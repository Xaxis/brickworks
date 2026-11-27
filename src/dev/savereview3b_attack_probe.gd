## savereview3b: more attacks on d43save's step stamp (Builder.PERSON while an
## input event of the person's is heard this frame, else Builder.BY = the chat
## of the call at work). Run the same on pre261 to compare.
##
##   godot --headless --path . --script src/dev/savereview3b_attack_probe.gd
##
## Every act of the person's is a real key through Input, heard by the app's
## own handlers; the chat's calls go through the app's own CommandSocket.
##   K1 a small Delete (kept in the key's frame) while the chat's look works
##   K2 a paint of 620 (Shell.SLOW_FROM says it first, so the frame after)
##   K3 a paint of 20 on a model where Working remembers paint as slow
##   K4 a Delete of 320 while the chat's save_model works (a call that may change)
##   K5 the person's own Ctrl+Z while the chat's save_model works, then Ctrl+Y
##   K6 the chat's step and the person's on one part in one call (builder level)
##   T  what the stamp costs on a 6,000-part step
extends SceneTree

const CHAT := "probe-savereview3b-chat"
const GRID := 26          ## 26 x 26 = 676 bricks of the person's
const SPACE := 40.0       ## LDU between them

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _bg_said: String = ""
var _bg_done: bool = false
var _d43: bool = false
## actorstamp's tree: a step is the person's unless a session's code keeps it
## (Builder.by); called by name, so the probe loads on pre261 too.
var _actors: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveTo.native = false
	Account.where = "user://probe_savereview3b_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_savereview3b_collection.json"
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
	_d43 = _builder.has_method("fold_own_since")  # callcheck: dynamic, d43save's tree when compared on one
	_actors = _builder.has_method("by_wait")
	Assistant.brickbench = false
	print("tree: %s" % ("actorstamp (a session's code keeps its own)" if _actors
		else "d43save (stamps steps)" if _d43 else "pre261 (no stamps)"))

	await _during_look("K1 Delete, 5 selected", 5, "delete")
	await _during_look("K2 C (paint), 620 selected", 620, "paint")
	# Working.attend says a command first, and runs it the frame after, once
	# it has cost 150 ms or more at this size (user://command_costs.json,
	# kept between visits): a paint of 20 on a model where paint was slow.
	Working.expected_ms("paint", 20)
	Working.costs["paint@%d" % Working._size_class(20)] = [400.0, 400.0]
	await _during_look("K3 C (paint), 20 selected, paint remembered slow", 20, "paint")
	Working.costs.erase("paint@%d" % Working._size_class(20))
	await _delete_during_save()
	await _undo_during_save()
	await _one_part_both()
	await _stamp_time()
	_quit()


# ---- K1-K3: the person's act while the chat's check_design looks -------------------


func _during_look(what: String, count: int, verb: String) -> void:
	var tag: String = what.left(2)
	print("\n%s while the chat's check_design looks; then the chat asks undo" % what)
	await _person_grid()
	var ids: Array = _select(count)
	var before: int = _world.brick_count()
	var mid: bool = await _act_during("check_design", {"name": "grid", "bricks": [
		{"part": "3005", "color": 1, "x": 0, "y": 0, "z": 0}]}, verb)
	var after: int = _world.brick_count()
	var red: int = _count_colour(ids, 4)
	print("    landed while the call was at work: %s; parts %d -> %d; red %d of %d; top %s" % [
		mid, before, after, red, ids.size(), _top()])
	var said: String = await _say("undo", {}, CHAT)
	print("    SAID: " + said.left(240).replace("\n", " "))
	print("    MEASURE %s: after the chat's undo parts %d (the person left %d), red %d (the person left %d)" % [
		tag, _world.brick_count(), after, _count_colour(ids, 4), red])
	_check("%s the person's act was kept while the call was at work" % tag, mid)
	if verb == "delete":
		_check("%s the chat's undo leaves the person's delete" % tag, _world.brick_count() == after
			and after == before - count)
	else:
		_check("%s the chat's undo leaves the person's paint" % tag, _count_colour(ids, 4) == red
			and red == count)


# ---- K4, K5: while the chat's save_model works -------------------------------------


func _delete_during_save() -> void:
	print("\nK4 Delete, 320 selected, while the chat's save_model works; then the chat asks undo")
	await _person_grid()
	_select(320)
	var before: int = _world.brick_count()
	var mid: bool = await _act_during("save_model", {"name": "sr3b grid"}, "delete")
	var after: int = _world.brick_count()
	print("    landed while the call was at work: %s; parts %d -> %d; top %s" % [mid, before, after, _top()])
	print("    the save said: " + _bg_said.left(240).replace("\n", " "))
	var said: String = await _say("undo", {}, CHAT)
	print("    SAID: " + said.left(240).replace("\n", " "))
	print("    MEASURE K4: mid %s; after the chat's undo parts %d (the person left %d)" % [
		mid, _world.brick_count(), after])
	_check("K4 the person's act was kept while the call was at work", mid)
	_check("K4 the chat's undo leaves the person's delete", _world.brick_count() == after
		and after == before - 320)


func _undo_during_save() -> void:
	print("\nK5 the person deletes 5 (Delete); while the chat's save_model works, the person's Ctrl+Z; then Ctrl+Y")
	await _person_grid()
	_select(5)
	var start: int = _world.brick_count()
	_key(KEY_DELETE)
	await _frames(8)
	var deleted: int = _world.brick_count()
	print("    parts %d -> %d by the person's Delete; top %s" % [start, deleted, _top()])
	var mid: bool = await _act_during("save_model", {"name": "sr3b k5"}, "undo")
	var undone: int = _world.brick_count()
	print("    the person's Ctrl+Z landed while the call was at work: %s; parts %d; top %s; redo %d" % [
		mid, undone, _top(), _builder._redo.size()])
	_key(KEY_Y, true)
	await _frames(8)
	var redone: int = _world.brick_count()
	print("    MEASURE K5 redo: after the person's Ctrl+Y parts %d (their redo makes it %d)" % [redone, deleted])
	_check("K5 the person's Ctrl+Z was made while the call was at work", mid and undone == start)
	_check("K5 the person's Ctrl+Y does their delete again", redone == deleted)
	# Back to where the person left it (their undo made, not their redo), for
	# the chat's undo.
	if redone != undone:
		_key(KEY_Z, true)
		await _frames(8)
	var left: int = _world.brick_count()
	var said: String = await _say("undo", {}, CHAT)
	print("    SAID: " + said.left(240).replace("\n", " "))
	print("    MEASURE K5 undo: after the chat's undo parts %d (the person left %d)" % [_world.brick_count(), left])
	_check("K5 the chat's undo leaves the person's own undo", _world.brick_count() == left)


## The person's [param verb] by its key while the chat's [param tool] is at
## work; whether the act's step was kept while the call was still at work.
func _act_during(tool: String, input: Dictionary, verb: String) -> bool:
	_bg_done = false
	_spawned(tool, input, CHAT)
	for _n: int in 600:
		if _bg_done or CommandSocket.at_work():
			break
		await process_frame
	if _bg_done:
		print("    the call ended before the person could act")
		return false
	var depth: int = _builder.history_depth()
	var count: int = _world.brick_count()
	var red: int = _count_colour(_builder.selection.keys(), 4)
	match verb:
		"delete":
			_key(KEY_DELETE)
		"paint":
			_key(KEY_C)
		"undo":
			_key(KEY_Z, true)
	var mid: bool = false
	for _n: int in 600:
		await process_frame
		var changed: bool = _builder.history_depth() != depth or _world.brick_count() != count \
			or _count_colour(_builder.selection.keys(), 4) != red
		if changed or _bg_done:
			mid = CommandSocket.at_work() and changed
			break
	for _n: int in 3000:
		if _bg_done:
			break
		await process_frame
	await _frames(3)
	return mid


# ---- K6: one part, the chat's step and the person's, in one call -----------------------


func _one_part_both() -> void:
	print("\nK6 in one call of the chat's: the chat paints a brick yellow, then the person paints it red")
	await _person_grid()
	var brick_id: int = int(_select(1)[0])
	_builder.clear_selection()
	var depth: int = _builder.history_depth()
	if _actors:
		# actorstamp: the chat's code keeps its paint as the chat's
		# (Builder.by, as CommandSocket._run runs a tool); the person's paint
		# is kept by no session's code; the call's end folds its own
		# (CommandSocket._one_step).
		_builder.call("by", CHAT, func() -> void: _builder.paint_brick(brick_id, 14))
		_builder.paint_brick(brick_id, 4)
		_builder.call("fold_since", depth, "", CHAT)
	elif _d43:
		_static("calls_at_work", int(_static("calls_at_work")) + 1)
		_static("call_chat", CHAT)
		_builder.paint_brick(brick_id, 14)
		_static("person_input", true)
		_builder.paint_brick(brick_id, 4)
		_static("person_input", false)
		_builder.call("fold_own_since", depth, CHAT)  # callcheck: dynamic, d43save's tree only
		_static("calls_at_work", int(_static("calls_at_work")) - 1)
		_static("call_chat", "")
	else:
		_builder.paint_brick(brick_id, 14)
		_builder.paint_brick(brick_id, 4)
		# pre261: the call's steps folded and the newest marked (_one_step, _mark).
		_builder.fold_since(depth)
		_builder.last_step()["by"] = CHAT
	print("    history after the call: %s" % _stamps(3))
	var said: String = await _say("undo", {}, CHAT)
	print("    SAID: " + said.left(240).replace("\n", " "))
	var after_chat: int = _world.get_brick(brick_id).color_code
	_key(KEY_Z, true)
	await _frames(8)
	var after_person: int = _world.get_brick(brick_id).color_code
	print("    MEASURE K6: colour after the chat's undo %d, after the person's Ctrl+Z then %d (1 blue as laid, 14 the chat's yellow, 4 the person's red)" % [
		after_chat, after_person])
	_check("K6 the chat's undo leaves the person's red", after_chat == 4)
	_check("K6 the person's Ctrl+Z never brings back the colour the chat took back", after_person != 14)


# ---- T: what the stamp costs ----------------------------------------------------


func _stamp_time() -> void:
	print("\nT a 6,000-part step kept as the person's, with the design's own 6,000")
	var assistant: Assistant = _main.get("_assistant")
	var ids := PackedInt64Array()
	var steps: Array = []
	for n: int in 6000:
		ids.append(1000000 + n)
		steps.append({"undo": "recolor", "brick": 1000000 + n, "color": 1})
	var times := PackedFloat64Array()
	for round: int in 5:
		assistant._placed_ids = ids.duplicate()
		var copy: Array = steps.duplicate(true)
		if _d43:
			_static("person_input", true)
		var from: int = Time.get_ticks_usec()
		_builder.record(copy, "probe: 6,000 recoloured")
		times.append((Time.get_ticks_usec() - from) / 1000.0)
		if _d43:
			_static("person_input", false)
		_builder._history.pop_back()
	assistant._placed_ids = PackedInt64Array()
	times.sort()
	print("    MEASURE T: record() of a 6,000-part step, ms over 5 rounds sorted %s (median %.2f)" % [
		times, times[2]])


# ---- the person's model and hands ----------------------------------------------


func _person_grid() -> void:
	await _say("clear_model", {}, CHAT)
	await _frames(2)
	_builder.clear_selection()
	var ids: Array = []
	for x: int in GRID:
		for z: int in GRID:
			ids.append(_world.add_brick("3005", 1, Transform3D(Basis(),
				Vector3(x * SPACE, 0, z * SPACE))))
	var steps: Array = []
	for brick_id: int in ids:
		steps.append({"undo": "remove", "brick": brick_id})
	_builder.record(steps, "laid %d bricks" % ids.size())
	await _frames(2)


## Builder's static [param name], read, or set to [param value]: by name, so
## the probe loads on pre261, which has none of them.
func _static(name: String, value: Variant = null) -> Variant:
	var script: Script = load("res://src/assembly/builder.gd")
	if value != null:
		script.set(name, value)
	return script.get(name)


func _select(count: int) -> Array:
	_builder.clear_selection()
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if ids.size() >= count:
			break
		if brick.part_id == "3005":
			ids.append(brick.id)
			_builder.selection[brick.id] = true
	_builder.selection_changed.emit(_builder.selection.size())
	_builder.held_color = 4
	return ids


func _count_colour(ids: Array, colour: int) -> int:
	var count: int = 0
	for brick_id: Variant in ids:
		var brick: BrickWorld.Brick = _world.get_brick(int(brick_id))
		if brick != null and brick.color_code == colour:
			count += 1
	return count


func _key(code: Key, ctrl: bool = false) -> void:
	root.gui_release_focus()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		event.pressed = pressed
		Input.parse_input_event(event)


func _top() -> String:
	return _stamps(1)


func _stamps(count: int) -> String:
	var out := PackedStringArray()
	var words: PackedStringArray = _builder.history_words(count, false)
	for k: int in mini(count, _builder.history_depth()):
		var step: Dictionary = _builder._history[_builder.history_depth() - 1 - k]
		out.append("\"%s\" by %s" % [words[k] if k < words.size() else "?", "the person"
			if bool(step.get("person", false)) else "\"%s\"" % str(step.get("by", "(unmarked)"))])
	return " | ".join(out) if not out.is_empty() else "(none)"


# ---- the harness (as savereview2_attack_probe's) ------------------------------


func _spawned(tool: String, arguments: Dictionary, chat: String) -> void:
	_bg_said = await _say(tool, arguments, chat)
	_bg_done = true


func _say(tool: String, arguments: Dictionary, chat: String) -> String:
	var said: String = await _one(tool, arguments, chat)
	var job := RegEx.create_from_string("^(Tab [^.]*\\. )?Started job (\\d+)")
	var found: RegExMatch = job.search(said)
	var polls: int = 0
	while found != null and polls < 120:
		said = await _one("job", {"id": int(found.get_string(2))}, chat)
		polls += 1
		if not said.contains("is still going"):
			break
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
	print("savereview3b_attack_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
