## Ask every real set's parts the half-stud question, and list what it refuses.
##
##   godot --headless --path . --script src/dev/half_studs_in_sets.gd -- DIR [FIRST COUNT]
##
## DIR is vendor/omr/files (tools/omr.py fetch), or any folder of .ldr and
## .mpd files. Each set is flattened, its upright parts square to the grid
## read back as placements, and every part standing on another half a stud
## off it is put to Assistant._note_loose, as the check puts it. A real set
## is built, so what it refuses is the rule's to answer for, or the set
## file's: each line names the two parts, how many studs reach up into the
## upper one, how many land, each one's distance in LDU from where it would
## be taken, and — the arbiter — how much of the upper part's own mesh lies
## inside each stud it refuses for. Plastic inside a stud is a file that
## puts two solids in one place; none means the rule refused a real seat.
##
## Not a probe: it needs the repository's files, which are not fetched by
## default, and a run over the 328 fetched sets is a few minutes. What it
## found, 2026-10-11: the first version of the rule refused 477 seats, and
## the mesh showed most of them real (flower stems between four studs, an
## angled tile's open end, a pig, a roll cage, train bases). It refuses 31
## of 2,828 now, none on a jumper and every one with the part's plastic
## inside a stud in the file: a sub-assembly seated half a stud off the one
## under it (6542's deck on its boat studs, 7735's platform, 31049's
## cockpit), or one part typed half a stud out between two that agree
## (6598's 2 x 2 plate at z=70 between a 6 x 10 and a box at 60). Named
## without _probe so a run of every probe does not run it.
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("give the folder of sets after --")
		quit(2)
		return
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
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

	var files: Array = []
	for file: String in DirAccess.get_files_at(args[0]):
		if file.ends_with(".mpd") or file.ends_with(".ldr"):
			files.append(file)
	files.sort()
	var first: int = int(args[1]) if args.size() > 1 else 0
	var count: int = int(args[2]) if args.size() > 2 else files.size()
	var counts := Vector3i.ZERO
	for file: String in files.slice(first, first + count):
		var model: Assistant.Model = _placed(assistant, library,
			LdrModel.load_file(args[0].path_join(file)))
		counts += _judge(assistant, library, builder, model, file)
	print("%d half-stud seats in %d files, %d refused, %d of them with the part's "
		% [counts.x, mini(count, files.size() - first), counts.y, counts.z]
		+ "plastic inside a stud in the file itself")
	quit(0)


## The set's upright parts, square to the grid, as placements: the inverse
## of Assistant._square_transform, as clutch_probe reads a shipped model.
func _placed(assistant: Assistant, library: PartLibrary, ldr: LdrModel) -> Assistant.Model:
	var model := Assistant.Model.new()
	if ldr == null:
		return model
	for piece: LdrModel.Placement in ldr.flatten():
		var id: String = piece.part_id.to_lower().trim_suffix(".dat")
		var part: Lbm.PartMesh = library.mesh_for(id)
		if part == null or not BrickLattice.is_square_to_grid(piece.transform.basis):
			continue
		var basis: Basis = BrickLattice.snap_basis(piece.transform.basis)
		var put := Assistant.Placement.new()
		put.part = id
		put.face = BrickLattice.face_of(basis)
		put.rot = BrickLattice.turns_about(basis, put.face)
		if not BrickLattice.basis_for(put.face, put.rot).is_equal_approx(basis):
			continue
		var cell: Vector3i = BrickLattice.to_cell(piece.transform.origin) \
			+ assistant._corner_cell(part, id, basis)
		put.x = float(cell.x) / BrickLattice.CELLS_PER_STUD
		put.y = float(cell.y) / BrickLattice.CELLS_PER_PLATE
		put.z = float(cell.z) / BrickLattice.CELLS_PER_STUD
		model.placements.append(put)
	return model


## Each part on another, as _check_support finds it, put to _note_loose;
## the half-stud refusals printed, each with whether the file itself has the
## part's plastic inside a stud there. Returns [seats judged, refused,
## refused where it does].
func _judge(assistant: Assistant, library: PartLibrary, builder: Builder,
		model: Assistant.Model, file: String) -> Vector3i:
	var lattice := BrickLattice.new()
	lattice.keeps_columns = false
	var cells_of: Dictionary = {}
	for index: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		var packed: PackedInt32Array = builder.boxes_for(part,
			assistant._transform(placement, part))
		if not packed.is_empty():
			lattice.occupy_boxes(index + 1, packed)
			cells_of[index] = packed
	var studs_in: Dictionary = {}
	for pair: Array in assistant._studs_reaching_in(model, cells_of, lattice):
		if not studs_in.has(pair[1]):
			studs_in[pair[1]] = []
		(studs_in[pair[1]] as Array).append(pair.slice(2))
	var counts := Vector3i.ZERO
	for index: int in studs_in:
		var below: int = _below(lattice, cells_of.get(index, PackedInt32Array()), index)
		if below < 0:
			continue
		var placement: Assistant.Placement = model.placements[index]
		var under: Assistant.Placement = model.placements[below]
		var across: float = absf(placement.x - under.x)
		var along: float = absf(placement.z - under.z)
		if not (Assistant._on_the_grid(across) and Assistant._on_the_grid(along)) \
				or (Assistant._on_the_grid(across, 1.0) and Assistant._on_the_grid(along, 1.0)) \
				or placement.face not in ["up", "down"] or under.face not in ["up", "down"]:
			continue
		counts.x += 1
		var issues: Dictionary = {}
		assistant._note_loose({}, model, index, below, true, issues, studs_in[index])
		if not str(issues.get("off its studs", [])).contains("half a stud off"):
			continue
		counts.y += 1
		var seen: Array = assistant._underside(model, index, studs_in[index])
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		var into: Transform3D = assistant._transform(placement, part).affine_inverse()
		var triangles: PackedVector3Array = _triangles(library, placement.part)
		var gaps := PackedStringArray()
		var plastic := PackedStringArray()
		var landed: int = 0
		var inside: bool = false
		for stud: Array in studs_in[index]:
			var at: Vector3 = stud[0]
			var flat := Vector2(at.x, at.z) / Assistant.STUD
			var nearest: float = INF
			for take: Vector2 in seen[2]:
				nearest = minf(nearest, flat.distance_to(take))
			landed += 1 if nearest <= Assistant.IN_A_SOCKET else 0
			gaps.append("%.1f" % (nearest * Assistant.STUD))
			if nearest > Assistant.IN_A_SOCKET and nearest < Assistant.HALF_OFF:
				var hits: int = _in_ring(triangles, into * at,
					(into.basis * (stud[1] as Vector3)).normalized())
				plastic.append(str(hits))
				inside = inside or hits > 0
		counts.z += 1 if inside else 0
		var upper: PartLibrary.PartInfo = library.parts.get(placement.part)
		var lower: PartLibrary.PartInfo = library.parts.get(under.part)
		print("%s | %s on %s | %s on %s | studs %d, in %d | LDU %s | plastic %s | %s" % [
			file, placement.part, under.part,
			upper.family_category() if upper != null else "?",
			lower.family_category() if lower != null else "?",
			(studs_in[index] as Array).size(), landed, ",".join(gaps), ",".join(plastic),
			"the file has the part's plastic inside a stud" if inside
				else "NOTHING IN THE WAY: the rule refuses a real seat"])
	return counts


## Every triangle of a part, three points each, in its own LDU, read from
## its .lbm: the app keeps them only on the GPU.
static func _triangles(library: PartLibrary, id: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var info: PartLibrary.PartInfo = library.parts.get(id)
	if info == null:
		return out
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		library._resolve_root() + "parts/" + info.mesh_hash + ".lbm")
	if bytes.size() < Lbm.HEADER_SIZE:
		return out
	var scale: float = 1.0 / bytes.decode_float(8)
	var offset: int = Lbm.HEADER_SIZE
	for _surface: int in bytes.decode_u16(6):
		var vertex_count: int = bytes.decode_u32(offset + 4)
		var index_count: int = bytes.decode_u32(offset + 8)
		offset += 12
		var points := PackedVector3Array()
		points.resize(vertex_count)
		for v: int in vertex_count:
			var at: int = offset + v * Lbm.VERTEX_SIZE
			points[v] = Vector3(bytes.decode_s16(at), bytes.decode_s16(at + 2),
				bytes.decode_s16(at + 4)) * scale
		offset += vertex_count * Lbm.VERTEX_SIZE
		var stride: int = 2 if vertex_count <= 0xFFFF else 4
		for i: int in index_count:
			var at: int = offset + i * stride
			out.append(points[bytes.decode_u16(at) if stride == 2 else bytes.decode_u32(at)])
		offset += index_count * stride
	return out


## How many points sampled over the part's triangles lie in the ring of a
## stud standing at [param base] along [param way]: 4.5 to 5.6 LDU from its
## axis (a hollow stud has room for a post inside), 0.5 to 3.5 LDU up. A
## stud in a socket, a tube or round a post has none; one half a stud off
## a plain part's has its wall or its tube in it. Checked first on known
## seats: a 2x2 half a stud along a 2x4, 150 to 353 a stud; whole, on a
## 3794b's stud by its tube, a 1x2's post on one: none.
static func _in_ring(triangles: PackedVector3Array, base: Vector3, way: Vector3) -> int:
	var hits: int = 0
	for t: int in range(0, triangles.size(), 3):
		var a: Vector3 = triangles[t]
		var b: Vector3 = triangles[t + 1]
		var c: Vector3 = triangles[t + 2]
		var lo: Vector3 = a.min(b).min(c)
		var hi: Vector3 = a.max(b).max(c)
		if hi.x < base.x - 7.0 or lo.x > base.x + 7.0 or hi.z < base.z - 7.0 \
				or lo.z > base.z + 7.0 or hi.y < base.y - 1.0 or lo.y > base.y + 5.0:
			continue
		var longest: float = maxf((b - a).length(), maxf((c - b).length(), (a - c).length()))
		var steps: int = clampi(ceili(longest / 0.6), 2, 600)
		for i: int in steps + 1:
			for j: int in steps + 1 - i:
				var d: Vector3 = a + (b - a) * (float(i) / steps) \
					+ (c - a) * (float(j) / steps) - base
				var up: float = d.dot(way)
				if up < 0.5 or up > 3.5:
					continue
				var out: float = (d - way * up).length()
				if out > 4.5 and out < 5.6:
					hits += 1
	return hits


## The first part found in the slab one cell under [param cover], or -1.
static func _below(lattice: BrickLattice, cover: PackedInt32Array, index: int) -> int:
	if cover.is_empty():
		return -1
	var floor_y: int = 0x7FFFFFFF
	for at: int in range(1, cover.size(), 6):
		floor_y = mini(floor_y, cover[at])
	var under := PackedInt32Array()
	for at: int in range(0, cover.size(), 6):
		if cover[at + 1] == floor_y:
			under.append_array(PackedInt32Array([cover[at], floor_y - 1,
				cover[at + 2], cover[at + 3], floor_y, cover[at + 5]]))
	for found: int in lattice.blockers_boxes(under, index + 1):
		if found > 0 and found - 1 != index:
			return found - 1
	return -1
