## Tools, Simulate mechanism…: a gear train turned from its driver, played,
## scrubbed and recorded, with every arm's period and the balance over the
## whole cycle. Phase P1b of docs/MECHANISMS.md, with P1c's period readout.
##
## The mechanism is read off the parts (Simulation, over Mechanism). The
## driver is the part the model marks (a sub-assembly named Crank, Motor or
## Handle), else the one selected, else the one that turns most of the
## train; clicking an axle or a crank drives that instead. Every part that
## turns is tinted by how fast it goes, blue slow to orange fast; the meshes
## that lock a train red, a free body amber, a floating gear violet, each
## named in the panel. Play turns the driver at the speed set; the slider
## goes anywhere in the cycle (every arm round once); Record draws a turn of
## the reference, or of the driver, off screen (StudioRender.animate) and
## keeps it as Pose's Render animation does (RenderOutput): an animated WebP,
## and on the desktop the frames and, with ffmpeg, an MP4.
##
## Simulating never changes the model. The turned parts are a picture of
## them (BrickWorld.set_drawn): nothing is moved, nothing goes into undo, and
## a save made while it plays writes the model as it was built.
##
## The program row (APP_UX9 hubprogram): a program for the model's motors
## (HubProgram), kept with the model, run at each motor's rated speed and
## stopped where Simulate finds each move stops. Its words are the model's
## as they are typed, one step of the history each time the box is written
## in (Undo takes them back), so a save, New, an open or Quit made with the
## keys still in the box keeps them as any change; and only the model they
## were typed for (hpreview F1, F2). Running it moves nothing.
##
## The power row (APP_UX11 wires): the model's cables read (Wiring), each
## battery box's switch, each IR receiver's and pole reverser's levers and
## each hub's ports worked on the part (a click on the part under the
## pointer while Simulate is open, inside a sub-assembly or a cable's path
## as anywhere: EditVerbs.part_click; a receiver's lever the one nearest the
## click) or by the row's buttons, and each motor said with its cable. A
## selection made any other way (the model tree, a session, an undo) works
## no switch. In a model that holds a battery box, a receiver or a hub, a
## motor whose cable reaches one runs at its rated speed with no load, the
## way its plugs face and its box's switch is setting its direction; Play on
## it switches on what its cable reaches where that is off, as a person
## pressing Play wants it run. Its cable pulled, it stops and says why. A
## motor with no cable of it drawn, and every motor in a model with nothing
## that gives power, turns by hand as before, and says so. The switches are
## Simulate's, not the model's: nothing is written; they are kept by the
## parts' numbers while the model changes, and forgotten when another model
## is opened (BrickWorld.generation).
##
## The balance is weighed over the cycle (Balance, through Shell's
## weigh_balance, which draws the support polygon and the centre of mass on
## the floor), and the arm that reaches furthest past the base's edge named.
##
## Where the motion stops is found over the cycle (Simulation.begin_stops):
## the first turn where moving parts meet, the driver's range either way, and
## where a motor that turns it stalls. Each is said; the two parts that meet
## are tinted red; Play stops there, the slider goes no further, and Go to
## the stop shows it.
## Over MCP, simulate_mechanism (AppTools) runs the same code: [method
## for_session].
class_name SimulatePanel
extends PanelContainer

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var shell: Shell
var scenery: Dictionary = {}
var eye: Camera3D
var look: Environment
var rig_lights: Array[DirectionalLight3D] = []
var named: Callable = func() -> String: return "Model"
## A drag's reading of the joints (GrabDrag), read ahead: the mechanism is
## turned as a drag turns it (Simulation.hold_with). Read here when null.
var grabbing: GrabDrag = null
## Whether a part is held by hand now, turned on its joint (Main's grab): the
## selection it makes as it takes hold is no choice of driver, as a click is.
var held_by_hand: Callable = func() -> bool: return false
## That selection, while it stands: not read as the driver either when the
## edit the grab made reads the mechanism again ([method _selected_body]).
## Up to appfix a part grabbed with Simulate open became its driver, its
## turns and its drawn pose gone (pastereview F4).
var _grab_selection: Dictionary = {}
## Where desktop files go; Downloads when empty. A probe points it elsewhere.
var folder: String = ""

## The mechanism as read, and the driver's turns now.
var sim: Simulation = null
var turns: float = 0.0
## Driver turns a second while it plays.
var speed: float = 0.5
var playing: bool = false
## The body periods are counted in, -1 for none.
var reference: int = -1
## The balance over the cycle, the frames it was weighed at and the arm
## furthest past the edge.
var balance: Balance.Report = null
var weighed_poses: Array = []
var furthest: Dictionary = {}
var renderer: StudioRender
var settings := RenderSettings.new()

## A frame of a recording drawn: its number, its picture. For a probe to
## read the renderer's copy of the parts as each one is.
signal frame_drawn(n: int, image: Image)

## How many frames the balance is weighed at over the cycle.
const BALANCE_FRAMES := 72
const FRAME_CHOICES: Array = [24, 48, 96]
const SPEEDS: Array = [0.1, 0.25, 0.5, 1.0, 2.0]

var _title: Label
var _driver: Label
var _readout: Label
var _trouble: Label
var _weighed: Label
var _reference: OptionButton
var _reference_bodies: Array = []
var _play: Button
var _scrub: HSlider
var _at: Label
var _speed: OptionButton
var _frames: OptionButton
var _record: Button
var _worst: Button
var _where: Button
var _stops: Label
var _close: Button
var _status: Label
var _frame: TextureRect
var _quiet: bool = false
var _reading: bool = false
var _driving: bool = false
## The body a click chose while a drive was still turning, weighing and
## checking where it stops, driven as soon as that gives way; -1 for none.
## A phone draws a frame slowly, and the stop check, a slice a frame, ran for
## seconds after Simulate opened: a tap then was dropped (smalls4,
## phonepanels' busy tap). phonewalk's 3 taps for a driver were not this:
## its first two landed on the orrery's frame, which does not turn.
var _wanted: int = -1
## The body the drive under way is turning.
var _driving_to: int = -1
var _recording: bool = false
var _seen_revision: int = -1
var _last: Dictionary = {}
var _told_page: String = ""
var _told_page_at: int = 0

## The model's cables and the switches as worked here (Wiring), and while
## Play runs a motor by its power, its rate in driver turns a second, signed
## (0 while Play turns the driver by hand).
var wiring: Wiring = null
## The model the switches were worked in (BrickWorld.generation): another
## one's part numbers start again at 1, so its switches are not these.
var _wiring_generation: int = -1
var _power_rate: float = 0.0
var _power_rows: VBoxContainer
var _power_buttons: HFlowContainer
var _power_said: Label

## The program row: the program running, how far in (seconds), its run
## (HubProgram.run), the motors on the hub's ports (HubProgram.ports_of),
## and each port's mechanism, driven from its motor, with its torque curve
## (HubProgram.curve_of). The panel's own reading drives the first port.
var running: bool = false
var program_time: float = 0.0
## When the run began (Time.get_ticks_usec): its time is the clock's, so a
## slow frame shows where the motors are by then, at their rated speed in
## real time, rather than slowing the run with the frames.
var _program_began: int = 0
var _ran: Dictionary = {}
var _ports: Dictionary = {}
var _port_sims: Dictionary = {}
var _port_curves: Dictionary = {}
var _preparing: bool = false
var _program_rows: VBoxContainer
## What acts on a mechanism: the periods, Play and its speed, the slider,
## Program and Record. Out of sight while nothing turns (ux14's walk, p13:
## two gears on the baseplate, and a column of controls that did nothing).
var _drive_rows: Array[Control] = []
var _program_box: TextEdit
var _run: Button
var _program_said: Label
## The model's program as the box last showed it or wrote it, the box's
## words then, the model it was (BrickWorld.generation), and the line lit.
var _shown_program: String = ""
var _box_said: String = ""
var _shown_generation: int = -1
var _lit_line: int = -1
## The history step the words being typed are written into while it is the
## newest; {} for none, as once the box is left.
var _typing_step: Dictionary = {}
## Whether the parts are drawn where a program's run left them.
var _program_posed: bool = false
## How long a frame gives working out a run (HubProgram.run_step).
const RUN_SLICE_MS := 6.0


func _ready() -> void:
	visible = false
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = Vector2i(480, 300)
	settings.contact_shadow = false
	settings.view = "current"
	_build()


# -- opening and reading ------------------------------------------------------------


## Read the model's mechanism and drive it: the part the model marks, else
## the one selected, else the one that turns most.
func open() -> void:
	visible = true
	_show_program_text()
	await read()


func close() -> void:
	if renderer != null and renderer.is_busy():
		renderer.cancel()
	_stop()
	# Words written in the box and not run are the model's as the panel goes.
	_commit_program()
	_stop_program()
	_port_sims.clear()
	visible = false
	if world != null:
		world.set_drawn({})
		world.set_tinted({})
	if shell != null and shell._balance_mark != null:
		shell._balance_mark.clear()
	sim = null
	_wanted = -1


func read() -> void:
	if _reading or world == null:
		return
	_reading = true
	_stop()
	_stop_program()
	_port_sims.clear()
	_program_posed = false
	world.set_drawn({})
	_status.text = ""
	_stops.text = ""
	_where.disabled = true
	_frame.visible = false
	var job: Working.Job = Working.begin("Reading the mechanism…")
	await job.shown()
	sim = await read_mechanism()
	_seen_revision = world.revision
	read_wiring()
	var body: int = sim.marked()
	var how: String = "its motor turns it" if sim.motored.has(body) else "the model marks it"
	var running: int = _running_body()
	if running >= 0:
		body = running
		how = "its cable's box is on"
	if body < 0:
		body = _selected_body()
		how = "selected"
	if body < 0:
		body = sim.best()
		how = "it turns the most"
	job.end()
	_reading = false
	_show_driving(body >= 0)
	if body < 0:
		_driver.text = "Nothing here turns on an axle, a pin or a turntable."
		_readout.text = ("Build a gear train: gears on axles through Technic holes, meshing at "
			+ "their pitch, and click the axle a crank or a motor turns.")
		_trouble.text = "\n".join(sim.trouble_lines())
		_fill_references()
		return
	await drive(body, how)
	# A motor its cable gives power runs, as the real one would, whether it
	# ran before this reading or its plug was put back just now.
	if running >= 0 and sim != null and sim.driver == running:
		play()


## The controls that act on a mechanism shown, or put away while nothing
## turns ([member _drive_rows]): what is left says why, and what to build.
func _show_driving(shown: bool) -> void:
	for control: Control in _drive_rows:
		if is_instance_valid(control):
			control.visible = shown


## The model's cables read again (Wiring), the switches as they were worked
## kept by the parts' numbers, and the power row shown.
func read_wiring() -> void:
	var same: bool = wiring != null and _wiring_generation == world.generation()
	var before: Dictionary = wiring.settings if same else {}
	wiring = Wiring.read(world.bricks(), sim.motors if sim != null
		else Simulation.motors_in(world.bricks(), library), true)
	_wiring_generation = world.generation()
	for key: Variant in before:
		wiring.settings[key] = before[key]
	_show_power()


## The body of the first motor its cable runs, -1 for none: with nothing in
## the model that gives power, none.
func _running_body() -> int:
	if wiring == null or sim == null or not wiring.has_power():
		return -1
	for body: int in sim.motored:
		var motor: int = int(sim.motored[body])
		if absf(float(wiring.power_of(motor)["run"])) > 1e-6 and sim.can_drive(body):
			return body
	return -1


## The driver's motor's power, when the model holds a battery box, a
## receiver or a hub and a cable of its motor is drawn: {"run", "why",
## "words", "wired", "by_hand"}; empty when Play turns the driver by hand.
func driver_power() -> Dictionary:
	if wiring == null or sim == null or not wiring.has_power() or not sim.motored.has(sim.driver):
		return {}
	var power: Dictionary = wiring.power_of(int(sim.motored[sim.driver]))
	return {} if bool(power["by_hand"]) else power


## The mechanism as the model stands, read on a worker for a big model so
## the window keeps drawing (the Working bar is up meanwhile).
func read_mechanism() -> Simulation:
	var bricks: Array = world.bricks()
	if bricks.size() < READ_OFF_THREAD_FROM or OS.has_feature("nothreads"):
		return await _held(Simulation.read(bricks, library, scenery))
	var still: BrickWorld = world.copy_for_reading()
	var standing: Array = still.bricks()
	# Every mesh it reads, loaded here first: a reader may not load one.
	for brick: BrickWorld.Brick in standing:
		library.mesh_for(brick.part_id)
	var made: Array = [null]
	library.begin_reading()
	var task: int = WorkerTasks.add(func() -> void:
		made[0] = Simulation.read(standing, library, scenery), false, "read the mechanism")
	library.reading_in(task)
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerTasks.collect(task)
	library.end_reading(task)
	still.free()
	return await _held(made[0])


## [param simulation] read in the world as a drag reads it, with the drag's
## joints when they are read for the model as it stands: waited for while a
## worker reads them (GrabDrag._ready_ahead) rather than read again here
## beside it.
func _held(simulation: Simulation) -> Simulation:
	if simulation == null or builder == null:
		return simulation
	while grabbing != null and grabbing.reads_ahead() and grabbing.is_reading():
		await get_tree().process_frame
	var joints: Bodies = grabbing.read_bodies() if grabbing != null else null
	if joints == null and world.brick_count() >= READ_OFF_THREAD_FROM:
		# Read ahead off the frame once the model stands still (GrabDrag); not
		# read here on it, where a big model's joints hold the window.
		simulation.grab_note = "the joints a drag reads are not read yet"
		return simulation
	simulation.hold_with(world, builder, joints)
	return simulation


const READ_OFF_THREAD_FROM := 600


## The body most of the selection is in that turns on a joint, or -1.
func _selected_body() -> int:
	if builder == null or sim == null:
		return -1
	if not _grab_selection.is_empty() and builder.selection == _grab_selection:
		return -1
	var counted: Dictionary = {}
	for brick_id: Variant in builder.selection:
		if not sim.model.parts.has(int(brick_id)):
			continue
		var body: int = sim.model.body_of(int(brick_id))
		if sim.can_drive(body):
			counted[body] = int(counted.get(body, 0)) + 1
	var best: int = -1
	for body: int in counted:
		if best < 0 or int(counted[body]) > int(counted[best]):
			best = body
	return best


## Drive [param body]: solved, tinted, its periods read and the balance
## weighed over its cycle. [param how] says why it is the driver.
func drive(body: int, how: String = "picked") -> void:
	if sim == null or _driving:
		return
	_driving = true
	_driving_to = body
	# What was said of the last driver or the last tap goes: a tap on the
	# frame, then one on the Earth, left "That part does not turn on anything
	# here" under "Driver: Earth, tapped".
	_status.text = ""
	_stop()
	turns = 0.0
	var job: Working.Job = Working.begin("Turning the mechanism…")
	await job.shown()
	sim.drive(body)
	job.end()
	if bool(sim.solved.get("locked", false)) and how == "it turns the most":
		how = "the app's pick"
	reference = _default_reference(sim)
	_fill_references()
	_driver.text = "Driver: %s, %s. Click an axle or a crank to drive that instead." % [
		sim.named_with_parts(body, 2), how]
	_scrub_range()
	_show_readout()
	world.set_drawn({})
	await weigh()
	# A part clicked meanwhile is the driver now: where this one stops is
	# not asked.
	if _wanted < 0:
		await check_stops()
	_driving = false
	if sim == null:
		_wanted = -1
		return
	var next: int = _wanted
	_wanted = -1
	if next >= 0 and next != sim.driver:
		await drive(next, "clicked")
		return
	world.set_tinted(sim.tints())
	_show_pose()


## The body named after Earth that turns, else none.
static func _default_reference(simulation: Simulation) -> int:
	for body: int in simulation.turning:
		if Simulation.planet_in(str(simulation.names[body])) == "earth":
			return body
	return -1


## Weigh the balance over the whole cycle, every arm round once.
func weigh() -> void:
	balance = null
	furthest = {}
	weighed_poses = []
	if sim == null or not sim.moves_anything() or shell == null:
		_weighed.text = ""
		return
	weighed_poses = sim.poses(sim.cycle(), BALANCE_FRAMES)
	balance = await shell.weigh_balance(weighed_poses, true, false)
	if balance != null and not balance.empty:
		furthest = sim.furthest_out(balance.support, weighed_poses)
	_weighed.text = balance_words(sim, balance, furthest, weighed_poses.size())
	_worst.disabled = balance == null or balance.worst_index < 0


## The balance over the cycle in words: the margin at its worst and where,
## and the arm furthest out. For a session ([param numbers]), Balance's own
## numbers in place of the person's sentence.
static func balance_words(simulation: Simulation, report: Balance.Report, out: Dictionary,
		frames: int, numbers: bool = false) -> String:
	if report == null or report.empty:
		return ""
	var said: String = report.words()
	if numbers:
		said = report.said().get_slice("\n", 0).trim_prefix("Balance: ")
	var line: String = "Balance over %d frames of the cycle (%s turns of %s): %s" % [frames,
		Simulation.figure(simulation.cycle()), simulation.names.get(simulation.driver, "the driver"),
		said]
	if not out.is_empty() and float(out["studs"]) > 0.0:
		line += " Furthest out: %s, %s studs past the %s edge with %s." % [
			simulation.names[int(out["body"])], Balance.studs(float(out["studs"])), out["edge"],
			out["label"]]
	return line


## Find where the motion stops: what meets over the cycle, the driver's
## range and a motor's stall, said in the panel.
func check_stops() -> void:
	_stops.text = ""
	_where.disabled = true
	if sim == null or sim.moving.is_empty():
		return
	var simulation: Simulation = sim
	var job: Working.Job = Working.begin("Checking where it stops…")
	await job.shown()
	await find_stops(simulation, true)
	job.end()
	if sim != simulation:
		return
	_stops.text = "\n".join(sim.stop_lines())
	_where.disabled = sim.stop_on() == INF


## [method Simulation.stops_step] a slice a frame, so the window keeps
## drawing; [param panel]'s stops given up once the panel reads another.
func find_stops(simulation: Simulation, panel: bool = false) -> void:
	simulation.begin_stops(simulation.cycle())
	while not simulation.stops_step(STOP_SLICE_MS):
		await get_tree().process_frame
		if panel and (sim != simulation or _wanted >= 0):
			return


## Milliseconds of finding where it stops a frame.
const STOP_SLICE_MS := 12.0


## Whether the motion's stops are found and Play and the slider keep short of
## them.
func _stopping() -> bool:
	return sim != null and sim.stops_done and sim.stop_on() != INF


# -- the readout -------------------------------------------------------------------


func _show_readout() -> void:
	if sim == null:
		return
	var lines := PackedStringArray()
	lines.append(str(sim.solved.get("said", "")))
	lines.append_array(sim.rate_lines(reference))
	_readout.text = "\n".join(lines)
	_trouble.text = "\n".join(sim.trouble_lines())


func _fill_references() -> void:
	_quiet = true
	_reference.clear()
	_reference_bodies = [-1]
	_reference.add_item("Periods in turns of the driver")
	if sim != null:
		for body: int in sim.turning:
			_reference_bodies.append(body)
			_reference.add_item("Periods in turns of %s" % sim.names[body])
	_reference.select(maxi(_reference_bodies.find(reference), 0))
	_quiet = false


func _scrub_range() -> void:
	_quiet = true
	var span: float = sim.cycle() if sim != null else 1.0
	_scrub.min_value = 0.0
	_scrub.max_value = span
	_scrub.step = span / 3600.0
	_scrub.set_value_no_signal(0.0)
	_quiet = false


# -- playing and scrubbing -----------------------------------------------------------


func play() -> void:
	_stop_program()
	if playing:
		_stop()
		return
	if sim == null or sim.moving.is_empty():
		_status.text = "Nothing turns from this driver."
		return
	_power_rate = 0.0
	var power: Dictionary = driver_power()
	var by_hand: String = _by_hand_said()
	if not by_hand.is_empty():
		_status.text = by_hand
	if not power.is_empty():
		var motor: int = int(sim.motored[sim.driver])
		# Play on a motor wants it run: what its cable reaches switched on
		# where it is off (a box, a receiver's lever, a hub and its port),
		# as a person would before pressing it.
		var switched: PackedStringArray = wiring.switch_on_for(motor) if absf(float(power["run"])) < 1e-6 \
			else PackedStringArray()
		if not switched.is_empty():
			power = wiring.power_of(motor)
			_show_power()
		var run: float = float(power["run"])
		if absf(run) < 1e-6:
			_status.text = tr("%s does not run: %s.") % [_motor_said(motor), str(power["why"])]
			return
		# At its rated speed with no load, the way its cable runs it.
		_power_rate = float((Simulation.MOTORS[sim.motors[motor]] as Array)[2]) / 60.0 * run
		_status.text = tr("%s runs %s at %s rpm: %s.") % [_motor_said(motor), tr("forward", &"power") if run > 0.0
			else tr("back", &"power"), Simulation.figure(roundf(absf(_power_rate) * 60.0)), str(power["words"])]
		if not switched.is_empty():
			var first: String = "; ".join(switched)
			_status.text = first.left(1).to_upper() + first.substr(1) + ". " + _status.text
	if _stopping() and turns >= sim.stop_on() - 1e-6 and _power_rate >= 0.0:
		turns = 0.0
	if _power_rate < 0.0 and sim.stops_done and sim.stop_back() != -INF and turns <= sim.stop_back() + 1e-6:
		turns = 0.0
	playing = true
	_play.text = "Pause"


## "The Power Functions L motor (#12)".
func _motor_said(motor: int) -> String:
	return tr("The %s (#%d)") % [str((Simulation.MOTORS[sim.motors[motor]] as Array)[0]), motor]


## Why Play turns the driver's motor by hand where the model gives motors
## power: no cable of it is drawn. "" for any other driver.
func _by_hand_said() -> String:
	if wiring == null or sim == null or not wiring.has_power() or not sim.motored.has(sim.driver):
		return ""
	var motor: int = int(sim.motored[sim.driver])
	var power: Dictionary = wiring.power_of(motor)
	return tr("%s: %s.") % [_motor_said(motor), str(power["why"])] if bool(power["by_hand"]) else ""


## A click with Select on the part [param brick] under the pointer (along
## the line from [param origin] along [param way]) while Simulate is open:
## a battery box's, a receiver's, a pole reverser's or a hub's switch is
## worked, as a finger works it on the part, whatever sub-assembly or cable
## path it is in, and the click selects nothing. False for any other part,
## whose click selects as ever (EditVerbs.part_click).
func take_click(brick: int, origin: Vector3, way: Vector3) -> bool:
	if not visible or wiring == null or _reading or not wiring.sources.has(brick):
		return false
	work_switch(brick, wiring.output_at(brick, origin, way))
	return true


func _stop() -> void:
	playing = false
	_power_rate = 0.0
	if _play != null:
		_play.text = "Play"


## Turn the driver to [param at] turns from where it was built, and show it.
func scrub_to(at: float) -> void:
	_stop()
	_stop_program()
	turns = maxf(at, 0.0)
	_show_pose()


## Where the driver stops going on: what meets, where its motor stalls or
## its loop goes no further, said.
func go_to_stop() -> void:
	if not _stopping():
		return
	scrub_to(sim.stop_on())
	_status.text = "Stops at %s: %s." % [Simulation.angle(sim.stop_on()), sim.stopped_said()]


## The worst frame of the balance.
func go_to_worst() -> void:
	if balance == null or balance.worst_index < 0 or balance.worst_index >= weighed_poses.size():
		return
	scrub_to(float((weighed_poses[balance.worst_index] as Dictionary)["turns"]))


func _show_pose() -> void:
	if sim == null or world == null:
		return
	_program_posed = false
	# No further than where it stops: two parts do not go through each other,
	# nor a stalled motor turn on.
	if _stopping() and turns > sim.stop_on():
		turns = sim.stop_on()
		if playing:
			_stop()
			_status.text = "Stopped at %s: %s." % [Simulation.angle(turns), sim.stopped_said()]
	elif sim.stops_done and turns < 0.0 and sim.stop_back() != -INF and turns < sim.stop_back():
		turns = sim.stop_back()
		if playing:
			_stop()
			_status.text = "Stopped at %s going back." % Simulation.angle(turns)
	world.set_drawn(sim.placed(turns))
	var span: float = sim.cycle()
	_quiet = true
	_scrub.set_value_no_signal(fmod(turns, span) if span > 0.0 else 0.0)
	_quiet = false
	_at.text = "%s %s" % [sim.names.get(sim.driver, "the driver"), Simulation.turned(turns)]


func _process(delta: float) -> void:
	if not visible:
		Wake.rest(self)
		return
	# Something else changed the model: an edit, an undo. What turns is read
	# again from the model as it now is.
	if not _reading and not _driving and not _recording and world != null \
			and world.revision != _seen_revision:
		_seen_revision = world.revision
		read()
		return
	if running:
		program_time = (Time.get_ticks_usec() - _program_began) / 1e6
		_show_program_pose()
	elif playing and sim != null:
		turns += (_power_rate if _power_rate != 0.0 else speed) * delta
		_show_pose()
	# The model's program changed by an undo, a redo, an open or a session:
	# the box shows it, whether or not the person is writing in it, as the
	# words typed are the model's already. Another model (an open, New)
	# shows its own: the words were the last one's, kept there as typed.
	if world != null and _program_box != null and (world.generation() != _shown_generation
			or world.program != _shown_program):
		_show_program_text()
		# A run's pose drawn for a program taken back (Undo after a stopped
		# run) goes with it: the parts drawn where they were built.
		if _program_posed and not running and sim != null:
			_program_posed = false
			turns = 0.0
			_show_pose()
	_tell_page()


## A click on a part while the panel is open: drive its body, when it turns.
func _on_selection(_count: int) -> void:
	if builder != null and held_by_hand.call():
		_grab_selection = builder.selection.duplicate()
		return
	_grab_selection = {}
	if not visible or sim == null or _reading or _quiet:
		return
	var body: int = _selected_body()
	# Still turning the last driver: this one goes next, and the stop check
	# under way gives up (drive).
	if _driving:
		if body >= 0:
			_wanted = body if body != _driving_to else -1
		return
	if body < 0:
		if builder != null and not builder.selection.is_empty():
			_status.text = "That part does not turn on anything here: click an axle or a crank."
		return
	if body != sim.driver:
		drive(body, "clicked")


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		if _recording and renderer != null:
			renderer.cancel()
		elif _program_box != null and _program_box.has_focus():
			# Out of the box first: Escape there leaves it, as a field's does.
			_program_box.release_focus()
		else:
			close()
		get_viewport().set_input_as_handled()


# -- the program -----------------------------------------------------------------------


## Run the model's program (Run), or stop it (Stop): the box's words made the
## model's first, each port it names driven from its motor, and the run
## played at each motor's rated speed from where the model was built.
func run_program() -> void:
	if running:
		_stop_program()
		return
	if sim == null or world == null or _reading or _driving or _preparing or _recording:
		return
	_commit_program()
	_stop()
	var program: HubProgram = HubProgram.parse(world.program)
	if program.is_empty():
		_program_said.text = ("Write a program first, a line each: \"to 90° at 50%\", "
			+ "\"wait 1 s\", \"repeat 3\" with the lines it repeats under it.")
		_said_into_view()
		return
	_preparing = true
	_run.disabled = true
	var job: Working.Job = Working.begin("Running the program…")
	await job.shown()
	var made: Dictionary = await prepare_run(program, sim, true)
	job.end()
	_preparing = false
	_run.disabled = false
	if made.has("refusal"):
		_program_said.text = str(made["refusal"])
		_said_into_view()
		return
	_ran = made["ran"]
	_ports = made["ports"]
	_port_sims = made["sims"]
	_port_curves = made["curves"]
	if not str(_ran.get("refusal", "")).is_empty():
		_program_said.text = str(_ran["refusal"])
		_said_into_view()
		return
	program_time = 0.0
	_program_began = Time.get_ticks_usec()
	running = true
	_program_posed = true
	_run.text = "Stop"
	_show_program_pose()
	_said_into_view()


## The program [param program] run on the model as [param simulation] reads
## it: each port it names driven from its motor (with [param panel], the
## first by the panel's own reading, driven there as a click drives it; the
## next each by a reading of its own), where each one's motion stops found,
## and the run (HubProgram.run). {ran, ports, sims, curves}, or {refusal}.
func prepare_run(program: HubProgram, simulation: Simulation, panel: bool) -> Dictionary:
	if not program.errors.is_empty():
		return {"refusal": "\n".join(program.errors)}
	var ports: Dictionary = HubProgram.ports_of(simulation.motors)
	var used: Variant = program.ports_used(ports)
	if used is String:
		return {"refusal": used}
	var sims: Dictionary = {}
	var curves: Dictionary = {}
	var bodies: Dictionary = {}
	for port: String in used:
		var motor: Dictionary = ports[port]
		var body: int = SimulatePanel._motored_body(simulation, int(motor["key"]))
		if body < 0:
			return {"refusal": ("%s turns nothing: its output holds no axle or pin here. Put "
				+ "an axle in its hub.") % HubProgram.port_said(port, motor)}
		var one: Simulation = simulation
		if not sims.is_empty():
			one = await read_mechanism()
		if panel and one == sim:
			if sim.driver != body or not sim.stops_done:
				await drive(body, "its motor turns it")
			if sim != one:
				return {"refusal": "The model changed as the program began: run it again."}
		else:
			one.drive(body)
		if not bool(one.solved.get("ok", false)):
			return {"refusal": "%s cannot turn: %s." % [HubProgram.port_said(port, motor),
				str(one.solved.get("said", ""))]}
		# Where it stops, found for this driver: the panel's drive found it
		# unless a click came meanwhile; a reading of its own, here.
		if not (panel and one == sim and one.stops_done):
			await find_stops(one)
		sims[port] = one
		curves[port] = HubProgram.curve_of(one)
		bodies[port] = body
	# Two motors whose trains turn each other: the one train held by both.
	for port: String in sims:
		for other: String in sims:
			if port != other and absf(float((sims[port] as Simulation).rates.get(bodies[other], 0.0))) \
					> Simulation.STILL:
				return {"refusal": ("%s and %s turn the same train: a program drives only one of "
					+ "them. Take the other's lines out, or part their trains.") % [
						HubProgram.port_said(port, ports[port]), HubProgram.port_said(other, ports[other])]}
	var reach := func(port: String, from: float, to: float) -> Dictionary:
		return HubProgram.reach_in(sims[port], curves[port], from, to)
	# A slice a frame, as the stops are found: made in one go, 2,000 moves
	# held the window 174 ms (hpreview F6).
	program.begin_run(ports, reach)
	while not program.run_step(RUN_SLICE_MS):
		await get_tree().process_frame
	return {"ran": program.ran, "ports": ports, "sims": sims, "curves": curves}


## The body [param key]'s motor turns in [param simulation], -1 for none.
static func _motored_body(simulation: Simulation, key: int) -> int:
	for body: int in simulation.motored:
		if int(simulation.motored[body]) == key:
			return body
	return -1


## Where every part each port's motor moves stands [param t] seconds into
## [param ran]: brick id -> Transform3D.
static func program_pose(ran: Dictionary, sims: Dictionary, t: float) -> Dictionary:
	var pose: Dictionary = {}
	var angles: Dictionary = HubProgram.angles_at(ran, t)
	for port: String in angles:
		var one: Simulation = sims.get(port)
		if one != null:
			pose.merge(one.placed(float(angles[port])), true)
	return pose


func _show_program_pose() -> void:
	if world == null:
		return
	var seconds: float = float(_ran.get("seconds", 0.0))
	var t: float = minf(program_time, seconds)
	world.set_drawn(SimulatePanel.program_pose(_ran, _port_sims, t))
	var angles: Dictionary = HubProgram.angles_at(_ran, t)
	for port: String in _port_sims:
		if _port_sims[port] == sim and angles.has(port):
			turns = float(angles[port])
	if sim != null:
		_at.text = "%s %s" % [sim.names.get(sim.driver, "the driver"), Simulation.turned(maxf(turns, 0.0))]
		# The slider goes round with it, as with Play: it stayed at 0 while
		# the arm stood at 42° (hpreview F7).
		var span: float = sim.cycle()
		_quiet = true
		_scrub.set_value_no_signal(fposmod(turns, span) if span > 0.0 else 0.0)
		_quiet = false
	_light_line(HubProgram.line_at(_ran, t))
	if program_time >= seconds:
		running = false
		_run.text = "Run"
		_light_line(int((_ran.get("stopped", {}) as Dictionary).get("line", 0)))
		_program_said.text = HubProgram.ran_words(_ran, _ports)
		_said_into_view()
		return
	_program_said.text = "%s s of %s s: line %d" % [Simulation.figure(snappedf(t, 0.1)),
		Simulation.figure(snappedf(seconds, 0.01)), HubProgram.line_at(_ran, t)]


## Stop the program where it is, its words said.
func _stop_program() -> void:
	if not running:
		return
	running = false
	if _run != null:
		_run.text = "Run"
		_program_said.text = "Stopped %s s in." % Simulation.figure(snappedf(program_time, 0.1))
		_said_into_view()
	_light_line(-1)


## Line [param line] of the box lit (from 1); 0 or less for none.
func _light_line(line: int) -> void:
	if _program_box == null or line == _lit_line:
		return
	if _lit_line > 0 and _lit_line <= _program_box.get_line_count():
		_program_box.set_line_background_color(_lit_line - 1, Color(0, 0, 0, 0))
	_lit_line = line
	if line > 0 and line <= _program_box.get_line_count():
		_program_box.set_line_background_color(line - 1, Color(0.30, 0.55, 1.0, 0.28))


## The box made the model's program, as the model has it.
func _show_program_text() -> void:
	if _program_box == null or world == null:
		return
	_shown_program = world.program
	_shown_generation = world.generation()
	_typing_step = {}
	# A model shared to look at keeps its program as it is (set_program).
	_program_box.editable = shell == null or not shell.read_only
	if _program_box.text != world.program:
		_program_box.text = world.program
		_lit_line = -1
	_box_said = _program_box.text


## The person's typing, the model's program at once (the box's text_changed,
## which comes at the frame's end): one step of the history for each time the
## box is written in, its words the newest typed while it is the newest step.
## So a save, New, an open or Quit made with the keys in the box keeps them
## (hpreview F2: Ctrl+S wrote the program as it was), and on the model they
## were typed for alone (F1: typed for one model and the box left after a
## session opened another, they became that one's).
func _typed() -> void:
	_commit_program()


## The box left: the next words typed are a step of their own.
func _left_box() -> void:
	_commit_program()
	_typing_step = {}


## The box's words made the model's program where they are not yet: as
## they are typed, as Run is pressed, as the box is left (and so before a
## save, New, an open or Quit: ModelBar.end_typing), at once, not at the
## frame's end. Typed for a model no longer here, they are dropped, never
## another's: that one's own is shown.
func _commit_program() -> void:
	if _program_box == null or world == null:
		return
	if world.generation() != _shown_generation:
		_show_program_text()
		return
	if _program_box.text == _box_said:
		return
	_box_said = _program_box.text
	if shell != null and shell.read_only:
		return
	var words: String = _box_said if not _box_said.strip_edges().is_empty() else ""
	if words != world.program:
		if builder != null and not _typing_step.is_empty() and is_same(builder.last_step(), _typing_step):
			world.program = words
			if shell != null and shell.store != null:
				shell.store.touch()
		else:
			set_program(words)
			_typing_step = builder.last_step() if builder != null else {}
	_shown_program = world.program


## [param words] made the model's program (blanks, none): one step of the
## history, which Undo takes back, and a save writes. False when it was so
## already, or the model is one shared to look at.
func set_program(words: String) -> bool:
	if words.strip_edges().is_empty():
		words = ""
	if world == null or words == world.program or (shell != null and shell.read_only):
		return false
	var had: String = world.program
	world.program = words
	_typing_step = {}
	if builder != null:
		builder.record([{"undo": "program", "program": had}],
			"took the program out" if words.is_empty() else "set the program")
	if _program_box != null and not _program_box.has_focus():
		_show_program_text()
	return true


# -- recording ------------------------------------------------------------------------


## Record a turn of the reference (or of the driver) in [param frames]
## frames, as Pose's Render animation keeps one. Returns how many were
## drawn; [member _last] says where they went.
func record(frames: int = 0) -> int:
	if sim == null or _recording:
		return 0
	if frames <= 0:
		frames = int(FRAME_CHOICES[maxi(_frames.selected, 0)])
	return await record_of(sim, reference, frames)


## [param view] is RenderSettings.view: the person's own camera when empty,
## as they see it; a session's is "hero", since it cannot see the window.
## [param given] is the job a session's call reports to (ToolJobs), the
## frames counted on it and its cancel stopping the renderer; without one
## the recording is a Working job of its own.
func record_of(simulation: Simulation, of: int, frames: int, turns_of: float = 1.0,
		view: String = "", given: Working.Job = null) -> int:
	if _recording:
		return 0
	if not StudioRender.possible():
		_status.text = "Recording needs something to draw with, and this app has no window."
		return 0
	if simulation.turning.is_empty():
		_status.text = "Nothing turns from this driver: nothing to record."
		return 0
	_stop()
	_recording = true
	_set_working(true)
	_last = {}
	var span: float = simulation.turns_for(of) * maxf(turns_of, 0.01)
	var poses: Array = []
	for n: int in frames:
		poses.append(simulation.placed(span * float(n) / float(frames)))
	var job: Working.Job = given
	if job == null:
		job = Working.begin("Recording the mechanism…", frames, true)
		await job.shown()
	else:
		job.count(0, frames)
	var stop := func() -> void:
		if renderer != null:
			renderer.cancel()
	job.cancel_wanted.connect(stop)
	_renderer()
	var chosen: RenderSettings = settings.copy()
	chosen.fps = 24
	chosen.frames = frames
	if not view.is_empty():
		chosen.view = view
	var output := RenderOutput.new()
	output.folder = folder
	var model: String = str(named.call())
	output.begin_turntable(model, chosen, "_mechanism")
	var started: int = Time.get_ticks_msec()
	var done: int = await renderer.animate(world, chosen, frames,
		func(n: int) -> Dictionary: return poses[n],
		func(_n: int) -> float: return 0.0, _reach(simulation, poses),
		func(n: int, image: Image) -> void:
			job.count(n + 1)
			_frame.texture = ImageTexture.create_from_image(image)
			_frame.visible = true
			frame_drawn.emit(n, image)
			await output.add_frame(n, image))
	await output.settle()
	job.cancel_wanted.disconnect(stop)
	var lines := PackedStringArray()
	if done == frames:
		job.say("Putting the frames together…")
		job.count(0, 0)
		lines = await output.finish_turntable()
	if given == null:
		job.end()
	_recording = false
	_set_working(false)
	var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
	if lines.is_empty():
		_status.text = "Cancelled." if done < frames else "Nothing was kept."
		_last = {"frames": done, "said": _status.text}
		return done
	_last = {"frames": done, "seconds": seconds, "paths": Array(output.paths),
		"said": "; ".join(lines), "turns": span}
	_status.text = "Recorded %d frames of %s turns of %s in %.0f s: %s." % [done,
		Simulation.figure(span), simulation.names.get(simulation.driver, "the driver"), seconds,
		"; ".join(lines)]
	return done


## The last recording: {frames, seconds, paths, said, turns}.
func last_recording() -> Dictionary:
	return _last


func is_recording() -> bool:
	return _recording


func _renderer() -> void:
	if renderer == null:
		renderer = StudioRender.new()
		add_child(renderer)
	renderer.library = library
	renderer.scenery = scenery
	renderer.eye = eye
	renderer.look = look
	renderer.rig_lights = rig_lights


## The box the moving parts sweep, with the model, for the framing.
func _reach(simulation: Simulation, poses: Array) -> AABB:
	var box := AABB()
	var first: bool = true
	for placed: Dictionary in poses:
		for key: Variant in placed:
			var piece: Mechanism.Piece = simulation.model.parts.get(int(key))
			if piece == null or piece.mesh == null:
				continue
			var here: AABB = ((placed[key] as Transform3D) * piece.mesh.bounds).abs()
			box = here if first else box.merge(here)
			first = false
	return box


## One picture of the mechanism with the driver turned [param at] turns,
## the model's own colours, off screen, from the hero view: for a session,
## which cannot see the window's camera. Null without a window.
func picture(simulation: Simulation, at: float, given: Dictionary = {}) -> Image:
	if not StudioRender.possible() or _recording:
		return null
	_renderer()
	if renderer.is_busy():
		return null
	var chosen: RenderSettings = settings.copy()
	chosen.size = Vector2i(720, 450)
	chosen.view = "hero"
	# [param given]: a pose of its own (a program's, every port's motor).
	var pose: Dictionary = given if not given.is_empty() else simulation.placed(at)
	var shot: Array = [null]
	await renderer.animate(world, chosen, 1, func(_n: int) -> Dictionary: return pose,
		func(_n: int) -> float: return 0.0, _reach(simulation, [pose]),
		func(_n: int, image: Image) -> void: shot[0] = image)
	return shot[0]


func _set_working(on: bool) -> void:
	_record.disabled = on
	_play.disabled = on
	_scrub.editable = not on


# -- for a session over MCP ---------------------------------------------------------------


## simulate_mechanism (AppTools): the same reading, driving, periods and
## balance as the panel, said compactly with what to do about it, a picture
## of its worst frame, and a recording when asked. Never changes the model,
## and leaves the panel as the person left it; but program= sets the model's
## program and runs it ([method _program_for_session]). A String, or text and a
## picture. Each slow step is on the Working bar, as the panel's are. With
## record=true the call is a job (ToolJobs.long_call), [param work], which
## the recording's frames are counted on.
func for_session(input: Dictionary, work: Working.Job = null) -> Variant:
	if world == null:
		return "This app cannot simulate from outside."
	var job: Working.Job = Working.begin("Reading the mechanism…")
	await job.shown()
	var simulation: Simulation = await read_mechanism()
	if input.has("program"):
		job.end()
		return await _program_for_session(simulation, str(input["program"]))
	var power_asked: String = str(input.get("power", "")).strip_edges().to_lower()
	var wired: Wiring = session_wiring(power_asked, simulation)
	var chosen: Dictionary = _session_driver(simulation, str(input.get("driver", "")))
	# The motor its cable runs drives, unless driver= names another.
	if str(input.get("driver", "")).strip_edges().is_empty() and wired.has_power():
		for turned: int in simulation.motored:
			var power: Dictionary = wired.power_of(int(simulation.motored[turned]))
			if absf(float(power["run"])) > 1e-6 and simulation.can_drive(turned):
				chosen = {"body": turned, "how": "its cable's box is on"}
				break
	job.end()
	if chosen.has("refusal"):
		return "\n".join(PackedStringArray([str(chosen["refusal"])]) + power_words(wired))
	var body: int = chosen["body"]
	# The driver's motor as Play runs it (S2): by its cable, the way its
	# plugs face; with power= not given, what its cable reaches switched on
	# where it is off, as Play does; not run at all when its cable is pulled
	# or what it reaches is off. One with no cable drawn turns by hand.
	var run: float = 1.0
	var said_power: String = ""
	if wired.has_power() and simulation.motored.has(body):
		var motor: int = int(simulation.motored[body])
		var power: Dictionary = wired.power_of(motor)
		if not bool(power["by_hand"]):
			if power_asked.is_empty() and absf(float(power["run"])) < 1e-6:
				var switched: PackedStringArray = wired.switch_on_for(motor)
				if not switched.is_empty():
					power = wired.power_of(motor)
					said_power = " Switched on as Play would: %s." % "; ".join(switched)
			run = float(power["run"])
			if absf(run) < 1e-6:
				return "\n".join(PackedStringArray(["The %s (#%d) does not run: %s; nothing turns.%s" % [
					str((Simulation.MOTORS[simulation.motors[motor]] as Array)[0]), motor, str(power["why"]),
					said_power]]) + power_words(wired))
			chosen["how"] = "%s; its cable runs it %s at %d%%, %s" % [str(chosen["how"]),
				"forward" if run > 0.0 else "back", roundi(absf(run) * 100.0), str(power["words"])]
		else:
			chosen["how"] = "%s; it turns by hand: %s" % [str(chosen["how"]), str(power["why"])]
	job = Working.begin("Turning the mechanism…")
	await job.shown()
	simulation.drive(body)
	job.end()
	var how: String = str(chosen["how"]) + said_power.trim_suffix(".")
	if bool(simulation.solved.get("locked", false)) and how.begins_with("chosen"):
		how = "the app's pick; driver= picks another"
	var ref: int = _default_reference(simulation)
	var ref_asked: String = str(input.get("reference", "")).strip_edges()
	if not ref_asked.is_empty():
		ref = simulation.body_named(ref_asked)
		if ref < 0 or not simulation.rates.has(ref):
			return "No turning part called %s: reference= takes one of %s." % [ref_asked,
				", ".join(PackedStringArray(simulation.turning.map(func(b: int) -> String:
					return str(simulation.names[b]))))]
	var targets: Dictionary = input.get("targets", {}) if input.get("targets") is Dictionary else {}
	var lines := PackedStringArray()
	lines.append("Driven by %s (%s); the base is %s. %s." % [simulation.named_with_parts(body, 2),
		how, simulation.base_said, str(simulation.solved.get("said", ""))])
	if not simulation.moves_anything():
		lines.append("Nothing else turns from it.")
	else:
		lines.append("Against the base (sidereal):" if ref < 0
			else "Periods in %s, against the base (sidereal):" % simulation.unit_of(ref))
		for line: String in simulation.rate_lines(ref, targets, 16):
			lines.append("  " + line)
	lines.append_array(simulation.trouble_lines())
	lines.append_array(power_words(wired))
	# Where it stops: what meets, its range, a motor's stall.
	if not simulation.moving.is_empty():
		job = Working.begin("Checking where it stops…")
		await job.shown()
		await find_stops(simulation)
		job.end()
		lines.append_array(simulation.stop_lines())
	# The balance over the cycle, through the same weighing the panel uses,
	# drawn nowhere: the person's window is left as it was.
	var worst: float = 0.0
	if simulation.moves_anything() and shell != null:
		var cycle: Array = simulation.poses(simulation.cycle(), BALANCE_FRAMES)
		var report: Balance.Report = await shell.weigh_balance(cycle, false)
		if report != null and not report.empty:
			var out: Dictionary = simulation.furthest_out(report.support, cycle)
			lines.append(balance_words(simulation, report, out, cycle.size(), true))
			# What to do about it: the counterweight, and the joints most loaded.
			lines.append_array(PackedStringArray(report.said().split("\n")).slice(1))
			if report.worst_index >= 0 and report.worst_index < cycle.size():
				worst = float((cycle[report.worst_index] as Dictionary)["turns"])
	if bool(input.get("record", false)):
		lines.append(await _record_for_session(simulation, ref,
			clampi(int(input.get("frames", 24)), 2, 240), float(input.get("turns", 1.0)), work))
	var text: String = "\n".join(lines)
	if not StudioRender.possible():
		return text + "\n(No picture: this app is running without a window.)"
	# The picture where it stops, when something stops it; else at the worst
	# of the balance.
	var shown: float = worst
	var why: String = ""
	if simulation.stops_done and run < 0.0 and simulation.stop_back() != -INF:
		# Its cable runs it back: where it stops going back.
		shown = simulation.stop_back()
		why = ", where it stops going back"
	elif simulation.stops_done and run > 0.0 and simulation.stop_on() != INF:
		shown = simulation.stop_on()
		why = ", where it stops: %s" % simulation.stopped_said()
	job = Working.begin("Drawing the mechanism…")
	await job.shown()
	var image: Image = await picture(simulation, shown)
	job.end()
	if image == null:
		return text
	text += "\nThe picture: %s %s%s." % [simulation.names.get(body, "the driver"),
		Simulation.turned(shown) if why.is_empty() else "at " + Simulation.angle(shown), why]
	return [{"type": "text", "text": text}, {"type": "image", "source": {"type": "base64",
		"media_type": "image/png", "data": Marshalls.raw_to_base64(image.save_png_to_buffer())}}]


## simulate_mechanism's program=: [param words] made the model's program
## (one step of the history, as the program row's Run makes it; blanks take
## it out) and run as the row runs it, in one call: what it did move by move,
## where it stopped and why, and a picture where it ended. With Simulate open
## in the window, it plays there too. Words it cannot read set nothing.
func _program_for_session(simulation: Simulation, words: String) -> Variant:
	var program: HubProgram = HubProgram.parse(words)
	if not program.errors.is_empty():
		return ("The program was not set: %s\nIts words, a line each: to 90° at 50%% (to "
			+ "an angle from where it was built), turn -45° at 30%% (by an angle), run 40%% for "
			+ "2 s, wait 1 s, repeat 3 (the lines indented under it); with two motors or more "
			+ "each line begins with its port, A to F.") % "; ".join(program.errors)
	if shell != null and shell.read_only:
		return "This tab shows a model shared to look at: its program cannot be changed."
	var changed: bool = set_program(words)
	if program.is_empty():
		return ("The program is taken out of the model (undo puts it back)." if changed
			else "The model has no program to take out.")
	var kept: String = ("Set as the model's program (kept in its file; undo takes it back)"
		if changed else "The model's program already")
	var job: Working.Job = Working.begin("Running the program…")
	await job.shown()
	var made: Dictionary = await prepare_run(program, simulation, false)
	job.end()
	if made.has("refusal"):
		return "%s, but it cannot run: %s" % [kept, made["refusal"]]
	var ran: Dictionary = made["ran"]
	var ports: Dictionary = made["ports"]
	if not str(ran.get("refusal", "")).is_empty():
		return "%s, but it cannot run: %s" % [kept, ran["refusal"]]
	var lines := PackedStringArray()
	lines.append("%s, and run in Simulate at each motor's rated speed: %s" % [kept,
		HubProgram.ran_words(ran, ports)])
	var named := PackedStringArray()
	for port: String in made["sims"]:
		var motor: Dictionary = ports[port]
		named.append("%s (%s rpm with no load, %s N·cm stalled, at %s V)" % [
			HubProgram.port_said(port, motor), Simulation.figure(float(motor["rpm"])),
			Simulation.figure(float(motor["gives"])), Simulation.figure(float(motor["volts"]))])
	lines.append("On the hub's ports: %s." % "; ".join(named))
	lines.append_array(HubProgram.moves_words(ran, ports))
	# Played in the window too, when Simulate is open there.
	if visible and sim != null and not _recording and not _reading and not _driving:
		_ran = ran
		_ports = ports
		_port_sims = made["sims"]
		_port_curves = made["curves"]
		_stop()
		program_time = 0.0
		_program_began = Time.get_ticks_usec()
		running = true
		_program_posed = true
		_run.text = "Stop"
		lines.append("Simulate is open in the window, and plays it there.")
	var text: String = "\n".join(lines)
	if not StudioRender.possible():
		return text + "\n(No picture: this app is running without a window.)"
	var seconds: float = float(ran.get("seconds", 0.0))
	var first: Simulation = (made["sims"] as Dictionary).values()[0]
	job = Working.begin("Drawing the mechanism…")
	await job.shown()
	var image: Image = await picture(first, 0.0, SimulatePanel.program_pose(ran, made["sims"], seconds))
	job.end()
	if image == null:
		return text
	text += "\nThe picture: where the program %s, %s s in." % ["stopped" if not (ran.get("stopped",
		{}) as Dictionary).is_empty() else "ended", Simulation.figure(snappedf(seconds, 0.01))]
	return [{"type": "text", "text": text}, {"type": "image", "source": {"type": "base64",
		"media_type": "image/png", "data": Marshalls.raw_to_base64(image.save_png_to_buffer())}}]


## The driver a session asks for, or the one the model marks, or the one
## that turns most: {body, how}, or {refusal} saying what to give instead.
## The model's cables for a session, the switches as Simulate has them, or
## with [param power] "on" every battery box, receiver lever, pole reverser
## and hub on (its ports at full speed), "off" every one off.
func session_wiring(power: String, simulation: Simulation = null) -> Wiring:
	var out: Wiring = Wiring.read(world.bricks(), simulation.motors if simulation != null
		else Simulation.motors_in(world.bricks(), library))
	if wiring != null and _wiring_generation == world.generation():
		for key: Variant in wiring.settings:
			out.settings[key] = wiring.settings[key]
	power = power.strip_edges().to_lower()
	if power == "on" or power == "off":
		out.set_all(power)
	return out


## What a session is told of the cables: each motor's, and the switches.
static func power_words(wired: Wiring) -> PackedStringArray:
	var out := PackedStringArray()
	if wired == null or wired.motors.is_empty():
		return out
	if not wired.has_power():
		out.append("Power: nothing here gives a motor power (no battery box, IR receiver or hub), "
			+ "so Play turns a motor by hand. A motor runs by its cable once there is one: "
			+ "lay_flex kind=pf_cable, pu_cable or 9v_wire lays one from the motor to the box or hub.")
		return out
	# Ten of each at most, and the rest counted: an answer is read whole.
	var switches: PackedStringArray = wired.switch_lines()
	var said: String = "; ".join(switches.slice(0, 10))
	if switches.size() > 10:
		said += "; and %d more" % (switches.size() - 10)
	out.append("Power (a motor whose cable is drawn runs only when it reaches a box, receiver or "
		+ "hub that is on, the way its plugs face, and stops when its cable is pulled; one with no "
		+ "cable drawn turns by hand; power not given switches the driver's on where it is off, as "
		+ "Play does; power=on switches every one on, power=off every one off): " + said + ".")
	var lines: PackedStringArray = wired.motor_lines()
	for line: String in lines.slice(0, 10):
		out.append("  " + line)
	if lines.size() > 10:
		out.append("  And %d more motors." % (lines.size() - 10))
	return out


static func _session_driver(simulation: Simulation, asked: String) -> Dictionary:
	asked = asked.strip_edges()
	if not asked.is_empty():
		var body: int = simulation.body_named(asked)
		if body < 0:
			return {"refusal": ("No part or sub-assembly %s here. driver= takes a part's number "
				+ "(look_at_model) or a sub-assembly's name.") % asked}
		# A motor's number is its output, which is what it drives: its case
		# is the base it stands in. APP_UX9's y6 session gave the SPIKE
		# motor's number, was told the motor "is the base", and read the arm
		# pinned into the hub as held by the case (mcpreach2).
		var motor: int = int(asked.strip_edges().trim_prefix("#")) \
			if asked.strip_edges().trim_prefix("#").is_valid_int() else -1
		if simulation.motors.has(motor):
			var turned: int = simulation.model.output_body(motor)
			if turned >= 0:
				return {"body": turned, "how": "the output of motor #%d, as asked" % motor}
			return {"refusal": ("#%d is a motor (%s), whose case is part of %s: nothing is keyed or "
				+ "pinned into its output, so it turns nothing. attachment_points brick=%d names "
				+ "the output's axle hole and pin holes; a part in one of them turns with it.") % [
				motor, (Simulation.MOTORS[simulation.motors[motor]] as Array)[0], simulation.named_with_parts(body, 2), motor]}
		if not simulation.can_drive(body):
			return {"refusal": ("%s does not turn on anything: it is %s. Give driver= an axle or "
				+ "a crank that turns in a hole.") % [simulation.named_with_parts(body, 2),
				"the base" if body == simulation.model.ground else "floating"]}
		return {"body": body, "how": "as asked"}
	var marked: int = simulation.marked()
	if marked >= 0:
		return {"body": marked, "how": "its motor turns it" if simulation.motored.has(marked)
			else "the model marks it"}
	var best: int = simulation.best()
	if best >= 0:
		return {"body": best, "how": "chosen as the one that turns most of the train; driver= "
			+ "picks another"}
	var nothing := PackedStringArray(["Nothing here turns on an axle, a pin or a turntable "
		+ "(%s)." % simulation.model.summary()])
	nothing.append_array(simulation.trouble_lines())
	return {"refusal": "\n".join(nothing)}


## A recording for a session, drawn to its end: the call is a job
## (ToolJobs), so the session asks job how far it has got rather than
## waiting on it, and the job's Cancel stops it as the window's does.
func _record_for_session(simulation: Simulation, of: int, frames: int, turns_of: float,
		work: Working.Job = null) -> String:
	if not StudioRender.possible():
		return "No recording: this app is running without a window (godot --path . -- --mcp)."
	if _recording:
		var going: Working.Job = Working.current()
		return "Still recording the last one (%s); ask again when it is done." % (
			going.line() if going != null else "")
	var span: float = simulation.turns_for(of) * maxf(turns_of, 0.01)
	var unit: String = simulation.unit_of(of) if of >= 0 else "turns of %s" % simulation.names.get(
		simulation.driver, "the driver")
	var what: String = "%s %s in %d frames" % [Simulation.figure(maxf(turns_of, 0.01)), unit, frames]
	await record_of(simulation, of, frames, turns_of, "hero", work)
	return _recorded_words(what, span)


func _recorded_words(what: String, span: float) -> String:
	if not _last.has("paths"):
		return "Recording: %s" % str(_last.get("said", "nothing was kept"))
	return "Recorded %d frames of %s (%s turns of the driver) in %.0f s: %s." % [
		int(_last["frames"]), what, Simulation.figure(span), float(_last["seconds"]),
		str(_last["said"])]


# -- building --------------------------------------------------------------------------


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.95)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 11
	backing.content_margin_bottom = 12
	add_theme_stylebox_override("panel", backing)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.text = "Simulate mechanism"
	_title.add_theme_font_size_override("font_size", 14)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_close = _button(header, "Close", close, "Back to building (Escape)")
	_driver = _words(column, 12, 1.0)
	_reference = OptionButton.new()
	_reference.accessibility_name = "Measure periods against"
	_reference.add_theme_font_size_override("font_size", 12)
	_reference.focus_mode = Control.FOCUS_NONE
	_reference.item_selected.connect(func(index: int) -> void:
		if _quiet:
			return
		reference = int(_reference_bodies[index]) if index < _reference_bodies.size() else -1
		_show_readout())
	column.add_child(_reference)
	_readout = _words(column, 12, 0.92)
	_trouble = _words(column, 12, 1.0)
	_trouble.add_theme_color_override("font_color", Color(1.0, 0.72, 0.55))
	_stops = _words(column, 12, 1.0)
	_stops.add_theme_color_override("font_color", Color(1.0, 0.72, 0.55))
	var legend := _words(column, 11, 0.6)
	legend.text = ("Tinted by speed, blue slow to orange fast; the driver white; red, the meshes "
		+ "that lock it or the parts that meet; amber, free; violet, floating. The model itself "
		+ "does not move.")
	var rule := HSeparator.new()
	column.add_child(rule)
	var playing := HBoxContainer.new()
	playing.add_theme_constant_override("separation", 6)
	column.add_child(playing)
	_play = _button(playing, "Play", play, "Turn the driver at the speed chosen (Escape closes)")
	_speed = OptionButton.new()
	_speed.accessibility_name = "Speed"
	_speed.add_theme_font_size_override("font_size", 12)
	_speed.focus_mode = Control.FOCUS_NONE
	for each: float in SPEEDS:
		_speed.add_item("%s turn%s a second" % [Simulation.figure(each), "" if each == 1.0 else "s"])
	_speed.select(SPEEDS.find(speed))
	_speed.item_selected.connect(func(index: int) -> void: speed = float(SPEEDS[index]))
	playing.add_child(_speed)
	_worst = _button(playing, "Worst balance", go_to_worst,
		"Go to the frame of the cycle where it comes nearest tipping")
	_where = _button(playing, "Go to the stop", go_to_stop,
		"Go to where it stops: two parts meet, its motor stalls or its loop goes no further")
	_where.disabled = true
	_scrub = HSlider.new()
	_scrub.accessibility_name = "Where in the cycle"
	_scrub.focus_mode = Control.FOCUS_NONE
	_scrub.custom_minimum_size = Vector2(300, 18)
	# A track to see, as Pose's sliders have.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.16)
	track.set_corner_radius_all(2)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	_scrub.add_theme_stylebox_override("slider", track)
	_scrub.value_changed.connect(func(value: float) -> void:
		if not _quiet:
			scrub_to(value))
	column.add_child(_scrub)
	_at = _words(column, 11, 0.7)
	_build_power(column)
	_build_program(column)
	_weighed = _words(column, 12, 0.92)
	var recording := HBoxContainer.new()
	recording.add_theme_constant_override("separation", 6)
	column.add_child(recording)
	_record = _button(recording, "Record", func() -> void: record(),
		"Draw a turn of the reference (or of the driver) and keep it: an animated WebP, and on "
			+ "the desktop the frames and an MP4")
	_frames = OptionButton.new()
	_frames.accessibility_name = "Frames"
	_frames.add_theme_font_size_override("font_size", 12)
	_frames.focus_mode = Control.FOCUS_NONE
	for count: int in FRAME_CHOICES:
		_frames.add_item("%d frames" % count)
	recording.add_child(_frames)
	_frame = TextureRect.new()
	_frame.custom_minimum_size = Vector2(300, 120)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_frame.visible = false
	column.add_child(_frame)
	_status = _words(column, 11, 0.8)
	_drive_rows.assign([_reference, legend, rule, playing, _scrub, _at, _program_rows, _weighed,
		recording])
	if Phone.on():
		_for_a_finger(column, playing)


## Laid out for a finger (the phone's layout or a tablet's), Play and the
## cycle's slider come first, under the title, as a phone's player keeps its
## controls at the top of its sheet: under the driver, the readout and the
## legend they sat four swipes down a phone's sheet, 9 taps to play against
## the desktop's 2, 4 to scrub against 1 (phonewalk, APP_UX8 phonepanels).
## What it reads follows them. The desktop keeps its order to the pixel.
func _for_a_finger(column: VBoxContainer, playing: Control) -> void:
	column.move_child(playing, 1)
	column.move_child(_scrub, 2)
	column.move_child(_at, 3)
	# The program next, under the player (hubprogram): Run a fingertip tall
	# beside its title, the box four lines of 14-point type the sheet's
	# width, written with the phone's own keyboard.
	column.move_child(_program_rows, 4)
	_run.custom_minimum_size = Vector2(Phone.px(get_viewport(), Phone.TARGET) * 1.6,
		Phone.px(get_viewport(), Phone.TARGET))
	_program_box.add_theme_font_size_override("font_size", 14)
	_program_box.custom_minimum_size = Vector2(0, 4 * 22 + 12)
	# What a run says under Run, above the box: below it, Stop's words were
	# under the sheet's fold (hpreview F7).
	_program_rows.move_child(_program_said, 1)


## What the program row says, in the panel's view on a phone once Run or
## Stop is pressed or the run ends: the sheet scrolls no further than it.
func _said_into_view() -> void:
	if _program_said == null or not Phone.on() or not is_inside_tree():
		return
	var scroll: Node = _program_said.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	if scroll != null:
		LaidOut.into_view(scroll as ScrollContainer, _program_said)


## The box, tapped where it shows at the panel's foot on a phone, whole in
## the panel's view to be written in, once the finger is off the glass: a
## list moved under a finger still down is thrown on as if the finger had
## moved it (FlingScroll), 328 units for the 62 it needed.
func _program_into_view() -> void:
	var scroll: Node = _program_box.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	if scroll == null:
		return
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_inside_tree():
		await get_tree().process_frame
	if is_instance_valid(scroll) and _program_box.has_focus():
		LaidOut.into_view(scroll as ScrollContainer, _program_box)


## The power row: a title, a button for each switch and each dial (shown
## for a model that holds a battery box, a receiver or a hub), and each
## motor said with its cable.
func _build_power(column: VBoxContainer) -> void:
	_power_rows = VBoxContainer.new()
	_power_rows.add_theme_constant_override("separation", 4)
	_power_rows.visible = false
	column.add_child(_power_rows)
	var title := _words(_power_rows, 12, 1.0)
	title.text = "Power: click a battery box, receiver or hub to work its switch"
	_power_buttons = HFlowContainer.new()
	_power_buttons.add_theme_constant_override("h_separation", 6)
	_power_buttons.add_theme_constant_override("v_separation", 4)
	_power_rows.add_child(_power_buttons)
	_power_said = _words(_power_rows, 11, 0.85)


## The power row as the switches now are.
func _show_power() -> void:
	if _power_rows == null:
		return
	_power_rows.visible = wiring != null and (wiring.has_power() or not wiring.motors.is_empty())
	for child: Node in _power_buttons.get_children():
		child.queue_free()
	if wiring == null:
		_power_said.text = ""
		return
	for brick: int in wiring.sources:
		var spec: Dictionary = Wiring.SOURCES[wiring.sources[brick]]
		match str(spec["kind"]):
			"box", "reverser", "hub":
				var said: String = _switch_words(brick, 0)
				_button(_power_buttons, said, work_switch.bind(brick, 0), "Work its switch, as a finger "
					+ "moves it on the part")
				if str(spec["kind"]) == "hub":
					var contacts: Array = Wiring.CONTACTS.get(Wiring.SAME.get(Wiring.base_part(str(
						wiring.parts[brick])), Wiring.base_part(str(wiring.parts[brick]))), [])
					for port: int in contacts.size():
						_dial(brick, port, Wiring.PORT_SPEEDS, tr("port %d") % (port + 1))
			"receiver":
				for output: int in 2:
					_button(_power_buttons, _switch_words(brick, output), work_switch.bind(brick, output),
						"Work its remote's lever for this output")
					_dial(brick, output, [1.0, 0.75, 0.5, 0.25], tr("%s speed") % tr(str((spec["outputs"] as Array)[output]), &"power"))
	var lines: PackedStringArray = wiring.motor_lines()
	if not wiring.has_power() and not wiring.motors.is_empty():
		lines.append(tr("Nothing here gives a motor power, so Play turns it by hand: add a battery box "
			+ "or a hub and lay its cable (Make, Cable, hose or chain…, Power Functions cable)."))
	_power_said.text = "\n".join(lines)


## A switch said for its button: "Battery box #12: off".
func _switch_words(brick: int, output: int) -> String:
	var spec: Dictionary = Wiring.SOURCES[wiring.sources[brick]]
	var short: String = str(spec["label"]).replace("Power Functions ", "")
	short = short.left(1).to_upper() + short.substr(1)
	match str(spec["kind"]):
		"box":
			return "%s #%d: %s" % [tr(short), brick, tr(str(((spec["switch"] as Array)[wiring.switch_index(brick)]
				as Array)[0]), &"power")]
		"receiver":
			return tr("%s #%d, %s output: %s") % [tr(short), brick, tr(str((spec["outputs"] as Array)[output]), &"power"),
				tr(str((Wiring.LEVER[wiring.lever_index(brick, output)] as Array)[0]), &"power")]
		"reverser":
			return "%s #%d: %s" % [tr(short), brick, tr(str((Wiring.LEVER[wiring.lever_index(brick, 0)]
				as Array)[0]), &"power")]
	return "%s #%d: %s" % [tr(short), brick, tr("on", &"power") if bool(wiring.settings.get(brick, false)) else tr("off", &"power")]


## A dial for a receiver's output (its speed remote's) or a hub's port,
## [param words] already in the person's language.
func _dial(brick: int, output: int, shares: Array, words: String) -> void:
	var dial := OptionButton.new()
	dial.accessibility_name = words
	dial.add_theme_font_size_override("font_size", 12)
	dial.focus_mode = Control.FOCUS_NONE
	var hub: bool = str(Wiring.SOURCES[wiring.sources[brick]]["kind"]) == "hub"
	var now: float = wiring.port_speed(brick, output) if hub else wiring.dial_of(brick, output)
	for share: float in shares:
		dial.add_item("%s %d%%" % [words, roundi(share * 100.0)])
	var at: int = 0
	for n: int in shares.size():
		if absf(float(shares[n]) - now) < 1e-3:
			at = n
	dial.select(at)
	dial.item_selected.connect(func(index: int) -> void:
		if hub:
			wiring.set_to(brick, str(shares[index]), output)
		else:
			wiring.set_dial(brick, float(shares[index]), output)
		_after_power())
	_power_buttons.add_child(dial)


## Work [param brick]'s switch (a receiver's [param output] lever): said,
## and each motor run or stopped as its cable now gives it power.
func work_switch(brick: int, output: int = 0) -> void:
	if wiring == null:
		return
	var said: String = wiring.work(brick, output)
	_after_power()
	if not said.is_empty():
		_status.text = said.left(1).to_upper() + said.substr(1) + ". " + _status.text


## After a switch or a dial: the row shown, and the motor its cable runs
## driven and played; the driver's motor stopped when its power is gone.
func _after_power() -> void:
	_show_power()
	if sim == null:
		return
	var running: int = _running_body()
	if running < 0:
		if playing and _power_rate != 0.0:
			_stop()
		var power: Dictionary = driver_power()
		if not power.is_empty():
			_status.text = tr("%s does not run: %s.") % [_motor_said(int(sim.motored[sim.driver])),
				str(power["why"])]
		return
	if running != sim.driver:
		if _driving:
			_wanted = running
			return
		await drive(running, "its cable's box is on")
	if sim != null and sim.driver == running:
		_stop()
		play()


## The program row: its title and Run, the box its words are written in, and
## what it says (the motors on the hub's ports, where a run is, what it did).
func _build_program(column: VBoxContainer) -> void:
	_program_rows = VBoxContainer.new()
	_program_rows.add_theme_constant_override("separation", 4)
	column.add_child(_program_rows)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	_program_rows.add_child(head)
	# Its words on the title, in the person's language; the box holds the
	# program, read in its own words whatever the language, so it and its
	# example are never translated.
	var title := Label.new()
	title.text = "Program"
	title.tooltip_text = ("A line each: to 90° at 50% (to an angle from where it was built), "
		+ "turn -45° at 30% (by an angle), run 40% for 2 s, wait 1 s, repeat 3 (the lines "
		+ "indented under it). With two motors or more, each line begins with its port, A to F.")
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	title.add_theme_font_size_override("font_size", 12)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_run = _button(head, "Run", run_program,
		"Run the program for the motors at each one's rated speed (it is kept with the model)")
	_program_box = TextEdit.new()
	_program_box.accessibility_name = "Program for the motors"
	_program_box.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_program_box.placeholder_text = "repeat 3\n  to 90° at 50%\n  wait 1 s\n  to 0° at 50%"
	_program_box.add_theme_font_size_override("font_size", 12)
	_program_box.custom_minimum_size = Vector2(320, 4 * 18 + 10)
	_program_box.text_changed.connect(_typed)
	_program_box.focus_exited.connect(_left_box)
	_program_box.focus_entered.connect(_program_into_view)
	_program_rows.add_child(_program_box)
	_program_said = _words(_program_rows, 11, 0.8)


func _words(into: Control, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(320, 0)
	label.modulate = Color(1, 1, 1, alpha)
	into.add_child(label)
	return label


func _button(into: Control, words: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	into.add_child(button)
	return button


# -- for a probe and a browser test ----------------------------------------------------------


## What the panel says, for a probe: the driver line, the readout, what is
## wrong, the balance.
func said() -> Dictionary:
	return {"driver": _driver.text, "readout": _readout.text, "trouble": _trouble.text,
		"stops": _stops.text, "balance": _weighed.text, "status": _status.text, "at": _at.text,
		"program": _program_said.text}


func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	return {"simulate_play": _play, "simulate_speed": _speed, "simulate_scrub": _scrub,
		"simulate_worst": _worst, "simulate_stop": _where, "simulate_reference": _reference,
		"simulate_record": _record,
		"simulate_frames": _frames, "simulate_close": _close,
		"simulate_program": _program_box, "simulate_run": _run}


## What the panel is doing, for a browser test: window.brickworksSimulate.
## Web builds only.
func _tell_page() -> void:
	if not OS.has_feature("web"):
		return
	var now: int = Time.get_ticks_msec()
	if now - _told_page_at < 500:
		return
	_told_page_at = now
	var state: Dictionary = {"open": visible, "playing": playing, "recording": _recording,
		"turns": snappedf(turns, 0.001), "driver": _driver.text, "readout": _readout.text,
		"trouble": _trouble.text, "stops": _stops.text, "balance": _weighed.text,
		"status": _status.text, "running": running, "program": _program_said.text}
	for key: String in _last:
		state[key] = _last[key]
	var text: String = JSON.stringify(state)
	if text == _told_page:
		return
	_told_page = text
	JavaScriptBridge.eval("window.brickworksSimulate = %s" % text, true)
