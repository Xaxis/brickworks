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
## And a sub-model placed by nothing once its last copy is taken off keeps
## its block, as the file had it, however the save is written (F5): a patch,
## live's write (patches off), the copy taken apart, the model written whole
## (an assembly made: a sub-model emptied and filled again, its old block
## kept beside it and its copy's name kept at the next open; a block placed
## by nothing, and the sub-model it places that the model still has, kept as
## the file has them; a block placed by nothing called as a placed one
## renames none of its copies; one renamed is written once), a model with
## nothing left in it saved, opened (it was
## refused: "there are no parts in that file") and saved again; a sub-model
## the file never placed, written whole; and an undo brings the file back.
##
## And a sub-model placed three times, once mirrored, of parts that look the
## same turned a half (kt5check's twice_mirror): the mirrored copy moved,
## or the first taken off, the model is written whole, the mirrored copy by
## a matrix that reflects, and opens again with every part turned as it was
## (F2); the copies lie on each other mirrored, and a wedge put in the first
## goes into the mirrored one in its other hand. The last copy taken off a
## file the app saved takes its COPY line with it (F3). A CRLF file with no
## line break at its end, its last line painted, moved or taken off, or a
## part added, ends as it began: no bare CR (F4).
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

## kt5check's twice_mirror: a wing of a plate and a tile, each the same
## turned a half, placed three times, the second mirrored.
const MIRRORED := """0 FILE plane.ldr
0 Plane
0 Name: plane.ldr
0 Author: Tess Tester
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 -80 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr
1 16 80 -24 0 -1 0 0 0 1 0 0 0 1 wing.ldr
1 16 0 -48 0 1 0 0 0 1 0 0 0 1 wing.ldr
0 NOFILE
0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
0 Author: Tess Tester
1 15 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
1 16 20 -8 0 1 0 0 0 1 0 0 0 1 3023.dat
0 NOFILE
"""

## The file the app saves of twice_mirror with its second wing taken off
## (kt5check's live tm_del_w2): each copy's number on a line before it.
const NUMBERED := """0 FILE plane.ldr
0 Plane
0 Name: plane.ldr
0 Author: Tess Tester
0 !BRICKWORKS FLOOR GRID

0 !BRICKWORKS COPY 1
1 16 0 24 0 1 0 0 0 1 0 0 0 1 wing.ldr
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 !BRICKWORKS COPY 3
1 16 80 0 0 1 0 0 0 1 0 0 0 1 wing.ldr
1 14 0 -72 0 1 0 0 0 1 0 0 0 1 3003.dat
0
0 NOFILE
0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
0 Author: Tess Tester

1 15 -80 -48 0 1 0 0 0 1 0 0 0 1 3020.dat
1 0 -60 -56 0 1 0 0 0 1 0 0 0 1 3023b.dat
0
0 NOFILE
"""

## A pod placing a fin, and a fin of its own beside it: the pod taken off,
## its block placed by nothing names a sub-model the model still has.
const NESTED := """0 FILE rig - main.ldr
0 Rig
0 Name: rig - main.ldr
0 Author: Somebody Else [someone]
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 rig - pod.ldr
1 16 100 0 0 1 0 0 0 1 0 0 0 1 rig - fin.ldr
0 NOFILE
0 FILE rig - pod.ldr
0 Pod
0 Name: rig - pod.ldr
0 Author: Somebody Else [someone]
1 1 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 rig - fin.ldr
0 NOFILE
0 FILE rig - fin.ldr
0 Fin
0 Name: rig - fin.ldr
0 Author: Somebody Else [someone]
1 14 0 0 0 1 0 0 0 1 0 0 0 1 3022.dat
0 NOFILE
"""

## A CRLF file whose last line has no line break after it (kt5check's
## crlf_tabs, cut down).
const CRLF_LINES := ["0 Engine", "0 Name: engine.ldr", "0 Author: Somebody Else",
	"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
	"1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3020.dat", "1 14 0 -48 0 1 0 0 0 1 0 0 0 1 3020.dat"]


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
	_emptied()
	_unplaced_kept()
	_copies_apart()
	_mirrored_copy()
	_copy_line_goes()
	_crlf_end()
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


## Every part of the sub-model placed once taken away: the line placing it
## goes, and nothing else changes. It used to stay in the file, empty and
## still placed; then its block went with it (keeptext4), until kt4review:
## a sub-model's block is kept, placed by nothing, as Ungroup, LDCad and
## Studio keep it. Placed by nothing, it is no part of the model.
func _emptied() -> void:
	print("fidelity: a sub-model emptied")
	_open(FILE)
	var gone: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3003":
			gone.append(brick.id)
	_expect(gone.size() == 2, "found the sub-model's two parts (%d)" % gone.size())
	for id: int in gone:
		_builder.remove_brick_id(id)
	var model: PackedStringArray = _model()
	var saved: String = _store.to_text(_store.title, true)
	var changed: Array = _changed(FILE, saved)
	_expect(not saved.contains("1 16 0 -48 0 1 0 0 0 1 0 0 0 1 fidelity - once.ldr"),
		"the line placing it is gone")
	_expect(saved.contains(FILE.substr(FILE.find("0 FILE fidelity - once.ldr"),
		FILE.find("0 FILE fidelity - twice.ldr") - FILE.find("0 FILE fidelity - once.ldr"))),
		"its block kept whole, placed by nothing, the other sub-models after it")
	_expect((changed[0] as Array) == ["1 16 0 -48 0 1 0 0 0 1 0 0 0 1 fidelity - once.ldr"]
		and (changed[1] as Array).size() == 0,
		"nothing else changed: the placing line out, none in: "
		+ "%d out, %d in" % [(changed[0] as Array).size(), (changed[1] as Array).size()])
	_open(saved)
	_expect(_model() == model, "opened again, the model as edited")


## The once sub-model's block as the file has it, from its FILE line to its
## NOFILE.
static func _once_block() -> String:
	var from: int = FILE.find("0 FILE fidelity - once.ldr")
	return FILE.substr(from, FILE.find("0 NOFILE", from) + 8 - from)


## How many lines of [param text] place [param file].
static func _placing(text: String, file: String) -> int:
	var count: int = 0
	for line: String in text.split("\n"):
		var words: PackedStringArray = line.strip_edges().split(" ", false)
		if words.size() >= 15 and words[0] == "1" and line.strip_edges().ends_with(" " + file):
			count += 1
	return count


## Each part's copy, sorted.
func _units() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append("%s %s" % [brick.part_id, Assemblies.path_of(brick)])
	out.sort()
	return out


func _ids_of(part_id: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part_id:
			out.append(brick.id)
	return out


func _unplaced_kept() -> void:
	print("fidelity: a sub-model placed by nothing keeps its block")
	var block: String = _once_block()
	# Live's write: the patch off, as when it cannot be one.
	ModelStore.patch_files = false
	_open(FILE)
	for id: int in _ids_of("3003"):
		_builder.remove_brick_id(id)
	var model: PackedStringArray = _model()
	var saved: String = _store.to_text(_store.title, true)
	ModelStore.patch_files = true
	_expect(saved.contains(block) and _placing(saved, "fidelity - once.ldr") == 0,
		"live's write: the block kept whole, nothing placing it (%d placing)"
		% _placing(saved, "fidelity - once.ldr"))
	_open(saved)
	_expect(_model() == model, "...opened again, the model as edited")
	# Taken apart: its parts loose in the model, the block placed by nothing.
	_open(FILE)
	var tree := Assemblies.new()
	tree.world = _world
	tree.builder = _builder
	tree.library = _library
	tree.scenery = _store.scenery
	var apart: int = tree.ungroup("Once#1")
	model = _model()
	saved = _store.to_text(_store.title, true)
	_expect(apart == 2 and saved.contains(block) and _placing(saved, "fidelity - once.ldr") == 0,
		"the copy taken apart (%d parts): the block kept whole, nothing placing it (%s)"
		% [apart, str(_store.get("last_whole"))])
	_open(saved)
	_expect(_model() == model, "...opened again, its parts where they were")
	# Written whole: the copy's parts taken off, and an assembly made.
	_open(FILE)
	for id: int in _ids_of("3003"):
		_builder.remove_brick_id(id)
	_builder.select_brick(_brick("3001", 4).id, false)
	_builder.name_group("Fidelity probe group")
	model = _model()
	saved = _store.to_text(_store.title, true)
	_expect(saved.contains(block) and _placing(saved, "fidelity - once.ldr") == 0,
		"written whole: the block kept as the file had it, nothing placing it (%s)"
		% str(_store.get("last_whole")))
	_expect(not saved.contains("0 FILE fidelity - twice.ldr")
		and not saved.contains("0 FILE fidelity - band.ldr"),
		"...and no section the model still places written twice")
	_open(saved)
	_expect(_model() == model, "...opened again, the model as edited")
	# Emptied and filled again: the model's Once written, the file's block
	# beside it placed by nothing, and the copy still Once#1 at the next open.
	_open(FILE)
	var refilled: Array = _ids_of("3003")
	var at := Transform3D(Basis.IDENTITY, (_world.get_brick(refilled[0]) as BrickWorld.Brick)
		.transform.origin + Vector3(0, -24, 0))
	var added: int = _world.add_brick("3005", 5, at)
	_builder.register(added, "3005", at)
	_world.get_brick(added).unit = "Once#1"
	for id: int in refilled:
		_builder.remove_brick_id(id)
	_builder.select_brick(_brick("3001", 4).id, false)
	_builder.name_group("Fidelity probe group")
	model = _model()
	var units: Array = _units()
	saved = _store.to_text(_store.title, true)
	_expect(saved.contains(block) and _placing(saved, "fidelity - once.ldr") == 0
		and saved.count("\n0 Once\n") == 2,
		"emptied and filled again, written whole: the file's block kept, placed by nothing, beside the model's (%d called Once)"
		% saved.count("\n0 Once\n"))
	_open(saved)
	_expect(_model() == model and _units() == units,
		"...opened again, the model and its copies as edited (%s; edited %s)"
		% [", ".join(_units()), ", ".join(units)])
	# The pod taken off, the model written whole: its block as the file has
	# it, and the fin's it places, beside the model's own fin.
	_open(NESTED)
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.unit.begins_with("Pod#1"):
			_builder.remove_brick_id(brick.id)
	_builder.select_brick(_brick("3001", 4).id, false)
	_builder.name_group("Fidelity probe group")
	model = _model()
	units = _units()
	saved = _store.to_text(_store.title, true)
	var pod_block: String = NESTED.substr(NESTED.find("0 FILE rig - pod.ldr"),
		NESTED.find("0 FILE rig - fin.ldr") - NESTED.find("0 FILE rig - pod.ldr"))
	var fin_block: String = NESTED.substr(NESTED.find("0 FILE rig - fin.ldr"))
	_expect(saved.contains(pod_block) and saved.contains(fin_block)
		and saved.count("\n0 Fin\n") == 2,
		"the pod taken off, written whole: its block and the fin's it places kept as the file has them, beside the model's fin (%d called Fin)"
		% saved.count("\n0 Fin\n"))
	_open(saved)
	_expect(_model() == model and _units() == units,
		"...opened again, the model and its copies as edited (%s; edited %s%s)" % [
			", ".join(_units()), ", ".join(units),
			"" if _model() == model else "; parts %s, edited %s" % [_model(), model]])
	# A sub-model the file never placed, the model written whole.
	var spare: String = "0 FILE spare.ldr\n0 Spare\n0 Name: spare.ldr\n" \
		+ "1 7 0 0 0 1 0 0 0 1 0 0 0 1 3004.dat\n0 NOFILE"
	_open(FILE + spare + "\n")
	_builder.select_brick(_brick("3001", 4).id, false)
	_builder.name_group("Fidelity probe group")
	saved = _store.to_text(_store.title, true)
	_expect(saved.contains(spare), "a sub-model the file never placed, written whole: kept (%s)"
		% str(_store.get("last_whole")))
	# Renamed, the model written whole: the sub-model's parts are the file's
	# still, so its block is not carried beside the model's.
	_open(FILE)
	tree = Assemblies.new()
	tree.world = _world
	tree.builder = _builder
	tree.library = _library
	tree.scenery = _store.scenery
	var renamed: String = tree.rename("Once#1", "Uno")
	_builder.select_brick(_brick("3001", 4).id, false)
	_builder.name_group("Fidelity probe group")
	model = _model()
	saved = _store.to_text(_store.title, true)
	_expect(renamed == "Uno" and not saved.contains("0 FILE fidelity - once.ldr")
		and saved.count(" 3003.dat\n") == 2,
		"renamed %s, written whole: written once, under its new name (%d lines of 3003)"
		% [renamed, saved.count(" 3003.dat\n")])
	_open(saved)
	_expect(_model() == model, "...opened again, the model as edited")
	# A block placed by nothing titled as a sub-model the model places: the
	# copies keep their names. Two of one title were told apart by file
	# name, placed or not, and the copies opened as "Twice (fidelity -
	# twice)#1".
	_open(FILE + "0 FILE spare twice.ldr\n0 Twice\n0 Name: spare twice.ldr\n"
		+ "1 7 0 0 0 1 0 0 0 1 0 0 0 1 3004.dat\n0 NOFILE\n")
	var twice: Array = _units().filter(func(unit: String) -> bool:
		return unit.begins_with("3022 "))
	_expect(twice == ["3022 Twice#1", "3022 Twice#1", "3022 Twice#2", "3022 Twice#2"],
		"a block placed by nothing called Twice too: the copies still Twice#1 and Twice#2 (%s)"
		% ", ".join(twice))
	# The model's one sub-model taken off: nothing left in it, saved, opened
	# and saved again, the sub-model still there.
	var only: String = "\n".join(["0 FILE solo - main.ldr", "0 Solo", "0 Name: solo - main.ldr",
		"0 Author: Somebody Else [someone]", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 solo - car.ldr",
		"0 NOFILE", "0 FILE solo - car.ldr", "0 Car", "0 Name: solo - car.ldr",
		"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat",
		"0 NOFILE", ""])
	var car: String = only.substr(only.find("0 FILE solo - car.ldr"),
		only.rfind("0 NOFILE") + 8 - only.find("0 FILE solo - car.ldr"))
	_open(only)
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			_builder.remove_brick_id(brick.id)
	saved = _store.to_text(_store.title, true)
	_expect(saved.contains(car) and _placing(saved, "solo - car.ldr") == 0,
		"the only sub-model taken off: its block kept, nothing placing it (%d placing)"
		% _placing(saved, "solo - car.ldr"))
	var opened: Dictionary = _open(saved)
	var again: String = _store.to_text(_store.title, true)
	_expect(str(opened.get("error", "")).is_empty() and _model().is_empty()
		and again.contains(car) and _placing(again, "solo - car.ldr") == 0
		and again.contains("0 Author: Somebody Else [someone]"),
		"...opened again: an empty model (%d parts; %s), saved again still theirs, the block kept"
		% [_model().size(), "opened" if str(opened.get("error", "")).is_empty() else str(opened["error"])])
	# Undone: the file again, the block and its line as they were.
	_open(FILE)
	var depth: int = _builder.history_depth()
	for id: int in _ids_of("3003"):
		_builder.remove_brick_id(id)
	while _builder.history_depth() > depth:
		_builder.undo()
	var differ: Array = _differ(FILE, _store.to_text(_store.title, true))
	_expect(differ.is_empty(), "the copy taken off and undone: the file again%s"
		% ("" if differ.is_empty() else ": " + "; ".join(differ.slice(0, 3))))


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


## What the app holds, each part turned too: "part colour copy at x y z,
## its three axes", sorted, off the ground as the file has it.
func _placed() -> PackedStringArray:
	var lift: Vector3 = _store.lift()
	var out := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var place := PackedStringArray()
		for v: Vector3 in [brick.transform.origin - lift, brick.transform.basis.x,
				brick.transform.basis.y, brick.transform.basis.z]:
			for n: float in [v.x, v.y, v.z]:
				place.append("%.2f" % (snappedf(n, 0.01) + 0.0))
		out.append("%s %d %s at %s" % [brick.part_id, brick.color_code,
			Assemblies.path_of(brick), " ".join(place)])
	out.sort()
	return out


## The determinant of each line of [param text] placing [param file].
static func _turns_of(text: String, file: String) -> Array:
	var out: Array = []
	for line: String in text.split("\n"):
		var words: PackedStringArray = line.strip_edges().split(" ", false)
		if words.size() == 15 and words[0] == "1" and words[14] == file:
			var m: Array = []
			for k: int in range(5, 14):
				m.append(words[k].to_float())
			out.append(snappedf(Basis(Vector3(m[0], m[3], m[6]), Vector3(m[1], m[4], m[7]),
				Vector3(m[2], m[5], m[8])).determinant(), 0.001))
	return out


func _of_unit(unit: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.unit == unit:
			out.append(brick)
	return out


func _mirrored_copy() -> void:
	print("fidelity: a mirrored copy of parts the same turned a half")
	for taken_off: bool in [false, true]:
		_open(MIRRORED)
		var mirrored: Array = _of_unit("Wing#2")
		var first: Array = _of_unit("Wing#1")
		_expect(mirrored.size() == 2 and first.size() == 2,
			"found the wings (%d, %d parts)" % [first.size(), mirrored.size()])
		if mirrored.size() != 2 or first.size() != 2:
			return
		if taken_off:
			for brick: BrickWorld.Brick in first:
				_builder.remove_brick_id(brick.id)
		else:
			var moves: Dictionary = {}
			for brick: BrickWorld.Brick in mirrored:
				moves[brick.id] = brick.transform.translated(Vector3(0, 0, 20))
			_builder.move_bricks(moves)
		var held: PackedStringArray = _placed()
		var saved: String = _store.to_text(_store.title, true)
		var turns: Array = _turns_of(saved, "wing.ldr")
		var what: String = "the first wing taken off" if taken_off else "the mirrored wing moved"
		_expect(turns.count(-1.0) == 1 and turns.count(1.0) == turns.size() - 1,
			"%s: written whole, the mirrored copy by a matrix that reflects (%s)"
			% [what, str(turns)])
		_open(saved)
		var again: PackedStringArray = _placed()
		var off: Array = []
		for line: String in held:
			if not again.has(line):
				off.append(line)
		_expect(off.is_empty() and again.size() == held.size(),
			"...and opens again with every part turned as it was: %d of %d not %s"
			% [off.size(), held.size(), str(off.slice(0, 2))])
	# The copies as a matcher lays one on another (Assemblies.best_match),
	# and a part put in the first followed into the mirrored one.
	_open(MIRRORED)
	var tree := Assemblies.new()
	tree.world = _world
	tree.builder = _builder
	tree.library = _library
	tree.scenery = _store.scenery
	var fit: Dictionary = tree.best_match(tree.content("Wing#1"), tree.content("Wing#2"))
	_expect(bool(fit["exact"]) and bool(fit["mirrored"]),
		"the mirrored wing lies on the first mirrored, not turned (exact %s, mirrored %s)"
		% [fit["exact"], fit["mirrored"]])
	var wedge: String = _library.resolve("41769")
	var other: String = Mirror.counterpart(_library, wedge)
	var plate: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _of_unit("Wing#1"):
		if brick.part_id == "3020":
			plate = brick
	if plate == null or other.is_empty():
		_expect(false, "found the first wing's plate and the wedge's other hand (%s)" % other)
		return
	var at: Transform3D = plate.transform.translated(Vector3(0, 8, 0))
	var added: int = _world.add_brick(wedge, 4, at)
	_builder.register(added, wedge, at)
	_world.get_brick(added).unit = "Wing#1"
	_world.get_brick(added).group = "Wing"
	tree.copies_follow({"Wing#1": true})
	var parts: Array = _of_unit("Wing#2").map(func(brick: BrickWorld.Brick) -> String:
		return brick.part_id)
	_expect(parts.has(other) and not parts.has(wedge),
		"a wedge put in the first wing goes into the mirrored one in its other hand (%s)"
		% str(parts))


## The last copy of a sub-model taken off a file the app saved: its line
## goes, and the line before it saying which copy it was goes with it.
func _copy_line_goes() -> void:
	print("fidelity: the last copy taken off a file the app saved")
	_open(NUMBERED)
	var last: Array = _of_unit("Wing#3")
	_expect(last.size() == 2, "found the last wing (%d parts)" % last.size())
	for brick: BrickWorld.Brick in last:
		_builder.remove_brick_id(brick.id)
	var saved: String = _store.to_text(_store.title, true)
	var whole: String = str(_store.get("last_whole"))
	_expect(not saved.contains("1 16 80 0 0 1 0 0 0 1 0 0 0 1 wing.ldr"), "its line is gone")
	_expect(not saved.contains("0 !BRICKWORKS COPY 3"),
		"...and the line saying which copy it was (written %s)"
		% ("as a patch" if whole.is_empty() else "whole: " + whole))
	_expect(saved.contains("0 !BRICKWORKS COPY 1\n1 16 0 24 0 1 0 0 0 1 0 0 0 1 wing.ldr"),
		"the first copy's number still on the line before it")


## A CRLF file with no line break at its end, saved after an edit to its
## last line or past it: every line but the last ends in CR LF, the last in
## nothing, as the file did.
func _crlf_end() -> void:
	print("fidelity: a CRLF file with no line break at its end")
	var file: String = "\r\n".join(PackedStringArray(CRLF_LINES))
	for edit: String in ["painted", "moved", "taken off", "added after"]:
		_open(file)
		var last: BrickWorld.Brick = _brick("3020", 14)
		if last == null:
			_expect(false, "found the file's last part")
			return
		match edit:
			"painted":
				_builder.paint_brick(last.id, 4)
			"moved":
				_builder.move_bricks({last.id: last.transform.translated(Vector3(20, 0, 0))})
			"taken off":
				_builder.remove_brick_id(last.id)
			"added after":
				var at: Transform3D = last.transform.translated(Vector3(0, 24, 0))
				var added: int = _world.add_brick("3005", 5, at)
				_builder.register(added, "3005", at)
		var saved: String = _store.to_text(_store.title, true)
		var whole: String = str(_store.get("last_whole"))
		var lines: PackedStringArray = saved.split("\n")
		var bare: int = 0
		for n: int in lines.size() - 1:
			if not lines[n].ends_with("\r"):
				bare += 1
		var tail: String = lines[lines.size() - 1]
		_expect(whole.is_empty() and bare == 0 and not tail.ends_with("\r") and not tail.is_empty(),
			"its last line %s: written as a patch (%s), every line but the last in CR LF (%d not), "
			% [edit, "yes" if whole.is_empty() else whole, bare]
			+ "the last with no end (%s)" % tail.c_escape().right(24))


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
