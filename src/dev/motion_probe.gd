## Tools, Simulate mechanism: where the motion stops (docs/MECHANISMS.md,
## section 39), in the real scene, as a person uses it.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1400x900x24" godot --path . \
##     --resolution 1400x900 --script src/dev/motion_probe.gd
##   ... and at 1280x720 (PROBE_SIZE=1280x720 bash tools/probe.sh motion_probe)
##   ... -- only=arm, only=fourbar, only=motor, only=spike, only=loose, only=pul,
##   only=hub or only=pieces runs that model alone
##
## Eight models, built here part by part on the baseplate:
##   - an arm on an axle through a Technic brick, turned by its sub-assembly's
##     name (Crank): alone it goes round either way and nothing meets; then a
##     beam is stood where the arm's face lies at 140° of its turn, and the
##     panel says the arm meets it there, to within 2°, tints the two red,
##     and Play, the slider and Go to the stop go no further;
##   - a four-bar on four pins (ground 120, crank 40, coupler 80, rocker 40,
##     the crank pointing at the rocker's pivot): no link goes round, and the
##     crank's range is +-acos(1/6), 160.81° in all, to within 1°;
##   - a Power Functions M motor geared up 9 to an arm of eight 1x8 bricks
##     standing up: the motor turns it (it marks the driver), the arm goes down
##     and over, and lifting it the motor stalls where the weight asks more
##     than its 11 N·cm, the angle worked from the parts' weight and the teeth;
##     the bricks taken off, the same motor turns it and says how fast;
##   - a SPIKE Prime large angular motor (25 N·cm at 7.2 V, LEGO's sheet),
##     held by two pins through its underside to a Technic plate on a column,
##     its hub's axle geared up 9 to an arm of ten 2x8 bricks: its case is the
##     base, the arm stalls where the virtual work says, to 1°, the working
##     said (the arm's weight, how far its middle stands from its axle, the
##     torque), and unloaded the motor turns it at its 175 rpm; over MCP
##     simulate_mechanism says the same stall;
##   - the same SPIKE motor and arm with the column, the plate and the two
##     pins left out, its case hanging on its output's axle and on nothing
##     the base holds (mcpreach2's y6): its case goes round with what it
##     turns, so nothing is weighed against it, and the panel and
##     simulate_mechanism both say NOT FIXED and to fix its body to the
##     frame, never "nothing to lift" or a stall;
##   - a Powered Up L motor (26 N·cm at 9 V, Hurbain's), held by two long
##     pins through it to a Technic plate, on the same train and arm: the
##     same, to 1°;
##   - a beam pinned by two pins to a SPIKE Prime medium angular motor's hub
##     (no axle): the hub turns in the case, so the beam is the driver,
##     turning on the hub's line, the pins going round through the hub
##     without meeting it, and the motor said by name at 7.2 V;
##   - a Technic large angular motor drawn in its pieces, as 42114-1's
##     steering motor is: a sub-model "69730" of its case's four pieces and
##     its hub, pinned on the stand, an axle in its hub: the hub turns the
##     axle in the pieces, held with the base as one case, and the motor is
##     said by name at 9 V.
## Simulating never changes the model: every part stands where it was built,
## the undo history is as deep, and the model's revision has not moved.
## What the simulation found is read by name, so on a build without it the
## probe runs to its end and fails (the pictures then show that build).
## Pictures in shots/motion/, named by the window's size.
extends SceneTree

const SHOTS := "res://shots/motion"
## The arm's face meets the beam at this turn of the arm, degrees.
const WALL_AT := 140.0
## The four-bar: ground, crank, coupler and rocker, LDU.
const GROUND := 120.0
const CRANK := 40.0
const COUPLER := 80.0
const ROCKER := 40.0
## The motor's gearing: two 24s driving two 8s.
const GEARED := 9.0
## A Power Functions M motor's stall torque at 9 V, N·cm (Philo's table).
const M_MOTOR_N_CM := 11.0
## The SPIKE Prime large angular motor's at 7.2 V (LEGO Education's sheet
## for 45602) and the Powered Up L's at 9 V (Hurbain's, extrapolated).
const SPIKE_L_N_CM := 25.0
const PU_L_N_CM := 26.0
## A SPIKE motor as the rigs stand it: its hub (+y in its own frame) facing
## +z, its body hanging below the hub's line (its own -z down).
const SPIKE_STANDS := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
## The Powered Up L on its side: its output still along +z, the holes through
## it (along its own x) upright.
const PU_STANDS := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
## N·cm for a gram lifted an LDU (0.4 mm) a radian: 9.81 m/s², a kilogram
## a thousand grams, a metre a hundred cm.
const N_CM := 9.81 * 0.001 * 0.4 * 0.001 * 100.0

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _shell: Shell
var _verbs: EditVerbs
var _store: ModelStore
var _panel: SimulatePanel
var _size: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
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
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	_store = _main.get("_store")
	_panel = _main.get("_simulate")
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	if not StudioRender.possible():
		print("motion: needs a window (xvfb-run); nothing checked")
		quit(1)
		return
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.trim_prefix("only=")
	if only.is_empty() or only == "arm":
		await _arm_and_wall()
	if only.is_empty() or only == "fourbar":
		await _four_bar()
	if only.is_empty() or only == "motor":
		await _motor()
	if only.is_empty() or only == "spike":
		await _spike_large()
	if only.is_empty() or only == "loose":
		await _spike_loose()
	if only.is_empty() or only == "pul":
		await _powered_up_l()
	if only.is_empty() or only == "hub":
		await _hub_pins()
	if only.is_empty() or only == "pieces":
		await _in_pieces()
	print("")
	if _failures == 0:
		print("motion: an arm meeting a beam at 140° said there, a four-bar's range against its "
			+ "closed form, a Power Functions M, a SPIKE Prime large and a Powered Up L motor "
			+ "that stall lifting their load said and stopped at, a motor on nothing the base "
			+ "holds said NOT FIXED, a beam pinned to a SPIKE hub "
			+ "turned by it, a motor drawn in its pieces turning its hub, and the model never moved")
	else:
		print("motion: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- an arm and a wall ---------------------------------------------------------------------


func _arm_and_wall() -> void:
	print("  an arm on an axle, alone, then with a beam where it lies at %d°" % int(WALL_AT))
	_main.call("clear_model")
	await _frames(10)
	var t: float = _top_of_floor()
	# A Technic brick on seven bricks, its hole 182 up, the axle through it
	# along z; the arm keyed on the axle in front, four bricks on it, standing up.
	for n: int in 7:
		_flat("3004", Vector3(0, t + 24.0 * (n + 1), -10), 71)
	_flat("3700", Vector3(0, t + 192, -10), 71)
	var pivot := Vector3(0, t + 182, 10)
	_along_z("3705", Vector3(0, pivot.y, 0), 0, "Crank")
	var arm: Array = [_flat("32064b", Vector3(0, pivot.y + 10, 10), 4, "Crank")]
	for n: int in 4:
		arm.append(_flat("3004", Vector3(0, pivot.y + 10 + 24.0 * (n + 1), 10), 4, "Crank"))
	await _frames(5)
	_camera.frame(AABB(Vector3(-170, t, -40), Vector3(340, 320, 80)), 1.1)
	await _frames(10)
	_shell.run("simulate")
	await _settled()
	var sim: Simulation = _panel.sim
	_check("the arm is the driver, marked by its name (%s)" % _panel.said()["driver"],
		sim != null and sim.driver == sim.model.body_of(arm[0])
		and str(_panel.said()["driver"]).contains("marks"))
	var stops: String = _stops_said()
	_check("alone it goes round either way and nothing meets: %s" % stops.replace("\n", " | "),
		_found(sim, "meets").is_empty() and _found(sim, "meets_back").is_empty()
		and stops.contains("all the way round"))
	var stop_button: Button = _panel.controls_by_name().get("simulate_stop")
	_check("...and Go to the stop has nowhere to go", stop_button != null and stop_button.disabled)
	await _shot("1_arm_alone")
	# Which way the arm turns going on: its top goes to -x turning anticlockwise
	# about +z, seen from the front.
	var top: int = arm[arm.size() - 1]
	var went: float = ((sim.placed(0.05)[top] as Transform3D).origin.x
		- _world.get_brick(top).transform.origin.x)
	var way: float = 1.0 if went < 0.0 else -1.0

	# The beam: its near face on the line the arm's leading face lies on at
	# WALL_AT, 20 out from the axle, from 30 to 168 along the arm.
	var turned := Basis(Vector3(0, 0, 1), deg_to_rad(way * WALL_AT))
	var along: Vector3 = turned * Vector3.UP
	var ahead: Vector3 = turned * Vector3(-way, 0, 0)
	var middle: Vector3 = pivot + ahead * 29.0 + along * 99.0
	var wall: int = _place("32524", Transform3D(Basis(ahead, Vector3(0, 0, 1),
		ahead.cross(Vector3(0, 0, 1))), middle), 1, "Stand")
	await _frames(3)
	await _settled()
	sim = _panel.sim
	var rest: Dictionary = _rest()
	var depth: int = _builder.history_depth()
	var revision: int = _world.revision
	stops = _stops_said()
	print("    stops: %s" % stops.replace("\n", " | "))
	var meets: Dictionary = _found(sim, "meets")
	var met: float = float(meets.get("turns", INF))
	_check("the panel says the arm meets the beam at %.2f° of its turn, built at %d° (to 2°)"
		% [met * 360.0, int(WALL_AT)], absf(met * 360.0 - WALL_AT) <= 2.0
		and stops.contains("MEETS") and stops.contains("#%d" % wall)
		and int(meets.get("other", 0)) == wall and arm.has(int(meets.get("key", 0))))
	_check("...not before: at %.2f° every part is clear" % (float(meets.get("clear", 0.0))
		* 360.0), float(meets.get("clear", -INF)) * 360.0 > WALL_AT - 2.0
		and sim.has_method("_meeting")
		and (sim.call("_meeting", sim.placed(float(meets.get("clear", 0.0)))) as Dictionary).is_empty())
	var back: Dictionary = _found(sim, "meets_back")
	_check("going back it meets the beam's other side (at %.2f°)"
		% (float(back.get("turns", 0.0)) * 360.0), int(back.get("other", 0)) == wall
		and float(back.get("turns", 0.0)) < 0.0)
	var tints: Dictionary = _world.tinted_ids()
	_check("the arm's brick and the beam that meet are tinted red",
		tints.get(wall) == Simulation.LOCKED and tints.get(int(meets.get("key", 0))) == Simulation.LOCKED)
	_check("Go to the stop is there to press", stop_button != null and not stop_button.disabled)
	if stop_button != null:
		await _click(stop_button.get_global_rect().get_center())
		await _frames(3)
	_check("Go to the stop turns the arm to where it meets (%.2f°) and says so: %s" % [
		_panel.turns * 360.0, _panel.said()["status"]], absf(_panel.turns - met) < 1e-9
		and str(_panel.said()["status"]).contains("meets") and _drawn_as(sim.placed(_panel.turns)))
	await _shot("2_arm_meets")
	var scrub: HSlider = _panel.controls_by_name()["simulate_scrub"]
	scrub.value = scrub.max_value * 0.9
	await _frames(3)
	_check("the slider goes no further than where it meets (%.2f°)" % (_panel.turns * 360.0),
		_panel.turns <= met + 1e-9)
	scrub.value = 0.0
	await _frames(3)
	var play: Button = _panel.controls_by_name()["simulate_play"]
	await _click(play.get_global_rect().get_center())
	for _n: int in 1200:
		await process_frame
		if not _panel.playing:
			break
	_check("Play stops where it meets (%.2f°): %s" % [_panel.turns * 360.0,
		_panel.said()["status"]], not _panel.playing and absf(_panel.turns - met) < 1e-9
		and str(_panel.said()["status"]).begins_with("Stopped at"))
	if _panel.playing:
		await _click(play.get_global_rect().get_center())
	_check("the model never moved: every part where it was built",
		_same_as(rest) and _world.revision == revision and _builder.history_depth() == depth)
	_panel.close()
	await _frames(3)


# -- a four-bar ----------------------------------------------------------------------------


func _four_bar() -> void:
	print("  a four-bar on four pins: ground %d, crank %d, coupler %d, rocker %d" % [
		int(GROUND), int(CRANK), int(COUPLER), int(ROCKER)])
	_main.call("clear_model")
	await _frames(10)
	var t: float = _top_of_floor()
	# The ground: a 1x8 Technic brick on three bricks, its holes 86 up; the
	# crank and the rocker on pins in its end holes, 120 apart.
	for n: int in 3:
		_flat("3008", Vector3(0, t + 24.0 * (n + 1), -10), 71)
	_flat("3702", Vector3(0, t + 96, -10), 71)
	var a := Vector3(-GROUND * 0.5, t + 86, 0)
	var b := Vector3(GROUND * 0.5, t + 86, 0)
	# The crank pointing at the rocker's pivot; the coupler and the rocker
	# closing the loop above the ground.
	var p: Vector3 = a + Vector3(CRANK, 0, 0)
	var q_x: float = (COUPLER * COUPLER - ROCKER * ROCKER + (GROUND - CRANK) * (GROUND - CRANK)) \
		/ (2.0 * (GROUND - CRANK))
	var q: Vector3 = p + Vector3(q_x, sqrt(COUPLER * COUPLER - q_x * q_x), 0)
	for at: Vector3 in [a, b]:
		_along_z("3673", at, 0)
	for at: Vector3 in [p, q]:
		_along_z("3673", at + Vector3(0, 0, 20), 0)
	var crank: int = _link("32523", a, p, 10.0, 4, "Crank")
	var coupler: int = _link("32316", p, q, 30.0, 14, "Coupler")
	var rocker: int = _link("32523", b, q, 10.0, 1, "Rocker")
	await _frames(5)
	_camera.frame(AABB(Vector3(-130, t, -40), Vector3(260, 200, 80)), 1.1)
	await _frames(10)
	var rest: Dictionary = _rest()
	var depth: int = _builder.history_depth()
	var revision: int = _world.revision
	_shell.run("simulate")
	await _settled()
	var sim: Simulation = _panel.sim
	print("    driver: %s" % _panel.said()["driver"])
	_check("the crank is the driver and turns the loop as a drag does (%s)" % (
		"its loop" if sim != null and sim.grab != null else sim.grab_note if sim != null else "?"),
		sim != null and sim.driver == sim.model.body_of(crank) and sim.grab != null
		and sim.grab.linkage != null and sim.moving.has(coupler) and sim.moving.has(rocker))
	var stops: String = _stops_said()
	print("    stops: %s" % stops.replace("\n", " | "))
	# Worked: the crank's far pin is at most coupler + rocker from the
	# rocker's pivot, cos(limit) = (g² + a² - (b + c)²) / (2ga), either way.
	var limit: float = rad_to_deg(acos((GROUND * GROUND + CRANK * CRANK
		- (COUPLER + ROCKER) * (COUPLER + ROCKER)) / (2.0 * GROUND * CRANK)))
	var reach: Vector2 = _found(sim, "loop_reach", Vector2(-INF, INF))
	var on: float = reach.y * 360.0
	var back: float = reach.x * 360.0
	_check("the crank goes %.3f° on and %.3f° back, %.3f° in all, against +-%.3f°, %.3f° (to 1°)"
		% [on, back, on - back, limit, 2.0 * limit], absf(on - limit) <= 1.0
		and absf(-back - limit) <= 1.0 and absf((on - back) - 2.0 * limit) <= 1.0)
	_check("...said as its range, stopped by the loop at each end", stops.contains("Range of")
		and stops.contains("in all") and stops.contains("the loop it closes goes no further")
		and _found(sim, "meets").is_empty() and _found(sim, "meets_back").is_empty())
	var stop_button: Button = _panel.controls_by_name().get("simulate_stop")
	if stop_button != null:
		await _click(stop_button.get_global_rect().get_center())
		await _frames(3)
	_check("Go to the stop turns the crank to the end of its range (%.2f°): %s" % [
		_panel.turns * 360.0, _panel.said()["status"]], absf(_panel.turns - reach.y) < 1e-9
		and str(_panel.said()["status"]).contains("goes no further"))
	await _shot("3_four_bar_end")
	_check("the model never moved", _same_as(rest) and _world.revision == revision
		and _builder.history_depth() == depth)
	_panel.close()
	await _frames(3)


## A beam from the hole at [param from] to the hole at [param to], its
## holes along z, its middle at [param z].
func _link(part_id: String, from: Vector3, to: Vector3, z: float, colour: int, unit: String) -> int:
	var way: Vector3 = (to - from).normalized()
	var middle: Vector3 = (from + to) * 0.5
	middle.z = z
	return _place(part_id, Transform3D(Basis(Vector3(0, 0, 1).cross(way), Vector3(0, 0, 1), way),
		middle), colour, unit)


# -- a motor and its load -------------------------------------------------------------------


func _motor() -> void:
	print("  a Power Functions M motor geared up 9 to an arm of eight 1x8 bricks")
	_main.call("clear_model")
	await _frames(10)
	var t: float = _top_of_floor()
	# The motor on three columns of ten 2x2 bricks and a plate, its output
	# 278 up, pointing at +z.
	for z: float in [-100.0, -60.0, -20.0]:
		for n: int in 10:
			_flat("3003", Vector3(0, t + 24.0 * (n + 1), z), 71)
		_flat("3022", Vector3(0, t + 248, z), 71)
	var h: float = t + 278.0
	var motor: int = _flat("58120c01", Vector3(0, h, 0), 71)
	var rig: Dictionary = _geared_arm(t, h, "3008", 8, 70.0)
	await _frames(5)
	_camera.frame(AABB(Vector3(-200, t, -140), Vector3(480, 560, 240)), 1.05)
	await _frames(10)
	await _stalls("Power Functions M motor", motor, rig, M_MOTOR_N_CM, "9 V", 0.5, "4_motor")
	await _unloaded("Power Functions M motor", rig, "eight 1x8 bricks", "6_motor_unloaded")


# -- a SPIKE Prime large angular motor and its load ---------------------------------------


func _spike_large() -> void:
	print("  a SPIKE Prime large angular motor pinned on a stand, its hub geared up 9 to an arm of "
		+ "ten 2x8 bricks")
	_main.call("clear_model")
	await _frames(10)
	var t: float = _top_of_floor()
	var h: float = t + 326.0
	# Its hub's face at z 0, its underside on a Technic plate 2 x 8 on a
	# column of seven 2x2 bricks, a pin up through the plate's holes 40 either
	# side into the two holes in the motor's underside.
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
	await _stalls("SPIKE Prime large angular motor", motor, rig, SPIKE_L_N_CM, "7.2 V", 1.0, "7_spike")
	var said: String = await _session_said(motor)
	_check("over MCP, simulate_mechanism driver=#%d says the stall too: %s" % [motor,
		_line_with(said, "#%d %s" % [motor, "54675"]).left(140)], said.contains("STALLS: the SPIKE "
		+ "Prime large angular motor (#%d 54675)" % motor) and not said.contains("NOT FIXED"))
	await _unloaded("SPIKE Prime large angular motor", rig, "ten 2x8 bricks", "9_spike_unloaded")


# -- a SPIKE Prime large motor on nothing that holds it -------------------------------------


func _spike_loose() -> void:
	print("  the SPIKE Prime large angular motor on its output's axle alone, its case on nothing "
		+ "the base holds")
	_main.call("clear_model")
	await _frames(10)
	var t: float = _top_of_floor()
	var h: float = t + 326.0
	# Where the pinned rig stands it, the column, its plate and the two pins
	# under it left out: the case hangs on the axle in its hub, as y6's hung
	# from a beam held by nothing.
	var motor: int = _place("54675", Transform3D(SPIKE_STANDS, Vector3(0, h, -50)), 71, "")
	var rig: Dictionary = _geared_arm(t, h, "3007", 10, 80.0)
	await _frames(5)
	_camera.frame(AABB(Vector3(-200, t, -200), Vector3(520, 680, 340)), 1.05)
	await _frames(10)
	var rest: Dictionary = _rest()
	var depth: int = _builder.history_depth()
	var revision: int = _world.revision
	_shell.run("simulate")
	await _settled()
	var sim: Simulation = _panel.sim
	print("    driver: %s" % _panel.said()["driver"])
	_check("the motor marks the driver: its output's axle", sim != null
		and sim.driver == sim.model.body_of(int(rig["output"])) and _found(sim, "motor", 0) == motor)
	_check("...its case on nothing the base holds, going round with what it turns",
		sim != null and sim.model.body_of(motor) != sim.model.ground and sim.moving.has(motor))
	var stops: String = _stops_said()
	print("    stops: %s" % stops.replace("\n", " | "))
	_check("the panel says NOT FIXED, the motor by name, and to fix its body to the frame",
		stops.contains("NOT FIXED: the SPIKE Prime large angular motor (#%d 54675)" % motor)
		and stops.contains("Fix its body to the frame"))
	_check("...never \"nothing to lift\", a stall or what it is asked, and nothing weighed",
		not stops.contains("nothing to lift") and not stops.contains("STALLS")
		and not stops.contains("it is asked") and not stops.contains("its motor stalls")
		and _found(sim, "stall").is_empty() and _found(sim, "heaviest").is_empty())
	await _shot("11_spike_loose")
	var said: String = await _session_said(motor)
	print("    simulate_mechanism: %s" % _line_with(said, "(#%d 54675)" % motor).left(300))
	_check("over MCP, simulate_mechanism driver=#%d says NOT FIXED and what to do, not "
		% motor + "\"nothing to lift\"", said.contains("NOT FIXED: the SPIKE Prime large angular "
		+ "motor (#%d 54675)" % motor) and said.contains("Fix its body to the frame")
		and not said.contains("nothing to lift") and not said.contains("STALLS"))
	_check("the model never moved", _same_as(rest) and _world.revision == revision
		and _builder.history_depth() == depth)
	_panel.close()
	await _frames(3)


## What simulate_mechanism driver=#[param motor] says, as a session asks it
## (AppTools, as simulate_probe asks it).
func _session_said(motor: int) -> String:
	var tools: AppTools = AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var answer: Variant = await tools.run("simulate_mechanism", {"driver": "#%d" % motor})
	return str((answer as Array)[0]["text"]) if answer is Array else str(answer)


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return "-"


# -- a Powered Up L motor and its load -----------------------------------------------------


func _powered_up_l() -> void:
	print("  a Powered Up L motor pinned on a stand, geared up 9 to an arm of ten 2x8 bricks")
	_main.call("clear_model")
	await _frames(10)
	var t: float = _top_of_floor()
	var h: float = t + 326.0
	# On its side, its face at z 0, the holes through its back end upright:
	# a long pin up through a Technic plate 2 x 6 on a column of twelve 2x2
	# bricks into each.
	for n: int in 12:
		_flat("3003", Vector3(0, t + 24.0 * (n + 1), -150), 71)
	_flat("32001", Vector3(0, h - 30, -150), 71)
	for x: float in [-20.0, 20.0]:
		_upright("6558", Vector3(x, h - 24, -150), 0)
	var motor: int = _place("22169", Transform3D(PU_STANDS, Vector3(0, h, -10)), 72, "")
	var rig: Dictionary = _geared_arm(t, h, "3007", 10, 80.0)
	await _frames(5)
	_camera.frame(AABB(Vector3(-200, t, -200), Vector3(520, 680, 340)), 1.05)
	await _frames(10)
	await _stalls("Powered Up L motor", motor, rig, PU_L_N_CM, "9 V", 1.0, "10_pul")
	_panel.close()
	await _frames(3)


# -- a beam pinned to a SPIKE hub ------------------------------------------------------------


func _hub_pins() -> void:
	print("  a beam pinned to a SPIKE Prime medium angular motor's hub by two pins, no axle")
	_main.call("clear_model")
	await _frames(10)
	var t: float = _top_of_floor()
	var h: float = t + 278.0
	for n: int in 5:
		_flat("3003", Vector3(0, t + 24.0 * (n + 1), -50), 71)
	_flat("32001", Vector3(0, h - 150, -50), 71)
	for x: float in [-20.0, 20.0]:
		_upright("2780", Vector3(x, h - 150, -50), 0)
	var motor: int = _place("54696p01", Transform3D(SPIKE_STANDS, Vector3(0, h, -50)), 71, "")
	# A beam 5 upright across the hub's face, its holes on z, two pins through
	# its holes 20 above and below its middle into the hub's.
	var beam: int = _place("32316", Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1),
		Vector3(0, -1, 0)), Vector3(0, h, 10)), 14, "Beam")
	for y: float in [20.0, -20.0]:
		_along_z("2780", Vector3(0, h + y, 0), 0, "Beam")
	await _frames(5)
	_camera.frame(AABB(Vector3(-160, t, -160), Vector3(320, 480, 260)), 1.05)
	await _frames(10)
	var rest: Dictionary = _rest()
	_shell.run("simulate")
	await _settled()
	var sim: Simulation = _panel.sim
	print("    driver: %s" % _panel.said()["driver"])
	var driver: int = sim.driver if sim != null else -1
	var joint: Mechanism.Joint = sim.model.joint_of(driver) if sim != null and driver >= 0 else null
	_check("the beam pinned to the hub is the driver, its motor's: the hub turns in the case",
		sim != null and driver == sim.model.body_of(beam) and int(sim.motored.get(driver, 0)) == motor
		and str(_panel.said()["driver"]).contains("its motor turns it"))
	_check("...on the hub's line (x 0, y %d, along z), against the case, the base" % int(h - t),
		joint != null and Mechanism._same_line(joint.point, joint.way.normalized(), Vector3(0, h, 0),
			Vector3(0, 0, 1)) and sim.model.body_of(motor) == sim.model.ground)
	var stops: String = _stops_said()
	print("    stops: %s" % stops.replace("\n", " | "))
	_check("the pins go round through the hub without meeting it, nor anything else",
		_found(sim, "meets").is_empty() and _found(sim, "meets_back").is_empty()
		and stops.contains("all the way round"))
	_check("...and the motor is said by name, at its 7.2 V", stops.contains("SPIKE Prime medium angular motor")
		and stops.contains("#%d" % motor) and stops.contains("7.2 V") and stops.contains("rpm"))
	await _shot("12_hub_pins")
	_check("the model never moved", _same_as(rest))
	_panel.close()
	await _frames(3)


# -- a motor drawn in its pieces ----------------------------------------------------------


func _in_pieces() -> void:
	print("  a Technic large angular motor drawn in its pieces, a sub-model 69730, an axle in its hub")
	_main.call("clear_model")
	await _frames(10)
	var t: float = _top_of_floor()
	var h: float = t + 326.0
	for n: int in 7:
		_flat("3003", Vector3(0, t + 24.0 * (n + 1), -50), 71)
	_flat("3738", Vector3(0, h - 150, -50), 71)
	for x: float in [-40.0, 40.0]:
		_upright("2780", Vector3(x, h - 150, -50), 0)
	# Each piece where 69730 (u9367c01's pieces and the hub) draws it, as the
	# SPIKE motor stands above, in a sub-model of the motor's number.
	var at := Transform3D(SPIKE_STANDS, Vector3(0, h, -50))
	var pieces: Array = []
	var hub: int = -1
	for piece: Array in [["u9367", Vector3(0, 20, 0)], ["u9368", Vector3(0, -20, 0)],
			["u9390", Vector3(0, 0, -140)], ["u9391", Vector3(0, 0, -140)],
			["u9363p01", Vector3(0, 50, 0)]]:
		var id: int = _place(str(piece[0]), at * Transform3D(Basis.IDENTITY, piece[1]), 72, "69730")
		if str(piece[0]) == "u9363p01":
			hub = id
		else:
			pieces.append(id)
	var axle: int = _along_z("3705", Vector3(0, h, 20), 0)
	_flat("3648a", Vector3(0, h, 10), 72)
	await _frames(5)
	_camera.frame(AABB(Vector3(-160, t, -160), Vector3(320, 480, 260)), 1.05)
	await _frames(10)
	var rest: Dictionary = _rest()
	_shell.run("simulate")
	await _settled()
	var sim: Simulation = _panel.sim
	print("    driver: %s" % _panel.said()["driver"])
	var driver: int = sim.driver if sim != null else -1
	_check("the axle in the hub is the driver, the motor's: its hub turns in its pieces",
		sim != null and driver == sim.model.body_of(axle) and int(sim.motored.get(driver, 0)) == hub
		and str(_panel.said()["driver"]).contains("its motor turns it"))
	var held: bool = sim != null and sim.model.body_of(hub) == sim.model.ground
	for id: int in pieces:
		held = held and sim.model.body_of(id) == sim.model.ground
	_check("...its four pieces and the hub's own case one, held with the base by the pins", held)
	var stops: String = _stops_said()
	print("    stops: %s" % stops.replace("\n", " | "))
	_check("nothing meets, and the motor is said by name, at its 9 V",
		_found(sim, "meets").is_empty() and stops.contains("Technic large angular motor")
		and stops.contains("#%d" % hub) and stops.contains("9 V") and stops.contains("rpm"))
	await _shot("13_in_pieces")
	_check("the model never moved", _same_as(rest))
	_panel.close()
	await _frames(3)


# -- a motor's train and what it lifts -------------------------------------------------------


## The gear train and arm a motor lifts, its output on the line x 0, y [param
## h], along +z, its face at z 0: a 1x8 Technic brick on a column of 1x8
## bricks holding three axles, the motor's (a 4L from z -20 to 60), 24 on 8,
## 24 on 8, and the arm on the last: a 1x2 Technic brick, two 1x2 bricks and
## [param count] of [param load] on them, their middle at z [param load_z].
## {output, last (the arm's axle), arm (each of its parts), load}.
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
	var loads: Array = []
	for n: int in count:
		loads.append(_flat(load, Vector3(80, h + 58 + 24.0 * (n + 1), load_z), 1, "Arm"))
	arm.append_array(loads)
	return {"output": output, "last": last, "arm": arm, "load": loads, "pivot": Vector3(80, h, 70)}


## Simulate on [param rig] driven by [param motor] (brick id), called [param
## named], giving [param torque] N·cm at [param volts]: the motor marks the
## driver, nothing meets, the arm turns GEARED times the motor, and lifting
## it the motor stalls where the arm's weight asks more, worked by virtual
## work to [param within] degrees with the working said; Play stops there,
## and the model never moved.
func _stalls(named: String, motor: int, rig: Dictionary, torque: float, volts: String,
		within: float, shots: String) -> void:
	var output: int = rig["output"]
	var last: int = rig["last"]
	var rest: Dictionary = _rest()
	var depth: int = _builder.history_depth()
	var revision: int = _world.revision
	_shell.run("simulate")
	await _settled()
	var sim: Simulation = _panel.sim
	print("    driver: %s" % _panel.said()["driver"])
	_check("the motor marks the driver: its output's axle, which it turns", sim != null
		and sim.driver == sim.model.body_of(output) and _found(sim, "motor", 0) == motor
		and str(_panel.said()["driver"]).contains("its motor turns it"))
	_check("...its case held still with the base by what it is pinned or stood on",
		sim != null and sim.model.body_of(motor) == sim.model.ground)
	_check("nothing meets over the cycle, the axle turning in the motor's output among it",
		_found(sim, "meets").is_empty() and _found(sim, "meets_back").is_empty())
	_check("the arm turns 9 times the motor's turn, two 24s on two 8s (%.4f)"
		% float(sim.rates.get(sim.model.body_of(last), 0.0)),
		absf(absf(float(sim.rates.get(sim.model.body_of(last), 0.0))) - GEARED) < 1e-4)
	var stops: String = _stops_said()
	print("    stops: %s" % stops.replace("\n", " | "))
	# Worked: the weight's moment about the arm's axle, standing up, from
	# the parts' grams; lifting it past the bottom asks GEARED times its
	# moment times sin of how far past, of the motor.
	var pivot: Vector3 = rig["pivot"]
	var moment: float = 0.0
	var grams: float = 0.0
	for key: int in rig["arm"]:
		var brick: BrickWorld.Brick = _world.get_brick(key)
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		var weighs: float = Stability.grams(_library.parts[brick.part_id])
		grams += weighs
		moment += weighs * ((brick.transform * mesh.bounds.get_center()) - pivot).y
	var at_arm: float = moment * N_CM
	var most: float = GEARED * at_arm
	var share: float = torque / most
	var stalls_at: float = (180.0 + rad_to_deg(asin(share))) / GEARED
	print(("    worked: the arm's %d parts weigh %.2f g, their middle %.1f LDU (%.2f cm) above "
		+ "its axle: standing up their weight's moment is %.3f N·cm at the arm, %.2f at the motor "
		+ "through the 9 up. Past the bottom it asks %.2f x sin(how far past); the %s gives "
		+ "%s N·cm at %s, so it stalls %.2f° past the bottom: the arm %.2f° round, the motor "
		+ "%.3f°.") % [(rig["arm"] as Array).size(), grams, moment / grams, moment / grams * 0.04,
			at_arm, most, most, named, Simulation.figure(torque), volts,
			rad_to_deg(asin(share)), stalls_at * GEARED, stalls_at])
	var stall: Dictionary = _found(sim, "stall")
	var said_at: float = float(stall.get("turns", INF)) * 360.0
	_check("the motor stalls at %.3f° of its turn, worked %.3f°, %.3f° apart (to %s°; the arm %.1f° "
		% [said_at, stalls_at, absf(said_at - stalls_at), Simulation.figure(within), stalls_at * GEARED]
		+ "round, its weight asking %.2f N·cm at most against %s)" % [most, Simulation.figure(torque)],
		share < 1.0 and absf(said_at - stalls_at) < within)
	_check("...asked %.2f N·cm at its heaviest, worked %.2f (to 2%%)" % [
		float(_found(sim, "heaviest").get("needs", 0.0)), most],
		absf(float(_found(sim, "heaviest").get("needs", 0.0)) - most) < most * 0.02)
	_check("...and says so: the motor named, STALLS, at its %s, gear it down" % volts,
		stops.contains("STALLS") and stops.contains(named) and stops.contains("#%d" % motor)
		and stops.contains("it gives at %s" % volts) and stops.contains("Gear it down")
		and stops.contains("its motor stalls"))
	await _shot(shots + "_loaded")
	var play: Button = _panel.controls_by_name()["simulate_play"]
	await _click(play.get_global_rect().get_center())
	for _n: int in 1200:
		await process_frame
		if not _panel.playing:
			break
	_check("Play stops where it stalls (%.3f°): %s" % [_panel.turns * 360.0,
		_panel.said()["status"]], not _panel.playing
		and absf(_panel.turns - float(stall.get("turns", INF))) < 1e-9
		and str(_panel.said()["status"]).contains("its motor stalls")
		and _drawn_as(sim.placed(_panel.turns)))
	if _panel.playing:
		await _click(play.get_global_rect().get_center())
	await _shot(shots + "_stalled")
	_check("the model never moved", _same_as(rest) and _world.revision == revision
		and _builder.history_depth() == depth)


## The load taken off [param rig]: the same motor turns the arm all the way
## round, and says how fast.
func _unloaded(named: String, rig: Dictionary, load_said: String, shot: String) -> void:
	print("  the %s taken off" % load_said)
	for key: int in rig["load"]:
		_builder.remove_brick_id(key)
	await _frames(3)
	await _settled()
	var sim: Simulation = _panel.sim
	var stops: String = _stops_said()
	print("    stops: %s" % stops.replace("\n", " | "))
	_check("unloaded it turns all the way round: no stall, and the motor's speed said",
		_found(sim, "stall").is_empty() and _found(sim, "meets").is_empty()
		and not stops.contains("STALLS")
		and stops.contains("The %s" % named) and stops.contains("rpm"))
	await _shot(shot)
	_panel.close()
	await _frames(3)


# -- building ------------------------------------------------------------------------------


## The top of whatever the model stands on: the baseplate's top face, or 0.
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


## A part as it is drawn, its origin at [param at].
func _flat(part_id: String, at: Vector3, colour: int, unit: String = "") -> int:
	return _place(part_id, Transform3D(Basis.IDENTITY, at), colour, unit)


## An axle or a pin lying along z, its middle at [param at].
func _along_z(part_id: String, at: Vector3, colour: int, unit: String = "") -> int:
	return _place(part_id, Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0),
		Vector3(-1, 0, 0)), at), colour, unit)


## A pin standing upright, its middle at [param at].
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


## What the simulation found, read by name: a build without it reads
## [param empty] and fails its checks rather than stopping.
static func _found(sim: Simulation, what: String, empty: Variant = {}) -> Variant:
	var got: Variant = sim.get(what) if sim != null else null
	return empty if got == null else got


func _stops_said() -> String:
	return str(_panel.said().get("stops", ""))


## Whether every part in [param pose] is drawn where it says.
func _drawn_as(pose: Dictionary) -> bool:
	for key: Variant in pose:
		var brick: BrickWorld.Brick = _world.get_brick(int(key))
		if brick == null or _world.drawn_at(brick).origin.distance_to(
				(pose[key] as Transform3D).origin) > 0.01:
			return false
	return not pose.is_empty()


# -- driving the window ---------------------------------------------------------------------


## Wait for the panel to finish reading, driving, weighing and finding
## where it stops, and say how long that took.
func _settled() -> void:
	var began: int = Time.get_ticks_msec()
	var frames: int = 0
	while Time.get_ticks_msec() - began < 600000:
		await process_frame
		frames += 1
		if not Working.is_busy() and _panel.sim != null and not _panel._reading \
				and not _panel._driving:
			break
	print("    (read, driven and checked in %.1f s, %d frames)" % [
		(Time.get_ticks_msec() - began) / 1000.0, frames])
	for _n: int in 600:
		var aim: Vector2 = _camera.seen_rect().get_center() - _camera._room() * 0.5
		if _camera._shift.distance_to(aim) < 0.5:
			break
		await process_frame
	await _frames(5)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = SHOTS.path_join("%s_%s.png" % [_size, name])
	image.save_png(ProjectSettings.globalize_path(path))
	print("    picture: %s" % path.trim_prefix("res://"))
