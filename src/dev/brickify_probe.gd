extends SceneTree
## A 3D model brought in and laid in LEGO: a sphere from an STL, a cube
## with chamfered edges from a GLB, and a low-poly bunny from an OBJ with
## vertex colours, each read through MeshFile as the file a person would
## pick, brickified at a size and checked as check_design checks a design:
## buildable, in one piece. Then what makes it worth doing over a voxel
## stack: the sphere's top is curved and sloped, not stepped studs; the
## cube's chamfers are straight slopes; the bunny keeps its colours; hollow
## takes parts out and still holds; plain is plain; and forty studs is
## seconds, not minutes.
##
##   godot --headless --path . --script src/dev/brickify_probe.gd [-- OUTDIR] [-- --fixtures]
##
## With OUTDIR each is saved there as brickify_<name>.ldr, to be looked at.
## With --fixtures, tests/fixtures/brickify/bunny.obj is written again.

var _failures: int = 0
var _library: PartLibrary
var _checker: Assistant
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore

## Parts by what they do on a surface.
var _curved: Dictionary = {}
var _sloped: Dictionary = {}
var _tiles: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	var out_dir: String = ""
	var fixtures: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--fixtures":
			fixtures = true
		elif not arg.begins_with("--"):
			out_dir = arg
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	_checker = Assistant.new()
	_checker.library = _library
	_checker.world = _world
	_checker.builder = _builder
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	for entry: Array in Shapes.Plan.SLOPES:
		for id: Variant in [entry[3], entry[4]]:
			if entry[0] == "curved":
				_curved[str(id)] = true
			else:
				_sloped[str(id)] = true
	for entry: Array in Shapes.Plan.INVERTED:
		for id: Variant in [entry[3], entry[4]]:
			_sloped[str(id)] = true
	for id: Variant in Patterns.WEDGES + Shapes.BRICK_WEDGES:
		_sloped[str(id)] = true
	for entry: Array in Shapes.TOPS:
		_tiles[str(entry[2])] = true
	for id: Variant in Assistant.PANELS.values():
		_tiles[str(id)] = true
	var missing: Array = []
	for id: String in Brickify.parts_needed():
		if _library.mesh_for(id) == null:
			missing.append(id)
	_check("every part Brickify lays is here (%d): missing %s" % [
		Brickify.parts_needed().size(), missing], missing.is_empty())

	print("")
	print("  reading the files")
	var stl: PackedByteArray = BrickifySamples.to_stl(BrickifySamples.sphere())
	var sphere: MeshFile = MeshFile.read(stl, "sphere.stl")
	_check("a binary STL: %d triangles, Z up, no colour of its own: %s" % [
		sphere.triangle_count(), sphere.error], sphere.error.is_empty()
		and sphere.triangle_count() == BrickifySamples.sphere().triangle_count()
		and sphere.up == "+Z" and not sphere.coloured)
	var flat: PackedByteArray = Brickify._flat_faces(sphere)
	var flat_count: int = 0
	for one: int in flat:
		flat_count += one
	_check("its normals worked out smooth across a sphere: %d of %d faces flat" % [
		flat_count, flat.size()], flat_count < flat.size() / 10)
	var ascii := PackedStringArray(["solid sphere"])
	for t: int in sphere.triangle_count():
		ascii.append("facet normal 0 0 0\nouter loop")
		for corner: int in 3:
			var p: Vector3 = sphere.positions[3 * t + corner]
			ascii.append("vertex %f %f %f" % [p.x, p.y, p.z])
		ascii.append("endloop\nendfacet")
	ascii.append("endsolid sphere")
	var from_text: MeshFile = MeshFile.read("\n".join(ascii).to_utf8_buffer(), "sphere.stl")
	_check("a text STL: %d triangles" % from_text.triangle_count(),
		from_text.error.is_empty() and from_text.triangle_count() == sphere.triangle_count())

	var glb: PackedByteArray = BrickifySamples.to_glb(BrickifySamples.chamfered_cube())
	var cube: MeshFile = MeshFile.read(glb, "chamfered cube.glb")
	_check("a GLB: %d triangles in its material's colour %s: %s" % [cube.triangle_count(),
		cube.colours[0] if not cube.colours.is_empty() else "none", cube.error],
		cube.error.is_empty() and cube.triangle_count() == 44 and cube.coloured
		and cube.colours[0].r > 0.6 and cube.colours[0].g < 0.3)
	var cube_flat: PackedByteArray = Brickify._flat_faces(cube)
	var cube_flat_count: int = 0
	for one: int in cube_flat:
		cube_flat_count += one
	_check("its faces flat, as they were written: %d of %d" % [cube_flat_count,
		cube_flat.size()], cube_flat_count == cube_flat.size())
	# The same as a .gltf with its .bin beside it, as a person picks both.
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_buffer(glb, "", state)
	var dir: String = "user://brickify_probe/"
	DirAccess.make_dir_recursive_absolute(dir)
	doc.write_to_filesystem(state, dir + "cube.gltf")
	var extras: Dictionary = {}
	var gltf_bytes := PackedByteArray()
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gltf":
			gltf_bytes = FileAccess.get_file_as_bytes(dir + file)
		else:
			extras[file] = FileAccess.get_file_as_bytes(dir + file)
		DirAccess.remove_absolute(dir + file)
	DirAccess.remove_absolute(dir)
	var gltf: MeshFile = MeshFile.read(gltf_bytes, "cube.gltf", extras)
	_check("a .gltf with %s beside it: %d triangles: %s" % [extras.keys(), gltf.triangle_count(),
		gltf.error], gltf.error.is_empty() and gltf.triangle_count() == 44)
	_check("nothing left in user:// from reading it",
		not DirAccess.dir_exists_absolute("user://brickify_import/")
		and not DirAccess.dir_exists_absolute(dir))

	var obj: String = BrickifySamples.to_obj(BrickifySamples.bunny())
	if fixtures:
		DirAccess.make_dir_recursive_absolute("res://tests/fixtures/brickify")
		var file := FileAccess.open("res://tests/fixtures/brickify/bunny.obj", FileAccess.WRITE)
		file.store_string(obj)
		file.close()
		print("  wrote tests/fixtures/brickify/bunny.obj")
	var bunny: MeshFile = MeshFile.read(obj.to_utf8_buffer(), "bunny.obj")
	_check("an OBJ with vertex colours: %d triangles, coloured: %s" % [bunny.triangle_count(),
		bunny.error], bunny.error.is_empty() and bunny.coloured
		and bunny.triangle_count() == BrickifySamples.bunny().triangle_count())
	_check("the shipped bunny.obj is this bunny",
		FileAccess.get_file_as_string("res://tests/fixtures/brickify/bunny.obj") == obj)
	var bad: MeshFile = MeshFile.read("not a model".to_utf8_buffer(), "notes.txt")
	_check("a file that is not a model says so: \"%s\"" % bad.error, not bad.error.is_empty())

	print("")
	print("  brickified")
	var options := Brickify.Options.new()
	options.studs = 24
	options.up = sphere.up
	var round: Dictionary = await _brickify("sphere", sphere, options, out_dir)
	if not round.is_empty():
		var tops: Dictionary = _tops(round)
		var shaped: int = int(tops["curved"]) + int(tops["sloped"])
		_check("the sphere's top is curved and sloped, not stepped studs: %s" % tops,
			shaped >= 2 * int(tops["studs"]) and int(tops["curved"]) * 4 >= shaped)
		var parts: Dictionary = _kinds(round["model"])
		_check("and in parts, curved and sloped well above plain bricks showing studs: %s"
			% parts, int(parts["curved"]) + int(parts["sloped"]) >= 2 * int(parts["studs"]))

	options = Brickify.Options.new()
	options.studs = 24
	options.colours = "model"
	var flat_cube: Dictionary = await _brickify("chamfered cube", cube, options, out_dir)
	if not flat_cube.is_empty():
		var tops: Dictionary = _tops(flat_cube)
		_check("its chamfers in straight slopes, not curved ones: %s" % tops,
			int(tops["sloped"]) > 0 and int(tops["sloped"]) > 3 * int(tops["curved"]))
		var colours: Dictionary = _colours(flat_cube["model"])
		_check("in its material's red: %s" % colours, colours.keys() == [4])

	options = Brickify.Options.new()
	options.studs = 28
	var animal: Dictionary = await _brickify("bunny", bunny, options, out_dir)
	if not animal.is_empty():
		var colours: Dictionary = _colours(animal["model"])
		var names: Array = []
		for code: Variant in colours:
			names.append(_library.color(int(code)).name)
		_check("the bunny keeps its colours, white, pink and black: %s" % ", ".join(names),
			colours.has(15) and colours.has(0) and (colours.has(29) or colours.has(5)
				or colours.has(353)))
		var tops: Dictionary = _tops(animal)
		_check("its back curved and sloped: %s" % tops,
			int(tops["curved"]) + int(tops["sloped"]) >= int(tops["studs"]))

	print("")
	print("  the choices")
	options = Brickify.Options.new()
	options.studs = 24
	options.up = sphere.up
	options.hollow = true
	var hollow: Dictionary = await _brickify("hollow sphere", sphere, options, "")
	if not hollow.is_empty() and not round.is_empty():
		var solid_parts: int = (round["model"] as Assistant.Model).placements.size()
		var hollow_parts: int = (hollow["model"] as Assistant.Model).placements.size()
		var solid_plastic: float = _plastic(round["model"])
		var hollow_plastic: float = _plastic(hollow["model"])
		_check("hollow is less plastic and no more parts: %.0f%% of the plastic in %d parts against %d, %d studs hollowed"
			% [100.0 * hollow_plastic / solid_plastic, hollow_parts, solid_parts,
				(hollow["grid"] as Brickify.Grid).hollowed],
			hollow_plastic < solid_plastic * 0.75 and hollow_parts <= solid_parts
			and (hollow["grid"] as Brickify.Grid).hollowed > 0)
	# A dome scanned with no underside: the sphere's top half alone, open.
	var open := MeshFile.new()
	open.name = "open dome"
	open.up = "+Z"
	for t: int in sphere.triangle_count():
		if sphere.positions[3 * t].z >= -0.001 and sphere.positions[3 * t + 1].z >= -0.001 \
				and sphere.positions[3 * t + 2].z >= -0.001:
			for corner: int in 3:
				open.positions.append(sphere.positions[3 * t + corner])
				open.normals.append(sphere.normals[3 * t + corner])
				open.colours.append(Color.WHITE)
				open.uvs.append(Vector2.ZERO)
			open.texture_of.append(-1)
	options = Brickify.Options.new()
	options.studs = 24
	options.up = "+Z"
	var dome: Dictionary = await _brickify("open dome", open, options, "")
	if not dome.is_empty() and not round.is_empty():
		var cells: int = (dome["grid"] as Brickify.Grid).cells
		var whole: int = (round["grid"] as Brickify.Grid).cells
		_check("left open underneath, it is closed from the ground, a solid half: %d studs and plates against the sphere's %d"
			% [cells, whole], cells > whole * 0.4 and cells < whole * 0.6)

	options = Brickify.Options.new()
	options.studs = 24
	options.up = sphere.up
	options.smooth = false
	var plain: Dictionary = await _brickify("plain sphere", sphere, options, "")
	if not plain.is_empty():
		var parts: Dictionary = _kinds(plain["model"])
		_check("plain is plain bricks and plates: %s" % parts, int(parts["curved"]) == 0
			and int(parts["sloped"]) == 0 and int(parts["tiles"]) == 0)
	options = Brickify.Options.new()
	options.studs = 24
	options.colours = "limit"
	options.limit = 2
	var two: Dictionary = await _brickify("two-colour bunny", bunny, options, "")
	if not two.is_empty():
		var colours: Dictionary = _colours(two["model"])
		_check("cut to two colours: %s" % colours, colours.size() <= 2)
	options = Brickify.Options.new()
	options.studs = 20
	options.colours = "one"
	options.colour = 1
	var blue: Dictionary = await _brickify("blue bunny", bunny, options, "")
	if not blue.is_empty():
		var colours: Dictionary = _colours(blue["model"])
		_check("one colour is one colour: %s" % colours, colours.keys() == [1])

	print("")
	print("  forty studs")
	options = Brickify.Options.new()
	options.studs = 40
	var big: Dictionary = await _brickify("forty-stud bunny", bunny, options, out_dir)
	if not big.is_empty():
		var ms: Dictionary = big["ms"]
		var total: int = int(ms["measure"]) + int(ms["lay"]) + int(ms["check"])
		_check("in seconds: %.1f s (measured %d ms, laid %d ms, checked %d ms)" % [total / 1000.0,
			ms["measure"], ms["lay"], ms["check"]], total < 20000)

	_checker.free()
	print("")
	if _failures == 0:
		print("brickify: every model laid in one piece, buildable, its surface sloped and curved")
	else:
		print("brickify: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _brickify(name: String, mesh: MeshFile, options: Brickify.Options,
		out_dir: String) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var result: Dictionary = Brickify.build(mesh, options, _checker)
	var took: int = Time.get_ticks_msec() - t0
	if result.has("error"):
		_check("%s: %s" % [name, result["error"]], false)
		return {}
	var model: Assistant.Model = result["model"]
	var report: Dictionary = result["report"]
	var grid: Brickify.Grid = result["grid"]
	_check("%s at %d studs (%d x %d studs, %d plates): %d parts, %s, %d piece%s, %d mended, in %d ms"
		% [name, options.studs, grid.across, grid.deep, grid.tall, model.placements.size(),
			report["summary"], int(report["pieces"]), "" if int(report["pieces"]) == 1 else "s",
			int(report.get("mended", 0)), took],
		bool(report["ok"]) and int(report["pieces"]) == 1)
	_check("  all of it there: %.1f%% of its %d studs and plates in a part" % [
		100.0 * float(report["coverage"]), grid.cells], float(report["coverage"]) >= 0.97)
	if not bool(report["ok"]):
		print(str(report["feedback"]).left(1200))
	if not out_dir.is_empty():
		_checker._apply(model)
		for _n: int in 3:
			await process_frame
		var path: String = "%s/brickify_%s.ldr" % [out_dir, name.replace(" ", "_")]
		print("    saved %s: %s" % [path, _store.export_to(path, name)])
		_world.clear()
		_builder.lattice.clear()
		_checker.forget_built()
	return result


## For each stud of the model's plan, what its topmost part is: curved,
## sloped (straight, inverted or a wedge), a tile, or a plain part with its
## studs showing.
func _tops(result: Dictionary) -> Dictionary:
	var model: Assistant.Model = result["model"]
	var highest: Dictionary = {}     ## Vector2i -> [top, part]
	for placement: Assistant.Placement in model.placements:
		var part: Lbm.PartMesh = _library.mesh_for(placement.part)
		if part == null:
			continue
		var box: AABB = _checker._transform(placement, part) * part.bounds
		for x: int in range(roundi(box.position.x / 20.0), roundi(box.end.x / 20.0)):
			for z: int in range(roundi(box.position.z / 20.0), roundi(box.end.z / 20.0)):
				var key := Vector2i(x, z)
				if not highest.has(key) or box.end.y > float(highest[key][0]):
					highest[key] = [box.end.y, placement.part]
	var out: Dictionary = {"curved": 0, "sloped": 0, "tiles": 0, "studs": 0}
	for key: Variant in highest:
		var id: String = str(highest[key][1])
		var kind: String = "studs"
		if _curved.has(id):
			kind = "curved"
		elif _sloped.has(id):
			kind = "sloped"
		elif _tiles.has(id):
			kind = "tiles"
		out[kind] = int(out[kind]) + 1
	return out


## The parts by kind: curved, sloped, tiles, and plain parts whose studs
## nothing covers.
func _kinds(model: Assistant.Model) -> Dictionary:
	var out: Dictionary = {"curved": 0, "sloped": 0, "tiles": 0, "studs": 0, "inside": 0}
	var lattice := BrickLattice.new()
	var boxes: Array = []
	for index: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = _library.mesh_for(placement.part)
		var at: Transform3D = _checker._transform(placement, part)
		lattice.occupy_boxes(index + 1, _builder.boxes_for(part, at))
		boxes.append(at * part.bounds)
	for index: int in model.placements.size():
		var id: String = model.placements[index].part
		if _curved.has(id):
			out["curved"] = int(out["curved"]) + 1
		elif _sloped.has(id):
			out["sloped"] = int(out["sloped"]) + 1
		elif _tiles.has(id):
			out["tiles"] = int(out["tiles"]) + 1
		else:
			# Studs showing: a stud of it with nothing over it.
			var part: Lbm.PartMesh = _library.mesh_for(id)
			var at: Transform3D = _checker._transform(model.placements[index], part)
			var bare: bool = false
			for connector: Lbm.Connector in part.connectors:
				if connector.kind == "stud" and connector.gender == "male" \
						and (at.basis * connector.axis).normalized().dot(Vector3.UP) > 0.9:
					var tip: Vector3 = at * (connector.position + connector.axis.normalized() * 5.0)
					if lattice.brick_at(BrickLattice.to_cell(tip)) == 0:
						bare = true
						break
			out["studs" if bare else "inside"] = int(out["studs" if bare else "inside"]) + 1
	return out


## How much plastic, as the plates' worth of room the parts' boxes take.
func _plastic(model: Assistant.Model) -> float:
	var out: float = 0.0
	for placement: Assistant.Placement in model.placements:
		var b: AABB = _library.mesh_for(placement.part).bounds
		out += b.size.x * b.size.y * b.size.z / 3200.0
	return out


func _colours(model: Assistant.Model) -> Dictionary:
	var out: Dictionary = {}
	for placement: Assistant.Placement in model.placements:
		out[placement.color] = int(out.get(placement.color, 0)) + 1
	return out
