## Recording what moves in real sets, every way the app has, as a person and
## as a session over MCP do: the audit behind docs/ANIMATION.md.
##
##   godot --path . --resolution 1400x900 --script src/dev/anim_walk_probe.gd
##   ... -- --into=DIR --only=steering,crane,door,gears,figure
##
## For each set it asks what moves (move_part with no part=), what poses
## (pose_model, and Build, Pose and animate's sliders), animates the part
## that moves (animate_model by its part, and the Pose panel's own keys
## where it has a joint), plays it in the window, and renders it; gears are
## recorded by Simulate as well. Every answer is printed and every file kept
## in DIR (one folder a set), with a picture of the window beside each.
## Headless it reads and answers but draws nothing.
extends SceneTree

const SETS: Dictionary = {
	"steering": ["res://vendor/omr/files/8808-1.mpd", "steering", 25.0],
	"crane": ["res://vendor/omr/files/4096-1_Crane.mpd", "boom", 30.0],
	"door": ["res://vendor/omr/files/31070-1.mpd", "doors", 70.0],
	"gears": ["res://vendor/omr/files/8020-1_Windmill.mpd", "gears", 180.0],
	"figure": ["res://vendor/omr/files/6061-1.mpd", "Minifig Arm", 60.0],
}

var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
var _shell: Shell
var _pose: PosePanel
var _out: String = ""
var _next: int = 0
var _here: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var only: PackedStringArray = PackedStringArray(SETS.keys())
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--into="):
			_out = argument.trim_prefix("--into=")
		elif argument.begins_with("--only="):
			only = argument.trim_prefix("--only=").split(",")
	if _out.is_empty():
		_out = ProjectSettings.globalize_path("res://shots/anim_walk")
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
	_shell = _main.get("_shell")
	_pose = _main.get("_pose")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	print("drawing: %s" % ("yes" if StudioRender.possible() else "no, headless"))
	for name: String in only:
		if SETS.has(name):
			await _walk(name)
	print("anim walk: done")
	_main.queue_free()
	await process_frame
	quit(0)


func _walk(name: String) -> void:
	var entry: Array = SETS[name]
	print("\n══ %s: %s ══" % [name, str(entry[0]).get_file()])
	_here = _out.path_join(name)
	DirAccess.make_dir_recursive_absolute(_here)
	Download.folder = _here
	_pose.folder = _here
	var simulate: SimulatePanel = _main.get("_simulate")
	if simulate != null:
		simulate.folder = _here
	if not await _open(str(entry[0])):
		print("  could not open it")
		return
	await _shot("0_opened")
	var before: Dictionary = _poses()
	var moves: String = await _say("move_part", {})
	print("── move_part {} ──\n" + moves)
	print("  [moved so far: %d]" % _differing(before))
	var poses: String = await _say("pose_model", {})
	print("── pose_model {} ──\n" + poses)
	print("  [moved so far: %d]" % _differing(before))
	# A person: Build, Pose and animate…
	_shell.run("pose")
	await _frames(5)
	var labels := PackedStringArray()
	for one: Poser.Joint in _pose.poser.joints:
		labels.append("%s (%s, %d parts)" % [Assemblies.label(one.path), one.kind(), one.ids.size()])
	print("── Pose panel: %d slider(s) ──\n  %s\n  status: %s" % [labels.size(), "\n  ".join(labels),
		_pose._status.text])
	print("  [moved so far: %d]" % _differing(before))
	await _shot("1_pose_panel")
	await _pose_reach()
	# The part to take hold of: the card's kind when it names one, else the
	# biggest body on a joint.
	var part: int = _part_for(moves, str(entry[1]))
	print("── the part taken: #%d ──" % part)
	if part > 0:
		print(await _say("move_part", {"part": "#%d" % part}))
		print("  [moved so far: %d]" % _differing(before))
		# As a session first tries it: turned, then put back.
		print("── move_part degrees=%d ──\n%s" % [roundi(float(entry[2])), await _say("move_part",
			{"part": "#%d" % part, "degrees": float(entry[2])})])
		print(await _say("undo", {}))
		print("  [moved so far: %d]" % _differing(before))
	var swing: float = float(entry[2])
	if part > 0:
		await _session_animation(part, swing, before)
		print("  [moved so far: %d]" % _differing(before))
	if not _pose.poser.joints.is_empty():
		await _person_animation(swing, before)
		print("  [moved so far: %d]" % _differing(before))
	if name == "gears":
		await _simulated(part)
	_pose.close()
	await _frames(3)
	var moved: int = _differing(before)
	print("── after: %d part(s) not where they were built ──" % moved)


## How far each of Pose's sliders goes each way, against what move_part
## says moves with the same part: the two notions of what moves, side by side.
func _pose_reach() -> void:
	print("── each Pose slider, ±90° and back, against move_part on its first part ──")
	for one: Poser.Joint in _pose.poser.joints.duplicate():
		var path: String = one.path
		var up: float = _pose.set_angle(path, 90.0)
		_pose.set_angle(path, 0.0)
		var down: float = _pose.set_angle(path, -90.0)
		_pose.set_angle(path, 0.0)
		var own: int = _pose.poser._own_brick(_pose.poser.joint(path))
		var said: String = await _say("move_part", {"part": "#%d" % own})
		print("  %s (%s, %d parts): +90 reached %d°, -90 reached %d° | move_part #%d: %s" % [
			Assemblies.label(path), one.kind(), one.ids.size(), roundi(up), roundi(down), own,
			said.get_slice("\n", 0).left(150)])


## animate_model by the part, as a session asks "show me it moving".
func _session_animation(part: int, swing: float, before: Dictionary) -> void:
	var key: String = "#%d" % part
	var keys: Array = [{"t": 0, "angles": {key: 0}}, {"t": 1, "angles": {key: swing}},
		{"t": 2, "angles": {key: -swing}}, {"t": 3, "angles": {key: 0}}]
	var said: String = await _say("animate_model", {"keys": keys, "render": false})
	print("── animate_model render=false ──\n" + said)
	print("  [moved so far: %d]" % _differing(before))
	if not StudioRender.possible():
		said = await _say("animate_model", {"keys": keys})
		print("── animate_model (headless) ──\n" + said)
		return
	var asked_at: int = Time.get_ticks_msec()
	var first: Dictionary = await _rpc("tools/call", {"name": "animate_model", "arguments": {"keys": keys}})
	var done: Dictionary = await _finished(first)
	print("── animate_model, rendered (%.0f s) ──\n%s" % [(Time.get_ticks_msec() - asked_at) / 1000.0,
		_text(done)])
	_keep_last("session")
	await _shot("2_after_session_render")
	print("  window's camera: %s" % str(_camera.global_transform.origin))
	print("  parts moved by the render: %d" % _differing(before))
	# The same keys again, the window's view zoomed out first: the render
	# is a session's, which cannot see the window.
	_camera.frame(AABB(Vector3(-2000, -200, -2000), Vector3(4000, 400, 4000)), 1.2)
	await _frames(20)
	await _shot("3_window_zoomed_out")
	first = await _rpc("tools/call", {"name": "animate_model", "arguments": {"keys": keys}})
	done = await _finished(first)
	print("── animate_model, the window zoomed out ──\n%s" % _text(done))
	_keep_last("session_zoomed_out")
	var box: AABB = _model_box()
	_camera.frame(box, 1.25)
	await _frames(20)


## The Pose panel's own keys, as a person makes them: the first slider swung
## out and back, Add key at each, Play, Render animation.
func _person_animation(swing: float, before: Dictionary) -> void:
	var one: Poser.Joint = _pose.poser.joints[0]
	_pose.animation.keys.clear()
	_pose._key_time.value = 0.0
	_pose.add_key()
	var reached: float = _pose.set_angle(one.path, swing)
	print("── a person: %s swung to %d°: %s" % [Assemblies.label(one.path), roundi(swing),
		_pose._status.text])
	_pose._key_time.value = 1.5
	_pose.add_key()
	print("  [moved so far: %d]" % _differing(before))
	_pose.set_angle(one.path, 0.0)
	print("  [back at 0: moved so far: %d]" % _differing(before))
	_pose._key_time.value = 3.0
	_pose.add_key()
	print("  keys: %d over %.1f s, %d frames at %d a second (reached %.0f°)" % [
		_pose.animation.keys.size(), _pose.animation.length(), _pose.animation.frame_count(),
		_pose.animation.fps, reached])
	_pose.play()
	await _frames(30)
	await _shot("4_person_playing")
	while _pose._playing:
		await process_frame
	print("  [played: moved so far: %d]" % _differing(before))
	if not StudioRender.possible():
		return
	var asked_at: int = Time.get_ticks_msec()
	var frames: int = await _pose.render_animation()
	print("── a person's Render animation: %d frames in %.0f s ──\n  %s" % [frames,
		(Time.get_ticks_msec() - asked_at) / 1000.0, _pose.rendered_words()])
	_keep_last("person")
	await _shot("5_person_rendered")


## Tools, Simulate mechanism over MCP, recorded.
func _simulated(part: int) -> void:
	var said: String = await _say("simulate_mechanism", {} if part <= 0 else {"driver": "#%d" % part})
	print("── simulate_mechanism ──\n" + said)
	if not StudioRender.possible():
		return
	var first: Dictionary = await _rpc("tools/call", {"name": "simulate_mechanism", "arguments":
		{"record": true, "frames": 24} if part <= 0 else {"record": true, "frames": 24, "driver": "#%d" % part}})
	var done: Dictionary = await _finished(first)
	print("── simulate_mechanism record=true ──\n" + _text(done))
	_keep_last("simulate")


## The files just written to this set's folder, moved aside under [param
## as] so the next render does not write over them.
func _keep_last(as_name: String) -> void:
	var into: String = _here.path_join(as_name)
	DirAccess.make_dir_recursive_absolute(into)
	var dir := DirAccess.open(_here)
	if dir == null:
		return
	for file: String in dir.get_files():
		if file.ends_with(".webp") or file.ends_with(".mp4"):
			dir.rename(file, into.path_join(file))
	for sub: String in dir.get_directories():
		if sub.ends_with("_animation") or sub.ends_with("_mechanism"):
			dir.rename(sub, into.path_join(sub))
	print("  kept in %s: %s" % [into, ", ".join(DirAccess.get_files_at(into))])


func _part_for(moves: String, kind: String) -> int:
	# A part by its name, the first in the model.
	if kind.begins_with("Minifig"):
		var library: PartLibrary = _main.get("_library")
		for brick: BrickWorld.Brick in _world.bricks():
			var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
			if info != null and info.name.begins_with(kind):
				return brick.id
	if not kind.is_empty():
		for line: String in moves.split("\n"):
			if line.begins_with("  %s: #" % kind):
				return int(line.trim_prefix("  %s: #" % kind).get_slice(" ", 0))
	var listing: bool = false
	for line: String in moves.split("\n"):
		if line.begins_with("On a joint a drag moves"):
			listing = true
		elif listing and line.begins_with("  #"):
			return int(line.trim_prefix("  #").get_slice(" ", 0))
	return 0


func _open(path: String) -> bool:
	if not FileAccess.file_exists(path):
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
	await _frames(30)
	return _world.brick_count() > 0


func _model_box() -> AABB:
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var here := AABB(brick.transform.origin - Vector3.ONE * 10.0, Vector3.ONE * 20.0)
		box = here if first else box.merge(here)
		first = false
	return box


func _poses() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


## How many parts stand other than in [param before]; the most any moved
## is kept in [member _most] (LDU, and the basis's largest change).
func _differing(before: Dictionary) -> int:
	var count: int = 0
	_most = Vector2.ZERO
	for brick: BrickWorld.Brick in _world.bricks():
		var was: Variant = before.get(brick.id)
		if was == null or not (was as Transform3D).is_equal_approx(brick.transform):
			count += 1
			if was != null:
				var a: Transform3D = was
				var b: Transform3D = brick.transform
				_most.x = maxf(_most.x, a.origin.distance_to(b.origin))
				_most.y = maxf(_most.y, maxf(a.basis.x.distance_to(b.basis.x), maxf(
					a.basis.y.distance_to(b.basis.y), a.basis.z.distance_to(b.basis.z))))
	if count > 0:
		print("    (the most: %.4f LDU, basis %.6f)" % [_most.x, _most.y])
	return count


var _most := Vector2.ZERO


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _here.path_join("window_%s.png" % name)
	image.save_png(path)


func _say(tool: String, arguments: Dictionary) -> String:
	return _text(await _rpc("tools/call", {"name": tool, "arguments": arguments}))


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


static func _job_of(result: Dictionary) -> int:
	var found: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(_text(result))
	return int(found.get_string(1)) if found != null else 0


## [param result], or when it is a job, the job's answer once it ends.
func _finished(result: Dictionary) -> Dictionary:
	var id: int = _job_of(result)
	if id == 0:
		return result
	for _n: int in 120:
		var polled: Dictionary = await _rpc("tools/call", {"name": "job", "arguments": {"id": id}})
		if _text(polled).contains(" is still going"):
			continue
		return polled
	return {"content": [{"type": "text", "text": "job %d never ended" % id}]}


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
