## im3check: an independent attack on intomodel3 (cb0a578e9). A model put
## into another, edited, saved, reopened and saved again; each case prints
## what the reopened file has and checks the invariant: the host's parts as
## the host opened alone and saved has them, the brought model's parts as it
## opened alone and saved has them (one rigid shift), in their sub-models and
## steps; no two sections of one name; the second save byte-identical.
##
##   godot --headless --path . --script src/dev/ic3_probe.gd [-- case,case]
##
## In the suite (tools/suite/headless.txt) with the cases intomodel3 answers
## for. Of the rest: mirror's mirrored copy is the app's own way with one
## (written as a copy of its own), same_name compares with a plain save of
## Roof it never makes, lodge_nested and lodge_ungroup are written whole and
## say so, and selfclash_edit is the base's (im3check items 5 and 6).
## intomodel3 added: delete_undo's file kept as it was and its steps as they
## were; motions_own, the observatory into a model of the app's own; and
## each of the bring's words about the motions.
extends SceneTree

const CAR := "res://models/car.ldr"
const OBS := "res://tests/fixtures/mcpwalk3/small-observatory.ldr"
const NESTED := "res://tests/fixtures/steps/nested_own.ldr"

## Someone's shed, in steps, with a step name, a ROTSTEP, header lines, a
## comment, and a part in each section the library has not got.
const SHED := """0 FILE shed.ldr
0 Shed
0 Name: shed.ldr
0 Author: A. Builder
0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt
0 // the shed's own note
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -48 0 1 0 0 0 1 0 0 0 1 zz9001.dat
0 !BRICKWORKS STEP_NAME Lay the floor
0 STEP
1 16 80 -24 0 1 0 0 0 1 0 0 0 1 roof.ldr
0 ROTSTEP 30 45 0 ABS
0 NOFILE
0 FILE roof.ldr
0 Roof
0 Name: roof.ldr
0 Author: A. Builder
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 zz9002.dat
0 STEP
0 NOFILE
"""

## All parts shown, no steps.
const PANE := """0 FILE pane.ldr
0 Pane
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 14 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"""

## Someone else's lodge, no steps: a top-level part the library has not
## got, a sub-model, comments and meta lines a source write keeps.
const LODGE := """0 FILE lodge.ldr
0 Lodge
0 Name: lodge.ldr
0 Author: A. Host
0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt
0 !HISTORY 2020-01-01 [host] first
0 // the lodge's own note
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 40 -48 0 1 0 0 0 1 0 0 0 1 zz9004.dat
1 0 0 -24 80 1 0 0 0 1 0 0 0 1 window.ldr
0 NOFILE
0 FILE window.ldr
0 Frame
0 Name: window.ldr
0 Author: A. Host
0 // a note in the frame
1 1 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 zz9003.dat
0 NOFILE
"""

## The app's own model with sub-models Roof and Roof 2 (roof_2.ldr).
const CLASHHOST := """0 FILE clashhost.ldr
0 Clash Host
0 Name: clashhost.ldr
0 Author: Brickworks
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 16 0 -24 80 1 0 0 0 1 0 0 0 1 roof.ldr
0 STEP
1 16 0 -24 160 1 0 0 0 1 0 0 0 1 roof_2.ldr
0 STEP
0 NOFILE
0 FILE roof.ldr
0 Roof
0 Name: roof.ldr
0 Author: Brickworks
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
0 NOFILE
0 FILE roof_2.ldr
0 Roof 2
0 Name: roof_2.ldr
0 Author: Brickworks
1 5 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
0 NOFILE
"""

## Someone else's model whose sub-models are called Roof and Roof 2 too.
const CLASHER := """0 FILE clasher.ldr
0 Clasher
0 Name: clasher.ldr
0 Author: B. Other
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -48 0 1 0 0 0 1 0 0 0 1 roof.ldr
1 16 0 -72 0 1 0 0 0 1 0 0 0 1 roof 2.ldr
0 STEP
0 NOFILE
0 FILE roof.ldr
0 Roof
0 Name: roof.ldr
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 zz9002.dat
0 NOFILE
0 FILE roof 2.ldr
0 Roof 2
0 Name: roof 2.ldr
1 3 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
0 NOFILE
"""

## A model with a sub-model called as the model itself is.
const TOWER := """0 FILE tower.ldr
0 Tower
0 Name: tower.ldr
0 Author: T. Maker
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -48 0 1 0 0 0 1 0 0 0 1 top.ldr
0 NOFILE
0 FILE top.ldr
0 Tower
0 Name: top.ldr
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3005.dat
0 NOFILE
"""

## The app's own model with two copies of Roof.
const HOME2 := """0 FILE home2.ldr
0 Home Two
0 Name: home2.ldr
0 Author: Brickworks
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 roof.ldr
1 16 200 -24 0 1 0 0 0 1 0 0 0 1 roof.ldr
0 STEP
0 NOFILE
0 FILE roof.ldr
0 Roof
0 Name: roof.ldr
0 Author: Brickworks
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
0 NOFILE
"""

## Someone else's model carrying its own oddpart.dat the app cannot build.
const LAB := """0 FILE lab.ldr
0 Lab
0 Name: lab.ldr
0 Author: A. Host
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -48 0 1 0 0 0 1 0 0 0 1 oddpart.dat
0 NOFILE
0 FILE oddpart.dat
0 The lab's own odd part
0 Name: oddpart.dat
0 Author: A. Host
0 !LDRAW_ORG Unofficial_Part
1 16 0 0 0 1 0 0 0 1 0 0 0 1 hostprim.dat
0 NOFILE
"""

## The app's own model placing an oddpart.dat it does not carry.
const REF := """0 FILE ref.ldr
0 Ref
0 Name: ref.ldr
0 Author: Brickworks
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 40 -24 0 1 0 0 0 1 0 0 0 1 oddpart.dat
0 STEP
0 NOFILE
"""

## A model with a mirrored copy of a sub-model and a mirrored part.
const MIRROR := """0 FILE mirror.ldr
0 Mirror
0 Name: mirror.ldr
0 Author: M. Maker
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 100 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr
1 16 -100 -24 0 -1 0 0 0 1 0 0 0 1 wing.ldr
1 7 0 -24 60 -1 0 0 0 1 0 0 0 1 3040.dat
0 STEP
0 NOFILE
0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3040.dat
1 1 20 0 0 1 0 0 0 1 0 0 0 1 43722.dat
0 NOFILE
"""

## Another model whose file is car.ldr, as the car's is called.
const OTHERCAR := """0 FILE car.ldr
0 Car
0 Name: car.ldr
0 Author: O. Other
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 14 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"""

## The app's own model, its author's steps.
const OWNSTEPS := """0 FILE ownsteps.ldr
0 Own Steps
0 Name: ownsteps.ldr
0 Author: Brickworks
0 !BRICKWORKS AUTHORED_STEPS
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
0 NOFILE
"""

## Another model called Car, with no FILE line.
const PLAINCAR := """0 Car
0 Name: car.ldr
0 Author: P. Plain
1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat
"""

## Someone's model whose file is clashhost.ldr, as Clash Host's is.
const OWNNAME := """0 FILE clashhost.ldr
0 Clash Host
0 Name: clashhost.ldr
0 Author: O. Other
1 3 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"""

## The app's own model called Car, one model, no FILE line.
const OWNCAR := """0 Car
0 Name: car.ldr
0 Author: Brickworks
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 40 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
"""

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _library: PartLibrary
var _store: ModelStore
var _bar: ModelBar
var _shell: Shell
var _socket: Variant
var _rpc_id: int = 0
var _only: PackedStringArray = PackedStringArray()
var _out: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ic3dir="):
			_out = arg.substr(9)
		else:
			_only = arg.split(",", false)
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_store = _main.get("_store")
	_bar = _main.get("_bar")
	_shell = _main.get("_shell")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	_store.keeps = false
	CustomParts.dir = OS.get_user_data_dir().path_join("ic3_parts/")
	CustomParts.keeps = false
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
	for pair: Array in [["Shed", SHED], ["Pane", PANE], ["Lodge", LODGE], ["Clash Host", CLASHHOST],
			["Clasher", CLASHER], ["Tower", TOWER], ["Home Two", HOME2], ["Lab", LAB], ["Ref", REF],
			["Mirror", MIRROR], ["Car", _file(CAR)], ["Observatory", _file(OBS)],
			["Nested", _file(NESTED)], ["Other Car", OTHERCAR], ["Plain Car", PLAINCAR],
			["Own Name", OWNNAME], ["Own Car", OWNCAR], ["Own Steps", OWNSTEPS]]:
		_keep(pair[0], pair[1])
	await _make_plains()
	for case: String in ["twice", "clash", "selfclash", "nested2", "flat", "lodge_edits",
			"lodge_twice", "undo_redo", "pattern", "motions", "mirror", "leak", "delete_undo",
			"lodge_nested", "lodge_ungroup", "menu", "nested_own", "same_name", "self_car", "self_lodge",
			"lodge_save_edit", "carname", "carname_plain", "ownname", "selfclash_edit", "owncar",
			"motions_own"]:
		if not _only.is_empty() and not _only.has(case):
			continue
		await call("_case_" + case)
	print("")
	print("ic3: %s" % ("all held" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- cases -------------------------------------------------------------------


## The shed brought twice into the car (a session's open_model into=true).
func _case_twice() -> void:
	print("\ntwice: the shed into the car twice")
	await _open_saved("Car")
	var tops: Array = _tops()
	for _n: int in 2:
		print("    MCP: " + (await _say("open_model", {"into": true, "name": "Shed"})).left(260))
	print("    tops now %s, held %s" % [_tops(), _held()])
	var texts: Array = await _save_twice("ic3 twice")
	await _invariant("twice", "Car", ["Shed", "Shed"], texts[0], tops)
	_same_again("twice", texts)


## The clasher (Roof, Roof 2) into the clash host (Roof, Roof 2 in roof_2.ldr).
func _case_clash() -> void:
	print("\nclash: Clasher (its Roof and Roof 2) into Clash Host (its Roof and Roof 2)")
	await _open_saved("Clash Host")
	var tops: Array = _tops()
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Clasher"})).left(300))
	var texts: Array = await _save_twice("ic3 clash")
	await _invariant("clash", "Clash Host", ["Clasher"], texts[0], tops)
	_same_again("clash", texts)


## Tower, whose sub-model is called Tower as the model is, into the car.
func _case_selfclash() -> void:
	print("\nselfclash: Tower (its sub-model called Tower) into the car")
	await _open_saved("Car")
	var tops: Array = _tops()
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Tower"})).left(300))
	print("    paths now %s" % [_paths()])
	var texts: Array = await _save_twice("ic3 selfclash")
	await _invariant("selfclash", "Car", ["Tower"], texts[0], tops)
	_same_again("selfclash", texts)


## The shed into Roof#1 of Home Two, which has two copies of Roof.
func _case_nested2() -> void:
	print("\nnested2: the shed into Roof#1 of Home Two (two copies of Roof)")
	await _open_saved("Home Two")
	var roof: String = _path_to("Roof", 1)
	_shell.assemblies.enter(roof)
	await _frames(2)
	print("    entered %s; MCP: %s" % [roof, (await _say("open_model", {"into": true, "name": "Shed"})).left(260)])
	_shell.assemblies.enter("")
	await _frames(4)
	print("    paths now %s; held %s" % [_paths(), _held()])
	var texts: Array = await _save_twice("ic3 nested2")
	var counts: Dictionary = _counts(texts[0])
	var want: Dictionary = _counts(_plain_save("Home Two"))
	for key: String in _counts(_plain_save("Shed")):
		want[key] = int(want.get(key, 0)) + 2 * int(_counts(_plain_save("Shed"))[key])
	_check("nested2: Home Two + the shed in each copy of Roof (%s)" % _difference(want, counts),
		counts == want)
	var trees: Dictionary = _trees(texts[0])
	print("    trees: %s" % trees)
	_unique_files("nested2", texts[0])
	_same_again("nested2", texts)


## The stepped shed into the lodge, someone else's file with no steps.
func _case_flat() -> void:
	print("\nflat: the stepped shed into the lodge (someone else's, no steps)")
	await _open_saved("Lodge")
	var tops: Array = _tops()
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Shed"})).left(260))
	var texts: Array = await _save_twice("ic3 flat")
	_lost("flat", LODGE, texts[0], true)
	await _invariant("flat", "Lodge", ["Shed"], texts[0], tops)
	_same_again("flat", texts)


## The shed into the lodge; moved, renamed, undone, redone, copied and pasted.
func _case_lodge_edits() -> void:
	print("\nlodge_edits: the shed into the lodge, moved, renamed Barn, undo, redo, copied, pasted")
	await _open_saved("Lodge")
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Shed"})).left(200))
	var shed: String = _path_to("Shed", 1)
	_select(_under(shed))
	_main.call("_nudge_by", Vector3i(4, 0, 0))
	await _frames(4)
	var named: String = _shell.assemblies.rename(shed, "Barn")
	_edited()
	await _frames(4)
	print("    renamed %s -> %s; held %s" % [shed, named, _held()])
	await _undo()
	await _frames(2)
	print("    undone: paths %s; held %s" % [_paths(), _held()])
	await _redo()
	await _frames(2)
	print("    redone: paths %s; held %s" % [_paths(), _held()])
	var barn: String = _path_to("Barn", 1)
	_select(_under(barn))
	_builder.copy_selection()
	_builder.hold_copy(Carry.clipboard)
	print("    pasted: %s; paths %s; held %s" % [await _put_beside(), _paths(), _held()])
	var texts: Array = await _save_twice("ic3 lodge edits")
	_lost("lodge_edits", LODGE, texts[0], true)
	var want: Dictionary = _counts(_plain_save("Lodge"))
	for key: String in _counts(_plain_save("Shed")):
		want[key] = int(want.get(key, 0)) + 2 * int(_counts(_plain_save("Shed"))[key])
	_check("lodge_edits: the lodge + two sheds (%s)" % _difference(want, _counts(texts[0])),
		_counts(texts[0]) == want)
	print("    trees: %s" % _trees(texts[0]))
	_offsets("lodge_edits", texts[0])
	_unique_files("lodge_edits", texts[0])
	_same_again("lodge_edits", texts)


## The shed, then the pane, then the shed again into the lodge.
func _case_lodge_twice() -> void:
	print("\nlodge_twice: shed, pane, shed into the lodge")
	await _open_saved("Lodge")
	var tops: Array = _tops()
	for which: String in ["Shed", "Pane", "Shed"]:
		print("    MCP: " + (await _say("open_model", {"into": true, "name": which})).left(160))
	var texts: Array = await _save_twice("ic3 lodge twice")
	_lost("lodge_twice", LODGE, texts[0], true)
	await _invariant("lodge_twice", "Lodge", ["Shed", "Pane", "Shed"], texts[0], tops)
	_same_again("lodge_twice", texts)


## The shed into the car; undone, then redone; saved.
func _case_undo_redo() -> void:
	print("\nundo_redo: the shed into the car, undo, redo, undo, redo")
	await _open_saved("Car")
	var tops: Array = _tops()
	var plain: Dictionary = _counts(_plain_save("Car"))
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Shed"})).left(160))
	var held_in: Array = _held()
	await _undo()
	await _frames(2)
	_check("undo_redo: one undo leaves the car (%d parts, held %s)" % [_model().size(), _held()],
		_held().is_empty() and _paths().size() == tops.size())
	var mid: Array = await _save_twice("ic3 undo")
	_check("undo_redo: saved after undo, the car's parts (%s)" % _difference(plain, _counts(mid[0])),
		_counts(mid[0]) == plain)
	await _open_saved("Car")
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Shed"})).left(100))
	await _undo()
	await _frames(2)
	await _redo()
	await _frames(2)
	await _undo()
	await _frames(2)
	await _redo()
	await _frames(2)
	_check("undo_redo: redone, held as brought (%s / %s)" % [_held(), held_in], _held().size() == held_in.size())
	var texts: Array = await _save_twice("ic3 redo")
	await _invariant("undo_redo", "Car", ["Shed"], texts[0], tops)
	_same_again("undo_redo", texts)


## The shed into the car, Pattern'd into three.
func _case_pattern() -> void:
	print("\npattern: the shed into the car, patterned three in a row")
	await _open_saved("Car")
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Shed"})).left(100))
	var ids: Array = _under(_path_to("Shed", 1))
	print("    pattern: " + (await _say("pattern_parts", {"bricks": ids, "columns": 3,
		"column_studs": 12, "picture": false})).left(260))
	print("    paths now %s; held %s" % [_paths(), _held()])
	var texts: Array = await _save_twice("ic3 pattern")
	var want: Dictionary = _counts(_plain_save("Car"))
	var shed: Dictionary = _counts(_plain_save("Shed"))
	for key: String in shed:
		want[key] = int(want.get(key, 0)) + 3 * int(shed[key])
	_check("pattern: the car + three sheds (%s)" % _difference(want, _counts(texts[0])),
		_counts(texts[0]) == want)
	_offsets("pattern", texts[0])
	_unique_files("pattern", texts[0])
	_same_again("pattern", texts)


## The observatory (motions, a floor) into the car: its motions?
func _case_motions() -> void:
	print("\nmotions: the small observatory (motions) into the car")
	await _open_saved("Car")
	var tops: Array = _tops()
	var said: String = await _say("open_model", {"into": true, "name": "Observatory"})
	print("    MCP: " + said.left(300))
	_check("motions: the bring says its 4 motions are kept and not played here",
		said.contains("its 4 motions kept in it, played only where it is the model"))
	var texts: Array = await _save_twice("ic3 motions")
	var had: int = _file(OBS).count("!BRICKWORKS MOTION ")
	var plain: int = _plain_save("Observatory").count("!BRICKWORKS MOTION ")
	var now: int = (texts[0] as String).count("!BRICKWORKS MOTION ")
	_check("motions: the observatory's %d motions (%d in its own save) in the save: %d" % [had, plain, now],
		now >= plain and plain > 0)
	await _invariant("motions", "Car", ["Observatory"], texts[0], tops)
	_same_again("motions", texts)


## The observatory into a model of the app's own its author gave steps,
## written whole: its motions kept in its sub-model through a save, a reopen
## and a save. (Into one nobody gave steps, the plan may write every copy in
## its parent's steps, and a copy so written has no section for its lines:
## the base's, said in intomodel3's report.)
func _case_motions_own() -> void:
	print("\nmotions_own: the small observatory (motions) into Own Steps, the app's own")
	await _open_saved("Own Steps")
	var tops: Array = _tops()
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Observatory"})).left(200))
	var texts: Array = await _save_twice("ic3 motions own")
	var plain: int = _plain_save("Observatory").count("!BRICKWORKS MOTION")
	var now: int = (texts[0] as String).count("!BRICKWORKS MOTION")
	var again: int = (texts[1] as String).count("!BRICKWORKS MOTION")
	_check("motions_own: the observatory's motion lines (%d in its own save) in the save: %d, again: %d" % [
		plain, now, again], now == plain and again == plain and plain > 0)
	var views: int = _plain_save("Observatory").count("!BRICKWORKS VIEW")
	_check("motions_own: its views (%d) in the save: %d" % [views,
		(texts[0] as String).count("!BRICKWORKS VIEW")], (texts[0] as String).count("!BRICKWORKS VIEW") >= views)
	_check("motions_own: the host plays none of them (%d motions)" % (_world.motions.list.size()
		if _world.motions != null else 0), _world.motions == null or _world.motions.list.is_empty())
	await _invariant("motions_own", "Own Steps", ["Observatory"], texts[0], tops)
	_same_again("motions_own", texts)


## A model with a mirrored copy and a mirrored part into the car.
func _case_mirror() -> void:
	print("\nmirror: Mirror (a mirrored copy of Wing, a mirrored part) into the car")
	await _open_saved("Car")
	var tops: Array = _tops()
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Mirror"})).left(200))
	var texts: Array = await _save_twice("ic3 mirror")
	await _invariant("mirror", "Car", ["Mirror"], texts[0], tops)
	_same_again("mirror", texts)


## The lab (carrying an oddpart.dat it cannot build) opened, then Ref (the
## app's own, placing an oddpart.dat it does not carry) opened and saved.
func _case_leak() -> void:
	print("\nleak: the lab opened, then Ref (no oddpart.dat of its own) opened and saved")
	await _open_saved("Lab")
	await _open_saved("Ref")
	await _frames(4)
	_check("leak: Ref saved", _store.save_as("ic3 leak"))
	var text: String = _file(ModelStore.saved_path("ic3 leak"))
	_check("leak: Ref's save carries no part file of the lab's (hostprim.dat: %s)" % text.contains("hostprim.dat"),
		not text.contains("hostprim.dat"))
	if not _out.is_empty():
		_write(_out.path_join("leak.ldr"), text)


## The shed into the car, all its shown parts taken off; saved; then undone.
func _case_delete_undo() -> void:
	print("\ndelete_undo: the shed into the car, its parts taken off, saved, undone, saved")
	await _open_saved("Car")
	var tops: Array = _tops()
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Shed"})).left(100))
	_select(_under(_path_to("Shed", 1)))
	print("    took off %d; held %s" % [_builder.remove_selection(), _held()])
	_edited()
	await _frames(4)
	print("    after edit: held %s" % [_held()])
	_check("delete_undo: saved", _store.save_as("ic3 deleted"))
	var gone: String = _file(ModelStore.saved_path("ic3 deleted"))
	_check("delete_undo: the car alone (%s)" % _difference(_counts(_plain_save("Car")), _counts(gone)),
		_counts(gone) == _counts(_plain_save("Car")))
	var lost: Array = _lost_lines(_file(CAR), gone)
	_check("delete_undo: every line of the car's file kept (%d lost: %s)" % [lost.size(), lost.slice(0, 4)],
		lost.is_empty())
	_check("delete_undo: no steps written into the car (AUTHORED_STEPS: %s)" % gone.contains("AUTHORED_STEPS"),
		not gone.contains("AUTHORED_STEPS") and not _lines(gone).any(func(line: String) -> bool:
			return line.to_upper() == "0 STEP"))
	var stepped: Array = _model().filter(func(brick: BrickWorld.Brick) -> bool: return brick.step != -1)
	_check("delete_undo: the car's parts in no step again, as it opened (%d in one)" % stepped.size(),
		stepped.is_empty())
	await _undo()
	await _frames(4)
	print("    undone: held %s" % [_held()])
	var texts: Array = await _save_twice("ic3 undeleted")
	await _invariant("delete_undo", "Car", ["Shed"], texts[0], tops)
	_same_again("delete_undo", texts)


## The pane into the lodge's Frame (entered), someone else's file.
func _case_lodge_nested() -> void:
	print("\nlodge_nested: the shed into the lodge's Frame#1")
	await _open_saved("Lodge")
	var frame: String = _path_to("Frame", 1)
	_shell.assemblies.enter(frame)
	await _frames(2)
	print("    entered %s; MCP: %s" % [frame, (await _say("open_model", {"into": true, "name": "Shed"})).left(200)])
	_shell.assemblies.enter("")
	await _frames(2)
	var texts: Array = await _save_twice("ic3 lodge nested")
	_lost("lodge_nested", LODGE, texts[0], true)
	var want: Dictionary = _counts(_plain_save("Lodge"))
	for key: String in _counts(_plain_save("Shed")):
		want[key] = int(want.get(key, 0)) + int(_counts(_plain_save("Shed"))[key])
	_check("lodge_nested: lodge + shed (%s)" % _difference(want, _counts(texts[0])), _counts(texts[0]) == want)
	print("    trees: %s" % _trees(texts[0]))
	_same_again("lodge_nested", texts)


## The shed into the lodge, taken apart.
func _case_lodge_ungroup() -> void:
	print("\nlodge_ungroup: the shed into the lodge, taken apart")
	await _open_saved("Lodge")
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Shed"})).left(100))
	print("    ungrouped %d" % _shell.assemblies.ungroup(_path_to("Shed", 1)))
	await _frames(4)
	var texts: Array = await _save_twice("ic3 lodge ungroup")
	_lost("lodge_ungroup", LODGE, texts[0], true)
	var want: Dictionary = _counts(_plain_save("Lodge"))
	for key: String in _counts(_plain_save("Shed")):
		want[key] = int(want.get(key, 0)) + int(_counts(_plain_save("Shed"))[key])
	_check("lodge_ungroup: lodge + shed (%s)" % _difference(want, _counts(texts[0])), _counts(texts[0]) == want)
	print("    trees: %s" % _trees(texts[0]))
	_same_again("lodge_ungroup", texts)


## The person's way: File, Import, Into this model…'s hold_text, a click.
func _case_menu() -> void:
	print("\nmenu: the shed by hold_text into the clash host, put down by a click")
	await _open_saved("Clash Host")
	var tops: Array = _tops()
	var count: int = await _bar.hold_text(SHED, "shed.ldr", "Shed")
	print("    in hand: %d; put down: %s" % [count, await _put_beside()])
	var texts: Array = await _save_twice("ic3 menu")
	await _invariant("menu", "Clash Host", ["Shed"], texts[0], tops)
	_same_again("menu", texts)


## nested_own (lights and views in its sub-models and its model) into the car.
func _case_nested_own() -> void:
	print("\nnested_own: nested_own (lights, views in sub-models and the model) into the car")
	await _open_saved("Car")
	var tops: Array = _tops()
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Nested"})).left(200))
	var texts: Array = await _save_twice("ic3 nested own")
	for word: String in ["LIGHT", "VIEW"]:
		var had: int = _plain_save("Nested").count("!BRICKWORKS %s " % word)
		var now: int = (texts[0] as String).count("!BRICKWORKS %s " % word)
		_check("nested_own: its %s lines (%d in its own save) in the save: %d" % [word, had, now], now >= had)
	await _invariant("nested_own", "Car", ["Nested"], texts[0], tops)
	_same_again("nested_own", texts)


## A saved model named as its file's sub-model: Shed saved as "Roof".
func _case_same_name() -> void:
	print("\nsame_name: the shed saved as Roof, into the car")
	_keep("Roof", SHED)
	await _open_saved("Car")
	var tops: Array = _tops()
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Roof"})).left(300))
	print("    paths now %s; held %s" % [_paths(), _held()])
	var texts: Array = await _save_twice("ic3 same name")
	await _invariant("same_name", "Car", ["Roof"], texts[0], tops)
	_same_again("same_name", texts)


## The car into itself.
func _case_self_car() -> void:
	print("\nself_car: the car into the car")
	await _open_saved("Car")
	var tops: Array = _tops()
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Car"})).left(300))
	var texts: Array = await _save_twice("ic3 self car")
	await _invariant("self_car", "Car", ["Car"], texts[0], tops)
	_same_again("self_car", texts)


## The lodge into itself (someone else's file, its Frame in window.ldr).
func _case_self_lodge() -> void:
	print("\nself_lodge: the lodge into the lodge")
	await _open_saved("Lodge")
	var tops: Array = _tops()
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Lodge"})).left(300))
	var texts: Array = await _save_twice("ic3 self lodge")
	_lost("self_lodge", LODGE, texts[0], true)
	await _invariant("self_lodge", "Lodge", ["Lodge"], texts[0], tops)
	_same_again("self_lodge", texts)


## The shed into the lodge, saved; then moved and saved again, unopened.
func _case_lodge_save_edit() -> void:
	print("\nlodge_save_edit: the shed into the lodge, saved, moved, saved again")
	await _open_saved("Lodge")
	var tops: Array = _tops()
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Shed"})).left(100))
	_check("lodge_save_edit: saved", _store.save_as("ic3 lodge save edit"))
	var first: String = _file(ModelStore.saved_path("ic3 lodge save edit"))
	_check("lodge_save_edit: saved again unedited, the same bytes", _store.save_as("ic3 lodge save edit")
		and _file(ModelStore.saved_path("ic3 lodge save edit")) == first)
	_select(_under(_path_to("Shed", 1)))
	_main.call("_nudge_by", Vector3i(4, 0, 0))
	await _frames(4)
	var texts: Array = await _save_twice("ic3 lodge save edit")
	_lost("lodge_save_edit", LODGE, texts[0], true)
	await _invariant("lodge_save_edit", "Lodge", ["Shed"], texts[0], tops)
	_offsets("lodge_save_edit", texts[0])
	_same_again("lodge_save_edit", texts)


## Another model whose file is called car.ldr into the car (no FILE line).
func _case_carname() -> void:
	print("\ncarname: Other Car (its file car.ldr) into the car")
	await _open_saved("Car")
	var tops: Array = _tops()
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Other Car"})).left(300))
	var texts: Array = await _save_twice("ic3 carname")
	var want: Dictionary = _counts(_plain_save("Car"))
	for key: String in _counts(OTHERCAR):
		want[key] = int(want.get(key, 0)) + int(_counts(OTHERCAR)[key])
	_check("carname: the car + Other Car's two yellow bricks, reopened (%s)" % _difference(want,
		_counts(texts[0])), _counts(texts[0]) == want)
	_unique_files("carname", texts[0])
	_same_again("carname", texts)
	if not _out.is_empty():
		_write(_out.path_join("carname.ldr"), texts[0])


## Another model called Car with no FILE line into the car.
func _case_carname_plain() -> void:
	print("\ncarname_plain: Plain Car (titled Car, no FILE line) into the car")
	await _open_saved("Car")
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Plain Car"})).left(300))
	var texts: Array = await _save_twice("ic3 carname plain")
	var want: Dictionary = _counts(_plain_save("Car"))
	for key: String in _counts(PLAINCAR):
		want[key] = int(want.get(key, 0)) + int(_counts(PLAINCAR)[key])
	_check("carname_plain: the car + Plain Car's two red plates, reopened (%s)" % _difference(want,
		_counts(texts[0])), _counts(texts[0]) == want)
	_unique_files("carname_plain", texts[0])
	_same_again("carname_plain", texts)
	if not _out.is_empty():
		_write(_out.path_join("carname_plain.ldr"), texts[0])


## Someone's model whose file is clashhost.ldr into Clash Host (the app's).
func _case_ownname() -> void:
	print("\nownname: Own Name (its file clashhost.ldr) into Clash Host")
	await _open_saved("Clash Host")
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Own Name"})).left(300))
	var texts: Array = await _save_twice("ic3 ownname")
	var want: Dictionary = _counts(_plain_save("Clash Host"))
	for key: String in _counts(OWNNAME):
		want[key] = int(want.get(key, 0)) + int(_counts(OWNNAME)[key])
	_check("ownname: Clash Host + Own Name's green brick, reopened (%s)" % _difference(want,
		_counts(texts[0])), _counts(texts[0]) == want)
	_unique_files("ownname", texts[0])
	_same_again("ownname", texts)


## Tower (its sub-model called Tower) into the car, then its inner copy's
## 3005 taken off.
func _case_selfclash_edit() -> void:
	print("\nselfclash_edit: Tower into the car, the inner Tower's 3005 taken off, then renamed")
	await _open_saved("Car")
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Tower"})).left(120))
	var inner: Array = _model().filter(func(b: BrickWorld.Brick) -> bool: return b.part_id == "3005")
	_select(inner.map(func(b: BrickWorld.Brick) -> int: return b.id))
	print("    took off %d (of %s)" % [_builder.remove_selection(), inner.map(func(b: BrickWorld.Brick) -> String:
		return Assemblies.path_of(b))])
	_edited()
	await _frames(4)
	print("    paths now %s; parts %s" % [_paths(), _model().map(func(b: BrickWorld.Brick) -> String:
		return "%s@%s" % [b.part_id, Assemblies.path_of(b)]).filter(func(s: String) -> bool: return s.contains("Tower"))])
	var texts: Array = await _save_twice("ic3 selfclash edit")
	var want: Dictionary = _counts(_plain_save("Car"))
	want["3001|4"] = int(want.get("3001|4", 0)) + 1
	want["3003|2"] = int(want.get("3003|2", 0)) + 1
	_check("selfclash_edit: the car + Tower's 3001 and 3003, its 3005 gone (%s)" % _difference(want,
		_counts(texts[0])), _counts(texts[0]) == want)
	print("    trees: %s" % _trees(texts[0]))
	_same_again("selfclash_edit", texts)


## Other Car (its file car.ldr) into the app's own Car (no FILE line).
func _case_owncar() -> void:
	print("\nowncar: Other Car (its file car.ldr) into Own Car (the app's, called Car, no FILE line)")
	await _open_saved("Own Car")
	print("    MCP: " + (await _say("open_model", {"into": true, "name": "Other Car"})).left(300))
	var texts: Array = await _save_twice("ic3 owncar")
	var want: Dictionary = _counts(OWNCAR)
	for key: String in _counts(OTHERCAR):
		want[key] = int(want.get(key, 0)) + int(_counts(OTHERCAR)[key])
	_check("owncar: Own Car + Other Car's two yellow bricks, reopened (%s)" % _difference(want,
		_counts(texts[0])), _counts(texts[0]) == want)
	_unique_files("owncar", texts[0])
	_same_again("owncar", texts)
	if not _out.is_empty():
		_write(_out.path_join("owncar.ldr"), texts[0])


# -- the invariant -----------------------------------------------------------


## [param text], a save of [param host] with [param brought] put in, against
## each opened alone and saved: the host's placements as they were, each
## brought model's as it has them, shifted alike.
func _invariant(case: String, host: String, brought: Array, text: String, tops_before: Array) -> void:
	var placed: Array = _placed(text)
	var host_want: Array = _placed(_plain_save(host))
	var host_keys: Dictionary = {}
	for entry: Dictionary in host_want:
		host_keys[_top_def(entry["chain"])] = true
	var own: Array = []
	var others: Dictionary = {}     ## top def -> entries
	for entry: Dictionary in placed:
		var top: String = _top_def(entry["chain"])
		if host_keys.has(top):
			own.append(entry)
		else:
			if not others.has(top):
				others[top] = []
			(others[top] as Array).append(entry)
	var stepless: bool = host_want.all(func(e: Dictionary) -> bool: return int(e["step"]) < 0)
	if stepless:
		print("    (the host has no steps: its parts compared without them)")
	var a: Array = host_want.map(func(e: Dictionary) -> String: return _row(_unstepped(e, stepless), Vector3.ZERO, false))
	var b: Array = own.map(func(e: Dictionary) -> String: return _row(_unstepped(e, stepless), Vector3.ZERO, false))
	a.sort()
	b.sort()
	_check("%s: the host's %d placements each in place, colour, sub-model and step (%d now)%s" % [
		case, a.size(), b.size(), _first_apart(a, b)], a == b)
	print("    brought tops in the save: %s" % [others.keys().map(func(k: String) -> String:
		return "%s (%d)" % [k, (others[k] as Array).size()])])
	var used: Dictionary = {}
	for which: String in brought:
		var want: Array = _placed(_plain_save(which))
		var found: String = ""
		for top: String in others:
			if used.has(top) or (others[top] as Array).size() != want.size():
				continue
			if _same_shifted(want, others[top]):
				found = top
				break
		if not found.is_empty():
			used[found] = true
		_check("%s: %s's %d placements, one shift, each colour, depth and step (as %s)" % [case, which,
			want.size(), found if not found.is_empty() else "none matched: " + _why_apart(want, others)],
			not found.is_empty())
	_unique_files(case, text)
	if not _out.is_empty():
		_write(_out.path_join(case + ".ldr"), text)


static func _top_def(chain: String) -> String:
	return chain.get_slice("/", 0)


## A row of an entry: its part and colour, its chain below its top (or whole),
## its place less [param shift] and its turn, its step.
static func _row(e: Dictionary, shift: Vector3, below_top: bool) -> String:
	var t: Transform3D = e["at"]
	var chain: String = str(e["chain"])
	if below_top:
		chain = str(chain.count("/"))
	var o: Vector3 = t.origin - shift
	var b: Basis = t.basis
	return "%s %s (%.0f %.0f %.0f) [%.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f] s%d" % [e["key"], chain,
		o.x, o.y, o.z, b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, int(e["step"])]


static func _unstepped(e: Dictionary, stepless: bool) -> Dictionary:
	if not stepless:
		return e
	var out: Dictionary = e.duplicate()
	out["step"] = -1
	return out


func _same_shifted(want: Array, have: Array) -> bool:
	var shift: Vector3 = _centre(have) - _centre(want)
	var stepless: bool = want.all(func(e: Dictionary) -> bool: return int(e["step"]) < 0)
	var a: Array = want.map(func(e: Dictionary) -> String: return _row(_deeper(e), Vector3.ZERO, true))
	var b: Array = have.map(func(e: Dictionary) -> String: return _row(_unstepped(e, stepless), shift, true))
	a.sort()
	b.sort()
	return a == b


func _why_apart(want: Array, others: Dictionary) -> String:
	var said: Array = []
	for top: String in others:
		var have: Array = others[top]
		var shift: Vector3 = _centre(have) - _centre(want)
		var stepless: bool = want.all(func(e: Dictionary) -> bool: return int(e["step"]) < 0)
		var a: Array = want.map(func(e: Dictionary) -> String: return _row(_deeper(e), Vector3.ZERO, true))
		var b: Array = have.map(func(e: Dictionary) -> String: return _row(_unstepped(e, stepless), shift, true))
		a.sort()
		b.sort()
		said.append("%s %d/%d%s" % [top, b.size(), a.size(), _first_apart(a, b)])
	return "; ".join(said)


## [param e] as if it were one level deeper, under a top copy.
static func _deeper(e: Dictionary) -> Dictionary:
	var out: Dictionary = e.duplicate()
	out["chain"] = "top/" + str(e["chain"]) if not str(e["chain"]).is_empty() else "top"
	return out


static func _centre(entries: Array) -> Vector3:
	var sum := Vector3.ZERO
	for e: Dictionary in entries:
		sum += (e["at"] as Transform3D).origin
	return sum / maxf(1.0, float(entries.size()))


static func _first_apart(a: Array, b: Array) -> String:
	var only_a: Array = a.filter(func(x: String) -> bool: return not b.has(x))
	var only_b: Array = b.filter(func(x: String) -> bool: return not a.has(x))
	if only_a.is_empty() and only_b.is_empty():
		return ""
	return " | wanted not there: %s | there not wanted: %s" % [only_a.slice(0, 3), only_b.slice(0, 3)]


func _unique_files(case: String, text: String) -> void:
	var seen: Dictionary = {}
	var twice: Array = []
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.to_upper().begins_with("0 FILE "):
			var key: String = LdrModel._key(line.substr(7))
			if seen.has(key):
				twice.append(key)
			seen[key] = true
	_check("%s: no two sections of one name (%s)" % [case, twice], twice.is_empty())


func _same_again(case: String, texts: Array) -> void:
	var a: String = texts[0]
	var b: String = texts[1]
	var apart: String = ""
	if a != b:
		var la: PackedStringArray = a.split("\n")
		var lb: PackedStringArray = b.split("\n")
		for n: int in maxi(la.size(), lb.size()):
			var x: String = la[n] if n < la.size() else "<none>"
			var y: String = lb[n] if n < lb.size() else "<none>"
			if x != y:
				apart = " first apart at line %d: [%s] / [%s]" % [n + 1, x.left(100), y.left(100)]
				break
	_check("%s: saved, reopened and saved again, byte-identical (%d / %d bytes)%s" % [case, a.length(),
		b.length(), apart], a == b)
	if not _out.is_empty() and a != b:
		_write(_out.path_join(case + ".again.ldr"), b)


func _lost(case: String, original: String, text: String, check: bool) -> void:
	var lost: Array = _lost_lines(original, text)
	print("    %s: %d of the host's lines missing from the save: %s" % [case, lost.size(), lost.slice(0, 6)])
	if check:
		_check("%s: the host's own lines kept (%d missing)" % [case, lost.size()], lost.is_empty())


# -- helpers -----------------------------------------------------------------


## [param name] opened alone and saved, as the app writes it: cached.
var _plains: Dictionary = {}
func _plain_save(name: String) -> String:
	return str(_plains.get(name, ""))


func _make_plains() -> void:
	for name: String in ["Car", "Shed", "Pane", "Lodge", "Clash Host", "Clasher", "Tower", "Home Two",
			"Own Steps",
			"Mirror", "Observatory", "Nested", "Lab"]:
		await _open_saved(name)
		await _frames(2)
		_store.save_as("ic3 plain " + name)
		_plains[name] = _file(ModelStore.saved_path("ic3 plain " + name))


func _tops() -> Array:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _model():
		var path: String = Assemblies.path_of(brick)
		out[Assemblies.segments(path)[0] if not path.is_empty() else ""] = true
	return out.keys()


func _held() -> Array:
	return _store._held_placements().map(func(p: LdrModel.Placement) -> String:
		return "%s in %s" % [p.part_id, _world.held_path(p)])


func _paths() -> Array:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _model():
		out[Assemblies.path_of(brick)] = true
	return out.keys()


func _under(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _model():
		var at: String = Assemblies.path_of(brick)
		if at == path or at.begins_with(path + "/"):
			out.append(brick.id)
	return out


static func _lines(text: String) -> Array:
	var out: Array = []
	for raw: String in text.split("\n"):
		var line: String = " ".join(LdrModel._fields(raw.strip_edges()))
		if not line.is_empty():
			out.append(line)
	return out


static func _lost_lines(original: String, text: String) -> Array:
	var have: Dictionary = {}
	for line: String in _lines(text):
		have[line.to_lower()] = int(have.get(line.to_lower(), 0)) + 1
	var out: Array = []
	for line: String in _lines(original):
		var key: String = line.to_lower()
		if int(have.get(key, 0)) > 0:
			have[key] = int(have[key]) - 1
		else:
			out.append(line)
	return out


func _path_to(def: String, copy: int) -> String:
	for brick: BrickWorld.Brick in _model():
		var parts: PackedStringArray = Assemblies.segments(Assemblies.path_of(brick))
		for n: int in parts.size():
			if Assemblies.definition(parts[n]) == def and Assemblies.copy_of(parts[n]) == copy:
				return "/".join(parts.slice(0, n + 1))
	return ""


func _keep(name: String, text: String) -> void:
	var path: String = ModelStore.saved_path(name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_write(path, text)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _file(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _open_saved(name: String) -> void:
	await _open_path(ModelStore.saved_path(name))


func _open_path(path: String) -> void:
	_builder.cancel_carry()
	_shell.assemblies.enter("")
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _frames(10)


## Saved, reopened, saved again under the same name: both texts.
func _save_twice(name: String) -> Array:
	await _frames(4)
	_check("saved as %s" % name, _store.save_as(name))
	var first: String = _file(ModelStore.saved_path(name))
	await _open_path(ModelStore.saved_path(name))
	_check("saved again as %s" % name, _store.save_as(name))
	var second: String = _file(ModelStore.saved_path(name))
	return [first, second]


func _placed(text: String) -> Array:
	var model: LdrModel = LdrModel.parse(text, "model.ldr")
	CustomParts.take_into([], _library, model, null)
	var out: Array = []
	var authored: bool = model.steps_are_authored()
	for placement: LdrModel.Placement in model.flatten(_library.parts):
		var part: String = ModelStore.studio_part(_library.resolve(placement.part_id), _library)
		out.append({"key": "%s|%d" % [part, placement.color_code],
			"chain": _chain(Assemblies.path_from(placement.group, placement.unit)),
			"at": placement.transform, "step": placement.step if authored else -1})
	return out


func _chain(path: String) -> String:
	return "/".join(Array(Assemblies.segments(path)).map(func(s: String) -> String:
		return Assemblies.definition(s)))


func _counts(text: String) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in _placed(text):
		out[entry["key"]] = int(out.get(entry["key"], 0)) + 1
	return out


static func _difference(a: Dictionary, b: Dictionary) -> String:
	var said: Array = []
	for key: Variant in a:
		if int(a[key]) != int(b.get(key, 0)):
			said.append("%s %d/%d" % [key, int(a[key]), int(b.get(key, 0))])
	for key: Variant in b:
		if not a.has(key):
			said.append("%s 0/%d" % [key, int(b[key])])
	return "same" if said.is_empty() else ", ".join(said)


func _trees(text: String) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in _placed(text):
		out[entry["key"]] = (out.get(entry["key"], []) as Array) + [entry["chain"]]
	return out


## Where each zz part sits against the nearest brick it sits on in the shed.
func _offsets(case: String, text: String) -> void:
	var placed: Array = _placed(text)
	for pair: Array in [["3001|4", "zz9001|1", Vector3(0, 24, 0)], ["3003|2", "zz9002|14", Vector3(0, 24, 0)]]:
		var bricks: Array = placed.filter(func(e: Dictionary) -> bool: return e["key"] == pair[0])
		var kept: Array = placed.filter(func(e: Dictionary) -> bool: return e["key"] == pair[1])
		var seen: Array = []
		for k: Dictionary in kept:
			var best := Vector3(INF, INF, INF)
			for b: Dictionary in bricks:
				var off: Vector3 = (k["at"] as Transform3D).origin - (b["at"] as Transform3D).origin
				if off.length() < best.length():
					best = off
			seen.append(best)
		_check("%s: each %s where the shed has it on a %s (%s)" % [case, pair[1], pair[0], seen],
			not seen.is_empty() and seen.all(func(v: Vector3) -> bool: return v.is_equal_approx(pair[2])))


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _select(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: Variant in ids:
		_builder.selection[int(brick_id)] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _put_beside() -> Variant:
	var model := AABB()
	var any: bool = false
	for brick: BrickWorld.Brick in _model():
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var here: AABB = (brick.transform * mesh.bounds).abs()
		model = here if not any else model.merge(here)
		any = true
	for tries: int in 30:
		var at := Vector3(model.end.x + 200.0 + 40.0 * tries, model.end.y + 600.0, model.get_center().z)
		_builder.carrying.aim(_builder.lattice, _builder, at, Vector3.DOWN)
		if _builder.carrying.can_place():
			var first: int = _builder.place()
			_edited()
			await _frames(4)
			return first if first != 0 else null
	return null


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	await _frames(6)
	return text.replace("\n", " | ")


## As the app does after an edit by hand, an undo and a redo (Main).
func _edited() -> void:
	_main.call("_on_model_edited")


func _undo() -> void:
	if _builder.undo():
		_edited()
	await _frames(2)


func _redo() -> void:
	if _builder.redo():
		_edited()
	await _frames(2)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
