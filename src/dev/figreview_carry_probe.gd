## figreview: a model wearing moulds made in figmould's maker, saved and
## opened again in this build and in an older one (live), and someone
## else's model bringing a mould of the same id as one of the person's.
##
## --figmode=make (in a figmould tree): five moulds made as Save mould makes
## them (Mould.make): 3901 pulled, grown and shrunk; a mould of that mould
## (Mould.of_made, as Make a mould… on a worn mould starts); 3901 made finer
## to 9,000 triangles; a club; and a second "Quiff" of another shape. Each
## worn on a head of a model (with a 3001 beside them) opened and saved:
## the file carries each as 0 FILE with its own text whole, reopened every
## part where it was, saved again with no edit to the same bytes. Then the
## same file as someone else's, the first mould's id given another shape:
## theirs drawn as theirs under a name of its own, mine left mine (in the
## library and in the kept folder), and saved, both kept.
##
## --figmode=read (in any tree, live's too): the file made above opened by a
## library that never saw its parts: every part where figmould had it, each
## mould built with the corners figmould built; saved with no edit to the
## same bytes; the 3001 moved a stud and saved: each mould's 0 FILE section
## the same to the byte, and reopened, every part where it was.
##
##   godot --headless --path . --script src/dev/figreview_carry_probe.gd -- --figmode=make --figdir=DIR
##   godot --headless --path . --script src/dev/figreview_carry_probe.gd -- --figmode=read --figdir=DIR --figlabel=live
##
## DIR is an absolute folder both runs reach (each probe run has its own
## user://). Made parts go to user://figreview_carry/, never the person's own.
extends "res://src/dev/pastereview_probe.gd"

const CARRY_DIR := "user://figreview_carry/"

var _mode: String = ""
var _dir: String = ""
var _label: String = "here"


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--figmode="):
			_mode = arg.trim_prefix("--figmode=")
		elif arg.begins_with("--figdir="):
			_dir = arg.trim_prefix("--figdir=")
		elif arg.begins_with("--figlabel="):
			_label = arg.trim_prefix("--figlabel=")
	if _dir.is_empty() or not _mode in ["make", "read"]:
		print("usage: -- --figmode=make|read --figdir=ABSOLUTE_DIR")
		quit(2)
		return
	await process_frame
	_forget(CARRY_DIR)
	DirAccess.make_dir_recursive_absolute(CARRY_DIR + "parts/")
	DirAccess.make_dir_recursive_absolute(_dir)
	CustomParts.dir = CARRY_DIR + "parts/"
	SaveTo.native = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(240)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_verbs = _main.get("_verbs")
	_store = _main.get("_store")
	print("figreview_carry: %s, in %s (%s)" % [_mode, ProjectSettings.globalize_path("res://"), _label])
	if _mode == "make":
		await _make()
	else:
		await _read()
	_forget(CARRY_DIR)
	print("\nfigreview_carry_probe (%s, %s): %d failed, %d notes" % [_mode, _label, _failures, _notes])
	quit(1 if _failures > 0 else 0)


# -- make ----------------------------------------------------------------------------------


func _make() -> void:
	print("\nfive moulds made as Save mould makes them")
	var ids: Array = []
	var quiff: Mould = Mould.of_part(_library, "3901", "headwear")
	quiff.refine(Mould.FINEST * 2.0)
	for tool: String in ["pull", "inflate", "shrink"]:
		_stroke(quiff, tool)
	ids.append(_made(quiff, "Quiff"))
	var script: GDScript = load("res://src/minifig/mould.gd")
	var further: Mould = script.call("of_made", _library, ids[0], "headwear")
	_ok(further != null and further.base == "3901", "a mould of the Quiff stands for 3901 (base %s)"
		% (further.base if further != null else "none"))
	further.refine(Mould.FINEST * 2.0)
	_stroke(further, "pull")
	ids.append(_made(further, "Quiff Further"))
	var fine: Mould = Mould.of_part(_library, "3901", "headwear")
	fine.refine(Mould.FINEST * 2.0)
	fine.refine(Mould.FINEST)
	fine.refine(Mould.FINEST)
	_stroke(fine, "pinch")
	print("  (the fine one: %d triangles)" % fine.triangle_count())
	ids.append(_made(fine, "Fine Ünïcødé ✨"))
	var club: Mould = Mould.club()
	club.refine(Mould.FINEST * 2.0)
	_stroke(club, "inflate")
	ids.append(_made(club, "Club"))
	var second: Mould = Mould.of_part(_library, "3901", "headwear")
	second.refine(Mould.FINEST * 2.0)
	_stroke(second, "push")
	ids.append(_made(second, "Quiff"))
	_ok(ids.size() == 5 and Dictionary(Array(ids).reduce(func(seen: Dictionary, id: String) -> Dictionary:
		seen[id] = true
		return seen, {})).size() == 5, "five moulds, five ids: %s" % ", ".join(PackedStringArray(ids)))

	var lines := PackedStringArray(["0 figreview carry", "0 Name: figreview_carry.ldr",
		"0 Author: figreview", "1 4 0 0 200 1 0 0 0 1 0 0 0 1 3001.dat"])
	for n: int in ids.size():
		var x: int = n * 60
		if n == 3:
			lines.append("1 6 %d -24 0 1 0 0 0 1 0 0 0 1 %s.dat" % [x, ids[n]])
			continue
		lines.append("1 14 %d -24 0 1 0 0 0 1 0 0 0 1 3626c.dat" % x)
		lines.append("1 %d %d -24 0 1 0 0 0 1 0 0 0 1 %s.dat" % [70 + n, x, ids[n]])
	var base: String = _dir.path_join("base.ldr")
	_write(base, "\n".join(lines) + "\n")
	await _open(base)
	var at: String = _dir.path_join("A.mpd")
	_ok(bool(_main.call("save_model", at)), "saved, wearing them, as A.mpd")
	var text: String = FileAccess.get_file_as_string(at)
	for id: String in ids:
		var own: String = _library.custom_source(id)
		_ok(text.contains("0 FILE %s.dat" % id) and text.contains(own.strip_edges()),
			"  A.mpd carries %s as 0 FILE, its text whole (%d bytes)" % [id, own.length()])
	var records: Array = _records_all()
	await _open(at)
	_exact("reopened here", records, _records_all())
	var again: String = _dir.path_join("A_again.mpd")
	_main.call("save_model", again)
	_ok(FileAccess.get_file_as_string(again) == text, "saved again with no edit: the same %d bytes"
		% text.length())
	var meshes: Dictionary = {}
	for id: String in ids:
		meshes[id] = _corners(_library.mesh_for(id))
	var kept := FileAccess.open(_dir.path_join("A.json"), FileAccess.WRITE)
	kept.store_string(JSON.stringify({"ids": ids, "records": _plain(records), "meshes": meshes}))
	kept.close()

	await _theirs(text, ids)


## Someone else's copy of A.mpd whose first mould has my id and their shape.
func _theirs(text: String, ids: Array) -> void:
	print("\nsomeone else's model: my Quiff's id, their shape")
	var mine: String = str(ids[0])
	var own: String = _library.custom_source(mine)
	var kept_file: String = CustomParts.dir + mine + ".dat"
	var kept_before: String = FileAccess.get_file_as_string(kept_file)
	var face: int = own.find("\n3 ")
	var line_end: int = own.find("\n", face + 1)
	var words: PackedStringArray = own.substr(face + 1, line_end - face - 1).split(" ")
	words[2] = str(float(words[2]) + 4.0)
	var theirs_part: String = own.substr(0, face + 1) + " ".join(words) + own.substr(line_end)
	var theirs: String = text.replace(own.strip_edges(), theirs_part.strip_edges())
	_ok(theirs != text, "  (their file: one corner of %s moved 4 LDU)" % mine)
	var at: String = _dir.path_join("T.mpd")
	_write(at, theirs)
	await _open(at)
	var placed: Array = _records_all()
	var named: Array = placed.filter(func(one: Dictionary) -> bool:
		return str(one["part"]).begins_with(mine))
	var renamed: bool = named.size() == 1 and str(named[0]["part"]) != mine
	_ok(renamed, "theirs comes in under a name of its own: %s" % (named[0]["part"] if named.size() == 1 else "%d parts" % named.size()))
	_ok(_library.custom_source(mine) == own and FileAccess.get_file_as_string(kept_file) == kept_before,
		"  mine is still mine, in the library and in the kept folder")
	if renamed:
		var theirs_id: String = named[0]["part"]
		_ok(CustomParts.as_read(_library.custom_source(theirs_id)).contains(" ".join(words).strip_edges()),
			"  and theirs is drawn as their file has it")
	var saved: String = _dir.path_join("T_saved.mpd")
	_main.call("save_model", saved)
	await _open(saved)
	_exact("their model saved and reopened", placed, _records_all())


func _stroke(mould: Mould, tool: String) -> void:
	var best: int = -1
	for v: int in mould.positions.size():
		if mould.locks[v] == 0.0 and (best < 0 or mould.positions[v].y > mould.positions[best].y):
			best = v
	mould.begin()
	mould.dab(tool, mould.positions[best], mould.normals[best], 6.0, 0.8, true)


func _made(mould: Mould, title: String) -> String:
	var result: Dictionary = mould.make(_library, title)
	_ok(str(result["problem"]).is_empty(), "made \"%s\": %s (%d triangles)%s" % [title, result["id"],
		mould.triangle_count(), "" if str(result["problem"]).is_empty() else " " + str(result["problem"])])
	return str(result["id"])


# -- read --------------------------------------------------------------------------------------


func _read() -> void:
	var made: Variant = JSON.parse_string(FileAccess.get_file_as_string(_dir.path_join("A.json")))
	if not made is Dictionary:
		_ok(false, "no A.json in %s: run --figmode=make first" % _dir)
		return
	var ids: Array = made["ids"]
	var at: String = _dir.path_join("A.mpd")
	var text: String = FileAccess.get_file_as_string(at)
	print("\nA.mpd opened where its parts were never made (%s)" % _label)
	await _open(at)
	var records: Array = _records_all()
	_exact("every part where figmould had it", _unplain(made["records"]), records)
	for id: String in ids:
		var corners: Array = _corners(_library.mesh_for(id))
		var theirs: Array = made["meshes"][id]
		var off: float = INF if corners.size() != theirs.size() or corners.is_empty() else 0.0
		for n: int in corners.size() if off == 0.0 else 0:
			off = maxf(off, absf(float(corners[n]) - float(theirs[n])))
		_ok(off <= 0.002, "  %s built with figmould's corners (%d numbers against %d, most apart %.4f LDU)"
			% [id, corners.size(), theirs.size(), off])
	var again: String = _dir.path_join("A_%s.mpd" % _label)
	_main.call("save_model", again)
	var written: String = FileAccess.get_file_as_string(again)
	_ok(written == text, "saved with no edit: the same bytes (%d against %d)%s" % [written.length(),
		text.length(), "" if written == text else ": " + _first_difference(text, written)])
	var brick: Array = _world.bricks().filter(func(one: BrickWorld.Brick) -> bool:
		return one.part_id == "3001")
	if brick.size() != 1:
		_ok(false, "one 3001 to move (%d)" % brick.size())
		return
	_select([(brick[0] as BrickWorld.Brick).id])
	var moved: int = _builder.move_selection_by(Vector3(20, 0, 0))
	_builder.clear_selection()
	await _frames(3)
	var after: Array = _records_all()
	var moved_at: String = _dir.path_join("A_%s_moved.mpd" % _label)
	_main.call("save_model", moved_at)
	var moved_text: String = FileAccess.get_file_as_string(moved_at)
	for id: String in ids:
		_ok(_section(moved_text, id + ".dat") == _section(text, id + ".dat")
			and not _section(text, id + ".dat").is_empty(),
			"  the 3001 moved (%d) and saved: %s's 0 FILE the same to the byte" % [moved, id])
	await _open(moved_at)
	_exact("moved, saved, reopened", after, _records_all())


# -- helpers -------------------------------------------------------------------------------


## Each part where [param b] has it as [param a] does, to a hundredth of an
## LDU, its part and colour the same.
func _exact(said: String, a: Array, b: Array) -> void:
	var p: Dictionary = _pair(a, b, Vector3.ZERO)
	var bad: bool = int(p["unpaired_a"]) > 0 or int(p["unpaired_b"]) > 0 or int(p["over"]) > 0
	_ok(not bad, "%s: %d against %d; unpaired %d/%d; most apart %.5f LDU" % [said, a.size(), b.size(),
		int(p["unpaired_a"]), int(p["unpaired_b"]), float(p["origin"])])


static func _corners(mesh: Lbm.PartMesh) -> Array:
	var out: Array = []
	if mesh == null:
		return out
	for surface: ArrayMesh in mesh.surfaces:
		for p: Vector3 in surface.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			out.append_array([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
	return out


static func _plain(records: Array) -> Array:
	var out: Array = []
	for one: Dictionary in records:
		var t: Transform3D = one["at"]
		out.append({"part": one["part"], "color": one["color"], "unit": one.get("unit", ""),
			"group": one.get("group", 0), "id": one.get("id", 0),
			"at": [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
				t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]})
	return out


static func _unplain(records: Array) -> Array:
	var out: Array = []
	for one: Dictionary in records:
		var m: Array = one["at"]
		out.append({"part": one["part"], "color": int(one["color"]), "unit": one["unit"],
			"group": one["group"], "id": int(one["id"]),
			"at": Transform3D(Basis(Vector3(m[0], m[1], m[2]), Vector3(m[3], m[4], m[5]),
				Vector3(m[6], m[7], m[8])), Vector3(m[9], m[10], m[11]))})
	return out


## The lines of the 0 FILE section named [param name], or "".
static func _section(text: String, name: String) -> String:
	var at: int = text.find("0 FILE " + name)
	if at < 0:
		return ""
	var end: int = text.find("\n0 FILE ", at + 1)
	return text.substr(at, (end - at) if end >= 0 else -1)


static func _first_difference(a: String, b: String) -> String:
	var one: PackedStringArray = a.split("\n")
	var other: PackedStringArray = b.split("\n")
	for n: int in mini(one.size(), other.size()):
		if one[n] != other[n]:
			return "line %d %s -> %s" % [n + 1, JSON.stringify(one[n].left(80)), JSON.stringify(other[n].left(80))]
	return "%d lines against %d" % [one.size(), other.size()]
