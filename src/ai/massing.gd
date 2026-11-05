## How much of its box a model fills, against real sets of its kind.
##
## The judge's commonest cause against our designs on likeness and overall
## is a generic or boxy shape: "a generic low tan block with flat grey slab
## roofs" (DESIGN_SCORES.md, design15). A set's shape is chosen when it is
## planned: its massing broken into volumes, a roofline, overhangs, gaps
## the subject has. This reads that off the lattice, the real cover of every
## part, a voxel half a stud across and a plate tall, filled when half its
## cells are.
##
## The ground is left out first: the flat layers at the bottom (a
## baseplate, a plinth, a lot of plates) wider than what stands on them.
## Then, of what stands there:
##   fill   its solid seen from above, every column filled from its top
##          down to the bottom, against its box: a box is 1.
##   front  its outline from the front against its box's front, and side
##          and plan the same from the side and above.
##   tall   its height against its footprint: height over the square root
##          of its width times its depth, in LDU.
##
## What it is measured by, design15 (2026-11-04), over 1,616 bench designs
## of 88 subjects judged against their own set: of one subject's designs,
## the half that fill less of their box won likeness 3.2 points more (+0.5,
## +6.0) and overall 2.9 more, and were called boxy less; 79% of designs
## fill more of their box than their set. Across subjects it says nothing:
## a BrickHeadz figure is a block and wins as one. So a model is measured
## against real sets of its theme and part count (the library's 1,234 set
## models, src/dev/set_massing.gd), never another kind's. Told after the
## first build, it moved too few sessions to win (design15); a plan's
## volumes are measured by it before any brick (MassingPlan).
class_name Massing
extends RefCounted

## Lattice cells a voxel is across (half a stud) and tall (a plate).
const COLUMN := 5
const LAYER := 4
## A voxel is filled when this many of its cells are.
const FULL := COLUMN * LAYER * COLUMN / 2
## The ground is at most this many layers, each this much wider than the
## first layer that stands on it.
const GROUND_LAYERS := 4
const GROUND_WIDER := 1.5
## Sets of the part count: within this factor of it, or this wider one when
## too few are; and at least this many sets, or nothing is said.
const BAND := 1.6
const WIDER := 2.5
const FEWEST := 8


## The measures of the bricks [param ids] on [param lattice] (measure).
static func read(lattice: BrickLattice, ids: Array) -> Dictionary:
	return measure(boxes_of(lattice, ids))


## The cover of each of [param ids], six ints a box: what measure() reads,
## taken on the main thread so the measure can run on a worker.
static func boxes_of(lattice: BrickLattice, ids: Array) -> Array:
	var out: Array = []
	for id: Variant in ids:
		out.append(lattice.boxes_of(int(id)))
	return out


## {"fill", "front", "side", "plan", "tall", "ground" (layers left out),
## "box": [width, depth in studs, height in plates]} of [param boxes]
## (boxes_of), or {} when nothing is there. Reads only its argument.
static func measure(boxes: Array) -> Dictionary:
	return measure_filled(voxels(boxes))


## The same of [param filled], voxel -> anything, as voxels() gives them:
## how a plan's volumes are measured as a build is (MassingPlan).
static func measure_filled(filled: Dictionary) -> Dictionary:
	if filled.is_empty():
		return {}
	var low := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var high := -low
	var area: Dictionary = {}   # layer -> {Vector2i column: true}
	for cell: Vector3i in filled:
		low = Vector3i(mini(low.x, cell.x), mini(low.y, cell.y), mini(low.z, cell.z))
		high = Vector3i(maxi(high.x, cell.x), maxi(high.y, cell.y), maxi(high.z, cell.z))
		if not area.has(cell.y):
			area[cell.y] = {}
		(area[cell.y] as Dictionary)[Vector2i(cell.x, cell.z)] = true
	var ground: int = _ground(area, low.y, high.y)
	var bottom: int = low.y + ground
	var body: Array[Vector3i] = []
	for cell: Vector3i in filled:
		if cell.y >= bottom:
			body.append(cell)
	if body.is_empty():
		return {}
	low = Vector3i(1 << 30, bottom, 1 << 30)
	high = Vector3i(-(1 << 30), bottom, -(1 << 30))
	for cell: Vector3i in body:
		low = Vector3i(mini(low.x, cell.x), low.y, mini(low.z, cell.z))
		high = Vector3i(maxi(high.x, cell.x), maxi(high.y, cell.y), maxi(high.z, cell.z))
	var wide: int = high.x - low.x + 1
	var deep: int = high.z - low.z + 1
	var tall: int = high.y - low.y + 1
	var top: Dictionary = {}     # Vector2i column -> its highest layer
	var front: Dictionary = {}   # Vector2i(x, y) -> true
	var side: Dictionary = {}    # Vector2i(z, y) -> true
	for cell: Vector3i in body:
		var column := Vector2i(cell.x, cell.z)
		top[column] = maxi(int(top.get(column, cell.y)), cell.y)
		front[Vector2i(cell.x, cell.y)] = true
		side[Vector2i(cell.z, cell.y)] = true
	var solid: int = 0
	for column: Vector2i in top:
		solid += int(top[column]) - bottom + 1
	return {
		"fill": float(solid) / (wide * deep * tall),
		"front": float(front.size()) / (wide * tall),
		"side": float(side.size()) / (deep * tall),
		"plan": float(top.size()) / (wide * deep),
		"tall": (tall * BrickLattice.PLATE) / sqrt(wide * deep * BrickLattice.STUD
			* BrickLattice.STUD / 4.0),
		"ground": ground,
		"box": [wide / 2.0, deep / 2.0, tall],
	}


## Voxel -> true for every voxel the boxes fill half of. The bricks' boxes
## never overlap one another, so what each adds to a voxel sums. A voxel
## (x, y, z) is studs x / 2 to (x + 1) / 2 across, plates y to y + 1 up.
static func voxels(boxes: Array) -> Dictionary:
	var cover: Dictionary = {}
	for packed: PackedInt32Array in boxes:
		var n: int = 0
		while n + 5 < packed.size():
			var lo := Vector3i(packed[n], packed[n + 1], packed[n + 2])
			var hi := Vector3i(packed[n + 3], packed[n + 4], packed[n + 5])
			n += 6
			for vx: int in range(floori(lo.x / float(COLUMN)), floori((hi.x - 1) / float(COLUMN)) + 1):
				var ox: int = mini(hi.x, (vx + 1) * COLUMN) - maxi(lo.x, vx * COLUMN)
				for vy: int in range(floori(lo.y / float(LAYER)), floori((hi.y - 1) / float(LAYER)) + 1):
					var oy: int = mini(hi.y, (vy + 1) * LAYER) - maxi(lo.y, vy * LAYER)
					for vz: int in range(floori(lo.z / float(COLUMN)), floori((hi.z - 1) / float(COLUMN)) + 1):
						var oz: int = mini(hi.z, (vz + 1) * COLUMN) - maxi(lo.z, vz * COLUMN)
						var key := Vector3i(vx, vy, vz)
						cover[key] = int(cover.get(key, 0)) + ox * oy * oz
	var filled: Dictionary = {}
	for key: Vector3i in cover:
		if int(cover[key]) >= FULL:
			filled[key] = true
	return filled


## How many layers at the bottom are ground: the most, up to GROUND_LAYERS,
## each GROUND_WIDER or more than the first layer above them.
static func _ground(area: Dictionary, bottom: int, top: int) -> int:
	var best: int = 0
	for layers: int in range(1, GROUND_LAYERS + 1):
		if bottom + layers > top:
			break
		var above: int = (area.get(bottom + layers, {}) as Dictionary).size()
		if above == 0:
			continue
		var wider: bool = true
		for y: int in range(bottom, bottom + layers):
			if (area.get(y, {}) as Dictionary).size() < GROUND_WIDER * above:
				wider = false
				break
		if wider:
			best = layers
	return best


## What real sets of the theme [param said] names (ColoursSeen.theme_in),
## or else of one of [param kinds] by a word of their names, and of about
## [param parts] parts fill of their box, none of them under test
## (SetKnowledge.massing): {"by": "City sets", "low", "high": their part
## counts, "sets", "q1", "median", "q3": their fill}. {} when too few are
## known.
static func sets_like(said: String, kinds: PackedStringArray, parts: int) -> Dictionary:
	var table: Dictionary = SetKnowledge.massing()
	var rows: Array = table.get("models", [])
	var at: int = (table.get("keys", []) as Array).find("fill")
	if rows.is_empty() or at < 0 or parts <= 0:
		return {}
	var themes: Array = []
	for row: Array in rows:
		if not themes.has(row[2]):
			themes.append(row[2])
	var picked: Array = []
	var by: String = ""
	var theme: int = ColoursSeen.theme_in(said, themes)
	if theme >= 0:
		picked = _of_size(rows.filter(func(row: Variant) -> bool:
			return str((row as Array)[2]) == str(themes[theme])), parts)
		by = "%s sets" % str(themes[theme])
	if picked.size() < FEWEST:
		for kind: String in kinds:
			picked = _of_size(rows.filter(func(row: Variant) -> bool:
				return ColoursSeen.name_words(str((row as Array)[1])).has(kind)), parts)
			by = "%s sets" % kind
			if picked.size() >= FEWEST:
				break
	if picked.size() < FEWEST:
		return {}
	var fills: Array[float] = []
	var low: int = 0x7FFFFFFF
	var high: int = 0
	for row: Array in picked:
		low = mini(low, int(row[3]))
		high = maxi(high, int(row[3]))
		fills.append(float(row[4 + at]))
	fills.sort()
	return {"by": by, "low": low, "high": high, "sets": picked.size(),
		"q1": fills[fills.size() / 4], "median": fills[fills.size() / 2],
		"q3": fills[fills.size() * 3 / 4]}


## Of [param rows], those within BAND of [param parts] parts (WIDER when too
## few are). SetKnowledge.massing() has left out the sets under test.
static func _of_size(rows: Array, parts: int) -> Array:
	var out: Array = []
	for wide: float in [BAND, WIDER]:
		out = rows.filter(func(row: Variant) -> bool:
			var n: int = int((row as Array)[3])
			return n >= parts / wide and n <= parts * wide)
		if out.size() >= FEWEST:
			break
	return out

