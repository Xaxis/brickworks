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
## edit to one copy the others take the same change, part by part
## (after_edit) — change one wing and the other follows, mirrored.
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
func next_copy(name: String) -> String:
	var highest: int = 0
	for path: String in paths() + PackedStringArray(world.unit_steps.keys()):
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
	# Read while the copy is still one: its frame is found from its parts.
	var lit: Dictionary = _lines_apart(path)
	var carry: Callable = func(at: String) -> Array:
		if at == path:
			return []
		return [join(parent, at.substr(path.length() + 1))] if within(at, path) else [at]
	if builder.regroup(changes, "took %s apart" % label(path), carry, numbers) > 0:
		if not looks.is_empty():
			builder.extend_last([{"undo": "steplooks", "looks": world.step_looks}])
			world.step_looks = looks
		if not lit.is_empty():
			set_lines(builder, lit["lines"])
			if not (lit["lights"] as Array).is_empty():
				builder.extend_last([{"undo": "scenelights", "take": lit["lights"], "put": []}])
				world.scene_lights = world.scene_lights + (lit["lights"] as Array)
			apart_said = lit["said"]
	changed.emit()
	return changes.size()


## What taking the copy at [param path] apart does to the lines kept by
## definition (BrickWorld.section_lines), read before its parts move. Each of
## its definition's lights goes with its parts, placed through the copy's
## frame as a save writes the copy (file_frames): into the lines of the one
## it is in, or the model's own lights (BrickWorld.scene_lights) when that is
## the model, as many as a model keeps (SceneLights.joins). Its last copy
## takes its definition's lines with it: its views too, as a view of a
## sub-model that is gone frames nothing. Returns {"lines": the table after,
## "lights": those the model gains, in the window's coordinates, "said": the
## words for it}, or {} when it has none. Up to 2026-11-11 the lines stayed
## under its name, and a save wrote them in whatever next took the name
## (lpcheck s6, s12); before that, taken apart, its lights went unsaid.
func _lines_apart(path: String) -> Dictionary:
	var def: String = definition(leaf(path))
	if not world.section_lines.has(def):
		return {}
	var parent: String = parent_of(path)
	var parent_def: String = definition(leaf(parent))
	# A copy in hand stands, as it does for lines_follow: put down, it is
	# still one.
	var last: bool = copies_of(path).is_empty() and not _in_hand(builder).has(def)
	var frames: Dictionary = file_frames()
	# The file's coordinates of its definition, as written, to the window's
	# (the copy's frame, file_frames'), and on to its parent's.
	var flip := Transform3D(Basis.from_scale(LdrModel.FLIP), Vector3.ZERO)
	var through: Transform3D = ((frames[path] as Dictionary)["frame"] as Transform3D) * flip
	if not parent.is_empty():
		through = flip * ((frames[parent] as Dictionary)["frame"] as Transform3D) \
			.affine_inverse() * through
	var lines: Dictionary = world.section_lines.duplicate()
	var theirs := PackedStringArray(lines.get(parent_def, PackedStringArray()))
	var gained: Array = []
	var moved: int = 0
	var lost: int = 0
	var why: String = ""
	var views: int = 0
	for line: String in world.section_lines[def]:
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
	if moved > 0:
		said.append("its light went with its parts" if moved == 1
			else "its %d lights went with its parts" % moved)
	if lost > 0:
		said.append("%d of its lights went with it" % lost)
		said.append(why)
	if last and views > 0:
		said.append("its saved view went with it" if views == 1
			else "its %d saved views went with it" % views)
	return {"lines": lines, "lights": gained, "said": " — ".join(said)}


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
	# Every copy renamed alike: none changed against another, so none is
	# built again from another. Built again, the blue Tower#2 came back red,
	# its parts new ones made from Tower#1's, and the save wrote it as a
	# sub-model of its own (copyfaults).
	no_copies_follow()
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
	set_lines(builder, now)


## The world's lines by definition (BrickWorld.section_lines) made [param
## lines], in the newest step of the history (Builder.extend_last). Its undo
## is the table as that step found it, kept once however many of the step's
## changes make them: a step's undos are applied in their order, so with two
## kept the later won, and the Undo of a Sections accept that kept one for
## each of two names left the first one's lights and views out (lpcheck s6).
## A step folded of others (Builder.fold_since) holds theirs newest first,
## and its oldest, put back last, is the table as the first found it.
static func set_lines(builder: Builder, lines: Dictionary) -> void:
	var world: BrickWorld = builder.world
	if lines == world.section_lines:
		return
	if not _keeps_lines(builder.last_step()):
		builder.extend_last([{"undo": "sectionlines", "lines": world.section_lines}])
	world.section_lines = lines


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
static func lines_follow(builder: Builder, step: Dictionary, held: Array = []) -> void:
	var world: BrickWorld = builder.world
	if world.section_lines.is_empty() or step.is_empty():
		return
	var left: Dictionary = {}
	_left_from(step, left)
	var asked: Array = left.keys().filter(func(def: String) -> bool:
		return world.section_lines.has(def))
	if asked.is_empty():
		return
	var standing: Dictionary = _in_hand(builder)
	for brick: BrickWorld.Brick in world.bricks():
		for segment: String in segments(path_of(brick)):
			standing[definition(segment)] = true
	for item: Variant in held:
		var placement: LdrModel.Placement = item
		for segment: String in segments(path_from(placement.group, placement.unit)):
			standing[definition(segment)] = true
	var lines: Dictionary = world.section_lines.duplicate()
	for def: String in asked:
		if not standing.has(def):
			lines.erase(def)
	set_lines(builder, lines)


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
## parts, Redo puts them back.
static func lines_pasted(builder: Builder, carried: Dictionary, pasted: Array,
		had: Dictionary) -> String:
	var lines: Dictionary = builder.world.section_lines.duplicate()
	var seen: Dictionary = {}
	var kept := PackedStringArray()
	for pair: Array in pasted:
		var from: PackedStringArray = segments(str(pair[0]))
		var to: PackedStringArray = segments(str(pair[1]))
		for n: int in mini(from.size(), to.size()):
			var was: String = definition(from[from.size() - 1 - n])
			var now: String = definition(to[to.size() - 1 - n])
			if seen.has(now) or not carried.has(was):
				continue
			seen[now] = true
			if not had.has(now):
				lines[now] = PackedStringArray(carried[was])
			elif PackedStringArray(lines.get(now, PackedStringArray())) \
					!= PackedStringArray(carried[was]):
				kept.append("%s here keeps its own lights and views, not the copied ones" % now)
	set_lines(builder, lines)
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


## The lines each definition [param instances] (file_frames) writes keeps of
## its own, for LdrModel.write_tree: those of the sub-model its copies are
## of, a copy written as one of its own ("Wing 2") among them.
static func lines_written(world: BrickWorld, instances: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if world.section_lines.is_empty():
		return out
	for path: String in instances:
		var lines: Variant = world.section_lines.get(definition(leaf(path)))
		if lines != null:
			out[str((instances[path] as Dictionary)["def"])] = PackedStringArray(lines)
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
	# Being edited inside, it is still: the path it is edited by is the new
	# one, as make_unique's is (an old path names nothing now).
	if within(entered, path):
		_set_entered(fresh + entered.substr(path.length()))
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
## copies, and those copies given the same change (copies_follow), as part
## of the same undo step. A copy moved, turned or mirrored whole still lies
## on the others exactly, and is left as it is.
func after_edit() -> int:
	if _syncing:
		return 0
	var step: Dictionary = builder.last_step()
	# An undo or a redo changed the model by a step whose copies already
	# followed it, inside it (Builder.settled): nothing to follow. Asked
	# again, the undo of a move of everything matched every copy of every
	# sub-model against the others once more, and the step left newest by
	# an undo had its copies built again into it, long after it was made.
	if step.is_empty() or is_same(step, _seen) or is_same(step, builder.settled):
		return 0
	_seen = step
	var followed: Array = copies_follow(step)
	var steps: Array = followed[0]
	if not steps.is_empty():
		builder.extend_last(steps)
		# The step as it is kept now: a step of one entry is made a group to
		# take them, a step after_edit had not seen, and asked again it
		# followed the edit a second time (a part put down in one post put
		# two down in the other, copyfaults2).
		_seen = builder.last_step()
		changed.emit()
	return int(followed[1])


## The newest step changed where parts are in the tree and not one part's
## shape or place (Sections.accept): no copy follows it. Copies a
## file holds that were never alike (31037's, 10179's) were rebuilt from
## one of them when sections were made round them, 1,115 parts of 10179-1
## swapped for others (2026-10-17).
func no_copies_follow() -> void:
	_seen = builder.last_step()


## Every other copy of what [param step] (a history step) changed takes the
## same change, part by part, as every reference to a file's sub-model shows
## a change to it. Returns [history steps, copies that followed]; the caller
## keeps the steps with the change that caused them, newest first, so one
## undo takes back both. Claude's change to a selection gathers into a step
## of its own (Assistant.focus), which after_edit, looking once at the newest
## step, would not see again.
##
## Each copy is laid on the other as both stood before the step, by shape
## ([method best_match]: a sub-model placed in red and in blue differs only
## in the colour it hands its parts of colour 16), and each part of the one
## changed is paired with the part of the other it lay on. That part takes
## the change: a move or a turn moves it; a paint paints it where the two
## were one colour, the part's own, and else it keeps its copy's placing
## colour; a part taken off goes from it; a part put down is put down in it,
## in its placing colour where it went down in this copy's, else in its own;
## a step changed is its step too where the copies share their definition's
## steps (neither is built in the steps of the one round it). Nothing else of
## it changes: its other parts keep their numbers, order, colours, steps and
## lines. Built again whole from the copy changed, a blue post came back red,
## every part a new number, for one part of the red moved a stud or put in
## the next step, and an undo of a paint in a car's wheel left the second
## car with both its old wheels and the new (cfcheck).
##
## A copy the step changed whole (every part moved alike, or moved, turned
## and mirrored so that it lies on itself as it was) is the shape it was, and
## nothing follows it: moving everything matched every copy of every
## sub-model against the others, and on a 4,139-part set that was most of a
## second. Nor does one the step put down whole, a duplicate or a paste:
## Tower#1 duplicated, the blue Tower#2 was built again from the red copy put
## down (copyfaults). A copy the step took parts off and put parts down in is
## not new: a session's edit_model laying Post#1 again where it stood left
## Post#2 as it was, and the save wrote two posts (cfcheck).
func copies_follow(step: Dictionary) -> Array:
	var paths_touched: Dictionary = {}
	for group: String in builder.touched_groups(step):
		var path: String = ""
		for segment: String in segments(group):
			path = join(path, segment)
			paths_touched[path] = true
	# Innermost first: a wheel's copies take a change to the wheel, and the
	# car's copies then find those parts given it already.
	var order: Array = paths_touched.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		return segments(a).size() > segments(b).size())
	# No copy of any of them, nothing to follow: asked of the model's paths
	# alone first. A replace of Orthanc touched ten sub-models, none with a
	# copy, and each was read out whole for nothing.
	if not _any_copied(order):
		return [[], 0]
	var then: Dictionary = _before(step)
	var moved: Dictionary = _moved_by(step)
	var units: Dictionary = _units_named(step)
	_from_ensured(step, then, units)
	# Every pair laid first, on the copies as they stood before the step;
	# then every change made. Laid as each changed, a car's copy, its wheels
	# given the change already, no longer lay on the car as it was.
	var plans: Array = []
	_syncing = true
	_begin_pass()
	for path: String in order:
		if not moved.is_empty() and _moved_alike(path, moved):
			continue
		var made: Dictionary = _made_in(path, then, units)
		if made.is_empty():
			continue
		var was: Array = made["then"]
		for other: String in copies_of(path):
			var twin: Array = _content_then(other, then)
			if twin.size() != was.size():
				continue
			var fit: Dictionary = best_match(was, twin)
			if int(fit["score"]) != was.size():
				continue
			var pairs: Dictionary = _laid_on(was, twin, fit)
			if pairs.size() == was.size():
				plans.append([path, other, fit, pairs, made, twin])
	_end_pass()
	var back: Array = []
	var claimed: Dictionary = {}
	var followed: Dictionary = {}
	_fresh_names.clear()
	for plan: Array in plans:
		var took: Array = _follow(plan, then, units, claimed)
		if not took.is_empty():
			back = took + back
			followed[plan[1]] = true
	# The model changed: read again at the next question.
	_indexed = false
	_syncing = false
	return [back, followed.size()]


## What [param undo], AuthorSteps.ensure's for a step edit, gave: the steps
## the model has from it, {"bricks": brick -> its step, "units": copy ->
## its step, or -1 for none}, {} for nothing. Kept with the edit's step as
## "ensured" ([method _from_ensured]).
static func ensured(world: BrickWorld, undo: Array) -> Dictionary:
	if undo.is_empty():
		return {}
	var bricks: Dictionary = {}
	var units: Dictionary = {}
	for entry: Dictionary in undo:
		match str(entry.get("undo", "")):
			"restep":
				var brick: BrickWorld.Brick = world.get_brick(int(entry["brick"]))
				if brick != null:
					bricks[brick.id] = brick.step
			"unitstep":
				units[str(entry["unit"])] = int(world.unit_steps.get(str(entry["unit"]), -1))
	return {"bricks": bricks, "units": units}


## A step edit on a model with no steps of its own gives every part and copy
## the worked-out ones first, in its step (AuthorSteps.ensure, the step's
## "ensured"): the edit starts from those, which are no change it made to
## the other copies. Read as its own, every twin kept the number ensure gave
## it, and a part of one wheel put in a step of its own, or the car's 3001,
## stayed so in that copy alone; saved, every wheel had it (cffix). So
## [param then] ([method _before]) reads each part ensure stepped in that
## step, and [param units] ([method _units_named]) leaves out each copy
## whose step is still ensure's.
func _from_ensured(step: Dictionary, then: Dictionary, units: Dictionary) -> void:
	var ensured: Dictionary = step.get("ensured", {})
	if ensured.is_empty():
		return
	var bricks: Dictionary = ensured["bricks"]
	for brick_id: int in bricks:
		var was: Variant = then.get(brick_id)
		if was is Dictionary:
			(was as Dictionary)["step"] = int(bricks[brick_id])
	var given: Dictionary = ensured["units"]
	for unit: String in given:
		if units.has(unit) and int(world.unit_steps.get(unit, -1)) == int(given[unit]):
			units.erase(unit)


## Each brick [param step] names as it was before it, by its number now, or
## for one it took off the number it had (below 0 where another holds that):
## {"part", "color", "at", "group", "unit", "step", "origin"}, or null for one
## it put down. Read backwards, as an undo carries it out, newest first.
func _before(step: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	_undone_into(step, out, [-1])
	return out


func _undone_into(step: Dictionary, out: Dictionary, unnumbered: Array) -> void:
	var kind: String = str(step.get("undo", ""))
	if kind == "group":
		for inner: Variant in step.get("steps", []):
			if inner is Dictionary:
				_undone_into(inner, out, unnumbered)
		return
	if kind == "add":
		var number: int = int(step.get("was", 0))
		if number <= 0 or out.get(number) != null:
			number = int(unnumbered[0])
			unnumbered[0] = number - 1
		out[number] = {"part": str(step.get("part", "")), "color": int(step.get("color", 0)),
			"at": step.get("transform", Transform3D.IDENTITY), "group": str(step.get("group", "")),
			"unit": str(step.get("unit", "")), "step": int(step.get("step", -1)),
			"origin": world.gone_origin(number) if number > 0 else ""}
		return
	if not step.has("brick") or not kind in ["move", "recolor", "restep", "regroup", "remove"]:
		return
	var brick_id: int = builder._live(int(step["brick"]))
	if not out.has(brick_id):
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		out[brick_id] = null if brick == null else {"part": brick.part_id,
			"color": brick.color_code, "at": brick.transform, "group": brick.group,
			"unit": brick.unit, "step": brick.step, "origin": brick.origin}
	var was: Variant = out[brick_id]
	if was == null:
		return
	match kind:
		"move":
			(was as Dictionary)["at"] = step["transform"]
		"recolor":
			(was as Dictionary)["color"] = int(step["color"])
		"restep":
			(was as Dictionary)["step"] = int(step["step"])
		"regroup":
			(was as Dictionary)["group"] = str(step["group"])
			if step.has("unit"):
				(was as Dictionary)["unit"] = str(step["unit"])
		"remove":
			out[brick_id] = null


## The copies [param step] gives a step of their own ("unitstep"), path ->
## true.
static func _units_named(step: Dictionary, out: Dictionary = {}) -> Dictionary:
	if step.get("undo", "") == "group":
		for inner: Variant in step.get("steps", []):
			if inner is Dictionary:
				_units_named(inner, out)
	elif step.get("undo", "") == "unitstep":
		out[str(step["unit"])] = true
	return out


## The parts of the copy at [param path] as they stood before the step
## [param then] reads ([method _before]), as [method content] lists them:
## those it does not name as they are, and those it does as they were, those
## it took off among them.
func _content_then(path: String, then: Dictionary) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in bricks_under(path):
		if not then.has(brick.id):
			out.append({"part": brick.part_id, "color": brick.color_code, "at": brick.transform,
				"rest": path_of(brick).substr(path.length()).trim_prefix("/"), "id": brick.id,
				"step": brick.step, "origin": brick.origin})
	for brick_id: int in then:
		var was: Variant = then[brick_id]
		if was == null:
			continue
		var at: String = path_from(str(was["group"]), str(was["unit"]))
		if at.is_empty() or not within(at, path):
			continue
		out.append({"part": was["part"], "color": was["color"], "at": was["at"],
			"rest": at.substr(path.length()).trim_prefix("/"), "id": brick_id,
			"step": was["step"], "origin": was["origin"]})
	return out


## What the step [param then] reads ([method _before]) made of the copy at
## [param path]: its parts before ("then", as [method content] lists them)
## and each change to them, "moved", "painted", "stepped" and "regrouped"
## ([before, now] each), "gone" (before), "fresh" (now) and "swapped"
## ([before, now]: one put down where one taken off stood). {} when it
## changed nothing of it, nor the step of any copy inside it ([param units],
## [method _units_named]: those [method _follow] gives the others); when it
## is new, nothing of it there before; when nothing of it is left; and when
## it changed it whole, no part standing where it stood and the copy lying
## on itself as it was.
func _made_in(path: String, then: Dictionary, units: Dictionary = {}) -> Dictionary:
	var now: Array = content(path)
	var was: Array = _content_then(path, then)
	if now.is_empty() or was.is_empty():
		return {}
	var now_of: Dictionary = {}
	for item: Dictionary in now:
		now_of[int(item["id"])] = item
	var made: Dictionary = {"then": was, "moved": [], "painted": [], "stepped": [],
		"regrouped": [], "gone": [], "fresh": [], "swapped": []}
	var standing: int = 0         ## parts before that stand where they stood
	var was_of: Dictionary = {}
	for item: Dictionary in was:
		var brick_id: int = int(item["id"])
		was_of[brick_id] = true
		var here: Variant = now_of.get(brick_id)
		if here == null:
			(made["gone"] as Array).append(item)
			continue
		if not then.has(brick_id):
			standing += 1
			continue
		var pair: Array = [item, here]
		if _alike(item["at"], (here as Dictionary)["at"]):
			standing += 1
		else:
			(made["moved"] as Array).append(pair)
		if int(item["color"]) != int(here["color"]):
			(made["painted"] as Array).append(pair)
		if int(item["step"]) != int(here["step"]):
			(made["stepped"] as Array).append(pair)
		if str(item["rest"]) != str(here["rest"]):
			(made["regrouped"] as Array).append(pair)
	for item: Dictionary in now:
		if not was_of.has(int(item["id"])):
			(made["fresh"] as Array).append(item)
	_swaps_in(made)
	var changed: bool = false
	for kind: String in ["moved", "painted", "stepped", "regrouped", "gone", "fresh", "swapped"]:
		changed = changed or not (made[kind] as Array).is_empty()
	if not changed:
		# A copy inside it put in another step, and nothing else: the wheel
		# the car puts on in its own step, which every car does.
		for unit: String in units:
			if unit != path and within(unit, path):
				return made
		return {}
	if standing == 0 and was.size() == now.size() \
			and int(best_match(was, now)["score"]) == was.size():
		return {}
	return made


## Each part [param made] put down that stands where one it took off stood
## (its middle in the other's box, or the other's in its, in the same copy
## inside), out of "fresh" and "gone" into "swapped" as [before, now]: a part
## replaced, or the same put down again. The nearest first.
func _swaps_in(made: Dictionary) -> void:
	var gone: Array = made["gone"]
	var fresh: Array = made["fresh"]
	if gone.is_empty() or fresh.is_empty():
		return
	var boxes: Array = gone.map(func(item: Dictionary) -> AABB:
		return Later.script(&"SelectionScope").box_of(str(item["part"]), item["at"], library))
	for item: Dictionary in fresh.duplicate():
		var box: AABB = Later.script(&"SelectionScope").box_of(str(item["part"]), item["at"], library)
		var middle: Vector3 = box.get_center()
		var best: int = -1
		for n: int in gone.size():
			var there: AABB = boxes[n]
			if str(gone[n]["rest"]) != str(item["rest"]) or not (there.grow(0.5).has_point(middle)
					or box.grow(0.5).has_point(there.get_center())):
				continue
			if best < 0 or (boxes[best] as AABB).get_center().distance_to(middle) \
					> there.get_center().distance_to(middle):
				best = n
		if best < 0:
			continue
		(made["swapped"] as Array).append([gone[best], item])
		gone.remove_at(best)
		boxes.remove_at(best)
		fresh.erase(item)


## The copy [param plan] names ([path, other, fit, pairs, made, its parts
## before]) given what the step made of the one at path ([method _made_in]),
## part by part. Returns the history steps that take it back, newest first.
## [param claimed]: what each brick has been given by this follow already,
## brick id -> {"at", "color", "step", "path" or "gone": true}, which another
## copy of a copy round it does not give it again; nor what the step itself
## changed of it ([param then]); and "laid" for each part this follow put
## down, which no later plan puts down again ([method _put_already]).
func _follow(plan: Array, then: Dictionary, units: Dictionary, claimed: Dictionary) -> Array:
	var path: String = plan[0]
	var other: String = plan[1]
	var fit: Dictionary = plan[2]
	var pairs: Dictionary = plan[3]
	var made: Dictionary = plan[4]
	var twin: Dictionary = {}       ## its brick -> as it stood before the step
	for item: Dictionary in plan[5]:
		twin[int(item["id"])] = item
	# Copies built in steps of their own share them, as a file writes the
	# sub-model once; one built in the steps of the one round it has its own.
	var shared: bool = not AuthorSteps.in_parent(world, path) \
		and not AuthorSteps.in_parent(world, other)
	var inner: Dictionary = _inner_names(made["then"], pairs, twin)
	var matched: Dictionary = {}    ## parts put down already that this plan has
	var back: Array = []
	for pair: Array in made["moved"]:
		var brick_id: int = int(pairs[int(pair[0]["id"])])
		if _free(brick_id, "at", twin, other, then, claimed):
			var laid: Array = _laid(fit, str(pair[1]["part"]), pair[1]["at"])
			back.push_front(builder._apply({"undo": "move", "brick": brick_id,
				"transform": laid[1]}))
	for pair: Array in made["painted"] + made["swapped"].filter(func(one: Array) -> bool:
			return _put_back(one)):
		var brick_id: int = int(pairs[int(pair[0]["id"])])
		# Its own colour where both copies had it; else the copy's placing
		# colour, which this copy keeps its own of.
		if int(pair[0]["color"]) != int(pair[1]["color"]) \
				and int(twin[brick_id]["color"]) == int(pair[0]["color"]) \
				and _free(brick_id, "color", twin, other, then, claimed):
			back.push_front(builder._apply({"undo": "recolor", "brick": brick_id,
				"color": int(pair[1]["color"])}))
	if shared:
		for pair: Array in made["stepped"] + made["swapped"].filter(func(one: Array) -> bool:
				return _put_back(one)):
			var brick_id: int = int(pairs[int(pair[0]["id"])])
			if int(pair[0]["step"]) != int(pair[1]["step"]) \
					and _free(brick_id, "step", twin, other, then, claimed):
				back.push_front(builder._apply({"undo": "restep", "brick": brick_id,
					"step": int(pair[1]["step"])}))
	for pair: Array in made["regrouped"]:
		var brick_id: int = int(pairs[int(pair[0]["id"])])
		var to: String = _named_in(other, str(pair[1]["rest"]), inner)
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null and path_of(brick) != to \
				and _free(brick_id, "path", twin, other, then, claimed):
			back.push_front(builder._apply({"undo": "regroup", "brick": brick_id,
				"group": group_of(to), "unit": to}))
	var off := PackedInt64Array()
	var on: Array = []
	for pair: Array in made["swapped"]:
		var brick_id: int = int(pairs[int(pair[0]["id"])])
		if _put_back(pair) or not _free(brick_id, "gone", twin, other, then, claimed):
			continue
		var was: Dictionary = twin[brick_id]
		var laid: Array = _laid(fit, str(pair[1]["part"]), pair[1]["at"])
		if _put_already(other, laid, then, claimed, matched):
			continue
		off.append(brick_id)
		# In the colour it is given where both copies had the one it replaces
		# in one colour; else in this copy's colour for it. On the line of the
		# one it replaces where the edited copy's is (a Replace, _swap), else
		# on a line of its own.
		on.append({"part": laid[0], "at": laid[1],
			"color": int(pair[1]["color"]) if int(was["color"]) == int(pair[0]["color"])
				else int(was["color"]),
			"path": _named_in(other, str(pair[1]["rest"]), inner),
			"step": int(pair[1]["step"]) if shared else int(was["step"]),
			"origin": "" if str(pair[1].get("origin", "")).is_empty()
				else str(was.get("origin", ""))})
	for item: Dictionary in made["gone"]:
		var brick_id: int = int(pairs[int(item["id"])])
		if _free(brick_id, "gone", twin, other, then, claimed):
			off.append(brick_id)
	var placing: Array = _placing(made["then"], pairs, twin)
	var votes: Dictionary = {} if shared else _step_votes(made["then"], pairs, twin)
	for item: Dictionary in made["fresh"]:
		var laid: Array = _laid(fit, str(item["part"]), item["at"])
		if _put_already(other, laid, then, claimed, matched):
			continue
		var colour: int = int(item["color"])
		if not placing.is_empty() and colour == int(placing[0]):
			colour = int(placing[1])
		on.append({"part": laid[0], "at": laid[1], "color": colour,
			"path": _named_in(other, str(item["rest"]), inner),
			"step": int(item["step"]) if shared or int(item["step"]) < 0
				else _voted(votes, int(item["step"])), "origin": ""})
	if not off.is_empty() or not on.is_empty():
		var swapped: Array = builder.swap_bricks(off, on)
		for step: Dictionary in swapped:
			if step["undo"] == "remove":
				claimed[int(step["brick"])] = {"laid": true}
		back = swapped + back
	if shared:
		for unit: String in units:
			if unit == path or not within(unit, path):
				continue
			var to: String = _named_in(other, unit.substr(path.length() + 1), inner)
			var kept: bool = world.unit_steps.has(unit)
			var wanted: int = int(world.unit_steps.get(unit, -1))
			if units.has(to) or (world.unit_steps.has(to) == kept
					and int(world.unit_steps.get(to, -1)) == wanted):
				continue
			back.push_front(builder._apply({"undo": "unitstep", "unit": to, "step": wanted,
				"kept": kept}))
	return back


## Whether the part [param laid] ([its part, its place], [method _laid]) is
## down in the copy at [param other] already, put down in this pass: by the
## step [param then] reads (a step folded with what followed it, asked
## again), or by the follow of another copy of a definition it is in, at any
## depth ([param claimed] "laid"). Then this plan has it ([param matched]),
## once. Each edit goes once into each copy of each definition: a 3024 put
## down in Car#1/Wheel#1 went into Car#2/Wheel#3 with the wheel's copies and
## again with the car's, and three deep once more with each copy round it
## (cf2check).
func _put_already(other: String, laid: Array, then: Dictionary, claimed: Dictionary,
		matched: Dictionary) -> bool:
	var at: Transform3D = laid[1]
	for brick: BrickWorld.Brick in bricks_under(other):
		var put: bool = (then.has(brick.id) and then[brick.id] == null) \
			or (claimed.get(brick.id, {}) as Dictionary).has("laid")
		if not put or matched.has(brick.id) or brick.part_id != str(laid[0]) \
				or brick.transform.origin.distance_to(at.origin) > 0.6 \
				or not _same_place(brick.part_id, brick.transform, at):
			continue
		matched[brick.id] = true
		return true
	return false


## Whether [param pair] ([before, now], swapped) is the same part put down
## again where it stood: a paint or a step at most, not a part replaced.
func _put_back(pair: Array) -> bool:
	return str(pair[0]["part"]) == str(pair[1]["part"]) \
		and (pair[0]["at"] as Transform3D).origin.distance_to((pair[1]["at"] as Transform3D).origin) \
			< 0.6 and _same_place(str(pair[0]["part"]), pair[0]["at"], pair[1]["at"])


## Whether the brick [param brick_id] of the copy at [param other] (a part of
## [param twin], as it stood before the step) may be given [param what] by
## this follow: it is still there, the step did not change that of it itself,
## and no copy has given it that already. Taken, it is [param claimed].
func _free(brick_id: int, what: String, twin: Dictionary, other: String, then: Dictionary,
		claimed: Dictionary) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	var given: Dictionary = claimed.get(brick_id, {})
	if brick == null or given.has("gone") or given.has(what):
		return false
	if then.has(brick_id):
		var was: Dictionary = twin[brick_id]
		var same: bool = true
		match what:
			"at":
				same = _alike(was["at"], brick.transform)
			"color":
				same = int(was["color"]) == brick.color_code
			"step":
				same = int(was["step"]) == brick.step
			"path", "gone":
				same = path_of(brick) == _named_in(other, str(was["rest"]), {})
		if not same:
			return false
	given[what] = true
	claimed[brick_id] = given
	return true


## Where [param at] (a part's place in the copy that changed) lays a part
## [param part] in the other copy by [param fit] ([method best_match]),
## mirrored where the fit is: [its part, its place].
func _laid(fit: Dictionary, part: String, at: Transform3D) -> Array:
	var placed: Dictionary = _mirrored({"part": part, "color": 0, "at": at}) \
		if bool(fit["mirrored"]) else {"part": part, "at": at}
	var laid: Transform3D = (fit["at"] as Transform3D) * (placed["at"] as Transform3D)
	return [str(placed["part"]), Builder._tidy(laid, BrickLattice.is_square_to_grid(laid.basis))]


## Each copy inside the one that changed, by its place there (its parts'
## "rest"), named as the copy it lies on inside the other ([param pairs],
## [param twin]): rest -> rest.
func _inner_names(was: Array, pairs: Dictionary, twin: Dictionary) -> Dictionary:
	var out: Dictionary = {"": ""}
	for item: Dictionary in was:
		var mate: Dictionary = twin[int(pairs[int(item["id"])])]
		var from: PackedStringArray = segments(str(item["rest"]))
		var to: PackedStringArray = segments(str(mate["rest"]))
		if from.size() != to.size():
			continue
		for n: int in from.size():
			out["/".join(from.slice(0, n + 1))] = "/".join(to.slice(0, n + 1))
	return out


## The path in the copy at [param other] of the place [param rest] has in
## the copy that changed, by [param inner] ([method _inner_names]); a copy
## inside it the step made is a new copy inside the other, numbered after
## every copy of its definition, and kept in [param inner] for the next.
func _named_in(other: String, rest: String, inner: Dictionary) -> String:
	if rest.is_empty():
		return other
	var mapped: String = ""
	var key: String = ""
	for segment: String in segments(rest):
		key = join(key, segment)
		if inner.has(key):
			mapped = str(inner[key])
			continue
		if inner.is_empty():
			return join(other, rest)
		var kind: String = definition(segment)
		var number: int = maxi(copy_of(next_copy(kind)), int(_fresh_names.get(kind, 0)) + 1)
		_fresh_names[kind] = number
		mapped = join(mapped, "%s#%d" % [kind, number])
		inner[key] = mapped
	return join(other, mapped)


## The copies a follow has numbered so far, definition -> its highest
## ([method _named_in]): not yet in the model when the next is numbered.
var _fresh_names: Dictionary = {}


## The colour the copy that changed hands its parts of colour 16, and the
## colour the other hands them, read where their parts lay on each other in
## two colours ([param pairs], [param twin]), the commonest such pair: [its,
## the other's], or [] where every part is one colour in both.
func _placing(was: Array, pairs: Dictionary, twin: Dictionary) -> Array:
	var counted: Dictionary = {}
	for item: Dictionary in was:
		var theirs: int = int(twin[int(pairs[int(item["id"])])]["color"])
		if theirs != int(item["color"]):
			var key: Vector2i = Vector2i(int(item["color"]), theirs)
			counted[key] = int(counted.get(key, 0)) + 1
	var best: Variant = null
	for key: Vector2i in counted:
		if best == null or int(counted[key]) > int(counted[best]):
			best = key
	return [] if best == null else [(best as Vector2i).x, (best as Vector2i).y]


## Which step of the other copy each step of the one that changed is, by
## how many of its parts lie on parts there ([param pairs]): a step of
## its -> {the other's step: how many}, for [method _voted].
func _step_votes(was: Array, pairs: Dictionary, twin: Dictionary) -> Dictionary:
	var votes: Dictionary = {}
	for item: Dictionary in was:
		var theirs: int = int(twin[int(pairs[int(item["id"])])]["step"])
		if int(item["step"]) < 0 or theirs < 0:
			continue
		var tally: Dictionary = votes.get(int(item["step"]), {})
		tally[theirs] = int(tally.get(theirs, 0)) + 1
		votes[int(item["step"])] = tally
	return votes


## Which part of [param b] each part of [param a] lies on, laid by [param
## fit] ([method best_match]): id -> id, of those that land on one, the same
## part at the same place filling the same cells, whatever its colour.
func _laid_on(a: Array, b: Array, fit: Dictionary) -> Dictionary:
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
	return out


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


## The step of a copy built in the steps of the one round it that most of
## the parts of [param step] of the copy it follows lie on ([param votes],
## Assemblies._step_votes), or of its nearest step that any lie on; [param
## step] itself when none do: where a part put down in one goes in the other.
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
