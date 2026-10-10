## The minifigure builder, used the way a person uses it.
##
##   godot --path . --resolution 1400x900 --script src/dev/minifig_ui_probe.gd
##
## Opens the real app, presses M, chooses slots, parts and colours by
## clicking them, types a name, presses Place in model, and clicks a stud
## on the baseplate — every step an input event, as a hand would send
## it. Then stands a row of different figures and photographs them
## close, from the front and from a corner, for a person to look at:
## head on the neck, arms at the shoulders, hands in the arms, legs
## under the hips. Pictures go to shots/minifig_*.png.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _figures: MinifigDialog


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
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_figures = _main.get("_figures")
	_main.call("clear_model")
	# A shelf of its own, so a run here never touches the figures the
	# person at this machine kept, and starts with nothing on it.
	Minifig.shelf_file = "user://minifig_ui_probe_shelf.json"
	if FileAccess.file_exists(Minifig.shelf_file):
		DirAccess.remove_absolute(Minifig.shelf_file)
	await _frames(10)

	print("  the builder")
	await _key(KEY_M)
	_check("M opens the minifigure builder", _figures.visible)
	await _wait_for_pictures()
	await _shot("minifig_builder_open")

	# The torso slot, then a printed torso, by clicking them.
	await _click_control(_figures._slot_buttons["torso"])
	_check("clicking Torso shows torsos (%s)" % _figures._found.text,
		_figures._slot == "torso" and _figures._grid.get_child_count() > 20)
	await _type_into(_figures._search, "police")
	_check("typing in the search narrows them (%s)" % _figures._found.text,
		_figures._grid.get_child_count() > 0 and _figures._grid.get_child_count() < 40)
	var chosen: Button = _figures._grid.get_child(0)
	var torso_id: String = str(chosen.get_meta("part"))
	await _click_control(chosen)
	_check("clicking one puts it on the figure: %s" % torso_id,
		_figures.figure.parts["torso"] == torso_id)
	# A colour, by clicking its swatch.
	var blue: Control = _figures._swatches.get(272)
	if blue != null:
		await _click_control(blue)
	_check("clicking a swatch colours it: %s" % _library.color(int(_figures.figure.colours["torso"])).name,
		int(_figures.figure.colours["torso"]) == 272)
	await _click_control(_figures._slot_buttons["headwear"])
	await _type_into(_figures._search, "police hat")
	if _figures._grid.get_child_count() > 0:
		await _click_control(_figures._grid.get_child(0))
	_check("and a hat: %s" % _figures.figure.parts["headwear"],
		not str(_figures.figure.parts["headwear"]).is_empty())
	await _click_control(_figures._name)
	await _type_into(_figures._name, "Officer Bob")
	_check("the name is typed in: %s" % _figures.figure.name, _figures.figure.name == "Officer Bob")
	await _wait_for_pictures()
	await _frames(20)
	await _shot("minifig_builder")

	# Escape with the search box in hand closes it, and M brings it back.
	await _click_control(_figures._search)
	await _key(KEY_ESCAPE)
	_check("Escape closes it even while typing in the search", not _figures.visible)
	await _key(KEY_M)
	_check("and M opens it again, with the figure still on the bench",
		_figures.visible and _figures.figure.name == "Officer Bob")

	# Place in model: the builder holds it; a click on the baseplate stands it there.
	var place: Button = _find_button(_figures, "Place in model")
	await _click_control(place)
	_check("Place in model closes the builder and the figure is held",
		not _figures.visible and _builder.is_holding_figure())
	var middle: Vector2 = root.get_visible_rect().size * 0.5
	var before: int = _world.brick_count()
	await _click_at(middle)
	var officer: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return brick.group == "Officer Bob")
	_check("a click on the baseplate stands it there: %d parts called Officer Bob"
		% officer.size(), officer.size() == _figures.figure.assemble(_library).size()
		and _world.brick_count() == before + officer.size())
	await _key(KEY_ESCAPE)
	_check("Escape puts the figure down from the hand", not _builder.is_holding_figure())
	_check("and it is kept for next time",
		Minifig.shelf().any(func(f: Minifig) -> bool: return f.name == "Officer Bob"))
	await _key(KEY_M)
	await _frames(10)
	await _click_control(_find_button(_figures, "Surprise me"))
	await _wait_for_pictures()
	await _frames(30)
	await _shot("minifig_builder_surprise")
	await _key(KEY_ESCAPE)

	print("  a row of figures, for looking at")
	_main.call("clear_model")
	await _frames(5)
	var row: Array[Minifig] = _row()
	# Three studs apart: a figure is two studs at the feet and three at
	# the hands, so closer than that one stands on the next one's hand.
	var x: float = -120.0
	for figure: Minifig in row:
		var parts: Array[Dictionary] = figure.assemble(_library)
		for item: Dictionary in parts:
			_library.request_mesh(str(item["part"]), true)
		for _n: int in 600:
			if parts.all(func(item: Dictionary) -> bool:
					return _library.mesh_for(str(item["part"])) != null):
				break
			await process_frame
		var at: Transform3D = _builder.settle_figure(Vector3(x, 0.0, 10.0), 0)
		var ids: PackedInt64Array = _builder.put_figure(parts, figure.name, at)
		_check("%s stands in the model, %d parts" % [figure.name, ids.size()],
			ids.size() == parts.size())
		x += 60.0
	await _frames(10)
	var box := AABB(Vector3(-150, 0, -20), Vector3(300, 130, 50))
	_camera.frame(box, 1.0)
	_camera.set_view("front")
	await _frames(90)
	await _shot("minifig_figures_front")
	_camera.set_view("default")
	_camera.frame(box, 1.0)
	await _frames(90)
	await _shot("minifig_figures_corner")
	# One close up.
	_camera.frame(AABB(Vector3(-145, 0, -10), Vector3(50, 120, 30)), 1.0)
	_camera.set_view("isometric")
	await _frames(90)
	await _shot("minifig_close")

	DirAccess.remove_absolute(Minifig.shelf_file)
	print("")
	if _failures == 0:
		print("minifig ui probe: a figure was made by clicking, named, placed on a stud and photographed")
	else:
		print("minifig ui probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


## Five figures that between them use every kind of part: a hat, a
## helmet, a printed torso, short legs, a neck accessory, and things
## held short and long.
func _row() -> Array[Minifig]:
	var out: Array[Minifig] = []
	var plain := Minifig.new()
	plain.name = "Classic"
	out.append(plain)
	var knight := Minifig.new()
	knight.name = "Knight"
	knight.parts["headwear"] = "3844"
	knight.colours["headwear"] = 71
	knight.parts["accessory"] = "4497"
	knight.colours["accessory"] = 70
	knight.colours["torso"] = 71
	knight.colours["arms"] = 71
	knight.colours["legs"] = 0
	knight.colours["hips"] = 0
	out.append(knight)
	var child := Minifig.new()
	child.name = "Child"
	child.parts["legs"] = "41879a"
	child.colours["legs"] = 1
	child.parts["head"] = "3626cp07"
	out.append(child)
	var diver := Minifig.new()
	diver.name = "Diver"
	diver.parts["headwear"] = "3842a"
	diver.colours["headwear"] = 15
	diver.parts["neck"] = "3838"
	diver.colours["neck"] = 0
	diver.colours["torso"] = 15
	diver.colours["arms"] = 15
	diver.colours["legs"] = 15
	diver.colours["hips"] = 15
	out.append(diver)
	var pirate := Minifig.new()
	pirate.name = "Pirate"
	pirate.parts["accessory"] = "2530"
	pirate.colours["accessory"] = 72
	pirate.dress_torso("973p32" if _library.parts.has("973p32") else "973")
	pirate.parts["head"] = "3626bp35" if _library.parts.has("3626bp35") else "3626cp01"
	pirate.parts["headwear"] = "2543" if _library.parts.has("2543") else "3901"
	pirate.colours["headwear"] = 4
	out.append(pirate)
	return out


# -- driving it ----------------------------------------------------------------


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## Until the thumbnails in sight are drawn, or a while has passed.
func _wait_for_pictures() -> void:
	for _n: int in 900:
		var waiting: int = 0
		for cell: Node in _figures._grid.get_children():
			if cell is Button and (cell as Button).icon == null \
					and not str(cell.get_meta("part")).is_empty():
				waiting += 1
		if waiting == 0 or (_n > 300 and waiting < 4):
			return
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _press(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
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
	# Scrolled into view first, as a person would scroll to it.
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


## Clear a line and type into it, a key at a time.
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
