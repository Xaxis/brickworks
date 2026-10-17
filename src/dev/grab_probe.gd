## Grab a part in the view and move it about its joint, as a person does with
## the Select tool, on real sets: the drag is simulated pointer events through
## the real scene (main.gd's press, the slop, GrabDrag), the parts read as
## rigid bodies (Bodies) and moved as the joint allows (Grab).
##
##   godot --path . --resolution 1400x900 --script src/dev/grab_probe.gd
##   godot --headless --path . --script src/dev/grab_probe.gd
##   godot --headless --path . --script src/dev/grab_probe.gd -- --survey vendor/omr/files/X.mpd ...
##
## For each case: the part dragged turns (or slides) to where the pointer
## says, frame by frame; where the model is in the way it stops at the last
## angle with room and the next degree has none; a gear drives its train by
## the tooth counts Simulate gives; what the drag says of the structure is
## what Balance says of the model weighed afresh; and one undo puts every
## part back exactly. Then move_part over MCP: a read that changes nothing,
## and a move. Windowed, pictures before, mid-drag and after go to
## bench/results/grab-2026-10-17/; frame timings are printed and written
## there as timings.json.
extends SceneTree

const OUT := "/mnt/Projects/brickworks/bench/results/grab-2026-10-17"
## The sets, each with the joint it drags: a kind of link, and what a part
## on its moving side must be (any when empty).
const CASES: Array = [
	["turntable", "res://vendor/omr/files/4096-1_Crane.mpd", "turntable", 0.0],
	["hinge", "res://vendor/omr/files/4096-1_Crane.mpd", "hinge", 0.0],
	["click hinge", "res://vendor/omr/files/4915-1_Fork-Lift.mpd", "click", 0.0],
	["gear train", "res://vendor/omr/files/8020-1_Windmill.mpd", "gear", 0.0],
	["minifigure", "res://vendor/omr/files/6627-1.mpd", "figure", 0.0],
	["ball joint", "res://vendor/omr/files/30472-1.mpd", "ball", 0.0],
	["slider", "res://vendor/omr/files/6630-1.mpd", "slide", 0.0],
]

var _failures: int = 0
var _passed: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _verbs: EditVerbs
var _grab: GrabDrag
var _store: ModelStore
var _windowed: bool = false
var _timings: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if ok:
		_passed += 1
	else:
		_failures += 1


func _run() -> void:
	await process_frame
	_windowed = DisplayServer.get_name() != "headless"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(OUT)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_verbs = _main.get("_verbs")
	_grab = _main.get("_grab_drag")
	_store = _main.get("_store")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--survey" in args:
		for file: String in args:
			if file.ends_with(".mpd") or file.ends_with(".ldr"):
				await _survey(file if file.begins_with("res://") else "res://" + file)
		quit(0)
		return
	var only: String = ""
	for arg: String in args:
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for case: Array in CASES:
		if not only.is_empty() and not str(case[0]).contains(only):
			continue
		await _case(case[0], case[1], case[2])
	if only.is_empty() or only == "mcp":
		await _session()
	if only.is_empty() or only == "big":
		await _big()
	var file := FileAccess.open(OUT.path_join("timings.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_timings, "  "))
	print("")
	if _failures == 0:
		print("grab: %d checks passed: parts dragged on their joints on real sets, stopped by the "
			% _passed + "model, gears driven by their teeth, the structure weighed, one undo each")
	else:
		print("grab: %d FAILED, %d passed" % [_failures, _passed])
	quit(1 if _failures > 0 else 0)


func _open(path: String) -> bool:
	if not FileAccess.file_exists(path):
		print("  (no %s: tools/omr.py fetch brings the sets; skipped)" % path)
		return false
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 400:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	if playback_stop():
		await _frames(3)
	_builder.forget_history()
	_verbs.set_mode("select")
	_builder.clear_selection()
	return _world.brick_count() > 0


func playback_stop() -> bool:
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null and playback.is_playing():
		playback.stop()
		return true
	return false


func _bodies() -> Bodies:
	return Bodies.read(_world, _library, _builder.lattice, _store.scenery, _builder.locked)


func _survey(path: String) -> void:
	if not await _open(path):
		return
	var bodies: Bodies = _bodies()
	print("%s: %d parts, %s" % [path.get_file(), _world.brick_count(), bodies.summary()])
	for body: int in bodies.members:
		var ids: PackedInt64Array = bodies.members[body]
		if ids.size() > 1 and ids.size() < 30:
			var parts := PackedStringArray()
			for key: int in ids:
				parts.append(_world.get_brick(key).part_id)
			print("    body %d%s: %s" % [body, " (anchor)" if bodies.anchors.has(body) else "",
				" ".join(parts)])
	for link: Bodies.Link in bodies.links:
		var child: int = link.b if bodies.parent_link.get(link.b) == link else link.a
		var moved: Array = bodies.beyond(child)
		print("    %-9s %s holds=%s slide=%s detent=%s moves %s" % [link.kind,
			_parts_said(bodies, link), link.holds, link.slide, link.detent,
			bodies.named(moved)])


func _parts_said(bodies: Bodies, link: Bodies.Link) -> String:
	var pair: Array = link.pairs[0]
	return "%s~%s" % [_world.get_brick(int(pair[0])).part_id, _world.get_brick(int(pair[1])).part_id]


# -- one case ------------------------------------------------------------------------


## Open [param path], find a joint of [param want], drag it.
func _case(name: String, path: String, want: String) -> void:
	print("\n%s: %s" % [name, path.get_file()])
	if not await _open(path):
		return
	var bodies: Bodies = _bodies()
	print("    %d parts read as %s" % [_world.brick_count(), bodies.summary()])
	var chosen: Dictionary = _choose(bodies, want)
	if chosen.is_empty():
		_check("%s: the set has a joint of that kind" % name, false)
		return
	var link: Bodies.Link = chosen["link"]
	var child: int = chosen["child"]
	var moving: PackedInt64Array = bodies.parts_of(bodies.beyond(child))
	print("    the joint: %s %s, moving %s" % [link.kind, _parts_said(bodies, link),
		bodies.named(bodies.beyond(child))])
	_frame_on(moving)
	await _frames(20)
	var before: Dictionary = _snapshot()
	var revision: int = _world.revision
	var depth: int = _builder.history_depth()
	var press: Dictionary = _press_point(moving, bodies)
	if press.is_empty():
		_check("%s: a part of what moves is under the pointer somewhere" % name, false)
		return
	if _windowed:
		await _shot(name, "1_before")
	var screen: Vector2 = press["screen"]
	await _move(screen, 0)
	await _button(screen, true)
	# Past the slop: the drag is the grab's.
	await _move(screen + Vector2(0, 7), MOUSE_BUTTON_MASK_LEFT)
	var grab: Grab = _grab.grab
	if grab == null:
		print("    (press state: grabbing=%s dragging=%s carrying=%s press_brick=%s mode=%s)" % [
			_main.get("_grabbing"), _main.get("_dragging_part"), _builder.is_carrying(),
			_main.get("_press_brick"), _verbs.mode])
		var trial := Grab.new()
		trial.world = _world
		trial.builder = _builder
		trial.library = _library
		trial.bodies = bodies
		print("    (Grab.begin on #%d directly: %s %s)" % [int(press["brick"]),
			trial.begin(int(press["brick"]), _world.get_brick(int(press["brick"])).transform.origin),
			trial.why])
	_check("%s: a drag on #%d is a grab on its joint, not a carry (%s)" % [name, int(press["brick"]),
		_grab.last_words if grab == null else grab.said], grab != null and grab.state == "moves"
		and not _builder.is_carrying())
	if grab == null or grab.state != "moves":
		await _button(screen, false)
		return
	_check("%s: what moves is the body grabbed and all beyond it (%d parts)" % [name,
		grab.moving.size()], grab.moving.size() >= 1 and _same_set(grab.moving, moving)
		or grab.moving.has(int(press["brick"])))
	_check("%s: the model is untouched while it is dragged" % name, _world.revision == revision)
	if want == "slide" and grab.can_slide():
		await _slide_drag(name, grab)
	elif grab.mode == "ball":
		await _ball_drag(name, grab)
	else:
		await _turn_drag(name, grab, want)
	var placed: Dictionary = grab.placed.duplicate()
	var end: Vector2 = _last_screen
	await _button(end, false)
	await _frames(3)
	_check("%s: let go, it is one step to undo (%s)" % [name, _builder.history_words(1)[0]
		if _builder.history_depth() > depth else "none"], _builder.history_depth() == depth + 1)
	if _windowed:
		await _shot(name, "3_after")
	# The structure said is what Balance says of the model as it now stands.
	var fresh := Balance.new()
	fresh.library = _library
	fresh.lattice = _builder.lattice
	fresh.floor_ids = _store.scenery
	var direct: Balance.Report = fresh.measure(_world.bricks())
	var said: Balance.Report = _grab.last_report
	_check("%s: the readout's balance is Balance's, weighed afresh (%s vs %s studs, %d vs %d over)"
		% [name, "-" if said == null else Balance.studs(said.margin), Balance.studs(direct.margin),
		-1 if said == null else said.over, direct.over], said != null
		and absf(said.margin - direct.margin) < 0.05 and said.over == direct.over)
	print("    said: %s" % _grab.last_words)
	_timings[name] = {"frames": _grab.frames, "worst_ms": snappedf(_grab.worst_ms, 0.01),
		"mean_ms": snappedf(_grab.mean_ms, 0.01), "parts": _world.brick_count(),
		"moving": grab.moving.size()}
	print("    drag frames: %d, mean %.2f ms, worst %.2f ms" % [_grab.frames, _grab.mean_ms,
		_grab.worst_ms])
	# Every part that moved stands where the drag left it.
	var kept: bool = true
	for key: int in placed:
		var brick: BrickWorld.Brick = _world.get_brick(key)
		if brick == null or not _near(brick.transform, placed[key]):
			kept = false
	_check("%s: every part stands where the drag left it" % name, kept or grab.mode == "turn"
		and not grab.link.holds)
	_builder.undo()
	await _frames(3)
	_check("%s: one undo puts every part back exactly" % name, _snapshot() == before)


var _last_screen := Vector2.ZERO


## Drag the held point round the joint, 5° a frame, to +150° and back to
## -150°: each frame's angle is the pointer's until the model stops it, and
## a stop is where the next degree has no room.
func _turn_drag(name: String, grab: Grab, want: String) -> void:
	var hold: Vector3 = grab._hold
	var worst: float = 0.0
	var followed: int = 0
	var stopped_at: float = NAN
	var targets: Array = []
	for n: int in range(1, 31):
		targets.append(5.0 * n)
	for n: int in range(29, -31, -1):
		targets.append(5.0 * n)
	var mid_shot: bool = false
	var driven: Dictionary = {}
	for target: float in targets:
		var turned: Vector3 = _about(grab.pivot, grab.axis, target) * hold
		var screen: Vector2 = _camera.unproject_position(turned)
		await _move(screen, MOUSE_BUTTON_MASK_LEFT)
		if grab.stopped:
			if is_nan(stopped_at):
				stopped_at = grab.angle
		else:
			var off: float = absf(grab.angle - _detented(grab, target))
			worst = maxf(worst, off)
			followed += 1
			stopped_at = NAN
		if not mid_shot and _windowed and absf(grab.angle) > 40.0:
			mid_shot = true
			await _shot(name, "2_mid")
		if want == "gear" and not grab.coupled.is_empty() and driven.is_empty() \
				and absf(grab.angle) > 20.0:
			driven = _gear_check(name, grab)
	_check("%s: the angle follows the pointer in %d frames, to %.2f°%s" % [name, followed, worst,
		" on its %s° clicks" % Balance.tidy(grab.link.detent) if grab.link.detent > 0.0 else ""],
		followed >= 4 and worst <= 1.5)
	if grab.stopped or not is_nan(stopped_at):
		var at: float = grab.angle
		var way: float = 1.0 if _last_target > at else -1.0
		var step: float = grab.link.detent if grab.link.detent > 0.0 else 1.0
		var room_here: bool = grab.has_room(grab.transforms_at(at))
		var room_past: bool = grab.has_room(grab.transforms_at(at + way * step))
		_check("%s: it stops where the model is: room at %.1f°, none %s° on" % [name, at,
			Balance.tidy(step)], room_here and not room_past)
	else:
		print("    (nothing stopped it over ±150°)")
	if want == "gear":
		_check("%s: the gears it drives turn with it (%d parts)" % [name, grab.coupled.size()],
			not grab.coupled.is_empty() and not driven.is_empty())


var _last_target: float = 0.0


func _detented(grab: Grab, target: float) -> float:
	_last_target = target
	if grab.link.detent > 0.0:
		return roundf(target / grab.link.detent) * grab.link.detent
	return target


## The gears the grabbed one drives turn by the tooth counts: each driven
## part's turn about its own axle, against the grab's angle, is the rate
## Simulate's reading gives it.
func _gear_check(name: String, grab: Grab) -> Dictionary:
	var simulation: Simulation = Simulation.read(_world.bricks(), _library, _store.scenery)
	var driver: int = simulation.model.body_of(grab.part)
	simulation.drive(driver)
	var worst: float = 0.0
	var checked: int = 0
	var ratios := PackedStringArray()
	for key: int in grab.coupled:
		var body: int = simulation.model.body_of(key)
		if not simulation.rates.has(body):
			continue
		var way: Vector3 = simulation.axis_of(body)
		var turn: Basis = (grab.placed[key] as Transform3D).basis \
			* (grab.rest[key] as Transform3D).basis.inverse()
		var measured: float = _turn_about(turn, way)
		var driver_way: Vector3 = simulation.axis_of(driver)
		var driver_angle: float = grab.angle * (1.0 if driver_way.dot(grab.axis) > 0.0 else -1.0)
		var expected: float = wrapf(driver_angle * float(simulation.rates[body]), -180.0, 180.0)
		worst = maxf(worst, absf(wrapf(measured - expected, -180.0, 180.0)))
		checked += 1
		if ratios.size() < 3:
			ratios.append("%s %s" % [_world.get_brick(key).part_id,
				Simulation.figure(float(simulation.rates[body]))])
	_check("%s: %d driven parts turn by the tooth counts at %.0f° (%s), to %.3f°" % [name, checked,
		grab.angle, ", ".join(ratios), worst], checked > 0 and worst < 0.05)
	return {"checked": checked}


func _slide_drag(name: String, grab: Grab) -> void:
	var hold: Vector3 = grab._hold
	var span: Vector2 = grab.slide_range()
	var worst: float = 0.0
	var followed: int = 0
	var targets: Array = []
	for n: int in range(1, 13):
		targets.append(2.0 * n)
	for n: int in range(11, -13, -1):
		targets.append(2.0 * n)
	for target: float in targets:
		var screen: Vector2 = _camera.unproject_position(hold + grab.axis * target)
		await _move(screen, MOUSE_BUTTON_MASK_LEFT)
		if grab.mode != "slide":
			break
		var expected: float = clampf(target, span.x, span.y)
		if not grab.stopped:
			worst = maxf(worst, absf(grab.shift - expected))
			followed += 1
		if followed == 4 and _windowed:
			await _shot(name, "2_mid")
	_check("%s: a drag along its line slides it (%s)" % [name, grab.mode], grab.mode == "slide")
	_check("%s: the slide follows the pointer in %d frames, to %.2f LDU, within %s to %s LDU" % [
		name, followed, worst, Balance.tidy(span.x), Balance.tidy(span.y)],
		followed >= 3 and worst <= 1.0)


func _ball_drag(name: String, grab: Grab) -> void:
	var hold: Vector3 = grab._hold
	var worst: float = 0.0
	var followed: int = 0
	var about: Vector3 = (hold - grab.pivot).cross(_camera.global_transform.basis.z).normalized()
	for n: int in range(1, 13):
		var turned: Vector3 = _about(grab.pivot, about, 4.0 * n) * hold
		await _move(_camera.unproject_position(turned), MOUSE_BUTTON_MASK_LEFT)
		if not grab.stopped:
			var now: Vector3 = grab.twist * (hold - grab.pivot) + grab.pivot
			worst = maxf(worst, now.distance_to(turned))
			followed += 1
		if n == 6 and _windowed:
			await _shot(name, "2_mid")
	_check("%s: the ball turns so the held point follows the pointer in %d frames, to %.2f LDU" % [
		name, followed, worst], followed >= 3 and worst < 1.5)


# -- a session -------------------------------------------------------------------------


func _session() -> void:
	print("\nmove_part over MCP: 4096-1_Crane.mpd")
	if not await _open("res://vendor/omr/files/4096-1_Crane.mpd"):
		return
	var bodies: Bodies = _bodies()
	var chosen: Dictionary = _choose(bodies, "turntable")
	if chosen.is_empty():
		_check("a turntable to move", false)
		return
	var moving: PackedInt64Array = bodies.parts_of(bodies.beyond(int(chosen["child"])))
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var before: Dictionary = _snapshot()
	var revision: int = _world.revision
	var read: String = str(await tools.run("move_part", {"part": "#%d" % int(moving[0])}))
	print("    read: %s" % read.replace("\n", " | "))
	_check("move_part with part= alone changes nothing", _snapshot() == before
		and _world.revision == revision and _builder.history_depth() == 0
		and read.contains("Nothing was changed"))
	var moved: String = str(await tools.run("move_part", {"part": "#%d" % int(moving[0]),
		"degrees": 90}))
	print("    moved: %s" % moved.replace("\n", " | "))
	_check("move_part degrees=90 turns it, as one step, and says how it stands",
		_builder.history_depth() == 1 and moved.contains("Moved") and moved.contains("Now:"))
	_builder.undo()
	await _frames(2)
	_check("...and undo puts it back exactly", _snapshot() == before)


# -- a big model: frame timings ---------------------------------------------------------


func _big() -> void:
	var path: String = "res://vendor/omr/files/10179-1.mpd"
	for candidate: String in ["res://vendor/omr/files/7191-1.mpd", "res://vendor/omr/files/10030-1.mpd",
			"res://vendor/omr/files/10179-1.mpd"]:
		if FileAccess.file_exists(candidate):
			path = candidate
			break
	print("\nframe timings on a big model: %s" % path.get_file())
	if not await _open(path):
		return
	var started: int = Time.get_ticks_msec()
	var bodies: Bodies = _bodies()
	print("    %d parts read as %s" % [_world.brick_count(), bodies.summary()])
	var chosen: Dictionary = _choose(bodies, "any")
	if chosen.is_empty():
		print("    (no joint to drag)")
		return
	var moving: PackedInt64Array = bodies.parts_of(bodies.beyond(int(chosen["child"])))
	_frame_on(moving)
	await _frames(10)
	var press: Dictionary = _press_point(moving, bodies)
	if press.is_empty():
		return
	var screen: Vector2 = press["screen"]
	var began: int = Time.get_ticks_usec()
	await _move(screen, 0)
	await _button(screen, true)
	await _move(screen + Vector2(0, 7), MOUSE_BUTTON_MASK_LEFT)
	var grabbed_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	var grab: Grab = _grab.grab
	if grab == null or grab.state != "moves":
		await _button(screen, false)
		return
	for n: int in 40:
		var turned: Vector3 = _about(grab.pivot, grab.axis, 2.0 * n) * grab._hold
		await _move(_camera.unproject_position(turned), MOUSE_BUTTON_MASK_LEFT)
	await _button(_last_screen, false)
	_timings["big"] = {"file": path.get_file(), "parts": _world.brick_count(),
		"moving": grab.moving.size(), "frames": _grab.frames, "mean_ms": snappedf(_grab.mean_ms, 0.01),
		"worst_ms": snappedf(_grab.worst_ms, 0.01), "first_grab_ms": snappedf(grabbed_ms, 0.1),
		"bodies_ms": bodies.took_ms}
	print("    %d parts, %d moving: grab began in %.0f ms (bodies read in %d ms); %d frames, mean %.2f ms, worst %.2f ms"
		% [_world.brick_count(), grab.moving.size(), grabbed_ms, bodies.took_ms, _grab.frames,
		_grab.mean_ms, _grab.worst_ms])
	_check("a drag frame on %d parts is within a 60 Hz frame (worst %.1f ms)" % [
		_world.brick_count(), _grab.worst_ms], _grab.worst_ms < 16.7)
	_builder.undo()
	await _frames(2)
	print("    (%d ms in all)" % (Time.get_ticks_msec() - started))


# -- choosing -----------------------------------------------------------------------


## A joint of [param want] whose moving side is not the whole model:
## {link, child}. "gear": a body with a gear that drives others; "figure":
## a minifigure's arm; "slide": a joint that slides; "any": the first.
func _choose(bodies: Bodies, want: String) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -INF
	for link: Bodies.Link in bodies.links:
		var child: int = -1
		if bodies.parent_link.get(link.b) == link:
			child = link.b
		elif bodies.parent_link.get(link.a) == link:
			child = link.a
		if child < 0:
			continue
		var moved: PackedInt64Array = bodies.parts_of(bodies.beyond(child))
		var ok: bool = false
		var score: float = float(moved.size())
		match want:
			"turntable", "hinge", "click", "ball":
				ok = link.kind == want
			"gear":
				for key: int in moved:
					if not Mechanism.spec_of(_world.get_brick(key).part_id).is_empty():
						ok = link.kind == "axle" or link.kind == "pin"
						break
			"figure":
				for key: int in moved:
					var part: String = _world.get_brick(key).part_id
					if part.begins_with("3818") or part.begins_with("3819") \
							or part.begins_with("981") or part.begins_with("982"):
						ok = true
						score = -float(moved.size())
						break
			"slide":
				ok = link.slide.x + link.slide.y > 8.0
			"any":
				ok = link.kind != "stud"
		if ok and score > best_score:
			best_score = score
			best = {"link": link, "child": child}
	return best


## A screen point over a part of [param moving], away from its joint's
## line: {screen, brick}.
func _press_point(moving: PackedInt64Array, bodies: Bodies) -> Dictionary:
	var ours: Dictionary = {}
	for key: int in moving:
		ours[key] = true
	var order: Array = Array(moving)
	var link: Bodies.Link = bodies.parent_link.get(int(bodies.body_of[int(moving[0])]))
	var middle: Vector3 = link.point if link != null else Vector3.ZERO
	order.sort_custom(func(a: int, b: int) -> bool:
		return _world.get_brick(a).transform.origin.distance_to(middle) \
			> _world.get_brick(b).transform.origin.distance_to(middle))
	for key: int in order:
		var brick: BrickWorld.Brick = _world.get_brick(key)
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		if info == null:
			continue
		# Its middle, then points towards its corners: a wing under a
		# fuselage shows only its tip.
		var box: AABB = info.bounds
		var spots: Array = [box.get_center()]
		for corner: int in 8:
			spots.append(box.get_center().lerp(box.get_endpoint(corner), 0.7))
		for spot: Vector3 in spots:
			var at: Vector3 = brick.transform * spot
			if _camera.is_position_behind(at):
				continue
			var screen: Vector2 = _camera.unproject_position(at)
			if not root.get_visible_rect().grow(-8.0).has_point(screen) \
					or bool(_main.call("_over_panel_at", screen)):
				continue
			if _verbs.brick_at(screen) == key:
				return {"screen": screen, "brick": key}
	return {}


func _frame_on(ids: PackedInt64Array) -> void:
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in _world.bricks():
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		if info == null:
			continue
		var here: AABB = brick.transform * info.bounds
		box = here if first else box.merge(here)
		first = false
	_camera.frame(box, 1.15)


# -- helpers -------------------------------------------------------------------------


static func _about(pivot: Vector3, axis: Vector3, degrees: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pivot) \
		* Transform3D(Basis(axis.normalized(), deg_to_rad(degrees)), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)


static func _turn_about(turn: Basis, axis: Vector3) -> float:
	var across: Vector3 = (Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).cross(axis).normalized()
	var turned: Vector3 = turn * across
	return rad_to_deg(atan2(axis.dot(across.cross(turned)), across.dot(turned)))


static func _same_set(a: Dictionary, b: PackedInt64Array) -> bool:
	if a.size() != b.size():
		return false
	for key: int in b:
		if not a.has(key):
			return false
	return true


func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


static func _near(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.05 and a.basis.x.distance_to(b.basis.x) < 0.001 \
		and a.basis.y.distance_to(b.basis.y) < 0.001 and a.basis.z.distance_to(b.basis.z) < 0.001


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or rect.x <= 0.0:
		return at
	return at * (window / rect)


func _move(at: Vector2, mask: int) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = _as_event(at) - _as_event(_last_screen)
	move.button_mask = mask
	Input.parse_input_event(move)
	_last_screen = at
	await _frames(1)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)
	await _frames(2)


func _shot(name: String, when: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = OUT.path_join("%s_%s.png" % [name.replace(" ", "_"), when])
	image.save_png(path)
	print("    picture: %s" % path)
