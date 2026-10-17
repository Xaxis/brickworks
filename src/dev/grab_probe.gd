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

const OUT := "/mnt/Projects/brickworks/bench/results/grab3-2026-10-17"
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

## Closed loops on real sets (Linkage), each against its closed form: a
## steering's arms and track rod (a four-bar: the rocker's turn from the
## circles its pins move on) and an engine's crank, rod and piston (a
## crank-slider: the piston's travel from the rod's length and the crank's
## throw).
const LOOPS: Array = [
	["four-bar: a steering's arms and track rod", "res://vendor/omr/files/8020-1_Jeep.mpd", "fourbar"],
	["crank and piston: an engine", "res://vendor/omr/files/8218-1.mpd", "engine"],
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
	if only.is_empty() or only == "loops" or only == "fourbar" or only == "engine":
		for loop: Array in LOOPS:
			if only.is_empty() or only == "loops" or only == loop[2]:
				await _loop_case(loop[0], loop[1], loop[2])
	if only.is_empty() or only == "racks":
		var asked_racks: Array = []
		for arg: String in args:
			if arg.begins_with("--rack-set="):
				asked_racks.append(["rack and pinion: %s" % arg.get_file(), "res://" + arg.trim_prefix("--rack-set=")])
		for one: Array in (RACKS if asked_racks.is_empty() else asked_racks):
			await _rack_case(one[0], one[1])
	if only.is_empty() or only == "scissor":
		await _scissor_case()
	if only.is_empty() or only == "falling":
		await _made_fall()
	if only.is_empty() or only == "follow":
		var gear_sets: Array = []
		for arg: String in args:
			if arg.begins_with("--list="):
				for line: String in FileAccess.get_file_as_string(arg.trim_prefix("--list=")).split("\n"):
					if not line.strip_edges().is_empty():
						gear_sets.append("res://" + line.strip_edges())
		await _follow_case(gear_sets if not gear_sets.is_empty() else FOLLOWING)
	if only == "tipping":
		var asked: Array = []
		for arg: String in args:
			if arg.ends_with(".mpd") or arg.ends_with(".ldr"):
				asked.append(arg if arg.begins_with("res://") else "res://" + arg)
			if arg.begins_with("--list="):
				for line: String in FileAccess.get_file_as_string(arg.trim_prefix("--list=")).split("\n"):
					if not line.strip_edges().is_empty():
						asked.append("res://" + line.strip_edges())
		await _topple_case(TIPPING if asked.is_empty() else asked)
	if only == "settling":
		var listed: Array = []
		for arg: String in args:
			if arg.begins_with("--list="):
				for line: String in FileAccess.get_file_as_string(arg.trim_prefix("--list=")).split("\n"):
					if not line.strip_edges().is_empty():
						listed.append("res://" + line.strip_edges())
		await _settle_case(SETTLING if listed.is_empty() else listed)
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
		print("    %-9s %s holds=%s slide=%s detent=%s %s at %s way %s" % [link.kind,
			_parts_said(bodies, link), link.holds, link.slide, link.detent,
			"CLOSES A LOOP" if bodies.closing.has(link) else "moves " + bodies.named(moved),
			link.point.snapped(Vector3.ONE * 0.1), link.axis.snapped(Vector3.ONE * 0.01)])
	if "--connectors" in OS.get_cmdline_user_args():
		var shown: Dictionary = {}
		var asked: Array = []
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--parts="):
				for part: String in arg.trim_prefix("--parts=").split(","):
					for brick: BrickWorld.Brick in _world.bricks():
						if brick.part_id == part:
							asked.append([brick.id])
							print("    #%d %s at %s" % [brick.id, part, brick.transform])
		for link: Bodies.Link in bodies.closing:
			asked.append_array(link.pairs)
		for pair: Array in asked:
				for key: int in pair:
					var part: String = _world.get_brick(key).part_id
					if shown.has(part):
						continue
					shown[part] = true
					var mesh: Lbm.PartMesh = _library.mesh_for(part)
					print("    %s %s:" % [part, _library.parts[part].name])
					for c: Lbm.Connector in mesh.connectors:
						print("      %s %s at %s way %s len %s r %s" % [c.kind, c.gender, c.position,
							c.axis, c.length, c.radius])


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


# -- closed loops ----------------------------------------------------------------------


## The joint between bodies [param x] and [param y], or null.
static func _link_between(bodies: Bodies, x: int, y: int) -> Bodies.Link:
	for link: Bodies.Link in bodies.touching.get(x, []):
		if link.other(x) == y:
			return link
	return null


## Open [param path], find its loop of [param kind], grab the loop's driver
## with the pointer and turn it: every frame the loop's other joints stand
## where its closed form puts them.
func _loop_case(name: String, path: String, kind: String) -> void:
	print("\n%s: %s" % [name, path.get_file()])
	if not await _open(path):
		return
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	print("    %s" % bodies.summary())
	# The four bodies round the loop: ground, crank (driven), coupler,
	# rocker or piston.
	var found: Dictionary = _find_loop(bodies, kind)
	if found.is_empty():
		_check("%s: the set has the loop" % name, false)
		return
	var crank: int = found["crank"]
	var coupler: int = found["coupler"]
	var last: int = found["last"]
	var driver: Bodies.Link = bodies.parent_link[crank]
	var crank_pin: Bodies.Link = _link_between(bodies, crank, coupler)
	var far_pin: Bodies.Link = _link_between(bodies, coupler, last)
	var far_joint: Bodies.Link = found["far_joint"]
	print("    crank %s %s at %s; coupler %s; %s %s on %s" % [bodies.named([crank]), driver.kind,
		driver.point, bodies.named([coupler]), "piston" if kind == "engine" else "rocker",
		bodies.named([last]), far_joint.kind])
	# Seen so the loop reads. A steering from above, everything over it cut
	# away (K); an engine from along its crank, everything but the crank, the
	# rod and the piston drawn see-through (x-ray, I).
	var line: Vector3 = driver.axis.normalized()
	var shown: PackedInt64Array = bodies.parts_of(bodies.beyond(crank) + bodies.beyond(last) + [coupler])
	if kind == "engine":
		var keep: Dictionary = {}
		for key: int in bodies.parts_of([crank, coupler, last]):
			keep[key] = true
		var ghosts: Dictionary = {}
		for brick: BrickWorld.Brick in _world.bricks():
			if not keep.has(brick.id) and not _store.scenery.has(brick.id):
				ghosts[brick.id] = true
		_world.set_xray(ghosts)
		_builder.lattice.see_through = ghosts
		# From the crank's side of its axle, the wheel on it behind.
		var crank_at := Vector3.ZERO
		var body_at := Vector3.ZERO
		for key: int in bodies.members[crank]:
			var brick: BrickWorld.Brick = _world.get_brick(key)
			var middle: Vector3 = brick.transform * _library.parts[brick.part_id].bounds.get_center()
			body_at += middle / float((bodies.members[crank] as PackedInt64Array).size())
			if brick.part_id.begins_with("2853"):
				crank_at = middle
		var side: float = -signf((body_at - crank_at).dot(line))
		if side == 0.0:
			side = 1.0
		_camera.look_from((line * side + Vector3(0.0, 0.45, 0.35)).normalized())
		shown = bodies.parts_of([coupler, last])
	else:
		# Cut just over the arms and the track rod, the wheels below the cut
		# with them.
		var top: float = -INF
		for key: int in bodies.parts_of([crank, coupler, last]):
			var brick: BrickWorld.Brick = _world.get_brick(key)
			top = maxf(top, (brick.transform * _library.parts[brick.part_id].bounds).end.y)
		var cut := Plane(Vector3.UP, top + 1.0)
		_world.set_cut(true, cut, false)
		_builder.lattice.cut = cut
		_camera.look_from(Vector3(0.05, 1.0, 0.12).normalized())
	_frame_on(shown)
	await _frames(20)
	var before: Dictionary = _snapshot()
	var depth: int = _builder.history_depth()
	var press: Dictionary = _press_off_line(bodies.members[crank], driver.point, line)
	for side: Vector3 in [Vector3(1, 0.6, 1), Vector3(-1, 0.6, 1), Vector3(1, 0.6, -1),
			Vector3(-1, 0.6, -1)]:
		if not press.is_empty():
			break
		_camera.look_from(side.normalized())
		_frame_on(bodies.parts_of([crank, coupler, last]))
		await _frames(10)
		press = _press_point(bodies.members[crank], bodies)
	if press.is_empty():
		_check("%s: the crank is under the pointer somewhere" % name, false)
		return
	if _windowed:
		await _shot(name.get_slice(":", 0), "1_before")
	var screen: Vector2 = press["screen"]
	# Past the slop the way the crank turns there, as a hand starts a turn:
	# the first move decides between turning and sliding along the axle.
	var ray_from: Vector3 = _camera.ray_origin(screen)
	var ray_way: Vector3 = _camera.ray_normal(screen).normalized()
	var hit: BrickLattice.Hit = _builder.lattice.raycast(ray_from, ray_way)
	var slop := Vector2(0, 7)
	if hit.is_valid():
		var on: Vector3 = ray_from + ray_way * hit.distance
		var tangent: Vector3 = line.cross(on - driver.point)
		if tangent.length() > 0.5:
			slop = (_camera.unproject_position(on + tangent.normalized() * 3.0) - screen).normalized() * 7.0
	await _move(screen, 0)
	await _button(screen, true)
	await _move(screen + slop, MOUSE_BUTTON_MASK_LEFT)
	var grab: Grab = _grab.grab
	if grab == null:
		print("    (press state: grabbing=%s dragging=%s carrying=%s press_brick=%s mode=%s chain=%s)" % [
			_main.get("_grabbing"), _main.get("_dragging_part"), _builder.is_carrying(),
			_main.get("_press_brick"), _verbs.mode, _grab.chain != null])
		var trial := Grab.new()
		trial.world = _world
		trial.builder = _builder
		trial.library = _library
		trial.bodies = bodies
		print("    (Grab.begin on #%d %s directly: %s %s)" % [int(press["brick"]),
			_world.get_brick(int(press["brick"])).part_id,
			trial.begin(int(press["brick"]), _world.get_brick(int(press["brick"])).transform.origin),
			trial.why])
	_check("%s: a drag on the crank takes the loop (%s)" % [name, _grab.last_words if grab == null
		else grab.said], grab != null and grab.state == "moves" and grab.linkage != null)
	if grab == null or grab.linkage == null:
		await _button(screen, false)
		return
	var linkage: Linkage = grab.linkage
	print("    %s; %d joints, %d closing, moving %d parts" % [linkage.said(), linkage.links.size(),
		linkage.closing.size(), grab.moving.size()])
	if "--debug" in OS.get_cmdline_user_args():
		for n: int in linkage.links.size():
			var one: Bodies.Link = linkage.links[n]
			print("    (joint %d: %s %s at %s way %s, turn col %d, slide col %d)" % [n, one.kind,
				_parts_said(bodies, one), one.point, one.axis, linkage.turn_col[n], linkage.slide_col[n]])
		for one: Bodies.Link in linkage.closing:
			print("    (closing: %s %s at %s way %s slide %s)" % [one.kind, _parts_said(bodies, one),
				one.point, one.axis, one.slide])
		for want: float in [3.0, 10.0]:
			var reached: float = rad_to_deg(linkage.reach(deg_to_rad(want)))
			print("    (loop to %.0f°: reached %.2f°, residual %.4f after %d iterations; q %s; derivatives off by %.6f)"
				% [want, reached, linkage.residual, linkage.iterations, str(linkage.q),
				linkage.jacobian_error()])
			print("    (%s; residual %s)" % [linkage.jacobian_said(), str(linkage.last_residual)])
			var at: Dictionary = linkage.transforms(grab.rest)
			print("    (room there: %s, met %s)" % [grab.has_room(at), str(grab.blocked_by.map(
				func(k: int) -> String: return "#%d %s" % [k, _world.get_brick(k).part_id]))])
	# By the pointer: round as far as it goes, each frame against the closed
	# form.
	var targets: Array = []
	var span: float = 360.0 if kind == "engine" else 40.0
	var step: float = 6.0 if kind == "engine" else 2.0
	var n: int = 1
	while step * n <= span:
		targets.append(step * n)
		n += 1
	if kind != "engine":
		for k: int in range(n - 2, -n, -1):
			targets.append(step * k)
	var hold: Vector3 = grab._hold
	var followed: int = 0
	var worst_follow: float = 0.0
	var worst_form: float = 0.0
	var checked: int = 0
	var low_s: float = INF
	var high_s: float = -INF
	var stops: int = 0
	var mid_shot: bool = false
	var form := {"prev": NAN}
	var frame_worst: float = 0.0
	for target: float in targets:
		var turned: Vector3 = _about(grab.pivot, grab.axis, target) * hold
		var began: int = Time.get_ticks_usec()
		await _move(_camera.unproject_position(turned), MOUSE_BUTTON_MASK_LEFT)
		frame_worst = maxf(frame_worst, float(Time.get_ticks_usec() - began) / 1000.0)
		if grab.stopped:
			stops += 1
		else:
			worst_follow = maxf(worst_follow, absf(wrapf(grab.angle - target, -180.0, 180.0)))
			followed += 1
		var off: float = _closed_form(kind, grab, driver, crank_pin, far_pin, far_joint, last, form)
		if not is_nan(off):
			worst_form = maxf(worst_form, off)
			checked += 1
		if kind == "engine":
			low_s = minf(low_s, float(form["s"]))
			high_s = maxf(high_s, float(form["s"]))
		if not mid_shot and _windowed and absf(grab.angle) > (90.0 if kind == "engine" else 20.0):
			mid_shot = true
			await _clean_shot(name.get_slice(":", 0), "2_mid")
	print("    (mode %s, angle %.1f, held %.1f LDU off the line, pressed #%d %s)" % [grab.mode, grab.angle,
		((grab._hold - grab.pivot) - grab.axis * (grab._hold - grab.pivot).dot(grab.axis)).length(),
		int(press["brick"]), _world.get_brick(int(press["brick"])).part_id])
	_check("%s: the crank follows the pointer in %d frames, to %.2f° (%d stopped by the model or the loop)"
		% [name, followed, worst_follow, stops], followed >= 6 and worst_follow <= 1.5)
	var unit: String = "LDU" if kind == "engine" else "°"
	_check("%s: in %d poses the loop's far joint stands where its closed form says, to %.3f %s" % [name,
		checked, worst_form, unit], checked >= 6 and worst_form < (0.1 if kind == "engine" else 0.1))
	if kind == "engine":
		var throw: float = float(form["throw"])
		_check("%s: the piston's stroke over a turn is twice the crank's throw (%.2f LDU, 2 x %.2f)" % [
			name, high_s - low_s, throw], absf((high_s - low_s) - 2.0 * throw) < 0.2)
	# A pinion in the loop's rack (8020's column on its track rod) turns as the
	# rack's place along its teeth says: dragged from the wheel, the column
	# turns.
	for mesh: Racks.Pinion in linkage.racks:
		var keyed := func(key: int) -> Transform3D:
			return (grab.placed.get(key, grab.rest.get(key, _world.get_brick(key).transform)) as Transform3D) \
				* (grab.rest.get(key, _world.get_brick(key).transform) as Transform3D).affine_inverse()
		var against: Transform3D = (keyed.call(mesh.rack) as Transform3D).affine_inverse() \
			* (keyed.call(mesh.gear) as Transform3D)
		var psi: float = _turn_about(against.basis, mesh.axis)
		var along: float = mesh.line.dot(against * mesh.centre - mesh.centre)
		var by_teeth: float = -Racks.pitch() * float(mesh.teeth) * psi / 360.0 * signf(mesh.rate)
		_check("%s: the pinion in the track rod's rack turned %.2f° with it, %.3f teeth: the rack %.2f LDU along them, the teeth %.2f"
			% [name, psi, psi / 360.0 * mesh.teeth, along, by_teeth], absf(psi) > 1.0
			and absf(along - by_teeth) < 0.1)
	print("    drag frames: worst %.1f ms whole (following %.2f ms worst: %s; drawing and weighing the rest), %d solves"
		% [frame_worst, _grab.worst_follow_ms, _grab.worst_follow_said, linkage.solves])
	print("    the slowest part to test: %s" % grab.slowest_said)
	_timings[name] = {"frames": _grab.frames, "worst_ms": snappedf(_grab.worst_ms, 0.01),
		"mean_ms": snappedf(_grab.mean_ms, 0.01), "worst_follow_ms": snappedf(_grab.worst_follow_ms, 0.01),
		"moving": grab.moving.size(), "parts": _world.brick_count()}
	# Set to a pose by hand, the far joint's turn against the form, printed.
	await _button(_last_screen, false)
	await _frames(3)
	await _settled()
	print("    said: %s" % _grab.last_words)
	_check("%s: let go, it is one step to undo (%s)" % [name, _builder.history_words(1)[0]
		if _builder.history_depth() > depth else "none"], _builder.history_depth() == depth + 1)
	if _windowed:
		await _clean_shot(name.get_slice(":", 0), "3_after")
	_builder.undo()
	await _frames(3)
	_check("%s: one undo puts every part back exactly (%s)" % [name, _differs(before)],
		_differs(before) == "none differs")
	_world.set_xray({})
	_builder.lattice.see_through = {}
	_world.set_cut(false)
	_builder.lattice.cut = Plane()


## The loop round [param kind]: {crank, coupler, last, far_joint}. A
## four-bar: a closing joint whose loop is four turning joints on parallel
## lines, two of them on the anchor. An engine: the loop through a piston.
func _find_loop(bodies: Bodies, kind: String) -> Dictionary:
	for loop: Bodies.Link in bodies.closing:
		var up_a: Array = [loop.a]
		while bodies.parent_link.has(up_a[-1]):
			up_a.append(int(bodies.parent_of[up_a[-1]]))
		var up_b: Array = [loop.b]
		while bodies.parent_link.has(up_b[-1]):
			up_b.append(int(bodies.parent_of[up_b[-1]]))
		var top: int = -1
		for one: int in up_a:
			if up_b.has(one):
				top = one
				break
		if top < 0:
			continue
		# Round the loop from where its two ways meet: down to b, across the
		# closing joint to a, up again.
		var down: Array = up_b.slice(0, up_b.find(top))
		down.reverse()
		var ring: Array = [top] + down + up_a.slice(0, up_a.find(top))
		if ring.size() != 4:
			continue
		var has_piston: bool = false
		for one: int in ring:
			for key: int in bodies.members[one]:
				if _world.get_brick(key).part_id.begins_with("2851"):
					has_piston = true
		if (kind == "engine") != has_piston:
			continue
		var ground: int = ring[0]
		# The crank: the ground's neighbour whose joint turns and does not slide
		# in a cylinder; the far joint: the other's.
		var first: int = ring[1]
		var other_end: int = ring[3]
		var crank: int = first
		var last: int = other_end
		if kind == "engine":
			for one: int in [first, other_end]:
				var piston: bool = false
				for key: int in bodies.members[one]:
					if _world.get_brick(key).part_id.begins_with("2851"):
						piston = true
				if piston:
					last = one
				else:
					crank = one
		var coupler: int = ring[2]
		var far_joint: Bodies.Link = _link_between(bodies, ground, last)
		if bodies.parent_link.get(crank) == null or bodies.parent_of.get(crank) != ground:
			# The crank must hang from the ground for the pointer to turn it.
			var swap: int = crank
			crank = last
			last = swap
			far_joint = _link_between(bodies, ground, last)
		if bodies.parent_of.get(crank) != ground or far_joint == null:
			continue
		if kind == "fourbar":
			var ways: Array = []
			for pair: Array in [[ground, crank], [crank, coupler], [coupler, last], [last, ground]]:
				var one: Bodies.Link = _link_between(bodies, pair[0], pair[1])
				if one == null or one.axis == Vector3.ZERO:
					ways = []
					break
				ways.append(one.axis.normalized())
			if ways.size() != 4 or absf((ways[0] as Vector3).dot(ways[1])) < 0.99 \
					or absf((ways[0] as Vector3).dot(ways[2])) < 0.99 \
					or absf((ways[0] as Vector3).dot(ways[3])) < 0.99:
				continue
		return {"crank": crank, "coupler": coupler, "last": last, "far_joint": far_joint}
	return {}


## How far the loop's far joint stands from where its closed form puts it,
## with the crank at the grab's angle: a four-bar's rocker turn, degrees
## (the coupler's far pin on the circle about the rocker's pivot at the
## coupler's length from its near pin: two circles meeting); an engine's
## piston travel along its cylinder, LDU (the wrist pin on the cylinder's
## line at the rod's length from the crank pin: a quadratic). NAN when the
## form has no answer there. [param form] carries the last answer, to pick
## the root the loop is on.
func _closed_form(kind: String, grab: Grab, driver: Bodies.Link, crank_pin: Bodies.Link,
		far_pin: Bodies.Link, far_joint: Bodies.Link, last: int, form: Dictionary) -> float:
	var axis: Vector3 = driver.axis.normalized()
	var o: Vector3 = driver.point
	var about := func(p: Vector3, degrees: float) -> Vector3:
		return _about(o, axis, degrees) * p
	# The crank pin where the crank's turn puts it; the far pin where it was.
	var pin_now: Vector3 = about.call(crank_pin.point, grab.angle)
	var last_key: int = int((_grab._bodies.members[last] as PackedInt64Array)[0])
	var moved: Transform3D = (grab.placed[last_key] as Transform3D) \
		* (grab.rest[last_key] as Transform3D).affine_inverse()
	# Distances in the plane square to the crank's line: the rod and the
	# track rod may slide along their pins, which the forms do not need.
	var flat := func(v: Vector3) -> Vector3:
		return v - axis * v.dot(axis)
	var length: float = (flat.call(far_pin.point - crank_pin.point) as Vector3).length()
	if kind == "engine":
		var u: Vector3 = far_joint.axis.normalized()
		var w0: Vector3 = far_pin.point
		var gap: Vector3 = flat.call(w0 - pin_now)
		var b: float = u.dot(gap)
		var c: float = gap.length_squared() - length * length
		var disc: float = b * b - c
		if disc < 0.0:
			return NAN
		var roots: Array = [-b + sqrt(disc), -b - sqrt(disc)]
		var prev: float = 0.0 if is_nan(float(form["prev"])) else float(form["prev"])
		var s: float = roots[0] if absf(float(roots[0]) - prev) < absf(float(roots[1]) - prev) else roots[1]
		form["prev"] = s
		form["s"] = s
		form["throw"] = (flat.call(crank_pin.point - o) as Vector3).length()
		var travelled: float = (moved * w0 - w0).dot(u)
		return absf(travelled - s)
	# Four-bar: in the plane, the far pin on two circles.
	var b0: Vector3 = far_joint.point
	var radius: float = (flat.call(far_pin.point - b0) as Vector3).length()
	var centre: Vector3 = b0 + axis * axis.dot(pin_now - b0)
	var d_vec: Vector3 = flat.call(pin_now - b0)
	var d: float = d_vec.length()
	if d < 0.001 or d > radius + length or d < absf(radius - length):
		return NAN
	var along: float = (radius * radius - length * length + d * d) / (2.0 * d)
	var high: float = sqrt(maxf(radius * radius - along * along, 0.0))
	var ex: Vector3 = d_vec / d
	var ey: Vector3 = axis.cross(ex)
	var first: Vector3 = centre + ex * along + ey * high
	var second: Vector3 = centre + ex * along - ey * high
	var prev_point: Vector3 = form.get("point", far_pin.point)
	var expected: Vector3 = first if first.distance_to(prev_point) < second.distance_to(prev_point) else second
	form["point"] = expected
	var from: Vector3 = flat.call(far_pin.point - b0)
	var to: Vector3 = flat.call(expected - b0)
	var want: float = rad_to_deg(atan2(axis.dot(from.cross(to)), from.dot(to)))
	var got_vec: Vector3 = flat.call(moved * far_pin.point - b0)
	var got: float = rad_to_deg(atan2(axis.dot(from.cross(got_vec)), from.dot(got_vec)))
	form["s"] = got
	return absf(wrapf(got - want, -180.0, 180.0))


# -- racks -----------------------------------------------------------------------------

## Steerings of real sets whose track rod carries a rack that the pinion on the
## steering column pushes: the rack and the two arms on their kingpins are a
## four-bar, held by the pinion's teeth (Racks, Linkage).
const RACKS: Array = [
	["rack and pinion: the steering wheel pushes the track rod's rack", "res://vendor/omr/files/8841-1_Chassis.mpd"],
	["rack and pinion: a racer's steering", "res://vendor/omr/files/8808-1.mpd"],
	["rack and pinion: a column turning its pinion through bevels", "res://vendor/omr/files/8054-1_Model-C.mpd"],
	["rack and pinion: a grader's column through bevels", "res://vendor/omr/files/8828-1_Grader.mpd"],
]
## Tried and not passing, run with --rack-set=: 5533-1_Tractor-Pulling's
## steering stops at 24° against the model, and its arms stand 5.7° and
## 9.2° off this planar hand form (its kingpins lean 3° and stand 6 LDU apart
## in height).


## Turn the steering by the pointer, as a person turns it: the steering
## wheel where the set has one, else the pinion's column. Every frame, by
## hand: the rack has gone a tooth (8 LDU) for every tooth of the pinion's
## turn against it, and the arms stand where the track rod's two pins and
## the rack's place along its teeth put them (two circles, and the rack's
## place found along the near arm's turn by bisection).
func _rack_case(name: String, path: String) -> void:
	print("\n%s: %s" % [name, path.get_file()])
	if not await _open(path):
		return
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	print("    %s" % bodies.summary())
	var meshes: Array[Racks.Pinion] = bodies.racks()
	_check("%s: a pinion stands in a rack (%s)" % [name, ", ".join(meshes.map(
		func(m: Racks.Pinion) -> String: return "%s, %.2f LDU off its pitch line" % [m.said(_world), m.off]))],
		not meshes.is_empty())
	if meshes.is_empty():
		return
	var mesh: Racks.Pinion = meshes[0]
	var pinion: int = int(bodies.body_of[mesh.gear])
	var rack: int = int(bodies.body_of[mesh.rack])
	# The four-bar: the near arm the rack's body hangs from, the far arm its
	# other pin closes on, each on its kingpin.
	var near_pin: Bodies.Link = bodies.parent_link.get(rack)
	var near_arm: int = int(bodies.parent_of.get(rack, -1))
	var far_pin: Bodies.Link = null
	for link: Bodies.Link in bodies.touching.get(rack, []):
		if bodies.closing.has(link):
			far_pin = link
	if near_pin == null or far_pin == null or not bodies.parent_link.has(near_arm):
		_check("%s: the rack is a track rod on two arms" % name, false)
		return
	var far_arm: int = far_pin.other(rack)
	var near_king: Bodies.Link = bodies.parent_link[near_arm]
	var far_king: Bodies.Link = bodies.parent_link.get(far_arm)
	print("    rack %s on its track rod (%s); arms %s and %s on kingpins at %s and %s; pinion %s on %s" % [
		_world.get_brick(mesh.rack).part_id, bodies.named([rack]), bodies.named([near_arm]),
		bodies.named([far_arm]), near_king.point, far_king.point if far_king != null else "?",
		bodies.named([pinion]), bodies.parent_link[pinion].words() if bodies.parent_link.has(pinion) else "?"])
	# Pressed where a person turns it: the steering wheel, else the column.
	# The steering wheel only where turning it reaches the pinion by joints:
	# a wheel that drives its pinion through gears is not read so yet.
	var wheel_body: int = pinion
	for brick: BrickWorld.Brick in _world.bricks():
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		if info == null or not info.name.contains("Steering Wheel") or not bodies.body_of.has(brick.id) \
				or not bodies.parent_link.has(int(bodies.body_of[brick.id])):
			continue
		var trial := Grab.new()
		trial.world = _world
		trial.builder = _builder
		trial.library = _library
		trial.bodies = bodies
		trial.shared_mechanism = _grab.get("_mechanism")
		if trial.begin(brick.id, brick.transform.origin) == "moves" and trial.linkage != null \
				and not trial.linkage.racks.is_empty():
			wheel_body = int(bodies.body_of[brick.id])
		else:
			print("    (the steering wheel does not reach the pinion by joints or gears read here: the pinion's column is turned)")
		break
	# Else a column that turns the pinion's axle through gears (a pair of
	# bevels under the steering wheel): turned there, the train's meshes hold
	# the loop with the rack.
	var train: Mechanism = _grab.get("_mechanism")
	var ratio: float = NAN
	var column_gear: int = 0
	if wheel_body == pinion and train != null and not "--pinion" in OS.get_cmdline_user_args():
		for coupling: Mechanism.Coupling in train.couplings:
			var ends: Array = [coupling.one, coupling.other]
			for k: int in 2:
				var mine: Mechanism.Gear = ends[k]
				var theirs: Mechanism.Gear = ends[1 - k]
				if int(bodies.body_of.get(mine.key, -1)) != pinion or theirs.kind == "worm":
					continue
				var column: int = int(bodies.body_of.get(theirs.key, -1))
				if column < 0 or column == pinion or not bodies.parent_link.has(column):
					continue
				var trial := Grab.new()
				trial.world = _world
				trial.builder = _builder
				trial.library = _library
				trial.bodies = bodies
				trial.shared_mechanism = train
				if trial.begin(theirs.key, _world.get_brick(theirs.key).transform.origin) == "moves" \
						and trial.linkage != null and not trial.linkage.racks.is_empty() \
						and not trial.linkage.gear_meshes.is_empty():
					wheel_body = column
					column_gear = theirs.key
					ratio = float(theirs.teeth) / float(mine.teeth)
					print("    the column that turns the pinion through gears: %s, %d teeth to the pinion axle's %d (%s)"
						% [bodies.named([column]), theirs.teeth, mine.teeth, coupling.how])
					break
			if wheel_body != pinion:
				break
	var driver: Bodies.Link = bodies.parent_link[wheel_body]
	var line: Vector3 = driver.axis.normalized()
	# From above, everything over the arms and the track rod cut away, the
	# steering wheel's column standing out of the cut.
	var top: float = -INF
	for key: int in bodies.parts_of([rack, near_arm, far_arm]):
		var brick: BrickWorld.Brick = _world.get_brick(key)
		top = maxf(top, (brick.transform * _library.parts[brick.part_id].bounds).end.y)
	var steering: PackedInt64Array = bodies.parts_of([rack, near_arm, far_arm, pinion, wheel_body])
	# Cut just over the pinion: the column, the seat and the body over the
	# steering are cut away; the rack, its pinion, the arms and the wheels
	# below the cut stay.
	for key: int in [mesh.gear, column_gear]:
		var gear_brick: BrickWorld.Brick = _world.get_brick(key)
		if gear_brick != null:
			top = maxf(top, (gear_brick.transform * _library.parts[gear_brick.part_id].bounds).end.y)
	var cut := Plane(Vector3.UP, top + 1.0)
	_world.set_cut(true, cut, false)
	_builder.lattice.cut = cut
	_camera.look_from(Vector3(0.05, 1.0, 0.12).normalized())
	_frame_on(steering)
	await _frames(20)
	var before: Dictionary = _snapshot()
	var depth: int = _builder.history_depth()
	# The pinion's own rim first, where the column is turned: a part near
	# the line, seen end on, reads as a slide along it.
	var pressable: PackedInt64Array = bodies.members[wheel_body]
	if wheel_body == pinion:
		pressable = PackedInt64Array([mesh.gear]) + pressable
	elif column_gear != 0:
		pressable = PackedInt64Array([column_gear]) + pressable
	var press: Dictionary = _press_off_line(pressable, driver.point, line)
	for side: Vector3 in [Vector3(1, 0.6, 1), Vector3(-1, 0.6, 1), Vector3(1, 0.6, -1),
			Vector3(-1, 0.6, -1)]:
		if not press.is_empty():
			break
		_camera.look_from(side.normalized())
		_frame_on(steering)
		await _frames(10)
		press = _press_off_line(pressable, driver.point, line)
	if press.is_empty():
		_check("%s: the steering is under the pointer somewhere" % name, false)
		return
	if _windowed:
		await _shot(name.get_slice(":", 0) + " " + path.get_file().get_basename(), "1_before")
	var screen: Vector2 = press["screen"]
	var ray_from: Vector3 = _camera.ray_origin(screen)
	var ray_way: Vector3 = _camera.ray_normal(screen).normalized()
	var hit: BrickLattice.Hit = _builder.lattice.raycast(ray_from, ray_way)
	var slop := Vector2(0, 7)
	if hit.is_valid():
		var on: Vector3 = ray_from + ray_way * hit.distance
		var tangent: Vector3 = line.cross(on - driver.point)
		if tangent.length() > 0.5:
			slop = (_camera.unproject_position(on + tangent.normalized() * 3.0) - screen).normalized() * 7.0
	if slop.length() < 6.0 or is_nan(slop.x):
		slop = Vector2(0, 7)
	print("    pressed #%d %s at %s, first move %s" % [int(press["brick"]),
		_world.get_brick(int(press["brick"])).part_id, screen, slop])
	await _move(screen, 0)
	await _button(screen, true)
	await _move(screen + slop, MOUSE_BUTTON_MASK_LEFT)
	var grab: Grab = _grab.grab
	if grab == null:
		var trial := Grab.new()
		trial.world = _world
		trial.builder = _builder
		trial.library = _library
		trial.bodies = bodies
		print("    (press state: grabbing=%s dragging=%s carrying=%s chain=%s said=%s press_brick=%s; Grab.begin on #%d %s directly: %s %s)" % [
			_main.get("_grabbing"), _main.get("_dragging_part"), _builder.is_carrying(), _grab.chain != null,
			_grab.last_words,
			_main.get("_press_brick"), int(press["brick"]), _world.get_brick(int(press["brick"])).part_id,
			trial.begin(int(press["brick"]), _world.get_brick(int(press["brick"])).transform.origin), trial.why])
	_check("%s: a drag on the steering takes the loop and the rack (%s)" % [name, _grab.last_words
		if grab == null else grab.said], grab != null and grab.state == "moves" and grab.linkage != null
		and not grab.linkage.racks.is_empty())
	if grab == null or grab.linkage == null:
		await _button(screen, false)
		return
	print("    %s; %d joints, moving %d parts" % [grab.linkage.said(), grab.linkage.links.size(),
		grab.moving.size()])
	var targets: Array = []
	for n: int in range(1, 16):
		targets.append(6.0 * n)
	for n: int in range(14, -16, -1):
		targets.append(6.0 * n)
	var hold: Vector3 = grab._hold
	var worst_teeth: float = 0.0
	var worst_far: float = 0.0
	var worst_near: float = 0.0
	var checked: int = 0
	var followed: int = 0
	var frame_worst: float = 0.0
	var mid_shot: bool = false
	var table := PackedStringArray()
	var keys: Dictionary = {"rack": mesh.rack, "gear": mesh.gear,
		"near": int((bodies.members[near_arm] as PackedInt64Array)[0]),
		"far": int((bodies.members[far_arm] as PackedInt64Array)[0])}
	var form := {"phi": 0.0, "far": far_pin.point}
	var turned_most: float = 0.0
	var worst_ratio: float = 0.0
	for target: float in targets:
		var turned: Vector3 = _about(grab.pivot, grab.axis, target) * hold
		var began: int = Time.get_ticks_usec()
		await _move(_camera.unproject_position(turned), MOUSE_BUTTON_MASK_LEFT)
		frame_worst = maxf(frame_worst, float(Time.get_ticks_usec() - began) / 1000.0)
		if not grab.stopped:
			followed += 1
		turned_most = maxf(turned_most, absf(grab.angle))
		var moved := func(which: String) -> Transform3D:
			var key: int = keys[which]
			return (grab.placed.get(key, grab.rest.get(key, _world.get_brick(key).transform)) as Transform3D) \
				* (grab.rest.get(key, _world.get_brick(key).transform) as Transform3D).affine_inverse()
		var w_rack: Transform3D = moved.call("rack")
		var w_gear: Transform3D = moved.call("gear")
		# The teeth: the pinion's turn against the rack, and where its centre
		# now is along the rack's teeth, as the rack sees it.
		var against: Transform3D = w_rack.affine_inverse() * w_gear
		var psi: float = _turn_about(against.basis, mesh.axis)
		if not is_nan(ratio):
			# The column's own turn, as drawn, against the pinion's: the gears'
			# teeth say how many times one goes round for the other.
			var w_column: Transform3D = (grab.placed.get(column_gear, grab.rest.get(column_gear))
				as Transform3D) * (grab.rest.get(column_gear) as Transform3D).affine_inverse()
			var column_turn: float = _turn_about(w_column.basis, grab.axis)
			worst_ratio = maxf(worst_ratio, absf(absf(psi) - ratio * absf(column_turn)))
		var along: float = mesh.line.dot(w_rack.affine_inverse() * (w_gear * mesh.centre) - mesh.centre)
		var by_teeth: float = -Racks.pitch() * float(mesh.teeth) * psi / 360.0 \
			* signf(mesh.rate)
		worst_teeth = maxf(worst_teeth, absf(along - by_teeth))
		# The arms by hand: the near arm's turn as drawn, the far arm's from
		# two circles, and the near arm's from the rack's place along its teeth.
		var phi_near: float = _turn_about(moved.call("near").basis, near_king.axis.normalized())
		var phi_far: float = _turn_about(moved.call("far").basis, far_king.axis.normalized())
		var hand: Dictionary = _steer_by_hand(near_king, far_king, near_pin, far_pin, mesh, by_teeth, form)
		if not hand.is_empty():
			checked += 1
			worst_near = maxf(worst_near, absf(wrapf(phi_near - float(hand["near"]), -180.0, 180.0)))
			worst_far = maxf(worst_far, absf(wrapf(phi_far - float(hand["far"]), -180.0, 180.0)))
			if absf(fmod(target, 30.0)) < 0.01 and not grab.stopped:
				table.append("      steering %+6.1f°: pinion %+6.1f° in the rack, %+.3f teeth, rack %+6.2f LDU (teeth %+6.2f); arms %+6.2f° and %+6.2f° (by hand %+6.2f°, %+6.2f°)"
					% [grab.angle, psi, psi / 360.0 * mesh.teeth, along, by_teeth, phi_near, phi_far,
					float(hand["near"]), float(hand["far"])])
		if not mid_shot and _windowed and absf(grab.angle) > 40.0:
			mid_shot = true
			await _clean_shot(name.get_slice(":", 0) + " " + path.get_file().get_basename(), "2_mid")
	for row: String in table:
		print(row)
	_check("%s: the steering follows the pointer in %d frames, %s, as far as %.1f°" % [name, followed,
		grab.mode, turned_most], followed >= 6 and grab.mode == "turn" and turned_most >= 30.0)
	if not is_nan(ratio):
		_check("%s: the pinion turns %.3f of the column's turn, by the gears' teeth, to %.3f°" % [name, ratio,
			worst_ratio], worst_ratio < 0.1)
	_check("%s: in %d poses the rack has gone a tooth, 8 LDU, for each tooth of the pinion's turn, to %.3f LDU"
		% [name, checked, worst_teeth], checked >= 6 and worst_teeth < 0.1)
	_check("%s: the near arm turns as the rack's place along its teeth says, by hand, to %.3f°" % [name,
		worst_near], checked >= 6 and worst_near < 0.1)
	_check("%s: the far arm stands where the track rod's pins put it, by hand, to %.3f°" % [name, worst_far],
		checked >= 6 and worst_far < 0.1)
	print("    drag frames: worst %.1f ms whole (following %.2f ms worst: %s), %d solves" % [frame_worst,
		_grab.worst_follow_ms, _grab.worst_follow_said, grab.linkage.solves])
	_timings[name + " " + path.get_file()] = {"frames": _grab.frames, "worst_ms": snappedf(_grab.worst_ms, 0.01),
		"mean_ms": snappedf(_grab.mean_ms, 0.01), "worst_follow_ms": snappedf(_grab.worst_follow_ms, 0.01),
		"moving": grab.moving.size(), "parts": _world.brick_count()}
	await _button(_last_screen, false)
	await _frames(3)
	await _settled()
	print("    said: %s" % _grab.last_words)
	_check("%s: let go, it is one step to undo" % name, _builder.history_depth() == depth + 1)
	if _windowed:
		await _clean_shot(name.get_slice(":", 0) + " " + path.get_file().get_basename(), "3_after")
	_builder.undo()
	await _frames(3)
	_check("%s: one undo puts every part back exactly (%s)" % [name, _differs(before)],
		_differs(before) == "none differs")
	_world.set_cut(false)
	_builder.lattice.cut = Plane()


## A picture of the pose with the drag's balance mark (the support and the
## centre of mass on the floor) hidden for it: the links read.
func _clean_shot(name: String, when: String) -> void:
	var mark: Node3D = _grab.get("_mark")
	var was: bool = mark != null and mark.visible
	if mark != null:
		mark.visible = false
	await _shot(name, when)
	if mark != null:
		mark.visible = was


## A steering's arms by hand, in the plane square to its kingpins, for the
## rack [param s] LDU along its teeth against the pinion: the near arm turned
## by phi carries the track rod's near pin round its kingpin; the far pin is
## where the circle about the far kingpin meets the circle about the near
## pin at the track rod's length; the track rod's turn follows from its two
## pins, and with it where the pinion's centre is along the rack. phi is
## found by bisection where that is [param s]. {near, far} degrees, or {}.
func _steer_by_hand(near_king: Bodies.Link, far_king: Bodies.Link, near_pin: Bodies.Link,
		far_pin: Bodies.Link, mesh: Racks.Pinion, s: float, form: Dictionary) -> Dictionary:
	var k: Vector3 = near_king.axis.normalized()
	var flat := func(v: Vector3) -> Vector3:
		return v - k * v.dot(k)
	var a_n: Vector3 = near_king.point
	var a_f: Vector3 = far_king.point
	var p_n0: Vector3 = near_pin.point
	var p_f0: Vector3 = far_pin.point
	var r_f: float = (flat.call(p_f0 - a_f) as Vector3).length()
	var rod: float = (flat.call(p_f0 - p_n0) as Vector3).length()
	# Where the rack stands along its teeth with the near arm at phi:
	# [s, far arm's turn, the far pin], or [] where the circles do not meet.
	var at := func(phi: float) -> Array:
		var p_n: Vector3 = _about(a_n, k, phi) * p_n0
		var centre: Vector3 = a_f + k * k.dot(p_n - a_f)
		var d_vec: Vector3 = flat.call(p_n - a_f)
		var d: float = d_vec.length()
		if d < 0.001 or d > r_f + rod or d < absf(r_f - rod):
			return []
		var x: float = (r_f * r_f - rod * rod + d * d) / (2.0 * d)
		var y: float = sqrt(maxf(r_f * r_f - x * x, 0.0))
		var ex: Vector3 = d_vec / d
		var ey: Vector3 = k.cross(ex)
		var one: Vector3 = centre + ex * x + ey * y
		var two: Vector3 = centre + ex * x - ey * y
		var prev: Vector3 = form["far"]
		var p_f: Vector3 = one if one.distance_to(prev) < two.distance_to(prev) else two
		var from: Vector3 = flat.call(p_f0 - p_n0)
		var to: Vector3 = flat.call(p_f - p_n)
		var rho: float = atan2(k.dot(from.cross(to)), from.dot(to))
		# The track rod placed: p_n0 to p_n, turned rho about k.
		var rod_at: Transform3D = Transform3D(Basis.IDENTITY, p_n) * Transform3D(Basis(k, rho), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -p_n0)
		var seen: Vector3 = rod_at.affine_inverse() * mesh.centre
		var far_from: Vector3 = flat.call(p_f0 - a_f)
		var far_to: Vector3 = flat.call(p_f - a_f)
		return [mesh.line.dot(seen - mesh.centre), rad_to_deg(atan2(k.dot(far_from.cross(far_to)),
			far_from.dot(far_to))), p_f]
	# s as the near arm turns is monotonic near where it stands: bisect
	# between the last answer less and more 40°.
	var lo: float = float(form["phi"]) - 40.0
	var hi: float = float(form["phi"]) + 40.0
	var f_lo: Array = at.call(lo)
	var f_hi: Array = at.call(hi)
	if f_lo.is_empty() or f_hi.is_empty() or signf(float(f_lo[0]) - s) == signf(float(f_hi[0]) - s):
		return {}
	for _round: int in 60:
		var mid: float = (lo + hi) * 0.5
		var f_mid: Array = at.call(mid)
		if f_mid.is_empty():
			return {}
		if signf(float(f_mid[0]) - s) == signf(float(f_lo[0]) - s):
			lo = mid
			f_lo = f_mid
		else:
			hi = mid
	var phi: float = (lo + hi) * 0.5
	var found: Array = at.call(phi)
	if found.is_empty():
		return {}
	form["phi"] = phi
	form["far"] = found[2]
	return {"near": phi, "far": float(found[1])}


# -- a scissor lift ----------------------------------------------------------------------

## A scissor lift of two stages, made here: four Technic beams 9 (40490) crossed
## and pinned at their middles and ends (pins with friction, 2780), one foot
## pinned to a beam 15 on the floor, the other on a cross block (6536)
## that slides along an axle 8 (3707) held at its ends by two more cross
## blocks pinned to a second beam 15; the two beams 15 held apart by three
## beams 5 between them, each pinned to the next by two pins. Its links
## stand at 45° to the floor: each stage is 160 LDU across its pins (beam
## 9's end holes) and 113.1 high.
const SCISSOR_LINK := 160.0
const SCISSOR_ANGLE := 45.0


## The made lift as an LDraw file: y down, the lift in the x-y plane, its
## fixed foot at the origin. Positions worked out from the link and angle.
static func _made_scissor() -> String:
	var c: float = cos(deg_to_rad(SCISSOR_ANGLE))
	var s: float = sin(deg_to_rad(SCISSOR_ANGLE))
	var across: float = SCISSOR_LINK * c
	var high: float = SCISSOR_LINK * s
	var lines := PackedStringArray(["0 A scissor lift, made by grab_probe", "0 Name: made_scissor.ldr", ""])
	var put := func(colour: int, at: Vector3, rows: Array, part: String) -> void:
		lines.append("1 %d %s %s %s %s %s.dat" % [colour, _num(at.x), _num(at.y), _num(at.z),
			" ".join(rows.map(func(v: float) -> String: return _num(v))), part])
	# A beam along d in the x-y plane, its holes along z.
	var beam := func(colour: int, middle: Vector3, d: Vector2, part: String) -> void:
		put.call(colour, middle, [-d.y, 0.0, d.x, d.x, 0.0, d.y, 0.0, 1.0, 0.0], part)
	var up_right := Vector2(c, -s)
	var up_left := Vector2(-c, -s)
	beam.call(4, Vector3(across / 2.0, -high / 2.0, 0.0), up_right, "40490")
	beam.call(14, Vector3(across / 2.0, -high / 2.0, 20.0), up_left, "40490")
	beam.call(4, Vector3(across / 2.0, -high * 1.5, 0.0), up_right, "40490")
	beam.call(14, Vector3(across / 2.0, -high * 1.5, 20.0), up_left, "40490")
	# Pins along z.
	var along_z: Array = [0.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0]
	for at: Vector3 in [Vector3(across / 2.0, -high / 2.0, 10.0), Vector3(across / 2.0, -high * 1.5, 10.0),
			Vector3(across, -high, 10.0), Vector3(0.0, -high, 10.0), Vector3(0.0, 0.0, -10.0),
			Vector3(0.0, 0.0, 50.0), Vector3(140.0, 0.0, 50.0)]:
		put.call(0, at, along_z, "2780")
	# The floor: two beams 15 along x, three beams 5 between them at the far
	# end, each layer pinned to the next twice.
	var along_x_holes_z: Array = [0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0]
	put.call(71, Vector3(140.0, 0.0, -20.0), along_x_holes_z, "32278")
	put.call(71, Vector3(140.0, 0.0, 60.0), along_x_holes_z, "32278")
	for z: float in [0.0, 20.0, 40.0]:
		put.call(71, Vector3(240.0, 0.0, z), along_x_holes_z, "32316")
	for z: float in [-10.0, 10.0, 30.0, 50.0]:
		for x: float in [220.0, 260.0]:
			put.call(0, Vector3(x, 0.0, z), along_z, "2780")
	# The rail, an axle 8 along x held by two cross blocks at its ends.
	put.call(72, Vector3(80.0, -20.0, 40.0), [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0], "3707")
	put.call(1, Vector3(0.0, -20.0, 40.0), [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0], "6536")
	put.call(1, Vector3(140.0, -20.0, 40.0), [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0], "6536")
	# The sliding foot: a cross block on the rail by its pin hole, an axle 2
	# in its axle hole through the beam's end.
	put.call(2, Vector3(across, 0.0, 40.0), [0.0, 0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0, 0.0], "6536")
	put.call(72, Vector3(across, 0.0, 30.0), along_z, "3704")
	return "\n".join(lines) + "\n"


static func _num(v: float) -> String:
	var out: String = "%.4f" % v
	while out.contains(".") and (out.ends_with("0") or out.ends_with(".")):
		out = out.substr(0, out.length() - 1)
	return "0" if out == "-0" else out


## Raise the made lift by sliding its foot along the rail with the pointer:
## every frame the top stands 2·L·sin θ above the floor pin, θ where the
## foot's distance from the fixed foot, L·cos θ, puts it (L = 160); by hand,
## sqrt(L² − x²) a stage.
func _scissor_case() -> void:
	var name: String = "scissor lift"
	print("\n%s: a made one, two stages of beams 9 at %.0f°" % [name, SCISSOR_ANGLE])
	var path: String = OUT.path_join("made_scissor.ldr")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(_made_scissor())
	file.close()
	if not await _open(path):
		_check("%s: the made lift opens" % name, false)
		return
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	print("    %s" % bodies.summary())
	var across: float = SCISSOR_LINK * cos(deg_to_rad(SCISSOR_ANGLE))
	var high: float = SCISSOR_LINK * sin(deg_to_rad(SCISSOR_ANGLE))
	# The foot that slides (the cross block at the beam's end), and the top
	# link's top pin hole, in the app's axes (LDraw's y and z turned over).
	# Opened, the model may stand elsewhere than the file put it: found from
	# its one axle 8, at (80, 20, -40) in the file.
	var shift := Vector3.ZERO
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3707":
			shift = brick.transform.origin - Vector3(80.0, 20.0, -40.0)
	var foot: int = 0
	var top_link: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "6536" and brick.transform.origin.distance_to(shift + Vector3(across, 0.0, -40.0)) < 1.0:
			foot = brick.id
		if brick.part_id == "40490" and brick.transform.origin.distance_to(
				shift + Vector3(across / 2.0, high * 1.5, 0.0)) < 1.0:
			top_link = brick.id
	if foot == 0 or top_link == 0:
		_check("%s: the made lift has its sliding foot and its top link" % name, false)
		return
	var foot_body: int = int(bodies.body_of[foot])
	var joint: Bodies.Link = bodies.parent_link.get(foot_body)
	print("    the foot: %s %s, slides %s" % [bodies.named([foot_body]), joint.words() if joint != null else "?",
		joint.slide if joint != null else Vector2.ZERO])
	var top_at: Vector3 = shift + Vector3(across, high * 2.0, 0.0)
	_camera.look_from(Vector3(0.35, 0.3, 1.0).normalized())
	_frame_on(PackedInt64Array())
	await _frames(20)
	var before: Dictionary = _snapshot()
	var depth: int = _builder.history_depth()
	var press: Dictionary = _press_point(bodies.members[foot_body], bodies)
	if press.is_empty():
		_check("%s: the sliding foot is under the pointer" % name, false)
		return
	if _windowed:
		await _shot("scissor_lift", "1_before")
	var screen: Vector2 = press["screen"]
	var rail := Vector3.RIGHT
	var first: Vector2 = (_camera.unproject_position(_world.get_brick(foot).transform.origin - rail * 3.0)
		- _camera.unproject_position(_world.get_brick(foot).transform.origin)).normalized() * 7.0
	await _move(screen, 0)
	await _button(screen, true)
	await _move(screen + first, MOUSE_BUTTON_MASK_LEFT)
	var grab: Grab = _grab.grab
	_check("%s: a drag on the foot along its rail slides it, the lift's loops with it (%s)" % [name,
		_grab.last_words if grab == null else grab.said], grab != null and grab.state == "moves"
		and grab.linkage != null and grab.mode == "slide")
	if grab == null or grab.linkage == null or grab.mode != "slide":
		await _button(screen, false)
		return
	print("    %s; %d joints, moving %d parts" % [grab.linkage.said(), grab.linkage.links.size(), grab.moving.size()])
	var hold: Vector3 = grab._hold
	var way: float = signf(grab.axis.dot(rail))
	var targets: Array = []
	for n: int in range(1, 21):
		targets.append(-4.0 * n)
	for n: int in range(19, -2, -1):
		targets.append(-4.0 * n)
	var worst: float = 0.0
	var followed: int = 0
	var worst_follow: float = 0.0
	var checked: int = 0
	var frame_worst: float = 0.0
	var mid_shot: bool = false
	var table := PackedStringArray()
	for target: float in targets:
		var at_screen: Vector2 = _camera.unproject_position(hold + rail * target)
		var began: int = Time.get_ticks_usec()
		await _move(at_screen, MOUSE_BUTTON_MASK_LEFT)
		frame_worst = maxf(frame_worst, float(Time.get_ticks_usec() - began) / 1000.0)
		# Drawn: the foot's place along the rail and the top's height.
		if not grab.stopped:
			followed += 1
			worst_follow = maxf(worst_follow, absf(grab.shift * grab.axis.dot(rail) - target))
		var foot_now: Transform3D = grab.placed.get(foot, _world.get_brick(foot).transform)
		var x: float = foot_now.origin.x - shift.x
		var top_now: Transform3D = (grab.placed.get(top_link, _world.get_brick(top_link).transform) as Transform3D) \
			* _world.get_brick(top_link).transform.affine_inverse()
		var h: float = (top_now * top_at).y - shift.y
		if absf(x) >= SCISSOR_LINK:
			continue
		var by_hand: float = 2.0 * sqrt(SCISSOR_LINK * SCISSOR_LINK - x * x)
		worst = maxf(worst, absf(h - by_hand))
		checked += 1
		if absf(fmod(target, 20.0)) < 0.01:
			table.append("      foot %6.2f LDU from the fixed one (%+6.2f): links at %5.2f°, top %7.2f LDU high; by hand 2·sqrt(160² − %.2f²) = %7.2f"
				% [x, grab.shift, rad_to_deg(acos(x / SCISSOR_LINK)), h, x, by_hand])
		if not mid_shot and _windowed and h > high * 2.0 + 60.0:
			mid_shot = true
			await _clean_shot("scissor_lift", "2_raised")
	for row: String in table:
		print(row)
	_check("%s: the foot follows the pointer along its rail in %d frames, to %.2f LDU" % [name, followed,
		worst_follow], followed >= 20 and worst_follow < 1.0)
	_check("%s: in %d poses the top stands where the foot's place puts it, 2·sqrt(L² − x²), to %.3f LDU"
		% [name, checked, worst], checked >= 20 and worst < 0.1)
	print("    drag frames: worst %.1f ms whole (following %.2f ms worst: %s), %d solves" % [frame_worst,
		_grab.worst_follow_ms, _grab.worst_follow_said, grab.linkage.solves])
	_timings[name] = {"frames": _grab.frames, "worst_ms": snappedf(_grab.worst_ms, 0.01),
		"mean_ms": snappedf(_grab.mean_ms, 0.01), "worst_follow_ms": snappedf(_grab.worst_follow_ms, 0.01),
		"moving": grab.moving.size(), "parts": _world.brick_count()}
	await _button(_last_screen, false)
	await _frames(3)
	await _settled()
	print("    said: %s" % _grab.last_words)
	_check("%s: let go, it is one step to undo" % name, _builder.history_depth() == depth + 1)
	if _windowed:
		await _clean_shot("scissor_lift", "3_after")
	_builder.undo()
	await _frames(3)
	_check("%s: one undo puts every part back exactly (%s)" % [name, _differs(before)],
		_differs(before) == "none differs")


# -- a model that tips -------------------------------------------------------------------

## Technic sets tried for a part hung on a driven gear's body.
const FOLLOWING: Array = ["res://vendor/omr/files/8418-1_B-Model.mpd"]
## Sets with a free joint inside a section that swings.
const SETTLING: Array = ["res://vendor/omr/files/8218-1.mpd", "res://vendor/omr/files/42045-1.mpd"]
## Sets tried, on no floor, for a section that turned out tips the model.
const TIPPING: Array = ["figure", "res://vendor/omr/files/4096-1_Crane.mpd", "res://vendor/omr/files/6630-1.mpd",
	"res://vendor/omr/files/30181-1.mpd", "res://vendor/omr/files/4903-1.mpd"]


## A model that tips falls: on no floor, a section turned out past the
## model's edge by move_part, as a session moves it; the reply says it fell,
## and then the model rests: its centre of mass over what it now stands on,
## its lowest point on the floor it stood on, one undo puts it all back.
## Then on a baseplate's studs it does not fall, and says why.
func _topple_case(paths: Array = TIPPING) -> void:
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	for path: String in paths:
		print("\ntipping: %s on no floor" % path.get_file())
		if path == "figure":
			# Two alike minifigures: a leg swung out from under one.
			await _two_figures()
		elif not await _open(path):
			continue
		await tools.run("set_floor", {"kind": "none"})
		await _frames(5)
		_builder.forget_history()
		_grab._ready_now()
		var bodies: Bodies = _grab._bodies
		var tried: Array = []
		for link: Bodies.Link in bodies.links:
			var child: int = link.b if bodies.parent_link.get(link.b) == link else link.a
			if bodies.parent_link.get(child) != link or link.axis == Vector3.ZERO:
				continue
			tried.append([bodies.parts_of(bodies.beyond(child)).size(), child])
		tried.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
		var floor_y: float = _lowest()
		for entry: Array in tried.slice(0, 6):
			var key: int = int((bodies.members[int(entry[1])] as PackedInt64Array)[0])
			for degrees: float in [90.0, -90.0, 150.0, -150.0]:
				var before: Dictionary = _snapshot()
				var depth: int = _builder.history_depth()
				var said: String = str(await tools.run("move_part", {"part": "#%d" % key, "degrees": degrees}))
				await _frames(3)
				if not said.contains("Then it tipped"):
					if "--debug" in OS.get_cmdline_user_args():
						print("    (#%d %s°: %s)" % [key, degrees, said.replace("\n", " | ").substr(0, 300)])
					while _builder.history_depth() > depth:
						_builder.undo()
					await _frames(2)
					continue
				print("    move_part #%d %s° said: %s" % [key, Balance.tidy(degrees), said.replace("\n", " | ")])
				_check("tipping: turned out past its edge, %s falls over, and says so" % path.get_file(),
					said.contains("tipped over to the") and (said.contains("lies") or said.contains("rest")))
				var fresh := Balance.new()
				fresh.library = _library
				fresh.lattice = _builder.lattice
				fresh.floor_ids = _store.scenery
				var now: Balance.Report = fresh.measure(_world.bricks())
				_check("tipping: where it lies, it stands: its centre of mass %s studs inside its new support"
					% Balance.studs(now.margin), now.margin >= 0.0)
				var lowest: float = _lowest()
				_check("tipping: it lies on the floor it stood on (lowest point %.1f LDU, the floor %.1f)"
					% [lowest, floor_y], absf(lowest - floor_y) <= 2.0)
				_check("tipping: the turn and the fall are one step to undo (%s)" % (_builder.history_words(1)[0]
					if _builder.history_depth() > depth else "none"), _builder.history_depth() == depth + 1)
				if _windowed:
					_frame_on(PackedInt64Array())
					await _frames(10)
					await _shot("tipping", "3_fallen")
				_builder.undo()
				await _frames(3)
				_check("tipping: one undo stands it up again exactly (%s)" % _differs(before),
					_differs(before) == "none differs")
				# On a baseplate's studs the same turn does not fall, and says why.
				await tools.run("set_floor", {"kind": "baseplate", "across": 32})
				await _frames(5)
				_builder.forget_history()
				_grab._ready_now()
				if not _grab._bodies._standing.is_empty():
					var held: String = str(await tools.run("move_part", {"part": "#%d" % key,
						"degrees": degrees}))
					print("    on a baseplate: %s" % held.replace("\n", " | "))
					_check("tipping: on the baseplate's studs it does not fall, and says why",
						not held.contains("Then it tipped") and held.contains("baseplate's studs"))
					_builder.undo()
					await _frames(3)
				else:
					print("    (nothing of it stands on the baseplate's studs: not asked)")
				return
		print("    (no section of it turned out tips it)")
	_check("tipping: some set tips when a section is turned out", false)


## Every free joint inside what moves swings down on release, not only the
## one turned: a section with a free joint inside it (a pin without
## friction, an axle in a round hole, its load off its line) turned by
## move_part; the reply names what swung, and each such joint's load then
## hangs under its line or rests on the model.
func _settle_case(paths: Array) -> void:
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	for path: String in paths:
		if not await _open(path):
			continue
		_grab._ready_now()
		var bodies: Bodies = _grab._bodies
		for link: Bodies.Link in bodies.links:
			var child: int = link.b if bodies.parent_link.get(link.b) == link else link.a
			if bodies.parent_link.get(child) != link or link.axis == Vector3.ZERO \
					or bodies.anchors.has(child):
				continue
			# A free joint inside it, across a line that is not upright.
			var inner: Array = []
			for one: int in bodies.beyond(child):
				var joined: Bodies.Link = bodies.parent_link.get(one)
				if one != child and joined != null and not joined.holds and joined.axis != Vector3.ZERO \
						and absf(joined.axis.normalized().y) < 0.9:
					inner.append(one)
			if inner.is_empty():
				continue
			var key: int = int((bodies.members[child] as PackedInt64Array)[0])
			var before: Dictionary = _snapshot()
			var depth: int = _builder.history_depth()
			var said: String = str(await tools.run("move_part", {"part": "#%d" % key, "degrees": 30}))
			await _frames(2)
			if not said.contains("swung down too"):
				while _builder.history_depth() > depth:
					_builder.undo()
				await _frames(2)
				continue
			print("\nsettling inside: %s, #%d %s" % [path.get_file(), key, _world.get_brick(key).part_id])
			print("    said: %s" % said.replace("\n", " | "))
			_check("settling: a free joint inside what moved swung down too, and the reply says which",
				said.contains("inside it swung down too"))
			_check("settling: one step to undo (%s)" % (_builder.history_words(1)[0]
				if _builder.history_depth() > depth else "none"), _builder.history_depth() == depth + 1)
			_builder.undo()
			await _frames(2)
			_check("settling: one undo puts it back exactly (%s)" % _differs(before),
				_differs(before) == "none differs")
			return
	print("\n(settling inside: none of the sets has a free joint inside a section that swings: %d tried)"
		% paths.size())


## A made model that tips when posed: a tall arm of 1x2 bricks on a hinge
## (3937 and 3938, placed as LDraw pairs them) on a tower of four 2x2 bricks,
## nothing under the arm's far end, on no floor. LDraw's own units, y down.
const MADE_CRANE := """0 A tall arm on a hinge on a 2x2 tower
0 Name: made_crane.ldr
0 !BRICKWORKS FLOOR NONE
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat
1 4 0 -72 0 1 0 0 0 1 0 0 0 1 3003.dat
1 4 0 -96 0 1 0 0 0 1 0 0 0 1 3003.dat
1 71 0 -120 10 1 0 0 0 1 0 0 0 1 3937.dat
1 14 0 -120 10 1 0 0 0 1 0 0 0 1 3938.dat
1 1 0 -144 10 1 0 0 0 1 0 0 0 1 3004.dat
1 1 0 -168 10 1 0 0 0 1 0 0 0 1 3004.dat
1 1 0 -192 10 1 0 0 0 1 0 0 0 1 3004.dat
1 1 0 -216 10 1 0 0 0 1 0 0 0 1 3004.dat
1 1 0 -240 10 1 0 0 0 1 0 0 0 1 3004.dat
1 14 0 -248 10 1 0 0 0 1 0 0 0 1 3023.dat
"""


## The made crane posed past its edge by a drag, on no floor: let go, it
## falls about its support's edge until the arm's far end reaches the floor,
## at the angle a hand works out from the posed corners (atan2 of a corner's
## height over its reach past the edge, the least of them), with that corner
## on the floor; one undo step, said in words. Then on a baseplate's studs
## the same drag leaves it standing, and it says why.
func _made_fall() -> void:
	print("\nfalling: a made crane, a tall arm on a 2x2 tower, on no floor")
	var path: String = OUT.path_join("made_crane.ldr")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(MADE_CRANE)
	file.close()
	if not await _open(path):
		_check("falling: the made crane opens", false)
		return
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	print("    %s" % bodies.summary())
	var hinge: Bodies.Link = null
	for link: Bodies.Link in bodies.links:
		if link.kind == "hinge":
			hinge = link
	if hinge == null:
		_check("falling: the made crane's arm is on its hinge", false)
		return
	var arm: int = hinge.b if bodies.parent_link.get(hinge.b) == hinge else hinge.a
	print("    the arm: %s on its hinge at %s, the anchor %s" % [bodies.named([arm]), hinge.point,
		bodies.named(bodies.anchors.keys())])
	var floor_y: float = _lowest()
	var before: Dictionary = _snapshot()
	var depth: int = _builder.history_depth()
	_camera.look_from(Vector3(1.0, 0.45, 0.25).normalized())
	_frame_on(PackedInt64Array())
	await _frames(15)
	if _windowed:
		await _shot("falling", "1_before")
	var press: Dictionary = _press_point(bodies.members[arm], bodies)
	if press.is_empty():
		_check("falling: the arm is under the pointer", false)
		return
	var screen: Vector2 = press["screen"]
	await _move(screen, 0)
	await _button(screen, true)
	await _move(screen + Vector2(0, 7), MOUSE_BUTTON_MASK_LEFT)
	var grab: Grab = _grab.grab
	_check("falling: a drag on the arm turns it on its hinge (%s)" % (grab.said if grab != null
		else _grab.last_words), grab != null and grab.state == "moves")
	if grab == null:
		await _button(screen, false)
		return
	# Outward: the way that carries the arm's weight past the tower's edge.
	var way: float = 1.0
	var out_plus: Vector3 = _centre_of(grab.transforms_at(60.0))
	var out_minus: Vector3 = _centre_of(grab.transforms_at(-60.0))
	var base_centre: Vector3 = _centre_of({})
	if Vector2(out_minus.x - base_centre.x, out_minus.z - base_centre.z).length() \
			> Vector2(out_plus.x - base_centre.x, out_plus.z - base_centre.z).length():
		way = -1.0
	var hold: Vector3 = grab._hold
	for n: int in range(1, 19):
		var turned: Vector3 = _about(grab.pivot, grab.axis, way * 5.0 * n) * hold
		await _move(_camera.unproject_position(turned), MOUSE_BUTTON_MASK_LEFT)
		if _windowed and n == 12:
			await _shot("falling", "2_mid_drag")
	# Held there a moment: it is weighed every 50 ms.
	await create_timer(0.08).timeout
	await _move(_last_screen + Vector2(0.5, 0), MOUSE_BUTTON_MASK_LEFT)
	var posed: float = grab.angle
	print("    posed to %.1f° (asked %.0f°)%s" % [posed, way * 90.0, " — stopped by the model" if grab.stopped else ""])
	_check("falling: dragged out to %.0f°, the model leans over its edge (%s)" % [posed, _grab._said],
		_grab.is_leaning())
	# By hand, from the pose: every part's box corners where the drag put
	# them; the edge the centre of mass is past; the least atan2(h, u).
	var placed: Dictionary = grab.placed.duplicate()
	var hand: Dictionary = _fall_by_hand(placed)
	print("    by hand: past the %s edge by %.1f LDU; the first corner down is %s, %.1f LDU out and %.1f up: %.2f°"
		% [hand["edge"], hand["past"], hand["corner"], hand["u"], hand["h"], hand["angle"]])
	await _button(_last_screen, false)
	# Half a second of falling, a picture half way.
	var released: int = Time.get_ticks_msec()
	var falling_shot: bool = false
	while _grab.is_falling() and Time.get_ticks_msec() - released < 3000:
		if _windowed and not falling_shot and Time.get_ticks_msec() - released > 250:
			falling_shot = true
			await _shot("falling", "3_falling")
		await process_frame
	await _frames(3)
	print("    said: %s" % _grab.last_words)
	_check("falling: let go past its edge it falls, and says how it lies (%s)" % _grab.last_words,
		_grab.last_words.contains("tipped over to the"))
	# The angle it fell: a base brick's up turned.
	var base_key: int = int((bodies.members[int(bodies.anchors.keys()[0])] as PackedInt64Array)[0])
	var up_before: Vector3 = (placed.get(base_key, before[base_key]) as Transform3D).basis.y.normalized()
	var up_after: Vector3 = _world.get_brick(base_key).transform.basis.y.normalized()
	var fell: float = rad_to_deg(up_before.angle_to(up_after))
	_check("falling: it turned %.2f° about its edge, as the hand works out (%.2f°)" % [fell, hand["angle"]],
		absf(fell - float(hand["angle"])) < 1.5)
	# The contact: the corner found by hand is on the floor, and so is the edge.
	var lowest: float = _lowest()
	var corner_now: Vector3 = _corner_now(int(hand["key"]), int(hand["index"]))
	_check("falling: that point is on the floor (%.2f LDU above it) and nothing is under it (lowest %.2f)"
		% [corner_now.y - floor_y, lowest - floor_y], absf(corner_now.y - floor_y) <= 2.0
		and lowest >= floor_y - 2.0)
	var fresh := Balance.new()
	fresh.library = _library
	fresh.lattice = _builder.lattice
	fresh.floor_ids = _store.scenery
	var now: Balance.Report = fresh.measure(_world.bricks())
	_check("falling: where it lies, it rests: its centre of mass %s studs inside what it lies on"
		% Balance.studs(now.margin), now.margin >= -0.1)
	_check("falling: the pose and the fall are one step to undo (%s)" % (_builder.history_words(1)[0]
		if _builder.history_depth() > depth else "none"), _builder.history_depth() == depth + 1)
	if _windowed:
		_frame_on(PackedInt64Array())
		await _frames(10)
		await _shot("falling", "4_fallen")
	_builder.undo()
	await _frames(3)
	_check("falling: one undo stands it up again exactly (%s)" % _differs(before),
		_differs(before) == "none differs")
	# On a baseplate's studs it stays standing, and says why.
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	await tools.run("set_floor", {"kind": "baseplate", "across": 16})
	await _frames(10)
	_builder.forget_history()
	_grab._ready_now()
	_check("falling: on a baseplate the tower stands on its studs (%d parts)" % _grab._bodies._standing.size(),
		not _grab._bodies._standing.is_empty())
	_frame_on(PackedInt64Array())
	await _frames(10)
	var on_plate: Dictionary = _snapshot()
	press = _press_point(_grab._bodies.members[int(_grab._bodies.body_of[int((bodies.members[arm] as PackedInt64Array)[0])])], _grab._bodies)
	if press.is_empty():
		_check("falling: the arm is under the pointer on the baseplate", false)
		return
	screen = press["screen"]
	await _move(screen, 0)
	await _button(screen, true)
	await _move(screen + Vector2(0, 7), MOUSE_BUTTON_MASK_LEFT)
	grab = _grab.grab
	if grab == null:
		_check("falling: on the baseplate a drag on the arm turns it", false)
		await _button(screen, false)
		return
	hold = grab._hold
	for n: int in range(1, 19):
		var turned: Vector3 = _about(grab.pivot, grab.axis, way * 5.0 * n) * hold
		await _move(_camera.unproject_position(turned), MOUSE_BUTTON_MASK_LEFT)
	await _button(_last_screen, false)
	await _frames(5)
	await _settled()
	print("    on a baseplate: %s" % _grab.last_words)
	var base_still: bool = (_world.get_brick(base_key).transform as Transform3D).is_equal_approx(on_plate[base_key])
	_check("falling: on the baseplate's studs it does not fall, and says why", base_still
		and not _grab.last_words.contains("tipped over") and _grab.last_words.contains("baseplate's studs"))
	if _windowed:
		await _shot("falling", "5_on_baseplate")
	_builder.undo()
	await _frames(3)


## A made train: an 8 tooth crank driving a 24 tooth gear on a Technic
## brick, and on the 24's axle a 1x2 brick with an axle hole carrying a hinge
## whose top holds a 1x6 plate: an arm hung on the driven axle by a joint the
## gear reading does not read. LDraw's units, y down.
const MADE_GEARS := """0 A crank turns an arm through two gears
0 Name: made_gears.ldr
0 !BRICKWORKS FLOOR NONE
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3010.dat
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3010.dat
1 4 0 -72 0 1 0 0 0 1 0 0 0 1 3010.dat
1 7 0 -96 0 1 0 0 0 1 0 0 0 1 3701.dat
1 0 -20 -86 0 0 0 -1 0 1 0 1 0 0 3705.dat
1 0 20 -86 0 0 0 -1 0 1 0 1 0 0 3705.dat
1 7 -20 -86 -20 1 0 0 0 1 0 0 0 1 3647.dat
1 7 20 -86 -20 1 0 0 0 1 0 0 0 1 3648b.dat
1 14 20 -96 20 1 0 0 0 1 0 0 0 1 32064a.dat
1 71 20 -120 20 1 0 0 0 1 0 0 0 1 3937.dat
1 14 20 -120 20 1 0 0 0 1 0 0 0 1 3938.dat
1 1 20 -128 20 1 0 0 0 1 0 0 0 1 3666.dat
"""


## An arm hung on a driven gear's axle goes round with the gear: the made
## train, then real Technic sets with gears until one has something hung on
## a driven body. The arm's turn about its axle is the crank's times the
## train's tooth ratio, as Simulate reads it.
func _follow_case(paths: Array) -> void:
	print("\nwhat hangs on a driven gear: a made train, 8 teeth driving 24")
	var path: String = OUT.path_join("made_gears.ldr")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(MADE_GEARS)
	file.close()
	if await _open(path):
		_grab._ready_now()
		print("    %s; the gear trains %s" % [_grab._bodies.summary(), "read" if _grab._mechanism != null
			else "NOT read"])
		var crank: int = 0
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id == "3647":
				crank = brick.id
		await _follow_check("made train", crank, true)
	for one: String in paths:
		if not await _open(one):
			continue
		_grab._ready_now()
		if _grab._mechanism == null:
			continue
		var bodies: Bodies = _grab._bodies
		for body: int in bodies.parent_link:
			var link: Bodies.Link = bodies.parent_link[body]
			if link.kind != "axle" and link.kind != "pin":
				continue
			var gear: int = 0
			for key: int in bodies.members[body]:
				if not Mechanism.spec_of(_world.get_brick(key).part_id).is_empty():
					gear = key
					break
			if gear == 0:
				continue
			var trial := Grab.new()
			trial.world = _world
			trial.builder = _builder
			trial.library = _library
			trial.bodies = bodies
			trial.shared_mechanism = _grab._mechanism
			if trial.begin(gear, _world.get_brick(gear).transform.origin) != "moves" or trial.followers.is_empty():
				continue
			print("\nwhat hangs on a driven gear: %s" % one.get_file())
			await _follow_check(one.get_file(), gear, false)
			return
	print("\n(what hangs on a driven gear: no real set of %d has a part hung on a driven body by a joint of its own)"
		% paths.size())


## Turn [param gear] 30° through Grab and check every follower: its turn
## about its carrier's axle is the crank's turn times the ratio Simulate
## gives the carrier's body.
func _follow_check(name: String, gear: int, made: bool) -> void:
	var grab := Grab.new()
	grab.world = _world
	grab.builder = _builder
	grab.library = _library
	grab.bodies = _grab._bodies
	grab.shared_mechanism = _grab._mechanism
	var state: String = grab.begin(gear, _world.get_brick(gear).transform.origin)
	print("    grabbed #%d %s: %s %s; %d driven parts, %d hung on them (%s)" % [gear,
		_world.get_brick(gear).part_id, state, grab.why, grab.coupled.size(), grab.followers.size(),
		" ".join(PackedStringArray(grab.followers.keys().map(func(k: int) -> String:
			return _world.get_brick(k).part_id)))])
	_check("%s: something hangs on the driven gear's body by a joint of its own (%d parts)" % [name,
		grab.followers.size()], not grab.followers.is_empty())
	if grab.followers.is_empty():
		return
	grab.turn_to(30.0)
	# The turn the train gives each carrier, from the gear reading the grab
	# drives (Mechanism: radians a radian of the crank, about each body's
	# line): the follower's own turn, as a rotation vector, must be it times
	# the crank's.
	var mechanism: Mechanism = grab.mechanism
	var crank: float = deg_to_rad(grab.angle) * grab._drive_sign
	var worst: float = 0.0
	var said := PackedStringArray()
	var ratio: float = 0.0
	for key: int in grab.followers:
		var carrier: int = grab.followers[key]
		var spin: Vector3 = mechanism.omega(mechanism.body_of(carrier))
		ratio = spin.length()
		var turned: Quaternion = Quaternion(((grab.placed[key] as Transform3D).basis
			* (grab.rest[key] as Transform3D).basis.inverse()).orthonormalized())
		var measured: Vector3 = turned.get_axis() * turned.get_angle() if turned.get_angle() > 1e-6 \
			else Vector3.ZERO
		var expected: Vector3 = spin * crank
		worst = maxf(worst, rad_to_deg((measured - expected).length()))
		if said.size() < 2:
			said.append("%s %.3f° for %.3f° (%s of the crank's)" % [_world.get_brick(key).part_id,
				rad_to_deg(measured.length()), rad_to_deg(expected.length()), Simulation.figure(ratio)])
	_check("%s: the crank turned %.0f°, what hangs on the driven axle turns by the tooth ratio: %s, to %.4f°"
		% [name, grab.angle, ", ".join(said), worst], not said.is_empty() and worst < 0.05)
	if made:
		_check("%s: the arm turns a third of the crank's turn (8 teeth to 24): %s" % [name,
			Simulation.figure(ratio)], absf(ratio - 1.0 / 3.0) < 1e-4)


## The centre of mass of the model with [param placed] where it says.
func _centre_of(placed: Dictionary) -> Vector3:
	var sum := Vector3.ZERO
	var weight: float = 0.0
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		if info == null:
			continue
		var g: float = Stability.grams(info)
		sum += ((placed.get(brick.id, brick.transform) as Transform3D) * info.bounds.get_center()) * g
		weight += g
	return sum / maxf(weight, 0.000001)


## How the model posed as [param placed] falls, worked by hand from its
## parts' drawn shapes, every vertex (not Topple's 2 LDU covers): the
## support is the points on the floor; the edge the centre of mass is past;
## each point u out past it and h above the floor comes down at atan2(h, u);
## the least.
func _fall_by_hand(placed: Dictionary) -> Dictionary:
	var corners: Array = []   ## [key, index, point]
	var low: float = INF
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		var at: Transform3D = placed.get(brick.id, brick.transform)
		var index: int = 0
		for surface: ArrayMesh in mesh.surfaces:
			for s: int in surface.get_surface_count():
				var points: PackedVector3Array = surface.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				for v: Vector3 in points:
					var p: Vector3 = at * v
					corners.append([brick.id, index, p])
					low = minf(low, p.y)
					index += 1
	var support := PackedVector2Array()
	for c: Array in corners:
		if (c[2] as Vector3).y <= low + 1.0:
			support.append(Vector2((c[2] as Vector3).x, (c[2] as Vector3).z))
	var hull: PackedVector2Array = Geometry2D.convex_hull(support)
	hull.resize(hull.size() - 1)
	var centre: Vector3 = _centre_of(placed)
	var standing: Dictionary = Balance.margin_in(hull, Vector2(centre.x, centre.z))
	var ends: PackedVector2Array = standing["ends"]
	var out2: Vector2 = standing["way"]
	var out := Vector3(out2.x, 0.0, out2.y)
	var a := Vector3(ends[0].x, low, ends[0].y)
	var best: Dictionary = {"angle": 180.0}
	for c: Array in corners:
		var q: Vector3 = (c[2] as Vector3) - a
		var u: float = q.dot(out)
		var h: float = q.y
		if h <= 1.0 and absf(u) <= 2.0:
			continue
		var angle: float = rad_to_deg(atan2(h, u))
		if angle > 0.01 and angle < float(best["angle"]):
			best = {"angle": angle, "u": u, "h": h, "key": c[0], "index": c[1],
				"corner": "a point of %s" % _world.get_brick(int(c[0])).part_id}
	best["edge"] = str(standing["edge"])
	best["past"] = -float(standing["margin"])
	return best


## Where vertex [param index] of [param key]'s drawn shape stands now.
func _corner_now(key: int, index: int) -> Vector3:
	var brick: BrickWorld.Brick = _world.get_brick(key)
	var at: int = 0
	for surface: ArrayMesh in _library.mesh_for(brick.part_id).surfaces:
		for s: int in surface.get_surface_count():
			var points: PackedVector3Array = surface.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			if index < at + points.size():
				return brick.transform * points[index - at]
			at += points.size()
	return brick.transform.origin


## The model's lowest point, LDU, by its parts' covers.
func _lowest() -> float:
	var low: float = INF
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh != null:
			low = minf(low, mesh.lowest_at(brick.transform))
	return low


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
	# A chain over MCP: the crane's end drawn to a point its joints reach,
	# found as the chain probe finds one: each joint a third of its range.
	_grab._ready_now()
	var read_bodies: Bodies = _grab._bodies
	var end_key: int = 0
	var longest: int = 0
	for body: int in read_bodies.members:
		var turning: int = 0
		for link: Bodies.Link in read_bodies.chain(body):
			if link.axis != Vector3.ZERO:
				turning += 1
		if turning > longest:
			longest = turning
			end_key = int((read_bodies.members[body] as PackedInt64Array)[0])
	var probe_chain := GrabChain.new()
	probe_chain.world = _world
	probe_chain.builder = _builder
	probe_chain.library = _library
	probe_chain.bodies = read_bodies
	var brick: BrickWorld.Brick = _world.get_brick(end_key)
	var middle: Vector3 = brick.transform * _library.parts[brick.part_id].bounds.get_center()
	if probe_chain.begin(end_key, middle) != "moves":
		_check("move_part to=: the crane has a chain to its end", false)
		return
	for n: int in probe_chain.joints.size():
		var span: Vector2 = probe_chain.ranges[n]
		probe_chain.angles[n] = span.y / 3.0 if span.y > -span.x else span.x / 3.0
	var goal: Vector3 = probe_chain.end_point()
	var depth: int = _builder.history_depth()
	var chained: String = str(await tools.run("move_part", {"part": "#%d" % end_key,
		"to": [goal.x / BrickLattice.STUD, goal.y / BrickLattice.STUD, goal.z / BrickLattice.STUD]}))
	print("    chain: %s" % chained.replace("\n", " | "))
	var now_middle: Vector3 = _world.get_brick(end_key).transform \
		* _library.parts[brick.part_id].bounds.get_center()
	_check("move_part to= draws the end along its chain to the point, %.2f LDU off, one step" % [
		now_middle.distance_to(goal)], chained.contains("joints back to") and now_middle.distance_to(goal) < 2.0
		and _builder.history_depth() == depth + 1)
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
	print(("    let go: checked and kept in %d ms, its worst frame %.1f ms (checking %.1f, cells %.1f); "
		+ "the keeping frame %.0f ms %s") % [Time.get_ticks_msec() - settling, _grab.worst_settle_ms,
		_grab.worst_verify_ms, _grab.worst_lay_ms, _grab.keep_ms, str(_grab.keep_took)])
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


## A screen point over one of [param ids] at least 12 LDU off the line
## through [param point] along [param way], so a turn about it reads: the
## rim of a wheel seen end on, not its hub. {} when none shows.
func _press_off_line(ids: PackedInt64Array, point: Vector3, way: Vector3) -> Dictionary:
	for key: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(key)
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		if info == null:
			continue
		for corner: int in 8:
			for share: float in [0.85, 0.6]:
				var at: Vector3 = brick.transform * info.bounds.get_center().lerp(
					info.bounds.get_endpoint(corner), share)
				var off: Vector3 = at - point
				if (off - way * off.dot(way)).length() < 12.0 or _camera.is_position_behind(at):
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
