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
## The balance is weighed over the cycle (Balance, through Shell's
## weigh_balance, which draws the support polygon and the centre of mass on
## the floor), and the arm that reaches furthest past the base's edge named.
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
## How long a session's call may wait for a recording before it is told
## the app goes on with it.
const SESSION_WAIT_MS := 20000

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
var _close: Button
var _status: Label
var _frame: TextureRect
var _quiet: bool = false
var _reading: bool = false
var _driving: bool = false
var _recording: bool = false
var _seen_revision: int = -1
var _last: Dictionary = {}
var _told_page: String = ""
var _told_page_at: int = 0


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
	await read()


func close() -> void:
	if renderer != null and renderer.is_busy():
		renderer.cancel()
	_stop()
	visible = false
	if world != null:
		world.set_drawn({})
		world.set_tinted({})
	if shell != null and shell._balance_mark != null:
		shell._balance_mark.clear()
	sim = null


func read() -> void:
	if _reading or world == null:
		return
	_reading = true
	_stop()
	world.set_drawn({})
	_status.text = ""
	_frame.visible = false
	var job: Working.Job = Working.begin("Reading the mechanism…")
	await job.shown()
	sim = await read_mechanism()
	_seen_revision = world.revision
	var body: int = sim.marked()
	var how: String = "the model marks it"
	if body < 0:
		body = _selected_body()
		how = "selected"
	if body < 0:
		body = sim.best()
		how = "it turns the most"
	job.end()
	_reading = false
	if body < 0:
		_driver.text = "Nothing here turns on an axle, a pin or a turntable."
		_readout.text = ("Build a gear train: gears on axles through Technic holes, meshing at "
			+ "their pitch, and click the axle a crank or a motor turns.")
		_trouble.text = "\n".join(sim.trouble_lines())
		_fill_references()
		return
	await drive(body, how)


## The mechanism as the model stands, read on a worker for a big model so
## the window keeps drawing (the Working bar is up meanwhile).
func read_mechanism() -> Simulation:
	var bricks: Array = world.bricks()
	if bricks.size() < READ_OFF_THREAD_FROM or OS.has_feature("nothreads"):
		return Simulation.read(bricks, library, scenery)
	var still: BrickWorld = world.copy_for_reading()
	var standing: Array = still.bricks()
	# Every mesh it reads, loaded here first: a reader may not load one.
	for brick: BrickWorld.Brick in standing:
		library.mesh_for(brick.part_id)
	var made: Array = [null]
	library.begin_reading()
	var task: int = WorkerThreadPool.add_task(func() -> void:
		made[0] = Simulation.read(standing, library, scenery), false, "read the mechanism")
	library.reading_in(task)
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	library.end_reading(task)
	still.free()
	return made[0]


const READ_OFF_THREAD_FROM := 600


## The body most of the selection is in that turns on a joint, or -1.
func _selected_body() -> int:
	if builder == null or sim == null:
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
	_driving = false
	if sim == null:
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
	if sim == null or sim.turning.is_empty() or shell == null:
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
	if playing:
		_stop()
		return
	if sim == null or sim.turning.is_empty():
		_status.text = "Nothing turns from this driver."
		return
	playing = true
	_play.text = "Pause"


func _stop() -> void:
	playing = false
	if _play != null:
		_play.text = "Play"


## Turn the driver to [param at] turns from where it was built, and show it.
func scrub_to(at: float) -> void:
	_stop()
	turns = maxf(at, 0.0)
	_show_pose()


## The worst frame of the balance.
func go_to_worst() -> void:
	if balance == null or balance.worst_index < 0 or balance.worst_index >= weighed_poses.size():
		return
	scrub_to(float((weighed_poses[balance.worst_index] as Dictionary)["turns"]))


func _show_pose() -> void:
	if sim == null or world == null:
		return
	world.set_drawn(sim.placed(turns))
	var span: float = sim.cycle()
	_quiet = true
	_scrub.set_value_no_signal(fmod(turns, span) if span > 0.0 else 0.0)
	_quiet = false
	_at.text = "%s %s" % [sim.names.get(sim.driver, "the driver"), Simulation.turned(turns)]


func _process(delta: float) -> void:
	if not visible:
		return
	# Something else changed the model: an edit, an undo. What turns is read
	# again from the model as it now is.
	if not _reading and not _driving and not _recording and world != null \
			and world.revision != _seen_revision:
		_seen_revision = world.revision
		read()
		return
	if playing and sim != null:
		turns += speed * delta
		_show_pose()
	_tell_page()


## A click on a part while the panel is open: drive its body, when it turns.
func _on_selection(_count: int) -> void:
	if not visible or sim == null or _reading or _driving or _quiet:
		return
	var body: int = _selected_body()
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
		else:
			close()
		get_viewport().set_input_as_handled()


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
func record_of(simulation: Simulation, of: int, frames: int, turns_of: float = 1.0,
		view: String = "") -> int:
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
	var job: Working.Job = Working.begin("Recording the mechanism…", frames, true)
	job.cancel_wanted.connect(func() -> void:
		if renderer != null:
			renderer.cancel())
	await job.shown()
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
	var lines := PackedStringArray()
	if done == frames:
		job.say("Putting the frames together…")
		lines = await output.finish_turntable()
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
func picture(simulation: Simulation, at: float) -> Image:
	if not StudioRender.possible() or _recording:
		return null
	_renderer()
	if renderer.is_busy():
		return null
	var chosen: RenderSettings = settings.copy()
	chosen.size = Vector2i(720, 450)
	chosen.view = "hero"
	var pose: Dictionary = simulation.placed(at)
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
## and leaves the panel as the person left it. A String, or text and a
## picture. Each slow step is on the Working bar, as the panel's are.
func for_session(input: Dictionary) -> Variant:
	if world == null:
		return "This app cannot simulate from outside."
	var job: Working.Job = Working.begin("Reading the mechanism…")
	await job.shown()
	var simulation: Simulation = await read_mechanism()
	var chosen: Dictionary = _session_driver(simulation, str(input.get("driver", "")))
	job.end()
	if chosen.has("refusal"):
		return str(chosen["refusal"])
	var body: int = chosen["body"]
	job = Working.begin("Turning the mechanism…")
	await job.shown()
	simulation.drive(body)
	job.end()
	var how: String = str(chosen["how"])
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
	var earlier: String = _session_recording_words()
	if not earlier.is_empty():
		lines.append(earlier)
	lines.append("Driven by %s (%s); the base is %s. %s." % [simulation.named_with_parts(body, 2),
		how, simulation.base_said, str(simulation.solved.get("said", ""))])
	if simulation.turning.is_empty():
		lines.append("Nothing else turns from it.")
	else:
		lines.append("Against the base (sidereal):" if ref < 0
			else "Periods in %s, against the base (sidereal):" % simulation.unit_of(ref))
		for line: String in simulation.rate_lines(ref, targets, 16):
			lines.append("  " + line)
	lines.append_array(simulation.trouble_lines())
	# The balance over the cycle, through the same weighing the panel uses,
	# drawn nowhere: the person's window is left as it was.
	var worst: float = 0.0
	if not simulation.turning.is_empty() and shell != null:
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
			clampi(int(input.get("frames", 24)), 2, 240), float(input.get("turns", 1.0))))
	var text: String = "\n".join(lines)
	if not StudioRender.possible():
		return text + "\n(No picture: this app is running without a window.)"
	job = Working.begin("Drawing the mechanism…")
	await job.shown()
	var image: Image = await picture(simulation, worst)
	job.end()
	if image == null:
		return text
	text += "\nThe picture: %s %s." % [simulation.names.get(body, "the driver"),
		Simulation.turned(worst)]
	return [{"type": "text", "text": text}, {"type": "image", "source": {"type": "base64",
		"media_type": "image/png", "data": Marshalls.raw_to_base64(image.save_png_to_buffer())}}]


## The driver a session asks for, or the one the model marks, or the one
## that turns most: {body, how}, or {refusal} saying what to give instead.
static func _session_driver(simulation: Simulation, asked: String) -> Dictionary:
	asked = asked.strip_edges()
	if not asked.is_empty():
		var body: int = simulation.body_named(asked)
		if body < 0:
			return {"refusal": ("No part or sub-assembly %s here. driver= takes a part's number "
				+ "(look_at_model) or a sub-assembly's name.") % asked}
		if not simulation.can_drive(body):
			return {"refusal": ("%s does not turn on anything: it is %s. Give driver= an axle or "
				+ "a crank that turns in a hole.") % [simulation.named_with_parts(body, 2),
				"the base" if body == simulation.model.ground else "floating"]}
		return {"body": body, "how": "as asked"}
	var marked: int = simulation.marked()
	if marked >= 0:
		return {"body": marked, "how": "the model marks it"}
	var best: int = simulation.best()
	if best >= 0:
		return {"body": best, "how": "chosen as the one that turns most of the train; driver= "
			+ "picks another"}
	var nothing := PackedStringArray(["Nothing here turns on an axle, a pin or a turntable "
		+ "(%s)." % simulation.model.summary()])
	nothing.append_array(simulation.trouble_lines())
	return {"refusal": "\n".join(nothing)}


## A recording for a session: waited for up to SESSION_WAIT_MS, then left
## going in the app (the Working bar shows it, and its Cancel stops it), with
## where its files will be; the next call says when it is done.
func _record_for_session(simulation: Simulation, of: int, frames: int, turns_of: float) -> String:
	if not StudioRender.possible():
		return "No recording: this app is running without a window (godot --path . -- --mcp)."
	if _recording:
		var going: Working.Job = Working.current()
		return "Still recording the last one (%s); ask again when it is done." % (
			going.line() if going != null else "")
	var finished: Array = [false]
	var span: float = simulation.turns_for(of) * maxf(turns_of, 0.01)
	var going_on := func() -> void:
		await record_of(simulation, of, frames, turns_of, "hero")
		finished[0] = true
	_session_recording = true
	going_on.call()
	var began: int = Time.get_ticks_msec()
	while not finished[0] and Time.get_ticks_msec() - began < SESSION_WAIT_MS:
		await get_tree().process_frame
	var unit: String = simulation.unit_of(of) if of >= 0 else "turns of %s" % simulation.names.get(
		simulation.driver, "the driver")
	var what: String = "%s %s in %d frames" % [Simulation.figure(maxf(turns_of, 0.01)), unit, frames]
	if not finished[0]:
		var job: Working.Job = Working.current()
		var output := RenderOutput.new()
		output.folder = folder
		var webp: String = output.where().path_join(RenderOutput.file_name(str(named.call()),
			"_mechanism", "webp"))
		return ("Recording %s: still drawing after %d s (%s), so it goes on in the app and is "
			+ "written to %s, with an MP4 beside it. The next simulate_mechanism call says when "
			+ "it is done.") % [what, SESSION_WAIT_MS / 1000, job.line() if job != null else "",
			webp]
	_session_recording = false
	return _recorded_words(what, span)


## A session's recording that went on past its call: done, or still going.
var _session_recording: bool = false


## What became of a session's recording left going, for the next call; "".
func _session_recording_words() -> String:
	if not _session_recording:
		return ""
	if _recording:
		var job: Working.Job = Working.current()
		return "The recording asked for earlier is still being drawn (%s)." % (
			job.line() if job != null else "")
	_session_recording = false
	return "The recording asked for earlier is done: " + _recorded_words("it",
		float(_last.get("turns", 0.0)))


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
	var legend := _words(column, 11, 0.6)
	legend.text = ("Tinted by speed, blue slow to orange fast; the driver white; red, the meshes "
		+ "that lock it; amber, free; violet, floating. The model itself does not move.")
	column.add_child(HSeparator.new())
	var playing := HBoxContainer.new()
	playing.add_theme_constant_override("separation", 6)
	column.add_child(playing)
	_play = _button(playing, "Play", play, "Turn the driver at the speed chosen (Escape closes)")
	_speed = OptionButton.new()
	_speed.add_theme_font_size_override("font_size", 12)
	_speed.focus_mode = Control.FOCUS_NONE
	for each: float in SPEEDS:
		_speed.add_item("%s turn%s a second" % [Simulation.figure(each), "" if each == 1.0 else "s"])
	_speed.select(SPEEDS.find(speed))
	_speed.item_selected.connect(func(index: int) -> void: speed = float(SPEEDS[index]))
	playing.add_child(_speed)
	_worst = _button(playing, "Worst balance", go_to_worst,
		"Go to the frame of the cycle where it comes nearest tipping")
	_scrub = HSlider.new()
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
	_weighed = _words(column, 12, 0.92)
	var recording := HBoxContainer.new()
	recording.add_theme_constant_override("separation", 6)
	column.add_child(recording)
	_record = _button(recording, "Record", func() -> void: record(),
		"Draw a turn of the reference (or of the driver) and keep it: an animated WebP, and on "
			+ "the desktop the frames and an MP4")
	_frames = OptionButton.new()
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
		"balance": _weighed.text, "status": _status.text, "at": _at.text}


func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	return {"simulate_play": _play, "simulate_speed": _speed, "simulate_scrub": _scrub,
		"simulate_worst": _worst, "simulate_reference": _reference, "simulate_record": _record,
		"simulate_frames": _frames, "simulate_close": _close}


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
		"trouble": _trouble.text, "balance": _weighed.text, "status": _status.text}
	for key: String in _last:
		state[key] = _last[key]
	var text: String = JSON.stringify(state)
	if text == _told_page:
		return
	_told_page = text
	JavaScriptBridge.eval("window.brickworksSimulate = %s" % text, true)
