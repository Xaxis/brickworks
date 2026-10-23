## Does every way of opening a model put on the baseplate exactly what the
## file holds, or else leave the model that was there under its own name and
## say why it did not open?
##
##   godot --headless --path . --script src/dev/empty_open_probe.gd
##
## In 0.5.0 and 0.6.0 (desktop060, 2026-10-23) a saved model with no parts
## said "Opened … 0 parts" and left the model before it on the baseplate, so
## a save of the model just opened wrote the other model's parts under its
## name. Here a saved house is on the baseplate each time, and then a file of
## each kind is opened by each way there is to open one:
##
##   - empty: a model the app saved with no parts in it. Opens as an empty
##     model under its own name, the window's title and the bar's name the
##     same, nothing to undo, and a save of it then writes no parts.
##   - garbled: not LDraw at all (an error page kept as .ldr); unknown: only
##     parts the library has not got; zero: no bytes. None opens: the house
##     stays, under its name, its undo as it was, and the person (or the
##     session) is told why.
##
## And with a part of the house still on its way (the web fetches most), a
## file that did not open must not take the house's place under its own name:
## the version and library opens counted parts in flight as the new model's.
## And Orthanc, laid a slice at a time as a big model is, with another model
## opened or New pressed before it is all down: that is what the baseplate
## holds, under its name, and Orthanc's open says it did not open.
##
## On 0.6.0 (c239c362) 68 checks fail: the empty file leaves the house by
## every way, a failed File › Open says nothing, and a version or library
## model that did not open renamed the house, or credited it, while a part
## of it was on its way.
extends SceneTree

const HOUSE := "Empty Open Probe House"
const EMPTY := "Empty Open Probe Empty"
const GARBLED := "Empty Open Probe Garbled"
const UNKNOWN := "Empty Open Probe Unknown"
const ZERO := "Empty Open Probe Zero"
const LINK := "Pr0beEmpty"
const BOOK := "omr-99999-1"

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _world: BrickWorld
var _builder: Builder
var _bar: ModelBar
var _shell: Shell
var _tools: AppTools
var _texts: Dictionary = {}


## A gallery that answers with the model it is given.
class FakeShared extends SharedModels:
	var text: String = ""
	var called: String = ""

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"name": called, "model": text, "version": 1}}


## The library, with one model in it: the one it is given.
class FakeLibrary extends ModelLibrary:
	var text: String = ""
	var called: String = ""

	func find(id: String) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"id": id, "name": called, "set": "", "file": "probe.ldr", "author": "Probe",
			"licence": "CCAL 2.0", "page": "https://library.ldraw.org/omr/sets/1"}

	func model_text(_entry: Dictionary, _job: Working.Job = null) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"text": text, "error": ""}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_store = _main.get("_store")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_bar = _main.get("_bar")
	_shell = _main.get("_shell")
	_store.keeps = true
	_tools = AppTools.new()
	_tools.app = _main
	_tools.assistant = _main.get("_assistant")
	var shared := FakeShared.new()
	_main.set("_shared", shared)
	var books := FakeLibrary.new()
	root.add_child(books)
	_main.set("_model_library", books)

	# The house, saved; and an empty model, saved as the app saves one.
	for name: String in [HOUSE, EMPTY, GARBLED, UNKNOWN, ZERO]:
		_forget(name)
	_store.open("res://models/house.ldr")
	_store.title = HOUSE
	_store.adopt()
	_check("the house is saved", _store.save_as(HOUSE))
	await _bar._start_new()
	_check("an empty model is saved", _store.save_as(EMPTY))
	_texts = {
		HOUSE: FileAccess.get_file_as_string(ModelStore.saved_path(HOUSE)),
		EMPTY: FileAccess.get_file_as_string(ModelStore.saved_path(EMPTY)),
		GARBLED: "<!DOCTYPE html>\n<html><body>404 Not Found</body></html>\n",
		UNKNOWN: "0 %s\n0 Name: unknown.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 nosuchpart.dat\n" % UNKNOWN,
		ZERO: "",
	}
	print("  the empty model's file: %d lines, %d parts" % [
		(_texts[EMPTY] as String).split("\n", false).size(), ModelStore.count_in(_texts[EMPTY])])

	# Every way a model is opened, each given which file to open; three of
	# them asked again while a part of the house is still on its way.
	var ways: Array = [
		["File › Open (a saved model)", _by_open_menu],
		["File › Open recent", _by_recent],
		["the reload offer (saved in another tab)", _by_reload_offer],
		["Collection › Open", _by_collection],
		["open_model name= (Claude)", _by_tool_name],
		["File › Open from a file (the desktop's dialog, the web's picker)", _by_picker],
		["File › Versions…", _by_versions_dialog],
		["open_model version= (Claude)", _by_tool_version],
		["the library (?library=, Open in a new tab)", _by_library_tab],
		["open_model library= (Claude)", _by_tool_library],
		["a shared link (Open in Brickworks)", _by_copy_link],
		["open_model link= (Claude)", _by_tool_link],
	]
	for way: Array in ways:
		print("\n%s" % way[0])
		for kind: String in [EMPTY, GARBLED, UNKNOWN, ZERO]:
			await _case(way[0], way[1], kind, false)
		# Parts of the house still on their way, then a file that will not open.
		if way[0] in ["File › Versions…", "open_model version= (Claude)",
				"the library (?library=, Open in a new tab)"]:
			await _case(way[0], way[1], GARBLED, true)

	print("\na big model opened over frames, put away before it is down")
	await _paced_case("File › Open of the house over it")
	await _paced_case("New over it")

	print("\nstart-up (the working model restored)")
	await _restore_case(EMPTY)
	await _restore_case(UNKNOWN)

	for name: String in [HOUSE, EMPTY, GARBLED, UNKNOWN, ZERO]:
		_forget(name)
	for copy: String in [EMPTY + " (copy)", EMPTY + " (copy 2)"]:
		_forget(copy)
	_done()


## The house on the baseplate, an edit of it to undo, and every file as it
## began; then [param kind] opened by [param way], and what is on the
## baseplate held to what that file holds.
func _case(way: String, open_by: Callable, kind: String, in_flight: bool) -> void:
	_write_files()
	_store.open(ModelStore.saved_path(HOUSE))
	_bar.opened.emit(_parts_on())
	# One edit, so a model left in place keeps its undo, and one opened has none.
	var first: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			first = brick
			break
	_builder.select_brick(first.id, false)
	await (_main.get("_verbs") as EditVerbs).press("delete")
	_store.adopt()
	# Saved as it is: an open asked of a tab with work not saved is refused
	# before it begins (the library's tab), or told to discard it (Claude).
	_store.save_as(HOUSE)
	var house_now: int = _parts_on()
	var house_kept: int = _file_parts(ModelStore.saved_path(HOUSE))
	var depth: int = _builder.history_depth()
	_store.write_now()
	_bar.say("")
	if in_flight:
		var coming := LdrModel.Placement.new("nosuchpart_on_its_way", 4, Transform3D.IDENTITY, 0)
		_store.awaited.append(coming)
		# Saved with it, as a model short of a part is (ModelStore._text_into).
		_store.save_as(HOUSE)
	var expect: String = _expected_name(way, _store.title)
	var said: String = str(await open_by.call(kind))
	_store.awaited = _store.awaited.filter(func(p: LdrModel.Placement) -> bool:
		return p.part_id != "nosuchpart_on_its_way")
	var name: String = _bar.model_name()
	var window: String = _main.get_window().title
	var tag: String = "%s%s" % [kind.trim_prefix("Empty Open Probe ").to_lower(),
		", parts of the house on their way" if in_flight else ""]
	if kind == EMPTY:
		var parts: int = _parts_on()
		_check("%s: opens as an empty model, %d parts on the baseplate (%s)" % [tag, parts, said.left(90)],
			parts == 0)
		_check("%s: called %s in the store, the bar and the window (%s / %s / %s)" % [tag, expect,
			_store.title, name, window],
			_store.title == expect and name == expect and window.begins_with(expect + " — "))
		_check("%s: nothing to undo into the house (%d steps)" % [tag, _builder.history_depth()],
			_builder.history_depth() == 0)
		# The model just opened saved where it came from, as a session saves
		# what it has opened: the house's parts must not go there.
		var file: String = ModelStore.saved_path(expect)
		_main.call("save_model", file)
		_check("%s: a save of it writes %d parts to its file" % [tag, _file_parts(file)],
			_file_parts(file) == 0)
		if expect != HOUSE:
			_check("%s: the house's file still holds the house (%d parts)" % [tag,
				_file_parts(ModelStore.saved_path(HOUSE))],
				_file_parts(ModelStore.saved_path(HOUSE)) == house_kept)
		if expect != EMPTY and expect != HOUSE:
			_forget(expect)
		return
	var parts: int = _parts_on()
	_check("%s: the house stays on the baseplate, %d parts of %d" % [tag, parts, house_now],
		parts == house_now)
	_check("%s: under its own name in the store, the bar and the window (%s / %s / %s)" % [tag,
		_store.title, name, window],
		_store.title == HOUSE and name == HOUSE and window.begins_with(HOUSE + " — "))
	_check("%s: its undo kept (%d steps of %d)" % [tag, _builder.history_depth(), depth],
		_builder.history_depth() == depth)
	_check("%s: and says it did not open: \"%s\"" % [tag, said.left(110)],
		said.to_lower().contains("could not") or said.to_lower().contains("not open")
			or said.to_lower().contains("no model") or said.to_lower().contains("not an ldraw")
			or said.to_lower().contains("none of"))


## Orthanc, laid a slice at a time as File › Open lays a big model, and
## [param then] done while it is being laid: whatever was done is what the
## baseplate holds, under its name, and the open says it did not open.
func _paced_case(then: String) -> void:
	_write_files()
	_store.open(ModelStore.saved_path(HOUSE))
	_bar.opened.emit(_parts_on())
	var house_parts: int = _parts_on()
	_bar.say("")
	var answer: Array = []
	_open_into_answer("res://models/orthanc.ldr", answer)
	for _n: int in 600:
		if _store.laying or not answer.is_empty():
			break
		await process_frame
	var caught: bool = _store.laying
	if then.begins_with("New"):
		await _bar._start_new()
	else:
		await _by_open_menu(HOUSE)
	var said_now: String = _bar.status_text()
	for _n: int in 600:
		if not answer.is_empty():
			break
		await process_frame
	var said: String = _bar.status_text()
	var expect: String = ModelStore.UNTITLED if then.begins_with("New") else HOUSE
	var parts: int = _parts_on()
	_check("%s: caught while Orthanc was being laid" % then, caught)
	_check("%s: Orthanc's open says it did not open (answered %s): \"%s\"" % [then,
		str(answer[0]) if not answer.is_empty() else "nothing", said.left(100)],
		not answer.is_empty() and int(answer[0]) < 0 and said.contains("orthanc"))
	_check("%s: the baseplate holds %d parts, as it should %d" % [then, parts,
		0 if expect == ModelStore.UNTITLED else house_parts],
		parts == (0 if expect == ModelStore.UNTITLED else house_parts))
	_check("%s: called %s in the store, the bar and the window (%s / %s / %s; said %s)" % [then,
		expect, _store.title, _bar.model_name(), _main.get_window().title, said_now.left(60)],
		_store.title == expect and _bar.model_name() == expect
			and _main.get_window().title.begins_with(expect + " — "))
	_check("%s: nothing to undo into Orthanc (%d steps)" % [then, _builder.history_depth()],
		_builder.history_depth() == 0)


func _open_into_answer(path: String, answer: Array) -> void:
	answer.append(await _bar.open_with_progress(path))


## The name a model opened by [param way] goes under: a link's copy is saved
## under a name of its own, a version under its model's.
func _expected_name(way: String, before: String) -> String:
	if way.begins_with("a shared link") or way.begins_with("open_model link="):
		return _store.unused_name(EMPTY)
	if way == "File › Versions…":
		return before
	return EMPTY


# -- the ways --------------------------------------------------------------------


func _by_open_menu(kind: String) -> String:
	_bar.set("_entries", _store.list_saved())
	var entries: Array = _bar.get("_entries")
	for n: int in entries.size():
		if (entries[n] as ModelStore.Entry).path == ModelStore.saved_path(kind):
			await _bar._on_pick(n)
			return _bar.status_text()
	return "(not listed)"


func _by_recent(kind: String) -> String:
	var recent: Array[ModelStore.Entry] = _store.list_saved()
	_shell.set("_recent", recent)
	for n: int in recent.size():
		if recent[n].path == ModelStore.saved_path(kind):
			await _shell._open_recent(null, n)
			return _bar.status_text()
	return "(not listed)"


func _by_reload_offer(kind: String) -> String:
	var offer: ReloadOffer = _main.get("_reload_offer")
	await offer.reopen.call(ModelStore.saved_path(kind))
	return _bar.status_text()


func _by_collection(kind: String) -> String:
	var dialog: CollectionDialog = _shell.collection
	var said: Array = [""]
	var hear: Callable = func(text: String) -> void: said[0] = text
	dialog.said.connect(hear)
	await dialog._open_candidate({"path": ModelStore.saved_path(kind)})
	dialog.said.disconnect(hear)
	dialog.visible = false
	return str(said[0]) + " " + _bar.status_text()


func _by_tool_name(kind: String) -> String:
	return str(await _tools.run("open_model", {"name": kind, "discard_changes": true}))


func _by_picker(kind: String) -> String:
	_bar._import()
	var picker: ModelFilePicker = _bar.get("_picker")
	var dialog: FileDialog = picker.get("_dialog")
	if dialog != null:
		dialog.hide()
	var before: int = _world.revision
	picker.take(FileAccess.get_file_as_bytes(ModelStore.saved_path(kind)), kind + ".ldr")
	for _n: int in 60:
		await process_frame
	if _world.revision == before:
		for _n: int in 60:
			await process_frame
	return _bar.status_text()


## A version of the house that is [param kind], opened from File, Versions….
func _by_versions_dialog(kind: String) -> String:
	var version: ModelVersions.Version = _kept_version(HOUSE, kind)
	if version == null:
		return "(no version kept)"
	var dialog: VersionsDialog = _shell.versions
	dialog.set("_shown", [version] as Array[ModelVersions.Version])
	await dialog._open_version(0)
	return _bar.status_text()


## A version of the empty model that is [param kind], opened by a session.
func _by_tool_version(kind: String) -> String:
	var version: ModelVersions.Version = _kept_version(EMPTY, kind)
	if version == null:
		return "(no version kept)"
	var kept: Array[ModelVersions.Version] = ModelVersions.of(EMPTY)
	return str(await _tools.run("open_model", {"name": EMPTY, "version": kept.find_custom(
		func(v: ModelVersions.Version) -> bool: return v.path == version.path) + 1,
		"discard_changes": true}))


func _by_library_tab(kind: String) -> String:
	_set_library(kind)
	_main.set("_from_library", BOOK)
	await _main.call("_maybe_open_library")
	return _bar.status_text()


func _by_tool_library(kind: String) -> String:
	_set_library(kind)
	return str(await _tools.run("open_model", {"library": BOOK, "discard_changes": true}))


func _by_copy_link(kind: String) -> String:
	_set_shared(kind)
	_main.set("_copying", LINK)
	_main.set("_copy_started", false)
	_main.set("_first_open_done", true)
	(_main.get("_account") as Account).state = Account.State.NOT_NEEDED
	await _main.call("_maybe_copy")
	_main.set("_copying", "")
	return _bar.status_text()


func _by_tool_link(kind: String) -> String:
	_set_shared(kind)
	return str(await _tools.run("open_model", {"link": LINK, "discard_changes": true}))


func _set_library(kind: String) -> void:
	var books: FakeLibrary = _main.get("_model_library")
	books.text = _texts[kind]
	books.called = kind


func _set_shared(kind: String) -> void:
	var shared: FakeShared = _main.get("_shared")
	shared.text = _texts[kind]
	shared.called = kind


## The working model of the last session [param kind], restored on an empty
## baseplate as the window starts.
func _restore_case(kind: String) -> void:
	_world.clear()
	_builder.lattice.clear()
	_store.scenery.clear()
	_store.title = ModelStore.UNTITLED
	var file: FileAccess = FileAccess.open(ModelStore.autosave(), FileAccess.WRITE)
	file.store_string(_texts[kind])
	file.close()
	var back: int = await _store.restore_fetched()
	var tag: String = kind.trim_prefix("Empty Open Probe ").to_lower()
	if kind == EMPTY:
		_check("%s: begun again empty, under its name (%s, %d parts)" % [tag, _store.title, back],
			back == 0 and _store.left_empty and _store.title == EMPTY and _parts_on() == 0)
	else:
		_check("%s: kept where the person finds it, and said: %s" % [tag, _store.unrestored.left(100)],
			back == 0 and not _store.unrestored.is_empty())
		_forget(UNKNOWN + " - could not open")


# -- the files -------------------------------------------------------------------


## Every file as it began: a way that wrote over one must not mislead the next.
func _write_files() -> void:
	for name: String in [HOUSE, EMPTY, GARBLED, UNKNOWN, ZERO]:
		var file: FileAccess = FileAccess.open(ModelStore.saved_path(name), FileAccess.WRITE)
		file.store_string(_texts[name])
		file.close()


## A version of the model saved as [param stem] whose text is [param kind]'s.
func _kept_version(stem: String, kind: String) -> ModelVersions.Version:
	var text: String = _texts[kind]
	var path: String = ModelVersions.keep(stem, text)
	if path.is_empty():
		for version: ModelVersions.Version in ModelVersions.of(stem):
			if ModelVersions.read(version.path) == text:
				return version
		# ModelVersions.keep keeps nothing of no bytes: one written as it would be.
		DirAccess.make_dir_recursive_absolute(ModelVersions.folder(stem))
		path = ModelVersions.folder(stem) + "%013d-0-0.ldr.gz" % int(Time.get_unix_time_from_system() * 1000.0)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
		file.close()
	for version: ModelVersions.Version in ModelVersions.of(stem):
		if version.path == path:
			return version
	return null


func _forget(name: String) -> void:
	DirAccess.remove_absolute(ModelStore.saved_path(name))
	var folder: String = ModelVersions.folder(ModelStore._safe_name(name))
	if DirAccess.dir_exists_absolute(folder):
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + file)
		DirAccess.remove_absolute(folder)


func _parts_on() -> int:
	return _world.brick_count() - _store.scenery.size()


func _file_parts(path: String) -> int:
	return ModelStore.count_in(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else -1


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("every open puts down what the file holds, or leaves the model there under its name and says why")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
