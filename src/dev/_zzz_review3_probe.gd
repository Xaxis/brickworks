## Temporary review probe 3.
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

	_positive_face_failures()
	_fallback_cover()
	quit(0)


func _positive_face_failures() -> void:
	print("== failures on up / +x / +z, named ==")
	for host: String in ["3005", "3001", "3024", "87087", "4070", "99207",
			"44728", "3062b", "3070b"]:
		if not library.parts.has(host):
			continue
		for face: String in ["up", "+x", "+z"]:
			var placed := {"part": host, "color": 1, "x": 4, "y": 8, "z": 4,
				"face": face, "rot": 0}
			var answer: String = assistant._attachment_points(placed)
			for line: String in answer.split("\n"):
				if not line.strip_edges().begins_with("stud "):
					continue
				var at: Dictionary = _read(line)
				if at.is_empty():
					continue
				for guest: String in ["3001", "3020"]:
					var model := Assistant.Model.new()
					for raw: Variant in [placed, {
							"part": guest, "color": 15,
							"x": at["x"], "y": at["y"], "z": at["z"],
							"face": at["face"], "rot": 0}]:
						model.placements.append(
							Assistant.Placement.from_dict(raw))
					var verdict: Dictionary = assistant._check(model)
					for c: String in str(verdict["feedback"]).split("\n"):
						if c.contains("brick 1 "):
							print("  host %s face %s guest %s | %s | %s"
								% [host, face, guest, line.strip_edges(),
									c.strip_edges()])


## For parts with no collision cover, does the bounding box fallback in
## Builder._cells_for really cover the whole part?
func _fallback_cover() -> void:
	print("== bounds fallback for parts with no cover ==")
	var loaded: int = 0
	var no_boxes: int = 0
	var under: int = 0
	var shown: int = 0
	var ids: Array = library.parts.keys()
	ids.shuffle()
	for part_id: String in ids:
		if loaded >= 1200:
			break
		var info: PartLibrary.PartInfo = library.parts[part_id]
		if info.is_redirect() or not info.reachable:
			continue
		if not FileAccess.file_exists(
				library._resolve_root() + "parts/" + info.mesh_hash + ".lbm"):
			continue
		var mesh: Lbm.PartMesh = library.mesh_for(part_id)
		if mesh == null:
			continue
		loaded += 1
		if not mesh.boxes.is_empty():
			continue
		no_boxes += 1
		var box: AABB = mesh.bounds
		if box.size == Vector3.ZERO:
			print("  %s has zero-size bounds -> no cells at all" % part_id)
			continue
		var lo := Vector3(
			floor(box.position.x / 2.0), floor(box.position.y / 2.0),
			floor(box.position.z / 2.0))
		var size := Vector3(
			ceil(box.size.x / 2.0), ceil(box.size.y / 2.0),
			ceil(box.size.z / 2.0))
		var covered_hi: Vector3 = (lo + size) * 2.0
		var real_hi: Vector3 = box.position + box.size
		if (covered_hi.x < real_hi.x - 0.001 or covered_hi.y < real_hi.y - 0.001
				or covered_hi.z < real_hi.z - 0.001):
			under += 1
			if shown < 6:
				shown += 1
				print("  %s bounds %s..%s, cover reaches only %s"
					% [part_id, box.position, real_hi, covered_hi])
	print("  %d loaded, %d with no cover, %d of those under-covered"
		% [loaded, no_boxes, under])


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
