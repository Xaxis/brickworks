## A session doing a person's CAD work hears CAD answers, finds a place in
## fewer calls, and sees what the person sees (APP_UX3, "Over MCP"; mcpcad).
##
##   godot --headless --path . --script src/dev/mcpcad_probe.gd
##
## Windowed (tools/probe.sh mcpcad, PROBE_SIZE=1280x720 for the smaller),
## it also keeps a picture of what the person sees as in_view reads it, in
## MCPCAD_SHOTS or user://mcpcad_probe.
##
## Each call is made as the connector and the desktop's MCP port make it
## (CommandSocket.answer_rpc, tools/call), on the app's scene:
## - The walk's side pod, five parts asked for by part, submitted with its
##   4 x 6 plate six studs along x, as the walk's session first did: refused,
##   nothing laid, and the refusal says the plate's span, the span a quarter
##   turn gives it at the same corner, and where the headlight would stand.
## - Turned, it is built, and answered as CAD: each part's span and what holds
##   it, none of the designer's method; its save asks for no fresh look. A wall
##   of eight bricks is answered so too.
## - The pod with a feature named, and a wall of 24 bricks naming none, are
##   designs: each answer has the method.
## - attachment_points of the pod's five parts in one call answers what the
##   walk's five calls did, word for word and in order, and says how a turn
##   moves a part.
## - in_view, with a model of nine steps at step 4, a 1 x 2 in hand turned
##   rot 1 with its ghost over the floor, and a plan laid on the floor, says
##   the step, the part, its colour, which way it points and the span its
##   ghost takes, and the picture; and changes nothing.
extends SceneTree

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _assistant: Assistant
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _camera: CadCamera
var _next: int = 0
var _shots: String = ""

## Words of the designer's method (Assistant.FROM_OUTSIDE_NEXT) a CAD answer
## must not carry.
const METHOD_WORDS: Array[String] = ["review_model", "settle_feature", "surface pass",
	"creative pass", "own designer", "silhouette", "fresh pair of eyes"]

## The walk's side pod (APP_UX3, task s1), as its session first submitted it:
## the plate at rot 0, six studs along x.
const POD: Array = [
	{"part": "3032", "color": 4, "x": 0, "y": 0, "z": 0},
	{"part": "41770a", "color": 71, "x": 2, "y": 1, "z": 2},
	{"part": "3040", "color": 4, "x": 3, "y": 1, "z": 0, "rot": 2},
	{"part": "4070", "color": 4, "x": 1, "y": 1, "z": 5},
	{"part": "54200", "color": 4, "x": 1, "y": 4, "z": 5},
]

## What the walk's session asked attachment_points about, in five calls.
const ASKED: Array = [
	{"part": "41770a", "x": 2, "y": 1, "z": 1, "rot": 0},
	{"part": "4070", "x": 3, "y": 1, "z": 5, "rot": 0},
	{"part": "3040", "x": 2, "y": 1, "z": 0, "rot": 0},
	{"part": "3040", "x": 3, "y": 1, "z": 0, "rot": 2},
	{"part": "54200", "x": 1, "y": 4, "z": 5, "rot": 0},
]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_camera = _main.get("_camera")
	_assistant = _main.get("_assistant")
	_socket = CommandSocket.new()
	_socket.assistant = _assistant
	_socket.app = _main
	_main.add_child(_socket)
	if DisplayServer.get_name() != "headless":
		_shots = OS.get_environment("MCPCAD_SHOTS")
		if _shots.is_empty():
			_shots = OS.get_user_data_dir().path_join("mcpcad_probe")
		DirAccess.make_dir_recursive_absolute(_shots)
	await process_frame

	await _cad_and_design()
	await _points_in_one_call()
	await _in_view()
	print("")
	print("mcpcad: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- CAD answers and design answers ------------------------------------------------


func _cad_and_design() -> void:
	print("── the side pod, refused and then built ──")
	await _say("clear_model", {})
	var refused: String = await _say("submit_design", _pod(POD, []))
	print(refused.indent("    "))
	_check("the pod with its plate along x is refused, nothing laid",
		refused.begins_with("Not applied") and _model_ids().is_empty())
	_check("...and the refusal says the plate's span: x 0..6, z 0..4",
		refused.contains("brick 0's (3032 at 0,0,0): x 0..6, z 0..4"))
	_check("...the span a quarter turn gives it at the same corner, under the headlight",
		refused.contains("with rot 1, a quarter turn at the same corner, it would take x 0..4, z 0..6"))
	_check("...and where the headlight would stand on it",
		refused.contains("brick 3 (4070 at 1,1,5)") and refused.contains("At 1,1,3 it would stand on it"))
	_check("...and not the cheese slope that stands on the headlight",
		not refused.contains("brick 4 (54200 at 1,4,5) takes"))

	var turned: Array = POD.duplicate(true)
	turned[0]["rot"] = 1
	var built: String = await _say("submit_design", _pod(turned, []))
	print(built.indent("    "))
	var ids: Array[int] = _model_ids()
	_check("turned, the pod is built: 5 parts (%d)" % ids.size(),
		built.begins_with("Built. 5 bricks on the baseplate. 5 bricks, buildable, one piece.") and ids.size() == 5)
	_check("...answered as CAD, with none of the designer's method (%s)" % _said_of(built),
		_said_of(built).is_empty() and not _assistant._outside_designed)
	var plate: int = _id_of("3032")
	var light: int = _id_of("4070")
	_check("...each part's span and what holds it: the plate x 0..4, z 0..6, on the ground",
		_row(built, plate).contains("x 0..4  z 0..6") and _row(built, plate).contains("on the ground"))
	_check("...the headlight on the plate, the cheese slope on the headlight",
		_row(built, light).contains("on #%d by 1 stud" % plate)
		and _row(built, _id_of("54200")).contains("on #%d by 1 stud" % light))
	var saved: String = await _say("save_model", {"name": "mcpcad side pod"})
	_check("...and its save asks for no fresh look and no designer's pass (%s)" % _said_of(saved),
		saved.begins_with("Written") and _said_of(saved).is_empty()
		and not saved.contains("Before it is finished"))

	print("── designs ──")
	var named: String = await _say("submit_design", _pod(turned, ["headlights"]))
	_check("the same parts with a feature named are a design, told the method",
		named.begins_with("Built.") and named.contains("review_model with no assembly")
		and _assistant._outside_designed)
	var big: String = await _say("submit_design", {"name": "Long wall",
		"description": "a wall of 24 bricks", "floor": "none", "bricks": _wall(3, 8, "3004", 2)})
	_check("a wall of 24 bricks naming no feature is a design, told the method",
		big.begins_with("Built.") and big.contains("review_model with no assembly"))
	await _say("clear_model", {})
	var small: String = await _say("submit_design", {"name": "Red wall",
		"description": "eight red 1x4 bricks in running bond", "bricks": _wall(2, 4, "3010", 4)})
	_check("a wall of eight bricks is answered as CAD (%s)" % small.get_slice("\n", 0),
		small.begins_with("Built. 8 bricks") and _said_of(small).is_empty())


func _pod(bricks: Array, features: Array) -> Dictionary:
	return {"name": "Little side pod", "description": "a red 4x6 plate with a wing, a slope "
		+ "and a headlight", "floor": "none", "bricks": bricks, "features": features,
		"assemblies": [{"name": "side pod", "x_from": 0, "x_to": 4, "z_from": 0, "z_to": 6}]}


## A running bond of [param courses] courses of [param across] bricks of
## [param part], [param long] studs long.
static func _wall(courses: int, across: int, part: String, long: int) -> Array:
	var bricks: Array = []
	for course: int in courses:
		for n: int in across:
			bricks.append({"part": part, "color": 4, "x": n * long + (course % 2) * (long / 2),
				"y": course * 3, "z": 0})
	return bricks


static func _said_of(answer: String) -> String:
	var found := PackedStringArray()
	for word: String in METHOD_WORDS:
		if answer.contains(word):
			found.append(word)
	return ", ".join(found)


## The CAD answer's row for brick [param brick_id].
static func _row(answer: String, brick_id: int) -> String:
	for line: String in answer.split("\n"):
		if line.strip_edges().begins_with("#%d " % brick_id):
			return line
	return ""


func _id_of(part: String) -> int:
	for brick_id: int in _model_ids():
		if _world.get_brick(brick_id).part_id == part:
			return brick_id
	return -1


# -- places in one call -----------------------------------------------------------


func _points_in_one_call() -> void:
	print("── attachment_points, five parts in one call ──")
	var each := PackedStringArray()
	for one: Dictionary in ASKED:
		each.append(await _say("attachment_points", one))
	var together: String = await _say("attachment_points", {"parts": ASKED})
	var at: int = 0
	var in_order: bool = true
	for n: int in each.size():
		var found: int = together.find("%d. %s" % [n + 1, each[n]], at)
		in_order = in_order and found >= at
		at = maxi(at, found)
	_check("one call answers what the walk's five did, word for word and in order (%d chars)"
		% together.length(), in_order and not each[0].is_empty())
	_check("...and says how a turn moves a part",
		together.contains("What points +z at rot 0 points +x at rot 1, -z at rot 2 and -x at rot 3"))


# -- what the person sees ----------------------------------------------------------


func _in_view() -> void:
	print("── in_view: step 4 of 9, a part in hand, a picture laid ──")
	_main.call("clear_model")
	await _frames(5)
	var path: String = OS.get_user_data_dir().path_join("mcpcad_nine_steps.ldr")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(_nine_steps())
	file.close()
	var placed: int = _store.open(path)
	(_main.get("_bar") as ModelBar).opened.emit(placed)
	await _frames(20)
	var plan := Image.create_empty(400, 300, false, Image.FORMAT_RGBA8)
	plan.fill(Color(0.95, 0.95, 0.9))
	plan.fill_rect(Rect2i(40, 40, 120, 80), Color(0.1, 0.3, 0.8))
	var reference: ReferenceImage = _main.get("_reference")
	reference.take(plan, "plan.png")
	await _frames(5)
	(reference.controls_by_name()["reference_dialog"] as AcceptDialog).hide()
	_shell.run("timeline")
	var steps: StepsBar = _main.get("_steps")
	for _n: int in 600:
		await process_frame
		if steps.is_playing_back() and not steps.is_starting():
			break
	steps.to_start()
	for _n: int in 4:
		steps.step_forward()
	await _frames(3)
	var step: Instructions.Step = steps.current_step()
	var all: Array[Instructions.Step] = steps.steps()
	_main.call("_on_part_chosen", "3004")
	_builder.held_color = 1
	_builder.held_rotation = 1
	await _frames(3)
	# The pointer over the floor beside the stack, as a mouse puts it there:
	# a headless run has no pointer of its own.
	_builder.update_preview(Vector3(250.0, 400.0, 150.0), Vector3.DOWN)
	var verbs: EditVerbs = _main.get("_verbs")
	var box: AABB = _ghost_box()
	var ghost: String = "" if not box.has_volume() else "x %s to %s, z %s to %s, y %s to %s plates" % [
		HandTools._n(box.position.x), HandTools._n(box.end.x), HandTools._n(box.position.z),
		HandTools._n(box.end.z), HandTools._n(box.position.y), HandTools._n(box.end.y)]
	var model: Array = _signature(_model_ids())
	var depth: int = _builder.history_depth()
	var kept: Dictionary = reference.said()
	var timeline: Vector2i = steps.timeline_at()
	var aimed: Variant = _builder.ghost_place()
	var answer: Dictionary = await _rpc("tools/call", {"name": "in_view", "arguments": {}})
	var said: String = _text(answer)
	print(said.indent("    "))
	_check("the model has nine steps, the timeline at step 4 (%d of %d)" % [
		step.number if step != null else -1, all.size()],
		all.size() == 9 and step != null and step.number == 4)
	_check("in_view says the step: at step 4 of 9", said.contains("at step 4 of 9"))
	_check("...the part in hand and its colour: Brick 1 x 2 (3004) in Blue (1)",
		said.contains("Brick 1 x 2 (3004) in Blue (1)") and said.contains("the Place tool"))
	_check("...which way it points: its studs up, rot 1", said.contains("its studs up, rot 1"))
	_check("...and the span its ghost takes, 1 stud across and 2 deep (%s)" % ghost,
		not ghost.is_empty() and said.contains("its ghost under the pointer takes %s" % ghost)
		and is_equal_approx(box.size.x, 1.0) and is_equal_approx(box.size.z, 2.0))
	_check("...and the reference picture laid on the floor, with its picture",
		said.contains("plan.png") and said.contains("on the floor") and _has_picture(answer))
	_check("...and nothing changed: the model, the history, the picture, the timeline, the hand",
		_signature(_model_ids()) == model and _builder.history_depth() == depth
		and _builder.ghost_place() == aimed
		and ReferenceImage.same(reference.said(), kept) and steps.timeline_at() == timeline
		and _builder.held_part == "3004" and _builder.held_rotation == 1
		and _builder.held_color == 1 and verbs.mode == "place")
	await _shot("in_view")


## Nine 2 x 4 bricks stacked, each a step of the author's.
static func _nine_steps() -> String:
	var lines := PackedStringArray(["0 Nine steps", "0 Name: mcpcad_nine_steps.ldr",
		"0 Author: mcpcad_probe"])
	for n: int in 9:
		lines.append("1 %d 0 %d 0 1 0 0 0 1 0 0 0 1 3001.dat" % [[4, 1, 14, 2][n % 4], -24 * n])
		lines.append("0 STEP")
	return "\n".join(lines) + "\n"


## The span the ghost takes, in studs across and deep and plates up, worked
## out here from the builder's own cover of it; empty when none shows.
func _ghost_box() -> AABB:
	if _builder.ghost_place() == null:
		return AABB()
	var library: PartLibrary = _main.get("_library")
	var packed: PackedInt32Array = _builder.boxes_for(library.mesh_for(_builder.held_part),
		_builder.ghost_transform())
	if packed.is_empty():
		return AABB()
	var lo := Vector3i(packed[0], packed[1], packed[2])
	var hi := Vector3i(packed[3], packed[4], packed[5])
	for n: int in range(6, packed.size(), 6):
		lo = lo.min(Vector3i(packed[n], packed[n + 1], packed[n + 2]))
		hi = hi.max(Vector3i(packed[n + 3], packed[n + 4], packed[n + 5]))
	var scale := Vector3(1.0 / 20.0, 1.0 / 8.0, 1.0 / 20.0)
	var low: Vector3 = BrickLattice.to_ldu(lo) * scale
	return AABB(low, BrickLattice.to_ldu(hi) * scale - low)


static func _has_picture(answer: Dictionary) -> bool:
	for block: Dictionary in answer.get("content", []):
		if str(block.get("type", "")) == "image":
			return true
	return false


# -- helpers ----------------------------------------------------------------------


func _model_ids() -> Array[int]:
	var ids: Array[int] = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			ids.append(brick.id)
	ids.sort()
	return ids


## Each part as what it is and where, sorted.
func _signature(ids: Array) -> Array:
	var rows: Array = []
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null:
			continue
		rows.append("%s|%d|%s" % [brick.part_id, brick.color_code, brick.transform])
	rows.sort()
	return rows


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _say(tool: String, arguments: Dictionary) -> String:
	return _text(await _rpc("tools/call", {"name": tool, "arguments": arguments}))


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## What the person sees, kept when there is a window to see it in.
func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	await _frames(20)
	await RenderingServer.frame_post_draw
	var size: Vector2i = DisplayServer.window_get_size()
	root.get_viewport().get_texture().get_image().save_png(
		_shots.path_join("%s_%dx%d.png" % [name, size.x, size.y]))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
