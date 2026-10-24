## Check the stability model against arrangements whose answer is known.
##
##   godot --headless --path . --script src/dev/stability_probe.gd
##
## Exits non-zero when a case comes out wrong, so it can be run as a
## check rather than only read.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	# Mass first: derived from volume, so it has to land near the
	# published figures or nothing built on it means anything.
	print("mass check (BrickLink's weights in brackets; balance_probe holds them to 8%):")
	for pair: Array in [["3005", 0.44], ["3004", 0.83], ["3003", 1.35],
			["3010", 1.64], ["3001", 2.32], ["2456", 3.74], ["3008", 3.21]]:
		var info: PartLibrary.PartInfo = library.parts.get(pair[0])
		if info:
			print("  %-6s %5.2f g  [%.2f]  %s" % [
				pair[0], Stability.grams(info), pair[1],
				info.name.strip_edges()])

	print("\narrangements:")
	_case(library, "a tidy stack of four 2x4", _stack(4), true)
	_case(library, "a wall, joints staggered", _wall(), true)
	_case(library, "a properly bonded arm, 2 studs of overlap", _arm(7), false)
	_case(library, "a slab resting on a single 1x1", _pillar(), false)

	await _contacts_are_what_the_lattice_says(library)
	await _checking_costs_about_what_building_costs(library)
	await _a_tall_model_costs_no_more(library)
	await _turned_parts_cost_no_more(library)

	if _failures > 0:
		print("\n%d case(s) wrong" % _failures)
	quit(1 if _failures > 0 else 0)


## The contact graph has to be the lattice's own view of what touches
## what, because collision already is.
##
## It used to be neither: the lower brick's cells came from the box
## *span* of its parts and the upper brick's from the lattice, which
## holds the exact cells. On the kart that reported 41 joints where
## there are 42.
##
## Walking the lattice cell by cell is the authoritative count and the
## reason the whole thing was slow, so it is used here on small models
## only, as the thing to agree with. It cannot settle a model where two
## parts are registered over the same cells: `brick_at` names one owner
## per cell, so the walk sees one relationship and the boxes see both.
## The house was one, by 1, until its bush was set a stud clear of the
## 2 x 2 tile beside it (2026-10-23): seated on their studs, the leaves
## reached across the tile, over cells it owns. The lighthouse was one, by
## 2, until its slopes were seated on their studs (2026-10-11): half a stud
## off them, two of the eight reached into the brick beside.
func _contacts_are_what_the_lattice_says(library: PartLibrary) -> void:
	print("\nthe contact graph against a cell-by-cell walk of the lattice:")
	for pair: Array in [["kart.ldr", 0], ["car.ldr", 0],
			["bench.ldr", 0], ["house.ldr", 0], ["lighthouse.ldr", 0]]:
		var name: String = pair[0]
		var allowed: int = pair[1]
		var ldr: LdrModel = LdrModel.load_file("res://models/" + name)
		if ldr == null:
			continue
		var world := BrickWorld.new()
		world.library = library
		get_root().add_child(world)
		var builder := Builder.new()
		builder.world = world
		builder.library = library
		get_root().add_child(builder)
		await process_frame
		for piece: LdrModel.Placement in ldr.flatten():
			var part_id: String = piece.part_id.to_lower().trim_suffix(".dat")
			if library.mesh_for(part_id) == null:
				continue
			var id: int = world.add_brick(part_id, piece.color_code,
				piece.transform)
			if id != 0:
				builder.register(id, part_id, piece.transform)
		var walked: int = 0
		for item: Variant in world.bricks():
			var brick: BrickWorld.Brick = item
			for cell: Vector3i in BrickLattice.cells_in(
					builder.lattice.boxes_of(brick.id)):
				var over: int = builder.lattice.brick_at(
					Vector3i(cell.x, cell.y + 1, cell.z))
				if over != 0 and over != brick.id:
					walked += 1
					break
		var judge := Stability.new()
		judge.library = library
		judge.lattice = builder.lattice
		var report: Stability.Report = judge.check(world)
		var differ: int = report.joints - walked
		if differ == allowed:
			print("  ok    %-16s %d joints, the walk says %d"
				% [name, report.joints, walked])
		else:
			_failures += 1
			print("  FAIL  %-16s %d joints against the walk's %d, "
				% [name, report.joints, walked]
				+ "a difference of %d where %d is expected"
					% [differ, allowed])
		world.queue_free()
		builder.queue_free()
		await process_frame


## Checking a model must not cost much more than building one.
##
## Not a wall clock, because a loaded machine makes any number look like
## a regression. Not a ratio of one size to another either: the version
## this replaced asked the lattice what was in the cell above every cell
## of every brick — nine thousand six hundred lookups a brick — and that
## is *linear in bricks* too, just with a constant four hundred times
## larger. A hundred bricks took 3.7 s and eight hundred took 29.5, which
## is the same shape of curve as the fast one.
##
## What tells them apart is the constant, and what measures a constant
## without a clock is something else on the same machine. Laying the
## bricks is the natural yardstick: the old check cost **84 times** the
## cost of building the model it was checking, the new one costs about a
## tenth of it.
func _checking_costs_about_what_building_costs(library: PartLibrary) -> void:
	print("\nand what it costs, against the cost of building the model:")
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	await process_frame
	var began: int = Time.get_ticks_usec()
	for n: int in 800:
		var at := Transform3D(Basis(), Vector3(
			float(n % 20) * 40.0 + (20.0 if (n / 20) % 2 == 1 else 0.0),
			float(n / 20) * 24.0, 0.0))
		var id: int = world.add_brick("3001", 4, at)
		if id != 0:
			builder.register(id, "3001", at)
	var built: int = maxi(1, Time.get_ticks_usec() - began)
	began = Time.get_ticks_usec()
	var judge := Stability.new()
	judge.library = library
	judge.lattice = builder.lattice
	judge.check(world)
	var checked: int = Time.get_ticks_usec() - began
	var times: float = float(checked) / float(built)
	if times < 3.0:
		print("  ok    800 bricks: built in %d ms, checked in %d — %.2f times"
			% [built / 1000, checked / 1000, times])
	else:
		_failures += 1
		print("  FAIL  checking 800 bricks costs %.1f times building them "
			% times + "(%d ms against %d) — it was 84 times when the "
				% [checked / 1000, built / 1000]
			+ "check asked the lattice about every cell of every brick")
	world.queue_free()
	builder.queue_free()
	await process_frame


## And a tall one. The 800 bricks above are forty courses; the owner's Falcon
## Heavy (src/dev/fixtures/falcon_heavy.json) is 4,242 parts and 332 plates,
## about seven hundred cuts, and asking at every cut about every brick made
## the check 3.5 s — twelve times building the model — where the wall above
## never showed it. The app asks after every change, and while the build
## animation played it asked about once a frame.
func _a_tall_model_costs_no_more(library: PartLibrary) -> void:
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	await process_frame
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://src/dev/fixtures/falcon_heavy.json"))
	var bricks: Array = []
	for row: Array in fixture["bricks"]:
		bricks.append({"part": row[0], "color": row[1], "x": row[2], "y": row[3],
			"z": row[4], "face": row[5], "rot": row[6]})
	var model: Assistant.Model = assistant._read_model({"bricks": bricks})
	for placement: Assistant.Placement in model.placements:
		library.mesh_for(placement.part)
	var began: int = Time.get_ticks_usec()
	assistant._apply(model)
	var built: int = maxi(1, Time.get_ticks_usec() - began)
	began = Time.get_ticks_usec()
	var judge := Stability.new()
	judge.library = library
	judge.lattice = builder.lattice
	var report: Stability.Report = judge.check(world)
	var checked: int = Time.get_ticks_usec() - began
	var times: float = float(checked) / float(built)
	if times < 3.0 and world.brick_count() == 4242:
		print("  ok    the Falcon, %d bricks and 332 plates tall: built in %d ms, "
			% [world.brick_count(), built / 1000]
			+ "checked in %d — %.2f times (%s)" % [checked / 1000, times,
				report.summary()])
	else:
		_failures += 1
		print("  FAIL  checking the %d-brick Falcon costs %.1f times building it "
			% [world.brick_count(), times] + "(%d ms against %d) — it was 12 "
				% [checked / 1000, built / 1000]
			+ "times when every cut summed every brick")
	assistant.queue_free()
	world.queue_free()
	builder.queue_free()
	await process_frame


## And one built of turned parts. A turned part's cover is a slice a cell
## deep for every z it spans, forty boxes for a turned 2 x 4 and eight
## hundred for a big turned plate, and counting what two of them share box
## against box was 10.4 s of Orthanc's 11 s check (8,785 parts, 5,345 of
## them turned; run 18), four times building it. The covers are compared
## slice by slice now (BrickLattice.shared_lifted), which must count
## exactly what box against box counts, lifted and as they stand.
func _turned_parts_cost_no_more(library: PartLibrary) -> void:
	var ldr: LdrModel = LdrModel.load_file("res://models/orthanc.ldr")
	if ldr == null:
		_failures += 1
		print("  FAIL  no models/orthanc.ldr")
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	await process_frame
	var pieces: Array = ldr.flatten()
	for piece: LdrModel.Placement in pieces:
		library.mesh_for(piece.part_id.to_lower().trim_suffix(".dat"))
	var began: int = Time.get_ticks_usec()
	for piece: LdrModel.Placement in pieces:
		var part_id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(part_id) == null:
			continue
		var id: int = world.add_brick(part_id, piece.color_code, piece.transform)
		if id != 0:
			builder.register(id, part_id, piece.transform)
	var built: int = maxi(1, Time.get_ticks_usec() - began)
	var lattice: BrickLattice = builder.lattice
	# Slice by slice against box by box, on every joint of the first
	# thousand turned parts: lifted, and as they stand (the cells two parts
	# already share, which Stability.stud_joints takes off what rests).
	var pairs: int = 0
	var wrong: int = 0
	var turned: int = 0
	var overlapping: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if turned >= 1000 or BrickLattice.is_square_to_grid(brick.transform.basis):
			continue
		turned += 1
		var mine: PackedInt32Array = lattice.boxes_of(brick.id)
		var lid: PackedInt32Array = BrickLattice.moved_by(mine, Vector3i(0, 1, 0))
		var slices: Array = BrickLattice.slices_of(mine)
		for over: int in lattice.near_bounds(lid, brick.id):
			var theirs: PackedInt32Array = lattice.boxes_of(over)
			pairs += 1
			var counted := Vector2i(BrickLattice.shared_cells(lid, theirs),
				BrickLattice.shared_cells(mine, theirs))
			if counted.y > 0:
				overlapping += 1
			if BrickLattice.shared_lifted(mine, slices, theirs) != counted \
					or BrickLattice.shared_lifted(mine, [], theirs) != counted:
				wrong += 1
	if wrong == 0 and pairs > 1000 and overlapping > 100:
		print("  ok    sliced and box by box count the same on %d pairs of Orthanc's turned parts, %d of them overlapping"
			% [pairs, overlapping])
	else:
		_failures += 1
		print("  FAIL  sliced and box by box differ on %d of %d pairs (%d overlapping)"
			% [wrong, pairs, overlapping])
	began = Time.get_ticks_usec()
	var judge := Stability.new()
	judge.library = library
	judge.lattice = lattice
	var report: Stability.Report = judge.check(world)
	var checked: int = Time.get_ticks_usec() - began
	var times: float = float(checked) / float(built)
	# Under 3, not 2: building Orthanc got twice as fast in m100 (a turned
	# cover worked out a line at a time), 803-831 ms to 433-444, while the
	# check stayed 1054-1152 ms; the ratio rose from 1.3 to 2.4-2.7 on
	# building's gain alone (2026-10-20). Under 3.5, not 3: the tower rebuilt
	# in one piece (m157, 9,541 parts to 10,094) ties its turned columns with
	# 288 more turned 1 x 2 plates and 312 more round bricks, cheap to build
	# and each beside several turned parts, so the check compares 33,839
	# pairs where it compared 28,005. Each pair costs what it did (50 us
	# against 51), the old tower still reads 2.5-2.7 by the same code, and
	# the new one 2.6-3.1 (2026-10-23). Box against box was 4.4 on the old.
	if times < 3.5 and world.brick_count() > 8000:
		print("  ok    Orthanc, %d bricks: built in %d ms, checked in %d — %.2f times (%s, %d joints)"
			% [world.brick_count(), built / 1000, checked / 1000, times,
				report.summary(), report.joints])
	else:
		_failures += 1
		print("  FAIL  checking the %d-brick Orthanc costs %.1f times building it "
			% [world.brick_count(), times] + "(%d ms against %d) — it was 4.4 "
				% [checked / 1000, built / 1000]
			+ "times when turned covers were compared box against box, 1.3 before "
			+ "building's covers were worked out a line at a time (m100), 2.4-2.7 after, "
			+ "2.6-3.1 on the tower rebuilt in one piece (m157)")
	world.queue_free()
	builder.queue_free()
	await process_frame


func _case(library: PartLibrary, label: String,
		placements: Array, expect_stable: bool) -> void:
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)

	var lattice := BrickLattice.new()
	for entry: Dictionary in placements:
		var at: Transform3D = Transform3D(Basis.IDENTITY, entry["at"])
		var id: int = world.add_brick(entry["part"], 4, at)
		if id != 0:
			var part: Lbm.PartMesh = library.mesh_for(entry["part"])
			lattice.occupy(id, BrickLattice.cells_for(
				part.boxes, BrickLattice.to_cell(at.origin), at.basis))

	var stability := Stability.new()
	stability.library = library
	stability.lattice = lattice
	var report: Stability.Report = stability.check(world)

	var got: bool = report.is_stable()
	if got != expect_stable:
		_failures += 1
	print("  %s %-38s %s" % [
		"OK " if got == expect_stable else "XX ", label, report.summary()])
	if not report.risks.is_empty():
		print("        %s" % report.risks[0].message)
	world.queue_free()


static func _stack(n: int) -> Array:
	var out: Array = []
	for i: int in n:
		out.append({"part": "3001", "at": Vector3(0, 24 + i * 24, 0)})
	return out


static func _wall() -> Array:
	var out: Array = []
	for course: int in 4:
		var offset: float = 40.0 if course % 2 else 0.0
		for n: int in 3:
			out.append({"part": "3001",
				"at": Vector3(n * 80.0 + offset, 24 + course * 24, 0)})
	return out


## An arm reaching out over nothing, each brick overlapping the one
## below by two studs so every piece is genuinely supported. It is a
## legal assembly and it would still bend down and let go at the root.
static func _arm(n: int) -> Array:
	var out: Array = [{"part": "3001", "at": Vector3(0, 24, 0)}]
	for i: int in n:
		out.append({"part": "3001",
			"at": Vector3(40.0 + i * 40.0, 48 + i * 24, 0)})
	return out


## A wide slab carried by one 1x1 brick: connected, supported, and far
## past what a single stud will hold.
static func _pillar() -> Array:
	var out: Array = [{"part": "3005", "at": Vector3(0, 24, 0)}]
	for i: int in 9:
		out.append({"part": "3001", "at": Vector3(0, 48 + i * 24, 0)})
	return out
