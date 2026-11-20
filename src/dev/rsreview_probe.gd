## rsreview's independent attacks on rareswap, kept by rsfix: what the rare
## swaps write, what they pick, and what they cost.
##
##   godot --headless --path . --script src/dev/rsreview_probe.gd
##
## - lpub, inherit, motion: someone else's file (LPub, BTG, LDCad groups,
##   CRLF), a sub-model placed in two colours, a motion's joint line: only
##   the swapped lines change, one undo, undo and redo to the byte;
## - mcp_edges, mcp_none: replace_parts rare=true's edges, rare=false and a
##   lone lots= keeping plain replace (rsreview F4), "3622.DAT/379" (F9);
## - held, control: a part lifted in hand when a swap runs goes back where
##   it was first, none lost (F5);
## - shapes: mould pairs judged by shape; a print offered its own plain part,
##   still made (3626cpbb to 3626c, F7); a mould holding every connection
##   and more (3665a to 3665b, F8);
## - webshard: a candidate's colours file on its way, then come: the same
##   offer as the desktop's (F3);
## - trans: see-through, chrome, metallic and pearl lots, none picked across;
## - sample: the ten gallery models' offers (RSR_OUT/lots.tsv, for
##   check_lots.py), each picked only where it keeps the look (F1);
## - catalogue: every rare part and colour of the colours files offered its
##   colour as the rule offers one: none picked across transparency or finish
##   or over RareSwap.CLOSE_DE (RSR_OUT/catalogue.tsv);
## - speed2, attrib: the parts list's open and the rare row's first press.
##
## RSR_CASES=lpub,inherit,motion,... for some (all but speed when none);
## RSR_BASE=1 on the merge base: the swaps
## made by replace_parts find=/replace= with the swaps rareswap offers there.
## RSR_OUT=DIR for the TSVs.
extends "res://src/dev/copyfaults_probe.gd"

## What a run with no RSR_CASES runs.
const DEFAULT_CASES: Array = ["lpub", "inherit", "motion", "mcp_edges", "held", "control",
	"mcp_none", "shapes", "webshard", "trans", "sample", "catalogue", "speed2", "attrib"]

## The swaps rareswap's own run offers for these lots (its prove1 log), for
## the merge base, which has no RareSwap: [part, colour, into part, into colour].
const BASE_SWAPS: Array = [["3622", 379, "", 71], ["87087", 379, "", 71], ["4032b", 72, "4032a", -1],
	["3070a", 14, "3070b", -1], ["3679", 0, "", 71]]

const LPUB := "0 FILE lpubtest.mpd
0 LPub Test Model
0 Name: lpubtest.mpd
0 Author: Ann Other [aother]
0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt
0 !LPUB ASSEM MODEL_SCALE GLOBAL 1.0000
0 !LPUB MULTI_STEP BEGIN
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 379 120 0 0 1 0 0 0 1 0 0 0 1 3622.dat
0 STEP
1 72 240 -8 0 1 0 0 0 1 0 0 0 1 4032b.dat
0 STEP
0 !LPUB MULTI_STEP END
0 BUFEXCHG A STORE
0 MLCAD BTG Roof
1 14 -120 -8 0 1 0 0 0 1 0 0 0 1 3070a.dat
0 MLCAD BTG Roof
1 0  360 -8 0 1 0 0 0 1 0 0 0 1 2431p70.dat
0 STEP
0 BUFEXCHG A RETRIEVE
0 ROTSTEP 0 90 0 REL
0 !LDCAD GROUP_DEF [topLevel=true] [LID=1] [GID=Nb0SPNsyhmwHoIF] [name=Pods] [center=0 0 0]
0 !LDCAD GROUP_NXT [ids=1] [nrs=-1]
1 16 0 0 200 1 0 0 0 1 0 0 0 1 lpub_wing.ldr
0 !LDCAD GROUP_NXT [ids=1] [nrs=-1]
1 16 0 0 -200 -1 0 0 0 1 0 0 0 1 lpub_wing.ldr
0 STEP
0 NOFILE

0 FILE lpub_wing.ldr
0 Wing
0 Name: lpub_wing.ldr
0 Author: Ann Other [aother]
1 15 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 379 -20 -24 0 1 0 0 0 1 0 0 0 1 87087.dat
1 379 40 -24 0 1 0 0 0 1 0 0 0 1 3622.dat
0 STEP
0 NOFILE
"

const INHERIT := "0 FILE inherit.mpd
0 Three pods
0 Name: inherit.mpd
0 Author: Ann Other [aother]
1 379 0 0 0 1 0 0 0 1 0 0 0 1 pod.ldr
1 4 0 0 100 1 0 0 0 1 0 0 0 1 pod.ldr
1 379 0 0 -100 -1 0 0 0 1 0 0 0 1 pod.ldr
0 NOFILE

0 FILE pod.ldr
0 Pod
0 Name: pod.ldr
0 Author: Ann Other [aother]
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 3622.dat
1 15 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(1500.0).timeout.connect(func() -> void:
		print("rsreview probe: not finished in time")
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
	# The suite runs every case but the old speed one (rsfix): RSR_CASES=
	# names some.
	var cases: PackedStringArray = OS.get_environment("RSR_CASES").split(",", false)
	if cases.is_empty():
		cases = PackedStringArray(DEFAULT_CASES)
	for name: String in cases:
		print("\n== %s" % name)
		match name:
			"lpub": await _case_lpub()
			"inherit": await _case_inherit()
			"motion": await _case_motion()
			"mcp_edges": await _case_mcp_edges()
			"held": await _case_held()
			"shapes": await _case_shapes()
			"sample": await _case_sample()
			"speed": await _case_speed()
			"webshard": await _case_webshard()
			"attrib": await _case_attrib()
			"control": await _case_control()
			"mcp_none": await _case_mcp_none()
			"trans": await _case_trans()
			"speed2": await _case_speed2()
			"catalogue": await _case_catalogue()
			_: _check("no such case %s" % name, false)
	print("\nrsreview probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


func _base() -> bool:
	return not OS.get_environment("RSR_BASE").is_empty()


func _open_as(text: String, name: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(text, name)
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)


func _count(part: String, colour: int) -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and brick.color_code == colour:
			count += 1
	return count


func _colours_of(part: String) -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			out[brick.color_code] = int(out.get(brick.color_code, 0)) + 1
	return out


func _list_up() -> InventoryPanel:
	var list: InventoryPanel = _main.get("_inventory_made")
	if list != null and list.is_showing():
		list.hide_list()
	_shell.run("parts_list")
	await _frames(6)
	await _filled()
	return _main.get("_inventory")


## The parts list fills across frames since smalls9 (b13cdf5c8), so its rows
## come a few frames after the command on a big model. Wait for it as a person
## waits for the rows; a build without is_filling (the base) fills at once.
func _filled() -> void:
	for n: int in 3000:
		var list: Object = _main.get("_inventory")
		if list != null and (not list.has_method("is_filling") or not bool(list.call("is_filling"))):
			return
		await process_frame
	_check("the parts list fills within 3000 frames", false)


## Every rare lot swapped as a person does (rsrev: the parts list's row,
## Swap; base: replace_parts find=/replace= for each of BASE_SWAPS present),
## as one undo step where the branch makes one. The undo steps it made.
func _swap_all(picks: Array = []) -> int:
	var depth: int = _builder.history_depth()
	if _base():
		for swap: Array in BASE_SWAPS:
			if _count(swap[0], swap[1]) == 0:
				continue
			var into: Dictionary = {}
			if not str(swap[2]).is_empty():
				into["part"] = swap[2]
			if int(swap[3]) >= 0:
				into["color"] = swap[3]
			var said: String = await _say("replace_parts", {"find": {"part": swap[0], "color": swap[1]},
				"replace": into})
			print("    base replace %s/%d: %s" % [swap[0], swap[1], said.get_slice("\n", 0).left(160)])
		return _builder.history_depth() - depth
	var list: InventoryPanel = await _list_up()
	var row: Control = list.controls_by_name().get("parts_rare")
	if row == null:
		print("    no rare row")
		return 0
	(row as Button).pressed.emit()
	var until: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until and (bool(list.get("_swapping"))
			or not list.controls_by_name().has("parts_swap_row")):
		await process_frame
	for lot: RefCounted in list.get("_rare"):
		# Every swap offered picked, a print's plain part aside, as a builder
		# ticks them: the writer is under attack here, not the defaults.
		if not picks.is_empty():
			lot.set("picked", picks.has(lot.get("key")) and lot.call("offered"))
		elif lot.call("offered") and not lot.call("drops_print"):
			lot.set("picked", true)
		print("    %s%s" % [lot.call("get", "key"), "  " + (list.get("_swapper") as RefCounted).call("lot_words", lot)
			+ ("" if lot.get("picked") else "  (not picked)")])
	var done: Dictionary = await list.swap_picked()
	print("    swapped: %s" % str(done.get("words", "")))
	list.hide_list()
	await _frames(6)
	return _builder.history_depth() - depth


## Line by line, where [param a] and [param b] differ: [line, before, after]
## for each, the \r kept; or a count mismatch.
static func _line_diff(a: String, b: String) -> Array:
	var x: PackedStringArray = a.split("\n")
	var y: PackedStringArray = b.split("\n")
	var out: Array = []
	if x.size() != y.size():
		return [[-1, "%d lines" % x.size(), "%d lines" % y.size()]]
	for n: int in x.size():
		if x[n] != y[n]:
			out.append([n + 1, x[n].c_escape(), y[n].c_escape()])
	return out


## Whether every changed line differs from its old self only in its colour
## (word 1) or part (word 14): what a swap may change.
static func _only_swapped(changes: Array) -> String:
	var bad := PackedStringArray()
	for change: Array in changes:
		if int(change[0]) < 0:
			return "line count changed: %s -> %s" % [change[1], change[2]]
		var was: PackedStringArray = str(change[1]).c_unescape().split(" ", false)
		var now: PackedStringArray = str(change[2]).c_unescape().split(" ", false)
		if was.size() != now.size() or was.size() < 15 or was[0] != "1":
			bad.append("line %d: %s -> %s" % change)
			continue
		for k: int in was.size():
			if k != 1 and k != 14 and was[k] != now[k]:
				bad.append("line %d word %d: %s -> %s" % [change[0], k, was[k], now[k]])
	return "; ".join(bad)


func _round_trip(tag: String, text: String, title: String, picks: Array = []) -> void:
	await _open_as(text, title)
	var before: String = _save()
	_check("%s: opened and saved to the byte (%s)" % [tag, _line_diff(text, before).slice(0, 3)],
		before == text)
	var steps: int = await _swap_all(picks)
	var after: String = _save()
	var changes: Array = _line_diff(before, after)
	for change: Array in changes:
		print("    line %d: %s\n         -> %s" % change)
	_check("%s: one undo step (%d)" % [tag, steps], steps == 1)
	var odd: String = _only_swapped(changes)
	_check("%s: only the swapped lines changed, each only in part or colour%s" % [tag,
		"" if odd.is_empty() else ": " + odd], odd.is_empty() and not changes.is_empty())
	_check("%s: CRLF kept on every line (%d of %d without)" % [tag,
		Array(after.split("\n")).filter(func(l: String) -> bool: return not l.is_empty() and not l.ends_with("\r")).size(),
		after.split("\n").size()], not text.contains("\r") or Array(after.split("\n")).all(
			func(l: String) -> bool: return l.is_empty() or l.ends_with("\r")))
	var shown: Array = _looks()
	var saved_twice: String = _save()
	_check("%s: saved twice alike" % tag, saved_twice == after)
	_shell.run("undo")
	await _frames(8)
	_check("%s: undo, the file opened to the byte (%s)" % [tag, _line_diff(before, _save()).slice(0, 3)],
		_save() == before)
	_shell.run("redo")
	await _frames(8)
	_check("%s: redo, the swap's file to the byte (%s)" % [tag, _line_diff(after, _save()).slice(0, 3)],
		_save() == after)
	await _open_as(after, title)
	_check("%s: reopened, every part and colour as shown%s" % [tag, _unlike(shown, _looks())],
		shown == _looks())
	_check("%s: reopened, saves to itself (%s)" % [tag, _line_diff(after, _save()).slice(0, 3)],
		_save() == after)


# -- kept --------------------------------------------------------------------------


func _case_lpub() -> void:
	await _round_trip("lpub LF", LPUB, "LPub Test Model")
	await _round_trip("lpub CRLF", LPUB.replace("\n", "\r\n"), "LPub Test Model")


## A sub-model placed in Sand Blue twice (one mirrored) and in Red once, its
## 3622 of colour 16: the Sand Blue ones rare, the Red one common.
func _case_inherit() -> void:
	await _open_as(INHERIT, "Three pods")
	print("    before: 3622 %s" % _colours_of("3622"))
	var before: String = _save()
	var steps: int = await _swap_all()
	var after: String = _save()
	print("    after: 3622 %s, %d undo steps" % [_colours_of("3622"), steps])
	for change: Array in _line_diff(before, after):
		print("    line %d: %s\n         -> %s" % change)
	print("    --- the file after:\n%s" % after)
	_check("inherit: the Red pod's 3622 stays Red (%s)" % _colours_of("3622"), _count("3622", 4) == 1)
	_check("inherit: the Sand Blue pods' 3622 swapped (%s)" % _colours_of("3622"), _count("3622", 379) == 0)
	_check("inherit: the pods' 3001 stay White (%s)" % _colours_of("3001"), _count("3001", 15) == 3)
	var shown: Array = _looks()
	await _open_as(after, "Three pods")
	_check("inherit: reopened as shown%s" % _unlike(shown, _looks()), shown == _looks())
	_shell.run("undo")


## maintenance_robot with its turntable top in Black (rare), a motion on it.
func _case_motion() -> void:
	var text: String = FileAccess.get_file_as_string("res://tools/web/gallery_seeds/maintenance_robot.ldr") \
		.replace("JOINT PART 3679 71 120 -176 -100", "JOINT PART 3679 0 120 -176 -100") \
		.replace("1 71 120 -176 -100 1 0 0 0 1 0 0 0 1 3679.dat", "1 0 120 -176 -100 1 0 0 0 1 0 0 0 1 3679.dat")
	await _open_as(text, "Maintenance Robot")
	print("    joints found before: %s" % _joints_found())
	var before: String = _save()
	var steps: int = await _swap_all(["3679/0"] if not _base() else [])
	var after: String = _save()
	print("    3679: %s, %d undo steps" % [_colours_of("3679"), steps])
	for line: String in after.split("\n"):
		if line.contains("MOTION_TRACK"):
			print("    saved: %s" % line)
	_check("motion: the turntable top swapped (%s)" % _colours_of("3679"), _count("3679", 0) == 0)
	_check("motion: its motion's joint line names the part as it now is",
		after.contains("JOINT PART 3679 71 120 -176 -100"))
	await _open_as(after, "Maintenance Robot")
	var found: Array = _joints_found()
	print("    joints found reopened: %s" % found)
	_check("motion: reopened, the motion still finds its joint (%s)" % found,
		not found.is_empty() and found.all(func(id: int) -> bool: return id != 0))


func _joints_found() -> Array:
	var out: Array = []
	var motions: Motions = _world.motions
	if motions == null:
		return out
	for motion: Motions.Motion in motions.list:
		for joint: Motions.Joint in motion.joints():
			if joint.by == "part":
				out.append(Motions.part_at(joint, _world, _store.lift()))
	return out


# -- MCP ----------------------------------------------------------------------------


func _case_mcp_edges() -> void:
	# A model whose one rare lot (the rim, 3482 in Light Bluish Grey, in no
	# set) has a close colour of its finish, Light Grey: swapped by default,
	# said close, one undo step (F1, F2).
	await _open(FileAccess.get_file_as_string("res://src/dev/fixtures/metalines/drive.ldr"))
	var before: String = _save()
	var depth: int = _builder.history_depth()
	var said: String = await _say("replace_parts", {"rare": true})
	print("    a close colour: %s" % said.replace("\n", " / "))
	_check("mcp: a rare lot with a close colour of its finish: swapped by default, said close, one undo step",
		_save() != before and _builder.history_depth() == depth + 1 and said.contains("a close colour")
		and _count("3482", 7) == 1 and said.contains("Swapped 1 rare lot"))
	_shell.run("undo")
	await _frames(6)
	_check("mcp: ...undone to the byte", _save() == before)
	# The kept fixture's Sand Blue lots have only a different colour: listed
	# as kept, and why, with the moulds swapped.
	await _open(FileAccess.get_file_as_string("res://src/dev/fixtures/rareswap_kept.mpd"))
	before = _save()
	said = await _say("replace_parts", {"rare": true})
	_check("mcp: a lot whose swap changes the look is kept and says so (Sand Blue 3622 %d)" % _count("3622", 379),
		_count("3622", 379) == 1 and said.contains("(ΔE 13.9); a different colour [3622/379] (kept: it would change how the model looks; name it in lots= to swap it)"))
	_shell.run("undo")
	await _frames(6)
	# The kept fixture: a lot not rare, an unknown lot, an empty list.
	var kept: String = FileAccess.get_file_as_string("res://src/dev/fixtures/rareswap_kept.mpd")
	await _open(kept)
	before = _save()
	for args: Dictionary in [{"rare": true, "lots": ["3001/4"]}, {"rare": true, "lots": ["zzzz/1"]},
			{"rare": true, "lots": []}, {"rare": true, "lots": ["3622/379", "3001/4"]},
			{"lots": ["3622/379"]}, {"rare": false, "find": {"part": "3001"}, "replace": {"color": 1}},
			{"rare": true, "lots": ["3622.DAT/379 "]}, {"rare": true, "preview": true, "lots": ["3622/379"]},
			{"rare": true, "lots": "3622/379"}]:
		depth = _builder.history_depth()
		said = await _say("replace_parts", args)
		var now: String = _save()
		var steps: int = _builder.history_depth() - depth
		var changed: Array = _minus(now, before)
		print("    %s\n      -> %s\n      changed lines %s, undo steps %d" % [JSON.stringify(args),
			said.replace("\n", "\n         "), changed, steps])
		var named: String = JSON.stringify(args)
		if args.get("rare") == false:
			# rare=false is a plain Find and Replace (F4): every 3001 Blue.
			_check("mcp: %s is a plain replace: the 3001s made Blue in one undo step (%d lines, %d steps)"
				% [named, changed.size(), steps], steps == 1 and _count("3001", 1) > 0
				and said.contains("Replaced "))
		elif not args.has("rare"):
			_check("mcp: %s alone says lots= goes with rare=true, and writes nothing" % named,
				now == before and steps == 0 and said.contains("lots= goes with rare=true"))
		elif args.get("lots") is Array and (args["lots"] as Array).size() == 1 \
				and str(args["lots"][0]).contains("DAT") and not args.has("preview"):
			# "3622.DAT/379 " is the lot 3622/379, tidied as find= is (F9).
			_check("mcp: %s names 3622/379: it alone swaps (%d lines, 3622 in Sand Blue %d)" % [named,
				changed.size(), _count("3622", 379)], steps == 1 and _count("3622", 379) == 0
				and not said.contains("No rare lot"))
		if now != before:
			_shell.run("undo")
			await _frames(6)
			_check("mcp: %s undone to the byte" % JSON.stringify(args), _save() == before)
	# Twice: the second has nothing picked left.
	said = await _say("replace_parts", {"rare": true})
	var once: String = _save()
	depth = _builder.history_depth()
	said = await _say("replace_parts", {"rare": true})
	print("    twice: %s" % said.get_slice("\n", said.count("\n")))
	_check("mcp: rare=true twice, the second changes nothing and makes no undo step (%d)"
		% (_builder.history_depth() - depth), _save() == once and _builder.history_depth() == depth)


# -- selected, in hand ------------------------------------------------------------


func _case_held() -> void:
	var kept: String = FileAccess.get_file_as_string("res://src/dev/fixtures/rareswap_kept.mpd")
	for how: String in ["selected", "in hand"]:
		await _open(kept)
		var before: String = _save()
		var target: BrickWorld.Brick = null
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id == "3622" and brick.color_code == 379:
				target = brick
		_builder.clear_selection()
		_builder.selection[target.id] = true
		_builder.selection_changed.emit(1)
		var parts: int = _world.bricks().size()
		var depth0: int = _builder.history_depth()
		if how == "in hand":
			var lifted: int = _builder.lift_selection()
			print("    lifted %d, carrying %s" % [lifted, _builder.is_carrying()])
		var steps: int = await _swap_all()
		print("    %s: %d undo steps, carrying %s, parts %d (were %d), 3622 %s" % [how, steps,
			_builder.is_carrying(), _world.bricks().size(), parts, _colours_of("3622")])
		if how == "in hand" and not _base():
			# F5: the lifted part went back where it was before the swap, as
			# Escape puts it (its lift step with it), and the swap is one step.
			# Lifted, it was off the parts list, so its lot was not offered.
			_check("in hand: put back first, nothing left in hand, none lost, one step over the start (parts %d, were %d; %d steps)"
				% [_world.bricks().size(), parts, _builder.history_depth() - depth0],
				not _builder.is_carrying() and _world.bricks().size() == parts
				and _count("3622", 379) == 1 and _builder.history_depth() == depth0 + 1)
			steps = _builder.history_depth() - depth0
		if _builder.is_carrying():
			_builder.cancel_carry()
			await _frames(6)
		var after: String = _save()
		print("    %s after put back: parts %d, 3622 %s, file diff %s" % [how, _world.bricks().size(),
			_colours_of("3622"), _diff(before, after)])
		_check("%s: one undo step (%d)" % [how, steps], steps == 1)
		_check("%s: no part lost or doubled (%d, were %d)" % [how, _world.bricks().size(), parts],
			_world.bricks().size() == parts)
		var looks: Array = _looks()
		_shell.run("undo")
		await _frames(8)
		_check("%s: undo, the file to the byte (%s)" % [how, _diff(before, _save())], _save() == before)
		_shell.run("redo")
		await _frames(8)
		_check("%s: redo, as after%s" % [how, _unlike(looks, _looks())], looks == _looks())


# -- right swaps --------------------------------------------------------------------


## Mould pairs: same_shape, and how their connection points differ.
func _case_shapes() -> void:
	if _base():
		return
	var swapper: RefCounted = Later.script(&"RareSwap").new(_library)
	var finder: FindReplace = FindReplace.new(_main)
	var pairs: Array = [["3626cpbb", "3626c"], ["3626cpbb", "3626a"], ["3626c", "3626a"], ["3626c", "3626b"],
		["3626a", "3626b"], ["3062a", "3062b"], ["4085a", "4085b"], ["4085b", "4085c"], ["4085a", "4085c"],
		["4081a", "4081b"], ["3665a", "3665"], ["3794a", "3794b"], ["4032a", "4032b"], ["3070a", "3070b"],
		["3069a", "3069b"], ["3068a", "3068b"], ["2412a", "2412b"], ["3040a", "3040b"], ["2454a", "2454b"],
		["4073", "6141"], ["3957a", "3957b"], ["6192a", "6192b"], ["4589", "4589b"], ["3941", "6143"],
		["60481a", "60481"], ["4287c", "4287b"], ["4287a", "4287b"], ["3010", "3010pt8"], ["3039", "3039p13"],
		["2431", "2431p70"], ["98138", "98138p07"], ["30414", "4162"], ["3008", "3008a"], ["32000", "32000a"],
		["2877", "30363"], ["3747a", "3747b"], ["3002", "3002a"], ["4070", "4070a"], ["3020", "3020a"]]
	for pair: Array in pairs:
		var a: Lbm.PartMesh = _library.mesh_for(pair[0])
		var b: Lbm.PartMesh = _library.mesh_for(pair[1])
		if a == null or b == null:
			print("    %s / %s: no shape (%s, %s)" % [pair[0], pair[1], a != null, b != null])
			continue
		var pa: PackedStringArray = FindReplace._points(a, Transform3D.IDENTITY)
		var pb: PackedStringArray = FindReplace._points(b, Transform3D.IDENTITY)
		var only_a: Array = Array(pa).filter(func(p: String) -> bool: return not pb.has(p))
		var only_b: Array = Array(pb).filter(func(p: String) -> bool: return not pa.has(p))
		print("    %s / %s: same_shape %s; size %s / %s, centre off %.2f; points %d / %d; only first %s; only second %s; candidates of first %s" % [
			pair[0], pair[1], RareSwap.same_shape(a, b), a.bounds.size, b.bounds.size,
			a.bounds.get_center().distance_to(b.bounds.get_center()), pa.size(), pb.size(),
			only_a.slice(0, 4), only_b.slice(0, 4), swapper.call("equal_candidates", pair[0])])
	# The heads: what each print is offered, and why not 3626c.
	for key: Array in [["3626cpbb", 14], ["3626cpbd", 70], ["3626bpx1", 14]]:
		var lot := RareSwap.Lot.new()
		lot.part = key[0]
		lot.colour = key[1]
		lot.key = "%s/%d" % key
		var info: PartLibrary.PartInfo = _library.parts.get(_library.resolve(key[0]))
		lot.printed = info != null and info.decor() != 0
		await swapper.call("offer", lot, finder)
		print("    offer %s: print_of %s; -> part %s colour %d sets %d; sets 3626a/b/c in it: %d %d %d; %s" % [lot.key,
			info.print_of if info != null else "?", lot.into_part, lot.into_colour, lot.into_sets,
			_library.sets_in_colour("3626a", key[1]), _library.sets_in_colour("3626b", key[1]),
			_library.sets_in_colour("3626c", key[1]), swapper.call("into_words", lot)])
		if key[0] == "3626cpbb":
			# Its own plain part, still made in Yellow, not the 1975 mould (F7).
			_check("shapes: 3626cpbb in Yellow is offered its own plain part 3626c, not picked (%s)"
				% swapper.call("into_words", lot), lot.into_part == "3626c" and not lot.picked)
	# A mould holding every connection of the old one and more (F8).
	var slope := RareSwap.Lot.new()
	slope.part = "3665a"
	slope.colour = 0
	slope.key = "3665a/0"
	slope.count = 2
	await swapper.call("offer", slope, finder)
	print("    offer 3665a/0: %s" % swapper.call("into_words", slope))
	_check("shapes: 3665a in Black is offered 3665b, holding its connections and more, picked (%s)"
		% swapper.call("into_words", slope), slope.into_part == "3665b" and slope.more_points > 0
		and slope.picked and str(swapper.call("into_words", slope)).contains("holding all its connections"))
	# And a part with no other mould: its none words say its own count.
	var lone := RareSwap.Lot.new()
	lone.part = "60748"
	lone.colour = 0
	lone.key = "60748/0"
	await swapper.call("offer", lone, finder)
	print("    offer 60748/0: %s" % swapper.call("into_words", lone))


## Every lot of the ten gallery models, with its offer, for an outside
## check (python): model, key, sets, printed, into part, into colour, into
## sets, ΔE, picked.
func _case_sample() -> void:
	if _base():
		return
	var ten: Array = ["models/orthanc.ldr", "models/corner_shop.ldr",
		"tools/web/gallery_seeds/oak_treehouse.ldr", "tools/web/gallery_seeds/red_fox.ldr",
		"tools/web/gallery_seeds/sleeping_dragon.ldr", "tools/web/gallery_seeds/lakeside_campsite.ldr",
		"models/barn_owl.ldr", "tools/web/gallery_seeds/vintage_tractor.ldr",
		"tools/web/gallery_seeds/maintenance_robot.ldr", "tools/web/gallery_seeds/village_bakery.ldr"]
	var rows := PackedStringArray(["model\tkey\tsets\tprinted\tinto_part\tinto_colour\tinto_sets\tdelta_e\tpicked\tcount"])
	var finder: FindReplace = FindReplace.new(_main)
	var wrong := PackedStringArray()
	var picked_n: int = 0
	var colour_n: int = 0
	for file: String in ten:
		await _open(FileAccess.get_file_as_string("res://" + file))
		var swapper: RefCounted = Later.script(&"RareSwap").new(_library)
		var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
		var rare: Dictionary = swapper.call("rare_of", stock)
		await swapper.call("offer_all", rare["lots"], finder)
		var targets: Dictionary = {}     ## a source colour -> the colours its lots go to
		for lot: RefCounted in rare["lots"]:
			rows.append("%s\t%s\t%d\t%s\t%s\t%d\t%d\t%.2f\t%s\t%d" % [file.get_file().get_basename(),
				lot.get("key"), lot.get("sets"), lot.get("printed"), lot.get("into_part"),
				lot.get("into_colour"), lot.get("into_sets"), lot.get("delta_e"), lot.get("picked"),
				lot.get("count")])
			print("    %s %s%s" % [file.get_file().get_basename(), swapper.call("lot_words", lot),
				"" if lot.get("picked") else "  (not picked)"])
			if lot.get("picked"):
				picked_n += 1
			if int(lot.get("into_colour")) < 0:
				continue
			colour_n += 1
			var was: PartLibrary.BrickColor = _library.color(int(lot.get("colour")))
			var now: PartLibrary.BrickColor = _library.color(int(lot.get("into_colour")))
			var key: int = int(lot.get("colour"))
			if not targets.has(key):
				targets[key] = {}
			targets[key][int(lot.get("into_colour"))] = true
			if lot.get("picked") and (float(lot.get("delta_e")) > RareSwap.CLOSE_DE
					or not _crossed(was, now).is_empty()):
				wrong.append("%s %s picked: %s" % [file.get_file().get_basename(), lot.get("key"),
					swapper.call("into_words", lot)])
		if file.ends_with("red_fox.ldr"):
			var orange: Array = (targets.get(25, {}) as Dictionary).keys()
			_check("sample: red_fox's Orange lots offered one colour (%s), none picked to change it"
				% ", ".join(orange.map(func(code: int) -> String: return _library.color(code).name)),
				orange.size() == 1 and not (rare["lots"] as Array).any(func(lot: RefCounted) -> bool:
					return int(lot.get("colour")) == 25 and lot.get("picked")))
	_check("sample: no colour swap picked over ΔE %.0f or across transparency or finish (%d picked of %d lots, %d colour swaps)%s"
		% [RareSwap.CLOSE_DE, picked_n, rows.size() - 1, colour_n, "" if wrong.is_empty() else ": " + "; ".join(wrong)],
		wrong.is_empty())
	var out: String = OS.get_environment("RSR_OUT")
	if not out.is_empty():
		var f := FileAccess.open(out.path_join("lots.tsv"), FileAccess.WRITE)
		f.store_string("\n".join(rows) + "\n")
		f.close()
		print("    written %s (%d lots)" % [out.path_join("lots.tsv"), rows.size() - 1])


# -- speed --------------------------------------------------------------------------


## The parts list opened on Orthanc: its whole frame, the rare row's part of
## it, and the swaps list's working out.
func _case_speed() -> void:
	for file: String in ["models/orthanc.ldr", "tools/web/gallery_seeds/village_bakery.ldr"]:
		await _open(FileAccess.get_file_as_string("res://" + file))
		for round: int in 3:
			var list: InventoryPanel = _main.get("_inventory_made")
			if list != null and list.is_showing():
				list.hide_list()
			await _frames(4)
			var t0: int = Time.get_ticks_usec()
			_shell.run("parts_list")
			var t1: int = Time.get_ticks_usec()
			await _frames(6)
			await _filled()
			list = _main.get("_inventory")
			var rare_ms: float = -1.0
			if not _base():
				var swapper: RefCounted = Later.script(&"RareSwap").new(_library)
				var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
				var r0: int = Time.get_ticks_usec()
				swapper.call("rare_of", stock)
				rare_ms = (Time.get_ticks_usec() - r0) / 1000.0
			print("    %s round %d: parts_list opened in %.1f ms (rare_of alone %.1f ms)" % [file.get_file(),
				round, (t1 - t0) / 1000.0, rare_ms])
			if not _base() and round == 2:
				var row: Control = list.controls_by_name().get("parts_rare")
				if row != null:
					var worst: float = 0.0
					var frames: int = 0
					var s0: int = Time.get_ticks_usec()
					(row as Button).pressed.emit()
					var last: int = Time.get_ticks_usec()
					worst = (last - s0) / 1000.0
					while bool(list.get("_swapping")) and frames < 2000:
						await process_frame
						var now: int = Time.get_ticks_usec()
						worst = maxf(worst, (now - last) / 1000.0)
						last = now
						frames += 1
					print("    %s: swaps list worked out over %d frames, %.1f ms in all, worst frame %.1f ms" % [
						file.get_file(), frames, (Time.get_ticks_usec() - s0) / 1000.0, worst])
					list.call("_show_rows")
		var l2: InventoryPanel = _main.get("_inventory_made")
		if l2 != null and l2.is_showing():
			l2.hide_list()


# -- the web's colours files -------------------------------------------------------


## As the web is the first time: a part's colours file not here yet. The
## equal part's file on its way when the swap is offered.
func _case_webshard() -> void:
	if _base():
		return
	var swapper: RefCounted = Later.script(&"RareSwap").new(_library)
	var finder: FindReplace = FindReplace.new(_main)
	for key: Array in [["3070a", 14], ["4032b", 72]]:
		var lot := RareSwap.Lot.new()
		lot.part = key[0]
		lot.colour = key[1]
		lot.key = "%s/%d" % key
		await swapper.call("offer", lot, finder)
		var here: String = "%s %d %d" % [lot.into_part, lot.into_colour, lot.into_sets]
		var cands: PackedStringArray = swapper.call("equal_candidates", key[0])
		var sets_held: Dictionary = _library.get("_colour_sets")
		var out: Dictionary = _library.get("_colour_sets_out")
		var kept: Dictionary = {}
		for other: String in cands:
			var file: int = PartLibrary.colour_shard_of(other)
			if file == PartLibrary.colour_shard_of(key[0]):
				continue
			kept[file] = sets_held.get(file)
			sets_held[file] = false
			out[file] = true
		# The files come in 1.5 s on, as a fetch's answer does, and say so.
		var came: Array = [0]
		create_timer(1.5).timeout.connect(func() -> void:
			for file: int in kept:
				sets_held[file] = kept[file]
				out.erase(file)
			came[0] = Time.get_ticks_msec()
			_library.colour_sets_came.emit())
		var asked: int = Time.get_ticks_msec()
		await swapper.call("offer", lot, finder)
		var web: String = "%s %d %d" % [lot.into_part, lot.into_colour, lot.into_sets]
		print("    %s: desktop offers [%s]; with the candidates' files on their way [%s], offered %d ms on (the files came %d ms on)"
			% [lot.key, here, web, Time.get_ticks_msec() - asked, int(came[0]) - asked if int(came[0]) > 0 else -1])
		_check("webshard %s: the same offer while a candidate's colours file is on its way (%s)" % [lot.key, web],
			here == web and lot.into_part == {"3070a": "3070b", "4032b": "4032a"}[key[0]])


## Lifted and put back with nothing swapped: the part count, for the held case.
func _case_control() -> void:
	await _open(FileAccess.get_file_as_string("res://src/dev/fixtures/rareswap_kept.mpd"))
	var before: String = _save()
	var parts: int = _world.bricks().size()
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3622" and brick.color_code == 379:
			_builder.clear_selection()
			_builder.selection[brick.id] = true
			_builder.selection_changed.emit(1)
	print("    carrying before lift: %s" % (_builder.carrying != null))
	var lifted: int = _builder.lift_selection()
	await _frames(6)
	print("    lifted %d: parts in the world %d (were %d)" % [lifted, _world.bricks().size(), parts])
	_builder.cancel_carry()
	await _frames(6)
	_check("control: lifted and put back with Escape, nothing swapped: parts %d (were %d), file the same (%s)"
		% [_world.bricks().size(), parts, _diff(before, _save())], _world.bricks().size() == parts and _save() == before)
	# And the same with the parts list opened and closed while it is held.
	_builder.lift_selection()
	await _frames(6)
	_shell.run("parts_list")
	await _frames(10)
	await _filled()
	var list: Control = _main.get("_inventory")
	var named: Dictionary = list.call("controls_by_name")
	print("    held, the parts list says: %s" % (str((named["parts_rare"] as Button).text) if named.has("parts_rare") else "(no rare row)"))
	list.call("hide_list")
	_builder.cancel_carry()
	await _frames(6)
	_check("control: held while the parts list opened and closed, put back: parts %d (were %d)"
		% [_world.bricks().size(), parts], _world.bricks().size() == parts and _save() == before)
	if _base():
		return
	# A plain Find and Replace while a part is in hand (F5, plain path): put
	# back first, then replaced with the rest, one undo to the byte.
	var depth: int = _builder.history_depth()
	_builder.lift_selection()
	await _frames(6)
	var said: String = await _say("replace_parts", {"find": {"part": "3622", "color": 379},
		"replace": {"color": 1}})
	print("    held, replace_parts 3622/379 -> Blue: %s" % said.replace("\n", " / "))
	_check("control: a plain replace with the part in hand puts it back first and replaces all, one step (parts %d, were %d; Blue 3622 %d; %d undo steps)"
		% [_world.bricks().size(), parts, _count("3622", 1), _builder.history_depth() - depth],
		not _builder.is_carrying() and _world.bricks().size() == parts and _count("3622", 379) == 0
		and _count("3622", 1) > 0 and said.contains("went back where it was first")
		and _builder.history_depth() == depth + 1)
	_shell.run("undo")
	await _frames(8)
	_check("control: that replace undone, the file to the byte (%s)" % _diff(before, _save()), _save() == before)
	# And replace_parts rare=true with a part in hand: the same, one step.
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3070a":
			_builder.clear_selection()
			_builder.selection[brick.id] = true
			_builder.selection_changed.emit(1)
	_builder.lift_selection()
	await _frames(6)
	said = await _say("replace_parts", {"rare": true})
	print("    held, replace_parts rare=true: %s" % said.get_slice("\n", said.count("\n")))
	_check("control: rare=true with 3070a in hand puts it back first and swaps it, one step (3070a %d, 3070b %d; %d undo steps)"
		% [_count("3070a", 14), _count("3070b", 14), _builder.history_depth() - depth],
		not _builder.is_carrying() and _world.bricks().size() == parts and _count("3070a", 14) == 0
		and said.contains("went back where it was first") and _builder.history_depth() == depth + 1)
	_shell.run("undo")
	await _frames(8)
	_check("control: that rare swap undone, the file to the byte (%s)" % _diff(before, _save()), _save() == before)


func _case_mcp_none() -> void:
	await _open("0 Plain\n0 Name: plain.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
	var before: String = _save()
	var depth: int = _builder.history_depth()
	var said: String = await _say("replace_parts", {"rare": true})
	print("    none rare: %s" % said.replace("\n", " / "))
	_check("mcp: no rare lot: says so, writes nothing, no undo step",
		_save() == before and _builder.history_depth() == depth and said.contains("No lot is rare"))


## The worst frame from the parts list's command to 20 frames on, and from
## the rare row's press until its swaps are shown.
func _case_speed2() -> void:
	for file: String in ["models/orthanc.ldr", "tools/web/gallery_seeds/village_bakery.ldr"]:
		await _open(FileAccess.get_file_as_string("res://" + file))
		await _frames(30)
		for round: int in 3:
			var shown: Control = _main.get("_inventory_made")
			if shown != null and shown.call("is_showing"):
				shown.call("hide_list")
			await _frames(10)
			var worst: float = 0.0
			var last: int = Time.get_ticks_usec()
			_shell.run("parts_list")
			for n: int in 20:
				await process_frame
				var now: int = Time.get_ticks_usec()
				worst = maxf(worst, (now - last) / 1000.0)
				last = now
			print("    %s round %d: worst frame after the parts list's command %.1f ms" % [file.get_file(),
				round, worst])
		if not _base():
			var list: Control = _main.get("_inventory")
			# A fresh swapper, as the first press in a session.
			list.set("_swapper", Later.script(&"RareSwap").new(_library))
			list.call("hide_list")
			_shell.run("parts_list")
			await _frames(10)
			await _filled()
			var row: Button = list.call("controls_by_name").get("parts_rare")
			var s0: int = Time.get_ticks_usec()
			row.pressed.emit()
			var worst: float = (Time.get_ticks_usec() - s0) / 1000.0
			var last: int = Time.get_ticks_usec()
			var frames: int = 0
			while bool(list.get("_swapping")) and frames < 2000:
				await process_frame
				var now: int = Time.get_ticks_usec()
				worst = maxf(worst, (now - last) / 1000.0)
				last = now
				frames += 1
			print("    %s: the rare row pressed, swaps shown after %d frames, worst %.1f ms" % [file.get_file(),
				frames, worst])
			# F6: the moulds' index is the library's, and the offers are cut
			# into frames, so the first press costs no frame of its own.
			_check("speed2 %s: the first rare row press's worst frame under 50 ms (%.1f ms)"
				% [file.get_file(), worst], worst < 50.0)
			list.call("_show_rows")
			list.call("hide_list")


## What the rule offers a transparent, a chrome and a pearl lot.
func _case_trans() -> void:
	var swapper: RefCounted = Later.script(&"RareSwap").new(_library)
	var finder: FindReplace = FindReplace.new(_main)
	for key: Array in [["3710", 47], ["3898", 43], ["30294", 38], ["3816c", 64], ["3933", 383],
			["30374", 334], ["3039", 80], ["32054", 315], ["49668", 379]]:
		var lot := RareSwap.Lot.new()
		lot.part = key[0]
		lot.colour = key[1]
		lot.key = "%s/%d" % key
		lot.sets = _library.sets_in_colour(key[0], key[1])
		lot.name = key[0]
		lot.colour_name = _library.color(key[1]).name
		await swapper.call("offer", lot, finder)
		var into: PartLibrary.BrickColor = _library.color(lot.into_colour) if lot.into_colour >= 0 else null
		print("    %s (%s, %s, transparent %s): %s; picked %s; into transparent %s, finish %s" % [lot.key,
			lot.colour_name, _library.color(key[1]).finish, _library.color(key[1]).is_transparent(),
			swapper.call("lot_words", lot), lot.picked, into.is_transparent() if into != null else "-",
			into.finish if into != null else "-"])


## Every rare colour of every part the colours files have, offered a colour
## by the rule's own steps (RareSwap._colour_choices, _share_colours,
## _crossing, keeps_look), as a model's lone lot of it is: none picked across
## transparency or finish or over CLOSE_DE (rsreview F2). Equal parts are
## left out here: they keep the colour. RSR_OUT/catalogue.tsv has each.
func _case_catalogue() -> void:
	if _base():
		return
	var swapper: RareSwap = Later.script(&"RareSwap").new(_library)
	var rows := PackedStringArray(["part\tcolour\tsets\tinto_colour\tinto_sets\tdelta_e\tsame_trans\tsame_family\tpicked"])
	var lots: int = 0
	var offered: int = 0
	var picked: int = 0
	var crossings: int = 0
	var bad := PackedStringArray()
	var t0: int = Time.get_ticks_msec()
	for id: String in _library.parts:
		var info: PartLibrary.PartInfo = _library.parts[id]
		if info.colors.is_empty() or info.is_redirect() or info.custom or not swapper._buyable(id):
			continue
		for code: int in info.colors:
			var was: PartLibrary.BrickColor = _library.color(code)
			if was == null or not was.is_plastic():
				continue
			var sets: int = _library.sets_in_colour(id, code)
			if sets < 0 or sets > RareSwap.RARE_IN:
				continue
			lots += 1
			var lot := RareSwap.Lot.new()
			lot.part = id
			lot.colour = code
			lot.key = "%s/%d" % [id, code]
			lot.count = 1
			lot.choices = swapper._colour_choices(id, code)
			swapper._share_colours([lot])
			if not lot.offered():
				RareSwap._take(lot, RareSwap._crossing(lot))
			lot.picked = swapper.keeps_look(lot)
			if not lot.offered():
				continue
			offered += 1
			var now: PartLibrary.BrickColor = _library.color(lot.into_colour)
			var same_trans: bool = now.is_transparent() == was.is_transparent() \
				and (not was.is_transparent() or (was.alpha < 200) == (now.alpha < 200))
			var same_family: bool = _crossed(was, now).is_empty()
			if not same_trans or not same_family:
				crossings += 1
			if lot.picked:
				picked += 1
				if not same_trans or not same_family or lot.delta_e > RareSwap.CLOSE_DE:
					bad.append("%s -> %s" % [lot.key, now.name])
			rows.append("%s\t%d\t%d\t%d\t%d\t%.2f\t%s\t%s\t%s" % [id, code, sets, lot.into_colour,
				lot.into_sets, lot.delta_e, same_trans, same_family, lot.picked])
	print("    catalogue: %d rare part colours, %d offered a colour, %d of them across transparency or finish (none picked), %d picked as close, in %d ms"
		% [lots, offered, crossings, picked, Time.get_ticks_msec() - t0])
	_check("catalogue: no swap picked across transparency or finish or over ΔE %.0f (%d of %d picked)%s"
		% [RareSwap.CLOSE_DE, picked, offered, "" if bad.is_empty() else ": " + ", ".join(bad.slice(0, 10))],
		bad.is_empty() and lots > 1000 and offered > 0)
	var out: String = OS.get_environment("RSR_OUT")
	if not out.is_empty():
		var f := FileAccess.open(out.path_join("catalogue.tsv"), FileAccess.WRITE)
		f.store_string("\n".join(rows) + "\n")
		f.close()


## Where the parts list's open spends its time on Orthanc: the whole
## show_for, and rareswap's parts of it, each timed alone.
func _case_attrib() -> void:
	await _open(FileAccess.get_file_as_string("res://models/orthanc.ldr"))
	_shell.run("parts_list")
	await _frames(20)
	await _filled()
	var list: Control = _main.get("_inventory")
	for round: int in 3:
		var t0: int = Time.get_ticks_usec()
		list.call("show_for", _world, _library, _store.scenery, "Orthanc")
		var t1: int = Time.get_ticks_usec()
		list.call("_take_rare")
		var t2: int = Time.get_ticks_usec()
		list.call("_tag_rare")
		var t3: int = Time.get_ticks_usec()
		var t4: int = Time.get_ticks_usec()
		# The moulds' index, made once with the library's (rsfix F6): what a
		# RareSwap of its own made on the first rare row pressed.
		if not _base():
			_library.call("_index_moulds")
		var t5: int = Time.get_ticks_usec()
		var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
		var t6: int = Time.get_ticks_usec()
		print("    orthanc round %d: show_for %.1f ms; _take_rare %.1f ms; _tag_rare %.1f ms; the library's moulds index %.1f ms; Inventory.of %.1f ms" % [
			round, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t5 - t4) / 1000.0, (t6 - t5) / 1000.0])
		await _frames(4)


## What a swap from [param was] to [param now] crosses, worked out here from
## the colours themselves (as ownswap_probe's crossed): "" for nothing. Its
## finish exactly (osreview H1: milky had been solid's, metallic pearl's),
## see-through and clear against clouded, and never into conductive plastic
## or an ink.
static func _crossed(was: PartLibrary.BrickColor, now: PartLibrary.BrickColor) -> String:
	if not now.is_plastic() or now.name.contains("Conductive") or now.group == "fluorescent paint":
		return "non-plastic"
	if was.is_transparent() != now.is_transparent() \
			or was.is_transparent() and (was.alpha < 200) != (now.alpha < 200):
		return "see-through"
	if was.drawn_as != now.drawn_as:
		return "finish"
	return ""
