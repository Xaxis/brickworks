## Temporary review probe. godot --headless --path . --script src/dev/_zzz_review_probe.gd
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

	_roundtrip()
	_fractional()
	_empty_cover()
	_advice()
	quit(0)


func _roundtrip() -> void:
	print("== round trip _transform -> _to_studs ==")
	var bad: int = 0
	var n: int = 0
	for part_id: String in ["3024", "3001", "3005", "3020", "87087",
			"4070", "3062b", "3070b", "3040b", "3622", "2412b"]:
		if not library.parts.has(part_id):
			print("  skip %s" % part_id)
			continue
		var mesh: Lbm.PartMesh = library.mesh_for(part_id)
		if mesh == null:
			print("  skip %s (no mesh)" % part_id)
			continue
		for face: String in BrickLattice.FACES:
			for rot: int in 4:
				var raw := {"part": part_id, "color": 4, "x": 3.0, "y": 8.0,
					"z": 5.0, "face": face, "rot": rot}
				var p: Assistant.Placement = Assistant.Placement.from_dict(raw)
				var at: Transform3D = assistant._transform(p, mesh)
				var id: int = world.add_brick(part_id, 4, at)
				var brick: BrickWorld.Brick = world.get_brick(id)
				var back: Vector3 = assistant._to_studs(
					brick, library.parts[part_id])
				n += 1
				if not back.is_equal_approx(Vector3(3.0, 8.0, 5.0)):
					bad += 1
					if bad < 12:
						print("  MISMATCH %s face=%s rot=%d -> %s"
							% [part_id, face, rot, back])
				# also: is the face/rot readable back?
				var f2: String = BrickLattice.face_of(at.basis)
				var r2: int = BrickLattice.turns_about(at.basis, f2)
				if f2 != face or r2 != rot:
					print("  ORIENT %s asked face=%s rot=%d read face=%s rot=%d"
						% [part_id, face, rot, f2, r2])
				world.remove_brick(id)
	print("  %d checked, %d mismatched" % [n, bad])


func _fractional() -> void:
	print("== off lattice coordinates ==")
	var mesh: Lbm.PartMesh = library.mesh_for("3024")
	for raw: Dictionary in [
			{"x": 0.55, "y": 2.0, "z": 0.0},
			{"x": -0.55, "y": 2.0, "z": 0.0},
			{"x": 0.05, "y": 2.0, "z": 0.0},
			{"x": -0.05, "y": 2.0, "z": 0.0},
			{"x": 0.0, "y": 2.125, "z": 0.0},
			{"x": 0.0, "y": -0.125, "z": 0.0},
			{"x": 0.33, "y": 1.0, "z": 0.66}]:
		var full: Dictionary = raw.duplicate()
		full["part"] = "3024"
		full["color"] = 4
		full["face"] = "up"
		full["rot"] = 0
		var p: Assistant.Placement = Assistant.Placement.from_dict(full)
		var at: Transform3D = assistant._transform(p, mesh)
		var id: int = world.add_brick("3024", 4, at)
		var back: Vector3 = assistant._to_studs(
			world.get_brick(id), library.parts["3024"])
		print("  asked %s -> origin %s -> read back %s"
			% [raw, at.origin, back])
		world.remove_brick(id)


func _empty_cover() -> void:
	print("== parts with no collision cover ==")
	var checked: int = 0
	var empty: PackedStringArray = PackedStringArray()
	for part_id: String in library.parts.keys():
		var info: PartLibrary.PartInfo = library.parts[part_id]
		if info.is_redirect() or not info.reachable:
			continue
		if not library.is_resident(part_id):
			continue
		var mesh: Lbm.PartMesh = library.mesh_for(part_id)
		checked += 1
		if mesh == null:
			continue
		if mesh.boxes.is_empty():
			empty.append(part_id)
	print("  %d resident parts, %d with empty boxes: %s"
		% [checked, empty.size(), ", ".join(empty)])
	# force-load a wider sample from disk
	var loaded: int = 0
	var no_boxes: PackedStringArray = PackedStringArray()
	var degenerate: PackedStringArray = PackedStringArray()
	for part_id: String in library.parts.keys():
		if loaded >= 400:
			break
		var info: PartLibrary.PartInfo = library.parts[part_id]
		if info.is_redirect() or not info.reachable:
			continue
		var mesh: Lbm.PartMesh = library.mesh_for(part_id)
		if mesh == null:
			continue
		loaded += 1
		if mesh.boxes.is_empty():
			no_boxes.append(part_id)
			var cells: Array[Vector3i] = builder._cells_for(
				mesh, Transform3D.IDENTITY)
			if cells.is_empty():
				degenerate.append(part_id)
	print("  %d loaded from disk, %d with no boxes (%s), %d giving no cells (%s)"
		% [loaded, no_boxes.size(), ", ".join(no_boxes),
			degenerate.size(), ", ".join(degenerate)])


func _advice() -> void:
	print("== attachment advice, all six faces, larger parts ==")
	var fails: int = 0
	var checked: int = 0
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
				for guest: String in ["3024", "3020", "3001"]:
					for grot: int in [0, 1]:
						if not library.parts.has(guest):
							continue
						checked += 1
						var model := Assistant.Model.new()
						for raw: Variant in [placed, {
								"part": guest, "color": 15,
								"x": at["x"], "y": at["y"], "z": at["z"],
								"face": at["face"], "rot": grot}]:
							model.placements.append(
								Assistant.Placement.from_dict(raw))
						var verdict: Dictionary = assistant._check(model)
						var wrong := PackedStringArray()
						for c: String in str(verdict["feedback"]).split("\n"):
							if c.contains("brick 1 "):
								wrong.append(c.strip_edges().lstrip("- "))
						if wrong.is_empty():
							continue
						fails += 1
						if fails < 25:
							print("  FAIL host %s face %s guest %s rot %d | %s"
								% [host, face, guest, grot,
									line.strip_edges()])
							for c: String in wrong:
								print("        " + c)
	print("  %d checked, %d failed" % [checked, fails])


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
