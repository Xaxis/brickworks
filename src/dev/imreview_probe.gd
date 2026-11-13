## Independent review of intomodel: inputs where bringing a model in, putting
## it down, saving and reopening loses or moves a part.
##
##   godot --headless --path . --script src/dev/imreview_probe.gd
##
## Each case prints FAIL with what the reopened file has against what it
## should have. The ground truth is the saved file read as an open reads
## it: every placement it flattens to, shown or not.
extends SceneTree

const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"
const WHOLE := "res://tests/fixtures/studio/whole_2025.io"

## A model with two parts the library has not got, one in a sub-model.
const SHED := """0 FILE shed.ldr
0 Shed
0 Name: shed.ldr
0 Author: A. Builder
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -48 0 1 0 0 0 1 0 0 0 1 zz9001.dat
1 16 80 -24 0 1 0 0 0 1 0 0 0 1 roof.ldr
0 NOFILE
0 FILE roof.ldr
0 Roof
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 zz9002.dat
0 NOFILE
"""

## A model carrying a part of its own that draws nothing the library has.
const ODD := """0 FILE odd.ldr
0 Odd
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 0 -48 0 1 0 0 0 1 0 0 0 1 oddpart.dat
0 NOFILE
0 FILE oddpart.dat
0 Odd part
0 Name: oddpart.dat
0 Author: A. Builder
0 !LDRAW_ORG Unofficial_Part
1 16 0 0 0 1 0 0 0 1 0 0 0 1 nosuchprim.dat
0 NOFILE
"""

## A host with a sub-model called Window of its own.
const SHACK := """0 FILE shack.ldr
0 Shack
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -48 0 1 0 0 0 1 0 0 0 1 window.ldr
0 NOFILE
0 FILE window.ldr
0 Window
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3002.dat
0 NOFILE
"""

## The shack again, its Window sharing a part with the gatehouse's.
const SHACK2 := """0 FILE shack2.ldr
0 Shack2
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -48 0 1 0 0 0 1 0 0 0 1 window.ldr
0 NOFILE
0 FILE window.ldr
0 Window
1 71 0 0 0 1 0 0 0 1 0 0 0 1 3005.dat
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3002.dat
0 NOFILE
"""

## A host whose sub-model "Window" is only a part the library has not got.
const HUT := """0 FILE hut.ldr
0 Hut
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -24 80 1 0 0 0 1 0 0 0 1 window.ldr
0 NOFILE
0 FILE window.ldr
0 Window
1 1 0 0 0 1 0 0 0 1 0 0 0 1 zz9003.dat
0 NOFILE
"""

## A model with no steps titled Window, its parts all known.
const PANE := """0 FILE pane.ldr
0 Window
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 14 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"""

## Three deep, with steps at each level.
const TOWER := """0 FILE tower.ldr
0 Tower
0 Author: A. Builder
1 16 0 0 0 1 0 0 0 1 0 0 0 1 floor.ldr
0 STEP
1 16 0 -200 0 1 0 0 0 1 0 0 0 1 floor.ldr
0 STEP
1 2 0 -400 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
0 NOFILE
0 FILE floor.ldr
0 Floor
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 16 80 -24 0 1 0 0 0 1 0 0 0 1 room.ldr
0 STEP
0 NOFILE
0 FILE room.ldr
0 Room
1 1 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 lamp.ldr
0 STEP
0 NOFILE
0 FILE lamp.ldr
0 Lamp
1 14 0 0 0 1 0 0 0 1 0 0 0 1 3005.dat
0 STEP
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3024.dat
0 STEP
0 NOFILE
"""

## Two copies of a house, each with a window inside.
const STREET := """0 FILE street.ldr
0 Street
1 16 0 0 0 1 0 0 0 1 0 0 0 1 house.ldr
1 16 400 0 0 1 0 0 0 1 0 0 0 1 house.ldr
0 NOFILE
0 FILE house.ldr
0 House
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -48 0 1 0 0 0 1 0 0 0 1 window.ldr
0 NOFILE
0 FILE window.ldr
0 Window
1 1 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3024.dat
0 NOFILE
"""

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _library: PartLibrary
var _store: ModelStore
var _bar: ModelBar
var _shell: Shell
var _verbs: EditVerbs
var _socket: Variant
var _rpc_id: int = 0
var _only: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		_only = arg
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
	_verbs = _main.get("_verbs")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	_store.keeps = false
	CustomParts.dir = OS.get_user_data_dir().path_join("imreview_parts/")
	CustomParts.keeps = false
	_keep("Gatehouse", FileAccess.get_file_as_string(GATEHOUSE))
	_keep("Shed", SHED)
	_keep("Hut", HUT)
	_keep("Pane", PANE)
	_keep("Tower", TOWER)
	_keep("Street", STREET)
	_keep("Odd", ODD)
	_keep("Shack", SHACK)
	_keep("Shack2", SHACK2)
	for case: String in ["undo_in_hand2", "pane_from_file", "undo_in_hand", "unmeshed", "unknown", "unshown_name", "unshown_path", "self", "deep", "undo_redo",
			"rotstep", "studio", "paste_nested", "lift_nested", "into_entered", "mcp_args"]:
		if not _only.is_empty() and not case in _only.split(","):
			continue
		await call("_case_" + case)
	print("")
	print("imreview: %s" % ("all held" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- cases ---------------------------------------------------------------------


## Parts the library has not got, in the model brought in: kept by an open
## of that file and its save; kept by bringing it in?
func _case_unknown() -> void:
	print("\nunknown: a model with 2 parts the library has not got, brought into the car")
	await _open_path(ModelStore.saved_path("Shed"))
	var opened_alone: Dictionary = _counts(await _save_reopen("Shed alone"))
	_check("baseline: Shed opened and saved alone keeps zz9001 and zz9002 (%s)" % opened_alone,
		int(opened_alone.get("zz9001|1", 0)) == 1 and int(opened_alone.get("zz9002|14", 0)) == 1)
	await _open_path("res://models/car.ldr")
	var host: Dictionary = _counts(FileAccess.get_file_as_string("res://models/car.ldr"))
	var said: String = await _say("open_model", {"into": true, "name": "Shed"})
	print("    MCP: " + said.left(400))
	var after: Dictionary = _counts(await _save_reopen("Car and shed"))
	var want: Dictionary = _plus(host, _counts(SHED))
	_check("Car and shed reopened: every part of the car and of the shed (lost: %s, gained: %s)"
		% [_minus(want, after), _minus(after, want)], after == want)


## A host whose sub-model is all parts the app cannot show, named as one
## the model brought in has: the host's sub-model in the saved file.
func _case_unshown_name() -> void:
	print("\nunshown_name: the gatehouse into a hut whose Window is a part the library has not got")
	await _open_path(ModelStore.saved_path("Hut"))
	var alone: Dictionary = _counts(await _save_reopen("Hut alone"))
	_check("baseline: Hut saved alone keeps zz9003 (%s)" % alone, int(alone.get("zz9003|1", 0)) == 1)
	await _open_path(ModelStore.saved_path("Hut"))
	var said: String = await _say("open_model", {"into": true, "name": "Gatehouse"})
	print("    MCP: " + said.left(300))
	var text: String = await _save_reopen("Hut and gatehouse")
	var after: Dictionary = _counts(text)
	var want: Dictionary = _plus(_counts(HUT), _counts(FileAccess.get_file_as_string(GATEHOUSE)))
	_check("reopened: every part of the hut and the gatehouse (lost: %s, gained: %s)"
		% [_minus(want, after), _minus(after, want)], after == want)
	if after != want:
		print("    saved file:\n      " + text.replace("\n", "\n      "))


## A model with no steps, titled as the host's unshown sub-model, into a
## host with no steps: its parts land in the host's sub-model?
func _case_unshown_path() -> void:
	print("\nunshown_path: a model titled Window into the hut (its Window all unshown)")
	await _open_path(ModelStore.saved_path("Hut"))
	var said: String = await _say("open_model", {"into": true, "name": "Pane"})
	print("    MCP: " + said.left(300))
	var put: Array = _paths_now()
	var text: String = await _save_reopen("Hut and pane")
	var after: Dictionary = _counts(text)
	var want: Dictionary = _plus(_counts(HUT), _counts(PANE))
	_check("reopened: every part (lost: %s, gained: %s)" % [_minus(want, after), _minus(after, want)],
		after == want)
	var trees: Dictionary = _trees(text)
	print("    put down: %s" % ", ".join(put))
	print("    reopened file's parts by sub-model: %s" % trees)
	_check("...the pane's two bricks in a sub-assembly of their own, not in the hut's Window with zz9003",
		not (trees.get("zz9003|1", []) as Array).any(func(chain: String) -> bool:
			return (trees.get("3001|14", []) as Array).has(chain)))
	if trees.get("zz9003|1", []) == trees.get("3001|14", []).slice(0, 1):
		print("    saved file:\n      " + text.replace("\n", "\n      "))


## The gatehouse into itself.
func _case_self() -> void:
	print("\nself: the gatehouse into the gatehouse")
	await _open_path(ModelStore.saved_path("Gatehouse"))
	var said: String = await _say("open_model", {"into": true, "name": "Gatehouse"})
	print("    MCP: " + said.left(300))
	var before: Array = _snapshot()
	var units: Dictionary = _world.unit_steps.duplicate()
	var text: String = await _save_reopen("Gatehouse twice")
	var after: Dictionary = _counts(text)
	var one: Dictionary = _counts(FileAccess.get_file_as_string(GATEHOUSE))
	_check("reopened: 28 parts, the gatehouse twice (lost: %s, gained: %s)" % [
		_minus(_plus(one, one), after), _minus(after, _plus(one, one))], after == _plus(one, one))
	_same_world(before, units)


## Three deep, with steps, into the car; into a model with steps.
func _case_deep() -> void:
	print("\ndeep: a tower three sub-models deep, with steps, into the car and into the gatehouse")
	for host: String in ["res://models/car.ldr", ModelStore.saved_path("Gatehouse")]:
		await _open_path(host)
		var said: String = await _say("open_model", {"into": true, "name": "Tower"})
		print("    MCP into %s: %s" % [host.get_file(), said.left(200)])
		var before: Array = _snapshot()
		var units: Dictionary = _world.unit_steps.duplicate()
		var text: String = await _save_reopen("Deep into " + host.get_file().get_basename())
		var want: Dictionary = _plus(_counts(_file_text(host)), _counts(TOWER))
		var after: Dictionary = _counts(text)
		_check("reopened: every part (lost: %s, gained: %s)" % [_minus(want, after), _minus(after, want)],
			after == want)
		_same_world(before, units)


## Brought, undone, redone, saved, reopened: as brought.
func _case_undo_redo() -> void:
	print("\nundo_redo: the tower brought in, undone, redone")
	await _open_path(ModelStore.saved_path("Gatehouse"))
	var start: Array = _snapshot()
	var start_units: Dictionary = _world.unit_steps.duplicate()
	await _say("open_model", {"into": true, "name": "Tower"})
	var brought: Array = _snapshot()
	var brought_units: Dictionary = _world.unit_steps.duplicate()
	_builder.undo()
	await _frames(4)
	_check("one undo: as it was (%d parts, units %s)" % [_snapshot().size(), _world.unit_steps],
		_snapshot() == start and _world.unit_steps == start_units)
	if _snapshot() != start:
		_diff(start, _snapshot())
	_builder.redo()
	await _frames(4)
	_check("redo: as brought (%d parts)" % _snapshot().size(), _snapshot() == brought)
	if _snapshot() != brought:
		_diff(brought, _snapshot())
	_check("...each copy's step as brought (%s vs %s)" % [_world.unit_steps, brought_units],
		_world.unit_steps == brought_units)
	await _save_reopen("Undo redo")
	_same_world(brought, brought_units)
	# Esc with it in hand, then undo: the last thing before it is undone, no more.
	await _open_path(ModelStore.saved_path("Gatehouse"))
	var depth: int = _builder.history_depth()
	var held: int = await _bar.hold_text(_file_text(ModelStore.saved_path("Tower")), "tower.ldr", "Tower")
	_check("in hand: %d parts, brought=%s" % [held, _builder.carrying.brought], held > 0 and _builder.carrying.brought)
	_builder.cancel_carry()
	_check("Esc: nothing in hand, brought cleared, history as it was (%d)" % _builder.history_depth(),
		not _builder.is_carrying() and not _builder.carrying.brought and _builder.carrying.brought_units.is_empty()
		and _builder.history_depth() == depth)


## The author's step views (ROTSTEP) of a model brought in.
func _case_rotstep() -> void:
	print("\nrotstep: the gatehouse's ROTSTEP, brought into the car")
	await _open_path("res://models/car.ldr")
	await _say("open_model", {"into": true, "name": "Gatehouse"})
	var text: String = await _save_reopen("Car rotstep")
	_check("the saved file keeps the gatehouse's ROTSTEP 0 45 0 ABS (%d ROTSTEP lines)" % text.count("ROTSTEP"),
		text.contains("ROTSTEP 0 45 0"))
	_check("the saved file keeps its author, A. Builder", text.contains("A. Builder"))


## Studio-only parts: carried in the saved file.
func _case_studio() -> void:
	print("\nstudio: whole_2025.io into the car, saved: its Studio-only parts carried in the file")
	await _open_path("res://models/car.ldr")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(WHOLE)
	var read: Dictionary = StudioIo.read(bytes, _library)
	var carried: PackedStringArray = read.get("studio_parts", PackedStringArray())
	var count: int = await _bar.hold_text(str(read.get("text", "")), "whole_2025.io") if read.has("text") else 0
	if count == 0:
		print("    (StudioIo.read keys: %s)" % read.keys())
		return
	var spot: Variant = await _put_beside()
	_check("put down", spot != null)
	var text: String = await _save_reopen("Car and whole")
	var model: LdrModel = LdrModel.parse(text, "x.ldr")
	var missing: PackedStringArray = PackedStringArray()
	for id: String in carried:
		if not model.embedded_parts.has(id + ".dat") and not model.embedded_sources.has(id + ".dat"):
			missing.append(id)
	_check("each of the %d Studio-only parts carried in the saved file (not carried: %s)" % [
		carried.size(), ", ".join(missing)], missing.is_empty() and carried.size() > 0)


## Copy a nested sub-assembly's parts and paste them, beside and inside.
func _case_paste_nested() -> void:
	print("\npaste_nested: the street's two houses, a window's parts copied and pasted")
	await _open_path(ModelStore.saved_path("Street"))
	var start: Dictionary = _counts(STREET)
	var window: Array = _ids_at("House#1/Window#1")
	print("    paths: %s" % ", ".join(_paths_now()))
	_check("House#1/Window#1 has 2 parts", window.size() == 2)
	_select(window)
	_verbs.copy()
	_verbs.paste()
	var spot: Variant = await _put_beside()
	await _frames(6)
	print("    after paste: %s" % ", ".join(_paths_now()))
	_check("each house still has its brick and its window (%s)" % _houses(),
		_houses() == {"House#1": 3, "House#2": 3})
	var text: String = await _save_reopen("Street pasted")
	var after: Dictionary = _counts(text)
	var want: Dictionary = _plus(start, {"3003|1": 1, "3024|15": 1})
	_check("reopened: the street and the 2 pasted (lost: %s, gained: %s)" % [_minus(want, after),
		_minus(after, want)], after == want)
	# One part out of the nested window, pasted.
	await _open_path(ModelStore.saved_path("Street"))
	var one: Array = _ids_at("House#1/Window#1").slice(0, 1)
	_select(one)
	_verbs.copy()
	_verbs.paste()
	await _put_beside()
	await _frames(6)
	print("    after pasting one: %s" % ", ".join(_paths_now()))
	_check("each house still has its brick and its window (%s)" % _houses(),
		_houses() == {"House#1": 3, "House#2": 3})
	text = await _save_reopen("Street pasted one")
	after = _counts(text)
	want = _plus(start, _counts_of(one))
	_check("reopened: the street and the 1 pasted (lost: %s, gained: %s)" % [_minus(want, after),
		_minus(after, want)], after == want)


## Lift a nested window's part and put it down elsewhere; back.
func _case_lift_nested() -> void:
	print("\nlift_nested: a part of House#1's window lifted and put down beside the street")
	await _open_path(ModelStore.saved_path("Street"))
	var one: Array = _ids_at("House#1/Window#1").slice(0, 1)
	var part: String = _world.get_brick(int(one[0])).part_id
	_select(one)
	_verbs.lift()
	await _put_beside()
	await _frames(6)
	print("    after: %s" % ", ".join(_paths_now()))
	var text: String = await _save_reopen("Street lifted")
	var after: Dictionary = _counts(text)
	_check("reopened: 6 parts as before, %s moved (%s)" % [part, after], after == _counts(STREET))
	_builder.undo()


## The tower brought in while House#1 is being edited: House#2 follows.
func _case_into_entered() -> void:
	print("\ninto_entered: the tower brought in while editing House#1 of two")
	await _open_path(ModelStore.saved_path("Street"))
	_shell.assemblies.enter("House#1")
	await _frames(2)
	var said: String = await _say("open_model", {"into": true, "name": "Tower"})
	print("    MCP: " + said.left(200))
	await _frames(8)
	print("    after: %s" % ", ".join(_paths_now()))
	var before: Array = _snapshot()
	var units: Dictionary = _world.unit_steps.duplicate()
	_shell.assemblies.enter("")
	var text: String = await _save_reopen("Street towered")
	var after: Dictionary = _counts(text)
	print("    reopened counts: %s" % after)
	_same_world(before, units)
	_builder.undo()


## Over MCP: turn, x and z, a bad name, a spot with no room.
func _case_mcp_args() -> void:
	print("\nmcp_args: x, z, turn, a bad name, no room")
	await _open_path("res://models/car.ldr")
	var start: Array = _snapshot()
	var depth: int = _builder.history_depth()
	for input: Dictionary in [{"name": "Nope"}, {"name": ""}, {"link": "bad"},
			{"library": "zzzz-99"}, {"name": "Gatehouse", "x": 0, "z": 0}]:
		input["into"] = true
		var said: String = await _say("open_model", input)
		print("    %s -> %s" % [input, said.left(160)])
		_check("...the model as it was, nothing in hand, no step", _snapshot() == start
			and not _builder.is_carrying() and _builder.history_depth() == depth)
	var said: String = await _say("open_model", {"into": true, "name": "Gatehouse", "turn": 7,
		"x": 30, "z": -10})
	print("    turn 7 x 30 z -10 -> %s" % said.left(200))
	var before: Array = _snapshot()
	var units: Dictionary = _world.unit_steps.duplicate()
	await _save_reopen("Car turned gatehouse")
	_same_world(before, units)


## A part the file carries that draws nothing here: said, or kept?
func _case_unmeshed() -> void:
	print("\nunmeshed: a model carrying a part of its own made of a primitive the library has not got")
	await _open_path(ModelStore.saved_path("Odd"))
	var alone: Dictionary = _counts(await _save_reopen("Odd alone"))
	print("    Odd opened alone, saved, reopened: %s" % alone)
	await _open_path("res://models/car.ldr")
	var host: Dictionary = _counts(FileAccess.get_file_as_string("res://models/car.ldr"))
	var held: Dictionary = await _store.held_from(ODD, "odd.ldr", null, "Odd")
	print("    held_from: parts %d, missing %s, error \"%s\"" % [held["parts"], held["missing"], held["error"]])
	var said: String = await _say("open_model", {"into": true, "name": "Odd"})
	print("    MCP: " + said.left(300))
	var after: Dictionary = _counts(await _save_reopen("Car and odd"))
	var want: Dictionary = _plus(host, _counts(ODD))
	_check("Car and odd reopened: every part (lost: %s, gained: %s)" % [_minus(want, after),
		_minus(after, want)], after == want)


## The shack's Window deleted, the gatehouse taken in hand (its Window not
## renamed: none here now), the delete undone, the gatehouse put down.
func _case_undo_in_hand() -> void:
	print("\nundo_in_hand: Window deleted, gatehouse in hand, the delete undone, put down")
	await _open_path(ModelStore.saved_path("Shack"))
	var window: Array = _ids_at("Window#1")
	_check("the shack's Window#1 is a red 3002 (%s)" % _counts_of(window), _counts_of(window) == {"3002|4": 1})
	_select(window)
	_builder.remove_selection()
	await _frames(6)
	var held: int = await _bar.hold_text(FileAccess.get_file_as_string(GATEHOUSE), "gatehouse.mpd", "Gatehouse")
	_check("gatehouse in hand, %d parts" % held, held == 14)
	_builder.undo()
	await _frames(6)
	_check("the delete undone: Window#1 is back (%s), still in hand" % _counts_of(_ids_at("Window#1")),
		_ids_at("Window#1").size() == 1 and _builder.is_carrying())
	await _put_beside()
	await _frames(8)
	print("    after: %s" % ", ".join(_paths_now()))
	var shack_window: Dictionary = _counts_of(_ids_at("Window#1"))
	_check("the shack's Window#1 is still its red 3002 (%s)" % shack_window, shack_window == {"3002|4": 1})
	var after: Dictionary = _counts(await _save_reopen("Shack and gatehouse"))
	var want: Dictionary = _plus(_counts(SHACK), _counts(FileAccess.get_file_as_string(GATEHOUSE)))
	_check("reopened: every part of the shack and the gatehouse (lost: %s, gained: %s)" % [
		_minus(want, after), _minus(after, want)], after == want)


## As undo_in_hand, the shack's Window sharing a 3005 with the gatehouse's.
func _case_undo_in_hand2() -> void:
	print("\nundo_in_hand2: as undo_in_hand, the host's Window sharing a part with the gatehouse's")
	await _open_path(ModelStore.saved_path("Shack2"))
	var window: Array = _ids_at("Window#1")
	var had: Dictionary = _counts_of(window)
	_select(window)
	_builder.remove_selection()
	await _frames(6)
	var held: int = await _bar.hold_text(FileAccess.get_file_as_string(GATEHOUSE), "gatehouse.mpd", "Gatehouse")
	_builder.undo()
	await _frames(6)
	_check("in hand %d, the delete undone: Window#1 back (%s)" % [held, _counts_of(_ids_at("Window#1"))],
		_counts_of(_ids_at("Window#1")) == had and _builder.is_carrying())
	await _put_beside()
	await _frames(8)
	print("    after: %s" % ", ".join(_paths_now()))
	var now: Dictionary = _counts_of(_ids_at("Window#1"))
	_check("the shack's Window#1 is still %s (%s)" % [had, now], now == had)
	var after: Dictionary = _counts(await _save_reopen("Shack2 and gatehouse"))
	var want: Dictionary = _plus(_counts(SHACK2), _counts(FileAccess.get_file_as_string(GATEHOUSE)))
	_check("reopened: every part of the shack and the gatehouse (lost: %s, gained: %s)" % [
		_minus(want, after), _minus(after, want)], after == want)


## The pane from a file on this computer (no name given: its title, Window)
## into the hut, whose Window is all unshown.
func _case_pane_from_file() -> void:
	print("\npane_from_file: pane.ldr (titled Window, no steps) from a file into the hut")
	await _open_path(ModelStore.saved_path("Hut"))
	var held: int = await _bar.hold_text(PANE, "pane.ldr")
	await _put_beside()
	await _frames(6)
	print("    in hand %d; after: %s" % [held, ", ".join(_paths_now())])
	var text: String = await _save_reopen("Hut and pane file")
	var after: Dictionary = _counts(text)
	var want: Dictionary = _plus(_counts(HUT), _counts(PANE))
	_check("reopened: every part (lost: %s, gained: %s)" % [_minus(want, after), _minus(after, want)],
		after == want)
	var trees: Dictionary = _trees(text)
	print("    reopened file's parts by sub-model: %s" % trees)
	_check("...the pane's two bricks a sub-assembly of their own, not in the hut's Window with zz9003",
		not (trees.get("zz9003|1", []) as Array).any(func(chain: String) -> bool:
			return (trees.get("3001|14", []) as Array).has(chain)))
	print("    saved file:\n      " + text.replace("\n", "\n      "))


# -- helpers --------------------------------------------------------------------


func _keep(name: String, text: String) -> void:
	var path: String = ModelStore.saved_path(name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _file_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _open_path(path: String) -> void:
	_builder.cancel_carry()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _frames(10)


## Saved under [param name] and opened again from it: the file's text.
func _save_reopen(name: String) -> String:
	await _frames(4)
	_check("saved as %s" % name, _store.save_as(name))
	var text: String = _file_text(ModelStore.saved_path(name))
	await _open_path(ModelStore.saved_path(name))
	return text


## The file read as an open reads it: part|colour -> how many, shown or not.
func _counts(text: String) -> Dictionary:
	var model: LdrModel = LdrModel.parse(text, "model.ldr")
	CustomParts.take_into([], _library, model, null)
	var out: Dictionary = {}
	for placement: LdrModel.Placement in model.flatten(_library.parts):
		var part: String = ModelStore.studio_part(_library.resolve(placement.part_id), _library)
		var key: String = "%s|%d" % [part, placement.color_code]
		out[key] = int(out.get(key, 0)) + 1
	return out


## part|colour -> [definition chain of each], from the file.
func _trees(text: String) -> Dictionary:
	var model: LdrModel = LdrModel.parse(text, "model.ldr")
	var out: Dictionary = {}
	for placement: LdrModel.Placement in model.flatten(_library.parts):
		var key: String = "%s|%d" % [placement.part_id, placement.color_code]
		var chain: String = "/".join(Array(Assemblies.segments(Assemblies.path_from(placement.group,
			placement.unit))).map(func(s: String) -> String: return Assemblies.definition(s)))
		out[key] = (out.get(key, []) as Array) + [chain]
	return out


func _counts_of(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for brick_id: Variant in ids:
		var brick: BrickWorld.Brick = _world.get_brick(int(brick_id))
		var key: String = "%s|%d" % [brick.part_id, brick.color_code]
		out[key] = int(out.get(key, 0)) + 1
	return out


static func _plus(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate()
	for key: Variant in b:
		out[key] = int(out.get(key, 0)) + int(b[key])
	return out


## What [param a] has more of than [param b].
static func _minus(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in a:
		var more: int = int(a[key]) - int(b.get(key, 0))
		if more > 0:
			out[key] = more
	return out


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


## Every part: number, colour, sub-assembly path, step, and place against the
## lowest corner of all of them (an open stands the model on the ground).
func _snapshot() -> Array:
	var low := Vector3(INF, INF, INF)
	for brick: BrickWorld.Brick in _model():
		low = low.min(brick.transform.origin)
	var out: Array = []
	for brick: BrickWorld.Brick in _model():
		var at := Transform3D(brick.transform.basis, brick.transform.origin - low)
		out.append("%s %d %s step %d at %s" % [brick.part_id, brick.color_code,
			Assemblies.path_of(brick), brick.step, LdrModel._line_numbers(at)])
	out.sort()
	return out


func _same_world(before: Array, units: Dictionary) -> void:
	var now: Array = _snapshot()
	_check("reopened world: every part in its place, sub-assembly and step (%d vs %d)" % [
		now.size(), before.size()], now == before)
	if now != before:
		_diff(before, now)
	_check("...each copy's step: %s" % ("as put in" if _world.unit_steps == units
		else "%s, was %s" % [_world.unit_steps, units]), _world.unit_steps == units)


func _diff(want: Array, have: Array) -> void:
	var lost: Array = want.filter(func(s: String) -> bool: return not have.has(s))
	var gained: Array = have.filter(func(s: String) -> bool: return not want.has(s))
	for line: String in lost.slice(0, 12):
		print("      - " + line)
	for line: String in gained.slice(0, 12):
		print("      + " + line)


func _paths_now() -> Array:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _model():
		var path: String = Assemblies.path_of(brick)
		out[path] = int(out.get(path, 0)) + 1
	var said: Array = []
	for path: String in out:
		said.append("%s:%d" % [path if not path.is_empty() else "(model)", out[path]])
	said.sort()
	return said


func _ids_at(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _model():
		if Assemblies.path_of(brick) == path:
			out.append(brick.id)
	out.sort()
	return out


## Parts in each copy of the house, its window's with it.
func _houses() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _model():
		var path: String = Assemblies.path_of(brick)
		if path.is_empty():
			continue
		var top: String = Assemblies.segments(path)[0]
		if top in ["House#1", "House#2"]:
			out[top] = int(out.get(top, 0)) + 1
	return out


func _select(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: Variant in ids:
		_builder.select_brick(int(brick_id), true)


## What is in hand put down beside the model, as the MCP call aims it.
func _put_beside() -> Variant:
	var tools: Object = (_main.get("_connector") as ClaudeConnector).get("tools") \
		if (_main.get("_connector") as ClaudeConnector).get("tools") != null else null
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
			await _frames(4)
			return first if first != 0 else null
	print("    (nowhere to put it down)")
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


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
