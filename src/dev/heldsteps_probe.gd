## A part the app holds but does not show keeps its step and its looks
## (APP_UX7 #3, heldsteps).
##
##   godot --headless --path . --script src/dev/heldsteps_probe.gd
##
## A model can hold parts it does not draw: one the catalogue has not got
## (a newer build's, a made part whose file is gone: ModelStore._absent, or
## someone else's file's SourceFile.not_shown), and one still on its way
## (ModelStore.awaited, as the web fetches a part after the model opens).
## Each is written back in its step. Up to 2026-11-11 a step edit numbered
## again only the parts on the baseplate: such a part kept the number it was
## read with, so after a step was merged, moved or taken out it was written
## in another step, and its step's zoom and name went with nothing
## (pkreview3, r5_new/as_next_3020_1_saved.ldr).
##
## The model: 3020 (A) in step 1; 3062b (H, the held part) alone in step 2,
## at ZOOM 1.5 and named "The held step"; 3003 (B) in step 3 with a TEXT;
## 3001 (C) in step 4 on a new page. Its twin is the same file without H and
## its step: what a person sees of the model, and edits. H is taken away
## (the catalogue's entry for it gone, as when its file is) or held back (its
## geometry not on disk, and asked for from a port nothing listens on, so it
## stays on its way), and then:
##   1. the plan's bar: opened, saved and opened: H on its own step with its
##      ZOOM and STEP_NAME lines byte for byte; with the part back, the file
##      saved from it opens and saves byte for byte as the model did;
##   2. each step edit a person makes on the steps they see (merge step 1,
##      step 1 later, delete step 2, 3020 to the next step, 3003 to the
##      previous, delete step 3, 3003 taken off), then saved: the steps but
##      H's are the twin's after the same edit, line for line; H alone in a
##      step of its own, where the edit leaves it, with its two lines; saved
##      again from the file, the same bytes; with the part back, opened and
##      saved, the same steps, H drawn in its own;
##   3. the same with H sharing step 2 with 3024 (D): H goes where D's step
##      goes, and stays in it when D alone moves on;
##   4. someone else's file, the same edits: H in its own step, written back;
##   5. H on its way, the app's own file and someone else's: 3020 to the
##      next step, which takes it past H's, saved: H alone in step 1; H
##      arrives and is put down in it; the edit undone and redone, H's step
##      each time with it;
##   6. hscheck's findings (hsfix), each the app's own file and someone
##      else's: a sub-model dragged in the tree into one whose step 2 is H
##      alone, H still alone there; 3003 moved on from the last step a person
##      sees, H's after it, the steps as they were; in a sub-model placed
##      twice, 3004 moved on in the second copy, both copies alike and H
##      alone in its step in the file's; and someone else's file written
##      whole, H missing or on its way, H alone in its own step.
## Saved files in HELDSTEPS_OUT (an absolute folder), or user://heldsteps/.
extends SceneTree

const MODELS := "user://models/"
const HELD := "3062b"
## Nothing listens here: a part held back is asked for and never comes.
const PORT := 9943
const WATCHDOG := 1500.0
const ZOOM := "0 !BRICKWORKS ZOOM 1.5"
const NAME := "0 !BRICKWORKS STEP_NAME The held step"
## H's step's lines, as _steps lists a step's: in order.
const HELD_LOOKS := [NAME, ZOOM]

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _socket: CommandSocket
var _rpc_id: int = 0
var _failures: int = 0
var _out: String = ""
## H's catalogue entry while it is taken away, and its geometry's name while
## it is held back.
var _away: PartLibrary.PartInfo = null
var _hash: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(WATCHDOG).timeout.connect(func() -> void:
		print("heldsteps_probe: FAILED, not finished in %d s" % int(WATCHDOG))
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	_out = OS.get_environment("HELDSTEPS_OUT")
	if _out.is_empty():
		_out = "user://heldsteps/"
	DirAccess.make_dir_recursive_absolute(_out)
	DirAccess.make_dir_recursive_absolute(MODELS)
	if not _check("%s is in the catalogue, to be taken away" % HELD, _library.parts.has(HELD)):
		quit(1)
		return

	print("\n1. the plan's bar: H taken away, opened, saved, opened; then back")
	for own: bool in [true, false]:
		await _bar(own)

	print("\n2. each step edit, H alone in its step, the app's own file")
	for edit: Array in _edits():
		await _case("own", true, false, "missing", edit)

	print("\n3. H sharing its step with 3024")
	# "with": H goes where 3024's step goes; "alone": 3024 moved on alone, H
	# keeps the step and its lines.
	for edit: Array in [["merge", {"op": "merge", "step": 1}, "with"],
			["next_D", {"op": "next", "bricks": ["3024"]}, "alone"],
			["delete_2", {"op": "delete", "step": 2}, "with"]]:
		await _case("shared", true, true, "missing", edit)

	print("\n4. someone else's file")
	for edit: Array in _edits().filter(func(e: Array) -> bool:
			return str(e[0]) in ["merge", "delete_2", "next_A", "later"]):
		await _case("theirs", false, false, "missing", edit)

	print("\n5. H on its way")
	await _coming(true)
	await _coming(false)

	print("\n6. hscheck's findings (hsfix)")
	for own: bool in [true, false]:
		await _drag_into(own)
		await _next_last(own)
		await _second_copy(own)
	await _theirs_whole("missing")
	await _theirs_whole("coming")

	_world.clear()
	await _frames(4)
	print("\nheldsteps_probe: %s" % ("all passed: a part the app holds but does not show keeps its step and its looks"
		if _failures == 0 else "%d FAILURE(S)" % _failures))
	quit(1 if _failures else 0)


## [name, edit_steps's arguments (bricks by part number) or edit_model's
## removal, the step H's is among the steps saved, from 0].
static func _edits() -> Array:
	return [
		["merge", {"op": "merge", "step": 1}, 1],
		["later", {"op": "later", "step": 1}, 1],
		["delete_2", {"op": "delete", "step": 2}, 1],
		["next_A", {"op": "next", "bricks": ["3020"]}, 0],
		["prev_B", {"op": "prev", "bricks": ["3003"]}, 1],
		["delete_3", {"op": "delete", "step": 3}, 1],
		["takeoff_B", {"remove": "3003"}, 1],
	]


# -- the model ------------------------------------------------------------------------


## The model, the app's own ([param own]) or someone else's, with H alone in
## step 2 or beside 3024 ([param shared]), or without H and its step
## ([param twin]).
static func _model(own: bool, shared: bool, twin: bool) -> String:
	var lines := PackedStringArray(["0 FILE heldsteps.ldr", "0 Held steps", "0 Name: heldsteps.ldr",
		"0 Author: " + ("Brickworks" if own else "Someone Else")])
	if own:
		lines.append("0 !BRICKWORKS AUTHORED_STEPS")
	lines.append_array(["", "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat", "0 STEP"])
	if not twin or shared:
		if not twin:
			lines.append("1 14 30 -24 10 1 0 0 0 1 0 0 0 1 %s.dat" % HELD)
		if shared:
			lines.append("1 2 -30 -8 10 1 0 0 0 1 0 0 0 1 3024.dat")
		lines.append_array([ZOOM, NAME, "0 STEP"])
	lines.append_array(["1 1 120 -16 0 1 0 0 0 1 0 0 0 1 3003.dat",
		"0 !BRICKWORKS TEXT 20 20 60 12 5 Step three", "0 STEP",
		"1 4 120 -40 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 !BRICKWORKS PAGE NEW", "0 NOFILE", ""])
	return "\n".join(lines)


## The model's own section of [param text], step by step: each [its parts,
## "part colour", and its booklet lines, each as written; both sorted, as
## the writer has an order of its own for a step's lines].
static func _steps(text: String) -> Array:
	var out: Array = [[[], []]]
	var files: int = 0
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		var words: PackedStringArray = line.split(" ", false)
		if words.size() >= 2 and words[0] == "0":
			var keyword: String = words[1].to_upper()
			if keyword == "FILE":
				files += 1
				if files > 1:
					break
				continue
			if keyword == "NOFILE":
				break
			if keyword == "STEP" or keyword == "ROTSTEP":
				out.append([[], []])
				continue
			if keyword == "!BRICKWORKS" and words.size() >= 3 and words[2] in BookletLooks.WORDS \
					and not words[2] in ["PAGE_SETUP", "PAGE_TEXT"]:
				(out[out.size() - 1][1] as Array).append(raw.trim_suffix("\r"))
			continue
		if words.size() >= 15 and words[0] == "1":
			(out[out.size() - 1][0] as Array).append("%s %s" % [words[14].get_basename().to_lower(),
				words[1]])
	while out.size() > 1 and (out[out.size() - 1][0] as Array).is_empty() \
			and (out[out.size() - 1][1] as Array).is_empty():
		out.pop_back()
	for step: Array in out:
		(step[0] as Array).sort()
		(step[1] as Array).sort()
	return out


static func _said(steps: Array) -> String:
	var out := PackedStringArray()
	for step: Array in steps:
		var looks := PackedStringArray()
		for line: String in step[1]:
			looks.append(line.trim_prefix("0 !BRICKWORKS "))
		out.append("[%s%s]" % [", ".join(PackedStringArray(step[0])),
			(" | " + ", ".join(looks)) if not looks.is_empty() else ""])
	return " ".join(out)


## [param steps] without H: each step's parts but H, and a step that held H
## alone gone, with its lines.
static func _without_held(steps: Array) -> Array:
	var out: Array = []
	for step: Array in steps:
		var parts: Array = (step[0] as Array).filter(func(p: String) -> bool:
			return not p.begins_with(HELD + " "))
		if parts.is_empty() and not (step[0] as Array).is_empty():
			continue
		out.append([parts, step[1]])
	return out


## The index of the step H is in, or -1.
static func _held_at(steps: Array) -> int:
	for index: int in steps.size():
		for part: String in steps[index][0]:
			if part.begins_with(HELD + " "):
				return index
	return -1


# -- H away and back ------------------------------------------------------------------


## H taken out of the catalogue ("missing", as when its file is gone), or its
## geometry held back so it is on its way ("coming").
func _take_away(how: String) -> void:
	if how == "missing":
		_away = _library.parts[HELD]
		_library.parts.erase(HELD)
	else:
		var info: PartLibrary.PartInfo = _library.parts[HELD]
		_hash = info.mesh_hash
		info.mesh_hash = "heldsteps-" + _hash
		_library.remote_parts = "http://127.0.0.1:%d/" % PORT


func _bring_back() -> void:
	if _away != null:
		_library.parts[HELD] = _away
		_away = null
	if not _hash.is_empty():
		(_library.parts[HELD] as PartLibrary.PartInfo).mesh_hash = _hash
		_hash = ""
		_library.request_mesh(HELD, true)


# -- the cases ------------------------------------------------------------------------


## 1: the plan's bar, the app's own file ([param own]) or someone else's.
func _bar(own: bool) -> void:
	var tag: String = "bar_" + ("own" if own else "theirs")
	print("\n  -- %s" % tag)
	var model: String = _model(own, false, false)
	var original: Array = _steps(model)
	# The model as it is with every part: opened and saved.
	var whole: String = await _open_save(tag, model, "")
	_put(tag + "_0_whole.ldr", whole)
	_take_away("missing")
	var saved: String = await _open_save(tag, model, "")
	_put(tag + "_1_saved.ldr", saved)
	var steps: Array = _steps(saved)
	print("    saved without %s: %s" % [HELD, _said(steps)])
	_check("%s: saved without it, %s is alone in step 2 with its ZOOM and STEP_NAME lines" % [tag, HELD],
		_held_at(steps) == 1 and steps.size() == 4 and (steps[1][0] as Array).size() == 1
		and steps[1][1] == HELD_LOOKS)
	_check("%s: ...and every step and look line as the file has them" % tag, steps == original)
	var again: String = await _open_save(tag + "_s", saved, "")
	_put(tag + "_2_saved_again.ldr", again)
	_check("%s: opened and saved again, byte for byte (%d bytes)" % [tag, again.length()], again == saved)
	_bring_back()
	var back: String = await _open_save(tag + "_b", again, "")
	_put(tag + "_3_back.ldr", back)
	print("    with %s back: %s" % [HELD, _said(_steps(back))])
	_check("%s: with %s back, opened and saved, byte for byte as the model with every part"
		% [tag, HELD], _strip_name(back) == _strip_name(whole))


## 2-4: [param edit] ([name, args, H's step]) on the model ([param own],
## [param shared]) with H away ([param how]), saved and checked against the
## twin's.
func _case(kind: String, own: bool, shared: bool, how: String, edit: Array) -> void:
	var tag: String = "%s_%s" % [kind, edit[0]]
	print("\n  -- %s" % tag)
	var twin: String = await _open_save(tag + "_twin", _model(own, shared, true), "", edit[1])
	_put(tag + "_0_twin.ldr", twin)
	var expected: Array = _steps(twin)
	_take_away(how)
	var saved: String = await _open_save(tag, _model(own, shared, false), how, edit[1])
	_put(tag + "_1_saved.ldr", saved)
	var steps: Array = _steps(saved)
	print("    twin:  %s" % _said(expected))
	print("    saved: %s" % _said(steps))
	var at: int = _held_at(steps)
	if shared:
		var with: int = -1
		for index: int in steps.size():
			if (steps[index][0] as Array).has("3024 2"):
				with = index
		if str(edit[2]) == "with":
			_check("%s: %s in 3024's step (%d), as it was" % [tag, HELD, with + 1], at >= 0 and at == with)
		else:
			_check("%s: %s alone in its step (%d), with its ZOOM and STEP_NAME lines" % [tag, HELD, at + 1],
				at >= 0 and at != with and (steps[at][0] as Array).size() == 1 and steps[at][1] == HELD_LOOKS)
		_check("%s: every step but for %s, its parts and lines, as the twin's" % [tag, HELD],
			_without_held(steps) == expected)
	else:
		_check("%s: %s alone in step %d with its ZOOM and STEP_NAME lines (in step %d)"
			% [tag, HELD, int(edit[2]) + 1, at + 1], at == int(edit[2])
			and (steps[at][0] as Array).size() == 1 and steps[at][1] == HELD_LOOKS)
		_check("%s: every other step, its parts and lines, as the twin's" % tag,
			_without_held(steps) == expected)
	var again: String = await _open_save(tag + "_s", saved, how)
	_put(tag + "_2_saved_again.ldr", again)
	_check("%s: opened and saved again, byte for byte" % tag, again == saved)
	_bring_back()
	var back: String = await _open_save(tag + "_b", again, "")
	_put(tag + "_3_back.ldr", back)
	print("    back:  %s" % _said(_steps(back)))
	_check("%s: with %s back, opened and saved, the same steps and lines" % [tag, HELD],
		_steps(back) == steps)


## 5: H on its way while 3020 goes to the next step, which takes its step
## past H's; then it comes, and the edit is undone and redone.
func _coming(own: bool) -> void:
	var tag: String = "coming_" + ("own" if own else "theirs")
	print("\n  -- %s" % tag)
	var edit: Dictionary = {"op": "next", "bricks": ["3020"]}
	var twin: String = await _open_save(tag + "_twin", _model(own, false, true), "", edit)
	var expected: Array = _steps(twin)
	var original: Array = _steps(_model(own, false, false))
	_take_away("coming")
	var saved: String = await _open_save(tag, _model(own, false, false), "coming", edit)
	_put(tag + "_1_saved.ldr", saved)
	var steps: Array = _steps(saved)
	print("    twin:  %s" % _said(expected))
	print("    saved while on its way: %s" % _said(steps))
	_check("%s: saved while it is on its way, %s alone in step 1 with its lines; the rest as the twin's"
		% [tag, HELD], _held_at(steps) == 0 and (steps[0][0] as Array).size() == 1
		and steps[0][1] == HELD_LOOKS and _without_held(steps) == expected)
	_bring_back()
	await _landed()
	var landed: String = await _save(tag)
	_put(tag + "_2_landed.ldr", landed)
	_check("%s: come, it is put down in its own step: %s" % [tag, _said(_steps(landed))],
		_store.awaited.is_empty() and _steps(landed) == steps)
	print("    undo: %s" % (await _say("undo", {})).get_slice("\n", 0).left(120))
	var undone: String = await _save(tag)
	_put(tag + "_3_undone.ldr", undone)
	_check("%s: the edit undone, the steps as the file had them: %s" % [tag, _said(_steps(undone))],
		_steps(undone) == original)
	print("    redo: %s" % (await _say("undo", {"redo": true})).get_slice("\n", 0).left(120))
	var redone: String = await _save(tag)
	_put(tag + "_4_redone.ldr", redone)
	_check("%s: and redone, as it was edited: %s" % [tag, _said(_steps(redone))], _steps(redone) == steps)


## 6a: hsone dragged in the model's tree into hstwo, whose step 2 is H alone
## (hscheck R_*_move_into: AuthorSteps.rehomed read H as a part, a script
## error): saved, H alone in hstwo's step 2 with its lines, hsone put on in
## hstwo after its last step, and nothing of H left in the model's own steps.
func _drag_into(own: bool) -> void:
	var tag: String = "drag_" + ("own" if own else "theirs")
	print("\n  -- %s" % tag)
	_take_away("missing")
	await _open(tag, _file(own, [[A], ["1 16 200 0 0 1 0 0 0 1 0 0 0 1 hsone.ldr"],
			["1 16 -200 0 0 1 0 0 0 1 0 0 0 1 hstwo.ldr"]],
		{"hsone.ldr": [["1 4 0 0 0 1 0 0 0 1 0 0 0 1 3004.dat"],
			["1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3004.dat"]],
		"hstwo.ldr": [["1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3010.dat"], [HELD_LINE, ZOOM, NAME],
			["1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3010.dat"]]}), "missing")
	var shell: Shell = _main.get("_shell")
	var moved: String = shell.assemblies.move_into(_path_named("hsone"), _path_named("hstwo"))
	shell.verbs.edited.call()
	await _frames(6)
	var saved: String = await _save(tag)
	_put(tag + "_1_saved.ldr", saved)
	var steps: Array = _steps(_sub(saved, "hstwo"))
	print("    hsone now %s; hstwo: %s" % [moved, _said(steps)])
	_check("%s: dragged into hstwo, %s alone in its step 2 with its lines, hsone on after its last"
		% [tag, HELD], not moved.is_empty() and steps.size() == 4 and _held_at(steps) == 1
		and (steps[1][0] as Array).size() == 1 and steps[1][1] == HELD_LOOKS
		and (steps[3][0] as Array).any(func(p: String) -> bool: return p.begins_with("hsone")))
	_check("%s: ...and not in the model's own steps" % tag, _held_at(_steps(saved)) < 0)
	_bring_back()


## 6b: 3003 moved to the next step from the last step a person sees, H's
## alone after it (hscheck E2_*_next_B: it went past H's): a part alone in
## its step stays, the steps as they were, as the model without H has it.
func _next_last(own: bool) -> void:
	var tag: String = "nextlast_" + ("own" if own else "theirs")
	print("\n  -- %s" % tag)
	var text: String = _file(own, [[A], [B, TEXT], [HELD_LINE, ZOOM, NAME]], {})
	_take_away("missing")
	await _open(tag, text, "missing")
	var said: String = await _say("edit_steps", {"op": "next", "bricks": [_id_of("3003")]})
	print("    next 3003: %s" % said.get_slice("\n", 0).left(140))
	var saved: String = await _save(tag)
	_put(tag + "_1_saved.ldr", saved)
	print("    saved: %s" % _said(_steps(saved)))
	_check("%s: the steps are as they were, %s's last with its lines" % [tag, HELD],
		said.contains("as they were") and _steps(saved) == _steps(text))
	_bring_back()


## 6c: hssub placed twice, the second mirrored; its 3004 moved on in the
## second copy only (hscheck E3_*_next_S1_one: one copy's H renumbered, the
## other's not, and the second's edit lost on the save): the same in both
## copies, H's step in each its own, and the file's hssub [H | its lines]
## [3004, 3010].
func _second_copy(own: bool) -> void:
	var tag: String = "copies_" + ("own" if own else "theirs")
	print("\n  -- %s" % tag)
	_take_away("missing")
	await _open(tag, _file(own, [[A], ["1 16 200 0 0 1 0 0 0 1 0 0 0 1 hssub.ldr"],
			["1 16 -200 0 0 -1 0 0 0 1 0 0 0 1 hssub.ldr", "0 !BRICKWORKS ZOOM 2"]],
		{"hssub.ldr": [["1 4 0 0 0 1 0 0 0 1 0 0 0 1 3004.dat"], [HELD_LINE, ZOOM, NAME],
			["1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3010.dat", TEXT]]}), "missing")
	var second: int = -1
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3004":
			second = maxi(second, brick.id)
	var said: String = await _say("edit_steps", {"op": "next", "bricks": [second]})
	print("    next the second copy's 3004: %s" % said.get_slice("\n", 0).left(140))
	var held_steps: Dictionary = {}
	for placement: LdrModel.Placement in _world.held_parts():
		held_steps[placement.step] = true
	var part_steps: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id in ["3004", "3010"]:
			(part_steps.get_or_add(brick.part_id, {}) as Dictionary)[brick.step] = true
	print("    %s's steps %s; the parts' %s" % [HELD, held_steps.keys(), part_steps])
	_check("%s: both copies the same, %s in one step in each, each part in one" % [tag, HELD],
		held_steps.size() == 1 and part_steps.values().all(func(s: Dictionary) -> bool:
			return s.size() == 1))
	var saved: String = await _save(tag)
	_put(tag + "_1_saved.ldr", saved)
	var steps: Array = _steps(_sub(saved, "hssub"))
	print("    hssub saved: %s" % _said(steps))
	_check("%s: hssub saved as [%s | its lines] [3004, 3010 | TEXT]" % [tag, HELD],
		steps.size() == 2 and _held_at(steps) == 0 and (steps[0][0] as Array).size() == 1
		and steps[0][1] == HELD_LOOKS and steps[1][0] == ["3004 4", "3010 1"])
	_bring_back()


## 6d: someone else's file written whole (a sub-model made of 3020 and 3003),
## H missing or on its way (hscheck Sa_theirs_make: H was carried into the
## model's last step, out of its own): H alone in its step with its lines.
func _theirs_whole(how: String) -> void:
	var tag: String = "whole_" + how
	print("\n  -- %s" % tag)
	_take_away(how)
	await _open(tag, _file(false, [[A], [HELD_LINE, ZOOM, NAME], [B, TEXT], [C]], {}), how)
	_builder.clear_selection()
	_builder.select_brick(_id_of("3020"), true)
	_builder.select_brick(_id_of("3003"), true)
	var shell: Shell = _main.get("_shell")
	print("    made Front of %d parts" % shell.verbs.name_submodel("Front"))
	await _frames(6)
	var saved: String = await _save(tag)
	_put(tag + "_1_saved.ldr", saved)
	var steps: Array = _steps(saved)
	var at: int = _held_at(steps)
	print("    %s; saved: %s" % [_store.last_whole, _said(steps)])
	_check("%s: written whole, %s alone in its step 2 with its lines" % [tag, HELD],
		_store.last_whole.contains("written whole") and at == 1 and (steps[at][0] as Array).size() == 1
		and steps[at][1] == HELD_LOOKS)
	_bring_back()
	await _landed()


# -- helpers --------------------------------------------------------------------------


const A := "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat"
const B := "1 1 120 -16 0 1 0 0 0 1 0 0 0 1 3003.dat"
const C := "1 4 120 -40 0 1 0 0 0 1 0 0 0 1 3001.dat"
const TEXT := "0 !BRICKWORKS TEXT 20 20 60 12 5 Step three"
const HELD_LINE := "1 14 30 -24 10 1 0 0 0 1 0 0 0 1 3062b.dat"


## A file of the probe's, the app's own ([param own]) or someone else's: the
## model's steps [param main] (each a step's lines), then each sub-model of
## [param subs] (its name -> its steps).
static func _file(own: bool, main: Array, subs: Dictionary) -> String:
	var lines := PackedStringArray(["0 FILE hsfix.ldr", "0 Held steps", "0 Name: hsfix.ldr",
		"0 Author: " + ("Brickworks" if own else "Someone Else")])
	if own:
		lines.append("0 !BRICKWORKS AUTHORED_STEPS")
	lines.append("")
	var blocks: Array = [main]
	var names: Array = [""]
	for name: String in subs:
		blocks.append(subs[name])
		names.append(name)
	for index: int in blocks.size():
		if index > 0:
			lines.append_array(["0 FILE " + names[index], "0 " + names[index], "0 Name: " + names[index]])
		var steps: Array = blocks[index]
		for n: int in steps.size():
			lines.append_array(PackedStringArray(steps[n]))
			if n < steps.size() - 1:
				lines.append("0 STEP")
		lines.append("0 NOFILE")
	lines.append("")
	return "\n".join(lines)


## The section of [param text] for the sub-model [param name] ("hssub", as
## a FILE line names it with ".ldr" once or more), as a file of its own for
## [method _steps]; "" when there is none.
static func _sub(text: String, name: String) -> String:
	var out := PackedStringArray()
	var inside: bool = false
	for raw: String in text.split("\n"):
		var words: PackedStringArray = raw.strip_edges().split(" ", false)
		if words.size() >= 3 and words[0] == "0" and words[1].to_upper() == "FILE":
			var named: String = words[2].to_lower()
			while named.ends_with(".ldr"):
				named = named.trim_suffix(".ldr")
			inside = named == name
		if inside:
			out.append(raw)
	return "\n".join(out)


## The path of the copy whose name begins [param name].
func _path_named(name: String) -> String:
	var paths: Array = AuthorSteps.paths_in(_world, _store.scenery).keys()
	paths.sort()
	for path: String in paths:
		if Assemblies.leaf(path).to_lower().begins_with(name):
			return path
	return ""


## [param text] written as a model of the probe's and opened ([param how]:
## H away so).
func _open(tag: String, text: String, how: String) -> void:
	_write(MODELS + "hs_" + tag + ".ldr", text)
	_main.call("clear_model")
	await _frames(4)
	var opened: String = await _say("open_model", {"name": "hs_" + tag})
	await _settled(how)
	print("    open: %s" % opened.get_slice("\n", 0).left(140))


## [param text] written as a model of the probe's, opened ([param how]: H
## away so, or "" with every part), [param edit] made, and saved: the saved
## text.
func _open_save(tag: String, text: String, how: String, edit: Dictionary = {}) -> String:
	_write(MODELS + "hs_" + tag + ".ldr", text)
	_main.call("clear_model")
	await _frames(4)
	var opened: String = await _say("open_model", {"name": "hs_" + tag})
	await _settled(how)
	print("    open: %s" % opened.get_slice("\n", 0).left(140))
	if not edit.is_empty():
		var said: String = ""
		if edit.has("remove"):
			said = await _say("edit_model", {"remove": [_id_of(str(edit["remove"]))], "picture": false})
		else:
			var args: Dictionary = edit.duplicate()
			if args.has("bricks"):
				args["bricks"] = (args["bricks"] as Array).map(func(p: String) -> int: return _id_of(p))
			said = await _say("edit_steps", args)
		print("    %s: %s" % [JSON.stringify(edit), said.get_slice("\n", 0).left(140)])
	return await _save(tag)


## Saved under the one name each case has, so two saves of a model are
## compared byte for byte.
func _save(tag: String) -> String:
	var name: String = "hs_saved_" + tag.get_slice("_", 0) + ".ldr"
	await _say("save_model", {"name": name})
	return FileAccess.get_file_as_string(MODELS + name)


## [param text] without its "0 Name:" line, which says the file it was
## saved as.
static func _strip_name(text: String) -> String:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if not line.begins_with("0 Name:"):
			out.append(line)
	return "\n".join(out)


## Until the model is down: with H on its way ([param how] "coming"), until
## it is the one part awaited.
func _settled(how: String) -> void:
	for _n: int in 900:
		if not _store.laying and (_store.awaited.is_empty() if how != "coming"
				else _store.awaited.size() == 1):
			break
		await process_frame
	await _frames(6)
	if how == "coming":
		_check("H is on its way: %d awaited, %d parts down" % [_store.awaited.size(),
			_world.brick_count()], _store.awaited.size() == 1
			and (_store.awaited[0] as LdrModel.Placement).part_id == HELD)


func _landed() -> void:
	for _n: int in 600:
		if _store.awaited.is_empty():
			break
		await process_frame
	await _frames(6)


func _id_of(part: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and not _store.scenery.has(brick.id):
			return brick.id
	return -1


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	var lines: PackedStringArray = text.split("\n")
	while lines.size() > 1 and (lines[0].begins_with("Tab ") or lines[0].begins_with("Careful")):
		lines.remove_at(0)
	return "\n".join(lines)


func _put(name: String, text: String) -> void:
	_write(_out.path_join(name), text)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
