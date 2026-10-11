## Seat parts back on their studs in a model written before placements
## were named by their footprint.
##
##   godot --headless --path . --script src/dev/reseat.gd -- FILE... [--write]
##
## Until 2026-10-10 a placement's corner was its cover's, and a part drawn
## inside its footprint — a wing plate's cut edge, a turntable's round top,
## a flag's narrow clip, plant leaves — landed that much off the studs it
## stood on whenever it was placed at whole studs: 2 to 4 LDU. Models
## designed then carry it in their LDraw. This moves a part only where
## both are true: it is off the half-stud grid now, and the old corner's
## error, undone, puts its studs on stud middles. A part placed off the
## grid on purpose, or by somebody else's rules, is left where it is.
##
## Prints what it would move; with --write, rewrites each file and keeps
## the original beside it as FILE.bak.
extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var write: bool = args.has("--write")
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

	for path: String in args:
		if path.begins_with("--"):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty():
			print("%s: could not be read" % path)
			continue
		var lines: PackedStringArray = text.split("\n")
		var moved: Dictionary = {}
		for n: int in lines.size():
			var line: String = lines[n]
			var fields: PackedStringArray = LdrModel._fields(line.strip_edges())
			if fields.size() < 15 or fields[0] != "1":
				continue
			var part: String = library.resolve(fields[14].to_lower().trim_suffix(".dat"))
			var mesh: Lbm.PartMesh = library.mesh_for(part)
			if mesh == null:
				continue
			var numbers := PackedFloat64Array()
			for k: int in range(2, 14):
				numbers.append(fields[k].to_float())
			var at: Transform3D = LdrModel.to_transform(numbers)
			if not BrickLattice.is_square_to_grid(at.basis):
				continue
			var basis: Basis = BrickLattice.snap_basis(at.basis)
			if absf((basis * Vector3.UP).y) < 0.99:
				continue
			var cover := Vector3i(0x7FFFFFFF, 0, 0x7FFFFFFF)
			for cell: Vector3i in builder._cells_for(mesh, Transform3D(basis, Vector3.ZERO)):
				cover = Vector3i(mini(cover.x, cell.x), 0, mini(cover.z, cell.z))
			var footprint: Vector3i = assistant._corner_cell(mesh, part, basis)
			var shift := Vector3((cover.x - footprint.x) * BrickLattice.CELL, 0.0,
				(cover.z - footprint.z) * BrickLattice.CELL)
			if shift == Vector3.ZERO:
				continue
			if _off_the_studs(mesh, at) <= 0.5:
				continue
			if _off_the_studs(mesh, at.translated(shift)) > 0.5:
				continue
			# LDraw's z runs the other way to the app's; its x does not.
			fields[2] = _number(fields[2].to_float() + shift.x)
			fields[4] = _number(fields[4].to_float() - shift.z)
			var indent: String = line.substr(0, line.length() - line.lstrip(" \t").length())
			lines[n] = indent + " ".join(fields)
			moved[part] = int(moved.get(part, 0)) + 1
		var total: int = 0
		var said := PackedStringArray()
		for part: String in moved:
			total += int(moved[part])
			said.append("%d %s" % [moved[part], part])
		print("%s: %d to seat%s" % [path.get_file(), total,
			"" if said.is_empty() else " (" + ", ".join(said) + ")"])
		if write and total > 0:
			var keep := FileAccess.open(path + ".bak", FileAccess.WRITE)
			keep.store_string(text)
			keep.close()
			var out := FileAccess.open(path, FileAccess.WRITE)
			out.store_string("\n".join(lines))
			out.close()
			print("  written; the original is %s.bak" % path.get_file())
	quit(0)


## How far a part's upward studs stand from the middles of the grid's, in
## LDU, the worst of them; its tubes where it has no studs.
static func _off_the_studs(mesh: Lbm.PartMesh, at: Transform3D) -> float:
	for kind: String in ["stud", "tube"]:
		var worst: float = -1.0
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind != kind \
					or absf((at.basis * connector.axis).normalized().y) < 0.99:
				continue
			var where: Vector3 = at * connector.position
			for v: float in [where.x - 10.0, where.z - 10.0]:
				var r: float = fposmod(v, 20.0)
				worst = maxf(worst, minf(r, 20.0 - r))
		if worst >= 0.0:
			return worst
	return 0.0


static func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(snappedf(value, 0.001))
