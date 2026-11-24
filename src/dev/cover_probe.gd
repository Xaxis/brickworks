## A part's cover from its surface (PartForge._surface_cover), checked
## against the cover worked out cell by cell (PartForge._voxelise and on, as
## occupancy.py works out the library's own).
##
##   godot --headless --path . --script src/dev/cover_probe.gd
##       the same cells both ways on library parts, parts made here and
##       carried parts; which way each size of part goes; 42112-1's drum and
##       the library's own 65421 and 65421p01 as the catalogue covers them
##   ... -- --cover-size=WHAT     one part made here, timed, its memory said:
##       50, 200, 400 (a cube that many mm a side), plate400 (400 x 400 x
##       3.2 mm), ball400 (a ball 400 mm across, 9,000 triangles once read)
##   ... -- --cover-joins         a plate 400 mm square with studs put on it:
##       a 3001 on each stud, and the plate on a 3001's stud
##   ... -- --cover-sets=a.mpd,b.mpd   every part of the library those sets
##       place, built by the forge, against the catalogue's cover of it
extends SceneTree

const PROBE_DIR := "user://cover_probe_parts/"
const GOBLET := "res://tests/fixtures/own_parts/lego-goblet.stl"

var _library: PartLibrary
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run()


func _ok(good: bool, what: String) -> void:
	if good:
		_passed += 1
		print("  ok    " + what)
	else:
		_failed += 1
		print("  FAIL  " + what)


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("FAIL no catalogue")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cover-size="):
			_one_size(arg.trim_prefix("--cover-size="))
			_done()
			return
		if arg == "--cover-joins":
			await _joins()
			_done()
			return
		if arg.begins_with("--cover-sets="):
			_sets(arg.trim_prefix("--cover-sets=").split(",", false))
			_done()
			return
	_which_way()
	_same_cells()
	_drum()
	_big_cube()
	_done()


func _done() -> void:
	print("\nCOVER PROBE: %d passed, %d FAILED; peak %s" % [_passed, _failed, _peak()])
	quit(0 if _failed == 0 else 1)


## The process's own peak resident memory, as /proc says it.
static func _peak() -> String:
	var said: Array = []
	OS.execute("grep", ["VmHWM", "/proc/%d/status" % OS.get_process_id()], said)
	var line: String = str(said[0]) if not said.is_empty() else ""
	if not line.begins_with("VmHWM:"):
		return "?"
	return "%d MB" % (line.trim_prefix("VmHWM:").strip_edges().to_int() / 1024)


# -- which way a part goes ---------------------------------------------------------


func _which_way() -> void:
	print("\nwhich way: cell by cell up to the bound, from the surface past it")
	var baseplate: float = PartForge.box_cells(PackedFloat64Array([-480.0, -8.0, -480.0]),
		PackedFloat64Array([480.0, 0.0, 480.0]))
	_ok(baseplate <= PartForge.MADE_DENSE_MOST,
		"a 48 x 48 baseplate's box is %d cells: cell by cell, even made here" % int(baseplate))
	var hull: float = PartForge.box_cells(PackedFloat64Array([-239.0, -107.0, -241.0]),
		PackedFloat64Array([239.0, 0.0, 241.0]))
	_ok(hull > PartForge.MADE_DENSE_MOST and hull <= PartForge.DENSE_MOST,
		"6286-1's hull (478 x 482 x 107 LDU), %d cells: cell by cell when carried" % int(hull))
	_ok(PartForge.dense_most("0 x\n" + PartPrints.IMPORTED_BY + " file=a.stl\n")
			== PartForge.MADE_DENSE_MOST and PartForge.dense_most("0 x\n") == PartForge.DENSE_MOST,
		"a part made from a 3D file is bounded at %d cells, any other at %d" % [
			PartForge.MADE_DENSE_MOST, PartForge.DENSE_MOST])


# -- the same cells both ways ------------------------------------------------------


func _same_cells() -> void:
	print("\nthe same cells both ways (raw, studs taken out, holes bored)")
	for id: String in ["3001", "3626c", "32524", "3062b", "4589", "3700", "6536", "41539",
			"2780", "3040b", "3068b", "32278", "3941", "30374", "4865b", "3747b", "60474", "65421"]:
		var path: String = PartForge.library_path(PartForge.normalise(id + ".dat"))
		if path.is_empty() or not FileAccess.file_exists(path):
			print("  (no source for %s)" % id)
			continue
		_compare(id, FileAccess.get_file_as_string(path), id, {})
	# Parts made here: the goblet with a stud on top, one on its side, a pin
	# hole at a slant and a bar put on it.
	var goblet: MeshPart = MeshPart.read(FileAccess.get_file_as_bytes(GOBLET), "lego-goblet.stl")
	if goblet.unit_unsure:
		goblet.read_as("mm")
	var box: AABB = goblet.box()
	var size: Vector3 = box.size
	var middle: Vector3 = box.get_center()
	var put := PackedStringArray()
	# Each [what, the height it is aimed at (a share of the goblet's), from
	# where off that point]: on top, on the cup's side, at a slant, the stem.
	for aim: Array in [["stud", 1.0, Vector3(0, 50, 0)], ["stud", 0.8, Vector3(60, 8, 4)],
			["pin hole", 0.85, Vector3(10, 25, 60)], ["bar", 0.3, Vector3(60, 0, 0)]]:
		var target := Vector3(middle.x, box.position.y + size.y * float(aim[1]), middle.z)
		var from: Vector3 = target + (aim[2] as Vector3)
		var hit: Dictionary = goblet.pick(from, (target - from).normalized())
		var said: String = goblet.put(str(aim[0]), hit) if not hit.is_empty() else "missed"
		put.append("%s %s" % [aim[0], "put" if said.is_empty() else said])
	print("  the goblet: %s, put %s" % [size, ", ".join(put)])
	var id: String = goblet.id_for("Goblet")
	_compare("the goblet made here", goblet.text(id, "Goblet"), id, {})
	# A cube with a pin hole through it at a slant, as a file can state one.
	var cube: String = _cube_text("bw-probe-slant", 120.0).trim_suffix("0\n") \
		+ "0 %s CONNECTOR pin_hole neutral 10 -60 5 0.5 0.7 0.5\n0\n" % PartEditor.CONNECTOR
	_compare("a cube with a slanted pin hole", cube, "bw-probe-slant", {})
	# Carried by a real set: 42112-1's drum, and 6286-1's hull.
	for pair: Array in [["42112-1.mpd", "42112 - 65421p01"], ["6286-1.mpd", "6286 - u9499p01c01"]]:
		var carried: Array = _carried(str(pair[0]), str(pair[1]))
		if carried.is_empty():
			print("  (%s not carried by %s)" % [pair[1], pair[0]])
			continue
		_compare("%s's %s" % [pair[0], pair[1]], carried[0], str(pair[1]), carried[1])


## [text, others] of [param part] as [param set_name] carries it, or [].
func _carried(set_name: String, part: String) -> Array:
	var text: String = FileAccess.get_file_as_string("res://vendor/omr/files/" + set_name)
	if text.is_empty():
		return []
	var model: LdrModel = LdrModel.parse(text, set_name)
	var others: Dictionary = model.embedded_parts.duplicate()
	others.merge(model.embedded_sources)
	for name: String in model.embedded_parts:
		if name.get_basename().to_lower() == part.to_lower():
			return [model.embedded_parts[name], others]
	return []


## The cells of [param text] cell by cell and from its surface: raw, then
## with its studs taken out, then its holes' cells.
func _compare(what: String, text: String, id: String, others: Dictionary) -> void:
	var forge := PartForge.new()
	var key: String = PartForge.normalise(id + ".dat")
	for name: String in others:
		forge._given[PartForge.normalise(name)] = others[name]
	forge._given[key] = text
	forge._flatten(key)
	if forge._tri_color.is_empty():
		_ok(false, "%s: no faces (missing %s)" % [what, forge._missing])
		return
	var lo := PackedFloat64Array([INF, INF, INF])
	var hi := PackedFloat64Array([-INF, -INF, -INF])
	for v: int in forge._tri.size() / 3:
		var p := PackedFloat64Array([forge._tri[v * 3], -forge._tri[v * 3 + 1],
			-forge._tri[v * 3 + 2]])
		for n: int in 3:
			lo[n] = minf(lo[n], p[n])
			hi[n] = maxf(hi[n], p[n])
	var at: int = Time.get_ticks_msec()
	var raw: PartForge.Grid = forge._voxelise()
	var dense_ms: int = Time.get_ticks_msec() - at
	at = Time.get_ticks_msec()
	var surface: Array = forge._surface_runs(lo, hi)
	var surface_ms: int = Time.get_ticks_msec() - at
	var plan: PartForge.Columns = surface[0]
	var runs: Dictionary = surface[1]
	var differ: Array = _differences(raw, plan, runs)
	_ok(differ[0] == 0, "%s: raw cells %d cell by cell (%d ms), %d from the surface (%d ms), %d differ%s" % [
		what, raw.count(), dense_ms, _run_cells(runs), surface_ms, differ[0], differ[1]])
	var found: Array = forge._connectors(key)
	var studs: int = found.filter(func(c: Array) -> bool:
		return c[0] == "stud" and c[1] == "male").size()
	if studs > 0:
		var dense: PartForge.Grid = forge._remove_studs(raw, found)
		var gone: Dictionary = {}
		PartForge._studs_out(plan, found, gone)
		var kept: Dictionary = runs.duplicate(true)
		PartForge._cells_out(plan, kept, gone)
		var d2: Array = _differences(dense, plan, kept)
		_ok(d2[0] == 0, "%s: %d studs out: %d cells left cell by cell, %d from the surface, %d differ%s" % [
			what, studs, dense.count(), _run_cells(kept), d2[0], d2[1]])
	var holes: Array = PartForge._holes(found)
	if not holes.is_empty():
		var mask: PackedByteArray = PartForge._bore(raw, holes, false)
		var bored: Dictionary = {}
		PartForge._holes_out(plan, holes, bored)
		var missing: int = 0
		var count: int = 0
		var s: Vector3i = raw.shape
		var n: int = mask.find(1)
		while n >= 0:
			count += 1
			var x: int = n / (s.y * s.z) + raw.origin.x
			var y: int = (n / s.z) % s.y + raw.origin.y
			var z: int = n % s.z + raw.origin.z
			var column: int = (x - plan.ox) * plan.sz + (z - plan.oz)
			if not (bored.get(column, {}) as Dictionary).has(y):
				missing += 1
			n = mask.find(1, n + 1)
		var surface_count: int = 0
		for column: int in bored:
			surface_count += (bored[column] as Dictionary).size()
		_ok(missing == 0 and surface_count == count,
			"%s: %d holes bore %d cells cell by cell, %d from the surface, %d of those missed" % [
				what, holes.size(), count, surface_count, missing])


static func _run_cells(runs: Dictionary) -> int:
	var out: int = 0
	for column: int in runs:
		var one: PackedInt32Array = runs[column]
		for n: int in range(0, one.size(), 2):
			out += one[n + 1] - one[n]
	return out


## [how many cells are in one and not the other, the first few as words].
static func _differences(grid: PartForge.Grid, plan: PartForge.Columns, runs: Dictionary) -> Array:
	var seen: int = 0
	var only_grid: int = 0
	var said := PackedStringArray()
	var s: Vector3i = grid.shape
	var n: int = grid.bits.find(1)
	while n >= 0:
		var x: int = n / (s.y * s.z) + grid.origin.x
		var y: int = (n / s.z) % s.y + grid.origin.y
		var z: int = n % s.z + grid.origin.z
		var column: int = (x - plan.ox) * plan.sz + (z - plan.oz)
		var inside: bool = false
		var one: PackedInt32Array = runs.get(column, PackedInt32Array())
		for m: int in range(0, one.size(), 2):
			if one[m] <= y and y < one[m + 1]:
				inside = true
				break
		if inside:
			seen += 1
		else:
			only_grid += 1
			if said.size() < 4:
				said.append("cell %s only cell by cell" % Vector3i(x, y, z))
		n = grid.bits.find(1, n + 1)
	var only_runs: int = _run_cells(runs) - seen
	if only_runs > 0 and said.size() < 4:
		said.append("%d only from the surface" % only_runs)
	return [only_grid + only_runs, "" if said.is_empty() else " (" + "; ".join(said) + ")"]


# -- the drum, and the library's own ------------------------------------------------


func _drum() -> void:
	print("\n42112-1's drum, and the library's own 65421 and 65421p01")
	var model_text: String = FileAccess.get_file_as_string("res://vendor/omr/files/42112-1.mpd")
	var model: LdrModel = LdrModel.parse(model_text, "42112-1.mpd")
	var others: Dictionary = model.embedded_parts.duplicate()
	others.merge(model.embedded_sources)
	var catalogue: Dictionary = {}
	for entry: Variant in JSON.parse_string(FileAccess.get_file_as_string(
			"res://assets/generated/catalogue.json"))["parts"]:
		var one: Dictionary = entry
		if ["65421", "65421p01"].has(str(one["id"])):
			catalogue[str(one["id"])] = one
	for name: String in model.embedded_parts:
		var id: String = name.get_basename()
		# The drum whole (p01) and its plain copy (s00); s01 and the p01s
		# are halves and prints it is drawn from, not parts the catalogue has.
		if not ["42112 - 65421p01", "42112 - 65421s00"].has(id.to_lower()):
			continue
		var at: int = Time.get_ticks_msec()
		var built: PartForge.Result = PartForge.build(model.embedded_parts[name], id, others, true,
			null, false)
		var library_id: String = "65421p01" if id.ends_with("p01") else "65421"
		var want: Dictionary = catalogue.get(library_id, {})
		var cells: float = PartForge.box_cells(built.bounds_min, built.bounds_max)
		_ok(built.problem.is_empty() and built.boxes.size() == int(want.get("box_count", -1))
				and built.sockets.size() == int(want.get("socket_count", -1)),
			"42112-1's %s (%d cells: %s): %d boxes, %d sockets in %d ms; the catalogue's %s: %d, %d" % [
				id, int(cells), "cell by cell" if cells <= PartForge.DENSE_MOST else "from its surface",
				built.boxes.size(), built.sockets.size(), Time.get_ticks_msec() - at, library_id,
				int(want.get("box_count", -1)), int(want.get("socket_count", -1))])
	for id: String in ["65421", "65421p01"]:
		var path: String = PartForge.library_path(PartForge.normalise(id + ".dat"))
		var built: PartForge.Result = PartForge.build(FileAccess.get_file_as_string(path), id, {},
			true, null, false)
		var mesh: Lbm.PartMesh = _library.mesh_for(id)
		var theirs := PackedStringArray()
		if mesh != null:
			for box: AABB in mesh.boxes:
				theirs.append(str([roundi(box.position.x), roundi(box.position.y),
					roundi(box.position.z), roundi(box.size.x), roundi(box.size.y),
					roundi(box.size.z)]))
		var ours := PackedStringArray()
		for box: Array in built.boxes:
			ours.append(str(box))
		theirs.sort()
		ours.sort()
		_ok(built.problem.is_empty() and ours == theirs
				and built.sockets.size() == (mesh.sockets.size() if mesh != null else -1),
			"the library's %s forged: %d boxes, %d sockets; its catalogue cover %d boxes, %d sockets, the boxes %s" % [
				id, built.boxes.size(), built.sockets.size(), theirs.size(),
				mesh.sockets.size() if mesh != null else -1,
				"the same" if ours == theirs else "NOT the same"])


func _big_cube() -> void:
	print("\na part past the bound")
	var at: int = Time.get_ticks_msec()
	var built: PartForge.Result = PartForge.build(_cube_text("bw-probe-big", 1000.0), "bw-probe-big",
		{}, true, null, false)
	var took: int = Time.get_ticks_msec() - at
	_ok(built.problem.is_empty() and built.boxes.size() == 1
			and str(built.boxes[0]) == str([-250, 0, -250, 500, 500, 500]),
		"a cube 1000 LDU a side from its surface in %d ms: %d box %s, %d cells" % [took,
			built.boxes.size(), built.boxes[0] if not built.boxes.is_empty() else "none", built.cells])
	var far: PartForge.Result = PartForge.build(_cube_text("bw-probe-far", 70000.0), "bw-probe-far",
		{}, true, null, false)
	_ok(far.problem.contains("12 m"), "one 70,000 LDU across is refused: %s" % far.problem)


# -- one size made, timed ----------------------------------------------------------


func _one_size(what: String) -> void:
	print("SIZE %s: start peak %s" % [what, _peak()])
	var bytes: PackedByteArray
	match what:
		"plate400":
			bytes = _stl_binary(_box(Vector3(400, 400, 3.2)))
		"ball400":
			bytes = _stl_binary(_scaled(_sphere(50, 90), 20.0))
		_:
			var mm: float = what.to_float()
			bytes = _stl_binary(_box(Vector3(mm, mm, mm)))
	var at: int = Time.get_ticks_msec()
	var part: MeshPart = MeshPart.read(bytes, "size.stl")
	if part.unit_unsure:
		part.read_as("mm")
	var read_ms: int = Time.get_ticks_msec() - at
	var size: Vector3 = part.box().size
	var made: Dictionary = part.make(_library, "Size %s" % what, false)
	var took: int = Time.get_ticks_msec() - at
	var info: PartLibrary.PartInfo = _library.parts.get(str(made["id"]))
	var cells: float = PartForge.box_cells(PackedFloat64Array([-size.x / 2, -size.y, -size.z / 2]),
		PackedFloat64Array([size.x / 2, 0.0, size.z / 2]))
	_ok(str(made["problem"]).is_empty() and info != null,
		"SIZE %s: %s LDU, %d cells' box (%s), read in %d ms, made in %d ms; %d triangles, %d boxes; peak %s%s" % [
			what, size, int(cells), "from its surface" if cells > PartForge.MADE_DENSE_MOST
			else "cell by cell", read_ms, took, info.triangles if info != null else -1,
			info.box_count if info != null else -1, _peak(),
			"" if info != null else "; made %s, read %s" % [made, part.problem]])


# -- joins on a big plate ----------------------------------------------------------


func _joins() -> void:
	print("\na plate 400 mm square, studs put on it")
	for thick: float in [3.2, 8.0]:
		var plate: MeshPart = MeshPart.read(_stl_binary(_box(Vector3(400, 400, thick))), "bigplate.stl")
		if plate.unit_unsure:
			plate.read_as("mm")
		var size: Vector3 = plate.box().size
		var put := PackedStringArray()
		var spots: Array = [Vector2(10, 10), Vector2(-10, -10), Vector2(size.x / 2 - 10, size.z / 2 - 10),
			Vector2(30, -50)]
		for s: Vector2 in spots:
			var hit: Dictionary = plate.pick(Vector3(s.x, 100.0, s.y), Vector3.DOWN)
			put.append(plate.put("stud", hit) if not hit.is_empty() else "missed")
		var under: Dictionary = plate.pick(Vector3(10, -100.0, 10), Vector3.UP)
		put.append(plate.put("anti-stud", under) if not under.is_empty() else "missed")
		var at: int = Time.get_ticks_msec()
		var made: Dictionary = plate.make(_library, "Big Plate %s" % thick, false)
		var id: String = str(made["id"])
		var info: PartLibrary.PartInfo = _library.parts.get(id)
		if info == null:
			_ok(false, "plate %s mm thick not made: %s" % [thick, made])
			continue
		print("  plate 400 x 400 x %s mm: %s LDU, put %s, made in %d ms, %d boxes" % [thick, size,
			", ".join(put), Time.get_ticks_msec() - at, info.box_count])
		for s: Vector2 in spots:
			var r: Dictionary = await _pair(id, Transform3D.IDENTITY, "3001",
				Transform3D(Basis.IDENTITY, Vector3(s.x + 10, 24, s.y + 10)))
			_ok(r["one body"] and (r["joins"] as Array).has("studs") and int(r["lodged"]) == 0,
				"plate %s mm, a 3001 on the stud at %s: %s" % [thick, s, r])
		# The 3001 under the plate's bottom (size.y below its top), its stud
		# up in the anti-stud: 24 under a plate 20 LDU thick.
		var r3: Dictionary = await _pair("3001", Transform3D(Basis.IDENTITY,
			Vector3(0, -4.0 - size.y, 0)), id, Transform3D.IDENTITY)
		_ok(r3["one body"] and (r3["joins"] as Array).has("studs"),
			"plate %s mm on a 3001's stud, through its anti-stud: %s" % [thick, r3])


func _pair(one: String, one_at: Transform3D, two: String, two_at: Transform3D) -> Dictionary:
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	await process_frame
	var a: int = world.add_brick(one, 4, one_at)
	builder.register(a, one, one_at)
	var b: int = world.add_brick(two, 15, two_at)
	builder.register(b, two, two_at)
	var bodies: Bodies = Bodies.read(world, _library, builder.lattice)
	var joins: Array = []
	for join: Array in bodies.joined_by.get(b, []):
		joins.append(str(join[1]).get_slice(":", 0))
	var out: Dictionary = {"one body": bodies.body_of.get(a) == bodies.body_of.get(b), "joins": joins,
		"lodged": bodies.lodged}
	world.queue_free()
	builder.queue_free()
	await process_frame
	return out


# -- the library's parts of real sets ----------------------------------------------


func _sets(names: PackedStringArray) -> void:
	print("\nthe library's parts the sets place, forged, against the catalogue's covers")
	var wanted: Dictionary = {}
	for set_name: String in names:
		var model: LdrModel = LdrModel.parse(
			FileAccess.get_file_as_string("res://vendor/omr/files/" + set_name), set_name)
		if model == null:
			continue
		for placement: LdrModel.Placement in model.flatten(_library.parts):
			var info: PartLibrary.PartInfo = _library.parts.get(placement.part_id)
			if info != null and not info.custom:
				wanted[placement.part_id] = true
	var same: int = 0
	var differ: int = 0
	var unbuilt: int = 0
	var surface: int = 0
	var keys: Array = wanted.keys()
	keys.sort()
	for id: String in keys:
		var path: String = PartForge.library_path(PartForge.normalise(id + ".dat"))
		var mesh: Lbm.PartMesh = _library.mesh_for(id)
		if path.is_empty() or not FileAccess.file_exists(path) or mesh == null:
			unbuilt += 1
			continue
		var built: PartForge.Result = PartForge.build(FileAccess.get_file_as_string(path), id, {},
			true, null, false)
		if not built.problem.is_empty():
			unbuilt += 1
			continue
		if PartForge.box_cells(built.bounds_min, built.bounds_max) > PartForge.DENSE_MOST:
			surface += 1
		var theirs := PackedStringArray()
		for box: AABB in mesh.boxes:
			theirs.append(str([roundi(box.position.x), roundi(box.position.y), roundi(box.position.z),
				roundi(box.size.x), roundi(box.size.y), roundi(box.size.z)]))
		var ours := PackedStringArray()
		for box: Array in built.boxes:
			ours.append(str(box))
		theirs.sort()
		ours.sort()
		if ours == theirs and built.sockets.size() == mesh.sockets.size():
			same += 1
		else:
			differ += 1
			print("  SETS differ %s: forged %d boxes %d sockets, catalogue %d boxes %d sockets" % [id,
				built.boxes.size(), built.sockets.size(), theirs.size(), mesh.sockets.size()])
	print("SETS %d parts: %d the same as the catalogue's, %d differ, %d not built here, %d past the bound" % [
		keys.size(), same, differ, unbuilt, surface])
	_ok(surface == 0, "no library part of these sets is past the bound (%d)" % surface)


# -- files -------------------------------------------------------------------------


## A closed cube [param side] LDU a side as a part's text, its top at 0.
static func _cube_text(id: String, side: float) -> String:
	var h: float = side / 2.0
	var lines := PackedStringArray(["0 Probe cube", "0 Name: %s.dat" % id, "0 BFC CERTIFY CCW"])
	var c: Array[Vector3] = []
	for n: int in 8:
		c.append(Vector3(h if n & 1 else -h, -side if n & 2 else 0.0, h if n & 4 else -h))
	for q: Array in [[0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5], [0, 2, 3, 1],
			[4, 5, 7, 6]]:
		# Outward by the right hand in the app's axes, as LDraw winds them.
		for three: Array in [[q[0], q[2], q[1]], [q[0], q[3], q[2]]]:
			var words := PackedStringArray(["3", "16"])
			for k: int in three:
				words.append_array([str(c[k].x), str(c[k].y), str(c[k].z)])
			lines.append(" ".join(words))
	lines.append("0")
	return "\n".join(lines) + "\n"


static func _stl_binary(points: PackedVector3Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(84 + 50 * (points.size() / 3))
	out.encode_u32(80, points.size() / 3)
	for t: int in points.size() / 3:
		for k: int in 3:
			var p: Vector3 = points[t * 3 + k]
			var at: int = 84 + 50 * t + 12 + 12 * k
			out.encode_float(at, p.x)
			out.encode_float(at + 4, p.y)
			out.encode_float(at + 8, p.z)
	return out


static func _box(size: Vector3) -> PackedVector3Array:
	var h: Vector3 = size / 2.0
	var c: Array[Vector3] = []
	for n: int in 8:
		c.append(Vector3(h.x if n & 1 else -h.x, h.y if n & 2 else -h.y, h.z if n & 4 else -h.z))
	var quads: Array = [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2],
		[1, 3, 7, 5]]
	var out := PackedVector3Array()
	for q: Array in quads:
		out.append_array([c[q[0]], c[q[1]], c[q[2]], c[q[0]], c[q[2]], c[q[3]]])
	return out


static func _sphere(rings: int, around: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for r: int in rings:
		var t0: float = PI * r / rings
		var t1: float = PI * (r + 1) / rings
		for n: int in around:
			var p0: float = TAU * n / around
			var p1: float = TAU * (n + 1) / around
			var a := Vector3(sin(t0) * cos(p0), sin(t0) * sin(p0), cos(t0)) * 10.0
			var b := Vector3(sin(t1) * cos(p0), sin(t1) * sin(p0), cos(t1)) * 10.0
			var c := Vector3(sin(t1) * cos(p1), sin(t1) * sin(p1), cos(t1)) * 10.0
			var d := Vector3(sin(t0) * cos(p1), sin(t0) * sin(p1), cos(t0)) * 10.0
			out.append_array([a, c, b, a, d, c])
	return out


static func _scaled(points: PackedVector3Array, by: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Vector3 in points:
		out.append(p * by)
	return out
