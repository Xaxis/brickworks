## Is every dialog, chooser and menu the app opens drawn in the app's look?
##
##   tools/probe.sh dialog_look_probe
##   godot --path . --resolution 1400x900 --script src/dev/dialog_look_probe.gd
##   ... -- --shots=DIR    each one pictured there, to look at
##
## walk256 DS1 (2026-10-25), desktop 0.8.0: the photo search's question,
## Build together and the picture chooser were drawn in the engine's grey
## beside panels in the app's own dark face; then Versions, Saved models
## and every other dialog of the engine's were too, and the menus.
## So this opens each as a person does and reads the window's own pixels:
##
##   File, Render… (a panel in the app's look) gives the face;
##   the photo search's question and its chooser, Print's chooser, Build
##   together, Versions, Saved models and its Delete question, About,
##   Clear the baseplate's question, the Open-a-model, Brickify and
##   collection choosers, Godot's own Save dialog (where there is no
##   portal) and its overwrite question, the 3D export's question, the
##   baseplate size, a sub-assembly's name, a section's report: each one's
##   title bar and body are that face;
##   and the menus (File, a part's menu, the colour picker's popup) are
##   too, on the desktop;
##   then every other dialog and menu in the window, popped up and read:
##   none of them is in the engine's grey.
##
## Nothing is written, sent or opened: each is closed as it was opened.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _shots: String = ""
var _out: String = ""
## The app's panel face, read off the Render panel.
var _face := Color()
## What has been read, by instance id.
var _read: Dictionary = {}
var _names: PackedStringArray = PackedStringArray()
## What this probe is called in its last line (contrast_probe walks the
## same windows and judges them by another measure).
var _label: String = "dialog look probe"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	_out = OS.get_user_data_dir().path_join("dialog_look_probe")
	DirAccess.make_dir_recursive_absolute(_out)
	# Godot's own Save dialog, as where the system has no portal: the
	# portal's would open on the desktop beside the probe's Xvfb.
	SaveTo.native = false

	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	var world: BrickWorld = null
	for _n: int in 600:
		await process_frame
		world = _main.get("_world")
		_shell = _main.get("_shell")
		if world != null and world.brick_count() > 1 and _main.get("_bin") != null \
				and _shell != null:
			break
	if world == null or world.brick_count() <= 1:
		print("  %s: SKIPPED — no model came up on the baseplate" % _label)
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(30)

	await _main_window()
	await _render_face()
	await _photo()
	await _print_chooser()
	await _together()
	await _versions()
	await _saved_models()
	await _about()
	await _clear()
	await _choosers()
	await _save_dialog()
	await _asked()
	await _menus()
	await _everything_else()

	_summary()
	print("")
	if _failures == 0:
		print("%s: all checks passed" % _label)
	else:
		print("%s: %d check(s) FAILED" % [_label, _failures])
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _summary() -> void:
	print("\n  %d read: %s" % [_names.size(), ", ".join(_names)])


## The main window before anything is opened over it: nothing to read for
## the look, which is its own panels'.
func _main_window() -> void:
	pass


## The face of a panel already in the app's look: File, Render….
func _render_face() -> void:
	print("\n  File, Render… (in the app's look already)")
	_main.call("open_render")
	await _frames(20)
	var panel: Control = _main.get("_render")
	if not _check("Render is up", panel != null and panel.visible):
		return
	var at: Rect2 = panel.get_global_rect()
	var picture: Image = await _picture()
	_face = _at(picture, at.position + Vector2(5, at.size.y * 0.5))
	_check("...its face is dark (%s)" % _say(_face), _face.v < 0.2)
	await _shot("01_render", picture)
	# Its colour's popup, which is a menu's kind of window.
	var colour: ColorPickerButton = panel.get("_picker")
	if colour != null:
		var popup: PopupPanel = colour.get_popup()
		popup.popup(Rect2i(Vector2i(500, 160), Vector2i.ZERO))
		await _in_the_look(popup, "Render's colour popup")
		await _shot("02_render_colour")
		popup.hide()
	panel.call("close")
	await _frames(10)


## The parts bin's camera: the question, then the chooser.
func _photo() -> void:
	print("\n  the parts bin's camera")
	var bin: Node = _main.get("_bin")
	var button: Button = bin.get("_photo_button")
	if not _check("the camera is there", button != null):
		return
	button.pressed.emit()
	await _frames(10)
	var told: Window = bin.get("_telling")
	if not _check("pressing it asks first", told != null and told.visible):
		return
	await _in_the_look(told, "the photo search's question")
	await _shot("03_photo_question")
	# The chosen picture goes nowhere: Brickognize is a third party.
	var picker: Node = bin.get("_picker")
	for link: Dictionary in picker.get_signal_connection_list("picked"):
		picker.disconnect("picked", link["callable"])
	(told as AcceptDialog).get_ok_button().pressed.emit()
	await _frames(10)
	var chooser: FileDialog = picker.get("_dialog")
	if not _check("Choose a photo opens the chooser", chooser != null and chooser.visible):
		return
	await _in_the_look(chooser, "the photo chooser")
	await _shot("04_photo_chooser")
	chooser.hide()
	await _frames(5)


## Print's own chooser.
func _print_chooser() -> void:
	print("\n  Print's picture chooser (PictureFile)")
	var files: Node = PictureFile.new()
	root.add_child(files)
	files.call("ask")
	await _frames(10)
	var chooser: FileDialog = files.get("_dialog")
	if _check("it opens", chooser != null and chooser.visible):
		await _in_the_look(chooser, "Print's chooser")
		await _shot("05_print_chooser")
		chooser.hide()
	files.queue_free()
	await _frames(5)


func _together() -> void:
	print("\n  File, Build together…")
	_main.call("open_together")
	await _frames(10)
	var dialog: Window = _main.get("_together_dialog")
	if _check("it opens", dialog != null and dialog.visible):
		await _in_the_look(dialog, "Build together")
		await _shot("06_together")
		dialog.hide()
	await _frames(5)


func _versions() -> void:
	print("\n  File, Versions…")
	_check("Versions can be pressed", _shell.run("versions"))
	await _frames(10)
	var dialog: Window = _shell.versions
	if _check("it opens", dialog != null and dialog.visible):
		await _in_the_look(dialog, "Versions")
		await _shot("07_versions")
		dialog.hide()
	await _frames(5)


## File, Open, Rename or delete saved models…, and Delete's question.
func _saved_models() -> void:
	print("\n  File, Open, Rename or delete saved models…")
	var dialog: AcceptDialog = _main.get("_saved_models")
	dialog.call("open")
	await _frames(10)
	if not _check("it opens", dialog.visible):
		return
	await _in_the_look(dialog, "Saved models")
	await _shot("08_saved_models")
	var question: ConfirmationDialog = dialog.get("_confirm_delete")
	question.dialog_text = "Delete “Probe”? It goes from this computer."
	question.popup_centered()
	await _in_the_look(question, "Saved models' Delete question")
	await _shot("09_saved_models_delete")
	question.hide()
	var rename: ConfirmationDialog = dialog.get("_rename")
	rename.popup_centered()
	await _in_the_look(rename, "Saved models' Rename")
	rename.hide()
	dialog.hide()
	await _frames(5)


func _about() -> void:
	print("\n  Help, About Brickworks")
	_check("About can be pressed", _shell.run("about"))
	await _frames(10)
	var dialog: Window = _shell.get("_about")
	if _check("it opens", dialog != null and dialog.visible):
		await _in_the_look(dialog, "About")
		await _shot("10_about")
		dialog.hide()
	await _frames(5)


## File, Clear the baseplate…: its question, answered No.
func _clear() -> void:
	print("\n  File, Clear the baseplate…")
	_check("Clear can be pressed", _shell.run("clear"))
	await _frames(10)
	var dialog: Window = _shown_dialog()
	if _check("it asks first (%s)" % (dialog.title if dialog != null else "nothing"),
			dialog != null):
		await _in_the_look(dialog, "Clear's question")
		await _shot("11_clear")
		dialog.hide()
	await _frames(5)


## The other choosers: Open a model from a file, Brickify's, the
## collection's list.
func _choosers() -> void:
	print("\n  the other choosers")
	var bar: Node = _main.get("_bar")
	bar.call("_import")
	await _frames(10)
	var model: FileDialog = (bar.get("_picker") as Node).get("_dialog")
	if _check("Open, From a file opens a chooser", model != null and model.visible):
		await _in_the_look(model, "the Open-a-model chooser")
		await _shot("12_model_chooser")
		model.hide()
	var brickify: Node = _main.get("_brickify")
	if brickify != null:
		(brickify.get("_picker") as Node).call("ask")
		await _frames(10)
		var mesh: FileDialog = (brickify.get("_picker") as Node).get("_dialog")
		if _check("Brickify's chooser opens", mesh != null and mesh.visible):
			await _in_the_look(mesh, "Brickify's chooser")
			await _shot("13_mesh_chooser")
			mesh.hide()
	var lists: Node = _shell.collection.get("_picker")
	lists.call("ask", ".csv,.txt")
	await _frames(10)
	var text: FileDialog = lists.get("_dialog")
	if _check("My collection's import chooser opens", text != null and text.visible):
		await _in_the_look(text, "the collection's chooser")
		await _shot("14_list_chooser")
		text.hide()
	await _frames(5)


## Godot's own Save dialog, and its question before it writes over a file.
func _save_dialog() -> void:
	print("\n  Godot's own Save dialog (no portal)")
	var there: String = _out.path_join("there.ldr")
	var file: FileAccess = FileAccess.open(there, FileAccess.WRITE)
	file.store_string("0 kept\n")
	file.close()
	SaveTo.ask("there.ldr", "", "Export")
	await _frames(10)
	var dialog: FileDialog = SaveTo.showing
	if not _check("Export asks where", dialog != null and dialog.visible):
		return
	await _in_the_look(dialog, "the Save dialog")
	await _shot("15_save_dialog")
	dialog.current_dir = _out
	dialog.current_file = "there.ldr"
	await _frames(2)
	dialog.get_ok_button().pressed.emit()
	await _frames(5)
	var question: ConfirmationDialog = null
	for n: int in dialog.get_child_count(true):
		var child: Node = dialog.get_child(n, true)
		if child is ConfirmationDialog and (child as ConfirmationDialog).visible:
			question = child
	if _check("over a file, it asks first", question != null):
		await _in_the_look(question, "the Save dialog's overwrite question")
		await _shot("16_save_overwrite")
		question.get_cancel_button().pressed.emit()
		await _frames(3)
	dialog.get_cancel_button().pressed.emit()
	await _frames(5)
	_check("...and nothing was written over", FileAccess.get_file_as_string(there) == "0 kept\n")


## The questions a command asks: the 3D export's, the baseplate's size,
## a sub-assembly's name, a section's report.
func _asked() -> void:
	print("\n  the questions commands ask")
	_check("Export, 3D model can be pressed", _shell.run("export_3d"))
	await _frames(10)
	var model_3d: Window = (_main.get("_exports") as Node).get("_model_3d")
	if _check("it asks how", model_3d != null and model_3d.visible):
		await _in_the_look(model_3d, "the 3D export's question")
		await _shot("17_export_3d")
		model_3d.hide()
	_check("Baseplate, other size can be pressed", _shell.run("floor_custom"))
	await _frames(10)
	var floor_size: Window = _shell.get("_floor_size")
	if _check("it asks how big", floor_size != null and floor_size.visible):
		await _in_the_look(floor_size, "the baseplate's size")
		floor_size.hide()
	var verbs: Node = _main.get("_verbs")
	verbs.call("_ask_name", "rename", "Rename the sub-assembly", "Rename",
		"What is it called? Every copy of it is renamed.", "Probe")
	await _frames(10)
	var naming: Window = verbs.get("_naming")
	if _check("a sub-assembly's name is asked", naming != null and naming.visible):
		await _in_the_look(naming, "a sub-assembly's name")
		naming.hide()
	_shell.sections.call("_open_dialog", {"name": "Probe section", "parts": 0})
	await _frames(10)
	var report: Window = _shell.sections.get("_dialog")
	if _check("a section's report opens", report != null and report.visible):
		await _in_the_look(report, "a section's report")
		report.hide()
	await _frames(5)


## The menus, which on the desktop are the app's face too.
func _menus() -> void:
	print("\n  the menus")
	var menus: Array = _shell.get("_menus")
	var file: MenuButton = menus[0]
	file.show_popup()
	await _frames(10)
	var popup: PopupMenu = file.get_popup()
	if _check("File opens its menu", popup.visible):
		await _in_the_look(popup, "the File menu")
		await _shot("18_file_menu")
		popup.hide()
	_shell.open_context(Vector2(700, 400))
	await _frames(10)
	var context: PopupMenu = _shell.context
	if _check("a part's menu opens", context != null and context.visible):
		await _in_the_look(context, "a part's menu")
		await _shot("19_context_menu")
		context.hide()
	await _frames(5)


## Every other dialog and menu in the window, popped up and read.
func _everything_else() -> void:
	print("\n  every other dialog and menu in the window")
	var found: Array[Window] = []
	var walk: Array[Node] = [root]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		for n: int in node.get_child_count(true):
			walk.append(node.get_child(n, true))
		var window := node as Window
		if window == null or window == root or _read.has(window.get_instance_id()):
			continue
		if Tooltips.is_tooltip(window) or not window.is_inside_tree():
			continue
		if window is AcceptDialog or window is PopupMenu and (window as PopupMenu).item_count > 0 \
				or window is PopupPanel:
			found.append(window)
	for window: Window in found:
		if window is AcceptDialog:
			(window as AcceptDialog).popup_centered()
		else:
			(window as Popup).popup(Rect2i(Vector2i(420, 140), Vector2i.ZERO))
		await _in_the_look(window, _named(window))
		window.hide()
		await _frames(2)
	_check("%d more found and read" % found.size(), true)


# -- helpers ---------------------------------------------------------------------


## [param window]'s body, and its title bar where it has one, read off the
## window, are the face of the app's panels.
func _in_the_look(window: Window, what: String) -> void:
	_read[window.get_instance_id()] = true
	_names.append(what)
	await _frames(5)
	var picture: Image = await _picture()
	var corner := Vector2(window.position)
	var body: Color = _at(picture, corner + Vector2(3, window.size.y * 0.5))
	if window is AcceptDialog:
		var title: float = float(window.get_theme_constant("title_height"))
		var bar: Color = _at(picture, corner + Vector2(10, -title * 0.5))
		_check("%s's title bar is the app's panel face (%s, the face %s)" % [what, _say(bar),
			_say(_face)], _near(bar, _face))
	_check("%s's body is the app's panel face (%s)" % [what, _say(body)], _near(body, _face))


## The dialog up now, the last one shown.
func _shown_dialog() -> Window:
	var shown: Window = null
	var walk: Array[Node] = [root]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		for n: int in node.get_child_count(true):
			walk.append(node.get_child(n, true))
		if node is AcceptDialog and (node as Window).visible:
			shown = node
	return shown


func _named(window: Window) -> String:
	return window.title if not window.title.is_empty() \
		else "%s %s in %s" % [window.get_class(), window.name, window.get_parent().name]


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.03 and absf(a.g - b.g) < 0.03 and absf(a.b - b.b) < 0.03


func _say(colour: Color) -> String:
	return "#" + colour.to_html(false)


## The window as drawn.
func _picture() -> Image:
	await _frames(3)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## The pixel at [param point], in the root's own units.
func _at(picture: Image, point: Vector2) -> Color:
	var pixel: Vector2 = root.get_final_transform() * point
	var x: int = clampi(roundi(pixel.x), 0, picture.get_width() - 1)
	var y: int = clampi(roundi(pixel.y), 0, picture.get_height() - 1)
	return picture.get_pixel(x, y)


func _shot(name: String, picture: Image = null) -> void:
	if _shots.is_empty():
		return
	if picture == null:
		picture = await _picture()
	picture.save_png(_shots.path_join(name + ".png"))
	print("    picture: %s" % _shots.path_join(name + ".png"))


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
