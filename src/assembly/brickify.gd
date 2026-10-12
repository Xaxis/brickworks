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
## How flat a facet has to be to take straight slopes: its corners' normals
## within this of its own.
const FLAT_DEGREES := 4.0


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


## What a worker says it is doing, for the dialog to show.
class Progress extends RefCounted:
	var _lock := Mutex.new()
	var _said: String = ""

	func say(what: String) -> void:
		_lock.lock()
		_said = what
		_lock.unlock()

	func said() -> String:
		_lock.lock()
		var out: String = _said
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

	## Whether [param p] is inside the surface, to a third of a stud.
	func inside(p: Vector3) -> bool:
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
	_one_piece(grid)
	if options.hollow:
		_hollow(grid)
	for i: int in total:
		if grid.state[i] == 1:
			grid.cells += 1
	_colour(grid, mesh, points, outward, options, library)
	return grid


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


## Only the largest piece: a speck of dust in a scan, or a part of a sculpt
## not touching the rest, would be bricks held by nothing.
static func _one_piece(grid: Grid) -> void:
	var total: int = grid.state.size()
	var seen := PackedByteArray()
	seen.resize(total)
	var best := PackedInt32Array()
	var others: Array = []
	var steps: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
		Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for x: int in grid.across:
		for z: int in grid.deep:
			for j: int in grid.tall:
				var start: int = grid.index(x, j, z)
				if grid.state[start] != 1 or seen[start] == 1:
					continue
				var piece := PackedInt32Array([start])
				var stack: Array[Vector3i] = [Vector3i(x, j, z)]
				seen[start] = 1
				while not stack.is_empty():
					var here: Vector3i = stack.pop_back()
					for step: Vector3i in steps:
						var next: Vector3i = here + step
						if next.x < 0 or next.y < 0 or next.z < 0 or next.x >= grid.across \
								or next.y >= grid.tall or next.z >= grid.deep:
							continue
						var i: int = grid.index(next.x, next.y, next.z)
						if grid.state[i] == 1 and seen[i] == 0:
							seen[i] = 1
							piece.append(i)
							stack.append(next)
				if piece.size() > best.size():
					if not best.is_empty():
						others.append(best)
					best = piece
				else:
					others.append(piece)
	for piece: PackedInt32Array in others:
		for i: int in piece:
			grid.state[i] = 2
		grid.dropped += piece.size()


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
		lab.append(Mosaic._oklab(known.rgb if known != null else Color.MAGENTA))
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
					var cell: int = _cell_of(grid, on - normal * 0.3)
					if cell < 0:
						cell = _cell_of(grid, on)
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
## or all of them; remembered by its key.
static func _nearest(key: int, lab: Array[Vector3], known: Dictionary,
		among: Array) -> int:
	if known.has(key):
		return known[key]
	var c := Color(float((key >> 10) & 31) / 31.0, float((key >> 5) & 31) / 31.0,
		float(key & 31) / 31.0)
	var here: Vector3 = Mosaic._oklab(c)
	var best: int = -1
	var gap: float = INF
	for n: int in lab.size():
		if not among.is_empty() and not among.has(n):
			continue
		var d: float = here.distance_squared_to(lab[n])
		if d < gap:
			gap = d
			best = n
	known[key] = best
	return best


# -- laying -------------------------------------------------------------------


## The shape Shapes lays: the grid as its solid, the hollow as a cut kept
## clear, and the surface as asked.
static func pattern(grid: Grid, options: Options) -> Dictionary:
	var size: Array = [grid.across, grid.tall, grid.deep]
	var cuts: Array = []
	if grid.hollowed > 0:
		cuts.append({Shapes.GRID: {"from": [0, 0, 0], "size": size, "colour_at": grid.hollow_at,
			"keep": true}})
	return {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": grid.dominant,
		"solids": [{Shapes.GRID: {"from": [0, 0, 0], "size": size, "colour_at": grid.colour_at}}],
		"cuts": cuts,
		"surface": "mixed" if options.smooth else "none",
		"top": "smooth" if options.smooth else "studs",
		"panels": options.smooth, "wedges": options.smooth, "near_edges": true,
		"stitch_first": true,
		"prefer": grid.prefer, "most_cells": grid.across * grid.deep * grid.tall + 1}


## Every part Shapes may lay, to be loaded before a worker reads them.
static func parts_needed() -> PackedStringArray:
	var out: Dictionary = {}
	for table: Array in [Shapes.CORE_BRICKS, Shapes.CORE_PLATES, Shapes.TOPS]:
		for entry: Array in table:
			out[str(entry[2])] = true
	for table: Array in [Shapes.Plan.SLOPES, Shapes.Plan.INVERTED]:
		for entry: Array in table:
			for id: Variant in [entry[3], entry[4]]:
				if not str(id).is_empty():
					out[str(id)] = true
	for id: Variant in Patterns.WEDGES + Shapes.BRICK_WEDGES:
		out[str(id)] = true
	for id: String in ["30414", "11211", "87087"]:
		out[id] = true
	for id: Variant in Assistant.PANELS.values():
		out[str(id)] = true
	return PackedStringArray(out.keys())


## Measure, lay and check: {"model", "report", "grid", "trouble", "ms"}, or
## {"error"}. Every part in [method parts_needed] must already be loaded.
static func build(mesh: MeshFile, options: Options, checker: Assistant,
		progress: Progress = null) -> Dictionary:
	var library: PartLibrary = checker.library
	var times: Dictionary = {}
	var t0: int = Time.get_ticks_msec()
	if progress != null:
		progress.say("measuring the model")
	var grid: Grid = voxelise(mesh, options, library)
	times["measure"] = Time.get_ticks_msec() - t0
	if grid.cells == 0:
		return {"error": "at that size nothing of it is a stud wide — make it bigger"}
	if progress != null:
		progress.say("laying %s studs of it in bricks" % _comma(grid.cells))
	var t1: int = Time.get_ticks_msec()
	var trouble: Array = []
	var made: Array = Shapes.lay(pattern(grid, options), trouble, library)
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
	times["lay"] = Time.get_ticks_msec() - t1
	if model.placements.is_empty():
		return {"error": "it could not be laid: %s" % "; ".join(PackedStringArray(trouble))
			if not trouble.is_empty() else "it came to no bricks"}
	if progress != null:
		progress.say("checking %s parts hold together" % _comma(model.placements.size()))
	var t2: int = Time.get_ticks_msec()
	var report: Dictionary = mend(model, checker)
	times["check"] = Time.get_ticks_msec() - t2
	report["coverage"] = coverage(grid, model, checker)
	return {"model": model, "report": report, "grid": grid, "trouble": trouble, "ms": times}


## How much of the model the parts fill: its studs and plates inside a part,
## over all of them. A model can pass the check having lost an ear.
static func coverage(grid: Grid, model: Assistant.Model, checker: Assistant) -> float:
	if grid.cells == 0:
		return 0.0
	var covered := PackedByteArray()
	covered.resize(grid.state.size())
	var count: int = 0
	for placement: Assistant.Placement in model.placements:
		var part: Lbm.PartMesh = checker.library.mesh_for(placement.part)
		if part == null:
			continue
		var box: AABB = checker._transform(placement, part) * part.bounds
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
					if grid.state[i] == 1 and covered[i] == 0:
						covered[i] = 1
						count += 1
	return float(count) / float(grid.cells)


## Checked as check_design checks a design, and mended until it passes in
## one piece: a part overlapping one before it, a part nothing holds, and a
## piece apart from the rest, each taken out and the whole checked again.
## The report of the last check, with "mended": how many parts came out.
static func mend(model: Assistant.Model, checker: Assistant) -> Dictionary:
	var report: Dictionary = checker._check(model, true)
	var taken_out: int = 0
	for _round: int in 8:
		# A model with nothing in it comes back without a count of pieces.
		if bool(report.get("ok", false)) and int(report.get("pieces", 0)) <= 1:
			break
		var drop: Dictionary = {}
		for index: Variant in report.get("floating", []):
			drop[int(index)] = true
		var kinds: Array = report.get("kinds", [])
		if kinds.has("overlap") or kinds.has("unknown part") or kinds.has("not loaded"):
			drop.merge(_overlapping(model, checker))
		if drop.is_empty() and int(report.get("pieces", 0)) > 1:
			drop = _apart(model, checker)
		if drop.is_empty():
			break
		var kept: Array[Assistant.Placement] = []
		for index: int in model.placements.size():
			if not drop.has(index):
				kept.append(model.placements[index])
		taken_out += model.placements.size() - kept.size()
		model.placements = kept
		report = checker._check(model, true)
	report["mended"] = taken_out
	return report


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
