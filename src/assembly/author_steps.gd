## The build steps a model's author gave it, and changing them.
##
## A model made in Studio, LDCad, LeoCAD or Bricksmith is divided into
## steps by its designer, with "0 STEP" lines, and a sub-model has steps
## of its own: the window built in three, then put on in step 9. Brickworks
## read those lines and dropped them, and wrote its own worked-out order
## over them on save, so opening somebody's model and saving it threw away
## the booklet they had made.
##
## Each part keeps its step within its own sub-model (BrickWorld.Brick.step)
## and each copy of a sub-model the step it is put on in, within the one
## that places it (BrickWorld.unit_steps). A step is therefore named by
## where it is — a "section", the sub-model's path, "" for the model — and
## its number there. The edits here change those numbers, one undo each
## (Builder.record), and leave every section numbered 0, 1, 2… with no gaps.
class_name AuthorSteps
extends RefCounted


## Whether any part of the model has a step its author gave it. Then the
## timeline and the booklet follow the author's steps, and saving keeps them.
static func any(world: BrickWorld, skip: Dictionary = {}) -> bool:
	for brick: BrickWorld.Brick in world.bricks():
		if brick.step >= 0 and not skip.has(brick.id):
			return true
	return false


## The lowest step of any part under each sub-model's path, at any depth:
## the step a sub-assembly made by hand from stepped parts goes on in,
## until it is given one.
static func lowest_under(world: BrickWorld, skip: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if brick.step < 0 or skip.has(brick.id):
			continue
		var path: String = ""
		for segment: String in Assemblies.segments(Assemblies.path_of(brick)):
			path = Assemblies.join(path, segment)
			out[path] = mini(int(out.get(path, brick.step)), brick.step)
	return out


## The first part under each sub-model's path, at any depth, by id: where
## the file places it among the copies its step places, since a model is
## read in the order its file lists it.
static func first_under(world: BrickWorld, skip: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id):
			continue
		var path: String = ""
		for segment: String in Assemblies.segments(Assemblies.path_of(brick)):
			path = Assemblies.join(path, segment)
			out[path] = mini(int(out.get(path, brick.id)), brick.id)
	return out


## The step the copy at [param path] goes on in, within its parent: as
## set, else as its parts suggest, else -1, none.
static func unit_step(world: BrickWorld, path: String, lowest: Dictionary) -> int:
	if world.unit_steps.has(path):
		return int(world.unit_steps[path])
	return int(lowest.get(path, -1))


## Where a step comes in the whole build, to sort by: at each level the
## step the copy is put on in and where that step places it ([param first],
## first_under), then the step itself. Within one step of a section, the
## sub-models it puts on come before its own parts (even, then odd), since
## they are built first and then put on; and each is built whole before the
## next. With the step alone, five buildings one step places went up a step
## of each in turn: the first course of every one, then the second.
static func key_of(world: BrickWorld, section: String, step: int,
		lowest: Dictionary, first: Dictionary = {}) -> Array:
	var key: Array = []
	var path: String = ""
	for segment: String in Assemblies.segments(section):
		path = Assemblies.join(path, segment)
		key.append(2 * maxi(unit_step(world, path, lowest), 0))
		key.append(int(first.get(path, 0)))
	key.append(2 * step + 1)
	return key


static func before(a: Array, b: Array) -> bool:
	for n: int in mini(a.size(), b.size()):
		if int(a[n]) != int(b[n]):
			return int(a[n]) < int(b[n])
	return a.size() < b.size()


# -- what a section holds --------------------------------------------------


## Every path in the model, ancestors included.
static func paths_in(world: BrickWorld, skip: Dictionary = {}) -> Dictionary:
	var found: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id):
			continue
		var path: String = ""
		for segment: String in Assemblies.segments(Assemblies.path_of(brick)):
			path = Assemblies.join(path, segment)
			found[path] = true
	return found


## What a section is built of, each with its step: its own parts
## ({"brick": id}) and the copies of sub-models it puts on ({"unit": path}).
## Only those that have a step.
static func items_of(world: BrickWorld, section: String, skip: Dictionary = {}) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if brick.step >= 0 and not skip.has(brick.id) \
				and Assemblies.path_of(brick) == section:
			out.append({"brick": brick.id, "step": brick.step})
	var lowest: Dictionary = lowest_under(world, skip)
	for path: String in paths_in(world, skip):
		if Assemblies.parent_of(path) != section:
			continue
		var at: int = unit_step(world, path, lowest)
		if at >= 0:
			out.append({"unit": path, "step": at})
	return out


## The item [param item] put in step [param to], what it had kept in
## [param undo] for Builder._apply.
static func _put(world: BrickWorld, item: Dictionary, to: int, undo: Array) -> void:
	if int(item["step"]) == to and (item.has("brick") or world.unit_steps.has(item["unit"])):
		return
	if item.has("brick"):
		var brick: BrickWorld.Brick = world.get_brick(int(item["brick"]))
		undo.append({"undo": "restep", "brick": brick.id, "step": brick.step})
		brick.step = to
	else:
		var path: String = item["unit"]
		undo.append({"undo": "unitstep", "unit": path,
			"step": int(world.unit_steps.get(path, -1))})
		world.unit_steps[path] = to
	item["step"] = to


## [param undo] with each part and each copy named once, by what it had
## first: the entries of an undo group are applied in the order they were
## kept, so a part moved and then renumbered was put back to its middle
## step, not its first.
static func squash(undo: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for entry: Dictionary in undo:
		var name: String = "b%d" % int(entry["brick"]) if entry.has("brick") \
			else "u" + str(entry["unit"])
		if seen.has(name):
			continue
		seen[name] = true
		out.append(entry)
	return out


## Number a section's steps 0, 1, 2… in the order they were, with no gaps:
## after an edit has emptied one, or made one between two.
static func _tidy(world: BrickWorld, section: String, skip: Dictionary, undo: Array) -> void:
	var items: Array = items_of(world, section, skip)
	var used: Dictionary = {}
	for item: Dictionary in items:
		used[int(item["step"])] = true
	var order: Array = used.keys()
	order.sort()
	for item: Dictionary in items:
		_put(world, item, order.find(int(item["step"])), undo)


## The steps in a section, in order.
static func steps_in(world: BrickWorld, section: String, skip: Dictionary = {}) -> Array:
	var used: Dictionary = {}
	for item: Dictionary in items_of(world, section, skip):
		used[int(item["step"])] = true
	var order: Array = used.keys()
	order.sort()
	return order


# -- giving a model steps ---------------------------------------------------


## Before a step edit: every part and every copy given a step. A model
## nobody gave steps takes the worked-out order (adopt_plan); in one that
## has them, a part added since goes after its section's last step, in
## the order worked out for such parts. Returns the undo for it.
static func ensure(world: BrickWorld, library: PartLibrary, skip: Dictionary = {}) -> Array:
	if not any(world, skip):
		return adopt_plan(world, library, skip)
	var undo: Array = []
	var numbers: Dictionary = numbers_for_file(world, library, skip, true)
	var bricks: Dictionary = numbers["bricks"]
	var changed: bool = false
	for brick_id: int in bricks:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick.step < 0:
			undo.append({"undo": "restep", "brick": brick_id, "step": -1})
			brick.step = int(bricks[brick_id])
			changed = true
	var units: Dictionary = numbers["units"]
	for path: String in units:
		if not world.unit_steps.has(path):
			undo.append({"undo": "unitstep", "unit": path, "step": -1})
			world.unit_steps[path] = int(units[path])
			changed = true
	if changed:
		var sections: Dictionary = paths_in(world, skip)
		sections[""] = true
		for section: String in sections:
			_tidy(world, section, skip, undo)
	return squash(undo)


## The worked-out order made the author's: every part given the step the
## plan puts it in, and every sub-assembly the step its last part goes in,
## so the first step edit on a model nobody gave steps starts from what the
## timeline showed. Returns the undo for it; nothing when the model already
## has steps.
static func adopt_plan(world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}) -> Array:
	var undo: Array = []
	if any(world, skip):
		return undo
	var numbers: Dictionary = numbers_from_plan(world, library, skip)
	var bricks: Dictionary = numbers["bricks"]
	for brick_id: int in bricks:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		undo.append({"undo": "restep", "brick": brick_id, "step": brick.step})
		brick.step = int(bricks[brick_id])
	var units: Dictionary = numbers["units"]
	for path: String in units:
		undo.append({"undo": "unitstep", "unit": path,
			"step": int(world.unit_steps.get(path, -1))})
		world.unit_steps[path] = int(units[path])
	var sections: Dictionary = paths_in(world, skip)
	sections[""] = true
	for section: String in sections:
		_tidy(world, section, skip, undo)
	return squash(undo)


## The worked-out order as numbers a file can hold: {"bricks": id -> the
## step it is in, "units": path -> the step its copy goes on in}. Each a
## step of the whole plan, so they are in order within any one section; a
## copy goes on with its last part, after it is built.
static func numbers_from_plan(world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}) -> Dictionary:
	return numbers_of(world, Instructions.plan(world, library, skip), skip)


## The same numbers, from steps already worked out (Instructions.plan_paced).
static func numbers_of(world: BrickWorld, steps: Array[Instructions.Step],
		skip: Dictionary = {}) -> Dictionary:
	var bricks: Dictionary = {}
	for index: int in steps.size():
		for brick_id: int in steps[index].brick_ids:
			bricks[brick_id] = index
	return {"bricks": bricks, "units": _units_after(world, bricks, skip)}


static func _units_after(world: BrickWorld, bricks: Dictionary, skip: Dictionary) -> Dictionary:
	var units: Dictionary = {}
	for brick_id: int in bricks:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null or skip.has(brick_id):
			continue
		var path: String = ""
		for segment: String in Assemblies.segments(Assemblies.path_of(brick)):
			path = Assemblies.join(path, segment)
			units[path] = maxi(int(units.get(path, 0)), int(bricks[brick_id]))
	return units


## The numbers to write into a file for a model that has the author's
## steps, the same shape as [method numbers_from_plan]. A part added since
## the steps were made, with none of its own, goes after its section's last
## step — in the order worked out for those parts when [param worked] is
## set, which a save can afford and the autosave, a second after every
## change, cannot.
static func numbers_for_file(world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}, worked: bool = false) -> Dictionary:
	var lowest: Dictionary = lowest_under(world, skip)
	var last: Dictionary = {}       ## section -> its last step
	var bricks: Dictionary = {}
	var units: Dictionary = {}
	var loose: Array[int] = []
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id):
			continue
		var section: String = Assemblies.path_of(brick)
		if brick.step >= 0:
			bricks[brick.id] = brick.step
			last[section] = maxi(int(last.get(section, 0)), brick.step)
		else:
			loose.append(brick.id)
	for path: String in paths_in(world, skip):
		var at: int = unit_step(world, path, lowest)
		if at >= 0:
			units[path] = at
			var parent: String = Assemblies.parent_of(path)
			last[parent] = maxi(int(last.get(parent, 0)), at)
	if loose.is_empty():
		return {"bricks": bricks, "units": units}
	# After the author's: in a step of their own, or the worked-out ones.
	var order: Dictionary = {}
	if worked and library != null:
		for step: Instructions.Step in Instructions.plan(world, library, skip, {}, true):
			if step.authored_step >= 0:
				continue
			for brick_id: int in step.brick_ids:
				order[brick_id] = step.number
	for brick_id: int in loose:
		var section: String = Assemblies.path_of(world.get_brick(brick_id))
		bricks[brick_id] = int(last.get(section, -1)) + 1 + int(order.get(brick_id, 0))
	for path: String in paths_in(world, skip):
		if not units.has(path):
			units[path] = int(last.get(Assemblies.parent_of(path), -1)) + 1
	return {"bricks": bricks, "units": units}


# -- the edits ---------------------------------------------------------------


## What a selection is, as items of the sections it is in: a part directly
## in the sub-assembly being edited ([param level]) is itself; one inside
## an assembly within it is that assembly's copy, which a click on it
## selects whole. section -> Array of items.
static func _selected(world: BrickWorld, ids: Array, level: String,
		skip: Dictionary) -> Dictionary:
	var lowest: Dictionary = lowest_under(world, skip)
	var out: Dictionary = {}
	var seen: Dictionary = {}
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null or skip.has(brick_id):
			continue
		var path: String = Assemblies.path_of(brick)
		var item: Dictionary = {}
		var section: String = path
		if path != level and Assemblies.within(path, level):
			var child: String = Assemblies.join(level,
				Assemblies.segments(path)[Assemblies.segments(level).size()])
			section = level
			item = {"unit": child, "step": maxi(unit_step(world, child, lowest), 0)}
		else:
			item = {"brick": brick_id, "step": maxi(brick.step, 0)}
		var name: String = str(item.get("unit", item.get("brick")))
		if seen.has(name):
			continue
		seen[name] = true
		if not out.has(section):
			out[section] = []
		(out[section] as Array).append(item)
	return out


## The selection moved [param by] steps, earlier or later, within its own
## section: Edit, Move to previous step and Move to next step. A part in
## the first step stays there; one moved on from the last makes a new one.
static func move(world: BrickWorld, ids: Array, by: int, level: String,
		skip: Dictionary = {}) -> Array:
	var undo: Array = []
	var picked: Dictionary = _selected(world, ids, level, skip)
	for section: String in picked:
		for item: Dictionary in picked[section]:
			_put(world, item, maxi(int(item["step"]) + by, 0), undo)
		_tidy(world, section, skip, undo)
	return squash(undo)


## A new step of the selection, straight after [param after] (the step the
## timeline is on, in [param after_in]) or else after the latest of the
## steps they were in, and everything later one on: Edit, New step from
## selection. This is how a step is split in two, and how one is put in.
static func new_step(world: BrickWorld, ids: Array, level: String,
		after_in: String = "", after: int = -1, skip: Dictionary = {}) -> Array:
	var undo: Array = []
	var picked: Dictionary = _selected(world, ids, level, skip)
	for section: String in picked:
		var mine: Array = picked[section]
		var from: int = after if section == after_in and after >= 0 else -1
		if from < 0:
			for item: Dictionary in mine:
				from = maxi(from, int(item["step"]))
		var chosen: Dictionary = {}
		for item: Dictionary in mine:
			chosen[str(item.get("unit", item.get("brick")))] = true
		for item: Dictionary in items_of(world, section, skip):
			if int(item["step"]) > from and not chosen.has(str(item.get("unit", item.get("brick")))):
				_put(world, item, int(item["step"]) + 1, undo)
		for item: Dictionary in mine:
			_put(world, item, from + 1, undo)
		_tidy(world, section, skip, undo)
	return squash(undo)


## The parts put down in [param section] since its last step, made a step
## of their own after it: Edit, Next step (E). A builder following a booklet,
## or writing one, ends each step as Studio's step button does and goes on
## to the next; the parts with no step yet are the ones put down since, and
## in a model with no steps every part so far is the first. A copy of a
## sub-model put on since goes in with them. Returns the undo, empty when
## nothing was put down since the last step.
static func close_step(world: BrickWorld, section: String, skip: Dictionary = {}) -> Array:
	var undo: Array = []
	var last: int = -1
	for item: Dictionary in items_of(world, section, skip):
		last = maxi(last, int(item["step"]))
	for brick: BrickWorld.Brick in world.bricks():
		if brick.step < 0 and not skip.has(brick.id) and Assemblies.path_of(brick) == section:
			_put(world, {"brick": brick.id, "step": -1}, last + 1, undo)
	var lowest: Dictionary = lowest_under(world, skip)
	for path: String in paths_in(world, skip):
		if Assemblies.parent_of(path) == section and unit_step(world, path, lowest) < 0:
			_put(world, {"unit": path, "step": -1}, last + 1, undo)
	return squash(undo)


## Every copy of the sub-model [param section] is, itself included: a
## change to the steps of one window is a change to the window.
static func _copies(world: BrickWorld, section: String, skip: Dictionary) -> Array:
	if section.is_empty():
		return [""]
	var out: Array = []
	var kind: String = Assemblies.definition(Assemblies.leaf(section))
	var depth: int = Assemblies.segments(section).size()
	for path: String in paths_in(world, skip):
		if Assemblies.segments(path).size() == depth \
				and Assemblies.definition(Assemblies.leaf(path)) == kind:
			out.append(path)
	return out


## Step [param step] of [param section] swapped with the one [param by]
## away: the timeline's Earlier and Later.
static func swap(world: BrickWorld, section: String, step: int, by: int,
		skip: Dictionary = {}) -> Array:
	var undo: Array = []
	var other: int = step + by
	for copy: String in _copies(world, section, skip):
		var steps: Array = steps_in(world, copy, skip)
		if not steps.has(step) or not steps.has(other):
			continue
		for item: Dictionary in items_of(world, copy, skip):
			if int(item["step"]) == step:
				_put(world, item, other, undo)
			elif int(item["step"]) == other:
				_put(world, item, step, undo)
	return squash(undo)


## Step [param step] of [param section] and the one after it made one:
## the timeline's Merge.
static func merge(world: BrickWorld, section: String, step: int,
		skip: Dictionary = {}) -> Array:
	var undo: Array = []
	for copy: String in _copies(world, section, skip):
		for item: Dictionary in items_of(world, copy, skip):
			if int(item["step"]) == step + 1:
				_put(world, item, step, undo)
		_tidy(world, copy, skip, undo)
	return squash(undo)


## Step [param step] of [param section] taken out, what it put on joining
## the step before it (the one after, for the first): the timeline's
## Delete step. No part is taken off the model.
static func remove(world: BrickWorld, section: String, step: int,
		skip: Dictionary = {}) -> Array:
	var undo: Array = []
	for copy: String in _copies(world, section, skip):
		var into: int = step - 1 if step > 0 else step + 1
		for item: Dictionary in items_of(world, copy, skip):
			if int(item["step"]) == step:
				_put(world, item, into, undo)
		_tidy(world, copy, skip, undo)
	return squash(undo)
