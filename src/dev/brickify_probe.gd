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
## Every model the probe laid, for the numbers they were laid in.
var _laid: Array[Assistant.Model] = []
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
	for id: Variant in Patterns.WEDGES + Shapes.EDGE_PLATES + Shapes.EDGE_BRICKS:
		_sloped[str(id)] = true
	for id: Variant in Shapes.ROUND_PLATES + Shapes.ROUND_BRICKS:
		_curved[str(id)] = true
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
	print("  the whole model")
	_whole()

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

	# A model with nothing in it: the check's report then has no count of
	# pieces, and mending read it unguarded and stopped the script.
	var mended: Dictionary = Brickify.mend(Assistant.Model.new(), _checker)
	_check("mending a model with nothing in it comes back, not a crash (%d out)"
		% int(mended.get("mended", -1)), mended.has("mended"))

	# Every number laid is the one LDraw gives the part today: 3023 says
	# "~Moved to 3023b", and a parts list then has no element for it.
	var moved: Dictionary = {}
	var count: int = 0
	for model: Assistant.Model in _laid:
		for placement: Assistant.Placement in model.placements:
			count += 1
			if _library.resolve(placement.part) != placement.part:
				moved[placement.part] = _library.resolve(placement.part)
	_check("every number laid is current, of %d parts in %d builds: moved %s" % [count,
		_laid.size(), moved], moved.is_empty() and count > 0)
	var turned: Array = []
	for id: String in Brickify.parts_needed():
		if _library.resolve(id) != id and _library.moved_by(id) != Transform3D.IDENTITY:
			turned.append(id)
	_check("and none of the %d Brickify may lay is a number whose stub turns it: %s" % [
		Brickify.parts_needed().size(), turned], turned.is_empty())

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
	_laid.append(model)
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


## Keeping the whole model, generally: a fox whose legs are thinner than a
## stud (they never reached the grid, its body floated, and every part was
## mended away), a piece apart from the body (dropped, once), and a model
## that would tip (said to be buildable, unweighed).
func _whole() -> void:
	var fox: MeshFile = MeshFile.read(FileAccess.get_file_as_bytes(
		"res://tests/fixtures/brickify/fox.obj"), "fox.obj")
	_check("the fox: %d triangles, %s" % [fox.triangle_count(), fox.error],
		fox.error.is_empty() and fox.triangle_count() == 576)
	var options := Brickify.Options.new()
	options.studs = 24
	var laid: Dictionary = Brickify.build(fox, options, _checker)
	_check("the fox at 24 studs is laid: %s" % str(laid.get("error", "%d parts" % (
		(laid["model"] as Assistant.Model).placements.size() if laid.has("model") else 0))),
		laid.has("model"))
	if laid.has("model"):
		var model: Assistant.Model = laid["model"]
		_laid.append(model)
		var legs: Array = _legs(fox, laid)
		var kept: int = 0
		for leg: Dictionary in legs:
			kept += 1 if float(leg["held"]) >= 0.9 else 0
		_check("its legs survive, each from its foot up, in parts: %s" % ", ".join(PackedStringArray(
			legs.map(func(leg: Dictionary) -> String: return "%d%%" % roundi(100.0 * float(leg["held"]))))),
			legs.size() == 4 and kept == 4)
		var report: Dictionary = laid["report"]
		var gone: Array = report.get("left_out", [])
		_check("and the whole of it: %.1f%% of it in a part, %d piece%s left out %s" % [
			100.0 * float(report.get("coverage", 0.0)), gone.size(), "" if gone.size() == 1 else "s",
			gone], float(report.get("coverage", 0.0)) >= 0.97 and gone.is_empty())
		_stands("the fox", model, laid)

	var apart: MeshFile = BrickifySamples.floating()
	laid = Brickify.build(apart, options, _checker)
	_check("a body with a piece apart over it is laid: %s" % str(laid.get("error", "")),
		laid.has("model"))
	if laid.has("model"):
		var model: Assistant.Model = laid["model"]
		_laid.append(model)
		# The piece apart's middle, where Brickify put it: a part there.
		var middle: Vector3 = _in_build(apart, laid, Vector3(6.0, 8.7, 4.0))
		var there: String = _part_at(model, middle)
		_check("the piece apart is joined, not dropped: %s at its middle" % (there if not there.is_empty()
			else "nothing"), not there.is_empty())
		_stands("the body and its piece", model, laid)

	var tips: MeshFile = BrickifySamples.overhang()
	laid = Brickify.build(tips, options, _checker)
	if laid.has("model"):
		var model: Assistant.Model = laid["model"]
		_laid.append(model)
		var stand: Dictionary = (laid["report"] as Dictionary).get("stand", {})
		_check("a model that would tip is given a stand: %s" % str(stand.get("why", "none")),
			not stand.is_empty())
		_stands("on it, it", model, laid)
	else:
		_check("a model that would tip is laid: %s" % str(laid.get("error", "")), false)


## Weighed as the bench weighs it (check_design with Balance): one piece,
## passing, and standing.
func _stands(what: String, model: Assistant.Model, laid: Dictionary) -> void:
	var report: Dictionary = _checker._check(model, true, true)
	var balance: Balance.Report = report.get("balance")
	var pieces: int = int(report.get("pieces", 0))
	_check("%s: %s, %d piece%s; %s" % [what, report.get("summary", ""), pieces,
		"" if pieces == 1 else "s", balance.words() if balance != null else "unweighed"],
		bool(report.get("ok", false)) and pieces == 1 and balance != null and balance.stands())


## A point of the model ([param p], its own units) where Brickify put it:
## studs, plates and studs from the build's corner, lifted onto any stand.
func _in_build(mesh: MeshFile, laid: Dictionary, p: Vector3) -> Vector3:
	var grid: Brickify.Grid = laid["grid"]
	var box: AABB = Brickify._turned_bounds(mesh, Brickify.turn_for(mesh.up))
	var q: Vector3 = Brickify.turn_for(mesh.up) * p - box.position
	var lift: int = int(((laid["report"] as Dictionary).get("stand", {}) as Dictionary).get("lift", 0))
	return Vector3(q.x * grid.scale + (grid.across - box.size.x * grid.scale) / 2.0,
		q.y * grid.scale * Brickify.PLATES + lift,
		q.z * grid.scale + (grid.deep - box.size.z * grid.scale) / 2.0)


## The part whose box holds [param at] (studs, plates, studs), or "".
func _part_at(model: Assistant.Model, at: Vector3) -> String:
	var point := Vector3(at.x * 20.0, at.y * 8.0, at.z * 20.0)
	for placement: Assistant.Placement in model.placements:
		var part: Lbm.PartMesh = _library.mesh_for(placement.part)
		if part != null and (_checker._transform(placement, part) * part.bounds).grow(2.0).has_point(point):
			return placement.part
	return ""


## The model's legs, found from its own triangles: its corners within the
## lowest twentieth of it, gathered stud by stud into feet, each foot's leg
## as tall as its corners near it reach up to the belly. For each, how much
## of that leg, plate by plate from the foot, has a part in it.
func _legs(mesh: MeshFile, laid: Dictionary) -> Array:
	var box: AABB = Brickify._turned_bounds(mesh, Brickify.turn_for(mesh.up))
	var feet: Array = []             ## [centre Vector2 (studs), corners]
	var low: float = box.position.y + box.size.y * 0.05
	for p: Vector3 in mesh.positions:
		if p.y > low:
			continue
		var at: Vector3 = _in_build(mesh, laid, p)
		var plan := Vector2(at.x, at.z)
		var found: bool = false
		for foot: Array in feet:
			if (foot[0] as Vector2).distance_to(plan) < 2.0:
				foot[0] = ((foot[0] as Vector2) * float(foot[1]) + plan) / float(int(foot[1]) + 1)
				foot[1] = int(foot[1]) + 1
				found = true
				break
		if not found:
			feet.append([plan, 1])
	var model: Assistant.Model = laid["model"]
	var lift: int = int(((laid["report"] as Dictionary).get("stand", {}) as Dictionary).get("lift", 0))
	var out: Array = []
	for foot: Array in feet:
		var centre: Vector2 = foot[0]
		# Up the leg: the corners within a stud of it, below the middle of
		# the model.
		var top: float = 0.0
		for p: Vector3 in mesh.positions:
			var at: Vector3 = _in_build(mesh, laid, p)
			if Vector2(at.x, at.z).distance_to(centre) < 1.0 and p.y < box.get_center().y:
				top = maxf(top, at.y - lift)
		var plates: int = maxi(1, floori(top))
		var held: int = 0
		for j: int in plates:
			var hit: bool = false
			for dx: float in [-0.5, 0.0, 0.5]:
				for dz: float in [-0.5, 0.0, 0.5]:
					if not hit and not _part_at(model, Vector3(centre.x + dx, lift + j + 0.5,
							centre.y + dz)).is_empty():
						hit = true
			held += 1 if hit else 0
		out.append({"at": centre, "plates": plates, "held": float(held) / float(plates)})
	return out


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
