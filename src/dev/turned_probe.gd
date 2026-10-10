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
## turns and boxes, and that it is quicker.
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
	print("")
	if _failures == 0:
		print("a turned part takes the cells it always did, quickly")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


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
