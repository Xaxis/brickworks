## Settings, Reduce motion: what moves by itself keeps still.
##
##   godot --path . --resolution 1280x800 --script src/dev/a11y_motion_probe.gd
##
## Three things move on their own: a model the assistant built goes up
## brick by brick (BuildPlayback), a part's picture still being drawn has a
## light crossing it (ThumbTile's shimmer), and the view glides to where it
## is sent (CadCamera's easing). Each is seen moving first, then Reduce
## motion is ticked in the Settings dialog as a person ticks it, and each is
## seen still: the model whole at once, the placeholder plain, the view
## there on the next frame.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _playback: BuildPlayback
var _store: ModelStore


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
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_playback = _main.get("_playback")
	_store = _main.get("_store")
	_store.keeps = false
	_playback.stop()
	_main.call("clear_model")
	await _frames(10)

	print("  as it is from the start:")
	await _see(true)

	# Ticked as a person ticks it: Settings, then the box.
	var shell: Shell = _main.get("_shell")
	shell.run("settings")
	await _frames(10)
	var settings: ControlsDialog = _main.get("_controls")
	# Asked by name, so this runs on a build without it and fails there.
	var box: CheckBox = settings.get("reduce_motion") as CheckBox if settings != null else null
	_check("Settings has Reduce motion (%s)" % (box.text if box != null else "none"),
		box != null and box.is_visible_in_tree())
	if box == null:
		_finish()
		return
	await _click(box.get_global_rect().get_center())
	var kept: bool = bool(ShellPrefs.value("reduce_motion"))
	_check("...and ticking it is kept (%s)" % kept, kept and box.button_pressed)
	settings.visible = false
	await _frames(4)

	print("  with Reduce motion:")
	await _see(false)
	_finish()


## Each of the three, moving when [param moving] and still when not.
func _see(moving: bool) -> void:
	# The model going up: a wall the assistant might have built, played.
	var fresh := PackedInt64Array()
	for course: int in 4:
		for along: int in 3:
			var where := Transform3D(Basis.IDENTITY,
				Vector3(along * 80 - 80, 24 + course * 24, 0))
			var brick: int = _world.add_brick("3001", 4, where)
			_builder.register(brick, "3001", where)
			fresh.append(brick)
	await _frames(2)
	var played: bool = _playback.play_new(fresh)
	await _frames(2)
	var shown: int = _shown_of(fresh)
	if moving:
		_check("a built model goes up brick by brick (%d of %d shown, playing %s)"
			% [shown, fresh.size(), _playback.is_playing()],
			played and _playback.is_playing() and shown < fresh.size())
	else:
		_check("a built model is there whole at once (%d of %d shown, playing %s)"
			% [shown, fresh.size(), _playback.is_playing()],
			not played and not _playback.is_playing() and shown == fresh.size())
	_playback.stop()
	_main.call("clear_model")
	await _frames(4)

	# A picture still being drawn.
	var tile := ThumbTile.new("3001", 4)
	tile.custom_minimum_size = Vector2(60, 60)
	root.add_child(tile)
	await _frames(2)
	var shimmering: bool = tile.state == ThumbTile.State.LOADING and tile.material != null
	if moving:
		_check("a picture being drawn shimmers (%s, %s)"
			% [ThumbTile.State.keys()[tile.state], tile.material], shimmering)
	else:
		_check("a picture being drawn keeps still (%s, %s)"
			% [ThumbTile.State.keys()[tile.state], tile.material],
			tile.state == ThumbTile.State.LOADING and tile.material == null)
	tile.queue_free()

	# The view sent from the front to the top: a frame later.
	_camera.set_view("front")
	await _frames(240)
	var from: Transform3D = _camera.global_transform
	_camera.set_view("top")
	await process_frame
	await process_frame
	var one_frame: Transform3D = _camera.global_transform
	await _frames(240)
	var arrived: Transform3D = _camera.global_transform
	var part_way: bool = not one_frame.is_equal_approx(from) \
		and not one_frame.is_equal_approx(arrived)
	if moving:
		_check("the view glides to where it is sent (part way after a frame)", part_way)
	else:
		_check("the view is where it is sent on the next frame",
			one_frame.is_equal_approx(arrived) and not arrived.is_equal_approx(from))


func _shown_of(bricks: PackedInt64Array) -> int:
	var shown: int = 0
	for brick_id: int in bricks:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick != null and not brick.hidden:
			shown += 1
	return shown


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = Vector2(1, 0)
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(4)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _finish() -> void:
	if _failures == 0:
		print("a11y motion probe: all checks passed")
	else:
		print("a11y motion probe: %d checks failed" % _failures)
	quit(1 if _failures > 0 else 0)
