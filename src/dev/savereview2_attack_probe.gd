## savereview2: second review of d43save (save_model leaves out the design's
## own refused parts, only before a bench's write), run the same on pre261.
##
##   godot --headless --path . --script src/dev/savereview2_attack_probe.gd
##
## Driven through the app's own command socket, as the connector, Claude Code
## on the port (no chat) and the bench reach save_model and undo. Each line
## says what a person keeps. The trees are compared by their MEASURE lines and
## their checks, not by one tree's verdict.
##   P  saves that are not the bench: no chat, a second chat.
##   Q  a bench tab where a person also edits (a ?brickbench or ?held-out= link
##      opens one in a browser): what counts as "the design's own".
##   U  a chat's undo with the person's own edits between its steps.
##
## d43save2: a step is the person's when an input event of theirs made it
## (Builder.PERSON, set by Main as the window hears one), so each act of the
## person's here comes as one, through Input as the window's would, and is
## done in the input's handling (_as_person). Until then they were made by
## calls to the builder from the probe's own frames, which a call at work
## cannot be told from. U1's chat paints the frame's rails: the 2x4 bricks it
## laid were refused as loose, so "A stays" could not pass on any tree.
extends SceneTree

const CHAT := "probe-savereview2-chat"
const OTHER := "probe-savereview2-other"
const FRAME: Array = [
	{"part": "32525", "color": 0, "x": 0, "y": 2.5, "z": 0, "face": "+x", "rot": 0, "name": "left rail"},
	{"part": "32525", "color": 0, "x": 6, "y": 2.5, "z": 0, "face": "+x", "rot": 0, "name": "right rail"},
	{"part": "3737", "color": 0, "axis": "x", "x": 3.5, "y": 3.75, "z": 1.4},
	{"part": "3737", "color": 0, "axis": "x", "x": 3.5, "y": 3.75, "z": 9.4},
	{"part": "3482", "color": 71, "axis": "x", "x": -1, "y": 3.75, "z": 1.4},
	{"part": "3482", "color": 71, "axis": "x", "x": 8, "y": 3.75, "z": 1.4},
	{"part": "3482", "color": 71, "axis": "x", "x": -1, "y": 3.75, "z": 9.4},
	{"part": "3482", "color": 71, "axis": "x", "x": 8, "y": 3.75, "z": 9.4},
	{"part": "3483", "color": 0, "axis": "x", "x": -1, "y": 3.75, "z": 1.4},
	{"part": "3483", "color": 0, "axis": "x", "x": 8, "y": 3.75, "z": 1.4},
	{"part": "3483", "color": 0, "axis": "x", "x": -1, "y": 3.75, "z": 9.4},
	{"part": "3483", "color": 0, "axis": "x", "x": 8, "y": 3.75, "z": 9.4},
]

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0
var _written: PackedStringArray = PackedStringArray()
var _assistant: Assistant
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _verbs: EditVerbs
var _pid: int = 0
var _bg_said: String = ""
var _bg_done: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveTo.native = false
	Account.where = "user://probe_savereview2_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_savereview2_collection.json"
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
	_assistant = _main.get("_assistant")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_verbs = _main.get("_verbs")
	_pid = OS.get_process_id()
	Assistant.brickbench = false
	print("bench_run at start: %s" % CommandSocket.bench_run())

	await _paths_not_the_bench()
	await _bench_with_a_person()
	Assistant.brickbench = false
	await _undo_between()
	_quit()


# ---- P: saves that are not the bench --------------------------------------------


func _paths_not_the_bench() -> void:
	for arm: Array in [["P1 a session with no chat (Claude Code on the port)", ""],
			["P2 a second chat in the tab", OTHER]]:
		print("\n%s: one gear not held, it saves" % arm[0])
		await _frame_built()
		var gear: int = await _unheld_gear(-1.0)
		_check("%s: a gear the check finds not held, #%d" % [arm[0].left(2), gear], gear > 0)
		var parts: int = _world.brick_count()
		var file: String = "sr2-%s-%d.ldr" % [arm[0].left(2).to_lower(), _pid]
		_written.append(ModelStore.SAVE_DIR + file)
		var said: String = await _say("save_model", {"name": file}, str(arm[1]))
		var text: String = FileAccess.get_file_as_string(ModelStore.SAVE_DIR + file).to_lower()
		print("    SAID: " + said.left(400).replace("\n", " "))
		print("    MEASURE %s: file has the gear %s; model has it %s; parts %d -> %d; unsaved %s" % [
			arm[0].left(2), text.contains("3648b.dat"), _world.get_brick(gear) != null, parts,
			_world.brick_count(), _store.has_unsaved_work()])
		_check("%s keeps the gear on the model" % arm[0].left(2), _world.get_brick(gear) != null)
		_check("%s says no \"Saved without\"" % arm[0].left(2), not said.contains("Saved without"))


# ---- Q: a bench tab where a person edits too ------------------------------------


func _bench_with_a_person() -> void:
	Assistant.brickbench = true
	print("\nbench_run on a bench tab: %s" % CommandSocket.bench_run())

	# Q1: the AI's gear, which the person then moved (still not held).
	print("\nQ1 bench tab: the AI laid a gear, the person moved it")
	await _frame_built()
	var gear: int = await _unheld_gear(-1.0)
	var was: Transform3D = _world.get_brick(gear).transform
	var moved: int = gear
	await _as_person(func() -> void:
		_builder.put_at(moved, Transform3D(was.basis, was.origin + Vector3(-60, 0, 0)))
		_builder.record([{"undo": "move", "brick": moved, "transform": was}], "Move 24 tooth gear"))
	print("    after the person's move: %s" % await _fault_of(gear))
	await _bench_save("q1", gear, "the gear the person moved")

	# Q2: the AI's gear, which the person then painted.
	print("\nQ2 bench tab: the AI laid a gear, the person painted it red")
	await _frame_built()
	gear = await _unheld_gear(-1.0)
	var painted: int = gear
	await _as_person(func() -> void:
		_world.recolor_brick(painted, 4)
		_builder.record([{"undo": "recolor", "brick": painted, "color": 71}], "Paint 24 tooth gear"))
	print("    after the person's paint: %s" % await _fault_of(gear))
	await _bench_save("q2", gear, "the gear the person painted")

	# Q3: the person's own gear, laid by them, not held.
	print("\nQ3 bench tab: the person's own gear, not held")
	await _frame_built()
	var laid: Array = [0]
	await _as_person(func() -> void:
		laid[0] = _world.add_brick("3648b", 4, Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-60, 60, 100)))
		_builder.record([{"undo": "remove", "brick": laid[0]}], "Place 24 tooth gear"))
	gear = int(laid[0])
	print("    the person's gear: %s" % await _fault_of(gear))
	await _bench_save("q3", gear, "the person's own gear")

	# Q4: the person's own beam (not locked) collides with the AI's rail.
	print("\nQ4 bench tab: the person's own beam, not locked, collides with the AI's rail")
	await _frame_built()
	var rail: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "32525":
			rail = brick
	var beam: Array = [0]
	var at: Transform3D = Transform3D(rail.transform.basis, rail.transform.origin + Vector3(0, 0, 20))
	await _as_person(func() -> void:
		beam[0] = _world.add_brick("32525", 4, at)
		_builder.record([{"undo": "remove", "brick": beam[0]}], "Place beam"))
	var theirs: int = int(beam[0])
	print("    the person's beam: %s; the AI's rail #%d: %s" % [await _fault_of(theirs), rail.id,
		await _fault_of(rail.id)])
	var rail_id: int = rail.id
	await _bench_save("q4", theirs, "the person's own beam")
	print("    MEASURE q4: the AI's rail #%d on the model %s" % [rail_id, _world.get_brick(rail_id) != null])

	# Q5: the AI's gear, locked by the person.
	print("\nQ5 bench tab: the AI's gear, not held, locked by the person")
	await _frame_built()
	gear = await _unheld_gear(-1.0)
	_builder.locked[gear] = true
	await _bench_save("q5", gear, "the gear the person locked")
	_builder.locked.erase(gear)
	Assistant.brickbench = false


## A bench save; prints what the model and the file keep of [param watched].
func _bench_save(tag: String, watched: int, what: String) -> void:
	var parts: int = _world.brick_count()
	var depth: int = _builder.history_depth()
	var file: String = "sr2-%s-%d.ldr" % [tag, _pid]
	_written.append(ModelStore.SAVE_DIR + file)
	var said: String = await _say("save_model", {"name": file}, CHAT)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(ModelStore.SAVE_DIR + file)
	var text: String = bytes.get_string_from_utf8().to_lower()
	var kept: BrickWorld.Brick = _world.get_brick(watched)
	print("    SAID: " + said.left(700).replace("\n", "\n    "))
	print("    MEASURE %s: %s on the model %s; file written %s (%d bytes); file parts %d; model parts %d -> %d; history %d -> %d (%s)" % [
		tag, what, kept != null, bytes.size() > 0, bytes.size(), _file_parts(text), parts,
		_world.brick_count(), depth, _builder.history_depth(), _top_words()])
	_check("%s %s stays on the model" % [tag.to_upper(), what], kept != null)


static func _file_parts(text: String) -> int:
	var count: int = 0
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("1 ") and line.strip_edges().ends_with(".dat"):
			count += 1
	return count


# ---- U: a chat's undo with the person's own steps between -----------------------


func _undo_between() -> void:
	print("\nU1 chat paints A, the person lays P, chat paints B; the chat asks undo steps 3")
	await _frame_built()
	var rails: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "32525":
			rails.append(brick.id)
	var a: int = await _chat_paints(int(rails[0]), 4, CHAT)
	var p: int = await _person_lays(Vector3(600, 12, 600))
	var b: int = await _chat_paints(int(rails[1]), 1, CHAT)
	var said: String = await _say("undo", {"steps": 3}, CHAT)
	print("    SAID: " + said.left(400).replace("\n", " "))
	print("    MEASURE U1: A painted %s, P %s, B painted %s" % [_painted(a, 4), _has(p), _painted(b, 1)])
	_check("U1 the chat's B is undone", b > 0 and not _painted(b, 1))
	_check("U1 the person's P stays", _has(p))
	_check("U1 the chat's A, under the person's P, stays", _painted(a, 4))

	print("\nU2 the person takes back P with their Undo; the chat asks undo again")
	await _verbs.press("undo", true)
	print("    after the person's Undo: P %s" % _has(p))
	said = await _say("undo", {}, CHAT)
	print("    SAID: " + said.left(300).replace("\n", " "))
	print("    MEASURE U2: A painted %s, P %s" % [_painted(a, 4), _has(p)])
	_check("U2 the chat's own A is undone once the person's P is gone", a > 0 and not _painted(a, 4))
	_check("U2 the person's P, which they took back, stays back", not _has(p))

	print("\nU3 the person lays P2; a session with no chat asks undo")
	await _frame_built()
	var p2: int = await _person_lays(Vector3(600, 12, 600))
	said = await _say("undo", {}, "")
	print("    SAID: " + said.left(300).replace("\n", " "))
	print("    MEASURE U3: P2 %s" % _has(p2))
	_check("U3 a chat-less session's undo leaves the person's P2", _has(p2))

	print("\nU4 the person lays P3 and takes it back; the chat asks redo")
	await _frame_built()
	var p3: int = await _person_lays(Vector3(600, 12, 600))
	await _verbs.press("undo", true)
	said = await _say("undo", {"redo": true}, CHAT)
	print("    SAID: " + said.left(300).replace("\n", " "))
	print("    MEASURE U4: P3 %s (the person had taken it back)" % _has_part_at("3001", Vector3(600, 12, 600)))
	_check("U4 the chat's redo leaves the person's own undone P3 undone",
		not _has_part_at("3001", Vector3(600, 12, 600)))

	print("\nU5 the person lays P4 while the chat's save runs; the chat asks undo after")
	await _frame_built()
	var gear: int = await _unheld_gear(-1.0)
	var depth: int = _builder.history_depth()
	_bg_done = false
	_spawned("save_model", {"name": "sr2-u5-%d.ldr" % _pid}, CHAT)
	_written.append(ModelStore.SAVE_DIR + "sr2-u5-%d.ldr" % _pid)
	var mid: Array = [false]
	var p4: int = 0
	for _n: int in 600:
		if _bg_done:
			break
		if CommandSocket.at_work():
			# Heard at the next frame's input, as the window hears a click.
			p4 = await _person_lays(Vector3(600, 12, 600), mid)
			break
		await process_frame
	while not _bg_done:
		await process_frame
	print("    the person laid P4 mid-call: %s; history %d -> %d (%s)" % [mid[0], depth,
		_builder.history_depth(), _top_words()])
	if p4 == 0:
		print("    no frame of the save ran mid-call; P4 laid after it")
		p4 = await _person_lays(Vector3(600, 12, 600))
	said = await _say("undo", {}, CHAT)
	print("    SAID: " + said.left(300).replace("\n", " "))
	print("    MEASURE U5: P4 %s (laid mid-call %s); gear %s" % [_has(p4), mid[0], _has(gear)])
	_check("U5 the person laid P4 while the chat's save was at work", bool(mid[0]))
	_check("U5 the chat's undo after its save leaves the person's P4", _has(p4))


func _spawned(tool: String, arguments: Dictionary, chat: String) -> void:
	_bg_said = await _say(tool, arguments, chat)
	_bg_done = true


## The chat paints [param id] [param colour] with edit_model: one step of
## its own. Returns the part, 0 when it was not painted.
func _chat_paints(id: int, colour: int, chat: String) -> int:
	var said: String = await _say("edit_model", {"picture": false, "recolor": [{"bricks": [id],
		"color": colour}]}, chat)
	if not _painted(id, colour):
		print("    the chat's paint not made: " + said.left(200))
		return 0
	return id


func _painted(id: int, colour: int) -> bool:
	return id > 0 and _world.get_brick(id) != null and _world.get_brick(id).color_code == colour


## The person lays a 2x4 brick at [param at], by an input event of theirs
## ([method _as_person]); [param mid] gets whether a call was at work then.
func _person_lays(at: Vector3, mid: Array = []) -> int:
	var laid: Array = [0]
	await _as_person(func() -> void:
		if not mid.is_empty():
			mid[0] = CommandSocket.at_work()
		laid[0] = _world.add_brick("3001", 4, Transform3D(Basis(), at))
		_builder.record([{"undo": "remove", "brick": laid[0]}], "Place 2x4 brick"))
	return int(laid[0])


## Hears the probe's own input event, and does the person's act it carries
## there, as the window's controls do a click's.
class Hand extends Node:
	var act: Callable = Callable()

	func _input(event: InputEvent) -> void:
		var it: InputEventAction = event as InputEventAction
		if it != null and it.action == &"probe_person" and act.is_valid():
			var doing: Callable = act
			act = Callable()
			doing.call()
			get_viewport().set_input_as_handled()


var _hand: Hand = null


## [param act] done as the person does one: in the handling of an input event
## of theirs, which comes through Input as the window's would, at the start
## of the next frame (Main hears it first and marks what follows the person's).
func _as_person(act: Callable) -> void:
	if _hand == null:
		_hand = Hand.new()
		root.add_child(_hand)
	_hand.act = act
	var event := InputEventAction.new()
	event.action = &"probe_person"
	event.pressed = true
	Input.parse_input_event(event)
	for _n: int in 120:
		await process_frame
		if not _hand.act.is_valid():
			return
	print("    the person's input was never heard")


func _has(id: int) -> bool:
	return id > 0 and _world.get_brick(id) != null


func _has_part_at(part: String, at: Vector3) -> bool:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and brick.transform.origin.is_equal_approx(at):
			return true
	return false


# ---- the harness (as saved_without_attack_probe's) ------------------------------


func _frame_built() -> void:
	await _say("clear_model", {}, CHAT)
	var built: String = await _say("submit_design", {"name": "Frame", "description": "a frame",
		"floor": "none", "bricks": FRAME}, CHAT)
	if not built.begins_with("Built."):
		print("    frame not built: " + built.left(200))


func _unheld_gear(side: float) -> int:
	var base: float = 0.0 if side < 0 else 120.0
	var spots: Array = []
	for out: float in [6.0, 5.0, 4.5, 4.0, 3.5]:
		spots.append([Basis(Vector3.UP, PI / 2.0), Vector3(base + side * out, 60, 100)])
	for height: int in [48, 47, 46, 45, 44, 43, 42, 41, 40]:
		spots.append([Basis(Vector3.RIGHT, PI / 2.0), Vector3(base + 10 * -side, height, 100)])
	for spot: Array in spots:
		var tried: int = _world.add_brick("3648b", 71, Transform3D(spot[0], spot[1]))
		if tried <= 0:
			continue
		_assistant._placed_ids.append(tried)
		if await _fault_of(tried) == "not held":
			return tried
		_assistant._placed_ids.remove_at(_assistant._placed_ids.find(tried))
		_world.remove_brick(tried)
	return 0


func _fault_of(id: int) -> String:
	_assistant._strict_mine = true
	var model: Assistant.Model = _assistant._model_from_world()
	var report: Dictionary = await _assistant._checked(model, true)
	_assistant._strict_mine = false
	for index: int in model.placements.size():
		if (model.placements[index] as Assistant.Placement).id != id:
			continue
		if (report.get("unheld", []) as Array).has(index):
			return "not held"
		if (report.get("colliding", []) as Array).has(index):
			return "colliding (the later of its pair)"
		return "no fault the check names"
	return "not in the model"


func _top_words() -> String:
	if _builder.history_depth() == 0:
		return "(none)"
	var step: Dictionary = _builder.last_step()
	# The stamp's key read as a word, not Builder.persons, so this probe also
	# loads on pre261, where the step carries no stamp of the person's.
	return "\"%s\" by %s" % [_builder.history_words(1, false)[0], "the person"
		if bool(step.get("person", false)) else "\"%s\"" % str(step.get("by", "(unmarked)"))]


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
	for path: String in _written:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(CollectionStore.where)
	print("savereview2_attack_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
