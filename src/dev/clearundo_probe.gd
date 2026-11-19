## Does an undo of a step that laid the floor again give the model back
## exactly: the same parts, the same floor (its plates where they lay, not
## one more), the same file on save byte for byte? And its redo the step
## again, and a second undo the model again?
##
##   godot --headless --path . --script src/dev/clearundo_probe.gd
##
## smalls6 item 3 (found by hpfix, older than hubprogram): an undo of a kept
## Clear gave back "15 parts of 14", the model's own parts and two baseplates
## under them (hpreview_a1.log 474). The model is hubprogram's arm, which
## stands on "0 !BRICKWORKS FLOOR BASEPLATE 32 32 288". The steps that lay
## the floor again: a kept Clear (Main.clear_model(true), as a session's is),
## a session's clear_model over MCP, its set_floor (another kind, another
## size), File › New and an open over the model, each undone (and redone).
extends SceneTree

const FIX := "res://src/dev/fixtures/hubprogram/arm_program.ldr"
const ARM := "Clear Undo Arm"
const OTHER := "Clear Undo Other"

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _world: BrickWorld
var _builder: Builder
var _bar: ModelBar
var _verbs: EditVerbs
var _tools: AppTools
var _socket: Object
var _rpc_id: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_store = _main.get("_store")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_bar = _main.get("_bar")
	_verbs = _main.get("_verbs")
	_store.keeps = true
	_tools = AppTools.new()
	_tools.app = _main
	_tools.assistant = _main.get("_assistant")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var fix: String = FileAccess.get_file_as_string(FIX)
	_write(ModelStore.saved_path(ARM), fix)
	_write(ModelStore.saved_path(OTHER), fix.replace("1 71 0 -24 50", "1 4 0 -24 50"))

	print("\na kept Clear (Main.clear_model(true)), undone by the keys")
	await _case(func() -> void: _main.call("clear_model", true, "probe's clear"), _by_keys)
	print("\na session's clear_model over MCP, undone by its undo")
	await _case(func() -> void: await _rpc("clear_model", {}), _by_tool)
	print("\na session's set_floor to the grid, undone by the keys")
	await _case(func() -> void: await _rpc("set_floor", {"kind": "grid"}), _by_keys)
	print("\na session's set_floor to a 48 x 48 plate, undone by its undo")
	await _case(func() -> void: await _rpc("set_floor", {"across": 48}), _by_tool)
	print("\nset_floor to no floor, then a 16 x 16 plate, both undone")
	await _case(func() -> void:
		await _rpc("set_floor", {"kind": "none"})
		await _rpc("set_floor", {"across": 16}), _by_keys, 2)
	print("\nthe baseplate made part of the model, then a session's clear_model, undone")
	await _case(func() -> void: await _rpc("clear_model", {}), _by_keys, 1,
		func() -> void: await _rpc("set_floor", {"part_of_model": true}))
	print("\nanother model opened over it (File › Open), undone by the keys")
	await _case(func() -> void:
		await _bar.open_with_progress(ModelStore.saved_path(OTHER))
		_bar.opened.emit(_world.brick_count() - _store.scenery.size()), _by_keys)
	print("\nFile › New over it, saved: what Undo does")
	await _new_case()
	_forget(ARM)
	_forget(OTHER)
	print("")
	if _failures == 0:
		print("every step that lays the floor again comes back whole: the same parts, the same floor, the same file")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## The arm opened from its file (and [param setup] done to it); [param step]
## done to it, then undone [param steps] times by [param undo], redone as many
## and undone again.
func _case(step: Callable, undo: Callable, steps: int = 1, setup: Callable = Callable()) -> void:
	await _open_arm()
	if setup.is_valid():
		await setup.call()
		await _settle()
	var was: Dictionary = _state()
	_note("opened: %s" % _said(was))
	await step.call()
	await _settle()
	var done: Dictionary = _state()
	_note("done: %s" % _said(done))
	_check("the step changed the model or its floor (%s)" % _said(done), not _same(done, was))
	for _n: int in steps:
		await undo.call(false)
	var back: Dictionary = _state()
	_compare("undo", back, was)
	for _n: int in steps:
		await undo.call(true)
	var again: Dictionary = _state()
	_compare("redo", again, done)
	for _n: int in steps:
		await undo.call(false)
	_compare("undo again", _state(), was)


## File › New over the arm as saved asks nothing; Undo is said either way.
func _new_case() -> void:
	await _open_arm()
	var was: Dictionary = _state()
	_bar.ask_for_new()
	await _settle()
	var fresh: Dictionary = _state()
	_note("new: %s" % _said(fresh))
	_check("New: a bare floor of its own, one plate (%s)" % _said(fresh),
		int(fresh["own"]) == 0 and int(fresh["scenery"]) == int(fresh["count"]))
	if _main.get("_shell").can("undo"):
		await _by_keys(false)
		_compare("New, then Undo", _state(), was)
	else:
		_note("New is not undone (nothing to undo); the arm is in its file as it was: %s"
			% (FileAccess.get_file_as_string(ModelStore.saved_path(ARM)) == str(was["file"])))


func _compare(what: String, now: Dictionary, wanted: Dictionary) -> void:
	_check("%s: %d parts of %d, %d of them the floor of %d (%s), the model's own %d of %d" % [what,
		now["count"], wanted["count"], now["scenery"], wanted["scenery"], now["floor"],
		now["own"], wanted["own"]],
		now["count"] == wanted["count"] and now["scenery"] == wanted["scenery"]
		and now["own"] == wanted["own"] and now["floor"] == wanted["floor"])
	_check("%s: the floor's plates where they lay (%s)" % [what, " ".join(now["plates"])],
		now["plates"] == wanted["plates"])
	_check("%s: the model's parts where they stood" % what, now["parts"] == wanted["parts"])
	_check("%s: Save writes the same file byte for byte (%s), named %s" % [what,
		"same" if now["saved"] == wanted["saved"] else _first_difference(now["saved"], wanted["saved"]),
		now["title"]], now["saved"] == wanted["saved"] and now["title"] == wanted["title"])


func _state() -> Dictionary:
	var plates := PackedStringArray()
	var parts := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		var o: Vector3 = brick.transform.origin
		var key: String = "%s|%d|%.1f,%.1f,%.1f" % [brick.part_id, brick.color_code, o.x, o.y, o.z]
		if _store.scenery.has(brick.id):
			plates.append(key)
		else:
			parts.append(key)
	plates.sort()
	parts.sort()
	return {"count": _world.brick_count(), "scenery": _store.scenery.size(),
		"own": _world.brick_count() - _store.scenery.size(),
		"floor": _store.model_floor.whole_words(), "plates": plates, "parts": parts,
		"saved": _store.saved_text(), "title": _store.title,
		"file": FileAccess.get_file_as_string(ModelStore.saved_path(ARM))}


func _same(a: Dictionary, b: Dictionary) -> bool:
	return a["count"] == b["count"] and a["floor"] == b["floor"] and a["plates"] == b["plates"] \
		and a["parts"] == b["parts"] and a["saved"] == b["saved"]


static func _said(state: Dictionary) -> String:
	return "%d parts, %d the floor (%s), %s" % [state["count"], state["scenery"], state["floor"],
		state["title"]]


func _open_arm() -> void:
	_write(ModelStore.saved_path(ARM), FileAccess.get_file_as_string(FIX))
	await _bar.open_with_progress(ModelStore.saved_path(ARM))
	_bar.opened.emit(_world.brick_count() - _store.scenery.size())
	await _settle()


func _by_keys(again: bool) -> void:
	await _verbs.press("redo" if again else "undo")
	await _settle()


func _by_tool(again: bool) -> void:
	var said: String = await _rpc("undo", {"redo": true} if again else {})
	_note("undo%s: %s" % [" redo=true" if again else "", said.left(120)])


func _rpc(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	if text.is_empty() and (answer as Dictionary).has("error"):
		text = str((answer as Dictionary)["error"])
	await _settle()
	return text


func _settle() -> void:
	for _n: int in 40:
		if not _store.laying and _store.awaited.is_empty():
			break
		await process_frame
	for _n: int in 6:
		await process_frame


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _forget(name: String) -> void:
	if FileAccess.file_exists(ModelStore.saved_path(name)):
		DirAccess.remove_absolute(ModelStore.saved_path(name))


static func _first_difference(a: String, b: String) -> String:
	var n: int = 0
	while n < mini(a.length(), b.length()) and a[n] == b[n]:
		n += 1
	return "differ at %d of %d/%d: %s | %s" % [n, a.length(), b.length(), a.substr(maxi(n - 20, 0), 60).c_escape(),
		b.substr(maxi(n - 20, 0), 60).c_escape()]


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _note(what: String) -> void:
	print("  note  %s" % what)
