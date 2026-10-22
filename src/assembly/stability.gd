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

## ABS is about 1.05 g/cm³ (1.03-1.06, Faria 2018; docs/MECHANISMS.md §4).
const DENSITY_G_PER_CM3 := 1.05
## Wall thickness, in LDU, as LDraw draws it: the side wall 1.6 mm and the
## top 1 mm.
const WALL_LDU := 4.0
const TOP_LDU := 2.5
## The tubes under a part two studs or more each way, 6.4 mm across and
## hollow to 4.8 (radii in LDU), one between each four studs; and the solid
## posts under a part one stud wide, 3.2 mm across, one between each two.
const TUBE_OUT_LDU := 8.0
const TUBE_IN_LDU := 6.0
const POST_LDU := 4.0
## 1 LDU is 0.4 mm, so a cubic LDU is 0.064 mm³, and a cubic centimetre
## is 15,625 of them.
const CUBIC_LDU_PER_CM3 := 15625.0

## What one stud's clutch is trusted with, in grams: a working load.
##
## The LEGO Group does not publish its clutch figure ("the ideal strength's
## value must remain secret", The Secret Life of LEGO® Bricks, p. 22). StableLego
## measured 0.98 N per contact point, three or four to a stud, so a stud
## lets go at about 3-4 N (arXiv 2402.10711). 80 g is 0.78 N, about a
## quarter of that. Balance takes 1 N a stud as the working load and 3 N as
## where it lets go (docs/MECHANISMS.md §4).
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

## Boxes on both sides of a joint from which they are compared slice by
## slice rather than box by box ([method BrickLattice.shared_lifted]).
## Below it the plain comparison is fewer steps.
const SLICED_FROM := 8


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
## Bricks that are the floor and not the model: the baseplate under it.
## Left out of whether it tips over.
var floor_ids: Dictionary = {}
## Set on the main thread to end a [method check] on a worker early, which
## then returns null (Main._weigh, PartLibrary.reading_in).
var stopped: bool = false


## Check a model. Returns the joints that would fail, weakest first.
func check(world: BrickWorld) -> Report:
	var report := Report.new()
	var bricks: Array = world.bricks()
	if bricks.is_empty():
		return report

	# Mass per brick, once.
	var mass: Dictionary = {}          ## id -> grams
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		mass[brick.id] = grams(info)
		report.total_grams += mass[brick.id]

	var graph: Dictionary = contacts(bricks)
	if stopped:
		return null
	var above: Dictionary = graph["above"]
	var boxes_of: Dictionary = graph["boxes"]

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
	# and it hands that on to the bricks beneath in proportion to the studs
	# between them. One pass from the top down is enough because a support
	# graph only ever points downward.
	var order: Array = bricks.duplicate()
	order.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return a.transform.origin.y > b.transform.origin.y)
	# Who carries whom is read as Balance and Sections read it. The lift's
	# own cells read two parts whose covers overlap as each resting on the
	# other: a pin in a beam, a cone on an antenna, two turned plates side by
	# side each carried the other, on studs that are not there. A wheel on
	# its spindle hands its weight on, but on no stud.
	var carriers: Dictionary = _carriers(order, stud_joints(graph, library, lattice, false))
	if stopped:
		return null

	var received: Dictionary = {}       ## id -> grams handed down
	var on_studs: Dictionary = {}       ## id -> grams of that through its studs
	var holding: Dictionary = {}        ## id -> the studs those stand on

	for item: Variant in order:
		var brick: BrickWorld.Brick = item
		var supporters: Dictionary = carriers.get(brick.id, {})
		if supporters.is_empty():
			continue
		var carried: float = mass.get(brick.id, 0.0) + float(received.get(brick.id, 0.0))
		var total: float = 0.0
		for supporter_id: int in supporters:
			total += maxf(1.0, float(supporters[supporter_id]))
		for supporter_id: int in supporters:
			var studs: int = supporters[supporter_id]
			var handed: float = carried * maxf(1.0, float(studs)) / total
			received[supporter_id] = float(received.get(supporter_id, 0.0)) + handed
			if studs > 0:
				on_studs[supporter_id] = float(on_studs.get(supporter_id, 0.0)) + handed
				holding[supporter_id] = int(holding.get(supporter_id, 0)) + studs

	for item: Variant in bricks:
		if stopped:
			return null
		var brick: BrickWorld.Brick = item
		if above.has(brick.id):
			report.joints += 1
		var grams: float = float(on_studs.get(brick.id, 0.0))
		if grams <= 0.0:
			continue
		var risk: Risk = _assess(brick, grams, int(holding[brick.id]))
		if risk != null:
			report.risks.append(risk)

	_check_levels(world, mass, boxes_of, report)
	if stopped:
		return null
	_check_tipping(bricks, mass, boxes_of, report)

	report.risks.sort_custom(func(a: Risk, b: Risk) -> bool:
		return a.margin < b.margin)
	if not report.risks.is_empty():
		report.weakest = report.risks[0]
	return report


## Whether the whole tips over on what it stands on: its centre of mass
## past the edge of where it touches the floor (Balance.support_of), the
## floor itself left out. The levels above cannot see it when the model
## stands on a baseplate, because the plate is under every cut and as wide
## as the ground: an arm eighteen studs past a 6x6 base read "stands up".
func _check_tipping(bricks: Array, mass: Dictionary, boxes_of: Dictionary,
		report: Report) -> void:
	var model: Dictionary = {}
	var grams: float = 0.0
	var weighted := Vector3.ZERO
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		if floor_ids.has(brick.id) or not boxes_of.has(brick.id):
			continue
		model[brick.id] = boxes_of[brick.id]
		var own: float = mass.get(brick.id, 0.0)
		grams += own
		weighted += _middle(brick) * own
	if grams <= 0.0:
		return
	var hull: PackedVector2Array = Balance.support_of(model)["hull"]
	if hull.size() < 3:
		return
	var centre: Vector3 = weighted / grams
	var standing: Dictionary = Balance.margin_in(hull, Vector2(centre.x, centre.z))
	var past: float = -float(standing["margin"]) / BrickLattice.STUD
	if past <= 0.0:
		return
	var risk := Risk.new()
	risk.kind = "tips"
	risk.margin = 0.0
	risk.carrying_grams = grams
	risk.message = "its weight is %s studs past the %s edge of what it stands on" % [
		Balance.studs(past), standing["edge"]]
	report.risks.append(risk)


## Who rests on whom, as the lattice has it: {"above": id -> {id of each
## brick resting on it: cells shared}, "boxes": id -> the boxes it
## occupies, "bricks": [param bricks], "overlap": [method pair_of] -> the
## cells the two share as they stand, for each pair "above" has that share
## any}. The stud joints [method check] weighs and Balance cuts are read
## from it by [method stud_joints].
func contacts(bricks: Array) -> Dictionary:
	var boxes_of: Dictionary = {}      ## id -> PackedInt32Array, 6 per box
	# Who rests on whom. A brick supports another when one of its cells
	# sits directly beneath one of theirs.
	# In boxes, and asked of the lattice once per brick.
	#
	# This walked every cell of every brick and asked the lattice what
	# was in the cell above it. A 2x4 brick is nine thousand six hundred
	# cells, so a thousand-brick model is ten million lookups: measured
	# at 37 ms a brick, 41 seconds for the 1,106-brick castle that
	# provoked this, and six minutes for the ten thousand the lattice
	# can hold. The app shows this on every change and the design loop
	# runs it on the one look it takes at its finished work.
	#
	# A brick's boxes lifted one cell is exactly the space whatever
	# rests on it occupies, so one bucket query finds the candidates and
	# the overlap of two boxes is a box — three subtractions and a
	# product, rather than a lookup per cell. Verified against the
	# cell-by-cell count on seven real pairs of parts: identical.
	var above: Dictionary = {}         ## id -> { id: shared cell count }
	var overlap: Dictionary = {}       ## pair_of -> cells shared as they stand
	var none: Array = []
	for item: Variant in bricks:
		if stopped:
			break
		var brick: BrickWorld.Brick = item
		var mine: PackedInt32Array = _boxes(brick)
		boxes_of[brick.id] = mine
		if mine.is_empty():
			continue
		var lid: PackedInt32Array = BrickLattice.moved_by(
			mine, Vector3i(0, 1, 0))
		# A turned part's many slices sorted once, for every brick it might
		# carry; and every brick whose bounds meet it counted outright, the
		# count being the test. Asking the lattice which ones touch first
		# compared the same boxes twice: on Orthanc that was 3.9 s, and
		# counting box against box 6.5 s more.
		var slices: Array = BrickLattice.slices_of(mine) \
			if mine.size() >= SLICED_FROM * 6 else none
		for over: int in lattice.near_bounds(lid, brick.id):
			# Skipping pairs whose boxes already overlap was tried, on
			# the theory that a part inside another is not resting on
			# it. It is wrong, and measurably: a stud belongs to the
			# brick below and reaches into the brick above, so nearly
			# every real joint overlaps. The kart went from 42 joints to
			# 14 and the car from 53 to 44. What the two share as they
			# stand is counted in the same pass, for stud_joints.
			var theirs: PackedInt32Array = lattice.boxes_of(over)
			var shared: Vector2i = BrickLattice.shared_lifted(mine,
				slices if theirs.size() >= SLICED_FROM * 6 else none, theirs)
			if shared.x <= 0:
				continue
			if not above.has(brick.id):
				above[brick.id] = {}
			above[brick.id][over] = int(above[brick.id].get(over, 0)) + shared.x
			if shared.y > 0:
				overlap[pair_of(brick.id, over)] = shared.y

	return {"above": above, "boxes": boxes_of, "bricks": bricks, "overlap": overlap}


## Lattice cells shared across one stud joint, as [method contacts] counts
## them: a stud's square, 10 x 10 cells. A 2 x 4 brick on another shares 800
## (sections_probe), 8 studs.
const STUD_CELLS := 100.0


## Two brick ids as one key, the lower first: how [method stud_joints] and
## Sections name a pair.
static func pair_of(a: int, b: int) -> int:
	return (mini(a, b) << 32) | maxi(a, b)


## Which of [param contacts]' parts (what [method contacts] found for them)
## studs join, as the build check reads studs: {"studs": [method pair_of] ->
## how many, "under": pair -> the id of the one with the studs, "sideways":
## pair -> [where its studs stand, LDU, the way they point] for a pair
## whose studs were read by their tips and do not point up, "seated": pair ->
## true for a pair the lift reaches only where the two already overlap,
## joined by no stud: a cone threaded on an antenna, a pin in a beam, or two
## turned covers side by side, "beside": pair -> true for a "seated" pair
## that is only touching, joined by nothing (below), "overlapped": pair ->
## true for a stud pair the lift read across covers that already overlap,
## with no stud's tip in either, "pivots": pair -> [where its stud stands,
## the way it points] for a pair one stud joins into a part turned to it off
## the square, which turns on that stud (below)}. Only pairs of those parts; worked out once and kept in [param
## contacts] as "joints", so a caller weighing its parts a few at a time
## (Tested, BrickifySteps) pays once. Balance, Sections, Tested and [method
## check] all read what holds what from here.
##
## The lift's resting cells are not studs as they stand. Turned parts'
## covers side by side overlap their whole height, and the lift read that
## overlap as each resting on the other: 10179-1's 2 x 3 plates on edge,
## held by nothing between them, were joined by 6 studs, and a stud
## pointing sideways never shows in a lift (2026-10-20). So a pair rests on
## the cells the lift reaches that the two did not already share ([method
## contacts]' "overlap", counted in the same pass: counted here after, it
## was 0.3-1.5 s of reading 1,000-1,300-part Technic sets, now 9-21 ms),
## and each stud whose tip is in another part joins them (Joints.studs_in),
## whichever way it points; a pair has whichever count is more.
##
## Even so, what the lift reaches past an overlap is mostly where the two
## covers' edges differ: a tyre on its rim, a pin in a beam, a turntable's
## two halves (342 studs). On 45 real sets 12,269 pairs were joined so, with
## no stud's tip in either, and 8466-1's steering arm was weighed as
## carrying its wheel on one stud, overloaded (2026-10-21). They hold the
## parts together, as Suggest sections reads them, and are "overlapped":
## [method check] and Balance weigh no stud there. Of the 12,219 left once
## tips are read as below, what holds them is a pin or an axle in its hole
## (6,080), a hinge, a turntable or a clip on a bar (1,017), a ball (78), a
## hose's pieces or a sticker's glue (496), and for 4,548 no joint the
## connectors name: a part seated in another, or turned beside it.
##
## Where covers overlap a tip's cell is in both, and [method
## BrickLattice.brick_at] names only the first: where that was the stud's
## own part the stud was in nothing. So on a part in an overlapped pair a
## tip is read in a part but its own ([method BrickLattice.bricks_at]), and
## a tip in none is looked round: in a turned 1 x 1 cone's hollow underside
## it is in no cover, and 1793-1's cones on its tilted round plates stood on
## no stud (2026-10-21). Of several, it is in the one with a socket where
## the stud stands, else the first ([method _taking]): a third part's
## cover can come first. Picking the part sitting on the stud's foot
## instead mended 1793-1's hinge plates inside its corner panel but moved
## 8466-1's stacked plates onto the bricks beside them; a socket is where
## the stud is, not a face near it.
##
## Studs into a part turned to them off the square ([method turned_to]) hold
## only where it takes them, in a socket facing them or a hole along them
## ([method _takes]), as Bodies reads them; the others are tips in its
## turned cover, which keeps every cell its boxes touch. 6753-1's steering
## plate, laid at 30 degrees on two hinges, stood on a stud of each hinge's
## base as well as on its top. A pair none of whose studs is taken leans on
## them: "seated" and "beside", touching and joined by nothing. One stud
## taken is a pivot: the part turned to it stands at its angle by turning on
## it, and a builder turns it so (Sections reads it as a joint that turns).
##
## A "seated" pair is seated where some box of one part's own cover goes
## into the other's ([method _seated_in]); one that only touches, two turned
## covers side by side, is "beside" too. Asked only [param everywhere].
##
## [param everywhere] false reads a stud's tip only where the lift cannot
## tell: on a part the lift reaches across an overlap, and for a stud not
## pointing up. A stud pointing up into a part that only touches its own is
## then what the lift counts there, as it was before tips were read. The
## status bar's check asks so, after every change: reading every tip, 6,162
## on stability_probe's 800 bricks, doubled what it cost (2026-10-21).
static func stud_joints(contacts: Dictionary, library: PartLibrary,
		lattice: BrickLattice, everywhere: bool = true) -> Dictionary:
	var kept: String = "joints" if everywhere else "joints where unsure"
	if contacts.has(kept):
		return contacts[kept]
	var boxes: Dictionary = contacts["boxes"]
	var above: Dictionary = contacts["above"]
	var overlap: Dictionary = contacts["overlap"]
	var studs: Dictionary = {}
	var under: Dictionary = {}
	var sideways: Dictionary = {}
	var seated: Dictionary = {}
	var overlapped: Dictionary = {}
	var unsure: Dictionary = {}        ## id -> true for a part in an overlapped pair
	for low: Variant in above:
		if not boxes.has(int(low)):
			continue
		var row: Dictionary = above[low]
		for high: Variant in row:
			if int(high) == int(low) or not boxes.has(int(high)):
				continue
			var key: int = pair_of(int(low), int(high))
			var resting: int = int(row[high]) - int(overlap.get(key, 0))
			if resting <= 0:
				seated[key] = true
				continue
			studs[key] = int(studs.get(key, 0)) + maxi(1, roundi(float(resting) / STUD_CELLS))
			under[key] = int(low)
			if overlap.has(key):
				overlapped[key] = true
				unsure[int(low)] = true
				unsure[int(high)] = true
	var entries: Array = []
	var ways_of: Dictionary = {}       ## part id -> its studs' ways, its own frame
	for brick: BrickWorld.Brick in contacts.get("bricks", []):
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		if not everywhere and not unsure.has(brick.id):
			if not ways_of.has(brick.part_id):
				var ways := PackedVector3Array()
				for connector: Lbm.Connector in mesh.connectors:
					if connector.kind == "stud" and connector.gender == "male" \
							and not ways.has(connector.axis.normalized()):
						ways.append(connector.axis.normalized())
				ways_of[brick.part_id] = ways
			var aside: bool = false
			for way: Vector3 in ways_of[brick.part_id]:
				if (brick.transform.basis * way).normalized().y <= 0.5:
					aside = true
					break
			if not aside:
				continue
		entries.append([brick.id, brick.transform, mesh])
	# An Array, not a PackedVector3Array: a packed array read out of a
	# container is a copy, and appending to it kept nothing.
	var tips: Dictionary = {}          ## Vector2i(whose, into) -> [feet, way]
	var placed: Dictionary = {}        ## id -> brick, for a tip in several covers
	if lattice != null:
		# A part in an overlapped pair is where covers overlap: its tip's cell
		# may be its own as well as the part it holds, or a third part's too,
		# and a tip in nothing is looked round, once the stud's foot and way
		# are known ([method _stud_in], [method _taking]).
		for stud: Array in Joints.studs_in(entries, func(tip: Vector3, key: Variant) -> Variant:
				var cell: Vector3i = BrickLattice.to_cell(tip)
				if not unsure.has(int(key)):
					var at: int = lattice.brick_at(cell)
					return at if at != int(key) and boxes.has(at) else null
				var owners: Array = _owners(lattice, cell, int(key), boxes)
				return owners[0] if owners.size() == 1 else owners):
			if stud[1] is Array and (stud[1] as Array).is_empty():
				stud[1] = _stud_in(stud[2], stud[3], int(stud[0]), boxes, lattice)
				if stud[1] == null:
					continue
			elif stud[1] is Array:
				if placed.is_empty():
					for brick: BrickWorld.Brick in contacts.get("bricks", []):
						placed[brick.id] = brick
				stud[1] = _taking(stud[1], stud[2], stud[3], placed, library)
			var by := Vector2i(int(stud[0]), int(stud[1]))
			if not tips.has(by):
				tips[by] = [[], stud[3]]
			((tips[by] as Array)[0] as Array).append(stud[2])
	if not tips.is_empty() and placed.is_empty():
		for brick: BrickWorld.Brick in contacts.get("bricks", []):
			placed[brick.id] = brick
	var askew: Dictionary = {}         ## pair -> Array of [Vector2i by, feet taken, way]
	var by_tips: Dictionary = {}       ## pair -> true where a stud's tip was read
	for by: Vector2i in tips:
		var feet: Array = (tips[by] as Array)[0]
		var key: int = pair_of(by.x, by.y)
		by_tips[key] = true
		overlapped.erase(key)
		var whose: BrickWorld.Brick = placed.get(by.x)
		var into: BrickWorld.Brick = placed.get(by.y)
		if whose != null and into != null and turned_to(whose.transform.basis, into.transform.basis):
			var way: Vector3 = (tips[by] as Array)[1]
			var mesh: Lbm.PartMesh = library.mesh_for(into.part_id)
			var taken: Array = feet.filter(func(foot: Vector3) -> bool:
				return mesh != null and _takes(into.transform, mesh, foot, way))
			if not askew.has(key):
				askew[key] = []
			(askew[key] as Array).append([by, taken, way])
			continue
		if feet.size() <= int(studs.get(key, 0)):
			continue
		studs[key] = feet.size()
		under[key] = by.x
		sideways.erase(key)
		if ((tips[by] as Array)[1] as Vector3).y <= 0.5:
			sideways[key] = [PackedVector3Array(feet), (tips[by] as Array)[1]]
	# Studs into a part turned to them off the square hold only where it
	# takes them, as Bodies reads them: the rest are tips in its turned
	# cover, which keeps every cell its boxes touch. One so taken is a pivot.
	var pivots: Dictionary = {}
	var beside: Dictionary = {}
	for key: int in askew:
		var most: Array = []
		var count: int = 0
		for one: Array in askew[key]:
			count += (one[1] as Array).size()
			if most.is_empty() or (one[1] as Array).size() > (most[1] as Array).size():
				most = one
		sideways.erase(key)
		if count == 0:
			# It leans on a stud it does not take: touching, held by nothing.
			studs.erase(key)
			under.erase(key)
			seated[key] = true
			beside[key] = true
			continue
		studs[key] = count
		under[key] = (most[0] as Vector2i).x
		var way: Vector3 = most[2]
		if way.y <= 0.5:
			sideways[key] = [PackedVector3Array(most[1]), way]
		if count == 1:
			pivots[key] = [(most[1] as Array)[0], way]
	# And a pair turned to each other that the lift alone stood one on the
	# other, no stud's tip in either: a turned cover rests on the other's
	# cells, and leans there. 6753-1's steering plate, laid at 30 degrees on
	# its hinges' tops, rested so on their bases. Not for the status bar's
	# check, which keeps the lift's reading.
	if everywhere:
		var turned: Dictionary = {}    ## id -> turned off the world's square
		for key: int in studs.keys():
			if by_tips.has(key) or overlapped.has(key):
				continue
			var ends: Array = [key >> 32, key & 0xFFFFFFFF]
			var any: bool = false
			for id: int in ends:
				if not turned.has(id):
					if placed.is_empty():
						for brick: BrickWorld.Brick in contacts.get("bricks", []):
							placed[brick.id] = brick
					var brick: BrickWorld.Brick = placed.get(id)
					turned[id] = brick != null and turned_to(Basis.IDENTITY, brick.transform.basis)
				any = any or bool(turned[id])
			if not any or not turned_to((placed[ends[0]] as BrickWorld.Brick).transform.basis,
					(placed[ends[1]] as BrickWorld.Brick).transform.basis):
				continue
			studs.erase(key)
			under.erase(key)
			sideways.erase(key)
			seated[key] = true
			beside[key] = true
	for key: int in studs:
		seated.erase(key)
	# A pair the lift reaches only where the two already overlap is seated
	# where one part's own boxes go into the other's; where they only touch,
	# it is two turned covers side by side, joined by nothing. Not asked of
	# the status bar's check, which weighs what rests on what and no joint.
	for key: int in seated:
		if beside.has(key) or not everywhere:
			continue
		if placed.is_empty():
			for brick: BrickWorld.Brick in contacts.get("bricks", []):
				placed[brick.id] = brick
		var one: BrickWorld.Brick = placed.get(key >> 32)
		var other: BrickWorld.Brick = placed.get(key & 0xFFFFFFFF)
		if one != null and other != null and not _seated_in(one, other, library):
			beside[key] = true
	var out: Dictionary = {"studs": studs, "under": under, "sideways": sideways,
		"seated": seated, "overlapped": overlapped, "pivots": pivots, "beside": beside}
	contacts[kept] = out
	return out


## Two parts turned to each other further off the square than this, as the
## cosine of the angle: 1 degree. A file's turns written to three places
## (0.999, 0.036) are square.
const ASKEW_COS := 0.99985


## Whether parts turned [param one] and [param other] stand turned to each
## other off the square: their studs and sockets on grids that do not meet.
static func turned_to(one: Basis, other: Basis) -> bool:
	var between: Basis = one.orthonormalized().inverse() * other.orthonormalized()
	for c: int in 3:
		var column: Vector3 = between[c].normalized()
		if maxf(absf(column.x), maxf(absf(column.y), absf(column.z))) < ASKEW_COS:
			return true
	return false


## Whether a part at [param at] takes a stud standing at [param foot] and
## pointing [param way]: in one of its sockets facing it, or in a pin or
## axle hole along it, its tip within the hole (Bodies._takes_stud).
static func _takes(at: Transform3D, mesh: Lbm.PartMesh, foot: Vector3, way: Vector3) -> bool:
	if Joints.socket_at(at, mesh, foot, way):
		return true
	var tip: Vector3 = foot + way * Joints.STUD_REACH
	for end: JointSnap.End in JointSnap.ends_of(mesh):
		if not end.is_hole():
			continue
		var hole: JointSnap.End = end.placed(at, 0)
		if absf(hole.axis.dot(way)) < 0.99:
			continue
		var gap: Vector3 = tip - hole.at
		var along: float = gap.dot(hole.axis)
		if absf(along) <= hole.reach + 1.0 and (gap - hole.axis * along).length() <= 2.0:
			return true
	return false


## How far one part's own boxes must go into another's to be seated in it,
## LDU: half a cell. Two turned plates side by side touch to a hundredth.
const SEAT_DEPTH := 1.0


## Whether [param one] and [param other] are seated one in the other: some
## box of one's own cover (Lbm.PartMesh.boxes, as it is turned) goes into
## one of the other's past [constant SEAT_DEPTH] every way (the separating
## axes of two boxes). A turned part's lattice cover keeps every cell its
## boxes touch, so two such covers side by side overlap where the parts
## only touch: 6753-1's trailer, drawn tipped 2 degrees, had its plates
## side by side read as seated in each other. A part with no boxes, or
## stretched, is taken as seated, as the lift says. A cover that fills a
## hollow seats what stands in it: 1793-1's figure in its corner panel.
static func _seated_in(one: BrickWorld.Brick, other: BrickWorld.Brick, library: PartLibrary) -> bool:
	var a_mesh: Lbm.PartMesh = library.mesh_for(one.part_id)
	var b_mesh: Lbm.PartMesh = library.mesh_for(other.part_id)
	if a_mesh == null or b_mesh == null or a_mesh.boxes.is_empty() or b_mesh.boxes.is_empty():
		return true
	for at: Transform3D in [one.transform, other.transform]:
		for c: int in 3:
			if absf(at.basis[c].length() - 1.0) > 0.01:
				return true
	# The other's boxes in one's own frame.
	var between: Transform3D = one.transform.orthonormalized().affine_inverse() \
		* other.transform.orthonormalized()
	var axes: Array[Vector3] = [between.basis[0], between.basis[1], between.basis[2]]
	var a_cell: float = a_mesh.cell_ldu
	var b_cell: float = b_mesh.cell_ldu
	for b_box: AABB in b_mesh.boxes:
		var b_half: Vector3 = b_box.size * b_cell * 0.5
		var b_mid: Vector3 = between * (b_box.position * b_cell + b_half)
		var reach := Vector3.ZERO
		for c: int in 3:
			reach += (axes[c] * b_half[c]).abs()
		for a_box: AABB in a_mesh.boxes:
			var a_half: Vector3 = a_box.size * a_cell * 0.5
			var gap: Vector3 = b_mid - (a_box.position * a_cell + a_half)
			# The box round the other's turned box first, then every axis.
			var room: Vector3 = a_half + reach - gap.abs()
			if room[room.min_axis_index()] <= SEAT_DEPTH:
				continue
			if _into(a_half, b_half, axes, gap):
				return true
	return false


## Whether a box of half size [param a_half] square in its frame and one of
## [param b_half] along [param axes], [param gap] between their middles, go
## one into the other past [constant SEAT_DEPTH] along every separating axis.
static func _into(a_half: Vector3, b_half: Vector3, axes: Array[Vector3], gap: Vector3) -> bool:
	var tried: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	tried.append_array(axes)
	for a: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		for b: Vector3 in axes:
			var across: Vector3 = a.cross(b)
			if across.length_squared() > 1e-6:
				tried.append(across.normalized())
	for line: Vector3 in tried:
		var a_reach: float = absf(line.x) * a_half.x + absf(line.y) * a_half.y + absf(line.z) * a_half.z
		var b_reach: float = 0.0
		for c: int in 3:
			b_reach += absf(axes[c].dot(line)) * b_half[c]
		if a_reach + b_reach - absf(gap.dot(line)) <= SEAT_DEPTH:
			return false
	return true


## A stud's radius, LDU: 4.8 mm across.
const STUD_RADIUS := 6.0


## The parts of [param boxes] but [param own] whose covers have [param cell].
static func _owners(lattice: BrickLattice, cell: Vector3i, own: int,
		boxes: Dictionary) -> Array:
	var out: Array = []
	for id: int in lattice.bricks_at(cell, own):
		if boxes.has(id):
			out.append(id)
	return out


## Of [param owners], the parts whose covers have a stud's tip, the first
## with a socket where the stud stands at [param foot] and pointing [param
## way] (Joints.socket_at), else the first.
## A turned part's cover keeps every cell its boxes touch, so a third part's
## can be named before the part the stud is in: 1793-1's hinge plates, tilted
## inside its corner panel, were read as standing in the panel, not in the
## plate on them.
static func _taking(owners: Array, foot: Vector3, way: Vector3, placed: Dictionary,
		library: PartLibrary) -> int:
	for id: int in owners:
		var brick: BrickWorld.Brick = placed.get(id)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if mesh != null and Joints.socket_at(brick.transform, mesh, foot, way):
			return id
	return int(owners[0])


## What a stud standing at [param foot] and pointing [param way], whose tip
## is in no part but its own, is in: a hollow the cover leaves open, a
## round brick's, a cone's or a dish's underside, so the first part of
## [param boxes] but [param own] round its tip on five of six sides, half a
## cell past its radius, as a peg in a hole is read (Joints.pushed_in): a
## cell's coarseness leaves one side of a 1 x 1 cone's thin wall out. Null
## for none.
static func _stud_in(foot: Vector3, way: Vector3, own: int, boxes: Dictionary,
		lattice: BrickLattice) -> Variant:
	var tip: Vector3 = foot + way * Joints.STUD_REACH
	var across: Vector3 = way.cross(Vector3.UP if absf(way.y) < 0.9 else Vector3.RIGHT).normalized()
	var other: Vector3 = way.cross(across).normalized()
	var sides: Dictionary = {}         ## id -> sides it is on
	for n: int in 6:
		var turn: float = TAU * float(n) / 6.0
		var point: Vector3 = tip + (across * cos(turn) + other * sin(turn)) * (STUD_RADIUS + 1.5)
		for id: int in _owners(lattice, BrickLattice.to_cell(point), own, boxes):
			sides[id] = int(sides.get(id, 0)) + 1
		if n == 1 and sides.is_empty():
			return null
	for id: int in sides:
		if int(sides[id]) >= 5:
			return id
	return null


## Who hands its weight to whom, from [param joints] ([method
## stud_joints]): id -> {the id of each part carrying it: the studs between
## them, 0 for a part held by no stud}. A stud joint whose studs point up is
## carried by the part with the studs. One whose studs point sideways or
## down, a part seated in another and a pair "overlapped" (no stud's tip in
## either) are carried by whichever of the two comes later in [param order],
## the weighing's top-down order.
static func _carriers(order: Array, joints: Dictionary) -> Dictionary:
	var rank: Dictionary = {}
	for n: int in order.size():
		rank[(order[n] as BrickWorld.Brick).id] = n
	var out: Dictionary = {}
	var studs: Dictionary = joints["studs"]
	var under: Dictionary = joints["under"]
	var sideways: Dictionary = joints["sideways"]
	var overlapped: Dictionary = joints["overlapped"]
	for by_studs: bool in [true, false]:
		for key: int in (studs if by_studs else joints["seated"]):
			var one: int = key >> 32
			var other: int = key & 0xFFFFFFFF
			if not rank.has(one) or not rank.has(other):
				continue
			var held: int = int(studs[key]) if by_studs and not overlapped.has(key) else 0
			var low: int = one if int(rank[one]) > int(rank[other]) else other
			if held > 0 and not sideways.has(key):
				low = int(under[key])
			var high: int = other if low == one else one
			if not out.has(high):
				out[high] = {}
			out[high][low] = held
	return out


## Whether [param brick]'s stud joints hold the [param grams] handed down
## to it through them: [param studs], the studs what is on it stands on.
func _assess(brick: BrickWorld.Brick, grams: float, studs: int) -> Risk:
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
	world: BrickWorld, mass: Dictionary, boxes_of: Dictionary, report: Report
) -> void:
	var bricks: Array = world.bricks()
	if bricks.size() < 2:
		return

	# Group by the height each brick starts at, in whole cells.
	var levels: Dictionary = {}        ## cell y -> Array[Brick]
	## id -> the lowest cell it occupies, worked out once.
	var stands_at: Dictionary = {}
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var boxes: PackedInt32Array = boxes_of.get(brick.id, PackedInt32Array())
		if boxes.is_empty():
			continue
		var corners: Array = BrickLattice.corners_in(boxes)
		var floor_y: int = (corners[0] as Vector3i).y
		stands_at[brick.id] = floor_y
		if not levels.has(floor_y):
			levels[floor_y] = []
		levels[floor_y].append(brick)

	var heights: Array = levels.keys()
	heights.sort()
	if heights.size() < 2:
		return

	# Everything above each cut, summed once from the top down, rather than
	# summed again over the whole model at every cut; and the footprint
	# below each cut grown from the bottom up the same way. Asked of every
	# brick at every course, this was 3.3 s of the 3.5 s the check took on
	# the Falcon Heavy's 4,242 parts — 332 plates tall, so about seven
	# hundred cuts — and the app asks it after every change.
	var count: int = heights.size()
	var level_of: Dictionary = {}      ## cell y -> its index in heights
	for n: int in count:
		level_of[heights[n]] = n
	var above_grams := PackedFloat64Array()
	above_grams.resize(count + 1)
	var above_x := above_grams.duplicate()
	var above_y := above_grams.duplicate()
	var above_z := above_grams.duplicate()
	for id: int in stands_at:
		var n: int = level_of[stands_at[id]]
		var w: float = mass.get(id, 0.0)
		var middle: Vector3 = _middle(world.get_brick(id))
		above_grams[n] += w
		above_x[n] += middle.x * w
		above_y[n] += middle.y * w
		above_z[n] += middle.z * w
	for n: int in range(count - 1, -1, -1):
		above_grams[n] += above_grams[n + 1]
		above_x[n] += above_x[n + 1]
		above_y[n] += above_y[n + 1]
		above_z[n] += above_z[n + 1]

	# Every box, lowest first, to be taken into the footprint as the cut
	# passes its bottom.
	var flat := PackedInt32Array()
	var order := PackedInt64Array()
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var boxes: PackedInt32Array = boxes_of.get(brick.id, PackedInt32Array())
		var at: int = 0
		while at < boxes.size():
			order.append((int(boxes[at + 1]) + (1 << 30)) * (1 << 31) + flat.size() / 6)
			flat.append_array(boxes.slice(at, at + 6))
			at += 6
	order.sort()
	var taken: int = 0
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)

	for n: int in range(1, count):
		var cut: int = heights[n]

		# The footprint it all stands on: everything below the cut. A box's
		# plan extent does not depend on how much of it is below the cut,
		# only on whether any of it is — so the box itself answers what
		# every one of its cells used to.
		while taken < order.size():
			var at: int = (order[taken] % (1 << 31)) * 6
			if flat[at + 1] >= cut:
				break
			var x_from: float = flat[at] * BrickLattice.CELL
			var z_from: float = flat[at + 2] * BrickLattice.CELL
			var x_to: float = (flat[at + 3] - 1) * BrickLattice.CELL
			var z_to: float = (flat[at + 5] - 1) * BrickLattice.CELL
			lo = Vector2(minf(lo.x, x_from), minf(lo.y, z_from))
			hi = Vector2(maxf(hi.x, x_to), maxf(hi.y, z_to))
			taken += 1

		# Everything above the cut, and where its mass sits.
		var grams: float = above_grams[n]
		if grams <= 0.0:
			continue
		var centre := Vector3(above_x[n], above_y[n], above_z[n]) / grams
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
## cavity instead got the trend right as well as the magnitude, but ran
## light on longer parts — a 2x4 at 2.08 g, 11% under the 2.32 it weighs,
## and a 2x6 22% under — because the tubes under them are plastic too.
## Counted, against BrickLink's catalogue weights (2026-10-13):
##
##     part     this    BrickLink   without the tubes
##     1x1      0.47 g    0.44 g      0.47 g
##     1x2      0.87 g    0.83 g      0.80 g
##     2x2      1.35 g    1.35 g      1.22 g
##     1x4      1.67 g    1.64 g      1.45 g
##     2x4      2.46 g    2.32 g      2.08 g
##     2x6      3.56 g    3.74 g      2.93 g
##     1x8      3.28 g    3.21 g      2.77 g
##
## Every one within 6%. StableLego weighed a 2x4 at 2.16 g and a 1x8 at
## 3.03 (docs/MECHANISMS.md §2), so the weighings themselves differ by
## that much. There is no mass table in the catalogue to look up instead;
## this has to answer for 29,000 parts, most of which nobody has weighed.
## Balance and Stability compare a model with itself, so an error that
## biases the whole model the same way mostly cancels.
static func grams(info: PartLibrary.PartInfo) -> float:
	# A flexible part's skin (CustomParts.begin_skins) runs across the model,
	# and its box is most of the model's: weighed as a shell of that box,
	# 42082's rope came to 1.3 kg. By its cover instead, a block of 4 LDU a
	# side for each of its boxes, a third of it plastic: the rope 1.5 g.
	if info.category == CustomParts.SKIN_CATEGORY:
		return info.box_count * pow(BrickLattice.CELL * PartForge.SKIN_BLOCK, 3.0) / 3.0 \
			/ CUBIC_LDU_PER_CM3 * DENSITY_G_PER_CM3
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
	# The tubes or posts standing in the cavity, on a part with an underside
	# to take studs and a footprint of whole studs.
	var across: int = roundi(width / BrickLattice.STUD)
	var deep: int = roundi(depth / BrickLattice.STUD)
	if cavity > 0.0 and info.socket_count > 0 \
			and absf(width - across * BrickLattice.STUD) < 1.0 \
			and absf(depth - deep * BrickLattice.STUD) < 1.0:
		var tall: float = maxf(height - TOP_LDU, 0.0)
		if mini(across, deep) >= 2:
			material += (across - 1) * (deep - 1) * PI * tall \
				* (TUBE_OUT_LDU * TUBE_OUT_LDU - TUBE_IN_LDU * TUBE_IN_LDU)
		elif maxi(across, deep) >= 2:
			material += (maxi(across, deep) - 1) * PI * tall * POST_LDU * POST_LDU
	return (material / CUBIC_LDU_PER_CM3) * DENSITY_G_PER_CM3


## Where a part's mass is: the middle of its shape.
##
## Not its origin, which LDraw puts on top of the body — the face a stud
## stands on. Weighed at their origins a stack's centre came out half a
## part too high, which on a tall narrow thing is the difference between
## standing and top-heavy: a minifigure on its two studs, every part of
## it hung from the top, read as about to tip.
func _middle(brick: BrickWorld.Brick) -> Vector3:
	var part: Lbm.PartMesh = library.mesh_for(brick.part_id) if library != null else null
	if part == null:
		return brick.transform.origin
	return brick.transform * part.bounds.get_center()


## The cells a brick occupies, as boxes — the lattice's own answer where
## it has one.
##
## Both sides of "is this resting on that" have to come from the same
## account of where a brick is, and the version this replaced did not:
## it took the *span* of a turned part's boxes for the lower brick and
## asked the lattice, which holds the exact cells, about the upper one.
## Measured over the eleven models here, that disagreed on two — the
## kart and the lighthouse, the two with turned parts — reporting 41
## joints where there are 42 and 56 where there are 58. No verdict
## changed on any of them, because `joints` is a count and not a
## judgement, but a contact graph that disagrees with the collision
## lattice about what is touching what is a bug waiting for a model that
## cares.
##
## Deriving it is the fallback, for a world holding a brick the lattice
## does not: scenery, or a model opened without being registered. A
## brick with no boxes would otherwise read as weightless rather than as
## unknown.
func _boxes(brick: BrickWorld.Brick) -> PackedInt32Array:
	if lattice != null:
		var known: PackedInt32Array = lattice.boxes_of(brick.id)
		if not known.is_empty():
			return known
	return _derive_boxes(brick)


func _derive_boxes(brick: BrickWorld.Brick) -> PackedInt32Array:
	var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
	if part == null:
		return PackedInt32Array()
	var boxes: Array[AABB] = part.boxes
	if boxes.is_empty():
		return PackedInt32Array()
	var at: Vector3i = BrickLattice.to_cell(brick.transform.origin)
	if BrickLattice.is_square_to_grid(brick.transform.basis):
		var square: PackedInt32Array = BrickLattice.boxes_for(boxes, at, brick.transform.basis)
		# As the builder reckons it: square and off the lattice, kept
		# inside the part.
		if BrickLattice.is_off_lattice(brick.transform.origin):
			return BrickLattice.within(square, part.bounds, brick.transform)
		return square
	return BrickLattice.boxes_for_turned(boxes, at, brick.transform.basis)
