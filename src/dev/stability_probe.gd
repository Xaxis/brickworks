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
	print("mass check (published in brackets):")
	for pair: Array in [["3005", 0.44], ["3004", 0.78], ["3622", 1.18],
			["3010", 1.74], ["3003", 1.18], ["3001", 2.20], ["2456", 3.28]]:
		var info: PartLibrary.PartInfo = library.parts.get(pair[0])
		if info:
			print("  %-6s %5.2f g  [%.2f]  %s" % [
				pair[0], Stability._grams(info), pair[1],
				info.name.strip_edges()])

	print("\narrangements:")
	_case(library, "a tidy stack of four 2x4", _stack(4), true)
	_case(library, "a wall, joints staggered", _wall(), true)
	_case(library, "a properly bonded arm, 2 studs of overlap", _arm(7), false)
	_case(library, "a slab resting on a single 1x1", _pillar(), false)

	if _failures > 0:
		print("\n%d case(s) wrong" % _failures)
	quit(1 if _failures > 0 else 0)


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
