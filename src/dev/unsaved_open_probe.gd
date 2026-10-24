## Does any way of opening a model over one with changes not saved lose
## those changes?
##
##   godot --headless --path . --script src/dev/unsaved_open_probe.gd
##
## walk180 (2026-10-23, D6 and A11): on desktop 0.6.0 and the live web app,
## File › Open and a saved model or an example put it in place of a model of
## 254 parts not saved, with no question, Undo greyed and History saying
## "nothing to go back to yet"; the work was in no file. File › New asked.
##
## Here a saved boat has a part taken off, not saved, before each open, and
## each way a person opens a model over it is answered each way:
##
##   - Cancel: the boat stays, as it was, its undo too.
##   - Don't save: the other model is opened; Undo (and History) bring the
##     boat back as it stood, and Redo the other model again.
##   - Save: the boat is saved as it stood first, then the other opens.
##
## The ways: File › Open of a saved model and of an example, Open recent, a
## file from the computer (the desktop's dialog, the web's picker),
## Collection › Open and File › Versions…. The reload offer (another tab
## saved the model) asks nothing, as Reload is the answer to a question, but
## Undo brings back what it replaced. And Claude's open_model: refused over
## the person's changes, and with discard_changes=true, undone by undo.
##
## With `-- --picture=FILE.png` (in a window) the question is pictured as asked.
##
## On base (rel-m155, 25312917) every way opens without asking, Cancel and
## Save are never offered, and Undo has nothing to undo.
extends SceneTree

const BOAT := "Unsaved Probe Boat"
const CAR := "Unsaved Probe Car"

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _world: BrickWorld
var _builder: Builder
var _bar: ModelBar
var _shell: Shell
var _verbs: EditVerbs
var _tools: AppTools
var _boat_text: String = ""
var _car_text: String = ""
var _boat_parts: int = 0
var _car_parts: int = 0
var _shot: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--picture="):
			_shot = argument.trim_prefix("--picture=")
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
	_verbs = _main.get("_verbs")
	_store.keeps = true
	_tools = AppTools.new()
	_tools.app = _main
	_tools.assistant = _main.get("_assistant")

	_forget(BOAT)
	_forget(CAR)
	_store.open("res://models/boat.ldr")
	_store.adopt()
	_check("the boat is saved", _store.save_as(BOAT))
	_boat_parts = _parts_on()
	_store.open("res://models/car.ldr")
	_check("the car is saved", _store.save_as(CAR))
	_car_parts = _parts_on()
	_boat_text = FileAccess.get_file_as_string(ModelStore.saved_path(BOAT))
	_car_text = FileAccess.get_file_as_string(ModelStore.saved_path(CAR))
	print("  the boat: %d parts; the car: %d" % [_boat_parts, _car_parts])

	var example: ModelStore.Entry = null
	for entry: ModelStore.Entry in _store.list_examples():
		if entry.path.ends_with("kart.ldr"):
			example = entry
	var ways: Array = [
		["File › Open, a saved model", _by_open_menu.bind(ModelStore.saved_path(CAR)), CAR],
		["File › Open, an example", _by_open_menu.bind(example.path), example.name],
		["File › Open recent", _by_recent, CAR],
		["File › Open from a file (the desktop's dialog, the web's picker)", _by_picker, CAR],
		["Collection › Open", _by_collection, CAR],
		["File › Versions…", _by_versions, BOAT],
	]
	for way: Array in ways:
		print("\n%s" % way[0])
		for answer: String in ["cancel", "discard", "save"]:
			await _case(way[0], way[1], answer, way[2])

	print("\nafter a still moment: the autosave written as the boat stands")
	await _still_case()
	print("\nnothing to lose: a file opened and not changed since")
	await _untouched_case()
	print("\nthe working model restored at start-up, never saved as it is")
	await _restored_case()
	print("\nthe reload offer (another tab saved the boat)")
	await _reload_case()
	print("\nopen_model (Claude)")
	await _tool_case()

	_forget(BOAT)
	_forget(CAR)
	_done()


## The boat on the baseplate, saved, with a part taken off since; then
## [param way] opens [param target] over it and the question is answered
## [param answer].
func _case(way: String, open_by: Callable, answer: String, target: String) -> void:
	var edited: int = await _boat_edited()
	var depth: int = _builder.history_depth()
	var asked: Dictionary = await _drive(open_by, answer)
	var tag: String = answer if answer != "discard" else "don't save"
	_check("%s: asked first (%s), the boat still there while asked (%d parts of %d)" % [
		tag, asked["title"] if not str(asked["title"]).is_empty() else "nothing asked",
		int(asked["parts_asked"]), edited],
		str(asked["title"]) == "Save changes to “%s”?" % BOAT and int(asked["parts_asked"]) == edited)
	if _shot.is_empty() == false and way.begins_with("File › Open, a saved") and answer == "cancel":
		print("  (pictured in %s)" % _shot)
	match answer:
		"cancel":
			_check("cancel: the boat stays as it was, %d parts of %d, its undo kept (%d of %d), under its name (%s)"
				% [_parts_on(), edited, _builder.history_depth(), depth, _store.title],
				_parts_on() == edited and _builder.history_depth() == depth and _store.title == BOAT)
		"discard":
			var opened: int = _parts_on()
			_check("don't save: %s opened in its place (%s, %d parts)" % [target, _store.title, opened],
				_store.title == target and (opened == _boat_parts if target == BOAT else opened != edited))
			var rows: PackedStringArray = _history_rows()
			_check("don't save: Undo can be pressed (%s), and History lists the open: %s" % [
				_shell.can("undo"), " | ".join(rows)],
				_shell.can("undo") and not rows.is_empty() and rows[rows.size() - 1].contains("opened"))
			await _verbs.press("undo")
			await _settle()
			_check("don't save, Undo: the boat back as it stood, %d parts of %d, as %s (said \"%s\")" % [
				_parts_on(), edited, _store.title, _bar.status_text()],
				_parts_on() == edited and _store.title == BOAT)
			_check("...and it is still not saved: the boat's file has %d parts" % _file_parts(BOAT),
				_file_parts(BOAT) == _boat_parts and _store.has_unsaved_work())
			_check("don't save, Undo, Redo can be pressed (%s)" % _shell.can("redo"), _shell.can("redo"))
			await _verbs.press("redo")
			await _settle()
			_check("don't save, Undo, Redo: %s again, %d parts of %d" % [_store.title, _parts_on(), opened],
				_store.title == target and _parts_on() == opened)
		"save":
			_check("save: the boat saved first as it stood, %d parts in its file of %d" % [
				_file_parts(BOAT), edited], _file_parts(BOAT) == edited)
			_check("save: then %s opened (%s, %d parts)" % [target, _store.title, _parts_on()],
				_store.title == target and (_parts_on() != edited or target == BOAT))


## The boat changed, then left a moment, as a person does choosing what to
## open: the autosave holds it as it stands, and is what the open keeps.
func _still_case() -> void:
	var edited: int = await _boat_edited()
	var since: int = Time.get_ticks_msec()
	while (bool(_store.get("_pending")) or bool(_store.get("_autosaving"))) \
			and Time.get_ticks_msec() - since < 20000:
		await process_frame
	var autosaved: int = ModelStore.count_in(FileAccess.get_file_as_string(ModelStore.autosave()))
	_check("the autosave written as the boat stands, %d parts of %d" % [autosaved, edited],
		autosaved == edited)
	await _drive(_by_open_menu.bind(ModelStore.saved_path(CAR)), "discard")
	_check("Don't save: the car open (%s)" % _store.title, _store.title == CAR)
	await _verbs.press("undo")
	await _settle()
	_check("Undo: the boat back as it stood, %d parts of %d, as %s" % [_parts_on(), edited,
		_store.title], _parts_on() == edited and _store.title == BOAT)


## A file from the computer opened, then another over it, nothing done in
## between: nothing would be lost, so nothing is asked (a run of files opened
## one after another was asked about each), and Undo still brings it back.
func _untouched_case() -> void:
	await _boat_edited()
	_store.save_as(BOAT)
	var first: Dictionary = await _drive(_by_picker, "cancel")
	_check("the car from a file over the boat just saved: nothing asked (%s), %s open" % [
		first["title"], _store.title], str(first["title"]).is_empty() and _parts_on() == _car_parts)
	var picker: ModelFilePicker = _bar.get("_picker")
	var title: String = _store.title
	var revision: int = _world.revision
	var again: Callable = func() -> void:
		picker.take(_boat_text.to_utf8_buffer(), "elsewhere.ldr")
		for _n: int in 400:
			if _world.revision != revision and _store.title != title and not _store.laying:
				break
			await process_frame
	var asked: Dictionary = await _drive(again, "cancel")
	_check("the boat from a file over it, untouched: nothing asked (%s), %d parts open" % [
		asked["title"], _parts_on()], str(asked["title"]).is_empty() and _parts_on() == _boat_parts)
	await _verbs.press("undo")
	await _settle()
	_check("Undo: the car back (%s, %d parts)" % [_store.title, _parts_on()], _parts_on() == _car_parts)


## The working model of the last session, restored as the window starts and
## changed from its save: it is nowhere else, so an open over it asks.
func _restored_case() -> void:
	await _boat_edited()
	var text: String = ModelStore.with_share(_store.to_text(BOAT), "", "", 0, {})
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_store.scenery.clear()
	var file: FileAccess = FileAccess.open(ModelStore.autosave(), FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var back: int = await _store.restore_fetched()
	_bar.opened.emit(back)
	await _settle()
	var asked: Dictionary = await _drive(_by_open_menu.bind(ModelStore.saved_path(CAR)), "cancel")
	_check("restored (%d parts, %s), File › Open asks: %s" % [back, _store.title,
		asked["title"] if not str(asked["title"]).is_empty() else "nothing asked"],
		str(asked["title"]) == "Save changes to “%s”?" % BOAT and _store.title == BOAT)


## The reload offer reopens the boat's file as another tab saved it: no
## question, and Undo brings back the boat as this tab had it.
func _reload_case() -> void:
	var edited: int = await _boat_edited()
	var offer: ReloadOffer = _main.get("_reload_offer")
	var reload: Callable = func() -> void:
		await offer.reopen.call(ModelStore.saved_path(BOAT))
	var asked: Dictionary = await _drive(reload, "cancel")
	_check("reload: asks nothing, it is the answer (%s)" % asked["title"], str(asked["title"]).is_empty())
	_check("reload: the boat as saved, %d parts of %d" % [_parts_on(), _boat_parts], _parts_on() == _boat_parts)
	await _verbs.press("undo")
	await _settle()
	_check("reload, Undo: the boat as this tab had it, %d parts of %d (said \"%s\")" % [_parts_on(), edited,
		_bar.status_text()], _parts_on() == edited and _store.title == BOAT)


## Claude's open_model: refused over the person's changes, and opened when
## told to discard them, which undo takes back.
func _tool_case() -> void:
	var edited: int = await _boat_edited()
	var said: String = str(await _tools.run("open_model", {"name": CAR}))
	_check("refused, the boat kept (%d parts of %d): \"%s\"" % [_parts_on(), edited, said.left(150)],
		_parts_on() == edited and _store.title == BOAT and said.contains("not saved")
		and said.contains("discard_changes"))
	said = str(await _tools.run("open_model", {"name": CAR, "discard_changes": true}))
	_check("discard_changes=true: the car opened, %d parts, and said so: \"%s\"" % [_parts_on(), said.left(200)],
		_store.title == CAR and _parts_on() == _car_parts and said.contains("undo brings it back"))
	said = str(await _tools.run("undo", {}))
	await _settle()
	_check("undo: the boat back as it stood, %d parts of %d: \"%s\"" % [_parts_on(), edited, said.left(150)],
		_parts_on() == edited and _store.title == BOAT and said.begins_with("Undid opened"))
	said = str(await _tools.run("undo", {"redo": true}))
	await _settle()
	_check("undo redo=true: the car again, %d parts: \"%s\"" % [_parts_on(), said.left(150)],
		_store.title == CAR and _parts_on() == _car_parts)


## Every file as it began, the boat opened from its own and a part of it
## taken off, not saved. How many parts are on the baseplate then.
func _boat_edited() -> int:
	for named: Array in [[BOAT, _boat_text], [CAR, _car_text]]:
		var file: FileAccess = FileAccess.open(ModelStore.saved_path(named[0]), FileAccess.WRITE)
		file.store_string(named[1])
		file.close()
	await _bar.open_with_progress(ModelStore.saved_path(BOAT))
	_bar.opened.emit(_parts_on())
	await _settle()
	var first: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			first = brick
			break
	_builder.select_brick(first.id, false)
	await _verbs.press("delete")
	_store.adopt()
	_bar.say("")
	return _parts_on()


## [param open_by] run, the question answered [param answer] if it is asked:
## {title: the question's title or "", parts_asked: the parts on the
## baseplate while it was asked}.
func _drive(open_by: Callable, answer: String) -> Dictionary:
	var state: Dictionary = {"done": false}
	var going: Callable = func() -> void:
		await open_by.call()
		state["done"] = true
	going.call()
	var dialog: ConfirmationDialog = null
	for _n: int in 240:
		dialog = _asking()
		if dialog != null or bool(state["done"]):
			break
		await process_frame
	var out: Dictionary = {"title": dialog.title if dialog != null else "", "parts_asked": _parts_on()}
	if dialog != null:
		if not _shot.is_empty() and answer == "cancel" and not FileAccess.file_exists(_shot):
			for _n: int in 10:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(_shot)
		match answer:
			"save":
				dialog.get_ok_button().pressed.emit()
			"cancel":
				dialog.get_cancel_button().pressed.emit()
			"discard":
				for button: Button in dialog.find_children("*", "Button", true, false):
					if button.text == "Don't save":
						button.pressed.emit()
	for _n: int in 600:
		if bool(state["done"]):
			break
		await process_frame
	await _settle()
	return out


## The question an open asks, while it is showing.
func _asking() -> ConfirmationDialog:
	for found: Node in root.find_children("*", "ConfirmationDialog", true, false):
		var dialog: ConfirmationDialog = found
		if dialog.visible and not dialog is FileDialog and dialog.title.begins_with("Save changes"):
			return dialog
	return null


## What Edit › History lists now, newest first.
func _history_rows() -> PackedStringArray:
	var menu := PopupMenu.new()
	_shell._fill_history(menu)
	var rows := PackedStringArray()
	for n: int in menu.item_count:
		rows.append(menu.get_item_text(n))
	menu.free()
	return rows


func _settle() -> void:
	for _n: int in 20:
		if not _store.laying:
			break
		await process_frame
	for _n: int in 5:
		await process_frame


# -- the ways --------------------------------------------------------------------


func _by_open_menu(path: String) -> void:
	var entries: Array[ModelStore.Entry] = _store.list_saved() + _store.list_examples()
	_bar.set("_entries", entries)
	for n: int in entries.size():
		if entries[n].path == path:
			await _bar._on_pick(n)
			return
	print("  (%s not listed)" % path)


func _by_recent() -> void:
	var recent: Array[ModelStore.Entry] = _store.list_saved()
	_shell.set("_recent", recent)
	for n: int in recent.size():
		if recent[n].path == ModelStore.saved_path(CAR):
			await _shell._open_recent(null, n)
			return
	print("  (not listed)")


func _by_picker() -> void:
	_bar._import()
	var picker: ModelFilePicker = _bar.get("_picker")
	var dialog: FileDialog = picker.get("_dialog")
	if dialog != null:
		dialog.hide()
	var revision: int = _world.revision
	var title: String = _store.title
	picker.take(_car_text.to_utf8_buffer(), CAR + ".ldr")
	# The open goes on in the picker's own handler: done once the model has
	# changed, or long after the question was answered.
	for _n: int in 400:
		if _asking() == null and (_world.revision != revision and not _store.laying
				and _store.title != title):
			break
		await process_frame


func _by_collection() -> void:
	var dialog: CollectionDialog = _shell.collection
	await dialog._open_candidate({"path": ModelStore.saved_path(CAR), "name": CAR})
	dialog.visible = false


## The boat's first save, the one with every part, from File › Versions….
func _by_versions() -> void:
	var first: ModelVersions.Version = null
	for version: ModelVersions.Version in ModelVersions.of(ModelStore._safe_name(BOAT)):
		if version.parts == _boat_parts:
			first = version
	var dialog: VersionsDialog = _shell.versions
	dialog.set("_shown", [first] as Array[ModelVersions.Version])
	await dialog._open_version(0)


# -- the files -------------------------------------------------------------------


func _forget(name: String) -> void:
	DirAccess.remove_absolute(ModelStore.saved_path(name))
	var folder: String = ModelVersions.folder(ModelStore._safe_name(name))
	if DirAccess.dir_exists_absolute(folder):
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + file)
		DirAccess.remove_absolute(folder)


func _parts_on() -> int:
	return _world.brick_count() - _store.scenery.size()


func _file_parts(name: String) -> int:
	var path: String = ModelStore.saved_path(name)
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
		print("no open loses the changes not saved: each asks, Cancel keeps them, Save saves them, and Undo brings back what Don't save replaced")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
