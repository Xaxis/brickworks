## Does every file chooser on the desktop open where a person keeps that
## kind of file, and then where they last chose one from?
##
##   tools/probe.sh picker_folder_probe
##   godot --headless --path . --script src/dev/picker_folder_probe.gd
##
## walk256 DS1 (2026-10-25): the photo search's chooser opened in the
## folder the app was started from, its install folder, and so did every
## other: Godot's own dialog starts in the working directory. Each is
## opened here as its button opens it, in a data folder of the probe's own:
##
##   a picture (the photo search's, Print's): Pictures the first time;
##   a model (File, Open, From a file): Documents, or the folder the last
##     export or Save as went to;
##   a 3D model to brickify, and a shop's list for My collection: Downloads,
##     where a browser saves them;
##   never the install folder, nor the folder the app was started from;
##   once a file is chosen, the next of its kind opens in its folder, and
##     choosers of the same kind share it; a folder gone since is the
##     first place again;
##   the sticker sheet's Save is the Save dialog every export has (SaveTo),
##     in the folder the last file went to.
##
## What is chosen goes nowhere: each chooser's own handler is cut first.
extends SceneTree

var _failures: int = 0
var _main: Node
var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_out = OS.get_user_data_dir().path_join("picker_folder_probe")
	for folder: String in ["photos", "models", "saved", "meshes", "lists"]:
		DirAccess.make_dir_recursive_absolute(_out.path_join(folder))
	var photo := Image.create(16, 16, false, Image.FORMAT_RGB8)
	photo.fill(Color(0.8, 0.1, 0.1))
	photo.save_png(_out.path_join("photos/brick.png"))
	_put("models/car.ldr", "0 Probe\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
	_put("meshes/cube.obj", "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n")
	_put("lists/wanted.csv", "Part,Color,Quantity\n3001,4,1\n")
	SaveTo.native = false

	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		if _main.get("_bin") != null and _main.get("_shell") != null \
				and _main.get("_brickify") != null:
			break
	await _frames(30)
	var shell: Shell = _main.get("_shell")
	var bin: Node = _main.get("_bin")
	var bar: Node = _main.get("_bar")

	print("\n  a picture: the photo search's chooser, and Print's")
	var photos: Node = bin.get("_picker")
	var photo_chooser: FileDialog = await _opened(photos, func() -> void: photos.call("ask"))
	_first(photo_chooser, OS.SYSTEM_DIR_PICTURES, "Pictures")
	await _choose(photo_chooser, "photos/brick.png")
	photo_chooser = await _opened(photos, func() -> void: photos.call("ask"))
	_in(photo_chooser, "photos", "the next time, the folder the last picture came from")
	var prints: Node = PictureFile.new()
	root.add_child(prints)
	var print_chooser: FileDialog = await _opened(prints, func() -> void: prints.call("ask"))
	_in(print_chooser, "photos", "Print's too")
	_gone("photos")
	print_chooser = await _opened(prints, func() -> void: prints.call("ask"))
	_first(print_chooser, OS.SYSTEM_DIR_PICTURES, "Pictures again once that folder is gone")
	prints.queue_free()

	print("\n  a model: File, Open, From a file")
	bar.call("_import")
	await _frames(5)
	var models: Node = bar.get("_picker")
	var model_chooser: FileDialog = models.get("_dialog")
	_cut(models)
	model_chooser.hide()
	model_chooser = await _opened(models, func() -> void: bar.call("_import"))
	_first(model_chooser, OS.SYSTEM_DIR_DOCUMENTS, "Documents")
	ShellPrefs.put("save_folder", _out.path_join("saved"))
	model_chooser = await _opened(models, func() -> void: bar.call("_import"))
	_in(model_chooser, "saved", "with no model opened from a file yet, where the last export went")
	await _choose(model_chooser, "models/car.ldr")
	model_chooser = await _opened(models, func() -> void: bar.call("_import"))
	_in(model_chooser, "models", "then the folder the last model came from")

	print("\n  a 3D model to brickify")
	var meshes: Node = (_main.get("_brickify") as Node).get("_picker")
	var mesh_chooser: FileDialog = await _opened(meshes, func() -> void: meshes.call("ask"))
	_first(mesh_chooser, OS.SYSTEM_DIR_DOWNLOADS, "Downloads")
	await _choose(mesh_chooser, "meshes/cube.obj")
	mesh_chooser = await _opened(meshes, func() -> void: meshes.call("ask"))
	_in(mesh_chooser, "meshes", "then the folder the last one came from")

	print("\n  a list for My collection")
	var lists: Node = shell.collection.get("_picker")
	var list_chooser: FileDialog = await _opened(lists, func() -> void: lists.call("ask", ".csv,.txt"))
	_first(list_chooser, OS.SYSTEM_DIR_DOWNLOADS, "Downloads")
	await _choose(list_chooser, "lists/wanted.csv")
	list_chooser = await _opened(lists, func() -> void: lists.call("ask", ".xml,.txt"))
	_in(list_chooser, "lists", "then the folder the last one came from")

	print("\n  the sticker sheet's Save")
	var sheet: Node = StickerSheetDialog.new()
	root.add_child(sheet)
	if _check("the sticker sheet saves as every export does (StickerSheetDialog.save_sheet)",
			sheet.has_method("save_sheet")):
		sheet.call("save_sheet", "pdf", PackedByteArray([37, 80, 68, 70]))
	await _frames(10)
	var saving: FileDialog = SaveTo.showing
	_check("it is the Save dialog every export has (%s)" % (saving.title if saving != null
		else "none"), saving != null and saving.file_mode == FileDialog.FILE_MODE_SAVE_FILE)
	if saving != null:
		_in(saving, "saved", "in the folder the last file went to")
		saving.get_cancel_button().pressed.emit()
		await _frames(5)

	print("")
	if _failures == 0:
		print("picker folder probe: all checks passed")
	else:
		print("picker folder probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	_quit(1 if _failures > 0 else 0)


func _quit(code: int) -> void:
	SaveTo.native = true
	quit(code)


## [param picker]'s chooser once [param ask] has opened it, its own handler
## of what is chosen cut.
func _opened(picker: Node, ask: Callable) -> FileDialog:
	ask.call()
	await _frames(5)
	_cut(picker)
	var chooser: FileDialog = picker.get("_dialog")
	_check("%s opens a chooser" % picker.get_script().get_global_name(),
		chooser != null and chooser.visible)
	return chooser


## What [param picker] does with a chosen file, undone: nothing is opened,
## read into the model or sent.
func _cut(picker: Node) -> void:
	for link: Dictionary in picker.get_signal_connection_list("picked"):
		picker.disconnect("picked", link["callable"])


## The person choosing [param file] in [param chooser], by its OK button.
func _choose(chooser: FileDialog, file: String) -> void:
	if chooser == null:
		return
	chooser.current_dir = _out.path_join(file.get_base_dir())
	chooser.current_file = file.get_file()
	await _frames(2)
	chooser.get_ok_button().pressed.emit()
	await _frames(5)
	_check("...choosing %s closes it" % file, not chooser.visible)


func _first(chooser: FileDialog, where: OS.SystemDir, said: String) -> void:
	if chooser == null:
		return
	var wanted: String = OS.get_system_dir(where)
	if wanted.is_empty() or not DirAccess.dir_exists_absolute(wanted):
		wanted = OS.get_environment("HOME")
	var install: String = OS.get_executable_path().get_base_dir()
	var started: String = OS.get_environment("PWD")
	var at: String = chooser.current_dir.trim_suffix("/")
	_check("...in %s the first time (%s, wanted %s)" % [said, at, wanted],
		at == wanted.trim_suffix("/"))
	_check("...not the install folder (%s) nor where the app was started (%s)" % [install,
		started], at != install.trim_suffix("/") and at != started.trim_suffix("/"))
	chooser.hide()


func _in(chooser: FileDialog, folder: String, said: String) -> void:
	if chooser == null:
		return
	var at: String = chooser.current_dir.trim_suffix("/")
	_check("...%s (%s)" % [said, at], at == _out.path_join(folder))
	chooser.hide()


## [param folder] taken away, with what is in it.
func _gone(folder: String) -> void:
	var path: String = _out.path_join(folder)
	for name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)


func _put(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(_out.path_join(path), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
