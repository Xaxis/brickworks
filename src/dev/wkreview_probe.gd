## wkreview: an independent review of wholekeep's whole save (a save written
## whole keeps what the file carried). Each case opens a file, makes one edit
## as a person makes it, saves as Save does (ModelStore.to_text with steps),
## and holds the text to what the file had: every line the reader skips, as
## often as the file had it (but the lines of what the edit took off), each
## line that says what the next line is (TEXMAP NEXT, LDCad's GROUP_NXT, BFC
## INVERTNEXT) still before the part or copy it was before, and nothing else;
## then opened again (the same parts), saved again (byte for byte) and the
## edit undone (the file's lines again).
##
##   godot --headless --path . --script src/dev/wkreview_probe.gd
##   WKR_CASES=remove_tile,frame   those cases only
##
## The same file runs on pre261 (wholekeep's base) for the comparison: there
## every kept line is lost at a whole write, so its "lost" lists are long;
## what matters here is what this branch moves, duplicates or invents.
extends SceneTree

## A picture, one pixel, as a !DATA section carries it.
const PIXEL := "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

## Someone else's MPD: a printed tile (TEXMAP NEXT), a plate in an LDCad
## group (GROUP_NXT), a printed panel (START / !: / FALLBACK / END), a frame
## sub-model that holds only another sub-model (no part of its own), a roof
## placed once, comments before each.
const HOUSE := """0 FILE wr_house.ldr
0 Review house
0 Name: wr_house.ldr
0 Author: Jane Builder
0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt

0 // the floor
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 // the printed tile
0 !TEXMAP NEXT PLANAR -20 -32 -10 20 -32 -10 -20 -32 10 sign.png
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3068b.dat
1 14 60 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat
0 !LDCAD GROUP_NXT [ids=1] [nrs=-1]
1 1 0 -24 -60 1 0 0 0 1 0 0 0 1 3024.dat
1 1 60 -24 -60 1 0 0 0 1 0 0 0 1 3023.dat
0 // the panel, printed
0 !TEXMAP START PLANAR -80 -48 -70 -40 -48 -70 -80 -24 -70 panel.png
0 !: 1 15 -60 -24 -60 1 0 0 0 1 0 0 0 1 4865b.dat
0 !TEXMAP FALLBACK
1 15 -60 -24 -60 1 0 0 0 1 0 0 0 1 4865b.dat
0 !TEXMAP END
0 // the frame holds the wing
0 !LDCAD GROUP_NXT [ids=2] [nrs=-1]
1 16 -200 -24 100 1 0 0 0 1 0 0 0 1 frame.ldr
0 // the roof
0 !LDCAD GROUP_NXT [ids=3] [nrs=-1]
1 16 200 -24 100 1 0 0 0 1 0 0 0 1 roof.ldr
1 7 -40 0 -200 1 0 0 0 1 0 0 0 1 3005.dat
1 7 -20 0 -200 1 0 0 0 1 0 0 0 1 3005.dat
0 NOFILE
0 FILE frame.ldr
0 Frame
0 Name: frame.ldr
0 Author: Jane Builder
1 16 0 0 0 1 0 0 0 1 0 0 0 1 wing.ldr
0 NOFILE
0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
0 Author: Jane Builder
0 // a wing: a plate and a brick
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3010.dat
0 NOFILE
0 FILE roof.ldr
0 Roof
0 Name: roof.ldr
0 Author: Jane Builder
0 // a roof: a plate and a brick on it
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3010.dat
0 NOFILE
0 !DATA sign.png
0 !: %s
0 !DATA panel.png
0 !: %s
""" % [PIXEL, PIXEL]

## Someone else's stepped file with an LPub MULTI_STEP round three steps.
const STEPS := """0 FILE wr_steps.ldr
0 Stepped
0 Name: wr_steps.ldr
0 Author: Jane Builder

1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
0 !LPUB MULTI_STEP BEGIN
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 14 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 1 0 -72 0 1 0 0 0 1 0 0 0 1 3003.dat
0 !LPUB MULTI_STEP END
0 STEP
1 7 -40 0 -100 1 0 0 0 1 0 0 0 1 3005.dat
1 7 -20 0 -100 1 0 0 0 1 0 0 0 1 3005.dat
0 NOFILE
"""

## The app's own file whose two wings are built in its steps and keep their
## sections (wholekeep_probe's BUILT): a copy pasted beside them has steps of
## its own (wholekeep's known limit: the other two go after IN lines).
const BUILT := """0 FILE wk_built.ldr
0 Built house
0 Name: wk_built.ldr
0 Author: Brickworks
0 !BRICKWORKS AUTHORED_STEPS
0 // the app's own file, its wings built a course of each in turn
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3068b.dat
0 // the first wing
0 !BRICKWORKS BUILT 0=0 1=2
1 16 -100 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr
0 STEP
0 // the second wing
0 !BRICKWORKS BUILT 0=1 1=3
0 !BRICKWORKS COPY 2
1 16 180 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr
0 STEP
0 STEP
1 7 -40 0 -60 1 0 0 0 1 0 0 0 1 3005.dat
1 7 -20 0 -60 1 0 0 0 1 0 0 0 1 3005.dat
1 14 30 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat
0 NOFILE
0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
0 Author: Brickworks
0 // a wing: a plate and its engine
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
0 STEP
0 // its engine, under the plate
0 !BRICKWORKS BUILT 0=1
1 16 0 8 0 1 0 0 0 1 0 0 0 1 engine.ldr
0 NOFILE
0 FILE engine.ldr
0 Engine
0 Name: engine.ldr
0 Author: Brickworks
0 // the engine's printed round brick
0 !TEXMAP NEXT PLANAR -10 0 -10 10 0 -10 -10 0 10 sign.png
1 0 0 0 0 1 0 0 0 1 0 0 0 1 3062b.dat
1 71 0 24 0 1 0 0 0 1 0 0 0 1 3005.dat
0 NOFILE
0 !DATA sign.png
0 !: %s
""" % PIXEL

## The app's own file with a wing placed twice, a printed tile in it.
const TWICE := """0 FILE wr_twice.ldr
0 Twice
0 Name: wr_twice.ldr
0 Author: Brickworks

1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 // the two wings
1 16 -100 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr
1 16 180 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr
0 NOFILE
0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
0 Author: Brickworks

1 2 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
0 // the wing's printed tile
0 !TEXMAP NEXT PLANAR -20 -8 -10 20 -8 -10 -20 -8 10 sign.png
1 15 0 -8 0 1 0 0 0 1 0 0 0 1 3068b.dat
0 NOFILE
0 !DATA sign.png
0 !: %s
""" % PIXEL

## The app's own file whose sections' heads say a line twice (a note ruled
## off above and below): each written as often as the file had it.
const HEADS := """0 FILE wr_heads.ldr
0 Heads
0 Name: wr_heads.ldr
0 Author: Brickworks
0 // ----------
0 // the model
0 // ----------
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 box.ldr
1 7 -40 0 -100 1 0 0 0 1 0 0 0 1 3005.dat
0 NOFILE
0 FILE box.ldr
0 Box
0 Name: box.ldr
0 Author: Brickworks
0 // ==========
0 // a box
0 // ==========
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
0 // a note
1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3010.dat
0 // a note
1 2 40 -24 0 1 0 0 0 1 0 0 0 1 3010.dat
0 NOFILE
"""

## The app's own file with lines of geometry in a sub-model's section (an
## edge and a quad drawn over a tile) and a sub-model with nothing in it.
const GEOM := """0 FILE wr_geom.ldr
0 Geom
0 Name: wr_geom.ldr
0 Author: Brickworks

1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 sticker.ldr
1 16 100 -24 0 1 0 0 0 1 0 0 0 1 empty.ldr
1 7 -40 0 -100 1 0 0 0 1 0 0 0 1 3005.dat
0 NOFILE
0 FILE sticker.ldr
0 Sticker
0 Name: sticker.ldr
0 Author: Brickworks

1 15 0 0 0 1 0 0 0 1 0 0 0 1 3068b.dat
2 24 -20 -8 -20 20 -8 -20
4 4 -10 -8.1 -10 10 -8.1 -10 10 -8.1 10 -10 -8.1 10
0 NOFILE
0 FILE empty.ldr
0 Empty
0 Name: empty.ldr
0 Author: Brickworks
0 // nothing here yet
0 NOFILE
"""

## The app's own file with a wing placed twice (the second turned), each
## with an engine of three round bricks nested in it: more of the engine's
## parts than the wing's own, so they outvote them where they are counted
## for the wing.
const NESTED := """0 FILE wr_nested.ldr
0 Nested twice
0 Name: wr_nested.ldr
0 Author: Brickworks

1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 -100 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr
1 16 180 -24 0 0 0 1 0 1 0 -1 0 0 wing.ldr
0 NOFILE
0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
0 Author: Brickworks

1 2 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
1 2 40 -24 0 1 0 0 0 1 0 0 0 1 3005.dat
1 16 -20 -24 0 1 0 0 0 1 0 0 0 1 engine.ldr
0 NOFILE
0 FILE engine.ldr
0 Engine
0 Name: engine.ldr
0 Author: Brickworks

1 0 0 0 0 1 0 0 0 1 0 0 0 1 3062b.dat
1 71 0 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat
1 71 0 -48 0 1 0 0 0 1 0 0 0 1 3062b.dat
0 NOFILE
"""

## [name, file, edit, the kept lines the edit takes with it (by their
## normalised text, [method _kept_counts]), the binding lines it takes ([method
## _binds])].
const CASES: Array = [
	# A control: someone else's file written whole with no other change.
	["plan_only", "house_other", "plan", [], []],
	# A copy with no part of its own (the frame holds only the wing): its
	# comment and GROUP_NXT stay before its line.
	["frame", "house_own", "add", [], []],
	# A part taken off: the line saying what it is goes with it, never onto
	# the next part.
	["remove_tile", "house_own", "remove_tile",
		["0 // the printed tile", "0 !TEXMAP NEXT PLANAR # # # # # # # # # sign.png"],
		["!TEXMAP NEXT -> 3068b.dat"]],
	["remove_plate", "house_own", "remove_plate", ["0 !LDCAD GROUP_NXT [ids=1] [nrs=-1]"],
		["GROUP_NXT [ids=1] -> 3024.dat"]],
	["remove_tile_other", "house_other", "plan+remove_tile",
		["0 // the printed tile", "0 !TEXMAP NEXT PLANAR # # # # # # # # # sign.png"],
		["!TEXMAP NEXT -> 3068b.dat"]],
	# A sub-assembly made inside a copy: the lines before the copy's own line
	# stay there, once.
	["make_in_roof", "house_own", "make_in_roof", [], []],
	# The printed panel's part swapped or painted: its texture-only geometry
	# ("0 !:") says the part and colour the model now has.
	["swap_fallback", "house_own", "swap_fallback", [], []],
	["recolour_fallback", "house_own", "recolour_fallback", [], []],
	# A whole write of a stepped file: LPub's MULTI_STEP still round its steps.
	["multistep_other", "steps_other", "make_pair", [], []],
	["multistep_own", "steps_own", "add", [], []],
	# wholekeep's known limit: a wing pasted with steps of its own beside two
	# built in the model's.
	["paste_built", "built", "paste", [], []],
	# One of two copies taken apart: its printed tile still printed, once.
	["ungroup_one", "twice", "ungroup_one", [], []],
	# A head that says a line twice: both written (_write_one skips a head
	# line the section's lines have already).
	["heads", "heads", "add", [], []],
	# Geometry in a sub-model's section and an empty sub-model: kept by
	# neither build's whole write (a NOTE where pre261 loses them too).
	["geom", "geom", "add", [], []],
	# The save that patches someone else's file: the tile moved, its TEXMAP
	# NEXT's points where they stood from it (wholekeep: left behind).
	["patch_move_tile", "house_other", "move_tile", [], []],
	# The engine taken apart in one wing: each wing's frame as the file gave
	# it (Assemblies._read_frames), the edited wing's line where it was.
	["apart_nested", "nested", "apart_engine", [], []],
]

## Each copy's frame as the file gave it before the edit (Assemblies
## ._read_frames, wholekeep's; {} on a build without it).
var _frames_before: Dictionary = {}

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: Variant = _main.get("_playback")
	if playback != null:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_shell = _main.get("_shell")
	var only: String = OS.get_environment("WKR_CASES")
	var wanted: PackedStringArray = only.split(",", false)
	for case: Array in CASES:
		if not wanted.is_empty() and not wanted.has(str(case[0])):
			continue
		await _case(str(case[0]), _file(str(case[1])), str(case[2]), case[3], case[4])
	print("\nwkreview probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


func _file(which: String) -> String:
	match which:
		"house_other":
			return HOUSE
		"house_own":
			return HOUSE.replace("Jane Builder", "Brickworks")
		"steps_other":
			return STEPS
		"steps_own":
			return STEPS.replace("Jane Builder", "Brickworks").replace("0 Author: Brickworks\n",
				"0 Author: Brickworks\n0 !BRICKWORKS AUTHORED_STEPS\n")
		"built":
			return BUILT
		"twice":
			return TWICE
		"heads":
			return HEADS
		"geom":
			return GEOM
		"nested":
			return NESTED
	return ""


# -- a case ------------------------------------------------------------------


func _case(name: String, text: String, edit: String, gone: Array, gone_binds: Array) -> void:
	print("\n== %s (%s)" % [name, edit])
	await _open(text)
	var depth: int = _builder.history_depth()
	var made: String = ""
	for step: String in edit.split("+"):
		made = await _edit(step)
		if not made.is_empty():
			break
	if not made.is_empty():
		_check("%s: the edit was made (%s)" % [name, made], false)
		return
	var edited: Array = _parts()
	var saved: String = _store.to_text("model", true)
	_keep(name, text, saved)
	print("  saved: %d lines (the file %d), %s" % [saved.split("\n").size(),
		text.split("\n").size(), "written whole" if not str(_store.get("last_whole")).is_empty()
		or _store.call("_live_source") == null else "a patch"])
	# Saved twice in a row, nothing between: the same text.
	var twice: String = _store.to_text("model", true)
	if not _check("%s: saved twice in a row, the same text" % name, twice == saved):
		_keep(name + ".twice", saved, twice)

	# Every kept line as often as the file had it, but those the edit took.
	var want: Dictionary = _kept_counts(text)
	for line: String in gone:
		want[line] = int(want.get(line, 0)) - 1
	var diff: Array = _diff(want, _kept_counts(saved))
	_check("%s: the file's lines, each as often as it had them%s" % [name,
		"" if diff[0].is_empty() and diff[1].is_empty()
		else "\n      lost: %s\n      more: %s" % [str(diff[0]), str(diff[1])]],
		diff[0].is_empty() and diff[1].is_empty())

	# Each line that says what the next line is still says it of the same.
	var binds_want: Array = _binds(text)
	for bind: String in gone_binds:
		binds_want.erase(bind)
	var binds_now: Array = _binds(saved)
	var bdiff: Array = _diff(_counted(binds_want), _counted(binds_now))
	_check("%s: each TEXMAP NEXT / GROUP_NXT / INVERTNEXT before what it was before%s" % [name,
		"" if bdiff[0].is_empty() and bdiff[1].is_empty()
		else "\n      the file's: %s\n      now: %s" % [str(binds_want), str(binds_now)]],
		bdiff[0].is_empty() and bdiff[1].is_empty())

	_case_facts(name, saved)

	# Opened again: the same parts; saved again: the same text.
	await _open(saved)
	var now: Array = _parts()
	var unlike: Array = _unlike(edited, now)
	_check("%s: opened again, %d of %d parts not as saved%s" % [name, unlike.size(),
		edited.size(), "" if unlike.is_empty() else ": " + str(unlike.slice(0, 3))],
		unlike.is_empty())
	var again: String = _store.to_text("model", true)
	var adiff: Array = _diff(_kept_counts(saved), _kept_counts(again))
	_check("%s: saved again, the same lines%s (%d lines, %d before; byte for byte: %s)" % [name,
		"" if adiff[0].is_empty() and adiff[1].is_empty()
		else ": lost %s, more %s" % [str(adiff[0]), str(adiff[1])],
		again.split("\n").size(), saved.split("\n").size(), str(again == saved)],
		adiff[0].is_empty() and adiff[1].is_empty())
	if not _check("%s: saved again byte for byte" % name, again == saved):
		_keep(name + ".again", saved, again)

	# Undone: the file's lines again.
	await _open(text)
	for step: String in edit.split("+"):
		await _edit(step)
	while _builder.history_depth() > depth:
		_builder.undo()
	await _frames(4)
	var undone: String = _store.to_text("model", true)
	var udiff: Array = _diff(_kept_counts(text), _kept_counts(undone))
	var ubinds: Array = _diff(_counted(_binds(text)), _counted(_binds(undone)))
	_check("%s: undone, the file's lines and bindings again%s" % [name,
		"" if udiff[0].is_empty() and udiff[1].is_empty() and ubinds[0].is_empty() \
			and ubinds[1].is_empty()
		else ": lost %s, more %s; bindings lost %s, more %s" % [str(udiff[0]), str(udiff[1]),
			str(ubinds[0]), str(ubinds[1])]],
		udiff[0].is_empty() and udiff[1].is_empty() and ubinds[0].is_empty() and ubinds[1].is_empty())


## What a case says beyond its lines: where its blocks and lines went.
func _case_facts(name: String, saved: String) -> void:
	match name:
		"frame":
			var after: String = _next_line(saved, "0 // the frame holds the wing")
			_check("frame: its comment still before the frame's line (before: %s)" % after,
				after.contains("GROUP_NXT [ids=2]") or after.to_lower().ends_with("frame.ldr"))
		"swap_fallback", "recolour_fallback":
			var shown: String = _after_word(saved, "0 !TEXMAP FALLBACK")
			var textured: String = ""
			for line: String in saved.split("\n"):
				if line.strip_edges().begins_with("0 !: 1 "):
					textured = line.strip_edges().substr(5)
			var a: PackedStringArray = shown.split(" ", false)
			var b: PackedStringArray = textured.split(" ", false)
			var same: bool = a.size() >= 15 and b.size() >= 15 and a[1] == b[1] \
				and a[a.size() - 1].to_lower() == b[b.size() - 1].to_lower()
			_check("%s: the panel's texture-only line says the part and colour it falls back to"
				% name + "\n      !: %s\n      fallback: %s" % [textured, shown], same)
		"multistep_other", "multistep_own":
			var inside: Array = _between(saved, "0 !LPUB MULTI_STEP BEGIN", "0 !LPUB MULTI_STEP END")
			var steps: int = inside.filter(func(l: String) -> bool: return l == "0 STEP").size()
			var bricks: int = inside.filter(func(l: String) -> bool:
				return l.to_lower().ends_with("3003.dat")).size()
			_check("%s: MULTI_STEP still round its three steps (%d STEP lines and %d of its 3003s "
				% [name, steps, bricks] + "inside: %s)" % str(inside), steps == 2 and bricks == 3)
		"geom":
			# The section's geometry and the empty sub-model, as the file had them.
			var lines: PackedStringArray = saved.replace("\r", "").split("\n")
			var edge: int = 0
			var quad: int = 0
			var empty: int = 0
			for line: String in lines:
				var said: String = line.strip_edges()
				edge += 1 if said.begins_with("2 24 ") else 0
				quad += 1 if said.begins_with("4 4 ") else 0
				empty += 1 if said.to_lower().ends_with(" empty.ldr") and said.begins_with("1 ") else 0
			_check("geom: the sticker's edge and quad lines kept (%d of 1, %d of 1)" % [edge, quad],
				edge == 1 and quad == 1)
			_check("geom: the empty sub-model still placed (%d of 1)" % empty, empty == 1)
		"patch_move_tile", "remove_plate", "plan_only":
			# The tile's TEXMAP NEXT where it stands from the tile: its first
			# point (-20, -8, -10) from the tile's place in the file.
			var from: String = _texmap_from_part(saved)
			_check("%s: the tile's TEXMAP NEXT where it stands from the tile (%s, the file's -20 -8 -10)"
				% [name, from], from == "-20 -8 -10")
		"apart_nested":
			var now: Dictionary = _read_frames_now()
			if _frames_before.is_empty():
				print("  (no Assemblies._read_frames on this build)")
			for path: String in _frames_before:
				var was: Variant = _frames_before[path]
				var is_now: Variant = now.get(path)
				var same: bool = was is Transform3D and is_now is Transform3D \
					and (was as Transform3D).is_equal_approx(is_now as Transform3D)
				_check("apart_nested: %s's frame as the file gave it, after the engine was taken apart"
					% path + "\n      before %s\n      after  %s" % [str(was), str(is_now)],
					same or Assemblies.parent_of(path) != "")
			# The edited wing (a definition of its own now) where the file placed it.
			var placed: int = 0
			for line: String in saved.replace("\r", "").split("\n"):
				if line.strip_edges().begins_with("1 16 -100 -24 0 1 0 0 0 1 0 0 0 1 "):
					placed += 1
			_check("apart_nested: a copy still placed where the file placed the first wing "
				+ "(1 16 -100 -24 0 ...: %d)" % placed, placed == 1)
		"paste_built", "ungroup_one", "make_in_roof":
			for needle: String in ["0 // its engine, under the plate", "0 // a wing: a plate and its engine",
					"0 // the first wing", "0 // the second wing", "0 // the wing's printed tile",
					"0 // the engine's printed round brick", "0 !TEXMAP NEXT", "0 // the roof",
					"0 !LDCAD GROUP_NXT [ids=3]"]:
				var where: Array = _sections_with(saved, needle)
				if not where.is_empty():
					print("  %-40s x%d in %s" % [needle, where.size(), str(where)])


# -- the edits -------------------------------------------------------------------


## [param edit] made, as a person makes it: "" when it was, else why not.
func _edit(edit: String) -> String:
	var main_parts: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and Assemblies.path_of(brick).is_empty():
			main_parts.append(brick)
	var by_part := func(part_id: String) -> int:
		for brick: BrickWorld.Brick in main_parts:
			if brick.part_id == part_id:
				return brick.id
		return -1
	match edit:
		"plan":
			var part: int = int((main_parts[main_parts.size() - 1] as BrickWorld.Brick).id)
			var said: String = _shell.change_steps("next", [part], _step_holding(part))
			print("  plan: %s" % said.get_slice("\n", 0).left(100))
			await _frames(4)
			return ""
		"add":
			var brick: int = by_part.call("3005")
			if brick < 0:
				brick = by_part.call("3001")
			_select_only([brick])
			(_main.get("_verbs") as EditVerbs).duplicate_selection(false)
			var put: int = await _put_down(true)
			return "" if put > 0 else "nothing put down"
		"remove_tile", "remove_plate":
			_select_only([by_part.call("3068b" if edit == "remove_tile" else "3024")])
			var taken: int = _builder.remove_selection()
			await _frames(4)
			return "" if taken > 0 else "nothing taken off"
		"make_in_roof":
			var roof: String = _first_path("Roof")
			if roof.is_empty():
				return "no roof"
			_shell.assemblies.enter(roof)
			var brick: int = -1
			for item: BrickWorld.Brick in _world.bricks():
				if Assemblies.path_of(item) == roof and item.part_id == "3010":
					brick = item.id
			_select_only([brick])
			_shell.run("make_submodel")
			await _frames(2)
			print("  make_submodel: %s" % _name_it("Roof Top"))
			await _frames(4)
			_shell.assemblies.leave_to("")
			for item: BrickWorld.Brick in _world.bricks():
				if item.id == brick or item.part_id == "3010" and item.color_code == 4:
					print("  the roof's brick is now in %s" % Assemblies.path_of(item))
			return ""
		"make_pair":
			var two: Array = []
			for brick: BrickWorld.Brick in main_parts:
				if brick.part_id == "3005":
					two.append(brick.id)
			_select_only(two)
			_shell.run("make_submodel")
			await _frames(2)
			print("  make_submodel: %s" % _name_it("Pair"))
			await _frames(4)
			_shell.assemblies.leave_to("")
			return ""
		"swap_fallback":
			var swapped := Vector2i.ZERO
			for into: String in ["4865a", "3069b", "3004"]:
				if swapped.x == 0:
					_select_only([by_part.call("4865b")])
					swapped = _builder.replace_selection(into, true)
					if swapped.x > 0:
						print("  swapped the panel for %s" % into)
			await _frames(4)
			return "" if swapped.x > 0 else "nothing swapped (%s)" % swapped
		"recolour_fallback":
			_select_only([by_part.call("4865b")])
			var painted: int = _builder.paint_selection(1)
			await _frames(4)
			return "" if painted > 0 else "nothing painted"
		"paste":
			var wing: String = _first_path("Wing")
			_select_assembly(wing)
			(_main.get("_verbs") as EditVerbs).duplicate_selection(false)
			var put: int = await _put_down(false)
			_shell.assemblies.leave_to("")
			return "" if put > 0 else "nothing put down"
		"ungroup_one":
			var wing: String = _first_path("Wing")
			if wing.is_empty():
				return "no wing"
			_select_assembly(wing)
			_shell.run("leave_submodel")
			await _frames(6)
			return ""
		"move_tile":
			_select_only([by_part.call("3068b")])
			var moved: int = _builder.move_selection(Vector3i(0, 200, 0))
			await _frames(4)
			return "" if moved > 0 else "nothing moved"
		"apart_engine":
			var wing: String = _first_path("Wing")
			var engine: String = ""
			for path: String in _shell.assemblies.paths():
				if Assemblies.parent_of(path) == wing \
						and Assemblies.definition(Assemblies.leaf(path)) == "Engine":
					engine = path
			if engine.is_empty():
				return "no engine in %s (%s)" % [wing, str(_shell.assemblies.paths())]
			_frames_before = _read_frames_now()
			_select_assembly(engine)
			_shell.run("leave_submodel")
			await _frames(6)
			_shell.assemblies.leave_to("")
			print("  %s taken apart: paths now %s" % [engine, str(_shell.assemblies.paths())])
			return ""
	return "no such edit"


## Each copy's frame as the file gave it (Assemblies._read_frames), {} on a
## build without it (pre261).
func _read_frames_now() -> Dictionary:
	var assemblies: Assemblies = _shell.assemblies
	if not assemblies.has_method("_read_frames"):
		return {}
	return assemblies.call("_read_frames")


# -- reading a text --------------------------------------------------------------


## Every line of [param text] the reader reads into nothing, by its text ->
## how many: comments and other programs' lines. Not the lines the writer
## writes of its own (FILE, NOFILE, STEP, Name, Author, a section's title, the
## app's own lines, a picture's data). A TEXMAP line's and a block's own
## geometry's numbers are "#": a write that moves a part moves them.
static func _kept_counts(text: String) -> Dictionary:
	var out: Dictionary = {}
	var titled: bool = false
	var in_data: bool = false
	var number := RegEx.create_from_string("(?<=\\s)-?[0-9.]+(e-?[0-9]+)?(?=\\s|$)")
	for raw: String in text.replace("\r", "").split("\n"):
		var line: String = raw.strip_edges()
		var words: PackedStringArray = line.split(" ", false)
		if words.is_empty() or words[0] != "0" or words.size() < 2:
			continue
		var key: String = words[1].to_upper()
		if key == "FILE":
			titled = false
			in_data = false
			continue
		if key == "!DATA":
			in_data = true
			continue
		if in_data and key == "!:":
			continue
		in_data = false
		if not titled:
			titled = true
			continue
		if key in ["NOFILE", "STEP", "ROTSTEP", "NAME:", "AUTHOR:", "!BRICKWORKS"]:
			continue
		if key == "!TEXMAP" or key == "!:":
			line = number.sub(line, "#", true)
		out[line] = int(out.get(line, 0)) + 1
	return out


## Each line of [param text] that says what the next line is, as "what it
## says -> the name the next placing line gives" (a part's file or a
## sub-model's), "-> (line)" where the next line places nothing.
static func _binds(text: String) -> Array:
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	var out: Array = []
	for n: int in lines.size():
		var line: String = lines[n].strip_edges()
		var said: String = ""
		if line.begins_with("0 !TEXMAP NEXT"):
			said = "!TEXMAP NEXT"
		elif line.begins_with("0 BFC INVERTNEXT"):
			said = "BFC INVERTNEXT"
		elif line.begins_with("0 !LDCAD GROUP_NXT"):
			said = "GROUP_NXT " + line.get_slice(" ", 3)
		if said.is_empty():
			continue
		var target: String = "(the end)"
		for m: int in range(n + 1, lines.size()):
			var next: String = lines[m].strip_edges()
			if next.is_empty():
				continue
			if next.begins_with("0 !TEXMAP NEXT") or next.begins_with("0 BFC INVERTNEXT") \
					or next.begins_with("0 !LDCAD GROUP_NXT"):
				continue
			var words: PackedStringArray = next.split(" ", false)
			target = words[words.size() - 1].to_lower() if words.size() >= 15 and words[0] == "1" \
				else "(%s)" % next.left(40)
			break
		out.append("%s -> %s" % [said, target])
	return out


static func _counted(items: Array) -> Dictionary:
	var out: Dictionary = {}
	for item: Variant in items:
		out[str(item)] = int(out.get(str(item), 0)) + 1
	return out


## [lost, more]: what [param want] has more of than [param got], and less.
static func _diff(want: Dictionary, got: Dictionary) -> Array:
	var lost: Array = []
	var more: Array = []
	for key: String in want:
		var n: int = int(want[key]) - int(got.get(key, 0))
		if n > 0:
			lost.append("%s x%d" % [key, n])
	for key: String in got:
		var n: int = int(got[key]) - int(want.get(key, 0))
		if n > 0:
			more.append("%s x%d" % [key, n])
	return [lost, more]


## The line after the first that is [param needle].
static func _next_line(text: String, needle: String) -> String:
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	for n: int in lines.size() - 1:
		if lines[n].strip_edges() == needle:
			return lines[n + 1].strip_edges()
	return "(not in the file)"


## Where the first TEXMAP NEXT's first point stands from the part line after
## it, in the file's numbers ("dx dy dz"), or why not.
static func _texmap_from_part(text: String) -> String:
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	for n: int in lines.size():
		var words: PackedStringArray = lines[n].strip_edges().split(" ", false)
		if words.size() < 13 or words[0] != "0" or words[1] != "!TEXMAP" or words[2] != "NEXT":
			continue
		for m: int in range(n + 1, lines.size()):
			var part: PackedStringArray = lines[m].strip_edges().split(" ", false)
			if part.size() >= 15 and part[0] == "1":
				var out := PackedStringArray()
				for k: int in 3:
					out.append(str(snappedf(words[4 + k].to_float() - part[2 + k].to_float(), 0.01)
						+ 0.0).trim_suffix(".0"))
				return " ".join(out)
		return "(no part after it)"
	return "(no TEXMAP NEXT)"


## The first placing line after a line beginning [param needle].
static func _after_word(text: String, needle: String) -> String:
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	for n: int in lines.size():
		if lines[n].strip_edges().begins_with(needle):
			for m: int in range(n + 1, lines.size()):
				if lines[m].strip_edges().begins_with("1 "):
					return lines[m].strip_edges()
	return ""


## The lines between the first [param begin] and the [param end] after it.
static func _between(text: String, begin: String, end: String) -> Array:
	var out: Array = []
	var inside: bool = false
	for raw: String in text.replace("\r", "").split("\n"):
		var line: String = raw.strip_edges()
		if not inside and line == begin:
			inside = true
			continue
		if inside and line == end:
			return out
		if inside and not line.is_empty():
			out.append(line)
	return out + ["(no END after it)"] if inside else ["(no BEGIN)"]


## The FILE section each line beginning [param needle] is in, once a line.
static func _sections_with(text: String, needle: String) -> Array:
	var out: Array = []
	var section: String = "(head)"
	for raw: String in text.replace("\r", "").split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 FILE "):
			section = line.substr(7)
		elif line.begins_with(needle):
			out.append(section)
	return out


## Every part as it stands in the file's coordinates: part, colour, place.
func _parts() -> Array:
	var lift: Vector3 = _store.lift()
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var t := Transform3D(brick.transform.basis, brick.transform.origin - lift)
		var place := PackedStringArray()
		for v: Vector3 in [t.origin / 10.0, t.basis.x, t.basis.y, t.basis.z]:
			for x: float in [v.x, v.y, v.z]:
				place.append("%.1f" % (snappedf(x, 0.1) + 0.0))
		out.append("%s %d at %s" % [brick.part_id, brick.color_code, " ".join(place)])
	out.sort()
	return out


static func _unlike(a: Array, b: Array) -> Array:
	var have: Dictionary = _counted(b)
	var out: Array = []
	for line: String in a:
		if int(have.get(line, 0)) > 0:
			have[line] = int(have[line]) - 1
		else:
			out.append(line)
	if out.is_empty() and a.size() != b.size():
		out.append("%d parts, %d before" % [b.size(), a.size()])
	return out


## The case's file as opened and as saved, in the run's data folder
## (probe.sh keeps it when a check fails): user://wkreview/.
func _keep(name: String, opened: String, saved: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://wkreview")
	for pair: Array in [[".opened.ldr", opened], [".saved.ldr", saved]]:
		var file := FileAccess.open("user://wkreview/" + name + str(pair[0]), FileAccess.WRITE)
		if file != null:
			file.store_string(str(pair[1]))
	print("  kept: %s" % ProjectSettings.globalize_path("user://wkreview/" + name + ".saved.ldr"))
	print("    | " + "\n    | ".join(Array(saved.split("\n")).slice(0, 90).map(
		func(line: String) -> String: return line.left(110))))


# -- driving it (wholekeep_probe's) ----------------------------------------------


func _first_path(definition: String) -> String:
	var paths: Array = Array(_shell.assemblies.paths())
	paths.sort()
	for path: String in paths:
		if Assemblies.definition(Assemblies.leaf(path)) == definition \
				and Assemblies.parent_of(path).is_empty():
			return path
	return ""


func _put_down(up: bool = false) -> int:
	var carry: Carry = _builder.carrying
	if carry == null:
		return 0
	var low := Vector3(INF, INF, INF)
	var high := -low
	for brick: BrickWorld.Brick in _world.bricks():
		low = low.min(brick.transform.origin)
		high = high.max(brick.transform.origin)
	var room: float = 4.0 * BrickLattice.STUD
	carry.stand_where_lifted(_builder.lattice, _builder)
	carry.pin()
	for k: int in 6:
		var by: Vector3 = Vector3(0.0, high.y - low.y + room * (k + 1), 0.0) if up \
			else Vector3(high.x - low.x + room * (k + 1), 0.0, 0.0)
		if carry.show_moved(Transform3D(Basis.IDENTITY, by), _builder.lattice, _builder):
			var put: int = _builder.place()
			await _frames(4)
			_builder.cancel_carry()
			return put
	_builder.cancel_carry()
	return 0


func _select_assembly(path: String) -> void:
	_shell.assemblies.leave_to(Assemblies.parent_of(path))
	_select_only(Array(_shell.assemblies.ids_under(path)))


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		if brick_id >= 0:
			_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _name_it(name: String) -> String:
	var verbs: EditVerbs = _main.get("_verbs")
	var field: LineEdit = verbs.get("_name_field")
	var dialog: ConfirmationDialog = verbs.get("_naming")
	if field == null or dialog == null or not dialog.visible:
		return "no naming dialog"
	field.text = name
	dialog.hide()
	dialog.confirmed.emit()
	return "named %s" % name


func _step_holding(brick_id: int) -> Instructions.Step:
	for step: Instructions.Step in Instructions.plan(_world, _main.get("_library"), _store.scenery,
			{}, true):
		if step.brick_ids.has(brick_id):
			return step
	return null


func _open(text: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(text, "model")
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
