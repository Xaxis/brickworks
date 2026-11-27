## savereview6: attacks on windowstep's ledgers (a run's or a call's step is
## what its own code noted, inside Builder.by, as the maker it names). Run the
## same on pre261, whose step was the model's difference over the run.
##
##   godot --headless --path . --script src/dev/savereview6_attack_probe.gd -- --sr6=skc,skp,stop
##
##   skc  the person's panel asks for three sketches (Sketch first); their Claude
##        chat picks one with choose_sketch; the panel designs the whole model
##        from it. Is every part of that design in a step, and does Undo take it?
##   skp  the same with the person pressing the sketch's card (the control)
##   stop the person's panel design stopped (Stop) while it is being laid
## Judged by the person's Ctrl+Z: every part the run put down is in a step, and
## undoing to the person's own grid leaves the grid and nothing else.
## Ports 13105-13109 (savereview6's).
extends SceneTree

const CHAT := "probe-savereview6-chat"
const SPACE := 40.0
const FIXTURE := "res://tests/fixtures/sketches/lighthouse.json"

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _assistant: Assistant
var _api: _Api
var _ended: Array = []
var _grid: Array = []


## A stand-in for the Messages API (savereview5's): each POST answered with the
## next reply written here, and "Done." once they run out.
class _Api extends Node:
	var replies: Array = []
	var asked: int = 0
	var port: int = 0
	var _server := TCPServer.new()
	var _peers: Array = []

	func _init() -> void:
		for wanted: int in range(13105, 13110):
			if _server.listen(wanted, "127.0.0.1") == OK:
				port = wanted
				return

	func _process(_delta: float) -> void:
		while _server.is_connection_available():
			_peers.append([_server.take_connection(), PackedByteArray()])
		for held: Array in _peers.duplicate():
			var peer: StreamPeerTCP = held[0]
			peer.poll()
			if peer.get_available_bytes() > 0:
				held[1] = (held[1] as PackedByteArray) \
					+ (peer.get_data(peer.get_available_bytes())[1] as PackedByteArray)
			var got: PackedByteArray = held[1]
			var text: String = got.get_string_from_utf8()
			var cut: int = text.find("\r\n\r\n")
			if cut < 0:
				continue
			var length: RegExMatch = RegEx.create_from_string("(?i)content-length: *(\\d+)") \
				.search(text.left(cut))
			if length != null and got.size() < cut + 4 + int(length.get_string(1)):
				continue
			asked += 1
			var reply: Dictionary = replies.pop_front() if not replies.is_empty() \
				else {"content": [{"type": "text", "text": "Done."}], "stop_reason": "end_turn"}
			var bytes: PackedByteArray = JSON.stringify(reply).to_utf8_buffer()
			peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
				+ "Content-Length: %d\r\nConnection: close\r\n\r\n" % bytes.size()).to_utf8_buffer())
			peer.put_data(bytes)
			peer.disconnect_from_host()
			_peers.erase(held)

	func _exit_tree() -> void:
		_server.stop()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveTo.native = false
	Account.where = "user://probe_savereview6_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_savereview6_collection.json"
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
	_assistant = _main.get("_assistant")
	Assistant.brickbench = false
	print("tree: %s" % ("windowstep" if _world.has_method("open_ledger") else "pre261"))
	_api = _Api.new()
	root.add_child(_api)
	_assistant.endpoint = "http://127.0.0.1:%d/v1/messages" % _api.port
	_assistant.stream_replies = false
	# A key for this run only, written nowhere, sent nowhere but the stand-in.
	OwnKey._this_visit = "sk-ant-probe-savereview6-000000000000000000000000000000"
	_assistant.finished.connect(func(ok: bool, summary: String) -> void: _ended.append([ok, summary]))
	var parts: PackedStringArray = PackedStringArray(["skc", "skp", "stop"])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sr6="):
			parts = arg.trim_prefix("--sr6=").split(",")
	for part: String in parts:
		match part:
			"skc":
				await _sketched("SKC", true)
			"skp":
				await _sketched("SKP", false)
			"skb":
				await _sketched("SKB", true, true)
			"skbp":
				await _sketched("SKBP", false, true)
			"stop":
				await _stopped("STOP")
			"ord":
				await _order("ORD", false)
				await _order("ORDP", true)
			"skw":
				await _sketched("SKW", true, false, true)
			"skf":
				await _sketched("SKF", true, false, false, true)
	_quit()


## A chat's edit_model taking off, moving and painting parts named out of
## order, then its undo ([param person]: the person's Ctrl+Z): the model as it
## was, and saved, the same bytes as before the edit.
func _order(tag: String, person: bool) -> void:
	print("\n%s a chat's edit_model takes off, moves and paints parts named out of order; %s; saved" % [tag,
		"the person's Ctrl+Z" if person else "the chat's undo"])
	await _person_grid(4)
	var name: String = "sr6 order %s" % tag
	var first: String = await _one("save_model", {"name": name}, CHAT)
	var path: String = _saved_path(first)
	var before: String = FileAccess.get_file_as_string(path)
	var snap: PackedStringArray = _snap()
	print("    saved %s (%d bytes, %d parts)" % [path.get_file(), before.length(), _world.brick_count()])
	var g: Array = _grid
	var said: String = await _one("edit_model", {"remove": [g[13], g[2], g[9], g[5]],
		"move": [{"bricks": [g[11], g[0]], "dx": 0, "dy": 0, "dz": 8}],
		"recolor": [{"bricks": [g[14], g[3], g[7]], "color": 4}]}, CHAT)
	print("    the chat's edit: %s" % said.left(120).replace("\n", " "))
	await _frames(10)
	if not _check("%s the chat's edit landed" % tag, _snap() != snap):
		return
	if person:
		(_main.get("_verbs") as EditVerbs).own_undo()
		await _frames(10)
	else:
		said = await _one("undo", {}, CHAT)
		print("    the chat's undo: %s" % said.left(120).replace("\n", " "))
		await _frames(10)
	var back: PackedStringArray = _snap()
	var off: int = 0
	for line: String in snap:
		if not back.has(line):
			off += 1
			print("      before, not after: %s" % line)
	for line: String in back:
		if not snap.has(line):
			print("      after, not before: %s" % line)
	_check("%s the undo puts every part back where and as it was (%d off, %d vs %d parts)" % [tag, off,
		back.size(), snap.size()], off == 0 and back.size() == snap.size())
	var again: String = await _one("save_model", {"name": name}, CHAT)
	var after: String = FileAccess.get_file_as_string(_saved_path(again))
	if after != before:
		var a: PackedStringArray = before.split("\n")
		var b: PackedStringArray = after.split("\n")
		for k: int in mini(a.size(), b.size()):
			if a[k] != b[k]:
				print("    first change, line %d:\n      before %s\n      after  %s" % [k + 1, a[k], b[k]])
				break
	_check("%s saved again, byte for byte the save before the edit (%d bytes vs %d): %s" % [tag,
		after.length(), before.length(), again.left(60).replace("\n", " ")], after == before)


func _saved_path(said: String) -> String:
	var found: RegExMatch = RegEx.create_from_string("\\(([^()]*\\.ldr)\\)").search(said)
	return found.get_string(1) if found != null else ""


## The model, part for part: part, colour, place and step of each, sorted.
func _snap() -> PackedStringArray:
	var out := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		var o: Vector3 = brick.transform.origin
		out.append("%s|%d|%.1f,%.1f,%.1f|%s|%s|%d" % [brick.part_id, brick.color_code, o.x, o.y, o.z,
			brick.group, brick.unit, brick.step])
	out.sort()
	return out


## The person's own grid of blue 1x1s, laid by them (one step of theirs).
func _person_grid(side: int) -> void:
	_main.call("clear_model")
	await _frames(3)
	_builder.forget_history()
	_builder.clear_selection()
	_grid = []
	for x: int in side:
		for z: int in side:
			_grid.append(_world.add_brick("3005", 1, Transform3D(Basis(),
				Vector3(-800 - x * SPACE, 24, -800 - z * SPACE))))
	var steps: Array = []
	for brick_id: int in _grid:
		steps.append({"undo": "remove", "brick": brick_id})
	_builder.record(steps, "laid %d bricks" % _grid.size())
	await _frames(3)


func _tool(input: Dictionary) -> Dictionary:
	return {"type": "tool_use", "id": "toolu_sr6_%d" % randi(), "name": "submit_design", "input": input}


## Sketch first in the panel, three sketches, one chosen ([param by_chat]: by
## the person's Claude chat over choose_sketch; else the person's card), the
## whole model designed from it.
func _sketched(tag: String, by_chat: bool, big: bool = false, waited: bool = false,
		fetched: bool = false) -> void:
	print("\n%s the person's panel sketches three; %s chooses the second%s%s%s; the panel designs from it" % [tag,
		"their Claude chat (choose_sketch)" if by_chat else "the person (the card)",
		", a 144-part slab" if big else "",
		", the chat's choice going on after a frame (as putting the sketch down does when its slice"
			+ " is spent, a slow page)" if waited else "",
		", over the socket, one of its parts fetched first (as on the web)" if fetched else ""])
	var recorded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var sketches: Array = recorded["sketches"]
	if big:
		# The second a slab of 144 2 x 4s: putting it down takes more than a
		# frame's slice (FramePace), so choose_sketch waits before the design
		# from it begins (Assistant._start reads whose the run is there).
		var slab: Array = []
		for x: int in 12:
			for z: int in 12:
				slab.append({"part": "3001", "color": 71, "x": x * 4 + 2, "y": 0, "z": z * 2 + 1, "rot": 0})
		sketches[1] = {"name": "A low grey slab", "description": "A wide low slab, the base is the idea.",
			"bricks": slab}
	await _person_grid(3)
	_assistant.forget_built()
	_assistant.forget_conversation()
	_main.set("_sample_untouched", false)
	_ended.clear()
	_api.replies = [
		{"content": [_tool(sketches[0]), _tool(sketches[1]), _tool(sketches[2])], "stop_reason": "tool_use"},
		{"content": [_tool(recorded["full"])], "stop_reason": "tool_use"},
	]
	var chat: ChatPanel = _main.get("_chat")
	chat._show_for_key(true)
	chat._sketch_first.visible = true
	chat._sketch_first.button_pressed = true
	chat._input.text = str(recorded["brief"])
	chat._on_send()
	print("    the sketch round began: %s" % _assistant.is_busy())
	for _n: int in 6000:
		if _assistant.held_sketches().size() == 3 and not _assistant.is_busy():
			break
		await process_frame
	print("    sketches held: %d, busy %s, asked %d" % [_assistant.held_sketches().size(), _assistant.is_busy(),
		_api.asked])
	if _assistant.held_sketches().size() != 3:
		_check("%s three sketches to choose from" % tag, false)
		return
	_ended.clear()
	if fetched:
		# The sketch's 6 x 8 plate not in this build yet, as a part is on the
		# web until it is fetched: choose_sketch waits for it a frame
		# (Assistant._ensure_parts), and it arrives as the wait begins.
		var library: PartLibrary = _assistant.get("library")
		var info: PartLibrary.PartInfo = library.parts.get("3036")
		var real_hash: String = info.mesh_hash
		info.mesh_hash = "sr6-on-its-way-" + real_hash
		_assistant.progress.connect(func(text: String) -> void:
			if text.begins_with("fetching") and info.mesh_hash != real_hash:
				print("    the chat's choose_sketch waits: %s" % text)
				info.mesh_hash = real_hash)
	if by_chat and waited:
		# The chat's choose_sketch as the socket runs it (Assistant._tool_answer
		# hands choose_sketch the chat as by), past its first wait: what follows
		# a wait runs as nobody's (Builder.by_wait), as Assistant._start does
		# once Assistant._apply has given a frame back.
		var said: String = await Builder.by_wait(CHAT, func() -> Variant:
			await process_frame
			return await _assistant.choose_sketch(2, CHAT))
		print("    the chat's choose_sketch: %s" % str(said).left(160).replace("\n", " "))
	elif by_chat:
		var said: String = await _one("choose_sketch", {"sketch": 2}, CHAT)
		print("    the chat's choose_sketch: %s" % said.left(160).replace("\n", " "))
	if by_chat:
		var mark: Dictionary = _assistant.get("_run_mark")
		print("    the run is whose: _run_by \"%s\"; its mark's maker \"%s\"" % [str(_assistant.get("_run_by")),
			str((mark["ledger"] as Object).get("by")) if mark.has("ledger") else "(pre261: no ledger)"])
	else:
		chat._sketch_buttons[1].pressed.emit()
	var until: int = Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < until:
		if not _ended.is_empty() and not _assistant.is_busy():
			break
		await process_frame
	await _frames(30)
	print("    the run ended: %s; asked %d" % [str(_ended.back()) if not _ended.is_empty() else "never",
		_api.asked])
	await _judge(tag)


## The person's panel design of a 600-part lot, stopped while it is laid.
func _stopped(tag: String) -> void:
	print("\n%s the person's panel design of 576 red bricks, stopped (Stop) while it is laid" % tag)
	await _person_grid(3)
	_assistant.forget_built()
	_assistant.forget_conversation()
	_main.set("_sample_untouched", false)
	_ended.clear()
	var bricks: Array = []
	for x: int in 24:
		for z: int in 24:
			bricks.append({"part": "3001", "color": 4, "x": x * 4 + 2, "y": 0, "z": z * 2 + 1})
	_api.replies = [{"content": [{"type": "tool_use", "id": "toolu_sr6_stop", "name": "submit_design",
		"input": {"name": "Lot", "description": "a flat red lot, a slab", "floor": "none",
			"bricks": bricks}}], "stop_reason": "tool_use"}]
	var chat: ChatPanel = _main.get("_chat")
	chat._sketch_first.button_pressed = false
	chat._input.text = "a flat red lot"
	chat._on_send()
	var until: int = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < until and _count_not_grid() < 100:
		await process_frame
	print("    %d of its parts down; Stop" % _count_not_grid())
	_assistant.cancel()
	await _frames(30)
	print("    the run ended: %s" % [str(_ended.back()) if not _ended.is_empty() else "never"])
	await _judge(tag)


## Every part standing that is not the person's grid is in some step; whose;
## then the person's Ctrl+Z down to their grid leaves the grid alone.
func _judge(tag: String) -> void:
	var holding: int = 0
	for step: Dictionary in _builder.steps_now()[0]:
		var by: String = str(step.get("by", ""))
		var laid: int = _lays(step)
		print("    history: \"%s\" by %s%s" % [str(step.get("words", step.get("undo", "?"))).left(90),
			"\"%s\"" % by if not by.is_empty() else "the person", (", lays %d of the run's parts" % laid)
			if laid > 0 else ""])
		holding += laid
	var standing: int = _count_not_grid()
	print("    MEASURE %s: %d of the run's parts stand, %d of them in some step" % [tag, standing, holding])
	_check("%s every part the run put down is in a step, so an undo takes it (%d of %d)" % [tag, holding,
		standing], holding >= standing)
	var verbs: EditVerbs = _main.get("_verbs")
	var undone := PackedStringArray()
	for _n: int in 8:
		var words: Array = _builder.history_words(1)
		if words.is_empty() or str(words[0]).begins_with("laid 9"):
			break
		undone.append(str(words[0]).left(60))
		verbs.own_undo()
		await _frames(10)
	print("    the person's Ctrl+Z: %s" % " || ".join(undone))
	var grid_left: int = 0
	for brick_id: int in _grid:
		if _world.get_brick(brick_id) != null:
			grid_left += 1
	print("    MEASURE %s: after Ctrl+Z to the grid, %d of the run's parts stand, %d of 9 of the grid" % [tag,
		_count_not_grid(), grid_left])
	_check("%s the person's Ctrl+Z to their grid leaves none of the run's parts (%d left)" % [tag,
		_count_not_grid()], _count_not_grid() == 0)
	_check("%s ...and the grid whole (%d of 9)" % [tag, grid_left], grid_left == 9)


func _count_not_grid() -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not _grid.has(brick.id) and not _store.scenery.has(brick.id):
			count += 1
	return count


## How many parts not of the grid the step [param step] put down.
func _lays(step: Dictionary) -> int:
	var count: int = 0
	if str(step.get("undo", "")) == "remove":
		var brick_id: int = int(step.get("brick", 0))
		if _world.get_brick(brick_id) != null and not _grid.has(brick_id) \
				and not _store.scenery.has(brick_id):
			count += 1
	for inner: Variant in step.get("steps", []):
		if inner is Dictionary:
			count += _lays(inner)
	return count


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
	if _world != null and _world.has_method("open_ledger"):
		var open: Array = _world.get("_ledgers")
		var whose := PackedStringArray()
		for ledger: Object in open:
			whose.append("%s (%d parts)" % [str(ledger.get("by")), (ledger.get("was") as Dictionary).size()])
		print("    ledgers still open at the end: %d %s" % [open.size(), ", ".join(whose)])
		_check("no ledger left open once every run and call has ended (%d)" % open.size(), open.is_empty())
	print("savereview6_attack_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
