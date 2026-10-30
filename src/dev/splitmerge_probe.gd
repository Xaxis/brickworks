## Split and Merge as a person uses them: one key each, Studio's Alt+S and
## Alt+M, pressed in the real window (APP_UX2 gap 6, splitmerge).
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
##     --resolution 1400x900 --script src/dev/splitmerge_probe.gd
##
## - A 2 x 4 plate becomes eight 1 x 1 plates on its eight studs in 1 key;
##   the brick on it is joined to the four under it, and one Ctrl+Z puts the
##   plate back.
## - Three stacked 1 x 4 plates become one 1 x 4 brick in 1 key, in their
##   box to the LDU, joined to what was on them and under them.
## - Six 1 x 1 plates in a 2 x 3 become one 2 x 3 plate.
## - Five 1 x 2 plates in a 2 x 5, which Studio's merge refuses, become two.
## - A merge with no real part says so and changes nothing: two stacked
##   1 x 4 plates, and two 1 x 1 plates in a colour no 1 x 2 plate was made in.
## - Studio's other splits: a 1 x 1 brick into three plates, a 2 x 2 slope
##   into two 2 x 1s.
## Every new part is in the lattice and runs into nothing, and each change is
## one undo. Pictures before and after in shots/splitmerge/.
extends SceneTree

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _shell: Shell
var _failures: int = 0
var _tag: String = ""

## How high the parts are laid, LDU: in the air, held by nothing but each
## other, so what is joined is only what the probe put together.
const LIFT := 96.0


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
	_shell = _main.get("_shell")
	var size: Vector2i = DisplayServer.window_get_size()
	_tag = "%dx%d" % [size.x, size.y]
	_check("Split is Alt+S and Merge Alt+M, and both are on the menu on a part (%s, %s)" % [
		_shell.key_words("split_parts"), _shell.key_words("merge_parts")],
		_shell.key_words("split_parts") == "Alt+S" and _shell.key_words("merge_parts") == "Alt+M"
		and "split_parts" in Shell.ON_A_PART and "merge_parts" in Shell.ON_A_PART)
	await _split_plate()
	await _merge_stack()
	await _merge_square()
	await _merge_further()
	await _merge_none()
	await _other_splits()
	print("splitmerge: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- the bars ---------------------------------------------------------------------


func _split_plate() -> void:
	print("\na 2 x 4 plate, split")
	await _fresh()
	var plate: int = _put("3020", 4, Transform3D(Basis.IDENTITY, Vector3(0, LIFT, 0)))
	# A 2 x 2 brick on its left four studs.
	var top: int = _put("3003", 15, Transform3D(Basis.IDENTITY, Vector3(-20, LIFT + 24.0, 0)))
	var studs: Array[Vector3] = _studs(plate)
	var was: Transform3D = _world.get_brick(plate).transform
	_check("the brick on it is joined to it before",
		_joined(top).size() == 2 and _joined(top).has(plate))
	await _select([plate])
	await _look([plate, top])
	await _shot("split_before")
	var before: Dictionary = _ids()
	var depth: int = _builder.history_depth()
	await _key(KEY_S, false, true)
	var made: Array = _made_since(before)
	var said: String = _said()
	print("    said: %s" % said)
	_check("1 key made %d parts, each a 1 x 1 plate in its red" % made.size(),
		made.size() == 8 and _all(made, "3024", 4))
	_check("the 2 x 4 plate is gone", _world.get_brick(plate) == null)
	var theirs: Array[Vector3] = []
	for brick_id: int in made:
		theirs.append_array(_studs(brick_id))
	_check("on the same eight studs, to the LDU", _same_points(studs, theirs))
	_check("one step to undo", _builder.history_depth() == depth + 1)
	_check("the status bar says so (%s)" % said, said.begins_with("split 1 part into 8"))
	_check("the eight are selected", _builder.selection.size() == 8)
	var joined: Array = _joined(top)
	var under: int = 0
	for brick_id: int in joined:
		if brick_id in made:
			under += 1
	_check("the brick on it is joined to the four under it, and to nothing else (%d of %d)"
		% [under, joined.size() - 1], under == 4 and joined.size() == 5)
	_check("each is in the lattice and runs into nothing", _all_clear(made))
	await _shot("split_after")
	await _key(KEY_Z, true)
	var back: BrickWorld.Brick = _only_part("3020")
	_check("one Ctrl+Z puts the 2 x 4 plate back where it was, and takes the eight off",
		back != null and back.transform.is_equal_approx(was) and _count("3024") == 0
		and _world.brick_count() == before.size())


func _merge_stack() -> void:
	print("\nthree 1 x 4 plates, stacked, merged")
	await _fresh()
	# On a 2 x 4 brick's back row, a 1 x 2 plate on them.
	var under: int = _put("3001", 14, Transform3D(Basis.IDENTITY, Vector3(0, LIFT, 0)))
	var plates: Array = []
	for k: int in 3:
		plates.append(_put("3710", 1, Transform3D(Basis.IDENTITY,
			Vector3(0, LIFT + 8.0 * (k + 1), -10.0))))
	var cap: int = _put("3023b", 15, Transform3D(Basis.IDENTITY, Vector3(-20, LIFT + 32.0, -10.0)))
	var box: AABB = _box_of(plates)
	await _select(plates)
	await _look([under, cap] + plates)
	await _shot("merge_before")
	var before: Dictionary = _ids()
	var depth: int = _builder.history_depth()
	await _key(KEY_M, false, true)
	var made: Array = _made_since(before)
	var said: String = _said()
	print("    said: %s" % said)
	var brick: BrickWorld.Brick = _world.get_brick(int(made[0])) if made.size() == 1 else null
	_check("1 key made one part, a 1 x 4 brick in their blue (%s)"
		% (_name(brick.part_id) if brick != null else "%d parts" % made.size()),
		brick != null and _name(brick.part_id) == "Brick 1 x 4" and brick.color_code == 1)
	_check("the three plates are gone", plates.all(func(id: int) -> bool:
		return _world.get_brick(id) == null))
	_check("in the three plates' box to the LDU", brick != null
		and _box_of([brick.id]).is_equal_approx(box))
	_check("one step to undo", _builder.history_depth() == depth + 1)
	_check("the status bar says so (%s)" % said, said == "merged 3 parts into a Brick 1 x 4")
	var joined: Array = _joined(cap)
	_check("the plate on it and the brick under it are joined to it (%d joined)" % joined.size(),
		brick != null and joined.size() == 3 and joined.has(brick.id) and joined.has(under))
	_check("it is in the lattice and runs into nothing", _all_clear(made))
	await _shot("merge_after")
	await _key(KEY_Z, true)
	_check("one Ctrl+Z puts the three plates back", _count("3710") == 3 and _count("3010") == 0)


func _merge_square() -> void:
	print("\nsix 1 x 1 plates in a 2 x 3, merged")
	await _fresh()
	var plates: Array = []
	for i: int in 3:
		for j: int in 2:
			plates.append(_put("3024", 14, Transform3D(Basis.IDENTITY,
				Vector3(-20.0 + 20.0 * i, LIFT, -10.0 + 20.0 * j))))
	var studs: Array[Vector3] = []
	for brick_id: int in plates:
		studs.append_array(_studs(brick_id))
	var box: AABB = _box_of(plates)
	await _select(plates)
	await _look(plates)
	await _shot("square_before")
	var before: Dictionary = _ids()
	await _key(KEY_M, false, true)
	var made: Array = _made_since(before)
	print("    said: %s" % _said())
	var plate: BrickWorld.Brick = _world.get_brick(int(made[0])) if made.size() == 1 else null
	_check("1 key made one 2 x 3 plate in their yellow (%s)"
		% (_name(plate.part_id) if plate != null else "%d parts" % made.size()),
		plate != null and _name(plate.part_id) == "Plate 2 x 3" and plate.color_code == 14)
	_check("on the six studs and in their box, to the LDU", plate != null
		and _same_points(studs, _studs(plate.id)) and _box_of([plate.id]).is_equal_approx(box))
	_check("it is in the lattice and runs into nothing", _all_clear(made))
	await _shot("square_after")


func _merge_further() -> void:
	print("\nfive 1 x 2 plates in a 2 x 5, merged (Studio's merge refuses it)")
	await _fresh()
	var plates: Array = []
	for i: int in 5:
		plates.append(_put("3023b", 4, Transform3D(Basis(Vector3.UP, PI / 2.0),
			Vector3(-40.0 + 20.0 * i, LIFT, 0))))
	var studs: Array[Vector3] = []
	for brick_id: int in plates:
		studs.append_array(_studs(brick_id))
	var box: AABB = _box_of(plates)
	await _select(plates)
	var before: Dictionary = _ids()
	await _key(KEY_M, false, true)
	var made: Array = _made_since(before)
	var names: Array = made.map(func(id: int) -> String: return _name(_world.get_brick(id).part_id))
	print("    said: %s" % _said())
	_check("1 key made %d parts (%s), two at most" % [made.size(), ", ".join(names)],
		made.size() == 2)
	var theirs: Array[Vector3] = []
	for brick_id: int in made:
		theirs.append_array(_studs(brick_id))
	_check("on the ten studs and in their box", _same_points(studs, theirs)
		and _box_of(made).is_equal_approx(box))
	_check("each is in the lattice and runs into nothing", _all_clear(made))


func _merge_none() -> void:
	print("\nmerges with no real part")
	await _fresh()
	var two: Array = []
	for k: int in 2:
		two.append(_put("3710", 1, Transform3D(Basis.IDENTITY, Vector3(0, LIFT + 8.0 * k, 0))))
	await _nothing_merged(two, "Blue", "two 1 x 4 plates stacked (no 1 x 4 two plates high)")
	await _shot("no_real_part")
	# A colour 1 x 1 plates were made in and no 1 x 2 plate was.
	var colour: int = -1
	for code: int in _library.colors:
		if _made("3024", code) and not ["3023a", "3023b"].any(func(id: String) -> bool:
				return _library.parts.has(id) and _made(id, code)):
			colour = code
			break
	_check("a colour 1 x 1 plates were made in and no 1 x 2 plate was: %s"
		% _library.color(colour).name, colour >= 0)
	if colour < 0:
		return
	await _fresh()
	var pair: Array = []
	for i: int in 2:
		pair.append(_put("3024", colour, Transform3D(Basis.IDENTITY, Vector3(-10.0 + 20.0 * i, LIFT, 0))))
	await _nothing_merged(pair, _library.color(colour).name,
		"two 1 x 1 plates side by side in %s" % _library.color(colour).name)


func _nothing_merged(ids: Array, colour: String, what: String) -> void:
	await _select(ids)
	var before: Dictionary = _ids()
	var depth: int = _builder.history_depth()
	await _key(KEY_M, false, true)
	var said: String = _said()
	print("    said: %s" % said)
	_check("%s: says no real part in %s is made of them (%s)" % [what, colour, said],
		said.begins_with("no real part") and said.contains(colour))
	_check("and changes nothing: the same %d parts, nothing to undo" % ids.size(),
		_ids() == before and _builder.history_depth() == depth)


func _other_splits() -> void:
	print("\na 1 x 1 brick and a 2 x 2 slope, split")
	await _fresh()
	var brick: int = _put("3005", 2, Transform3D(Basis.IDENTITY, Vector3(-40, LIFT, 0)))
	var slope: int = _put("3039", 4, Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(40, LIFT, 0)))
	var brick_box: AABB = _box_of([brick])
	var slope_box: AABB = _box_of([slope])
	await _select([brick, slope])
	await _look([brick, slope])
	await _shot("others_before")
	var before: Dictionary = _ids()
	var depth: int = _builder.history_depth()
	await _key(KEY_S, false, true)
	var made: Array = _made_since(before)
	print("    said: %s" % _said())
	var plates: Array = made.filter(func(id: int) -> bool: return _world.get_brick(id).part_id == "3024")
	var slopes: Array = made.filter(func(id: int) -> bool:
		return _name(_world.get_brick(id).part_id) == "Slope Brick 45 2 x 1")
	_check("the 1 x 1 brick is three 1 x 1 plates in its box", plates.size() == 3
		and _box_of(plates).is_equal_approx(brick_box))
	_check("the 2 x 2 slope is two 2 x 1 slopes in its box, turned as it was", slopes.size() == 2
		and _box_of(slopes).is_equal_approx(slope_box))
	_check("in one step to undo", _builder.history_depth() == depth + 1)
	_check("each is in the lattice and runs into nothing", _all_clear(made))
	await _shot("others_after")


# -- reading the model ------------------------------------------------------------


func _put(part: String, colour: int, at: Transform3D) -> int:
	var id: int = _world.add_brick(part, colour, at)
	_builder.register(id, part, at)
	return id


func _fresh() -> void:
	_main.call("clear_model")
	await _frames(6)
	_builder.clear_selection()
	_builder.forget_history()


func _select(ids: Array) -> void:
	_builder.selection.clear()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(ids.size())
	await _frames(3)


func _ids() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.part_id
	return out


func _made_since(before: Dictionary) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not before.has(brick.id):
			out.append(brick.id)
	return out


func _all(ids: Array, part: String, colour: int) -> bool:
	return ids.all(func(id: int) -> bool:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		return brick.part_id == part and brick.color_code == colour)


func _count(part: String) -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			count += 1
	return count


func _only_part(part: String) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			return brick
	return null


func _name(part: String) -> String:
	return Inventory._tidy(_library.parts[part].name) if _library.parts.has(part) else part


func _made(part: String, colour: int) -> bool:
	var info: PartLibrary.PartInfo = _library.parts[part]
	return info.availability_known() and not info.never_made_in(colour)


## Where a part's studs are in the model.
func _studs(brick_id: int) -> Array[Vector3]:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var out: Array[Vector3] = []
	for connector: Lbm.Connector in _library.mesh_for(brick.part_id).connectors:
		if connector.kind == "stud" and connector.gender == "male":
			out.append(brick.transform * connector.position)
	return out


func _same_points(ours: Array[Vector3], theirs: Array[Vector3]) -> bool:
	if ours.size() != theirs.size():
		return false
	for point: Vector3 in ours:
		if not theirs.any(func(other: Vector3) -> bool: return point.distance_to(other) < 0.01):
			return false
	return true


func _box_of(ids: Array) -> AABB:
	var box := AABB()
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		var here: AABB = brick.transform * _library.mesh_for(brick.part_id).bounds
		box = here if box.size == Vector3.ZERO else box.merge(here)
	return box


## What a part is joined to, as Select joined finds it: itself among them.
func _joined(brick_id: int) -> Array:
	var store: ModelStore = _main.get("_store")
	return SelectBy.connected(_world, _builder.lattice, [brick_id], store.scenery)


## Each part has its cover in the lattice, and the cover meets no other part's.
func _all_clear(ids: Array) -> bool:
	for brick_id: int in ids:
		var cover: PackedInt32Array = _builder.lattice.cover_of(brick_id)[0]
		if cover.is_empty() or _builder.lattice.collides_boxes(cover, brick_id):
			return false
	return true


func _said() -> String:
	var status: Label = _shell.bar.get("_status")
	return status.text if status != null else ""


# -- the window --------------------------------------------------------------------


func _look(ids: Array) -> void:
	_camera.frame(_box_of(ids).grow(30.0), 1.0)
	_camera.look_from(Vector3(0.45, 0.6, 0.65).normalized())
	await create_timer(1.5).timeout
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _key(code: Key, command: bool = false, alt: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.alt_pressed = alt
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


func _shot(name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/splitmerge/%s_%s.png" % [name, _tag])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/splitmerge/%s_%s.png" % [name, _tag])
