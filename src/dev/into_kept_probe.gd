## A model brought into this one loses nothing (intomodel2, after imreview).
##
##   godot --headless --path . --script src/dev/into_kept_probe.gd
##
## File, Import, Into this model…, the library's Put in this model and MCP
## open_model into=true put a model into the one open whole. An independent
## review (imreview, 2026-11-06) found, by running, three ways it lost what a
## person had:
##   1. a host's sub-model of parts the app cannot show (a hut's "Window"
##      that is one part the library has not got) was replaced by a brought
##      one of the same name: a save wrote the gatehouse's window in its place
##      (lost zz9003, gained 3 parts); and a model titled "Window" brought from
##      a file had its bricks written into the hut's window;
##   2. the brought model's parts the library has not got were dropped (a shed
##      lost zz9001 and zz9002 to a save; a plain open keeps both);
##   3. its ROTSTEP views and its author line were not in the saved file.
##
## Each case here brings a model in (over MCP, or in hand from a file and put
## down beside), then checks the invariant: one undo takes it all out (the
## model as it was, part for part, and written so); redone, saved and opened
## again, the file has every part the host had, in place, in colour, in its
## sub-assembly and step, plus exactly the brought model's parts, each at one
## rigid placement of the model, in colour, in its sub-assembly and its
## author's step, those the app cannot show included; and saved again from
## that, the same. Then what the brief named beside: the brought model's
## ROTSTEP and its makers' credit in its own sections' headers, the files it
## carried for a part that could not be built, and every place a name is
## given (Make, Rename, a figure's group) taking a hidden sub-model's name as
## taken. Runs on the commit before the fix too, where cases 1-3 fail.
##
## `-- case,case` runs only those.
extends SceneTree

const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"
const CAR := "res://models/car.ldr"

## A host whose sub-model "Window" is only a part the library has not got.
const HUT := """0 FILE hut.ldr
0 Hut
0 Name: hut.ldr
0 Author: Brickworks
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -24 80 1 0 0 0 1 0 0 0 1 window.ldr
0 NOFILE
0 FILE window.ldr
0 Window
1 1 0 0 0 1 0 0 0 1 0 0 0 1 zz9003.dat
0 NOFILE
"""

## The hut again, someone else's, its window in a file of another name.
const LODGE := """0 FILE lodge.ldr
0 Lodge
0 Name: lodge.ldr
0 Author: A. Host
0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 0 0 -24 80 1 0 0 0 1 0 0 0 1 window.ldr
0 NOFILE
0 FILE window.ldr
0 Frame
0 Name: window.ldr
0 Author: A. Host
1 1 0 0 0 1 0 0 0 1 0 0 0 1 zz9003.dat
0 NOFILE
"""

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

## A model carrying a part of its own made of a primitive the library has not.
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

## A model with no steps titled Window, its parts all known.
const PANE := """0 FILE pane.ldr
0 Window
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 14 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"""

## A gallery model as the app wrote it: whose it is, only the gallery says.
const MILL := """0 FILE mill.ldr
0 Mill
0 Name: mill.ldr
0 Author: Brickworks
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -48 0 1 0 0 0 1 0 0 0 1 sail.ldr
0 NOFILE
0 FILE sail.ldr
0 Sail
0 Name: sail.ldr
0 Author: Brickworks
1 15 0 0 0 1 0 0 0 1 0 0 0 1 3004.dat
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
var _socket: Variant
var _rpc_id: int = 0
var _only: PackedStringArray = PackedStringArray()
## Counts for the report: parts checked by the invariant, cases.
var _parts_checked: int = 0
var _unshown_checked: int = 0
var _cases: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
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
	CustomParts.dir = OS.get_user_data_dir().path_join("into_kept_parts/")
	CustomParts.keeps = false
	_keep("Gatehouse", FileAccess.get_file_as_string(GATEHOUSE))
	for pair: Array in [["Hut", HUT], ["Lodge", LODGE], ["Shed", SHED], ["Odd", ODD],
			["Pane", PANE]]:
		_keep(pair[0], pair[1])
	for case: String in ["unshown_name", "unshown_path", "pane_from_file", "foreign_host",
			"unknown", "unmeshed", "shed_into_steps", "rotstep", "credited", "names",
			"landing"]:
		if not _only.is_empty() and not _only.has(case):
			continue
		_cases += 1
		await call("_case_" + case)
	print("")
	print("into_kept: %d cases, %d brought or kept parts checked by the invariant (%d the app cannot show)"
		% [_cases, _parts_checked, _unshown_checked])
	print("into_kept: %s" % ("all held" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- the three findings ----------------------------------------------------------


## 1. The gatehouse (its own "Window") into a hut whose Window is a part the
## library has not got.
func _case_unshown_name() -> void:
	print("\nunshown_name: the gatehouse into a hut whose Window is a part the library has not got")
	var text: String = await _invariant(ModelStore.saved_path("Hut"), _file(GATEHOUSE),
		func() -> void: await _say("open_model", {"into": true, "name": "Gatehouse"}))
	var trees: Dictionary = _trees(text)
	_check("...zz9003 still in the hut's own Window (%s)" % [trees.get("zz9003|1", [])],
		trees.get("zz9003|1", []) == ["Window"])


## 1, second form. A model titled Window over MCP into the hut.
func _case_unshown_path() -> void:
	print("\nunshown_path: a model titled Window (pane.ldr, as Pane) over MCP into the hut")
	var text: String = await _invariant(ModelStore.saved_path("Hut"), PANE,
		func() -> void: await _say("open_model", {"into": true, "name": "Pane"}))
	_apart(text)


## 1, second form, as imreview found it: pane.ldr from a file on this computer,
## no name given, so named by its title, Window.
func _case_pane_from_file() -> void:
	print("\npane_from_file: pane.ldr (titled Window) from a file into the hut, put down beside")
	var text: String = await _invariant(ModelStore.saved_path("Hut"), PANE, func() -> void:
		var held: int = await _bar.hold_text(PANE, "pane.ldr")
		_check("in hand: 2 parts (%d)" % held, held == 2)
		_check("put down", await _put_beside() != null))
	_apart(text)


## 1 in someone else's file: its window a file of another name ("Frame" in
## window.ldr), the gatehouse's Window brought in.
func _case_foreign_host() -> void:
	print("\nforeign_host: the gatehouse into A. Host's lodge, whose Frame (window.ldr) is a part the library has not got")
	var text: String = await _invariant(ModelStore.saved_path("Lodge"), _file(GATEHOUSE),
		func() -> void: await _say("open_model", {"into": true, "name": "Gatehouse"}))
	var trees: Dictionary = _trees(text)
	_check("...zz9003 still in the lodge's own Frame (%s)" % [trees.get("zz9003|1", [])],
		trees.get("zz9003|1", []) == ["Frame"])
	var heads: Dictionary = _heads(text)
	_check("...the lodge's own header still A. Host's, its licence too (%s)" % [heads.get("", [])],
		heads.get("", []).has("0 Author: A. Host")
		and heads.get("", []).has("0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt"))
	_check("...the gatehouse's sections A. Builder's, not A. Host's (%s)" % _authors(heads),
		_authors(heads).get("A. Builder", 0) == 3 and _authors(heads).get("A. Host", 0) == 2)


## 2. A shed with two parts the library has not got, one in a sub-model, into
## the car over MCP.
func _case_unknown() -> void:
	print("\nunknown: a shed with 2 parts the library has not got into the car over MCP")
	await _open_path(ModelStore.saved_path("Shed"))
	var alone: Dictionary = _counts(await _save_reopen("Shed alone"))
	_check("baseline: the shed opened and saved alone keeps zz9001 and zz9002 (%s)" % alone,
		int(alone.get("zz9001|1", 0)) == 1 and int(alone.get("zz9002|14", 0)) == 1)
	var said: Array = [""]
	var text: String = await _invariant(CAR, SHED, func() -> void:
		said[0] = await _say("open_model", {"into": true, "name": "Shed"}))
	print("    MCP: " + str(said[0]).left(320))
	_check("...MCP says the 2 are kept, not left out", str(said[0]).contains("not shown, kept")
		and not str(said[0]).contains("left out"))
	var trees: Dictionary = _trees(text)
	_check("...zz9002 in the shed's Roof (%s), zz9001 in the shed (%s)" % [
		trees.get("zz9002|14", []), trees.get("zz9001|1", [])],
		trees.get("zz9002|14", []) == ["Shed/Roof"] and trees.get("zz9001|1", []) == ["Shed"])


## 2. A part the file carries that the app could not build (its primitive is
## not in the library): kept, and its file with it.
func _case_unmeshed() -> void:
	print("\nunmeshed: a model carrying a part of a primitive the library has not got, into the car")
	var text: String = await _invariant(CAR, ODD,
		func() -> void: await _say("open_model", {"into": true, "name": "Odd"}))
	var model: LdrModel = LdrModel.parse(text, "x.ldr")
	_check("...the file it carried for oddpart is in the saved file", model.embedded_parts.has("oddpart.dat")
		and str(model.embedded_parts.get("oddpart.dat", "")).contains("nosuchprim.dat"))


## 2 into a model with steps: the shed's parts kept in the step it went on in.
func _case_shed_into_steps() -> void:
	print("\nshed_into_steps: the shed into the gatehouse, a model with steps")
	await _invariant(ModelStore.saved_path("Gatehouse"), SHED,
		func() -> void: await _say("open_model", {"into": true, "name": "Shed"}))


## 3. The gatehouse's ROTSTEP and its maker, into the car.
func _case_rotstep() -> void:
	print("\nrotstep: the gatehouse into the car: its ROTSTEP and its author kept")
	var text: String = await _invariant(CAR, _file(GATEHOUSE),
		func() -> void: await _say("open_model", {"into": true, "name": "Gatehouse"}))
	_check("the saved file keeps the gatehouse's 0 ROTSTEP 0 45 0 ABS (%d ROTSTEP lines)"
		% text.count("ROTSTEP"), text.contains("0 ROTSTEP 0 45 0 ABS"))
	var parsed: LdrModel = LdrModel.parse(text, "x.ldr")
	var looks: Dictionary = BookletLooks.read(text, parsed._assembly_names(),
		LdrModel._key(parsed.main.name))
	var turned: Array = []
	for key: String in looks:
		var turn: Variant = (looks[key] as Dictionary).get("turn") if looks[key] is Dictionary else null
		if turn is Array and (turn as Array).size() == 3 \
				and Vector3(turn[0], turn[1], turn[2]).is_equal_approx(Vector3(0, 45, 0)):
			turned.append(key)
	_check("...turning the gatehouse's own step, as its author had it (%s)" % [turned],
		turned.size() == 1 and str(turned[0]).begins_with("Gatehouse|"))
	var heads: Dictionary = _heads(text)
	_check("...the car's header James Jessiman's (%s)" % [heads.get("", [])],
		heads.get("", []).has("0 Author: James Jessiman"))
	_check("...the gatehouse, its base and its window A. Builder's (%s)" % _authors(heads),
		_authors(heads).get("A. Builder", 0) == 3)
	# Renamed, and a copy of its window made its own: still A. Builder's.
	var assemblies: Assemblies = _shell.get("assemblies")
	var castle: String = assemblies.rename(_path_to("Gatehouse", 1), "Castle")
	await _frames(2)
	_check("renamed Castle (%s): its maker with it (%s)" % [castle, _credits().keys()],
		castle == "Castle" and _credits().has("Castle") and not _credits().has("Gatehouse"))
	_builder.undo()
	await _frames(2)
	_check("...one undo: the gatehouse's again (%s)" % [_credits().keys()],
		_credits().has("Gatehouse") and not _credits().has("Castle"))
	_builder.redo()
	await _frames(2)
	var own: String = assemblies.make_unique(_path_to("Window", 2))
	var own_name: String = Assemblies.definition(Assemblies.leaf(own))
	await _frames(2)
	_check("a window made its own (%s): its maker with it (%s)" % [own, _credits().keys()],
		not own.is_empty() and _credits().has(own_name) and _credits().has("Window"))
	_builder.undo()
	await _frames(2)
	_check("...one undo: no maker for it (%s)" % [_credits().keys()],
		not _credits().has(own_name))
	_builder.redo()
	await _frames(2)
	var kept: Dictionary = _heads(await _save_reopen("Into car renamed"))
	_check("...saved: Castle and %s A. Builder's in their own sections (%s)" % [own_name,
		_authors(kept)], (kept.get("Castle", []) as Array).has("0 Author: A. Builder")
		and (kept.get(own_name, []) as Array).has("0 Author: A. Builder")
		and _authors(kept).get("A. Builder", 0) == 4)


## Whose each sub-model is (BrickWorld.credits), read by name: the commit
## before the fix keeps none.
func _credits() -> Dictionary:
	var credits: Variant = _world.get("credits")
	return credits if credits is Dictionary else {}


## The path to copy [param copy] of sub-model [param def] in the model, or ""
## when none: from the first part under it.
func _path_to(def: String, copy: int) -> String:
	for brick: BrickWorld.Brick in _model():
		var parts: PackedStringArray = Assemblies.segments(Assemblies.path_of(brick))
		for n: int in parts.size():
			if Assemblies.definition(parts[n]) == def and Assemblies.copy_of(parts[n]) == copy:
				return "/".join(parts.slice(0, n + 1))
	return ""


## 3. A gallery model the app wrote: its maker from the gallery, in its section.
func _case_credited() -> void:
	print("\ncredited: a gallery model the app wrote, its maker and licence from the gallery")
	var credited: Dictionary = {"by": "Jane Doe", "licence": "CC BY 4.0",
		"page": "https://brickworks.diy/m/abcde12345", "from": SharedModels.GALLERY}
	var takes: bool = false
	for method: Dictionary in _bar.get_method_list():
		if method["name"] == "hold_text" and (method["args"] as Array).size() >= 5:
			takes = true
	if not _check("hold_text takes the credit to keep", takes):
		return
	var text: String = await _invariant(CAR, MILL, func() -> void:
		# Called by name: the commit before the fix takes no credit to keep.
		var held: int = await _bar.call("hold_text", MILL, "abcde12345.mpd", "Mill",
			"credit Jane Doe, CC BY 4.0", credited)
		_check("in hand: 2 parts (%d)" % held, held == 2)
		_check("put down", await _put_beside() != null))
	var heads: Dictionary = _heads(text)
	var want: Array = ["0 Author: Jane Doe",
		"0 !LICENSE Licensed under CC BY 4.0 : see https://brickworks.diy/m/abcde12345"]
	_check("...the mill and its sail credited to Jane Doe under CC BY 4.0, linked (%s, %s)" % [
		heads.get("Mill", []), heads.get("Sail", [])], (heads.get("Mill", []) as Array).has(want[0])
		and (heads.get("Mill", []) as Array).has(want[1]) and (heads.get("Sail", []) as Array).has(want[0]))


# -- siblings: every place a name is given ---------------------------------------


## Make, Rename and a figure's group in the hut: "Window" is taken by its
## window of a part the library has not got.
func _case_names() -> void:
	print("\nnames: Make, Rename, Make unique and a figure's group in the hut, whose Window shows nothing")
	await _open_path(ModelStore.saved_path("Hut"))
	var assemblies: Assemblies = _shell.assemblies
	_check("Assemblies.unused_name(\"Window\") -> %s" % assemblies.unused_name("Window"),
		assemblies.unused_name("Window") == "Window 2")
	_check("Builder.unused_group(\"Window\") -> %s" % _builder.unused_group("Window"),
		_builder.unused_group("Window") == "Window 2")
	_check("next copy of Window -> %s" % assemblies.next_copy("Window"),
		assemblies.next_copy("Window") == "Window#2")
	var brick: Array = _model().map(func(b: BrickWorld.Brick) -> int: return b.id)
	_select(brick)
	var made: String = assemblies.make("Window")
	await _frames(4)
	_check("Make \"Window\" of the hut's brick -> %s" % made, made == "Window 2#1")
	var renamed: String = assemblies.rename(made, "Frame")
	await _frames(4)
	renamed = assemblies.rename("Frame#1", "Window")
	_check("renamed back to \"Window\" -> %s" % renamed, renamed == "Window 2")
	var text: String = await _save_reopen("Hut named")
	var trees: Dictionary = _trees(text)
	_check("reopened: zz9003 in Window, the brick in Window 2 (%s)" % [trees],
		trees.get("zz9003|1", []) == ["Window"] and trees.get("3001|4", []) == ["Window 2"])
	# A file name the model carries a sub-model in is taken too: the lodge's
	# Frame is in window.ldr.
	await _open_path(ModelStore.saved_path("Lodge"))
	_check("in the lodge, Window (its Frame's file) -> %s" % assemblies.unused_name("Window"),
		assemblies.unused_name("Window") == "Window 2")


## On the web a brought part whose geometry had not come lands when it does,
## in its sub-assembly and step; the undo that takes the model out takes it.
func _case_landing() -> void:
	print("\nlanding: a brought part with no geometry yet put down when it comes, taken out by the undo")
	if not _store.has_method("keep_brought"):
		_check("the store keeps a brought part it cannot show (keep_brought)", false)
		return
	await _open_path(CAR)
	var start: Array = _snapshot()
	var placement := LdrModel.Placement.new("3005", 14, Transform3D(Basis.IDENTITY,
		Vector3(400, -24, 0)), 2)
	placement.group = "Lamp"
	placement.unit = "Lamp#1/Bulb#1"
	var waiting: Array[LdrModel.Placement] = [placement]
	_store.set("brought", waiting)
	_store.set("_brought_in", _world.generation())
	var landed: int = _store.place_awaited("3005")
	var down: Array = _model().filter(func(b: BrickWorld.Brick) -> bool:
		return b.part_id == "3005" and b.color_code == 14)
	_check("arrived: put down once (%d), in Lamp#1/Bulb#1, step 2 (%s)" % [landed,
		down.map(func(b: BrickWorld.Brick) -> String: return "%s step %d" % [b.unit, b.step])],
		landed == 1 and down.size() == 1 and (down[0] as BrickWorld.Brick).unit == "Lamp#1/Bulb#1"
		and (down[0] as BrickWorld.Brick).step == 2)
	_check("...no longer waiting", _store.get("brought").is_empty())
	_store.call("keep_brought", [placement], false)
	_check("let go (the undo): the landed part taken off too", _snapshot() == start)
	_store.call("keep_brought", [placement], true)
	_check("kept again (the redo): its geometry here, down at once (%d of 3005|14)" % _model().filter(
		func(b: BrickWorld.Brick) -> bool: return b.part_id == "3005" and b.color_code == 14).size(),
		_model().filter(func(b: BrickWorld.Brick) -> bool:
			return b.part_id == "3005" and b.color_code == 14).size() == 1)
	_store.call("keep_brought", [placement], false)


# -- the invariant -----------------------------------------------------------------


## [param host] opened, [param bring] run (it brings [param brought] in and
## puts it down), then: one undo takes it all out; redone, saved, reopened,
## the file is the host's parts in place plus the brought model's at one
## placement; saved and reopened again, the same. The first save's text.
func _invariant(host: String, brought: String, bring: Callable) -> String:
	await _open_path(host)
	var host_text: String = _file(host)
	var host_parts: Array = _placed(host_text)
	var before: Array = _snapshot()
	var before_units: Dictionary = _world.unit_steps.duplicate()
	var before_looks: Dictionary = _world.step_looks.duplicate(true)
	var before_credits: Dictionary = _credits().duplicate(true)
	var depth: int = _builder.history_depth()
	await bring.call()
	await _frames(6)
	_check("brought in, put down, one step (%d -> %d)" % [depth, _builder.history_depth()],
		_builder.history_depth() == depth + 1 and not _builder.is_carrying())
	var brought_snapshot: Array = _snapshot()
	# One undo: as it was, and written so.
	_builder.undo()
	await _frames(4)
	var kept: Variant = _store.get("brought")
	_check("one undo: every part, place, sub-assembly and step as before (%d vs %d; %s)"
		% [_snapshot().size(), before.size(), _difference(_tally(before), _tally(_snapshot()))],
		_snapshot() == before)
	_check("...the sub-assemblies' steps as before (%s -> %s)" % [before_units, _world.unit_steps],
		_world.unit_steps == before_units)
	_check("...the booklet's views as before (%s -> %s)" % [before_looks.keys(),
		_world.step_looks.keys()], _world.step_looks == before_looks)
	_check("...whose each sub-model is as before (%s)" % [_credits().keys()],
		_credits() == before_credits)
	_check("...nothing it could not show kept (%s)" % [kept], kept == null or (kept as Array).is_empty())
	_check("...and written so: the host's parts, no more (%s)" % _difference(_counts_of_placed(
		host_parts), _counts(_store.to_text("Undone"))),
		_counts(_store.to_text("Undone")) == _counts_of_placed(host_parts))
	_builder.redo()
	await _frames(4)
	_check("redo: as brought (%d parts)" % _snapshot().size(), _snapshot() == brought_snapshot)
	var text: String = await _save_reopen("Into " + host.get_file().get_basename())
	_holds(text, host_parts, _placed(brought), _authored(host_text), _authored(brought))
	var again: String = await _save_reopen("Into " + host.get_file().get_basename() + " again")
	_check("saved again from the reopened file: the same parts (%s)" % _difference(_counts(text),
		_counts(again)), _counts(again) == _counts(text))
	_check("...and the same makers (%s)" % _authors(_heads(again)),
		_authors(_heads(again)) == _authors(_heads(text)))
	return text


## The saved [param text] has every one of [param host]'s parts in place
## (its file's coordinates), colour, sub-assembly and step (where the host had
## steps of its own), and exactly [param brought]'s besides: each in colour,
## in its sub-assembly under the whole, in its author's step, at one rigid
## placement of all of them.
func _holds(text: String, host: Array, brought: Array, host_steps: bool, brought_steps: bool) -> void:
	var left: Array = _placed(text)
	var lost: Array = []
	for want: Dictionary in host:
		var found: int = -1
		for n: int in left.size():
			var have: Dictionary = left[n]
			if have["key"] == want["key"] and have["chain"] == want["chain"] \
					and (have["at"] as Transform3D).origin.distance_to((want["at"] as Transform3D).origin) < 0.01 \
					and (not host_steps or have["step"] == want["step"]):
				found = n
				break
		if found < 0:
			lost.append("%s in %s" % [want["key"], want["chain"]])
		else:
			left.remove_at(found)
	_check("reopened: the host's %d parts, each in place, colour and sub-assembly%s (lost: %s)" % [
		host.size(), ", step" if host_steps else "", lost], lost.is_empty())
	# The rest is the brought model, at one placement: found from its first
	# part, tried at each of the rest that could be it.
	var best: Array = []
	var anchor: Dictionary = brought[0]
	for candidate: Dictionary in left:
		if candidate["key"] != anchor["key"]:
			continue
		var frame: Transform3D = (candidate["at"] as Transform3D) * (anchor["at"] as Transform3D).affine_inverse()
		var pool: Array = left.duplicate()
		var missed: Array = []
		for want: Dictionary in brought:
			var at: Transform3D = frame * (want["at"] as Transform3D)
			var found: int = -1
			for n: int in pool.size():
				var have: Dictionary = pool[n]
				if have["key"] == want["key"] and _under_whole(str(have["chain"])) == _bare(str(want["chain"])) \
						and (have["at"] as Transform3D).origin.distance_to(at.origin) < 0.05 \
						and (not brought_steps or have["step"] == want["step"]):
					found = n
					break
			if found < 0:
				missed.append("%s in %s step %d" % [want["key"], want["chain"], want["step"]])
			else:
				pool.remove_at(found)
		if best.is_empty() or missed.size() < (best[0] as Array).size():
			best = [missed, pool]
		if missed.is_empty():
			break
	var missed_all: Array = best[0] if not best.is_empty() else brought.map(_key_of)
	var extra: Array = (best[1] as Array).map(_said) if not best.is_empty() else left.map(_said)
	var unshown: int = brought.filter(_not_shown).size()
	_check(("...and the brought model's %d (%d the app cannot show), at one placement, in colour, "
		+ "sub-assembly%s (lost: %s, more: %s)") % [brought.size(), unshown,
		" and step" if brought_steps else "", missed_all, extra],
		missed_all.is_empty() and extra.is_empty())
	_parts_checked += host.size() + brought.size()
	_unshown_checked += unshown


func _key_of(entry: Dictionary) -> String:
	return str(entry["key"])


func _said(entry: Dictionary) -> String:
	return "%s in %s" % [entry["key"], entry["chain"]]


## Whether the app cannot show [param entry]'s part.
func _not_shown(entry: Dictionary) -> bool:
	var part: String = str(entry["key"]).get_slice("|", 0)
	return not _library.parts.has(part) or _library.mesh_for(part) == null


## The pane's two bricks a sub-assembly of their own, not in the hut's Window.
func _apart(text: String) -> void:
	var trees: Dictionary = _trees(text)
	_check("...the pane's bricks a sub-assembly of their own (%s), zz9003 alone in Window (%s)" % [
		trees.get("3001|14", []), trees.get("zz9003|1", [])],
		trees.get("zz9003|1", []) == ["Window"] and not (trees.get("3001|14", []) as Array).has("Window"))


# -- helpers --------------------------------------------------------------------


func _keep(name: String, text: String) -> void:
	var path: String = ModelStore.saved_path(name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _file(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _authored(text: String) -> bool:
	return LdrModel.parse(text, "x.ldr").steps_are_authored()


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
	var text: String = _file(ModelStore.saved_path(name))
	await _open_path(ModelStore.saved_path(name))
	return text


## Every part [param text] places as an open reads it, shown or not:
## {key "part|colour", chain (its sub-models' definitions), at, step}.
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


## A chain without its first definition (the whole brought in), each name
## as the file it came from had it ("Window 2" was "Window").
func _under_whole(chain: String) -> String:
	var parts: PackedStringArray = chain.split("/", false)
	return _bare("/".join(parts.slice(1)))


static func _bare(chain: String) -> String:
	var out: Array = []
	for name: String in chain.split("/", false):
		var words: PackedStringArray = name.split(" ")
		if words.size() > 1 and words[words.size() - 1].is_valid_int():
			name = " ".join(words.slice(0, words.size() - 1))
		out.append(name)
	return "/".join(out)


func _counts(text: String) -> Dictionary:
	return _counts_of_placed(_placed(text))


static func _counts_of_placed(placed: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in placed:
		out[entry["key"]] = int(out.get(entry["key"], 0)) + 1
	return out


## Each line of [param lines] -> how many times: a snapshot as counts.
static func _tally(lines: Array) -> Dictionary:
	var out: Dictionary = {}
	for line: Variant in lines:
		out[line] = int(out.get(line, 0)) + 1
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


## part|colour -> [definition chain of each], from the file.
func _trees(text: String) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in _placed(text):
		out[entry["key"]] = (out.get(entry["key"], []) as Array) + [entry["chain"]]
	return out


## Each section's title -> its header's credit lines (Author, !LICENSE), the
## model's own under "" too.
static func _heads(text: String) -> Dictionary:
	var out: Dictionary = {}
	var title: String = ""
	var head: bool = false
	var after_file: bool = false
	var first: bool = true
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 FILE "):
			after_file = true
			head = true
			continue
		if after_file and line.begins_with("0 ") and not line.begins_with("0 !BRICKWORKS"):
			title = line.substr(2).strip_edges()
			out[title] = []
			if first:
				out[""] = out[title]
				first = false
			after_file = false
			continue
		if line.begins_with("1 ") or SourceFile._is_step(line) or line == "0 NOFILE":
			head = false
		if head and not title.is_empty() and (line.begins_with("0 Author:") or line.begins_with("0 !LICENSE")):
			(out[title] as Array).append(line)
	return out


## How many sections each author is credited with.
static func _authors(heads: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for title: String in heads:
		if title.is_empty():
			continue
		for line: String in heads[title]:
			if line.begins_with("0 Author:"):
				var by: String = line.substr(9).strip_edges()
				out[by] = int(out.get(by, 0)) + 1
	return out


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


## Every part: number, colour, sub-assembly path, step, and place against the
## lowest corner of all of them.
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


func _select(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: Variant in ids:
		_builder.select_brick(int(brick_id), true)


## What is in hand put down beside the model, as the MCP call aims it.
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
