## Are the desktop's own dialogs drawn in the app's look, and does the
## picture chooser open where a person's pictures are?
##
##   tools/probe.sh dialog_look_probe
##   godot --path . --resolution 1400x900 --script src/dev/dialog_look_probe.gd
##   ... -- --shots=DIR    each dialog pictured there, to look at
##
## walk256 DS1 (2026-10-25), desktop 0.8.0: the photo search's question,
## Build together and the picture chooser were drawn in the engine's grey
## beside panels in the app's own dark face, and the chooser opened in
## the folder the app was started from, its install folder. So this opens
## each as a person does and reads the window's own pixels:
##
##   File, Render… (a panel already in the app's look) gives the face;
##   the parts bin's camera: its question's title bar and body are that
##   face, and so is the chooser Choose a photo opens;
##   the chooser opens in Pictures (the home folder where there is none),
##   not the install folder; once a picture is chosen from a folder, the
##   next opens there, the photo search's and Print's alike; a folder gone
##   since is Pictures again;
##   Print's own chooser (PictureFile) and File, Build together… are that
##   face too.
##
## Nothing goes to Brickognize: the chosen picture's way there is cut.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shots: String = ""
var _out: String = ""
## The app's panel face, read off the Render panel.
var _face := Color()


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

	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	var world: BrickWorld = null
	for _n: int in 600:
		await process_frame
		world = _main.get("_world")
		if world != null and world.brick_count() > 1 and _main.get("_bin") != null:
			break
	if world == null or world.brick_count() <= 1:
		print("  dialog look probe: SKIPPED — no model came up on the baseplate")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(30)

	await _render_face()
	await _photo()
	await _print_chooser()
	await _together()

	print("")
	if _failures == 0:
		print("dialog look probe: all checks passed")
	else:
		print("dialog look probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


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
	await _shot("1_render", picture)
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
	if not _check("pressing it asks first (%s)" % (told.title if told != null else "none"),
			told != null and told.visible):
		return
	await _in_the_look(told, "the question")
	await _shot("2_photo_question")

	# The chosen picture goes nowhere: Brickognize is a third party.
	var picker: Node = bin.get("_picker")
	for link: Dictionary in picker.get_signal_connection_list("picked"):
		picker.disconnect("picked", link["callable"])
	(told as AcceptDialog).get_ok_button().pressed.emit()
	await _frames(10)
	var chooser: FileDialog = picker.get("_dialog")
	if not _check("Choose a photo opens the chooser", chooser != null and chooser.visible):
		return
	await _in_the_look(chooser, "the chooser")
	_opens_in(chooser, _pictures(), "Pictures the first time")
	var install: String = OS.get_executable_path().get_base_dir()
	var started: String = OS.get_environment("PWD")
	_check("...not the folder the app is in (%s) or was started from (%s)" % [install, started],
		_dir(chooser) != install.trim_suffix("/") and _dir(chooser) != started.trim_suffix("/"))
	await _shot("3_photo_chooser")

	# A picture chosen from a folder of the probe's own.
	var folder: String = _out.path_join("photos")
	DirAccess.make_dir_recursive_absolute(folder)
	var photo := Image.create(32, 32, false, Image.FORMAT_RGB8)
	photo.fill(Color(0.8, 0.1, 0.1))
	photo.save_png(folder.path_join("brick.png"))
	chooser.current_dir = folder
	chooser.current_file = "brick.png"
	await _frames(3)
	chooser.get_ok_button().pressed.emit()
	await _frames(10)
	_check("...and choosing a picture closes it", not chooser.visible)
	picker.call("ask")
	await _frames(10)
	_opens_in(chooser, folder, "the folder the last picture came from, the next time")
	chooser.hide()
	await _frames(5)


## Print's own chooser: the same look, and where the last picture came from.
func _print_chooser() -> void:
	print("\n  Print's picture chooser (PictureFile)")
	var files: Node = PictureFile.new()
	root.add_child(files)
	files.call("ask")
	await _frames(10)
	var chooser: FileDialog = files.get("_dialog")
	if not _check("it opens", chooser != null and chooser.visible):
		return
	await _in_the_look(chooser, "Print's chooser")
	_opens_in(chooser, _out.path_join("photos"), "where the photo search last chose from")
	await _shot("4_print_chooser")
	chooser.hide()
	# A folder gone since: Pictures again.
	for name: String in DirAccess.get_files_at(_out.path_join("photos")):
		DirAccess.remove_absolute(_out.path_join("photos").path_join(name))
	DirAccess.remove_absolute(_out.path_join("photos"))
	files.call("ask")
	await _frames(10)
	_opens_in(chooser, _pictures(), "Pictures again once that folder is gone")
	chooser.hide()
	files.queue_free()
	await _frames(5)


## File, Build together….
func _together() -> void:
	print("\n  File, Build together…")
	_main.call("open_together")
	await _frames(10)
	var dialog: Window = _main.get("_together_dialog")
	if not _check("it opens", dialog != null and dialog.visible):
		return
	await _in_the_look(dialog, "Build together")
	await _shot("5_together")
	dialog.hide()
	await _frames(5)


# -- helpers ---------------------------------------------------------------------


## [param window]'s title bar and body, read off the window, are the face
## of the app's panels.
func _in_the_look(window: Window, what: String) -> void:
	await _frames(5)
	var picture: Image = await _picture()
	var title: float = float(window.get_theme_constant("title_height"))
	var corner := Vector2(window.position)
	var bar: Color = _at(picture, corner + Vector2(10, -title * 0.5))
	var body: Color = _at(picture, corner + Vector2(3, window.size.y * 0.5))
	_check("%s's title bar is the app's panel face (%s, the face %s)" % [what, _say(bar),
		_say(_face)], _near(bar, _face))
	_check("%s's body is the app's panel face (%s)" % [what, _say(body)], _near(body, _face))


func _opens_in(chooser: FileDialog, wanted: String, when: String) -> void:
	_check("...it opens in %s (%s, wanted %s)" % [when, _dir(chooser), wanted],
		_dir(chooser) == wanted.trim_suffix("/"))


func _dir(chooser: FileDialog) -> String:
	return chooser.current_dir.trim_suffix("/")


## Pictures, or the home folder where there is none.
func _pictures() -> String:
	var pictures: String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if not pictures.is_empty() and DirAccess.dir_exists_absolute(pictures):
		return pictures
	return OS.get_environment("HOME")


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
