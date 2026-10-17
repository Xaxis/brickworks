## A sculpt, a scan or any 3D model, laid in LEGO at a size the person picks.
##
## What the CAD programs offer for this is a voxel stack: a stud on every
## cell and every curve a staircase. Here the mesh is only measured — which
## studs and plates it fills, what colour its surface is at each, and
## whether the surface there is a curve or a flat facet — and then laid by
## the brickifier the assistant lays a car or a hull with (Shapes): big
## bricks inside, plates where the surface passes through a course, slopes
## and curved slopes where it falls away, inverted ones under an overhang,
## wedges along a diagonal edge, tiles on top, and bricks with studs on
## their side carrying tiles on a flat flank. Then it is checked as
## check_design checks a design, and mended until it passes in one piece.
##
## Everything here is pure: it reads the mesh and the part library and
## changes neither, so it can run on a worker (BrickifyDialog does, so the
## page keeps drawing while a forty-stud model is worked out).
class_name Brickify
extends RefCounted

## Columns sampled a stud: Shapes asks whether a wedge's cut side follows
## the surface at thirds of a stud.
const FINE := 3
const PLATES := 2.5
const LEAST_STUDS := 6
const MOST_STUDS := 64
## Which way the file's up is, each turned to stand on the baseplate.
const UPS: PackedStringArray = ["+Y", "+Z", "-Z", "+X", "-X", "-Y"]
## What a hollowed model keeps: walls two studs thick, and three plates
## under and over its hollow, so its ceiling is plates bonded across.
const WALL_STUDS := 2
const WALL_PLATES := 3
## The colours a model is laid in: solid colours LEGO makes now, in
## hundreds of sets each, so the slopes and bricks it asks for exist in
## them. Not the mosaic's palette, whose transparent and pearl colours are
## for a picture of plates: a red cube came out in trans-red.
const PALETTE: Array[int] = [15, 71, 72, 0, 4, 320, 5, 29, 353, 26, 25, 484, 191, 14, 226,
	27, 326, 10, 2, 288, 330, 378, 3, 323, 322, 321, 212, 73, 1, 272, 379, 30, 31, 85,
	19, 28, 84, 92, 78, 70, 308]
## A colour sample every this many studs along a triangle's longest side.
const SAMPLE_STUDS := 0.35
## A surface with more of the model than this in front of it, studs, is one
## the build hides (a mouth's inside, a second skin), and colours nothing.
const HIDDEN_STUDS := 1.5
## And one with the model's own inside this far in front of it is buried in
## another part of it, and colours nothing.
const BURIED_STUDS := 0.25
## How flat a facet has to be to take straight slopes: its corners' normals
## within this of its own.
const FLAT_DEGREES := 4.0
## What joining a piece apart costs, per step of the way: a stud across or a
## plate up or down through empty air, or along the model's own surface,
## where it is thinner than a stud. A path costing more than [method
## _join_reach] allows is not a join but a new part of the model.
const JOIN_STUD := 5
const JOIN_PLATE := 2
const SURFACE_STUD := 2
const SURFACE_PLATE := 1
## A stand: plates crossing each other's joints, in a colour sets give
## their stands, under a model that stands only on feet no bigger than
## this (a fox's legs a stud or two thick, an aircraft's wheels), or would
## tip, or stands in pieces nothing else joins. By its feet and not by its
## share of its plan: a sphere stands on a twelfth of its plan, and stands.
const STAND_PLATES := 2
const STAND_COLOUR := 0
const THIN_FOOT := 3
## A 1 x 2 plate, a 1 x 1 plate and a 1 x 1 brick: what a join is made of,
## by the numbers LDraw gives them today.
const JOIN_PLATE_PART := "3023b"
const ONE_PLATE := "3024"
const ONE_BRICK := "3005"
## The plates and tiles a stand is laid in: [studs along, part, rot] for a
## strip two studs wide running along x (rot as Shapes.CORE_PLATES has it),
## and along z; one stud wide; tiles on top.
const STAND_ALONG_X: Array = [[8, "3034", 0], [6, "3795", 0], [4, "3020", 0], [3, "3021", 0],
	[2, "3022", 0], [1, "3023b", 1]]
const STAND_ALONG_Z: Array = [[8, "3034", 1], [6, "3795", 1], [4, "3020", 1], [3, "3021", 1],
	[2, "3022", 0], [1, "3023b", 0]]
const STAND_ONE_X: Array = [[6, "3666", 0], [4, "3710", 0], [3, "3623", 0], [2, "3023b", 0],
	[1, "3024", 0]]
const STAND_ONE_Z: Array = [[6, "3666", 1], [4, "3710", 1], [3, "3623", 1], [2, "3023b", 1],
	[1, "3024", 0]]


## What the person chose.
class Options extends RefCounted:
	## Studs along the model's longest side, its height counted in studs too.
	var studs: int = 24
	var up: String = "+Y"
	var hollow: bool = false
	## Slopes, curved slopes, wedges, tiles and studs-sideways panels; off,
	## plain bricks and plates with their studs showing.
	var smooth: bool = true
	## "model" its own colours, "one" all [member colour], "limit" its own
	## colours cut to the [member limit] it uses most.
	var colours: String = "model"
	var colour: int = 71
	var limit: int = 4
	var palette: PackedInt32Array = PackedInt32Array(PALETTE)
	## A stand under it where it needs one (see [constant THIN_FOOT]);
	## off, it is laid as it stands, and said if it would tip.
	var stand: bool = true
	## Its core bonded as a builder bonds it (Shapes' "bond"); off, laid by
	## the colours measured, as [method build] lays it again where the
	## bonded build leaves more of the model out.
	var bond: bool = true
	## Its slopes fitted by distance to the model's own surface (Shapes'
	## "fine"); off, chosen by the flag as before, as [method build] lays it
	## again where the build leaves a region of the model out.
	var near: bool = true
	## Its steep sides laid on their sides (Shapes' "cubes"): each cube of
	## the surface two studs by five plates by two studs that faces out
	## within 30 degrees of level laid in plates, slopes and tiles whose up
	## points out, on bricks with studs on the side; off, every side a
	## staircase of studs up, as [method build] lays it again where the
	## build leaves a region of the model out.
	var snot: bool = true

	func copied() -> Options:
		var out := Options.new()
		for property: Dictionary in get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				out.set(property["name"], get(property["name"]))
		return out


## What a worker says it is doing, for the dialog to show.
class Progress extends RefCounted:
	var _lock := Mutex.new()
	var _said: String = ""
	var _stopped: bool = false

	func say(what: String) -> void:
		_lock.lock()
		_said = what
		_lock.unlock()

	func said() -> String:
		_lock.lock()
		var out: String = _said
		_lock.unlock()
		return out

	## Asked on the main thread (Cancel, the panel closed, the app
	## quitting): the run ends at its next step, with nothing laid.
	func stop() -> void:
		_lock.lock()
		_stopped = true
		_lock.unlock()

	func stopped() -> bool:
		_lock.lock()
		var out: bool = _stopped
		_lock.unlock()
		return out


## The model measured in studs and plates.
class Grid extends RefCounted:
	var across: int = 0
	var deep: int = 0
	var tall: int = 0
	## Studs per unit of the file.
	var scale: float = 1.0
	## Each cell: 0 outside, 1 the model, 2 a piece apart from the rest and
	## left out, 3 hollowed out.
	var state := PackedByteArray()
	var colour := PackedInt32Array()
	## For every third of a stud across and along, where the surface goes
	## in and comes out, in plates: pairs, rising.
	var spans: Array = []
	## Each stud's top: 1 a flat facet, 0 a curve.
	var flat_top := PackedByteArray()
	var dominant: int = 71
	var cells: int = 0
	var dropped: int = 0
	var hollowed: int = 0
	## How much of the surface each colour covers, code -> share.
	var shares: Dictionary = {}
	## Each cell the measuring added: 1 where the surface passes through a
	## part of it thinner than a stud or a plate (a leg, a spout, a wing), 2
	## to join a piece apart to the rest. Solid wherever Shapes samples it.
	var added := PackedByteArray()
	var thin: int = 0
	## Each piece apart that was joined: {"cells": its size, "path": cells
	## added, "to": "the rest" or "the ground", "way": "pillar" or "bridge"}.
	var joins: Array = []
	## What the measuring left out, each {"cells", "low", "high" (Vector3i,
	## studs, plates, studs), "why"}: never silently.
	var left_out: Array = []
	## The stand it is to be laid on, studs (x, z, across, deep), or empty;
	## why it needs one, and its colour.
	var stand := Rect2i()
	var stand_why: String = ""
	var stand_colour: int = STAND_COLOUR
	## What it stands on as measured: studs on the ground, studs of its plan,
	## pieces standing apart on the ground, and the centre of its mass's
	## margin inside what it stands on, studs (negative: it would tip).
	var on_ground: int = 0
	var plan_studs: int = 0
	var standing_apart: int = 0
	var margin: float = 0.0
	## What measuring took, ms, step by step.
	var ms: Dictionary = {}
	## The cubes of the surface that face out (see [method Brickify._cubes]):
	## Vector3i(x / 2, j / 5, z / 2) -> the way out, Vector2i(x, z).
	var cubes: Dictionary = {}
	## Rays across, for those sides: along x through every third of a stud
	## along z and up, and along z through every third across and up; where
	## each goes in and comes out, studs along it, as [member spans] has them.
	var spans_x: Array = []
	var spans_z: Array = []
	var side_rows: int = 0

	## The model's side where a ray along the way [param facing] points, at
	## [param side_at] studs across it and [param up] plates, leaves the
	## model going that way (or with [param inner], comes into it), nearest
	## [param near] studs along it and within [param reach]; else NAN. What
	## Shapes fits a side laid on its side to, as [method fine] a top.
	func side(facing: Vector2i, side_at: float, up: float, near: float, inner: bool,
			reach: float = 2.0) -> float:
		var along_x: bool = facing.x != 0
		var spans_here: Array = spans_x if along_x else spans_z
		if spans_here.is_empty():
			return NAN
		var fu: int = floori(side_at * FINE)
		var fv: int = floori(up / PLATES * FINE)
		var width: int = (deep if along_x else across) * FINE
		if fu < 0 or fv < 0 or fu >= width or fv >= side_rows:
			return NAN
		var span: PackedFloat32Array = spans_here[fu * side_rows + fv]
		var outward: bool = facing.x + facing.y > 0
		var best: float = NAN
		var gap: float = reach
		for n: int in range(1 if outward != inner else 0, span.size(), 2):
			var d: float = absf(span[n] - near)
			if d <= gap:
				gap = d
				best = span[n]
		return best

	func index(x: int, j: int, z: int) -> int:
		return (x * deep + z) * tall + j

	## The colour at [param p], studs across, plates up and studs along
	## from the grid's corner, or -1 where the model is not: what Shapes
	## samples. At the middle of a stud it is that stud; anywhere else it is
	## the surface itself, for a wedge's cut side to follow.
	func colour_at(p: Vector3) -> int:
		var x: int = floori(p.x)
		var j: int = floori(p.y)
		var z: int = floori(p.z)
		if x < 0 or z < 0 or j < 0 or x >= across or z >= deep or j >= tall:
			return -1
		var i: int = index(x, j, z)
		if p.x - x == 0.5 and p.z - z == 0.5:
			return colour[i] if state[i] == 1 else -1
		if state[i] >= 2 or not inside(p):
			return -1
		return colour[i] if state[i] == 1 else dominant

	## Whether [param p] is inside the surface, to a third of a stud. A cell
	## added for a thin part or a join is solid all through: its surface is
	## thinner than the samples, and a wedge cut to them would take it away.
	func inside(p: Vector3) -> bool:
		if not added.is_empty():
			var x: int = floori(p.x)
			var j: int = floori(p.y)
			var z: int = floori(p.z)
			if x >= 0 and z >= 0 and j >= 0 and x < across and z < deep and j < tall:
				var i: int = index(x, j, z)
				if added[i] != 0 and state[i] == 1:
					return true
		return within(p)

	## Whether [param p] is inside the model's own surface, to a third of a
	## stud across and exactly up: where its rays went in and not yet out.
	func within(p: Vector3) -> bool:
		var fx: int = floori(p.x * FINE)
		var fz: int = floori(p.z * FINE)
		if fx < 0 or fz < 0 or fx >= across * FINE or fz >= deep * FINE:
			return false
		var span: PackedFloat32Array = spans[fx * deep * FINE + fz]
		for k: int in range(0, span.size(), 2):
			if p.y >= span[k] and p.y < span[k + 1]:
				return true
		return false

	## Inside the hollow, for Shapes to keep clear: nothing laid there, and
	## no panel facing into it.
	func hollow_at(p: Vector3) -> int:
		var x: int = floori(p.x)
		var j: int = floori(p.y)
		var z: int = floori(p.z)
		if x < 0 or z < 0 or j < 0 or x >= across or z >= deep or j >= tall:
			return -1
		return 1 if state[index(x, j, z)] == 3 else -1

	## The model's own surface over a stud, at each of its nine thirds of a
	## stud (across, then along: x * FINE + z): where its rays come out (or
	## with [param under], go in) nearest [param near] plates and within
	## [param reach] of it, else NAN. What Shapes fits a surface part to.
	func fine(cell: Vector2i, near: float, under: bool, reach: float = 6.0) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		out.resize(FINE * FINE)
		out.fill(NAN)
		if cell.x < 0 or cell.y < 0 or cell.x >= across or cell.y >= deep:
			return out
		for i: int in FINE:
			for k: int in FINE:
				var span: PackedFloat32Array = spans[(cell.x * FINE + i) * deep * FINE + cell.y * FINE + k]
				var gap: float = reach
				for n: int in range(0 if under else 1, span.size(), 2):
					var d: float = absf(span[n] - near)
					if d <= gap:
						gap = d
						out[i * FINE + k] = span[n]
		return out

	## A flat facet takes straight slopes and a curve curved ones.
	func prefer(cell: Vector2i) -> String:
		if cell.x < 0 or cell.y < 0 or cell.x >= across or cell.y >= deep:
			return "curved"
		return "straight" if flat_top[cell.x * deep + cell.y] == 1 else "curved"


## The turn that stands a model with [param up] on the baseplate.
static func turn_for(up: String) -> Basis:
	match up:
		"+Z":
			return Basis(Vector3.RIGHT, -PI / 2.0)
		"-Z":
			return Basis(Vector3.RIGHT, PI / 2.0)
		"+X":
			return Basis(Vector3.BACK, PI / 2.0)
		"-X":
			return Basis(Vector3.BACK, -PI / 2.0)
		"-Y":
			return Basis(Vector3.RIGHT, PI)
	return Basis.IDENTITY


## How big it comes out: studs across, plates up, studs along.
static func size_of(mesh: MeshFile, up: String, studs: int) -> Vector3i:
	return size_in(_turned_bounds(mesh, turn_for(up)), studs)


## The same from its bounds, stood up already.
static func size_in(box: AABB, studs: int) -> Vector3i:
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest <= 0.0:
		return Vector3i.ZERO
	var scale: float = float(studs) / longest
	return Vector3i(maxi(1, ceili(box.size.x * scale - 0.001)),
		maxi(1, ceili(box.size.y * scale * PLATES - 0.001)),
		maxi(1, ceili(box.size.z * scale - 0.001)))


static func _turned_bounds(mesh: MeshFile, turn: Basis) -> AABB:
	if mesh.positions.is_empty():
		return AABB()
	var box := AABB(turn * mesh.positions[0], Vector3.ZERO)
	for p: Vector3 in mesh.positions:
		box = box.expand(turn * p)
	return box


# -- measuring ----------------------------------------------------------------


## The model in studs and plates: which cells it fills, the colour of each,
## and whether its top is a curve or a facet.
static func voxelise(mesh: MeshFile, options: Options, library: PartLibrary) -> Grid:
	var start: int = Time.get_ticks_msec()
	var grid := Grid.new()
	var turn: Basis = turn_for(options.up)
	var count: int = mesh.triangle_count()
	var box: AABB = _turned_bounds(mesh, turn)
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if count == 0 or longest <= 0.0:
		return grid
	var studs: int = clampi(options.studs, LEAST_STUDS, MOST_STUDS)
	grid.scale = float(studs) / longest
	var size: Vector3i = size_in(box, studs)
	grid.across = size.x
	grid.tall = size.y
	grid.deep = size.z
	# Into the grid's own units, studs across and along and plates up, in
	# the middle of its studs and standing on the ground.
	var shift := Vector3((grid.across - box.size.x * grid.scale) / 2.0, 0.0,
		(grid.deep - box.size.z * grid.scale) / 2.0)
	var points := PackedVector3Array()
	points.resize(count * 3)
	for n: int in points.size():
		var p: Vector3 = turn * mesh.positions[n] - box.position
		points[n] = Vector3(p.x * grid.scale + shift.x, p.y * grid.scale * PLATES,
			p.z * grid.scale + shift.z)
	# Which way round its faces are wound: outward faces enclose a positive
	# volume. A file wound the other way is read the other way.
	var volume: float = 0.0
	for t: int in count:
		volume += points[3 * t].dot(points[3 * t + 1].cross(points[3 * t + 2]))
	var outward: float = 1.0 if volume >= 0.0 else -1.0
	var flat: PackedByteArray = _flat_faces(mesh)

	var fw: int = grid.across * FINE
	var fd: int = grid.deep * FINE
	var hits: Array = []
	hits.resize(fw * fd)
	# A ray up through the middle of every third of a stud. Off the exact
	# middle by a hair, so one that meets two triangles' shared edge does
	# not count it twice.
	const NUDGE_X := 0.0000731
	const NUDGE_Z := 0.0000419
	for t: int in count:
		var a: Vector3 = points[3 * t]
		var b: Vector3 = points[3 * t + 1]
		var c: Vector3 = points[3 * t + 2]
		var d: float = (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(d) < 0.0000001:
			continue
		var up: float = (b - a).cross(c - a).y * outward
		var x0: int = maxi(0, ceili(minf(a.x, minf(b.x, c.x)) * FINE - 0.5 - 0.01))
		var x1: int = mini(fw - 1, floori(maxf(a.x, maxf(b.x, c.x)) * FINE - 0.5 + 0.01))
		var z0: int = maxi(0, ceili(minf(a.z, minf(b.z, c.z)) * FINE - 0.5 - 0.01))
		var z1: int = mini(fd - 1, floori(maxf(a.z, maxf(b.z, c.z)) * FINE - 0.5 + 0.01))
		for fx: int in range(x0, x1 + 1):
			var px: float = (fx + 0.5) / FINE + NUDGE_X
			for fz: int in range(z0, z1 + 1):
				var pz: float = (fz + 0.5) / FINE + NUDGE_Z
				var w1: float = ((px - a.x) * (c.z - a.z) - (c.x - a.x) * (pz - a.z)) / d
				if w1 < 0.0 or w1 > 1.0:
					continue
				var w2: float = ((b.x - a.x) * (pz - a.z) - (px - a.x) * (b.z - a.z)) / d
				if w2 < 0.0 or w1 + w2 > 1.0:
					continue
				var column: int = fx * fd + fz
				if hits[column] == null:
					hits[column] = []
				(hits[column] as Array).append(Vector3(a.y + (b.y - a.y) * w1 + (c.y - a.y) * w2,
					1.0 if up > 0.0 else -1.0, t))

	grid.spans.resize(fw * fd)
	var nothing := PackedFloat32Array()
	grid.flat_top.resize(grid.across * grid.deep)
	for column: int in fw * fd:
		if hits[column] == null:
			grid.spans[column] = nothing
			continue
		var list: Array = hits[column]
		list.sort()
		grid.spans[column] = _spans(list)
	# The studs: inside where the middle of the stud is, plate by plate.
	var total: int = grid.across * grid.deep * grid.tall
	grid.state.resize(total)
	grid.colour.resize(total)
	grid.colour.fill(-1)
	for x: int in grid.across:
		for z: int in grid.deep:
			var column: int = (x * FINE + 1) * fd + z * FINE + 1
			var span: PackedFloat32Array = grid.spans[column]
			for k: int in range(0, span.size(), 2):
				for j: int in range(maxi(0, ceili(span[k] - 0.5)),
						mini(grid.tall, ceili(span[k + 1] - 0.5))):
					grid.state[grid.index(x, j, z)] = 1
			# Its top: the highest face the ray leaves by.
			if hits[column] != null:
				var top: float = -INF
				var face: int = -1
				for hit: Vector3 in (hits[column] as Array):
					if hit.y > 0.0 and hit.x > top:
						top = hit.x
						face = int(hit.z)
				if face >= 0:
					grid.flat_top[x * grid.deep + z] = flat[face]
	var clock: int = Time.get_ticks_msec()
	grid.ms["spans"] = clock - start
	var touched: PackedByteArray = _touched(grid, points, count)
	grid.ms["touched"] = Time.get_ticks_msec() - clock
	clock = Time.get_ticks_msec()
	_thin(grid, touched)
	grid.ms["thin"] = Time.get_ticks_msec() - clock
	clock = Time.get_ticks_msec()
	_join(grid, touched, studs)
	grid.ms["join"] = Time.get_ticks_msec() - clock
	if options.hollow:
		_hollow(grid)
	for i: int in total:
		if grid.state[i] == 1:
			grid.cells += 1
	clock = Time.get_ticks_msec()
	_colour(grid, mesh, points, outward, options, library)
	grid.ms["colour"] = Time.get_ticks_msec() - clock
	clock = Time.get_ticks_msec()
	grid.stand_colour = _stand_colour(grid, options, library)
	_stance(grid, options)
	grid.ms["stance"] = Time.get_ticks_msec() - clock
	if options.smooth and options.snot:
		clock = Time.get_ticks_msec()
		grid.cubes = _cubes(grid, points, count, outward)
		if not grid.cubes.is_empty():
			grid.side_rows = ceili(grid.tall / PLATES * FINE)
			grid.spans_x = _side_spans(grid, points, count, outward, true)
			grid.spans_z = _side_spans(grid, points, count, outward, false)
		grid.ms["cubes"] = Time.get_ticks_msec() - clock
	return grid


## The rays of [member Grid.spans_x] (or with [param along_x] false,
## spans_z): as the rays up are cast, along x or z.
static func _side_spans(grid: Grid, points: PackedVector3Array, count: int, outward: float,
		along_x: bool) -> Array:
	var fu: int = (grid.deep if along_x else grid.across) * FINE
	var fv: int = grid.side_rows
	var hits: Array = []
	hits.resize(fu * fv)
	const NUDGE_U := 0.0000613
	const NUDGE_V := 0.0000287
	for t: int in count:
		var a: Vector3 = points[3 * t]
		var b: Vector3 = points[3 * t + 1]
		var c: Vector3 = points[3 * t + 2]
		# Across the ray and up (in studs), and along it.
		var au: float = a.z if along_x else a.x
		var bu: float = b.z if along_x else b.x
		var cu: float = c.z if along_x else c.x
		var av: float = a.y / PLATES
		var bv: float = b.y / PLATES
		var cv: float = c.y / PLATES
		var d: float = (bu - au) * (cv - av) - (cu - au) * (bv - av)
		if absf(d) < 0.0000001:
			continue
		var n: Vector3 = (b - a).cross(c - a) * outward
		var way: float = n.x if along_x else n.z
		var u0: int = maxi(0, ceili(minf(au, minf(bu, cu)) * FINE - 0.5 - 0.01))
		var u1: int = mini(fu - 1, floori(maxf(au, maxf(bu, cu)) * FINE - 0.5 + 0.01))
		var v0: int = maxi(0, ceili(minf(av, minf(bv, cv)) * FINE - 0.5 - 0.01))
		var v1: int = mini(fv - 1, floori(maxf(av, maxf(bv, cv)) * FINE - 0.5 + 0.01))
		var aw: float = a.x if along_x else a.z
		var bw: float = b.x if along_x else b.z
		var cw: float = c.x if along_x else c.z
		for iu: int in range(u0, u1 + 1):
			var pu: float = (iu + 0.5) / FINE + NUDGE_U
			for iv: int in range(v0, v1 + 1):
				var pv: float = (iv + 0.5) / FINE + NUDGE_V
				var w1: float = ((pu - au) * (cv - av) - (cu - au) * (pv - av)) / d
				if w1 < 0.0 or w1 > 1.0:
					continue
				var w2: float = ((bu - au) * (pv - av) - (pu - au) * (bv - av)) / d
				if w2 < 0.0 or w1 + w2 > 1.0:
					continue
				var column: int = iu * fv + iv
				if hits[column] == null:
					hits[column] = []
				(hits[column] as Array).append(Vector3(aw + (bw - aw) * w1 + (cw - aw) * w2,
					1.0 if way > 0.0 else -1.0, t))
	var out: Array = []
	out.resize(fu * fv)
	var nothing := PackedFloat32Array()
	for column: int in fu * fv:
		if hits[column] == null:
			out[column] = nothing
			continue
		var list: Array = hits[column]
		list.sort()
		out[column] = _spans(list)
	return out


## A cube of the surface is two studs by five plates by two studs, as
## Lambrecht's are [lambrecht]: as long every way (40 LDU), so a cube turned
## on its side fills the same box. One faces out where the model's surface
## in it, its triangles' areas summed by the way each faces, turns from
## level by under [constant STEEP] (sine): a side steeper than 60 degrees.
## Measured a hair inside the surface, so a side on a cube's edge is the
## cube it bounds; only where the surface in it is at least
## [constant CUBE_AREA] square studs and mostly faces one way.
const CUBE_STUDS := 2
const CUBE_PLATES := 5
const STEEP := 0.5
const CUBE_AREA := 1.0
const CUBE_AGREES := 0.6


static func _cubes(grid: Grid, points: PackedVector3Array, count: int, outward: float) -> Dictionary:
	var sums: Dictionary = {}    ## Vector3i -> Vector3, area times the way out, square studs
	var areas: Dictionary = {}   ## Vector3i -> float
	var iso := Vector3(1.0, 1.0 / PLATES, 1.0)
	for t: int in count:
		var a: Vector3 = points[3 * t]
		var b: Vector3 = points[3 * t + 1]
		var c: Vector3 = points[3 * t + 2]
		var ab: Vector3 = (b - a) * iso
		var ac: Vector3 = (c - a) * iso
		var n: Vector3 = ab.cross(ac) * (0.5 * outward)
		var area: float = n.length()
		if area < 0.000001:
			continue
		var inward: Vector3 = -n / area * 0.25
		var longest: float = maxf(ab.length(), maxf(ac.length(), (ac - ab).length()))
		var k: int = clampi(ceili(longest), 1, 8)
		var share: Vector3 = n / float(k * k)
		var each: float = area / float(k * k)
		for i: int in k:
			for m: int in k - i:
				for flip: int in 2:
					if flip == 1 and i + m >= k - 1:
						continue
					var u: float = (i + (1.0 if flip == 0 else 2.0) / 3.0) / k
					var v: float = (m + (1.0 if flip == 0 else 2.0) / 3.0) / k
					var p: Vector3 = a + (b - a) * u + (c - a) * v
					p += Vector3(inward.x, inward.y * PLATES, inward.z)
					var key := Vector3i(floori(p.x / CUBE_STUDS), floori(p.y / CUBE_PLATES),
						floori(p.z / CUBE_STUDS))
					sums[key] = (sums.get(key, Vector3.ZERO) as Vector3) + share
					areas[key] = float(areas.get(key, 0.0)) + each
	var out: Dictionary = {}
	var keys: Array = sums.keys()
	keys.sort()
	for key: Variant in keys:
		var sum: Vector3 = sums[key]
		var area: float = areas[key]
		if area < CUBE_AREA or sum.length() < CUBE_AGREES * area:
			continue
		var way: Vector3 = sum.normalized()
		if absf(way.y) >= STEEP:
			continue
		out[key] = Vector2i(signi(roundi(signf(way.x))), 0) if absf(way.x) >= absf(way.z) \
			else Vector2i(0, signi(roundi(signf(way.z))))
	return out


## The stand's colour: the one colour asked for, the darkest of the colours
## it is cut to, or black, as sets' stands are.
static func _stand_colour(grid: Grid, options: Options, library: PartLibrary) -> int:
	if options.colours == "one":
		return options.colour
	if options.colours == "limit" and library != null and not grid.shares.is_empty():
		var darkest: int = grid.dominant
		var least: float = INF
		for code: Variant in grid.shares:
			var known: PartLibrary.BrickColor = library.color(int(code))
			if known != null and known.rgb.get_luminance() < least:
				least = known.rgb.get_luminance()
				darkest = int(code)
		return darkest
	return STAND_COLOUR


# -- what is thinner than a stud ----------------------------------------------


## Every cell the surface passes through, whether or not it holds the
## middle of the cell: a triangle against each cell its box reaches, by
## separating axes (Akenine-Möller). A triangle inside one cell, which is
## most of a scan's, is that cell's without a test.
static func _touched(grid: Grid, points: PackedVector3Array, count: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(grid.state.size())
	var top_x: int = grid.across - 1
	var top_j: int = grid.tall - 1
	var top_z: int = grid.deep - 1
	for t: int in count:
		var a: Vector3 = points[3 * t]
		var b: Vector3 = points[3 * t + 1]
		var c: Vector3 = points[3 * t + 2]
		var low: Vector3 = a.min(b).min(c)
		var high: Vector3 = a.max(b).max(c)
		var x0: int = clampi(floori(low.x), 0, top_x)
		var x1: int = clampi(floori(high.x), 0, top_x)
		var j0: int = clampi(floori(low.y), 0, top_j)
		var j1: int = clampi(floori(high.y), 0, top_j)
		var z0: int = clampi(floori(low.z), 0, top_z)
		var z1: int = clampi(floori(high.z), 0, top_z)
		if x0 == x1 and j0 == j1 and z0 == z1:
			out[grid.index(x0, j0, z0)] = 1
			continue
		for x: int in range(x0, x1 + 1):
			for z: int in range(z0, z1 + 1):
				for j: int in range(j0, j1 + 1):
					var i: int = grid.index(x, j, z)
					if out[i] == 0 and _crosses(a, b, c, Vector3(x + 0.5, j + 0.5, z + 0.5)):
						out[i] = 1
	return out


## Whether the triangle a b c meets the unit cell round [param centre].
static func _crosses(a: Vector3, b: Vector3, c: Vector3, centre: Vector3) -> bool:
	var v0: Vector3 = a - centre
	var v1: Vector3 = b - centre
	var v2: Vector3 = c - centre
	if minf(v0.x, minf(v1.x, v2.x)) > 0.5 or maxf(v0.x, maxf(v1.x, v2.x)) < -0.5 \
			or minf(v0.y, minf(v1.y, v2.y)) > 0.5 or maxf(v0.y, maxf(v1.y, v2.y)) < -0.5 \
			or minf(v0.z, minf(v1.z, v2.z)) > 0.5 or maxf(v0.z, maxf(v1.z, v2.z)) < -0.5:
		return false
	var e0: Vector3 = v1 - v0
	var e1: Vector3 = v2 - v1
	var e2: Vector3 = v0 - v2
	var n: Vector3 = e0.cross(e1)
	if absf(n.dot(v0)) > 0.5 * (absf(n.x) + absf(n.y) + absf(n.z)):
		return false
	for e: Vector3 in [e0, e1, e2]:
		if _parted(Vector3(0.0, -e.z, e.y), v0, v1, v2) \
				or _parted(Vector3(e.z, 0.0, -e.x), v0, v1, v2) \
				or _parted(Vector3(-e.y, e.x, 0.0), v0, v1, v2):
			return false
	return true


## Whether [param axis] separates the triangle from the unit cell round 0.
static func _parted(axis: Vector3, v0: Vector3, v1: Vector3, v2: Vector3) -> bool:
	var p0: float = axis.dot(v0)
	var p1: float = axis.dot(v1)
	var p2: float = axis.dot(v2)
	var r: float = 0.5 * (absf(axis.x) + absf(axis.y) + absf(axis.z))
	return minf(p0, minf(p1, p2)) > r or maxf(p0, maxf(p1, p2)) < -r


## The cells a part of the model thinner than a stud or a plate passes
## through, kept: measured only where the middle of a cell is inside, a
## fox's legs never reached the grid, its body floated and the mend took
## every part out. A cell the surface passes through counts where nothing
## measured is beside it, above it, below it or on a diagonal, so a thick
## body comes out no fatter; then the cells it passes through between such
## a part and the body, so the two meet; and a part one plate thick is made
## two, so its plates can cross each other's joints.
static func _thin(grid: Grid, touched: PackedByteArray) -> void:
	var total: int = grid.state.size()
	grid.added.resize(total)
	var tall: int = grid.tall
	var column: int = grid.tall * grid.deep
	var candidates := PackedInt32Array()
	for i: int in total:
		if touched[i] == 1 and grid.state[i] == 0:
			candidates.append(i)
	if candidates.is_empty():
		return
	var thin := PackedInt32Array()
	for i: int in candidates:
		var x: int = i / column
		var z: int = (i / tall) % grid.deep
		var j: int = i % tall
		var near: bool = false
		for dx: int in range(maxi(x - 1, 0), mini(x + 2, grid.across)):
			for dz: int in range(maxi(z - 1, 0), mini(z + 2, grid.deep)):
				var base: int = (dx * grid.deep + dz) * tall
				for dj: int in range(maxi(j - 1, 0), mini(j + 2, tall)):
					if grid.state[base + dj] == 1:
						near = true
						break
				if near:
					break
			if near:
				break
		if not near:
			thin.append(i)
	for i: int in thin:
		grid.added[i] = 1
	if thin.is_empty():
		return
	# Where a thin part meets the body: the cells it passes through there.
	var seams := PackedInt32Array()
	for i: int in candidates:
		if grid.added[i] != 0:
			continue
		for n: int in _faces(grid, i):
			if grid.added[n] == 1:
				seams.append(i)
				break
	for i: int in seams:
		grid.added[i] = 1
	for i: int in thin + seams:
		grid.state[i] = 1
	# One plate thick, two: plates side by side in one layer hold nothing.
	var thicker := PackedInt32Array()
	for i: int in thin:
		var j: int = i % tall
		var above: bool = j + 1 < tall and grid.state[i + 1] == 1
		var below: bool = j > 0 and grid.state[i - 1] == 1
		if above or below:
			continue
		if j > 0 and grid.state[i - 1] == 0:
			thicker.append(i - 1)
		elif j + 1 < tall and grid.state[i + 1] == 0:
			thicker.append(i + 1)
	for i: int in thicker:
		grid.state[i] = 1
		grid.added[i] = 1
	grid.thin = thin.size() + seams.size() + thicker.size()


## The cells beside [param i], above and below it, inside the grid.
static func _faces(grid: Grid, i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var tall: int = grid.tall
	var column: int = grid.tall * grid.deep
	var x: int = i / column
	var z: int = (i / tall) % grid.deep
	var j: int = i % tall
	if j > 0:
		out.append(i - 1)
	if j + 1 < tall:
		out.append(i + 1)
	if z > 0:
		out.append(i - tall)
	if z + 1 < grid.deep:
		out.append(i + tall)
	if x > 0:
		out.append(i - column)
	if x + 1 < grid.across:
		out.append(i + column)
	return out


# -- pieces apart -------------------------------------------------------------


## The model's pieces, each its cells, largest first: cells joined face to
## face.
static func _pieces(grid: Grid) -> Array:
	var total: int = grid.state.size()
	var seen := PackedByteArray()
	seen.resize(total)
	var out: Array = []
	for start: int in total:
		if grid.state[start] != 1 or seen[start] == 1:
			continue
		var piece := PackedInt32Array([start])
		seen[start] = 1
		var n: int = 0
		while n < piece.size():
			for next: int in _faces(grid, piece[n]):
				if grid.state[next] == 1 and seen[next] == 0:
					seen[next] = 1
					piece.append(next)
			n += 1
		out.append(piece)
	out.sort_custom(func(a: PackedInt32Array, b: PackedInt32Array) -> bool:
		return a.size() > b.size())
	return out


## How far a piece apart may be joined from, in the join's costs: four
## studs across empty air at 24 studs, eight at 48.
static func _join_reach(studs: int) -> int:
	return JOIN_STUD * maxi(4, studs / 6)


## Join, don't drop. Each piece apart from the largest is joined to the
## rest by the cheapest way there: along the model's own surface where it
## is thinner than a stud, else straight through the air, a plate up or
## down costing less than a stud across, so a join is a pillar more than a
## bridge. The largest piece, if it stands on nothing, is stood on the
## ground or on a piece that is. A piece too far to join that stands on the
## ground is kept, for a stand to join; any other is left out, and said.
## Taking every piece but the largest out (as this once did) laid nothing at
## all for a fox whose body floated over legs it had not measured.
static func _join(grid: Grid, touched: PackedByteArray, studs: int) -> void:
	if grid.added.is_empty():
		grid.added.resize(grid.state.size())
	var pieces: Array = _pieces(grid)
	if pieces.is_empty():
		return
	var cells: int = 0
	for piece: PackedInt32Array in pieces:
		cells += piece.size()
	# A speck: a few cells of a scan's dust, which a stand would not be
	# built for.
	var speck: int = maxi(4, cells / 400)
	var main: PackedInt32Array = pieces[0]
	var kept := PackedInt32Array(main)
	var grounded: Array = []
	for n: int in range(1, pieces.size()):
		var piece: PackedInt32Array = pieces[n]
		if piece.size() >= speck and _on_ground(grid, piece):
			grounded.append(n)
			kept.append_array(piece)
	# The largest piece, standing on nothing: a pillar to the ground, or to
	# a piece that stands on it.
	if not _on_ground(grid, main):
		var reach: Dictionary = _reach(grid, touched, main, -1, 1 << 20)
		var dist: PackedInt32Array = reach["dist"]
		var best: int = -1
		for x: int in grid.across:
			for z: int in grid.deep:
				var i: int = grid.index(x, 0, z)
				if dist[i] >= 0 and (best < 0 or dist[i] < dist[best]):
					best = i
		for n: int in grounded:
			for i: int in (pieces[n] as PackedInt32Array):
				if dist[i] >= 0 and (best < 0 or dist[i] < dist[best]):
					best = i
		if best >= 0:
			var path: PackedInt32Array = _trace(grid, reach, best)
			path.append_array(_widened(grid, path))
			grid.joins.append({"cells": main.size(), "path": path.size(),
				"to": "the ground", "way": "pillar"})
			kept.append_array(path)
	var rest: Array = []
	for n: int in range(1, pieces.size()):
		if not grounded.has(n):
			rest.append(n)
	if rest.is_empty():
		return
	var limit: int = _join_reach(studs)
	var reach: Dictionary = _reach(grid, touched, kept, JOIN_STUD * 2, limit)
	var dist: PackedInt32Array = reach["dist"]
	for n: int in rest:
		var piece: PackedInt32Array = pieces[n]
		# From the cell beside it the way there is cheapest, and of those the
		# one nearest its middle: from the first found, a pillar stood under a
		# corner of a cube and carried it on one stud's edge.
		var middle := Vector2.ZERO
		for i: int in piece:
			middle += Vector2(i / (grid.tall * grid.deep), (i / grid.tall) % grid.deep)
		middle /= float(piece.size())
		var best: int = -1
		var off: float = INF
		for i: int in piece:
			for next: int in _faces(grid, i):
				if grid.state[next] == 1 or dist[next] < 0:
					continue
				var here: float = Vector2(next / (grid.tall * grid.deep),
					(next / grid.tall) % grid.deep).distance_to(middle)
				if best < 0 or dist[next] < dist[best] or (dist[next] == dist[best] and here < off):
					best = next
					off = here
		if best >= 0:
			var path: PackedInt32Array = _trace(grid, reach, best)
			var way: String = _way(path)
			var to_ground: bool = bool(reach.get("grounded", false))
			if to_ground and piece.size() < speck:
				# A speck joined only by a pillar of its own to the floor is dust.
				for i: int in path:
					grid.state[i] = 0
					grid.added[i] = 0
			else:
				if piece.size() >= speck:
					path.append_array(_widened(grid, path))
				grid.joins.append({"cells": piece.size(), "path": path.size(),
					"to": "the ground" if to_ground else "the rest", "way": way})
				continue
		for i: int in piece:
			grid.state[i] = 2
		grid.dropped += piece.size()
		grid.left_out.append(_described(grid, piece,
			"a speck apart from the rest" if piece.size() < speck
			else "a piece apart from the rest, too far from it to join"))


## Whether a piece has a cell on the ground.
static func _on_ground(grid: Grid, piece: PackedInt32Array) -> bool:
	for i: int in piece:
		if i % grid.tall == 0:
			return true
	return false


## The cheapest way from [param sources] to every cell, as far as [param
## limit]: {"dist" (-1 not reached), "from"}. Through the model's cells
## free, along its surface cheaply, through the air dearly; from the ground
## too, at [param ground] more, when it is not -1 (a piece may stand on its
## own pillar). By buckets, the costs being small whole numbers.
static func _reach(grid: Grid, touched: PackedByteArray, sources: PackedInt32Array,
		ground: int, limit: int) -> Dictionary:
	var total: int = grid.state.size()
	var dist := PackedInt32Array()
	dist.resize(total)
	dist.fill(-1)
	var from := PackedInt32Array()
	from.resize(total)
	from.fill(-1)
	# Arrays, not packed ones: a packed array in a dictionary is copied on
	# every append.
	var buckets: Dictionary = {}    ## distance -> Array of cells
	for i: int in sources:
		dist[i] = 0
		from[i] = i
	buckets[0] = Array(sources)
	if ground >= 0:
		for x: int in grid.across:
			for z: int in grid.deep:
				var i: int = grid.index(x, 0, z)
				var d: int = ground + _cost(grid, touched, i, true)
				if d <= limit and (dist[i] < 0 or d < dist[i]):
					dist[i] = d
					from[i] = -2
					if not buckets.has(d):
						buckets[d] = []
					(buckets[d] as Array).append(i)
	var d: int = 0
	while d <= limit and not buckets.is_empty():
		if not buckets.has(d):
			d += 1
			continue
		var here: Array = buckets[d]
		var n: int = 0
		while n < here.size():
			var i: int = here[n]
			n += 1
			if dist[i] != d:
				continue
			for next: int in _faces(grid, i):
				var nd: int = d + _cost(grid, touched, next, absi(next - i) == 1)
				if nd > limit or (dist[next] >= 0 and nd >= dist[next]):
					continue
				dist[next] = nd
				from[next] = i
				# A free step, into the model, lands in this same bucket and is
				# read before it is done.
				if not buckets.has(nd):
					buckets[nd] = []
				(buckets[nd] as Array).append(next)
		buckets.erase(d)
		d += 1
	return {"dist": dist, "from": from}


## What a step into cell [param i] costs: nothing into the model, little
## along its surface, more through the air; a plate up or down is less
## than a stud across.
static func _cost(grid: Grid, touched: PackedByteArray, i: int, upright: bool) -> int:
	if grid.state[i] == 1:
		return 0
	if touched[i] == 1:
		return SURFACE_PLATE if upright else SURFACE_STUD
	return JOIN_PLATE if upright else JOIN_STUD


## The way back from [param start] to where [param reach] began, its cells
## made the model's: the cells added. Says in reach["grounded"] whether it
## began on the ground.
static func _trace(grid: Grid, reach: Dictionary, start: int) -> PackedInt32Array:
	var from: PackedInt32Array = reach["from"]
	var path := PackedInt32Array()
	var at: int = start
	reach["grounded"] = false
	for _step: int in grid.state.size():
		if grid.state[at] != 1:
			grid.state[at] = 1
			grid.added[at] = 2
			path.append(at)
		var back: int = from[at]
		if back == -2:
			reach["grounded"] = true
			break
		if back < 0 or back == at:
			break
		at = back
	return path


## A path two studs square, not one: the cells beside each of its cells on
## one side and the next, made the model's, for a join to be 2 x 2 bricks and
## plates, four studs to a joint, and not a column of 1 x 1s that a cube on
## it bends over. The cells added.
static func _widened(grid: Grid, path: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var column: int = grid.tall * grid.deep
	for i: int in path:
		var x: int = i / column
		var z: int = (i / grid.tall) % grid.deep
		var dx: int = column if x + 1 < grid.across else -column
		var dz: int = grid.tall if z + 1 < grid.deep else -grid.tall
		for next: int in [i + dx, i + dz, i + dx + dz]:
			if next >= 0 and next < grid.state.size() and grid.state[next] == 0:
				grid.state[next] = 1
				grid.added[next] = 2
				out.append(next)
	return out


## Whether a path is more up and down than across.
static func _way(path: PackedInt32Array) -> String:
	var upright: int = 0
	for n: int in range(1, path.size()):
		if absi(path[n] - path[n - 1]) == 1:
			upright += 1
	return "pillar" if upright * 2 >= path.size() - 1 else "bridge"


## A piece said by where it is: its cells, its corners in studs and plates,
## and why.
static func _described(grid: Grid, piece: PackedInt32Array, why: String) -> Dictionary:
	var low := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var high := -low
	var column: int = grid.tall * grid.deep
	for i: int in piece:
		var at := Vector3i(i / column, i % grid.tall, (i / grid.tall) % grid.deep)
		low = low.min(at)
		high = high.max(at)
	return {"cells": piece.size(), "low": low, "high": high, "why": why}


# -- what it stands on --------------------------------------------------------


## The most studs any one foot stands on: the cells on the ground in pieces
## side by side.
static func _widest_foot(feet: Dictionary) -> int:
	var seen: Dictionary = {}
	var widest: int = 0
	for key: Variant in feet:
		if seen.has(key):
			continue
		var count: int = 0
		var stack: Array = [key]
		seen[key] = true
		while not stack.is_empty():
			var here: Vector2i = stack.pop_back()
			count += 1
			for step: Vector2i in Shapes.OUT:
				var next: Vector2i = here + step
				if feet.has(next) and not seen.has(next):
					seen[next] = true
					stack.append(next)
		widest = maxi(widest, count)
	return widest


## Whether it stands as measured, and the stand it is laid on if not: on
## feet none bigger than [constant THIN_FOOT] studs (a fox's legs, an
## aircraft's wheels); with its centre of mass within half a stud of the
## edge of what it stands on, or past it; or in pieces on the ground that
## nothing else joins. A stand covers what it stands on and its centre of
## mass a stud and a half round, and a stud more, inside its own bounds.
## Balance weighs it once laid.
static func _stance(grid: Grid, options: Options) -> void:
	var feet: Dictionary = {}       ## Vector2i -> true
	var mass := Vector2.ZERO
	var count: int = 0
	var plan: int = 0
	for x: int in grid.across:
		for z: int in grid.deep:
			var base: int = grid.index(x, 0, z)
			var any: bool = false
			for j: int in grid.tall:
				if grid.state[base + j] == 1:
					any = true
					mass += Vector2(x + 0.5, z + 0.5)
					count += 1
			if any:
				plan += 1
			if grid.state[base] == 1:
				feet[Vector2i(x, z)] = true
	grid.on_ground = feet.size()
	grid.plan_studs = plan
	if count == 0:
		return
	mass /= float(count)
	var corners := PackedVector2Array()
	for key: Variant in feet:
		var cell: Vector2i = key
		corners.append_array([Vector2(cell), Vector2(cell.x + 1, cell.y),
			Vector2(cell.x + 1, cell.y + 1), Vector2(cell.x, cell.y + 1)])
	var hull: PackedVector2Array = Geometry2D.convex_hull(corners)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.resize(hull.size() - 1)
	grid.margin = float(Balance.margin_in(hull, mass)["margin"]) if hull.size() >= 3 else -1.0
	var ground_pieces: int = 0
	for piece: PackedInt32Array in _pieces(grid):
		if _on_ground(grid, piece):
			ground_pieces += 1
	grid.standing_apart = ground_pieces
	if not options.stand or feet.is_empty():
		return
	var why: String = ""
	if ground_pieces > 1:
		why = "it stands in %d pieces that only the ground would join" % ground_pieces
	elif grid.margin < 0.0:
		why = "it would tip, its centre of mass %s studs past what it stands on" % Balance.studs(
			-grid.margin)
	elif grid.margin < Balance.SPARE:
		why = "it would all but tip, its centre of mass %s studs inside what it stands on" \
			% Balance.studs(grid.margin)
	elif _widest_foot(feet) <= THIN_FOOT:
		why = "it stands on %d stud%s, on feet none bigger than %d" % [grid.on_ground,
			"" if grid.on_ground == 1 else "s", THIN_FOOT]
	if why.is_empty():
		return
	var low := Vector2i(floori(mass.x - 1.5), floori(mass.y - 1.5))
	var high := Vector2i(ceili(mass.x + 1.5), ceili(mass.y + 1.5))
	for key: Variant in feet:
		var foot: Vector2i = key
		low = low.min(foot)
		high = high.max(foot + Vector2i.ONE)
	low = (low - Vector2i.ONE).max(Vector2i.ZERO)
	high = (high + Vector2i.ONE).min(Vector2i(grid.across, grid.deep))
	grid.stand = Rect2i(low, high - low)
	grid.stand_why = why


## Where a column is inside, from the faces a ray up it crosses: in at a
## face looking down, out at one looking up, and inside wherever more have
## been gone in by than come out of — so two shells that overlap, a body and
## the ears pushed into it, are one solid. A surface whose faces disagree
## which way is out is read the old way instead: in, out, in, out. And one
## left open — a scanned statue with no underside, a sculpt with no top —
## is closed: from the ground, where the first face the ray meets faces up
## and so was met from inside; never up into the sky.
static func _spans(list: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var winding: int = 0
	var start: float = 0.0
	var sound: bool = true
	var last := Vector3(-INF, 0.0, -1.0)
	var hits: Array[Vector3] = []
	for hit: Vector3 in list:
		# The same face twice, from a seam the ray ran along.
		if hit.y == last.y and absf(hit.x - last.x) < 0.0001:
			continue
		last = hit
		hits.append(hit)
	for hit: Vector3 in hits:
		var before: int = winding
		winding += -1 if hit.y > 0.0 else 1
		if winding < 0:
			sound = false
			break
		if before == 0 and winding > 0:
			start = hit.x
		elif before > 0 and winding == 0 and hit.x - start > 0.001:
			out.append(start)
			out.append(hit.x)
	if sound and winding == 0:
		return out
	out = PackedFloat32Array()
	if hits.size() % 2 == 1:
		if hits[0].y > 0.0:
			hits.push_front(Vector3(0.0, -1.0, -1.0))
		else:
			hits.pop_back()
	for n: int in range(0, hits.size() - 1, 2):
		out.append(hits[n].x)
		out.append(hits[n + 1].x)
	return out


## Each triangle flat (1) where its corners' normals are its own: a facet,
## not part of a curve.
static func _flat_faces(mesh: MeshFile) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(mesh.triangle_count())
	var limit: float = cos(deg_to_rad(FLAT_DEGREES))
	for t: int in mesh.triangle_count():
		var a: Vector3 = mesh.positions[3 * t]
		var face: Vector3 = (mesh.positions[3 * t + 1] - a).cross(mesh.positions[3 * t + 2] - a)
		if face.length_squared() <= 0.0:
			continue
		face = face.normalized()
		var flat: bool = true
		for corner: int in 3:
			if absf(mesh.normals[3 * t + corner].dot(face)) < limit:
				flat = false
				break
		out[t] = 1 if flat else 0
	return out


## Hollowed: every cell further in than the walls left out. Worked out as
## a box worn away from the outside one direction at a time.
static func _hollow(grid: Grid) -> void:
	var total: int = grid.state.size()
	var deep_in := PackedByteArray()
	deep_in.resize(total)
	for i: int in total:
		deep_in[i] = 1 if grid.state[i] == 1 else 0
	deep_in = _worn(grid, deep_in, Vector3i(1, 0, 0), WALL_STUDS)
	deep_in = _worn(grid, deep_in, Vector3i(0, 0, 1), WALL_STUDS)
	deep_in = _worn(grid, deep_in, Vector3i(0, 1, 0), WALL_PLATES)
	# In whole courses, so the walls round the hollow are bricks: cut through
	# a course, the hollow's floor and ceiling were a layer of plates each and
	# a hollow sphere came out a fifth more parts than a solid one.
	for x: int in grid.across:
		for z: int in grid.deep:
			for k: int in grid.tall / 3:
				var whole: bool = true
				for n: int in 3:
					whole = whole and deep_in[grid.index(x, 3 * k + n, z)] == 1
				if not whole:
					continue
				for n: int in 3:
					grid.state[grid.index(x, 3 * k + n, z)] = 3
					grid.hollowed += 1


## [param cells] kept only where [param reach] more of them run on either
## side along [param along].
static func _worn(grid: Grid, cells: PackedByteArray, along: Vector3i,
		reach: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(cells.size())
	var size := Vector3i(grid.across, grid.tall, grid.deep)
	var length: int = size.x if along.x == 1 else (size.y if along.y == 1 else size.z)
	var before := PackedInt32Array()
	before.resize(length)
	for a: int in (size.y if along.x == 1 else size.x):
		for b: int in (size.y if along.z == 1 else size.z):
			var line := PackedInt32Array()
			line.resize(length)
			for n: int in length:
				var at: Vector3i = _on_line(along, a, b, n)
				line[n] = grid.index(at.x, at.y, at.z)
			var run: int = 0
			for n: int in length:
				run = run + 1 if cells[line[n]] == 1 else 0
				before[n] = run
			run = 0
			for n: int in range(length - 1, -1, -1):
				run = run + 1 if cells[line[n]] == 1 else 0
				if before[n] > reach and run > reach:
					out[line[n]] = 1
	return out


## The [param n]th cell of the line along [param along] through the two
## other coordinates [param a] and [param b], as Vector3i(x, j, z).
static func _on_line(along: Vector3i, a: int, b: int, n: int) -> Vector3i:
	if along.x == 1:
		return Vector3i(n, a, b)
	if along.z == 1:
		return Vector3i(a, b, n)
	return Vector3i(a, n, b)


# -- colour -------------------------------------------------------------------


## The colour of each cell: the surface's colour over it, matched to a real
## LEGO colour as a mosaic is (in Oklab, where equal distances look equally
## different), each surface cell the colour most of its surface is, and the
## inside the colour of the surface nearest it, or under that the colour
## the model is most of.
static func _colour(grid: Grid, mesh: MeshFile, points: PackedVector3Array,
		outward: float, options: Options, library: PartLibrary) -> void:
	if options.colours == "one" or not mesh.coloured:
		_one_colour(grid, options.colour)
		return
	var palette: PackedInt32Array = options.palette
	var lab: Array[Vector3] = []
	for code: int in palette:
		var known: PartLibrary.BrickColor = library.color(code) if library != null else null
		lab.append(HiddenColours.lab(known.rgb if known != null else Color.MAGENTA))
	# Every sample: the cell it colours, its colour to a 32nd, how much
	# surface it stands for.
	var cells := PackedInt32Array()
	var keys := PackedInt32Array()
	var weights := PackedFloat32Array()
	for t: int in mesh.triangle_count():
		# In studs all three ways, for the area and the step inward.
		var a: Vector3 = points[3 * t] * Vector3(1.0, 1.0 / PLATES, 1.0)
		var ab: Vector3 = points[3 * t + 1] * Vector3(1.0, 1.0 / PLATES, 1.0) - a
		var ac: Vector3 = points[3 * t + 2] * Vector3(1.0, 1.0 / PLATES, 1.0) - a
		var normal: Vector3 = ab.cross(ac)
		var area: float = normal.length() / 2.0
		if area <= 0.0:
			continue
		normal = normal / (2.0 * area) * outward
		var longest: float = maxf(ab.length(), maxf(ac.length(), (ac - ab).length()))
		var n: int = clampi(ceili(longest / SAMPLE_STUDS), 1, 96)
		var weight: float = area / float(n * n)
		for i: int in n:
			for k: int in n - i:
				for second: int in (2 if i + k + 1 < n else 1):
					var u: float = (i + (2.0 if second == 1 else 1.0) / 3.0) / n
					var v: float = (k + (2.0 if second == 1 else 1.0) / 3.0) / n
					var on: Vector3 = a + ab * u + ac * v
					var cell: int = _shown_at(grid, on, normal)
					if cell < 0:
						continue
					var c: Color = mesh.colour_at(t, Vector3(1.0 - u - v, u, v))
					cells.append(cell)
					keys.append((roundi(clampf(c.r, 0.0, 1.0) * 31.0) << 10)
						| (roundi(clampf(c.g, 0.0, 1.0) * 31.0) << 5)
						| roundi(clampf(c.b, 0.0, 1.0) * 31.0))
					weights.append(weight)
	if cells.is_empty():
		_one_colour(grid, options.colour)
		return
	var nearest: Dictionary = {}     ## key -> palette index
	var area_of: Dictionary = {}     ## palette index -> area
	for s: int in keys.size():
		var at: int = _nearest(keys[s], lab, nearest, [])
		area_of[at] = float(area_of.get(at, 0.0)) + weights[s]
	# Cut to the colours it uses most, the rest matched again among them.
	if options.colours == "limit":
		var ranked: Array = area_of.keys()
		ranked.sort_custom(func(p: int, q: int) -> bool: return area_of[p] > area_of[q])
		var kept: Array = ranked.slice(0, maxi(1, options.limit))
		nearest = {}
		area_of = {}
		for s: int in keys.size():
			var at: int = _nearest(keys[s], lab, nearest, kept)
			area_of[at] = float(area_of.get(at, 0.0)) + weights[s]
	var votes: Dictionary = {}       ## cell -> {palette index: area}
	for s: int in keys.size():
		var at: int = nearest[keys[s]]
		if not votes.has(cells[s]):
			votes[cells[s]] = {}
		var vote: Dictionary = votes[cells[s]]
		vote[at] = float(vote.get(at, 0.0)) + weights[s]
	var most: int = -1
	var all_area: float = 0.0
	for at: Variant in area_of:
		all_area += float(area_of[at])
		if most < 0 or float(area_of[at]) > float(area_of[most]):
			most = int(at)
	grid.dominant = palette[most]
	for at: Variant in area_of:
		grid.shares[palette[int(at)]] = float(area_of[at]) / maxf(all_area, 0.000001)
	var frontier: Array[int] = []
	for cell: Variant in votes:
		var vote: Dictionary = votes[cell]
		var best: int = -1
		for at: Variant in vote:
			if best < 0 or float(vote[at]) > float(vote[best]):
				best = int(at)
		grid.colour[int(cell)] = palette[best]
		frontier.append(int(cell))
	# Inward from the surface two cells, then the main colour: hidden, and
	# one colour is fewer, larger bricks.
	for _depth: int in 2:
		var next: Array[int] = []
		for i: int in frontier:
			var x: int = i / (grid.deep * grid.tall)
			var z: int = (i / grid.tall) % grid.deep
			var j: int = i % grid.tall
			for step: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
					Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var o := Vector3i(x, j, z) + step
				if o.x < 0 or o.y < 0 or o.z < 0 or o.x >= grid.across or o.y >= grid.tall \
						or o.z >= grid.deep:
					continue
				var k: int = grid.index(o.x, o.y, o.z)
				if grid.state[k] == 1 and grid.colour[k] < 0:
					grid.colour[k] = grid.colour[i]
					next.append(k)
		frontier = next
	for i: int in grid.state.size():
		if grid.state[i] == 1 and grid.colour[i] < 0:
			grid.colour[i] = grid.dominant


static func _one_colour(grid: Grid, one: int) -> void:
	for i: int in grid.state.size():
		if grid.state[i] == 1:
			grid.colour[i] = one
	grid.dominant = one
	grid.shares = {one: 1.0}


## The cell whose face shows the surface at [param on] (studs all three
## ways), which faces [param faces]: going out from just inside it, the last
## of the model's cells before the air; or, where the grid stops short of the
## surface, the first going in. A cell is coloured by what can be seen of it,
## as ObjToSchematic's smart averaging colours a block by its visible faces
## only: a sample stepped a fixed way in landed in a cell under the one that
## shows, and the one that shows took its colour from its neighbours. -1 for
## a surface the build hides: more of the model than [constant HIDDEN_STUDS]
## in front of it.
static func _shown_at(grid: Grid, on: Vector3, faces: Vector3) -> int:
	# Buried in another part of the model: a figure's head under its hair,
	# whose skin coloured the hair's cells. A quarter of a stud out, past the
	# third of a stud the surface is measured to, it is still inside, and a
	# quarter in too. Inside ahead and not behind, it is a face wound the
	# other way round from the rest, and faces the other way.
	var ahead: Vector3 = on + faces * BURIED_STUDS
	var behind: Vector3 = on - faces * BURIED_STUDS
	var normal: Vector3 = faces
	if grid.within(Vector3(ahead.x, ahead.y * PLATES, ahead.z)):
		if grid.within(Vector3(behind.x, behind.y * PLATES, behind.z)):
			return -1
		normal = -faces
	var cell: int = _cell_of(grid, on - normal * 0.3)
	if cell < 0:
		cell = _cell_of(grid, on)
	if cell < 0:
		for k: int in range(1, 5):
			cell = _cell_of(grid, on - normal * (0.3 + 0.25 * k))
			if cell >= 0:
				return cell
		return -1
	var from: Vector3 = on - normal * 0.3
	for k: int in range(1, ceili(HIDDEN_STUDS / 0.25) + 1):
		var next: int = _cell_of(grid, from + normal * (0.25 * k))
		if next < 0:
			return cell
		cell = next
	return -1


## The model's cell holding [param p] (studs all three ways), or -1.
static func _cell_of(grid: Grid, p: Vector3) -> int:
	var x: int = floori(p.x)
	var j: int = floori(p.y * PLATES)
	var z: int = floori(p.z)
	if x < 0 or z < 0 or j < 0 or x >= grid.across or z >= grid.deep or j >= grid.tall:
		return -1
	var i: int = grid.index(x, j, z)
	return i if grid.state[i] == 1 else -1


## The palette colour nearest a sampled one, among [param among] (indices)
## or all of them, as an eye judges (CIEDE2000); remembered by its key.
## Oklab's straight line sent a dark grey to Reddish Brown before Black, and
## Spot's black patches came out brown. The few nearest in a straight line
## in L*a*b* are weighed, which CIEDE2000 never puts more than twice as far.
static func _nearest(key: int, lab: Array[Vector3], known: Dictionary,
		among: Array) -> int:
	if known.has(key):
		return known[key]
	var c := Color(float((key >> 10) & 31) / 31.0, float((key >> 5) & 31) / 31.0,
		float(key & 31) / 31.0)
	var here: Vector3 = HiddenColours.lab(c)
	var straight := PackedFloat32Array()
	straight.resize(lab.size())
	var least: float = INF
	for n: int in lab.size():
		if not among.is_empty() and not among.has(n):
			straight[n] = INF
			continue
		straight[n] = here.distance_to(lab[n])
		least = minf(least, straight[n])
	var best: int = -1
	var gap: float = INF
	for n: int in lab.size():
		if straight[n] > 2.0 * least + 2.0:
			continue
		var d: float = de2000(here, lab[n])
		if d < gap:
			gap = d
			best = n
	known[key] = best
	return best


## How different two colours look, CIEDE2000 (Sharma, Wu and Dalal's
## formulation), from CIE L*a*b*: the measure the bench scores colour by.
static func de2000(one: Vector3, two: Vector3) -> float:
	const POW25_7 := 6103515625.0
	var c1: float = sqrt(one.y * one.y + one.z * one.z)
	var c2: float = sqrt(two.y * two.y + two.z * two.z)
	var cm: float = pow((c1 + c2) / 2.0, 7.0)
	var g: float = 0.5 * (1.0 - sqrt(cm / (cm + POW25_7)))
	var a1: float = (1.0 + g) * one.y
	var a2: float = (1.0 + g) * two.y
	var c1p: float = sqrt(a1 * a1 + one.z * one.z)
	var c2p: float = sqrt(a2 * a2 + two.z * two.z)
	var h1: float = fposmod(rad_to_deg(atan2(one.z, a1)), 360.0)
	var h2: float = fposmod(rad_to_deg(atan2(two.z, a2)), 360.0)
	var both: bool = c1p * c2p != 0.0
	var dh: float = 0.0
	if both:
		dh = h2 - h1
		if dh > 180.0:
			dh -= 360.0
		elif dh < -180.0:
			dh += 360.0
	var dl: float = two.x - one.x
	var dc: float = c2p - c1p
	var dhh: float = 2.0 * sqrt(c1p * c2p) * sin(deg_to_rad(dh) / 2.0)
	var lm: float = (one.x + two.x) / 2.0
	var cpm: float = (c1p + c2p) / 2.0
	var hm: float = h1 + h2
	if both:
		if absf(h1 - h2) <= 180.0:
			hm = (h1 + h2) / 2.0
		elif h1 + h2 < 360.0:
			hm = (h1 + h2 + 360.0) / 2.0
		else:
			hm = (h1 + h2 - 360.0) / 2.0
	var t: float = 1.0 - 0.17 * cos(deg_to_rad(hm - 30.0)) + 0.24 * cos(deg_to_rad(2.0 * hm)) \
		+ 0.32 * cos(deg_to_rad(3.0 * hm + 6.0)) - 0.20 * cos(deg_to_rad(4.0 * hm - 63.0))
	var theta: float = 30.0 * exp(-pow((hm - 275.0) / 25.0, 2.0))
	var cp7: float = pow(cpm, 7.0)
	var rc: float = 2.0 * sqrt(cp7 / (cp7 + POW25_7))
	var l50: float = (lm - 50.0) * (lm - 50.0)
	var x: float = dl / (1.0 + 0.015 * l50 / sqrt(20.0 + l50))
	var y: float = dc / (1.0 + 0.045 * cpm)
	var z: float = dhh / (1.0 + 0.015 * cpm * t)
	return sqrt(maxf(0.0, x * x + y * y + z * z - sin(deg_to_rad(2.0 * theta)) * rc * y * z))


## Every part in a colour the LEGO Group makes it in, by Rebrickable's elements: one
## whose colour no element of it comes in is laid in the nearest that does,
## as an eye judges, among the palette (or, cut to a few colours, among
## those). 1.3% of smooth's parts were in a colour no one can buy them in.
## One colour asked for is kept as asked. How many parts changed colour.
static func made_colours(model: Assistant.Model, options: Options, library: PartLibrary) -> int:
	if library == null or options.colours == "one":
		return 0
	var among: Array[int] = []
	if options.colours == "limit":
		for placement: Assistant.Placement in model.placements:
			if not among.has(placement.color):
				among.append(placement.color)
	else:
		for code: int in options.palette:
			among.append(code)
	var labs: Dictionary = {}
	for code: int in among:
		var known: PartLibrary.BrickColor = library.color(code)
		if known != null:
			labs[code] = HiddenColours.lab(known.rgb)
	var chosen: Dictionary = {}     ## "part/colour" -> colour
	var changed: int = 0
	for placement: Assistant.Placement in model.placements:
		var key: String = "%s/%d" % [placement.part, placement.color]
		if not chosen.has(key):
			var id: String = library.resolve(placement.part)
			var best: int = placement.color
			var own: PartLibrary.BrickColor = library.color(placement.color)
			if own != null and library.element_for(id, placement.color).is_empty():
				var here: Vector3 = HiddenColours.lab(own.rgb)
				var gap: float = INF
				for code: Variant in labs:
					if library.element_for(id, int(code)).is_empty():
						continue
					var d: float = de2000(here, labs[code])
					if d < gap:
						gap = d
						best = int(code)
			chosen[key] = best
		if int(chosen[key]) != placement.color:
			placement.color = int(chosen[key])
			changed += 1
	return changed


# -- laying -------------------------------------------------------------------


## The shape Shapes lays: the grid as its solid, the hollow as a cut kept
## clear, and the surface as asked. Its pieces kept, every one: what Shapes
## cannot join, [method mend] joins, and only what nothing joins is taken
## out, and said.
static func pattern(grid: Grid, options: Options) -> Dictionary:
	var size: Array = [grid.across, grid.tall, grid.deep]
	var cuts: Array = []
	if grid.hollowed > 0:
		cuts.append({Shapes.GRID: {"from": [0, 0, 0], "size": size, "colour_at": grid.hollow_at,
			"keep": true}})
	var shape: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": grid.dominant,
		"solids": [{Shapes.GRID: {"from": [0, 0, 0], "size": size, "colour_at": grid.colour_at}}],
		"cuts": cuts,
		"surface": "mixed" if options.smooth else "none",
		"top": "smooth" if options.smooth else "studs",
		"panels": options.smooth, "wedges": options.smooth,
		"stitch_first": true, "keep_pieces": true, "colour_shown": true, "bond": options.bond,
		"sold_in": options.palette,
		"plain_at": _plain_columns(grid),
		"prefer": grid.prefer, "most_cells": grid.across * grid.deep * grid.tall + 1}
	if options.near:
		shape["fine"] = grid.fine
	if not grid.cubes.is_empty():
		shape["sideways"] = true
		shape["cubes"] = grid.cubes
		if options.near:
			shape["side_fine"] = grid.side
	return shape


## The columns a cell the measuring added stands in (a part thinner than a
## stud, a join), laid plain: a wing two plates thick in tiles, wedges and
## slopes came apart in loose bits that were taken out, where in plates
## with their studs it held, as Surface plain lays it.
static func _plain_columns(grid: Grid) -> Dictionary:
	var out: Dictionary = {}
	if grid.added.is_empty():
		return out
	var column: int = grid.tall * grid.deep
	for i: int in grid.added.size():
		if grid.added[i] != 0 and grid.state[i] == 1:
			out[Vector2i(i / column, (i / grid.tall) % grid.deep)] = true
	return out


## Every part Brickify may lay, to be loaded before a worker reads them: by
## the numbers Shapes knows them by, and with [param library], the numbers
## LDraw gives them today, which is what goes down.
static func parts_needed(library: PartLibrary = null) -> PackedStringArray:
	var out: Dictionary = {}
	for table: Array in [Shapes.CORE_BRICKS, Shapes.CORE_PLATES, Shapes.TOPS]:
		for entry: Array in table:
			out[str(entry[2])] = true
	for table: Array in [Shapes.Plan.SLOPES, Shapes.Plan.INVERTED]:
		for entry: Array in table:
			for id: Variant in [entry[3], entry[4]]:
				if not str(id).is_empty():
					out[str(id)] = true
	for id: Variant in Shapes.ROUND_PLATES + Shapes.EDGE_PLATES + Patterns.WEDGES \
			+ Shapes.ROUND_BRICKS + Shapes.EDGE_BRICKS:
		out[str(id)] = true
	for id: String in ["30414", "11211", "87087", JOIN_PLATE_PART, ONE_PLATE, ONE_BRICK]:
		out[id] = true
	for id: Variant in Assistant.PANELS.values():
		out[str(id)] = true
	for table: Array in [STAND_ALONG_X, STAND_ONE_X]:
		for entry: Array in table:
			out[str(entry[1])] = true
	if library != null:
		for id: Variant in out.keys():
			out[library.resolve(str(id))] = true
	return PackedStringArray(out.keys())


## Measure, lay, stand, check and weigh: {"model", "report", "grid",
## "trouble", "ms"}, or {"error", "studs"} (a size that keeps it, or 0).
## Every part in [method parts_needed] must already be loaded.
##
## The report is the last check's, with what was done to it: "mended"
## (parts taken out), "tied" (parts added to join pieces), "joined" (the
## measuring's joins), "left_out" (each piece taken out, where and why),
## "lost" (the model's own cells no part fills, in regions), "stand" (the
## stand it was given and why, or empty), "balance" (Balance.Report) and
## "coverage".
static func build(mesh: MeshFile, options: Options, checker: Assistant,
		progress: Progress = null, suggest: bool = true) -> Dictionary:
	var library: PartLibrary = checker.library
	var times: Dictionary = {}
	var t0: int = Time.get_ticks_msec()
	# A try at another size (_keeps_at) stops with the run, and says nothing
	# over the run's own "trying it at".
	var telling: Progress = progress if suggest else null
	if telling != null:
		telling.say("measuring the model")
	var grid: Grid = voxelise(mesh, options, library)
	times["measure"] = Time.get_ticks_msec() - t0
	if _stopping(progress):
		return _stopped_run()
	for step: Variant in grid.ms:
		times["measure." + str(step)] = grid.ms[step]
	if grid.cells == 0:
		return _cannot(mesh, options, checker, progress, suggest,
			"at %d studs there is nothing of it to lay" % options.studs)
	if telling != null:
		telling.say("laying %s studs of it in bricks" % _comma(grid.cells))
	var t1: int = Time.get_ticks_msec()
	var trouble: Array = []
	var shape: Dictionary = pattern(grid, options)
	if progress != null:
		shape["stop"] = progress.stopped
	var made: Array = Shapes.lay(shape, trouble, library)
	var model := Assistant.Model.new()
	model.name = mesh.name
	for raw: Dictionary in made:
		var one: Dictionary = raw
		if one.has("panel"):
			# A brick with studs on its side, turned to face out, and the tile
			# laid on them flat against the side — as a design's are.
			var tile: Dictionary = checker._panel(one, str(one["panel"]))
			one.erase("panel")
			if not tile.is_empty():
				model.placements.append(Assistant.Placement.from_dict(tile))
		model.placements.append(Assistant.Placement.from_dict(one))
	# In colours the parts are made in before it is checked, so what the check
	# says of colours is said of these; and once more at the end, for the
	# joins and props it adds.
	var recoloured: int = made_colours(model, options, library)
	times["lay"] = Time.get_ticks_msec() - t1
	for step: Variant in (Shapes.last.get("ms", {}) as Dictionary):
		times["lay." + str(step)] = Shapes.last["ms"][step]
	for step: Variant in (Shapes.last.get("stitch", {}) as Dictionary):
		times["lay.stitch." + str(step)] = Shapes.last["stitch"][step]
	if _stopping(progress):
		return _stopped_run()
	if model.placements.is_empty():
		return _cannot(mesh, options, checker, progress, suggest, "at %d studs it came to no bricks%s"
			% [options.studs, ": " + "; ".join(PackedStringArray(trouble)) if not trouble.is_empty() else ""])
	if telling != null:
		telling.say("checking %s parts hold together" % _comma(model.placements.size()))
	var t2: int = Time.get_ticks_msec()
	var stand: Dictionary = {}
	if grid.stand.has_area():
		stand = lay_stand(model, grid.stand, grid.stand_why, checker, options.smooth,
			grid.stand_colour)
	times["check.stand"] = Time.get_ticks_msec() - t2
	var t3: int = Time.get_ticks_msec()
	var report: Dictionary = mend(model, checker, progress)
	times["check.mend"] = Time.get_ticks_msec() - t3
	if _stopping(progress):
		return _stopped_run()
	var balance: Balance.Report = report.get("balance")
	# Weighed, and it would tip after all, or all but (Balance's half a stud,
	# as the grid was judged): stood on a stand under what it stands on and
	# its centre of mass, and checked again.
	if options.stand and stand.is_empty() and balance != null and not balance.empty \
			and balance.needs_help() and not model.placements.is_empty():
		var under: Rect2i = _stand_under(model, checker, balance)
		if under.has_area():
			var why: String = ("it would tip, its centre of mass %s studs past what it stands on"
				% Balance.studs(-balance.margin)) if balance.margin < 0.0 else ("it would all but "
				+ "tip, its centre of mass %s studs inside what it stands on" % Balance.studs(
					balance.margin))
			stand = lay_stand(model, under, why, checker, options.smooth, grid.stand_colour)
			report = _again(mend(model, checker, progress), report)
			balance = report.get("balance")
	# A stud joint past its working load, propped: a pillar under what it
	# carries, down to whatever is under that or the ground, kept only if
	# fewer joints are past their load. A figure's arm held out on one stud,
	# a car's bumper hung under its body.
	report["propped"] = 0
	var t4: int = Time.get_ticks_msec()
	if _stopping(progress):
		return _stopped_run()
	if balance != null and balance.over > 0:
		var was: int = model.placements.size()
		var props: int = _prop(model, checker, balance)
		if props > 0:
			var after: Dictionary = checker._check(model, true, true, false, false)
			var weighed: Balance.Report = after.get("balance")
			if weighed != null and weighed.over < balance.over \
					and _loose(after) <= _loose(report) and bool(after.get("ok", false)) \
					== bool(report.get("ok", false)):
				report = _again(after, report)
				report["propped"] = props
			else:
				model.placements.resize(was)
	times["check.props"] = Time.get_ticks_msec() - t4
	times["check.checks"] = int(report.get("checks", 0))
	times["check.checks_ms"] = int(report.get("checks_ms", 0))
	times["check"] = Time.get_ticks_msec() - t2
	report["recoloured"] = recoloured + made_colours(model, options, library)
	var lift: int = STAND_PLATES if not stand.is_empty() else 0
	if not stand.is_empty():
		stand["lift"] = lift
	report["stand"] = stand
	report["joined"] = grid.joins
	report["thin"] = grid.thin
	report["left_out"] = grid.left_out + (report["left_out"] as Array)
	var covered: PackedByteArray = _covered(grid, model, checker, lift)
	var count: int = 0
	for one: int in covered:
		count += one
	report["coverage"] = float(count) / float(maxi(grid.cells, 1))
	report["lost"] = _lost(grid, covered)
	if model.placements.is_empty():
		return _cannot(mesh, options, checker, progress, suggest,
			"at %d studs nothing of it held together" % options.studs)
	var out: Dictionary = {"model": model, "report": report, "grid": grid, "trouble": trouble,
		"ms": times}
	# A bonded core is kept only if it keeps as much of the model. Where the
	# bonded build leaves a region of it out, it is laid again by the colours
	# measured and the one that fills more of the model kept, the time of both
	# counted. A temple scene at 48 studs, bonded, lost the moon on its stick,
	# which its stitch could no longer join, where the colours measured kept it.
	# Laid again with its slopes by the flag too, as before both: unbonded with
	# its slopes fitted by distance, the temple lost the moon again.
	if (options.bond or (options.near or options.snot) and options.smooth) \
			and not (report["lost"]["regions"] as Array).is_empty():
		var unbonded: Options = options.copied()
		unbonded.bond = false
		unbonded.near = false
		unbonded.snot = false
		var other: Dictionary = build(mesh, unbonded, checker, progress, false)
		if other.has("model"):
			var bonded: bool = float(other["report"]["coverage"]) <= float(report["coverage"])
			var kept: Dictionary = out if bonded else other
			var spent: Dictionary = other["ms"] if bonded else times
			for step: String in ["measure", "lay", "check"]:
				kept["ms"][step] = int(kept["ms"].get(step, 0)) + int(spent.get(step, 0))
			kept["report"]["bond"] = "bonded" if bonded else "laid again unbonded"
			out = kept
			report = out["report"]
	# What it lost is said; and where most of it went, a size that keeps it.
	if suggest and float(report["coverage"]) < 0.75:
		out["studs"] = _keeps_at(mesh, options, checker, progress)
	return out


## Whether [param progress] was told to stop.
static func _stopping(progress: Progress) -> bool:
	return progress != null and progress.stopped()


## What a run stopped part way gives back: nothing laid.
static func _stopped_run() -> Dictionary:
	return {"error": "stopped", "stopped": true, "studs": 0}


## A later check's report carrying what an earlier mend did: the parts it took
## out and put in, and what it said it left out.
static func _again(later: Dictionary, earlier: Dictionary) -> Dictionary:
	later["mended"] = int(later.get("mended", 0)) + int(earlier.get("mended", 0))
	later["checks"] = int(later.get("checks", 0)) + int(earlier.get("checks", 0))
	later["checks_ms"] = int(later.get("checks_ms", 0)) + int(earlier.get("checks_ms", 0))
	later["tied"] = int(later.get("tied", 0)) + int(earlier.get("tied", 0))
	later["left_out"] = (earlier.get("left_out", []) as Array) + (later.get("left_out", []) as Array)
	return later


## Props under the parts beyond each stud joint past its working load,
## worst first: the shortest pillar of 1 x 1s from under the part down onto
## a stud of anything else, or the ground. How many parts went in.
static func _prop(model: Assistant.Model, checker: Assistant, balance: Balance.Report) -> int:
	var before: int = model.placements.size()
	var room := Laid.new(model, checker)
	var done: Dictionary = {}
	for one: Balance.JointLoad in balance.joints.slice(0, 16):
		if one.ratio <= 1.0:
			break
		var index: int = one.beyond - 1
		if index < 0 or index >= before or done.has(index):
			continue
		done[index] = true
		var rest: Dictionary = {}
		for n: int in model.placements.size():
			if n != index:
				rest[n] = true
		room.pillar([index], rest, true, 24)
	return model.placements.size() - before


## Why nothing was laid, and the smallest size tried that lays it whole:
## {"error", "studs"}.
static func _cannot(mesh: MeshFile, options: Options, checker: Assistant, progress: Progress,
		suggest: bool, why: String) -> Dictionary:
	if _stopping(progress):
		return _stopped_run()
	var studs: int = _keeps_at(mesh, options, checker, progress) if suggest else 0
	var words: String = why
	if studs > 0:
		words += " — at %d studs it is laid whole" % studs
	elif suggest:
		words += " — nor at any size up to %d studs" % MOST_STUDS
	return {"error": words, "studs": studs}


## The smallest size above the one asked that lays the model whole (at
## least 95% of it in a part, nothing left out), by half again each try; 0
## for none up to [constant MOST_STUDS].
static func _keeps_at(mesh: MeshFile, options: Options, checker: Assistant,
		progress: Progress) -> int:
	var studs: int = options.studs
	while studs < MOST_STUDS:
		if _stopping(progress):
			return 0
		studs = mini(MOST_STUDS, maxi(studs + 4, ceili(studs * 1.5)))
		if progress != null:
			progress.say("trying it at %d studs" % studs)
		var tried := Options.new()
		tried.studs = studs
		tried.up = options.up
		tried.hollow = options.hollow
		tried.smooth = options.smooth
		tried.colours = options.colours
		tried.colour = options.colour
		tried.limit = options.limit
		tried.palette = options.palette
		tried.stand = options.stand
		var result: Dictionary = build(mesh, tried, checker, progress, false)
		if result.has("model"):
			var report: Dictionary = result["report"]
			if float(report["coverage"]) >= 0.95 and (report["left_out"] as Array).is_empty():
				return studs
	return 0


# -- the stand ------------------------------------------------------------------


## Under the model as laid: what it stands on and its centre of mass (as
## Balance found it) a stud and a half round, a stud more all round, inside
## its own plan.
static func _stand_under(model: Assistant.Model, checker: Assistant,
		balance: Balance.Report) -> Rect2i:
	var low := Vector2i(1 << 20, 1 << 20)
	var high := -low
	var plan_low := low
	var plan_high := high
	for placement: Assistant.Placement in model.placements:
		var part: Lbm.PartMesh = checker.library.mesh_for(placement.part)
		if part == null:
			continue
		var box: AABB = checker._transform(placement, part) * part.bounds
		var a := Vector2i(roundi(box.position.x / 20.0), roundi(box.position.z / 20.0))
		var b := Vector2i(roundi(box.end.x / 20.0), roundi(box.end.z / 20.0))
		plan_low = plan_low.min(a)
		plan_high = plan_high.max(b)
		if box.position.y < 4.0:
			low = low.min(a)
			high = high.max(b)
	if high.x <= low.x:
		return Rect2i()
	var centre := Vector2(balance.rest_centre.x, balance.rest_centre.z) / 20.0
	low = low.min(Vector2i(floori(centre.x - 1.5), floori(centre.y - 1.5))) - Vector2i.ONE
	high = high.max(Vector2i(ceili(centre.x + 1.5), ceili(centre.y + 1.5))) + Vector2i.ONE
	low = low.max(plan_low)
	high = high.min(plan_high)
	return Rect2i(low, high - low)


## A stand of [param rect] under the model, as a set gives a figure or an
## aircraft one: the model lifted onto it, two plates whose joints cross
## (strips two studs wide along x under strips along z, each strip's joints
## where the strips of the other layer run over them), and tiles over what
## the model does not stand on. {"rect", "why", "parts" (how many),
## "placements" (the stand's own, which a mend may renumber but not
## replace)}.
static func lay_stand(model: Assistant.Model, rect: Rect2i, why: String, checker: Assistant,
		tiles: bool = true, colour: int = STAND_COLOUR) -> Dictionary:
	for placement: Assistant.Placement in model.placements:
		placement.y += STAND_PLATES
	var first: int = model.placements.size()
	var add := func(part: String, x: int, y: int, z: int, rot: int) -> void:
		model.placements.append(Assistant.Placement.from_dict({"part": part,
			"color": colour, "x": x, "y": y, "z": z, "rot": rot}))
	# The lower layer: strips along x, two studs deep, their joints at even
	# studs from the corner, each strip starting long or short in turn.
	for k: int in range(0, rect.size.y, 2):
		var wide: int = mini(2, rect.size.y - k)
		var runs: Array = _runs(rect.size.x, 8 if (k / 2) % 2 == 0 else 4, 8 if wide == 2 else 6)
		var x: int = 0
		for length: int in runs:
			var entry: Array = _strip_part(length, wide, true)
			add.call(str(entry[1]), rect.position.x + x, 0, rect.position.y + k, int(entry[2]))
			x += length
	# The upper layer: strips along z, the first a stud wide so their sides
	# fall where the lower strips run on, their joints at odd studs, so every
	# joint of each layer has a strip of the other over or under it.
	var strips: Array = [[0, mini(1, rect.size.x)]]
	for a: int in range(1, rect.size.x, 2):
		strips.append([a, mini(2, rect.size.x - a)])
	for n: int in strips.size():
		var a: int = strips[n][0]
		var wide: int = strips[n][1]
		var runs: Array = _runs(rect.size.y, 3 if n % 2 == 0 else 1, 8 if wide == 2 else 6)
		var z: int = 0
		for length: int in runs:
			var entry: Array = _strip_part(length, wide, false)
			add.call(str(entry[1]), rect.position.x + a, 1, rect.position.y + z, int(entry[2]))
			z += length
	if tiles:
		_tile_stand(model, rect, first, checker, colour)
	return {"rect": rect, "why": why, "parts": model.placements.size() - first,
		"placements": model.placements.slice(first)}


## A strip [param length] long cut into plates: [param first] studs, then
## as long as plates come ([param longest]), five and seven as an even
## length and a 1. So every joint is an even number of studs on from the
## first one: the first's length says whether those are even or odd.
static func _runs(length: int, first: int, longest: int) -> Array:
	var out: Array = []
	var left: int = length
	var start: int = mini(first, left)
	if start > 0:
		out.append(start)
		left -= start
	while left > 0:
		var next: int = mini(longest, left)
		if next == 7 or next == 5:
			next -= 1
		out.append(next)
		left -= next
	return out


## The plate for [param length] studs of a strip [param wide] studs (1 or
## 2), along x or along z: [length, part, rot].
static func _strip_part(length: int, wide: int, along_x: bool) -> Array:
	var table: Array = (STAND_ALONG_X if along_x else STAND_ALONG_Z) if wide == 2 \
		else (STAND_ONE_X if along_x else STAND_ONE_Z)
	for entry: Array in table:
		if int(entry[0]) == length:
			return entry
	return table[table.size() - 1]


## Tiles over the stand's top where the model does not stand on it, so it
## reads as a stand and not as a baseplate.
static func _tile_stand(model: Assistant.Model, rect: Rect2i, first: int,
		checker: Assistant, colour: int) -> void:
	var taken: Dictionary = {}      ## Vector2i -> true: the model stands there
	for index: int in first:
		var placement: Assistant.Placement = model.placements[index]
		if placement.y > STAND_PLATES + 3:
			continue
		var part: Lbm.PartMesh = checker.library.mesh_for(placement.part)
		if part == null:
			continue
		var box: AABB = checker._transform(placement, part) * part.bounds
		if box.position.y > (STAND_PLATES + 1) * 8.0 - 1.0:
			continue
		for x: int in range(floori(box.position.x / 20.0 + 0.01), ceili(box.end.x / 20.0 - 0.01)):
			for z: int in range(floori(box.position.z / 20.0 + 0.01), ceili(box.end.z / 20.0 - 0.01)):
				taken[Vector2i(x, z)] = true
	var free: Dictionary = {}
	for x: int in range(rect.position.x, rect.end.x):
		for z: int in range(rect.position.y, rect.end.y):
			if not taken.has(Vector2i(x, z)):
				free[Vector2i(x, z)] = true
	for z: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var corner := Vector2i(x, z)
			if not free.has(corner):
				continue
			for entry: Array in Shapes.TOPS:
				var w: int = int(entry[0])
				var d: int = int(entry[1])
				var fits: bool = true
				for a: int in w:
					for b: int in d:
						fits = fits and free.has(corner + Vector2i(a, b))
				if not fits:
					continue
				for a: int in w:
					for b: int in d:
						free.erase(corner + Vector2i(a, b))
				model.placements.append(Assistant.Placement.from_dict({"part": str(entry[2]),
					"color": colour, "x": x, "y": STAND_PLATES, "z": z, "rot": int(entry[3])}))
				break


# -- what it fills, and what it lost ------------------------------------------


## Each cell of the model a part fills, its studs and plates inside a part
## (1), as laid [param lift] plates up.
static func _covered(grid: Grid, model: Assistant.Model, checker: Assistant,
		lift: int = 0) -> PackedByteArray:
	var covered := PackedByteArray()
	covered.resize(grid.state.size())
	for placement: Assistant.Placement in model.placements:
		var part: Lbm.PartMesh = checker.library.mesh_for(placement.part)
		if part == null:
			continue
		var box: AABB = checker._transform(placement, part) * part.bounds
		box.position.y -= lift * 8.0
		for x: int in range(maxi(0, roundi(box.position.x / 20.0)),
				mini(grid.across, roundi(box.end.x / 20.0))):
			for z: int in range(maxi(0, roundi(box.position.z / 20.0)),
					mini(grid.deep, roundi(box.end.z / 20.0))):
				for j: int in range(maxi(0, floori(box.position.y / 8.0)),
						mini(grid.tall, ceili(box.end.y / 8.0))):
					var centre: float = (j + 0.5) * 8.0
					if centre < box.position.y or centre > box.end.y - 3.9:
						continue
					var i: int = grid.index(x, j, z)
					if grid.state[i] == 1:
						covered[i] = 1
	return covered


## How much of the model the parts fill: its studs and plates inside a part,
## over all of them. A model can pass the check having lost an ear.
static func coverage(grid: Grid, model: Assistant.Model, checker: Assistant,
		lift: int = 0) -> float:
	if grid.cells == 0:
		return 0.0
	var count: int = 0
	for one: int in _covered(grid, model, checker, lift):
		count += one
	return float(count) / float(grid.cells)


## The model's cells no part fills, in regions face to face, each big enough
## to be a feature (a spout, an ear: a hundredth of the model or six cells)
## said where it is: {"share", "regions": [{"cells", "low", "high", "why"}]}.
## Coverage alone said 98% for a teapot that had lost its spout and handle.
static func _lost(grid: Grid, covered: PackedByteArray) -> Dictionary:
	var total: int = grid.state.size()
	var seen := PackedByteArray()
	seen.resize(total)
	var uncovered: int = 0
	var regions: Array = []
	var least: int = maxi(6, grid.cells / 100)
	for start: int in total:
		if grid.state[start] != 1 or covered[start] == 1 or seen[start] == 1:
			continue
		var region := PackedInt32Array([start])
		seen[start] = 1
		var n: int = 0
		while n < region.size():
			for next: int in _faces(grid, region[n]):
				if grid.state[next] == 1 and covered[next] == 0 and seen[next] == 0:
					seen[next] = 1
					region.append(next)
			n += 1
		uncovered += region.size()
		if region.size() >= least:
			regions.append(_described(grid, region, "no part fills it"))
	regions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["cells"]) > int(b["cells"]))
	return {"share": float(uncovered) / float(maxi(grid.cells, 1)), "regions": regions}


## Where a piece or region is on the model, in words a person can find it
## by: "at its top left, toward the front".
static func where_on(grid: Grid, low: Vector3i, high: Vector3i) -> String:
	var middle := Vector3(low + high) / 2.0 + Vector3(0.5, 0.5, 0.5)
	var words: PackedStringArray = []
	var up: float = middle.y / float(maxi(grid.tall, 1))
	words.append("top" if up > 0.67 else ("bottom" if up < 0.33 else "middle"))
	var side: float = middle.x / float(maxi(grid.across, 1))
	if side < 0.33:
		words.append("left")
	elif side > 0.67:
		words.append("right")
	var along: float = middle.z / float(maxi(grid.deep, 1))
	var toward: String = ""
	if along < 0.33:
		toward = ", toward the back"
	elif along > 0.67:
		toward = ", toward the front"
	return "at its %s%s" % [" ".join(words), toward]


# -- saying what it came to -----------------------------------------------------


## What a Brickify came to, in words, for the panel's status line and a
## session's answer: whether it is one piece and stands (weighed, not
## assumed), on what, what was joined, and what was left out, where and
## why. "buildable" only when it is one piece, passes the check, stands and
## no stud joint is past its working load.
static func said(result: Dictionary) -> String:
	var report: Dictionary = result["report"]
	var grid: Grid = result["grid"]
	var out := PackedStringArray()
	var one_piece: bool = bool(report.get("ok", false)) and int(report.get("pieces", 0)) <= 1
	var balance: Balance.Report = report.get("balance")
	var weighed: bool = balance != null and not balance.empty
	var stands: bool = weighed and balance.stands()
	var over: int = balance.over if weighed else 0
	if one_piece and stands and over == 0:
		out.append("buildable in one piece")
	elif one_piece:
		out.append("in one piece")
	else:
		out.append("not buildable as laid (%s)" % str(report.get("summary", "")))
	var stand: Dictionary = report.get("stand", {})
	var on: String
	if not stand.is_empty():
		var rect: Rect2i = stand["rect"]
		on = "on a stand %d × %d studs, added because %s" % [rect.size.x, rect.size.y,
			str(stand["why"])]
	else:
		on = "on %d stud%s of its own" % [grid.on_ground, "" if grid.on_ground == 1 else "s"]
	if weighed:
		if balance.margin >= 0.0:
			out.append("it stands %s, %s studs inside its %s edge" % [on,
				Balance.studs(balance.margin), balance.edge])
		else:
			out.append("it would tip %s, %s studs past its %s edge" % [on,
				Balance.studs(-balance.margin), balance.edge])
		if over > 0:
			out.append("%d stud joint%s past %s working load" % [over, "" if over == 1 else "s",
				"its" if over == 1 else "their"])
	var joins: Array = report.get("joined", [])
	var tied: int = int(report.get("tied", 0))
	if not joins.is_empty() or tied > 0:
		var ways: Dictionary = {}
		for one: Dictionary in joins:
			var way: String = "a pillar to the ground" if str(one["to"]) == "the ground" \
				else ("a pillar" if str(one["way"]) == "pillar" else "a bridge")
			ways[way] = int(ways.get(way, 0)) + 1
		var named := PackedStringArray()
		for way: String in ways:
			named.append(way if int(ways[way]) == 1 else "%d × %s" % [ways[way], way])
		if tied > 0:
			named.append("%d part%s across the joints" % [tied, "" if tied == 1 else "s"])
		out.append("joined, not dropped: %s" % ", ".join(named))
	var propped: int = int(report.get("propped", 0))
	if propped > 0:
		out.append("%d part%s propping what was held out on too few studs" % [propped,
			"" if propped == 1 else "s"])
	if grid.thin > 0:
		out.append("its parts thinner than a stud kept a stud thick")
	var gone := PackedStringArray()
	for one: Dictionary in report.get("left_out", []):
		var what: String = ("%d part%s" % [one["parts"], "" if int(one["parts"]) == 1 else "s"]) \
			if one.has("parts") else ("%d studs and plates" % int(one["cells"]))
		gone.append("%s %s (%s)" % [what, where_on(grid, one["low"], one["high"]), one["why"]])
	var lost: Dictionary = report.get("lost", {})
	for one: Dictionary in (lost.get("regions", []) as Array).slice(0, 3):
		gone.append("%d studs and plates %s that no part fills" % [int(one["cells"]),
			where_on(grid, one["low"], one["high"])])
	if gone.is_empty():
		out.append("nothing of it left out")
	else:
		out.append("left out: %s" % "; ".join(gone.slice(0, 4)))
	if int(result.get("studs", 0)) > 0:
		out.append("at %d studs it is laid whole" % int(result["studs"]))
	return "; ".join(out)


# -- checking and mending -------------------------------------------------------


## Checked and weighed as check_design checks a design, and mended until it
## passes in one piece. Join, don't drop: a piece apart, or parts nothing
## holds, are first joined to the rest by the least that reaches (_tie), and
## only what nothing joins is taken out, and said. A part overlapping one
## before it is taken out. The report of the last check, with "mended" (how
## many parts came out), "tied" (how many went in to join) and "left_out"
## (each round's parts taken out: {"parts", "low", "high" in studs and plates,
## "why"}).
##
## In as few checks as it can, each of which on a big model is most of its
## time: what collides goes in one round, two rounds of joins at most, and
## then what is still apart and what floats go together. Twelve rounds of one
## kind at a time took a temple scene's check from 6 s to 290.
static func mend(model: Assistant.Model, checker: Assistant,
		progress: Progress = null) -> Dictionary:
	var clock: Dictionary = {"checks": 0, "checks_ms": 0}
	var report: Dictionary = _timed(model, checker, clock)
	var taken_out: int = 0
	var tied: int = 0
	var tying: int = 0
	var left_out: Array = []
	for _round: int in 8:
		if _stopping(progress):
			break
		# A model with nothing in it comes back without a count of pieces.
		if bool(report.get("ok", false)) and int(report.get("pieces", 0)) <= 1:
			break
		# What runs into what: by the lattice, or by the parts' real shapes (the
		# exact check), which the lattice let through — a curved slope's
		# underside in the brick beside it. Taken out first, alone: what it
		# leaves held is checked again.
		var drop: Dictionary = {}
		var kinds: Array = report.get("kinds", [])
		if kinds.has("overlap") or kinds.has("unknown part") or kinds.has("not loaded"):
			drop = _overlapping(model, checker)
		if kinds.has("collision"):
			for index: Variant in report.get("colliding", []):
				drop[int(index)] = true
		if not drop.is_empty():
			left_out.append(_parts_said(model, drop, checker,
				"it ran into the part beside it, or never arrived"))
			taken_out += _take_out(model, drop)
			report = _timed(model, checker, clock)
			continue
		var loose: int = _loose(report)
		if loose > 1 and tying < 2:
			tying += 1
			var was: int = model.placements.size()
			var added: int = _tie(model, checker, report)
			if added > 0:
				var after: Dictionary = _timed(model, checker, clock)
				# Kept only if it joined something: parts that join nothing are
				# taken back, not left to be taken out as floating.
				if _loose(after) < loose:
					tied += added
					report = after
					continue
				model.placements.resize(was)
			tying = 2
		# What nothing could join or hold, taken out together, and said.
		var floating: Dictionary = {}
		for index: Variant in report.get("floating", []) + report.get("unheld", []):
			floating[int(index)] = true
		var apart: Dictionary = _apart(model, checker) if int(report.get("pieces", 0)) > 1 else {}
		for index: Variant in floating:
			apart.erase(index)
		if floating.is_empty() and apart.is_empty():
			break
		# Never the body: when most of it is what nothing holds, it is kept and
		# the check says so, rather than the model taken out for its crumbs.
		if floating.size() * 2 > model.placements.size():
			break
		if not floating.is_empty():
			left_out.append(_parts_said(model, floating, checker, "nothing could hold it up"))
		if not apart.is_empty():
			left_out.append(_parts_said(model, apart, checker, "nothing could join it to the rest"))
		floating.merge(apart)
		taken_out += _take_out(model, floating)
		report = _timed(model, checker, clock)
	# Weighed already if it passed whole; what ends the mend otherwise is
	# weighed now, for the line to say whether it stands.
	if not report.has("balance") and not model.placements.is_empty():
		report = _timed(model, checker, clock, true)
	report["mended"] = taken_out
	report["tied"] = tied
	report["left_out"] = left_out
	report["checks"] = clock["checks"]
	report["checks_ms"] = clock["checks_ms"]
	return report


## The check, counted and timed into [param clock]; weighed only when it
## passes in one piece, which is when the mend stops, or [param weigh]; and
## without its advice, which nothing here reads: a quarter of each check of
## a forty-stud scan.
static func _timed(model: Assistant.Model, checker: Assistant, clock: Dictionary,
		weigh: bool = false) -> Dictionary:
	var t: int = Time.get_ticks_msec()
	var report: Dictionary = checker._check(model, true, weigh, true, false)
	clock["checks"] = int(clock["checks"]) + 1
	clock["checks_ms"] = int(clock["checks_ms"]) + Time.get_ticks_msec() - t
	return report


## The placements [param drop] names taken out of [param model]: how many.
static func _take_out(model: Assistant.Model, drop: Dictionary) -> int:
	var kept: Array[Assistant.Placement] = []
	for index: int in model.placements.size():
		if not drop.has(index):
			kept.append(model.placements[index])
	var gone: int = model.placements.size() - kept.size()
	model.placements = kept
	return gone


## How far a check is from one piece that holds: its pieces, and the parts
## nothing holds up, by the lattice (floating) or by the parts' real shapes
## (unheld). One when it is whole.
static func _loose(report: Dictionary) -> int:
	return maxi(1, int(report.get("pieces", 0))) + (report.get("floating", []) as Array).size() \
		+ (report.get("unheld", []) as Array).size()


## The placements [param drop] says, as one: how many, their corners in
## studs and plates, and why they went.
static func _parts_said(model: Assistant.Model, drop: Dictionary, checker: Assistant,
		why: String) -> Dictionary:
	var low := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var high := -low
	for index: Variant in drop:
		var placement: Assistant.Placement = model.placements[int(index)]
		var part: Lbm.PartMesh = checker.library.mesh_for(placement.part)
		var at := Vector3i(roundi(placement.x), roundi(placement.y), roundi(placement.z))
		low = low.min(at)
		high = high.max(at)
		if part != null:
			var box: AABB = checker._transform(placement, part) * part.bounds
			high = high.max(Vector3i(roundi(box.end.x / 20.0) - 1, roundi(box.end.y / 8.0) - 1,
				roundi(box.end.z / 20.0) - 1))
	return {"parts": drop.size(), "low": low, "high": high, "why": why}


## What stands where in a laid model, on the stud and plate grid: each
## cell's part, each part's lowest plate, and the studs standing up into each
## cell, with the lattice the check uses to say whether a part fits. What
## [method _tie] joins pieces with.
class Laid extends RefCounted:
	var model: Assistant.Model
	var checker: Assistant
	var lattice := BrickLattice.new()
	var owner: Dictionary = {}       ## Vector3i(x, plate, z) -> index
	var studs: Dictionary = {}       ## Vector3i -> index whose stud reaches up into it
	var low_of: Dictionary = {}      ## index -> its lowest plate
	var cells_of: Dictionary = {}    ## index -> Array[Vector3i]

	func _init(laid: Assistant.Model, check: Assistant) -> void:
		model = laid
		checker = check
		lattice.keeps_columns = false
		for index: int in model.placements.size():
			take(index)

	func take(index: int) -> void:
		var placement: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = checker.library.mesh_for(placement.part)
		if part == null:
			return
		var at: Transform3D = checker._transform(placement, part)
		lattice.occupy_boxes(index + 1, checker.builder.boxes_for(part, at))
		var box: AABB = at * part.bounds
		var j0: int = roundi(box.position.y / 8.0)
		var j1: int = maxi(j0 + 1, ceili((box.end.y - 4.5) / 8.0))
		var cells: Array[Vector3i] = []
		for x: int in range(roundi(box.position.x / 20.0), maxi(roundi(box.end.x / 20.0),
				roundi(box.position.x / 20.0) + 1)):
			for z: int in range(roundi(box.position.z / 20.0), maxi(roundi(box.end.z / 20.0),
					roundi(box.position.z / 20.0) + 1)):
				for j: int in range(j0, j1):
					var cell := Vector3i(x, j, z)
					owner[cell] = index
					cells.append(cell)
		cells_of[index] = cells
		low_of[index] = j0
		for connector: Lbm.Connector in part.connectors:
			if connector.kind != "stud" or connector.gender != "male" \
					or (at.basis * connector.axis).normalized().dot(Vector3.UP) < 0.9:
				continue
			var tip: Vector3 = at * (connector.position + connector.axis.normalized() * 5.0)
			studs[Vector3i(floori(tip.x / 20.0), floori(tip.y / 8.0), floori(tip.z / 20.0))] = index

	## Whether a part fits there, and if it does, in: the index it went in at,
	## or -1.
	func put(part_id: String, colour: int, x: int, y: int, z: int, rot: int) -> int:
		if y < 0:
			return -1
		var part: Lbm.PartMesh = checker.library.mesh_for(part_id)
		if part == null:
			return -1
		var placement := Assistant.Placement.from_dict({"part": part_id, "color": colour,
			"x": x, "y": y, "z": z, "rot": rot})
		var boxes: PackedInt32Array = checker.builder.boxes_for(part,
			checker._transform(placement, part))
		if lattice.collides_boxes(boxes):
			return -1
		model.placements.append(placement)
		take(model.placements.size() - 1)
		return model.placements.size() - 1

	func open_at(cell: Vector3i) -> bool:
		return cell.y >= 0 and not owner.has(cell)

	## Whether a stud rising into [param cell] from the plate under it goes
	## into part [param index], by the part's real cover and not its box: an
	## inverted slope's box reaches out over air its underside never does, and
	## a plate under it there joined nothing and stood alone.
	func takes(cell: Vector3i, index: int) -> bool:
		var tip := Vector3(cell.x * 20.0 + 10.0, cell.y * 8.0 + 5.0, cell.z * 20.0 + 10.0)
		return lattice.brick_at(BrickLattice.to_cell(tip)) == index + 1

	## A 1 x 2 plate under the joint where a part of [param piece] and one of
	## [param rest] stand side by side on the same plate, its studs in both;
	## or over it, on a stud of each. Whether one went in.
	func across(piece: Array, rest: Dictionary) -> bool:
		for over: bool in [false, true]:
			for index: Variant in piece:
				var colour: int = model.placements[int(index)].color
				for cell: Vector3i in cells_of.get(int(index), []):
					for step: Vector2i in Shapes.OUT:
						var next := Vector3i(cell.x + step.x, cell.y, cell.z + step.y)
						var at := Vector3i(mini(cell.x, next.x), 0, mini(cell.z, next.z))
						var rot: int = 0 if step.x != 0 else 1
						if not over:
							var below := Vector3i(cell.x, cell.y - 1, cell.z)
							var other: int = int(owner.get(next, -1))
							if cell.y != int(low_of[int(index)]) or not rest.has(other) \
									or not open_at(below) or not open_at(next - Vector3i(0, 1, 0)) \
									or not takes(cell, int(index)) or not takes(next, other):
								continue
							if put(JOIN_PLATE_PART, colour, at.x, cell.y - 1, at.z, rot) >= 0:
								return true
						else:
							var up := Vector3i(cell.x, cell.y + 1, cell.z)
							var beside := Vector3i(next.x, next.y + 1, next.z)
							if int(studs.get(up, -1)) != int(index) \
									or not rest.has(int(studs.get(beside, -1))) \
									or not open_at(up) or not open_at(beside):
								continue
							if put(JOIN_PLATE_PART, colour, at.x, cell.y + 1, at.z, rot) >= 0:
								return true
		return false

	## A pillar of 1 x 1 bricks and plates from under [param piece] down onto
	## a stud of [param rest], or onto the ground when [param ground]; or up
	## from a stud of the piece to the underside of the rest. The shortest
	## there is, no taller than [param most] plates. Whether one went in.
	func pillar(piece: Array, rest: Dictionary, ground: bool, most: int) -> bool:
		var best: Array = []             ## [x, from plate, plates, colour]
		for index: Variant in piece:
			var colour: int = model.placements[int(index)].color
			for cell: Vector3i in cells_of.get(int(index), []):
				# Down, from its underside.
				if cell.y == int(low_of[int(index)]) and open_at(cell - Vector3i(0, 1, 0)) \
						and takes(cell, int(index)):
					var j: int = cell.y - 1
					while j >= 0 and open_at(Vector3i(cell.x, j, cell.z)):
						j -= 1
					var lands: bool = j < 0 and ground
					if j >= 0:
						lands = rest.has(int(studs.get(Vector3i(cell.x, j + 1, cell.z), -1)))
					var plates: int = cell.y - 1 - j
					if lands and plates <= most and (best.is_empty() or plates < int(best[2])):
						best = [cell.x, j + 1, plates, colour, cell.z]
				# Up, from a stud of its top.
				var up := Vector3i(cell.x, cell.y + 1, cell.z)
				if int(studs.get(up, -1)) == int(index) and open_at(up):
					var j: int = up.y
					while j - up.y <= most and open_at(Vector3i(cell.x, j, cell.z)):
						j += 1
					var other: int = int(owner.get(Vector3i(cell.x, j, cell.z), -1))
					var plates: int = j - up.y
					if rest.has(other) and plates <= most and takes(Vector3i(cell.x, j, cell.z), other) \
							and (best.is_empty() or plates < int(best[2])):
						best = [cell.x, up.y, plates, colour, cell.z]
		if best.is_empty():
			return false
		var y: int = int(best[1])
		var left: int = int(best[2])
		var made: Array = []
		while left > 0:
			var tall: int = 3 if left >= 3 else 1
			var at: int = put(ONE_BRICK if tall == 3 else ONE_PLATE, int(best[3]), int(best[0]), y,
				int(best[4]), 0)
			if at < 0:
				# Taken back: a pillar part way is a part held by nothing.
				for n: int in made:
					model.placements.remove_at(n)
				return false
			made.push_front(at)
			y += tall
			left -= tall
		return true


## Pieces apart joined to the largest, and parts nothing holds up joined to
## what is held: each by the least that reaches, a 1 x 2 plate across a
## joint where the two stand side by side, else the shortest pillar of 1 x 1s
## from one onto the other's studs. A largest piece none of which is held is
## stood on the ground. One join a piece a round. How many parts went in.
static func _tie(model: Assistant.Model, checker: Assistant, report: Dictionary) -> int:
	var pieces: Array = (report.get("each_piece", []) as Array).duplicate()
	if pieces.is_empty():
		return 0
	pieces.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	var floating: Dictionary = {}
	for index: Variant in report.get("floating", []) + report.get("unheld", []):
		floating[int(index)] = true
	var before: int = model.placements.size()
	var room := Laid.new(model, checker)
	# What is held of the largest piece; each part of it nothing holds up
	# (resting under an overhang it does not clutch) is a piece to join too.
	var rest: Dictionary = {}
	var groups: Array = []
	for index: Variant in pieces[0]:
		if floating.has(int(index)):
			groups.append([int(index)])
		else:
			rest[int(index)] = true
	if rest.is_empty():
		# None of it held: a pillar down to the ground, or onto anything that
		# is held (a stand it floats over).
		groups = []
		var held: Dictionary = {}
		for index: int in before:
			if not floating.has(index):
				held[index] = true
		for index: Variant in pieces[0]:
			held.erase(int(index))
		if room.pillar(pieces[0], held, true, 24):
			for index: Variant in pieces[0]:
				rest[int(index)] = true
	groups.append_array(pieces.slice(1))
	for piece: Array in groups:
		var made: int = model.placements.size()
		if room.across(piece, rest) or room.pillar(piece, rest, false, 12):
			for index: Variant in piece:
				rest[int(index)] = true
			for index: int in range(made, model.placements.size()):
				rest[index] = true
	return model.placements.size() - before


## The placements that run into one before them, or whose part is not here.
static func _overlapping(model: Assistant.Model, checker: Assistant) -> Dictionary:
	var lattice := BrickLattice.new()
	lattice.keeps_columns = false
	var out: Dictionary = {}
	for index: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = checker.library.mesh_for(placement.part)
		if part == null:
			out[index] = true
			continue
		var boxes: PackedInt32Array = checker.builder.boxes_for(part,
			checker._transform(placement, part))
		if lattice.collides_boxes(boxes):
			out[index] = true
			continue
		lattice.occupy_boxes(index + 1, boxes)
	return out


## Every placement but those of the largest piece, pieces found as the
## check finds them: a part on another, or a stud of one in the other.
static func _apart(model: Assistant.Model, checker: Assistant) -> Dictionary:
	var lattice := BrickLattice.new()
	lattice.keeps_columns = false
	var boxes_of: Dictionary = {}
	var at_of: Dictionary = {}
	for index: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = checker.library.mesh_for(placement.part)
		if part == null:
			continue
		var at: Transform3D = checker._transform(placement, part)
		var boxes: PackedInt32Array = checker.builder.boxes_for(part, at)
		if lattice.collides_boxes(boxes):
			continue
		lattice.occupy_boxes(index + 1, boxes)
		boxes_of[index] = boxes
		at_of[index] = at
	var joined: Dictionary = {}
	for index: Variant in boxes_of:
		joined[index] = []
	for index: Variant in boxes_of:
		var packed: PackedInt32Array = boxes_of[index]
		var over := PackedInt32Array()
		over.resize(packed.size())
		for n: int in range(0, packed.size(), 6):
			over[n] = packed[n]
			over[n + 1] = packed[n + 4]
			over[n + 2] = packed[n + 2]
			over[n + 3] = packed[n + 3]
			over[n + 4] = packed[n + 4] + 1
			over[n + 5] = packed[n + 5]
		for above: int in lattice.blockers_boxes(over, int(index) + 1):
			if above > 0 and joined.has(above - 1):
				(joined[index] as Array).append(above - 1)
				(joined[above - 1] as Array).append(index)
		var part: Lbm.PartMesh = checker.library.mesh_for(model.placements[int(index)].part)
		for connector: Lbm.Connector in part.connectors:
			if connector.kind != "stud" or connector.gender != "male":
				continue
			var tip: Vector3 = (at_of[index] as Transform3D) * (connector.position
				+ connector.axis.normalized() * 5.0)
			var reached: int = lattice.brick_at(BrickLattice.to_cell(tip))
			if reached > 0 and reached - 1 != int(index) and joined.has(reached - 1):
				(joined[index] as Array).append(reached - 1)
				(joined[reached - 1] as Array).append(index)
	var best: Array = []
	var seen: Dictionary = {}
	for start: Variant in boxes_of:
		if seen.has(start):
			continue
		var piece: Array = [start]
		seen[start] = true
		var n: int = 0
		while n < piece.size():
			for next: Variant in joined[piece[n]]:
				if not seen.has(next):
					seen[next] = true
					piece.append(next)
			n += 1
		if piece.size() > best.size():
			best = piece
	var keep: Dictionary = {}
	for index: Variant in best:
		keep[int(index)] = true
	var out: Dictionary = {}
	for index: int in model.placements.size():
		if not keep.has(index):
			out[index] = true
	return out


static func _comma(value: int) -> String:
	var text: String = str(value)
	var out := ""
	for index: int in text.length():
		if index > 0 and (text.length() - index) % 3 == 0:
			out += ","
		out += text[index]
	return out
