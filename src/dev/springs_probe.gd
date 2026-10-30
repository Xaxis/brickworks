## Rubber bands round pulleys and springs that stretch, by hand, in the real
## scene. A band picked from the bin and clicked onto two wedge belt wheels
## five studs apart, then another onto three in a triangle, each in four
## actions or fewer; one onto two wheels turned and tilted, as a session
## over MCP lays one; a wheel nudged and its band following. A spring from
## Build, Hose, tube or chain… between two pin holes four studs apart,
## stretched to six by nudging one, and a shock absorber picked from the
## bin. Saved, opened again, and found the same.
##
##   godot --path . --resolution 1400x900 --script src/dev/springs_probe.gd
##
## The loop is measured off the parts laid, not the tool's own sums: the
## pieces' lengths added up against the tangents and arcs worked out by hand
## from the parts' own files (4185a.dat's groove is a cylinder of radius
## 27.5; 85546.dat's band is 1.906 thick either side of its centreline).
## A band drawn straight, or round the wrong side, is too short and touches
## no groove. Pictures go to shots/springs/, named for the window's size;
## the saved file to shots/springs/saved.ldr.
extends SceneTree

const GROOVE := 27.5
const HALF := 1.906
const BAND := "85546"

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
var _bin: PartsBin
var _size: String = ""


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
	_bin = _main.get("_bin")
	_tree = _shell.assemblies
	var size: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [size.x, size.y]
	print("  a %s window" % _size)
	for _n: int in 600:
		if _library.search_ready():
			break
		await process_frame
	_main.call("clear_model")

	await _two_pulleys()
	await _triangle()
	await _turned_and_tilted()
	await _pulley_moved()
	await _spring()
	await _shock()
	await _saved_and_opened()

	print("")
	if _failures == 0:
		print("springs: bands round two wheels and three, turned and tilted, following a wheel "
			+ "moved; a spring stretched from 4 to 6 studs; a shock; saved and opened the same")
	else:
		print("springs: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- bands ---------------------------------------------------------------------------


func _two_pulleys() -> void:
	print("  a band round two wedge belt wheels five studs apart")
	var a: int = _put("4185a", Transform3D(Basis.IDENTITY, Vector3(0, 60, 0)))
	var b: int = _put("4185a", Transform3D(Basis.IDENTITY, Vector3(100, 60, 0)))
	# The wheels right of the middle, clear of the tool's panel over the
	# model's top left.
	await _look_at(AABB(Vector3(-120, 40, -10), Vector3(300, 120, 20)))
	await _shot("1_before")
	var before: int = _count()
	var depth: int = _builder.history_depth()
	var actions: int = await _pick_from_bin(BAND)
	_check("picking the band from the bin opens the tool on it (%s, %s)" % [_flex.stage, _flex._told.text],
		_flex.active and _flex.stage == "pulleys" and _flex._band == BAND)
	await _move(_screen(_rim(a)))
	var over: Control = root.gui_get_hovered_control()
	_check("pointing at a wheel lights it (%s over it)" % (over.name if over != null else "nothing"),
		_flex._hover_round != null and _flex._hover_round.brick == a)
	await _click(_screen(_rim(a)))
	actions += 1
	_check("a click puts the band round it (%s)" % _flex._told.text, _flex._rounds.size() == 1)
	await _click(_screen(_rim(b)))
	actions += 1
	await _frames(10)
	var item: String = _flex._item
	_check("a click on the second lays it, in %d actions (%s, %d pieces)" % [actions, item,
		_tree.ids_under(item).size()], actions <= 4 and not item.is_empty()
		and _count() == before + _tree.ids_under(item).size())
	if item.is_empty():
		return
	var hand: float = 200.0 + TAU * (GROOVE + HALF)
	_loop_checks(item, [a, b], hand)
	_check("one step in the history (%s)" % _builder.history_words(1)[0],
		_builder.history_depth() == depth + 1 and _builder.history_words(1)[0].begins_with("laid"))
	await _shot("2_two_wheels")
	_shell.run("undo")
	await _frames(5)
	_check("one undo takes it off whole (%d parts)" % _count(), _count() == before)
	_shell.run("redo")
	await _frames(5)
	_check("and redo puts it back (%d parts)" % _count(), _count() > before)
	_flex.leave()


func _triangle() -> void:
	print("  a band round three wheels in a triangle")
	var a: int = _put("4185a", Transform3D(Basis.IDENTITY, Vector3(240, 60, 0)))
	var b: int = _put("4185a", Transform3D(Basis.IDENTITY, Vector3(340, 60, 0)))
	var c: int = _put("4185a", Transform3D(Basis.IDENTITY, Vector3(290, 140, 0)))
	await _look_at(AABB(Vector3(200, 20, -10), Vector3(180, 160, 20)))
	var before: int = _count()
	var depth: int = _builder.history_depth()
	var actions: int = await _pick_from_bin(BAND)
	for brick_id: int in [a, b, c]:
		await _click(_screen(_rim(brick_id)))
		actions += 1
	await _frames(10)
	var item: String = _flex._item
	_check("three clicks lay it round all three, in %d actions (%s)" % [actions, _flex._told.text],
		actions <= 4 and not item.is_empty() and _flex._rounds.size() == 3)
	if item.is_empty():
		return
	var hand: float = 100.0 + 2.0 * Vector2(50, 80).length() + TAU * (GROOVE + HALF)
	_loop_checks(item, [a, b, c], hand)
	_check("however many clicks it took, one step in the history (%d)" % (
		_builder.history_depth() - depth), _builder.history_depth() == depth + 1)
	await _shot("3_triangle")
	_shell.run("undo")
	await _frames(5)
	_check("one undo takes it off whole (%d parts)" % _count(), _count() == before)
	_shell.run("redo")
	await _frames(5)
	_flex.leave()


func _turned_and_tilted() -> void:
	print("  a band round two wheels turned and tilted, as a session lays one")
	var turned := Basis(Vector3(0.3, 1.0, 0.2).normalized(), 0.7) * Basis(Vector3.RIGHT, 0.5)
	var from := Vector3(480, 90, 0)
	var a: int = _put("4185a", Transform3D(turned, from))
	var b: int = _put("4185a", Transform3D(turned, from + turned * Vector3(100, 0, 0)))
	var laid: Flex.Laid = await _flex.lay("band", [], [a, b], 4, "", BAND)
	await _frames(5)
	var item: String = _flex.laid_item()
	_check("laid (%s)" % ("; ".join(laid.notes) if laid != null else "nothing"),
		laid != null and not laid.pieces.is_empty())
	_loop_checks(item, [a, b], 200.0 + TAU * (GROOVE + HALF))
	await _look_at(AABB(from - Vector3(60, 60, 60), Vector3(220, 160, 140)))
	await _shot("4_turned_and_tilted")


## The first band's wheel nudged a stud to the right, as the arrow key does:
## the band follows it, longer by twice the stud, in the same undo step.
func _pulley_moved() -> void:
	print("  a wheel moved, and its band following")
	var wheel: int = _brick_at("4185a", Vector3(100, 60, 0))
	var item: String = _band_round(wheel)
	_check("the first band and its second wheel are there (%s)" % item,
		not item.is_empty() and wheel != 0)
	if item.is_empty() or wheel == 0:
		return
	await _look_at(AABB(Vector3(-40, 20, -10), Vector3(200, 80, 20)))
	_select([wheel])
	var depth: int = _builder.history_depth()
	await _key(KEY_RIGHT)
	await _frames(5)
	var moved: Vector3 = _world.get_brick(wheel).transform.origin
	_check("the arrow key moves the wheel a stud (%s, %s)" % [str(moved), str(_builder.refused_by)],
		moved.distance_to(Vector3(120, 60, 0)) < 0.01)
	_loop_checks(_band_round(wheel), [_brick_at("4185a", Vector3(0, 60, 0)), wheel],
		240.0 + TAU * (GROOVE + HALF))
	_check("the move and the band's following are one step (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	await _shot("5_wheel_moved")
	_shell.run("undo")
	await _frames(5)
	_check("one undo puts the wheel back", _world.get_brick(wheel) != null
		and _world.get_brick(wheel).transform.origin.distance_to(Vector3(100, 60, 0)) < 0.01)
	_loop_checks(_band_round(wheel), [_brick_at("4185a", Vector3(0, 60, 0)), wheel],
		200.0 + TAU * (GROOVE + HALF), "and its band with it")
	_builder.clear_selection()


## Every check of a band laid round [param wheels]: its pieces add up to
## [param hand] within 1 LDU, and lie in each wheel's groove, its
## centreline [constant HALF] out from the groove's bottom, round an arc of
## each and nowhere inside one.
func _loop_checks(item: String, wheels: Array, hand: float, what: String = "") -> void:
	var drawn: float = 0.0
	var points: Array = []
	for brick: BrickWorld.Brick in _tree.bricks_under(item):
		if not brick.part_id.begins_with(Bands.SEGMENT_PREFIX):
			continue
		drawn += brick.transform.basis.y.length()
		points.append(brick.transform.origin)
	_check("%sits pieces come to %.2f LDU round, by hand %.2f" % [what + ": " if not what.is_empty()
		else "", drawn, hand], absf(drawn - hand) <= 1.0)
	for wheel_id: int in wheels:
		var wheel: BrickWorld.Brick = _world.get_brick(wheel_id)
		if wheel == null:
			_check("wheel %d is there" % wheel_id, false)
			continue
		var back: Transform3D = wheel.transform.affine_inverse()
		var on: int = 0
		var inside: int = 0
		for point: Vector3 in points:
			var local: Vector3 = back * point
			var out: float = Vector2(local.x, local.y).length()
			if absf(local.z) < 0.3 and absf(out - (GROOVE + HALF)) < 0.3:
				on += 1
			if absf(local.z) < 6.0 and out < GROOVE + HALF - 0.5:
				inside += 1
		_check("  round wheel %d's groove: %d pieces on it, %d inside it" % [wheel_id, on, inside],
			on >= 6 and inside == 0)


# -- springs -------------------------------------------------------------------------


func _spring() -> void:
	print("  a spring between two pin holes, four studs apart, stretched to six")
	var a: int = _put("3700", Transform3D(Basis.IDENTITY, Vector3(0, 224, 0)))
	var b: int = _put("3700", Transform3D(Basis.IDENTITY, Vector3(80, 224, 0)))
	await _look_at(AABB(Vector3(-40, 190, -20), Vector3(220, 60, 40)))
	var holes: Array = [_hole_of(a), _hole_of(b)]
	_check("both bricks have a pin hole", holes[0] != null and holes[1] != null)
	if holes[0] == null or holes[1] == null:
		return
	var before: int = _count()
	var depth: int = _builder.history_depth()
	_shell.run("flex")
	await _frames(3)
	await _click((_flex._kind_buttons["spring"] as Button).get_global_rect().get_center())
	_check("Spring or shock asks for its first end (%s)" % _flex._told.text,
		_flex.kind == "spring" and _flex.stage == "start")
	if _flex._spring != "70038":
		var springs: Array = _flex._spring_choices()
		_flex._length_picker.select(springs.find("70038"))
		_flex._length_picker.item_selected.emit(springs.find("70038"))
	await _click(_screen((holes[0] as Flex.Anchor).at))
	await _click(_screen((holes[1] as Flex.Anchor).at))
	await _frames(10)
	var item: String = _flex._item
	_check("two clicks lay it (%s; %s)" % [item, _flex._told.text], not item.is_empty()
		and _count() == before + 1)
	var read: Dictionary = Bands.spring_read(_pieces(item))
	var turns: int = int(read.get("turns", 0))
	_check("as many turns as four studs give a 7 LDU pitch: %d" % turns, turns == roundi(80.0 / 7.0))
	_spring_ends(item, a, b, 80.0)
	_check("one step in the history", _builder.history_depth() == depth + 1)
	await _shot("6_spring_4_studs")
	_flex.leave()
	_select([b])
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT)
	await _frames(5)
	_check("two presses of the arrow key move the brick two studs (%s, %s)"
		% [str(_world.get_brick(b).transform.origin), str(_builder.refused_by)],
		_world.get_brick(b).transform.origin.distance_to(Vector3(120, 224, 0)) < 0.01)
	item = _item_named("Spring", 0)
	read = Bands.spring_read(_pieces(item))
	_check("stretched to six studs it keeps its %d turns (%d)" % [turns, int(read.get("turns", 0))],
		int(read.get("turns", 0)) == turns)
	_spring_ends(item, a, b, 120.0)
	await _shot("7_spring_6_studs")
	_shell.run("undo")
	await _frames(5)
	item = _item_named("Spring", 0)
	_spring_ends(item, a, b, 100.0, "one undo takes back one stud, the spring with it: ")
	_shell.run("redo")
	await _frames(5)
	_builder.clear_selection()


## The spring at [param item] runs from brick [param a]'s hole's face to
## [param b]'s, [param length] apart.
func _spring_ends(item: String, a: int, b: int, length: float, what: String = "") -> void:
	var read: Dictionary = Bands.spring_read(_pieces(item))
	if read.is_empty():
		_check(what + "there is a spring", false)
		return
	var faces: Array = []
	for brick_id: int in [a, b]:
		var hole: Flex.Anchor = _hole_of(brick_id)
		faces.append([hole.at + hole.axis * hole.reach, hole.at - hole.axis * hole.reach])
	var near: Callable = func(point: Vector3, pair: Array) -> float:
		return minf(point.distance_to(pair[0]), point.distance_to(pair[1]))
	var gap_a: float = near.call(read["a"], faces[0])
	var gap_b: float = near.call(read["b"], faces[1])
	var span: float = (read["a"] as Vector3).distance_to(read["b"])
	_check("%sits ends are on the holes' faces (%.2f, %.2f LDU off), %.1f LDU apart"
		% [what, gap_a, gap_b, span], gap_a < 0.1 and gap_b < 0.1 and absf(span - length) < 0.1)


func _shock() -> void:
	print("  a shock absorber picked from the bin, between two pin holes five studs apart")
	var a: int = _put("3700", Transform3D(Basis.IDENTITY, Vector3(260, 224, 0)))
	var b: int = _put("3700", Transform3D(Basis.IDENTITY, Vector3(360, 224, 0)))
	await _look_at(AABB(Vector3(220, 190, -40), Vector3(180, 60, 80)))
	var before: int = _count()
	var actions: int = await _pick_from_bin("73129")
	_check("picking it from the bin opens the tool on it (%s)" % _flex._told.text,
		_flex.active and _flex.kind == "spring" and _flex._spring == "73129")
	await _click(_screen(_hole_of(a).at))
	await _click(_screen(_hole_of(b).at))
	actions += 2
	await _frames(10)
	var item: String = _flex._item
	var parts: Array = _pieces(item).map(func(p: Dictionary) -> String: return str(p["part"]))
	parts.sort()
	_check("laid in %d actions as its cylinder, a coil and its rod (%s)" % [actions, str(parts)],
		actions <= 4 and _count() == before + 3 and parts.has("4255") and parts.has("4254"))
	_check("counted as the one shock absorber (%s)" % Flex.real_part(_library, "spring", _pieces(item)),
		Flex.real_part(_library, "spring", _pieces(item)) == "73129")
	await _shot("8_shock")
	_flex.leave()


# -- saved and opened ----------------------------------------------------------------


func _saved_and_opened() -> void:
	print("  saved, opened again, and found the same")
	var bands: Dictionary = {}
	var springs: Dictionary = {}
	for path: String in _tree.paths():
		var pieces: Array = _pieces(path)
		match Flex.kind_of(pieces.map(func(p: Dictionary) -> String: return str(p["part"]))):
			"band":
				bands[path] = _length_of(pieces)
			"spring":
				springs[path] = Bands.spring_read(pieces)
	var text: String = _store.to_text("Springs Probe")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/springs"))
	var file: FileAccess = FileAccess.open(ProjectSettings.globalize_path("res://shots/springs/saved.ldr"),
		FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("    saved: shots/springs/saved.ldr")
	_check("the file carries the pieces it is made of (%d FILE sections)" % text.count("0 FILE "),
		text.contains("0 FILE bw-belt-85546.dat") and text.contains("0 FILE bw-coil-70038-"))
	var before: int = _count()
	_store.open_text(text, "springs probe")
	for _n: int in 120:
		await process_frame
		if _count() == before:
			break
	await _frames(10)
	_check("it reads back whole (%d parts of %d)" % [_count(), before], _count() == before)
	var bands_again: Array = []
	var springs_again: Array = []
	for path: String in _tree.paths():
		var pieces: Array = _pieces(path)
		match Flex.kind_of(pieces.map(func(p: Dictionary) -> String: return str(p["part"]))):
			"band":
				bands_again.append(_length_of(pieces))
			"spring":
				springs_again.append(Bands.spring_read(pieces))
	var lengths: Array = bands.values()
	lengths.sort()
	bands_again.sort()
	var same: bool = lengths.size() == bands_again.size()
	for n: int in mini(lengths.size(), bands_again.size()):
		same = same and absf(float(lengths[n]) - float(bands_again[n])) < 0.01
	_check("its %d bands are bands again, as long as they were (%s)" % [bands_again.size(),
		", ".join(bands_again.map(func(x: float) -> String: return "%.1f" % x))], same and lengths.size() == 3)
	var turns: Array = springs.values().map(func(r: Dictionary) -> int: return int(r["turns"]))
	var turns_again: Array = springs_again.map(func(r: Dictionary) -> int: return int(r["turns"]))
	turns.sort()
	turns_again.sort()
	_check("its springs are springs again, their turns kept (%s)" % str(turns_again),
		turns == turns_again and turns.size() == 2)
	var reshaped: String = _item_named("Spring", 0)
	var ids: PackedInt64Array = _tree.ids_under(reshaped)
	_select(Array(ids))
	_shell.run("reshape_flex")
	await _frames(5)
	_check("Reshape opens a spring read back (%s, %d turns, ends on %s)" % [_flex.stage, _flex._turns,
		str(_flex._ends.map(func(e: Dictionary) -> String: return str(e.get("kind", ""))))],
		_flex.active and _flex.kind == "spring" and _flex._turns > 0 and _flex._ends.size() == 2
		and _flex._ends.all(func(e: Dictionary) -> bool: return str(e.get("free", "")) != "yes"))
	_flex.leave()
	var band: String = _band_round(_brick_at("4185a", Vector3(0, 60, 0)))
	_select(Array(_tree.ids_under(band)))
	_shell.run("reshape_flex")
	await _frames(5)
	_check("and a band read back, round its %d wheels" % _flex._rounds.size(),
		_flex.active and _flex.kind == "band" and _flex._rounds.size() >= 2)
	_flex.leave()


# -- helpers -------------------------------------------------------------------------


func _put(part: String, at: Transform3D) -> int:
	var brick_id: int = _world.add_brick(part, 7, at)
	_builder.register(brick_id, part, at)
	return brick_id


## A point on a wheel's rim, its top as it faces the front: where a person
## clicks it (its middle is its axle's hole, and a click there goes through).
func _rim(brick_id: int) -> Vector3:
	return _world.get_brick(brick_id).transform.origin + Vector3(0, GROOVE + 1.3, 0)


func _hole_of(brick_id: int) -> Flex.Anchor:
	for anchor: Flex.Anchor in Flex.anchors_in(_world, _library, "spring"):
		if anchor.brick == brick_id and anchor.kind == "pin_hole":
			return anchor
	return null


func _brick_at(part: String, at: Vector3) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and brick.transform.origin.distance_to(at) < 0.01:
			return brick.id
	return 0


## The band whose loop lies in [param wheel_id]'s groove.
func _band_round(wheel_id: int) -> String:
	var wheel: BrickWorld.Brick = _world.get_brick(wheel_id)
	if wheel == null:
		return ""
	var back: Transform3D = wheel.transform.affine_inverse()
	for path: String in _tree.paths():
		for brick: BrickWorld.Brick in _tree.bricks_under(path):
			if not brick.part_id.begins_with(Bands.SEGMENT_PREFIX):
				break
			var local: Vector3 = back * brick.transform.origin
			if absf(local.z) < 0.3 and absf(Vector2(local.x, local.y).length() - GROOVE - HALF) < 0.3:
				return path
	return ""


## The [param n]th item whose name begins [param name], in the tree's order.
func _item_named(name: String, n: int) -> String:
	var found: Array = []
	for path: String in _tree.paths():
		if Assemblies.label(path).begins_with(name) and not _tree.ids_under(path).is_empty():
			found.append(path)
	return str(found[n]) if n < found.size() else ""


func _pieces(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _tree.bricks_under(path):
		out.append({"part": brick.part_id, "at": brick.transform, "color": brick.color_code,
			"id": brick.id})
	return out


func _length_of(pieces: Array) -> float:
	var total: float = 0.0
	for piece: Dictionary in pieces:
		total += (piece["at"] as Transform3D).basis.y.length()
	return total


## Picked out, as a click on the model does: the keys go to the model, not
## to the last control pressed.
func _select(ids: Array) -> void:
	root.gui_release_focus()
	_builder.clear_selection()
	for brick_id: Variant in ids:
		_builder.selection[int(brick_id)] = true
	_builder.selection_changed.emit(ids.size())


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


## The bin searched for [param part] and its tile clicked: one action.
func _pick_from_bin(part: String) -> int:
	var search: LineEdit = _bin.controls_by_name()["part search"]
	search.text = part
	search.text_changed.emit(part)
	var at := Vector2.ZERO
	for _n: int in 300:
		await process_frame
		at = _tile(part)
		if at != Vector2.ZERO:
			break
	_check("the bin shows %s" % part, at != Vector2.ZERO)
	await _click(at)
	await _frames(5)
	return 1


func _tile(part: String) -> Vector2:
	var scroll: Control = _bin.controls_by_name()["parts list"]
	for tile: Node in _bin.find_children("*", "Button", true, false):
		var button := tile as Button
		if str(button.get_meta("part", "")) == part and button.is_visible_in_tree() \
				and scroll.get_global_rect().encloses(button.get_global_rect()):
			return button.get_global_rect().get_center()
	return Vector2.ZERO


func _look_at(box: AABB) -> void:
	_camera.set_view("front")
	await _frames(3)
	_camera.frame(box, 1.8)
	await _frames(30)


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
	if down:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/springs"))
	var path: String = "res://shots/springs/%s_%s.png" % [_size, name]
	image.save_png(ProjectSettings.globalize_path(path))
	print("    picture: shots/springs/%s_%s.png" % [_size, name])
