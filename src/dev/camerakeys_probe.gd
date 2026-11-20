## The camera keyed in a motion (docs/APP_UX10.md gap 12, unit camerakeys):
## where it stands, what it looks at and its lens, kept in the motion's
## MOTION_CAMERA lines, played in the window and filmed through.
##
##   godot --path . --resolution 1400x900 --script src/dev/camerakeys_probe.gd
##   ... -- OUT_DIR   (where the files go; shots/camerakeys when not given)
##
## On 1484-1 (vendor/omr/files), its doors and gates:
##  1. Keyed in the Motions panel as a person keys it: a new motion, the
##     view turned three ways at 0, 2 and 4 s and Key the camera pressed at
##     each; three keys, three steps, each the view's numbers.
##  2. Played in the window: at each key's frame the window's camera within
##     1 LDU and 1° of where the key puts it, by the probe's own sum from
##     the key's numbers; no flip through a pole (its up never below
##     level, no frame's turn a big jump); the model drawn as it stands and
##     no step kept. A wheel turn and a hand zoom part way are put back and
##     the status says so; at the end, and at a Stop part way, the view is
##     the person's again, where it was, its lens too.
##  3. Filmed: render_motion and File, Render's Animation draw each key's
##     frame from where the key puts the camera, within 1 LDU and 1°, every
##     frame drawn from the keyed track, nothing moved in the model.
##  4. A turntable is two keys: Turntable pressed makes two, once round at
##     one speed, at the height and distance the camera stands; filmed, its
##     first and last frames drawn from the same place and alike, the
##     middle from the far side, the model in the middle of every frame.
##     Undo brings the three keys back byte for byte.
##  5. Saved: the three lines in the file, opened again and written byte
##     for byte the same, twice; another motion changed, the camera lines
##     kept byte for byte.
##  6. Picked together: on the doors' motion with the camera keyed, two
##     camera keys and a door's key Ctrl+clicked and Delete pressed: one
##     step takes all three out, Undo brings them back byte for byte; two
##     picked keys dragged move both in one step; Delete typed in the name
##     field, or after a press in the view, takes no key out.
##  7. The person's Claude: render_motion with camera= {"turntable": true}
##     on a name the model has not got makes it and films it in one call,
##     its first and last frames from one place.
##  8. Time: a camera track playing on Orthanc against the view turned the
##     same way by hand, each frame's own work (Performance TIME_PROCESS):
##     at most 1 ms more a frame.
##
## Pictures in shots/camerakeys/ (or OUT_DIR), named by the window's size.
extends SceneTree

const DOORS := "res://vendor/omr/files/1484-1.mpd"
const ORTHANC := "res://models/orthanc.ldr"
## LDraw's coordinates in the window's: y and z the other way.
const FLIP := Vector3(1.0, -1.0, -1.0)
const NEAR_LDU := 1.0
const NEAR_DEG := 1.0
const TIMES: Array = [0.0, 2.0, 4.0]
const PLAY_FPS := 12

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _player: MotionPlayer
var _panel: PosePanel
var _shell: Shell
var _eye: Camera3D
var _out: String = ""
var _next: int = 0
var _size: String = ""
var _windowed: bool = false
var _last_screen := Vector2.ZERO
## The motion keyed in the panel, by its name.
var _name: String = ""
## Each frame's shot as a render draws it: frame -> [origin, facing, fov].
var _shots: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://shots/camerakeys")
	DirAccess.make_dir_recursive_absolute(_out)
	if not FileAccess.file_exists(ProjectSettings.globalize_path(DOORS)):
		print("camerakeys_probe: SKIPPED, no %s (tools/omr.py fetch brings the sets)" % DOORS)
		quit(3)
		return
	await _start()
	_windowed = StudioRender.possible()
	if not _windowed:
		print("camerakeys probe: drawn headless, so nothing is rendered (tools/probe.sh runs it in a window)")
	var files: String = OS.get_user_data_dir().path_join("camerakeys_files_%d_%d"
		% [int(Time.get_unix_time_from_system()), OS.get_process_id()])
	DirAccess.make_dir_recursive_absolute(files)
	Download.folder = files
	_panel.folder = files
	(_main.get("_render") as RenderDialog).folder = files
	if await _open(DOORS):
		if await _keyed():
			await _played()
			await _filmed()
			await _turntable()
			await _saved()
		await _picked()
		await _mcp()
	await _time()
	print("")
	print("camerakeys_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	_main.queue_free()
	for _n: int in 5:
		await process_frame
	quit(1 if _failures > 0 else 0)


func _start() -> void:
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_player = _main.get("_motions")
	_panel = _main.get("_pose")
	_shell = _main.get("_shell")
	_eye = _main.get("_camera")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame


# -- 1. keyed in the panel ------------------------------------------------------------------


## Three views a person might turn to: [focus offset from the model's
## middle, yaw, pitch (degrees), distance as a share of the model's size,
## lens].
func _views() -> Array:
	var box: AABB = _player._model_box()
	var middle: Vector3 = box.get_center()
	var size: float = maxf(box.size.length(), 100.0)
	return [[middle, 20.0, 25.0, size * 1.6, 30.0],
		[middle + Vector3(size * 0.1, 0.0, 0.0), 130.0, 55.0, size * 1.1, 42.0],
		[middle - Vector3(0.0, size * 0.05, 0.0), 250.0, -10.0, size * 2.0, 28.0]]


func _aim(view: Array) -> void:
	var focus: Vector3 = view[0]
	_eye.call("aim_at", {"yaw": deg_to_rad(float(view[1])), "pitch": deg_to_rad(float(view[2])),
		"distance": float(view[3]), "focus": [focus.x, focus.y, focus.z]})
	_eye.fov = float(view[4])


func _keyed() -> bool:
	print("\n1. keyed in the Motions panel (%s)" % _size)
	_shell.run("pose")
	await _frames(10)
	await _click(_panel.controls_by_name()["motions_new"])
	await _frames(6)
	var depth: int = _builder.history_depth()
	var views: Array = _views()
	for n: int in 3:
		_panel.set_time(float(TIMES[n]))
		_aim(views[n])
		await _frames(40)
		await _seen(_panel.controls_by_name()["motions_key_camera"])
		await _click(_panel.controls_by_name()["motions_key_camera"])
		await _frames(4)
	var motion: Motions.Motion = _panel._edited()
	_name = motion.name if motion != null else ""
	var keys: Array = motion.camera.keys if motion != null and motion.camera != null else []
	_check("Key the camera pressed at 0, 2 and 4 s keeps three keys in the new motion %s, three steps (%d)"
		% [Motions.quoted(_name), _builder.history_depth() - depth], keys.size() == 3
		and _builder.history_depth() == depth + 3 and _player.motions().named(_name) != null)
	if keys.size() != 3:
		return false
	var lift: Vector3 = _store.lift()
	var worst: Array = [0.0, 0.0]
	for n: int in 3:
		var view: Array = views[n]
		var key: Array = keys[n]
		var at: Vector3 = (key[1] as Vector3) * FLIP + lift
		worst[0] = maxf(float(worst[0]), at.distance_to(view[0]))
		worst[1] = maxf(float(worst[1]), absf(angle_difference(deg_to_rad(float(key[2])), deg_to_rad(float(view[1])))))
		worst[1] = maxf(float(worst[1]), absf(deg_to_rad(float(key[3]) - float(view[2]))))
		_check("key %d at %s s: %s" % [n + 1, Motions.num(float(key[0]), 2), Motions.camera_line(_name, key)],
			is_equal_approx(float(key[0]), float(TIMES[n])) and absf(float(key[4]) - float(view[3])) < 0.02
			and absf(float(key[5]) - float(view[4])) < 0.02)
	_check("...each the view's own: the point it looks at within %.3f LDU, its turn and tilt within %.3f°"
		% [worst[0], rad_to_deg(worst[1])], float(worst[0]) < 0.02 and rad_to_deg(worst[1]) < 0.02)
	var lines: PackedStringArray = _camera_lines(_store.to_text("Doors"))
	_check("the file has the three MOTION_CAMERA lines (%d)" % lines.size(), lines.size() == 3)
	_fits("the camera keyed")
	await _shot("1_keyed")
	return true


# -- 2. played in the window ------------------------------------------------------------------


## Where key [param key] puts the camera, the probe's own sum from its
## numbers: {at, from, facing, fov}.
func _expected(key: Array) -> Dictionary:
	var at: Vector3 = (key[1] as Vector3) * FLIP + _store.lift()
	var turn: float = deg_to_rad(float(key[2]))
	var tilt: float = deg_to_rad(float(key[3]))
	var from: Vector3 = at + Vector3(cos(tilt) * sin(turn), sin(tilt), cos(tilt) * cos(turn)) * float(key[4])
	return {"at": at, "from": from, "facing": (at - from).normalized(), "fov": float(key[5])}


## [LDU off, degrees off, lens off] of a camera at [param from] facing
## [param facing] through [param fov] against [param want].
static func _off_from(from: Vector3, facing: Vector3, fov: float, want: Dictionary) -> Array:
	return [from.distance_to(want["from"]), rad_to_deg(facing.angle_to(want["facing"])),
		absf(fov - float(want["fov"]))]


func _played() -> void:
	print("\n2. played in the window")
	var motion: Motions.Motion = _player.motions().named(_name)
	var keys: Array = motion.camera.keys
	var built: Dictionary = _poses()
	var depth: int = _builder.history_depth()
	_eye.call("aim_at", {"yaw": 0.4, "pitch": 0.3, "distance": 900.0, "focus": [10.0, -30.0, 5.0]})
	_eye.fov = 33.0
	await _frames(60)
	var before: Dictionary = _eye.call("aim")
	var seen: Dictionary = {}
	var drawn_moved: int = 0
	var flipped: int = 0
	var jump: float = 0.0
	var last_facing := Vector3.ZERO
	var held_said: bool = false
	var put_back: float = -1.0
	await _click(_panel.controls_by_name()["motions_play"])
	for frame: int in 3000:
		await process_frame
		if not _panel.is_playing():
			break
		var shown: int = int(_panel.get("_shown"))
		var at: Transform3D = _eye.global_transform
		if shown >= 0 and not seen.has(shown):
			seen[shown] = [at, _eye.fov]
		if not _world.drawn_ids().is_empty():
			drawn_moved += 1
		if at.basis.y.y < 0.0:
			flipped += 1
		var facing: Vector3 = -at.basis.z
		if last_facing != Vector3.ZERO:
			jump = maxf(jump, rad_to_deg(facing.angle_to(last_facing)))
		last_facing = facing
		# Part way, a wheel turn over the view and a hand zoom: put back.
		if shown == 30 and put_back < 0.0:
			await _wheel(root.get_visible_rect().get_center() + Vector2(-200, 0), 3)
			_eye.call("key_zoom", 4)
			await _frames(2)
			# Where this frame's camera is, as the panel holds it.
			var now: int = int(_panel.get("_shown"))
			var cameras: Array = _panel.get("_cameras")
			put_back = _eye.global_position.distance_to(MotionPlayer.camera_transform(cameras[now]).origin) \
				if now >= 0 and now < cameras.size() and cameras[now] != null else 1e9
			held_said = (_panel.get("_status") as Label).text == PosePanel.HELD_WORDS
			await _shot("2_held")
	await _frames(30)
	var report := PackedStringArray()
	var worst: Array = [0.0, 0.0, 0.0]
	var found: int = 0
	for n: int in 3:
		var frame_at: int = roundi(float(keys[n][0]) * PLAY_FPS)
		if not seen.has(frame_at):
			continue
		found += 1
		var t: Transform3D = seen[frame_at][0]
		var off: Array = _off_from(t.origin, -t.basis.z, float(seen[frame_at][1]), _expected(keys[n]))
		for k: int in 3:
			worst[k] = maxf(float(worst[k]), float(off[k]))
		report.append("frame %d %.3f LDU %.3f° lens %.3f°" % [frame_at, off[0], off[1], off[2]])
	_check("Play goes through all three keys: at each key's frame the window's camera where the key puts it (%s)"
		% ", ".join(report), found == 3 and float(worst[0]) <= NEAR_LDU and float(worst[1]) <= NEAR_DEG
		and float(worst[2]) <= 0.01)
	_check("...upright all the way, no flip through a pole (%d frames upside down), each frame's turn at most %.1f°"
		% [flipped, jump], flipped == 0 and jump < 20.0)
	_check("...the model drawn as it stands (%d frames drawn moved) and no step kept (%d)" % [drawn_moved,
		_builder.history_depth() - depth], drawn_moved == 0 and _builder.history_depth() == depth
		and int(_off(built, 0.0)[0]) == 0)
	_check("a wheel turn and a hand zoom part way are put back (%.3f LDU off the key's view) and the status says so"
		% put_back, put_back >= 0.0 and put_back < NEAR_LDU and held_said)
	var after: Dictionary = _eye.call("aim")
	_check("at the end the view is the person's again, where it was (%s), its lens %.1f°" % [_aim_off(before, after),
		_eye.fov], not bool(_eye.call("is_held")) and _aim_off(before, after) == "same" and is_equal_approx(_eye.fov, 33.0))
	# Stopped part way: given back too.
	await _click(_panel.controls_by_name()["motions_play"])
	for _n: int in 600:
		await process_frame
		if int(_panel.get("_shown")) >= 12:
			break
	var held_mid: bool = bool(_eye.call("is_held"))
	await _click(_panel.controls_by_name()["motions_play"])
	await _frames(30)
	after = _eye.call("aim")
	_check("Stop part way gives the view back (held while it played: %s; now %s, lens %.1f°)" % [held_mid,
		_aim_off(before, after), _eye.fov], held_mid and not bool(_eye.call("is_held"))
		and _aim_off(before, after) == "same" and is_equal_approx(_eye.fov, 33.0) and not _panel.is_playing())


static func _aim_off(one: Dictionary, other: Dictionary) -> String:
	var off: Array = []
	for word: String in ["yaw", "pitch", "distance"]:
		if absf(float(one[word]) - float(other[word])) > 0.0001 * maxf(1.0, absf(float(one[word]))):
			off.append("%s %s → %s" % [word, one[word], other[word]])
	var a: Array = one["focus"]
	var b: Array = other["focus"]
	if Vector3(a[0], a[1], a[2]).distance_to(Vector3(b[0], b[1], b[2])) > 0.01:
		off.append("focus %s → %s" % [a, b])
	return "same" if off.is_empty() else ", ".join(off)


# -- 3. filmed ----------------------------------------------------------------------------------


func _on_shot(n: int, shot: StudioRender.Shot) -> void:
	_shots[n] = [shot.origin, -shot.basis.z, shot.fov]


func _filmed() -> void:
	print("\n3. filmed")
	if not _windowed:
		print("  (headless: not rendered)")
		return
	var motion: Motions.Motion = _player.motions().named(_name)
	var keys: Array = motion.camera.keys
	var built: Dictionary = _poses()
	var depth: int = _builder.history_depth()
	_panel._ready_renderer()
	_shots.clear()
	_panel.renderer.frame_shot.connect(_on_shot)
	var said: String = _text(await _finished(await _rpc("tools/call", {"name": "render_motion",
		"arguments": {"name": _name, "fps": 12, "size": "480x300"}})))
	_print(said)
	_panel.renderer.frame_shot.disconnect(_on_shot)
	_against_keys("render_motion", said.contains("through its camera keys"), keys)
	_check("...the model as it was and no step kept", int(_off(built, 0.0)[0]) == 0
		and _builder.history_depth() == depth)
	var dir: String = _frames_dir(str(_panel._last.get("name", "")), _panel.folder)
	_keep_frames(dir, "3_render_motion", 49)
	# File, Render's Animation, pressed as a person presses it.
	var dialog: RenderDialog = _main.get("_render")
	dialog._make_renderer()
	_shots.clear()
	dialog.renderer.frame_shot.connect(_on_shot)
	_shell.run("render")
	await _frames(20)
	var motions: OptionButton = dialog.controls_by_name()["render_motion"]
	for n: int in motions.item_count:
		if str(motions.get_item_metadata(n)) == _name:
			motions.select(n)
			motions.item_selected.emit(n)
	await _click(dialog.controls_by_name()["render_quick"])
	await _shot("3_dialog")
	await _click(dialog.controls_by_name()["render_animation"])
	for _n: int in 20000:
		await process_frame
		if not dialog.is_rendering():
			break
	await _frames(5)
	dialog.renderer.frame_shot.disconnect(_on_shot)
	print("    dialog: %s" % dialog._status.text)
	_against_keys("File, Render's Animation", true, keys)
	dialog.close()
	await _frames(5)


## The shots a render drew against [param keys]: each key's frame from where
## the key puts the camera, every frame drawn.
func _against_keys(what: String, said: bool, keys: Array) -> void:
	var report := PackedStringArray()
	var worst: Array = [0.0, 0.0, 0.0]
	var found: int = 0
	for key: Array in keys:
		var n: int = roundi(float(key[0]) * 12.0)
		if not _shots.has(n):
			continue
		found += 1
		var off: Array = _off_from(_shots[n][0], _shots[n][1], float(_shots[n][2]), _expected(key))
		for k: int in 3:
			worst[k] = maxf(float(worst[k]), float(off[k]))
		report.append("frame %d %.3f LDU %.3f° lens %.3f°" % [n, off[0], off[1], off[2]])
	var frames: int = roundi(float(keys.back()[0]) * 12.0) + 1
	_check("%s films through the camera keys, %d of %d frames drawn: %s" % [what, _shots.size(), frames,
		", ".join(report)], said and found == keys.size() and _shots.size() == frames
		and float(worst[0]) <= NEAR_LDU and float(worst[1]) <= NEAR_DEG and float(worst[2]) <= 0.01)


# -- 4. a turntable ------------------------------------------------------------------------------


func _turntable() -> void:
	print("\n4. a turntable is two keys")
	var before: PackedStringArray = _camera_lines(_store.to_text("Doors"))
	var depth: int = _builder.history_depth()
	_aim(_views()[0])
	await _frames(60)
	var box: AABB = _player._model_box()
	var offset: Vector3 = _eye.global_position - box.get_center()
	await _seen(_panel.controls_by_name()["motions_turntable"])
	await _click(_panel.controls_by_name()["motions_turntable"])
	await _frames(4)
	var motion: Motions.Motion = _player.motions().named(_name)
	var keys: Array = motion.camera.keys if motion.camera != null else []
	var ok: bool = keys.size() == 2 and _builder.history_depth() == depth + 1
	if ok:
		var first: Array = keys[0]
		var last: Array = keys[1]
		ok = is_zero_approx(float(first[0])) and is_equal_approx(float(last[0]), 4.0) \
			and str(first[6]) == "LINEAR" and str(last[6]) == "LINEAR" \
			and is_equal_approx(float(last[2]) - float(first[2]), 360.0) \
			and absf(float(first[4]) - offset.length()) < 0.02 \
			and absf(float(first[3]) - rad_to_deg(asin(offset.y / offset.length()))) < 0.02 \
			and ((first[1] as Vector3) * FLIP + _store.lift()).distance_to(box.get_center()) < 0.02
	_check("Turntable makes two keys, one step: once round the model's middle in 4 s at one speed, at the height and distance the camera stood (%s)"
		% " / ".join(_camera_lines(_store.to_text("Doors"))), ok)
	await _shot("4_turntable")
	if ok and _windowed:
		_panel._ready_renderer()
		_shots.clear()
		_panel.renderer.frame_shot.connect(_on_shot)
		var said: String = _text(await _finished(await _rpc("tools/call", {"name": "render_motion",
			"arguments": {"name": _name, "fps": 12, "size": "480x300"}})))
		_print(said)
		_panel.renderer.frame_shot.disconnect(_on_shot)
		_round(said, keys, "the turntable")
	_shell.run("undo")
	await _frames(8)
	var back: PackedStringArray = _camera_lines(_store.to_text("Doors"))
	_check("Undo brings the three keys back byte for byte", back == before and back.size() == 3)


## A turntable's film: its first and last frames from one place and alike,
## the middle from the far side, the model in the middle of each.
func _round(said: String, keys: Array, what: String) -> void:
	var frames: int = roundi(float(keys.back()[0]) * 12.0) + 1
	if not _shots.has(0) or not _shots.has(frames - 1) or not _shots.has((frames - 1) / 2):
		_check("%s filmed, every frame drawn (%d of %d)" % [what, _shots.size(), frames], false)
		return
	var first: Array = _shots[0]
	var last: Array = _shots[frames - 1]
	var middle: Array = _shots[(frames - 1) / 2]
	var centre: Vector3 = _expected(keys[0])["at"]
	var apart: float = rad_to_deg(((first[0] as Vector3) - centre).angle_to((middle[0] as Vector3) - centre))
	_check("%s filmed: its first and last frames drawn from one place (%.4f LDU, %.4f° apart), the middle from the far side (%.1f° round)"
		% [what, (first[0] as Vector3).distance_to(last[0]), rad_to_deg((first[1] as Vector3).angle_to(last[1])), apart],
		said.contains("through its camera keys") and (first[0] as Vector3).distance_to(last[0]) <= NEAR_LDU
		and rad_to_deg((first[1] as Vector3).angle_to(last[1])) <= NEAR_DEG and absf(apart - 180.0) < 2.0)
	var dir: String = _frames_dir(str(_panel._last.get("name", "")), _panel.folder)
	var one: Image = _frame(dir, 1)
	var other: Image = _frame(dir, frames)
	var half: Image = _frame(dir, (frames - 1) / 2 + 1)
	var alike: float = _difference(one, other)
	_check("...its first and last frames alike (%.4f of a pixel's range apart on average), the middle not (%.4f)"
		% [alike, _difference(one, half)], one != null and alike < 0.01 and _difference(one, half) > alike)
	var off: float = 0.0
	for image: Image in [one, half, other]:
		if image != null:
			off = maxf(off, _drawn_middle(image).distance_to(Vector2(image.get_size()) * 0.5) / float(image.get_width()))
	_check("...the model in the middle of each (at most %.0f%% of the width off)" % (off * 100.0), off < 0.12)
	_keep_frames(dir, "4_%s" % what.replace(" ", "_"), frames)


# -- 5. saved ------------------------------------------------------------------------------------


func _saved() -> void:
	print("\n5. saved")
	var path_a: String = _out.path_join("%s_camera_a.mpd" % _size)
	var path_b: String = _out.path_join("%s_camera_b.mpd" % _size)
	var path_c: String = _out.path_join("%s_camera_c.mpd" % _size)
	if not _store.save_file(path_a, "Doors"):
		_check("saved (%s)" % _store.refused, false)
		return
	var a: String = FileAccess.get_file_as_string(path_a)
	var lines: PackedStringArray = _camera_lines(a)
	_check("saved with its three camera lines: %s" % " / ".join(lines), lines.size() == 3)
	if not await _open(path_a):
		_check("opened again", false)
		return
	var motion: Motions.Motion = _player.motions().named(_name)
	_check("opened again, the motion has its three camera keys", motion != null and motion.camera != null
		and motion.camera.keys.size() == 3)
	_store.save_file(path_b, "Doors")
	_store.save_file(path_c, "Doors")
	var b: String = FileAccess.get_file_as_string(path_b)
	var c: String = FileAccess.get_file_as_string(path_c)
	_check("written again byte for byte the same (%d bytes), and again (%d)" % [b.length(), c.length()],
		a == b and b == c)
	# Another motion changed: the camera's lines kept as they are.
	var said: String = await _say("define_motion", {"name": "Open the doors", "suggested": true})
	_print(said.left(160))
	var edited: String = _store.to_text("Doors")
	_check("another motion kept, the camera lines kept byte for byte", said.begins_with("Kept")
		and _camera_lines(edited) == lines)
	# A hand-written file's own spelling of a key: kept as it is written.
	var spelled: String = a.replace(lines[1], lines[1].replace(" TURN ", " TURN  ").replace(" EASE", " ease"))
	var path_d: String = _out.path_join("%s_camera_d.mpd" % _size)
	_write(path_d, spelled)
	if await _open(path_d):
		var path_e: String = _out.path_join("%s_camera_e.mpd" % _size)
		_store.save_file(path_e, "Doors")
		var e: String = FileAccess.get_file_as_string(path_e)
		motion = _player.motions().named(_name)
		_check("a file's own spelling of a key read and kept byte for byte at an unedited save",
			e == spelled and motion != null and motion.camera != null and motion.camera.keys.size() == 3)
	await _open(path_a)


# -- 6. picked together ------------------------------------------------------------------------


func _picked() -> void:
	print("\n6. keys picked together")
	_panel.back_to_list()
	await _frames(4)
	var said: String = await _say("define_motion", {"name": "Open the doors", "suggested": true})
	said = await _say("define_motion", {"name": "Open the doors", "camera": {"keys": [
		{"t": 0, "turn": 10, "tilt": 30, "away": 900}, {"t": 1, "turn": 60, "tilt": 30, "away": 900},
		{"t": 2.5, "turn": 120, "tilt": 20, "away": 800}]}})
	_print(said.left(200))
	var motion: Motions.Motion = _player.motions().named("Open the doors")
	_check("define_motion camera= alone keys the camera and keeps the doors' tracks", motion != null
		and motion.camera != null and motion.camera.keys.size() == 3 and not motion.tracks.is_empty())
	if motion == null or motion.camera == null or motion.tracks.is_empty():
		return
	if not _panel.visible:
		_shell.run("pose")
		await _frames(6)
	_panel.edit("Open the doors")
	await _frames(10)
	var before: PackedStringArray = _motion_lines(_store.to_text("Doors"))
	var strip: PosePanel.KeyStrip = _panel.controls_by_name()["motions_camera_keys"]
	var door: PosePanel.KeyStrip = _panel._joint_parts[0]["strip"]
	var door_keys: int = door.times.size()
	await _seen(strip)
	await _press_key(strip, 0, false)
	await _press_key(strip, 2, true)
	await _seen(door)
	await _press_key(door, door_keys - 1, true)
	_check("Ctrl+click picks three keys, two of the camera's and a door's (%d picked)" % _panel._picked.size(),
		_panel._picked.size() == 3)
	await _shot("6_picked")
	var depth: int = _builder.history_depth()
	await _key(KEY_DELETE)
	motion = _player.motions().named("Open the doors")
	var cameras: int = motion.camera.keys.size() if motion.camera != null else 0
	var track: Motions.Track = motion.tracks[0] if not motion.tracks.is_empty() else null
	_check("Delete takes all three out in one step (camera keys %d, the door's %d of %d, %d step): %s" % [cameras,
		track.keys.size() if track != null else 0, door_keys, _builder.history_depth() - depth,
		(_panel.get("_status") as Label).text], cameras == 1 and _builder.history_depth() == depth + 1
		and (track != null and track.keys.size() == door_keys - 1 or door_keys == 1))
	_shell.run("undo")
	await _frames(8)
	var back: PackedStringArray = _motion_lines(_store.to_text("Doors"))
	_check("Undo brings all three back byte for byte", back == before)
	# Two picked and one of them dragged: both move, one step.
	_panel.edit("Open the doors")
	await _frames(10)
	strip = _panel.controls_by_name()["motions_camera_keys"]
	await _seen(strip)
	await _press_key(strip, 1, false)
	await _press_key(strip, 2, true)
	depth = _builder.history_depth()
	await _drag_key(strip, 1, 0.5)
	motion = _player.motions().named("Open the doors")
	var times: Array = motion.camera.keys.map(func(key: Array) -> float: return float(key[0]))
	_check("two picked keys, one dragged half a second on: both moved, one step (%s, %d)" % [times,
		_builder.history_depth() - depth], times.size() == 3 and is_equal_approx(times[1], 1.5)
		and is_equal_approx(times[2], 3.0) and _builder.history_depth() == depth + 1)
	_shell.run("undo")
	await _frames(8)
	_check("...undone, back as they were", _motion_lines(_store.to_text("Doors")) == before)
	# Delete where it is not a key's: typed in the name, and after a press in the view.
	_panel.edit("Open the doors")
	await _frames(10)
	strip = _panel.controls_by_name()["motions_camera_keys"]
	await _seen(strip)
	await _press_key(strip, 1, false)
	var name_field: LineEdit = _panel.get("_name")
	name_field.grab_focus()
	await _frames(2)
	await _key(KEY_DELETE)
	_check("Delete typed in the name field takes no key out", _motion_lines(_store.to_text("Doors")) == before)
	await _press_key(strip, 1, false)
	var outside := Vector2(_panel.get_global_rect().position.x - 120.0, root.get_visible_rect().size.y * 0.5)
	await _move(outside, 0)
	await _button(outside, true)
	await _button(outside, false)
	await _key(KEY_DELETE)
	_check("Delete after a press in the view takes no key out", _motion_lines(_store.to_text("Doors")) == before)
	_panel.back_to_list()
	await _frames(4)


# -- 7. the person's Claude -------------------------------------------------------------------


func _mcp() -> void:
	print("\n7. the person's Claude: a turntable filmed in one call")
	var listed: Dictionary = await _rpc("tools/list", {})
	var has: bool = false
	for tool: Dictionary in listed.get("tools", []):
		if str(tool.get("name", "")) == "render_motion":
			has = (tool.get("inputSchema", {}) as Dictionary).get("properties", {}).has("camera")
	_check("render_motion takes camera=", has)
	if not _windowed:
		print("  (headless: not rendered)")
		return
	var depth: int = _builder.history_depth()
	_panel._ready_renderer()
	_shots.clear()
	_panel.renderer.frame_shot.connect(_on_shot)
	var said: String = _text(await _finished(await _rpc("tools/call", {"name": "render_motion",
		"arguments": {"name": "Turntable", "camera": {"turntable": true}, "fps": 12, "size": "480x300"}})))
	_print(said)
	_panel.renderer.frame_shot.disconnect(_on_shot)
	var motion: Motions.Motion = _player.motions().named("Turntable")
	_check("one call: the motion made, its camera two keys, one undo step", said.begins_with("Made \"Turntable\"")
		and motion != null and motion.camera != null and motion.camera.keys.size() == 2
		and _builder.history_depth() == depth + 1)
	if motion != null and motion.camera != null:
		_round(said, motion.camera.keys, "the session's turntable")


# -- 8. time ---------------------------------------------------------------------------------------


func _time() -> void:
	print("\n8. time on Orthanc")
	if not FileAccess.file_exists(ProjectSettings.globalize_path(ORTHANC)) or not await _open(ORTHANC):
		_check("Orthanc opens", false)
		return
	var said: String = await _say("define_motion", {"name": "Fly round", "camera": {"turntable": true, "seconds": 8}})
	_print(said.left(200))
	var motion: Motions.Motion = _player.motions().named("Fly round")
	if motion == null or motion.camera == null:
		_check("a turntable kept on Orthanc", false)
		return
	var lift: Vector3 = _store.lift()
	var views: Array = []
	var times: Array = []
	for n: int in 97:
		times.append(8.0 * float(n) / 96.0)
	for view: Array in motion.camera.views_at(times):
		views.append(MotionPlayer.camera_view(view, lift))
	var rounds: Array = []
	for round_n: int in 3:
		# The view turned by hand the same way, a step each frame.
		var hand: Array = []
		for n: int in views.size():
			var view: Array = views[n]
			var focus: Vector3 = view[0]
			_eye.call("aim_at", {"yaw": view[1], "pitch": view[2], "distance": view[3],
				"focus": [focus.x, focus.y, focus.z]})
			await process_frame
			hand.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		# The camera track playing.
		var keyed: Array = []
		if not _panel.visible:
			_shell.run("pose")
		await _frames(4)
		_panel.play("Fly round")
		for n: int in 4000:
			await process_frame
			if not _panel.is_playing():
				break
			keyed.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		await _frames(10)
		rounds.append([_median(hand), _median(keyed), keyed.size()])
	var report := PackedStringArray()
	var adds: Array = []
	for one: Array in rounds:
		report.append("by hand %.3f ms, keyed %.3f ms over %d frames" % [one[0], one[1], one[2]])
		adds.append(float(one[1]) - float(one[0]))
	adds.sort()
	_check("a camera track playing on Orthanc adds %.3f ms a frame of the app's own work, the median of 3 rounds (%s)"
		% [adds[1], "; ".join(report)], float(adds[1]) <= 1.0)


static func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])


# -- helpers --------------------------------------------------------------------------------------


func _open(path: String) -> bool:
	var real: String = ProjectSettings.globalize_path(path)
	if _panel.visible:
		_panel.back_to_list()
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", real)
	for _n: int in 900:
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


func _fits(state: String) -> void:
	var rect: Rect2 = _panel.get_global_rect()
	var view: Rect2 = root.get_visible_rect()
	_check("%s: the panel fits the window (%s in %s)" % [state, str(rect.size.round()), str(view.size)],
		view.encloses(rect))


## [param control] scrolled into the panel's sight.
func _seen(control: Control) -> void:
	var node: Node = control.get_parent()
	while node != null and not node is ScrollContainer:
		node = node.get_parent()
	if node != null:
		(node as ScrollContainer).ensure_control_visible(control)
	await _frames(3)


## Key [param index] of [param strip] pressed, with Ctrl held for [param adding].
func _press_key(strip: PosePanel.KeyStrip, index: int, adding: bool) -> void:
	await _frames(2)
	var at: Vector2 = strip.get_global_rect().position + Vector2(strip._x_of(float(strip.times[index])), strip.size.y * 0.5)
	await _move(at, 0)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.ctrl_pressed = adding
		event.position = _as_event(at)
		event.global_position = event.position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)


## Key [param index] of [param strip] dragged [param by] seconds on.
func _drag_key(strip: PosePanel.KeyStrip, index: int, by: float) -> void:
	var t: float = float(strip.times[index])
	var origin: Vector2 = strip.get_global_rect().position + Vector2(0.0, strip.size.y * 0.5)
	var from: Vector2 = origin + Vector2(strip._x_of(t), 0.0)
	var to: Vector2 = origin + Vector2(strip._x_of(t + by), 0.0)
	await _move(from, 0)
	await _button(from, true)
	for n: int in 6:
		await _move(from.lerp(to, float(n + 1) / 6.0), MOUSE_BUTTON_MASK_LEFT)
	await _button(to, false)
	await _frames(6)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)


func _wheel(at: Vector2, notches: int) -> void:
	await _move(at, 0)
	for _n: int in notches:
		for down: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_WHEEL_UP
			event.pressed = down
			event.factor = 1.0
			event.position = _as_event(at)
			event.global_position = event.position
			Input.parse_input_event(event)
		await process_frame


static func _camera_lines(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with(Motions.META + "_CAMERA "):
			out.append(line.strip_edges())
	return out


static func _motion_lines(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with(Motions.META):
			out.append(line.strip_edges())
	return out


func _poses() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


func _off(built: Dictionary, slack: float) -> Array:
	var count: int = 0
	var most: float = 0.0
	for brick: BrickWorld.Brick in _world.bricks():
		var was: Variant = built.get(brick.id)
		if was == null:
			count += 1
			continue
		var off: float = brick.transform.origin.distance_to((was as Transform3D).origin)
		most = maxf(most, off)
		if off > slack + 0.0001:
			count += 1
	return [count, most]


static func _frames_dir(name: String, folder: String) -> String:
	return folder.path_join(name).get_basename()


static func _frame(dir: String, n: int) -> Image:
	var path: String = dir.path_join("frame_%04d.png" % n)
	return Image.load_from_file(path) if FileAccess.file_exists(path) else null


func _keep_frames(dir: String, name: String, frames: int) -> void:
	for n: int in [1, (frames - 1) / 2 + 1, frames]:
		var image: Image = _frame(dir, n)
		if image != null:
			image.save_png(_out.path_join("%s_%s_frame_%04d.png" % [_size, name, n]))


## How far apart two pictures are, on average, as a share of a pixel's range.
static func _difference(one: Image, other: Image) -> float:
	if one == null or other == null or one.get_size() != other.get_size():
		return 1.0
	var sum: float = 0.0
	var count: int = 0
	for y: int in range(0, one.get_height(), 2):
		for x: int in range(0, one.get_width(), 2):
			var a: Color = one.get_pixel(x, y)
			var b: Color = other.get_pixel(x, y)
			sum += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			count += 1
	return sum / float(maxi(count, 1))


static func _drawn_middle(image: Image) -> Vector2:
	if image == null:
		return Vector2.ZERO
	var backdrop: Color = image.get_pixel(0, 0)
	var sum := Vector2.ZERO
	var count: int = 0
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			var c: Color = image.get_pixel(x, y)
			if absf(c.r - backdrop.r) + absf(c.g - backdrop.g) + absf(c.b - backdrop.b) > 0.3:
				sum += Vector2(x, y)
				count += 1
	return sum / float(count) if count > 0 else Vector2(image.get_size()) * 10.0


func _write(path: String, text: String) -> void:
	var access := FileAccess.open(path, FileAccess.WRITE)
	access.store_string(text)
	access.close()


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


func _finished(result: Dictionary) -> Dictionary:
	var found: RegExMatch = RegEx.create_from_string("Started job (\\d+)").search(_text(result))
	if found == null:
		return result
	for _n: int in 600:
		var polled: Dictionary = await _rpc("tools/call", {"name": "job", "arguments":
			{"id": int(found.get_string(1))}})
		if not _text(polled).contains(" is still going"):
			return polled
	return {"content": [{"type": "text", "text": "the job never ended"}]}


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		return
	var path: String = _out.path_join("%s_%s.png" % [_size, name])
	image.save_png(path)
	print("    picture: %s" % path)


func _click(control: Control) -> void:
	await _frames(2)
	if control == null or not control.is_visible_in_tree():
		_check("the control to press shows (%s)" % (control.name if control != null else "none"), false)
		return
	var at: Vector2 = control.get_global_rect().get_center()
	await _move(at, 0)
	await _button(at, true)
	await _button(at, false)
	await _frames(3)


func _move(at: Vector2, mask: int) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = _as_event(at) - _as_event(_last_screen)
	move.button_mask = mask
	Input.parse_input_event(move)
	_last_screen = at
	await process_frame


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)
	await _frames(2)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or rect.x <= 0.0:
		return at
	return at * (window / rect)


func _print(said: String) -> void:
	print("    " + said.replace("\n", "\n    "))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
