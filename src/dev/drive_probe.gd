## A model driven along a path, its wheels turning as it goes (docs/APP_UX6.md,
## unit 12 drive).
##
##   godot --path . --resolution 1400x900 --script src/dev/drive_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh drive_probe      the smaller window
##   ... -- OUT_DIR   (where the files go; shots/drive when not given)
##   DRIVE_ONLY=review ...   section 9 alone
##
## Kinebrick Studio's car drives; Brickworks' motions turned and slid joints
## only. Here 8808-1, the F1 racer (vendor/omr/files): two front wheels on
## stub axles its steering turns, and a back axle of four.
##
##  1. The Motions panel suggests "Drive and turn left" from its wheels, and
##     Keep keeps it; Play drives it in the view and Play backwards brings it
##     back; its editor shows the path's two legs, and the corner made right
##     there writes RIGHT in the file, undone.
##  2. Over MCP, define_motion with path= a 32-stud straight and a quarter
##     turn left keeps it: one step, the model put back.
##  3. Played, nothing kept, read from its frames alone (the probe's own
##     measures, not the player's): the middle of the back axle goes 32
##     studs straight on, then round a quarter circle of the radius the file
##     says, ending turned 90° left where that circle ends, within 0.1 stud
##     and 0.5°; no part left behind.
##  4. Each axle (its tyres, found from how they move together) turns once
##     for every round of its tyre its middle travels, within 2%, the tyre's
##     radius read from its mesh; and the way that rolls it: its bottom
##     still on the ground.
##  5. The file: the path's, wheels' and steering's lines out, opened again
##     and written byte for byte the same; played again from the file, the
##     same drive.
##  6. play_motion keeps it, one undo step, the model where the path ends;
##     backwards brings every part back; undo too.
##  7. Rendered: render_motion's WebP and its frames, the racer in another
##     place in the last frame than in the first.
##  8. A link that opens it playing (?motion=drive-and-turn-left): the viewer draws the
##     racer driving off and its tyres turning, all of it in the window and
##     on its floor all the way.
##  9. Someone else's file, as its review tried it (drivereview F1-F9): the
##     racer (CRLF, a sub-model placed twice, one mirrored) driven and kept,
##     saved: only its main model's placing lines and the motion lines
##     differ, no noise, CRLF kept; opened again, every joint of the drive
##     finds its part, and so after a move by hand and after a wheel taken
##     off and put back by undo; refused and out-of-order lines said, kept
##     verbatim and read alike; a leg or seconds that rounds to nothing, and
##     values of the wrong kind, refused in words; the panel's seconds the
##     motion's length; a contact of no studs said, not divided by.
##
## It loads on a build from before (what is new is asked for by name), so
## that build fails its checks rather than failing to load. Pictures in
## shots/drive/ (or OUT_DIR), named by the window's size.
extends SceneTree

const RACER := "res://vendor/omr/files/8808-1.mpd"
const NAME := "Drive and turn left"
const LINK_ID := "Dr1veL1nk01"
const STUD := 20.0
## How near the path its back axle's middle keeps, LDU (0.1 stud), and its
## heading, degrees; how near the wheels' turns, a share.
const ON_THE_PATH := 2.0
const HEADING_DEG := 0.5
const WHEEL_SHARE := 0.02

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _player: MotionPlayer
var _library: PartLibrary
var _out: String = ""
var _next: int = 0
var _size: String = ""
var _windowed: bool = false
## The racer's text with the drive in it, for the link.
var _shared_text: String = ""


class FakeShared extends SharedModels:
	var answer: Dictionary = {}

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func built(_id: String, _device: String, _version: int = 1) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "can_write": false, "why_not": "signed out"}}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://shots/drive")
	DirAccess.make_dir_recursive_absolute(_out)
	if not FileAccess.file_exists(ProjectSettings.globalize_path(RACER)):
		print("drive_probe: SKIPPED, no %s (tools/omr.py fetch brings the sets)" % RACER)
		quit(3)
		return
	await _start()
	_windowed = StudioRender.possible()
	if not _windowed:
		print("drive probe: drawn headless, so nothing is rendered (xvfb-run draws it)")
	Download.folder = _out
	(_main.get("_pose") as PosePanel).folder = _out
	# DRIVE_ONLY=review: section 9 alone, as a build from before is tried.
	var only_review: bool = OS.get_environment("DRIVE_ONLY") == "review"
	if not only_review and await _open(RACER):
		await _panel()
		var motion: Motions.Motion = await _defined()
		if motion != null:
			var shape: Dictionary = await _played(motion)
			await _file(motion, shape)
			await _kept(shape)
			await _rendered()
	_main.queue_free()
	for _n: int in 10:
		await process_frame
	if not _shared_text.is_empty():
		await _link()
	# Last, in a window of its own: it opens other files.
	await _start()
	await _review()
	print("")
	print("drive_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	if _main != null and is_instance_valid(_main):
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
	_library = _main.get("_library")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame


# -- 1. the panel -------------------------------------------------------------------------


func _panel() -> void:
	print("\n1. the Motions panel (%s)" % _size)
	var panel: PosePanel = _main.get("_pose")
	var shell: Shell = _main.get("_shell")
	var built: Dictionary = _poses()
	var depth: int = _builder.history_depth()
	shell.run("pose")
	await _frames(10)
	var offered: Array = panel._offered().map(func(one: Motions.Motion) -> String: return one.name)
	_check("it suggests “%s” from the racer's wheels (%s)" % [NAME, offered], offered.has(NAME))
	await _shot("1_suggested")
	if not offered.has(NAME):
		shell.run("pose")
		return
	await _click(panel._keep_buttons[offered.find(NAME)])
	var motion: Motions.Motion = _player.motions().named(NAME)
	_check("Keep keeps it, one step", motion != null and _builder.history_depth() == depth + 1)
	if motion == null:
		return
	var row: int = _player.motions().list.find(motion)
	# Play drives it, drawn a frame at a time, and leaves it where the path
	# ends, one step; Play backwards drives it back, another.
	var eye: Camera3D = _main.get("_camera")
	for way: String in ["play", "back"]:
		await _click(panel._row_buttons[row][way])
		var far: float = 0.0
		var shot: bool = false
		var seen: int = 0
		var unseen: int = 0
		for _n: int in 1200:
			await process_frame
			far = maxf(far, _drawn_far(built))
			# Its middle as drawn, in the window or not.
			var drawn: Dictionary = _world.drawn_ids()
			if not drawn.is_empty() and eye != null:
				var middle := Vector3.ZERO
				for key: Variant in drawn:
					middle += (drawn[key] as Transform3D).origin / float(drawn.size())
				if not eye.is_position_behind(middle) and root.get_visible_rect().has_point(eye.unproject_position(middle)):
					seen += 1
				else:
					unseen += 1
			if not shot and far > 16.0 * STUD:
				shot = true
				await _shot("1_%s" % way)
			if not panel.is_playing():
				break
		await _frames(4)
		if way == "play":
			var moved: float = _moved_far(built)
			_check("Play drives it in the view, drawn up to %.1f studs from where it was built, and leaves it where the path ends (%.1f studs on), one step"
				% [far / STUD, moved / STUD], far > 30.0 * STUD and moved > 30.0 * STUD
				and _builder.history_depth() == depth + 2)
			_check("...in the window all the way: its middle in it in %d frames drawn, out of it in %d" % [seen, unseen],
				seen > 10 and unseen == 0)
			await _shot("1_driven")
		else:
			var back: Array = _off(built, 0.05)
			_check("Play backwards drives it back, drawn up to %.1f studs off, to where it was built: %d parts off, %.3f LDU at most, one step"
				% [far / STUD, back[0], back[1]], far > 30.0 * STUD and int(back[0]) == 0
				and _builder.history_depth() == depth + 3)
			_check("...in the window all the way: its middle in it in %d frames drawn, out of it in %d" % [seen, unseen],
				seen > 10 and unseen == 0)
	# Its editor: the path's legs, a row each.
	await _click(panel._row_buttons[row]["edit"])
	await _frames(6)
	var rows: Array = panel.get("_path_controls") if panel.get("_path_controls") != null else []
	var said: String = ""
	if rows.size() == 2:
		var kind: OptionButton = rows[1][0]
		var amount: SpinBox = rows[1][1]
		var radius: SpinBox = rows[1][2]
		said = "%s %s, %s %s r %s" % [(rows[0][0] as OptionButton).get_item_text((rows[0][0] as OptionButton).selected),
			(rows[0][1] as SpinBox).value, kind.get_item_text(kind.selected), amount.value, radius.value]
	_check("its editor shows the path's two legs, a row each: %s" % said, rows.size() == 2
		and said.begins_with("Straight 32") and said.contains("Left 90"))
	_fits(panel, "editor")
	await _shot("1_editor")
	if rows.size() == 2:
		var kind: OptionButton = rows[1][0]
		kind.select(2)
		kind.item_selected.emit(2)
		await _frames(6)
		var lines: PackedStringArray = _motion_lines(_store.to_text("Racer"))
		var path_line: String = ""
		for line: String in lines:
			if line.contains("MOTION_PATH"):
				path_line = line
		_check("the corner made right there, the file says so: %s" % path_line, path_line.contains(" RIGHT 90 RADIUS "))
		await _shot("1_right")
		shell.run("undo")
		await _frames(6)
		lines = _motion_lines(_store.to_text("Racer"))
		_check("...and undo makes it left again", "\n".join(lines).contains(" LEFT 90 RADIUS "))
	panel.back_to_list()
	shell.run("pose")
	await _frames(4)


func _fits(panel: PosePanel, state: String) -> void:
	await _frames(2)
	var rect: Rect2 = panel.get_global_rect()
	var view: Rect2 = root.get_visible_rect()
	_check("%s: the panel fits the window (%s in %s)" % [state, str(rect.size.round()), str(view.size)],
		view.encloses(rect))
	var rows: Array = panel.get("_path_controls") if panel.get("_path_controls") != null else []
	for row: Array in rows:
		for item: Variant in row:
			var control: Control = item
			if control.visible and not rect.encloses(control.get_global_rect()):
				_check("%s: a leg's %s shows whole in the panel" % [state, control.get_class()], false)


# -- 2. defined over MCP -----------------------------------------------------------------------


func _defined() -> Motions.Motion:
	print("\n2. define_motion with path=")
	var built: Dictionary = _poses()
	var depth: int = _builder.history_depth()
	var said: String = await _say("define_motion", {"name": NAME, "path": {"legs": [{"straight": 32},
		{"left": 90}]}})
	_print(said)
	_check("define_motion keeps a 32-stud straight and a quarter turn left, played once to check",
		said.begins_with("Changed \"%s\"" % NAME) or said.begins_with("Kept \"%s\"" % NAME))
	_check("...the model put back (%d parts off)" % _off(built, 0.0)[0], int(_off(built, 0.0)[0]) == 0)
	_check("...one undo step", _builder.history_depth() == depth + 1)
	var listed: String = await _say("list_motions", {"suggest": false})
	_print(listed)
	_check("list_motions says where it drives and what turns as it rolls",
		listed.contains("32 studs straight, then 90° left") and listed.contains("wheels turn as it rolls"))
	var motion: Motions.Motion = _player.motions().named(NAME)
	if motion == null or motion.get("path") == null:
		_check("the motion has a path", false)
		return null
	return motion


# -- 3, 4. its frames -------------------------------------------------------------------------


## [param motion] played and its frames read: the path its back axle's
## middle takes, and each axle's turns. Returns what the file is checked
## against: {"end": the chassis' last move, "radius": studs}.
func _played(motion: Motions.Motion) -> Dictionary:
	print("\n3. played, read from its frames")
	var built: Dictionary = _poses()
	var played: MotionPlayer.Played = _player.play(motion, false, 24, false)
	var frames: Array = played.frames
	_print(_player.said(played))
	_check("played, nothing changed (%d frames)" % frames.size(), frames.size() > 24 and int(_off(built, 0.0)[0]) == 0)
	if frames.size() < 2:
		return {}
	var radius: float = _radius_in_file()
	_check("the file's corner: a radius of %s studs" % radius, radius > 0.0)
	# The chassis: the part most of the model moves as, frame by frame.
	var chassis: int = _chassis(frames, built)
	var tyres: Array = _tyres()
	var axles: Array = _axles(tyres, frames, built)
	var moves: Array = frames.map(func(frame: Dictionary) -> Transform3D:
		return (frame.get(chassis, built[chassis]) as Transform3D) * (built[chassis] as Transform3D).affine_inverse())
	# Steered axles turn about the upright against the chassis; the others
	# do not. The back axle: the one the steering does not turn.
	var fixed: Array = axles.filter(func(axle: Dictionary) -> bool: return not _steered(axle, frames, moves))
	var steered: Array = axles.filter(func(axle: Dictionary) -> bool: return _steered(axle, frames, moves))
	_check("its axles: %d, %d of them steered (each front wheel on its own stub axle)" % [axles.size(),
		steered.size()], axles.size() == 3 and steered.size() == 2 and fixed.size() == 1)
	if fixed.is_empty() or steered.is_empty():
		return {}
	var back: Dictionary = fixed[0]
	var line: Vector3 = back["axis"]
	var forward: Vector3 = Vector3.UP.cross(Vector3(line.x, 0.0, line.z).normalized()).normalized()
	var front := Vector3.ZERO
	for axle: Dictionary in steered:
		front += (axle["middle"] as Vector3) / float(steered.size())
	if forward.dot(front - (back["middle"] as Vector3)) < 0.0:
		forward = -forward
	var left: Vector3 = Vector3.UP.cross(forward)
	var start: Vector3 = back["middle"]
	start.y -= float(back["radius"])
	var corner: Vector3 = start + forward * 32.0 * STUD + left * radius * STUD
	# Up to 32 studs ahead: on the straight line, still facing ahead. Past
	# it: on the circle whose middle is the radius to the left of the
	# straight's end, which only a path that turns there keeps to.
	var off_straight: float = 0.0
	var turned_early: float = 0.0
	var on_straight: int = 0
	var off_corner: float = 0.0
	var on_corner: int = 0
	var furthest: float = 0.0
	for n: int in frames.size():
		var at: Vector3 = (moves[n] as Transform3D) * start
		var ahead: float = (at - start).dot(forward)
		if ahead <= 32.0 * STUD:
			on_straight += 1
			furthest = maxf(furthest, ahead)
			off_straight = maxf(off_straight, absf((at - start).dot(left)))
			turned_early = maxf(turned_early, absf(rad_to_deg(_heading(moves[n], forward, left))))
		else:
			on_corner += 1
			off_corner = maxf(off_corner, absf(Vector3(at.x - corner.x, 0.0, at.z - corner.z).length() - radius * STUD))
	var last: Transform3D = moves.back()
	var end: Vector3 = last * start
	var wanted: Vector3 = start + forward * (32.0 + radius) * STUD + left * radius * STUD
	var turned: float = rad_to_deg(_heading(last, forward, left))
	_check("its back axle's middle goes straight on for 32 studs: %d frames up to %.2f studs, %.3f studs off the line and %.3f° off ahead at most"
		% [on_straight, furthest / STUD, off_straight / STUD, turned_early],
		on_straight > 10 and furthest > 30.0 * STUD and off_straight <= ON_THE_PATH and turned_early <= HEADING_DEG)
	_check("...then round a quarter circle of %s studs from there: %d frames, %.3f studs off it at most" % [radius,
		on_corner, off_corner / STUD], on_corner > 10 and off_corner <= ON_THE_PATH)
	_check("...ending turned %.2f° left (90 ± %.1f), %.3f studs from where that circle ends" % [turned, HEADING_DEG,
		end.distance_to(wanted) / STUD], absf(turned - 90.0) <= HEADING_DEG and end.distance_to(wanted) <= ON_THE_PATH)
	# No part left behind: every part ends near where the chassis' move puts it.
	var behind: int = 0
	var most: float = 0.0
	for key: Variant in built:
		var was: Transform3D = built[key]
		var now: Transform3D = (frames.back() as Dictionary).get(key, was)
		var off: float = now.origin.distance_to(last * was.origin)
		most = maxf(most, off)
		if off > 2.0 * STUD:
			behind += 1
	_check("the model goes whole: every part within %.1f LDU of where the path puts it (%d not)" % [most, behind],
		behind == 0)
	print("\n4. its wheels, each axle by itself")
	for axle: Dictionary in axles:
		_wheels(axle, frames, built)
	return {"end": last, "radius": radius, "start": start}


## The tyres' turns against the chassis and their middle's travel, for one
## axle: [param axle] {"tyres", "middle", "axis", "radius"}.
func _wheels(axle: Dictionary, frames: Array, built: Dictionary) -> void:
	var tyre: int = int((axle["tyres"] as Array)[0])
	var at_built: Transform3D = built[tyre]
	var middle_own: Vector3 = at_built.affine_inverse() * (axle["middle"] as Vector3)
	var info: PartLibrary.PartInfo = _library.parts.get(_world.get_brick(tyre).part_id)
	var own_axis: Vector3 = _own_axis(info.bounds)
	var radius: float = float(axle["radius"])
	var spun: float = 0.0
	var gone: float = 0.0
	var slipped: float = 0.0
	for n: int in range(1, frames.size()):
		var was: Transform3D = (frames[n - 1] as Dictionary).get(tyre, at_built)
		var now: Transform3D = (frames[n] as Dictionary).get(tyre, at_built)
		var turn := Quaternion((was.basis.orthonormalized().inverse() * now.basis.orthonormalized()).orthonormalized())
		spun += wrapf(2.0 * atan2(Vector3(turn.x, turn.y, turn.z).dot(own_axis), turn.w), -PI, PI)
		var from: Vector3 = was * middle_own
		var to: Vector3 = now * middle_own
		gone += Vector3(to.x - from.x, 0.0, to.z - from.z).length()
		# The axle's bottom, under its middle on the ground, as the tyre
		# carries it: still, rolled the right way.
		var bottom: Vector3 = from - Vector3.UP * radius
		var carried: Vector3 = now * (was.affine_inverse() * bottom)
		slipped += Vector3(carried.x - bottom.x, 0.0, carried.z - bottom.z).length()
	var turns: float = absf(spun) / TAU
	var rounds: float = gone / (TAU * radius)
	var share: float = turns / rounds - 1.0 if rounds > 0.0 else INF
	_check("%s (tyres %s): turned %.3f times while its middle went %.2f studs, %.3f rounds of its %.1f-LDU tyre: %+.2f%%"
		% [axle["name"], axle["tyres"], turns, gone / STUD, rounds, radius, share * 100.0],
		absf(share) <= WHEEL_SHARE)
	_check("...and rolled the right way: its bottom slid %.2f studs of the %.2f its middle went (%.1f%%)" % [
		slipped / STUD, gone / STUD, 100.0 * slipped / maxf(gone, 0.001)], slipped <= gone * 0.1)


## The part most of the model moves as: grouped by where the last frame
## puts each part, the biggest group's first.
func _chassis(frames: Array, built: Dictionary) -> int:
	var groups: Dictionary = {}
	var last: Dictionary = frames.back()
	for key: Variant in built:
		var was: Transform3D = built[key]
		var move: Transform3D = (last.get(key, was) as Transform3D) * was.affine_inverse()
		var said: String = "%s %s" % [move.origin.snapped(Vector3.ONE * 0.5), (move.basis.z).snapped(Vector3.ONE * 0.01)]
		if not groups.has(said):
			groups[said] = []
		(groups[said] as Array).append(int(key))
	var best: Array = []
	for said: String in groups:
		if (groups[said] as Array).size() > best.size():
			best = groups[said]
	return int(best[0])


func _tyres() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		if info != null and (info.name.contains("Tyre") or info.name.contains("Tire")):
			out.append(brick.id)
	return out


## The tyres grouped by what moves them as one (their places against each
## other the same in every frame): each {"name", "tyres", "middle" (their
## middle as built), "axis" (their axle's line as built), "radius" (from the
## mesh: its furthest point from that line)}.
func _axles(tyres: Array, frames: Array, built: Dictionary) -> Array:
	var groups: Array = []
	for id: int in tyres:
		var found: bool = false
		for group: Array in groups:
			if _together(int(group[0]), id, frames, built):
				group.append(id)
				found = true
				break
		if not found:
			groups.append([id])
	var out: Array = []
	for group: Array in groups:
		var middle := Vector3.ZERO
		var radius: float = 0.0
		var axis := Vector3.ZERO
		for id: int in group:
			var at: Transform3D = built[id]
			var info: PartLibrary.PartInfo = _library.parts.get(_world.get_brick(id).part_id)
			middle += (at * info.bounds.get_center()) / float(group.size())
			axis = (at.basis * _own_axis(info.bounds)).normalized()
			radius = maxf(radius, _mesh_radius(_world.get_brick(id).part_id, info.bounds))
		out.append({"name": "the axle at %s" % (middle / STUD).snapped(Vector3.ONE * 0.5), "tyres": group,
			"middle": middle, "axis": axis, "radius": radius})
	return out


func _together(one: int, other: int, frames: Array, built: Dictionary) -> bool:
	var first: Transform3D = (built[one] as Transform3D).affine_inverse() * (built[other] as Transform3D)
	for frame: Dictionary in frames:
		var now: Transform3D = (frame.get(one, built[one]) as Transform3D).affine_inverse() \
			* (frame.get(other, built[other]) as Transform3D)
		if now.origin.distance_to(first.origin) > 0.05 or not now.basis.is_equal_approx(first.basis):
			return false
	return true


## Whether [param axle]'s line turns about the upright against the chassis
## in any frame (the steering turns it).
func _steered(axle: Dictionary, frames: Array, moves: Array) -> bool:
	var tyre: int = int((axle["tyres"] as Array)[0])
	var at_built: Transform3D = _world.get_brick(tyre).transform
	var line: Vector3 = axle["axis"]
	for n: int in frames.size():
		var now: Transform3D = (frames[n] as Dictionary).get(tyre, at_built)
		var against: Basis = (moves[n] as Transform3D).basis.inverse() * now.basis * at_built.basis.inverse()
		var turned: Vector3 = against * line
		if absf(Vector3(turned.x, 0.0, turned.z).normalized().cross(Vector3(line.x, 0.0, line.z).normalized()).y) > 0.02:
			return true
	return false


## The part's own axle: its box's thinnest side.
static func _own_axis(bounds: AABB) -> Vector3:
	var size: Vector3 = bounds.size
	if size.x <= size.y and size.x <= size.z:
		return Vector3.RIGHT
	return Vector3.UP if size.y <= size.z else Vector3.BACK


## The furthest point of the part's mesh from its own axle through its box's
## middle, LDU: a tyre's radius as its tread is drawn.
func _mesh_radius(part_id: String, bounds: AABB) -> float:
	var mesh: Lbm.PartMesh = _library.mesh_for(part_id)
	var axis: Vector3 = _own_axis(bounds)
	var middle: Vector3 = bounds.get_center()
	var most: float = 0.0
	var lists: Array = []
	if mesh != null:
		for surface: ArrayMesh in mesh.surfaces:
			for n: int in surface.get_surface_count():
				lists.append(surface.surface_get_arrays(n)[Mesh.ARRAY_VERTEX])
		for arrays: Variant in mesh.arrays:
			if arrays is Array and (arrays as Array).size() > Mesh.ARRAY_VERTEX:
				lists.append((arrays as Array)[Mesh.ARRAY_VERTEX])
	for points: Variant in lists:
		if not (points is PackedVector3Array):
			continue
		for point: Vector3 in points:
			var off: Vector3 = point - middle
			most = maxf(most, (off - axis * off.dot(axis)).length())
	return most if most > 0.0 else maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 0.5


static func _heading(move: Transform3D, forward: Vector3, left: Vector3) -> float:
	var now: Vector3 = move.basis * forward
	return atan2(now.dot(left), now.dot(forward))


func _radius_in_file() -> float:
	for line: String in _motion_lines(_store.to_text("Racer")):
		if line.contains("MOTION_PATH") and line.contains(" RADIUS "):
			return line.get_slice(" RADIUS ", 1).get_slice(" ", 0).to_float()
	return 0.0


# -- 5. the file --------------------------------------------------------------------------------


func _file(motion: Motions.Motion, shape: Dictionary) -> void:
	print("\n5. kept in the file")
	var text: String = _store.to_text("Racer drive")
	var lines: PackedStringArray = _motion_lines(text)
	_print("\n".join(lines))
	var joined: String = "\n".join(lines)
	_check("its lines: the path (SECONDS, EASE, STRAIGHT 32, LEFT 90 RADIUS), 3 wheels and the steering",
		joined.contains("MOTION_PATH \"%s\" SECONDS " % NAME) and joined.contains(" EASE STRAIGHT 32 LEFT 90 RADIUS ")
		and joined.count("MOTION_WHEEL \"%s\" AT " % NAME) == 3 and joined.count("MOTION_STEER \"%s\" AT " % NAME) == 1)
	var file: String = _out.path_join("racer_drive.mpd")
	var access := FileAccess.open(file, FileAccess.WRITE)
	access.store_string(text)
	access.close()
	_shared_text = text
	if not await _open(file):
		_check("the file opens again", false)
		return
	var again: PackedStringArray = _motion_lines(_store.to_text("Racer drive"))
	_check("opened again and written, its lines the same byte for byte", again == lines)
	var read: Motions.Motion = _player.motions().named(NAME)
	_check("...the motion read back with its path", read != null and read.get("path") != null)
	if read == null or read.get("path") == null or shape.is_empty():
		return
	var built: Dictionary = _poses()
	var played: MotionPlayer.Played = _player.play(read, false, 24, false)
	var chassis: int = _chassis(played.frames, built)
	var move: Transform3D = ((played.frames.back() as Dictionary).get(chassis, built[chassis]) as Transform3D) \
		* (built[chassis] as Transform3D).affine_inverse()
	var start: Vector3 = shape["start"]
	_check("...and played from the file it drives the same: ends %.3f studs from where it did" % [
		(move * start).distance_to((shape["end"] as Transform3D) * start) / STUD],
		(move * start).distance_to((shape["end"] as Transform3D) * start) <= ON_THE_PATH)


# -- 6. kept where it ends ---------------------------------------------------------------------


func _kept(shape: Dictionary) -> void:
	print("\n6. play_motion keeps it")
	var built: Dictionary = _poses()
	var depth: int = _builder.history_depth()
	var said: String = await _say("play_motion", {"name": NAME})
	_print(said)
	var moved: float = _moved_far(built)
	_check("played and kept: one step, the model %.1f studs from where it stood" % [moved / STUD],
		_builder.history_depth() == depth + 1 and moved > 30.0 * STUD)
	if not shape.is_empty():
		var start: Vector3 = shape["start"]
		var chassis: int = _chassis([_poses()], built)
		var move: Transform3D = _world.get_brick(chassis).transform * (built[chassis] as Transform3D).affine_inverse()
		_check("...standing where the path ends (%.3f studs off)" % [(move * start).distance_to(
			(shape["end"] as Transform3D) * start) / STUD],
			(move * start).distance_to((shape["end"] as Transform3D) * start) <= ON_THE_PATH)
	_check("...on its floor: the floor covers where it stands", _on_floor())
	await _shot("6_kept")
	said = await _say("play_motion", {"name": NAME, "reverse": true})
	_print(said)
	var back: Array = _off(built, 0.05)
	_check("backwards, it drives back where it began (%d parts off, %.3f LDU at most)" % back, int(back[0]) == 0)
	await _say("undo", {})
	await _say("undo", {})
	await _frames(4)
	_check("...and undone, on its floor still where it was built", _on_floor())
	var undone: Array = _off(built, 0.0)
	_check("undo twice, every part exactly where it was (%d off)" % undone[0], int(undone[0]) == 0
		and _builder.history_depth() == depth)


# -- 7. rendered ---------------------------------------------------------------------------------


func _rendered() -> void:
	print("\n7. rendered")
	if not _windowed:
		print("  (headless: not rendered)")
		return
	var built: Dictionary = _poses()
	var rendered: Dictionary = await _finished(await _rpc("tools/call", {"name": "render_motion",
		"arguments": {"name": NAME}}))
	var said: String = _text(rendered)
	_print(said)
	var webp: String = _out.path_join(str((_main.get("_pose") as PosePanel)._last.get("name", "")))
	_check("render_motion renders it, a WebP, the model as it was", said.contains("Rendered ")
		and FileAccess.file_exists(webp) and int(_off(built, 0.0)[0]) == 0)
	var sheet: Image = _image_of(rendered)
	if sheet != null:
		sheet.save_png(_out.path_join("%s_7_rendered_sheet.png" % _size))
	var frames: String = webp.get_basename()
	var drawn: int = 0
	for kept: String in DirAccess.get_files_at(frames):
		if kept.begins_with("frame_") and kept.ends_with(".png"):
			drawn += 1
	var first: Image = Image.load_from_file(frames.path_join("frame_0001.png")) if drawn > 0 else null
	var last: Image = Image.load_from_file(frames.path_join("frame_%04d.png" % drawn)) if drawn > 0 else null
	# Where the racer is drawn in each: the middle of what is not the
	# backdrop, as a share of the frame's width.
	var from: Vector2 = _drawn_middle(first)
	var to: Vector2 = _drawn_middle(last)
	var went: float = from.distance_to(to) / float(first.get_width()) if first != null else 0.0
	_check("its %d frames: the racer drawn %.0f%% of the frame's width from where it began by the last" % [drawn,
		went * 100.0], drawn > 24 and went > 0.25)
	if first != null:
		first.save_png(_out.path_join("%s_7_first_frame.png" % _size))
		var middle: String = frames.path_join("frame_%04d.png" % maxi(drawn / 2, 1))
		if FileAccess.file_exists(middle):
			Image.load_from_file(middle).save_png(_out.path_join("%s_7_middle_frame.png" % _size))
		last.save_png(_out.path_join("%s_7_last_frame.png" % _size))


## The middle of what [param image] draws that is not its backdrop (its
## corner's colour), pixels.
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
	return sum / float(count) if count > 0 else Vector2.ZERO


# -- 8. a link that opens it playing --------------------------------------------------------------


func _link() -> void:
	print("\n8. a link opens it driving (?motion=%s)" % Motions.slug(NAME))
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": LINK_ID, "name": "Probe Racer", "author": "Probe Builder",
		"parts": 0, "url": "https://brickworks.diy/m/" + LINK_ID, "model": _shared_text}}
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_viewing", LINK_ID)
	_main.set("_shared", fake)
	_main.set("_viewing_motion", Motions.slug(NAME))
	root.add_child(_main)
	var world: BrickWorld = null
	var built: Dictionary = {}
	var shown_at: int = 0
	var far: float = 0.0
	# Each tyre's most turned against the chassis, degrees.
	var turned: Dictionary = {}
	var chassis: int = 0
	var shot: bool = false
	# Frames drawn with all of it in sight, or not; and off its floor.
	var in_sight: int = 0
	var out_of_sight: int = 0
	var off_floor: int = 0
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 120000:
		await process_frame
		var view: ShareView = _main.get("_share_view")
		if view == null:
			continue
		if view.state in ["failed", "gone"]:
			break
		if shown_at == 0 and view.state == "ready":
			shown_at = Time.get_ticks_msec()
			world = _main.get("_world")
			_world = world
			_library = _main.get("_library")
			built = _poses()
			for id: int in _tyres():
				turned[id] = 0.0
		if shown_at == 0:
			continue
		far = maxf(far, _drawn_far(built))
		var drawn: Dictionary = world.drawn_ids()
		if not drawn.is_empty():
			var whole: Array = _whole_in_sight(drawn)
			if bool(whole[0]):
				in_sight += 1
			else:
				out_of_sight += 1
			if not bool(whole[1]):
				off_floor += 1
		if chassis == 0 and far > 5.0 * STUD:
			var frame: Dictionary = built.duplicate()
			frame.merge(drawn, true)
			chassis = _chassis([frame], built)
		if chassis != 0 and drawn.has(chassis):
			var body: Basis = (drawn[chassis] as Transform3D).basis
			var body_built: Basis = (built[chassis] as Transform3D).basis
			for id: int in turned:
				if drawn.has(id):
					var was: Basis = body_built.inverse() * (built[id] as Transform3D).basis
					var now: Basis = body.inverse() * (drawn[id] as Transform3D).basis
					turned[id] = maxf(float(turned[id]), rad_to_deg(Quaternion((was.inverse() * now).orthonormalized())
						.get_angle()))
		if not shot and far > 20.0 * STUD:
			shot = true
			await _shot("8_link_driving")
		if Time.get_ticks_msec() - shown_at > 12000:
			break
	_check("the link's racer opened", shown_at > 0)
	var least: float = INF
	for id: int in turned:
		least = minf(least, float(turned[id]))
	_check("...and drives: drawn up to %.1f studs from where it was built, every one of its %d tyres turned against the chassis, %.0f° the least (12 s)"
		% [far / STUD, turned.size(), least if not turned.is_empty() else 0.0],
		far > 30.0 * STUD and not turned.is_empty() and least > 90.0)
	_check("...all of it in the window all the way: in sight in %d frames drawn, out of it in %d" % [in_sight, out_of_sight],
		in_sight > 10 and out_of_sight == 0)
	_check("...and on its floor all the way: off it in %d frames drawn" % off_floor,
		in_sight > 10 and off_floor == 0)
	var builder: Builder = _main.get("_builder") if _main != null else null
	_check("...drawn only: the store wrote nothing, no step kept", builder != null and builder.history_depth() == 0
		and _off(built, 0.0)[0] == 0)


# -- 9. someone else's file, as the review tried it -------------------------------------------------


func _review() -> void:
	print("\n9. someone else's file, driven, kept and saved (drivereview)")
	if not await _open(RACER):
		_check("the racer opens", false)
		return
	await _say("define_motion", {"name": NAME, "suggested": true})
	var defined: String = _saved("rv_defined.mpd")
	_print((await _say("play_motion", {"name": NAME})).get_slice("\n", 0))
	var driven: String = _saved("rv_driven.mpd")
	var a: PackedStringArray = defined.split("\n")
	var b: PackedStringArray = driven.split("\n")
	var main_end: int = _main_end(a)
	var placing: int = 0
	var other := PackedStringArray()
	var noisy := PackedStringArray()
	for n: int in mini(a.size(), b.size()):
		if a[n] == b[n]:
			continue
		if a[n].strip_edges().begins_with(Motions.META) and b[n].strip_edges().begins_with(Motions.META):
			continue
		if n < main_end and a[n].begins_with("1 ") and b[n].begins_with("1 "):
			placing += 1
			if _rotation_words(a[n]) != _rotation_words(b[n]):
				if noisy.is_empty():
					noisy.append("%d: %s -> %s" % [n + 1, a[n].c_escape().left(90), b[n].c_escape().left(90)])
				else:
					noisy.append("")
			continue
		if other.size() < 3:
			other.append("%d: %s -> %s" % [n + 1, a[n].c_escape().left(90), b[n].c_escape().left(90)])
		else:
			other.append("")
	_print("main model %d lines; %d placing lines moved; other lines changed: %d %s" % [main_end, placing,
		other.size(), " | ".join(other.slice(0, 3))])
	_check("F2: kept and saved, the same lines (%d, %d) and only main-model placing lines and motion lines differ (%d other)"
		% [a.size(), b.size(), other.size()], a.size() == b.size() and other.is_empty() and placing > 0)
	var bare: int = 0
	for line: String in b:
		if line.strip_edges().begins_with(Motions.META) and not line.ends_with("\r"):
			bare += 1
	_check("F2: ...CRLF kept (%d and %d), the motion lines in CRLF too (%d not), and no float noise" % [
		defined.count("\r\n"), driven.count("\r\n"), bare], defined.count("\r\n") == driven.count("\r\n")
		and bare == 0 and RegEx.create_from_string("\\b-?0\\.0000\\d*[1-9]").search(driven) == null)
	# A quarter turn shuffles a line's rotation and turns some signs; the numbers
	# themselves come back as the author wrote them (0.988, not 0.98799998).
	_check("F2: ...each moved line's rotation in the author's own numbers, turned (%d of %d not%s)" % [
		noisy.size(), placing, (": " + noisy[0]) if not noisy.is_empty() else ""], noisy.is_empty() and placing > 0)
	var file: String = _out.path_join("rv_driven.mpd")
	await _open(file)
	_check("F1: opened again, the drive's joints all find their part (%s)" % _found(), _found_all())
	# Moved whole by hand, nothing asked of its joints first: live's own bug.
	await _open(file)
	_move_all(Vector3(40.0, 0.0, 0.0))
	_saved("rv_by_hand.mpd")
	await _open(_out.path_join("rv_by_hand.mpd"))
	_check("F1: moved whole by hand, saved and opened again, its joints all found (%s)" % _found(), _found_all())
	# A part put back as another id (Builder.renumber), the model moved
	# since its file was read, so its place no longer finds it.
	_move_all(Vector3(0.0, 0.0, 60.0))
	var motion: Motions.Motion = _player.motions().named(NAME)
	var path: Variant = motion.get("path") if motion != null else null
	var wheel: Motions.Joint = (path.get("wheels") as Array)[0] if path != null \
		and not (path.get("wheels") as Array).is_empty() else null
	var was: BrickWorld.Brick = _world.get_brick(wheel.lead) if wheel != null else null
	if was != null:
		var at: Transform3D = was.transform
		var part: String = was.part_id
		var colour: int = was.color_code
		var unit: String = was.unit
		var group: String = was.group
		_world.remove_brick(was.id)
		var again: int = _world.add_brick(part, colour, at)
		_world.get_brick(again).unit = unit
		_world.get_brick(again).group = group
		_builder.renumber(was.id, again)
		var back_as: Array = _player.parts_of(wheel)
		var text: String = _saved("rv_renumbered.mpd")
		var want: Vector3 = (at.origin - _store.lift()) * LdrModel.FLIP
		_check("F1: a wheel put back as #%d for #%d is found (%s) and written where it stands" % [again, was.id, back_as],
			back_as == [again] and text.contains(wheel.ref_words()) and wheel.place.distance_to(want) < 0.01)
		# And one taken off for good: written as it was, and the save says so.
		_builder.remove_brick_id(again)
		_saved("rv_wheel_gone.mpd")
		var gone: String = str(_store.get("motions_gone_words"))
		_print("a wheel taken off, saved: %s" % gone)
		_check("F1: a joint whose part is gone at a save gets a sentence naming its motion",
			gone.contains(Motions.quoted(NAME)) and gone.contains(part))
	else:
		_check("F1: a wheel of the drive found to put back", false)
	# Lines out of order, and lines it cannot read: said, read alike, kept as they are.
	var lines: PackedStringArray = _motion_lines(driven)
	var reordered := PackedStringArray()
	for line: String in lines:
		if line.contains("_WHEEL ") or line.contains("_STEER "):
			reordered.append(line)
	for line: String in lines:
		if not (line.contains("_WHEEL ") or line.contains("_STEER ")):
			reordered.append(line)
	var refused := PackedStringArray([
		'0 !BRICKWORKS MOTION "Too far" AFTER "" SECONDS 8',
		'0 !BRICKWORKS MOTION_PATH "Too far" SECONDS 8 EASE' + " STRAIGHT 1".repeat(33),
		'0 !BRICKWORKS MOTION_PATH "%s" SECONDS 8 EASE STRAIGHT 0.004' % NAME,
		'0 !BRICKWORKS MOTION_PATH "No radius" SECONDS 8 EASE STRAIGHT 32 LEFT 90'])
	var odd: String = Motions.written_into(driven, reordered + refused)
	_write(_out.path_join("rv_odd.mpd"), odd)
	await _open(_out.path_join("rv_odd.mpd"))
	var said: String = ModelBar.unshown_words(_store)
	_print("opened: %s" % said)
	var listed: String = await _say("list_motions", {"suggest": false})
	var read: Motions.Motion = _player.motions().named(NAME)
	var read_path: Variant = read.get("path") if read != null else null
	_check("F4: wheel and steering lines before their path read alike (%d wheels, steering %s)" % [
		(read_path.get("wheels") as Array).size() if read_path != null else 0,
		read_path != null and read_path.get("steer") != null],
		read_path != null and (read_path.get("wheels") as Array).size() == 3 and read_path.get("steer") != null)
	_check("F5: the 4 lines it cannot read said on open and by list_motions",
		said.contains("4 motion lines not read, kept in the file as they are") and listed.contains("4 motion lines not read"))
	var resaved: String = _saved("rv_odd_saved.mpd")
	var kept: int = 0
	for line: String in refused:
		if resaved.contains(line + "\r\n"):
			kept += 1
	_check("F5: ...and saved, each written back as it was, in CRLF (%d of %d)" % [kept, refused.size()],
		kept == refused.size() and _motion_lines(resaved).size() == lines.size() + refused.size())
	# Values from a session, each checked for what it is.
	var asked := {
		"a straight of 0.004 studs": [{"legs": [{"straight": 0.004}]}, "not 0.004"],
		"seconds of 0.0001": [{"seconds": 0.0001}, "not 0.0001"],
		"a straight of [1]": [{"legs": [{"straight": [1]}]}, "a number of studs"],
		"seconds of {}": [{"seconds": {}}, "a number of seconds"],
		"eased of \"no\"": [{"eased": "no"}, "true or false"],
		"a straight of 1e30": [{"legs": [{"straight": 1e30}]}, "not 1e+30"],
		"a word it has not": [{"legs": [], "speed": 3}, "not speed="],
	}
	for what: String in asked:
		var answer: String = await _say("define_motion", {"name": "Odd", "path": asked[what][0]})
		_check("F3/F7: %s refused in words (%s)" % [what, answer.get_slice("\n", 0).left(110)],
			answer.contains(str(asked[what][1])) and _player.motions().named("Odd") == null)
	var turned: String = await _say("define_motion", {"name": "Odd turn", "path": {"legs": [{"left": 90,
		"radius": 0.996}]}})
	var odd_turn: Motions.Motion = _player.motions().named("Odd turn")
	_check("F7: a radius of 0.996 kept as 1 (%s)" % turned.get_slice("\n", 0).left(80), odd_turn != null
		and odd_turn.get("path") != null and is_equal_approx(float((odd_turn.get("path").get("legs") as Array)[0][2]), 1.0))
	# The panel's seconds are the motion's length.
	var panel: PosePanel = _main.get("_pose")
	panel.edit(NAME)
	panel.call("set_path_seconds", 3.0)
	var length: float = _player.motions().named(NAME).length() if _player.motions().named(NAME) != null else -1.0
	_check("F8: the panel's Over at 3 seconds, the motion's length 3 (%s)" % Motions.num(length, 3),
		is_equal_approx(length, 3.0) and _store.to_text("Racer").contains('MOTION "%s" AFTER "" SECONDS 3' % NAME))
	panel.back_to_list()
	# A contact of no studs.
	var report := Balance.Report.new()
	var none := Balance.JointLoad.new()
	none.beyond_part = "3001"
	none.studs = 0
	none.moment = 2.0
	none.capacity = 0.0
	none.ratio = 2.0 / 0.000001
	report.joints = [none]
	report.margin = 40.0
	report.edge = "left"
	var words: String = (_main.get("_grab_drag") as GrabDrag).call("_standing_words", report, false)
	_check("F9: a contact of no studs said as no contact, no load divided (%s)" % words,
		words.contains("no stud in contact") and not words.contains("carry about"))


## Every part of the model moved by [param by] (LDU), one grab, as a
## person moving it all by hand.
func _move_all(by: Vector3) -> void:
	var moving := Grab.new()
	moving.world = _world
	moving.builder = _builder
	moving.library = _library
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			moving.rest[brick.id] = brick.transform
			moving.placed[brick.id] = Transform3D(Basis.IDENTITY, by) * brick.transform
	moving.commit("moved it all")


## The first line past the main model's: the second FILE line, or the end.
static ## A placing line's nine rotation numbers as written, signs dropped, in order:
## what a quarter turn leaves alone.
func _rotation_words(line: String) -> PackedStringArray:
	var words: PackedStringArray = LdrModel._fields(line.strip_edges())
	var out := PackedStringArray()
	for k: int in range(5, mini(14, words.size())):
		out.append(words[k].trim_prefix("-"))
	out.sort()
	return out


func _main_end(lines: PackedStringArray) -> int:
	var files: int = 0
	for n: int in lines.size():
		if lines[n].strip_edges().begins_with("0 FILE "):
			files += 1
			if files == 2:
				return n
	return lines.size()


## The model saved as the review saved it (ModelStore.save_file), its text.
func _saved(file: String) -> String:
	var path: String = _out.path_join(file)
	if not _store.save_file(path, "Racer"):
		_check("saved %s (%s)" % [file, _store.refused], false)
		return ""
	return FileAccess.get_file_as_string(path)


func _write(path: String, text: String) -> void:
	var access := FileAccess.open(path, FileAccess.WRITE)
	access.store_string(text)
	access.close()


## The drive's joints, found and not: "4 of 4".
func _found() -> String:
	var motion: Motions.Motion = _player.motions().named(NAME)
	if motion == null:
		return "no drive"
	var joints: Array = motion.joints()
	var found: int = joints.filter(func(one: Motions.Joint) -> bool: return not _player.parts_of(one).is_empty()).size()
	return "%d of %d" % [found, joints.size()]


func _found_all() -> bool:
	var motion: Motions.Motion = _player.motions().named(NAME)
	if motion == null or motion.joints().is_empty():
		return false
	return motion.joints().all(func(one: Motions.Joint) -> bool: return not _player.parts_of(one).is_empty())


# -- helpers --------------------------------------------------------------------------------------


func _open(path: String) -> bool:
	var real: String = ProjectSettings.globalize_path(path)
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


## Whether all of the model as [param drawn] puts it (the box round its
## parts' middles) is in the window's sight, and on its floor: [in, on].
func _whole_in_sight(drawn: Dictionary) -> Array:
	var box := AABB()
	var first: bool = true
	for key: Variant in drawn:
		var at: Vector3 = (drawn[key] as Transform3D).origin
		box = AABB(at, Vector3.ZERO) if first else box.expand(at)
		first = false
	var eye: Camera3D = _main.get("_camera")
	var inside: bool = eye != null
	for n: int in 8:
		var corner: Vector3 = box.get_endpoint(n)
		if inside and (eye.is_position_behind(corner)
				or not root.get_visible_rect().has_point(eye.unproject_position(corner))):
			inside = false
	var floor: Variant = _main.get("_floor")
	return [inside, floor != null and bool(floor.call("covers", box))]


## Whether the model's floor, as the window lays it, covers the model.
func _on_floor() -> bool:
	var floor: Variant = _main.get("_floor")
	return floor != null and bool(floor.call("covers", _main.call("_model_bounds")))


func _poses() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


## [parts not where [param built] has them, beyond [param slack] LDU or
## 0.05°; the furthest off, LDU].
func _off(built: Dictionary, slack: float) -> Array:
	var count: int = 0
	var most: float = 0.0
	for brick: BrickWorld.Brick in _world.bricks():
		var was: Variant = built.get(brick.id)
		if was == null:
			count += 1
			continue
		var off: float = brick.transform.origin.distance_to((was as Transform3D).origin)
		var turned: float = rad_to_deg(((was as Transform3D).basis.orthonormalized().inverse()
			* brick.transform.basis.orthonormalized()).get_rotation_quaternion().get_angle())
		most = maxf(most, off)
		if off > slack + 0.0001 or turned > 0.05 + slack:
			count += 1
	return [count, most]


## The furthest any part stands from [param built], LDU.
func _moved_far(built: Dictionary) -> float:
	var most: float = 0.0
	for brick: BrickWorld.Brick in _world.bricks():
		if built.has(brick.id):
			most = maxf(most, brick.transform.origin.distance_to((built[brick.id] as Transform3D).origin))
	return most


## The furthest any part is drawn from [param built], LDU.
func _drawn_far(built: Dictionary) -> float:
	var most: float = 0.0
	var drawn: Dictionary = _world.drawn_ids()
	for key: Variant in drawn:
		if built.has(int(key)):
			most = maxf(most, (drawn[key] as Transform3D).origin.distance_to((built[int(key)] as Transform3D).origin))
	return most


static func _motion_lines(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with(Motions.META):
			out.append(line.strip_edges())
	return out


func _say(tool: String, arguments: Dictionary) -> String:
	return _text(await _rpc("tools/call", {"name": tool, "arguments": arguments}))


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


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


func _finished(result: Dictionary) -> Dictionary:
	var found: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(_text(result))
	if found == null:
		return result
	for _n: int in 240:
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


var _last_screen := Vector2.ZERO


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
