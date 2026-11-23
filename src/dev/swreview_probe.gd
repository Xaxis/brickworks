## swreview's attacks on Find and Replace (swapfind), beyond its own probe.
##
##   godot --headless --path . --script src/dev/swreview_probe.gd
##
##   SWREVIEW_CASES=a,b   those cases
extends "res://src/dev/swapfind_probe.gd"

const MY_CASES: Array = ["swap_save", "two_replaces", "submodel_only", "shared", "colour16",
	"direct", "mirror_colour", "allblack", "tiles", "locked", "selection_copy", "hostile",
	"write_paths", "together_actor"]

const SHARED := """0 FILE shared.mpd
0 Shared
0 Name: shared.mpd
0 Author: Brickworks

1 16 0 0 0 1 0 0 0 1 0 0 0 1 side.ldr
1 16 0 0 200 1 0 0 0 1 0 0 0 1 side.ldr
1 16 200 0 0 1 0 0 0 1 0 0 0 1 sill.ldr
1 16 200 0 200 1 0 0 0 1 0 0 0 1 door.ldr
1 4 -200 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0
0 NOFILE
0 FILE side.ldr
0 Side
0 Name: side.ldr
0 Author: Brickworks

1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 sill.ldr
0
0 NOFILE
0 FILE door.ldr
0 Door
0 Name: door.ldr
0 Author: Brickworks

1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 sill.ldr
0
0 NOFILE
0 FILE sill.ldr
0 Sill
0 Name: sill.ldr
0 Author: Brickworks

1 0 0 -8 0 1 0 0 0 1 0 0 0 1 3023.dat
1 0 0 -8 20 1 0 0 0 1 0 0 0 1 3024.dat
0
0 NOFILE
"""

const C16 := """0 FILE c16.mpd
0 C16
0 Name: c16.mpd
0 Author: Brickworks

1 4 0 0 0 1 0 0 0 1 0 0 0 1 blk.ldr
1 1 120 0 0 1 0 0 0 1 0 0 0 1 blk.ldr
1 4 -120 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 0x2FF0000 -120 -32 0 1 0 0 0 1 0 0 0 1 3023.dat
0
0 NOFILE
0 FILE blk.ldr
0 Blk
0 Name: blk.ldr
0 Author: Brickworks

1 16 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 0 0 -32 0 1 0 0 0 1 0 0 0 1 3023.dat
1 24 0 -40 0 1 0 0 0 1 0 0 0 1 3024.dat
1 0x2FF0000 0 -32 -20 1 0 0 0 1 0 0 0 1 3023.dat
0
0 NOFILE
"""


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(1700.0).timeout.connect(func() -> void:
		print("swreview probe: not finished in time")
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var cases: Array = MY_CASES if OS.get_environment("SWREVIEW_CASES").is_empty() \
		else Array(OS.get_environment("SWREVIEW_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		_builder.unlock_all()
		_shell.assemblies.leave_to("")
		match name:
			"swap_save": await _r_swap_save()
			"two_replaces": await _r_two_replaces()
			"submodel_only": await _r_submodel_only()
			"shared": await _r_shared()
			"colour16": await _r_colour16()
			"direct": await _r_direct()
			"mirror_colour": await _r_mirror_colour()
			"allblack": await _r_allblack()
			"tiles": await _r_tiles()
			"locked": await _r_locked()
			"selection_copy": await _r_selection_copy()
			"hostile": await _r_hostile()
			"write_paths": await _r_write_paths()
			"together_actor": await _r_together_actor()
			"big": await _r_big()
			"resolve": await _r_resolve()
			"room_copies": await _r_room_copies()
			_: _check("no such case %s" % name, false)
	print("\nswreview probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


func _find_into(part: String, colour: int, into_part: String, into_colour: int,
		where: String = "all") -> Dictionary:
	_bar.call("set_find", part, colour)
	_bar.call("set_into", into_part, into_colour)
	_bar.call("set_where", where)
	await _refresh()
	return _bar.get("found")


## The bar found again (refresh), and waited for: where the copies' frames
## are not to hand they are worked out a slice of a frame at a time first
## (FindReplace.frames_paced_for), and "found" is empty until then. On a busy
## box a small model's took more than a slice: swapfind's car read it empty
## and stopped on a script error (keepfix, from wkfix's run).
func _refresh() -> void:
	_bar.call("refresh")
	for _n: int in 3000:
		if not bool(_bar.get("_framing")):
			return
		await process_frame


func _block(text: String, file: String) -> Array:
	var out: Array = []
	var inside: bool = false
	for line: String in text.split("\n"):
		var key: String = line.strip_edges()
		if key.begins_with("0 FILE "):
			inside = key == "0 FILE " + file
			continue
		if inside and key.begins_with("1 "):
			out.append(key)
	return out


func _parts_count(part: String) -> int:
	var n: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and not _store.scenery.has(brick.id):
			n += 1
	return n


## A part swap across copies: the save writes each sub-model once, with its
## own lines, and opens again as shown; undo and redo to the byte; a second
## replace and two undos give the first file.
func _r_swap_save() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	var before: String = _save()
	await _find_into("3023", BLACK, "3794b", -1)
	print("  bar: %s" % _bar_said())
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(6)
	var after: String = _save()
	print("  done %s; diff %s" % [done, _diff(before, after)])
	print("  sill.ldr: %s" % " | ".join(_block(after, "sill.ldr")))
	_check("swap_save: 4 jumpers in the world (%d), done says %d" % [_parts_count("3794b"),
		int(done.get("changed", 0))], _parts_count("3794b") == 4 and int(done.get("changed", 0)) == 4)
	_check("swap_save: sill.ldr written once with 2 lines (%d defs, %d lines)" % [
		_defined(after, "sill.ldr"), _block(after, "sill.ldr").size()],
		_defined(after, "sill.ldr") == 1 and _block(after, "sill.ldr").size() == 2)
	_check("swap_save: side.ldr keeps its line count (%d -> %d)" % [_block(before, "side.ldr").size(),
		_block(after, "side.ldr").size()], _block(before, "side.ldr").size() == _block(after, "side.ldr").size())
	_check("swap_save: 3 lines changed (%d +, %d -)" % [_minus(after, before).size(),
		_minus(before, after).size()], _minus(after, before).size() == 3 and _minus(before, after).size() == 3)
	var shown: Array = _looks(false)
	await _open(after)
	_check("swap_save: opened again as shown%s" % _unlike(shown, _looks(false)), shown == _looks(false))
	await _open(text)
	await _find_into("3023", BLACK, "3794b", -1)
	await _bar.call("replace_now")
	await _frames(4)
	var undone: String = await _undone()
	_check("swap_save: undo, the save before (%s)" % _diff(before, undone), undone == before)
	_shell.run("redo")
	await _frames(6)
	var redone: String = _save()
	_check("swap_save: redo, the save after (%s)" % _diff(after, redone), redone == after)


## Redo, then a second replace, then undo twice.
func _r_two_replaces() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	var before: String = _save()
	var depth: int = _builder.history_depth()
	await _find_into("3023", BLACK, "", DARK_BLUISH_GREY)
	await _bar.call("replace_now")
	await _frames(4)
	var first: String = _save()
	await _undone()
	_shell.run("redo")
	await _frames(6)
	_check("two: redo gives the first replace (%s)" % _diff(first, _save()), _save() == first)
	await _find_into("3024", -1, "3070b", -1)
	print("  bar: %s" % _bar_said())
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(6)
	var second: String = _save()
	print("  second: %s; %s" % [done, _diff(first, second)])
	_check("two: two steps (%d)" % (_builder.history_depth() - depth), _builder.history_depth() == depth + 2)
	var u1: String = await _undone()
	_check("two: first undo gives the first replace (%s)" % _diff(first, u1), u1 == first)
	var u2: String = await _undone()
	_check("two: second undo gives the file before (%s)" % _diff(before, u2), u2 == before)
	_shell.run("redo")
	await _frames(6)
	_shell.run("redo")
	await _frames(6)
	_check("two: two redos give the second (%s)" % _diff(second, _save()), _save() == second)


## "In Side and its copies": only Side's lines (and Sill inside it) change.
func _r_submodel_only() -> void:
	var text: String = _fixture(CAR)
	await _open(text)
	var side: String = ""
	for path: String in _shell.assemblies.paths():
		if Assemblies.definition(Assemblies.leaf(path)) == "Side":
			side = path
			break
	_shell.assemblies.enter(side)
	await _frames(4)
	_builder.clear_selection()
	_shell.run("find_replace")
	await _frames(4)
	_bar = _main.get("_find_replace_made")
	var before: String = _save()
	var found: Dictionary = await _find_into("", 4, "", 14, "submodel")
	var said: String = _bar_said()
	print("  entered %s; bar: %s" % [side, said])
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(6)
	var after: String = _save()
	print("  done %s" % done)
	var outside: Array = []
	for line: String in _minus(after, before):
		if not _block(after, "side.ldr").has(line) and not _block(after, "sill.ldr").has(line):
			outside.append(line)
	_check("submodel_only: only side.ldr/sill.ldr lines changed (%d outside: %s)" % [outside.size(),
		" | ".join(outside.slice(0, 3))], outside.is_empty() and not _minus(after, before).is_empty())
	_check("submodel_only: the model's own red parts still red (%s)" % _diff(before, after),
		_block(after, "car.mpd").filter(func(l: String) -> bool: return l.begins_with("1 14 ")).is_empty())
	_shell.assemblies.leave_to("")
	var undone: String = await _undone()
	_check("submodel_only: undo to the byte (%s)" % _diff(before, undone), undone == before)
	# The model's own parts only.
	await _bar_on(text)
	await _find_into("", BLACK, "", 14, "submodel")
	said = _bar_said()
	print("  top bar: %s" % said)
	await _bar.call("replace_now")
	await _frames(6)
	after = _save()
	var touched: Array = _minus(after, before).filter(func(l: String) -> bool:
		return _block(after, "car.mpd").has(l))
	_check("submodel_only: the model's own parts only (%d of %d in car.mpd)" % [touched.size(),
		_minus(after, before).size()], touched.size() == _minus(after, before).size())


## A sub-model in two parents and at the top: N said, every copy follows,
## one definition.
func _r_shared() -> void:
	await _bar_on(SHARED)
	var before: String = _save()
	print("  opened: %s" % _diff(SHARED, before))
	var found: Dictionary = await _find_into("3023", BLACK, "", DARK_BLUISH_GREY)
	var said: String = _bar_said()
	print("  bar all: %s" % said)
	var paths: Array = Array(_shell.assemblies.paths())
	print("  paths: %s" % ", ".join(paths))
	_check("shared: 4 found (Sill at top, in 2 Sides, in Door) (%d)" % (found["ids"] as Array).size(),
		(found["ids"] as Array).size() == 4)
	_check("shared: says all 4 copies of Sill", said.contains("Changes all 4 copies of Sill"))
	await _bar.call("replace_now")
	await _frames(6)
	var after: String = _save()
	print("  after all: %s" % _diff(before, after))
	_check("shared: one line changed, Sill once (%d, %d)" % [_minus(after, before).size(),
		_defined(after, "sill.ldr")], _minus(after, before).size() == 1 and _defined(after, "sill.ldr") == 1)
	var shown: Array = _looks(false)
	await _open(after)
	_check("shared: opened again as shown%s" % _unlike(shown, _looks(false)), shown == _looks(false))
	# Inside one Side: the bar's N and what changes.
	await _open(SHARED)
	var side: String = ""
	for path: String in _shell.assemblies.paths():
		if Assemblies.definition(Assemblies.leaf(path)) == "Side":
			side = path
			break
	_shell.assemblies.enter(side)
	await _frames(4)
	_builder.clear_selection()
	_shell.run("find_replace")
	await _frames(4)
	found = await _find_into("3023", BLACK, "", DARK_BLUISH_GREY, "submodel")
	said = _bar_said()
	print("  bar in %s: %s" % [side, said])
	var answer: String = await _say("replace_parts", {"find": {"part": "3023", "color": 0},
		"replace": {"color": 72}, "where": "submodel", "preview": true})
	print("  mcp preview in Side: %s" % answer.replace("\n", " / "))
	_check("shared: in Side, 2 found, and it says all 4 copies of Sill change (%d)" % (found["ids"] as Array).size(),
		(found["ids"] as Array).size() == 2 and said.contains("Changes all 4 copies of Sill"))
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(6)
	var in_side: String = _save()
	print("  done %s; %s" % [done, _diff(before, in_side)])
	_check("shared: in Side, every Sill follows: 4 grey (%d), one line" % _count("3023", DARK_BLUISH_GREY),
		_count("3023", DARK_BLUISH_GREY) == 4 and _minus(in_side, before).size() == 1)
	_check("shared: in Side, done counts what changed (%s, 4 changed)" % done,
		int(done.get("changed", 0)) == 4)
	_shell.assemblies.leave_to("")


## Colour 16 in a sub-model placed in Red and in Blue; 24; a direct colour.
func _r_colour16() -> void:
	await _bar_on(C16)
	var before: String = _save()
	print("  opened: %s" % _diff(C16, before))
	var found: Dictionary = await _find_into("", 4, "", DARK_BLUISH_GREY)
	print("  bar Red: %s" % _bar_said())
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(6)
	var after: String = _save()
	print("  done %s" % done)
	print("  saved:\n%s" % after)
	var shown: Array = _looks(false)
	await _open(after)
	_check("colour16: opened again as shown%s" % _unlike(shown, _looks(false)), shown == _looks(false))
	_check("colour16: blk still one definition (%d)" % _defined(after, "blk.ldr"),
		_defined(after, "blk.ldr") == 1)
	await _open(C16)
	before = _save()
	var a: String = await _say("replace_parts", {"find": {"color": 16}})
	print("  mcp find 16: %s" % a.replace("\n", " / "))
	a = await _say("replace_parts", {"find": {"color": 24}})
	print("  mcp find 24: %s" % a.replace("\n", " / "))
	a = await _say("replace_parts", {"find": {"part": "3001"}, "replace": {"color": 16}})
	print("  mcp into 16: %s" % a.replace("\n", " / "))
	var into16: String = _save()
	print("  into 16 diff: %s" % _diff(before, into16))
	_check("colour16: replace into 16 (not a colour) refused, nothing changed", into16 == before)
	await _open(C16)
	a = await _say("replace_parts", {"find": {"part": "3024"}, "replace": {"color": 24}})
	print("  mcp into 24: %s" % a.replace("\n", " / "))
	_check("colour16: replace into 24 (edge colour) refused, nothing changed (%s)" % _diff(before, _save()),
		_save() == before)


func _r_direct() -> void:
	await _bar_on(C16)
	var before: String = _save()
	var direct: int = 0x2FF0000
	_bar.call("set_find", "", direct)
	await _refresh()
	var said: String = _bar_said()
	print("  bar direct: %s" % said)
	var found: Dictionary = _bar.get("found")
	_check("direct: the bar finds the 3 direct-coloured parts (%d)" % (found.get("ids", []) as Array).size(),
		(found.get("ids", []) as Array).size() == 3)
	var a: String = await _say("replace_parts", {"find": {"color": direct}})
	print("  mcp find direct: %s" % a.replace("\n", " / "))
	_check("direct: replace_parts finds a direct colour too", a.contains("Found 3"))
	a = await _say("replace_parts", {"find": {"part": "3023"}, "preview": true})
	print("  mcp 3023: %s" % a.replace("\n", " / "))
	await _find_into("", direct, "3710", -1)
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(6)
	var after: String = _save()
	print("  direct to 3710: %s; %s" % [done, _diff(before, after)])
	_check("direct: the part swapped keeps its direct colour", after.contains("0x2FF0000") and
		not _diff(before, after).contains("no line changed"))
	var shown: Array = _looks(false)
	await _open(after)
	_check("direct: opened again as shown%s" % _unlike(shown, _looks(false)), shown == _looks(false))


## A colour replace in the mirrored Side, and a handed door by colour.
func _r_mirror_colour() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	var before: String = _save()
	var found: Dictionary = await _find_into("3024", 46, "", 4)
	print("  bar 3024/46: %s" % _bar_said())
	await _bar.call("replace_now")
	await _frames(6)
	var after: String = _save()
	print("  %s" % _diff(before, after))
	_check("mirror_colour: 2 side.ldr lines, nothing else (%d)" % _minus(after, before).size(),
		_minus(after, before).size() == 2 and _defined(after, "side.ldr") == 1)
	var shown: Array = _looks(false)
	await _open(after)
	_check("mirror_colour: opened as shown%s" % _unlike(shown, _looks(false)), shown == _looks(false))
	await _open(text)
	found = await _find_into("3821", -1, "", 14)
	print("  bar 3821 (mirrored door): %s" % _bar_said())
	await _bar.call("replace_now")
	await _frames(6)
	after = _save()
	print("  %s" % _diff(before, after))
	_check("mirror_colour: the door Yellow in both sides (%d, %d), side.ldr's 3822 line"
		% [_count("3821", 14), _count("3822", 14)], _count("3821", 14) == 1 and _count("3822", 14) == 1
		and after.contains("1 14 30 -56 -30 1 0 0 0 1 0 0 0 1 3822.dat") and _minus(after, before).size() == 1)
	var undone: String = await _undone()
	_check("mirror_colour: undo to the byte", undone == before)


## Every Black part, every sub-model: lines, reopen, undo.
func _r_allblack() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	var before: String = _save()
	var blacks: int = 0
	for line: String in before.split("\n"):
		if line.begins_with("1 0 "):
			blacks += 1
	var found: Dictionary = await _find_into("", BLACK, "", DARK_BLUISH_GREY)
	print("  bar: %s" % _bar_said())
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(6)
	var after: String = _save()
	var left: int = 0
	for line: String in after.split("\n"):
		if line.begins_with("1 0 "):
			left += 1
	print("  done %s; %d Black lines before, %d after; %s" % [done, blacks, left, _diff(before, after)])
	_check("allblack: no Black line left, %d lines changed" % _minus(after, before).size(),
		left == 0 and _minus(after, before).size() == blacks)
	var shown: Array = _looks(false)
	await _open(after)
	_check("allblack: opened as shown%s" % _unlike(shown, _looks(false)), shown == _looks(false))
	await _open(text)
	await _find_into("", BLACK, "", DARK_BLUISH_GREY)
	await _bar.call("replace_now")
	await _frames(4)
	var undone: String = await _undone()
	_check("allblack: undo to the byte (%s)" % _diff(before, undone), undone == before)


## 3024 everywhere (in Side and in Sill, mirrored Side too) for 3070b tiles.
func _r_tiles() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	var before: String = _save()
	var found: Dictionary = await _find_into("3024", -1, "3070b", -1)
	print("  bar: %s" % _bar_said())
	var made: Dictionary = _bar.get("made")
	print("  made: otherwise %d floats %d room %d follow %d changes %d" % [(made["otherwise"] as Array).size(),
		(made["floats"] as Array).size(), (made["room"] as Array).size(), (made["follow"] as Array).size(),
		(made["changes"] as Array).size()])
	var n: int = (found["ids"] as Array).size()
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(6)
	var after: String = _save()
	print("  done %s; 3070b %d, 3024 %d; %s" % [done, _parts_count("3070b"), _parts_count("3024"),
		_diff(before, after)])
	_check("tiles: every 3024 a 3070b (%d of %d), none doubled" % [_parts_count("3070b"), n],
		_parts_count("3070b") == n and _parts_count("3024") == 0)
	_check("tiles: side.ldr and sill.ldr keep their line counts", _block(after, "side.ldr").size()
		== _block(before, "side.ldr").size() and _block(after, "sill.ldr").size() == _block(before, "sill.ldr").size())
	var shown: Array = _looks(false)
	await _open(after)
	_check("tiles: opened as shown%s" % _unlike(shown, _looks(false)), shown == _looks(false))
	await _open(text)
	await _find_into("3024", -1, "3070b", -1)
	await _bar.call("replace_now")
	await _frames(4)
	var undone: String = await _undone()
	_check("tiles: undo to the byte (%s)" % _diff(before, undone), undone == before)


## A part locked in one copy of Sill: said as left out; is it?
func _r_locked() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	var before: String = _save()
	var target: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3023b" and brick.color_code == BLACK \
				and Assemblies.definition(Assemblies.leaf(Assemblies.path_of(brick))) == "Sill":
			target = brick
			break
	_builder.clear_selection()
	_builder.selection[target.id] = true
	_builder.lock_selection(true)
	_builder.clear_selection()
	var found: Dictionary = await _find_into("3023", BLACK, "", DARK_BLUISH_GREY)
	var said: String = _bar_said()
	print("  bar: %s" % said)
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(6)
	var still: BrickWorld.Brick = _world.get_brick(target.id)
	print("  done %s; locked one now %s" % [done, "gone" if still == null else str(still.color_code)])
	_check("locked: the locked part said left out (%d locked)" % int(found.get("locked", 0)),
		int(found.get("locked", 0)) == 1)
	_check("locked: ...and left Black, as said", still != null and still.color_code == BLACK)
	_builder.unlock_all()


## One wheel's rim selected: all 4 wheels follow, said.
func _r_selection_copy() -> void:
	var text: String = _fixture(CAR)
	await _open(text)
	var rim: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "4624":
			rim = brick
			break
	_builder.clear_selection()
	_builder.selection[rim.id] = true
	_builder.selection_changed.emit(1)
	_shell.run("find_replace")
	await _frames(4)
	_bar = _main.get("_find_replace_made")
	var before: String = _save()
	await _find_into("4624", 7, "", 71, "selection")
	var said: String = _bar_said()
	print("  bar: %s" % said)
	_check("selection_copy: says all 4 copies of Wheel change", said.contains("Changes all 4 copies of Wheel"))
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(6)
	print("  done %s; %d LBG rims" % [done, _count("4624", 71)])
	_check("selection_copy: 4 rims follow (%d)" % _count("4624", 71), _count("4624", 71) == 4)


## replace_parts given what a session may send wrong.
func _r_hostile() -> void:
	var text: String = _fixture(CAR)
	await _open(text)
	var before: String = _save()
	var asks: Array = [
		["unknown find part", {"find": {"part": "nope123"}, "replace": {"color": 72}}],
		["unknown find colour", {"find": {"part": "3023", "color": 999}, "replace": {"color": 72}}],
		["empty find", {"find": {}, "replace": {"color": 72}}],
		["find as a string", {"find": "3023", "replace": {"color": 72}}],
		["no find at all", {"replace": {"color": 72}}],
		["where misspelt", {"find": {"part": "3023"}, "replace": {"color": 72}, "where": "everywhere"}],
		["selection empty", {"find": {"part": "3023"}, "replace": {"color": 72}, "where": "selection"}],
		["unknown colour name", {"find": {"part": "3023"}, "replace": {"color": "Plaid"}}],
		["colour -5", {"find": {"part": "3023"}, "replace": {"color": -5}}],
		["colour as a numeric string", {"find": {"part": "3023"}, "replace": {"color": "72"}, "preview": true}],
		["typo'd part number", {"find": {"part": "3023"}, "replace": {"part": "30699"}, "preview": true}],
		["nonsense part", {"find": {"part": "3023"}, "replace": {"part": "qqzzxx"}, "preview": true}],
		["a word for a part", {"find": {"part": "3023"}, "replace": {"part": "plate"}, "preview": true}],
		["find equal to replace", {"find": {"part": "3023", "color": 0}, "replace": {"part": "3023b", "color": 0}}],
		["find equal to replace, colour", {"find": {"color": 0}, "replace": {"color": 0}}],
		["replace not a dict", {"find": {"part": "3023"}, "replace": "3794b"}],
	]
	for ask: Array in asks:
		await _open(text)
		var answer: String = await _say("replace_parts", ask[1])
		var now: String = _save()
		print("  %s -> %s%s" % [ask[0], answer.replace("\n", " / ").left(400),
			"" if now == before else "  [CHANGED: %s]" % _diff(before, now)])
	# A typo'd number, not previewed: what goes in?
	await _open(text)
	var answer: String = await _say("replace_parts", {"find": {"part": "3023", "color": 0},
		"replace": {"part": "30699"}})
	var now: String = _save()
	print("  typo'd, done -> %s  [%s]" % [answer.replace("\n", " / ").left(400), _diff(before, now)])
	_check("hostile: a part number the library lacks is refused, not swapped for a search's guess",
		now == before)
	await _open(text)
	answer = await _say("replace_parts", {"find": {"part": "3023", "color": 0},
		"replace": {"part": "3023b", "color": 0}})
	print("  same -> %s" % answer.replace("\n", " / "))
	_check("hostile: find equal to replace is not called 'none had room'",
		not answer.contains("none had room"))


## After a replace: the autosave's text (no steps) and the export's open as shown.
func _r_write_paths() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	await _find_into("3023", BLACK, "3794b", DARK_BLUISH_GREY)
	await _bar.call("replace_now")
	await _frames(6)
	var shown: Array = _looks(false)
	var steps: String = _steps_said()
	var kept: String = _store.to_text(_store.title)
	var exported: String = _store.to_text(_store.title, true)
	var together: String = (_main.get("_together") as Together).model_text()
	var path: String = OS.get_user_data_dir().path_join("swreview_export.ldr")
	var ok: bool = _store.export_to(path, _store.title)
	var file_text: String = FileAccess.get_file_as_string(path)
	_check("write_paths: the export written is the save (%s)" % ok, ok and file_text == exported)
	for pair: Array in [["autosave text", kept], ["export", exported], ["together's", together]]:
		await _open(pair[1])
		_check("write_paths: %s opens as shown%s" % [pair[0], _unlike(shown, _looks(false))],
			shown == _looks(false))
	await _open(exported)
	_check("write_paths: the export keeps the steps (%s)" % ("same" if _steps_said() == steps else
		"was %s / now %s" % [steps.left(200), _steps_said().left(200)]), _steps_said() == steps)


## A replace in a Together room, then Ann changes one of its parts, then
## this side's undo: the other 3 back, Ann's kept.
func _r_together_actor() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	var together: Together = _main.get("_together")
	together.check_alone([{"who": "a11ce000", "name": "Ann", "here": true, "owner": false,
		"at": null, "sel": [], "view": null}])
	await _frames(10)
	await _find_into("3023", BLACK, "", DARK_BLUISH_GREY)
	await _bar.call("replace_now")
	await _frames(10)
	# The room's server numbers this side's sends (none here): confirmed, as
	# the next poll would.
	var mine: String = str(together.get("_client"))
	var pending: Array = (together.get("_pending") as Array).duplicate(true)
	for sent: Dictionary in pending:
		together._take([{"seq": together.seq + 1, "client": mine, "cid": int(sent["cid"]),
			"who": "me", "changes": sent["changes"]}])
	await _frames(4)
	print("  confirmed %d sends; %d waiting" % [pending.size(), together.waiting()])
	# Ann paints the model's first grey 3023 Yellow.
	var target: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3023b" and brick.color_code == DARK_BLUISH_GREY \
				and Assemblies.path_of(brick).is_empty():
			target = brick
			break
	var uid: String = together.uid_of(target.id)
	var shown_state: Variant = (together.get("_shown") as Dictionary).get(uid)
	print("  Ann's part %s state %s" % [uid, str(shown_state).left(120)])
	var state: Array = (shown_state as Array).duplicate()
	state[1] = 14
	together._take([{"seq": together.seq + 1, "client": "ann-client", "cid": 0, "who": "a11ce000",
		"changes": {uid: state}}])
	await _frames(10)
	var painted: BrickWorld.Brick = _world.get_brick(together.brick_of(uid))
	print("  after Ann: %s" % (str(painted.color_code) if painted != null else "gone"))
	_shell.run("undo")
	await _frames(10)
	painted = _world.get_brick(together.brick_of(uid))
	print("  after undo: Ann's %s; Black 3023 %d, grey %d, yellow %d" % [str(painted.color_code)
		if painted != null else "gone", _count("3023b", BLACK), _count("3023b", DARK_BLUISH_GREY),
		_count("3023b", 14)])
	_check("together_actor: Ann's Yellow kept, the other 3 Black again", painted != null
		and painted.color_code == 14 and _count("3023b", BLACK) == 3)
	together._stop("")
	await _frames(6)


const PL := """0 FILE pl.mpd
0 Pl
0 Name: pl.mpd
0 Author: Brickworks

1 16 0 0 0 1 0 0 0 1 0 0 0 1 pl.ldr
1 16 0 0 100 1 0 0 0 1 0 0 0 1 pl.ldr
1 4 -40 -8 100 1 0 0 0 1 0 0 0 1 3024.dat
1 4 40 -8 100 1 0 0 0 1 0 0 0 1 3024.dat
0
0 NOFILE
0 FILE pl.ldr
0 Pl
0 Name: pl.ldr
0 Author: Brickworks

1 0 0 -8 0 1 0 0 0 1 0 0 0 1 3023.dat
0
0 NOFILE
"""


## One copy of a sub-model has room for the new part, the other has none
## (the model's own parts beside it): said as "1 has no room and stays", is
## it left, or does the copy follow into the parts beside it?
func _r_room_copies() -> void:
	await _bar_on(PL)
	var before: String = _save()
	await _find_into("3023", BLACK, "3623", -1)
	var said: String = _bar_said()
	var made: Dictionary = _bar.get("made")
	print("  bar: %s" % said)
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(6)
	var after: String = _save()
	print("  done %s; %s" % [done, _diff(before, after)])
	var overlapping: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3623":
			var packed: PackedInt32Array = _builder.boxes_for(_library.mesh_for("3623"), brick.transform)
			for other: int in _builder.lattice.blockers_boxes(packed, brick.id):
				overlapping.append("%s at %s through #%d" % [brick.part_id, brick.transform.origin, other])
	print("  overlapping: %s" % ", ".join(overlapping))
	_check("room_copies: said 1 has no room (%d)" % (made.get("room", []) as Array).size(),
		(made.get("room", []) as Array).size() == 1)
	_check("room_copies: ...and nothing laid through another part (%s)" % ", ".join(overlapping),
		overlapping.is_empty())
	_check("room_copies: ...and the copy said to stay stays a 3023 (%d 3623, %d 3023b)" % [
		_parts_count("3623"), _parts_count("3023b")], _parts_count("3023b") >= 1)
	var answer: String = ""
	await _open(PL)
	answer = await _say("replace_parts", {"find": {"part": "3023"}, "replace": {"part": "3623"}})
	print("  mcp: %s" % answer.replace("\n", " / "))


## What a typed replacement and a colour given as a string resolve to, and
## whether the bar or the answer names it before the replace.
func _r_resolve() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	var finder: RefCounted = Later.script(&"FindReplace").new(_main)
	for typed: String in ["30699", "plate", "3069", "tile 1 x 2", "3023x", "brick", "30230"]:
		var part: String = finder.call("part_of", typed)
		print("  part_of(%s) = %s (%s); library has it as typed: %s" % [typed, part,
			finder.call("part_name", part) if not part.is_empty() else "-", _library.parts.has(typed)])
		_bar.call("set_find", "3023", BLACK)
		_bar.call("set_into", typed, -1)
		await _refresh()
		var said: String = _bar_said()
		print("    bar: %s" % said.right(200))
		_check("resolve: the bar names %s before Replace for '%s'" % [part, typed],
			part.is_empty() or said.contains(part) or said.contains(str(finder.call("part_name", part))))
	for asked: Variant in ["72", "71", "0", "Black", "dark bluish grey", "#FF0000", 72.0]:
		print("  colour_of(%s) = %s" % [var_to_str(asked), finder.call("colour_of", asked)])
	await _open(text)
	var before: String = _save()
	var answer: String = await _say("replace_parts", {"find": {"part": "3023", "color": 0},
		"replace": {"color": "72"}})
	print("  colour \"72\": %s; %s" % [answer.replace("\n", " / "), _diff(before, _save())])
	_check("resolve: colour \"72\" given as a string is 72 or refused", _save() == before
		or _count("3023b", 72) == 4)


## Orthanc-size: the bar's find and plan, and the replace, timed.
func _r_big() -> void:
	var text: String = FileAccess.get_file_as_string("res://vendor/omr/files/10179-1.mpd")
	var began: int = Time.get_ticks_msec()
	await _bar_on(text)
	print("  opened %d parts in %d ms" % [_world.brick_count(), Time.get_ticks_msec() - began])
	var before: String = _save()
	began = Time.get_ticks_msec()
	_bar.call("set_find", "3023", -1)
	_bar.call("set_into", "", -1)
	await _refresh()
	var found: Dictionary = _bar.get("found")
	print("  find 3023: %d found, %d ms; %s" % [(found["ids"] as Array).size(), Time.get_ticks_msec() - began,
		_bar_said().left(300)])
	began = Time.get_ticks_msec()
	_bar.call("set_into", "3069b", -1)
	await _refresh()
	print("  plan into 3069b: %d ms; %s" % [Time.get_ticks_msec() - began, _bar_said().left(400)])
	began = Time.get_ticks_msec()
	var done: Dictionary = await _bar.call("replace_now")
	print("  replace: %s in %d ms" % [done, Time.get_ticks_msec() - began])
	await _frames(6)
	began = Time.get_ticks_msec()
	var undone: String = await _undone()
	print("  undo %d ms" % (Time.get_ticks_msec() - began))
	_check("big: undo to the byte (%s)" % _diff(before, undone), undone == before)
