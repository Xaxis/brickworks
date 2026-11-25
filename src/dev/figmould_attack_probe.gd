## Your own minifig hair attacked (figmould's self-attack): hair files that
## are inside out, half turned, open, 300 times too big or a thousandth of
## the size, and of a million triangles; a mould kept for the tab that is
## damaged on the disk, cut short, out of range, or left half written; a name
## holding a carriage return. Each is mended or refused in a sentence, a
## refused file makes no part, and the mould is saved whole after each.
##
##   godot --headless --path . --script src/dev/figmould_attack_probe.gd
##
## Made parts and drafts go to user://figmould_attack/, never the person's own.
extends SceneTree

const PROBE_DIR := "user://figmould_attack/"
const FIXTURES := "res://tests/fixtures/own_parts/"

var _failures: int = 0
var _library: PartLibrary


func _initialize() -> void:
	_forget(PROBE_DIR)
	CustomParts.dir = PROBE_DIR + "parts/"
	MouldEditor.drafts = PROBE_DIR + "drafts/"
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_files()
	await _drafts()
	_forget(PROBE_DIR)
	print("\nfigmould_attack: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- hair from a file -----------------------------------------------------------------


func _files() -> void:
	print("\nhair files that are wrong")
	var points: PackedVector3Array = _stl_corners(FileAccess.get_file_as_bytes(FIXTURES + "wig_67.stl"))
	var straight: MeshPart = _as_hair(points, "wig.stl")
	_ok(straight.problem.is_empty(), "the wig as it comes is hair (%s)" % straight.problem)
	var volume: float = _volume(straight)

	var inside_out := PackedVector3Array()
	var half := PackedVector3Array()
	for t: int in points.size() / 3:
		var a: Vector3 = points[t * 3]
		var b: Vector3 = points[t * 3 + 1]
		var c: Vector3 = points[t * 3 + 2]
		inside_out.append_array(PackedVector3Array([a, c, b]))
		half.append_array(PackedVector3Array([a, c, b] if t % 2 == 1 else [a, b, c]))
	for pair: Array in [[inside_out, "inside out"], [half, "every other triangle turned"]]:
		var part: MeshPart = _as_hair(pair[0], "wig-%s.stl" % str(pair[1]).replace(" ", "-"))
		_ok(part.problem.is_empty() and absf(_volume(part) - volume) <= absf(volume) * 1e-4
			and _volume(part) * volume > 0.0,
			"a wig %s is turned outward, as the wig is: volume %.1f, the wig's %.1f (%s)"
				% [pair[1], _volume(part), volume, part.problem])
		_ok(part.turn.is_equal_approx(straight.turn) and part.box().size.is_equal_approx(straight.box().size),
			"  stood, faced and sized on the head as the wig is: %s against %s"
				% [part.box().size, straight.box().size])

	for scaled: Array in [[300.0, "300 times too big"], [0.001, "a thousandth of the size"]]:
		var grown := PackedVector3Array()
		for p: Vector3 in points:
			grown.append(p * float(scaled[0]))
		var part: MeshPart = _as_hair(grown, "wig-scaled.stl")
		_ok(part.problem.is_empty() and part.box().size.distance_to(straight.box().size)
			< straight.box().size.length() * 0.01,
			"a wig %s is sized round the head as the wig is: %s against %s (%s)"
				% [scaled[1], part.box().size, straight.box().size, part.problem])

	var open: MeshPart = MeshPart.read(FileAccess.get_file_as_bytes(FIXTURES + "hair-emka.stl"),
		"hair-emka.stl")
	_ok(open.problem.contains("not a closed shape") and open.problem.contains("Fill Holes"),
		"an open hair is refused, with how to close it: %s" % open.problem)

	var stl_million := PackedByteArray()
	stl_million.resize(84 + 50 * 1000000)
	stl_million.encode_u32(80, 1000000)
	var at: int = Time.get_ticks_msec()
	var big: MeshPart = MeshPart.read(stl_million, "million.stl")
	_ok(not big.problem.is_empty() and Time.get_ticks_msec() - at < 200,
		"an STL of a million triangles (%d MB) is refused before it is read, in %d ms: %s"
			% [stl_million.size() >> 20, Time.get_ticks_msec() - at, big.problem])

	var obj_million: PackedByteArray = _grid_obj(709)
	_ok(obj_million.size() < MeshPart.MOST_BYTES, "  an OBJ of 1,002,528 triangles in %d MB, under the %d MB a file may be"
		% [obj_million.size() >> 20, MeshPart.MOST_BYTES >> 20])
	at = Time.get_ticks_msec()
	var fine: MeshPart = MeshPart.read(obj_million, "million.obj")
	var took: int = Time.get_ticks_msec() - at
	_ok(fine.problem.contains("1,002,528") and fine.problem.contains("at most 120,000"),
		"an OBJ of a million triangles is refused in a sentence, in %d ms: %s" % [took, fine.problem])

	var kept: PackedStringArray = DirAccess.get_files_at(CustomParts.dir) \
		if DirAccess.dir_exists_absolute(CustomParts.dir) else PackedStringArray()
	_ok(kept.is_empty(), "no file refused or read made a part (%d kept)" % kept.size())


func _as_hair(points: PackedVector3Array, file_name: String) -> MeshPart:
	var part: MeshPart = MeshPart.read(_stl_binary(points), file_name)
	if part.problem.is_empty():
		part.make_hair()
	return part


## The part's volume as its triangles wind: positive outward, the sign the
## same for any two wound the same way.
static func _volume(part: MeshPart) -> float:
	var sum: float = 0.0
	for t: int in part.triangles.size() / 3:
		var a: Vector3 = part.corners[part.triangles[t * 3]]
		var b: Vector3 = part.corners[part.triangles[t * 3 + 1]]
		var c: Vector3 = part.corners[part.triangles[t * 3 + 2]]
		sum += a.dot(b.cross(c)) / 6.0
	return sum


## A flat grid of [param side] x [param side] corners as an OBJ, two
## triangles a square, its numbers as short as an OBJ's can be.
static func _grid_obj(side: int) -> PackedByteArray:
	var lines := PackedStringArray()
	for i: int in side:
		for j: int in side:
			lines.append("v %d %d 0" % [i, j])
	for i: int in side - 1:
		for j: int in side - 1:
			var v: int = i * side + j + 1
			lines.append("f %d %d %d" % [v, v + side, v + 1])
			lines.append("f %d %d %d" % [v + 1, v + side, v + side + 1])
	return "\n".join(lines).to_utf8_buffer()


# -- the mould kept for the tab -------------------------------------------------------


func _drafts() -> void:
	print("\nthe mould kept for the tab, damaged")
	var editor := MouldEditor.new()
	editor.library = _library
	root.add_child(editor)
	await process_frame
	editor.open("3901", "headwear", 0)
	await process_frame
	_ok(editor.mould != null and editor.mould.base == "3901", "Make a mould… opens on 3901")
	_stroke(editor.mould)
	var shaped: PackedVector3Array = editor.mould.positions.duplicate()
	editor._name.text = "Quiff"
	editor.close()
	var path: String = editor._draft_path()
	var good: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_ok(good.size() > 1000 and not FileAccess.file_exists(path + ".new"),
		"closed, the mould is kept whole (%d bytes), nothing left half written" % good.size())

	var cut: PackedByteArray = good.slice(0, good.size() / 2)
	var garbage := PackedByteArray()
	garbage.resize(4096)
	for n: int in garbage.size():
		garbage[n] = (n * 131 + 7) % 256
	var draft: Dictionary = bytes_to_var(good)
	var out_of_range: Dictionary = draft.duplicate(true)
	var triangles: PackedInt32Array = out_of_range["mould"]["triangles"]
	triangles[0] = 999999
	out_of_range["mould"]["triangles"] = triangles
	var no_number: Dictionary = draft.duplicate(true)
	var corners: PackedVector3Array = no_number["mould"]["positions"]
	corners[5] = Vector3(NAN, 0, 0)
	no_number["mould"]["positions"] = corners
	for bad: Array in [[cut, "cut short"], [garbage, "noise"], [var_to_bytes(out_of_range),
			"a triangle past its corners"], [var_to_bytes(no_number), "a corner that is no number"],
			[var_to_bytes(["not", "a", "draft"]), "not a draft at all"], [PackedByteArray(), "empty"]]:
		_write(path, bad[0])
		editor.open("3901", "headwear", 0)
		await process_frame
		_ok(editor.mould != null and editor.mould.base == "3901" and not editor.mould.can_undo()
			and editor._status.text.contains("could not be read back")
			and not FileAccess.file_exists(path),
			"a kept mould %s: begun again from 3901, said, and let go: \"%s\"" % [bad[1], editor._status.text])
		editor.close()

	_write(path, good)
	_write(path + ".new", cut)
	editor.open("3901", "headwear", 0)
	await process_frame
	_ok(editor.mould.positions == shaped and editor._name.text == "Quiff",
		"a write cut short beside it leaves the mould before as it was: \"%s\"" % editor._status.text)
	_stroke(editor.mould)
	editor._keep_draft()
	_ok(not FileAccess.file_exists(path + ".new") and FileAccess.get_file_as_bytes(path) != good,
		"  the next stroke is kept in its place, nothing left beside it")

	print("\na name that would break the part's lines")
	editor._name.text = "Swept\r0 FILE evil.dat\u0007 quiff"
	editor._keep_draft()
	editor.close()
	editor.open("3901", "headwear", 0)
	await process_frame
	print("  (the name field holds %s)" % JSON.stringify(editor._name.text))
	var plain_lines: int = editor.mould.text("x", "Plain").split("\n").size()
	await editor._save_mould()
	var ids: Array = []
	for id: String in _library.custom:
		ids.append(id)
	var text: String = str(_library.custom[ids[0]]) if ids.size() == 1 else ""
	var lines: PackedStringArray = text.split("\n")
	var files: int = 0
	for line: String in lines:
		if line.begins_with("0 FILE"):
			files += 1
	_ok(ids.size() == 1 and not text.contains("\r") and not text.contains("\u0007")
		and files == 0 and lines.size() == plain_lines and lines[0].contains("Custom Mould Swept")
		and lines[0].ends_with("quiff"),
		"saved, its name is one line of words, %d lines as a plain name's: %s"
			% [lines.size(), JSON.stringify(lines[0])])
	_ok(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".new"),
		"  saved, nothing is kept for next time")
	editor.queue_free()
	await process_frame


## A pull on the hair's free crown, as one step.
func _stroke(mould: Mould) -> void:
	var best: int = -1
	for v: int in mould.positions.size():
		if mould.locks[v] == 0.0 and (best < 0 or mould.positions[v].y < mould.positions[best].y):
			best = v
	mould.begin()
	mould.dab("pull", mould.positions[best], mould.normals[best], 6.0, 0.8, true)


# -- helpers ----------------------------------------------------------------------------


func _write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


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
