## The window's hand tools for a session (APP_UX3, mcphand): Mirror, Split,
## Merge and Measure, and what the person sees, each called the way the
## connector and the desktop's MCP port call it (CommandSocket.answer_rpc,
## tools/call) and read back off the model, against what the window's own
## command does to the same parts.
##
##   godot --headless --path . --script src/dev/mcphand_probe.gd
##
## Windowed (tools/probe.sh mcphand), it also keeps pictures of what the
## person sees before and after in MCPHAND_SHOTS, or user://mcphand_probe.
##
## - The car's left half mirrored by mirror_parts in 1 call is, part for
##   part, what the window's Shift+M gives the same parts; one undo step, the
##   person's selection as it was. A copy across the car's middle with its
##   right half taken off lays that right half again; a mirror whose image
##   would run into a part is refused, nothing changed.
## - A 2 x 2 slope split, and six 1 x 1 plates merged into a 2 x 3, in 1
##   call each, are what Alt+S and Alt+M give; a part that does not split is
##   refused, nothing changed.
## - A hinge brick left at 37° by the window's own swing is measured as
##   37.0°, within 0.1°: the turn between its halves, as attach's yaw, and the
##   angle between a stud on each half. Two beams' pin holes are said as the
##   window's Measure says them.
## - in_view names the step the timeline is at, the part in hand and the
##   reference picture a person laid, with the picture and the model drawn
##   on it; and changes nothing.
extends SceneTree

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _camera: CadCamera
var _next: int = 0
var _shots: String = ""

## How high the small cases are laid, LDU: in the air, clear of the floor,
## as splitmerge_probe lays them.
const LIFT := 96.0


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
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_camera = _main.get("_camera")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	if DisplayServer.get_name() != "headless":
		_shots = OS.get_environment("MCPHAND_SHOTS")
		if _shots.is_empty():
			_shots = OS.get_user_data_dir().path_join("mcphand_probe")
		DirAccess.make_dir_recursive_absolute(_shots)
	await process_frame

	var listed: Dictionary = await _rpc("tools/list", {})
	var names: Array = (listed.get("tools", []) as Array).map(
		func(tool: Dictionary) -> String: return str(tool["name"]))
	_check("tools/list offers %s" % ", ".join(HandTools.NAMES),
		HandTools.NAMES.all(func(name: String) -> bool: return names.has(name)))
	_check("Mirror, Split, Merge and Measure are done by a tool, no longer the window's alone",
		AppTools.COMMANDS.get("mirror") == "mirror_parts"
		and AppTools.COMMANDS.get("split_parts") == "split_parts"
		and AppTools.COMMANDS.get("merge_parts") == "merge_parts"
		and AppTools.COMMANDS.get("measure") == "measure"
		and not AppTools.WINDOW_ONLY.has("mirror") and not AppTools.WINDOW_ONLY.has("measure"))

	await _mirror()
	await _split_merge()
	await _measure()
	await _in_view()
	print("")
	print("mcphand: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- mirror -----------------------------------------------------------------------


func _mirror() -> void:
	print("── mirror_parts on the car ──")
	await _open_car()
	var all: Array[int] = _model_ids()
	var middle: float = _box(all).get_center().x
	var left: Array[int] = []
	var right: Array[int] = []
	for brick_id: int in all:
		var x: float = _box([brick_id]).get_center().x
		if x < middle - 5.0:
			left.append(brick_id)
		elif x > middle + 5.0:
			right.append(brick_id)
	var handed: int = 0
	for brick_id: int in left:
		if not Mirror.counterpart(_library, _world.get_brick(brick_id).part_id).is_empty():
			handed += 1
	_check("the car: %d parts, %d on its left, %d on its right, %d of the left made in a left and a right hand"
		% [all.size(), left.size(), right.size(), handed], left.size() >= 10 and handed > 0)
	var model: Array = _signature(all)

	# The window: the left half selected, Shift+M, seen from the front.
	_camera.set_view("front")
	for _n: int in 600:
		await process_frame
		if _camera.global_transform.basis.x.x > 0.999:
			break
	_check("Shift+M is the window's Mirror (%s)" % _shell.key_words("mirror"),
		_shell.key_words("mirror") == "Shift+M")
	_select(left)
	await _shot("mirror_before")
	var before: Dictionary = _ids_now()
	var depth: int = _builder.history_depth()
	_shell.run("mirror")
	await _frames(5)
	var window: Array = _signature(_made_since(before))
	_check("the window's Shift+M mirrors the %d left parts in one step" % window.size(),
		window.size() == left.size() and _builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(2)
	_check("...and one undo puts the car back", _signature(_model_ids()) == model)

	# A session: the same parts by number, the person's selection elsewhere.
	var picked: Array[int] = [right[0]]
	_select(picked)
	depth = _builder.history_depth()
	before = _ids_now()
	var said: String = await _say("mirror_parts", {"bricks": left})
	print("    said: %s" % said)
	var made: Array = _made_since(before)
	var session: Array = _signature(made)
	_check("mirror_parts mirrors them in 1 call, part for part what Shift+M gave (%d of %d alike)"
		% [_alike(session, window), window.size()], session == window)
	_check("...left and right parts swapped, and said (%d)" % handed, said.contains("other hand"))
	_check("...one undo step", _builder.history_depth() == depth + 1)
	_check("...and the person's selection is as it was",
		_builder.selection.keys() == [right[0]])
	await _shot("mirror_after")
	said = await _say("undo", {})
	_check("undo puts the car back: %s" % said.left(60), _signature(_model_ids()) == model)

	# The left half laid again as the right: a copy across the car's middle.
	var right_was: Array = _signature(right)
	var right_covers: Array = _covers(right)
	var left_was: Array = _signature(left)
	_builder.selection.clear()
	for brick_id: int in right:
		_builder.selection[brick_id] = true
	_builder.remove_selection()
	before = _ids_now()
	var across: float = snappedf(middle / 20.0, 0.5)
	said = await _say("mirror_parts", {"bricks": left, "copy": true, "across": across})
	print("    said: %s" % said)
	var copy: Array = _signature(_made_since(before))
	var covers: Array = _covers(_made_since(before))
	_check("a copy across x = %s with the right half off lays the right half again (%d of %d alike, %d of %d covering what it did)"
		% [across, _alike(copy, right_was), right_was.size(), _alike(covers, right_covers),
			right_covers.size()], covers == right_covers)
	_check("...and the left half stays as it was", _signature(left) == left_was)
	_builder.undo()
	_builder.undo()
	await _frames(2)
	_check("two undos put the car back", _signature(_model_ids()) == model)

	# Refused where the image runs into a part: beside the left half is the
	# car's middle, and a copy across their own middle is on themselves.
	depth = _builder.history_depth()
	said = await _say("mirror_parts", {"bricks": left, "copy": true})
	_check("a copy beside the left half, onto the car's middle, is refused: %s" % said.left(70),
		said.begins_with("Not mirrored") and _signature(_model_ids()) == model)
	said = await _say("mirror_parts", {"bricks": left, "copy": true, "across": snappedf(
		_box(left).get_center().x / 20.0, 0.5)})
	_check("a copy onto themselves is refused, nothing changed: %s" % said.left(70),
		said.begins_with("Not mirrored") and _signature(_model_ids()) == model
		and _builder.history_depth() == depth)
	said = await _say("mirror_parts", {"bricks": [left[0]], "across": 0.3})
	_check("across= off a half stud is refused: %s" % said.left(60), said.contains("half number"))

	# A side pod and its mirror image beside it, the walk's s2: a plate and
	# a left wing plate, copied across their right side.
	_main.call("clear_model")
	await _frames(5)
	var plate: int = _put("3020", 4, Vector3(0, LIFT, 0))
	var wing: int = _put("41770", 71, Vector3(0, LIFT, 100))
	var pod: Array[int] = [plate, wing]
	var pod_was: Array = _signature(pod)
	# Seen from above at an angle, where a pod and its mirror read as a pair,
	# both pictures framed on the pod and the room its mirror takes beside it.
	var pair: AABB = _box(pod)
	pair.size.x *= 2.0
	_camera.set_view("isometric")
	await _frames(90)
	await _shot("pod_before", pair)
	before = _ids_now()
	said = await _say("mirror_parts", {"bricks": pod, "copy": true})
	print("    said: %s" % said)
	made = _made_since(before)
	await _shot("pod_after", pair)
	var parts: Array = made.map(func(brick_id: int) -> String:
		return _world.get_brick(brick_id).part_id)
	parts.sort()
	_check("the pod's mirror image beside it in 1 call, the left wing a right one (%s), from x %s"
		% [", ".join(parts), HandTools._n(_box(made).position.x / 20.0)], parts.size() == 2
		and parts[0] == "3020" and str(parts[1]).begins_with("41769")
		and _signature(pod) == pod_was and _box(made).position.x >= _box(pod).end.x - 0.01)


# -- split and merge --------------------------------------------------------------


func _split_merge() -> void:
	print("── split_parts and merge_parts ──")
	_main.call("clear_model")
	await _frames(5)
	var slope: int = _put("3039", 4, Vector3(0, LIFT, 0))
	_check("Alt+S and Alt+M are the window's Split and Merge (%s, %s)" % [
		_shell.key_words("split_parts"), _shell.key_words("merge_parts")],
		_shell.key_words("split_parts") == "Alt+S" and _shell.key_words("merge_parts") == "Alt+M")
	var start: Array = _signature(_model_ids())
	_select([slope])
	var before: Dictionary = _ids_now()
	_shell.run("split_parts")
	await _frames(5)
	var window: Array = _signature(_made_since(before))
	_builder.undo()
	await _frames(2)
	_check("the window's Alt+S splits the 2 x 2 slope into %d, undone" % window.size(),
		window.size() == 2 and _signature(_model_ids()) == start)
	_builder.selection.clear()
	var depth: int = _builder.history_depth()
	before = _ids_now()
	var said: String = await _say("split_parts", {"bricks": [slope]})
	print("    said: %s" % said)
	var session: Array = _signature(_made_since(before))
	_check("split_parts splits it in 1 call, part for part as Alt+S did: %s" % ", ".join(session),
		session == window and _world.get_brick(slope) == null)
	_check("...one undo step, nothing selected", _builder.history_depth() == depth + 1
		and _builder.selection.is_empty())
	var one_by_one: int = _put("3024", 1, Vector3(100, LIFT, 0))
	start = _signature(_model_ids())
	said = await _say("split_parts", {"bricks": [one_by_one]})
	_check("a 1 x 1 plate does not split, said, nothing changed: %s" % said.left(70),
		said.begins_with("Nothing split") and _signature(_model_ids()) == start)

	_main.call("clear_model")
	await _frames(5)
	var plates: Array[int] = []
	for i: int in 2:
		for k: int in 3:
			plates.append(_put("3024", 4, Vector3(10 + 20 * i, LIFT, 10 + 20 * k)))
	start = _signature(_model_ids())
	_select(plates)
	before = _ids_now()
	_shell.run("merge_parts")
	await _frames(5)
	window = _signature(_made_since(before))
	_builder.undo()
	await _frames(2)
	_check("the window's Alt+M merges six 1 x 1 plates into %s, undone" % ", ".join(window),
		window.size() == 1 and _signature(_model_ids()) == start)
	_builder.selection.clear()
	depth = _builder.history_depth()
	before = _ids_now()
	said = await _say("merge_parts", {"bricks": plates})
	print("    said: %s" % said)
	session = _signature(_made_since(before))
	_check("merge_parts merges them in 1 call into a 2 x 3 plate, as Alt+M did",
		session == window and session.size() == 1 and str(session[0]).begins_with("3021|"))
	_check("...one undo step", _builder.history_depth() == depth + 1)
	said = await _say("undo", {})
	_check("undo brings the six back", _signature(_model_ids()) == start)


# -- measure ----------------------------------------------------------------------


func _measure() -> void:
	print("── measure ──")
	_main.call("clear_model")
	await _frames(5)
	# A hinge, its top swung 37° by the window's own swing, as a person
	# leaves one with the Hinge tool or Properties.
	var base: int = _put("3937", 4, Vector3(0, LIFT, 0))
	var top: int = _put("3938", 4, Vector3(0, LIFT, 0))
	_select([top])
	var turned: int = _builder.swing_selection(37.0)
	var shown: Variant = _builder.hinge_angle()
	_check("the window swings the top 37° on its hinge, Properties says %s°" % [
		"%.1f" % shown if shown != null else "nothing"], turned == 1 and shown != null
		and absf(absf(float(shown)) - 37.0) < 0.1)
	_builder.selection.clear()
	var depth: int = _builder.history_depth()
	var model: Array = _signature(_model_ids())
	var said: String = await _say("measure", {"from": "#%d.hinge[0]" % base,
		"to": "#%d.hinge[0]" % top})
	print("    said: %s" % said)
	var found: RegExMatch = RegEx.create_from_string("turned (-?[\\d.]+)°").search(said)
	var read: float = absf(float(found.get_string(1))) if found != null else -1.0
	_check("measure reads the hinge back as %s° (37.0 within 0.1)" % _deg(read),
		absf(read - 37.0) <= 0.1)
	said = await _say("measure", {"from": "#%d.hole[0]" % base, "to": "#%d.open[0]" % top})
	print("    said: %s" % said)
	found = RegEx.create_from_string("([\\d.]+)° between").search(said)
	read = float(found.get_string(1)) if found != null else -1.0
	_check("...and the angle between a stud on top and a stud's hole under the base as %s°" % _deg(read),
		absf(read - 37.0) <= 0.1)
	_check("...changing nothing", _signature(_model_ids()) == model
		and _builder.history_depth() == depth)
	said = await _say("measure", {"from": "#%d.hinge" % base, "to": "#%d.open[9]" % top})
	_check("a connector it does not have is refused with what it has: %s" % said.left(80),
		said.contains("open[0] to open[1]"))

	# Two beams, one turned 37° about the upright: the window's ruler on a
	# pin hole of each, and measure on the same two.
	_main.call("clear_model")
	await _frames(5)
	var one: int = _put("32524", 0, Vector3(0, 100, 0))
	var other: int = _put("32524", 0, Vector3(200, 100, 60), Basis(Vector3.RIGHT, deg_to_rad(37.0)))
	var ruler: Measure = _main.get("_measure")
	ruler.toggle()
	var ends: Array = []
	for brick_id: int in [one, other]:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		for end: JointSnap.End in JointSnap.ends_for(_library, brick.part_id):
			if end.kind == "pin_hole":
				ends.append(end.placed(brick.transform, brick_id))
				break
	ruler.set("_from", (ends[0] as JointSnap.End).middle())
	ruler.set("_from_end", ends[0])
	ruler.set("_to", (ends[1] as JointSnap.End).middle())
	ruler.set("_to_end", ends[1])
	ruler.set("_fixed", true)
	var window: String = ruler.words()
	ruler.toggle()
	# The same holes as attach numbers them: the one whose middle is the ruler's.
	var asked: Array[String] = []
	for n: int in 2:
		var brick: BrickWorld.Brick = _world.get_brick([one, other][n])
		for point: Attach.Point in Attach.points_of(_library, brick.part_id):
			if (brick.transform * point.frame).origin.distance_to((ends[n] as JointSnap.End).middle()) < 4.0:
				asked.append("#%d.%s" % [brick.id, point.address()])
				break
	said = ""
	if asked.size() == 2:
		said = await _say("measure", {"from": asked[0], "to": asked[1]})
	print("    window: %s" % window)
	print("    said:   %s" % said)
	_check("measure on two beams' pin holes says what the window's Measure says",
		window.contains("37.0° between the two pin holes") and said.contains(window))
	said = await _say("measure", {"from": "0 0 0", "to": "2 3 1"})
	_check("between two points too: %s" % said, said.contains("2 studs across, 1 deep, 3 plates up"))


# -- what the person sees ----------------------------------------------------------


func _in_view() -> void:
	print("── in_view ──")
	await _open_car()
	var verbs: EditVerbs = _main.get("_verbs")
	var said: String = _text(await _rpc("tools/call", {"name": "in_view", "arguments": {}}))
	_check("with nothing laid: %s" % said.get_slice("\n", 4).strip_edges(),
		said.contains("No reference picture") and said.contains("timeline is down"))
	# A plan laid on the floor as a person lays one, from the dialog's pick.
	var plan := Image.create_empty(400, 300, false, Image.FORMAT_RGBA8)
	plan.fill(Color(0.95, 0.95, 0.9))
	plan.fill_rect(Rect2i(40, 40, 120, 80), Color(0.1, 0.3, 0.8))
	var reference: ReferenceImage = _main.get("_reference")
	reference.take(plan, "plan.png")
	await _frames(5)
	(reference.controls_by_name()["reference_dialog"] as AcceptDialog).hide()
	# The timeline at a step, a part in hand, two parts selected.
	_shell.run("timeline")
	var steps: StepsBar = _main.get("_steps")
	for _n: int in 600:
		await process_frame
		if steps.is_playing_back() and not steps.is_starting():
			break
	var slider: HSlider = steps.get("_slider")
	slider.value = roundi(slider.max_value * 0.4)
	await _frames(3)
	var step: Instructions.Step = steps.current_step()
	_main.call("_on_part_chosen", "3001")
	_builder.held_color = 4
	var ids: Array[int] = _model_ids()
	_select([ids[0], ids[1]])
	var model: Array = _signature(_model_ids())
	var depth: int = _builder.history_depth()
	var kept: Dictionary = reference.said()
	var held: String = _builder.held_part
	var answer: Dictionary = await _rpc("tools/call", {"name": "in_view", "arguments": {}})
	said = _text(answer)
	print(said.indent("    "))
	_check("in_view names the step the timeline is at (%d)" % (step.number if step != null else -1),
		step != null and said.contains("at step %d of" % step.number))
	_check("...the part in hand", said.contains("Brick 2 x 4 (3001) in Red (4)")
		and said.contains("the Place tool"))
	_check("...the selection", said.contains("Selected: 2 parts"))
	_check("...and the reference picture a person laid: its file, plane and size",
		said.contains("plan.png") and said.contains("on the floor")
		and said.contains("%s x %s studs" % [HandTools._n(reference.width / 20.0),
			HandTools._n(reference.height() / 20.0)]))
	var picture: Image = null
	for block: Dictionary in answer.get("content", []):
		if str(block.get("type", "")) == "image":
			picture = Image.new()
			picture.load_png_from_buffer(Marshalls.base64_to_raw(str(block.get("data", ""))))
	var drawn: int = _differs(picture, plan)
	_check("...with the picture, the model drawn on it where it stands (%d%% of it changed)"
		% drawn, picture != null and drawn > 3 and drawn < 90)
	_check("...and nothing changed: the model, the history, the picture, the selection, the hand",
		_signature(_model_ids()) == model and _builder.history_depth() == depth
		and ReferenceImage.same(reference.said(), kept) and _builder.selection.size() == 2
		and _builder.held_part == held and verbs.mode == "place")
	if picture != null and not _shots.is_empty():
		picture.save_png(_shots.path_join("in_view_reference.png"))
	await _shot("in_view")


# -- helpers ----------------------------------------------------------------------


func _open_car() -> void:
	_main.call("clear_model")
	await _frames(5)
	var placed: int = _store.open("res://models/car.ldr")
	(_main.get("_bar") as ModelBar).opened.emit(placed)
	await _frames(20)


func _put(part: String, colour: int, at: Vector3, basis: Basis = Basis.IDENTITY) -> int:
	var where := Transform3D(basis, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)
	return brick_id


func _select(ids: Array) -> void:
	_builder.selection.clear()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _model_ids() -> Array[int]:
	var ids: Array[int] = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			ids.append(brick.id)
	ids.sort()
	return ids


func _ids_now() -> Dictionary:
	var now: Dictionary = {}
	for brick_id: int in _model_ids():
		now[brick_id] = true
	return now


func _made_since(before: Dictionary) -> Array:
	return _model_ids().filter(func(brick_id: int) -> bool: return not before.has(brick_id))


func _box(ids: Array) -> AABB:
	return _builder._bounds_of(PackedInt64Array(ids), Transform3D.IDENTITY)


## Each part as what it is and where, sorted: two sets of parts alike when
## these are.
func _signature(ids: Array) -> Array:
	var rows: Array = []
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null:
			continue
		var t: Transform3D = brick.transform
		var row := PackedStringArray([brick.part_id, str(brick.color_code)])
		for v: Vector3 in [t.origin, t.basis.x, t.basis.y, t.basis.z]:
			for n: int in 3:
				row.append(str(snappedf(v[n], 0.01) + 0.0))
		rows.append("|".join(row))
	rows.sort()
	return rows


## Each part as what it is and the lattice's cells it covers, sorted: two
## sets of parts that look alike when these are, whichever way a part
## symmetrical itself was turned to get there.
func _covers(ids: Array) -> Array:
	var rows: Array = []
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null:
			continue
		var cells: Array = Array(_builder.boxes_for(_library.mesh_for(brick.part_id), brick.transform))
		var boxes: Array = []
		for n: int in range(0, cells.size(), 6):
			boxes.append(str(cells.slice(n, n + 6)))
		boxes.sort()
		rows.append("%s|%d|%s" % [brick.part_id, brick.color_code, ",".join(boxes)])
	rows.sort()
	return rows


static func _alike(one: Array, other: Array) -> int:
	var left: Array = other.duplicate()
	var count: int = 0
	for row: Variant in one:
		var at: int = left.find(row)
		if at >= 0:
			left.remove_at(at)
			count += 1
	return count


## How much of [param picture] differs from [param plan] at its size, in
## percent of its pixels.
static func _differs(picture: Image, plan: Image) -> int:
	if picture == null or picture.is_empty():
		return 0
	var scaled: Image = plan.duplicate()
	scaled.resize(picture.get_width(), picture.get_height(), Image.INTERPOLATE_BILINEAR)
	var changed: int = 0
	for y: int in range(0, picture.get_height(), 2):
		for x: int in range(0, picture.get_width(), 2):
			var a: Color = picture.get_pixel(x, y)
			var b: Color = scaled.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.15:
				changed += 1
	return roundi(100.0 * changed / maxf(1.0, ceilf(picture.get_width() / 2.0)
		* ceilf(picture.get_height() / 2.0)))


static func _deg(value: float) -> String:
	return "%.1f" % value if value >= 0.0 else "nothing"


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
func _shot(name: String, box: AABB = AABB()) -> void:
	if _shots.is_empty():
		return
	_camera.frame(box if box.has_volume() else _box(_model_ids()))
	await _frames(20)
	await RenderingServer.frame_post_draw
	var size: Vector2i = DisplayServer.window_get_size()
	root.get_viewport().get_texture().get_image().save_png(
		_shots.path_join("%s_%dx%d.png" % [name, size.x, size.y]))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
