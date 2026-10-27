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

## Whether the planner's steps are put right: off only for a probe, to see
## what the planner alone would have made.
static var mends: bool = true
## What the last mend did, for a probe: {"waited": parts put in later than
## planned, "sooner": parts put in with what holds them, "floating" and
## "hidden": what the steps test still finds, "rounds", "ms"}.
static var said: Dictionary = {}


## [param steps], worked out for [param world]'s parts but [param skip], put
## right where they are. A slice at a time with a [param job], and the steps
## read on a worker; at once without one.
static func mend_into(steps: Array[Instructions.Step], world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}, job: Working.Job = null) -> void:
	said = {}
	if not mends:
		return
	var began: int = Time.get_ticks_msec()
	var bricks: Array = []
	var by_id: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if not skip.has(brick.id) and library.mesh_for(brick.part_id) != null:
			bricks.append(brick)
			by_id[brick.id] = brick
	if bricks.size() < 2 or steps.is_empty():
		return
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
				return
		lattice.occupy_boxes(brick.id, covers.boxes_for(library.mesh_for(brick.part_id), brick.transform))
	covers.free()
	var holding: Dictionary = {}
	await Tested.holds_into(holding, bricks, lattice, library, job)
	if holding.is_empty() or job != null and job.cancelled:
		return
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
			return
	else:
		got = _mended(slots, holding, by_id, nodes, library)
	var mended: Dictionary = got
	var out: Array[Instructions.Step] = _steps_of(mended["slots"], world)
	steps.clear()
	steps.append_array(out)
	said = mended["said"]
	said["ms"] = Time.get_ticks_msec() - began


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
		"floating": test.floating.size(), "hidden": test.hidden.size(), "rounds": rounds, "left": left}}


static func _faults(carried: Dictionary) -> int:
	var test: Tested.Steps = carried["test"]
	return test.floating.size() + test.hidden.size()


## The steps of [param slots] built as the steps test builds them, each part
## that would not stand where it is put waiting for the first step where it
## would, and each sub-assembly put on so too: {"slots", "test": the
## Tested.Steps that built them, with what it found}.
static func _carried(slots: Array, holding: Dictionary, by_id: Dictionary, nodes: Dictionary,
		library: PartLibrary) -> Dictionary:
	var test := Tested.Steps.new(by_id, holding, library)
	test.nodes = nodes
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
		ids.append_array(slot["ids"])
		waiting = []
		if not step.copies.is_empty() and not _copies_stand(test, step):
			waiting = ids
			held_back.append({"step": step, "ids": [] as Array[int], "other": slot["other"],
				"before": slot["before"]})
			continue
		_in_hand_taken(test, slot)
		out.append({"step": step, "ids": _put(test, step, ids, waiting), "other": slot["other"],
			"before": slot["before"]})
		_put_back(test, held_back, out, waiting)
	# What still waits after the last step, in steps of its own.
	var after: int = 0
	while (not waiting.is_empty() or not held_back.is_empty()) and after < MOST_AFTER:
		after += 1
		var kept: Array[int] = []
		if not waiting.is_empty():
			var step := Instructions.Step.new()
			step.section = section
			var ids: Array[int] = waiting
			waiting = []
			kept = _put(test, step, ids, waiting)
			if not kept.is_empty():
				out.append({"step": step, "ids": kept, "other": [] as Array[int], "before": []})
		if not _put_back(test, held_back, out, waiting) and kept.is_empty():
			break
	# Held by nothing that stands even then: last, as planned.
	for slot: Dictionary in held_back:
		_in_hand_taken(test, slot)
		test.take(slot["step"], test.copies_of(slot["step"]))
		out.append(slot)
	if not waiting.is_empty():
		var step := Instructions.Step.new()
		step.section = section
		var things: Array = []
		for id: int in waiting:
			things.append(PackedInt64Array([id]))
		test.take(step, things)
		out.append({"step": step, "ids": waiting, "other": [] as Array[int], "before": []})
	test.finish()
	return {"slots": out, "test": test}


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
static func _put_back(test: Tested.Steps, held_back: Array, out: Array, waiting: Array[int]) -> bool:
	var any: bool = false
	var more: bool = true
	while more:
		more = false
		for slot: Dictionary in held_back.duplicate():
			if not _copies_stand(test, slot["step"]):
				continue
			_in_hand_taken(test, slot)
			_put(test, slot["step"], [] as Array[int], waiting)
			out.append(slot)
			held_back.erase(slot)
			more = true
			any = true
	return any


## [param ids] tried as [param step]'s parts, after the sub-assemblies it puts
## on: those that would stand put in with them, and returned; the rest added
## to [param waiting].
static func _put(test: Tested.Steps, step: Instructions.Step, ids: Array[int],
		waiting: Array[int]) -> Array[int]:
	var things: Array = test.copies_of(step)
	var copies: int = things.size()
	for id: int in ids:
		things.append(PackedInt64Array([id]))
	var stands: Array[bool] = test.stands_if(step, things)
	var taken: Array = things.slice(0, copies)
	var kept: Array[int] = []
	for n: int in range(copies, things.size()):
		var id: int = int((things[n] as PackedInt64Array)[0])
		if stands[n]:
			taken.append(things[n])
			kept.append(id)
		else:
			waiting.append(id)
	if not taken.is_empty():
		test.take(step, taken)
	return kept


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
			var best: int = -1
			for other: int in (near.get(id, {}) as Dictionary):
				if at.has(other) and int(at[other]) < here:
					var there: int = int(at[other])
					best = there if best < 0 else (maxi(best, there) if int(sooner[id]) < 2 else mini(best, there))
			if best < 0:
				continue
			((places[here] as Dictionary)[key] as Array).erase(thing_of[id])
			((places[best] as Dictionary)[key] as Array).append(thing_of[id])
			at[id] = best
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
