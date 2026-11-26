## stepfast: a big pick at a step, timed and taken apart, and a minifigure's
## later parts checked where they land.
##
##   godot --path . --resolution 1280x720 --script src/dev/stepfast_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh stepfast_probe --case=pick      10030 at step 40
##   PROBE_SIZE=1280x720 tools/probe.sh stepfast_probe                  the figure (all but pick)
##   PROBE_SIZE=390x844 tools/probe.sh stepfast_probe                   the same on a phone
##
## --case= pick or figland (all but pick when not said).
##   pick     10030-1 at step 40: a click on its biggest sub-assembly, seven
##            times, each timed (select_brick, its listeners in it) with the
##            longest of the frames after; then one click with the listeners
##            held back, and each listener of selection_changed timed alone in
##            the order it is told, Main's own taken apart. The same probe runs
##            in a tree from before stepfix (00d35a98f) at the same moment.
##   figland  tests/fixtures/stepfast/fig_held_later.mpd, a figure whose held
##            plate comes a step after the rest of it, and a wall: at the step
##            with the figure on and the plate to come, X over the torso, the
##            figure aimed where its parts on show stand clear and the plate
##            would land in the wall: refused as a figure in a part is (its
##            ghost red, a click puts nothing down, the same line), nothing
##            moved. At the next step, the plate on show, the same aim refused
##            the same way. Put down clear, the plate goes with it; undone,
##            all back.
## Exits non-zero when a check fails.
extends "res://src/dev/stepreview_probe.gd"

const HELD_LATER := "res://tests/fixtures/stepfast/fig_held_later.mpd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("stepfast_probe: needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			_case = arg.substr(7)
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	_layout = "phone" if mini(window.x, window.y) < int(Phone.NARROW) else "desktop"
	Phone._on = 0 if _layout == "desktop" else 1
	Phone._wide = false
	Keymap.reset()
	Keymap.use("brickworks")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	if _layout == "phone":
		(_main.get("_phone") as Node).set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
	await _frames(20)
	_store = _main.get("_store")
	_store.keeps = false
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_steps = _main.get("_steps")
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	print("stepfast_probe: a %s window, laid out for a %s, case %s, code %s" % [_size, _layout, _case,
		# callcheck: dynamic, it names the code it runs on, an older build's too (_followers_now went in eb4babd0f)
		"stepfast" if _builder.has_method("_followers_now") else (
			"stepfix" if _builder.has_method("later_refusal") else "before stepfix")])
	if _case == "pick":
		await _pick()
	if _case in ["all", "figland"]:
		await _figland()
	print("\nstepfast_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


# -- pick: 10030 at step 40, its biggest sub-assembly clicked -----------------


func _pick() -> void:
	print("\nP. 10030-1 at step 40: a click on its biggest sub-assembly")
	if _steps.is_playing_back():
		_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(BIG)
	_bar.opened.emit(placed)
	await _frames(60)
	_shell.run("timeline")
	for _n: int in 900:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	await _frames(10)
	_steps.to_start()
	for _n: int in 40:
		_steps.step_forward()
	await _frames(20)
	var big: int = 0
	var most: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if _ahead(brick.id):
			continue
		var unit: Variant = _verbs.assemblies.unit_path_of(brick.id)
		if unit == null or str(unit).is_empty():
			continue
		var under: int = _verbs.assemblies.ids_under(str(unit)).size()
		if under > most:
			most = under
			big = brick.id
	_result("pick.what", "%d parts, %d ahead; brick #%d of a sub-assembly of %d (%s)" % [_world.bricks().size(),
		_builder.lattice.ahead.size(), big, most, str(_verbs.assemblies.unit_path_of(big))])
	var took: Array = []
	for trial: int in 7:
		_builder.clear_selection()
		await _frames(20)
		var t0: int = Time.get_ticks_usec()
		_builder.select_brick(big, false)
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		var longest: float = 0.0
		for _n: int in 10:
			var f0: int = Time.get_ticks_usec()
			await process_frame
			longest = maxf(longest, (Time.get_ticks_usec() - f0) / 1000.0)
		took.append(ms)
		_result("pick.click%d" % trial, "%.1f ms, %d selected; the longest of the next 10 frames %.1f ms"
			% [ms, _builder.selection.size(), longest])
	var warm: Array = took.slice(1)
	warm.sort()
	_result("pick.click", "first %.1f ms; the next six median %.1f ms (min %.1f, max %.1f)" % [took[0],
		warm[3], warm[0], warm[-1]])
	# Where it goes: the click with nobody told, then each listener alone.
	_builder.clear_selection()
	await _frames(20)
	_builder.set_block_signals(true)
	var q0: int = Time.get_ticks_usec()
	_builder.select_brick(big, false)
	var quiet: float = (Time.get_ticks_usec() - q0) / 1000.0
	_builder.set_block_signals(false)
	var count: int = _builder.selection.size()
	var said := PackedStringArray(["select_brick told nobody %.1f" % quiet])
	for link: Dictionary in _builder.selection_changed.get_connections():
		var call: Callable = link["callable"]
		var target: Object = call.get_object()
		var where: String = ""
		if target != null and target.get_script() != null:
			where = str((target.get_script() as Script).resource_path.get_file())
		elif target != null:
			where = target.get_class()
		var t0: int = Time.get_ticks_usec()
		call.call(count)
		said.append("%s.%s %.1f" % [where, call.get_method(), (Time.get_ticks_usec() - t0) / 1000.0])
	_result("pick.listeners_ms", ", ".join(said))
	# Main's own, piece by piece, as its listener runs them.
	var pieces := PackedStringArray()
	var outline: Object = _main.get("_outline")
	var t: int = Time.get_ticks_usec()
	outline.call("show_selection", _builder.selection)
	pieces.append("outline %.1f" % ((Time.get_ticks_usec() - t) / 1000.0))
	for method: String in ["_tell_bin_selection", "_look_under_again"]:
		if _main.has_method(method):
			t = Time.get_ticks_usec()
			_main.call(method)
			pieces.append("%s %.1f" % [method, (Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	var whole: String = _verbs.assemblies.selected_assembly()
	pieces.append("selected_assembly %.1f (\"%s\")" % [(Time.get_ticks_usec() - t) / 1000.0, whole])
	t = Time.get_ticks_usec()
	var under_now: int = _verbs.assemblies.ids_under(whole).size() if not whole.is_empty() else 0
	pieces.append("ids_under %.1f (%d)" % [(Time.get_ticks_usec() - t) / 1000.0, under_now])
	t = Time.get_ticks_usec()
	var tree: Variant = _verbs.assemblies.tree()
	pieces.append("tree %.1f (%s)" % [(Time.get_ticks_usec() - t) / 1000.0, tree != null])
	_result("pick.main_ms", ", ".join(pieces))
	# The properties' own, piece by piece, as _refresh runs them.
	var inspector: Object = _shell.inspector
	var assemblies: Assemblies = _verbs.assemblies
	var bricks: Array[BrickWorld.Brick] = []
	for brick_id: int in _builder.selection:
		bricks.append(_world.get_brick(brick_id))
	var props := PackedStringArray()
	for piece: Array in [["_show_credit", []], ["_state_of", [bricks]], ["_buttons_for", [true]],
			["_show_many", [bricks]], ["_show_assembly", [whole, bricks.size()]]]:
		if not inspector.has_method(str(piece[0])):
			continue
		t = Time.get_ticks_usec()
		inspector.callv(str(piece[0]), piece[1])
		props.append("%s %.1f" % [piece[0], (Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	var copies: int = assemblies.copies_of(whole).size()
	props.append("copies_of %.1f (%d)" % [(Time.get_ticks_usec() - t) / 1000.0, copies])
	t = Time.get_ticks_usec()
	var paths: int = assemblies.paths().size()
	props.append("paths %.1f (%d)" % [(Time.get_ticks_usec() - t) / 1000.0, paths])
	t = Time.get_ticks_usec()
	var hinge: Variant = _builder.hinge_angle()
	props.append("hinge_angle %.1f (%s)" % [(Time.get_ticks_usec() - t) / 1000.0, hinge])
	t = Time.get_ticks_usec()
	var all_of: int = assemblies.bricks_under(whole).size()
	props.append("bricks_under %.1f (%d)" % [(Time.get_ticks_usec() - t) / 1000.0, all_of])
	t = Time.get_ticks_usec()
	inspector.set("_shown", "")
	inspector.call("_refresh", true)
	props.append("_refresh whole %.1f" % ((Time.get_ticks_usec() - t) / 1000.0))
	_result("pick.inspector_ms", ", ".join(props))
	_builder.clear_selection()
	await _frames(4)


# -- figland: a figure's later parts where it is put down ----------------------


func _figland() -> void:
	print("\nF. a figure lifted at a step, its held plate to come: put down where the plate lands in a wall")
	if _steps.is_playing_back():
		_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(HELD_LATER)
	_bar.opened.emit(placed)
	await _frames(30)
	var found: Dictionary = _fig_parts()
	if not _check("the fixture has a torso, a held plate and a wall (%s)" % str(found),
			int(found["torso"]) != 0 and int(found["plate"]) != 0 and (found["wall"] as Array).size() == 3):
		return
	_shell.run("timeline")
	for _n: int in 600:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	await _frames(6)
	var at_step: bool = await _to_plate_step()
	var at: Instructions.Step = _steps.current_step()
	if not _check("step %d: the figure on, its plate to come, the wall on" % (at.number if at != null else -1),
			at_step and (found["wall"] as Array).all(func(id: int) -> bool: return not _ahead(id))):
		return
	_verbs.set_mode("select")
	_builder.clear_selection()
	await _frames(4)
	var depth: int = _builder.history_depth()
	_result("figland.start", _steps_said())
	var steps_were: int = _steps.steps().size()
	var start: Array = _signed(_full())
	var plate_was: Transform3D = _world.get_brick(int(found["plate"])).transform
	# X over the torso: the parts on show in hand, the plate left on the model
	# to go where the figure goes.
	var going: Dictionary = await _lift(int(found["torso"]))
	var plate: int = int(found["plate"])
	var plate_at: Transform3D = going.get(plate, Transform3D.IDENTITY)
	_result("figland.lift", "lifted %s: a figure of %d parts in hand, %d to come with it (the plate %s)"
		% [_builder.is_holding_figure(), _builder.held_figure.size(), going.size(),
			"among them" if going.has(plate) else "not"])
	if not _check("X over the torso holds the figure, its plate to come with it",
			_builder.is_holding_figure() and going.has(plate)):
		return
	# Aimed so the plate lands in the wall: first anywhere near, then moved by
	# what is between where the plate would land and the wall.
	var wall: Array = found["wall"]
	var wall_at: Vector3 = _world.get_brick(int(wall[1])).transform.origin
	var spot: Vector3 = await _spot_landing(plate_at, wall_at)
	var ghost: Transform3D = await _aim_figure(spot)
	var plate_part: Lbm.PartMesh = (_main.get("_library") as PartLibrary).mesh_for(_world.get_brick(plate).part_id)
	var in_wall: Array = Array(_builder.lattice.blockers_boxes(_builder.boxes_for(plate_part, ghost * plate_at),
		0, going)).filter(func(id: int) -> bool: return wall.has(id))
	# Asked by name: a tree from before stepfast has no third argument, and
	# runs only the pick.
	# From handkeep the parts in hand are out of the lattice, so none is in
	# the way of the rest: two arguments.
	var shown_clear: bool = bool(_builder.call("figure_fits", _builder.held_figure, ghost)) \
		if _builder.has_method("_figure_whole") \
		else bool(_builder.call("figure_fits", _builder.held_figure, ghost, going))
	_result("figland.aim", "aimed at %s: stands at %s; the plate would land at %s, in %d of the wall's bricks; its parts on show clear %s"
		% [str(spot.snapped(Vector3.ONE)), str(ghost.origin.snapped(Vector3.ONE)),
			str((ghost * plate_at).origin.snapped(Vector3.ONE)), in_wall.size(), shown_clear])
	if not _check("there, the parts on show stand clear and the plate would land in the wall",
			shown_clear and not in_wall.is_empty()):
		return
	var later: Dictionary = await _refused_at(spot, "plate to come")
	await _pic3("FL1_plate_to_come_in_wall")
	_check("the plate to come landing in the wall, the figure is refused: its ghost red, a click puts nothing down",
		not bool(later["valid"]) and int(later["put"]) == 0 and not bool(later["ghosts_valid"]))
	_check("nothing moved: no part changed, the plate where it was, the figure still in hand",
		(later["changed"] as Array).is_empty() and _world.get_brick(plate).transform.is_equal_approx(plate_was)
			and _builder.is_holding_figure())
	# The next step, the plate on show and in hand, aimed so it lands in the
	# wall: the refusal a figure in a part always had.
	# Undone as a person undoes: the timeline worked out again for the
	# model as it is (the builder's own undo leaves it at the lift's).
	await _verbs.press("undo")
	await _frames(4)
	_check("undoing the lift puts the figure back as it was (%s)" % _steps_said(), _signed(_full()) == start
		and not _builder.is_holding_figure())
	_steps.step_forward()
	await _frames(6)
	found = _fig_parts()
	var on: bool = not _ahead(int(found["plate"]))
	var shown: Dictionary = await _lift(int(found["torso"]))
	var held_plate: Array = _builder.held_figure.filter(func(item: Dictionary) -> bool:
		return str(item["part"]).begins_with("3023"))
	var now: Dictionary = {}
	if not held_plate.is_empty():
		var in_hand: Transform3D = held_plate[0]["at"]
		var there: Vector3 = await _spot_landing(in_hand, wall_at)
		var aimed: Transform3D = await _aim_figure(there)
		_result("figland.aim2", "the plate in hand: aimed at %s, it would land at %s"
			% [str(there.snapped(Vector3.ONE)), str((aimed * in_hand).origin.snapped(Vector3.ONE))])
		now = await _refused_at(there, "plate on show")
	_check("at the next step (the plate on %s, in hand %s, %d to come), aimed into the wall it is refused the same way"
		% [on, not held_plate.is_empty(), shown.size()], on and not now.is_empty() and shown.is_empty()
		and not bool(now["valid"]) and int(now["put"]) == 0 and not bool(now["ghosts_valid"])
		and (now["changed"] as Array).is_empty())
	_check("the same words both times (\"%s\" / \"%s\")" % [later["said"], now.get("said", "?")],
		later["said"] == now.get("said", "?"))
	await _verbs.press("undo")
	await _frames(4)
	# Put down clear: the plate goes with it.
	var back: bool = await _to_plate_step()
	if not back:
		_result("figland.walk", "; ".join(_plate_walk.slice(0, 6)))
	found = _fig_parts()
	plate = int(found["plate"])
	going = await _lift(int(found["torso"]))
	plate_at = going.get(plate, Transform3D.IDENTITY)
	var clear: Transform3D = await _aim_figure(Vector3(spot.x - 200, 0, spot.z + 200))
	var put: int = _builder.place()
	await _frames(4)
	var plate_now: Transform3D = _world.get_brick(plate).transform if _world.get_brick(plate) != null \
		else Transform3D.IDENTITY
	_result("figland.clear", "back at the plate's step %s; put down clear at %s: #%d, %d to come with it, the plate %s, held as it was %s"
		% [back, str(clear.origin.snapped(Vector3.ONE)), put, going.size(),
			"moved" if not plate_now.is_equal_approx(plate_was) else "where it was",
			plate_now.is_equal_approx(clear * plate_at)])
	_check("put down clear, the figure goes down and its plate with it",
		back and put != 0 and going.has(plate) and plate_now.is_equal_approx(clear * plate_at))
	await _pic3("FL2_put_down_clear")
	while _builder.history_depth() > depth:
		await _verbs.press("undo")
		await _frames(2)
	_check("undone, every part is back where it was, the timeline's steps as they were (%s)" % _steps_said(),
		_signed(_full()) == start and _steps.steps().size() == steps_were)


## From the first step, forward to the step that has the figure on and its
## plate still to come: false when no step does.
func _to_plate_step() -> bool:
	_builder.clear_selection()
	_steps.to_start()
	await _frames(4)
	_plate_walk = PackedStringArray(["%d steps, playing %s" % [_steps.steps().size(), _steps.is_playing_back()]])
	for _n: int in 16:
		var found: Dictionary = _fig_parts()
		var at: Instructions.Step = _steps.current_step()
		_plate_walk.append("%d: torso %s, plate %s (step %d)" % [at.number if at != null else -1,
			"ahead" if _ahead(int(found["torso"])) else "on", "ahead" if _ahead(int(found["plate"])) else "on",
			_world.get_brick(int(found["plate"])).step if _world.get_brick(int(found["plate"])) != null else -9])
		if not _ahead(int(found["torso"])) and _ahead(int(found["plate"])):
			return true
		_steps.step_forward()
		await _frames(6)
	return false


## How [method _to_plate_step] last walked the steps.
var _plate_walk := PackedStringArray()


## The fixture's torso, held plate and wall bricks by id, found again after
## an undo (a part put back may come back under another number).
func _steps_said() -> String:
	var at: Instructions.Step = _steps.current_step()
	var parts := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		parts.append("%s@%d%s" % [brick.part_id.get_basename(), brick.step, "~" if _ahead(brick.id) else ""])
	return "%d steps, mode %d, at %d, history %d: %s" % [_steps.steps().size(), _steps.mode(),
		at.number if at != null else -1, _builder.history_depth(), " ".join(parts)]


func _fig_parts() -> Dictionary:
	var out: Dictionary = {"torso": 0, "plate": 0, "wall": []}
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("973"):
			out["torso"] = brick.id
		if brick.part_id.begins_with("3023"):
			out["plate"] = brick.id
		if brick.part_id == "3003":
			(out["wall"] as Array).append(brick.id)
	return out


## X over [param torso]: the figure in hand. The parts of it to come, id ->
## where each stands in the figure's frame.
func _lift(torso: int) -> Dictionary:
	_builder.clear_selection()
	_builder.lift_brick(torso)
	await _frames(4)
	var going: Dictionary = {}
	var followers: Variant = _builder.get("_figure_followers")
	if followers is Array:
		for follower: Dictionary in followers:
			going[int(follower["brick"])] = follower["at"]
	# From handkeep the whole figure is in hand, each part where it stands in
	# its frame (Builder._figure_parts): those to come are the ones that go.
	var in_hand: Variant = _builder.get("_figure_parts")
	if in_hand is Dictionary:
		for brick_id: int in in_hand:
			if _builder.is_ahead(brick_id):
				going[brick_id] = in_hand[brick_id]
	return going


## The figure in hand aimed at [param spot] and a click to put it down:
## {valid, put, ghosts_valid (any ghost drawn as fitting), changed, said}.
func _refused_at(spot: Vector3, what: String) -> Dictionary:
	var before: Dictionary = _full()
	var stands: Transform3D = await _aim_figure(spot)
	var valid: bool = bool(_builder.get("_ghost_valid"))
	var ghosts_valid: bool = false
	for ghost: MeshInstance3D in _builder.get("_figure_ghosts"):
		if ghost.visible:
			ghosts_valid = ghosts_valid or bool((ghost.material_override as ShaderMaterial).get_shader_parameter("valid"))
	var line_was: String = _line()
	var put: int = _builder.place()
	await _frames(4)
	# What the click said: nothing, where the line is as it was.
	var out: Dictionary = {"valid": valid, "put": put, "ghosts_valid": ghosts_valid,
		"changed": _changed(before, _full()), "said": _line() if _line() != line_was else "(nothing)"}
	_result("figland.refused", "%s: the ghost at %s turned %d, valid %s (drawn valid %s), put down #%d, %d changed, said \"%s\""
		% [what, str(stands.origin.snapped(Vector3.ONE)), _builder.held_rotation, valid, ghosts_valid, put,
			(out["changed"] as Array).size(), out["said"]])
	return out


## Where to aim the figure in hand so its part standing at [param part_at] in
## its frame lands over [param target]: aimed near first, then moved by what
## is between where the part would land and the target.
func _spot_landing(part_at: Transform3D, target: Vector3) -> Vector3:
	var first: Transform3D = await _aim_figure(Vector3(target.x, 0, target.z))
	var lands: Vector3 = (first * part_at).origin
	return Vector3(target.x - (lands.x - first.origin.x), 0, target.z - (lands.z - first.origin.z))


## The figure in hand aimed straight down at [param spot]: where it would stand.
## Aimed last in the frame it returns in, as a tap aims where it lands and puts
## down in one frame: at 390 x 844 after an Undo, the frames between the aim
## and the click stood the figure 80 LDU off the spot asked.
func _aim_figure(spot: Vector3) -> Transform3D:
	for _n: int in 4:
		_builder.update_preview(spot + Vector3(0, 4000, 0), Vector3.DOWN)
		await process_frame
	_builder.update_preview(spot + Vector3(0, 4000, 0), Vector3.DOWN)
	return _builder.get("_ghost_transform")
