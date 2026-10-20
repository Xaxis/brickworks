## Animating a crane the way a person does, in the real scene, in Build,
## Motions…: a turret on a turntable, an arm on a hinge on the turret. A new
## motion offers a slider for each of Grab's joints (what Pose's sliders
## were); a click on the arm's slider at a time puts a key there, the arm
## drawn swung about its pin, and the turret's carries the arm round with
## it. Keys at 0, 1 and 2 s make frames that turn each joint through them —
## read off the copy the renderer draws, frame by frame — and Render
## animation keeps them as frames, an animated WebP and an MP4.
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
var _player: MotionPlayer
var _ids: Dictionary = {}
## The two joints the editor offers, and their rows.
var _arm: Motions.Joint
var _turret: Motions.Joint
var _arm_row: Dictionary = {}
var _turret_row: Dictionary = {}


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
	_player = _main.get("_motions")
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

	_check("Build has Motions…", _shell.menu_id("pose") >= 0 and _shell.can("pose"))
	_shell.run("pose")
	await _frames(5)
	await _click(_pose._new.get_global_rect().get_center())
	await _frames(5)
	for row: Dictionary in _pose._joint_parts:
		var ids: Array = _player.parts_of(row["joint"])
		if ids.has(_ids["arm"]) or ids.has(_ids["top"]):
			_arm = row["joint"]
			_arm_row = row
		elif ids.has(_ids["turntable"]) or ids.has(_ids["hinge"]):
			_turret = row["joint"]
			_turret_row = row
	var said: Array = _pose._joint_parts.map(func(row: Dictionary) -> String: return _player.joint_words(row["joint"]))
	_check("New motion offers a slider for each joint, Grab's (%s)" % ", ".join(said), _pose.visible
		and _pose._joint_parts.size() == 2 and _arm != null and _turret != null)
	await _shot("1_panel")
	if _arm == null or _turret == null:
		quit(1)
		return

	await _a_slider()
	await _keys_and_frames()
	await _kept()

	print("")
	if _failures == 0:
		print("pose: each of Grab's joints on a slider, the arm swung and carried round, and the "
			+ "motion's frames turn each joint through its keys")
	else:
		print("pose: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## Which way raises the arm: the one it has room for.
var _up: float = 1.0


func _a_slider() -> void:
	print("  the arm's slider, at 2 s")
	var rest: Transform3D = _brick("arm").transform
	var steps: int = _builder.history_depth()
	_check("the time is 2 s, a new motion's first key's (%s s)" % Motions.num(_pose._at, 2),
		is_equal_approx(_pose._at, 2.0))
	# Down into the turret first: stopped short of it, and said.
	var reached: float = await _slide(_arm_row, 80.0)
	var other: float = reached
	var said: String = _pose.status_words()
	if reached >= 79.0:
		other = await _slide(_arm_row, -80.0)
		said = _pose.status_words()
	else:
		_up = -1.0
	_check("swung down into the turret it stops short, and says where (%.0f°; \"%s\")" % [other, said.left(90)],
		absf(other) < 79.0 and absf(other) > 1.0 and said.contains("stops at"))
	_check("...kept as a key where it stopped, the motion made (%s), the model itself unmoved" % (
		_builder.history_words(1)[0]), _builder.history_depth() > steps
		and _near(_brick("arm").transform, rest))
	# A click on the track at 45 degrees up, as a person would.
	var want: float = 45.0 * _up
	reached = await _slide(_arm_row, want)
	_check("a click on the arm's slider at %d° puts the key there (%.1f)" % [roundi(want), reached],
		absf(reached - want) <= 1.0)
	var pin: Grab = _player.hold(_arm).grab
	var expected: Transform3D = _turned(pin, reached) * rest
	_check("...and the arm is drawn about its pin: where turning it %d° about the hinge puts it"
		% roundi(reached), _near(_world.drawn_at(_brick("arm")), expected))
	_check("...one step (%s), the model itself unmoved" % _builder.history_words(1)[0],
		_builder.history_words(1)[0].begins_with("set ") and _near(_brick("arm").transform, rest))
	var turret: Grab = _player.hold(_turret).grab
	await _slide(_turret_row, 90.0)
	await _frames(3)
	var carried: Transform3D = _turned(turret, 90.0) * _turned(pin, reached) * rest
	_check("the turret's slider carries the arm round with it, drawn there",
		_near(_world.drawn_at(_brick("arm")), carried))
	_camera.frame(AABB(Vector3(-140, 0, -140), Vector3(280, 180, 280)), 1.2)
	await _frames(40)
	await _shot("2_posed")


func _keys_and_frames() -> void:
	print("  keys at 0, 1 and 2 s, and the frames between them")
	await _time_to(1.0)
	await _slide(_arm_row, 50.0 * _up)
	await _slide(_turret_row, 90.0)
	await _time_to(2.0)
	await _slide(_arm_row, 20.0 * _up)
	await _slide(_turret_row, 180.0)
	var motion: Motions.Motion = _pose._edited()
	var arm: Motions.Track = _pose._track_of(motion, _arm)
	var turret: Motions.Track = _pose._track_of(motion, _turret)
	_check("each joint keyed at 0, 1 and 2 s (%s; %s)" % [str(arm.keys), str(turret.keys)],
		arm.keys.size() == 3 and turret.keys.size() == 3 and is_equal_approx(float(arm.keys[2][0]), 2.0))
	var played: MotionPlayer.Played = _player.play(motion, false, 12, false)
	var frames: int = played.frames.size()
	_check("2 s at 12 a second is 25 frames, the last key's included (%d)" % frames, frames == 25)
	# Through the keys exactly, eased, never past them.
	var at_keys: Array = [arm.place_at(0.0), arm.place_at(1.0), arm.place_at(2.0)]
	_check("the arm's place at each key is the key's (%s)" % str(at_keys),
		absf(at_keys[0]) < 0.01 and absf(at_keys[1] - 50.0 * _up) < 0.01 and absf(at_keys[2] - 20.0 * _up) < 0.01)
	var overshoot: bool = false
	var jumps: float = 0.0
	var last: float = 0.0
	for n: int in frames:
		var value: float = arm.place_at(float(n) / 12.0) * _up
		if value < -0.001 or value > 50.001:
			overshoot = true
		if n > 0:
			jumps = maxf(jumps, absf(value - last))
		last = value
	_check("it never swings past a key, and moves at most %.1f° a frame" % jumps, not overshoot and jumps < 8.0)
	var start: float = arm.place_at(1.0 / 12.0) * _up
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
	var poses: Array = played.frames
	var model_before: Array = _snapshot()
	var pin: Grab = _player.hold(_arm).grab
	var turning: Grab = _player.hold(_turret).grab
	var seen_arm: Array = []
	var seen_turret: Array = []
	var pictures: Array = []
	var done: int = await renderer.animate(_world, settings, frames,
		func(n: int) -> Dictionary: return poses[n],
		func(_n: int) -> float: return 0.0,
		_pose.poser.reach(poses),
		func(_n: int, image: Image) -> void:
			var hinge: Transform3D = renderer.staged_transform(_ids["hinge"])
			var top: Transform3D = renderer.staged_transform(_ids["top"])
			var table: Transform3D = renderer.staged_transform(_ids["turntable"])
			seen_arm.append(_about(hinge.basis.inverse() * top.basis, pin.axis.normalized()))
			seen_turret.append(_about(table.basis, turning.axis.normalized()))
			pictures.append(image))
	_check("every frame is drawn (%d of %d)" % [done, frames], done == frames)
	var worst: float = 0.0
	for n: int in seen_arm.size():
		var t: float = float(n) / 12.0
		# A whole turn either way is the same angle: 180 is read back as -180.
		worst = maxf(worst, absf(wrapf(float(seen_arm[n]) - arm.place_at(t), -180.0, 180.0)))
		worst = maxf(worst, absf(wrapf(float(seen_turret[n]) - turret.place_at(t), -180.0, 180.0)))
	_check("in every frame drawn, each joint stands at the place its keys give it, to %.3f°"
		% worst, seen_arm.size() == frames and worst < 0.05)
	if seen_arm.size() == frames:
		_check("the arm drawn at 0°, %d° and %d° in the key frames (%.1f, %.1f, %.1f)" % [
			roundi(50.0 * _up), roundi(20.0 * _up), seen_arm[0], seen_arm[12], seen_arm[24]],
			absf(seen_arm[0]) < 0.05 and absf(float(seen_arm[12]) - 50.0 * _up) < 0.05
			and absf(float(seen_arm[24]) - 20.0 * _up) < 0.05)
		_check("and the turret at 0°, 90° and 180° (%.1f, %.1f, %.1f)" % [seen_turret[0],
			seen_turret[12], seen_turret[24]], absf(seen_turret[0]) < 0.05
			and absf(float(seen_turret[12]) - 90.0) < 0.05
			and absf(absf(float(seen_turret[24])) - 180.0) < 0.05)
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
	var before: Array = _snapshot()
	var frames: int = roundi(_pose._edited().length() * 12.0) + 1
	var done: int = await _pose.render_animation()
	_check("Render animation draws every frame (%d of %d): %s" % [done, frames, _pose.status_words()],
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


## A click on [param row]'s slider at [param value], as a person clicks
## the track: the key's place there, where its joint got to.
func _slide(row: Dictionary, value: float) -> float:
	var slider: HSlider = row["slider"] if is_instance_valid(row["slider"]) else null
	for part: Dictionary in _pose._joint_parts:
		if part["joint"] == row["joint"]:
			slider = part["slider"]
	var rect: Rect2 = slider.get_global_rect()
	var grab: float = slider.get_theme_icon("grabber").get_width()
	var ratio: float = (value - slider.min_value) / (slider.max_value - slider.min_value)
	await _click(Vector2(rect.position.x + grab * 0.5 + (rect.size.x - grab) * ratio, rect.get_center().y))
	await _frames(5)
	var track: Motions.Track = _pose._track_of(_pose._edited(), row["joint"]) if _pose._edited() != null else null
	return track.place_at(_pose._at) if track != null else NAN


## The editor's time set by a click on its slider.
func _time_to(t: float) -> void:
	var slider: HSlider = _pose._time
	var rect: Rect2 = slider.get_global_rect()
	var grab: float = slider.get_theme_icon("grabber").get_width()
	var ratio: float = (t - slider.min_value) / (slider.max_value - slider.min_value)
	await _click(Vector2(rect.position.x + grab * 0.5 + (rect.size.x - grab) * ratio, rect.get_center().y))
	await _frames(3)
	if absf(_pose._at - t) > 0.051:
		_pose.set_time(t)


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


func _turned(held: Grab, degrees: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, held.pivot) \
		* Transform3D(Basis(held.axis.normalized(), deg_to_rad(degrees)), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -held.pivot)


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
