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
	var by_path: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if brick.step < 0 or skip.has(brick.id):
			continue
		var path: String = Assemblies.path_of(brick)
		by_path[path] = mini(int(by_path.get(path, brick.step)), brick.step)
	return _up_paths(by_path)


## Each of [param by_path]'s numbers (a part's path -> the least of its
## parts') taken up to every path above it, the least of them: walked once
## a path, not once a part. Walked once a part, the three readings of the
## model each step edit makes were most of what it did on the Wizard's
## Tower (race244).
static func _up_paths(by_path: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for leaf: String in by_path:
		var least: int = by_path[leaf]
		var path: String = ""
		for segment: String in Assemblies.segments(leaf):
			path = Assemblies.join(path, segment)
			out[path] = mini(int(out.get(path, least)), least)
	return out


## The first part under each sub-model's path, at any depth, by id: where
## the file places it among the copies its step places, since a model is
## read in the order its file lists it.
static func first_under(world: BrickWorld, skip: Dictionary = {}) -> Dictionary:
	var by_path: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id):
			continue
		var path: String = Assemblies.path_of(brick)
		by_path[path] = mini(int(by_path.get(path, brick.id)), brick.id)
	return _up_paths(by_path)


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
	var leaves: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if not skip.has(brick.id):
			leaves[Assemblies.path_of(brick)] = 0
	var found: Dictionary = {}
	for path: String in _up_paths(leaves):
		found[path] = true
	return found


## What a section is built of, each with its step: its own parts
## ({"brick": id}) and the copies of sub-models it puts on ({"unit": path}).
## Only those that have a step.
static func items_of(world: BrickWorld, section: String, skip: Dictionary = {}) -> Array:
	return items_in(world, [section], skip)[section]


## [method items_of] for each of [param sections], in one reading of the
## model: section -> its items. Read a section at a time, the Wizard's
## Tower's 19 sub-models were 19 readings of its 10,101 parts, three passes
## each, twice: 1.4 s of a step edit's 2.6 (BookletLooks.items_by_step,
## race244).
static func items_in(world: BrickWorld, sections: Array, skip: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for section: String in sections:
		out[section] = []
	for brick: BrickWorld.Brick in world.bricks():
		if brick.step < 0 or skip.has(brick.id):
			continue
		var items: Variant = out.get(Assemblies.path_of(brick))
		if items != null:
			(items as Array).append({"brick": brick.id, "step": brick.step})
	var lowest: Dictionary = lowest_under(world, skip)
	for path: String in paths_in(world, skip):
		var items: Variant = out.get(Assemblies.parent_of(path))
		if items == null:
			continue
		var at: int = unit_step(world, path, lowest)
		if at >= 0:
			(items as Array).append({"unit": path, "step": at})
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
		# A part by its number, which no name of a copy or an undo can be.
		var name: Variant = int(entry["brick"]) if entry.has("brick") \
			else ("u" + str(entry["unit"]) if entry.has("unit") else str(entry.get("undo", "")))
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
	var place: Dictionary = {}
	for index: int in order.size():
		place[order[index]] = index
	for item: Dictionary in items:
		_put(world, item, int(place[int(item["step"])]), undo)


## The steps in a section, in order.
static func steps_in(world: BrickWorld, section: String, skip: Dictionary = {}) -> Array:
	return steps_of(items_of(world, section, skip))


## The steps [param items] (a section's, [method items_of]) are in, in order.
static func steps_of(items: Array) -> Array:
	var used: Dictionary = {}
	for item: Dictionary in items:
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
	if _all_given(world, skip):
		return []
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


## Whether every part and every copy of a sub-model has its step already,
## so [method ensure] has nothing to give: read in two passes, where working
## out every part's number to find none missing was 80 ms of each step edit
## on the Wizard's Tower (race244).
static func _all_given(world: BrickWorld, skip: Dictionary) -> bool:
	for brick: BrickWorld.Brick in world.bricks():
		if brick.step < 0 and not skip.has(brick.id):
			return false
	for path: String in paths_in(world, skip):
		if not world.unit_steps.has(path):
			return false
	return true


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
	_copies_alike(world, skip, undo)
	return squash(undo)


## Every copy of a sub-model stepped as its first copy is, part for part:
## a file writes a sub-model once, from its first copy (LdrModel.write_tree),
## so a second copy the plan built in an order of its own was built as the
## first once saved and opened again (10016-1's second pair of wheels).
## A copy whose parts are not the first's, part for part, keeps its own.
static func _copies_alike(world: BrickWorld, skip: Dictionary, undo: Array) -> void:
	var own: Dictionary = {}       ## path -> its own bricks, by id
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id):
			continue
		var path: String = Assemblies.path_of(brick)
		if path.is_empty():
			continue
		if not own.has(path):
			own[path] = []
		(own[path] as Array).append(brick)
	var by_definition: Dictionary = {}
	for path: String in paths_in(world, skip):
		var named: String = Assemblies.definition(Assemblies.leaf(path))
		if not by_definition.has(named):
			by_definition[named] = []
		(by_definition[named] as Array).append(path)
	for named: String in by_definition:
		var copies: Array = by_definition[named]
		if copies.size() < 2:
			continue
		# The first as the file writes it: outermost, then by name.
		copies.sort_custom(func(a: String, b: String) -> bool:
			if a.count("/") != b.count("/"):
				return a.count("/") < b.count("/")
			return a.naturalnocasecmp_to(b) < 0)
		var first: String = copies[0]
		var model: Array = own.get(first, [])
		model.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
		for copy: String in copies.slice(1):
			var bricks: Array = own.get(copy, [])
			bricks.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
			if bricks.size() != model.size():
				continue
			var alike: bool = true
			for n: int in bricks.size():
				if (bricks[n] as BrickWorld.Brick).part_id != (model[n] as BrickWorld.Brick).part_id:
					alike = false
					break
			if not alike:
				continue
			for n: int in bricks.size():
				var brick: BrickWorld.Brick = bricks[n]
				var step: int = (model[n] as BrickWorld.Brick).step
				if brick.step != step:
					undo.append({"undo": "restep", "brick": brick.id, "step": brick.step})
					brick.step = step
			for path: String in world.unit_steps.keys():
				if Assemblies.parent_of(path) != first:
					continue
				var twin: String = Assemblies.join(copy, Assemblies.leaf(path))
				if world.unit_steps.has(twin) \
						and int(world.unit_steps[twin]) != int(world.unit_steps[path]):
					undo.append({"undo": "unitstep", "unit": twin,
						"step": int(world.unit_steps[twin])})
					world.unit_steps[twin] = int(world.unit_steps[path])


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
	# Read only for a copy: a part of its own section needs none of it.
	var lowest: Dictionary = {}
	var read: bool = false
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
			if not read:
				lowest = lowest_under(world, skip)
				read = true
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


## The selection put in step [param to] of [param section], however far
## that is: Studio's step list, where the selection is dragged onto any
## step, and Move to step…. A step it empties is taken out, so the steps
## after it are one fewer. Parts outside [param section] are not moved
## ([method outside] says so first).
static func move_to(world: BrickWorld, ids: Array, level: String, section: String, to: int,
		skip: Dictionary = {}) -> Array:
	var undo: Array = []
	var picked: Dictionary = _selected(world, ids, level, skip)
	if not picked.has(section):
		return undo
	for item: Dictionary in picked[section]:
		_put(world, item, to, undo)
	_tidy(world, section, skip, undo)
	return squash(undo)


## How many of the selection's items are in a section other than
## [param section], as [method _selected] reads them: a step of one
## sub-model takes none of another's parts.
static func outside(world: BrickWorld, ids: Array, level: String, section: String,
		skip: Dictionary = {}) -> int:
	var count: int = 0
	var picked: Dictionary = _selected(world, ids, level, skip)
	for other: String in picked:
		if other != section:
			count += (picked[other] as Array).size()
	return count


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
	for copy: String in _copies(world, section, skip):
		var steps: Array = steps_in(world, copy, skip)
		# The step beside it that has anything in it: a file's empty step
		# (a ROTSTEP alone) is no step to change places with.
		var other: int = neighbour(steps, step, by)
		if not steps.has(step) or other < 0:
			continue
		for item: Dictionary in items_of(world, copy, skip):
			if int(item["step"]) == step:
				_put(world, item, other, undo)
			elif int(item["step"]) == other:
				_put(world, item, step, undo)
	return squash(undo)


## Why step [param step] of [param section] cannot change places with the
## one [param by] away (-1 the one before, 1 the one after), or "": the
## step that would go first must not stand on the other, or its parts are
## put down in the air. "Stands on" is read off the parts' boxes: one whose
## foot is on another's top, where its studs are.
static func blocked_swap(world: BrickWorld, section: String, step: int, by: int,
		skip: Dictionary = {}) -> String:
	var other: int = neighbour(steps_in(world, section, skip), step, by)
	if other < 0:
		return ""
	var early: int = mini(step, other)
	var late: int = maxi(step, other)
	var low: Array[AABB] = _boxes_in(world, section, early, skip)
	var high: Array[AABB] = _boxes_in(world, section, late, skip)
	for upper: AABB in high:
		for lower: AABB in low:
			if _stands_on(upper, lower):
				return ("that step cannot go %s: parts of the later step stand on the earlier "
					+ "one's, and would be put down in the air") % ["earlier" if by < 0 else "later"]
	return ""


static func _boxes_in(world: BrickWorld, section: String, step: int,
		skip: Dictionary) -> Array[AABB]:
	var out: Array[AABB] = []
	var units: Array[String] = []
	for item: Dictionary in items_of(world, section, skip):
		if int(item["step"]) != step:
			continue
		if item.has("brick"):
			out.append(_box_of(world, world.get_brick(int(item["brick"]))))
		else:
			units.append(str(item["unit"]))
	if not units.is_empty():
		for brick: BrickWorld.Brick in world.bricks():
			if skip.has(brick.id):
				continue
			var path: String = Assemblies.path_of(brick)
			for unit: String in units:
				if path == unit or path.begins_with(unit + "/"):
					out.append(_box_of(world, brick))
					break
	return out


static func _box_of(world: BrickWorld, brick: BrickWorld.Brick) -> AABB:
	var part: Lbm.PartMesh = world.library.mesh_for(brick.part_id) if world.library != null \
		else null
	if part == null:
		return AABB(brick.transform.origin - Vector3(10, 0, 10), Vector3(20, 24, 20))
	return brick.transform * part.bounds


## Whether [param upper] rests on [param lower]: its foot within a stud's
## height of the other's top, over it by more than an edge.
static func _stands_on(upper: AABB, lower: AABB) -> bool:
	var foot: float = upper.position.y
	if foot < lower.end.y - 6.0 or foot > lower.end.y + 0.5 or foot <= lower.position.y + 2.0:
		return false
	var a := Rect2(upper.position.x, upper.position.z, upper.size.x, upper.size.z).grow(-2.0)
	var b := Rect2(lower.position.x, lower.position.z, lower.size.x, lower.size.z).grow(-2.0)
	return a.intersects(b)


## The step [param by] places from [param step] in [param steps] (a
## section's steps in order, steps_in), or -1 at either end.
static func neighbour(steps: Array, step: int, by: int) -> int:
	var at: int = steps.find(step)
	if at < 0 or at + by < 0 or at + by >= steps.size():
		return -1
	return int(steps[at + by])


## Step [param step] of [param section] and the one after it made one:
## the timeline's Merge.
static func merge(world: BrickWorld, section: String, step: int,
		skip: Dictionary = {}) -> Array:
	var undo: Array = []
	for copy: String in _copies(world, section, skip):
		var next: int = neighbour(steps_in(world, copy, skip), step, 1)
		for item: Dictionary in items_of(world, copy, skip):
			if int(item["step"]) == next:
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
