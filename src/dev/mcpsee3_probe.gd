## Does a session keep the person's view, and pick a part out the first time
## (APP_UX6 #3, mcpsee3)? Each tool called the way the connector and the
## desktop's MCP port call it (CommandSocket.answer_rpc, tools/call).
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 \
##       --script src/dev/mcpsee3_probe.gd
##
## PROBE_SIZE=1280x720 tools/probe.sh mcpsee3 runs it at a laptop's size.
## Keeps every picture a call answered with, and the window's, in
## MCPSEE3_SHOTS, or user://mcpsee3_probe.
##
## On the MCP walk's Pods (src/dev/fixtures/mcp_walk_pods.ldr, saved by its
## session in APP_UX6's walk), opened as that session opened it:
##   1. view_board's highlight= with 4070 as sessions sent it, "4070",
##      "\"4070\"" and "'4070'", each picks out exactly #6 and #11, the two
##      headlight bricks, the rest drawn see-through; xray= the same; the
##      description shows no part number in quotes, and a refusal echoes
##      what was sent without quotes of its own (the walk's u2 and v3 were
##      refused, and v3 called it a bug);
##   2. save_view {"name": "Three quarter"} keeps the window's view in 1
##      call, answered with the model from there; in_view lists it with its
##      key; the window looked away, its key (Alt+Shift+N) brings the camera
##      back within 0.1° and 0.1 LDU; render_model {"view": "Three quarter"}
##      draws from where the window was, its camera within 0.1° and 0.1 LDU
##      of a render of the window then; remove=true takes a view out (the
##      walk's v4 could only tell the person how to save one).
## Written to run on a build without them (pre261): there it fails, it does
## not stop.
extends SceneTree

const PODS := "res://src/dev/fixtures/mcp_walk_pods.ldr"
## The walk's session saw the two headlight bricks as these (v2, v3).
const HEADLIGHTS: Array = [6, 11]
const NAME := "Three quarter"
## What is "back": the bar's.
const DEGREES := 0.1
const LDU := 0.1

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _store: ModelStore
var _camera: Camera3D
var _next: int = 0
var _shots: String = ""
var _window: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	Engine.max_fps = 0
	BookletMaker.open_when_written = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_store = _main.get("_store")
	_camera = _main.get("_camera")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	var size: Vector2i = DisplayServer.window_get_size()
	_window = "%dx%d" % [size.x, size.y]
	_shots = OS.get_environment("MCPSEE3_SHOTS")
	if _shots.is_empty():
		_shots = OS.get_user_data_dir().path_join("mcpsee3_probe")
	_shots = _shots.path_join(_window)
	DirAccess.make_dir_recursive_absolute(_shots)
	print("mcpsee3: the window %s, pictures in %s" % [_window, _shots])
	if not ModelShot.possible():
		print("mcpsee3 probe: SKIPPED: no window to draw in")
		quit(3)
		return

	await _listed()
	await _open_pods()
	await _picked_out()
	await _saved()
	await _frames(10)
	await _shoot("window")
	print("")
	print("mcpsee3: %s (%s)" % ["every check passed" if _failures == 0
		else "%d FAILED" % _failures, _window])
	quit(1 if _failures > 0 else 0)


# -- what a session is told -----------------------------------------------------------


func _listed() -> void:
	print("")
	print("── what tools/list says ──")
	var listed: Dictionary = await _rpc("tools/list", {})
	var tools: Dictionary = {}
	for tool: Dictionary in listed.get("tools", []):
		tools[str(tool["name"])] = tool
	var takes: Dictionary = ((tools.get("view_board", {}) as Dictionary).get("inputSchema",
		{}) as Dictionary).get("properties", {})
	var said: String = str((takes.get("highlight", {}) as Dictionary).get("description", ""))
	print("    highlight: " + said)
	_check("view_board's highlight= shows a part number bare: 3024, never \"3024\"",
		said.contains("3024") and not said.contains("\"3024\"") and not said.contains("“3024”"))
	var save: Dictionary = tools.get("save_view", {})
	var schema: Dictionary = (save.get("inputSchema", {}) as Dictionary).get("properties", {})
	_check("tools/list has save_view, which takes name=", schema.has("name"))
	var hint: Dictionary = save.get("annotations", {})
	_check("...and says it changes the model, and nothing is lost by it (%s)" % str(hint),
		hint.get("readOnlyHint", true) == false and hint.get("destructiveHint", true) == false)


func _open_pods() -> void:
	print("")
	print("── the walk's Pods, opened as its session opened it ──")
	DirAccess.make_dir_recursive_absolute(ModelStore.SAVE_DIR)
	var copied: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(PODS),
		ProjectSettings.globalize_path(ModelStore.SAVE_DIR + "Pods.ldr"))
	await _rpc("tools/call", {"name": "clear_model", "arguments": {}})
	var opened: Dictionary = await _rpc("tools/call", {"name": "open_model",
		"arguments": {"name": "Pods"}})
	_print(_text(opened).left(300))
	await _settled()
	var lights: Array = _of_part("4070")
	_check("Pods opens: %d parts, its headlight bricks #%s" % [_parts(),
		", #".join(PackedStringArray(lights.map(func(n: int) -> String: return str(n))))],
		copied == OK and _parts() == 36 and lights == HEADLIGHTS)


# -- 1. a part number, however it is quoted ------------------------------------------


func _picked_out() -> void:
	print("")
	print("── 1. highlight= and xray= take 4070 however it is sent ──")
	var model: Array = _signature()
	for sent: String in ["4070", "\"4070\"", "'4070'"]:
		var answer: Dictionary = await _rpc("tools/call", {"name": "view_board",
			"arguments": {"views": ["corner", "top"], "highlight": sent}})
		var said: String = _text(answer)
		_print(said)
		var shown: Array[Image] = _images(answer)
		# A refusal draws nothing: the last picture's parts are not this one's.
		var drawn: Array = _edged() if shown.size() == 1 else []
		_check("highlight=%s picks out exactly #6 and #11 in 1 call: %s, one picture" % [
			JSON.stringify(sent), "#" + ", #".join(PackedStringArray(drawn.map(
				func(n: int) -> String: return str(n)))) if not drawn.is_empty() else "none"],
			shown.size() == 1 and drawn == HEADLIGHTS and said.contains("4070, every"))
		if shown.size() == 1:
			shown[0].save_png(_shots.path_join("1_highlight_%s.png" % sent.replace("\"", "dq")
				.replace("'", "sq")))
	var through: Dictionary = await _rpc("tools/call", {"name": "view_board",
		"arguments": {"views": ["corner"], "xray": "'4070'"}})
	_print(_text(through))
	_check("xray=\"'4070'\" sees through the two of them",
		_images(through).size() == 1 and _text(through).contains("Seen through: 4070, every"))
	if _images(through).size() == 1:
		_images(through)[0].save_png(_shots.path_join("1_xray.png"))
	# 3001 is a part, and none of Pods'.
	var refused: String = _text(await _rpc("tools/call", {"name": "view_board",
		"arguments": {"views": ["corner"], "highlight": "\"3001\""}}))
	_print(refused)
	_check("a part not in the model is refused, echoing what was sent as it was sent",
		refused.contains("no \"3001\" in the model") and not refused.contains("\"\"3001")
		and not refused.contains("(\"3024\")"))
	_check("looking changed nothing", _signature() == model)


## The parts the last view_board drew edged, by their numbers: every other
## part is see-through and left out of its codes (SeeTools, ModelShot).
func _edged() -> Array:
	var tools: AppTools = _socket.call("_the_app_tools")
	var see: Object = tools.get("_see") if tools != null else null
	var shot: ModelShot = see.get("_shot") if see != null else null
	if shot == null or shot.get("_codes_stage") == null:
		return []
	var out: Array = []
	for staged: BrickWorld.Brick in (shot.get("_codes_stage") as BrickWorld).bricks():
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id == staged.part_id and brick.transform.origin.is_equal_approx(
					staged.transform.origin) and not out.has(brick.id):
				out.append(brick.id)
	out.sort()
	return out


# -- 2. a view kept by a session -----------------------------------------------------


func _saved() -> void:
	print("")
	print("── 2. save_view keeps the window's view ──")
	var box: AABB = _world.model_bounds()
	var middle: Vector3 = box.get_center()
	_camera.call("square_on", false)
	_camera.call("aim_at", {"yaw": 0.63, "pitch": 0.47, "distance": 360.0,
		"focus": [middle.x - 14.0, middle.y + 6.0, middle.z + 10.0]})
	await _at_rest()
	var was: Transform3D = _camera.global_transform
	await _shoot("2_window_at_the_view")
	var dialog: RenderDialog = _main.get("_render")
	# The window's own render from here, as render_model view= is to match.
	var reference: Array = await _render_of_window(dialog)

	var before: int = (_world.get("saved_views") as Array).size()
	var answer: Dictionary = await _rpc("tools/call", {"name": "save_view",
		"arguments": {"name": NAME}})
	var said: String = _text(answer)
	_print(said)
	var views: Array = _world.get("saved_views")
	var at: int = SavedViews.index_of(views, NAME)
	_check("save_view {\"name\": \"%s\"} keeps it in 1 call, answered with the model from there"
		% NAME, at >= 0 and views.size() == before + 1 and said.contains(NAME)
		and _images(answer).size() == 1)
	if _images(answer).size() == 1:
		_images(answer)[0].save_png(_shots.path_join("2_save_view.png"))
	if at < 0:
		return
	var key: String = Keymap.written("saved_view_%d" % (at + 1))
	_check("...and says its key (%s) and view= by its name" % key,
		not key.is_empty() and said.contains(key) and said.contains("view="))
	_check("a session's save is unsaved work until the model is saved, as the window's is",
		_store.has_unsaved_work())

	var seen: String = _text(await _rpc("tools/call", {"name": "in_view",
		"arguments": {"picture": false}}))
	_print(seen)
	_check("in_view lists “%s” with its key" % NAME,
		seen.contains("“%s” (%s)" % [NAME, key]))

	# Looked away, then back by its key, as the person would.
	_camera.call("aim_at", {"yaw": -2.1, "pitch": 0.15, "distance": 900.0, "focus": [0, 0, 0]})
	await _at_rest()
	root.gui_release_focus()
	await _press(int(Keymap.key_of("saved_view_%d" % (at + 1))))
	await _at_rest()
	var now: Transform3D = _camera.global_transform
	var off: float = now.origin.distance_to(was.origin)
	var angle: float = rad_to_deg(Quaternion(now.basis.orthonormalized()).angle_to(
		Quaternion(was.basis.orthonormalized())))
	_check("%s looks from “%s” again: %.4f LDU and %.4f° from where the window was"
		% [key, NAME, off, angle], off <= LDU and angle <= DEGREES)
	await _shoot("2_window_by_its_key")

	# Looked away again: render_model draws from the view, not the window.
	_camera.call("aim_at", {"yaw": 2.6, "pitch": 0.9, "distance": 700.0, "focus": [0, 0, 0]})
	await _at_rest()
	var rendered: Dictionary = await _finished(await _rpc("tools/call", {"name": "render_model",
		"arguments": {"view": NAME, "quality": "quick", "size": "720p"}}))
	_print(_text(rendered).left(240))
	var shot: StudioRender.Shot = dialog.renderer.last_shot if dialog.renderer != null else null
	var picture: Image = dialog.last_picture()
	if shot == null or reference.is_empty() or picture == null:
		_check("render_model {\"view\": \"%s\"} renders it" % NAME, false)
		return
	var then: StudioRender.Shot = reference[0]
	var shot_off: float = shot.origin.distance_to(then.origin)
	var shot_angle: float = rad_to_deg(Quaternion(shot.basis.orthonormalized()).angle_to(
		Quaternion(then.basis.orthonormalized())))
	var apart: float = _rmse(picture, reference[1] as Image)
	_check("render_model {\"view\": \"%s\"} draws from where the window was: its camera %.4f LDU and %.4f° off, the picture %.4f apart"
		% [NAME, shot_off, shot_angle, apart],
		shot_off <= LDU and shot_angle <= DEGREES and apart <= 0.005)
	picture.save_png(_shots.path_join("2_render_model.png"))
	(reference[1] as Image).save_png(_shots.path_join("2_render_of_window.png"))

	# A spare one, taken out again by its name as quoted.
	await _rpc("tools/call", {"name": "save_view", "arguments": {"name": "Spare",
		"picture": false}})
	var kept: int = (_world.get("saved_views") as Array).size()
	var out: String = _text(await _rpc("tools/call", {"name": "save_view",
		"arguments": {"name": "'Spare'", "remove": true}}))
	_print(out)
	_check("remove=true takes “Spare” out, “%s” kept" % NAME,
		kept == before + 2 and (_world.get("saved_views") as Array).size() == before + 1
		and SavedViews.index_of(_world.get("saved_views"), NAME) == at)


## A quick 720p render of the window as it looks now, as render_model's own
## settings draw one: [its camera, its picture], or [] when none came.
func _render_of_window(dialog: RenderDialog) -> Array:
	var chosen: RenderSettings = dialog.settings.copy()
	chosen.quality = RenderSettings.Quality.QUICK
	chosen.size = Vector2i(1280, 720)
	chosen.look = "window"
	chosen.view = "current"
	chosen.forget_eye()
	chosen.keep_eye(_camera)
	if dialog.renderer == null:
		dialog.call("_make_renderer")
	while dialog.renderer.is_busy():
		await process_frame
	var picture: Image = await dialog.renderer.render(_world, chosen)
	if picture == null or dialog.renderer.last_shot == null:
		return []
	var shot := StudioRender.Shot.new()
	shot.origin = dialog.renderer.last_shot.origin
	shot.basis = dialog.renderer.last_shot.basis
	return [shot, picture]


# -- helpers --------------------------------------------------------------------------


func _of_part(part: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and brick.part_id.to_lower() == part:
			out.append(brick.id)
	out.sort()
	return out


func _parts() -> int:
	return _world.brick_count() - _store.scenery.size()


func _signature() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		out.append([brick.id, brick.part_id, brick.color_code, brick.transform])
	return out


## The camera come to rest where it was sent.
func _at_rest() -> void:
	for _n: int in 900:
		await process_frame
		if is_equal_approx(float(_camera.get("_yaw")), float(_camera.get("_target_yaw"))) \
				and float(_camera.get("_pitch")) == float(_camera.get("_target_pitch")) \
				and float(_camera.get("distance")) == float(_camera.get("_target_distance")) \
				and (_camera.get("focus") as Vector3) == (_camera.get("_target_focus") as Vector3) \
				and (_camera.get("_frame") as Basis) == (_camera.get("_target_frame") as Basis):
			break
	await _frames(3)


## A key and its modifiers, down and up, as the window delivers them.
func _press(accel: int) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = Keymap.press_of(accel)
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(4)


func _settled() -> void:
	for _n: int in 600:
		await process_frame
		if (_world.get("_dirty") as Dictionary).is_empty() \
				and not bool(_world.get("_rebuild_queued")) and _store.awaited.is_empty():
			break
	await _frames(3)


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_shots.path_join(name + ".png"))


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _finished(result: Dictionary) -> Dictionary:
	var found: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(_text(result))
	if found == null:
		return result
	for _n: int in 600:
		var polled: Dictionary = await _rpc("tools/call", {"name": "job", "arguments":
			{"id": int(found.get_string(1))}})
		if not _text(polled).contains(" is still going"):
			return polled
	return {"content": [{"type": "text", "text": "the job never ended"}]}


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


static func _images(result: Dictionary) -> Array[Image]:
	var out: Array[Image] = []
	for block: Dictionary in result.get("content", []):
		if str(block.get("type", "")) == "image":
			var picture := Image.new()
			if picture.load_png_from_buffer(Marshalls.base64_to_raw(str(block.get("data", "")))) == OK:
				out.append(picture)
	return out


static func _rmse(a: Image, b: Image) -> float:
	var first: Image = a.duplicate() as Image
	var second: Image = b.duplicate() as Image
	first.convert(Image.FORMAT_RGB8)
	second.convert(Image.FORMAT_RGB8)
	if first.get_size() != second.get_size():
		return 1.0
	var one: PackedByteArray = first.get_data()
	var two: PackedByteArray = second.get_data()
	var sum: float = 0.0
	for n: int in one.size():
		var d: float = float(one[n] - two[n])
		sum += d * d
	return sqrt(sum / float(maxi(one.size(), 1))) / 255.0


func _print(said: String) -> void:
	print("    " + said.replace("\n", "\n    "))


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
