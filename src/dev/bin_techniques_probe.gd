## The assistant's worked constructions, from the parts bin, by hand.
##
##   godot --path . --resolution 1280x860 --script src/dev/bin_techniques_probe.gd
##
## Seventy-odd constructions with real parts and coordinates were the
## assistant's alone (Techniques, show_technique): someone building by hand
## could reach none of them. The bin's Techniques tab, beside Recent and
## Favourites, shows each with its picture and why it works. Chosen, one is
## held whole, as a paste is: R turns it, a click puts it down, and one undo
## takes it all back. The colour in hand stands in for its main colour.
##
## Every step is a click or a key sent as an input event against the real
## scene. "Window in a wall" goes down on a wall, and three constructions
## from other groups on the ground; each time the model checks as a design
## is checked, the count rises by the construction's parts, and one undo
## puts the model back. Pictures go to shots/bin_techniques/.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _assistant: Assistant
var _bin: PartsBin


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
	_store = _main.get("_store")
	_assistant = _main.get("_assistant")
	_bin = _main.get("_bin")
	_store.keeps = false
	_main.call("clear_model")
	await _frames(4)

	# A wall to put the window in: two courses of 1 x 8 bricks, in the grey
	# the colour in hand will be.
	_put("3008", 71, Vector3(0, 24, 10))
	_put("3008", 71, Vector3(0, 48, 10))
	_camera.frame(AABB(Vector3(-160, 0, -120), Vector3(320, 160, 240)))
	await _frames(30)
	_check("the wall checks as a design does", _passes())
	_bin.choose_colour(71)
	await _frames(2)

	var tab: Button = _tab()
	_check("the parts bin has a Techniques tab beside Recent and Favourites (%s)"
		% (tab.text if tab != null else "none"), tab != null and _beside_shelves(tab))
	if tab == null:
		_finish()
		return
	await _click(tab.get_global_rect().get_center())
	await _frames(4)
	var groups: int = 0
	var rows: int = 0
	for child: Node in _bin._grid.get_children():
		if child is Label:
			groups += 1
		elif child.has_meta("technique"):
			rows += 1
	_check("it lists every construction (%d of %d) under its group (%d groups)"
		% [rows, Techniques.all().size(), groups], rows == Techniques.all().size()
		and groups == Techniques.GROUPS.size())
	var window: Button = _row("window in a wall")
	_check("each row says why it works (\"%s\")" % _reason_of(window),
		_reason_of(window).begins_with("A window is a frame set into the wall"))
	# The pictures in sight are drawn, each the whole construction.
	var drawn: bool = false
	for _n: int in 400:
		await process_frame
		drawn = _first_rows_drawn(4)
		if drawn:
			break
	_check("the rows in sight get their pictures", drawn)
	await _shot("tab")

	# Window in a wall, onto the wall.
	await _choose("window in a wall")
	var technique: Dictionary = Techniques.named("window in a wall")
	var parts: int = (technique["bricks"] as Array).size()
	_check("choosing it holds it whole (%d of %d parts)" % [
		_builder.carrying.count() if _builder.is_carrying() else 0, parts],
		_builder.is_carrying() and _builder.carrying.count() == parts)
	var colours: Dictionary = {}
	for item: Dictionary in _builder.carrying.items:
		colours[int(item["color"])] = int(colours.get(int(item["color"]), 0)) + 1
	_check("the colour in hand stands in for its main colour, red (%s)" % str(colours),
		colours == {71: 14, 15: 2, 47: 1})
	await _move(_screen(Vector3(0, 48, 10)))
	for want: int in [1, 2, 3, 0]:
		await _key(KEY_R)
		_check("R turns it a quarter (%d)" % _builder.carrying.turns,
			_builder.carrying.turns == want)
	var before: Array = _snapshot()
	var start: int = _count()
	var spot: Vector2 = await _onto_wall()
	_check("its ghost stands on the wall and can go down there", spot != Vector2.INF)
	await _shot("window_ghost")
	await _click(spot)
	_check("a click puts it down: %d bricks from %d, %d more" % [_count(), start,
		_count() - start], _count() == start + parts and not _builder.is_carrying())
	_check("...in the wall, on top of it", _on_the_wall())
	_check("...and the model checks as a design does", _passes())
	await _shot("window_down")
	await _key(KEY_Z, true)
	_check("one undo takes it all back (%d bricks)" % _count(), _snapshot() == before)

	# One from each of three other groups, on the ground.
	for name: String in ["smooth diagonal", "round tower", "corner on a turntable"]:
		await _on_the_ground(name)

	_finish()


func _finish() -> void:
	print("")
	if _failures == 0:
		print("techniques in the bin: every construction can be had by hand, held whole, "
			+ "turned and put down as one undo")
	else:
		print("techniques in the bin: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _on_the_ground(name: String) -> void:
	print("  %s, on the ground" % name)
	var technique: Dictionary = Techniques.named(name)
	_check("%s is in the library (%s)" % [name, technique.get("group", "")],
		not technique.is_empty())
	if technique.is_empty():
		return
	var parts: int = (technique["bricks"] as Array).size()
	var before: Array = _snapshot()
	var start: int = _count()
	await _choose(name)
	_check("choosing it holds it whole (%d of %d parts)" % [
		_builder.carrying.count() if _builder.is_carrying() else 0, parts],
		_builder.is_carrying() and _builder.carrying.count() == parts)
	await _key(KEY_R)
	_check("R turns it (%d)" % _builder.carrying.turns, _builder.carrying.turns == 1)
	var spot: Vector2 = _screen(Vector3(-100, 0, -60))
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	_check("its ghost can go down there", _builder.can_place())
	await _click(spot + Vector2(1, 0))
	_check("a click puts it down: %d more" % (_count() - start), _count() == start + parts)
	_check("...and the model checks as a design does", _passes())
	await _shot(name.replace(" ", "_"))
	await _key(KEY_Z, true)
	_check("one undo takes it all back", _snapshot() == before)


## Its row clicked, and held once its parts are read.
func _choose(name: String) -> void:
	var row: Button = _row(name)
	if row == null:
		_check("%s has a row" % name, false)
		return
	_bin._scroll.ensure_control_visible(row)
	await _frames(4)
	await _click(row.get_global_rect().get_center())
	for _n: int in 60:
		if _builder.is_carrying():
			break
		await process_frame


## The pointer moved over the wall's top until the ghost stands on it as a
## course of it, as a person moves it: the window's bottom bricks on the
## wall's top, in its line. INF when nowhere does.
func _onto_wall() -> Vector2:
	var middle: Vector2 = _screen(Vector3(0, _wall_top(), 10))
	for dy: int in range(-45, 46, 5):
		for dx: int in range(-45, 46, 5):
			var at: Vector2 = middle + Vector2(dx, dy)
			await _move(at)
			if not _builder.can_place():
				continue
			if _in_line(_builder.carrying.placements(_builder)):
				return at
	return Vector2.INF


## The top of the wall, in LDU: where a third course's bottom would be, a
## course above the second's (a part's box takes its studs in).
func _wall_top() -> float:
	var bottoms: Array[float] = []
	for brick: BrickWorld.Brick in _model():
		if brick.part_id == "3008":
			bottoms.append((brick.transform * _library.mesh_for("3008").bounds).position.y)
	if bottoms.size() != 2:
		return INF
	bottoms.sort()
	return bottoms[1] + (bottoms[1] - bottoms[0])


## The window's bottom course, its two 1 x 4s, on the wall's top and over
## its studs: [{part, at}].
func _in_line(placed: Array) -> bool:
	var wall: AABB = (Transform3D(Basis.IDENTITY, Vector3(0, 24, 10))
		* _library.mesh_for("3008").bounds)
	var bottom: int = 0
	for item: Dictionary in placed:
		if str(item["part"]) != "3010":
			continue
		var box: AABB = (item["at"] as Transform3D) * _library.mesh_for("3010").bounds
		if is_equal_approx(box.position.y, _wall_top()) \
				and is_equal_approx(box.position.z, wall.position.z) \
				and is_equal_approx(box.end.z, wall.end.z):
			bottom += 1
	return bottom == 2


func _on_the_wall() -> bool:
	var placed: Array = []
	for brick: BrickWorld.Brick in _model():
		placed.append({"part": brick.part_id, "at": brick.transform})
	return _in_line(placed)


## The model as it stands, checked as the assistant checks a design.
func _passes() -> bool:
	var verdict: Dictionary = _assistant._check(_assistant._model_from_world(), true)
	if not bool(verdict["ok"]):
		print("        " + str(verdict.get("summary", "")))
		print("        " + str(verdict.get("feedback", "")).left(600).replace("\n", "\n        "))
	return bool(verdict["ok"])


func _tab() -> Button:
	for child: Node in _bin._category_row.get_children():
		if str(child.get_meta("category", "")) == "Techniques":
			return child
	return null


func _beside_shelves(tab: Button) -> bool:
	var at: int = tab.get_index()
	return at >= 2 and str(_bin._category_row.get_child(at - 1).get_meta("category", "")) \
		== PartsBin.FAVOURITES


func _row(name: String) -> Button:
	for child: Node in _bin._grid.get_children():
		if str(child.get_meta("technique", "")) == name:
			return child
	return null


func _reason_of(row: Button) -> String:
	if row == null:
		return ""
	for label: Node in row.find_children("*", "Label", true, false):
		if (label as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
			return (label as Label).text
	return ""


func _first_rows_drawn(count: int) -> bool:
	var seen: int = 0
	for child: Node in _bin._grid.get_children():
		if not child.has_meta("tile"):
			continue
		var tile: ThumbTile = child.get_meta("tile")
		if tile.state != ThumbTile.State.READY or tile.texture == null:
			return false
		seen += 1
		if seen >= count:
			return true
	return seen > 0


func _put(part: String, colour: int, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _snapshot() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _model():
		out.append("%s %d %s" % [brick.part_id, brick.color_code,
			LdrModel._line_numbers(brick.transform)])
	out.sort()
	return out


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _frames(count: int) -> void:
	for _n: int in count:
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
	await _frames(3)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/bin_techniques/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/bin_techniques/%s.png" % name)
