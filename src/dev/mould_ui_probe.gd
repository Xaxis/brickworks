## Sculpting moulds in the figure builder, the way a person does it.
##
##   godot --path . --resolution 1400x900 --script src/dev/mould_ui_probe.gd
##
## Opens the real app, presses M, and in the Headgear slot presses "Make a
## mould…": the classic hair (3901) opens, its inside tinted as locked.
## Sculpted with the mouse into a quiff — the forelock taken hold of and
## swept up and forward, the sides swollen, the crown smoothed, the back
## drawn down longer, the whole of it lifted by a lattice handle — its walls
## checked, saved and worn. Then in the right hand a club, from the Club
## primitive, its ball swollen and pulled into spikes. Every stroke is a
## press, a drag and a release on the view. Then the figure is placed and
## photographed.
##
## Pictures go to shots/mould_*.png: look at them. The hair is still on
## the head, not through it; its fringe rises in a quiff; the club is in
## the hand where a sword would be.
##
## Made parts go to user://mould_ui_probe_parts/, never the person's own.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _figures: MinifigDialog
var _editor: MouldEditor

const PROBE_DIR := "user://mould_ui_probe_parts/"


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	_forget(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
	Minifig.shelf_file = "user://mould_ui_probe_shelf.json"
	if FileAccess.file_exists(Minifig.shelf_file):
		DirAccess.remove_absolute(Minifig.shelf_file)
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
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_figures = _main.get("_figures")
	_main.call("clear_model")
	await _frames(10)

	print("  a hairstyle")
	await _key(KEY_M)
	await _click_control(_figures._slot_buttons["headwear"])
	_check("the Headgear slot offers \"%s\"" % _figures._make.text,
		_figures._make.visible and _figures._make.text == "Make a mould…")
	await _click_control(_figures._make)
	_editor = _figures.mould_editor()
	await _frames(20)
	var mould: Mould = _editor.mould
	_check("it opens on the figure's hair, 3901, made finer to sculpt: %d triangles"
		% (mould.triangle_count() if mould != null else 0),
		_editor.visible and mould != null and mould.base == "3901" and mould.triangle_count() > 1000)
	if mould == null:
		_finish()
		return
	var original: PackedVector3Array = mould.positions.duplicate()
	var locked: PackedFloat32Array = mould.locks.duplicate()
	_editor.turn_to(0.6, 0.3, 95.0)
	await _frames(20)
	await _shot("mould_hair_start")

	# Turned with the right button, as a hand turns it.
	var view: Rect2 = _editor.view().get_global_rect()
	await _drag([view.get_center() + Vector2(-60, 120), view.get_center() + Vector2(40, 120)],
		MOUSE_BUTTON_RIGHT)
	await _frames(4)

	# The forelock, seen from the side, taken hold of and swept up and
	# forward.
	_editor.turn_to(PI * 0.5, 0.15, 95.0)
	await _frames(6)
	await _click_control(_editor._tools["grab"])
	_editor.set_brush(9.0, 0.6)
	var fringe: Vector3 = _surface(Vector3(0, 6, 40), Vector3(0, 4, 8))
	await _drag_on([fringe, fringe + Vector3(0, 5, 2), fringe + Vector3(0, 10, 5)])
	var lifted: float = 0.0
	for v: int in mould.positions.size():
		lifted = maxf(lifted, mould.positions[v].y - original[v].y)
	_check("the fringe swept up %.1f LDU" % lifted, lifted > 4.0)
	# The editor's own Undo and Redo keys are the keymap's.
	var swept: PackedVector3Array = mould.positions.duplicate()
	await _chord(Keymap.key_of("undo"))
	var undone: bool = mould.positions == original
	await _chord(Keymap.key_of("redo"))
	_check("%s takes the sweep back, %s puts it back" % [Keymap.listed("undo"), Keymap.listed("redo")],
		undone and mould.positions == swept)
	# The back drawn down longer.
	var nape: Vector3 = _surface(Vector3(0, -10, -40), Vector3(0, -8, -10))
	await _drag_on([nape, nape + Vector3(0, -3, -1), nape + Vector3(0, -6, -2)])
	# The sides swollen, both at once with symmetry.
	_editor.turn_to(0.0, 0.25, 95.0)
	await _frames(6)
	await _click_control(_editor._tools["inflate"])
	_editor.set_brush(8.0, 0.5)
	var side: Vector3 = _surface(Vector3(40, 0, 5), Vector3(10, -2, 2))
	await _drag_on([side + Vector3(0, 3, -3), side, side + Vector3(0, -3, 3)])
	# The crown smoothed.
	_editor.turn_to(0.5, 0.9, 95.0)
	await _frames(6)
	await _click_control(_editor._tools["smooth"])
	_editor.set_brush(10.0, 0.7)
	var crown: Vector3 = _surface(Vector3(0, 40, 0), Vector3(0, 6, 0))
	await _drag_on([crown + Vector3(-6, 0, 4), crown, crown + Vector3(6, 0, -4)])
	# The lattice: its top middle handle lifted a little, the whole hair
	# taller.
	_editor.turn_to(0.6, 0.2, 110.0)
	await _frames(6)
	await _click_control(_editor._lattice)
	await _frames(6)
	var handles: PackedVector3Array = mould.lattice_handles()
	var top_middle: Vector3 = handles[1 * 9 + 2 * 3 + 1]
	await _drag_points([_on_screen(top_middle), _on_screen(top_middle + Vector3(0, 4, 0))])
	_check("the lattice's top handle lifts the hair (%.1f LDU)" % (mould.lattice_handles()[16].y
		- top_middle.y), mould.lattice_handles()[16].y > top_middle.y + 1.0)
	await _click_control(_editor._lattice)
	var locked_moved: float = 0.0
	for v: int in original.size():
		if locked[v] >= 1.0:
			locked_moved = maxf(locked_moved, mould.positions[v].distance_to(original[v]))
	_check("not one locked corner moved, by any amount (%.6f)" % locked_moved, locked_moved == 0.0)
	_editor.turn_to(0.75, 0.25, 90.0)
	await _frames(20)
	await _shot("mould_hair_sculpted")
	await _click_control(_editor._walls)
	await _frames(20)
	_check("Check walls says how thin it is: %s" % _editor._status.text,
		_editor._status.text.begins_with("Thinnest wall"))
	await _shot("mould_hair_walls")
	await _click_control(_editor._walls)
	await _type_into(_editor._name, "Quiff")
	await _click_control(_editor._save)
	await _frames(20)
	var hair: String = _figures.figure.part("headwear")
	_check("Save mould puts it on the figure: %s" % hair,
		not _editor.visible and hair.begins_with("bw-3901-m") and _library.parts.has(hair))
	_check("and it is first in the headgear grid",
		_figures._grid.get_child_count() > 1 and str(_figures._grid.get_child(1).get_meta("part")) == hair)

	print("  a club")
	await _click_control(_figures._slot_buttons["accessory"])
	_check("the right hand offers \"%s\"" % _figures._make.text, _figures._make.text == "Make a mould…")
	await _click_control(_figures._make)
	await _frames(10)
	await _click_control(_find_button(_editor, "Club"))
	await _frames(10)
	mould = _editor.mould
	_check("Club starts a club held as 3847 is: %s" % mould.base, mould.base == "3847")
	_editor.turn_to(0.4, 0.2, 140.0)
	await _frames(6)
	await _click_control(_editor._tools["inflate"])
	_editor.set_brush(10.0, 0.6)
	var ball: Vector3 = _surface(Vector3(40, 22, 0), Vector3(8, 22, 0))
	await _drag_on([ball + Vector3(0, -4, 4), ball, ball + Vector3(0, 4, -4)])
	await _click_control(_editor._tools["pull"])
	_editor.set_brush(4.0, 1.0)
	for target: Vector3 in [Vector3(0, 60, 0), Vector3(40, 24, 30), Vector3(40, 30, -30)]:
		var spike: Vector3 = _surface(target, Vector3(0, 22, 0))
		for _n: int in 4:
			await _drag_on([spike, spike])
	await _frames(10)
	await _shot("mould_club")
	await _type_into(_editor._name, "Spiked Club")
	await _click_control(_editor._save)
	await _frames(20)
	var club: String = _figures.figure.part("accessory")
	_check("the club is in his right hand: %s" % club, club.begins_with("bw-3847-m"))
	await _type_into(_figures._name, "Quiff")
	await _frames(30)
	await _shot("mould_builder")

	print("  in the model")
	await _click_control(_find_button(_figures, "Place in model"))
	var centre: Vector2 = root.get_visible_rect().size * 0.5
	var before: int = _world.brick_count()
	await _click_at(centre)
	var standing: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return brick.group == "Quiff")
	var made: int = 0
	for brick: BrickWorld.Brick in standing:
		if PartPrints.bases.has(brick.part_id):
			made += 1
	_check("placed like any figure: %d parts, %d of them moulded here" % [standing.size(), made],
		standing.size() == _figures.figure.assemble(_library).size()
		and _world.brick_count() == before + standing.size() and made == 2)
	await _key(KEY_ESCAPE)
	if not standing.is_empty():
		var at: Vector3 = (standing[0] as BrickWorld.Brick).transform.origin
		var box := AABB(Vector3(at.x - 36, 0, at.z - 20), Vector3(72, 110, 40))
		_camera.frame(box, 1.0)
		_camera.set_view("front")
		await _frames(90)
		await _shot("mould_figure_front")
		_camera.set_view("default")
		_camera.frame(box, 1.0)
		await _frames(90)
		await _shot("mould_figure_corner")
		_camera.set_view("right")
		_camera.frame(box, 1.0)
		await _frames(90)
		await _shot("mould_figure_side")
	_finish()


func _finish() -> void:
	DirAccess.remove_absolute(Minifig.shelf_file)
	_forget(PROBE_DIR)
	print("")
	if _failures == 0:
		print("mould ui probe: a hairstyle and a club were sculpted by hand, worn, held and placed")
	else:
		print("mould ui probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


# -- driving it ----------------------------------------------------------------------


## Where the surface is along a ray from a point outside towards another.
func _surface(from: Vector3, toward: Vector3) -> Vector3:
	var hit: Dictionary = _editor.mould.pick(from, (toward - from).normalized())
	if hit.is_empty():
		_check("a ray from %s towards %s finds the surface" % [from, toward], false)
		return toward
	return hit["at"]


func _on_screen(point: Vector3) -> Vector2:
	return _editor.view().get_global_rect().position + _editor.on_view(point)


## A stroke with the left button through points of the part.
func _drag_on(points: Array) -> void:
	await _drag_points(points.map(func(p: Vector3) -> Vector2: return _on_screen(p)))


func _drag_points(points: Array, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await _drag(points, button)


func _drag(points: Array, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var mask: int = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	_move(points[0], 0)
	await _frames(2)
	_button(points[0], button, true, mask)
	await _frames(2)
	# In small steps, as a hand moves, so a stroke dabs all along its way.
	for n: int in range(1, points.size()):
		var a: Vector2 = points[n - 1]
		var b: Vector2 = points[n]
		var steps: int = maxi(1, ceili(a.distance_to(b) / 4.0))
		for k: int in range(1, steps + 1):
			_move(a.lerp(b, float(k) / steps), mask)
			await process_frame
	_button(points[points.size() - 1], button, false, 0)
	await _frames(3)


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
	if control == null:
		_check("there is a control to click", false)
		return
	var scroll: Node = control.get_parent()
	while scroll != null and not (scroll is ScrollContainer):
		scroll = scroll.get_parent()
	if scroll != null:
		(scroll as ScrollContainer).ensure_control_visible(control)
		await _frames(3)
	await _click_at(control.get_global_rect().get_center())


func _key(code: Key, text: String = "") -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		if not text.is_empty():
			event.unicode = text.unicode_at(0)
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


## A key with its modifiers, as the keymap writes it (Keymap.key_of).
func _chord(accel: int) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = (accel & KEY_CODE_MASK) as Key
		event.physical_keycode = event.keycode
		event.ctrl_pressed = accel & KEY_MASK_CMD_OR_CTRL != 0
		event.shift_pressed = accel & KEY_MASK_SHIFT != 0
		event.alt_pressed = accel & KEY_MASK_ALT != 0
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _type_into(line: LineEdit, text: String) -> void:
	await _click_control(line)
	line.grab_focus()
	line.select_all()
	await _key(KEY_BACKSPACE)
	for character: String in text:
		var code: Key = OS.find_keycode_from_string(character.to_upper())
		if character == " ":
			code = KEY_SPACE
		await _key(code, character)
	await _frames(4)
	line.release_focus()


func _find_button(under: Node, text: String) -> Button:
	for child: Node in under.find_children("*", "Button", true, false):
		if (child as Button).text == text:
			return child
	return null


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/%s.png" % name)


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	DirAccess.remove_absolute(dir)
