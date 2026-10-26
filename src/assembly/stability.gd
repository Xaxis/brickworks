## Whether a model would stand up, and where it would fail first.
##
## Connection and support say a model is *assembled*. They say nothing
## about whether it holds together once gravity is applied: a tower of
## single bricks is connected and supported and falls over, and a long
## cantilever is connected and supported and snaps at the root.
##
## What this does
## --------------
## It asks of every course whether what is above it leans past what holds
## it or stands too tall on it, and of the whole whether it tips over on
## what it stands on. With [member with_margins], it weighs every stud joint
## that alone holds what is past it as Balance does, levered about the edge
## it would turn on, and a joint past its studs' working load is a weak one;
## so is a piece standing on touches alone with its weight past them.
##
## A load goes only through what joins parts: studs, pins, axles, clips,
## hinges. A touch, one face on another, carries weight straight down into
## what is under it, and nothing hangs from it or levers on it (Balance).
## The weight pressing down on a joint's studs is not weighed: a stud
## pressed on holds whatever presses it. That was a check here, 80 g a
## stud, and the one real set it flagged, 75060-1, was a 1x1 plate pressed
## by 160 g.
##
## What this is not
## ----------------
## Not a force-balance solve. The published approach sets up a quadratic
## program over friction, support and normal forces at every contact and
## minimises the worst friction margin; it is exact, it names the failing
## contact, and it runs in milliseconds — but it needs a QP solver.
##
## This is the honest subset that can run on every edit without one. It
## catches the failures that actually happen — a joint levered or pulled
## past what its studs hold, a load hanging past its footprint, and a load
## stacked too high over too small a base — and it reports a margin rather
## than a verdict so the difference shows. It will not catch a structure
## that fails through an interior path rather than at a joint.
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
	## "levered" (a joint past its studs' working load), "rests on a touch",
	## "leaning", "top-heavy" or "tips"
	var kind: String
	var margin: float       ## < 1 is failing; 2 means twice the strength needed
	var carrying_grams: float
	var studs: int
	var message: String


class Report extends RefCounted:
	var risks: Array[Risk] = []
	var total_grams: float = 0.0
	var joints: int = 0
	var weakest: Risk = null
	## With [member Stability.with_margins]: every stud joint that alone
	## holds what is past it, weighed as Balance weighs it, by the part past
	## it — the brick above it, or the one hung under it: id ->
	## Balance.JointLoad, whose margin is 1 / ratio. A joint that shares
	## its load with others is in none: statics alone cannot say what it
	## carries, and it is never the one that gives first.
	var margins: Dictionary = {}
	## ...and how each part none of them holds is held (Balance.Report.held),
	## and the pieces standing on a touch alone past where they touch
	## (Balance.Report.tipping), heaviest first.
	var held: Dictionary = {}
	var tipping: Array = []

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
## Set to have [method check] weigh every stud joint's margin as well
## ([member Report.margins]), from the contacts it reads anyway, and say a
## joint past its working load and a piece tipping off a touch as weak:
## the status bar's verdict, View, Stress (StressView) and a session's
## weakest_joints all ask so, and agree.
var with_margins: bool = false


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
	for item: Variant in bricks:
		if above.has((item as BrickWorld.Brick).id):
			report.joints += 1

	_check_levels(world, mass, boxes_of, report)
	if stopped:
		return null
	_check_tipping(bricks, mass, boxes_of, report)
	if with_margins:
		_weigh_margins(bricks, graph, report)
		if stopped:
			return null

	report.risks.sort_custom(func(a: Risk, b: Risk) -> bool:
		return a.margin < b.margin)
	if not report.risks.is_empty():
		report.weakest = report.risks[0]
	return report


## Every stud joint's margin, as Balance weighs it with the model as it
## stands: the moment about the edge it would turn on, against what its studs
## hold there. Not the weight on a joint's studs, which [method _assess]
## weighs: a stud pressed on holds whatever presses it, and a joint fails by
## being levered or pulled off.
func _weigh_margins(bricks: Array, graph: Dictionary, report: Report) -> void:
	var weigher := Balance.new()
	weigher.library = library
	weigher.lattice = lattice
	weigher.floor_ids = floor_ids
	var weighed: Balance.Report = weigher.measure(bricks, [], null, graph)
	for one: Balance.JointLoad in weighed.joints:
		report.margins[one.beyond] = one
		if one.ratio <= 1.0 or floor_ids.has(one.beyond):
			continue
		var risk := Risk.new()
		risk.brick_id = one.beyond
		risk.kind = "levered"
		risk.margin = 1.0 / one.ratio
		risk.carrying_grams = one.grams
		risk.studs = one.studs
		risk.message = "%s %s %s %s with %s g past it, %sx its %sworking load" % [
			one.beyond_part, ("hangs from" if one.hangs else "is levered off") if one.kind == "studs"
				else "turns on", one.held_part, one.held_on(), Balance.tidy(one.grams),
			Balance.tidy(one.ratio), "studs' " if one.kind == "studs" else ""]
		report.risks.append(risk)
	for piece: Dictionary in weighed.tipping:
		var risk := Risk.new()
		risk.brick_id = int((piece["ids"] as Array)[0])
		risk.kind = "rests on a touch"
		risk.margin = 0.0
		risk.carrying_grams = float(piece["grams"])
		var on: BrickWorld.Brick = null
		for item: Variant in bricks:
			if (item as BrickWorld.Brick).id == int(piece["on"]):
				on = item
		risk.message = "%s g held by nothing stands on %s by touch alone, %s" % [
			Balance.tidy(float(piece["grams"])), on.part_id if on != null else "what is under it",
			"its weight %s studs past where it touches" % Balance.studs(float(piece["past"]))
				if float(piece["past"]) < 1000.0 else "on an edge too thin to stand on"]
		report.risks.append(risk)
	report.held = weighed.held
	report.tipping = weighed.tipping


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
	# What is below the floor's top is in it: a string hanging through the
	# baseplate is not what the model stands on (Balance.floor_top).
	var hull: PackedVector2Array = Balance.support_of(model, 0x7FFFFFFF,
		_floor_top(boxes_of))["hull"]
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


## The top cell of [member floor_ids]' parts, by [param boxes_of], or unset
## for no floor (Balance.floor_top).
func _floor_top(boxes_of: Dictionary) -> int:
	var top: int = 0x7FFFFFFF
	for id: Variant in floor_ids:
		var under: PackedInt32Array = boxes_of.get(id, PackedInt32Array())
		for at: int in range(0, under.size(), 6):
			top = under[at + 4] if top == 0x7FFFFFFF else maxi(top, under[at + 4])
	return top


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
	# A turned part's many slices sorted once, for every brick it might
	# carry or rest on; and every brick whose bounds meet it counted
	# outright, the count being the test. Asking the lattice which ones
	# touch first compared the same boxes twice: on Orthanc that was 3.9 s,
	# and counting box against box 6.5 s more.
	var sliced: Dictionary = {}        ## id -> BrickLattice.slices_of its boxes, or []
	# Each pair once, both ways: what rests on each counted in one pass
	# (BrickLattice.shared_lifted), the other way only for a part asked of.
	var asked: Dictionary = {}
	for item: Variant in bricks:
		asked[(item as BrickWorld.Brick).id] = true
	var compared: Dictionary = {}      ## pair_of -> true
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
		var slices: Array = _sliced(sliced, brick.id, mine)
		for over: int in lattice.near_bounds(lid, brick.id):
			# Skipping pairs whose boxes already overlap was tried, on
			# the theory that a part inside another is not resting on
			# it. It is wrong, and measurably: a stud belongs to the
			# brick below and reaches into the brick above, so nearly
			# every real joint overlaps. The kart went from 42 joints to
			# 14 and the car from 53 to 44. What the two share as they
			# stand is counted in the same pass, for stud_joints.
			var pair: int = pair_of(brick.id, over)
			if compared.has(pair):
				continue
			compared[pair] = true
			var theirs: PackedInt32Array = lattice.boxes_of(over)
			var shared: Vector3i = BrickLattice.shared_lifted(mine, slices, theirs,
				_sliced(sliced, over, theirs))
			var back: bool = shared.z > 0 and asked.has(over)
			if shared.x > 0:
				if not above.has(brick.id):
					above[brick.id] = {}
				above[brick.id][over] = int(above[brick.id].get(over, 0)) + shared.x
			if back:
				if not above.has(over):
					above[over] = {}
				above[over][brick.id] = int(above[over].get(brick.id, 0)) + shared.z
			if shared.y > 0 and (shared.x > 0 or back):
				overlap[pair] = shared.y

	return {"above": above, "boxes": boxes_of, "bricks": bricks, "overlap": overlap}


## [param boxes]' slices (BrickLattice.slices_of), kept in [param sliced] by
## [param id], or [] for a part of fewer boxes than [constant SLICED_FROM].
static func _sliced(sliced: Dictionary, id: int, boxes: PackedInt32Array) -> Array:
	var slices: Variant = sliced.get(id)
	if slices == null:
		slices = BrickLattice.slices_of(boxes) if boxes.size() >= SLICED_FROM * 6 else []
		sliced[id] = slices
	return slices


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
## the square, which turns on that stud (below), "resting": pair -> the id of
## the part under, for a pair the lift stood one on the other that no stud
## joins, "seated" and "beside" too: one face on another (below)}. Only pairs of those parts; worked out once and kept in [param
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
## into the other's; one that only touches, two turned covers side by side,
## is "beside" too, once [method beside] is asked.
##
## [param everywhere] false reads a stud's tip only where the lift cannot
## tell: on a part the lift reaches across an overlap, and for a stud not
## pointing up. A stud pointing up into a part that only touches its own is
## then what the lift counts there, as it was before tips were read, and a
## face resting on a face is a stud joint, never "resting". The
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
	# And a pair the lift alone stood one on the other with no stud of either
	# in the other: a face resting on a face. walk180's tug (2026-10-23) had
	# its forecastle's ladder standing on the deck on two rails 4 LDU square,
	# between the deck's studs: 8 cells, which the lift counted a stud, and
	# that stud shared the bow's load with the four that held it, so none of
	# them was weighed. It is touching, joined by nothing ("seated" and
	# "beside"), and "resting" names the part under: what stands on a touch
	# can rest there (Balance), but nothing hangs from one or levers on it.
	var resting: Dictionary = {}
	if everywhere:
		for key: int in studs.keys():
			if by_tips.has(key) or overlapped.has(key):
				continue
			if placed.is_empty():
				for brick: BrickWorld.Brick in contacts.get("bricks", []):
					placed[brick.id] = brick
			var low: BrickWorld.Brick = placed.get(int(under[key]))
			var high: BrickWorld.Brick = placed.get((key >> 32) if int(under[key]) != (key >> 32)
				else (key & 0xFFFFFFFF))
			if low == null or high == null or _stud_between(low, high, boxes, library, lattice):
				continue
			resting[key] = int(under[key])
			studs.erase(key)
			under.erase(key)
			sideways.erase(key)
			seated[key] = true
			beside[key] = true
	for key: int in studs:
		seated.erase(key)
	var out: Dictionary = {"studs": studs, "under": under, "sideways": sideways,
		"seated": seated, "overlapped": overlapped, "pivots": pivots, "beside": beside,
		"resting": resting}
	contacts[kept] = out
	return out


## Of [param contacts]' seated pairs ([method stud_joints]' "seated"), those
## that only touch, joined by nothing: its "beside", and each seated pair
## whose own boxes do not go one into the other ([method _seated_in]): two
## turned covers side by side. What joins a section asks it; Balance, which
## weighs what rests on what, does not, and stud_joints stays as quick as it
## was: read with it, 8466-1's 589 seated pairs took 28 ms to 93-184.
## Worked out once and kept with the joints.
static func beside(contacts: Dictionary, library: PartLibrary, lattice: BrickLattice) -> Dictionary:
	var joints: Dictionary = stud_joints(contacts, library, lattice)
	if joints.has("beside read"):
		return joints["beside"]
	var out: Dictionary = joints["beside"]
	var placed: Dictionary = {}
	for brick: BrickWorld.Brick in contacts.get("bricks", []):
		placed[brick.id] = brick
	for key: int in joints["seated"]:
		if out.has(key):
			continue
		var one: BrickWorld.Brick = placed.get(key >> 32)
		var other: BrickWorld.Brick = placed.get(key & 0xFFFFFFFF)
		if one != null and other != null and not _seated_in(one, other, library):
			out[key] = true
	joints["beside read"] = true
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
	# Two parts square to the lattice and on it have covers to the cell: what
	# they share is plastic in plastic. Only a turned cover is rounded out.
	if BrickLattice.is_square_to_grid(one.transform.basis) and BrickLattice.is_square_to_grid(other.transform.basis) \
			and not BrickLattice.is_off_lattice(one.transform.origin) \
			and not BrickLattice.is_off_lattice(other.transform.origin):
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
		var near: Vector3 = a_mesh.bounds.size * 0.5 + Vector3.ONE * a_cell + reach \
			- (b_mid - a_mesh.bounds.get_center()).abs()
		if near[near.min_axis_index()] <= SEAT_DEPTH:
			continue
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


## Whether a stud of [param low] pointing up, or of [param high] pointing
## down, stands in the other: its tip in the other's cover, or in a hollow
## of it ([method _stud_in]), as a stud in a round brick's underside is. Only
## the studs over the other's footprint are asked, so a baseplate's
## thousands are not.
static func _stud_between(low: BrickWorld.Brick, high: BrickWorld.Brick, boxes: Dictionary,
		library: PartLibrary, lattice: BrickLattice) -> bool:
	for pair: Array in [[low, high, 1.0], [high, low, -1.0]]:
		var whose: BrickWorld.Brick = pair[0]
		var into: BrickWorld.Brick = pair[1]
		var mesh: Lbm.PartMesh = library.mesh_for(whose.part_id)
		var other: Lbm.PartMesh = library.mesh_for(into.part_id)
		if mesh == null or other == null:
			continue
		var span: AABB = (into.transform * other.bounds).grow(STUD_RADIUS)
		var only: Dictionary = {into.id: boxes.get(into.id)}
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind != "stud" or connector.gender != "male":
				continue
			var way: Vector3 = (whose.transform.basis * connector.axis).normalized()
			if way.y * float(pair[2]) < 0.5:
				continue
			var foot: Vector3 = whose.transform * connector.position
			if foot.x < span.position.x or foot.x > span.end.x \
					or foot.z < span.position.z or foot.z > span.end.z:
				continue
			var tip: Vector3 = foot + way * Joints.STUD_REACH
			if lattice.bricks_at(BrickLattice.to_cell(tip), whose.id).has(into.id) \
					or _stud_in(foot, way, whose.id, only, lattice) != null:
				return true
	return false


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

	# Group by the height each brick starts at, in whole cells: on a floor,
	# no lower than its top, since what is below that is in it.
	var levels: Dictionary = {}        ## cell y -> Array[Brick]
	## id -> the lowest cell it occupies, worked out once.
	var stands_at: Dictionary = {}
	var top: int = _floor_top(boxes_of)
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var boxes: PackedInt32Array = boxes_of.get(brick.id, PackedInt32Array())
		if boxes.is_empty():
			continue
		var corners: Array = BrickLattice.corners_in(boxes)
		var floor_y: int = (corners[0] as Vector3i).y
		if top != 0x7FFFFFFF and not floor_ids.has(brick.id):
			floor_y = maxi(floor_y, top)
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
