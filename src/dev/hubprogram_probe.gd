## Tools, Simulate mechanism's program row (APP_UX9 hubprogram): a program
## for the model's motors, played at each motor's rated speed, stopped where
## the motor stalls, kept in the model's file, and set over MCP in one call.
##
##   godot --path . --resolution 1400x900 --script src/dev/hubprogram_probe.gd
##   (tools/probe.sh hubprogram_probe; PROBE_SIZE=390x844 for the row on a phone)
##   ... -- only=older   on the build before this one: how an older build treats the file
##   ... -- only=words, plays, kept, stalls, motors or mcp runs that part alone
##
## 1. The words (HubProgram.parse): the bar's four lines (repeat 3, to 90° at
##    50%, wait 1 s, to 0° at 50%) read as a repeat of three; Pybricks' names
##    taken; a word it has not, a speed past 100%, a repeat with nothing
##    under it and a port past F each refused with its line.
## 2. It plays: a beam pinned to a SPIKE Prime large angular motor's hub (the
##    motor pinned on a stand). Simulate opened, the bar's program typed into
##    the program row and Run clicked: nine moves, each 90° in 90 / (50% of
##    175 rpm x 6) = 0.1714 s, 4.0286 s in all; in the window the beam drawn
##    at the program's angle every frame, turning 525°/s by the clock (a line
##    fitted to its first move, to 3%), at 90° three times, at 0° at the end,
##    the model never moved.
## 3. It's kept: Run made it the model's program, one step of the history;
##    Undo takes it back and Redo puts it back. Saved: one "0 !BRICKWORKS
##    PROGRAM" line in the model's head, none in its sub-model Arm's; saved
##    again byte for byte; opened again, the row shows it and a save is the
##    file byte for byte. A copy (saved under another name) carries it;
##    someone else's file with the line written by hand opens with it and
##    saves byte for byte, and a new program changes that line alone. The
##    model put into another (open_model into=true) keeps its program in its
##    sub-model, and the host's own stays the host's.
## 4. It stalls: spikemotors' rig (the motor's hub geared up 9 to an arm of
##    ten 2x8 bricks): "to 90° at 50%" stops where virtual work says the
##    motor's 25 N·cm gives out, to 1°, at Simulate's own stall to 1e-6, and
##    says so; "to -90° at 50%" stalls the same way back, to 1°.
## 5. Two motors and one on no hub: two SPIKE motors, each with its beam,
##    are A and B; a line with no port is refused naming both; "A to 90° at
##    50%" then "B to -45° at 100%" turns each its own beam in turn. A Power
##    Functions M motor is refused as on no hub.
## 6. Over MCP: simulate_mechanism program= sets and runs the program in one
##    call, said move by move with a picture; undo takes it back; words it
##    cannot read set nothing.
## 7. (only=older) src/dev/fixtures/hubprogram/arm_program.ldr, this build's
##    file of the beam with its program, opened and saved: the PROGRAM line
##    byte for byte. Run on the build before this one, it is how an older
##    build treats the file: it keeps the line as a later build's
##    (MetaIndex.unclaimed). Written so it compiles there: nothing here names
##    a class or a member that build lacks.
## On a phone (390 x 844): the row under the player, Run a fingertip tall, the
## box four lines tall, the program typed and run by finger.
## Pictures in shots/hubprogram/WxH/.
extends SceneTree

const SHOTS := "res://shots/hubprogram/"
const MODELS := "user://models/"
const FIXTURE := "res://src/dev/fixtures/hubprogram/arm_program.ldr"
const WATCHDOG := 1500.0
## The bar's program, as typed.
const BAR := "repeat 3\n  to 90° at 50%\n  wait 1 s\n  to 0° at 50%"
## The SPIKE Prime large angular motor (LEGO Education's sheet): 175 rpm
## with no load, 25 N·cm stalled, at 7.2 V.
const SPIKE_RPM := 175.0
const SPIKE_L_N_CM := 25.0
## A SPIKE motor as the rigs stand it (motion_probe): its hub facing +z.
const SPIKE_STANDS := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
const GEARED := 9.0
## N·cm for a gram lifted an LDU a radian (motion_probe).
const N_CM := 9.81 * 0.001 * 0.4 * 0.001 * 100.0
const META := "0 !BRICKWORKS PROGRAM "

var _failures: int = 0
var _out: String = ""
var _size: Vector2i
var _finger: bool = false
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _camera: CadCamera
var _verbs: Node
## The panel, untyped: what this build adds to it is called by name, so the
## probe compiles on the build before (only=older).
var _panel: Node
var _socket: CommandSocket
var _rpc_id: int = 0
var _hp: Script = null


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("hubprogram_probe: needs a window")
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(WATCHDOG).timeout.connect(func() -> void:
		print("hubprogram_probe: FAILED, not finished in %d s" % int(WATCHDOG))
		quit(1))
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_size = DisplayServer.window_get_size()
	_finger = _size.x < 1200
	if _finger:
		Phone._on = 1
		Phone._wide = _size.x >= 600
	_out = SHOTS + "%dx%d/" % [_size.x, _size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	DirAccess.make_dir_recursive_absolute(MODELS)
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.trim_prefix("only=")
	print("hubprogram_probe: a %dx%d window%s" % [_size.x, _size.y, ", laid out for a finger"
		if _finger else ""])
	await _start()
	if only == "older":
		await _older()
	elif _finger:
		await _phone()
	else:
		_hp = load("res://src/assembly/hub_program.gd")
		if only.is_empty() or only == "words":
			_words()
		if only.is_empty() or only == "plays" or only == "kept":
			await _plays()
		if only.is_empty() or only == "kept":
			await _kept()
		if only.is_empty() or only == "stalls":
			await _stalls()
		if only.is_empty() or only == "motors":
			await _motors()
		if only.is_empty() or only == "mcp":
			await _mcp()
	print("\nhubprogram_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


## The app through the sign-in screen with a throwaway account.
func _start() -> void:
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		if _main.get("_shell") != null and _main.get("_world") != null:
			break
	await _frames(60)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_camera = _main.get("_camera")
	_verbs = _main.get("_verbs")
	_panel = _main.get("_simulate")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var account: Account = _main.get("_account")
	while account.state == Account.State.CHECKING:
		await account.changed
	account.email = "hubprogram-probe@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	await _frames(20)


# -- 1. the words ---------------------------------------------------------------------------


func _words() -> void:
	print("\n1. the words")
	var program: Object = _hp.call("parse", BAR)
	var lines: Array = program.get("lines")
	var inside: Array = (lines[0] as Object).get("inside") if lines.size() == 1 else []
	_check("the bar's four lines read as one repeat of 3 holding to 90° at 50%, wait 1 s, to 0° at "
		+ "50%% (%s)" % _said_lines(lines), lines.size() == 1 and (lines[0] as Object).get("verb") == "repeat"
		and int((lines[0] as Object).get("times")) == 3 and inside.size() == 3
		and _said_lines(inside) == "to 90 50%|wait 1s|to 0 50%"
		and (program.get("errors") as PackedStringArray).is_empty())
	var pybricks: Object = _hp.call("parse", "run_target 90 at 40%\nrun_angle -30\nrun_time -20% for 500 ms")
	_check("Pybricks' names taken: run_target, run_angle (at SPIKE's 75%%), run_time in ms (%s)"
		% _said_lines(pybricks.get("lines")), _said_lines(pybricks.get("lines"))
		== "to 90 40%|turn -30 75%|run -20% 0.5s")
	for case: Array in [["spin 90°", "Line 1: \"spin\" is not one of its words"],
			["to 90° at 150%", "Line 1: a speed is 100% at most"],
			["wait 1 s\nrepeat 3\nwait 1 s", "Line 2: nothing to repeat"],
			["G to 90°", "Line 1: a hub's ports are A to F, not G"],
			["to 90° at 50%\nto ninety", "Line 2: to takes degrees"]]:
		var said: PackedStringArray = (_hp.call("parse", case[0]) as Object).get("errors")
		_check("%s refused: %s" % [str(case[0]).c_escape(), " / ".join(said)],
			said.size() == 1 and said[0].begins_with(str(case[1])))
	# Run on one motor that every move reaches: nine moves, each to its time.
	var ports: Dictionary = _hp.call("ports_of", {12: "54675"})
	var ran: Dictionary = program.call("run", ports, func(_port: String, _from: float, to: float) -> Dictionary:
		return {"at": to, "why": ""})
	var moves: Array = HubProgram.moves_of(ran)
	var move_s: float = 90.0 / (0.5 * SPIKE_RPM * 6.0)
	var each: bool = moves.size() == 9
	for move: Dictionary in moves:
		var length: float = float(move["end"]) - float(move["start"])
		each = each and absf(length - (1.0 if str(move["verb"]) == "wait" else move_s)) < 1e-6
	_check("on port A (%s), run: 9 moves, each 90° in %.4f s, each wait 1 s, %.4f s in all (worked %.4f)"
		% [ports.get("A", {}).get("name", "none"), move_s, float(ran.get("seconds", 0.0)), 3.0 * (2.0 * move_s + 1.0)],
		ports.has("A") and each and absf(float(ran.get("seconds", 0.0)) - 3.0 * (2.0 * move_s + 1.0)) < 1e-6)


func _said_lines(list: Array) -> String:
	var out := PackedStringArray()
	for one: Object in list:
		var verb: String = one.get("verb")
		match verb:
			"to", "turn":
				out.append("%s %s %s%%" % [verb, Simulation.figure(float(one.get("degrees"))),
					Simulation.figure(float(one.get("speed")))])
			"run":
				out.append("run %s%% %ss" % [Simulation.figure(float(one.get("speed"))),
					Simulation.figure(float(one.get("seconds")))])
			"wait":
				out.append("wait %ss" % Simulation.figure(float(one.get("seconds"))))
			_:
				out.append("%s %d" % [verb, int(one.get("times"))])
	return "|".join(out)


# -- 2. it plays ----------------------------------------------------------------------------


## A beam pinned upright across a SPIKE Prime large angular motor's hub, the
## motor pinned on a stand (motion_probe's rigs), [param x] across: {motor,
## beam}.
func _spike_beam(x: float, unit: String = "Arm") -> Dictionary:
	var t: float = _top_of_floor()
	var h: float = t + 326.0
	for n: int in 7:
		_flat("3003", Vector3(x, t + 24.0 * (n + 1), -50), 71)
	_flat("3738", Vector3(x, h - 150, -50), 71)
	for dx: float in [-40.0, 40.0]:
		_upright("2780", Vector3(x + dx, h - 150, -50), 0)
	var motor: int = _place("54675", Transform3D(SPIKE_STANDS, Vector3(x, h, -50)), 71, "")
	var beam: int = _place("32316", Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1),
		Vector3(0, -1, 0)), Vector3(x, h, 10)), 14, unit)
	for y: float in [20.0, -20.0]:
		_along_z("2780", Vector3(x, h + y, 0), 0, unit)
	return {"motor": motor, "beam": beam, "h": h, "t": t}


func _plays() -> void:
	print("\n2. it plays: a beam on a SPIKE Prime large angular motor's hub")
	_main.call("clear_model")
	await _frames(10)
	var rig: Dictionary = _spike_beam(0.0)
	await _frames(5)
	_camera.frame(AABB(Vector3(-160, float(rig["t"]), -160), Vector3(320, 480, 260)), 1.05)
	await _frames(10)
	var rest: Dictionary = _rest()
	var revision: int = _world.revision
	_shell.run("simulate")
	await _settled()
	var sim: Simulation = _panel.get("sim")
	var named: Dictionary = _panel.call("controls_by_name")
	var box: TextEdit = named.get("simulate_program")
	var run: Button = named.get("simulate_run")
	_check("Simulate's program row: its box and Run in the panel (%s)" % ("shown" if box != null
		and box.is_visible_in_tree() and run != null and run.is_visible_in_tree() else "not shown"),
		box != null and box.is_visible_in_tree() and run != null and run.is_visible_in_tree())
	if box == null or run == null or sim == null:
		return
	var depth: int = _builder.history_depth()
	await _click(box.get_global_rect().get_center())
	await _type_text(BAR)
	_check("the bar's program typed into the box as written (%s)" % box.text.c_escape(), box.text == BAR)
	await _shot("2_typed")
	await _click(run.get_global_rect().get_center())
	# Run clicked: sampled every frame by the clock, the beam as drawn.
	var beam: BrickWorld.Brick = _world.get_brick(int(rig["beam"]))
	var samples: Array = []   ## [seconds by the clock, the beam's angle drawn, the program's]
	var began: int = 0
	for _n: int in 6000:
		await process_frame
		var running: bool = bool(_panel.get("running"))
		if running and began == 0:
			began = Time.get_ticks_usec()
		if began == 0:
			continue
		var drawn: float = rad_to_deg(Quaternion((beam.transform.basis.inverse()
			* _world.drawn_at(beam).basis).orthonormalized()).get_angle())
		samples.append([(Time.get_ticks_usec() - began) / 1e6, drawn, float(_panel.get("turns")) * 360.0,
			float(_panel.get("program_time"))])
		if not running:
			break
	var ran: Dictionary = _panel.get("_ran")
	var moves: Array = HubProgram.moves_of(ran)
	var move_s: float = 90.0 / (0.5 * SPIKE_RPM * 6.0)
	_check("Run plays it: %d moves, %.4f s in all (worked %.4f), the panel says \"%s\"" % [moves.size(),
		float(ran.get("seconds", 0.0)), 3.0 * (2.0 * move_s + 1.0), _panel.call("said").get("program", "")],
		moves.size() == 9 and absf(float(ran.get("seconds", 0.0)) - 3.0 * (2.0 * move_s + 1.0)) < 1e-6
		and str(_panel.call("said").get("program", "")).begins_with("Ran to its end in 4.03 s"))
	# The beam drawn where the program says, every frame.
	var worst: float = 0.0
	for sample: Array in samples:
		worst = maxf(worst, absf(float(sample[1]) - absf(float(sample[2]))))
	_check("the beam drawn at the program's angle in each of %d frames (at most %.3f° apart)" % [
		samples.size(), worst], samples.size() > 20 and worst < 0.05)
	# Its speed: the beam as drawn against the run's clock (the panel's, the
	# time since Run), a line fitted to the first move's frames.
	var xs: Array = []
	var ys: Array = []
	for sample: Array in samples:
		if float(sample[3]) > move_s:
			break
		if float(sample[1]) > 2.0 and float(sample[1]) < 88.0:
			xs.append(float(sample[3]))
			ys.append(float(sample[1]))
	var slope: float = _slope(xs, ys)
	var rated: float = 0.5 * SPIKE_RPM * 6.0
	_check("the beam drawn turning %.2f°/s over the first move's %d frames by the run's clock: 50%% of the motor's %d rpm is %.1f°/s (to 0.5%%)"
		% [slope, xs.size(), int(SPIKE_RPM), rated], xs.size() >= 3 and absf(slope - rated) / rated < 0.005)
	var tops: int = 0
	var up: bool = false
	for sample: Array in samples:
		if not up and float(sample[1]) > 89.9:
			tops += 1
			up = true
		elif up and float(sample[1]) < 45.0:
			up = false
	var last: Array = samples.back() if not samples.is_empty() else [0.0, -1.0, -1.0]
	_check("at 90° three times (%d), back at 0° at the end (%.3f°), in %.2f s by the clock" % [tops,
		float(last[1]), float(last[0])], tops == 3 and absf(float(last[1])) < 0.01
		and absf(float(last[0]) - 3.0 * (2.0 * move_s + 1.0)) < 0.35)
	await _shot("2_ran")
	_check("the model never moved", _same_as(rest) and _world.revision == revision)
	var said: PackedStringArray = _builder.history_words(1)
	_check("Run made it the model's program, one step of the history (%d -> %d, \"%s\")" % [depth,
		_builder.history_depth(), said[0] if not said.is_empty() else ""], _program_now() == BAR
		and _builder.history_depth() == depth + 1 and not said.is_empty() and said[0] == "set the program")
	# And by this probe's own clock, over three seconds of frames: run 50% for
	# 3 s turns the beam 1575°, its angle followed frame to frame.
	_panel.call("set_program", "run 50% for 3 s")
	_panel.call("run_program")
	var gone: float = 0.0
	var last_drawn: float = 0.0
	xs.clear()
	ys.clear()
	began = 0
	for _n: int in 6000:
		await process_frame
		var running: bool = bool(_panel.get("running"))
		if running and began == 0:
			began = Time.get_ticks_usec()
		if began == 0:
			continue
		# The beam's turn about the hub's line (z), as drawn: where its
		# rest's x axis has gone.
		var turned: Basis = (_world.drawn_at(beam).basis * beam.transform.basis.inverse()).orthonormalized()
		var drawn: float = rad_to_deg(atan2(turned.x.y, turned.x.x))
		gone += wrapf(drawn - last_drawn, -180.0, 180.0)
		last_drawn = drawn
		if running:
			xs.append((Time.get_ticks_usec() - began) / 1e6)
			ys.append(absf(gone))
		else:
			break
	slope = _slope(xs.slice(1), ys.slice(1))
	_check("\"run 50%% for 3 s\": by this probe's clock the beam turns %.1f°/s over %d frames, %.0f° in all (worked %.1f°/s, 1575°; to 3%%)"
		% [slope, xs.size(), absf(gone), rated], xs.size() >= 20 and absf(slope - rated) / rated < 0.03
		and absf(absf(gone) - 1575.0) < 1.0)
	await _verbs.press("undo")
	await _frames(4)
	_check("...undone, the model's program is the bar's again", _program_now() == BAR
		and _builder.history_depth() == depth + 1)


static func _slope(xs: Array, ys: Array) -> float:
	var n: float = float(xs.size())
	if n < 2.0:
		return 0.0
	var sx: float = 0.0
	var sy: float = 0.0
	var sxx: float = 0.0
	var sxy: float = 0.0
	for k: int in xs.size():
		sx += float(xs[k])
		sy += float(ys[k])
		sxx += float(xs[k]) * float(xs[k])
		sxy += float(xs[k]) * float(ys[k])
	return (n * sxy - sx * sy) / (n * sxx - sx * sx)


# -- 3. it's kept ---------------------------------------------------------------------------


func _kept() -> void:
	print("\n3. it's kept")
	var box: TextEdit = (_panel.call("controls_by_name") as Dictionary).get("simulate_program")
	await _verbs.press("undo")
	await _frames(6)
	_check("Undo takes the program back: none, the box empty (\"%s\")" % box.text.c_escape(),
		_program_now().is_empty() and box.text.is_empty())
	await _verbs.press("redo")
	await _frames(6)
	_check("...Redo puts it back, in the box too", _program_now() == BAR and box.text == BAR)
	var first: String = await _save("hp_arm.ldr")
	var line: String = META + JSON.stringify({"text": BAR})
	var found: Array = _lines_with(first, META)
	_check("saved: one PROGRAM line, its text as JSON (%s)" % ", ".join(PackedStringArray(found.map(
		func(one: Array) -> String: return "line %d %s" % [one[0], str(one[1]).c_escape()]))),
		found.size() == 1 and str(found[0][1]) == line)
	var head_end: int = _first_part_line(first)
	var sub_at: int = first.split("\n").find("0 FILE arm.ldr")
	_check("...in the model's head (line %d, its first part on line %d), none in the sub-model Arm's (from line %d)"
		% [int(found[0][0]) if not found.is_empty() else -1, head_end, sub_at],
		not found.is_empty() and int(found[0][0]) < head_end and (sub_at < 0 or int(found[0][0]) < sub_at))
	var second: String = await _save("hp_arm.ldr")
	_check("saved again: byte for byte (%d bytes)" % second.length(), second == first and not first.is_empty())
	_panel.call("close")
	await _frames(4)
	_main.call("clear_model")
	await _frames(6)
	await _open(MODELS + "hp_arm.ldr")
	_check("opened again: the model's program is the text as written", _program_now() == BAR)
	_shell.run("simulate")
	await _settled()
	_check("...and the program row shows it", box.text == BAR)
	var third: String = await _save("hp_arm.ldr")
	_check("...saved unedited: the file byte for byte", third == first)
	var copy: String = await _save("hp_copy.ldr")
	_check("a copy under another name carries the same line", _lines_with(copy, META).size() == 1
		and str(_lines_with(copy, META)[0][1]) == line)
	_panel.call("close")
	await _frames(4)
	_main.call("clear_model")
	await _frames(6)
	await _open(MODELS + "hp_copy.ldr")
	_check("...and opens with the program", _program_now() == BAR)

	print("  someone else's file, the line written by hand")
	var theirs: String = ("0 Arm on a hub\n0 Name: theirs.ldr\n0 Author: Someone Else\n"
		+ "0 !BRICKWORKS PROGRAM {\"text\": \"to 90 at 50%\\nwait 1 s\\nto 0 at 50%\"}\n"
		+ _parts_of(first) + "0\n")
	_write(MODELS + "hp_theirs.ldr", theirs)
	_main.call("clear_model")
	await _frames(6)
	await _open(MODELS + "hp_theirs.ldr")
	_check("opened: its program read from the line as its author spaced it (%s)" % _program_now().c_escape(),
		_program_now() == "to 90 at 50%\nwait 1 s\nto 0 at 50%")
	var kept: String = await _save("hp_theirs.ldr")
	_check("...saved unedited: byte for byte (%s)" % ("the same" if kept == theirs
		else _first_difference(theirs, kept)), kept == theirs)
	_panel.call("set_program", "to 45° at 20%")
	await _frames(4)
	var changed: String = await _save("hp_theirs.ldr")
	var differ: Array = _changed_lines(theirs, changed)
	_check("...a new program changes its line alone (%s)" % ", ".join(PackedStringArray(differ)),
		differ.size() == 1 and str(differ[0]).contains("PROGRAM") and str(differ[0]).contains("45° at 20%"))

	print("  a later build's program: a word this build does not know, and a form it cannot read")
	for case: Array in [["hp_later_word.ldr", "{\"text\":\"beep 440 for 1 s\\nto 90 at 50%\"}",
			"its program does not run as written (Line 1: \"beep\" is not one of its words"],
			["hp_later_form.ldr", "{\"blocks\":[{\"motor\":\"A\",\"to\":90}]}",
			"a program for its motors this build cannot read, kept in the file as it is"]]:
		var later: String = ("0 Arm on a hub\n0 Name: %s\n0 Author: Someone Else\n" % case[0]
			+ "0 !BRICKWORKS PROGRAM %s\n" % case[1] + _parts_of(first) + "0\n")
		_write(MODELS + str(case[0]), later)
		_main.call("clear_model")
		await _frames(6)
		await _open(MODELS + str(case[0]))
		var note: String = ModelBar.unshown_words(_store)
		_check("%s: the open names it (\"%s\")" % [case[0], note.strip_edges().trim_prefix("— ")],
			note.contains(str(case[2])))
		var saved: String = await _save(str(case[0]))
		_check("...and a save keeps the file byte for byte (%s)" % ("the same" if saved == later
			else _first_difference(later, saved)), saved == later)

	print("  the model put into another")
	_main.call("clear_model")
	await _frames(6)
	_flat("3001", Vector3(0, _top_of_floor() + 24.0, 200), 1)
	_panel.call("set_program", "wait 2 s")
	var brought: String = await _say("open_model", {"name": "hp_arm.ldr", "into": true})
	await _settled()
	print("    %s" % brought.get_slice("\n", 0))
	_check("the host's program is still its own (%s)" % _program_now().c_escape(), _program_now() == "wait 2 s")
	var host: String = await _save("hp_host.ldr")
	var host_lines: Array = _lines_with(host, META)
	var host_head: int = _first_part_line(host)
	var in_head: Array = host_lines.filter(func(one: Array) -> bool: return int(one[0]) < host_head)
	_check("saved: the host's line in its head, the brought model's kept in its sub-model (%s)" % ", ".join(
		PackedStringArray(host_lines.map(func(one: Array) -> String: return "line %d %s" % [one[0],
			str(one[1]).c_escape()]))), host_lines.size() == 2 and in_head.size() == 1
		and str(in_head[0][1]) == META + JSON.stringify({"text": "wait 2 s"})
		and host_lines.any(func(one: Array) -> bool: return str(one[1]) == line))
	_main.call("clear_model")
	await _frames(6)
	await _open(MODELS + "hp_host.ldr")
	var again: String = await _save("hp_host.ldr")
	_check("...opened again its program is the host's, and saved byte for byte", _program_now() == "wait 2 s"
		and again == host)


# -- 4. it stalls ---------------------------------------------------------------------------


func _stalls() -> void:
	print("\n4. it stalls: spikemotors' rig, the hub geared up 9 to an arm of ten 2x8 bricks")
	_panel.call("close")
	_main.call("clear_model")
	await _frames(10)
	var t: float = _top_of_floor()
	var h: float = t + 326.0
	for n: int in 7:
		_flat("3003", Vector3(0, t + 24.0 * (n + 1), -50), 71)
	_flat("3738", Vector3(0, h - 150, -50), 71)
	for x: float in [-40.0, 40.0]:
		_upright("2780", Vector3(x, h - 150, -50), 0)
	var motor: int = _place("54675", Transform3D(SPIKE_STANDS, Vector3(0, h, -50)), 71, "")
	var rig: Dictionary = _geared_arm(t, h, "3007", 10, 80.0)
	await _frames(5)
	_camera.frame(AABB(Vector3(-200, t, -200), Vector3(520, 680, 340)), 1.05)
	await _frames(10)
	_shell.run("simulate")
	await _settled()
	var sim: Simulation = _panel.get("sim")
	# Worked as motion_probe works it: the arm's weight's moment standing up,
	# geared 9, against the motor's 25 N·cm.
	var pivot: Vector3 = rig["pivot"]
	var moment: float = 0.0
	for key: int in rig["arm"]:
		var brick: BrickWorld.Brick = _world.get_brick(key)
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		moment += Stability.grams(_library.parts[brick.part_id]) * ((brick.transform * mesh.bounds.get_center()) - pivot).y
	var most: float = GEARED * moment * N_CM
	var share: float = SPIKE_L_N_CM / most
	var worked: float = (180.0 + rad_to_deg(asin(share))) / GEARED
	var stall: Dictionary = sim.stall if sim != null else {}
	print("    worked: the arm asks %.2f N·cm at most through the 9 up; the motor gives %s, so it stalls at %.3f° of its turn"
		% [most, Simulation.figure(SPIKE_L_N_CM), worked])
	for way: float in [1.0, -1.0]:
		_panel.call("set_program", "to %d° at 50%%" % int(90.0 * way))
		_panel.call("run_program")
		for _n: int in 3000:
			await process_frame
			if not bool(_panel.get("running")) and not bool(_panel.get("_preparing")):
				break
		var ran: Dictionary = _panel.get("_ran")
		var stopped: Dictionary = ran.get("stopped", {})
		var at: float = float(stopped.get("at", INF)) * 360.0
		var drawn_turns: float = float(_panel.get("turns")) * 360.0
		var said: String = str(_panel.call("said").get("program", ""))
		print("    %s" % said)
		_check(("\"to %d° at 50%%\" stops at %.3f° of the motor's turn, worked %.3f°, %.3f° apart (to 1°)%s; "
			+ "drawn there (%.3f°), and said: line 1, stalls, its 25 N·cm") % [int(90.0 * way), at, worked * way,
			absf(at - worked * way), (", Simulate's own stall %.6f°" % (float(stall.get("turns", INF)) * 360.0))
				if way > 0.0 else " going back", drawn_turns],
			absf(at - worked * way) < 1.0 and absf(drawn_turns - at) < 1e-6 and said.begins_with("Line 1:")
			and said.contains("stalls") and said.contains("25 N·cm")
			and (way < 0.0 or absf(at - float(stall.get("turns", INF)) * 360.0) < 1e-6))
		await _shot("4_stalled_%s" % ("on" if way > 0.0 else "back"))
	_check("...the motor's own: the program names it", str(_panel.call("said").get("program", "")).contains(
		"A, the SPIKE Prime large angular motor #%d" % motor))


func _geared_arm(t: float, h: float, load: String, count: int, load_z: float) -> Dictionary:
	for n: int in roundi((h - 14.0 - t) / 24.0):
		_flat("3008", Vector3(40, t + 24.0 * (n + 1), 50), 71)
	_flat("3702", Vector3(40, h + 10, 50), 71)
	var output: int = _along_z("3705", Vector3(0, h, 20), 0)
	_along_z("4519", Vector3(40, h, 30), 0)
	var last: int = _along_z("4519", Vector3(80, h, 50), 0)
	_flat("3648a", Vector3(0, h, 10), 72)
	_flat("3647", Vector3(40, h, 10), 14)
	_flat("3648a", Vector3(40, h, 30), 72)
	_flat("3647", Vector3(80, h, 30), 14)
	var arm: Array = [_flat("32064b", Vector3(80, h + 10, 70), 4, "Arm")]
	for n: int in 2:
		arm.append(_flat("3004", Vector3(80, h + 10 + 24.0 * (n + 1), 70), 4, "Arm"))
	for n: int in count:
		arm.append(_flat(load, Vector3(80, h + 58 + 24.0 * (n + 1), load_z), 1, "Arm"))
	return {"output": output, "last": last, "arm": arm, "pivot": Vector3(80, h, 70)}


# -- 5. two motors, and one on no hub ------------------------------------------------------


func _motors() -> void:
	print("\n5. two motors, and one on no hub")
	_panel.call("close")
	_main.call("clear_model")
	await _frames(10)
	var one: Dictionary = _spike_beam(0.0, "Arm")
	var two: Dictionary = _spike_beam(240.0, "Other arm")
	await _frames(5)
	_camera.frame(AABB(Vector3(-160, float(one["t"]), -160), Vector3(560, 480, 260)), 1.05)
	await _frames(10)
	_shell.run("simulate")
	await _settled()
	_panel.call("set_program", "to 90° at 50%")
	await _panel.call("run_program")
	await _frames(4)
	var said: String = str(_panel.call("said").get("program", ""))
	_check("a line with no port, two motors on the hub: refused, naming A and B (%s)" % said,
		said.contains("Line 1 names no motor") and said.contains("A, the SPIKE Prime large angular motor #%d"
			% int(one["motor"])) and said.contains("B, the SPIKE Prime large angular motor #%d" % int(two["motor"])))
	_panel.call("set_program", "A to 90° at 50%\nB to -45° at 100%")
	_panel.call("run_program")
	for _n: int in 3000:
		await process_frame
		if not bool(_panel.get("running")) and not bool(_panel.get("_preparing")):
			break
	var ran: Dictionary = _panel.get("_ran")
	var moves: Array = HubProgram.moves_of(ran)
	var worked: float = 90.0 / (0.5 * SPIKE_RPM * 6.0) + 45.0 / (SPIKE_RPM * 6.0)
	var a: BrickWorld.Brick = _world.get_brick(int(one["beam"]))
	var b: BrickWorld.Brick = _world.get_brick(int(two["beam"]))
	var a_at: float = rad_to_deg(Quaternion((a.transform.basis.inverse() * _world.drawn_at(a).basis).orthonormalized()).get_angle())
	var b_at: float = rad_to_deg(Quaternion((b.transform.basis.inverse() * _world.drawn_at(b).basis).orthonormalized()).get_angle())
	_check("A then B, each its own beam: A's at %.2f°, B's at %.2f° (45° back), in %.4f s (worked %.4f): %s"
		% [a_at, b_at, float(ran.get("seconds", 0.0)), worked, _panel.call("said").get("program", "")],
		moves.size() == 2 and str(moves[0]["port"]) == "A" and str(moves[1]["port"]) == "B"
		and absf(a_at - 90.0) < 0.05 and absf(b_at - 45.0) < 0.05
		and absf(float(ran.get("seconds", 0.0)) - worked) < 1e-6)
	await _shot("5_two_motors")
	# A Power Functions M motor: on no hub.
	_panel.call("close")
	_main.call("clear_model")
	await _frames(10)
	var t: float = _top_of_floor()
	for z: float in [-100.0, -60.0, -20.0]:
		for n: int in 10:
			_flat("3003", Vector3(0, t + 24.0 * (n + 1), z), 71)
		_flat("3022", Vector3(0, t + 248, z), 71)
	var h: float = t + 278.0
	var pf: int = _flat("58120c01", Vector3(0, h, 0), 71)
	_geared_arm(t, h, "3008", 8, 70.0)
	await _frames(5)
	_shell.run("simulate")
	await _settled()
	_panel.call("set_program", "to 90° at 50%")
	await _panel.call("run_program")
	await _frames(4)
	said = str(_panel.call("said").get("program", ""))
	_check("a Power Functions M motor: refused as on no hub (%s)" % said,
		said.contains("Power Functions M motor #%d plugs into no hub" % pf) and said.contains("Play turns it"))


# -- 6. over MCP ----------------------------------------------------------------------------


func _mcp() -> void:
	print("\n6. over MCP")
	_panel.call("close")
	_main.call("clear_model")
	await _frames(10)
	_spike_beam(0.0)
	await _frames(10)
	var depth: int = _builder.history_depth()
	var program: String = "to 90° at 50%\nwait 1 s\nto 0° at 50%"
	var answer: Array = await _say_all("simulate_mechanism", {"program": program})
	var text: String = answer[0]
	print("    " + text.replace("\n", "\n    "))
	_check("simulate_mechanism program= sets it and runs it in 1 call: set and kept, ran to its end in 1.34 s, move by move, a picture",
		text.begins_with("Set as the model's program") and text.contains("Ran to its end in 1.34 s")
		and text.contains("line 1: A from 0° to 90° at 50% (525°/s)") and bool(answer[1])
		and _program_now() == program and _builder.history_depth() == depth + 1)
	var undone: String = await _say("undo", {})
	_check("undo takes it back (%s)" % undone.get_slice("\n", 0), _program_now().is_empty()
		and undone.contains("set the program"))
	var refused: String = await _say("simulate_mechanism", {"program": "spin 3"})
	_check("words it cannot read set nothing (%s)" % refused.get_slice("\n", 0),
		refused.begins_with("The program was not set: Line 1:") and _program_now().is_empty())


# -- 7. as an older build treats the file ---------------------------------------------------


func _older() -> void:
	print("\n7. the file of the beam with its program, opened and saved")
	var fixture: String = FileAccess.get_file_as_string(FIXTURE)
	_write(MODELS + "hp_fixture.ldr", fixture)
	_main.call("clear_model")
	await _frames(6)
	await _open(MODELS + "hp_fixture.ldr")
	_check("opened whole: %d parts" % (_world.brick_count() - _store.scenery.size()),
		_world.brick_count() - _store.scenery.size() == 14)
	var line: Array = _lines_with(fixture, META)
	var saved: String = await _save("hp_fixture.ldr")
	var kept: Array = _lines_with(saved, META)
	_check("...saved: the PROGRAM line kept byte for byte, where the file had it (%s)" % (
		"line %d" % int(kept[0][0]) if kept.size() == 1 else "%d lines" % kept.size()),
		line.size() == 1 and kept.size() == 1 and str(kept[0][1]) == str(line[0][1])
		and int(kept[0][0]) == int(line[0][0]))
	_check("...and the file byte for byte (%s)" % ("the same" if saved == fixture
		else _first_difference(fixture, saved)), saved == fixture)


# -- on a phone -----------------------------------------------------------------------------


func _phone() -> void:
	print("\nthe program row on a phone")
	_main.call("clear_model")
	await _frames(10)
	var rig: Dictionary = _spike_beam(0.0)
	await _frames(10)
	_shell.run("simulate")
	await _settled()
	var named: Dictionary = _panel.call("controls_by_name")
	var box: TextEdit = named.get("simulate_program")
	var run: Button = named.get("simulate_run")
	var play: Button = named.get("simulate_play")
	var screen: Rect2 = root.get_visible_rect()
	var target: float = Phone.px(root, Phone.TARGET)
	_check("the row under the player: Run beside its title (%s), the box below Play (%s)" % [
		run.get_global_rect() if run != null else "none", box.get_global_rect() if box != null else "none"],
		run != null and box != null and play != null and box.get_global_rect().position.y > play.get_global_rect().end.y
		and screen.encloses(run.get_global_rect()) and run.is_visible_in_tree() and box.is_visible_in_tree())
	_check("Run a fingertip tall (%.0f px of %.0f), the box four lines of 14-point type (%.0f px tall)" % [
		run.size.y, target, box.size.y], run.size.y >= target - 0.5 and box.size.y >= 4 * 22)
	# Tapped where it shows: the panel scrolls, so the box may show only its
	# first line at the panel's foot.
	var scroll: Node = box.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	var view: Rect2 = (scroll as Control).get_global_rect() if scroll != null else screen
	var shown: Rect2 = box.get_global_rect().intersection(view)
	_check("the box shows at the panel's foot (%.0f of its %.0f px)" % [shown.size.y, box.size.y],
		shown.size.y >= 12.0)
	var before: int = (scroll as ScrollContainer).scroll_vertical if scroll != null else 0
	await _click(shown.get_center())
	await _frames(10)
	shown = box.get_global_rect().intersection((scroll as Control).get_global_rect() if scroll != null
		else screen)
	_check("tapped there, it comes whole into the panel's view once the finger lifts (%.0f of %.0f px,"
		% [shown.size.y, box.size.y] + " the panel scrolled %d px, no further)"
		% [((scroll as ScrollContainer).scroll_vertical if scroll != null else 0) - before],
		box.has_focus() and shown.size.y >= box.size.y - 1.0
		and shown.end.y >= view.end.y - box.size.y - 1.0)
	await _type_text("to 90° at 50%\nwait 1 s\nto 0° at 50%")
	await _shot("phone_typed")
	var run_shown: Rect2 = run.get_global_rect().intersection(view)
	await _click(run_shown.get_center() if run_shown.has_area() else run.get_global_rect().get_center())
	for _n: int in 3000:
		await process_frame
		if not bool(_panel.get("running")) and not bool(_panel.get("_preparing")) and _n > 5:
			break
	var said: String = str(_panel.call("said").get("program", ""))
	_check("typed and run by finger: %s" % said, said.begins_with("Ran to its end in 1.34 s"))
	await _shot("phone_ran")
	if rig.is_empty():
		return


# -- building -------------------------------------------------------------------------------


func _top_of_floor() -> float:
	var top: float = -INF
	for id: Variant in _store.scenery:
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		if brick == null:
			continue
		var box: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		var studs: float = 4.0 if _library.parts[brick.part_id].stud_count > 0 else 0.0
		top = maxf(top, box.end.y - studs)
	return top if top > -INF else 0.0


func _place(part_id: String, at: Transform3D, colour: int, unit: String) -> int:
	var id: int = _world.add_brick(part_id, colour, at)
	_builder.register(id, part_id, at)
	if not unit.is_empty():
		_world.get_brick(id).unit = unit + "#1"
		_world.get_brick(id).group = Assemblies.group_of(unit + "#1")
	return id


func _flat(part_id: String, at: Vector3, colour: int, unit: String = "") -> int:
	return _place(part_id, Transform3D(Basis.IDENTITY, at), colour, unit)


func _along_z(part_id: String, at: Vector3, colour: int, unit: String = "") -> int:
	return _place(part_id, Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0),
		Vector3(-1, 0, 0)), at), colour, unit)


func _upright(part_id: String, at: Vector3, colour: int, unit: String = "") -> int:
	return _place(part_id, Transform3D(Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0),
		Vector3(0, 0, 1)), at), colour, unit)


func _rest() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


func _same_as(rest: Dictionary) -> bool:
	for id: Variant in rest:
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		if brick == null or not brick.transform.is_equal_approx(rest[id]):
			return false
	return _world.bricks().size() == rest.size()


# -- files ----------------------------------------------------------------------------------


func _program_now() -> String:
	return str(_world.get("program")) if _world.get("program") != null else ""


## The model saved to [param file] in the app's models as Save writes it
## (main.save_model; save_model over MCP refuses a file it did not write).
func _save(file: String) -> String:
	if not bool(_main.call("save_model", MODELS + file)):
		print("    could not write %s" % file)
		return ""
	await _settled()
	return FileAccess.get_file_as_string(MODELS + file)


func _open(path: String) -> void:
	_main.call("_open", path)
	await _settled()


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Each line of [param text] beginning [param start]: [its index, the line].
static func _lines_with(text: String, start: String) -> Array:
	var out: Array = []
	var lines: PackedStringArray = text.split("\n")
	for n: int in lines.size():
		if lines[n].begins_with(start):
			out.append([n, lines[n].trim_suffix("\r")])
	return out


## The index of the first part line ("1 ...") of [param text].
static func _first_part_line(text: String) -> int:
	var lines: PackedStringArray = text.split("\n")
	for n: int in lines.size():
		if lines[n].begins_with("1 "):
			return n
	return lines.size()


## The part lines of the model's own section of [param text], each with its
## line end, as another program would write them in a file of one section.
static func _parts_of(text: String) -> String:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with("0 FILE ") and not out.is_empty():
			break
		if line.begins_with("1 ") and not line.to_lower().ends_with(".ldr"):
			out.append(line)
	return "\n".join(out) + "\n"


static func _changed_lines(before: String, after: String) -> Array:
	var a: PackedStringArray = before.split("\n")
	var b: PackedStringArray = after.split("\n")
	var out: Array = []
	if a.size() != b.size():
		return ["%d lines became %d" % [a.size(), b.size()]]
	for n: int in a.size():
		if a[n] != b[n]:
			out.append("line %d: %s" % [n, b[n]])
	return out


static func _first_difference(a: String, b: String) -> String:
	var n: int = 0
	while n < mini(a.length(), b.length()) and a[n] == b[n]:
		n += 1
	return "differ at %d: %s | %s" % [n, a.substr(maxi(n - 20, 0), 60).c_escape(),
		b.substr(maxi(n - 20, 0), 60).c_escape()]


# -- driving the window ---------------------------------------------------------------------


func _settled() -> void:
	for _n: int in 600:
		if _store == null or _store.awaited.is_empty():
			break
		await process_frame
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 600000:
		await process_frame
		if not Working.is_busy() and (not _panel.visible or (_panel.get("sim") != null
				and not bool(_panel.get("_reading")) and not bool(_panel.get("_driving")))):
			break
	await _frames(10)


func _say(tool: String, arguments: Dictionary) -> String:
	return str((await _say_all(tool, arguments))[0])


## [param tool]'s answer: [its text, whether it carried a picture].
func _say_all(tool: String, arguments: Dictionary) -> Array:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	var pictured: bool = false
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
		pictured = pictured or str(block.get("type", "")) == "image"
	if text.is_empty() and (answer as Dictionary).has("error"):
		text = str((answer as Dictionary)["error"])
	var lines: PackedStringArray = text.split("\n")
	while lines.size() > 1 and (lines[0].begins_with("Tab ") or lines[0].begins_with("Careful")):
		lines.remove_at(0)
	return ["\n".join(lines), pictured]


## [param words] typed, a key a letter, Return for each line end.
func _type_text(words: String) -> void:
	for n: int in words.length():
		var key := InputEventKey.new()
		key.pressed = true
		if words[n] == "\n":
			key.keycode = KEY_ENTER
			key.physical_keycode = KEY_ENTER
		else:
			key.unicode = words.unicode_at(n)
		Input.parse_input_event(key)
		await process_frame
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
	await _frames(4)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(3)


func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out + name + ".png"))
	print("    picture: %s%s.png" % [_out.trim_prefix("res://"), name])
