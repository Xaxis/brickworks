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


## Whether a brick's group is in the assembly at ``path`` (or is it).
static func within(group: String, path: String) -> bool:
	if path.is_empty():
		return true
	return group == path or group.begins_with(path + "/")


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
	for brick: BrickWorld.Brick in world.bricks():
		if not scenery.has(brick.id) and within(path_of(brick), path):
			out.append(brick)
	return out


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
	if not taken.has(base):
		return base
	var n: int = 2
	while taken.has("%s %d" % [base, n]):
		n += 1
	return "%s %d" % [base, n]


## The next copy of a definition, numbered across the whole model as an
## opened file numbers them: "Wing#1", then "Wing#2".
func next_copy(name: String) -> String:
	var highest: int = 0
	for path: String in paths():
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
		Builder._many(changes.size())])
	changed.emit()
	return path


## Take an assembly apart one level: what was in it is in its parent.
func ungroup(path: String) -> int:
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
	builder.regroup(changes, "took %s apart" % label(path))
	changed.emit()
	return changes.size()


## Call a definition something else, in every copy of it.
func rename(path: String, wanted: String) -> String:
	var old: String = definition(leaf(path))
	var name: String = wanted.strip_edges().replace("/", "-").replace("#", "")
	if name.is_empty() or name == old:
		return old
	name = unused_name(name)
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
	builder.regroup(changes, "renamed %s to %s" % [old, name])
	if not was_entered.is_empty():
		_set_entered(_renamed_path(was_entered, old, name))
	changed.emit()
	return name


static func _renamed_path(path: String, old: String, name: String) -> String:
	var parts: PackedStringArray = segments(path)
	for n: int in parts.size():
		if definition(parts[n]) == old:
			parts[n] = "%s#%d" % [name, copy_of(parts[n])]
	return "/".join(parts)


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
	builder.regroup(changes, "made %s a sub-assembly of its own" % label(path))
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
	builder.regroup(changes, "put %s in %s" % [label(path),
		"the model" if into.is_empty() else label(into)])
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
	if step.is_empty() or is_same(step, _seen):
		return 0
	_seen = step
	var followed: Array = copies_follow(builder.touched_groups(step))
	var steps: Array = followed[0]
	if not steps.is_empty():
		builder.extend_last(steps)
		changed.emit()
	return int(followed[1])


## Every other copy of the assemblies at [param touched] (paths, and
## what they are in) built again from the one that changed. Returns
## [history steps, copies rebuilt]; the caller keeps the steps with the
## change that caused them, so one undo takes back both. Claude's change
## to a selection gathers into a step of its own (Assistant.focus), which
## after_edit, looking once at the newest step, would not see again.
func copies_follow(touched: Dictionary) -> Array:
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
	var steps: Array = []
	var rebuilt: int = 0
	_syncing = true
	for path: String in order:
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
			rebuilt += 1
	_syncing = false
	return [steps, rebuilt]


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
	return out


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
## nothing. {"at", "mirrored", "exact"}.
func exact_match(a: Array, b: Array) -> Dictionary:
	var none: Dictionary = {"at": Transform3D.IDENTITY, "mirrored": false, "score": 0,
		"exact": false}
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
	if bool(found["exact"]):
		found["mirrored"] = false
		return found
	return _exact_mirrored(a, b)


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
			"id": brick.id, "step": brick.step})
	return out


## The copy at ``to`` built again from the one at ``from``: its parts taken
## off, and ``from``'s put down where ``at`` (and a mirror, when
## ``mirrored``) lays them. Returns the history steps, newest last.
func realize(from: String, to: String, at: Transform3D, mirrored: bool) -> Array:
	var adds: Array = []
	for item: Dictionary in content(from):
		var placed: Dictionary = _mirrored(item) if mirrored else item
		var rest: String = str(item["rest"])
		adds.append({"part": placed["part"], "color": item["color"],
			"at": Builder._tidy(at * (placed["at"] as Transform3D),
				BrickLattice.is_square_to_grid((at * (placed["at"] as Transform3D)).basis)),
			"path": to if rest.is_empty() else to + "/" + rest, "step": item["step"]})
	return builder.swap_bricks(ids_under(to), adds)


## A part reflected across the world's x = 0 plane, as Mirror reflects one:
## put where its reflection is, turned to look reflected, its other hand
## where it has one.
func _mirrored(item: Dictionary) -> Dictionary:
	var part: String = item["part"]
	var other: String = Mirror.counterpart(library, part)
	if not other.is_empty() and library.parts.has(other):
		part = other
	return {"part": part, "color": item["color"],
		"at": Mirror.reflected(item["at"], 0, 0.0)}


## How ``a`` lies on ``b``: the turn and shift, mirrored or not, that lays
## the most of a's parts on b's. {"at", "mirrored", "score", "exact"};
## exact when every part of each lies on one of the other, in its colour.
func best_match(a: Array, b: Array) -> Dictionary:
	var best: Dictionary = {"at": Transform3D.IDENTITY, "mirrored": false, "score": 0,
		"exact": false}
	for mirrored: bool in [false, true]:
		var from: Array = a.map(func(item: Dictionary) -> Dictionary:
			return _mirrored(item)) if mirrored else a
		var found: Dictionary = _rigid_match(from, b)
		if int(found["score"]) > int(best["score"]) or (int(found["score"]) == int(best["score"])
				and bool(found["exact"]) and not bool(best["exact"])):
			best = found
			best["mirrored"] = mirrored
	return best


func _rigid_match(a: Array, b: Array, exact_only: bool = false) -> Dictionary:
	var best: Dictionary = {"at": Transform3D.IDENTITY, "score": 0, "exact": false,
		"colours": false}
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
	for anchor: Dictionary in anchors.slice(0, 3):
		var mates: Array = by_part.get(anchor["part"], [])
		for mate: Dictionary in mates:
			for spin: Transform3D in [Transform3D.IDENTITY, half]:
				var at: Transform3D = (mate["at"] as Transform3D) * spin \
					* (anchor["at"] as Transform3D).affine_inverse()
				at = Transform3D(at.basis.orthonormalized(), at.origin)
				var scored: Dictionary = _score(at, a, by_part, exact_only)
				tried += 1
				if int(scored["score"]) > int(best["score"]) or (
						int(scored["score"]) == int(best["score"])
						and bool(scored["colours"]) and not bool(best["colours"])):
					best = scored
					best["at"] = at
				if int(best["score"]) == a.size() and bool(best["colours"]):
					break
			if tried > 400:
				break
	best["exact"] = int(best["score"]) == a.size() and a.size() == b.size() \
		and bool(best["colours"])
	return best


## How many of a's parts, laid by ``at``, land on a part of b: the same
## part, at the same place, filling the same cells.
func _score(at: Transform3D, a: Array, by_part: Dictionary,
		exact_only: bool = false) -> Dictionary:
	var score: int = 0
	var colours: bool = true
	var used: Dictionary = {}
	for item: Dictionary in a:
		var to: Transform3D = at * (item["at"] as Transform3D)
		var hit: Dictionary = {}
		for other: Dictionary in by_part.get(item["part"], []):
			if used.has(other["id"]):
				continue
			if (other["at"] as Transform3D).origin.distance_to(to.origin) > 0.6:
				continue
			if not _same_place(str(item["part"]), to, other["at"]):
				continue
			hit = other
			break
		if hit.is_empty():
			# Asked only whether it lies exactly: it does not.
			if exact_only:
				return {"score": score, "colours": false}
			continue
		used[hit["id"]] = true
		score += 1
		if int(hit["color"]) != int(item["color"]):
			colours = false
	return {"score": score, "colours": colours}


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
	var other: String = Mirror.counterpart(library, placement.part_id)
	if not other.is_empty() and library.parts.has(other):
		placement.part_id = other
	var at: Transform3D = placement.frame * Mirror.reflected(placement.local, 0, 0.0)
	placement.transform = Builder._tidy(at, BrickLattice.is_square_to_grid(at.basis))
	placement.mirrored = false
