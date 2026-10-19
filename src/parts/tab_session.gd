## Which tab this is — or, on the desktop, which window — and where its own
## working state is kept.
##
## Everything under user:// is shared: by every tab of the site in a
## browser (it is the site's IndexedDB), and by every window of the app on
## a computer (it is one folder). The person's saved models and settings
## are shared on purpose. The model on the baseplate is not: two tabs each
## restored the one autosave and wrote it in turn, so both reopened the
## same model, under the name of whichever wrote last, and the connector's
## address was one per browser, so a second tab switching it on took it
## from the first (2026-10-13).
##
## So each tab has a short id of its own, and its working model and its
## Claude connector live under user://sessions/<id>/. On the web the page
## chooses it before the engine starts (src/boot/shell.html): kept in
## sessionStorage, which a reload keeps and no other tab has, and held with
## a Web Lock while the page is open. On the desktop a window holds one by
## a lock folder with its process id in it ([method _hold]). A tab or
## window with none of its own takes the most recently used one nobody
## holds — so closing the browser, or the app, and coming back opens what
## was there, as it always did — and otherwise starts a new one.
##
## File, New tab (New window on the desktop) opens one on a new model
## ([method open_another]): it takes a new id at once, never one another
## left, and begins on an empty baseplate. There was no way to start a
## second model from the app: a person had to open the site again
## themselves, and that tab came up on an older model nobody held.
##
## The id is also what Claude is shown: every tab with the connector on is
## a target of its own, called by this id and its model's name (api/mcp.js).
class_name TabSession
extends RefCounted

const ROOT := "user://sessions/"
## What an id looks like: lowercase letters and digits that cannot be
## misread for one another (no i, l, o, 0 or 1).
const SHAPE := "^[a-z2-9]{4,12}$"
const LETTERS := "abcdefghjkmnpqrstuvwxyz23456789"
## Where the working model and the connector were kept before each tab
## had its own: taken by the first tab to open, once.
const LEGACY_AUTOSAVE := "user://autosave.ldr"
const LEGACY_CONNECTOR := "user://claude_connector.json"
## A window's hold is good while it has said so within this long (it says
## so every minute, Main): a window that crashed lets its session go after
## three minutes, and at once where the system can say its process has gone.
const HELD_FOR_S := 180
## What a window opened by New window is started with: a session of its
## own, not one another window left. The web's is ?new in the address.
const NEW_WINDOW := "--new-session"

static var _id: String = ""
## A run driven from the command line (a design, a render, a benchmark) is
## nobody's window: it holds no session and moves nothing. Main sets this
## before anything asks.
static var driven: bool = false


## This tab's id, chosen the first time anything asks.
static func id() -> String:
	if _id.is_empty():
		_claim()
	return _id


## Be [param given] rather than choose: for a probe playing several tabs
## in one process, each with its own working state.
static func use(given: String) -> void:
	_id = given


## This tab or window was opened by New tab or New window: it begins on an
## empty baseplate (Main), not on the sample a first visit is shown.
static func opened_new() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("window.brickworksTabNew === true", true))
	return OS.get_cmdline_user_args().has(NEW_WINDOW)


## File, New tab: the app again in a tab of its own, on a new model, this
## one left as it is. Opened in the click itself, since a browser lets a
## page open a tab only in answer to one (Shell.IN_THE_PRESS); noopener,
## so the two pages do not share one thread. On the desktop, New window:
## the app started again ([method window_arguments]).
static func open_another() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(() => {
				const there = new URL(location.href);
				there.search = "?new=1";
				there.hash = "";
				window.open(there.href, "_blank", "noopener");
			})();
		""", true)
		return
	var pid: int = OS.create_instance(window_arguments())
	if pid <= 0:
		push_warning("could not start another window")


## How New window starts the app again: as this one draws, from the same
## project when it runs from source, and with a session of its own. Not this
## run's own switches (a model to open, a port, a script): the new window is
## the app as it opens for anyone, on a new model.
static func window_arguments() -> PackedStringArray:
	var arguments := PackedStringArray()
	if not OS.has_feature("template"):
		arguments.append_array(["--path", ProjectSettings.globalize_path("res://")])
	if DisplayServer.get_name() == "headless":
		arguments.append("--headless")
	else:
		arguments.append_array([
			"--rendering-driver", RenderingServer.get_current_rendering_driver_name(),
			"--rendering-method", RenderingServer.get_current_rendering_method()])
	arguments.append_array(["--", NEW_WINDOW])
	return arguments


## Where else a model is saved from, in words: another tab in a browser,
## another window on the desktop.
static func elsewhere() -> String:
	return "another tab" if OS.has_feature("web") else "another window"


## A file of this tab's own.
static func path(file: String) -> String:
	return ROOT + id() + "/" + file


## Where this tab's working model is kept (ModelStore).
static func autosave() -> String:
	return path("autosave.ldr")


static func shaped(text: String) -> bool:
	return RegEx.create_from_string(SHAPE).search(text) != null


static func fresh_id() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(5)
	var made: String = ""
	for byte: int in bytes:
		made += LETTERS[byte % LETTERS.length()]
	return made


static func _claim() -> void:
	var takes_legacy: bool = false
	if OS.has_feature("web"):
		var given: Variant = JavaScriptBridge.eval("window.brickworksTab || ''", true)
		_id = str(given) if given != null and shaped(str(given)) else fresh_id()
		takes_legacy = bool(JavaScriptBridge.eval("window.brickworksTabLegacy === true", true))
	elif driven or OS.get_cmdline_args().has("--script"):
		# A probe, or a run driven from the command line, is nobody's
		# window: it holds nothing, and it leaves the working state from
		# before alone — a design run had otherwise taken the session the
		# person's next window would have opened.
		_id = "probe"
	else:
		_id = _claim_here(not opened_new())
		takes_legacy = not opened_new()
	DirAccess.make_dir_recursive_absolute(ROOT + _id)
	if takes_legacy:
		_move(LEGACY_AUTOSAVE, autosave())
		_move(LEGACY_CONNECTOR, path("claude_connector.json"))


## The old file into this tab's folder, unless this tab has one already.
## A rename, so a second window starting at the same moment finds it gone.
static func _move(from: String, to: String) -> void:
	if not FileAccess.file_exists(from) or FileAccess.file_exists(to):
		return
	DirAccess.rename_absolute(from, to)


## A window's session: the newest nobody holds, or a new one. Only a new
## one when not [param reclaim] (New window).
static func _claim_here(reclaim: bool = true) -> String:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var free: Array = []
	for name: String in DirAccess.get_directories_at(ROOT) if reclaim else PackedStringArray():
		if shaped(name) and not _held(name):
			free.append([_latest(name), name])
	free.sort()
	free.reverse()
	for pair: Array in free:
		if _hold(str(pair[1])):
			return str(pair[1])
	for tries: int in 50:
		var made: String = fresh_id()
		if not DirAccess.dir_exists_absolute(ROOT + made) and _hold(made):
			return made
	return fresh_id()


## When anything in a session was last written.
static func _latest(name: String) -> int:
	var newest: int = 0
	for file: String in DirAccess.get_files_at(ROOT + name):
		newest = maxi(newest, FileAccess.get_modified_time(ROOT + name + "/" + file))
	return newest


static func _held(name: String) -> bool:
	var pid_file: String = ROOT + name + "/held/pid"
	if not FileAccess.file_exists(pid_file):
		# A hold with no id in it is not one this app makes; an empty folder
		# is gone over by the rename in _hold.
		return false
	var pid: int = FileAccess.get_file_as_string(pid_file).strip_edges().to_int()
	if pid <= 0 or pid == OS.get_process_id():
		return false
	# Not OS.is_process_running: it knows only processes this one started,
	# and called every other window's hold gone, so two windows took one.
	if DirAccess.dir_exists_absolute("/proc/self") and not DirAccess.dir_exists_absolute("/proc/%d" % pid):
		return false
	return Time.get_unix_time_from_system() - FileAccess.get_modified_time(pid_file) < HELD_FOR_S


## Take [param name] for this window. The hold is a folder with this
## process's id already in it, renamed into place: a rename onto a folder
## that holds something fails, so two windows cannot both succeed, and no
## other window ever sees a hold without its id. (A hold made empty first
## and its id written after was read as left over by a window that had
## gone, in that moment, and two windows starting together both took it.)
static func _hold(name: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ROOT + name)
	var lock: String = ROOT + name + "/held"
	var mine: String = ROOT + name + "/held-%d" % OS.get_process_id()
	DirAccess.make_dir_absolute(mine)
	var file: FileAccess = FileAccess.open(mine + "/pid", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(str(OS.get_process_id()))
	file.close()
	var took: bool = DirAccess.rename_absolute(mine, lock) == OK
	if not took and not _held(name):
		# Left by a window that has gone.
		DirAccess.remove_absolute(lock + "/pid")
		DirAccess.remove_absolute(lock)
		took = DirAccess.rename_absolute(mine, lock) == OK
	if not took:
		DirAccess.remove_absolute(mine + "/pid")
		DirAccess.remove_absolute(mine)
		return false
	_id = name
	return true


## Say this window still holds its session. Called now and then while it
## runs (Main); nothing on the web, where the page's lock does it.
static func still_here() -> void:
	if OS.has_feature("web") or _id.is_empty() or _id == "probe":
		return
	if not DirAccess.dir_exists_absolute(ROOT + _id + "/held"):
		return
	var file: FileAccess = FileAccess.open(ROOT + _id + "/held/pid", FileAccess.WRITE)
	if file != null:
		file.store_string(str(OS.get_process_id()))
		file.close()


## Let it go as the window closes, so the next one to open takes it at once.
static func release() -> void:
	if OS.has_feature("web") or _id.is_empty() or _id == "probe":
		return
	DirAccess.remove_absolute(ROOT + _id + "/held/pid")
	DirAccess.remove_absolute(ROOT + _id + "/held")


## Files another tab stored since this one last asked, copied into this
## tab's user:// by the page: [{path (user://…), gone}]. Always empty on the
## desktop, where every window reads the one folder.
static func changed_elsewhere() -> Array:
	if not OS.has_feature("web"):
		return []
	var said: Variant = JavaScriptBridge.eval(
		"window.brickworksTakeChanges ? window.brickworksTakeChanges() : '[]'", true)
	var parsed: Variant = JSON.parse_string(str(said)) if said != null else null
	var found: Array = []
	if not parsed is Array:
		return found
	var root: String = ProjectSettings.globalize_path("user://")
	if not root.ends_with("/"):
		root += "/"
	for change: Variant in parsed as Array:
		if not change is Dictionary:
			continue
		var at: String = str((change as Dictionary).get("path", ""))
		if not at.begins_with(root):
			continue
		found.append({"path": "user://" + at.substr(root.length()),
			"gone": bool((change as Dictionary).get("gone", false))})
	return found


## A write that is not a save (a setting, the parts bin's shelf), so the
## page does not copy another tab's over it before this one is stored.
static func writing(path: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.brickworksWriting && window.brickworksWriting(%s)"
		% JSON.stringify(ProjectSettings.globalize_path(path)), true)
