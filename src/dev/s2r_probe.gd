## s2review: an independent attack on smalls2 476dccca9 (a copy of a sub-model
## that keeps lines of its own is built in its own steps in a host nobody gave
## steps). Run the same in pre261 and smalls2 and diff --out folders: each case
## dumps the save, the plan the timeline shows (one line a step: section, its
## step, parts, callout), the playback order, and the parts put in the air.
##
##   godot --headless --path . --script src/dev/s2r_probe.gd -- --s2rout=DIR [case,case]
##
## With no --s2rout the dumps go to the user data folder (the suite runs it so).
##
## In the suite since inlines (2026-11-14), which keeps in_place's order and
## writes a copy's own lines after its IN line. Changed from s2review's copy
## (bench/results/s2review-2026-11-15/s2r_probe.gd) only where it judged
## nothing: a redo after a save that reopened the file redid nothing (the
## reopen clears the history), so each case's edit is undone and redone
## before any reopen; a copy taken apart gives the model its 20 motion lines
## and they play (was -1, no count); the Save button's file is compared with
## save_as's under one name; the castle's steps, parts in the air and view are
## judged; the cut observatory plays in drive_steps too; the comment case's
## note is kept and what is not kept is said.
extends SceneTree

const OBS := "res://tests/fixtures/mcpwalk3/small-observatory.ldr"

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

## A small plain host of the app's own, no sub-models, stepless.
const FLATHOST := """0 Flat Host
0 Name: flathost.ldr
0 Author: Brickworks
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
"""

const VIEW := "0 !BRICKWORKS VIEW {\"distance\":300,\"focus\":[0,0,0],\"name\":\"obs view\",\"pitch\":-20,\"yaw\":10}"
const LIGHT := "0 !BRICKWORKS LIGHT {\"aim\":[0,1,0],\"at\":[0,-50,0],\"colour\":\"#00ff00\",\"kind\":\"point\",\"shadows\":true,\"size\":4,\"strength\":1}"

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _library: PartLibrary
var _store: ModelStore
var _bar: Node
var _shell: Node
var _socket: Variant
var _rpc_id: int = 0
var _only: PackedStringArray = PackedStringArray()
var _out: String = ""
var _back: String = ""
var _failures: int = 0
## What open_model said of the last model it put into another.
var _held_said: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--s2rout="):
			_out = arg.substr(9)
		elif arg.begins_with("--back="):
			_back = arg.substr(7)
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
	CustomParts.dir = OS.get_user_data_dir().path_join("s2r_parts/")
	CustomParts.keeps = false
	if _out.is_empty():
		_out = OS.get_user_data_dir().path_join("s2r_out")
	DirAccess.make_dir_recursive_absolute(_out)
	var obs: String = _file(OBS)
	var plain: String = _without_motions(obs)
	for pair: Array in [["Clash Host", CLASHHOST], ["Own Steps", OWNSTEPS], ["Flat Host", FLATHOST],
			["Observatory", obs], ["Obs Plain", plain],
			["Obs View", _after_first_author(plain, VIEW)],
			["Obs Light", _after_first_author(plain, LIGHT)],
			["Obs Credit", plain.replace("0 Author: Brickworks", "0 Author: A. Builder")],
			["Obs Comment", _with_comment(plain)],
			["Wrapper", _wrapper(obs)], ["Deep", _deep(obs)],
			["Castle", _file("res://models/castle.ldr")],
			["Castle View", _castle_view(_file("res://models/castle.ldr"))]]:
		_keep(pair[0], pair[1])
	for case: String in ["plain", "motions", "view", "light", "credit", "comment", "nested",
			"wrapper_alone", "two", "mixed", "flat", "paced", "e_delete_part", "e_move_part",
			"e_recolour_part", "e_delete_copy", "e_ungroup", "e_second_copy", "drive", "back",
			"deep", "castle", "castle_view", "drive_steps"]:
		if not _only.is_empty() and not _only.has(case):
			continue
		await call("_case_" + case)
	print("")
	print("s2r: %s" % ("all held" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- texts --------------------------------------------------------------------


static func _without_motions(text: String) -> String:
	var out: PackedStringArray = []
	for line: String in text.split("\n"):
		if not line.begins_with("0 !BRICKWORKS MOTION"):
			out.append(line)
	return "\n".join(out)


static func _after_first_author(text: String, line: String) -> String:
	var at: int = text.find("0 Author: Brickworks\n")
	return text.substr(0, at) + "0 Author: Brickworks\n" + line + "\n" + text.substr(at + 21)


## A comment, a BFC line, and the main section's first STEP a ROTSTEP.
static func _with_comment(text: String) -> String:
	var t: String = _after_first_author(text, "0 // the builder's own note\n0 BFC CERTIFY CCW")
	var at: int = t.find("\n0 STEP\n")
	return t.substr(0, at) + "\n0 ROTSTEP 30 45 0 ABS\n" + t.substr(at + 8)


## A model of the app's own holding a 3001 and the observatory, motions and
## all, as a sub-model of its own (obs.ldr).
static func _wrapper(obs: String) -> String:
	var inner: String = obs.replace("0 FILE model.ldr", "0 FILE obs.ldr").replace("0 Name: model.ldr", "0 Name: obs.ldr")
	return "0 FILE wrapper.ldr\n0 Wrapper\n0 Name: wrapper.ldr\n0 Author: Brickworks\n" \
		+ "1 4 0 -24 600 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 obs.ldr\n0 STEP\n0 NOFILE\n" \
		+ inner


## A model of the app's own: a 3001 and base.ldr, which holds a 3001 and
## the observatory (obs.ldr, motions and all): a copy with lines inside one
## without.
static func _deep(obs: String) -> String:
	var inner: String = obs.replace("0 FILE model.ldr", "0 FILE obs.ldr").replace("0 Name: model.ldr", "0 Name: obs.ldr")
	return "0 FILE deep.ldr\n0 Deep\n0 Name: deep.ldr\n0 Author: Brickworks\n" \
		+ "1 4 0 -24 600 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 base.ldr\n0 STEP\n0 NOFILE\n" \
		+ "0 FILE base.ldr\n0 Base\n0 Name: base.ldr\n0 Author: Brickworks\n" \
		+ "1 1 0 -24 700 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 obs.ldr\n0 STEP\n0 NOFILE\n" \
		+ inner


## The castle (models/castle.ldr) with a view of its own in the north-east
## tower: the tower a sub-model that keeps a line of its own.
static func _castle_view(text: String) -> String:
	var at: int = text.find("0 FILE north_east_tower.ldr")
	var head: int = text.find("0 Author: Brickworks\n", at)
	return text.substr(0, head) + "0 Author: Brickworks\n" + VIEW + "\n" + text.substr(head + 21)


# -- what the person sees -----------------------------------------------------


## The plan the Steps timeline, the booklet and Build show, dumped: a line a
## step, then the playback order, the parts in the air and hidden.
func _seen(case: String, label: String) -> Dictionary:
	var skip: Dictionary = _store.scenery
	var read: Dictionary = {}
	var worked: Array[Instructions.Step] = Instructions.worked_out(_world, _library, skip, {}, read)
	var kept: Array[Instructions.Step] = Instructions.plan(_world, _library, skip)
	var numbers: Dictionary = Instructions.kept_numbers(_world, _library, skip, worked, read)
	var in_parent: int = 0
	var own: Array = []
	for path: String in numbers["units"]:
		if int(numbers["units"][path]) == AuthorSteps.IN_PARENT:
			in_parent += 1
		else:
			own.append("%s@%d" % [path, int(numbers["units"][path])])
	own.sort()
	var lines: PackedStringArray = []
	var order: PackedStringArray = []
	var callouts: int = 0
	for step: Instructions.Step in kept:
		if step.in_callout():
			callouts += 1
		var parts: Dictionary = {}
		for brick_id: int in step.brick_ids:
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			if brick == null:
				continue
			parts[brick.part_id] = int(parts.get(brick.part_id, 0)) + 1
			order.append("%s@%s" % [brick.part_id, _round(brick.transform.origin)])
		var keys: Array = parts.keys()
		keys.sort()
		lines.append("%d\t%s\t%d\t%s\t%d\t%s" % [step.number, step.authored_in, step.authored_step,
			"callout" if step.in_callout() else "", step.brick_ids.size(),
			" ".join(keys.map(func(k: String) -> String: return "%sx%d" % [k, int(parts[k])]))])
	var faults: Array = [-1, -1]
	var was: Array = [-1, -1]
	if not read.is_empty():
		faults = Later.script(&"HeldSteps").faults_of(kept, read, _library)
		was = read["faults"]
	var said: String = "%s %s: %d steps (%d in callouts), copies in parent's steps %d, in own steps %s; in the air %d hidden %d (the order worked out: %d, %d)" % [
		case, label, kept.size(), callouts, in_parent, own, faults[0], faults[1], was[0], was[1]]
	print("    " + said)
	_write(_out.path_join("%s.%s.plan.txt" % [case, label]), said + "\n" + "\n".join(lines) + "\n\n" + "\n".join(order) + "\n")
	return {"steps": kept.size(), "air": faults[0], "own": own}


static func _round(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x), roundi(v.y), roundi(v.z)]


## The save's lines that are not parts, counted, and its steps.
func _said(case: String, text: String) -> void:
	var counts: Dictionary = {}
	for word: String in ["0 STEP", "0 ROTSTEP", "!BRICKWORKS MOTION", "!BRICKWORKS VIEW", "!BRICKWORKS LIGHT",
			"0 Author: A. Builder", "0 // the builder's own note", "0 BFC CERTIFY", "!BRICKWORKS IN ", "0 FILE "]:
		counts[word.strip_edges()] = text.count(word)
	print("    %s save: %s; sections %s; empty steps %d" % [case, JSON.stringify(counts), _sections(text), _empty_steps(text)])


## Steps with no part and no reference in them: a 0 STEP right after the
## head or after another.
static func _empty_steps(text: String) -> int:
	var count: int = 0
	var since: int = 0
	var in_section: bool = false
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 FILE "):
			in_section = true
			since = 0
			continue
		if line == "0 STEP" or line.begins_with("0 ROTSTEP"):
			if since == 0 and in_section:
				count += 1
			since = 0
		elif line.begins_with("1 "):
			since += 1
	return count


static func _sections(text: String) -> Array:
	var out: Array = []
	for line: String in text.split("\n"):
		if line.begins_with("0 FILE "):
			out.append(line.substr(7).strip_edges())
	return out


# -- cases --------------------------------------------------------------------


func _into(host: String, brought: Array, case: String) -> Array:
	print("\n%s: %s into %s" % [case, brought, host])
	await _open_saved(host)
	for name: String in brought:
		_held_said = await _say("open_model", {"into": true, "name": name})
		print("    MCP: " + _held_said.left(140))
	print("    section_lines: %s" % [_world.section_lines.keys()])
	await _seen(case, "before")
	var texts: Array = await _save_twice("s2r " + case)
	_said(case, texts[0])
	await _seen(case, "reopened")
	_write(_out.path_join(case + ".ldr"), texts[0])
	_same_again(case, texts)
	return texts


func _case_plain() -> void:
	await _into("Clash Host", ["Obs Plain"], "plain")


func _case_motions() -> void:
	var texts: Array = await _into("Clash Host", ["Observatory"], "motions")
	_check("motions: 20 motion lines kept (%d)" % (texts[0] as String).count("!BRICKWORKS MOTION"),
		(texts[0] as String).count("!BRICKWORKS MOTION") == 20)


func _case_view() -> void:
	var texts: Array = await _into("Clash Host", ["Obs View"], "view")
	_check("view: its view kept (%d)" % (texts[0] as String).count("!BRICKWORKS VIEW"),
		(texts[0] as String).count("!BRICKWORKS VIEW") == 1)


func _case_light() -> void:
	var texts: Array = await _into("Clash Host", ["Obs Light"], "light")
	_check("light: its light kept (%d)" % (texts[0] as String).count("!BRICKWORKS LIGHT"),
		(texts[0] as String).count("!BRICKWORKS LIGHT") == 1)


func _case_credit() -> void:
	var texts: Array = await _into("Clash Host", ["Obs Credit"], "credit")
	_check("credit: whose it is kept (%d)" % (texts[0] as String).count("0 Author: A. Builder"),
		(texts[0] as String).count("0 Author: A. Builder") >= 1)


func _case_comment() -> void:
	var texts: Array = await _into("Clash Host", ["Obs Comment"], "comment")
	_check("comment: its note kept (%d)" % (texts[0] as String).count("0 // the builder's own note"),
		(texts[0] as String).count("0 // the builder's own note") == 1)
	_check("comment: the brought words say its BFC line and ROTSTEP are not kept (%s)" % _held_said,
		_held_said.contains("not kept: its BFC line") and _held_said.contains("its ROTSTEP"))


func _case_nested() -> void:
	var texts: Array = await _into("Clash Host", ["Wrapper"], "nested")
	_check("nested: 20 motion lines kept (%d)" % (texts[0] as String).count("!BRICKWORKS MOTION"),
		(texts[0] as String).count("!BRICKWORKS MOTION") == 20)


func _case_wrapper_alone() -> void:
	print("\nwrapper_alone: Wrapper (the observatory a sub-model of the app's own) opened, saved")
	await _open_saved("Wrapper")
	print("    section_lines: %s" % [_world.section_lines.keys()])
	await _seen("wrapper_alone", "before")
	var texts: Array = await _save_twice("s2r wrapper alone")
	_said("wrapper_alone", texts[0])
	_write(_out.path_join("wrapper_alone.ldr"), texts[0])
	_check("wrapper_alone: 20 motion lines kept (%d)" % (texts[0] as String).count("!BRICKWORKS MOTION"),
		(texts[0] as String).count("!BRICKWORKS MOTION") == 20)
	_same_again("wrapper_alone", texts)


func _case_two() -> void:
	var texts: Array = await _into("Clash Host", ["Observatory", "Obs View"], "two")
	_check("two: 20 motion lines and the view kept (%d, %d)" % [(texts[0] as String).count("!BRICKWORKS MOTION"),
		(texts[0] as String).count("!BRICKWORKS VIEW")], (texts[0] as String).count("!BRICKWORKS MOTION") == 20
		and (texts[0] as String).count("!BRICKWORKS VIEW") == 1)


func _case_mixed() -> void:
	await _into("Own Steps", ["Observatory"], "mixed")


func _case_flat() -> void:
	var texts: Array = await _into("Flat Host", ["Observatory"], "flat")
	_check("flat: 20 motion lines kept (%d)" % (texts[0] as String).count("!BRICKWORKS MOTION"),
		(texts[0] as String).count("!BRICKWORKS MOTION") == 20)


## Twice into Clash Host: 387 parts, past PACED_FROM, so the Save button
## writes it a slice at a time (save_as_paced, numbers_of on the kept plan).
func _case_paced() -> void:
	print("\npaced: the observatory twice into Clash Host, saved as the Save button saves a big model")
	await _open_saved("Clash Host")
	for _n: int in 2:
		print("    MCP: " + (await _say("open_model", {"into": true, "name": "Observatory"})).left(140))
	print("    paces: %s (%d parts)" % [_store.paces(), _model().size()])
	await _seen("paced", "before")
	var sync: Array = await _save_twice("s2r paced sync")
	_said("paced sync", sync[0])
	_write(_out.path_join("paced.sync.ldr"), sync[0])
	_same_again("paced sync", sync)
	await _open_saved("Clash Host")
	for _n: int in 2:
		await _say("open_model", {"into": true, "name": "Observatory"})
	var first: String = await _save_paced("s2r paced")
	await _open_path(ModelStore.saved_path("s2r paced"))
	await _seen("paced", "reopened")
	var second: String = await _save_paced("s2r paced")
	_said("paced", first)
	_write(_out.path_join("paced.ldr"), first)
	_check("paced: 40 motion lines kept (%d, again %d)" % [first.count("!BRICKWORKS MOTION"),
		second.count("!BRICKWORKS MOTION")], first.count("!BRICKWORKS MOTION") == 40
		and second.count("!BRICKWORKS MOTION") == 40)
	_same_again("paced", [first, second])
	# Saved under two names, the model's title line is each one's.
	var named: String = (sync[0] as String).replace("0 s2r paced sync\n", "0 s2r paced\n")
	_check("paced: the Save button's file is the one save_as writes, but for its name (%d / %d bytes)%s"
		% [first.length(), named.length(), _first_apart(named, first)], first == named)


func _save_paced(name: String) -> String:
	await _frames(4)
	var job: Working.Job = Working.begin("Saving", 0, true)
	await job.shown()
	var ok: bool = await _store.save_as_paced(name, job)
	job.end()
	_check("saved paced as %s" % name, ok)
	return _file(ModelStore.saved_path(name))


# -- edits after --------------------------------------------------------------


## The observatory into Clash Host, saved and reopened: the copy's parts.
func _reopened_host(case: String) -> Array:
	print("\n%s: the observatory into Clash Host, saved, reopened, then edited" % case)
	await _open_saved("Clash Host")
	await _say("open_model", {"into": true, "name": "Observatory"})
	_check("%s: saved" % case, _store.save_as("s2r " + case + " base"))
	await _open_path(ModelStore.saved_path("s2r " + case + " base"))
	return _under(_path_to("Observatory", 1))


func _edited_save(case: String, motions: int) -> void:
	await _seen(case, "edited")
	var texts: Array = await _save_twice("s2r " + case)
	_said(case, texts[0])
	_write(_out.path_join(case + ".ldr"), texts[0])
	_check("%s: %d motion lines (%d)" % [case, motions, (texts[0] as String).count("!BRICKWORKS MOTION")],
		(texts[0] as String).count("!BRICKWORKS MOTION") == motions)
	_check("%s: no empty step (%d)" % [case, _empty_steps(texts[0])], _empty_steps(texts[0]) == 0)
	_same_again(case, texts)


## Edit, save; undo, save; redo, save. The undone save once, without the
## reopen that would clear the history the redo needs; the redone saved,
## reopened and saved again, and the undone one reopened and saved again.
func _edit_undo_redo(case: String, edit: Callable, motions_after: int) -> void:
	var ids: Array = await _reopened_host(case)
	print("    the copy's parts: %d" % ids.size())
	await edit.call(ids)
	await _edited_save(case, motions_after)
	await _open_path(ModelStore.saved_path("s2r " + case + " base"))
	ids = _under(_path_to("Observatory", 1))
	await edit.call(ids)
	await _undo()
	await _seen(case + "_undone", "edited")
	await _frames(4)
	_check("saved as s2r %s_undone" % case, _store.save_as("s2r " + case + "_undone"))
	var undone: String = _file(ModelStore.saved_path("s2r " + case + "_undone"))
	_said(case + "_undone", undone)
	_write(_out.path_join(case + "_undone.ldr"), undone)
	_check("%s_undone: 20 motion lines (%d)" % [case, undone.count("!BRICKWORKS MOTION")],
		undone.count("!BRICKWORKS MOTION") == 20)
	await _redo()
	await _edited_save(case + "_redone", motions_after)
	await _open_path(ModelStore.saved_path("s2r " + case + "_undone"))
	_check("saved again as s2r %s_undone" % case, _store.save_as("s2r " + case + "_undone"))
	_same_again(case + "_undone", [undone, _file(ModelStore.saved_path("s2r " + case + "_undone"))])


func _case_e_delete_part() -> void:
	await _edit_undo_redo("e_delete_part", func(ids: Array) -> void:
		_select([_lowest(ids)])
		_shell.run("delete")
		await _frames(4)
		_edited(), 20)


func _case_e_move_part() -> void:
	await _edit_undo_redo("e_move_part", func(ids: Array) -> void:
		_select([_highest(ids)])
		print("    moved %d" % _builder.move_selection(Vector3i(0, 0, 4)))
		await _frames(4)
		_edited(), 20)


func _case_e_recolour_part() -> void:
	await _edit_undo_redo("e_recolour_part", func(ids: Array) -> void:
		_select([_highest(ids)])
		print("    painted %d" % _builder.paint_selection(1))
		await _frames(4)
		_edited(), 20)


func _case_e_delete_copy() -> void:
	await _edit_undo_redo("e_delete_copy", func(ids: Array) -> void:
		_select(ids)
		_shell.run("delete")
		await _frames(4)
		_edited(), 0)


func _case_e_ungroup() -> void:
	await _edit_undo_redo("e_ungroup", func(ids: Array) -> void:
		print("    ungrouped %d (%s)" % [_shell.assemblies.ungroup(_path_to("Observatory", 1)),
			_shell.assemblies.apart_said])
		await _frames(4)
		_edited(), 20)
	# Taken apart, the model's own: played, each joint's part found.
	await _open_path(ModelStore.saved_path("s2r e_ungroup_redone"))
	var have: Array = _motion_state()
	print("    the host's motions after it was taken apart, reopened: %s" % [have])
	_check("e_ungroup: the host plays the observatory's 4 motions, every joint found (%s)" % [have],
		have == [4, 4, 4])
	_check("e_ungroup: and Play moves its parts", _plays_all())


func _case_e_second_copy() -> void:
	await _edit_undo_redo("e_second_copy", func(_ids: Array) -> void:
		print("    MCP: " + (await _say("open_model", {"into": true, "name": "Observatory"})).left(120)), 40)


# -- the motions drive after reopen -------------------------------------------


## The observatory cut from the host's save (Export as its own file) and
## opened alone: every motion and every joint found, as the observatory
## opened alone has them.
func _case_drive() -> void:
	print("\ndrive: the observatory's motions after the host's save, cut out and opened alone")
	await _open_saved("Observatory")
	var want: Array = _motion_state()
	await _open_saved("Clash Host")
	await _say("open_model", {"into": true, "name": "Observatory"})
	_check("drive: saved", _store.save_as("s2r drive"))
	var text: String = _file(ModelStore.saved_path("s2r drive"))
	await _open_path(ModelStore.saved_path("s2r drive"))
	var hosts: int = _world.motions.list.size() if _world.motions != null else 0
	print("    host plays %d motions" % hosts)
	_check("drive: the host plays none of them, its sub-model's (%d)" % hosts, hosts == 0)
	var whole: SubmodelFile.Whole = SubmodelFile.read(text, _library.parts)
	var path: String = ""
	for one: String in SubmodelFile.paths(whole):
		if Assemblies.definition(Assemblies.leaf(one)) == "Observatory":
			path = one
	var made: SubmodelFile.Made = SubmodelFile.cut(whole, path) if not path.is_empty() else null
	_check("drive: the observatory cut from the save (%s)" % path, made != null)
	if made == null:
		return
	_keep("s2r drive cut", made.text)
	await _open_saved("s2r drive cut")
	var have: Array = _motion_state()
	print("    alone: %s\n    cut:   %s" % [want, have])
	_check("drive: the cut observatory's motions and joints as the observatory's own", want == have and int(want[0]) == 4)
	_check("drive: every motion of the cut observatory plays and moves parts", _plays_all())


## Each of the model's motions played: its frames move parts (a sequence
## plays others). Said, with how many parts each moved.
func _plays_all() -> bool:
	# The window's own player, Grab and all: one made bare had no Grab, and
	# every play stopped at its first joint (s2review's drive).
	var player: RefCounted = _main.get("_motions")
	var moved: Array = []
	var all_move: bool = true
	for motion: Variant in _world.motions.list:
		var played: Variant = player.play(motion, false, 12, false)
		var parts: Dictionary = {}
		for frame: Variant in played.frames:
			for id: Variant in (frame as Dictionary):
				parts[id] = true
		moved.append([(motion as Motions.Motion).name, parts.size(), Array(played.refused)])
		if parts.is_empty() and not (motion as Motions.Motion).is_sequence():
			all_move = false
	print("    played: %s" % [moved])
	return all_move and not moved.is_empty()


func _motion_state() -> Array:
	var motions: Motions = _world.motions
	if motions == null:
		return [0, 0, 0]
	var found: int = 0
	for joint: Variant in motions.joints:
		if (joint as Motions.Joint).lead != 0:
			found += 1
	return [motions.list.size(), motions.joints.size(), found]


func _places() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


func _moved_count(before: Dictionary) -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if before.has(brick.id) and not (before[brick.id] as Transform3D).is_equal_approx(brick.transform):
			count += 1
	return count


func _case_deep() -> void:
	print("\ndeep: Deep (the observatory inside base, inside the model) opened, saved")
	await _open_saved("Deep")
	print("    section_lines: %s" % [_world.section_lines.keys()])
	await _seen("deep", "before")
	var texts: Array = await _save_twice("s2r deep")
	_said("deep", texts[0])
	await _seen("deep", "reopened")
	_write(_out.path_join("deep.ldr"), texts[0])
	_check("deep: 20 motion lines kept (%d)" % (texts[0] as String).count("!BRICKWORKS MOTION"),
		(texts[0] as String).count("!BRICKWORKS MOTION") == 20)
	_same_again("deep", texts)


func _case_castle() -> void:
	await _castle("castle", "Castle")


func _case_castle_view() -> void:
	await _castle("castle_view", "Castle View")


func _castle(case: String, name: String) -> void:
	print("\n%s: %s opened, saved" % [case, name])
	await _open_saved(name)
	print("    section_lines: %s; %d parts" % [_world.section_lines.keys(), _model().size()])
	var seen: Dictionary = await _seen(case, "before")
	_check("%s: 400 steps, none in the air (%d, %d)" % [case, int(seen["steps"]), int(seen["air"])],
		int(seen["steps"]) == 400 and int(seen["air"]) == 0)
	_check("%s: saved" % case, _store.save_as("s2r " + case))
	var text: String = _file(ModelStore.saved_path("s2r " + case))
	_said(case, text)
	_write(_out.path_join(case + ".ldr"), text)
	var views: int = 1 if case == "castle_view" else 0
	_check("%s: %d view kept (%d)" % [case, views, text.count("!BRICKWORKS VIEW")],
		text.count("!BRICKWORKS VIEW") == views)
	await _open_path(ModelStore.saved_path("s2r " + case))
	seen = await _seen(case, "reopened")
	_check("%s: reopened, 400 steps, none in the air (%d, %d)" % [case, int(seen["steps"]), int(seen["air"])],
		int(seen["steps"]) == 400 and int(seen["air"]) == 0)
	_check("%s: saved again" % case, _store.save_as("s2r " + case))
	_same_again(case, [text, _file(ModelStore.saved_path("s2r " + case))])


## The drive check in a host with steps (Own Steps), the path live has.
func _case_drive_steps() -> void:
	print("\ndrive_steps: the observatory's motions after a host with steps is saved, cut out and opened alone")
	await _open_saved("Observatory")
	var want: Array = _motion_state()
	await _open_saved("Own Steps")
	await _say("open_model", {"into": true, "name": "Observatory"})
	_check("drive_steps: saved", _store.save_as("s2r drive steps"))
	var text: String = _file(ModelStore.saved_path("s2r drive steps"))
	var whole: SubmodelFile.Whole = SubmodelFile.read(text, _library.parts)
	var path: String = ""
	for one: String in SubmodelFile.paths(whole):
		if Assemblies.definition(Assemblies.leaf(one)) == "Observatory":
			path = one
	var made: SubmodelFile.Made = SubmodelFile.cut(whole, path) if not path.is_empty() else null
	_check("drive_steps: the observatory cut from the save (%s)" % path, made != null)
	if made == null:
		return
	_keep("s2r drive steps cut", made.text)
	await _open_saved("s2r drive steps cut")
	var have: Array = _motion_state()
	print("    alone: %s\n    cut:   %s" % [want, have])
	_check("drive_steps: the cut observatory's motions and joints as the observatory's own", want == have and int(want[0]) == 4)
	_check("drive_steps: every motion of the cut observatory plays and moves parts", _plays_all())


## A file another build saved (--back=PATH), opened here and saved twice.
func _case_back() -> void:
	if _back.is_empty():
		print("\nback: no --back=PATH; not run")
		return
	print("\nback: %s opened and saved here" % _back)
	var given: String = _file(_back)
	_keep("s2r back given", given)
	await _open_saved("s2r back given")
	await _seen("back", "opened")
	var texts: Array = await _save_twice("s2r back")
	_said("back given", given)
	_said("back", texts[0])
	_write(_out.path_join("back.ldr"), texts[0])
	_check("back: motion lines %d of %d given" % [(texts[0] as String).count("!BRICKWORKS MOTION"),
		given.count("!BRICKWORKS MOTION")], (texts[0] as String).count("!BRICKWORKS MOTION") == given.count("!BRICKWORKS MOTION"))
	_same_again("back", texts)


# -- helpers ------------------------------------------------------------------


func _same_again(case: String, texts: Array) -> void:
	var a: String = texts[0]
	var b: String = texts[1]
	_check("%s: saved, reopened and saved again, byte-identical (%d / %d bytes)%s" % [case, a.length(),
		b.length(), _first_apart(a, b)], a == b)
	if a != b:
		_write(_out.path_join(case + ".again.ldr"), b)


static func _first_apart(a: String, b: String) -> String:
	if a == b:
		return ""
	var la: PackedStringArray = a.split("\n")
	var lb: PackedStringArray = b.split("\n")
	for n: int in maxi(la.size(), lb.size()):
		var x: String = la[n] if n < la.size() else "<none>"
		var y: String = lb[n] if n < lb.size() else "<none>"
		if x != y:
			return " first apart at line %d: [%s] / [%s]" % [n + 1, x.left(90), y.left(90)]
	return ""


func _lowest(ids: Array) -> int:
	var best: int = ids[0]
	for id: Variant in ids:
		if _world.get_brick(int(id)).transform.origin.y < _world.get_brick(best).transform.origin.y:
			best = int(id)
	return best


func _highest(ids: Array) -> int:
	var best: int = ids[0]
	for id: Variant in ids:
		if _world.get_brick(int(id)).transform.origin.y > _world.get_brick(best).transform.origin.y:
			best = int(id)
	return best


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _under(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _model():
		var at: String = Assemblies.path_of(brick)
		if at == path or at.begins_with(path + "/"):
			out.append(brick.id)
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


func _save_twice(name: String) -> Array:
	await _frames(4)
	_check("saved as %s" % name, _store.save_as(name))
	var first: String = _file(ModelStore.saved_path(name))
	await _open_path(ModelStore.saved_path(name))
	_check("saved again as %s" % name, _store.save_as(name))
	var second: String = _file(ModelStore.saved_path(name))
	return [first, second]


func _select(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: Variant in ids:
		_builder.selection[int(brick_id)] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	await _frames(6)
	return text.replace("\n", " | ")


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
