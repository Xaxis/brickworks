## Tools, Simulate mechanism: where the motion stops (docs/MECHANISMS.md,
## section 39), in the real scene, as a person uses it.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1400x900x24" godot --path . \
##     --resolution 1400x900 --script src/dev/motion_probe.gd
##   ... and at 1280x720 (PROBE_SIZE=1280x720 bash tools/probe.sh motion_probe)
##   ... -- only=arm, only=fourbar or only=motor runs that model alone
##
## Three models, built here part by part on the baseplate:
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
##     the bricks taken off, the same motor turns it and says how fast.
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
	print("")
	if _failures == 0:
		print("motion: an arm meeting a beam at 140° said there, a four-bar's range against its "
			+ "closed form, a motor that stalls lifting its load said and stopped at, and the "
			+ "model never moved")
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
	# Three axles in a 1x8 Technic brick on eleven bricks: the motor's,
	# 24 on 8, 24 on 8, the arm on the last.
	for n: int in 11:
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
	var load: Array = []
	for n: int in 8:
		load.append(_flat("3008", Vector3(80, h + 58 + 24.0 * (n + 1), 70), 1, "Arm"))
	arm.append_array(load)
	await _frames(5)
	_camera.frame(AABB(Vector3(-200, t, -140), Vector3(480, 560, 240)), 1.05)
	await _frames(10)
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
	var pivot := Vector3(80, h, 70)
	var moment: float = 0.0
	for key: int in arm:
		var brick: BrickWorld.Brick = _world.get_brick(key)
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		var grams: float = Stability.grams(_library.parts[brick.part_id])
		moment += grams * ((brick.transform * mesh.bounds.get_center()) - pivot).y
	var most: float = GEARED * moment * N_CM
	var share: float = M_MOTOR_N_CM / most
	var stalls_at: float = (180.0 + rad_to_deg(asin(share))) / GEARED
	var stall: Dictionary = _found(sim, "stall")
	var said_at: float = float(stall.get("turns", INF)) * 360.0
	_check("the motor stalls at %.3f° of its turn, worked %.3f° (the arm %.1f° round, its weight "
		% [said_at, stalls_at, stalls_at * GEARED] + "asking %.2f N·cm at most against 11)" % most,
		share < 1.0 and absf(said_at - stalls_at) < 0.5)
	_check("...asked %.2f N·cm at its heaviest, worked %.2f (to 2%%)" % [
		float(_found(sim, "heaviest").get("needs", 0.0)), most],
		absf(float(_found(sim, "heaviest").get("needs", 0.0)) - most) < most * 0.02)
	_check("...and says so: the motor named, STALLS, gear it down", stops.contains("STALLS")
		and stops.contains("Power Functions M motor") and stops.contains("#%d" % motor)
		and stops.contains("Gear it down") and stops.contains("its motor stalls"))
	await _shot("4_motor_loaded")
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
	await _shot("5_motor_stalled")
	_check("the model never moved", _same_as(rest) and _world.revision == revision
		and _builder.history_depth() == depth)

	# The load taken off: the same motor turns the arm, and says how fast.
	print("  the eight 1x8 bricks taken off")
	for key: int in load:
		_builder.remove_brick_id(key)
	await _frames(3)
	await _settled()
	sim = _panel.sim
	stops = _stops_said()
	print("    stops: %s" % stops.replace("\n", " | "))
	_check("unloaded it turns all the way round: no stall, and the motor's speed said",
		_found(sim, "stall").is_empty() and _found(sim, "meets").is_empty()
		and not stops.contains("STALLS")
		and stops.contains("The Power Functions M motor") and stops.contains("rpm"))
	await _shot("6_motor_unloaded")
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
