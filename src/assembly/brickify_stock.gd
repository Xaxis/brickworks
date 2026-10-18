## A Brickify build laid from what the person owns: "create designs using
## only parts which are on hand" (docs/BRICKIFY.md, unit 7).
##
## The build is laid as ever, and then each part drawn from the collection
## (CollectionStore.on_hand: part and colour -> how many, sets expanded), in
## the order a builder sorting a pile would take them:
##   1. its own part in its own colour (or the other moulding of it,
##      Collection.family_of), the parts that show first, since a part
##      inside may be any colour;
##   2. the same part in the nearest colour on hand (CIEDE2000, as Brickify
##      matches colours), what shows first and nearest first;
##   3. two smaller parts of the same kind that make its footprint
##      (Collection._splits: a 1 x 4 from two 1 x 2s), in its colour or the
##      nearest on hand, kept only if the build is still one piece and passes
##      the check;
## and what is still short is said, by part and colour. A part inside the
## build costs nothing in another colour; one that shows costs its colour's
## difference, which is what the share drawn costs in colour.
class_name BrickifyStock
extends RefCounted

## How each part was drawn.
const SHORT := 0
const AS_IT_IS := 1
const BY_COLOUR := 2
const BY_SIZE := 3
## Rounds of taking back the splits near what came apart, before all of them.
const SPLIT_ROUNDS := 3
## The most a part that shows may differ from its own colour (CIEDE2000) and
## still stand in for it: about white against light bluish grey or tan. A
## white bunny patched in yellow and green is not the model, and the part is
## better said short; inside, any colour does. INF takes any (the probe
## measures both).
static var shown_most: float = 16.0


## Draw [param model]'s parts from [param on_hand], changing the colours and
## the parts it lays as said above (it is the build that goes down). What it
## came to: {"parts", "drawn", "as_it_is", "by_colour", "by_size",
## "short": [[part, colour, count]], "short_pieces", "short_lots",
## "shown", "de_shown" (mean CIEDE2000 over the parts that show, unchanged
## ones counted as nothing), "de_changed" (over those that changed),
## "splits_undone", "ms"}.
static func draw(model: Assistant.Model, on_hand: Dictionary, checker: Assistant) -> Dictionary:
	var began: int = Time.get_ticks_msec()
	var library: PartLibrary = checker.library
	var pool: Dictionary = {}
	for key: String in on_hand:
		if int(on_hand[key]) > 0:
			pool[key] = int(on_hand[key])
	var count: int = model.placements.size()
	var shown: PackedByteArray = shows(model, checker)
	var how := PackedByteArray()
	how.resize(count)
	var was := PackedInt32Array()
	was.resize(count)
	for index: int in count:
		was[index] = (model.placements[index] as Assistant.Placement).color
	# What shows first.
	var order: Array = range(count)
	order.sort_custom(func(a: int, b: int) -> bool:
		return shown[a] > shown[b] if shown[a] != shown[b] else a < b)
	# The pool by part, its mouldings together: family -> keys.
	var by_family: Dictionary = {}
	for key: String in pool:
		var family: String = Collection.family_of(Collection.part_of(key))
		if not by_family.has(family):
			by_family[family] = []
		(by_family[family] as Array).append(key)

	# 1. As it is, or in its other moulding.
	for index: int in order:
		var placement: Assistant.Placement = model.placements[index]
		var key: String = Collection.key_of(placement.part, placement.color, library)
		if _take(pool, key):
			how[index] = AS_IT_IS
			continue
		var family: String = Collection.family_of(Collection.part_of(key))
		for other: String in by_family.get(family, []):
			if Collection.colour_of(other) == Collection.colour_of(key) and _take(pool, other):
				how[index] = AS_IT_IS
				break

	# 2. The same part in the nearest colour on hand.
	var labs: Dictionary = {}
	for index: int in order:
		if how[index] != SHORT:
			continue
		var placement: Assistant.Placement = model.placements[index]
		var key: String = Collection.key_of(placement.part, placement.color, library)
		var family: String = Collection.family_of(Collection.part_of(key))
		var best: String = ""
		var gap: float = INF
		for other: String in by_family.get(family, []):
			if int(pool.get(other, 0)) <= 0:
				continue
			var d: float = _de(library, labs, placement.color, Collection.colour_of(other))
			if shown[index] == 1 and d > shown_most:
				continue
			if d < gap:
				gap = d
				best = other
		if best.is_empty() or not _take(pool, best):
			continue
		placement.color = Collection.colour_of(best)
		how[index] = BY_COLOUR

	# 3. Two smaller parts that make its footprint.
	var sizes: Dictionary = Collection._sizes(library)
	var split: Array = []    ## [index, the placement it was, its second half, keys taken]
	var halves: Dictionary = {}    ## second half -> [the colour laid, whether it shows]
	for index: int in order:
		if how[index] != SHORT:
			continue
		var placement: Assistant.Placement = model.placements[index]
		if placement.face != "up":
			continue
		var made: Array = _split(placement, library, sizes, pool, labs,
			shown_most if shown[index] == 1 else INF)
		if made.is_empty():
			continue
		model.placements[index] = made[0]
		model.placements.append(made[1])
		how[index] = BY_SIZE
		halves[made[1]] = [was[index], shown[index]]
		split.append([index, placement, made[1], made[2]])
	# Kept only while it holds: two halves of a brick bridge less than it. What
	# came apart or floats is found, and the splits near it taken back, a few
	# rounds; then all of them.
	var undone: int = 0
	var checks: int = 0
	for round: int in SPLIT_ROUNDS + 1:
		if split.is_empty():
			break
		var report: Dictionary = checker._check(model, true, false, false, false)
		checks += 1
		if bool(report.get("ok", false)) and int(report.get("pieces", 1)) <= 1:
			break
		var trouble: Array = []
		for index: Variant in (report.get("floating", []) as Array) \
				+ (report.get("unheld", []) as Array):
			trouble.append(model.placements[int(index)])
		var pieces: Array = report.get("each_piece", [])
		pieces.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
		for piece: Array in pieces.slice(1):
			for index: Variant in piece:
				trouble.append(model.placements[int(index)])
		var back: Array = []
		for one: Array in split:
			if round < SPLIT_ROUNDS and not _near_any(one[1], trouble):
				continue
			back.append(one)
		if back.is_empty():
			back = split.duplicate()
		for one: Array in back:
			model.placements[int(one[0])] = one[1]
			how[int(one[0])] = SHORT
			model.placements.erase(one[2])
			halves.erase(one[2])
			for key: String in one[3]:
				pool[key] = int(pool.get(key, 0)) + 1
			split.erase(one)
			undone += 1
	for placement: Assistant.Placement in model.placements.slice(count):
		how.append(BY_SIZE)
		was.append(int(halves[placement][0]))
		shown.append(int(halves[placement][1]))

	# What it came to.
	var tally: Dictionary = {AS_IT_IS: 0, BY_COLOUR: 0, BY_SIZE: 0, SHORT: 0}
	var short: Dictionary = {}    ## key -> pieces
	var de_sum: float = 0.0
	var changed: int = 0
	var showing: int = 0
	for index: int in model.placements.size():
		tally[how[index]] = int(tally[how[index]]) + 1
		var placement: Assistant.Placement = model.placements[index]
		if how[index] == SHORT:
			var key: String = Collection.key_of(placement.part, placement.color, library)
			short[key] = int(short.get(key, 0)) + 1
		if shown[index] == 1:
			showing += 1
			if placement.color != was[index]:
				de_sum += _de(library, labs, was[index], placement.color)
				changed += 1
	var rows: Array = []
	var short_pieces: int = 0
	for key: String in short:
		rows.append([Collection.part_of(key), Collection.colour_of(key), int(short[key])])
		short_pieces += int(short[key])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2]))
	var parts: int = model.placements.size()
	return {"parts": parts, "drawn": parts - int(tally[SHORT]),
		"as_it_is": int(tally[AS_IT_IS]), "by_colour": int(tally[BY_COLOUR]),
		"by_size": int(tally[BY_SIZE]), "short": rows, "short_pieces": short_pieces,
		"short_lots": rows.size(), "shown": showing,
		"de_shown": de_sum / float(maxi(showing, 1)),
		"de_changed": de_sum / float(maxi(changed, 1)), "changed_shown": changed,
		"splits_undone": undone, "checks": checks, "ms": Time.get_ticks_msec() - began}


## What [method draw] came to, in words for the panel and the session.
static func said(stock: Dictionary) -> String:
	var parts: int = int(stock.get("parts", 0))
	var out: String = "laid from your collection: %s of its %s parts are yours" % [
		Brickify._comma(int(stock.get("drawn", 0))), Brickify._comma(parts)]
	var ways := PackedStringArray()
	if int(stock.get("by_colour", 0)) > 0:
		ways.append("%s in another colour" % Brickify._comma(int(stock["by_colour"])))
	if int(stock.get("by_size", 0)) > 0:
		ways.append("%s as two smaller parts" % Brickify._comma(int(stock["by_size"])))
	if not ways.is_empty():
		out += " (%s)" % ", ".join(ways)
	if int(stock.get("changed_shown", 0)) > 0:
		out += ", a colour difference of %.1f (CIEDE2000) where it shows" % float(
			stock.get("de_shown", 0.0))
	var short: int = int(stock.get("short_pieces", 0))
	out += (", nothing short" if short == 0 else ", %s parts in %d lots short" % [
		Brickify._comma(short), int(stock.get("short_lots", 0))])
	return out


## The parts that show: any cell of its box beside air reached from outside
## the build, on a grid of studs and plates. Per placement, 1 or 0.
static func shows(model: Assistant.Model, checker: Assistant) -> PackedByteArray:
	var library: PartLibrary = checker.library
	var count: int = model.placements.size()
	var out := PackedByteArray()
	out.resize(count)
	var boxes: Array = []
	var low := Vector3i(0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF)
	var high := -low
	for index: int in count:
		var placement: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			boxes.append(null)
			continue
		var box: AABB = checker._transform(placement, part) * part.bounds
		var a := Vector3i(floori(box.position.x / 20.0 + 0.05), floori(box.position.y / 8.0 + 0.05),
			floori(box.position.z / 20.0 + 0.05))
		var b := Vector3i(ceili(box.end.x / 20.0 - 0.05), ceili(box.end.y / 8.0 - 0.05),
			ceili(box.end.z / 20.0 - 0.05))
		b = Vector3i(maxi(b.x, a.x + 1), maxi(b.y, a.y + 1), maxi(b.z, a.z + 1))
		boxes.append([a, b])
		low = Vector3i(mini(low.x, a.x), mini(low.y, a.y), mini(low.z, a.z))
		high = Vector3i(maxi(high.x, b.x), maxi(high.y, b.y), maxi(high.z, b.z))
	if low.x == 0x7FFFFFFF:
		return out
	low -= Vector3i.ONE
	high += Vector3i.ONE
	var size: Vector3i = high - low
	var filled := PackedByteArray()
	filled.resize(size.x * size.y * size.z)
	var at := func(p: Vector3i) -> int:
		return ((p.x - low.x) * size.y + (p.y - low.y)) * size.z + (p.z - low.z)
	for one: Variant in boxes:
		if one == null:
			continue
		var a: Vector3i = one[0]
		var b: Vector3i = one[1]
		for x: int in range(a.x, b.x):
			for y: int in range(a.y, b.y):
				for z: int in range(a.z, b.z):
					filled[at.call(Vector3i(x, y, z))] = 1
	# The air outside: everything empty reached from the grid's corner.
	var outside := PackedByteArray()
	outside.resize(filled.size())
	var queue := PackedInt32Array([0])
	outside[0] = 1
	var head: int = 0
	var step: Array = [size.y * size.z, size.z, 1]
	while head < queue.size():
		var cell: int = queue[head]
		head += 1
		var x: int = cell / (size.y * size.z)
		var y: int = (cell / size.z) % size.y
		var z: int = cell % size.z
		var coords: Array = [x, y, z]
		var dims: Array = [size.x, size.y, size.z]
		for axis: int in 3:
			for way: int in [-1, 1]:
				var c: int = int(coords[axis]) + way
				if c < 0 or c >= int(dims[axis]):
					continue
				var next: int = cell + way * int(step[axis])
				if outside[next] == 0 and filled[next] == 0:
					outside[next] = 1
					queue.append(next)
	for index: int in count:
		var one: Variant = boxes[index]
		if one == null:
			continue
		var a: Vector3i = one[0]
		var b: Vector3i = one[1]
		var seen: bool = false
		for x: int in range(a.x - 1, b.x + 1):
			for y: int in range(a.y - 1, b.y + 1):
				for z: int in range(a.z - 1, b.z + 1):
					# Beside it, not inside or corner to corner.
					var inside: int = int(x >= a.x and x < b.x) + int(y >= a.y and y < b.y) \
						+ int(z >= a.z and z < b.z)
					if inside == 2 and outside[at.call(Vector3i(x, y, z))] == 1:
						seen = true
						break
				if seen:
					break
			if seen:
				break
		out[index] = 1 if seen else 0
	return out


## Whether [param placement] is within a few studs of any of [param others]:
## a split under or beside what came apart.
static func _near_any(placement: Assistant.Placement, others: Array) -> bool:
	for other: Assistant.Placement in others:
		if absf(other.x - placement.x) <= 4.0 and absf(other.z - placement.z) <= 4.0 \
				and absf(other.y - placement.y) <= 6.0:
			return true
	return false


static func _take(pool: Dictionary, key: String) -> bool:
	if int(pool.get(key, 0)) <= 0:
		return false
	pool[key] = int(pool[key]) - 1
	return true


static func _de(library: PartLibrary, labs: Dictionary, one: int, other: int) -> float:
	if one == other:
		return 0.0
	for code: int in [one, other]:
		if not labs.has(code):
			var colour: PartLibrary.BrickColor = library.color(code)
			labs[code] = HiddenColours.lab(colour.rgb) if colour != null else Vector3.ZERO
	return Brickify.de2000(labs[one], labs[other])


## [param placement] as two smaller parts of its kind on hand, in its colour
## or the nearest: [first, second, keys taken], or [] when none are.
static func _split(placement: Assistant.Placement, library: PartLibrary, sizes: Dictionary,
		pool: Dictionary, labs: Dictionary, most: float) -> Array:
	var part: String = library.resolve(placement.part)
	var whole: Lbm.PartMesh = library.mesh_for(part)
	if whole == null:
		return []
	var turned: AABB = Transform3D(BrickLattice.basis_for("up", placement.rot), Vector3.ZERO) * whole.bounds
	var long_x: bool = turned.size.x >= turned.size.z
	for pair: Array in Collection._splits(part, sizes):
		var a: String = pair[0]
		var b: String = pair[1]
		# Its colour if both are on hand in it, else the nearest both are.
		var colour: int = -1
		var gap: float = INF
		var colours: Dictionary = {placement.color: true}
		for key: String in pool:
			if Collection.part_of(key) == a:
				colours[Collection.colour_of(key)] = true
		for code: int in colours:
			var key_a: String = Collection.key_of(a, code, library)
			var key_b: String = Collection.key_of(b, code, library)
			var need_a: int = 2 if a == b else 1
			if int(pool.get(key_a, 0)) < need_a or (a != b and int(pool.get(key_b, 0)) < 1):
				continue
			var d: float = _de(library, labs, placement.color, code)
			if d > most:
				continue
			if d < gap:
				gap = d
				colour = code
		if colour < 0:
			continue
		var made_a: Assistant.Placement = _half(placement, a, colour, Vector2.ZERO, long_x,
			library)
		var mesh_a: Lbm.PartMesh = library.mesh_for(a)
		if made_a == null or mesh_a == null:
			continue
		var box_a: AABB = Transform3D(BrickLattice.basis_for("up", made_a.rot), Vector3.ZERO) * mesh_a.bounds
		var size_a := Vector2(roundf(box_a.size.x / 20.0), roundf(box_a.size.z / 20.0))
		var size_whole := Vector2(roundf(turned.size.x / 20.0), roundf(turned.size.z / 20.0))
		# The second beside the first, along whichever way the first falls short.
		var shift := Vector2(size_a.x, 0.0) if size_a.y >= size_whole.y else Vector2(0.0, size_a.y)
		var made_b: Assistant.Placement = _half(placement, b, colour, shift, long_x, library)
		if made_b == null:
			continue
		var taken := PackedStringArray([Collection.key_of(a, colour, library),
			Collection.key_of(b, colour, library)])
		for key: String in taken:
			_take(pool, key)
		return [made_a, made_b, taken]
	return []


## One half of a split part: [param part] at [param placement]'s corner
## shifted by [param shift] studs, its length the same way as the whole's.
static func _half(placement: Assistant.Placement, part: String, colour: int, shift: Vector2,
		long_x: bool, library: PartLibrary) -> Assistant.Placement:
	var mesh: Lbm.PartMesh = library.mesh_for(part)
	if mesh == null:
		return null
	var rot: int = 0
	for turn: int in 2:
		var box: AABB = Transform3D(BrickLattice.basis_for("up", turn), Vector3.ZERO) * mesh.bounds
		if (box.size.x >= box.size.z) == long_x:
			rot = turn
			break
	return Assistant.Placement.from_dict({"part": part, "color": colour,
		"x": placement.x + shift.x, "y": placement.y, "z": placement.z + shift.y, "rot": rot})
