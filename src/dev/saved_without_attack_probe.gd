## savereview: attacks on save_model leaving out a part the exact check refuses
## (d43save), run the same on pre261 to compare.
##
##   godot --headless --path . --script src/dev/saved_without_attack_probe.gd
##
## Driven through the app's own command socket, as a person's own Claude (the
## connector) and the bench both reach save_model. Each section prints what a
## person keeps: the parts on their baseplate after their Claude's save, what
## the file holds, what the answer says of it, and what undo takes back.
## A "FAIL" line is a person's part lost or a false word; the run's totals
## are compared between trees, not read as one tree's verdict.
extends SceneTree

const CHAT := "probe-savereview-chat"
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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveTo.native = false
	Account.where = "user://probe_savereview_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_savereview_collection.json"
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
	var pid: int = OS.get_process_id()

	# ---- A: a model with nothing refused, saved twice each way: bytes and time.
	Assistant.brickbench = false
	print("\nA. nothing refused: the file's bytes and the save's time")
	await _frame_built()
	var parts: int = _world.brick_count()
	for arm: String in ["connector", "bench"]:
		Assistant.brickbench = arm == "bench"
		for n: int in 2:
			var file: String = "sr-clean-%s-%d-%d.ldr" % [arm, n, pid]
			_written.append(ModelStore.SAVE_DIR + file)
			var began: int = Time.get_ticks_usec()
			var said: String = await _say("save_model", {"name": file})
			var ms: float = (Time.get_ticks_usec() - began) / 1000.0
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(ModelStore.SAVE_DIR + file)
			var text: String = bytes.get_string_from_utf8().replace(file.get_basename(), "NAME")
			print("    MEASURE clean %s #%d: %.0f ms, %d bytes, sha(name blanked) %s, said: %s" % [arm, n,
				ms, bytes.size(), text.sha256_text().left(16), said.left(110).replace("\n", " ")])
			_check("clean %s save keeps all %d parts on the baseplate" % [arm, parts],
				_world.brick_count() == parts and not said.contains("Saved without"))
	Assistant.brickbench = false

	# ---- B: a person's own Claude (the connector): one gear not held.
	print("\nB. connector: one gear not held, the person's Claude saves")
	await _frame_built()
	parts = _world.brick_count()
	var gear: int = await _unheld_gear(-1.0)
	_check("a gear the check finds not held, #%d" % gear, gear > 0)
	var gear_at: Transform3D = _world.get_brick(gear).transform if gear > 0 else Transform3D()
	var depth: int = _builder.history_depth()
	var file_b: String = "sr-b-%d.ldr" % pid
	_written.append(ModelStore.SAVE_DIR + file_b)
	var said_b: String = await _say("save_model", {"name": file_b})
	print("    SAID: " + said_b.left(600).replace("\n", "\n    "))
	var text_b: String = FileAccess.get_file_as_string(ModelStore.SAVE_DIR + file_b).to_lower()
	var file_has: bool = text_b.contains("3648b.dat")
	var world_has: bool = _world.get_brick(gear) != null
	print("    MEASURE B: file has the gear %s; baseplate has the gear %s; parts %d -> %d; history %d -> %d (%s); unsaved %s" % [
		file_has, world_has, parts + 1, _world.brick_count(), depth, _builder.history_depth(),
		_top_words(), _store.has_unsaved_work()])
	_check("B1 the person's model keeps the gear after their Claude's save", world_has)
	_check("B2 the answer says only what the file holds (no \"Saved without\" over a file that has it)",
		not (said_b.contains("Saved without") and file_has))
	_check("B3 a save leaves nothing unsaved", not _store.has_unsaved_work())
	# What the person's own Save then writes: the model's own file (Ctrl+S).
	var own: String = ModelStore.saved_path("sr-own-%d" % pid)
	_written.append(own)
	_store.save_file(own, "sr-own-%d" % pid)
	_check("B4 the person's next Save writes the gear", FileAccess.get_file_as_string(own)
		.to_lower().contains("3648b.dat"))

	# ---- C: undo order with the person's own edit after the save (B left it).
	print("\nC. the person places a part, then the session does as told (\"undo puts it back\")")
	var mine: int = _world.add_brick("3001", 4, Transform3D(Basis(), Vector3(300, 12, 300)))
	_builder.record([{"undo": "remove", "brick": mine}], "Place 2x4 brick")
	var undone: String = await _say("undo", {})
	print("    SAID: " + undone.left(300).replace("\n", " "))
	print("    MEASURE C: person's brick %s; gear %s" % [_world.get_brick(mine) != null,
		_world.get_brick(gear) != null])
	_check("C1 the session's undo leaves the person's own brick", _world.get_brick(mine) != null)
	# The person's own Undo then: theirs, and next the save's.
	var verbs: EditVerbs = _main.get("_verbs")
	while _world.get_brick(mine) != null and _builder.history_depth() > 0:
		await verbs.press("undo", true)
	if not world_has:
		await verbs.press("undo", true)
	var back: BrickWorld.Brick = _world.get_brick(gear)
	if back == null:
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id == "3648b":
				back = brick
	print("    MEASURE C: after the person's undos the gear is %s" % ("back" if back != null else "gone"))
	_check("C2 the gear stands where it was, in its colour", back != null
		and back.transform.is_equal_approx(gear_at) and back.color_code == 71)

	# ---- D: a person's own part, which their Claude's part collides with, locked.
	print("\nD. connector: the person's own locked beam collides with Claude's rail")
	await _frame_built()
	parts = _world.brick_count()
	var rail: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "32525":
			rail = brick
	var theirs: int = _world.add_brick("32525", 4, Transform3D(rail.transform.basis,
		rail.transform.origin + Vector3(0, 0, 20)))
	_builder.record([{"undo": "remove", "brick": theirs}], "Place beam")
	_builder.locked[theirs] = true
	print("    the person's beam: %s; Claude's rail: %s" % [await _fault_of(theirs), await _fault_of(rail.id)])
	var file_d: String = "sr-d-%d.ldr" % pid
	_written.append(ModelStore.SAVE_DIR + file_d)
	var said_d: String = await _say("save_model", {"name": file_d})
	print("    SAID: " + said_d.left(500).replace("\n", "\n    "))
	print("    MEASURE D: person's locked beam on the baseplate %s; parts %d -> %d; top step %s" % [
		_world.get_brick(theirs) != null, parts + 1, _world.brick_count(), _top_words()])
	_check("D1 the person's own locked part stays after their Claude's save", _world.get_brick(theirs) != null)
	_builder.locked.erase(theirs)

	# ---- E: the bench: two gears not held and one colliding part. All named, one undo.
	print("\nE. bench: two gears not held and a colliding part")
	Assistant.brickbench = true
	await _frame_built()
	parts = _world.brick_count()
	var g1: int = await _unheld_gear(-1.0)
	var g2: int = await _unheld_gear(1.0)
	_check("two gears not held, #%d and #%d" % [g1, g2], g1 > 0 and g2 > 0)
	var before_e: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		before_e[brick.id] = [brick.part_id, brick.color_code, brick.transform]
	var file_e: String = "sr-e-%d.ldr" % pid
	_written.append(ModelStore.SAVE_DIR + file_e)
	var said_e: String = await _say("save_model", {"name": file_e})
	print("    SAID: " + said_e.left(700).replace("\n", "\n    "))
	var text_e: String = FileAccess.get_file_as_string(ModelStore.SAVE_DIR + file_e).to_lower()
	print("    MEASURE E: gears in file %d; parts %d -> %d" % [text_e.count("3648b.dat"),
		before_e.size(), _world.brick_count()])
	if g1 > 0 and g2 > 0 and said_e.contains("Saved without"):
		_check("E1 the answer names both gears", said_e.contains(str(g1)) and said_e.contains(str(g2)))
		var undone_e: String = await _say("undo", {})
		var same: bool = _world.brick_count() == before_e.size()
		for id: Variant in before_e:
			var brick: BrickWorld.Brick = _world.get_brick(int(id))
			var was: Array = before_e[id]
			if brick == null:
				for other: BrickWorld.Brick in _world.bricks():
					if other.part_id == was[0] and other.transform.is_equal_approx(was[2]):
						brick = other
			same = same and brick != null and brick.color_code == int(was[1]) \
				and brick.transform.is_equal_approx(was[2])
		print("    undo: " + undone_e.left(160).replace("\n", " "))
		_check("E2 one undo puts every part back exactly", same)
	Assistant.brickbench = false
	_quit()


## The frame, submitted afresh by the session.
func _frame_built() -> void:
	await _say("clear_model", {})
	var built: String = await _say("submit_design", {"name": "Frame", "description": "a frame",
		"floor": "none", "bricks": FRAME})
	if not built.begins_with("Built."):
		print("    frame not built: " + built.left(200))


## A 24-tooth gear the session placed where the exact check finds it not held,
## beside the left rail ([param side] -1) or the right (+1). 0 if none found.
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
		return "no fault of its own"
	return "not in the model"


func _top_words() -> String:
	if _builder.history_depth() == 0:
		return "(none)"
	return "\"%s\" by %s" % [_builder.history_words(1, false)[0],
		str(_builder.last_step().get("by", "the person"))]


func _say(tool: String, arguments: Dictionary) -> String:
	var said: String = await _one(tool, arguments)
	var job := RegEx.create_from_string("^(Tab [^.]*\\. )?Started job (\\d+)")
	var found: RegExMatch = job.search(said)
	var polls: int = 0
	while found != null and polls < 120:
		said = await _one("job", {"id": int(found.get_string(2))})
		polls += 1
		if not said.contains("is still going"):
			break
	return said


func _one(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments,
			"_meta": {CommandSocket.CHAT_KEY: {"chat": CHAT}}}})
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
	print("saved_without_attack_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
