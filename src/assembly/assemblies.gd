## Sub-assemblies: discrete groups of parts, named, moved as one, nested,
## and copied as instances of one definition — the way a LEGO kit is built
## (two identical wings, bag 3) and the way Studio and LDCad hold a model.
##
## Everything here is read off the bricks themselves. A brick's unit
## (BrickWorld.Brick.unit) is the path of the assemblies it is in, outermost
## first: "Car#1/Wing#2" is the second copy of the definition "Wing", inside
## the first Car. Copies are numbered across the whole model. This is the
## path the booklet reads to build sub-assemblies in callouts (Instructions,
## LdrModel.Placement.unit), so one tree serves both. A brick's group is the
## outermost kind ("Car"), as an opened file and a design have it. A brick
## with a group and no unit — a minifigure, a design's assembly — is that
## group's one copy. Because the path is on the brick, undo, redo, save and
## the timeline carry it without knowing it is a tree.
##
## Nothing about where a copy stands is stored either. Where one copy is
## against another is found by matching their parts (best_match): which
## rigid turn and shift, mirrored or not, lays one on the other. So a copy
## moved, turned or mirrored as a whole needs no bookkeeping, and after an
## edit to one copy the others are built again from it (after_edit) —
## change one wing and the other follows, mirrored.
class_name Assemblies
extends RefCounted

var world: BrickWorld
var builder: Builder
var library: PartLibrary
## The baseplate: never in an assembly.
var scenery: Dictionary = {}

## The assembly being edited, by path; "" for the model itself. While one
## is entered a click picks out its own parts and the assemblies directly
## inside it, and a part put down goes into it.
var entered: String = ""

signal entered_changed(path: String)
## The tree changed shape or names (not merely moved).
signal changed()

## The last history step after_edit looked at, so it looks once.
var _seen: Dictionary = {}
var _syncing: bool = false
## The bricks under every path (path -> Array of bricks, in the world's
## order): one walk of the model in place of one an assembly asked about.
## Moving all of a 5,025-part set with 160 copies of sub-models walked the
## model twice for each, and then again for each of its copies
## (2026-10-16). While a pass over many assemblies at once holds it
## ([method _begin_pass]) it is kept through the pass's own changes.
## Outside one it is kept while the model and its tree are as they were
## ([member _indexed_as]), and made for a model asked about a second time:
## the pointer on a part of Orthanc asked which sub-assembly a click there
## takes, every step onto another part, and each asking walked all 10,101
## parts, 15 to 24 ms of the frame on a desktop (hover_cost_probe,
## 2026-10-31). A model asked about once is walked once, as before: made
## for every question of an edit that changes the model between them, the
## index, dearer than a walk, took bigmodel_probe's redo of a big set's move
## to 1,233 ms, against 348 and 615 walked and 554 so.
var _under: Dictionary = {}
var _passing: int = 0
var _indexed: bool = false
## What the model was when the index was made, outside a pass, and when a
## question was last answered by a walk: cleared, changed, any part's
## group or unit, the baseplates.
var _indexed_as: Array = []
var _walked_as: Array = []


# -- paths --------------------------------------------------------------------


static func segments(path: String) -> PackedStringArray:
	return path.split("/", false)


## A brick's place in the tree: its unit, or the one copy of its group.
static func path_of(brick: BrickWorld.Brick) -> String:
	return path_from(brick.group, brick.unit)


static func path_from(group: String, unit: String) -> String:
	if not unit.is_empty():
		return unit
	return "" if group.is_empty() else group + "#1"


## The group a path gives a brick: its outermost kind.
static func group_of(path: String) -> String:
	return "" if path.is_empty() else definition(segments(path)[0])


## "Wing#2" -> "Wing".
static func definition(segment: String) -> String:
	return segment.get_slice("#", 0)


## "Wing#2" -> 2, "Wing" -> 1.
static func copy_of(segment: String) -> int:
	var at: int = segment.find("#")
	return 1 if at < 0 else maxi(segment.substr(at + 1).to_int(), 1)


static func leaf(path: String) -> String:
	var parts: PackedStringArray = segments(path)
	return "" if parts.is_empty() else parts[parts.size() - 1]


static func parent_of(path: String) -> String:
	var at: int = path.rfind("/")
	return "" if at < 0 else path.substr(0, at)


static func join(path: String, segment: String) -> String:
	return segment if path.is_empty() else path + "/" + segment


## Where a copy at [param path] that has no part on the baseplate (one only
## parts on their way, or that the catalogue lacks, are in: BrickWorld
## .held_paths) is after a change that puts each copy where [param carry]
## says (Builder.regroup's): where the nearest copy round it, itself first,
## that the change moves goes, with the rest of its path. One taken apart
## (none) puts it in the one round it; one split leaves it where it was.
static func carried(carry: Callable, path: String) -> String:
	var at: String = path
	var rest: String = ""
	while not at.is_empty():
		var to: Array = carry.call(at)
		if to.is_empty():
			return _joined(parent_of(at), rest)
		if not to.has(at):
			return _joined(str(to[0]), rest)
		if to.size() > 1:
			return path
		rest = _joined(leaf(at), rest)
		at = parent_of(at)
	return path


static func _joined(path: String, rest: String) -> String:
	return path if rest.is_empty() else join(path, rest)


## Whether a brick's group is in the assembly at ``path`` (or is it).
static func within(group: String, path: String) -> bool:
	if path.is_empty():
		return true
	return group == path or group.begins_with(path + "/")


## The assembly directly inside [param at] that [param path] is in, or "".
static func child_of(at: String, path: String) -> String:
	if path == at or not within(path, at):
		return ""
	var rest: String = path.substr(at.length()).trim_prefix("/")
	var first: String = rest.get_slice("/", 0)
	return join(at, first) if not first.is_empty() else ""


## How a person reads an assembly's name: "Wing", "Wing (copy 2)".
static func label(path: String) -> String:
	var segment: String = leaf(path)
	var copy: int = copy_of(segment)
	return definition(segment) if copy == 1 else "%s (copy %d)" % [definition(segment), copy]


# -- reading the tree ---------------------------------------------------------


## One assembly in the tree.
class Item extends RefCounted:
	var path: String = ""
	var name: String = ""          ## its definition
	var copy: int = 1
	var parts: int = 0             ## directly in it
	var total: int = 0             ## in it and everything inside it
	var children: Array[Item] = []
	var hidden: int = 0            ## parts of it hidden
	var locked: int = 0            ## parts of it locked


## The model as a tree: the root is the model itself (path ""), its parts
## the loose ones; each child an assembly. Children in name order.
func tree() -> Item:
	var root := Item.new()
	root.name = "Model"
	var by_path: Dictionary = {"": root}
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var path: String = ""
		var node: Item = root
		root.total += 1
		_tally(root, brick)
		for segment: String in segments(path_of(brick)):
			path = join(path, segment)
			var next: Item = by_path.get(path)
			if next == null:
				next = Item.new()
				next.path = path
				next.name = definition(segment)
				next.copy = copy_of(segment)
				by_path[path] = next
				node.children.append(next)
			next.total += 1
			_tally(next, brick)
			node = next
		node.parts += 1
	_sort(root)
	return root


func _tally(node: Item, brick: BrickWorld.Brick) -> void:
	if builder.lattice.unseen.has(brick.id):
		node.hidden += 1
	if builder.is_locked(brick.id):
		node.locked += 1


static func _sort(node: Item) -> void:
	node.children.sort_custom(func(a: Item, b: Item) -> bool:
		if a.name != b.name:
			return a.name.naturalnocasecmp_to(b.name) < 0
		return a.copy < b.copy)
	for child: Item in node.children:
		_sort(child)


## Every assembly's path, outermost first.
func paths() -> PackedStringArray:
	if _passing > 0:
		_index()
		var listed := PackedStringArray(_under.keys())
		listed.sort()
		return listed
	var found: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		var path: String = ""
		for segment: String in segments(path_of(brick)):
			path = join(path, segment)
			found[path] = true
	var out := PackedStringArray(found.keys())
	out.sort()
	return out


## Each assembly's own parts by number, "3001,3004", path -> list: what a
## browser check reads the tree by (window.brickworksState.tree).
func parts_by_path() -> Dictionary:
	var found: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		var path: String = path_of(brick)
		if path.is_empty() or scenery.has(brick.id):
			continue
		# Taken out, added to and put back: a packed array in a dictionary
		# is handed out as a copy.
		var listed: PackedStringArray = found.get(path, PackedStringArray())
		listed.append(brick.part_id)
		found[path] = listed
	var out: Dictionary = {}
	for path: String in found:
		var listed: PackedStringArray = found[path]
		listed.sort()
		out[path] = ",".join(listed)
	return out


## Where each assembly's own parts are: path -> the box round their origins.
func own_bounds() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		var path: String = path_of(brick)
		if path.is_empty() or scenery.has(brick.id):
			continue
		var at: Vector3 = brick.transform.origin
		out[path] = (out[path] as AABB).expand(at) if out.has(path) else AABB(at, Vector3.ZERO)
	return out


## The bricks in an assembly and everything inside it.
func bricks_under(path: String) -> Array:
	var out: Array = []
	if path.is_empty():
		return out
	if _passing == 0:
		var model: Array = _model()
		if not (_indexed and model == _indexed_as) and model != _walked_as:
			_walked_as = model
			for brick: BrickWorld.Brick in world.bricks():
				if not scenery.has(brick.id) and within(path_of(brick), path):
					out.append(brick)
			return out
	_index()
	return (_under.get(path, []) as Array).duplicate()


func ids_under(path: String) -> PackedInt64Array:
	var out := PackedInt64Array()
	for brick: BrickWorld.Brick in bricks_under(path):
		out.append(brick.id)
	return out


## The assembly a click on this brick takes, at the level being edited:
## the outermost one inside the entered assembly that holds it; "" when
## the brick is loose at this level, and null when it is outside the
## entered assembly altogether.
func unit_path_of(brick_id: int) -> Variant:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return null
	if not within(path_of(brick), entered):
		return null
	if path_of(brick) == entered:
		return ""
	var depth: int = segments(entered).size()
	return join(entered, segments(path_of(brick))[depth])


## What a click on a brick selects: its whole assembly at this level, or
## the brick alone; nothing outside the assembly being edited.
func unit_of(brick_id: int) -> PackedInt64Array:
	var path: Variant = unit_path_of(brick_id)
	if path == null:
		return PackedInt64Array()
	if str(path).is_empty():
		return PackedInt64Array([brick_id])
	return ids_under(str(path))


## The assembly the selection is exactly, if it is one: "" otherwise.
func selected_assembly() -> String:
	var ids: Array = builder.selection.keys()
	if ids.is_empty():
		return ""
	var path: Variant = unit_path_of(int(ids[0]))
	if path == null or str(path).is_empty():
		return ""
	# A part selected that a click takes elsewhere is no part under it:
	# none, without walking the model. Each panel asked it of the 296 parts
	# a replace of Orthanc left selected, a walk of 10,101 parts each.
	for brick_id: Variant in ids:
		if unit_path_of(int(brick_id)) != path:
			return ""
	var under: PackedInt64Array = ids_under(str(path))
	if under.size() != ids.size():
		return ""
	for brick_id: int in under:
		if not builder.selection.has(brick_id):
			return ""
	return str(path)


## Every other copy of the definition the assembly at ``path`` is a copy
## of, anywhere in the model.
func copies_of(path: String) -> PackedStringArray:
	var name: String = definition(leaf(path))
	var out := PackedStringArray()
	for other: String in paths():
		if other == path or within(other, path) or within(path, other):
			continue
		if definition(leaf(other)) == name:
			out.append(other)
	return out


## A definition name no assembly uses yet: "Wing", else "Wing 2", "Wing 3".
func unused_name(wanted: String) -> String:
	var base: String = wanted.strip_edges().replace("/", "-").replace("#", "")
	if base.is_empty():
		base = "Sub-assembly"
	var taken: Dictionary = {}
	for path: String in paths():
		taken[definition(leaf(path))] = true
	# And those only parts not on the baseplate are in (BrickWorld.held_paths).
	for path: Variant in world.held_paths.values():
		for segment: String in segments(str(path)):
			taken[definition(segment)] = true
	if not taken.has(base):
		return base
	var n: int = 2
	while taken.has("%s %d" % [base, n]):
		n += 1
	return "%s %d" % [base, n]


## The next copy of a definition, numbered across the whole model as an
## opened file numbers them: "Wing#1", then "Wing#2".
## A number a copy taken off still holds a step under (BrickWorld.unit_steps,
## kept for its undo) is not given again: a copy pasted would be put on in
## that step, or built in its parent's steps, as the one taken off was.
## Nor one only parts not on the baseplate are in (BrickWorld.held_paths): a
## Sub pasted into a model whose Sub's one part the catalogue lacks went into
## that copy, and a save wrote the two as one (lp2check HB2).
func next_copy(name: String) -> String:
	var highest: int = 0
	for path: String in paths() + PackedStringArray(world.unit_steps.keys()) \
			+ PackedStringArray(world.held_paths.values()):
		for segment: String in segments(path):
			if definition(segment) == name:
				highest = maxi(highest, copy_of(segment))
	return "%s#%d" % [name, highest + 1]


# -- changing the tree --------------------------------------------------------


## Make the selection a new sub-assembly called ``name``, inside the one
## being edited. Assemblies already in the selection go inside it. Returns
## its path, or "" when nothing was selected.
func make(name: String) -> String:
	var ids: Array = builder.selection.keys()
	if ids.is_empty():
		return ""
	var segment: String = unused_name(name) + "#1"
	var path: String = join(entered, segment)
	Language.keep_name(definition(segment))
	var changes: Dictionary = {}
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null or scenery.has(brick_id) or not within(path_of(brick), entered):
			continue
		var rest: String = path_of(brick).substr(entered.length()).trim_prefix("/")
		changes[brick_id] = path if rest.is_empty() else path + "/" + rest
	if changes.is_empty():
		return ""
	builder.regroup(changes, "made the sub-assembly %s of %s" % [definition(segment),
		Builder._many(changes.size())], wrapped(changes),
		made_steps(PackedStringArray([path])))
	changed.emit()
	return path


## What [method ungroup] last said of the lights and views it moved or let
## go ([method _lines_apart]), for the status bar after "took … apart"; ""
## when it moved none.
var apart_said: String = ""


## Take an assembly apart one level: what was in it is in its parent. A
## copy built in steps of its own has them made its parent's, in the order
## they were built (AuthorSteps.inlined), and the looks of the steps with
## them (BookletLooks.inlined). Its lights go with its parts, and its last
## copy takes its definition's lights and views with it ([method
## _lines_apart]), in the same step.
func ungroup(path: String) -> int:
	apart_said = ""
	if path.is_empty():
		return 0
	var parent: String = parent_of(path)
	var changes: Dictionary = {}
	for brick: BrickWorld.Brick in bricks_under(path):
		var rest: String = path_of(brick).substr(path.length()).trim_prefix("/")
		changes[brick.id] = parent if rest.is_empty() else join(parent, rest)
	if changes.is_empty():
		return 0
	if within(entered, path) and entered != parent:
		leave_to(parent)
	var numbers: Dictionary = AuthorSteps.inlined(world, path, scenery)
	var looks: Dictionary = BookletLooks.inlined(world, path, numbers)
	# Read while the copy is still one, before its parts move.
	var lit: Dictionary = _lines_apart(path)
	var carry: Callable = func(at: String) -> Array:
		if at == path:
			return []
		return [join(parent, at.substr(path.length() + 1))] if within(at, path) else [at]
	if builder.regroup(changes, "took %s apart" % label(path), carry, numbers) > 0:
		if not looks.is_empty():
			builder.extend_last([{"undo": "steplooks", "looks": world.step_looks}])
			world.step_looks = looks
		_lines_gone_apart(lit)
	changed.emit()
	return changes.size()


## Take the parts [param ids] out of the sub-assembly each is in, into the one
## round it: Ungroup with parts picked inside a copy. A copy it leaves empty
## is a copy taken apart, as [method ungroup] takes one ([method
## _lines_apart]): its lights go with its parts into the one round it, its
## last copy's views go, in the same step, and [member apart_said] says so.
## Up to 2026-11-11 its lights and views went silently (lp2check R). Returns
## how many parts moved.
func take_out(ids: Array) -> int:
	apart_said = ""
	var changes: Dictionary = {}
	var leaving: Dictionary = {}    ## a copy -> how many of its own parts leave it
	for brick_id: Variant in ids:
		var brick: BrickWorld.Brick = world.get_brick(int(brick_id))
		if brick == null:
			continue
		var path: String = path_of(brick)
		changes[brick.id] = parent_of(path)
		leaving[path] = int(leaving.get(path, 0)) + 1
	# Its own parts all out, and none inside a copy in it: emptied. Copies
	# emptied are never one inside another, as what leaves one stays in the
	# one round it.
	var emptied: Array = []
	for path: String in leaving:
		if not path.is_empty() and bricks_under(path).size() == int(leaving[path]):
			emptied.append(path)
	# Read while each is still one, before its parts move.
	var lit: Dictionary = {}
	for path: String in emptied:
		var next: Dictionary = _lines_apart(path, lit, emptied)
		lit = next if not next.is_empty() else lit
	var moved: int = builder.regroup(changes, "took %s out of its sub-assembly"
		% Builder._many(changes.size()))
	if moved > 0:
		_lines_gone_apart(lit)
		changed.emit()
	return moved


## What [method _lines_apart] found, made so in the newest step of the
## history, after the parts moved: the lines by definition, the frames it
## gave the copies of one that gains lines, and none for the copies it took
## apart ([method set_lines]); the lights the model gains ("scenelights"),
## and said ([member apart_said]).
func _lines_gone_apart(lit: Dictionary) -> void:
	if lit.is_empty():
		return
	var frames: Dictionary = world.section_frames.duplicate()
	frames.merge(lit["framed"], true)
	for path: String in lit["gone"]:
		frames.erase(path)
	set_lines(builder, lit["lines"], frames)
	if not (lit["lights"] as Array).is_empty():
		builder.extend_last([{"undo": "scenelights", "take": lit["lights"], "put": []}])
		world.scene_lights = world.scene_lights + (lit["lights"] as Array)
	apart_said = lit["said"]


## What taking the copy at [param path] apart does to the lines kept by
## definition (BrickWorld.section_lines), read before its parts move. Each of
## its definition's lights goes with its parts: from the frame its lines are
## in where this copy stands ([method _frame_of]), into the lines of the one
## it is in, in the frame those are in there, or the model's own lights
## (BrickWorld.scene_lights) when that is the model, as many as a model keeps
## (SceneLights.joins). A mirrored copy's go mirrored. One it is in that had
## no lines has its copies framed from now where a save writes each. Its last
## copy takes its definition's lines with it: its views too, as a view of a
## sub-model that is gone frames nothing. [param before] is what one before
## it in the same change found (from its tables on), and [param going] the
## copies that change takes apart. Returns {"lines": the table after,
## "framed": frames given (BrickWorld.section_frames, by path), "gone": the
## copies taken apart, "lights": those the model gains, in the window's
## coordinates, "said": the words for it}, or {} when it has none. Up to
## 2026-11-11 the lines stayed under its name, and a save wrote them in
## whatever next took the name (lpcheck s6, s12); before that, taken apart,
## its lights went unsaid; and up to 2026-11-11 they were placed by where a
## save writes its first copy, not by the frame they were read in, so a copy
## moved before it was taken apart left its light behind (lp2check M), and
## then by a frame found again from its parts, which no mirrored copy lay on:
## a mirrored copy's light landed 120 LDU off its parts, unmirrored (pccheck
## FW3).
func _lines_apart(path: String, before: Dictionary = {}, going: Array = []) -> Dictionary:
	var had: Dictionary = before.get("lines", world.section_lines)
	var def: String = definition(leaf(path))
	if not had.has(def):
		return {}
	var parent: String = parent_of(path)
	var parent_def: String = definition(leaf(parent))
	var framed: Dictionary = (before.get("framed", {}) as Dictionary).duplicate()
	# A copy in hand stands, as it does for lines_follow: put down, it is
	# still one. A copy the same change takes apart does not.
	var others: Array = Array(copies_of(path)).filter(func(other: String) -> bool:
		return not going.has(other))
	var last: bool = others.is_empty() and not _in_hand(builder).has(def)
	# Its definition's file coordinates, in the frame its lines are in here,
	# to the window's, and on to the frame its parent's lines are in there.
	var flip := Transform3D(Basis.from_scale(LdrModel.FLIP), Vector3.ZERO)
	var through: Transform3D = _frame_of(path, framed) * flip
	if not parent.is_empty():
		# The one round it, with no lines yet: each of its copies framed
		# where a save writes it, carried with it from now.
		if not had.has(parent_def) and not framed.has(parent):
			var written: Dictionary = file_frames()
			for copy: String in Array(copies_of(parent)) + [parent]:
				if not world.section_frames.has(copy):
					framed[copy] = (written.get(copy, {}) as Dictionary).get("frame",
						Transform3D.IDENTITY)
		through = flip * _frame_of(parent, framed).affine_inverse() * through
	var lines: Dictionary = had.duplicate()
	var theirs := PackedStringArray(lines.get(parent_def, PackedStringArray()))
	var gained: Array = (before.get("lights", []) as Array).duplicate()
	var moved: int = 0
	var lost: int = 0
	var why: String = ""
	var views: int = 0
	for line: String in had[def]:
		var word: String = _meta_word(line)
		if word != "LIGHT":
			views += 1 if word == "VIEW" else 0
			continue
		var light: Dictionary = SceneLights.of_line(line)
		var reason: String = "not a light's words" if light.is_empty() else ""
		if reason.is_empty():
			light = SceneLights.through(light, through)
			if parent.is_empty():
				reason = SceneLights.joins(world.scene_lights + gained, light)
				if reason.is_empty():
					gained.append(light)
			else:
				theirs.append(SceneLights.META + JSON.stringify(light))
		if reason.is_empty():
			moved += 1
		else:
			lost += 1
			why = reason
	if not parent.is_empty() and moved > 0:
		lines[parent_def] = theirs
	if last:
		lines.erase(def)
	var said := PackedStringArray()
	var was: String = str(before.get("said", ""))
	if not was.is_empty():
		said.append(was)
	if moved > 0:
		said.append("its light went with its parts" if moved == 1
			else "its %d lights went with its parts" % moved)
	if lost > 0:
		said.append("one of its lights went with it" if lost == 1
			else "%d of its lights went with it" % lost)
		said.append(why)
	if last and views > 0:
		said.append("its saved view went with it" if views == 1
			else "its %d saved views went with it" % views)
	var gone: Array = (before.get("gone", []) as Array) + [path]
	return {"lines": lines, "framed": framed, "gone": gone, "lights": gained,
		"said": " — ".join(said)}


## Where the frame the lines of the sub-model at [param path] are in stands
## for that copy, in the window's coordinates: as [param given] or BrickWorld
## .section_frames has it, carried with the copy since the open by every
## change that moved it; or, for a copy with none (put down since by
## something that carried none), where a save writes it ([method
## file_frames]), as its lines are then written.
func _frame_of(path: String, given: Dictionary = {}) -> Transform3D:
	if given.has(path):
		return given[path]
	if world.section_frames.has(path):
		return world.section_frames[path]
	return (file_frames().get(path, {}) as Dictionary).get("frame", Transform3D.IDENTITY)


## The word after "0 !BRICKWORKS" on [param line] ("LIGHT", "VIEW"), or "".
static func _meta_word(line: String) -> String:
	var words: PackedStringArray = line.strip_edges().replace("\t", " ").split(" ", false, 3)
	return words[2] if words.size() > 2 and words[0] == "0" and words[1] == "!BRICKWORKS" else ""


## Call a definition something else, in every copy of it.
func rename(path: String, wanted: String) -> String:
	var old: String = definition(leaf(path))
	var name: String = wanted.strip_edges().replace("/", "-").replace("#", "")
	if name.is_empty() or name == old:
		return old
	name = unused_name(name)
	Language.keep_name(name)
	var changes: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if path_of(brick).is_empty():
			continue
		var parts: PackedStringArray = segments(path_of(brick))
		var touched: bool = false
		for n: int in parts.size():
			if definition(parts[n]) == old:
				parts[n] = "%s#%d" % [name, copy_of(parts[n])]
				touched = true
		if touched:
			changes[brick.id] = "/".join(parts)
	if changes.is_empty():
		return old
	var was_entered: String = entered
	var carry: Callable = func(at: String) -> Array: return [_renamed_path(at, old, name)]
	# Its steps' looks are kept by its name, and so are its own lights and views.
	if builder.regroup(changes, "renamed %s to %s" % [old, name], carry) > 0:
		builder.extend_last(BookletLooks.renamed(world, old, name, true))
		lines_renamed(builder, old, name, true)
	if not was_entered.is_empty():
		_set_entered(_renamed_path(was_entered, old, name))
	changed.emit()
	return name


## A sub-model's own lines (BrickWorld.section_lines) of [param from] given
## to [param to] as well, or with [param moved] in their place, in the newest
## step of the history ([method set_lines]), as BookletLooks.renamed carries
## its looks: a rename takes them, a copy made one of its own keeps them.
## [param to] is a name no sub-model has ([method unused_name]), and none
## keeps lines: a sub-model's go with its last copy ([method lines_follow]).
static func lines_renamed(builder: Builder, from: String, to: String, moved: bool) -> void:
	var lines: Dictionary = builder.world.section_lines
	if to.is_empty() or from == to or not lines.has(from):
		return
	var now: Dictionary = lines.duplicate()
	now[to] = PackedStringArray(lines[from])
	if moved:
		now.erase(from)
	# Their frames, by the copies' paths, went with the copies
	# (Builder._carry).
	set_lines(builder, now)


## The world's lines by definition (BrickWorld.section_lines) made [param
## lines], in the newest step of the history (Builder.extend_last). Its undo
## is the table as that step found it, kept once however many of the step's
## changes make them: a step's undos are applied in their order, so with two
## kept the later won, and the Undo of a Sections accept that kept one for
## each of two names left the first one's lights and views out (lpcheck s6).
## A step folded of others (Builder.fold_since) holds theirs newest first,
## and its oldest, put back last, is the table as the first found it.
## [param frames] are where the frame they are in stands for each copy
## (BrickWorld.section_frames, by path), the world's as they are when not
## given: kept only for a copy of a definition that keeps lines, in the same
## undo.
static func set_lines(builder: Builder, lines: Dictionary, frames: Variant = null) -> void:
	var world: BrickWorld = builder.world
	var given: Dictionary = frames if frames is Dictionary else world.section_frames
	var framed: Dictionary = {}
	for path: String in given:
		if lines.has(definition(leaf(path))):
			framed[path] = given[path]
	if lines == world.section_lines and framed == world.section_frames:
		return
	if not _keeps_lines(builder.last_step()):
		builder.extend_last([{"undo": "sectionlines", "lines": world.section_lines,
			"frames": world.section_frames}])
	world.section_lines = lines
	world.section_frames = framed


## Whether history [param step], or one in it, puts the world's lines back
## ([method set_lines]).
static func _keeps_lines(step: Dictionary) -> bool:
	if str(step.get("undo", "")) == "sectionlines":
		return true
	for inner: Variant in step.get("steps", []):
		if inner is Dictionary and _keeps_lines(inner):
			return true
	return false


## After an edit kept in the history, [param step] (Builder.last_step): the
## lines of each sub-model it left no copy of (BrickWorld.section_lines) gone,
## in that step ([method set_lines]), so its Undo puts them back with the
## copy: deleted, cut, taken off over MCP, or every part moved out of it. A
## copy taken apart takes its own ([method ungroup]). A sub-model one of
## [param held] is in (ModelStore's parts on their way and those the
## catalogue lacks, which a save writes in their sub-models) is still there,
## and so is one a copy in hand is of ([method _in_hand]). Cut, the
## clipboard has them for its paste ([method lines_held]).
## Kept under its name, a gone sub-model's lines were written in whatever
## next took the name: a copy pasted from another model, a hose laid, a
## Make, a Sections accept (lpcheck s12).
##
## And the frame each copy's lines are in (BrickWorld.section_frames) moved
## as the step moved that copy, every part of it alike ([method
## frames_moved]): a turn, a tip, a drag, a pose, a session's move. A copy
## no longer in the model takes its frame with it, and its Undo brings both.
static func lines_follow(builder: Builder, step: Dictionary, held: Array = []) -> void:
	var world: BrickWorld = builder.world
	if world.section_lines.is_empty() or step.is_empty():
		return
	var moves: Dictionary = moves_in(builder, step)
	var left: Dictionary = {}
	_left_from(step, left)
	if moves.is_empty() and left.is_empty():
		return
	var frames: Dictionary = frames_moved(world, world.section_frames, moves)
	if left.is_empty():
		set_lines(builder, world.section_lines, frames)
		return
	var standing: Dictionary = _in_hand(builder)
	var stands: Dictionary = _paths_in_hand(builder)
	for brick: BrickWorld.Brick in world.bricks():
		var at: String = ""
		for segment: String in segments(path_of(brick)):
			standing[definition(segment)] = true
			at = join(at, segment)
			stands[at] = true
	for item: Variant in held:
		var placement: LdrModel.Placement = item
		var at: String = ""
		for segment: String in segments(path_from(placement.group, placement.unit)):
			standing[definition(segment)] = true
			at = join(at, segment)
			stands[at] = true
	for path: String in frames.keys():
		if not stands.has(path):
			frames.erase(path)
	var lines: Dictionary = world.section_lines.duplicate()
	for def: String in left:
		if lines.has(def) and not standing.has(def):
			lines.erase(def)
	set_lines(builder, lines, frames)


## How history [param step] moved each part it moved: brick id -> where it
## is now against where the step found it (now times then's inverse), from
## its "move"s, the one undone last (a step's undos run in their order, so
## the last is where it began) giving where it was. A part the step put
## down has no move. Turns, tips, drags, poses and a session's moves are
## each kept so, as one transform of every part they move.
static func moves_in(builder: Builder, step: Dictionary) -> Dictionary:
	var was: Dictionary = {}
	var put: Dictionary = {}
	_moves_from(builder, step, was, put)
	var out: Dictionary = {}
	for brick_id: int in was:
		var brick: BrickWorld.Brick = builder.world.get_brick(brick_id)
		if brick != null and not put.has(brick_id):
			out[brick_id] = brick.transform * (was[brick_id] as Transform3D).affine_inverse()
	return out


static func _moves_from(builder: Builder, step: Dictionary, was: Dictionary, put: Dictionary) -> void:
	match str(step.get("undo", "")):
		"group":
			for inner: Variant in step.get("steps", []):
				if inner is Dictionary:
					_moves_from(builder, inner, was, put)
		"move":
			was[builder._live(int(step["brick"]))] = step["transform"]
		"remove":
			put[builder._live(int(step["brick"]))] = true


## [param frames] (BrickWorld.section_frames: copy path -> where its lines'
## frame stands) with each copy every part of which [param moves] (brick id
## -> how it moved) moved alike moved with it, nested copies too. A copy only
## some of whose parts moved, or not alike, is the same sub-model changed:
## its frame stays. Up to 2026-11-11 a frame was found again from a few of
## its copy's parts wherever they stood, and no match saw a mirrored copy,
## or a turn of one whose parts look the same turned (pccheck FW, FX, FY).
static func frames_moved(world: BrickWorld, frames: Dictionary, moves: Dictionary) -> Dictionary:
	if frames.is_empty() or moves.is_empty():
		return frames
	var how: Dictionary = {}     ## a framed path -> its parts' one move, or null
	for brick: BrickWorld.Brick in world.bricks():
		var at: String = ""
		for segment: String in segments(path_of(brick)):
			at = join(at, segment)
			if not frames.has(at):
				continue
			var moved: Variant = moves.get(brick.id)
			if moved == null:
				how[at] = null
			elif not how.has(at):
				how[at] = moved
			elif how[at] != null and not _alike(how[at], moved):
				how[at] = null
	var out: Dictionary = frames.duplicate()
	for path: String in how:
		if how[path] != null:
			out[path] = (how[path] as Transform3D) * (frames[path] as Transform3D)
	return out


## Each copy's frame (BrickWorld.section_frames) carried as [param moves]
## (brick id -> how it moved) moved its parts, in the newest step of the
## history ([method frames_moved], [method set_lines]): what a move put down
## (Builder._put_carried), a mirror (Builder.mirror_bricks) and a drive kept
## call, as their parts are put down anew, not moved.
static func frames_carried(builder: Builder, moves: Dictionary) -> void:
	var world: BrickWorld = builder.world
	var frames: Dictionary = frames_moved(world, world.section_frames, moves)
	if frames != world.section_frames:
		set_lines(builder, world.section_lines, frames)


## Each copy history [param step] took parts off the model of ("add", which
## puts one back) that has no part on the baseplate now, nor any in hand:
## deleted, cut, or taken off over MCP. Paths, each one round it too.
static func copies_emptied(builder: Builder, step: Dictionary) -> Array:
	var taken: Dictionary = {}
	_taken_from(step, taken)
	if taken.is_empty():
		return []
	var stands: Dictionary = _paths_in_hand(builder)
	for brick: BrickWorld.Brick in builder.world.bricks():
		var at: String = ""
		for segment: String in segments(path_of(brick)):
			at = join(at, segment)
			stands[at] = true
	return taken.keys().filter(func(path: String) -> bool: return not stands.has(path))


static func _taken_from(step: Dictionary, into: Dictionary) -> void:
	match str(step.get("undo", "")):
		"group":
			for inner: Variant in step.get("steps", []):
				if inner is Dictionary:
					_taken_from(inner, into)
		"add":
			var at: String = ""
			for segment: String in segments(path_from(str(step.get("group", "")),
					str(step.get("unit", "")))):
				at = join(at, segment)
				into[at] = true


## Every path of the parts in hand, and each one round it ([method _in_hand]).
static func _paths_in_hand(builder: Builder) -> Dictionary:
	var out: Dictionary = {}
	if not builder.is_carrying():
		return out
	for item: Dictionary in builder.carrying.items:
		var at: String = ""
		for segment: String in segments(path_from(str(item.get("group", "")),
				str(item.get("unit", "")))):
			at = join(at, segment)
			out[at] = true
	return out


## The sub-model of every part in hand (Builder.carrying), and each one it
## is inside: lifted off the model to move it, or a copy to put down.
static func _in_hand(builder: Builder) -> Dictionary:
	var out: Dictionary = {}
	if not builder.is_carrying():
		return out
	for item: Dictionary in builder.carrying.items:
		for segment: String in segments(path_from(str(item.get("group", "")),
				str(item.get("unit", "")))):
			out[definition(segment)] = true
	return out


## For the clipboard (Carry.clipboard_lines): the lights and views of each
## sub-model [param parts] (Carry.gather's) are in, at any depth. Cut, the
## model lets them go with the parts (lines_follow), and a paste brings them
## back, into this model or another.
static func lines_held(world: BrickWorld, parts: Array) -> Dictionary:
	var out: Dictionary = {}
	if world.section_lines.is_empty():
		return out
	for item: Dictionary in parts:
		for segment: String in segments(path_from(str(item.get("group", "")),
				str(item.get("unit", "")))):
			var def: String = definition(segment)
			if world.section_lines.has(def):
				out[def] = PackedStringArray(world.section_lines[def])
	return out


## For the clipboard too (Carry.clipboard_frames): where the frame its lines
## are in stands (BrickWorld.section_frames) for each copy [param parts]
## (Carry.gather's) are in, at any depth, so a paste puts them where the copy
## it puts down stands.
static func frames_held(world: BrickWorld, parts: Array) -> Dictionary:
	var out: Dictionary = {}
	if world.section_frames.is_empty():
		return out
	for item: Dictionary in parts:
		var at: String = ""
		for segment: String in segments(path_from(str(item.get("group", "")),
				str(item.get("unit", "")))):
			at = join(at, segment)
			if world.section_frames.has(at):
				out[at] = world.section_frames[at]
	return out


## Every sub-model [param world] has before a paste: one a part is in, or
## one with lights or views kept. A paste's lines never replace these.
static func definitions_had(world: BrickWorld) -> Dictionary:
	var out: Dictionary = {}
	for def: String in world.section_lines:
		out[def] = true
	for brick: BrickWorld.Brick in world.bricks():
		for segment: String in segments(path_of(brick)):
			out[definition(segment)] = true
	return out


## A paste's step (the newest) takes the lights and views [param carried]
## (lines_held) of each sub-model it put a copy of down: [param pasted] is
## each part's [path in the clipboard, path it was given], the sub-model of
## each segment matched from the leaf up, so one renamed (a figure: "Guard"
## to "Guard 2") takes its own. A sub-model the model [param had]
## (definitions_had) keeps what it had, and what is returned says so where
## the copied ones differed; "" otherwise. Undo takes them out with the
## parts, Redo puts them back. Each copy put down whose lines here are the
## copied ones stands in the frame its copied one stood in ([param frames],
## frames_held's), moved as the paste moved the parts ([param moved],
## Carry.moved): up to 2026-11-11 they kept the frame of the copy copied, and
## a light pasted into another model was written where that copy had been
## (lp2check P). One whose lines here are another model's is in no frame of
## them, and a save writes them in another copy (lines_written).
static func lines_pasted(builder: Builder, carried: Dictionary, pasted: Array,
		had: Dictionary, frames: Dictionary = {}, moved: Transform3D = Transform3D.IDENTITY) -> String:
	var lines: Dictionary = builder.world.section_lines.duplicate()
	var framed: Dictionary = builder.world.section_frames.duplicate()
	var seen: Dictionary = {}
	var put: Dictionary = {}
	var kept := PackedStringArray()
	for pair: Array in pasted:
		var from: PackedStringArray = segments(str(pair[0]))
		var to: PackedStringArray = segments(str(pair[1]))
		for n: int in mini(from.size(), to.size()):
			var was: String = definition(from[from.size() - 1 - n])
			var now: String = definition(to[to.size() - 1 - n])
			if not carried.has(was):
				continue
			if not seen.has(now):
				seen[now] = true
				if not had.has(now):
					lines[now] = PackedStringArray(carried[was])
				elif PackedStringArray(lines.get(now, PackedStringArray())) \
						!= PackedStringArray(carried[was]):
					kept.append("%s here keeps its own lights and views, not the copied ones" % now)
			var copied: String = "/".join(from.slice(0, from.size() - n))
			var copy: String = "/".join(to.slice(0, to.size() - n))
			if not put.has(copy) and frames.has(copied) and PackedStringArray(lines.get(now,
					PackedStringArray())) == PackedStringArray(carried[was]):
				put[copy] = true
				framed[copy] = moved * (frames[copied] as Transform3D)
	set_lines(builder, lines, framed)
	return "; ".join(kept)


## Into [param into], the definition of every copy history [param step] took
## a part off or out of: each part taken off ("add", which puts it back) and
## each moved in the tree ("regroup"), by the path it had.
static func _left_from(step: Dictionary, into: Dictionary) -> void:
	var kind: String = str(step.get("undo", ""))
	if kind == "group":
		for inner: Variant in step.get("steps", []):
			if inner is Dictionary:
				_left_from(inner, into)
		return
	if kind != "add" and kind != "regroup":
		return
	for segment: String in segments(path_from(str(step.get("group", "")),
			str(step.get("unit", "")))):
		into[definition(segment)] = true


## [param model]'s sub-models' own lines (LdrModel.section_lines), by the
## definition their copies are of once laid (LdrModel._assembly_names), as
## BrickWorld.section_lines keeps them.
static func lines_of(model: LdrModel) -> Dictionary:
	var out: Dictionary = {}
	if model.section_lines.is_empty():
		return out
	var names: Dictionary = model._assembly_names()
	for key: String in model.section_lines:
		if names.has(key):
			out[str(names[key])] = PackedStringArray(model.section_lines[key])
	return out


## The lines each definition [param instances] (file_frames, each frame in
## the file's coordinates: [param back] of where it stands) writes keeps of
## its own, for LdrModel.write_tree: those of the sub-model its copies are of
## ([param lined]'s BrickWorld.section_lines), a copy written as one of its own
## ("Wing 2") among them. Each in the frame its definition is written in, from
## the one they are in where its first copy written that has one stands
## (BrickWorld.section_frames, carried with it by every change since the
## open): a copy moved, turned, mirrored, pasted into another model, or
## written from somewhere other than where the file had it ([method
## rebased]). This tree's world is the model as it is written, [param lined]
## the one that keeps the lines (ModelStore._text_into: the same one, or the
## one a section broken out is written home from, its frames brought home
## with its parts). Up to 2026-11-11 they were written as read, and a light
## stayed where its copy had been (lp2check P_moved; lpcheck s7_a: another
## tool's file whose first copy is not where the app writes it).
##
## A copy written as one of its own that is in no frame of them (another
## model's Sub pasted in under this one's name: lines_pasted) is written
## without them while a copy in one has them: placed by nothing, they were
## written at the other copy's place, a second light on it. Where no copy has
## a frame of them, they are written as they are kept.
func lines_written(lined: BrickWorld, instances: Dictionary, back: Transform3D) -> Dictionary:
	var out: Dictionary = {}
	if lined.section_lines.is_empty():
		return out
	var flip := Transform3D(Basis.from_scale(LdrModel.FLIP), Vector3.ZERO)
	var chosen: Dictionary = {}      ## written name -> [path, its frame or null]
	for path: String in instances:
		var def: String = definition(leaf(path))
		if not lined.section_lines.has(def):
			continue
		var written: String = str((instances[path] as Dictionary)["def"])
		var frame: Variant = _frame_written(lined, path)
		if not chosen.has(written) or (chosen[written] as Array)[1] == null and frame != null:
			chosen[written] = [path, frame]
	var framed: Dictionary = {}      ## definition -> true, written through a frame
	for written: String in chosen:
		var path: String = (chosen[written] as Array)[0]
		var frame: Variant = (chosen[written] as Array)[1]
		if frame == null:
			continue
		framed[definition(leaf(path))] = true
		var into: Transform3D = flip * ((instances[path] as Dictionary)["frame"] as Transform3D) \
			.affine_inverse() * back
		out[written] = rebased(PackedStringArray(lined.section_lines[definition(leaf(path))]),
			into * (frame as Transform3D) * flip)
	for written: String in chosen:
		var path: String = (chosen[written] as Array)[0]
		var def: String = definition(leaf(path))
		if (chosen[written] as Array)[1] == null and not framed.has(def):
			out[written] = PackedStringArray(lined.section_lines[def])
	return out


## Where the frame the lines of the copy at [param path] are in stands, as
## [param lined] keeps it (BrickWorld.section_frames), brought home with its
## parts where a section broken out has it (BrickWorld.home_of); null for a
## copy with none.
static func _frame_written(lined: BrickWorld, path: String) -> Variant:
	var frame: Variant = lined.section_frames.get(path)
	if frame == null:
		return null
	for section: String in lined.broken_out:
		if within(path, section):
			var offset: Vector3 = (lined.broken_out[section] as Dictionary).get("offset", Vector3.ZERO)
			return (frame as Transform3D).translated(-offset)
	return frame


## [param lines], a sub-model's own (LIGHT and VIEW: BrickWorld
## .section_lines), carried by [param through] from the file's coordinates of
## one frame of its definition to another's: each light's place and the way
## it shines (SceneLights.through), each view's point and the way it looks
## (SavedViews.through_line). As they are where it moves nothing, and a line
## that is not read as one is as it is.
static func rebased(lines: PackedStringArray, through: Transform3D) -> PackedStringArray:
	if through.is_equal_approx(Transform3D.IDENTITY):
		return lines
	var out := PackedStringArray()
	for line: String in lines:
		match _meta_word(line):
			"LIGHT":
				var light: Dictionary = SceneLights.of_line(line)
				out.append(line if light.is_empty()
					else SceneLights.META + JSON.stringify(SceneLights.through(light, through)))
			"VIEW":
				out.append(SavedViews.through_line(line, through))
			_:
				out.append(line)
	return out


## Where the frame each sub-model's own lines (BrickWorld.section_lines) are
## in stands for each of its copies, as [param model], the file just laid,
## placed them, the model stood [param up] from where its file has it: every
## copy's reference as the file has it, a mirrored one's reflecting, and
## carried with it from now by every change that moves it. What BrickWorld
## .section_frames keeps from the open (ModelStore._open_into).
func frames_read(model: LdrModel, up: Vector3) -> Dictionary:
	var out: Dictionary = {}
	if world.section_lines.is_empty():
		return out
	var lifted := Transform3D(Basis.IDENTITY, up)
	for path: String in model.unit_frames:
		if world.section_lines.has(definition(leaf(path))):
			out[path] = lifted * (model.unit_frames[path] as Transform3D)
	return out


static func _renamed_path(path: String, old: String, name: String) -> String:
	var parts: PackedStringArray = segments(path)
	for n: int in parts.size():
		if definition(parts[n]) == old:
			parts[n] = "%s#%d" % [name, copy_of(parts[n])]
	return "/".join(parts)


## Where a change that puts parts inside new sub-assemblies ([method make],
## Sections.accept) puts each assembly they were in, as Builder.regroup
## carries what is kept by its path: [param changes] are brick id -> the
## path it is given, the path below its level kept ("Tower#1" in "Keep#1/
## Tower#1"). An assembly some of whose parts stay where they were is split:
## in both places. Read before the change.
func wrapped(changes: Dictionary) -> Callable:
	var to: Dictionary = {}         ## path -> {a path it is at after: true}
	var going: Dictionary = {}      ## path -> how many of its parts go
	for brick_id: int in changes:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		var was: PackedStringArray = segments(path_of(brick))
		var now: PackedStringArray = segments(str(changes[brick_id]))
		var kept: int = 0
		while kept < mini(was.size(), now.size()) \
				and was[was.size() - 1 - kept] == now[now.size() - 1 - kept]:
			kept += 1
		for n: int in kept:
			var path: String = "/".join(was.slice(0, was.size() - n))
			if not to.has(path):
				to[path] = {}
			(to[path] as Dictionary)["/".join(now.slice(0, now.size() - n))] = true
			going[path] = int(going.get(path, 0)) + 1
	var split: Dictionary = {}
	for path: String in going:
		if bricks_under(path).size() > int(going[path]):
			split[path] = true
	return func(path: String) -> Array:
		if not to.has(path):
			return [path]
		var out: Array = (to[path] as Dictionary).keys()
		if split.has(path):
			out.append(path)
		return out


## The steps of sub-assemblies [param made] from parts of a model with steps
## of its own, as Builder.regroup takes them: each built in the steps of the
## one round it (AuthorSteps.IN_PARENT), so the parts stay in the steps the
## person sees. Built whole, the castle's east wall and tower made one
## sub-assembly moved 2,194 of its 2,497 parts to other steps, and from step
## 53 bricks were put down in the air (unitsteps). In a model with no steps,
## none, and no step an old copy of that name left.
func made_steps(made: PackedStringArray) -> Dictionary:
	var units: Dictionary = {}
	var step: int = AuthorSteps.IN_PARENT if AuthorSteps.any(world, scenery) else -1
	for path: String in made:
		units[path] = step
	return {"units": units}


## A copy cut loose from the others: a definition of its own, so editing it
## no longer changes them.
func make_unique(path: String) -> String:
	if path.is_empty():
		return ""
	var name: String = unused_name(definition(leaf(path)))
	var fresh: String = join(parent_of(path), name + "#1")
	var changes: Dictionary = {}
	for brick: BrickWorld.Brick in bricks_under(path):
		changes[brick.id] = fresh + path_of(brick).substr(path.length())
	var own_steps: bool = not AuthorSteps.in_parent(world, path)
	var carry: Callable = func(at: String) -> Array:
		return [fresh + at.substr(path.length())] if within(at, path) else [at]
	var moved: int = builder.regroup(changes, "made %s a sub-assembly of its own" % label(path),
		carry)
	# Built in steps of its own, it is shown as it was: its steps' looks,
	# kept by the name it had, are its new name's too.
	if own_steps and moved > 0:
		builder.extend_last(BookletLooks.renamed(world, definition(leaf(path)), name, false))
	# And its own lights and views, built in its own steps or not.
	if moved > 0:
		lines_renamed(builder, definition(leaf(path)), name, false)
	if within(entered, path):
		_set_entered(fresh + entered.substr(path.length()))
	changed.emit()
	return fresh


## Put the assembly at ``path`` inside ``into`` (or at the top, ""). What
## dragging a row in the model tree onto another does.
func move_into(path: String, into: String) -> String:
	if path.is_empty() or within(into, path) or parent_of(path) == into:
		return path
	var fresh: String = join(into, leaf(path))
	var changes: Dictionary = {}
	for brick: BrickWorld.Brick in bricks_under(path):
		changes[brick.id] = fresh + path_of(brick).substr(path.length())
	var carry: Callable = func(at: String) -> Array:
		return [fresh + at.substr(path.length())] if within(at, path) else [at]
	builder.regroup(changes, "put %s in %s" % [label(path),
		"the model" if into.is_empty() else label(into)], carry)
	changed.emit()
	return fresh


## Edit inside an assembly: its parts become clickable one by one, and a
## part put down goes into it.
func enter(path: String) -> void:
	if path == entered:
		return
	builder.clear_selection()
	_set_entered(path)


## Back out to the level above, or to the model.
func leave() -> void:
	if entered.is_empty():
		return
	leave_to(parent_of(entered))


func leave_to(path: String) -> void:
	builder.clear_selection()
	_set_entered(path)


func _set_entered(path: String) -> void:
	entered = path
	builder.place_group = path
	entered_changed.emit(path)


## The path a pasted or duplicated part's path becomes: the assembly it was
## in, another copy of the same definition ("Wing#1" pasted is "Wing#2", and
## what is inside it new copies too), inside the assembly being edited. A
## minifigure is another figure ("Guard 2"), as it always was. Loose parts
## pasted while editing go into the assembly. ``renamed`` keeps what this
## paste has given each path, so its parts stay together.
func group_for_copy(path: String, renamed: Dictionary) -> String:
	if renamed.has(path):
		return renamed[path]
	var fresh: String = entered
	if not path.is_empty() and path != entered:
		var parts: PackedStringArray = segments(path)
		# The part of the path below the level being edited, or all of it
		# when it came from somewhere else.
		var depth: int = segments(entered).size() if within(path, entered) else 0
		fresh = entered
		for n: int in range(depth, parts.size()):
			var was: String = "/".join(parts.slice(0, n + 1))
			if renamed.has(was):
				fresh = renamed[was]
				continue
			var kind: String = definition(parts[n])
			if n == depth and _is_figure(was):
				fresh = join(fresh, builder.unused_group(kind) + "#1")
			else:
				fresh = join(fresh, next_copy(kind))
			renamed[was] = fresh
	renamed[path] = fresh
	return fresh


func _is_figure(path: String) -> bool:
	var members: Array = bricks_under(path)
	return not members.is_empty() and Minifig.is_figure(members, library)


# -- copies follow ------------------------------------------------------------


## After an edit made by hand: every assembly it touched that has other
## copies, and those copies built again from it, as part of the same undo
## step. A copy moved, turned or mirrored whole still lies on the others
## exactly, and is left as it is.
func after_edit() -> int:
	if _syncing:
		return 0
	var step: Dictionary = builder.last_step()
	# An undo or a redo changed the model by a step whose copies already
	# followed it, inside it (Builder.settled): nothing to build again. Asked
	# again, the undo of a move of everything matched every copy of every
	# sub-model against the others once more, and the step left newest by
	# an undo had its copies built again into it, long after it was made.
	if step.is_empty() or is_same(step, _seen) or is_same(step, builder.settled):
		return 0
	_seen = step
	var followed: Array = copies_follow(builder.touched_groups(step), _moved_by(step))
	var steps: Array = followed[0]
	if not steps.is_empty():
		builder.extend_last(steps)
		changed.emit()
	return int(followed[1])


## The newest step changed where parts are in the tree and not one part's
## shape or place (Sections.accept): no copy is built again for it. Copies a
## file holds that were never alike (31037's, 10179's) were rebuilt from
## one of them when sections were made round them, 1,115 parts of 10179-1
## swapped for others (2026-10-17).
func no_copies_follow() -> void:
	_seen = builder.last_step()


## Every other copy of the assemblies at [param touched] (paths, and
## what they are in) built again from the one that changed. Returns
## [history steps, copies rebuilt]; the caller keeps the steps with the
## change that caused them, so one undo takes back both. Claude's change
## to a selection gathers into a step of its own (Assistant.focus), which
## after_edit, looking once at the newest step, would not see again.
## [param moved]: brick id -> how a step moved it ([method _moved_by]). An
## assembly all of whose parts moved alike is the same shape as before, and
## is left as it is: moving everything matched every copy of every
## sub-model against the others, and on a 4,139-part set that was most of
## a second whenever the copies were alike, and seconds when some were not.
func copies_follow(touched: Dictionary, moved: Dictionary = {}) -> Array:
	var paths_touched: Dictionary = {}
	for group: String in touched:
		var path: String = ""
		for segment: String in segments(group):
			path = join(path, segment)
			paths_touched[path] = true
	# Innermost first: a wing's copies follow the wing, and then the car's
	# copies already match the car.
	var order: Array = paths_touched.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		return segments(a).size() > segments(b).size())
	# No copy of any of them, nothing to build again: asked of the model's
	# paths alone first. A replace of Orthanc touched ten sub-models, none
	# with a copy, and each was read out whole for nothing.
	if not _any_copied(order):
		return [[], 0]
	var steps: Array = []
	var rebuilt: int = 0
	_syncing = true
	_begin_pass()
	for path: String in order:
		if not moved.is_empty() and _moved_alike(path, moved):
			continue
		var source: Array = content(path)
		if source.is_empty():
			continue
		for other: String in copies_of(path):
			var target: Array = content(other)
			if target.is_empty():
				continue
			var fit: Dictionary = best_match(source, target)
			if bool(fit["exact"]) or int(fit["score"]) == 0:
				continue
			steps.append_array(realize(path, other, fit["at"], bool(fit["mirrored"])))
			# The model changed: read again at the next question.
			_indexed = false
			rebuilt += 1
	_end_pass()
	_syncing = false
	return [steps, rebuilt]


## Whether any of [param asked] (paths) has a copy, as [method copies_of]
## inside a pass finds them: every path of a part that is no baseplate, read
## from each part's own path, not built into the index.
func _any_copied(asked: Array) -> bool:
	var own: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if not scenery.has(brick.id):
			own[path_of(brick)] = true
	var every: Dictionary = {}
	for at: String in own:
		var path: String = ""
		for segment: String in segments(at):
			path = join(path, segment)
			every[path] = true
	for path: String in asked:
		var name: String = definition(leaf(path))
		for other: String in every:
			if other == path or within(other, path) or within(path, other):
				continue
			if definition(leaf(other)) == name:
				return true
	return false


## The copies [method copies_follow] would build again for [param
## touched], as [[path, other], ...], without building anything: what
## HiddenColours asks before it keeps a change, so that no copy is rebuilt
## for it. A pair counts when its fit is not exact (a symmetrical assembly
## can fit another copy several ways, and the one the search finds first
## decides).
func unlike_copies(touched: Dictionary) -> Array:
	var paths_touched: Dictionary = {}
	for group: String in touched:
		var path: String = ""
		for segment: String in segments(group):
			path = join(path, segment)
			paths_touched[path] = true
	var out: Array = []
	_begin_pass()
	for path: String in paths_touched:
		var source: Array = content(path)
		if source.is_empty():
			continue
		for other: String in copies_of(path):
			var target: Array = content(other)
			if target.is_empty():
				continue
			var fit: Dictionary = best_match(source, target)
			if not bool(fit["exact"]) and int(fit["score"]) != 0:
				out.append([path, other])
	_end_pass()
	return out


## How a history step moved each brick it moved and changed nothing else
## of: brick id -> where it is now against where it was (now times was's
## inverse). A brick the step names twice, or changes otherwise, is not in it.
func _moved_by(step: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var spoiled: Dictionary = {}
	_gather_moves(step, out, spoiled)
	for brick_id: int in spoiled:
		out.erase(brick_id)
	return out


func _gather_moves(step: Dictionary, out: Dictionary, spoiled: Dictionary) -> void:
	if step.get("undo", "") == "group":
		for inner: Variant in step.get("steps", []):
			_gather_moves(inner, out, spoiled)
		return
	if not step.has("brick"):
		return
	# Which sub-assembly a brick is in changes neither its shape nor its
	# place: a copy made its own and posed in one step (GrabDrag) moved 131
	# parts of 7191's wing alike, and read as spoiled they had a nacelle
	# matched against its copy part by part, 2.1 s in one frame.
	if step.get("undo", "") == "regroup":
		return
	var brick_id: int = builder._live(int(step["brick"]))
	if step.get("undo", "") != "move" or out.has(brick_id):
		spoiled[brick_id] = true
		return
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		spoiled[brick_id] = true
		return
	out[brick_id] = brick.transform * (step["transform"] as Transform3D).affine_inverse()


## Whether every part of the assembly at [param path] moved, and all the same
## way: then it is the shape it was.
func _moved_alike(path: String, moved: Dictionary) -> bool:
	var first: Variant = null
	for brick: BrickWorld.Brick in bricks_under(path):
		var how: Variant = moved.get(brick.id)
		if how == null:
			return false
		if first == null:
			first = how
		elif not Assemblies._alike(how, first):
			return false
	return first != null


## Two moves the same to within what 32-bit transforms keep of them: a
## turn of 7191's wing, read back part by part 300 LDU out, differed in the
## fifth decimal, beyond is_equal_approx, and its nacelle was matched against
## its copy part by part to find nothing to rebuild, 2 s in one frame.
static func _alike(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.01 and a.basis.x.distance_to(b.basis.x) < 1e-4 \
		and a.basis.y.distance_to(b.basis.y) < 1e-4 and a.basis.z.distance_to(b.basis.z) < 1e-4


## A pass over many assemblies begins: [method bricks_under] and
## [method paths] answer from one walk of the model, made at the first
## question, until [method _end_pass]. Nested passes share it.
func _begin_pass() -> void:
	if _passing == 0 and not _current():
		_indexed = false
	_passing += 1


func _end_pass() -> void:
	_passing = maxi(0, _passing - 1)
	if _passing == 0 and not _current():
		_under.clear()
		_indexed = false


## Whether the index is made and the model is as it was made for: kept
## into a pass and out of one, as outside one.
func _current() -> bool:
	return _indexed and _indexed_as == _model()


## The bricks under every path, as [method bricks_under] finds them one
## path at a time: each brick under its own path and every path above it.
func _index() -> void:
	var model: Array = _model()
	if _indexed and (_passing > 0 or model == _indexed_as):
		return
	_indexed = true
	_indexed_as = model
	_under.clear()
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var path: String = ""
		for segment: String in segments(path_of(brick)):
			path = join(path, segment)
			var listed: Variant = _under.get(path)
			if listed == null:
				listed = []
				_under[path] = listed
			(listed as Array).append(brick)


## The model as the index is kept for.
func _model() -> Array:
	return [world.generation(), world.revision, BrickWorld.paths_written, scenery.size()]


## [method content] of every assembly at once, path -> its content: one
## pass over the model, where asking each path apart is one pass a path.
func contents_by_path() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var own: String = path_of(brick)
		var path: String = ""
		for segment: String in segments(own):
			path = join(path, segment)
			if not out.has(path):
				out[path] = []
			(out[path] as Array).append({"part": brick.part_id, "color": brick.color_code,
				"at": brick.transform, "rest": own.substr(path.length()).trim_prefix("/"),
				"id": brick.id, "step": brick.step})
	return out


## Whether ``a`` lies exactly on ``b``, as [method best_match] says it, but
## asking only that: the same parts in the same colours first, and each way
## of laying one on the other given up at its first part that lands on
## nothing. {"at", "mirrored", "exact", "bases"}: "bases" when each part
## then lies turned as it is, not only filling the cells it fills.
##
## Of a fit laid as it is and a mirrored one, the one laying each part
## turned as it is: a mirrored copy of parts that look the same turned a
## half (twice_mirror's wing, a plate and a tile) lies on the first copy
## turned a half too, filling the same cells, and was written so, by a
## matrix that turns. Opened again, each of its parts came back turned a
## half from where the model had it (kt5check F2): a part read through a
## reflecting matrix is put down in its reflection (unmirror), and only the
## mirror lays each part back as it was.
func exact_match(a: Array, b: Array) -> Dictionary:
	var none: Dictionary = {"at": Transform3D.IDENTITY, "mirrored": false, "score": 0,
		"exact": false, "bases": false}
	if a.is_empty() or a.size() != b.size():
		return none
	var tally: Dictionary = {}
	for item: Dictionary in a:
		var key: String = "%s|%d" % [item["part"], int(item["color"])]
		tally[key] = int(tally.get(key, 0)) + 1
	for item: Dictionary in b:
		var key: String = "%s|%d" % [item["part"], int(item["color"])]
		if int(tally.get(key, 0)) <= 0:
			# A part reflected may be its other hand: only a mirror can match.
			return _exact_mirrored(a, b)
		tally[key] = int(tally[key]) - 1
	var found: Dictionary = _rigid_match(a, b, true)
	found["mirrored"] = false
	if bool(found["exact"]) and bool(found["bases"]):
		return found
	var mirrored: Dictionary = _exact_mirrored(a, b)
	if bool(mirrored["exact"]) and (bool(mirrored["bases"]) or not bool(found["exact"])):
		return mirrored
	return found if bool(found["exact"]) else mirrored


func _exact_mirrored(a: Array, b: Array) -> Dictionary:
	var from: Array = a.map(func(item: Dictionary) -> Dictionary: return _mirrored(item))
	var found: Dictionary = _rigid_match(from, b, true)
	found["mirrored"] = true
	return found


## The parts of an assembly and everything inside it: part, colour, where,
## and the group below the assembly ("" for its own parts).
func content(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in bricks_under(path):
		out.append({"part": brick.part_id, "color": brick.color_code,
			"at": brick.transform, "rest": path_of(brick).substr(path.length()).trim_prefix("/"),
			"id": brick.id, "step": brick.step, "origin": brick.origin})
	return out


## The copy at ``to`` built again from the one at ``from``: its parts taken
## off, and ``from``'s put down where ``at`` (and a mirror, when
## ``mirrored``) lays them. Returns the history steps, newest last.
##
## A copy built in its parent's steps (AuthorSteps.IN_PARENT) has steps of
## its own, not its definition's, so each part goes in the step of the one it
## takes the place of: the same part where it stood (painted, it is the same
## part), else whatever stood there; one put where nothing stood, in the step
## most of its step's parts went to. Given the steps of the copy it followed,
## the castle's second north-east tower, built elsewhere in the castle's
## steps, had all of its parts put in the first tower's steps when one part
## of that was painted (stepsiblings). Copies built in steps of their own
## share them, as a file writes the sub-model once: they take the steps of
## the one they follow.
func realize(from: String, to: String, at: Transform3D, mirrored: bool) -> Array:
	var own: bool = (AuthorSteps.in_parent(world, from) or AuthorSteps.in_parent(world, to)) \
		and AuthorSteps.any(world, scenery)
	var stood: Dictionary = _steps_where(content(to)) if own else {}
	# Each part of someone else's file on its own line in this copy: the
	# line of the part it follows, in the copy this one is (SourceFile).
	# Built again with none, a copy's parts were all new to a save, and the
	# copy came back as another sub-model of its own (keeptext4).
	var from_chain: String = str(world.unit_chains.get(from, ""))
	var to_chain: String = str(world.unit_chains.get(to, ""))
	var chained: bool = not from_chain.is_empty() and not to_chain.is_empty() \
		and not from_chain.contains("|") and not to_chain.contains("|")
	# And a part put back where the same part of this copy stood is that
	# part, on its line: a copy following one with no lines of its own (put
	# down new) lost every line it had.
	var lined: Dictionary = {}      ## place -> [[part, origin], ...] of to's
	for item: Dictionary in content(to):
		if not str(item.get("origin", "")).is_empty():
			var key: String = _place_key(str(item["rest"]), (item["at"] as Transform3D).origin)
			if not lined.has(key):
				lined[key] = []
			(lined[key] as Array).append([str(item["part"]), str(item["origin"])])
	var votes: Dictionary = {}      ## a step of from's -> {the step of to's it is: how many}
	var unplaced: Array = []        ## [an add with none where it goes, its step in from]
	var adds: Array = []
	for item: Dictionary in content(from):
		var placed: Dictionary = _mirrored(item) if mirrored else item
		var rest: String = str(item["rest"])
		var laid: Transform3D = Builder._tidy(at * (placed["at"] as Transform3D),
			BrickLattice.is_square_to_grid((at * (placed["at"] as Transform3D)).basis))
		var add: Dictionary = {"part": placed["part"], "color": item["color"], "at": laid,
			"path": to if rest.is_empty() else to + "/" + rest, "step": item["step"]}
		var origin: String = str(item.get("origin", ""))
		if chained and origin.begins_with(from_chain + "/"):
			add["origin"] = to_chain + origin.substr(from_chain.length())
		else:
			var stood_here: Array = lined.get(_place_key(rest, laid.origin), [])
			for n: int in stood_here.size():
				if str(stood_here[n][0]) == str(placed["part"]):
					add["origin"] = str(stood_here[n][1])
					stood_here.remove_at(n)
					break
		adds.append(add)
		if not own or int(item["step"]) < 0:
			continue
		var there: Array = stood.get(_place_key(rest, laid.origin), [])
		var found: int = -1
		for n: int in there.size():
			if str(there[n][0]) == str(placed["part"]):
				found = n
				break
		if found < 0 and not there.is_empty():
			found = 0
		if found < 0:
			unplaced.append([add, int(item["step"])])
			continue
		var step: int = int(there[found][1])
		there.remove_at(found)
		add["step"] = step
		var tally: Dictionary = votes.get(int(item["step"]), {})
		tally[step] = int(tally.get(step, 0)) + 1
		votes[int(item["step"])] = tally
	for one: Array in unplaced:
		(one[0] as Dictionary)["step"] = _voted(votes, int(one[1]))
	return builder.swap_bricks(ids_under(to), adds)


## [param items] (content's) by where each stands: [method _place_key] ->
## [[part, step], ...].
static func _steps_where(items: Array) -> Dictionary:
	var out: Dictionary = {}
	for item: Dictionary in items:
		var key: String = _place_key(str(item["rest"]), (item["at"] as Transform3D).origin)
		if not out.has(key):
			out[key] = []
		(out[key] as Array).append([str(item["part"]), int(item["step"])])
	return out


## Where a part stands in a copy, to half an LDU.
static func _place_key(rest: String, at: Vector3) -> String:
	return "%s|%d,%d,%d" % [rest, roundi(at.x * 2.0), roundi(at.y * 2.0), roundi(at.z * 2.0)]


## The step of the copy built again that most of the parts of [param step]
## of the one it follows went to ([param votes]), or of its nearest step
## that any went to; [param step] itself when none did.
static func _voted(votes: Dictionary, step: int) -> int:
	var nearest: int = -1
	for one: int in votes:
		if nearest < 0 or absi(one - step) < absi(nearest - step) \
				or absi(one - step) == absi(nearest - step) and one < nearest:
			nearest = one
	if nearest < 0:
		return step
	var tally: Dictionary = votes[nearest]
	var best: int = -1
	for to: int in tally:
		if best < 0 or int(tally[to]) > int(tally[best]) \
				or int(tally[to]) == int(tally[best]) and to < best:
			best = to
	return best


## A part reflected across the world's x = 0 plane, as Mirror reflects one:
## put where its reflection is, turned to look reflected, its other hand
## where it has one.
func _mirrored(item: Dictionary) -> Dictionary:
	var image: Dictionary = Later.script(&"Mirror").image(library, item["part"], item["at"], 0, 0.0)
	return {"part": image["part"], "color": item["color"], "at": image["at"]}


## How ``a`` lies on ``b``: the turn and shift, mirrored or not, that lays
## the most of a's parts on b's. {"at", "mirrored", "score", "exact"};
## exact when every part of each lies on one of the other, in its colour.
func best_match(a: Array, b: Array) -> Dictionary:
	var best: Dictionary = {"at": Transform3D.IDENTITY, "mirrored": false, "score": 0,
		"exact": false, "bases": false}
	for mirrored: bool in [false, true]:
		# Laid exactly as it is, each part turned as it is, a mirrored fit
		# could only tie, and a tie does not replace it.
		if mirrored and bool(best["exact"]) and bool(best["bases"]):
			break
		var from: Array = a.map(func(item: Dictionary) -> Dictionary:
			return _mirrored(item)) if mirrored else a
		var found: Dictionary = _rigid_match(from, b)
		# As many laid either way: the exact one, then the one laying each
		# part turned as it is (exact_match). A mirrored copy of parts that
		# look the same turned a half was taken for one turned, and a part
		# added to the first copy went into it turned, not in its other hand.
		var tie: bool = int(found["score"]) == int(best["score"])
		if int(found["score"]) > int(best["score"]) or tie and (
				(bool(found["exact"]) and not bool(best["exact"]))
				or (bool(found["exact"]) == bool(best["exact"])
					and bool(found["bases"]) and not bool(best["bases"]))):
			best = found
			best["mirrored"] = mirrored
	return best


func _rigid_match(a: Array, b: Array, exact_only: bool = false) -> Dictionary:
	var best: Dictionary = {"at": Transform3D.IDENTITY, "score": 0, "exact": false,
		"colours": false, "bases": false}
	if a.is_empty() or b.is_empty():
		return best
	# b by part, for the candidates and the look-ups.
	var by_part: Dictionary = {}
	for item: Dictionary in b:
		var part: String = item["part"]
		if not by_part.has(part):
			by_part[part] = []
		(by_part[part] as Array).append(item)
	# A few anchors of a, rarest in b first: each laid on each b of its part
	# (and turned a half on it, for a part that looks the same either way)
	# is a candidate.
	var anchors: Array = a.duplicate()
	anchors.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return (by_part.get(x["part"], []) as Array).size() \
			< (by_part.get(y["part"], []) as Array).size())
	var half := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var tried: int = 0
	# Every part laid in its colour, some only filling the cells their
	# match fills: only a way laying each turned as it is can do better,
	# and only that is looked for after it, given up at a part that does
	# not lie so (cheap: no part's cells are asked for).
	var laid: bool = false
	for anchor: Dictionary in anchors.slice(0, 3):
		var mates: Array = by_part.get(anchor["part"], [])
		for mate: Dictionary in mates:
			for spin: Transform3D in [Transform3D.IDENTITY, half]:
				var at: Transform3D = (mate["at"] as Transform3D) * spin \
					* (anchor["at"] as Transform3D).affine_inverse()
				at = Transform3D(at.basis.orthonormalized(), at.origin)
				var scored: Dictionary = _score(at, a, by_part, exact_only or laid, laid)
				tried += 1
				if laid:
					if int(scored["score"]) == a.size() and bool(scored["colours"]):
						best = scored
						best["at"] = at
						best["exact"] = a.size() == b.size()
						return best
					continue
				if int(scored["score"]) > int(best["score"]) or (
						int(scored["score"]) == int(best["score"])
						and ((bool(scored["colours"]) and not bool(best["colours"]))
							or (bool(scored["colours"]) == bool(best["colours"])
								and bool(scored["bases"]) and not bool(best["bases"])))):
					best = scored
					best["at"] = at
				# Every part laid, in its colour, each turned as it is: nothing
				# can lay more, and a tie never replaces it, so the rest of the
				# search would end with this one. It went on through every
				# anchor's every mate, 400 tries, for each of a model's copies.
				if int(best["score"]) == a.size() and bool(best["colours"]):
					best["exact"] = a.size() == b.size()
					if bool(best["bases"]):
						return best
					laid = true
			if tried > 400:
				break
	if laid:
		return best
	best["exact"] = int(best["score"]) == a.size() and a.size() == b.size() \
		and bool(best["colours"])
	return best


## How many of a's parts, laid by ``at``, land on a part of b: the same
## part, at the same place, filling the same cells. {"score", "colours":
## each in its colour, "bases": each turned as the one it lands on}; with
## [param turned_alike], a part lands only on one turned as it is.
func _score(at: Transform3D, a: Array, by_part: Dictionary,
		exact_only: bool = false, turned_alike: bool = false) -> Dictionary:
	var score: int = 0
	var colours: bool = true
	var bases: bool = true
	var used: Dictionary = {}
	for item: Dictionary in a:
		var to: Transform3D = at * (item["at"] as Transform3D)
		var hit: Dictionary = {}
		var alike: bool = false
		for other: Dictionary in by_part.get(item["part"], []):
			if used.has(other["id"]):
				continue
			if (other["at"] as Transform3D).origin.distance_to(to.origin) > 0.6:
				continue
			if (other["at"] as Transform3D).basis.is_equal_approx(to.basis):
				hit = other
				alike = true
				break
			# Filling the same cells turned otherwise: taken where none
			# there is turned as it is.
			if hit.is_empty() and not turned_alike \
					and _same_place(str(item["part"]), to, other["at"]):
				hit = other
		if hit.is_empty():
			# Asked only whether it lies exactly: it does not.
			if exact_only:
				return {"score": score, "colours": false, "bases": false}
			continue
		used[hit["id"]] = true
		score += 1
		bases = bases and alike
		if int(hit["color"]) != int(item["color"]):
			colours = false
	return {"score": score, "colours": colours, "bases": bases and score > 0}


## Which part of the copy at [param to] each part of the copy at [param
## from] is, brick id -> brick id, by how one lies on the other
## ([method best_match]). Empty unless they match exactly, part for part
## and colour for colour: what HiddenColours reads to keep copies alike.
func counterparts(from: String, to: String) -> Dictionary:
	var a: Array = content(from)
	var b: Array = content(to)
	var fit: Dictionary = best_match(a, b)
	if not bool(fit["exact"]):
		return {}
	var at: Transform3D = fit["at"]
	var by_part: Dictionary = {}
	for item: Dictionary in b:
		if not by_part.has(item["part"]):
			by_part[item["part"]] = []
		(by_part[item["part"]] as Array).append(item)
	var out: Dictionary = {}
	var used: Dictionary = {}
	for item: Dictionary in a:
		var laid: Dictionary = _mirrored(item) if bool(fit["mirrored"]) else item
		var there: Transform3D = at * (laid["at"] as Transform3D)
		for other: Dictionary in by_part.get(laid["part"], []):
			if used.has(other["id"]) \
					or (other["at"] as Transform3D).origin.distance_to(there.origin) > 0.6 \
					or not _same_place(str(laid["part"]), there, other["at"]):
				continue
			out[int(item["id"])] = int(other["id"])
			used[other["id"]] = true
			break
	return out if out.size() == a.size() else {}


func _same_place(part: String, here: Transform3D, there: Transform3D) -> bool:
	if here.basis.is_equal_approx(there.basis):
		return true
	var mesh: Lbm.PartMesh = library.mesh_for(part)
	if mesh == null:
		return false
	# A part that looks the same turned: the same cells filled.
	return builder.boxes_for(mesh, here) == builder.boxes_for(mesh, there)


# -- files --------------------------------------------------------------------


## Paths in the order a file lists them: outermost first, then by name,
## the first copy before the second.
static func in_file_order(found: Array) -> Array:
	var out: Array = found.duplicate()
	out.sort_custom(func(a: String, b: String) -> bool:
		var depth_a: int = a.count("/")
		var depth_b: int = b.count("/")
		if depth_a != depth_b:
			return depth_a < depth_b
		return a.naturalnocasecmp_to(b) < 0)
	return out


## Every assembly's frame and definition, for LdrModel.write_tree: the first
## copy of each definition is written as it stands (or, for a minifigure,
## in the frame [param figures] gives it), and each other copy is placed by
## how it lies on that one — mirrored, by a reflecting matrix. A copy that
## no longer lies exactly on the first is written as a definition of its
## own rather than lose what makes it different.
##
## Each copy's content read in one pass over the model, and each copy only
## asked whether it lies exactly on the first ([method exact_match]): saving
## 42043-1 (7,909 parts, sub-models five deep) took 718 s, nearly all of it
## here, scanning every part for each copy and scoring up to 400 ways one
## copy might lie on another that could not lie on it at all.
func file_frames(figures: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var masters: Dictionary = {}
	var taken: Dictionary = {}
	var ordered: Array = in_file_order(Array(paths()))
	var contents: Dictionary = contents_by_path()
	for path: String in ordered:
		taken[definition(leaf(path))] = true
	for path: String in ordered:
		var def: String = definition(leaf(path))
		if not masters.has(def):
			masters[def] = path
			out[path] = {"frame": _figure_frame(figures, path), "def": def}
			continue
		var master: String = masters[def]
		var fit: Dictionary = exact_match(contents.get(master, []), contents.get(path, []))
		if bool(fit["exact"]):
			var reflect: Transform3D = LdrModel.REFLECT_X if bool(fit["mirrored"]) \
				else Transform3D.IDENTITY
			out[path] = {"frame": (fit["at"] as Transform3D) * reflect
				* ((out[master] as Dictionary)["frame"] as Transform3D), "def": def}
			continue
		var own: String = "%s %d" % [def, copy_of(leaf(path))]
		while taken.has(own):
			own += "+"
		taken[own] = true
		masters[own] = path
		out[path] = {"frame": _figure_frame(figures, path), "def": own}
	return out


## The frame a minifigure stands in (ModelStore.figure_frames, by group),
## for a path that is one: "Guard 2#1" is the figure "Guard 2".
static func _figure_frame(figures: Dictionary, path: String) -> Transform3D:
	if figures.has(path):
		return figures[path]
	if not path.contains("/") and figures.has(definition(path)):
		return figures[definition(path)]
	return Transform3D.IDENTITY


## A part read from a mirrored reference, made one that can be built: its
## other hand where it has one, where its reflection is.
static func unmirror(placement: LdrModel.Placement, library: PartLibrary) -> void:
	var image: Dictionary = Later.script(&"Mirror").image(library, placement.part_id,
		placement.local, 0, 0.0)
	placement.part_id = image["part"]
	var at: Transform3D = placement.frame * (image["at"] as Transform3D)
	placement.transform = Builder._tidy(at, BrickLattice.is_square_to_grid(at.basis))
	placement.mirrored = false
