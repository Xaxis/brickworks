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
## Then the same gear locked, which a bench's save leaves; and a person's own
## Claude's save, which writes the file whole and never changes the model
## (savereview F1: it took the gear off the baseplate after the file held it).
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
	# A browser never takes the bench's flags: there the arguments are the
	# address's query, so a link could make a person's tab a bench whose save
	# takes parts off (savereview2 G1).
	var flags := PackedStringArray([Assistant.BRICKBENCH_FLAG, "--held-out=7634-1",
		"--held-out-name=Tower Crane"])
	_check("the desktop reads --brickbench, --held-out and --held-out-name",
		Assistant.brickbench_of(flags, false) and DesignMemory.bench_arguments(flags, false) == flags
		and DesignMemory.held_out_of(DesignMemory.bench_arguments(flags, false)) == PackedStringArray(["7634-1"]))
	_check("...a browser (the web feature) reads none of them",
		not Assistant.brickbench_of(flags, true) and DesignMemory.bench_arguments(flags, true).is_empty())
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
	# Where the exact check finds the gear not held, as 42061's was. World
	# units are LDU, y up; the left rail's top is at y 40, its holes along z 8
	# to 208. On its edge beside the left rail's outer face, resting on
	# nothing, moved in a little at a time; then lying on the rail (a gear laid
	# flat on a face with no stud is only advice, set down); one that collides
	# is the fallback, the same edit taking it off.
	var gear: int = 0
	var where: String = ""
	var spots: Array = []
	for out: float in [-6.0, -5.0, -4.5, -4.0, -3.5]:
		spots.append(["on its edge against the left rail at x %s" % out, Basis(Vector3.UP, PI / 2.0),
			Vector3(out, 60, 100)])
	for height: int in [48, 47, 46, 45, 44, 43, 42, 41, 40]:
		spots.append(["lying on the left rail at y %d" % height, Basis(Vector3.RIGHT, PI / 2.0),
			Vector3(10, height, 100)])
	spots.append(["half in the left rail", Basis(), Vector3(10, 40, 100)])
	# The gear is the session's own part, as 42061's was: the check answers
	# for what the design placed (Assistant._exact_subject), and a part it
	# never placed is somebody else's, which it does not judge.
	for spot: Array in spots:
		var tried: int = world.add_brick("3648b", 71, Transform3D(spot[1], spot[2]))
		if tried <= 0:
			continue
		assistant._placed_ids.append(tried)
		var fault: String = await _fault_of(assistant, tried)
		print("    a gear %s: %s" % [spot[0], fault if not fault.is_empty() else "no fault"])
		if fault == "not held" or (fault == "colliding" and spot == spots[-1]):
			gear = tried
			where = "%s (%s)" % [spot[0], fault]
			break
		assistant._placed_ids.remove_at(assistant._placed_ids.find(tried))
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
	# Put back as the design's own part, whatever number it has now.
	gear = _gear_standing(world)
	if gear > 0 and not assistant._placed_ids.has(gear):
		assistant._placed_ids.append(gear)

	print("\nthe gear locked by the person: a bench's save leaves it, written as it stands, and says so")
	var builder: Builder = _main.get("_builder")
	builder.locked[gear] = true
	var held: String = "probe-save-whole-locked-%d.ldr" % OS.get_process_id()
	_written.append(ModelStore.SAVE_DIR + held)
	var kept: String = await _say("save_model", {"name": held})
	print("    " + kept.left(300).replace("\n", "\n    "))
	_check("written with the gear in it, the model untouched: %s" % kept.left(80).replace("\n", " "),
		kept.contains("Written to %s" % held) and FileAccess.get_file_as_string(ModelStore.SAVE_DIR
			+ held).to_lower().contains("3648b.dat") and world.get_brick(gear) != null
		and world.brick_count() == parts + 1)
	_check("...and said as it stands, the gear named", kept.contains("Saved as it stands")
		and kept.contains("#%d" % gear) and not kept.contains("Saved without"))
	builder.locked.erase(gear)

	print("\na person's save is as it was: written whole, the model untouched, the gear named")
	Assistant.brickbench = false
	var store: ModelStore = _main.get("_store")
	var depth: int = builder.history_depth()
	var mine: String = "probe-save-whole-person-%d.ldr" % OS.get_process_id()
	_written.append(ModelStore.SAVE_DIR + mine)
	var person: String = await _say("save_model", {"name": mine})
	print("    " + person.left(400).replace("\n", "\n    "))
	_check("written, the gear in it: %s" % person.left(80).replace("\n", " "),
		person.contains("Written to %s" % mine) and FileAccess.get_file_as_string(
			ModelStore.SAVE_DIR + mine).to_lower().contains("3648b.dat"))
	_check("...and on the baseplate still, no step taken, nothing left unsaved",
		world.get_brick(gear) != null and world.brick_count() == parts + 1
		and builder.history_depth() == depth and not store.has_unsaved_work())
	_check("...which the answer names as not finished, never \"Saved without\"",
		person.contains("Not finished yet") and person.contains("#%d" % gear)
		and person.contains("not held") and not person.contains("Saved without"))
	if library == null or assistant == null:
		_check("the app's library and assistant", false)
	_quit()


## The 24-tooth gear on the baseplate, by its part: 0 if none.
func _gear_standing(world: BrickWorld) -> int:
	for brick: BrickWorld.Brick in world.bricks():
		if brick.part_id == "3648b":
			return brick.id
	return 0


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
