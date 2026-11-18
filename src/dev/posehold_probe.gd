## A pose that holds its own weight, or droops (docs/APP_UX9.md, posehold):
## each posed friction joint weighed against what one of its kind was
## measured to hold (data/joint_hold.json, tools/joint_hold_table.py), and
## marked, with how far over, where it droops.
##
##   godot --headless --path . --script src/dev/posehold_probe.gd
##   ... -- --only=table, built, sets or app runs that part alone.
##
##  1. The table, as the code reads it: a Technic ball and a friction pin
##     measured, each with its median hold inside what every one held and
##     what every one gave way under, and its sources linked; a small ball,
##     a click hinge, a friction hinge, a turntable and a clip on a bar with
##     no number at all. Balance's friction pin reads the table's.
##  2. Built, and worked by hand: the weight past the joint times how far its
##     middle is from the joint (about the ball's middle any way, about a
##     pin's line), against the table.
##     - Two 1 x 16s on a Technic ball (92013's socket on 17114's ball, the
##       pair the table was measured on), 2 x 4s stacked at their end: none
##       holds, 6 may droop (past what every joint measured held), 10
##       droops. The ball's holder is locked in by a plate to a second
##       column, so no stud joint but the arm's carries what it does.
##     - A Technic brick on one friction pin, a 1 x 16 on it and 1 x 4s at
##       its end: none holds, 2 may droop, 6 droops; both halves of the pin
##       weighed.
##     - The 10-stud arm with a 2 x 4 at its end: on a Technic ball it holds;
##       on a small ball (14417 in 14704) and on a click hinge (44302 and
##       44301) it is named, with what it carries, and not weighed, since
##       nobody has published what one holds.
##     - No friction joint (a tower and an arm on studs): nothing weighed or
##       named, and no word of a pose.
##  3. Real sets: 11 figures, mechs and creatures from the library, none of
##     them held out (tools/bench/realset.py's choice, 2026-11-18), each
##     with a friction joint weighed: every one holds at the box's own pose.
##     And 6 more whose joints are all of the kinds nobody measured: named.
##  4. The app, the ball arm loaded to droop:
##     - Check stability selects the arm, says it droops and the share
##       ("it holds 74% of what hangs on it"), and tints it red;
##     - pose_model with nothing asked names the droop and the share, in 1
##       call; swung up 60° it says the pose holds, and Check stability then
##       says it stands, the arm neither selected nor red;
##     - undone, Build, Motions…, New motion: the panel says the joint
##       droops and the share, each of the ball's rows marked so; the arm
##       raised on its slider, both go.
##
## Exits non-zero when an answer is wrong.
extends SceneTree

const SETS := "res://vendor/omr/files/"
## Figures, mechs and creatures with a friction joint weighed at the box's
## pose (a scan of the library, 2026-11-18). None is held out.
## 8001-1_AT---ST is 8001's second model, a walker; 5974-1's Galactic
## Enforcer opens into a mech.
const WEIGHED_SETS: Array[String] = ["8001-1", "8001-1_AT---ST", "8002-1", "8012-1", "21303-1",
	"17101-1_Vernie", "17101-1_Frankie-the-Cat", "5764-1", "5974-1", "8245-1", "40436-1"]
## Mechs and creatures whose joints are all of the kinds nobody measured:
## 70814-1's arms turn on click joints (47455 in 48171), which a friction
## pin's figure read as drooping.
const NAMED_SETS: Array[String] = ["70814-1", "31088-1_Angler-Fish", "31031-1_Chameleon", "7268-1",
	"4905-1", "6043-1"]

var _failures: int = 0
var _only: String = ""
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _main: Node
var _shell: Shell
var _pose: PosePanel
var _player: MotionPlayer
var _socket: CommandSocket
var _next: int = 0
var _began: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	if _only.is_empty() or _only in ["table", "built", "sets"]:
		_library = PartLibrary.new()
		if not _library.load_catalogue():
			print("no catalogue")
			quit(1)
			return
		if _only.is_empty() or _only == "table":
			_table()
		if _only.is_empty() or _only == "built":
			await _built()
		if _only.is_empty() or _only == "sets":
			await _sets()
		if _world != null:
			_world.queue_free()
			_builder.queue_free()
			await process_frame
	if _only.is_empty() or _only == "app":
		await _app()
	print("")
	if _failures == 0:
		print("posehold: each friction joint weighed against its kind's measured hold, a built droop "
			+ "droops and a built hold holds as worked by hand, the real sets hold at their pose, and "
			+ "Pose, Check stability and pose_model mark the droop with its share until the pose holds")
	else:
		print("posehold: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- 1. the table ----------------------------------------------------------------


func _table() -> void:
	print("the table: %s" % PoseHold.TABLE)
	var text: String = FileAccess.get_file_as_string(PoseHold.TABLE)
	var table: Dictionary = JSON.parse_string(text) if not text.is_empty() else {}
	var sources: Dictionary = table.get("sources", {})
	var kinds: PackedStringArray = PoseHold.kinds()
	_check("seven kinds, the measured first (%s)" % ", ".join(kinds), kinds.size() == 7
		and kinds[0] == PoseHold.TECHNIC_BALL and kinds[1] == PoseHold.FRICTION_PIN)
	for kind: String in kinds:
		var row: Dictionary = (table.get("kinds", {}) as Dictionary).get(kind, {})
		var cited: Array = row.get("sources", [])
		var linked: bool = not cited.is_empty() and cited.all(func(key: Variant) -> bool:
			return str((sources.get(str(key), {}) as Dictionary).get("url", "")).begins_with("https://"))
		if PoseHold.known(kind):
			print("    %s: holds %s N·cm, every one held %s, every one gave %s, %d measured (%s)" % [
				PoseHold.said(kind), Balance.tidy(PoseHold.holds(kind)), Balance.tidy(PoseHold.every_held(kind)),
				Balance.tidy(PoseHold.every_gave(kind)), PoseHold.measured(kind), ", ".join(cited)])
			_check("%s measured: every one held <= the median <= every one gave, its sources linked"
				% PoseHold.said(kind), PoseHold.every_held(kind) > 0.0
				and PoseHold.every_held(kind) <= PoseHold.holds(kind)
				and PoseHold.holds(kind) <= PoseHold.every_gave(kind) and PoseHold.measured(kind) >= 1 and linked)
		else:
			# Its source is the search that found nothing: where, and when.
			var searched: bool = not cited.is_empty() and cited.all(func(key: Variant) -> bool:
				var source: Dictionary = sources.get(str(key), {})
				return not str(source.get("quote", "")).is_empty() and not str(source.get("date", "")).is_empty())
			print("    %s: not known (%s)" % [PoseHold.said(kind), row.get("why", "")])
			_check("%s not known: no number at all, why said, and where it was searched for" % PoseHold.said(kind),
				row.get("holds_n_mm") == null and not row.has("every_held_n_mm")
				and PoseHold.holds(kind) == 0.0 and not str(row.get("why", "")).is_empty() and searched)
	_check("Balance's friction pin is the table's: %s N·cm where it slips, %s for a loose one" % [
		Balance.tidy(Balance.PIN_LETS_GO_N_CM), Balance.tidy(Balance.PIN_LOOSE_N_CM)],
		Balance.PIN_N_CM == PoseHold.holds(PoseHold.FRICTION_PIN)
		and Balance.PIN_LETS_GO_N_CM == PoseHold.holds(PoseHold.FRICTION_PIN)
		and Balance.PIN_LOOSE_N_CM == PoseHold.every_held(PoseHold.FRICTION_PIN))


# -- 2. built, and worked by hand -------------------------------------------------


func _built() -> void:
	print("\nbuilt, and worked by hand")
	for loads: Array in [[0, "holds"], [6, "may droop"], [10, "droops"]]:
		await _fresh()
		var arm: Dictionary = _ball_arm(int(loads[0]))
		_weighed_against_hand("two 1 x 16s on a Technic ball, %d 2 x 4s at their end" % int(loads[0]),
			arm, str(loads[1]))
	for loads: Array in [[0, "holds"], [2, "may droop"], [6, "droops"]]:
		await _fresh()
		var arm: Dictionary = _pin_arm(int(loads[0]))
		_weighed_against_hand("a Technic brick on one friction pin, %d 1 x 4s at its 1 x 16's end"
			% int(loads[0]), arm, str(loads[1]))
	await _fresh()
	_weighed_against_hand("the 10-stud arm with a 2 x 4 at its end on a Technic ball",
		_ball_arm(1, "6111"), "holds")
	for kind: String in [PoseHold.SMALL_BALL, PoseHold.CLICK_HINGE]:
		await _fresh()
		var arm: Dictionary = _small_ball_arm() if kind == PoseHold.SMALL_BALL else _hinge_arm()
		var report: Balance.Report = _weigh()
		var named: Array = report.unweighed.filter(func(one: Dictionary) -> bool:
			return int(one["beyond"]) == int(arm["moved"]) and str(one["kind"]) == kind)
		var words: String = PoseHold.pose_words(report, _named)
		print("    %s: %s" % [PoseHold.said(kind), words.replace("\n", " | ")])
		_check("the 10-stud arm with a 2 x 4 at its end on a %s: named, %s g past it, not weighed" % [
			PoseHold.said(kind), Balance.tidy(float(named[0]["grams"]) if not named.is_empty() else 0.0)],
			named.size() == 1 and report.adrift == 0 and float(named[0]["grams"]) > 5.0
			and report.joints.all(func(one: Balance.JointLoad) -> bool: return one.hold.is_empty())
			and words.contains("not weighed: no one has published what one holds")
			and not words.contains("droop"))
	# No friction joint: a tower, and an arm on studs.
	await _fresh()
	_foot(-20.0)
	for n: int in 6:
		_put("3003", Vector3(0, 48 + 24 * n, 0))
	_put("3001", Vector3(40, 192, 0))
	var plain: Balance.Report = _weigh()
	_check("no friction joint: none weighed or named, no word of a pose or a droop (%d joints)"
		% plain.joints.size(), not plain.joints.is_empty()
		and plain.joints.all(func(one: Balance.JointLoad) -> bool: return one.hold.is_empty())
		and plain.unweighed.is_empty() and PoseHold.pose_words(plain, _named).is_empty()
		and not plain.words().contains("droop") and not plain.said().contains("Pose:"))


## [param arm] weighed by Balance, against the same sum by hand: its joint's
## turning load and its verdict.
func _weighed_against_hand(what: String, arm: Dictionary, want: String) -> void:
	var report: Balance.Report = _weigh()
	var moved: int = arm["moved"]
	var one: Balance.JointLoad = null
	for joint: Balance.JointLoad in report.joints:
		if joint.beyond == moved and not joint.hold.is_empty():
			one = joint
	var hand: float = _by_hand(arm["past"], arm["at"], arm["way"])
	var kind: String = arm["kind"]
	var by_table: String = "droops" if hand > PoseHold.holds(kind) else (
		"may droop" if hand > PoseHold.every_held(kind) else "holds")
	var verdict: String = "" if one == null else ("droops" if one.droops() else (
		"may droop" if one.may_droop() else "holds"))
	print("    %s: %s N·cm by hand, %s by Balance, against %s (every one held %s): %s, %s" % [what,
		Balance.tidy(hand), Balance.tidy(one.moment) if one != null else "-",
		Balance.tidy(PoseHold.holds(kind)), Balance.tidy(PoseHold.every_held(kind)), verdict,
		PoseHold.share_words(one.share()) if one != null else ""])
	_check("%s: %s, as by hand (%s N·cm), within 1%%" % [what, want, Balance.tidy(hand)],
		one != null and one.hold == kind and absf(one.moment - hand) <= hand * 0.01 + 0.0005
		and by_table == want and verdict == want)
	var words: String = PoseHold.pose_words(report, _named)
	if want == "droops":
		_check("...and the pose's words say so, with the share: \"%s\"" % words.replace("\n", " | "),
			words.begins_with("Joints that droop: ") and words.contains(
				"holds %d%% of what hangs on" % PoseHold.percent(one.share())))
	elif want == "may droop":
		_check("...and the pose's words say a loose one may not hold: \"%s\"" % words.replace("\n", " | "),
			words.contains("and none droops") and words.contains("a loose joint of its kind may not"))


## The turning load, N·cm, of the parts [param past] about [param at]: the
## weight of all of them at their middle (each at the middle of its shape,
## as Stability weighs it) levered about the point whichever way where
## [param way] is zero, and about that line where it is not.
func _by_hand(past: Array, at: Vector3, way: Vector3) -> float:
	var grams: float = 0.0
	var middle := Vector3.ZERO
	for id: int in past:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		var mass: float = Stability.grams(info)
		grams += mass
		middle += (brick.transform * _library.mesh_for(brick.part_id).bounds.get_center()) * mass
	middle /= grams
	var newtons: float = grams / 1000.0 * Balance.GRAVITY
	var turning: Vector3 = (middle - at).cross(Vector3(0, -newtons, 0))
	var n_ldu: float = turning.length() if way == Vector3.ZERO else absf(turning.dot(way))
	return n_ldu * Balance.MM_PER_LDU / 10.0


# -- the builds (y up, a part's place the top of its body, the floor at 0) -------


func _fresh() -> void:
	if _world != null:
		_world.queue_free()
		_builder.queue_free()
		await process_frame
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	await process_frame


func _put(part: String, at: Vector3, basis: Basis = Basis.IDENTITY, unit: String = "") -> int:
	var where := Transform3D(basis, at)
	var id: int = _world.add_brick(part, 4 if unit.is_empty() else 14, where)
	_builder.register(id, part, where)
	if not unit.is_empty():
		_world.get_brick(id).unit = unit
		_world.get_brick(id).group = Assemblies.group_of(unit)
	return id


func _weigh() -> Balance.Report:
	var judge := Balance.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	return judge.measure(_world.bricks())


func _named(id: int) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	return "#%d %s" % [id, brick.part_id if brick != null else "?"]


## Two 1 x 16s side by side on the floor, as a foot along x from
## [param from], the first at [param near] across: under a 2 x 2 column at
## -10, under a 1-wide one at 0.
func _foot(from: float, near: float = -10.0) -> void:
	for z: float in [near, near + 20.0]:
		_put("2465", Vector3(from + 160.0, 24, z))


## A Technic ball's holder: 17114 on a column of four 2 x 2s, locked by a
## 2 x 4 plate to a second column beside it, so no stud joint of the holder
## alone carries the arm. Returns the ball's middle.
func _ball_holder() -> Vector3:
	_foot(-60.0)
	for n: int in 4:
		_put("3003", Vector3(0, 48 + 24 * n, 0))
	for n: int in 5:
		_put("3003", Vector3(-40, 48 + 24 * n, 0))
	var holder: int = _put("17114", Vector3(0, 144, 0))
	_put("3020", Vector3(-20, 152, 0))
	var ball: Vector3 = Vector3.ZERO
	for end: JointSnap.End in JointSnap.balls_of(_library, "17114"):
		if end.kind == "ball" and end.at.x > 0.0:
			ball = _world.get_brick(holder).transform * end.at
	return ball


## The arm on the ball: 92013's socket on it, [param lever] on its studs
## (two 1 x 16s side by side, or one 1 x 10), [param loads] 2 x 4s at the
## end, stacked.
func _ball_arm(loads: int, lever: String = "2465") -> Dictionary:
	var ball: Vector3 = _ball_holder()
	var socket: int = _put("92013", Vector3(80, 144, 0), Basis(Vector3.UP, PI), "Arm#1")
	var past: Array = [socket]
	var end: float
	if lever == "2465":
		for z: float in [-10.0, 10.0]:
			past.append(_put("2465", Vector3(220, 168, z), Basis.IDENTITY, "Arm#1"))
		end = 340.0
	else:
		past.append(_put("6111", Vector3(160, 168, 10), Basis.IDENTITY, "Arm#1"))
		end = 220.0
	for n: int in loads:
		past.append(_put("3001", Vector3(end, 192 + 24 * n, 0 if lever == "2465" else 20), Basis.IDENTITY,
			"Arm#1"))
	return {"moved": socket, "past": past, "at": ball, "way": Vector3.ZERO, "kind": PoseHold.TECHNIC_BALL}


## A 1 x 8 Technic brick on one friction pin (2780) in the end hole of
## another, on a third; a 1 x 16 on the hanging one, [param loads] 1 x 4s
## stacked at its end. The hanging brick's joint on the pin, the pin's line
## along z.
func _pin_arm(loads: int) -> Dictionary:
	_foot(-360.0, 0.0)
	_foot(-40.0, 0.0)
	_put("3702", Vector3(0, 48, 0))
	_put("3702", Vector3(0, 72, 0))
	_put("2780", Vector3(-60, 62, 10), Basis(Vector3.UP, -PI / 2.0), "Arm#1")
	var hanging: int = _put("3702", Vector3(-120, 72, 20), Basis.IDENTITY, "Arm#1")
	var past: Array = [hanging, _put("2465", Vector3(-200, 96, 20), Basis.IDENTITY, "Arm#1")]
	for n: int in loads:
		past.append(_put("3010", Vector3(-320, 120 + 24 * n, 20), Basis.IDENTITY, "Arm#1"))
	return {"moved": hanging, "past": past, "at": Vector3(-60, 62, 10), "way": Vector3(0, 0, 1),
		"kind": PoseHold.FRICTION_PIN}


## The 10-stud arm, a 2 x 4 at its end, on a small ball: 14704's socket on
## 14417's ball, side on, the ball past the column's edge (on its middle, the
## socket's cup would sit on the column's top).
func _small_ball_arm() -> Dictionary:
	_foot(-20.0)
	for n: int in 4:
		_put("3003", Vector3(0, 48 + 24 * n, 0))
	_put("14417", Vector3(0, 128, 10))
	var socket: int = _put("14704", Vector3(0, 128, 50), Basis(Vector3.UP, PI), "Arm#1")
	_put("6111", Vector3(80, 152, 50), Basis.IDENTITY, "Arm#1")
	_put("3001", Vector3(140, 176, 60), Basis.IDENTITY, "Arm#1")
	return {"moved": socket}


## The same arm on a click hinge: 44301's finger in 44302's fork.
func _hinge_arm() -> Dictionary:
	_foot(-20.0)
	for n: int in 4:
		_put("3003", Vector3(0, 48 + 24 * n, 0))
	_put("44302a", Vector3(0, 128, 0))
	var finger: int = _put("44301a", Vector3(60, 128, 0), Basis(Vector3.UP, PI), "Arm#1")
	_put("6111", Vector3(140, 152, 0), Basis.IDENTITY, "Arm#1")
	_put("3001", Vector3(200, 176, 10), Basis.IDENTITY, "Arm#1")
	return {"moved": finger}


# -- 3. real sets -----------------------------------------------------------------


func _sets() -> void:
	print("\nreal sets, at the box's own pose (%s)" % SETS)
	if not DirAccess.dir_exists_absolute(SETS):
		_check("the library's sets are here (tools/omr.py fetch brings them)", false)
		return
	await _fresh()
	var store := ModelStore.new()
	store.world = _world
	store.library = _library
	store.builder = _builder
	store.keeps = false
	var weighed_sets: int = 0
	var all_hold: bool = true
	var named_only: int = 0
	for name: String in WEIGHED_SETS + NAMED_SETS:
		var path: String = SETS + name + ".mpd"
		if not FileAccess.file_exists(path):
			_check("%s is in the library" % name, false)
			continue
		store.open_text(FileAccess.get_file_as_string(path), path.get_file())
		var judge := Balance.new()
		judge.library = _library
		judge.lattice = _builder.lattice
		judge.floor_ids = store.scenery
		var report: Balance.Report = judge.measure(_world.bricks())
		var weighed: Array = report.joints.filter(func(one: Balance.JointLoad) -> bool:
			return not one.hold.is_empty())
		var unknown: Dictionary = {}
		for one: Dictionary in report.unweighed:
			unknown[one["kind"]] = int(unknown.get(one["kind"], 0)) + 1
		var least: float = INF
		for one: Balance.JointLoad in weighed:
			least = minf(least, one.share())
		var droops: Array = PoseHold.drooping(report)
		print("    %s: %d parts, %d friction joints weighed, the least held %s; not weighed %s" % [name,
			_world.brick_count(), weighed.size(), PoseHold.share_words(least) if not weighed.is_empty()
			else "-", JSON.stringify(unknown)])
		for one: Balance.JointLoad in droops:
			print("      DROOPS #%d %s on #%d %s, %s" % [one.beyond, one.beyond_part, one.held_by,
				one.held_part, PoseHold.share_words(one.share())])
		all_hold = all_hold and droops.is_empty()
		if name in WEIGHED_SETS:
			if not weighed.is_empty():
				weighed_sets += 1
			_check("%s: every friction joint at the box's pose holds" % name,
				not weighed.is_empty() and droops.is_empty())
		else:
			var words: String = PoseHold.pose_words(report, _named, 8)
			if weighed.is_empty() and not unknown.is_empty() and words.contains("not weighed"):
				named_only += 1
			_check("%s: its joints nobody measured named, none given a number" % name,
				droops.is_empty() and not unknown.is_empty() and words.contains("not weighed"))
	_check("%d real sets with posed friction joints, every one holding; %d more named only" % [
		weighed_sets, named_only], weighed_sets >= 10 and all_hold and named_only == NAMED_SETS.size())


# -- 4. the app -------------------------------------------------------------------


func _app() -> void:
	print("\nthe app: the ball arm loaded to droop")
	_began = Time.get_ticks_msec()
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	_at("the window up")
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_pose = _main.get("_pose")
	_player = _main.get("_motions")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_main.call("clear_model")
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	var arm: Dictionary = _ball_arm(10)
	var socket: int = arm["moved"]
	var top: int = (arm["past"] as Array).back()
	await _frames(5)
	_at("the arm built")
	var grabbing: GrabDrag = _main.get("_grab_drag")
	for _n: int in 1200:
		if grabbing.is_ready():
			break
		await process_frame
	_at("grab ready: %s" % grabbing.is_ready())
	var weighed: Stability.Report = await _main.call("weigh_joints")
	_at("weighed")
	var droop: Balance.JointLoad = null
	for one: Balance.JointLoad in PoseHold.drooping(weighed.balance):
		if one.beyond == socket:
			droop = one
	_check("the arm droops on its ball as built: %s" % (PoseHold.share_words(droop.share())
		if droop != null else "not drooping"), droop != null)
	if droop == null:
		return
	var share: String = "holds %d%% of what hangs on it" % PoseHold.percent(droop.share())

	# Check stability.
	await _check_stability()
	var said: String = (_shell.status.fields() as Dictionary)["message"]
	print("    Check stability: %s" % said)
	var tint: Variant = _world.tinted_ids().get(socket)
	_check("Check stability selects the arm and says it droops and the share (\"%s\")" % share,
		said.begins_with("1 weak joint, selected: 92013 droops on 17114 on a Technic ball joint")
		and said.contains("it " + share) and _builder.selection.has(socket))
	_check("...and tints it red", tint is Color and (tint as Color).is_equal_approx(BalanceMark.TIPS))

	# pose_model: the droop named in 1 call, then swung up to hold.
	var listed: String = await _say("pose_model", {})
	print("    pose_model: %s" % listed.replace("\n", " | "))
	_check("pose_model names the droop and its share in 1 call",
		listed.contains("Joints that droop: 1") and listed.contains("#%d " % socket)
		and listed.contains("its Technic ball joint " + share))
	var weakest: String = await _say("weakest_joints", {})
	print("    weakest_joints: %s" % weakest.left(400).replace("\n", " | "))
	_check("weakest_joints names it too, in 1 call: \"droops: it %s\"" % share,
		weakest.contains("droops: it " + share))
	var about_z: String = ""
	for line: String in listed.split("\n"):
		if line.contains("about z") and line.strip_edges().split(" ")[0].trim_suffix(".").is_valid_int():
			about_z = line.strip_edges().split(" ")[0].trim_suffix(".")
	var was: float = _world.get_brick(top).transform.origin.y
	var swung: String = ""
	for degrees: float in [60.0, -60.0]:
		swung = await _say("pose_model", {"joint": about_z, "degrees": degrees})
		if _world.get_brick(top).transform.origin.y > was + 40.0:
			break
	print("    swung up: %s" % swung.replace("\n", " | "))
	_check("...swung up 60° about z (joint %s), it says the pose holds" % about_z,
		_world.get_brick(top).transform.origin.y > was + 40.0
		and swung.contains("Friction joints weighed: 1, and none droops."))
	_builder.clear_selection()
	await _check_stability()
	said = (_shell.status.fields() as Dictionary)["message"]
	print("    Check stability: %s" % said)
	tint = _world.tinted_ids().get(socket)
	print("    the socket selected %s, tinted %s" % [_builder.selection.has(socket), tint])
	# The column on its narrow foot may tip in Check stability's sweep of
	# the arm's poses; what matters here is that the joint no longer droops.
	_check("...and Check stability no longer says it droops, the arm neither selected nor red",
		not said.contains("droop") and not said.contains("weak joint") and not _builder.selection.has(socket)
		and not (tint is Color and (tint as Color).is_equal_approx(BalanceMark.TIPS)))

	# Pose, after the swing undone: its hold lines name the ball's droop.
	# Pose's rows are Grab's joints, and Grab turns no ball (pose_model and
	# the rotate handle do), so a ball has no row to mark; a pin has.
	_builder.undo()
	await _frames(5)
	_check("undone, the arm is level again", absf(_world.get_brick(top).transform.origin.y - was) < 0.5)
	await _ready_to_grab()
	_shell.run("pose")
	await _frames(5)
	_pose._new.pressed.emit()
	await _frames(30)
	var lines: String = _pose.hold_words()
	print("    Pose: %s; %d rows" % [lines.replace("\n", " | "), _pose._joint_parts.size()])
	_check("Pose's hold lines say the ball joint droops, and the share",
		lines.begins_with("Joints that droop: 1") and lines.contains("its Technic ball joint " + share))
	_pose.back_to_list()
	await _frames(3)

	print("\nthe app: the pin arm loaded to droop, in Pose")
	_main.call("clear_model")
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	var pinned: Dictionary = _pin_arm(6)
	var hanging: int = pinned["moved"]
	top = (pinned["past"] as Array).back()
	await _frames(5)
	await _ready_to_grab()
	was = _world.get_brick(top).transform.origin.y
	_pose._new.pressed.emit()
	await _frames(30)
	await create_timer(0.3).timeout
	await _frames(10)
	lines = _pose.hold_words()
	var rows: Array = _pose._joint_parts.filter(func(row: Dictionary) -> bool:
		return Array(_pose.player.parts_of(row["joint"])).has(hanging))
	for row: Dictionary in _pose._joint_parts:
		print("    a row: %s, parts %s, marked %s \"%s\"" % [_pose.player.joint_words(row["joint"]),
			str(_pose.player.parts_of(row["joint"])), (row["droop"] as Label).visible, (row["droop"] as Label).text])
	var first: Balance.JointLoad = null
	for one: Balance.JointLoad in PoseHold.drooping(_pose.get("_hold_report")):
		first = one
		break
	share = "holds %d%% of what hangs on it" % (PoseHold.percent(first.share()) if first != null else -1)
	var marked: Array = rows.filter(func(row: Dictionary) -> bool:
		return (row["droop"] as Label).visible and (row["droop"] as Label).text == "Droops: it %s." % share)
	print("    Pose: %s; %d of the arm's %d rows marked (of %d)" % [lines.replace("\n", " | "), marked.size(),
		rows.size(), _pose._joint_parts.size()])
	_check("Pose says the pin droops and the share, and marks the arm's row so (\"Droops: it %s.\")" % share,
		lines.begins_with("Joints that droop:") and lines.contains("its friction pin " + share)
		and rows.size() == 1 and marked.size() == 1)
	var raised: bool = false
	for row: Dictionary in rows:
		for degrees: float in [60.0, -60.0]:
			(row["slider"] as HSlider).value = degrees
			await _frames(20)
			var drawn: Dictionary = _world.drawn_ids()
			if drawn.has(top) and (drawn[top] as Transform3D).origin.y > was + 40.0:
				raised = true
				break
			(row["slider"] as HSlider).value = 0.0
			await _frames(5)
		if raised:
			break
	await create_timer(0.3).timeout
	await _frames(10)
	lines = _pose.hold_words()
	var still: Array = _pose._joint_parts.filter(func(row: Dictionary) -> bool:
		return (row["droop"] as Label).visible)
	print("    raised on its slider: %s; %d rows marked" % [lines.replace("\n", " | "), still.size()])
	_check("...the arm raised 60° on its slider, the panel says the pose holds and the row's mark is gone",
		raised and lines.begins_with("Friction joints weighed: 2, and none droops.") and still.is_empty())


func _ready_to_grab() -> void:
	var grabbing: GrabDrag = _main.get("_grab_drag")
	for _n: int in 1200:
		if grabbing.is_ready():
			break
		await process_frame

func _at(what: String) -> void:
	print("    (%s, %d ms)" % [what, Time.get_ticks_msec() - _began])


func _check_stability() -> void:
	_shell.balance_shown = null
	_shell.run("stability")
	for _n: int in 900:
		await process_frame
		if not Working.is_busy() and _shell.balance_shown != null:
			break
	await _frames(5)


func _say(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	return text


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
