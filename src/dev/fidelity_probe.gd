## Prove someone else's file comes back as it went in (SourceFile).
##
##   godot --headless --path . --script src/dev/fidelity_probe.gd [-- FILE ...]
##
## A file written the way the LDraw model repository's are, with what a save
## used to lose: the author's name and licence, its history, LDCad's meta
## lines and a flexible part's skin, a retired number placed turned (30028,
## which became 30028b turned and moved 5 LDU), a model drawn below the
## ground, author's steps, a sub-model placed once and one placed twice, a
## part the library has not got. Then:
##
## - saved untouched, it is the same file, line for line, but for the app's
##   own meta lines (which other readers skip);
## - a part recoloured, moved (the retired one), taken away, added, and moved
##   inside the sub-model placed once: each written as such, in place, every
##   other line as it was, and the file opened again is the model edited;
## - a part moved in one copy of the sub-model placed twice cannot be one
##   line: the model is written whole, still under its author's name and
##   licence, and opens as edited;
## - saved under a name of its own, it opens under that name, its first line
##   the author's still;
## - a part the app cannot show is kept and named; the flexible part is
##   drawn, as one piece (flex_skin_probe proves the rest of that).
##
## With FILE arguments, each is also opened, saved untouched and compared
## line for line (the repository's own files).
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore

const FILE := """0 FILE fidelity - main.ldr
0 Fidelity probe
0 Name: fidelity - main.ldr
0 Author: Somebody Else [someone]
0 !LDRAW_ORG Model
0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt
0 !HISTORY 2026-10-16 [someone] Drawn by hand
0 !THEME Probe
0 BFC CERTIFY CCW
0 !LDCAD GROUP_DEF [topLevel=true] [LID=1] [GID=probe] [name=probe] [center=0 0 0]

1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 0 60 1 0 0 0 1 0 0 0 1 3001.dat
1 14 -120 -8 0 1 0 0 0 1 0 0 0 1 30028.dat
1 14 40 0 -60 1 0 0 0 1 0 0 0 1 nopart9x.dat
0 STEP
1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -48 0 1 0 0 0 1 0 0 0 1 fidelity - once.ldr
0 STEP
1 16 100 0 100 1 0 0 0 1 0 0 0 1 fidelity - twice.ldr
1 16 -100 0 100 1 0 0 0 1 0 0 0 1 fidelity - twice.ldr
1 71 0 -96 200 1 0 0 0 1 0 0 0 1 fidelity - band.ldr
0 STEP
0 NOFILE
0 FILE fidelity - once.ldr
0 Once
0 Name: fidelity - once.ldr
0 Author: Somebody Else [someone]
0 !LDRAW_ORG Model
1 15 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
0 NOFILE
0 FILE fidelity - twice.ldr
0 Twice
0 Name: fidelity - twice.ldr
0 Author: Somebody Else [someone]
0 !LDRAW_ORG Model
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3022.dat
1 25 0 -8 0 1 0 0 0 1 0 0 0 1 3022.dat
0 NOFILE
0 FILE fidelity - band.ldr
0 Band
0 Name: fidelity - band.ldr
0 !LDCAD PATH_SKIN [donCol=16] [donPart=4-4cyli.dat]
0 !LDCAD GENERATED [generator=LDCad 1.6b]
1 16 0 0 0 1 0 0 0 1 0 0 0 1 4-4cyli.dat
1 16 0 -1 0 1 0 0 0 1 0 0 0 1 4-4cyli.dat
1 16 0 -2 0 1 0 0 0 1 0 0 0 1 4-4cyli.dat
0 NOFILE
"""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	CustomParts.dir = OS.get_user_data_dir().path_join("fidelity_probe_parts/")
	CustomParts.keeps = false
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("fidelity: FAIL the catalogue does not load")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.builder = _builder
	_store.library = _library
	_store.keeps = false
	await process_frame

	_untouched()
	_edits()
	_copies_apart()
	_named()
	for path: String in OS.get_cmdline_user_args():
		_repository(path)
	print("fidelity: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _expect(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


## The file's lines and the saved one's, the app's own meta lines left out of
## the saved one: the lines that differ, each way.
static func _differ(before: String, after: String) -> Array:
	var kept := PackedStringArray()
	for line: String in after.split("\n"):
		if not line.begins_with("0 !BRICKWORKS "):
			kept.append(line)
	var a: PackedStringArray = before.split("\n")
	var out: Array = []
	var n: int = 0
	while n < maxi(a.size(), kept.size()):
		var x: String = a[n] if n < a.size() else "<none>"
		var y: String = kept[n] if n < kept.size() else "<none>"
		if x != y:
			out.append("line %d: %s  =>  %s" % [n + 1, x, y])
		n += 1
	return out


## The lines one text has that the other has not, the app's own left out:
## [only in before, only in after], whatever their order.
static func _changed(before: String, after: String) -> Array:
	var counts: Dictionary = {}
	for line: String in before.split("\n"):
		counts[line] = int(counts.get(line, 0)) + 1
	var added: Array = []
	for line: String in after.split("\n"):
		if line.begins_with("0 !BRICKWORKS "):
			continue
		if int(counts.get(line, 0)) > 0:
			counts[line] = int(counts[line]) - 1
		else:
			added.append(line)
	var removed: Array = []
	for line: String in counts:
		for _n: int in int(counts[line]):
			removed.append(line)
	return [removed, added]


func _open(text: String) -> Dictionary:
	_world.clear()
	return _store.open_text(text, "fidelity")


## What the app holds: "part colour x y z" a part, sorted, in the view.
func _model() -> PackedStringArray:
	var out := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var at: Vector3 = brick.transform.origin
		# + 0.0: -0.0 is 0.0, and "%.1f" prints the two apart.
		out.append("%s %d %.1f %.1f %.1f" % [brick.part_id, brick.color_code,
			snappedf(at.x, 0.1) + 0.0, snappedf(at.y, 0.1) + 0.0, snappedf(at.z, 0.1) + 0.0])
	out.sort()
	return out


func _brick(part_id: String, colour: int, unit: String = "") -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part_id and brick.color_code == colour and brick.unit == unit:
			return brick
	return null


func _untouched() -> void:
	print("fidelity: saved untouched")
	var opened: Dictionary = _open(FILE)
	_expect(int(opened["placed"]) == 11, "11 parts on the baseplate, the band one of them (%d)"
		% int(opened["placed"]))
	_expect(_store._lifted_by > 0.0, "stood on the ground: lifted %s" % _store._lifted_by)
	_expect(bool(opened.get("kept")), "the file is kept")
	var unshown: Dictionary = opened.get("unshown", {})
	_expect(unshown == {"nopart9x": 1},
		"the part the library has not got named, and the band not: %s" % unshown)
	_expect(_brick("fidelity - band-flex", 71, "Band#1") != null,
		"the band drawn, one piece in its copy, in its colour")
	var saved: String = _store.to_text(_store.title, true)
	var differ: Array = _differ(FILE, saved)
	_expect(differ.is_empty(), "the same file, line for line: %s" % ["; ".join(differ)])
	_expect(saved.contains("0 !BRICKWORKS FLOOR"), "the floor said in the app's own line")


func _edits() -> void:
	print("fidelity: edited")
	_open(FILE)
	var lift: float = _store._lifted_by
	var red: BrickWorld.Brick = _brick("3001", 4)
	var blue: BrickWorld.Brick = _brick("3001", 1)
	var retired: BrickWorld.Brick = _brick("30028b", 14)
	var once: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3003" and brick.transform.origin.y > 60.0 + lift:
			once = brick
	_expect(red != null and blue != null and retired != null and once != null,
		"found the parts to edit (30028 opened as 30028b)")
	if red == null or blue == null or retired == null or once == null:
		return
	_builder.paint_brick(red.id, 0)
	_builder.move_bricks({retired.id: retired.transform.translated(Vector3(20, 0, 0))})
	_builder.remove_brick_id(blue.id)
	_builder.move_bricks({once.id: once.transform.translated(Vector3(0, 0, -20))})
	var at := Transform3D(Basis.IDENTITY, Vector3(0, 96 + lift, 0))
	var added: int = _world.add_brick("3005", 5, at)
	_builder.register(added, "3005", at)
	_world.get_brick(added).step = 2
	var model: PackedStringArray = _model()
	var saved: String = _store.to_text(_store.title, true)
	var changed: Array = _changed(FILE, saved)
	print("    out: %s\n    in:  %s" % ["\n         ".join(changed[0]),
		"\n         ".join(changed[1])])
	_expect(saved.contains("\n1 0 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"),
		"recoloured in place, the rest of its line as it was")
	_expect(saved.contains("\n1 14 -100 -8 0 1 0 0 0 1 0 0 0 1 30028.dat\n"),
		"the retired 30028 moved 20 LDU, still 30028, turned as the file had it")
	_expect(not saved.contains("1 1 0 0 60 1 0 0 0 1 0 0 0 1 3001.dat"), "the part taken away is gone")
	_expect(saved.contains("\n1 15 0 -24 20 1 0 0 0 1 0 0 0 1 3003.dat\n"),
		"moved in the sub-model placed once, in its own frame")
	_expect(saved.contains("1 5 0 -96 0 1 0 0 0 1 0 0 0 1 3005.dat\n0 STEP\n0 NOFILE"),
		"the part added at the end of its step, in the file's coordinates")
	_expect((changed[0] as Array).size() == 4 and (changed[1] as Array).size() == 4,
		"nothing else changed: 4 lines out (3 rewritten, 1 taken away), 4 in (3 rewritten, "
		+ "1 added): %d out, %d in" % [(changed[0] as Array).size(), (changed[1] as Array).size()])
	_open(saved)
	_expect(_model() == model, "opened again, the model as edited")


func _copies_apart() -> void:
	print("fidelity: one copy of two changed")
	_open(FILE)
	var mover: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3022" and brick.color_code == 25 and brick.unit.ends_with("#1"):
			mover = brick
	_expect(mover != null, "found a part of the first copy")
	if mover == null:
		return
	_builder.move_bricks({mover.id: mover.transform.translated(Vector3(0, 0, 20))})
	var model: PackedStringArray = _model()
	var saved: String = _store.to_text(_store.title, true)
	_expect(saved.contains("0 Author: Somebody Else [someone]") and saved.contains(
		"0 !LICENSE Redistributable under CCAL version 2.0"),
		"written whole, still under its author's name and licence")
	_expect(not saved.contains("0 Author: Brickworks"), "not claimed as Brickworks's")
	_expect(saved.contains("\n1 14 40 0 -60 1 0 0 0 1 0 0 0 1 nopart9x.dat\n"),
		"the part it could not show carried, where it was, in its colour")
	_expect(saved.contains("0 FILE fidelity - band-flex.dat") and saved.contains(
		"0 !LDCAD PATH_SKIN"), "the band carried as a part, its path with it")
	var again: Dictionary = _open(saved)
	_expect(_model() == model, "opened again, the model as edited, the band in it")
	_expect(again.get("unshown", {}) == {"nopart9x": 1},
		"and the part it cannot show still there, still said: %s" % again.get("unshown", {}))


func _named() -> void:
	print("fidelity: saved under a name of its own")
	_open(FILE)
	var name: String = "Fidelity probe %d" % (Time.get_ticks_usec() % 100000)
	_expect(_store.save_as(name), "saved as %s" % name)
	var path: String = ModelStore.saved_path(name)
	var text: String = FileAccess.get_file_as_string(path)
	_expect(text.begins_with("0 FILE fidelity - main.ldr\n"), "the file's first line its own")
	_world.clear()
	_store.open(path)
	_expect(_store.title == name, "opened under its name: %s" % _store.title)
	_expect(_differ(FILE, _store.to_text(_store.title, true)).is_empty(),
		"and saved again, still the author's file")
	DirAccess.remove_absolute(path)
	for version: ModelVersions.Version in ModelVersions.of(ModelStore._safe_name(name)):
		DirAccess.remove_absolute(version.path)


func _repository(path: String) -> void:
	print("fidelity: %s" % path.get_file())
	var text: String = FileAccess.get_file_as_string(path)
	var began: int = Time.get_ticks_msec()
	_open(text)
	var opened_ms: int = Time.get_ticks_msec() - began
	began = Time.get_ticks_msec()
	var saved: String = _store.to_text(_store.title, true)
	var save_ms: int = Time.get_ticks_msec() - began
	var differ: Array = _differ(text, saved)
	_expect(differ.is_empty(), "%s saved untouched is the same file (opened %d ms, saved %d ms)%s"
		% [path.get_file(), opened_ms, save_ms,
			"" if differ.is_empty() else ": " + "; ".join(differ.slice(0, 4))])
	# Made an assembly of one part: the file cannot say that as it is, so
	# the model is written whole. It must open as the same model: the parts
	# the file carries with what they are drawn from (3315-1 came back 28
	# LDU higher with 5 parts gone), in the file's coordinates.
	var model: PackedStringArray = _model()
	var first: BrickWorld.Brick = _world.bricks()[0]
	_builder.select_brick(first.id, false)
	_builder.name_group("Fidelity probe group")
	began = Time.get_ticks_msec()
	var whole: String = _store.to_text(_store.title, true)
	var whole_ms: int = Time.get_ticks_msec() - began
	_expect(_differ(text, whole).size() > 0, "an assembly made: written whole (%d ms)" % whole_ms)
	var unshown: Dictionary = _store.unshown.duplicate()
	_open(whole)
	var again: PackedStringArray = _model()
	var gone: int = 0
	for line: String in model:
		if not again.has(line):
			gone += 1
	_expect(again.size() == model.size(),
		"written whole, it opens with every part: %d of %d" % [again.size(), model.size()])
	# A part written whole goes through its sub-model's frame, to four
	# decimals, and a few come back either side of a tenth from where they
	# were (6 of 4,139 in 42082-1). Said, not failed, unless it is many.
	print("  note %d of %d parts not where they were, written whole" % [gone, model.size()])
	_expect(gone * 20 < model.size(), "...nearly all where they were (%d not)" % gone)
	_expect(_store.unshown == unshown, "and what it could not show still there: %s"
		% _store.unshown)
