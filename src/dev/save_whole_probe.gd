## A bench's save never loses the model to one part (design43).
##
##   godot --headless --path . --script src/dev/save_whole_probe.gd
##
## design42's 42061 telehandler: 45 minutes, 138 parts, and the bench's own
## save at the session's end was refused over one Technic gear not held, so
## the session left no model at all. In a bench run (Assistant.brickbench, as
## DesignMemory.holding() is in realset) saving waited on the exact check.
## Now the parts at fault are taken off as one edit, everything else is
## written, and the answer names each part.
##
## Driven through the app's own command socket, the way the bench's save and
## a session's are: a beam frame on wheels is built, then a gear is put on it
## where the exact check finds it at fault, nothing holding it (straight into
## the world, as a part left behind when what held it was taken away is), and
## save_model is asked. A gear alone in the air is not this: it is a piece of
## its own, which the BrickBench pieces gate refuses twice and then saves.
extends SceneTree

const CHAT := "probe-save-whole-chat"
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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveTo.native = false
	Account.where = "user://probe_save_whole_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_save_whole_collection.json"
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
	# The bench's save: what realset's last save_model meets (bench_run()).
	Assistant.brickbench = true
	_check("a bench run, as realset's is", CommandSocket.bench_run())
	var assistant: Assistant = _main.get("_assistant")
	var world: BrickWorld = _main.get("_world")
	var library: PartLibrary = _main.get("_library")

	print("\na frame on wheels, saved whole: nothing is said of parts left out")
	await _say("clear_model", {})
	var built: String = await _say("submit_design", {"name": "Frame", "description": "a frame",
		"floor": "none", "bricks": FRAME})
	_check("the frame is built: %s" % built.left(70), built.begins_with("Built."))
	var parts: int = world.brick_count()
	var clean: String = "probe-save-whole-clean-%d.ldr" % OS.get_process_id()
	_written.append(ModelStore.SAVE_DIR + clean)
	var said: String = await _say("save_model", {"name": clean})
	_check("saved: %s" % said.left(90).replace("\n", " "), said.contains("Written to %s" % clean)
		and FileAccess.file_exists(ModelStore.SAVE_DIR + clean))
	_check("...with nothing left out", not said.contains("Saved without") and world.brick_count() == parts)

	print("\none gear not held: everything else is saved, and the gear is named")
	# Where the exact check finds the gear at fault (not held, or colliding),
	# as 42061's was. A gear in the air alone is a piece of its own, which the
	# BrickBench pieces gate refuses twice and then saves (a first run of this
	# probe): not this. World units are LDU, y up; the left rail's top is at
	# y 40, its holes along z 8 to 208.
	var gear: int = 0
	var where: String = ""
	for spot: Array in [["lying on the left rail", Basis(Vector3.RIGHT, PI / 2.0), Vector3(10, 44, 100)],
			["on its edge on the left rail", Basis(), Vector3(10, 71, 100)],
			["half in the left rail", Basis(), Vector3(10, 40, 100)]]:
		var tried: int = world.add_brick("3648b", 71, Transform3D(spot[1], spot[2]))
		if tried <= 0:
			continue
		var fault: String = await _fault_of(assistant, tried)
		print("    a gear %s: %s" % [spot[0], fault if not fault.is_empty() else "no fault"])
		if not fault.is_empty():
			gear = tried
			where = "%s (%s)" % [spot[0], fault]
			break
		world.remove_brick(tried)
	_check("a 24-tooth gear %s, #%d" % [where, gear], gear > 0 and world.brick_count() == parts + 1)
	var file: String = "probe-save-whole-%d.ldr" % OS.get_process_id()
	var path: String = ModelStore.SAVE_DIR + file
	_written.append(path)
	var saved: String = await _say("save_model", {"name": file})
	print("    " + saved.left(700).replace("\n", "\n    "))
	_check("save_model is not refused: the file is written", FileAccess.file_exists(path)
		and saved.contains("Written to %s" % file) and not saved.begins_with("Not saved"))
	var text: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var lines: int = 0
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("1 ") and line.strip_edges().to_lower().ends_with(".dat"):
			lines += 1
	_check("...holding the whole frame, %d of its %d parts" % [lines, parts], lines == parts)
	_check("...and not the gear", not text.to_lower().contains("3648b.dat"))
	_check("...which the answer names, by its number and why", saved.contains("Saved without number %d"
		% gear) and (saved.contains("not held") or saved.contains("collision"))
		and saved.contains("3648b"))
	_check("...taken off the model as one edit, the rest standing", world.get_brick(gear) == null
		and world.brick_count() == parts)
	var undone: String = await _say("undo", {})
	_check("...and undo puts it back: %s" % undone.left(80), world.brick_count() == parts + 1)

	print("\na person's save is as it was: written whole, never refused")
	Assistant.brickbench = false
	var mine: String = "probe-save-whole-person-%d.ldr" % OS.get_process_id()
	_written.append(ModelStore.SAVE_DIR + mine)
	var person: String = await _say("save_model", {"name": mine})
	_check("written, the gear in it: %s" % person.left(80).replace("\n", " "),
		person.contains("Written to %s" % mine) and FileAccess.get_file_as_string(
			ModelStore.SAVE_DIR + mine).to_lower().contains("3648b.dat"))
	if library == null or assistant == null:
		_check("the app's library and assistant", false)
	_quit()


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


## What the save gate's own exact check finds of brick [param id]: "not held",
## "colliding" or "" (Assistant._exact_save_gate reads the same report).
func _fault_of(assistant: Assistant, id: int) -> String:
	assistant._strict_mine = true
	var model: Assistant.Model = assistant._model_from_world()
	var report: Dictionary = await assistant._checked(model, true)
	assistant._strict_mine = false
	for index: int in model.placements.size():
		if (model.placements[index] as Assistant.Placement).id != id:
			continue
		if (report.get("unheld", []) as Array).has(index):
			return "not held"
		if (report.get("colliding", []) as Array).has(index):
			return "colliding"
	return ""


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
	print("save_whole_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
