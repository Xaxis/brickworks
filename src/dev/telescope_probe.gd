## What a session's Claude told the owner about a telescope that tilts and
## extends, tried on small rigs of real parts in Simulate, in Grab and over
## MCP (docs/MECHANISMS.md, section 27):
##   rack_wheel     a wheel, a gear chain 8:24, a pinion and a rack on a tube
##                  that slides on a rod
##   crank_slider   a wheel on a crank, a connecting rod and the same tube
##   tilt_cradle    a cradle tilting on the pinion's axle, carrying the tube,
##                  the pinion held by a gear chain with a friction pin
##   telescope      the owner's shape: the same, with a tilt wheel turning the
##                  cradle through a chain with a friction pin of its own
##   friction_arms  a beam on a friction pin and one on a plain pin, let go
## and the orrery, whose periods Simulate must keep.
##
##   godot --path . --resolution 1400x900 --script src/dev/telescope_probe.gd
##   ... -- --into=DIR   pictures and answers there (shots/telescope)
##
## Every number is read off the parts where each path puts them: LDU along
## the tube's rod, degrees of a body's turn. Headless it measures and checks
## all of it and draws nothing.
extends SceneTree

const FIXTURES := "res://src/dev/fixtures"
## An 8 tooth pinion moves its rack 8 teeth a turn, 8 LDU each (Racks).
const RACK_PER_TURN := 64.0
## The crank's throw, LDU: its two axle holes a stud apart.
const THROW := 20.0

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _panel: SimulatePanel
var _grabbing: GrabDrag
var _camera: CadCamera
var _out: String = ""
var _next: int = 0
## What each path said, for the docs: claim -> path -> words.
var _said: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


## A gap docs/MECHANISMS.md section 27 says is left: printed, not failed.
func _gap(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "GAP ", what])
	if not ok:
		_gaps += 1


var _gaps: int = 0


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--into="):
			_out = argument.trim_prefix("--into=")
	if _out.is_empty():
		_out = ProjectSettings.globalize_path("res://shots/telescope")
	DirAccess.make_dir_recursive_absolute(_out)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_panel = _main.get("_simulate")
	_grabbing = _main.get("_grab_drag")
	_camera = _main.get("_camera")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	print("drawing: %s" % ("yes" if StudioRender.possible() else "no, headless"))
	await _rack_wheel()
	await _crank_slider()
	await _tilt_cradle()
	await _telescope()
	await _friction_arms()
	await _two_planets()
	await _orrery()
	print("\ntelescope: %s, %d gap%s left as docs/MECHANISMS.md section 27 says" % [
		"every check passed" if _failures == 0 else "%d FAILED" % _failures, _gaps, "" if _gaps == 1 else "s"])
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- the rigs ----------------------------------------------------------------------


## A wheel turns an 8 into a 24 whose axle carries the pinion: a third of a
## turn of the pinion, a third of 64 LDU along the rack, for each turn of
## the wheel.
func _rack_wheel() -> void:
	print("\n══ rack_wheel: wheel, 8:24, pinion, rack on a tube on a rod ══")
	if not await _open("rack_wheel.ldr"):
		return
	var wheel: int = _find("4185a")
	var tube: int = _find("3700")
	var want: float = RACK_PER_TURN / 3.0
	var grab_turn: float = _along_z(tube, await _grab_turned(wheel, 360.0))
	var grab_quarter: float = _along_z(tube, await _grab_turned(wheel, 90.0))
	print("  Grab: a turn of the wheel slides the tube %.3f LDU (a quarter turn %.3f); the teeth say %.3f" % [
		grab_turn, grab_quarter, want])
	_check("Grab: a turn of the wheel slides the tube a third of 64 LDU (%.3f)" % grab_turn,
		absf(absf(grab_turn) - want) < 0.05)
	await _picture("rack_wheel_grab_wheel_540", await _grab_turned(wheel, 540.0))
	await _simulate_shot("rack_wheel_simulate_1.5_turns", wheel, 1.5)
	var sim: Simulation = await _simulated(wheel)
	var sim_turn: float = _along_z(tube, sim.placed(1.0))
	print("  Simulate: %s" % _lines(sim))
	print("  Simulate: a turn of the wheel slides the tube %.3f LDU" % sim_turn)
	_check("Simulate: a turn of the wheel slides the tube as Grab does (%.3f, Grab %.3f)" % [sim_turn,
		grab_turn], absf(sim_turn - grab_turn) < 0.05)
	_check("Simulate: the tube is not called free (nothing decides how it turns)",
		not _parts_free(sim, tube))
	var mcp: String = await _say("move_part", {"part": "#%d" % wheel, "degrees": 360})
	var mcp_turn: float = _along_z(tube, _now([tube]))
	print("  move_part degrees=360: tube %.3f LDU; %s" % [mcp_turn, mcp.get_slice("\n", 1)])
	await _say("undo", {})
	_check("move_part: a turn of the wheel slides the tube as Grab does (%.3f)" % mcp_turn,
		absf(mcp_turn - grab_turn) < 0.05)
	var said: String = await _say("simulate_mechanism", {"driver": "#%d" % wheel})
	print("  simulate_mechanism driver=#%d:\n    %s" % [wheel, said.replace("\n", "\n    ")])
	_said["rack"] = {"simulate": said, "move_part": mcp, "grab": grab_turn, "sim": sim_turn}
	# The tube drawn along its rod by hand: its rack turns the pinion, and the
	# pinion the train back to the wheel, three times as fast as the 24.
	var held: Grab = _grabbing._taken([tube])
	var drawn: float = 10.0
	var wheel_turn: float = NAN
	if held.state == "moves" and held.can_slide():
		held.use_slide()
		var got: float = held.slide_to(drawn)
		wheel_turn = _turn_of(wheel, held.placed)
		print("  Grab: the tube drawn %.2f LDU turns the wheel %.2f° (the teeth say %.2f°): %s" % [got,
			wheel_turn, 3.0 * 360.0 * got / RACK_PER_TURN, held.said])
		_check("Grab: the tube drawn 10 LDU turns the wheel back through its gears, 168.75° (%.2f°)" % wheel_turn,
			absf(absf(wheel_turn) - 3.0 * 360.0 * got / RACK_PER_TURN) < 0.5)
	else:
		print("  Grab: the tube does not slide: %s" % held.why)
	await _shot("rack_wheel")


## A crank of a stud's throw, a rod five studs long and the tube on its rod:
## the tube strokes twice the throw over a turn, and nothing locks.
func _crank_slider() -> void:
	print("\n══ crank_slider: wheel on a crank, rod, slider ══")
	if not await _open("crank_slider.ldr"):
		return
	var wheel: int = _find("4185a")
	var tube: int = _find("3700")
	var rod: int = _find("32316")
	var turning: Variant = _grabbing.turning_for_session("#%d" % wheel)
	var least: float = INF
	var most: float = -INF
	if turning is GrabDrag.Turning:
		for n: int in 25:
			var at: float = _along_z(tube, (turning as GrabDrag.Turning).placed_at(15.0 * n))
			least = minf(least, at)
			most = maxf(most, at)
		print("  Grab: over a turn the tube goes from %.3f to %.3f LDU, %.3f (twice the throw: %.1f)" % [
			least, most, most - least, 2.0 * THROW])
	else:
		print("  Grab: %s" % str(turning))
	_check("Grab: the slider strokes twice the crank's throw (%.3f LDU)" % (most - least),
		absf(most - least - 2.0 * THROW) < 0.5)
	await _picture("crank_slider_grab_wheel_120", await _grab_turned(wheel, 120.0))
	await _simulate_shot("crank_slider_simulate_120", wheel, 1.0 / 3.0)
	var sim: Simulation = await _simulated(wheel)
	print("  Simulate at dead centre: %s" % _lines(sim))
	var s_least: float = INF
	var s_most: float = -INF
	var rod_most: float = 0.0
	for n: int in 25:
		var at: Dictionary = sim.placed(n / 24.0)
		var z: float = _along_z(tube, at)
		s_least = minf(s_least, z)
		s_most = maxf(s_most, z)
		rod_most = maxf(rod_most, absf(_turn_of(rod, at)))
	print("  Simulate: the tube goes %.3f LDU over a turn; the rod turns as much as %.1f°" % [
		s_most - s_least, rod_most])
	_check("Simulate: the slider strokes twice the throw, as Grab has it (%.3f LDU)" % (s_most - s_least),
		absf(s_most - s_least - 2.0 * THROW) < 0.5)
	_check("Simulate: the connecting rod rocks, never past 30° (%.1f°)" % rod_most, rod_most < 30.0)
	# Off its dead centre, as a session's crank is built or left.
	var moved: String = await _say("move_part", {"part": "#%d" % wheel, "degrees": 90})
	print("  move_part degrees=90: %s" % moved.get_slice("\n", 1))
	_said["crank"] = {"move_part": moved}
	sim = await _simulated(wheel)
	print("  Simulate off dead centre: %s" % _lines(sim))
	_check("Simulate off dead centre: not locked (%s)" % str(sim.solved.get("said", "")),
		not bool(sim.solved.get("locked", false)))
	var said: String = await _say("simulate_mechanism", {"driver": "#%d" % wheel})
	print("  simulate_mechanism off dead centre:\n    %s" % said.replace("\n", "\n    "))
	_said["crank"]["simulate"] = said
	await _shot("crank_slider")
	await _say("undo", {})


## The cradle tilts on the pinion's axle and the gear chain holds the pinion:
## the rack rolls along it, 64 LDU a turn of the tilt. The wheel turns the
## pinion and slides the tube, and leaves the cradle where it stands.
func _tilt_cradle() -> void:
	print("\n══ tilt_cradle: a cradle on the pinion's axle, the chain with a friction pin ══")
	if not await _open("tilt_cradle.ldr"):
		return
	var cradle: int = _find("3029")
	var tube: int = _find("3700", Vector3(0, -128, 10))
	var wheel: int = _find("4185a")
	await _tilts(cradle, tube, wheel, "tilt_cradle", false)


## The owner's telescope as their Claude described it.
func _telescope() -> void:
	print("\n══ telescope: tilt wheel and extension wheel, a friction pin in each chain ══")
	if not await _open("telescope.mpd"):
		return
	var cradle: int = _find("3029")
	var tube: int = _find("3700", Vector3(0, -128, 10))
	var extension: int = _find("4185a", Vector3(-120, -158, 60))
	var tilt: int = _find("4185a", Vector3(120, -158, 60))
	await _tilts(cradle, tube, extension, "telescope", true)
	# The tilt wheel turns the cradle a turn for its turn, through an idler.
	var placed: Dictionary = await _grab_turned(tilt, 45.0)
	var tilted: float = _turn_of(cradle, placed)
	var slid: float = _slide_in(cradle, tube, placed)
	print("  Grab: the tilt wheel at 45° tilts the cradle %.2f° and slides the tube %.3f LDU in it (%.3f stud)" % [
		tilted, slid, slid / 20.0])
	_check("Grab: the tilt wheel tilts the cradle 45° and the tube slides 8 LDU, 0.4 stud (%.3f)" % slid,
		absf(absf(tilted) - 45.0) < 0.5 and absf(absf(slid) - 8.0) < 0.2)
	var sim: Simulation = await _simulated(tilt)
	var sim_at: Dictionary = sim.placed(45.0 / 360.0)
	var sim_slid: float = _slide_in(cradle, tube, sim_at)
	print("  Simulate from the tilt wheel: the cradle %.2f°, the tube %.3f LDU in it; %s" % [
		_turn_of(cradle, sim_at), sim_slid, _lines(sim)])
	# Simulate's base holds the sub-assembly named Stand still whole, with the
	# friction pin the tilt chain's idler is read fixed to: its chain locks
	# there, where Grab's anchors turn it (a gap).
	_gap("Simulate: the tilt wheel slides the tube in the cradle as Grab does (%.3f, Grab %.3f)" % [
		sim_slid, slid], absf(sim_slid - slid) < 0.2)
	await _picture("telescope_grab_tilt_wheel_45", placed)
	for part: int in [tilt, cradle]:
		var said: String = await _say("move_part", {"part": "#%d" % part, "degrees": 45})
		print("  move_part #%d degrees=45, let go: %s" % [part, said.get_slice("\n", 1)])
		print("    the cradle stands %.2f° from where it was built, the tube %.3f LDU along it" % [
			_turn_of(cradle, _now([cradle])), _slide_in(cradle, tube, _now([cradle, tube]))])
		_said["telescope_%d" % part] = said
		await _say("undo", {})
	await _shot("telescope")


## Tilt [param cradle] 45° by hand, and turn [param wheel] a quarter turn,
## in Grab, in Simulate and over MCP: how far [param tube] slides in it.
func _tilts(cradle: int, tube: int, wheel: int, name: String, held_tilt: bool) -> void:
	var want: float = RACK_PER_TURN * 45.0 / 360.0
	var placed: Dictionary = await _grab_turned(cradle, 45.0)
	var slid: float = _slide_in(cradle, tube, placed)
	print("  Grab: the cradle tilted 45° slides the tube %.3f LDU along it (%.3f stud; the teeth say %.1f)" % [
		slid, slid / 20.0, want])
	_check("Grab: tilted 45°, the tube slides 8 LDU in the cradle, 0.4 stud (%.3f)" % slid,
		absf(absf(slid) - want) < 0.2)
	var sim: Simulation = await _simulated(cradle)
	var sim_at: Dictionary = sim.placed(45.0 / 360.0)
	var sim_slid: float = _slide_in(cradle, tube, sim_at)
	print("  Simulate from the cradle: the tube %.3f LDU in it; %s" % [sim_slid, _lines(sim)])
	_check("Simulate: tilted 45°, the tube slides in the cradle as Grab has it (%.3f)" % sim_slid,
		absf(sim_slid - slid) < 0.2)
	await _picture("%s_grab_tilt_45" % name, placed)
	await _simulate_shot("%s_simulate_tilt_45" % name, cradle, 45.0 / 360.0)
	# The extension wheel: the pinion turns, the tube slides, the cradle stays.
	var turned: Dictionary = await _grab_turned(wheel, 90.0)
	var cradle_turn: float = _turn_of(cradle, turned)
	var wheel_slid: float = _slide_in(cradle, tube, turned)
	print("  Grab: the wheel at 90° turns the cradle %.2f° and slides the tube %.3f LDU in it (the teeth say %.1f)" % [
		cradle_turn, wheel_slid, RACK_PER_TURN / 4.0])
	# A cradle whose tilt nothing holds hangs on the pinion's own axle by a
	# free bearing: which of the two goes, the tube or the cradle, is the
	# parts' weight and friction to decide; Grab carries it round (a gap).
	var judge: Callable = _check if held_tilt else _gap
	judge.call("Grab: the wheel leaves the cradle where it stands (%.2f°)" % cradle_turn, absf(cradle_turn) < 0.5)
	judge.call("Grab: the wheel at 90° slides the tube 16 LDU in the cradle (%.3f)" % wheel_slid,
		absf(absf(wheel_slid) - RACK_PER_TURN / 4.0) < 0.2)
	await _picture("%s_grab_wheel_90" % name, turned)
	sim = await _simulated(wheel)
	var sim_turned: Dictionary = sim.placed(0.25)
	var sim_cradle: float = _turn_of(cradle, sim_turned)
	var sim_wheel_slid: float = _slide_in(cradle, tube, sim_turned)
	print("  Simulate from the wheel: the cradle %.2f°, the tube %.3f LDU in it; %s" % [sim_cradle,
		sim_wheel_slid, _lines(sim)])
	_check("Simulate from the wheel: the cradle and the tube where Grab puts them (%.2f°, %.3f LDU)" % [
		sim_cradle, sim_wheel_slid], absf(sim_cradle - cradle_turn) < 0.5 and absf(sim_wheel_slid - wheel_slid) < 0.2)
	await _simulate_shot("%s_simulate_wheel_90" % name, wheel, 0.25)
	var said: String = await _say("move_part", {"part": "#%d" % wheel, "degrees": 90})
	print("  move_part wheel degrees=90: %s\n    the cradle stands %.2f° from where it was built, the tube %.3f LDU along it" % [
		said.get_slice("\n", 1), _turn_of(cradle, _now([cradle])), _slide_in(cradle, tube,
			_now([cradle, tube]))])
	_said["%s_wheel" % name] = said
	await _say("undo", {})
	said = await _say("simulate_mechanism", {"driver": "#%d" % wheel})
	print("  simulate_mechanism driver=#%d:\n    %s" % [wheel, said.replace("\n", "\n    ")])


## Two beams lifted 30° and let go: the one on a friction pin holds, the one
## on a plain pin swings down.
func _friction_arms() -> void:
	print("\n══ friction_arms: a beam on a friction pin, one on a plain pin ══")
	if not await _open("friction_arms.ldr"):
		return
	var arms: Array = _all("41239")
	for arm: int in arms:
		var said: String = await _say("move_part", {"part": "#%d" % arm, "degrees": 30})
		var stands: float = _turn_of(arm, _now([arm]))
		print("  move_part #%d degrees=30: %s\n    let go, it stands %.1f° from where it was built" % [
			arm, said.get_slice("\n", 1), stands])
		var pin_held: bool = said.get_slice("\n", 0).contains("holds where it is put")
		_check("move_part: the arm on %s %s (%.1f°)" % ["a friction pin" if pin_held else "a plain pin",
			"holds at 30°" if pin_held else "swings down", stands],
			absf(stands - 30.0) < 0.5 if pin_held else stands < 20.0)
		_said["arm_%s" % ("friction" if pin_held else "plain")] = said
	await _shot("friction_arms")


## The two-planet orrery simulate_probe records: a drag on its crank turns
## every part where the gear reading does.
func _two_planets() -> void:
	print("\n══ the two-planet orrery ══")
	if not await _open("orrery_two_planets.ldr"):
		return
	var sim: Simulation = await _panel.read_mechanism()
	sim.drive(sim.marked())
	print("  Grab's model: %s" % _grab_said(sim))
	var crank: int = (sim.model.bodies[sim.driver] as Array)[0]
	var dragged: Dictionary = await _grab_turned(crank, 90.0)
	var theirs: Dictionary = sim.model.pose(0.25 * TAU)
	var worst: float = 0.0
	var said := PackedStringArray()
	for key: int in theirs:
		var was: Transform3D = sim.model.rest[key]
		var gear: Transform3D = theirs[key]
		var mine: Transform3D = dragged.get(key, was)
		var off: float = mine.origin.distance_to(gear.origin)
		if off > 0.01:
			said.append("#%d %s %.2f LDU" % [key, _world.get_brick(key).part_id, off])
		worst = maxf(worst, off)
	print("  a drag on the crank to 90°, against the gear reading: %s" % (", ".join(said.slice(0, 8))
		if not said.is_empty() else "every part where it puts it"))
	# A drag reads the crank held rigidly where the gear reading turns it on
	# its axle (a gap): Simulate draws the gear reading's poses here.
	_gap("two planets: a drag on the crank turns every part where the gear reading does (%.3f LDU)" % worst,
		worst < 0.01)
	_check("two planets: Simulate draws the gear reading's poses (%s)" % _grab_said(sim), sim.get("grab") == null)


## The orrery's periods and frames: what Simulate said before (section 9) it
## says still.
func _orrery() -> void:
	print("\n══ the orrery ══")
	if not await _open("", "Orrery of the Sun and eight planets"):
		return
	var sim: Simulation = await _panel.read_mechanism()
	var crank: int = sim.marked()
	sim.drive(crank)
	var earth: int = SimulatePanel._default_reference(sim)
	var lines: PackedStringArray = sim.rate_lines(earth, {}, 9)
	print("  " + "\n  ".join(lines))
	var periods: Dictionary = {}
	for body: int in sim.turning:
		var planet: String = Simulation.planet_in(str(sim.names[body]))
		if not planet.is_empty() and body != earth:
			periods[planet] = sim.period_in(body, earth)
	# As section 9 has them, to four figures.
	var real: Dictionary = {"mercury": 0.24, "venus": 0.6144, "mars": 1.875, "jupiter": 11.85,
		"saturn": 29.4, "uranus": 84.0, "neptune": 164.64}
	for planet: String in real:
		_check("orrery: %s's period %.4f Earth years, as before (%.4f)" % [planet, float(periods.get(planet,
			NAN)), real[planet]], absf(float(periods.get(planet, NAN)) / float(real[planet]) - 1.0) < 0.0005)
	# Its frames: where Grab's model puts each part the gear reading turns.
	print("  Grab's model: %s" % _grab_said(sim))
	var worst: float = 0.0
	var missing: int = 0
	for turns: float in [0.13, 0.5, 1.7, 7.25]:
		var mine: Dictionary = sim.placed(turns)
		var theirs: Dictionary = sim.model.pose(turns * TAU)
		for key: int in theirs:
			var was: Transform3D = sim.model.rest[key]
			var gear: Transform3D = theirs[key]
			if gear.origin.distance_to(was.origin) < 1e-4 and gear.basis.is_equal_approx(was.basis):
				continue
			if not mine.has(key):
				missing += 1
				continue
			worst = maxf(worst, (mine[key] as Transform3D).origin.distance_to(gear.origin))
	print("  every part the gear reading turns, in Grab's frames: %d missing, the furthest %.5f LDU off" % [
		missing, worst])
	_check("orrery: every frame stands every turning part where the gear reading does (%d missing, %.5f LDU)"
		% [missing, worst], missing == 0 and worst < 0.01)


# -- the paths -----------------------------------------------------------------------


## Where everything stands with [param part]'s joint turned [param degrees]
## from where it was built, as a drag turns it (GrabDrag.Turning).
func _grab_turned(part: int, degrees: float) -> Dictionary:
	var turning: Variant = _grabbing.turning_for_session("#%d" % part)
	if not turning is GrabDrag.Turning:
		print("  Grab: #%d does not turn: %s" % [part, str(turning)])
		return {}
	return (turning as GrabDrag.Turning).placed_at(degrees)


## The mechanism as Simulate reads it, driven from [param part]'s body.
func _simulated(part: int) -> Simulation:
	var sim: Simulation = await _panel.read_mechanism()
	sim.drive(sim.model.body_of(part))
	return sim


## Whether Simulate took Grab's model, and why not: read by name, so this
## runs on a build from before it could.
static func _grab_said(sim: Simulation) -> String:
	var held: Variant = sim.get("grab")
	if held == null:
		return "not taken: %s" % str(sim.get("grab_note"))
	return "taken, %s" % ("a loop" if (held as Grab).linkage != null else "its gear train")


func _lines(sim: Simulation) -> String:
	var lines := PackedStringArray([str(sim.solved.get("said", ""))])
	lines.append_array(sim.rate_lines(-1, {}, 6))
	lines.append_array(sim.trouble_lines())
	return " | ".join(lines)


func _parts_free(sim: Simulation, part: int) -> bool:
	for body: int in sim.solved.get("free", []):
		if (sim.keys_of.get(body, []) as Array).has(part):
			return true
	return false


# -- measuring -------------------------------------------------------------------------


## How far [param part] stands along the rod's line (z) from where it was
## built, in [param placed] (brick id -> Transform3D); 0 when it is not there.
func _along_z(part: int, placed: Dictionary) -> float:
	if not placed.has(part):
		return 0.0
	return (placed[part] as Transform3D).origin.z - _built[part].origin.z


## How far [param part] has turned from where it was built, degrees, signed
## about its largest turn's axis as it is read: 0 when it is not in [param
## placed].
func _turn_of(part: int, placed: Dictionary) -> float:
	if not placed.has(part):
		return 0.0
	var turn: Basis = (placed[part] as Transform3D).basis.orthonormalized() \
		* (_built[part] as Transform3D).basis.orthonormalized().inverse()
	var q := Quaternion(turn)
	var angle: float = rad_to_deg(q.get_angle())
	if angle > 180.0:
		angle -= 360.0
	# Signed about +x, the line every rig here turns on.
	return angle * (1.0 if q.get_axis().x >= 0.0 else -1.0)


## How far [param tube] has slid along its rod inside [param cradle], LDU.
func _slide_in(cradle: int, tube: int, placed: Dictionary) -> float:
	var cradle_now: Transform3D = placed.get(cradle, _built[cradle])
	var tube_now: Transform3D = placed.get(tube, _built[tube])
	var was: Vector3 = ((_built[cradle] as Transform3D).affine_inverse() * (_built[tube] as Transform3D)).origin
	var now: Vector3 = (cradle_now.affine_inverse() * tube_now).origin
	# The rod runs along z where the cradle was built, read in its own frame.
	var rod: Vector3 = ((_built[cradle] as Transform3D).basis.inverse() * Vector3.BACK).normalized()
	return (now - was).dot(rod)


## Where [param ids] stand in the model now.
func _now(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for id: int in ids:
		out[id] = _world.get_brick(id).transform
	return out


var _built: Dictionary = {}


## The brick of [param part] nearest [param near] (LDraw LDU), else the first.
func _find(part: String, near: Variant = null) -> int:
	var best: int = 0
	var best_gap: float = INF
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id != part:
			continue
		if near == null:
			return brick.id
		var at: Vector3 = Vector3((near as Vector3).x, -(near as Vector3).y, -(near as Vector3).z)
		var gap: float = brick.transform.origin.distance_to(at)
		if gap < best_gap:
			best_gap = gap
			best = brick.id
	return best


func _all(part: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			out.append(brick.id)
	return out


## Open [param file] of the fixtures, or the model [param name] (an example).
func _open(file: String, name: String = "") -> bool:
	if name.is_empty():
		var path: String = FIXTURES.path_join(file)
		if not FileAccess.file_exists(path):
			_check("%s is there" % path, false)
			return false
		# Saved among the person's models and opened as a session opens one,
		# baseplate and all (File, Open of a file reads no floor from it).
		name = "probe " + file.get_basename()
		DirAccess.make_dir_recursive_absolute(ModelStore.SAVE_DIR)
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(ModelStore.SAVE_DIR + name + ".ldr"))
	var opened: String = await _say("open_model", {"name": name, "discard_changes": true})
	for _n: int in 400:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	if not opened.begins_with("Opened"):
		_check("%s opens: %s" % [file, opened], false)
		return false
	await _frames(10)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null and playback.is_playing():
		playback.stop()
	_builder.forget_history()
	await _frames(30)
	_built.clear()
	for brick: BrickWorld.Brick in _world.bricks():
		_built[brick.id] = brick.transform
	print("  %s: %d parts" % [name, _world.brick_count()])
	return _world.brick_count() > 0


## [param placed] drawn over the model as it stands (BrickWorld.set_drawn),
## pictured, and put away.
func _picture(name: String, placed: Dictionary) -> void:
	if DisplayServer.get_name() == "headless" or placed.is_empty():
		return
	_world.set_drawn(placed)
	await _shot(name)
	_world.set_drawn({})


## Tools, Simulate mechanism open on the model, driven from [param part]'s
## body and scrubbed to [param turns], pictured with its panel, and closed.
func _simulate_shot(name: String, part: int, turns: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_builder.selection.clear()
	_builder.selection[part] = true
	await _main.call("open_simulate")
	for _n: int in 600:
		await process_frame
		if _panel.sim != null and not _panel._driving and not _panel._reading:
			break
	if _panel.sim != null and _panel.sim.driver != _panel.sim.model.body_of(part):
		await _panel.drive(_panel.sim.model.body_of(part), "picked")
	_panel.scrub_to(turns)
	await _shot(name, false)
	_panel.close()
	await _frames(5)


func _shot(name: String, frame_it: bool = true) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if frame_it:
		_camera.frame(_model_box(), 1.3)
	await _frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join("%s.png" % name))


func _model_box() -> AABB:
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var here := AABB(brick.transform.origin - Vector3.ONE * 20.0, Vector3.ONE * 40.0)
		box = here if first else box.merge(here)
		first = false
	return box


func _say(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	# A long call is a job: followed to its answer, as a session follows it.
	var job: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(text)
	if job != null and tool != "job":
		for _n: int in 600:
			var polled: String = await _say("job", {"id": int(job.get_string(1))})
			if not polled.contains(" is still going"):
				return polled
	return text


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
