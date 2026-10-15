## Can a session build a gear train that turns, through the tools it has?
##
##   godot --headless --path . --script src/dev/axle_probe.gd
##
## The owner's Claude, building an orrery over MCP, asked them whether to
## "add axle-in-hole support to Brickworks next so I can put the real gear
## train in the drum". It could not put one in:
##
##   - attachment_points said 3700 at 80, 0, 80 has a pin hole at 81, 1.75,
##     80.5 running along z, and that "a pin goes in at the position given".
##     A 2780 written there, then an axle 3706, then an axle through a 40
##     tooth gear's hole, by a quarter turn and by face +z: every one "Not
##     applied", overlapping the part it was meant to be in. A placement's
##     x, y and z were its low corner, not the point a hole is said by.
##   - An axle was held only by holes within a stud of its tips, so a gear
##     in the middle of one was not on it.
##   - Two gears in mesh share the ring their teeth turn in, and each one's
##     cover is a disc: every gear train was an overlap. A session asked for
##     an 8 driving a 24 ran a chain between them instead.
##
## Each is driven here through the tools a session calls (use_tool), with
## the numbers those tools hand back, and then the parts are asked what
## turns with what (Mechanism) and how fast.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant


func _initialize() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	get_root().add_child(_assistant)
	await process_frame

	await _the_owners_pin()
	await _an_axle_through_a_forty()
	await _the_gear_train()
	await _the_orrery_steps()
	_by_hand()

	print("")
	if _failures == 0:
		print("axles: a pin and an axle go in the hole attachment_points names, an axle "
			+ "carries every part on its line, gears in mesh are not an overlap, and a "
			+ "crank turns an 8, a 24 and an arm at 1:3")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _clear() -> void:
	_assistant.clear_built()
	_world.clear()
	_builder.lattice.clear()


## A tool's answer as one line of text.
func _say(tool: String, input: Dictionary) -> String:
	var answer: Variant = await _assistant.use_tool(tool, input)
	var text: String = ""
	if answer is Array:
		for block: Variant in answer:
			if block is Dictionary and (block as Dictionary).get("type", "") == "text":
				text += str((block as Dictionary)["text"])
	else:
		text = str(answer)
	return text.replace("\n", " / ")


func _bricks_of(part: String) -> Array[BrickWorld.Brick]:
	var out: Array[BrickWorld.Brick] = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			out.append(brick)
	return out


## Where a pin's or an axle's line runs, standing as it stands: [middle,
## way]. Both are drawn about their middle, along their own x.
static func _line_of(brick: BrickWorld.Brick) -> Array:
	return [brick.transform.origin, (brick.transform.basis * Vector3.RIGHT).normalized()]


# -- the owner's own session ---------------------------------------------------


## The sequence the owner's session ran, with its own numbers.
func _the_owners_pin() -> void:
	print("\nthe owner's pin and axle in 3700's hole, at the point attachment_points gives")
	_clear()
	var said: String = await _say("attachment_points", {"part": "3700", "x": 80, "y": 0,
		"z": 80})
	_ok(said.contains("x=81 y=1.75 z=80.50") and said.contains("running along z"),
		"attachment_points: 3700 at 80, 0, 80 has its hole at 81, 1.75, 80.5 along z: %s"
			% said.left(400))
	var hole := Vector3(81 * 20.0, 1.75 * 8.0, 80.5 * 20.0)

	var tries: Array = [
		["2780 by a quarter turn", {"part": "2780", "color": 0, "x": 81, "y": 1.75,
			"z": 80.5, "rot": 1}],
		["2780 by face +z", {"part": "2780", "color": 0, "x": 81, "y": 1.75, "z": 80.5,
			"face": "+z", "rot": 0}],
		["2780 by its axis", {"part": "2780", "color": 0, "x": 81, "y": 1.75, "z": 80.5,
			"rot": 0, "axis": "z"}],
		["axle 3706 by a quarter turn", {"part": "3706", "color": 0, "x": 81, "y": 1.75,
			"z": 80.5, "rot": 1}],
		["axle 3706 by its axis", {"part": "3706", "color": 0, "x": 81, "y": 1.75,
			"z": 80.5, "rot": 0, "axis": "z"}],
	]
	for one: Array in tries:
		_clear()
		var brick: Dictionary = {"part": "3700", "color": 71, "x": 80, "y": 0, "z": 80,
			"rot": 0}
		said = await _say("edit_model", {"add": [brick, one[1]]})
		var part: String = str(one[1]["part"])
		var them: Array[BrickWorld.Brick] = _bricks_of(part)
		var line: Array = _line_of(them[0]) if not them.is_empty() else [Vector3.INF, Vector3.ZERO]
		# A pin two studs long goes half into a hole a stud deep, its collar at
		# the hole's mouth: put by its middle at the hole's, it is slid along its
		# line until it is, since by the parts' real shapes (ExactCheck) the
		# collar is wider than the bore. An axle runs on through.
		var off: Vector3 = (line[0] as Vector3) - hole
		var at_mouth: bool = Vector2(off.x, off.y).length() < 1.01 \
			and (absf(absf(off.z) - 10.0) < 1.01 if part == "2780" else absf(off.z) < 1.01)
		_ok(not said.begins_with("Not applied") and them.size() == 1 and at_mouth
			and absf((line[1] as Vector3).z) > 0.99,
			"edit_model, %s at 81, 1.75, 80.5: in the hole, along z%s (%s; middle %s): %s"
				% [one[0], ", its collar at the mouth" if part == "2780" else "",
					"applied" if them.size() == 1 else "refused", line[0], said.left(300)])

	# And submit_design, the other way a design lands.
	_clear()
	said = await _say("submit_design", {"name": "pin", "description": "a pin in a brick",
		"bricks": [{"part": "3700", "color": 71, "x": 80, "y": 0, "z": 80, "rot": 0},
			{"part": "2780", "color": 0, "x": 81, "y": 1.75, "z": 80.5, "rot": 1}]})
	_ok(said.begins_with("Built") and _bricks_of("2780").size() == 1,
		"submit_design takes the same pin: %s" % said.left(200))

	# Forgiving the joint forgives only the joint: the same pin by its axis
	# half a stud along, where the brick is solid, still overlaps it.
	_clear()
	said = await _say("check_design", {"bricks": [
		{"part": "3700", "color": 71, "x": 80, "y": 0, "z": 80, "rot": 0},
		{"part": "2780", "color": 0, "x": 80.5, "y": 1.75, "z": 80.5, "rot": 0, "axis": "z"}]})
	_ok(said.contains("overlap"),
		"...and the same pin half a stud along, in the brick's wall, still overlaps: %s"
			% said.left(200))


## An axle through a 40 tooth gear, at the point attachment_points gives
## its hole, and through the brick the gear stands beside.
func _an_axle_through_a_forty() -> void:
	print("\nan axle through a 40 tooth gear's hole, where attachment_points says it is")
	_clear()
	# A 3700 two bricks up, so a gear 5.2 studs across clears the ground: its
	# hole at 81, 7.75, 80.5 along z, and the gear beside it, behind.
	var stand: Array = [
		{"part": "3004", "color": 71, "x": 80, "y": 0, "z": 80, "rot": 0},
		{"part": "3004", "color": 71, "x": 80, "y": 3, "z": 80, "rot": 0},
		{"part": "3700", "color": 71, "x": 80, "y": 6, "z": 80, "rot": 0}]
	# The gear considered where it would stand, by its corner, behind the
	# brick and on its hole's line: asked of attachment_points, as the owner's
	# session asked it.
	var gear: Dictionary = {"part": "3649", "color": 71, "x": 78.4, "y": 1.25, "z": 81,
		"rot": 0}
	var said: String = await _say("attachment_points", gear)
	var found := RegEx.create_from_string("joint 0: axle hole at x=([0-9.]+) y=([0-9.]+) "
		+ "z=([0-9.]+), running along z").search(said)
	_ok(found != null, "attachment_points lists its axle hole along z: %s" % said.left(300))
	if found == null:
		return
	var at := Vector3(found.get_string(1).to_float(), found.get_string(2).to_float(),
		found.get_string(3).to_float())
	_ok(at.is_equal_approx(Vector3(81, 7.75, 81.5)), "...at 81, 7.75, 81.5: %s" % at)
	_ok(said.contains("grips an axle"), "...and says it grips an axle")
	# The owner's way: the axle's x, y, z at that point, a quarter turn.
	var all: Array = stand.duplicate()
	all.append(gear)
	all.append({"part": "3706", "color": 0, "x": at.x, "y": at.y, "z": at.z, "rot": 1})
	said = await _say("edit_model", {"add": all})
	var axles: Array[BrickWorld.Brick] = _bricks_of("3706")
	var gears: Array[BrickWorld.Brick] = _bricks_of("3649")
	_ok(not said.begins_with("Not applied") and axles.size() == 1 and gears.size() == 1,
		"the gear and an axle 6 at its hole's point go in: %s" % said.left(300))
	if axles.is_empty() or gears.is_empty():
		return
	var through: Array = _through_world()
	_ok(_has(through, axles[0].id, gears[0].id, "grips"), "...it grips the gear")
	var brick: int = _bricks_of("3700")[0].id
	_ok(_has(through, axles[0].id, brick, "turns"), "...and turns in the brick's round hole")


func _through_world() -> Array:
	var entries: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		entries.append([brick.id, brick.transform, _library.mesh_for(brick.part_id),
			brick.part_id])
	return Joints.through(entries)


static func _has(through: Array, shaft: int, holder: int, how: String) -> bool:
	for one: Array in through:
		if int(one[0]) == shaft and int(one[1]) == holder and str(one[2]) == how:
			return true
	return false


# -- the brief: a hand-cranked gear train ---------------------------------------


## A frame of two Technic bricks with holes (3702) on bricks on a plate; a
## crank on an axle turns an 8, which drives a 24 two studs along on a
## second axle, which turns an arm. Every part said by its axis at the
## points the frame's holes are at.
func _train_bricks() -> Array:
	# The frame. 3702 at x 1 has its holes at x 2..8, 1.75 plates up, along
	# z: at y 5.75, z 0.5 at the front and 5.5 at the back.
	var y: float = 5.75
	var bricks: Array = [
		{"part": "3033", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3008", "color": 71, "x": 1, "y": 1, "z": 0, "rot": 0},
		{"part": "3008", "color": 71, "x": 1, "y": 1, "z": 5, "rot": 0},
		{"part": "3702", "color": 0, "x": 1, "y": 4, "z": 0, "rot": 0},
		{"part": "3702", "color": 0, "x": 1, "y": 4, "z": 5, "rot": 0},
		# The crank's axle at x 3, 8 long, from z -1.5 to 6.5.
		{"part": "3707", "color": 0, "x": 3, "y": y, "z": 2.5, "rot": 0, "axis": "z"},
		# The 8 on it between the walls, and a 24 on the second axle two studs
		# along: 1.25 LDU a tooth, (8 + 24) x 1.25 = 40 = 2 studs.
		{"part": "3647", "color": 72, "x": 3, "y": y, "z": 2.5, "rot": 0, "axis": "z"},
		{"part": "3707", "color": 0, "x": 5, "y": y, "z": 3.5, "rot": 0, "axis": "z"},
		{"part": "3648b", "color": 72, "x": 5, "y": y, "z": 2.5, "rot": 0, "axis": "z"},
		# A bush against the front wall, and a half bush behind the back one,
		# hold the crank's axle from sliding.
		{"part": "3713", "color": 71, "x": 3, "y": y, "z": -0.5, "rot": 0, "axis": "z"},
		{"part": "4265c", "color": 71, "x": 3, "y": y, "z": 6.25, "rot": 0, "axis": "z"},
		# The crank: a liftarm by its end axle hole on the axle's front tip,
		# pointing up, and a handle in its other end.
		{"part": "6632", "color": 4, "x": 3, "y": y, "z": -1.25, "rot": 0, "axis": "z",
			"joint": 0},
		# The arm: the same liftarm on the second axle's back end.
		{"part": "6632", "color": 14, "x": 5, "y": y, "z": 7.25, "rot": 0, "axis": "z",
			"joint": 0},
	]
	return bricks


func _the_gear_train() -> void:
	print("\na crank on an axle turns an 8, which drives a 24 on a second axle, which turns "
		+ "an arm")
	_clear()
	var bricks: Array = _train_bricks()
	# The handle goes in the crank's other axle hole, wherever its turn put
	# it: asked of attachment_points, as a session would.
	var crank: Dictionary = bricks[11]
	var said: String = await _say("attachment_points", crank)
	var found := RegEx.create_from_string("joint 1: axle hole at x=([-0-9.]+) y=([-0-9.]+) "
		+ "z=([-0-9.]+), running along z").search(said)
	_ok(found != null, "attachment_points gives the crank's other end: %s" % said.left(400))
	if found == null:
		return
	bricks.append({"part": "4519", "color": 0, "x": found.get_string(1).to_float(),
		"y": found.get_string(2).to_float(), "z": found.get_string(3).to_float() - 1.25,
		"rot": 0, "axis": "z"})
	said = await _say("check_design", {"bricks": bricks})
	_ok(said.contains("buildable") and not said.contains("overlap")
		and not said.contains("floating"),
		"check_design: every part held, nothing collides: %s" % said.left(600))
	# The same train by its corners, as the axes were read: for checking the
	# joints and the meshes on their own, against code that has no axis.
	var corners: Array = []
	for placement: Assistant.Placement in _assistant._read_model({"bricks": bricks}).placements:
		corners.append({"part": placement.part, "color": placement.color, "x": placement.x,
			"y": placement.y, "z": placement.z, "face": placement.face, "rot": placement.rot})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/axles"))
	var kept: FileAccess = FileAccess.open("res://shots/axles/train_corners.json",
		FileAccess.WRITE)
	if kept != null:
		kept.store_string(JSON.stringify(corners))
		kept.close()
	_ok(said.contains("meshes") and said.contains("an 8 with a 24"),
		"...and it says the 8 meshes the 24: %s" % _from(said, "What turns"))
	said = await _say("submit_design", {"name": "gear train", "description": "a crank, "
		+ "an 8, a 24 and an arm", "bricks": bricks})
	_ok(said.begins_with("Built"), "submit_design builds it: %s" % said.left(200))

	# What turns with what, read off the parts as they stand.
	var list: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		list.append({"key": brick.id, "part": brick.part_id, "at": brick.transform,
			"mesh": _library.mesh_for(brick.part_id)})
	var plate: int = _bricks_of("3033")[0].id
	var model: Mechanism = Mechanism.build(list, [plate])
	var axle_a: int = 0
	var axle_b: int = 0
	for brick: BrickWorld.Brick in _bricks_of("3707"):
		if absf(brick.transform.origin.x - 60.0) < 5.0:
			axle_a = brick.id
		else:
			axle_b = brick.id
	var crank_body: int = model.body_of(axle_a)
	var arm_body: int = model.body_of(axle_b)
	print("     %s" % model.summary())
	var solved: Dictionary = model.solve({crank_body: 1.0})
	var arm: float = model.spin(arm_body, model.joint_axis(crank_body))
	_ok(bool(solved.get("ok", false)) and is_equal_approx(snappedf(arm, 0.000001), -0.333333),
		"turning the crank once turns the arm a third of a turn the other way (%.6f): %s"
			% [arm, solved.get("said", "")])
	var handle: int = _bricks_of("4519")[0].id
	var arms: Array[BrickWorld.Brick] = _bricks_of("6632")
	_ok(model.body_of(handle) == crank_body and model.body_of(_bricks_of("3647")[0].id)
		== crank_body and model.body_of(_bricks_of("3713")[0].id) == crank_body,
		"the handle, the 8 and the bush turn with the crank's axle")
	_ok(model.body_of(_bricks_of("3648b")[0].id) == arm_body
		and (model.body_of(arms[0].id) == arm_body or model.body_of(arms[1].id) == arm_body),
		"the 24 and the arm turn with the second axle")
	_ok(model.body_of(_bricks_of("3702")[0].id) == model.ground,
		"the frame stands still")
	await _draw(model, crank_body, arm_body, _bricks_of("6632"))

	# Too near: a 24 in the 8's place, two studs from the other 24. Refused,
	# with the spacing they mesh at.
	var near: Array = _train_bricks()
	near[6]["part"] = "3648b"
	said = await _say("check_design", {"bricks": near})
	_ok(said.contains("overlap") and said.contains("60 LDU (3 studs) apart"),
		"two 24s two studs apart overlap, and are told they mesh 3 studs apart: %s"
			% _from(said, "overlap"))
	# Too far, nearly: a 20 in the 24's place. Not an overlap, but said.
	var far: Array = _train_bricks()
	far[8]["part"] = "69779"
	said = await _say("check_design", {"bricks": far})
	_ok(not said.contains("overlap") and said.contains("do not mesh")
		and said.contains("35 LDU"),
		"an 8 and a 20 two studs apart do not overlap, and are told they mesh at 35 LDU: %s"
			% _from(said, "What turns"))


## The train drawn turning, sixteen frames of a sixteenth of a crank's turn,
## each frame's arm read back off the renderer's copy: a third of the
## crank's step, the other way. In shots/axles/. Headless, nothing drawn.
func _draw(model: Mechanism, crank: int, arm: int, arms: Array[BrickWorld.Brick]) -> void:
	if not StudioRender.possible():
		print("     (headless: nothing drawn)")
		return
	var renderer := StudioRender.new()
	root.add_child(renderer)
	renderer.library = _library
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = Vector2i(640, 480)
	settings.contact_shadow = false
	settings.view = "hero"
	var frames: int = 16
	var step: float = TAU / float(frames)
	var poses: Array = []
	for n: int in frames:
		poses.append(model.pose(step * float(n)))
	var box := AABB()
	for brick: BrickWorld.Brick in _world.bricks():
		var here: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		box = here if box.size == Vector3.ZERO else box.merge(here)
	box = box.grow(30.0)
	var watched: Array = [_bricks_of("4519")[0].id, arms[0].id if model.body_of(arms[0].id)
		== arm else arms[1].id]
	var axis: Vector3 = model.joint_axis(crank)
	var seen: Array = []
	var pictures: Array = []
	var done: int = await renderer.animate(_world, settings, frames,
		func(n: int) -> Dictionary: return poses[n],
		func(_n: int) -> float: return 0.0, box,
		func(_n: int, image: Image) -> void:
			var angles: Array = []
			for key: int in watched:
				var turned: Basis = renderer.staged_transform(key).basis \
					* (model.rest[key] as Transform3D).basis.inverse()
				angles.append(_about(turned, axis))
			seen.append(angles)
			pictures.append(image))
	_ok(done == frames, "drawn turning: %d frames of %d" % [done, frames])
	var worst: float = 0.0
	for n: int in range(1, seen.size()):
		var a: float = wrapf(float(seen[n][0]) - float(seen[n - 1][0]), -180.0, 180.0)
		var b: float = wrapf(float(seen[n][1]) - float(seen[n - 1][1]), -180.0, 180.0)
		worst = maxf(worst, absf(b + a / 3.0))
	_ok(seen.size() == frames and worst < 0.01,
		"in every frame drawn the arm turns a third of the crank's step the other way, "
			+ "to %.4f degrees" % worst)
	var folder: String = ProjectSettings.globalize_path("res://shots/axles")
	DirAccess.make_dir_recursive_absolute(folder)
	var webp := AnimatedWebP.new(8)
	for n: int in pictures.size():
		(pictures[n] as Image).save_png(folder.path_join("train_%02d.png" % n))
		webp.add(pictures[n])
	var file: FileAccess = FileAccess.open(folder.path_join("train.webp"), FileAccess.WRITE)
	if file != null:
		file.store_buffer(webp.bytes())
		file.close()
	print("     pictures: shots/axles/train_00..%02d.png and train.webp" % (pictures.size() - 1))
	renderer.queue_free()
	await process_frame


## A turn's angle about an axis, degrees.
static func _about(turn: Basis, axis: Vector3) -> float:
	var across: Vector3 = (Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).cross(
		axis).normalized()
	var turned: Vector3 = turn * across
	return rad_to_deg(atan2(axis.dot(across.cross(turned)), across.dot(turned)))


## The text from where [param word] first is.
static func _from(said: String, word: String) -> String:
	var at: int = said.find(word)
	return said.substr(maxi(at, 0), 400)


# -- the owner's next steps --------------------------------------------------------


## What the owner's orrery needs next: a worm on a crank driving a
## turntable, two 40s in mesh five studs apart, a 20 pinion, and an idler.
## Each seats, holds and meshes, and turns as its teeth say.
##
## The stages, in a frame of two 1 x 16 walls with holes (3703) whose holes
## are at y 8.75, z 0.5 and 5.5, every stud along x:
##   A, x 3: a 40 at z 1.5, driven.
##   B, x 8: a 40 at z 1.5 (40 + 40 teeth, 100 LDU, 5 studs), a 24 at z 2.5
##     and a 20 at z 3.5.
##   I, x 10: an 8 at z 2.5, the idler, on an axle 4 from the back wall that
##     stops short of B's 40, whose teeth reach past x 10.
##   C, x 12: a 24 at z 2.5, turned by B's 24 through the idler.
##   D, x 6: a 12 at z 3.5, 2 studs from B's 20 (20 + 12 teeth, 40 LDU), on
##     an axle 3 from the back wall.
func _stage_bricks() -> Array:
	var y: float = 8.75
	var bricks: Array = [
		{"part": "3036", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3036", "color": 72, "x": 8, "y": 0, "z": 0, "rot": 0},
	]
	for z: float in [0.0, 5.0]:
		for course: float in [1.0, 4.0, 7.0]:
			bricks.append({"part": "3703", "color": 71 if course < 7.0 else 0, "x": 0,
				"y": course, "z": z, "rot": 0})
	for one: Array in [["3706", 3, 3], ["3706", 8, 3], ["3705", 10, 4], ["3706", 12, 3],
			["4519", 6, 4.5], ["3649", 3, 1.5], ["3649", 8, 1.5], ["3648b", 8, 2.5],
			["69779", 8, 3.5], ["3647", 10, 2.5], ["3648b", 12, 2.5], ["69778", 6, 3.5]]:
		bricks.append({"part": one[0], "color": 0 if one[0] in ["3706", "3705", "4519"] else 72,
			"x": one[1], "y": y, "z": one[2], "rot": 0, "axis": "z"})
	return bricks


func _the_orrery_steps() -> void:
	print("\nthe orrery's next steps: 40 with 40 five studs apart, a 20 pinion, an idler, "
		+ "a worm into a turntable")
	_clear()
	var bricks: Array = _stage_bricks()
	var said: String = await _say("check_design", {"bricks": bricks})
	_ok(said.contains("buildable") and not said.contains("overlap")
		and not said.contains("floating"),
		"every part held, none collides: %s" % said.left(500))
	_ok(said.count("meshes") == 4, "...and four meshes said: %s" % _from(said, "What turns"))
	said = await _say("submit_design", {"name": "stages", "description": "an orrery's stages",
		"bricks": bricks})
	_ok(said.begins_with("Built"), "submit_design builds it: %s" % said.left(200))
	var model: Mechanism = _mechanism_of(_bricks_of("3036")[0].id)
	var body: Dictionary = {}   ## axle's x in studs -> its body
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id in ["3706", "3705", "4519"]:
			body[roundi(brick.transform.origin.x / 20.0)] = model.body_of(brick.id)
	var solved: Dictionary = model.solve({body.get(3, 0): 1.0})
	var axis: Vector3 = model.joint_axis(body.get(3, 0))
	var rates: Dictionary = {}
	for x: int in body:
		rates[x] = snappedf(model.spin(body[x], axis), 0.000001)
	_ok(bool(solved.get("ok", false)) and is_equal_approx(rates.get(8, 0.0), -1.0),
		"40 to 40, five studs apart: B turns once, the other way (%s)" % rates.get(8))
	_ok(is_equal_approx(rates.get(10, 0.0), 3.0) and is_equal_approx(rates.get(12, 0.0), -1.0),
		"24 to the 8 idler to a 24: the idler turns 3 times, C as B does (%s, %s)"
			% [rates.get(10), rates.get(12)])
	_ok(is_equal_approx(rates.get(6, 0.0), snappedf(20.0 / 12.0, 0.000001)),
		"the 20 pinion turns a 12 20/12 times B's, the other way (%s)" % rates.get(6))

	# A worm on a crank's axle, driving a turntable's 28 teeth.
	_clear()
	var table: Array = await _worm_and_turntable()
	if table.is_empty():
		return
	said = await _say("check_design", {"bricks": table})
	# The base stands three quarters of a stud off the plate's studs, so the
	# worm 45 LDU behind its axis is on a stud's line: by the parts' real
	# shapes (ExactCheck) the studs under it are in its solid, which the
	# lattice let it rest on. Said as that, with the turntable named.
	_ok(said.contains("collision") and said.contains("99009") and said.contains("stud"),
		"a worm into a turntable whose base is off the plate's studs: named: %s" % said.left(500))
	_ok(said.contains("a worm with a 28") or said.contains("a 28 with a worm"),
		"...and meshes its 28 teeth: %s" % _from(said, "What turns"))
	# Built as it is, unchecked, for what the mechanism makes of it.
	await _assistant._apply(_assistant._read_model({"name": "worm", "bricks": table}))
	if _bricks_of("4716").is_empty() or _bricks_of("99010").is_empty():
		_ok(false, "the worm and the turntable are built: %s" % said.left(300))
		return
	# The base rests on the plate's studs, which holds it with the plate
	# (Mechanism._rest_on_studs): only the plate is the ground here.
	model = _mechanism_of(_bricks_of("3033")[0].id)
	_ok(model.body_of(_bricks_of("99009")[0].id) == model.ground,
		"the turntable's base, resting on the plate's studs, stands still with it")
	var worm: int = model.body_of(_bricks_of("4716")[0].id)
	var top: int = model.body_of(_bricks_of("99010")[0].id)
	solved = model.solve({worm: 1.0})
	var turned: float = absf(model.spin(top, Vector3.UP))
	# A tooth a turn is 1/28. The worm is 45 LDU off the axis in a real set,
	# and the lattice is 2 LDU, so here it is 46; the ratio is the teeth's all
	# the same (read at one gear's pitch circle it was 1/28.8).
	_ok(bool(solved.get("ok", false)) and absf(turned * 28.0 - 1.0) < 1e-5,
		"a turn of the crank turns the turntable a tooth, 1/28 (1/%.4f): %s"
			% [1.0 / maxf(turned, 1e-9), solved.get("said", "")])


## A turntable on a plate, its top put on its base where attachment_points
## says the base turns, and a worm on an axle through two bricks with holes
## turned to run along x, 45 LDU off the turntable's axis (the worm's 10 and
## the top's 35) and a lattice cell above the top's teeth, and a crank on the
## axle's end.
func _worm_and_turntable() -> Array:
	var base: Lbm.PartMesh = _library.mesh_for("99009")
	if base == null or _library.mesh_for("99010") == null:
		_ok(false, "the turntable's parts have geometry")
		return []
	var bricks: Array = [{"part": "3033", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0}]
	# The base on the plate, its axis on a stud's line.
	var under := Assistant.Placement.from_dict({"part": "99009", "x": 2, "y": 1, "z": 1})
	var origin: Vector3 = _assistant._transform(under, base).origin
	# And three quarters of a stud on in z, so the worm 2.25 studs behind it
	# is on a stud's line and its holders on the plate's studs.
	under.x += (roundf(origin.x / 20.0) * 20.0 - origin.x) / 20.0
	under.z += (roundf(origin.z / 20.0) * 20.0 - origin.z) / 20.0 + 0.75
	var put: Dictionary = {"part": "99009", "color": 0, "x": under.x, "y": under.y,
		"z": under.z, "rot": 0}
	bricks.append(put)
	var said: String = await _say("attachment_points", put)
	var found := RegEx.create_from_string("joint (\\d+): turntable at x=([-0-9.]+) "
		+ "y=([-0-9.]+) z=([-0-9.]+)").search(said)
	_ok(found != null, "attachment_points says where the base turns: %s" % _from(said,
		"Its joints"))
	if found == null:
		return []
	var turns := Vector3(found.get_string(2).to_float(), found.get_string(3).to_float(),
		found.get_string(4).to_float())
	bricks.append({"part": "99010", "color": 71, "x": turns.x, "y": turns.y, "z": turns.z,
		"rot": 0, "axis": "y"})
	# The worm's axle 3 plates up, where a 3700 on two plates has its hole:
	# 24 + 14 = 38 LDU, a cell from the teeth's plane, and 45 behind the axis.
	var m := Vector3(turns.x, 38.0 / 8.0, turns.z + 45.0 / 20.0)
	print("     the turntable turns at %s, the worm's middle at %s" % [turns, m])
	bricks.append({"part": "4716", "color": 0, "x": m.x, "y": m.y, "z": m.z, "rot": 0,
		"axis": "x"})
	bricks.append({"part": "3707", "color": 0, "x": m.x + 0.5, "y": m.y, "z": m.z, "rot": 0,
		"axis": "x"})
	# Its holders clear of the top's teeth, which reach 1.84 studs out.
	for side: float in [-2.5, 2.5]:
		var holder := Assistant.Placement.from_dict({"part": "3700", "x": m.x + side,
			"y": m.y, "z": m.z, "rot": 0, "axis": "x"})
		_assistant._on_its_line(holder)
		for course: float in [1.0, 2.0]:
			bricks.append({"part": "3023", "color": 71, "x": holder.x, "y": course,
				"z": holder.z, "rot": holder.rot})
		bricks.append({"part": "3700", "color": 71, "x": m.x + side, "y": m.y, "z": m.z,
			"rot": 0, "axis": "x"})
	# The crank on the axle's end, beyond the right-hand holder.
	bricks.append({"part": "6632", "color": 4, "x": m.x + 3.25, "y": m.y, "z": m.z,
		"rot": 0, "axis": "x", "joint": 0})
	return bricks


func _mechanism_of(ground: int, also: Array = []) -> Mechanism:
	var list: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		list.append({"key": brick.id, "part": brick.part_id, "at": brick.transform,
			"mesh": _library.mesh_for(brick.part_id)})
	return Mechanism.build(list, [ground] + also)


# -- by hand -----------------------------------------------------------------------


## A gear put down by hand in mesh with one already down has room, as the
## check says (Builder.room_for, Joints.meshing).
func _by_hand() -> void:
	print("\nby hand: a gear put down in mesh with another")
	_clear()
	var eight: Lbm.PartMesh = _library.mesh_for("3647")
	var at := Transform3D(Basis.IDENTITY, Vector3(0, 60, 0))
	_builder.put_part("3647", 72, at)
	var beside := Transform3D(Basis.IDENTITY, Vector3(40, 60, 0))
	_ok(_builder.room_for("3648b", beside, true),
		"a 24 two studs from an 8, in one plane, has room")
	_ok(not _builder.room_for("3648b", Transform3D(Basis.IDENTITY, Vector3(36, 60, 0)), true),
		"...and none 36 LDU from it")
	if eight == null:
		_ok(false, "3647 has geometry")
	# An 8 and a 28 on a stud's diagonal, 44.72 for 45, as real sets stand
	# them: the 28's teeth clear the 8's axle by 1.4 LDU, less than a cell.
	_clear()
	var up := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	var flat := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	_builder.put_part("3705", 0, Transform3D(up, Vector3(0, 60, 0)))
	_builder.put_part("3647", 72, Transform3D(flat, Vector3(0, 60, 0)))
	_builder.put_part("3705", 0, Transform3D(up, Vector3(40, 60, 20)))
	_ok(_builder.room_for("46372", Transform3D(flat, Vector3(40, 60, 20)), true),
		"a 28 on a stud's diagonal from an 8 has room beside the 8's axle")
	# The 28's cover is the square round its teeth; past them is air, but
	# inside them is the gear: an axle 30 LDU from its middle is in its way.
	_clear()
	_builder.put_part("3705", 0, Transform3D(up, Vector3(30, 60, 0)))
	_builder.put_part("3705", 0, Transform3D(up, Vector3(0, 60, 0)))
	_ok(not _builder.room_for("46372", Transform3D(flat, Vector3(0, 60, 0)), true),
		"...and a bare axle 30 LDU from a 28's middle, inside its teeth, is in its way")
	_clear()
	_builder.put_part("3705", 0, Transform3D(up, Vector3(32, 60, 32)))
	_builder.put_part("3705", 0, Transform3D(up, Vector3(0, 60, 0)))
	_ok(_builder.room_for("46372", Transform3D(flat, Vector3(0, 60, 0)), true),
		"...and one in its square's corner, 45.3 LDU out on the diagonal, past its teeth, is not")
