## savereview4: attacks on actorstamp (a step is the person's unless a session's
## code keeps it: Builder.by / by_wait for a call's first stretch, a tool that
## carries the session past a wait). Run the same on pre261 to compare.
##
##   godot --headless --path . --script src/dev/savereview4_attack_probe.gd -- --sr4=fam,mid,k,par,mech
##
## Every act of the person's is a real key through Input, heard by the app's
## own handlers; the chat's calls go through the app's own CommandSocket.
##   fam  one call from each family (placing, painting, Brickify, plans, a design
##        with its floor): every step it keeps is the chat's, and one undo of the
##        chat's puts the model back as it was, part for part
##   mid  the person paints 5 bricks red by C while a call that waits works:
##        their paint is theirs, the chat's steps the chat's, the chat's undo
##        leaves the red, and the person's Ctrl+Z then the chat's undo put the
##        model back as it was
##   k    savereview3b's K1-K2 as first written (a one-brick check, ending in the
##        frame a paint said first lands), judged by what the person keeps; K4
##        and K5 on a call that waits and may change (submit_design); K6 on a
##        real call (edit_model's recolour, then the person's C on that brick)
##   par  a chat's submit_design on a baseplate and its save_model sent at once,
##        as a client sends parallel calls: whose the floor's step is
##   mech 31070-1: move_part, a motion played, pose_model: each step the chat's
extends SceneTree

const CHAT := "probe-savereview4-chat"
const OTHER := "probe-savereview4-other"
const SPACE := 40.0
const SVG := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"64\"><rect width=\"64\" height=\"64\" fill=\"#d01012\"/><circle cx=\"32\" cy=\"32\" r=\"20\" fill=\"#ffffff\"/></svg>"
const DOORS := "res://vendor/omr/files/31070-1.mpd"

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _bg_said: String = ""
var _bg_done: bool = false
var _actors: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveTo.native = false
	Account.where = "user://probe_savereview4_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_savereview4_collection.json"
	DirAccess.remove_absolute(CollectionStore.where)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")) and _main.get("_shell") != null and _main.get("_bar") != null:
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	var account: Account = _main.get("_account")
	while account.state == Account.State.CHECKING:
		await account.changed
	await process_frame
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_actors = _builder.has_method("by_wait")
	Assistant.brickbench = false
	print("tree: %s" % ("actorstamp" if _actors else "pre261"))
	var parts: PackedStringArray = PackedStringArray(["fam", "mid", "k", "par", "mech"])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sr4="):
			parts = arg.trim_prefix("--sr4=").split(",")
	if "fam" in parts:
		await _families()
	if "mid" in parts:
		await _mids()
	if "k" in parts:
		await _ks()
	if "par" in parts:
		await _parallel()
	if "mech" in parts:
		await _mechanisms()
	if "t6" in parts:
		await _big_steps()
	if "relay" in parts:
		await _relaid()
	_quit()


# ---- relay: a part taken off and the same put back, by a session's edit_model -------------


## The chat's edit_model takes a brick off and puts the same brick back where it
## was (and paints a second, so the call changes something); then the person's
## Ctrl+Z. Every part back under its own number?
func _relaid() -> void:
	print("\nR1 the chat's edit_model takes #a off and puts the same part back in its place, and paints #b; then the person's Ctrl+Z")
	await _person_grid(6)
	var two: Array = _ids(2)
	var brick: BrickWorld.Brick = _world.get_brick(int(two[0]))
	var o: Vector3 = brick.transform.origin
	var ids_before: Array = _all_ids()
	var was: PackedStringArray = _snap()
	# Its place in edit_model's words, as the designer reads the model
	# (copyfaults_probe's _placement_of).
	var add: Dictionary = {"part": "3005", "color": 1}
	var model: Object = (_main.get("_assistant") as Object).call("_model_from_world")
	for placement: Object in model.get("placements"):
		if int(placement.get("id")) == brick.id:
			for key: String in ["x", "y", "z", "face", "rot"]:
				if placement.get(key) != null:
					add[key] = placement.get(key)
	var said: String = await _say("edit_model", {"remove": [brick.id], "add": [add],
		"recolor": [{"bricks": [int(two[1])], "color": 14}]}, CHAT)
	await _frames(5)
	print("    edit_model: %s" % said.left(200).replace("\n", " "))
	print("    kept: %s" % _stamps(2))
	var same_place: bool = false
	for one: BrickWorld.Brick in _world.bricks():
		if one.part_id == "3005" and one.transform.origin.is_equal_approx(o) and one.id != brick.id:
			same_place = true
	print("    a new 3005 where #%d stood: %s" % [brick.id, same_place])
	_key(KEY_Z, true)
	await _frames(10)
	var ids_after: Array = _all_ids()
	print("    MEASURE R1: #%d back %s; ids as before %s; %d parts off" % [brick.id,
		_world.get_brick(brick.id) != null, ids_after == ids_before, _off(was, _snap())])
	_check("R1 the person's Ctrl+Z puts every part back as it was, under its own number",
		ids_after == ids_before and _snap() == was)


func _all_ids() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		out.append(brick.id)
	out.sort()
	return out


# ---- t6: the person's own steps on 6,084 parts, no chat ------------------------------


## The person's C and Delete on 6,084 selected parts, then Ctrl+Z and Ctrl+Y:
## how long from the key to the change (frames included), and each comes back
## exactly. No chat at all.
func _big_steps() -> void:
	print("\nT6 the person's own C, Delete, Ctrl+Z and Ctrl+Y on 6,084 parts, no chat")
	await _person_grid(78)
	for verb: String in ["paint", "delete", "paint", "delete"]:
		var ids: Array = _select(6084)
		var was: PackedStringArray = _snap()
		var count: int = _world.brick_count()
		var from: int = Time.get_ticks_usec()
		_key(KEY_C if verb == "paint" else KEY_DELETE)
		var frames: int = 0
		for _n: int in 2000:
			await process_frame
			frames += 1
			if (verb == "paint" and _count_colour(ids, 4) == ids.size()) or (verb == "delete"
					and _world.brick_count() < count):
				break
		var act_ms: float = (Time.get_ticks_usec() - from) / 1000.0
		var done: PackedStringArray = _snap()
		from = Time.get_ticks_usec()
		_key(KEY_Z, true)
		for _n: int in 2000:
			await process_frame
			if _snap_size_or_colour(was):
				break
		var undo_ms: float = (Time.get_ticks_usec() - from) / 1000.0
		var undone: PackedStringArray = _snap()
		from = Time.get_ticks_usec()
		_key(KEY_Y, true)
		for _n: int in 2000:
			await process_frame
			if _snap_size_or_colour(done):
				break
		var redo_ms: float = (Time.get_ticks_usec() - from) / 1000.0
		var redone: PackedStringArray = _snap()
		print("    MEASURE T6 %s: key to change %.0f ms (%d frames), Ctrl+Z %.0f ms, Ctrl+Y %.0f ms" % [verb,
			act_ms, frames, undo_ms, redo_ms])
		_check("T6 %s: Ctrl+Z puts back exactly (%d off), Ctrl+Y does it again exactly (%d off)" % [verb,
			_off(was, undone), _off(done, redone)], undone == was and redone == done)
		# Back to the grid as laid, for the next.
		_key(KEY_Z, true)
		await _frames(20)
		_builder._redo.clear()


## Whether the model now matches [param snap] in count and in red parts.
func _snap_size_or_colour(snap: PackedStringArray) -> bool:
	if _world.brick_count() != snap.size():
		return false
	var red: int = 0
	for line: String in snap:
		if line.contains("|4|"):
			red += 1
	var now: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.color_code == 4:
			now += 1
	return now == red


# ---- fam: each family's call, every step the chat's ---------------------------------


func _families() -> void:
	var bunny: String = ProjectSettings.globalize_path("res://tests/fixtures/brickify/bunny.obj")
	await _person_grid(6)
	var two: Array = _ids(2)
	await _one_call("F1 edit_model add (placing)", "edit_model", {"add": [
		{"part": "3001", "color": 4, "x": -8, "y": 0, "z": -8}]})
	await _person_grid(6)
	two = _ids(2)
	await _one_call("F2 edit_model recolor (painting)", "edit_model", {"recolor": [
		{"bricks": two, "color": 14}]})
	await _person_grid(26)
	await _one_call("F3 replace_parts 676 (painting, a swap)", "replace_parts", {
		"find": {"part": "3005"}, "replace": {"part": "3004"}})
	await _person_grid(6)
	await _one_call("F4 print_part svg (painting, a print)", "print_part", {
		"brick": int(_ids(1)[0]), "svg": SVG, "name": "sr4 print"})
	await _person_grid(6)
	await _one_call("F5 brickify bunny (Brickify)", "brickify", {"file": bunny, "studs": 10})
	await _person_grid(6)
	await _one_call("F6 page_setup header (plans)", "page_setup", {"header": "sr4 header"})
	await _person_grid(6)
	await _one_call("F7 edit_booklet highlight (plans)", "edit_booklet", {"step": 1, "highlight": true})
	await _person_grid(26)
	await _one_call("F8 edit_steps name, 676 parts (plans, paced)", "edit_steps", {
		"op": "name", "step": 1, "name": "sr4 grid"})
	await _say("clear_model", {}, CHAT)
	await _frames(3)
	_builder.forget_history()
	await _one_call("F9 submit_design on a baseplate (a design with its floor)", "submit_design", _hut())
	await _person_grid(6)
	await _one_call("F10 mirror_parts copy (placing)", "mirror_parts", {"bricks": _ids(2), "axis": "x",
		"copy": true})


## A small scene on its lot: a baseplate goes in as part of the build.
func _hut() -> Dictionary:
	var bricks: Array = []
	for x: int in 4:
		for z: int in 3:
			bricks.append({"part": "3001", "color": 4, "x": x * 4, "y": 0, "z": z * 2})
	return {"name": "sr4 hut", "description": "a small red hut on its lot, a scene", "floor": "baseplate",
		"floor_colour": "Green", "bricks": bricks}


## The chat's [param tool] once; every step kept since it began, whose; one undo
## of the chat's; the model as it was before.
func _one_call(what: String, tool: String, input: Dictionary) -> void:
	print("\n%s" % what)
	var prefix: Array = _builder.steps_now()[0].duplicate()
	var was: PackedStringArray = _snap()
	var said: String = await _say(tool, input, CHAT)
	await _frames(5)
	print("    SAID: " + said.left(200).replace("\n", " "))
	var new: Array = _since(prefix)
	var mine: int = 0
	var others: PackedStringArray = PackedStringArray()
	for step: Dictionary in new:
		var by: String = str(step.get("by", ""))
		print("    kept: \"%s\" by %s" % [_words(step), "\"%s\"" % by if not by.is_empty() else "the person"])
		if by == CHAT:
			mine += 1
		else:
			others.append(_words(step))
	var changed: bool = _snap() != was
	print("    MEASURE %s: changed %s, steps since %d, the chat's %d, others %s" % [what.get_slice(" ", 0),
		changed, new.size(), mine, others])
	if not changed and new.is_empty():
		print("  SKIP %s: the call changed nothing" % what.get_slice(" ", 0))
		return
	_check("%s every step it kept is the chat's" % what.get_slice(" ", 0), others.is_empty() and mine >= 1)
	_check("%s one call, one step" % what.get_slice(" ", 0), new.size() == 1)
	var undo: String = await _say("undo", {}, CHAT)
	await _frames(5)
	print("    the chat's undo: " + undo.left(220).replace("\n", " "))
	var back: PackedStringArray = _snap()
	_check("%s one undo of the chat's puts the model back as it was (%d parts off)" % [
		what.get_slice(" ", 0), _off(was, back)], back == was)


# ---- mid: the person's paint while the call waits -----------------------------------


func _mids() -> void:
	var bunny: String = ProjectSettings.globalize_path("res://tests/fixtures/brickify/bunny.obj")
	await _person_grid(6)
	await _paint_during("M1 brickify bunny", "brickify", {"file": bunny, "studs": 10})
	await _person_grid(26)
	await _paint_during("M2 edit_steps name, 676 parts", "edit_steps", {"op": "name", "step": 1,
		"name": "sr4 grid"})
	await _person_grid(26)
	await _paint_during("M3 replace_parts 676", "replace_parts", {"find": {"part": "3005"},
		"replace": {"part": "3004"}})
	await _person_grid(6)
	await _paint_during("M4 submit_design beside the person's grid", "submit_design", {
		"name": "sr4 wall", "description": "a short red wall", "floor": "none", "bricks": [
			{"part": "3001", "color": 4, "x": -12, "y": 0, "z": -12},
			{"part": "3001", "color": 4, "x": -8, "y": 0, "z": -12}]})


## The person paints 5 bricks red by C while the chat's [param tool] works.
func _paint_during(what: String, tool: String, input: Dictionary) -> void:
	var tag: String = what.get_slice(" ", 0)
	print("\n%s while the person paints 5 bricks red by C" % what)
	var ids: Array = _select(5)
	var prefix: Array = _builder.steps_now()[0].duplicate()
	var was: PackedStringArray = _snap()
	_bg_done = false
	_spawned(tool, input, CHAT)
	for _n: int in 600:
		if _bg_done or CommandSocket.at_work():
			break
		await process_frame
	# A frame into the call: its first stretch has run.
	await process_frame
	var during: bool = not _bg_done
	_key(KEY_C)
	for _n: int in 120:
		await process_frame
		if _count_colour(ids, 4) == ids.size():
			break
	var painted_during: bool = not _bg_done and _count_colour(ids, 4) == ids.size()
	for _n: int in 6000:
		if _bg_done:
			break
		await process_frame
	await _frames(5)
	print("    SAID: " + _bg_said.left(200).replace("\n", " "))
	print("    the person's C landed while the call worked: %s (call still going a frame in: %s)" % [
		painted_during, during])
	var person: int = 0
	var chats: int = 0
	var wrong: PackedStringArray = PackedStringArray()
	for step: Dictionary in _since(prefix):
		var by: String = str(step.get("by", ""))
		var paints: bool = _names_only(step, ids)
		print("    kept: \"%s\" by %s%s" % [_words(step), "\"%s\"" % by if not by.is_empty() else "the person",
			" (the person's paint)" if paints else ""])
		if paints and by.is_empty():
			person += 1
		elif by == CHAT and not paints:
			chats += 1
		else:
			wrong.append("\"%s\" by \"%s\"" % [_words(step), by])
	print("    MEASURE %s: the person's %d, the chat's %d, wrong %s" % [tag, person, chats, wrong])
	_check("%s the person's paint is theirs and every other step the chat's" % tag,
		person == 1 and wrong.is_empty())
	var undo: String = await _say("undo", {}, CHAT)
	await _frames(5)
	print("    the chat's undo: " + undo.left(220).replace("\n", " "))
	_check("%s the chat's undo leaves the person's red" % tag, _count_colour(ids, 4) == ids.size())
	if not undo.begins_with("Undid"):
		# Under the person's newer step: their Ctrl+Z first, then the chat's.
		_key(KEY_Z, true)
		await _frames(8)
		undo = await _say("undo", {}, CHAT)
		await _frames(5)
		print("    after the person's Ctrl+Z, the chat's undo: " + undo.left(160).replace("\n", " "))
	else:
		_key(KEY_Z, true)
		await _frames(8)
	var back: PackedStringArray = _snap()
	_check("%s the chat's undo and the person's Ctrl+Z put the model back as it was (%d parts off)" % [
		tag, _off(was, back)], back == was)


# ---- k: savereview3b's attacks as first written, and on calls that wait ---------------


func _ks() -> void:
	await _during_one_brick("K1r Delete, 5 selected", 5, "delete")
	await _during_one_brick("K2r C (paint), 620 selected", 620, "paint")
	# savereview3b's K3 as first written: paint remembered slow at this size.
	Working.expected_ms("paint", 20)
	Working.costs["paint@%d" % Working._size_class(20)] = [400.0, 400.0]
	await _during_one_brick("K3r C (paint), 20 selected, paint remembered slow", 20, "paint")
	Working.costs.erase("paint@%d" % Working._size_class(20))
	await _during_design_delete()
	await _during_design_undo()
	await _one_brick_both()


## savereview3b's K1/K2 as first written: a check of one brick, which can end
## in the frame a paint said first lands. Judged by what the person keeps.
func _during_one_brick(what: String, count: int, verb: String) -> void:
	var tag: String = what.get_slice(" ", 0)
	print("\n%s while the chat's check_design of ONE brick looks; then the chat asks undo" % what)
	await _person_grid(26)
	var ids: Array = _select(count)
	var before: int = _world.brick_count()
	var was: PackedStringArray = _snap()
	_bg_done = false
	_spawned("check_design", {"name": "grid", "bricks": [{"part": "3005", "color": 1, "x": 0, "y": 0,
		"z": 0}]}, CHAT)
	for _n: int in 600:
		if _bg_done or CommandSocket.at_work():
			break
		await process_frame
	_key(KEY_DELETE if verb == "delete" else KEY_C)
	for _n: int in 600:
		await process_frame
		if _world.brick_count() != before or _count_colour(ids, 4) == ids.size():
			break
	print("    landed with the call at work: %s; call done %s" % [CommandSocket.at_work(), _bg_done])
	for _n: int in 3000:
		if _bg_done:
			break
		await process_frame
	await _frames(3)
	print("    top %s" % _stamps(2))
	var after: int = _world.brick_count()
	var red: int = _count_colour(ids, 4)
	var said: String = await _say("undo", {}, CHAT)
	print("    SAID: " + said.left(200).replace("\n", " "))
	if verb == "delete":
		_check("%s the chat's undo leaves the person's delete" % tag, _world.brick_count() == after
			and after == before - count)
	else:
		_check("%s the chat's undo leaves the person's paint" % tag, _count_colour(ids, 4) == red
			and red == count)
	_key(KEY_Z, true)
	await _frames(10)
	_check("%s the person's Ctrl+Z puts back exactly what they did (%d parts off)" % [tag,
		_off(was, _snap())], _snap() == was)


## K4 on a call that waits and may change: the person's Delete of 320 while
## the chat's submit_design works beside their grid.
func _during_design_delete() -> void:
	print("\nK4r Delete, 320 selected, while the chat's submit_design works; then the chat asks undo")
	await _person_grid(26)
	_select(320)
	var before: int = _world.brick_count()
	var was: PackedStringArray = _snap()
	_bg_done = false
	_spawned("submit_design", _wall(), CHAT)
	for _n: int in 600:
		if _bg_done or CommandSocket.at_work():
			break
		await process_frame
	await process_frame
	var during: bool = not _bg_done
	_key(KEY_DELETE)
	for _n: int in 600:
		await process_frame
		if _world.brick_count() <= before - 320:
			break
	var landed_during: bool = not _bg_done
	for _n: int in 6000:
		if _bg_done:
			break
		await process_frame
	await _frames(5)
	print("    SAID: " + _bg_said.left(160).replace("\n", " "))
	print("    the Delete landed while the call worked: %s (a frame in: %s); top %s" % [landed_during,
		during, _stamps(3)])
	var after: int = _world.brick_count()
	var said: String = await _say("undo", {}, CHAT)
	await _frames(5)
	print("    the chat's undo: " + said.left(200).replace("\n", " "))
	var after_chat: int = _world.brick_count()
	print("    MEASURE K4r: parts %d -> %d (after the call) -> %d (after the chat's undo); the person's delete leaves %d"
		% [before, after, after_chat, before - 320])
	_check("K4r the person's Delete landed while the call worked", landed_during)
	_check("K4r the chat's undo leaves the person's delete and takes the wall", after_chat == before - 320
		or not said.begins_with("Undid"))
	# The person's Ctrl+Z (and the chat's, if it waited under it): back as it was.
	_key(KEY_Z, true)
	await _frames(10)
	if not said.begins_with("Undid"):
		await _say("undo", {}, CHAT)
		await _frames(5)
	_check("K4r the person's Ctrl+Z brings back their 320 exactly (%d parts off)" % _off(was, _snap()),
		_snap() == was)


## K5 on a call that waits: the person's own Ctrl+Z while submit_design works,
## then their Ctrl+Y.
func _during_design_undo() -> void:
	print("\nK5r the person deletes 5; while the chat's submit_design works, their Ctrl+Z; then Ctrl+Y")
	await _person_grid(26)
	_select(5)
	var start: int = _world.brick_count()
	_key(KEY_DELETE)
	await _frames(8)
	var deleted: int = _world.brick_count()
	_bg_done = false
	_spawned("submit_design", _wall(), CHAT)
	for _n: int in 600:
		if _bg_done or CommandSocket.at_work():
			break
		await process_frame
	await process_frame
	_key(KEY_Z, true)
	for _n: int in 600:
		await process_frame
		if _world.brick_count() >= start:
			break
	var landed_during: bool = not _bg_done
	for _n: int in 6000:
		if _bg_done:
			break
		await process_frame
	await _frames(5)
	var wall: int = 2
	var undone: int = _world.brick_count()
	print("    the Ctrl+Z landed while the call worked: %s; parts %d -> %d -> %d; top %s" % [landed_during,
		start, deleted, undone, _stamps(3)])
	_check("K5r the person's Ctrl+Z landed while the call worked, and brought back their 5", landed_during
		and undone == start + wall)
	_key(KEY_Y, true)
	await _frames(8)
	var redone: int = _world.brick_count()
	print("    MEASURE K5r redo: after Ctrl+Y parts %d (their delete again makes it %d)" % [redone,
		deleted + wall])
	_check("K5r the person's Ctrl+Y does their delete again", redone == deleted + wall)


## A short wall of two bricks beside the person's grid, not on it.
func _wall() -> Dictionary:
	return {"name": "sr4 wall", "description": "a short red wall", "floor": "none", "bricks": [
		{"part": "3001", "color": 4, "x": -12, "y": 0, "z": -12},
		{"part": "3001", "color": 4, "x": -8, "y": 0, "z": -12}]}


## K6 on a real call: the chat's edit_model recolours a brick yellow; while the
## call still works, the person paints the same brick red by C.
func _one_brick_both() -> void:
	print("\nK6r the chat's edit_model paints a brick yellow; in that call the person paints it red by C")
	await _person_grid(6)
	var brick_id: int = int(_select(1)[0])
	_bg_done = false
	_spawned("edit_model", {"recolor": [{"bricks": [brick_id], "color": 14}]}, CHAT)
	var yellow_during: bool = false
	for _n: int in 600:
		await process_frame
		if _world.get_brick(brick_id).color_code == 14:
			yellow_during = not _bg_done
			break
		if _bg_done:
			break
	if _bg_done:
		print("    the call ended in the frame its paint landed: the person paints right after")
	_key(KEY_C)
	for _n: int in 120:
		await process_frame
		if _world.get_brick(brick_id).color_code == 4:
			break
	var red_during: bool = not _bg_done
	for _n: int in 3000:
		if _bg_done:
			break
		await process_frame
	await _frames(5)
	print("    yellow while the call worked %s; the person's red while it worked %s; history %s" % [
		yellow_during, red_during, _stamps(3)])
	var said: String = await _say("undo", {}, CHAT)
	await _frames(5)
	var after_chat: int = _world.get_brick(brick_id).color_code
	print("    the chat's undo: %s -> colour %d" % [said.left(160).replace("\n", " "), after_chat])
	_check("K6r the chat's undo leaves the person's red", after_chat == 4)
	_key(KEY_Z, true)
	await _frames(8)
	var after_person: int = _world.get_brick(brick_id).color_code
	said = await _say("undo", {}, CHAT)
	await _frames(5)
	var last: int = _world.get_brick(brick_id).color_code
	print("    MEASURE K6r: after the chat's undo %d, the person's Ctrl+Z %d, the chat's undo again %d (1 blue, 14 yellow, 4 red)"
		% [after_chat, after_person, last])
	_check("K6r the person's Ctrl+Z takes back only their red (to the chat's yellow)", after_person == 14)
	_check("K6r the chat's undo then takes back its yellow, to the blue laid", last == 1)


# ---- par: a chat's parallel calls ---------------------------------------------------


func _parallel() -> void:
	print("\nP1 a chat's submit_design on a baseplate and its save_model sent at once")
	await _say("clear_model", {}, CHAT)
	await _frames(3)
	_builder.forget_history()
	var was: PackedStringArray = _snap()
	_bg_done = false
	_spawned("submit_design", _hut(), CHAT)
	for _n: int in 600:
		if _bg_done or CommandSocket.at_work():
			break
		await process_frame
	var saved: String = await _say("save_model", {"name": "sr4 parallel"}, CHAT)
	print("    save_model, sent while the design worked (done %s): %s" % [_bg_done, saved.left(160).replace("\n", " ")])
	for _n: int in 6000:
		if _bg_done:
			break
		await process_frame
	await _frames(5)
	print("    the design: " + _bg_said.left(160).replace("\n", " "))
	var wrong: PackedStringArray = PackedStringArray()
	for step: Dictionary in _builder.steps_now()[0]:
		var by: String = str(step.get("by", ""))
		print("    kept: \"%s\" by %s" % [_words(step), "\"%s\"" % by if not by.is_empty() else "the person"])
		if by != CHAT:
			wrong.append(_words(step))
	_check("P1 every step of the design is the chat's (%s)" % ", ".join(wrong), wrong.is_empty())
	var undo: String = await _say("undo", {}, CHAT)
	await _frames(5)
	print("    the chat's undo: " + undo.left(200).replace("\n", " "))
	_check("P1 one undo of the chat's takes its design and its baseplate (%d parts left)" % _world.brick_count(),
		_snap() == was)
	if _snap() != was:
		undo = await _say("undo", {}, CHAT)
		await _frames(5)
		print("    the chat's second undo: " + undo.left(260).replace("\n", " "))
		_check("P1 the chat is never told its own baseplate is the person's", not undo.contains("person's own"))

	print("\nP2 another chat's save_model while the first chat's design works")
	await _say("clear_model", {}, CHAT)
	await _frames(3)
	_builder.forget_history()
	_bg_done = false
	_spawned("submit_design", _hut(), CHAT)
	for _n: int in 600:
		if _bg_done or CommandSocket.at_work():
			break
		await process_frame
	saved = await _say("save_model", {"name": "sr4 other"}, OTHER)
	print("    the other chat's save_model (design done %s): %s" % [_bg_done, saved.left(160).replace("\n", " ")])
	for _n: int in 6000:
		if _bg_done:
			break
		await process_frame
	await _frames(5)
	wrong = PackedStringArray()
	for step: Dictionary in _builder.steps_now()[0]:
		var by: String = str(step.get("by", ""))
		print("    kept: \"%s\" by %s" % [_words(step), "\"%s\"" % by if not by.is_empty() else "the person"])
		if by != CHAT:
			wrong.append(_words(step))
	_check("P2 every step of the first chat's design is its own (%s)" % ", ".join(wrong), wrong.is_empty())

	print("\nP3 a chat's design, then its review_model surface=true (the surface pass lays parts), alone")
	await _say("clear_model", {}, CHAT)
	await _frames(3)
	_builder.forget_history()
	var block: Array = []
	for x: int in 3:
		for z: int in 3:
			block.append({"part": "3001", "color": 71, "x": x * 4, "y": 0, "z": z * 2})
	var built: String = await _say("submit_design", {"name": "sr4 block", "description": "a grey block",
		"floor": "none", "bricks": block}, CHAT)
	print("    the design: " + built.left(100).replace("\n", " "))
	_builder.forget_history()
	await _one_call("P3 review_model surface=true", "review_model", {"surface": true})


# ---- mech: 31070-1's joints ------------------------------------------------------------


func _mechanisms() -> void:
	print("\nmech: 31070-1")
	if not await _open(DOORS):
		return
	var player: MotionPlayer = _main.get("_motions")
	var joints: Array = player.movable()
	var lead: int = player.parts_of(joints[0])[0] if not joints.is_empty() else 0
	print("    the first joint a drag moves: #%d" % lead)
	await _one_call("X1 move_part 20 degrees (a mechanism, grabbed)", "move_part", {"part": "#%d" % lead,
		"degrees": 20})
	var kept: String = await _say("define_motion", {"name": "sr4 out and back", "tracks": [
		{"joint": "#%d" % lead, "keys": [{"t": 0, "place": 0}, {"t": 1, "place": 20}, {"t": 2, "place": 10}]}]},
		CHAT)
	print("    define_motion: " + kept.left(120).replace("\n", " "))
	# Its own step (the motion kept) set aside: the play's is what is judged.
	_builder.forget_history()
	await _one_call("X2 play_motion (a mechanism, paced)", "play_motion", {"name": "sr4 out and back"})
	await _one_call("X3 pose_model joint 1 to 30 degrees", "pose_model", {"joint": "1", "degrees": 30})
	_select_ids([])
	await _paint_open("X4 play_motion while the person paints 5 red", "play_motion", {"name": "sr4 out and back"})


## [method _paint_during] on the model open now.
func _paint_open(what: String, tool: String, input: Dictionary) -> void:
	await _paint_during(what, tool, input)


func _open(path: String) -> bool:
	if not FileAccess.file_exists(path):
		print("    (no %s)" % path)
		_failures += 1
		return false
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 400:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(5)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null and playback.is_playing():
		playback.stop()
	_builder.forget_history()
	await _frames(20)
	return _world.brick_count() > 0


# ---- the person's model and hands ----------------------------------------------


func _person_grid(side: int) -> void:
	await _say("clear_model", {}, CHAT)
	await _frames(2)
	_builder.forget_history()
	_builder.clear_selection()
	var ids: Array = []
	for x: int in side:
		for z: int in side:
			ids.append(_world.add_brick("3005", 1, Transform3D(Basis(),
				Vector3(x * SPACE, 0, z * SPACE))))
	var steps: Array = []
	for brick_id: int in ids:
		steps.append({"undo": "remove", "brick": brick_id})
	_builder.record(steps, "laid %d bricks" % ids.size())
	await _frames(2)


func _ids(count: int) -> Array:
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if ids.size() >= count:
			break
		if brick.part_id == "3005":
			ids.append(brick.id)
	return ids


func _select(count: int) -> Array:
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if ids.size() >= count:
			break
		if not _store.scenery.has(brick.id):
			ids.append(brick.id)
	_select_ids(ids)
	return ids


func _select_ids(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: Variant in ids:
		_builder.selection[int(brick_id)] = true
	_builder.selection_changed.emit(_builder.selection.size())
	_builder.held_color = 4


func _count_colour(ids: Array, colour: int) -> int:
	var count: int = 0
	for brick_id: Variant in ids:
		var brick: BrickWorld.Brick = _world.get_brick(int(brick_id))
		if brick != null and brick.color_code == colour:
			count += 1
	return count


## Whether [param step] recolours only bricks among [param ids].
func _names_only(step: Dictionary, ids: Array) -> bool:
	var inner: Array = step.get("steps", [step])
	if inner.is_empty():
		return false
	for one: Variant in inner:
		if not one is Dictionary or str((one as Dictionary).get("undo", "")) != "recolor" \
				or not ids.has(int((one as Dictionary).get("brick", 0))):
			return false
	return true


## The model, part for part: part, colour and place of each, sorted.
func _snap() -> PackedStringArray:
	var out := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		var o: Vector3 = brick.transform.origin
		var b: Basis = brick.transform.basis
		out.append("%s|%d|%.1f,%.1f,%.1f|%.2f,%.2f,%.2f,%.2f,%.2f,%.2f" % [brick.part_id, brick.color_code,
			o.x, o.y, o.z, b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z])
	out.sort()
	return out


## How many of the parts of [param a] and [param b] are not in the other.
func _off(a: PackedStringArray, b: PackedStringArray) -> int:
	var count: Dictionary = {}
	for line: String in a:
		count[line] = int(count.get(line, 0)) + 1
	for line: String in b:
		count[line] = int(count.get(line, 0)) - 1
	var off: int = 0
	for line: String in count:
		off += absi(int(count[line]))
	return off


## The history's steps kept since [param prefix] was its start.
func _since(prefix: Array) -> Array:
	var now: Array = _builder.steps_now()[0]
	var same: int = 0
	while same < mini(prefix.size(), now.size()) and is_same(prefix[same], now[same]):
		same += 1
	return now.slice(same)


func _words(step: Dictionary) -> String:
	return str(step.get("words", step.get("undo", "?"))).left(70)


func _key(code: Key, ctrl: bool = false) -> void:
	root.gui_release_focus()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		event.pressed = pressed
		Input.parse_input_event(event)


func _stamps(count: int) -> String:
	var out := PackedStringArray()
	var words: PackedStringArray = _builder.history_words(count, false)
	for k: int in mini(count, _builder.history_depth()):
		var step: Dictionary = _builder._history[_builder.history_depth() - 1 - k]
		out.append("\"%s\" by %s" % [words[k] if k < words.size() else "?",
			"\"%s\"" % str(step.get("by", "")) if step.has("by") else "the person"])
	return " | ".join(out) if not out.is_empty() else "(none)"


# ---- the harness (as savereview3b_attack_probe's) ------------------------------


func _spawned(tool: String, arguments: Dictionary, chat: String) -> void:
	_bg_said = await _say(tool, arguments, chat)
	_bg_done = true


func _say(tool: String, arguments: Dictionary, chat: String) -> String:
	var said: String = await _one(tool, arguments, chat)
	var job := RegEx.create_from_string("^(Tab [^.]*\\. )?Started job (\\d+)")
	var found: RegExMatch = job.search(said)
	var polls: int = 0
	while found != null and polls < 240:
		said = await _one("job", {"id": int(found.get_string(2))}, chat)
		polls += 1
		if not said.contains("is still going"):
			break
		await _frames(30)
	return said


func _one(tool: String, arguments: Dictionary, chat: String) -> String:
	_next += 1
	var params: Dictionary = {"name": tool, "arguments": arguments}
	if not chat.is_empty():
		params["_meta"] = {CommandSocket.CHAT_KEY: {"chat": chat}}
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": params})
	var text := PackedStringArray()
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		if str((block as Dictionary).get("type", "")) == "text":
			text.append(str((block as Dictionary).get("text", "")))
	return "\n".join(text)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _quit() -> void:
	if _socket != null:
		_socket.stop()
	DirAccess.remove_absolute(CollectionStore.where)
	print("savereview4_attack_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
