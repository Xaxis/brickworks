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
##
## A copy whose unit step is [constant IN_PARENT] is built in the steps of
## the sub-model that places it, its parts numbered among that one's: the
## section of its parts is that one's ([method home]). The castle's towers
## and walls go up together, a course of each in turn, and the order a
## person was shown could not be kept by sub-models built whole, each in
## steps of its own (stepskeep).
class_name AuthorSteps
extends RefCounted

## The unit step of a copy built in the steps of the one that places it.
## In the file its parts are written in that one's steps, each run of them
## after a line naming the copy ("0 !BRICKWORKS IN tower#1", LdrModel.IN_META),
## so every LDraw reader builds them in the order shown, and this app reads
## the copy back as it was.
const IN_PARENT := LdrModel.IN_PARENT


## The section the parts directly in [param path] are stepped in: its own,
## or for a copy built in its parent's steps ([constant IN_PARENT]), the
## nearest one round it that has steps of its own. With [param units], as
## those say (numbers_from_plan's, before they are the model's).
static func home(world: BrickWorld, path: String, units: Variant = null) -> String:
	var steps: Dictionary = world.unit_steps if units == null else units
	if steps.is_empty():
		return path
	while not path.is_empty() and int(steps.get(path, -1)) == IN_PARENT:
		path = Assemblies.parent_of(path)
	return path


## Whether the copy at [param path] is built in its parent's steps.
static func in_parent(world: BrickWorld, path: String, units: Variant = null) -> bool:
	return int((world.unit_steps if units == null else units).get(path, -1)) == IN_PARENT


## How many of [param path]'s copies are built in steps of their own, the
## outermost first: the levels of its key ([method key_of]).
static func levels(world: BrickWorld, path: String, units: Variant = null) -> int:
	var count: int = 0
	var at: String = ""
	for segment: String in Assemblies.segments(path):
		at = Assemblies.join(at, segment)
		if not in_parent(world, at, units):
			count += 1
	return count


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
## set, else as its parts suggest, else -1, none. With [param units], as
## those say (numbers_from_plan's, before they are the model's).
static func unit_step(world: BrickWorld, path: String, lowest: Dictionary,
		units: Variant = null) -> int:
	if units != null:
		return int((units as Dictionary).get(path, -1))
	if world.unit_steps.has(path):
		return int(world.unit_steps[path])
	return int(lowest.get(path, -1))


## Where a step comes in the whole build, to sort by: at each level the
## step the copy is put on in and where that step places it ([param first],
## first_under), then the step itself. Within one step of a section, the
## sub-models it puts on come before its own parts (even, then odd), since
## they are built first and then put on; and each is built whole before the
## next. With the step alone, five buildings one step places went up a step
## of each in turn: the first course of every one, then the second. A copy
## built in its parent's steps is no level of its own.
static func key_of(world: BrickWorld, section: String, step: int,
		lowest: Dictionary, first: Dictionary = {}, units: Variant = null) -> Array:
	var key: Array = []
	var path: String = ""
	for segment: String in Assemblies.segments(section):
		path = Assemblies.join(path, segment)
		if in_parent(world, path, units):
			continue
		key.append(2 * maxi(unit_step(world, path, lowest, units), 0))
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
## ({"brick": id}) and the copies of sub-models it puts on ({"unit": path}),
## and those of every copy built in its steps ([constant IN_PARENT]). Only
## those that have a step.
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
		var items: Variant = out.get(home(world, Assemblies.path_of(brick)))
		if items != null:
			(items as Array).append({"brick": brick.id, "step": brick.step})
	var lowest: Dictionary = lowest_under(world, skip)
	for path: String in paths_in(world, skip):
		var items: Variant = out.get(home(world, Assemblies.parent_of(path)))
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
## step, not its first. With [param world], without those that would give
## a part or a copy back the step it has now: a part alone in its step made
## a step of its own is renumbered and numbered back, and an edit that
## moves nothing is none, with nothing to undo (Shell.change_steps).
static func squash(undo: Array, world: BrickWorld = null) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for entry: Dictionary in undo:
		# A part by its number, which no name of a copy or an undo can be.
		var name: Variant = int(entry["brick"]) if entry.has("brick") \
			else ("u" + str(entry["unit"]) if entry.has("unit") else str(entry.get("undo", "")))
		if seen.has(name):
			continue
		seen[name] = true
		if world == null or _changes(world, entry):
			out.append(entry)
	return out


## Whether [param entry], a step edit's undo, gives back what the model no
## longer has.
static func _changes(world: BrickWorld, entry: Dictionary) -> bool:
	match str(entry.get("undo", "")):
		"restep":
			var brick: BrickWorld.Brick = world.get_brick(int(entry["brick"]))
			return brick == null or brick.step != int(entry["step"])
		"unitstep":
			return int(world.unit_steps.get(str(entry["unit"]), -1)) != int(entry["step"])
	return true


## Number a section's steps 0, 1, 2… in the order they were: after an edit
## has emptied one, or made one between two. A step the section had empty
## before the edit ([param undo] says what each item had) stays: an
## author's page for a note or a turn of the model, which a file keeps as
## a STEP line of its own and a booklet's looks by its number
## (BookletLooks). Taken out, the turn after it went on the step before it
## and the note ended the step before (kt3review #4).
static func _tidy(world: BrickWorld, section: String, skip: Dictionary, undo: Array) -> void:
	var items: Array = items_of(world, section, skip)
	var was: Dictionary = {}
	for entry: Dictionary in undo:
		if entry.has("step") and (entry.has("brick") or entry.has("unit")):
			var named: String = _name_of(entry)
			if not was.has(named):
				was[named] = int(entry["step"])
	var used: Dictionary = {}
	var had: Dictionary = {}
	for item: Dictionary in items:
		used[int(item["step"])] = true
		had[int(was.get(_name_of(item), item["step"]))] = true
	var last: int = -1
	for step: int in had:
		last = maxi(last, step)
	for step: int in last:
		if not had.has(step):
			used[step] = true
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


## The worked-out order made the author's: every part and every copy of a
## sub-model given the numbers the plan was shown in (numbers_from_plan),
## so the first step edit on a model nobody gave steps starts from what the
## timeline showed, every step it does not change where it was. And the
## booklet's sections with them, marked on the steps they start on
## (BookletLooks.mark_sections), which the model's own steps do not say:
## the lighthouse's three banners were gone after one edit (sectionmarks).
## Returns the undo for it; nothing when the model already has steps.
static func adopt_plan(world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}) -> Array:
	var undo: Array = []
	if any(world, skip):
		return undo
	var read: Dictionary = {}
	var worked: Array[Instructions.Step] = Instructions.worked_out(world, library, skip, {}, read)
	var numbers: Dictionary = Instructions.kept_numbers(world, library, skip, worked, read)
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
	if not worked.is_empty():
		undo.append_array(BookletLooks.mark_sections(world,
			Instructions.adopted_plan(world, library, skip, worked)))
	return squash(undo)


## The worked-out order as numbers the model can keep, and a file can
## hold: {"bricks": id -> its step in its own sub-model, "units": path ->
## the step its copy goes on in, in the one that places it, or IN_PARENT}.
## The plan shows a model nobody gave steps in these (Instructions._kept),
## the first step edit gives them to it (adopt_plan), and a save writes
## them: what the person saw is what is kept.
static func numbers_from_plan(world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}) -> Dictionary:
	var read: Dictionary = {}
	var worked: Array[Instructions.Step] = Instructions.worked_out(world, library, skip, {}, read)
	return Instructions.kept_numbers(world, library, skip, worked, read)


## [param steps], a plan, as numbers the model can keep ([method
## numbers_of]), each section numbered 0, 1, 2… and every copy of a
## sub-model stepped as its first copy is. With [param in_place], every copy
## not built on the side is built in its parent's steps ([constant
## IN_PARENT]), so the numbers are [param steps]' own.
static func adopted(world: BrickWorld, steps: Array[Instructions.Step],
		skip: Dictionary = {}, in_place: bool = false) -> Dictionary:
	var numbers: Dictionary = numbers_of(world, steps, skip, in_place)
	_tidy_numbers(world, numbers, skip)
	_copies_alike(world, numbers, skip)
	return numbers


## The numbers of [param steps], a plan: each part the step it is in, and
## each copy of a sub-model the step it goes on in. One built on the side
## goes on in the step that puts it on; one built where it stands, in the
## step its first part goes in, and is built whole there, in its own steps.
## The plan may build a sub-model where it stands round another step: the
## lighthouse's keeper was put on in step 45, between the island's last two.
## The model's steps cannot hold that, and given the step of its last part
## the island was built after the keeper, every step of it one later than
## the person had read it (stepsnum).
##
## With [param in_place], every copy but those built on the side is built in
## the steps of the one that places it ([constant IN_PARENT]): the plan's
## own order, which builds the castle's towers and walls a course of each in
## turn, as no sub-model built whole can.
static func numbers_of(world: BrickWorld, steps: Array[Instructions.Step],
		skip: Dictionary = {}, in_place: bool = false) -> Dictionary:
	var bricks: Dictionary = {}
	var aside: Dictionary = {}      ## a copy built on the side -> the step that puts it on
	for index: int in steps.size():
		var step: Instructions.Step = steps[index]
		for brick_id: int in step.brick_ids:
			bricks[brick_id] = index
		if step.callout > 0 and step.callout_step == 0:
			for ids: PackedInt64Array in step.copies:
				var copy: String = _copy_made_of(world, ids)
				if not copy.is_empty():
					aside[copy] = index
	if in_place:
		var units: Dictionary = {}
		for path: String in paths_in(world, skip):
			if not path.is_empty():
				units[path] = IN_PARENT
		units.merge(aside, true)
		return {"bricks": bricks, "units": units}
	var first: Dictionary = {}
	for brick_id: int in bricks:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null or skip.has(brick_id):
			continue
		var path: String = Assemblies.path_of(brick)
		first[path] = mini(int(first.get(path, bricks[brick_id])), int(bricks[brick_id]))
	var units: Dictionary = _up_paths(first)
	units.erase("")
	units.merge(aside, true)
	return {"bricks": bricks, "units": units}


## Whether [param steps], a plan of the steps a model can keep
## (Instructions._kept), builds its copies in their parents' steps: a step
## holds a part of a section other than its own (in a callout, of the copy
## it shows). Its numbers are then [method numbers_of]'s with in_place;
## read without, the castle's paced save wrote each tower whole.
static func in_place_plan(world: BrickWorld, steps: Array[Instructions.Step]) -> bool:
	for step: Instructions.Step in steps:
		if step.authored_step < 0:
			continue
		for brick_id: int in (step.shown_ids if step.in_callout() else step.brick_ids):
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick != null and Assemblies.path_of(brick) != step.authored_in:
				return true
	return false


## The copy of a sub-model [param ids] make: the path every one of them is
## under.
static func _copy_made_of(world: BrickWorld, ids: PackedInt64Array) -> String:
	var shared: PackedStringArray = PackedStringArray()
	var started: bool = false
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		var segments: PackedStringArray = Assemblies.segments(Assemblies.path_of(brick))
		if not started:
			shared = segments
			started = true
			continue
		var same: int = 0
		while same < mini(shared.size(), segments.size()) and shared[same] == segments[same]:
			same += 1
		shared = shared.slice(0, same)
	return "/".join(shared)


## [param numbers] ([method numbers_of]) with each section's steps
## numbered 0, 1, 2… in the order they were, as [method _tidy] numbers a
## model's.
static func _tidy_numbers(world: BrickWorld, numbers: Dictionary, skip: Dictionary) -> void:
	var bricks: Dictionary = numbers["bricks"]
	var units: Dictionary = numbers["units"]
	var used: Dictionary = {}       ## section -> {number: true}
	var own: Dictionary = {}        ## part id -> its section
	var placed: Dictionary = {}     ## a copy put on in a step -> the section it is put on in
	for path: String in units:
		if int(units[path]) != IN_PARENT:
			placed[path] = home(world, Assemblies.parent_of(path), units)
	for brick_id: int in bricks:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null or skip.has(brick_id):
			continue
		var section: String = home(world, Assemblies.path_of(brick), units)
		own[brick_id] = section
		if not used.has(section):
			used[section] = {}
		(used[section] as Dictionary)[int(bricks[brick_id])] = true
	for path: String in placed:
		var parent: String = placed[path]
		if not used.has(parent):
			used[parent] = {}
		(used[parent] as Dictionary)[int(units[path])] = true
	var place: Dictionary = {}      ## section -> {number: its place}
	for section: String in used:
		var order: Array = (used[section] as Dictionary).keys()
		order.sort()
		var at: Dictionary = {}
		for index: int in order.size():
			at[order[index]] = index
		place[section] = at
	for brick_id: int in own:
		bricks[brick_id] = int(place[own[brick_id]][int(bricks[brick_id])])
	for path: String in placed:
		units[path] = int(place[placed[path]][int(units[path])])


## Every copy of a sub-model in [param numbers] stepped as its first copy
## is, part for part: a file writes a sub-model once, from its first copy
## (LdrModel.write_tree), so a second copy the plan built in an order of its
## own was built as the first once saved and opened again (10016-1's second
## pair of wheels). A copy whose parts are not the first's, part for part,
## keeps its own. So does one built in the model's own steps, whose parts
## the file writes there, each copy's its own (IN_PARENT).
static func _copies_alike(world: BrickWorld, numbers: Dictionary, skip: Dictionary) -> void:
	var bricks: Dictionary = numbers["bricks"]
	var units: Dictionary = numbers["units"]
	var own: Dictionary = {}       ## path -> its own bricks, by id
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id) or not bricks.has(brick.id):
			continue
		var path: String = Assemblies.path_of(brick)
		if path.is_empty():
			continue
		if not own.has(path):
			own[path] = []
		(own[path] as Array).append(brick)
	var by_definition: Dictionary = {}
	for path: String in paths_in(world, skip):
		if int(units.get(path, -1)) == IN_PARENT and home(world, path, units).is_empty():
			continue
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
			var copied: Array = own.get(copy, [])
			copied.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
			if copied.size() != model.size():
				continue
			var alike: bool = true
			for n: int in copied.size():
				if (copied[n] as BrickWorld.Brick).part_id != (model[n] as BrickWorld.Brick).part_id:
					alike = false
					break
			if not alike:
				continue
			for n: int in copied.size():
				bricks[(copied[n] as BrickWorld.Brick).id] = bricks[(model[n] as BrickWorld.Brick).id]
			for path: String in units.keys():
				if Assemblies.parent_of(path) != first:
					continue
				var twin: String = Assemblies.join(copy, Assemblies.leaf(path))
				if units.has(twin):
					units[twin] = units[path]


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
		var section: String = home(world, Assemblies.path_of(brick))
		if brick.step >= 0:
			bricks[brick.id] = brick.step
			last[section] = maxi(int(last.get(section, 0)), brick.step)
		else:
			loose.append(brick.id)
	for path: String in paths_in(world, skip):
		var at: int = unit_step(world, path, lowest)
		if at == IN_PARENT:
			units[path] = at
		elif at >= 0:
			units[path] = at
			var parent: String = home(world, Assemblies.parent_of(path))
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
		var section: String = home(world, Assemblies.path_of(world.get_brick(brick_id)))
		bricks[brick_id] = int(last.get(section, -1)) + 1 + int(order.get(brick_id, 0))
	for path: String in paths_in(world, skip):
		if not units.has(path):
			units[path] = int(last.get(home(world, Assemblies.parent_of(path)), -1)) + 1
	return {"bricks": bricks, "units": units}


## The steps of the copy at [param path], built in steps of its own, made
## steps of the section that puts it on, as taking it apart leaves its parts
## there (Assemblies.ungroup): where the copy was put on, after the copies
## that step built before it, each of its steps in turn, then the rest of
## that step, and every step after it as many later, numbered with no gaps.
## The build goes in the order it did. Left as they were, its parts were
## numbered in steps of a sub-model that was gone, and went in among the
## first steps of the one they were now in; put first in the step, 7140-1's
## Biggs, taken apart, was built before the ship and the support vehicle the
## step puts on beside him, which the booklet had built first (stepsiblings).
## {"bricks": id -> step, "units": path -> step} of what it holds, and "steps"
## {"section": the one it is put on in, "at": the step that put it on,
## "outer": each of that one's steps -> the step it is now (the one that put
## it on, the step after its last), "inner": each of the copy's -> the step
## it is now, and "before": the step the copies built before it are now in,
## when there are any}; empty for a copy built in its parent's steps
## already, or a model with no steps.
static func inlined(world: BrickWorld, path: String, skip: Dictionary = {}) -> Dictionary:
	if path.is_empty() or in_parent(world, path) or not any(world, skip):
		return {}
	var outer: String = home(world, Assemblies.parent_of(path))
	var read: Dictionary = items_in(world, [path, outer], skip)
	var at: int = -1
	for item: Dictionary in read[outer]:
		if str(item.get("unit", "")) == path:
			at = int(item["step"])
	var own: Array = steps_of(read[path])
	if at < 0 or own.is_empty():
		return {}
	# Where the step built it among the sub-models it puts on, as the
	# booklet builds them (Instructions._authored_from): those it builds
	# first, the sections the step puts on and the callouts ahead of it, stay
	# in the step; it, and the rest of the step, after them.
	var others: Dictionary = {}     ## a copy the step puts on -> true
	for item: Dictionary in read[outer]:
		if item.has("unit") and int(item["step"]) == at and str(item["unit"]) != path:
			others[str(item["unit"])] = true
	var first_at: Dictionary = {}   ## a copy -> the plan's first step with a part of it
	if not others.is_empty() and world.library != null:
		var watched: Array = others.keys()
		watched.append(path)
		var steps: Array[Instructions.Step] = Instructions.plan(world, world.library, skip,
			{}, true)
		for index: int in steps.size():
			for brick_id: int in steps[index].brick_ids:
				var brick: BrickWorld.Brick = world.get_brick(brick_id)
				var brick_path: String = Assemblies.path_of(brick) if brick != null else ""
				for unit: String in watched:
					if not first_at.has(unit) and Assemblies.within(brick_path, unit):
						first_at[unit] = index
	var mine: int = int(first_at.get(path, -1))
	var built_before := func(item: Dictionary) -> bool:
		return item.has("unit") and others.has(str(item["unit"])) and mine >= 0 \
			and int(first_at.get(str(item["unit"]), mine)) < mine
	var outer_at := func(item: Dictionary) -> int:
		var step: int = int(item["step"])
		if step < at or built_before.call(item):
			return step
		return step + own.size() + 1
	var inner: Dictionary = {}      ## its step -> where it goes
	for index: int in own.size():
		inner[own[index]] = at + 1 + index
	var numbered: Array = []        ## [item, its step before the gaps are closed]
	var before: bool = false
	for item: Dictionary in read[outer]:
		if str(item.get("unit", "")) != path:
			numbered.append([item, outer_at.call(item)])
			before = before or built_before.call(item)
	for item: Dictionary in read[path]:
		numbered.append([item, int(inner[int(item["step"])])])
	var used: Dictionary = {}
	for one: Array in numbered:
		used[int(one[1])] = true
	var order: Array = used.keys()
	order.sort()
	var place: Dictionary = {}
	for index: int in order.size():
		place[order[index]] = index
	var bricks: Dictionary = {}
	var units: Dictionary = {}
	for one: Array in numbered:
		var item: Dictionary = one[0]
		var to: int = int(place[int(one[1])])
		# Every part, its step changed or not: the change takes these as the
		# steps it gives, and numbers no other (rehomed).
		if item.has("brick"):
			bricks[int(item["brick"])] = to
		else:
			units[str(item["unit"])] = to
	var outer_steps: Dictionary = {}
	for item: Dictionary in read[outer]:
		var step: int = int(item["step"])
		if str(item.get("unit", "")) != path and not built_before.call(item):
			outer_steps[step] = int(place[step if step < at else step + own.size() + 1])
	var inner_steps: Dictionary = {}
	for step: int in own:
		inner_steps[step] = int(place[int(inner[step])])
	var steps: Dictionary = {"section": outer, "at": at, "outer": outer_steps,
		"inner": inner_steps}
	if before:
		steps["before"] = int(place[at])
	return {"bricks": bricks, "units": units, "steps": steps}


## What a change to the tree (Builder.regroup) put in a section other than
## the one it was stepped in, numbered in the one it is in now: a part, and a
## copy built in steps of its own, put on in a step. Taken out to a section
## round the one it was in, it goes in the step that section put that one on
## in; put into another, after that one's last step, in the order it was
## built. Then each section it left or went to is numbered 0, 1, 2… again.
## Left with their numbers, they were numbered in the steps of a section they
## were no longer in: Ungroup on two parts of 7140-1's upper left wing, put on
## in a step of the ship's, left them in the ship's step of the wing's number
## for them, and the wing dragged out of the ship went on in a step of the
## model's that the model has none of (stepsiblings).
## [param was] is brick id -> its path before the change, [param units] the
## copies' steps before it, [param carry] where it put each assembly (as
## regroup's: unset, none), [param given] the steps it gave itself (regroup's
## numbers), left as given. Returns the undo, each part and copy once, as
## the edits here do: nothing when nothing changed section.
static func rehomed(world: BrickWorld, was: Dictionary, units: Dictionary, carry: Callable,
		given: Dictionary, skip: Dictionary = {}) -> Array:
	var undo: Array = []
	if not any(world, skip):
		return undo
	var to_of := func(path: String) -> Array:
		return carry.call(path) if carry.is_valid() else [path]
	var numbered: Dictionary = {}
	for path: String in given.get("units", {}):
		for to: String in to_of.call(path):
			numbered[to] = true
	var stepped: Dictionary = given.get("bricks", {})
	# [item, the section it is in now, the one it was in, the path its own
	# copies are read up from], for each part and copy whose section changed.
	var moving: Array = []
	for brick_id: int in was:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null or brick.step < 0 or skip.has(brick_id) or stepped.has(brick_id):
			continue
		var from: String = home(world, str(was[brick_id]), units)
		var now: String = home(world, Assemblies.path_of(brick))
		if from != now and not (to_of.call(from) as Array).has(now):
			moving.append([{"brick": brick_id, "step": brick.step}, now, from, str(was[brick_id])])
	for path: String in units:
		var step: int = int(units[path])
		if step < 0:
			continue
		for to: String in to_of.call(path):
			if numbered.has(to) or int(world.unit_steps.get(to, -1)) != step:
				continue
			var from: String = home(world, Assemblies.parent_of(path), units)
			var now: String = home(world, Assemblies.parent_of(to))
			if from != now and not (to_of.call(from) as Array).has(now):
				moving.append([{"unit": to, "step": step}, now, from, Assemblies.parent_of(path)])
	if moving.is_empty():
		return undo
	var going: Dictionary = {}      ## an item's name -> true
	for one: Array in moving:
		going[_name_of(one[0])] = true
	var into: Dictionary = {}       ## a section -> [[the order it was built in, item]]
	var touched: Dictionary = {}
	for one: Array in moving:
		var item: Dictionary = one[0]
		var now: String = one[1]
		touched[now] = true
		for left: String in to_of.call(str(one[2])):
			touched[left] = true
		# Out to a section round it: the step that put on the copy it was in.
		var at: int = -1
		var path: String = one[3]
		while not path.is_empty():
			if home(world, Assemblies.parent_of(path), units) == now:
				at = int(units.get(path, -1))
				break
			path = Assemblies.parent_of(path)
		if at >= 0:
			_put(world, item, at, undo)
			continue
		if not into.has(now):
			into[now] = []
		(into[now] as Array).append([key_of(world, str(one[2]), int(item["step"]), {}, {}, units),
			item])
	for now: String in into:
		var last: int = -1
		for item: Dictionary in items_of(world, now, skip):
			if not going.has(_name_of(item)):
				last = maxi(last, int(item["step"]))
		var order: Array = into[now]
		order.sort_custom(func(a: Array, b: Array) -> bool: return before(a[0], b[0]))
		var step: int = last
		var key: Array = []
		for one: Array in order:
			if one[0] != key:
				step += 1
				key = one[0]
			_put(world, one[1], step, undo)
	for section: String in touched:
		_tidy(world, section, skip, undo)
	return squash(undo)


static func _name_of(item: Dictionary) -> String:
	return ("u" + str(item["unit"])) if item.has("unit") else str(item["brick"])


# -- the edits ---------------------------------------------------------------


## What a selection is, as items of the sections it is in: a part directly
## in the sub-assembly being edited ([param level]) is itself; one inside
## an assembly within it is that assembly's copy when the selection holds
## all of the copy, as a click on it selects it whole (the outermost copy
## held whole), and else itself, in its own sub-model's steps. A session
## names parts by number, and the island's rocks, named with two parts of
## the tower, stood for the island and the tower whole: "to" step 1 put
## both on in step 1, built before the baseplates there, which went to
## step 53 (stepsto). section -> Array of items.
static func _selected(world: BrickWorld, ids: Array, level: String,
		skip: Dictionary) -> Dictionary:
	# Read only for a part below the level: one of its own section needs none of it.
	var lowest: Dictionary = {}
	var whole: Dictionary = {}
	var read: bool = false
	var out: Dictionary = {}
	var seen: Dictionary = {}
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null or skip.has(brick_id):
			continue
		var path: String = Assemblies.path_of(brick)
		var item: Dictionary = {"brick": brick_id, "step": maxi(brick.step, 0)}
		# A copy built in its parent's steps is no item: its parts are each
		# their own, in the steps of the one round it.
		var section: String = home(world, path)
		if path != level and Assemblies.within(path, level):
			if not read:
				lowest = lowest_under(world, skip)
				whole = _whole_under(world, ids, skip)
				for copy: String in whole.keys():
					if in_parent(world, copy):
						whole.erase(copy)
				read = true
			var copy: String = level
			for segment: String in Assemblies.segments(path).slice(Assemblies.segments(level).size()):
				copy = Assemblies.join(copy, segment)
				if whole.has(copy):
					break
			if whole.has(copy):
				section = home(world, Assemblies.parent_of(copy))
				item = {"unit": copy, "step": maxi(unit_step(world, copy, lowest), 0)}
		var name: String = str(item.get("unit", item.get("brick")))
		if seen.has(name):
			continue
		seen[name] = true
		if not out.has(section):
			out[section] = []
		(out[section] as Array).append(item)
	return out


## The copies [param ids] hold whole: every path every part under which, at
## any depth, is one of them.
static func _whole_under(world: BrickWorld, ids: Array, skip: Dictionary) -> Dictionary:
	var chosen: Dictionary = {}
	for brick_id: Variant in ids:
		chosen[int(brick_id)] = true
	# 1 for a path all of whose own parts are chosen, 0 for one missing any.
	var by_path: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if not skip.has(brick.id):
			var path: String = Assemblies.path_of(brick)
			by_path[path] = mini(int(by_path.get(path, 1)), int(chosen.has(brick.id)))
	var out: Dictionary = {}
	var up: Dictionary = _up_paths(by_path)
	for path: String in up:
		if int(up[path]) == 1:
			out[path] = true
	return out


## [param picked] ([method _selected]) with the same items of every other
## copy of each sub-model built in steps of its own: a file says a sub-model's
## steps once, for all its copies, so a part moved to another step in one
## window is moved in every window, as a step swapped, merged or taken out is
## ([method _copies]). Moved in one copy alone, 7140-1's four rear engines
## could not be said in the file as it was, the model was written whole and
## lost every line of the file's own text, and opened again every copy took
## the steps of the one written (keeptext). A copy is another's twin part for
## part, in the order its parts were read; one that is not keeps its own.
static func _with_twins(world: BrickWorld, picked: Dictionary, skip: Dictionary) -> Dictionary:
	var out: Dictionary = picked.duplicate()
	var wanted: Dictionary = {}     ## a section of picked -> its other copies
	for section: String in picked:
		if section.is_empty():
			continue
		for copy: String in _copies(world, section, skip):
			if copy != section and not picked.has(copy):
				wanted[section] = (wanted.get(section, []) as Array) + [copy]
	if wanted.is_empty():
		return out
	var own: Dictionary = {}        ## a copy -> its parts, by id, at any depth it steps
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id):
			continue
		var home_path: String = home(world, Assemblies.path_of(brick))
		if not own.has(home_path):
			own[home_path] = []
		(own[home_path] as Array).append(brick)
	for path: String in own:
		(own[path] as Array).sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
			return a.id < b.id)
	for section: String in wanted:
		var model: Array = own.get(section, [])
		var place: Dictionary = {}  ## brick id -> its index in its copy
		for n: int in model.size():
			place[(model[n] as BrickWorld.Brick).id] = n
		for copy: String in wanted[section]:
			var twin: Array = own.get(copy, [])
			if twin.size() != model.size():
				continue
			var alike: bool = true
			for n: int in model.size():
				if (model[n] as BrickWorld.Brick).part_id != (twin[n] as BrickWorld.Brick).part_id:
					alike = false
					break
			if not alike:
				continue
			var items: Array = []
			for item: Dictionary in picked[section]:
				if item.has("brick") and place.has(int(item["brick"])):
					var other: BrickWorld.Brick = twin[int(place[int(item["brick"])])]
					items.append({"brick": other.id, "step": maxi(other.step, 0)})
				elif item.has("unit"):
					var path: String = Assemblies.join(copy,
						str(item["unit"]).substr(section.length() + 1))
					if world.unit_steps.has(path):
						items.append({"unit": path, "step": maxi(int(world.unit_steps[path]), 0)})
			if not items.is_empty():
				out[copy] = items
	return out


## The selection moved [param by] steps, earlier or later, within its own
## section: Edit, Move to previous step and Move to next step. A part in
## the first step stays there; one moved on from the last makes a new one.
static func move(world: BrickWorld, ids: Array, by: int, level: String,
		skip: Dictionary = {}) -> Array:
	var undo: Array = []
	var picked: Dictionary = _with_twins(world, _selected(world, ids, level, skip), skip)
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
	var own: Dictionary = _with_twins(world, {section: picked[section]}, skip)
	for copy: String in own:
		for item: Dictionary in own[copy]:
			_put(world, item, to, undo)
		_tidy(world, copy, skip, undo)
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
	var picked: Dictionary = _with_twins(world, _selected(world, ids, level, skip), skip)
	# The step named is one of every copy of its sub-model.
	var named: Array = _copies(world, after_in, skip)
	for section: String in picked:
		var mine: Array = picked[section]
		var from: int = after if named.has(section) and after >= 0 else -1
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
		if brick.step < 0 and not skip.has(brick.id) \
				and home(world, Assemblies.path_of(brick)) == section:
			_put(world, {"brick": brick.id, "step": -1}, last + 1, undo)
	var lowest: Dictionary = lowest_under(world, skip)
	for path: String in paths_in(world, skip):
		if home(world, Assemblies.parent_of(path)) == section \
				and unit_step(world, path, lowest) == -1:
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
		if Assemblies.segments(path).size() == depth and not in_parent(world, path) \
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
