## A part put down inside a sub-assembly being edited goes into it, and its
## copies follow, as a person does it: a double-click into the wing, a part
## taken from the bin by its tile, and a click on the wing. Fresh, and on the
## same model saved and opened again (the web's assembly_flow, which placed
## nothing there from rel-m324: wingplace).
##
##   godot --path . --resolution 1100x700 --script src/dev/wingplace_probe.gd
##
## Every gesture is a click or a key sent as an input event against the real
## scene, as assembly_probe's.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _verbs: EditVerbs
var _shell: Shell
var _tree: Assemblies
var _bin: PartsBin
var _wedge: String = ""


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
	_verbs = _main.get("_verbs")
	_shell = _main.get("_shell")
	_bin = _main.get("_bin")
	_tree = _shell.assemblies
	_main.call("clear_model")
	Carry.clipboard = []

	await _make_plane()
	await _put_inside("as made")
	await _key(KEY_Z, true)
	_check("saved as Kit car", _store.save_as("Kit car"))
	var placed: int = _store.open(ModelStore.saved_path("Kit car"))
	await _frames(10)
	_check("...and opened again (%d parts; tree %s)" % [placed, str(_tree.paths())],
		placed == _count() and _tree.ids_under("Wing#1").size() == 3)
	_frame_view()
	await _frames(40)
	await _put_inside("saved and opened again")
	await _key(KEY_Z, true)
	await _beside()

	print("")
	if _failures == 0:
		print("wingplace: a part put down inside an edited sub-assembly goes into it, fresh and reopened")
	else:
		print("wingplace: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## The plane of assembly_probe: a body of two bricks, and a wing on the left
## (a plate, a brick on it, a wedge plate) made the sub-assembly Wing, copied
## and mirrored to the right.
func _make_plane() -> void:
	_wedge = _library.resolve("41769")
	_put("3001", 1, Vector3(0, 24, 0))
	_put("3001", 1, Vector3(0, 24, -80))
	_put("3034", 14, Vector3(-100, 8, -40))
	_put("3004", 4, Vector3(-120, 32, -40))
	_put(_wedge, 14, Vector3(-120, 16, 40))
	await _frames(3)
	_frame_view()
	await _frames(40)
	var wing: Array = _model().filter(func(b: BrickWorld.Brick) -> bool:
		return b.transform.origin.x < -50.0).map(func(b: BrickWorld.Brick) -> int: return b.id)
	_select_only(wing)
	await _key(KEY_G, true)
	_verbs._name_field.text = "Wing"
	_verbs._naming.hide()
	_verbs._naming.confirmed.emit()
	await _frames(3)
	_check("the three wing parts are the sub-assembly Wing",
		wing.all(func(b: int) -> bool: return Assemblies.path_of(_world.get_brick(b)) == "Wing#1"))
	_select_only(Array(_tree.ids_under("Wing#1")))
	_verbs.duplicate_selection()
	var spot: Vector2 = _clear_spot([Vector3(120, 0, -40), Vector3(120, 0, 40),
		Vector3(160, 0, -40), Vector3(0, 0, 180), Vector3(80, 0, 200)])
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	await _click(spot + Vector2(1, 0))
	await _key(KEY_ESCAPE)
	var copy: PackedInt64Array = _tree.ids_under("Wing#2")
	_select_only(Array(copy))
	_camera.set_view("top")
	await _frames(30)
	await _key(KEY_M, false, true)
	_camera.set_view("default")
	_frame_view()
	await _frames(40)
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	_check("a second Wing, mirrored (%s)" % str(_tree.paths()),
		_tree.ids_under("Wing#2").size() == 3)


## Edit inside the left wing by a double-click, take a 1 x 2 plate from the
## bin by its tile, and click it down on the wing's plate.
func _put_inside(label: String) -> void:
	print("  a plate put down inside the wing, %s" % label)
	await _click_tool("mode_select")
	var left_plate: int = _of_part("Wing#1", "3034")
	await _double_click(_on(left_plate))
	_check("a double-click edits inside the wing (%s)" % _tree.entered, _tree.entered == "Wing#1")
	_bin._on_part("3023")
	await _frames(5)
	var on_plate: Vector2 = _clear_spot([Vector3(-60, 8, -40), Vector3(-60, 8, 40),
		Vector3(-160, 8, -40)])
	await _move(on_plate)
	await _move(on_plate + Vector2(1, 0))
	var count: int = _count()
	print("    before the click: mode %s, holding %s, carrying %s, ghost %s %s, into \"%s\", editing \"%s\""
		% [_verbs.mode, _builder.held_part, _builder.is_carrying(), _builder.has_preview(),
		_builder.get("_ghost_valid"), _builder.place_group, _tree.entered])
	await _click(on_plate + Vector2(1, 0))
	await _frames(5)
	print("    after: %d parts (were %d), said \"%s\"" % [_count(), count,
		_shell.status.fields()["message"]])
	_check("a plate put down while editing goes into the wing (%d in Wing#1)"
		% _tree.ids_under("Wing#1").size(), _tree.ids_under("Wing#1").size() == 4)
	_check("...and the right wing follows with its own (%d in Wing#2, %d parts, were %d)"
		% [_tree.ids_under("Wing#2").size(), _count(), count],
		_tree.ids_under("Wing#2").size() == 4 and _count() == count + 2)
	await _shot("put_inside_%s" % label.replace(" ", "_"))
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)


## The web's assembly_flow since ux14: Ctrl+D puts the copy down at once
## beside the wing, and Shift-M mirrors it where it stands, so the two wings
## stand side by side. Edited inside the first, a plate is aimed at the ground
## all round it; each place whose ghost says it fits is clicked.
func _beside() -> void:
	print("  the copy put beside by Ctrl+D and mirrored there")
	_main.call("clear_model")
	await _frames(3)
	_put("3034", 14, Vector3(-100, 8, -40))
	_put("3004", 4, Vector3(-120, 32, -40))
	_put(_wedge, 14, Vector3(-120, 16, 40))
	await _frames(3)
	_frame_view()
	await _frames(30)
	_select_only(_model().map(func(b: BrickWorld.Brick) -> int: return b.id))
	await _key(KEY_G, true)
	_verbs._name_field.text = "Wing"
	_verbs._naming.hide()
	_verbs._naming.confirmed.emit()
	await _frames(3)
	_select_only(Array(_tree.ids_under("Wing#1")))
	await _key(KEY_D, true)
	await _frames(3)
	_check("Ctrl+D puts a second Wing beside it (%s, %d selected)" % [str(_tree.paths()),
		_builder.selection.size()], _tree.ids_under("Wing#2").size() == 3)
	_select_only(Array(_tree.ids_under("Wing#2")))
	await _key(KEY_M, false, true)
	await _frames(3)
	for path: String in ["Wing#1", "Wing#2"]:
		for brick_id: int in _tree.ids_under(path):
			var b: BrickWorld.Brick = _world.get_brick(brick_id)
			print("    %s %s at %s, mirrored %s" % [path, b.part_id, str(b.transform.origin),
				b.transform.basis.determinant() < 0.0])
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	await _click_tool("mode_select")
	await _double_click(_on(_of_part("Wing#1", "3034")))
	_check("a double-click edits inside the wing (%s)" % _tree.entered, _tree.entered == "Wing#1")
	_bin._on_part("3023")
	await _frames(5)
	await _sweep("a plate from the bin", 2)
	await _key(KEY_ESCAPE)
	# The same from the clipboard: the wing's brick copied inside it, pasted,
	# and aimed all round (a paste goes into the wing being edited).
	_select_only([_of_part("Wing#1", "3004")])
	await _key(KEY_C, true)
	await _key(KEY_V, true)
	await _frames(3)
	_check("Ctrl+V holds a copy of the brick (%s)" % _builder.is_carrying(), _builder.is_carrying())
	# A paste is put down once: pasted again for the next place.
	await _sweep("a brick pasted", 2, func() -> void:
		await _key(KEY_V, true)
		await _frames(2))
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)


## What is in hand aimed at the ground all round the wing being edited, a
## stud apart, and clicked wherever its ghost stands: each ghost that says it
## fits takes the part, and its copy's twin [param twins] parts in all; each
## red only for the copy (Builder.copies_refuse) is said as it turns red and
## takes nothing, the click's refusal in the same words.
func _sweep(what: String, twins: int, again: Callable = Callable()) -> void:
	var box := AABB()
	var first: bool = true
	for brick_id: int in _tree.ids_under("Wing#1"):
		var b: BrickWorld.Brick = _world.get_brick(brick_id)
		var mesh_box: AABB = (b.transform * _library.mesh_for(b.part_id).bounds).abs()
		box = mesh_box if first else box.merge(mesh_box)
		first = false
	var green: int = 0
	var green_put: int = 0
	var red: int = 0
	var red_put: int = 0
	var red_said: int = 0
	var same_words: int = 0
	var wrong: Array = []
	var shown: Array = []
	var slowest: int = 0
	for x: int in range(int(box.position.x) - 60, int(box.end.x) + 61, 20):
		for z: int in range(int(box.position.z) - 60, int(box.end.z) + 61, 20):
			var at: Vector2 = _screen(Vector3(float(x), 0.0, float(z)))
			if not _clickable(at):
				continue
			if again.is_valid() and not _builder.is_carrying():
				await again.call()
			await _move(at)
			var began: int = Time.get_ticks_usec()
			await _move(at + Vector2(1, 0))
			slowest = maxi(slowest, Time.get_ticks_usec() - began)
			var predicted: String = _builder.copies_refuse
			var fits: bool = _builder.can_place()
			if not fits and predicted.is_empty():
				continue
			var heard: String = _shell.status.fields()["message"]
			var count: int = _count()
			await _click(at + Vector2(1, 0))
			await _frames(3)
			var put: bool = _count() > count
			if fits:
				green += 1
				if put and _count() == count + twins:
					green_put += 1
				elif wrong.size() < 6:
					wrong.append("green at %s took %d (\"%s\")" % [str(Vector3(x, 0, z)), _count() - count,
						_tree.refused])
			else:
				red += 1
				red_put += 1 if put else 0
				red_said += 1 if heard == predicted else 0
				same_words += 1 if _tree.refused == predicted else 0
				if put and wrong.size() < 6:
					wrong.append("red at %s took %d (\"%s\")" % [str(Vector3(x, 0, z)), _count() - count,
						predicted])
				if shown.is_empty():
					shown.append(predicted)
					await _shot("red_%s" % what.replace(" ", "_"))
			if put:
				await _key(KEY_Z, true)
				await _frames(2)
	print("    %s: %d places green, %d of them put down with the twin; %d red for the copy, %d put down, %d said as it turned red, %d refused in the same words; the slowest aim %d us"
		% [what, green, green_put, red, red_put, red_said, same_words, slowest])
	for one: String in wrong:
		print("      " + one)
	for one: String in shown:
		print("      red says: " + one)
	_check("%s: every green ghost takes the part and the copy its twin (%d of %d)" % [what, green_put,
		green], green > 0 and green_put == green)
	_check("...every ghost red for the copy takes nothing (%d red, %d put)" % [red, red_put],
		red > 0 and red_put == 0)
	_check("...and says why as it turns red, in the words the click's refusal says (%d, %d of %d)"
		% [red_said, same_words, red], red_said == red and same_words == red)


func _frame_view() -> void:
	_camera.frame(AABB(Vector3(-240, 0, -200), Vector3(480, 80, 360)), 1.6)


func _of_part(path: String, part: String) -> int:
	for brick_id: int in _tree.ids_under(path):
		if _world.get_brick(brick_id).part_id.begins_with(part):
			return brick_id
	return 0


func _on(brick_id: int) -> Vector2:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var box: AABB = (brick.transform * mesh.bounds).abs()
	var top: float = box.end.y - 4.0
	for share: Vector2 in [Vector2.ZERO, Vector2(0.3, 0.3), Vector2(-0.3, 0.3),
			Vector2(0.3, -0.3), Vector2(-0.3, -0.3), Vector2(0.4, 0), Vector2(-0.4, 0)]:
		var at: Vector2 = _screen(Vector3(box.get_center().x + box.size.x * share.x, top,
			box.get_center().z + box.size.z * share.y))
		if _clickable(at) and _verbs.brick_at(at) == brick_id:
			return at
	print("    (no point of %s is clear of the panels to click)" % brick.part_id)
	return _screen(Vector3(box.get_center().x, top, box.get_center().z))


func _clickable(at: Vector2) -> bool:
	return root.get_visible_rect().grow(-4.0).has_point(at) and not _main.call("_over_panel_at", at)


func _clear_spot(places: Array) -> Vector2:
	for place: Vector3 in places:
		var at: Vector2 = _screen(place)
		if _clickable(at):
			return at
	print("    (none of %s is clear of the panels)" % str(places))
	return _screen(places[0])


func _click_tool(name: String) -> void:
	var button: Button = _shell.toolbar._buttons[name]
	await _click(button.get_global_rect().get_center())


func _put(part: String, colour: int, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


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


func _button(at: Vector2, down: bool, twice: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.double_click = twice and down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _double_click(at: Vector2) -> void:
	await _click(at)
	_button(at, true, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _key(code: Key, command: bool = false, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/wingplace"))
	image.save_png(ProjectSettings.globalize_path("res://shots/wingplace/%s.png" % name))
	print("    picture: shots/wingplace/%s.png" % name)
