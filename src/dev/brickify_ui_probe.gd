## Brickify used the way a person uses it, in the real app.
##
##   godot --path . --resolution 1400x900 --script src/dev/brickify_ui_probe.gd
##
## Opens the app and presses I. The file dialog that comes up is answered
## with tests/fixtures/brickify/bunny.obj, as choosing it there answers it;
## the panel shows the bunny turning, its triangles and what it comes to.
## The size is typed into the size box, Brickify is clicked, and the bunny
## lands: one sub-assembly called "bunny", every part of it in it and all of
## them selected, buildable in one piece by the status line's word. One undo
## takes the whole of it off and redo puts it back. Then a sphere, an STL
## with Z up, is brought in hollow from the Build menu's own command and
## lands beside the bunny, touching nothing of it.
##
## Pictures: shots/brickify_dialog.png (the panel) and
## shots/brickify_placed.png (the two models). Look at them.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _library: PartLibrary
var _dialog: BrickifyDialog
var _bar: ModelBar

const TEMP := "user://brickify_ui_probe/"


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_dialog = _main.get("_brickify")
	_bar = _main.get("_bar")
	_main.call("clear_model")
	await _frames(10)
	var scenery: int = (_main.get("_store") as ModelStore).scenery.size()

	print("  the bunny, from its OBJ")
	await _key(KEY_I, "", true)
	var picker: MeshFilePicker = _dialog._picker
	var chooser: FileDialog = picker._dialog
	_check("Ctrl-I brings up a file dialog for 3D models: %s" % (chooser.filters if chooser != null
		else "none"), chooser != null and chooser.visible
		and str(chooser.filters).contains("*.obj"))
	if chooser == null:
		_finish()
		return
	chooser.hide()
	chooser.file_selected.emit(ProjectSettings.globalize_path(
		"res://tests/fixtures/brickify/bunny.obj"))
	await _frames(30)
	_check("the panel is up for it: %s, %s" % [_dialog._title.text, _dialog._about.text],
		_dialog.visible and _dialog._title.text.contains("bunny"))
	await _type_into(_dialog._studs.get_line_edit(), "32")
	await _frames(10)
	_check("the size typed in is the size: %d studs, %s" % [int(_dialog._studs.value),
		_dialog._detail.text], int(_dialog._studs.value) == 32
		and _dialog._detail.text.contains("bricks tall"))
	await _shot("brickify_dialog")
	await _click_control(_dialog._go)
	var waited: int = await _until_down(240)
	var bricks: int = _world.brick_count() - scenery
	var tree: Dictionary = (_main.get("_shell") as Shell).assemblies.parts_by_path()
	_check("it lands in %d s: %d parts, as the sub-assembly %s" % [waited, bricks, tree.keys()],
		bricks > 300 and tree.has("bunny#1")
		and str(tree["bunny#1"]).split(",").size() == bricks)
	var said: String = _status()
	_check("the status line says so: \"%s\"" % said, said.contains("buildable in one piece"))
	_check("and all of it is selected, to move or turn straight away: %d" % _builder.selection.size(),
		_builder.selection.size() == bricks)
	var grouped: bool = true
	for brick: BrickWorld.Brick in _world.bricks():
		if not (_main.get("_store") as ModelStore).scenery.has(brick.id) and brick.group != "bunny":
			grouped = false
	_check("every part of it is in the bunny", grouped)
	_builder.clear_selection()
	await _key(KEY_Z, "", true)
	await _frames(20)
	_check("one undo takes all of it back: %d left" % (_world.brick_count() - scenery),
		_world.brick_count() - scenery == 0)
	await _key(KEY_Z, "", true, true)
	await _frames(20)
	_check("and redo puts it back: %d" % (_world.brick_count() - scenery),
		_world.brick_count() - scenery == bricks)
	var bunny_box: AABB = _bounds("bunny")

	print("")
	print("  a sphere, hollow, from an STL, beside it")
	DirAccess.make_dir_recursive_absolute(TEMP)
	var stl_path: String = ProjectSettings.globalize_path(TEMP + "sphere.stl")
	var file := FileAccess.open(stl_path, FileAccess.WRITE)
	file.store_buffer(BrickifySamples.to_stl(BrickifySamples.sphere()))
	file.close()
	(_main.get("_shell") as Shell).run("brickify")
	await _frames(10)
	_check("the Build menu's Brickify brings up the same dialog", chooser.visible)
	chooser.hide()
	chooser.file_selected.emit(stl_path)
	await _frames(30)
	_check("an STL is stood Z up: %s" % _dialog._up.get_item_text(_dialog._up.selected),
		_dialog.visible and _dialog._up.selected == 1)
	await _click_control(_dialog._hollow)
	await _type_into(_dialog._studs.get_line_edit(), "20")
	await _click_control(_dialog._go)
	waited = await _until_down(240)
	tree = (_main.get("_shell") as Shell).assemblies.parts_by_path()
	var sphere_box: AABB = _bounds("sphere")
	_check("it lands in %d s as its own sub-assembly: %s" % [waited, tree.keys()],
		tree.has("sphere#1") and tree.has("bunny#1"))
	_check("beside the bunny, touching nothing of it: %s and %s" % [bunny_box, sphere_box],
		sphere_box.size.x > 0.0 and not sphere_box.grow(-1.0).intersects(bunny_box.grow(-1.0)))
	_check("the status line: \"%s\"" % _status(), _status().contains("buildable in one piece"))
	_builder.clear_selection()
	var camera: CadCamera = _main.get("_camera")
	camera.frame(bunny_box.merge(sphere_box), 1.15)
	await _frames(30)
	await _shot("brickify_placed")
	_finish()


func _finish() -> void:
	if DirAccess.dir_exists_absolute(TEMP):
		for name: String in DirAccess.get_files_at(TEMP):
			DirAccess.remove_absolute(TEMP + name)
		DirAccess.remove_absolute(TEMP)
	print("")
	if _failures == 0:
		print("brickify ui probe: a bunny and a hollow sphere brought in, laid and placed as sub-assemblies")
	else:
		print("brickify ui probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


## Until the panel has put its model down: the seconds it took.
func _until_down(seconds: int) -> int:
	var began: int = Time.get_ticks_msec()
	await _frames(5)
	while (_dialog.is_busy() or _dialog.visible) and Time.get_ticks_msec() - began < seconds * 1000:
		await process_frame
	await _frames(20)
	if _dialog.visible:
		print("    still up: %s" % _dialog._status.text)
	return (Time.get_ticks_msec() - began) / 1000


func _status() -> String:
	var label: Label = _bar.get("_status")
	return label.text if label != null else ""


func _bounds(group: String) -> AABB:
	var out := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.group != group:
			continue
		var box: AABB = brick.transform * _library.mesh_for(brick.part_id).bounds
		out = box if first else out.merge(box)
		first = false
	return out


# -- driving it ----------------------------------------------------------------


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = mask
	Input.parse_input_event(event)


func _button(at: Vector2, which: MouseButton, down: bool, mask: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = mask
	Input.parse_input_event(event)


func _click_at(at: Vector2) -> void:
	_move(at)
	await _frames(6)
	_button(at, MOUSE_BUTTON_LEFT, true, MOUSE_BUTTON_MASK_LEFT)
	await _frames(2)
	_button(at, MOUSE_BUTTON_LEFT, false, 0)
	await _frames(6)


func _click_control(control: Control) -> void:
	var scroll: Node = control.get_parent()
	while scroll != null and not (scroll is ScrollContainer):
		scroll = scroll.get_parent()
	if scroll != null:
		(scroll as ScrollContainer).ensure_control_visible(control)
		await _frames(3)
	await _click_at(control.get_global_rect().get_center())


func _key(code: Key, text: String = "", ctrl: bool = false, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = ctrl
		event.shift_pressed = shift
		if not text.is_empty():
			event.unicode = text.unicode_at(0)
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _type_into(line: LineEdit, text: String) -> void:
	await _click_control(line)
	line.grab_focus()
	line.select_all()
	await _key(KEY_BACKSPACE)
	for character: String in text:
		await _key(OS.find_keycode_from_string(character.to_upper()), character)
	await _key(KEY_ENTER)
	await _frames(4)
	line.release_focus()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/%s.png" % name)
