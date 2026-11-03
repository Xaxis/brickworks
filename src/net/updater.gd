## The desktop app keeping itself up to date, as VS Code, Obsidian and a
## Sparkle Mac app do (docs/UPDATES.md): asks once a day whether a newer
## version is out, and in Settings, Updates, Automatic (the default)
## downloads it in the background and puts it in place as the app quits, or
## at once on Update and restart. Ask first says it is out and waits; Off
## asks nothing until Help, Check for updates….
##
## What it trusts is Updates': a signed manifest, https on GitHub's hosts
## alone, and each download held to its size and SHA-256 before anything is
## unpacked. The swap is a small helper's, beside the app
## (src/net/update_helper.sh, .ps1), run once the app has quit: a running
## program cannot be replaced in place on Windows, and on every system the
## old copy is kept until the new one has started once, and put back if it
## does not.
##
## Update and restart writes the working model first, as the web app's
## Reload does, and the window that comes back takes the same session
## (TabSession, --session=), so it opens the model as it was left.
class_name Updater
extends Node

signal changed

## Settings, Updates (ShellPrefs "updates").
const MODES: Array[String] = ["auto", "ask", "off"]
const MODE_WORDS: Dictionary = {"auto": "Automatic", "ask": "Ask first", "off": "Off"}
## How often the app asks by itself.
const EVERY_S := 86400
## How long after the window is up it asks: the start is the person's.
const AFTER_START_S := 8.0
const WHERE := "user://updates/"
const STATE := WHERE + "state.json"
## The update just put in place, for the copy that starts next.
const PENDING := WHERE + "pending.json"
const LOG := WHERE + "log.txt"
## A redirect followed at most this often.
const HOPS := 5

enum { IDLE, CHECKING, UP_TO_DATE, OUT, DOWNLOADING, READY, RESTARTING, FAILED }

var state: int = IDLE
## The newer version's manifest, once one is found.
var manifest: Dictionary = {}
## What the last step says: "You're up to date (0.16.0)", or why not.
var said: String = ""
var received: int = 0
var total: int = 0
## Whether what is being downloaded is this same version again (Reinstall).
var reinstalling: bool = false
## Where this copy is and how it would be updated (Updates.here): a probe
## puts its own.
var install: Dictionary = Updates.here()
var store: ModelStore
## Runs the helper and ends the app: a probe replaces it, and is told the
## helper's arguments.
var hand_over: Callable = _hand_over
## What a person sees said once, in the status bar (Main).
var say: Callable = func(_line: String) -> void: pass

var _http: HTTPRequest = null
var _staged: Dictionary = {}
## The copy an update replaced, taken away once this one is surely up.
var _drop_later: String = ""
## latest.json as it came, kept beside the download it describes.
var _signed: PackedByteArray = PackedByteArray()
var _state: Dictionary = {}
## --update=check, fetch, install, reinstall, restart or report: what a
## test run asked for (tools/update_check.py).
var _asked: String = ""


## The setting, or Off where BRICKWORKS_UPDATES=off says so: a test run of
## a package (tools/release.py smoke), or a machine an administrator updates.
static func mode() -> String:
	if OS.get_environment("BRICKWORKS_UPDATES").to_lower() == "off":
		return "off"
	var chosen: String = str(ShellPrefs.value("updates"))
	return chosen if chosen in MODES else "auto"


static func choose(chosen: String) -> void:
	if chosen in MODES:
		ShellPrefs.put("updates", chosen)


## Whether this copy can be updated from inside: the desktop app as it was
## downloaded.
func can_install() -> bool:
	return not str(install.get("kind", "")).is_empty() and str(install.get("why_not", "")).is_empty()


## Whether the app is on a system it updates on at all (not the web).
static func on_desktop() -> bool:
	return not OS.has_feature("web")


func _ready() -> void:
	_state = _read_json(STATE)
	_asked = _argument("--update")
	_load_staged()


## Once the window is up and the model is back (Main): a copy just updated
## says it started, and the day's check is made a little later.
func begin() -> void:
	_started_after_update()
	if _asked == "report":
		_report.call_deferred()
		return
	if not _asked.is_empty():
		_run_asked.call_deferred()
		return
	# Run from source, as every probe and its windows are, it never asks by
	# itself: only a downloaded copy has anything to update.
	if mode() == "off" or not OS.has_feature("template") or OS.get_cmdline_args().has("--script"):
		return
	var last: float = float(_state.get("checked", 0.0))
	if Time.get_unix_time_from_system() - last < EVERY_S:
		return
	get_tree().create_timer(AFTER_START_S).timeout.connect(func() -> void:
		if state == IDLE or state == READY:
			check())


## Ask whether a newer version is out. By hand (Help, Check for updates…)
## it asks whatever the setting and however lately it last asked.
func check() -> void:
	if state in [CHECKING, DOWNLOADING, RESTARTING]:
		return
	_become(CHECKING, "Checking for updates…")
	var got: Dictionary = await _fetch(Updates.manifest_url(), "", Updates.MANIFEST_MOST)
	if not got.has("body"):
		_fail("Couldn't check for updates: %s" % str(got["why"]))
		return
	var read: Dictionary = Updates.read(got["body"])
	if not read.has("manifest"):
		_fail(str(read["why"]))
		return
	_state["checked"] = Time.get_unix_time_from_system()
	_write_state()
	var found: Dictionary = read["manifest"]
	var version: String = str(found["version"])
	var newer: int = Updates.compare(version, BuildInfo.version())
	if newer <= 0:
		# An older release than this copy is never offered: a manifest of
		# one, however well signed, is what a downgrade attack replays.
		manifest = {}
		_become(UP_TO_DATE, "You're up to date (%s)" % BuildInfo.version() if newer == 0
			else "You're up to date (%s): refused %s, which is older" % [BuildInfo.version(), version])
		return
	manifest = found
	_signed = got["body"]
	if not _staged.is_empty() and str(_staged.get("version", "")) == version:
		_become(READY, "Brickworks %s is ready" % version)
		return
	_become(OUT, "Brickworks %s is out" % version)
	if mode() == "auto" and can_install() and not version in _state.get("failed", []) \
			and _asked.is_empty():
		download()


## Download the newer version, check it and unpack it beside this one.
func download() -> void:
	if manifest.is_empty() or state in [DOWNLOADING, RESTARTING]:
		return
	if not can_install():
		_fail(str(install.get("why_not", "This copy can't update itself")))
		return
	var version: String = str(manifest["version"])
	var file: Dictionary = Updates.file_for(manifest, str(install["os"]), str(install["package"]))
	if file.is_empty():
		_fail("The release has no %s for this system" % str(install["package"]))
		return
	var folder: String = str(install["stage"]).path_join(version)
	_remove_tree(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	_keep_manifest(folder)
	var archive: String = folder.path_join(str(file["name"]))
	total = int(file["size"])
	received = 0
	_become(DOWNLOADING, "Downloading Brickworks %s…" % version)
	var got: Dictionary = await _fetch(str(file["url"]), archive + ".part", total)
	var expected: int = total
	# Done with the bytes: what is said from here on has no share of them.
	total = 0
	if not got.has("body"):
		_drop(folder)
		_fail("Couldn't download Brickworks %s: %s" % [version, str(got["why"])])
		return
	var size: int = FileAccess.open(archive + ".part", FileAccess.READ).get_length() \
		if FileAccess.file_exists(archive + ".part") else -1
	if size != expected:
		_drop(folder)
		_fail("refused the download: %d bytes, where the manifest says %d" % [size, expected])
		return
	_become(DOWNLOADING, "Checking Brickworks %s…" % version)
	var part: String = archive + ".part"
	var hashed: String = str(await _off_thread(func() -> String: return Updates.sha256_file(part)))
	if hashed != str(file["sha256"]):
		_drop(folder)
		_fail("refused the download: its SHA-256 is not the manifest's")
		return
	DirAccess.rename_absolute(archive + ".part", archive)
	_become(DOWNLOADING, "Unpacking Brickworks %s…" % version)
	var unpacked: Dictionary = await _off_thread(_unpack.bind(archive, folder))
	if not unpacked.has("item"):
		_drop(folder)
		_fail("Couldn't unpack Brickworks %s: %s" % [version, str(unpacked["why"])])
		return
	_staged = {"version": version, "item": unpacked["item"], "folder": folder,
		"reinstall": reinstalling}
	_state["staged"] = _staged
	_write_state()
	_note("staged %s at %s" % [version, str(unpacked["item"])])
	_become(READY, "Brickworks %s is ready" % version)


## Help, Reinstall Brickworks…: this same version downloaded again, checked
## as an update is, and put in place of this copy.
func reinstall() -> void:
	if state in [CHECKING, DOWNLOADING, RESTARTING]:
		return
	if not can_install():
		_fail(str(install.get("why_not", "This copy can't update itself")))
		return
	_become(CHECKING, "Finding Brickworks %s…" % BuildInfo.version())
	var got: Dictionary = await _fetch(Updates.manifest_url(BuildInfo.version()), "",
		Updates.MANIFEST_MOST)
	if not got.has("body"):
		_fail("Couldn't find Brickworks %s to reinstall: %s" % [BuildInfo.version(), str(got["why"])])
		return
	var read: Dictionary = Updates.read(got["body"])
	if not read.has("manifest"):
		_fail(str(read["why"]))
		return
	if Updates.compare(str(read["manifest"]["version"]), BuildInfo.version()) != 0:
		_fail("refused: the manifest is for %s, not this version" % str(read["manifest"]["version"]))
		return
	manifest = read["manifest"]
	_signed = got["body"]
	_staged = {}
	reinstalling = true
	await download()
	reinstalling = false


## Update and restart: the newer version downloaded first if it is not yet.
func update_and_restart() -> void:
	if state == OUT or (state == FAILED and not manifest.is_empty() and _staged.is_empty()):
		await download()
	if state == READY:
		restart("install")


## End this copy and start it again: as it is ("restart"), or with the
## version staged put in place first ("install"). The working model is
## written first, and the window that comes back takes the same session.
func restart(how: String = "restart") -> void:
	if state == RESTARTING:
		return
	if how == "install" and _staged.is_empty():
		return
	var mine: String = BuildInfo.version()
	_become(RESTARTING, "Restarting…" if how == "restart" else
		"Restarting into Brickworks %s…" % str(_staged["version"]))
	await _keep_the_model()
	_note("restart: model “%s”, %d parts; session %s" % [store.title if store != null else "",
		store.world.brick_count() if store != null and store.world != null else 0, TabSession.id()])
	var user: PackedStringArray = PackedStringArray([TabSession.SAME_SESSION + TabSession.id()])
	if how == "install":
		user.append("--updated-from=%s" % mine)
	# A test run's copy says what it came back as, and stops (tools/update_check.py).
	if _asked in ["install", "reinstall", "restart"]:
		user.append("--update=report")
	var helper: Array = _helper(how, user)
	if helper.is_empty():
		_fail("Couldn't restart: no helper for this system")
		return
	if how == "install":
		_write_json(PENDING, {"to": str(_staged["version"]), "from": mine,
			"marker": _marker(str(_staged["version"])), "folder": str(_staged["folder"]),
			"at": Time.get_unix_time_from_system()})
	_note("%s: %s" % [how, " ".join(helper)])
	hand_over.call(helper)


## The app is quitting: in Automatic, an update staged is put in place now,
## so the next start is the new version. Nothing is started after it.
func on_quit() -> void:
	if not _drop_later.is_empty():
		_drop(_drop_later)
		_drop_later = ""
	if state == RESTARTING or _staged.is_empty() or mode() != "auto" or not can_install():
		return
	var item: String = str(_staged["item"])
	if bool(_staged.get("reinstall", false)) \
			or (not FileAccess.file_exists(item) and not DirAccess.dir_exists_absolute(item)):
		return
	var helper: Array = _helper("quit", PackedStringArray())
	if helper.is_empty():
		return
	_write_json(PENDING, {"to": str(_staged["version"]), "from": BuildInfo.version(),
		"marker": _marker(str(_staged["version"])), "folder": str(_staged["folder"]),
		"at": Time.get_unix_time_from_system()})
	_note("quit: %s" % " ".join(helper))
	OS.create_process(str(helper[0]), PackedStringArray(helper.slice(1)))


## The command that runs the helper: what it swaps, what it starts after,
## and how it can tell the new copy started.
func _helper(how: String, user: PackedStringArray) -> Array:
	var windows: bool = OS.get_name() == "Windows"
	var script: String = _write_helper("ps1" if windows else "sh")
	if script.is_empty():
		return []
	var launch: Array = _launch(user)
	var target: String = "-"
	var staged: String = "-"
	var backup: String = "-"
	var about: String = "-"
	var version: String = BuildInfo.version()
	if how != "restart":
		target = str(install["target"])
		staged = str(_staged["item"])
		backup = str(_staged["folder"]).path_join("previous" + (".AppImage"
			if install["kind"] == "appimage" else ""))
		about = str(install["about"][0])
		version = str(_staged["version"])
	var marker: String = _marker(version)
	DirAccess.remove_absolute(marker)
	var arguments: Array = [script, how, str(OS.get_process_id()), target, staged, backup,
		marker, version, about, ProjectSettings.globalize_path(LOG), "--"]
	arguments.append_array(launch)
	if windows:
		return ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
			"-WindowStyle", "Hidden", "-File"] + arguments
	return ["/bin/sh"] + arguments


## How the copy at the target is started, with this run's engine switches
## and [param user]'s.
func _launch(user: PackedStringArray) -> Array:
	var engine: Array = []
	if DisplayServer.get_name() == "headless":
		engine.append("--headless")
	else:
		engine.append_array(["--rendering-driver", RenderingServer.get_current_rendering_driver_name(),
			"--rendering-method", RenderingServer.get_current_rendering_method()])
	var launch: Array = []
	if str(install.get("kind", "")).is_empty():
		# Run from source: started as TabSession.window_arguments does.
		launch = [OS.get_executable_path(), "--path", ProjectSettings.globalize_path("res://")]
	else:
		launch = (install["launch"] as Array).duplicate()
		if install["kind"] == "mac":
			# open -W lasts as long as the app does, so the helper can tell it ended.
			launch.insert(2, "-W")
	return launch + engine + ["--"] + Array(user)


## The helper's script, written where it can run from.
func _write_helper(kind: String) -> String:
	var source: String = "res://src/net/update_helper.%s" % kind
	var text: String = FileAccess.get_file_as_string(source)
	if text.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(WHERE)
	var path: String = WHERE + "helper." + kind
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(text)
	file.close()
	return ProjectSettings.globalize_path(path)


## What the new copy writes once its window is up, for the helper.
func _marker(version: String) -> String:
	return ProjectSettings.globalize_path(WHERE + "started-%s" % version)


func _hand_over(helper: Array) -> void:
	var pid: int = OS.create_process(str(helper[0]), PackedStringArray(helper.slice(1)))
	if pid <= 0:
		DirAccess.remove_absolute(PENDING)
		_fail("Couldn't start the updater's helper")
		return
	get_tree().quit()


## The working model written before the app goes, and stored (as Reload):
## what is on screen, changed or not. A model opened from the command line
## and not touched since had never been written, so the window that came
## back opened the session's model before it.
func _keep_the_model() -> void:
	if store == null:
		return
	store.touch()
	var path: String = store.write_now()
	var waited: float = 0.0
	while not path.is_empty() and not ModelStore.stored(path) and waited < 30.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25


## The copy that starts after an update: says it started, so the helper
## keeps it, and takes away the copy it replaced. A copy that did not start
## was put back by the helper, which says so (--update-failed=).
func _started_after_update() -> void:
	var failed: String = _argument("--update-failed")
	var pending: Dictionary = _read_json(PENDING)
	if not failed.is_empty() and Updates.is_version(failed):
		var kept: Array = _state.get("failed", [])
		if not failed in kept:
			kept.append(failed)
		_state["failed"] = kept
		_state.erase("staged")
		_write_state()
		DirAccess.remove_absolute(PENDING)
		_drop(str(pending.get("folder", "")))
		_staged = {}
		state = IDLE
		_note("%s did not start; %s kept" % [failed, BuildInfo.version()])
		said = "Brickworks %s didn't start, so %s was kept" % [failed, BuildInfo.version()]
		_say_later(said)
		return
	if pending.is_empty() or str(pending.get("to", "")) != BuildInfo.version():
		return
	var marker: FileAccess = FileAccess.open(str(pending.get("marker", "")), FileAccess.WRITE)
	if marker != null:
		marker.store_string(str(OS.get_process_id()))
		marker.close()
	DirAccess.remove_absolute(PENDING)
	_state.erase("staged")
	_write_state()
	var from: String = str(pending.get("from", ""))
	_note("started %s (from %s)" % [BuildInfo.version(), from])
	# The old copy, once the helper has seen this one start: a little later,
	# or as this one quits if that is sooner.
	_drop_later = str(pending.get("folder", ""))
	get_tree().create_timer(15.0).timeout.connect(func() -> void:
		if not _drop_later.is_empty():
			_drop(_drop_later)
			_drop_later = "")
	if Updates.compare(from, BuildInfo.version()) < 0:
		_say_later("Brickworks was updated to %s" % BuildInfo.version())
	else:
		_say_later("Brickworks %s was reinstalled" % BuildInfo.version())


func _say_later(line: String) -> void:
	get_tree().create_timer(3.0).timeout.connect(func() -> void: say.call(line))


## An update downloaded before, still there and still what its signed
## manifest says: ready to put in place.
func _load_staged() -> void:
	var kept: Variant = _state.get("staged")
	if not kept is Dictionary or not can_install():
		return
	var staged: Dictionary = kept
	var version: String = str(staged.get("version", ""))
	var item: String = str(staged.get("item", ""))
	var folder: String = str(staged.get("folder", ""))
	var read: Dictionary = Updates.read(FileAccess.get_file_as_bytes(folder.path_join("latest.json")))
	var whole: bool = FileAccess.file_exists(item) or DirAccess.dir_exists_absolute(item)
	if not read.has("manifest") or str(read["manifest"]["version"]) != version or not whole \
			or Updates.compare(version, BuildInfo.version()) < 0 or not folder.begins_with(str(install["stage"])) \
			or (Updates.compare(version, BuildInfo.version()) == 0 and not bool(staged.get("reinstall", false))):
		_state.erase("staged")
		_write_state()
		_drop(folder)
		return
	_staged = staged
	manifest = read["manifest"]
	state = READY
	said = "Brickworks %s is ready" % version


## The signed manifest kept beside what it describes, so a later start
## believes the staged copy only as far as the signature does.
func _keep_manifest(folder: String) -> void:
	var file: FileAccess = FileAccess.open(folder.path_join("latest.json"), FileAccess.WRITE)
	if file != null:
		file.store_buffer(_signed)
		file.close()


## Fetch [param url], following redirects only to the hosts Updates lets in:
## {"body": bytes} (into [param into] when it is a path), or {"why": why not}.
func _fetch(url: String, into: String, most: int) -> Dictionary:
	var at: String = url
	for hop: int in HOPS + 1:
		var why: String = Updates.refuse_url(at)
		if not why.is_empty():
			_note(why)
			return {"why": why}
		_http = HTTPRequest.new()
		_http.use_threads = true
		_http.max_redirects = 0
		_http.download_file = into
		_http.body_size_limit = most
		_http.timeout = 30.0 if into.is_empty() else 3600.0
		add_child(_http)
		var asked: int = _http.request(at, PackedStringArray([
			"User-Agent: Brickworks/%s (%s)" % [BuildInfo.version(), OS.get_name()]]))
		if asked != OK:
			_http.queue_free()
			_http = null
			return {"why": "could not ask %s" % at}
		var done: Array = await _http.request_completed
		_http.queue_free()
		_http = null
		var result: int = done[0]
		var code: int = done[1]
		if code in [301, 302, 303, 307, 308]:
			at = Updates.resolve(at, _header(done[2], "location"))
			if at.is_empty():
				return {"why": "a redirect to nowhere"}
			_note("redirected to %s" % at)
			continue
		if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return {"why": "refused: more bytes than the manifest says"}
		if result != HTTPRequest.RESULT_SUCCESS:
			return {"why": RESULTS.get(result, "the connection failed (%d)" % result)}
		if code != 200:
			return {"why": "the server answered %d" % code}
		return {"body": done[3]}
	return {"why": "too many redirects"}


const RESULTS: Dictionary = {
	HTTPRequest.RESULT_CANT_CONNECT: "no connection", HTTPRequest.RESULT_CANT_RESOLVE: "no connection",
	HTTPRequest.RESULT_CONNECTION_ERROR: "the connection failed",
	HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: "the server's certificate did not hold",
	HTTPRequest.RESULT_TIMEOUT: "no answer in time",
	HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: "nowhere to write the download",
	HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: "the disk would not take the download",
}


static func _header(headers: PackedStringArray, name: String) -> String:
	for line: String in headers:
		if line.to_lower().begins_with(name + ":"):
			return line.substr(name.length() + 1).strip_edges()
	return ""


func _process(_delta: float) -> void:
	if _http != null and state == DOWNLOADING:
		var now: int = _http.get_downloaded_bytes()
		if now != received:
			received = now
			changed.emit()


## [param work] run on a thread of its own, waited for a frame at a time, and
## what it returned. A Thread's own answer: an Array element written from a
## worker thread can read as null on this one.
func _off_thread(work: Callable) -> Variant:
	var thread := Thread.new()
	thread.start(work)
	while thread.is_alive():
		await get_tree().process_frame
	return thread.wait_to_finish()


## The archive unpacked in [param folder]: {"item": the AppImage, folder or
## .app to put in place}, or {"why"}. On a worker thread.
func _unpack(archive: String, folder: String) -> Dictionary:
	var output: Array = []
	match str(install["kind"]):
		"appimage":
			var image: String = folder.path_join("Brickworks.AppImage")
			if DirAccess.rename_absolute(archive, image) != OK:
				return {"why": "could not move it into place"}
			OS.execute("chmod", ["755", image], output)
			return {"item": image}
		"tar.xz":
			if OS.execute("tar", ["-xJf", archive, "-C", folder], output, true) != 0:
				return {"why": "tar: %s" % "".join(output).strip_edges().left(200)}
			DirAccess.remove_absolute(archive)
			return _found_in(folder, "brickworks.x86_64")
		"mac":
			# ditto is what Finder unpacks with, and keeps the bundle's seal.
			if OS.execute("ditto", ["-x", "-k", archive, folder], output, true) != 0:
				return {"why": "ditto: %s" % "".join(output).strip_edges().left(200)}
			DirAccess.remove_absolute(archive)
			var app: String = ""
			for each: String in DirAccess.get_directories_at(folder):
				if DirAccess.dir_exists_absolute(folder.path_join(each).path_join("Brickworks.app")):
					app = folder.path_join(each).path_join("Brickworks.app")
			if app.is_empty():
				return {"why": "no Brickworks.app in it"}
			var why: String = _signature_refused(app)
			return {"why": why} if not why.is_empty() else {"item": app}
		"windows":
			# Windows 10 and later have bsdtar, which reads a zip.
			var tar: String = OS.get_environment("SystemRoot").path_join("System32/tar.exe")
			if OS.execute(tar, ["-xf", archive, "-C", folder], output, true) != 0:
				output.clear()
				if OS.execute("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command",
						"Expand-Archive -LiteralPath '%s' -DestinationPath '%s'" % [archive, folder]],
						output, true) != 0:
					return {"why": "the zip would not unpack"}
			DirAccess.remove_absolute(archive)
			return _found_in(folder, OS.get_executable_path().get_file())
	return {"why": "this system's packages are not known"}


## The folder in [param folder] holding [param program].
static func _found_in(folder: String, program: String) -> Dictionary:
	for each: String in DirAccess.get_directories_at(folder):
		if FileAccess.file_exists(folder.path_join(each).path_join(program)):
			return {"item": folder.path_join(each)}
	return {"why": "no %s in it" % program}


## On a Mac, the new app's signature checked as macOS will at launch, and
## when this copy is signed with a Developer ID, by the same team.
func _signature_refused(app: String) -> String:
	var output: Array = []
	if OS.execute("codesign", ["--verify", "--deep", "--strict", app], output, true) != 0:
		return "refused: its code signature does not hold"
	var mine: String = _team(str(install.get("target", "")) if not install.has("moves_to")
		else OS.get_executable_path().get_base_dir().get_base_dir().get_base_dir())
	if not mine.is_empty() and _team(app) != mine:
		return "refused: it is signed by someone else"
	return ""


static func _team(app: String) -> String:
	var output: Array = []
	OS.execute("codesign", ["-dv", "--verbose=2", app], output, true)
	var team: RegExMatch = RegEx.create_from_string("TeamIdentifier=([A-Z0-9]{10})").search("".join(output))
	return team.get_string(1) if team != null else ""


func _become(to: int, words: String) -> void:
	state = to
	said = words
	_note(words)
	changed.emit()


func _fail(words: String) -> void:
	_become(FAILED, words)


## A folder of the updater's own taken away, and the stage with it once it
## is empty: never anything outside the stage.
func _drop(folder: String) -> void:
	if folder.is_empty() or not "/.brickworks-update/" in folder.replace("\\", "/"):
		return
	_remove_tree(folder)
	var stage: String = folder.get_base_dir()
	if stage.ends_with(".brickworks-update") and DirAccess.get_files_at(stage).is_empty() \
			and DirAccess.get_directories_at(stage).is_empty():
		DirAccess.remove_absolute(stage)


static func _remove_tree(path: String) -> void:
	if not "/.brickworks-update/" in path.replace("\\", "/"):
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return
	if not DirAccess.dir_exists_absolute(path):
		return
	var here := DirAccess.open(path)
	if here == null:
		return
	here.include_hidden = true
	# A link is taken away, never followed: an .app's frameworks have them.
	for name: String in here.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	for name: String in here.get_directories():
		if here.is_link(name):
			DirAccess.remove_absolute(path.path_join(name))
		else:
			_remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)


## A line in the updater's log, said on the console too.
func _note(line: String) -> void:
	print("update: %s" % line)
	DirAccess.make_dir_recursive_absolute(WHERE)
	var file: FileAccess = FileAccess.open(LOG, FileAccess.READ_WRITE if FileAccess.file_exists(LOG)
		else FileAccess.WRITE)
	if file == null:
		return
	if file.get_length() > 256 * 1024:
		file.close()
		file = FileAccess.open(LOG, FileAccess.WRITE)
	file.seek_end()
	file.store_line("%s %s" % [Time.get_datetime_string_from_system(true), line])
	file.close()


func _write_state() -> void:
	_write_json(STATE, _state)


static func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) \
		if FileAccess.file_exists(path) else null
	return parsed if parsed is Dictionary else {}


static func _write_json(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()


static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.substr(prefix.length() + 1)
	return ""


## --update=check, fetch, install, reinstall or restart: the step a test run
## asked for, once the window is up, saying what it found and quitting
## (exit 0 for what was asked done, 1 for refused or failed). Install,
## reinstall and restart quit by restarting.
func _run_asked() -> void:
	await get_tree().create_timer(1.0).timeout
	match _asked:
		"check":
			await check()
		"fetch", "install":
			await check()
			if state == OUT:
				await download()
			if _asked == "install" and state == READY:
				restart("install")
				return
		"reinstall":
			await reinstall()
			if state == READY:
				restart("install")
				return
		"restart":
			restart("restart")
			return
	print("update: %s: %s" % [_asked, said])
	get_tree().quit(0 if state in [UP_TO_DATE, OUT, READY] else 1)


## --update=report: the copy a test run restarted into says what it is,
## what it opened and in which session, and quits.
func _report() -> void:
	await get_tree().create_timer(3.0).timeout
	var model: String = store.title if store != null else ""
	var parts: int = 0
	if store != null and store.world != null:
		parts = store.world.brick_count()
	var line: String = "report: running %s; model “%s”, %d parts; session %s" % [
		BuildInfo.version(), model, parts, TabSession.id()]
	_note(line)
	get_tree().quit(0)
