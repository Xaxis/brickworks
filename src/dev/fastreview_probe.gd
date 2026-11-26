## fastreview: an independent review of stepfast (a swing's joint asked of what
## it moves, a minifig's later parts checked where they land), run in its
## tree and in one from before it at the same moment, the two logs diffed.
##
##   godot --path . --resolution 1280x720 --script src/dev/fastreview_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh fastreview_probe --case=hinges   every shipped example and two sets
##   PROBE_SIZE=1280x720 tools/probe.sh fastreview_probe --case=figs     the figure's later parts
##
## --case= hinges, figs or all (the default).
##   hinges  each model in models/ and two sets with many round joints, at up
##           to 12 of its steps: each sub-assembly with parts on show and
##           parts to come clicked as a person clicks it, then what the
##           Hinge, J and the rings are told (hinge_angle, hung_from) and the
##           joint the swing turns about (_joint_of, of its parts on show and
##           of all it moves); swung 30 degrees (J), what moved, then undone,
##           redone and undone, each compared with the parts as they were.
##           One H line each, to diff with the other tree's.
##   figs    a figure whose head and held plate come a step after it, aimed
##           so the plate lands in a part on show, on a brick's studs, flush
##           beside one, in a part of a later step and in a part turned 45
##           degrees; each at the plate's step (the plate to come) and at the
##           next (the plate on show, in hand), which must say the same. Then
##           aimed back where it stood (its own head under its feet).
## Exits non-zero when a check fails.
extends "res://src/dev/stepfast_probe.gd"

const MODELS := "res://models/"
const HINGE_SETS := ["res://vendor/omr/files/8841-1_Balance.mpd", "res://vendor/omr/files/5762-1_Plane.mpd"]
const FIG_DIR := "user://fastreview_probe/"

## The figure: its head and its held plate in a step after the rest.
const FIG := """0 FILE main.ldr
0 fastreview: a figure whose head and held plate come a step after it
0 Name: main.ldr
0 Author: fastreview_probe
1 71 0 0 0 1 0 0 0 1 0 0 0 1 3811.dat
%ON%0 STEP
1 16 0 -80 0 1 0 0 0 1 0 0 0 1 fig.ldr
0 STEP
%LATER%0 NOFILE
0 FILE fig.ldr
0 fig
0 Name: fig.ldr
1 1 0 32 0 1 0 0 0 1 0 0 0 1 3815.dat
1 1 0 44 0 1 0 0 0 1 0 0 0 1 3816.dat
1 1 0 44 0 1 0 0 0 1 0 0 0 1 3817.dat
1 4 0 0 0 1 0 0 0 1 0 0 0 1 973.dat
1 4 15.552 9 0 0.985 0.174 0 -0.174 0.985 0 0 0 1 3818.dat
1 4 -15.552 9 0 0.985 -0.174 0 0.174 0.985 0 0 0 1 3819.dat
0 STEP
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3626b.dat
1 15 60 20 0 1 0 0 0 1 0 0 0 1 3023.dat
0 STEP
0 NOFILE
"""

var _same_count: int = 0
var _differ_count: int = 0


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("fastreview_probe: needs a window")
		quit(1)
		return
	_case = "all"
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
	print("fastreview_probe: a %s window, case %s, code %s" % [_size, _case,
		"stepfast" if _builder.has_method("_swinging") else "before stepfast"])
	if _case in ["all", "figs"]:
		await _figs()
	if _case in ["all", "hinges"]:
		await _hinges()
	if _case in ["all", "hfix"]:
		await _hinge_fixture()
	print("\nfastreview_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


# -- hinges --------------------------------------------------------------------


func _hinges() -> void:
	var files: Array = []
	for name: String in DirAccess.get_files_at(MODELS):
		if name.ends_with(".ldr"):
			files.append(MODELS + name)
	files.sort()
	files.append_array(HINGE_SETS)
	for path: String in files:
		await _sweep(path)
	_result("hinges.count", "%d clicks where a swing carries later parts, %d where it carries none"
		% [_differ_count, _same_count])


func _open_timeline(path: String) -> bool:
	if _steps.is_playing_back():
		_steps.stop()
	_builder.cancel_carry()
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _frames(30)
	_shell.run("timeline")
	for _n: int in 900:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	await _frames(6)
	_steps.to_start()
	await _frames(6)
	_verbs.set_mode("select")
	return _steps.is_playing_back()


func _sweep(path: String) -> void:
	print("\n== %s" % path.get_file())
	if not await _open_timeline(path):
		_result("hinges.%s" % path.get_file(), "no timeline")
		return
	var count: int = _steps.steps().size()
	var stride: int = maxi(1, ceili(count / 12.0))
	print("  %d parts, %d steps, every %d" % [_world.brick_count(), count, stride])
	for s: int in count:
		if s % stride == 0 and _builder.at_a_step():
			await _at_this_step(path.get_file(), s)
		_steps.step_forward()
		await _frames(2)


func _places() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


static func _moved_between(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for id: int in a:
		if not b.has(id) or a[id] != b[id]:
			out.append(id)
	for id: int in b:
		if not a.has(id):
			out.append(id)
	out.sort()
	return out


static func _joint_said(joint: Dictionary) -> String:
	if joint.is_empty():
		return "none"
	var p: Vector3 = (joint["point"] as Vector3).snapped(Vector3.ONE * 0.01)
	var a: Vector3 = (joint["axis"] as Vector3).normalized().snapped(Vector3.ONE * 0.001)
	return "(%.2f,%.2f,%.2f|%.3f,%.3f,%.3f)" % [p.x, p.y, p.z, absf(a.x), absf(a.y), absf(a.z)]


func _at_this_step(name: String, s: int) -> void:
	var units: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if _ahead(brick.id) or _store.scenery.has(brick.id):
			continue
		var unit: Variant = _verbs.assemblies.unit_path_of(brick.id)
		if unit == null or str(unit).is_empty():
			continue
		if not units.has(str(unit)):
			units[str(unit)] = brick.id
	var keys: Array = units.keys()
	keys.sort()
	for unit: String in keys.slice(0, 25):
		_builder.clear_selection()
		if not _builder.select_brick(int(units[unit]), false):
			continue
		var alive: PackedInt64Array = _builder.call("_living_selection")
		var moving: PackedInt64Array = _builder.call("_moving_selection")
		if moving.size() == alive.size():
			_same_count += 1
			_builder.clear_selection()
			continue
		_differ_count += 1
		var angle: Variant = _builder.hinge_angle()
		var hung: Dictionary = _builder.hung_from()
		var of_alive: Dictionary = _builder.call("_joint_of", alive) if alive.size() <= 60 else {}
		var of_moving: Dictionary = _builder.call("_joint_of", moving) if moving.size() <= 400 else {"point": Vector3.ZERO, "axis": Vector3.ONE, "big": true}
		var before: Dictionary = _places()
		var swung: int = _builder.swing_selection(30.0)
		var after: Dictionary = _places()
		var moved: Array = _moved_between(before, after)
		var outside: int = 0
		var moving_set: Dictionary = {}
		for id: int in moving:
			moving_set[id] = true
		for id: int in moved:
			if not moving_set.has(id):
				outside += 1
		var back: String = "-"
		if swung > 0:
			var undone: bool = _builder.undo()
			var b1: bool = _places() == before
			var redone: bool = _builder.redo()
			var r1: bool = _places() == after
			var undone2: bool = _builder.undo()
			var b2: bool = _places() == before
			back = "%s%s%s" % ["U" if undone and b1 else "u!", "R" if redone and r1 else "r!", "U" if undone2 and b2 else "u!"]
			_check("%s step %d %s: a swing undone, redone and undone comes back exactly (%s)" % [name, s, unit, back],
				back == "URU")
		_check("%s step %d %s: the swing moves only what it carries (%d moved outside)" % [name, s, unit, outside],
			outside == 0 and (swung == 0 or moved.size() == moving.size()))
		print("  H %s s%d %s alive=%d moving=%d hinge=%s hung=%s jalive=%s jmoving=%s swung=%d moved=%d back=%s" % [
			name, s, unit, alive.size(), moving.size(), "null" if angle == null else "%.3f" % float(angle),
			_joint_said(hung), _joint_said(of_alive), "big" if of_moving.has("big") else _joint_said(of_moving),
			swung, moved.size(), back])
		_builder.clear_selection()


# -- figs ----------------------------------------------------------------------


func _fig_file(tag: String, on: String, later: String) -> String:
	DirAccess.make_dir_recursive_absolute(FIG_DIR)
	var path: String = ProjectSettings.globalize_path(FIG_DIR + "fig_%s.mpd" % tag)
	var text: String = FIG.replace("%ON%", on).replace("%LATER%", later)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


func _fig_ids() -> Dictionary:
	var out: Dictionary = {"torso": 0, "plate": 0, "head": 0, "posts": []}
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("973"):
			out["torso"] = brick.id
		if brick.part_id.begins_with("3023"):
			out["plate"] = brick.id
		if brick.part_id.begins_with("3626"):
			out["head"] = brick.id
		if brick.part_id == "3005":
			(out["posts"] as Array).append(brick.id)
	return out


## Open [param path] at the step with the figure on and its head and plate to
## come.
func _fig_at_step(path: String) -> bool:
	if not await _open_timeline(path):
		return false
	for _n: int in 12:
		var found: Dictionary = _fig_ids()
		if int(found["torso"]) != 0 and not _ahead(int(found["torso"])) and _ahead(int(found["plate"])):
			return true
		_steps.step_forward()
		await _frames(4)
	return false


## Lifted, aimed at [param spot] and clicked: {valid, put, changed, G}; put
## back by undo after.
func _fig_try(spot: Vector3) -> Dictionary:
	var found: Dictionary = _fig_ids()
	var depth: int = _builder.history_depth()
	var before: Dictionary = _full()
	var going: Dictionary = await _lift(int(found["torso"]))
	# What the click changes, against the model with the figure in hand.
	var lifted: Dictionary = _full()
	var ghost: Transform3D = await _aim_figure(spot)
	var valid: bool = bool(_builder.get("_ghost_valid"))
	var put: int = _builder.place()
	await _frames(3)
	var after: Dictionary = _full()
	var plate_now: Variant = _world.get_brick(int(found["plate"])).transform if _world.get_brick(int(found["plate"])) != null else null
	var out: Dictionary = {"valid": valid, "put": put, "changed": _changed(lifted, after).size(), "G": ghost,
		"going": going, "plate": plate_now, "held": _builder.held_figure.size()}
	if _builder.is_holding_figure():
		_builder.drop_figure()
	while _builder.history_depth() > depth:
		await _verbs.press("undo")
		await _frames(2)
	await _frames(3)
	out["restored"] = _signed(_full()) == _signed(before)
	return out


func _figs() -> void:
	print("\nF. a figure whose head and held plate come after it")
	var plain: String = _fig_file("plain", "", "")
	if not _check("the fixture opens at the step with the figure on, its head and plate to come",
			await _fig_at_step(plain)):
		return
	var found: Dictionary = _fig_ids()
	var spot := Vector3(-200, 0, -200)
	var clear: Dictionary = await _fig_try(spot)
	var going: Dictionary = clear["going"]
	var g: Transform3D = clear["G"]
	var plate_at: Transform3D = going.get(int(found["plate"]), Transform3D.IDENTITY)
	var head_at: Transform3D = going.get(int(found["head"]), Transform3D.IDENTITY)
	var landing: Transform3D = g * plate_at
	_result("figs.clear", "aimed at %s: stands at %s, valid %s, put #%d, %d to come with it (plate %s, head %s), the plate lands at %s, restored %s"
		% [spot, g.origin.snapped(Vector3.ONE * 0.01), clear["valid"], clear["put"], going.size(),
			going.has(int(found["plate"])), going.has(int(found["head"])), landing.origin, clear["restored"]])
	_check("clear of everything, the figure goes down with its head and plate", bool(clear["valid"])
		and int(clear["put"]) != 0 and going.size() == 2)
	# Where the file's (0,0,0) stands once opened: the baseplate's place.
	var offset := Vector3.ZERO
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3811":
			offset = brick.transform.origin
	var plate_mesh: Lbm.PartMesh = (_main.get("_library") as PartLibrary).mesh_for("3023")
	var box: AABB = (landing * plate_mesh.bounds).abs()
	_result("figs.plate", "the plate lands turned %s, its box %s, the file's origin opened at %s"
		% [landing.basis.get_euler().snapped(Vector3.ONE * 0.001), box, offset])
	# A 1 x 1 brick's line whose top (its origin) stands at [param top] in the
	# world, in the file's numbers (LdrModel.FLIP: y and z the other way).
	var brick_at: Callable = func(top: Vector3, turn: String) -> String:
		var f: Vector3 = (top - offset) * LdrModel.FLIP
		return "1 4 %.3f %.3f %.3f %s 3005.dat\n" % [f.x, f.y, f.z, turn]
	var square := "1 0 0 0 1 0 0 0 1"
	# A hinge, its base 3937 and its top 3938 on one place, one brick tall.
	var hinge_at: Callable = func(top: Vector3, turn: String) -> String:
		var f: Vector3 = (top - offset) * LdrModel.FLIP
		return "1 4 %.3f %.3f %.3f %s 3937.dat\n1 4 %.3f %.3f %.3f %s 3938.dat\n" % [
			f.x, f.y, f.z, turn, f.x, f.y, f.z, turn]
	var mid: Vector3 = box.get_center()
	var bottom: float = box.position.y
	var top: float = landing.origin.y
	var cases: Array = [
		# The plate to come put down on a hinge's top; and with the hinge's
		# top 4 into it, where the plate on show is raised 4 to seat on its
		# studs (fastreview F2: the plate to come was refused there).
		["on_hinge", hinge_at.call(Vector3(mid.x, bottom, mid.z), square), "", true],
		["in_hinge", hinge_at.call(Vector3(mid.x, bottom + 4.0, mid.z), square), "", true],
		# Its top inside the plate's body: refused.
		["in_on", brick_at.call(Vector3(mid.x, bottom + 4.0, mid.z), square), "", false],
		# Its top at the plate's bottom, its stud in the plate: a plate on a stud.
		["on_studs", brick_at.call(Vector3(mid.x, bottom, mid.z), square), "", true],
		# Beside it, side to side.
		["flush_side", brick_at.call(Vector3(box.end.x + 10.0, top, mid.z), square), "", true],
		["in_later", "", brick_at.call(Vector3(mid.x, bottom + 4.0, mid.z), square) + "0 STEP\n", false],
		["in_turned", brick_at.call(Vector3(mid.x, bottom + 4.0, mid.z), "0.7071 0 0.7071 0 1 0 -0.7071 0 0.7071"), "", false],
	]
	for one: Array in cases:
		var path: String = _fig_file(str(one[0]), str(one[1]), str(one[2]))
		if not await _fig_at_step(path):
			_check("%s: opens at the plate's step" % one[0], false)
			continue
		var later: Dictionary = await _fig_try(spot)
		# The next step: the head and plate on show, in hand with the rest.
		_steps.step_forward()
		await _frames(6)
		var f2: Dictionary = _fig_ids()
		var shown: bool = not _ahead(int(f2["plate"]))
		var now: Dictionary = await _fig_try(spot)
		_result("figs.%s" % one[0], "plate to come: valid %s, put #%d, %d changed, stands at %s, restored %s; plate on show (%s, %d in hand, %d to come): valid %s, put #%d, stands at %s, restored %s"
			% [later["valid"], later["put"], later["changed"], (later["G"] as Transform3D).origin.snapped(Vector3.ONE * 0.01),
				later["restored"], shown, now["held"], (now["going"] as Dictionary).size(), now["valid"], now["put"],
				(now["G"] as Transform3D).origin.snapped(Vector3.ONE * 0.01), now["restored"]])
		_check("%s: the plate to come is judged as the plate on show is (%s / %s)" % [one[0], later["valid"], now["valid"]],
			bool(later["valid"]) == bool(now["valid"]))
		_check("%s: %s" % [one[0], "let down" if bool(one[3]) else "refused, nothing changed"],
			bool(later["valid"]) == bool(one[3]) and (bool(one[3]) or int(later["changed"]) == 0))
		_check("%s: undone, all as it was" % one[0], bool(later["restored"]) and bool(now["restored"]))
	# Back where it stood: its own head, still to come, in its feet's columns.
	if not await _fig_at_step(plain):
		return
	found = _fig_ids()
	var torso_was: Transform3D = _world.get_brick(int(found["torso"])).transform
	var home: Dictionary = await _fig_try(Vector3(torso_was.origin.x, 0, torso_was.origin.z))
	var stands: Transform3D = home["G"]
	_result("figs.home", "aimed where it stood (torso at %s): stands at %s (clear spot stood at y %.2f), valid %s, put #%d"
		% [torso_was.origin, stands.origin.snapped(Vector3.ONE * 0.01), g.origin.y, home["valid"], home["put"]])
	_check("aimed back where it stood, it stands as high as on the clear spot, not on its own head to come",
		absf(stands.origin.y - g.origin.y) < 0.5)
	# A stud over, as a person nudges it.
	if not await _fig_at_step(plain):
		return
	var nudged: Dictionary = await _fig_try(Vector3(torso_was.origin.x, 0, torso_was.origin.z + 20.0))
	_result("figs.nudged", "aimed a stud over: stands at %s, valid %s, put #%d" % [
		(nudged["G"] as Transform3D).origin.snapped(Vector3.ONE * 0.01), nudged["valid"], nudged["put"]])
	_check("a stud over from where it stood, it stands as high as on the clear spot",
		absf((nudged["G"] as Transform3D).origin.y - g.origin.y) < 0.5)


# -- hfix: hinges whose sides come at different steps ----------------------------


## How far up (world y) a part's body goes from its origin, studs left off.
func _body_top(part: String) -> float:
	var mesh: Lbm.PartMesh = (_main.get("_library") as PartLibrary).mesh_for(part)
	return mesh.bounds.end.y - (4.0 if part != "3938" and part != "3679" else 0.0) if mesh != null else 0.0


func _body_bottom(part: String) -> float:
	var mesh: Lbm.PartMesh = (_main.get("_library") as PartLibrary).mesh_for(part)
	return mesh.bounds.position.y if mesh != null else 0.0


## A line placing [param part] with its origin at world height [param y]
## over (x, z), square.
static func _line_at(colour: int, part: String, x: float, y: float, z: float) -> String:
	var f: Vector3 = Vector3(x, y, z) * LdrModel.FLIP
	return "1 %d %.3f %.3f %.3f 1 0 0 0 1 0 0 0 1 %s.dat\n" % [colour, f.x, f.y, f.z, part]


## Stood on [param under] (whose origin is at [param at]): the height of
## [param part]'s origin.
func _on(under: String, at: float, part: String) -> float:
	return at + _body_top(under) - _body_bottom(part)


func _hinge_text() -> String:
	# The hinge's base on the baseplate (its origin where the baseplate's top
	# is, as a brick stands), its top at the base's own origin (mcphand).
	var floor_y: float = _on("3811", 0.0, "3937")
	var plate_y: float = _on("3938", 0.0, "3020")
	var flap_base_y: float = _on("3020", plate_y, "3937")
	var brick_y: float = _on("3020", plate_y, "3004")
	var flap_plate_y: float = _on("3938", 0.0, "3023")
	var spin_y: float = _on("3811", 0.0, "3680")
	var spin_plate_y: float = _on("3679", 0.0, "3020")
	var text: String = "0 FILE main.ldr\n0 fastreview: hinges whose sides come at different steps\n0 Name: main.ldr\n0 Author: fastreview_probe\n"
	text += _line_at(71, "3811", 0, 0, 0)
	text += _line_at(4, "3937", 0, floor_y, 0) + _line_at(4, "3937", 200, floor_y, 0) + _line_at(4, "3680", -200, spin_y, 0)
	text += "0 STEP\n"
	text += _line_at(16, "wing", 0, floor_y, 0).replace("wing.dat", "wing.ldr")
	text += _line_at(16, "wing2", 200, floor_y, 0).replace("wing2.dat", "wing2.ldr")
	text += _line_at(16, "spin", -200, spin_y, 0).replace("spin.dat", "spin.ldr")
	text += "0 STEP\n" + _line_at(15, "3001", -100, _on("3811", 0.0, "3001"), 160) + "0 STEP\n0 NOFILE\n"
	# The wing: its hinge's top and a plate on show, a brick to come, and a
	# flap hinged on its plate, half of it to come.
	text += "0 FILE wing.ldr\n0 wing\n0 Name: wing.ldr\n"
	text += _line_at(1, "3938", 0, 0, 0) + _line_at(1, "3020", 0, plate_y, 0)
	text += _line_at(4, "3937", 20, flap_base_y, 0)
	text += _line_at(16, "flap", 20, flap_base_y, 0).replace("flap.dat", "flap.ldr")
	text += "0 STEP\n" + _line_at(14, "3004", -20, brick_y, 0) + "0 STEP\n0 NOFILE\n"
	text += "0 FILE flap.ldr\n0 flap\n0 Name: flap.ldr\n" + _line_at(2, "3938", 0, 0, 0) + "0 STEP\n"
	text += _line_at(2, "3023", 0, flap_plate_y, 0) + "0 STEP\n0 NOFILE\n"
	# The second wing: its plate on show, the hinge's top it hangs from to come.
	text += "0 FILE wing2.ldr\n0 wing2\n0 Name: wing2.ldr\n" + _line_at(1, "3020", 0, plate_y, 0) + "0 STEP\n"
	text += _line_at(1, "3938", 0, 0, 0) + "0 STEP\n0 NOFILE\n"
	# A turntable's top with a plate on show, a brick on it to come.
	text += "0 FILE spin.ldr\n0 spin\n0 Name: spin.ldr\n" + _line_at(5, "3679", 0, 0, 0) + _line_at(5, "3020", 0, spin_plate_y, 0)
	text += "0 STEP\n" + _line_at(14, "3004", 0, _on("3020", spin_plate_y, "3004"), 0) + "0 STEP\n0 NOFILE\n"
	return text


func _hinge_fixture() -> void:
	print("\nX. hinges whose sides come at different steps")
	DirAccess.make_dir_recursive_absolute(FIG_DIR)
	var path: String = ProjectSettings.globalize_path(FIG_DIR + "hinges.mpd")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(_hinge_text())
	file.close()
	print(FileAccess.get_file_as_string(path))
	if not await _open_timeline(path):
		_check("the hinge fixture opens with a timeline", false)
		return
	var count: int = _steps.steps().size()
	print("  %d parts, %d steps" % [_world.brick_count(), count])
	for s: int in count:
		if _builder.at_a_step():
			var shown := PackedStringArray()
			for brick: BrickWorld.Brick in _world.bricks():
				if not _ahead(brick.id):
					shown.append("%s@%s" % [brick.part_id, brick.unit])
			print("  step %d on: %s" % [s, " ".join(shown)])
			for want: Array in [["wing#1", "3020", ""], ["wing2#1", "3020", ""], ["spin#1", "3020", ""],
					["wing#1/flap#1", "3938", "wing#1"]]:
				await _hinge_click("hfix", s, str(want[0]), str(want[1]), str(want[2]))
		_steps.step_forward()
		await _frames(3)


## A click on the [param part] of the copy [param unit] that is on show (in
## [param inside] when it is entered first), then what the Hinge, J, the rings
## and a swing make of it.
func _hinge_click(name: String, s: int, unit: String, part: String, inside: String) -> void:
	var pick: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.unit == unit and brick.part_id == part and not _ahead(brick.id):
			pick = brick.id
	if pick == 0:
		return
	if not inside.is_empty():
		_verbs.assemblies.enter(inside)
		await _frames(2)
	_builder.clear_selection()
	var picked: bool = _builder.select_brick(pick, false)
	var alive: PackedInt64Array = _builder.call("_living_selection")
	var moving: PackedInt64Array = _builder.call("_moving_selection")
	var angle: Variant = _builder.hinge_angle()
	var hung: Dictionary = _builder.hung_from()
	var of_alive: Dictionary = _builder.call("_joint_of", alive) if not alive.is_empty() else {}
	var of_moving: Dictionary = _builder.call("_joint_of", moving) if not moving.is_empty() else {}
	var before: Dictionary = _places()
	var swung: int = _builder.swing_selection(30.0)
	if swung == 0:
		swung = _builder.swing_selection(-30.0)
	var after: Dictionary = _places()
	var moved: Array = _moved_between(before, after)
	var later_moved: int = 0
	for id: int in moved:
		if _ahead(id):
			later_moved += 1
	var back: String = "-"
	if swung > 0:
		var undone: bool = _builder.undo()
		var b1: bool = _places() == before
		var redone: bool = _builder.redo()
		var r1: bool = _places() == after
		var undone2: bool = _builder.undo()
		var b2: bool = _places() == before
		back = "%s%s%s" % ["U" if undone and b1 else "u!", "R" if redone and r1 else "r!", "U" if undone2 and b2 else "u!"]
		_check("%s step %d %s: a swing undone, redone and undone comes back exactly (%s)" % [name, s, unit, back],
			back == "URU")
	print("  H %s s%d %s(%s) picked=%s alive=%d moving=%d hinge=%s hung=%s jalive=%s jmoving=%s swung=%d moved=%d later_moved=%d back=%s" % [
		name, s, unit, part, picked, alive.size(), moving.size(), "null" if angle == null else "%.3f" % float(angle),
		_joint_said(hung), _joint_said(of_alive), _joint_said(of_moving), swung, moved.size(), later_moved, back])
	_check("%s step %d %s: J is offered (%s) exactly when a swing turns something (%d)" % [name, s, unit,
		angle != null, swung], (angle != null) == (swung > 0))
	_builder.clear_selection()
	if not inside.is_empty():
		_verbs.assemblies.leave_to("")
		await _frames(2)
