## Sub-assemblies as a person builds with them: made and named, moved as
## one, copied as instances of one definition, mirrored, edited inside with
## the copies following, nested, saved as LDraw sub-models and read back,
## and the model tree.
##
##   godot --path . --resolution 1400x900 --script src/dev/assembly_probe.gd
##
## Every gesture is a key or a click sent as an input event against the
## real scene. Pictures go to shots/assemblies/.
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
	_tree = _shell.assemblies
	_main.call("clear_model")
	Carry.clipboard = []
	# Under 1200 wide the panels beside and over the model leave it a strip
	# too narrow to build a plane in by clicking; a person would fold them.
	# Said rather than failed for the wrong reason thirty times over.
	var room: Vector2 = root.get_visible_rect().size
	_check("the window has room to build in by hand (%.0f x %.0f, at least 1200 x 720)"
		% [room.x, room.y], room.x >= 1199.0 and room.y >= 719.0)

	await _make_and_name()
	await _copies_follow()
	await _nested()
	await _saved_and_read_back()
	await _the_model_tree()
	await _an_official_model()

	print("")
	if _failures == 0:
		print("assemblies: made, moved whole, copied, mirrored, edited inside with the "
			+ "copies following, nested, saved and read back")
	else:
		print("assemblies: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- the checks ---------------------------------------------------------------


## A small plane: a body of two bricks along the middle, and a wing on the
## left of three parts — a plate, a brick on it, and a right-hand wedge
## plate at its tip.
var _wedge: String = ""


func _make_and_name() -> void:
	print("  making and naming a sub-assembly")
	_wedge = _library.resolve("41769")
	_put("3001", 1, Vector3(0, 24, 0))
	_put("3001", 1, Vector3(0, 24, -80))
	_put("3034", 14, Vector3(-100, 8, -40))
	_put("3004", 4, Vector3(-120, 32, -40))
	_put(_wedge, 14, Vector3(-120, 16, 40))
	await _frames(3)
	_camera.frame(AABB(Vector3(-240, 0, -200), Vector3(480, 80, 360)), 1.6)
	await _frames(40)
	var wing: Array = _model().filter(func(b: BrickWorld.Brick) -> bool:
		return b.transform.origin.x < -50.0).map(func(b: BrickWorld.Brick) -> int: return b.id)
	_select_only(wing)
	await _key(KEY_G, true)
	_check("Ctrl-G asks what the sub-assembly is called", _verbs._naming.visible)
	_verbs._name_field.text = "Wing"
	_verbs._naming.hide()
	_verbs._naming.confirmed.emit()
	await _frames(3)
	_check("...and makes the three wing parts the sub-assembly Wing",
		wing.all(func(b: int) -> bool: return Assemblies.path_of(_world.get_brick(b)) == "Wing#1"))
	_builder.clear_selection()
	await _click_tool("mode_select")
	await _click(_on(wing[1]))
	_check("a click with the Select tool takes the whole wing (%d)" % _builder.selection.size(),
		_builder.selection.size() == 3)
	_check("...and the properties say so (%s)" % _shell.inspector._title.text,
		_shell.inspector._title.text.begins_with("Wing"))
	var before: Vector3 = _world.get_brick(wing[0]).transform.origin
	await _key(KEY_LEFT)
	var moved: Vector3 = _world.get_brick(wing[0]).transform.origin - before
	# What was said and what had the keys, so a failure says why.
	var focused: Control = root.gui_get_focus_owner()
	_check("an arrow moves it as one (%s; said \"%s\"; keys with %s)" % [str(moved),
		_shell.status.fields()["message"], focused.get_class() if focused != null else "the model"],
		moved.length() > 1.0 and wing.all(func(b: int) -> bool: return _builder.selection.has(b)))
	await _key(KEY_Z, true)
	await _shot("wing_selected")


func _copies_follow() -> void:
	print("  a mirrored copy that follows")
	var wing: PackedInt64Array = _tree.ids_under("Wing#1")
	_select_only(Array(wing))
	await _key(KEY_D, true)
	_check("Ctrl-D holds a copy of the wing", _builder.is_carrying())
	# On the right if the panels leave it clear, else in front, nearer the
	# bottom of the window, where nothing covers the model.
	var spot: Vector2 = _clear_spot([Vector3(120, 0, -40), Vector3(120, 0, 40),
		Vector3(160, 0, -40), Vector3(120, 0, -120), Vector3(160, 0, 40),
		Vector3(0, 0, 180), Vector3(-80, 0, 200), Vector3(80, 0, 200), Vector3(0, 0, 260)])
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	await _click(spot + Vector2(1, 0))
	var copy: PackedInt64Array = _tree.ids_under("Wing#2")
	_check("put down, it is a second copy of Wing, not a new sub-assembly (%d parts in Wing#2)"
		% copy.size(), copy.size() == 3)
	_select_only(Array(copy))
	_camera.set_view("top")
	await _frames(30)
	await _key(KEY_M, false, true)
	copy = _tree.ids_under("Wing#2")
	var parts: Array = Array(copy).map(func(b: int) -> String: return _world.get_brick(b).part_id)
	var other: String = Mirror.counterpart(_library, _wedge)
	_check("Shift-M mirrors the copy into the right wing (%s)" % str(parts),
		parts.has(other) and not parts.has(_wedge))
	var fit: Dictionary = _tree.best_match(_tree.content("Wing#1"), _tree.content("Wing#2"))
	_check("...which lies on the left wing exactly, mirrored", bool(fit["exact"])
		and bool(fit["mirrored"]))
	_camera.set_view("default")
	_camera.frame(AABB(Vector3(-240, 0, -200), Vector3(480, 80, 360)), 1.6)
	await _frames(40)
	await _shot("two_wings")

	# Edit inside the left wing: a part added there appears in the right,
	# mirrored.
	_builder.clear_selection()
	await _click_tool("mode_select")
	var left_plate: int = _of_part("Wing#1", "3034")
	await _double_click(_on(left_plate))
	_check("a double-click with the Select tool edits inside the wing (%s)" % _tree.entered,
		_tree.entered == "Wing#1")
	_check("...saying so over the model", _shell.banner.visible)
	await _click(_on(left_plate))
	_check("...where a click takes one part (%d)" % _builder.selection.size(),
		_builder.selection.size() == 1)
	await _key(KEY_ESCAPE)
	await _click_tool("mode_place")
	_builder.held_part = "3023"
	_builder.held_color = 4
	var on_plate: Vector2 = _clear_spot([Vector3(-60, 8, -40), Vector3(-60, 8, 40),
		Vector3(-160, 8, -40)])
	await _move(on_plate)
	await _move(on_plate + Vector2(1, 0))
	var count: int = _count()
	await _click(on_plate + Vector2(1, 0))
	await _frames(5)
	_check("a plate put down while editing goes into the wing (%d in Wing)"
		% _tree.ids_under("Wing#1").size(), _tree.ids_under("Wing#1").size() == 4)
	_check("...and the right wing follows with its own (%d in Wing#2, %d parts in all)"
		% [_tree.ids_under("Wing#2").size(), _count()], _tree.ids_under("Wing#2").size() == 4
		and _count() == count + 2)
	fit = _tree.best_match(_tree.content("Wing#1"), _tree.content("Wing#2"))
	_check("...mirrored where the left one's is", bool(fit["exact"]) and bool(fit["mirrored"]))
	await _shot("copies_follow")
	await _key(KEY_Z, true)
	_check("one undo takes back both (%d, %d)" % [_tree.ids_under("Wing#1").size(),
		_tree.ids_under("Wing#2").size()], _tree.ids_under("Wing#1").size() == 3
		and _tree.ids_under("Wing#2").size() == 3)
	await _key(KEY_Z, true, true)
	_check("...and redo puts both back", _tree.ids_under("Wing#1").size() == 4
		and _tree.ids_under("Wing#2").size() == 4)
	# Painting a part inside one paints its twin.
	var plate: int = _of_part("Wing#1", "3034")
	_select_only([plate])
	_builder.held_color = 2
	await _key(KEY_C)
	await _frames(3)
	_check("a part painted in one wing is painted in the other (%d)"
		% _colour_of("Wing#2", "3034"), _colour_of("Wing#2", "3034") == 2)
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	_check("Escape puts the part in hand away and stays inside (%s, %s)" % [_verbs.mode,
		_tree.entered], _verbs.mode == "select" and _tree.entered == "Wing#1")
	await _key(KEY_ESCAPE)
	_check("...and again stops editing inside (%s)" % _tree.entered, _tree.entered.is_empty()
		and not _shell.banner.visible)
	# A copy moved whole stays a copy and changes nothing else.
	var snapshot: Array = _snapshot_of("Wing#1")
	_select_only(Array(_tree.ids_under("Wing#2")))
	await _key(KEY_RIGHT)
	_check("moving the right wing whole leaves the left one as it was",
		_snapshot_of("Wing#1") == snapshot)
	await _key(KEY_Z, true)


func _nested() -> void:
	print("  sub-assemblies inside a sub-assembly")
	await _key(KEY_A, true)
	await _key(KEY_G, true)
	_verbs._name_field.text = "Plane"
	_verbs._naming.hide()
	_verbs._naming.confirmed.emit()
	await _frames(3)
	var groups: Dictionary = {}
	for brick: BrickWorld.Brick in _model():
		groups[Assemblies.path_of(brick)] = true
	var named: Array = groups.keys()
	named.sort()
	_check("the whole of it made Plane holds the wings inside it (%s)" % str(named),
		named == ["Plane#1", "Plane#1/Wing#1", "Plane#1/Wing#2"])
	_builder.clear_selection()
	await _click_tool("mode_select")
	await _click(_on(_of_part("Plane#1/Wing#1", "3034")))
	_check("a click on a wing now takes the whole plane (%d)" % _builder.selection.size(),
		_builder.selection.size() == _count())
	await _double_click(_on(_of_part("Plane#1/Wing#1", "3034")))
	_check("a double-click edits inside the plane, where a click takes a wing (%d)"
		% _builder.selection.size(), _tree.entered == "Plane#1" and _builder.selection.size() == 4)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_check("Escape steps out to the model", _tree.entered.is_empty())


func _saved_and_read_back() -> void:
	print("  saved as LDraw sub-models, and read back")
	var text: String = _store.to_text("Probe Plane")
	var files: Array = []
	for line: String in text.split("\n"):
		if line.begins_with("0 FILE "):
			files.append(line.substr(7))
	_check("the file has the model, the plane and one wing (%s)" % str(files),
		files == ["probe_plane.ldr", "plane.ldr", "wing.ldr"])
	var references: int = 0
	var mirrored: int = 0
	for line: String in text.split("\n"):
		if line.begins_with("1 ") and line.ends_with("wing.ldr"):
			references += 1
			var numbers: PackedFloat64Array = PackedFloat64Array()
			for token: String in line.split(" ", false).slice(2, 14):
				numbers.append(token.to_float())
			if LdrModel.to_transform(numbers).basis.determinant() < 0.0:
				mirrored += 1
	_check("...the wing placed twice in the plane, once mirrored (%d, %d)" % [references,
		mirrored], references == 2 and mirrored == 1)
	var before: Array = _snapshot()
	var result: Dictionary = _store.open_text(text, "probe plane")
	await _frames(5)
	_check("read back, every part is where it was (%d)" % int(result["placed"]),
		_snapshot() == before)
	var groups: Dictionary = {}
	for brick: BrickWorld.Brick in _model():
		groups[Assemblies.path_of(brick)] = true
	var named: Array = groups.keys()
	named.sort()
	_check("...in the same tree (%s)" % str(named),
		named == ["Plane#1", "Plane#1/Wing#1", "Plane#1/Wing#2"])
	# Edit one wing of the reopened plane; the other still follows.
	await _click_tool("mode_select")
	await _double_click(_on(_of_part("Plane#1/Wing#1", "3034")))
	await _double_click(_on(_of_part("Plane#1/Wing#1", "3034")))
	_check("editing inside a wing of the reopened plane (%s)" % _tree.entered,
		_tree.entered == "Plane#1/Wing#1")
	var plate: int = _of_part("Plane#1/Wing#1", "3023")
	_select_only([plate])
	_builder.held_color = 15
	await _key(KEY_C)
	await _frames(3)
	_check("...and the other wing follows it still (%d)" % _colour_of("Plane#1/Wing#2", "3023"),
		_colour_of("Plane#1/Wing#2", "3023") == 15)
	if _colour_of("Plane#1/Wing#2", "3023") != 15:
		for brick: BrickWorld.Brick in _model():
			print("    %s %s %d" % [Assemblies.path_of(brick), brick.part_id, brick.color_code])
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	# Cut loose, a copy no longer follows.
	_select_only(Array(_tree.ids_under("Plane#1/Wing#2")))
	await _frames(2)
	_tree.enter("Plane#1")
	_select_only(Array(_tree.ids_under("Plane#1/Wing#2")))
	_shell.run("make_unique")
	var loose: String = ""
	for path: String in _tree.paths():
		if path.begins_with("Plane#1/Wing 2"):
			loose = path
	_check("Make unique gives the copy a definition of its own (%s)" % loose,
		not loose.is_empty())
	_tree.enter("Plane#1/Wing#1")
	_select_only([_of_part("Plane#1/Wing#1", "3023")])
	_builder.held_color = 0
	await _key(KEY_C)
	await _frames(3)
	_check("...so painting the first wing leaves it as it was (%d)" % _colour_of(loose, "3023"),
		_colour_of(loose, "3023") == 15)
	_tree.enter("")


func _the_model_tree() -> void:
	print("  the model tree")
	var outliner: Outliner = _shell.outliner
	_check("the model tree is on screen", outliner.is_visible_in_tree())
	outliner._refresh(true)
	var rows: Array = []
	_rows_of(outliner._tree.get_root(), rows)
	_check("it lists the model, the plane and its wings (%s)" % ", ".join(rows),
		rows.size() == 4 and rows[1].begins_with("Plane") and rows[2].begins_with("Wing"))
	# A row selects its parts.
	var wing_row: TreeItem = outliner._find(outliner._tree.get_root(), "Plane#1/Wing#1")
	wing_row.select(0)
	await _frames(3)
	if _builder.selection.is_empty():
		outliner._on_selected()
		await _frames(3)
	_check("choosing a row selects its parts (%d)" % _builder.selection.size(),
		_builder.selection.size() == _tree.ids_under("Plane#1/Wing#1").size())
	await _shot("model_tree")
	# Its eye hides it, and again shows it. (Choosing the row drew the tree
	# again, so the row is found again.)
	wing_row = outliner._find(outliner._tree.get_root(), "Plane#1/Wing#1")
	outliner._on_button(wing_row, 1, Outliner.EYE, MOUSE_BUTTON_LEFT)
	await _frames(3)
	_check("the eye hides it", Array(_tree.ids_under("Plane#1/Wing#1")).all(
		func(b: int) -> bool: return _world.get_brick(b).hidden))
	wing_row = outliner._find(outliner._tree.get_root(), "Plane#1/Wing#1")
	outliner._on_button(wing_row, 1, Outliner.EYE, MOUSE_BUTTON_LEFT)
	await _frames(3)
	_check("...and shows it", Array(_tree.ids_under("Plane#1/Wing#1")).all(
		func(b: int) -> bool: return not _world.get_brick(b).hidden))
	# Renamed in place, in every copy.
	_tree.enter("Plane#1")
	_select_only(Array(_tree.ids_under("Plane#1/Wing#1")))
	var called: String = _tree.rename("Plane#1/Wing#1", "Left wing")
	_check("renaming the wing renames it (%s)" % called, called == "Left wing"
		and _tree.ids_under("Plane#1/Left wing#1").size() == 4)
	# Dragged onto the model, it leaves the plane.
	var moved: String = _tree.move_into("Plane#1/Left wing#1", "")
	_check("dragged onto the model it is at the top (%s)" % moved, moved == "Left wing#1"
		and _tree.ids_under("Left wing#1").size() == 4)
	await _key(KEY_Z, true)
	_check("...and undo puts it back in the plane", _tree.ids_under("Plane#1/Left wing#1").size() == 4)
	_tree.enter("")
	_select_only(Array(_tree.ids_under("Plane#1")))
	await _key(KEY_G, true, true)
	_check("Ctrl-Shift-G takes the plane apart, its wings at the top",
		_tree.ids_under("Left wing#1").size() == 4 and _tree.ids_under("Plane#1").is_empty())


func _an_official_model() -> void:
	print("  an official model's sub-models")
	var path: String = "res://vendor/omr/files/31037-1_Hovercraft.mpd"
	if not FileAccess.file_exists(path):
		print("    (no vendor/omr here; skipped)")
		return
	var result: Dictionary = _store.open_text(FileAccess.get_file_as_string(path), "hovercraft")
	await _frames(10)
	var found: PackedStringArray = _tree.paths()
	_check("31037's tree has its propellers as two copies of one (%s)" % ", ".join(found),
		found.has("31037 - Propeller") or Array(found).any(func(p: String) -> bool:
			return p.ends_with("#2")))
	_check("...and its parts (%d)" % int(result["placed"]), int(result["placed"]) > 100)
	_shell.outliner._refresh(true)
	await _shot("hovercraft_tree")


# -- helpers ------------------------------------------------------------------


func _rows_of(item: TreeItem, into: Array) -> void:
	if item == null:
		return
	into.append(item.get_text(0))
	for child: TreeItem in item.get_children():
		_rows_of(child, into)


## The colour of a part in an assembly, or -1 when it has no such part.
func _colour_of(path: String, part: String) -> int:
	var brick: BrickWorld.Brick = _world.get_brick(_of_part(path, part))
	return -1 if brick == null else brick.color_code


## A part of an assembly, by its number as the library has it now ("3023"
## is put down as 3023b).
func _of_part(path: String, part: String) -> int:
	var wanted: String = _library.resolve(part)
	for brick: BrickWorld.Brick in _model():
		if Assemblies.path_of(brick) == path and brick.part_id == wanted:
			return brick.id
	return 0


func _snapshot_of(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _tree.bricks_under(path):
		out.append("%s %d %s" % [brick.part_id, brick.color_code,
			LdrModel._line_numbers(brick.transform)])
	out.sort()
	return out


func _snapshot() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _model():
		out.append("%s %d %s" % [brick.part_id, brick.color_code,
			LdrModel._line_numbers(brick.transform)])
	out.sort()
	return out


## A point on a brick's top that a person could click: on screen, not under
## a panel (the model tree, the properties, the toolbar), and where a click
## would land on that brick and not on one in front of it. The middle of
## its top first, then points towards its corners.
##
## Its top middle alone was where this used to aim, which held while the
## window was the size it was written at. On a smaller window, or a screen
## that draws the interface larger, the panels over the model's corners
## covered the wing, the click went to a panel, and the probe reported a
## click that selected nothing as if the app had ignored it.
func _on(brick_id: int) -> Vector2:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var box: AABB = (brick.transform * mesh.bounds).abs()
	var top: float = box.end.y - 4.0
	for share: Vector2 in [Vector2.ZERO, Vector2(0.3, 0.3), Vector2(-0.3, 0.3),
			Vector2(0.3, -0.3), Vector2(-0.3, -0.3), Vector2(0.4, 0), Vector2(-0.4, 0),
			Vector2(0, 0.4), Vector2(0, -0.4)]:
		var at: Vector2 = _screen(Vector3(box.get_center().x + box.size.x * share.x, top,
			box.get_center().z + box.size.z * share.y))
		if _clickable(at) and _verbs.brick_at(at) == brick_id:
			return at
	print("    (no point of %s is clear of the panels to click)" % brick.part_id)
	return _screen(Vector3(box.get_center().x, top, box.get_center().z))


## Whether a click here would reach the model: inside the window, and not
## over any panel.
func _clickable(at: Vector2) -> bool:
	return root.get_visible_rect().grow(-4.0).has_point(at) and not _main.call("_over_panel_at", at)


## The first of these places on the ground whose spot on screen is clear of
## the panels, for putting something down.
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/assemblies"))
	var path: String = "res://shots/assemblies/%s.png" % name
	image.save_png(ProjectSettings.globalize_path(path))
	print("    picture: shots/assemblies/%s.png" % name)
