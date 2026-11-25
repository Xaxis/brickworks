## stepfast2: a minifigure lifted at a step, while it is in hand and once it is
## put down: the person's steps, the floor under its feet, and its parts still
## to come judged as its parts on show are. The same file runs in live
## (129a7c3ed), before (stepfast b00a5429c) and after, and says what each does.
##
##   godot --path . --resolution 1280x720 --script src/dev/stepfast2_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh stepfast2_probe                 every case
##   PROBE_SIZE=390x844 tools/probe.sh stepfast2_probe                  a phone
##   PROBE_SIZE=1280x720 tools/probe.sh stepfast2_probe --case=replan   one case
##
## --case= replan, home or seat (all when not said).
##   replan  a figure in a sub-model of its own (fig.ldr) whose held plate comes
##           a step after it, a step of the main model before it and one after.
##           At the figure's step (its plate to come) and at the last (all of it
##           on show): X over the torso, then what the timeline shows while it is
##           in hand (its steps, the step it is at, the plate drawn or not), a
##           save made then, and put down where it stood and somewhere else:
##           each part's step and sub-model, the timeline's steps and the saved
##           file's, against the model as it opened; then one Undo, which puts
##           it back where it stood. Saved in hand and then put back, saved
##           again: the file as opened.
##   home    a figure on a 2 x 4 brick, its head and held plate to come, aimed
##           back where it stood and a quarter turned there: it stands on the
##           brick, as on a clear spot, never on its own head (fastreview F1).
##   seat    a cone (4589) and a 1 x 1 round brick under where the held plate
##           lands, at three heights: the plate to come judged as the plate on
##           show, valid or not and how high (fastreview F2).
## Pictures in shots/stepfast2/. Exits non-zero when a check fails.
extends "res://src/dev/twist_probe.gd"

const SHOTS2 := "res://shots/stepfast2/"
const DIR := "user://stepfast2_probe/"

## A figure in fig.ldr, its held plate a step after it; the main model's first
## step a plate and a wall, its second the figure, its third a brick.
const REPLAN := """0 FILE main.ldr
0 stepfast2: a figure whose held plate comes a step after it, a step before it and one after
0 Name: main.ldr
0 Author: stepfast2_probe
1 71 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
1 4 200 -16 0 1 0 0 0 1 0 0 0 1 3003.dat
1 4 200 -40 0 1 0 0 0 1 0 0 0 1 3003.dat
1 4 200 -64 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 16 0 -80 0 1 0 0 0 1 0 0 0 1 fig.ldr
0 STEP
1 2 -120 -16 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
0 NOFILE
0 FILE fig.ldr
0 fig
0 Name: fig.ldr
1 1 0 32 0 1 0 0 0 1 0 0 0 1 3815.dat
1 1 0 44 0 1 0 0 0 1 0 0 0 1 3816.dat
1 1 0 44 0 1 0 0 0 1 0 0 0 1 3817.dat
1 4 0 0 0 1 0 0 0 1 0 0 0 1 973.dat
1 4 15.552 9 0 0.985 0.174 0 -0.174 0.985 0 0 0 1 3818.dat
1 4 -15.552 9 0 0.985 -0.174 0 0.174 0.985 0 0 0 1 3819.dat
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3626b.dat
0 STEP
1 15 60 20 0 1 0 0 0 1 0 0 0 1 3023.dat
0 STEP
0 NOFILE
"""

## A figure standing on a 2 x 4 brick, its head and held plate a step after
## the rest of it, and a second brick as tall, clear, to stand it on for the
## height it should stand at. %UNDER% is more of the first step.
const HOME := """0 FILE main.ldr
0 stepfast2: a figure on a brick, its head and held plate to come
0 Name: main.ldr
0 Author: stepfast2_probe
1 71 0 0 0 1 0 0 0 1 0 0 0 1 3811.dat
1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 -200 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
%UNDER%0 STEP
1 16 0 -104 0 1 0 0 0 1 0 0 0 1 fig.ldr
0 STEP
0 NOFILE
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

var _case: String = "all"
var _store: ModelStore
var _steps: StepsBar
var _shell: Shell
var _bar: ModelBar
var _code: String = ""


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("stepfast2_probe: needs a window")
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
	_code = "stepfast" if _builder.has_method("_followers_now") else (
		"stepfix" if _builder.has_method("later_refusal") else "live")
	print("stepfast2_probe: a %s window, laid out for a %s, case %s, code %s" % [_size, _layout, _case, _code])
	if _case in ["all", "replan"]:
		await _replan()
	if _case in ["all", "home"]:
		await _where_it_stood()
	if _case in ["all", "seat"]:
		await _seat()
	print("\nstepfast2_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


func _result(key: String, value: Variant) -> void:
	print("  RESULT %s %s = %s" % [_layout, key, str(value)])


# -- replan: the person's steps while the figure is in hand --------------------


func _replan() -> void:
	print("\nR. a figure in its own sub-model lifted at a step: the person's steps")
	var path: String = _fixture("replan", REPLAN)
	if not _check("the fixture opens in the author's steps", await _open(path)):
		return
	var opened: Dictionary = _model()
	var timeline: String = _timeline()
	_store.title = "stepfast2 replan opened"
	var file_opened: String = _saved_steps("stepfast2 replan opened")
	_result("replan.opened", "%s; saved: %s" % [timeline, file_opened])
	for at_last: bool in [false, true]:
		var where: String = "last" if at_last else "fig"
		for put: String in ["hand", "home", "away"]:
			if not await _to(path, at_last):
				_check("%s: opens at the step asked" % where, false)
				continue
			var depth: int = _builder.history_depth()
			var before: Dictionary = _model()
			var steps_were: String = _timeline()
			var ids_were: String = _timeline(true)
			var f: Dictionary = _ids()
			var torso_was: Transform3D = _world.get_brick(int(f["torso"])).transform
			var plate: int = int(f["plate"])
			_builder.clear_selection()
			_builder.lift_brick(int(f["torso"]))
			await _frames(6)
			var held: bool = _builder.is_holding_figure()
			var in_hand: String = _timeline()
			var plate_drawn: String = "in hand" if _world.get_brick(plate) == null \
				else ("drawn" if not _ahead(plate) else "not drawn")
			# The timeline by brick: the parts in hand are off the model, so by
			# name they read as gone.
			_check("%s %s: in hand, the timeline's steps are the person's, at the step it was (%s / %s)"
				% [where, put, in_hand, steps_were], _timeline(true) == ids_were)
			if not at_last:
				_check("fig %s: in hand, its plate still to come is not drawn (%s)" % [put, plate_drawn],
					plate_drawn == "not drawn")
			if put == "hand":
				# A save made with the figure in hand, then put back where it
				# stood and saved again.
				var name: String = "stepfast2 replan in hand %s" % where
				_store.title = name
				var file_held: String = _saved_steps(name)
				_result("replan.%s.hand" % where, "lifted %s; the timeline %s (was %s); the plate %s; saved: %s"
					% [held, in_hand, steps_were, plate_drawn, file_held])
				if not at_last:
					await _shot("R1_in_hand_at_fig_step")
				_check("%s: X over the torso holds the figure" % where, held)
				_check("%s: saved in hand, each file's steps as opened, the figure's parts in hand not in them (%s / %s)"
					% [where, file_held, file_opened], _steps_but_figure(file_held, file_opened))
				await _aim(Vector3(torso_was.origin.x, 0, torso_was.origin.z))
				var back: int = _builder.place()
				await _frames(6)
				name = "stepfast2 replan in hand then back %s" % where
				_store.title = name
				var file_back: String = _saved_steps(name)
				var moved: Array = _differ(before, _model(), true)
				_result("replan.%s.hand_back" % where, "put back #%d; the timeline %s; parts not in their own step and sub-model: %s; saved: %s"
					% [back, _timeline(), moved, file_back])
				_check("%s: put back after a save in hand, every part in its own step and sub-model (%d not), the file's steps as opened (%s)"
					% [where, moved.size(), file_back], back != 0 and moved.is_empty() and file_back == file_opened)
			else:
				var spot: Vector3 = Vector3(torso_was.origin.x, 0, torso_was.origin.z) if put == "home" \
					else Vector3(-120, 0, 120)
				var stands: Transform3D = await _aim(spot)
				var valid: bool = bool(_builder.get("_ghost_valid"))
				var id: int = _builder.place()
				await _frames(6)
				var after: Dictionary = _model()
				var steps_after: String = _timeline()
				var name: String = "stepfast2 replan %s %s" % [put, where]
				_store.title = name
				var file_put: String = _saved_steps(name)
				# By step and sub-model: aimed where it stood, a figure is seated
				# as the app seats one, which may not be where a file put it.
				var moved: Array = _differ(before, after, true)
				_result("replan.%s.%s" % [where, put], "aimed at %s: stands at %s, valid %s, put #%d; the timeline %s (was %s, in hand %s); parts not in their own step and sub-model: %s; saved: %s"
					% [spot, stands.origin.snapped(Vector3.ONE * 0.01), valid, id, steps_after, steps_were,
						in_hand, moved, file_put])
				if put == "home" and not at_last:
					await _shot("R2_put_back_at_fig_step")
				_check("%s %s: put down" % [where, put], id != 0)
				_check("%s %s: every part in its own step and sub-model (%d not)"
					% [where, put, moved.size()], moved.is_empty())
				_check("%s %s: the timeline's steps as they were (%s / %s)" % [where, put, steps_after, steps_were],
					_same_steps(steps_after, steps_were))
				_check("%s %s: saved, the file's steps as opened (%s)" % [where, put, file_put],
					file_put == file_opened)
				# One Undo, the figure still in hand as a click left it: it is
				# back where it stood, never off the model.
				await _verbs.press("undo")
				await _frames(4)
				var undone: Array = _signed(_model())
				_result("replan.%s.%s_undo" % [where, put], "one Undo: %d parts (were %d), the timeline %s"
					% [undone.size(), before.size(), _timeline()])
				_check("%s %s: one Undo puts the figure back where it stood, the timeline as it was (%s)"
					% [where, put, _timeline()], undone == _signed(before) and _same_steps(_timeline(), steps_were))
			if _builder.is_holding_figure():
				_builder.drop_figure()
			while _builder.history_depth() > depth:
				await _verbs.press("undo")
				await _frames(2)
			await _frames(4)
			_check("%s %s: undone, all as it was (%s)" % [where, put, _timeline()],
				_signed(_model()) == _signed(before) and _same_steps(_timeline(), steps_were))


## Whether two timelines read alike: their steps, each one's parts, and the step
## at (the brick numbers aside).
static func _same_steps(a: String, b: String) -> bool:
	return a == b


## A file saved with the figure in hand against the file as opened: the same
## steps in every file, but the figure's parts (and the line placing its
## sub-model, with the whole of it in hand) gone, and no other.
static func _steps_but_figure(held: String, opened: String) -> bool:
	var figure: PackedStringArray = PackedStringArray(["3815", "3816", "3817", "973", "3818", "3819",
		"3626b", "3023", "fig"])
	var drop: Callable = func(text: String) -> String:
		var out := PackedStringArray()
		for section: String in text.split(" | "):
			var kept := PackedStringArray()
			for word: String in section.split(" ", false):
				if not figure.has(word):
					kept.append(word)
			out.append(" ".join(kept))
		return " | ".join(out)
	return drop.call(held) == drop.call(opened)


# -- home: aimed back where it stood --------------------------------------------


func _where_it_stood() -> void:
	print("\nH. a figure on a brick, its head and held plate to come: aimed back where it stood")
	var path: String = _fixture("home", HOME.replace("%UNDER%", ""))
	for turn: int in [0, 1]:
		if not await _at_fig_step(path):
			_check("home: opens at the figure's step", false)
			return
		var f: Dictionary = _ids()
		var torso_was: Transform3D = _world.get_brick(int(f["torso"])).transform
		var depth: int = _builder.history_depth()
		var before: Dictionary = _model()
		_builder.clear_selection()
		_builder.lift_brick(int(f["torso"]))
		await _frames(4)
		var turned: int = 0
		while turned < turn:
			_builder.rotate_held(1)
			turned += 1
		# Where its torso stands in it, to read where a put-down one stands.
		var torso_in: float = 0.0
		for item: Dictionary in _builder.held_figure:
			if str(item["part"]).begins_with("973"):
				torso_in = (item["at"] as Transform3D).origin.y
		# The other brick, as tall and clear: the height it should stand at.
		var clear: Transform3D = await _aim(Vector3(-200.0, 0, torso_was.origin.z))
		var home: Transform3D = await _aim(Vector3(torso_was.origin.x, 0, torso_was.origin.z))
		var home_valid: bool = bool(_builder.get("_ghost_valid"))
		var put: int = _builder.place()
		await _frames(4)
		var head: BrickWorld.Brick = _world.get_brick(int(f["head"]))
		var torso_now: Transform3D = Transform3D()
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id.begins_with("973"):
				torso_now = brick.transform
		_result("home.%d" % turn, "turned %d: aimed where it stood (torso at %s), stands at %s, valid %s; on the other brick it stands at %s; put #%d, the torso at %s, the head at %s"
			% [turn, torso_was.origin, home.origin.snapped(Vector3.ONE * 0.01), home_valid,
				clear.origin.snapped(Vector3.ONE * 0.01), put, torso_now.origin.snapped(Vector3.ONE * 0.01),
				head.transform.origin.snapped(Vector3.ONE * 0.01) if head != null else "gone"])
		_check("turned %d: aimed back where it stood, it stands on its brick (y %.2f), as on the other (y %.2f)"
			% [turn, home.origin.y, clear.origin.y], absf(home.origin.y - clear.origin.y) < 0.5 and home_valid)
		_check("turned %d: put down there, its torso at the height it stands at on the other brick (%.2f / %.2f), the head on its neck"
			% [turn, torso_now.origin.y, clear.origin.y + torso_in],
			put != 0 and absf(torso_now.origin.y - (clear.origin.y + torso_in)) < 0.5 and head != null
			and (head.transform.origin - torso_now.origin).length() < 30.0)
		if _builder.is_holding_figure():
			_builder.drop_figure()
		while _builder.history_depth() > depth:
			await _verbs.press("undo")
			await _frames(2)
		_check("turned %d: undone, all as it was" % turn, _signed(_model()) == _signed(before))


# -- seat: the plate to come over a cone, as the plate on show ------------------


func _seat() -> void:
	print("\nS. the plate to come over a cone and a round brick, judged as the plate on show")
	var plain: String = _fixture("seat_plain", HOME.replace("%UNDER%", ""))
	if not await _at_fig_step(plain):
		_check("seat: opens at the figure's step", false)
		return
	var f: Dictionary = _ids()
	var spot := Vector3(-160, 0, -160)
	var probe: Dictionary = await _try(spot)
	var g: Transform3D = probe["G"]
	var plate_at: Transform3D = (probe["going"] as Dictionary).get(int(f["plate"]), Transform3D.IDENTITY)
	if _code == "live" or plate_at == Transform3D.IDENTITY:
		# Live lifts the plate with the rest: where it stands in the figure.
		for item: Dictionary in probe["held_parts"]:
			if str(item["part"]).begins_with("3023"):
				plate_at = item["at"]
	var landing: Transform3D = g * plate_at
	var plate_mesh: Lbm.PartMesh = (_main.get("_library") as PartLibrary).mesh_for("3023")
	var box: AABB = (landing * plate_mesh.bounds).abs()
	var offset := Vector3.ZERO
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3811":
			offset = brick.transform.origin
	_result("seat.clear", "on a clear spot it stands at %s, the plate's box %s" % [g.origin, box])
	# The plate's stud nearest the figure: under it, what is tried.
	var stud: Vector3 = Vector3(box.position.x + 10.0, box.position.y, box.get_center().z)
	for part: String in ["4589", "3062b"]:
		var mesh: Lbm.PartMesh = (_main.get("_library") as PartLibrary).mesh_for(part)
		if mesh == null:
			_check("seat: %s is in the library" % part, false)
			continue
		# Its body's top (its stud left off, 4 up) at the plate's bottom, and 2
		# and 4 into the plate.
		for into: float in [0.0, 2.0, 4.0]:
			var origin_y: float = stud.y + into - (mesh.bounds.end.y - 4.0)
			var at: Vector3 = (Vector3(stud.x, origin_y, stud.z) - offset) * LdrModel.FLIP
			var line: String = "1 4 %.3f %.3f %.3f 1 0 0 0 1 0 0 0 1 %s.dat\n" % [at.x, at.y, at.z, part]
			var tag: String = "%s_%d" % [part, int(into)]
			var path: String = _fixture("seat_" + tag, HOME.replace("%UNDER%", line))
			if not await _at_fig_step(path):
				_check("seat %s: opens at the figure's step" % tag, false)
				continue
			var later: Dictionary = await _try(spot)
			_steps.step_forward()
			await _frames(6)
			var on: Dictionary = await _try(spot)
			var shown: bool = (on["going"] as Dictionary).is_empty()
			_result("seat.%s" % tag, "plate to come: valid %s, stands at y %.2f, put #%d; plate on show (%s): valid %s, stands at y %.2f, put #%d; undone %s %s"
				% [later["valid"], (later["G"] as Transform3D).origin.y, later["put"], shown, on["valid"],
					(on["G"] as Transform3D).origin.y, on["put"], later["restored"], on["restored"]])
			_check("seat %s: the plate to come judged as the plate on show (valid %s / %s, y %.2f / %.2f)"
				% [tag, later["valid"], on["valid"], (later["G"] as Transform3D).origin.y, (on["G"] as Transform3D).origin.y],
				shown and bool(later["valid"]) == bool(on["valid"])
				and absf((later["G"] as Transform3D).origin.y - (on["G"] as Transform3D).origin.y) < 0.5)
			_check("seat %s: undone, all as it was" % tag, bool(later["restored"]) and bool(on["restored"]))


## Lifted by the torso, aimed at [param spot] and clicked; put back by undo.
func _try(spot: Vector3) -> Dictionary:
	var f: Dictionary = _ids()
	var depth: int = _builder.history_depth()
	var before: Array = _signed(_model())
	_builder.clear_selection()
	_builder.lift_brick(int(f["torso"]))
	await _frames(4)
	var going: Dictionary = {}
	var followers: Variant = _builder.get("_figure_followers")
	if followers is Array:
		for follower: Dictionary in followers:
			going[int(follower["brick"])] = follower["at"]
	var held_parts: Array = _builder.held_figure.duplicate()
	var ghost: Transform3D = await _aim(spot)
	var valid: bool = bool(_builder.get("_ghost_valid"))
	var put: int = _builder.place()
	await _frames(3)
	if _builder.is_holding_figure():
		_builder.drop_figure()
	while _builder.history_depth() > depth:
		await _verbs.press("undo")
		await _frames(2)
	await _frames(3)
	return {"valid": valid, "put": put, "G": ghost, "going": going, "held_parts": held_parts,
		"restored": _signed(_model()) == before}


# -- the model, the timeline and the file -----------------------------------------


func _fixture(tag: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String = ProjectSettings.globalize_path(DIR + "%s.mpd" % tag)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


## Opened, the timeline in the author's steps at its start.
func _open(path: String) -> bool:
	if _steps.is_playing_back():
		_steps.stop()
	_builder.cancel_carry()
	if _builder.is_holding_figure():
		_builder.drop_figure()
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


## [param path] opened at the figure's step (its torso on, its plate to come),
## or at the last step.
func _to(path: String, at_last: bool) -> bool:
	if not await _open(path):
		return false
	if at_last:
		_steps.to_end()
		await _frames(6)
		var f: Dictionary = _ids()
		return not _ahead(int(f["torso"])) and not _ahead(int(f["plate"]))
	return await _at_fig_step(path, false)


func _at_fig_step(path: String, open: bool = true) -> bool:
	if open and not await _open(path):
		return false
	for _n: int in 12:
		var f: Dictionary = _ids()
		if int(f["torso"]) != 0 and not _ahead(int(f["torso"])) and _ahead(int(f["plate"])):
			return true
		_steps.step_forward()
		await _frames(4)
	return false


func _ids() -> Dictionary:
	var out: Dictionary = {"torso": 0, "plate": 0, "head": 0}
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("973"):
			out["torso"] = brick.id
		if brick.part_id.begins_with("3023"):
			out["plate"] = brick.id
		if brick.part_id.begins_with("3626"):
			out["head"] = brick.id
	return out


func _ahead(brick_id: int) -> bool:
	return _builder.lattice.ahead.has(brick_id)


## Every part by id: [part, colour, place, step, sub-model path].
func _model() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = [brick.part_id.get_basename(), brick.color_code,
			brick.transform.origin.snapped(Vector3.ONE * 0.01), brick.step,
			Assemblies.path_from(brick.group, brick.unit)]
	return out


static func _signed(by_id: Dictionary) -> Array:
	var out: Array = []
	for one: Array in by_id.values():
		out.append("%s %d %s step %d in %s" % one)
	out.sort()
	return out


## The parts of [param before] not found in [param after] as they were: by
## part, colour, step and sub-model, and by place too unless [param moved].
static func _differ(before: Dictionary, after: Dictionary, moved: bool) -> Array:
	var key: Callable = func(one: Array) -> String:
		return "%s %d step %d in %s" % [one[0], one[1], one[3], one[4]] if moved \
			else "%s %d %s step %d in %s" % one
	var left: Dictionary = {}
	for one: Array in after.values():
		var k: String = key.call(one)
		left[k] = int(left.get(k, 0)) + 1
	var out: Array = []
	for one: Array in before.values():
		var k: String = key.call(one)
		if int(left.get(k, 0)) > 0:
			left[k] = int(left[k]) - 1
		else:
			out.append(k)
	for k: String in left:
		for _n: int in int(left[k]):
			out.append("now: " + k)
	return out


## The timeline: how many steps, the step it is at, and each step's parts, by
## name, or with [param by_id] by brick number.
func _timeline(by_id: bool = false) -> String:
	var at: Instructions.Step = _steps.current_step()
	var out := PackedStringArray()
	for step: Instructions.Step in _steps.steps():
		var parts := PackedStringArray()
		for brick_id: int in step.brick_ids:
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			parts.append(str(brick_id) if by_id else brick.part_id.get_basename() if brick != null else "#gone")
		parts.sort()
		out.append("%d:%s" % [step.number, ",".join(parts)])
	return "%d steps at %d [%s]" % [_steps.steps().size(), at.number if at != null else -1, " ".join(out)]


## Saved under [param name] and read back: each file of it, its steps and
## their parts ("main.ldr: 3020 3003 / fig.ldr | fig.ldr: ..."); the save
## taken off after.
func _saved_steps(name: String) -> String:
	_forget(name)
	if not _store.save_as(name):
		return "(not saved)"
	var path: String = ModelStore.saved_path(name)
	var text: String = FileAccess.get_file_as_string(path)
	_forget(name)
	# Each file: [its name, its steps (each its parts joined)], the parts of
	# the step being read last. (A lambda would take these by value.)
	var files: Array = [["(no FILE)", [], []]]
	for raw: String in (text + "\n0 FILE (end)").split("\n"):
		var words: PackedStringArray = raw.strip_edges().split(" ", false)
		if words.size() >= 3 and words[0] == "0" and words[1] == "FILE":
			if files.size() == 1 and (files[0][1] as Array).is_empty() and (files[0][2] as Array).is_empty():
				files.clear()
			files.append([" ".join(words.slice(2)), [], []])
		elif words.size() >= 2 and words[0] == "0" and (words[1] == "STEP" or words[1] == "ROTSTEP"):
			(files[-1][1] as Array).append(" ".join(PackedStringArray(files[-1][2])))
			files[-1][2] = []
		elif words.size() >= 15 and words[0] == "1":
			(files[-1][2] as Array).append(" ".join(words.slice(14)).get_basename())
	var out := PackedStringArray()
	for one: Array in files.slice(0, files.size() - 1):
		var steps: Array = (one[1] as Array).duplicate()
		if not (one[2] as Array).is_empty():
			steps.append(" ".join(PackedStringArray(one[2])))
		out.append("%s: %s" % [one[0], " / ".join(PackedStringArray(steps))])
	return " | ".join(out) if not out.is_empty() else "(no FILE lines: %d bytes)" % text.length()


func _forget(name: String) -> void:
	DirAccess.remove_absolute(ModelStore.saved_path(name))
	var folder: String = ModelVersions.folder(ModelStore._safe_name(name))
	if DirAccess.dir_exists_absolute(folder):
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + file)
		DirAccess.remove_absolute(folder)


## The figure in hand aimed straight down at [param spot], aimed last in the
## frame it returns in, as a tap aims and puts down in one: where it stands.
func _aim(spot: Vector3) -> Transform3D:
	for _n: int in 4:
		_builder.update_preview(spot + Vector3(0, 4000, 0), Vector3.DOWN)
		await process_frame
	_builder.update_preview(spot + Vector3(0, 4000, 0), Vector3.DOWN)
	return _builder.get("_ghost_transform")


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS2))
	root.get_texture().get_image().save_png("%s%s_%s_%s_%s.png" % [SHOTS2, _size, _layout, _code, name])
