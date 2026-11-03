## Does the desktop app keep itself up to date, believing only what its
## release signed?
##
##   godot --headless --path . --script src/dev/updater_probe.gd
##
## Updates' rules first: versions compared as semantic versions; a manifest
## signed by a key of the probe's own (Updates.keys_for_probe) read, and
## refused when its words were changed, when another key signed it, when it
## is not Brickworks', or names a file with no SHA-256, over plain HTTP or
## off GitHub; the release's two public keys load and are the ids they are
## filed under; and the addresses let in.
##
## Then the app on the real scene, against a server on this machine
## (tools/update_check.py serve, which BRICKWORKS_UPDATE_URL points at):
## Check for updates refuses a bad signature and an older version, and says
## what is out; in Ask first the notice says so with What's new, Update and
## restart and Later; in Automatic a download is refused when its SHA-256 or
## its size is not the manifest's, or a redirect leaves the server, and a
## good one is checked, unpacked beside the install and said ready. Update
## and restart, pressed on the notice, writes the working model and hands
## the helper the swap, the new copy and the same session; Help, Restart
## Brickworks hands it a restart; Help, Reinstall Brickworks… downloads this
## same version. Help has the three items, and Settings, Updates offers
## Automatic, Ask first and Off. The helper is never run: the probe takes
## what the app hands it (Updater.hand_over), and tools/update_check.py
## installs real packages.
##
## Before 2026-11-03 the desktop app had no check at all.
extends SceneTree

const VERSION := "99.0.0"
const PACKAGE := "Brickworks-99.0.0-linux-x86_64.tar.xz"

var _failures: int = 0
var _main: Node
var _updater: Updater
var _notice: UpdateNotice
var _root: String = ""
var _server: int = 0
var _port: int = 0
var _handed: Array = []
var _kept: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	OS.unset_environment("BRICKWORKS_UPDATE_URL")
	_versions()
	_addresses()
	var key: CryptoKey = Crypto.new().generate_rsa(2048)
	Updates.keys_for_probe = {"probe": key.save_to_string(true)}
	_manifests(key)
	_release_keys()

	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_updater = _main.get("_updater")
	_notice = _main.get("_update_notice")
	_check("the desktop app has an updater and its notice, put away",
		_updater != null and _notice != null and not _notice.showing())
	if _updater == null or _notice == null:
		_done()
		return
	_keep_state()
	await _menus()
	await _settings()
	if OS.get_name() != "Linux" or not _serve(key):
		print("  --    the server and the tar.xz are this probe's on Linux: the rest skipped")
	else:
		await _online()
	_cleanup()
	_done()


## Versions: semver's order, which a downgrade check stands on.
func _versions() -> void:
	var table: Array = [["0.16.0", "0.15.0", 1], ["0.15.0", "0.15.0", 0], ["0.15.0", "0.16.0", -1],
		["0.10.0", "0.9.12", 1], ["1.0.0", "0.99.99", 1], ["1.0.0-beta.2", "1.0.0", -1],
		["1.0.0-beta.10", "1.0.0-beta.2", 1], ["1.0.0-alpha", "1.0.0-beta", -1],
		["1.0.0-rc.1", "1.0.0-rc.1", 0], ["nonsense", "0.0.1", -1]]
	var wrong: Array = []
	for row: Array in table:
		if Updates.compare(row[0], row[1]) != int(row[2]):
			wrong.append("%s vs %s" % [row[0], row[1]])
	_check("versions compare as semantic versions (0.10.0 after 0.9.12, a beta before its release)%s"
		% ("" if wrong.is_empty() else ": wrong " + ", ".join(wrong)), wrong.is_empty())
	_check("a version is three numbers and an optional pre-release",
		Updates.is_version("0.16.0") and Updates.is_version("1.0.0-beta.1")
			and not Updates.is_version("v0.16.0") and not Updates.is_version("0.16")
			and not Updates.is_version("0.16.0 ") and not Updates.is_version("01.2.3"))


## Addresses: https on GitHub's release hosts and brickworks.diy, nothing else.
func _addresses() -> void:
	var let_in: Array = ["https://github.com/Xaxis/brickworks-releases/releases/latest/download/latest.json",
		"https://release-assets.githubusercontent.com/github-production-release-asset/1/2",
		"https://objects.githubusercontent.com/x", "https://brickworks.diy/download"]
	var refused: Dictionary = {
		"http://github.com/Xaxis/brickworks-releases/": "refused plain HTTP",
		"https://example.com/Brickworks.zip": "refused an address off GitHub",
		"https://github.com.example.net/x": "refused an address off GitHub",
		"https://example.net/github.com/x": "refused an address off GitHub",
		"ftp://github.com/x": "not an address",
		"https://github.com@example.net/x": "not an address",
	}
	var wrong: Array = []
	for url: String in let_in:
		if not Updates.refuse_url(url).is_empty():
			wrong.append(url)
	for url: String in refused:
		if not Updates.refuse_url(url).begins_with(str(refused[url])):
			wrong.append("%s (%s)" % [url, Updates.refuse_url(url)])
	_check("only https on GitHub's release hosts and brickworks.diy is let in%s"
		% ("" if wrong.is_empty() else ": wrong " + ", ".join(wrong)), wrong.is_empty())
	_check("with no test server named, latest.json is the newest GitHub release's, a version's its own",
		Updates.manifest_url() == Updates.RELEASES + "latest/download/latest.json"
			and Updates.manifest_url("0.15.0") == Updates.RELEASES + "download/v0.15.0/latest.json")
	_check("a redirect's path stays on its host; an absolute one is checked as any address",
		Updates.resolve("https://github.com/a/b", "/c/d") == "https://github.com/c/d"
			and Updates.resolve("https://github.com/a", "https://example.com/x") == "https://example.com/x"
			and Updates.resolve("https://github.com/a", "c") == "")


## The manifest: believed only once a known key's signature over its exact
## words holds, and only then read.
func _manifests(key: CryptoKey) -> void:
	var file: Dictionary = _file("https://github.com/Xaxis/brickworks-releases/releases/download/v99.0.0/"
		+ PACKAGE, 1234, "ab".repeat(32))
	var good: Dictionary = Updates.read(_signed(_manifest(VERSION, [file]), key))
	_check("a manifest a known key signed is read: %s" % str(good.get("why", "")),
		good.has("manifest") and str(good["manifest"]["version"]) == VERSION)
	var reads: Dictionary = {
		"its words changed after signing": [_signed(_manifest(VERSION, [file]), key, "99.0.0", "99.0.1"),
			"refused: the manifest's signature does not hold"],
		"signed by another key": [_signed(_manifest(VERSION, [file]), Crypto.new().generate_rsa(2048)),
			"refused: the manifest's signature does not hold"],
		"not Brickworks'": [_signed(_manifest(VERSION, [file]).merged({"product": "elsewhere"}, true), key),
			"refused: the manifest is not Brickworks'"],
		"a file with no SHA-256": [_signed(_manifest(VERSION, [_file(str(file["url"]), 1234, "")]), key),
			"refused: %s has no SHA-256" % PACKAGE],
		"a file over plain HTTP": [_signed(_manifest(VERSION, [_file("http://github.com/" + PACKAGE, 1234,
			"ab".repeat(32))]), key), "refused plain HTTP"],
		"a file off GitHub": [_signed(_manifest(VERSION, [_file("https://example.com/" + PACKAGE, 1234,
			"ab".repeat(32))]), key), "refused an address off GitHub"],
		"not JSON": ["<html>".to_utf8_buffer(), "latest.json is not a manifest"],
	}
	for what: String in reads:
		var read: Dictionary = Updates.read(reads[what][0])
		_check("a manifest %s is refused: %s" % [what, str(read.get("why", "read!"))],
			not read.has("manifest") and str(read.get("why", "")).begins_with(str(reads[what][1])))


## The release's own two public keys: each loads, and is filed under its id.
func _release_keys() -> void:
	var held: Array = []
	for id: String in Updates.KEYS:
		var pem: String = Updates.KEYS[id]
		var key := CryptoKey.new()
		var body: String = ""
		for line: String in pem.split("\n"):
			if not line.begins_with("-----"):
				body += line.strip_edges()
		var der: PackedByteArray = Marshalls.base64_to_raw(body)
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(der)
		if key.load_from_string(pem, true) == OK and digest.finish().hex_encode().left(16) == id:
			held.append(id)
	_check("the app carries two release keys, each loading and filed under its own id (%s)"
		% ", ".join(held), held.size() == 2 and Updates.KEYS.size() == 2)


## Help's three items, and Restart run from the menu.
func _menus() -> void:
	var shell: Shell = _main.get("_shell")
	_check("Help has Check for updates…, Reinstall Brickworks… and Restart Brickworks",
		shell.menu_id("check_updates") >= 0 and shell.menu_id("reinstall") >= 0
			and shell.menu_id("restart") >= 0 and shell.can("check_updates") and shell.can("restart"))
	_updater.hand_over = func(helper: Array) -> void: _handed = helper
	_handed = []
	var store: ModelStore = _main.get("_store")
	store.open("res://models/house.ldr")
	store.title = "Updater Probe House"
	store.adopt()
	# A probe keeps no working model unless it turns that on (Main).
	store.keeps = true
	var own: String = ModelStore.autosave()
	DirAccess.remove_absolute(own)
	await _frames(10)
	shell.run("restart")
	await _until(func() -> bool: return not _handed.is_empty(), 30.0)
	var session: String = TabSession.SAME_SESSION + TabSession.id()
	_check("Help, Restart Brickworks writes the working model, then hands the helper a restart in the same session: %s"
		% " ".join(_handed.slice(1, 3)),
		_handed.size() > 3 and str(_handed[0]) == "/bin/sh" and str(_handed[2]) == "restart"
			and str(_handed[3]) == str(OS.get_process_id()) and _handed.has(session)
			and FileAccess.get_file_as_string(own).begins_with("0 Updater Probe House"))
	_check("...with the helper the app ships, written where it can run",
		not _handed.is_empty() and FileAccess.get_file_as_string(str(_handed[1]))
			== FileAccess.get_file_as_string("res://src/net/update_helper.sh"))
	_updater.state = Updater.IDLE


## Settings, Updates: Automatic, Ask first and Off, the one chosen kept.
func _settings() -> void:
	var settings: ControlsDialog = _main.get("_controls")
	settings.open()
	await _frames(5)
	var choice: OptionButton = settings.updates_choice
	var items: Array = []
	if choice != null:
		for n: int in choice.item_count:
			items.append(choice.get_item_text(n))
	_check("Settings, Updates offers %s, Automatic by default" % ", ".join(items),
		items == ["Automatic", "Ask first", "Off"] and ShellPrefs.DEFAULTS.get("updates") == "auto"
			and choice.selected == Updater.MODES.find(Updater.mode()))
	if choice != null:
		choice.select(2)
		choice.item_selected.emit(2)
	_check("choosing Off is kept", Updater.mode() == "off")
	Updater.choose("ask")
	settings.hide()


## A server on this machine with the probe's own release laid out on it.
func _serve(key: CryptoKey) -> bool:
	_root = ProjectSettings.globalize_path("user://updater_probe")
	_remove(_root)
	var made: String = _root.path_join("made/Brickworks-99.0.0-linux")
	DirAccess.make_dir_recursive_absolute(made)
	DirAccess.make_dir_recursive_absolute(_root.path_join("serve/files"))
	var program: FileAccess = FileAccess.open(made.path_join("brickworks.x86_64"), FileAccess.WRITE)
	program.store_string("#!/bin/sh\necho 'Brickworks 99.0.0'\n")
	program.close()
	var package: String = _root.path_join("serve/files").path_join(PACKAGE)
	if OS.execute("tar", ["-cJf", package, "-C", made.get_base_dir(), made.get_file()]) != 0:
		return false
	var probe := TCPServer.new()
	probe.listen(0, "127.0.0.1")
	_port = probe.get_local_port()
	probe.stop()
	var base: String = "http://127.0.0.1:%d/" % _port
	var size: int = FileAccess.open(package, FileAccess.READ).get_length()
	var sha: String = Updates.sha256_file(package)
	var direct: String = base + "files/" + PACKAGE
	var lay: Dictionary = {
		"good": _signed(_manifest(VERSION, [_file(base + "redirect/files/" + PACKAGE, size, sha)]), key),
		"badsig": _signed(_manifest(VERSION, [_file(direct, size, sha)]), key, "99.0.0", "99.0.1"),
		"older": _signed(_manifest("0.0.1", [_file(direct, size, sha)]), key),
		"badhash": _signed(_manifest(VERSION, [_file(direct, size, "0".repeat(64))]), key),
		"short": _signed(_manifest(VERSION, [_file(direct, size - 1, sha)]), key),
		"offhost": _signed(_manifest(VERSION, [_file(base + "redirect-off/files/" + PACKAGE, size, sha)]), key),
	}
	for name: String in lay:
		_put(_root.path_join("serve/%s/latest/download/latest.json" % name), lay[name])
	# This same version's own, for Reinstall.
	var mine: String = BuildInfo.version()
	_put(_root.path_join("serve/good/download/v%s/latest.json" % mine),
		_signed(_manifest(mine, [_file(direct.replace(VERSION, mine), size, sha)]), key))
	DirAccess.copy_absolute(package, package.replace(VERSION, mine))
	_server = OS.create_process("python3", [ProjectSettings.globalize_path("res://tools/update_check.py"),
		"serve", "--dir=" + _root.path_join("serve"), "--port=%d" % _port, "--seconds=600"])
	if _server <= 0:
		return false
	var waited: int = 0
	while waited < 100:
		var peer := StreamPeerTCP.new()
		peer.connect_to_host("127.0.0.1", _port)
		peer.poll()
		OS.delay_msec(100)
		peer.poll()
		var up: bool = peer.get_status() == StreamPeerTCP.STATUS_CONNECTED
		peer.disconnect_from_host()
		if up:
			return true
		waited += 1
	return false


## The app against the server: checks, downloads, the notice and the dialogs.
func _online() -> void:
	var install: String = _root.path_join("install/Brickworks-0.15.0-linux")
	DirAccess.make_dir_recursive_absolute(install)
	_updater.install = {"kind": "tar.xz", "os": "linux", "package": "tar.xz", "target": install,
		"launch": [install.path_join("brickworks.x86_64")],
		"about": [install.path_join("brickworks.x86_64")],
		"stage": _root.path_join("install/.brickworks-update"), "why_not": ""}
	var stage: String = _root.path_join("install/.brickworks-update/" + VERSION)

	Updater.choose("ask")
	await _check_at("badsig")
	_check("Check for updates refuses a manifest whose signature does not hold: %s" % _updater.said,
		_updater.state == Updater.FAILED and _updater.said == "refused: the manifest's signature does not hold"
			and not _notice.showing())
	await _check_at("older")
	_check("...and an older version, however well signed: %s" % _updater.said,
		_updater.state == Updater.UP_TO_DATE
			and _updater.said == "You're up to date (%s): refused 0.0.1, which is older" % BuildInfo.version()
			and not _notice.showing())

	await _check_at("good")
	await _frames(3)
	var named: Dictionary = _notice.controls_by_name()
	_check("in Ask first, a newer version is said and not downloaded: %s" % _updater.said,
		_updater.state == Updater.OUT and _updater.said == "Brickworks 99.0.0 is out"
			and not DirAccess.dir_exists_absolute(stage))
	_check("the notice: the version, What's new, Update and restart, Later",
		_notice.showing() and named.has("update_restart") and named.has("update_later")
			and named.has("update_whats_new")
			and (named["update_restart"] as Button).text == "Update and restart")
	(named["update_whats_new"] as LinkButton).pressed.emit()
	await _frames(2)
	_check("What's new shows the release notes", _texts(_notice).contains("A release the updater probe made."))
	(named["update_later"] as Button).pressed.emit()
	_updater.changed.emit()
	await _frames(2)
	_check("Later puts it away for this run", not _notice.showing())
	_notice.set("_put_off", "")

	_main.call("check_updates")
	var dialog: UpdateDialog = _main.get("_update_dialog")
	await _until(func() -> bool: return _updater.state != Updater.CHECKING, 30.0)
	await _frames(2)
	_check("Help, Check for updates… says what is out, with Update and restart and Later",
		dialog.visible and dialog.dialog_text.begins_with("Brickworks 99.0.0 is out. You have %s." % BuildInfo.version())
			and dialog.get_ok_button().text == "Update and restart"
			and dialog.get_cancel_button().text == "Later")
	dialog.hide()

	Updater.choose("auto")
	var refusals: Dictionary = {
		"badhash": "refused the download: its SHA-256 is not the manifest's",
		"short": "refused: more bytes than the manifest says",
		"offhost": "refused an address off GitHub and brickworks.diy: https://example.com/files/" + PACKAGE,
	}
	for name: String in refusals:
		await _check_at(name)
		await _until(func() -> bool: return _updater.state in [Updater.FAILED, Updater.READY], 60.0)
		_check("in Automatic, a download is refused (%s): %s" % [name, _updater.said],
			_updater.state == Updater.FAILED and _updater.said.ends_with(str(refusals[name]))
				and not DirAccess.dir_exists_absolute(stage))

	await _check_at("good")
	_check("in Automatic, the download runs out of sight: %s" % _updater.said,
		_updater.state == Updater.DOWNLOADING and not _notice.showing())
	await _until(func() -> bool: return _updater.state in [Updater.FAILED, Updater.READY], 60.0)
	var item: String = stage.path_join("Brickworks-99.0.0-linux")
	_check("in Automatic, a good one is downloaded by a redirect on its host, checked and unpacked beside the install: %s"
		% _updater.said, _updater.state == Updater.READY and _updater.said == "Brickworks 99.0.0 is ready"
			and FileAccess.file_exists(item.path_join("brickworks.x86_64"))
			and FileAccess.file_exists(stage.path_join("latest.json")))
	await _frames(2)
	named = _notice.controls_by_name()
	_check("the notice says it is ready", _notice.showing() and _texts(_notice).contains("Brickworks 99.0.0 is ready"))

	# Not changed since it was last written, as a model opened from the
	# command line is not: what is on screen is what comes back all the same.
	var own: String = ModelStore.autosave()
	DirAccess.remove_absolute(own)
	_handed = []
	(named["update_restart"] as Button).pressed.emit()
	await _until(func() -> bool: return not _handed.is_empty(), 30.0)
	var pending: Variant = JSON.parse_string(FileAccess.get_file_as_string(Updater.PENDING))
	_check("Update and restart writes the working model, then hands the helper the swap: %s"
		% " ".join(_handed.slice(2, 9)),
		_handed.size() > 9 and str(_handed[2]) == "install" and str(_handed[4]) == install
			and str(_handed[5]) == item and str(_handed[8]) == VERSION
			and FileAccess.get_file_as_string(own).begins_with("0 Updater Probe House"))
	_check("...the new copy started in the same session, told what it came from",
		_handed.has(TabSession.SAME_SESSION + TabSession.id())
			and _handed.has("--updated-from=" + BuildInfo.version()))
	_check("...and the copy that starts next told it is the update",
		pending is Dictionary and str((pending as Dictionary).get("to", "")) == VERSION
			and str((pending as Dictionary).get("from", "")) == BuildInfo.version())
	DirAccess.remove_absolute(Updater.PENDING)
	_updater.state = Updater.IDLE

	_main.call("ask_reinstall")
	await _frames(2)
	_check("Help, Reinstall Brickworks… asks first", dialog.visible
		and dialog.dialog_text.begins_with("Download Brickworks %s again" % BuildInfo.version())
		and dialog.get_ok_button().text == "Reinstall and restart")
	_handed = []
	dialog.get_ok_button().pressed.emit()
	await _until(func() -> bool: return not _handed.is_empty() or _updater.state == Updater.FAILED, 60.0)
	_check("...then downloads this same version, checked as an update is, and restarts into it: %s"
		% _updater.said, _handed.size() > 9 and str(_handed[2]) == "install"
			and str(_handed[8]) == BuildInfo.version() and not _notice.showing())
	dialog.hide()

	# What an earlier start could not take away goes at the next: an older
	# version's folder, never a newer one's, which another window may be
	# fetching.
	var left: String = _root.path_join("install/.brickworks-update/0.0.1/previous")
	var fetching: String = _root.path_join("install/.brickworks-update/99.9.9")
	DirAccess.make_dir_recursive_absolute(left)
	DirAccess.make_dir_recursive_absolute(fetching)
	_put(left.path_join("Brickworks.console.exe"), "MZ".to_utf8_buffer())
	_put(fetching.path_join("Brickworks-99.9.9-linux-x86_64.tar.xz.part"), "part".to_utf8_buffer())
	_updater.call("_sweep")
	_check("a start takes away what an earlier one left of an older version, and leaves a newer one's download",
		not DirAccess.dir_exists_absolute(left.get_base_dir())
			and FileAccess.file_exists(fetching.path_join("Brickworks-99.9.9-linux-x86_64.tar.xz.part")))
	_remove(fetching)


func _check_at(name: String) -> void:
	OS.set_environment("BRICKWORKS_UPDATE_URL", "http://127.0.0.1:%d/%s/" % [_port, name])
	_updater.state = Updater.IDLE
	_updater.manifest = {}
	_updater.set("_staged", {})
	await _updater.check()


func _manifest(version: String, files: Array) -> Dictionary:
	return {"product": Updates.PRODUCT, "version": version, "date": "2026-11-03", "tag": "v" + version,
		"page": "https://github.com/Xaxis/brickworks-releases/releases/tag/v" + version,
		"notes": "A release the updater probe made.", "files": files}


func _file(url: String, size: int, sha: String) -> Dictionary:
	return {"os": "linux", "kind": "tar.xz", "name": url.get_file(), "url": url, "size": size,
		"sha256": sha}


## latest.json as a release writes it, signed by [param key]; [param from]
## changed to [param to] in the signed words after signing, when given.
func _signed(manifest: Dictionary, key: CryptoKey, from: String = "", to: String = "") -> PackedByteArray:
	var text: String = JSON.stringify(manifest)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(text.to_utf8_buffer())
	var signature: PackedByteArray = Crypto.new().sign(HashingContext.HASH_SHA256, digest.finish(), key)
	if not from.is_empty():
		text = text.replace(from, to)
	return JSON.stringify({"signed": text, "signatures": [{"key": "probe",
		"rsa_sha256": Marshalls.raw_to_base64(signature)}]}).to_utf8_buffer()


func _put(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## Every label's and button's words under [param node].
func _texts(node: Node) -> String:
	var said: String = ""
	for child: Node in node.find_children("*", "", true, false):
		if (child is Label or child is Button) and (child as CanvasItem).is_visible_in_tree():
			said += str(child.get("text")) + "\n"
	return said


## The app's update state as it was, so the probe leaves none behind.
func _keep_state() -> void:
	for path: String in [Updater.STATE, Updater.PENDING]:
		if FileAccess.file_exists(path):
			_kept[path] = FileAccess.get_file_as_bytes(path)
	_kept["mode"] = ShellPrefs.value("updates")


func _cleanup() -> void:
	if _server > 0:
		OS.kill(_server)
	OS.unset_environment("BRICKWORKS_UPDATE_URL")
	Updates.keys_for_probe = {}
	# Nothing staged and a copy that cannot install: the app's quit runs no helper.
	_updater.set("_staged", {})
	_updater.install = Updates.here()
	_updater.state = Updater.IDLE
	for path: String in [Updater.STATE, Updater.PENDING]:
		if not _kept.has(path):
			DirAccess.remove_absolute(path)
		else:
			_put(path, _kept[path])
	ShellPrefs.put("updates", _kept.get("mode"))
	if not _root.is_empty():
		_remove(_root)


func _remove(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	for name: String in DirAccess.get_directories_at(folder):
		_remove(folder.path_join(name))
	DirAccess.remove_absolute(folder)


func _until(done: Callable, seconds: float) -> void:
	var began: int = Time.get_ticks_msec()
	while not bool(done.call()) and Time.get_ticks_msec() - began < seconds * 1000.0:
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("the desktop app checks, refuses what it must, downloads, and hands over the restart with the model kept")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
