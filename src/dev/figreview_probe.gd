## figreview: an independent review of figmould (your own minifig hair, made
## in 3D) attacked headless, the maker driven as its buttons and strokes
## drive it. Each check states what must hold; a FAIL is a finding.
##
## 1. The lattice on, then Finer: a handle's drag bends every corner, the new
##    ones too, as a lattice put round the finer part bends it.
## 2. The lattice on, a brush stroke on the part, then a handle's drag: the
##    stroke stays.
## 3. The disk full from the second stroke on (a run under a limit on a
##    file's size, so the write stops partway as on a full disk; three runs,
##    disk_full.sh): the mould kept before is still there to open, not
##    "could not be read back".
## 4. OBJ files past 120,000 triangles that the count before reading misses:
##    faces of many corners, and lines that begin with a space. Each refused
##    in under 2 s, as a plain one is.
## 5. Start from a part of 144,000 triangles (56823, a string a figure
##    holds): the maker opens in under 2 s, and what is kept of it opens.
## 6. Someone else's part carried in a model, with a carriage return in its
##    name and its category: no carriage return reaches a mould made from it.
##
##   godot --headless --path . --script src/dev/figreview_probe.gd -- [--cases=1,2]
##
## Made parts and drafts go to user://figreview_probe/, never the person's own.
extends SceneTree

const PROBE_DIR := "user://figreview_probe/"

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
		await _lattice_finer()
	if _on("2"):
		await _lattice_brush()
	if _on("3"):
		await _draft_disk_full()
	if _on("4"):
		_obj_uncounted()
	if _on("5"):
		await _huge_start()
	if _on("6"):
		await _carried_names()
	_forget(PROBE_DIR)
	print("\nfigreview_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _on(case: String) -> bool:
	return _cases.is_empty() or _cases.has(case)


func _editor() -> MouldEditor:
	var editor := MouldEditor.new()
	editor.library = _library
	root.add_child(editor)
	editor.size = Vector2(1280, 800)
	return editor


# -- 1. lattice, then Finer -------------------------------------------------------------


func _lattice_finer() -> void:
	print("\n1. the lattice on, then Finer, then a handle dragged")
	var editor: MouldEditor = _editor()
	await process_frame
	editor.open("3901", "hat_extra", 0)
	await process_frame
	editor._lattice.button_pressed = true
	var corners: int = editor.mould.positions.size()
	editor._make_finer()
	var finer: int = editor.mould.positions.size()
	print("  (Finer with the lattice on: %d corners -> %d)" % [corners, finer])
	# The right answer: a lattice put round the part as it is after Finer. A
	# copy of its own: to_draft() hands over the mould's own arrays, and a
	# mould made from them shares them (a packed array is held by reference).
	var reference: Mould = Mould.from_draft(bytes_to_var(var_to_bytes(editor.mould.to_draft())))
	reference.lattice_begin()
	# A handle's drag as the maker makes it (_press on a handle, then _move):
	# the right middle handle out by 3 LDU, symmetry on (its mirror too).
	var handle: int = 2 * 9 + 1 * 3 + 1
	var to: Vector3 = editor.mould.lattice_handles()[handle] + Vector3(3.0, 0.0, 0.0)
	editor._begin_step()
	editor.mould.lattice_move(handle, to, true)
	editor._show()
	editor._release()
	reference.lattice_move(handle, to, true)
	var worst: float = 0.0
	var worst_new: float = 0.0
	var unmoved_new: int = 0
	for v: int in finer:
		var d: float = editor.mould.positions[v].distance_to(reference.positions[v])
		worst = maxf(worst, d)
		if v >= corners:
			worst_new = maxf(worst_new, d)
			if d > 0.05:
				unmoved_new += 1
	_ok(finer > corners and worst < 0.01,
		"Finer under the lattice, then a handle out 3 LDU: every corner where a lattice round the finer part puts it (most off %.2f LDU; %d of the %d new corners left behind, most %.2f LDU)"
			% [worst, unmoved_new, finer - corners, worst_new])
	editor._undo()
	_ok(editor.mould.positions.size() == finer, "  Undo takes the drag back (%d corners)" % editor.mould.positions.size())
	editor.close()
	editor.queue_free()
	await process_frame


# -- 2. lattice, a brush stroke, then a handle --------------------------------------


func _lattice_brush() -> void:
	print("\n2. the lattice on, a brush stroke, then a handle dragged")
	var editor: MouldEditor = _editor()
	await process_frame
	editor.open("3901", "hat_extra", 0)
	await process_frame
	editor._lattice.button_pressed = true
	var mould: Mould = editor.mould
	var crown: int = _crown(mould)
	var before: Vector3 = mould.positions[crown]
	# A pull on the crown, as _press -> _dab makes it (no handle under it).
	editor._begin_step()
	mould.dab("pull", mould.positions[crown], mould.normals[crown], 6.0, 0.8, true)
	editor._release()
	var pulled: Vector3 = mould.positions[crown]
	# The bottom corner handle, far from the crown, nudged half an LDU.
	var handle: int = 0
	var to: Vector3 = mould.lattice_handles()[handle] + Vector3(0.0, 0.0, -0.5)
	editor._begin_step()
	mould.lattice_move(handle, to, true)
	editor._release()
	var after: Vector3 = mould.positions[crown]
	_ok(after.distance_to(pulled) < before.distance_to(pulled) * 0.25,
		"the crown pulled %.2f LDU stays pulled after a bottom handle moves half an LDU: now %.2f from the pull, %.2f from before it"
			% [before.distance_to(pulled), after.distance_to(pulled), after.distance_to(before)])
	editor.close()
	editor.queue_free()
	await process_frame


func _crown(mould: Mould) -> int:
	var best: int = -1
	for v: int in mould.positions.size():
		if mould.locks[v] == 0.0 and (best < 0 or mould.positions[v].y > mould.positions[best].y):
			best = v
	return best


# -- 3. the disk full mid-draft ------------------------------------------------------


## Three runs, one step each, the second under a limit on how big a file it
## may write (ulimit -f, SIGXFSZ ignored): each write past it is refused
## partway, as a full disk refuses one. --fullstep=prepare keeps a mould
## after a stroke in --draftdir=DIR; fill opens it, strokes and closes under
## the limit; check opens what is kept, as after a reload. Run them with
## bench/results/figreview-2026-11-25/disk_full.sh.
func _draft_disk_full() -> void:
	var step: String = ""
	var dir: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fullstep="):
			step = arg.trim_prefix("--fullstep=")
		elif arg.begins_with("--draftdir="):
			dir = arg.trim_prefix("--draftdir=")
	if step.is_empty() or dir.is_empty():
		print("\n3. the disk full: run by disk_full.sh (--fullstep= and --draftdir=), skipped here")
		return
	print("\n3. the disk full, step %s" % step)
	MouldEditor.drafts = dir
	var editor: MouldEditor = _editor()
	await process_frame
	editor.open("3901", "headwear", 0)
	await process_frame
	var path: String = editor._draft_path()
	var shaped_file: String = dir.path_join("shaped.bin")
	match step:
		"prepare":
			_stroke(editor)
			editor._name.text = "Quiff"
			editor.close()
			var file := FileAccess.open(shaped_file, FileAccess.WRITE)
			file.store_var(editor.mould.positions)
			file.close()
			_ok(FileAccess.get_file_as_bytes(path).size() > 40000, "  kept after one stroke: %d bytes"
				% FileAccess.get_file_as_bytes(path).size())
		"fill":
			_ok(editor._restored, "  opened on the mould kept (%s)" % editor._status.text)
			_stroke(editor)
			editor.close()
			print("  (the disk full: after a stroke and Close the draft is %d bytes)"
				% FileAccess.get_file_as_bytes(path).size())
		"check":
			var file := FileAccess.open(shaped_file, FileAccess.READ)
			var shaped: PackedVector3Array = file.get_var() if file != null else PackedVector3Array()
			_ok(editor._restored and not editor._status.text.contains("could not be read back"),
				"a write the full disk cut short leaves a mould to open: restored %s, %d corners as the first stroke left them of %d, \"%s\""
					% [editor._restored, _same_corners(editor.mould.positions, shaped), shaped.size(),
						editor._status.text])
	editor.queue_free()
	await process_frame


static func _same_corners(a: PackedVector3Array, b: PackedVector3Array) -> int:
	var same: int = 0
	for v: int in mini(a.size(), b.size()):
		if a[v] == b[v]:
			same += 1
	return same


func _stroke(editor: MouldEditor) -> void:
	var mould: Mould = editor.mould
	var crown: int = _crown(mould)
	editor._begin_step()
	mould.dab("pull", mould.positions[crown], mould.normals[crown], 6.0, 0.8, true)
	editor._release()


# -- 4. OBJ files the count misses -------------------------------------------------------


func _obj_uncounted() -> void:
	print("\n4. OBJ files past 120,000 triangles that are not counted before they are read")
	var side: int = 709
	var lines := PackedStringArray()
	for i: int in side:
		for j: int in side:
			lines.append("v %d %d 0" % [i, j])
	var vertices: String = "\n".join(lines)
	# Each row of the grid one face, its corners zigzagging between two rows:
	# 1,416 triangles a face, 708 faces.
	var faces := PackedStringArray()
	for i: int in side - 1:
		var corners := PackedStringArray(["f"])
		for j: int in side:
			corners.append(str(i * side + j + 1))
			corners.append(str((i + 1) * side + j + 1))
		faces.append(" ".join(corners))
	var polygons: PackedByteArray = (vertices + "\n" + "\n".join(faces) + "\n").to_utf8_buffer()
	# The plain grid of triangles, each line begun with a space.
	var spaced := PackedStringArray()
	for line: String in lines:
		spaced.append(" " + line)
	for i: int in side - 1:
		for j: int in side - 1:
			var v: int = i * side + j + 1
			spaced.append(" f %d %d %d" % [v, v + side, v + 1])
			spaced.append(" f %d %d %d" % [v + 1, v + side, v + side + 1])
	var indented: PackedByteArray = "\n".join(spaced).to_utf8_buffer()
	for pair: Array in [[polygons, "faces of 1,418 corners (1,002,528 triangles in 708 faces)"],
			[indented, "every line begun with a space (1,002,528 triangles)"]]:
		var bytes: PackedByteArray = pair[0]
		var at: int = Time.get_ticks_msec()
		var part: MeshPart = MeshPart.read(bytes, "hair.obj")
		var took: int = Time.get_ticks_msec() - at
		_ok(not part.problem.is_empty() and took < 2000,
			"an OBJ with %s, %d MB (under the %d MB a file may be), refused in %d ms: %s"
				% [pair[1], bytes.size() >> 20, MeshPart.MOST_BYTES >> 20, took, part.problem.left(120)])


# -- 5. Start from a big part --------------------------------------------------------------


func _huge_start() -> void:
	print("\n5. Start from 56823 (a string a figure holds, 143,996 triangles)")
	var editor: MouldEditor = _editor()
	await process_frame
	editor.open("3847", "accessory", 0)
	await process_frame
	var at: int = Time.get_ticks_msec()
	editor._start_from("56823")
	var took: int = Time.get_ticks_msec() - at
	var faces: int = editor.mould.triangle_count() if editor.mould != null else 0
	_ok(editor.mould != null and took < 2000,
		"Start from 56823 opens the maker in %d ms on this box's main thread (%d triangles)" % [took, faces])
	if editor.mould != null:
		at = Time.get_ticks_msec()
		_stroke(editor)
		print("  (one stroke and its draft: %d ms)" % (Time.get_ticks_msec() - at))
		editor.close()
		var kept: Dictionary = editor._kept()
		_ok(not kept.has("lost") and not kept.is_empty(),
			"  what is kept of it opens again: %s" % ("could not be read back (lost)" if kept.has("lost")
				else "nothing kept" if kept.is_empty() else "%d triangles" % (kept["mould"] as Mould).triangle_count()))
	editor.queue_free()
	await process_frame


# -- 6. someone else's names ---------------------------------------------------------------


func _carried_names() -> void:
	print("\n6. someone else's part with a carriage return in its name and category")
	MouldEditor.drafts = PROBE_DIR + "drafts6/"
	var theirs: String = "\n".join(PackedStringArray([
		"0 Minifig Hair Evil\r0 FILE evil.dat\r1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"0 Name: bw-evilhair-s00000000000000000001.dat",
		"0 Author: someone else",
		"0 !LDRAW_ORG Unofficial_Part",
		"0 !CATEGORY Minifig Headwear\r1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"0 BFC CERTIFY CCW",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 3901.dat",
		"0"])) + "\n"
	var id: String = "bw-evilhair-s00000000000000000001"
	var added: Dictionary = CustomParts.add(_library, theirs, id, false)
	_ok(str(added["problem"]).is_empty(), "their part is built as a model file brings it (%s)" % added["problem"])
	var moulded: String = theirs.replace("0 BFC CERTIFY CCW",
		"%s from=3901 triangles=1\n0 BFC CERTIFY CCW" % PartPrints.MOULDED_BY)
	var mould_id: String = "bw-3901-m-00000000000000000001"
	CustomParts.add(_library, moulded.replace(id, mould_id), mould_id, false)
	var editor: MouldEditor = _editor()
	await process_frame
	for one: Array in [[id, "their part, Make a mould… on it"], [mould_id, "their mould, shaped further"]]:
		editor.open(str(one[0]), "headwear", 0)
		await process_frame
		if editor.mould == null:
			_ok(false, "%s: no mould" % one[1])
			continue
		var text: String = editor.mould.text("bw-x-m-0", "Mine")
		var lines: int = 0
		for line: String in text.split("\n"):
			if line.contains("\r"):
				lines += 1
		_ok(lines == 0, "%s: no carriage return in the part made of it (%d lines hold one: %s)"
			% [one[1], lines, JSON.stringify(text.split("\n")[0].left(90))])
		editor._drop_draft()
		editor.close()
	editor.queue_free()
	await process_frame


# -- helpers ----------------------------------------------------------------------------


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
