## Recording what moves on real sets: what the animation audit found broken
## (docs/ANIMATION.md), each checked as the person or the session meets it.
##
##   godot --path . --resolution 1400x900 --script src/dev/animation_probe.gd
##
##  1. 31070-1's back window, pose_model's joint swung to 70° and back to
##     0°, stands where it was built: it stopped 6 LDU and 4° short, the
##     room test meeting what it was built against.
##  2. Play of a motion on it, out and back, in Build, Motions…, leaves
##     every part where it was built: Pose's Play once squared up 73 parts'
##     LDraw matrices, with no step to undo.
##  3. "Show me the steering turning" on 8808-1, by its part, with the
##     window zoomed far out: the session's animation frames the car. It was
##     drawn through the window's camera, a dot. The answer carries its
##     frames at its keys, and says how long drawing took as that: a real
##     session read "— 3 s" as an MP4 cut short, and had not seen it.
##  4. Then the person opens Build, Motions…, where the session's keys are
##     the motion "Animation": Play turns the steering and puts it back, and
##     Render animation draws it turning. Both once stood still: the part was
##     turned for one render only. Cancel a few frames into a render stops
##     it, and moves nothing.
##  5. A part that meets the model at once (31070-1's windscreen): the
##     answer says where it stopped. It said only how many frames it drew.
##     And pose_model says which of its joints have no room to turn: real
##     sessions swung 4096-1's one joint both ways before finding the boom.
##  6. A run of 6 frames after one of 12 of the same name: its MP4 is 6
##     frames at the rate asked. It was 25 a second, and made of the 12.
## Files in shots/animation/.
extends SceneTree

const DOORS := "res://vendor/omr/files/31070-1.mpd"
const RACER := "res://vendor/omr/files/8808-1.mpd"
const OUT := "res://shots/animation"

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
var _pose: PosePanel
var _out: String = ""
var _next: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_out = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_store = _main.get("_store")
	_pose = _main.get("_pose")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	if not StudioRender.possible():
		print("animation probe: SKIPPED, it needs a window to draw (xvfb-run)")
		quit(0)
		return
	Download.folder = _out
	_pose.folder = _out
	await _doors()
	await _racer()
	await _mp4()
	print("")
	if _failures == 0:
		print("animation: posed joints come back, play changes nothing, a session's animation "
			+ "is framed, plays and renders from the panel, says where it stops, and its MP4 is true")
	else:
		print("animation: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _doors() -> void:
	print("── 31070-1: its back window, posed, and its windscreen, animated ──")
	if not await _open(DOORS):
		return
	var built: Dictionary = _poses()
	var window: Poser.Joint = null
	for one: Poser.Joint in _pose.joints_now():
		if Assemblies.label(one.path) == "Back Window":
			window = one
	_check("pose_model has the back window on its hinge", window != null)
	if window == null:
		return
	var reached: float = _pose.set_angle(window.path, 70.0)
	_check("swung to 70° it goes there (%.0f°)" % reached, absf(reached - 70.0) < 0.5)
	_pose.set_angle(window.path, 0.0)
	var off: Array = _off(built)
	_check("...and back to 0° it stands where it was built (%d parts off, by %.2f LDU at most)"
		% [off[0], off[1]], int(off[0]) == 0)
	var kept: String = await _say("define_motion", {"name": "Swing the back window", "tracks": [
		{"joint": "Back Window", "keys": [{"t": 0, "place": 0}, {"t": 1, "place": 40}, {"t": 2, "place": 0}]}]})
	_check("a motion on it, out and back: %s" % kept.get_slice("\n", 0).left(70), kept.begins_with("Kept"))
	_main.call("open_pose")
	await _frames(5)
	_pose.play("Swing the back window")
	var swung: bool = false
	for _n: int in 300:
		await process_frame
		if not _world.drawn_ids().is_empty():
			swung = true
		if not _pose.is_playing():
			break
	off = _off(built)
	_check("Play of it in Build, Motions… swings it and leaves every part where it was built (%d off)"
		% off[0], swung and not _pose.is_playing() and int(off[0]) == 0)
	_pose.close()
	await _frames(3)
	# The windscreen's angle connector, which move_part says meets the
	# model at once.
	var said: String = await _say("move_part", {"part": "#143", "degrees": 30})
	_check("move_part says the windscreen meets the model at once: %s" % said.get_slice("\n", 1).left(70),
		said.contains("It did not move"))
	said = _text(await _finished(await _rpc("tools/call", {"name": "animate_model", "arguments":
		{"keys": [{"t": 0, "angles": {"#143": 0}}, {"t": 1, "angles": {"#143": 30}}]}})))
	print("    " + said.replace("\n", "\n    "))
	_check("animate_model on it says where it stopped", said.contains("#143 stops at 0° of the 30° asked"))
	_check("...and the model stands as it was built", int(_off(built)[0]) == 0)


func _racer() -> void:
	print("── 8808-1: \"show me the steering turning\" ──")
	if not await _open(RACER):
		return
	var built: Dictionary = _poses()
	var moves: String = await _say("move_part", {})
	var wheel: int = 0
	var arms: Array = []
	for line: String in moves.split("\n"):
		if line.begins_with("  steering: #"):
			for named: String in line.trim_prefix("  steering: ").split(", "):
				var id: int = int(named.trim_prefix("#").get_slice(" ", 0))
				if named.contains("Steering Wheel"):
					wheel = id
				elif named.contains("Steering Arm"):
					arms.append(id)
	_check("move_part names the steering wheel and both arms (#%d, %s)" % [wheel, str(arms)],
		wheel > 0 and arms.size() == 2)
	# Pose's joints here are the file's: the steering arms, in a loop with
	# the rack, cannot turn on their own, and pose_model says so.
	var joints: String = await _say("pose_model", {})
	var held: Array = []
	for line: String in joints.split("\n"):
		if line.contains("with no room to turn 10° or 90° either way"):
			held.append(line.strip_edges().get_slice(",", 0))
	_check("pose_model says which of its joints have no room to turn (%s), and points to move_part"
		% ", ".join(held), held == ["2. Main Sub 12", "3. Main Sub 13"]
		and joints.contains("move_part with no part= lists what a drag moves"))
	_check("...and changes nothing", int(_off(built)[0]) == 0)
	if wheel == 0 or arms.size() != 2:
		return
	# Looking at something else, far off: the session cannot see the window.
	_camera.frame(AABB(Vector3(-2000, -200, -2000), Vector3(4000, 400, 4000)), 1.2)
	await _frames(20)
	var key: String = "#%d" % wheel
	var keys: Array = [{"t": 0, "angles": {key: 0}}, {"t": 1, "angles": {key: 40}},
		{"t": 2, "angles": {key: -40}}, {"t": 3, "angles": {key: 0}}]
	var answer: Dictionary = await _finished(await _rpc("tools/call", {"name": "animate_model",
		"arguments": {"keys": keys}}))
	var said: String = _text(answer)
	print("    " + said.replace("\n", "\n    "))
	_check("the answer says how long drawing took, not as the film's length: %s"
		% said.get_slice(": ", 1).left(60), said.contains("37 frames, 12 a second, drawn in "))
	# A sheet of its frames at its keys, for a session that cannot watch it.
	var sheet: Image = _image_of(answer)
	var pieces: Array = []
	if sheet != null:
		for k: int in 4:
			pieces.append(sheet.get_region(Rect2i(Vector2i((k % 2) * 484, (k / 2) * 304), Vector2i(480, 300))))
		sheet.save_png(_out.path_join("session_sheet.png"))
	_check("...and a picture of its frames at its four keys (%s), the steering turned in the second"
		% (str(sheet.get_size()) if sheet != null else "none"), sheet != null
		and sheet.get_size() == Vector2i(964, 604) and _changed(pieces[0], pieces[1]) > 200
		and said.contains("its frames at 0 s, 1 s, 2 s, 3 s"))
	var first: Image = _frame_of(said, 1)
	var wide: Vector2 = _spread(first)
	_check("the window zoomed far out, the session's animation frames the car: it spans %d%% x %d%%"
		% [roundi(wide.x * 100.0), roundi(wide.y * 100.0)] + " of its first frame",
		first != null and maxf(wide.x, wide.y) > 0.5)
	if first != null:
		first.save_png(_out.path_join("session_first_frame.png"))
	_check("...and the model stands as it was built", int(_off(built)[0]) == 0)
	# The person, then, in Build, Motions…, where the session's keys are.
	_camera.frame(_model_box(), 1.25)
	await _frames(20)
	_main.call("open_pose")
	await _frames(5)
	var animation: Motions.Motion = (_main.get("_motions") as MotionPlayer).motions().named("Animation")
	_check("the session's keys are the panel's motion \"Animation\" (%d keys)" % (
		(animation.tracks[0] as Motions.Track).keys.size() if animation != null else 0),
		animation != null and (animation.tracks[0] as Motions.Track).keys.size() == 4
		and _pose._row_buttons.any(func(row: Dictionary) -> bool: return str(row["name"]) == "Animation"))
	_pose.play("Animation")
	var turned: Dictionary = {}
	for _n: int in 400:
		await process_frame
		for id: int in arms:
			var at: Variant = _world.drawn_ids().get(id)
			if at != null and not (at as Transform3D).basis.is_equal_approx((built[id] as Transform3D).basis):
				turned[id] = true
		if not _pose.is_playing():
			break
	_check("Play turns both steering arms in the window (%d of 2)" % turned.size(), turned.size() == 2)
	_check("...and ends with every part back where it was built", not _pose.is_playing()
		and int(_off_tolerant(built)[0]) == 0)
	_pose._chosen = "Animation"
	var frames: int = await _pose.render_animation()
	said = _pose.rendered_words()
	var start: Image = _frame_of(said, 1)
	var middle: Image = _frame_of(said, 13)
	var changed: int = _changed(start, middle)
	_check("the panel's Render animation draws the steering turning: %d pixels differ at 1 s" % changed,
		frames == 37 and changed > 200)
	_check("...and the model stands as it was built", int(_off(built)[0]) == 0)
	# Cancel, as the panel's button does, a few frames in.
	var cancelled: Array = [false]
	var stop := func() -> void:
		await _frames(30)
		_pose.renderer.cancel()
		cancelled[0] = true
	stop.call()
	frames = await _pose.render_animation()
	_check("Cancel stops a render part way (%d of 37 frames): %s" % [frames, _pose.rendered_words()],
		cancelled[0] and frames < 37 and _pose.rendered_words() == "Cancelled.")
	_check("...and the model stands as it was built", int(_off(built)[0]) == 0)
	_pose.close()


## Twelve frames at 12 a second, then six of the same name.
func _mp4() -> void:
	print("── an MP4 kept after a longer one of the same name ──")
	if RenderOutput.ffmpeg().is_empty():
		print("    (no ffmpeg here: no MP4 to look at)")
		return
	var folder: String = _out.path_join("mp4")
	DirAccess.make_dir_recursive_absolute(folder)
	for count: int in [12, 6]:
		var settings := RenderSettings.new()
		settings.fps = 12
		settings.frames = count
		var output := RenderOutput.new()
		output.folder = folder
		output.begin_turntable("Runs", settings, "_animation")
		for n: int in count:
			var image := Image.create(64, 48, false, Image.FORMAT_RGB8)
			image.fill(Color.from_hsv(float(n) / 12.0, 0.8, 0.9))
			await output.add_frame(n, image)
		await output.finish_turntable()
	var mp4: String = folder.path_join("runs_animation.mp4")
	var said: Array = []
	OS.execute("ffprobe", ["-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries",
		"stream=nb_read_frames,r_frame_rate", "-of", "csv=p=0", mp4], said)
	var probed: String = str(said[0]).strip_edges() if not said.is_empty() else ""
	_check("the six-frame MP4 is 6 frames at 12 a second (%s)" % probed, probed == "12/1,6")
	var pngs: int = 0
	for file: String in DirAccess.get_files_at(folder.path_join("runs_animation")):
		if file.ends_with(".png"):
			pngs += 1
	_check("...and its folder holds its 6 frames (%d)" % pngs, pngs == 6)


# -- helpers ---------------------------------------------------------------------


func _open(path: String) -> bool:
	if not FileAccess.file_exists(path):
		print("    (no %s: tools/omr.py fetch brings the sets)" % path)
		_failures += 1
		return false
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 400:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(5)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null and playback.is_playing():
		playback.stop()
	_builder.forget_history()
	await _frames(20)
	return _world.brick_count() > 0


## [parts not standing exactly as in [param built], the furthest off in LDU].
func _off(built: Dictionary) -> Array:
	var count: int = 0
	var most: float = 0.0
	for brick: BrickWorld.Brick in _world.bricks():
		var was: Variant = built.get(brick.id)
		if was == null or not (was as Transform3D).is_equal_approx(brick.transform):
			count += 1
			if was != null:
				most = maxf(most, (was as Transform3D).origin.distance_to(brick.transform.origin))
	return [count, most]


## As [method _off], within 0.05 LDU and a tenth of a degree: a play kept
## where it ends is laid down again through Grab, and a loop's slide
## comes back within a thousandth of an LDU.
func _off_tolerant(built: Dictionary) -> Array:
	var count: int = 0
	var most: float = 0.0
	for brick: BrickWorld.Brick in _world.bricks():
		var was: Variant = built.get(brick.id)
		if was == null:
			count += 1
			continue
		var off: float = (was as Transform3D).origin.distance_to(brick.transform.origin)
		var a: Basis = (was as Transform3D).basis.orthonormalized()
		var b: Basis = brick.transform.basis.orthonormalized()
		var chord: float = maxf(a.x.distance_to(b.x), maxf(a.y.distance_to(b.y), a.z.distance_to(b.z)))
		if off > 0.05 or chord > 0.0018:
			count += 1
			most = maxf(most, off)
	return [count, most]


func _poses() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


func _model_box() -> AABB:
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			var here := AABB(brick.transform.origin - Vector3.ONE * 10.0, Vector3.ONE * 20.0)
			box = here if first else box.merge(here)
			first = false
	return box


## Frame [param n] (from 1) of the render an answer says it kept, read off
## the disk: "frames in DIR".
func _frame_of(said: String, n: int) -> Image:
	var found: RegExMatch = RegEx.create_from_string("frames in ([^;\\n]+?)(;|$| —)").search(said)
	if found == null:
		return null
	var path: String = found.get_string(1).strip_edges().path_join("frame_%04d.png" % n)
	return Image.load_from_file(path) if FileAccess.file_exists(path) else null


## How much of a picture the model spans, across and up, 0 to 1: the
## pixels darker or more coloured than the sweep behind it.
func _spread(image: Image) -> Vector2:
	if image == null:
		return Vector2.ZERO
	var low := Vector2i(image.get_width(), image.get_height())
	var high := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.s > 0.25 or c.v < 0.45:
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	if high.x < 0:
		return Vector2.ZERO
	return Vector2(float(high.x - low.x + 1) / image.get_width(),
		float(high.y - low.y + 1) / image.get_height())


func _changed(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return 0
	var count: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.1:
				count += 1
	return count


func _say(tool: String, arguments: Dictionary) -> String:
	return _text(await _rpc("tools/call", {"name": tool, "arguments": arguments}))


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


## The picture an answer carries, or null.
static func _image_of(result: Dictionary) -> Image:
	for block: Dictionary in result.get("content", []):
		if str(block.get("type", "")) == "image":
			var image := Image.new()
			if image.load_png_from_buffer(Marshalls.base64_to_raw(str(block.get("data", "")))) == OK:
				return image
	return null


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


## [param result], or when it is a job, the job's answer once it ends.
func _finished(result: Dictionary) -> Dictionary:
	var found: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(_text(result))
	if found == null:
		return result
	for _n: int in 120:
		var polled: Dictionary = await _rpc("tools/call", {"name": "job", "arguments":
			{"id": int(found.get_string(1))}})
		if not _text(polled).contains(" is still going"):
			return polled
	return {"content": [{"type": "text", "text": "the job never ended"}]}


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
