## Whether a model would stand up, and where it would fail first.
##
## Connection and support say a model is *assembled*. They say nothing
## about whether it holds together once gravity is applied: a tower of
## single bricks is connected and supported and falls over, and a long
## cantilever is connected and supported and snaps at the root.
##
## What this does
## --------------
## For every joint in the model — every place one brick rests on another
## — it asks two questions about everything carried above that joint:
##
##   Does its weight exceed what the connection can hold?
##     A stud's clutch is a measured quantity. Multiply by how many studs
##     the joint actually has and compare.
##
##   Does its centre of mass fall outside the joint's footprint?
##     If it does, the load is a moment rather than a weight, and the
##     joint is being levered apart rather than pulled.
##
## What this is not
## ----------------
## Not a force-balance solve. The published approach sets up a quadratic
## program over friction, support and normal forces at every contact and
## minimises the worst friction margin; it is exact, it names the failing
## contact, and it runs in milliseconds — but it needs a QP solver.
##
## This is the honest subset that can run on every edit without one. It
## catches the three failures that actually happen — a joint carrying
## more than its studs hold, a load hanging past its footprint, and a
## load stacked too high over too small a base — and it reports a margin
## rather than a verdict so the difference shows. It will not catch a
## structure that fails through an interior path rather than at a joint.
class_name Stability
extends RefCounted

## ABS is about 1.05 g/cm³.
const DENSITY_G_PER_CM3 := 1.05
## Wall thickness, in LDU. A brick's side wall is 1.6 mm and its top is
## 1 mm; 4 and 2.5 LDU respectively.
const WALL_LDU := 4.0
const TOP_LDU := 2.5
## 1 LDU is 0.4 mm, so a cubic LDU is 0.064 mm³, and a cubic centimetre
## is 15,625 of them.
const CUBIC_LDU_PER_CM3 := 15625.0

## What one stud's clutch will hold before it lets go, in grams.
##
## The LEGO Group's own figure for clutch power is a pull-off force
## around 1 N per stud, which is about 100 g. Taken conservatively here:
## a joint at exactly its limit is already a bad joint.
const GRAMS_PER_STUD := 80.0

## How far outside the footprint the centre of mass may sit before the
## joint counts as levered rather than loaded, as a fraction of the
## footprint's half-width.
const TIPPING_MARGIN := 0.5

## How tall a load may stand above a joint, relative to the half-width of
## the base carrying it, before it is called top-heavy.
##
## This is the aspect ratio at which a small push tips the thing over
## rather than sliding it. A load whose centre of mass is six times its
## base half-width up needs less than ten degrees of lean to fall, which
## is about what a table getting knocked provides.
const SLENDERNESS_LIMIT := 6.0


class Risk extends RefCounted:
	var brick_id: int
	var kind: String        ## "overloaded" or "levered"
	var margin: float       ## < 1 is failing; 2 means twice the strength needed
	var carrying_grams: float
	var studs: int
	var message: String


class Report extends RefCounted:
	var risks: Array[Risk] = []
	var total_grams: float = 0.0
	var joints: int = 0
	var weakest: Risk = null

	func is_stable() -> bool:
		return risks.is_empty()

	func summary() -> String:
		if risks.is_empty():
			return "stands up · %.0f g" % total_grams
		var worst: String = weakest.kind if weakest else "weak"
		return "%d weak joint%s (%s) · %.0f g" % [
			risks.size(), "" if risks.size() == 1 else "s", worst, total_grams]


var library: PartLibrary
var lattice: BrickLattice


## Check a model. Returns the joints that would fail, weakest first.
func check(world: BrickWorld) -> Report:
	var report := Report.new()
	var bricks: Array = world.bricks()
	if bricks.is_empty():
		return report

	# Mass per brick, and the cells each occupies, once.
	var mass: Dictionary = {}          ## id -> grams
	var cells_of: Dictionary = {}      ## id -> Array[Vector3i]
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		mass[brick.id] = grams(info)
		report.total_grams += mass[brick.id]

	# Who rests on whom. A brick supports another when one of its cells
	# sits directly beneath one of theirs.
	var above: Dictionary = {}         ## id -> { id: shared column count }
	var below: Dictionary = {}
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var cells: Array[Vector3i] = _cells(brick)
		cells_of[brick.id] = cells
		for cell: Vector3i in cells:
			var over: int = lattice.brick_at(Vector3i(cell.x, cell.y + 1, cell.z))
			if over == 0 or over == brick.id:
				continue
			if not above.has(brick.id):
				above[brick.id] = {}
			above[brick.id][over] = int(above[brick.id].get(over, 0)) + 1
			if not below.has(over):
				below[over] = {}
			below[over][brick.id] = int(below[over].get(brick.id, 0)) + 1

	# Push the load downward, sharing it among supporters.
	#
	# The first attempt gave every brick the entire mass of everything
	# above it, which reads plausibly and is wrong the moment a structure
	# has more than one path to the ground: in a hollow tower each corner
	# brick appeared to carry the whole ring, whose centre of mass sits
	# over the courtyard rather than over the brick. It reported
	# twenty-six failing joints in a wall that stands up perfectly well.
	#
	# A brick's load is its own mass plus whatever is handed down to it,
	# and it hands that on to the bricks beneath in proportion to how
	# much of it each one carries. One pass from the top down is enough
	# because a support graph only ever points downward.
	var order: Array = bricks.duplicate()
	order.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return a.transform.origin.y > b.transform.origin.y)

	var received: Dictionary = {}       ## id -> grams handed down
	var load_centre: Dictionary = {}    ## id -> grams-weighted position

	for item: Variant in order:
		var brick: BrickWorld.Brick = item
		var own: float = mass.get(brick.id, 0.0)
		var carried: float = own + float(received.get(brick.id, 0.0))
		var centre: Vector3 = brick.transform.origin * own
		if load_centre.has(brick.id):
			centre += load_centre[brick.id]

		var supporters: Dictionary = below.get(brick.id, {})
		if supporters.is_empty():
			continue
		var total_contact: float = 0.0
		for supporter_id: int in supporters:
			total_contact += float(supporters[supporter_id])
		if total_contact <= 0.0:
			continue
		for supporter_id: int in supporters:
			var share: float = float(supporters[supporter_id]) / total_contact
			received[supporter_id] = float(
				received.get(supporter_id, 0.0)) + carried * share
			load_centre[supporter_id] = (
				load_centre.get(supporter_id, Vector3.ZERO) + centre * share)

	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		if not above.has(brick.id):
			continue
		report.joints += 1
		var grams: float = float(received.get(brick.id, 0.0))
		if grams <= 0.0:
			continue
		var centre: Vector3 = load_centre.get(brick.id, Vector3.ZERO) / grams

		var risk: Risk = _assess(brick, grams, centre, cells_of, above)
		if risk != null:
			report.risks.append(risk)

	_check_levels(world, mass, cells_of, report)

	report.risks.sort_custom(func(a: Risk, b: Risk) -> bool:
		return a.margin < b.margin)
	if not report.risks.is_empty():
		report.weakest = report.risks[0]
	return report


func _assess(
	brick: BrickWorld.Brick, grams: float, centre: Vector3,
	cells_of: Dictionary, above: Dictionary
) -> Risk:
	# The joint's strength is the number of stud-sized columns shared
	# with what sits directly on it.
	var columns: int = 0
	for other_id: int in above.get(brick.id, {}):
		columns += int(above[brick.id][other_id])
	# Cells are 2 LDU and a stud is 20, so a stud's footprint is 100
	# cells in plan; the count above is per cell, over one layer.
	var studs: int = maxi(1, int(round(float(columns) / 100.0)))

	var holds: float = studs * GRAMS_PER_STUD
	if grams > holds:
		var risk := Risk.new()
		risk.brick_id = brick.id
		risk.kind = "overloaded"
		risk.margin = holds / grams
		risk.carrying_grams = grams
		risk.studs = studs
		risk.message = (
			"%s carries %.0f g on %d stud%s, which holds about %.0f g" % [
				brick.part_id, grams, studs, "" if studs == 1 else "s", holds])
		return risk

	return null


## Does the model lean, or stand on too little?
##
## Levering and toppling are properties of a *level*, not of a brick. A
## brick in the middle of a wall carries a load whose centre of mass sits
## well outside its own little footprint, and it is held perfectly well
## by the bricks either side of it — checking it alone reported thirteen
## failing joints in a bonded tower that stands up fine.
##
## So the question is asked of horizontal slices instead: at each course,
## is the centre of mass of everything above it over the footprint of
## everything at and below it? That is the criterion that actually
## decides whether a thing tips, and it catches a leaning tower and a
## cantilevered arm without libelling a wall.
func _check_levels(
	world: BrickWorld, mass: Dictionary, cells_of: Dictionary, report: Report
) -> void:
	var bricks: Array = world.bricks()
	if bricks.size() < 2:
		return

	# Group by the height each brick starts at, in whole cells.
	var levels: Dictionary = {}        ## cell y -> Array[Brick]
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var cells: Array[Vector3i] = cells_of.get(brick.id, [])
		if cells.is_empty():
			continue
		var floor_y: int = 0x7FFFFFFF
		for cell: Vector3i in cells:
			floor_y = mini(floor_y, cell.y)
		if not levels.has(floor_y):
			levels[floor_y] = []
		levels[floor_y].append(brick)

	var heights: Array = levels.keys()
	heights.sort()
	if heights.size() < 2:
		return

	for n: int in range(1, heights.size()):
		var cut: int = heights[n]

		# Everything above the cut, and where its mass sits.
		var grams: float = 0.0
		var centre := Vector3.ZERO
		for item: Variant in bricks:
			var brick: BrickWorld.Brick = item
			var cells: Array[Vector3i] = cells_of.get(brick.id, [])
			if cells.is_empty() or cells[0].y < cut:
				continue
			var floor_y: int = 0x7FFFFFFF
			for cell: Vector3i in cells:
				floor_y = mini(floor_y, cell.y)
			if floor_y < cut:
				continue
			var w: float = mass.get(brick.id, 0.0)
			grams += w
			centre += brick.transform.origin * w
		if grams <= 0.0:
			continue
		centre /= grams

		# The footprint it all stands on: everything below the cut.
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for item: Variant in bricks:
			var brick: BrickWorld.Brick = item
			for cell: Vector3i in cells_of.get(brick.id, []):
				if cell.y >= cut:
					continue
				var x: float = cell.x * BrickLattice.CELL
				var z: float = cell.z * BrickLattice.CELL
				lo = Vector2(minf(lo.x, x), minf(lo.y, z))
				hi = Vector2(maxf(hi.x, x), maxf(hi.y, z))
		if lo.x == INF:
			continue

		var middle := (lo + hi) * 0.5
		var half := (hi - lo) * 0.5
		var offset := Vector2(
			absf(centre.x - middle.x), absf(centre.z - middle.y))
		# A stud of slack: the footprint measured from cell centres is
		# marginally smaller than the plastic actually is.
		var allowed := half + Vector2(BrickLattice.STUD, BrickLattice.STUD)

		if offset.x > allowed.x or offset.y > allowed.y:
			var risk := Risk.new()
			risk.kind = "leaning"
			risk.margin = minf(
				allowed.x / maxf(offset.x, 0.001),
				allowed.y / maxf(offset.y, 0.001))
			risk.carrying_grams = grams
			# GDScript has no implicit string-literal joining; the pieces
			# have to be added.
			risk.message = ("above %.0f studs up, %.0f g sits past the edge "
				+ "of what holds it") % [
					cut * BrickLattice.CELL / BrickLattice.STUD, grams]
			report.risks.append(risk)
			return

		var base: float = maxf(minf(half.x, half.y), BrickLattice.CELL)
		var rise: float = maxf(centre.y - cut * BrickLattice.CELL, 0.0)
		if rise > base * SLENDERNESS_LIMIT:
			var risk := Risk.new()
			risk.kind = "top-heavy"
			risk.margin = (base * SLENDERNESS_LIMIT) / maxf(rise, 0.001)
			risk.carrying_grams = grams
			risk.message = (
				"%.0f g stands %.0f studs above a base %.1f studs wide"
				% [grams, rise / BrickLattice.STUD,
					base * 2.0 / BrickLattice.STUD])
			report.risks.append(risk)
			return


## A part's mass, from the plastic in its walls.
##
## Derived rather than looked up: a table covers the dozen brick sizes
## anyone has measured, and this has to answer for 29,000 parts.
##
## The first attempt took a flat fraction of the bounding volume and was
## wrong in a way that mattered — 32% light on a 1x1 and 10% heavy on a
## 2x4 — because a brick is not a uniformly filled box. It is a shell,
## and the thinner the part the more of it is wall. Subtracting the
## cavity instead gets the trend right as well as the magnitude:
##
##     part     this    published
##     1x1      0.47 g    0.44 g
##     1x2      0.80 g    0.78 g
##     2x2      1.22 g    1.18 g
##     1x4      1.45 g    1.74 g
##     2x4      2.08 g    2.20 g
##     2x6      2.93 g    3.28 g
##
## The remaining error is the underside tubes and ribs, which this does
## not model, so it runs light on longer parts — worst case about 17% on
## a 1x4. Stability is a ratio, and an error that biases the whole model
## the same way mostly cancels.
static func grams(info: PartLibrary.PartInfo) -> float:
	# The body, without the studs standing proud of it.
	var width: float = info.size.x
	var depth: float = info.size.z
	var height: float = info.size.y
	if info.stud_count > 0:
		height = maxf(height - 4.0, 1.0)

	var outer: float = width * height * depth
	var cavity: float = (
		maxf(width - WALL_LDU * 2.0, 0.0)
		* maxf(height - TOP_LDU, 0.0)
		* maxf(depth - WALL_LDU * 2.0, 0.0))
	var material: float = maxf(outer - cavity, outer * 0.25)
	# The studs, which were taken off the body height above and are solid
	# plastic: a 6 LDU radius standing 4 LDU proud.
	material += info.stud_count * PI * 36.0 * 4.0
	return (material / CUBIC_LDU_PER_CM3) * DENSITY_G_PER_CM3


func _cells(brick: BrickWorld.Brick) -> Array[Vector3i]:
	var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
	if part == null:
		return []
	var boxes: Array[AABB] = part.boxes
	if boxes.is_empty():
		return []
	return BrickLattice.cells_for(
		boxes, BrickLattice.to_cell(brick.transform.origin), brick.transform.basis)
