extends SceneTree
## Every kind of 3D model file Brickify reads beside OBJ, STL and glTF, read
## through MeshFile as the file a person picks: PLY as text and as binary
## of both byte orders, 3MF, MagicaVoxel's VOX, FBX, and an OBJ picked with
## a picture and no .mtl. Each fixture (MeshFormatSamples, committed in
## tests/fixtures/brickify/formats/) comes in with the triangles, colours,
## places and turns it was made with, and is laid in LEGO. Then the files
## that should be refused: cut short, counts larger than the bytes, a zip
## that unpacks to more than it says or to gigabytes, objects that place
## each other in a loop or by the hundred million. Each is refused, saying
## why, in well under a second, and nothing is laid.
##
##   godot --headless --path . --script src/dev/mesh_formats_probe.gd [-- --fixtures] [-- --bench=DIR] [-- --real=DIR]
##
## --fixtures writes the fixtures again. --bench=DIR is a checkout's
## bench/data/brickify: the bench's PLY originals and Spot are read as they
## came, and measured and laid as their converted copies in DIR/prepared
## are, cell for cell and colour for colour. --real=DIR reads every 3MF
## and VOX in DIR (files fetched from public sources: docs/BRICKIFY.md says
## which) and lays each at 24 studs.

const FIXTURES := "res://tests/fixtures/brickify/formats/"

var _failures: int = 0
var _library: PartLibrary
var _checker: Assistant
var _world: BrickWorld
var _builder: Builder


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	var bench: String = ""
	var real: String = ""
	var fixtures: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--fixtures":
			fixtures = true
		elif arg.begins_with("--bench="):
			bench = arg.trim_prefix("--bench=")
		elif arg.begins_with("--real="):
			real = arg.trim_prefix("--real=")
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
	await process_frame

	var made: Dictionary = MeshFormatSamples.all()
	if fixtures:
		DirAccess.make_dir_recursive_absolute(FIXTURES)
		for name: String in made:
			var file := FileAccess.open(FIXTURES + name, FileAccess.WRITE)
			file.store_buffer(made[name])
			file.close()
		print("  wrote %d fixtures in %s" % [made.size(), FIXTURES])
	print("")
	print("  the fixtures are the samples")
	for name: String in made:
		var shipped: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURES + name)
		if name.get_extension() == "3mf":
			# A zip carries the time it was made: its members are compared.
			_check("%s holds what the samples write" % name, _members(shipped) == _members(made[name]))
		else:
			_check("%s is what the samples write (%d bytes)" % [name, shipped.size()],
				shipped == made[name])

	print("")
	print("  read")
	var bunny: MeshFile = BrickifySamples.bunny()
	_ply_text(bunny)
	_ply_binary(bunny)
	_ply_prism()
	_three_mf()
	_scene_vox()
	_plain_vox()
	_fbx(bunny)
	_picture()

	print("")
	print("  refused")
	_refused()

	print("")
	print("  laid in LEGO")
	for name: String in ["bunny.ply", "prism.ply", "shapes.3mf", "scene.vox", "bunny.fbx",
			"spotty.obj"]:
		var extras: Dictionary = {"spotty.png": made["spotty.png"]} if name == "spotty.obj" else {}
		var mesh: MeshFile = MeshFile.read(made[name], name, extras)
		if not mesh.error.is_empty():
			_check("%s: %s" % [name, mesh.error], false)
			continue
		var options := Brickify.Options.new()
		options.studs = 24
		options.up = mesh.up
		_laid(name, mesh, options)
	# A voxel a stud: the scene is 12 voxels along its longest side.
	var voxels: MeshFile = MeshFile.read(made["scene.vox"], "scene.vox")
	var one := Brickify.Options.new()
	one.studs = 12
	one.up = voxels.up
	var grid: Brickify.Grid = Brickify.voxelise(voxels, one, _library)
	_check(("at 12 studs, a voxel of scene.vox is a stud and 2.5 plates: %d x %d studs, %d plates "
		+ "tall, %d cells for its 82 voxels (%d plates each)") % [grid.across, grid.deep, grid.tall,
			grid.cells, roundi(grid.cells / 82.0)],
		grid.across == 12 and grid.deep == 4 and grid.tall == 20)

	if not bench.is_empty():
		print("")
		print("  the bench's own files, as they came")
		await _bench(bench)
	if not real.is_empty():
		print("")
		print("  real files")
		_real(real)

	print("")
	print("mesh formats probe: %s" % ("all ok" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures > 0 else 0)


## A zip's members, name -> bytes.
func _members(zip: PackedByteArray) -> Dictionary:
	var out: Dictionary = {}
	var entries: Dictionary = StudioIo._entries(zip)
	for name: Variant in entries:
		if entries[name] is Dictionary:
			out[name] = StudioIo._unpack(zip, entries[name])
	return out


func _read(name: String, extras: Dictionary = {}) -> MeshFile:
	var t0: int = Time.get_ticks_usec()
	var mesh: MeshFile = MeshFile.read(FileAccess.get_file_as_bytes(FIXTURES + name), name, extras)
	print("    %s read in %.1f ms: %d triangles, %s%s" % [name,
		(Time.get_ticks_usec() - t0) / 1000.0, mesh.triangle_count(),
		"coloured" if mesh.coloured else "no colour", (", " + mesh.error) if mesh.error else ""])
	return mesh


## The biggest gap between two lists of points, corner for corner.
func _apart(a: PackedVector3Array, b: PackedVector3Array) -> float:
	if a.size() != b.size():
		return INF
	var most: float = 0.0
	for n: int in a.size():
		most = maxf(most, a[n].distance_to(b[n]))
	return most


func _colour_gap(a: PackedColorArray, b: PackedColorArray) -> float:
	if a.size() != b.size():
		return INF
	var most: float = 0.0
	for n: int in a.size():
		most = maxf(most, maxf(absf(a[n].r - b[n].r), maxf(absf(a[n].g - b[n].g),
			absf(a[n].b - b[n].b))))
	return most


## Triangles by colour, to the nearest of [param named].
func _by_colour(mesh: MeshFile, named: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in named:
		out[key] = 0
	for t: int in mesh.triangle_count():
		var c: Color = mesh.colour_at(t, Vector3.ONE / 3.0)
		var best: Variant = null
		var gap: float = INF
		for key: Variant in named:
			var d: float = Vector3(c.r, c.g, c.b).distance_to(Vector3(named[key].r, named[key].g,
				named[key].b))
			if d < gap:
				gap = d
				best = key
		if gap < 0.05:
			out[best] = int(out[best]) + 1
	return out


## The volume a closed surface holds, positive when it is wound to face out.
func _volume(mesh: MeshFile, from: int = 0, to: int = -1) -> float:
	var sum: float = 0.0
	for t: int in range(from, mesh.triangle_count() if to < 0 else to):
		var a: Vector3 = mesh.positions[3 * t]
		sum += a.dot(mesh.positions[3 * t + 1].cross(mesh.positions[3 * t + 2])) / 6.0
	return sum


func _bounds_of(mesh: MeshFile, triangles: Array) -> AABB:
	var box := AABB(mesh.positions[3 * int(triangles[0])], Vector3.ZERO)
	for t: Variant in triangles:
		for corner: int in 3:
			box = box.expand(mesh.positions[3 * int(t) + corner])
	return box


func _ply_text(bunny: MeshFile) -> void:
	var mesh: MeshFile = _read("bunny.ply")
	_check(("text PLY, Windows line ends: the bunny's %d triangles, its corners within %.5f, "
		+ "its colours within %.4f of a byte's, Y up") % [mesh.triangle_count(),
			_apart(mesh.positions, bunny.positions), _colour_gap(mesh.colours, bunny.colours)],
		mesh.error.is_empty() and mesh.triangle_count() == bunny.triangle_count()
		and _apart(mesh.positions, bunny.positions) < 0.0001
		and _colour_gap(mesh.colours, bunny.colours) <= 0.5 / 255.0 + 0.0001
		and mesh.coloured and mesh.up == "+Y")


func _ply_binary(bunny: MeshFile) -> void:
	var mesh: MeshFile = _read("bunny_binary.ply")
	var normals: float = 0.0
	for n: int in mesh.normals.size():
		normals = maxf(normals, mesh.normals[n].distance_to(bunny.normals[n].normalized()))
	_check(("binary little-endian PLY: the bunny's corners exactly (%s), its normals as given "
		+ "(within %.6f), its colours as fractions (within %.6f)") % [
			mesh.positions == bunny.positions, normals, _colour_gap(mesh.colours, bunny.colours)],
		mesh.error.is_empty() and mesh.positions == bunny.positions and normals < 0.00001
		and _colour_gap(mesh.colours, bunny.colours) < 0.00001)


func _ply_prism() -> void:
	var mesh: MeshFile = _read("prism.ply")
	var colours: Dictionary = _by_colour(mesh, {"red": MeshFormatSamples.RED,
		"blue": MeshFormatSamples.BLUE})
	var box: AABB = mesh.bounds()
	var flat: bool = true
	for t: int in mesh.triangle_count():
		var face: Vector3 = (mesh.positions[3 * t + 1] - mesh.positions[3 * t]).cross(
			mesh.positions[3 * t + 2] - mesh.positions[3 * t]).normalized()
		for corner: int in 3:
			flat = flat and mesh.normals[3 * t + corner].dot(face) > 0.999
	_check(("binary big-endian PLY, a byte before each face's corners, an element after: two "
		+ "six-cornered ends and six four-cornered sides fanned into %d triangles, %s, "
		+ "%.1f x %.1f x %.1f, its sides' normals flat (%s), outward (volume %.1f)") % [
			mesh.triangle_count(), colours, box.size.x, box.size.y, box.size.z, flat,
			_volume(mesh)],
		mesh.error.is_empty() and mesh.triangle_count() == 20 and int(colours["red"]) == 8
		and int(colours["blue"]) == 12 and box.size.is_equal_approx(Vector3(6, 3 * sqrt(3.0), 4))
		and flat and _volume(mesh) > 0.0)


func _three_mf() -> void:
	var mesh: MeshFile = _read("shapes.3mf")
	var colours: Dictionary = _by_colour(mesh, {"red": MeshFormatSamples.RED,
		"blue": MeshFormatSamples.BLUE, "green": MeshFormatSamples.GREEN,
		"yellow": MeshFormatSamples.YELLOW})
	var box: AABB = mesh.bounds() if mesh.triangle_count() > 0 else AABB()
	# The two red cubes come first, from the first item's components.
	var cubes: float = _volume(mesh, 0, 24) if mesh.triangle_count() >= 24 else 0.0
	var textured: Array = []
	for t: int in mesh.triangle_count():
		if mesh.texture_of[t] >= 0:
			textured.append(t)
	var halves: Array = []
	for t: Variant in textured:
		halves.append(mesh.colour_at(int(t), Vector3.ONE / 3.0).to_html(false))
	_check(("3MF: %d triangles from its build, the support left out, Z up; by colour %s; "
		+ "%s to %s; its two cubes, one placed in a mirror, both outward (%.0f mm3 for 2000); "
		+ "its square on its picture's two halves: %s") % [mesh.triangle_count(), colours,
			box.position, box.end, cubes, halves],
		mesh.error.is_empty() and mesh.triangle_count() == 46 and mesh.up == "+Z"
		and int(colours["red"]) == 25 and int(colours["blue"]) == 13
		and int(colours["green"]) + int(colours["yellow"]) == 7
		and box.position.is_equal_approx(Vector3(-30, -20, 0))
		and box.end.is_equal_approx(Vector3(30, 40, 25)) and is_equal_approx(cubes, 2000.0)
		and halves.size() == 2 and halves[0] == MeshFormatSamples.RED.to_html(false)
		and halves[1] == MeshFormatSamples.BLUE.to_html(false))
	# The wedge's last triangle has a colour at each corner.
	var mixed: bool = false
	for t: int in mesh.triangle_count():
		if mesh.colours[3 * t].is_equal_approx(MeshFormatSamples.GREEN) \
				and mesh.colours[3 * t + 1].is_equal_approx(MeshFormatSamples.YELLOW):
			mixed = true
	_check("and a triangle coloured a corner at a time, green, yellow, green: %s" % mixed, mixed)


func _scene_vox() -> void:
	var mesh: MeshFile = _read("scene.vox")
	var colours: Dictionary = _by_colour(mesh, {"red": MeshFormatSamples.RED,
		"green": MeshFormatSamples.GREEN, "blue": MeshFormatSamples.BLUE})
	var box: AABB = mesh.bounds() if mesh.triangle_count() > 0 else AABB()
	var blue: Array = []
	for t: int in mesh.triangle_count():
		if mesh.colours[3 * t].is_equal_approx(MeshFormatSamples.BLUE):
			blue.append(t)
	var wall: AABB = _bounds_of(mesh, blue) if not blue.is_empty() else AABB()
	_check(("VOX: the outside of two models, %d triangles (150 faces), by colour %s, %s to %s, "
		+ "holding %.0f voxels; the hidden third left out; the wall turned to run along y: "
		+ "%s to %s") % [mesh.triangle_count(), colours, box.position, box.end, _volume(mesh),
			wall.position, wall.end],
		mesh.error.is_empty() and mesh.triangle_count() == 300 and mesh.up == "+Z"
		and int(colours["red"]) == 128 and int(colours["green"]) == 64
		and int(colours["blue"]) == 108 and box.position == Vector3(0, -2, -2)
		and box.end == Vector3(12, 2, 6) and is_equal_approx(_volume(mesh), 82.0)
		and wall.position == Vector3(0, -1, 0) and wall.end == Vector3(1, 2, 6))


func _plain_vox() -> void:
	var mesh: MeshFile = _read("plain.vox")
	var along: Array = []
	for x: int in 5:
		for t: int in mesh.triangle_count():
			var middle: Vector3 = (mesh.positions[3 * t] + mesh.positions[3 * t + 1]
				+ mesh.positions[3 * t + 2]) / 3.0
			if middle.x > x and middle.x < x + 1:
				along.append(mesh.colours[3 * t].to_html(false))
				break
	_check(("a VOX with no palette, in MagicaVoxel's own: %d triangles; voxels 1, 36, 216, 255 "
		+ "and 37 are %s") % [mesh.triangle_count(), along],
		mesh.error.is_empty() and mesh.triangle_count() == 44
		and along == ["ffffff", "ff0000", "ee0000", "111111", "ccffff"])


func _fbx(bunny: MeshFile) -> void:
	if not ClassDB.class_exists("FBXDocument"):
		_check("this engine has no FBX reader", false)
		return
	var mesh: MeshFile = _read("bunny.fbx")
	var count: int = bunny.triangle_count()
	if not mesh.error.is_empty() or mesh.triangle_count() != count + 12:
		_check("FBX: the bunny and a cube, %d triangles for %d: %s" % [mesh.triangle_count(),
			count + 12, mesh.error], false)
		return
	# Godot's FBX reader has a metre a unit and the file a centimetre.
	var scale: float = mesh.bounds().size.y / bunny.bounds().size.y
	# Each triangle found by its middle, in whatever order the reader gives
	# them and from whichever corner.
	var wanted: Dictionary = {}
	for t: int in count:
		wanted[_key(_middle(bunny, t) + Vector3(20, 0, 0))] = t
	var found: int = 0
	var gap: float = 0.0
	var cube: Array = []
	for t: int in mesh.triangle_count():
		var middle: Vector3 = _middle(mesh, t) / scale
		var match: int = _found(wanted, middle)
		if match >= 0:
			found += 1
			var c: Color = mesh.colour_at(t, Vector3.ONE / 3.0)
			var e: Color = bunny.colour_at(match, Vector3.ONE / 3.0)
			gap = maxf(gap, maxf(absf(c.r - e.r), maxf(absf(c.g - e.g), absf(c.b - e.b))))
		elif middle.x < -10.0:
			cube.append(t)
	var red: Color = mesh.colour_at(int(cube[0]), Vector3.ONE / 3.0) if not cube.is_empty() \
		else Color.BLACK
	var box: AABB = _bounds_of(mesh, cube) if not cube.is_empty() else AABB()
	_check(("FBX: all %d of the bunny's triangles where its moved node puts them (%d found, "
		+ "%.2f a unit), in its vertex colours (within %.4f); the cube's 12 (%d) in its "
		+ "material's red %s for %s, %s to %s") % [count, found, scale, gap, cube.size(),
			red.to_html(false), MeshFormatSamples.RED.to_html(false), box.position / scale,
			box.end / scale],
		found == count and is_equal_approx(scale, 0.01) and gap < 0.01 and cube.size() == 12
		and Vector3(red.r, red.g, red.b).distance_to(Vector3(MeshFormatSamples.RED.r,
			MeshFormatSamples.RED.g, MeshFormatSamples.RED.b)) < 0.01
		and (box.get_center() / scale).is_equal_approx(Vector3(-20, 3, 0)))


func _middle(mesh: MeshFile, t: int) -> Vector3:
	return (mesh.positions[3 * t] + mesh.positions[3 * t + 1] + mesh.positions[3 * t + 2]) / 3.0


func _key(p: Vector3) -> Vector3i:
	return Vector3i((p * 100.0).round())


## The triangle of [param wanted] (key -> index) whose middle is at [param
## p], looked for in the keys round it too: a middle a hair from the edge
## of a key rounds into the next.
func _found(wanted: Dictionary, p: Vector3) -> int:
	var at: Vector3i = _key(p)
	for x: int in [0, -1, 1]:
		for y: int in [0, -1, 1]:
			for z: int in [0, -1, 1]:
				if wanted.has(at + Vector3i(x, y, z)):
					return int(wanted[at + Vector3i(x, y, z)])
	return -1


func _bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		box = box.expand(p)
	return box


func _picture() -> void:
	var picture: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURES + "spotty.png")
	var bare: MeshFile = _read("spotty.obj")
	var with: MeshFile = _read("spotty.obj", {"spotty.png": picture})
	var colours: Dictionary = _by_colour(with, {"red": MeshFormatSamples.RED,
		"blue": MeshFormatSamples.BLUE})
	_check(("an OBJ picked alone comes in with no colour of its own (%s); picked with one "
		+ "picture and no .mtl, the picture is its texture: %s") % [bare.coloured, colours],
		bare.error.is_empty() and not bare.coloured and with.coloured
		and with.textures.size() == 1 and int(colours["red"]) == 6 and int(colours["blue"]) == 6)
	var two: MeshFile = MeshFile.read(FileAccess.get_file_as_bytes(FIXTURES + "spotty.obj"),
		"spotty.obj", {"spotty.png": picture, "other.png": picture})
	_check("with two pictures and nothing to say which, neither is guessed at: %s" % two.coloured,
		not two.coloured)
	# On the desktop, the one picture beside it is read with it.
	var dir: String = "user://mesh_formats_probe/"
	DirAccess.make_dir_recursive_absolute(dir)
	for name: String in ["spotty.obj", "spotty.png"]:
		var file := FileAccess.open(dir + name, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES + name))
		file.close()
	var beside: Dictionary = MeshFilePicker.read_path(ProjectSettings.globalize_path(dir
		+ "spotty.obj"))
	var file := FileAccess.open(dir + "other.png", FileAccess.WRITE)
	file.store_buffer(picture)
	file.close()
	var crowded: Dictionary = MeshFilePicker.read_path(ProjectSettings.globalize_path(dir
		+ "spotty.obj"))
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	DirAccess.remove_absolute(dir)
	_check(("the desktop reads the one picture beside it (%s), and none from a folder of "
		+ "two (%s)") % [(beside["extras"] as Dictionary).keys(),
			(crowded["extras"] as Dictionary).keys()],
		(beside["extras"] as Dictionary).keys() == ["spotty.png"]
		and (crowded["extras"] as Dictionary).is_empty())


## A file that should not be read, refused saying why in words, quickly.
func _refuse(what: String, bytes: PackedByteArray, name: String, says: String) -> void:
	var t0: int = Time.get_ticks_usec()
	var mesh: MeshFile = MeshFile.read(bytes, name)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_check("%s: \"%s\" in %.1f ms" % [what, mesh.error, ms],
		mesh.error.contains(says) and mesh.triangle_count() == 0 and ms < 1000.0)


func _refused() -> void:
	var binary: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURES + "bunny_binary.ply")
	_refuse("a binary PLY cut in half", binary.slice(0, binary.size() / 2), "cut.ply",
		"cut short")
	var header: String = "ply\nformat binary_little_endian 1.0\nelement vertex %d\n" \
		+ "property float x\nproperty float y\nproperty float z\nelement face %d\n" \
		+ "property list uchar int vertex_indices\nend_header\n"
	var tiny := PackedByteArray()
	tiny.resize(48)
	var liar: PackedByteArray = (header % [1000000, 1]).to_ascii_buffer()
	liar.append_array(tiny)
	_refuse("a PLY saying it has a million vertices in 48 bytes", liar, "liar.ply",
		"cut short")
	var huge: PackedByteArray = (header % [2000000000, 1]).to_ascii_buffer()
	huge.append_array(tiny)
	_refuse("a PLY saying it has two billion vertices", huge, "huge.ply", "at most")
	var many: PackedByteArray = (header % [3, 2000000]).to_ascii_buffer()
	many.append_array(tiny)
	_refuse("a PLY saying it has two million faces", many, "many.ply", "at most")
	var wide: PackedByteArray = (header % [3, 1]).to_ascii_buffer()
	var corners := PackedByteArray()
	corners.resize(36)
	corners.append(255)
	corners.append_array(PackedByteArray([0, 0, 0, 0]))
	wide.append_array(corners)
	_refuse("a PLY face saying it has 255 corners, with one", wide, "wide.ply", "cut short")
	var far: PackedByteArray = (header % [3, 1]).to_ascii_buffer()
	var face := PackedByteArray()
	face.resize(36 + 13)
	face[36] = 3
	face.encode_s32(37, 0)
	face.encode_s32(41, 1)
	face.encode_s32(45, 7)
	far.append_array(face)
	_refuse("a PLY face naming a vertex it does not have", far, "far.ply", "names vertex")
	_refuse("a PLY of points and no faces", ("ply\nformat ascii 1.0\nelement vertex 3\n"
		+ "property float x\nproperty float y\nproperty float z\nend_header\n0 0 0\n1 0 0\n"
		+ "0 1 0\n").to_ascii_buffer(), "cloud.ply", "no surfaces")
	_refuse("a PLY in a format there is none of", "ply\nformat binary_middle_endian 1.0\nend_header\n"
		.to_ascii_buffer(), "odd.ply", "neither text nor binary")
	_refuse("a file called .ply that is not one", "solid nothing".to_ascii_buffer(), "not.ply",
		"no header")

	_refuse("a file called .3mf that is not a zip", "not a zip at all".to_ascii_buffer(),
		"not.3mf", "not the zip")
	var shapes: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURES + "shapes.3mf")
	_refuse("a 3MF cut short", shapes.slice(0, shapes.size() - 40), "cut.3mf", "not the zip")
	_refuse("a 3MF whose model says it unpacks to 4 GB", _restated(shapes, "3d/3dmodel.model",
		0xFFFFFFF0), "huge.3mf", "more than")
	_refuse("a 3MF whose model unpacks to more than it says", _restated(shapes,
		"3d/3dmodel.model", 1000), "bomb.3mf", "does not unpack")
	var zeros := PackedByteArray()
	zeros.resize(64 * 1024 * 1024)
	var bomb: PackedByteArray = StudioIo.zip([["3D/3dmodel.model", zeros]])
	zeros = PackedByteArray()
	_refuse("a 3MF whose model is 64 MB of nothing, in %d bytes" % bomb.size(), bomb, "bomb.3mf",
		"no surfaces")
	_refuse("a 3MF whose objects place each other in a loop", _model_3mf(
		'<object id="1"><components><component objectid="2"/></components></object>'
		+ '<object id="2"><components><component objectid="1"/></components></object>',
		'<item objectid="1"/>'), "loop.3mf", "in a loop")
	var nested: String = '<object id="1"><mesh><vertices>%s</vertices><triangles>%s</triangles>' \
		% MeshFormatSamples._cube_xml("") + '</mesh></object>'
	for n: int in range(2, 10):
		nested += '<object id="%d"><components>' % n
		for _k: int in 10:
			nested += '<component objectid="%d"/>' % (n - 1)
		nested += '</components></object>'
	_refuse("a 3MF of a cube placed ten times, ten times over, eight deep (1.2 billion "
		+ "triangles)", _model_3mf(nested, '<item objectid="9"/>'), "deep.3mf", "more than can")
	_refuse("a 3MF triangle naming a corner it does not have", _model_3mf(
		'<object id="1"><mesh><vertices><vertex x="0" y="0" z="0"/></vertices><triangles>'
		+ '<triangle v1="0" v2="1" v3="2"/></triangles></mesh></object>', '<item objectid="1"/>'),
		"corner.3mf", "does not have")
	_refuse("a 3MF laying an object it has not got", _model_3mf("", '<item objectid="4"/>'),
		"none.3mf", "does not have")

	var scene: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURES + "scene.vox")
	_refuse("a VOX cut short", scene.slice(0, scene.size() / 2), "cut.vox", "cut short")
	_refuse("a file called .vox that is not one", "VOX!not one".to_ascii_buffer(), "not.vox",
		"not a MagicaVoxel")
	_refuse("a VOX whose voxels are more than its chunk", MeshFormatSamples._vox(150, [
		MeshFormatSamples._chunk("SIZE", MeshFormatSamples._words([2, 2, 2])),
		MeshFormatSamples._chunk("XYZI", MeshFormatSamples._words([1000000, 0]))]),
		"liar.vox", "cut short")
	_refuse("a VOX with a model no voxels across", MeshFormatSamples._vox(150, [
		MeshFormatSamples._chunk("SIZE", MeshFormatSamples._words([0, 2, 2]))]), "flat.vox",
		"not a size")
	var looped: PackedByteArray = MeshFormatSamples._words([0])
	looped.append_array(MeshFormatSamples._dict({}))
	looped.append_array(MeshFormatSamples._words([0, -1, -1, 1]))
	looped.append_array(MeshFormatSamples._dict({}))
	var one: Array = MeshFormatSamples._model(Vector3i(1, 1, 1), [[0, 0, 0, 1]])
	_refuse("a VOX whose scene holds itself", MeshFormatSamples._vox(200, one + [
		MeshFormatSamples._chunk("nTRN", looped)]), "loop.vox", "scene")
	_refuse("a VOX placing two voxels a million apart", _spread_vox(), "far.vox", "at most")

	_refuse("a file called .fbx that is not one", "Kaydara FBX Binary  nothing more"
		.to_ascii_buffer(), "not.fbx", "could not read")
	_refuse("a USDZ, which nothing here reads", "PK".to_ascii_buffer(), "model.usdz",
		"save it from your 3D program")
	# And the picker says the same before reading it.
	var picker := MeshFilePicker.new()
	var heard: Array = []
	picker.failed.connect(func(why: String) -> void: heard.append(why))
	picker.take("PK".to_ascii_buffer(), "model.usdz")
	picker.take("a note".to_ascii_buffer(), "notes.txt")
	picker.free()
	_check("the picker refuses them as MeshFile does: %s" % [heard],
		heard.size() == 2 and str(heard[0]).contains("is USD")
		and str(heard[1]).contains(MeshFile.NAMED))


## [param zip] with member [param member]'s size restated as [param size].
func _restated(zip: PackedByteArray, member: String, size: int) -> PackedByteArray:
	var out: PackedByteArray = zip.duplicate()
	var entries: Dictionary = StudioIo._entries(zip)
	var end: int = out.size() - 22
	var at: int = out.decode_u32(end + 16)
	for _n: int in out.decode_u16(end + 10):
		var name_length: int = out.decode_u16(at + 28)
		var name: String = out.slice(at + 46, at + 46 + name_length).get_string_from_utf8()
		if name.to_lower() == member:
			out.encode_u32(at + 24, size)
		at += 46 + name_length + out.decode_u16(at + 30) + out.decode_u16(at + 32)
	return out if entries.has(member) else PackedByteArray()


func _model_3mf(resources: String, build: String) -> PackedByteArray:
	return StudioIo.zip([["3D/3dmodel.model", (('<?xml version="1.0"?><model unit="millimeter" '
		+ 'xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02"><resources>%s'
		+ '</resources><build>%s</build></model>') % [resources, build]).to_utf8_buffer()]])


func _spread_vox() -> PackedByteArray:
	var chunks: Array = MeshFormatSamples._model(Vector3i(1, 1, 1), [[0, 0, 0, 1]])
	var node := func(id: int, rest: Array, frame: Dictionary) -> PackedByteArray:
		var content: PackedByteArray = MeshFormatSamples._words([id])
		content.append_array(MeshFormatSamples._dict({}))
		content.append_array(MeshFormatSamples._words(rest))
		if rest.size() == 4:
			content.append_array(MeshFormatSamples._dict(frame))
		return content
	chunks.append(MeshFormatSamples._chunk("nTRN", node.call(0, [1, -1, -1, 1], {})))
	var group: PackedByteArray = MeshFormatSamples._words([1])
	group.append_array(MeshFormatSamples._dict({}))
	group.append_array(MeshFormatSamples._words([2, 2, 4]))
	chunks.append(MeshFormatSamples._chunk("nGRP", group))
	chunks.append(MeshFormatSamples._chunk("nTRN", node.call(2, [3, -1, 0, 1], {"_t": "0 0 0"})))
	chunks.append(MeshFormatSamples._chunk("nTRN", node.call(4, [3, -1, 0, 1],
		{"_t": "1000000 1000 1000"})))
	var shape: PackedByteArray = MeshFormatSamples._words([3])
	shape.append_array(MeshFormatSamples._dict({}))
	shape.append_array(MeshFormatSamples._words([1, 0]))
	shape.append_array(MeshFormatSamples._dict({}))
	chunks.append(MeshFormatSamples._chunk("nSHP", shape))
	return MeshFormatSamples._vox(200, chunks)


## Laid as the panel lays it, checked as check_design checks a design.
func _laid(name: String, mesh: MeshFile, options: Brickify.Options) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var result: Dictionary = Brickify.build(mesh, options, _checker)
	var took: int = Time.get_ticks_msec() - t0
	if result.has("error"):
		_check("%s: %s" % [name, result["error"]], false)
		return {}
	var model: Assistant.Model = result["model"]
	var report: Dictionary = result["report"]
	var colours: Dictionary = {}
	for placement: Assistant.Placement in model.placements:
		colours[placement.color] = int(colours.get(placement.color, 0)) + 1
	var named: PackedStringArray = []
	for code: Variant in colours:
		named.append("%s %d" % [_library.color(int(code)).name, colours[code]])
	_check("%s at %d studs: %d parts, %s, %d piece%s, in %d ms; %s" % [name, options.studs,
		model.placements.size(), report["summary"], int(report["pieces"]),
		"" if int(report["pieces"]) == 1 else "s", took, ", ".join(named)],
		bool(report["ok"]) and int(report["pieces"]) == 1
		and (colours.size() > 1 or not mesh.coloured))
	result["colours"] = colours
	return result


func _bench(dir: String) -> void:
	var pairs: Array = [["stanford-bunny", "bun_zipper.ply", "bun_zipper.obj"],
		["armadillo", "Armadillo.ply", "Armadillo.obj"],
		["spot", "spot_triangulated.obj", "spot_triangulated.obj"]]
	for pair: Array in pairs:
		var original: String = dir.path_join("models").path_join(pair[0]).path_join(pair[1])
		var converted: String = dir.path_join("prepared").path_join(pair[0]).path_join(pair[2])
		if not FileAccess.file_exists(original) or not FileAccess.file_exists(converted):
			_check("%s and %s are there" % [original, converted], false)
			continue
		var t0: int = Time.get_ticks_msec()
		var read: Dictionary = MeshFilePicker.read_path(original)
		var as_came: MeshFile = MeshFile.read(read["bytes"], original.get_file(), read["extras"])
		var took: int = Time.get_ticks_msec() - t0
		var again: Dictionary = MeshFilePicker.read_path(converted)
		var as_made: MeshFile = MeshFile.read(again["bytes"], converted.get_file(), again["extras"])
		_check(("%s as it came (%s, %s): %d triangles in %d ms, %s; its converted copy %d, "
			+ "corners within %.6f") % [pair[0], original.get_file(),
				(read["extras"] as Dictionary).keys(), as_came.triangle_count(), took,
				"coloured" if as_came.coloured else "no colour", as_made.triangle_count(),
				_apart(as_came.positions, as_made.positions)],
			as_came.error.is_empty() and as_came.triangle_count() == as_made.triangle_count()
			and as_came.coloured == as_made.coloured
			and _apart(as_came.positions, as_made.positions) < 0.0001)
		for studs: int in [24, 48]:
			var options := Brickify.Options.new()
			options.studs = studs
			options.up = "+Y"
			var a: Brickify.Grid = Brickify.voxelise(as_came, options, _library)
			var b: Brickify.Grid = Brickify.voxelise(as_made, options, _library)
			var cells: int = 0
			var colours: int = 0
			for n: int in mini(a.state.size(), b.state.size()):
				if a.state[n] != b.state[n]:
					cells += 1
				elif a.colour.size() > n and b.colour.size() > n and a.colour[n] != b.colour[n]:
					colours += 1
			_check("  measured at %d studs: %d cells for %d, %d differ in what they are, %d in colour"
				% [studs, a.cells, b.cells, cells, colours],
				a.cells == b.cells and cells == 0 and colours == 0
				and a.state.size() == b.state.size())
		var options := Brickify.Options.new()
		options.studs = 24
		options.up = "+Y"
		var laid: Dictionary = _laid(pair[0] + " as it came", as_came, options)
		var made: Dictionary = _laid(pair[0] + " converted", as_made, options)
		if not laid.is_empty() and not made.is_empty():
			_check("  laid the same: %d parts for %d, colours %s for %s" % [
				(laid["model"] as Assistant.Model).placements.size(),
				(made["model"] as Assistant.Model).placements.size(), laid["colours"],
				made["colours"]],
				(laid["model"] as Assistant.Model).placements.size()
					== (made["model"] as Assistant.Model).placements.size()
				and laid["colours"] == made["colours"])
		await process_frame


func _real(dir: String) -> void:
	for name: String in DirAccess.get_files_at(dir):
		if not name.get_extension().to_lower() in ["3mf", "vox", "ply", "fbx"]:
			continue
		var t0: int = Time.get_ticks_msec()
		var mesh: MeshFile = MeshFile.read(FileAccess.get_file_as_bytes(dir.path_join(name)), name)
		var took: int = Time.get_ticks_msec() - t0
		var box: AABB = mesh.bounds()
		_check("%s: %d triangles in %d ms, %s, %s to %s, holding %.0f, %d pictures%s" % [name,
			mesh.triangle_count(), took, "coloured" if mesh.coloured else "no colour",
			box.position, box.end, _volume(mesh), mesh.textures.size(),
			(": " + mesh.error) if mesh.error else ""], mesh.error.is_empty())
		if mesh.error.is_empty():
			var options := Brickify.Options.new()
			options.studs = 24
			options.up = mesh.up
			_laid(name, mesh, options)
