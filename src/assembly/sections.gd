## Sections: a model split the way a builder builds it, a section pulled out
## of the model to work on and put back, and a section weighed on its own.
##
## A set is not built as one heap. Its parts come in numbered bags, and a
## bag builds a section: the base, a wall, the roof, a wing built in the
## hand and put on. Each is one piece when it is done, joined to what came
## before by a few joints, and of a size a person finishes in a sitting.
## The owner (2026-10-16): builders build "one section at a time", and the
## CAD "should be able to intelligently break out sections that users define
## into groups" that "can be separated out and evaluated individually".
##
## Suggesting
## ----------
## [method suggest] reads the model the way two things here already do and
## adds no third reading of its own:
##   the booklet's planner (Instructions): what rests on what, which
##     sub-builds are built on the side (a sub-model that holds together, a
##     minifigure, a hose), and so the order the sections come in;
##   the build check's joint graph, as Balance builds it: the stud joints
##     the lattice holds (Stability.contacts) and the pins, axles, clips,
##     hinges and glue (Joints), each with how much holds it.
## The parts are gathered into units that never part: a sub-assembly the
## model already has that fits in a section and is one piece, and the
## planner's sub-builds. Then the booklet's own order is cut, not the model
## in space: a bag is a run of the build, so what a section needs is in it
## or an earlier one and the sections are built one after another. Cutting
## the model where it is held least, in space, gave Sungnyemun's two halves
## side by side, each built onto the other (2026-10-16). The cuts fall near
## every bag's worth (about one for every 90 parts, at least two, at most
## 40) where least holds the units before to the units after; each run is
## then its pieces by the joint graph, so each section is one piece, and a
## piece under 0.3 of a bag goes in with the one it is held to most.
## Minifigures are a section of their own, as a set bags them.
##
## Breaking out
## ------------
## [method break_out] moves a section's parts away from the model the way
## it comes off — up off the studs it stands on, or out to the side it is
## pinned to — clear of the rest by two studs, by whole studs and whole
## bricks so it stays on the lattice, as one undo step. Where each part
## stood is kept with the model (BrickWorld.broken_out), so [method put_back]
## puts each exactly there, to the bit, as one more; a part put in while it
## was out goes back by the same offset. A file is written with every
## section put back (BrickWorld.home_of).
class_name Sections
extends RefCounted

## Fewer parts than this is built in one go: nothing to suggest.
const SMALLEST := 24
## Parts to a section, about: a bag's worth. A 300-part set comes in three
## or four bags and a 1,000-part one in ten or so.
const PER_SECTION := 90.0
const MOST := 40
## A section is let grow to this times the average before it stops taking
## parts, and one smaller than SMALL_SHARE of it is folded into the one it
## is held to most.
const GROW := 1.7
const SMALL_SHARE := 0.3
## How much a pin, an axle, a clip or a hinge holds against a stud.
const LINK := 2.0
## Lattice cells shared across one stud joint, as Stability.contacts counts
## them: a stud's square, 10 x 10 cells. A 2 x 4 brick on another shares 800
## (sections_probe), 8 studs.
const STUD_CELLS := 100.0
## How far clear of the rest a section broken out stands, in LDU: two studs
## to the side, two bricks above.
const CLEAR_SIDE := 40.0
const CLEAR_UP := 48.0

var world: BrickWorld
var library: PartLibrary
var builder: Builder
var assemblies: Assemblies
## The baseplate: never in a section.
var scenery: Dictionary = {}


## One section suggested.
class Suggestion extends RefCounted:
	## Its place in the build, from 1: bag 1 is built first.
	var number: int = 0
	var name: String = ""
	var ids: PackedInt64Array = PackedInt64Array()
	## What joins it to the rest: stud joints, as studs, and pins, axles,
	## clips and hinges.
	var studs: int = 0
	var links: int = 0
	## The sections it is built onto, by number.
	var onto: PackedInt32Array = PackedInt32Array()
	## Minifigures, or parts touching nothing: a section by what they are,
	## not one piece.
	var apart: bool = false
	## The way it comes off the model.
	var way: Vector3 = Vector3.UP
	## The sub-assembly it would be made in ("" the model).
	var level: String = ""

	func joints() -> int:
		return studs + links

	func said() -> String:
		var line: String = "%d. %s: %d part%s" % [number, name, ids.size(),
			"" if ids.size() == 1 else "s"]
		if apart:
			return line + ", built apart"
		line += ", joined by %s" % Sections.joins_words(studs, links)
		if not onto.is_empty():
			var numbers := PackedStringArray()
			for n: int in onto:
				numbers.append(str(n))
			line += ", built onto %s" % ", ".join(numbers)
		return line + ", comes off %s" % Sections.way_words(way)

	func to_dict() -> Dictionary:
		var onto_list: Array = []
		for n: int in onto:
			onto_list.append(n)
		return {"number": number, "name": name, "parts": ids.size(), "studs": studs,
			"links": links, "onto": onto_list, "apart": apart,
			"comes_off": Sections.way_words(way)}


## The last suggestion, and the level it was made at.
var suggested: Array[Suggestion] = []
var level: String = ""
## Why nothing was suggested, or "".
var why_none: String = ""
signal suggested_changed()


static func joins_words(studs: int, links: int) -> String:
	var bits := PackedStringArray()
	if studs > 0:
		bits.append("%d stud%s" % [studs, "" if studs == 1 else "s"])
	if links > 0:
		bits.append("%d pin, axle or clip joint%s" % [links, "" if links == 1 else "s"])
	return "nothing" if bits.is_empty() else " and ".join(bits)


static func way_words(way: Vector3) -> String:
	if way.y > 0.5:
		return "upward"
	if way.y < -0.5:
		return "downward"
	if absf(way.x) > absf(way.z):
		return "to the right" if way.x > 0.0 else "to the left"
	return "to the front" if way.z > 0.0 else "to the back"


static func _pair(a: int, b: int) -> int:
	return (mini(a, b) << 32) | maxi(a, b)


# -- reading the model ----------------------------------------------------------


## The level a suggestion is made at: the assembly being edited, or the
## model; and inside the one sub-assembly that holds all of it, when one
## does (a file whose main model is a sub-model of its own).
func _level() -> String:
	var at: String = assemblies.entered if assemblies != null else ""
	for _depth: int in 8:
		var bricks: Array = _bricks_in(at)
		if bricks.is_empty():
			return at
		var first: String = ""
		var one: bool = true
		for brick: BrickWorld.Brick in bricks:
			var below: String = _child_of(at, Assemblies.path_of(brick))
			if below.is_empty() or (not first.is_empty() and below != first):
				one = false
				break
			first = below
		if not one or first.is_empty():
			return at
		at = first
	return at


## The assembly directly inside [param at] that [param path] is in, or "".
static func _child_of(at: String, path: String) -> String:
	if path == at or not Assemblies.within(path, at):
		return ""
	var rest: String = path.substr(at.length()).trim_prefix("/")
	var first: String = rest.get_slice("/", 0)
	return Assemblies.join(at, first) if not first.is_empty() else ""


## The model's parts at [param at], the baseplate left out.
func _bricks_in(at: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		if Assemblies.within(Assemblies.path_of(brick), at):
			out.append(brick)
	return out


## The build check's joint graph over [param bricks], as Balance builds it:
## {"studs": pair -> studs, "under": pair -> the id of the one under,
## "links": pair -> 1}. A pair is [method _pair] of two brick ids.
func joint_graph(bricks: Array) -> Dictionary:
	var own: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		own[brick.id] = true
	var judge := Stability.new()
	judge.library = library
	judge.lattice = builder.lattice
	var contacts: Dictionary = judge.contacts(bricks)
	var studs: Dictionary = {}
	var under: Dictionary = {}
	var above: Dictionary = contacts["above"]
	for low: Variant in above:
		if not own.has(int(low)):
			continue
		var row: Dictionary = above[low]
		for high: Variant in row:
			if int(high) == int(low) or not own.has(int(high)):
				continue
			var key: int = _pair(int(low), int(high))
			studs[key] = int(studs.get(key, 0)) + maxi(1, roundi(float(row[high]) / STUD_CELLS))
			under[key] = int(low)
	var links: Dictionary = {}
	for held: Dictionary in _held_otherwise(bricks):
		for one: Variant in held:
			for other: Variant in held[one]:
				if int(one) != int(other) and own.has(int(one)) and own.has(int(other)):
					links[_pair(int(one), int(other))] = 1
	return {"studs": studs, "under": under, "links": links}


## Pins, axles, balls, clips, hinges, glue and one thing in pieces, as
## Balance._links finds them (Joints).
func _held_otherwise(bricks: Array) -> Array:
	var entries: Array = []
	for brick: BrickWorld.Brick in bricks:
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh != null:
			entries.append([brick.id, brick.transform, mesh, brick.part_id,
				Assemblies.path_of(brick)])
	return [Joints.both_ways(entries), Joints.rounds(entries),
		Joints.held_otherwise(entries, library)]


# -- suggesting -----------------------------------------------------------------


## How a builder would split the model, or the sub-assembly being edited,
## into sections. Kept in [member suggested]; [member why_none] says why
## there are none.
func suggest() -> Array[Suggestion]:
	suggested = []
	why_none = ""
	_made_in = world.generation()
	level = _level()
	var bricks: Array = _bricks_in(level)
	if bricks.size() < SMALLEST:
		why_none = ("%d parts is built in one go: nothing to split" % bricks.size()
			if not bricks.is_empty() else "nothing built yet")
		suggested_changed.emit()
		return suggested
	var count: int = bricks.size()
	var cut: Dictionary = _cut(bricks, clampi(roundi(count / PER_SECTION), 2, MOST))
	var index_of: Dictionary = cut["index_of"]
	var graph: Dictionary = cut["graph"]
	var groups: Array = cut["sections"]
	var figures: Array = cut["figures"]
	var loose: Array = cut["loose"]
	var cluster_of := PackedInt32Array()
	cluster_of.resize(count)
	cluster_of.fill(-1)
	for c: int in groups.size():
		for n: int in groups[c]:
			cluster_of[n] = c

	var model_box: AABB = _bounds_of_indices(bricks, range(count))
	var studs: Dictionary = graph["studs"]
	var under: Dictionary = graph["under"]
	var links: Dictionary = graph["links"]
	var names_taken: Dictionary = {}
	for path: String in assemblies.paths():
		names_taken[Assemblies.definition(Assemblies.leaf(path))] = true
	for c: int in groups.size():
		var made := Suggestion.new()
		made.level = level
		made.number = c + 1
		for n: int in groups[c]:
			made.ids.append((bricks[n] as BrickWorld.Brick).id)
		suggested.append(made)
	# What joins each to the rest, and which way it comes off.
	var sits: Dictionary = {}      ## section -> it stands on another's studs
	var carries: Dictionary = {}   ## section -> another stands on its studs
	var onto: Dictionary = {}
	var tally := func(key: int, is_stud: bool) -> void:
		var a: int = index_of[key >> 32]
		var b: int = index_of[key & 0xFFFFFFFF]
		var ca: int = cluster_of[a]
		var cb: int = cluster_of[b]
		if ca == cb:
			return
		for side: Array in [[ca, a], [cb, b]]:
			var c: int = side[0]
			if c < 0:
				continue
			var made: Suggestion = suggested[c]
			if is_stud:
				made.studs += int(studs[key])
				var low: int = index_of[int(under[key])]
				if low == int(side[1]):
					carries[c] = true
				else:
					sits[c] = true
			else:
				made.links += 1
	for key: int in studs:
		tally.call(key, true)
	for key: int in links:
		tally.call(key, false)
	# What each is built onto: what its parts need first, as the planner has it.
	var needs: Dictionary = cut["needs"]
	for brick_id: int in needs:
		if not index_of.has(brick_id):
			continue
		var c: int = cluster_of[index_of[brick_id]]
		if c < 0:
			continue
		for need: int in needs[brick_id]:
			if index_of.has(need):
				var d: int = cluster_of[index_of[need]]
				if d >= 0 and d != c:
					if not onto.has(c):
						onto[c] = {}
					onto[c][d] = true
	# Built in turn: each after every one it needs, the earliest begun first
	# among those ready; a loop of needs is taken where it begins.
	var order: Array = []
	var done: Dictionary = {}
	while order.size() < groups.size():
		var next: int = -1
		for c: int in groups.size():
			if done.has(c):
				continue
			var ready: bool = true
			for d: int in onto.get(c, {}):
				if not done.has(d):
					ready = false
					break
			if ready:
				next = c
				break
		if next < 0:
			for c: int in groups.size():
				if not done.has(c):
					next = c
					break
		done[next] = true
		order.append(next)
	var renumbered: Array[Suggestion] = []
	var new_groups: Array = []
	var new_onto: Dictionary = {}
	var place: Dictionary = {}
	for k: int in order.size():
		place[order[k]] = k
	for k: int in order.size():
		var made: Suggestion = suggested[order[k]]
		made.number = k + 1
		renumbered.append(made)
		new_groups.append(groups[order[k]])
		var mine: Dictionary = {}
		for d: int in onto.get(order[k], {}):
			mine[place[d]] = true
		new_onto[k] = mine
		if sits.has(order[k]):
			sits[-1 - k] = true
		if carries.has(order[k]):
			carries[-1 - k] = true
	suggested = renumbered
	groups = new_groups
	onto = new_onto
	for c: int in groups.size():
		var made: Suggestion = suggested[c]
		var box: AABB = _bounds_of_indices(bricks, groups[c])
		made.way = _way(box.get_center() - model_box.get_center(), sits.has(-1 - c),
			carries.has(-1 - c))
		for other: int in onto.get(c, {}):
			made.onto.append(other + 1)
		made.onto.sort()
		made.name = _name(made, box, model_box, bricks, groups[c], names_taken)
	for apart: Array in [[figures, "Minifigures" if figures.size() > 8 else "Minifigure"],
			[loose, "Loose parts"]]:
		var members: Array = apart[0]
		if members.is_empty():
			continue
		var made := Suggestion.new()
		made.level = level
		made.apart = true
		for n: int in members:
			made.ids.append((bricks[n] as BrickWorld.Brick).id)
		made.name = _unused(str(apart[1]), names_taken)
		made.number = suggested.size() + 1
		suggested.append(made)
	suggested_changed.emit()
	return suggested


## [param bricks] cut into about [param wanted] sections the way a set's bags
## cut a build. {"sections": Array of Arrays of indices into bricks, in the
## order they are built; "figures" and "loose": indices; "graph" (the joint
## graph); "index_of": brick id -> index}.
##
## The booklet's own order is cut, not the model in space: a bag is a run
## of the build, so what a section needs is in it or an earlier one, and the
## sections can be built one after another. Cut where least holds the
## parts before to the parts after, near every bag's worth; each run is
## then its pieces, by the joint graph, so each section is one piece.
func _cut(bricks: Array, wanted: int) -> Dictionary:
	var count: int = bricks.size()
	var index_of: Dictionary = {}
	for n: int in count:
		index_of[(bricks[n] as BrickWorld.Brick).id] = n
	var most: int = ceili(count * GROW / wanted)
	var smallest: int = maxi(3, floori(count * SMALL_SHARE / wanted))

	# The planner's reading of these parts alone, as Instructions.plan reads
	# a model: what rests on what, what it builds on the side, and the order.
	var skip: Dictionary = scenery.duplicate()
	for brick: BrickWorld.Brick in world.bricks():
		if not index_of.has(brick.id):
			skip[brick.id] = true
	var nodes: Array[Instructions.Node2] = Instructions._survey(world, library, skip)
	Instructions._find_supports(nodes, world, library)
	Instructions._find_joints(nodes, world, library)
	Instructions._tidy_needs(nodes)
	Instructions._find_hangers(nodes)
	var subs: Array[Instructions.Assembly] = Instructions._find_assemblies(nodes, world, library)
	Instructions._find_bundles(nodes, world, library, subs)
	Instructions._frame_turned(subs, world, library, null)
	var built: Array[Instructions.Node2] = Instructions._contract(nodes, subs)
	var named: bool = Instructions._assign_regions(built, {}, nodes.size())
	var raw: Array = Instructions._sequence(built, named, Instructions._per_step(nodes.size()))
	var steps: Array[Instructions.Step] = Instructions._expand(raw, world)
	var position := PackedInt64Array()
	position.resize(count)
	position.fill(0x7FFFFFFF)
	var at: int = 0
	for step: Instructions.Step in steps:
		for brick_id: int in step.brick_ids:
			if index_of.has(brick_id) and position[index_of[brick_id]] == 0x7FFFFFFF:
				position[index_of[brick_id]] = at
			at += 1
		for copy: PackedInt64Array in step.copies:
			for brick_id: int in copy:
				if index_of.has(brick_id) and position[index_of[brick_id]] == 0x7FFFFFFF:
					position[index_of[brick_id]] = at
				at += 1

	# The joint graph, part to part.
	var graph: Dictionary = joint_graph(bricks)
	var held: Array = []               ## index -> {index: how much holds them}
	held.resize(count)
	for n: int in count:
		held[n] = {}
	for kind: String in ["studs", "links"]:
		for key: int in graph[kind]:
			var a: int = index_of[key >> 32]
			var b: int = index_of[key & 0xFFFFFFFF]
			var much: float = float(graph["studs"][key]) if kind == "studs" else LINK
			held[a][b] = float(held[a].get(b, 0.0)) + much
			held[b][a] = float(held[b].get(a, 0.0)) + much

	# What the planner says each part rests on or needs, guesses and all:
	# what a piece the joint graph holds to nothing is put with (a tile
	# held by its clips, a part the graph does not read).
	var leans: Array = []
	leans.resize(count)
	for n: int in count:
		leans[n] = []
	for node: Instructions.Node2 in nodes:
		if not index_of.has(node.id):
			continue
		var n: int = index_of[node.id]
		for need: int in node.needs:
			if index_of.has(need) and int(index_of[need]) != n:
				(leans[n] as Array).append(int(index_of[need]))
				(leans[int(index_of[need])] as Array).append(n)

	# Units: what never parts. A sub-assembly the model has, when it fits in
	# a section and is one piece; the planner's sub-builds, figures and hoses.
	var unit := _Sets.new(count)
	var size_of: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		var path: String = Assemblies.path_of(brick)
		while not path.is_empty() and path != level:
			size_of[path] = int(size_of.get(path, 0)) + 1
			path = Assemblies.parent_of(path)
	var by_whole: Dictionary = {}
	for n: int in count:
		var path: String = Assemblies.path_of(bricks[n])
		var whole: String = ""
		var inside: String = _child_of(level, path)
		while not inside.is_empty():
			if int(size_of.get(inside, 0)) <= most:
				whole = inside
				break
			inside = _child_of(inside, path)
		if not whole.is_empty():
			if not by_whole.has(whole):
				by_whole[whole] = []
			(by_whole[whole] as Array).append(n)
	for whole: String in by_whole:
		var members: Array = by_whole[whole]
		if _one_piece(members, held):
			for n: int in members:
				unit.join(members[0], n)
	var figure_part: Dictionary = {}
	for made: Instructions.Assembly in subs:
		var first: int = -1
		for member: Instructions.Node2 in made.members:
			if not index_of.has(member.id):
				continue
			var n: int = index_of[member.id]
			if first < 0:
				first = n
			else:
				unit.join(first, n)
			if made.figure:
				figure_part[n] = true
		made.node = null
	# A unit is a figure when figures are all it is: one sat in a cockpit
	# its author made is built with the cockpit.
	var unit_size: Dictionary = {}
	var unit_figures: Dictionary = {}
	var unit_at: Dictionary = {}
	for n: int in count:
		var r: int = unit.top(n)
		unit_size[r] = int(unit_size.get(r, 0)) + 1
		unit_at[r] = mini(int(unit_at.get(r, 0x7FFFFFFF)), position[n])
		if figure_part.has(n):
			unit_figures[r] = int(unit_figures.get(r, 0)) + 1
	var figures: Array = []
	var units: Array = []
	for r: int in unit_size:
		if int(unit_figures.get(r, 0)) == int(unit_size[r]):
			continue
		units.append(r)
	for n: int in count:
		var r: int = unit.top(n)
		if int(unit_figures.get(r, 0)) == int(unit_size[r]):
			figures.append(n)
	# In build order.
	units.sort_custom(func(x: int, y: int) -> bool:
		return int(unit_at[x]) < int(unit_at[y]) or (int(unit_at[x]) == int(unit_at[y]) and x < y))
	var rank: Dictionary = {}
	for k: int in units.size():
		rank[units[k]] = k
	var total: int = 0
	var before := PackedInt64Array()   ## parts in the units ranked before k
	before.resize(units.size() + 1)
	for k: int in units.size():
		before[k] = total
		total += int(unit_size[units[k]])
	before[units.size()] = total
	# What holds the units before a cut to those after it, at every cut.
	var across := PackedFloat64Array()
	across.resize(units.size() + 2)
	across.fill(0.0)
	for a: int in count:
		var ra: Variant = rank.get(unit.top(a))
		if ra == null:
			continue
		for b: int in held[a]:
			if b <= a:
				continue
			var rb: Variant = rank.get(unit.top(b))
			if rb == null or int(ra) == int(rb):
				continue
			across[mini(int(ra), int(rb)) + 1] += float(held[a][b])
			across[maxi(int(ra), int(rb)) + 1] -= float(held[a][b])
	var running: float = 0.0
	for k: int in across.size():
		running += across[k]
		across[k] = running
	# Cuts: near each bag's worth, where least holds.
	var share: float = float(total) / wanted
	var cuts: Array = [0]
	var start: int = 0
	while total - int(before[start]) > roundi(share * 1.5):
		var best: int = -1
		var best_cost: float = INF
		for k: int in range(start + 1, units.size()):
			var parts: int = int(before[k]) - int(before[start])
			if parts < roundi(share * 0.5):
				continue
			if parts > roundi(share * 1.6):
				break
			# Least held, and nearer a bag's worth when alike.
			var cost: float = across[k] + absf(parts - share) / share
			if cost < best_cost:
				best_cost = cost
				best = k
		if best < 0:
			break
		cuts.append(best)
		start = best
	cuts.append(units.size())

	# Each run, its pieces.
	var pieces: Array = []             ## each an Array of unit ranks
	var run_of: Array = []             ## piece -> the run it is in
	for c: int in cuts.size() - 1:
		var run := _Sets.new(units.size())
		for a: int in count:
			var ra: Variant = rank.get(unit.top(a))
			if ra == null or int(ra) < cuts[c] or int(ra) >= cuts[c + 1]:
				continue
			for b: int in held[a]:
				var rb: Variant = rank.get(unit.top(b))
				if rb != null and int(rb) >= cuts[c] and int(rb) < cuts[c + 1]:
					run.join(int(ra), int(rb))
		var by_top: Dictionary = {}
		for k: int in range(cuts[c], cuts[c + 1]):
			var top: int = run.top(k)
			if not by_top.has(top):
				by_top[top] = []
				pieces.append(by_top[top])
				run_of.append(c)
			(by_top[top] as Array).append(k)
	# A piece too small to be a section goes in with one it is held to: of
	# its own run, the one held most; else the last run before it, which it
	# stands on; else the first after. Into any other its section would
	# need one built after it. One held by nothing is loose.
	var piece_of: Dictionary = {}      ## unit rank -> piece
	var parts_in: Array = []
	for p: int in pieces.size():
		var parts: int = 0
		for k: int in pieces[p]:
			piece_of[k] = p
			parts += int(unit_size[units[k]])
		parts_in.append(parts)
	var into: Array = []
	for p: int in pieces.size():
		into.append(p)
	var loose: Array = []
	var follow := func(p: int) -> int:
		while int(into[p]) != p:
			p = int(into[p])
		return p
	for p: int in pieces.size():
		if int(parts_in[p]) >= smallest:
			continue
		var pull: Dictionary = {}
		for a: int in count:
			var ra: Variant = rank.get(unit.top(a))
			if ra == null or int(piece_of[int(ra)]) != p:
				continue
			for b: int in held[a]:
				var rb: Variant = rank.get(unit.top(b))
				if rb == null:
					continue
				var q: int = follow.call(int(piece_of[int(rb)]))
				if q != p:
					pull[q] = float(pull.get(q, 0.0)) + float(held[a][b])
		# A part or two held by nothing the graph reads (a tile in clips, a
		# part whose joint it does not know): with what it rests on or
		# carries. Bigger ones stay loose: put with a section by a guess,
		# the build check found it in two pieces (10179-1, 2026-10-17).
		if pull.is_empty() and int(parts_in[p]) <= 2:
			for a: int in count:
				var ra: Variant = rank.get(unit.top(a))
				if ra == null or int(piece_of[int(ra)]) != p:
					continue
				for b: int in leans[a]:
					var rb: Variant = rank.get(unit.top(b))
					if rb == null:
						continue
					var q: int = follow.call(int(piece_of[int(rb)]))
					if q != p:
						pull[q] = float(pull.get(q, 0.0)) + 0.5
		var best: int = -1
		var best_key: float = -INF
		for q: int in pull:
			var gap: int = int(run_of[q]) - int(run_of[p])
			# Its own run first, then the nearest before, then the nearest after;
			# the most held among equals.
			var key: float = (3000.0 if gap == 0 else 2000.0 + gap if gap < 0
				else 1000.0 - gap) * 1000000.0 + float(pull[q])
			if key > best_key:
				best_key = key
				best = q
		if best >= 0:
			into[p] = best
			parts_in[best] = int(parts_in[best]) + int(parts_in[p])
	# Each whole a section; one still too small is loose parts.
	var sections: Array = []
	var section_of: Dictionary = {}    ## piece it all went into -> section, or -1
	for p: int in pieces.size():
		var q: int = follow.call(p)
		if section_of.has(q):
			continue
		if int(parts_in[q]) < smallest:
			section_of[q] = -1
			continue
		section_of[q] = sections.size()
		sections.append([])
	for n: int in count:
		var r: int = unit.top(n)
		if not rank.has(r):
			continue
		var s: int = int(section_of[follow.call(int(piece_of[int(rank[r])]))])
		if s < 0:
			loose.append(n)
		else:
			(sections[s] as Array).append(n)
	# In the order they are built: by where each begins.
	var first_at: Dictionary = {}
	for s: int in sections.size():
		var least: int = 0x7FFFFFFF
		for n: int in sections[s]:
			least = mini(least, position[n])
		first_at[s] = least
	var order: Array = range(sections.size())
	order.sort_custom(func(x: int, y: int) -> bool: return int(first_at[x]) < int(first_at[y]))
	var ordered: Array = []
	for s: int in order:
		if not (sections[s] as Array).is_empty():
			ordered.append(sections[s])
	# What each part needs first, as the planner has it, less what it only
	# guessed from a box touching or a height (Node2.weak).
	var needs: Dictionary = {}
	for node: Instructions.Node2 in nodes:
		if node.weak.is_empty():
			needs[node.id] = node.needs
			continue
		var sure := PackedInt64Array()
		for need: int in node.needs:
			if not need in node.weak:
				sure.append(need)
		needs[node.id] = sure
	return {"sections": ordered, "figures": figures, "loose": loose, "graph": graph,
		"index_of": index_of, "needs": needs}


## Whether [param members] (indices) are one piece by [param held].
static func _one_piece(members: Array, held: Array) -> bool:
	if members.size() < 2:
		return true
	var own: Dictionary = {}
	for n: int in members:
		own[n] = true
	var reached: Dictionary = {members[0]: true}
	var frontier: Array = [members[0]]
	while not frontier.is_empty():
		var at: int = frontier.pop_back()
		for b: int in held[at]:
			if own.has(b) and not reached.has(b):
				reached[b] = true
				frontier.append(b)
	return reached.size() == members.size()


## Disjoint sets over 0..n-1.
class _Sets extends RefCounted:
	var _up := PackedInt32Array()

	func _init(count: int) -> void:
		_up.resize(count)
		for n: int in count:
			_up[n] = n

	func top(n: int) -> int:
		while _up[n] != n:
			_up[n] = _up[_up[n]]
			n = _up[n]
		return n

	func join(a: int, b: int) -> void:
		var ra: int = top(a)
		var rb: int = top(b)
		if ra != rb:
			_up[maxi(ra, rb)] = mini(ra, rb)


## The way a section comes off: up off the studs it stands on when nothing
## stands on it, and otherwise out the side of the model it is on, from the
## middle of the rest to its own; the front when it is in the middle.
static func _way(away: Vector3, sits: bool, carries: bool) -> Vector3:
	if not carries and (sits or away.y > maxf(absf(away.x), absf(away.z))):
		return Vector3.UP
	if absf(away.x) < BrickLattice.STUD and absf(away.z) < BrickLattice.STUD:
		return Vector3(0, 0, 1)
	if absf(away.x) > absf(away.z):
		return Vector3(signf(away.x), 0, 0)
	return Vector3(0, 0, signf(away.z))


## What a builder calls it: where it is in the model ("Base", "Top", "Left
## side", "Front"), or the sub-assembly it already is.
func _name(made: Suggestion, box: AABB, whole: AABB, bricks: Array, members: Array,
		taken: Dictionary) -> String:
	# One sub-assembly the model has, whole: its own name.
	var paths: Dictionary = {}
	for n: int in members:
		paths[_child_of(level, Assemblies.path_of(bricks[n]))] = true
	if paths.size() == 1 and not str(paths.keys()[0]).is_empty():
		var own: String = Assemblies.definition(Assemblies.leaf(str(paths.keys()[0])))
		# "subModel-48", as some files call every sub-model, says nothing.
		var numbered: bool = own.to_lower().replace(" ", "").replace("_", "").replace("-", "") \
			.trim_prefix("submodel").is_valid_int()
		if own.length() <= 40 and not numbered:
			return _unused(own, taken)
	var wide: float = maxf(whole.size.x * whole.size.z, 1.0)
	var footprint: float = box.size.x * box.size.z
	var centre: Vector3 = box.get_center() - whole.get_center()
	var reach: Vector3 = (whole.size * 0.5).max(Vector3.ONE)
	var off := Vector3(centre.x / reach.x, centre.y / reach.y, centre.z / reach.z)
	var word: String = "Section"
	if made.number == 1 and box.position.y <= whole.position.y + BrickLattice.PLATE \
			and footprint >= wide * 0.4:
		word = "Base"
	elif box.end.y >= whole.end.y - BrickLattice.PLATE and footprint >= wide * 0.35 \
			and box.position.y > whole.position.y + whole.size.y * 0.4:
		word = "Top"
	else:
		var most: float = maxf(absf(off.x), maxf(absf(off.y), absf(off.z)))
		if most < 0.25:
			word = "Middle" if made.number > 1 else "Base"
		elif absf(off.x) == most:
			word = "Right side" if off.x > 0.0 else "Left side"
		elif absf(off.z) == most:
			word = "Front" if off.z > 0.0 else "Back"
		else:
			word = "Upper part" if off.y > 0.0 else "Lower part"
	return _unused(word, taken)


static func _unused(word: String, taken: Dictionary) -> String:
	var name: String = word
	var n: int = 2
	while taken.has(name):
		name = "%s %d" % [word, n]
		n += 1
	taken[name] = true
	return name


func _bounds_of_indices(bricks: Array, members: Array) -> AABB:
	var out := AABB()
	var first: bool = true
	for n: int in members:
		var brick: BrickWorld.Brick = bricks[n]
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var box: AABB = brick.transform * info.bounds if info != null \
			else AABB(brick.transform.origin, Vector3.ZERO)
		out = box if first else out.merge(box)
		first = false
	return out


func bounds_of(ids: Variant) -> AABB:
	var out := AABB()
	var first: bool = true
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var box: AABB = brick.transform * info.bounds if info != null \
			else AABB(brick.transform.origin, Vector3.ZERO)
		out = box if first else out.merge(box)
		first = false
	return out


# -- changing the suggestion ------------------------------------------------------


## Rename a suggestion. The name is what the sub-assembly will be called.
func rename(number: int, wanted: String) -> String:
	var made: Suggestion = _numbered(number)
	var name: String = wanted.strip_edges().replace("/", "-").replace("#", "")
	if made == null or name.is_empty():
		return ""
	made.name = name
	suggested_changed.emit()
	return name


## Two suggestions as one: [param number] into [param into], or into the
## one it is joined to most when [param into] is 0.
func merge(number: int, into: int = 0) -> String:
	var made: Suggestion = _numbered(number)
	if made == null:
		return "no section %d" % number
	if into <= 0:
		into = _most_joined(made)
		if into <= 0:
			return "%s is joined to no other section" % made.name
	var other: Suggestion = _numbered(into)
	if other == null or other == made:
		return "no section %d to merge into" % into
	other.ids.append_array(made.ids)
	other.apart = other.apart and made.apart
	suggested.erase(made)
	_renumber()
	_rejoin()
	suggested_changed.emit()
	return "%s merged into %s" % [made.name, other.name]


## One suggestion as two, parted where it is held by least.
func split(number: int) -> String:
	var made: Suggestion = _numbered(number)
	if made == null:
		return "no section %d" % number
	if made.ids.size() < 4:
		return "%s is too small to split" % made.name
	var bricks: Array = []
	for brick_id: int in made.ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null:
			bricks.append(brick)
	var halves: Array = _two(bricks)
	if halves.size() < 2:
		return "%s does not come apart in two pieces" % made.name
	var at: int = suggested.find(made)
	var taken: Dictionary = {}
	for one: Suggestion in suggested:
		taken[one.name] = true
	taken.erase(made.name)
	made.ids = PackedInt64Array(halves[0])
	var other := Suggestion.new()
	other.level = made.level
	other.apart = made.apart
	other.ids = PackedInt64Array(halves[1])
	other.name = _unused(made.name, taken)
	suggested.insert(at + 1, other)
	_renumber()
	_rejoin()
	suggested_changed.emit()
	return "%s split into %s (%d parts) and %s (%d)" % [made.name, made.name,
		made.ids.size(), other.name, other.ids.size()]


## [param bricks] in two, cut as [method suggest] cuts a model: the first
## built, and the rest. Ids.
func _two(bricks: Array) -> Array:
	var cut: Dictionary = _cut(bricks, 2)
	var parts: Array = cut["sections"]
	if parts.size() < 2:
		return []
	var out: Array = [[], []]
	for s: int in parts.size():
		for n: int in parts[s]:
			(out[0 if s == 0 else 1] as Array).append((bricks[n] as BrickWorld.Brick).id)
	for n: int in (cut["figures"] as Array) + (cut["loose"] as Array):
		(out[1] as Array).append((bricks[n] as BrickWorld.Brick).id)
	return out


func _numbered(number: int) -> Suggestion:
	for made: Suggestion in suggested:
		if made.number == number:
			return made
	return null


func _renumber() -> void:
	for n: int in suggested.size():
		suggested[n].number = n + 1


## The joints between suggestions again, after a merge or a split.
func _rejoin() -> void:
	var all: Array = []
	var section_of: Dictionary = {}
	for made: Suggestion in suggested:
		made.studs = 0
		made.links = 0
		made.onto = PackedInt32Array()
		for brick_id: int in made.ids:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick != null:
				all.append(brick)
				section_of[brick_id] = made
	var graph: Dictionary = joint_graph(all)
	for key: int in graph["studs"]:
		var a: Suggestion = section_of[key >> 32]
		var b: Suggestion = section_of[key & 0xFFFFFFFF]
		if a == b:
			continue
		a.studs += int(graph["studs"][key])
		b.studs += int(graph["studs"][key])
		var low: int = int(graph["under"][key])
		var high: Suggestion = b if section_of[low] == a else a
		var below: Suggestion = a if high == b else b
		if not below.number in high.onto:
			high.onto.append(below.number)
	for key: int in graph["links"]:
		var a: Suggestion = section_of[key >> 32]
		var b: Suggestion = section_of[key & 0xFFFFFFFF]
		if a != b:
			a.links += 1
			b.links += 1
	for made: Suggestion in suggested:
		made.onto.sort()


## The suggestion [param made] is joined to by the most.
func _most_joined(made: Suggestion) -> int:
	var all: Array = []
	var section_of: Dictionary = {}
	for one: Suggestion in suggested:
		for brick_id: int in one.ids:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick != null:
				all.append(brick)
				section_of[brick_id] = one
	var graph: Dictionary = joint_graph(all)
	var held: Dictionary = {}
	for kind: String in ["studs", "links"]:
		for key: int in graph[kind]:
			var a: Suggestion = section_of[key >> 32]
			var b: Suggestion = section_of[key & 0xFFFFFFFF]
			if a == b or (a != made and b != made):
				continue
			var other: Suggestion = b if a == made else a
			held[other.number] = float(held.get(other.number, 0.0)) \
				+ (float(graph["studs"][key]) if kind == "studs" else LINK)
	var best: int = 0
	var most: float = 0.0
	for number: int in held:
		if float(held[number]) > most:
			most = float(held[number])
			best = number
	return best


## Make the suggestions sub-assemblies, as one undo step: all of them, or
## those numbered in [param numbers]. Each takes the name it was given;
## what is in a sub-assembly already goes inside it. Returns the paths made.
func accept(numbers: Array = []) -> PackedStringArray:
	var made_paths := PackedStringArray()
	var changes: Dictionary = {}
	var taken: Dictionary = {}
	for made: Suggestion in suggested:
		if not numbers.is_empty() and not made.number in numbers:
			continue
		var name: String = assemblies.unused_name(made.name)
		while taken.has(name):
			name = assemblies.unused_name(name + " %d" % (taken.size() + 1))
		taken[name] = true
		var path: String = Assemblies.join(made.level, name + "#1")
		made_paths.append(path)
		for brick_id: int in made.ids:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick == null or scenery.has(brick_id):
				continue
			var rest: String = Assemblies.path_of(brick).substr(made.level.length()).trim_prefix("/")
			changes[brick_id] = path if rest.is_empty() else path + "/" + rest
	if changes.is_empty():
		return PackedStringArray()
	builder.regroup(changes, "made %d section%s of %s" % [made_paths.size(),
		"" if made_paths.size() == 1 else "s", Builder._many(changes.size())])
	assemblies.no_copies_follow()
	var kept: Array[Suggestion] = []
	for made: Suggestion in suggested:
		if not numbers.is_empty() and not made.number in numbers:
			kept.append(made)
	suggested = kept
	_renumber()
	assemblies.changed.emit()
	suggested_changed.emit()
	return made_paths


## The model the suggestion was made for: one opened since has other parts.
var _made_in: int = -1


## Put the suggestion away when the model it was made for is gone.
func forget_if_stale() -> void:
	if not suggested.is_empty() and world.generation() != _made_in:
		dismiss()


func dismiss() -> void:
	suggested = []
	why_none = ""
	suggested_changed.emit()


# -- the sections there are -------------------------------------------------------


## The model's sections as they are: the sub-assemblies directly inside the
## one being edited (or the model), each with its parts.
func sections() -> Array:
	var at: String = _level()
	var found: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var child: String = _child_of(at, Assemblies.path_of(brick))
		if child.is_empty():
			continue
		# An Array: a packed one taken out of a dictionary is a copy, and
		# what was appended to it went nowhere (the exploded view drew
		# nothing apart, 2026-10-16).
		if not found.has(child):
			found[child] = []
		(found[child] as Array).append(brick.id)
	var out: Array = []
	for path: String in found:
		out.append({"path": path, "ids": PackedInt64Array(found[path])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["path"]).naturalnocasecmp_to(str(b["path"])) < 0)
	return out


## A sub-assembly by what a person or a session calls it: its path, its
## label ("Wing (copy 2)"), or its name; "" when there is none.
func find_section(asked: String) -> String:
	var wanted: String = asked.strip_edges()
	if wanted.is_empty():
		return ""
	var by_name: String = ""
	for path: String in assemblies.paths():
		if path == wanted:
			return path
		if Assemblies.label(path).to_lower() == wanted.to_lower():
			return path
		if by_name.is_empty() and Assemblies.definition(Assemblies.leaf(path)).to_lower() \
				== wanted.to_lower():
			by_name = path
	return by_name


# -- what joins a section to the rest -----------------------------------------------


## What holds [param ids] to the rest of the model: {"on": rest id -> studs
## it stands on, "carries": rest id -> studs standing on it, "links": rest
## id -> pins, axles, clips and hinges, "studs", "joints", "at": where they
## are, on average}.
func joins(ids: Dictionary) -> Dictionary:
	var lattice: BrickLattice = builder.lattice
	var on: Dictionary = {}
	var carries: Dictionary = {}
	var where := Vector3.ZERO
	var count: int = 0
	for brick_id: int in ids:
		var mine: PackedInt32Array = lattice.boxes_of(brick_id)
		if mine.is_empty():
			continue
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		for way: int in [1, -1]:
			var moved: PackedInt32Array = BrickLattice.moved_by(mine, Vector3i(0, way, 0))
			for other: int in lattice.near_bounds(moved, brick_id):
				if ids.has(other) or scenery.has(other):
					continue
				var shared: int = BrickLattice.shared_cells(moved, lattice.boxes_of(other))
				if shared <= 0:
					continue
				var into: Dictionary = carries if way == 1 else on
				into[other] = int(into.get(other, 0)) + shared
				var them: BrickWorld.Brick = world.get_brick(other)
				if brick != null and them != null:
					where += (brick.transform.origin + them.transform.origin) * 0.5
					count += 1
	var studs: int = 0
	for side: Dictionary in [on, carries]:
		for other: int in side:
			side[other] = maxi(1, roundi(float(side[other]) / STUD_CELLS))
			studs += int(side[other])
	# Pins, axles and clips, between it and what is near it.
	var box: AABB = bounds_of(ids.keys()).grow(BrickLattice.STUD)
	var near: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		if ids.has(brick.id):
			near.append(brick)
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info != null and box.intersects(brick.transform * info.bounds):
			near.append(brick)
	var links: Dictionary = {}
	var seen: Dictionary = {}
	for held: Dictionary in _held_otherwise(near):
		for one: Variant in held:
			for other: Variant in held[one]:
				var a: int = int(one)
				var b: int = int(other)
				if ids.has(a) == ids.has(b):
					continue
				var key: int = _pair(a, b)
				if seen.has(key):
					continue
				seen[key] = true
				var theirs: int = b if ids.has(a) else a
				links[theirs] = int(links.get(theirs, 0)) + 1
				var x: BrickWorld.Brick = world.get_brick(a)
				var y: BrickWorld.Brick = world.get_brick(b)
				if x != null and y != null:
					where += (x.transform.origin + y.transform.origin) * 0.5
					count += 1
	return {"on": on, "carries": carries, "links": links, "studs": studs,
		"joints": studs + seen.size(), "pins": seen.size(),
		"at": where / count if count > 0 else Vector3.INF}


## The way [param ids] come off the model (a unit vector on an axis).
func way_off(ids: Dictionary, held: Dictionary = {}) -> Vector3:
	if held.is_empty():
		held = joins(ids)
	var box: AABB = bounds_of(ids.keys())
	var from: Vector3 = _rest_bounds(ids).get_center()
	return _way(box.get_center() - from, not (held["on"] as Dictionary).is_empty(),
		not (held["carries"] as Dictionary).is_empty())


## Everything of the model but [param ids] (and the baseplate).
func _rest_bounds(ids: Dictionary) -> AABB:
	var rest: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if not ids.has(brick.id) and not scenery.has(brick.id):
			rest.append(brick.id)
	return bounds_of(rest)


# -- breaking out and putting back ----------------------------------------------


## The record of the section broken out that [param path] is (or holds the
## parts of), as [path it is kept under, record]; [] when it is not out.
func out_record(path: String) -> Array:
	if world.broken_out.has(path):
		return [path, world.broken_out[path]]
	var ids: PackedInt64Array = assemblies.ids_under(path)
	for kept: String in world.broken_out:
		var home: Dictionary = (world.broken_out[kept] as Dictionary).get("home", {})
		for brick_id: int in ids:
			if home.has(brick_id):
				return [kept, world.broken_out[kept]]
	return []


## Pull the section at [param path] away from the model the way it comes
## off, as one undo step. {"ok", "words", "offset", "bounds"}.
func break_out(path: String, words_name: String = "") -> Dictionary:
	var name: String = words_name if not words_name.is_empty() else Assemblies.label(path)
	if path.is_empty():
		return {"ok": false, "words": "choose a section (a sub-assembly) to break out"}
	if not out_record(path).is_empty():
		return {"ok": false, "words": "%s is broken out already" % name}
	var ids: PackedInt64Array = assemblies.ids_under(path)
	if ids.is_empty():
		return {"ok": false, "words": "no section %s" % name}
	# A copy inside another with copies: moving it would rebuild the others.
	var up: String = Assemblies.parent_of(path)
	while not up.is_empty():
		if not assemblies.copies_of(up).is_empty():
			return {"ok": false, "words": ("%s is inside %s, which has other copies: make "
				% [name, Assemblies.label(up)] + "that copy unique first")}
		up = Assemblies.parent_of(up)
	var own: Dictionary = {}
	for brick_id: int in ids:
		own[brick_id] = true
	var way: Vector3 = way_off(own)
	var box: AABB = bounds_of(ids)
	var rest: AABB = _rest_bounds(own)
	var step: float = BrickLattice.BRICK if way.y != 0.0 else BrickLattice.STUD
	var reach: float
	if way.y > 0.0:
		reach = rest.end.y - box.position.y + CLEAR_UP
	elif way.x > 0.0:
		reach = rest.end.x - box.position.x + CLEAR_SIDE
	elif way.x < 0.0:
		reach = box.end.x - rest.position.x + CLEAR_SIDE
	elif way.z > 0.0:
		reach = rest.end.z - box.position.z + CLEAR_SIDE
	else:
		reach = box.end.z - rest.position.z + CLEAR_SIDE
	reach = maxf(ceilf(reach / step), 1.0) * step
	var home: Dictionary = {}
	for brick_id: int in ids:
		home[brick_id] = world.get_brick(brick_id).transform
	# What its parts overlap where they stand, as parts at a joint do: a
	# stud in a tube, a pin in its hole. Going back, it may meet those
	# again and nothing else.
	var touching: Dictionary = {}
	for brick_id: int in ids:
		for other: int in builder.lattice.blockers_boxes(builder.lattice.boxes_of(brick_id),
				brick_id):
			if not own.has(other):
				touching[other] = true
	for _try: int in 12:
		var offset: Vector3 = way * reach
		var targets: Dictionary = {}
		for brick_id: int in ids:
			targets[brick_id] = (home[brick_id] as Transform3D).translated(offset)
		var record: Dictionary = {"offset": offset, "home": home, "touching": touching}
		var moved: int = _move(targets, "broke out %s" % name,
			{"undo": "sectionout", "path": path, "record": null}, path, record)
		if moved > 0:
			return {"ok": true, "words": "broke %s out, %s %s" % [name,
				_distance(reach, way), way_words(way)], "offset": offset,
				"bounds": bounds_of(ids)}
		reach += step
	return {"ok": false, "words": "nowhere clear to pull %s out to" % name}


static func _distance(reach: float, way: Vector3) -> String:
	if way.y != 0.0:
		var bricks: int = roundi(reach / BrickLattice.BRICK)
		return "%d brick%s" % [bricks, "" if bricks == 1 else "s"]
	var studs: int = roundi(reach / BrickLattice.STUD)
	return "%d stud%s" % [studs, "" if studs == 1 else "s"]


## Put the section at [param path] back where it was pulled from, as one
## undo step. {"ok", "words"}.
func put_back(path: String, words_name: String = "") -> Dictionary:
	var found: Array = out_record(path)
	var name: String = words_name if not words_name.is_empty() else Assemblies.label(path)
	if found.is_empty():
		return {"ok": false, "words": "%s is not broken out" % name}
	var kept: String = found[0]
	var record: Dictionary = found[1]
	var targets: Dictionary = {}
	var ids: Dictionary = {}
	for brick_id: int in assemblies.ids_under(kept):
		ids[brick_id] = true
	for brick_id: int in (record.get("home", {}) as Dictionary):
		if world.get_brick(brick_id) != null:
			ids[brick_id] = true
	for brick_id: int in ids:
		targets[brick_id] = home_for(world.get_brick(brick_id).transform, record, brick_id)
	var moved: int = _move(targets, "put %s back" % name,
		{"undo": "sectionout", "path": kept, "record": record}, kept, null,
		record.get("touching", {}))
	if moved == 0 and not targets.is_empty():
		return {"ok": false, "words": ("something was built where %s goes: move it, then put "
			% name + "it back")}
	return {"ok": true, "words": "put %s back" % name}


## Where a part of a section broken out goes back to: where it stood, to
## the bit, when it has not moved since; its offset back otherwise.
static func home_for(now: Transform3D, record: Dictionary, brick_id: int) -> Transform3D:
	var offset: Vector3 = record.get("offset", Vector3.ZERO)
	var home: Dictionary = record.get("home", {})
	if home.has(brick_id):
		var was: Transform3D = home[brick_id]
		if now.basis.is_equal_approx(was.basis) \
				and now.origin.distance_to(was.origin + offset) < 0.01:
			return was
	return now.translated(-offset)


## Move bricks to [param targets] (id -> Transform3D) as one step of the
## history with [param state] (the sectionout step that undoes it), and set
## the section's record to [param record] (null: not out). None move when
## any would run into something or through the floor. How many moved.
func _move(targets: Dictionary, words: String, state: Dictionary, path: String,
		record: Variant, allowed: Dictionary = {}) -> int:
	var lattice: BrickLattice = builder.lattice
	var was: Dictionary = {}
	var covers: Dictionary = {}
	for brick_id: int in targets:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		was[brick_id] = brick.transform
		covers[brick_id] = lattice.cover_of(brick_id)
		lattice.release(brick_id)
	var landing: Dictionary = {}
	var blocked: bool = false
	for brick_id: int in was:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var to: Transform3D = targets[brick_id]
		var cells: Variant = Builder._cells_moved(brick.transform, to)
		var cover: Array = covers[brick_id]
		var shifted: bool = cells != null and not (cover[0] as PackedInt32Array).is_empty()
		var packed: PackedInt32Array = BrickLattice.moved_by(cover[0], cells) if shifted \
			else builder.boxes_for(library.mesh_for(brick.part_id), to)
		var n: int = 1
		while n < packed.size():
			if packed[n] < Builder.GROUND_CELL:
				blocked = true
				break
			n += 6
		if blocked or (lattice.collides_boxes(packed) if allowed.is_empty()
				else not lattice.blockers_boxes(packed, 0, allowed).is_empty()):
			blocked = true
			break
		landing[brick_id] = [to, packed, shifted, cells]
	if blocked:
		for brick_id: int in was:
			var cover: Array = covers[brick_id]
			if not (cover[0] as PackedInt32Array).is_empty():
				lattice.occupy_moved(brick_id, cover, Vector3i.ZERO)
			else:
				lattice.occupy_boxes(brick_id, builder.boxes_for(
					library.mesh_for(world.get_brick(brick_id).part_id), was[brick_id]))
		return 0
	var steps: Array = []
	for brick_id: int in landing:
		var land: Array = landing[brick_id]
		steps.append({"undo": "move", "brick": brick_id, "transform": was[brick_id]})
		world.move_brick(brick_id, land[0])
		if bool(land[2]):
			lattice.occupy_moved(brick_id, covers[brick_id], land[3])
		else:
			lattice.occupy_boxes(brick_id, land[1])
	if record is Dictionary:
		world.broken_out[path] = record
	else:
		world.broken_out.erase(path)
	steps.append(state)
	builder.record(steps, words)
	# The section moved whole: no part's shape changed, and no copy of a
	# sub-model is built again for it. One split between sections (a file's
	# unlike copies, 10179-1) had its other copy rebuilt, 10 parts swapped,
	# and the section could not go back (2026-10-17).
	assemblies.no_copies_follow()
	return landing.size()


# -- the exploded view ------------------------------------------------------------


## Where each section is drawn in the exploded view, apart: brick id ->
## Transform3D, for BrickWorld.set_drawn. [param share] 0 is together and 1
## all the way apart. [param groups] is Array of {ids}; the sections there
## are when empty, or the suggestion when there are none.
func exploded(share: float, groups: Array = []) -> Dictionary:
	if groups.is_empty():
		groups = explode_groups()
	var all: Dictionary = {}
	for group: Dictionary in groups:
		for brick_id: int in group["ids"]:
			all[brick_id] = true
	var whole: AABB = bounds_of(all.keys())
	var centre: Vector3 = whole.get_center()
	var placed: Dictionary = {}
	for group: Dictionary in groups:
		var own: Dictionary = {}
		for brick_id: int in group["ids"]:
			own[brick_id] = true
		var way: Vector3 = group.get("way", way_off(own))
		var box: AABB = bounds_of(own.keys())
		var along: float = absf(box.size.dot(way))
		var out: Vector3 = way * (along * 0.6 + BrickLattice.STUD * 2.0) \
			+ (box.get_center() - centre) * Vector3(0.35, 0.2, 0.35)
		var shift := Vector3(snappedf(out.x, 2.0), snappedf(maxf(out.y, 0.0), 2.0),
			snappedf(out.z, 2.0)) * share
		for brick_id: int in own:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick != null:
				placed[brick_id] = brick.transform.translated(shift)
	return placed


## What the exploded view takes apart: the sections there are, when there
## are two or more; the suggested ones otherwise.
func explode_groups() -> Array:
	var made: Array = sections()
	if made.size() >= 2:
		return made
	var out: Array = []
	for one: Suggestion in suggested:
		out.append({"ids": one.ids, "way": one.way, "name": one.name})
	return out


# -- weighing one alone -------------------------------------------------------------


## A section on its own, in numbers: {"name", "parts" (as the parts list
## counts them), "lots", "grams", "weight", "pieces" (by the joint graph:
## 1 holds together), "stands", "balance" (words), "margin", "joins"
## ({"studs", "pins", "parts"}), "load" (words), "steps", "lots_list"}.
func evaluate(ids: PackedInt64Array, name: String = "") -> Dictionary:
	var own: Dictionary = {}
	var bricks: Array = []
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null and not scenery.has(brick_id):
			own[brick_id] = true
			bricks.append(brick)
	var out: Dictionary = {"name": name, "parts": 0}
	if bricks.is_empty():
		return out
	var rest: Dictionary = scenery.duplicate()
	for brick: BrickWorld.Brick in world.bricks():
		if not own.has(brick.id):
			rest[brick.id] = true
	var stock: Inventory = Inventory.of(world, library, rest)
	out["parts"] = Inventory.pieces_in(world, library, rest)
	out["lots"] = stock.lots.size()
	out["grams"] = stock.grams
	out["weight"] = stock.weight()
	var listed: Array = []
	for lot: Inventory.Lot in stock.lots:
		listed.append({"count": lot.count, "part": lot.part_id, "name": lot.name,
			"colour": lot.color_name})
	out["lots_list"] = listed
	# One piece, by the joint graph.
	var graph: Dictionary = joint_graph(bricks)
	out["pieces"] = _pieces(bricks, graph)
	# Whether it stands, built on its own: on its own lowest parts.
	var judge := Balance.new()
	judge.library = library
	judge.lattice = builder.lattice
	var balance: Balance.Report = judge.measure(bricks)
	out["stands"] = balance.stands()
	out["margin"] = balance.margin
	out["balance"] = balance.words()
	# What joins it to the rest, and what that carries.
	var held: Dictionary = joins(own)
	var joined: Dictionary = {}
	for kind: String in ["on", "carries", "links"]:
		for other: int in held[kind]:
			joined[other] = true
	out["joins"] = {"studs": int(held["studs"]), "pins": int(held["pins"]),
		"parts": joined.size()}
	out["way"] = way_words(way_off(own, held))
	var hangs: bool = (held["on"] as Dictionary).is_empty()
	var studs: int = int(held["studs"])
	var hold: float = studs * Stability.GRAMS_PER_STUD
	if joined.is_empty():
		out["load"] = "it touches nothing else of the model"
	elif hangs and studs > 0:
		out["load"] = ("it hangs from %s: %s on %d stud%s, which hold %.0f g at the working load (%s)"
			% [joins_words(studs, int(held["pins"])), stock.weight(), studs,
			"" if studs == 1 else "s", hold, "carries it" if stock.grams <= hold
			else "too heavy for them: %.1fx" % (stock.grams / maxf(hold, 1.0))])
	elif hangs:
		out["load"] = ("it is held by %d pin, axle or clip joint%s alone, %s on them"
			% [int(held["pins"]), "" if int(held["pins"]) == 1 else "s", stock.weight()])
	else:
		out["load"] = "it stands on %s of the rest: %s pressing down on them" % [
			joins_words(studs, int(held["pins"])), stock.weight()]
	# Its own steps, as the booklet would build it alone.
	var steps: Array = Instructions.plan(world, library, rest)
	out["steps"] = steps.size()
	return out


## How many pieces [param bricks] are in, by [param graph].
static func _pieces(bricks: Array, graph: Dictionary) -> int:
	var root: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		root[brick.id] = brick.id
	var find := func(x: int) -> int:
		while int(root[x]) != x:
			root[x] = root[root[x]]
			x = root[x]
		return x
	for kind: String in ["studs", "links"]:
		for key: int in graph[kind]:
			var a: int = find.call(key >> 32)
			var b: int = find.call(key & 0xFFFFFFFF)
			if a != b:
				root[a] = b
	var tops: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		tops[find.call(brick.id)] = true
	return tops.size()


## The section in words, as the window and a session read it.
static func evaluation_words(made: Dictionary) -> String:
	if int(made.get("parts", 0)) == 0:
		return "%s has no parts" % str(made.get("name", "It"))
	var lines := PackedStringArray()
	lines.append("%s: %d part%s in %d lot%s, %s." % [str(made["name"]), int(made["parts"]),
		"" if int(made["parts"]) == 1 else "s", int(made["lots"]),
		"" if int(made["lots"]) == 1 else "s", str(made["weight"])])
	var pieces: int = int(made.get("check_pieces", made["pieces"]))
	lines.append("Holds together: %s." % ("yes, one piece" if pieces == 1
		else "no, it is %d pieces" % pieces))
	if made.has("check"):
		lines.append("Build check alone: %s." % str(made["check"]))
	lines.append("Built on its own: %s" % str(made["balance"]))
	var joins: Dictionary = made["joins"]
	lines.append("Joined to the rest by %s, to %d part%s; it comes off %s." % [
		joins_words(int(joins["studs"]), int(joins["pins"])), int(joins["parts"]),
		"" if int(joins["parts"]) == 1 else "s", str(made["way"])])
	lines.append("Load: %s." % str(made["load"]))
	lines.append("Its own steps: %d, as the booklet would build it alone." % int(made["steps"]))
	return "\n".join(lines)
