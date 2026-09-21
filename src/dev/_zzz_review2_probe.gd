## Temporary review probe 2.
extends SceneTree

var library: PartLibrary
var world: BrickWorld
var builder: Builder
var assistant: Assistant


func _initialize() -> void:
	library = PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	world = BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	builder = Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	assistant = Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	await process_frame

	_overlap_message()
	_advice_summary()
	_ray()
	quit(0)


func _overlap_message() -> void:
	print("== which brick does the overlap message name ==")
	var model := Assistant.Model.new()
	# 0: a 2x4 at the origin. 1: a plate well away. 2: right on top of 0.
	for raw: Variant in [
			{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0},
			{"part": "3024", "color": 1, "x": 10, "y": 0, "z": 10},
			{"part": "3001", "color": 2, "x": 0, "y": 1, "z": 0}]:
		model.placements.append(Assistant.Placement.from_dict(raw))
	var verdict: Dictionary = assistant._check(model)
	print(verdict["feedback"])
	print("  (placement 2 sits inside placement 0; there is no placement 3)")


func _advice_summary() -> void:
	print("== attachment advice: which face/guest combinations fail ==")
	var tally: Dictionary = {}
	for host: String in ["3005", "3001", "3024", "87087", "4070", "99207",
			"44728", "3062b", "3070b"]:
		if not library.parts.has(host):
			continue
		for face: String in BrickLattice.FACES:
			var placed := {"part": host, "color": 1, "x": 4, "y": 8, "z": 4,
				"face": face, "rot": 0}
			var answer: String = assistant._attachment_points(placed)
			for line: String in answer.split("\n"):
				if not line.strip_edges().begins_with("stud "):
					continue
				var at: Dictionary = _read(line)
				if at.is_empty():
					continue
				for guest: String in ["3024", "3020", "3001", "3005"]:
					if not library.parts.has(guest):
						continue
					var model := Assistant.Model.new()
					for raw: Variant in [placed, {
							"part": guest, "color": 15,
							"x": at["x"], "y": at["y"], "z": at["z"],
							"face": at["face"], "rot": 0}]:
						model.placements.append(
							Assistant.Placement.from_dict(raw))
					var verdict: Dictionary = assistant._check(model)
					var bad: bool = false
					for c: String in str(verdict["feedback"]).split("\n"):
						if c.contains("brick 1 "):
							bad = true
					var key: String = "%s guest %s" % [at["face"], guest]
					var counts: Array = tally.get(key, [0, 0])
					counts[0] += 1
					if bad:
						counts[1] += 1
					tally[key] = counts
	var keys: Array = tally.keys()
	keys.sort()
	for key: String in keys:
		print("  %-18s %d of %d refused" % [key, tally[key][1], tally[key][0]])


func _ray() -> void:
	print("== raycast against the cells the same part occupies ==")
	var lattice: BrickLattice = builder.lattice
	lattice.clear()
	var mesh: Lbm.PartMesh = library.mesh_for("3005")
	# Two 1x1 bricks side by side, the first over x 0..20, the second 20..40.
	for n: int in 2:
		var p: Assistant.Placement = Assistant.Placement.from_dict(
			{"part": "3005", "color": 4, "x": n, "y": 0, "z": 0})
		var at: Transform3D = assistant._transform(p, mesh)
		var cells: Array[Vector3i] = builder._cells_for(mesh, at)
		var lo := Vector3i(99, 99, 99)
		var hi := Vector3i(-99, -99, -99)
		for c: Vector3i in cells:
			lo = Vector3i(mini(lo.x, c.x), mini(lo.y, c.y), mini(lo.z, c.z))
			hi = Vector3i(maxi(hi.x, c.x), maxi(hi.y, c.y), maxi(hi.z, c.z))
		lattice.occupy(n + 1, cells)
		print("  brick %d origin %s cells x %d..%d y %d..%d z %d..%d"
			% [n + 1, at.origin, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])

	for x: float in [1.0, 10.0, 18.0, 19.0, 19.5, 20.0, 21.0, 30.0, 39.0]:
		var hit: BrickLattice.Hit = lattice.raycast(
			Vector3(x, 200.0, 10.0), Vector3.DOWN)
		print("  ray down at x=%s LDU hits brick %d (cell %s)"
			% [x, hit.brick_id, hit.cell])
	print("  brick 1 really occupies x 0..20 LDU, brick 2 x 20..40")


func _read(line: String) -> Dictionary:
	var out: Dictionary = {}
	for token: String in line.split(" ", false):
		var bits: PackedStringArray = token.split("=")
		if bits.size() != 2:
			continue
		if bits[0] == "face":
			out["face"] = bits[1]
		elif bits[0] in ["x", "y", "z"]:
			out[bits[0]] = float(bits[1])
	return out if out.size() == 4 else {}
