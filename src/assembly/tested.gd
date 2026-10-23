## Whether a shared model can be built as its steps say: the "Tested" mark
## (2026-10-18), worked out by the app as the model is published, where the
## model and the library are. The server cannot run any of it, so it keeps
## what the app found, as the app's finding, with the app's version
## (api/share.js, supabase/tested.sql).
##
## Paid fan instructions elsewhere are often untested virtual models, and a
## builder finds out when the build falls apart. Four tests, each passed or
## failed with its reason:
##
##   stands  the model stands at every step of the steps the share carries:
##           each step's build so far weighed as the build check weighs it
##           (Balance): its centre of mass over what it stands on, and no stud
##           joint past where it lets go. A sub-assembly built in the hand is
##           weighed once it is on the model.
##   steps   no part in a step is put down in the air or hidden behind what
##           is already built, by the booklet's own rules: at the end of its
##           step each new thing is held to something that stands (the steps
##           score's "floating", src/dev/steps_score.gd: on the model, what is
##           on its lowest point, its first parts and the first parts of each
##           piece a step begins; in the hand, the sub-assembly's first parts),
##           and shows a tenth of itself from the front or from the back with
##           what earlier steps built in front of it (Instructions.Pictures,
##           the planner's own pictures of a step).
##   parts   every part is a real element in its colour, as the catalogue's
##           colour availability knows it (PartInfo.never_made_in): none in a
##           colour it was never made in, none made here, none in a colour
##           typed in rather than one parts are made in. A part the catalogue
##           has no colours for is not held against it, and is counted.
##   whole   it is one piece, every part held, none through another, by the
##           parts' exact shapes as the design check reads them (ExactCheck):
##           no two parts' real shapes overlap by more than 1 LDU, past what
##           a joint's own parts do and gears in mesh (ExactCheck.forgiven);
##           each part is joined to the rest by BrickNet's connections (a
##           stud in its hole, a pin, an axle, a clip, a hinge, a ball), by
##           glue, magnets or being one flexible thing (Joints.held_otherwise),
##           or, standing where it is, caught there so it cannot slide out
##           (ExactCheck.comes_away). A part with no exact shape is held as
##           the joints and what rests on what hold it, as before.
##           models175 found the test before this held a part whenever it
##           touched a held one and never asked about collisions: Orthanc,
##           145 pairs through each other and 72 pieces, could have passed.
##
## A part the finished model does not hold is the whole test's, and is not
## held against its step too, as the steps score leaves it out.
##
## Paced ([method check]): a slice a frame, so the share panel is never held.
class_name Tested
extends RefCounted

const VERSION := 1
## A new thing shows at least this much of itself, from the front or the
## back: the steps score's SEEN, the planner's Pictures.SEEN.
const SEEN := 0.1
## How many failures each test names before it says how many more.
const NAMED := 3
## How much of a test's reason the site keeps (api/_tested.js MOST_WHY).
const MOST_WHY := 300
## How long the tests may take before the model goes untested, ms: a
## 2,042-part set takes about 2.2 s here.
const MOST_MS := 15000
## LDraw's direct colours, 0x2RRGGBB: a colour typed in, not one parts are made in.
const DIRECT_FROM := 0x2000000


## Where the last [method check]'s time went, in microseconds, for a probe.
static var laps: Dictionary = {}


## A build's parts joined as they go in: the main build, or a sub-assembly
## in the hand. Which part each is joined to, and whether its piece stands.
class Pile extends RefCounted:
	var placed: Dictionary = {}       ## id -> true
	var _parent: Dictionary = {}      ## id -> id
	var _stands: Dictionary = {}      ## root id -> true
	var begun: bool = false
	var lowest: int = 0x7FFFFFFF

	func root(id: int) -> int:
		var at: int = id
		while int(_parent.get(at, at)) != at:
			var up: int = int(_parent[at])
			_parent[at] = int(_parent.get(up, up))
			at = up
		return at

	func put(id: int) -> void:
		placed[id] = true
		_parent[id] = id

	func join(a: int, b: int) -> void:
		var ra: int = root(a)
		var rb: int = root(b)
		if ra == rb:
			return
		_parent[rb] = ra
		if _stands.has(rb):
			_stands[ra] = true
			_stands.erase(rb)

	func stand(id: int) -> void:
		_stands[root(id)] = true

	func stands(id: int) -> bool:
		return _stands.has(root(id))


## The four tests of [param world]'s parts as [param steps] build them.
## [param lattice] holds the parts' covers (what rests on what, the stud
## joints); [param skip] is the baseplate, which is the floor. {"v", "app",
## "parts", "steps", "tests": {stands, steps, parts, whole: {"ok", "why"}},
## "ms"}, or {} when there is nothing to test or [param job] was cancelled.
static func check(world: BrickWorld, lattice: BrickLattice, library: PartLibrary,
		steps: Array[Instructions.Step], skip: Dictionary = {},
		job: Working.Job = null) -> Dictionary:
	var began: int = Time.get_ticks_msec()
	var asked: Working.Job = job if job != null else Working.Job.new()
	var bricks: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if not skip.has(brick.id) and library.mesh_for(brick.part_id) != null:
			bricks.append(brick)
	if bricks.is_empty() or steps.is_empty():
		return {}
	var by_id: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		by_id[brick.id] = brick

	asked.say("Testing it: what holds what in %s parts…" % Working.comma(bricks.size()))
	await asked.next()
	laps.clear()
	var lap_from: int = Time.get_ticks_usec()
	var judge := Stability.new()
	judge.library = library
	judge.lattice = lattice
	var contacts: Dictionary = judge.contacts(bricks)
	laps["contacts"] = Time.get_ticks_usec() - lap_from
	var boxes: Dictionary = contacts["boxes"]
	var bottom: Dictionary = {}
	var floor_cell: int = 0x7FFFFFFF
	for id: int in by_id:
		var low: int = 0x7FFFFFFF
		var packed: PackedInt32Array = boxes.get(id, PackedInt32Array())
		for at: int in range(1, packed.size(), 6):
			low = mini(low, packed[at])
		bottom[id] = low
		floor_cell = mini(floor_cell, low)
	await asked.next()
	if asked.cancelled:
		return {}

	# What holds what: the studs, as Balance and Sections read them
	# (Stability.stud_joints), what is seated in what, and every other joint
	# the build check reads, either way round. And the joints Balance weighs a
	# part by. Without what is seated, 1793-1's whip on a cone threaded on an
	# antenna was loose, and 8466-1, held by its pins, took 108 s to find
	# held by touch and went untested (2026-10-20).
	var near: Dictionary = {}
	for id: int in by_id:
		near[id] = {}
	var link := func(a: Variant, b: Variant) -> void:
		if a == b or not by_id.has(a) or not by_id.has(b):
			return
		(near[a] as Dictionary)[b] = true
		(near[b] as Dictionary)[a] = true
	var joints: Dictionary = Stability.stud_joints(contacts, library, lattice)
	for held: Dictionary in [joints["studs"], joints["seated"]]:
		for key: int in held:
			link.call(key >> 32, key & 0xFFFFFFFF)
	var entries: Array = []
	var with_paths: Array = []
	for brick: BrickWorld.Brick in bricks:
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		entries.append([brick.id, brick.transform, mesh])
		with_paths.append([brick.id, brick.transform, mesh, brick.part_id, Assemblies.path_of(brick)])
	var links: Array = []
	var both: Dictionary = Joints.both_ways(entries)
	await asked.next()
	var rounds: Dictionary = Joints.rounds(entries)
	await asked.next()
	var otherwise: Dictionary = Joints.held_otherwise(with_paths, library)
	await asked.next()
	for held: Dictionary in [both, rounds, otherwise]:
		for one: Variant in held:
			for other: Variant in (held[one] as Dictionary):
				link.call(one, other)
				links.append([int(one), int(other)])
	var balls: Dictionary = Joints.balls(entries)
	for one: Variant in balls:
		for other: Variant in (balls[one] as Dictionary):
			link.call(one, other)
	for pair: Array in Joints.through(entries):
		link.call(pair[0], pair[1])
	await asked.next()
	if asked.cancelled:
		return {}

	laps["joints"] = Time.get_ticks_usec() - lap_from - int(laps["contacts"])
	# What the finished model holds to what it stands on, and its pieces.
	var held: Dictionary = {}
	var queue: Array[int] = []
	for id: int in by_id:
		if int(bottom[id]) <= floor_cell + Balance.ON_FLOOR:
			held[id] = true
			queue.append(id)
	while not queue.is_empty():
		var here: int = queue.pop_back()
		for next: int in (near[here] as Dictionary):
			if not held.has(next):
				held[next] = true
				queue.append(next)
	# What a step is judged on: held through what joins it, as the steps score
	# judges it. Then, for a part with no exact shape, which the whole test
	# holds by these as the design check holds it by the lattice
	# ([method _exact_whole]), what rests against what is held though nothing
	# read joins them — a wheel on an old holder's pin, a tool in a figure's
	# hand: such a part is loose only when it touches nothing held. 6688-1's
	# car read 67 parts loose without it.
	var joined: Dictionary = held.duplicate()
	var touches: Dictionary = {}
	for id: int in by_id:
		if held.has(id):
			continue
		var grown: PackedInt32Array = _grown(boxes.get(id, PackedInt32Array()))
		var found: Array[int] = []
		for other: int in lattice.near_bounds(grown, id):
			if by_id.has(other) and BrickLattice.shared_cells(grown, lattice.boxes_of(other)) > 0:
				found.append(other)
		touches[id] = found
	var more: bool = true
	while more:
		more = false
		for id: int in touches:
			if held.has(id):
				continue
			for other: int in (touches[id] as Array):
				if held.has(other):
					held[id] = true
					more = true
					break
	var piece: Dictionary = {}
	var pieces: int = 0
	for start: int in by_id:
		if piece.has(start):
			continue
		piece[start] = pieces
		var pending: Array[int] = [start]
		while not pending.is_empty():
			var here: int = pending.pop_back()
			for next: int in (near[here] as Dictionary):
				if not piece.has(next):
					piece[next] = pieces
					pending.append(next)
		pieces += 1

	# The whole of it by the parts' exact shapes, on a worker.
	var lap_exact: int = Time.get_ticks_usec()
	var whole: Dictionary = await _exactly(bricks, otherwise, near, held, library, asked)
	laps["exact"] = Time.get_ticks_usec() - lap_exact
	if asked.cancelled or whole.is_empty():
		return {}

	# Step by step: each new thing held and in sight, and the build so far
	# weighed.
	var main := Pile.new()
	var side: Dictionary = {}          ## callout -> Pile
	var main_pictures := Instructions.Pictures.new()
	var side_pictures: Dictionary = {} ## callout -> Instructions.Pictures
	var nodes: Dictionary = {}         ## id -> Instructions.Node2
	var begun_pieces: Dictionary = {}
	var floating: Array = []           ## [step number, id]
	var hidden: Array = []
	var tips: Array = []               ## [step number, words]
	## How many steps were built when the time ran out; -1 when every one was.
	var built_to: int = -1
	var standing: Array = []
	var weighed: int = 0
	## What each stud joint's studs are, and what each part is, worked out
	## once for every step.
	var overlaps: Dictionary = {}
	var known: Dictionary = {}
	asked.say("Testing it: building its %d steps…" % steps.size())
	asked.count(0, steps.size())
	for step: Instructions.Step in steps:
		if asked.due():
			await asked.next()
			if asked.cancelled:
				return {}
		# Past its time a model's steps are built no further, rather than hold
		# its share: a 3,457-part ship took 38 s, most of it weighed at 676
		# steps. What it failed already is said ([method _unfinished]).
		if Time.get_ticks_msec() - began > MOST_MS:
			built_to = step.index
			break
		asked.count(step.index, steps.size())
		var in_hand: bool = step.in_callout()
		var pile: Pile = main
		var pictures: Instructions.Pictures = main_pictures
		var things: Array = []        ## PackedInt64Array of ids
		if in_hand:
			if not side.has(step.callout):
				side[step.callout] = Pile.new()
				side_pictures[step.callout] = Instructions.Pictures.new()
			pile = side[step.callout]
			pictures = side_pictures[step.callout]
			for id: int in (step.shown_ids if not step.shown_ids.is_empty() else step.brick_ids):
				if by_id.has(id):
					things.append(PackedInt64Array([id]))
		else:
			for copy: PackedInt64Array in step.copies:
				var mine := PackedInt64Array()
				for id: int in copy:
					if by_id.has(id):
						mine.append(id)
				if not mine.is_empty():
					things.append(mine)
			for id: int in step.brick_ids:
				if by_id.has(id):
					things.append(PackedInt64Array([id]))
		if things.is_empty():
			continue
		var new_ids: Array[int] = []
		for thing: PackedInt64Array in things:
			for id: int in thing:
				if not pile.placed.has(id):
					new_ids.append(id)
		# Hidden by what earlier steps built, before this one's parts go in.
		var hidden_from: int = Time.get_ticks_usec()
		for thing: PackedInt64Array in things:
			if _hidden(thing, pictures, nodes, by_id, library):
				hidden.append([step.number, thing[0]])
		laps["hidden"] = int(laps.get("hidden", 0)) + Time.get_ticks_usec() - hidden_from
		# Put in, and joined to what is there.
		for id: int in new_ids:
			pile.put(id)
			pile.lowest = mini(pile.lowest, int(bottom[id]))
		for id: int in new_ids:
			for other: int in (near[id] as Dictionary):
				if pile.placed.has(other):
					pile.join(id, other)
		# What stands: in the hand its first parts; on the model those, what
		# is on its lowest point as it stands, and the first parts of each
		# piece of the finished model a step begins.
		if not pile.begun:
			for id: int in new_ids:
				pile.stand(id)
			pile.begun = true
		if not in_hand:
			for id: int in pile.placed:
				if int(bottom[id]) <= pile.lowest + Balance.ON_FLOOR:
					pile.stand(id)
			for thing: PackedInt64Array in things:
				var which: int = int(piece[thing[0]])
				if not begun_pieces.has(which):
					begun_pieces[which] = true
					pile.stand(thing[0])
		for thing: PackedInt64Array in things:
			if not joined.has(thing[0]):
				continue
			var stood: bool = false
			for id: int in thing:
				if pile.stands(id):
					stood = true
					break
			if not stood:
				floating.append([step.number, thing[0]])
		var step_nodes: Array = []
		for id: int in new_ids:
			step_nodes.append(_node(id, nodes, by_id, library))
		pictures.built(step_nodes)
		if in_hand:
			continue
		# Weighed as the build check weighs it, the build so far.
		for id: int in new_ids:
			standing.append(by_id[id])
		var weigh_from: int = Time.get_ticks_usec()
		var balance := Balance.new()
		balance.library = library
		balance.lattice = lattice
		balance.overlaps = overlaps
		balance.known = known
		var report: Balance.Report = balance.measure(standing, [], links, contacts)
		laps["weigh"] = int(laps.get("weigh", 0)) + Time.get_ticks_usec() - weigh_from
		if report.empty:
			continue
		weighed += 1
		if report.margin < 0.0:
			tips.append([step.number, "it tips over, %s studs past the %s edge" % [
				Balance.studs(-report.margin), report.edge]])
			continue
		for one: Balance.JointLoad in report.joints:
			if one.moment > one.ultimate:
				tips.append([step.number, "%s %s %s on %d stud%s past where it lets go" % [
					_named(one.beyond_part, library), "hangs from" if one.hangs else "is held by",
					_named(one.held_part, library), one.studs, "" if one.studs == 1 else "s"]])
				break

	# Every part in its colour.
	var never: Dictionary = {}         ## "part:colour" -> [part, colour, how many, why]
	var unknown: int = 0
	for brick: BrickWorld.Brick in bricks:
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var why: String = ""
		if brick.color_code >= DIRECT_FROM:
			why = "in a colour typed in, not one parts are made in"
		elif info == null or info.custom:
			why = "made here, not a real element"
		elif info.never_made_in(brick.color_code):
			why = "never made in %s" % HiddenColours.colour_name(library, brick.color_code)
		elif not info.availability_known():
			unknown += 1
		if why.is_empty():
			continue
		var key: String = "%s:%d" % [brick.part_id, brick.color_code]
		if not never.has(key):
			never[key] = [brick.part_id, brick.color_code, 0, why]
		never[key][2] = int(never[key][2]) + 1

	var tests: Dictionary = {}
	var main_steps: int = 0
	for step: Instructions.Step in steps:
		if not step.in_callout():
			main_steps += 1
	if tips.is_empty():
		tests["stands"] = {"ok": weighed > 0, "why": ("Stands at every one of its %s"
			% _counted(main_steps, "step")) if weighed > 0 else "Nothing in it stands on anything to weigh"}
	else:
		tests["stands"] = {"ok": false, "why": _list(tips.map(func(one: Array) -> String:
			return "At step %d %s" % [int(one[0]), str(one[1])]), tips.size(), "step")}
	if floating.is_empty() and hidden.is_empty():
		tests["steps"] = {"ok": true, "why": "Every part goes onto what is already built, in sight"}
	else:
		var said: Array = []
		for one: Array in floating:
			said.append("Step %d: %s is put down in the air" % [int(one[0]),
				_named((by_id[int(one[1])] as BrickWorld.Brick).part_id, library)])
		for one: Array in hidden:
			said.append("Step %d: %s is hidden behind what is already built" % [int(one[0]),
				_named((by_id[int(one[1])] as BrickWorld.Brick).part_id, library)])
		tests["steps"] = {"ok": false, "why": _list(said, said.size(), "part")}
	if never.is_empty():
		tests["parts"] = {"ok": true, "why": "Every part is made in its colour" + (
			(" (%s the catalogue has no colours for)" % _counted(unknown, "part")) if unknown > 0 else "")}
	else:
		var said: Array = []
		for key: String in never:
			var one: Array = never[key]
			said.append("%s%s %s" % [_named(str(one[0]), library),
				(" (%d)" % int(one[2])) if int(one[2]) > 1 else "", str(one[3])])
		tests["parts"] = {"ok": false, "why": _list(said, said.size(), "kind")}
	tests["whole"] = _whole_said(whole, bricks, library)
	if built_to >= 0 and not _unfinished(tests, built_to, steps.size()):
		return {"untested": "it is too big to test in the time a share takes (%s)"
			% _counted(bricks.size(), "part"), "parts": bricks.size(), "steps": steps.size()}
	return {"v": VERSION, "app": BuildInfo.version(), "parts": bricks.size(), "steps": steps.size(),
		"tests": tests, "ms": Time.get_ticks_msec() - began}


## A model whose steps were built only to step [param built_to] of [param
## of] before the time ran out: its stands and steps tests, where they found
## nothing wrong so far, say they were not finished, and are not passed. True
## when another test failed, so the finding says why it is not Tested;
## false when nothing failed, and it goes untested, as it went before.
## Orthanc's 9,541 parts in 1,494 steps run out of time, and it fails the
## whole test (models175).
static func _unfinished(tests: Dictionary, built_to: int, of: int) -> bool:
	var failed_already: bool = false
	for name: String in ["stands", "steps", "parts", "whole"]:
		if not bool((tests[name] as Dictionary)["ok"]):
			failed_already = true
	if not failed_already:
		return false
	var so_far: String = "Not finished: built to step %d of %d in the time a share takes" % [built_to, of]
	if bool((tests["stands"] as Dictionary)["ok"]) or built_to == 0:
		tests["stands"] = {"ok": false, "why": so_far + (", standing at each" if built_to > 0 else "")}
	if bool((tests["steps"] as Dictionary)["ok"]):
		tests["steps"] = {"ok": false, "why": so_far + (", each part on what was built, in sight"
			if built_to > 0 else "")}
	return true


## The model by its parts' exact shapes (ExactCheck), as the design check
## reads a whole design. The shapes are read here a part a slice, and in a
## browser fetched, as the design check waits for them; the rest runs on a
## worker ([method _exact_whole]). [param otherwise] is what glue, magnets
## and flexible things hold (Joints.held_otherwise), [param near] every joint
## read, and [param held] what they and what rests on what hold, by brick id:
## a part with no exact shape is judged by those. {} when [param asked] was
## cancelled.
static func _exactly(bricks: Array, otherwise: Dictionary, near: Dictionary, held: Dictionary,
		library: PartLibrary, asked: Working.Job) -> Dictionary:
	var ids: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		ids[brick.part_id] = true
	asked.say("Testing it: reading its parts' exact shapes…")
	for part_id: String in ids:
		if asked.due():
			await asked.next()
			if asked.cancelled:
				return {}
		Exact.shape_for(library, part_id)
	var deadline: int = Time.get_ticks_msec() + Assistant.FETCH_WAIT_MS
	var wanted: Array = ids.keys().filter(func(part_id: String) -> bool:
		return not Exact.known(library, part_id) and library.is_exact_on_its_way(part_id))
	while not wanted.is_empty() and Time.get_ticks_msec() < deadline:
		await Engine.get_main_loop().process_frame
		if asked.cancelled:
			return {}
		wanted = wanted.filter(func(part_id: String) -> bool:
			return not Exact.known(library, part_id) and library.is_exact_on_its_way(part_id))
	var shapes: Dictionary = Exact.shapes_for(library, ids.keys())
	var parts: Array = []          ## [part id, Transform3D, Lbm.PartMesh] each
	var number: Dictionary = {}    ## brick id -> its number in parts
	for brick: BrickWorld.Brick in bricks:
		number[brick.id] = parts.size()
		parts.append([brick.part_id, brick.transform, library.mesh_for(brick.part_id)])
	var glued: Array = []
	for one: Variant in otherwise:
		for other: Variant in (otherwise[one] as Dictionary):
			if number.has(one) and number.has(other):
				glued.append([int(number[one]), int(number[other])])
	var joints: Array = []
	for one: Variant in near:
		for other: Variant in (near[one] as Dictionary):
			if int(one) < int(other) and number.has(one) and number.has(other):
				joints.append([int(number[one]), int(number[other])])
	var resting: Dictionary = {}
	for id: Variant in held:
		if number.has(id):
			resting[int(number[id])] = true
	asked.say("Testing it: what holds what, by the parts' exact shapes…")
	var found: Variant = await WorkerTasks.awaited(func() -> Dictionary:
		return _exact_whole(parts, shapes, glued, joints, resting), "test a model's parts", library)
	return found if found is Dictionary else {}


## How far a part's exact shapes may be off the floor and stand on it, LDU
## (ExactCheck.ON_GROUND).
const ON_GROUND := ExactCheck.ON_GROUND


## What [method _exactly] finds, on a worker: {"into": [[a, b, depth], ...]
## the pairs whose real shapes pass into each other by more than 1 LDU, the
## deepest first, past what a joint's own parts do and gears in mesh
## (ExactCheck.forgiven, as the design check forgives them); "pieces": how
## many it is in; "apart": [{kind, part, on, size}, ...] each piece but the
## model, the biggest first, kind "falls" (held by nothing, it does not stand
## where it is), "away" (it stands, and comes away in the hand), "missed"
## (that, on another part's stud grid where it has no stud) or "apart" (on
## the floor beside the model)}. Numbers are [param parts]'.
##
## Two parts are joined by BrickNet's connections, by [param glued], and by
## [param joints] where either has no exact shape. The piece with the most
## parts on the floor is the model. Another that stands where it is and is
## caught there stays with it, as the orrery's planet rings do (connect166,
## models175: ExactCheck.comes_away), unless what catches it comes away
## itself; and so does one with a part of no exact shape that [param resting]
## holds, as the design check holds such a part by the lattice.
static func _exact_whole(parts: Array, shapes: Dictionary, glued: Array, joints: Array,
		resting: Dictionary) -> Dictionary:
	var count: int = parts.size()
	var exact := ExactCheck.new(shapes, count)
	var low := PackedFloat64Array()
	low.resize(count)
	var floor_y: float = INF
	var entries: Array = []
	for n: int in count:
		exact.place(n, parts[n][0], parts[n][1])
		var item: Exact.Item = exact.items[n]
		var mesh: Lbm.PartMesh = parts[n][2]
		low[n] = item.lo.y if item != null else ((parts[n][1] as Transform3D) * mesh.bounds).position.y
		floor_y = minf(floor_y, low[n])
		entries.append([n, parts[n][1], mesh, parts[n][0]])
	exact.ground = floor_y
	var meshing: Dictionary = Joints.meshing(entries)
	var into: Array = []
	for found: Dictionary in exact.collisions({}):
		var a: int = found["a"]
		var b: int = found["b"]
		if (meshing.get(a, {}) as Dictionary).has(b) or (meshing.get(b, {}) as Dictionary).has(a) \
				or exact.forgiven(a, b):
			continue
		into.append([a, b, float(found["depth"])])
	into.sort_custom(func(x: Array, y: Array) -> bool: return x[2] > y[2])

	var extra: Array = glued.duplicate()
	for pair: Array in joints:
		if exact.items[pair[0]] == null or exact.items[pair[1]] == null:
			extra.append(pair)
	var root: PackedInt32Array = exact.pieces(extra)
	var members: Dictionary = {}       ## root -> its parts
	var on_floor: Dictionary = {}      ## root -> true
	var by_covers: Dictionary = {}     ## root -> true: a part of no shape held as before
	for n: int in count:
		var key: int = root[n]
		if not members.has(key):
			members[key] = []
		(members[key] as Array).append(n)
		if low[n] - floor_y <= ON_GROUND:
			on_floor[key] = true
		if exact.items[n] == null and resting.has(n):
			by_covers[key] = true
	var model: int = -1
	for key: int in on_floor:
		if model < 0 or (members[key] as Array).size() > (members[model] as Array).size():
			model = key
	# What stands where it is and is caught there stays; what falls, and what
	# comes away, catches nothing, asked again until nothing more comes away.
	var stands: Dictionary = {}
	var gone: Dictionary = {}
	for key: int in members:
		if key == model or by_covers.has(key):
			continue
		stands[key] = not on_floor.has(key) and exact.rests(members[key])
		if not stands[key]:
			for n: int in members[key]:
				gone[n] = true
	var away: Dictionary = {}
	var more: bool = true
	while more:
		more = false
		for key: int in stands:
			if stands[key] and not away.has(key) and exact.comes_away(members[key], gone):
				away[key] = true
				more = true
				for n: int in members[key]:
					gone[n] = true
	var apart: Array = []
	for key: int in stands:
		if stands[key] and not away.has(key):
			continue
		apart.append({"kind": "apart" if on_floor.has(key) else "away" if away.has(key) else "falls",
			"part": (members[key] as Array)[0], "on": -1, "size": (members[key] as Array).size(),
			"key": key})
	apart.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["size"]) > int(y["size"]))
	# Those named, by the part that rests on something not of its piece.
	for one: Dictionary in apart.slice(0, NAMED):
		var them: Array = members[one["key"]]
		for n: int in them:
			var under: int = exact.under(n)
			if under >= 0 and not them.has(under):
				one["part"] = n
				one["on"] = under
				break
		if one["kind"] == "away":
			var missed: int = exact.on_missing_stud(them)
			if missed >= 0:
				one["kind"] = "missed"
				one["on"] = missed
		one.erase("key")
	return {"into": into, "pieces": 1 + apart.size(), "apart": apart}


## The whole test, said: one piece, every part held and none in another, or
## what is not, in a person's words.
static func _whole_said(whole: Dictionary, bricks: Array, library: PartLibrary) -> Dictionary:
	var name := func(n: int) -> String: return _named((bricks[n] as BrickWorld.Brick).part_id, library)
	var into: Array = whole.get("into", [])
	var apart: Array = whole.get("apart", [])
	if into.is_empty() and apart.is_empty():
		return {"ok": true, "why": "One piece: every part is held by a stud or a joint, or caught "
			+ "where it is, and none passes into another"}
	var pairs: Array = into.map(func(one: Array) -> String:
		return "%s into %s by %s LDU" % [name.call(int(one[0])), name.call(int(one[1])),
			ExactCheck._n(snappedf(float(one[2]), 0.1))])
	var pieces: Array = apart.map(func(one: Dictionary) -> String:
		var who: String = name.call(int(one["part"]))
		var rest: int = int(one["size"]) - 1
		if rest > 0:
			who += " and %s with it" % _counted(rest, "part")
		var on: String = name.call(int(one["on"])) if int(one["on"]) >= 0 else ""
		match str(one["kind"]):
			"apart":
				return "%s stands apart" % who
			"missed":
				return "%s stands on %s where it has no stud" % [who, on]
			"away":
				return ("%s rests on %s with nothing holding it" % [who, on]) if not on.is_empty() \
					else "%s rests with nothing holding it" % who
		return ("%s rests on %s, held by nothing, and falls off" % [who, on]) if not on.is_empty() \
			else "%s is held by nothing and falls" % who)
	var heads := PackedStringArray()
	if not into.is_empty():
		heads.append("%s %s into each other: " % [_counted(into.size(), "pair"),
			"of parts passes" if into.size() == 1 else "of parts pass"])
	if not apart.is_empty():
		heads.append("%s in %s, not one, so it comes apart when it is lifted: " % [
			"and it is" if not into.is_empty() else "It is",
			_counted(int(whole.get("pieces", 1 + apart.size())), "piece")])
	# The site keeps MOST_WHY characters of it (api/_tested.js): each list
	# names what fits in its share, after the heads and its "and N more".
	var room: int = maxi(40, (MOST_WHY - "".join(heads).length() - 2) / heads.size() - 24)
	var said := PackedStringArray()
	var at: int = 0
	if not into.is_empty():
		said.append(heads[at] + _list_within(pairs, into.size(), "pair", room))
		at += 1
	if not apart.is_empty():
		said.append(heads[at] + _list_within(pieces, apart.size(), "piece", room))
	return {"ok": false, "why": "; ".join(said)}


## Whether every test passed.
static func passed(found: Dictionary) -> bool:
	var tests: Variant = found.get("tests")
	if not tests is Dictionary:
		return false
	for name: String in ["stands", "steps", "parts", "whole"]:
		var one: Variant = (tests as Dictionary).get(name)
		if not one is Dictionary or not bool((one as Dictionary).get("ok", false)):
			return false
	return true


## The tests that failed, by name.
static func failed(found: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var tests: Dictionary = found.get("tests", {})
	for name: String in ["stands", "steps", "parts", "whole"]:
		var one: Dictionary = tests.get(name, {})
		if not bool(one.get("ok", false)):
			out.append(name)
	return out


## What the share panel says of it to its owner: that it is marked Tested,
## or which test it failed and why, plainly. Only its owner sees a failure.
static func words(found: Dictionary) -> String:
	if found.has("untested"):
		return "Not tested: %s." % str(found["untested"])
	if found.is_empty():
		return "Not tested: its steps could not be worked out to test."
	if passed(found):
		return "Marked Tested: it stands at every step, every step can be reached, every part " \
			+ "is made in its colour, and it is one piece, every part held and none in another."
	var tests: Dictionary = found["tests"]
	var said := PackedStringArray()
	for name: String in failed(found):
		said.append(str((tests[name] as Dictionary).get("why", name)))
	return "Not marked Tested (only you see why): %s." % "; ".join(said).trim_suffix(".")


## A model file's fingerprint as the server takes it (api/_directory.js
## modelHash): each line trimmed, the blank ones left out, joined by line
## feeds. A finding is the finding of exactly this file.
static func fingerprint(text: String) -> String:
	var kept := PackedStringArray()
	for line: String in text.trim_prefix("﻿").replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty():
			kept.append(trimmed)
	return "\n".join(kept).sha256_text()


## Whether [param thing] shows less than a tenth of itself from the front and
## from the back, with what earlier steps built in front of it.
static func _hidden(thing: PackedInt64Array, pictures: Instructions.Pictures, nodes: Dictionary,
		by_id: Dictionary, library: PartLibrary) -> bool:
	var own: Dictionary = {}
	for id: int in thing:
		own[id] = true
	for v: int in 2:
		var mine: Dictionary = {}
		var before: Dictionary = {}
		for id: int in thing:
			var node: Instructions.Node2 = _node(id, nodes, by_id, library)
			var drawn: Dictionary = pictures.pixels_of(node, v)
			for pixel: int in drawn:
				mine[pixel] = maxf(float(mine.get(pixel, -INF)), float(drawn[pixel]))
			for other: Instructions.Node2 in pictures.in_front(node):
				if not own.has(other.id):
					before[other.id] = other
		if mine.is_empty():
			return false
		var open: Dictionary = mine.duplicate()
		for other: Instructions.Node2 in before.values():
			if open.is_empty():
				break
			Instructions.Pictures._cover(open, pictures.pixels_of(other, v))
		if float(open.size()) / float(mine.size()) >= SEEN:
			return false
	return true


## [param packed] boxes each a cell bigger every way: what touches them.
static func _grown(packed: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = packed.duplicate()
	for at: int in range(0, out.size(), 6):
		out[at] -= 1
		out[at + 1] -= 1
		out[at + 2] -= 1
		out[at + 3] += 1
		out[at + 4] += 1
		out[at + 5] += 1
	return out


## The planner's node for a part: its id and its box where it stands.
static func _node(id: int, nodes: Dictionary, by_id: Dictionary, library: PartLibrary) -> Instructions.Node2:
	var known: Variant = nodes.get(id)
	if known != null:
		return known
	var brick: BrickWorld.Brick = by_id[id]
	var node := Instructions.Node2.new()
	node.id = id
	node.part_id = brick.part_id
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
	node.box = brick.transform * mesh.bounds if mesh != null else AABB(brick.transform.origin, Vector3.ZERO)
	nodes[id] = node
	return node


## A part as a person reads its name: "Plate 1 x 2", not "Plate  1 x  2".
static func _named(part: String, library: PartLibrary) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part)
	var name: String = info.name if info != null and not info.name.is_empty() else part
	while name.contains("  "):
		name = name.replace("  ", " ")
	return name.strip_edges().trim_prefix("~")


static func _counted(n: int, one: String) -> String:
	return "%s %s%s" % [Working.comma(n), one, "" if n == 1 else "s"]


## The first few of [param said] that fit in [param room] characters (the
## first always), and how many more of [param total].
static func _list_within(said: Array, total: int, what: String, room: int) -> String:
	var out: String = ""
	var shown: int = 0
	for one: Variant in said.slice(0, NAMED):
		var longer: String = str(one) if shown == 0 else out + "; " + str(one)
		if shown > 0 and longer.length() > room:
			break
		out = longer
		shown += 1
	if total > shown:
		out += "; and %s more" % _counted(total - shown, what)
	return out


## The first few of [param said], and how many more of [param total].
static func _list(said: Array, total: int, what: String) -> String:
	var shown: Array = said.slice(0, NAMED)
	var out: String = "; ".join(PackedStringArray(shown))
	if total > shown.size():
		out += "; and %s more" % _counted(total - shown.size(), what)
	return out
