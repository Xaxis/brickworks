## What the third MCP walk-through met, replayed on the real scene.
##
##   godot --headless --path . --script src/dev/mcp_walk3_probe.gd
##
## A real Claude Code session on the subscription built the owner's kind of
## model, an observatory with a dome panel on hinges, a telescope slid out
## by a rack and a hand wheel, and back wall panels that swing open, and
## gave it motions (bench/results/mcpwalk3-2026-10-20). Its model is
## tests/fixtures/mcpwalk3/observatory.ldr, as it saved it. Each check is a
## call it made, called as the desktop's MCP port calls it
## (CommandSocket.answer_rpc, tools/call):
##
##  - "Extend the telescope", after "Open the dome panel": define_motion
##    checks it after the motion it follows. Alone it stopped on the shut
##    dome, and the session had to tell the person to ignore the check.
##  - Played, the wheel's answer says the rack slid and how far: it said
##    only that the gear turned 612°, and the session measured the
##    telescope with view_model to find out.
##  - Two tracks in one motion, the dome and the wheel: the one that stops
##    on the other's part says the tracks are tested apart, and to make it
##    a motion of its own with after=. The session took the dome to have
##    opened too late.
##  - Played backwards, a wheel whose rack is held now says what holds it
##    (or turns back), not "it slides; a motion turns this joint"; move_part
##    not "it is already there". A door turned to 90° and then held says
##    what holds it, not only that it is part of the biggest body.
##  - A door turned says which way it went, into the model or out from it:
##    the rerun's session opened its back doors -100° and 100° and could not
##    tell from four views which way either had gone.
##  - move_part says a joint's height in plates, as look_at_model does, and
##    its loop "closed by an 8 tooth pinion", not "closed by 0 and a 8".
##  - A play's frames carry every part the sequence moves (play_motion's
##    picture showed the telescope out through the shut dome).
##  - Saved under a name of the session's own and opened again: no
##    "changes that are not saved".
##  - check_design says a gear in a rack's teeth, and one beside a rack and
##    not in them with how far to move it: the session stood a rack on its
##    side in thirteen checks that said nothing either way.
extends SceneTree

const FIXTURE := "res://tests/fixtures/mcpwalk3/observatory.ldr"

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _next: int = 0


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
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	_whole_frames()
	await _motions()
	await _held()
	await _saved_and_opened()
	await _racks_in_the_check()
	_done()


## The observatory as the session saved it, opened afresh.
func _open() -> void:
	_main.call("clear_model")
	_main.call("_open", ProjectSettings.globalize_path(FIXTURE))
	for _n: int in 10:
		await process_frame


## The first brick of [param part], or 0.
func _brick(part: String, nth: int = 0) -> int:
	var found: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			found.append(brick.id)
	found.sort()
	return int(found[nth]) if found.size() > nth else 0


func _whole_frames() -> void:
	print("── a sequence's frames carry what every motion moves ──")
	var a0 := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	var a1 := Transform3D(Basis.IDENTITY, Vector3(10, 0, 0))
	var b0 := Transform3D(Basis.IDENTITY, Vector3(0, 5, 0))
	var b1 := Transform3D(Basis.IDENTITY, Vector3(0, 9, 0))
	var whole: Array = AppTools._whole_frames([[{1: a0}, {1: a1}], [{2: b0}, {2: b1}]])
	_check("the first motion's frames hold the second's part where it began",
		(whole[0][0] as Dictionary).get(2) == b0 and (whole[0][1] as Dictionary).get(2) == b0)
	_check("...and the second's hold the first's where it ended",
		(whole[1][0] as Dictionary).get(1) == a1 and (whole[1][1] as Dictionary).get(1) == a1)
	_check("...and each its own as it played",
		(whole[0][1] as Dictionary).get(1) == a1 and (whole[1][1] as Dictionary).get(2) == b1)


func _motions() -> void:
	print("── the observatory's motions ──")
	await _open()
	var gear: int = _brick("3647")
	# The dome panel as the session's own motion names it.
	var listed: String = await _say("list_motions", {"suggest": false})
	var found: RegExMatch = RegEx.create_from_string("\"Open the dome panel\"[^\n]*\n\\s+#(\\d+) ").search(listed)
	var dome: int = int(found.get_string(1)) if found != null else 0
	_check("the fixture has the session's gear (#%d) and its dome panel (#%d)" % [gear, dome],
		gear > 0 and dome > 0 and _world.get_brick(dome) != null and _world.get_brick(dome).part_id == "87375")
	var said: String = await _say("define_motion", {"name": "Extend the telescope",
		"after": "Open the dome panel", "driver": {"joint": "#%d" % gear, "turns": 1.7, "seconds": 4}})
	print("    " + said)
	# Not on the shut dome. Since Grab 17 the carriage stops where it meets
	# the bearing its axle turns in (#151), 574° of the 612°: before, it slid
	# on into it, "clear all the way" (docs/MECHANISMS.md §28).
	_check("define_motion checks a motion after the ones it follows",
		said.contains("then \"Open the dome panel\", which it follows") and not said.contains("Quarter Dome")
		and (said.contains("clear all the way") or said.contains("(#150) meets the Technic Brick 1 x 2 with Hole (#151)")))
	_check("...and says the rack slid with it", said.contains("Technic Gear Rack") and said.contains(" slid "))
	said = await _say("play_motion", {"name": "Open the dome panel"})
	said = await _say("play_motion", {"name": "Extend the telescope"})
	print("    " + said.get_slice("\n", 0))
	_check("played, the wheel says the rack slid, how far and which way",
		RegEx.create_from_string("Rack 1 x 4 \\(#\\d+\\) slid [0-9.]+ studs toward [+-][xz], and \\d+ parts with it")
		.search(said) != null)
	await _say("undo", {"steps": 2})
	# The session's one motion of both: the dome opened, then the wheel.
	said = await _say("define_motion", {"name": "Dome and telescope", "tracks": [
		{"joint": "#%d" % dome, "keys": [{"t": 0, "place": 0}, {"t": 1.5, "place": 110}]},
		{"joint": "#%d" % gear, "keys": [{"t": 0, "place": 0}, {"t": 2, "place": 0, "how": "hold"},
			{"t": 6, "place": 612}]}]})
	print("    " + said)
	_check("two tracks, one stopping on the other's part, say they are tested apart and to use after=",
		said.contains("tested as if the others stood still") and said.contains("after="))
	await _say("define_motion", {"name": "Dome and telescope", "remove": true})


func _held() -> void:
	print("── a joint a move left held ──")
	await _open()
	var gear: int = _brick("3647")
	var said: String = await _say("move_part", {"part": "#%d" % gear})
	print("    " + said.get_slice("\n", 0))
	_check("move_part says a joint's height in plates, as look_at_model does",
		said.contains(" plates up") and not RegEx.create_from_string("y=[0-9.]+ z=").search(said) != null)
	_check("...and its loop is closed by an 8 tooth pinion, not \"closed by 0 and a 8\"",
		said.contains("closed by an 8 tooth pinion in rack 3743") and not said.contains("closed by 0"))
	await _say("play_motion", {"name": "Open the dome panel"})
	await _say("play_motion", {"name": "Extend the telescope"})
	said = await _say("play_motion", {"name": "Extend the telescope", "reverse": true})
	print("    " + said.get_slice("\n", 0))
	_check("played backwards, the wheel turns back or says what holds its rack",
		(said.contains("went from") and said.contains(" slid ")) or said.contains("what it turns is held"))
	_check("...and never \"it slides; a motion turns this joint\"",
		not said.contains("it slides; a motion turns this joint"))
	said = await _say("move_part", {"part": "#%d" % gear, "degrees": -612})
	_check("move_part on it turns it back or says why, not \"it is already there\"",
		not said.contains("it is already there") or said.contains("Moved "))
	await _open()
	var door: int = _brick("60616b")
	said = await _say("move_part", {"part": "#%d" % door, "degrees": 90})
	print("    " + _line_with(said, "Moved "))
	_check("a door turned says which way it went, into the model or out from it",
		RegEx.create_from_string("its middle went [0-9.]+ studs toward [+-][xz], (into|out from) the model")
		.search(said) != null)
	said = await _say("move_part", {"part": "#%d" % door})
	print("    " + said.get_slice("\n", 0))
	_check("a door turned to 90° moves on, or says what holds it there",
		said.contains("on its hinge") or said.contains("grip"))


func _saved_and_opened() -> void:
	print("── saved under the session's name, opened again ──")
	await _open()
	await _say("play_motion", {"name": "Open the back wall panels"})
	var said: String = await _say("save_model", {"name": "probe-observatory.ldr"})
	_check("saved: %s" % said.get_slice("\n", 0), said.begins_with("Written to probe-observatory.ldr"))
	said = await _say("open_model", {"name": "probe-observatory.ldr"})
	print("    " + said)
	_check("opened again with no \"changes that are not saved\"",
		said.begins_with("Opened") and not said.contains("not saved"))
	said = await _say("list_motions", {"suggest": false})
	_check("...and its motions came with it", said.contains("\"Extend the telescope\"")
		and said.contains("\"Open the back wall panels\""))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ModelStore.SAVE_DIR + "probe-observatory.ldr"))


func _racks_in_the_check() -> void:
	print("── a gear in a rack, and one beside it, in the design check ──")
	_main.call("clear_model")
	# The session's own test of a rack and pinion, whose gear move_part found
	# in the rack's teeth.
	var bricks: Array = [{"part": "3035", "color": 72, "x": 0, "y": 0, "z": 0},
		{"part": "3743", "color": 71, "x": 2, "y": 6, "z": 1},
		{"part": "3705", "color": 0, "axis": "z", "x": 4, "y": 8.75, "z": 2},
		{"part": "3647", "color": 71, "axis": "z", "x": 4, "y": 8.75, "z": 1.5}]
	var said: String = await _say("check_design", {"bricks": bricks})
	_check("check_design says the gear is in the rack's teeth: %s" % _line_with(said, "rack brick"),
		said.contains("is in the teeth of rack brick 1"))
	var high: Array = bricks.duplicate(true)
	high[3]["y"] = 10.75
	high[2]["y"] = 10.75
	said = await _say("check_design", {"bricks": high})
	_check("...and one two plates too high, beside it, with how far down: %s" % _line_with(said, "rack brick"),
		said.contains("is beside rack brick 1 and not in its teeth") and said.contains("plates down"))


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line.strip_edges()
	return "(none)"


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
	print("what the third walk-through's session met is answered" if _failures == 0
		else "%d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)
