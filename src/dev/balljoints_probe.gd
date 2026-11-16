## A ball joint seated and turned by hand, and over MCP (docs/APP_UX9.md,
## balljoints). Until this, the hand took pins, axles, holes, bars, clips,
## tyres and hinges and no ball, and a person's Claude asked to raise an arm
## 30° on a ball shoulder found nothing that turned and seated the socket
## already turned, in 38 calls (MCP f1).
##
##   godot --headless --path . --script src/dev/balljoints_probe.gd
##   godot --path . --resolution 1280x720 --script src/dev/balljoints_probe.gd -- --picture
##   --only=real, catalogue, turn, pose or session runs that part alone; --only=app the
##   last three in one app, in turn, as a whole run has them.
##
##  1. The real ones: every ball in its socket the stability reads in the
##     real sets' files (src/dev/balljoints_real.json, 749 kinds of pose of
##     1,111, read by src/dev/balljoints_scan.gd) seated by hand: the down
##     part where the set has it, the other held as the set turns it (the
##     nearest of the hand's square turns, the rest turned after with the
##     rotate handle's trackball about the ball), aimed at the ball (from
##     its side, along the stem, from above), T and R pressed as a person
##     presses them till the end wanted is on with room, clicked.
##     It lands at the set's place and turn to 0.01 LDU and 0.1°, with its
##     ball's centre on the socket's: where the set's own centres are apart
##     (a link's second end, a rod's ball rounded in a turned engine), the
##     set's place moved by that gap. Both ways round: the socket held onto
##     the ball, and the ball onto the socket. Where the set's own file has
##     the two meet past the ball's round, check_design refuses the set's
##     own place, and the hand refuses it by that one rule; those are
##     counted apart (9396-1's two links, tilted 24° and 41° on 2736).
##     --set=NAME runs the joints of the sets whose files begin so, and says
##     why each is refused.
##  2. The catalogue's: eleven more pairs, Joint-8 plates', towball plates'
##     with sockets drawn as solid rings (3730, 3183a), Technic tow balls
##     (2736, 6628, 2508), a trailer's hitching ball (779), Technic balls
##     (57908 in 57910, Constraction), a minifigure blaster's socket, seat
##     the same way at a turn check_design builds. The catalogue has no
##     Duplo ball; 3491's shape fills its socket's mouth, so check_design
##     builds it on no towball at any turn, and it is left out.
##  3. The turn: a seated arm turned 30° about two axes by the rotate
##     handle's rings (typed) keeps the ball's centre to 0.01 LDU; R in the
##     hand turns the part about the ball's own axis, its centre kept.
##  4. Pose: pose_model lists a sub-assembly on a ball as three joints, its
##     turns about x, y and z, and one swings it about the ball's centre.
##  5. The session's half: f1's arm (15456 on a stand, 3730 on its ball, the
##     arm on 3730) raised 30° by move_part about the ball, the stand still;
##     pose_model, with no sub-assembly to pose, names the ball and the turn.
##  6. --picture: a ball joint seated by hand, at the window's size, in
##     shots/balljoints/.
extends SceneTree

const REAL := "res://src/dev/balljoints_real.json"
const OUT := "res://shots/balljoints"
## How near a seat is to the set's, LDU and degrees (the bar).
const PLACE := 0.01
const TURN := 0.1
## How many times T is pressed for the end wanted on (a link's other end, the
## other way on), at most, and R at each (an eighth of a turn about the ball).
const TS := 8
const ROLLS := 8

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _library: PartLibrary
var _camera: CadCamera
var _verbs: EditVerbs
var _handles: Handles
var _next: int = 0
var _picture: bool = false
## --set=NAME: the real ones of those sets alone, each refusal said.
var _only_set: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_picture = "--picture" in OS.get_cmdline_user_args()
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	# The seats by hand in a model of their own, as technic_hand_probe has
	# them: the window's stability and grab read the model again at every
	# change, and 1,500 seats took minutes of it.
	if only.is_empty() or only == "real" or only == "catalogue":
		_library = PartLibrary.new()
		_library.load_catalogue()
		_world = BrickWorld.new()
		_world.library = _library
		root.add_child(_world)
		_builder = Builder.new()
		_builder.world = _world
		_builder.library = _library
		root.add_child(_builder)
		await process_frame
		if only.is_empty() or only == "real":
			_real_ones()
		if only.is_empty() or only == "catalogue":
			_catalogue()
		_builder.queue_free()
		_world.queue_free()
		await process_frame
	if not (only.is_empty() or only in ["turn", "pose", "session", "app"]) and not _picture:
		_end()
		return
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_camera = _main.get("_camera")
	_verbs = _main.get("_verbs")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	if only.is_empty() or only == "turn" or only == "app":
		await _turn()
	if only.is_empty() or only == "pose" or only == "app":
		await _pose()
	if only.is_empty() or only == "session" or only == "app":
		await _session()
	if _picture:
		await _shoot()
	_end()


func _end() -> void:
	print("")
	if _failures == 0:
		print("balljoints: a ball joint is seated by hand as the real sets seat it, both ways round, turns "
			+ "about its centre by the handle, R and Pose, and a session raises an arm on its ball")
	else:
		print("balljoints: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- the real ones and the catalogue's -----------------------------------------------------


func _real_ones() -> void:
	print("\nthe real ones: %s" % REAL.get_file())
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(REAL))
	var times: int = 0
	var tally: Dictionary = {}
	var worst: Dictionary = {}
	var started: int = Time.get_ticks_msec()
	# --set=NAME: only the joints of the sets whose file names begin so.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			_only_set = arg.trim_prefix("--set=")
	for one: Dictionary in cases:
		if not str(one["set"]).begins_with(_only_set):
			continue
		times += int(one["times"])
		var ball_at: Transform3D = _t(one["ball_at"])
		var socket_at: Transform3D = _t(one["socket_at"])
		for way: String in ["socket onto ball", "ball onto socket"]:
			var onto_ball: bool = way == "socket onto ball"
			var got: Dictionary = _seat(one["ball"] if onto_ball else one["socket"],
				ball_at if onto_ball else socket_at, one["socket"] if onto_ball else one["ball"],
				socket_at if onto_ball else ball_at)
			var kind: String = str(got["result"])
			# A set whose own file has the two meet past the ball's round, as
			# check_design builds nothing (no known fit either): refused by
			# hand by that one rule, as the check refuses the set's own.
			if kind != "at the set's place" and not _set_builds(one, ball_at, socket_at):
				kind = SET_PAST_ROUND
			var key: String = "%s: %s" % [way, kind]
			tally[key] = int(tally.get(key, 0)) + int(one["times"])
			if kind != "at the set's place" and not worst.has(key):
				worst[key] = "%s %s + %s: %s" % [one["set"], one["ball"], one["socket"], got["words"]]
	var keys: Array = tally.keys()
	keys.sort()
	for key: String in keys:
		print("    %s: %d%s" % [key, tally[key], (" (first: %s)" % worst[key]) if worst.has(key) else ""])
	print("    %d kinds of pose, %d joints, both ways, in %.1f s" % [cases.size(), times,
		(Time.get_ticks_msec() - started) / 1000.0])
	for way: String in ["socket onto ball", "ball onto socket"]:
		var landed: int = int(tally.get("%s: at the set's place" % way, 0))
		var past: int = int(tally.get("%s: %s" % [way, SET_PAST_ROUND], 0))
		_check("the real ones, %s: %d of %d land at the set's place to %.2f LDU and %.1f°%s" % [way,
			landed, times - past, PLACE, TURN, (" (%d more where %s)" % [past, SET_PAST_ROUND]) if past > 0 else ""],
			landed == times - past)


## Where the set's own file has its ball and socket meet as check_design
## builds no ball joint.
const SET_PAST_ROUND := "the set's own file meets past the ball's round, which check_design refuses"


## Whether check_design builds the joint of [param one] where its set has it
## ([param ball_at], [param socket_at]): its shapes meet only inside the
## ball's round (_builds), or no deeper than the sets meet those two parts
## (ExactCheck.meet_as_sets).
func _set_builds(one: Dictionary, ball_at: Transform3D, socket_at: Transform3D) -> bool:
	var centre := Vector3.INF
	var gap: float = INF
	for b: JointSnap.End in JointSnap.ends_for(_library, one["ball"]):
		for s: JointSnap.End in JointSnap.ends_for(_library, one["socket"]):
			if b.is_ball() and s.is_ball() and JointSnap.mates(b, s) \
					and (ball_at * b.at).distance_to(socket_at * s.at) < gap:
				gap = (ball_at * b.at).distance_to(socket_at * s.at)
				centre = (ball_at * b.at + socket_at * s.at) * 0.5
	if centre == Vector3.INF:
		return true
	if _builds(one["ball"], ball_at, one["socket"], socket_at, centre):
		return true
	return ExactCheck.meet_as_sets(Exact.Item.new(Exact.shape_for(_library, one["ball"]), ball_at),
		one["ball"], Exact.Item.new(Exact.shape_for(_library, one["socket"]), socket_at), one["socket"])


## The catalogue's kinds the real sets' files have none of in a socket.
const CATALOGUE: Array = [
	["3731", "3730", "a towball socket drawn as a solid ring, on a 2 x 2 towball plate"],
	["3184", "3183a", "a long towball socket plate on a towball plate"],
	["2736", "3730", "a Technic axle's towball in a towball socket plate"],
	["779", "3730", "a tractor trailer's hitching ball in a towball socket plate"],
	["2508", "3183a", "a towball on its 3L extension in a long socket"],
	["57908", "57910", "a Technic ball (2 x 2 brick) in its socket"],
	["32474", "32174", "a Technic ball joint in a Constraction socket"],
	["47297", "47296", "a Constraction limb's ball in a double socket"],
	["14417", "23922", "a minifigure blaster's Joint-8 socket on a ball plate"],
	["22890", "98263", "a Joint-8 ball in a 1 x 4 socket plate"],
	["6628", "3730", "a towball pin's ball in a towball socket plate"],
]


func _catalogue() -> void:
	print("\nthe catalogue's")
	var seated: int = 0
	for pair: Array in CATALOGUE:
		var ball_end: JointSnap.End = _first_ball(pair[0], "ball")
		var socket_end: JointSnap.End = _first_ball(pair[1], "socket")
		if ball_end == null or socket_end == null:
			_check("%s: %s has a ball and %s a socket" % [pair[2], pair[0], pair[1]], false)
			continue
		# The set's place made up: the socket lined up on the ball, rolled
		# 25° about it and turned 20° about the two lines across it, the first
		# such turn check_design builds (a long socket plate turned into its
		# ball's plate is refused, rightly); else rolled only, the first roll
		# it builds.
		var ball_at := Transform3D(Basis.IDENTITY, Vector3(0, 24, 0))
		var site: JointSnap.End = ball_end.placed(ball_at, 0)
		var lined: Transform3D = JointSnap.pose(socket_end, site, -1, 0.0, 0.0, Basis.IDENTITY)
		var across: Vector3 = site.axis.cross(Vector3.UP if absf(site.axis.y) < 0.9 else Vector3.RIGHT).normalized()
		var other_way: Vector3 = site.axis.cross(across).normalized()
		var turned: Transform3D = _about(site.at, Basis(site.axis, deg_to_rad(25.0))) * lined
		var turns: Array = []
		for tilt: Vector2 in [Vector2(20, -20), Vector2(-20, 20), Vector2(20, 20), Vector2(-20, -20),
				Vector2(10, -10), Vector2(-10, 10), Vector2(10, 10), Vector2(-10, -10)]:
			turns.append(_about(site.at, Basis(across, deg_to_rad(tilt.x))
				* Basis(other_way, deg_to_rad(tilt.y)) * Basis(site.axis, deg_to_rad(25.0))) * lined)
		for roll: float in [25.0, 65.0, 115.0, 155.0, 205.0, 245.0, 295.0, 335.0]:
			turns.append(_about(site.at, Basis(site.axis, deg_to_rad(roll))) * lined)
		for tried: Transform3D in turns:
			if _builds(pair[0], ball_at, pair[1], tried, site.at):
				turned = tried
				break
		var ok: int = 0
		var words := PackedStringArray()
		for way: int in 2:
			var got: Dictionary = _seat(pair[0], ball_at, pair[1], turned) if way == 0 \
				else _seat(pair[1], turned, pair[0], ball_at)
			if str(got["result"]) == "at the set's place":
				ok += 1
			else:
				words.append("%s: %s" % ["socket onto ball" if way == 0 else "ball onto socket", got["words"]])
		seated += 1 if ok == 2 else 0
		_check("%s (%s in %s), both ways round%s" % [pair[2], pair[0], pair[1],
			"" if words.is_empty() else ": " + "; ".join(words)], ok == 2)
	print("    %d of %d" % [seated, CATALOGUE.size()])


## Whether ball part [param ball] at [param ball_at] and socket part [param
## socket] at [param socket_at] meet as check_design builds a ball joint
## (ExactCheck.at_joint): clear, or every overlap of their pieces inside the
## ball's round of [param centre].
func _builds(ball: String, ball_at: Transform3D, socket: String, socket_at: Transform3D,
		centre: Vector3) -> bool:
	var a := Exact.Item.new(Exact.shape_for(_library, ball), ball_at)
	var b := Exact.Item.new(Exact.shape_for(_library, socket), socket_at)
	for hit: Array in Exact.overlaps(a, b):
		if Exact.overlap_reach(a, int(hit[1]), b, int(hit[2]), centre) > float(ExactCheck.JOINT_ROUND["ball"]):
			return false
	return true


## [param held] seated by hand on [param down] where a set has them:
## {"result": "at the set's place" or why not, "words"}.
func _seat(down: String, down_at: Transform3D, held: String, held_at: Transform3D) -> Dictionary:
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_builder.clear_selection()
	# The two well above the ground (y up), which a set's file has anywhere
	# and the hand and a drag keep a part above.
	var lift := Vector3(0, maxf(0.0, 200.0 - minf(_lowest(down, down_at), _lowest(held, held_at))), 0)
	down_at = Transform3D(down_at.basis, down_at.origin + lift)
	held_at = Transform3D(held_at.basis, held_at.origin + lift)
	var down_id: int = _put(down, 7, down_at)
	# The ends that meet in the set: the nearest ball and socket of the two.
	var site: JointSnap.End = null
	var mine: JointSnap.End = null
	var gap: float = INF
	for end: JointSnap.End in JointSnap.ends_for(_library, down):
		if not end.is_ball():
			continue
		var placed: JointSnap.End = end.placed(down_at, down_id)
		for other: JointSnap.End in JointSnap.ends_for(_library, held):
			if other.is_ball() and JointSnap.mates(other, placed) \
					and (held_at * other.at).distance_to(placed.at) < gap:
				gap = (held_at * other.at).distance_to(placed.at)
				site = placed
				mine = other
	if site == null:
		return {"result": "no ball and socket", "words": "the hand reads no ball and socket on them"}
	# Where the set has it, its centre put on the ball's, its turn a true
	# turn (a file's matrix is written to six places).
	var want_basis: Basis = held_at.basis.orthonormalized()
	var want := Transform3D(want_basis, site.at - want_basis * mine.at)
	# Held as the set turns it, the nearest of the hand's square turns, and
	# aimed at the ball from the side the held part is on.
	var square: Array = _nearest_square(held_at.basis)
	var part: Lbm.PartMesh = _library.mesh_for(held)
	var out: Vector3 = want * part.bounds.get_center() - site.at
	if out.length() < 1.0:
		out = site.axis
	# From the held part's side first; then, as a person moves the pointer
	# when the line passes another socket of the part first (a link's other
	# end), along the ball's stem, from above, and from the other side.
	var aims: Array = []
	for way: Vector3 in [out, site.axis, Vector3.UP, (site.axis + Vector3.UP), -out]:
		if way.length() > 0.001 and not aims.any(func(was: Vector3) -> bool:
				return was.dot(way.normalized()) > 0.99):
			aims.append(way.normalized())
	_builder.held_part = held
	_builder.held_color = 4
	# Picked up afresh: no way on chosen with T for the last seat's part.
	_builder.set("_joint_part", "")
	var tries: Array = [square] + _squares()
	var placed_id: int = 0
	var clicked: Transform3D
	var on: int = 0
	var other_end: int = 0
	for both: Array in _each(aims, tries):
		var from: Vector3 = site.at + (both[0] as Vector3) * 240.0
		var turn: Array = both[1]
		if placed_id != 0:
			break
		_builder.held_face = turn[0]
		_builder.held_rotation = turn[1]
		_builder.update_preview(from, (site.at - from).normalized())
		if not _builder.is_on_joint():
			continue
		on += 1
		# Another end of it on the ball (a link's other socket), or no room
		# the way it goes on: T, as a person presses it, the next way on, and
		# R about the ball at each, till the end they want is on with room.
		var on_it: bool = false
		var presses: int = 0
		while presses < TS and not on_it:
			for _r: int in ROLLS:
				on_it = (_builder.ghost_transform() * mine.at).distance_to(site.at) <= PLACE \
					and _builder.can_place()
				if on_it or (_builder.ghost_transform() * mine.at).distance_to(site.at) > PLACE:
					break
				_builder.rotate_held(1)
				_builder.update_preview(from, (site.at - from).normalized())
			if on_it:
				break
			_builder.tip_held(1)
			_builder.update_preview(from, (site.at - from).normalized())
			presses += 1
		if not on_it:
			if (_builder.ghost_transform() * mine.at).distance_to(site.at) > PLACE:
				other_end += 1
			if not _only_set.is_empty():
				var g: Transform3D = _builder.ghost_transform()
				var ia := Exact.Item.new(Exact.shape_for(_library, down), down_at)
				var ib := Exact.Item.new(Exact.shape_for(_library, held), g)
				var reaches: Array = []
				for hit: Array in Exact.overlaps(ia, ib):
					reaches.append(snappedf(Exact.overlap_reach(ia, int(hit[1]), ib, int(hit[2]), site.at), 0.1))
				print("      %s from %s: the hand's site %s; its end %.3f off; in the way %d, reaches %s" % [
					turn, (both[0] as Vector3).snappedf(0.01), (_builder.get("_joint_site") as JointSnap.End).at,
					(g * mine.at).distance_to(site.at), _builder.room_blocker, reaches])
			continue
		clicked = _builder.ghost_transform()
		placed_id = _builder.place()
	if placed_id == 0:
		return {"result": "no turn in hand seats it", "words": "on the joint in %d of %d tries (aims and turns), %d of them by another end after %d presses of T, no room in the rest at %d presses of R each" % [
			on, aims.size() * tries.size(), other_end, TS, ROLLS]}
	var brick: BrickWorld.Brick = _world.get_brick(placed_id)
	if brick == null:
		return {"result": "placed nothing", "words": "place() gave %d" % placed_id}
	var centre_off: float = (brick.transform * mine.at).distance_to(site.at)
	if centre_off > PLACE:
		return {"result": "off the ball's centre", "words": "its centre %.3f LDU off the ball's" % centre_off}
	# The rest of the set's turn with the rotate handle, about the ball.
	if _angle(brick.transform.basis, want.basis) > TURN * 0.5:
		_builder.select_brick(placed_id, false)
		# Where the rotate handle stands on it (Handles._known), as the turn
		# section proves with the window's own handle.
		var hung: Dictionary = JointSnap.ball_hung(_world, _library, _builder.lattice,
			PackedInt64Array([placed_id]))
		var pivot: Vector3 = hung.get("point", Vector3.INF)
		if hung.is_empty() or pivot.distance_to(site.at) > PLACE:
			return {"result": "the handle not on the ball", "words": "the ball it hangs from %s" % [
				"none" if hung.is_empty() else "%.3f LDU off" % pivot.distance_to(site.at)]}
		var by: Transform3D = _about(pivot, want.basis * brick.transform.basis.inverse())
		if _builder.drag_begin() == 0 or _builder.drag_end(by, "turned on its ball") == 0:
			return {"result": "no room to turn to the set's turn", "words": "blocked by %s" % [_builder.refused_by]}
		brick = _world.get_brick(placed_id)
	var off: float = brick.transform.origin.distance_to(want.origin)
	var angle: float = _angle(brick.transform.basis, want.basis)
	if off > PLACE or angle > TURN:
		return {"result": "off the set's place", "words": "%.3f LDU and %.2f° off" % [off, angle]}
	return {"result": "at the set's place", "words": "%.3f LDU from the set's own (its centres %.3f apart)" % [
		brick.transform.origin.distance_to(held_at.origin), gap]}


# -- the turn ------------------------------------------------------------------------


func _turn() -> void:
	print("\nthe turn")
	# f1's arm raised 30° on its towball (about x) and turned 30° about the
	# ball's own line (z). 3730 tilts 40° on a towball before its rim meets
	# the ball's neck and swings 60° across, by the shapes, so 30° about x
	# and then 30° about y, a 41° cone, is refused as the real joint stops.
	var arm: Dictionary = _build_arm()
	await _ring_turns(PackedInt64Array([int(arm["socket"]), int(arm["arm"])]), arm["centre"], arm["mine"],
		[0, 2], "f1's arm on its towball")
	# A Technic ball's socket tilted 30° and swung 30° (about z, then y).
	_main.call("clear_model")
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	var ball_at := Transform3D(Basis.IDENTITY, Vector3(0, 120, 0))
	var ball_id: int = _put("57908", 0, ball_at)
	var site: JointSnap.End = _first_ball("57908", "ball").placed(ball_at, ball_id)
	var mine: JointSnap.End = _first_ball("57910", "socket")
	var socket: int = _put("57910", 4, JointSnap.pose(mine, site, -1, 0.0, 0.0, Basis.IDENTITY))
	await _ring_turns(PackedInt64Array([socket]), site.at, mine, [2, 1], "a Technic ball's socket")
	# R in the hand: about the ball's own axis, the centre kept.
	_world.clear()
	_builder.lattice.clear()
	ball_at = Transform3D(Basis.IDENTITY, Vector3(0, 24, 0))
	ball_id = _put("14417", 7, ball_at)
	site = _first_ball("14417", "ball").placed(ball_at, ball_id)
	var held: JointSnap.End = _first_ball("14418", "socket")
	var from: Vector3 = site.at + Vector3(20, 160, 200)
	_builder.held_part = "14418"
	_builder.held_face = "up"
	_builder.held_rotation = 0
	_builder.update_preview(from, (site.at - from).normalized())
	var before: Transform3D = _builder.ghost_transform()
	_builder.rotate_held(1)
	_builder.update_preview(from, (site.at - from).normalized())
	var after: Transform3D = _builder.ghost_transform()
	var turn: Basis = after.basis * before.basis.inverse()
	var axis: Vector3 = Quaternion(turn).get_axis()
	_check("R on the ball turns it %.1f° about the ball's own axis (%.3f off it), its centre %.4f LDU off" % [
		_angle(after.basis, before.basis), 1.0 - absf(axis.dot(site.axis)),
		(after * held.at).distance_to(site.at)], _builder.is_on_joint()
		and _angle(after.basis, before.basis) > 1.0 and absf(axis.dot(site.axis)) > 0.999
		and (after * held.at).distance_to(site.at) <= PLACE)
	_builder.held_part = ""
	_builder.hide_preview()


## The rotate handle on [param ids] (the first a part on its ball, its
## ball end [param mine], the ball's centre [param centre]): it stands on the
## ball's centre, and its rings, typed, turn them 30° about each of the
## model's [param axes] in turn (0 x, 1 y, 2 z), the centre kept, a step each.
func _ring_turns(ids: PackedInt64Array, centre: Vector3, mine: JointSnap.End, axes: Array,
		what: String) -> void:
	var socket: int = ids[0]
	_builder.clear_selection()
	for n: int in ids.size():
		_builder.select_brick(ids[n], n > 0)
	_verbs.set_mode("rotate")
	_handles = _verbs.handles
	_handles.frame = "model"
	await _frames(3)
	_check("%s: the rotate handle stands on the ball's centre (%s, %.4f LDU off)" % [what,
		_handles.pivot_is(), _handles.pivot().distance_to(centre)], _handles.pivot_is() == "ball"
		and _handles.pivot().distance_to(centre) <= PLACE)
	var was: Transform3D = _world.get_brick(socket).transform
	var depth: int = _builder.history_depth()
	var want: Basis = Basis.IDENTITY
	for n: int in axes:
		var way: Vector3 = [Vector3.RIGHT, Vector3.UP, Vector3.BACK][n]
		var started: bool = _handles._start({"kind": "ring", "axis": n, "way": way,
			"view": CadCamera.MAIN}, Vector2.ZERO)
		var typed: bool = started and _handles.begin_typing()
		var turned: bool = typed and _handles.typed_apply({"move": Vector3.ZERO, "turn": 30.0,
			"tilt": 0.0, "words": "30"})
		var now: Vector3 = _world.get_brick(socket).transform * mine.at
		_check("...a ring turns it 30° about %s, typed: its ball's centre %.4f LDU from where it was%s" % [
			"xyz"[n], now.distance_to(centre), "" if turned else " (%s, in the way: %s)" % [
				"turned none" if typed else "typing refused" if started else "the drag not begun",
				_builder.refused_by]], turned and now.distance_to(centre) <= PLACE)
		if started and not turned:
			_handles.typed_cancel()
			_builder.drag_end(Transform3D.IDENTITY)
		# Turned about the model's own axis each time, its way as the ring has it.
		var by: Basis = (_world.get_brick(socket).transform.basis * was.basis.inverse()) * want.inverse()
		want = Basis(way, deg_to_rad(30.0 * signf(Quaternion(by).get_axis().dot(way)))) * want
	var got: Transform3D = _world.get_brick(socket).transform
	_check("...turned 30° about %s and then %s, %.2f° from that, in %d steps to undo" % [
		"xyz"[int(axes[0])], "xyz"[int(axes[1])], _angle(got.basis, want * was.basis),
		_builder.history_depth() - depth],
		_angle(got.basis, want * was.basis) <= TURN and _builder.history_depth() - depth == axes.size())
	_verbs.set_mode("select")



# -- Pose and the session -------------------------------------------------------------


func _pose() -> void:
	print("\nPose")
	var arm: Dictionary = _build_arm()
	var centre: Vector3 = arm["centre"]
	var assemblies: Assemblies = (_main.get("_shell") as Object).get("assemblies")
	_builder.clear_selection()
	_builder.select_brick(int(arm["socket"]), false)
	_builder.select_brick(int(arm["arm"]), true)
	var path: String = assemblies.make("Arm")
	_builder.clear_selection()
	_check("the socket and the arm on it made the sub-assembly Arm (%s)" % path, not path.is_empty())
	var listed: String = await _say("pose_model", {})
	print("    %s" % listed.replace("\n", " | "))
	var turns: int = 0
	for axis: String in ["x", "y", "z"]:
		if listed.contains("Arm (about %s), on its ball" % axis):
			turns += 1
	_check("pose_model lists the arm on its ball as three joints, its turns about x, y and z (%d)" % turns,
		turns == 3)
	var was: Transform3D = _world.get_brick(int(arm["socket"])).transform
	var said: String = await _say("pose_model", {"joint": "Arm (about x)", "degrees": 30})
	var now: Transform3D = _world.get_brick(int(arm["socket"])).transform
	var mine: JointSnap.End = arm["mine"]
	_check("pose_model swings it 30° about x on its ball (%s): turned %.2f°, its centre %.4f LDU off" % [
		said, _angle(now.basis, was.basis), (now * mine.at).distance_to(centre)],
		absf(_angle(now.basis, was.basis) - 30.0) < TURN and (now * mine.at).distance_to(centre) <= PLACE)
	var back: String = await _say("pose_model", {})
	_check("...and lists it there after (%s)" % back.get_slice("\n", 1).strip_edges(),
		back.contains("Arm (about x), on its ball, at 30°"))


func _session() -> void:
	print("\nthe session's half")
	var arm: Dictionary = _build_arm()
	var centre: Vector3 = arm["centre"]
	var mine: JointSnap.End = arm["mine"]
	var stand_was: Transform3D = _world.get_brick(int(arm["ball"])).transform
	var was: Transform3D = _world.get_brick(int(arm["socket"])).transform
	var arm_was: Transform3D = _world.get_brick(int(arm["arm"])).transform
	# Asked what turns, with no sub-assembly, the answer names the ball and
	# how to turn it: f1's session asked, then asked move_part with no
	# degrees, before it turned the arm.
	var listed: String = await _say("pose_model", {})
	print("    pose_model: %s" % listed.replace("\n", " | "))
	_check("pose_model with nothing to pose names the socket on its ball and move_part's turn",
		listed.contains("#%d 3730 on #%d 15456's ball" % [arm["socket"], arm["ball"]]) and listed.contains("move_part {\"part\""))
	var said: String = await _say("move_part", {"part": str(arm["socket"]), "degrees": 30, "axis": [-1, 0, 0]})
	var now: Transform3D = _world.get_brick(int(arm["socket"])).transform
	var arm_now: Transform3D = _world.get_brick(int(arm["arm"])).transform
	print("    move_part: %s" % said.replace("\n", " | "))
	_check("move_part raises the arm 30° about the ball (turned %.2f°, its centre %.4f LDU off), the arm on it"
		% [_angle(now.basis, was.basis), (now * mine.at).distance_to(centre)],
		absf(_angle(now.basis, was.basis) - 30.0) < 0.5 and (now * mine.at).distance_to(centre) <= PLACE
		and _angle(arm_now.basis * arm_was.basis.inverse(), now.basis * was.basis.inverse()) < TURN)
	_check("...the stand where it was", _world.get_brick(int(arm["ball"])).transform.is_equal_approx(stand_was))
	_check("...and says the turn with its sign about the axis asked", said.contains("turned 30° about [-1, 0, 0] (asked 30°)"))
	var back: String = await _say("move_part", {"part": str(arm["socket"]), "degrees": -30, "axis": [-1, 0, 0]})
	_check("...and -30° about it says so, and takes it back (%.2f°)" % _angle(_world.get_brick(int(arm["socket"])).transform.basis, was.basis),
		back.contains("turned -30° about [-1, 0, 0] (asked -30°)")
		and _angle(_world.get_brick(int(arm["socket"])).transform.basis, was.basis) < TURN)
	await _aligned_end_for_end()


## A session's socket put on a ball by its connectors (edit_model's attach,
## Attach.pose), aligned end for end, its own -z along the model's +z, as
## f1's last walk had it: half a turn about up, studs up, and its -z along
## +z; not half a turn about a level line, studs down.
func _aligned_end_for_end() -> void:
	var a: Attach.Point = Attach.pick(Attach.points_of(_library, "15456"), "ball", 0)
	var b: Attach.Point = Attach.pick(Attach.points_of(_library, "3730"), "ball", 0)
	var posed: Dictionary = Attach.pose(Transform3D.IDENTITY, a, b,
		{"align": [Vector3(0, 0, -1), Vector3(0, 0, 1)]}) if a != null and b != null else {}
	var up_kept: float = -1.0
	var along: float = -1.0
	if posed.has("at"):
		var at: Basis = (posed["at"] as Transform3D).basis
		up_kept = (at * Vector3.UP).dot(Vector3.UP)
		along = (at * Vector3(0, 0, -1)).dot(Vector3(0, 0, 1))
	_check("a socket put on a ball aligned end for end (-z along +z): its -z along +z (%.3f), its up kept (%.3f)"
		% [along, up_kept], along > 0.999 and up_kept > 0.999)


## f1's model: a stand of bricks on a baseplate, 15456 on top with its ball
## out in front, 3730 on the ball lined up, a 2 x 6 plate on 3730.
func _build_arm() -> Dictionary:
	_main.call("clear_model")
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	# y up: a part's place is its top, the ground at 0.
	var base: int = _put("3958", 72, Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
	var top: float = 8.0
	for n: int in 3:
		top += 24.0
		_put("3003", 71, Transform3D(Basis.IDENTITY, Vector3(0, top, 0)))
	top += 8.0
	var ball_at := Transform3D(Basis.IDENTITY, Vector3(0, top, 0))
	var ball_id: int = _put("15456", 0, ball_at)
	var site: JointSnap.End = _first_ball("15456", "ball").placed(ball_at, ball_id)
	var mine: JointSnap.End = _first_ball("3730", "socket")
	var socket_at: Transform3D = JointSnap.pose(mine, site, -1, 0.0, 0.0, Basis.IDENTITY)
	var socket: int = _put("3730", 0, socket_at)
	# Long ways on 3730's studs, reaching out away from the ball.
	var arm: int = _put("3795", 14, socket_at * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, 8, -40)))
	return {"base": base, "ball": ball_id, "socket": socket, "arm": arm, "centre": site.at, "mine": mine}


# -- the picture -----------------------------------------------------------------------


func _shoot() -> void:
	print("\nthe picture")
	if DisplayServer.get_name() == "headless":
		_check("a picture needs a window", false)
		return
	# f1's stand, its towball out in front, and 3730 in hand.
	var arm: Dictionary = _build_arm()
	_builder.remove_brick_id(int(arm["arm"]))
	_builder.remove_brick_id(int(arm["socket"]))
	var centre: Vector3 = arm["centre"]
	_camera.look_from(Vector3(0.75, 0.5, 0.45).normalized())
	_camera.frame(AABB(centre - Vector3(60, 90, 60), Vector3(120, 120, 120)), 1.1)
	await _frames(40)
	# The socket in hand, pointed at the ball through the window, as a
	# person aims it.
	_builder.held_part = "3730"
	_builder.held_color = 4
	_builder.held_face = "up"
	_builder.held_rotation = 0
	var at: Vector2 = _camera.screen_of(centre)
	var from: Vector3 = _camera.ray_origin(at)
	_builder.update_preview(from, _camera.ray_normal(at))
	await _frames(6)
	await _save("1_socket_aimed_at_the_ball")
	var placed: int = _builder.place()
	_builder.held_part = ""
	_builder.hide_preview()
	await _frames(6)
	await _save("2_seated")
	_check("a picture of a ball joint seated by hand (%d placed) at %s" % [placed,
		DisplayServer.window_get_size()], placed != 0)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = ProjectSettings.globalize_path("%s/%dx%d/%s.png" % [OUT, size.x, size.y, name])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s" % path)


# -- helpers -------------------------------------------------------------------------


## Every pair of one of [param a] and one of [param b], the first of [param
## a] with each of [param b] first.
static func _each(a: Array, b: Array) -> Array:
	var out: Array = []
	for x: Variant in a:
		for y: Variant in b:
			out.append([x, y])
	return out


## How far down a part reaches at [param at]: its bounds' least y.
func _lowest(part: String, at: Transform3D) -> float:
	var mesh: Lbm.PartMesh = _library.mesh_for(part)
	return (at * mesh.bounds).position.y if mesh != null else at.origin.y


func _put(part: String, colour: int, at: Transform3D) -> int:
	var brick: int = _world.add_brick(part, colour, at)
	_builder.register(brick, part, at)
	return brick


func _first_ball(part: String, kind: String) -> JointSnap.End:
	for end: JointSnap.End in JointSnap.ends_for(_library, part):
		if end.kind == kind:
			return end
	return null


## The hand's square turn nearest [param basis]: [face, rotation].
func _nearest_square(basis: Basis) -> Array:
	var best: Array = ["up", 0]
	var least: float = INF
	for turn: Array in _squares():
		var angle: float = _angle(BrickLattice.basis_for(turn[0], turn[1]), basis)
		if angle < least:
			least = angle
			best = turn
	return best


func _squares() -> Array:
	var out: Array = []
	for face: String in BrickLattice.FACES:
		for rotation: int in 4:
			out.append([face, rotation])
	return out


## Degrees between two turns.
static func _angle(a: Basis, b: Basis) -> float:
	return rad_to_deg(Quaternion(a.orthonormalized()).angle_to(Quaternion(b.orthonormalized())))


static func _about(point: Vector3, turn: Basis) -> Transform3D:
	return Transform3D(Basis.IDENTITY, point) * Transform3D(turn, Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -point)


static func _t(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])),
		Vector3(a[9], a[10], a[11]))


func _frames(n: int) -> void:
	for _n: int in n:
		await process_frame


func _say(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	return text
