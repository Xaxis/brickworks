## The model's room holds still as parts are put down and undone, in a window
## 390 points across: after every put and every undo, and in every frame
## between, Main._model_rect is one size. It flipped between 770 and 748 units
## tall there (wingfin's j390), and the view glided 11 px after each brick put
## down, so a ghost read during the glide was a stud from where the click put
## the part (room390). And the status bar fits the window: nothing past its
## edge, no word cut short.
##
##   godot --path . --resolution 390x844 --script src/dev/room_steady_probe.gd
##
## Every gesture is a click or a key sent as an input event against the real
## scene. Each frame the rects of the middle column's children are read, and
## any change is printed with what was last done, so a change names the child
## that took the room.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
var _verbs: EditVerbs
var _shell: Shell
var _tree: Assemblies
var _bin: PartsBin
var _middle: Control
var _last_layout: String = ""
var _doing: String = "start"
var _frame: int = 0
var _watching: bool = false
## Every room height read, each frame of the watch: height -> frames.
var _heights: Dictionary = {}
var _changes: int = 0
## Frames the window's column was wider than the window.
var _column_wide: int = 0
## The phone's layout (-- --phone), as a browser on a phone lays it out.
var _phone: bool = false


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
	# The phone's own layout, as a phone's browser gets it (Phone.on is the
	# web's alone): its status line shows only while the app works, over
	# the room the foot's row keeps.
	_phone = OS.get_cmdline_user_args().has("--phone")
	if _phone:
		Phone._on = 1
		Phone._wide = false
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
	_store = _main.get("_store")
	_verbs = _main.get("_verbs")
	_shell = _main.get("_shell")
	_bin = _main.get("_bin")
	_tree = _shell.assemblies
	_middle = (_main.get("_over_model") as Control).get_parent() as Control
	_main.call("clear_model")
	Carry.clipboard = []
	print("  window %s units (%s px)" % [str(root.get_visible_rect().size),
		str(DisplayServer.window_get_size())])

	# A wing of three parts made a sub-assembly and copied, as wingplace's
	# plane: edited inside, a put there says the copy's words, and a refused
	# one says why, the longest lines the status bar is given.
	_put("3001", 1, Vector3(0, 24, 0))
	_put("3034", 14, Vector3(-100, 8, -40))
	_put("3004", 4, Vector3(-120, 32, -40))
	await _frames(3)
	_select_only([_world.bricks()[1].id, _world.bricks()[2].id])
	await _key(KEY_G, true)
	_verbs._name_field.text = "Wing"
	_verbs._naming.hide()
	_verbs._naming.confirmed.emit()
	await _frames(3)
	_select_only(Array(_tree.ids_under("Wing#1")))
	await _key(KEY_D, true)
	await _frames(3)
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	_camera.frame(AABB(Vector3(-240, 0, -200), Vector3(480, 80, 360)), 1.6)
	await _frames(60)
	_check("a wing and its copy (%s)" % str(_tree.paths()), _tree.ids_under("Wing#2").size() == 2)
	# Saved under a name and opened again, as wingplace's model is: then a put
	# is the first unsaved work, and its undo the last.
	_check("saved as Room probe", _store.save_as("Room probe"))
	_store.open(ModelStore.saved_path("Room probe"))
	await _frames(10)
	_camera.frame(AABB(Vector3(-240, 0, -200), Vector3(480, 80, 360)), 1.6)
	await _frames(60)

	process_frame.connect(_watch)
	_watching = true
	_doing = "the model framed, at rest"
	await _frames(30)
	await _shot("before_put")
	_status_fits("at rest")

	# Plain puts and undos on the ground, at the model's level.
	_bin._on_part("3023")
	await _frames(10)
	var after_put: Dictionary = {}
	var after_undo: Dictionary = {}
	var puts: int = 0
	var spots: Array = [Vector3(60, 0, 60), Vector3(100, 0, -60), Vector3(-40, 0, 100),
		Vector3(140, 0, 20), Vector3(20, 0, -140)]
	for n: int in 10:
		var depth: int = _builder.history_depth()
		var at: Vector2 = _screen(spots[n % spots.size()])
		_doing = "put %d on the ground" % n
		await _move(at)
		await _move(at + Vector2(1, 0))
		await _click(at + Vector2(1, 0))
		await _frames(30)
		if _builder.history_depth() > depth:
			puts += 1
		var h: float = _room_height()
		after_put[h] = int(after_put.get(h, 0)) + 1
		if n == 0:
			await _shot("after_put")
			_status_fits("after a put")
		_doing = "undo %d on the ground" % n
		await _key(KEY_Z, true)
		await _frames(30)
		h = _room_height()
		after_undo[h] = int(after_undo.get(h, 0)) + 1
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)

	# Inside the wing being edited: each put says the copy's words, and a
	# spot the copy has no room for says why.
	if _phone:
		# A finger's way in is a hold and Edit inside (PhoneShell); entered
		# here as that does.
		_verbs.assemblies.enter("Wing#1")
		await _frames(5)
	else:
		await _click_tool("mode_select")
		await _double_click(_on(_of_part("Wing#1", "3034")))
	_check("a double-click edits inside the wing (%s)" % _tree.entered, _tree.entered == "Wing#1")
	_bin._on_part("3023")
	await _frames(10)
	var inside: Array = [Vector3(-60, 8, -40), Vector3(-160, 8, -40), Vector3(-100, 8, -20),
		Vector3(-140, 8, -60), Vector3(-80, 8, -60)]
	for n: int in 10:
		var depth: int = _builder.history_depth()
		var at: Vector2 = _screen(inside[n % inside.size()])
		_doing = "put %d inside the wing" % n
		await _move(at)
		await _move(at + Vector2(1, 0))
		await _click(at + Vector2(1, 0))
		await _frames(30)
		var put: bool = _builder.history_depth() > depth
		if put:
			puts += 1
		var h: float = _room_height()
		after_put[h] = int(after_put.get(h, 0)) + 1
		_status_fits("put %d inside the wing (\"%s\")" % [n, str(_shell.status.fields()["message"]).left(40)])
		if put:
			_doing = "undo %d inside the wing" % n
			await _key(KEY_Z, true)
			await _frames(30)
			h = _room_height()
			after_undo[h] = int(after_undo.get(h, 0)) + 1
	_watching = false
	await _shot("inside_the_wing")
	print("    %d puts made; %d changes of the middle column's layout while watched" % [puts, _changes])
	_check("the room's height after each put is one value (%s)" % str(after_put), after_put.size() == 1)
	_check("...and after each undo, the same (%s)" % str(after_undo),
		after_undo.size() == 1 and after_undo.keys() == after_put.keys())
	_check("...and in every frame of the watch (%s)" % str(_heights), _heights.size() == 1)
	_check("at least 15 puts made (%d)" % puts, puts >= 15)
	_check("the window's column never wider than the window (%d frames wider)" % _column_wide,
		_column_wide == 0)

	print("")
	if _failures == 0:
		print("room_steady: the model's room holds still through puts and undos, and the status bar fits")
	else:
		print("room_steady: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _room_height() -> float:
	return snappedf((_main.call("_model_rect") as Rect2).size.y, 0.1)


## Each frame: the room's height counted, and the middle column's children's
## rects, the status bar's and the notices', printed when they change.
func _watch() -> void:
	if not _watching:
		return
	_frame += 1
	var h: float = _room_height()
	_heights[h] = int(_heights.get(h, 0)) + 1
	var parts: PackedStringArray = []
	for child: Node in _middle.get_children():
		var c: Control = child as Control
		if c == null:
			continue
		var name: String = c.get_class()
		var script: Script = c.get_script()
		if script != null and not script.get_global_name().is_empty():
			name = script.get_global_name()
		parts.append("%s%s y%.0f h%.0f" % [name, "" if c.visible else "(hidden)",
			c.get_global_rect().position.y, c.size.y])
	var status: Control = _shell.status
	parts.append("status y%.0f h%.0f w%.0f" % [status.get_global_rect().position.y, status.size.y,
		status.size.x])
	# And the column round it: the header, the toolbar, the row the middle
	# is in; the header's own row's visible children, by x and y.
	var column: Control = _middle.get_parent().get_parent() as Control
	for child: Node in column.get_children():
		var c: Control = child as Control
		if c != null and c.visible:
			var named: String = c.get_class()
			if c.get_script() != null and not (c.get_script() as Script).get_global_name().is_empty():
				named = (c.get_script() as Script).get_global_name()
			parts.append("%s y%.0f h%.0f w%.0f" % [named, c.get_global_rect().position.y, c.size.y, c.size.x])
	var bar: Control = _main.get("_bar")
	var row: Control = bar.get_child(0) as Control
	var header: PackedStringArray = []
	for child: Node in row.get_children():
		var c: Control = child as Control
		if c != null and c.visible:
			header.append("%s@%.0f,%.0f w%.0f" % [str(c.name).left(12), c.position.x, c.position.y, c.size.x])
	parts.append("header [%s]" % ", ".join(header))
	var layout: String = "room y%.0f h%.1f | %s" % [(_main.call("_model_rect") as Rect2).position.y, h,
		" | ".join(parts)]
	var window: float = root.get_visible_rect().size.x
	if column.size.x > window + 0.5:
		_column_wide += 1
		# What in the status bar's row asks for the width, while it is wider.
		var fields: PackedStringArray = []
		for found: Node in status.find_children("*", "Control", true, false):
			var c: Control = found as Control
			if c.visible and c.get_parent() is HBoxContainer and c.get_parent().get_parent() == status:
				fields.append("%s %.0f%s" % [c.get_class(), c.get_combined_minimum_size().x,
					" \"%s\"" % (c as Label).text.left(40) if c is Label else ""])
		layout += " | wider than the window %.0f: %s" % [window, ", ".join(fields)]
	if layout != _last_layout:
		_changes += 1
		if _changes <= 80:
			print("    [frame %d, %s] %s" % [_frame, _doing, layout])
		_last_layout = layout


## The status bar inside the window, and each of its lines whole or cut at a
## word: nothing past the window's right edge.
func _status_fits(when: String) -> void:
	var window: Vector2 = root.get_visible_rect().size
	if not (_shell.status as Control).is_visible_in_tree():
		print("    (the status bar is put away %s: a phone's shows only while the app works)" % when)
		return
	var bar: Rect2 = (_shell.status as Control).get_global_rect()
	var past: Array = []
	for found: Node in (_shell.status as Node).find_children("*", "Control", true, false):
		var c: Control = found as Control
		if not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		if r.end.x > window.x + 0.5:
			past.append("%s %s" % [c.get_class(), str(r)])
	var cut: Array = []
	for found: Node in (_shell.status as Node).find_children("*", "Label", true, false):
		var label: Label = found as Label
		if not label.is_visible_in_tree() or label.text.is_empty():
			continue
		var whole: float = label.get_theme_font("font").get_string_size(label.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		var room: float = label.size.x - label.get_theme_stylebox("normal").get_minimum_size().x
		if whole > room + 0.5 and label.text_overrun_behavior != TextServer.OVERRUN_TRIM_WORD_ELLIPSIS \
				and label.text_overrun_behavior != TextServer.OVERRUN_TRIM_WORD:
			cut.append("\"%s\" (%.0f in %.0f)" % [label.text.left(30), whole, room])
	_check("the status bar fits the window %s (%s in %.0f; past the edge %s; cut mid-word %s)"
		% [when, str(bar), window.x, str(past), str(cut)],
		bar.end.x <= window.x + 0.5 and past.is_empty() and cut.is_empty())


func _put(part: String, colour: int, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)


func _of_part(path: String, part: String) -> int:
	for brick_id: int in _tree.ids_under(path):
		if _world.get_brick(brick_id).part_id.begins_with(part):
			return brick_id
	return 0


func _on(brick_id: int) -> Vector2:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var mesh: Lbm.PartMesh = (_main.get("_library") as PartLibrary).mesh_for(brick.part_id)
	var box: AABB = (brick.transform * mesh.bounds).abs()
	var top: float = box.end.y - 4.0
	for share: Vector2 in [Vector2.ZERO, Vector2(0.3, 0.3), Vector2(-0.3, 0.3),
			Vector2(0.3, -0.3), Vector2(-0.3, -0.3), Vector2(0.4, 0), Vector2(-0.4, 0)]:
		var at: Vector2 = _screen(Vector3(box.get_center().x + box.size.x * share.x, top,
			box.get_center().z + box.size.z * share.y))
		if root.get_visible_rect().grow(-4.0).has_point(at) and not _main.call("_over_panel_at", at) \
				and _verbs.brick_at(at) == brick_id:
			return at
	print("    (no point of %s is clear of the panels to click)" % brick.part_id)
	return _screen(Vector3(box.get_center().x, top, box.get_center().z))


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _click_tool(name: String) -> void:
	var button: Button = _shell.toolbar._buttons[name]
	await _click(button.get_global_rect().get_center())


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
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
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
	if _phone:
		name = "phone_" + name
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var folder: String = OS.get_environment("ROOM_SHOTS")
	if folder.is_empty():
		folder = ProjectSettings.globalize_path("res://shots/room_steady")
	DirAccess.make_dir_recursive_absolute(folder)
	image.save_png(folder.path_join("%s.png" % name))
	print("    picture: %s/%s.png" % [folder, name])
