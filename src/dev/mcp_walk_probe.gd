## What the second MCP walk-through met, replayed on the real scene.
##
##   godot --headless --path . --script src/dev/mcp_walk_probe.gd
##
## Real Claude Code sessions on the subscription were asked what a person
## asks (bench/results/mcpwalk2-2026-10-19). Each check is a call one of
## them made, or the call it had no way to make, called as the desktop's
## MCP port calls it (CommandSocket.answer_rpc, tools/call):
##
##  - "What in this model moves?" on the Technic Go-Kart: move_part with no
##    part= says what moves and every part on a joint, by a part that moves
##    it, and changes nothing; the part it names first for the front
##    steering turns both front wheels and back; pose_model, with nothing
##    to pose, points to it. The session had tried five parts one at a time.
##  - "Find the most built small model and open it": open_model link= opens
##    a copy of a gallery model (its answer played here, FakeShared) saved
##    in the person's models under its own name and remixed from its link;
##    refused over changes not saved, and for a link that is not one. The
##    session could only read it and send the person to its page.
##  - "What can I build from my collection?": parts_list which="buildable"
##    ranks what My collection's What can I build? ranks, the examples and
##    the official models of real sets with the saved models: a collection
##    of the Bench example's pieces builds the Bench whole, first. The
##    session, given only the saved models, said nothing could be built.
extends SceneTree

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _store: ModelStore
var _next: int = 0


## The gallery's answer for one model, played here.
class FakeShared extends SharedModels:
	var asked: Array = []

	func fetch(id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		asked.append(id)
		if id != "Walk000001":
			return {"code": 404, "body": {"error": "There is no such model."}}
		return {"code": 200, "body": {"id": id, "name": "Played Racer", "author": "Played Builder",
			"parts": 3, "licence": "cc-by-4.0", "version": 2, "url": "https://brickworks.diy/m/" + id,
			"model": "0 Played Racer\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
				+ "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat\n"}}


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
	_world = _main.get("_world")
	_store = _main.get("_store")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	await _what_moves()
	await _open_link()
	await _buildable()
	_done()


func _what_moves() -> void:
	print("── what moves, on the Technic Go-Kart ──")
	var said: String = await _say("open_model", {"name": "kart", "discard_changes": true})
	_check("the kart is open: %s" % said, said.begins_with("Opened Technic Go-Kart"))
	var listed: Dictionary = await _rpc("tools/list", {})
	var schema: Dictionary = {}
	for tool: Dictionary in listed.get("tools", []):
		if str(tool["name"]) == "move_part":
			schema = tool.get("inputSchema", tool.get("input_schema", {}))
	_check("move_part is offered with part= not required, to list what moves",
		not schema.is_empty() and not (schema.get("required", []) as Array).has("part"))
	var before: Dictionary = _poses()
	said = await _say("move_part", {})
	print("    " + said.replace("\n", "\n    "))
	_check("move_part with no part= lists the parts on a joint, biggest first",
		said.contains("On a joint a drag moves") and said.contains("move_part part=N"))
	_check("...and says what its link's card says moves",
		said.begins_with("What moves, as its link's card says") or said.begins_with("Moves: "))
	_check("...and changes nothing", _poses() == before and said.contains("Nothing was changed."))
	# The front steering, as the session found it at last: the beam on the
	# frictionless upright pin at the front right turned both front wheels.
	var steering: int = 0
	for line: String in said.split("\n"):
		if line.contains("on a pin without friction") and line.begins_with("  #"):
			steering = int(line.trim_prefix("  #").get_slice(" ", 0))
			break
	_check("a part on a pin without friction is listed: #%d" % steering, steering != 0)
	said = await _say("move_part", {"part": "#%d" % steering, "degrees": 20})
	var moved: int = int(said.get_slice("Moved ", 1).get_slice(" part", 0)) if said.contains("Moved ") else 0
	_check("the part it lists steers: %d parts moved" % moved, moved >= 8)
	said = await _say("move_part", {"part": "#%d" % steering, "degrees": -20})
	_check("...and back where it was built", _same(_poses(), before))
	said = await _say("pose_model", {})
	_check("pose_model, with nothing to pose, points to move_part: %s" % said.get_slice(". ", 2).left(80),
		said.contains("move_part with no part= lists them"))


func _open_link() -> void:
	print("── a gallery model opened, as Open in Brickworks does ──")
	var fake := FakeShared.new()
	_main.add_child(fake)
	var real: SharedModels = _main.get("_shared")
	_main.set("_shared", fake)
	_main.call("clear_model")
	await _say("edit_model", {"add": [{"part": "3001", "color": 1, "x": 0, "y": 0, "z": 0}]})
	var said: String = await _say("open_model", {"link": "Walk000001"})
	_check("over changes not saved, refused, nothing fetched: %s" % said.left(70),
		said.contains("not saved") and fake.asked.is_empty())
	said = await _say("open_model", {"link": "not a link!"})
	_check("a link that is not one: %s" % said.left(70), said.begins_with("link is a gallery model's link id"))
	said = await _say("open_model", {"link": "https://brickworks.diy/m/Walk000001", "discard_changes": true})
	print("    " + said)
	_check("opened by its address: a copy, its parts on the baseplate",
		said.begins_with("Opened a copy of Played Racer") and _world.brick_count() - _store.scenery.size() == 3)
	_check("...saved in the person's models under its own name",
		_store.title == "Played Racer" and not _store.has_unsaved_work()
		and _store.list_saved().any(func(entry: ModelStore.Entry) -> bool: return entry.name == "Played Racer"))
	_check("...remixed from its link, at its version, and no link of its own",
		_store.remixed_from == "Walk000001" and _store.remixed_from_version == 2 and _store.share_id.is_empty())
	_check("...with its credit and licence said", said.contains("by Played Builder")
		and said.contains("CC BY 4.0"))
	said = await _say("open_model", {"link": "Walk000002", "discard_changes": true})
	_check("a link never shared: %s" % said.left(70), said.begins_with("Could not open Walk000002"))
	_main.set("_shared", real)


func _buildable() -> void:
	print("── what can I build, as My collection ranks it ──")
	var library: PartLibrary = _main.get("_library")
	var mine: CollectionStore = (_main.get("_shell") as Shell).collection.store
	var bench: ModelStore.Entry = null
	for entry: ModelStore.Entry in _store.list_examples():
		if entry.path.get_file() == "bench.ldr":
			bench = entry
	# A collection of exactly the Bench example's pieces: it, and no saved
	# model, is what it builds whole.
	var needs: Dictionary = Collection.needs_of_ldraw(FileAccess.get_file_as_string(bench.path), library)
	var parts: Array = []
	for key: String in needs:
		parts.append({"part": Collection.part_of(key), "colour": Collection.colour_of(key), "qty": int(needs[key])})
	mine.collection = Collection.from_json({"sets": [], "parts": parts})
	await mine.refresh_pool()
	var said: String = await _say("parts_list", {"which": "buildable"})
	for line: String in said.split("\n").slice(0, 4):
		print("    " + line)
	_check("the examples are measured too, the one owned whole first: %s" % said.get_slice("\n", 1).strip_edges(),
		said.get_slice("\n", 1).strip_edges().begins_with("100% Bench (an example)"))
	_check("...and the official models of real sets, as What can I build? ranks them",
		said.contains("(the official model of set "))
	_check("...and how to open one", said.contains("open_model name="))


## Every part's place, by id.
func _poses() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


static func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: Variant in a:
		if not b.has(key) or (a[key] as Transform3D).origin.distance_to((b[key] as Transform3D).origin) > 0.1:
			return false
	return true


func _say(tool: String, arguments: Dictionary) -> String:
	var result: Dictionary = await _rpc("tools/call", {"name": tool, "arguments": arguments})
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _done() -> void:
	print("what the walk-through's sessions met is answered" if _failures == 0
		else "%d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)
