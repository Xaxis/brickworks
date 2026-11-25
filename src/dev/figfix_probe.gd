## figfix: the mould maker's fixes for figreview's findings, past the cases
## figreview_probe drives. Each check states what must hold.
##
## 1. The lattice bends what is there when a handle is taken: two handles
##    dragged in turn, a brush between them, and Undo and Redo back through
##    each exactly; a corner pulled past the lattice's box moves no further
##    than the handle that moves it.
## 2. A draft that cannot be written leaves the one before as it was, and
##    says so; the next that can be written takes its place and the words go.
##    A draft that cannot be read is set aside whole, never deleted.
## 3. A part of more triangles than the maker shapes is refused in words at
##    once, from Start and from Make a mould… on it; the mould shown stays.
## 4. 3D files past the most a part is made from are refused as they are
##    read: a binary STL by its own count, a text STL, an OBJ of more corners
##    than its triangles could use; a file within it is read whole, and the
##    3D-file reader's own bound for Brickify is as it was.
## 5. Someone else's carried part with a carriage return in its name and
##    category: the catalogue holds them as one line.
##
##   godot --headless --path . --script src/dev/figfix_probe.gd -- [--cases=1,2]
##
## Made parts and drafts go to user://figfix_probe/, never the person's own.
extends SceneTree

const PROBE_DIR := "user://figfix_probe/"

var _failures: int = 0
var _library: PartLibrary
var _cases: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cases="):
			_cases = Array(arg.trim_prefix("--cases=").split(",", false))
	_forget(PROBE_DIR)
	CustomParts.dir = PROBE_DIR + "parts/"
	MouldEditor.drafts = PROBE_DIR + "drafts/"
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	await process_frame
	if _on("1"):
		await _lattice()
	if _on("2"):
		await _drafts()
	if _on("3"):
		await _too_big()
	if _on("4"):
		_files()
	if _on("5"):
		_names()
	_forget(PROBE_DIR)
	print("\nfigfix_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _on(case: String) -> bool:
	return _cases.is_empty() or _cases.has(case)


func _editor() -> MouldEditor:
	var editor := MouldEditor.new()
	editor.library = _library
	root.add_child(editor)
	editor.size = Vector2(1280, 800)
	return editor


# -- 1. the lattice ----------------------------------------------------------------------


func _lattice() -> void:
	print("\n1. the lattice bends what is there when a handle is taken")
	var editor: MouldEditor = _editor()
	await process_frame
	editor.open("3901", "hat_extra", 0)
	await process_frame
	editor._lattice.button_pressed = true
	var mould: Mould = editor.mould
	var start: PackedVector3Array = mould.positions.duplicate()
	# The right middle handle out 3 LDU (its mirror too), as _press and _move.
	var side: int = 2 * 9 + 1 * 3 + 1
	editor._begin_step()
	mould.lattice_move(side, mould.lattice_handles()[side] + Vector3(3.0, 0.0, 0.0), true)
	editor._release()
	var bent: PackedVector3Array = mould.positions.duplicate()
	# A pull on the crown, then the bottom middle handle down 2 LDU.
	var crown: int = _crown(mould)
	editor._begin_step()
	mould.dab("pull", mould.positions[crown], mould.normals[crown], 6.0, 0.8, true)
	editor._release()
	var pulled: PackedVector3Array = mould.positions.duplicate()
	var bottom: int = 1 * 9 + 0 * 3 + 1
	editor._begin_step()
	mould.lattice_move(bottom, mould.lattice_handles()[bottom] + Vector3(0.0, -2.0, 0.0), true)
	editor._release()
	var both: PackedVector3Array = mould.positions.duplicate()
	# The top, far from the bottom handle, stays as the side drag and the pull
	# left it (the bottom handle's weight there is under a sixteenth).
	var top_kept: float = _most_apart(both, pulled, _top_corners(mould, pulled))
	var pull_kept: float = both[crown].distance_to(pulled[crown])
	# (A middle handle weighs a quarter at most: 3 LDU bends the side about 0.7.)
	_ok(top_kept < 0.25 and pull_kept < 0.25 and pulled[crown].distance_to(bent[crown]) > 0.3
		and _most_apart(bent, start, []) > 0.3,
		"a second handle bends from the first's bend and the pull: the top moved %.2f LDU from them, the crown %.2f (bent %.2f, pulled %.2f)"
			% [top_kept, pull_kept, _most_apart(bent, start, []), pulled[crown].distance_to(bent[crown])])
	var undone: Array = []
	for want: PackedVector3Array in [pulled, bent, start]:
		editor._undo()
		undone.append(_most_apart(mould.positions, want, []))
	_ok(undone.max() == 0.0, "Undo goes back through the bottom drag, the pull and the side drag exactly (%s LDU off)"
		% str(undone))
	var redone: Array = []
	for want: PackedVector3Array in [bent, pulled, both]:
		editor._redo()
		redone.append(_most_apart(mould.positions, want, []))
	_ok(redone.max() == 0.0, "  Redo forward through them exactly (%s LDU off)" % str(redone))
	# The lattice put round again, a free corner on the right grabbed 50 LDU
	# further right, far past the box; then the right middle handle 4 LDU
	# out: nothing moves further than the handle does. (Weighed past the box
	# as inside it, a corner's weights there grow past one.)
	editor._lattice.button_pressed = false
	editor._lattice.button_pressed = true
	var right: int = -1
	for v: int in mould.positions.size():
		if mould.locks[v] == 0.0 and (right < 0 or mould.positions[v].x > mould.positions[right].x):
			right = v
	mould.grab(mould.positions[right], 6.0, false)
	mould.drag(Vector3(50.0, 0.0, 0.0))
	mould.let_go()
	var grabbed: PackedVector3Array = mould.positions.duplicate()
	var handle_from: Vector3 = mould.lattice_handles()[side]
	editor._begin_step()
	mould.lattice_move(side, handle_from + Vector3(4.0, 0.0, 0.0), false)
	editor._release()
	var furthest: float = _most_apart(mould.positions, grabbed, [])
	_ok(furthest <= 4.0 + 1e-3 and furthest > 0.5 and grabbed[right].x > start[right].x + 40.0,
		"a handle moved 4 LDU after a Grab 50 LDU past the box: no corner moved further (most %.2f LDU, the grabbed one %.2f)"
			% [furthest, mould.positions[right].distance_to(grabbed[right])])
	editor._make_finer()
	var finer: int = mould.positions.size()
	var top: int = 1 * 9 + 2 * 3 + 1
	editor._begin_step()
	mould.lattice_move(top, mould.lattice_handles()[top] + Vector3(0.0, 0.0, -2.0), true)
	editor._release()
	_ok(mould.positions.size() == finer, "Finer under the lattice, then a handle: %d corners, no error" % finer)
	editor._drop_draft()
	editor.close()
	editor.queue_free()
	await process_frame


func _crown(mould: Mould) -> int:
	var best: int = -1
	for v: int in mould.positions.size():
		if mould.locks[v] == 0.0 and (best < 0 or mould.positions[v].y > mould.positions[best].y):
			best = v
	return best


## The corners in the top quarter of the part, far from the bottom handles.
static func _top_corners(mould: Mould, at: PackedVector3Array) -> Array:
	var box := AABB(at[0], Vector3.ZERO)
	for p: Vector3 in at:
		box = box.expand(p)
	var out: Array = []
	for v: int in at.size():
		if at[v].y > box.position.y + box.size.y * 0.75 and mould.locks[v] == 0.0:
			out.append(v)
	return out


## The furthest apart two sets of corners are, over [param only] or all.
static func _most_apart(a: PackedVector3Array, b: PackedVector3Array, only: Array) -> float:
	if a.size() != b.size():
		return INF
	var most: float = 0.0
	for v: int in (only if not only.is_empty() else range(a.size())):
		most = maxf(most, a[v].distance_to(b[v]))
	return most


# -- 2. drafts ---------------------------------------------------------------------------


func _drafts() -> void:
	print("\n2. a draft that cannot be written, and one that cannot be read")
	MouldEditor.drafts = PROBE_DIR + "drafts2/"
	var editor: MouldEditor = _editor()
	await process_frame
	editor.open("3901", "headwear", 0)
	await process_frame
	_stroke(editor)
	editor._name.text = "Quiff"
	editor._keep_draft()
	var path: String = editor._draft_path()
	var good: PackedByteArray = FileAccess.get_file_as_bytes(path)
	# A folder where the draft is written beside it: nothing can be written.
	DirAccess.make_dir_recursive_absolute(path + ".new")
	_stroke(editor)
	editor._keep_draft()
	_ok(FileAccess.get_file_as_bytes(path) == good and editor._status.text == MouldEditor.NOT_KEPT,
		"a stroke that cannot be kept leaves the draft before byte for byte (%d bytes), and says \"%s\""
			% [FileAccess.get_file_as_bytes(path).size(), editor._status.text])
	DirAccess.remove_absolute(path + ".new")
	_stroke(editor)
	editor._keep_draft()
	var now: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_ok(now != good and now.size() > 1000 and editor._status.text.is_empty()
		and not FileAccess.file_exists(path + ".new"),
		"  room again: the next stroke is kept in its place, the words gone, nothing beside it")
	editor.close()
	var damaged: PackedByteArray = now.slice(0, now.size() / 3)
	_write(path, damaged)
	editor.open("3901", "headwear", 0)
	await process_frame
	_ok(editor._status.text.contains("could not be read back") and not FileAccess.file_exists(path)
		and FileAccess.get_file_as_bytes(path + ".unread") == damaged,
		"a draft cut short is said, begun again, and set aside whole as .unread (%d bytes), not deleted"
			% FileAccess.get_file_as_bytes(path + ".unread").size())
	editor._drop_draft()
	editor.close()
	editor.queue_free()
	await process_frame


func _stroke(editor: MouldEditor) -> void:
	var mould: Mould = editor.mould
	var crown: int = _crown(mould)
	editor._begin_step()
	mould.dab("pull", mould.positions[crown], mould.normals[crown], 6.0, 0.8, true)
	editor._release()


# -- 3. a part too big to shape -----------------------------------------------------------


func _too_big() -> void:
	print("\n3. parts of more triangles than the maker shapes")
	MouldEditor.drafts = PROBE_DIR + "drafts3/"
	var editor: MouldEditor = _editor()
	await process_frame
	editor.open("3847", "accessory", 0)
	await process_frame
	var held: Mould = editor.mould
	for part: String in ["56823", "30191-f2", "t1031"]:
		var at: int = Time.get_ticks_msec()
		editor._start_from(part)
		var took: int = Time.get_ticks_msec() - at
		_ok(editor.mould == held and took < 200 and editor._status.text.begins_with(part + " has ")
			and editor._status.text.contains("up to 18,000"),
			"Start from %s (%d triangles) is refused in %d ms, the club stays: \"%s\""
				% [part, Mould.triangles_in(_library, part), took, editor._status.text])
	editor._start_from("62711")
	_ok(editor.mould != held and editor.mould != null and editor.mould.base == "62711",
		"  Start from 62711 (%d triangles) opens it" % Mould.triangles_in(_library, "62711"))
	editor.close()
	editor._drop_draft()
	editor.open("56823", "accessory", 0)
	await process_frame
	_ok(editor.mould == null and editor._status.text.begins_with("56823 has 143,996 triangles")
		and not FileAccess.file_exists(editor._draft_path()),
		"Make a mould… on a hand holding 56823: said, nothing opened, nothing kept: \"%s\"" % editor._status.text)
	editor.close()
	editor.queue_free()
	await process_frame


# -- 4. 3D files past the most -------------------------------------------------------------


func _files() -> void:
	print("\n4. 3D files past the most a part is made from, refused as they are read")
	var binary := PackedByteArray()
	binary.resize(84 + 50 * 200000)
	binary.encode_u32(80, 200000)
	var at: int = Time.get_ticks_msec()
	var part: MeshPart = MeshPart.read(binary, "big.stl")
	_ok(part.problem.contains("at least 200,000 triangles") and Time.get_ticks_msec() - at < 200,
		"a binary STL saying 200,000 triangles, refused by its count in %d ms: %s"
			% [Time.get_ticks_msec() - at, part.problem])
	var facets := PackedStringArray(["solid big"])
	for t: int in 130000:
		var x: int = t % 400
		var y: int = t / 400
		facets.append("facet normal 0 0 1\nouter loop\nvertex %d %d 0\nvertex %d %d 0\nvertex %d %d 0\nendloop\nendfacet"
			% [x, y, x + 1, y, x, y + 1])
	facets.append("endsolid big")
	var text_stl: PackedByteArray = "\n".join(facets).to_utf8_buffer()
	at = Time.get_ticks_msec()
	part = MeshPart.read(text_stl, "big.stl")
	_ok(part.problem.contains("at least 120,001 triangles") and part.problem.contains("at most 120,000"),
		"a text STL of 130,000 facets (%d MB), refused as read in %d ms: %s"
			% [text_stl.size() >> 20, Time.get_ticks_msec() - at, part.problem])
	at = Time.get_ticks_msec()
	var whole: MeshFile = MeshFile.read(text_stl, "big.stl")
	_ok(whole.error.is_empty() and whole.triangle_count() == 130000,
		"  Brickify's reader, bound at %d, reads it whole: %d triangles in %d ms (%s)"
			% [MeshFile.MOST_TRIANGLES, whole.triangle_count(), Time.get_ticks_msec() - at, whole.error])
	var lines := PackedStringArray()
	for n: int in 3 * MeshPart.MOST_BROUGHT + 10:
		lines.append("v %d %d %d" % [n % 97, n % 89, n % 83])
	lines.append("f 1 2 3")
	at = Time.get_ticks_msec()
	part = MeshPart.read("\n".join(lines).to_utf8_buffer(), "corners.obj")
	_ok(part.problem.contains("more than 360,000 corners"),
		"an OBJ of %d corners and one face, refused as read in %d ms: %s"
			% [lines.size() - 1, Time.get_ticks_msec() - at, part.problem])
	# Within the most: a closed box of quads (12 triangles), and the wig.
	var cube := "v -10 -10 -10\nv 10 -10 -10\nv 10 10 -10\nv -10 10 -10\nv -10 -10 10\nv 10 -10 10\nv 10 10 10\nv -10 10 10\n" \
		+ "f 1 4 3 2\nf 5 6 7 8\nf 1 2 6 5\nf 2 3 7 6\nf 3 4 8 7\nf 4 1 5 8\n"
	part = MeshPart.read(cube.to_utf8_buffer(), "box.obj")
	_ok(part.problem.is_empty() and part.file_triangles == 12,
		"a box of six quads is read whole: %d triangles (%s)" % [part.file_triangles, part.problem])
	var wig: PackedByteArray = FileAccess.get_file_as_bytes("res://tests/fixtures/own_parts/wig_67.stl")
	part = MeshPart.read(wig, "wig_67.stl")
	_ok(part.problem.is_empty() and part.file_triangles > 1000,
		"  the wig fixture is read whole: %d triangles (%s)" % [part.file_triangles, part.problem])


# -- 5. names carried in --------------------------------------------------------------------


func _names() -> void:
	print("\n5. someone else's part's name and category, held as one line")
	var theirs: String = "\n".join(PackedStringArray([
		"0 Minifig Hair Evil\r0 FILE evil.dat\r1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"0 Name: bw-evilhair-s00000000000000000002.dat",
		"0 Author: someone else",
		"0 !LDRAW_ORG Unofficial_Part",
		"0 !CATEGORY Minifig Headwear\r1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"0 BFC CERTIFY CCW",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 3901.dat",
		"0"])) + "\n"
	var id: String = "bw-evilhair-s00000000000000000002"
	var added: Dictionary = CustomParts.add(_library, theirs, id, false)
	var info: PartLibrary.PartInfo = _library.parts.get(id)
	_ok(str(added["problem"]).is_empty() and info != null and not _has_control(info.name)
		and not _has_control(info.ldraw_category) and info.name.begins_with("Minifig Hair Evil"),
		"its name and category are one line each: %s / %s" % [JSON.stringify(info.name if info else ""),
			JSON.stringify(info.ldraw_category if info else "")])
	_ok(_library.custom.get(id, "") == theirs, "  their part's text is kept as it came")


static func _has_control(words: String) -> bool:
	for n: int in words.length():
		var code: int = words.unicode_at(n)
		if code < 32 or (code >= 127 and code < 160):
			return true
	return false


# -- helpers ----------------------------------------------------------------------------


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	for name: String in DirAccess.get_directories_at(dir):
		_forget(dir + name + "/")
	DirAccess.remove_absolute(dir)
