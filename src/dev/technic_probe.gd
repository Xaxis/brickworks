## Can a mechanism be built at all?
##
##   godot --headless --path . --script src/dev/technic_probe.gd
##
## Studs are not the only way LEGO parts join, and for anything that
## moves they are the wrong way: a chassis, a steering linkage, an arm
## are pins through Technic beams. Two separate things had to be true
## before any of that could be built here, and neither was.
##
## The hole had to be empty. fill_cavities closes voids one horizontal
## layer at a time, and a hole running vertically — which is every beam
## hole — is a closed circle in each layer it crosses, so it filled. A
## pin pushed into a liftarm was a collision.
##
## And the joint had to count as holding something. The only attachments
## the checker knew were "something in the cell below" and "a stud
## reaching in", so a beam pinned to a beam was two floating parts.
##
## This probe does not hardcode where a pin goes. It searches the
## orientations and asserts that one of them works, which is the claim
## that matters and survives the geometry being rebuilt.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	await process_frame

	_check_the_parts_know(library)
	_check_the_holes_are_open(library, builder)
	_check_a_pin_holds(assistant)
	await _check_a_round_brick_takes_a_pin(assistant)
	await _check_the_tool_says_where(assistant)

	print("")
	if _failures == 0:
		print("a pin joins two parts, and the checker knows it")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _check_the_parts_know(library: PartLibrary) -> void:
	print("\nwhat the parts carry")
	var pin: Lbm.PartMesh = library.mesh_for("2780")
	var ends: int = 0
	if pin != null:
		for connector: Lbm.Connector in pin.connectors:
			if connector.kind == "pin":
				ends += 1
	# 2780 is the friction pin, the most used Technic part there is. It
	# is drawn as two mirrored confric5 halves, and the confric family
	# was represented in the primitive table by two of its eleven
	# members — so it had no connectors at all.
	_ok(ends == 2, "2780, the friction pin, has two pin ends (%d)" % ends)

	var beam: Lbm.PartMesh = library.mesh_for("32523")
	var holes: int = 0
	if beam != null:
		for connector: Lbm.Connector in beam.connectors:
			if connector.kind == "pin_hole":
				holes += 1
	_ok(holes == 3, "Technic beam 3 has three pin holes (%d)" % holes)

	# A plain axle is not something another axle can pass through, and
	# "axlehol8" is the axle's own perimeter, not a hole in it.
	var axle: Lbm.PartMesh = library.mesh_for("3705")
	var claimed: int = 0
	if axle != null:
		for connector: Lbm.Connector in axle.connectors:
			if connector.kind == "axle_hole":
				claimed += 1
	_ok(claimed == 0, "Technic axle 4 claims no axle hole (%d)" % claimed)


func _check_the_holes_are_open(library: PartLibrary, builder: Builder) -> void:
	print("\nwhether a pin could physically go in")
	for id: String in ["32523", "43857", "3700"]:
		var part: Lbm.PartMesh = library.mesh_for(id)
		if part == null:
			_ok(false, "%s has no geometry" % id)
			continue
		var cells: Dictionary = {}
		for cell: Vector3i in builder._cells_for(part, Transform3D.IDENTITY):
			cells[cell] = true
		var blocked: int = 0
		var total: int = 0
		for connector: Lbm.Connector in part.connectors:
			if connector.kind != "pin_hole" and connector.kind != "axle_hole":
				continue
			total += 1
			if cells.has(BrickLattice.to_cell(connector.position)):
				blocked += 1
		_ok(total > 0 and blocked == 0,
			"%s: %d hole%s, %d filled solid" % [
				id, total, "" if total == 1 else "s", blocked])


func _check_a_pin_holds(assistant: Assistant) -> void:
	print("\nwhether the checker counts the joint")
	# Where a pin has to go to be in 3700's hole. Not guessed: the hole
	# is at (20, 14, 10) LDU running along z, the pin's own connector is
	# at its centre, and the placement is affine in x, y and z — so the
	# offset is the gap over a stud, a plate and a stud. A first version
	# of this probe put the pin at x=0.5 when the hole is at x=1.0, ten
	# LDU off an axis that tolerates four, so nothing could ever mate.
	_ok(_joins(assistant, 0.6, 0.75, -0.5, "up", 1),
		"a pin in the hole of a Technic brick is held, and does not collide")

	# The same pin turned a quarter so it lies across the hole instead of
	# through it. This is what proves the joint is being matched rather
	# than anything nearby being accepted.
	_ok(not _joins(assistant, 0.6, 0.75, -0.5, "up", 0),
		"...and the same pin turned across the hole is not")

	# And well away from it.
	_ok(not _joins(assistant, 4.0, 0.75, 4.0, "up", 1),
		"...nor one four studs away")

	# Forgiving the joint must forgive only the joint. A third brick
	# driven through the same space is still an overlap, or the
	# suppression would be a hole anything could be hidden in.
	var model := Assistant.Model.new()
	var brick := Assistant.Placement.new()
	brick.part = "3700"
	brick.color = 4
	model.placements.append(brick)
	var pin := Assistant.Placement.new()
	pin.part = "3673"
	pin.color = 0
	pin.x = 0.6
	pin.y = 0.75
	pin.z = -0.5
	pin.face = "up"
	pin.rot = 1
	model.placements.append(pin)
	var intruder := Assistant.Placement.new()
	intruder.part = "3005"       # a 1x1 brick, square in the pin's way
	intruder.color = 2
	intruder.x = 0.6
	intruder.y = 0.75
	intruder.z = -0.5
	model.placements.append(intruder)
	var said: String = str(assistant._check(model, true).get("feedback", ""))
	_ok(said.contains("overlap"),
		"a third brick in the same space is still an overlap")


## A round brick with holes in its side: 6222 is 4x4 and 18897 6x6, and
## each has a Technic pin hole at the middle of every side, a plate and a
## quarter under the top. Their covers were their bounding boxes, solid
## right through the holes, so a pin pushed into one was refused as an
## overlap with the brick it was pinned to.
##
## Where the pin goes is read off the brick, not guessed: each brick sits
## at the origin, its middle half its width in, and the hole on its +x
## side runs along x at 14 LDU up, its mouth on the brick's face. A 3673
## laid along x (rot 0) is 40 long and 16 across its collar, so its
## corner cell is 20 back from the mouth and 8 under and beside the axis.
func _check_a_round_brick_takes_a_pin(assistant: Assistant) -> void:
	print("\na pin in the side of a round brick")
	for brick: Array in [["6222", 80.0], ["18897", 120.0]]:
		var width: float = brick[1]
		var pin_at := Vector3(width - 20.0, 14.0 - 8.0, width * 0.5 - 8.0)
		var said: String = await _check_design(assistant, brick[0], pin_at)
		_ok(said.contains("buildable") and not said.contains("overlap"),
			"a pin in a side hole of %s is buildable: %s" % [brick[0], said])

		# The same pin a stud along the face, where there is wall and no
		# hole: forgiving the joint must not forgive this.
		said = await _check_design(assistant, brick[0], pin_at + Vector3(0, 0, 20))
		_ok(said.contains("overlap"),
			"...and the same pin a stud beside the hole, in %s's wall, overlaps: %s"
				% [brick[0], said])


## What check_design, the tool a design is checked with, says of a brick
## at the origin and a 3673 along x with its corner cell at [param pin_at]
## LDU, on one line.
func _check_design(assistant: Assistant, brick: String, pin_at: Vector3) -> String:
	var bricks: Array = [
		{"part": brick, "color": 4, "x": 0, "y": 0, "z": 0},
		{"part": "3673", "color": 0, "x": pin_at.x / 20.0, "y": pin_at.y / 8.0,
			"z": pin_at.z / 20.0, "face": "up", "rot": 0},
	]
	var answer: Variant = await assistant.use_tool("check_design", {"bricks": bricks})
	var text: String = ""
	if answer is Array:
		for block: Variant in answer:
			if block is Dictionary and (block as Dictionary).get("type", "") == "text":
				text += str((block as Dictionary)["text"])
	else:
		text = str(answer)
	return text.replace("\n", " / ").left(240)


## Whether this pair stands up: no overlap, nothing floating.
func _joins(assistant: Assistant, x: float, y: float, z: float,
		face: String, rot: int) -> bool:
	var model := Assistant.Model.new()
	var brick := Assistant.Placement.new()
	brick.part = "3700"
	brick.color = 4
	model.placements.append(brick)
	var pin := Assistant.Placement.new()
	pin.part = "3673"
	pin.color = 0
	pin.x = x
	pin.y = y
	pin.z = z
	pin.face = face
	pin.rot = rot
	model.placements.append(pin)
	var report: Dictionary = assistant._check(model, true)
	var feedback: String = str(report.get("feedback", ""))
	return not feedback.contains("nothing holding") \
		and not feedback.contains("overlap")


func _check_the_tool_says_where(assistant: Assistant) -> void:
	print("\nwhat attachment_points will tell a design")
	var said: String = await assistant._attachment_points(
		{"part": "32523", "x": 0, "y": 0, "z": 0})
	print("     %s" % said.replace("\n", "\n     "))
	# It reported male studs and nothing else, so about a Technic beam it
	# said "no studs — nothing clutches to it", which is the part the
	# whole of Technic is built from.
	_ok(said.contains("pin hole"), "a beam's holes are listed")
	_ok(not said.contains("nothing clutches to it"),
		"...and it is not described as something nothing attaches to")
