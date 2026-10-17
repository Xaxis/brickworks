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
## Each build's stitch: [name, studs, rounds, stalls], for the stitch to be
## seen to end before its rounds run out.
var _stitched: Array = []
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
		# All of it: it met "no more parts" once only by its mend taking 45
		# parts out, which the stitch had left apart while its first ways laid
		# the same pair again and again. Whole, its hollow's ceiling joined,
		# it is a few parts more than the solid sphere.
		var taken: int = int((hollow["report"] as Dictionary).get("mended", 0))
		_check(("hollow is less plastic, nothing taken out, and hardly more parts: %.0f%% of the "
			+ "plastic in %d parts against %d, %d taken out, %d studs hollowed")
			% [100.0 * hollow_plastic / solid_plastic, hollow_parts, solid_parts, taken,
				(hollow["grid"] as Brickify.Grid).hollowed],
			hollow_plastic < solid_plastic * 0.75 and taken == 0
			and hollow_parts <= solid_parts * 1.1
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
	print("  colour that reads right")
	_colours_right(animal)

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

	print("")
	print("  bonded as a builder bonds")
	_bonded(round, plain, big)

	# The stitch ends because nothing more joins, not because its rounds ran
	# out: kept unchecked, its first ways laid the same pair again and again,
	# on most of the bench's models, until all 96 were spent and the rejoin
	# was never tried.
	var spent: Array = _stitched.filter(func(one: Array) -> bool: return int(one[2]) >= 96)
	_check("every stitch ends before its 96 rounds run out, of %d builds (%s); stalled and taken back %d times: %s"
		% [_stitched.size(), ", ".join(_stitched.map(func(one: Array) -> String:
			return "%s %d: %d" % [one[0], one[1], one[2]])),
		_stitched.reduce(func(sum: int, one: Array) -> int: return sum + int(one[3]), 0), spent],
		spent.is_empty() and not _stitched.is_empty())

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
	var ms: Dictionary = result.get("ms", {})
	_stitched.append([name, options.studs, int(ms.get("lay.stitch.rounds", 0)),
		int(ms.get("lay.stitch.stalls", 0))])
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


## Colour matched as an eye judges it, and every part in a colour it is made
## in: a dark grey went to Reddish Brown by Oklab's straight line, so Spot's
## black patches came out brown, and 1.7% of parts were in a colour no
## element of theirs comes in.
func _colours_right(animal: Dictionary) -> void:
	var sharma: float = Brickify.de2000(Vector3(50.0, 2.6772, -79.7751), Vector3(50.0, 0.0, -82.7485))
	_check("CIEDE2000 as Sharma, Wu and Dalal's test data has it: %.4f (2.0425)" % sharma,
		absf(sharma - 2.0425) < 0.0002)
	var lab: Array[Vector3] = []
	for code: int in Brickify.PALETTE:
		lab.append(HiddenColours.lab(_library.color(code).rgb))
	var names: PackedStringArray = []
	var chromatic: PackedStringArray = []
	for grey: int in [2, 4, 6, 8, 10, 12, 16, 20, 24, 28, 31]:
		var at: int = Brickify._nearest((grey << 10) | (grey << 5) | grey, lab, {}, [])
		var found: PartLibrary.BrickColor = _library.color(Brickify.PALETTE[at])
		names.append("%d: %s" % [roundi(grey * 255.0 / 31.0), found.name])
		if HiddenColours.chroma(found.rgb) >= 20.0:
			chromatic.append(found.name)
	_check("greys stay grey, from black to white: %s" % ", ".join(names), chromatic.is_empty()
		and names[3].ends_with("Black"))
	if animal.is_empty():
		return
	var model: Assistant.Model = animal["model"]
	var none: Dictionary = {}
	for placement: Assistant.Placement in model.placements:
		if _library.element_for(_library.resolve(placement.part), placement.color).is_empty():
			none["%s in %s" % [placement.part, _library.color(placement.color).name]] = true
	_check("every part of the bunny in its own colours has an element number (%d parts, %d recoloured): %s"
		% [model.placements.size(), int((animal["report"] as Dictionary).get("recoloured", 0)),
			none.keys()], none.is_empty())


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

	# Laid plain, its colours split its plates at their edges, and the stitch
	# paired the same plates again and again until its rounds ran out: 21
	# parts of its hind legs came out held by nothing and were taken out.
	var plain := Brickify.Options.new()
	plain.studs = 24
	plain.smooth = false
	var flat: Dictionary = Brickify.build(fox, plain, _checker)
	if flat.has("model"):
		_laid.append(flat["model"])
		var report: Dictionary = flat["report"]
		var gone: Array = report.get("left_out", [])
		var ms: Dictionary = flat["ms"]
		_check("laid plain, the whole of it too: %.1f%% in a part, %d mended, %s left out; its stitch %d rounds"
			% [100.0 * float(report.get("coverage", 0.0)), int(report.get("mended", 0)), gone,
				int(ms.get("lay.stitch.rounds", 0))],
			float(report.get("coverage", 0.0)) >= 0.97 and gone.is_empty())
	else:
		_check("the fox laid plain: %s" % str(flat.get("error", "")), false)
	_across_colours()

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


## Two plates side by side in two colours, a piece each: the stitch lays a
## plate across the edge, moving as few studs into the other colour as it
## can, and the rest of each side keeps its own. Joined only within a colour,
## a fox's legs and an aircraft's gear stood apart at their colour's edge and
## were taken out.
func _across_colours() -> void:
	var columns: Dictionary = {}
	for x: int in 6:
		columns[Vector2i(x, 0)] = PackedInt32Array([4 if x < 3 else 1])
	var plan := Shapes.Plan.new(columns, 1, false, _library)
	plan.made = [
		plan._annotated({"part": "3623", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
			Shapes.CORE_PLATES, 1, true),
		plan._annotated({"part": "3623", "color": 1, "x": 3, "y": 0, "z": 0, "rot": 0},
			Shapes.CORE_PLATES, 1, true)]
	var same: bool = plan._pair_across([0], {1: true})
	var joined: bool = plan._pair_across([0], {1: true}, {}, true)
	var studs: Dictionary = {}       ## colour -> studs
	var across: Array = []
	for one: Dictionary in plan.made:
		var cells: Array = one["_cells"]
		studs[int(one["color"])] = int(studs.get(int(one["color"]), 0)) + cells.size()
		var xs: Array = cells.map(func(cell: Vector2i) -> int: return cell.x)
		if xs.min() <= 2 and xs.max() >= 3:
			across.append("%s in %d" % [one["part"], one["color"]])
	_check(("two plates of two colours side by side are not paired as one colour (%s), and are "
		+ "across them: %d parts, %s reaching across, red %d studs and blue %d")
		% [same, plan.made.size(), across, int(studs.get(4, 0)), int(studs.get(1, 0))],
		not same and joined and across.size() == 1
		and int(studs.get(4, 0)) + int(studs.get(1, 0)) == 6
		and absi(int(studs.get(4, 0)) - int(studs.get(1, 0))) <= 2)


## Bonded as a builder bonds (unit 3): the hidden core in whole bricks
## whatever colour the measuring gave it, parts merged where two make one,
## and builds with few 1 x 1s, most seams bridged and few parts whose loss
## splits them, measured as the bench measures them (brickify_bench.py
## bond). Laid in the colours measured, a cow's core changed colour two
## studs in from every patch, and 37% of its 5,082 parts were 1 x 1s.
func _bonded(round: Dictionary, plain: Dictionary, big: Dictionary) -> void:
	# A block four studs square and six plates tall, white outside and red in
	# the middle where nothing of it shows: two courses of bricks, all white.
	var columns: Dictionary = {}
	for x: int in 4:
		for z: int in 4:
			var column := PackedInt32Array()
			for j: int in 6:
				var inner: bool = x in [1, 2] and z in [1, 2] and j in [1, 2, 3, 4]
				column.append(4 if inner else 15)
			columns[Vector2i(x, z)] = column
	var plan := Shapes.Plan.new(columns, 6, false, _library)
	plan.bridges = false
	plan.wedges = false
	plan.sides_smooth = false
	plan.bond = true
	plan.core_colour = 15
	plan.lay()
	var heights: Dictionary = {}
	var colours: Dictionary = {}
	for one: Dictionary in plan.made:
		heights[int(one["_h"])] = int(heights.get(int(one["_h"]), 0)) + 1
		colours[int(one["color"])] = true
	# Laid by the colours measured, as it was: the red middle in plates.
	var measured := Shapes.Plan.new(columns, 6, false, _library)
	measured.bridges = false
	measured.wedges = false
	measured.sides_smooth = false
	measured.lay()
	_check(("a block red only where nothing shows is two courses of white bricks: %d parts, by height %s, "
		+ "colours %s (by the colours measured, %d parts)") % [plan.made.size(), heights, colours.keys(),
			measured.made.size()],
		heights.keys() == [3] and plan.made.size() <= 4 and colours.keys() == [15]
		and measured.made.size() > plan.made.size())
	# Three 2 x 4 plates stacked are a brick, and two 1 x 2 plates side by side
	# over them a 2 x 2 plate.
	columns = {}
	for x: int in 4:
		for z: int in 2:
			columns[Vector2i(x, z)] = PackedInt32Array([15, 15, 15, 15])
	plan = Shapes.Plan.new(columns, 4, false, _library)
	plan.bond = true
	plan.core_colour = 15
	for y: int in 3:
		plan.made.append(plan._annotated({"part": "3020", "color": 15, "x": 0, "y": y, "z": 0, "rot": 0},
			Shapes.CORE_PLATES, 1, true))
	plan.made.append(plan._annotated({"part": "3023", "color": 15, "x": 0, "y": 3, "z": 0, "rot": 0},
		Shapes.CORE_PLATES, 1, true))
	plan.made.append(plan._annotated({"part": "3023", "color": 15, "x": 0, "y": 3, "z": 1, "rot": 0},
		Shapes.CORE_PLATES, 1, true))
	var saved: int = plan.merge()
	var parts: Array = plan.made.map(func(one: Dictionary) -> String: return "%s at %d" % [one["part"],
		int(one["y"])])
	_check("three plates of one footprint merge into a brick, two side by side into one plate: %s, %d saved"
		% [parts, saved], saved == 3 and parts.has("3001 at 0") and parts.has("3022 at 3"))
	# The forty-stud bunny is white with pink and black, and the measuring
	# colours two studs in from each patch: on main (a1d1998) its hidden core
	# was 203 bricks and 159 plates, three plates wherever two colours met
	# out of sight.
	if not big.is_empty():
		var hidden: Dictionary = _bond(big["model"])["hidden"]
		_check("the forty-stud bunny's hidden core is bricks, plates only at its edges: %d bricks, %d plates"
			% [int(hidden["brick"]), int(hidden["plate"])],
			int(hidden["plate"]) * 2 <= int(hidden["brick"]))
	# Each against main's (a1d1998, 2026-10-16): parts, the share of 1 x 1s,
	# of seams bridged and of weak points. Fewer parts and 1 x 1s; seams and
	# weak points within two points of main's.
	var main: Dictionary = {"the sphere": [1606, 0.352, 0.539, 0.309],
		"the plain sphere": [1266, 0.384, 0.668, 0.363],
		"the forty-stud bunny": [2062, 0.386, 0.497, 0.312]}
	for one: Array in [["the sphere", round], ["the plain sphere", plain], ["the forty-stud bunny", big]]:
		var laid: Dictionary = one[1]
		if laid.is_empty():
			continue
		var was: Array = main[one[0]]
		var bond: Dictionary = _bond(laid["model"])
		_check("%s: %d parts (main %d), %.1f%% of them 1 x 1 (%.1f%%), %.1f%% of %d seams bridged (%.1f%%), %.1f%% weak points (%.1f%%)"
			% [one[0], int(bond["parts"]), int(was[0]), 100.0 * float(bond["one"]), 100.0 * float(was[1]),
				100.0 * float(bond["seams"]), int(bond["pairs"]), 100.0 * float(was[2]),
				100.0 * float(bond["weak"]), 100.0 * float(was[3])],
			int(bond["parts"]) < int(was[0]) and float(bond["one"]) < float(was[1])
			and float(bond["seams"]) >= float(was[2]) - 0.02 and float(bond["weak"]) <= float(was[3]) + 0.02)


## A build's bond as brickify_bench.py measures it, from the parts' boxes on
## the stud and plate grid: the share of 1 x 1s; of the pairs of parts side
## by side in a plate's layer, the share a third part joins from above or
## below; and the share of parts whose removal splits the rest (articulation
## points of the graph of parts on parts). A stand's parts left out.
func _bond(model: Assistant.Model) -> Dictionary:
	var owner: Dictionary = {}    ## Vector3i(x, plate, z) -> index
	var ones: int = 0
	var count: int = model.placements.size()
	for n: int in count:
		var placement: Assistant.Placement = model.placements[n]
		var part: Lbm.PartMesh = _library.mesh_for(placement.part)
		if part == null:
			continue
		if roundi(part.bounds.size.x / 20.0) == 1 and roundi(part.bounds.size.z / 20.0) == 1:
			ones += 1
		var box: AABB = _checker._transform(placement, part) * part.bounds
		for j: int in range(floori(box.position.y / 8.0), ceili(box.end.y / 8.0)):
			var centre: float = (j + 0.5) * 8.0
			if centre < box.position.y or centre > box.end.y - 3.9:
				continue
			for x: int in range(roundi(box.position.x / 20.0), roundi(box.end.x / 20.0)):
				for z: int in range(roundi(box.position.z / 20.0), roundi(box.end.z / 20.0)):
					if not owner.has(Vector3i(x, j, z)):
						owner[Vector3i(x, j, z)] = n
	var vertical: Array = []
	for n: int in count:
		vertical.append({})
	for key: Variant in owner:
		var a: int = owner[key]
		var c: int = int(owner.get((key as Vector3i) + Vector3i(0, 1, 0), -1))
		if c >= 0 and c != a:
			(vertical[a] as Dictionary)[c] = true
			(vertical[c] as Dictionary)[a] = true
	var pairs: Dictionary = {}
	for key: Variant in owner:
		var a: int = owner[key]
		for step: Vector3i in [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
			var b: int = int(owner.get((key as Vector3i) + step, -1))
			if b >= 0 and b != a:
				pairs[Vector2i(mini(a, b), maxi(a, b))] = true
	var bridged: int = 0
	for key: Variant in pairs:
		var pair: Vector2i = key
		for c: Variant in vertical[pair.x]:
			if (vertical[pair.y] as Dictionary).has(c):
				bridged += 1
				break
	# Tarjan's articulation points, iteratively.
	var disc := PackedInt32Array()
	disc.resize(count)
	disc.fill(-1)
	var low := PackedInt32Array()
	low.resize(count)
	var weak: Dictionary = {}
	var timer: int = 0
	for start: int in count:
		if disc[start] >= 0 or (vertical[start] as Dictionary).is_empty():
			continue
		disc[start] = timer
		low[start] = timer
		timer += 1
		var children: int = 0
		var stack: Array = [[start, -1, (vertical[start] as Dictionary).keys(), 0]]
		while not stack.is_empty():
			var top: Array = stack[-1]
			var node: int = top[0]
			var near: Array = top[2]
			if int(top[3]) < near.size():
				var next: int = near[top[3]]
				top[3] = int(top[3]) + 1
				if disc[next] < 0:
					disc[next] = timer
					low[next] = timer
					timer += 1
					if node == start:
						children += 1
					stack.append([next, node, (vertical[next] as Dictionary).keys(), 0])
				elif next != int(top[1]):
					low[node] = mini(low[node], disc[next])
				continue
			stack.pop_back()
			var parent: int = top[1]
			if parent >= 0:
				low[parent] = mini(low[parent], low[node])
				if parent != start and low[node] >= disc[parent]:
					weak[parent] = true
		if children > 1:
			weak[start] = true
	# The plain bricks and plates none of which shows (every plate of them has
	# a part on all six sides).
	var plain: Dictionary = {}    ## part -> "brick" or "plate"
	for entry: Array in Shapes.CORE_BRICKS:
		plain[_library.resolve(str(entry[2]))] = "brick"
	for entry: Array in Shapes.CORE_PLATES:
		plain[_library.resolve(str(entry[2]))] = "plate"
	var cells_of: Dictionary = {}
	for key: Variant in owner:
		var n: int = owner[key]
		if plain.has(model.placements[n].part):
			if not cells_of.has(n):
				cells_of[n] = []
			(cells_of[n] as Array).append(key)
	var hidden: Dictionary = {"brick": 0, "plate": 0}
	for n: Variant in cells_of:
		var seen: bool = false
		for key: Variant in cells_of[n]:
			for step: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
					Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				seen = seen or not owner.has((key as Vector3i) + step)
		if not seen:
			var kind: String = plain[model.placements[int(n)].part]
			hidden[kind] = int(hidden[kind]) + 1
	return {"parts": count, "one": float(ones) / maxf(count, 1.0), "pairs": pairs.size(),
		"seams": float(bridged) / maxf(pairs.size(), 1.0), "weak": float(weak.size()) / maxf(count, 1.0),
		"hidden": hidden}


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
