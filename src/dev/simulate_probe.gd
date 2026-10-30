## Tools, Simulate mechanism in the real scene, as a person uses it (phase
## P1b of docs/MECHANISMS.md, with P1c's period readout).
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1600x900x24" godot --path . \
##     --resolution 1600x900 --script src/dev/simulate_probe.gd
##   ... and at 3200x1800, the same layout at 2x
##   ... -- --write    also writes the two fixtures to src/dev/fixtures/
##
## Two models, built here part by part on the baseplate (a session cannot
## yet seat an axle in a hole over MCP):
##   - an 8 driving a 24 on two axles in a Technic plate, with a 16 free on
##     the 8's axle and an 8 lying loose: the driver is clicked, played,
##     scrubbed and recorded, the 24 turning a third as fast the other way in
##     every frame the renderer draws; then two 16s meshed as well lock it,
##     and the panel names the meshes that fight;
##   - mechanism_probe's two-planet orrery, standing on two pillars: Earth's
##     arm on the central axle, Mars's on a turntable round it, both from one
##     crank axle three studs off (28:20 below, 20:28 above), its frame named
##     Frame, which holds it still. The crank is marked by its
##     sub-assembly's name; Mars's year reads 1.96 Earth years against
##     1.8808, +4.2%, the balance is weighed over the cycle and the arm
##     furthest out named, and a recording's frames turn Earth 1.4 and Mars
##     20/28 of the crank's step.
## Simulating never changes the model: every part stands where it was built,
## the undo history is as deep, and the model's revision has not moved.
## Pictures and the recordings in shots/simulate/.
extends SceneTree

const SHOTS := "res://shots/simulate"
const FIXTURES := "res://src/dev/fixtures"
## Mars goes round once for every 1.8808 of Earth's (NASA's sidereal
## periods, 686.98 and 365.256 days).
const MARS_YEARS := 686.980 / 365.256

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
var _floor_top: float = 0.0


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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	if not StudioRender.possible():
		print("simulate: needs a window (xvfb-run); nothing checked")
		quit(1)
		return
	await _gear_train()
	await _orrery()
	print("")
	if _failures == 0:
		print("simulate: a driver clicked, played, scrubbed and recorded, every frame's turn the "
			+ "tooth counts', a locked train named, Mars's year in Earth years against NASA's, "
			+ "the balance over the cycle, and the model never moved")
	else:
		print("simulate: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- an 8 driving a 24 ------------------------------------------------------------------


func _gear_train() -> void:
	print("  an 8 driving a 24, a 16 free on the 8's axle, an 8 lying loose")
	_main.call("clear_model")
	await _frames(10)
	_floor_top = _top_of_floor()
	var t: float = _floor_top
	_flat("3709b", Vector3(0, t + 8, 0), 71)
	var axle_a: int = _upright("3705", Vector3(-20, t + 0.5, 0), 0)
	var axle_b: int = _upright("3705", Vector3(20, t + 0.5, 0), 0)
	var small: int = _gear("3647", Vector3(-20, t + 24, 0), 14)
	var large: int = _gear("3648a", Vector3(20, t + 24, 0), 72)
	var idle: int = _gear("6542b", Vector3(-20, t + 64, 0), 4)
	var loose: int = _gear("3647", Vector3(70, t + 22, 40), 14)
	await _frames(5)
	_camera.frame(AABB(Vector3(-90, t, -60), Vector3(200, 100, 140)), 1.2)
	await _frames(20)
	var rest: Dictionary = _rest()
	var depth: int = _builder.history_depth()
	var revision: int = _world.revision

	# By its name: Make came in before Tools (keys3), and the fifth menu was
	# Make's from then.
	var tools: Array = []
	for menu: Array in Shell.MENUS:
		if menu[0] == "Tools":
			tools = menu[1]
	_check("Tools has Simulate mechanism", _shell.can("simulate") and "simulate" in tools)
	# The parts column open, as a person building by hand has it.
	var bin: SideDock = _main.get("_bin_dock")
	bin.set_open(true, false)
	await _frames(10)
	_shell.run("simulate")
	await _frames(1)
	_check("...and the Working line is up while it reads and turns the mechanism (%s)" % (
		Working.current().words if Working.current() != null else "nothing"), Working.is_busy())
	await _settled()
	_check("the panel is open with the mechanism read", _panel.visible and _panel.sim != null)
	# Docked beside the model, not over it: the parts column folded for it,
	# and every part of the train on screen inside the model's column.
	var model_rect: Rect2 = _main.call("_model_rect")
	var inside: bool = true
	for id: int in [axle_a, axle_b, small, large, idle]:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		var box: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		for n: int in 8:
			var corner: Vector3 = box.position + box.size * Vector3(n & 1, (n >> 1) & 1, (n >> 2) & 1)
			inside = inside and model_rect.has_point(_camera.unproject_position(corner))
	_check("the panel is docked beside the model (%s), the parts column folded for it, and the "
		% str(_panel.get_global_rect()) + "whole train on screen in the model's column (%s)"
		% str(model_rect), not _panel.get_global_rect().intersects(model_rect)
		and not bin.is_open() and inside)
	var sim: Simulation = _panel.sim
	var a: int = sim.model.body_of(axle_a)
	var b: int = sim.model.body_of(axle_b)
	print("    %s" % sim.model.summary())
	print("    driver: %s" % _panel.said()["driver"])

	# A click on the 24 drives its axle, and a click on the 8's axle that.
	await _click(_clickable_point([large, axle_b]))
	await _settled()
	sim = _panel.sim
	_check("a click on the 24 makes its axle the driver, the 8 then turning 3 the other way "
		+ "(%s)" % _panel.said()["driver"], sim.driver == b
		and absf(float(sim.rates.get(a, 0.0)) + 3.0) < 1e-5
		and str(_panel.said()["driver"]).contains("clicked"))
	await _click(_clickable_point([axle_a, small]))
	await _settled()
	sim = _panel.sim
	_check("a click on the 8's axle makes it the driver (%s)" % _panel.said()["driver"],
		sim.driver == a and str(_panel.said()["driver"]).contains("#%d" % small))
	var ratio: float = float(sim.rates.get(b, 0.0))
	_check("the 24 turns a third of the 8's turn, the other way (%.6f)" % ratio,
		absf(ratio + 1.0 / 3.0) < 1e-5)
	var readout: String = _panel.said()["readout"]
	print("    readout: %s" % readout.replace("\n", " | "))
	_check("...and the panel says so", readout.contains("0.3333 turns for each turn of")
		and readout.contains("the other way"))
	var trouble: String = _panel.said()["trouble"]
	print("    trouble: %s" % trouble.replace("\n", " | "))
	_check("the 16 on a round hole is named free, by its number", trouble.contains("Free")
		and trouble.contains("#%d" % idle))
	_check("the 8 lying loose is named floating, by its number", trouble.contains("Floating")
		and trouble.contains("#%d" % loose))
	var tints: Dictionary = _world.tinted_ids()
	_check("the turning parts are tinted, the 24 slower than the 8's axle, the loose 8 violet",
		tints.has(large) and tints.has(axle_a) and tints.get(loose) == Simulation.FLOATING
		and tints.get(idle) == Simulation.FREE and tints.get(axle_a) == Simulation.DRIVER)
	await _shot("1_train")

	# Played: the picture turns, the model does not.
	var play: Button = _panel.controls_by_name()["simulate_play"]
	await _click(play.get_global_rect().get_center())
	var seen: Array = []
	for _n: int in 40:
		await process_frame
		seen.append([_turned(axle_a), _turned(axle_b)])
	_check("Play turns the driver (%.3f turns in)" % _panel.turns, _panel.playing
		and _panel.turns > 0.05)
	var worst: float = 0.0
	var steps: int = 0
	for n: int in range(1, seen.size()):
		var one: float = wrapf(float(seen[n][0]) - float(seen[n - 1][0]), -180.0, 180.0)
		var other: float = wrapf(float(seen[n][1]) - float(seen[n - 1][1]), -180.0, 180.0)
		if absf(one) > 0.01:
			steps += 1
			worst = maxf(worst, absf(other + one / 3.0))
	_check("in every frame played the 24 turns a third of the 8's step back (%d frames, to %.4f°)"
		% [steps, worst], steps > 10 and worst < 0.01)
	await _shot("2_playing")
	await _click(play.get_global_rect().get_center())
	_check("...and Play again pauses it", not _panel.playing)
	_check("while it played the model stood still: every part where it was built",
		_same_as(rest) and _world.revision == revision and _builder.history_depth() == depth)

	# Scrubbed to a quarter of the cycle.
	var scrub: HSlider = _panel.controls_by_name()["simulate_scrub"]
	scrub.value = scrub.max_value * 0.25
	await _frames(3)
	var wanted: Dictionary = sim.placed(scrub.max_value * 0.25)
	var off: float = 0.0
	for key: int in wanted:
		off = maxf(off, (_world.drawn_at(_world.get_brick(key)).origin
			- (wanted[key] as Transform3D).origin).length())
	_check("the slider puts every turning part where a quarter of the cycle does (%.4f)" % off,
		absf(_panel.turns - scrub.max_value * 0.25) < 1e-4 and off < 0.01)

	# Recorded, read back off the renderer frame by frame.
	_panel.folder = ProjectSettings.globalize_path(SHOTS.path_join("train"))
	DirAccess.make_dir_recursive_absolute(_panel.folder)
	var angles: Array = []
	var reading := func(_n: int, _image: Image) -> void:
		var renderer: StudioRender = _panel.renderer
		angles.append([_about(renderer.staged_transform(axle_a).basis
			* (_world.get_brick(axle_a).transform.basis).inverse()),
			_about(renderer.staged_transform(large).basis
			* (_world.get_brick(large).transform.basis).inverse())])
	_panel.frame_drawn.connect(reading)
	var record: Button = _panel.controls_by_name()["simulate_record"]
	await _click(record.get_global_rect().get_center())
	await _frames(2)
	_check("Record shows the Working line while it draws (%s)" % (
		Working.current().words if Working.current() != null else "nothing"),
		Working.is_busy() and _panel.is_recording())
	await _recorded()
	_panel.frame_drawn.disconnect(reading)
	var last: Dictionary = _panel.last_recording()
	print("    recording: %s frames in %.1f s: %s" % [str(last.get("frames", 0)),
		float(last.get("seconds", 0.0)), str(last.get("said", ""))])
	_check("every frame recorded (%d of 24)" % int(last.get("frames", 0)),
		int(last.get("frames", 0)) == 24 and angles.size() == 24)
	worst = 0.0
	for n: int in range(1, angles.size()):
		var one: float = wrapf(float(angles[n][0]) - float(angles[n - 1][0]), -180.0, 180.0)
		var other: float = wrapf(float(angles[n][1]) - float(angles[n - 1][1]), -180.0, 180.0)
		worst = maxf(worst, absf(other + one / 3.0))
	_check("in every frame drawn the 24 turns a third of the 8's 15° step back, to %.4f°" % worst,
		angles.size() == 24 and worst < 0.01)
	_check("...kept as a WebP%s" % (" and an MP4" if not RenderOutput.ffmpeg().is_empty() else ""),
		_written(last, ".webp") and (RenderOutput.ffmpeg().is_empty() or _written(last, ".mp4")))
	_check("recording changed nothing either", _same_as(rest) and _world.revision == revision
		and _builder.history_depth() == depth)

	# Two 16s meshed as well: locked, and the meshes that fight named.
	print("  the same two axles also joined 16 to 16")
	var sixteen_a: int = _gear("94925", Vector3(-20, t + 44, 0), 1)
	var sixteen_b: int = _gear("94925", Vector3(20, t + 44, 0), 1)
	await _frames(3)
	await _settled()
	trouble = _panel.said()["trouble"]
	print("    trouble: %s" % trouble.replace("\n", " | "))
	_check("the panel reads the model again and says it is locked", trouble.contains("LOCKED"))
	_check("...naming the 16s and the 8 and 24 as the meshes that fight",
		trouble.contains("#%d" % sixteen_a) and trouble.contains("#%d" % sixteen_b)
		and trouble.contains("#%d" % small) and trouble.contains("#%d" % large))
	tints = _world.tinted_ids()
	_check("...and tints them red", tints.get(sixteen_a) == Simulation.LOCKED
		and tints.get(large) == Simulation.LOCKED)
	await _shot("3_locked")
	if "--write" in OS.get_cmdline_user_args():
		_main.call("save_model", ProjectSettings.globalize_path(FIXTURES.path_join(
			"gears_locked.ldr")))
	_panel.close()
	await _frames(3)
	_check("closing puts every part's picture back and the tints away, and the parts column "
		+ "as it was", _world.drawn_ids().is_empty() and _world.tinted_ids().is_empty()
		and (_main.get("_bin_dock") as SideDock).is_open())


# -- a two-planet orrery ---------------------------------------------------------------------


func _orrery() -> void:
	print("  a two-planet orrery: Earth on the central axle, Mars on a turntable, one crank")
	_main.call("clear_model")
	await _frames(10)
	var t: float = _top_of_floor()
	# mechanism_probe's orrery, on two pillars. The frame is a beam lying flat,
	# its holes up, and the turntable's base on it, held to it in the real
	# thing by what the parts do not record: named Frame, so the simulation
	# holds them still, as a person or a session names a base that is not
	# stud by stud on the baseplate.
	for z: float in [-120.0, 120.0]:
		var top: float = t
		for _n: int in 3:
			_flat("3003", Vector3(0, top + 24, z), 71)
			top += 24.0
		_flat("3068b", Vector3(0, top + 8, z), 71)
	var h: float = t + 90.0
	_flat("32278", Vector3(0, h, 0), 71, "Frame")
	_flat("99009", Vector3(0, h + 39, 0), 72, "Frame")
	# The central axle carries Earth: a 20 below the beam, Earth's arm and the
	# Sun on top.
	var centre: int = _along_y("3707", Vector3(0, h + 40, 0), 71, "Earth")
	_gear("32269", Vector3(0, h - 20, 0), 72, "Earth")
	var earth_arm: int = _flat("6632", Vector3(0, h + 80, 0), 1, "Earth")
	_along_y("3704", Vector3(0, h + 100, -40), 0, "Earth")
	var earth: int = _flat("3941", Vector3(0, h + 114, -40), 1, "Earth")
	_flat("3941", Vector3(0, h + 118, 0), 14, "Sun")
	# The crank's axle, three studs off: a 28 meshing the 20 below, a 20 the
	# turntable's 28 above. It stops short of Mars's arm, which sweeps over it.
	var crank: int = _along_y("3706", Vector3(0, h - 11, 60), 71, "Crank")
	var crank_low: int = _gear("46372", Vector3(0, h - 20, 60), 72, "Crank")
	var crank_high: int = _gear("32269", Vector3(0, h + 39, 60), 72, "Crank")
	# Mars's arm: the turntable's top, a beam pinned across it.
	var mars_gear: int = _flat("99010", Vector3(0, h + 39, 0), 72, "Mars arm")
	var across := Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
	var mars_arm: int = _place("32524", Transform3D(across, Vector3(0, h + 59, 30)), 4, "Mars arm")
	var along_z := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	_place("2780", Transform3D(along_z, Vector3(20, h + 59, 20)), 0, "Mars arm")
	_place("2780", Transform3D(along_z, Vector3(-20, h + 59, 20)), 0, "Mars arm")
	await _frames(5)
	_camera.frame(AABB(Vector3(-120, t, -150), Vector3(240, 230, 300)), 1.1)
	await _frames(20)
	var rest: Dictionary = _rest()
	var depth: int = _builder.history_depth()
	var revision: int = _world.revision
	if "--write" in OS.get_cmdline_user_args():
		_main.call("save_model", ProjectSettings.globalize_path(FIXTURES.path_join(
			"orrery_two_planets.ldr")))
		revision = _world.revision
		depth = _builder.history_depth()

	_shell.run("simulate")
	await _settled()
	var sim: Simulation = _panel.sim
	print("    %s" % sim.model.summary())
	print("    driver: %s" % _panel.said()["driver"])
	var turning_crank: int = sim.model.body_of(crank)
	_check("the crank is the driver, as its sub-assembly's name marks it",
		sim.driver == turning_crank and str(_panel.said()["driver"]).begins_with("Driver: Crank"))
	await _click(_clickable_point([crank, crank_low, crank_high]))
	await _settled()
	sim = _panel.sim
	_check("...and clicking the crank's axle keeps it so", sim.driver == turning_crank)
	var earth_body: int = sim.model.body_of(earth_arm)
	var mars_body: int = sim.model.body_of(mars_arm)
	_check("Earth rides its arm, Mars's arm the turntable's top (%s; %s)" % [sim.names.get(earth_body, "?"),
		sim.names.get(mars_body, "?")], sim.model.body_of(earth) == earth_body
		and sim.model.body_of(mars_gear) == mars_body and sim.model.body_of(centre) == earth_body)
	var earth_rate: float = float(sim.rates.get(earth_body, 0.0))
	var mars_rate: float = float(sim.rates.get(mars_body, 0.0))
	_check("Earth turns 28/20 = 1.4 times the crank, the other way (%.6f)" % earth_rate,
		absf(earth_rate + 1.4) < 1e-5)
	_check("Mars turns 20/28 of the crank, the other way: round the Sun as Earth goes (%.6f)"
		% mars_rate, absf(mars_rate + 20.0 / 28.0) < 1e-5)
	var readout: String = _panel.said()["readout"]
	print("    readout: %s" % readout.replace("\n", " | "))
	_check("the periods are in Earth years, Earth named as the reference",
		_panel.reference == earth_body)
	var years: float = sim.period_in(mars_body, earth_body)
	_check("Mars's year is %.4f Earth years against %.4f, said with the error: \"Mars arm: 1.96 "
		% [years, MARS_YEARS] + "Earth years; real 1.8808, +4.2%\"", absf(years - 1.96) < 1e-5
		and readout.contains("Mars arm: 1.96 Earth years; real 1.8808, +4.2%"))
	var weighed: String = _panel.said()["balance"]
	print("    balance: %s" % weighed)
	_check("the balance is weighed over the cycle and the arm furthest out named",
		_panel.balance != null and not _panel.balance.empty
		and _panel.weighed_poses.size() == SimulatePanel.BALANCE_FRAMES
		and weighed.begins_with("Balance over 72 frames of the cycle")
		and weighed.contains("Furthest out: Mars arm"))
	_check("...the support polygon and the centre of mass drawn on the floor",
		_shell._balance_mark != null and _shell._balance_mark.visible)
	var worst_button: Button = _panel.controls_by_name()["simulate_worst"]
	await _click(worst_button.get_global_rect().get_center())
	var worst_turns: float = float((_panel.weighed_poses[_panel.balance.worst_index]
		as Dictionary)["turns"])
	_check("Worst balance goes to the frame where it comes nearest tipping (%s)" % _panel.said()["at"],
		absf(_panel.turns - worst_turns) < 1e-6)
	await _shot("4_orrery_worst")

	_panel.folder = ProjectSettings.globalize_path(SHOTS.path_join("orrery"))
	DirAccess.make_dir_recursive_absolute(_panel.folder)
	var angles: Array = []
	var reading := func(_n: int, _image: Image) -> void:
		var renderer: StudioRender = _panel.renderer
		var row: Array = []
		for key: int in [crank, earth_arm, mars_arm]:
			row.append(_about(renderer.staged_transform(key).basis
				* (_world.get_brick(key).transform.basis).inverse()))
		angles.append(row)
	_panel.frame_drawn.connect(reading)
	await _panel.record(24)
	_panel.frame_drawn.disconnect(reading)
	var last: Dictionary = _panel.last_recording()
	print("    recording: %s frames in %.1f s: %s" % [str(last.get("frames", 0)),
		float(last.get("seconds", 0.0)), str(last.get("said", ""))])
	var steps: Array = [1.4, 20.0 / 28.0]
	var worst: Array = [0.0, 0.0]
	for n: int in range(1, angles.size()):
		var turn: float = wrapf(float(angles[n][0]) - float(angles[n - 1][0]), -180.0, 180.0)
		for w: int in 2:
			var step: float = wrapf(float(angles[n][w + 1]) - float(angles[n - 1][w + 1]), -180.0,
				180.0)
			worst[w] = maxf(float(worst[w]), absf(step + turn * float(steps[w])))
	_check("a recording of one Earth year: in every frame drawn Earth turns 1.4 of the crank's "
		+ "step and Mars 20/28 (to %.4f° and %.4f°)" % [worst[0], worst[1]],
		angles.size() == 24 and float(worst[0]) < 0.01 and float(worst[1]) < 0.01)
	_check("...one Earth year is %s crank turns" % Simulation.figure(float(last.get("turns", 0.0))),
		absf(float(last.get("turns", 0.0)) - 1.0 / 1.4) < 1e-6)
	_check("...kept as a WebP%s" % (" and an MP4" if not RenderOutput.ffmpeg().is_empty() else ""),
		_written(last, ".webp") and (RenderOutput.ffmpeg().is_empty() or _written(last, ".mp4")))
	_check("and the orrery itself never moved: every part where it was built, the undo history "
		+ "as deep", _same_as(rest) and _world.revision == revision
		and _builder.history_depth() == depth)

	# The same over MCP, as a session asks it.
	var tools: AppTools = AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var answer: Variant = await tools.run("simulate_mechanism", {})
	var text: String = str((answer as Array)[0]["text"]) if answer is Array else str(answer)
	if answer is Array:
		var shot := Image.new()
		shot.load_png_from_buffer(Marshalls.base64_to_raw(str(((answer as Array)[1]
			as Dictionary)["source"]["data"])))
		shot.save_png(ProjectSettings.globalize_path(SHOTS.path_join("5_session_picture.png")))
		print("    picture: shots/simulate/5_session_picture.png")
	print("    simulate_mechanism: %s" % text.replace("\n", " | "))
	_check("simulate_mechanism says the driver, the periods against NASA's and the balance, "
		+ "with a picture", answer is Array and text.contains("Driven by Crank")
		and text.contains("Mars arm: 1.96 Earth years; real 1.8808, +4.2%")
		and text.contains("Balance over 72 frames") and str((answer as Array)[1]["type"]) == "image")
	_check("...and leaves the model as it was", _same_as(rest) and _world.revision == revision)
	_panel.close()
	await _frames(3)


# -- building -----------------------------------------------------------------------------


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


## An axle or a pin standing up: its length (its longest side) along y, the
## middle of its footprint at x and z of [param foot], its bottom at foot.y.
func _upright(part_id: String, foot: Vector3, colour: int, unit: String = "") -> int:
	var bounds: AABB = _library.mesh_for(part_id).bounds
	var basis := Basis.IDENTITY
	var longest: int = 0
	for n: int in 3:
		if bounds.size[n] > bounds.size[longest]:
			longest = n
	if longest == 0:
		basis = Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	elif longest == 2:
		basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	var box: AABB = (Transform3D(basis, Vector3.ZERO) * bounds).abs()
	var middle: Vector3 = box.get_center()
	return _place(part_id, Transform3D(basis, Vector3(foot.x - middle.x, foot.y - box.position.y,
		foot.z - middle.z)), colour, unit)


## An axle standing up, its origin (its middle) at [param at], as
## mechanism_probe stands one.
func _along_y(part_id: String, at: Vector3, colour: int, unit: String = "") -> int:
	return _place(part_id, Transform3D(Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0),
		Vector3(0, 0, 1)), at), colour, unit)


## A gear lying flat, its axis up, its middle at [param at].
func _gear(part_id: String, at: Vector3, colour: int, unit: String = "") -> int:
	var spec: Dictionary = Mechanism.spec_of(part_id)
	var basis := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	if str(spec.get("axis", "z")) == "y":
		basis = Basis.IDENTITY
	return _place(part_id, Transform3D(basis, at), colour, unit)


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


# -- reading back -----------------------------------------------------------------------------


## How far a part is drawn turned about the upright from where it stands, degrees.
func _turned(key: int) -> float:
	var brick: BrickWorld.Brick = _world.get_brick(key)
	return _about(_world.drawn_at(brick).basis * brick.transform.basis.inverse())


## How far a rotation turns about the upright, degrees.
static func _about(turn: Basis) -> float:
	var across := Vector3.RIGHT
	var turned: Vector3 = turn * across
	return rad_to_deg(atan2(Vector3.UP.dot(across.cross(turned)), across.dot(turned)))


static func _written(last: Dictionary, ending: String) -> bool:
	for path: Variant in last.get("paths", []):
		if str(path).ends_with(ending) and FileAccess.file_exists(str(path)) \
				and FileAccess.get_file_as_bytes(str(path)).size() > 1000:
			return true
	return false


# -- driving the window ---------------------------------------------------------------------


## Wait for the panel to finish reading, driving and weighing.
func _settled() -> void:
	for _n: int in 900:
		await process_frame
		if not Working.is_busy() and _panel.sim != null and not _panel._reading \
				and not _panel._driving:
			break
	# The panel's column opening (or closing) moves the lens over to the
	# model's new middle: a click aimed before it arrives lands beside the part.
	for _n: int in 600:
		var aim: Vector2 = _camera.seen_rect().get_center() - _camera._room() * 0.5
		if _camera._shift.distance_to(aim) < 0.5:
			break
		await process_frame
	await _frames(5)


func _recorded() -> void:
	for _n: int in 20000:
		await process_frame
		if not _panel.is_recording():
			break
	await _frames(5)


## A point on screen where a click lands on one of [param ids] (the parts
## of one body: an axle and the gears keyed to it), clear of the panels.
func _clickable_point(ids: Array) -> Vector2:
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		var box: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		for share: Vector3 in [Vector3(0.5, 0.95, 0.5), Vector3(0.5, 0.9, 0.5),
				Vector3(0.5, 0.8, 0.5), Vector3(0.5, 0.7, 0.5), Vector3(0.5, 0.6, 0.5),
				Vector3(0.5, 0.5, 0.5), Vector3(0.5, 0.4, 0.5), Vector3(0.5, 0.3, 0.5),
				Vector3(0.2, 0.9, 0.5), Vector3(0.8, 0.9, 0.5), Vector3(0.5, 0.9, 0.2),
				Vector3(0.5, 0.9, 0.8)]:
			var at: Vector2 = _camera.unproject_position(box.position + box.size * share)
			if root.get_visible_rect().grow(-4.0).has_point(at) \
					and not _main.call("_over_panel_at", at) \
					and not _panel.get_global_rect().has_point(at) and _verbs.brick_at(at) in ids:
				return at
	print("    (no point of %s is clear to click)" % str(ids))
	var first: BrickWorld.Brick = _world.get_brick(int(ids[0]))
	return _camera.unproject_position((first.transform
		* _library.mesh_for(first.part_id).bounds).abs().get_center())


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
	var path: String = SHOTS.path_join("%s.png" % name)
	image.save_png(ProjectSettings.globalize_path(path))
	print("    picture: %s" % path.trim_prefix("res://"))
