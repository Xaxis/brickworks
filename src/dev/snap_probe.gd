## Where does a brick actually land when you point at a stud?
##
##   godot --headless --path . --script src/dev/snap_probe.gd
##
## A part's origin is its centre, so where it may sit depends on how
## wide it is: a part one stud across is centred ON a stud, and a part
## two across is centred on the line BETWEEN two. Get that phase
## backwards and every brick placed by hand is half a stud out of step
## with every brick placed by the assistant — which uses its own
## transform and never goes through here.
##
## Half a stud is 4 mm. It is not subtle once two bricks meet.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	# Where the assistant puts things, which is the answer the hand
	# placement has to agree with: origin = (studs + width/2) * STUD.
	for case: Array in [
		["3005", 1, "one stud across"],
		["3004", 2, "two studs across"],
		["3622", 3, "three studs across"],
		["3001", 4, "four studs across"],
	]:
		var part: String = case[0]
		var across: int = case[1]
		var info: PartLibrary.PartInfo = library.parts[part]
		var footprint: Vector2i = info.footprint_studs()

		# What the assistant would produce for stud column 0, 1, 2.
		var wanted := PackedFloat32Array()
		for column: int in 3:
			wanted.append((column + across * 0.5) * BrickLattice.STUD)

		# What snapping produces for a cursor near each of those.
		var got := PackedFloat32Array()
		for column: int in 3:
			var near: Vector3 = Vector3(wanted[column] + 3.0, 0.0, 0.0)
			got.append(BrickLattice.snap_to_studs(near, footprint).x)

		var agrees: bool = true
		for column: int in 3:
			if absf(got[column] - wanted[column]) > 0.01:
				agrees = false
		_check("%s (%s): snapped to %s, the assistant uses %s" % [
			part, case[2],
			", ".join(PackedStringArray(Array(got).map(
				func(v: float) -> String: return "%.0f" % v))),
			", ".join(PackedStringArray(Array(wanted).map(
				func(v: float) -> String: return "%.0f" % v)))],
			agrees)

	print("")
	_which_cell()

	print("")
	print("%d disagree" % _failures if _failures
		else "hand placement lands where the assistant would put it")
	quit(1 if _failures else 0)


## Does to_cell name the cell a point is actually in?
##
## Cell i is the span from i * CELL up to but not including the next
## one, which is what occupancy and cells_for both assume. to_cell used
## to round to the nearest instead, which is a different question with
## the same shape: a point at 25 LDU is in cell 12, spanning 24 to 26,
## and rounding said 13.
##
## Every position this project builds is cell-aligned and those agree
## either way, so nothing caught it. What it got wrong is the points in
## between — where a ray struck a brick, and where the tip of a stud
## lands — which is to say: what you clicked on, and what holds a part
## on that is not sitting on anything.
func _which_cell() -> void:
	var cell: float = BrickLattice.CELL
	for ldu: float in [0.0, 0.1, 1.0, 1.9, 2.0, 2.1, 24.0, 25.0, 25.9,
			-0.1, -1.0, -2.0, -2.1, -25.0]:
		var got: int = BrickLattice.to_cell(Vector3(ldu, ldu, ldu)).x
		# The cell a point is in is the one whose span contains it.
		var holds: bool = (got * cell <= ldu and ldu < (got + 1) * cell)
		_check("%.1f LDU is in cell %d" % [ldu, got], holds)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
