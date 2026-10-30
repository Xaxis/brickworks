## Meet in Properties, as a person uses it: a ring of eight click hinge
## plates laid in a line is closed in three actions (a click on one end, a
## Shift-click on the other, Meet), its hinges all at 45°, and taken back
## with one Ctrl+Z. Pictures before and after in shots/hinge_align/.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
##     --resolution 1400x900 --script src/dev/hinge_align_ui_probe.gd
##
## The two ends are clicked where the camera shows them, Shift held for the
## second, as the Select tool takes a second part; Meet is pressed where
## Properties draws it. What counts is the model: the last plate's finger in
## the first plate's fork (Joints.rounds), the build check's verdict, and
## every plate back where it was after the undo.
extends SceneTree

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _shell: Shell
var _failures: int = 0
var _acts: int = 0
var _tag: String = ""

var _held_shift: bool = false

## How high the ring is laid, LDU.
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
	await _ring()
	print("hinge align ui: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _ring() -> void:
	_main.call("clear_model")
	await _frames(6)
	var ends: Array = []
	# The plates a person sees and clicks: each end segment's 1 x 4 on top.
	var tops: Array = []
	var box := AABB()
	# Laid in the air over the baseplate, not on its studs: a segment on them
	# would be held by them, as the real one would.
	for k: int in 8:
		var x: float = 100.0 * k - 350.0
		var fork: int = _put("44302b", 4, Transform3D(Basis(Vector3.UP, PI), Vector3(x - 20.0, LIFT, 0)))
		var finger: int = _put("44301b", 4, Transform3D(Basis.IDENTITY, Vector3(x + 20.0, LIFT, 0)))
		var top: int = _put("3710", 15, Transform3D(Basis.IDENTITY, Vector3(x, LIFT + 8.0, 0)))
		if k == 0:
			ends.append(fork)
			tops.append(top)
		if k == 7:
			ends.append(finger)
			tops.append(top)
	for brick: BrickWorld.Brick in _world.bricks():
		var here: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		box = here if box.size == Vector3.ZERO else box.merge(here)
	var rest: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		rest[brick.id] = brick.transform
	_builder.clear_selection()
	_builder.forget_history()
	# Where the parts bin and the right-hand column take turns
	# (Main._fit_panels), Properties' column is opened by its rail, as a
	# person opens it.
	var dock: SideDock = SideDock.of(_shell.inspector)
	if dock != null and not dock.is_open():
		await _click(dock.rail().get_global_rect().get_center())
		await _frames(30)
	_shell.inspector.set_open(true)
	_camera.frame(box.grow(20.0), 1.0)
	_camera.look_from(Vector3(0.25, 0.55, 0.8).normalized())
	await _settled()
	await _shot("ring_before")
	var depth: int = _builder.history_depth()
	_acts = 0
	# The Select tool, the app's own to start with: V when another is in hand.
	if _shell.verbs.mode != "select":
		await _key(KEY_V)
		_acts += 1
	# The last segment's top plate, clicked.
	await _click_part(int(tops[1]), false)
	# The first's, Shift-clicked.
	await _click_part(int(tops[0]), true)
	_check("the two ends are selected (%s)" % [_builder.selection.keys()],
		_builder.selection.size() == 2 and _builder.selection.has(tops[0])
		and _builder.selection.has(tops[1]))
	await _frames(10)
	var meet: Button = _shell.inspector.controls_by_name().get("prop_meet")
	_check("Properties offers Meet for the two", meet != null and meet.is_visible_in_tree())
	if meet == null or not meet.is_visible_in_tree():
		var hidden: Node = meet
		while hidden is CanvasItem and (hidden as CanvasItem).visible:
			hidden = hidden.get_parent()
		print("    Meet %s; hidden at %s; Properties open %s" % ["missing" if meet == null else "there",
			hidden.get_path() if hidden != null else "", _shell.inspector.is_open()])
		await _shot("ring_selected")
		return
	var scroll: ScrollContainer = _shell.inspector.get("_scroll")
	if scroll != null:
		scroll.ensure_control_visible(meet)
		await _frames(4)
	await _shot("ring_selected")
	# Meet.
	await _click(meet.get_global_rect().get_center())
	await _frames(10)
	var status: Label = _shell.bar.get("_status")
	print("    said: %s" % (status.text if status != null else ""))
	_check("closed in %d actions (4 at most)" % _acts, _acts <= 4)
	_check("one step to undo", _builder.history_depth() == depth + 1)
	var held: Dictionary = Joints.rounds(_entries())
	_check("the last plate's finger is in the first plate's fork",
		(held.get(ends[1], {}) as Dictionary).has(ends[0]))
	var moved: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not Grab._same(brick.transform, rest[brick.id]):
			moved += 1
	_check("the ring swung: %d of 24 parts moved" % moved, moved >= 18)
	_camera.frame(_bounds().grow(40.0))
	_camera.look_from(Vector3(0.2, 0.35, 0.9).normalized())
	await _settled()
	await _shot("ring_closed")
	# One undo, every part back.
	await _key(KEY_Z, true)
	await _frames(6)
	var back: bool = true
	for brick: BrickWorld.Brick in _world.bricks():
		if not Grab._same(brick.transform, rest[brick.id]):
			back = false
	_check("one Ctrl+Z puts every plate back", back)


func _put(part: String, colour: int, at: Transform3D) -> int:
	var id: int = _world.add_brick(part, colour, at)
	_builder.register(id, part, at)
	return id


func _entries() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		out.append([brick.id, brick.transform, _library.mesh_for(brick.part_id)])
	return out


func _bounds() -> AABB:
	var box := AABB()
	for brick: BrickWorld.Brick in _world.bricks():
		var here: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		box = here if box.size == Vector3.ZERO else box.merge(here)
	return box


## A click on the part where the view shows it, Shift held when [param
## add]: the first of a few points on its top the pointer finds it at, as a
## person aims at what they see.
func _click_part(brick_id: int, add: bool) -> void:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var box: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
	var at: Vector2 = _camera.unproject_position(box.get_center())
	var found: bool = false
	for along: float in [0.0, -0.3, 0.3, -0.15, 0.15]:
		var point := Vector3(lerpf(box.position.x, box.end.x, 0.5 + along), box.end.y - 5.0,
			box.get_center().z)
		var screen: Vector2 = _camera.unproject_position(point)
		if _shell.verbs.brick_at(screen) == brick_id:
			at = screen
			found = true
			break
	if not found:
		print("    %d not under the pointer at %s (%d is)" % [brick_id, at, _shell.verbs.brick_at(at)])
	if add:
		await _shift(true)
	await _click(at)
	if add:
		await _shift(false)
	await _frames(4)
	print("    clicked %d at %s: selected %s" % [brick_id, at.round(), _builder.selection.keys()])


func _shift(down: bool) -> void:
	_held_shift = down
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = down
	event.shift_pressed = down
	Input.parse_input_event(event)
	await process_frame


## The view eased to where it was sent: it eases by the clock, and frames
## come faster than a screen's here.
func _settled() -> void:
	await create_timer(1.5).timeout
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	motion.shift_pressed = _held_shift
	Input.parse_input_event(motion)
	await _frames(3)
	var whole: Vector2 = _as_event(at).floor()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = whole
		event.global_position = whole
		event.shift_pressed = _held_shift
		Input.parse_input_event(event)
		await _frames(2)
	_acts += 1
	await _frames(3)


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
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/hinge_align/%s_%s.png" % [name, _tag])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/hinge_align/%s_%s.png" % [name, _tag])
