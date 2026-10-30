## View › Split (docs/APP_UX.md, B9): the model square on beside the
## perspective view, driven as a person drives it, keys and clicks sent as
## input events against the real scene.
##
##   godot --path . --resolution 1280x720 --script src/dev/split_probe.gd
##
## PROBE_SIZE=1400x900 runs it at the larger window, and a window too narrow
## for two views (PROBE_SIZE=600x800) checks that View › Split is greyed
## there with why. Pictures go to shots/split/WxH/.
##
## The bar: a 1 x 1 brick with a stud on its side (87087) put on that stud
## of another, once from the main view and once from the second, each
## action counted as connect_probe counts them (a click, a key, an aim of
## the pointer somewhere new); the second takes no more. The second view's
## click is made where only the second view draws the stud: with its ray
## not routed (CadCamera.beside), the main view's ray there misses it and
## this fails. Also: off out of the box, F8 in every preset, the model's
## column halved and the bin and the right-hand column as they were, the
## second view drawing the model, its header turning it to the top, the
## main view's own marks left out of it, and nothing drawn standing still
## that was not drawn without it.
##
## `-- unrouted` takes the second view's ray off the main camera once the
## split is on (CadCamera.beside), the split doing nothing, to see this fail.
extends SceneTree

const PART := "87087"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Shell
var _verbs: EditVerbs
var _split: SplitView
var _acts: Dictionary = {}


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
	_verbs = _main.get("_verbs")
	_split = _main.get("_split")
	print("  window %s" % DisplayServer.window_get_size())
	_check("the app has a second view to show (Main._split)", _split != null)
	if _split == null:
		_finish()
		return
	await _command()
	if not _split.fits():
		await _too_narrow()
		_finish()
		return
	await _model()
	await _shot("off")
	await _turn_on()
	await _shot("on")
	if "unrouted" in OS.get_cmdline_user_args():
		print("  -- unrouted: the second view's ray taken off the main camera")
		_camera.beside = Callable()
	await _place_from("main")
	await _place_from("second")
	await _sides()
	await _main_only()
	await _still()
	await _turn_off()
	_finish()


func _finish() -> void:
	print("")
	print("split: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- the command ----------------------------------------------------------------


func _command() -> void:
	_check("off out of the box: not shown, and not wanted on this device",
		not _split.is_showing() and not SplitView.wanted())
	var in_view: bool = false
	for menu: Array in Shell.MENUS:
		if menu[0] == "View" and "split_view" in menu[1]:
			in_view = true
	_check("View holds Split", in_view)
	_check("Find a command finds it by \"split\" (%s)" % str(_shell.palette.matches("split")),
		_shell.palette != null and "split_view" in _shell.palette.matches("split"))
	var keyed: Dictionary = {}
	for preset: String in Keymap.PRESETS:
		Keymap.use(preset)
		keyed[preset] = Keymap.action_of(KEY_F8)
	Keymap.use("brickworks")
	_check("F8 is Split's in every preset, and nothing else's (%s)" % str(keyed),
		keyed.values().all(func(action: Variant) -> bool: return action == "split_view"))


## A window too small for two views: View › Split greyed, saying why, and the
## key does nothing.
func _too_narrow() -> void:
	print("  -- too small (the model's column %.0f, under %.0f)"
		% [_split.room(), _split.least()])
	_check("View › Split is greyed (%s)" % _shell.why_not("split_view"),
		not _shell.can("split_view") and not _shell.why_not("split_view").is_empty())
	await _key(KEY_F8)
	await _frames(10)
	_check("...and F8 shows no second view", not _split.is_showing())


# -- the model: one 87087 standing on the baseplate --------------------------------


func _model() -> void:
	_verbs.set_mode("select")
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(4)
	for _n: int in 600:
		if _library.mesh_for(PART) != null:
			break
		await process_frame
	_put(PART, 15, Vector3(10, 24, 10))
	_camera.set_view("default")
	_camera.frame(AABB(Vector3(-50, 0, -50), Vector3(120, 60, 120)))
	await _settle()


func _turn_on() -> void:
	print("  -- on")
	var bin: float = (_main.get("_bin_dock") as Control).size.x
	var right: Control = _main.get("_props_dock") if _main.get("_props_dock") != null \
		else _main.get("_chat_dock")
	var right_was: float = right.size.x if right != null and right.visible else 0.0
	var middle: Control = _split.beside_of
	var room: float = middle.size.x
	await _key(KEY_F8)
	await _settle()
	_check("F8 shows the second view", _split.is_showing())
	_check("...wanted on this device from now on", SplitView.wanted())
	_check("...and View › Split is ticked", _shell.command("split_view").ticked.call())
	var shared: float = middle.size.x + _split.size.x
	_check("the main view and the second share the model's column (%.0f + %.0f of %.0f)"
		% [middle.size.x, _split.size.x, room], absf(shared - room) <= 2.0
		and middle.size.x >= SplitView.LEAST and _split.size.x >= SplitView.LEAST)
	var right_now: float = right.size.x if right != null and right.visible else 0.0
	_check("...and the bin (%.0f) and the right-hand column (%.0f) keep their widths"
		% [bin, right_was], is_equal_approx((_main.get("_bin_dock") as Control).size.x, bin)
		and is_equal_approx(right_now, right_was))
	var seen: Rect2 = _camera.seen_rect()
	_check("the main view is centred in its own half (%s), not the column's" % str(seen),
		seen.end.x <= _split.get_global_rect().position.x + 1.0)
	# The second view draws the model: where it draws the white brick is not
	# the sky at its top corner.
	var image: Image = _split.picture()
	var box: AABB = _box_of(_model_bricks()[0])
	var at: Vector2 = _split.on_screen(box.get_center())
	var rect: Rect2 = _split.picture_rect()
	var pixel: Vector2i = Vector2i(((at - rect.position) / rect.size) * Vector2(image.get_size()))
	var brick: Color = image.get_pixelv(pixel.clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE))
	var sky: Color = image.get_pixel(image.get_width() - 4, 4)
	_check("the second view draws the model: the brick %s there, the sky %s" % [
		brick.to_html(false), sky.to_html(false)], rect.has_point(at)
		and _distance(brick, sky) > 0.15)


# -- the bar: an 87087 on a side stud, from each view ----------------------------


## Put an 87087 on the standing one's side stud, from the main view or the
## second: in hand from the bin, tipped until its underside faces the stud,
## aimed at the stud and clicked. Counted, then taken back with Ctrl+Z.
func _place_from(view: String) -> void:
	print("  -- from the %s view" % view)
	var standing: BrickWorld.Brick = _model_bricks()[0]
	var stud: Array = _side_stud(standing)
	if stud.is_empty():
		_check("the 87087 has a stud on its side", false)
		return
	# The middle of the stud's end, where a person points at a stud. Its
	# side, from the main view's angle, is the side of a peg, and a part
	# aimed there goes against that.
	var point: Vector3 = (stud[0] as Vector3) + (stud[1] as Vector3) * 3.5
	var at: Vector2 = _camera.unproject_position(point) if view == "main" \
		else _split.on_screen(point)
	var main_rect: Rect2 = _camera.seen_rect()
	var second: Rect2 = _split.picture_rect()
	if view == "main":
		_check("the stud is in the main view at %s" % str(at.round()), main_rect.has_point(at)
			and not second.has_point(at))
	else:
		_check("the stud is in the second view at %s, outside the main one" % str(at.round()),
			second.has_point(at) and not main_rect.has_point(at))
		# Where the second view draws it, the main view's own ray finds
		# nothing of the stud: only the second view's ray can put it there.
		var own: BrickLattice.Hit = _builder.lattice.raycast(
			_main_ray_origin(at), _main_ray_normal(at))
		_check("...where the main view's own ray meets %s" % (
			"nothing" if not own.is_valid() else "the baseplate"
			if _store.scenery.has(own.brick_id) else "part %d" % own.brick_id),
			not own.is_valid() or own.brick_id != standing.id)
	var before: int = _model_bricks().size()
	_builder.held_face = "up"
	_builder.held_rotation = 0
	_count_from()
	await _hold(PART, 4)
	var tips: int = 0
	while not _faces(stud[1]) and tips < 6:
		await _act_key(KEY_T)
		tips += 1
	await _act_move(at)
	var aimed: bool = _builder.has_preview()
	await _act_click(at)
	var made: Array = _model_bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return b.id != standing.id)
	var on_stud: bool = made.size() == 1 and _socket_on(made[0], stud[0])
	var total: int = int(_acts["point"]) + int(_acts["click"]) + int(_acts["key"])
	_acts["total"] = total
	set_meta(view, total)
	print("    %d actions: %d clicks, %d keys (T %d), %d aims" % [total, _acts["click"],
		_acts["key"], tips, _acts["point"]])
	_check("from the %s view, the part's ghost is aimed there" % view, aimed)
	_check("...and a click puts it on the side stud (%d part%s more)" % [
		_model_bricks().size() - before, "" if _model_bricks().size() - before == 1 else "s"],
		on_stud)
	await _shot("placed_" + view)
	if view == "second":
		var first: int = int(get_meta("main", -1))
		_check("the second view took no more actions than the main one (%d, %d)"
			% [total, first], first >= 0 and total <= first)
	await _key(KEY_ESCAPE)
	await _key(KEY_Z, true)
	await _frames(4)
	_check("...and Ctrl+Z takes it back", _model_bricks().size() == before)


# -- the header: the side it looks from --------------------------------------------


func _sides() -> void:
	print("  -- the header")
	var top: Button = _split.buttons()["top"]
	await _click(top.get_global_rect().get_center())
	await _frames(4)
	var eye: Camera3D = _split.get("_eye")
	var looks: Vector3 = -eye.global_transform.basis.z
	_check("Top looks straight down (%s)" % str(looks.snappedf(0.01)),
		looks.dot(Vector3.DOWN) > 0.999 and _split.side == "top")
	_check("...and is kept on this device", str(ShellPrefs.value("split_side")) == "top")
	await _shot("top")
	var front: Button = _split.buttons()["front"]
	await _click(front.get_global_rect().get_center())
	await _frames(4)
	looks = -eye.global_transform.basis.z
	_check("Front looks along -z, as CadCamera's front does (%s)" % str(looks.snappedf(0.01)),
		looks.dot(Vector3.FORWARD) > 0.999)
	# The scale is the main view's: a step of the wheel over the main view
	# zooms the second as much.
	var was: float = eye.size
	_camera.key_zoom(1)
	await _settle()
	_check("a zoom of the main view zooms the second with it (%.1f -> %.1f)" % [was, eye.size],
		eye.size < was * 0.97)


# -- the main view's own ------------------------------------------------------------


func _main_only() -> void:
	print("  -- the main view's own")
	var cube: Control = _main.get("_gizmo")
	_check("the view cube stays in the main view",
		cube.get_global_rect().end.x <= _split.get_global_rect().position.x + 1.0)
	var turning: MeshInstance3D = _main.get("_turning")
	var eye: Camera3D = _split.get("_eye")
	_check("the pivot of a turn is drawn in the main view only",
		turning.layers == SplitView.MAIN_ONLY and (eye.cull_mask & SplitView.MAIN_ONLY) == 0
		and (_camera.cull_mask & SplitView.MAIN_ONLY) != 0)
	var cover: Dictionary = _main.call("model_cover")
	var view: Rect2 = cover["view"]
	_check("the model's room as the page is told it takes in both views (%s), nothing over it "
		% str(view) + "but the header (%d covered)" % (cover["covered"] as Array).size(),
		view.end.x >= _split.picture_rect().end.x - 1.0 and (cover["covered"] as Array).is_empty())


## Standing still, the split draws nothing the main view alone did not.
func _still() -> void:
	print("  -- standing still")
	IdleDraw.begin()
	await _move(Vector2(4, 4))
	var on: int = await _drawn_in(1.5)
	await _key(KEY_F8)
	var off: int = await _drawn_in(1.5)
	await _key(KEY_F8)
	IdleDraw.end()
	await _settle()
	_check("standing still, frames drawn in 1.5 s: %d with the split, %d without" % [on, off],
		on <= off + 1)


func _turn_off() -> void:
	print("  -- off")
	var middle: Control = _split.beside_of
	var shared: float = middle.size.x + _split.size.x
	await _key(KEY_F8)
	await _settle()
	_check("F8 again: one view", not _split.is_showing() and not SplitView.wanted())
	_check("...the model's column whole again (%.0f of %.0f)" % [middle.size.x, shared],
		absf(middle.size.x - shared) <= 2.0)
	var view: SubViewport = _split.get("_view")
	_check("...and the second view not drawn at all",
		view.render_target_update_mode == SubViewport.UPDATE_DISABLED)


# -- helpers ---------------------------------------------------------------------


func _put(part: String, colour: int, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)


func _model_bricks() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _box_of(brick: BrickWorld.Brick) -> AABB:
	return brick.transform * _library.mesh_for(brick.part_id).bounds


## The brick's stud that points sideways: [where, which way].
func _side_stud(brick: BrickWorld.Brick) -> Array:
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	for connector: Lbm.Connector in mesh.connectors:
		var axis: Vector3 = (brick.transform.basis * connector.axis).normalized()
		if connector.kind == "stud" and absf(axis.y) < 0.1:
			return [brick.transform * connector.position, axis]
	return []


## Whether the part in hand has its underside to a stud pointing [param out].
func _faces(out: Vector3) -> bool:
	return (BrickLattice.basis_for(_builder.held_face, _builder.held_rotation)
		* Vector3.UP).dot(out) > 0.99


## Whether one of [param brick]'s sockets sits on the stud at [param stud].
func _socket_on(brick: BrickWorld.Brick, stud: Vector3) -> bool:
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var out: Vector3 = (brick.transform.basis * Vector3.UP).normalized()
	for socket: Vector2 in mesh.sockets:
		var under: Vector3 = brick.transform * Vector3(socket.x, mesh.bounds.position.y, socket.y)
		var off: Vector3 = under - stud
		off -= out * off.dot(out)
		if off.length() < 0.5 and absf((under - stud).dot(out)) < 4.5:
			return true
	return false


## The main view's own ray, without the second view's: as it was before.
func _main_ray_origin(at: Vector2) -> Vector3:
	var lent: Callable = _camera.beside
	_camera.beside = Callable()
	var origin: Vector3 = _camera.ray_origin(at)
	_camera.beside = lent
	return origin


func _main_ray_normal(at: Vector2) -> Vector3:
	var lent: Callable = _camera.beside
	_camera.beside = Callable()
	var normal: Vector3 = _camera.ray_normal(at)
	_camera.beside = lent
	return normal


static func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _drawn_in(seconds: float) -> int:
	await create_timer(0.5).timeout
	var drawn: int = Engine.get_frames_drawn()
	await create_timer(seconds).timeout
	return Engine.get_frames_drawn() - drawn


## Long enough for the camera to ease where it was sent, and the columns to
## settle.
func _settle() -> void:
	await create_timer(0.6).timeout
	await _frames(6)


func _count_from() -> void:
	_acts = {"point": 0, "click": 0, "key": 0}


## The part taken in hand as a click on its tile does: one click.
func _hold(part: String, colour: int) -> void:
	_main.call("_on_part_chosen", part)
	for _n: int in 600:
		if _library.mesh_for(part) != null:
			break
		await process_frame
	_builder.held_color = colour
	_acts["click"] = int(_acts["click"]) + 1
	await _frames(3)


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


func _act_move(at: Vector2) -> void:
	_acts["point"] = int(_acts["point"]) + 1
	await _move(at)


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


func _act_click(at: Vector2) -> void:
	_acts["click"] = int(_acts["click"]) + 1
	await _click(at)


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


func _act_key(code: Key) -> void:
	_acts["key"] = int(_acts["key"]) + 1
	await _key(code)


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = ProjectSettings.globalize_path("res://shots/split/%dx%d/%s.png" % [
		size.x, size.y, name])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s" % path)
