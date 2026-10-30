## Drawing prints in the figure builder, the way a person does it.
##
##   godot --path . --resolution 1400x900 --script src/dev/print_ui_probe.gd
##
## Opens the real app, presses M, and in the Head slot presses "Draw a
## print…": draws a captain's face on the canvas with the mouse — eyes in
## one mirrored dab, brows with the line tool, cheeks and a moustache with
## the oval, a grin with the brush — and hair round the back of his head,
## then saves it. The same for a torso, a jacket front and back with a
## badge and words, and for a pair of legs with a belt. Every mark is an
## input event, as a hand would send it. Then the figure is placed on the
## baseplate and photographed from the front and from behind.
##
## Pictures go to shots/print_*.png: look at them. The face is on the
## front of the head, the right way up; the jacket's badge is on the
## figure's left breast (the picture's right) and "CREW" reads from
## behind; the belt is across the hips and the legs below it blue.
##
## Made parts go to user://print_ui_probe_parts/, never the person's own.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _figures: MinifigDialog
var _editor: PrintEditor

const PROBE_DIR := "user://print_ui_probe_parts/"


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	_forget(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
	Minifig.shelf_file = "user://print_ui_probe_shelf.json"
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

	print("  a face")
	await _key(KEY_M)
	await _click_control(_figures._slot_buttons["head"])
	_check("the Head slot offers \"%s\"" % _figures._make.text,
		_figures._make.visible and _figures._make.text == "Draw a print…")
	await _click_control(_figures._make)
	_editor = _figures.print_editor()
	await _frames(10)
	_check("it opens the print editor on the head: %s" % _keys(),
		_editor.visible and _editor.base == "3626c" and _keys() == "face,back")
	await _frames(20)
	# The figure's head is 3626cp01, so the editor starts from its grin;
	# this face is drawn from a clean sheet.
	_check("opened on the figure's printed head, it starts from that print",
		not _editor.paper("face").composite().is_invisible())
	await _choose_start("A clean sheet")
	_check("and \"A clean sheet\" clears it", _editor.paper("face").composite().is_invisible())
	await _draw_face()
	await _frames(20)
	await _shot("print_face_editor")
	var face_paper: PrintPaint = _editor.paper("face")
	var face_area: PartPrints.Area = _editor.areas()[0]
	var middle: int = face_area.size.x / 2
	_check("the eyes are drawn either side of the middle, mirrored",
		face_paper.composite().get_pixel(middle - 38, 74).v < 0.3
		and face_paper.composite().get_pixel(middle + 38, 74).v < 0.3
		and face_paper.composite().get_pixel(middle, 74).a == 0.0)
	# The editor's own Undo and Redo keys are the keymap's.
	var drawn: PackedByteArray = face_paper.composite().get_data()
	await _chord(Keymap.key_of("undo"))
	var undone: bool = face_paper.composite().get_data() != drawn
	await _chord(Keymap.key_of("redo"))
	_check("%s takes the last stroke back, %s puts it back" % [Keymap.listed("undo"), Keymap.listed("redo")],
		undone and face_paper.composite().get_data() == drawn)
	await _click_tab("Back of the head")
	await _draw_hair()
	await _frames(10)
	await _shot("print_face_back_editor")
	await _type_into(_editor._name, "Captain")
	await _click_control(_editor._save)
	await _frames(10)
	var head: String = _figures.figure.part("head")
	_check("Save print puts it on the figure: %s" % head,
		not _editor.visible and head.begins_with("bw-3626c-p") and _library.parts.has(head))
	_check("and it is in the head slot's grid, first",
		_figures._grid.get_child_count() > 1 and str(_figures._grid.get_child(1).get_meta("part")) == head)

	print("  a torso, front and back")
	await _click_control(_figures._slot_buttons["torso"])
	await _click_control(_figures._make)
	await _frames(10)
	_check("the torso's front and back: %s" % _keys(), _editor.visible and _keys() == "front,back")
	await _draw_jacket()
	await _frames(10)
	await _shot("print_torso_editor")
	await _click_tab("Back")
	await _draw_jacket_back()
	await _frames(10)
	await _shot("print_torso_back_editor")
	await _type_into(_editor._name, "Crew Jacket")
	await _click_control(_editor._save)
	await _frames(10)
	var torso: String = _figures.figure.part("torso")
	_check("the jacket is the figure's torso: %s" % torso, torso.begins_with("bw-973-p"))

	print("  a pair of legs")
	await _click_control(_figures._slot_buttons["legs"])
	await _click_control(_figures._make)
	await _frames(10)
	_check("one front over the hips and both legs: %s, %d parts" % [_keys(),
		_editor.areas()[0].parts.size() if not _editor.areas().is_empty() else 0],
		_keys() == "legs" and _editor.areas()[0].parts.size() == 3)
	await _draw_legs()
	await _frames(10)
	await _shot("print_legs_editor")
	await _type_into(_editor._name, "Crew Trousers")
	await _click_control(_editor._save)
	await _frames(10)
	var legs: String = _figures.figure.part("legs")
	var hips: String = _figures.figure.part("hips")
	_check("the trousers are the figure's legs and hips: %s, %s" % [legs, hips],
		legs.begins_with("bw-3816c-p") and hips.begins_with("bw-3815b-p")
		and Minifig._tag(legs) == Minifig._tag(hips))
	var left: String = _figures.figure.left_leg(_library)
	_check("and the left leg is the printed left: %s" % left, left.begins_with("bw-3817c-p"))
	# Moulded in the dark blue they are printed in, as a person would
	# choose, so the unprinted knees and feet match.
	var dark_blue: Control = _figures._swatches.get(272)
	if dark_blue != null:
		await _click_control(dark_blue)
	_check("and coloured dark blue to match: %s" % _library.color(int(_figures.figure.colours["legs"])).name,
		int(_figures.figure.colours["legs"]) == 272)

	# Starting from a print LEGO made: 3626cp01's grin on the canvas.
	await _click_control(_figures._slot_buttons["head"])
	await _click_control(_figures._make)
	await _frames(10)
	_editor.start_from("3626cp01")
	for _n: int in 300:
		if not _editor.paper("face").composite().is_invisible():
			break
		await process_frame
	await _frames(10)
	await _shot("print_from_lego")
	_check("starting from 3626cp01 puts its grin on the canvas",
		not _editor.paper("face").composite().is_invisible())

	print("  a printed tile")
	await _type_into(_editor._other, "3068b")
	await _click_control(_find_button(_editor, "Print on it"))
	await _frames(10)
	_check("\"Print on it\" with 3068b: its top (%s), and no slot" % _keys(),
		_editor.base == "3068b" and _keys().begins_with("top") and _editor.slot.is_empty())
	await _draw_sign()
	await _frames(10)
	await _shot("print_tile_editor")
	await _type_into(_editor._name, "Bakery Sign")
	await _click_control(_editor._save)
	await _frames(10)
	var tile: String = ""
	for id: String in PartPrints.bases:
		if id.begins_with("bw-3068b-p") and _library.parts.has(id):
			tile = id
	_check("the tile is made (%s), and the figure keeps its head" % tile,
		not tile.is_empty() and _figures.figure.part("head") == head
		and _figures._summary.text.contains(tile))

	await _click_control(_figures._make)
	await _frames(6)
	await _key(KEY_ESCAPE)
	_check("Escape closes the editor and leaves the figure as it was",
		not _editor.visible and _figures.visible and _figures.figure.part("head") == head)

	await _type_into(_figures._name, "Captain Crew")
	await _frames(30)
	await _shot("print_builder")

	print("  in the model")
	await _click_control(_find_button(_figures, "Place in model"))
	var centre: Vector2 = root.get_visible_rect().size * 0.5
	var before: int = _world.brick_count()
	await _click_at(centre)
	var standing: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return brick.group == "Captain Crew")
	var printed: int = 0
	for brick: BrickWorld.Brick in standing:
		if PartPrints.bases.has(brick.part_id):
			printed += 1
	_check("placed like any figure: %d parts, %d of them printed here" % [standing.size(), printed],
		standing.size() == _figures.figure.assemble(_library).size()
		and _world.brick_count() == before + standing.size() and printed == 5)
	await _key(KEY_ESCAPE)
	var box := AABB(Vector3(-30, 0, -30), Vector3(60, 80, 60))
	if not standing.is_empty():
		var at: Vector3 = (standing[0] as BrickWorld.Brick).transform.origin
		box = AABB(Vector3(at.x - 24, 0, at.z - 14), Vector3(48, 104, 28))
	_camera.frame(box, 1.0)
	_camera.set_view("front")
	await _frames(90)
	await _shot("print_figure_front")
	_camera.set_view("back")
	_camera.frame(box, 1.0)
	await _frames(90)
	await _shot("print_figure_back")
	_camera.set_view("default")
	_camera.frame(box, 1.0)
	await _frames(90)
	await _shot("print_figure_corner")

	# The tile, held as a part from the bin is, and put down by the figure.
	if not tile.is_empty() and not standing.is_empty():
		_main.call("_on_part_chosen", tile)
		await _frames(10)
		var at: Vector3 = (standing[0] as BrickWorld.Brick).transform.origin
		var beside: Vector2 = _camera.unproject_position(Vector3(at.x + 60, 0.0, at.z))
		var before_tile: int = _world.brick_count()
		await _click_at(beside)
		var placed: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
			return brick.part_id == tile)
		_check("the printed tile goes down on the baseplate like any part (%d)" % placed.size(),
			placed.size() == 1 and _world.brick_count() == before_tile + 1)
		await _key(KEY_ESCAPE)
		_camera.set_view("default")
		_camera.frame(AABB(Vector3(at.x - 30, 0, at.z - 30), Vector3(130, 100, 60)), 1.0)
		await _frames(90)
		await _shot("print_with_tile")

	DirAccess.remove_absolute(Minifig.shelf_file)
	_forget(PROBE_DIR)
	print("")
	if _failures == 0:
		print("print ui probe: a face, a jacket and trousers were drawn by hand, worn and placed")
	else:
		print("print ui probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


# -- the drawings ------------------------------------------------------------------


func _draw_face() -> void:
	var face: PartPrints.Area = _editor.areas()[0]
	var c: float = face.size.x * 0.5
	await _tool("brush")
	await _ink(0)
	_editor.set_brush_size(9)
	await _click_control(_editor._mirror)
	# Both eyes in one dab.
	await _stroke([Vector2(c - 38, 72)])
	await _click_control(_editor._mirror)
	await _ink(15)
	_editor.set_brush_size(3)
	await _stroke([Vector2(c - 41, 69)])
	await _stroke([Vector2(c + 35, 69)])
	# Brows.
	await _click_control(_editor._mirror)
	await _tool("line")
	await _ink(0)
	_editor.set_brush_size(3)
	await _stroke([Vector2(c - 54, 52), Vector2(c - 24, 47)])
	# Cheeks and a moustache.
	await _tool("oval")
	await _ink(29)
	await _stroke([Vector2(c - 78, 96), Vector2(c - 54, 110)])
	await _ink(70)
	await _stroke([Vector2(c - 30, 100), Vector2(c - 2, 114)])
	await _click_control(_editor._mirror)
	# A grin.
	await _tool("brush")
	await _ink(0)
	_editor.set_brush_size(4)
	var grin: Array = []
	for n: int in 21:
		var t: float = float(n) / 20.0
		grin.append(Vector2(c - 36 + 72 * t, 122 + 14 * sin(PI * t)))
	await _stroke(grin)


func _draw_hair() -> void:
	var back: PartPrints.Area = _editor.areas()[1]
	await _tool("brush")
	await _ink(70)
	_editor.set_brush_size(6)
	for n: int in 9:
		var x: float = back.size.x * (0.15 + 0.7 * n / 8.0)
		await _stroke([Vector2(x, 2), Vector2(x + 6, 40), Vector2(x - 4, 80)])


func _draw_jacket() -> void:
	var front: PartPrints.Area = _editor.areas()[0]
	var w: float = front.size.x
	var h: float = front.size.y
	await _tool("fill")
	await _ink(272)
	await _stroke([Vector2(w * 0.5, h * 0.6)])
	await _click_control(_editor._mirror)
	await _tool("line")
	await _ink(15)
	_editor.set_brush_size(7)
	await _stroke([Vector2(w * 0.36, 2), Vector2(w * 0.5 - 4, h * 0.3)])
	await _tool("box")
	_editor._filled.button_pressed = false
	_editor.set_brush_size(3)
	await _ink(71)
	await _stroke([Vector2(w * 0.22, h * 0.68), Vector2(w * 0.38, h * 0.82)])
	await _click_control(_editor._mirror)
	await _tool("line")
	await _ink(71)
	_editor.set_brush_size(2)
	await _stroke([Vector2(w * 0.5, h * 0.3), Vector2(w * 0.5, h - 2)])
	# A badge on his left breast: the picture's right.
	await _tool("oval")
	_editor._filled.button_pressed = true
	await _ink(14)
	await _stroke([Vector2(w * 0.6, h * 0.36), Vector2(w * 0.76, h * 0.54)])
	await _tool("text")
	await _ink(0)
	_editor._word_size.value = 30
	_editor._words.text = "BW"
	_editor.canvas().words = "BW"
	await _stroke([Vector2(w * 0.625, h * 0.5)])


func _draw_jacket_back() -> void:
	var back: PartPrints.Area = _editor.areas()[1]
	await _tool("fill")
	await _ink(272)
	await _stroke([Vector2(back.size.x * 0.5, back.size.y * 0.6)])
	await _tool("text")
	await _ink(15)
	_editor._word_size.value = 64
	_editor.canvas().words = "CREW"
	await _stroke([Vector2(back.size.x * 0.17, back.size.y * 0.5)])


func _draw_sign() -> void:
	var top: PartPrints.Area = _editor.areas()[0]
	var w: float = top.size.x
	var h: float = top.size.y
	await _tool("box")
	_editor._filled.button_pressed = true
	await _ink(15)
	await _stroke([Vector2(w * 0.08, h * 0.08), Vector2(w * 0.92, h * 0.92)])
	_editor._filled.button_pressed = false
	_editor.set_brush_size(6)
	await _ink(4)
	await _stroke([Vector2(w * 0.12, h * 0.12), Vector2(w * 0.88, h * 0.88)])
	await _tool("oval")
	_editor._filled.button_pressed = true
	await _ink(70)
	await _stroke([Vector2(w * 0.3, h * 0.2), Vector2(w * 0.7, h * 0.5)])
	await _tool("text")
	await _ink(0)
	_editor._word_size.value = 64
	_editor.canvas().words = "BAKERY"
	await _stroke([Vector2(w * 0.15, h * 0.75)])


func _draw_legs() -> void:
	var front: PartPrints.Area = _editor.areas()[0]
	var w: float = front.size.x
	var h: float = front.size.y
	await _tool("box")
	_editor._filled.button_pressed = true
	await _ink(272)
	await _stroke([Vector2(0, 0), Vector2(w, h)])
	await _ink(70)
	await _stroke([Vector2(0, 0), Vector2(w, h * 0.13)])
	await _ink(14)
	await _stroke([Vector2(w * 0.45, h * 0.01), Vector2(w * 0.55, h * 0.12)])
	await _click_control(_editor._mirror)
	await _ink(71)
	await _stroke([Vector2(w * 0.12, h * 0.56), Vector2(w * 0.34, h * 0.64)])
	await _click_control(_editor._mirror)


# -- driving it ----------------------------------------------------------------------


func _keys() -> String:
	return ",".join(_editor.areas().map(func(a: PartPrints.Area) -> String: return a.key))


## Click a tab of the editor's tab bar where it is drawn.
func _click_tab(title: String) -> void:
	var bar: TabBar = _editor._tabs
	for n: int in bar.tab_count:
		if bar.get_tab_title(n) == title:
			await _click_at(bar.get_global_rect().position + bar.get_tab_rect(n).get_center())
			return
	_check("there is a tab called %s" % title, false)


## Choose an entry of the Start from menu by its words, as choosing it
## from the list does (a list's rows are not controls to click).
func _choose_start(words: String) -> void:
	var menu: OptionButton = _editor._start
	for n: int in menu.item_count:
		if menu.get_item_text(n).begins_with(words):
			menu.select(n)
			menu.item_selected.emit(n)
			break
	await _frames(6)


func _tool(name: String) -> void:
	await _click_control(_editor._tools[name])


func _ink(code: int) -> void:
	var swatch: Control = _editor.controls_by_name().get("print_ink_%d" % code)
	if swatch == null:
		_editor.set_ink(code)
		return
	await _click_control(swatch)


## A stroke on the canvas through canvas pixels: press at the first, drag
## through the rest, let go at the last.
func _stroke(points: Array) -> void:
	var canvas: PrintCanvas = _editor.canvas()
	var on_screen: Array = points.map(func(p: Vector2) -> Vector2:
		return canvas.get_global_rect().position + canvas.to_screen(p))
	_move(on_screen[0], false)
	await _frames(2)
	_press(on_screen[0], true)
	await _frames(1)
	for n: int in range(1, on_screen.size()):
		_move(on_screen[n], true)
		await process_frame
	_press(on_screen[on_screen.size() - 1], false)
	await _frames(2)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	if held:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _press(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	if down:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _click_at(at: Vector2) -> void:
	_move(at)
	await _frames(6)
	_press(at, true)
	await _frames(2)
	_press(at, false)
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
