## A part of one's own from a 3D file (MeshPart): real files brought in or
## refused as said, sized and seated, connectors put where pointed, and the
## part kept, worn, saved, reopened and carried.
##
##   godot --headless --path . --script src/dev/mesh_part_probe.gd -- [--files=DIR] [--write=DIR]
##
## The files are real: three hair pieces and a goblet from Printables, CC0
## and CC-BY (tests/fixtures/own_parts/LICENCES.txt), and a hair piece
## whose surface is open. --files= is where the 3.4 MB ponytail is, which
## the repository does not carry (skipped, and said, without it). --write=
## keeps the saved model and each part file there, for tools that read
## LDraw (tools/own_parts_check.py).
##
## Made parts go to user://mesh_part_probe/, never the person's own.
extends SceneTree

const PROBE_DIR := "user://mesh_part_probe/"
const FIXTURES := "res://tests/fixtures/own_parts/"

var _failures: int = 0
var _library: PartLibrary
var _files: String = ""
var _write: String = ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--files="):
			_files = arg.trim_prefix("--files=")
		elif arg.begins_with("--write="):
			_write = arg.trim_prefix("--write=")
	_forget(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	if not _write.is_empty():
		DirAccess.make_dir_recursive_absolute(_write)

	print("\nrefused, in a sentence")
	_refused("hair-emka.stl", _bytes(FIXTURES + "hair-emka.stl"), "not a closed shape")
	_refused("lid-off.stl", _stl_binary(_box_without_top()), "not a closed shape")
	_refused("sheet.stl", _stl_binary(_flat_sheet()), "has no size")
	_refused("noise.stl", "not a mesh at all, only words".to_utf8_buffer(), "neither text nor binary")
	_refused("model.fbx", PackedByteArray([1, 2, 3]), "STL or OBJ")
	var ball: PackedVector3Array = _sphere(260, 260)
	_refused("too-fine.obj", _obj(ball), "at most 120,000")

	print("\nbrought in: binary STL, ASCII STL, OBJ")
	var goblet_bytes: PackedByteArray = _bytes(FIXTURES + "lego-goblet.stl")
	var goblet: MeshPart = MeshPart.read(goblet_bytes, "lego-goblet.stl")
	_ok(goblet.problem.is_empty() and goblet.triangles.size() / 3 == 6436,
		"the goblet, binary STL, closed, all %d triangles kept %s" % [goblet.triangles.size() / 3,
			goblet.problem])
	var soup: PackedVector3Array = _soup(goblet)
	var as_text: MeshPart = MeshPart.read(_stl_ascii(soup), "lego-goblet-ascii.stl")
	_ok(as_text.problem.is_empty() and as_text.triangles.size() == goblet.triangles.size()
			and as_text.box().size.is_equal_approx(goblet.box().size),
		"the same goblet written as ASCII STL reads the same: %s" % as_text.size_words())
	var as_obj: MeshPart = MeshPart.read(_obj(_in_file_axes(soup)), "lego-goblet.obj")
	_ok(as_obj.problem.is_empty() and as_obj.triangles.size() == goblet.triangles.size()
			and as_obj.box().size.is_equal_approx(goblet.box().size),
		"and as OBJ (Y up): %s" % as_obj.size_words())
	var wig_bytes: PackedByteArray = _bytes(FIXTURES + "wig_67.stl")
	var started: int = Time.get_ticks_msec()
	var wig_obj: MeshPart = MeshPart.read(_obj(_stl_corners(wig_bytes)), "wig_67.obj")
	var simplify_ms: int = Time.get_ticks_msec() - started
	_ok(wig_obj.problem.is_empty() and wig_obj.triangles.size() / 3 <= MeshPart.MOST_TRIANGLES
			and wig_obj.file_triangles == 12244 and wig_obj.moved_by > 0.0,
		"an OBJ over the limit, 12,244 triangles, simplified in %d ms: %s" % [simplify_ms,
			wig_obj.note if wig_obj.problem.is_empty() else wig_obj.problem])
	_closed(wig_obj, "the simplified wig")
	if wig_obj.problem.is_empty():
		var longest: float = wig_obj.longest("LDU") / wig_obj._k()
		_ok(wig_obj.moved_by <= MeshPart.holds_within(longest),
			"its surface within %.3f mm of the file's everywhere (allowed %.3f)" % [wig_obj.moved_by,
				MeshPart.holds_within(longest)])

	print("\nsized and placed")
	var size: Vector3 = goblet.box().size
	_ok(absf(size.x - 8.026 * 2.5) < 0.2 and absf(size.z - 8.015 * 2.5) < 0.2
			and absf(size.y - 44.0) < 0.01,
		"read as millimetres, upright (Z up in the file), its height a whole number of lattice steps: %s"
			% goblet.size_words())
	var placed_box: AABB = goblet.box()
	_ok(absf(placed_box.end.y) < 0.001 and absf(placed_box.get_center().x) < 0.001
			and absf(placed_box.get_center().z) < 0.001,
		"centred, its top at the part's origin as a brick's is")
	goblet.set_longest(2.0, "studs")
	_ok(absf(goblet.longest("LDU") - 40.0) < 0.01, "two studs tall: %s" % goblet.size_words())
	goblet.set_longest(17.5, "mm")
	goblet.quarter_turn(Vector3.RIGHT)
	_ok(goblet.box().size.z > goblet.box().size.y * 1.8, "a quarter turn lays it down: %s"
		% goblet.size_words())
	goblet.quarter_turn(Vector3.RIGHT)
	goblet.quarter_turn(Vector3.RIGHT)
	goblet.quarter_turn(Vector3.RIGHT)
	var back: Vector3 = goblet.box().size
	_ok(absf(back.x - size.x) < 0.3 and absf(back.y - size.y) < 0.3 and absf(back.z - size.z) < 0.3,
		"four turns stand it back up: %s" % goblet.size_words())

	print("\nconnectors, one click each")
	var block: MeshPart = MeshPart.read(_stl_binary(_box(Vector3(16, 8, 9.6))), "block.stl")
	_ok(block.problem.is_empty(), "a block 16 x 8 x 9.6 mm: %s" % block.size_words())
	_put(block, "stud", Vector3(5.3, 100, 3.1), Vector3.DOWN)
	_put(block, "anti-stud", Vector3(-9.1, -100, 0.7), Vector3.UP)
	_put(block, "pin hole", Vector3(-100, -12, 0), Vector3.RIGHT)
	_put(block, "bar hole", Vector3(100, -12, 0), Vector3.LEFT)
	_put(block, "bar", Vector3(0, -12, 100), Vector3.FORWARD)
	var made_block: Dictionary = block.placed()
	var stud: Array = made_block["studs"][0] if not (made_block["studs"] as Array).is_empty() else []
	_ok(not stud.is_empty() and stud[0] == Vector3(6, 0, -4) and stud[1] == Vector3(0, -1, 0),
		"the stud on the top, on the lattice (6, 0, -4 in LDraw), facing up: %s" % [stud])
	var block_made: Dictionary = block.make(_library, "Probe Block")
	_ok(str(block_made["problem"]).is_empty(), "made: %s" % block_made)
	var block_id: String = block_made["id"]
	var kinds: Dictionary = {}
	if _library.mesh_for(block_id) != null:
		for c: Lbm.Connector in _library.mesh_for(block_id).connectors:
			var key: String = c.kind + ("%d" % roundi(c.radius) if c.radius > 0.0 else "")
			kinds[key] = int(kinds.get(key, 0)) + 1
	_ok(kinds.get("stud", 0) == 1 and kinds.get("tube", 0) == 1 and kinds.get("pin_hole", 0) == 1
			and kinds.get("bore4", 0) == 1 and kinds.get("shaft4", 0) == 1,
		"built, it has a stud, an anti-stud, a pin hole, a bar hole and a bar: %s" % kinds)
	_save_text(block_id)

	# The goblet's stem is its bar, along it, through its middle.
	goblet.guess_fit()
	var stem: Dictionary = goblet.pick(Vector3(100, -30, 0), Vector3.LEFT)
	_ok(not stem.is_empty() and goblet.put("bar", stem).is_empty(), "a bar put on the goblet's stem")
	var bars: Array = goblet.placed()["connectors"]
	var bar: Array = bars[0] if not bars.is_empty() else []
	_ok(not bar.is_empty() and bar[0] == "shaft" and absf(float(bar[6])) > 0.99
			and float(bar[8]) > 6.0 and absf(float(bar[2])) < 0.6 and absf(float(bar[4])) < 0.6,
		"it runs up the stem through its middle, %s LDU, a 4 LDU round: %s" % [
			bar[8] if not bar.is_empty() else "", bar])
	var goblet_made: Dictionary = goblet.make(_library, "Probe Goblet")
	_ok(str(goblet_made["problem"]).is_empty(), "the goblet made: %s" % goblet_made)
	_save_text(str(goblet_made["id"]))

	print("\nhair, three real pieces")
	var hairs: Array = [["wig_67.stl", FIXTURES + "wig_67.stl"],
		["mohawk.stl", FIXTURES + "mohawk.stl"]]
	var ponytail: String = _files.path_join("hair-ponytail/w-fit-trainer-hair.stl")
	if not _files.is_empty() and FileAccess.file_exists(ponytail):
		hairs.append(["w-fit-trainer-hair.stl", ponytail])
	else:
		print("  --    the ponytail (68,416 triangles) is not here: pass --files=")
	var worn: Array[String] = []
	for entry: Array in hairs:
		var at: int = Time.get_ticks_msec()
		var piece: MeshPart = MeshPart.read(_bytes(entry[1]), entry[0])
		var read_ms: int = Time.get_ticks_msec() - at
		if not piece.problem.is_empty():
			_ok(false, "%s: %s" % [entry[0], piece.problem])
			continue
		at = Time.get_ticks_msec()
		piece.make_hair()
		var seat_ms: int = Time.get_ticks_msec() - at
		var hair_box: AABB = piece.box()
		# A mohawk's crest is narrow across and long front to back.
		var widest: float = maxf(hair_box.size.x, hair_box.size.z)
		_ok(piece.head_inside <= 0.08 and widest > 22.0 and widest < 60.0,
			"%s: read in %d ms%s, seated in %d ms, stood with the file's %s up and its %s forward, %s, the head %d%% inside it"
				% [entry[0], read_ms, (" (" + piece.note + ")") if not piece.note.is_empty() else "",
				seat_ms, piece.turn.inverse() * Vector3.UP, piece.turn.inverse() * Vector3.BACK,
				piece.size_words(), roundi(piece.head_inside * 100.0)])
		var made: Dictionary = piece.make(_library, piece.name)
		var id: String = made["id"]
		_ok(str(made["problem"]).is_empty() and PartPrints.base_in(_library.custom_source(id)) == "3901"
				and Minifig.slot_for(_library.parts.get(id)) == "headwear",
			"made %s, worn as 3901, offered as headgear (%s)" % [id,
				_library.parts[id].name if _library.parts.has(id) else made["problem"]])
		var socket: bool = false
		if _library.mesh_for(id) != null:
			for c: Lbm.Connector in _library.mesh_for(id).connectors:
				socket = socket or (c.kind == "tube" and c.position.is_equal_approx(Vector3(0, 4, 0)))
		_ok(socket, "its socket is 3901's, where the head's stud goes in")
		worn.append(id)
		_save_text(id)

	print("\non a figure, in a model, reopened")
	for id: String in worn:
		await _wear(id)
	_finish()


## A figure wearing [param id] placed on a plate: where 3901 would be, the
## head's stud in it so it turns with the head, saved, reopened on a library
## that never saw it, and still there.
func _wear(id: String) -> void:
	var plain := Minifig.new()
	var own := Minifig.new()
	own.parts["headwear"] = id
	var a: Array[Dictionary] = plain.assemble(_library)
	var b: Array[Dictionary] = own.assemble(_library)
	var hat_a: Transform3D = Transform3D.IDENTITY
	var hat_b: Transform3D = Transform3D.IDENTITY
	for item: Dictionary in a:
		if item["slot"] == "headwear":
			hat_a = item["at"]
	for item: Dictionary in b:
		if item["slot"] == "headwear" and item["part"] == id:
			hat_b = item["at"]
	_ok(hat_a.is_equal_approx(hat_b) and hat_a != Transform3D.IDENTITY,
		"%s sits where 3901 sits on the head" % id)
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	await process_frame
	var plate := Transform3D(Basis.IDENTITY, Vector3(40, 8, 10))
	builder.register(world.add_brick("3023", 15, plate), "3023", plate)
	builder.hold_figure(b, "Probe")
	builder.update_preview(Vector3(40, 400, 10), Vector3.DOWN)
	var first: int = builder.place()
	var figure: PackedInt64Array = builder.figure_of(first) if first != 0 else PackedInt64Array()
	_ok(figure.size() == b.size(), "placed on a plate like any figure (%d parts)" % figure.size())
	var head_id: int = 0
	var hair_id: int = 0
	for brick_id: int in figure:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick.part_id == id:
			hair_id = brick_id
		elif brick.part_id.begins_with("3626"):
			head_id = brick_id
	var bodies: Bodies = Bodies.read(world, _library, builder.lattice)
	var moves: PackedInt64Array = bodies.parts_of(bodies.beyond(int(bodies.body_of.get(head_id, -1))))
	# Held by the head's stud as 3901 is, not lodged in whatever it overlaps
	# most: a ponytail was lodged in the torso and stayed when the head
	# turned.
	var joins: Array = bodies.joined_by.get(hair_id, [])
	var by_stud: bool = false
	for join: Array in joins:
		by_stud = by_stud or (int(join[0]) == head_id and str(join[1]).begins_with("studs"))
	_ok(head_id != 0 and hair_id != 0 and moves.has(hair_id) and by_stud,
		"the head's stud is in it, as in 3901: turning the head turns it (%s)" % [joins])
	# Saved and opened elsewhere.
	var placements: Array = []
	var used: Array = []
	for brick_id: int in figure:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		placements.append(LdrModel.Placement.new(brick.part_id, brick.color_code, brick.transform, 0))
		used.append(brick.part_id)
	var file: String = LdrModel.write_ldr(placements, "Probe", "Brickworks", {},
		CustomParts.sources_for(_library, used))
	_ok(file.contains("0 FILE %s.dat" % id), "the saved model carries it as 0 FILE %s.dat" % id)
	if not _write.is_empty():
		var out: FileAccess = FileAccess.open(_write.path_join("figure-%s.mpd" % id), FileAccess.WRITE)
		out.store_string(file)
		out.close()
	var read: LdrModel = LdrModel.parse(file, "probe.mpd")
	CustomParts.dir = PROBE_DIR + "elsewhere/"
	var fresh := PartLibrary.new()
	fresh.load_catalogue()
	var carried: Dictionary = CustomParts.take_from(fresh, read)
	var built: Lbm.PartMesh = _library.mesh_for(id)
	_ok(fresh.mesh_for(id) != null and fresh.mesh_for(id).triangle_count == built.triangle_count
			and fresh.mesh_for(id).boxes == built.boxes,
		"a library that never saw it builds it from the file, the same to the cell %s"
			% carried["added"])
	var again: Transform3D = Transform3D.IDENTITY
	var head_again: Transform3D = Transform3D.IDENTITY
	for placement: LdrModel.Placement in read.flatten():
		if placement.part_id == id:
			again = placement.transform
		elif placement.part_id.begins_with("3626"):
			head_again = placement.transform
	_ok(again.is_equal_approx(world.get_brick(hair_id).transform)
			and (head_again.affine_inverse() * again).is_equal_approx(
				world.get_brick(head_id).transform.affine_inverse() * world.get_brick(hair_id).transform),
		"reopened, it is still seated on the head")
	CustomParts.dir = PROBE_DIR
	world.queue_free()
	builder.queue_free()


func _put(part: MeshPart, kind: String, from: Vector3, toward: Vector3) -> void:
	var hit: Dictionary = part.pick(from, toward)
	var why: String = part.put(kind, hit) if not hit.is_empty() else "missed"
	_ok(why.is_empty(), "a %s put where pointed (%s)" % [kind, why if not why.is_empty()
		else str(hit.get("at"))])


func _refused(file_name: String, bytes: PackedByteArray, says: String) -> void:
	var part: MeshPart = MeshPart.read(bytes, file_name)
	_ok(part.problem.contains(says), "%s: %s" % [file_name, part.problem])


func _closed(part: MeshPart, what: String) -> void:
	var edges: Dictionary = {}
	for t: int in part.triangles.size() / 3:
		for k: int in 3:
			var a: int = part.triangles[t * 3 + k]
			var b: int = part.triangles[t * 3 + (k + 1) % 3]
			var key := Vector2i(a, b)
			edges[key] = int(edges.get(key, 0)) + 1
	var open: int = 0
	for key: Vector2i in edges:
		if int(edges.get(Vector2i(key.y, key.x), 0)) != int(edges[key]):
			open += 1
	_ok(open == 0, "%s is still closed, every edge run once each way (%d not)" % [what, open])


func _save_text(id: String) -> void:
	if _write.is_empty() or not _library.parts.has(id):
		return
	var out: FileAccess = FileAccess.open(_write.path_join(id + ".dat"), FileAccess.WRITE)
	out.store_string(_library.custom_source(id))
	out.close()


# -- files to read ----------------------------------------------------------------------


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


## A part's triangles back as three corners each, in its file's units and the
## app's axes ([param fitted]: as fitted).
static func _soup(part: MeshPart, fitted: bool = false) -> PackedVector3Array:
	var out := PackedVector3Array()
	var points: PackedVector3Array = part.fitted() if fitted else part.corners
	for n: int in part.triangles:
		out.append(points[n])
	return out


## The app's axes back into an STL's, Z up.
static func _in_file_axes(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Vector3 in points:
		out.append(Basis(Vector3.RIGHT, PI / 2.0) * p)
	return out


static func _stl_corners(bytes: PackedByteArray) -> PackedVector3Array:
	var out := PackedVector3Array()
	var count: int = bytes.decode_u32(80)
	for t: int in count:
		for k: int in 3:
			var at: int = 84 + 50 * t + 12 + 12 * k
			out.append(Vector3(bytes.decode_float(at), bytes.decode_float(at + 4),
				bytes.decode_float(at + 8)))
	return out


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


## Written in the app's axes, back to Z up for the file.
static func _stl_ascii(points: PackedVector3Array) -> PackedByteArray:
	var lines := PackedStringArray(["solid probe"])
	var file_points: PackedVector3Array = _in_file_axes(points)
	for t: int in file_points.size() / 3:
		lines.append("  facet normal 0 0 0")
		lines.append("    outer loop")
		for k: int in 3:
			var p: Vector3 = file_points[t * 3 + k]
			lines.append("      vertex %.6f %.6f %.6f" % [p.x, p.y, p.z])
		lines.append("    endloop")
		lines.append("  endfacet")
	lines.append("endsolid probe")
	return "\n".join(lines).to_utf8_buffer()


## An OBJ, Y up, from points Z up as an STL has them.
static func _obj(points: PackedVector3Array) -> PackedByteArray:
	var lines := PackedStringArray(["# probe"])
	var upright: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in points:
		upright.append(MeshPart.UPRIGHT_FROM_Z * p)
	var index: Dictionary = {}
	var faces := PackedStringArray()
	for t: int in upright.size() / 3:
		var three := PackedStringArray()
		for k: int in 3:
			var p: Vector3 = upright[t * 3 + k]
			if not index.has(p):
				index[p] = index.size() + 1
				lines.append("v %.6f %.6f %.6f" % [p.x, p.y, p.z])
			three.append(str(index[p]))
		faces.append("f " + " ".join(three))
	lines.append_array(faces)
	return "\n".join(lines).to_utf8_buffer()


## A closed box of [param size], outward, Z up as a printer's file has it.
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


static func _box_without_top() -> PackedVector3Array:
	var whole: PackedVector3Array = _box(Vector3(20, 20, 20))
	return whole.slice(0, 6) + whole.slice(12)


static func _flat_sheet() -> PackedVector3Array:
	var a := Vector3(0, 0, 0)
	var b := Vector3(10, 0, 0)
	var c := Vector3(0, 10, 0)
	return PackedVector3Array([a, b, c, a, c, b])


static func _sphere(rings: int, around: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for r: int in rings:
		var t0: float = PI * r / rings
		var t1: float = PI * (r + 1) / rings
		for n: int in around:
			var p0: float = TAU * n / around
			var p1: float = TAU * (n + 1) / around
			var a := Vector3(sin(t0) * cos(p0), cos(t0), sin(t0) * sin(p0)) * 10.0
			var b := Vector3(sin(t1) * cos(p0), cos(t1), sin(t1) * sin(p0)) * 10.0
			var c := Vector3(sin(t1) * cos(p1), cos(t1), sin(t1) * sin(p1)) * 10.0
			var d := Vector3(sin(t0) * cos(p1), cos(t0), sin(t0) * sin(p1)) * 10.0
			out.append_array([a, b, c, a, c, d])
	return out


func _finish() -> void:
	_forget(PROBE_DIR + "elsewhere/")
	_forget(PROBE_DIR)
	if _failures == 0:
		print("\na part from a 3D file is brought in, fitted, given connectors, worn, saved and carried")
	else:
		print("\n%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	for name: String in DirAccess.get_directories_at(dir):
		_forget(dir + name + "/")
	DirAccess.remove_absolute(dir)
