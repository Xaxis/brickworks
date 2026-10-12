## Posing and animating a crane, the way a person does, in the real scene:
## a turret on a turntable, an arm on a hinge on the turret. Build, Pose
## and animate… gives each its slider; a click on the arm's slider swings
## it about its pin, and the turret's carries the arm round with it. Three
## keys make an animation whose frames turn each joint through the keyed
## angles — read off the copy the renderer draws, frame by frame — and it is
## kept as frames, an animated WebP and an MP4.
##
##   godot --path . --resolution 1400x900 --script src/dev/pose_probe.gd
##
## Pictures in shots/pose/; the animation's files in shots/pose/out/.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _shell: Shell
var _pose: PosePanel
var _ids: Dictionary = {}


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
	_pose = _main.get("_pose")
	_main.call("clear_model")

	print("  a crane: a turret on a turntable, an arm on a hinge on it")
	_put("base", "3680", Vector3(0, 8, 0), Basis.IDENTITY, "")
	_put("turntable", "3679", Vector3(0, 8, 0), Basis.IDENTITY, "Turret#1")
	_put("hinge", "3937", Vector3(0, 32, 0), Basis.IDENTITY, "Turret#1")
	_put("top", "3938", Vector3(0, 32, 0), Basis.IDENTITY, "Turret#1/Arm#1")
	_put("arm", "3795", Vector3(0, 40, 50), Basis(Vector3.UP, PI * 0.5), "Turret#1/Arm#1")
	await _frames(3)
	_camera.frame(AABB(Vector3(-120, 0, -120), Vector3(240, 160, 240)), 1.2)
	await _frames(60)

	_check("Build has Pose and animate…", _shell.menu_id("pose") >= 0 and _shell.can("pose"))
	_shell.run("pose")
	await _frames(5)
	var joints: Array = _pose.poser.joints
	var said: Array = joints.map(func(j: Poser.Joint) -> String: return "%s %s" % [j.path, j.kind()])
	_check("it opens with a slider for each joint (%s)" % str(said), _pose.visible
		and joints.size() == 2 and _pose._sliders.size() == 2
		and said.has("Turret#1 turntable") and said.has("Turret#1/Arm#1 hinge"))
	await _shot("1_panel")

	await _a_slider()
	await _keys_and_frames()
	await _kept()

	print("")
	if _failures == 0:
		print("pose: each joint on a slider, the arm swung and carried round, and the "
			+ "animation's frames turn each joint through its keys")
	else:
		print("pose: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## Which way raises the arm: the one it has room for.
var _up: float = 1.0


func _a_slider() -> void:
	print("  the arm's slider")
	var arm: Poser.Joint = _pose.poser.joint("Turret#1/Arm#1")
	var slider: HSlider = _pose._sliders[_pose.poser.joints.find(arm)]
	var rest: Transform3D = _brick("arm").transform
	# Down into the turret first: refused short of it, and said.
	var steps: int = _builder.history_depth()
	var reached: float = _pose.set_angle(arm.path, 80.0)
	var other: float = 0.0
	if reached < 79.0:
		_up = -1.0
		other = reached
		_builder.undo()
		await _frames(3)
	else:
		_builder.undo()
		await _frames(3)
		other = _pose.set_angle(arm.path, -80.0)
		_builder.undo()
		await _frames(3)
	_check("swung down into the turret it stops short and says so (%.0f°; \"%s\")" % [other,
		_pose._status.text], absf(other) < 79.0 and absf(other) > 1.0)
	_check("...and an undo of each leaves it as it was", _builder.history_depth() == steps
		and _near(_brick("arm").transform, rest))
	await _frames(5)
	_check("the slider reads back 0 after the undo (%d)" % roundi(slider.value),
		absf(slider.value) < 0.5)
	# A click on the track at 45 degrees up, as a person would.
	var want: float = 45.0 * _up
	var rect: Rect2 = slider.get_global_rect()
	var at := Vector2(rect.position.x + rect.size.x * (want + 180.0) / 360.0, rect.get_center().y)
	# The grabber is drawn inside the ends: aim as the slider measures.
	var grab: float = slider.get_theme_icon("grabber").get_width()
	at.x = rect.position.x + grab * 0.5 + (rect.size.x - grab) * (want + 180.0) / 360.0
	await _click(at)
	await _frames(5)
	_check("a click on the arm's slider at %d° swings it there (%.1f)" % [roundi(want), arm.angle],
		absf(arm.angle - want) <= 1.0)
	var expected: Transform3D = _turned(arm, arm.angle) * rest
	_check("...about its pin: the arm stands where turning it %d° about the hinge puts it"
		% roundi(arm.angle), _near(_brick("arm").transform, expected))
	_check("...as one step (%s)" % _builder.history_words(1)[0],
		_builder.history_words(1)[0].begins_with("posed"))
	var turret: Poser.Joint = _pose.poser.joint("Turret#1")
	_pose.set_angle(turret.path, 90.0)
	await _frames(3)
	var carried: Transform3D = _turned(turret, 90.0) * _turned(arm, arm.angle) * rest
	_check("the turret's slider carries the arm round with it (turret %.0f°)" % turret.angle,
		absf(turret.angle - 90.0) < 0.5 and _near(_brick("arm").transform, carried))
	_camera.frame(AABB(Vector3(-140, 0, -140), Vector3(280, 180, 280)), 1.2)
	await _frames(40)
	await _shot("2_posed")
	_pose.at_rest()
	await _frames(3)
	_check("At rest puts both back", _near(_brick("arm").transform, rest)
		and is_zero_approx(arm.angle) and is_zero_approx(turret.angle))


func _keys_and_frames() -> void:
	print("  three keys, and the frames between them")
	var arm: Poser.Joint = _pose.poser.joint("Turret#1/Arm#1")
	var turret: Poser.Joint = _pose.poser.joint("Turret#1")
	_pose._key_time.value = 0.0
	_pose.add_key()
	_pose.set_angle(arm.path, 50.0 * _up)
	_pose.set_angle(turret.path, 90.0)
	_pose.add_key()
	_pose.set_angle(arm.path, 20.0 * _up)
	_pose.set_angle(turret.path, 180.0)
	_pose.add_key()
	var animation: PoseAnimation = _pose.animation
	_check("three keys, at 0, 1 and 2 s (%s)" % str(animation.keys.map(
		func(k: Dictionary) -> float: return float(k["t"]))), animation.keys.size() == 3
		and is_equal_approx(float(animation.keys[2]["t"]), 2.0))
	animation.fps = 12
	var frames: int = animation.frame_count()
	_check("2 s at 12 a second is 25 frames, the last key's included (%d)" % frames, frames == 25)
	# Through the keys exactly, eased, never past them.
	var at_keys: Array = [animation.angle_at(arm.path, 0.0), animation.angle_at(arm.path, 1.0),
		animation.angle_at(arm.path, 2.0)]
	_check("the arm's angle at each key is the key's (%s)" % str(at_keys),
		is_equal_approx(at_keys[0], 0.0) and is_equal_approx(at_keys[1], 50.0 * _up)
		and is_equal_approx(at_keys[2], 20.0 * _up))
	var overshoot: bool = false
	var jumps: float = 0.0
	var last: float = 0.0
	for n: int in frames:
		var value: float = animation.angle_at(arm.path, animation.time_of(n)) * _up
		if value < -0.001 or value > 50.001:
			overshoot = true
		if n > 0:
			jumps = maxf(jumps, absf(value - last))
		last = value
	_check("it never swings past a key, and moves at most %.1f° a frame" % jumps,
		not overshoot and jumps < 8.0)
	var start: float = animation.angle_at(arm.path, animation.time_of(1)) * _up
	_check("it eases out of the first key (%.2f° in the first frame of 50)" % start, start < 3.0)

	# The frames themselves: the renderer's copy of the model, read as each
	# frame is drawn, against the keys.
	var renderer: StudioRender = StudioRender.new()
	root.add_child(renderer)
	renderer.library = _library
	renderer.scenery = _main.get("_store").scenery
	renderer.eye = _camera
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = Vector2i(320, 200)
	settings.contact_shadow = false
	settings.view = "hero"
	var poses: Array = []
	for n: int in frames:
		poses.append(_pose.poser.transforms_for(animation.angles_at(animation.time_of(n))))
	var model_before: Array = _snapshot()
	var seen_arm: Array = []
	var seen_turret: Array = []
	var pictures: Array = []
	var done: int = await renderer.animate(_world, settings, frames,
		func(n: int) -> Dictionary: return poses[n],
		func(_n: int) -> float: return 0.0,
		_pose.poser.reach(poses),
		func(_n: int, image: Image) -> void:
			var hinge: Basis = renderer.staged_transform(_ids["hinge"]).basis
			var top: Basis = renderer.staged_transform(_ids["top"]).basis
			var turning: Basis = renderer.staged_transform(_ids["turntable"]).basis
			seen_arm.append(_about(hinge.inverse() * top, arm.axis))
			seen_turret.append(_about(turning, turret.axis))
			pictures.append(image))
	_check("every frame is drawn (%d of %d)" % [done, frames], done == frames)
	var worst: float = 0.0
	for n: int in seen_arm.size():
		var t: float = animation.time_of(n)
		# A whole turn either way is the same angle: 180 is read back as -180.
		worst = maxf(worst, absf(wrapf(float(seen_arm[n]) - animation.angle_at(arm.path, t),
			-180.0, 180.0)))
		worst = maxf(worst, absf(wrapf(float(seen_turret[n])
			- animation.angle_at(turret.path, t), -180.0, 180.0)))
	_check("in every frame drawn, each joint stands at the angle the keys give it, to %.3f°"
		% worst, seen_arm.size() == frames and worst < 0.05)
	if seen_arm.size() == frames:
		_check("the arm drawn at 0°, %d° and %d° in the key frames (%.1f, %.1f, %.1f)" % [
			roundi(50.0 * _up), roundi(20.0 * _up), seen_arm[0], seen_arm[12], seen_arm[24]],
			absf(seen_arm[0]) < 0.01 and absf(float(seen_arm[12]) - 50.0 * _up) < 0.01
			and absf(float(seen_arm[24]) - 20.0 * _up) < 0.01)
		_check("and the turret at 0°, 90° and 180° (%.1f, %.1f, %.1f)" % [seen_turret[0],
			seen_turret[12], seen_turret[24]], absf(seen_turret[0]) < 0.01
			and absf(float(seen_turret[12]) - 90.0) < 0.01
			and absf(absf(float(seen_turret[24])) - 180.0) < 0.01)
		_check("the pictures change with the pose (frame 1 against 13: %.3f)"
			% _difference(pictures[0], pictures[12]), _difference(pictures[0], pictures[12]) > 0.002)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/pose"))
		for n: int in [0, 12, 24]:
			(pictures[n] as Image).save_png(ProjectSettings.globalize_path(
				"res://shots/pose/frame_%02d.png" % n))
	_check("the model itself is not moved by drawing it", _snapshot() == model_before)
	renderer.queue_free()


func _kept() -> void:
	print("  Render animation keeps it")
	var out: String = ProjectSettings.globalize_path("res://shots/pose/out")
	DirAccess.make_dir_recursive_absolute(out)
	_pose.folder = out
	_pose.animation.turntable = true
	var before: Array = _snapshot()
	var done: int = await _pose.render_animation()
	var frames: int = _pose.animation.frame_count()
	_check("Render animation draws every frame (%d of %d): %s" % [done, frames, _pose._status.text],
		done == frames)
	var paths: Array = _pose._last.get("paths", [])
	var webp: String = ""
	var mp4: String = ""
	for path: String in paths:
		if path.ends_with(".webp"):
			webp = path
		elif path.ends_with(".mp4"):
			mp4 = path
	_check("an animated WebP of %d frames (%s)" % [_webp_frames(webp), webp.get_file()],
		_webp_frames(webp) == frames)
	var folder: String = webp.get_basename()
	var pngs: int = 0
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".png"):
			pngs += 1
	_check("its frames in a folder beside it (%d)" % pngs, pngs == frames)
	if RenderOutput.ffmpeg().is_empty():
		print("    (no ffmpeg here: no MP4 to look for)")
	else:
		_check("and an MP4 (%s, %d bytes)" % [mp4.get_file(), _size_of(mp4)], _size_of(mp4) > 1000)
	_check("the model is as it was", _snapshot() == before)
	await _shot("3_rendered")


# -- helpers ---------------------------------------------------------------------


func _put(key: String, part: String, at: Vector3, basis: Basis, path: String) -> void:
	var where := Transform3D(basis, at)
	var brick_id: int = _world.add_brick(part, 4 if key == "arm" else 7, where)
	_builder.register(brick_id, part, where)
	# Builder.set_path, which a call through the class name cannot reach:
	# the script's own Resource.set_path answers instead.
	_world.get_brick(brick_id).unit = path
	_world.get_brick(brick_id).group = Assemblies.group_of(path)
	_ids[key] = brick_id


func _brick(key: String) -> BrickWorld.Brick:
	return _world.get_brick(int(_ids[key]))


func _turned(joint: Poser.Joint, degrees: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, joint.point) \
		* Transform3D(Basis(joint.axis, deg_to_rad(degrees)), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -joint.point)


## How far a rotation turns about [param axis], degrees.
func _about(turn: Basis, axis: Vector3) -> float:
	var across: Vector3 = (Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).cross(axis).normalized()
	var turned: Vector3 = turn * across
	return rad_to_deg(atan2(axis.dot(across.cross(turned)), across.dot(turned)))


func _near(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.05 and a.basis.x.distance_to(b.basis.x) < 0.001 \
		and a.basis.y.distance_to(b.basis.y) < 0.001 and a.basis.z.distance_to(b.basis.z) < 0.001


func _snapshot() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		out.append([brick.id, brick.part_id, brick.transform.origin.snapped(Vector3.ONE * 0.01)])
	return out


func _difference(a: Image, b: Image) -> float:
	var total: float = 0.0
	var count: int = 0
	for y: int in range(0, a.get_height(), 4):
		for x: int in range(0, a.get_width(), 4):
			var one: Color = a.get_pixel(x, y)
			var two: Color = b.get_pixel(x, y)
			total += absf(one.r - two.r) + absf(one.g - two.g) + absf(one.b - two.b)
			count += 1
	return total / float(maxi(count, 1))


func _webp_frames(path: String) -> int:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return -1
	var at: int = 12
	var frames: int = 0
	while at + 8 <= bytes.size():
		var tag: String = bytes.slice(at, at + 4).get_string_from_ascii()
		var length: int = bytes.decode_u32(at + 4)
		if tag == "ANMF":
			frames += 1
		at += 8 + length + (length & 1)
	return frames


func _size_of(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var length: int = file.get_length()
	file.close()
	return length


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		if down:
			event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		await _frames(3)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/pose"))
	var path: String = "res://shots/pose/%s.png" % name
	image.save_png(ProjectSettings.globalize_path(path))
	print("    picture: shots/pose/%s.png" % name)
