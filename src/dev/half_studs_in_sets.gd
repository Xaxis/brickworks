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
## upper one, how many land, and each one's distance in LDU from where it
## would be taken.
##
## Not a probe: it needs the repository's files, which are not fetched by
## default, and a run over the 328 fetched sets is about ten minutes. What it
## found, 2026-10-11: the first version of the rule refused 477 seats; it
## refuses 59 of the 2,828 it judges now, none of them on a jumper — plain
## plates exactly half a stud off in the set file, flower stems (3741)
## between four studs, train and turntable parts. Named without _probe so a
## run of every probe does not run it.
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
	var seats: int = 0
	var refused: int = 0
	for file: String in files.slice(first, first + count):
		var model: Assistant.Model = _placed(assistant, library,
			LdrModel.load_file(args[0].path_join(file)))
		var counts: Vector2i = _judge(assistant, library, builder, model, file)
		seats += counts.x
		refused += counts.y
	print("%d half-stud seats in %d files, %d refused" % [seats,
		mini(count, files.size() - first), refused])
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
## the half-stud refusals printed. Returns [seats judged, refused].
func _judge(assistant: Assistant, library: PartLibrary, builder: Builder,
		model: Assistant.Model, file: String) -> Vector2i:
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
	var counts := Vector2i.ZERO
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
		var gaps := PackedStringArray()
		var landed: int = 0
		for stud: Vector2 in seen[0]:
			var nearest: float = INF
			for take: Vector2 in seen[2]:
				nearest = minf(nearest, stud.distance_to(take))
			landed += 1 if nearest <= Assistant.IN_A_SOCKET else 0
			gaps.append("%.1f" % (nearest * Assistant.STUD))
		var upper: PartLibrary.PartInfo = library.parts.get(placement.part)
		var lower: PartLibrary.PartInfo = library.parts.get(under.part)
		print("%s | %s on %s | %s on %s | studs %d, in %d | LDU %s" % [file,
			placement.part, under.part,
			upper.family_category() if upper != null else "?",
			lower.family_category() if lower != null else "?",
			(seen[0] as PackedVector2Array).size(), landed, ",".join(gaps)])
	return counts


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
