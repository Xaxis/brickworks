## How a model is built, against how real sets of its kind are.
##
## Every measure before this was of what a model is made of — how many
## different parts, colours, how big. None was of how it is built, and
## the owner's verdict on an Orthanc that held together and measured
## fine on those was that it "still ultimately sucked": too symmetric,
## functional square bricks studs-up, nothing used creatively. Measured
## against real fantasy sets (tools/style.py, over LDraw's official
## models), that Orthanc was 0% sideways where they are a median 19%, 0%
## at an angle against 27%, 57% plain bricks and plates against 28%, and
## 88% mirror-symmetric against 31%. Telling the design in words changed
## nothing; a rebuild with the craft guidance came out 0%, 0% and 77%.
##
## So it is measured, the way variety is, and said only on the tails:
## below the tenth percentile of real sets of the kind, or above the
## ninetieth, so the advice costs one real set in ten at most.
##
## The rules for what kind a part is live in tools/style.py, which
## writes every part's kinds into style_norms.json; this reads them
## rather than keeping a second copy that would drift.
class_name Style
extends RefCounted

## Where the norms are: packed for the web build, which leaves
## assets/generated out of the export, and generated on the desktop.
const NORMS: Array[String] = ["res://assets/generated/style_norms.json",
	"res://assets/web/style_norms.json"]
## Real sets are only measured from this size, so a model is too.
const LEAST := 100
## A part's studs point up when within this of straight up, as in
## tools/style.py (cos 20 degrees).
const UP_COS := 0.9397
## Turned by other than a quarter turn, when any axis is further than
## this from square, as in tools/style.py.
const SQUARE := 0.02
## How close a mirrored part has to land, in LDU, as in tools/style.py.
const TOLERANCE := 4.0

static var _norms: Dictionary = {}
static var _loaded: bool = false


static func norms() -> Dictionary:
	if not _loaded:
		_loaded = true
		for path: String in NORMS:
			if not FileAccess.file_exists(path):
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_norms = parsed
				break
	return _norms


## A part's kinds as tools/style.py names them, in letters: c curve,
## s slope, n a part that turns studs sideways, a a part that lets
## another sit at an angle, t texture, i tile, o organic, p plain, and u
## when its studs say which way is up. "" for what is not a building
## part — a figure, a sticker — and unknown parts.
static func kinds_of(part: String) -> String:
	var kinds: Dictionary = norms().get("part_kinds", {}) as Dictionary
	return str(kinds.get(part, ""))


## Which real sets a brief is to be compared with.
##
## By what the brief says, because the brief is the only thing that
## knows a tower is Orthanc and not an office block. Castles go with the
## fantasy sets: twelve of the fourteen castles in the repository are
## from 1984-93 and build almost nothing sideways, which is not the bar.
static func group_for(brief: String) -> String:
	var said: String = brief.to_lower()
	var groups: Dictionary = norms().get("groups", {}) as Dictionary
	for pair: Array in [
		[["orthanc", "mordor", "rivendell", "hobbit", "lord of the rings",
			"wizard", "dragon", "elf", "elven", "dwarf", "fantasy", "castle",
			"knight", "medieval", "fortress", "keep", "dungeon", "ruin",
			"tolkien", "isengard", "sauron", "magic"], "fantasy"],
		[["spaceship", "starship", "space", "rocket", "star wars", "x-wing",
			"tie fighter", "shuttle", "satellite", "planet"], "space"],
		[["car", "truck", "train", "locomotive", "bus", "plane", "aircraft",
			"helicopter", "boat", "ship", "tractor", "motorbike", "vehicle"],
			"vehicles"],
		[["skyline", "landmark", "architecture", "cathedral", "skyscraper"],
			"architecture"],
		[["house", "shop", "station", "street", "town", "city", "building",
			"cafe", "bakery", "school", "hotel", "modular"], "buildings_since_2010"],
	]:
		for word: String in pair[0]:
			if said.contains(word) and groups.has(pair[1]):
				return str(pair[1])
	return "since_2010" if groups.has("since_2010") else ""


## The measures of some parts, each [part id, colour, Transform3D of
## the part, its box in its own LDU]: the shares of building parts that
## point their studs other than up, that are turned off the square, and
## of each kind, and the share with a mirror partner.
static func measure(parts: Array) -> Dictionary:
	var counted: int = 0
	var tally: Dictionary = {"snot": 0, "angled": 0, "curve": 0, "slope": 0,
		"plain": 0, "texture": 0, "shaped": 0}
	var boxes: Array = []
	for entry: Array in parts:
		var part: String = entry[0]
		var kinds: String = kinds_of(part)
		if kinds.is_empty():
			continue
		counted += 1
		var at: Transform3D = entry[2]
		var basis: Basis = at.basis.orthonormalized()
		var turned: bool = _angled(basis)
		if turned:
			tally["angled"] += 1
		if kinds.contains("u") and basis.y.y < UP_COS:
			tally["snot"] += 1
		if kinds.contains("c"):
			tally["curve"] += 1
		elif kinds.contains("s"):
			tally["slope"] += 1
		if kinds.contains("p"):
			tally["plain"] += 1
		if kinds.contains("t"):
			tally["texture"] += 1
		if kinds.contains("c") or kinds.contains("s") or turned:
			tally["shaped"] += 1
		var own: AABB = entry[3]
		var box: AABB = at * own
		boxes.append([part, int(entry[1]), box.get_center(), box.size / 2.0])
	var found: Dictionary = {"parts": counted}
	if counted == 0:
		return found
	for key: String in tally:
		found[key] = float(tally[key]) / float(counted)
	found["symmetry"] = _symmetry(boxes)
	return found


static func _angled(basis: Basis) -> bool:
	for column: Vector3 in [basis.x, basis.y, basis.z]:
		for value: float in [column.x, column.y, column.z]:
			if minf(absf(value), absf(absf(value) - 1.0)) > SQUARE:
				return true
	return false


## The share of parts with a partner mirrored across the best vertical
## plane, as tools/style.py finds it: pairs of like parts level with
## each other vote for the plane halfway between them, and the middle of
## the model is tried too. The middle alone was tried first, and read
## the shipped castle as 0% mirrored where the tool reads 55%: a plane
## that falls between the lines of the part grid matches nothing.
static func _symmetry(boxes: Array) -> float:
	if boxes.is_empty():
		return 0.0
	var grid: Dictionary = {}
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for n: int in boxes.size():
		var one: Array = boxes[n]
		var centre: Vector3 = one[2]
		var key: Array = [one[0], one[1], _cell(centre)]
		if not grid.has(key):
			grid[key] = []
		(grid[key] as Array).append(n)
		low = Vector3(minf(low.x, centre.x), minf(low.y, centre.y), minf(low.z, centre.z))
		high = Vector3(maxf(high.x, centre.x), maxf(high.y, centre.y), maxf(high.z, centre.z))
	var best: float = 0.0
	for axis: int in [0, 2]:
		var planes: Array = _planes(boxes, axis)
		planes.append((low[axis] + high[axis]) / 2.0)
		for at: float in planes:
			best = maxf(best, _mirrored(boxes, grid, axis, at))
	return best


## Where a mirror plane across an axis might be: the three places pairs
## of like parts, level with each other, most often put halfway between
## them.
static func _planes(boxes: Array, axis: int) -> Array:
	var others: Array = [2, 1] if axis == 0 else [0, 1]
	var buckets: Dictionary = {}
	for one: Array in boxes:
		var centre: Vector3 = one[2]
		var half: Vector3 = one[3]
		var key: Array = [one[0], one[1], roundi(centre[others[0]] / TOLERANCE),
			roundi(centre[others[1]] / TOLERANCE), roundi(half[axis]),
			roundi(half[others[0]])]
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(centre[axis])
	var votes: Dictionary = {}
	for key: Variant in buckets:
		var values: Array = buckets[key]
		values.sort()
		values = values.slice(0, 120)
		for i: int in values.size():
			for j: int in range(i + 1, values.size()):
				var middle: float = roundf((float(values[i]) + float(values[j])) / 4.0) * 2.0
				votes[middle] = int(votes.get(middle, 0)) + 1
	var ranked: Array = votes.keys()
	ranked.sort_custom(func(a: float, b: float) -> bool:
		return int(votes[a]) > int(votes[b]))
	return ranked.slice(0, 3)


## The share of parts with a partner across the plane axis = at: one
## partner each, a part across the plane from itself its own.
static func _mirrored(boxes: Array, grid: Dictionary, axis: int, at: float) -> float:
	if true:
		var matched: Dictionary = {}
		for n: int in boxes.size():
			if matched.has(n):
				continue
			var one: Array = boxes[n]
			var target: Vector3 = one[2]
			target[axis] = 2.0 * at - target[axis]
			var home: Vector3i = _cell(target)
			var found: int = -1
			for dx: int in [-1, 0, 1]:
				for dy: int in [-1, 0, 1]:
					for dz: int in [-1, 0, 1]:
						var key: Array = [one[0], one[1], home + Vector3i(dx, dy, dz)]
						for other: int in grid.get(key, []):
							if matched.has(other) and other != n:
								continue
							var them: Array = boxes[other]
							var centre: Vector3 = them[2]
							if (centre - target).abs()[(centre - target).abs().max_axis_index()] > TOLERANCE:
								continue
							found = other
							break
						if found >= 0:
							break
					if found >= 0:
						break
				if found >= 0:
					break
			if found >= 0:
				matched[n] = true
				matched[found] = true
		return float(matched.size()) / float(boxes.size())
	return 0.0


static func _cell(point: Vector3) -> Vector3i:
	return Vector3i(int(floor(point.x / TOLERANCE)), int(floor(point.y / TOLERANCE)),
		int(floor(point.z / TOLERANCE)))


## What to tell a design, or "": the measures on the tails of real sets
## of its kind, each with the median and the edge it is past.
static func advice(found: Dictionary, group: String) -> String:
	if int(found.get("parts", 0)) < LEAST or group.is_empty():
		return ""
	var band: Dictionary = (norms().get("groups", {}) as Dictionary).get(group, {})
	if band.is_empty():
		return ""
	var said := PackedStringArray()
	var low: Array = [
		["snot", "of its parts sideways or upside down — a face of tiles on brackets, a headlight brick, a grille stood up"],
		["shaped", "curved, sloped or at an angle"],
		["curve", "curved — arches, rounds, curved slopes, wedges"],
		["angled", "turned to an angle — a section on a hinge, a wall that bends, a horn that leans"],
	]
	for pair: Array in low:
		var key: String = pair[0]
		if not found.has(key) or not band.has(key):
			continue
		var edges: Array = band[key]
		if float(found[key]) < float(edges[0]):
			said.append("%s %s, where they are about %s (and below %s is plainer than nine in ten)"
				% [_share(found[key]), pair[1], _share(edges[1]), _share(edges[0])])
	for pair: Array in [["plain", "plain rectangular bricks and plates"],
			["symmetry", "mirrored left to right"]]:
		var key: String = pair[0]
		if not found.has(key) or not band.has(key):
			continue
		var edges: Array = band[key]
		if float(found[key]) > float(edges[2]):
			said.append("%s %s, where they are about %s (and above %s is more than nine in ten)"
				% [_share(found[key]), pair[1], _share(edges[1]), _share(edges[2])])
	if said.is_empty():
		return ""
	# The calls that do it, by name: designs take up a technique when it
	# is one call they are told of — the finishing pass was used in two runs
	# running once the advice named it, and a prism once in four without.
	var calls := PackedStringArray()
	if found.has("snot") and band.has("snot") and float(found["snot"]) < float((band["snot"] as Array)[0]) \
			or found.has("plain") and band.has("plain") and float(found["plain"]) > float((band["plain"] as Array)[2]):
		calls.append("restyle_model, for the plain faces already built")
	if found.has("angled") and band.has("angled") and float(found["angled"]) < float((band["angled"] as Array)[0]):
		calls.append("a prism pattern, for a tower, a pier or a turret that should have more than four sides")
	var who: String = "real sets since 2010" if group == "since_2010" else (
		"real %s sets%s" % [group.replace("_since_2010", ""),
			" since 2010" if group.ends_with("_since_2010") else ""])
	return ("Built more squarely than %s (%d measured, from LDraw's "
		% [who, int(band.get("models", 0))]
		+ "official models):\n  " + "\n  ".join(said) + "\nThis is how a "
		+ "model that holds together comes to look like a pile of bricks. "
		+ "The way out is technique, not more bricks: brackets and headlight "
		+ "bricks to turn a face, sections turned to the angle a thing really "
		+ "has, curved slopes and arches where an edge can round, the rock "
		+ "pattern where the ground is irregular — and symmetry only where the "
		+ "subject has it."
		+ ("\nOne call each: " + "; ".join(calls) + "." if not calls.is_empty() else ""))


static func _share(value: Variant) -> String:
	return "%d%%" % int(round(float(value) * 100.0))
