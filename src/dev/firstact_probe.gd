## The first act after a rest is drawn as soon with the panels asleep as awake.
##
##   PROBE_SIZE=390x844 tools/probe.sh src/dev/firstact_probe.gd --touch
##   tools/probe.sh src/dev/firstact_probe.gd --call
##     (godot --path . --resolution 1280x860 --script src/dev/firstact_probe.gd)
##
## idlesleep's panels sleep at rest (Wake), and two acts after a long rest
## were drawn later than with every panel running: a phone's first
## two-finger touchdown (frame 2, not 1) and the first call of Claude's
## through the connector (frame 7, not 1), timed in a browser (connector20,
## minute). Here the app stands still till every sleeper is asleep, then
## each act comes at the start of a frame, before any node runs, as a
## browser hands the page a finger coming down or the relay's answer
## between frames: two fingers down on the model (--touch), or an
## edit_model call heard as the tab hears one (--call: the answer wakes the
## app, the connector says it was called, the tool runs). Counted: the
## frame the first drawing comes in, 1 being the frame the act came in; for
## the fingers, the frame their first move is drawn in (a touchdown alone
## draws nothing either way, and is said).
## Each act is done with sleeping on and off in turn, the first with it on
## (with -- --off-first, off), and every wake, rest and drawn frame of the
## first is printed (Wake's trace). Held: each with sleeping on drawn in
## the same frame as with it off, or sooner.
extends SceneTree

const MODEL := "res://models/car.ldr"
const ROUNDS := 4

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _camera: CadCamera
var _calls: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 30:
		await process_frame
	_world = _main.get("_world")
	_camera = _main.get("_camera")
	if _world == null or _camera == null:
		_check("the app came up", false)
		_finish()
		return
	(_main.get("_store") as ModelStore).keeps = false
	var placed: int = int(_main.call("_open", MODEL))
	print("  %s, %d parts" % [MODEL.get_file(), placed])
	var library: PartLibrary = _main.get("_library")
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 120000:
		await process_frame
		var waiting: bool = false
		for brick: BrickWorld.Brick in _world.bricks():
			if library.mesh_for(brick.part_id) == null:
				waiting = true
				break
		if not waiting:
			break
	(_main.get("_playback") as BuildPlayback).stop()
	_camera.frame(_world.model_bounds())
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var connector: Node = null
	if args.has("--call"):
		connector = _main.get("_connector")
		# Its answer goes nowhere: no relay here, and never the live one.
		connector.set("base_url", "http://127.0.0.1:10969")
	IdleDraw.begin()
	await _seconds(3.0)
	var on_first: bool = not args.has("--off-first")
	var on_frames: Array[int] = []
	var off_frames: Array[int] = []
	for round: int in ROUNDS:
		var sleeping: bool = (round % 2 == 0) == on_first
		if sleeping:
			Wake.begin()
		else:
			Wake.end()
		await _seconds(2.0)
		var asleep: int = _asleep()
		Wake._trace = round < 2
		print("")
		print("  round %d, sleeping %s, %d asleep" % [round + 1, "on" if sleeping else "off", asleep])
		var frame: int = 0
		if connector != null:
			frame = await _call(connector)
		else:
			frame = await _touch()
		Wake._trace = false
		print("    drawn in frame %d" % frame)
		(on_frames if sleeping else off_frames).append(frame)
		await _seconds(1.5)
	var what: String = "the first call heard" if connector != null else "two fingers coming down"
	_check("%s: drawn in frames %s asleep, %s awake" % [what, on_frames, off_frames],
		on_frames.max() <= maxi(off_frames.max(), 1) and on_frames.min() > 0)
	_finish()


## Two fingers down either side of the middle, at the start of a frame: the
## frame the first drawing came in, if any within 20 (a touchdown alone
## changes nothing on screen, awake or asleep: the view turns once the
## fingers move). Then both fingers moved, as a turn begins: the frame that
## move is drawn in, which is what is held. Then lifted.
func _touch() -> int:
	var middle: Vector2 = root.get_visible_rect().size * 0.5
	var left: Vector2 = middle - Vector2(60.0, 0.0)
	var right: Vector2 = middle + Vector2(60.0, 0.0)
	await process_frame
	var drawn: int = Engine.get_frames_drawn()
	_finger(0, left, true)
	_finger(1, right, true)
	var down: int = await _drawn_since(drawn, 20)
	print("    the touchdown alone: %s" % ("drawn in frame %d" % down if down > 0 else "nothing drawn"))
	await process_frame
	drawn = Engine.get_frames_drawn()
	_drag(0, left, left + Vector2(8.0, 0.0))
	_drag(1, right, right + Vector2(8.0, 0.0))
	var frame: int = await _drawn_since(drawn)
	_finger(1, right + Vector2(8.0, 0.0), false)
	_finger(0, left + Vector2(8.0, 0.0), false)
	return frame


## An edit_model call heard as the tab hears one (ClaudeConnector._answer):
## the relay's answer wakes the app (PageFetch), the panels hear it was
## called, then the tool runs. Not the connector's own _answer, which keeps
## its file in the user's folder.
func _call(connector: Node) -> int:
	_calls += 1
	var arguments: Dictionary = {"add": [{"part": "3004", "color": 4 if _calls % 2 else 1,
		"x": -40 - 4 * _calls, "y": 0, "z": 20}]}
	var request: Dictionary = {"jsonrpc": "2.0", "id": _calls, "method": "tools/call",
		"params": {"name": "edit_model", "arguments": arguments}}
	await process_frame
	var drawn: int = Engine.get_frames_drawn()
	var bricks: int = _world.brick_count()
	Wake.all("fetch")
	Wake.trace("TRACE call")
	connector.emit_signal(&"called", "edit_model", arguments, "")
	var rpc: Object = connector.get("rpc")
	var answering: Array = [false]
	(func() -> void:
		await rpc.answer_rpc(request)
		Wake.trace("TRACE answered")
		answering[0] = true).call()
	var frame: int = await _drawn_since(drawn)
	var until: int = Time.get_ticks_msec() + 30000
	while not bool(answering[0]) and Time.get_ticks_msec() < until:
		await process_frame
	print("    answered %s, %d -> %d bricks" % [answering[0], bricks, _world.brick_count()])
	return frame


## The frame the first drawing since [param drawn] came in: 1 is the frame
## the act came in, which is drawn by the time the next one starts.
func _drawn_since(drawn: int, most: int = 600) -> int:
	for frame: int in range(1, most + 1):
		await process_frame
		if Engine.get_frames_drawn() > drawn:
			return frame
	return -1


func _finger(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	Input.parse_input_event(event)
	# As a browser's touchstart is: handled at once, between frames.
	Input.flush_buffered_events()


func _drag(index: int, from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to
	event.relative = to - from
	Input.parse_input_event(event)
	# A browser's touchmove waits for the next frame's start: the same.
	Input.flush_buffered_events()


func _asleep() -> int:
	return Wake._asleep.size()


func _seconds(how_long: float) -> void:
	var until: int = Time.get_ticks_msec() + int(how_long * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _check(what: String, held: bool) -> void:
	print("    %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILURE(S)" % _failures if _failures
		else "the first act after a rest drawn as soon asleep as awake")
	Wake.end()
	quit(1 if _failures else 0)
