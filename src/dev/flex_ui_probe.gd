## Laying a hose and a chain by hand, the way a person does it, in the real
## scene: Build, Hose, tube or chain…, a click on one pin hole and on
## another, a bend added and dragged, undone and done again; a chain put
## round two gears with two clicks; saved, reopened and reshaped from the
## pieces alone.
##
##   godot --path . --resolution 1400x900 --script src/dev/flex_ui_probe.gd
##
## Every click is an input event at the place on screen the connector is.
## Pictures go to shots/flex/.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Shell
var _flex: FlexTool
var _tree: Assemblies


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
	_shell = _main.get("_shell")
	_flex = _main.get("_flex")
	_tree = _shell.assemblies
	_main.call("clear_model")

	# Two Technic bricks with their holes to the front, four studs apart,
	# and two 24-tooth gears above them, axles to the front too.
	_put("3700", Vector3(0, 24, 0))
	_put("3700", Vector3(80, 24, 0))
	_put("3648b", Vector3(-20, 110, 0))
	_put("3648b", Vector3(110, 110, 0))
	await _frames(3)
	_camera.set_view("front")
	_camera.frame(AABB(Vector3(-80, 0, -40), Vector3(240, 160, 140)), 1.3)
	await _frames(60)
	_camera.set_view("default")
	await _frames(60)

	await _a_hose()
	await _a_chain()
	await _saved_and_reshaped()

	print("")
	if _failures == 0:
		print("flex by hand: a tube laid between two holes, bent, undone, a chain round two "
			+ "gears, saved, reopened and reshaped")
	else:
		print("flex by hand: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _a_hose() -> void:
	print("  a pneumatic tube between two pin holes")
	_check("Build has Hose, tube or chain…", _shell.menu_id("flex") >= 0 and _shell.can("flex"))
	_shell.run("flex")
	await _frames(3)
	_check("it opens the tool and its panel, asking for the first end (%s)" % _flex._told.text,
		_flex.active and _flex.panel.visible and _flex.stage == "start")
	await _click((_flex._kind_buttons["pneumatic_tube"] as Button).get_global_rect().get_center())
	var nine: int = -1
	var lengths: Array = Flex.lengths_of(_library, "pneumatic_tube")
	for n: int in lengths.size():
		if str(lengths[n]["name"]).contains(" 9L"):
			nine = n
	_flex._length_picker.select(nine + 1)
	_flex._length_picker.item_selected.emit(nine + 1)
	var holes: Array = _holes()
	_check("both holes are things to click (%d)" % holes.size(), holes.size() == 2)
	if holes.size() != 2:
		return
	var bricks_before: int = _count()
	await _move(_screen((holes[0] as Flex.Anchor).at))
	_check("pointing at the first hole lights it", _flex._hover != null
		and _flex._hover.brick == (holes[0] as Flex.Anchor).brick)
	await _shot("1_aimed")
	await _click(_screen((holes[0] as Flex.Anchor).at))
	_check("a click picks it and asks for the other end (%s)" % _flex._told.text,
		_flex.stage == "end" and _flex._ends.size() == 1)
	await _click(_screen((holes[1] as Flex.Anchor).at))
	await _frames(10)
	var item: String = _flex._item
	_check("a click on the second lays it, as one item (%s, %d parts)" % [item,
		_tree.ids_under(item).size()], not item.is_empty() and _tree.ids_under(item).size() > 10
		and _count() == bricks_before + _tree.ids_under(item).size())
	_check("it is the 9L, 180 LDU along it (%.1f)" % _flex._laid.length,
		absf(_flex._laid.length - 180.0) < 0.5)
	_check("with nothing to warn about (%s)" % _flex._status.text, _flex._laid.warnings.is_empty())
	var parts: Dictionary = {}
	for brick: BrickWorld.Brick in _tree.bricks_under(item):
		parts[brick.part_id] = true
	_check("its parts are the tube's LDraw segments (%s)" % str(parts.keys()),
		parts.keys().all(func(p: String) -> bool: return p == "71533k02" or p == "71533k03"))
	_check("the history says so (%s)" % _builder.history_words(1)[0],
		_builder.history_words(1)[0].begins_with("laid"))
	await _shot("2_laid")

	var shape: Array = _shape(item)
	_flex.add_bend()
	await _frames(10)
	_check("Add a bend puts a point on it to drag", _flex.handles().size() == 1)
	var handle: Vector3 = _flex.handles()[0]
	var from: Vector2 = _screen(handle)
	# Too far first: up and over, tighter than a tube bends.
	var steps: int = _builder.history_depth()
	await _drag(from, from + Vector2(0, -260))
	await _frames(10)
	_check("dragged so far it would kink, it is left as it was, and says so (%s)"
		% _flex._status.text, _same(_shape(item), shape) and _builder.history_depth() == steps
		and _flex._status.text.contains("left as it was"))
	await _drag(from, from + Vector2(0, -40))
	await _frames(10)
	var moved: Array = _shape(item)
	_check("dragging it up a little reshapes the tube (its highest point %.0f, was %.0f)" % [
		_highest(moved), _highest(shape)], _highest(moved) > _highest(shape) + 8.0)
	_check("...still 180 LDU (%.1f), still one item, bent no tighter than it goes (%.0f)" % [
		_flex._laid.length, _flex._laid.tightest], absf(_flex._laid.length - 180.0) < 0.5
		and _tree.ids_under(item).size() > 10 and _flex._laid.warnings.is_empty())
	_check("...and the history says reshaped (%s)" % _builder.history_words(1)[0],
		_builder.history_words(1)[0].begins_with("reshaped"))
	await _shot("3_bent")
	_builder.undo()
	await _frames(5)
	_check("one undo puts the tube back as it was", _same(_shape(item), shape))
	_builder.redo()
	await _frames(5)
	_check("and redo bends it again", _same(_shape(item), moved))
	_flex.leave()
	await _frames(3)
	_check("Done closes the tool and leaves the tube selected (%d)" % _builder.selection.size(),
		not _flex.active and _builder.selection.size() == _tree.ids_under(item).size())
	_builder.clear_selection()
	var piece: int = _tree.ids_under(item)[_tree.ids_under(item).size() / 2]
	await _click((_shell.toolbar._buttons["mode_select"] as Button).get_global_rect().get_center())
	await _click(_screen(_world.get_brick(piece).transform.origin))
	_check("a click on the tube takes all of it (%d of %d)" % [_builder.selection.size(),
		_tree.ids_under(item).size()], _builder.selection.size() == _tree.ids_under(item).size())
	_check("and Edit can reshape it", _shell.can("reshape_flex"))
	_builder.clear_selection()
	# Its end pin sits in a hole, which reads as a hinge: Pose once offered
	# the tube a slider, and swung it off its other hole.
	var pose: Control = _main.get("_pose")
	if pose != null:
		_shell.run("pose")
		await _frames(5)
		var offered: Array = (pose.get("poser") as Poser).joints.map(
			func(j: Poser.Joint) -> String: return j.path)
		_check("Pose offers the laid tube no slider (%s)" % str(offered), not offered.has(item))
		pose.call("close")
		await _frames(3)


func _a_chain() -> void:
	print("  a chain round two gears")
	_shell.run("flex")
	await _frames(3)
	await _click((_flex._kind_buttons["chain"] as Button).get_global_rect().get_center())
	_check("for a chain it asks for sprockets (%s)" % _flex._told.text, _flex.stage == "sprockets")
	var gears: Array = _model().filter(func(b: BrickWorld.Brick) -> bool:
		return b.part_id == "3648b")
	for gear: BrickWorld.Brick in gears:
		var sprocket: Flex.Sprocket = Flex.sprocket_of(gear, _library)
		await _click(_screen(sprocket.centre + Vector3(0, sprocket.radius * 0.8, 10)))
	await _frames(10)
	var item: String = _flex._item
	var links: Array = _tree.bricks_under(item)
	_check("two clicks lay a chain round them (%s, %d links)" % [item, links.size()],
		links.size() > 10 and links.all(func(b: BrickWorld.Brick) -> bool:
			return b.part_id == "3711"))
	var entries: Array = []
	for n: int in links.size():
		entries.append([n, (links[n] as BrickWorld.Brick).transform, _library.mesh_for("3711")])
	var held: Dictionary = Joints.rounds(entries)
	var joined: int = 0
	for n: int in links.size():
		if (held.get(n, {}) as Dictionary).has((n + 1) % links.size()):
			joined += 1
	_check("every link on its neighbour's pins, all the way round (%d of %d)" % [joined,
		links.size()], joined == links.size())
	await _shot("4_chain")
	_flex.leave()
	_builder.clear_selection()


func _saved_and_reshaped() -> void:
	print("  saved, reopened, and reshaped from its pieces")
	var text: String = _store.to_text("Flex Probe")
	var files: Array = []
	for line: String in text.split("\n"):
		if line.begins_with("0 FILE "):
			files.append(line.substr(7))
	_check("the file has a sub-model for the tube and one for the chain (%s)" % str(files),
		files.size() == 3)
	var tube_lines: int = 0
	var section: String = ""
	var foreign: int = 0
	for line: String in text.split("\n"):
		if line.begins_with("0 FILE "):
			section = line.substr(7)
		elif line.begins_with("1 ") and section.contains("tube"):
			tube_lines += 1
			if not (line.ends_with("71533k02.dat") or line.ends_with("71533k03.dat")):
				foreign += 1
	_check("the tube's section is its segments and nothing else (%d lines)" % tube_lines,
		tube_lines > 10 and foreign == 0)
	var before: int = _count()
	_store.open_text(text, "flex probe")
	await _frames(10)
	_check("it reads back whole (%d parts)" % _count(), _count() == before)
	var tube: String = ""
	for path: String in _tree.paths():
		if path.contains("Tube"):
			tube = path
	_check("the tube is a sub-assembly again (%s)" % tube, not tube.is_empty())
	if tube.is_empty():
		return
	var shape: Array = _shape(tube)
	var ids: PackedInt64Array = _tree.ids_under(tube)
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(ids.size())
	_check("Edit can reshape what was read back", _shell.can("reshape_flex"))
	_shell.run("reshape_flex")
	await _frames(5)
	_check("Reshape opens it (%s)" % _flex.stage, _flex.active and _flex.stage == "shaping")
	_check("its ends are found on the two holes again",
		_flex._ends.size() == 2 and _flex._ends.all(func(e: Dictionary) -> bool:
			return str(e.get("free", "")) != "yes"))
	_check("its length is the 9L's (%s)" % _flex._real_id,
		_library.parts.has(_flex._real_id) and _library.parts[_flex._real_id].name.contains(" 9L"))
	_check("its bend read back as points to drag (%d)" % _flex.handles().size(),
		_flex.handles().size() >= 1)
	var laid_again: Flex.Laid = _flex._compute()
	var worst: float = 0.0
	for point: Vector3 in shape:
		worst = maxf(worst, point.distance_to(laid_again.path.at(FlexTool._along(laid_again.path,
			point))))
	_check("laid again from what was read, it lies within %.1f LDU of where it was" % worst,
		worst < 6.0)
	await _shot("5_reshaping")
	_flex.leave()


# -- helpers -----------------------------------------------------------------------


func _holes() -> Array:
	var out: Array = []
	for anchor: Flex.Anchor in Flex.anchors_in(_world, _library, "pneumatic_tube"):
		if anchor.kind == "pin_hole":
			out.append(anchor)
	out.sort_custom(func(a: Flex.Anchor, b: Flex.Anchor) -> bool: return a.at.x < b.at.x)
	return out


func _shape(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _tree.bricks_under(path):
		out.append(brick.transform.origin)
	return out


func _highest(points: Array) -> float:
	var top: float = -INF
	for point: Vector3 in points:
		top = maxf(top, point.y)
	return top


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var left: Array = a.duplicate()
	var right: Array = b.duplicate()
	var key := func(x: Vector3, y: Vector3) -> bool:
		return x.x < y.x if not is_equal_approx(x.x, y.x) else x.y < y.y
	left.sort_custom(key)
	right.sort_custom(key)
	for n: int in left.size():
		if (left[n] as Vector3).distance_to(right[n]) > 0.01:
			return false
	return true


func _put(part: String, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, 7, where)
	_builder.register(brick_id, part, where)


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


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
	await _frames(3)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	if down:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _drag(from: Vector2, to: Vector2) -> void:
	await _move(from)
	_button(from, true)
	await _frames(2)
	for n: int in range(1, 9):
		await _move(from.lerp(to, float(n) / 8.0), true)
	_button(to, false)
	await _frames(4)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/flex"))
	var path: String = "res://shots/flex/%s.png" % name
	image.save_png(ProjectSettings.globalize_path(path))
	print("    picture: shots/flex/%s.png" % name)
