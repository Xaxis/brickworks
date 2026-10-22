## A solid said as a shape, laid in the parts a set builder would choose.
##
## The car built for the held-out benchmark was told, every check, to use
## wedge plates, curved slopes and a hinged section, and used none of them:
## its body was plates stacked square. The roadmap's rule held a sixth time
## — words move nothing; one call shaped like the work does. A rocket had
## that call (the round pattern) and came out round. A car, a hull, a bird
## and a fuselage had nothing, so a design built them as boxes.
##
## So a design says the solid and this lays it:
##
##   loft      cross-sections along an axis, each a rounded box or an
##             ellipse that can narrow to a keel — a hull, a car's body, a
##             fuselage, an animal's body
##   extrude   a side profile pulled across a width — a car seen from the
##             side, a wing's section
##   revolve   a profile turned about an axis
##   box       with its plan corners rounded or cut and its top edges rounded
##   ellipsoid and dome
##
## any number of them together ("solids", each with its own colour if it
## wants one), less any number taken away ("cuts": a wheel arch, a cockpit).
## Coordinates are studs across and along and plates up, from "at".
##
## The parts are chosen the way a builder chooses them, by what each part of
## the surface is doing:
##
##   the core       bricks where a whole course is inside, plates where the
##                  surface passes through a course, in a bond
##   a step         where the top falls two plates or more from one stud to
##                  the next, a slope on the lower stud against the higher,
##                  as long as the flat beyond it: a cheese slope for one
##                  stud, a curved slope two plates tall for a step of two,
##                  and for a taller one 45, 33 or 18 degrees for two, three
##                  or four studs, on a plate or a brick to make up the step —
##                  curved for a rounded shape, straight for a chamfered one
##   an overhang    where the foot steps up as far, an inverted slope under it
##   a plan edge    on a diagonal, wedge plates in the plate layers
##   a round        where a layer is a disc 1, 2, 4, 6 or 8 studs across,
##                  the round parts the round pattern lays there (round
##                  plates and bricks, corner rounds round a ring), and a
##                  dish on a dome's crown
##   the top        tiles, so a body reads as a surface and not as studs
##   a flat side    every other course, bricks with studs on their side and a
##                  tile laid flat on them, as a set's flank is
##   a curved side  where it curves up and down, the bulge laid by this plan
##                  turned on its side, on studs out of the core
##   two sides      a shape that is its own mirror is laid as one half and
##                  its mirror, tied across the middle by parts that span it,
##                  so a left wing is never a stud out from a right one
##
## Nothing here knows what a car is.
class_name Shapes
extends RefCounted

## The kinds of solid a shape is made of.
const KINDS: Array[String] = ["loft", "extrude", "revolve", "box", "ellipsoid", "dome"]

## A solid given as a function instead of in numbers: a sculpt or a scan,
## voxelised by Brickify. {"grid": {"from", "size", "colour_at"}}, where
## colour_at(Vector3 studs, plates, studs) is the colour there or -1 outside.
## Not one of KINDS: a design says its solids, it has no function to give.
const GRID := "grid"

## Studs to plates: a stud is 20 LDU across, a plate 8 high.
const PLATES_PER_STUD := 2.5

## A shape that would sample more plate-cells than this is a mistake in the
## numbers (sixty studs by sixty by forty plates is 144,000).
const MOST_CELLS := 160000

## Which way is out, by quarter turn: a slope at rot 0 descends towards +z.
const OUT: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1),
	Vector2i(-1, 0)]

## The core's bricks and plates, largest first: hidden inside a body, where
## the fill's short bricks (kept short so a castle wall has texture) only
## multiply the parts. Laid with these the four held-out bodies came to a
## third fewer parts.
const CORE_BRICKS: Array = [
	[8, 2, "3007", 0], [2, 8, "3007", 1], [6, 2, "2456", 0], [2, 6, "2456", 1],
	[4, 2, "3001", 0], [2, 4, "3001", 1], [3, 2, "3002", 0], [2, 3, "3002", 1],
	[2, 2, "3003", 0], [8, 1, "3008", 0], [1, 8, "3008", 1], [6, 1, "3009", 0],
	[1, 6, "3009", 1], [4, 1, "3010", 0], [1, 4, "3010", 1], [3, 1, "3622", 0],
	[1, 3, "3622", 1], [2, 1, "3004", 0], [1, 2, "3004", 1], [1, 1, "3005", 0],
]
const CORE_PLATES: Array = [
	[8, 6, "3036", 0], [6, 8, "3036", 1], [8, 4, "3035", 0], [4, 8, "3035", 1],
	[6, 6, "3958", 0], [6, 4, "3032", 0], [4, 6, "3032", 1], [8, 2, "3034", 0],
	[2, 8, "3034", 1], [4, 4, "3031", 0], [6, 2, "3795", 0], [2, 6, "3795", 1],
	[4, 2, "3020", 0], [2, 4, "3020", 1], [3, 2, "3021", 0], [2, 3, "3021", 1],
	[2, 2, "3022", 0], [6, 1, "3666", 0], [1, 6, "3666", 1], [4, 1, "3710", 0],
	[1, 4, "3710", 1], [3, 1, "3623", 0], [1, 3, "3623", 1], [2, 1, "3023", 0],
	[1, 2, "3023", 1], [1, 1, "3024", 0],
]

## Tiles for a smooth top, largest first, as Patterns.TILES has plates.
const TOPS: Array = [
	[4, 2, "87079", 0], [2, 4, "87079", 1], [3, 2, "26603", 0], [2, 3, "26603", 1],
	[2, 2, "3068b", 0], [4, 1, "2431", 0], [1, 4, "2431", 1], [3, 1, "63864", 0],
	[1, 3, "63864", 1], [2, 1, "3069b", 0], [1, 2, "3069b", 1], [1, 1, "3070b", 0],
]

## The windscreens a raked front is laid in, where a solid says "screen":
## the way a set builds a cabin or a canopy, a windscreen standing on the
## plates at the foot of its rake, leaning back to the roof, the roof on its
## top studs. The commonest in LDraw's official models first: 92583 and 4176
## six studs across, 3823 and 57783 four. Each read off its own mesh
## (screen_part).
const SCREENS: Array = ["92583", "4176", "3823", "57783"]
## Glass, where a screen names no colour: trans-black, as a set's windscreen
## is; trans-clear where the part was never made in it.
const GLASS: Array = [40, 47]
## A brick laid in glass is the glass brick of its size: a set's trans
## bricks have no tubes under them, and LEGO never made the tubed 1 x 2 and
## 1 x 4 in trans-black.
const GLASS_SWAP: Dictionary = {"3004": "3065", "3010": "3066"}

## Which colours are glass, by code, read once.
static var _glassy: Dictionary = {}

## What each surface part is, read once off its own mesh: "w" studs across
## its fall, "d" along it, "h" plates tall, and "turn", the quarter turns
## that make rot = facing + turn point its fall that way.
static var _parts: Dictionary = {}
## And each windscreen, as screen_part reads it.
static var _screens: Dictionary = {}

## What the last shape laid came to, for a probe to read: its mirror axis
## and the sum a stud and its mirror add up to, its columns and plates.
static var last: Dictionary = {}
## TRY: screen flags, taken out before landing.
static var TRY: String = OS.get_environment("SNOT_TRY")

## What the shapes laid since Patterns.expand began say to the design: a
## part they could not join, a shape standing on nothing. Read into the
## check's advice, so the reason and the fix come with the shape.
static var said: Array = []
## How many parts the shapes laid since then turned out on their sides (side
## shells): a body whose curved flanks are already skinned is not told to
## skin them.
static var turned: int = 0


## The number LDraw gives [param id] today: 3023 says "~Moved to 3023b", and
## a parts list or a booklet given 3023 has no element number for the
## commonest plate there is. Read from the catalogue's stubs, so a part
## LDraw moves later is laid by its new number too. Only where the stub
## moves it nowhere (its moved_by the identity, as for all but 68 of the
## 1,161): a part a stub turns would want its placement turned with it.
static func current(library: PartLibrary, id: String) -> String:
	if library == null:
		return id
	var now: String = library.resolve(id)
	if now == id or library.moved_by(id) != Transform3D.IDENTITY:
		return id
	return now


## Whether [param colour] is glass: a transparent colour.
static func is_glass(library: PartLibrary, colour: int) -> bool:
	if colour < 0 or library == null:
		return false
	if not _glassy.has(colour):
		var found: PartLibrary.BrickColor = library.colors.get(colour)
		_glassy[colour] = found != null and found.is_transparent()
	return bool(_glassy[colour])


## [param part] as it is laid in the glass [param colour]: itself, or its
## glass brick (GLASS_SWAP) where LEGO made that and not it.
static func in_glass(library: PartLibrary, part: String, colour: int) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part) if library != null else null
	if info == null or not info.never_made_in(colour):
		return part
	var swap: String = str(GLASS_SWAP.get(part, ""))
	var other: PartLibrary.PartInfo = library.parts.get(swap) if not swap.is_empty() else null
	return swap if other != null and not other.never_made_in(colour) else part


## Whether [param part] can be laid in [param colour] as LEGO made it: in
## it, or as its glass brick.
static func made_in_glass(library: PartLibrary, part: String, colour: int) -> bool:
	var laid: String = in_glass(library, part, colour)
	var info: PartLibrary.PartInfo = library.parts.get(laid) if library != null else null
	return info == null or not info.never_made_in(colour)


## Every brick of a shape, or a reason in [param trouble].
## Whether a run's [param stop] (Brickify.Progress.stopped) says to stop.
static func _halted(stop: Callable) -> bool:
	return stop.is_valid() and bool(stop.call())


static func lay(pattern: Dictionary, trouble: Array, library: PartLibrary) -> Array:
	# Asked between the steps, a run on a worker that was told to stop
	# (Brickify.Progress) ends at the next: a 64-stud bunny's laying held
	# the app's quit 18 s.
	var stop: Callable = pattern.get("stop", Callable()) as Callable
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var origin := Vector3(float(at.get("x", 0.0)), float(at.get("y", 0.0)),
		float(at.get("z", 0.0)))
	var colour: int = int(pattern.get("color", pattern.get("colour", 15)))
	var solids: Array = _read(pattern, "solids", trouble, true)
	var cuts: Array = _read(pattern, "cuts", trouble, false)
	if not trouble.is_empty():
		return []
	if solids.is_empty():
		trouble.append("a shape wants a solid: \"loft\", \"extrude\", \"revolve\", "
			+ "\"box\", \"ellipsoid\" or \"dome\", or several in \"solids\"")
		return []
	var wheels: Array = _wheels(pattern, solids, cuts, trouble)
	if not trouble.is_empty():
		return []
	# A front said as glass: where each windscreen goes is worked out on the
	# plan, once the solids are sampled (Plan.screen).
	var screens: Array = _screens_asked(solids, trouble)
	if not trouble.is_empty():
		return []
	var bands: Array = []
	for raw: Variant in pattern.get("bands", []):
		if raw is Dictionary:
			bands.append(raw)
	var smooth: bool = str(pattern.get("top", "smooth")).to_lower() != "studs"
	# Every piece kept, for the caller to join or say (Brickify's mend).
	var keep_pieces: bool = bool(pattern.get("keep_pieces", false))
	var surface: String = str(pattern.get("surface", "auto")).to_lower()
	if surface == "auto":
		surface = "straight"
		for solid: Dictionary in solids:
			if bool(solid["round"]):
				surface = "curved"

	# Sampled at the middle of every stud and plate the solids reach.
	var box: AABB = solids[0]["box"]
	for solid: Dictionary in solids:
		box = box.merge(solid["box"])
	var x0: int = floori(box.position.x)
	var x1: int = ceili(box.end.x)
	var z0: int = floori(box.position.z)
	var z1: int = ceili(box.end.z)
	var y0: int = floori(box.position.y)
	var y1: int = ceili(box.end.y)
	var tall: int = y1 - y0
	var faces: Array = _read_faces(pattern, y0, trouble)
	if not trouble.is_empty():
		return []
	# A grid solid says how many cells it has, having been sized to them.
	var most: int = maxi(MOST_CELLS, int(pattern.get("most_cells", 0)))
	if (x1 - x0) * (z1 - z0) * tall > most or tall < 1:
		trouble.append("that shape is %d by %d studs and %d plates, which is a "
			% [x1 - x0, z1 - z0, tall] + "mistake in the numbers rather than a model")
		return []
	var columns: Dictionary = {}    ## Vector2i -> PackedInt32Array, colour or -1
	for x: int in range(x0, x1):
		for z: int in range(z0, z1):
			var column := PackedInt32Array()
			column.resize(tall)
			var any: bool = false
			for j: int in tall:
				var point := Vector3(x + 0.5, y0 + j + 0.5, z + 0.5)
				var here: int = _colour_at(solids, cuts, point, colour, bands)
				column[j] = here
				any = any or here >= 0
			if any:
				columns[Vector2i(x, z)] = column
		if _halted(stop):
			return []
	# A plate of the shape with nothing of it above, below or beside is held
	# by nothing, and a 1 x 1 laid there was reported floating on three of
	# the four first bodies. Left out.
	for key: Variant in columns.keys():
		var cell: Vector2i = key
		var column: PackedInt32Array = columns[cell]
		for j: int in tall:
			if column[j] < 0 or (j > 0 and column[j - 1] >= 0) \
					or (j < tall - 1 and column[j + 1] >= 0) or j == 0:
				continue
			var beside: bool = false
			for step: Vector2i in OUT:
				var other: Variant = columns.get(cell + step)
				if other != null and (other as PackedInt32Array)[j] >= 0:
					beside = true
			if not beside:
				column[j] = -1
		columns[cell] = column
		if column.find(-1) >= 0 and _empty(column):
			columns.erase(cell)
	if columns.is_empty():
		trouble.append("that shape covers nothing: every solid is too small to "
			+ "hold the middle of a stud, or the cuts take all of it")
		return []

	# A sculpt's grid has no sections said round: a scan's 2 x 2 is as likely
	# a square leg as a round one, and Brickify's own lay is left as it was.
	var gridded: bool = false
	for solid: Dictionary in solids:
		gridded = gridded or solid["kind"] == GRID
	# The wheels' Technic bricks and the chassis under them, put among the
	# plan's own parts while it joins its pieces, so it counts what they hold.
	var fixed: Array = []
	for one: Dictionary in wheels:
		var size := Vector2i.ZERO
		var h: int = 1
		if one.has("_size"):
			size = one["_size"]
		elif str(one["part"]) == "32064a":
			size = Vector2i(2, 1)
			h = 3
		var corner := Vector3(float(one["x"]), float(one["y"]), float(one["z"]))
		if size == Vector2i.ZERO or corner != corner.round():
			continue
		var cells: Array[Vector2i] = []
		for i: int in size.x:
			for k: int in size.y:
				cells.append(Vector2i(roundi(corner.x) + i, roundi(corner.z) + k))
		fixed.append({"part": one["part"], "color": one["color"], "x": corner.x,
			"y": roundi(corner.y) - y0, "z": corner.z, "rot": one["rot"], "_cells": cells,
			"_h": h, "_studs": cells, "_base": cells, "_fixed": true})
	var build := func(sideways: bool) -> Array:
		var plan := Plan.new(columns.duplicate(true), tall, smooth, library)
		# Off the ground — on its own wheels, or raised onto what the design
		# builds under it — its foot is held only where something is under it:
		# the chassis, or a brick whose top is there.
		plan.afloat = not fixed.is_empty() or not gridded and roundi(origin.y) + y0 > 0
		for one: Dictionary in fixed:
			if int(one["y"]) + int(one["_h"]) == 0:
				for cell: Vector2i in one["_cells"]:
					plan.foot_held[cell] = true
		var under: Dictionary = pattern.get("_under", {})
		for key: Variant in columns:
			var cell: Vector2i = key
			if under.has(Vector3i(cell.x + roundi(origin.x), roundi(origin.y) + y0,
					cell.y + roundi(origin.z))):
				plan.foot_held[cell] = true
		plan.sides_smooth = bool(pattern.get("panels", true))
		plan.wedges = bool(pattern.get("wedges", true))
		# Columns laid plain, [x, z] from at as columns are counted: no slope,
		# wedge or top tile there, studs showing.
		if pattern.get("plain_at") is Dictionary:
			plan.plain_at = pattern["plain_at"]
			for key: Variant in plan.plain_at:
				if columns.has(key):
					plan.studded[key] = true
		if pattern.get("prefer") is Callable:
			plan.prefer = pattern["prefer"]
		if pattern.get("fine") is Callable:
			plan.fine = pattern["fine"]
		plan.sample = func(x: float, j: float, z: float) -> bool:
			return _colour_at(solids, cuts, Vector3(x, y0 + j, z), colour, bands) >= 0
		# Studs left showing on the studs named, [x, z] from at, for something to
		# stand on: a tower on its plinth stands on bricks, not on tiles.
		for raw: Variant in pattern.get("studs_at", []):
			if raw is Array and (raw as Array).size() >= 2:
				var cell := Vector2i(int(raw[0]), int(raw[1]))
				if columns.has(cell):
					plan.studded[cell] = true
		# And where anything else of the same design stands on this one's
		# top (Patterns.expand): a car's cabin said as a shape on its body
		# stood on the body's tiles, gripping nothing, and the run threw the
		# body away. Stud -> the heights of the feet there, in plates.
		var carried: Dictionary = pattern.get("_carried", {})
		for key: Variant in columns:
			var cell: Vector2i = key
			var world := Vector2i(cell.x + roundi(origin.x), cell.y + roundi(origin.z))
			if not carried.has(world):
				continue
			var heights: Variant = carried[world]
			var column: PackedInt32Array = columns[cell]
			for j: int in range(tall - 1, -1, -1):
				if column[j] >= 0:
					var foot: int = roundi(origin.y) + y0 + j + 1
					if (heights is Array and (heights as Array).has(foot)) \
							or (not heights is Array and foot == int(heights)):
						plan.studded[cell] = true
					break
		# A cut marked "keep" is kept clear of everything: a wedge's cut side, a
		# slope, a panel's tile. A plinth's stair stands in its cut, and the
		# terraces' wedges reached into it.
		for cut: Dictionary in cuts:
			if not bool((cut["spec"] as Dictionary).get("keep", false)):
				continue
			var kept: AABB = cut["box"]
			for x: int in range(floori(kept.position.x), ceili(kept.end.x)):
				for z: int in range(floori(kept.position.z), ceili(kept.end.z)):
					for j: int in tall:
						if _inside(cut, Vector3(x + 0.5, y0 + j + 0.5, z + 0.5)):
							plan.taken[Vector3i(x, j, z)] = true
		plan.colour_at = func(x: float, j: float, z: float) -> int:
			return _colour_at(solids, cuts, Vector3(x, y0 + j, z), colour, bands)
		plan.stop = stop
		plan.rounds = bool(pattern.get("rounds", not gridded))
		plan.bridges = bool(pattern.get("bridges", not gridded))
		plan.rejoin = bool(pattern.get("rejoin", keep_pieces))
		plan.colour_shown = bool(pattern.get("colour_shown", false))
		plan.bond = bool(pattern.get("bond", false))
		plan.core_colour = colour
		plan.sold_in = PackedInt32Array(pattern.get("sold_in", []))
		plan.sold_only = bool(pattern.get("sold_only", false))
		plan.faces = faces
		if pattern.get("cubes") is Dictionary:
			plan.cubes = pattern["cubes"]
		if pattern.get("cube_phases") is Array:
			plan.cube_phases = pattern["cube_phases"]
		if pattern.get("cube_bins") is Dictionary:
			plan.cube_bins = pattern["cube_bins"]
		if pattern.get("side_fine") is Callable:
			plan.side_fine = pattern["side_fine"]
		plan.mirror_of()
		last = {"mirror": plan.axis, "sum": plan.sum, "columns": columns.size(), "plates": tall,
			"ms": {}}
		var clock: int = Time.get_ticks_msec()
		if _halted(stop):
			return []
		plan.round_runs()
		last["ms"]["rounds"] = Time.get_ticks_msec() - clock
		if _halted(stop):
			return []
		last["rounds"] = plan.round_made.size()
		last["round_runs"] = plan.round_said
		# Before the sides are turned out and the surface is sloped: the plates
		# a windscreen stands in are taken first, and no slope is fitted there.
		for one: Dictionary in screens:
			var asked: Dictionary = one.duplicate()
			asked["origin"] = origin
			asked["y0"] = y0
			# A cabin on wheels is glazed behind its screen (Plan._glaze): a car's,
			# a truck's, a bus's. A fuselage's cockpit or a fighter's canopy is not:
			# its roof runs on to the tail, and the glass would run with it.
			asked["glaze"] = not wheels.is_empty()
			# The cabin is where its solid is and no other is: its glass stops at
			# the body it stands on.
			var own_solid: Dictionary = one["solid"]
			# Its top at a stud, as said and before any cut: where its roof is.
			var roofs: Dictionary = {}
			asked["roof_of"] = func(cell: Vector2i) -> int:
				if not roofs.has(cell):
					roofs[cell] = -1
					for j: int in range(tall - 1, -1, -1):
						var p := Vector3(cell.x + 0.5, y0 + j + 0.5, cell.y + 0.5)
						if (own_solid["box"] as AABB).grow(0.001).has_point(p) and _inside(own_solid, p):
							roofs[cell] = j + 1
							break
				return int(roofs[cell])
			asked["own"] = func(x: float, j: float, z: float) -> bool:
				var p := Vector3(x, y0 + j, z)
				if not (own_solid["box"] as AABB).grow(0.001).has_point(p) or not _inside(own_solid, p):
					return false
				for other: Dictionary in solids:
					if not is_same(other, own_solid) and other["kind"] != GRID \
							and (other["box"] as AABB).grow(0.001).has_point(p) and _inside(other, p):
						return false
				return true
			plan.screen(asked)
		var shells: Array = []
		if sideways:
			clock = Time.get_ticks_msec()
			shells = plan.shells("straight" if surface == "none" else surface)
			# A shell whose side studs hold less than most of what it took out
			# of the core is laid upright instead: on a body three and a half
			# plates tall (a minifigure-scale car) the rows and the side studs
			# found little to hold, and the shells kept 5 of their 74 parts, the
			# body "eroded into a narrow strip".
			# A side and its mirror are kept or given back together, on what
			# the two cover between them: a hull kept one flank at 65% and gave
			# the other back at 59%, and came out lopsided.
			var covered: Dictionary = {}    ## facing -> share
			for shell: Dictionary in shells:
				# A cube's shell was tried as it was cut (_cube_shells).
				if not bool(shell.get("tried", false)):
					plan.lay_shell(shell, "straight" if surface == "none" else surface, true)
				covered[shell["facing"]] = float(shell.get("covered", 0.0))
			var held: Array = []
			for shell: Dictionary in shells:
				# A cube's shell keeps only the cubes it covers already.
				if bool(shell.get("tried", false)):
					held.append(shell)
					continue
				var facing: Vector2i = shell["facing"]
				var share: float = covered[facing]
				var twin := Vector2i(facing.x, -facing.y) if plan.axis == "z" \
					else Vector2i(-facing.x, facing.y)
				if not plan.axis.is_empty() and twin != facing and covered.has(twin):
					share = (share + float(covered[twin])) / 2.0
				if share >= Plan.SHELL_KEEPS:
					held.append(shell)
				else:
					plan.drop_shell(shell)
					plan.kept.append("%s given back, %d%% of its plates held" % [str(facing),
						roundi(100.0 * float(covered[facing]))])
			shells = held
			plan.under_shells(shells)
			last["ms"]["shells"] = Time.get_ticks_msec() - clock
		if _halted(stop):
			return []
		clock = Time.get_ticks_msec()
		if surface != "none":
			plan.surface(surface)
		last["ms"]["surface"] = Time.get_ticks_msec() - clock
		if _halted(stop):
			return []
		clock = Time.get_ticks_msec()
		plan.lay()
		last["ms"]["core"] = Time.get_ticks_msec() - clock
		if _halted(stop):
			return []
		clock = Time.get_ticks_msec()
		# A model standing on legs is pieces at its foot that meet the body above
		# only side by side: pruned first from the foot, a bunny on its feet kept
		# its feet and lost the rest. Joined first, then pruned.
		var stitched: bool = bool(pattern.get("stitch_first", false))
		# What a sculpt's shells cut off is taken out before the stitch spends
		# its rounds on it: a bunny at 48 studs tried 86 joins where it had 27.
		# Joined first where they meet the core, as the stitch's first way
		# joins, all at once: only what that leaves is taken out.
		if not shells.is_empty():
			last["joined_cut_off"] = plan.join_cut_off()
			last["cut_off"] = plan.cut_off(true)
		if stitched:
			plan.stitch()
		last["ms"]["stitch"] = Time.get_ticks_msec() - clock
		if _halted(stop):
			return []
		# Pruned here, a teapot's spout and handle went without a word, and
		# its coverage still read 98%.
		if not keep_pieces:
			plan.prune()
		for one: Dictionary in fixed:
			plan.made.append(one.duplicate(true))
		# Stitched again only where something changed since: with every piece
		# kept and nothing fixed added, it was the first stitch twice over.
		if _halted(stop):
			return []
		if not (stitched and keep_pieces and fixed.is_empty()):
			plan.stitch()
		if _halted(stop):
			return []
		if plan.bond:
			clock = Time.get_ticks_msec()
			last["merged"] = plan.merge()
			last["ms"]["merge"] = Time.get_ticks_msec() - clock
		if _halted(stop):
			return []
		return [plan, shells]
	var built: Array = build.call(bool(pattern.get("sideways", not gridded)))
	if built.is_empty():
		return []
	var plan: Plan = built[0]
	var shells: Array = built[1]
	# Turning a side out must not cut the core in two: a car's arches left
	# a body six studs wide over them, and it came apart in ten pieces.
	# Laid upright again where it does. Nor take away what a windscreen
	# stands on: a round fuselage turned out at its nose lost the plates
	# under its cockpit's screen, and the screen with them.
	if not shells.is_empty() and plan.cubes.is_empty() and (plan.pieces().size() > 1
			or plan.screens_kept() < plan.screens_laid):
		var upright: Array = build.call(false)
		if upright.is_empty():
			return []
		var up: Plan = upright[0]
		if up.pieces().size() < plan.pieces().size() \
				or (up.pieces().size() == plan.pieces().size()
					and up.screens_kept() > plan.screens_kept()):
			plan = up
			shells = []
	# A sculpt's cubes on their sides can leave a few parts of its core cut
	# off beside them, on nothing and under nothing: taken out here, as the
	# mend would take them out, so the check is asked once. Spot at 48
	# studs left seven such, and its mend checked it three times over; a milk
	# truck's strip a stud wide under its flank was 29 parts in three pieces.
	if not plan.cubes.is_empty() and not shells.is_empty():
		last["cut_off"] = int(last.get("cut_off", 0)) + plan.cut_off() + plan.caps_apart()
	# What a sculpt's turned sides took from the core and gave back, and what
	# was cut off beside them, for src/dev/snot_gaps.gd to say which of the
	# model no part fills, and why.
	last["shelled"] = plan.shelled
	last["given_back"] = plan.given_back
	last["cut_cells"] = plan.cut_cells
	last["shell_frames"] = shells.map(func(one: Dictionary) -> Dictionary:
		return {"facing": one["facing"], "along": one["along"], "a0": one["a0"], "a1": one["a1"],
			"face": one["face"], "top": one["top"], "rows": one["rows"],
			"depth": one.get("depth", roundi(Plan.SHELL_DEPTH * PLATES_PER_STUD))})
	# What each screen laid, or why it laid none; and a steep front of a raised
	# solid said with no screen, which is how a session says a cabin.
	said.append_array(plan.screens_said)
	var unheld: Array = plan.screens_where.duplicate()
	for one: Dictionary in plan.made:
		if bool(one.get("_screen", false)):
			said.append(one["_said"])
			unheld.erase(one["_where"])
	for where: Variant in unheld:
		said.append(("The windscreen at the screen at %s could not be held: what it stands " % where)
			+ "on was laid otherwise. Give the front a plate or two more under its foot, "
			+ "or say the shape with \"sideways\": false.")
	last["screens"] = plan.screens_kept()
	# Only where a screen can be meant: a shape on wheels, or a solid said in
	# glass. A ship's raised stern was told three times it might be a cabin.
	if screens.is_empty():
		said.append_array(_screen_hints(solids, y0, wheels.is_empty(), library, colour))
	var pieces: Array = plan.pieces()
	# A part or three at a tip that no way of joining could hold are left
	# off, and said: a fighter's nose ended in a stud-long row of plates, a
	# stud wide, held by nothing, and the whole design was refused for it.
	var left_off: Array = []
	if pieces.size() > 1 and not keep_pieces:
		var gone: Dictionary = {}
		for piece: Array in pieces.slice(1):
			if piece.size() > 3:
				continue
			var low := Vector3(INF, INF, INF)
			var high := -low
			var held_fast: bool = false
			for n: int in piece:
				var one: Dictionary = plan.made[n]
				held_fast = held_fast or bool(one.get("_fixed", false))
				# Standing on what the design built under it is holding enough.
				if int(round(float(one["y"]))) == 0 and plan.afloat:
					for cell: Vector2i in one.get("_base", []):
						held_fast = held_fast or plan.foot_held.has(cell)
				var p := Vector3(float(one["x"]), float(one["y"]), float(one["z"]))
				low = low.min(p)
				high = high.max(p)
			if held_fast:
				continue
			for n: int in piece:
				gone[n] = true
			left_off.append("x %s, y %s, z %s" % [_num(low.x + origin.x), _num(low.y + y0 + origin.y),
				_num(low.z + origin.z)])
		if not gone.is_empty():
			var kept: Array = []
			for n: int in plan.made.size():
				if not gone.has(n):
					kept.append(plan.made[n])
			plan.made = kept
			pieces = plan.pieces()
			said.append("%d part%s of the shape at %s that nothing could hold %s left off: "
				% [gone.size(), "" if gone.size() == 1 else "s", "; ".join(PackedStringArray(left_off)),
				"is" if gone.size() == 1 else "are"] + "a tip a stud or two across, a plate or "
				+ "three thick. To keep it, give it more to stand on there: wider, or a plate deeper.")
	last["pieces"] = pieces.size()
	last["left_off"] = left_off
	# Where each piece but the largest is, for a probe to say: parts, and
	# the low and high corner in studs and plates.
	var apart: Array = []
	for piece: Array in pieces.slice(1):
		var low := Vector3(INF, INF, INF)
		var high := -low
		for n: int in piece:
			var one: Dictionary = plan.made[n]
			var p := Vector3(float(one["x"]), float(one["y"]), float(one["z"]))
			low = low.min(p)
			high = high.max(p)
		apart.append([piece.size(), low + origin + Vector3(0, y0, 0), high + origin + Vector3(0, y0, 0)])
	last["apart"] = apart
	# What could not be joined is said, where and how to join it. Left to the
	# check, a car's nose came back "floating" and its session built the body
	# again by hand, square and without its curves.
	if pieces.size() > 1:
		var where: PackedStringArray = []
		for one: Array in apart.slice(0, 4):
			var low: Vector3 = one[1]
			var high: Vector3 = one[2]
			where.append("%d part%s at x %s-%s, y %s-%s, z %s-%s" % [int(one[0]),
				"" if int(one[0]) == 1 else "s", _num(low.x), _num(high.x), _num(low.y),
				_num(high.y), _num(low.z), _num(high.z)])
		if apart.size() > 4:
			where.append("%d more" % (apart.size() - 4))
		var why: Array = _apart_why(plan, pieces[1], pieces[0])
		said.append("The shape laid on its own is %d pieces: %s %s held to the rest of it by "
			% [pieces.size(), "; ".join(where), "is" if apart.size() == 1 else "are"]
			+ "nothing, because %s. Unless what stands under %s holds %s, %s." % [why[0],
			"it" if apart.size() == 1 else "them", "it" if apart.size() == 1 else "them", why[1]])
	var made: Array = plan.made.filter(func(one: Dictionary) -> bool:
		return not bool(one.get("_fixed", false)))
	var turned_out: int = 0
	for shell: Dictionary in shells:
		# A sculpt's shells are many: the run's stop asked between them.
		if _halted(stop):
			return []
		var laid: Array = plan.lay_shell(shell, "straight" if surface == "none" else surface)
		turned_out += laid.size()
		made = made + laid
	last["shells"] = shells.size()
	last["sideways"] = turned_out
	turned += turned_out
	last["shells_kept"] = plan.kept
	last["faces"] = plan.faces_laid
	# A face that found no curved side with side studs to sit on is said,
	# not dropped: a head laid without the face it was given reads as done.
	for asked: Dictionary in faces:
		if not plan.faces_laid.has(asked["said"]):
			trouble.append("the face %s has nothing to sit on: %s. A face goes on a "
				% [asked["said"], str(plan.faces_why.get(asked["said"],
					"no curved side faces that way, so no side studs are laid there"))]
				+ "side that curves out (an ellipsoid's front), its centre on that "
				+ "side's middle, at least a stud inside its edges all round")
	var top_colour: int = int(pattern.get("top_color", pattern.get("top_colour", -1)))
	var placed: Array = []
	for one: Dictionary in made:
		if top_colour >= 0 and bool(one.get("_top", false)):
			one["color"] = top_colour
		# A brick in glass as LEGO made it in glass: its glass brick, which
		# Plan._made_in chose it for.
		if is_glass(library, int(one["color"])):
			one["part"] = in_glass(library, str(one["part"]), int(one["color"]))
		var out := {"part": current(library, str(one["part"])), "color": one["color"],
			"x": float(one["x"]) + origin.x, "y": float(one["y"]) + y0 + origin.y,
			"z": float(one["z"]) + origin.z, "rot": int(one["rot"])}
		if one.has("panel"):
			out["panel"] = one["panel"]
		if one.has("face"):
			out["face"] = one["face"]
		placed.append(out)
	for one: Dictionary in wheels:
		var out: Dictionary = {"part": current(library, str(one["part"])), "color": one["color"],
			"rot": one["rot"]}
		out["x"] = float(one["x"]) + origin.x
		out["y"] = float(one["y"]) + origin.y
		out["z"] = float(one["z"]) + origin.z
		placed.append(out)
	return placed


## The axles a Speed Champions car stands on, from a shape's "wheels": the
## positions along x of each axle's middle. Each is a wheel and tyre at both
## sides (18976c01), a row of Technic bricks with axle holes between them on
## an axle through both wheels, the body over it standing on those bricks'
## studs, and the body kept clear of each wheel's whole box and of the
## bricks: the cuts are added here, marked keep.
##
## Why the shape says them. Every bench car that tried a shaped body gave it
## up: raised over nothing it floated (126 to 183 parts), with wheels added
## its slopes ran into the tyres' boxes (a round arch cut leaves the box's
## corners), and the session built the car by hand, studs up and boxy. The
## wheel unit is the one the d5b car proved holds; across, the body must be
## 6, 8, 10 or 12 studs, an axle of that width less two.
##
## Each wheel's cross hole faces in, onto the axle, and its clip, which
## takes a hubcap, out: as 75893 stands them on axle pins. The other way
## round the axle ended in the clip's ring, which is a bar's width: by the
## parts' real shapes it joined neither wheel and ran a LDU into each.
const WHEEL := "18976c01"
const AXLES: Dictionary = {6: "3705", 8: "3706", 10: "3707", 12: "3737"}


static func _wheels(pattern: Dictionary, solids: Array, cuts: Array, trouble: Array) -> Array:
	var asked: Variant = pattern.get("wheels", [])
	if not asked is Array or (asked as Array).is_empty():
		return []
	var box: AABB = solids[0]["box"]
	for solid: Dictionary in solids:
		box = box.merge(solid["box"])
	var z0: int = floori(box.position.z + 0.01)
	var wide: int = ceili(box.end.z - 0.01) - z0
	if not AXLES.has(wide):
		trouble.append("wheels go under a body laid along x that is 6, 8, 10 or 12 studs "
			+ "across (z); this one is %d. Say the body that wide, or build the wheels " % wide
			+ "as bricks")
		return []
	var rim: int = int(pattern.get("wheel_color", pattern.get("wheel_colour", 71)))
	var out: Array = []
	for raw: Variant in asked:
		# On a whole stud: the axle's bricks are two studs long about it, and at
		# x 15.5 they stood half a stud off the body's studs and were refused.
		var c: float = roundf(float(raw))
		if not is_equal_approx(c, float(raw)):
			said.append("A wheel asked at x=%s is laid at x=%s: its axle's Technic bricks "
				% [_num(float(raw)), _num(c)] + "stand on whole studs.")
		if c - 2.0 < box.position.x - 0.01 or c + 2.0 > box.end.x + 0.01:
			trouble.append("a wheel at x=%s is not under the body (x %s to %s)" % [c,
				box.position.x, box.end.x])
			return []
		out.append({"part": WHEEL, "color": rim, "x": c - 1.5, "y": 0, "z": z0, "rot": 2})
		out.append({"part": WHEEL, "color": rim, "x": c - 1.5, "y": 0,
			"z": z0 + wide - 1.5, "rot": 0})
		for k: int in range(z0 + 2, z0 + wide - 2):
			out.append({"part": "32064a", "color": 0, "x": c - 1.0, "y": 2, "z": k, "rot": 0})
		out.append({"part": AXLES[wide], "color": 0, "x": c - 0.3, "y": 3, "z": z0 + 1,
			"rot": 1})
		# Clear of each wheel's box and of the bricks, the body over them
		# from five plates up standing on the bricks' studs.
		for from: Vector3 in [Vector3(c - 2.0, -1.0, z0 - 1.0),
				Vector3(c - 2.0, -1.0, z0 + wide - 2.0)]:
			cuts.append(_solid("box", {"from": [from.x, from.y, from.z], "size": [4.0, 9.5, 3.0],
				"keep": true}, trouble))
		cuts.append(_solid("box", {"from": [c - 1.0, -1.0, z0 + 1.5], "size": [2.0, 6.0,
			wide - 3.0], "keep": true}, trouble))
		# The body has to come down to the bricks to stand on them.
		if _colour_at(solids, [], Vector3(c, 5.5, z0 + wide / 2.0), 0, []) < 0:
			trouble.append(("the body does not come down to the wheels' Technic bricks at "
				+ "x=%s: its underside there must be 5 plates up or lower (under), so it " % c)
				+ "stands on them")
			return []
	out.append_array(_chassis(solids, box, z0, wide))
	return out


## A chassis: plates the width of the axles' Technic bricks, a plate under
## them, from the body's front to its back, as a set's car stands on its
## chassis plates. The body's foot between the wheels stands on it, so the
## nose ahead of the front axle and the tail behind the back one are held
## by it, and not only by what the body's fill happens to tie over the
## axles: without it, the nose and tail corners of four of the bench's car
## bodies were held by nothing, and their sessions built the body by hand.
## Laid only where the body's underside is two plates up; lower, the body
## is its own floor.
static func _chassis(solids: Array, box: AABB, z0: int, wide: int) -> Array:
	var middle: float = z0 + wide / 2.0
	var xs: Array[int] = []
	for x: int in range(floori(box.position.x), ceili(box.end.x)):
		if _colour_at(solids, [], Vector3(x + 0.5, 1.5, middle), 0, []) >= 0:
			return []
		if _colour_at(solids, [], Vector3(x + 0.5, 2.5, middle), 0, []) >= 0:
			xs.append(x)
	if xs.is_empty():
		return []
	var deep: int = wide - 4
	var lengths: Array = []
	for entry: Array in CORE_PLATES:
		if int(entry[1]) == deep:
			lengths.append(entry)
	lengths.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var out: Array = []
	var x: int = xs[0]
	var placed: bool = true
	while x <= xs[-1] and placed:
		placed = false
		for entry: Array in lengths:
			if int(entry[0]) <= xs[-1] + 1 - x:
				out.append({"part": entry[2], "color": 0, "x": x, "y": 1, "z": z0 + 2,
					"rot": entry[3], "_size": Vector2i(int(entry[0]), deep)})
				x += int(entry[0])
				placed = true
				break
	return out


## The screens the solids say, each {"along", "from", "to", "centre",
## "colour", "parts"} in the shape's own studs: "screen": true on a loft, an
## extrude or a revolve finds its steepest rise or fall; {"from", "to"} names
## the stretch along it; either may say "color" and "part".
##
## Why a shape says it. The judge's fault on the shapes round's car was the
## session's own cabin, "a boxy cabin with a flat roof and an upright
## windscreen": every car session said a cabin as a loft with a flat top,
## laid in body-coloured slopes, and fitted a windscreen afterwards by hand,
## if at all. A set's cabin is a windscreen element at its rake, the roof on
## its studs, curved slopes falling away behind.
static func _screens_asked(solids: Array, trouble: Array) -> Array:
	var out: Array = []
	for solid: Dictionary in solids:
		var spec: Dictionary = solid["spec"]
		var asked: Variant = spec.get("screen", null)
		if asked == null or (asked is bool and not bool(asked)):
			continue
		if not str(solid["kind"]) in ["loft", "extrude", "revolve"]:
			trouble.append("a screen goes on a loft, an extrude or a revolve laid along x or "
				+ "z: the solid whose front is the glass")
			continue
		var along: String = str(spec.get("along", spec.get("axis", "x"))).to_lower()
		if not along in ["x", "z"]:
			trouble.append("a screen goes on a solid laid along x or z, not %s" % along)
			continue
		var given: Dictionary = asked if asked is Dictionary else {}
		var stretch := Vector2.ZERO
		if given.has("from") and given.has("to"):
			stretch = Vector2(float(given["from"]), float(given["to"]))
			if stretch.y < stretch.x:
				stretch = Vector2(stretch.y, stretch.x)
		else:
			var line: Array = _top_line(solid, along)
			stretch = _climb(line, _steepest(line, 3))
			if stretch == Vector2.ZERO:
				trouble.append("a screen on a solid whose top rises nowhere by three plates "
					+ "or more: say where its glass is, \"screen\": {\"from\": .., \"to\": ..} "
					+ "along %s, or let its front rise to the roof" % along)
				continue
		var parts: Array = SCREENS
		if given.has("part"):
			parts = [str(given["part"])]
		# Its studs across, for the roof to be read over all of them: read off
		# the middle two, a seat cut there lowered the roof to the cut's floor.
		var box: AABB = solid["box"]
		var span := Vector2(box.position.z, box.end.z) if along == "x" \
			else Vector2(box.position.x, box.end.x)
		out.append({"along": along, "from": stretch.x, "to": stretch.y,
			"centre": _middle_across(solid, along), "span": span, "solid": solid,
			"colour": int(given.get("color", given.get("colour", -1))), "parts": parts})
	return out


## The middle of a solid across the axis it is laid along, in studs.
static func _middle_across(solid: Dictionary, along: String) -> float:
	var spec: Dictionary = solid["spec"]
	match str(solid["kind"]):
		"loft":
			return float(spec["_middle"])
		"extrude":
			return float(spec.get("from", 0.0)) + float(spec.get("width", 0.0)) / 2.0
		"revolve":
			var centre: Vector3 = _vec(spec.get("centre", spec.get("center", [0, 0, 0])))
			return centre.z if along == "x" else centre.x
	var box: AABB = solid["box"]
	return (box.get_center().z if along == "x" else box.get_center().x)


## A solid's top along its middle, a stud at a time: [Vector2(stud along,
## plates up to its top)], each where the solid is at that stud.
static func _top_line(solid: Dictionary, along: String) -> Array:
	var box: AABB = solid["box"]
	var middle: float = _middle_across(solid, along)
	var from: int = floori((box.position.x if along == "x" else box.position.z) + 0.01)
	var to: int = ceili((box.end.x if along == "x" else box.end.z) - 0.01)
	var low: int = floori(box.position.y)
	var high: int = ceili(box.end.y)
	var out: Array = []
	for a: int in range(from, to):
		for j: int in range(high - 1, low - 1, -1):
			var p := Vector3(a + 0.5, j + 0.5, middle) if along == "x" \
				else Vector3(middle, j + 0.5, a + 0.5)
			if _inside(solid, p):
				out.append(Vector2(a, j + 1))
				break
	return out


## The stretch of [param line] where its top changes most within three
## studs, by [param least] plates or more: Vector2(first stud, past the
## last), or ZERO.
static func _steepest(line: Array, least: int) -> Vector2:
	var best := Vector2.ZERO
	var most: float = 0.0
	for n: int in line.size():
		var one: Vector2 = line[n]
		for k: int in range(1, 4):
			if n + k >= line.size():
				break
			var two: Vector2 = line[n + k]
			if not is_equal_approx(two.x - one.x, float(k)):
				break
			var change: float = absf(two.y - one.y)
			if change >= least and change / k > most + 0.01:
				most = change / k
				best = Vector2(one.x, two.x + 1.0)
	return best


## [param stretch] of [param line] carried on along the whole climb it is
## in, each way while the top keeps rising (or falling) a stud at a time:
## from the bonnet to the roof, not only its steepest studs.
static func _climb(line: Array, stretch: Vector2) -> Vector2:
	if stretch == Vector2.ZERO:
		return stretch
	var top: Dictionary = {}
	for one: Vector2 in line:
		top[roundi(one.x)] = one.y
	var a: int = roundi(stretch.x)
	var b: int = roundi(stretch.y) - 1
	var way: float = signf(float(top[b]) - float(top[a]))
	while top.has(a - 1) and signf(float(top[a]) - float(top[a - 1])) == way:
		a -= 1
	while top.has(b + 1) and signf(float(top[b + 1]) - float(top[b])) == way:
		b += 1
	return Vector2(a, b + 1)


## What a shape that says no screen is told, once: a solid raised off the
## ground whose top rises steeply to a roof, laid in slopes of its own
## colour, is how every session said a cabin. Said with the fix. Off wheels
## ([param glass_only]) only of a solid said in glass, a canopy: both ships of
## the cabins round were told it of a raised stern, three times each.
static func _screen_hints(solids: Array, y0: int, glass_only: bool = false,
		library: PartLibrary = null, colour: int = -1) -> Array:
	for solid: Dictionary in solids:
		if not str(solid["kind"]) in ["loft", "extrude"]:
			continue
		var glass: bool = is_glass(library, int(solid["color"]) if int(solid.get("color", -1)) >= 0
			else colour)
		if glass_only and not glass:
			continue
		var spec: Dictionary = solid["spec"]
		var along: String = str(spec.get("along", "x")).to_lower()
		if not along in ["x", "z"]:
			continue
		var line: Array = _top_line(solid, along)
		var stretch: Vector2 = _steepest(line, 3)
		if stretch == Vector2.ZERO:
			continue
		var low: float = INF
		var high: float = -INF
		for one: Vector2 in line:
			if one.x >= stretch.x and one.x < stretch.y:
				low = minf(low, one.y)
				high = maxf(high, one.y)
		# A cabin stands on a body: its foot well off the ground. A body's own
		# nose rising from its bumper is not one. A solid said in glass is.
		if low < y0 + 6 and not glass:
			continue
		return [("A solid's top rises %d plates over %d studs at %s %s-%s, to %s, and is laid "
			% [roundi(high - low), roundi(stretch.y - stretch.x) - 1, along, _num(stretch.x),
				_num(stretch.y), _num(high)])
			+ "there in slopes of its own colour. If that is a cabin's or a canopy's front, it "
			+ "is glass at that rake: say \"screen\": true on that solid and a windscreen is "
			+ "laid there, on the plates at its foot, the roof on its top studs, as a set "
			+ "builds one; let the roof fall behind it to the tail, a fastback, in curved "
			+ "slopes rather than standing flat."]
	return []


## What a windscreen is, read off its own mesh: "w" studs across, "d" along
## its rake, "h" plates tall without its studs, "turn" as part() has it (the
## quarter turns that point its rake from its top towards its foot along
## +z), and [across, row from its top end] of the studs on its top ("tops")
## and of the studs under it that its tubes grip ("grips"). {} for a part
## that is not laid on studs and leant back along its depth, with every top
## stud in its top row, so the roof over that row holds by them.
static func screen_part(library: PartLibrary, id: String) -> Dictionary:
	if _screens.has(id):
		return _screens[id]
	_screens[id] = {}
	if library == null:
		return {}
	var info: PartLibrary.PartInfo = library.parts.get(id)
	var mesh: Lbm.PartMesh = library.mesh_for(id)
	if info == null or mesh == null:
		return {}
	var b: AABB = mesh.bounds
	var foot: Vector2i = info.footprint_studs()
	var tops: Array = []
	var tubes: Array = []
	for connector: Lbm.Connector in mesh.connectors:
		var up: float = connector.axis.normalized().dot(Vector3.UP)
		if connector.kind == "stud" and connector.gender == "male" and up > 0.9 \
				and connector.position.y > b.end.y - 4.6:
			tops.append(Vector2(connector.position.x, connector.position.z))
		elif connector.gender == "female" and up < -0.9 and connector.position.y < b.position.y + 6.0:
			tubes.append(Vector2(connector.position.x, connector.position.z))
	if tops.is_empty() or tubes.is_empty():
		return {}
	var top_z: float = 0.0
	for one: Vector2 in tops:
		top_z += one.y / tops.size()
	var foot_z: float = 0.0
	for one: Vector2 in tubes:
		foot_z += one.y / tubes.size()
	if absf(foot_z - top_z) < 10.0:
		return {}
	var native: int = 0 if top_z < foot_z else 2
	var cell := func(x: float, z: float) -> Vector2i:
		var i: int = clampi(floori((x - b.position.x) / 20.0), 0, foot.x - 1)
		var k: int = clampi(floori((z - b.position.z) / 20.0), 0, foot.y - 1)
		return Vector2i(i, k) if native == 0 else Vector2i(foot.x - 1 - i, foot.y - 1 - k)
	var top_cells: Array[Vector2i] = []
	for one: Vector2 in tops:
		var c: Vector2i = cell.call(one.x, one.y)
		if c.y != 0:
			return {}
		if not top_cells.has(c):
			top_cells.append(c)
	# A tube grips the studs round it: those whose middles are within half a
	# stud of it either way.
	var grips: Array[Vector2i] = []
	for one: Vector2 in tubes:
		for i: int in foot.x:
			for k: int in foot.y:
				var middle := Vector2(b.position.x + 10.0 + 20.0 * i, b.position.z + 10.0 + 20.0 * k)
				if absf(middle.x - one.x) <= 10.5 and absf(middle.y - one.y) <= 10.5:
					var c: Vector2i = cell.call(middle.x, middle.y)
					if not grips.has(c):
						grips.append(c)
	var found := {"id": id, "w": foot.x, "d": foot.y,
		"h": int(round((b.size.y - 4.0) / 8.0)), "turn": posmod(-native, 4),
		"tops": top_cells, "grips": grips}
	_screens[id] = found
	return found


## Where a shape's foot is, stud by stud: world (x, z) -> the plate its
## lowest plate there stands on, for the shape under it to keep studs
## there. {} for a shape that cannot be read.
static func feet(pattern: Dictionary) -> Dictionary:
	var trouble: Array = []
	var solids: Array = _read(pattern, "solids", trouble, true)
	var cuts: Array = _read(pattern, "cuts", trouble, false)
	if not trouble.is_empty() or solids.is_empty():
		return {}
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var origin := Vector3(float(at.get("x", 0.0)), float(at.get("y", 0.0)), float(at.get("z", 0.0)))
	var box: AABB = solids[0]["box"]
	for solid: Dictionary in solids:
		box = box.merge(solid["box"])
	var size: Vector3 = box.size
	if size.x * size.y * size.z > MOST_CELLS:
		return {}
	var out: Dictionary = {}
	for x: int in range(floori(box.position.x), ceili(box.end.x)):
		for z: int in range(floori(box.position.z), ceili(box.end.z)):
			for y: int in range(floori(box.position.y), ceili(box.end.y)):
				if _colour_at(solids, cuts, Vector3(x + 0.5, y + 0.5, z + 0.5), 0, []) >= 0:
					out[Vector2i(x + roundi(origin.x), z + roundi(origin.z))] = y + roundi(origin.y)
					break
	return out


## Why [param piece] of [param plan] is held by nothing of [param main], and
## what in the shape's numbers would hold it: [why, fix].
static func _apart_why(plan: Plan, piece: Array, main: Array) -> Array:
	var rest: Dictionary = {}    ## Vector3i(x, plate, z) -> true
	for n: int in main:
		var one: Dictionary = plan.made[n]
		var y: int = int(round(float(one["y"])))
		for cell: Vector2i in one.get("_covers", one.get("_cells", [])):
			for h: int in int(one.get("_h", 1)):
				rest[Vector3i(cell.x, y + h, cell.y)] = true
	var stacked: bool = false
	var beside: bool = false
	var edge: bool = false
	for n: int in piece:
		var one: Dictionary = plan.made[n]
		var y: int = int(round(float(one["y"])))
		for cell: Vector2i in one.get("_covers", one.get("_cells", [])):
			for h: int in int(one.get("_h", 1)):
				var here := Vector3i(cell.x, y + h, cell.y)
				stacked = stacked or rest.has(here + Vector3i.UP) or rest.has(here + Vector3i.DOWN)
				for step: Vector2i in OUT:
					beside = beside or rest.has(here + Vector3i(step.x, 0, step.y))
				for dx: int in [-1, 1]:
					for dz: int in [-1, 1]:
						edge = edge or rest.has(here + Vector3i(dx, 0, dz))
					edge = edge or rest.has(here + Vector3i(dx, 1, 0)) or rest.has(here + Vector3i(dx, -1, 0)) \
						or rest.has(here + Vector3i(0, 1, dx)) or rest.has(here + Vector3i(0, -1, dx))
	if stacked:
		return ["it stands on a slope or a tile of the body, or under one, and neither "
			+ "holds a stud", "give it a flat top to stand on there: lower it a plate into the "
			+ "body, or the body's top under it a plate, so a plate meets a plate"]
	if beside:
		return ["it meets the body only side by side, where nothing over or under both "
			+ "reaches across", "let it reach a plate or more over or under the body where "
			+ "they meet, and two studs wide or more, so a plate can cross the joint"]
	if edge:
		return ["it meets the body only at an edge", "let the two solids overlap by a "
			+ "stud where they meet"]
	return ["it does not touch the body", "move it to overlap the body by a stud, or say it "
		+ "as a shape of its own on what holds it"]


static func _empty(column: PackedInt32Array) -> bool:
	for value: int in column:
		if value >= 0:
			return false
	return true


## The ways a face can look out of a shape, by name.
const FACINGS: Dictionary = {"+x": Vector2i(1, 0), "-x": Vector2i(-1, 0),
	"+z": Vector2i(0, 1), "-z": Vector2i(0, -1)}
## A face's disc by how many studs across: a round plate, and the square
## plate that brings it out to the curve behind it.
const FACE_DISCS: Dictionary = {4: ["60474", "3031"], 6: ["11213", "3958"],
	8: ["74611", "41539"]}


## The faces a shape is given: {"facing": "+z", "x", "y", "z": its middle in
## the shape's studs and plates, "across": 4, 6 or 8, "color": the disc's,
## "rim": the plate behind it, "eyes": the iris, "beak": its colour or -1}.
## The plate of its middle is counted from the plan's foot ([param y0]).
static func _read_faces(pattern: Dictionary, y0: int, trouble: Array) -> Array:
	var asked: Variant = pattern.get("face", pattern.get("faces", []))
	if asked is Dictionary:
		asked = [asked]
	var out: Array = []
	if not asked is Array:
		return out
	for raw: Variant in asked:
		if not raw is Dictionary:
			trouble.append("a shape's face is an object: {\"facing\": \"+z\", \"x\", \"y\", "
				+ "\"z\", \"across\": 6}")
			continue
		var one: Dictionary = raw
		var facing: String = str(one.get("facing", "+z")).strip_edges().to_lower()
		var across: int = int(one.get("across", 4))
		if not FACINGS.has(facing):
			trouble.append("a face looks out +x, -x, +z or -z, not \"%s\"" % facing)
			continue
		if not FACE_DISCS.has(across):
			trouble.append("a face is 4, 6 or 8 studs across, the round plate that is its "
				+ "disc, not %d" % across)
			continue
		var centre: Vector3 = _vec(one.get("centre", [one.get("x", 0.0), one.get("y", 0.0),
			one.get("z", 0.0)]))
		out.append({"facing": FACINGS[facing], "x": centre.x, "j": centre.y - y0,
			"z": centre.z, "across": across, "color": int(one.get("color", -1)),
			"rim": int(one.get("rim", -1)), "eyes": int(one.get("eyes", 0)),
			"beak": int(one.get("beak", 19)),
			"said": "facing %s at %s, %s" % [facing, _num(centre.x), _num(centre.y)]
				if facing.ends_with("z") else "facing %s at %s, %s" % [facing,
					_num(centre.z), _num(centre.y)]})
	return out


static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.1))


## The solids or cuts a shape names: in a list under [param key], and for
## solids also the one kind given at the top level.
static func _read(pattern: Dictionary, key: String, trouble: Array,
		top_level: bool) -> Array:
	var raw: Array = []
	if pattern.get(key) is Array:
		raw = (pattern[key] as Array).duplicate()
	if top_level:
		for kind: String in KINDS:
			if pattern.get(kind) is Dictionary:
				raw.append({kind: pattern[kind]})
	var out: Array = []
	var named: Array = KINDS + [GRID]
	for entry: Variant in raw:
		if not entry is Dictionary:
			trouble.append("each of a shape's %s is an object naming one kind: " % key
				+ ", ".join(PackedStringArray(KINDS)))
			continue
		var given: Dictionary = entry
		var kind: String = str(given.get("kind", ""))
		var spec: Dictionary = given
		for one: String in named:
			if given.get(one) is Dictionary:
				kind = one
				spec = (given[one] as Dictionary).duplicate()
				if given.has("color") and not spec.has("color"):
					spec["color"] = given["color"]
				break
		if not kind in named:
			trouble.append("a shape's %s are %s" % [key, ", ".join(PackedStringArray(KINDS))])
			continue
		var solid: Dictionary = _solid(kind, spec, trouble)
		if not solid.is_empty():
			out.append(solid)
	return out


## One solid, checked and with what it needs worked out: its box (studs
## across and along, plates up), whether it is round, and its colour.
static func _solid(kind: String, spec: Dictionary, trouble: Array) -> Dictionary:
	var solid := {"kind": kind, "spec": spec, "round": false,
		"color": int(spec.get("color", spec.get("colour", -1)))}
	match kind:
		GRID:
			var from: Vector3 = _vec(spec.get("from", [0, 0, 0]))
			var size: Vector3 = _vec(spec.get("size", [0, 0, 0]))
			if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0 \
					or not spec.get("colour_at") is Callable:
				trouble.append("a grid wants a size and a colour_at function")
				return {}
			solid["box"] = AABB(from, size)
			solid["round"] = bool(spec.get("round", true))
		"box":
			var from: Vector3 = _vec(spec.get("from", [0, 0, 0]))
			var size: Vector3 = _vec(spec.get("size", [0, 0, 0]))
			if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
				trouble.append("a box wants size [across, plates up, deep], each above nought")
				return {}
			solid["box"] = AABB(from, size)
			solid["round"] = float(spec.get("round", 0.0)) > 0.0 \
				or float(spec.get("edge", 0.0)) > 0.0
		"ellipsoid", "dome":
			var centre: Vector3 = _vec(spec.get("centre", spec.get("center", [0, 0, 0])))
			var radii: Vector3 = _vec(spec.get("radii", [0, 0, 0]))
			if radii.x <= 0.0 or radii.y <= 0.0 or radii.z <= 0.0:
				trouble.append("an %s wants radii [studs across, plates up, studs deep]" % kind)
				return {}
			var low: Vector3 = centre - radii
			if kind == "dome":
				low.y = centre.y
			solid["box"] = AABB(low, centre + radii - low)
			solid["round"] = true
		"loft":
			var along: String = str(spec.get("along", "x")).to_lower()
			var sections: Array = []
			for raw: Variant in spec.get("sections", []):
				if raw is Dictionary:
					sections.append(raw)
			if sections.size() < 2 or not along in ["x", "z"]:
				trouble.append("a loft wants \"along\": \"x\" or \"z\" and two or more "
					+ "sections, each {\"at\", \"width\", \"height\", \"bottom\"}")
				return {}
			sections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a.get("at", 0.0)) < float(b.get("at", 0.0)))
			var widest: float = 0.0
			for section: Dictionary in sections:
				widest = maxf(widest, float(section.get("width", 0.0)))
			var middle: float = float(spec.get("centre", spec.get("center", widest / 2.0)))
			var low := Vector3(INF, INF, INF)
			var high := Vector3(-INF, -INF, -INF)
			for section: Dictionary in sections:
				var a: float = float(section.get("at", 0.0))
				var w: float = float(section.get("width", 0.0))
				var c: float = middle + float(section.get("offset", 0.0))
				var b: float = float(section.get("bottom", 0.0))
				var h: float = float(section.get("height", 0.0))
				solid["round"] = solid["round"] or float(section.get("round", 0.5)) > 0.0
				var lat := Vector2(c - w / 2.0, c + w / 2.0)
				if along == "x":
					low = Vector3(minf(low.x, a), minf(low.y, b), minf(low.z, lat.x))
					high = Vector3(maxf(high.x, a), maxf(high.y, b + h), maxf(high.z, lat.y))
				else:
					low = Vector3(minf(low.x, lat.x), minf(low.y, b), minf(low.z, a))
					high = Vector3(maxf(high.x, lat.y), maxf(high.y, b + h), maxf(high.z, a))
			spec["_sections"] = sections
			spec["_middle"] = middle
			solid["box"] = AABB(low, high - low)
		"extrude":
			var along: String = str(spec.get("along", "x")).to_lower()
			var profile: Array = _points(spec.get("profile", []))
			var under: Array = _points(spec.get("under", []))
			var width: float = float(spec.get("width", 0.0))
			if profile.size() < 2 or width <= 0.0 or not along in ["x", "z"]:
				trouble.append("an extrude wants \"along\", a \"width\" and a \"profile\" "
					+ "of two or more [along, plates up] points along its top")
				return {}
			var from: float = float(spec.get("from", 0.0))
			var lo: float = INF
			var hi: float = -INF
			var top: float = -INF
			var bottom: float = INF
			for point: Vector2 in profile:
				lo = minf(lo, point.x)
				hi = maxf(hi, point.x)
				top = maxf(top, point.y)
			for point: Vector2 in under:
				bottom = minf(bottom, point.y)
			if under.is_empty():
				bottom = 0.0
			spec["_profile"] = profile
			spec["_under"] = under
			solid["round"] = float(spec.get("round", 0.0)) > 0.0
			if along == "x":
				solid["box"] = AABB(Vector3(lo, bottom, from), Vector3(hi - lo, top - bottom, width))
			else:
				solid["box"] = AABB(Vector3(from, bottom, lo), Vector3(width, top - bottom, hi - lo))
		"revolve":
			var axis: String = str(spec.get("axis", "y")).to_lower()
			var centre: Vector3 = _vec(spec.get("centre", spec.get("center", [0, 0, 0])))
			var profile: Array = _points(spec.get("profile", []))
			if profile.size() < 2 or not axis in ["x", "y", "z"]:
				trouble.append("a revolve wants \"axis\" and a \"profile\" of two or more "
					+ "[along, radius in studs] points")
				return {}
			var lo: float = INF
			var hi: float = -INF
			var reach: float = 0.0
			for point: Vector2 in profile:
				lo = minf(lo, point.x)
				hi = maxf(hi, point.x)
				reach = maxf(reach, point.y)
			spec["_profile"] = profile
			solid["round"] = true
			match axis:
				"y":
					solid["box"] = AABB(Vector3(centre.x - reach, centre.y + lo, centre.z - reach),
						Vector3(2.0 * reach, hi - lo, 2.0 * reach))
				"x":
					solid["box"] = AABB(Vector3(centre.x + lo, centre.y - reach * PLATES_PER_STUD,
						centre.z - reach), Vector3(hi - lo, 2.0 * reach * PLATES_PER_STUD, 2.0 * reach))
				"z":
					solid["box"] = AABB(Vector3(centre.x - reach, centre.y - reach * PLATES_PER_STUD,
						centre.z + lo), Vector3(2.0 * reach, 2.0 * reach * PLATES_PER_STUD, hi - lo))
	return solid


static func _vec(raw: Variant) -> Vector3:
	if raw is Array and (raw as Array).size() >= 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	if raw is Dictionary:
		return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))
	return Vector3.ZERO


## [[a, b], ...] as Vector2s, sorted by a.
static func _points(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for one: Variant in raw:
			if one is Array and (one as Array).size() >= 2:
				out.append(Vector2(float(one[0]), float(one[1])))
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out


## Linear between the points, nothing (NAN) outside them.
static func _along(points: Array, a: float) -> float:
	if points.is_empty() or a < (points[0] as Vector2).x or a > (points[-1] as Vector2).x:
		return NAN
	for n: int in range(1, points.size()):
		var one: Vector2 = points[n - 1]
		var two: Vector2 = points[n]
		if a <= two.x:
			if two.x - one.x < 0.0001:
				return maxf(one.y, two.y)
			return lerpf(one.y, two.y, (a - one.x) / (two.x - one.x))
	return (points[-1] as Vector2).y


## The colour of the shape at [param p] (studs, plates, studs), or -1 where
## it is not: the last solid that holds it, a band by height, and nothing
## where a cut takes it.
static func _colour_at(solids: Array, cuts: Array, p: Vector3, colour: int,
		bands: Array) -> int:
	var found: int = -2
	for solid: Dictionary in solids:
		if solid["kind"] == GRID:
			# Its own colour at every point, asked once.
			if (solid["box"] as AABB).grow(0.001).has_point(p):
				var here: int = int(((solid["spec"] as Dictionary)["colour_at"] as Callable).call(p))
				if here >= 0:
					found = here
			continue
		if (solid["box"] as AABB).grow(0.001).has_point(p) and _inside(solid, p):
			found = int(solid["color"]) if int(solid["color"]) >= 0 else colour
	if found == -2:
		return -1
	for cut: Dictionary in cuts:
		if (cut["box"] as AABB).grow(0.001).has_point(p) and _inside(cut, p):
			return -1
	for band: Dictionary in bands:
		if p.y >= float(band.get("from", -INF)) and p.y < float(band.get("to", INF)):
			found = int(band.get("color", band.get("colour", found)))
	return found


## Is [param p] inside [param solid]?
static func _inside(solid: Dictionary, p: Vector3) -> bool:
	var spec: Dictionary = solid["spec"]
	match str(solid["kind"]):
		GRID:
			return int((spec["colour_at"] as Callable).call(p)) >= 0
		"box":
			var from: Vector3 = _vec(spec.get("from", [0, 0, 0]))
			var size: Vector3 = _vec(spec.get("size", [0, 0, 0]))
			var r: float = minf(float(spec.get("round", 0.0)), minf(size.x, size.z) / 2.0)
			var c: float = float(spec.get("chamfer", 0.0))
			var dx: float = maxf(maxf(from.x + r - p.x, 0.0), p.x - (from.x + size.x - r))
			var dz: float = maxf(maxf(from.z + r - p.z, 0.0), p.z - (from.z + size.z - r))
			if r > 0.0 and dx * dx + dz * dz > r * r:
				return false
			if c > 0.0:
				var ex: float = minf(p.x - from.x, from.x + size.x - p.x)
				var ez: float = minf(p.z - from.z, from.z + size.z - p.z)
				if ex + ez < c:
					return false
			var top: float = from.y + size.y
			var edge: float = float(spec.get("edge", 0.0))
			if edge > 0.0:
				var e: float = minf(minf(p.x - from.x, from.x + size.x - p.x),
					minf(p.z - from.z, from.z + size.z - p.z))
				top -= _round_off(e, edge)
			return p.y >= from.y and p.y <= top
		"ellipsoid", "dome":
			var centre: Vector3 = _vec(spec.get("centre", spec.get("center", [0, 0, 0])))
			var radii: Vector3 = _vec(spec.get("radii", [1, 1, 1]))
			if str(solid["kind"]) == "dome" and p.y < centre.y:
				return false
			var d: Vector3 = (p - centre) / radii
			return d.length_squared() <= 1.0
		"loft":
			var along: String = str(spec.get("along", "x")).to_lower()
			var a: float = p.x if along == "x" else p.z
			var u: float = p.z if along == "x" else p.x
			return _in_loft(spec, a, u, p.y)
		"extrude":
			var along: String = str(spec.get("along", "x")).to_lower()
			var a: float = p.x if along == "x" else p.z
			var u: float = p.z if along == "x" else p.x
			var from: float = float(spec.get("from", 0.0))
			var width: float = float(spec.get("width", 0.0))
			if u < from or u > from + width:
				return false
			var top: float = _along(spec["_profile"], a)
			if is_nan(top):
				return false
			var bottom: float = 0.0
			if not (spec["_under"] as Array).is_empty():
				bottom = _along(spec["_under"], a)
				if is_nan(bottom):
					return false
			var r: float = float(spec.get("round", 0.0))
			if r > 0.0:
				top -= _round_off(minf(u - from, from + width - u), r)
			return p.y >= bottom and p.y <= top
		"revolve":
			var axis: String = str(spec.get("axis", "y")).to_lower()
			var centre: Vector3 = _vec(spec.get("centre", spec.get("center", [0, 0, 0])))
			var d: Vector3 = p - centre
			match axis:
				"y":
					var r: float = _along(spec["_profile"], d.y)
					return not is_nan(r) and Vector2(d.x, d.z).length() <= r
				"x":
					var r: float = _along(spec["_profile"], d.x)
					return not is_nan(r) and Vector2(d.y / PLATES_PER_STUD, d.z).length() <= r
				"z":
					var r: float = _along(spec["_profile"], d.z)
					return not is_nan(r) and Vector2(d.x, d.y / PLATES_PER_STUD).length() <= r
	return false


## How far a top edge rounded to [param radius] studs falls, in plates, at
## [param e] studs in from the edge.
static func _round_off(e: float, radius: float) -> float:
	if e >= radius:
		return 0.0
	var t: float = (radius - e) / radius
	return radius * PLATES_PER_STUD * (1.0 - sqrt(maxf(0.0, 1.0 - t * t)))


## Inside a loft at [param a] along it, [param u] across and [param v]
## plates up: between its sections, inside the section there — a
## superellipse from a box ("round": 0) to an ellipse (1), its lower half
## narrowing towards a keel by "keel" (0 to 1).
static func _in_loft(spec: Dictionary, a: float, u: float, v: float) -> bool:
	var sections: Array = spec["_sections"]
	var first: Dictionary = sections[0]
	var last: Dictionary = sections[-1]
	if a < float(first.get("at", 0.0)) or a > float(last.get("at", 0.0)):
		return false
	var one: Dictionary = first
	var two: Dictionary = last
	for n: int in range(1, sections.size()):
		if a <= float((sections[n] as Dictionary).get("at", 0.0)):
			one = sections[n - 1]
			two = sections[n]
			break
	var span: float = float(two.get("at", 0.0)) - float(one.get("at", 0.0))
	var t: float = 0.0 if span < 0.0001 else (a - float(one.get("at", 0.0))) / span
	var width: float = lerpf(float(one.get("width", 0.0)), float(two.get("width", 0.0)), t)
	var height: float = lerpf(float(one.get("height", 0.0)), float(two.get("height", 0.0)), t)
	var bottom: float = lerpf(float(one.get("bottom", 0.0)), float(two.get("bottom", 0.0)), t)
	var middle: float = float(spec["_middle"]) + lerpf(float(one.get("offset", 0.0)),
		float(two.get("offset", 0.0)), t)
	var rounded: float = lerpf(float(one.get("round", 0.5)), float(two.get("round", 0.5)), t)
	var keel: float = lerpf(float(one.get("keel", 0.0)), float(two.get("keel", 0.0)), t)
	if width <= 0.0 or height <= 0.0:
		return false
	var du: float = absf(u - middle) / (width / 2.0)
	var dv: float = (v - (bottom + height / 2.0)) / (height / 2.0)
	if du > 1.0 or absf(dv) > 1.0:
		return false
	if dv < 0.0 and keel > 0.0:
		du /= maxf(0.05, 1.0 - keel * -dv)
		if du > 1.0:
			return false
	var power: float = lerpf(16.0, 2.0, clampf(rounded, 0.0, 1.0))
	return pow(du, power) + pow(absf(dv), power) <= 1.0


## What a surface part is, read off its own mesh once: how wide across its
## fall, how long along it, how many plates tall, and the quarter turns that
## point its fall (from its high end, or for an inverted one from its deep
## end) along +z. {} when the part is not here.
static func part(library: PartLibrary, id: String, inverted: bool = false) -> Dictionary:
	var key: String = "%s %s" % [id, inverted]
	if _parts.has(key):
		return _parts[key]
	_parts[key] = {}
	if library == null or id.is_empty():
		return {}
	var info: PartLibrary.PartInfo = library.parts.get(id)
	var mesh: Lbm.PartMesh = library.mesh_for(id)
	if info == null or mesh == null or mesh.boxes.is_empty():
		return {}
	var b: AABB = mesh.bounds
	var studded: bool = false
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind == "stud" and connector.gender == "male" \
				and connector.axis.normalized().dot(Vector3.UP) > 0.9:
			studded = true
	var foot: Vector2i = info.footprint_studs()
	# The highest top (or for an inverted part the lowest bottom) in each half
	# of the footprint, along z and along x. The fall runs along the axis where
	# the halves differ most, from the high half.
	var halves := func(along_z: bool) -> Vector2:
		var middle: float = (b.position.z + b.size.z / 2.0) if along_z \
			else (b.position.x + b.size.x / 2.0)
		var low_half: float = -INF if not inverted else INF
		var high_half: float = -INF if not inverted else INF
		for box: AABB in mesh.boxes:
			var from: float = box.position.z if along_z else box.position.x
			var to: float = box.end.z if along_z else box.end.x
			var value: float = box.end.y if not inverted else box.position.y
			if from < middle - 0.5:
				low_half = maxf(low_half, value) if not inverted else minf(low_half, value)
			if to > middle + 0.5:
				high_half = maxf(high_half, value) if not inverted else minf(high_half, value)
		return Vector2(low_half, high_half)
	var on_z: Vector2 = halves.call(true)
	var on_x: Vector2 = halves.call(false)
	var fall_z: float = absf(on_z.x - on_z.y)
	var fall_x: float = absf(on_x.x - on_x.y)
	if maxf(fall_z, fall_x) < 1.0:
		return {}
	var native: int
	if fall_z >= fall_x:
		var high_low: bool = on_z.x > on_z.y if not inverted else on_z.x < on_z.y
		native = 0 if high_low else 2
	else:
		var high_low: bool = on_x.x > on_x.y if not inverted else on_x.x < on_x.y
		native = 1 if high_low else 3
	var along_z: bool = native % 2 == 0
	var d: int = foot.y if along_z else foot.x
	# The rows along its fall, from the high end, that a stud from below
	# reaches into, read as the check reads it: a little past the stud's tip.
	# A curved slope is hollow under its high end, so only its low rows grip;
	# upright it rests on its plates whatever they hold, but on its side it is
	# held by those rows or by nothing, and the owl's flanks were refused four
	# times for 11477s whose side stud stood under the hollow end.
	var grips: Array[int] = []
	for row: int in d:
		var n: int = row if native in [0, 1] else d - 1 - row
		var across: float = (b.position.z if along_z else b.position.x) + 10.0 + 20.0 * n
		var stud: float = (b.position.x if along_z else b.position.z) + 10.0
		var probe := Vector3(stud, b.position.y + 5.0, across) if along_z \
			else Vector3(across, b.position.y + 5.0, stud)
		# The cover is in the lattice's cells, the bounds in LDU.
		probe /= BrickLattice.CELL
		for box: AABB in mesh.boxes:
			if box.grow(0.01).has_point(probe):
				grips.append(row)
				break
	# And the rows with a stud on top, from the same end: what stands on it is
	# held there and nowhere else. An inverted curved 4 x 1 was counted
	# holding what stood on all four of its studs; it has studs over two, and
	# a ship's bow it was the only tie to came away from the hull.
	var tops: Array[int] = []
	for connector: Lbm.Connector in mesh.connectors:
		# On its top: a stud lower down, where its top steps down, is under
		# what stands over the part and reaches nothing.
		if connector.kind != "stud" or connector.gender != "male" \
				or connector.axis.normalized().dot(Vector3.UP) < 0.9 \
				or connector.position.y < b.end.y - 4.5:
			continue
		var at: float = connector.position.z if along_z else connector.position.x
		var n: int = clampi(floori((at - (b.position.z if along_z else b.position.x)) / 20.0), 0, d - 1)
		var row: int = n if native in [0, 1] else d - 1 - n
		if not tops.has(row):
			tops.append(row)
	tops.sort()
	var found := {"id": id, "w": foot.x if along_z else foot.y, "d": d,
		"h": int(round((b.size.y - (4.0 if studded else 0.0)) / 8.0)),
		"turn": posmod(-native, 4), "grips": grips, "tops": tops}
	_parts[key] = found
	return found


## What a plan's edge is laid in where it runs off the square, a plate tall
## and a brick tall. The round parts a set rounds a body with come first,
## where they fit: corner rounds 2 to 4 studs across. Then plates and bricks
## without a corner, cut at 45 degrees, and the wedges. Whole round plates
## and bricks (60474, 3941 and the rest), 30503 and the double wedges 41747
## and 43710 are not here: their collision cover is one square box, so the
## check would read each as a square, overlapping whatever follows the curve
## beside it.
const ROUND_PLATES: Array = ["30565", "30357", "79491"]
const EDGE_PLATES: Array = ["2450", "26601"]
const ROUND_BRICKS: Array = ["2577", "5152", "3063b"]
const EDGE_BRICKS: Array = ["30505", "6564", "6565", "41767", "41768"]

## How much of a stud each part and the shape cover, as 16 bits: a 4 x 4
## grid in the stud, bit v * 4 + u.
const FULL := 0xFFFF

## height -> "part rot" -> [across, deep, studs {cell: true}, covers
## {cell: bits}, the first stud it covers only in part, round].
static var _edge_parts: Dictionary = {}

## How many bits each 16-bit number has set.
static var _ones: PackedByteArray = PackedByteArray()


static func edge_parts(library: PartLibrary, height: int) -> Dictionary:
	if _edge_parts.has(height):
		return _edge_parts[height]
	var out: Dictionary = {}
	var round_ones: Array = ROUND_PLATES if height == 1 else ROUND_BRICKS
	var others: Array = (EDGE_PLATES + Patterns.WEDGES) if height == 1 else EDGE_BRICKS
	for part: Variant in round_ones + others:
		var base: Array = _covers(library, str(part))
		if base.is_empty():
			continue
		for rot: int in 4:
			var turned: Array = _cover_turned(base, rot)
			turned.append(round_ones.has(part))
			out["%s %d" % [str(part), rot]] = turned
	if library != null and not out.is_empty():
		_edge_parts[height] = out
	return out


## What a part covers in plan, read off its own mesh: [across, deep, the
## studs on its top, the bits of each stud of its box it covers, the first
## of them it covers only in part]. [] for a part that is not here, or that
## covers every stud it stands on whole, which a plate does as well.
static func _covers(library: PartLibrary, part: String) -> Array:
	var info: PartLibrary.PartInfo = library.parts.get(part) if library != null else null
	var mesh: Lbm.PartMesh = library.mesh_for(part) if info != null else null
	if mesh == null or mesh.boxes.is_empty():
		return []
	var foot: Vector2i = info.footprint_studs()
	var b: AABB = mesh.bounds
	var studs: Dictionary = {}
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "stud" or connector.gender != "male" \
				or connector.axis.normalized().dot(Vector3.UP) < 0.9:
			continue
		var at := Vector2i(int(floor((connector.position.x - b.position.x) / 20.0)),
			int(floor((connector.position.z - b.position.z) / 20.0)))
		if at.x >= 0 and at.y >= 0 and at.x < foot.x and at.y < foot.y:
			studs[at] = true
	var covers: Dictionary = {}
	for i: int in foot.x:
		for k: int in foot.y:
			var bits: int = 0
			for v: int in 4:
				for u: int in 4:
					var x: float = b.position.x + 20.0 * i + 5.0 * u + 2.5
					var z: float = b.position.z + 20.0 * k + 5.0 * v + 2.5
					for cells: AABB in mesh.boxes:
						if cells.position.x * mesh.cell_ldu <= x and cells.end.x * mesh.cell_ldu >= x \
								and cells.position.z * mesh.cell_ldu <= z \
								and cells.end.z * mesh.cell_ldu >= z:
							bits |= 1 << (v * 4 + u)
							break
			if bits != 0:
				covers[Vector2i(i, k)] = bits
	for at: Variant in studs:
		covers[at] = FULL
	var first := Vector2i(-1, -1)
	for k: int in foot.y:
		for i: int in foot.x:
			var bits: int = int(covers.get(Vector2i(i, k), 0))
			if first.x < 0 and bits != 0 and bits != FULL:
				first = Vector2i(i, k)
	if studs.is_empty() or first.x < 0:
		return []
	return [foot.x, foot.y, studs, covers, first]


## A part's cover turned [param rot] quarter turns, as Patterns._turned
## turns studs: (i, k) to (k, across - 1 - i), and inside a stud (u, v) to
## (v, 3 - u).
static func _cover_turned(base: Array, rot: int) -> Array:
	var across: int = base[0]
	var deep: int = base[1]
	var studs: Dictionary = base[2]
	var covers: Dictionary = base[3]
	for _turn: int in posmod(rot, 4):
		var next_studs: Dictionary = {}
		for key: Variant in studs:
			var at: Vector2i = key
			next_studs[Vector2i(at.y, across - 1 - at.x)] = true
		var next_covers: Dictionary = {}
		for key: Variant in covers:
			var at: Vector2i = key
			var bits: int = covers[key]
			var turned: int = 0
			for v: int in 4:
				for u: int in 4:
					if bits & (1 << (v * 4 + u)):
						turned |= 1 << ((3 - u) * 4 + v)
			next_covers[Vector2i(at.y, across - 1 - at.x)] = turned
		studs = next_studs
		covers = next_covers
		var swap: int = across
		across = deep
		deep = swap
	var first := Vector2i(-1, -1)
	for k: int in deep:
		for i: int in across:
			var bits: int = int(covers.get(Vector2i(i, k), 0))
			if first.x < 0 and bits != 0 and bits != FULL:
				first = Vector2i(i, k)
	return [across, deep, studs, covers, first]


## Whether what the shape covers of a stud is bounded square to it: the same
## in every row of the 4 x 4 grid, or in every column. A stud the edge
## crosses on a slant is neither.
static func square(bits: int) -> bool:
	var rows: bool = true
	var columns: bool = true
	var row: int = bits & 0xF
	var column: int = bits & 0x1111
	for n: int in range(1, 4):
		rows = rows and (bits >> (4 * n)) & 0xF == row
		columns = columns and (bits >> n) & 0x1111 == column
	return rows or columns


static func ones(bits: int) -> int:
	if _ones.is_empty():
		_ones.resize(65536)
		for n: int in 65536:
			_ones[n] = (_ones[n >> 1] if n > 0 else 0) + (n & 1)
	return _ones[bits & FULL]


## What a wedge plate covers in plan at half a stud, placed as "part rot"
## names it, from its own mesh, as one comparable string — reflected across
## x or z first when [param mirror] says so. "" when the part is not here.
static var _plans: Dictionary = {}


static func wedge_plan(library: PartLibrary, named: String, mirror: String) -> String:
	var key: String = "%s %s" % [named, mirror]
	if _plans.has(key):
		return _plans[key]
	_plans[key] = ""
	var said: PackedStringArray = named.split(" ")
	var mesh: Lbm.PartMesh = library.mesh_for(said[0]) if library != null else null
	var info: PartLibrary.PartInfo = library.parts.get(said[0]) if library != null else null
	if mesh == null or info == null:
		return ""
	var foot: Vector2i = info.footprint_studs()
	var b: AABB = mesh.bounds
	var cells: Dictionary = {}
	for u: int in 2 * foot.x:
		for v: int in 2 * foot.y:
			var x: float = b.position.x + 10.0 * u + 5.0
			var z: float = b.position.z + 10.0 * v + 5.0
			# The boxes are in lattice cells, not LDU: read as LDU, every plan
			# was the middle half of the part, and a twin was found by chance.
			for box: AABB in mesh.boxes:
				if box.position.x * mesh.cell_ldu <= x and box.end.x * mesh.cell_ldu >= x \
						and box.position.z * mesh.cell_ldu <= z and box.end.z * mesh.cell_ldu >= z:
					cells[Vector2i(u, v)] = true
					break
	# Turned as Patterns._turned turns studs, at twice the resolution.
	var across_: int = 2 * foot.x
	var deep: int = 2 * foot.y
	for _turn: int in posmod(said[1].to_int(), 4):
		var next: Dictionary = {}
		for cell: Variant in cells:
			var at: Vector2i = cell
			next[Vector2i(at.y, across_ - 1 - at.x)] = true
		cells = next
		var swap: int = across_
		across_ = deep
		deep = swap
	if mirror == "z" or mirror == "x":
		var flipped: Dictionary = {}
		for cell: Variant in cells:
			var at: Vector2i = cell
			flipped[Vector2i(at.x, deep - 1 - at.y) if mirror == "z"
				else Vector2i(across_ - 1 - at.x, at.y)] = true
		cells = flipped
	var said_cells := PackedStringArray()
	for cell: Variant in cells:
		said_cells.append("%d,%d" % [(cell as Vector2i).x, (cell as Vector2i).y])
	said_cells.sort()
	_plans[key] = "%dx%d %s" % [across_, deep, "|".join(said_cells)]
	return _plans[key]


## A shape laid out: which plate of which stud is what colour, which of them
## are the core, the ledges and the top, and the parts that cover them.
class Plan extends RefCounted:
	var columns: Dictionary          ## Vector2i -> PackedInt32Array
	var tall: int
	var smooth: bool
	## Straight sides as tiles on bricks with side studs.
	var sides_smooth: bool = true
	var library: PartLibrary
	## Plates taken by a surface part: Vector3i(x, j, z) -> true.
	var taken: Dictionary = {}
	var made: Array = []
	## Whether the shape holds a point, in studs across, plates up from the
	## plan's foot and studs along.
	var sample: Callable
	## The mirror: "" none, "x" about a plane across x, "z" across z, with
	## [member sum] the coordinate a cell and its mirror add up to.
	var axis: String = ""
	var sum: int = 0
	## Wedge plates and bricks on a diagonal plan edge. Off, the plan's edges
	## are left in plain plates and bricks.
	var wedges: bool = true
	## For a "mixed" surface, which kind of slope suits a stud, cell ->
	## "curved" or "straight": a sculpt says where it is round and where
	## it is a flat facet, and a chamfered cube is not a sphere.
	var prefer: Callable = Callable()
	## The model's own surface over a stud at its nine thirds of a stud
	## (Brickify.Grid.fine): with it, each surface part is chosen by how near
	## it lays the surface (_fit), not by [member prefer].
	var fine: Callable = Callable()
	## The shape's colour at a point, as [member sample] says whether it is
	## there: -1 outside.
	var colour_at: Callable = Callable()
	## Whether a section that is a disc of a size round parts come in is
	## laid in them (round_runs).
	var rounds: bool = true
	## Off the ground: its foot is held only where [member foot_held] has the
	## stud, a chassis or a brick under it.
	var afloat: bool = false
	var foot_held: Dictionary = {}

	## Whether the stud [param cell] at the plan's foot stands on something:
	## the ground, or off it, what is under it.
	func foot_on(cell: Vector2i) -> bool:
		return not afloat or foot_held.has(cell)
	## Whether a course over nothing with nothing studded over it is laid in
	## plates (lay). A sculpt's grid keeps its bricks: Brickify's own lay
	## measures what it is, and a hollow sculpt lost 3% of itself.
	var bridges: bool = true
	## Whether a grid's pieces are joined in every way a design's are, once
	## its own first ways are spent (stitch): for a caller that keeps every
	## piece, so what is not joined here is joined or said there.
	var rejoin: bool = false
	## A slope in the colour of the surface it stands for (_shown), not the
	## stud above it: for a sculpt's grid, whose colours are its surface's.
	## A design's bands keep the colour above, as they always have.
	var colour_shown: bool = false
	## With colours here, a slope the LEGO Group sells in none of them (by Rebrickable's
	## elements) is not laid: the inverted 2 x 2 slope Brickify once laid under
	## overhangs, 3660a, has no element in any colour, so no colour of it can
	## be bought.
	var sold_in := PackedInt32Array()
	## Every slope only in a colour it is sold in, chosen by the flag too: a
	## sculpt in one colour asked for, which is not recoloured after. A blue
	## bunny laid again by the flag came back with inverted slopes no one
	## sells in blue.
	var sold_only: bool = false
	var _sold_somewhere: Dictionary = {}
	## Rounds of the stitch in a row whose first ways, kept unchecked, left no
	## fewer pieces, before it takes them back and checks them (see [method
	## stitch]).
	const STALLED := 12
	## The parts [method _replate] may lay again, by the plates they stand in,
	## for each kind it is asked: mapped once a stitch round (Vector3i(x,
	## plate, z) -> index).
	var _replatable_at: Dictionary = {}
	## A curved side laid on its side (lay_shell): its outside is the flank
	## a person sees, and where it curves a curved slope fits as well as a
	## cheese slope, the curved one.
	var flank: bool = false
	## The round parts round_runs laid, put into [member made] by lay(), and
	## the runs said, for a probe.
	var round_made: Array = []
	var round_said: Array = []
	## Faces to lay onto the shells, as Shapes._read_faces reads them; the
	## ones laid, by what they were said as, and why each other one was not.
	var faces: Array = []
	var faces_laid: Array = []
	var faces_why: Dictionary = {}
	## Bond as a builder does (a sculpt's grid, Brickify's): only what shows
	## of a brick of the core is laid in its colour and what is hidden in any,
	## so three plates of the body are a brick wherever they are, whatever
	## colour the measuring gave the hidden ones ([method _bonded]); and once
	## stitched, parts that make one part are merged ([method merge]). Laid
	## with every hidden plate in its measured colour, a cow at 48 studs was
	## 5,082 parts, 37% of them 1 x 1s, where a greedy stack of bricks was
	## 1,882.
	var bond: bool = false
	## A run's stop (Brickify.Progress.stopped), asked each course of lay
	## and each pass of merge: bonding made a course long enough that a quit
	## waited 10 s for the laying.
	var stop: Callable = Callable()
	## The colour of a core part none of which shows: the model's main colour.
	var core_colour: int = -1
	var _made_in_colour: Dictionary = {}

	func _init(given: Dictionary, height: int, tiles: bool, parts: PartLibrary) -> void:
		columns = given
		tall = height
		smooth = tiles
		library = parts

	func at(cell: Vector2i, j: int) -> int:
		if j < 0 or j >= tall or not columns.has(cell):
			return -1
		return (columns[cell] as PackedInt32Array)[j]

	## The top plate of a run of plates that has another under it: a tile,
	## where the top is to be smooth.
	func is_top(cell: Vector2i, j: int) -> bool:
		if not smooth or at(cell, j) < 0 or at(cell, j + 1) >= 0 or at(cell, j - 1) < 0 \
				or studded.has(cell):
			return false
		# Beside a bridge one plate thick, a plate, so the bridge's plates can
		# reach across onto it: tiled, a car's nose was tied to the body over
		# its wheel arch by nothing, and came out a piece of its own.
		for step: Vector2i in Shapes.OUT:
			if at(cell + step, j) >= 0 and at(cell + step, j - 1) < 0 and at(cell + step, j + 1) < 0:
				return false
		return true

	## The core's plates: every plate of the shape but a top tile, and but a
	## plate under a shell.
	func body(cell: Vector2i, j: int) -> bool:
		return at(cell, j) >= 0 and not is_top(cell, j) and not under_shell(cell, j)

	## Whether the core's plate [param j] of [param cell] is right under a
	## plate a shell has taken: the shell's parts lie on their sides there,
	## and stand their edge on its top, which a stud would run into. So it is
	## a tile, smooth or not.
	func under_shell(cell: Vector2i, j: int) -> bool:
		return at(cell, j) >= 0 and shelled.has(Vector3i(cell.x, j + 1, cell.y))

	## Studs where course [param k] is whole, in one colour: with [member
	## bond], in one colour where it shows, but in a thin part's columns
	## ([member plain_at]) as measured, whose plates cross and hold it.
	func full(k: int) -> Dictionary:
		var out: Dictionary = {}
		for key: Variant in columns:
			var cell: Vector2i = key
			var j: int = 3 * k
			if not (body(cell, j) and body(cell, j + 1) and body(cell, j + 2)):
				continue
			if bond and not plain_at.has(cell) and shown_colour(cell, j, 3) != MIXED \
					or at(cell, j) == at(cell, j + 1) and at(cell, j + 1) == at(cell, j + 2):
				out[cell] = true
		return out

	## A part's colour that nothing decides: none of it shows.
	const ANY := -2
	## Plates that show in two colours: no one part.
	const MIXED := -3

	## Whether plate [param j] of [param cell] shows: the shape is not there
	## on one of its six sides. A plate a stud in from the surface, under a
	## slope or behind the side, is hidden.
	func shows(cell: Vector2i, j: int) -> bool:
		if at(cell, j - 1) < 0 or at(cell, j + 1) < 0:
			return true
		for step: Vector2i in Shapes.OUT:
			if at(cell + step, j) < 0:
				return true
		return false

	## The colour [param height] plates from [param j] up show: [constant ANY]
	## where none shows, [constant MIXED] where they show two.
	func shown_colour(cell: Vector2i, j: int, height: int) -> int:
		var out: int = ANY
		for n: int in height:
			if not shows(cell, j + n):
				continue
			var c: int = at(cell, j + n)
			if out == ANY:
				out = c
			elif c != out:
				return MIXED
		return out

	## Whether the shape is its own mirror, about a plane across x or z: the
	## columns either side the same, plate for plate and colour for colour.
	func mirror_of() -> void:
		for try_axis: String in ["z", "x"]:
			var low: int = 1 << 30
			var high: int = -(1 << 30)
			for key: Variant in columns:
				var cell: Vector2i = key
				var c: int = cell.y if try_axis == "z" else cell.x
				low = mini(low, c)
				high = maxi(high, c)
			var total: int = low + high
			var same: bool = true
			for key: Variant in columns:
				var cell: Vector2i = key
				var twin: Vector2i = Vector2i(cell.x, total - cell.y) if try_axis == "z" \
					else Vector2i(total - cell.x, cell.y)
				if not columns.has(twin) or columns[twin] != columns[cell]:
					same = false
					break
			if same:
				axis = try_axis
				sum = total
				return

	func across(cell: Vector2i) -> int:
		return cell.y if axis == "z" else cell.x

	func reflect(cell: Vector2i) -> Vector2i:
		return Vector2i(cell.x, sum - cell.y) if axis == "z" else Vector2i(sum - cell.x, cell.y)

	## The cells of the middle strip at plate [param j]: across the mirror
	## plane, alternately two studs wide and four (a plane between studs),
	## or three and one (a plane through a row of studs), so the joints
	## either side of it move from layer to layer and every half is tied to
	## the strip by the layer over it. Two and none, a nose only a few plates
	## thick, all of them odd, had no strip and came out as two halves.
	func spine(j: int) -> Vector2i:
		if axis.is_empty():
			return Vector2i(1, 0)
		# posmod: a shape centred on its at has studs either side of nought,
		# and -1 % 2 is -1, which took a plane between studs for one through a
		# row of them and laid a three-wide strip off the middle of a plinth.
		if posmod(sum, 2) == 1:
			var a: int = (sum - 1) / 2
			return Vector2i(a, a + 1) if j % 2 == 0 else Vector2i(a - 1, a + 2)
		var m: int = sum / 2
		return Vector2i(m - 1, m + 1) if j % 2 == 0 else Vector2i(m, m)

	## The top of each column (one plate over its highest) and its foot.
	func tops() -> Dictionary:
		var out: Dictionary = {}
		for key: Variant in columns:
			var column: PackedInt32Array = columns[key]
			for j: int in range(tall - 1, -1, -1):
				if column[j] >= 0:
					out[key] = j + 1
					break
		return out

	func feet() -> Dictionary:
		var out: Dictionary = {}
		for key: Variant in columns:
			var column: PackedInt32Array = columns[key]
			for j: int in tall:
				if column[j] >= 0:
					out[key] = j
					break
		return out

	## Where a layer's section is a disc of a size round parts come in — a
	## cylinder, a dome's or an egg's narrowing sections, a post — the
	## round parts a set lays there, by the round pattern's own choice for
	## that diameter (Rounds._body: round plates and bricks, cylinder
	## halves, four corner rounds tied by a round plate), instead of plates
	## and corner pieces tiled stud by stud. A whole round part's collision
	## cover is its square box, so it is laid only where the box holds
	## nothing else of the layer; the plates it stands in are taken, so
	## nothing else is laid there, no slope stands on them and no wedge's
	## cut side reaches in. The edge fitter left them out for that reason:
	## beside parts that follow the curve, the check reads them as squares.
	func round_runs() -> void:
		if not rounds or library == null or not colour_at.is_valid():
			return
		# Every layer's discs, by where and how wide: "x z d colour" -> plates.
		var discs: Dictionary = {}
		for j: int in tall:
			var seen: Dictionary = {}
			for key: Variant in columns:
				var cell: Vector2i = key
				var c: int = at(cell, j)
				if c < 0 or seen.has(cell):
					continue
				var blob: Array[Vector2i] = [cell]
				seen[cell] = true
				var low: Vector2i = cell
				var high: Vector2i = cell
				var n: int = 0
				while n < blob.size():
					var here: Vector2i = blob[n]
					n += 1
					low = Vector2i(mini(low.x, here.x), mini(low.y, here.y))
					high = Vector2i(maxi(high.x, here.x), maxi(high.y, here.y))
					for step: Vector2i in Shapes.OUT:
						var next: Vector2i = here + step
						if not seen.has(next) and at(next, j) == c:
							seen[next] = true
							blob.append(next)
				var d: int = high.x - low.x + 1
				if d != high.y - low.y + 1 or not d in Rounds.DIAMETERS:
					continue
				# Its own mirror where the shape is one: a disc off the plane
				# has no twin, and the check would call the model lopsided.
				if not axis.is_empty() and across(low) + across(high) != sum:
					continue
				if _is_disc(low, d, j, blob.size()):
					var said: String = "%d %d %d %d" % [low.x, low.y, d, c]
					if not discs.has(said):
						discs[said] = []
					(discs[said] as Array).append(j)
		# Runs of plates one over the next, each to be laid as a length of
		# round body: [low, d, colour, from, to].
		var runs: Array = []
		for said: Variant in discs:
			var plates: Array = discs[said]
			var parts: PackedStringArray = str(said).split(" ")
			var from: int = 0
			while from < plates.size():
				var to: int = from + 1
				while to < plates.size() and int(plates[to]) == int(plates[to - 1]) + 1:
					to += 1
				runs.append([Vector2i(parts[0].to_int(), parts[1].to_int()), parts[2].to_int(),
					parts[3].to_int(), int(plates[from]), int(plates[to - 1]) + 1])
				from = to
		runs.sort_custom(func(a: Array, b: Array) -> bool: return int(a[3]) < int(b[3]))
		runs = _stacked(runs)
		_ease(runs)
		Rounds._parts = library
		var capped: Dictionary = {}    ## Vector2i cell -> the plate a dish caps it from
		for run: Array in runs:
			var low: Vector2i = run[0]
			var d: int = run[1]
			if capped.has(low + Vector2i(d / 2, d / 2)) \
					and int(run[3]) >= int(capped[low + Vector2i(d / 2, d / 2)]):
				continue
			# Taken whole by the eased rim under it.
			if int(run[3]) >= int(run[4]):
				continue
			var top: int = run[4]
			var highest: int = -1
			var studs_kept: bool = false
			for i: int in d:
				for k: int in d:
					var cell := Vector2i(low.x + i, low.y + k)
					studs_kept = studs_kept or studded.has(cell)
					for j: int in range(top, tall):
						if at(cell, j) >= 0:
							highest = maxi(highest, j)
			# The top of the shape, and smooth: its last plate round tiles, as
			# a set finishes a round it shows from above, not bare studs.
			if highest < 0 and smooth and not studs_kept:
				if top - int(run[3]) > 1:
					_round_run(low, d, run[2], run[3], top - 1, int(run[5]) if run.size() > 5 else 0)
				_round_tiles(low, d, run[2], top - 1)
				round_said.append("%d at %d,%d plates %d-%d, tiled" % [d, low.x, low.y, run[3], top - 1])
				continue
			_round_run(low, d, run[2], run[3], run[4], int(run[5]) if run.size() > 5 else 0)
			round_said.append("%d at %d,%d plates %d-%d" % [d, low.x, low.y, run[3], int(run[4]) - 1])
			# A dome's crown: where all the shape has left over the run, in its
			# box, is no taller than a dish, the dish — not a cake of rings.
			if not DISHES.has(d):
				continue
			var cap: int = highest + 1 - top
			var dish: Array = DISHES[d]
			var riser: int = 1 if dish.size() > 4 else 0
			if highest < 0 or cap > int(dish[1]) + riser + 1 or not _cap_free(low, d, top, highest):
				continue
			var cells: Array[Vector2i] = []
			for i: int in d:
				for k: int in d:
					cells.append(Vector2i(low.x + i, low.y + k))
					for j: int in range(top, highest + 1):
						taken[Vector3i(low.x + i, j, low.y + k)] = true
			# The studs at its middle, under a round tile.
			var crown: Array = DISHES[d]
			var centre: Array[Vector2i] = []
			for i: int in 2:
				for k: int in 2:
					centre.append(low + Vector2i(d / 2 - 1 + i, d / 2 - 1 + k))
			if riser > 0:
				round_made.append({"part": dish[4], "color": int(run[2]),
					"x": low.x + d / 2 - 1, "y": top, "z": low.y + d / 2 - 1, "rot": 0,
					"_cells": centre, "_h": 1, "_studs": centre, "_base": centre,
					"_round": true})
			round_made.append({"part": dish[0], "color": int(run[2]), "x": low.x,
				"y": top + riser, "z": low.y, "rot": 0, "_cells": cells, "_h": int(dish[1]),
				"_studs": centre, "_base": centre if riser > 0 else cells, "_round": true})
			var middle: float = d / 2.0 - float(crown[3]) / 2.0
			round_made.append({"part": crown[2], "color": int(run[2]), "x": low.x + middle,
				"y": top + riser + int(dish[1]), "z": low.y + middle, "rot": 0,
				"_cells": centre, "_h": 1, "_studs": [] as Array[Vector2i],
				"_base": centre, "_round": true, "_top": true})
			capped[low + Vector2i(d / 2, d / 2)] = top

	## The runs that are a round body's: two plates or more, or one plate on
	## or under another round about the same middle. A single plate that is
	## a disc where an oval body passes through one (an owl's head and body
	## are ovals, 13 studs by 11) was laid as a round plate with its studs
	## bare round the rim and, at the crown, a dish on it: the owl's head
	## wore it as a hat, and the run took it off and stacked round plates
	## there by hand, studs on every ring.
	static func _stacked(runs: Array) -> Array:
		var middles: Dictionary = {}    ## "2x 2z plate" -> true, at each plate a run has
		for run: Array in runs:
			var low: Vector2i = run[0]
			for j: int in range(int(run[3]), int(run[4])):
				middles["%d %d %d" % [2 * low.x + int(run[1]), 2 * low.y + int(run[1]), j]] = true
		var out: Array = []
		for run: Array in runs:
			var low: Vector2i = run[0]
			var middle: String = "%d %d" % [2 * low.x + int(run[1]), 2 * low.y + int(run[1])]
			if int(run[4]) - int(run[3]) >= 2 or middles.has("%s %d" % [middle, int(run[3]) - 1]) \
					or middles.has("%s %d" % [middle, int(run[4])]):
				out.append(run)
		return out

	## A dome's step eased, as a set eases one: where a round of 6 or 8 has a
	## round a stud narrower standing on it, the step between them was a
	## ledge of bare studs a stud wide, ring over ring — a wedding cake from
	## the side. A curved slope wants two studs of ledge to fall over, so the
	## round above stands inset for the slopes' two plates: on the rim of the
	## round below, 2 x 2 curved slopes falling out on each side and a round
	## plate with a quarter-round tile at each corner; inside them a round
	## four studs narrower (a core of round plates); and the round above goes
	## on from a round plate that bridges in over the slopes' tops. A round
	## above only one or two plates tall is the slopes, all of it. Only where
	## the round above is one colour with the one under it, and nothing else
	## of the shape is in the rim.
	const EASED: Array = [6, 8]
	## The slope on each side of an eased rim, and what stands on a corner's
	## one stud: a round plate and a quarter-round tile, two plates as the
	## slope is.
	const EASE_SLOPE := "15068"
	const EASE_CORNER: Array = ["6141", "25269"]

	func _ease(runs: Array) -> void:
		var at_bottom: Dictionary = {}    ## "x z d c from" -> the run
		for run: Array in runs:
			at_bottom["%d %d %d %d %d" % [(run[0] as Vector2i).x, (run[0] as Vector2i).y,
				int(run[1]), int(run[2]), int(run[3])]] = run
		for run: Array in runs:
			var low: Vector2i = run[0]
			var d: int = run[1]
			if not d in EASED or int(run[3]) >= int(run[4]):
				continue
			var key: String = "%d %d %d %d %d" % [low.x + 1, low.y + 1, d - 2, int(run[2]),
				int(run[4])]
			if not at_bottom.has(key):
				continue
			var step: int = int(run[4])
			if not _rim_free(low, d, step):
				continue
			_ease_rim(low, d, int(run[2]), step)
			_round_run(low + Vector2i(2, 2), d - 4, int(run[2]), step, step + 2)
			round_said.append("%d at %d,%d plates %d-%d eased" % [d, low.x, low.y, step,
				step + 1])
			# The round above goes on from over the slopes. One or two plates
			# tall, the slopes are all of it — a dome's rings a plate or two
			# each were left a stack of round plates with studs bare on every
			# ring, the owl's head among them — and a round on it within the
			# two plates goes on from over them too.
			var middle: Vector2i = 2 * low + Vector2i(d, d)
			for other: Array in runs:
				if other == run or 2 * (other[0] as Vector2i) + Vector2i(other[1], other[1]) != middle \
						or int(other[3]) < step or int(other[3]) >= step + 2:
					continue
				other[3] = step + 2
				if other.size() < 6:
					other.append(d - 4)
				if other[3] >= other[4]:
					round_said.append("%d at %d,%d is the slopes" % [int(other[1]),
						(other[0] as Vector2i).x, (other[0] as Vector2i).y])

	## Whether the rim of the round of [param d] at [param low], for the two
	## plates from [param from], has nothing of the shape but the round a
	## stud narrower, and nothing taken.
	func _rim_free(low: Vector2i, d: int, from: int) -> bool:
		for i: int in d:
			for k: int in d:
				if i >= 2 and i < d - 2 and k >= 2 and k < d - 2:
					continue
				var cell := Vector2i(low.x + i, low.y + k)
				var inner: bool = i >= 1 and i < d - 1 and k >= 1 and k < d - 1
				for j: int in range(from, from + 2):
					if taken.has(Vector3i(cell.x, j, cell.y)):
						return false
					if not inner and at(cell, j) >= 0:
						return false
		return true

	## The slopes and corners round the rim of a round of [param d], on its
	## top plate at [param j]: the two studs of each side between its
	## corners fall out, two by two.
	func _ease_rim(low: Vector2i, d: int, c: int, j: int) -> void:
		var slope: Dictionary = Shapes.part(library, EASE_SLOPE)
		if slope.is_empty():
			return
		for side: int in 4:
			var facing: Vector2i = Shapes.OUT[side]
			var perp := Vector2i(absi(facing.y), absi(facing.x))
			# The high row, a stud in from the edge on that side.
			var inner: Vector2i
			match side:
				0: inner = Vector2i(0, d - 2)
				1: inner = Vector2i(d - 2, 0)
				2: inner = Vector2i(0, 1)
				_: inner = Vector2i(1, 0)
			for a: int in range(2, d - 2, 2):
				var high_row: Array[Vector2i] = []
				var cells: Array[Vector2i] = []
				for n: int in 2:
					var cell: Vector2i = low + inner + perp * (a + n)
					high_row.append(cell)
					cells.append(cell)
					cells.append(cell + facing)
				var corner := Vector2i(1 << 30, 1 << 30)
				for one: Vector2i in cells:
					corner = Vector2i(mini(corner.x, one.x), mini(corner.y, one.y))
				round_made.append({"part": EASE_SLOPE, "color": c, "x": corner.x, "y": j,
					"z": corner.y, "rot": posmod(side + int(slope["turn"]), 4), "_top": true,
					"_cells": cells, "_h": 2, "_studs": [] as Array[Vector2i],
					"_base": high_row, "_slope": true, "_round": true})
				_take(cells, j, 2)
		# A corner's one stud: a round plate, and a quarter-round tile on it
		# with its curve to the outside.
		var tile: Lbm.PartMesh = library.mesh_for(EASE_CORNER[1])
		var corners: Array[Vector2i] = [Vector2i(1, 1), Vector2i(d - 2, 1),
			Vector2i(d - 2, d - 2), Vector2i(1, d - 2)]
		var inward: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1),
			Vector2(1, -1)]
		for n: int in 4:
			var cell: Vector2i = low + corners[n]
			var one: Array[Vector2i] = [cell]
			round_made.append({"part": EASE_CORNER[0], "color": c, "x": cell.x, "y": j,
				"z": cell.y, "rot": 0, "_cells": one, "_h": 1, "_studs": one, "_base": one,
				"_round": true})
			var rot: int = Rounds.QUARTER_TURNS[n]
			if tile != null:
				for turn: int in 4:
					if Rounds.lean(tile, turn) == inward[n]:
						rot = turn
						break
			round_made.append({"part": EASE_CORNER[1], "color": c, "x": cell.x, "y": j + 1,
				"z": cell.y, "rot": rot, "_cells": one, "_h": 1,
				"_studs": [] as Array[Vector2i], "_base": one, "_round": true, "_top": true})
			_take(one, j, 2)

	## The dish that crowns a round of each diameter, how many plates of it
	## there are, as the round pattern's dome nose lays them, and the round
	## tile over the studs at its middle and how wide: a 4 x 4 dish has one
	## stud, the others a 2 x 2. The 4 x 4 stands on a 2 x 2 round's four
	## studs, the fifth: a round plate's twelve run into its underside by the
	## parts' real shapes, as they do in BrickBench's check.
	const DISHES: Dictionary = {4: ["3960", 2, "98138", 1, "4032a"], 6: ["44375b", 2, "14769", 2],
		8: ["3961", 3, "14769", 2]}

	## The round tiles that finish a round's top, by diameter: one whole, or
	## rings of corner round tiles (TILE_RINGS). There is no round tile of 8.
	const ROUND_TILES: Dictionary = {1: "98138", 2: "14769", 4: "27925", 6: "7212", 8: "27507"}

	## A round's top plate in round tiles: one round tile, or four corner
	## round tiles each turned to lean on the middle, read off its mesh — and
	## a ring's middle in the round tiles of the round inside it. Before, the
	## middle of a round of 8 kept 12 bare studs.
	func _round_tiles(low: Vector2i, d: int, c: int, j: int) -> void:
		var part: String = ROUND_TILES[d]
		var cells: Array[Vector2i] = []
		for i: int in d:
			for k: int in d:
				cells.append(Vector2i(low.x + i, low.y + k))
				taken[Vector3i(low.x + i, j, low.y + k)] = true
		if d <= 2 or d == 6:
			round_made.append({"part": part, "color": c, "x": low.x, "y": j, "z": low.y,
				"rot": 0, "_cells": cells, "_h": 1, "_studs": [] as Array[Vector2i],
				"_base": cells, "_round": true, "_top": true})
			return
		# The corner round tiles of 4 and 8 are rings (macaroni): a set nests
		# them, 4 x 4 round 3 x 3 round 2 x 2, with a round tile in the middle.
		# Laid alone, a round of 8's top kept twenty bare studs inside its
		# ring and a round of 4's a hole a stud across. (A 6 x 6 round tile
		# would do the middle of 8, but its cover is its square box, and the
		# check reads it as overlapping the ring.)
		for ring: Array in TILE_RINGS:
			var across: int = ring[0]
			if across > d:
				continue
			var off: int = (d - across) / 2
			round_made.append_array(_quarter_tiles(low + Vector2i(off, off), across,
				str(ring[1]), c, j, _box(low + Vector2i(off + 1, off + 1), across - 2)))
		var middle: Array[Vector2i] = []
		for one: Variant in _box(low + Vector2i(d / 2 - 1, d / 2 - 1), 2):
			middle.append(one)
		round_made.append({"part": ROUND_TILES[2], "color": c, "x": low.x + d / 2 - 1, "y": j,
			"z": low.y + d / 2 - 1, "rot": 0, "_cells": middle, "_h": 1,
			"_studs": [] as Array[Vector2i], "_base": middle, "_round": true, "_top": true})

	## The rings of corner round tiles, widest first: each a quarter ring a
	## stud wide, whose inside is the next.
	const TILE_RINGS: Array = [[8, "27507"], [6, "79393"], [4, "27925"]]

	static func _box(low: Vector2i, d: int) -> Dictionary:
		var out: Dictionary = {}
		for i: int in d:
			for k: int in d:
				out[low + Vector2i(i, k)] = true
		return out

	## Four corner round tiles of [param part] over the box of [param d] at
	## [param low], each turned to lean as a quarter of a round, studs in
	## [param skip] left to another part. [param top]: what shows from above.
	func _quarter_tiles(low: Vector2i, d: int, part: String, c: int, j: int,
			skip: Dictionary, top: bool = true) -> Array:
		var out: Array = []
		var mesh: Lbm.PartMesh = library.mesh_for(part)
		var half: int = d / 2
		var corners: Array[Vector2i] = [Vector2i(0, 0), Vector2i(half, 0), Vector2i(half, half),
			Vector2i(0, half)]
		# Which way each one's cover leans: a 2 x 2 corner round tile's to the
		# middle, as a corner round brick's does, the 4 x 4's and 3 x 3's
		# (quarter rings a stud wide) to their curve. Turned the other way,
		# four made a star of curves facing each other.
		var inward: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
		if part == "27507" or part == "79393":
			inward = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
		for n: int in 4:
			var rot: int = Rounds.QUARTER_TURNS[n]
			if mesh != null:
				for turn: int in 4:
					if Rounds.lean(mesh, turn) == inward[n]:
						rot = turn
						break
			var mine: Array[Vector2i] = []
			for i: int in half:
				for k: int in half:
					var cell: Vector2i = low + corners[n] + Vector2i(i, k)
					if not skip.has(cell):
						mine.append(cell)
			out.append({"part": part, "color": c, "x": low.x + corners[n].x, "y": j,
				"z": low.y + corners[n].y, "rot": rot, "_cells": mine, "_h": 1,
				"_studs": [] as Array[Vector2i], "_base": mine, "_round": true, "_top": top})
		return out

	## A round part a shell's lowest edge stands on, finished smooth under it:
	## its top plate laid as a set tiles the rim of a round it stands a panel
	## on, in rings of corner round tiles as far in as the shells reach, and a
	## round plate inside them, whose studs the core over it stands on. A cat
	## head's flanks and face stood their edges on an 8 x 8 round plate's
	## studs, 4 LDU into each by the parts' real shapes: the lattice takes
	## every stud for one into a socket. Where no ring is narrow enough, or
	## the part is not a round plate, the shells give the columns over its
	## studs back to the core, which stands on them upright.
	func under_shells(shells: Array) -> void:
		var kept_: Array = []
		var added: Array = []
		for one: Dictionary in round_made:
			var under: Array[Vector2i] = _studs_under_shell(one)
			if under.is_empty():
				kept_.append(one)
				continue
			var ringed: Array = _ringed(one)
			if not ringed.is_empty():
				added.append_array(ringed)
				continue
			kept_.append(one)
			for cell: Vector2i in under:
				for shell: Dictionary in shells:
					var mine: Dictionary = shell["cells"]
					for key: Variant in mine.keys():
						if (key as Vector3i).x == cell.x and (key as Vector3i).z == cell.y:
							mine.erase(key)
							taken.erase(key)
							shelled.erase(key)
		round_made = kept_ + added

	## The cells of a round part's studs that a shell's plate stands right
	## over: its own studs, read off the part, where it is a whole round.
	func _studs_under_shell(one: Dictionary) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		var studs: Array = one.get("_studs", [])
		if studs.is_empty():
			return out
		var over: int = roundi(float(one["y"])) + int(one.get("_h", 1))
		var cells: Array = studs
		var read: Array = Patterns._studs_of(library, str(one["part"]))
		if int(one.get("rot", 0)) == 0 and read.size() == 3 \
				and studs.size() == int(read[0]) * int(read[1]):
			var low := Vector2i(roundi(float(one["x"])), roundi(float(one["z"])))
			cells = []
			for at_: Variant in read[2]:
				cells.append(low + (at_ as Vector2i))
		for cell: Vector2i in cells:
			if shelled.has(Vector3i(cell.x, over, cell.y)):
				out.append(cell)
		return out

	## [param one], a round plate, as rings of corner round tiles and the
	## round plate inside them, the widest with no shell over it; [] where
	## there is none.
	func _ringed(one: Dictionary) -> Array:
		var cells: Array = one.get("_cells", [])
		var d: int = roundi(sqrt(float(cells.size())))
		if int(one.get("_h", 1)) != 1 or d * d != cells.size() or not Rounds.PARTS.has(d) \
				or str((Rounds.PARTS[d] as Dictionary).get("plate", "")) != str(one["part"]):
			return []
		var rings: Dictionary = {}
		for ring: Array in TILE_RINGS:
			rings[int(ring[0])] = str(ring[1])
		var low := Vector2i(roundi(float(one["x"])), roundi(float(one["z"])))
		var j: int = roundi(float(one["y"]))
		var c: int = int(one["color"])
		for inner: int in range(d - 2, 1, -2):
			if not Rounds.PARTS.has(inner) or not (Rounds.PARTS[inner] as Dictionary).has("plate"):
				continue
			var off: int = (d - inner) / 2
			var clear: bool = true
			for across: int in range(d, inner, -2):
				clear = clear and rings.has(across)
			# No shell over any stud the plate inside may have.
			for at_: Variant in _box(low + Vector2i(off, off), inner):
				clear = clear and not shelled.has(Vector3i((at_ as Vector2i).x, j + 1,
					(at_ as Vector2i).y))
			if not clear:
				continue
			var out: Array = []
			for across: int in range(d, inner, -2):
				var o: int = (d - across) / 2
				out.append_array(_quarter_tiles(low + Vector2i(o, o), across, str(rings[across]),
					c, j, _box(low + Vector2i(o + 1, o + 1), across - 2), false))
			var middle: Array[Vector2i] = []
			for at_: Variant in _box(low + Vector2i(off, off), inner):
				middle.append(at_)
			out.append({"part": str(Rounds.PARTS[inner]["plate"]), "color": c,
				"x": low.x + off, "y": j, "z": low.y + off, "rot": 0, "_cells": middle,
				"_h": 1, "_studs": middle, "_base": middle, "_round": true})
			return out
		return []

	## Whether nothing of the box at [param low], [param d] studs across,
	## from plate [param from] to [param to], is taken or another colour's.
	func _cap_free(low: Vector2i, d: int, from: int, to: int) -> bool:
		for i: int in d:
			for k: int in d:
				for j: int in range(from, to + 1):
					if taken.has(Vector3i(low.x + i, j, low.y + k)):
						return false
		return true

	## The heights of the round parts the round pattern lays, in plates.
	const ROUND_TALL: Dictionary = {"3062b": 3, "3941": 3, "87081": 3, "6222": 3, "5152": 3,
		"48092": 3, "85941": 15, "24593": 6, "30562": 18}

	## Lay plates [param from] to [param to] of a disc [param d] studs across
	## with its low corner at [param low], in colour [param c].
	## [param under]: the diameter of the round it stands on, where that is
	## narrower — its first plate is then a round plate, bridging in.
	func _round_run(low: Vector2i, d: int, c: int, from: int, to: int, under: int = 0) -> void:
		var parts: Array = []
		var state := {"d": d, "below": "", "last_d": under if under > 0 else d}
		var centre := Vector2(low.x + d / 2.0, low.y + d / 2.0)
		Rounds._body(parts, centre, float(from), d, to - from, c, state)
		for one: Dictionary in parts:
			var part: String = str(one["part"])
			var tall_: int = int(ROUND_TALL.get(part, 1))
			# A quarter covers its own corner of the box; a half its half; a
			# whole round part all of it.
			var size := Vector2i(d, d)
			if part in ["5152", "48092", "30562"]:
				size = Vector2i(d / 2, d / 2)
			elif part in ["85941", "24593"]:
				size = Vector2i(d, d / 2)
			var cells: Array[Vector2i] = []
			for i: int in size.x:
				for k: int in size.y:
					cells.append(Vector2i(roundi(float(one["x"])) + i, roundi(float(one["z"])) + k))
			one["_cells"] = cells
			one["_h"] = tall_
			one["_studs"] = cells
			one["_base"] = cells
			one["_round"] = true
			round_made.append(one)
		for i: int in d:
			for k: int in d:
				for j: int in range(from, to):
					taken[Vector3i(low.x + i, j, low.y + k)] = true

	## Whether the blob of [param count] studs at plate [param j] is, over
	## the box of [param d] studs at [param low] and a stud round it, nearer
	## a disc filling the box than the box itself, on a 4 x 4 grid in every
	## stud, and within a tenth of the disc; and the box holds nothing else.
	func _is_disc(low: Vector2i, d: int, j: int, count: int) -> bool:
		var c: int = -1
		var inside: int = 0
		for i: int in d:
			for k: int in d:
				var cell := Vector2i(low.x + i, low.y + k)
				if at(cell, j) >= 0:
					c = at(cell, j)
					inside += 1
				if taken.has(Vector3i(cell.x, j, cell.y)):
					return false
		if inside != count:
			return false
		# The section against a disc of its own area about the box's middle,
		# and against the box: a dome's section a third of a stud wider than
		# the disc of six is still a disc, and a square post is not.
		var centre := Vector2(low.x + d / 2.0, low.y + d / 2.0)
		var points: Array[Vector2] = []
		var here: Array[bool] = []
		var area: int = 0
		var y: float = j + 0.5
		for i: int in range(-1, d + 1):
			for k: int in range(-1, d + 1):
				for v: int in 4:
					for u: int in 4:
						var p := Vector2(low.x + i + (u + 0.5) / 4.0, low.y + k + (v + 0.5) / 4.0)
						var inside_: bool = int(colour_at.call(p.x, y, p.y)) == c
						points.append(p)
						here.append(inside_)
						area += 1 if inside_ else 0
		var r2: float = area / 16.0 / PI
		var off_disc: int = 0
		var off_box: int = 0
		for n: int in points.size():
			var p: Vector2 = points[n]
			var box: bool = p.x >= low.x and p.y >= low.y and p.x < low.x + d and p.y < low.y + d
			off_disc += 1 if here[n] != (p.distance_squared_to(centre) <= r2) else 0
			off_box += 1 if here[n] != box else 0
		return off_disc < off_box and off_disc <= 0.15 * area

	## How far out from its core a curved side is laid on its side, in studs:
	## five plates of a shell.
	const SHELL_DEPTH := 2
	## A side narrower than this behind its shell keeps no core to hold it.
	const SHELL_CORE := 2
	## The share of the plates a shell takes out of the core that its kept
	## parts must cover, or the side is laid upright.
	const SHELL_KEEPS := 0.4
	## The brick with a stud on one side that holds a shell.
	const ANCHOR := "87087"
	## And the longer ones, by how many lanes each holds: a run of lanes in a
	## course of the core's wall is held by 1 x 4s and 1 x 2s with studs on a
	## side, not a 1 x 1 a lane.
	const ANCHOR_RUNS: Dictionary = {4: "30414", 2: "11211", 1: ANCHOR}

	## Side studs a shell is held by, laid in the core: placements.
	var anchors: Array = []
	## What each shell laid came to (lay_shell), said.
	var kept: Array = []
	## For a shell's own plan, the cells of its foot a side stud reaches:
	## only parts joined to those are kept.
	var held: Dictionary = {}
	## Plates of the shape a shell has taken, Vector3i(x, j, z): a later
	## shell does not reach into them.
	var shelled: Dictionary = {}
	## For a shell's own plan, whether a plate of its frame (lane, plates
	## out, row, at its middle) is the shell's own, its plates or the air
	## of its box ([member room]); or free in the model, the shell's or
	## nobody's ([member air]), where a stud may stand.
	var room: Callable = Callable()
	var air: Callable = Callable()

	## A curved side laid on its side, as a set's flank is: where the shape
	## bulges out of a face of its core — an owl's breast, the shoulder of a
	## car, a hull's side — the bulge is not laid in courses that step out
	## a stud at a time, which is the staircase every round body here came
	## out as from the front, but as a shape of its own lying on that face:
	## plates, tiles, curved slopes and corner rounds whose up points out,
	## laid by this same plan turned on its side (lay_shell), so its outside
	## is the parts' smooth faces. It is held by bricks with a stud on one
	## side (87087) in the core's outer wall, every second row of the shell,
	## where the side stud meets the middle of a row (one and three quarter
	## plates up the brick; a row on its side is two and a half plates).
	## A side that does not curve is left to the side panels.
	##
	## Each shell is {facing, along, a0, a1, face, top, rows, held}: the way
	## out and the way along it, the lanes it spans, the plane of the core's
	## face in studs out, the plate its top row starts under, how many rows.
	func shells(kind: String = "straight") -> Array:
		var out: Array = []
		if library == null or not colour_at.is_valid() or library.mesh_for(ANCHOR) == null:
			return out
		if not cubes.is_empty():
			return _cube_shells(kind)
		# Opposite sides together, so a mirrored shape's two flanks are cut
		# by the same corners.
		for facing: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var shell: Dictionary = _shell(facing)
			if not shell.is_empty():
				out.append(shell)
		return out

	## Which way runs along a side facing [param facing], so that along, out
	## and down are a turn of up, along and out: +z along +x, +x along -z.
	static func along_of(facing: Vector2i) -> Vector2i:
		return {Vector2i(0, 1): Vector2i(1, 0), Vector2i(1, 0): Vector2i(0, -1),
			Vector2i(0, -1): Vector2i(-1, 0), Vector2i(-1, 0): Vector2i(0, 1)}[facing]

	## A stud's cell as [lane, out]: how far along [param along] and out along
	## [param facing], each counted so the cell spans [n, n + 1).
	static func _lane(cell: Vector2i, facing: Vector2i, along: Vector2i) -> Vector2i:
		var a: int = cell.x * along.x + cell.y * along.y
		var t: int = cell.x * facing.x + cell.y * facing.y
		return Vector2i(a if along.x + along.y > 0 else a - 1, t if facing.x + facing.y > 0 else t - 1)

	## The world point, in studs, of a lane and out given as numbers.
	static func _point(a: float, t: float, facing: Vector2i, along: Vector2i) -> Vector2:
		var x: float = 0.0
		var z: float = 0.0
		var sa: float = a if along.x + along.y > 0 else -a
		var st: float = t if facing.x + facing.y > 0 else -t
		if along.x != 0:
			x = sa
		else:
			z = sa
		if facing.x != 0:
			x = st
		else:
			z = st
		return Vector2(x, z)

	func _shell(facing: Vector2i) -> Dictionary:
		var along: Vector2i = along_of(facing)
		# How far out the shape reaches in each lane at each plate, and how
		# far in its core starts; nothing over a round run.
		var reach: Dictionary = {}    ## Vector2i(lane, j) -> one past the outermost
		var inmost: Dictionary = {}   ## lane -> the least out of any stud in it
		var occupied: Dictionary = {}    ## Vector3i(lane, out, j) -> true, the shape there
		var most: int = -(1 << 30)
		for key: Variant in columns:
			var cell: Vector2i = key
			var lt: Vector2i = _lane(cell, facing, along)
			for j: int in tall:
				if at(cell, j) < 0:
					continue
				# The shape's, whoever has laid it: a side and its mirror must
				# read their cores alike, and the first side's own side studs
				# stand in the second's core.
				occupied[Vector3i(lt.x, lt.y, j)] = true
				# Glass is never skinned: a cabin's side windows turned out on
				# side studs were red plates over open studs.
				if taken.has(Vector3i(cell.x, j, cell.y)) or shelled.has(Vector3i(cell.x, j, cell.y)) \
						or Shapes.is_glass(library, at(cell, j)):
					continue
				var here := Vector2i(lt.x, j)
				reach[here] = maxi(int(reach.get(here, -(1 << 30))), lt.y + 1)
				inmost[lt.x] = mini(int(inmost.get(lt.x, 1 << 30)), lt.y)
				most = maxi(most, lt.y + 1)
		if reach.is_empty():
			return {}
		var face: int = most - SHELL_DEPTH
		# Whether the core is right behind the face at a lane's plate: a leg or
		# a fin past the face with nothing of the core behind it is not the side
		# curving, and a beast's flank took its legs into itself, held none of
		# them, and stood on nothing.
		var backed := func(at_: Vector2i) -> bool:
			return occupied.has(Vector3i(at_.x, face - 1, at_.y)) \
				and occupied.has(Vector3i(at_.x, face - SHELL_CORE, at_.y))
		var patch: Array[Vector2i] = []
		var low := Vector2i(1 << 30, 1 << 30)
		var high := -low
		var curves: bool = false
		for key: Variant in reach:
			var at_: Vector2i = key
			if int(reach[at_]) <= face or int(inmost[at_.x]) > face - SHELL_CORE \
					or not backed.call(at_):
				continue
			# Steep: out no more than two studs in four plates up or down. A
			# gentler fall is a top, which the slopes lay (a ramp's low end
			# was turned on its side and lost its 18 degree slopes).
			var above: int = int(reach.get(at_ + Vector2i(0, 2), face))
			var below: int = int(reach.get(at_ - Vector2i(0, 2), face))
			if absi(above - below) > 2:
				continue
			patch.append(at_)
			low = Vector2i(mini(low.x, at_.x), mini(low.y, at_.y))
			high = Vector2i(maxi(high.x, at_.x), maxi(high.y, at_.y))
		# Curving up the side, not only round it: a cylinder's side is the
		# round parts', and a flat side the panels'.
		var in_patch: Dictionary = {}
		for at_: Vector2i in patch:
			in_patch[at_] = true
		for at_: Vector2i in patch:
			var up: Vector2i = at_ + Vector2i(0, 1)
			curves = curves or in_patch.has(up) and int(reach[up]) != int(reach[at_])
		# Two rows tall at least: a few plates at the foot of a ramp are its
		# slopes'.
		if patch.size() < 4 or not curves or high.y + 1 - low.y < 5:
			return {}
		# And all of those lanes past the face, up and down: a crown left to
		# the core above the shell stood on the shell's edge, held by nothing.
		# Only where the core is behind them.
		for key: Variant in reach:
			var at_: Vector2i = key
			if at_.x >= low.x and at_.x <= high.x and int(reach[at_]) > face and backed.call(at_):
				low.y = mini(low.y, at_.y)
				high.y = maxi(high.y, at_.y)
		var top: int = high.y + 1
		var rows: int = 2 * ceili((top - low.y) / 5.0)
		var bottom: int = maxi(0, top - roundi(2.5 * rows))
		# Its rows stop above what hangs under the side, a row pair short if
		# they must: whole rows reaching into a leg took the leg's top.
		var hanging: bool = false
		for key: Variant in reach:
			var at_: Vector2i = key
			hanging = hanging or at_.x >= low.x and at_.x <= high.x and at_.y >= bottom \
				and at_.y < low.y and int(reach[at_]) > face and not backed.call(at_)
		while hanging and bottom < low.y and rows > 2:
			rows -= 2
			bottom = maxi(0, top - roundi(2.5 * rows))
		if hanging and bottom < low.y:
			return {}
		# Taken out of the core: every plate of the box, past the face, that
		# no shell before it has.
		# And the box's plates outside the shape too: a wedge's cut side
		# reached into one beside the shell and overlapped it.
		var mine: Dictionary = {}
		var outside: Array[Vector3i] = []
		# Glass in the box stays the core's, and what stands on it in its lane
		# (a cabin's roof over its windows): no part of the shell reaches in.
		# Taken over the glass, a car's roof edge was laid by the shell, held by
		# no side stud, and pruned, and the glass under it stood open.
		var glass: Dictionary = {}
		var glass_from: Dictionary = {}    ## lane -> its lowest plate of glass
		for a: int in range(low.x, high.x + 1):
			for j: int in range(bottom, top):
				for t: int in range(face, most):
					var p: Vector2 = _point(a + 0.5, t + 0.5, facing, along)
					if Shapes.is_glass(library, at(Vector2i(floori(p.x), floori(p.y)), j)):
						glass_from[a] = mini(int(glass_from.get(a, j)), j)
		for a: int in range(low.x, high.x + 1):
			for j: int in range(bottom, top):
				for t: int in range(face, most):
					var p: Vector2 = _point(a + 0.5, t + 0.5, facing, along)
					var key := Vector3i(floori(p.x), j, floori(p.y))
					if glass_from.has(a) and j >= int(glass_from[a]):
						glass[key] = true
						continue
					if shelled.has(key) or taken.has(key):
						continue
					if at(Vector2i(key.x, key.z), j) >= 0:
						mine[key] = true
					else:
						outside.append(key)
		# Not over a side-stud brick another shell laid: its studs stand up
		# out of its top, and a plate on its side over one stands its edge on
		# them. A cat head's front flank stood 4 LDU into the studs of its
		# side flanks' 1 x 4s by the parts' real shapes, which the lattice,
		# taking every stud for one into a socket, could not see. That column
		# is the core's, laid upright on the studs.
		var studs_up: Dictionary = {}    ## Vector2i column -> the plate they stand into
		for one: Dictionary in anchors:
			for cell: Vector2i in one["_cells"]:
				studs_up[cell] = int(one["y"]) + int(one["_h"])
		for key: Variant in mine.keys():
			var column := Vector2i((key as Vector3i).x, (key as Vector3i).z)
			if studs_up.has(column) and int(studs_up[column]) >= bottom \
					and int(studs_up[column]) < top:
				mine.erase(key)
		for key: Variant in mine:
			taken[key] = true
			shelled[key] = true
		for key: Vector3i in outside:
			taken[key] = true
		var shell := {"facing": facing, "along": along, "a0": low.x, "a1": high.x + 1,
			"face": face, "top": top, "rows": rows, "held": {}, "cells": mine,
			"outside": outside, "glass": glass}
		return shell if _anchored(shell) else {}

	## A shell's side studs: every second row, in the core's outer wall behind
	## each lane the shell's first row of plates covers there. Given back, and
	## false, where none holds it.
	func _anchored(shell: Dictionary) -> bool:
		var facing: Vector2i = shell["facing"]
		var along: Vector2i = shell["along"]
		var low := Vector2i(int(shell["a0"]), 0)
		var high := Vector2i(int(shell["a1"]) - 1, 0)
		var face: int = shell["face"]
		var top: int = shell["top"]
		var rows: int = shell["rows"]
		var mine: Dictionary = shell["cells"]
		if _anchor_turn(facing) < 0:
			drop_shell(shell)
			return false
		for w: int in range(0, rows, 2):
			var jb: int = top - roundi(2.5 * w) - 3
			if jb < 0:
				break
			# Each lane the shell's row covers there, with the cell of the
			# core's outer wall behind it: [lane, cell, colour], or [] where
			# none can go.
			var lanes: Array = []
			for a: int in range(low.x, high.x + 1):
				# In every lane, a course of them as studs_out lays one: one
				# lane in two cut the core's outer wall into columns of 1 x 1s
				# between them, tied to nothing, and a bird's breast floated.
				var row_y: float = top - 2.5 * (w + 0.5)
				var p: Vector2 = _point(a + 0.5, face + 0.2, facing, along)
				if int(colour_at.call(p.x, row_y, p.y)) < 0 \
						or not mine.has(Vector3i(floori(p.x), floori(row_y), floori(p.y))):
					lanes.append([])
					continue
				var q: Vector2 = _point(a + 0.5, face - 0.5, facing, along)
				var cell := Vector2i(floori(q.x), floori(q.y))
				var free: bool = true
				for n: int in 3:
					free = free and at(cell, jb + n) >= 0 \
						and not taken.has(Vector3i(cell.x, jb + n, cell.y)) \
						and not Shapes.is_glass(library, at(cell, jb + n))
				# Nor with its own studs up into a shell laid before: the same
				# edge on studs, from under it. A cube's shell reaches into the
				# air of its box too, and a 1 x 4's studs ran into Spot's flank.
				free = free and not shelled.has(Vector3i(cell.x, jb + 3, cell.y)) \
					and not (shell.has("id") and taken.has(Vector3i(cell.x, jb + 3, cell.y))
						and at(cell, jb + 3) < 0)
				lanes.append([a, cell, at(cell, jb + 1)] if free else [])
			# Runs of lanes side by side in one colour, each held by side-stud
			# bricks as long as fit, laid the same from either end so a side
			# that is its own mirror stays one: 84 of an egg's 450 parts were
			# 1 x 1s with a stud on a side.
			var run: Array = []
			for n: int in lanes.size() + 1:
				var lane: Array = lanes[n] if n < lanes.size() else []
				if not lane.is_empty() and (run.is_empty()
						or int((run[-1] as Array)[2]) == int(lane[2])):
					run.append(lane)
					continue
				var at_: int = 0
				for size: int in _split(run.size()):
					var cells: Array[Vector2i] = []
					var holds: Array = []
					for k: int in size:
						var one: Array = run[at_ + k]
						cells.append(one[1])
						holds.append(Vector2i(int(one[0]) - low.x, w))
						for m: int in 3:
							taken[Vector3i((one[1] as Vector2i).x, jb + m, (one[1] as Vector2i).y)] = true
					at_ += size
					var part: String = ANCHOR_RUNS[size]
					var turn: int = _anchor_turn(facing, part)
					if turn < 0:
						continue
					var corner: Vector2i = cells[0]
					for cell: Vector2i in cells:
						corner = Vector2i(mini(corner.x, cell.x), mini(corner.y, cell.y))
					anchors.append({"part": part, "color": int((run[0] as Array)[2]), "x": corner.x,
						"y": jb, "z": corner.y, "rot": turn, "_cells": cells, "_h": 3,
						"_studs": cells, "_base": cells, "_holds": [facing, holds],
						"_of": int(shell.get("id", -1))})
					for held: Vector2i in holds:
						(shell["held"] as Dictionary)[held] = true
				run = [lane] if not lane.is_empty() else []
		# Held by nothing, its plates go back to the core: taken and then
		# left, they were laid by nobody, and a body thinned to a strip.
		if (shell["held"] as Dictionary).is_empty():
			drop_shell(shell)
			return false
		return true

	## Lambrecht's cubes [lambrecht], for a sculpt's grid: the cubes of its
	## surface two studs by five plates by two studs that face out, as
	## Brickify measured them (Vector3i(x / 2, j / 5, z / 2) -> the way out).
	## A side steeper than 60 degrees laid upright is a staircase a stud a
	## step, its studs up, whichever way it turns; turned out, the same side
	## is plates two fifths of a stud thick, slopes and tiles facing it.
	var cubes: Dictionary = {}
	## The cubes cut again a few plates up (Brickify.Grid.cube_phases):
	## [[phase, cubes]], each cube in the patch of the cubes facing its way at
	## its depth in every cut ([method _cube_shells]).
	var cube_phases: Array = []
	## The model's surface a plate at a time in each two-stud column
	## (Brickify.Grid.cube_bins): a patch's row is its own only where the
	## surface in it faces the patch's way, or there is none.
	var cube_bins: Dictionary = {}
	## Each cube's studs and plates, as Brickify's cubes are cut.
	const CUBE_STUDS := 2
	const CUBE_PLATES := 5
	## A cube with fewer of the model's plates than this is its side's flat
	## back, which the core lays as well; and one whose kept parts cover
	## less than [constant CUBE_KEEPS] of its plates goes back to the core.
	const CUBE_LEAST := 4
	const CUBE_KEEPS := 0.6
	## How deep the core behind a cube, not turned itself, has to be, studs.
	## A fox at 48 studs, two studs deep, hung its head on two joints past
	## their load more than upright; three, as many as upright.
	const CUBE_BACK := 3
	## How many cubes deep one shell runs, out from the innermost, where a
	## cube and the one past it at the same height both face out. One deep, a
	## side leaning out down a cube's height left the inner cube upright, the
	## model past it in its lower plates; on Bob and the Stanford bunny at 48
	## studs, nearly every cube refused so.
	const CUBE_DEEP := 2
	## The most parts of a piece of the core a shell cuts off that are taken
	## out before the check (Shapes.lay).
	const CUT_OFF := 16
	## Shells in the order made: a side stud says which it holds.
	var _shells_made: int = 0
	## Why cubes were left upright, by reason, for a probe to say.
	var _why_not: Dictionary = {}
	## And each cube refused, [x / 2, its foot plate, z / 2, why], for the bench.
	var _why_at: Array = []
	## The plates of the core's parts cut off beside a shell (cut_off,
	## caps_apart), each by which, and the shells' plates given back to the
	## core (_give_back): what Shapes.last tells a probe of a turned side.
	var cut_cells: Dictionary = {}
	var given_back: Dictionary = {}
	## The model's side at a point (Brickify.Grid.side): with it, a cube's
	## shell fits its slopes by distance (_fit_near) as a top's are.
	var side_fine: Callable = Callable()

	## The cubes as patches: the cubes of every cut facing one way at one
	## depth are one shell, its outline the rows and lanes of its own frame
	## they cover, laid as a curved side is (lay_shell) and held by side studs
	## in the core's wall behind it; a cube its parts do not cover given back
	## to the core, and the patch laid again without it. Cut by cut, a side
	## was a shell of each cut's cubes, and the band of one to four plates
	## between two cuts' shells was laid upright between them, its side-stud
	## bricks and fitted slopes standing out of the turned plates round them,
	## and every cut's shell its own trial. First-tier connections only: a
	## side stud into a plate's underside, nothing wedged.
	func _cube_shells(kind: String) -> Array:
		var groups: Dictionary = {}    ## Vector4i(way x, way z, depth, 0) -> [[cube, phase]]
		var order: Array = []
		for cut: Array in [[0, cubes]] + cube_phases:
			_group_cut(int(cut[0]), cut[1], groups, order)
		var out: Array = []
		var asked: int = 0
		for key: Variant in order:
			asked += 1
			if asked % 8 == 0 and stop.is_valid() and bool(stop.call()):
				break
			var group: Vector4i = key
			var facing := Vector2i(group.x, group.y)
			var list: Array = groups[key]
			var shell: Dictionary = {}
			for _round: int in 3:
				shell = _cube_shell(facing, list)
				if shell.is_empty():
					break
				lay_shell(shell, kind, true)
				var covered: Dictionary = shell.get("covered_at", {})
				var mine: Dictionary = shell["cells"]
				var kept: Array = []
				for member: Array in shell["cubes"]:
					var n: Vector2i = Vector2i.ZERO
					for p: Vector3i in _cube_plates(member[0], member[1]):
						if mine.has(p):
							n += Vector2i(1, 1 if covered.has(p) else 0)
					if n.x > 0 and float(n.y) >= (0.8 if Shapes.TRY.contains("keeps8") else CUBE_KEEPS) * n.x:
						kept.append(member)
				if kept.size() == (shell["cubes"] as Array).size():
					break
				_why_not["uncovered"] = int(_why_not.get("uncovered", 0)) + (shell["cubes"] as Array).size() \
					- kept.size()
				for member: Array in shell["cubes"]:
					if not kept.has(member):
						_why_at.append(_why_of(member, "uncovered"))
				drop_shell(shell)
				shell = {}
				if kept.is_empty():
					break
				list = kept
			if not shell.is_empty():
				shell["tried"] = true
				_give_back(shell)
				out.append(shell)
			else:
				_why_not["unheld"] = int(_why_not.get("unheld", 0)) + list.size()
				for member: Array in list:
					_why_at.append(_why_of(member, "lost"))
		var kept_cubes: int = 0
		var kept_list: Array = []
		for shell: Dictionary in out:
			kept_cubes += (shell["cubes"] as Array).size()
			for member: Array in shell["cubes"]:
				var c: Vector3i = member[0]
				kept_list.append(Vector3i(c.x, c.y * CUBE_PLATES + int(member[1]), c.z))
		_why_not["kept"] = kept_cubes
		_why_not["asked"] = cubes.size()
		Shapes.last["cubes"] = _why_not
		# Each turned cube by its foot plate, for the bench to say where a side is
		# turned.
		Shapes.last["cubes_kept"] = kept_list
		# And each cube refused, why: "lost" where its group came to no shell,
		# "moved" where the side's outermost cube was tried in its place.
		Shapes.last["cubes_why"] = _why_at
		return out

	## [x / 2, its foot plate, z / 2, why] of a cube [param member] refused.
	static func _why_of(member: Array, why: String) -> Array:
		var c: Vector3i = member[0]
		return [c.x, c.y * CUBE_PLATES + int(member[1]), c.z, why]

	## The cubes of cut [param phase] into [param groups] by the way they face
	## and their depth, each [cube, phase], a group first met added to
	## [param order].
	func _group_cut(phase: int, cut: Dictionary, groups: Dictionary, order: Array) -> void:
		var keys: Array = cut.keys()
		keys.sort()
		var moved: Dictionary = {}
		for key: Variant in keys:
			var c: Vector3i = key
			var facing: Vector2i = cut[key]
			# The side's outermost cube: where the model reaches into the cube
			# past this one, that one faces out instead (its own surface too
			# little or too mixed to say so).
			for _step: int in 2:
				var past := c + Vector3i(facing.x, 0, facing.y)
				if cut.has(past) or moved.has(past) or not _cube_has_model(past, phase):
					break
				c = past
			if c != key:
				_why_at.append(_why_of([key, phase], "moved"))
			if moved.has(c):
				continue
			moved[c] = facing
		for key: Variant in moved:
			var c: Vector3i = key
			var facing: Vector2i = moved[c]
			# A side that leans out down a cube's height is a cube facing out
			# and the one past it at the same height facing out too: one shell,
			# the two deep ([constant CUBE_DEEP]), counted from the innermost.
			var out3 := Vector3i(facing.x, 0, facing.y)
			var root: Vector3i = c
			while moved.get(root - out3, Vector2i.ZERO) == facing:
				root -= out3
			var steps: int = absi((c - root).x + (c - root).z)
			root += out3 * (steps - steps % CUBE_DEEP)
			var group := Vector4i(facing.x, facing.y, root.x if facing.x != 0 else root.z,
				phase if Shapes.TRY.contains("phased") else 0)
			if not groups.has(group):
				groups[group] = []
				order.append(group)
			(groups[group] as Array).append([c, phase])

	## The plates of [param shell]'s cubes in a row of a lane where none of its
	## parts is, given back to the core, which lays them upright: left out, a
	## truck's flat side had holes through to the core a stud in. Only where no
	## part of the shell is in that row and lane at any depth: a plate given
	## back beside one, or over a plate of it whose studs face out, ran into it.
	func _give_back(shell: Dictionary) -> void:
		var sub: Plan = shell.get("_sub")
		if sub == null:
			return
		var used: Dictionary = {}
		for one: Dictionary in sub.made:
			for cell: Vector2i in one.get("_cells", []):
				used[cell] = true
		# And where a side stud is: one left open takes a tile on its face.
		for cell: Variant in shell["held"]:
			used[cell] = true
		var facing: Vector2i = shell["facing"]
		var along: Vector2i = shell["along"]
		var a0: int = shell["a0"]
		var top: int = shell["top"]
		var mine: Dictionary = shell["cells"]
		for plate: Variant in mine.keys():
			var p: Vector3i = plate
			var u: int = _lane(Vector2i(p.x, p.z), facing, along).x - a0
			var free: bool = true
			# Each row of the shell the plate reaches into: two and a half
			# plates a row, from the top down.
			for w: int in range(maxi(0, floori((top - p.y - 1) / Shapes.PLATES_PER_STUD)),
					floori((top - p.y) / Shapes.PLATES_PER_STUD - 0.001) + 1):
				free = free and not used.has(Vector2i(u, w))
			if free:
				mine.erase(plate)
				taken.erase(plate)
				shelled.erase(plate)
				given_back[plate] = true

	## Whether the model's surface in the plates [param low] to [param high] of
	## stud [param cell]'s two-stud column faces [param facing], as a cube's must
	## (Brickify.STEEP, sine 0.6), or there is next to none of it.
	func _row_faces(cell: Vector2i, low: float, high: float, facing: Vector2i) -> bool:
		var sum := Vector3.ZERO
		var bx: int = floori(cell.x / float(CUBE_STUDS))
		var bz: int = floori(cell.y / float(CUBE_STUDS))
		for j: int in range(floori(low), ceili(high)):
			var share: float = 1.0 if j >= low and j + 1 <= high else 0.5
			sum += (cube_bins.get(Vector3i(bx, j, bz), Vector3.ZERO) as Vector3) * share
		if sum.length() < 0.25:
			return true
		var way: Vector3 = sum.normalized()
		return absf(way.y) < 0.6 and way.x * facing.x + way.z * facing.y > 0.5

	## Whether the model has a plate in cube [param c] of cut [param phase].
	func _cube_has_model(c: Vector3i, phase: int) -> bool:
		for p: Vector3i in _cube_plates(c, phase):
			if at(Vector2i(p.x, p.z), p.y) >= 0:
				return true
		return false

	## Every plate of cube [param c] of cut [param phase], Vector3i(x, j, z).
	static func _cube_plates(c: Vector3i, phase: int) -> Array[Vector3i]:
		var out: Array[Vector3i] = []
		var j0: int = c.y * CUBE_PLATES + phase
		for dx: int in CUBE_STUDS:
			for dz: int in CUBE_STUDS:
				for j: int in range(maxi(0, j0), j0 + CUBE_PLATES):
					out.append(Vector3i(c.x * CUBE_STUDS + dx, j, c.z * CUBE_STUDS + dz))
		return out

	## Whether any plate of [param cells] from [param j0] up a cube's height is
	## a shell's, or taken by one.
	func _cube_shelled(cells: Array[Vector2i], j0: int) -> bool:
		for cell: Vector2i in cells:
			for j: int in range(j0, j0 + CUBE_PLATES):
				var key := Vector3i(cell.x, j, cell.y)
				if shelled.has(key) or taken.has(key):
					return true
		return false

	## One shell of the cubes [param list], each [cube, phase], all facing
	## [param facing] at one depth: a patch. Each cube's plates of the model
	## are the patch's where the cube is the side's outermost, the core is
	## behind it, and it has plates enough. The patch is cut on its own frame:
	## rows two and a half plates tall from the top of the cut most of its
	## cubes are in, each row of each stud the patch's where the cubes kept
	## hold its whole plates, so the cubes of two cuts lie in it as one side.
	## Held, or {}.
	func _cube_shell(facing: Vector2i, list: Array) -> Dictionary:
		var along: Vector2i = along_of(facing)
		var lanes := Vector2i(1 << 30, -(1 << 30))
		var face: int = 1 << 30
		var kept: Array = []
		# The outermost first, and of cubes as far out the first cut's first.
		var rank := {0: 0}
		for n: int in cube_phases.size():
			rank[int((cube_phases[n] as Array)[0])] = n + 1
		list = list.duplicate()
		list.sort_custom(func(a: Array, b: Array) -> bool:
			var ca: Vector3i = a[0]
			var cb: Vector3i = b[0]
			var da: int = ca.x * facing.x + ca.z * facing.y
			var db: int = cb.x * facing.x + cb.z * facing.y
			if da != db:
				return da > db
			if int(rank[a[1]]) != int(rank[b[1]]):
				return int(rank[a[1]]) < int(rank[b[1]])
			if ca.y != cb.y:
				return ca.y < cb.y
			return ca.x < cb.x if ca.x != cb.x else ca.z < cb.z)
		# Every plate in a cube of the patch, kept or not yet tried: a cube
		# with another of the patch over or under it has no cap there.
		var boxes: Dictionary = {}
		for member: Array in list:
			for p: Vector3i in _cube_plates(member[0], member[1]):
				boxes[p] = true
		var kept_boxes: Dictionary = {}    ## Vector3i plate -> the cut it was kept in
		var columns_in: Dictionary = {}    ## Vector2i -> true, the studs of the cubes kept
		for member: Array in list:
			var c: Vector3i = member[0]
			var phase: int = member[1]
			var cells: Array[Vector2i] = []
			for dx: int in CUBE_STUDS:
				for dz: int in CUBE_STUDS:
					cells.append(Vector2i(c.x * CUBE_STUDS + dx, c.z * CUBE_STUDS + dz))
			var j0: int = c.y * CUBE_PLATES + phase
			# Cut again a few plates up, only where no shell before has any of
			# it: half a cube on a shell's edge would be a cap of its own.
			if phase != 0 and _cube_shelled(cells, j0):
				_why_not["shelled"] = int(_why_not.get("shelled", 0)) + 1
				_why_at.append([c.x, j0, c.z, "shelled"])
				continue
			var plates: int = 0
			var beyond: int = 0
			var backed: int = 0
			var inmost: int = 1 << 30
			for cell: Vector2i in cells:
				inmost = mini(inmost, _lane(cell, facing, along).y)
			# Nor under a cap of the core a plate or two thick, which would
			# stand on the shell's edge and be held by nothing: a single tile
			# over a bunny's flank came away on its own. Above a cube of the
			# same patch, a brick or more of the core, or a cap that runs on
			# back over the core behind the cube, on the core there, it is held:
			# the core's plates bridge from one to the other. The same under it:
			# a ledge a plate or two thick hung from it, unless it runs on back
			# under the core.
			var capped: bool = false
			for cell: Vector2i in cells:
				if boxes.has(Vector3i(cell.x, j0 + CUBE_PLATES, cell.y)):
					continue
				var over: int = 0
				while over < 3 and at(cell, j0 + CUBE_PLATES + over) >= 0:
					over += 1
				if over == 1 or over == 2:
					var behind: Vector2i = cell - facing * (1 + _lane(cell, facing, along).y - inmost)
					capped = capped or at(behind, j0 + CUBE_PLATES) < 0 \
						or at(behind, j0 + CUBE_PLATES - 1) < 0
			for cell: Vector2i in cells:
				if boxes.has(Vector3i(cell.x, j0 - 1, cell.y)):
					continue
				var under: int = 0
				while under < 3 and j0 - 1 - under >= 0 and at(cell, j0 - 1 - under) >= 0:
					under += 1
				if (under == 1 or under == 2) and j0 - 1 - under >= 0:
					var behind: Vector2i = cell - facing * (1 + _lane(cell, facing, along).y - inmost)
					capped = capped or at(behind, j0 - 1) < 0 or at(behind, j0) < 0
			if capped:
				_why_not["capped"] = int(_why_not.get("capped", 0)) + 1
				_why_at.append([c.x, j0, c.z, "capped"])
				continue
			for cell: Vector2i in cells:
				var past: Vector2i = cell + facing * CUBE_STUDS
				var inner: bool = _lane(cell, facing, along).y == inmost
				for j: int in range(maxi(0, j0), j0 + CUBE_PLATES):
					var key := Vector3i(cell.x, j, cell.y)
					if at(past, j) >= 0 and not kept_boxes.has(Vector3i(past.x, j, past.y)):
						beyond += 1
					if inner:
						var deep_enough: bool = true
						for k: int in range(1, CUBE_BACK + 1):
							var back: Vector2i = cell - facing * k
							deep_enough = deep_enough and at(back, j) >= 0 \
								and not shelled.has(Vector3i(back.x, j, back.y))
						if deep_enough:
							backed += 1
					if at(cell, j) >= 0 and not taken.has(key) and not shelled.has(key) \
							and not Shapes.is_glass(library, at(cell, j)):
						plates += 1
			# The side's outermost, the core behind it, plates enough.
			# Anything of the model further out is cut off by the shell: a sliver
			# a stud thick past a bunny's flank stood apart.
			if beyond > 0 or backed < CUBE_STUDS * CUBE_PLATES * 6 / 10 or plates < CUBE_LEAST:
				var why: String = "beyond" if beyond > 0 else ("backed" if plates >= CUBE_LEAST else "few")
				_why_not[why] = int(_why_not.get(why, 0)) + 1
				_why_at.append([c.x, j0, c.z, why])
				continue
			kept.append(member)
			for p: Vector3i in _cube_plates(c, phase):
				kept_boxes[p] = phase
			for cell: Vector2i in cells:
				columns_in[cell] = true
				var lt: Vector2i = _lane(cell, facing, along)
				lanes = Vector2i(mini(lanes.x, lt.x), maxi(lanes.y, lt.x))
				face = mini(face, lt.y)
		if kept.is_empty():
			return {}
		# Its rows from the top of the cut most of its cubes are in, raised by
		# whole cubes over any cube of another cut that stands higher.
		var count: Dictionary = {}
		for member: Array in kept:
			count[member[1]] = int(count.get(member[1], 0)) + 1
		var grid_phase: int = kept[0][1]
		for phase: Variant in count:
			if int(count[phase]) > int(count[grid_phase]):
				grid_phase = phase
		var top: int = -(1 << 30)
		var highest: int = -(1 << 30)
		var bottom: int = 1 << 30
		for member: Array in kept:
			var j0: int = (member[0] as Vector3i).y * CUBE_PLATES + int(member[1])
			if int(member[1]) == grid_phase:
				top = maxi(top, j0 + CUBE_PLATES)
			highest = maxi(highest, j0 + CUBE_PLATES)
			bottom = mini(bottom, maxi(0, j0))
		top += CUBE_PLATES * ceili(float(highest - top) / CUBE_PLATES)
		var rows: int = ceili((top - bottom) / Shapes.PLATES_PER_STUD)
		# Each row of each stud the patch's where the cubes kept hold its whole
		# plates; the half plate it shares with the row beside it is its too.
		# A row reaching a plate another shell has, or glass, is the core's.
		var mine: Dictionary = {}
		var empty: Dictionary = {}
		var row_free := func(cell: Vector2i, low: float, high: float) -> bool:
			for j: int in range(floori(low), ceili(high)):
				var p := Vector3i(cell.x, j, cell.y)
				if j < 0 or taken.has(p) or shelled.has(p) or Shapes.is_glass(library, at(cell, j)):
					return false
			return true
		var take_row := func(cell: Vector2i, low: float, high: float) -> void:
			for j: int in range(floori(low), ceili(high)):
				var p := Vector3i(cell.x, j, cell.y)
				if at(cell, j) >= 0:
					mine[p] = true
				else:
					empty[p] = true
		var reach: Dictionary = {}    ## Vector2i(lane, row) -> the outermost stud out with the row whole
		for key: Variant in columns_in:
			var cell: Vector2i = key
			var lt: Vector2i = _lane(cell, facing, along)
			for w: int in rows:
				var high: float = top - Shapes.PLATES_PER_STUD * w
				var low: float = high - Shapes.PLATES_PER_STUD
				var whole: bool = true
				for j: int in range(floori(low), ceili(high)):
					if j >= low and j + 1 <= high:
						whole = whole and kept_boxes.has(Vector3i(cell.x, j, cell.y))
				if not whole or not bool(row_free.call(cell, low, high)):
					continue
				if Shapes.TRY.contains("rowface") and not _row_faces(cell, low, high, facing):
					continue
				var at_ := Vector2i(lt.x, w)
				reach[at_] = maxi(int(reach.get(at_, lt.y)), lt.y)
				take_row.call(cell, low, high)
		# Solid from the face out: a row of a lane whose cubes stand further out
		# than the face takes the model between them and the face too, so it
		# stands on the face, where the side studs hold it, and not on nothing.
		if Shapes.TRY.contains("solid"):
			for key: Variant in reach:
				var at_: Vector2i = key
				var high: float = top - Shapes.PLATES_PER_STUD * at_.y
				var low: float = high - Shapes.PLATES_PER_STUD
				var cells_in: Array[Vector2i] = []
				var all_free: bool = true
				for t: int in range(face, int(reach[at_])):
					var q: Vector2 = _point(at_.x + 0.5, t + 0.5, facing, along)
					var cell := Vector2i(floori(q.x), floori(q.y))
					if columns_in.has(cell) and mine.has(Vector3i(cell.x, floori(low) + 1, cell.y)):
						continue
					all_free = all_free and bool(row_free.call(cell, low, high))
					cells_in.append(cell)
				if all_free:
					for cell: Vector2i in cells_in:
						take_row.call(cell, low, high)
		var outside: Array[Vector3i] = []
		for p: Vector3i in empty:
			if not mine.has(p):
				outside.append(p)
		if mine.is_empty():
			return {}
		# Not over a side-stud brick another shell laid, its studs up into
		# this one's plates (as _shell keeps clear).
		var studs_up: Dictionary = {}
		for one: Dictionary in anchors:
			for cell: Vector2i in one["_cells"]:
				studs_up[cell] = int(one["y"]) + int(one["_h"])
		for key: Variant in mine.keys():
			var p: Vector3i = key
			var column := Vector2i(p.x, p.z)
			if studs_up.has(column) and int(studs_up[column]) == p.y:
				mine.erase(key)
		# Nor the air over one, which the shell may otherwise reach into.
		var clear: Array[Vector3i] = []
		for key: Vector3i in outside:
			var column := Vector2i(key.x, key.z)
			if studs_up.has(column) and int(studs_up[column]) == key.y:
				taken[key] = true
			else:
				clear.append(key)
		outside = clear
		for key: Variant in mine:
			taken[key] = true
			shelled[key] = true
		for key: Vector3i in outside:
			taken[key] = true
		_shells_made += 1
		var outmost: int = face
		for key: Variant in mine:
			outmost = maxi(outmost, _lane(Vector2i((key as Vector3i).x, (key as Vector3i).z), facing, along).y)
		var shell := {"facing": facing, "along": along, "a0": lanes.x, "a1": lanes.y + 1,
			"face": face, "top": top, "rows": rows, "held": {},
			"cells": mine, "outside": outside, "glass": {}, "id": _shells_made, "cubes": kept,
			"phase": grid_phase, "depth": roundi((outmost - face + 1) * Shapes.PLATES_PER_STUD)}
		if _anchored(shell):
			return shell
		_why_not["unanchored"] = int(_why_not.get("unanchored", 0)) + kept.size()
		for member: Array in kept:
			_why_at.append(_why_of(member, "unanchored"))
		return {}

	## The pieces of the core apart from the rest, of [constant CUT_OFF] parts
	## or fewer, that touch a shell (with [param wholly], every part of them
	## does: a sliver beside one, not a leg that meets one at its top):
	## taken out of [member made]. How many parts.
	func cut_off(wholly: bool = false) -> int:
		if cubes.is_empty() or shelled.is_empty():
			return 0
		var gone: Dictionary = {}
		for piece: Array in pieces().slice(1):
			if piece.size() > CUT_OFF:
				continue
			var touches: bool = wholly
			for n: int in piece:
				touches = (touches and beside_shell(made[n])) if wholly \
					else (touches or beside_shell(made[n]))
			if touches:
				for n: int in piece:
					gone[n] = true
		if not gone.is_empty():
			var left: Array = []
			for n: int in made.size():
				if not gone.has(n):
					left.append(made[n])
				else:
					for cell: Vector2i in made[n].get("_cells", []):
						for v: int in int(made[n].get("_h", 1)):
							cut_cells[Vector3i(cell.x, roundi(float(made[n]["y"])) + v, cell.y)] = \
								"wholly" if wholly else "cut"
			made = left
		return gone.size()

	## The pieces of the core a shell cuts off, as [method cut_off] finds
	## them (any part beside a shell), joined to the rest where they meet it: a
	## plate of one and a plate of the rest side by side laid again across
	## (the stitch's first way), and where a brick of the rest stands beside
	## a plate of one, that brick laid again as three plates to be paired the
	## next pass. All at once, a few passes. A turned cube leaves the side's
	## surface past its shell's end, and the plates of its own rows it laid
	## nothing in, beside the core and on nothing: taken out unjoined, a blue
	## bunny at 20 studs lost 2.1% of itself; left to the stitch, which joins
	## one piece a round, a forty-eight-stud Bob took 11.6 s to stitch from
	## 4.5. Joined so only where every part was beside a shell, the bunny at 48
	## studs turned from 65 degrees still stitched 59 of them (12.3 s); any
	## part, 22 (5.8 s). How many were joined.
	func join_cut_off() -> int:
		if cubes.is_empty() or shelled.is_empty():
			return 0
		var joined: int = 0
		for _pass: int in 4:
			var found: Array = pieces()
			var main: Dictionary = {}
			for n: int in (found[0] if not found.is_empty() else []):
				main[n] = true
			var apart: Array = []
			for piece: Array in found.slice(1):
				if piece.size() > CUT_OFF:
					continue
				var touches: bool = false
				for n: int in piece:
					touches = touches or beside_shell(made[n])
				if touches:
					apart.append(piece)
			if apart.is_empty():
				break
			var plain: Dictionary = _plain_cells(main)
			var gone: Dictionary = {}
			var added: Array = []
			var unpaired: Array = []
			for piece: Array in apart:
				var pair: Array = _pair(piece, main, plain)
				if pair.is_empty() or gone.has(pair[0]) or gone.has(pair[1]):
					unpaired.append(piece)
					continue
				var across: Array = _across(made[pair[0]], made[pair[1]])
				if across.is_empty():
					continue
				gone[pair[0]] = true
				gone[pair[1]] = true
				added.append_array(across)
				joined += 1
			# None side by side at one height: the rest's bricks beside a plate
			# of one laid again as three plates each, to be paired next pass.
			if not unpaired.is_empty():
				var bricks: Dictionary = {}    ## Vector3i plate -> a brick of the rest
				for m: Variant in main:
					var two: Dictionary = made[m]
					if _plain(two) and int(two["_h"]) == 3:
						for cell: Vector2i in two["_cells"]:
							for h: int in 3:
								bricks[Vector3i(cell.x, int(round(float(two["y"]))) + h, cell.y)] = m
				var unbricked: Dictionary = {}
				for piece: Array in unpaired:
					for n: int in piece:
						var one: Dictionary = made[n]
						if not _plain(one) or int(one["_h"]) != 1:
							continue
						var y: int = int(round(float(one["y"])))
						for cell: Vector2i in one["_cells"]:
							for step: Vector2i in Shapes.OUT:
								var m: int = int(bricks.get(Vector3i(cell.x + step.x, y, cell.y + step.y), -1))
								if m >= 0 and not gone.has(m) \
										and int((made[m] as Dictionary)["color"]) == int(one["color"]):
									unbricked[m] = true
				for m: Variant in unbricked:
					gone[m] = true
					var brick: Dictionary = made[m]
					var cells: Dictionary = {}
					for cell: Vector2i in brick["_cells"]:
						cells[cell] = true
					for h: int in 3:
						for part: Dictionary in _tile(cells.duplicate(), int(round(float(brick["y"]))) + h,
								int(brick["color"]), Shapes.CORE_PLATES, {}, -1):
							added.append(_annotated(part, Shapes.CORE_PLATES, 1, true))
			if gone.is_empty():
				break
			var kept: Array = []
			for n: int in made.size():
				if not gone.has(n):
					kept.append(made[n])
			made = kept + added
		return joined

	## The pieces of the core apart from the rest of three parts or fewer, each
	## at the core's top (nothing of it, or a shell, over any of its parts), that
	## the stitch could not join: taken out of [member made]. Left to the mend,
	## which took them out too, an avocado's 1 x 1 plates and tile at its top
	## sent it to a second check, a fifth of its time. How many parts.
	func caps_apart() -> int:
		if cubes.is_empty() or shelled.is_empty():
			return 0
		var gone: Dictionary = {}
		for piece: Array in pieces().slice(1):
			if piece.size() > 3:
				continue
			# Capped: nothing over any part of it that its studs could reach,
			# the shape's air, a shell, or a tile's smooth top.
			var capped: bool = true
			for n: int in piece:
				var one: Dictionary = made[n]
				if (one.get("_studs", []) as Array).is_empty():
					continue
				var top: int = roundi(float(one["y"])) + int(one.get("_h", 1))
				for cell: Vector2i in one.get("_cells", []):
					var above: Vector3i = Vector3i(cell.x, top, cell.y)
					capped = capped and (at(cell, top) < 0 or shelled.has(above) or _over_tile(above, piece))
			if capped:
				for n: int in piece:
					gone[n] = true
		if not gone.is_empty():
			var left: Array = []
			for n: int in made.size():
				if not gone.has(n):
					left.append(made[n])
				else:
					for cell: Vector2i in made[n].get("_cells", []):
						for v: int in int(made[n].get("_h", 1)):
							cut_cells[Vector3i(cell.x, roundi(float(made[n]["y"])) + v, cell.y)] = "caps"
			made = left
		return gone.size()

	## Whether plate [param at_] is in a part of [param piece] itself.
	func _over_tile(at_: Vector3i, piece: Array) -> bool:
		for n: int in piece:
			var one: Dictionary = made[n]
			var y: int = roundi(float(one["y"]))
			if at_.y >= y and at_.y < y + int(one.get("_h", 1)) \
					and (one.get("_cells", []) as Array).has(Vector2i(at_.x, at_.z)):
				return true
		return false

	## Whether a part of the core touches a plate a shell has taken, beside,
	## over or under it.
	func beside_shell(one: Dictionary) -> bool:
		var y: int = roundi(float(one["y"]))
		for cell: Vector2i in one.get("_cells", []):
			for v: int in int(one.get("_h", 1)):
				for step: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1),
						Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
					if shelled.has(Vector3i(cell.x, y + v, cell.y) + step):
						return true
		return false

	## Whether side-stud brick [param one] holds [param shell]: a cube's shell
	## by its own number, a design's by the way it faces.
	static func _holds(one: Dictionary, shell: Dictionary) -> bool:
		return one.has("_holds") and (one["_holds"] as Array)[0] == shell["facing"] \
			and int(one.get("_of", -1)) == int(shell.get("id", -1))

	## A shell given back to the core: its plates, the plates beside it it
	## kept clear, and its side studs.
	func drop_shell(shell: Dictionary) -> void:
		for key: Variant in shell["cells"]:
			taken.erase(key)
			shelled.erase(key)
		for key: Vector3i in shell["outside"]:
			taken.erase(key)
		var left: Array = []
		for one: Dictionary in anchors:
			if _holds(one, shell):
				for cell: Vector2i in one["_cells"]:
					for m: int in 3:
						taken.erase(Vector3i(cell.x, int(one["y"]) + m, cell.y))
			else:
				left.append(one)
		anchors = left

	## A run of [param n] lanes as side-stud bricks, longest first and the
	## same from either end: 6 is 2 2 2, 9 is 4 1 4.
	static func _split(n: int) -> Array:
		var ends: Array = []
		var left: int = n
		while not left in [0, 1, 2, 4]:
			var size: int = 4 if left >= 8 else (2 if left >= 4 else 1)
			ends.append(size)
			left -= 2 * size
		var out: Array = ends.duplicate()
		if left > 0:
			out.append(left)
		ends.reverse()
		return out + ends

	## The quarter turn that points [param part]'s side studs [param facing].
	func _anchor_turn(facing: Vector2i, part: String = ANCHOR) -> int:
		var mesh: Lbm.PartMesh = library.mesh_for(part)
		if mesh == null:
			return -1
		var out := Vector3(facing.x, 0, facing.y)
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind != "stud" or connector.gender != "male" \
					or absf(connector.axis.y) > 0.1:
				continue
			for rot: int in 4:
				if (BrickLattice.basis_for("up", rot) * connector.axis).dot(out) > 0.9:
					return rot
		return -1

	## A shell's parts: its own plan, a stud along the side by a plate out
	## by a row down, laid as any shape is, and each part turned so its up
	## points out of the side.
	func lay_shell(shell: Dictionary, kind: String, trial: bool = false) -> Array:
		var facing: Vector2i = shell["facing"]
		var along: Vector2i = shell["along"]
		var a0: int = shell["a0"]
		var face: int = shell["face"]
		var top: int = shell["top"]
		var rows: int = shell["rows"]
		var depth: int = int(shell.get("depth", roundi(SHELL_DEPTH * Shapes.PLATES_PER_STUD)))
		var to_world := func(x: float, j: float, z: float) -> Vector3:
			var p: Vector2 = _point(a0 + x, face + j / Shapes.PLATES_PER_STUD, facing, along)
			return Vector3(p.x, top - Shapes.PLATES_PER_STUD * z, p.y)
		var mine: Dictionary = shell["cells"]
		# The squares a face is laid in, left out of the shell's own plan.
		var masked: Dictionary = {}    ## Vector2i(lane, row) from a0 and top
		# The plates beside the shell it keeps clear, its own to reach into.
		var beside: Dictionary = {}
		for key: Vector3i in shell["outside"]:
			beside[key] = true
		var local_colour := func(x: float, j: float, z: float) -> int:
			if masked.has(Vector2i(floori(x), floori(z))):
				return -1
			var p: Vector3 = to_world.call(x, j, z)
			if not mine.has(Vector3i(floori(p.x), floori(p.y), floori(p.z))):
				return -1
			# A row is two and a half plates: every plate it reaches into
			# is the shell's or nobody's, or a round part's box beside it is
			# overlapped.
			var row: float = p.y + Shapes.PLATES_PER_STUD * (z - floorf(z) - 1.0)
			# And every stud its plate reaches into, out from the face: a plate
			# on its side is two fifths of a stud thick, and one whose middle
			# was the shell's reached into the stud before it, where another
			# side's side-stud brick stood.
			var studs: Dictionary = {}
			for out: float in [floorf(j) + 0.02, floorf(j) + 0.98]:
				var q: Vector3 = to_world.call(x, out, z)
				studs[Vector2i(floori(q.x), floori(q.z))] = true
			for j_: int in range(floori(row + 0.01), ceili(row + Shapes.PLATES_PER_STUD - 0.01)):
				if j_ < 0:
					return -1
				for stud: Variant in studs:
					var key := Vector3i((stud as Vector2i).x, j_, (stud as Vector2i).y)
					if (taken.has(key) or at(stud, j_) >= 0) and not mine.has(key) \
							and not (beside.has(key) and stud != Vector2i(floori(p.x), floori(p.z))):
						return -1
			return int(colour_at.call(p.x, p.y, p.z))
		# Whether a point of the shell's frame is free for a face: every plate
		# its row reaches into the shell's or nobody's, as for its own parts.
		var room := func(x: float, j: float, z: float) -> bool:
			var p: Vector3 = to_world.call(x, j, z)
			var row: float = p.y + Shapes.PLATES_PER_STUD * (z - floorf(z) - 1.0)
			for j_: int in range(floori(row + 0.01), ceili(row + Shapes.PLATES_PER_STUD - 0.01)):
				if j_ < 0:
					return false
				var key := Vector3i(floori(p.x), j_, floori(p.z))
				if (taken.has(key) or at(Vector2i(key.x, key.z), j_) >= 0) and not mine.has(key) \
						and not beside.has(key):
					return false
			return true
		# And whether it is the shell's own: its plates or the air of its box,
		# which it keeps clear. Free air past the box is no one's yet, and the
		# core's surface is laid there after: on Bob a curved 3 x 1 of a shell
		# stood in the air over a stud where the core then laid a cheese slope.
		var own := func(x: float, j: float, z: float) -> bool:
			var p: Vector3 = to_world.call(x, j, z)
			var row: float = p.y + Shapes.PLATES_PER_STUD * (z - floorf(z) - 1.0)
			for j_: int in range(floori(row + 0.01), ceili(row + Shapes.PLATES_PER_STUD - 0.01)):
				var key := Vector3i(floori(p.x), j_, floori(p.z))
				if j_ < 0 or not mine.has(key) and not beside.has(key):
					return false
			return true
		# Held where an anchor the core kept reaches: one in a column the
		# core's own pruning let go holds nothing.
		# Tried before the core is laid, every side stud it was given.
		var held_here: Dictionary = {}
		for one: Dictionary in (anchors if trial else made):
			if _holds(one, shell):
				for held: Vector2i in (one["_holds"] as Array)[1]:
					held_here[held] = true
		# A face asked for on this side: its square is the face's, laid on the
		# side studs behind it, and left out of the shell's own plan.
		var face_parts: Array = []
		for asked: Dictionary in faces:
			if asked["facing"] != facing:
				continue
			var laid_face: Variant = _face_on_shell(shell, asked, held_here, local_colour, room,
				depth)
			if laid_face is String:
				if not trial:
					faces_why[asked["said"]] = laid_face
				continue
			face_parts.append_array((laid_face as Dictionary)["parts"])
			masked.merge((laid_face as Dictionary)["cells"])
			if not trial:
				faces_laid.append(asked["said"])
				kept.append("a face %s: %s" % [asked["said"], (laid_face as Dictionary)["said"]])
		# A cube's shell as it was tried, where the core kept every side stud
		# it was tried on: laid again, it is the same parts (it reads nothing
		# outside its cubes, so nothing the core laid since).
		var sub: Plan = null
		var laid: int = 0
		if not trial and shell.has("id") and shell.get("_sub") is Plan and faces.is_empty() \
				and (shell["_held"] as Dictionary) == held_here:
			sub = shell["_sub"]
			laid = int(shell["_laid"])
		else:
			var local: Dictionary = {}
			for u: int in int(shell["a1"]) - a0:
				for w: int in rows:
					var column := PackedInt32Array()
					column.resize(depth)
					var any: bool = false
					for v: int in depth:
						column[v] = int(local_colour.call(u + 0.5, v + 0.5, w + 0.5))
						any = any or column[v] >= 0
					if any:
						local[Vector2i(u, w)] = column
			# A face may take the whole side: then it is all that is laid there.
			if local.is_empty() and face_parts.is_empty():
				return []
			sub = Plan.new(local, depth, true, library)
			sub.flank = true
			sub.sides_smooth = false
			sub.rounds = false
			sub.wedges = wedges
			sub.colour_at = local_colour
			sub.sample = func(x: float, j: float, z: float) -> bool:
				return int(local_colour.call(x, j, z)) >= 0
			sub.room = own
			sub.air = room
			sub.held = held_here
			# A sculpt's colours and the colours it may lay go with it on its side.
			sub.colour_shown = colour_shown
			sub.sold_in = sold_in
			sub.sold_only = sold_only
			sub.stop = stop
			# And its side's own surface, at thirds of a stud along and down, in
			# plates out from the face: its slopes fitted by distance.
			if side_fine.is_valid() and shell.has("id"):
				var sf: Callable = side_fine
				var sign_: float = 1.0 if facing.x + facing.y > 0 else -1.0
				sub.fine = func(cell: Vector2i, near: float, under: bool) -> PackedFloat32Array:
					var nine := PackedFloat32Array()
					nine.resize(9)
					nine.fill(NAN)
					var t_near: float = face + near / Shapes.PLATES_PER_STUD
					for i: int in 3:
						for k: int in 3:
							var p: Vector2 = _point(a0 + cell.x + (i + 0.5) / 3.0, t_near, facing, along)
							var up: float = top - Shapes.PLATES_PER_STUD * (cell.y + (k + 0.5) / 3.0)
							var hit: float = float(sf.call(facing, p.y if facing.x != 0 else p.x, up,
								p.x if facing.x != 0 else p.y, under))
							if not is_nan(hit):
								nine[i * 3 + k] = (hit * sign_ - face) * Shapes.PLATES_PER_STUD
					return nine
			if sub.held.is_empty():
				shell["covered"] = 0.0
				return []
			if not local.is_empty():
				sub.mirror_of()
				sub.surface(kind)
				sub.lay()
			laid = sub.made.size()
			# None reaching into the glass beside it: an inverted slope hung from
			# a fuselage's flank reached into its canopy's glass bricks.
			var glass: Dictionary = shell.get("glass", {})
			if not glass.is_empty():
				sub.made = sub.made.filter(func(one: Dictionary) -> bool:
					for cell: Vector2i in one.get("_cells", []):
						for v: int in int(one.get("_h", 1)):
							var p: Vector3 = to_world.call(cell.x + 0.5, float(one["y"]) + v + 0.5,
								cell.y + 0.5)
							var row: float = top - Shapes.PLATES_PER_STUD * (cell.y + 1)
							for j_: int in range(floori(row + 0.01), ceili(row + Shapes.PLATES_PER_STUD - 0.01)):
								if glass.has(Vector3i(floori(p.x), j_, floori(p.z))):
									return false
					return true)
			# Pruned to what a side stud holds, and not stitched: a piece of a
			# shell on a stud of its own is held, and a stitch lays parts again
			# that no stud may reach.
			if not local.is_empty():
				sub.prune()
			sub.made.append_array(face_parts)
			# How much of what it took out of the core its kept parts cover.
			var covered: Dictionary = {}
			for one: Dictionary in sub.made:
				for cell: Vector2i in one.get("_cells", []):
					for v: int in int(one.get("_h", 1)):
						var p: Vector3 = to_world.call(cell.x + 0.5, float(one["y"]) + v + 0.5, cell.y + 0.5)
						var row: float = top - Shapes.PLATES_PER_STUD * (cell.y + 1)
						for j_: int in range(floori(row + 0.01), ceili(row + Shapes.PLATES_PER_STUD - 0.01)):
							var key := Vector3i(floori(p.x), j_, floori(p.z))
							if mine.has(key):
								covered[key] = true
			shell["covered"] = float(covered.size()) / float(maxi(1, mine.size()))
			shell["covered_at"] = covered
			if trial:
				# Kept for the lay after the core's, where the same side studs hold it.
				shell["_sub"] = sub
				shell["_held"] = held_here.duplicate()
				shell["_laid"] = laid
				return []
		# Nothing of a cube's shell over the studs of a side-stud brick another
		# shell laid in the core: on Spot at 48 studs a 1 x 4's studs ran into
		# the plate on its side over it.
		if shell.has("id"):
			var stud_tops: Dictionary = {}
			for one: Dictionary in made:
				if one.has("_holds"):
					for cell: Vector2i in one["_cells"]:
						stud_tops[Vector3i(cell.x, int(one["y"]) + int(one["_h"]), cell.y)] = true
			var laid_here: int = sub.made.size()
			sub.made = sub.made.filter(func(one: Dictionary) -> bool:
				for cell: Vector2i in one.get("_cells", []):
					for v: int in int(one.get("_h", 1)):
						var p: Vector3 = to_world.call(cell.x + 0.5, float(one["y"]) + v + 0.5, cell.y + 0.5)
						var row: float = top - Shapes.PLATES_PER_STUD * (cell.y + 1)
						for j_: int in range(floori(row + 0.01), ceili(row + Shapes.PLATES_PER_STUD - 0.01)):
							if stud_tops.has(Vector3i(floori(p.x), j_, floori(p.z))):
								return false
				return true)
			# What a part taken out held goes too: pruned again from the side
			# studs. Left, a cube's four parts on the Stanford bunny's flank
			# rested on its core held by no stud, and the steps put them last.
			if sub.made.size() < laid_here and faces.is_empty():
				var foot: bool = false
				for one: Dictionary in sub.made:
					foot = foot or roundi(float(one["y"])) == 0
				if foot:
					sub.prune()
				else:
					sub.made = []
		_close_side_studs(shell, sub, held_here, masked, local_colour)
		if Shapes.TRY.contains("tally") and shell.has("id"):
			var got: Dictionary = {}
			for one: Dictionary in sub.made:
				for cell: Vector2i in one.get("_cells", []):
					for v: int in int(one.get("_h", 1)):
						var p: Vector3 = to_world.call(cell.x + 0.5, float(one["y"]) + v + 0.5, cell.y + 0.5)
						var row: float = top - Shapes.PLATES_PER_STUD * (cell.y + 1)
						for j_: int in range(floori(row + 0.01), ceili(row + Shapes.PLATES_PER_STUD - 0.01)):
							var key := Vector3i(floori(p.x), j_, floori(p.z))
							if mine.has(key):
								got[key] = true
			var trial_held: int = (shell.get("_held", {}) as Dictionary).size()
			print("TALLY shell %d %s: plates %d, trial covered %d, real covered %d, held %d of %d tried, %s" % [
				int(shell["id"]), str(shell["facing"]), mine.size(),
				(shell.get("covered_at", {}) as Dictionary).size(), got.size(), held_here.size(),
				trial_held, "reused" if is_same(sub, shell.get("_sub")) else "relaid"])
		# How much of each shell its side studs kept, for a probe to say.
		kept.append("%s %d of %d parts on %d side studs, %d%% of its plates" % [str(facing),
			sub.made.size(), laid, sub.held.size(), roundi(100.0 * float(shell["covered"]))])
		# Turned: up to out, x to along, z to down; the frame's foot where
		# the first lane meets the face at the top row.
		var c1 := Vector3(along.x, 0, along.y)
		var c2 := Vector3(facing.x, 0, facing.y)
		var turn := Basis(c1, c2, Vector3(0, -1, 0))
		var start: Vector2 = _point(a0, face, facing, along)
		var foot := Vector3(start.x * 20.0, top * 8.0, start.y * 20.0)
		var out: Array = []
		for one: Dictionary in sub.made:
			var part: String = str(one["part"])
			var cover: AABB = Rounds._cover(library, part)
			var basis: Basis = BrickLattice.basis_for(str(one.get("face", "up")), int(one["rot"]))
			var corner := Vector3(float(one["x"]) * 20.0, float(one["y"]) * 8.0,
				float(one["z"]) * 20.0)
			var origin: Vector3 = corner - Rounds._low(basis, cover)
			var named: Array = Rounds._named(turn * basis)
			if named.is_empty():
				continue
			var placed: Dictionary = Rounds._placed(cover, part, int(one["color"]), str(named[0]),
				int(named[1]), foot + turn * origin)
			placed["_shell"] = true
			out.append(placed)
		return out

	## Plain bricks by length, for a side-stud brick none of whose studs a
	## shell kept anything on.
	const PLAIN_RUNS: Dictionary = {1: "3005", 2: "3004", 3: "3622", 4: "3010"}

	## No side stud left open by a shell [param sub] facing [param facing]: a
	## side-stud brick none of whose studs carries anything of it is a plain
	## brick of its length, the same cover in the core's wall; and a stud of
	## one that holds something elsewhere along it takes a 1 x 1 tile on its
	## face. The shell keeps only what a side stud holds, and the cabins
	## round's first car kept 54% of its plates: the studs it let go of stood
	## open along its cabin, and its session called the body too blocky.
	func _close_side_studs(shell: Dictionary, sub: Plan, held_here: Dictionary,
			masked: Dictionary, local_colour: Callable) -> void:
		var used: Dictionary = {}
		for one: Dictionary in sub.made:
			if roundi(float(one["y"])) != 0:
				continue
			for cell: Vector2i in one.get("_cells", []):
				used[cell] = true
		for cell: Variant in masked:
			used[cell] = true
		for one: Dictionary in made:
			if not _holds(one, shell):
				continue
			var holds: Array = (one["_holds"] as Array)[1]
			var open: Array[Vector2i] = []
			for held: Vector2i in holds:
				if not used.has(held):
					open.append(held)
			if open.is_empty():
				continue
			if open.size() < holds.size():
				for held: Vector2i in open:
					var colour: int = int(local_colour.call(held.x + 0.5, 0.5, held.y + 0.5))
					sub.made.append({"part": "3070b", "color": colour if colour >= 0
						else int(one["color"]), "x": held.x, "y": 0, "z": held.y, "rot": 0,
						"_cells": [held], "_h": 1})
				continue
			var cells: Array = one["_cells"]
			one["part"] = PLAIN_RUNS.get(cells.size(), one["part"])
			one["rot"] = 0 if cells.size() == 1 \
				or (cells[0] as Vector2i).x != (cells[-1] as Vector2i).x else 1
			one.erase("_holds")
			for held: Vector2i in holds:
				held_here.erase(held)

	## A face laid onto a shell the way a set lays one onto a head: the
	## square it sits in is taken out of the shell, a square plate (or two)
	## on the core's side studs behind it brings it out to the curve, a round
	## plate on that is the disc, and on the disc's upper studs two eyes — a
	## 2 x 2 round plate with a centre stud in the iris's colour under a
	## printed eye tile — with a beak on a jumper between them and under, a
	## cheese slope falling down the face. Every part studs out, so the face
	## is features on a disc flush with the curve, not tiles on a panel.
	##
	## In the shell's own frame, as lay_shell lays it: x along the side, y out
	## in plates, z down in rows. {parts, cells, said}, or why not.
	func _face_on_shell(shell: Dictionary, asked: Dictionary, held_cells: Dictionary,
			colour: Callable, room: Callable, depth: int) -> Variant:
		var n: int = asked["across"]
		var along: Vector2i = shell["along"]
		var lanes: int = int(shell["a1"]) - int(shell["a0"])
		var rows: int = shell["rows"]
		var middle: float = float(asked["x"]) * along.x + float(asked["z"]) * along.y
		var u0: int = roundi(middle - n / 2.0) - int(shell["a0"])
		var w0: int = roundi((float(shell["top"]) - float(asked["j"])) / Shapes.PLATES_PER_STUD
			- n / 2.0)
		if n > lanes or n > rows:
			return ("the curved side there is %d studs along and %d rows (a row is a stud) "
				% [lanes, rows] + "from plate %d down, too small for a face %d across"
				% [int(shell["top"]), n])
		# A stud or two off the side is the side's: the middle a design reads
		# off a picture is a guess at where the curve's middle is.
		var u_in: int = clampi(u0, 0, lanes - n)
		var w_in: int = clampi(w0, 0, rows - n)
		if absi(u_in - u0) > 2 or absi(w_in - w0) > 2:
			return ("its %d x %d square is %d studs off the curved side, which is %d studs "
				% [n, n, maxi(absi(u_in - u0), absi(w_in - w0)), lanes]
				+ "along and %d rows (a row is a stud) from plate %d down"
				% [rows, int(shell["top"])])
		# Where it was said, or the nearest place a stud or two away where its
		# square is clear of the core and has side studs behind it.
		var tries: Array = []
		for du: int in range(-2, 3):
			for dw: int in range(-2, 3):
				tries.append(Vector2i(du, dw))
		tries.sort_custom(func(one: Vector2i, other: Vector2i) -> bool:
			return absi(one.x) + absi(one.y) < absi(other.x) + absi(other.y))
		var why: String = ""
		var studs: int = 0
		var backing: int = 0
		var cells: Dictionary = {}
		var square: Array[Vector2i] = []
		var found: bool = false
		for shift: Vector2i in tries:
			var u1: int = u_in + shift.x
			var w1: int = w_in + shift.y
			if u1 < 0 or w1 < 0 or u1 + n > lanes or w1 + n > rows \
					or absi(u1 - u0) > 2 or absi(w1 - w0) > 2:
				continue
			studs = 0
			var height: int = 0
			cells = {}
			square = []
			for u: int in range(u1, u1 + n):
				for w: int in range(w1, w1 + n):
					var cell := Vector2i(u, w)
					cells[cell] = true
					square.append(cell)
					if held_cells.has(cell):
						studs += 1
					for v: int in range(depth - 1, -1, -1):
						if int(colour.call(u + 0.5, v + 0.5, w + 0.5)) >= 0:
							height += v + 1
							break
			if studs < 2:
				why = "the core behind it has %d side stud%s there to hold a disc" % [
					studs, "" if studs == 1 else "s"]
				continue
			# Out to the curve: the disc's face where the shell's surface is
			# on average, the eyes standing a plate or two proud of it.
			backing = clampi(roundi(float(height) / square.size()) - 2, 0, depth - 2)
			var clear: bool = true
			for cell: Vector2i in square:
				for v: int in backing + 1:
					clear = clear and bool(room.call(cell.x + 0.5, v + 0.5, cell.y + 0.5))
			if not clear:
				why = "the core is in the way of its square"
				continue
			u0 = u1
			w0 = w1
			found = true
			break
		if not found:
			return why if not why.is_empty() else "it does not fit the curved side"
		var face_colour: int = int(asked["color"])
		if face_colour < 0:
			face_colour = int(colour.call(u0 + n / 2.0, backing + 0.5, w0 + n / 2.0))
		if face_colour < 0:
			face_colour = int(colour.call(u0 + n / 2.0, 0.5, w0 + n / 2.0))
		var rim: int = int(asked["rim"])
		if rim < 0:
			rim = int(colour.call(u0 + 0.5, 0.5, w0 + 0.5))
		if rim < 0:
			rim = face_colour
		var parts: Array = []
		var discs: Array = Shapes.FACE_DISCS[n]
		for v: int in backing:
			parts.append({"part": discs[1], "color": rim, "x": u0, "y": v, "z": w0, "rot": 0,
				"_cells": square, "_h": 1})
		parts.append({"part": discs[0], "color": face_colour, "x": u0, "y": backing, "z": w0,
			"rot": 0, "_cells": square, "_h": 1})
		var on: int = backing + 1
		# The eyes on the upper studs, touching, in the middle: a stud in from
		# the rim on a 6, two on an 8 (a stud apart, they read as a panda's);
		# the beak under their middle.
		var eye_row: int = 0 if n == 4 else 1
		var eye_at: Array = {4: [0, 2], 6: [1, 3], 8: [2, 4]}[n]
		for at_: int in eye_at:
			parts.append({"part": "18674", "color": int(asked["eyes"]), "x": u0 + at_, "y": on,
				"z": w0 + eye_row, "rot": 0})
			parts.append({"part": "98138p07", "color": 15, "x": u0 + at_ + 0.5, "y": on + 1,
				"z": w0 + eye_row + 0.5, "rot": 0})
		if int(asked["beak"]) >= 0:
			parts.append({"part": "3794b", "color": face_colour, "x": u0 + (n >> 1) - 1, "y": on,
				"z": w0 + eye_row + 2, "rot": 0})
			parts.append({"part": "54200", "color": int(asked["beak"]), "x": u0 + (n >> 1) - 0.5,
				"y": on + 1, "z": w0 + eye_row + 2, "rot": 0})
		# The disc's other studs tiled, so the face is smooth round its
		# features: the held-out owl's disc, studs bare, was judged "a round
		# plate with its studs showing". A 2 x 2 tile where four free studs
		# lie wholly inside the disc, a 1 x 1 where one does, and a round
		# 1 x 1 at the rim, where a square one's corner would stand off it.
		var used: Dictionary = {}
		for at_: int in eye_at:
			for di: int in 2:
				for dk: int in 2:
					used[Vector2i(at_ + di, eye_row + dk)] = true
		if int(asked["beak"]) >= 0:
			used[Vector2i((n >> 1) - 1, eye_row + 2)] = true
			used[Vector2i(n >> 1, eye_row + 2)] = true
		# Its studs as the part has them: the 6 x 6's ring is not every stud
		# whose middle is on the disc, and a tile there held by nothing.
		var read: Array = Patterns._studs_of(library, discs[0])
		var has_stud: Dictionary = read[2] if read.size() == 3 else {}
		var tiles: int = 0
		for k: int in n:
			for i: int in n:
				if used.has(Vector2i(i, k)) or not (has_stud.has(Vector2i(i, k))
						if not has_stud.is_empty() else _disc_stud(i, k, n)):
					continue
				var block: bool = i + 1 < n and k + 1 < n
				for di: int in 2:
					for dk: int in 2:
						block = block and not used.has(Vector2i(i + di, k + dk)) \
							and _disc_inside(i + di, k + dk, n) and (has_stud.is_empty()
								or has_stud.has(Vector2i(i + di, k + dk)))
				var part: String = "98138"
				if block:
					part = "3068b"
					for di: int in 2:
						for dk: int in 2:
							used[Vector2i(i + di, k + dk)] = true
				elif _disc_inside(i, k, n):
					part = "3070b"
				used[Vector2i(i, k)] = true
				parts.append({"part": part, "color": face_colour, "x": u0 + i, "y": on,
					"z": w0 + k, "rot": 0})
				tiles += 1
		return {"parts": parts, "cells": cells, "said": "a %d x %d disc %d plate%s out on %d side studs, %d tiles round its features"
			% [n, n, backing, "" if backing == 1 else "s", studs, tiles]}

	## Whether a round plate [param n] studs across has a stud at (i, k): its
	## middle inside the disc.
	static func _disc_stud(i: int, k: int, n: int) -> bool:
		var r: float = n / 2.0
		return Vector2(i + 0.5 - r, k + 0.5 - r).length() < r

	## Whether the whole of the stud's square (i, k) lies on the disc.
	static func _disc_inside(i: int, k: int, n: int) -> bool:
		var r: float = n / 2.0
		for corner: Vector2 in [Vector2(i, k), Vector2(i + 1, k), Vector2(i, k + 1),
				Vector2(i + 1, k + 1)]:
			if (corner - Vector2(r, r)).length() > r + 0.01:
				return false
		return true

	## Cells whose top plate carries a slope, so is laid with studs, not tiled.
	var studded: Dictionary = {}
	## Columns laid plain, Vector2i -> true: no slope, wedge or top tile, its
	## studs showing (Shapes.lay's "plain_at"). Brickify's parts thinner than a
	## stud: an aircraft's wings, two plates thick, laid in tiles, wedges and
	## slopes, came apart into loose bits, where plain they held.
	var plain_at: Dictionary = {}

	## [method _wedged] but for the columns laid plain, kept out of it and
	## put back.
	func _wedged_off(cells: Dictionary, j: int, height: int = 1) -> Array:
		if plain_at.is_empty():
			return _wedged(cells, j, height)
		var aside: Dictionary = {}
		for key: Variant in cells.keys():
			if plain_at.has(key):
				aside[key] = cells[key]
				cells.erase(key)
		var out: Array = _wedged(cells, j, height)
		cells.merge(aside)
		return out

	## The slopes there are, as [kind, length in studs, height in plates, one
	## wide, two wide, the height of the surface over the middle of each stud
	## of it, from its high end]. Straight ones have a flat stud at the top.
	## Then the surface at each third of a stud along it, the middle of the
	## first stud across, read off its mesh (studs and all), what _fit_near
	## lays against the model's own; and true for a part only it lays: the
	## 65 degree slope and the 1 x 3 x 2 curved top, for a flank falling two
	## bricks a stud. The 75 degree slopes (4460b, and 2449 inverted) were
	## here too: three bricks tall on a stud, nothing beside them bridged to
	## them, and the sphere's seams bridged fell from 53% to 49%.
	const SLOPES: Array = [
		["curved", 4, 3, "61678", "93606", [2.8, 2.2, 1.4, 0.5],
			[2.97, 2.92, 2.87, 2.78, 2.63, 2.47, 2.29, 2.02, 1.76, 1.46, 1.08, 0.69]],
		["curved", 3, 3, "50950", "24309", [2.6, 1.6, 0.6],
			[2.98, 2.93, 2.81, 2.66, 2.43, 2.14, 1.79, 1.35, 0.79]],
		["curved", 2, 2, "11477", "15068", [1.6, 0.6], [1.98, 1.91, 1.76, 1.53, 1.21, 0.76]],
		["straight", 4, 3, "60477", "30363", [3.0, 2.2, 1.4, 0.6],
			[3.0, 3.5, 3.0, 2.86, 2.58, 2.31, 2.03, 1.75, 1.47, 1.19, 0.92, 0.64]],
		["straight", 3, 3, "4286", "3298", [3.0, 1.8, 0.7],
			[3.0, 3.5, 3.0, 2.79, 2.38, 1.96, 1.54, 1.13, 0.71]],
		["straight", 2, 3, "3040b", "3039", [3.0, 1.2], [3.0, 3.5, 3.0, 2.58, 1.75, 0.92]],
		["cheese", 1, 2, "54200", "85984", [1.0], [1.75, 1.25, 0.75]],
		["straight", 2, 6, "60481a", "3678b", [6.0, 3.3], [6.0, 6.5, 6.0, 5.08, 3.25, 1.42], true],
		["curved", 3, 6, "33243", "", [6.0, 5.5, 4.3],
			[6.0, 6.0, 6.0, 5.97, 5.84, 5.54, 5.05, 4.29, 2.99], true],
	]
	## Under an overhang, the same by how high the underside is over the
	## inverted slope's bottom at each stud, from its deep end.
	## Each hung under a 2 x 2 plate in every turn and checked: the 1 x 2
	## (3665) runs into the plate over it, and the curved 2 x 1 and 2 x 2
	## (24201, 32803) are not read as slopes off their meshes, so neither is
	## here. A two-stud run under an overhang takes the 2 x 2 or nothing.
	## Each read off its mesh as SLOPES are, its deep end's hollow under it
	## taken as its foot. Each in the mould the LEGO Group sells now: the
	## older 4287a is sold in 7 of Brickify's colours and 3660a in none, so
	## 259 places under Bob's yellow overhangs fitted one and got nothing.
	## 4287c's underside is 3747b's, a little higher than 4287a's.
	const INVERTED: Array = [
		["under", 4, 3, "13547", "", [0.3, 1.0, 1.8, 2.6],
			[0.0, 0.0, 0.0, 0.02, 0.1, 0.2, 0.34, 0.56, 0.86, 1.21, 1.65, 2.21]],
		["under", 3, 3, "4287c", "3747b", [0.0, 1.2, 2.3],
			[0.0, 0.0, 0.0, 0.22, 0.66, 1.09, 1.53, 1.97, 2.41]],
		["under", 2, 3, "", "3660b", [0.0, 1.8], [0.0, 0.0, 0.0, 0.42, 1.25, 2.08]],
	]

	## The studs a windscreen stands over: no slope is fitted to them.
	var screened: Dictionary = {}
	## Why each screen laid none, in a line; how many it laid, and where.
	var screens_said: Array = []
	var screens_laid: int = 0
	var screens_where: Array = []

	## The windscreens still among [member made].
	func screens_kept() -> int:
		var n: int = 0
		for one: Dictionary in made:
			n += 1 if bool(one.get("_screen", false)) else 0
		return n

	## A windscreen where [param spec] (Shapes._screens_asked, with "origin"
	## and "y0") says the glass is: of the screens that fit across the solid's
	## middle, the one whose rake is nearest the solid's own, its top row
	## where the roof is, standing on the plates at its foot. Its plates are
	## taken out of the shape and kept from everything else; the plates its
	## tubes grip keep their studs, a plate or two laid under them where the
	## shape is lower; and over its top row the roof is two plates, a plate on
	## its top studs and a tile, so the roof holds by them, as a set's does.
	func screen(spec: Dictionary) -> void:
		var along_x: bool = str(spec["along"]) == "x"
		var unit := Vector2i(1, 0) if along_x else Vector2i(0, 1)
		var origin: Vector3 = spec.get("origin", Vector3.ZERO)
		var y0: int = int(spec.get("y0", 0))
		var cell_at := func(a: int, u: int) -> Vector2i:
			return Vector2i(a, u) if along_x else Vector2i(u, a)
		# Its middle across: the mirror's, when the shape is its own mirror
		# across the rake.
		var centre: float = float(spec["centre"])
		if axis == ("z" if along_x else "x"):
			centre = (sum + 1) / 2.0
		var mids: Array[int] = []
		if absf(centre - roundf(centre)) < 0.01:
			mids.append(roundi(centre) - 1)
			mids.append(roundi(centre))
		else:
			mids.append(floori(centre))
		# The roof is read across the solid's whole width, its highest stud at
		# each step along: read off the middle two, a seat cut there for the
		# driver lowered the roof to the cut's floor, and the windscreen stood
		# on it, four plates up, leaning forward.
		var across: Array[int] = mids.duplicate()
		var span: Vector2 = spec.get("span", Vector2.ZERO)
		for u: int in range(floori(span.x + 0.01), ceili(span.y - 0.01)):
			if not across.has(u):
				across.append(u)
		var heights: Dictionary = tops()
		# And off the solid as it was said, before any cut: a seat cut through
		# the roof leaves the windscreen standing where the roof was said.
		var roof_of: Callable = spec.get("roof_of", Callable())
		var top_of := func(cell: Vector2i) -> int:
			var here: int = int(heights.get(cell, -1))
			return maxi(here, int(roof_of.call(cell))) if roof_of.is_valid() else here
		var top_at := func(a: int) -> int:
			var best: int = -1
			for u: int in across:
				best = maxi(best, int(top_of.call(cell_at.call(a, u))))
			return best
		var a0: int = floori(float(spec["from"]) + 0.01)
		var a1: int = ceili(float(spec["to"]) - 0.01)
		var name_of := func(a: float) -> String:
			return Shapes._num(a + (origin.x if along_x else origin.z))
		var where: String = "%s %s-%s" % [spec["along"], name_of.call(a0), name_of.call(a1)]
		var first: int = top_at.call(a0)
		var last: int = top_at.call(a1 - 1)
		if a1 - a0 < 2 or first < 0 or last < 0 or first == last:
			screens_said.append(("The screen at %s is laid as the shape: its top does not "
				% where) + "rise or fall there. Say the stretch where the front climbs to the "
				+ "roof, two studs or more along it.")
			return
		# Its foot towards the lower end, its top row towards the roof.
		var fall: int = -1 if last > first else 1
		var facing: Vector2i = unit * fall
		var roof_top: int = -1
		for a: int in range(a0 - 1, a1 + 1):
			roof_top = maxi(roof_top, top_at.call(a))
		var best: Dictionary = {}
		var off_centre: bool = false
		for raw: Variant in spec["parts"]:
			var s: Dictionary = Shapes.screen_part(library, str(raw))
			if s.is_empty():
				continue
			var w: int = int(s["w"])
			var d: int = int(s["d"])
			var h: int = int(s["h"])
			var start: int = roundi(centre - w / 2.0)
			if axis == ("z" if along_x else "x"):
				# Centred on the mirror, or the shape is lopsided: a screen an even
				# number of studs across on a body an odd number across is neither.
				if posmod(sum + 1 - w, 2) != 0:
					off_centre = true
					continue
				start = (sum + 1 - w) / 2
			for a_hi: int in range(a0 - 1, a1 + 1):
				var a_lo: int = a_hi + fall * (d - 1)
				if mini(a_hi, a_lo) < a0 - 1 or maxi(a_hi, a_lo) > a1:
					continue
				var t: int = top_at.call(a_hi)
				var base: int = t - 2 - h
				var low_top: int = top_at.call(a_lo)
				if t < 0 or low_top < 0 or base < 1:
					continue
				# Every stud of its top row is the shape's, and every stud it
				# grips stands within two plates under its foot.
				var fits: bool = true
				for u: int in range(start, start + w):
					fits = fits and heights.has(cell_at.call(a_hi, u))
				for g: Vector2i in s["grips"]:
					var under: Vector2i = cell_at.call(a_hi + fall * g.y, start + g.x)
					var top: int = int(heights.get(under, -1))
					fits = fits and top >= 1 and base - top <= 2
				if not fits:
					continue
				# The roof's width over its top row, studs within three plates of
				# its top either side of the middle.
				var wide: int = 0
				for u: int in range(start - 2, start + w + 2):
					wide += 1 if int(top_of.call(cell_at.call(a_hi, u))) >= t - 3 else 0
				# Nearest the solid's own rake, the roof's full height, as wide as
				# the roof: a four-wide screen in a six-wide cabin stands between
				# pillars, a six-wide one is the cabin's whole front.
				var score: float = absf(float(low_top) - (base + float(h) / d)) \
					+ 3.0 * (roof_top - t) + 0.75 * absi(wide - w)
				if best.is_empty() or score < float(best["score"]) - 0.01 \
						or (absf(score - float(best["score"])) <= 0.01 and w > int(best["w"])):
					best = {"s": s, "w": w, "d": d, "h": h, "start": start, "a_hi": a_hi,
						"base": base, "t": t, "score": score}
		if best.is_empty() and off_centre:
			screens_said.append(("No windscreen is laid at the screen at %s: the shape is an " % where)
				+ "odd number of studs across, and a windscreen is four or six, so it cannot "
				+ "stand on its middle. Say the body an even number of studs across, its "
				+ "middle on a line between studs (a centre of 4, not 3.5).")
			return
		if best.is_empty():
			screens_said.append(("No windscreen fits the screen at %s: it rises %d plates " % [
				where, absi(last - first)]) + "there, and a windscreen (92583, 4176, 3823 or "
				+ "57783) stands 4 or 6 plates tall over 2 or 3 studs, four or six studs across, "
				+ "with the roof two plates over its top. Let the front rise 6 to 8 plates over "
				+ "2 or 3 studs to the roof, four or six studs wide at the roof.")
			return
		var s: Dictionary = best["s"]
		var id: String = str(s["id"])
		var w: int = best["w"]
		var d: int = best["d"]
		var h: int = best["h"]
		var start: int = best["start"]
		var a_hi: int = best["a_hi"]
		var base: int = best["base"]
		var glass: int = int(spec.get("colour", -1))
		var info: PartLibrary.PartInfo = library.parts.get(id)
		var colours: Array = ([glass] if glass >= 0 else []) + Shapes.GLASS
		for one: Variant in colours:
			glass = int(one)
			if info == null or not info.never_made_in(glass):
				break
		# The roof's colour, from the top of the shape over the screen's top row:
		# the middle's, or where the roof is across it.
		var roof: int = -1
		for u: int in across:
			if roof < 0:
				roof = at(cell_at.call(a_hi, u), int(best["t"]) - 1)
		var cells: Array[Vector2i] = []
		for b: int in d:
			for i: int in w:
				var cell: Vector2i = cell_at.call(a_hi + fall * b, start + i)
				cells.append(cell)
				var column := PackedInt32Array()
				if columns.has(cell):
					column = columns[cell]
				else:
					column.resize(tall)
					column.fill(-1)
				for j: int in range(base, tall):
					if b == 0 and j >= base + h and j < base + h + 2:
						if column[j] < 0:
							column[j] = roof
					elif b > 0 or j < base + h + 2:
						column[j] = -1
				columns[cell] = column
				screened[cell] = true
				for j: int in range(base, base + h):
					taken[Vector3i(cell.x, j, cell.y)] = true
		var grips: Array[Vector2i] = []
		for g: Vector2i in s["grips"]:
			var cell: Vector2i = cell_at.call(a_hi + fall * g.y, start + g.x)
			grips.append(cell)
			var column: PackedInt32Array = columns[cell]
			var top: int = -1
			for j: int in range(base - 1, -1, -1):
				if column[j] >= 0:
					top = j + 1
					break
			if top > 0 and base - top <= 2:
				for j: int in range(top, base):
					column[j] = column[top - 1]
			columns[cell] = column
			studded[cell] = true
		var studs: Array[Vector2i] = []
		for t: Vector2i in s["tops"]:
			studs.append(cell_at.call(a_hi + fall * t.y, start + t.x))
		var low := Vector2i(1 << 30, 1 << 30)
		for one: Vector2i in cells:
			low = Vector2i(mini(low.x, one.x), mini(low.y, one.y))
		var rot: int = posmod(Shapes.OUT.find(facing) + int(s["turn"]), 4)
		var foot_at: int = a_hi + fall * (d - 1)
		var glazed: Vector2i = Vector2i.ZERO
		if bool(spec.get("glaze", false)):
			glazed = _glaze(across, cell_at, a_hi, fall, base, h, w, glass,
				spec.get("own", Callable()))
		# Said only if it is still there once the shape is joined and pruned
		# (Shapes.lay): a windscreen said and not laid is worse than none said.
		var laid: String = (("The screen at %s is a windscreen, %s (%s), %d studs across, "
			% [where, id, info.name if info != null else id, w])
			+ "its foot at %s %s standing on the plates at y=%s, leaning back %d plates over "
			% [spec["along"], name_of.call(foot_at), Shapes._num(base + y0 + origin.y), h]
			+ "%d studs to its top row at %s %s, the roof on its top studs two plates over it."
			% [d, spec["along"], name_of.call(a_hi)])
		if glazed.x > 0:
			laid += (" Behind it the cabin is glazed in the same glass, %d studs along under "
				% glazed.x) + ("the roof and %d plates up from its foot, as a set's side " % glazed.y) \
				+ "windows are; cut a seat into it for a driver and the glass stays its walls."
		made.append({"part": id, "color": glass, "x": low.x, "y": base, "z": low.y,
			"rot": rot, "_cells": cells, "_h": h, "_studs": studs, "_base": grips,
			"_screen": true, "_said": laid, "_where": where})
		screens_laid += 1
		screens_where.append(where)

	## The cabin behind a windscreen glazed, as a set glazes one: from the
	## screen's foot up to the roof, a step at a time back from its top row
	## for as long as two plates of roof are over the glass, and no further
	## back than the screen is wide ([param most] studs), every plate
	## there of the cabin's own solid (where no other solid is: the body it
	## stands on keeps its colour) laid in the screen's glass. Where the roof
	## falls behind, the glass falls with it, three plates under it, a fastback's
	## quarter window. Speed Champions' 76897 glazes its cabin so, a 2 x 6
	## block of trans-black bricks under the roof behind a 92583.
	##
	## Why. Both cars of the cabins round laid their windscreen and judged
	## the rest of the cabin, solid red, "too blocky" — "a tall, square-sided
	## block", said the judge — and built the car again by hand; a fire truck
	## called its cab "a solid lump". [studs along, plates up], or ZERO.
	func _glaze(across_: Array[int], cell_at: Callable, a_hi: int, fall: int, base: int,
			h: int, most: int, glass: int, own: Callable) -> Vector2i:
		var heights: Dictionary = tops()
		var along: int = 0
		var up: int = 0
		var a: int = a_hi - fall
		while along < most:
			var here: int = 0
			for u: int in across_:
				var cell: Vector2i = cell_at.call(a, u)
				if not columns.has(cell) or screened.has(cell) or not heights.has(cell):
					continue
				var column: PackedInt32Array = columns[cell]
				# Under the roof two plates of it, a plate and its tile; where the
				# roof falls, three, the height of the curved slope laid there.
				var top: int = int(heights[cell])
				var high: int = mini(base + h, top - (2 if top >= base + h + 2 else 3))
				var count: int = 0
				for j: int in range(base, high):
					if column[j] < 0 or taken.has(Vector3i(cell.x, j, cell.y)):
						continue
					if own.is_valid() and not bool(own.call(cell.x + 0.5, j + 0.5, cell.y + 0.5)):
						continue
					column[j] = glass
					count += 1
				# Two plates at least, or it is a sliver of glass in a slope: the
				# column is a copy, and left as it was.
				if count < 2:
					continue
				columns[cell] = column
				up = maxi(up, count)
				here += 1
			if here == 0:
				break
			along += 1
			a -= fall
		return Vector2i(along, up)

	## Surface parts wherever the top falls away from one stud to the next,
	## and wherever the foot rises: for each run of studs going down, the
	## slope whose own fall is the nearest to the shape's, standing on the
	## lowest of them with its high end flush with the stud above, and the
	## plates it stands in taken out of the shape for it.
	##
	## A first version sloped only where whole courses stepped in, and a
	## car's cabin and bonnet stayed stairs of plates; a second only where a
	## run of studs was flat, and a smooth body, which falls a plate or so
	## every stud, got cheese slopes and nothing else.
	func surface(kind: String) -> void:
		var picks: Array = []
		if fine.is_valid():
			_fit_near(picks, false)
			_fit_near(picks, true)
		else:
			_fit(picks, kind, false)
			_fit(picks, kind, true)
		# A pick and its mirror together or neither: laid one at a time, a car's
		# inverted slope went in on one side and its mirror found its place
		# taken, and the check called the car lopsided.
		for group: Array in _symmetric(picks):
			var ready: Array = []
			var whole: bool = true
			for pick: Dictionary in group:
				var parts: Array = _ready(pick)
				if parts.is_empty():
					whole = false
				ready.append_array(parts)
			if not whole:
				continue
			var claimed: Dictionary = {}
			for one: Dictionary in ready:
				if not _fits(one, claimed):
					whole = false
			if not whole:
				continue
			for one: Dictionary in ready:
				_carve(one)
				_place(one)

	## The part a pick is laid as, or "".
	func _part_id(pick: Dictionary) -> String:
		var wide: int = int(pick.get("wide", 1))
		for entry: Array in (INVERTED if bool(pick["under"]) else SLOPES):
			if entry[0] == pick["kind"] and int(entry[1]) == int(pick["length"]) \
					and int(entry[2]) == int(pick["tall"]):
				var id: String = str(entry[2 + wide])
				if id.is_empty() or not _sold(id):
					return ""
				# Fitted by distance, only in a colour it is sold in: two of the one
				# wide where the two wide is not.
				if (fine.is_valid() or sold_only) and pick.has("colour") and not _made(id, int(pick["colour"])):
					return ""
				var shape: Dictionary = Shapes.part(library, id, bool(pick["under"]))
				if shape.is_empty() or int(shape["w"]) != wide \
						or int(shape["d"]) != int(pick["length"]):
					return ""
				return id
		return ""

	## A pick as it can be laid: itself, or a pair the two-wide part of
	## which is not here as two of the one-wide, or nothing.
	func _ready(pick: Dictionary) -> Array:
		if not _part_id(pick).is_empty():
			return [pick]
		if int(pick.get("wide", 1)) != 2:
			return []
		var facing: Vector2i = pick["facing"]
		var perp := Vector2i(absi(facing.y), absi(facing.x))
		var out: Array = []
		for a: int in 2:
			var one: Dictionary = pick.duplicate()
			one.erase("wide")
			one["cell"] = (pick["cell"] as Vector2i) + perp * a
			if not _part_id(one).is_empty():
				out.append(one)
		return out

	## Nothing already laid in the plates a pick would stand in, nor claimed
	## by another of its group ([param claimed], which this adds to).
	func _fits(pick: Dictionary, claimed: Dictionary = {}) -> bool:
		var facing: Vector2i = pick["facing"]
		var perp := Vector2i(absi(facing.y), absi(facing.x))
		for a: int in int(pick.get("wide", 1)):
			for b: int in int(pick["length"]):
				var cell: Vector2i = (pick["cell"] as Vector2i) + perp * a + facing * b
				if plain_at.has(cell):
					return false
				for n: int in int(pick["tall"]):
					var key := Vector3i(cell.x, int(pick["y"]) + n, cell.y)
					if taken.has(key) or claimed.has(key):
						return false
					claimed[key] = true
		return true

	## The runs going down from a higher stud, and the slope that fits each.
	func _fit(picks: Array, kind: String, under: bool) -> void:
		var height: Dictionary = feet() if under else tops()
		# Not on a windscreen's studs: its glass is the surface there.
		var used: Dictionary = screened.duplicate()
		# From the top of every fall down (from the foot up, under it), each
		# slope's own surface then the height of the studs it covers, so the
		# next one down carries on from it. Taken in order along x, a ramp
		# started every slope at its lowest stud and got a cheese slope a stud.
		var cells: Array = height.keys()
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var ha: int = height[a]
			var hb: int = height[b]
			if ha != hb:
				return ha < hb if under else ha > hb
			return a.x < b.x or a.x == b.x and a.y < b.y)
		var table: Array = []
		for entry: Array in (INVERTED if under else SLOPES):
			# The steep ones are fitted by distance only (_fit_near).
			if entry.size() > 7 and bool(entry[7]):
				continue
			if under or entry[0] == "cheese" or entry[0] == kind or kind == "mixed":
				table.append(entry)
		for key: Variant in cells:
			var cell: Vector2i = key
			if used.has(cell):
				continue
			var best: Dictionary = {}
			for out: Vector2i in Shapes.OUT:
				var inner: Vector2i = cell - out
				if not height.has(inner):
					continue
				var top: int = height[inner]
				var drop: int = (int(height[cell]) - top) if under else (top - int(height[cell]))
				if drop < 1:
					continue
				for entry: Array in table:
					var length: int = entry[1]
					var tall_: int = entry[2]
					var profile: Array = entry[5]
					# Its high end flush with the stud above, or a plate or two
					# under it: the surface passes through the middle of that
					# stud, and a ramp falling a plate a stud, fitted flush, was
					# a plate too high all the way down and took cheese slopes.
					for drop_by: int in 3:
						var base: int = (top + drop_by) if under else (top - tall_ - drop_by)
						var error: float = 0.0
						var fits: bool = base >= 0
						for n: int in length:
							if not fits:
								break
							var at_: Vector2i = cell + out * n
							if not height.has(at_) or used.has(at_):
								fits = false
								break
							var here: int = height[at_]
							if under:
								# Hung from the shape's plates over it, so they have
								# to be there: under a wheel arch's thin bridge an
								# inverted slope took the bridge's place and hung
								# from nothing.
								if here < base or here > base + tall_ or at(at_, base + tall_) < 0:
									fits = false
									break
								error += absf(float(here - base) - float(profile[n]))
							else:
								# Standing on the shape's plates, so they have to be
								# there: over a wheel arch a slope took the place of
								# a bridge one plate thick and stood on nothing.
								# Nor at the foot on wheels, where only the chassis
								# holds a stud: a car's nose corner was a cheese
								# slope on nothing, held by nothing.
								if here < base or here > base + tall_ \
										or (base > 0 and (at(at_, base - 1) < 0
											or taken.has(Vector3i(at_.x, base - 1, at_.y)))) \
										or (base == 0 and not foot_on(at_)):
									fits = false
									break
								error += absf(float(here - base) - float(profile[n]))
						if not fits:
							continue
						# On its side a slope is held only by a stud reaching into
						# a row it grips by: against the core, a side stud there.
						if flank and not under:
							var gripped: bool = false
							for row: Variant in Shapes.part(library, str(entry[3])).get("grips", []):
								gripped = gripped or base > 0 or held.has(cell + out * int(row))
							if not gripped:
								continue
						error /= length
						# The longest slope whose fall is within a plate of the
						# shape's.
						var score: float = error - 0.2 * length
						# Mixed: the kind the surface is here, curved on a round
						# part and straight on a flat facet, unless the other
						# fits it by more than half a plate.
						if kind == "mixed" and not under and prefer.is_valid() \
								and entry[0] != "cheese" and str(prefer.call(cell)) != entry[0]:
							score += 0.5
						# A flank falling a plate a stud took a cheese slope a
						# stud, a staircase of little wedges: there a curved
						# 2 x 1 falls within half a plate of it, and reads as
						# the curve it is. An egg's flank was 2.6% curved. Not
						# where its colour changes: on a fuselage's canopy edge
						# a curved 2 x 1 laid there was held by nothing.
						if flank and kind == "curved" and entry[0] == "cheese" \
								and _one_colour(inner, top, cell, out):
							score += 0.3
						if error <= 1.0 and (best.is_empty() or score < float(best["score"])):
							var colour: int = at(inner, (top if under else top - 1))
							if colour < 0:
								colour = at(cell, int(height[cell]) - (0 if under else 1))
							best = {"cell": cell, "facing": out, "length": length,
								"tall": tall_, "y": base, "kind": entry[0], "colour": colour,
								"under": under, "score": score, "inner": inner}
			if best.is_empty():
				continue
			if colour_shown:
				best["colour"] = _shown(best)
			for n: int in int(best["length"]):
				used[cell + (best["facing"] as Vector2i) * n] = true
			var profile_of: Array = []
			for entry: Array in table:
				if entry[0] == best["kind"] and int(entry[1]) == int(best["length"]) \
						and int(entry[2]) == int(best["tall"]):
					profile_of = entry[5]
			for n: int in int(best["length"]):
				var over: float = float(profile_of[n]) if n < profile_of.size() else 0.0
				height[cell + (best["facing"] as Vector2i) * n] = int(best["y"]) + roundi(over)
			picks.append(best)

	## How much nearer the model, in studs, the best surface part at a place
	## has to be than a longer one for the longer not to be taken: a slope
	## three studs long where three cheese slopes are as near. At 0.04 the
	## bunny at 48 studs had 276 cheese slopes 1 x 1; at 0.1, 201, and as
	## near. At 0.1 the probe's sphere took 5 parts more than main's, at 0.15
	## its seams bridged fell a point short of main's; at 0.12 both hold.
	const LONGER := 0.06
	## What a degree between a part's surface and the model's costs, in studs
	## of distance: shading shows the turn, as Chamfer shows the gap.
	const TURN := 0.1
	## The longest surface part, in studs along its fall.
	const LONGEST := 4
	## Fit each surface part where the model's surface leans as well as where
	## its studs step down (_fit_near).
	const LEAN_FIRST := true
	## The most a part fitted to the lean alone may stand off the model's
	## surface at any third of a stud, plates.
	const PROUD := 1.0

	## The base, in plates, that lays a part's surface ([param near], at each
	## third of a stud) nearest the model's ([param ahead], rows of thirds)
	## over its [param length] studs: the mean of the two's differences,
	## rounded; -1 where the model has too little surface there.
	static func _fitted_base(ahead: Array, near: Array, length: int) -> int:
		var sum: float = 0.0
		var count: int = 0
		for n: int in length:
			var row: PackedFloat32Array = ahead[n]
			for t: int in 3:
				if not is_nan(row[t]):
					sum += row[t] - float(near[3 * n + t])
					count += 1
		if count < length * 2:
			return -1
		return roundi(sum / count)

	## [method _fit] by distance, where the plan has [member fine]: at each
	## place a slope could start, every slope, curved slope and inverted one
	## in every turn and at each height that stands on the shape is laid
	## against the model's own surface at the thirds of a stud it covers, by
	## how far its surface is from the model's and how far it turns from it;
	## the nearest is kept, or the longest within [constant LONGER] of it, if
	## it is nearer than the plates it takes the place of. Chosen per stud by
	## a flat-or-curved flag, smooth was no nearer the model than plain bricks
	## (Chamfer 0.263 against 0.265 studs at 48 studs; 0.253 fitted so).
	## Stacking a straight slope's flat top under the slope above, as a roof
	## is laid, was nearer still, but the slope under took the place of the
	## core's plates that bridged its neighbours, and the sphere's seams
	## bridged fell from 53% to 48%.
	func _fit_near(picks: Array, under: bool) -> void:
		var height: Dictionary = feet() if under else tops()
		var first: Dictionary = height.duplicate()
		var used: Dictionary = screened.duplicate()
		var rows: Dictionary = {}
		var cells: Array = height.keys()
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var ha: int = height[a]
			var hb: int = height[b]
			if ha != hb:
				return ha < hb if under else ha > hb
			return a.x < b.x or a.x == b.x and a.y < b.y)
		var table: Array = INVERTED if under else SLOPES
		var asked: int = 0
		for key: Variant in cells:
			# A run's stop asked as the courses ask it: at 64 studs this is a
			# second's work on a busy box.
			asked += 1
			if asked % 256 == 0 and stop.is_valid() and bool(stop.call()):
				return
			var cell: Vector2i = key
			if used.has(cell):
				continue
			var found: Array = []
			var least: float = INF
			for o: int in Shapes.OUT.size():
				var out: Vector2i = Shapes.OUT[o]
				var inner: Vector2i = cell - out
				# Its high end by the stud above it where that stud stands higher;
				# else, the lean first: where the model's own surface falls away
				# along [param out], at the height that lays it nearest (below).
				var stepped: bool = height.has(inner)
				var top: int = height[inner] if stepped else int(height[cell])
				var drop: int = (int(height[cell]) - top) if under else (top - int(height[cell]))
				stepped = stepped and drop >= 1
				if not stepped and not LEAN_FIRST:
					continue
				# The model's surface over each stud a part here could cover.
				var ahead: Array = []
				for n: int in LONGEST:
					var at_: Vector2i = cell + out * n
					if not height.has(at_):
						break
					ahead.append(_row(rows, at_, o, first, under))
				for entry: Array in table:
					var length: int = entry[1]
					var tall_: int = entry[2]
					var near: Array = entry[6]
					if length > ahead.size():
						continue
					# Its high end flush with the stud above, or as far under it as
					# it is tall: a steep slope's flat top where the stud it covers
					# is, not where the one above it is. And at the height its
					# surface is nearest the model's, wherever that is.
					var bases: Array[int] = []
					if stepped:
						for drop_by: int in maxi(3, tall_ + 1):
							bases.append((top + drop_by) if under else (top - tall_ - drop_by))
					var steps: int = bases.size()
					# Not the curved four-long ones: fitted to the lean their tips ran
					# past the model's edge, the farthest of anything seen from the side.
					if LEAN_FIRST and not (length == LONGEST and entry[0] != "straight"):
						var fitted: int = _fitted_base(ahead, near, length)
						# Its high end no higher than a plate over the stud above or
						# its own (under an overhang, no lower): its back stood proud
						# of the model, seen from the side.
						if fitted != -1 and height.has(inner):
							var high: int = maxi(int(height[inner]), int(height[cell]))
							var low: int = mini(int(height[inner]), int(height[cell]))
							if (not under and fitted + tall_ > high + 1) or (under and fitted < low - 1):
								fitted = -1
						if fitted != -1 and not bases.has(fitted):
							bases.append(fitted)
					for b_: int in bases.size():
						var base: int = bases[b_]
						if base < 0:
							continue
						# Fitted to the lean alone, it stands on the model's surface over
						# every stud, none of it [constant PROUD] plates off: a curved 4 x 1
						# fitted by its mean ran its tip out past the model's edge.
						var strict: bool = b_ >= steps
						var fits: bool = true
						var gap: float = 0.0
						var stair: float = 0.0
						var turn: float = 0.0
						var stair_turn: float = 0.0
						var count: int = 0
						var turns: int = 0
						var was := Vector3(NAN, NAN, NAN)    ## model, part, plates, a third back
						for n: int in length:
							var at_: Vector2i = cell + out * n
							if not height.has(at_) or used.has(at_) \
									or not _stands_at(at_, int(height[at_]), base, tall_, under):
								fits = false
								break
							# On its side, a straight slope's stud on its high end stands
							# in nothing of another side's: at a corner of Bob two shells
							# met, and one's stud stood in the other's curved slope.
							if n == 0 and air.is_valid() and not under and entry[0] == "straight" \
									and not bool(air.call(at_.x + 0.5, base + tall_ + 0.5, at_.y + 0.5)):
								fits = false
								break
							var row: PackedFloat32Array = ahead[n]
							var flat: float = float(first[at_])
							var here_count: int = 0
							for s: int in 3:
								var m: float = row[s]
								var p: float = base + float(near[3 * n + s])
								if is_nan(m):
									was = Vector3(NAN, NAN, NAN)
									continue
								if strict and absf(m - p) > PROUD:
									fits = false
								here_count += 1
								gap += absf(m - p)
								stair += absf(m - flat)
								count += 1
								if not is_nan(was.x):
									# A third of a stud apart: a plate's rise is 1.2 studs a stud.
									var model_angle: float = atan((m - was.x) * 1.2)
									turn += absf(model_angle - atan((p - was.y) * 1.2))
									stair_turn += absf(model_angle - atan((flat - was.z) * 1.2))
									turns += 1
								was = Vector3(m, p, flat)
							if strict and here_count < (3 if Shapes.TRY.contains("full") else 2):
								fits = false
							if not fits:
								break
						if not fits or count < length * 2:
							continue
						var mean_gap: float = gap / count
						if mean_gap > 1.0:
							continue
						var score: float = 0.4 * mean_gap + TURN * rad_to_deg(turn / maxi(turns, 1))
						var plain: float = 0.4 * stair / count + TURN * rad_to_deg(stair_turn / maxi(turns, 1))
						if score > plain:
							continue
						# On its side, on the core's face, a slope is held only by a
						# side stud into a row it grips by (as _fit has it).
						if flank and not under and base == 0:
							var gripped: bool = false
							var one_wide: String = str(entry[3]) if not str(entry[3]).is_empty() else str(entry[4])
							for row: Variant in Shapes.part(library, one_wide).get("grips", []):
								gripped = gripped or held.has(cell + out * int(row))
							if not gripped:
								continue
						least = minf(least, score)
						found.append([score, length, {"cell": cell, "facing": out, "length": length,
							"tall": tall_, "y": base, "kind": entry[0], "under": under,
							"score": score, "inner": inner, "top": top}])
			if found.is_empty():
				continue
			# The longest as near as the nearest, then the nearest.
			found.sort_custom(func(a: Array, b: Array) -> bool:
				var a_near: bool = float(a[0]) <= least + LONGER
				var b_near: bool = float(b[0]) <= least + LONGER
				if a_near != b_near:
					return a_near
				if a_near and int(a[1]) != int(b[1]):
					return int(a[1]) > int(b[1])
				return float(a[0]) < float(b[0]))
			var best: Dictionary = {}
			for one: Array in found:
				var pick: Dictionary = one[2]
				var inner: Vector2i = pick["inner"]
				var top: int = pick["top"]
				var colour: int = at(inner, (top if under else top - 1))
				if colour < 0:
					colour = at(cell, int(height[cell]) - (0 if under else 1))
				pick["colour"] = colour
				if colour_shown:
					pick["colour"] = _shown(pick)
				# Only in a colour it is sold in, as the core's bricks are (_made).
				if _made(_slope_id(pick), int(pick["colour"])):
					best = pick
					break
			if best.is_empty():
				continue
			for n: int in int(best["length"]):
				used[cell + (best["facing"] as Vector2i) * n] = true
			var profile_of: Array = []
			for entry: Array in table:
				if entry[0] == best["kind"] and int(entry[1]) == int(best["length"]) \
						and int(entry[2]) == int(best["tall"]):
					profile_of = entry[5]
			for n: int in int(best["length"]):
				var over: float = float(profile_of[n]) if n < profile_of.size() else 0.0
				height[cell + (best["facing"] as Vector2i) * n] = int(best["y"]) + roundi(over)
			picks.append(best)

	## Whether a surface part [param tall_] plates tall from [param base]
	## stands at [param at_], whose top (or under an overhang, foot) is
	## [param here]: within it, and on the shape's own plates (hung from them).
	func _stands_at(at_: Vector2i, here: int, base: int, tall_: int, under: bool) -> bool:
		if here < base or here > base + tall_ or base + tall_ > tall:
			return false
		# What it stands in past the shape's top (under an overhang, below its
		# foot) is air nothing else has: fitted to the lean a plate proud of
		# its stud, a curved 4 x 1 on Bob's flank stood out of its shell's box
		# into a cheese slope of the side beside it, and three parts were
		# taken out.
		for j: int in (range(base, here) if under else range(here, base + tall_)):
			var key := Vector3i(at_.x, j, at_.y)
			if taken.has(key) or shelled.has(key) \
					or (room.is_valid() and not bool(room.call(at_.x + 0.5, j + 0.5, at_.y + 0.5))):
				return false
		# Not under a shell: a slope's studs (an inverted one's, or a straight
		# one's flat top) ran into the plate on its side over it.
		if shelled.has(Vector3i(at_.x, base + tall_, at_.y)):
			return false
		if under:
			return at(at_, base + tall_) >= 0
		if base > 0:
			return at(at_, base - 1) >= 0 and not taken.has(Vector3i(at_.x, base - 1, at_.y))
		return foot_on(at_)

	## The model's surface over [param cell] at the three thirds of a stud
	## along Shapes.OUT[[param o]] from the side it comes in by, each the mean
	## across, in plates; NAN where none of the three has it.
	func _row(rows: Dictionary, cell: Vector2i, o: int, first: Dictionary,
			under: bool) -> PackedFloat32Array:
		if not rows.has(cell):
			var nine: PackedFloat32Array = fine.call(cell, float(first[cell]), under)
			var out := PackedFloat32Array()
			out.resize(12)
			for way: int in 4:
				var step: Vector2i = Shapes.OUT[way]
				for s: int in 3:
					var t: int = s if step.x + step.y > 0 else 2 - s
					var sum: float = 0.0
					var count: int = 0
					for c: int in 3:
						var v: float = nine[t * 3 + c] if step.x != 0 else nine[c * 3 + t]
						if not is_nan(v):
							sum += v
							count += 1
					out[way * 3 + s] = sum / count if count > 0 else NAN
			rows[cell] = out
		var all: PackedFloat32Array = rows[cell]
		return all.slice(o * 3, o * 3 + 3)

	## The one-wide part a pick is laid as, whatever it is turned.
	func _slope_id(pick: Dictionary) -> String:
		for entry: Array in (INVERTED if bool(pick["under"]) else SLOPES):
			if entry[0] == pick["kind"] and int(entry[1]) == int(pick["length"]) \
					and int(entry[2]) == int(pick["tall"]):
				return str(entry[3]) if not str(entry[3]).is_empty() else str(entry[4])
		return ""

	## The colour a slope shows: the shape's own where the surface it stands
	## for is, the top plate of each stud it covers (the lowest, under an
	## overhang), the colour most of them are; a tie goes to the stud above.
	## Coloured by the stud above it, a sculpt's patches ran down its flanks
	## in the colour over them, and smooth matched a model's colours worse
	## than plain bricks did (CIEDE2000 10.1 against 8.8 at 48 studs).
	func _shown(pick: Dictionary) -> int:
		var votes: Dictionary = {}
		var facing: Vector2i = pick["facing"]
		var y: int = pick["y"]
		var high: int = mini(y + int(pick["tall"]), tall)
		for n: int in int(pick["length"]):
			var cell: Vector2i = (pick["cell"] as Vector2i) + facing * n
			var c: int = -1
			if bool(pick["under"]):
				for j: int in range(maxi(y, 0), tall):
					c = at(cell, j)
					if c >= 0:
						break
			else:
				for j: int in range(high - 1, -1, -1):
					c = at(cell, j)
					if c >= 0:
						break
			if c >= 0:
				votes[c] = int(votes.get(c, 0)) + 1
		var best: int = int(pick["colour"])
		for c: Variant in votes:
			if int(votes[c]) > int(votes.get(best, 0)):
				best = int(c)
		return best

	## Whether the two studs falling from [param inner] (its top at
	## [param top]) along [param out] from [param cell] are topped in its
	## colour.
	func _one_colour(inner: Vector2i, top: int, cell: Vector2i, out: Vector2i) -> bool:
		var tops_: Dictionary = tops()
		var colour: int = at(inner, top - 1)
		for n: int in 2:
			var here: Vector2i = cell + out * n
			if not tops_.has(here) or at(here, int(tops_[here]) - 1) != colour:
				return false
		return true

	## Take the plates a slope stands in out of the shape — everything over
	## its foot in the studs it covers, or under an overhang everything under
	## its top — and keep the plate under it studded.
	func _carve(pick: Dictionary) -> void:
		var facing: Vector2i = pick["facing"]
		var perp := Vector2i(absi(facing.y), absi(facing.x))
		var y: int = pick["y"]
		var under: bool = pick["under"]
		for a: int in int(pick.get("wide", 1)):
			for b: int in int(pick["length"]):
				var cell: Vector2i = (pick["cell"] as Vector2i) + perp * a + facing * b
				if not columns.has(cell):
					continue
				var column: PackedInt32Array = columns[cell]
				var span: Vector2i = Vector2i(0, mini(y + int(pick["tall"]), tall)) if under \
					else Vector2i(maxi(y, 0), tall)
				for j: int in range(span.x, span.y):
					column[j] = -1
				columns[cell] = column
				if not under:
					studded[cell] = true

	## The picks as a mirror would have them, in groups to be laid together:
	## those on one side of the plane and on it, each paired with the one
	## beside it into a part two studs wide where the two are the same, each
	## with its reflection on the other side.
	## A pick beside the plane falling along it pairs with its own mirror,
	## so the part over the middle is one part, symmetric by itself.
	func _symmetric(picks: Array) -> Array:
		var by_cell: Dictionary = {}
		for pick: Dictionary in picks:
			by_cell[_key(pick["cell"], pick)] = pick
		var paired: Dictionary = {}
		var out: Array = []
		for pick: Dictionary in picks:
			var cell: Vector2i = pick["cell"]
			if paired.has(_key(cell, pick)):
				continue
			if not axis.is_empty() and across(cell) * 2 > sum:
				continue
			var facing: Vector2i = pick["facing"]
			var perp := Vector2i(absi(facing.y), absi(facing.x))
			var twin: Dictionary = by_cell.get(_key(cell + perp, pick), {})
			if not twin.is_empty() and not axis.is_empty() \
					and across(twin["cell"]) * 2 > sum and reflect(cell) != Vector2i(twin["cell"]):
				twin = {}
			if not twin.is_empty() and twin["facing"] == facing \
					and twin["length"] == pick["length"] and twin["tall"] == pick["tall"] \
					and twin["kind"] == pick["kind"] and twin["colour"] == pick["colour"] \
					and not paired.has(_key(twin["cell"], twin)):
				var both: Dictionary = pick.duplicate()
				both["wide"] = 2
				paired[_key(cell, pick)] = true
				paired[_key(twin["cell"], twin)] = true
				out.append(both)
				continue
			paired[_key(cell, pick)] = true
			out.append(pick)
		var whole: Array = []
		if axis.is_empty():
			for pick: Dictionary in out:
				whole.append([pick])
			return whole
		for pick: Dictionary in out:
			whole.append([pick])
			var cell: Vector2i = pick["cell"]
			var facing: Vector2i = pick["facing"]
			var perp := Vector2i(absi(facing.y), absi(facing.x))
			var cells: Array[Vector2i] = [cell]
			if int(pick.get("wide", 1)) == 2:
				cells.append(cell + perp)
			var mirrored: Array[Vector2i] = []
			for one: Vector2i in cells:
				mirrored.append(reflect(one))
			if mirrored.has(cell):
				continue
			var start: Vector2i = mirrored[0]
			for one: Vector2i in mirrored:
				if one.x * perp.x + one.y * perp.y < start.x * perp.x + start.y * perp.y:
					start = one
			var twin: Dictionary = pick.duplicate()
			twin["cell"] = start
			twin["facing"] = Vector2i(facing.x, -facing.y) if axis == "z" \
				else Vector2i(-facing.x, facing.y)
			(whole[-1] as Array).append(twin)
		return whole

	func _key(cell: Vector2i, pick: Dictionary) -> String:
		return "%d %d %d %s" % [cell.x, cell.y, int(pick["y"]), str(pick["under"])]

	## Lay a pick: its slope, one or two studs wide, standing on the stud at
	## the foot of its run (or, under an overhang, hung from it).
	func _place(pick: Dictionary) -> void:
		var cell: Vector2i = pick["cell"]
		var facing: Vector2i = pick["facing"]
		var wide: int = int(pick.get("wide", 1))
		var under: bool = pick["under"]
		var length: int = pick["length"]
		var tall_: int = pick["tall"]
		var id: String = _part_id(pick)
		var shape: Dictionary = Shapes.part(library, id, under)
		var perp := Vector2i(absi(facing.y), absi(facing.x))
		var cells: Array[Vector2i] = []
		var high_row: Array[Vector2i] = []
		for a: int in wide:
			high_row.append(cell + perp * a)
			for b: int in length:
				cells.append(cell + perp * a + facing * b)
		var low := Vector2i(1 << 30, 1 << 30)
		for one: Vector2i in cells:
			low = Vector2i(mini(low.x, one.x), mini(low.y, one.y))
		var rot: int = posmod(Shapes.OUT.find(facing) + int(shape["turn"]), 4)
		var from: int = pick["y"]
		# Joined where the part really is: by the rows with studs on top to
		# what stands on it, and by the rows a stud from below reaches into to
		# what it stands on (Shapes.part's "tops" and "grips"), each read off
		# its own mesh. Counted held by its high end, a curved slope, hollow
		# there, was said to join what the check found apart.
		var studs: Array[Vector2i] = _gripped(pick, shape, "tops")
		var base: Array[Vector2i] = _gripped(pick, shape)
		if base.is_empty():
			base.append_array(high_row)
		if under:
			# Hung from the studs over it.
			made.append({"part": id, "color": pick["colour"], "x": low.x, "y": from,
				"z": low.y, "rot": rot, "_cells": cells, "_h": tall_, "_studs": studs,
				"_base": base, "_slope": true})
		else:
			made.append({"part": id, "color": pick["colour"], "x": low.x, "y": from,
				"z": low.y, "rot": rot, "_top": true, "_cells": cells, "_h": tall_,
				"_studs": studs, "_base": base, "_slope": true})
		_take(cells, from, tall_)

	## The cells of a pick a stud from under it reaches into: its rows the
	## part grips by, every stud across.
	func _gripped(pick: Dictionary, shape: Dictionary, rows: String = "grips") -> Array[Vector2i]:
		var facing: Vector2i = pick["facing"]
		var perp := Vector2i(absi(facing.y), absi(facing.x))
		var out: Array[Vector2i] = []
		for a: int in int(pick.get("wide", 1)):
			for row: Variant in shape.get(rows, []):
				out.append((pick["cell"] as Vector2i) + perp * a + facing * int(row))
		return out

	## Mark the plates a surface part stands in, so nothing else is laid there
	## and no wedge's cut side reaches into it.
	func _take(cells: Array[Vector2i], from: int, plates: int) -> void:
		for one: Vector2i in cells:
			for n: int in plates:
				taken[Vector3i(one.x, from + n, one.y)] = true

	## The core and the top: plate by plate from the bottom, bricks where a
	## whole course is the shape's and nothing has taken it, plates where it
	## is not, tiles on top; each layer as one half, its mirror, and a strip
	## across the middle tying them.
	func lay() -> Array:
		var covered: Dictionary = {}
		made.append_array(round_made)
		made.append_array(anchors)
		for j: int in tall:
			if stop.is_valid() and bool(stop.call()):
				break
			if j % 3 == 0:
				var k: int = j / 3
				var bricks: Dictionary = {}
				for key: Variant in full(k):
					var cell: Vector2i = key
					# A course with nothing under it and nothing studded over it
					# is a bridge, and bricks side by side in one course join
					# only through what is over and under them. A car's body
					# over its arches was a course of bricks with tiles on top
					# and a cut under, and its nose came away from it; laid in
					# plates, the layers cross the joints. (A ceiling with more
					# courses over it, as a hollow sculpt's is, keeps bricks.)
					if bridges and j > 0 and at(cell, j - 1) < 0 and not body(cell, j + 3):
						continue
					# Nor at a foot off the ground with nothing under it: there
					# the plates cross each other's joints and tie the foot
					# together, which side by side bricks never are. A car's
					# tail corners past its chassis, and a fighter's nose past
					# its stands, were bricks at the foot held by nothing.
					if bridges and j == 0 and not foot_on(cell):
						continue
					if _free(covered, cell, j) and _free(covered, cell, j + 1) \
							and _free(covered, cell, j + 2):
						var shown: int = shown_colour(cell, j, 3) if bond else ANY
						bricks[cell] = shown if shown >= 0 else at(cell, j + 1)
				# Wedge bricks where a course's plan edge runs on the diagonal: a
				# hull's bow in bricks was a staircase where its plates had
				# wedges.
				var claimed: Dictionary = bricks.duplicate()
				for one: Dictionary in _wedged_off(bricks, j, 3):
					made.append(one)
				for key: Variant in claimed:
					if not bricks.has(key):
						for n: int in 3:
							covered[Vector3i((key as Vector2i).x, j + n, (key as Vector2i).y)] = true
				# Where a plate's edge part follows the edge and no brick's
				# does, the studs it would take are left to the plates, which
				# come in more cuts than bricks do: laid in bricks, a round
				# body's rim was a staircase up every course.
				var trial: Dictionary = bricks.duplicate()
				var cut_before: Dictionary = cut_in.duplicate()
				_wedged_off(trial, j + 1)
				cut_in = cut_before
				for key: Variant in bricks.keys():
					if not trial.has(key):
						bricks.erase(key)
				# Every other course, the outside of a straight side as bricks
				# with studs on it and a tile on them: the side smooth, as a
				# set's is, and not a face of plain bricks.
				if sides_smooth and k % 2 == 0:
					for one: Dictionary in _panels(bricks, j, k):
						made.append(one)
						for cell: Vector2i in one["_cells"]:
							for n: int in 3:
								covered[Vector3i(cell.x, j + n, cell.y)] = true
				for one: Dictionary in _layer(bricks, j, Shapes.CORE_BRICKS, k):
					made.append(_annotated(one, Shapes.CORE_BRICKS, 3, true))
				for key: Variant in bricks:
					var cell: Vector2i = key
					for n: int in 3:
						covered[Vector3i(cell.x, j + n, cell.y)] = true
			var plates: Dictionary = {}
			var tops: Dictionary = {}
			var under: Dictionary = {}
			for key: Variant in columns:
				var cell: Vector2i = key
				if at(cell, j) < 0 or not _free(covered, cell, j):
					continue
				if is_top(cell, j):
					tops[cell] = at(cell, j)
				elif under_shell(cell, j):
					under[cell] = at(cell, j)
				else:
					plates[cell] = at(cell, j)
			for one: Dictionary in _wedged_off(plates, j):
				made.append(one)
			for one: Dictionary in _layer(plates, j, Shapes.CORE_PLATES, -1):
				made.append(_annotated(one, Shapes.CORE_PLATES, 1, true))
			for one: Dictionary in _layer(tops, j, Shapes.TOPS, -1):
				one["_top"] = true
				made.append(_annotated(one, Shapes.TOPS, 1, false))
			# Under a shell, tiles too, but no top's: a top colour is for what
			# shows from above.
			for one: Dictionary in _layer(under, j, Shapes.TOPS, -1):
				made.append(_annotated(one, Shapes.TOPS, 1, false))
			for key: Variant in plates:
				covered[Vector3i((key as Vector2i).x, j, (key as Vector2i).y)] = true
			for key: Variant in tops:
				covered[Vector3i((key as Vector2i).x, j, (key as Vector2i).y)] = true
			for key: Variant in under:
				covered[Vector3i((key as Vector2i).x, j, (key as Vector2i).y)] = true
		return made

	## A core part with the studs it covers, how tall it is, and which of
	## them carry studs on top ([param studded]: plates and bricks do, tiles
	## do not).
	func _annotated(one: Dictionary, tiles: Array, height: int, studded: bool) -> Dictionary:
		var size := Vector2i(1, 1)
		for tile: Variant in tiles:
			var entry: Array = tile
			if str(entry[2]) == str(one["part"]) and int(entry[3]) == int(one["rot"]):
				size = Vector2i(int(entry[0]), int(entry[1]))
				break
		var cells: Array[Vector2i] = []
		for dx: int in size.x:
			for dz: int in size.y:
				cells.append(Vector2i(int(one["x"]) + dx, int(one["z"]) + dz))
		one["_cells"] = cells
		one["_h"] = height
		one["_studs"] = cells if studded else ([] as Array[Vector2i])
		one["_base"] = cells
		return one

	## Only the parts joined to the shape's foot by studs, each into a part
	## over it or under it: a plate a stud wide on the rim, its neighbours all
	## bricks, was laid as a 1 x 1 held by nothing, and a bird's tail tip came
	## out as a wedge with two tiles on it, joined to each other and nothing
	## else.
	func prune() -> void:
		var bottoms: Dictionary = {}    ## Vector3i(x, bottom, z) -> part
		for n: int in made.size():
			var one: Dictionary = made[n]
			var y: int = int(round(float(one["y"])))
			for cell: Vector2i in one.get("_base", []):
				bottoms[Vector3i(cell.x, y, cell.y)] = n
		var joined: Array = []
		for n: int in made.size():
			joined.append([])
		for n: int in made.size():
			var one: Dictionary = made[n]
			var y: int = int(round(float(one["y"])))
			var h: int = int(one.get("_h", 1))
			for cell: Vector2i in one.get("_studs", []):
				var above: int = int(bottoms.get(Vector3i(cell.x, y + h, cell.y), -1))
				if above >= 0 and above != n:
					(joined[n] as Array).append(above)
					(joined[above] as Array).append(n)
		var reached: Dictionary = {}
		var stack: Array = []
		var lowest: int = 1 << 30
		for one: Dictionary in made:
			lowest = mini(lowest, int(round(float(one["y"]))))
		for n: int in made.size():
			if int(round(float((made[n] as Dictionary)["y"]))) > lowest:
				continue
			# A shell on its side is held where a side stud reaches its foot,
			# not wherever its foot is.
			var seeded: bool = held.is_empty()
			for cell: Vector2i in (made[n] as Dictionary).get("_base", []):
				seeded = seeded or held.has(cell)
			if seeded:
				reached[n] = true
				stack.append(n)
		while not stack.is_empty():
			var n: int = stack.pop_back()
			for m: int in joined[n]:
				if not reached.has(m):
					reached[m] = true
					stack.append(m)
		var kept: Array = []
		for n: int in made.size():
			if reached.has(n):
				kept.append(made[n])
		made = kept

	## The parts in pieces, each an Array of indices into [member made], by
	## studs into the part over or under, largest first. Counted every round of
	## the stitch and after every way it tries, so in packed arrays: as Arrays of
	## Arrays it was most of a forty-stud bunny's stitch. Walked in the order it
	## always was (each part's joins as its studs and the studs under it meet
	## them), so the same pieces come out in the same order, and the stitch
	## makes the same joins.
	func pieces() -> Array:
		var count: int = made.size()
		var bottoms: Dictionary = {}
		var tops := PackedInt32Array()
		tops.resize(count)
		for n: int in count:
			var one: Dictionary = made[n]
			var y: int = int(round(float(one["y"])))
			tops[n] = y + int(one.get("_h", 1))
			for cell: Vector2i in one.get("_base", []):
				bottoms[Vector3i(cell.x, y, cell.y)] = n
		var from := PackedInt32Array()
		var to := PackedInt32Array()
		var first := PackedInt32Array()
		first.resize(count + 1)
		for n: int in count:
			var top: int = tops[n]
			for cell: Vector2i in (made[n] as Dictionary).get("_studs", []):
				var above: int = int(bottoms.get(Vector3i(cell.x, top, cell.y), -1))
				if above >= 0 and above != n:
					from.append(n)
					to.append(above)
					first[n + 1] += 1
					first[above + 1] += 1
		for n: int in count:
			first[n + 1] += first[n]
		var fill: PackedInt32Array = first.duplicate()
		var joins := PackedInt32Array()
		joins.resize(first[count])
		for e: int in from.size():
			joins[fill[from[e]]] = to[e]
			fill[from[e]] += 1
			joins[fill[to[e]]] = from[e]
			fill[to[e]] += 1
		var seen := PackedByteArray()
		seen.resize(count)
		var stack := PackedInt32Array()
		stack.resize(count + 1)
		var out: Array = []
		for start: int in count:
			if seen[start] == 1:
				continue
			var piece: Array = []
			stack[0] = start
			var held: int = 1
			seen[start] = 1
			while held > 0:
				held -= 1
				var n: int = stack[held]
				piece.append(n)
				for k: int in range(first[n], first[n + 1]):
					var m: int = joins[k]
					if seen[m] == 0:
						seen[m] = 1
						stack[held] = m
						held += 1
			out.append(piece)
		out.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
		return out

	## Join a piece that stands apart to the rest: somewhere it has a plate or
	## a brick beside one of the rest's, at the same height, the two are laid
	## again as parts one of which reaches across — and the same at the
	## mirror. A car's nose stood on its own past the wheel arch, joined to
	## the body by nothing over the arch's thin bridge.
	##
	## A way of joining is kept only if it leaves fewer pieces. Kept whether
	## or not it did, the car's corner was laid again joined and the brick
	## beside it left apart, then that brick joined and the corner left apart,
	## 96 times over: its nose and its tail came back loose, and the run built
	## the body by hand.
	func stitch() -> void:
		var refused: Dictionary = {}
		var first_refused: Dictionary = {}
		var again: bool = true
		var clock: Dictionary = {"rounds": 0, "pieces": 0, "pair": 0, "unedge": 0, "rejoin": 0,
			"rejoin_tries": 0}
		Shapes.last["stitch"] = clock
		# The fewest pieces the plan has been in, and the plan then; the pieces
		# apart in each round since, to know a round that only goes back; and
		# whether the first ways are now checked as the rejoin's are.
		var fewest := Vector2i(1 << 30, 0)
		var best: Array = []
		var stalled: int = 0
		var seen_apart: Dictionary = {}
		var checked_first: bool = false
		for _round: int in 96:
			clock["rounds"] = int(clock["rounds"]) + 1
			_replatable_at.clear()
			var t: int = Time.get_ticks_msec()
			var found: Array = pieces()
			clock["pieces"] = int(clock["pieces"]) + Time.get_ticks_msec() - t
			clock["apart"] = found.size() - 1
			if found.size() <= 1:
				break
			# The first ways kept unchecked, and the pieces apart as they were in
			# a round before, or no fewer for STALLED rounds: the plan as it was at
			# its fewest pieces, and from then on the first ways checked with
			# the rejoin's. Kept unchecked, they laid the same pair again and
			# again on 41 of the bench's 56 runs until the 96 rounds ran out,
			# and the rejoin was never tried: a fox's legs and an aircraft's
			# gear were left to the mend, which took them out.
			var now := Vector2i(found.size(), _bulk(found[0]))
			if now.x < fewest.x or now.x == fewest.x and now.y > fewest.y:
				fewest = now
				best = made.duplicate()
				stalled = 0
			elif not bridges and rejoin and not checked_first:
				stalled += 1
				var apart := PackedStringArray()
				for piece: Array in found.slice(1):
					apart.append(_piece_key(piece))
				apart.sort()
				var key: String = "|".join(apart)
				if stalled >= STALLED or seen_apart.has(key):
					checked_first = true
					clock["stalls"] = int(clock.get("stalls", 0)) + 1
					made = best.duplicate()
					found = pieces()
				seen_apart[key] = true
			var main: Dictionary = {}
			for n: int in found[0]:
				main[n] = true
			var joined_one: bool = false
			# A sculpt's grid is stitched as it always was, each first way kept:
			# its bunny's feet were joined to its body only through ways that
			# left as many pieces on the way, and refused them it kept its feet
			# alone. Its own check mends what is left.
			if not bridges:
				# With the rejoin to follow, a piece the first two ways have
				# refused is not offered them again: each try at a joint maps the
				# whole plan, and a round for every piece the rejoin joined was
				# most of a forty-stud bunny's lay.
				var keys: Array = []
				for piece: Array in found.slice(1):
					keys.append(_piece_key(piece) if rejoin else "")
				t = Time.get_ticks_msec()
				# The rest's plain parts mapped once a round, not once a piece
				# tried: nothing changes until one joins, and then the round ends.
				var plain: Dictionary = {} if checked_first else _plain_cells(main)
				for n: int in keys.size():
					if checked_first:
						break
					if not first_refused.has(keys[n]) and _pair_across(found[n + 1], main, plain):
						joined_one = true
						break
				clock["pair"] = int(clock["pair"]) + Time.get_ticks_msec() - t
				t = Time.get_ticks_msec()
				if not joined_one and not checked_first:
					var edges: Dictionary = _edge_cells()
					for n: int in keys.size():
						if not first_refused.has(keys[n]) and _unedge(found[n + 1], main, edges):
							joined_one = true
							break
				clock["unedge"] = int(clock["unedge"]) + Time.get_ticks_msec() - t
				if not joined_one and rejoin:
					for key: Variant in keys:
						first_refused[key] = true
				# Then, for a caller that keeps every piece (Brickify), its plates
				# and slopes about the joint laid again as plates crossing it, each
				# way kept only if it leaves fewer pieces: a teapot's handle, a
				# column of 1 x 1 plates beside the body's slopes, was joined by
				# neither of the first two and left out. A piece no way joined is
				# not tried again: tried every round, a forty-stud bunny's few
				# loose bits took its lay from 5 s to 23.
				t = Time.get_ticks_msec()
				if not joined_one and rejoin:
					var before := Vector2i(found.size(), _bulk(found[0]))
					for n: int in keys.size():
						if refused.has(keys[n]):
							continue
						clock["rejoin_tries"] = int(clock["rejoin_tries"]) + 1
						if _join(found[n + 1], main, before, true, checked_first):
							joined_one = true
							break
						refused[keys[n]] = true
				clock["rejoin"] = int(clock["rejoin"]) + Time.get_ticks_msec() - t
				# Once nothing more joins, what was refused is offered every way
				# once more: joins since may have laid what it meets otherwise. A
				# fox's haunch, refused before its legs were joined, was left out.
				if not joined_one and rejoin and again \
						and not (refused.is_empty() and first_refused.is_empty()):
					again = false
					refused.clear()
					first_refused.clear()
					continue
				if not joined_one:
					break
				continue
			var before := Vector2i(found.size(), _bulk(found[0]))
			for piece: Array in found.slice(1):
				if _join(piece, main, before):
					joined_one = true
					break
			if not joined_one:
				break

	## A piece by where its parts are, so the same piece is known again in
	## the next round's pieces.
	func _piece_key(piece: Array) -> String:
		var parts := PackedStringArray()
		for n: int in piece:
			var one: Dictionary = made[n]
			parts.append("%s@%s,%s,%s" % [one.get("part", ""), one.get("x", 0), one.get("y", 0),
				one.get("z", 0)])
		parts.sort()
		return "|".join(parts)

	## How much of the shape a piece holds, in plates.
	func _bulk(piece: Array) -> int:
		var n: int = 0
		for index: int in piece:
			var one: Dictionary = made[index]
			n += (one.get("_cells", []) as Array).size() * int(one.get("_h", 1))
		return n

	## [param piece] joined to the rest by the first way that leaves fewer
	## pieces than [param before] says (x), or as many and the largest bigger
	## (y), so a way that joins one piece and splits a smaller one off still
	## counts, and nothing is undone and done again. [member made] as it was
	## when no way does.
	##
	## [param regrid] for a sculpt's grid whose first ways are spent: only the
	## plates laid again, one and two parts out, with the top's tiles, and then
	## with the slopes at the joint. Each way tried is a piece count of the
	## whole, and the full list on a forty-stud bunny's loose bits was most of
	## its lay.
	func _join(piece: Array, main: Dictionary, before: Vector2i, regrid: bool = false,
			first_too: bool = false) -> bool:
		if regrid:
			# With [param first_too], the stitch's first ways first, checked as
			# these are: once they have stalled, kept unchecked they only stall.
			var firsts: Array = [
				func() -> bool: return first_too and _pair_across(piece, main),
				func() -> bool: return first_too and _unedge(piece, main)]
			return _first_that_joins(firsts + [
				func() -> bool: return _replate(piece, main, 1, 0),
				func() -> bool: return _replate(piece, main, 2, 0),
				func() -> bool: return _replate(piece, main, 1, 1),
				# A teapot's handle met its body only at its curved slopes.
				func() -> bool: return _replate(piece, main, 1, 3),
				func() -> bool: return _replate(piece, main, 2, 3),
				# And last a plate across a colour's edge, where nothing of one
				# colour reaches the piece: pieces of an avocado, a milk truck
				# and a bust met the rest only at a colour's edge, which no part
				# of one colour crosses, and were taken out.
				func() -> bool: return _pair_across(piece, main, {}, true)], before)
		var ways: Array[Callable] = [
			func() -> bool: return _pair_across(piece, main),
			func() -> bool: return _unedge(piece, main),
			# A sculpt's grid keeps its bricks, as it does over a bridge.
			func() -> bool: return bridges and _unbrick(piece, main),
			func() -> bool: return bridges and _replate(piece, main, 1, 0),
			func() -> bool: return bridges and _replate(piece, main, 2, 0),
			func() -> bool: return bridges and _replate(piece, main, 3, 0),
			# And the top's tiles with them, their studs left showing for the
			# surface pass to tile: a nose lower than the body behind it meets
			# it only in the plate of its own top, and a tile there joins
			# nothing.
			func() -> bool: return bridges and _replate(piece, main, 1, 1),
			func() -> bool: return bridges and _replate(piece, main, 2, 1),
			func() -> bool: return bridges and _replate(piece, main, 3, 1),
			# And last the wedges, laid again square: a fighter's nose tapered
			# in wedge plates that all began at the same stud, plate over
			# plate, and met the body in a joint nothing crossed.
			func() -> bool: return bridges and _replate(piece, main, 2, 2),
			func() -> bool: return bridges and _replate(piece, main, 3, 2)]
		return _first_that_joins(ways, before)

	## The first of [param ways] that leaves fewer pieces than [param before]
	## (or as many and the largest bigger), kept; [member made] as it was when
	## none does.
	func _first_that_joins(ways: Array, before: Vector2i) -> bool:
		var was: Array = made.duplicate()
		for way: Callable in ways:
			if bool(way.call()):
				var after: Array = pieces()
				if after.size() < before.x or after.size() == before.x and _bulk(after[0]) > before.y:
					return true
			made = was.duplicate()
		return false

	## A plate or brick of [param piece] and one of the rest side by side, laid
	## again as parts one of which reaches across, and the same at the mirror.
	## Whether it was.
	func _pair_across(piece: Array, main: Dictionary, cells: Dictionary = {},
			colours: bool = false) -> bool:
		var pair: Array = _pair(piece, main, cells, colours)
		if pair.is_empty():
			return false
		var twin: Array = _mirror_pair(pair)
		var gone: Dictionary = {pair[0]: true, pair[1]: true}
		var added: Array = _across(made[pair[0]], made[pair[1]], colours)
		if added.is_empty():
			return false
		if not twin.is_empty() and not gone.has(twin[0]) and not gone.has(twin[1]):
			var mirrored: Array = _across(made[twin[0]], made[twin[1]], colours)
			if not mirrored.is_empty():
				gone[twin[0]] = true
				gone[twin[1]] = true
				added.append_array(mirrored)
		var kept: Array = []
		for n: int in made.size():
			if not gone.has(n):
				kept.append(made[n])
		kept.append_array(added)
		made = kept
		return true

	## The plain plates and bricks of [param piece], and every plain plate and
	## brick beside them out to [param reach] parts away, laid again as
	## plates, plate by plate, each plate turned across the one under it — and
	## the same at the mirror. Two parts side by side are joined only by what
	## is over or under both; at a body's foot, under a slope, there is
	## nothing, and a nose's corner, a column of 1 x 1s under a cheese slope
	## beside the bricks of the body, was joined to nothing. As plates, the
	## courses cross each other's joints there. Whether any were laid again.
	func _replate(piece: Array, main: Dictionary, reach: int, kinds: int) -> bool:
		# Mapped once a round for each kind: every way the round tries that
		# does not join is taken back, so the plan is as it was, part for part.
		# Mapped for every way, it was most of a forty-stud bunny's rejoin.
		var by_cell: Dictionary = _replatable_at.get(kinds, {})    ## Vector3i(x, plate, z) -> index
		if not _replatable_at.has(kinds):
			for n: int in made.size():
				var one: Dictionary = made[n]
				if not _replatable(one, kinds):
					continue
				var y: int = int(round(float(one["y"])))
				for cell: Vector2i in one["_cells"]:
					for h: int in int(one["_h"]):
						by_cell[Vector3i(cell.x, y + h, cell.y)] = n
			_replatable_at[kinds] = by_cell
		var region: Dictionary = {}
		for n: int in piece:
			if _replatable(made[n], kinds):
				region[n] = true
		if region.is_empty():
			return false
		for _ring: int in reach:
			var more: Dictionary = {}
			for n: Variant in region:
				var one: Dictionary = made[n]
				var y: int = int(round(float(one["y"])))
				for cell: Vector2i in one["_cells"]:
					for h: int in int(one["_h"]):
						for step: Vector2i in Shapes.OUT:
							var m: int = int(by_cell.get(Vector3i(cell.x + step.x, y + h,
								cell.y + step.y), -1))
							if m >= 0 and not region.has(m):
								more[m] = true
			if more.is_empty():
				break
			region.merge(more)
		var reaches_main: bool = false
		for n: Variant in region:
			reaches_main = reaches_main or main.has(n)
		if not reaches_main:
			return false
		if not axis.is_empty():
			for n: Variant in region.keys():
				var twin: int = _mirror_part(made[n])
				if twin >= 0:
					region[twin] = true
		var levels: Dictionary = {}    ## plate -> {cell: colour}
		for n: Variant in region:
			var one: Dictionary = made[n]
			var y: int = int(round(float(one["y"])))
			for h: int in int(one["_h"]):
				if not levels.has(y + h):
					levels[y + h] = {}
				for cell: Vector2i in one["_cells"]:
					(levels[y + h] as Dictionary)[cell] = int(one["color"])
		var kept: Array = []
		for n: int in made.size():
			if not region.has(n):
				kept.append(made[n])
		var plates: Array = levels.keys()
		plates.sort()
		var plane: String = axis
		for j: Variant in plates:
			var cells: Dictionary = levels[j]
			# Inside, where nothing shows, in the plate's commonest colour: two
			# solids of two colours meeting face to face (a smokebox on its
			# boiler) were laid each in its own parts, and nothing crossed.
			var counts: Dictionary = {}
			for cell: Variant in cells:
				counts[cells[cell]] = int(counts.get(cells[cell], 0)) + 1
			if counts.size() > 1:
				var most: int = -1
				for c: Variant in counts:
					if most < 0 or int(counts[c]) > int(counts[most]) \
							or int(counts[c]) == int(counts[most]) and int(c) < most:
						most = int(c)
				for cell: Variant in cells.keys():
					if _hidden(cell, int(j)):
						cells[cell] = most
			# Laid as a mirror only where the plate's studs are their own
			# mirror; elsewhere as they are.
			if not plane.is_empty():
				var same: bool = true
				for cell: Variant in cells:
					same = same and int(cells.get(reflect(cell), -1)) == int(cells[cell])
				axis = plane if same else ""
			for one: Dictionary in _layer(cells, int(j), Shapes.CORE_PLATES, -1):
				kept.append(_annotated(one, Shapes.CORE_PLATES, 1, true))
			axis = plane
		made = kept
		return true

	## Whether the plate at [param cell], [param j] is the shape's on every
	## side, over and under: inside, where its colour never shows.
	func _hidden(cell: Vector2i, j: int) -> bool:
		if at(cell, j - 1) < 0 or at(cell, j + 1) < 0:
			return false
		for step: Vector2i in Shapes.OUT:
			if at(cell + step, j) < 0:
				return false
		return true

	## A part that can be laid again as plates: a plain plate or brick of the
	## core; with [param kinds] 1 a tile of the top as well, and with 2 a wedge
	## plate or brick, square over its studs. Never a slope, a round part or a
	## brick with a stud on a side.
	func _replatable(one: Dictionary, kinds: int = 0) -> bool:
		if kinds >= 2 and bool(one.get("_edge", false)) and not bool(one.get("_fixed", false)) \
				and not (one["_cells"] as Array).is_empty():
			return int(one["_h"]) in [1, 3]
		# And at kinds 3, the slopes too, plate by plate over what each
		# covered: a sculpt's handle met its body only at slopes, which nothing
		# laid again, and was left out. Studs show there, where it joins.
		if kinds >= 3 and bool(one.get("_slope", false)) and not bool(one.get("_fixed", false)) \
				and not (one.get("_cells", []) as Array).is_empty():
			return true
		var tops: bool = kinds >= 1
		if one.has("panel") or one.has("_holds") or not _plain(one):
			return false
		var part: String = str(one["part"])
		var tiles: Array = Shapes.CORE_PLATES if int(one["_h"]) == 1 else Shapes.CORE_BRICKS
		if (one["_studs"] as Array).is_empty():
			if not tops or int(one["_h"]) != 1:
				return false
			tiles = Shapes.TOPS
		for entry: Array in tiles:
			if str(entry[2]) == part:
				return int(one["_h"]) in [1, 3]
		return false

	## The index of the part that is [param one]'s mirror, or -1.
	func _mirror_part(one: Dictionary) -> int:
		var want: Dictionary = {}
		for cell: Vector2i in one["_cells"]:
			want[reflect(cell)] = true
		# A wedge's mirror is its other hand.
		var edge: bool = bool(one.get("_edge", false))
		for m: int in made.size():
			var two: Dictionary = made[m]
			if (two.get("part") != one.get("part") and not (edge and bool(two.get("_edge", false)))) \
					or float(two["y"]) != float(one["y"]) \
					or not two.has("_cells") or (two["_cells"] as Array).size() != want.size():
				continue
			var same: bool = true
			for cell: Vector2i in two["_cells"]:
				same = same and want.has(cell)
			if same:
				return m
		return -1

	## Every plate the plan's parts stand in, Vector3i(x, y, z) -> index: by
	## the studs each covers in part, where it says.
	func _edge_cells() -> Dictionary:
		var by_cell: Dictionary = {}
		for n: int in made.size():
			var one: Dictionary = made[n]
			for cell: Vector2i in one.get("_covers", one.get("_cells", [])):
				for h: int in int(one.get("_h", 1)):
					by_cell[Vector3i(cell.x, int(round(float(one["y"]))) + h, cell.y)] = n
		return by_cell

	## An edge part where [param piece] meets the rest, side by side at the
	## same height, laid again as the plates or bricks of its studs, and its
	## mirror with it, so the two can be stitched by plain parts. A wedge or a
	## round part at the joint left a twenty-stud bunny's feet apart from it.
	## Whether one was. [param cells] is [method _edge_cells], mapped once for
	## every piece tried while nothing changes.
	func _unedge(piece: Array, main: Dictionary, cells: Dictionary = {}) -> bool:
		var by_cell: Dictionary = cells if not cells.is_empty() else _edge_cells()
		var mine: Dictionary = {}
		for n: int in piece:
			mine[n] = true
		for n: int in made.size():
			var one: Dictionary = made[n]
			if not bool(one.get("_edge", false)):
				continue
			var y: int = int(round(float(one["y"])))
			var touches: bool = false
			for cell: Vector2i in one["_covers"]:
				for step: Vector2i in Shapes.OUT:
					for h: int in int(one["_h"]):
						var other: int = int(by_cell.get(Vector3i(cell.x + step.x, y + h,
							cell.y + step.y), -1))
						if other >= 0 and (mine.has(n) and main.has(other)
								or main.has(n) and mine.has(other)):
							touches = true
			if not touches:
				continue
			var gone: Dictionary = {n: true}
			if not axis.is_empty():
				var want: Dictionary = {}
				for cell: Vector2i in one["_cells"]:
					want[reflect(cell)] = true
				for m: int in made.size():
					var two: Dictionary = made[m]
					if m != n and bool(two.get("_edge", false)) and int(round(float(two["y"]))) == y \
							and (two["_cells"] as Array).size() == want.size():
						var same: bool = true
						for cell: Vector2i in two["_cells"]:
							same = same and want.has(cell)
						if same:
							gone[m] = true
							break
			var added: Array = []
			for m: Variant in gone:
				var edge_part: Dictionary = made[m]
				var height: int = int(edge_part["_h"])
				var tiles: Array = Shapes.CORE_PLATES if height == 1 else Shapes.CORE_BRICKS
				# Its studs, and the plan's studs it covered in part.
				var studs: Dictionary = {}
				for cell: Vector2i in edge_part["_covers"]:
					var free: bool = true
					for h: int in height:
						var other: int = int(by_cell.get(Vector3i(cell.x, y + h, cell.y), -1))
						free = free and at(cell, y + h) >= 0 and (other < 0 or gone.has(other))
					if free or (edge_part["_cells"] as Array).has(cell):
						studs[cell] = true
				for part: Dictionary in _tile(studs, y, int(edge_part["color"]), tiles, {}, -1):
					added.append(_annotated(part, tiles, height, true))
			var kept: Array = []
			for m: int in made.size():
				if not gone.has(m):
					kept.append(made[m])
			made = kept + added
			return true
		return false

	## A brick of the rest beside a plate of [param piece] within its course,
	## laid again as three plates, and its mirror with it, so the two can be
	## stitched by a plate reaching across. Whether one was. The held-out car's
	## nose, past its front arch, was plates beside the body's middle brick
	## course with tiles over it: 14 parts held by nothing, and the run threw
	## the shaped body away.
	func _unbrick(piece: Array, main: Dictionary) -> bool:
		var plates: Dictionary = {}    ## Vector3i(x, y, z) -> a plate of the piece there
		for n: int in piece:
			var one: Dictionary = made[n]
			if not _plain(one) or int(one["_h"]) != 1:
				continue
			for cell: Vector2i in one["_cells"]:
				plates[Vector3i(cell.x, int(round(float(one["y"]))), cell.y)] = n
		for m: Variant in main:
			var two: Dictionary = made[m]
			# Not a side-stud brick: what it holds is laid already.
			if not _plain(two) or int(two["_h"]) != 3 or two.has("_holds"):
				continue
			var y: int = int(round(float(two["y"])))
			var beside: bool = false
			for cell: Vector2i in two["_cells"]:
				for step: Vector2i in Shapes.OUT:
					for h: int in 3:
						var n: int = int(plates.get(Vector3i(cell.x + step.x, y + h, cell.y + step.y), -1))
						beside = beside or n >= 0 and int((made[n] as Dictionary)["color"]) == int(two["color"])
			if not beside:
				continue
			var gone: Dictionary = {int(m): true}
			if not axis.is_empty():
				var want: Dictionary = {}
				for cell: Vector2i in two["_cells"]:
					want[reflect(cell)] = true
				for k: int in made.size():
					var other: Dictionary = made[k]
					if k == int(m) or other.get("part") != two.get("part") \
							or int(round(float(other["y"]))) != y \
							or (other["_cells"] as Array).size() != want.size():
						continue
					var same: bool = true
					for cell: Vector2i in other["_cells"]:
						same = same and want.has(cell)
					if same:
						gone[k] = true
						break
			var added: Array = []
			for k: Variant in gone:
				var brick: Dictionary = made[k]
				var cells: Dictionary = {}
				for cell: Vector2i in brick["_cells"]:
					cells[cell] = true
				for h: int in 3:
					for part: Dictionary in _tile(cells.duplicate(), y + h, int(brick["color"]),
							Shapes.CORE_PLATES, {}, -1):
						added.append(_annotated(part, Shapes.CORE_PLATES, 1, true))
			var kept: Array = []
			for k: int in made.size():
				if not gone.has(k):
					kept.append(made[k])
			made = kept + added
			return true
		return false

	## The plain parts of [param main] by the plates they stand in, at their
	## foot: Vector3i(x, y, z) -> index.
	func _plain_cells(main: Dictionary) -> Dictionary:
		var by_cell: Dictionary = {}
		for n: Variant in main:
			var one: Dictionary = made[n]
			if not _plain(one):
				continue
			for cell: Vector2i in one["_cells"]:
				by_cell[Vector3i(cell.x, int(round(float(one["y"]))), cell.y)] = n
		return by_cell

	## A part of [param piece] and one of the rest side by side: the same
	## height, colour and kind (studded plates or bricks), touching along an
	## edge. [] when there is none. [param cells] is [method _plain_cells],
	## mapped once for every piece tried. With [param colours], a pair of two
	## colours instead, and never one.
	func _pair(piece: Array, main: Dictionary, cells: Dictionary = {},
			colours: bool = false) -> Array:
		var by_cell: Dictionary = cells if not cells.is_empty() else _plain_cells(main)
		for n: int in piece:
			var one: Dictionary = made[n]
			if not _plain(one):
				continue
			var y: int = int(round(float(one["y"])))
			for cell: Vector2i in one["_cells"]:
				for step: Vector2i in Shapes.OUT:
					var other: int = int(by_cell.get(Vector3i(cell.x + step.x, y, cell.y + step.y), -1))
					if other < 0:
						continue
					var two: Dictionary = made[other]
					if int(two["_h"]) == int(one["_h"]) \
							and (int(two["color"]) == int(one["color"])) != colours:
						return [n, other]
		return []

	## A plate, a brick or a top tile: what can be laid again over the same
	## studs as other plates, bricks or tiles. Not a slope or a wedge, nor a
	## brick with studs on its side a shell hangs from: laid again across a
	## piece the shells cut off, a bunny's 1 x 2 with studs on its side came
	## back plain, and its shell lost 7 of its 10 parts.
	func _plain(one: Dictionary) -> bool:
		if not one.has("_cells") or (one["_cells"] as Array).is_empty() or bool(one.get("_slope", false)) \
				or bool(one.get("_fixed", false)) or one.has("_holds"):
			return false
		var studs: int = (one["_studs"] as Array).size()
		return studs == (one["_cells"] as Array).size() or (studs == 0 and bool(one.get("_top", false)))

	## The parts that are the mirror of a pair, or [].
	func _mirror_pair(pair: Array) -> Array:
		if axis.is_empty():
			return []
		var out: Array = []
		for n: int in pair:
			var one: Dictionary = made[n]
			var want: Dictionary = {}
			for cell: Vector2i in one["_cells"]:
				want[reflect(cell)] = true
			var hit: int = -1
			for m: int in made.size():
				var two: Dictionary = made[m]
				if two.get("part") != one.get("part") or float(two["y"]) != float(one["y"]) \
						or not two.has("_cells"):
					continue
				var cells: Array = two["_cells"]
				if cells.size() != want.size():
					continue
				var same: bool = true
				for cell: Vector2i in cells:
					if not want.has(cell):
						same = false
						break
				if same:
					hit = m
					break
			if hit < 0:
				return []
			out.append(hit)
		return out

	## Two side-by-side parts laid again over the same studs, the first part
	## laid the largest that covers a stud of each; with [param colours], two
	## of two colours, the one across laying fewest studs in the other's colour.
	func _across(one: Dictionary, two: Dictionary, colours: bool = false) -> Array:
		var height: int = int(one["_h"])
		var tiles: Array = Shapes.CORE_PLATES if height == 1 else Shapes.CORE_BRICKS
		# A top tile beside a plate nothing stands on: the two laid again as
		# tiles, one reaching across, so the top stays smooth. A tile holds
		# what is under both its ends as a plate does.
		var smooth_top: bool = height == 1 and (bool(one.get("_top", false)) \
			or bool(two.get("_top", false)))
		if smooth_top:
			var y_over: int = int(round(float(one["y"]))) + 1
			for other: Dictionary in made:
				if int(round(float(other["y"]))) != y_over:
					continue
				for cell: Vector2i in other.get("_base", []):
					if (one["_cells"] as Array).has(cell) or (two["_cells"] as Array).has(cell):
						smooth_top = false
			if smooth_top:
				tiles = Shapes.TOPS
		var cells: Dictionary = {}
		var first: Dictionary = {}
		for cell: Vector2i in one["_cells"]:
			cells[cell] = true
			first[cell] = true
		for cell: Vector2i in two["_cells"]:
			cells[cell] = true
		var y: int = int(round(float(one["y"])))
		var colour: int = int(one["color"])
		# Every part that reaches across, in the order tried: the largest first;
		# across two colours, the one that lays fewest studs in the other
		# side's colour first.
		var reaching: Array = []    ## [entry, corner, studs of the first, studs moved, order]
		for tile: Variant in _made_in(tiles, colour):
			var entry: Array = tile
			var wide: int = entry[0]
			var deep: int = entry[1]
			for key: Variant in cells:
				var corner: Vector2i = key
				var fits: bool = true
				var mine: int = 0
				for i: int in wide:
					for k: int in deep:
						var at_: Vector2i = corner + Vector2i(i, k)
						if not cells.has(at_):
							fits = false
						elif first.has(at_):
							mine += 1
				if not fits or mine == 0 or mine == wide * deep:
					continue
				reaching.append([entry, corner, mine, mini(mine, wide * deep - mine),
					reaching.size()])
		if colours:
			reaching.sort_custom(func(a: Array, b: Array) -> bool:
				if int(a[3]) != int(b[3]):
					return int(a[3]) < int(b[3])
				return int(a[4]) < int(b[4]))
		for one_way: Array in reaching:
			var entry: Array = one_way[0]
			var corner: Vector2i = one_way[1]
			var mine: int = one_way[2]
			var wide: int = entry[0]
			var deep: int = entry[1]
			var rest: Dictionary = cells.duplicate()
			for i: int in wide:
				for k: int in deep:
					rest.erase(corner + Vector2i(i, k))
			var laid: Dictionary = {}
			# Two colours: the part across in the colour of most of its studs,
			# the rest of each side in its own.
			var across_colour: int = colour if not colours or mine * 2 >= wide * deep \
				else int(two["color"])
			var out: Array = [_annotated({"part": entry[2], "color": across_colour,
				"x": corner.x, "y": y, "z": corner.y, "rot": entry[3]}, tiles, height,
				not smooth_top)]
			var rest_two: Dictionary = {}
			if colours:
				for key_: Variant in rest.keys():
					if not first.has(key_):
						rest_two[key_] = true
						rest.erase(key_)
			for part: Dictionary in _tile(rest, y, colour, tiles, laid, -1):
				out.append(_annotated(part, tiles, height, not smooth_top))
			if not rest_two.is_empty():
				for part: Dictionary in _tile(rest_two, y, int(two["color"]),
						_made_in(tiles, int(two["color"])), laid, -1):
					out.append(_annotated(part, tiles, height, not smooth_top))
			if smooth_top:
				for part: Dictionary in out:
					part["_top"] = true
			if rest.is_empty() and rest_two.is_empty():
				return out
		return []

	func _free(covered: Dictionary, cell: Vector2i, j: int) -> bool:
		var key := Vector3i(cell.x, j, cell.y)
		return not covered.has(key) and not taken.has(key)

	## Round parts and wedges where a layer's plan edge runs off the square,
	## each laid with its mirror; the studs they cover come out of [param
	## cells].
	##
	## A part goes where it brings the layer's outline nearer the shape's own
	## edge than the studs it replaces, measured stud by stud on a 4 x 4 grid
	## of what it covers against what the shape does (_gain). Its cut side
	## lies across a stud the edge cuts, inside the plan or out of it, and a
	## stud of the plan it covers only in part is its own. The first rule, a
	## wedge's cut side outside every stud of the plan and a fifth to four
	## fifths inside the shape, could not be met on a round plan, whose rim
	## studs are the ones the edge cuts: a cylinder of radius 5, a box with
	## 45 degree corners and an egg came out staircases with no wedge in them,
	## and four of five held-out designs looked stepped for it.
	##
	## Round parts first, then the rest, as a set rounds a body: in each pass
	## the part that brings the outline nearest first.
	func _wedged(cells: Dictionary, j: int, height: int = 1) -> Array:
		if cells.size() < 4 or library == null or not wedges or not sample.is_valid():
			return []
		var parts: Dictionary = Shapes.edge_parts(library, height)
		if parts.is_empty():
			return []
		var by_colour: Dictionary = {}
		for key: Variant in cells:
			var c: int = cells[key]
			if not by_colour.has(c):
				by_colour[c] = {}
			(by_colour[c] as Dictionary)[key] = true
		# Every stud of the shape at this plate, laid or not: a part's cut side
		# takes only studs still to be laid here, never one a brick or another
		# colour has.
		var solid: Dictionary = {}
		for key: Variant in columns:
			for n: int in height:
				if at(key, j + n) >= 0:
					solid[key] = true
		# And every stud a slope stands over at this plate: an inverted slope
		# under an overhang reaches out past the shape, and a wedge cut into
		# it there overlapped it.
		for key: Variant in taken:
			var where: Vector3i = key
			if where.y >= j and where.y < j + height:
				solid[Vector2i(where.x, where.z)] = true
		# The studs either side of the plan's edge: the only ones a part may
		# cover in part.
		var edge: Dictionary = {}
		for key: Variant in solid:
			for dx: int in range(-1, 2):
				for dz: int in range(-1, 2):
					var beside: Vector2i = (key as Vector2i) + Vector2i(dx, dz)
					if not solid.has(beside):
						edge[beside] = true
						edge[key] = true
		var state := {"solid": solid, "edge": edge, "built": {}, "claimed": {}, "truth": {},
			"j": j, "height": height}
		var out: Array = []
		var names: Array = parts.keys()
		names.sort()
		var spots: Array = edge.keys()
		spots.sort()
		for c: Variant in by_colour:
			# Glass is laid square: no wedge or round part was made in it.
			if Shapes.is_glass(library, int(c)):
				continue
			var wanted: Dictionary = by_colour[c]
			for round_pass: bool in [true, false]:
				var tried: Array = []
				for named: String in names:
					var part: Array = parts[named]
					if bool(part[5]) != round_pass:
						continue
					for key: Variant in spots:
						var corner: Vector2i = (key as Vector2i) - (part[4] as Vector2i)
						var gain: int = _gain(part, corner, wanted, state)
						if gain >= MIN_GAIN:
							tried.append([gain, (part[2] as Dictionary).size(), named, corner])
				tried.sort_custom(func(a: Array, b: Array) -> bool:
					if a[0] != b[0]:
						return a[0] > b[0]
					if a[1] != b[1]:
						return a[1] > b[1]
					if a[2] != b[2]:
						return a[2] < b[2]
					return a[3].x < b[3].x or a[3].x == b[3].x and a[3].y < b[3].y)
				for one: Array in tried:
					var named: String = one[2]
					var corner: Vector2i = one[3]
					var part: Array = parts[named]
					if _gain(part, corner, wanted, state) < MIN_GAIN:
						continue
					var family: Array = [[named, corner]]
					if not axis.is_empty():
						var twin: Array = _twin(parts, named, corner)
						if twin.is_empty():
							continue
						if twin[0] != named or twin[1] != corner:
							if _gain(parts[twin[0]], twin[1], wanted, state) < MIN_GAIN \
									or _overlap(part, corner, parts[twin[0]], twin[1]):
								continue
							family.append(twin)
					for member: Array in family:
						var studs: Array[Vector2i] = _take_edge(parts[member[0]], member[1],
							wanted, cells, state)
						var placed: Dictionary = Patterns._placement(member[0], [], member[1], j,
							int(c))
						var whole: Array[Vector2i] = []
						var covers: Dictionary = (parts[member[0]] as Array)[3]
						for key: Variant in covers:
							if int(covers[key]) == Shapes.FULL:
								whole.append((member[1] as Vector2i) + (key as Vector2i))
						placed["_cells"] = studs
						placed["_h"] = height
						placed["_studs"] = studs
						placed["_base"] = whole
						placed["_slope"] = true
						placed["_edge"] = true
						var touched: Array[Vector2i] = []
						for key: Variant in covers:
							touched.append((member[1] as Vector2i) + (key as Vector2i))
						placed["_covers"] = touched
						out.append(placed)
		return out

	## Less than a quarter of a stud nearer the shape is no reason to lay a
	## part.
	const MIN_GAIN := 4

	## How much nearer the shape's edge the outline comes with [param part]
	## at [param corner] than without it, in sixteenths of a stud; -1 where it
	## cannot go: a stud of it not still to be laid here, a stud it covers in
	## part away from the edge or laid by something else, or anything it
	## covers covered already.
	func _gain(part: Array, corner: Vector2i, wanted: Dictionary, state: Dictionary) -> int:
		for key: Variant in part[2]:
			if not wanted.has(corner + (key as Vector2i)):
				return -1
		var solid: Dictionary = state["solid"]
		var edge: Dictionary = state["edge"]
		var built: Dictionary = state["built"]
		var claimed: Dictionary = state["claimed"]
		var covers: Dictionary = part[3]
		var gain: int = 0
		var slanted: bool = false
		for key: Variant in covers:
			var cell: Vector2i = key
			var here: int = covers[cell]
			var at_: Vector2i = corner + cell
			var mine: bool = wanted.has(at_)
			if mine:
				if here != Shapes.FULL and not edge.has(at_):
					return -1
				if not (part[2] as Dictionary).has(cell) and not _may_cut(at_, state):
					return -1
			elif solid.has(at_):
				if not claimed.has(at_):
					return -1
			elif not edge.has(at_):
				return -1
			var already: int = int(built.get(at_, 0))
			if already & here:
				return -1
			var truth: int = _truth(at_, state)
			slanted = slanted or not Shapes.square(truth)
			var before: int = Shapes.FULL if mine else already
			var after: int = here | already
			gain += Shapes.ones(before ^ truth) - Shapes.ones(after ^ truth)
		# An edge that runs square across every stud it covers is the studs'
		# own: a ramp's falls each cross a stud half way, and wedges laid there
		# sawed a straight edge into teeth.
		return gain if slanted else -1

	## What the shape covers of the stud at [param cell], in the middle of the
	## layer, as 16 bits.
	func _truth(cell: Vector2i, state: Dictionary) -> int:
		var known: Dictionary = state["truth"]
		if known.has(cell):
			return known[cell]
		var y: float = float(state["j"]) + float(state["height"]) / 2.0
		var bits: int = 0
		for v: int in 4:
			for u: int in 4:
				if sample.call(cell.x + (u + 0.5) / 4.0, y, cell.y + (v + 0.5) / 4.0):
					bits |= 1 << (v * 4 + u)
		known[cell] = bits
		return bits

	## Lay [param part]: what it covers is built, and every stud it covers,
	## whole or in part, is no longer to be laid. The studs on its top.
	func _take_edge(part: Array, corner: Vector2i, wanted: Dictionary, cells: Dictionary,
			state: Dictionary) -> Array[Vector2i]:
		var built: Dictionary = state["built"]
		var claimed: Dictionary = state["claimed"]
		var covers: Dictionary = part[3]
		var j: int = state["j"]
		for key: Variant in covers:
			var at_: Vector2i = corner + (key as Vector2i)
			built[at_] = int(built.get(at_, 0)) | int(covers[key])
			claimed[at_] = true
			if wanted.has(at_) and not (part[2] as Dictionary).has(key):
				for n: int in int(state["height"]):
					cut_in[Vector3i(at_.x, j + n, at_.y)] = true
			wanted.erase(at_)
			cells.erase(at_)
		var studs: Array[Vector2i] = []
		for key: Variant in part[2]:
			studs.append(corner + (key as Vector2i))
		return studs

	## Plates of the shape a part covers without a stud on them: what is over
	## or under one there is not held through it. Vector3i(x, j, z) -> true.
	var cut_in: Dictionary = {}

	## Whether a stud of the plan may be covered without a stud on it: where
	## the shape ends over it or under it, or the stud under it is not held
	## through either, so no column of the shape is cut through the middle.
	## Cut anywhere, a twenty-stud bunny's legs were wedges over wedges
	## that met at no stud, and it stood on its feet with its body beside them.
	func _may_cut(cell: Vector2i, state: Dictionary) -> bool:
		var j: int = state["j"]
		var below := Vector3i(cell.x, j - 1, cell.y)
		return at(cell, j - 1) < 0 or at(cell, j + int(state["height"])) < 0 \
			or cut_in.has(below) or taken.has(below)

	## Do two parts cover any of the same bits?
	func _overlap(one: Array, here: Vector2i, two: Array, there: Vector2i) -> bool:
		var covers: Dictionary = two[3]
		for key: Variant in one[3]:
			var other: Vector2i = here + (key as Vector2i) - there
			if covers.has(other) and int(covers[other]) & int((one[3] as Dictionary)[key]):
				return true
		return false

	## The wedge that is this one's mirror across the plane, as [name, corner]:
	## the same box reflected, its plan — what the part covers, at half a stud
	## — the reflection of this one's. By studs alone a 2 x 3 wing found
	## itself: its left hand turned half round has the same three studs as its
	## right hand, the cut running the other way, and the check called the
	## pair lopsided.
	func _twin(shapes: Dictionary, named: String, corner: Vector2i) -> Array:
		var shape: Array = shapes[named]
		var across_: int = int(shape[0])
		var deep: int = int(shape[1])
		var far: Vector2i = corner + Vector2i(across_ - 1, deep - 1)
		var one: Vector2i = reflect(corner)
		var two: Vector2i = reflect(far)
		var low := Vector2i(mini(one.x, two.x), mini(one.y, two.y))
		var mirrored: String = Shapes.wedge_plan(library, named, axis)
		if mirrored.is_empty():
			return []
		for candidate: Variant in shapes:
			var name: String = candidate
			var other: Array = shapes[name]
			if int(other[0]) != across_ or int(other[1]) != deep:
				continue
			if Shapes.wedge_plan(library, name, "") == mirrored:
				return [name, low]
		return []

	## The parts of [param given] a layer in [param colour] may be laid in: all
	## of them, but in glass only those LEGO made in it, or whose glass brick
	## it made (Shapes.GLASS_SWAP, swapped as the shape is placed). A 2 x 4
	## plate in trans-black was never moulded.
	func _made_in(given: Array, colour: int) -> Array:
		if not Shapes.is_glass(library, colour):
			return given
		var out: Array = []
		var single: bool = false
		for entry: Variant in given:
			if Shapes.made_in_glass(library, str((entry as Array)[2]), colour):
				out.append(entry)
				single = single or (int((entry as Array)[0]) == 1 and int((entry as Array)[1]) == 1)
		# A stud at a time at the least, or the shape loses studs.
		if not single:
			for entry: Variant in given:
				if int((entry as Array)[0]) == 1 and int((entry as Array)[1]) == 1:
					out.append(entry)
		return out

	## Whether the LEGO Group sells [param part] in any of [member sold_in], by
	## Rebrickable's elements, under the number LDraw gives the part today;
	## true when none are asked.
	func _sold(part: String) -> bool:
		if sold_in.is_empty() or library == null:
			return true
		if not _sold_somewhere.has(part):
			var now: String = Shapes.current(library, part)
			var found: bool = false
			for code: int in sold_in:
				if not library.element_for(now, code).is_empty():
					found = true
					break
			_sold_somewhere[part] = found
		return bool(_sold_somewhere[part])

	## One layer of the core: by colour, a strip across the middle tying the
	## two halves, one half laid and the other its mirror.
	func _layer(cells: Dictionary, j: int, given: Array, course: int) -> Array:
		if bond and course >= 0:
			if axis.is_empty():
				return _bonded(cells, j, given, course)
			# A shape that is its own mirror keeps its strip across the middle
			# and its halves mirrored, whose joints move from course to course,
			# but its hidden bricks in the core's colour: laid as the rest are, a
			# plain sphere's seams bridged fell from 67% to 57%.
			var shown: Dictionary = {}
			for key: Variant in cells:
				var c: int = shown_colour(key, j, 3)
				shown[key] = c if c >= 0 else (core_colour if c == ANY else int(cells[key]))
			cells = shown
		var out: Array = []
		var by_colour: Dictionary = {}
		for key: Variant in cells:
			var c: int = cells[key]
			if not by_colour.has(c):
				by_colour[c] = {}
			(by_colour[c] as Dictionary)[key] = true
		# Plates in one layer turned the other way from the layer under them,
		# and tried from the other side: laid the same way every layer, the
		# outside row of a bird's body came out as strips along it, every
		# layer, tied to nothing inside and reported floating.
		if course < 0:
			given = _alternate(given, j)
		for c: Variant in by_colour:
			var tiles: Array = _made_in(given, int(c))
			var wanted: Dictionary = _ordered(by_colour[c], j)
			var laid: Dictionary = {}
			if axis.is_empty():
				out.append_array(_tile(wanted, j, int(c), tiles, laid, course))
				continue
			var got: Array = []
			var middle: Vector2i = spine(j)
			var strip: Dictionary = {}
			var half: Dictionary = {}
			for key: Variant in wanted:
				var cell: Vector2i = key
				var a: int = across(cell)
				if a >= middle.x and a <= middle.y:
					strip[cell] = true
				elif a * 2 < sum:
					half[cell] = true
			var width: int = middle.y - middle.x + 1
			var spanning: Array = []
			for tile: Variant in tiles:
				var one: Array = tile
				if (int(one[1]) if axis == "z" else int(one[0])) == width:
					spanning.append(one)
			if not strip.is_empty():
				got.append_array(_tile(strip, j, int(c), spanning, laid, course))
				# Too narrow for its own width, the strip of the plate over or
				# under: a fighter's nose two studs across, on the plates whose
				# strip is four, was 1 x 1s a stud at a time, tied along it by
				# nothing, and came apart row by row.
				var other: Vector2i = spine(j + 1)
				if other != middle and not strip.is_empty():
					var inner: Dictionary = {}
					for key: Variant in strip:
						if across(key) >= other.x and across(key) <= other.y:
							inner[key] = true
					var narrow: Array = []
					for tile: Variant in tiles:
						var one: Array = tile
						if (int(one[1]) if axis == "z" else int(one[0])) == other.y - other.x + 1:
							narrow.append(one)
					if not inner.is_empty():
						got.append_array(_tile(_ordered(inner, j), j, int(c), narrow, laid, course))
						for key: Variant in inner:
							if laid.has(key):
								strip.erase(key)
				# What the strip could not take, one stud at a time, in pairs.
				for key: Variant in strip.keys():
					var cell: Vector2i = key
					if not strip.has(cell) or across(cell) * 2 > sum:
						continue
					var single: Dictionary = {cell: true}
					var side: Array = _tile(single, j, int(c), tiles, laid, course)
					got.append_array(side)
					if reflect(cell) != cell:
						for one: Dictionary in side:
							got.append(_reflected(one, tiles))
					strip.erase(cell)
					strip.erase(reflect(cell))
			var left: Array = _tile(_ordered(half, j), j, int(c), tiles, laid, course)
			got.append_array(left)
			for one: Dictionary in left:
				got.append(_reflected(one, tiles))
			# A reflection is laid only where its studs are free: a side's
			# studs turned out on one flank and not the other left the plate
			# lopsided, and a reflected plate stood in a side-stud brick.
			var free: Dictionary = by_colour[c]
			var claimed: Dictionary = {}
			for one: Dictionary in got:
				var studs: Array[Vector2i] = _studs_of(one, tiles)
				var fits: bool = true
				for cell: Vector2i in studs:
					fits = fits and free.has(cell) and not claimed.has(cell)
				if not fits:
					continue
				for cell: Vector2i in studs:
					claimed[cell] = true
				out.append(one)
			var rest: Dictionary = {}
			for cell: Variant in free:
				if not claimed.has(cell):
					rest[cell] = true
			if not rest.is_empty():
				out.append_array(_tile(_ordered(rest, j), j, int(c), tiles, {}, course))
		return out

	## A course of the core's bricks as a builder lays it ([member bond]):
	## each stud, those with the fewest free beside them first, under the
	## first brick that covers it in one colour where it shows. What is hidden
	## is any colour, and a brick nothing of which shows is the core's. Laid by
	## the colours measured, the plates the measuring coloured from the
	## surface two studs in split a course where nothing of it shows: a cow's
	## core came out in 1 x 1s at every change, and three plates where a
	## brick would do.
	func _bonded(cells: Dictionary, j: int, given: Array, course: int) -> Array:
		var tiles: Array = Patterns._corners_turn(given, course)
		var wanted: Dictionary = {}
		for key: Variant in cells:
			var shown: int = shown_colour(key, j, 3)
			wanted[key] = int(cells[key]) if shown == MIXED else shown
		var order: Array = _ordered(wanted, j).keys()
		var rank: Dictionary = {}
		for n: int in order.size():
			var cell: Vector2i = order[n]
			var free: int = 0
			for step: Vector2i in Shapes.OUT:
				if wanted.has(cell + step):
					free += 1
			rank[cell] = free * order.size() + n
		order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return int(rank[a]) < int(rank[b]))
		var out: Array = []
		for key: Variant in order:
			var cell: Vector2i = key
			if not wanted.has(cell):
				continue
			var placed: bool = false
			for tile: Variant in tiles:
				var one: Array = tile
				var wide: int = one[0]
				var deep: int = one[1]
				for dx: int in wide:
					for dz: int in deep:
						var corner: Vector2i = cell - Vector2i(dx, dz)
						var colour: int = _fits_any(wanted, corner, wide, deep)
						if colour == MIXED:
							continue
						colour = colour if colour >= 0 else core_colour
						if wide * deep > 1 and not _made(str(one[2]), colour):
							continue
						for i: int in wide:
							for k: int in deep:
								wanted.erase(corner + Vector2i(i, k))
						out.append({"part": one[2], "color": colour, "x": corner.x, "y": j,
							"z": corner.y, "rot": one[3]})
						placed = true
						break
					if placed:
						break
				if placed:
					break
		return out

	## Whether the LEGO Group sells [param part] in [param colour], by
	## Rebrickable's elements, when colours are asked ([member sold_in]). A
	## longer brick is not made in every colour its studs are: merged into a
	## 1 x 8 brick, an avocado's Bright Green flesh came out Green, the
	## nearest colour that brick is sold in.
	func _made(part: String, colour: int) -> bool:
		if sold_in.is_empty() or library == null:
			return true
		var key: String = "%s/%d" % [part, colour]
		if not _made_in_colour.has(key):
			_made_in_colour[key] = not library.element_for(Shapes.current(library, part), colour).is_empty()
		return bool(_made_in_colour[key])

	## Whether a part [param wide] by [param deep] at [param corner] fits the
	## studs [param wanted] still has, and in what colour: [constant MIXED]
	## where it does not fit, or would show two.
	func _fits_any(wanted: Dictionary, corner: Vector2i, wide: int, deep: int) -> int:
		var colour: int = ANY
		for i: int in wide:
			for k: int in deep:
				var c: Variant = wanted.get(corner + Vector2i(i, k))
				if c == null:
					return MIXED
				if int(c) == ANY:
					continue
				if colour == ANY:
					colour = int(c)
				elif int(c) != colour:
					return MIXED
		return colour

	## The core's plain plates and bricks merged, once laid and stitched
	## ([member bond]): two side by side in a course whose studs together are
	## a part we lay, and three plates of one footprint stacked, a brick. Each
	## in one colour where it shows. A merge only joins: whatever held either
	## part holds the one, so the plan is in no more pieces. How many parts
	## it saved.
	func merge() -> int:
		var before: int = made.size()
		var plates: Dictionary = _sizes(Shapes.CORE_PLATES)
		var bricks: Dictionary = _sizes(Shapes.CORE_BRICKS)
		var changed: bool = true
		var passes: int = 0
		while changed and passes < 6:
			if stop.is_valid() and bool(stop.call()):
				break
			changed = false
			passes += 1
			# Side by side.
			var at_: Dictionary = {}    ## Vector3i(x, y, z) of a corner stud -> index
			var plain: Dictionary = {}    ## index -> Rect2i
			for n: int in made.size():
				var rect: Rect2i = _plain_rect(made[n], plates, bricks)
				if rect.has_area():
					plain[n] = rect
					at_[Vector3i(rect.position.x, int(made[n]["y"]), rect.position.y)] = n
			var gone: Dictionary = {}
			var touched: Dictionary = {}
			for key: Variant in plain:
				var n: int = key
				if touched.has(n):
					continue
				var one: Dictionary = made[n]
				var rect: Rect2i = plain[n]
				var h: int = int(one["_h"])
				# The part beside it along x, then along z, whose side is its side.
				for along: Vector2i in [Vector2i(rect.size.x, 0), Vector2i(0, rect.size.y)]:
					var m: int = int(at_.get(Vector3i(rect.position.x + along.x, int(one["y"]),
						rect.position.y + along.y), -1))
					if m < 0 or touched.has(m) or not plain.has(m):
						continue
					var other: Dictionary = made[m]
					var r2: Rect2i = plain[m]
					if int(other["_h"]) != h or (along.x > 0 and r2.size.y != rect.size.y) \
							or (along.y > 0 and r2.size.x != rect.size.x):
						continue
					var whole: Rect2i = rect.merge(r2)
					var table: Dictionary = bricks if h == 3 else plates
					if not table.has(whole.size):
						continue
					var colour: int = _merged_colour([one, other])
					if colour == MIXED or not _made(str(table[whole.size][2]), colour):
						continue
					made[n] = _merged(table[whole.size], whole, int(one["y"]), colour, h)
					gone[m] = true
					touched[n] = true
					touched[m] = true
					changed = true
					break
			if not gone.is_empty():
				var kept: Array = []
				for n: int in made.size():
					if not gone.has(n):
						kept.append(made[n])
				made = kept
			# Three plates of one footprint stacked: a brick.
			var stack: Dictionary = {}    ## Vector3i(x, y, z) of a plate's corner -> index
			for n: int in made.size():
				var rect: Rect2i = _plain_rect(made[n], plates, bricks)
				if rect.has_area() and int(made[n]["_h"]) == 1 and bricks.has(rect.size):
					stack[Vector3i(rect.position.x, int(made[n]["y"]), rect.position.y)] = n
			gone = {}
			for key: Variant in stack:
				var corner: Vector3i = key
				var n: int = stack[key]
				if gone.has(n):
					continue
				var mid: int = int(stack.get(corner + Vector3i(0, 1, 0), -1))
				var top: int = int(stack.get(corner + Vector3i(0, 2, 0), -1))
				if mid < 0 or top < 0 or gone.has(mid) or gone.has(top):
					continue
				var rect: Rect2i = _plain_rect(made[n], plates, bricks)
				if _plain_rect(made[mid], plates, bricks) != rect \
						or _plain_rect(made[top], plates, bricks) != rect:
					continue
				var colour: int = _merged_colour([made[n], made[mid], made[top]])
				if colour == MIXED or not _made(str(bricks[rect.size][2]), colour):
					continue
				made[n] = _merged(bricks[rect.size], rect, corner.y, colour, 3)
				gone[mid] = true
				gone[top] = true
				changed = true
			if not gone.is_empty():
				var kept: Array = []
				for n: int in made.size():
					if not gone.has(n):
						kept.append(made[n])
				made = kept
		return before - made.size()

	## A table of core parts by the studs they cover, across and along.
	static func _sizes(table: Array) -> Dictionary:
		var out: Dictionary = {}
		for entry: Variant in table:
			var one: Array = entry
			var size := Vector2i(int(one[0]), int(one[1]))
			if not out.has(size):
				out[size] = one
		return out

	## The studs a plain plate or brick of the core covers, or an empty
	## rectangle for anything else: a top's tile, a panel, a slope, a part
	## turned out, dressing.
	func _plain_rect(one: Dictionary, plates: Dictionary, bricks: Dictionary) -> Rect2i:
		if one.has("panel") or bool(one.get("_top", false)) or bool(one.get("dressing", false)) \
				or bool(one.get("_fixed", false)) or not one.has("_cells") or int(one.get("rot", 0)) > 1:
			return Rect2i()
		var h: int = int(one.get("_h", 0))
		var table: Dictionary = bricks if h == 3 else plates if h == 1 else {}
		var cells: Array = one["_cells"]
		if cells.is_empty() or (one.get("_studs", []) as Array).size() != cells.size():
			return Rect2i()
		var low: Vector2i = cells[0]
		var high: Vector2i = cells[0]
		for cell: Vector2i in cells:
			low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
			high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
		var rect := Rect2i(low, high - low + Vector2i.ONE)
		if rect.get_area() != cells.size() or not table.has(rect.size):
			return Rect2i()
		var entry: Array = table[rect.size]
		if str(entry[2]) != str(one["part"]) or int(entry[3]) != int(one["rot"]) \
				or Vector2i(int(one["x"]), int(one["z"])) != low:
			return Rect2i()
		return rect

	## The colour parts merged into one would be: the colour of what shows
	## of them, [constant MIXED] where they show two, the first's where none
	## shows.
	func _merged_colour(parts: Array) -> int:
		var out: int = ANY
		for one: Dictionary in parts:
			var y: int = int(one["y"])
			var shown: bool = false
			for cell: Vector2i in one["_cells"]:
				for n: int in int(one["_h"]):
					shown = shown or shows(cell, y + n)
			if not shown:
				continue
			if out == ANY:
				out = int(one["color"])
			elif int(one["color"]) != out:
				return MIXED
		return out if out != ANY else int((parts[0] as Dictionary)["color"])

	func _merged(entry: Array, rect: Rect2i, y: int, colour: int, h: int) -> Dictionary:
		var one: Dictionary = {"part": entry[2], "color": colour, "x": rect.position.x, "y": y,
			"z": rect.position.y, "rot": entry[3]}
		return _annotated(one, Shapes.CORE_BRICKS if h == 3 else Shapes.CORE_PLATES, h, true)

	## The studs a core part laid by [method _tile] covers.
	func _studs_of(one: Dictionary, tiles: Array) -> Array[Vector2i]:
		var size := Vector2i(1, 1)
		for tile: Variant in tiles:
			var entry: Array = tile
			if str(entry[2]) == str(one["part"]) and int(entry[3]) == int(one["rot"]):
				size = Vector2i(int(entry[0]), int(entry[1]))
				break
		var out: Array[Vector2i] = []
		for dx: int in size.x:
			for dz: int in size.y:
				out.append(Vector2i(int(one["x"]) + dx, int(one["z"]) + dz))
		return out

	## A layer's studs laid in parts: bricks in a bond as a wall is
	## (Patterns._tile), plates and tiles stud by stud, the stud with the
	## fewest free neighbours first and the largest part that covers it with
	## them. Largest-first over the whole layer took the open ground and left
	## the hemmed-in studs to 1 x 1s, a column of them up the edge of every
	## body, tied to nothing.
	func _tile(wanted: Dictionary, j: int, colour: int, tiles: Array, laid: Dictionary,
			course: int) -> Array:
		# In glass, the parts made in it, whichever way here was reached.
		tiles = _made_in(tiles, colour)
		if course >= 0:
			return Patterns._tile(wanted, j, colour, tiles, {}, laid, course)
		var made_here: Array = []
		var order: Array = wanted.keys()
		var free_beside := func(cell: Vector2i) -> int:
			var n: int = 0
			for step: Vector2i in Shapes.OUT:
				if wanted.has(cell + step):
					n += 1
			return n
		var counts: Dictionary = {}
		for key: Variant in order:
			counts[key] = free_beside.call(key)
		order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return int(counts[a]) < int(counts[b]))
		for key: Variant in order:
			var cell: Vector2i = key
			if not wanted.has(cell):
				continue
			var placed: bool = false
			for tile: Variant in tiles:
				var one: Array = tile
				var wide: int = one[0]
				var deep: int = one[1]
				for dx: int in wide:
					for dz: int in deep:
						var corner: Vector2i = cell - Vector2i(dx, dz)
						var fits: bool = true
						for i: int in wide:
							for k: int in deep:
								if not wanted.has(corner + Vector2i(i, k)):
									fits = false
									break
							if not fits:
								break
						if not fits:
							continue
						for i: int in wide:
							for k: int in deep:
								wanted.erase(corner + Vector2i(i, k))
								laid[corner + Vector2i(i, k)] = true
						made_here.append({"part": one[2], "color": colour, "x": corner.x,
							"y": j, "z": corner.y, "rot": one[3]})
						placed = true
						break
					if placed:
						break
				if placed:
					break
		return made_here

	## Bricks with studs on one side for the outside row of a straight side
	## in course [param k]: studs whose way out is clear for this course and
	## the next, and whose stud over them is part of the side too, so the
	## tile on them lies flat over both. In runs along the side, 1 x 4, 1 x 2
	## and 1 x 1 (30414, 11211, 87087); one side of a mirror and the other its
	## reflection. They come out of [param bricks]; the core's next course
	## ties them in.
	func _panels(bricks: Dictionary, j: int, k: int) -> Array:
		var above: Dictionary = full(k + 1)
		var facing_of: Dictionary = {}
		for key: Variant in bricks:
			var cell: Vector2i = key
			if not above.has(cell) or bricks[cell] != at(cell, j + 3) \
					or Shapes.is_glass(library, int(bricks[cell])):
				continue
			var found := Vector2i.ZERO
			var count: int = 0
			for step: Vector2i in Shapes.OUT:
				var clear: bool = true
				for n: int in 6:
					if at(cell + step, j + n) >= 0 or taken.has(Vector3i(cell.x + step.x,
							j + n, cell.y + step.y)):
						clear = false
						break
				if clear:
					found = step
					count += 1
			if count == 1:
				facing_of[cell] = found
		var out: Array = []
		var done: Dictionary = {}
		var cells: Array = facing_of.keys()
		cells.sort()
		for key: Variant in cells:
			var cell: Vector2i = key
			if done.has(cell):
				continue
			if not axis.is_empty() and across(cell) * 2 > sum:
				continue
			var facing: Vector2i = facing_of[cell]
			var along := Vector2i(absi(facing.y), absi(facing.x))
			# The run this stud starts, along the side, on this side of the
			# plane or across it.
			var run: Array[Vector2i] = []
			var at_: Vector2i = cell
			while facing_of.get(at_) == facing and not done.has(at_) \
					and bricks.get(at_) == bricks[cell] \
					and (axis.is_empty() or across(at_) * 2 <= sum):
				run.append(at_)
				at_ += along
			var placed: int = 0
			while placed < run.size():
				var left: int = run.size() - placed
				var long: int = 4 if left >= 4 else (2 if left >= 2 else 1)
				# A stud on the plane stands alone, its own mirror.
				if not axis.is_empty():
					for n: int in long:
						if across(run[placed + n]) * 2 == sum:
							long = n if n > 0 else 1
							break
				var part: String = {4: "30414", 2: "11211", 1: "87087"}[long]
				var piece: Array[Vector2i] = []
				for n: int in long:
					piece.append(run[placed + n])
				out.append(_panel_brick(part, piece, facing, j, int(bricks[cell])))
				var twin: Array[Vector2i] = []
				if not axis.is_empty():
					for one: Vector2i in piece:
						twin.append(reflect(one))
				if not twin.is_empty() and not twin.has(piece[0]):
					var flipped: Vector2i = Vector2i(facing.x, -facing.y) if axis == "z" \
						else Vector2i(-facing.x, facing.y)
					out.append(_panel_brick(part, twin, flipped, j, int(bricks[cell])))
					for one: Vector2i in twin:
						done[one] = true
				for one: Vector2i in piece:
					done[one] = true
				placed += long
		for one: Dictionary in out:
			for cell: Vector2i in one["_cells"]:
				bricks.erase(cell)
		return out

	func _panel_brick(part: String, cells: Array[Vector2i], facing: Vector2i, j: int,
			colour: int) -> Dictionary:
		var low := Vector2i(1 << 30, 1 << 30)
		for one: Vector2i in cells:
			low = Vector2i(mini(low.x, one.x), mini(low.y, one.y))
		var way: String = {Vector2i(0, 1): "+z", Vector2i(1, 0): "+x", Vector2i(0, -1): "-z",
			Vector2i(-1, 0): "-x"}[facing]
		return {"part": part, "color": colour, "x": low.x, "y": j, "z": low.y,
			"rot": 0 if facing.x == 0 else 1, "panel": way, "_cells": cells, "_h": 3,
			"_studs": cells, "_base": cells}

	## [param cells] in the order a layer's parts are tried at: along x on
	## even plates, along z on odd ones.
	func _ordered(cells: Dictionary, j: int) -> Dictionary:
		var keys: Array = cells.keys()
		if j % 2 == 0:
			keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return a.x < b.x or a.x == b.x and a.y < b.y)
		else:
			keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return a.y < b.y or a.y == b.y and a.x < b.x)
		var out: Dictionary = {}
		for key: Variant in keys:
			out[key] = cells[key]
		return out

	## The plates in the order to try them on plate [param j]: each part
	## turned across before along on odd plates, as a bonded course turns
	## its corners.
	func _alternate(tiles: Array, j: int) -> Array:
		if j % 2 == 0:
			return tiles
		return Patterns._corners_turn(tiles, 1)

	## A core part reflected across the plane: its far corner, mirrored.
	func _reflected(one: Dictionary, tiles: Array) -> Dictionary:
		var size := Vector2i(1, 1)
		for tile: Variant in tiles:
			var entry: Array = tile
			if str(entry[2]) == str(one["part"]) and int(entry[3]) == int(one["rot"]):
				size = Vector2i(int(entry[0]), int(entry[1]))
				break
		var twin: Dictionary = one.duplicate()
		if axis == "z":
			twin["z"] = sum - int(one["z"]) - size.y + 1
		else:
			twin["x"] = sum - int(one["x"]) - size.x + 1
		return twin
