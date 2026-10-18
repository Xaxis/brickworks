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

const OUT := "/mnt/Projects/brickworks/bench/results/grab7-2026-10-17"
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
## The last case reached its end.
var _case_done: bool = false


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
		if arg == "--check-covers":
			# Every turned part asked where something is is also worked out
			# whole, and the two answers compared (Grab.check_covers).
			Grab.check_covers = true
	for case: Array in CASES:
		if not only.is_empty() and only != "cases" and not str(case[0]).contains(only):
			continue
		# A case that stopped on a script error says so: it counted no
		# failure, and what it left going broke the next one.
		_case_done = false
		var failed_before: int = _failures
		await _case(case[0], case[1], case[2])
		if not _case_done and _failures == failed_before:
			_check("%s: the case ran to its end" % case[0], false)
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
	if only.is_empty() or only == "worms":
		var asked_worms: Array = []
		for arg: String in args:
			if arg.begins_with("--worm-set="):
				asked_worms.append(["worm: %s" % arg.get_file(), "res://" + arg.trim_prefix("--worm-set=")])
		for one: Array in (WORMS if asked_worms.is_empty() else asked_worms):
			await _worm_case(one[0], one[1])
	if only.is_empty() or only == "actuators":
		var asked_actuators: Array = []
		for arg: String in args:
			if arg.begins_with("--actuator-set="):
				asked_actuators.append(["actuator: %s" % arg.get_file(), "res://" + arg.trim_prefix("--actuator-set=")])
		for one: Array in (ACTUATORS if asked_actuators.is_empty() else asked_actuators):
			await _actuator_case(one[0], one[1], one[2] if one.size() > 2 else false)
	if only.is_empty() or only == "scissor":
		await _scissor_case()
	if only.is_empty() or only == "falling":
		await _made_fall()
	if only.is_empty() or only == "swing":
		await _swing_case()
	if only.is_empty() or only == "swing" or only == "double":
		await _double_case()
	if only.is_empty() or only == "falling" or only == "landing":
		await _landing_case()
	if only.is_empty() or only == "coast":
		await _coast_case()
	if only.is_empty() or only == "cardan":
		await _cardan_case()
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
	if only.is_empty() or only == "mcp" or only == "steer":
		await _steer_twice()
	if only == "kart":
		await _steer_twice(true)
	if only.is_empty() or only == "big":
		await _big()
	if Grab.check_covers:
		_check("a turned part's cover asked where something is answers as the whole cover does, %d of %d"
			% [Grab.covers_checked - Grab.covers_differ, Grab.covers_checked], Grab.covers_differ == 0)
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
	await _clean_slate()
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


## Until the view stops moving: framed from another side, it eases there
## over some frames, and a point picked on the way is over another part by
## the press.
func _camera_still() -> void:
	var was: Transform3D = _camera.global_transform
	var still: int = 0
	for _n: int in 240:
		await process_frame
		var now: Transform3D = _camera.global_transform
		still = still + 1 if now.is_equal_approx(was) else 0
		was = now
		if still >= 3:
			return


## Nothing an earlier case left going: a button still down, a grab or a
## drag not let go, a part in hand, a selection. A case that stopped half
## way (the windmill's press once carried a part off and the case ended on
## it) left a drag going, and the next case's press was not a grab.
func _clean_slate() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or bool(_main.get("_dragging_part")) \
			or bool(_main.get("_grabbing")) or _grab.is_grabbing():
		await _button(_last_screen, false)
	if _grab.is_grabbing():
		_grab.cancel()
	if _builder.is_carrying():
		_verbs.put_away()
	_main.set("_dragging_part", false)
	_main.set("_grabbing", false)
	_main.set("_press_brick", 0)
	_builder.clear_selection()
	await _frames(2)


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
							var its: int = int(bodies.body_of.get(brick.id, -1))
							print("    #%d %s at %s, in body %d of %d parts: %s" % [brick.id, part, brick.transform,
								its, (bodies.members.get(its, PackedInt64Array()) as PackedInt64Array).size(),
								bodies.named([its]) if its >= 0 else "none"])
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
	# Still that part under the point, once the view has come to rest: framed
	# from another side, the view was still moving, and the windmill's press
	# landed on the frame beside its crank and carried it off.
	await _camera_still()
	for _settle: int in 6:
		if _verbs.brick_at(press["screen"]) == int(press["brick"]):
			break
		await _frames(10)
		var again: Dictionary = _press_point(bodies.members[child], bodies)
		if again.is_empty():
			again = _press_point(moving, bodies)
		if not again.is_empty():
			press = again
	# What a grab of the part pressed reads, asked before the press: a press
	# that carries it off takes it out of the model.
	var pressed: int = int(press["brick"])
	var trial := Grab.new()
	trial.world = _world
	trial.builder = _builder
	trial.library = _library
	trial.bodies = bodies
	var trial_said: String = trial.begin(pressed, _world.get_brick(pressed).transform.origin)
	trial_said += " " + (trial.why if not trial.why.is_empty() else trial.said)
	if "--debug" in OS.get_cmdline_user_args():
		_grab._ready_now()
		var as_drag := Grab.new()
		as_drag.world = _world
		as_drag.builder = _builder
		as_drag.library = _library
		as_drag.bodies = _grab.get("_bodies")
		as_drag.shared_mechanism = _grab.get("_mechanism")
		print("    (as GrabDrag reads it: %s %s %s)" % [as_drag.begin(pressed,
			_world.get_brick(pressed).transform.origin), as_drag.why, as_drag.said])
	var screen: Vector2 = press["screen"]
	var revision_before: int = _world.revision
	var under_before: int = _verbs.brick_at(screen)
	await _move(screen, 0)
	var under_hover: int = _verbs.brick_at(screen)
	await _button(screen, true)
	var pressed_on: int = int(_main.get("_press_brick"))
	var pressed_at: Vector2 = _main.get("_press_at")
	var pressed_part: String = _world.get_brick(pressed_on).part_id if _world.get_brick(pressed_on) != null else "?"
	# Past the slop: the drag is the grab's.
	await _move(screen + Vector2(0, 7), MOUSE_BUTTON_MASK_LEFT)
	var grab: Grab = _grab.grab
	if grab == null:
		print("    (the press landed on #%d %s; under the point before %d, hovering %d, pressed %d at %s, event %s, main pressed at %s; revision %d at the case, %d before the press, %d now; playing %s)" % [
			pressed_on, pressed_part, under_before, under_hover, int(press["brick"]), screen, _as_event(screen), pressed_at,
			revision, revision_before, _world.revision, (_main.get("_playback") as BuildPlayback).is_playing()])
		print("    (press state: grabbing=%s dragging=%s carrying=%s press_brick=%s mode=%s copies=%s locked=%s ready=%s selection=%s; GrabDrag said %s)" % [
			_main.get("_grabbing"), _main.get("_dragging_part"), _builder.is_carrying(),
			_main.get("_press_brick"), _verbs.mode, _main.get("_press_copies"),
			_builder.is_locked(pressed), _grab.is_ready(), _builder.selection.keys(), _grab.last_words])
		print("    (Grab.begin on #%d directly, before the press: %s)" % [pressed, trial_said])
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
	if not grab._round_self.is_empty():
		await _round_parts_check(name, grab)
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
	_case_done = true


## A round part turned beside the joint's line (4096's cones under the boom)
## is tested as its own shape moved round, not by its turned cover: still
## held to the model. Pushed 4 LDU into the part beside it, it has no room;
## where it stands, it has.
func _round_parts_check(name: String, grab: Grab) -> void:
	var pushed: int = 0
	var met: int = 0
	var said := PackedStringArray()
	for key: int in grab._round_self:
		var brick: BrickWorld.Brick = _world.get_brick(key)
		var box: AABB = brick.transform * _library.parts[brick.part_id].bounds
		for other: BrickWorld.Brick in _world.bricks():
			if grab.skip.has(other.id) or grab.moving.has(other.id) or _store.scenery.has(other.id):
				continue
			var info: PartLibrary.PartInfo = _library.parts.get(other.part_id)
			if info == null or not box.grow(1.0).intersects(other.transform * info.bounds):
				continue
			# Beside it, not under or over it: side by side along the line by
			# more than a plate's height.
			var mine: Vector2 = Grab._reach_along(brick.transform, _library.parts[brick.part_id].bounds, grab.axis)
			var theirs: Vector2 = Grab._reach_along(other.transform, info.bounds, grab.axis)
			if minf(mine.y, theirs.y) - maxf(mine.x, theirs.x) < 8.0:
				continue
			var gap: Vector3 = (other.transform * info.bounds).get_center() - box.get_center()
			gap -= grab.axis * gap.dot(grab.axis)
			if gap.length() < 0.5:
				continue
			var at: Dictionary = grab.rest.duplicate()
			at[key] = Transform3D(brick.transform.basis, brick.transform.origin + gap.normalized() * 4.0)
			pushed += 1
			var meets: bool = not grab.has_room(at)
			if meets:
				met += 1
			said.append("#%d %s into #%d %s%s" % [key, brick.part_id, other.id, other.part_id,
				"" if meets else " (room)"])
	_check("%s: a round part pushed 4 LDU into the part beside it meets it (%d of %d: %s), and where it stands has room"
		% [name, met, pushed, ", ".join(said)], pushed > 0 and met == pushed and grab.has_room(grab.rest))


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
					if grab.blocked_by.size() == 2:
						stop_said += ": #%d %s meets #%d %s" % [int(grab.blocked_by[0]),
							_world.get_brick(int(grab.blocked_by[0])).part_id, int(grab.blocked_by[1]),
							_world.get_brick(int(grab.blocked_by[1])).part_id]
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
	# What a frame costs with nothing moving: drawing the model and the window.
	_cost_idle.clear()
	for _n: int in 30:
		var idle_began: int = Time.get_ticks_usec()
		await _frames(1)
		_cost_idle.append(float(Time.get_ticks_usec() - idle_began) / 1000.0)
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
	var whole := PackedFloat64Array()
	_costs_begin()
	for target: float in targets:
		var turned: Vector3 = _about(grab.pivot, grab.axis, target) * hold
		var began: int = Time.get_ticks_usec()
		await _move(_camera.unproject_position(turned), MOUSE_BUTTON_MASK_LEFT)
		whole.append(float(Time.get_ticks_usec() - began) / 1000.0)
		frame_worst = maxf(frame_worst, whole[whole.size() - 1])
		_costs_sample()
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
	print("    whole frames: %s; %s" % [_spread(whole), _costs_said()])
	if kind == "fourbar" and _windowed:
		# A whole frame is the window's own frame, as it costs with nothing
		# moving, plus the drag's work: drawing what moved adds next to
		# nothing. Under xvfb the window's own frame is most of it, its
		# picture copied to the screen in software (section 13).
		var drawn: float = _mean(whole) - _mean(_cost_idle) - _mean(_cost_drag)
		_check("%s: a drag frame is the window's idle frame and the drag's own work, the drawing %.1f ms more on average (whole %s; idle %s; the drag's own %s)"
			% [name, drawn, _spread(whole), _spread(_cost_idle), _spread(_cost_drag)], drawn < 4.0)
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
	["rack and pinion: a column riding in a cab of hinges", "res://vendor/omr/files/8062-1_Truck-with-Motorbike.mpd"],
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
				var trial_state: String = trial.begin(theirs.key, _world.get_brick(theirs.key).transform.origin)
				print("    (the column on %s, %d teeth: %s %s%s; %s)" % [theirs.part, theirs.teeth, trial_state,
					trial.why if not trial.why.is_empty() else trial.said, "" if trial.linkage == null
					else ", gears carried" if trial.linkage.gears_carried else "", trial.gear_note])
				if trial_state == "moves" \
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
		elif followed + 1 >= targets.find(target) and absf(target) <= 24.0:
			print("      (at %.0f° it reads %.2f°: %s%s; the loop's residual %.4f after %d rounds)" % [target, grab.angle,
				"its loop closes no further" if grab.loop_short else "it meets the model",
				"" if grab.blocked_by.size() != 2 else ", #%d %s meets #%d %s" % [int(grab.blocked_by[0]),
				_world.get_brick(int(grab.blocked_by[0])).part_id, int(grab.blocked_by[1]),
				_world.get_brick(int(grab.blocked_by[1])).part_id], grab.linkage.residual, grab.linkage.iterations])
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
			# Both turns against what carries the column (Willis: in the frame
			# of the carrier, two gears in mesh turn as their teeth say, however
			# the carrier moves; it stands still on 8054 and 8828, and rides on
			# the cab's hinges on 8062).
			var w_column: Transform3D = (grab.placed.get(column_gear, grab.rest.get(column_gear))
				as Transform3D) * (grab.rest.get(column_gear) as Transform3D).affine_inverse()
			var carrier_key: int = int((bodies.members[int(bodies.parent_of[wheel_body])] as PackedInt64Array)[0])
			var w_carrier: Transform3D = (grab.placed.get(carrier_key, _world.get_brick(carrier_key).transform)
				as Transform3D) * (grab.rest.get(carrier_key, _world.get_brick(carrier_key).transform)
				as Transform3D).affine_inverse()
			var column_turn: float = _turn_about((w_carrier.affine_inverse() * w_column).basis, grab.axis)
			var pinion_turn: float = _turn_about((w_carrier.affine_inverse() * w_gear).basis, mesh.axis)
			worst_ratio = maxf(worst_ratio, absf(absf(pinion_turn) - ratio * absf(column_turn)))
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


# -- worms ---------------------------------------------------------------------------------

## Real sets with a worm driving a gear: a crane's winch, a tower crane.
const WORMS: Array = [
	["worm: a tower crane's winch", "res://vendor/omr/files/42042-1_Tower-Crane.mpd"],
	["worm: a tractor's sower, on a 24", "res://vendor/omr/files/8063-1_Sower.mpd"],
	["worm: a log loader's grabber", "res://vendor/omr/files/8049-1.mpd"],
	["worm: a crane's winch, through two universal joints", "res://vendor/omr/files/8062-1_Crane.mpd"],
]
## Tried and not passing, run with --worm-set=: 8258-1's worm stops at 10°, a
## beam on its axle meeting the beam beside it.


## Turn a worm by the pointer, as a person turns its crank, two whole turns:
## every frame its gear has turned a tooth for each turn of the worm (1/24 of
## a turn for a 24, by hand from the teeth its name gives). Then take hold of
## the gear's side: nothing turns, and the status bar says the worm holds it.
func _worm_case(name: String, path: String) -> void:
	print("\n%s: %s" % [name, path.get_file()])
	if not await _open(path):
		return
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	var train: Mechanism = _grab._mechanism
	if train == null:
		_check("%s: the gear trains are read" % name, false)
		return
	var chosen: Mechanism.Coupling = null
	for coupling: Mechanism.Coupling in train.couplings:
		if coupling.how != "worm":
			continue
		var worm_body: int = int(bodies.body_of.get(coupling.one.key, -1))
		if worm_body < 0 or not bodies.parent_link.has(worm_body):
			continue
		var trial := Grab.new()
		trial.world = _world
		trial.builder = _builder
		trial.library = _library
		trial.bodies = bodies
		trial.shared_mechanism = train
		var state: String = trial.begin(coupling.one.key, _world.get_brick(coupling.one.key).transform.origin)
		if state == "moves" and trial.coupled.has(coupling.other.key):
			chosen = coupling
			break
		print("    (the worm #%d on %s: %s %s)" % [coupling.one.key, coupling.other.part, state, trial.why])
	_check("%s: a worm turns a gear here (%s)" % [name, train.couplings_said()], chosen != null)
	if chosen == null:
		return
	var worm_key: int = chosen.one.key
	var wheel_key: int = chosen.other.key
	var worm_body: int = int(bodies.body_of[worm_key])
	var wheel_body: int = int(bodies.body_of[wheel_key])
	var wheel_name: String = _library.parts[_world.get_brick(wheel_key).part_id].name
	# The gear's teeth, by hand: the number its name gives.
	var named_teeth: int = 0
	var words: PackedStringArray = wheel_name.split(" ")
	for n: int in range(1, words.size()):
		if words[n].begins_with("Tooth") and words[n - 1].is_valid_int():
			named_teeth = int(words[n - 1])
	print("    the worm #%d %s on %s; it turns #%d %s (%s, %d teeth), %s LDU from its axis for %s" % [worm_key,
		_world.get_brick(worm_key).part_id, bodies.parent_link[worm_body].words(), wheel_key,
		_world.get_brick(wheel_key).part_id, wheel_name, named_teeth, Mechanism._tidy(chosen.apart),
		Mechanism._tidy(chosen.ideal)])
	var driver: Bodies.Link = bodies.parent_link[worm_body]
	var line: Vector3 = driver.axis.normalized()
	# A universal joint the train turns through, pictured where it stood:
	# the shafts the universal joints join, and their crosses, drawn alone.
	var cardan := PackedInt64Array()
	for joint: Dictionary in train.universals:
		for body: int in [int(joint["one"]), int(joint["other"])]:
			for key: int in train.bodies.get(body, []):
				if not cardan.has(key):
					cardan.append(key)
		for key: int in joint["cross"]:
			if not cardan.has(key):
				cardan.append(key)
	var first_joint := PackedInt64Array()
	if not train.universals.is_empty():
		first_joint.append_array([int(train.universals[0]["end_one"]), int(train.universals[0]["end_other"])])
		for key: int in train.universals[0]["cross"]:
			first_joint.append(key)
	if _windowed and not cardan.is_empty():
		await _cardan_shot(cardan, first_joint, name.get_slice(":", 0) + " " + path.get_file().get_basename(),
			"u_before")
	var around: PackedInt64Array = bodies.parts_of([worm_body, wheel_body])
	_camera.look_from(Vector3(0.6, 0.7, 1.0).normalized())
	_frame_on(around)
	await _frames(20)
	var before: Dictionary = _snapshot()
	var depth: int = _builder.history_depth()
	var revision: int = _world.revision
	var press: Dictionary = _press_off_line(bodies.parts_of(bodies.beyond(worm_body)), driver.point, line)
	for side: Vector3 in [Vector3(1, 0.6, 1), Vector3(-1, 0.6, 1), Vector3(1, 0.6, -1),
			Vector3(-1, 0.6, -1), Vector3(0.1, 1, 0.1)]:
		if not press.is_empty():
			break
		_camera.look_from(side.normalized())
		_frame_on(around)
		await _frames(10)
		press = _press_off_line(bodies.parts_of(bodies.beyond(worm_body)), driver.point, line)
	if press.is_empty():
		_check("%s: the worm's axle is under the pointer somewhere" % name, false)
		return
	if _windowed:
		await _clean_shot(name.get_slice(":", 0) + " " + path.get_file().get_basename(), "1_before")
	var screen: Vector2 = press["screen"]
	# The first move round the axle, as a hand turning a crank moves: along the
	# line it would read as a slide.
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
	_check("%s: a drag on the worm's axle turns it and its gear (%s)" % [name, _grab.last_words
		if grab == null else grab.said], grab != null and grab.state == "moves" and grab.coupled.has(wheel_key))
	if grab == null or not grab.coupled.has(wheel_key):
		await _button(screen, false)
		return
	var hold: Vector3 = grab._hold
	var worm_axis: Vector3 = chosen.one.axis
	var wheel_axis: Vector3 = chosen.other.axis
	var worm_turned: float = 0.0
	var last_worm: float = 0.0
	var worst: float = 0.0
	var sense: float = 0.0
	var followed: int = 0
	var checked: int = 0
	var table := PackedStringArray()
	var mid_shot: bool = false
	var frame_worst: float = 0.0
	# Each universal joint's two shafts, their turns about their own lines
	# as drawn, unwrapped frame to frame: [last one, last other, turned one,
	# turned other, worst apart].
	var crossing: Array = []
	for joint: Dictionary in train.universals:
		crossing.append([0.0, 0.0, 0.0, 0.0, 0.0])
	for n: int in range(1, 73):
		var target: float = 10.0 * n
		var began: int = Time.get_ticks_usec()
		await _move(_camera.unproject_position(_about(grab.pivot, grab.axis, target) * hold),
			MOUSE_BUTTON_MASK_LEFT)
		frame_worst = maxf(frame_worst, float(Time.get_ticks_usec() - began) / 1000.0)
		if not grab.stopped and absf(grab.angle - target) < 1.5:
			followed += 1
		elif n <= 3 or (n % 18 == 0):
			print("      (at %.0f°: the grab reads %.2f°, stopped %s%s)" % [target, grab.angle, grab.stopped,
				"" if grab.blocked_by.size() != 2 else ", #%d %s meets #%d %s" % [int(grab.blocked_by[0]),
				_world.get_brick(int(grab.blocked_by[0])).part_id, int(grab.blocked_by[1]),
				_world.get_brick(int(grab.blocked_by[1])).part_id]])
		# As drawn: the worm's own turn about its axis, unwrapped, and its gear's.
		var w_worm: Transform3D = (grab.placed.get(worm_key, grab.rest[worm_key]) as Transform3D) \
			* (grab.rest[worm_key] as Transform3D).affine_inverse()
		var raw: float = _turn_about(w_worm.basis, worm_axis)
		worm_turned += wrapf(raw - last_worm, -180.0, 180.0)
		last_worm = raw
		var w_wheel: Transform3D = (grab.placed.get(wheel_key, grab.rest[wheel_key]) as Transform3D) \
			* (grab.rest[wheel_key] as Transform3D).affine_inverse()
		var wheel_turned: float = _turn_about(w_wheel.basis, wheel_axis)
		for u: int in train.universals.size():
			var joint: Dictionary = train.universals[u]
			var turns: Array = crossing[u]
			for side: int in 2:
				var end: int = int(joint["end_one" if side == 0 else "end_other"])
				var w_end: Transform3D = (grab.placed.get(end, _world.get_brick(end).transform) as Transform3D) \
					* (grab.rest.get(end, _world.get_brick(end).transform) as Transform3D).affine_inverse()
				var now: float = _turn_about(w_end.basis, joint["way_one" if side == 0 else "way_other"])
				turns[2 + side] = float(turns[2 + side]) + wrapf(now - float(turns[side]), -180.0, 180.0)
				turns[side] = now
			# In line, Cardano's ratio is one for one.
			turns[4] = maxf(float(turns[4]), absf(float(turns[3]) - float(turns[2])))
		if absf(worm_turned) < 5.0:
			continue
		if sense == 0.0:
			sense = signf(wheel_turned * worm_turned)
		# By hand: a tooth a turn of the worm.
		var by_hand: float = sense * worm_turned / float(maxi(named_teeth, 1))
		worst = maxf(worst, absf(wheel_turned - by_hand))
		checked += 1
		if n % 18 == 0:
			table.append("      worm %+7.1f° (%+.2f turns): gear %+7.3f°, by hand %+.2f/%d turns = %+7.3f°"
				% [worm_turned, worm_turned / 360.0, wheel_turned, worm_turned / 360.0, named_teeth, by_hand])
		if not mid_shot and _windowed and absf(worm_turned) >= 360.0:
			mid_shot = true
			await _clean_shot(name.get_slice(":", 0) + " " + path.get_file().get_basename(), "2_mid")
	for row: String in table:
		print(row)
	_check("%s: the worm follows the pointer round in %d of 72 frames, %.0f° (%.1f turns)" % [name, followed,
		grab.angle, grab.angle / 360.0], followed >= 60 and absf(grab.angle) >= 700.0)
	_check("%s: in %d poses its %d tooth gear has turned a tooth for each turn of the worm, 1/%d, to %.4f°"
		% [name, checked, named_teeth, named_teeth, worst], named_teeth > 0 and checked >= 60 and worst < 0.01
		and chosen.other.teeth == named_teeth)
	if _windowed and not cardan.is_empty():
		await _cardan_shot(cardan, first_joint, name.get_slice(":", 0) + " " + path.get_file().get_basename(),
			"u_turned")
	for u: int in train.universals.size():
		var joint: Dictionary = train.universals[u]
		var turns: Array = crossing[u]
		var bent: float = rad_to_deg((joint["way_one"] as Vector3).angle_to(joint["way_other"]))
		# A universal joint passes the turn on: the shaft past it turns as the
		# one before it (one for one in line, by Cardano), and its cross stays
		# between its ends (the room test would stop it there otherwise).
		_check(("%s: a universal joint (#%d %s to #%d %s, its shafts %.1f° apart) passes the turn on: the shaft "
			+ "before it turned %.1f°, the one past it %.1f°, at most %.4f° apart") % [name, int(joint["end_one"]),
			_world.get_brick(int(joint["end_one"])).part_id, int(joint["end_other"]),
			_world.get_brick(int(joint["end_other"])).part_id, bent, float(turns[2]), float(turns[3]),
			float(turns[4])], bent < 1.0 and absf(float(turns[2])) > 30.0 and float(turns[4]) < 0.01)
	print("    drag frames: worst %.1f ms whole (following %.2f ms worst)" % [frame_worst, _grab.worst_follow_ms])
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
	# The other way round: the gear's side taken hold of does not turn the worm.
	_grab._ready_now()
	bodies = _grab._bodies
	wheel_body = int(bodies.body_of[wheel_key])
	var wheel_link: Bodies.Link = bodies.parent_link.get(wheel_body)
	if wheel_link == null:
		print("    (the gear's body is an anchor here: nothing to take hold of on its side)")
		return
	# A part of the gear's own body: one further out turns on a joint of its own.
	var back_press: Dictionary = _press_off_line(bodies.members[wheel_body], wheel_link.point,
		wheel_link.axis.normalized())
	if back_press.is_empty():
		_frame_on(bodies.members[wheel_body])
		await _frames(10)
		back_press = _press_off_line(bodies.members[wheel_body], wheel_link.point,
			wheel_link.axis.normalized())
	if not back_press.is_empty():
		var trial_back := Grab.new()
		trial_back.world = _world
		trial_back.builder = _builder
		trial_back.library = _library
		trial_back.bodies = bodies
		trial_back.shared_mechanism = _grab._mechanism
		var pressed_back: int = int(back_press["brick"])
		print("    (a grab of #%d %s reads: %s, %s %s)" % [pressed_back, _world.get_brick(pressed_back).part_id,
			trial_back.begin(pressed_back, _world.get_brick(pressed_back).transform.origin), trial_back.said,
			trial_back.gear_note])
	if back_press.is_empty():
		_check("%s: the gear's side is under the pointer somewhere" % name, false)
		return
	revision = _world.revision
	depth = _builder.history_depth()
	before = _snapshot()
	var at: Vector2 = back_press["screen"]
	await _move(at, 0)
	await _button(at, true)
	for step: int in range(1, 6):
		await _move(at + Vector2(6.0 * step, 4.0 * step), MOUSE_BUTTON_MASK_LEFT)
	var held: Grab = _grab.grab
	var drawn_moved: bool = held != null and held.state == "moves" and not held.changed().is_empty()
	var status: String = _grab.last_words
	print("    pressed the gear's side, #%d %s: %s" % [int(back_press["brick"]),
		_world.get_brick(int(back_press["brick"])).part_id, status])
	_check("%s: a drag on the gear's side turns nothing: the worm holds it, said (\"%s\")" % [name,
		status.get_slice("(", 0).strip_edges()], held != null and held.state == "locked" and not drawn_moved
		and status.contains("self-locking") and _world.revision == revision)
	await _button(_last_screen, false)
	await _frames(3)
	_check("%s: let go, nothing was kept (%s)" % [name, _differs(before)], _builder.history_depth() == depth
		and _differs(before) == "none differs")


## A picture of [param keys] alone, from one side, as a drag has them drawn,
## close on [param near].
func _cardan_shot(keys: PackedInt64Array, near: PackedInt64Array, name: String, when: String) -> void:
	var alone: Dictionary = {}
	for key: int in keys:
		alone[key] = true
	var eye: Transform3D = _camera.global_transform
	_world.show_only(alone)
	_camera.look_from(Vector3(0.25, 0.45, 1.0).normalized())
	_frame_on(near)
	await _frames(20)
	await _clean_shot(name, when)
	_world.show_only({})
	_camera.global_transform = eye
	await _frames(5)


# -- linear actuators -----------------------------------------------------------------------

## Real sets with a linear actuator raising a boom.
## Each with whether an end of its stroke is in reach of the drag: 42024-1's
## small one meets the model both ways first.
const ACTUATORS: Array = [
	["actuator: a wheel loader's arm", "res://vendor/omr/files/42081-1.mpd", true],
	["actuator: a small one, and its input", "res://vendor/omr/files/42024-1.mpd", false],
	["cylinders: a forest machine's crane on two pneumatic cylinders", "res://vendor/omr/files/42080-1.mpd", true],
]
## Tried and not passing, run with --actuator-set=: 42006-1's boom closes its
## triangle to 0.006° but stops 3.4 LDU out and 13.3 in, a beam 5 of the boom
## meeting an axle 8 of the turret by the room test.


## The triangle an actuator closes: its body pinned to one body (x), its rod
## pinned to another (y), and those two pinned to each other, every pin along
## one way (k). {b, d, x, y, p, r, o, k}: the actuator's body and rod bodies,
## the three pins' points. {} where it closes none.
func _actuator_triangle(bodies: Bodies, link: Bodies.Link) -> Dictionary:
	var pair: Array = link.pairs[0]
	var b: int = int(bodies.body_of[int(pair[0])])
	var d: int = int(bodies.body_of[int(pair[1])])
	for pb: Bodies.Link in bodies.touching.get(b, []):
		if pb == link or pb.axis == Vector3.ZERO:
			continue
		var x: int = pb.other(b)
		for pd: Bodies.Link in bodies.touching.get(d, []):
			if pd == link or pd.axis == Vector3.ZERO:
				continue
			var y: int = pd.other(d)
			if y == x or y == b or x == d:
				continue
			for po: Bodies.Link in bodies.touching.get(x, []):
				if po.other(x) != y or po.axis == Vector3.ZERO:
					continue
				var k: Vector3 = po.axis.normalized()
				if absf(pb.axis.normalized().dot(k)) < 0.999 or absf(pd.axis.normalized().dot(k)) < 0.999:
					continue
				return {"b": b, "d": d, "x": x, "y": y, "p": pb.point, "r": pd.point, "o": po.point, "k": k}
	return {}


## By hand: how far the triangle's y body has turned against its x body
## about k, degrees, with the rod drawn [param e] LDU out along [param way]
## from where it stood. The rod's pin moves along the actuator, so the two
## pins stand |r + way e - p| apart, square to k; the rod's pin goes round o
## at its own distance from it, the body's pin stays at its own: the angle at
## o is the law of cosines'.
static func _triangle_turn(tri: Dictionary, way: Vector3, e: float) -> float:
	var k: Vector3 = tri["k"]
	var o: Vector3 = tri["o"]
	var p: Vector3 = tri["p"]
	var r: Vector3 = tri["r"]
	var flat := func(v: Vector3) -> Vector3:
		return v - k * v.dot(k)
	var to_p: Vector3 = flat.call(p - o)
	var to_r: Vector3 = flat.call(r - o)
	var apart: float = (flat.call(r + way * e - p) as Vector3).length()
	var c: float = (to_r.length_squared() + to_p.length_squared() - apart * apart) \
		/ (2.0 * to_r.length() * to_p.length())
	if absf(c) > 1.0:
		return NAN
	var was: float = atan2(k.dot(to_p.cross(to_r)), to_p.dot(to_r))
	return rad_to_deg(signf(was) * acos(c) - was)


## Draw an actuator's rod out and in by the pointer, past both ends of its
## stroke: every frame it stays within the stroke the library draws, and the
## boom its loop raises stands where the law of cosines puts it for the rod's
## place. Then take hold of the boom: the actuator's screw holds it. Then turn
## the input over MCP (move_part degrees=), where it is a part of its own:
## the rod goes the stroke over the turns builders counted.
func _actuator_case(name: String, path: String, reaches_an_end: bool = false) -> void:
	print("\n%s: %s" % [name, path.get_file()])
	if not await _open(path):
		return
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	var chosen: Bodies.Link = null
	var tri: Dictionary = {}
	for link: Bodies.Link in bodies.links:
		if link.kind != "actuator" and link.kind != "cylinder":
			continue
		var found: Dictionary = _actuator_triangle(bodies, link)
		print("    actuator %s~%s: slide %s, %s" % [_world.get_brick(int(link.pairs[0][0])).part_id,
			_world.get_brick(int(link.pairs[0][1])).part_id, link.slide, "closes a triangle" if not found.is_empty()
			else "in no triangle"])
		if chosen == null and not found.is_empty():
			chosen = link
			tri = found
	print("    %s; %d pieces held by what they are lodged in" % [bodies.summary(), bodies.lodged])
	_check("%s: a linear actuator raises something by a loop here" % name, chosen != null)
	if chosen == null:
		return
	var body_key: int = int(chosen.pairs[0][0])
	var rod_key: int = int(chosen.pairs[0][1])
	var stroke: float = chosen.slide.x + chosen.slide.y
	var out_by: float = chosen.slide.y
	var way: Vector3 = chosen.axis.normalized()
	var x_key: int = int((bodies.members[int(tri["x"])] as PackedInt64Array)[0])
	var y_key: int = int((bodies.members[int(tri["y"])] as PackedInt64Array)[0])
	print("    %s in %s: stroke %s LDU, drawn out %s; its loop turns %s against %s" % [
		_world.get_brick(rod_key).part_id, _world.get_brick(body_key).part_id, Balance.tidy(stroke),
		Balance.tidy(out_by), bodies.named([int(tri["y"])]), bodies.named([int(tri["x"])])])
	var around: PackedInt64Array = bodies.parts_of([int(tri["b"]), int(tri["d"]), int(tri["y"])])
	_camera.look_from(tri["k"] as Vector3 + Vector3(0.0, 0.25, 0.0))
	_frame_on(around)
	await _frames(20)
	var before: Dictionary = _snapshot()
	var depth: int = _builder.history_depth()
	var press: Dictionary = _press_point(PackedInt64Array([rod_key]), bodies)
	for side: Vector3 in [-(tri["k"] as Vector3), Vector3(1, 0.6, 1), Vector3(-1, 0.6, 1)]:
		if not press.is_empty():
			break
		_camera.look_from(side.normalized())
		_frame_on(around)
		await _frames(10)
		press = _press_point(PackedInt64Array([rod_key]), bodies)
	if press.is_empty():
		_check("%s: the rod is under the pointer somewhere" % name, false)
		return
	if _windowed:
		await _clean_shot(name.get_slice(":", 0) + " " + path.get_file().get_basename(), "1_before")
	var screen: Vector2 = press["screen"]
	var rod_at: Vector3 = _world.get_brick(rod_key).transform.origin
	var first: Vector2 = (_camera.unproject_position(rod_at + way * 3.0) - _camera.unproject_position(rod_at)) \
		.normalized() * 7.0
	await _move(screen, 0)
	await _button(screen, true)
	await _move(screen + first, MOUSE_BUTTON_MASK_LEFT)
	var grab: Grab = _grab.grab
	_check("%s: a drag on the rod draws it along its actuator, the loop with it (%s)" % [name,
		_grab.last_words if grab == null else grab.said], grab != null and grab.state == "moves"
		and grab.mode == "slide" and grab.linkage != null)
	if grab == null or grab.state != "moves" or grab.linkage == null:
		var tried := Grab.new()
		tried.world = _world
		tried.builder = _builder
		tried.library = _library
		tried.bodies = bodies
		tried.shared_mechanism = _grab._mechanism
		print("    (a grab of the rod reads %s: %s)" % [tried.begin(rod_key, _world.get_brick(rod_key).transform.origin),
			tried.said if tried.why.is_empty() else tried.why])
		await _button(screen, false)
		return
	print("    %s; %d joints, moving %d parts" % [grab.linkage.said(), grab.linkage.links.size(), grab.moving.size()])
	var hold: Vector3 = grab._hold
	# The pointer drags the slide's far side along the line: the rod out of
	# its body, or, where the tree hangs the body from the rod (42080-1's
	# cylinders, their rods pinned to the cab), the body along the rod, so
	# the rod goes in as the pointer goes out.
	var flip: float = 1.0 if bodies.parent_link.get(int(bodies.body_of[rod_key])) == chosen else -1.0
	# What the actuator raises: the triangle's body that moves with the drag.
	var boom_key: int = y_key if grab.moving.has(y_key) or not grab.moving.has(x_key) else x_key
	var targets: Array = []
	# Past both ends of the stroke, whichever side the pointer drags.
	var top: float = stroke - out_by + 16.0 if flip > 0.0 else out_by + 16.0
	var bottom: float = -out_by - 16.0 if flip > 0.0 else -(stroke - out_by) - 16.0
	var at: float = 0.0
	while at < top:
		at += 4.0
		targets.append(at)
	while at > bottom:
		at -= 4.0
		targets.append(at)
	# Let go half way out, somewhere new.
	while at < (stroke - out_by) * 0.5:
		at += 4.0
		targets.append(at)
	var moved := func(key: int) -> Transform3D:
		var now: Transform3D = _world.get_brick(key).transform
		return (grab.placed.get(key, now) as Transform3D) * (grab.rest.get(key, now) as Transform3D).affine_inverse()
	var worst: float = 0.0
	var checked: int = 0
	var followed: int = 0
	var most: float = -INF
	var least: float = INF
	var outside: float = 0.0
	var table := PackedStringArray()
	var mid_shot: bool = false
	var frame_worst: float = 0.0
	var rod_rest: Vector3 = _world.get_brick(rod_key).transform.origin
	var stop_said: Dictionary = {}
	# Every frame's pose, for a run before a change to be set against one
	# after: each moving part's place (poses_<set>.json).
	var poses: Array = []
	var pose_keys: Array = grab.moving.keys()
	pose_keys.sort()
	# The drag's own work each frame (GrabDrag.last_motion_ms), and where the
	# rod was at the last.
	var own := PackedFloat64Array()
	var last_e: float = 0.0
	for target: float in targets:
		var began: int = Time.get_ticks_usec()
		await _move(_camera.unproject_position(hold + way * target), MOUSE_BUTTON_MASK_LEFT)
		frame_worst = maxf(frame_worst, float(Time.get_ticks_usec() - began) / 1000.0)
		own.append(_grab.last_motion_ms)
		var origins: Array = []
		for key: int in pose_keys:
			var o: Vector3 = (grab.placed.get(key, _world.get_brick(key).transform) as Transform3D).origin
			origins.append([snappedf(o.x, 0.0001), snappedf(o.y, 0.0001), snappedf(o.z, 0.0001)])
		poses.append({"target": target, "shift": grab.shift, "stopped": grab.stopped, "origins": origins})
		# As drawn: the rod's place along the actuator against its body.
		var rel: Transform3D = (moved.call(body_key) as Transform3D).affine_inverse() * moved.call(rod_key)
		var e: float = way.dot(rel * rod_rest - rod_rest)
		last_e = e
		most = maxf(most, e)
		least = minf(least, e)
		outside = maxf(outside, maxf(-(out_by + e), out_by + e - stroke))
		if not grab.stopped and absf(e - flip * target) < 1.0:
			followed += 1
		elif grab.stopped and not stop_said.has(signf(target)):
			stop_said[signf(target)] = true
			var at_end: bool = absf(e - (stroke - out_by)) < 0.05 or absf(e + out_by) < 0.05
			print("      (stopped at %.2f LDU asked %.0f: %s%s)" % [e, flip * target, "the end of its stroke" if at_end
				else ("its loop closes no further" if grab.loop_short else "it meets the model"),
				"" if at_end or grab.blocked_by.size() != 2
				else ", #%d %s meets #%d %s" % [int(grab.blocked_by[0]), _world.get_brick(int(grab.blocked_by[0])).part_id,
				int(grab.blocked_by[1]), _world.get_brick(int(grab.blocked_by[1])).part_id]])
		var turned: float = _turn_about(((moved.call(x_key) as Transform3D).affine_inverse()
			* moved.call(y_key)).basis, tri["k"])
		var by_hand: float = _triangle_turn(tri, way, e)
		if not is_nan(by_hand):
			worst = maxf(worst, absf(wrapf(turned - by_hand, -180.0, 180.0)))
			checked += 1
		if absf(fmod(target, 20.0)) < 0.01:
			table.append("      rod %+7.2f LDU out (%.2f of %s in its stroke): %s turned %+7.3f°, by hand %+7.3f°%s"
				% [e, out_by + e, Balance.tidy(stroke), bodies.named([int(tri["y"])]).get_slice(",", 0), turned,
				by_hand, " (stopped)" if grab.stopped else ""])
		if not mid_shot and _windowed and e >= stroke - out_by - 0.5:
			mid_shot = true
			await _clean_shot(name.get_slice(":", 0) + " " + path.get_file().get_basename(), "2_out")
	for row: String in table:
		print(row)
	_check("%s: the rod follows the pointer in %d frames, from %.2f to %.2f LDU" % [name, followed, least, most],
		followed >= 10)
	_check(("%s: drawn past both ends it never leaves its stroke: %.2f to %.2f LDU, the stroke's %.2f to %.2f, "
		+ "past it by %.3f; %s") % [name, least, most, -out_by, stroke - out_by, maxf(outside, 0.0),
		"both ends reached" if absf(most - (stroke - out_by)) < 0.1 and absf(least + out_by) < 0.1
		else ("an end reached, the other short of it where the model stops it" if absf(most - (stroke - out_by))
		< 0.1 or absf(least + out_by) < 0.1 else "the model stops it short of both")], outside < 0.05
		and (not reaches_an_end or absf(most - (stroke - out_by)) < 0.1 or absf(least + out_by) < 0.1))
	_check("%s: in %d poses the boom stands where the rod's place puts it, by the law of cosines, to %.4f°"
		% [name, checked, worst], checked >= 10 and worst < 0.05)
	print("    drag frames: worst %.1f ms whole (following %.2f ms worst: %s), %d solves" % [frame_worst,
		_grab.worst_follow_ms, _grab.worst_follow_said, grab.linkage.solves])
	_timings[name + " " + path.get_file()] = {"frames": _grab.frames, "worst_ms": snappedf(_grab.worst_ms, 0.01),
		"mean_ms": snappedf(_grab.mean_ms, 0.01), "worst_follow_ms": snappedf(_grab.worst_follow_ms, 0.01),
		"moving": grab.moving.size(), "parts": _world.brick_count()}
	# Its own work a frame within a frame at 30 a second, the drag's whole
	# share: 42081-1's arm cost 253 ms a frame on average and held one 2.9 s,
	# a panel's turned cover worked out whole at each new turn; 42024-1's 148,
	# its loop solved in steps the screw's input turned eight radians in.
	var sorted_own: PackedFloat64Array = own.duplicate()
	sorted_own.sort()
	var own_mean: float = 0.0
	for ms: float in own:
		own_mean += ms / maxf(own.size(), 1.0)
	var own_95: float = sorted_own[mini(sorted_own.size() - 1, int(sorted_own.size() * 0.95))] \
		if not sorted_own.is_empty() else 0.0
	_check("%s: the drag's own work a frame, mean %.1f ms, 95%% %.1f, worst %.1f, within a 33 ms frame"
		% [name, own_mean, own_95, sorted_own[sorted_own.size() - 1] if not sorted_own.is_empty() else 0.0],
		not own.is_empty() and own_mean <= 33.0 and own_95 <= 33.0)
	_timings[name + " " + path.get_file()]["p95_ms"] = snappedf(own_95, 0.01)
	var behind: Array = _left_behind(grab, bodies)
	_check("%s: nothing it carries is left behind: %d parts moved, %s" % [name, grab.changed().size(),
		"none lodged in them stays" if behind.is_empty() else "%d stay lodged in them: %s" % [behind.size(),
		", ".join(behind.slice(0, 6))]], behind.is_empty() and not grab.changed().is_empty())
	var pose_file := FileAccess.open(OUT.path_join("poses_%s.json" % path.get_file().get_basename()), FileAccess.WRITE)
	if pose_file != null:
		pose_file.store_string(JSON.stringify({"keys": pose_keys, "frames": poses}))
		pose_file.close()
	var let_go: int = Time.get_ticks_msec()
	await _button(_last_screen, false)
	await _frames(3)
	# 42081-1's arm, 262 parts, is checked on a worker and its cells laid a
	# share a frame: on a loaded box that took more than the usual 20 s.
	await _settled(120000)
	var kept_in: float = float(Time.get_ticks_msec() - let_go) / 1000.0
	print("    said: %s (kept in %.1f s)" % [_grab.last_words, kept_in])
	_timings[name + " " + path.get_file()]["kept_s"] = snappedf(kept_in, 0.01)
	# Checked and kept in a few seconds: 42081-1's arm took 20.6 to 22 s, its
	# panel's turned cover worked out whole at every bisection.
	_check("%s: let go, it is checked and kept in %.1f s" % [name, kept_in], kept_in <= 10.0)
	# Kept where it was let go. A stop met earlier in the drag and not yet
	# found was found at the release, and 42081-1's arm let go 20 LDU out was
	# kept 60 in, at that stop; 42080-1's arm, its saw's drive gear read as a
	# piece of its own and left standing, was put back near where it began.
	var now_at := func(key: int) -> Transform3D:
		return _world.get_brick(key).transform * (grab.rest[key] as Transform3D).affine_inverse()
	var kept_rel: Transform3D = (now_at.call(body_key) as Transform3D).affine_inverse() * now_at.call(rod_key)
	var kept_e: float = way.dot(kept_rel * rod_rest - rod_rest)
	_check("%s: kept where it was let go, the rod %.2f LDU out, let go at %.2f" % [name, kept_e, last_e],
		absf(kept_e - last_e) < 0.1)
	_check("%s: let go, it is one step to undo" % name, _builder.history_depth() == depth + 1)
	if _windowed:
		await _clean_shot(name.get_slice(":", 0) + " " + path.get_file().get_basename(), "3_after")
	_builder.undo()
	await _frames(3)
	_check("%s: one undo puts every part back exactly (%s)" % [name, _differs(before)],
		_differs(before) == "none differs")
	# The boom taken hold of: the actuator's screw holds it.
	_grab._ready_now()
	bodies = _grab._bodies
	var boom: int = int(bodies.body_of[boom_key])
	var trial := Grab.new()
	trial.world = _world
	trial.builder = _builder
	trial.library = _library
	trial.bodies = bodies
	trial.shared_mechanism = _grab._mechanism
	var boom_part: int = boom_key
	for key: int in bodies.members[boom]:
		if key != rod_key:
			boom_part = key
			break
	var state: String = trial.begin(boom_part, _world.get_brick(boom_part).transform.origin)
	if chosen.kind == "cylinder":
		# No screw holds a cylinder: what its rod raises, taken hold of and
		# turned, draws the rod along its cylinder, within its stroke, the
		# loop with it, as a drag on the rod does.
		trial.budget_ms = INF
		var turned_to: float = 0.0
		if state == "moves" and trial.mode == "turn":
			turned_to = trial.turn_to(trial.angle + 4.0)
			if absf(turned_to) < 0.5:
				turned_to = trial.turn_to(trial.angle - 4.0)
		var moved_by := func(key: int) -> Transform3D:
			var stood: Transform3D = trial.rest.get(key, _world.get_brick(key).transform)
			return (trial.placed.get(key, stood) as Transform3D) * stood.affine_inverse()
		var rel_now: Transform3D = (moved_by.call(body_key) as Transform3D).affine_inverse() * moved_by.call(rod_key)
		var slid: float = way.dot(rel_now * rod_rest - rod_rest)
		var by_hand_turn: float = _triangle_turn(tri, way, slid)
		_check(("%s: what it raises taken hold of and turned %.2f° draws the rod %.2f LDU along its cylinder, the "
			+ "triangle by hand %.2f° for that (%s)") % [name, turned_to, slid, by_hand_turn,
			trial.said if trial.why.is_empty() else trial.why], state == "moves" and trial.linkage != null
			and absf(turned_to) > 0.5 and absf(slid) > 0.1 and slid >= -out_by - 0.05 and slid <= stroke - out_by + 0.05)
		return
	_check("%s: the boom taken hold of does not move: %s" % [name, trial.why.get_slice("(", 0).strip_edges()
		if not trial.why.is_empty() else trial.said], state == "locked" and trial.why.contains("self-locking"))
	# The input turned over MCP, where it is a part of its own.
	await _input_turned(name, bodies)


## What a grab left behind: each part that stands still while one it is
## lodged in (their covers share cells where they stood) has moved, when it
## is in a piece of the model of its own, joined by no joint to the part
## that moved, so nothing but that part could have held it; not a hose,
## which bends. A part of the standing model beside one that moves (42024-1's
## angle connector on its own hinge, by a beam 3 turning on its pins) stays
## rightly. As "#key part (in #key part)". 42080-1's arm left an axle 3, an
## axle 5, a joiner, its saw's drive gear and the log in its gripper.
func _left_behind(grab: Grab, bodies: Bodies) -> Array:
	var piece_of: Dictionary = {}
	for start: int in bodies.members:
		if piece_of.has(start):
			continue
		piece_of[start] = start
		var frontier: Array = [start]
		while not frontier.is_empty():
			var at: int = frontier.pop_back()
			for l: Bodies.Link in bodies.touching.get(at, []):
				if not piece_of.has(l.other(at)):
					piece_of[l.other(at)] = start
					frontier.append(l.other(at))
	var out: Array = []
	var seen: Dictionary = {}
	for key: Variant in grab.changed():
		var mine: int = int(bodies.body_of.get(int(key), -1))
		for other: int in _builder.lattice.blockers_boxes(_builder.lattice.boxes_of(int(key)), int(key), {}):
			if grab.placed.has(other) or _store.scenery.has(other) or seen.has(other):
				continue
			var theirs: int = int(bodies.body_of.get(other, -1))
			if bodies.flexible.has(theirs) or piece_of.get(theirs, -1) == piece_of.get(mine, -2):
				continue
			seen[other] = true
			out.append("#%d %s (in #%d %s)" % [other, _world.get_brick(other).part_id, int(key),
				_world.get_brick(int(key)).part_id])
	return out


## A small linear actuator's input turned a whole turn over MCP (move_part
## degrees=360): its rod goes out the stroke over the turns builders counted
## (60 LDU over 19.9 turns for the small one: 3.02 LDU), and one undo puts it
## back.
func _input_turned(name: String, bodies: Bodies) -> void:
	var screw: Racks.Pinion = null
	for mesh: Racks.Pinion in bodies.racks():
		if mesh.screw:
			screw = mesh
			break
	if screw == null:
		print("    (no actuator here has its input as a part of its own: the input is not turned)")
		return
	var spec: Dictionary = (Mechanism.table()["actuators"] as Dictionary)[_world.get_brick(screw.body).part_id]
	var per_turn: float = absf(float(spec["to"]) - float(spec["from"])) / float(spec["turns"])
	var before: Dictionary = _snapshot()
	var rod_was: Transform3D = _world.get_brick(screw.rack).transform
	var body_was: Transform3D = _world.get_brick(screw.body).transform
	var said: String = _grab.for_session({"part": str(screw.gear), "degrees": 360.0})
	await _frames(3)
	var rod_now: Transform3D = _world.get_brick(screw.rack).transform
	var body_now: Transform3D = _world.get_brick(screw.body).transform
	# The rod's place against its body, before and after, along the actuator.
	var e: float = screw.line.dot(body_was.basis * (body_now.affine_inverse() * rod_now.origin
		- body_was.affine_inverse() * rod_was.origin))
	print("    move_part %s degrees=360: %s" % [screw.gear, said.replace("\n", " / ")])
	_check("%s: its input turned once over MCP, the rod goes %.3f LDU, the stroke over %.1f turns: %.3f" % [name,
		absf(e), float(spec["turns"]), per_turn], absf(absf(e) - per_turn) < 0.01)
	_builder.undo()
	await _frames(3)
	_check("%s: one undo puts the input and the rod back (%s)" % [name, _differs(before)],
		_differs(before) == "none differs")


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
	hand["floor"] = floor_y
	# Posed as it was let go: the arm where the drag left it, the rest where
	# it stood.
	var let_go: Dictionary = before.duplicate()
	for key: Variant in placed:
		let_go[key] = placed[key]
	await _fall_time_check("falling", let_go, hand)
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


## A made pendulum: a Technic beam 7 (32524) hanging on a pin without
## friction (3673) from the middle hole of a Technic brick 1x4 (3701) on a
## tower of twelve 2x4 bricks, the beam in front of the tower with nothing
## in its way. With [param wall], a column of ten 1x2 bricks stands in its
## swing on one side; with [param double], a second beam 7 hangs on a second
## free pin from the first one's foot. On no floor. LDraw's units, y down.
static func _pendulum_ldr(wall: bool, double: bool) -> String:
	var lines := PackedStringArray(["0 A beam on a free pin", "0 Name: made_pendulum.ldr",
		"0 !BRICKWORKS FLOOR NONE"])
	for k: int in range(1, 13):
		lines.append("1 4 0 %d -10 1 0 0 0 1 0 0 0 1 3001.dat" % (-24 * k))
	lines.append("1 7 0 -312 0 1 0 0 0 1 0 0 0 1 3701.dat")
	lines.append("1 0 0 -302 10 0 0 -1 0 1 0 1 0 0 3673.dat")
	lines.append("1 14 0 -242 20 -1 0 0 0 0 1 0 1 0 32524.dat")
	if double:
		lines.append("1 0 0 -182 30 0 0 -1 0 1 0 1 0 0 3673.dat")
		lines.append("1 1 0 -122 40 -1 0 0 0 0 1 0 1 0 32524.dat")
	if wall:
		for k: int in range(1, 11):
			lines.append("1 1 100 %d 20 1 0 0 0 1 0 0 0 1 3004.dat" % (-24 * k))
	return "\n".join(lines) + "\n"


## Look at the made pendulum from the side its beams hang on, a little above.
func _look_at_beams(bodies: Bodies, beam: int) -> void:
	var tower := Vector3.ZERO
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3701":
			tower = brick.transform.origin
	var key: int = int((bodies.members[beam] as PackedInt64Array)[0])
	for one: int in bodies.members[beam]:
		if _world.get_brick(one).part_id == "32524":
			key = one
	var side: Vector3 = _world.get_brick(key).transform.origin - tower
	side.y = 0.0
	_camera.look_from((side.normalized() + Vector3(0.1, 0.18, 0.0)).normalized())
	_frame_on(PackedInt64Array())
	await _frames(15)
	await _camera_still()


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## The free pins of the open model, outermost last: [link, child body].
func _free_pins(bodies: Bodies) -> Array:
	var out: Array = []
	for link: Bodies.Link in bodies.links:
		if link.kind != "pin" or link.holds:
			continue
		var child: int = link.b if bodies.parent_link.get(link.b) == link else link.a
		out.append([link, child])
	out.sort_custom(func(x: Array, y: Array) -> bool:
		return bodies.parts_of(bodies.beyond(int(x[1]))).size() > bodies.parts_of(bodies.beyond(int(y[1]))).size())
	return out


## Press on [param moving] and drag it [param degrees] about its joint in
## 5° frames, as a person does; the grab, or null. [param away_from], when
## given, picks the way that takes its centre of mass away from that point.
func _drag_out(moving: PackedInt64Array, bodies: Bodies, degrees: float,
		away_from: Variant = null) -> Grab:
	await _camera_still()
	var press: Dictionary = _press_point(moving, bodies)
	if press.is_empty():
		_check("the part to drag is under the pointer", false)
		return null
	var screen: Vector2 = press["screen"]
	await _move(screen, 0)
	await _button(screen, true)
	await _move(screen + Vector2(0, 7), MOUSE_BUTTON_MASK_LEFT)
	var grab: Grab = _grab.grab
	if grab == null or grab.state != "moves":
		_check("a drag on it turns it on its joint (%s; pressed #%d %s, carried %s)" % [_grab.last_words,
			int(press["brick"]), _world.get_brick(int(press["brick"])).part_id, _main.get("_dragging_part")], false)
		await _button(_last_screen, false)
		return null
	var way: float = 1.0
	if away_from != null:
		var plus: Vector3 = _centre_of(grab.transforms_at(20.0))
		var minus: Vector3 = _centre_of(grab.transforms_at(-20.0))
		if minus.distance_to(away_from) > plus.distance_to(away_from):
			way = -1.0
	var steps: int = maxi(1, ceili(absf(degrees) / 5.0))
	var hold: Vector3 = grab._hold
	for n: int in range(1, steps + 1):
		var turned: Vector3 = _about(grab.pivot, grab.axis, way * degrees * n / steps) * hold
		await _move(_camera.unproject_position(turned), MOUSE_BUTTON_MASK_LEFT)
	await create_timer(0.06).timeout
	await _move(_last_screen + Vector2(0.5, 0), MOUSE_BUTTON_MASK_LEFT)
	return grab


## A pendulum worked by hand from the parts [param grab] moves where they
## stand: each part's mass (Stability's), its middle, its box; the moment of
## inertia about the joint's line, Σ m (r² + (a² + b²)/12) for the box's two
## sides across it; the centre of mass's distance d from the line; the
## small-swing period 2π√(I/(m g d)); where it hangs; the friction's dead
## band asin(μ r/d) and the swing it loses each half, 2 μ r/d.
func _pendulum_by_hand(grab: Grab) -> Dictionary:
	var u: Vector3 = grab.axis.normalized()
	var p: Vector3 = grab.pivot
	var m: float = 0.0
	var inertia: float = 0.0
	var sum := Vector3.ZERO
	var said := PackedStringArray()
	for key: int in grab.moving:
		var brick: BrickWorld.Brick = _world.get_brick(key)
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		var g: float = Stability.grams(info)
		var at: Transform3D = grab.placed[key]
		var c: Vector3 = at * info.bounds.get_center()
		var off: Vector3 = (c - p) - u * (c - p).dot(u)
		# The box's own: its sides across the line, in its own frame.
		var local: Vector3 = at.basis.orthonormalized().inverse() * u
		var size: Vector3 = info.bounds.size
		var own: float = g / 12.0 * (local.x * local.x * (size.y * size.y + size.z * size.z)
			+ local.y * local.y * (size.x * size.x + size.z * size.z)
			+ local.z * local.z * (size.x * size.x + size.y * size.y))
		inertia += g * off.length_squared() + own
		m += g
		sum += c * g
		said.append("%s %.2f g at %.1f LDU (own %.0f)" % [brick.part_id, g, off.length(), own])
	var centre: Vector3 = sum / m
	var out: Vector3 = (centre - p) - u * (centre - p).dot(u)
	var d: float = out.length()
	var down: Vector3 = Vector3.DOWN - u * Vector3.DOWN.dot(u)
	var to_bottom: float = rad_to_deg(atan2(u.dot(out.cross(down)), out.dot(down)))
	var t0: float = TAU * sqrt(inertia / (m * Swing.GRAVITY * d))
	return {"m": m, "I": inertia, "d": d, "T0": t0, "to_bottom": to_bottom,
		"bottom": grab.angle + to_bottom, "dead": rad_to_deg(asin(Swing.MU * Swing.BEARING / d)),
		"loss": rad_to_deg(2.0 * Swing.MU * Swing.BEARING / d), "parts": ", ".join(said)}


## The complete elliptic integral of the first kind, K(k), by the
## arithmetic-geometric mean: a pendulum let go θ0 out swings with period
## 4 √(I/(m g d)) K(sin(θ0/2)).
static func _elliptic_k(k: float) -> float:
	var a: float = 1.0
	var b: float = sqrt(1.0 - k * k)
	for _n: int in 30:
		var next_a: float = (a + b) * 0.5
		b = sqrt(a * b)
		a = next_a
	return PI / (2.0 * a)


## Wait out a swing, drawing pictures every [param every] frames while it
## lasts (windowed): the angles drawn, frame by frame.
func _watch_swing(name: String, every: int, most: int) -> PackedFloat64Array:
	var angles := PackedFloat64Array()
	var shots: int = 0
	var frames: int = 0
	var swinging: Grab = _grab.get("_swinging")
	while _grab.is_swinging() and frames < 60000:
		if swinging != null:
			angles.append(swinging.angle)
		if _windowed and every > 0 and frames % every == 0 and shots < most:
			await _shot(name, "seq_%02d" % shots)
			shots += 1
		await process_frame
		frames += 1
	await _frames(3)
	return angles


## Swinging on release. The made pendulum dragged 10° out and let go swings
## as a pendulum: its period against 2π√(I/(m g d)) worked by hand from its
## parts; the swing it loses each half against the friction's 2μr/d; where
## it comes to rest against where statics hangs it (within its friction's
## dead band asin(μr/d)) and against the settle that came before; its energy
## never above where it was let go; one undo step. Then 75° out, pictures of
## the swing and its period against the elliptic integral. Then a column in
## its way: it stops dead where the room test says. Then over MCP.
func _swing_case() -> void:
	print("\nswinging: a beam 7 on a pin without friction, let go 30° out")
	var path: String = OUT.path_join("made_pendulum.ldr")
	_write(path, _pendulum_ldr(false, false))
	if not await _open(path):
		_check("swinging: the made pendulum opens", false)
		return
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	print("    %s" % bodies.summary())
	var pins: Array = _free_pins(bodies)
	_check("swinging: the beam hangs on a pin without friction (%d free)" % pins.size(), pins.size() == 1)
	if pins.is_empty():
		return
	var beam: int = int(pins[0][1])
	await _look_at_beams(bodies, beam)
	var before: Dictionary = _snapshot()
	var depth: int = _builder.history_depth()
	var grab: Grab = await _drag_out(bodies.members[beam], bodies, 30.0)
	if grab == null:
		return
	var hand: Dictionary = _pendulum_by_hand(grab)
	var amplitude: float = absf(float(hand["to_bottom"]))
	print("    by hand: %s; m %.3f g, d %.2f LDU, I %.1f g·LDU²: T0 = 2π√(I/(m g d)) = %.4f s"
		% [hand["parts"], hand["m"], hand["d"], hand["I"], hand["T0"]])
	print("    let go %.2f° from hanging (%.2f°); dead band asin(μr/d) = %.2f°, loss 2μr/d = %.3f° a half swing"
		% [amplitude, hand["bottom"], hand["dead"], hand["loss"]])
	# Where the settle that came before leaves it, from the same pose.
	var trial := Grab.new()
	trial.world = _world
	trial.builder = _builder
	trial.library = _library
	trial.bodies = bodies
	trial.begin(int((bodies.members[beam] as PackedInt64Array)[0]), grab._hold)
	trial.turn_to(grab.angle)
	trial._settle_joint()
	var statics: float = trial.angle
	await _button(_last_screen, false)
	_check("swinging: let go, it swings (%s)" % _grab.last_words, _grab.is_swinging())
	var drawn: PackedFloat64Array = await _watch_swing("swing_small", 0, 0)
	var swing: Swing = _grab.last_swing
	if swing == null:
		_check("swinging: a swing ran", false)
		return
	var halves: PackedFloat64Array = swing.half_periods()
	# The ends of its swings, as distances from hanging.
	var q_bottom: float = deg_to_rad(float(hand["to_bottom"]))
	var ends := PackedFloat64Array([absf(q_bottom)])
	for turn: Array in swing.turns:
		ends.append(absf(float(turn[1]) - q_bottom))
	# Each half swing against the period by hand at its mean amplitude: the
	# small-swing 2π√(I/(m g d)), lengthened by the elliptic integral,
	# 2K(sin(θ/2))/π, which is 1 + θ²/16 for small θ.
	var counted: int = 0
	var off_most: float = 0.0
	var mean_half: float = 0.0
	var mean_expect: float = 0.0
	for n: int in halves.size():
		if n + 2 >= ends.size():
			break
		var a: float = (ends[n + 1] + ends[n + 2]) * 0.5
		var expect_half: float = float(hand["T0"]) / PI * _elliptic_k(sin(a * 0.5))
		off_most = maxf(off_most, absf(halves[n] - expect_half) / expect_half)
		mean_half += halves[n]
		mean_expect += expect_half
		counted += 1
	print("    swung %.2f s simulated, %.2f s on the clock, %d frames drawn; %d half swings, ends %s°"
		% [swing.time, _grab.swing_clock_s, drawn.size(), halves.size(),
		", ".join(Array(ends).map(func(e: float) -> String: return "%.2f" % rad_to_deg(e)))])
	_check(("swinging: its period %.4f s over %d half swings against T0 = 2π√(I/(m g d)) = %.4f s by hand, "
		+ "lengthened for each swing's amplitude to %.4f s: %.2f%% off, the worst half %.2f%%") % [
		2.0 * mean_half / maxi(counted, 1), counted, hand["T0"], 2.0 * mean_expect / maxi(counted, 1),
		100.0 * absf(mean_half - mean_expect) / maxf(mean_expect, 1e-9), 100.0 * off_most],
		counted >= 3 and absf(mean_half - mean_expect) / maxf(mean_expect, 1e-9) < 0.01 and off_most < 0.03)
	var losses: float = 0.0
	var lost_n: int = mini(ends.size() - 1, 6)
	for n: int in lost_n:
		losses += rad_to_deg(ends[n] - ends[n + 1]) / lost_n
	_check("swinging: it loses %.3f° a half swing to the pin's friction; 2μr/d by hand %.3f°" % [losses,
		hand["loss"]], lost_n >= 3 and absf(losses - float(hand["loss"])) / float(hand["loss"]) < 0.1)
	var end: float = grab.angle
	_check("swinging: it comes to rest at %.2f°, %.2f° from hanging straight (%.2f°), within its friction's dead band %.2f°"
		% [end, absf(end - float(hand["bottom"])), hand["bottom"], hand["dead"]],
		absf(end - float(hand["bottom"])) <= float(hand["dead"]) + 0.05)
	_check("swinging: where the settle before it put it (%.2f°), to within that band" % statics,
		absf(end - statics) <= float(hand["dead"]) + 0.5)
	_check("swinging: its energy never stood above where it was let go (%.4f%% of what it lost)"
		% (100.0 * swing.energy_rise_share()), swing.energy_rise_share() < 0.01)
	print("    said: %s" % _grab.last_words)
	_check("swinging: it says it swung and where it came to rest", _grab.last_words.contains("back and forth")
		and _grab.last_words.contains("came to rest at"))
	_check("swinging: the drag and the swing are one step to undo (%s)" % (_builder.history_words(1)[0]
		if _builder.history_depth() > depth else "none"), _builder.history_depth() == depth + 1)
	_timings["swing_small"] = {"frames": _grab.swing_frames, "worst_ms": _grab.swing_worst_ms,
		"mean_ms": _grab.swing_mean_ms, "simulated_s": swing.time, "clock_s": _grab.swing_clock_s,
		"tests": swing.tests, "worst_test_ms": swing.worst_test_ms}
	_check("swinging: its frames' own work mean %.2f ms, worst %.2f ms (%d frames, %d room tests, the worst %.2f ms)"
		% [_grab.swing_mean_ms, _grab.swing_worst_ms, _grab.swing_frames, swing.tests, swing.worst_test_ms],
		_grab.swing_worst_ms < 33.0)
	_builder.undo()
	await _frames(3)
	_check("swinging: one undo puts it back exactly (%s)" % _differs(before), _differs(before) == "none differs")

	# 75° out: pictures of the swing, and its first swings' period against
	# the elliptic integral.
	print("\nswinging: let go 75° out, pictures")
	_grab._ready_now()
	bodies = _grab._bodies
	grab = await _drag_out(bodies.members[int(_free_pins(bodies)[0][1])], bodies, 75.0)
	if grab == null:
		return
	hand = _pendulum_by_hand(grab)
	amplitude = absf(float(hand["to_bottom"]))
	if _windowed:
		await _shot("swing_big", "0_held")
	await _button(_last_screen, false)
	drawn = await _watch_swing("swing_big", 4, 12)
	swing = _grab.last_swing
	halves = swing.half_periods()
	var first: float = halves[0] if not halves.is_empty() else 0.0
	# The first half swing goes from θ0 out to a little less the other side:
	# its half period by the mean of the two.
	var other: float = absf(float(swing.turns[0][1]) - deg_to_rad(float(hand["to_bottom"]))) \
		if not swing.turns.is_empty() else 0.0
	var mean_amp: float = (deg_to_rad(amplitude) + other) * 0.5
	var big: float = 2.0 * sqrt(float(hand["I"]) / (float(hand["m"]) * Swing.GRAVITY * float(hand["d"]))) \
		* _elliptic_k(sin(mean_amp * 0.5))
	_check("swinging: the first half swing from %.1f° takes %.4f s; 2√(I/(m g d))·K(sin(θ/2)) by hand %.4f s, %.2f%% off"
		% [amplitude, first, big, 100.0 * absf(first - big) / maxf(big, 1e-6)], absf(first - big) / maxf(big, 1e-6) < 0.02)
	print("    said: %s" % _grab.last_words)
	_check("swinging: from 75° it comes to rest within its dead band of hanging (%.2f° off, band %.2f°)"
		% [absf(grab.angle - float(hand["bottom"])), hand["dead"]],
		absf(grab.angle - float(hand["bottom"])) <= float(hand["dead"]) + 0.05)
	_timings["swing_big"] = {"frames": _grab.swing_frames, "worst_ms": _grab.swing_worst_ms,
		"mean_ms": _grab.swing_mean_ms, "simulated_s": swing.time, "clock_s": _grab.swing_clock_s,
		"tests": swing.tests}
	print("    frames: own work mean %.2f ms, worst %.2f ms over %d; %.2f s simulated in %.2f s on the clock"
		% [_grab.swing_mean_ms, _grab.swing_worst_ms, _grab.swing_frames, swing.time, _grab.swing_clock_s])
	if _windowed:
		await _shot("swing_big", "9_rest")
	_builder.undo()
	await _frames(3)

	# Caught by a press half way.
	grab = await _drag_out(bodies.members[int(_free_pins(bodies)[0][1])], bodies, 60.0)
	if grab != null:
		depth = _builder.history_depth()
		await _button(_last_screen, false)
		await create_timer(0.15).timeout
		var caught_at: float = (_grab.get("_swinging") as Grab).angle if _grab.is_swinging() else NAN
		await _button(_last_screen, true)
		await _button(_last_screen, false)
		await _frames(3)
		print("    caught: %s" % _grab.last_words)
		_check("swinging: a press caught it where it was (%.1f°), kept as one step" % caught_at,
			not _grab.is_swinging() and _grab.last_words.contains("caught by a press")
			and _builder.history_depth() == depth + 1)
		while _builder.history_depth() > depth:
			_builder.undo()
		await _frames(3)

	# Over MCP: move_part says it swung and where it rests.
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var key: int = int((bodies.members[int(_free_pins(bodies)[0][1])] as PackedInt64Array)[0])
	depth = _builder.history_depth()
	var said: String = str(await tools.run("move_part", {"part": "#%d" % key, "degrees": 40}))
	print("    move_part #%d degrees=40 said: %s" % [key, said.replace("\n", " | ")])
	_check("swinging: over MCP move_part says it swung and where it came to rest",
		said.contains("swung down under its own weight") and said.contains("came to rest at"))
	_check("swinging: over MCP one step", _builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(3)
	_check("swinging: over MCP one undo puts it back exactly (%s)" % _differs(before), _differs(before) == "none differs")

	# A column in its way: it stops dead where the room test says.
	print("\nswinging: a column of bricks in its swing")
	path = OUT.path_join("made_pendulum_wall.ldr")
	_write(path, _pendulum_ldr(true, false))
	if not await _open(path):
		return
	_grab._ready_now()
	bodies = _grab._bodies
	beam = int(_free_pins(bodies)[0][1])
	var column := Vector3.ZERO
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3004":
			column = brick.transform.origin
	await _look_at_beams(bodies, beam)
	# Where a turn towards the column stops, the room test's, in 2° frames
	# from hanging as a drag would.
	var probe := Grab.new()
	probe.world = _world
	probe.builder = _builder
	probe.library = _library
	probe.bodies = bodies
	var beam_key: int = int((bodies.members[beam] as PackedInt64Array)[0])
	probe.begin(beam_key, _world.get_brick(beam_key).transform.origin)
	var toward: float = 1.0 if _centre_of(probe.transforms_at(20.0)).distance_to(column) \
		< _centre_of(probe.transforms_at(-20.0)).distance_to(column) else -1.0
	var wall_at: float = NAN
	for n: int in range(1, 70):
		probe.turn_to(toward * 2.0 * n)
		if probe.stopped:
			wall_at = probe.angle
			break
	print("    a turn towards the column stops at %.2f°" % wall_at)
	depth = _builder.history_depth()
	before = _snapshot()
	grab = await _drag_out(bodies.members[beam], bodies, 60.0, column)
	if grab == null:
		return
	var let_go: float = grab.angle
	await _button(_last_screen, false)
	drawn = await _watch_swing("swing_wall", 3, 8)
	swing = _grab.last_swing
	var first_end: float = let_go + rad_to_deg(float(swing.turns[0][1])) if not swing.turns.is_empty() else NAN
	print("    said: %s" % _grab.last_words)
	_check("swinging: it stops dead at the column, its first swing ending at %.2f°, where the room test stops a turn (%.2f°)"
		% [first_end, wall_at], swing.stops >= 1 and absf(first_end - wall_at) <= 0.5)
	_check("swinging: it says it met the model", _grab.last_words.contains("met the model"))
	_builder.undo()
	await _frames(3)
	_check("swinging: one undo puts it back exactly (%s)" % _differs(before), _differs(before) == "none differs")


## Two beams on two free pins, the inner one dragged 60° out and let go:
## they swing together as a double pendulum, its energy never above where
## it was let go, and come to rest where the settle before it put them (each
## hanging straight within its friction's band), as one step.
func _double_case() -> void:
	print("\ndouble pendulum: two beams 7 on two pins without friction, the inner one let go 60° out")
	var path: String = OUT.path_join("made_double.ldr")
	_write(path, _pendulum_ldr(false, true))
	if not await _open(path):
		_check("double pendulum: the model opens", false)
		return
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	var pins: Array = _free_pins(bodies)
	_check("double pendulum: two pins without friction (%d)" % pins.size(), pins.size() == 2)
	if pins.size() < 2:
		return
	var inner: int = int(pins[0][1])
	await _look_at_beams(bodies, inner)
	var before: Dictionary = _snapshot()
	var depth: int = _builder.history_depth()
	var outer_key: int = int((bodies.members[int(pins[1][1])] as PackedInt64Array)[0])
	# Press on the inner beam itself, not the outer.
	var grab: Grab = await _drag_out(bodies.members[inner], bodies, 60.0)
	if grab == null:
		return
	var trial := Grab.new()
	trial.world = _world
	trial.builder = _builder
	trial.library = _library
	trial.bodies = bodies
	trial.begin(int((bodies.members[inner] as PackedInt64Array)[0]), grab._hold)
	trial.turn_to(grab.angle)
	trial.settle()
	var static_outer: Vector3 = (trial.placed[outer_key] as Transform3D).origin
	var static_inner: float = trial.angle
	if _windowed:
		await _shot("double", "0_held")
	await _button(_last_screen, false)
	var drawn: PackedFloat64Array = await _watch_swing("double", 3, 14)
	var swing: Swing = _grab.last_swing
	print("    said: %s" % _grab.last_words)
	_check("double pendulum: both joints swing together (%d joints)" % (swing.joints.size() if swing else 0),
		swing != null and swing.joints.size() == 2)
	if swing == null:
		return
	var outer_now: Vector3 = _world.get_brick(outer_key).transform.origin
	# Each pin holds within asin(μr/d) of hanging, d the centre of mass of what
	# it carries from its line (about 120 and 60 LDU here): 0.9° and 1.7°,
	# at 180 and 60 LDU from the outer beam's middle, 2.7 and 1.8 LDU.
	var band: float = 8.0
	_check("double pendulum: the outer beam comes to rest %.2f LDU from where the settle before it hangs it (inner %.2f° against %.2f°)"
		% [outer_now.distance_to(static_outer), grab.angle, static_inner], outer_now.distance_to(static_outer) <= band)
	_check("double pendulum: its energy never stood above where it was let go (%.4f%% of what it lost)"
		% (100.0 * swing.energy_rise_share()), swing.energy_rise_share() < 0.01)
	_check("double pendulum: it says a chain swung", _grab.last_words.contains("chain of 2 free joints"))
	_check("double pendulum: one step to undo (%s)" % (_builder.history_words(1)[0]
		if _builder.history_depth() > depth else "none"), _builder.history_depth() == depth + 1)
	_timings["double"] = {"frames": _grab.swing_frames, "worst_ms": _grab.swing_worst_ms,
		"mean_ms": _grab.swing_mean_ms, "simulated_s": swing.time, "clock_s": _grab.swing_clock_s,
		"tests": swing.tests, "worst_test_ms": swing.worst_test_ms}
	_check("double pendulum: its frames' own work mean %.2f ms, worst %.2f ms (%d frames; %.2f s simulated, %.2f on the clock)"
		% [_grab.swing_mean_ms, _grab.swing_worst_ms, _grab.swing_frames, swing.time, _grab.swing_clock_s],
		_grab.swing_worst_ms < 33.0)
	if _windowed:
		await _shot("double", "9_rest")
	_builder.undo()
	await _frames(3)
	_check("double pendulum: one undo puts it back exactly (%s)" % _differs(before), _differs(before) == "none differs")


## How long a rigid model posed as [param placed] takes to fall about the
## edge [param hand] found (_fall_by_hand: its point and line, the angle it
## falls), worked by hand: its moment of inertia about the edge from each
## part's mass and box, Σ m (r² + its box's own about the line); its centre
## of mass r from the edge, φ0 past upright; from rest, energy gives
## θ'² = 2 m g r (cos φ0 − cos(φ0 + θ)) / I, and the time is the integral of
## dθ/θ' to the angle it falls (by Simpson's rule, θ = s² taking out the
## start's 1/√θ).
func _fall_time_by_hand(placed: Dictionary, hand: Dictionary) -> Dictionary:
	var a: Vector3 = hand["point"]
	var u: Vector3 = (hand["line"] as Vector3).normalized()
	var out: Vector3 = hand["out"]
	var m: float = 0.0
	var inertia: float = 0.0
	var sum := Vector3.ZERO
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		if info == null:
			continue
		var g: float = Stability.grams(info)
		var at: Transform3D = placed.get(brick.id, brick.transform)
		var c: Vector3 = at * info.bounds.get_center()
		var local: Vector3 = at.basis.orthonormalized().inverse() * u
		var size: Vector3 = info.bounds.size
		var own: float = g / 12.0 * (local.x * local.x * (size.y * size.y + size.z * size.z)
			+ local.y * local.y * (size.x * size.x + size.z * size.z)
			+ local.z * local.z * (size.x * size.x + size.y * size.y))
		var r: Vector3 = (c - a) - u * (c - a).dot(u)
		inertia += g * r.length_squared() + own
		m += g
		sum += c * g
	var w: Vector3 = (sum / m - a)
	w -= u * w.dot(u)
	var r: float = w.length()
	var phi0: float = atan2(w.dot(out), w.y)
	var fall: float = deg_to_rad(float(hand["angle"]))
	var k: float = 2.0 * m * Swing.GRAVITY * r / inertia
	var top: float = sqrt(fall)
	var n: int = 2000
	var total: float = 0.0
	for i: int in n + 1:
		var s: float = top * i / n
		var f: float
		if i == 0:
			f = 2.0 / sqrt(k * sin(phi0))
		else:
			f = 2.0 * s / sqrt(k * (cos(phi0) - cos(phi0 + s * s)))
		total += f * (1.0 if i == 0 or i == n else (4.0 if i % 2 == 1 else 2.0))
	return {"seconds": total * top / n / 3.0, "m": m, "I": inertia, "r": r, "phi0": rad_to_deg(phi0)}


## The fall just shown against the hand: its simulated time (Topple.timed)
## against the integral, its drawn frames never through the floor, and the
## clock it took: checked when [param pictured] is false (a picture taken
## during the fall holds its frames, and the last frame ends it late).
func _fall_time_check(name: String, placed: Dictionary, hand: Dictionary, pictured: bool = false) -> void:
	var by_hand: Dictionary = _fall_time_by_hand(placed, hand)
	print("    by hand: m %.2f g, its centre of mass %.1f LDU from the edge and %.2f° past upright, I about the edge %.0f g·LDU²: falls %.2f° in %.4f s"
		% [by_hand["m"], by_hand["r"], by_hand["phi0"], by_hand["I"], hand["angle"], by_hand["seconds"]])
	var off: float = absf(_grab.fall_seconds - float(by_hand["seconds"])) / float(by_hand["seconds"])
	_check("%s: it falls in %.4f s, a rigid body turning about its edge from rest; the integral by hand %.4f s, %.2f%% off"
		% [name, _grab.fall_seconds, by_hand["seconds"], 100.0 * off], off < 0.02)
	if pictured:
		print("    drawn falling over %.3f s on the clock (%.3f s simulated), with pictures taken during it"
			% [_grab.fall_clock_s, _grab.fall_seconds])
	else:
		_check("%s: drawn falling over %.3f s on the clock (%.3f s simulated), not a fixed half second"
			% [name, _grab.fall_clock_s, _grab.fall_seconds], absf(_grab.fall_clock_s - _grab.fall_seconds) < 0.1)
	var floor_y: float = float(hand.get("floor", _lowest()))
	_check("%s: no frame of it went through the floor (lowest corner drawn %.2f LDU from it)"
		% [name, _grab.fall_lowest - floor_y], _grab.fall_lowest >= floor_y - 1.0)


## The made crane, its arm two bricks longer, on a tower one brick taller, its fourth course two
## Technic bricks 1 x 2 with holes (3700) turned across, and from the outer
## hole a short beam (32523, a beam 3) on a pin without friction, beside the
## tower: the arm on its hinge holds, the beam swings. The tower is the
## heavier body and stays. LDraw's units, y down.
const MADE_CRANE_SWING := """0 A tall arm on a hinge on a 2x2 tower, a beam hung at its side
0 Name: made_crane_swing.ldr
0 !BRICKWORKS FLOOR NONE
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat
1 4 0 -72 0 1 0 0 0 1 0 0 0 1 3003.dat
1 7 -10 -96 0 0 0 1 0 1 0 -1 0 0 3700.dat
1 7 10 -96 0 0 0 1 0 1 0 -1 0 0 3700.dat
1 4 0 -120 0 1 0 0 0 1 0 0 0 1 3003.dat
1 71 0 -144 10 1 0 0 0 1 0 0 0 1 3937.dat
1 14 0 -144 10 1 0 0 0 1 0 0 0 1 3938.dat
1 1 0 -168 10 1 0 0 0 1 0 0 0 1 3004.dat
1 1 0 -192 10 1 0 0 0 1 0 0 0 1 3004.dat
1 1 0 -216 10 1 0 0 0 1 0 0 0 1 3004.dat
1 1 0 -240 10 1 0 0 0 1 0 0 0 1 3004.dat
1 1 0 -264 10 1 0 0 0 1 0 0 0 1 3004.dat
1 1 0 -288 10 1 0 0 0 1 0 0 0 1 3004.dat
1 1 0 -312 10 1 0 0 0 1 0 0 0 1 3004.dat
1 0 -20 -86 0 1 0 0 0 1 0 0 0 1 3673.dat
1 14 -30 -66 0 0 1 0 0 0 1 1 0 0 32523.dat
"""


## Falling with motion and landing: the made crane with a beam hung at its
## arm's top, the arm dragged out 90° on its hinge (which holds) and let go.
## Past its edge, the model falls at once about it as a body falls (its time
## against the integral by hand), the beam held as it falls; it lands where
## Topple says; and the beam, carried round by the fall, swings on in its new
## lie until it hangs within its friction of straight down. One step to undo.
func _landing_case() -> void:
	print("\nfalling and landing: the made crane with a beam 3 on a free pin at its tower's side, on no floor")
	var path: String = OUT.path_join("made_crane_swing.ldr")
	_write(path, MADE_CRANE_SWING)
	if not await _open(path):
		_check("landing: the model opens", false)
		return
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	print("    %s" % bodies.summary())
	var hinge: Bodies.Link = null
	for link: Bodies.Link in bodies.links:
		if link.kind == "hinge":
			hinge = link
	var pins: Array = _free_pins(bodies)
	_check("landing: an arm on a hinge, a beam on a free pin at the tower's side (%d free)" % pins.size(),
		hinge != null and pins.size() == 1)
	if hinge == null or pins.is_empty():
		return
	var arm: int = hinge.b if bodies.parent_link.get(hinge.b) == hinge else hinge.a
	var beam_key: int = 0
	for key: int in bodies.members[int(pins[0][1])]:
		if _world.get_brick(key).part_id == "32523":
			beam_key = key
	var base_key: int = int((bodies.members[int(bodies.anchors.keys()[0])] as PackedInt64Array)[0])
	var floor_y: float = _lowest()
	_camera.look_from(Vector3(-1.0, 0.4, 0.3).normalized())
	_frame_on(PackedInt64Array())
	await _frames(15)
	await _camera_still()
	var before: Dictionary = _snapshot()
	var depth: int = _builder.history_depth()
	# Out the way that carries the weight past the tower's edge.
	var probe := Grab.new()
	probe.world = _world
	probe.builder = _builder
	probe.library = _library
	probe.bodies = bodies
	var arm_key: int = int((bodies.members[arm] as PackedInt64Array)[0])
	probe.begin(arm_key, _world.get_brick(arm_key).transform.origin)
	var base_centre: Vector3 = _centre_of({})
	var plus: Vector3 = _centre_of(probe.transforms_at(60.0))
	var minus: Vector3 = _centre_of(probe.transforms_at(-60.0))
	var away: Vector3 = base_centre + (plus - base_centre if Vector2(plus.x - base_centre.x, plus.z - base_centre.z).length()
		< Vector2(minus.x - base_centre.x, minus.z - base_centre.z).length() else minus - base_centre) * 10.0
	# _drag_out picks the way taking it away from a point: the point behind.
	var behind: Vector3 = base_centre - (away - base_centre)
	var grab: Grab = await _drag_out(bodies.members[arm], bodies, 90.0, behind)
	if grab == null:
		return
	print("    posed to %.1f°" % grab.angle)
	if _windowed:
		await _shot("landing", "00_held")
	await _button(_last_screen, false)
	var swung_first: bool = _grab.is_swinging()
	var shots: int = 0
	var frames: int = 0
	var fall_from: Dictionary = {}
	var fell_seen: bool = false
	var landed_swing: bool = false
	var started: int = Time.get_ticks_msec()
	while (_grab.is_settling()) and Time.get_ticks_msec() - started < 60000:
		if _grab.is_falling() and not fell_seen:
			fell_seen = true
			fall_from = (_grab.get("_falling") as Dictionary)["from"]
		if fell_seen and not _grab.is_falling() and _grab.is_swinging():
			landed_swing = true
		if _windowed and frames % 3 == 0 and shots < 30:
			await _shot("landing", "seq_%02d" % shots)
			shots += 1
		await process_frame
		frames += 1
	await _frames(3)
	print("    said: %s" % _grab.last_words)
	_check("landing: let go past its edge on a hinge that holds, it falls at once, the beam held as it falls",
		not swung_first and fell_seen and _grab.last_words.contains("tipped over to the"))
	if fell_seen:
		var hand: Dictionary = _fall_by_hand(fall_from)
		hand["floor"] = floor_y
		print("    by hand: past the %s edge by %.1f LDU; first down %s, %.1f out and %.1f up: %.2f°"
			% [hand["edge"], hand["past"], hand["corner"], hand["u"], hand["h"], hand["angle"]])
		var up_before: Vector3 = (fall_from[base_key] as Transform3D).basis.y.normalized()
		var up_after: Vector3 = _world.get_brick(base_key).transform.basis.y.normalized()
		var fell: float = rad_to_deg(up_before.angle_to(up_after))
		_check("landing: it turned %.2f° about its edge, where the hand puts it down (%.2f°)" % [fell, hand["angle"]],
			absf(fell - float(hand["angle"])) < 1.5)
		await _fall_time_check("landing", fall_from, hand, _windowed)
	_check("landing: as it landed the beam swung on in its new lie, and it says so", landed_swing
		and _grab.last_words.contains("as it landed"))
	# The beam hangs: its centre of mass under its pin, within its friction.
	var beam: BrickWorld.Brick = _world.get_brick(beam_key)
	var info: PartLibrary.PartInfo = _library.parts.get(beam.part_id)
	_grab._ready_now()
	var lying: Array = _free_pins(_grab._bodies)
	var pin_link: Bodies.Link = lying[0][0] if not lying.is_empty() else hinge
	var pin_point: Vector3 = pin_link.point
	var pin_axis: Vector3 = pin_link.axis.normalized()
	var hang: Vector3 = beam.transform * info.bounds.get_center() - pin_point
	hang -= pin_axis * hang.dot(pin_axis)
	var down: Vector3 = Vector3.DOWN - pin_axis * Vector3.DOWN.dot(pin_axis)
	var off: float = rad_to_deg(hang.angle_to(down))
	var dead: float = rad_to_deg(asin(Swing.MU * Swing.BEARING / maxf(hang.length(), 1.0)))
	_check("landing: the beam hangs %.2f° from straight down below its pin, within its friction's band (%.2f°)"
		% [off, dead], off <= dead + 0.5)
	_check("landing: it lies on the floor it stood on (lowest point %.1f LDU, the floor %.1f)" % [_lowest(), floor_y],
		absf(_lowest() - floor_y) <= 2.0)
	_check("landing: the drag, the swing, the fall and the landing are one step to undo (%s)" % (
		_builder.history_words(1)[0] if _builder.history_depth() > depth else "none"),
		_builder.history_depth() == depth + 1)
	_timings["landing"] = {"fall_s": _grab.fall_seconds, "fall_clock_s": _grab.fall_clock_s,
		"swing_frames": _grab.swing_frames, "swing_worst_ms": _grab.swing_worst_ms,
		"swing_mean_ms": _grab.swing_mean_ms}
	if _windowed:
		_frame_on(PackedInt64Array())
		await _frames(10)
		await _shot("landing", "99_rest")
	_builder.undo()
	await _frames(3)
	_check("landing: one undo stands it up again exactly (%s)" % _differs(before), _differs(before) == "none differs")
	# Over MCP: the same turn, the same story in words.
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	depth = _builder.history_depth()
	var said: String = str(await tools.run("move_part", {"part": "#%d" % arm_key, "degrees": grab.angle}))
	print("    move_part #%d degrees=%.0f said: %s" % [arm_key, grab.angle, said.replace("\n", " | ")])
	_check("landing: over MCP it says the model fell and for how long, and the beam swung as it landed",
		said.contains("falling for") and said.contains("As it landed") and said.contains("swung down"))
	_check("landing: over MCP one step", _builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(3)
	_check("landing: over MCP one undo puts it back exactly (%s)" % _differs(before), _differs(before) == "none differs")


# -- flick to spin, and coast ----------------------------------------------------------

## A flywheel made here: a Technic gear 40 (3649) on an axle 4 (3705) in a
## Technic brick 1 x 6 with holes (3894) on a tower of three bricks 1 x 6.
## [constant MADE_TRAIN_GEAR] adds an 8 tooth gear (3647) on a second axle
## three holes along, meshing with the 40: a train that turns the 8 five
## times as fast. LDraw's units, y down.
const MADE_FLYWHEEL := """0 A flywheel: a gear 40 on an axle
0 Name: made_flywheel.ldr
0 !BRICKWORKS FLOOR NONE
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3009.dat
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3009.dat
1 4 0 -72 0 1 0 0 0 1 0 0 0 1 3009.dat
1 7 0 -96 0 1 0 0 0 1 0 0 0 1 3894.dat
1 0 -40 -86 0 0 0 -1 0 1 0 1 0 0 3705.dat
1 7 -40 -86 -20 1 0 0 0 1 0 0 0 1 3649.dat
"""
const MADE_TRAIN_GEAR := """1 0 20 -86 0 0 0 -1 0 1 0 1 0 0 3705.dat
1 7 20 -86 -20 1 0 0 0 1 0 0 0 1 3647.dat
"""
## How fast the pointer turns the flywheel before it lets go, degrees a
## second (three turns a second), and for how long, s.
const FLICK_RATE := 1080.0
const FLICK_S := 0.3


## Flick to spin, and coast: the made flywheel taken by its rim and turned
## by the pointer at a steady rate by the clock, let go while it turns. It
## carries on at the pointer's rate, slows against its bearing's friction
## and stops where the parts say by hand; then the same with a gear 8 it
## drives five times as fast, whose inertia counts 25 times and its
## bearing's friction 5 times, so the train coasts less far, as worked by
## hand from the teeth; a picture mid-coast; over MCP (move_part spin=); a
## hinge, which holds by friction, flicked the same way stays where it is
## let go.
func _coast_case() -> void:
	for train: bool in [false, true]:
		var name: String = "coast: %s" % ("a gear 40 driving a gear 8" if train else "a flywheel")
		print("\n%s" % name)
		var path: String = OUT.path_join("made_%s.ldr" % ("train" if train else "flywheel"))
		_write(path, MADE_FLYWHEEL + (MADE_TRAIN_GEAR if train else ""))
		if not await _open(path):
			_check("%s: the made model opens" % name, false)
			continue
		_grab._ready_now()
		var bodies: Bodies = _grab._bodies
		var big: int = 0
		var small: int = 0
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id == "3649":
				big = brick.id
			elif brick.part_id == "3647":
				small = brick.id
		var wheel: int = int(bodies.body_of[big])
		var link: Bodies.Link = bodies.parent_link.get(wheel)
		print("    %s; the 40's joint: %s" % [bodies.summary(), "none" if link == null else "%s, %s" % [link.kind,
			"holds" if link.holds else "turns freely"]])
		if link == null:
			_check("%s: the 40 turns on a joint" % name, false)
			continue
		# From the side the gears are on (LDraw's -z is the view's +z).
		_camera.look_from(Vector3(0.15, 0.25, 1.0).normalized())
		_frame_on(PackedInt64Array())
		await _frames(15)
		await _camera_still()
		var before: Dictionary = _snapshot()
		var depth: int = _builder.history_depth()
		var flick: Array = await _flick(bodies.members[wheel], bodies, FLICK_RATE, FLICK_S, name)
		var grab: Grab = flick[0]
		if grab == null:
			continue
		var swinging: Grab = _grab.get("_swinging")
		var swing: Swing = swinging.swing if swinging != null else null
		# Within 15%: the pointer's rate is the probe's, by when it asked for
		# each move; the app reads each move a frame later, when it comes, and
		# on a loaded box one frame late in the last tenth of a second moved
		# the reading 11% (1,195° a second). On a quiet box it reads to 1%.
		_check("%s: let go while it turns, it carries on at the pointer's speed: %.0f° a second against the pointer's %.0f"
			% [name, absf(rad_to_deg(swing.flung)) if swing != null else 0.0, float(flick[1])], swing != null
			and absf(absf(rad_to_deg(swing.flung)) - float(flick[1])) <= float(flick[1]) * 0.15)
		if swing == null:
			await _settled()
			continue
		# Mid-coast: the status line says it, and a picture.
		var said_mid: String = ""
		var shot: bool = false
		var waited: int = Time.get_ticks_msec()
		while _grab.is_swinging() and Time.get_ticks_msec() - waited < 60000:
			if not shot and swing.time > 0.12:
				shot = true
				said_mid = str(_grab.get("_said"))
				if _windowed:
					await _clean_shot("coast " + ("train" if train else "flywheel"), "2_mid")
			await process_frame
		await _settled()
		print("    mid-coast the status line said: %s" % said_mid)
		_check("%s: while it coasts the status line says so: %s" % [name, said_mid], said_mid.contains("coasting at"))
		# By hand from the parts and the teeth.
		var turning: Array = [[bodies.parts_of([wheel]), link.point, link.axis.normalized(), 1.0]]
		if train:
			var other: int = int(bodies.body_of[small])
			var teeth_big: float = float(Mechanism.spec_of("3649")["teeth"])
			var teeth_small: float = float(Mechanism.spec_of("3647")["teeth"])
			var other_link: Bodies.Link = bodies.parent_link.get(other)
			turning.append([bodies.parts_of([other]), other_link.point, other_link.axis.normalized(),
				teeth_big / teeth_small])
		var hand: Dictionary = _coast_by_hand(turning, absf(swing.flung))
		print("    by hand: I %.0f g·LDU² (the 40's %.0f), friction %.0f g·LDU²/s², %.2f rad/s² against it: from %.2f rad/s it coasts %.4f turns in %.4f s"
			% [hand["I"], hand["I_first"], hand["friction"], hand["alpha"], absf(swing.flung), hand["turns"], hand["seconds"]])
		var coasted: float = swing.travel / TAU
		var took: float = swing.time - Swing.STILL_S
		print("    it coasted %.4f turns in %.4f s; %s" % [coasted, took, _grab.last_words])
		_check("%s: it coasts %.3f turns, by hand %.3f (ω² / 2α, α its bearings' friction over its inertia%s)"
			% [name, coasted, float(hand["turns"]), ", the 8's counted at 5 and 25 times" if train else ""],
			absf(coasted - float(hand["turns"])) <= float(hand["turns"]) * 0.01)
		_check("%s: and stops after %.3f s, by hand %.3f (ω / α)" % [name, took, float(hand["seconds"])],
			absf(took - float(hand["seconds"])) <= float(hand["seconds"]) * 0.02 + 0.002)
		_timings[name] = {"flung_deg_s": rad_to_deg(swing.flung), "coast_turns": coasted, "by_hand_turns": hand["turns"],
			"coast_s": took, "by_hand_s": hand["seconds"], "swing_frames": _grab.swing_frames,
			"swing_mean_ms": _grab.swing_mean_ms, "swing_worst_ms": _grab.swing_worst_ms,
			"clock_s": _grab.swing_clock_s}
		_check("%s: its own work a coasting frame, mean %.2f ms, worst %.2f, within a 33 ms frame" % [name,
			_grab.swing_mean_ms, _grab.swing_worst_ms], _grab.swing_frames > 0 and _grab.swing_mean_ms <= 33.0
			and _grab.swing_worst_ms <= 33.0)
		_check("%s: let go, it says how it spun and where it stopped: %s" % [name, _grab.last_words],
			_grab.last_words.contains("coasted") and _grab.last_words.contains("came to rest at"))
		if train:
			# The 8 turned five times the 40's turn, the other way, by its teeth.
			var turned_big: float = _turn_about(_world.get_brick(big).transform.basis
				* (before[big] as Transform3D).basis.inverse(), Vector3(0, 0, 1))
			var turned_small: float = _turn_about(_world.get_brick(small).transform.basis
				* (before[small] as Transform3D).basis.inverse(), Vector3(0, 0, 1))
			var whole: float = grab.angle * signf(grab.axis.z)
			var want: float = wrapf(-5.0 * whole, -180.0, 180.0)
			print("    the 40 stands %.3f° round (%.3f° in all), the 8 %.3f°; by the teeth the 8 is %.3f° round" % [
				turned_big, whole, turned_small, want])
			_check("%s: at rest the 8 stands where five times the 40's turn puts it, to %.4f°" % [name,
				absf(wrapf(turned_small - want, -180.0, 180.0))], absf(wrapf(turned_small - want, -180.0, 180.0)) < 0.05)
		_check("%s: let go, the drag and the coast are one step to undo" % name, _builder.history_depth() == depth + 1)
		if _windowed:
			await _clean_shot("coast " + ("train" if train else "flywheel"), "3_rest")
		_builder.undo()
		await _frames(3)
		_check("%s: one undo puts it back exactly (%s)" % [name, _differs(before)], _differs(before) == "none differs")
		# Over MCP: let go at a speed, and the answer says how it spun.
		var tools := AppTools.new()
		tools.app = _main
		tools.assistant = _main.get("_assistant")
		depth = _builder.history_depth()
		var said: String = str(await tools.run("move_part", {"part": "#%d" % big, "spin": 720.0}))
		print("    move_part #%d spin=720 said: %s" % [big, said.replace("\n", " | ")])
		var hand_mcp: Dictionary = _coast_by_hand(turning, deg_to_rad(720.0))
		var last: Swing = _grab.last_swing
		_check("%s: over MCP let go at 720° a second it coasts %.3f turns, by hand %.3f, and says so" % [name,
			last.travel / TAU if last != null else 0.0, float(hand_mcp["turns"])], last != null
			and absf(last.travel / TAU - float(hand_mcp["turns"])) <= float(hand_mcp["turns"]) * 0.01
			and said.contains("coasted") and said.contains("came to rest at"))
		_check("%s: over MCP one step" % name, _builder.history_depth() == depth + 1)
		_builder.undo()
		await _frames(3)
	await _hinge_flick()


## A hinge holds by friction: flicked as the flywheel is, it stays where the
## pointer let it go and does not coast; over MCP, spin= says so.
func _hinge_flick() -> void:
	var name: String = "coast: a hinge holds"
	print("\n%s" % name)
	if not await _open("res://vendor/omr/files/4096-1_Crane.mpd"):
		return
	_grab._ready_now()
	var bodies: Bodies = _grab._bodies
	var chosen: Dictionary = _choose(bodies, "hinge")
	if chosen.is_empty():
		_check("%s: the crane has a hinge" % name, false)
		return
	var child: int = chosen["child"]
	_frame_on(PackedInt64Array())
	await _frames(15)
	await _camera_still()
	var depth: int = _builder.history_depth()
	var flick: Array = await _flick(bodies.members[child], bodies, 180.0, 0.2, name)
	var grab: Grab = flick[0]
	if grab == null:
		return
	var let_go_at: float = float(flick[2])
	await _settled()
	_check("%s: flicked at %.0f° a second and let go at %.1f°, it does not coast: %s" % [name, float(flick[1]),
		let_go_at, _grab.last_words], not _grab.last_words.contains("coasted")
		and absf(grab.angle - let_go_at) < 0.01)
	_check("%s: one step to undo" % name, _builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(3)
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var part: int = int((bodies.members[child] as PackedInt64Array)[0])
	var said: String = str(await tools.run("move_part", {"part": "#%d" % part, "degrees": 10.0, "spin": 360.0}))
	print("    move_part #%d degrees=10 spin=360 said: %s" % [part, said.replace("\n", " | ")])
	_check("%s: over MCP spin= says it does not coast" % name, said.contains("does not coast"))
	if _builder.history_depth() > depth:
		_builder.undo()
		await _frames(3)


## Press on [param ids] and turn it about its joint with the pointer at
## [param rate] degrees a second by the clock for [param seconds], then let
## go while it still turns: [the grab or null, the pointer's rate over its
## last tenth of a second by the probe's own clock, the turn as it was let
## go].
func _flick(ids: PackedInt64Array, bodies: Bodies, rate: float, seconds: float, name: String) -> Array:
	var joined: Bodies.Link = bodies.parent_link[int(bodies.body_of[int(ids[0])])]
	var press: Dictionary = _press_off_line(ids, joined.point, joined.axis.normalized())
	if press.is_empty():
		press = _press_point(ids, bodies)
	if press.is_empty():
		_check("%s: the part to flick is under the pointer" % name, false)
		return [null, 0.0, 0.0]
	var screen: Vector2 = press["screen"]
	await _move(screen, 0)
	await _button(screen, true)
	await _move(screen + Vector2(0, 7), MOUSE_BUTTON_MASK_LEFT)
	var grab: Grab = _grab.grab
	if grab == null or grab.state != "moves" or grab.mode != "turn":
		_check("%s: a drag on it turns it on its joint (%s)" % [name, _grab.last_words], false)
		await _button(_last_screen, false)
		return [null, 0.0, 0.0]
	var hold: Vector3 = grab._hold
	var began: int = Time.get_ticks_usec()
	var asked: Array = []   ## [s, degrees]
	var start: float = grab.angle
	while true:
		var t: float = float(Time.get_ticks_usec() - began) / 1000000.0
		var target: float = start + rate * t
		asked.append([t, target])
		await _move(_camera.unproject_position(_about(grab.pivot, grab.axis, target) * hold), MOUSE_BUTTON_MASK_LEFT)
		if t >= seconds:
			break
	var let_go_at: float = grab.angle
	await _button(_last_screen, false)
	# The pointer's own rate over its last tenth of a second, by the probe's
	# clock: what the grab reads from the moves it was given.
	var t_end: float = float(asked[asked.size() - 1][0])
	var first: Array = asked[asked.size() - 1]
	for one: Array in asked:
		if t_end - float(one[0]) <= 0.1:
			first = one
			break
	var measured: float = (float(asked[asked.size() - 1][1]) - float(first[1])) / maxf(t_end - float(first[0]), 0.001)
	print("    flicked at %.0f° a second for %.2f s in %d moves; the grab read %.0f° a second" % [measured, seconds,
		asked.size(), rad_to_deg(_grab.held_fling)])
	return [grab, absf(measured), let_go_at]


## A train coasting, by hand from its parts: each part's mass (Stability's)
## and its moment of inertia about its own axle, its mass spread through its
## box (Σ m (d² + (a² + b²)/12) for the box's sides across the axle); each
## body counted at its ratio to the driver by the teeth, its inertia times
## the ratio squared and its bearing's friction, μ r m g, times the ratio.
## From [param rate], rad/s, at a steady α = friction / inertia it coasts
## rate² / 2α radians in rate / α seconds. [param turning]: [[keys, a point
## on its axle, its axle's way, its ratio]].
func _coast_by_hand(turning: Array, rate: float) -> Dictionary:
	var inertia: float = 0.0
	var friction: float = 0.0
	var first: float = 0.0
	for one: Array in turning:
		var p: Vector3 = one[1]
		var u: Vector3 = one[2]
		var ratio: float = one[3]
		var mine: float = 0.0
		for key: int in one[0]:
			var brick: BrickWorld.Brick = _world.get_brick(key)
			var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
			var g: float = Stability.grams(info)
			var at: Transform3D = brick.transform
			var c: Vector3 = at * info.bounds.get_center()
			var off: Vector3 = (c - p) - u * (c - p).dot(u)
			var local: Vector3 = at.basis.orthonormalized().inverse() * u
			var size: Vector3 = info.bounds.size
			var own: float = g / 12.0 * (local.x * local.x * (size.y * size.y + size.z * size.z)
				+ local.y * local.y * (size.x * size.x + size.z * size.z)
				+ local.z * local.z * (size.x * size.x + size.y * size.y))
			mine += g * off.length_squared() + own
			friction += Swing.MU * Swing.BEARING * Swing.GRAVITY * g * absf(ratio)
		inertia += mine * ratio * ratio
		if first == 0.0:
			first = mine
	var alpha: float = friction / inertia
	return {"I": inertia, "I_first": first, "friction": friction, "alpha": alpha,
		"turns": rate * rate / (2.0 * alpha) / TAU, "seconds": rate / alpha}


# -- a universal joint at an angle ------------------------------------------------------

## A crank turning a shaft through a universal joint, made here from
## 8062-1's winch (its sub-model Crane Sub 26 4): an axle 4 in a Technic
## brick 1 x 4 with holes on a tower, a gear 8 on it driven by a gear 8 on a
## crank axle 3 beside it, a universal joint (3712, 3326a, 3712), and the far
## shaft, an axle 4 with a gear 8 on it, in a Technic brick 1 x 4 on a tower
## of its own. Straight,
## the shafts are in line; [method _cardan_case] turns the far half about the
## near end's pin by [constant CARDAN_BETA]. LDraw's units, y down.
const MADE_CARDAN := """0 A crank turns a shaft through a universal joint
0 Name: made_cardan.ldr
0 !BRICKWORKS FLOOR NONE
1 0 0 0 0 1 0 0 0 1 0 0 0 1 3705.dat
1 7 -10 -10 0 0 0 1 0 1 0 -1 0 0 3701.dat
1 4 -10 14 0 0 0 1 0 1 0 -1 0 0 3010.dat
1 4 -10 38 0 0 0 1 0 1 0 -1 0 0 3010.dat
1 7 10 0 0 0 0 1 0 1 0 -1 0 0 3647.dat
1 0 10 0 20 1 0 0 0 1 0 0 0 1 4519.dat
1 7 10 0 20 0 0 1 0 1 0 -1 0 0 3647.dat
1 7 -30 0 0 0 0 1 0 1 0 -1 0 0 3712.dat
1 7 -60 0 0 0 0 1 0 1 0 -1 0 0 3326a.dat
1 7 -90 0 0 0 0 -1 -1 0 0 0 1 0 3712.dat
1 0 -120 0 0 1 0 0 0 1 0 0 0 1 3705.dat
1 7 -140 0 0 0 0 1 0 1 0 -1 0 0 3647.dat
1 7 -110 -10 0 0 0 1 0 1 0 -1 0 0 3701.dat
1 4 -110 14 0 0 0 1 0 1 0 -1 0 0 3010.dat
1 4 -110 38 0 0 0 1 0 1 0 -1 0 0 3010.dat
"""
## The made joint's angle between its shafts, degrees.
const CARDAN_BETA := 30.0


## Turn the made crank round through the universal joint at an angle: the
## far shaft against Cardano's relation, tan ψ2 = tan ψ1 cos β (ψ1 the near
## end's pin from square to the shafts' plane, ψ2 the far end's pin from that
## plane), worked by hand from where the joint's parts stand, every 10° of two
## turns of the near shaft; and against the mean the gear reading gives (one
## for one), which it runs ahead of and behind.
func _cardan_case() -> void:
	var name: String = "universal joint at %.0f°" % CARDAN_BETA
	print("\n%s" % name)
	var straight: String = OUT.path_join("made_cardan_straight.ldr")
	_write(straight, MADE_CARDAN)
	if not await _open(straight):
		_check("%s: the made joint opens" % name, false)
		return
	_grab._ready_now()
	var found: Array = _grab._bodies.universals()
	_check("%s: the joint is read as a universal joint, straight" % name, found.size() == 1)
	if found.size() != 1:
		print("    %s" % _grab._bodies.summary())
		for link: Bodies.Link in _grab._bodies.links:
			print("    %s %s at %s way %s" % [link.kind, _parts_said(_grab._bodies, link), link.point.snapped(Vector3.ONE * 0.1),
				link.axis.snapped(Vector3.ONE * 0.01)])
		return
	# The near end's pin: the link between the cross and the end on the near
	# shaft (x above the crossing).
	var at: Vector3 = found[0][3]
	var pin: Bodies.Link = found[0][1]
	for link: Bodies.Link in [found[0][1], found[0][2]]:
		var end: int = link.other(int(found[0][0]))
		if _world.get_brick(int((_grab._bodies.members[end] as PackedInt64Array)[0])).transform.origin.x \
				> at.x + 1.0:
			pin = link
	# Turned in LDraw's frame: its y and z are the view's turned round, and the
	# model was set on the floor (the near axle stands at LDraw's origin).
	var flip := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
	var origin := Vector3.ZERO
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3705":
			origin = brick.transform.origin
			break
	var at_ldraw: Vector3 = flip * (at - origin)
	var turn := Transform3D(Basis.IDENTITY, at_ldraw) \
		* Transform3D(flip * Basis(pin.axis.normalized(), deg_to_rad(CARDAN_BETA)) * flip, Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -at_ldraw)
	var lines := PackedStringArray()
	for line: String in MADE_CARDAN.split("\n"):
		var bits: PackedStringArray = line.split(" ", false)
		if bits.size() < 15 or bits[0] != "1" or float(bits[2]) > -59.0:
			lines.append(line)
			continue
		var placed := Transform3D(Basis(Vector3(float(bits[5]), float(bits[8]), float(bits[11])),
			Vector3(float(bits[6]), float(bits[9]), float(bits[12])),
			Vector3(float(bits[7]), float(bits[10]), float(bits[13]))),
			Vector3(float(bits[2]), float(bits[3]), float(bits[4])))
		var moved: Transform3D = turn * placed
		var m: Basis = moved.basis
		lines.append("1 %s %.4f %.4f %.4f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %s" % [bits[1],
			moved.origin.x, moved.origin.y, moved.origin.z, m.x.x, m.y.x, m.z.x, m.x.y, m.y.y, m.z.y,
			m.x.z, m.y.z, m.z.z, bits[14]])
	var angled: String = OUT.path_join("made_cardan.ldr")
	_write(angled, "\n".join(lines))
	if not await _open(angled):
		return
	# Both towers stay: their parts locked (the far one stands turned).
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3010" or brick.part_id == "3701":
			_builder.locked[brick.id] = true
	_grab._ready_now()
	var crank: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "4519":
			crank = brick.id
	var grab := Grab.new()
	grab.world = _world
	grab.builder = _builder
	grab.library = _library
	grab.bodies = _grab._bodies
	grab.shared_mechanism = _grab._mechanism
	var state: String = grab.begin(crank, _world.get_brick(crank).transform.origin)
	var joint: Dictionary = grab.mechanism.universals[0] if grab.mechanism != null \
		and not grab.mechanism.universals.is_empty() else {}
	_check("%s: the crank drives the shaft through the joint (%s %s; %s)" % [name, state, grab.said,
		grab.gear_note], state == "moves" and not joint.is_empty())
	if joint.is_empty():
		print("    %s; universals read %d; gear reading: %s" % [_grab._bodies.summary(), _grab._bodies.universals().size(),
			grab.mechanism.summary() if grab.mechanism != null else "none"])
		if grab.mechanism != null:
			print("    floating %s; %s" % [grab.mechanism.floating, grab.mechanism.describe().replace("\n", " | ")])
		_builder.locked.clear()
		return
	var a: Vector3 = (joint["way_one"] as Vector3).normalized()
	var b: Vector3 = (joint["way_other"] as Vector3).normalized()
	var beta: float = a.angle_to(b)
	var normal: Vector3 = a.cross(b).normalized()
	var p0: Vector3 = (joint["pin_one"] as Vector3).normalized()
	# ψ1 where it stood: the near pin from square to the shafts' plane.
	var psi_rest: float = atan2(a.dot(normal.cross(p0)), normal.dot(p0))
	var near_key: int = int(joint["end_one"])
	var far_key: int = int(joint["end_other"])
	var worst: float = 0.0
	var worst_mean: float = 0.0
	var poses: int = 0
	for step: int in range(1, 37):
		var asked: float = 20.0 * step
		grab.turn_to(asked)
		if grab.stopped:
			break
		var near_turn: float = deg_to_rad(_turn_about((grab.placed[near_key] as Transform3D).basis
			* (grab.rest[near_key] as Transform3D).basis.inverse(), a))
		var far_turn: float = deg_to_rad(_turn_about((grab.placed[far_key] as Transform3D).basis
			* (grab.rest[far_key] as Transform3D).basis.inverse(), b))
		# By hand: tan ψ2 = tan ψ1 cos β, from where each stood.
		var psi1: float = psi_rest + near_turn
		var psi2: float = atan2(cos(beta) * sin(psi1), cos(psi1))
		var psi2_rest: float = atan2(cos(beta) * sin(psi_rest), cos(psi_rest))
		var by_hand: float = wrapf(psi2 - psi2_rest, -PI, PI)
		worst = maxf(worst, absf(rad_to_deg(wrapf(far_turn - by_hand, -PI, PI))))
		worst_mean = maxf(worst_mean, absf(rad_to_deg(wrapf(near_turn - by_hand, -PI, PI))))
		poses += 1
		if step == 6 and _windowed:
			_world.set_drawn(grab.placed)
			_frame_on(PackedInt64Array())
			await _frames(10)
			await _clean_shot("cardan", "2_turned")
			_world.set_drawn({})
	print("    β %.2f°; the mean (one for one) is off Cardano's relation by up to %.3f° over %d poses" % [
		rad_to_deg(beta), worst_mean, poses])
	_check("%s: in %d poses through two turns the far shaft stands where Cardano's relation puts it, to %.4f°"
		% [name, poses, worst], poses >= 30 and worst < 0.05 and worst_mean > 1.0)
	_builder.locked.clear()


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
	best["point"] = a
	best["line"] = Vector3(ends[1].x - ends[0].x, 0.0, ends[1].y - ends[0].y).normalized() \
		if ends.size() > 1 else out.cross(Vector3.UP)
	best["out"] = out
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


## A steering column turned one way and back again over MCP. A real session
## (bench/results/mcpwalk-2026-10-17) built a buggy whose column's 24 tooth
## gear sits on a Technic plate's studs, in the gear's holes. Turned 30
## degrees the studs no longer met the holes, the next reading counted them
## as held in the gear, locked the column and both kingpins to the chassis,
## and the turn back was refused: "held rigidly to what stays". The session
## took the steering wheel off its column to get round it.
##
## --only=kart: a second session's kart (steering_kart.json), on four rims
## with their tyres, still OPEN. The first turn goes as it should; then a
## front tyre's tread, whose gaps the part file reads as sockets (58090 has
## four), comes over a baseplate stud and is taken for standing on it, the
## front axle becomes what stays, and the turn back swings the chassis round
## it. Asking a turned part for two studs to stand fixed it and broke
## 42081-1's arm, whose rolled tyre stands on one, so it is not in the run.
func _steer_twice(kart: bool = false) -> void:
	var fixtures: Array = [["kart", "steering_kart.json", "edit_model"]] if kart \
		else [["buggy", "steering_buggy.json", "submit_design"]]
	for fixture: Array in fixtures:
		print("\nmove_part twice: a session's %s, its steering turned, and turned back" % fixture[0])
		await _clean_slate()
		_main.call("clear_model")
		await _frames(3)
		var design: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://tests/fixtures/mcpwalk/" + str(fixture[1])))
		var assistant: Assistant = _main.get("_assistant")
		# In a window the answer is blocks, the picture among them.
		var answer: Variant = await assistant.use_tool(str(fixture[2]), design)
		var built: String = str(answer)
		if answer is Array:
			built = ""
			for block: Variant in answer:
				if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
					built += str((block as Dictionary)["text"])
		_check("the session's %s builds: %s" % [fixture[0], built.left(50)],
			built.begins_with("Built") or built.begins_with("Done"))
		var wheel: BrickWorld.Brick = null
		var deck: BrickWorld.Brick = null
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id == "2819":
				wheel = brick
			elif brick.part_id == "3738" and deck == null:
				deck = brick
		if wheel == null or deck == null:
			_check("it has its steering wheel and its deck", false)
			continue
		var key: int = wheel.id
		var as_built: Basis = wheel.transform.basis
		var deck_at: Transform3D = deck.transform
		var turned := func() -> float:
			var relative: Basis = _world.get_brick(key).transform.basis * as_built.inverse()
			return rad_to_deg(atan2(-relative.x.z, relative.x.x))
		var tools := AppTools.new()
		tools.app = _main
		tools.assistant = assistant
		for step: Array in [[30.0, 30.0], [-60.0, -30.0], [30.0, 0.0]]:
			var said: String = str(await tools.run("move_part", {"part": "#%d" % key,
				"degrees": step[0]}))
			await _frames(3)
			var now: float = turned.call()
			var still: bool = _world.get_brick(deck.id).transform.is_equal_approx(deck_at)
			_check("turned %+d: the wheel stands %+.1f degrees from where it was built, for %+d, the chassis %s: %s"
				% [int(step[0]), now, int(step[1]), "where it was" if still else "MOVED",
					said.left(110).replace("\n", " | ")],
				said.contains("Moved") and absf(now - float(step[1])) < 1.0 and still)
		_builder.forget_history()


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


# -- what a frame costs ----------------------------------------------------------------

## Per frame of a drag: the engine's process time (scripts: the drag, the
## status bar, the balance), the renderer's CPU time (the scene culled and
## the draw lists built, with what set_drawn rewrote) and its GPU time.
var _cost_process := PackedFloat64Array()
var _cost_cpu := PackedFloat64Array()
var _cost_gpu := PackedFloat64Array()
var _cost_drag := PackedFloat64Array()
var _cost_flush := PackedFloat64Array()
var _cost_batches: int = 0
var _cost_idle := PackedFloat64Array()
var _cost_drag_frames: int = 0


func _costs_begin() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_cost_process.clear()
	_cost_cpu.clear()
	_cost_gpu.clear()
	_cost_drag.clear()
	_cost_flush.clear()
	_cost_batches = 0
	_world.rebuilt_ms = 0.0
	_world.rebuilt_batches = 0


func _costs_sample() -> void:
	var viewport: RID = root.get_viewport_rid()
	_cost_process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_cost_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		+ RenderingServer.get_frame_setup_time_cpu())
	_cost_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	_cost_drag.append(_grab.last_motion_ms)
	_cost_flush.append(_world.rebuilt_ms)
	_cost_batches = maxi(_cost_batches, _world.rebuilt_batches)
	_world.rebuilt_ms = 0.0
	_world.rebuilt_batches = 0


func _costs_said() -> String:
	return ("idle frames before the press %s; render CPU %s; GPU %s; the drag's own (follow, draw, "
		+ "weigh, say) %s; the batches rewritten %s, %d at most") % [_spread(_cost_idle), _spread(_cost_cpu),
		_spread(_cost_gpu), _spread(_cost_drag), _spread(_cost_flush), _cost_batches]


## "mean 12.3, 95% 20.1, worst 31.0 ms"
static func _spread(values: PackedFloat64Array) -> String:
	if values.is_empty():
		return "none"
	var total: float = 0.0
	for value: float in values:
		total += value
	return "mean %.1f, 95%% %.1f, worst %.1f ms" % [total / values.size(), _percentile(values, 0.95),
		_percentile(values, 1.0)]


static func _mean(values: PackedFloat64Array) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / maxf(float(values.size()), 1.0)


static func _percentile(values: PackedFloat64Array, share: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	return sorted[clampi(ceili(share * sorted.size()) - 1, 0, sorted.size() - 1)]


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
func _settled(most_ms: int = 20000) -> void:
	var waited: int = Time.get_ticks_msec()
	while _grab.is_settling() and Time.get_ticks_msec() - waited < most_ms:
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
