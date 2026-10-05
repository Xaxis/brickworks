## Check that a booklet could actually be followed.
##
##   godot --headless --path . --script src/dev/instructions_probe.gd
##
## The interesting failure is not a crash — it is a plausible-looking
## sequence that nobody could build: a brick placed in mid-air because
## the one under it comes three steps later, or a booklet that starts at
## the roof because the sign of "up" went the wrong way. Both look fine
## in a list and are obvious the moment you try to follow them.
##
## So this builds models whose right answer is known and follows the
## booklet through, holding a set of what is on the table.
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
	root.add_child(world)

	_tower(world, library)
	_wall(world, library)
	_two_towers(world, library)
	_a_pin_goes_in_last(world, library)

	print("")
	print("%d failed" % _failures if _failures else "every booklet can be followed")
	quit(1 if _failures else 0)


## A pin cannot go into a hole that is not on the table yet.
##
## _find_supports only knows what sits on what, and a pin goes in
## sideways: nothing is under it, so it had no prerequisites at all and
## was free to be step one. On models/kart.ldr, 20 of its 40 joints came
## out inserted before the part they go into — pins at step 2 reaching
## into beams placed at step 7.
##
## The kart is the fixture because a two-part toy will not do it. With a
## brick and one pin, both are ready at once and the brick happens to be
## chosen first, so the check passes whether the dependency exists or
## not. What makes the kart bite is that its pins sit *lower* than the
## beams they enter — they go into the wheels — and the sequencer
## prefers whatever is lowest.
func _a_pin_goes_in_last(world: BrickWorld, library: PartLibrary) -> void:
	world.clear()
	var ldr: LdrModel = LdrModel.load_file("res://models/kart.ldr")
	if ldr == null:
		_assert("models/kart.ldr can be read", false)
		return
	for piece: LdrModel.Placement in ldr.flatten():
		var id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(id) == null:
			continue
		world.add_brick(id, piece.color_code, piece.transform)

	var entries: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh != null:
			entries.append([brick.id, brick.transform, mesh])
	var joints: Array = Joints.pairs(entries)

	var steps: Array[Instructions.Step] = Instructions.plan(world, library)
	# Where each part comes in the booklet read straight through. One
	# step may hold both ends of a joint — "add this beam and pin it" is
	# a single instruction — so what matters is which comes first.
	var order: Dictionary = {}
	var place: int = 0
	for step: Instructions.Step in steps:
		for id: int in step.brick_ids:
			order[id] = place
			place += 1

	var early: int = 0
	for pair: Array in joints:
		if int(order.get(pair[0], 0)) < int(order.get(pair[1], 0)):
			early += 1

	print("\n  a Technic go-kart, %d parts in %d steps" % [
		world.bricks().size(), steps.size()])
	_assert("its joints are found (%d)" % joints.size(), joints.size() > 20)
	_assert("every part gets a step (%d of %d)" % [
		order.size(), world.bricks().size()],
		order.size() == world.bricks().size())
	_assert("no pin goes in before the hole exists (%d do)" % early, early == 0)


## Ten bricks stacked. There is only one legal order, and it is bottom up.
func _tower(world: BrickWorld, library: PartLibrary) -> void:
	world.clear()
	var ids := PackedInt64Array()
	# Added top-down on purpose: if the planner were quietly relying on
	# insertion order rather than on geometry, this would pass anyway and
	# the wall below would not.
	for level: int in range(9, -1, -1):
		ids.append(world.add_brick("3001", 4,
			Transform3D(Basis.IDENTITY, Vector3(0, level * 24.0, 0))))

	var steps: Array[Instructions.Step] = Instructions.plan(world, library)
	_follow("stack of 10", steps, world, library)

	# Bottom-up means the first brick placed is the one nearest the
	# ground. +Y is up in engine space — the conversion already negated
	# it — so that is the *smallest* Y.
	#
	# This read "largest" and so did the planner, and the two agreeing
	# is exactly why a stack built from the top passed this check.
	var first: BrickWorld.Brick = world.get_brick(steps[0].brick_ids[0])
	var lowest: float = INF
	for brick: BrickWorld.Brick in world.bricks():
		lowest = minf(lowest, brick.transform.origin.y)
	_assert("stack starts at the bottom, at y=%.0f of %.0f"
		% [first.transform.origin.y, lowest],
		is_equal_approx(first.transform.origin.y, lowest))


## A wall two courses high, laid in staggered rows so the upper course
## rests on two lower bricks at once.
func _wall(world: BrickWorld, library: PartLibrary) -> void:
	world.clear()
	for course: int in 2:
		var offset: float = 0.0 if course == 0 else 40.0
		for column: int in 6:
			world.add_brick("3001", 1, Transform3D(Basis.IDENTITY,
				Vector3(offset + column * 80.0, course * 24.0, 0)))
	var steps: Array[Instructions.Step] = Instructions.plan(world, library)
	_follow("staggered wall", steps, world, library)
	_assert("wall takes more than one step, got %d" % steps.size(),
		steps.size() > 1)


## Two stacks far apart. A step must not reach across the gap: the point
## of grouping by distance is that a step stays somewhere you can see.
func _two_towers(world: BrickWorld, library: PartLibrary) -> void:
	world.clear()
	for tower: int in 2:
		for level: int in 4:
			world.add_brick("3001", 14, Transform3D(Basis.IDENTITY,
				Vector3(tower * 600.0, level * 24.0, 0)))
	var steps: Array[Instructions.Step] = Instructions.plan(world, library)
	_follow("two towers", steps, world, library)

	var split: bool = true
	for step: Instructions.Step in steps:
		var left: bool = false
		var right: bool = false
		for brick_id: int in step.brick_ids:
			if world.get_brick(brick_id).transform.origin.x < 300.0:
				left = true
			else:
				right = true
		if left and right:
			split = false
	_assert("no step spans both towers", split)


## Walk the booklet the way a person would, and complain about anything
## they could not have done.
func _follow(what: String, steps: Array[Instructions.Step],
		world: BrickWorld, library: PartLibrary) -> void:
	var on_table: Dictionary = {}
	var seen: Dictionary = {}
	var duplicated: bool = false
	var floating: int = 0

	# Placed one at a time in the order the step lists them, not all at
	# the end of the step. A booklet step is routinely self-supporting —
	# four bricks up the same column is one step in any real set — so
	# requiring a brick's support to come from an *earlier* step would
	# fail sequences that are perfectly buildable. What this still
	# catches is the failure that matters: a brick resting on one that
	# comes later.
	for step: Instructions.Step in steps:
		for brick_id: int in step.brick_ids:
			if seen.has(brick_id):
				duplicated = true
			seen[brick_id] = true
			if not step.unsupported and not _rests_on_something(
					brick_id, on_table, world, library):
				floating += 1
			on_table[brick_id] = true

	_assert("%s: every brick placed once (%d of %d)"
		% [what, seen.size(), world.brick_count()],
		not duplicated and seen.size() == world.brick_count())
	_assert("%s: nothing placed in mid-air (%d floating)" % [what, floating],
		floating == 0)


## True when the brick is on the ground, or on something already placed.
func _rests_on_something(brick_id: int, on_table: Dictionary,
		world: BrickWorld, library: PartLibrary) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	var box: AABB = brick.transform * library.mesh_for(brick.part_id).bounds
	# On the floor: with +Y up the underside is box.position.y, and the
	# table is the smallest y anything reaches.
	var floor_y: float = INF
	for other: BrickWorld.Brick in world.bricks():
		var other_box: AABB = other.transform * library.mesh_for(other.part_id).bounds
		floor_y = minf(floor_y, other_box.position.y)
	if absf(box.position.y - floor_y) < 1.0:
		return true

	for other_id: int in on_table:
		var other: BrickWorld.Brick = world.get_brick(other_id)
		var other_box: AABB = other.transform * library.mesh_for(other.part_id).bounds
		var under: bool = absf(other_box.end.y - box.position.y) <= 5.0
		var overlap: bool = (box.position.x < other_box.end.x - 0.5
			and other_box.position.x < box.end.x - 0.5
			and box.position.z < other_box.end.z - 0.5
			and other_box.position.z < box.end.z - 0.5)
		if under and overlap:
			return true
	return false


func _assert(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
