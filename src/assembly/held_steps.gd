## Worked-out steps a person can build by: each part put in at the first step
## where something standing holds it, and a part a step would put behind what
## is already built put in with what holds it, by the Tested mark's own rules
## and joints (Tested.Steps, Tested.holds_into). The planner reads what rests
## on what by its own covers and boxes, and the mark by the joints: of the
## twelve house models seed211 made with the app's own designer (2026-10-24),
## eight failed the steps test as saved (the fox put 122 parts down before
## what holds them), and each was put right by a script
## (tools/house_models/fixsteps.gd) that a person designing with the
## assistant never runs. Here it is the planner's last stage, for every model
## whose steps it works out (Instructions.plan, plan_paced): the timeline,
## the booklet, a save, a share.
##
## The planner's order is kept wherever it already builds: its courses, its
## regions, its sub-assemblies built on the side. Only a part that would be in
## the air waits, for the first step where it is held, and only a part that
## would be hidden goes in sooner, with what holds it. A sub-assembly's own
## steps in the hand, and the sub-assemblies a step puts on, stay as they are.
class_name HeldSteps
extends RefCounted

## How many times the parts the steps hide are put in sooner and the steps
## read again.
const ROUNDS := 4
## The most steps after the last for the parts still waiting then, each what
## stands with what is in by then.
const MOST_AFTER := 64
## The most later parts one step takes in sooner, each with a part of it whose
## cover meets its own both ways round ([method _put]). Tuned on the steps
## score's tune sample (docs/INSTRUCTIONS.md, buildorder): 8 left 2.1% of
## things in under one already there, 16 1.5%, 32 1.4%.
const PULL_MOST := 32
## The most steps a part that would stand waits for what it rests on
## ([method Under._waited]). Round a sub-assembly put on whole, what it waits
## for may wait for it in turn: 4 left 7347's truck dumping its cab at the
## last step, and 8, 16 and 32 left 2.1%, 1.5% and 1.4% of things in under.
const PATIENCE := 32

## Whether the planner's steps are put right: off only for a probe, to see
## what the planner alone would have made.
static var mends: bool = true
## What the last mend did, for a probe: {"waited": parts put in later than
## planned, "sooner": parts put in with what holds them, "floating" and
## "hidden": what the steps test still finds, "rounds", "ms"}.
static var said: Dictionary = {}


## [param steps], worked out for [param world]'s parts but [param skip], put
## right where they are. A slice at a time with a [param job], and the steps
## read on a worker; at once without one. Returns what it read of the model,
## for [method faults_of] to judge other steps of it by, and "faults", what
## the steps it mended still put down in the air and hide, as faults_of
## counts them: {} when it mended nothing.
static func mend_into(steps: Array[Instructions.Step], world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}, job: Working.Job = null) -> Dictionary:
	said = {}
	if not mends:
		return {}
	var began: int = Time.get_ticks_msec()
	var bricks: Array = []
	var by_id: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if not skip.has(brick.id) and library.mesh_for(brick.part_id) != null:
			bricks.append(brick)
			by_id[brick.id] = brick
	if bricks.size() < 2 or steps.is_empty():
		return {}
	# The parts' covers in a lattice of their own, as a share's test has them
	# (SharedPages.pages_for).
	var covers := Builder.new()
	var lattice := BrickLattice.new()
	lattice.keeps_columns = false
	for brick: BrickWorld.Brick in bricks:
		if job != null and job.due():
			await job.next()
			if job.cancelled:
				covers.free()
				return {}
		lattice.occupy_boxes(brick.id, covers.boxes_for(library.mesh_for(brick.part_id), brick.transform))
	covers.free()
	var holding: Dictionary = {}
	await Tested.holds_into(holding, bricks, lattice, library, job)
	if holding.is_empty() or job != null and job.cancelled:
		return {}
	Under.read_into(holding)
	# Each part's box where it stands, made here: nothing on the worker reads
	# the library.
	var nodes: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		Tested._node(brick.id, nodes, by_id, library)
	var slots: Array = _slots(steps, by_id)
	var got: Variant
	if job != null:
		got = await WorkerTasks.awaited(func() -> Dictionary:
			return _mended(slots, holding, by_id, nodes, library), "put a model's steps on what holds them",
			library)
		if job.cancelled or not got is Dictionary:
			return {}
	else:
		got = _mended(slots, holding, by_id, nodes, library)
	var mended: Dictionary = got
	var out: Array[Instructions.Step] = _steps_of(mended["slots"], world)
	steps.clear()
	steps.append_array(out)
	said = mended["said"]
	said["ms"] = Time.get_ticks_msec() - began
	return {"holding": holding, "by_id": by_id, "nodes": nodes,
		"faults": [int(said["floating"]), int(said["hidden"]), int(said["under"]),
			hand_floating(out, by_id, holding["near"])] as Array[int]}


## How many parts [param steps] put down in the air, how many behind what is
## already built, by the steps test's own rules (Tested.check), how many in
## under a part already there ([class Under]), and how many a sub-assembly's
## steps in the hand put down apart from what it began ([class Hand]), of the
## model as [param read] ([method mend_into]'s) has it: [in the air, hidden,
## under, apart in the hand]. With [param most], it stops once any is past
## most's: they only grow. Reads nothing but what it is given, so it runs on
## a worker.
static func faults_of(steps: Array[Instructions.Step], read: Dictionary, library: PartLibrary,
		most: Array[int] = []) -> Array[int]:
	var test := Tested.Steps.new(read["by_id"], read["holding"], library)
	test.nodes = read["nodes"]
	var under := Under.new(read["holding"])
	var hand := Hand.new((read["holding"] as Dictionary)["near"])
	for step: Instructions.Step in steps:
		var things: Array = test.things_of(step)
		if things.is_empty():
			continue
		test.take(step, things)
		if step.in_callout():
			hand.take(step, things)
		else:
			under.take(things)
		if not most.is_empty() and (test.floating.size() > most[0] or test.hidden.size() > most[1]
				or most.size() > 2 and under.faults > most[2] or most.size() > 3 and hand.floating > most[3]):
			return [test.floating.size(), test.hidden.size(), under.faults, hand.floating]
	test.finish()
	return [test.floating.size(), test.hidden.size(), under.faults, hand.floating]


## Things the sub-assemblies of [param steps] built in the hand put down
## apart from what their first steps began ([class Hand]).
static func hand_floating(steps: Array[Instructions.Step], by_id: Dictionary, near: Dictionary) -> int:
	var hand := Hand.new(near)
	for step: Instructions.Step in steps:
		if not step.in_callout():
			continue
		var things: Array = []
		for id: int in (step.shown_ids if not step.shown_ids.is_empty() else step.brick_ids):
			if by_id.has(id):
				things.append(PackedInt64Array([id]))
		hand.take(step, things)
	return hand.floating


## A sub-assembly built in the hand is held as one piece: what its first step
## puts down, and what is joined to that. A thing a later step puts down
## apart from it is in the air, as the steps score reads it (src/dev/
## steps_score.gd, floating on the table), though the steps test lets the
## first parts of each of the author's sub-models stand (Tested.Steps.take):
## the lighthouse's sub-models built whole in one box, the robot's arm
## beside its body, each begun on nothing. Kept for the steps a model of
## sub-models keeps (Instructions._kept), they put 1.4% of 100 real sets'
## steps in the air that the order worked out did not (buildorder).
class Hand extends RefCounted:
	var near: Dictionary
	## callout -> its parts down so far (id -> true).
	var _of: Dictionary = {}
	## id -> the part it is joined to, toward its piece's root.
	var _up: Dictionary = {}
	## The roots of the pieces held: those the first step began.
	var _held: Dictionary = {}
	var floating: int = 0

	func _init(given_near: Dictionary) -> void:
		near = given_near

	## [param things], each a PackedInt64Array of ids, put down as [param
	## step]'s in its box.
	func take(step: Instructions.Step, things: Array) -> void:
		if things.is_empty():
			return
		var first: bool = not _of.has(step.callout)
		if first:
			_of[step.callout] = {}
		var mine: Dictionary = _of[step.callout]
		var fresh: Array[int] = []
		for thing: PackedInt64Array in things:
			for id: int in thing:
				if not mine.has(id):
					mine[id] = true
					_up[id] = id
					fresh.append(id)
					if first:
						_held[id] = true
		for id: int in fresh:
			for other: int in (near.get(id, {}) as Dictionary):
				if mine.has(other):
					_join(id, other)
		for thing: PackedInt64Array in things:
			var held: bool = false
			for id: int in thing:
				if _held.has(_root(id)):
					held = true
					break
			if not held:
				floating += 1

	func _root(id: int) -> int:
		while int(_up[id]) != id:
			_up[id] = _up[_up[id]]
			id = _up[id]
		return id

	func _join(one: int, other: int) -> void:
		var a: int = _root(one)
		var b: int = _root(other)
		if a == b:
			return
		_up[a] = b
		if _held.has(a):
			_held[b] = true


## What rests on what by the parts' covers, as the steps score reads a part
## put in under one already there (src/dev/steps_score.gd, "blocked"): its
## cover lifted a cell meets another's (Stability.contacts), and no pin, axle,
## clip, ball or hole holds the two, which go in along their line. A part goes
## in once what it rests on is in, or with it: put in after, it goes in under
## a part already there, which a hand cannot press on from above. In 100 real
## sets the planner's steps put 5.0% of what they put in under one already
## there, against the authors' 1.2% (docs/INSTRUCTIONS.md, buildorder): the
## order reads what rests on what by the studs and the boxes, and waits for
## what holds a part, not for all it rests on.
class Under extends RefCounted:
	## id -> what it rests on, and id -> what rests on it.
	var rests: Dictionary = {}
	var carries: Dictionary = {}
	## id -> the parts whose covers meet its own both ways round: whichever of
	## two goes in second goes in under the first, so they go in together.
	var mutual: Dictionary = {}
	## id -> the step of the model it went in at, counted from 1.
	var at: Dictionary = {}
	## The parts a later step of the main build puts in, each of which may go
	## in sooner with a part [member mutual] to it (HeldSteps._put).
	var later: Dictionary = {}
	## id -> the step it first stood at and waited for what it rests on; a
	## sub-assembly's copies by their first part.
	var since: Dictionary = {}
	var step: int = 0
	## Things put in under one already there.
	var faults: int = 0

	func _init(holding: Dictionary) -> void:
		rests = holding.get("rests", {})
		carries = holding.get("carries", {})
		mutual = holding.get("mutual", {})

	## Into [param holding] (Tested.holds_into's): "rests", "carries" and
	## "mutual".
	static func read_into(holding: Dictionary) -> void:
		var above: Dictionary = (holding["contacts"] as Dictionary)["above"]
		var jointed: Dictionary = holding["jointed"]
		var otherwise: Dictionary = holding["otherwise"]
		var rests: Dictionary = {}
		var carries: Dictionary = {}
		var mutual: Dictionary = {}
		var held := func(a: int, b: int) -> bool:
			return (jointed.has(a) and (jointed[a] as Dictionary).has(b)
				or jointed.has(b) and (jointed[b] as Dictionary).has(a)) \
				and not (otherwise.has(a) and (otherwise[a] as Dictionary).has(b)
					or otherwise.has(b) and (otherwise[b] as Dictionary).has(a))
		for low: Variant in above:
			for high: Variant in (above[low] as Dictionary):
				var a: int = int(low)
				var b: int = int(high)
				# Covers that meet both ways round (a stud's into the part over
				# it) say neither rests on the other: each would wait for the
				# other, and a model's plates all for one another.
				if a == b or held.call(a, b):
					continue
				if above.has(high) and (above[high] as Dictionary).has(low):
					if not mutual.has(a):
						mutual[a] = PackedInt64Array()
					var with: PackedInt64Array = mutual[a]
					with.append(b)
					mutual[a] = with
					continue
				if not rests.has(b):
					rests[b] = PackedInt64Array()
				if not carries.has(a):
					carries[a] = PackedInt64Array()
				# Not appended in place: a packed array read out of a Dictionary
				# is a copy.
				var on: PackedInt64Array = rests[b]
				on.append(a)
				rests[b] = on
				var over: PackedInt64Array = carries[a]
				over.append(b)
				carries[a] = over
		holding["rests"] = rests
		holding["carries"] = carries
		holding["mutual"] = mutual

	## [param things] (each a PackedInt64Array of ids) put on the model as its
	## next step: a fault for each that goes in under one already there.
	func take(things: Array) -> void:
		step += 1
		for thing: PackedInt64Array in things:
			var below: bool = false
			for id: int in thing:
				for over: int in carries.get(id, PackedInt64Array()):
					if int(at.get(over, step)) < step and not thing.has(over):
						below = true
						break
				if below:
					break
			if below:
				faults += 1
		for thing: PackedInt64Array in things:
			for id: int in thing:
				if not at.has(id):
					at[id] = step

	## Of [param trying], in order, those [param standing] has (id -> true)
	## that may go in now, with [param going] (id -> true): every part each
	## rests on is in, going in, or one of them that may, and no part of
	## [param together] whose cover meets its own both ways round is left out.
	## One that has waited as long as it may ([method _waited]) goes in anyway.
	func ready_of(trying: Array[int], standing: Dictionary, going: Dictionary,
			together: Dictionary) -> Array[int]:
		var left: Dictionary = {}
		for id: int in trying:
			if standing.has(id):
				left[id] = true
		var gone: Array[int] = []
		for id: int in trying:
			if left.has(id) and not _waited(id) and (not _on_built(id, left, going)
					or _apart(id, left, together, going)):
				gone.append(id)
		while not gone.is_empty():
			var id: int = gone.pop_back()
			if not left.erase(id):
				continue
			for over: int in carries.get(id, PackedInt64Array()):
				if left.has(over) and not _waited(over):
					gone.append(over)
			if together.has(id):
				for other: int in mutual.get(id, PackedInt64Array()):
					if left.has(other) and not _waited(other):
						gone.append(other)
		var out: Array[int] = []
		for id: int in trying:
			if left.has(id):
				out.append(id)
			elif standing.has(id) and not since.has(id):
				since[id] = step
		return out

	## Whether [param id], which stands, has waited for what it rests on as
	## long as it may: what it waits for may wait for it in turn, round a
	## sub-assembly put on whole, and the last step would take both.
	func _waited(id: int) -> bool:
		return since.has(id) and step - int(since[id]) >= HeldSteps.PATIENCE

	## Whether a part of [param together] whose cover meets [param id]'s both
	## ways round is not in, nor going in with it ([param left]).
	func _apart(id: int, left: Dictionary, together: Dictionary, going: Dictionary) -> bool:
		for other: int in mutual.get(id, PackedInt64Array()):
			if together.has(other) and not left.has(other) and not at.has(other) and not going.has(other):
				return true
		return false

	## Whether everything [param id] rests on is in, or in [param left] or
	## [param going].
	func _on_built(id: int, left: Dictionary, going: Dictionary) -> bool:
		for low: int in rests.get(id, PackedInt64Array()):
			if not at.has(low) and not left.has(low) and not going.has(low):
				return false
		return true

	## Whether every part [param copies] put on rest on what is in, on one
	## another, or on [param ids].
	func copies_ready(copies: Array, ids: Array[int]) -> bool:
		if copies.is_empty():
			return true
		var going: Dictionary = {}
		for copy: PackedInt64Array in copies:
			for id: int in copy:
				going[id] = true
		for id: int in ids:
			going[id] = true
		var first: int = (copies[0] as PackedInt64Array)[0]
		if _waited(first):
			return true
		for copy: PackedInt64Array in copies:
			for id: int in copy:
				if not _on_built(id, {}, going):
					if not since.has(first):
						since[first] = step
					return false
		return true


## The main build's steps, each a slot: {"step", "ids": the parts it puts in
## that the tests judge, "other": its parts with no shape here, "before": the
## steps in the hand of the sub-assembly it puts on, each an entry ([method
## _entries])}.
static func _slots(steps: Array[Instructions.Step], by_id: Dictionary) -> Array:
	var slots: Array = []
	var box: Array[Instructions.Step] = []
	for step: Instructions.Step in steps:
		if step.in_callout():
			box.append(step)
			continue
		var ids: Array[int] = []
		var other: Array[int] = []
		for id: int in step.brick_ids:
			if by_id.has(id):
				ids.append(id)
			else:
				other.append(id)
		slots.append({"step": step, "ids": ids, "other": other, "before": _entries(box, step, by_id)})
		box = []
	if not box.is_empty():
		slots.append({"step": null, "ids": [] as Array[int], "other": [] as Array[int],
			"before": _entries(box, null, by_id)})
	return slots


## A sub-assembly's steps in the hand, each an entry: {"step", "units": each
## part of the copy its pictures show with the same part of each other copy
## ([param attach]'s copies, which list each copy's parts in its steps'
## order), the shown one first, "shown": the shown parts with no shape here,
## "rest": the other copies' parts that have no twin found}.
static func _entries(box: Array[Instructions.Step], attach: Instructions.Step, by_id: Dictionary) -> Array:
	var where: Dictionary = {}        ## id -> [copy, place in it]
	var copies: Array = attach.copies if attach != null else []
	for copy: int in copies.size():
		for n: int in (copies[copy] as PackedInt64Array).size():
			where[copies[copy][n]] = [copy, n]
	var out: Array = []
	for step: Instructions.Step in box:
		var here: Dictionary = {}
		for id: int in step.brick_ids:
			here[id] = true
		var units: Array = []
		var shown: Array[int] = []
		var used: Dictionary = {}
		for id: int in (step.shown_ids if not step.shown_ids.is_empty() else step.brick_ids):
			used[id] = true
			if not by_id.has(id):
				shown.append(id)
				continue
			var unit: Array[int] = [id]
			var at: Variant = where.get(id)
			if at != null and int(at[0]) == 0:
				for copy: int in range(1, copies.size()):
					var twin: int = int(copies[copy][at[1]]) if int(at[1]) < (copies[copy] as PackedInt64Array).size() else 0
					if here.has(twin) and not used.has(twin) and by_id.has(twin) \
							and (by_id[twin] as BrickWorld.Brick).part_id == (by_id[id] as BrickWorld.Brick).part_id:
						unit.append(twin)
						used[twin] = true
			units.append(unit)
		var rest: Array[int] = []
		for id: int in step.brick_ids:
			if not used.has(id):
				rest.append(id)
		out.append({"step": step, "units": units, "shown": shown, "rest": rest})
	return out


## The sub-assemblies built in the hand put right, each on its own: there
## only its first step's parts stand, so the first part of each piece of it
## goes in at its first step (a pair of shoes, a dragon's two horns, built as
## one sub-assembly, is two pieces until it is put on), and then each part
## waits for the step of it where it is held, the last step taking what still
## waits. [param slots] with their entries put right.
static func _in_hand(slots: Array, holding: Dictionary, by_id: Dictionary, nodes: Dictionary,
		library: PartLibrary) -> Array:
	var near: Dictionary = holding["near"]
	var test := Tested.Steps.new(by_id, holding, library)
	test.nodes = nodes
	var out: Array = []
	for slot: Dictionary in slots:
		var entries: Array = slot["before"]
		if entries.is_empty():
			out.append(slot)
			continue
		# Its pieces, by what joins its own parts.
		var unit_of: Dictionary = {}  ## shown id -> its unit
		var order: Array[int] = []
		for entry: Dictionary in entries:
			for unit: Array[int] in entry["units"]:
				unit_of[unit[0]] = unit
				order.append(unit[0])
		var piece: Dictionary = {}
		for start: int in order:
			if piece.has(start):
				continue
			piece[start] = start
			var pending: Array[int] = [start]
			while not pending.is_empty():
				var here: int = pending.pop_back()
				for other: int in (near[here] as Dictionary):
					if unit_of.has(other) and not piece.has(other):
						piece[other] = start
						pending.append(other)
		var queue: Array = []         ## per entry, its units as tried
		for entry: Dictionary in entries:
			queue.append([])
		var begun: Dictionary = {}
		for n: int in entries.size():
			for unit: Array[int] in (entries[n] as Dictionary)["units"]:
				var which: int = int(piece[unit[0]])
				if n > 0 and not begun.has(which):
					(queue[0] as Array).append(unit)
				else:
					(queue[n] as Array).append(unit)
				begun[which] = true
		var mended: Array = []
		var waiting: Array = []
		for n: int in entries.size():
			var entry: Dictionary = entries[n]
			var trying: Array = waiting + (queue[n] as Array)
			waiting = []
			var things: Array = []
			for unit: Array[int] in trying:
				things.append(PackedInt64Array([unit[0]]))
			var stands: Array[bool] = test.stands_if(entry["step"], things)
			var kept: Array = []
			var taken: Array = []
			for k: int in trying.size():
				if stands[k] or n == entries.size() - 1:
					kept.append(trying[k])
					taken.append(things[k])
				else:
					waiting.append(trying[k])
			if not taken.is_empty():
				test.take(entry["step"], taken)
			mended.append({"step": entry["step"], "units": kept, "shown": entry["shown"],
				"rest": entry["rest"]})
		out.append({"step": slot["step"], "ids": slot["ids"], "other": slot["other"], "before": mended})
	return out


## [param slots] put right: each part waiting for the step that holds it,
## and in rounds, each part the steps hide put in with what holds it, kept
## where that leaves fewer faults. {"slots", "said"}. Reads nothing but what
## it is given, so it runs on a worker.
static func _mended(slots: Array, holding: Dictionary, by_id: Dictionary, nodes: Dictionary,
		library: PartLibrary) -> Dictionary:
	slots = _in_hand(slots, holding, by_id, nodes, library)
	var first: Dictionary = _carried(slots, holding, by_id, nodes, library)
	var best: Dictionary = first
	var sooner: Dictionary = {}
	var rounds: int = 1
	var last: Dictionary = first
	while rounds < ROUNDS:
		var more: int = 0
		# Hidden still beside what holds it, it goes in with the first of
		# what holds it.
		for one: Array in (last["test"] as Tested.Steps).hidden:
			var level: int = int(sooner.get(int(one[1]), 0))
			if level < 2:
				sooner[int(one[1])] = level + 1
				more += 1
		if more == 0:
			break
		rounds += 1
		last = _carried(_sooner(first["slots"], sooner, holding["near"]), holding, by_id, nodes, library)
		if _faults(last) < _faults(best):
			best = last
	var test: Tested.Steps = best["test"]
	var planned: Dictionary = {}
	for n: int in slots.size():
		for id: int in (slots[n] as Dictionary)["ids"]:
			planned[id] = n
	var waited: int = 0
	for n: int in (best["slots"] as Array).size():
		for id: int in (best["slots"][n] as Dictionary)["ids"]:
			if int(planned.get(id, n)) < n:
				waited += 1
	var in_hand: Dictionary = {}
	for slot: Dictionary in slots:
		for entry: Dictionary in slot["before"]:
			for unit: Array[int] in entry["units"]:
				in_hand[unit[0]] = true
	var left: Array = []
	for kind: String in ["floating", "hidden"]:
		for one: Array in (test.get(kind) as Array):
			left.append("%s %s %s at %d" % [kind, "hand" if in_hand.has(int(one[1])) else "model",
				(by_id[int(one[1])] as BrickWorld.Brick).part_id, int(one[0])])
	return {"slots": best["slots"], "said": {"waited": waited, "sooner": sooner.size(),
		"floating": test.floating.size(), "hidden": test.hidden.size(),
		"under": (best["under"] as Under).faults, "rounds": rounds, "left": left}}


static func _faults(carried: Dictionary) -> int:
	var test: Tested.Steps = carried["test"]
	return test.floating.size() + test.hidden.size() + (carried["under"] as Under).faults


## The steps of [param slots] built as the steps test builds them, each part
## that would not stand where it is put waiting for the first step where it
## would, and each sub-assembly put on so too: {"slots", "test": the
## Tested.Steps that built them, with what it found}.
static func _carried(slots: Array, holding: Dictionary, by_id: Dictionary, nodes: Dictionary,
		library: PartLibrary) -> Dictionary:
	var test := Tested.Steps.new(by_id, holding, library)
	test.nodes = nodes
	var under := Under.new(holding)
	# The parts the main build's later steps put in: one may go in sooner, with
	# a part whose cover meets its own both ways round.
	for slot: Dictionary in slots:
		for id: int in slot["ids"]:
			under.later[id] = true
	var out: Array = []
	var waiting: Array[int] = []
	## Slots whose sub-assemblies wait, their parts put on beside them gone on.
	var held_back: Array = []
	var section: String = ""
	for slot: Dictionary in slots:
		var step: Instructions.Step = slot["step"]
		if step == null:
			_in_hand_taken(test, slot)
			out.append(slot)
			continue
		section = step.section
		var ids: Array[int] = waiting.duplicate()
		for id: int in slot["ids"]:
			if under.later.erase(id):
				ids.append(id)
		waiting = []
		if not step.copies.is_empty() and not (_copies_stand(test, step)
				and under.copies_ready(test.copies_of(step), ids)):
			waiting = ids
			held_back.append({"step": step, "ids": [] as Array[int], "other": slot["other"],
				"before": slot["before"]})
			continue
		_in_hand_taken(test, slot)
		out.append({"step": step, "ids": _put(test, under, step, ids, waiting), "other": slot["other"],
			"before": slot["before"]})
		_put_back(test, under, held_back, out, waiting)
	# What still waits after the last step, in steps of its own.
	var after: int = 0
	var pressed: bool = false
	while (not waiting.is_empty() or not held_back.is_empty()) and after < MOST_AFTER:
		after += 1
		var kept: Array[int] = []
		if not waiting.is_empty():
			var step := Instructions.Step.new()
			step.section = section
			var ids: Array[int] = waiting
			waiting = []
			kept = _put(test, under, step, ids, waiting)
			if not kept.is_empty():
				out.append({"step": step, "ids": kept, "other": [] as Array[int], "before": []})
		if not _put_back(test, under, held_back, out, waiting) and kept.is_empty():
			# What waits only for what it rests on has waited long enough now.
			if pressed:
				break
			pressed = true
			under.step += PATIENCE
	# Held by nothing that stands even then: last, as planned.
	for slot: Dictionary in held_back:
		_in_hand_taken(test, slot)
		var copies: Array = test.copies_of(slot["step"])
		test.take(slot["step"], copies)
		under.take(copies)
		out.append(slot)
	if not waiting.is_empty():
		var step := Instructions.Step.new()
		step.section = section
		var things: Array = []
		for id: int in waiting:
			things.append(PackedInt64Array([id]))
		test.take(step, things)
		under.take(things)
		out.append({"step": step, "ids": waiting, "other": [] as Array[int], "before": []})
	test.finish()
	return {"slots": out, "test": test, "under": under}


## The steps in the hand of the sub-assembly [param slot] puts on, built.
static func _in_hand_taken(test: Tested.Steps, slot: Dictionary) -> void:
	for entry: Dictionary in slot["before"]:
		var things: Array = []
		for unit: Array[int] in entry["units"]:
			things.append(PackedInt64Array([unit[0]]))
		if not things.is_empty():
			test.take(entry["step"], things)


## Whether every copy of a sub-assembly [param step] puts on would stand.
static func _copies_stand(test: Tested.Steps, step: Instructions.Step) -> bool:
	return not test.stands_if(step, test.copies_of(step)).has(false)


## Each of [param held_back] whose sub-assemblies would stand now put on, in
## a step of its own after what is built, as often as one put on lets
## another: whether any was.
static func _put_back(test: Tested.Steps, under: Under, held_back: Array, out: Array,
		waiting: Array[int]) -> bool:
	var any: bool = false
	var more: bool = true
	while more:
		more = false
		for slot: Dictionary in held_back.duplicate():
			if not _copies_stand(test, slot["step"]) \
					or not under.copies_ready(test.copies_of(slot["step"]), [] as Array[int]):
				continue
			_in_hand_taken(test, slot)
			# With the parts it takes in sooner, if any.
			slot["ids"] = _put(test, under, slot["step"], [] as Array[int], waiting)
			out.append(slot)
			held_back.erase(slot)
			more = true
			any = true
	return any


## [param ids] tried as [param step]'s parts, after the sub-assemblies it puts
## on: those that would stand, and rest on nothing not yet in ([class Under]),
## put in with them, and returned; the rest added to [param waiting].
static func _put(test: Tested.Steps, under: Under, step: Instructions.Step, ids: Array[int],
		waiting: Array[int]) -> Array[int]:
	var copies: Array = test.copies_of(step)
	var going: Dictionary = {}
	for copy: PackedInt64Array in copies:
		for id: int in copy:
			going[id] = true
	var trying: Array[int] = ids.duplicate()
	var asked: Dictionary = {}
	for id: int in ids:
		asked[id] = true
	var sooner: Array[int] = []
	while true:
		while not trying.is_empty():
			var things: Array = copies.duplicate()
			for id: int in trying:
				things.append(PackedInt64Array([id]))
			var stands: Array[bool] = test.stands_if(step, things)
			var standing: Dictionary = {}
			for n: int in trying.size():
				if stands[copies.size() + n]:
					standing[trying[n]] = true
			# What stands, and is not over what is not yet in. One left out may
			# have held up another, so asked again of those left.
			var ready: Array[int] = under.ready_of(trying, standing, going, asked)
			if ready.size() == trying.size():
				break
			trying = ready
		# A later part whose cover meets one of these both ways round goes in
		# with it if it stands: put in after, it would go in under it.
		var more: Array[int] = []
		# Not in the model's first step, where anything stands (Tested.Steps).
		for id: int in (trying + going.keys()) if test.main.begun else []:
			for other: int in under.mutual.get(id, PackedInt64Array()):
				if sooner.size() + more.size() < PULL_MOST and not asked.has(other) \
						and under.later.has(other) and not under.at.has(other):
					asked[other] = true
					more.append(other)
		if more.is_empty():
			break
		sooner.append_array(more)
		trying.append_array(more)
	var kept: Dictionary = {}
	for id: int in trying:
		kept[id] = true
	var taken: Array = copies.duplicate()
	var put: Array[int] = []
	for id: int in ids:
		if kept.has(id):
			taken.append(PackedInt64Array([id]))
			put.append(id)
		else:
			waiting.append(id)
	for id: int in sooner:
		if kept.has(id):
			taken.append(PackedInt64Array([id]))
			put.append(id)
			under.later.erase(id)
	if not taken.is_empty():
		test.take(step, taken)
		under.take(taken)
	return put


## [param slots] with each part of [param sooner] in the step of what holds
## it: the latest of the steps before its own that put in a part it is joined
## to ([param near]), or at its second time asked the first of them. A part
## of a sub-assembly built in the hand, so among the steps of its box.
static func _sooner(slots: Array, sooner: Dictionary, near: Dictionary) -> Array:
	var out: Array = []
	var at: Dictionary = {}           ## id -> its slot
	for n: int in slots.size():
		var slot: Dictionary = slots[n]
		var ids: Array[int] = (slot["ids"] as Array[int]).duplicate()
		var box: Array = []
		for entry: Dictionary in slot["before"]:
			var copy: Dictionary = entry.duplicate()
			copy["units"] = (entry["units"] as Array).duplicate()
			box.append(copy)
		_sooner_within(box, "units", sooner, near, func(unit: Array) -> int: return int(unit[0]))
		out.append({"step": slot["step"], "ids": ids, "other": slot["other"], "before": box})
		for id: int in ids:
			at[id] = n
		var step: Instructions.Step = slot["step"]
		if step != null:
			for copy: PackedInt64Array in step.copies:
				for id: int in copy:
					at[id] = n
	_sooner_within(out, "ids", sooner, near, func(id: int) -> int: return id, at)
	return out


## Each of [param sooner] in [param places] (each its [param key] list of
## things, [param id_of] a thing's id) moved into the place of what holds it,
## as [method _sooner] says. [param at]: where each id is, among things that
## do not move too (a sub-assembly put on); worked out when not given.
static func _sooner_within(places: Array, key: String, sooner: Dictionary, near: Dictionary,
		id_of: Callable, at: Dictionary = {}) -> void:
	var thing_of: Dictionary = {}     ## id -> the thing
	for n: int in places.size():
		for thing: Variant in (places[n] as Dictionary)[key]:
			var id: int = id_of.call(thing)
			at[id] = n
			thing_of[id] = thing
	# Again while one moved lets another: a hand goes in with the arm it is
	# on once the arm goes in sooner with the body.
	for sweep: int in 3:
		var moved: bool = false
		for id: int in sooner:
			if not thing_of.has(id):
				continue
			var here: int = at[id]
			# Joined only to parts of its own step (a figure's head to its
			# body, the body to its hips), it goes in sooner with them: what
			# they are joined to that went in before is what holds it.
			var with: Array[int] = [id]
			var seen: Dictionary = {id: true}
			var n: int = 0
			while n < with.size():
				for other: int in (near.get(with[n], {}) as Dictionary):
					if not seen.has(other) and thing_of.has(other) and int(at[other]) == here:
						seen[other] = true
						with.append(other)
				n += 1
			var best: int = -1
			for one: int in with:
				for other: int in (near.get(one, {}) as Dictionary):
					if at.has(other) and int(at[other]) < here:
						var there: int = int(at[other])
						best = there if best < 0 else (maxi(best, there) if int(sooner[id]) < 2 else mini(best, there))
				if one == id and best >= 0:
					with = [id]
					break
			if best < 0:
				continue
			for one: int in with:
				((places[here] as Dictionary)[key] as Array).erase(thing_of[one])
				((places[best] as Dictionary)[key] as Array).append(thing_of[one])
				at[one] = best
			moved = true
		if not moved:
			break


## The steps of [param slots], numbered again as the planner numbers them
## (Instructions._expand): a sub-assembly's steps in the hand carry the
## number of the step that puts it on. A step left with nothing goes.
static func _steps_of(slots: Array, world: BrickWorld) -> Array[Instructions.Step]:
	var out: Array[Instructions.Step] = []
	var number: int = 0
	for slot: Dictionary in slots:
		var step: Instructions.Step = slot["step"]
		var ids: Array = (slot["ids"] as Array) + (slot["other"] as Array)
		if step != null and ids.is_empty() and step.copies.is_empty():
			continue
		number += 1
		# A step of the box left showing nothing goes, its other copies' parts
		# into the step before it, or else the one after.
		var box: Array = []
		var orphans: Array[int] = []
		for entry: Dictionary in slot["before"]:
			if (entry["units"] as Array).is_empty() and (entry["shown"] as Array).is_empty():
				orphans.append_array(entry["rest"])
				continue
			if not orphans.is_empty():
				entry = entry.duplicate()
				entry["rest"] = orphans + (entry["rest"] as Array)
				orphans = []
			box.append(entry)
		if not orphans.is_empty() and not box.is_empty():
			box[-1] = (box[-1] as Dictionary).duplicate()
			box[-1]["rest"] = (box[-1]["rest"] as Array) + orphans
		for at: int in box.size():
			var entry: Dictionary = box[at]
			var inside: Instructions.Step = entry["step"]
			inside.number = number
			inside.callout_step = at + 1
			inside.callout_steps = box.size()
			inside.shown_ids = PackedInt64Array()
			inside.brick_ids = PackedInt64Array()
			for unit: Array[int] in entry["units"]:
				inside.shown_ids.append(unit[0])
			inside.shown_ids.append_array(PackedInt64Array(entry["shown"]))
			inside.brick_ids.append_array(inside.shown_ids)
			for unit: Array[int] in entry["units"]:
				inside.brick_ids.append_array(PackedInt64Array(unit.slice(1)))
			inside.brick_ids.append_array(PackedInt64Array(entry["rest"]))
			inside.parts = _parts_of(inside.brick_ids, world)
			out.append(inside)
		if step == null:
			continue
		if not box.is_empty():
			step.callout_steps = box.size()
		step.number = number
		step.brick_ids = PackedInt64Array(ids)
		step.parts = _parts_of(step.brick_ids, world)
		out.append(step)
	for index: int in out.size():
		out[index].index = index + 1
	return out


## Part id -> how many of it [param ids] are.
static func _parts_of(ids: PackedInt64Array, world: BrickWorld) -> Dictionary:
	var parts: Dictionary = {}
	for id: int in ids:
		var part: String = world.get_brick(id).part_id
		parts[part] = int(parts.get(part, 0)) + 1
	return parts
