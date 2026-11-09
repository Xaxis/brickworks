## A part's surface made a closed solid for a 3MF (APP_UX7 #12, print3mf2):
## every edge shared by exactly two triangles, once each way round, which is
## what the 3MF core asks of a model's mesh (4.1) and what lib3mf's
## IsManifoldAndOriented checks. A slicer then prints each colour as it is,
## with nothing to repair.
##
## LDraw draws a part as surfaces that meet without sharing edges, so a part
## as drawn is closed only to the eye. In the order this mends them:
##
## - A T-junction: one side's edge runs straight past the corners the other
##   side's shorter edges meet at. The long edge is split at each of them,
##   found exactly: every place is a whole number of 1/64 LDU, and the edges
##   on one line share its direction and moment (Plücker's coordinates).
## - A near one: where a fine curve meets a coarse one (a 48-sided circle
##   on a 16-sided one), the fine side's corners lie a hair off the coarse
##   side's edge. Within 0.1 LDU (0.04 mm, finer than any printer) the edge
##   is split at them too, so the gap closes with no triangle added.
## - Two triangles on one side of an edge, one lying on the other, as a
##   print's shapes sometimes do: the smaller goes.
## - An edge of more than two triangles, where solids touch along it: round
##   the edge, each wedge of solid is bounded by one triangle going one way
##   and the next going the other, and those two are paired.
## - What is still open is a loop of edges with no triangle on one side.
##   Where the part's own face lies across the loop facing the same way (a
##   stud's foot on a plate's top, a tube's top under it), the loop is cut
##   into that face: the face is remade with the loop as its hole, so stud
##   and plate are one solid with no wall inside it.
## - Any other loop (a gap, an open end) gets a cap across it. Loops in one
##   plane are capped together, a loop inside another its hole; a loop not
##   in a plane gets the triangles spanning it with the least area
##   (Barequet and Sharir).
## - Last, a corner where solids touch only at a point gets a vertex for
##   each, as the core allows ("unless coalescing duplicates would create
##   non-manifold edges").
##
## Nothing moves but a near T-junction's corners, by under 0.1 LDU, so the
## part's size is as it was. Measured on the example car (print3mf_probe):
## its 24,921 triangles become 29,552 and all 7 colours' objects close.
extends RefCounted

## 0.1 LDU, in the 1/64 LDU steps places are counted in, squared.
const NEAR_SQUARED := 6.4 * 6.4
## A loop longer than this is fanned from its middle rather than spanned
## with the least area, which takes the cube of its length.
const LEAST_AREA_MOST := 64
## Places beyond this many steps from the part's middle are a hose's or a
## flex axle's coarser ones, where products of three coordinates would
## overflow: such a part is left as drawn.
const FARTHEST := 1 << 16
## Bits of an edge's key: its two vertices, then the half-edge.
const HALF_BITS := 23
const HALF_MASK := (1 << HALF_BITS) - 1
const VERTEX_LIMIT := 1 << 20

var positions := PackedVector3Array()
var triangles := PackedInt32Array()
var painted := PackedInt32Array()
## What it did, for a probe: T-junctions split, triangles dropped as lying
## on others, edges paired round, loops capped, vertices given copies.
var counts: Dictionary = {}

var _pace: FramePace
## Each vertex's place in whole 1/64 LDU steps.
var _grid: Array[Vector3i] = []


func _init(pace: FramePace) -> void:
	_pace = pace if pace != null else FramePace.new()


## [param at] places in LDU, [param corners] three a triangle,
## counter-clockwise from outside, and each triangle's [param colours]:
## the same closed, in [member positions], [member triangles] and
## [member painted]. A coroutine.
func close(at: PackedVector3Array, corners: PackedInt32Array, colours: PackedInt32Array) -> void:
	positions = at
	triangles = corners
	painted = colours
	counts = {"split": 0, "near": 0, "dropped": 0, "paired": 0, "capped": 0, "copies": 0}
	if at.size() >= VERTEX_LIMIT or corners.size() > HALF_MASK or corners.is_empty():
		return
	_grid.resize(at.size())
	for i: int in at.size():
		var key := Vector3i((at[i] * 64.0).round())
		if absi(key.x) > FARTHEST or absi(key.y) > FARTHEST or absi(key.z) > FARTHEST:
			return
		_grid[i] = key
	counts["split"] = await _split_on_lines()
	counts["near"] = await _split_near()
	counts["split"] += await _split_on_lines()
	var dropped: int = await _drop_overlaps()
	counts["dropped"] = dropped
	if dropped > 0:
		counts["near"] += await _split_near()
		counts["split"] += await _split_on_lines()
	var partner: PackedInt32Array = await _pair()
	var cut: int = await _imprint(_loops(partner))
	counts["imprinted"] = cut
	if cut > 0:
		counts["split"] += await _split_on_lines()
		counts["near"] += await _split_near()
		counts["split"] += await _split_on_lines()
		partner = await _pair()
	partner = await _cap(partner)
	await _split_fans(partner)


# -- edges ------------------------------------------------------------------------


## Every half-edge as a key, sorted so a run of one key is one edge:
## its lower vertex, its higher, then the half-edge (triangle * 3 + side).
func _edges() -> PackedInt64Array:
	var keys := PackedInt64Array()
	keys.resize(triangles.size())
	for h: int in triangles.size():
		var a: int = triangles[h]
		var b: int = triangles[h - h % 3 + (h + 1) % 3]
		keys[h] = (mini(a, b) << (HALF_BITS + 20)) | (maxi(a, b) << HALF_BITS) | h
	keys.sort()
	return keys


func _start(h: int) -> int:
	return triangles[h]


func _end(h: int) -> int:
	return triangles[h - h % 3 + (h + 1) % 3]


func _opposite(h: int) -> int:
	return triangles[h - h % 3 + (h + 2) % 3]


## Each open half-edge (an edge only one triangle has): from its start, the
## Array of its ends, and from start << 20 | end, its half-edge.
func _open(keys: PackedInt64Array, out_ends: Dictionary, half: Dictionary) -> void:
	var i: int = 0
	while i < keys.size():
		var j: int = i + 1
		while j < keys.size() and keys[j] >> HALF_BITS == keys[i] >> HALF_BITS:
			j += 1
		if j - i == 1:
			var h: int = keys[i] & HALF_MASK
			var a: int = _start(h)
			var b: int = _end(h)
			if not out_ends.has(a):
				out_ends[a] = []
			(out_ends[a] as Array).append(b)
			half[(a << 20) | b] = h
		i = j


## Triangles rebuilt with [param splits] (triangle -> [side, Array of the
## vertices along that side, in order]) each made a fan from its opposite
## corner.
func _apply(splits: Dictionary) -> void:
	var out := PackedInt32Array()
	var colours := PackedInt32Array()
	for t: int in triangles.size() / 3:
		if not splits.has(t):
			out.append_array([triangles[t * 3], triangles[t * 3 + 1], triangles[t * 3 + 2]])
			colours.append(painted[t])
			continue
		var side: int = splits[t][0]
		var along: Array = splits[t][1]
		var a: int = triangles[t * 3 + side]
		var b: int = triangles[t * 3 + (side + 1) % 3]
		var c: int = triangles[t * 3 + (side + 2) % 3]
		var chain: Array = [a]
		chain.append_array(along)
		chain.append(b)
		for n: int in chain.size() - 1:
			out.append_array([chain[n], chain[n + 1], c])
			colours.append(painted[t])
	triangles = out
	painted = colours


# -- T-junctions -----------------------------------------------------------------------


## Every open edge split at the ends of the open edges on its line that lie
## between its own ends; until none is. How many triangles were split.
func _split_on_lines() -> int:
	var total: int = 0
	for _round: int in 8:
		var keys: PackedInt64Array = _edges()
		var lines: Dictionary = {}          ## "direction moment" -> Array of half-edges
		var i: int = 0
		while i < keys.size():
			var j: int = i + 1
			while j < keys.size() and keys[j] >> HALF_BITS == keys[i] >> HALF_BITS:
				j += 1
			if j - i == 1:
				var h: int = keys[i] & HALF_MASK
				var a: Vector3i = _grid[_start(h)]
				var d: Vector3i = _direction(_grid[_end(h)] - a)
				var key: String = "%d %d %d %d %d %d" % [d.x, d.y, d.z, a.y * d.z - a.z * d.y,
					a.z * d.x - a.x * d.z, a.x * d.y - a.y * d.x]
				if not lines.has(key):
					lines[key] = []
				(lines[key] as Array).append(h)
			i = j
			if i & 4095 == 0 and _pace.due():
				await _pace.next()
		var splits: Dictionary = {}
		for key: String in lines:
			var group: Array = lines[key]
			if group.size() < 2:
				continue
			var d: Vector3i = _direction(_grid[_end(group[0])] - _grid[_start(group[0])])
			var along: Dictionary = {}       ## vertex -> its place along the line
			for h: int in group:
				for v: int in [_start(h), _end(h)]:
					along[v] = _dot(_grid[v], d)
			for h: int in group:
				var t: int = h / 3
				if splits.has(t):
					continue
				var from: int = along[_start(h)]
				var to: int = along[_end(h)]
				var inside: Array = []
				for v: int in along:
					var s: int = along[v]
					if s > mini(from, to) and s < maxi(from, to):
						inside.append([s if to > from else -s, v])
				if inside.is_empty():
					continue
				inside.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
				splits[t] = [h % 3, inside.map(func(pair: Array) -> int: return pair[1])]
		if splits.is_empty():
			break
		total += splits.size()
		_apply(splits)
	return total


## An open edge a to b whose other side is a chain of open edges from b back
## to a, each corner within 0.1 LDU of a to b and further along it than the
## last: split there, when the pieces face as the triangle did.
func _split_near() -> int:
	var total: int = 0
	for _round: int in 8:
		var out_ends: Dictionary = {}
		var half: Dictionary = {}
		_open(_edges(), out_ends, half)
		var splits: Dictionary = {}
		var walked: int = 0
		for code: int in half:
			var h: int = half[code]
			var t: int = h / 3
			if splits.has(t):
				continue
			var a: int = _start(h)
			var b: int = _end(h)
			var d: Vector3i = _grid[b] - _grid[a]
			var length: int = _dot(d, d)
			if length == 0:
				continue
			var chain: Array = []
			var at: int = b
			var last: int = length
			var closed: bool = false
			for _step: int in 32:
				var next: int = -1
				for y: int in out_ends.get(at, []):
					if y == a:
						next = a
						break
					var r: Vector3i = _grid[y] - _grid[a]
					var s: int = _dot(r, d)
					if s <= 0 or s >= last:
						continue
					var off: Vector3i = Vector3i(r.y * d.z - r.z * d.y, r.z * d.x - r.x * d.z,
						r.x * d.y - r.y * d.x)
					if float(_dot(off, off)) <= NEAR_SQUARED * float(length):
						next = y
						last = s
						break
				if next == -1:
					break
				if next == a:
					closed = not chain.is_empty()
					break
				chain.append(next)
				at = next
			walked += 1
			if walked & 1023 == 0 and _pace.due():
				await _pace.next()
			if not closed:
				continue
			chain.reverse()
			var c: int = _opposite(h)
			var normal: Vector3 = Vector3(_grid[b] - _grid[a]).cross(Vector3(_grid[c] - _grid[a]))
			var corners: Array = [a]
			corners.append_array(chain)
			corners.append(b)
			var facing: bool = true
			for n: int in corners.size() - 1:
				var p: Vector3 = Vector3(_grid[corners[n]])
				var q: Vector3 = Vector3(_grid[corners[n + 1]])
				if (q - p).cross(Vector3(_grid[c]) - p).dot(normal) <= 0.0:
					facing = false
					break
			if facing:
				splits[t] = [h % 3, chain]
		if splits.is_empty():
			break
		total += splits.size()
		_apply(splits)
	return total


## Of two triangles that share an edge the same way round and lie in one
## plane on the same side of it, one lying on the other, the smaller goes.
func _drop_overlaps() -> int:
	var keys: PackedInt64Array = _edges()
	var drop: Dictionary = {}
	var i: int = 0
	while i < keys.size():
		var j: int = i + 1
		while j < keys.size() and keys[j] >> HALF_BITS == keys[i] >> HALF_BITS:
			j += 1
		for m: int in range(i, j):
			for n: int in range(m + 1, j):
				var hm: int = keys[m] & HALF_MASK
				var hn: int = keys[n] & HALF_MASK
				if drop.has(hm / 3) or drop.has(hn / 3) or _start(hm) != _start(hn):
					continue
				var a: Vector3i = _grid[_start(hm)]
				var d: Vector3i = _grid[_end(hm)] - a
				var cm: Vector3i = _grid[_opposite(hm)] - a
				var cn: Vector3i = _grid[_opposite(hn)] - a
				var nm: Array = _cross(d, cm)
				# In one plane, exactly; then on the same side, by sign alone.
				if nm[0] * cn.x + nm[1] * cn.y + nm[2] * cn.z != 0:
					continue
				var fm := Vector3(Vector3(d).cross(Vector3(cm)))
				var fn := Vector3(Vector3(d).cross(Vector3(cn)))
				if fm.dot(fn) <= 0.0:
					continue
				drop[hm / 3 if fm.length_squared() < fn.length_squared() else hn / 3] = true
		i = j
		if i & 4095 == 0 and _pace.due():
			await _pace.next()
	if drop.is_empty():
		return 0
	var out := PackedInt32Array()
	var colours := PackedInt32Array()
	for t: int in triangles.size() / 3:
		if not drop.has(t):
			out.append_array([triangles[t * 3], triangles[t * 3 + 1], triangles[t * 3 + 2]])
			colours.append(painted[t])
	triangles = out
	painted = colours
	return drop.size()


# -- pairing --------------------------------------------------------------------------


## Each half-edge's partner, the other side of its edge, or -1. Round an
## edge of more than two, each "-" half-edge (from the higher vertex)
## starts a wedge of solid going round and the next "+" one closes it.
func _pair() -> PackedInt32Array:
	var partner := PackedInt32Array()
	partner.resize(triangles.size())
	partner.fill(-1)
	var keys: PackedInt64Array = _edges()
	var i: int = 0
	var paired: int = 0
	while i < keys.size():
		var j: int = i + 1
		while j < keys.size() and keys[j] >> HALF_BITS == keys[i] >> HALF_BITS:
			j += 1
		if j - i == 2:
			var h0: int = keys[i] & HALF_MASK
			var h1: int = keys[i + 1] & HALF_MASK
			if _start(h0) != _start(h1):
				partner[h0] = h1
				partner[h1] = h0
		elif j - i > 2:
			paired += 1
			_pair_round(keys, i, j, partner)
		i = j
		if i & 4095 == 0 and _pace.due():
			await _pace.next()
	counts["paired"] = paired
	return partner


func _pair_round(keys: PackedInt64Array, from: int, to: int, partner: PackedInt32Array) -> void:
	var h0: int = keys[from] & HALF_MASK
	var lo: int = mini(_start(h0), _end(h0))
	var hi: int = maxi(_start(h0), _end(h0))
	var d: Vector3 = Vector3(_grid[hi] - _grid[lo]).normalized()
	var u: Vector3 = d.cross(Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.UP).normalized()
	var w: Vector3 = d.cross(u)
	var wings: Array = []
	for k: int in range(from, to):
		var h: int = keys[k] & HALF_MASK
		var r: Vector3 = Vector3(_grid[_opposite(h)] - _grid[lo])
		wings.append([atan2(r.dot(w), r.dot(u)), _start(h) == lo, h])
	# Going round, and at one angle a "-" before a "+".
	wings.sort_custom(func(x: Array, y: Array) -> bool:
		if x[0] != y[0]:
			return x[0] < y[0]
		if x[1] != y[1]:
			return not x[1]
		return x[2] < y[2])
	var open: Array = []
	for k: int in 2 * wings.size():
		var wing: Array = wings[k % wings.size()]
		var h: int = wing[2]
		if partner[h] != -1:
			continue
		if not wing[1]:
			if not open.has(h):
				open.append(h)
		elif not open.is_empty():
			var other: int = open.pop_back()
			partner[other] = h
			partner[h] = other


# -- loops cut into faces ---------------------------------------------------------------


## Loops in a plane whose caps would lie on the part's own face there,
## facing the other way (a stud's foot on a top face, a tube's top under
## one, a gap where two of a print's triangles overlap): the faces they
## cross remade with the loops cut out, so the stud stands in a hole its
## own shape and no face lies on another. Done only where the remade faces
## cover the old less the loops exactly and add no edge a third triangle;
## any other loop is capped. How many loops were cut in.
func _imprint(loops: Array) -> int:
	var planes: Dictionary = {}         ## "normal offset" -> Array of triangles
	for t: int in triangles.size() / 3:
		var key: String = _plane_key(_cross(_grid[triangles[t * 3 + 1]] - _grid[triangles[t * 3]],
			_grid[triangles[t * 3 + 2]] - _grid[triangles[t * 3]]), _grid[triangles[t * 3]])
		if key.is_empty():
			continue
		if not planes.has(key):
			planes[key] = []
		(planes[key] as Array).append(t)
		if t & 4095 == 4095 and _pace.due():
			await _pace.next()
	var groups: Dictionary = {}         ## plane key -> [normal, Array of loops]
	for loop: Array in loops:
		var n: Array = _normal_of(loop)
		if n.is_empty():
			continue
		var key: String = _plane_key(n, _grid[loop[0]])
		if not planes.has(key):
			continue
		if not groups.has(key):
			groups[key] = [n, []]
		(groups[key][1] as Array).append(loop)
	if groups.is_empty():
		return 0
	var used: Dictionary = {}
	for h: int in triangles.size():
		var code: int = _code(_start(h), _end(h))
		used[code] = int(used.get(code, 0)) + 1
	var gone: Dictionary = {}
	var added := PackedInt32Array()
	var colours := PackedInt32Array()
	var cut: int = 0
	for key: String in groups:
		var group: Array = groups[key][1]
		var remade: Array = _remade(groups[key][0], group, planes[key], used)
		if remade.is_empty():
			continue
		for t: int in remade[0]:
			gone[t] = true
		var faces: PackedInt32Array = remade[1]
		added.append_array(faces)
		for _t: int in faces.size() / 3:
			colours.append(painted[remade[0][0]])
		cut += group.size()
		if _pace.due():
			await _pace.next()
	if cut == 0:
		return 0
	var out := PackedInt32Array()
	var kept := PackedInt32Array()
	for t: int in triangles.size() / 3:
		if not gone.has(t):
			out.append_array([triangles[t * 3], triangles[t * 3 + 1], triangles[t * 3 + 2]])
			kept.append(painted[t])
	out.append_array(added)
	kept.append_array(colours)
	triangles = out
	painted = kept
	return cut


## The faces of one plane that the loops cross, and those faces remade with
## the loops cut out ([the old triangles, the new corners]); empty when the
## loops cross none or the remaking is not exact. [param used] is updated.
func _remade(n: Array, group: Array, faces: Array, used: Dictionary) -> Array:
	var axis: int = 0
	for k: int in [1, 2]:
		if absi(n[k]) > absi(n[axis]):
			axis = k
	var u: int = [1, 2, 0][axis]
	var v: int = [2, 0, 1][axis]
	var flip: bool = n[axis] < 0
	var at: Dictionary = {}
	var corners: Array = []
	for loop: Array in group:
		corners.append_array(loop)
	for t: int in faces:
		for c: int in 3:
			corners.append(triangles[t * 3 + c])
	for x: int in corners:
		var p: Vector3i = _grid[x]
		at[x] = Vector2i(p[v], p[u]) if flip else Vector2i(p[u], p[v])
	# The faces any loop crosses: a face's middle in a loop, a loop's corner
	# in a face, or an edge of each crossing.
	var chosen: Array = []
	for t: int in faces:
		var a: Vector2i = at[triangles[t * 3]]
		var b: Vector2i = at[triangles[t * 3 + 1]]
		var c: Vector2i = at[triangles[t * 3 + 2]]
		var hit: bool = false
		for loop: Array in group:
			if _in_ring(at, loop, a + b + c, 3):
				hit = true
			for k: int in loop.size():
				if hit:
					break
				var p: Vector2i = at[loop[k]]
				var q: Vector2i = at[loop[(k + 1) % loop.size()]]
				if (_turn(a, b, p) > 0 and _turn(b, c, p) > 0 and _turn(c, a, p) > 0) \
						or _crosses(a, b, p, q) or _crosses(b, c, p, q) or _crosses(c, a, p, q):
					hit = true
			if hit:
				break
		if hit:
			chosen.append(t)
	if chosen.is_empty():
		return []
	# The remade region's edges: the faces' half-edges, split at the loops'
	# corners on them, and each loop's going the other way round; a
	# half-edge and its opposite cancel.
	var half: Dictionary = {}           ## start << 20 | end -> how many
	for t: int in chosen:
		for side: int in 3:
			var a: int = triangles[t * 3 + side]
			var b: int = triangles[t * 3 + (side + 1) % 3]
			var on: Array = []
			var d: Vector2i = at[b] - at[a]
			for x: int in corners.slice(0, corners.size() - faces.size() * 3):
				if x == a or x == b:
					continue
				var r: Vector2i = at[x] - at[a]
				var s: int = r.x * d.x + r.y * d.y
				if _turn(at[a], at[b], at[x]) == 0 and s > 0 and s < d.x * d.x + d.y * d.y:
					on.append([s, x])
			on.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
			var chain: Array = [a]
			for pair: Array in on:
				if chain[-1] != pair[1]:
					chain.append(pair[1])
			chain.append(b)
			for k: int in chain.size() - 1:
				var code: int = (chain[k] << 20) | chain[k + 1]
				half[code] = int(half.get(code, 0)) + 1
	for loop: Array in group:
		for k: int in loop.size():
			var code: int = (loop[(k + 1) % loop.size()] << 20) | loop[k]
			half[code] = int(half.get(code, 0)) + 1
	var out_ends: Dictionary = {}
	for code: int in half.keys():
		var back: int = ((code & 0xFFFFF) << 20) | (code >> 20)
		var both: int = mini(int(half[code]), int(half.get(back, 0)))
		if code != back and both > 0:
			half[code] = int(half[code]) - both
			half[back] = int(half[back]) - both
	for code: int in half:
		for _k: int in int(half[code]):
			var a: int = code >> 20
			if not out_ends.has(a):
				out_ends[a] = []
			(out_ends[a] as Array).append(code & 0xFFFFF)
	var rings: Array = _rings(out_ends)
	if not rings[1]:
		return []
	var ring_list: Array = rings[0]
	var signed: Array = ring_list.map(func(ring: Array) -> int: return _area2(at, ring))
	var holes_of: Dictionary = {}
	for o: int in ring_list.size():
		if signed[o] > 0:
			holes_of[o] = []
	for h: int in ring_list.size():
		if signed[h] == 0:
			return []
		if signed[h] > 0:
			continue
		var best: int = -1
		for o: int in holes_of:
			if _inside(at, ring_list[o], ring_list[h]) and (best == -1 or signed[o] < signed[best]):
				best = o
		if best == -1:
			return []
		(holes_of[best] as Array).append(ring_list[h])
	var made := PackedInt32Array()
	for o: int in holes_of:
		var part: PackedInt32Array = _triangulate(at, ring_list[o], holes_of[o])
		if part.is_empty():
			return []
		made.append_array(part)
	# Exactly the faces less the loops, every new triangle turning left.
	var want: int = 0
	for t: int in chosen:
		want += _turn(at[triangles[t * 3]], at[triangles[t * 3 + 1]], at[triangles[t * 3 + 2]])
	for loop: Array in group:
		want -= _area2(at, loop)
	var got: int = 0
	for t: int in made.size() / 3:
		var area: int = _turn(at[made[t * 3]], at[made[t * 3 + 1]], at[made[t * 3 + 2]])
		if area <= 0:
			return []
		got += area
	if got != want:
		return []
	var trial: Dictionary = used.duplicate()
	for t: int in chosen:
		for side: int in 3:
			var code: int = _code(triangles[t * 3 + side], triangles[t * 3 + (side + 1) % 3])
			trial[code] = int(trial[code]) - 1
	for h: int in made.size():
		var code: int = _code(made[h], made[h - h % 3 + (h + 1) % 3])
		trial[code] = int(trial.get(code, 0)) + 1
		if int(trial[code]) > 2:
			return []
	used.clear()
	used.merge(trial)
	return [chosen, made]


## A plane's key: its normal made primitive (its sign kept: a face's way
## round) and its offset; empty for no normal.
func _plane_key(n: Array, on: Vector3i) -> String:
	var g: int = _gcd(_gcd(absi(n[0]), absi(n[1])), absi(n[2]))
	if g == 0:
		return ""
	return "%d %d %d %d" % [n[0] / g, n[1] / g, n[2] / g,
		(n[0] / g) * on.x + (n[1] / g) * on.y + (n[2] / g) * on.z]


## A loop's normal as it goes round (Newell's), when every corner lies in
## its plane exactly; empty otherwise.
func _normal_of(loop: Array) -> Array:
	var n: Array = _newell(loop)
	if n == [0, 0, 0]:
		return []
	var first: Vector3i = _grid[loop[0]]
	for x: int in loop:
		var r: Vector3i = _grid[x] - first
		if r.x * n[0] + r.y * n[1] + r.z * n[2] != 0:
			return []
	return n


## Whether [param p] / [param scale] lies inside the ring, by crossings.
static func _in_ring(at: Dictionary, ring: Array, p: Vector2i, scale: int) -> bool:
	var inside: bool = false
	for k: int in ring.size():
		var a: Vector2i = at[ring[k]] * scale
		var b: Vector2i = at[ring[(k + 1) % ring.size()]] * scale
		if (a.y > p.y) != (b.y > p.y):
			var across: int = (b.x - a.x) * (p.y - a.y) - (p.x - a.x) * (b.y - a.y)
			if (across > 0) == (b.y > a.y):
				inside = not inside
	return inside


## Whether segments a-b and c-d cross at a point inside both.
static func _crosses(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> bool:
	var d1: int = _turn(a, b, c)
	var d2: int = _turn(a, b, d)
	var d3: int = _turn(c, d, a)
	var d4: int = _turn(c, d, b)
	return ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0))


# -- caps ------------------------------------------------------------------------------


## The loops the half-edges with no partner make, each going the way its
## half-edges go, as simple loops.
func _loops(partner: PackedInt32Array) -> Array:
	var out_ends: Dictionary = {}
	for h: int in partner.size():
		if partner[h] == -1:
			var a: int = _start(h)
			if not out_ends.has(a):
				out_ends[a] = []
			(out_ends[a] as Array).append(_end(h))
	return _rings(out_ends)[0]


## The simple loops a set of half-edges (start -> Array of ends) makes,
## and whether every one closed.
static func _rings(out_ends: Dictionary) -> Array:
	var loops: Array = []
	var all_closed: bool = true
	for a: int in out_ends.keys():
		while not (out_ends[a] as Array).is_empty():
			var loop: Array = [a]
			var at: int = a
			var whole: bool = true
			while true:
				var y: int = (out_ends[at] as Array).pop_back()
				if y == a:
					break
				loop.append(y)
				at = y
				if not out_ends.has(at) or (out_ends[at] as Array).is_empty():
					whole = false
					break
			if whole:
				loops.append_array(_simple(loop))
			else:
				all_closed = false
	return [loops, all_closed]


## The loops of half-edges with no partner, each capped: those in one plane
## together, a loop inside another its hole; any other spanned with the
## least area, or fanned from a new middle vertex. The partners, with the
## caps'.
func _cap(partner: PackedInt32Array) -> PackedInt32Array:
	var loops: Array = _loops(partner)
	if loops.is_empty():
		return partner
	var used: Dictionary = {}           ## lo << 20 | hi -> triangles on it
	for h: int in triangles.size():
		var code: int = _code(_start(h), _end(h))
		used[code] = int(used.get(code, 0)) + 1
	var planes: Dictionary = {}         ## "normal offset" -> [normal, Array of loops]
	var loose: Array = []
	for loop: Array in loops:
		loop.reverse()                  # a cap goes round the other way
		var normal: Array = _newell(loop)
		if normal == [0, 0, 0]:
			loose.append(loop)
			continue
		var g: int = _gcd(_gcd(absi(normal[0]), absi(normal[1])), absi(normal[2]))
		var n: Array = [normal[0] / g, normal[1] / g, normal[2] / g]
		var first: Vector3i = _grid[loop[0]]
		var flat: bool = true
		for v: int in loop:
			var r: Vector3i = _grid[v] - first
			if r.x * n[0] + r.y * n[1] + r.z * n[2] != 0:
				flat = false
				break
		if not flat:
			loose.append(loop)
			continue
		if n[0] < 0 or (n[0] == 0 and (n[1] < 0 or (n[1] == 0 and n[2] < 0))):
			n = [-n[0], -n[1], -n[2]]
		var key: String = "%d %d %d %d" % [n[0], n[1], n[2],
			first.x * n[0] + first.y * n[1] + first.z * n[2]]
		if not planes.has(key):
			planes[key] = [n, []]
		(planes[key][1] as Array).append(loop)
	var added := PackedInt32Array()
	for key: String in planes:
		var n: Array = planes[key][0]
		var group: Array = planes[key][1]
		var flat_at: Dictionary = _projected(group, n)
		var signed: Array = group.map(func(loop: Array) -> int: return _area2(flat_at, loop))
		var holes_of: Dictionary = {}
		for o: int in group.size():
			if signed[o] > 0:
				holes_of[o] = []
		for h: int in group.size():
			if signed[h] == 0:
				loose.append(group[h])
			if signed[h] >= 0:
				continue
			var best: int = -1
			for o: int in holes_of:
				if _inside(flat_at, group[o], group[h]) and (best == -1 or signed[o] < signed[best]):
					best = o
			if best == -1:
				loose.append(group[h])
			else:
				(holes_of[best] as Array).append(group[h])
		for o: int in holes_of:
			var cap: PackedInt32Array = _triangulate(flat_at, group[o], holes_of[o])
			if cap.is_empty() or not _fits(cap, used):
				loose.append(group[o])
				loose.append_array(holes_of[o])
				continue
			_count(cap, used)
			added.append_array(cap)
		if _pace.due():
			await _pace.next()
	for loop: Array in loose:
		var cap := PackedInt32Array()
		if loop.size() <= LEAST_AREA_MOST:
			cap = _least_area(loop, used)
		if cap.is_empty():
			var middle := Vector3.ZERO
			for v: int in loop:
				middle += positions[v]
			var m: int = positions.size()
			positions.append(middle / loop.size())
			_grid.append(Vector3i((middle / loop.size() * 64.0).round()))
			for k: int in loop.size():
				cap.append_array([loop[k], loop[(k + 1) % loop.size()], m])
		_count(cap, used)
		added.append_array(cap)
		if _pace.due():
			await _pace.next()
	counts["capped"] = loops.size()
	# Each cap half-edge partnered with the one it closes, or the cap's own
	# other side.
	var base: int = triangles.size()
	triangles.append_array(added)
	for t: int in added.size() / 3:
		painted.append(Lbm.COLOR_INHERIT)
	partner.resize(triangles.size())
	for h: int in range(base, triangles.size()):
		partner[h] = -1
	var waiting: Dictionary = {}        ## start << 20 | end -> Array of half-edges
	for h: int in partner.size():
		if partner[h] != -1:
			continue
		var back: int = (_end(h) << 20) | _start(h)
		var list: Array = waiting.get(back, [])
		if not list.is_empty():
			var other: int = list.pop_back()
			partner[h] = other
			partner[other] = h
			continue
		var code: int = (_start(h) << 20) | _end(h)
		if not waiting.has(code):
			waiting[code] = []
		(waiting[code] as Array).append(h)
	return partner


## A loop that passes one vertex twice, as the simple loops it is made of.
static func _simple(loop: Array) -> Array:
	var out: Array = []
	var stack: Array = []
	var at: Dictionary = {}
	for v: int in loop:
		if at.has(v):
			var from: int = at[v]
			var cycle: Array = stack.slice(from)
			for w: int in cycle:
				at.erase(w)
			stack.resize(from)
			if cycle.size() >= 3:
				out.append(cycle)
		at[v] = stack.size()
		stack.append(v)
	if stack.size() >= 3:
		out.append(stack)
	return out


func _newell(loop: Array) -> Array:
	var n: Array = [0, 0, 0]
	for k: int in loop.size():
		var a: Vector3i = _grid[loop[k]]
		var b: Vector3i = _grid[loop[(k + 1) % loop.size()]]
		n[0] += a.y * b.z - a.z * b.y
		n[1] += a.z * b.x - a.x * b.z
		n[2] += a.x * b.y - a.y * b.x
	return n


## The loops' vertices in two dimensions, dropping the normal's largest
## axis, turned so a loop going round the normal counter-clockwise has a
## positive area.
func _projected(group: Array, n: Array) -> Dictionary:
	var axis: int = 0
	for k: int in [1, 2]:
		if absi(n[k]) > absi(n[axis]):
			axis = k
	var u: int = [1, 2, 0][axis]
	var v: int = [2, 0, 1][axis]
	var out: Dictionary = {}
	for loop: Array in group:
		for x: int in loop:
			var p: Vector3i = _grid[x]
			out[x] = Vector2i(p[v], p[u]) if n[axis] < 0 else Vector2i(p[u], p[v])
	return out


static func _area2(at: Dictionary, loop: Array) -> int:
	var s: int = 0
	for k: int in loop.size():
		var a: Vector2i = at[loop[k]]
		var b: Vector2i = at[loop[(k + 1) % loop.size()]]
		s += a.x * b.y - b.x * a.y
	return s


## Whether [param hole] lies in [param outer]: its first vertex not on the
## outer's line, by crossings.
static func _inside(at: Dictionary, outer: Array, hole: Array) -> bool:
	for x: int in hole:
		var p: Vector2i = at[x]
		var inside: bool = false
		var on: bool = false
		for k: int in outer.size():
			var a: Vector2i = at[outer[k]]
			var b: Vector2i = at[outer[(k + 1) % outer.size()]]
			if a == p:
				on = true
				break
			if (a.y > p.y) != (b.y > p.y):
				# Where the edge crosses p's row, against p.x, exactly.
				var across: int = (b.x - a.x) * (p.y - a.y) - (p.x - a.x) * (b.y - a.y)
				if across == 0:
					on = true
					break
				if (across > 0) == (b.y > a.y):
					inside = not inside
		if not on:
			return inside
	return false


## The outer loop with its holes, bridged into one and cut into ears; empty
## when that fails or the ears do not cover the loops' area exactly.
static func _triangulate(at: Dictionary, outer: Array, holes: Array) -> PackedInt32Array:
	var ring: Array = outer.duplicate()
	var area: int = _area2(at, outer)
	var ordered: Array = holes.duplicate()
	ordered.sort_custom(func(x: Array, y: Array) -> bool:
		return _rightmost(at, x).x > _rightmost(at, y).x)
	for hole: Array in ordered:
		area += _area2(at, hole)
		ring = _bridge(at, ring, hole)
		if ring.is_empty():
			return PackedInt32Array()
	var ears: PackedInt32Array = _ears(at, ring)
	var covered: int = 0
	for t: int in ears.size() / 3:
		covered += _turn(at[ears[t * 3]], at[ears[t * 3 + 1]], at[ears[t * 3 + 2]])
	return ears if covered == area and not ears.is_empty() else PackedInt32Array()


static func _rightmost(at: Dictionary, loop: Array) -> Vector2i:
	var best: Vector2i = at[loop[0]]
	for x: int in loop:
		var p: Vector2i = at[x]
		if p.x > best.x or (p.x == best.x and p.y > best.y):
			best = p
	return best


## The ring with the hole spliced in: from the hole's rightmost vertex to
## the ring vertex it sees first to its right (Eberly's bridge).
static func _bridge(at: Dictionary, ring: Array, hole: Array) -> Array:
	var m: int = 0
	for k: int in hole.size():
		var p: Vector2i = at[hole[k]]
		var best: Vector2i = at[hole[m]]
		if p.x > best.x or (p.x == best.x and p.y > best.y):
			m = k
	var mp: Vector2i = at[hole[m]]
	var nearest: float = INF
	var to: int = -1
	for k: int in ring.size():
		var a: Vector2i = at[ring[k]]
		var b: Vector2i = at[ring[(k + 1) % ring.size()]]
		if a.y == b.y or (a.y > mp.y) == (b.y > mp.y) and a.y != mp.y and b.y != mp.y:
			continue
		if mini(a.y, b.y) > mp.y or maxi(a.y, b.y) < mp.y:
			continue
		var x: float = a.x + float(mp.y - a.y) * float(b.x - a.x) / float(b.y - a.y)
		if x < mp.x or x >= nearest:
			continue
		nearest = x
		to = k if a.x > b.x else (k + 1) % ring.size()
		if a.y == mp.y and a.x >= mp.x:
			to = k
		elif b.y == mp.y and b.x >= mp.x:
			to = (k + 1) % ring.size()
	if to == -1:
		return []
	# A ring vertex inside the triangle from the hole's vertex to where the
	# ray met the ring and on to the vertex found, nearest the ray, is seen
	# instead.
	var pp: Vector2i = at[ring[to]]
	var hit := Vector2(nearest, mp.y)
	var best_tan: float = INF
	var chosen: int = to
	for k: int in ring.size():
		var v: Vector2i = at[ring[k]]
		if v == pp or v.x < mp.x or v.x > pp.x:
			continue
		var tri: Array = [Vector2(mp), hit, Vector2(pp)] if mp.y < pp.y else [Vector2(pp), hit, Vector2(mp)]
		if not Geometry2D.point_is_inside_triangle(Vector2(v), tri[0], tri[1], tri[2]):
			continue
		var tan: float = INF if v.x == mp.x else absf(v.y - mp.y) / float(v.x - mp.x)
		if tan < best_tan:
			best_tan = tan
			chosen = k
	var spliced: Array = ring.slice(0, chosen + 1)
	for k: int in hole.size() + 1:
		spliced.append(hole[(m + k) % hole.size()])
	spliced.append_array(ring.slice(chosen))
	return spliced


## Ears cut from a ring counter-clockwise, its vertices maybe met twice (a
## hole's bridge): an ear is a corner turning left with no other place in
## it or on its edges.
static func _ears(at: Dictionary, ring: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var left: Array = ring.duplicate()
	var guard: int = left.size() * left.size() + 8
	while left.size() > 3 and guard > 0:
		guard -= 1
		var cut: bool = false
		for k: int in left.size():
			var ia: int = left[(k + left.size() - 1) % left.size()]
			var ib: int = left[k]
			var ic: int = left[(k + 1) % left.size()]
			var a: Vector2i = at[ia]
			var b: Vector2i = at[ib]
			var c: Vector2i = at[ic]
			if _turn(a, b, c) <= 0:
				continue
			var clear: bool = true
			for x: int in left:
				var p: Vector2i = at[x]
				if p == a or p == b or p == c:
					continue
				if _turn(a, b, p) >= 0 and _turn(b, c, p) >= 0 and _turn(c, a, p) >= 0:
					clear = false
					break
			if clear:
				out.append_array([ia, ib, ic])
				left.remove_at(k)
				cut = true
				break
		if not cut:
			return PackedInt32Array()
	if left.size() != 3 or _turn(at[left[0]], at[left[1]], at[left[2]]) <= 0:
		return PackedInt32Array()
	out.append_array([left[0], left[1], left[2]])
	return out


static func _turn(a: Vector2i, b: Vector2i, c: Vector2i) -> int:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)


## The triangles spanning a loop with the least area, none on an edge the
## part already has (Barequet and Sharir's dynamic programme); empty when
## there are none.
func _least_area(loop: Array, used: Dictionary) -> PackedInt32Array:
	var n: int = loop.size()
	var at := PackedVector3Array()
	for v: int in loop:
		at.append(Vector3(_grid[v]))
	var cost := PackedFloat64Array()
	cost.resize(n * n)
	var best := PackedInt32Array()
	best.resize(n * n)
	best.fill(-1)
	for span: int in range(2, n):
		for i: int in n - span:
			var j: int = i + span
			cost[i * n + j] = INF
			if not (i == 0 and j == n - 1) and used.has(_code(loop[i], loop[j])):
				continue
			for m: int in range(i + 1, j):
				var area: float = (at[m] - at[i]).cross(at[j] - at[i]).length()
				if area <= 0.0:
					continue
				var total: float = cost[i * n + m] + cost[m * n + j] + area
				if total < cost[i * n + j]:
					cost[i * n + j] = total
					best[i * n + j] = m
	if n < 3 or cost[n - 1] == INF:
		return PackedInt32Array()
	var out := PackedInt32Array()
	var stack: Array = [[0, n - 1]]
	while not stack.is_empty():
		var span: Array = stack.pop_back()
		var i: int = span[0]
		var j: int = span[1]
		if j - i < 2:
			continue
		var m: int = best[i * n + j]
		out.append_array([loop[i], loop[m], loop[j]])
		stack.append([i, m])
		stack.append([m, j])
	return out


static func _code(a: int, b: int) -> int:
	return (mini(a, b) << 20) | maxi(a, b)


## Whether [param cap] adds no edge beyond a second triangle on it.
static func _fits(cap: PackedInt32Array, used: Dictionary) -> bool:
	var seen: Dictionary = {}
	for h: int in cap.size():
		var code: int = _code(cap[h], cap[h - h % 3 + (h + 1) % 3])
		seen[code] = int(seen.get(code, 0)) + 1
	for code: int in seen:
		if int(used.get(code, 0)) + int(seen[code]) > 2:
			return false
	return true


static func _count(cap: PackedInt32Array, used: Dictionary) -> void:
	for h: int in cap.size():
		var code: int = _code(cap[h], cap[h - h % 3 + (h + 1) % 3])
		used[code] = int(used.get(code, 0)) + 1


# -- corners where solids touch ----------------------------------------------------


## Round each vertex, the triangles joined through their partnered edges
## are one fan; each fan beyond the first gets a copy of the vertex.
func _split_fans(partner: PackedInt32Array) -> void:
	var corners_at: Dictionary = {}     ## vertex -> Array of corners (t * 3 + c)
	for k: int in triangles.size():
		var v: int = triangles[k]
		if not corners_at.has(v):
			corners_at[v] = []
		(corners_at[v] as Array).append(k)
	var copies: int = 0
	var done: int = 0
	for v: int in corners_at:
		var corners: Array = corners_at[v]
		done += 1
		if done & 1023 == 0 and _pace.due():
			await _pace.next()
		if corners.size() < 2:
			continue
		var parent: Dictionary = {}
		var corner_of: Dictionary = {}
		for k: int in corners:
			parent[k] = k
			corner_of[k / 3] = k
		for k: int in corners:
			var t: int = k / 3
			var c: int = k % 3
			for side: int in [(c + 2) % 3, c]:
				var other: int = partner[t * 3 + side]
				if other == -1 or not corner_of.has(other / 3):
					continue
				var ra: int = _root(parent, k)
				var rb: int = _root(parent, corner_of[other / 3])
				if ra != rb:
					parent[ra] = rb
		var fans: Dictionary = {}
		for k: int in corners:
			var r: int = _root(parent, k)
			if not fans.has(r):
				fans[r] = []
			(fans[r] as Array).append(k)
		if fans.size() < 2:
			continue
		var first: bool = true
		for r: int in fans:
			if first:
				first = false
				continue
			var copy: int = positions.size()
			positions.append(positions[v])
			_grid.append(_grid[v])
			copies += 1
			for k: int in fans[r]:
				triangles[k] = copy
	counts["copies"] = copies


static func _root(parent: Dictionary, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


# -- whole numbers ------------------------------------------------------------------


## A direction made primitive and pointing its first non-zero axis up, so
## every edge on one line has the same.
static func _direction(d: Vector3i) -> Vector3i:
	var g: int = _gcd(_gcd(absi(d.x), absi(d.y)), absi(d.z))
	if g == 0:
		return d
	d = Vector3i(d.x / g, d.y / g, d.z / g)
	if d.x < 0 or (d.x == 0 and (d.y < 0 or (d.y == 0 and d.z < 0))):
		d = -d
	return d


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var r: int = a % b
		a = b
		b = r
	return a


static func _dot(a: Vector3i, b: Vector3i) -> int:
	return a.x * b.x + a.y * b.y + a.z * b.z


static func _cross(a: Vector3i, b: Vector3i) -> Array:
	return [a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x]
