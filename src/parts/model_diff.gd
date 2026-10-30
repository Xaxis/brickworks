## What changed between a save of a model (ModelVersions) and the model on
## the baseplate, part by part: what was added, what was taken away, what was
## moved or turned, and what was painted another colour. File, Versions…'s
## Compare draws it (CompareView), and open_model reads it for a session.
##
## The gallery says what changed between two versions of a shared model
## (api/_versions.js) by counting each part in each colour, its place to the
## hundredth of an LDU: right for "4 parts added in step 12", and no use for
## a picture, where a part moved a stud must be one part drawn amber, not one
## taken away and one put down. So the parts are matched here, by part,
## colour and place, the fewest changes first:
##
##   1. the same part in the same colour, under [constant NEAR] LDU from
##      where it was and turned the same way, is unchanged;
##   2. of the rest, the same part where one stood, turned the same way, in
##      another colour, was recoloured;
##   3. of the rest, the same part in the same colour anywhere else was
##      moved or turned: as many as there are of it on both sides, each
##      paired with the nearest, so ten 1 x 1 bricks in a row with one moved
##      to the end is that one moved, not one taken away and one put down;
##   4. what is left was added, or taken away.
##
## Both sides are read as the app opens a file (ModelStore._open_into):
## sub-models placed in the model, a retired number as the part it became, a
## mirrored copy's parts in their other hand; and both in the file's own
## coordinates, the model on the baseplate less the lift it was opened with,
## so a model another tool drew in the air is not all moved. Pure but for
## the library it reads parts from.
class_name ModelDiff
extends RefCounted

## A part this near where it was, LDU, has not moved.
const NEAR := 0.5
## ...and turned the same way when no axis of it is further than this off.
const SAME_TURN := 0.01
## Moved parts of one part and colour are paired nearest first while there
## are no more pairs than this to weigh; past it, in order along the model.
const PAIRS_WEIGHED := 40000

const ADDED := "added"
const REMOVED := "removed"
const MOVED := "moved"
const RECOLOURED := "recoloured"
## In the order the counts are said and the changes stepped through.
const KINDS: Array[String] = [ADDED, REMOVED, MOVED, RECOLOURED]


## One part, on one side.
class Part extends RefCounted:
	var part_id: String
	var colour: int
	## Where it stands, in the file's coordinates (LDU, Godot's axes).
	var at: Transform3D
	## The brick on the baseplate it is; 0 for a part of the save, or one
	## of the model's still on its way (ModelStore.awaited).
	var id: int = 0
	## Its sub-assembly (Assemblies.path_of); "" for the model itself.
	var path: String = ""

	func _init(part: String, code: int, place: Transform3D, brick: int = 0,
			in_path: String = "") -> void:
		part_id = part
		colour = code
		at = place
		id = brick
		path = in_path


## One change: [member now] null for a part taken away, [member was] null
## for one added.
class Change extends RefCounted:
	var kind: String
	var now: Part = null
	var was: Part = null
	## Moved: turned as well as, or rather than, moved.
	var turned: bool = false
	## Moved: how far, LDU.
	var by: float = 0.0


## Every change, by kind (ADDED, REMOVED, MOVED, RECOLOURED) and within each
## from the bottom of the model up.
var changes: Array[Change] = []
## The bricks on the baseplate that did not change: id -> true.
var unchanged: Dictionary = {}
## How many parts each side had.
var parts_was: int = 0
var parts_now: int = 0
## How long matching them took, ms.
var matched_ms: float = 0.0


## How many changes of [param kind].
func count(kind: String) -> int:
	var n: int = 0
	for change: Change in changes:
		if change.kind == kind:
			n += 1
	return n


## {"added": n, "removed": n, "moved": n, "recoloured": n}.
func counts() -> Dictionary:
	var out: Dictionary = {}
	for kind: String in KINDS:
		out[kind] = 0
	for change: Change in changes:
		out[change.kind] = int(out[change.kind]) + 1
	return out


## "3 added, 2 removed, 2 moved, 1 recoloured", or "no change".
func summary() -> String:
	if changes.is_empty():
		return "no change"
	var said := PackedStringArray()
	var counted: Dictionary = counts()
	for kind: String in KINDS:
		if int(counted[kind]) > 0:
			said.append("%d %s" % [int(counted[kind]), kind])
	return ", ".join(said)


## What changed from [param was] to [param now] (Parts each).
static func between(was: Array, now: Array) -> ModelDiff:
	var began: int = Time.get_ticks_usec()
	var diff := ModelDiff.new()
	diff.parts_was = was.size()
	diff.parts_now = now.size()
	var left_was: Array = was.duplicate()
	var left_now: Array = now.duplicate()
	var pairs: Array = []
	# 1. Unchanged: the same part and colour where it was.
	_pair_in_place(left_was, left_now, true, pairs)
	for pair: Array in pairs:
		var kept: Part = pair[1]
		if kept.id != 0:
			diff.unchanged[kept.id] = true
	# 2. Recoloured: the same part where one was, in another colour.
	pairs = []
	_pair_in_place(left_was, left_now, false, pairs)
	var recoloured: Array[Change] = []
	for pair: Array in pairs:
		var change := Change.new()
		change.kind = RECOLOURED
		change.was = pair[0]
		change.now = pair[1]
		recoloured.append(change)
	# 3. Moved or turned: the same part and colour, the nearest paired.
	var moved: Array[Change] = []
	for pair: Array in _pair_anywhere(left_was, left_now):
		var change := Change.new()
		change.kind = MOVED
		change.was = pair[0]
		change.now = pair[1]
		change.by = change.was.at.origin.distance_to(change.now.at.origin)
		change.turned = not _same_turn(change.was.at.basis, change.now.at.basis)
		moved.append(change)
	# 4. What is left was put down, or taken away.
	var added: Array[Change] = []
	for part: Part in left_now:
		if part != null:
			var change := Change.new()
			change.kind = ADDED
			change.now = part
			added.append(change)
	var removed: Array[Change] = []
	for part: Part in left_was:
		if part != null:
			var change := Change.new()
			change.kind = REMOVED
			change.was = part
			removed.append(change)
	for list: Array in [added, removed, moved, recoloured]:
		list.sort_custom(_lower)
		diff.changes.append_array(list)
	diff.matched_ms = (Time.get_ticks_usec() - began) / 1000.0
	return diff


## Bottom up, then along x and z: the order a change is stepped to in.
static func _lower(a: Change, b: Change) -> bool:
	var p: Vector3 = (a.now if a.now != null else a.was).at.origin
	var q: Vector3 = (b.now if b.now != null else b.was).at.origin
	# Godot's y is up: the higher a part, the larger its y.
	if not is_equal_approx(p.y, q.y):
		return p.y < q.y
	if not is_equal_approx(p.x, q.x):
		return p.x < q.x
	return p.z < q.z


static func _same_turn(a: Basis, b: Basis) -> bool:
	return a.x.distance_to(b.x) <= SAME_TURN and a.y.distance_to(b.y) <= SAME_TURN \
		and a.z.distance_to(b.z) <= SAME_TURN


## The cell a place is in, a whole LDU.
static func _cell(at: Vector3) -> Vector3i:
	return Vector3i(roundi(at.x), roundi(at.y), roundi(at.z))


## Pairs a part of [param was] with one of [param now] of the same part,
## standing where it stood and turned the same way: in the same colour when
## [param same_colour], else in another. Each pair, [was, now], appended to
## [param pairs], and both taken out of their lists (set to null). Looked
## up by the whole LDU each stands in, and the cells round it only for a
## part with none of its kind in its own: nearly every part of a model is
## found in one look.
static func _pair_in_place(was: Array, now: Array, same_colour: bool, pairs: Array) -> void:
	var at: Dictionary = {}  ## key -> Array of indexes into was
	for n: int in was.size():
		var part: Part = was[n]
		if part == null:
			continue
		var key: String = _key(part, _cell(part.at.origin), same_colour)
		if not at.has(key):
			at[key] = []
		(at[key] as Array).append(n)
	for m: int in now.size():
		var part: Part = now[m]
		if part == null:
			continue
		var cell: Vector3i = _cell(part.at.origin)
		var found: int = _find_in(at, _key(part, cell, same_colour), was, part, same_colour)
		if found < 0:
			for dx: int in [-1, 0, 1]:
				for dy: int in [-1, 0, 1]:
					for dz: int in [-1, 0, 1]:
						if found < 0 and (dx != 0 or dy != 0 or dz != 0):
							found = _find_in(at, _key(part, cell + Vector3i(dx, dy, dz), same_colour),
								was, part, same_colour)
		if found >= 0:
			pairs.append([was[found], part])
			was[found] = null
			now[m] = null


static func _key(part: Part, cell: Vector3i, same_colour: bool) -> String:
	if same_colour:
		return "%s|%d|%d|%d|%d" % [part.part_id, part.colour, cell.x, cell.y, cell.z]
	return "%s|%d|%d|%d" % [part.part_id, cell.x, cell.y, cell.z]


## The index in [param was] of a part under [param key] that [param part]
## stands where, turned as, and in the colour asked: -1 for none.
static func _find_in(at: Dictionary, key: String, was: Array, part: Part,
		same_colour: bool) -> int:
	var found: Array = at.get(key, [])
	for n: int in found:
		var other: Part = was[n]
		if other == null:
			continue
		if (other.colour == part.colour) != same_colour:
			continue
		if other.at.origin.distance_to(part.at.origin) < NEAR \
				and _same_turn(other.at.basis, part.at.basis):
			return n
	return -1


## Of what is left, each part of [param was] paired with one of [param now]
## of the same part and colour, nearest first, as many as both sides have:
## [[was, now], …], each taken out of its list.
static func _pair_anywhere(was: Array, now: Array) -> Array:
	var groups: Dictionary = {}  ## part|colour -> [indexes into was, indexes into now]
	for n: int in was.size():
		if was[n] != null:
			var key: String = "%s|%d" % [(was[n] as Part).part_id, (was[n] as Part).colour]
			if not groups.has(key):
				groups[key] = [[], []]
			(groups[key][0] as Array).append(n)
	for m: int in now.size():
		if now[m] != null:
			var key: String = "%s|%d" % [(now[m] as Part).part_id, (now[m] as Part).colour]
			if groups.has(key):
				(groups[key][1] as Array).append(m)
	var out: Array = []
	for key: String in groups:
		var olds: Array = groups[key][0]
		var news: Array = groups[key][1]
		if olds.is_empty() or news.is_empty():
			continue
		if olds.size() * news.size() <= PAIRS_WEIGHED:
			# Every pair weighed, and the nearest taken first: sorted by the
			# engine, [distance, was, now] each.
			var weighed: Array = []
			for n: int in olds:
				for m: int in news:
					weighed.append([(was[n] as Part).at.origin.distance_squared_to(
						(now[m] as Part).at.origin), n, m])
			weighed.sort()
			for one: Array in weighed:
				var n: int = one[1]
				var m: int = one[2]
				if was[n] != null and now[m] != null:
					out.append([was[n], now[m]])
					was[n] = null
					now[m] = null
		else:
			# Too many to weigh every pair: in order along the model.
			var olds_along: Array = _along(was, olds)
			var news_along: Array = _along(now, news)
			for k: int in mini(olds_along.size(), news_along.size()):
				out.append([was[olds_along[k]], now[news_along[k]]])
				was[olds_along[k]] = null
				now[news_along[k]] = null
	return out


## The indexes [param of] into [param parts], in order along x, then z, then y.
static func _along(parts: Array, of: Array) -> Array:
	var keyed: Array = []
	for n: int in of:
		var at: Vector3 = (parts[n] as Part).at.origin
		keyed.append([at.x, at.z, at.y, n])
	keyed.sort()
	return keyed.map(func(one: Array) -> int: return int(one[3]))


# -- the two sides --------------------------------------------------------------


## The parts a save's [param text] puts down, as the app opens it, in the
## file's coordinates; only those in the sub-assembly [param inside] when it
## is not "" (Assemblies.within). Empty for text that is not a model.
static func parts_of_text(text: String, library: PartLibrary, inside: String = "") -> Array:
	var out: Array = []
	var model: LdrModel = LdrModel.parse(text, "version")
	if model == null:
		return out
	for placement: LdrModel.Placement in model.flatten(library.parts):
		# As ModelStore._open_into puts a file's parts down, so a part the
		# baseplate holds as another number is the same part here.
		placement.part_id = ModelStore.studio_part(placement.part_id, library)
		if placement.mirrored:
			Assemblies.unmirror(placement, library)
		var real: String = library.resolve(placement.part_id)
		if real != placement.part_id:
			placement.transform = placement.transform * library.moved_by(placement.part_id)
			placement.part_id = real
		var colour: int = library.current_colour(placement.part_id)
		if colour >= 0:
			placement.part_id = library.current(placement.part_id)
			placement.color_code = colour
		var path: String = Assemblies.path_from(placement.group, placement.unit)
		if Assemblies.within(path, inside):
			out.append(Part.new(placement.part_id, placement.color_code, placement.transform, 0,
				path))
	return out


## The model on the baseplate as its file would have it: every brick but the
## baseplate's ([param scenery]), where it stands in the model as built
## (BrickWorld.home_of) less [param lift], and the parts still on their way
## ([param awaited], LdrModel.Placements, already lifted); only those inside
## [param inside] when it is not "".
static func parts_of_world(world: BrickWorld, scenery: Dictionary, lift: Vector3,
		awaited: Array = [], inside: String = "") -> Array:
	var out: Array = []
	var back := Transform3D(Basis.IDENTITY, -lift)
	for item: Variant in world.bricks():
		var brick: BrickWorld.Brick = item
		if scenery.has(brick.id):
			continue
		var path: String = Assemblies.path_of(brick)
		if Assemblies.within(path, inside):
			out.append(Part.new(brick.part_id, brick.color_code, back * world.home_of(brick),
				brick.id, path))
	for item: Variant in awaited:
		var placement: LdrModel.Placement = item
		var path: String = Assemblies.path_from(placement.group, placement.unit)
		if Assemblies.within(path, inside):
			out.append(Part.new(placement.part_id, placement.color_code,
				back * placement.transform, 0, path))
	return out
