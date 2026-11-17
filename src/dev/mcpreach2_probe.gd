## Where the person's Claude stalled or guessed in APP_UX9's MCP walk, each in
## the answer that would have spared it (mcpreach2, docs/APP_UX9.md).
##
##   godot --path . --resolution 1400x900 --script src/dev/mcpreach2_probe.gd
##
## Needs a window: where_to_attach's picture and the turntable are drawn.
## Every call is a session's, through CommandSocket's tools/call, a job
## followed with the job tool as a session follows it, and the calls
## counted. The first of the five, the other chats in a tab, is the relay's
## (api/mcp.js), checked by tests/test_relay_chats.py and tabpair_probe.
##
##  f5  "Show me, in a picture, every place on the model where another part
##      could still clip, snap or pin on", with nothing selected: the walk's
##      session was asked to select everything first. A small car, nothing
##      selected: where_to_attach is a picture in one call, of the whole
##      model, its free points counted by kind, the numbered spread over
##      every part, the rest drawn as dots; parts= reads only those named;
##      with a selection, the selection, as before.
##  y6  A SPIKE Prime large motor turning a beam pinned into its hub, as the
##      walk's session first built it: attachment_points on the motor names
##      its output's axle hole and pin holes as the output's, which turn,
##      apart from the case's; simulate_mechanism driver=<the motor> turns
##      the output and what is on it, where it was told the motor "is the
##      base"; move_part's list and pose_model name the motor and that its
##      output turns when driven, not by a drag or a pose: the before walk's
##      session read "Nothing here turns" and never asked Simulate.
##  f4  A turntable says what moves: render_model kind=turntable's answer says
##      the camera goes once round a model that stands still.
##  5   submit_design pool=: a design held to one set's parts (31058-1,
##      Mighty Dinosaurs) as mine=true is to the collection: all in the set,
##      each part over by how many, a bare "31058" read as 31058-1, two sets
##      pooled, a number in no inventory said so, and nothing said without.
extends SceneTree

## The walk's y6 first build, call 12, as its session gave it.
const Y6_BUILD: Array = [
	{"part": "54675", "color": 322, "x": 20, "y": 0, "z": 0, "face": "+z", "rot": 2},
	{"part": "32524", "color": 72, "axis": "x", "x": 19.5, "y": 1.25, "z": 3.5},
	{"part": "32524", "color": 72, "axis": "x", "x": 25.5, "y": 1.25, "z": 3.5},
	{"part": "2780", "color": 0, "axis": "x", "x": 20, "y": 1.25, "z": 0.5},
	{"part": "2780", "color": 0, "axis": "x", "x": 20, "y": 1.25, "z": 2.5},
	{"part": "2780", "color": 0, "axis": "x", "x": 25, "y": 1.25, "z": 0.5},
	{"part": "2780", "color": 0, "axis": "x", "x": 25, "y": 1.25, "z": 2.5},
	{"part": "40490", "color": 71, "axis": "z", "rot": 1, "x": 25.5, "y": 18.75, "z": 4.5},
	{"part": "2780", "color": 0, "axis": "z", "x": 21.5, "y": 18.75, "z": 4},
	{"part": "2780", "color": 0, "axis": "z", "x": 23.5, "y": 18.75, "z": 4},
	{"part": "4274", "color": 1, "axis": "z", "x": 29.5, "y": 18.75, "z": 5},
]
const SET := "31058-1"

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0
## The picture the last answer carried; null for none.
var _seen: Image = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	SaveTo.native = false
	CollectionStore.where = OS.get_temp_dir().path_join("brickworks_mcpreach2_%d.json" % OS.get_process_id())
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
	await process_frame
	await _whole()
	await _turntable()
	await _motor()
	await _pool()
	_quit()


# -- f5: where_to_attach with nothing selected -------------------------------------------


## A small car of the walk's f3 parts: a chassis of two 2x4 bricks on 1x4
## plates, wheel holders under, a white cab.
static func _car() -> Array:
	return [
		{"part": "3710", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3710", "color": 0, "x": 0, "y": 0, "z": 1, "rot": 0},
		{"part": "3710", "color": 0, "x": 0, "y": 0, "z": 2, "rot": 0},
		{"part": "3710", "color": 0, "x": 0, "y": 0, "z": 3, "rot": 0},
		{"part": "3001", "color": 4, "x": 0, "y": 1, "z": 0, "rot": 0},
		{"part": "3001", "color": 4, "x": 0, "y": 1, "z": 2, "rot": 0},
		{"part": "3003", "color": 15, "x": 1, "y": 4, "z": 1, "rot": 0},
		{"part": "3003", "color": 15, "x": 1, "y": 7, "z": 1, "rot": 0},
	]


func _whole() -> void:
	print("")
	print("f5: every place a part could go, with nothing selected")
	await _say("clear_model", {})
	var built: String = await _say("submit_design", {"name": "Small car", "description": "a small car",
		"floor": "none", "bricks": _car()})
	_check("the car is built: %s" % built.left(120), built.begins_with("Built"))
	var builder: Builder = _main.get("_builder")
	builder.clear_selection()
	await _frames(2)
	var calls_said: Array = await _called("where_to_attach", {})
	var said: String = calls_said[0]
	print("    %s" % said.left(700).replace("\n", " | "))
	_check("one call, and a picture with it", int(calls_said[1]) == 1 and _seen != null)
	_check("of the whole model, said so", said.begins_with("The model's open connection points:")
		and said.contains("Nothing is selected, so this is the whole model."))
	_check("every free one counted by kind", said.contains("Every free one, by kind:"))
	var parts: Dictionary = {}
	for found: RegExMatch in RegEx.create_from_string("\\] \\S+ on #(\\d+) ").search_all(said):
		parts[int(found.get_string(1))] = true
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var all: int = world.brick_count() - store.scenery.size()
	_check("the numbered points are on %d of the %d parts, not one plate's" % [parts.size(), all],
		parts.size() >= mini(all, 6))
	_check("the caption says the whole model, numbered and dots", said.contains("The whole model from the"))
	var one: int = int(parts.keys()[0]) if not parts.is_empty() else -1
	var named: String = (await _called("where_to_attach", {"parts": [one]}))[0]
	_check("parts=[#%d] reads that part alone" % one, named.begins_with("Parts #%d' open connection points" % one)
		and not named.contains("Nothing is selected"))
	var seated: String = (await _called("where_to_attach", {"part": "3001", "color": 1}))[0]
	_check("given part=, it seats one on the whole model, in edit_model's add",
		seated.contains("edit_model") and not seated.contains("select"))
	builder.select_brick(one, false)
	await _frames(2)
	var selected: String = (await _called("where_to_attach", {}))[0]
	_check("with #%d selected, the selection as before" % one,
		selected.begins_with("The selection's open connection points"))
	builder.clear_selection()


# -- f4: a turntable says what moves ------------------------------------------------------


func _turntable() -> void:
	print("")
	print("f4: a turntable of the car, said as it is seen")
	var calls_said: Array = await _called("render_model", {"kind": "turntable", "quality": "quick"})
	var said: String = calls_said[0]
	print("    %s" % said.left(900).replace("\n", " | "))
	_check("the answer says the camera goes once round the model, which stands still",
		said.contains("the camera goes once round the model") and said.contains("while the model stands still")
		and said.contains("No part of the model moves"))
	_check("...and how it is drawn, after", said.contains("drawn by turning the model on a turntable"))


# -- y6: a motor's output, named --------------------------------------------------------


func _motor() -> void:
	print("")
	print("y6: a SPIKE Prime large motor turning a beam pinned into its hub")
	await _say("clear_model", {})
	var made: String = await _say("edit_model", {"add": Y6_BUILD, "picture": false})
	print("    %s" % made.left(300).replace("\n", " | "))
	var world: BrickWorld = _main.get("_world")
	var motor: int = -1
	var arm: int = -1
	for brick: BrickWorld.Brick in world.bricks():
		if brick.part_id == "54675":
			motor = brick.id
		elif brick.part_id == "40490":
			arm = brick.id
	_check("built: the motor #%d and the arm #%d" % [motor, arm], motor >= 0 and arm >= 0)
	if motor < 0:
		return
	var points: String = (await _called("attachment_points", {"brick": motor}))[0]
	var output: String = points.substr(points.find("Its output"))
	print("    %s" % output.left(700).replace("\n", " | "))
	_check("attachment_points names its output, which the motor turns", points.contains(
		"Its output, which the motor turns in its case about the line through"))
	_check("...with its axle hole", output.contains("axle hole: an axle keyed in it turns with the output"))
	var pins: int = output.count("pin hole: a pin in it, and what it holds, turns with the output")
	_check("...and the ring's pin holes, %d of them" % pins, pins >= 4)
	_check("...apart from the case's", output.contains("Every other hole is the case's, which stands still"))
	var driven: String = (await _called("simulate_mechanism", {"driver": str(motor)}))[0]
	print("    %s" % driven.left(500).replace("\n", " | "))
	_check("driver= the motor turns its output, not the case", driven.contains(
		"(the output of motor #%d, as asked)" % motor) and not driven.contains("is the base. Give driver="))
	_check("...and the arm pinned into the hub turns with it", driven.contains("#%d" % arm)
		or driven.contains("Beam 9") or driven.contains("Liftarm"))
	var moves: String = (await _called("move_part", {}))[0]
	_check("move_part's list names the motor, and that its output turns when driven",
		moves.contains("Motors in it: #%d the SPIKE Prime" % motor) and moves.contains("turns when the motor drives it"))
	var posed: String = (await _called("pose_model", {}))[0]
	_check("pose_model, with no hinge to pose, says the motor's output turns when driven: %s"
		% _line_with(posed, "Nothing here turns").right(160), not posed.begins_with("Nothing here turns")
		or posed.contains("simulate_mechanism driver=<the motor's number> turns it"))


# -- 5: submit_design pool= ------------------------------------------------------------


static func _tower(bricks: Array) -> Array:
	var out: Array = []
	var y: int = 0
	for one: Array in bricks:
		out.append({"part": one[0], "color": one[1], "x": 0, "y": y, "z": 0, "rot": 0})
		y += 1 if str(one[0]) in ["3020", "3021", "3023", "3024"] else 3
	return out


func _pool() -> void:
	print("")
	print("5: a design held to one set's parts (%s, Mighty Dinosaurs)" % SET)
	await _say("clear_model", {})
	# All in the set: a Tan 2x4 plate, a Tan 2x4 brick, two Tan 2x2 plates.
	var fits: Array = _tower([["3020", 19], ["3001", 19], ["3021", 19], ["3021", 19]])
	var held: String = await _say("submit_design", {"name": "Tan tower", "description": "a tower",
		"floor": "none", "bricks": fits, "pool": SET})
	print("    %s" % _line_with(held, "pool").left(220))
	_check("all in the set: said so, with what is left", held.begins_with("Built") and held.contains(
		"From 31058-1 Mighty Dinosaurs's parts alone (pool): every one of its 4 pieces is in the set in its colour, 170 pieces left of the set's 174."))
	# Three Tan 2x4 bricks where the set has one, and a Red one it has none of.
	var over: Array = _tower([["3020", 19], ["3001", 19], ["3001", 19], ["3001", 19], ["3001", 4]])
	var too_many: String = await _say("submit_design", {"name": "Tan tower", "description": "a tower",
		"floor": "none", "bricks": over, "pool": "31058"})
	var tan: String = _line_with(too_many, "Brick 2 x 4 in Tan")
	var red: String = _line_with(too_many, "Brick 2 x 4 in Red")
	print("    %s" % _line_with(too_many, "(pool)").left(220))
	_check("\"31058\" is 31058-1, and two parts over by three pieces", too_many.contains(
		"Over 31058-1 Mighty Dinosaurs's parts (pool): 2 parts it uses more of than the set has, 3 pieces over in all"))
	_check("...the Tan 2 x 4: %s" % tan.strip_edges(), tan.contains("3 used, the set has 1, 2 over"))
	_check("...and the Red 2 x 4: %s" % red.strip_edges(), red.contains("1 used, the set has 0, 1 over"))
	_check("...with a compare call ready", too_many.contains("parts_list which=\"compare\" a=\"open\" b=\"31058-1\""))
	# Two Black 2x4 bricks: 7140-1 has four, 31058-1 none; pooled, none over.
	var black: Array = _tower([["3001", 0], ["3001", 0]])
	var pooled: String = await _say("submit_design", {"name": "Black pair", "description": "two bricks",
		"floor": "none", "bricks": black, "pool": "31058-1, 7140-1"})
	_check("two sets pooled: %s" % _line_with(pooled, "(pool)").left(160), pooled.contains(
		"From 31058-1 Mighty Dinosaurs and 7140-1 X-wing Fighter's parts alone (pool): every one of its 2 pieces is in the sets"))
	var unknown: String = await _say("submit_design", {"name": "Black pair", "description": "two bricks",
		"floor": "none", "bricks": black, "pool": "99999999"})
	_check("a number in no inventory is said so", unknown.contains("no set 99999999-1 is in Rebrickable's inventories"))
	var without: String = await _say("submit_design", {"name": "Black pair", "description": "two bricks",
		"floor": "none", "bricks": black})
	_check("without pool, nothing is said of a set", not without.contains("(pool)"))
	await _say("clear_model", {})


# -- helpers -----------------------------------------------------------------------------


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return "-"


## A session's call, its job followed to the end with the job tool as a
## session follows it: [the answer's words, the calls it took].
func _called(tool: String, arguments: Dictionary) -> Array:
	var said: String = await _say(tool, arguments)
	var calls: int = 1
	var job := RegEx.create_from_string("^Started job (\\d+)")
	var found: RegExMatch = job.search(said)
	while found != null and calls < 60:
		said = await _say("job", {"id": int(found.get_string(1))})
		calls += 1
		if not said.contains("is still going"):
			break
	return [said, calls]


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _say(tool: String, arguments: Dictionary) -> String:
	var result: Dictionary = await _rpc("tools/call", {"name": tool, "arguments": arguments})
	var text := PackedStringArray()
	_seen = null
	for block: Dictionary in result.get("content", []):
		if str(block.get("type", "")) == "text":
			text.append(str(block.get("text", "")))
		elif str(block.get("type", "")) == "image":
			_seen = Image.new()
			if _seen.load_png_from_buffer(Marshalls.base64_to_raw(str(block.get("data", "")))) != OK \
					and _seen.load_jpg_from_buffer(Marshalls.base64_to_raw(str(block.get("data", "")))) != OK:
				_seen = null
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
	print("mcpreach2_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
