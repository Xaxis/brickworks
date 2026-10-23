## Does every export ask where to save, on the desktop, and say where it went?
##
##   godot --path . --resolution 1400x900 --script src/dev/save_dialog_probe.gd
##
## Needs a window: the picture and the booklet are drawn. With
## `-- --shots=DIR` it leaves pictures of the dialogs and of the status
## line there, to look at.
##
## walk180 (2026-10-23) on desktop 0.6.0: Export (.io) and Instructions
## wrote straight into ~/Downloads with no dialog; Instructions handed a
## 4.5 MB page to a browser that was not there, and "nothing happened"
## three times; Save as named a copy in the app's own folder only. So this
## presses each as a person does, from the menus and the parts list, and
## answers the dialog that comes up, as a person would:
##
##   does each open a Save dialog, in Documents the first time and in the
##   folder the last file went to after, with the model's name filled in?
##   is the file then where it was put, and whole?
##   does the status bar say where, with Show in folder, and does that
##   show the file?
##   does a file already there get the overwrite question, and is it kept
##   when the answer is no? does Cancel write nothing?
##   does Save as write the file chosen, and Save write it again?
##   does Instructions open the booklet in the browser and say so, and
##   where no browser can be opened, say where the file is?
##
## The dialog here is Godot's own (SaveTo.native off): the platform's is a
## window of the desktop's own, which a probe in Xvfb can neither see nor
## answer, and which the probe's session bus would open on the desktop of
## the person beside it.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _bar: ModelBar
var _world: BrickWorld
var _out: String = ""
var _shots: String = ""
## What the stand-in for the system opened and showed.
var _opened: Array = []
var _shown: Array = []
var _browser: bool = true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	_check("a person gets the platform's own Save dialog (SaveTo.native)", SaveTo.native)
	SaveTo.native = false
	SaveTo.open_with = func(uri: String) -> Error:
		_opened.append(uri)
		return OK if _browser else ERR_CANT_OPEN
	SaveTo.show_with = func(path: String) -> Error:
		_shown.append(path)
		return OK
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	_out = OS.get_user_data_dir().path_join("save_dialog_probe")
	DirAccess.make_dir_recursive_absolute(_out.path_join("other"))
	for name: String in DirAccess.get_files_at(_out):
		DirAccess.remove_absolute(_out.path_join(name))

	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_shell = _main.get("_shell")
		_bar = _main.get("_bar")
		_world = _main.get("_world")
		if _shell != null and _bar != null and _world != null and _world.brick_count() > 1:
			break
	if _world == null or _world.brick_count() <= 1:
		print("  save dialog probe: SKIPPED — no model came up on the baseplate")
		quit(0)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(30)

	await _ldraw()
	await _overwrite()
	await _cancel()
	await _io()
	await _model_3d()
	await _lists()
	await _picture()
	await _save_as()
	await _all_models()
	await _instructions()

	print("")
	if _failures == 0:
		print("save dialog probe: all checks passed")
	else:
		print("save dialog probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## LDraw: the first dialog, in Documents, named after the model.
func _ldraw() -> void:
	print("\n  File, Export, LDraw model")
	var name: String = _bar.model_name()
	var wanted: String = name.to_snake_case() + _bar.ldraw_extension()
	var dialog: FileDialog = await _dialog_after("export_ldraw")
	if not _check("pressing it opens a Save dialog", dialog != null):
		return
	_check("...for saving a file (%d), anywhere on the computer" % dialog.file_mode,
		dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE
		and dialog.access == FileDialog.ACCESS_FILESYSTEM)
	_check("...named after the model (%s)" % dialog.current_file, dialog.current_file == wanted)
	var documents: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	_check("...in Documents the first time (%s)" % dialog.current_dir,
		dialog.current_dir.trim_suffix("/") == documents.trim_suffix("/"))
	_check("...offering the LDraw kind (%s)" % ", ".join(dialog.filters),
		dialog.filters.size() == 1 and str(dialog.filters[0]).begins_with("*." + wanted.get_extension()))
	_check("...and nothing says it is working while the person chooses",
		not Working.is_busy())
	# Pictured in the probe's own folder, not the person's Documents.
	dialog.current_dir = _out
	await _shot("01_export_ldraw_dialog")
	var path: String = _out.path_join("kept_" + wanted)
	await _answer(dialog, path)
	var said: String = await _said()
	_check("the status bar says where it went (%s)" % said, said == "wrote %s" % path)
	_check("...and it is there, every part in it (%d of %d)" % [_parts_in(path),
		_world.brick_count() - (_main.get("_store") as ModelStore).scenery.size()],
		_parts_in(path) > 0 and _parts_in(path)
			== _world.brick_count() - (_main.get("_store") as ModelStore).scenery.size())
	await _frames(3)
	var button: Button = _shell.status.show_folder
	_check("...with Show in folder beside it", button.is_visible_in_tree())
	await _shot("02_status_wrote_ldraw")
	button.pressed.emit()
	_check("...which shows that file in its folder (%s)" % str(_shown),
		_shown.size() == 1 and _shown[0] == path)


## A file that is there: the overwrite question, and No keeps it.
func _overwrite() -> void:
	print("\n  the same file again")
	var path: String = _out.path_join("kept_" + _bar.model_name().to_snake_case()
		+ _bar.ldraw_extension())
	var was: String = FileAccess.get_file_as_string(path)
	_put(path, "0 the person's own file\n")
	var dialog: FileDialog = await _dialog_after("export_ldraw")
	if not _check("Export again opens the dialog", dialog != null):
		return
	_check("...in the folder the last file went to (%s)" % dialog.current_dir,
		dialog.current_dir.trim_suffix("/") == _out)
	await _answer(dialog, path)
	var asked: ConfirmationDialog = _question(dialog)
	_check("a file already there is asked about before it is written over (%s)"
		% (asked.dialog_text.replace("\n", " ") if asked != null else "nothing asked"),
		asked != null and asked.dialog_text.contains(path.get_file()))
	await _shot("03_overwrite_question")
	if asked == null:
		return
	asked.get_cancel_button().pressed.emit()
	await _frames(5)
	_check("...and No keeps the person's file as it was",
		FileAccess.get_file_as_string(path) == "0 the person's own file\n")
	_check("...with the dialog still up to choose another name", dialog.visible)
	await _answer(dialog, path)
	asked = _question(dialog)
	if asked != null:
		asked.get_ok_button().pressed.emit()
	var said: String = await _said()
	_check("...and Yes writes it (%s)" % said, said == "wrote %s" % path
		and FileAccess.get_file_as_string(path) != "0 the person's own file\n"
		and FileAccess.get_file_as_string(path).length() == was.length())


## Cancel: nothing written, nothing said to be.
func _cancel() -> void:
	print("\n  Cancel")
	var before: PackedStringArray = DirAccess.get_files_at(_out)
	_bar.say("")
	var dialog: FileDialog = await _dialog_after("export_io")
	if not _check("Export as Studio opens the dialog", dialog != null):
		return
	dialog.get_cancel_button().pressed.emit()
	await _frames(20)
	_check("Cancel writes nothing (%s)" % ", ".join(DirAccess.get_files_at(_out)),
		DirAccess.get_files_at(_out) == before)
	_check("...and says nothing was (%s)" % _bar.status_text(),
		not _bar.status_text().begins_with("wrote"))
	_check("...and leaves nothing working", not Working.is_busy() and Working.asking == 0
		and SaveTo.showing == null)


## BrickLink Studio, put in another folder.
func _io() -> void:
	print("\n  File, Export, BrickLink Studio model")
	var dialog: FileDialog = await _dialog_after("export_io")
	if not _check("pressing it opens the dialog", dialog != null):
		return
	_check("...named after the model (%s)" % dialog.current_file,
		dialog.current_file == _bar.model_name().to_snake_case() + ".io")
	var path: String = _out.path_join("other/my tug.io")
	await _answer(dialog, path)
	var said: String = await _said()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_check("it is written where it was put (%s)" % said, said == "wrote %s" % path
		and bytes.size() > 100 and bytes[0] == 0x50 and bytes[1] == 0x4b)
	var dialog_next: FileDialog = await _dialog_after("export_io")
	if dialog_next != null:
		_check("...and the next dialog opens there (%s)" % dialog_next.current_dir,
			dialog_next.current_dir.trim_suffix("/") == _out.path_join("other"))
		dialog_next.current_dir = _out
		dialog_next.get_cancel_button().pressed.emit()
		await _frames(5)


## The 3D model: its format chosen, then where; an OBJ's colours beside it.
func _model_3d() -> void:
	print("\n  File, Export, 3D model")
	var exports: Exports = _main.get("_exports")
	_shell.run("export_3d")
	await _frames(10)
	var format: ConfirmationDialog = exports.get("_model_3d")
	if not _check("pressing it asks which format", format != null and format.visible):
		return
	var choice: OptionButton = exports.get("_format_choice")
	choice.select(MeshExport.FORMATS.find("obj"))
	choice.item_selected.emit(choice.selected)
	format.get_ok_button().pressed.emit()
	var dialog: FileDialog = await _dialog_after("")
	if not _check("...then where, in the Save dialog", dialog != null):
		return
	_check("...named for the format (%s)" % dialog.current_file,
		dialog.current_file == MeshExport._file_base(_bar.model_name()) + ".obj")
	await _shot("04_export_obj_dialog")
	var path: String = _out.path_join("for blender.obj")
	await _answer(dialog, path)
	var said: String = await _said(["wrote", "could not", "no part"], 120.0)
	var obj: String = FileAccess.get_file_as_string(path)
	_check("the OBJ is where it was put (%s)" % said.left(120), obj.contains("\nv "))
	_check("...its colours beside it, named after it, and named in it",
		FileAccess.file_exists(_out.path_join("for blender.mtl"))
		and obj.contains("mtllib for blender.mtl"))
	# glTF, the format a 3D program takes whole.
	_shell.run("export_3d")
	await _frames(10)
	choice.select(MeshExport.FORMATS.find("glb"))
	choice.item_selected.emit(choice.selected)
	format.get_ok_button().pressed.emit()
	dialog = await _dialog_after("")
	if dialog == null:
		_check("a GLB asks where too", false)
		return
	path = _out.path_join("model.glb")
	await _answer(dialog, path)
	said = await _said(["wrote", "could not", "no part"], 120.0)
	var glb: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_check("a GLB is written where it was put (%s)" % said.left(80),
		glb.size() > 12 and glb.slice(0, 4).get_string_from_ascii() == "glTF")


## The parts lists: BrickLink's and Rebrickable's from the menu, the CSV
## from the parts list.
func _lists() -> void:
	print("\n  the parts lists")
	for each: Array in [["export_bricklink", "_bricklink.xml", "<INVENTORY>"],
			["export_rebrickable", "_rebrickable.csv", "Part,Color,Quantity"]]:
		var dialog: FileDialog = await _dialog_after(each[0])
		if not _check("%s opens the dialog" % each[0], dialog != null):
			continue
		_check("...named after the model (%s)" % dialog.current_file,
			dialog.current_file == _bar.model_name().to_snake_case() + str(each[1]))
		var path: String = _out.path_join("list" + str(each[1]))
		await _answer(dialog, path)
		var said: String = await _said()
		_check("...and the list is where it was put (%s)" % said.left(100),
			said.begins_with("wrote %s" % path)
			and FileAccess.get_file_as_string(path).contains(str(each[2])))
	_shell.run("parts_list")
	await _frames(20)
	var panel: InventoryPanel = _main.get("_inventory")
	var csv: Button = panel.get("_csv")
	if not _check("the parts list is up, with its CSV", panel.visible and csv != null):
		return
	csv.pressed.emit()
	var dialog: FileDialog = await _dialog_after("")
	if _check("its CSV opens the dialog", dialog != null):
		var path: String = _out.path_join("parts.csv")
		await _answer(dialog, path)
		var said: String = await _said()
		_check("...and it is where it was put, said on the status bar (%s)" % said,
			said == "wrote %s" % path and FileAccess.get_file_as_string(path).length() > 20)
	_shell.run("parts_list")
	await _frames(10)


func _picture() -> void:
	print("\n  File, Export, Picture")
	var dialog: FileDialog = await _dialog_after("export_picture")
	if not _check("pressing it opens the dialog", dialog != null):
		return
	var path: String = _out.path_join("picture.png")
	await _answer(dialog, path)
	var said: String = await _said(["wrote", "could not", "nothing", "no picture"], 60.0)
	var image := Image.load_from_file(path) if FileAccess.file_exists(path) else null
	_check("the picture is where it was put (%s)" % said,
		said == "wrote %s" % path and image != null and image.get_width() > 100)


## Save as: a file where the person says, the model named after it, and
## Save keeping it up to date.
func _save_as() -> void:
	print("\n  File, Save as")
	var dialog: FileDialog = await _dialog_after("save_as")
	if not _check("Save as opens the platform's Save dialog", dialog != null):
		return
	_check("...its title Save as (%s)" % dialog.title, dialog.title == "Save as")
	_check("...named after the model (%s)" % dialog.current_file,
		dialog.current_file == ModelStore._safe_name(_bar.model_name()) + _bar.ldraw_extension())
	await _shot("05_save_as_dialog")
	var path: String = _out.path_join("Probe Tug" + _bar.ldraw_extension())
	await _answer(dialog, path)
	var said: String = await _said(["saved “Probe Tug” — wrote", "saved “Probe Tug” here",
		"could not", "Not saved"], 60.0)
	var store: ModelStore = _main.get("_store")
	var parts: int = _world.brick_count() - store.scenery.size()
	_check("the model takes the file's name (%s)" % _bar.model_name(),
		_bar.model_name() == "Probe Tug")
	_check("...is kept here under it, for Open",
		FileAccess.file_exists(ModelStore.SAVE_DIR + "Probe Tug.ldr"))
	_check("...and written to the file chosen, every part (%s)" % said,
		_parts_in(path) == parts and said.contains(path))
	_world.add_brick("3001", 4, Transform3D(Basis.IDENTITY, Vector3(400, 0, 400)))
	store.touch()
	_shell.run("save")
	said = await _said(["saved “Probe Tug” — wrote", "saved “Probe Tug” here",
		"could not", "Not saved"], 60.0)
	_check("Save writes the file again (%d parts, %s)" % [_parts_in(path), said],
		_parts_in(path) == parts + 1 and said == "saved “Probe Tug” — wrote %s" % path)


func _all_models() -> void:
	print("\n  File, Export, All my models")
	var dialog: FileDialog = await _dialog_after("export_all")
	if not _check("pressing it opens the dialog", dialog != null):
		return
	var path: String = _out.path_join("everything.zip")
	await _answer(dialog, path)
	var said: String = await _said()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_check("the zip is where it was put (%s)" % said, said.begins_with("wrote %s" % path)
		and bytes.size() > 30 and bytes[0] == 0x50 and bytes[1] == 0x4b)


## Instructions: asked where before it is drawn; opened in the browser, and
## where none can be opened, the file said and shown.
func _instructions() -> void:
	print("\n  Instructions, with no browser to open it")
	_browser = false
	var dialog: FileDialog = await _dialog_after("instructions")
	if not _check("Instructions asks where to save the booklet", dialog != null):
		return
	_check("...before it is drawn", not BookletMaker.busy)
	_check("...named after the model (%s)" % dialog.current_file,
		dialog.current_file == _bar.model_name().to_snake_case() + "_instructions.html")
	_check("...its title saying what it is (%s)" % dialog.title,
		dialog.title == "Save the instructions")
	await _shot("06_instructions_dialog")
	var path: String = _out.path_join("tug booklet.html")
	await _answer(dialog, path)
	var said: String = await _said(["wrote", "could not", "stopped", "nothing"], 400.0)
	_check("the booklet is where it was put", FileAccess.get_file_as_string(path)
		.contains("section class=\"page steps\""))
	_check("...and the browser was asked to open it (%s)" % str(_opened),
		_opened.size() == 1 and str(_opened[0]) == "file://" + path)
	_check("...and with none to open it, the line says where the file is (%s)" % said,
		said.begins_with("wrote %s" % path) and said.ends_with(
			"no browser opened it: Show in folder finds it"))
	await _frames(3)
	_check("...with Show in folder beside it", _shell.status.show_folder.is_visible_in_tree())
	await _shot("07_status_no_browser")
	_shown.clear()
	_shell.status.show_folder.pressed.emit()
	_check("...which shows the booklet in its folder", _shown == [path])

	print("\n  Instructions, with a browser")
	_browser = true
	_opened.clear()
	dialog = await _dialog_after("instructions")
	if dialog == null:
		_check("Instructions asks again", false)
		return
	_check("...in the folder the booklet went to (%s)" % dialog.current_dir,
		dialog.current_dir.trim_suffix("/") == _out)
	path = _out.path_join("tug booklet 2.html")
	await _answer(dialog, path)
	said = await _said(["wrote", "could not", "stopped", "nothing"], 400.0)
	_check("the booklet opens in the browser, said (%s)" % said,
		_opened == ["file://" + path] and said.ends_with("opened in your browser")
		and said.contains(path))
	await _frames(3)
	await _shot("08_status_opened")


# -- helpers ---------------------------------------------------------------------


## The Save dialog [param command] opens (none pressed for ""), once it is up.
func _dialog_after(command: String) -> FileDialog:
	if not command.is_empty():
		_check("%s can be pressed" % command, _shell.run(command))
	var until: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < until:
		await process_frame
		if SaveTo.showing != null and SaveTo.showing.visible:
			await _frames(3)
			return SaveTo.showing
	return null


## The person typing [param path] into the dialog and pressing Save.
func _answer(dialog: FileDialog, path: String) -> void:
	dialog.current_dir = path.get_base_dir()
	dialog.current_file = path.get_file()
	await _frames(2)
	# What the last file's line said is not this one's.
	_bar.say("")
	dialog.get_ok_button().pressed.emit()
	await _frames(3)


## The dialog's overwrite question, while it is up.
func _question(dialog: FileDialog) -> ConfirmationDialog:
	for n: int in dialog.get_child_count(true):
		var child: Node = dialog.get_child(n, true)
		if child is ConfirmationDialog and (child as ConfirmationDialog).visible:
			return child
	return null


## The status line once it begins with one of [param starts], waiting at
## most [param seconds].
func _said(starts: Array = ["wrote", "could not", "nothing"], seconds: float = 30.0) -> String:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		var line: String = _bar.status_text()
		for start: String in starts:
			if line.begins_with(start):
				return line
	return _bar.status_text()


func _parts_in(path: String) -> int:
	var count: int = 0
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges().begins_with("1 "):
			count += 1
	return count


func _put(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(_shots.path_join(name + ".png"))
	print("    picture: %s" % _shots.path_join(name + ".png"))


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
