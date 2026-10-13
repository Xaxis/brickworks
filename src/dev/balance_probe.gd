## Balance against arrangements whose answers can be worked out by hand.
##
##   godot --headless --path . --script src/dev/balance_probe.gd
##
## A T on one stud, a staircase of plates whose tipping point is a line of
## arithmetic, a tower on a 1x1, a part hung under another, a long arm on a
## small base with the counterweight its advice asks for put on and weighed
## again, the shipped models standing, a turntable arm swept round to the
## pose where it tips, and check_design saying all of it. Exits non-zero
## when an answer is wrong.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder

const TO_CM := 0.04   ## N·LDU to N·cm


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_masses()
	await _t_on_one_stud()
	await _staircase()
	await _tower_on_a_1x1()
	await _hung_under()
	await _held_by_a_pin()
	await _long_arm()
	await _models_stand()
	await _swept_round()
	await _check_design_says_it()
	print("")
	if _failures == 0:
		print("balance: the margins, the joints and the counterweight come out as worked by hand, "
			+ "the shipped models stand, and the worst pose is found")
	else:
		print("balance: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## Masses from volume, against BrickLink's weights (2026-10-13).
func _masses() -> void:
	print("masses, against BrickLink's weights:")
	for pair: Array in [["3005", 0.44], ["3004", 0.83], ["3003", 1.35], ["3010", 1.64],
			["3001", 2.32], ["2456", 3.74], ["3008", 3.21]]:
		var info: PartLibrary.PartInfo = _library.parts.get(pair[0])
		var grams: float = Stability.grams(info)
		_check("%-5s %.2f g against %.2f (%+.0f%%)  %s" % [pair[0], grams, pair[1],
			(grams / float(pair[1]) - 1.0) * 100.0, info.name.strip_edges()],
			absf(grams / float(pair[1]) - 1.0) < 0.08)


# -- building ------------------------------------------------------------------


func _fresh() -> void:
	if _world != null:
		_world.queue_free()
		_builder.queue_free()
		await process_frame
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	await process_frame


## A part with the middle of its footprint at [param x], [param z] and the
## bottom of its body at [param bottom], LDU; long along x unless [param
## along_z]. Returns its id.
func _put(part_id: String, x: float, bottom: float, z: float, along_z: bool = false,
		unit: String = "") -> int:
	var part: Lbm.PartMesh = _library.mesh_for(part_id)
	var info: PartLibrary.PartInfo = _library.parts.get(part_id)
	var basis := Basis.IDENTITY
	var long_x: bool = info.size.x >= info.size.z
	if long_x == along_z:
		basis = Basis(Vector3.UP, PI * 0.5)
	var box: AABB = (Transform3D(basis, Vector3.ZERO) * part.bounds).abs()
	var middle: Vector3 = box.get_center()
	var at := Transform3D(basis, Vector3(roundf(x - middle.x), roundf(bottom - box.position.y),
		roundf(z - middle.z)))
	var id: int = _world.add_brick(part_id, 4, at)
	_builder.register(id, part_id, at)
	if not unit.is_empty():
		_world.get_brick(id).unit = unit
		_world.get_brick(id).group = Assemblies.group_of(unit)
	return id


## The top of a part's body, LDU: where the next thing stands.
func _top(id: int) -> float:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var box: AABB = (brick.transform * part.bounds).abs()
	return box.end.y - (4.0 if _library.parts[brick.part_id].stud_count > 0 else 0.0)


func _weigh(poses: Array = []) -> Balance.Report:
	var judge := Balance.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	return judge.measure(_world.bricks(), poses)


func _grams(part_id: String) -> float:
	return Stability.grams(_library.parts.get(part_id))


func _newtons(part_id: String) -> float:
	return _grams(part_id) / 1000.0 * Balance.GRAVITY


func _near(got: float, want: float, within: float) -> bool:
	return absf(got - want) <= within


# -- the cases -------------------------------------------------------------------


## A 1x1 brick carrying a 1x8 plate by its end stud. The plate's middle is
## 3.5 studs out and the stud's edge half a stud, so the joint carries the
## plate's weight on a 3 stud lever (24 mm), against one stud's 1 N half a
## stud (4 mm) from that edge: 0.4 N·cm. And the whole falls off its 1x1.
func _t_on_one_stud() -> void:
	print("a T on one stud: a 1x8 plate by its end stud on a 1x1 brick")
	await _fresh()
	var post: int = _put("3005", 0, 0, 0)
	_put("3460", 70, _top(post), 0)
	var report: Balance.Report = _weigh()
	var want_moment: float = _newtons("3460") * 60.0 * TO_CM
	var joint: Balance.JointLoad = report.joints[0] if not report.joints.is_empty() else null
	_check("one joint, the plate on the brick, on one stud (%s)" % (
		"none" if joint == null else "%s on %s, %d" % [joint.beyond_part, joint.held_part, joint.studs]),
		report.joints.size() == 1 and joint.beyond_part == "3460" and joint.studs == 1)
	if joint == null:
		return
	_check("its moment is the plate's weight on 3 studs: %.4f N·cm, by hand %.4f"
		% [joint.moment, want_moment], _near(joint.moment, want_moment, want_moment * 0.01))
	_check("...against 0.4 N·cm working and 1.2 letting go (%.3f, %.3f)" % [joint.capacity,
		joint.ultimate], _near(joint.capacity, 0.4, 0.001) and _near(joint.ultimate, 1.2, 0.001))
	var x: float = (_grams("3460") * 70.0) / (_grams("3460") + _grams("3005"))
	var want_margin: float = (10.0 - x) / 20.0
	_check("and the whole tips off its 1x1: %.3f studs past the right edge, by hand %.3f"
		% [-report.margin, -want_margin], _near(report.margin, want_margin, 0.005)
		and report.edge == "right" and not report.stands())


## A staircase of 2x4 plates, each a stud further out than the one under
## it. The centre of mass of n of them is (n - 1)/2 studs out and the
## bottom plate's edge 2, so it tips past 5: by hand 0.5 studs inside at 4,
## on the edge at 5, half a stud past at 6. (Two wide, so the side edges
## are a stud away and never the nearest.) The root joint of 6 carries the
## five above it, their middle 3 studs out, on an edge 2 studs out and a
## joint 3 studs long and 2 wide: 5W on 1 stud against 1 N on two rows of
## 2.5 + 1.5 + 0.5 studs.
func _staircase() -> void:
	print("a cantilever of n plates, each a stud further out")
	for n: int in [4, 5, 6]:
		await _fresh()
		for k: int in n:
			_put("3020", 20.0 * k, 8.0 * k, 0)
		var report: Balance.Report = _weigh()
		var want: float = 2.0 - (n - 1) * 0.5
		_check("%d plates: %.3f studs from the right edge, by hand %.1f" % [n, report.margin, want],
			_near(report.margin, want, 0.01) and report.edge == "right")
		if n == 6:
			var root: Balance.JointLoad = null
			for one: Balance.JointLoad in report.joints:
				if one.grams > _grams("3020") * 4.5:
					root = one
			var moment: float = 5.0 * _newtons("3020") * 20.0 * TO_CM
			var capacity: float = 2.0 * (50.0 + 30.0 + 10.0) * TO_CM
			_check("...its root joint carries the five above: %.4f N·cm against %.2f, by hand %.4f against %.2f"
				% [root.moment if root else -1.0, root.capacity if root else -1.0, moment, capacity],
				root != null and _near(root.moment, moment, moment * 0.01)
				and _near(root.capacity, capacity, 0.001) and root.studs == 6)
			_check("...%d joints, every one a bridge from the floor up" % report.joints.size(),
				report.joints.size() == 5)


## A tower of 2x2 bricks on one 1x1: half a stud to every edge, and the
## tilt that tips it is atan(half a stud over the height of its centre of
## mass), which a tall tower makes small.
func _tower_on_a_1x1() -> void:
	print("a tower of 2x2 bricks on a 1x1")
	await _fresh()
	var bottom: float = 0.0
	var mass: float = 0.0
	var moment: float = 0.0
	var parts: Array = ["3005", "3003", "3003", "3003", "3003", "3003", "3003"]
	for part_id: String in parts:
		var id: int = _put(part_id, 0, bottom, 0)
		var box: AABB = _library.mesh_for(part_id).bounds
		mass += _grams(part_id)
		moment += _grams(part_id) * (bottom + box.size.y * 0.5)
		bottom = _top(id)
	var report: Balance.Report = _weigh()
	var height: float = moment / mass
	var tilt: float = rad_to_deg(atan2(10.0, height))
	_check("half a stud to the nearest edge (%.3f)" % report.margin, _near(report.margin, 0.5, 0.001))
	_check("force angle %.2f°, by hand atan(10 / %.1f) = %.2f°" % [report.tilt, height, tilt],
		_near(report.tilt, tilt, 0.05))
	var foot: Balance.JointLoad = report.joints[report.joints.size() - 1] if not report.joints.is_empty() else null
	for one: Balance.JointLoad in report.joints:
		if one.held_part == "3005":
			foot = one
	_check("its foot carries the whole tower straight down: no moment (%.5f N·cm)" % (
		foot.moment if foot else -1.0), foot != null and foot.moment < 0.00001)


## A 1x1 brick pressed up under the end of a plate: held by its own stud,
## pulled straight off it by its weight, and levered about the stud's edge
## half a stud away.
func _hung_under() -> void:
	print("a 1x1 brick hung under the end of a plate")
	await _fresh()
	var low: int = _put("3005", 0, 0, 0)
	var high: int = _put("3005", 0, _top(low), 0)
	var plate: int = _put("3710", 0, _top(high), 0)
	var plate_bottom: float = _world.get_brick(plate).transform.origin.y - 8.0
	_put("3005", 30, plate_bottom - 24.0, 0)
	var report: Balance.Report = _weigh()
	var hung: Balance.JointLoad = null
	for one: Balance.JointLoad in report.joints:
		if one.hangs:
			hung = one
	var weight: float = _newtons("3005")
	_check("it hangs, pulled %.5f N, by hand its weight %.5f" % [hung.pull if hung else -1.0, weight],
		hung != null and _near(hung.pull, weight, weight * 0.01) and hung.beyond_part == "3005")
	if hung != null:
		_check("...levered on half a stud: %.5f N·cm, by hand %.5f, against 0.4" % [hung.moment,
			weight * 10.0 * TO_CM], _near(hung.moment, weight * 10.0 * TO_CM, 0.00002)
			and _near(hung.capacity, 0.4, 0.001))


## A part held by something that is not studs — a pin, a clip, a hinge —
## is carried by the stud joint under what holds it. Two 1x1 bricks
## stacked, and a 2x2 standing clear of them joined to the top one only as
## a pin would join it: the foot carries all three, and nothing is adrift.
## Without the link, the 2x2 is adrift and the foot carries one brick.
func _held_by_a_pin() -> void:
	print("a part held by a pin, not studs")
	await _fresh()
	var low: int = _put("3005", 0, 0, 0)
	var high: int = _put("3005", 0, _top(low), 0)
	var aside: int = _put("3003", 60, 30, 0)
	var judge := Balance.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	var alone: Balance.Report = judge.measure(_world.bricks(), [], [])
	var pinned: Balance.Report = judge.measure(_world.bricks(), [], [[high, aside], [aside, high]])
	var foot: Balance.JointLoad = pinned.joints[0] if not pinned.joints.is_empty() else null
	var want: float = _grams("3005") + _grams("3003")
	_check("unlinked it is adrift (%d), linked it is not (%d)" % [alone.adrift, pinned.adrift],
		alone.adrift == 1 and pinned.adrift == 0)
	_check("...and the foot carries it: %.2f g, by hand %.2f" % [foot.grams if foot else -1.0,
		want], foot != null and _near(foot.grams, want, 0.001) and foot.held_by == low)


## An arm reaching 18 studs past a 6x6 base: it tips. The advice says how
## much to add and where; added, as 2x4 bricks stacked there, it stands.
func _long_arm() -> void:
	print("a long arm on a small base, and the counterweight its advice asks for")
	await _fresh()
	var base: int = _put("3958", 0, 0, 0)
	var top: float = _top(base)
	var column: int = 0
	for _n: int in 4:
		column = _put("3003", 40, top, 0)
		top = _top(column)
	# Two courses of 2x8 plates, each across the joint below: a bonded arm
	# out to x = 21 studs, 18 past the base's edge at 3.
	_put("3034", 100, top, 0)
	_put("3034", 260, top, 0)
	_put("3034", 180, top + 8.0, 0)
	_put("3034", 340, top + 8.0, 0)
	var report: Balance.Report = _weigh()
	_check("it tips, %s studs past the %s edge" % [Balance.studs(-report.margin), report.edge],
		report.margin < 0.0 and report.edge == "right")
	_check("...and Stability, which the status bar reads, says so too (%s)" % _verdict(),
		_verdict().contains("tips"))
	_check("...and says what would hold it: %d g %s, at x=%s, or %d studs wider" % [
		ceili(report.counterweight), report.counterweight_where,
		Balance.studs(report.counterweight_at.x / 20.0), report.widen],
		report.counterweight > 0.0 and report.counterweight_where.contains("left")
		and report.widen == ceili(0.5 - report.margin))
	var lever: float = (60.0 - report.counterweight_at.x) / 20.0
	var by_hand: float = report.grams * (-report.margin + 0.5) / (lever - 0.5)
	_check("...w·L ≥ m·d by hand: %.1f g at %.1f studs in for %.1f g %.2f studs out (said %.1f)"
		% [by_hand, lever, report.grams, -report.margin, report.counterweight],
		_near(report.counterweight, by_hand, 0.1))
	print("    %s" % report.words())
	# Done as it says: 2x4 bricks, as many as weigh that, stacked there.
	var each: float = _grams("3001")
	var bricks: int = ceili(report.counterweight / each)
	var at: Vector2 = report.counterweight_at
	var stack: float = _top(base)
	for _n: int in bricks:
		stack = _top(_put("3001", roundf(at.x / 20.0) * 20.0, stack, roundf(at.y / 20.0) * 20.0))
	var after: Balance.Report = _weigh()
	_check("with %d 2x4 bricks stacked there (%.1f g) it stands, %.2f studs inside the %s edge"
		% [bricks, bricks * each, after.margin, after.edge],
		after.stands() and after.margin >= Balance.SPARE - 0.02 and after.counterweight == 0.0)
	_check("...and Stability no longer says it tips (%s)" % _verdict(), not _verdict().contains("tips"))


## Stability's summary of the model as it stands: the status bar's words.
func _verdict() -> String:
	var judge := Stability.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	return judge.check(_world).summary()


## The models that ship stand on what they stand on.
func _models_stand() -> void:
	print("the shipped models")
	for name: String in ["house.ldr", "car.ldr", "lighthouse.ldr", "castle.ldr", "kart.ldr"]:
		await _fresh()
		var ldr: LdrModel = LdrModel.load_file("res://models/" + name)
		for piece: LdrModel.Placement in ldr.flatten():
			var part_id: String = piece.part_id.to_lower().trim_suffix(".dat")
			if _library.mesh_for(part_id) == null:
				continue
			var id: int = _world.add_brick(part_id, piece.color_code, piece.transform)
			if id != 0:
				_builder.register(id, part_id, piece.transform)
		var began: int = Time.get_ticks_msec()
		var report: Balance.Report = _weigh()
		_check("%-15s stands, %s studs inside the %s edge, %.0f g, %d bridge joints, the worst at %.2f of its working load (%d ms)"
			% [name, Balance.studs(report.margin), report.edge, report.grams, report.joints.size(),
				report.joints[0].ratio if not report.joints.is_empty() else 0.0,
				Time.get_ticks_msec() - began], report.stands() and not _verdict().contains("tips"))


## A 2x8 arm on a turntable over a long narrow base: it stands as built,
## along the base, and tips swung across it. Every joint swung through its
## reach (Poser.sweep), and the Pose panel's animation, find that pose.
func _swept_round() -> void:
	print("an arm on a turntable, swept round")
	await _fresh()
	var base: int = _put("3034", 0, 0, 0)
	_put("3680", 0, _top(base), 0)
	var turn_top: int = _put("3679", 0, _top(base), 0, false, "Arm#1")
	var arm: int = _put("3034", 60, _top(turn_top), 0, false, "Arm#1")
	_put("3003", 120, _top(arm), 0, false, "Arm#1")
	var arm_at: Transform3D = _world.get_brick(arm).transform
	var assemblies := Assemblies.new()
	assemblies.world = _world
	assemblies.builder = _builder
	assemblies.library = _library
	var poser := Poser.new()
	poser.world = _world
	poser.builder = _builder
	poser.library = _library
	poser.assemblies = assemblies
	var found: int = poser.find()
	_check("the arm turns on the turntable (%d joint%s, %s)" % [found, "" if found == 1 else "s",
		poser.joints[0].kind() if found > 0 else "none"], found == 1
		and poser.joints[0].kind() == "turntable")
	if found == 0:
		return
	var still: Balance.Report = _weigh()
	_check("as built, along the base, it stands (%s studs)" % Balance.studs(still.margin),
		still.stands())
	# The turntable's top holds by the turntable, not by studs: Joints says
	# so, and the graph reads it.
	var judge := Balance.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	judge.measure(_world.bricks())
	var linked: bool = judge._links().any(func(pair: Array) -> bool:
		return int(pair[0]) == turn_top and _world.get_brick(int(pair[1])).part_id == "3680")
	_check("the turntable's top is joined to its base by the turntable (Joints.rounds)", linked)
	var poses: Array = poser.sweep()
	var swept: Balance.Report = _weigh(poses)
	_check("swept round, %d poses: it tips, %s studs past the %s edge, at worst %s" % [
		swept.poses + 1, Balance.studs(-swept.margin), swept.edge, swept.worst_pose],
		swept.poses == 23 and not swept.stands() and swept.worst_pose.begins_with("Arm at ")
		and (swept.worst_pose.ends_with(" 90°") or swept.worst_pose.ends_with(" -90°"))
		and (swept.edge == "front" or swept.edge == "back"))
	_check("...as it stands it still reads %s studs inside" % Balance.studs(swept.rest_margin),
		_near(swept.rest_margin, still.margin, 0.001))
	# In the middle of a base two studs wide, a stud from the edge it tips
	# over: w·1 ≥ m·d with half a stud to spare is w = m (1 + 2d).
	var middle: float = swept.grams * (1.0 - 2.0 * swept.margin)
	_check("...and the counterweight that holds every pose goes in the middle of the base: %.2f g, by hand %.2f (%s)"
		% [swept.counterweight, middle, swept.counterweight_where],
		swept.counterweight_where == "in the middle of the base"
		and _near(swept.counterweight, middle, middle * 0.02))
	var animation := PoseAnimation.new()
	animation.add_key(0.0, {"Arm#1": 0.0})
	animation.add_key(1.0, {"Arm#1": 90.0})
	var keyed: Balance.Report = _weigh(poser.sweep(animation))
	_check("the Pose panel's animation, 0° to 90° in a second: %d frames, worst %s" % [
		keyed.poses, keyed.worst_pose], keyed.poses == animation.frame_count()
		and keyed.worst_pose == "the animation at 1.00 s" and not keyed.stands())
	_check("...and nothing in the model moved", _world.get_brick(arm).transform.is_equal_approx(
		arm_at) and poser.holds())


## check_design (Assistant._check, weighing) carries the same numbers.
func _check_design_says_it() -> void:
	print("check_design")
	await _fresh()
	var assistant := Assistant.new()
	assistant.library = _library
	assistant.world = _world
	assistant.builder = _builder
	get_root().add_child(assistant)
	await process_frame
	var model := Assistant.Model.new()
	# The staircase of six, in a design's own coordinates: studs and plates.
	for k: int in 6:
		model.placements.append(Assistant.Placement.from_dict(
			{"part": "3020", "color": 4, "x": k, "y": k, "z": 0}))
	var report: Dictionary = assistant._check(model, false, true)
	var balance: Balance.Report = report.get("balance")
	var namer: Callable = func(id: int) -> String: return "brick %d" % (id - 1)
	var said: String = balance.said(namer) if balance != null else ""
	print("    " + said.replace("\n", "\n    "))
	_check("it says it tips, by how much and where",
		said.contains("TIPS OVER") and said.contains("0.5 studs past the right edge"))
	_check("...what to add, and where", said.contains("add at least") and said.contains("g ("))
	_check("...and the three most loaded joints, by the design's own numbers",
		said.contains("Most loaded stud joints") and said.contains("brick 1 on brick 0"))
	var unweighed: Dictionary = assistant._check(model)
	_check("a check that does not ask is not weighed", not unweighed.has("balance"))
	assistant.queue_free()
