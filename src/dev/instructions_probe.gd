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
	_built_on_the_side(world, library)
	_a_published_model(world, library)
	_wheels_go_on_last(world, library)
	_floating_detail(world, library)

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
##
## And a pin that joins two parts goes into the first and the second goes
## on it, as a Technic booklet has it: waiting for both put every such pin
## in last, between two beams already there, where no picture can show it.
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

	# A wheel is the exception, the other way round: it is pushed on to
	# its axle, so the axle goes in first and the wheel after it.
	var wheels_first: int = 0
	var wheels: int = 0
	var into: Dictionary = {}   ## pin -> the parts it joins
	for pair: Array in joints:
		var socket: BrickWorld.Brick = world.get_brick(pair[1])
		var info: PartLibrary.PartInfo = library.parts.get(socket.part_id)
		if info != null and info.name.strip_edges().begins_with("Wheel"):
			wheels += 1
			if int(order.get(pair[1], 0)) < int(order.get(pair[0], 0)):
				wheels_first += 1
			continue
		if not into.has(pair[0]):
			into[pair[0]] = []
		(into[pair[0]] as Array).append(pair[1])
	# Each pin after the first part it goes into; a pin joining two parts
	# before the other, which goes on it.
	var early: int = 0
	var joining: int = 0
	var buried: int = 0
	for pin: int in into:
		var parts: Array = into[pin]
		var at: Array = parts.map(func(id: int) -> int: return int(order.get(id, 0)))
		if int(order.get(pin, 0)) < int(at.min()):
			early += 1
		var distinct: Dictionary = {}
		for id: int in parts:
			distinct[id] = true
		if distinct.size() >= 2:
			joining += 1
			if int(order.get(pin, 0)) > int(at.max()):
				buried += 1

	print("\n  a Technic go-kart, %d parts in %d steps" % [
		world.bricks().size(), steps.size()])
	_assert("its joints are found (%d)" % joints.size(), joints.size() > 20)
	_assert("every part gets a step (%d of %d)" % [
		order.size(), world.bricks().size()],
		order.size() == world.bricks().size())
	_assert("no pin goes in before the hole exists (%d do)" % early, early == 0)
	_assert("a pin joining two parts goes in before the second (%d of %d after both)"
		% [buried, joining], joining > 0 and buried * 4 <= joining)
	_assert("no wheel goes on before its axle (%d of %d do)" % [wheels_first, wheels],
		wheels > 0 and wheels_first == 0)


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
	_assert("a model one region wide is built in one go, with no parts",
		steps.all(func(step: Instructions.Step) -> bool:
			return step.section.is_empty()))


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
	# Tall enough to be cut into tiles of its plan (Instructions.TILED_FROM).
	world.clear()
	for tower: int in 2:
		for level: int in Instructions.TILED_FROM / 2:
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

	# Built a region at a time: one tower to the top, then the other. Run
	# course by course across the model, a 1,895-part castle's steps
	# jumped a median of 12.5 studs, and up to 61, from one to the next.
	var switches: int = 0
	var was: bool = world.get_brick(steps[0].brick_ids[0]).transform.origin.x < 300.0
	for step: Instructions.Step in steps:
		var here: bool = world.get_brick(step.brick_ids[0]).transform.origin.x < 300.0
		if here != was:
			switches += 1
			was = here
	_assert("one tower is finished before the other is begun (%d switches)"
		% switches, switches == 1)
	_assert("...and each is a named part of the booklet (%s, %s)" % [
		steps[0].section, steps[-1].section],
		steps[0].section == "part 1" and steps[-1].section == "part 2")

	# Eight bricks the same shape are not: a 92-part spaceship was "Part 1",
	# one step on a page of its own, and "Part 2" twice.
	world.clear()
	for tower: int in 2:
		for level: int in 4:
			world.add_brick("3001", 14, Transform3D(Basis.IDENTITY,
				Vector3(tower * 600.0, level * 24.0, 0)))
	var small: Array[Instructions.Step] = Instructions.plan(world, library)
	_assert("a small model as wide is not cut into parts (%s)" % ", ".join(
		small.map(func(step: Instructions.Step) -> String: return step.section)),
		small.all(func(step: Instructions.Step) -> bool: return step.section.is_empty()))


## A shed with two windows the same and a figure standing in it.
##
## The document builds its window once and places it twice, and the figure
## is a sub-model of its own: what a booklet builds in a callout, "2x",
## and puts on with an arrow. Flattened, the windows were four loose
## bricks of the wall and the figure was two "sections" of a model the
## size of a hand — Orthanc's booklet built Saruman as a part of the tower.
const SHED := """0 FILE shed.ldr
0 Shed
1 16 0 0 0 1 0 0 0 1 0 0 0 1 walls.ldr
1 16 0 0 0 1 0 0 0 1 0 0 0 1 figure.ldr
0 NOFILE
0 FILE walls.ldr
0 Walls
1 15 0 0 0 1 0 0 0 1 0 0 0 1 3958.dat
1 15 0 -24 -50 1 0 0 0 1 0 0 0 1 3009.dat
1 15 0 -48 -50 1 0 0 0 1 0 0 0 1 3009.dat
1 15 0 -24 50 1 0 0 0 1 0 0 0 1 3004.dat
1 15 0 -48 50 1 0 0 0 1 0 0 0 1 3004.dat
1 4 -40 -24 50 1 0 0 0 1 0 0 0 1 window.ldr
1 4 40 -24 50 1 0 0 0 1 0 0 0 1 window.ldr
0 NOFILE
0 FILE window.ldr
0 Window
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3004.dat
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 3004.dat
0 NOFILE
0 FILE figure.ldr
0 Saruman
1 15 0 -28 1.25 1 0 0 0 1 0 0 0 1 3816c.dat
1 15 0 -28 1.25 1 0 0 0 1 0 0 0 1 3817c.dat
1 15 0 -40 1.25 1 0 0 0 1 0 0 0 1 3815b.dat
1 14 23.69 -45.226 -8.648 0.985 0.12 -0.12 -0.17 0.696 -0.696 0 0.707 0.707 3820.dat
1 14 -23.69 -45.226 -8.648 0.985 -0.12 0.12 0.17 0.696 -0.696 0 0.707 0.707 3820.dat
1 15 -15.552 -63 1.25 0.985 -0.17 0 0.17 0.985 0 0 0 1 3818.dat
1 15 15.552 -63 1.25 0.985 0.17 0 -0.17 0.985 0 0 0 1 3819.dat
1 15 0 -72 1.25 1 0 0 0 1 0 0 0 1 973.dat
1 14 0 -96 1.25 1 0 0 0 1 0 0 0 1 3626c.dat
0 NOFILE
"""


func _built_on_the_side(world: BrickWorld, library: PartLibrary) -> void:
	_load(world, library, LdrModel.parse(SHED, "shed.ldr"))
	var steps: Array[Instructions.Step] = Instructions.plan(world, library)
	print("\n  a shed with two windows and a figure, %d parts in %d steps" % [
		world.brick_count(), steps.size()])
	_follow("shed", steps, world, library)

	var windows: Array = steps.filter(func(step: Instructions.Step) -> bool:
		return step.in_callout() and step.assembly.to_lower() == "window")
	_assert("the window is built in a callout (%d steps)" % windows.size(),
		not windows.is_empty())
	if windows.is_empty():
		return
	var window: Instructions.Step = windows[0]
	_assert("...once, marked 2x (%dx)" % window.times, window.times == 2)
	var shown: int = 0
	var built: int = 0
	for step: Instructions.Step in windows:
		shown += step.shown_ids.size()
		built += step.brick_ids.size()
	_assert("...its pictures show one copy (%d bricks) and it builds both (%d)"
		% [shown, built], shown == 2 and built == 4)
	var attach: Instructions.Step = null
	for step: Instructions.Step in steps:
		if step.attaches() and step.callout == window.callout:
			attach = step
	_assert("...and then both go on in one step, after it",
		attach != null and attach.copies.size() == 2
		and attach.index > (windows[-1] as Instructions.Step).index
		and attach.number == window.number and attach.brick_ids.is_empty())

	var figure: Array = steps.filter(func(step: Instructions.Step) -> bool:
		return step.in_callout() and step.figure)
	_assert("the figure is a callout of one step, all %d parts (%s)" % [
		9, str(figure.map(func(step: Instructions.Step) -> int:
			return step.brick_ids.size()))],
		figure.size() == 1 and (figure[0] as Instructions.Step).brick_ids.size() == 9)
	_assert("...and it is not a part of the model of its own",
		steps.all(func(step: Instructions.Step) -> bool: return step.section.is_empty()))

	# The numbers a reader sees: 1, 2, 3 with no gaps, a callout's steps
	# carrying the number of the step its assembly goes on in.
	var numbers: Array[int] = []
	var ordered: bool = true
	for step: Instructions.Step in steps:
		if step.in_callout():
			continue
		numbers.append(step.number)
	for at: int in numbers.size():
		ordered = ordered and numbers[at] == at + 1
	_assert("main steps numbered 1 to %d with no gaps" % numbers.size(), ordered)
	_assert("the timeline says it as the booklet does (%s)"
		% window.caption(numbers.size()),
		window.caption(numbers.size()).begins_with("Step %d of %d · Window (2x), 1 of"
			% [window.number, numbers.size()]))


## A model from LDraw's repository, built by people from the set's own
## booklet: its sub-models are the booklet's sub-assemblies. Skipped when
## the repository has not been fetched (tools/fetch_data.sh).
func _a_published_model(world: BrickWorld, library: PartLibrary) -> void:
	const PATH := "res://vendor/omr/files/31009-1_Skaters-House.mpd"
	if not FileAccess.file_exists(PATH):
		print("\n  SKIP 31009 Skaters House: vendor/omr is not here")
		return
	_load(world, library, LdrModel.load_file(PATH))
	var steps: Array[Instructions.Step] = Instructions.plan(world, library)
	print("\n  31009 Skaters House, %d parts in %d steps" % [
		world.brick_count(), steps.size()])
	_follow("31009", steps, world, library)
	var callouts: Dictionary = {}
	var most: int = 0
	for step: Instructions.Step in steps:
		if step.in_callout():
			callouts[step.assembly] = true
			most = maxi(most, step.times)
	_assert("its windows, table, chair, skateboard and figure are callouts (%s)"
		% ", ".join(callouts.keys()),
		callouts.has("Window") and callouts.has("Table") and callouts.has("Chair")
		and callouts.has("Skateboard") and callouts.has("MiniFig1"))
	_assert("...and a window is built once for two (%dx)" % most, most >= 2)


## The example car a first visit opens: its booklet began with four
## wheels standing on the table, because the hole is in the wheel and a
## pin needs its hole.
func _wheels_go_on_last(world: BrickWorld, library: PartLibrary) -> void:
	_load(world, library, LdrModel.load_file("res://models/car.ldr"))
	var steps: Array[Instructions.Step] = Instructions.plan(world, library)
	var first: Array = Array(steps[0].brick_ids).map(func(id: int) -> String:
		var info: PartLibrary.PartInfo = library.parts.get(world.get_brick(id).part_id)
		return info.name.strip_edges() if info != null else "")
	print("\n  the example car, %d parts in %d steps" % [world.brick_count(), steps.size()])
	_assert("it starts with the chassis, not the wheels (%s)" % ", ".join(first),
		not first.any(func(name: String) -> bool:
			return name.begins_with("Wheel") or name.begins_with("Tyre")))
	var at: Dictionary = {}
	var place: int = 0
	for step: Instructions.Step in steps:
		for id: int in step.brick_ids:
			at[id] = place
			place += 1
	var tyres_after: bool = true
	for tyre: BrickWorld.Brick in world.bricks():
		if not library.parts[tyre.part_id].name.begins_with("Tyre"):
			continue
		var box: AABB = _box(tyre.id, world, library)
		for rim: BrickWorld.Brick in world.bricks():
			if library.parts[rim.part_id].name.begins_with("Wheel") \
					and _box(rim.id, world, library).grow(1.0).intersects(box):
				tyres_after = tyres_after and int(at[tyre.id]) > int(at[rim.id])
	_assert("...and every tyre goes on after its rim", tyres_after)


## A detail that touches nothing — a design's pinnacle a hair off its
## tower — was free to go in at step 1, hanging in the air above an empty
## table: Orthanc had 188 of them. It waits until the model reaches it.
func _floating_detail(world: BrickWorld, library: PartLibrary) -> void:
	world.clear()
	for level: int in 6:
		world.add_brick("3001", 4, Transform3D(Basis.IDENTITY, Vector3(0, level * 24.0, 0)))
	var detail: int = world.add_brick("3024", 14, Transform3D(Basis.IDENTITY,
		Vector3(160.0, 5 * 24.0, 0.0)))
	var steps: Array[Instructions.Step] = Instructions.plan(world, library)
	var before: int = 0
	for step: Instructions.Step in steps:
		if step.brick_ids.has(detail):
			break
		before += step.brick_ids.size()
	print("\n  a detail floating beside a stack of six")
	_assert("it goes in once the stack has reached it (after %d of 6)" % before, before >= 5)


func _load(world: BrickWorld, library: PartLibrary, ldr: LdrModel) -> void:
	world.clear()
	for piece: LdrModel.Placement in ldr.flatten(library.parts):
		var id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(id) == null:
			continue
		var brick_id: int = world.add_brick(id, piece.color_code, piece.transform)
		world.get_brick(brick_id).group = piece.group
		world.get_brick(brick_id).unit = piece.unit


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
	#
	# A figure is clipped together, not stacked — an arm rests on nothing —
	# so its callout is not held to it. Anything else built in a callout
	# is built on the table: its copy's lowest bricks stand on that, and
	# the rest on what was placed before them.
	var floor_of: Dictionary = {}
	for step: Instructions.Step in steps:
		for copy: PackedInt64Array in step.copies:
			var lowest: float = INF
			for brick_id: int in copy:
				lowest = minf(lowest, _box(brick_id, world, library).position.y)
			for brick_id: int in copy:
				floor_of[brick_id] = lowest
	for step: Instructions.Step in steps:
		for brick_id: int in step.brick_ids:
			if seen.has(brick_id):
				duplicated = true
			seen[brick_id] = true
			var on_its_own_table: bool = (step.in_callout() and absf(
				_box(brick_id, world, library).position.y
				- float(floor_of.get(brick_id, INF))) < 1.0)
			if not step.unsupported and not step.figure and not on_its_own_table \
					and not _rests_on_something(brick_id, on_table, world, library):
				floating += 1
				if floating <= 8:
					print("        floating: %s in step %d%s" % [
						world.get_brick(brick_id).part_id, step.number,
						" (%s %d of %d)" % [step.assembly, step.callout_step,
							step.callout_steps] if step.in_callout() else ""])
			on_table[brick_id] = true

	_assert("%s: every brick placed once (%d of %d)"
		% [what, seen.size(), world.brick_count()],
		not duplicated and seen.size() == world.brick_count())
	_assert("%s: nothing placed in mid-air (%d floating)" % [what, floating],
		floating == 0)


func _box(brick_id: int, world: BrickWorld, library: PartLibrary) -> AABB:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	return brick.transform * library.mesh_for(brick.part_id).bounds


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
		if _sits_on(box, _box(other_id, world, library)):
			return true
	# Nothing in the whole model is under it — a tap clipped to a brick's
	# side, a wheel on an axle — so it hangs from what it touches, and
	# that has to be there first.
	for other: BrickWorld.Brick in world.bricks():
		if other.id != brick_id and _sits_on(box, _box(other.id, world, library)):
			return false
	for other_id: int in on_table:
		if box.grow(1.0).intersects(_box(other_id, world, library)):
			return true
	return false


func _sits_on(box: AABB, other_box: AABB) -> bool:
	var under: bool = absf(other_box.end.y - box.position.y) <= 5.0
	var overlap: bool = (box.position.x < other_box.end.x - 0.5
		and other_box.position.x < box.end.x - 0.5
		and box.position.z < other_box.end.z - 0.5
		and other_box.position.z < box.end.z - 0.5)
	return under and overlap


func _assert(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
