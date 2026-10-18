## Are turned parts given the same cells, quickly?
##
##   godot --headless --path . --script src/dev/turned_probe.gd
##
## A part at an angle reserves the lattice cells its box touches, by a
## fifteen-axis separating test. That test was run on every cell of the
## box's bounding box, with its axes worked out again each time: an
## Orthanc built of a thousand angled bricks took three minutes to place,
## on the thread the app answers on, and every look the design asked for
## timed out. BrickLattice.cells_for_turned now finds each row's run of
## cells from its ends. This checks it gives exactly the cells the old
## way gave — the old way is kept here as the reference — over many
## turns and boxes, and that it is quicker; and that the lattice says what
## such covers meet as asking every pair of their boxes said, quicker.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261010
	var same: int = 0
	var tried: int = 0
	var old_ms: int = 0
	var new_ms: int = 0
	var first_difference: String = ""
	for n: int in 300:
		var basis := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1),
			rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, TAU))
		if n % 5 == 0:
			# The common case: a turn about the vertical only.
			basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		var size := Vector3(rng.randi_range(1, 40), rng.randi_range(1, 12),
			rng.randi_range(1, 20))
		var boxes: Array[AABB] = [AABB(Vector3(-size.x / 2, -size.y, -size.z / 2), size)]
		if n % 3 == 0:
			boxes.append(AABB(Vector3(-2, 0, -2), Vector3(4, 1, 4)))
		var origin := Vector3i(rng.randi_range(-50, 50), rng.randi_range(0, 50),
			rng.randi_range(-50, 50))
		var t0: int = Time.get_ticks_usec()
		var old: Array[Vector3i] = _reference(boxes, origin, basis)
		var t1: int = Time.get_ticks_usec()
		var now: Array[Vector3i] = BrickLattice.cells_for_turned(boxes, origin, basis)
		var t2: int = Time.get_ticks_usec()
		old_ms += t1 - t0
		new_ms += t2 - t1
		tried += 1
		var a: Dictionary = {}
		for cell: Vector3i in old:
			a[cell] = true
		var b: Dictionary = {}
		for cell: Vector3i in now:
			b[cell] = true
		if a.size() == b.size() and a.keys().all(func(c: Variant) -> bool: return b.has(c)):
			same += 1
		elif first_difference.is_empty():
			first_difference = "box %s turned %s: %d cells before, %d now" % [
				size, basis.get_euler(), a.size(), b.size()]
	_check("the same cells as before, for %d of %d turned boxes%s" % [same, tried,
		"" if first_difference.is_empty() else " — " + first_difference], same == tried)
	_check("and quicker: %d ms before, %d ms now" % [old_ms / 1000, new_ms / 1000],
		new_ms * 3 < old_ms)
	_lattice_answers(rng)
	_asked_answers(rng)
	print("")
	if _failures == 0:
		print("a turned part takes the cells it always did, quickly")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## What the lattice says of turned covers, against every pair of boxes.
##
## A turned part's cover is a box a row of cells, hundreds of them, and
## 42112's mixer drum is 23,309: asked pair by pair what such covers meet,
## the check of that set took 16 minutes. The lattice answers by rows now
## (BrickLattice._rows, _overlaps), and must answer exactly as every pair
## did: what a cover runs into, whether it runs into anything, which part a
## cell is in (the first in its bucket, as before), and with slivers among
## the boxes, which every pair answered for in its own way.
func _lattice_answers(rng: RandomNumberGenerator) -> void:
	var shapes: Array = []
	for n: int in 10:
		var box: Array[AABB] = [AABB(Vector3(-rng.randf_range(2, 10), -rng.randf_range(1, 4),
			-rng.randf_range(2, 20)), Vector3(rng.randf_range(4, 20), rng.randf_range(2, 8),
			rng.randf_range(4, 40)))]
		var basis := Basis(Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5)
			.normalized(), rng.randf() * TAU)
		shapes.append(BrickLattice.boxes_for_turned(box, Vector3i.ZERO, basis))
	var lattice := BrickLattice.new()
	lattice.keeps_columns = false
	var all: Dictionary = {}
	for id: int in range(1, 100):
		var at := Vector3i(rng.randi_range(-60, 60), rng.randi_range(-20, 40), rng.randi_range(-60, 60))
		var packed := PackedInt32Array()
		match rng.randi_range(0, 3):
			0, 1:
				packed = BrickLattice.moved_by(shapes[rng.randi_range(0, shapes.size() - 1)], at)
			2:
				packed = PackedInt32Array([at.x, at.y, at.z, at.x + rng.randi_range(1, 40),
					at.y + rng.randi_range(1, 12), at.z + rng.randi_range(1, 40)])
			_:
				packed = _scatter(rng, at, rng.randi_range(25, 60), 0.05)
		lattice.occupy_boxes(id, packed)
		all[id] = packed
	var wrong: PackedStringArray = PackedStringArray()
	var by_rows: int = 0
	var pairwise: int = 0
	for q: int in 200:
		var at := Vector3i(rng.randi_range(-70, 70), rng.randi_range(-25, 45), rng.randi_range(-70, 70))
		var query := PackedInt32Array()
		match rng.randi_range(0, 3):
			0:
				query = PackedInt32Array([at.x, at.y, at.z, at.x + 1, at.y + 1, at.z + 1])
			1:
				query = BrickLattice.moved_by(shapes[rng.randi_range(0, shapes.size() - 1)], at)
			2:
				query = PackedInt32Array([at.x, at.y, at.z, at.x + rng.randi_range(1, 80),
					at.y + rng.randi_range(1, 8), at.z + rng.randi_range(1, 80)])
			_:
				query = _scatter(rng, at, rng.randi_range(1, 40), 0.03)
		var t0: int = Time.get_ticks_usec()
		var found: Dictionary = {}
		for id: int in lattice.blockers_boxes(query):
			found[id] = true
		by_rows += Time.get_ticks_usec() - t0
		var collides: bool = lattice.collides_boxes(query)
		var t1: int = Time.get_ticks_usec()
		var wanted: Dictionary = {}
		var bound: PackedInt32Array = BrickLattice._bound_of(query)
		for id: int in lattice._near(query):
			if BrickLattice._overlaps_pairwise(bound, BrickLattice._bound_of(all[id])) \
					and BrickLattice._overlaps_pairwise(query, all[id]):
				wanted[id] = true
		pairwise += Time.get_ticks_usec() - t1
		if found.size() != wanted.size() or not found.keys().all(func(k: int) -> bool:
				return wanted.has(k)) or collides == wanted.is_empty():
			wrong.append("a query of %d boxes met %s, not %s" % [query.size() / 6, found.keys(),
				wanted.keys()])
	for q: int in 2000:
		var cell := Vector3i(rng.randi_range(-70, 70), rng.randi_range(-25, 45), rng.randi_range(-70, 70))
		var want: int = 0
		var here: Variant = lattice._bucket.get(Vector3i(BrickLattice._floor_div(cell.x, BrickLattice.BUCKET),
			BrickLattice._floor_div(cell.y, BrickLattice.BUCKET),
			BrickLattice._floor_div(cell.z, BrickLattice.BUCKET)))
		for id: int in (here if here != null else PackedInt64Array()):
			var boxes: PackedInt32Array = all[id]
			for n: int in range(0, boxes.size(), 6):
				if cell.x >= boxes[n] and cell.x < boxes[n + 3] and cell.y >= boxes[n + 1] \
						and cell.y < boxes[n + 4] and cell.z >= boxes[n + 2] and cell.z < boxes[n + 5]:
					want = id
					break
			if want != 0:
				break
		if lattice.brick_at(cell) != want:
			wrong.append("cell %s is in %d, not %d" % [cell, lattice.brick_at(cell), want])
	_check("what turned covers meet and which part a cell is in, as every pair of boxes says, "
		+ "%d of them laid out by rows%s" % [lattice._rows.size(),
			"" if wrong.is_empty() else ": " + "; ".join(wrong.slice(0, 3))], wrong.is_empty())
	_check("and quicker: %d ms by rows, %d ms pair by pair" % [by_rows / 1000, pairwise / 1000],
		by_rows * 3 < pairwise)


## A part of several boxes, as a part's cover is, at a turn.
static func _a_part(rng: RandomNumberGenerator) -> Array:
	var boxes: Array[AABB] = []
	for k: int in rng.randi_range(1, 12):
		var lo := Vector3(rng.randi_range(-20, 10), rng.randi_range(-12, 2), rng.randi_range(-20, 10))
		boxes.append(AABB(lo, Vector3(rng.randi_range(1, 20), rng.randi_range(1, 8), rng.randi_range(1, 20))))
	var basis := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1),
		rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, TAU))
	if rng.randf() < 0.3:
		basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU))
	return [boxes, basis]


## A turned part's cover asked where another part's boxes are
## (BrickLattice.TurnedCover) says what the whole cover says: whether a cell
## of it is in them. Against boxes beside it, into it, and just touching it.
func _asked_answers(rng: RandomNumberGenerator) -> void:
	var same: int = 0
	var tried: int = 0
	var met: int = 0
	var whole_us: int = 0
	var asked_us: int = 0
	var first_difference: String = ""
	for n: int in 150:
		var part: Array = _a_part(rng)
		var origin := Vector3i(rng.randi_range(-50, 50), rng.randi_range(0, 50), rng.randi_range(-50, 50))
		var t0: int = Time.get_ticks_usec()
		var whole: PackedInt32Array = BrickLattice.boxes_for_turned(part[0], origin, part[1])
		whole_us += Time.get_ticks_usec() - t0
		var bound: PackedInt32Array = BrickLattice._bound_of(whole)
		var cover: BrickLattice.TurnedCover = BrickLattice.turned_cover(part[0], origin, part[1])
		for k: int in 12:
			# Another part's boxes about the cover's bound: some into it, some
			# beside it, some laid against one of its own boxes' faces.
			var theirs := PackedInt32Array()
			for j: int in rng.randi_range(1, 4):
				var at := Vector3i(rng.randi_range(bound[0] - 6, bound[3] + 2),
					rng.randi_range(bound[1] - 4, bound[4] + 1), rng.randi_range(bound[2] - 6, bound[5] + 2))
				if rng.randf() < 0.4 and whole.size() >= 6:
					# Against a face of one of the cover's boxes.
					var o: int = rng.randi_range(0, whole.size() / 6 - 1) * 6
					var axis: int = rng.randi_range(0, 2)
					at = Vector3i(whole[o], whole[o + 1], whole[o + 2])
					at[axis] = whole[o + 3 + axis]
				var size := Vector3i(rng.randi_range(1, 6), rng.randi_range(1, 4), rng.randi_range(1, 6))
				theirs.append_array([at.x, at.y, at.z, at.x + size.x, at.y + size.y, at.z + size.z])
			var t1: int = Time.get_ticks_usec()
			var said: bool = BrickLattice._overlaps_pairwise(whole, theirs)
			var t2: int = Time.get_ticks_usec()
			var asked: bool = cover.meets(theirs)
			asked_us += Time.get_ticks_usec() - t2
			whole_us += t2 - t1
			tried += 1
			if said:
				met += 1
			if said == asked:
				same += 1
			elif first_difference.is_empty():
				first_difference = "%s against %d boxes turned %s: whole %s, asked %s" % [theirs,
					(part[0] as Array).size(), (part[1] as Basis).get_euler(), said, asked]
	_check("a turned cover asked where another part is says what the whole cover says, %d of %d (%d meet)%s"
		% [same, tried, met, "" if first_difference.is_empty() else " — " + first_difference], same == tried)
	_check("and quicker: %d ms worked out whole, %d ms asked" % [whole_us / 1000, asked_us / 1000],
		asked_us < whole_us)


## A brick of loose boxes round [param at], now and then one empty along an
## axis.
static func _scatter(rng: RandomNumberGenerator, at: Vector3i, count: int,
		slivers: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k: int in count:
		var lo := at + Vector3i(rng.randi_range(-10, 10), rng.randi_range(-4, 4), rng.randi_range(-10, 10))
		var size := Vector3i(rng.randi_range(1, 6), rng.randi_range(1, 3), rng.randi_range(1, 6))
		if rng.randf() < slivers:
			size[rng.randi_range(0, 2)] = 0
		out.append_array([lo.x, lo.y, lo.z, lo.x + size.x, lo.y + size.y, lo.z + size.z])
	return out


## The way it was done before: every cell of the bounding box, each put
## to the full separating test.
func _reference(boxes: Array[AABB], origin_cell: Vector3i, basis: Basis) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var taken: Dictionary = {}
	for box: AABB in boxes:
		var lo := Vector3(box.position)
		var hi := lo + Vector3(box.size)
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for n: int in 8:
			var corner: Vector3 = basis * Vector3(hi.x if n & 1 else lo.x,
				hi.y if n & 2 else lo.y, hi.z if n & 4 else lo.z)
			low = low.min(corner)
			high = high.max(corner)
		var half: Vector3 = (hi - lo) * 0.5
		var middle: Vector3 = basis * ((lo + hi) * 0.5)
		for x: int in range(floori(low.x), ceili(high.x)):
			for y: int in range(floori(low.y), ceili(high.y)):
				for z: int in range(floori(low.z), ceili(high.z)):
					if not BrickLattice._touches(middle, basis, half, Vector3(
							float(x) + 0.5, float(y) + 0.5, float(z) + 0.5)):
						continue
					var cell: Vector3i = origin_cell + Vector3i(x, y, z)
					if taken.has(cell):
						continue
					taken[cell] = true
					out.append(cell)
	return out


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)
