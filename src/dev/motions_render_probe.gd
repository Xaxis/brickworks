## File, Render's Animation on real sets (docs/MOTIONS.md, unit 4), pressed
## as a person presses it: the motion chosen, the camera, Render animation.
##
##   godot --path . --resolution 1400x900 --script src/dev/motions_render_probe.gd
##   ... -- OUT_DIR [pictures]   (bench/results/motions4-2026-10-20 when not given;
##                                pictures: only the dialog's pictures, for PROBE_SIZE=1280x720)
##
##  1. 1484-1's doors: "Open the doors" kept, and "Close the first gate"
##     after it. Rendered as I see it and framed on what moves: every frame
##     the motion has, the frames differ where the doors move, framed on
##     what moves the doors fill more of the frame, the files named after
##     the model and the motion and numbered the second time. All, in order:
##     both motions' frames, the gate closing at the end. Cancel part way:
##     nothing kept, the model as it was.
##  2. 4096-1's crane: "Lift the boom" framed on what moves fills the
##     frame, against the whole model's box (unit 1's framing).
##  3. One path: the same frames from the dialog and the Motions panel's
##     Render animation (as I see it), and from the dialog and render_motion
##     over MCP (framed on what moves), for the same settings: the same
##     camera and every moving part in the same place, exactly, and pixels
##     as alike as the dialog drawing them twice. The model stands as built
##     after each, and redo is kept.
## Pictures of the dialog with Animation chosen, named by the window's size.
extends SceneTree

const DOORS := "res://vendor/omr/files/1484-1.mpd"
const CRANE := "res://vendor/omr/files/4096-1_Crane.mpd"

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _player: MotionPlayer
var _dialog: RenderDialog
var _panel: PosePanel
var _out: String = ""
var _next: int = 0
var _last_screen := Vector2.ZERO


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else "/mnt/Projects/brickworks/bench/results/motions4-2026-10-20"
	var pictures_only: bool = args.size() > 1 and args[1] == "pictures"
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
	_store = _main.get("_store")
	_player = _main.get("_motions")
	_dialog = _main.get("_render")
	_panel = _main.get("_pose")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	if not StudioRender.possible():
		print("motions render probe: needs a window (tools/probe.sh runs it in one)")
		quit(3)
		return
	# Each run's files in a folder of its own, new: the names are numbered
	# against what is there. Never the last run's folder trashed:
	# OS.move_to_trash runs gio, which no probe may call (tools/probe.sh), so
	# the last run's files stayed and the names came out numbered 11
	# (rel-m228, 2026-10-31).
	var files: String = OS.get_user_data_dir().path_join("motions_render_files_%d_%d"
		% [int(Time.get_unix_time_from_system()), OS.get_process_id()])
	DirAccess.make_dir_recursive_absolute(files)
	Download.folder = files
	_dialog.folder = files
	_panel.folder = files
	if pictures_only:
		await _pictures()
	else:
		await _doors()
		await _crane()
	print("")
	if _failures == 0 and pictures_only:
		print("motions render: the dialog with Animation chosen, every control inside it")
	elif _failures == 0:
		print("motions render: File, Render's Animation drew 1484-1's doors and 4096-1's boom as seen "
			+ "and framed on what moves, named and numbered, cancelled, the same frames as the panel and "
			+ "render_motion")
	else:
		print("motions render: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- 1484-1 -----------------------------------------------------------------------------


func _doors() -> void:
	print("── 1484-1: open the doors, then close the first gate ──")
	if not await _two_motions():
		return
	var built: Dictionary = _poses()
	var model: String = str(_dialog.named.call())
	await _open_dialog()
	_check("the dialog offers both motions and All, in order (%s)" % str(_offered()),
		_offered() == ["Open the doors", "Close the first gate", MotionRender.ALL])
	await _click(_dialog.controls_by_name()["render_quick"])
	await _click(_dialog.controls_by_name()["render_size_720p"])
	await _shot("dialog_animation")
	var length: float = _player.motions().named("Open the doors").length()
	var frames: int = maxi(roundi(length * 24.0), 1) + 1
	var seen: Dictionary = await _render("Open the doors", "render_camera_seen")
	_check("as I see it: %d frames of %d, %s" % [seen["frames"], frames, seen["status"]],
		seen["frames"] == frames and str(seen["name"]) == "%s Open the doors.webp" % model)
	var moved: Dictionary = await _render("Open the doors", "render_camera_moves")
	_check("framed on what moves: %d frames, numbered %s" % [moved["frames"], moved["name"]],
		moved["frames"] == frames and str(moved["name"]) == "%s Open the doors 2.webp" % model)
	for one: Dictionary in [seen, moved]:
		_check("...%s: a WebP of %d frames, an MP4, %d PNGs" % [one["name"], one["webp_frames"],
			one["pngs"], ], one["webp_frames"] == frames and one["pngs"] == frames
			and (one["mp4"] or RenderOutput.ffmpeg().is_empty()))
		_check("...its frames differ where the doors move: %d pixels from first to last, over %s of the frame"
			% [one["changed"], _percent(one["changed_box"])], one["changed"] > 500)
	_check("framed on what moves, the doors' sweep fills more of the frame (%s against %s as seen)"
		% [_percent(moved["changed_box"]), _percent(seen["changed_box"])],
		_area(moved["changed_box"]) > _area(seen["changed_box"]) * 1.3)
	_check("...and the model stands as built (%d parts off)" % _off(built), _off(built) == 0)
	# Every motion in order: the gate opens with the others, then closes.
	var close: float = _player.motions().named("Close the first gate").length()
	var all_frames: int = frames + maxi(roundi(close * 24.0), 1) + 1
	var all: Dictionary = await _render(MotionRender.ALL, "render_camera_moves")
	_check("All, in order: %d frames of %d, %s" % [all["frames"], all_frames, all["name"]],
		all["frames"] == all_frames and str(all["name"]) == "%s all in order.webp" % model)
	var last: Image = _frame(all["dir"], all_frames)
	var opened: Image = _frame(all["dir"], frames)
	_check("...the gate closes in its last frames: %d pixels differ from where the doors stood open"
		% _changed(opened, last), _changed(opened, last) > 200)
	_check("...and the model stands as built (%d parts off), redo as it was (%d)" % [_off(built),
		_builder.steps_now()[1].size()], _off(built) == 0 and _builder.steps_now()[1].size() == 1)
	# Cancel a few frames in, as a person does.
	var webps: int = _count(".webp")
	_select("Open the doors")
	await _click(_dialog.controls_by_name()["render_animation"])
	for _n: int in 600:
		await process_frame
		if _dialog._working == "animation" and _dialog._progress.value > 0.3:
			break
	var was: String = _dialog._working
	await _click(_dialog.controls_by_name()["render_cancel"])
	for _n: int in 600:
		if not _dialog.is_rendering():
			break
		await process_frame
	_check("Cancel stops it part way (was %s at %d%%): \"%s\", no WebP kept (%d, %d before)" % [was,
		roundi(_dialog._progress.value * 100.0), _dialog._status.text, _count(".webp"), webps],
		was == "animation" and not _dialog.is_rendering() and _dialog._status.text == "Cancelled."
		and _count(".webp") == webps)
	_check("...and the model stands as built (%d parts off)" % _off(built), _off(built) == 0)
	# One path: the panel's Render animation and the dialog's, as I see it.
	_dialog.close()
	await _frames(5)
	var same: RenderSettings = _panel.settings.copy()
	same.fps = 12
	await _select_camera("render_camera_seen")
	_select("Open the doors")
	var from_dialog: String = await _render_for(same)
	var again: Array = _compare(from_dialog, await _render_for(same))
	_panel._chosen = "Open the doors"
	await _panel.render_animation()
	var from_panel: String = _folder_of(str(_panel._last.get("name", "")))
	_same_frames("the dialog and the Motions panel's Render animation", "Open the doors",
		_compare(from_dialog, from_panel), again)
	_check("...and the model stands as built (%d parts off)" % _off(built), _off(built) == 0)


## 1484-1 with its doors' motion kept and a second after it: true when both are.
func _two_motions() -> bool:
	if not await _open(DOORS):
		return false
	var said: String = await _say("define_motion", {"name": "Open the doors", "suggested": true})
	_print(said)
	var motion: Motions.Motion = _player.motions().named("Open the doors")
	if motion == null or motion.tracks.is_empty():
		_check("define_motion keeps the doors' suggestion", false)
		return false
	var track: Motions.Track = motion.tracks[0]
	var open_at: float = float(track.keys.back()[1])
	said = await _say("define_motion", {"name": "Close the first gate", "after": "Open the doors",
		"tracks": [{"joint": "#%d" % track.joint.lead, "keys": [{"t": 0, "place": open_at},
			{"t": 1.5, "place": 0}]}]})
	_print(said)
	_check("two motions, the second after the first", said.begins_with("Kept \"Close the first gate\""))
	# Something to redo, which a render must leave alone.
	var depth: int = _builder.history_depth()
	await _say("define_motion", {"name": "Spare", "suggested": false, "tracks": [{"joint":
		"#%d" % track.joint.lead, "keys": [{"t": 0, "place": 0}, {"t": 1, "place": open_at * 0.5}]}]})
	await _say("undo", {})
	return _builder.history_depth() == depth and _builder.steps_now()[1].size() == 1


# -- 4096-1 -----------------------------------------------------------------------------


func _crane() -> void:
	print("── 4096-1: lift the crane's boom ──")
	if not await _open(CRANE):
		return
	var built: Dictionary = _poses()
	var said: String = await _say("define_motion", {"name": "Lift the boom", "suggested": true})
	_print(said)
	_check("define_motion keeps lifting the boom", said.begins_with("Kept \"Lift the boom\""))
	await _open_dialog()
	await _click(_dialog.controls_by_name()["render_quick"])
	await _click(_dialog.controls_by_name()["render_size_720p"])
	var moved: Dictionary = await _render("Lift the boom", "render_camera_moves")
	var length: float = _player.motions().named("Lift the boom").length()
	var frames: int = maxi(roundi(length * 24.0), 1) + 1
	_check("framed on what moves: %d frames of %d, %s" % [moved["frames"], frames, moved["name"]],
		moved["frames"] == frames and moved["webp_frames"] == frames)
	var spread: Vector2 = _spread(_frame(moved["dir"], frames))
	_check("...the boom fills the frame: its sweep over %s, the crane across %d%% and up %d%% at the top"
		% [_percent(moved["changed_box"]), roundi(spread.x * 100.0), roundi(spread.y * 100.0)],
		maxf(moved["changed_box"].x, moved["changed_box"].y) > 0.6)
	_sheet(moved["dir"], frames, "crane_framed_on_what_moves.png")
	# The whole model's box and the sweep's, from the same side, as unit 1 framed it.
	_dialog.close()
	await _frames(5)
	var drawn: MotionRender = MotionRender.frames_of(_player, [_player.motions().named("Lift the boom")], false, 24)
	await _panel.render_poses(drawn.poses, 24, func(_n: int) -> float: return 0.0, [], null, "hero",
		"Lift the boom as unit 1 framed it", false)
	var box: Vector2 = _changed_box(_frame(_folder_of(str(_panel._last.get("name", ""))), 1),
		_frame(_folder_of(str(_panel._last.get("name", ""))), frames))
	_check("...against the whole model's box from three-quarters: over %s" % _percent(box),
		_area(moved["changed_box"]) > _area(box) * 1.5)
	# One path: render_motion over MCP and the dialog, framed on what moves.
	var answer: Dictionary = await _finished(await _rpc("tools/call", {"name": "render_motion",
		"arguments": {"name": "Lift the boom"}}))
	_print(_text(answer))
	var from_mcp: String = _folder_of(str(_panel._last.get("name", "")))
	var same: RenderSettings = _panel.settings.copy()
	same.fps = 12
	same.view = "hero"
	await _select_camera("render_camera_moves")
	_select("Lift the boom")
	var from_dialog: String = await _render_for(same)
	var again: Array = _compare(from_dialog, await _render_for(same))
	_same_frames("render_motion and the dialog", "Lift the boom", _compare(from_dialog, from_mcp), again)
	_check("...and the model stands as built (%d parts off)" % _off(built), _off(built) == 0)


# -- pictures -----------------------------------------------------------------------------


func _pictures() -> void:
	print("── the dialog with Animation chosen ──")
	if not await _two_motions():
		return
	await _open_dialog()
	await _shot("dialog_animation")


## Render opened from the File menu, with the Animation section scrolled
## into view and its first motion chosen, and the layout checked: every
## Animation control inside the dialog.
func _open_dialog() -> void:
	(_main.get("_shell") as Shell).run("render")
	await _frames(20)
	_check("File, Render opens the dialog", _dialog.visible)
	var named: Dictionary = _dialog.controls_by_name()
	var scroll: ScrollContainer = (named["render_motion"] as Control).get_parent().get_parent()
	scroll.ensure_control_visible(named["render_camera_moves"])
	await _frames(6)
	var inside: Rect2 = _dialog.get_global_rect()
	var out := PackedStringArray()
	for key: String in ["render_motion", "render_camera_seen", "render_camera_moves", "render_animation",
			"render_turntable", "render_picture"]:
		var control: Control = named[key]
		if not control.is_visible_in_tree() or not inside.encloses(control.get_global_rect()):
			out.append(key)
	var size: Vector2i = DisplayServer.window_get_size()
	_check("at %dx%d every Animation control shows inside the dialog%s" % [size.x, size.y,
		"" if out.is_empty() else " (not: %s)" % ", ".join(out)], out.is_empty())


func _shot(name: String) -> void:
	await _frames(30)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = _out.path_join("%s_%dx%d.png" % [name, size.x, size.y])
	image.save_png(path)
	print("    picture: %s" % path)


# -- rendering ----------------------------------------------------------------------------


func _offered() -> Array:
	var names: Array = []
	var motion: OptionButton = _dialog.controls_by_name()["render_motion"]
	for n: int in motion.item_count:
		names.append(str(motion.get_item_metadata(n)))
	return names


## The motion chosen in the dialog's list, as a pick from it does.
func _select(name: String) -> void:
	var motion: OptionButton = _dialog.controls_by_name()["render_motion"]
	for n: int in motion.item_count:
		if str(motion.get_item_metadata(n)) == name:
			motion.select(n)
			motion.item_selected.emit(n)


func _select_camera(key: String) -> void:
	var was: bool = _dialog.visible
	if not was:
		await _open_dialog()
	await _click(_dialog.controls_by_name()[key])
	if not was:
		_dialog.close()
		await _frames(5)


## [param name] chosen, [param camera] pressed and Render animation pressed,
## as a person does; what came of it once it is done.
func _render(name: String, camera: String) -> Dictionary:
	_select(name)
	await _click(_dialog.controls_by_name()[camera])
	await _click(_dialog.controls_by_name()["render_animation"])
	for _n: int in 20000:
		await process_frame
		if not _dialog.is_rendering():
			break
	await _frames(5)
	return _found(str(_dialog._last.get("name", "")), _dialog._status.text, int(_dialog._last.get("frames", 0)))


## The dialog's Animation drawn with [param chosen] (as render_model draws
## a picture): the folder its frames went to.
func _render_for(chosen: RenderSettings) -> String:
	var said: String = await _dialog.render_for("animation", chosen)
	print("    dialog: %s" % said)
	return _folder_of(str(_dialog._last.get("name", "")))


func _found(name: String, status: String, frames: int) -> Dictionary:
	var webp: String = _dialog.folder.path_join(name)
	var dir: String = webp.get_basename()
	var pngs: int = 0
	for file: String in DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else []:
		if file.begins_with("frame_") and file.ends_with(".png"):
			pngs += 1
	var first: Image = _frame(dir, 1)
	var last: Image = _frame(dir, pngs)
	print("    %s" % status)
	return {"name": name, "status": status, "frames": frames, "dir": dir, "pngs": pngs,
		"webp_frames": _webp_frames(webp), "mp4": FileAccess.file_exists(dir + ".mp4"),
		"changed": _changed(first, last), "changed_box": _changed_box(first, last)}


func _folder_of(name: String) -> String:
	return _dialog.folder.path_join(name).get_basename()


func _frame(dir: String, n: int) -> Image:
	var path: String = dir.path_join("frame_%04d.png" % n)
	return Image.load_from_file(path) if FileAccess.file_exists(path) else null


## The dialog's renderer and the panel's drew the same frames: the same
## camera and the same places for every part that moves (exactly), and
## pixels as alike as the dialog's own drawn twice.
func _same_frames(who: String, motion: String, compared: Array, again: Array) -> void:
	var a: StudioRender.Shot = _dialog.renderer.last_shot
	var b: StudioRender.Shot = _panel.renderer.last_shot
	var camera: bool = a != null and b != null and a.origin.is_equal_approx(b.origin) \
		and a.basis.is_equal_approx(b.basis) and is_equal_approx(a.fov, b.fov)
	var drawn: MotionRender = MotionRender.frames_of(_player, [_player.motions().named(motion)], false, 12)
	var placed: int = 0
	for id: Variant in drawn.poses.back():
		if _dialog.renderer.staged_transform(int(id)).is_equal_approx(_panel.renderer.staged_transform(int(id))) \
				and _dialog.renderer.staged_transform(int(id)).is_equal_approx(drawn.poses.back()[id]):
			placed += 1
	var moving: int = (drawn.poses.back() as Dictionary).size()
	_check("%s draw the same %d frames of %s: the same camera (%s), the %d moving parts where the motion puts them (%d)"
		% [who, compared[0], Motions.quoted(motion), camera, moving, placed],
		compared[0] == drawn.poses.size() and camera and placed == moving)
	# StudioRender does not draw a frame twice bit for bit: the dialog drawing
	# the same frames again, back to back, differs in thousands of pixels by
	# a few levels. Across the paths they differ no more than that. How much
	# the dialog differs from itself moves from run to run (by 1, then by 11,
	# 384 pixels, then 7,927), so it is a floor, not the bar: the paths
	# differed by 8 where the dialog twice differed by 1 (m119, 2026-10-20),
	# and a part out of place differs by a hundred levels or more.
	_check("...and the pixels as alike as the dialog's own drawn twice: %d differ, by %d of 255 at most (the dialog twice: %d, by %d)"
		% [compared[1], compared[2], again[1], again[2]],
		int(compared[2]) <= maxi(int(again[2]) + 4, 16)
			and int(compared[1]) <= maxi(int(again[1]) * 2, compared[0] * 480))


## [frames compared, pixels that differ, the most a channel differs (of 255)].
func _compare(a: String, b: String) -> Array:
	var compared: int = 0
	var differ: int = 0
	var most: int = 0
	for n: int in range(1, 1000):
		var one: Image = _frame(a, n)
		var other: Image = _frame(b, n)
		if one == null or other == null:
			if (one == null) != (other == null):
				differ += 1
			break
		compared += 1
		if one.get_size() != other.get_size():
			differ += one.get_width() * one.get_height()
			continue
		one.convert(Image.FORMAT_RGBA8)
		other.convert(Image.FORMAT_RGBA8)
		var x: PackedByteArray = one.get_data()
		var y: PackedByteArray = other.get_data()
		for i: int in range(0, x.size(), 4):
			var gap: int = maxi(maxi(absi(x[i] - y[i]), absi(x[i + 1] - y[i + 1])), absi(x[i + 2] - y[i + 2]))
			if gap > 0:
				differ += 1
				most = maxi(most, gap)
	return [compared, differ, most]


func _sheet(dir: String, frames: int, name: String) -> void:
	var images: Array = []
	for n: int in [1, frames / 3, frames * 2 / 3, frames]:
		var image: Image = _frame(dir, maxi(n, 1))
		if image != null:
			images.append(image)
	var sheet: Image = PosePanel.sheet_of(images)
	if sheet != null:
		sheet.save_png(_out.path_join(name))
		print("    picture: %s" % _out.path_join(name))


func _count(extension: String) -> int:
	var count: int = 0
	for file: String in DirAccess.get_files_at(_dialog.folder):
		if file.ends_with(extension):
			count += 1
	return count


# -- measuring ------------------------------------------------------------------------------


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


## How much of the frame the pixels that change span, across and up, 0 to 1.
func _changed_box(a: Image, b: Image) -> Vector2:
	if a == null or b == null or a.get_size() != b.get_size():
		return Vector2.ZERO
	var low := Vector2i(a.get_width(), a.get_height())
	var high := Vector2i(-1, -1)
	for y: int in a.get_height():
		for x: int in a.get_width():
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.1:
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	if high.x < 0:
		return Vector2.ZERO
	return Vector2(float(high.x - low.x + 1) / a.get_width(), float(high.y - low.y + 1) / a.get_height())


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


static func _area(box: Vector2) -> float:
	return box.x * box.y


static func _percent(box: Vector2) -> String:
	return "%d%% across and %d%% up" % [roundi(box.x * 100.0), roundi(box.y * 100.0)]


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


func _poses() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


## How many parts stand more than a twentieth of an LDU or a tenth of a
## degree from where [param built] has them.
func _off(built: Dictionary) -> int:
	var count: int = 0
	for key: Variant in built:
		var brick: BrickWorld.Brick = _world.get_brick(int(key))
		if brick == null:
			count += 1
			continue
		var was: Transform3D = built[key]
		var a: Basis = was.basis.orthonormalized()
		var b: Basis = brick.transform.basis.orthonormalized()
		var chord: float = maxf(a.x.distance_to(b.x), maxf(a.y.distance_to(b.y), a.z.distance_to(b.z)))
		if was.origin.distance_to(brick.transform.origin) > 0.05 or rad_to_deg(2.0 * asin(clampf(chord * 0.5, 0.0, 1.0))) > 0.1:
			count += 1
	return count


# -- the app ------------------------------------------------------------------------------


func _open(path: String) -> bool:
	var real: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(real):
		print("    (no %s: tools/omr.py fetch brings the sets)" % path)
		_failures += 1
		return false
	if _dialog.visible:
		_dialog.close()
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", real)
	for _n: int in 600:
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


func _click(control: Control) -> void:
	await _frames(2)
	if control == null or not control.is_visible_in_tree():
		_check("the control to press shows (%s)" % (control.name if control != null else "none"), false)
		return
	await _click_at(control.get_global_rect().get_center())


func _click_at(at: Vector2) -> void:
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


func _print(said: String) -> void:
	print("    " + said.replace("\n", "\n    "))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
