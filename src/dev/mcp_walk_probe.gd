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
##    it, and changes nothing; its card says steering, not boom (its knuckles
##    are blocks on frictionless pins, and the card said "boom"), and the
##    part it names for the steering turns both front wheels and not the
##    back ones; pose_model, with nothing to pose, points to it. The session
##    had tried five parts one at a time.
##  - "Steer the wheels left and back": turned 20° and then 15°, the answer
##    says the steering stands 35° from where it was built, as the knuckle's
##    turn against the beam it hangs on measures it, and back by 35° it
##    stands where it was built. It said "now 15°", that call's turn.
##  - "Show me it turning": animate_model takes the steering by its part, as
##    move_part names it, in degrees from where it was built: the frames it
##    would draw turn both front wheels as move_part does, nothing on the
##    baseplate moves, and asked only to set keys it keeps them as the
##    motion "Animation", whose Play in Build, Motions… turns the wheels and
##    Play backwards puts them back. The
##    session's car steered with move_part and animate_model said nothing
##    turns; then keys on a part were refused unless rendered, and keys a
##    render left in the panel played nothing (animaudit, 2026-10-20).
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
##    Then the person that session spoke for, who owns sets 31070-1 and
##    6061-1: each set's own official model is listed as the set holds it
##    (Collection.as_its_set), so the Siege Tower is whole and first, and
##    the Turbo Track Racer short only of the two axle joiners its model
##    draws and its box does not hold. Measured as drawn they were 84% and
##    96%, and the session said nothing could be built completely.
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
	_check("...and its card says steering, not boom: %s" % said.get_slice("\n", 0),
		said.begins_with("Moves: steering,") and not said.get_slice("\n", 0).contains("boom"))
	var steering: int = 0
	for line: String in said.split("\n"):
		if line.begins_with("  steering: #"):
			steering = int(line.trim_prefix("  steering: #").get_slice(" ", 0))
			break
	_check("it names a part to take hold of for the steering: #%d" % steering, steering != 0)
	# The kart's front wheels (#10, #11) and its back ones (#8, #9), by where
	# the file puts them.
	said = await _say("move_part", {"part": "#%d" % steering, "degrees": 20})
	var after: Dictionary = _poses()
	_check("the part it names steers both front wheels, not the back ones",
		_turned(before, after, 10) and _turned(before, after, 11)
		and not _turned(before, after, 8) and not _turned(before, after, 9))
	print("    " + said.get_slice("\n", 1))
	said = await _say("move_part", {"part": "#%d" % steering, "degrees": 15})
	var stands: String = said.get_slice("Its joint now stands ", 1).get_slice(";", 0)
	_check("turned 20° and then 15°, it says the turn and where it stands: %s, %s"
		% [said.get_slice("\n", 1).get_slice(" (", 0), stands],
		said.contains("Moved ") and said.contains(": turned 15° (asked 15°)")
		and stands == "35° from where it was built")
	said = await _say("move_part", {"part": "#%d" % steering})
	_check("asked with nothing else, it says where it stands: %s" % said.get_slice("Its joint stands ", 1)
		.get_slice(".", 0), said.contains("Its joint stands 35° from where it was built."))
	said = await _say("move_part", {"part": "#%d" % steering, "degrees": -35})
	_check("...and back by 35°, where it was built: %s" % said.get_slice("Its joint now stands ", 1)
		.get_slice(";", 0), said.contains("Its joint now stands where it was built")
		and _same(_poses(), before))
	await _animate(steering, before)
	said = await _say("pose_model", {})
	_check("pose_model, with nothing to pose, points to move_part: %s" % said.get_slice(". ", 2).left(80),
		said.contains("move_part with no part= lists them"))


## animate_model on the kart's steering, by its part.
func _animate(steering: int, before: Dictionary) -> void:
	var grabbing: GrabDrag = _main.get("_grab_drag")
	var turning: Variant = grabbing.turning_for_session("#%d" % steering)
	_check("a part on its joint is a joint to animate", turning is GrabDrag.Turning)
	if not turning is GrabDrag.Turning:
		return
	var placed: Dictionary = (turning as GrabDrag.Turning).placed_at(25.0)
	var at: Dictionary = before.duplicate()
	at.merge(placed, true)
	_check("its frame at 25° turns both front wheels, not the back ones (%d parts)" % placed.size(),
		_turned(before, at, 10) and _turned(before, at, 11) and not _turned(before, at, 8)
		and not _turned(before, at, 9))
	_check("...and moves nothing on the baseplate", _same(_poses(), before))
	var keys: Array = [{"t": 0, "angles": {"#%d" % steering: 0}}, {"t": 1, "angles": {"#%d" % steering: 25}}]
	var said: String = await _say("animate_model", {"keys": keys, "render": false})
	_check("keys alone are set for the person to play: %s" % said.left(70),
		said.begins_with("Set 2 keys over 1.0 s") and said.contains("plays it"))
	# Play, as the person presses it in Build, Motions…, where the keys are
	# the motion "Animation": the steering turns in the window and stays
	# where it ends, and Play backwards puts every part where it was built.
	# Refused before, and keys left by a render played nothing.
	var pose: PosePanel = _main.get("_pose")
	_main.call("open_pose")
	await process_frame
	pose.play("Animation")
	var turned_while_playing: bool = false
	for _n: int in 240:
		await process_frame
		if _turned(before, _poses(), 10) and _turned(before, _poses(), 11):
			turned_while_playing = true
		if not pose.is_playing():
			break
	_check("...and Play turns both front wheels", turned_while_playing)
	pose.play("Animation", true)
	for _n: int in 240:
		await process_frame
		if not pose.is_playing():
			break
	_check("...and Play backwards puts them back where they were built", not pose.is_playing()
		and _same(_poses(), before))
	pose.close()
	said = await _say("animate_model", {"keys": keys})
	_check("keys to render, headless: set, and why it is not drawn: %s" % said.left(60),
		said.begins_with("Set 2 keys over 1.0 s") and said.contains("without a window"))
	said = await _say("animate_model", {"keys": [{"t": 0, "angles": {"#999": 10}}]})
	_check("a part that is not there: %s" % said.left(70), said.begins_with("No joint #999: no part"))
	_check("...and nothing on the baseplate moved", _same(_poses(), before))


## Whether brick [param id] stands turned in [param b] from where it stood in [param a].
static func _turned(a: Dictionary, b: Dictionary, id: int) -> bool:
	return not (a[id] as Transform3D).basis.is_equal_approx((b[id] as Transform3D).basis)


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
	mine.collection = Collection.from_json({"sets": [{"set": "31070-1", "qty": 1},
		{"set": "6061-1", "qty": 1}], "parts": []})
	await mine.refresh_pool()
	said = await _say("parts_list", {"which": "buildable"})
	for line: String in said.split("\n").slice(0, 3):
		print("    " + line)
	var first: String = said.get_slice("\n", 1).strip_edges()
	var racer: String = ""
	for line: String in said.split("\n"):
		if line.contains("(the official model of set 31070-1"):
			racer = line.strip_edges()
			break
	_check("owning 31070-1 and 6061-1, the Siege Tower is built whole from its own set: %s" % first,
		first.begins_with("100% Siege Tower") and first.contains(", 0 missing"))
	_check("...and the Turbo Track Racer is short only of what its box does not hold: %s" % racer,
		racer.contains("owns 663 of its 665 pieces in their colours, 2 missing"))


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
