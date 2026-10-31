## The parts nobody sees in the finished model, given colours that tell a
## person building it where they are: the way big sets are coloured inside.
##
## A LEGO designer who worked on them gave the reason: "Lowering the time to
## find bricks is one of the things that gets scrutinised intensely", and a
## bright brick among 99% grey wing plates is found at once; "the number one
## reason is build flow" (Brickset, 2024, docs/HIDDEN_COLOURS.md). So the
## Imperial Star Destroyer is "as colorful as possible" inside, the Razor
## Crest's colours "are always hidden as each section is completed", and the
## Eiffel Tower's core is red north to south and yellow east to west, so its
## legs go on the right way round. The colours are ones already made in
## that mould, and none of them is seen once the model is finished.
##
## So this does that, and no more:
##
##   which parts   only those SeenParts never sees from any side: measured,
##                 never guessed. A part seen from anywhere keeps its colour.
##   how grouped   by section (the booklet's sections: an assembly the
##                 design named, a sub-model, a region of a big model), by
##                 build stage (the booklet's steps cut into stages, as bags
##                 are), or by side (left and right, or front and back: the
##                 two halves of a symmetrical build told apart)
##   which colours few and strong, as real sets have them: LEGO's own order
##                 (blue, yellow, red, green, then the modern brights, pinks
##                 only when those are out), one a group, a group too small
##                 to matter joined to its neighbour ([constant SMALLEST]),
##                 two stages unless asked for more ([constant COLOURS]). A
##                 colour is out when it, with the colours near it, is a real
##                 share of the outside ([constant OUTSIDE_SHARE]): LEGO puts
##                 blue inside a model with a few blue parts showing, not
##                 inside a blue one. For each part only a colour the catalogue
##                 says it was made in, and never the colour of a seen part it
##                 touches, which would read as more of that part. A part
##                 that cannot take its group's colour, nor one near enough to
##                 stand for it, keeps its own.
##   what is kept  see-through, chrome, rubber and the like; printed and
##                 stickered parts; minifigures; locked parts; parts whose
##                 colours nobody knows; a hidden part already in a bright
##                 colour nothing seen has (somebody coded it already: LEGO,
##                 or the person); and every copy of a sub-assembly unless
##                 every copy's part is hidden, because copies are kept alike
##                 (Assemblies.after_edit) and one would change the other.
##
## The change is one step to undo (Builder.record). What it chose goes with
## the model as a line LDraw readers pass over ([constant META]), so the
## booklet can show each group's colour where it starts.
class_name HiddenColours
extends RefCounted

const MODES: Array[String] = ["sections", "stages", "left_right", "front_back"]
const MODE_WORDS: Dictionary = {
	"sections": "by section", "stages": "by build stage",
	"left_right": "left and right", "front_back": "front and back",
}

## The colours a group can be, in the order they are offered: as often as
## real sets use each where nobody sees it (docs/HIDDEN_COLOURS.md, 1,576
## sets measured: Blue in 41, Yellow 33, Red 28, Green 20), then the modern
## brights (Dark Turquoise 7, Lime, Orange and Medium Azure 6, Bright Green
## 2), then the pinks, lavender and coral, which LEGO keeps for when the
## rest are out. Blue and yellow first suits colour blindness too: its
## commonest kind cannot tell red from green.
const ACCENTS: Array[int] = [1, 14, 4, 2, 3, 27, 25, 322, 10, 73, 321, 191, 29, 5, 26, 30,
	353, 212, 15, 19]
## A group takes the first colour of [constant ACCENTS] that at least this
## share as many of its parts can take as the colour most of them can: the
## order wins unless a colour further down reaches far more of them.
const GOOD_ENOUGH := 0.6
## How far, in CIE76 units, a colour on the outside must be from a group's
## for it not to count against it: Blue against Dark Blue is 26, Red against
## Dark Red 31, Lime against Bright Green 30.
const APART := 22.0
## The share of the outside's parts, in a colour and those within APART of
## it, that rules the colour out for the inside. Of LEGO's 130 inside colours
## in the 68 sets that mark their insides, 82 are seen outside too, at a
## median 0.15% of the outside's parts and at most 3.1%; 127 are under 2%.
const OUTSIDE_SHARE := 0.02
## Colours, when the person does not say: the stages a build is cut into.
## LEGO's 68 marked sets use 1.9 on average (37 one, 17 two, 7 three, 4
## four, three sets more).
const COLOURS := 2
## A group with less than this share of the parts being coloured joins its
## neighbour in the build rather than take a colour of its own: three in four
## of LEGO's smallest inside colours, in sets with more than one, have more
## than 9% of the set's inside-coloured parts (median 20%).
const SMALLEST := 0.1
## And more groups than this, left to the model to say, are joined until
## there are no more: 62 of the 68 marked sets use four colours or fewer.
const MOST_COLOURS := 4
## And from every other group's.
const GROUPS_APART := 20.0
## How near another colour may be to a group's own and stand in for it, on
## a part not made in the group's colour: Medium Azure for Dark Azure (17),
## Bright Light Orange for Yellow (19).
const NEAR := 24.0
## A hidden part in a colour nothing seen has, and vivid ([method vivid]:
## at least this CIE chroma and this lightness), is a mark somebody made
## already, and is kept. Blue is 48 and 40, Medium Azure 30 and 74; Reddish
## Brown (37, 24), Dark Red (52, 24) and Tan (27) are filler, not marks.
const CODED_CHROMA := 28.0
const CODED_LIGHTNESS := 33.0
## The most stages a build is cut into when the person asks.
const MOST_STAGES := 12

const META := "0 !BRICKWORKS HIDDEN_COLOURS "


## One group: a section, a stage or a side.
class Group extends RefCounted:
	var key: String = ""
	var label: String = ""
	## LDraw code of its colour, -1 when it has none.
	var colour: int = -1
	## Colours near enough to stand in for it.
	var also: PackedInt32Array = PackedInt32Array()
	## Hidden parts in it that could take a colour.
	var hidden: int = 0
	var recoloured: int = 0
	## Its place in the build: stages are numbered in order, so two stages
	## next to each other never share a colour when colours run out.
	var order: int = 0
	## The sections or stages it stands for once small ones are joined to
	## it, as the booklet names them; and a stage group's first and last
	## stage and steps.
	var names: PackedStringArray = PackedStringArray()
	var stage_from: int = 0
	var stage_to: int = 0
	var step_from: int = 0
	var step_to: int = 0


## What would be done: worked out, shown, then applied or not.
class Plan extends RefCounted:
	var mode: String = "sections"
	var groups: Array[Group] = []
	## Brick id -> the colour it would be, and the group it is in.
	var changes: Dictionary = {}
	var group_of: Dictionary = {}
	var parts: int = 0
	## Hidden: seen from no side SeenParts drew.
	var hidden: int = 0
	## Why each hidden part not recoloured was kept, reason -> how many.
	var kept: Dictionary = {}
	## The colours seen on the outside.
	var outside: PackedInt32Array = PackedInt32Array()
	## Said when the model should not be recoloured without asking: a real
	## set's own colours. Empty when nothing stands in the way.
	var ask_first: String = ""
	## The measure it rests on.
	var views: int = 0
	var pixel: float = 0.0

	## What goes with the model for the booklet: {mode, groups: [{label,
	## colour, also}]}, the groups that took a colour.
	func scheme() -> Dictionary:
		var out: Array = []
		for group: Group in groups:
			if group.recoloured > 0:
				out.append({"label": group.label, "colour": group.colour,
					"also": Array(group.also), "sections": Array(group.names)})
		return {"mode": mode, "groups": out}

	## In words: what it would do and what it keeps.
	func summary(library: PartLibrary) -> String:
		if hidden == 0:
			return ("Every one of the %d parts can be seen from somewhere outside (%d sides "
				+ "looked from), so there is nothing hidden to colour.") % [parts, views]
		var said := PackedStringArray()
		var named := PackedStringArray()
		for group: Group in groups:
			if group.recoloured > 0:
				named.append("%s in %s (%d)" % [group.label,
					HiddenColours.colour_name(library, group.colour), group.recoloured])
		said.append("%d of the %d parts are hidden: seen from none of %d sides, a pixel "
			% [hidden, parts, views] + "%.1f LDU at most." % pixel)
		if named.is_empty():
			said.append("None of them can take a colour %s." % MODE_WORDS.get(mode, mode))
		else:
			said.append("%d would be coloured %s: %s." % [changes.size(),
				MODE_WORDS.get(mode, mode), "; ".join(named)])
		var kept_words := PackedStringArray()
		for reason: String in kept:
			kept_words.append("%d %s" % [int(kept[reason]), HiddenColours.REASONS.get(reason,
				reason)])
		if not kept_words.is_empty():
			said.append("Kept as they are: %s." % ", ".join(kept_words))
		return " ".join(said)


const REASONS: Dictionary = {
	"not_plastic": "not plain plastic (chrome, rubber, glow…)",
	"printed": "printed or stickered",
	"figure": "minifigure parts",
	"locked": "locked",
	"unknown": "whose colours the catalogue does not know",
	"not_made": "not made in their group's colour",
	"coded": "already in a colour of their own that nothing outside has",
	"copies_seen": "with a copy of their sub-assembly that is seen",
	"copies_apart": "with copies in different groups",
	"copies_kept": "with a copy kept for a reason of its own",
	"copies_differ": "in copies of a sub-assembly that differ from one another",
	"middle": "across the middle",
	"beside_seen": "touching a seen part of their group's colour",
	"no_colour": "in a group no colour was left for",
}


## The model's bricks as SeenParts and pictures take them: [[id, part,
## colour, transform], ...], the baseplate left out.
static func bricks_of(world: BrickWorld, scenery: Dictionary) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if not scenery.has(brick.id):
			out.append([brick.id, brick.part_id, brick.color_code, brick.transform])
	return out


## What to do, worked out from what is [param hidden] (SeenParts.Result
## .hidden()). [param steps] are the booklet's (Instructions.plan, with the
## author's steps), which name the sections and set the stages. [param
## stages] 0 lets the size of the model say how many.
static func plan(world: BrickWorld, library: PartLibrary, scenery: Dictionary,
		hidden: Dictionary, mode: String, steps: Array[Instructions.Step],
		assemblies: Assemblies, locked: Dictionary = {}, stages: int = 0) -> Plan:
	var made := Plan.new()
	made.mode = mode if mode in MODES else "sections"
	var bricks: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if not scenery.has(brick.id):
			bricks[brick.id] = brick
	made.parts = bricks.size()
	made.hidden = hidden.size()

	# What is seen: how many parts of each colour, which a mark must stand
	# out from, and where each part in an accent colour is, which a part
	# taking that colour must not touch.
	var outside: Dictionary = {}
	var seen_at: Dictionary = {}
	for brick_id: int in bricks:
		if not hidden.has(brick_id):
			var brick: BrickWorld.Brick = bricks[brick_id]
			var colour: PartLibrary.BrickColor = library.color(brick.color_code)
			if colour.is_transparent():
				continue
			var plain: int = library.plain_code(colour.code)
			outside[plain] = int(outside.get(plain, 0)) + 1
			if plain in ACCENTS:
				_file_box(seen_at, plain, _box_of(library, brick))
	made.outside = PackedInt32Array(outside.keys())

	# Which hidden parts may take a colour at all, and why not the rest.
	var free: Dictionary = {}
	for brick_id: int in hidden:
		if not bricks.has(brick_id):
			continue
		var reason: String = _kept_for(bricks[brick_id], library, outside, locked)
		if reason.is_empty():
			free[brick_id] = true
		else:
			made.kept[reason] = int(made.kept.get(reason, 0)) + 1

	# Copies of a sub-assembly are kept alike: a part goes with its
	# counterparts in every copy, or not at all.
	var family: Dictionary = _families(assemblies, bricks)
	var with: Dictionary = {}
	for brick_id: int in free:
		var root: int = int(family.get(brick_id, brick_id))
		if not with.has(root):
			with[root] = []
		(with[root] as Array).append(brick_id)
	var members_of: Dictionary = {}
	for brick_id: int in family:
		var root: int = family[brick_id]
		if not members_of.has(root):
			members_of[root] = []
		(members_of[root] as Array).append(brick_id)

	# Groups.
	var group_of: Dictionary = _group_each(made, world, library, bricks, steps, stages)
	var by_key: Dictionary = {}
	for group: Group in made.groups:
		by_key[group.key] = group

	# A set of copies is one choice: all hidden, all free, one group.
	var choices: Array = []
	for root: int in with:
		var ready: Array = with[root]
		if root == -1:
			_keep(made, "copies_differ", ready.size())
			continue
		var members: Array = members_of.get(root, [root])
		if ready.size() < members.size():
			var seen_one: bool = members.any(func(id: int) -> bool: return not hidden.has(id))
			_keep(made, "copies_seen" if seen_one else "copies_kept", ready.size())
			continue
		var keys: Dictionary = {}
		for brick_id: int in members:
			keys[str(group_of.get(brick_id, ""))] = true
		if keys.size() != 1:
			_keep(made, "middle" if keys.has("") else "copies_apart", members.size())
			continue
		var key: String = keys.keys()[0]
		if key.is_empty():
			_keep(made, "middle", members.size())
			continue
		choices.append([key, members])
		(by_key[key] as Group).hidden += members.size()

	_join_small(made, choices, by_key, stages > 0)
	var boxes: Dictionary = {}
	var touch: Callable = func(members: Array, code: int) -> bool:
		if not seen_at.has(code):
			return false
		for brick_id: int in members:
			if not boxes.has(brick_id):
				boxes[brick_id] = _box_of(library, bricks[brick_id])
			if _touches(seen_at, code, boxes[brick_id]):
				return true
		return false
	_choose_colours(made, library, outside, choices, bricks, touch)

	for choice: Array in choices:
		var group: Group = by_key[choice[0]]
		var members: Array = choice[1]
		if group.colour < 0:
			_keep(made, "no_colour", members.size())
			continue
		var colour: int = _colour_for(library, members, bricks, group, touch)
		if colour == -2:
			_keep(made, "beside_seen", members.size())
			continue
		if colour < 0:
			_keep(made, "not_made", members.size())
			continue
		for brick_id: int in members:
			if (bricks[brick_id] as BrickWorld.Brick).color_code != colour:
				made.changes[brick_id] = colour
				made.group_of[brick_id] = group
		group.recoloured += members.size()
	return made


static func _keep(made: Plan, reason: String, count: int) -> void:
	made.kept[reason] = int(made.kept.get(reason, 0)) + count


## Why a hidden brick keeps its colour whatever the group, or "".
static func _kept_for(brick: BrickWorld.Brick, library: PartLibrary, outside: Dictionary,
		locked: Dictionary) -> String:
	var colour: PartLibrary.BrickColor = library.color(brick.color_code)
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
	if colour.is_transparent() or colour.finish != "solid" or not colour.is_plastic():
		return "not_plastic"
	if info == null:
		return "unknown"
	if info.decor() != 0:
		return "printed"
	if info.category.begins_with("Minifig") or brick.group.begins_with("Minifig") \
			or info.category == "Sticker":
		return "figure"
	if locked.has(brick.id):
		return "locked"
	if info.colors.is_empty():
		return "unknown"
	var plain: int = library.plain_code(brick.color_code)
	if not outside.has(plain) and vivid(colour.rgb):
		return "coded"
	return ""


## Brick id -> the first brick of its family: itself and its counterparts
## in every other copy of each sub-assembly it is in (Assemblies
## .counterparts). A brick in no copied assembly is not in it. A copy that
## does not match its first copy exactly makes all its parts a family of
## their own that can never be free (the -1 root).
static func _families(assemblies: Assemblies, bricks: Dictionary) -> Dictionary:
	var parent: Dictionary = {}
	if assemblies == null:
		return parent
	var find: Callable = func(id: int) -> int:
		var at: int = id
		while parent.has(at) and int(parent[at]) != at:
			at = parent[at]
		return at
	var done: Dictionary = {}
	# One walk of the model for every path asked about, as Assemblies' own
	# passes over many copies have it: a path at a time, each of Orthanc's
	# copies walked its 10,101 parts again, a third of a second (bigmodels).
	assemblies._begin_pass()
	for path: String in assemblies.paths():
		var definition: String = Assemblies.definition(Assemblies.leaf(path))
		if done.has(definition):
			continue
		var copies: Array = Array(assemblies.copies_of(path))
		if copies.is_empty():
			continue
		copies.append(path)
		copies = Assemblies.in_file_order(copies)
		done[definition] = true
		var first: String = copies[0]
		for other: String in copies.slice(1):
			var pairs: Dictionary = assemblies.counterparts(first, other)
			if pairs.is_empty():
				# Copies that differ: none of their parts is anybody's to
				# recolour, since an edit to one rebuilds the others.
				for one: String in copies:
					for brick_id: int in assemblies.ids_under(one):
						parent[brick_id] = -1
				break
			for a: int in pairs:
				var b: int = pairs[a]
				if int(parent.get(a, 0)) == -1 or int(parent.get(b, 0)) == -1:
					continue
				if not parent.has(a):
					parent[a] = a
				if not parent.has(b):
					parent[b] = b
				var root_a: int = find.call(a)
				var root_b: int = find.call(b)
				if root_a != root_b:
					parent[root_b] = root_a
	assemblies._end_pass()
	var out: Dictionary = {}
	for brick_id: int in parent:
		if not bricks.has(brick_id):
			continue
		out[brick_id] = -1 if int(parent[brick_id]) == -1 else int(find.call(brick_id))
	# A family with a member that may not change is one that cannot.
	return out


## Each brick's group key, and the groups, for [param made]'s mode.
static func _group_each(made: Plan, world: BrickWorld, library: PartLibrary,
		bricks: Dictionary, steps: Array[Instructions.Step], stages: int) -> Dictionary:
	var out: Dictionary = {}
	var groups: Dictionary = {}
	var add: Callable = func(key: String, label: String, order: int) -> void:
		if not groups.has(key):
			var group := Group.new()
			group.key = key
			group.label = label
			group.order = order
			groups[key] = group
	match made.mode:
		"sections", "stages":
			# Where each brick goes in the booklet, and its section: a
			# callout's steps take the section of the step that puts the
			# finished assembly on.
			var rank: Dictionary = {}
			var section: Dictionary = {}
			var pending: Array = []
			var counted: int = 0
			for step: Instructions.Step in steps:
				for brick_id: int in step.brick_ids:
					if not rank.has(brick_id):
						rank[brick_id] = counted
						counted += 1
				if step.in_callout():
					pending.append(step)
					continue
				for one: Instructions.Step in pending + [step]:
					for brick_id: int in one.brick_ids:
						section[brick_id] = step.section
				pending.clear()
			if made.mode == "sections":
				var named: bool = section.values().any(func(s: String) -> bool:
					return not s.is_empty())
				var order: Dictionary = {}
				for brick_id: int in bricks:
					var key: String = str(section.get(brick_id, ""))
					if not named:
						# Built in one go: its sub-assemblies, else the whole.
						var path: String = Assemblies.path_of(bricks[brick_id])
						key = Assemblies.definition(Assemblies.segments(path)[0]) \
							if not path.is_empty() else "Inside"
					if key.is_empty():
						key = "Inside"
					if not order.has(key):
						order[key] = int(rank.get(brick_id, counted))
					order[key] = mini(int(order[key]), int(rank.get(brick_id, counted)))
					out[brick_id] = key
				for key: String in order:
					add.call(key, key.capitalize() if key.begins_with("part ") else key,
						int(order[key]))
			else:
				var total: int = maxi(1, counted)
				var count: int = clampi(stages if stages > 0 else COLOURS, 1, MOST_STAGES)
				var first_step: Dictionary = {}
				var last_step: Dictionary = {}
				for step: Instructions.Step in steps:
					for brick_id: int in step.brick_ids:
						var stage: int = mini(count - 1, int(rank.get(brick_id, 0)) * count / total)
						first_step[stage] = mini(int(first_step.get(stage, step.number)),
							step.number)
						last_step[stage] = maxi(int(last_step.get(stage, step.number)), step.number)
				for brick_id: int in bricks:
					var stage: int = mini(count - 1, int(rank.get(brick_id, counted)) * count / total)
					out[brick_id] = "stage %d" % (stage + 1)
				for stage: int in count:
					add.call("stage %d" % (stage + 1), "Stage %d (steps %d–%d)" % [stage + 1,
						int(first_step.get(stage, 0)), int(last_step.get(stage, 0))], stage)
					var made_group: Group = groups["stage %d" % (stage + 1)]
					made_group.stage_from = stage + 1
					made_group.stage_to = stage + 1
					made_group.step_from = int(first_step.get(stage, 0))
					made_group.step_to = int(last_step.get(stage, 0))
		_:
			# The two halves: across x (left and right, as the model is
			# seen from the front, which faces +z) or across z.
			var axis: int = 0 if made.mode == "left_right" else 2
			var boxes: Dictionary = {}
			var whole := AABB()
			var any: bool = false
			for brick_id: int in bricks:
				var brick: BrickWorld.Brick = bricks[brick_id]
				var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
				var box: AABB = brick.transform * part.bounds if part != null \
					else AABB(brick.transform.origin, Vector3.ZERO)
				boxes[brick_id] = box
				whole = box if not any else whole.merge(box)
				any = true
			var middle: float = whole.get_center()[axis]
			var names: Array = ["left", "right"] if axis == 0 else ["back", "front"]
			for brick_id: int in bricks:
				var box: AABB = boxes[brick_id]
				if box.end[axis] <= middle + 0.5:
					out[brick_id] = names[0]
				elif box.position[axis] >= middle - 0.5:
					out[brick_id] = names[1]
				else:
					out[brick_id] = ""
			add.call(names[0], "Left side" if axis == 0 else "Back half", 0)
			add.call(names[1], "Right side" if axis == 0 else "Front half", 1)
	var listed: Array = groups.values()
	listed.sort_custom(func(a: Group, b: Group) -> bool: return a.order < b.order)
	for group: Group in listed:
		group.names = PackedStringArray([group.label])
		made.groups.append(group)
	return out


## Few, strong colours: a group with under [constant SMALLEST] of the parts
## being coloured joins its neighbour in the build, the smallest first, and
## while more than [constant MOST_COLOURS] remain and the person did not ask
## for how many ([param asked]), the smallest joins its neighbour too. The
## choices that named a group joined name the one it joined.
static func _join_small(made: Plan, choices: Array, by_key: Dictionary, asked: bool) -> void:
	var live: Array = made.groups.filter(func(g: Group) -> bool: return g.hidden > 0)
	var total: int = 0
	for group: Group in live:
		total += group.hidden
	var into: Dictionary = {}
	while live.size() > 1:
		var smallest: Group = live[0]
		for group: Group in live:
			if group.hidden < smallest.hidden:
				smallest = group
		var too_small: bool = float(smallest.hidden) < SMALLEST * float(total)
		if not too_small and (asked or live.size() <= MOST_COLOURS):
			break
		# Its neighbour in the build: the one before, else the one after,
		# the smaller of the two when it has both.
		var at: int = live.find(smallest)
		var before: Group = live[at - 1] if at > 0 else null
		var after: Group = live[at + 1] if at + 1 < live.size() else null
		var neighbour: Group = before if after == null or (before != null
			and before.hidden <= after.hidden) else after
		neighbour.hidden += smallest.hidden
		neighbour.names.append_array(smallest.names)
		neighbour.stage_from = mini(neighbour.stage_from, smallest.stage_from)
		neighbour.stage_to = maxi(neighbour.stage_to, smallest.stage_to)
		neighbour.step_from = mini(neighbour.step_from, smallest.step_from)
		neighbour.step_to = maxi(neighbour.step_to, smallest.step_to)
		smallest.hidden = 0
		into[smallest.key] = neighbour.key
		live.erase(smallest)
	if into.is_empty():
		return
	for choice: Array in choices:
		var key: String = choice[0]
		while into.has(key):
			key = into[key]
		choice[0] = key
	for group: Group in made.groups:
		if group.names.size() < 2:
			continue
		if made.mode == "stages":
			group.label = "Stages %d–%d (steps %d–%d)" % [group.stage_from, group.stage_to,
				group.step_from, group.step_to]
		else:
			var sorted: PackedStringArray = group.names.duplicate()
			group.label = ", ".join(sorted.slice(0, sorted.size() - 1)) + " and " \
				+ sorted[sorted.size() - 1]


## A brick's box in the world.
static func _box_of(library: PartLibrary, brick: BrickWorld.Brick) -> AABB:
	var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
	return brick.transform * part.bounds if part != null \
		else AABB(brick.transform.origin, Vector3.ZERO)


## Boxes of seen parts by colour, in cells of [constant TOUCH_CELL] LDU.
const TOUCH_CELL := 80.0
## How near a seen part may be and still touch: a hair, so parts standing
## side by side or on each other's studs touch and parts a gap apart do not.
const TOUCH_GAP := 1.0


static func _file_box(seen_at: Dictionary, code: int, box: AABB) -> void:
	if not seen_at.has(code):
		seen_at[code] = {}
	var cells: Dictionary = seen_at[code]
	var low := Vector3i((box.position / TOUCH_CELL).floor())
	var high := Vector3i((box.end / TOUCH_CELL).floor())
	for x: int in range(low.x, high.x + 1):
		for y: int in range(low.y, high.y + 1):
			for z: int in range(low.z, high.z + 1):
				var cell := Vector3i(x, y, z)
				if not cells.has(cell):
					cells[cell] = []
				(cells[cell] as Array).append(box)


## Whether [param box] touches a seen part of colour [param code].
static func _touches(seen_at: Dictionary, code: int, box: AABB) -> bool:
	var cells: Dictionary = seen_at.get(code, {})
	if cells.is_empty():
		return false
	var grown: AABB = box.grow(TOUCH_GAP)
	var low := Vector3i((grown.position / TOUCH_CELL).floor())
	var high := Vector3i((grown.end / TOUCH_CELL).floor())
	for x: int in range(low.x, high.x + 1):
		for y: int in range(low.y, high.y + 1):
			for z: int in range(low.z, high.z + 1):
				for other: AABB in cells.get(Vector3i(x, y, z), []):
					if grown.intersects(other):
						return true
	return false


## A colour for each group, the largest group first: of the colours not
## out ([method _out]) and far enough from the groups given one already,
## the first in LEGO's order ([constant ACCENTS]) that reaches at least
## [constant GOOD_ENOUGH] as many of the group's parts as the colour that
## reaches most. A part is reached when it was made in the colour and
## touches no seen part of it ([param touch]).
static func _choose_colours(made: Plan, library: PartLibrary, outside: Dictionary,
		choices: Array, bricks: Dictionary, touch: Callable) -> void:
	var seen_total: int = 0
	for code: int in outside:
		seen_total += int(outside[code])
	var offered: Array[int] = []
	for code: int in ACCENTS:
		var colour: PartLibrary.BrickColor = library.colors.get(code)
		if colour == null or not library.is_current(code):
			continue
		if not _out(library, code, outside, seen_total):
			offered.append(code)
	# Families by group, for what each colour would reach.
	var families_of: Dictionary = {}
	for choice: Array in choices:
		var key: String = choice[0]
		if not families_of.has(key):
			families_of[key] = []
		(families_of[key] as Array).append(choice[1])
	var order: Array = made.groups.duplicate()
	order.sort_custom(func(a: Group, b: Group) -> bool:
		if a.hidden != b.hidden:
			return a.hidden > b.hidden
		return a.order < b.order)
	var taken: Array[Group] = []
	for group: Group in order:
		if group.hidden == 0:
			continue
		var chosen: int = -1
		for pass_number: int in 2:
			var reach: Dictionary = {}
			var most: int = 0
			for code: int in offered:
				var clash: bool = false
				for other: Group in taken:
					if pass_number == 0:
						if other.colour == code or delta_e(library.color(code).rgb,
								library.color(other.colour).rgb) < GROUPS_APART:
							clash = true
					# Colours run out: shared, but never by stages side by side.
					elif other.colour == code and absi(other.order - group.order) < 2 \
							and made.mode == "stages":
						clash = true
				if clash:
					continue
				var reached: int = 0
				for members: Array in families_of.get(group.key, []):
					if _takes(library, members, bricks, code) and not touch.call(members, code):
						reached += members.size()
				reach[code] = reached
				most = maxi(most, reached)
			if most > 0:
				for code: int in offered:
					if reach.has(code) and float(reach[code]) >= GOOD_ENOUGH * float(most):
						chosen = code
						break
				break
		if chosen < 0:
			continue
		group.colour = chosen
		taken.append(group)
	# What may stand in for each: near its own colour, nearer it than any
	# other group's, and not out either.
	for group: Group in made.groups:
		if group.colour < 0:
			continue
		var own: Color = library.color(group.colour).rgb
		for code: int in offered:
			if code == group.colour or taken.any(func(g: Group) -> bool: return g.colour == code):
				continue
			var near: float = delta_e(library.color(code).rgb, own)
			if near > NEAR:
				continue
			var closest_other: float = INF
			for other: Group in taken:
				if other != group:
					closest_other = minf(closest_other, delta_e(library.color(code).rgb,
						library.color(other.colour).rgb))
			if near + 8.0 < closest_other:
				group.also.append(code)


## Whether [param code] is out for the inside: it, with the colours seen
## within [constant APART] of it, is [constant OUTSIDE_SHARE] or more of the
## outside's parts.
static func _out(library: PartLibrary, code: int, outside: Dictionary, seen_total: int) -> bool:
	if seen_total <= 0:
		return false
	var rgb: Color = library.color(code).rgb
	var near: int = 0
	for seen: int in outside:
		if seen == code or delta_e(rgb, library.color(seen).rgb) < APART:
			near += int(outside[seen])
	return float(near) >= OUTSIDE_SHARE * float(seen_total)


## Whether every part of a family was made in [param code].
static func _takes(library: PartLibrary, members: Array, bricks: Dictionary, code: int) -> bool:
	for brick_id: int in members:
		if made_in(library, (bricks[brick_id] as BrickWorld.Brick).part_id, code) <= 0.0:
			return false
	return true


## The colour a family of parts takes in its group: the group's own when
## every one of them was made in it and none touches a seen part in it,
## else the first stand-in that holds for; -1 when none was made in any,
## -2 when one was but touches a seen part in it.
static func _colour_for(library: PartLibrary, members: Array, bricks: Dictionary,
		group: Group, touch: Callable) -> int:
	var beside: bool = false
	for code: int in [group.colour] + Array(group.also):
		if not _takes(library, members, bricks, code):
			continue
		if touch.call(members, code):
			beside = true
			continue
		return code
	return -2 if beside else -1


## How surely [param part_id] was made in [param code]: 1 when it is in
## sets in it still, 0.7 when it was, 0 when the catalogue does not say so.
static func made_in(library: PartLibrary, part_id: String, code: int) -> float:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if info == null:
		return 0.0
	if info.colors_recent.has(code):
		return 1.0
	if info.colors.has(code):
		return 0.7
	return 0.0


## Carry it out, as one step of the history. Returns how many changed.
##
## With [param assemblies], every copy of a sub-assembly it touched must
## still match its fellows exactly, or Assemblies.after_edit would build
## them again from it. A family's counterparts are found by one fit of
## the copies; a symmetrical assembly fits another copy several ways, and
## the fit after_edit's search finds first may not be that one. So it is
## asked (Assemblies.unlike_copies), and any copies that would be rebuilt
## have their parts put back as they were, kept "copies_differ".
static func apply(made: Plan, world: BrickWorld, builder: Builder,
		assemblies: Assemblies = null) -> int:
	var steps: Array = []
	for brick_id: int in made.changes:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var code: int = int(made.changes[brick_id])
		if brick == null or brick.color_code == code:
			continue
		steps.append({"undo": "recolor", "brick": brick_id, "color": brick.color_code})
		world.recolor_brick(brick_id, code)
	for _round: int in 4:
		if assemblies == null or steps.is_empty():
			break
		var touched: Dictionary = {}
		for step: Dictionary in steps:
			var brick: BrickWorld.Brick = world.get_brick(int(step["brick"]))
			if brick != null:
				touched[Assemblies.path_of(brick)] = true
		var unlike: Array = assemblies.unlike_copies(touched)
		if unlike.is_empty():
			break
		var under: Dictionary = {}
		for pair: Array in unlike:
			for path: String in pair:
				for one: String in [path] + Array(assemblies.copies_of(path)):
					for brick_id: int in assemblies.ids_under(one):
						under[brick_id] = true
		var kept: Array = []
		for step: Dictionary in steps:
			var brick_id: int = int(step["brick"])
			if not under.has(brick_id):
				kept.append(step)
				continue
			world.recolor_brick(brick_id, int(step["color"]))
			made.changes.erase(brick_id)
			var group: Group = made.group_of.get(brick_id)
			if group != null:
				group.recoloured -= 1
			_keep(made, "copies_differ", 1)
		steps = kept
	builder.record(steps, "coloured %d hidden parts %s" % [steps.size(),
		MODE_WORDS.get(made.mode, made.mode)])
	return steps.size()


## The fewest parts, and sections, a model has before colouring its
## hidden parts is offered when it is built: a set that size has bags.
const OFFER_PARTS := 300
const OFFER_SECTIONS := 2


## Whether a model just built is one to offer this for: big and in
## sections (bricks' groups: the assemblies a design named). Only an
## offer; nothing is coloured unless the person says so.
static func worth_offering(world: BrickWorld, scenery: Dictionary) -> bool:
	var count: int = 0
	var sections: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		count += 1
		if not brick.group.is_empty():
			sections[brick.group] = true
	return count >= OFFER_PARTS and sections.size() >= OFFER_SECTIONS


## Why a model should not be recoloured without asking, or "": a model
## opened from a real set is that set as its designers coloured it.
static func ask_first(store: ModelStore) -> String:
	if store == null or store.from_set.is_empty():
		return ""
	return ("This is %s as the LEGO Group's designers coloured it: recolouring its hidden "
		+ "parts changes the set.") % ("a real set" if store.from_set == "set"
			else "set " + store.from_set)


# -- the line it is saved as ----------------------------------------------------


## [param text] with [param scheme] on a line after its first, in place of
## any it had; as it is for none.
static func written_into(text: String, scheme: Dictionary) -> String:
	var lines: PackedStringArray = text.split("\n")
	var kept := PackedStringArray()
	for line: String in lines:
		if not line.begins_with(META):
			kept.append(line)
	if scheme.is_empty() or (scheme.get("groups", []) as Array).is_empty():
		return "\n".join(kept)
	kept.insert(mini(1, kept.size()), META + JSON.stringify(scheme))
	return "\n".join(kept)


## The scheme a model's text carries, or {}: read at the edge and made
## precise, a line of the wrong shape is no scheme.
static func read(text: String) -> Dictionary:
	var at: int = text.find(META)
	if at < 0:
		return {}
	var end: int = text.find("\n", at)
	var raw: Variant = JSON.parse_string(text.substr(at + META.length(),
		(end if end >= 0 else text.length()) - at - META.length()))
	if not (raw is Dictionary):
		return {}
	var mode: String = str((raw as Dictionary).get("mode", ""))
	if not mode in MODES:
		return {}
	var groups: Array = []
	for one: Variant in (raw as Dictionary).get("groups", []):
		if not (one is Dictionary):
			continue
		var group: Dictionary = one
		var colour: Variant = group.get("colour")
		if not (colour is float or colour is int):
			continue
		var also: Array = []
		for code: Variant in group.get("also", []):
			if code is float or code is int:
				also.append(int(code))
		var sections: Array = []
		for name: Variant in group.get("sections", []):
			sections.append(str(name))
		if sections.is_empty():
			sections.append(str(group.get("label", "")))
		groups.append({"label": str(group.get("label", "")), "colour": int(colour),
			"also": also, "sections": sections})
	return {"mode": mode, "groups": groups} if not groups.is_empty() else {}


## The scheme's groups whose colour some part of [param world] is still
## in, for the booklet: colour code -> {label, name, rgb (#hex)}, the
## stand-ins under their group's label too.
static func live_marks(scheme: Dictionary, world: BrickWorld, library: PartLibrary,
		scenery: Dictionary = {}) -> Dictionary:
	var in_use: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if not scenery.has(brick.id):
			in_use[brick.color_code] = true
	var out: Dictionary = {}
	for group: Dictionary in scheme.get("groups", []):
		var main: int = int(group["colour"])
		for code: int in [main] + (group.get("also", []) as Array):
			if in_use.has(code):
				out[code] = {"label": str(group["label"]), "colour": main,
					"name": colour_name(library, main),
					"rgb": "#" + library.color(main).rgb.to_html(false),
					"sections": group.get("sections", [str(group["label"])])}
	return out


# -- colour ---------------------------------------------------------------------


static func colour_name(library: PartLibrary, code: int) -> String:
	var colour: PartLibrary.BrickColor = library.colors.get(code)
	return colour.name if colour != null else "colour %d" % code


## CIE L*a*b* of an sRGB colour (D65).
static func lab(colour: Color) -> Vector3:
	var linear: Array[float] = []
	for channel: float in [colour.r, colour.g, colour.b]:
		linear.append(channel / 12.92 if channel <= 0.04045
			else pow((channel + 0.055) / 1.055, 2.4))
	var x: float = (0.4124 * linear[0] + 0.3576 * linear[1] + 0.1805 * linear[2]) / 0.95047
	var y: float = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
	var z: float = (0.0193 * linear[0] + 0.1192 * linear[1] + 0.9505 * linear[2]) / 1.08883
	var f: Callable = func(t: float) -> float:
		return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	var fx: float = f.call(x)
	var fy: float = f.call(y)
	var fz: float = f.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func delta_e(a: Color, b: Color) -> float:
	return lab(a).distance_to(lab(b))


## A colour that reads as a mark: strong and not dark.
static func vivid(colour: Color) -> bool:
	var at: Vector3 = lab(colour)
	return Vector2(at.y, at.z).length() >= CODED_CHROMA and at.x >= CODED_LIGHTNESS


static func chroma(colour: Color) -> float:
	var at: Vector3 = lab(colour)
	return Vector2(at.y, at.z).length()
