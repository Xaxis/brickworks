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
	["turned turntable", "res://vendor/omr/files/30181-1.mpd", "turntable", 0.0],
	["hinge", "res://vendor/omr/files/4096-1_Crane.mpd", "hinge", 0.0],
	["click hinge", "res://vendor/omr/files/4903-1.mpd", "click", 0.0],
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
	if "--gears" in args:
		await _gears_headless()
		quit(1 if _failures > 0 else 0)
		return
	var only: String = ""
	for arg: String in args:
		if arg.begins_with("--move-frames="):
			_move_frames = maxi(1, int(arg.trim_prefix("--move-frames=")))
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for case: Array in CASES:
		if not only.is_empty() and not str(case[0]).contains(only):
			continue
		await _case(case[0], case[1], case[2])
	if only.is_empty() or only == "copies":
		await _copies()
	if only.is_empty() or only == "chain":
		await _chain_case("chain: a minifigure's hand", "", "hand")
		await _chain_case("chain: the crane's end", "res://vendor/omr/files/4096-1_Crane.mpd", "end")
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
	# As File, Open ends: the bar says it opened, and the model's floor is
	# laid under it then (main.gd's opened handler). Opened behind the bar's
	# back, the floor was laid by the first edit instead, and an undo of the
	# drag found one part more than before it (the baseplate).
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(5)
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
	for pair: Vector2i in bodies._resting:
		print("    resting on studs: %s on %s" % [_world.get_brick(pair.x).part_id,
			_world.get_brick(pair.y).part_id])
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
	_frame_on(PackedInt64Array())
	await _frames(20)
	var before: Dictionary = _snapshot()
	var revision: int = _world.revision
	var depth: int = _builder.history_depth()
	# A part of the grabbed body itself: one further out has a joint of its
	# own (the windmill's crank once went unseen, a part of the hub beyond it
	# was pressed instead, and no gear turned).
	var press: Dictionary = _press_point(bodies.members[child], bodies)
	# Hidden from here (the windmill's crank sits inside its frame): looked
	# at from the other sides, as a person turns the view to reach it.
	for side: Vector3 in [Vector3(1, 0.6, 1), Vector3(-1, 0.6, 1), Vector3(1, 0.6, -1),
			Vector3(-1, 0.6, -1)]:
		if not press.is_empty():
			break
		_camera.look_from(side.normalized())
		_frame_on(bodies.members[child])
		await _frames(10)
		press = _press_point(bodies.members[child], bodies)
	if press.is_empty():
		_frame_on(moving)
		await _frames(10)
		press = _press_point(moving, bodies)
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
	var end: Vector2 = _last_screen
	await _button(end, false)
	await _frames(3)
	await _settled()
	var placed: Dictionary = grab.placed.duplicate()
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
		"moving": grab.moving.size(), "worst_follow_ms": snappedf(_grab.worst_follow_ms, 0.01),
		"worst_weigh_ms": snappedf(_grab.worst_weigh_ms, 0.01)}
	print("    drag frames: %d, mean %.2f ms, worst %.2f ms (following %.2f, weighing %.2f)" % [
		_grab.frames, _grab.mean_ms, _grab.worst_ms, _grab.worst_follow_ms, _grab.worst_weigh_ms])
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
	_check("%s: one undo puts every part back exactly (%s)" % [name, _differs(before)],
		_differs(before) == "none differs")


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
	var stop_ok: bool = false
	var stop_said: String = ""
	var furthest: float = 0.0
	var miss_said: String = ""
	for target: float in targets:
		var turned: Vector3 = _about(grab.pivot, grab.axis, target) * hold
		var screen: Vector2 = _camera.unproject_position(turned)
		await _move(screen, MOUSE_BUTTON_MASK_LEFT)
		if grab.stopped:
			if is_nan(stopped_at):
				stopped_at = grab.angle
				if stop_said.is_empty():
					# Where it stopped, there is room; a step further towards
					# the pointer, none.
					var way: float = 1.0 if _detented(grab, target) > grab.angle else -1.0
					var step: float = grab.link.detent if grab.link.detent > 0.0 else 1.0
					stop_ok = grab.has_room(grab.transforms_at(grab.angle)) \
						and not grab.has_room(grab.transforms_at(grab.angle + way * step))
					stop_said = "room at %.1f°, none %s° on towards %.0f°" % [grab.angle,
						Balance.tidy(step), target]
		else:
			var off: float = absf(grab.angle - _detented(grab, target))
			if off > 10.0 and miss_said.is_empty():
				var ray: Vector3 = _camera.ray_normal(screen)
				miss_said = "at %.0f° it read %.1f°, the ray %.2f along the line" % [target,
					grab.angle, absf(ray.dot(grab.axis))]
			worst = maxf(worst, off)
			followed += 1
			stopped_at = NAN
		if absf(grab.angle) > absf(furthest):
			furthest = grab.angle
		if not mid_shot and _windowed and absf(grab.angle) > 40.0:
			mid_shot = true
			await _shot(name, "2_mid")
		if want == "gear" and not grab.coupled.is_empty() and driven.is_empty() \
				and absf(grab.angle) > 20.0:
			driven = _gear_check(name, grab)
	# Let go half way to the furthest it went, so a joint the model stops at
	# rest one way (a boom laid on its cones) is still let go somewhere new.
	if absf(grab.angle) < 1.0 and absf(furthest) > 2.0:
		# Back up there in steps, as a hand would: one jump past half a
		# turn reads the short way round.
		for n: int in range(1, 11):
			var back: Vector3 = _about(grab.pivot, grab.axis, furthest * 0.05 * n) * hold
			await _move(_camera.unproject_position(back), MOUSE_BUTTON_MASK_LEFT)
	if not miss_said.is_empty():
		print("    (%s)" % miss_said)
	_check("%s: the angle follows the pointer in %d frames, to %.2f°%s" % [name, followed, worst,
		" on its %s° clicks" % Balance.tidy(grab.link.detent) if grab.link.detent > 0.0 else ""],
		followed >= 4 and worst <= 1.5)
	if not stop_said.is_empty():
		_check("%s: it stops where the model is: %s" % [name, stop_said], stop_ok)
	else:
		print("    (nothing stopped it over ±150°)")
	if want == "gear" and grab.coupled.is_empty():
		print("    (no gears turned: trains read %s, this grab's %s, ready %s; %s; pressed #%d %s)" % [
			_grab._mechanism != null, grab.mechanism != null, _grab.is_ready(), grab.gear_note,
			grab.part, _world.get_brick(grab.part).part_id])
		var again: Bodies = _bodies()
		var mine: Bodies = _grab._bodies
		print("    (#%d: in a body of %d by a fresh reading, of %d by the app's; %s / %s; app revision %d, world %d)" % [
			grab.part, (again.members[again.body_of[grab.part]] as PackedInt64Array).size(),
			(mine.members[mine.body_of[grab.part]] as PackedInt64Array).size(), again.summary(),
			mine.summary(), mine.revision, _world.revision])
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
	# The sails: the driven body with most parts, which docs/MECHANISMS.md
	# says turns once in 9 of the crank's turns.
	var sails: int = -1
	for key: int in grab.coupled:
		var body: int = simulation.model.body_of(key)
		if simulation.rates.has(body) and absf(float(simulation.rates[body])) > 1e-6 and (sails < 0
				or absf(float(simulation.rates[body])) < absf(float(simulation.rates[sails]))):
			sails = body
	if sails >= 0:
		var turned: float = 0.0
		for key: int in simulation.keys_of[sails]:
			if grab.placed.has(key):
				turned = _turn_about((grab.placed[key] as Transform3D).basis
					* (grab.rest[key] as Transform3D).basis.inverse(), simulation.axis_of(sails))
				break
		_check("%s: the sails (%s) turn %.3f° for the crank's %.1f°: 1 in %s, as the train's 9:1"
			% [name, simulation.names.get(sails, "?"), turned, grab.angle,
			Simulation.figure(1.0 / maxf(absf(float(simulation.rates[sails])), 1e-9))],
			absf(absf(float(simulation.rates[sails])) - 1.0 / 9.0) < 1e-4
			and absf(absf(turned) - absf(grab.angle) / 9.0) < 0.05)
	else:
		_check("%s: the sails are among the driven parts" % name, false)
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
	var out: Vector3 = (hold - grab.pivot).normalized()
	var side: Vector3 = out.cross(_camera.global_transform.basis.z).normalized()
	var up: Vector3 = out.cross(side).normalized()
	var met := PackedStringArray()
	# Three ways round, each there and back: a wing on a ball meets its
	# fuselage one way and swings free another.
	for about: Vector3 in [side, up, -side]:
		for n: int in [1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1, 0]:
			var turned: Vector3 = _about(grab.pivot, about, 4.0 * n) * hold
			await _move(_camera.unproject_position(turned), MOUSE_BUTTON_MASK_LEFT)
			if not grab.stopped:
				# Under the pointer: where the eye sees it, since a point behind
				# the ball and one in front of it are the same to the pointer.
				var now: Vector3 = grab.twist * (hold - grab.pivot) + grab.pivot
				worst = maxf(worst, _camera.unproject_position(now).distance_to(
					_camera.unproject_position(turned)))
				followed += 1
			elif not grab.blocked_by.is_empty() and met.size() < 3:
				var line: String = "%s meets %s" % [_world.get_brick(int(grab.blocked_by[0])).part_id,
					_world.get_brick(int(grab.blocked_by[1])).part_id]
				if not met.has(line):
					met.append(line)
			if n == 6 and about == side and _windowed:
				await _shot(name, "2_mid")
	_check("%s: the ball turns so the held point stays under the pointer in %d frames, to %.1f px%s" % [
		name, followed, worst, " (stopped where %s)" % ", ".join(met) if not met.is_empty() else ""],
		followed >= 3 and worst < 3.0)


# -- the gear train without a pointer ---------------------------------------------------


## 8020's crank turned 20° through Grab itself, as the drag turns it, read
## ahead as the app reads it: the sails turn 1 in 9 (docs/MECHANISMS.md).
## Headless, for git bisect: godot --headless --path . --script
## src/dev/grab_probe.gd -- --gears
func _gears_headless() -> void:
	print("\ngears, headless: 8020-1_Windmill.mpd")
	if not await _open("res://vendor/omr/files/8020-1_Windmill.mpd"):
		_failures += 1
		return
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	print("    %s; the gear trains %s" % [bodies.summary(),
		"read" if _grab._mechanism != null else "NOT read"])
	var chosen: Dictionary = _choose(bodies, "gear")
	if chosen.is_empty():
		_check("gears: a gear axle on a joint", false)
		return
	var child: int = chosen["child"]
	var key: int = int((bodies.members[child] as PackedInt64Array)[0])
	var grab := Grab.new()
	grab.world = _world
	grab.builder = _builder
	grab.library = _library
	grab.bodies = bodies
	grab.shared_mechanism = _grab._mechanism
	var state: String = grab.begin(key, _world.get_brick(key).transform.origin)
	print("    grabbed #%d %s: %s %s" % [key, _world.get_brick(key).part_id, state, grab.why])
	if grab.mechanism == null and _grab._mechanism != null:
		var driven: int = _grab._mechanism.body_of(key)
		var said: Dictionary = _grab._mechanism.solve({driven: 1.0})
		print("    (Mechanism on its own: body %d, joint %s, %s)" % [driven,
			"yes" if _grab._mechanism.joint_of(driven) != null else "none", str(said["said"])])
	grab.turn_to(20.0)
	_check("gears: the crank's drag drives %d parts" % grab.coupled.size(), not grab.coupled.is_empty())
	if not grab.coupled.is_empty():
		_gear_check("gears", grab)


# -- copies of one sub-assembly --------------------------------------------------------


## Two alike minifigures, copies of one sub-assembly: the first's arm
## posed, the second's stays where it was, and the first is a sub-assembly of
## its own in the same step; one undo puts back both the arm and the copy.
## Then the same over MCP, on the second's arm.
func _two_figures() -> Array:
	_main.call("clear_model")
	await _frames(3)
	var figure := Minifig.new()
	var parts: Array = figure.assemble(_library)
	var out: Array = []
	for n: int in 2:
		var at := Transform3D(Basis.IDENTITY, Vector3(-30.0 + 60.0 * n, 0.0, 0.0))
		var ids: PackedInt64Array = _builder.put_figure(parts, "Figure", at)
		var path: String = "Figure#%d" % (n + 1)
		for key: int in ids:
			_world.get_brick(key).unit = path
			_world.get_brick(key).group = Assemblies.group_of(path)
		out.append(ids)
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(10)
	_builder.forget_history()
	_verbs.set_mode("select")
	return out


func _copies() -> void:
	print("\ncopies: two alike minifigures")
	var figures: Array = await _two_figures()
	var first: PackedInt64Array = figures[0]
	var second: PackedInt64Array = figures[1]
	var assemblies: Assemblies = (_main.get("_shell") as Shell).assemblies
	_check("copies: two minifigures, copies of one sub-assembly (%d parts each)" % first.size(),
		first.size() > 5 and assemblies.copies_of("Figure#1").size() == 1)
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	var arm: int = _arm_of(first)
	if arm == 0:
		_check("copies: the first figure has an arm on its shoulder", false)
		return
	var child: int = int(bodies.body_of[arm])
	_frame_on(PackedInt64Array(Array(first) + Array(second)))
	await _frames(20)
	var before: Dictionary = _snapshot()
	var depth: int = _builder.history_depth()
	var press: Dictionary = _press_point(bodies.members[child], bodies)
	if press.is_empty():
		_check("copies: the first figure's arm is under the pointer somewhere", false)
		return
	var screen: Vector2 = press["screen"]
	await _move(screen, 0)
	await _button(screen, true)
	await _move(screen + Vector2(0, 7), MOUSE_BUTTON_MASK_LEFT)
	var grab: Grab = _grab.grab
	if grab == null:
		_check("copies: the arm is grabbed (%s)" % _grab.last_words, false)
		await _button(screen, false)
		return
	for n: int in range(1, 9):
		var turned: Vector3 = _about(grab.pivot, grab.axis, -6.0 * n) * grab._hold
		await _move(_camera.unproject_position(turned), MOUSE_BUTTON_MASK_LEFT)
	await _button(_last_screen, false)
	await _settled()
	await _frames(3)
	var unmoved: bool = true
	for key: int in second:
		if _world.get_brick(key).transform != before[key]:
			unmoved = false
	var moved: bool = false
	for key: int in first:
		if _world.get_brick(key).transform != before[key]:
			moved = true
	var own: String = Assemblies.path_of(_world.get_brick(arm))
	_check("copies: the first figure's arm turned (%s)" % _grab.last_words, moved)
	_check("copies: the second figure did not move", unmoved)
	_check("copies: the first is a sub-assembly of its own now (%s, %d other copies)" % [own,
		assemblies.copies_of(own).size()], not own.begins_with("Figure#") or assemblies.copies_of(own).is_empty())
	_check("copies: the status bar says so", _grab.last_words.contains("is now its own")
		and _grab.last_words.contains("the other one stays as it was"))
	_check("copies: one step to undo (%s)" % (_builder.history_words(1)[0]
		if _builder.history_depth() > depth else "none"), _builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(3)
	_check("copies: one undo puts back the arm and the copy (%s, %s)" % [_differs(before),
		Assemblies.path_of(_world.get_brick(arm))], _differs(before) == "none differs"
		and Assemblies.path_of(_world.get_brick(arm)) == "Figure#1")
	# Over MCP, the second's arm.
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var other_arm: int = _arm_of(second)
	var said: String = str(await tools.run("move_part", {"part": "#%d" % other_arm, "degrees": -30}))
	print("    move_part: %s" % said.replace("\n", " | "))
	var first_still: bool = true
	for key: int in first:
		if _world.get_brick(key).transform != before[key]:
			first_still = false
	_check("copies over MCP: the second's arm turns, the first stays, and the reply says so",
		said.contains("is now its own") and first_still
		and _world.get_brick(other_arm).transform != before[other_arm])
	_builder.undo()
	await _frames(3)
	_check("copies over MCP: one undo puts it back (%s)" % _differs(before),
		_differs(before) == "none differs")


## A minifigure's arm among [param ids]: 3818 or 3819.
func _arm_of(ids: PackedInt64Array) -> int:
	for key: int in ids:
		var part: String = _world.get_brick(key).part_id
		if part.begins_with("3818") or part.begins_with("3819"):
			return key
	return 0


# -- the end of a chain ----------------------------------------------------------------


## Held still on the end part, then dragged: the end goes under the pointer
## along the chain back to the anchor, each joint within the range read for
## it, and let go it is one step that undo takes back. [param path] empty:
## the two minifigures, the first's hand.
func _chain_case(name: String, path: String, end: String) -> void:
	print("\n%s" % name)
	var ids: PackedInt64Array = PackedInt64Array()
	if path.is_empty():
		var figures: Array = await _two_figures()
		ids = figures[0]
	elif not await _open(path):
		return
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	# The end: a hand, or the body furthest from the anchor by its chain.
	var target_key: int = 0
	if end == "hand":
		for key: int in ids:
			if _world.get_brick(key).part_id.begins_with("3820"):
				target_key = key
				break
	else:
		var longest: int = 0
		for body: int in bodies.members:
			var links: int = 0
			for link: Bodies.Link in bodies.chain(body):
				if link.axis != Vector3.ZERO:
					links += 1
			if links > longest:
				longest = links
				target_key = int((bodies.members[body] as PackedInt64Array)[0])
	if target_key == 0:
		_check("%s: an end with joints back from it" % name, false)
		return
	var child: int = int(bodies.body_of[target_key])
	_frame_on(PackedInt64Array())
	await _frames(20)
	var before: Dictionary = _snapshot()
	var depth: int = _builder.history_depth()
	var press: Dictionary = _press_point(bodies.members[child], bodies)
	if press.is_empty():
		_check("%s: the end is under the pointer somewhere" % name, false)
		return
	var screen: Vector2 = press["screen"]
	await _move(screen, 0)
	await _button(screen, true)
	# Held still, as a person does to take it by its chain.
	await create_timer(0.5).timeout
	await _move(screen + Vector2(0, 7), MOUSE_BUTTON_MASK_LEFT)
	var links: GrabChain = _grab.chain
	_check("%s: held still then dragged, it is taken by its chain (%s)" % [name,
		links.said if links != null else _grab.last_words], links != null)
	if links == null:
		await _button(screen, false)
		return
	print("    %d joints, their ranges %s, read in %.0f ms" % [links.joints.size(),
		str(links.ranges), links.range_ms])
	# A place it can reach: each joint turned a third of the way to the end of
	# its range, drawn where that puts the end.
	var want := PackedFloat64Array()
	for n: int in links.joints.size():
		var span: Vector2 = links.ranges[n]
		want.append(span.y / 3.0 if span.y > -span.x else span.x / 3.0)
	var keep := PackedFloat64Array(links.angles)
	for n: int in want.size():
		links.angles[n] = want[n]
	var goal: Vector3 = links.end_point()
	for n: int in keep.size():
		links.angles[n] = keep[n]
	var goal_screen: Vector2 = _camera.unproject_position(goal)
	for n: int in range(1, 13):
		await _move(screen.lerp(goal_screen, float(n) / 12.0), MOUSE_BUTTON_MASK_LEFT)
	await _frames(2)
	var off: float = _camera.unproject_position(links.end_point()).distance_to(goal_screen)
	var within: bool = true
	for n: int in links.angles.size():
		within = within and links.angles[n] >= links.ranges[n].x - 0.01 \
			and links.angles[n] <= links.ranges[n].y + 0.01
	_check("%s: the end is drawn under the pointer, %.1f px off; every joint within its range (%s)"
		% [name, off, str(links.angles)], off < 4.0 and within)
	if _windowed:
		await _shot(name.replace(": ", "_").replace("'", ""), "2_mid")
	_check("%s: the status bar says chain (%s)" % [name, _grab._said], _grab._said.to_lower().contains("chain"))
	await _button(_last_screen, false)
	await _frames(3)
	print("    said: %s" % _grab.last_words)
	_check("%s: let go, it is tested and kept as one step (%s)" % [name, _builder.history_words(1)[0]
		if _builder.history_depth() > depth else "none"], _builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(3)
	_check("%s: one undo puts it back (%s)" % [name, _differs(before)], _differs(before) == "none differs")


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
	_check("...and undo puts it back exactly (%s)" % _differs(before), _differs(before) == "none differs")


# -- a big model: frame timings ---------------------------------------------------------


func _big() -> void:
	var path: String = "res://vendor/omr/files/7191-1.mpd"
	print("\nframe timings on a big model: %s" % path.get_file())
	if not await _open(path):
		return
	# As a person pauses after opening: the app reads the joints ahead.
	var waited: int = Time.get_ticks_msec()
	while not _grab.is_ready() and Time.get_ticks_msec() - waited < 60000:
		await process_frame
	print("    %d parts read ahead in %d ms %s (%s), %.1f s after it opened" % [_world.brick_count(),
		_grab.ready_ms, "on a worker" if _grab.ready_off_thread else "on the main thread",
		str(_grab.ready_took), float(Time.get_ticks_msec() - waited) / 1000.0])
	_check("the joints are read ahead of the press", _grab.is_ready())
	var bodies: Bodies = _grab._bodies
	print("    %s" % bodies.summary())
	# The biggest sections first that a pointer can land on.
	var tried: Array = []
	for link: Bodies.Link in bodies.links:
		var child: int = link.b if bodies.parent_link.get(link.b) == link else link.a
		if bodies.parent_link.get(child) != link or link.kind == "stud":
			continue
		tried.append([bodies.parts_of(bodies.beyond(child)).size(), child])
	tried.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	_frame_on(PackedInt64Array())
	await _frames(10)
	var press: Dictionary = {}
	var child: int = -1
	for entry: Array in tried.slice(0, 12):
		press = _press_point(bodies.members[int(entry[1])], bodies)
		if not press.is_empty():
			child = int(entry[1])
			break
	if press.is_empty():
		_check("a section of the big model is under the pointer somewhere", false)
		return
	var screen: Vector2 = press["screen"]
	var before: Dictionary = _snapshot()
	await _move(screen, 0)
	await _button(screen, true)
	var began: int = Time.get_ticks_usec()
	await _move(screen + Vector2(0, 7), MOUSE_BUTTON_MASK_LEFT)
	var grabbed_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	var grab: Grab = _grab.grab
	if grab == null or grab.state != "moves":
		_check("the big model's section is grabbed (%s)" % _grab.last_words, false)
		await _button(screen, false)
		return
	var frame_worst: float = 0.0
	var frame_total: float = 0.0
	for n: int in 60:
		var turned: Vector3 = _about(grab.pivot, grab.axis if grab.axis != Vector3.ZERO
			else Vector3.UP, 3.0 * n) * grab._hold
		var at: int = Time.get_ticks_usec()
		await _move(_camera.unproject_position(turned), MOUSE_BUTTON_MASK_LEFT)
		var spent: float = float(Time.get_ticks_usec() - at) / 1000.0
		frame_worst = maxf(frame_worst, spent)
		frame_total += spent
	if _windowed:
		await _shot("big", "2_mid")
	await _button(_last_screen, false)
	var settling: int = Time.get_ticks_msec()
	await _settled()
	print("    let go: checked and kept in %d ms, its worst frame %.1f ms; the keeping frame %.0f ms %s" % [
		Time.get_ticks_msec() - settling, _grab.worst_settle_ms, _grab.keep_ms, str(_grab.keep_took)])
	_timings["big"] = {"file": path.get_file(), "parts": _world.brick_count(),
		"moving": grab.moving.size(), "frames": _grab.frames, "mean_ms": snappedf(_grab.mean_ms, 0.01),
		"worst_ms": snappedf(_grab.worst_ms, 0.01), "first_grab_ms": snappedf(grabbed_ms, 0.1),
		"ready_ms": _grab.ready_ms, "worst_follow_ms": snappedf(_grab.worst_follow_ms, 0.01),
		"worst_weigh_ms": snappedf(_grab.worst_weigh_ms, 0.01),
		"app_frame_mean_ms": snappedf(frame_total / 60.0, 0.01), "app_frame_worst_ms": snappedf(frame_worst, 0.01)}
	print("    the press: %s" % str(grab.begin_took))
	print(("    %d parts, %s (%d moving): the grab began in %.0f ms; %d drag frames, mean %.2f ms, "
		+ "worst %.2f ms (following %.2f, weighing %.2f); whole frames as drawn here in software, "
		+ "mean %.1f ms, worst %.1f ms") % [_world.brick_count(), grab.said, grab.moving.size(),
		grabbed_ms, _grab.frames, _grab.mean_ms, _grab.worst_ms, _grab.worst_follow_ms,
		_grab.worst_weigh_ms, frame_total / 60.0, frame_worst])
	_check("the grab began within 200 ms at %d parts (%.0f ms)" % [_world.brick_count(), grabbed_ms],
		grabbed_ms < 200.0)
	_check("a drag frame's work at %d parts is under 33 ms on average and 100 at worst (%.2f, %.2f)"
		% [_world.brick_count(), _grab.mean_ms, _grab.worst_ms],
		_grab.mean_ms < 33.0 and _grab.worst_ms < 100.0)
	_check("let go, no frame of checking and keeping it is over 100 ms (%.1f)" % _grab.worst_settle_ms,
		_grab.worst_settle_ms < 100.0)
	_builder.undo()
	await _frames(3)
	_check("big: one undo puts every part back exactly (%s)" % _differs(before),
		_differs(before) == "none differs")


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
				# The crank: the gear axle that turns the slowest body of the
				# train slowest, which on 8020 is the sails at 1 in 9.
				for key: int in moved:
					if not Mechanism.spec_of(_world.get_brick(key).part_id).is_empty():
						ok = link.kind == "axle" or link.kind == "pin"
						score = _slowest_driven(key)
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


## How many turns of [param key]'s axle the slowest body it drives takes for
## one of its own: a crank's is the largest.
func _slowest_driven(key: int) -> float:
	var simulation: Simulation = Simulation.read(_world.bricks(), _library, _store.scenery)
	simulation.drive(simulation.model.body_of(key))
	var slowest: float = 0.0
	for body: int in simulation.turning:
		var rate: float = absf(float(simulation.rates[body]))
		if rate > 1e-6:
			slowest = maxf(slowest, 1.0 / rate)
	return slowest


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
	var only: Dictionary = {}
	for key: int in ids:
		only[key] = true
	for brick: BrickWorld.Brick in _world.bricks():
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		# The model (or the parts asked for), not the baseplate laid under it.
		if info == null or _store.scenery.has(brick.id) or (not only.is_empty() and not only.has(brick.id)):
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


## Which part stands other than in [param before], and by how much.
func _differs(before: Dictionary) -> String:
	var now: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		now[brick.id] = brick.transform
	# The other copies of a sub-assembly follow an edit of one (Assemblies.
	# after_edit) by being laid again, under new numbers: the same parts in the
	# same places is the same model.
	var placed_now: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var spot: String = "%s %s" % [brick.part_id, _rounded(brick.transform)]
		placed_now[spot] = int(placed_now.get(spot, 0)) + 1
	for key: Variant in before:
		var a: Transform3D = before[key]
		if not now.has(key):
			var spot: String = "%s %s" % [str(_names.get(key, "?")), _rounded(a)]
			if int(placed_now.get(spot, 0)) > 0:
				placed_now[spot] = int(placed_now[spot]) - 1
				continue
			return "#%d %s is gone" % [int(key), str(_names.get(key, "?"))]
		var b: Transform3D = now[key]
		if a != b:
			return "#%d %s off by %.6f LDU, %.6f in its turn" % [int(key),
				_world.get_brick(int(key)).part_id, a.origin.distance_to(b.origin),
				(a.basis.x - b.basis.x).length() + (a.basis.y - b.basis.y).length()]
	return "none differs"


## Every part of the model where it stands; not the baseplate the floor lays
## under it, which grows (new plates, new numbers) when a section swings out
## past its edge.
func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out[brick.id] = brick.transform
			_names[brick.id] = brick.part_id
	return out


var _names: Dictionary = {}
## Frames each move is given before it is read (--move-frames=N).
var _move_frames: int = 1


static func _rounded(at: Transform3D) -> String:
	return "%s %s %s %s" % [at.origin.snapped(Vector3.ONE * 0.01), at.basis.x.snapped(Vector3.ONE * 0.001),
		at.basis.y.snapped(Vector3.ONE * 0.001), at.basis.z.snapped(Vector3.ONE * 0.001)]


static func _near(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.05 and a.basis.x.distance_to(b.basis.x) < 0.001 \
		and a.basis.y.distance_to(b.basis.y) < 0.001 and a.basis.z.distance_to(b.basis.z) < 0.001


## Until a big section let go has been checked and kept.
func _settled() -> void:
	var waited: int = Time.get_ticks_msec()
	while _grab.is_settling() and Time.get_ticks_msec() - waited < 20000:
		await process_frame


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
	await _frames(_move_frames)


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
