## Motors run by their cables (docs/APP_UX11.md, wires).
##
##   godot --headless --path . --script src/dev/wires_probe.gd
##   godot --headless --path . --script src/dev/wires_probe.gd -- --sets=LISTING --rows=ROWS
##   godot --headless --path . --script src/dev/wires_probe.gd -- --only=hand   (1. alone)
##
## With nothing given:
##   1. Wiring read off parts placed by hand: a Power Functions L motor's
##      cable (a sub-model, as LDCad writes one) ending in its plug on a
##      battery box: the box off, nothing runs; forward, it runs forward; the
##      plug turned half round, back; a quarter round, no contact; lifted off,
##      not wired. A receiver with its own cable on the box and the motor on
##      its red output (its lever, the box's switch); a pole reverser; a
##      Control+ hub's port; an extension wire between.
##   2. In the app: a box and an M motor placed, and a Power Functions cable
##      laid from the motor's outlet to the box by lay_flex (MCP, as a
##      session lays one): its plug on the box, the cable 500 LDU (its real
##      20 cm), one undo; read by Wiring as the motor's cable; saved, opened
##      again and saved: the file byte for byte, the cable's sub-model the
##      same and still the motor's cable; simulate_mechanism power=on says the
##      motor runs; undo takes the cable away and the motor is not wired.
##   3. 42042's L motor through Simulate as a person drives it: the box
##      clicked on (its switch, worked on the part), the motor plays at 390
##      rpm and turns its train; the plug pulled off the box, it stops and
##      says why; undone, it runs again. And 42042's file saved untouched:
##      each LDCad cable path in it byte for byte.
##   4. The wiring read, and where a cable's ends may go, each under 16 ms
##      (the best of five) on Orthanc and on 42042.
##
## With --sets, each set of LISTING (tools/wires_sets.py) opened as File,
## Open opens it: each motor's cable read as its booklet wires it, the boxes
## (and receivers' levers, hubs' ports) switched on, each function whose
## control turns with a running motor's output measured as KINEFUNCS
## measures it (kinefuncs_probe: the driver turned 1.5 radians the way the
## motor runs, every part in moves moving, none in stays), and the motor's
## plug pulled off: the motor stops. One JSON row a motor in ROWS.
extends SceneTree

const MODELS := "user://wires_probe/"
const SET_42042 := "/mnt/Projects/brickworks/bench/data/kinebrick/omr/42042-1 Crawler Crane.mpd"
const REACH := 1.5
const MOVED := 1.0
const NEAR := 1.5
const WATCHDOG := 5400.0

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _panel: SimulatePanel
var _socket: CommandSocket
var _rpc_id: int = 0
var _cells: Dictionary = {}
var _rows: FileAccess = null


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	var listing: String = ""
	var rows: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sets="):
			listing = arg.trim_prefix("--sets=")
		elif arg.begins_with("--rows="):
			rows = arg.trim_prefix("--rows=")
	# Seventeen sets opened one after another take hours on a loaded box.
	var limit: float = WATCHDOG * (3.0 if not listing.is_empty() else 1.0)
	create_timer(limit).timeout.connect(func() -> void:
		print("wires_probe: FAILED, not finished in %d s" % int(limit))
		quit(1))
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	if listing.is_empty():
		print("\n1. wiring read off parts placed by hand")
		_by_hand()
	if only == "hand":
		print("\nwires_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
		quit(1 if _failures else 0)
		return
	await _start()
	if listing.is_empty():
		print("\n2. a Power Functions cable laid from a motor to a box")
		await _laid()
		print("\n3. 42042's L motor in Simulate: the box switched on, the plug pulled")
		await _simulate_42042()
		print("\n4. time: the wiring read on Orthanc and on 42042, inside a frame")
		await _timed()
	else:
		await _sets(listing, rows)
	print("\nwires_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


func _start() -> void:
	Account.where = "user://wires_probe_session.json"
	Account._clear()
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_panel = _main.get("_simulate")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var account: Account = _main.get("_account")
	while account.state == Account.State.CHECKING:
		await account.changed
	account.email = "wires-probe@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	await _frames(20)
	DirAccess.make_dir_recursive_absolute(MODELS)


# -- 1. by hand ---------------------------------------------------------------------------


static func _motor_of(part: String) -> String:
	return Simulation.motor_of(null, part)


## A brick placed by hand, in [param unit] ("" for none).
static func _brick(id: int, part: String, at: Transform3D, unit: String = "") -> BrickWorld.Brick:
	var brick := BrickWorld.Brick.new(id, part, 0, at)
	if not unit.is_empty():
		brick.unit = unit
		brick.group = Assemblies.group_of(unit)
	return brick


## Where a plug goes on [param part]'s contacts [param index] placed at
## [param at], turned [param turn] degrees about the contacts' up, lifted
## [param lift] LDU more.
static func _plug_on(part: String, at: Transform3D, index: int, turn: float = 0.0, lift: float = 0.0) -> Transform3D:
	var row: Array = (Wiring.CONTACTS[Wiring.SAME.get(part, part)] as Array)[index]
	var holder := BrickWorld.Brick.new(0, part, 0, at)
	var frame: Array = Wiring._frame(holder, row)
	var up: Vector3 = frame[2]
	var x: Vector3 = (frame[1] as Vector3).rotated(up, deg_to_rad(turn))
	var raise: float = (Wiring.PLUG_UP if str(row[0]) == "pf" else 0.0) + lift
	return Transform3D(Basis(x, up, x.cross(up)), (frame[0] as Vector3) + up * raise)


## Where [param part], whose own plug [param index] is to stand at
## [param plug], stands.
static func _part_for_own_plug(part: String, plug: Transform3D, index: int = 0) -> Transform3D:
	var row: Array = (Wiring.OWN_PLUGS[part] as Array)[index]
	var local := BrickWorld.Brick.new(0, part, 0, Transform3D.IDENTITY)
	var frame: Array = Wiring._frame(local, row)
	var x: Vector3 = frame[1]
	var up: Vector3 = frame[2]
	var own := Transform3D(Basis(x, up, x.cross(up)), frame[0])
	return plug * own.affine_inverse()


func _by_hand() -> void:
	var box_at := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	var motor_at := Transform3D(Basis.IDENTITY, Vector3(200, 0, 0))
	var cases: Array = [[0.0, 0.0, "forward"], [180.0, 0.0, "back"], [90.0, 0.0, "quarter"],
		[0.0, 8.0, "lifted"]]
	for case: Array in cases:
		var bricks: Array = [_brick(1, "58119", box_at), _brick(2, "99499", motor_at, "cable#1"),
			_brick(3, "58124c01", _plug_on("58119", box_at, 0, float(case[0]), float(case[1])), "cable#1"),
			_brick(4, "3005", Transform3D(Basis.IDENTITY, Vector3(0, 100, 0)), "cable#1")]
		var wired: Wiring = Wiring.read(bricks, _motor_of)
		var off: Dictionary = wired.power_of(2)
		match str(case[2]):
			"forward", "back":
				var sign: float = 1.0 if case[2] == "forward" else -1.0
				_check("the plug %s on the box: wired %s, the box off and still (%s)" % [
					"facing" if sign > 0.0 else "turned half round", str(off["words"]), str(off["why"])],
					bool(off["wired"]) and float(off["run"]) == 0.0 and str(off["why"]).contains("is off"))
				wired.work(1)
				var on: Dictionary = wired.power_of(2)
				_check("the box's switch worked once (forward): it runs %s" % ("forward" if sign > 0.0
					else "back"), is_equal_approx(float(on["run"]), sign))
				wired.work(1)
				_check("worked again (back): it runs the other way", is_equal_approx(
					float(wired.power_of(2)["run"]), -sign))
				wired.work(1)
				_check("worked again: off, and still", float(wired.power_of(2)["run"]) == 0.0)
			"quarter":
				wired.set_to(1, "forward")
				var quarter: Dictionary = wired.power_of(2)
				_check("the plug a quarter round: no contact, said (%s)" % str(quarter["why"]),
					not bool(quarter["wired"]) and str(quarter["why"]).contains("quarter turn"))
			"lifted":
				wired.set_to(1, "forward")
				var lifted: Dictionary = wired.power_of(2)
				_check("the plug lifted off the box: not wired, its plug on nothing (%s)" % str(lifted["why"]),
					not bool(lifted["wired"]) and str(lifted["why"]).contains("on nothing")
					and float(lifted["run"]) == 0.0)
	# A motor with no cable in the model.
	var bare: Wiring = Wiring.read([_brick(1, "58119", box_at), _brick(2, "58120", motor_at)], _motor_of)
	bare.set_to(1, "forward")
	_check("a motor with no cable: not wired, said (%s)" % str(bare.power_of(2)["why"]),
		not bool(bare.power_of(2)["wired"]) and str(bare.power_of(2)["why"]).contains("no cable"))
	# The receiver: its own cable's plug on the box, the motor on its red output.
	var receiver_at: Transform3D = _part_for_own_plug("58123c01", _plug_on("58119", box_at, 0))
	var bricks: Array = [_brick(1, "58119", box_at), _brick(5, "58123c01", receiver_at),
		_brick(2, "58120c01", _part_for_own_plug("58120c01", _plug_on("58123c01", receiver_at, 0)))]
	var through: Wiring = Wiring.read(bricks, _motor_of)
	through.set_to(1, "forward")
	_check("on the receiver's red output, its lever off: still (%s)" % str(through.power_of(2)["why"]),
		bool(through.power_of(2)["wired"]) and float(through.power_of(2)["run"]) == 0.0
		and str(through.power_of(2)["why"]).contains("red output"))
	through.work(5, 1)
	_check("the blue lever worked: the red output's motor still still", float(through.power_of(2)["run"]) == 0.0)
	through.work(5, 0)
	_check("the red lever forward: it runs (%s)" % str(through.power_of(2)["words"]),
		is_equal_approx(float(through.power_of(2)["run"]), 1.0)
		and str(through.power_of(2)["words"]).contains("receiver"))
	through.set_dial(5, 0.5, 0)
	_check("the red output's speed dial at 50%: it runs at half", is_equal_approx(
		float(through.power_of(2)["run"]), 0.5))
	through.set_to(1, "back")
	_check("the box switched back: a receiver runs its outputs the same", is_equal_approx(
		float(through.power_of(2)["run"]), 0.5))
	through.set_to(1, "off")
	_check("the box off: the receiver has no power, the motor stops (%s)" % str(through.power_of(2)["why"]),
		float(through.power_of(2)["run"]) == 0.0 and str(through.power_of(2)["why"]).contains("off"))
	# The pole reverser between: its lever passes the box's way on, or turns it.
	var reverser_at: Transform3D = _part_for_own_plug("61929c01", _plug_on("58119", box_at, 0))
	var flipped: Wiring = Wiring.read([_brick(1, "58119", box_at), _brick(6, "61929c01", reverser_at),
		_brick(2, "58121c01", _part_for_own_plug("58121c01", _plug_on("61929c01", reverser_at, 0)))], _motor_of)
	flipped.set_to(1, "forward")
	_check("through a pole reverser, its lever off: still", float(flipped.power_of(2)["run"]) == 0.0)
	flipped.set_to(6, "forward")
	var once: float = float(flipped.power_of(2)["run"])
	flipped.set_to(6, "back")
	_check("its lever forward runs the motor, back runs it the other way (%s, %s)" % [once,
		float(flipped.power_of(2)["run"])], is_equal_approx(once, 1.0)
		and is_equal_approx(float(flipped.power_of(2)["run"]), -1.0))
	# A Control+ hub: the L motor's own plug in its third port.
	var hub_at := Transform3D(Basis.IDENTITY, Vector3(0, 0, 400))
	var plug_in: Transform3D = _plug_on("22127", hub_at, 2)
	var hub: Wiring = Wiring.read([_brick(7, "22127", hub_at),
		_brick(2, "22169c01", _part_for_own_plug("22169c01", plug_in))], _motor_of)
	_check("in a Control+ hub's port 3, the hub off: still (%s)" % str(hub.power_of(2)["why"]),
		bool(hub.power_of(2)["wired"]) and float(hub.power_of(2)["run"]) == 0.0)
	hub.set_to(7, "-0.5", 2)
	_check("its port at -50%%: it runs back at half (%s)" % str(hub.power_of(2)["words"]),
		is_equal_approx(float(hub.power_of(2)["run"]), -0.5) and str(hub.power_of(2)["words"]).contains("port 3"))
	# An extension wire between: the motor's plug on the wire's plug, the
	# wire's other plug on the box.
	var near_plug: Transform3D = _plug_on("58119", box_at, 0)
	var wire_at: Transform3D = _part_for_own_plug("60656", near_plug, 1)
	var wire_brick: BrickWorld.Brick = _brick(8, "60656", wire_at)
	var far: Array = Wiring._frame(wire_brick, (Wiring.OWN_PLUGS["60656"] as Array)[0])
	var far_up: Vector3 = far[2]
	var on_far := Transform3D(Basis(far[1], far_up, (far[1] as Vector3).cross(far_up)),
		(far[0] as Vector3) + far_up * Wiring.PLUG_UP)
	var extended: Wiring = Wiring.read([_brick(1, "58119", box_at), wire_brick,
		_brick(2, "58120c01", _part_for_own_plug("58120c01", on_far))], _motor_of)
	extended.set_to(1, "forward")
	_check("through an extension wire: it runs (%s)" % str(extended.power_of(2)["words"]),
		is_equal_approx(absf(float(extended.power_of(2)["run"])), 1.0))


# -- 2. a cable laid ----------------------------------------------------------------------


func _laid() -> void:
	_main.call("clear_model")
	await _frames(5)
	var box: int = _place("58119", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 0)
	var motor: int = _place("58120", Transform3D(Basis.IDENTITY, Vector3(120, 0, 160)), 71)
	_builder.forget_history()
	await _frames(5)
	var depth: int = _builder.history_depth()
	var said: String = await _say("lay_flex", {"kind": "pf_cable", "from": {"brick": motor},
		"to": {"brick": box}})
	print("    lay_flex: %s" % said)
	_check("laid one item, one step to undo", said.begins_with("Laid") and _builder.history_depth() == depth + 1)
	var plug: int = -1
	var pieces: int = 0
	var item: String = ""
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "58124c01":
			plug = brick.id
			item = Assemblies.path_of(brick)
		elif brick.part_id == "343":
			pieces += 1
	var length: float = Flex.item_length("pf_cable", _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return b.part_id == "343").map(func(b: BrickWorld.Brick) -> Dictionary:
			return {"part": b.part_id, "at": b.transform}))
	_check("its plug and %d pieces of cable in one sub-assembly (%s), %.0f LDU long, the real 20 cm's 500" % [
		pieces, item, length], plug >= 0 and pieces > 1 and not item.is_empty() and absf(length - 500.0) < 15.0)
	var wired: Wiring = _wiring()
	wired.set_to(box, "forward")
	var power: Dictionary = wired.power_of(motor)
	_check("read as the motor's cable, its plug on the box: runs with the box on (%s)" % str(power["words"]),
		bool(power["wired"]) and is_equal_approx(float(power["run"]), 1.0))
	_check("lay_flex says what the cable wires", said.contains("wired to") or said.contains("wired on"))
	# A second motor's cable on the first's plug, its plug turned half round.
	var other: int = _place("58120", Transform3D(Basis.IDENTITY, Vector3(-120, 0, 160)), 71)
	var stacked: String = await _say("lay_flex", {"kind": "pf_cable", "from": {"brick": other},
		"to": {"brick": box}})
	_check("the box's contacts taken, a second cable is not put on it (%s)" % stacked,
		not stacked.begins_with("Laid"))
	stacked = await _say("lay_flex", {"kind": "pf_cable", "from": {"brick": other},
		"to": {"brick": plug}, "reversed": true})
	print("    lay_flex reversed: %s" % stacked)
	var both: Wiring = _wiring()
	both.set_to(box, "forward")
	_check("a second cable's plug on the first's, turned half round: its motor runs back, the first forward",
		stacked.begins_with("Laid") and is_equal_approx(float(both.power_of(other)["run"]), -1.0)
		and is_equal_approx(float(both.power_of(motor)["run"]), 1.0))
	var first: String = await _save("wires_laid.ldr")
	await _open(MODELS + "wires_laid.ldr")
	var second: String = await _save("wires_laid.ldr")
	_check("saved, opened again and saved: byte for byte (%d bytes)" % first.length(),
		not first.is_empty() and first == second)
	var again: Wiring = _wiring()
	var box_again: int = -1
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "58119":
			box_again = brick.id
	again.set_to(box_again, "forward")
	var runs_again: Array = []
	for key: int in again.motors:
		runs_again.append(float(again.power_of(key)["run"]))
	runs_again.sort()
	_check("opened again, still the motors' cables: %s" % "; ".join(again.motor_lines()),
		box_again >= 0 and runs_again == [-1.0, 1.0])
	var told: String = await _say("simulate_mechanism", {"power": "on"})
	_check("simulate_mechanism power=on says the motor's cable and that it runs",
		told.contains("Power (a motor runs only when its cable reaches a box that is on")
		and told.contains("runs forward at 100%") and told.contains("runs back at 100%"))
	if not told.contains("runs forward"):
		print(told.left(1500))
	# Undo, on the file as laid: the cable goes, and the motor is not wired.
	await _open(MODELS + "wires_laid.ldr")
	_builder.forget_history()
	var cable_ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "343" or brick.part_id == "58124c01":
			cable_ids.append(brick.id)
	var steps: Array = _builder.swap_bricks(PackedInt64Array(cable_ids), [])
	_builder.record(steps, "took the cable out")
	var gone: Wiring = _wiring()
	gone.set_to(box_again if _world.get_brick(box_again) != null else box, "forward")
	var unwired: bool = true
	for key: int in gone.motors:
		unwired = unwired and not bool(gone.power_of(key)["wired"])
	_check("the cable taken out: the motor is not wired", unwired and not gone.motors.is_empty())
	_builder.undo()
	var back: Wiring = _wiring()
	var runs: bool = false
	for key: int in back.sources:
		back.set_to(key, "forward")
	for key: int in back.motors:
		runs = runs or float(back.power_of(key)["run"]) > 0.0
	_check("undone: the cable is back and the motor runs", runs)


func _wiring() -> Wiring:
	var lib: PartLibrary = _library
	return Wiring.read(_world.bricks(), func(part: String) -> String:
		return Simulation.motor_of(lib, part))


func _place(part_id: String, at: Transform3D, colour: int) -> int:
	var id: int = _world.add_brick(part_id, colour, at)
	_builder.register(id, part_id, at)
	return id


# -- 3. 42042 in Simulate -------------------------------------------------------------------


func _simulate_42042() -> void:
	if not FileAccess.file_exists(SET_42042):
		_check("42042's file is here (tools/kinefuncs.py fetch)", false)
		return
	var problem: String = await _open_file(SET_42042)
	if not _check("42042 opened (%d parts)" % _world.brick_count(), problem.is_empty()):
		return
	# Its file saved untouched: every LDCad path byte for byte.
	var source: String = FileAccess.get_file_as_string(SET_42042)
	var saved: String = await _save("wires_42042.mpd")
	var paths: Array = _ldcad_sections(source)
	var kept: int = 0
	for section: String in paths:
		if saved.contains(section):
			kept += 1
	_check("saved untouched: %d of its %d LDCad cable and hose paths byte for byte" % [kept, paths.size()],
		not paths.is_empty() and kept == paths.size())
	_panel.open()
	await _settled()
	var wiring: Wiring = _panel.wiring
	var box: int = -1
	var motor: int = -1
	if wiring != null:
		for key: int in wiring.sources:
			box = key
		for key: int in wiring.motors:
			motor = key
	_check("Simulate reads the L motor's cable to the box: %s" % (
		"\n      ".join(wiring.motor_lines()) if wiring != null else "nothing read"),
		box >= 0 and motor >= 0 and bool(wiring.power_of(motor)["wired"]))
	_panel.play()
	await _frames(5)
	_check("the box off: Play does not run the motor, and says why (%s)" % _panel._status.text,
		not _panel.playing and _panel._status.text.contains("is off"))
	# The box clicked, as a person clicks it: its switch worked on the part.
	_builder.selection.clear()
	_builder.selection[box] = true
	_builder.selection_changed.emit(1)
	await _settled()
	await _frames(30)
	var rate: float = _panel._power_rate
	_check("the box clicked on: the motor drives and plays at 390 rpm (%s)" % _panel._status.text,
		_panel.playing and absf(absf(rate) * 60.0 - 390.0) < 1.0
		and _panel.sim.motored.get(_panel.sim.driver, -1) == motor)
	var turned: float = _panel.turns
	_check("its train turns: the driver %.2f turns on, %d parts moving" % [turned, _panel.sim.moving.size()],
		absf(turned) > 0.05 and _panel.sim.moving.size() > 3)
	# The plug pulled off the box.
	var plug: int = _plug_of(wiring, motor)
	var brick: BrickWorld.Brick = _world.get_brick(plug)
	var lifted: Transform3D = brick.transform.translated(Vector3(0, 40, 0))
	var steps: Array = _builder.swap_bricks(PackedInt64Array([plug]), [{"part": brick.part_id,
		"color": brick.color_code, "at": lifted, "path": Assemblies.path_of(brick)}])
	_builder.record(steps, "pulled the plug")
	await _frames(5)
	await _settled()
	await _frames(10)
	var stopped_at: float = _panel.turns
	await _frames(20)
	var why: String = "\n".join(_panel.wiring.motor_lines()) if _panel.wiring != null else ""
	_check("its plug pulled off the box: it stops, and says its plug is on nothing (%s)" % why,
		not _panel.playing and is_equal_approx(stopped_at, _panel.turns) and why.contains("on nothing"))
	_builder.undo()
	await _frames(5)
	await _settled()
	await _frames(20)
	_check("undone: the plug back on the box, the box still on, it runs again (%s)" % _panel._status.text,
		_panel.playing and _panel._power_rate != 0.0)
	_panel.close()


func _timed() -> void:
	for path: String in ["res://models/orthanc.ldr", SET_42042]:
		var problem: String = await _open_file(path)
		if not _check("%s opened (%d parts)" % [path.get_file(), _world.brick_count()], problem.is_empty()):
			continue
		var reading: float = INF
		var placing: float = INF
		for _n: int in 5:
			var began: int = Time.get_ticks_usec()
			_wiring()
			reading = minf(reading, (Time.get_ticks_usec() - began) / 1000.0)
			began = Time.get_ticks_usec()
			Flex.electric_anchors(_world, _library, "pf_cable")
			placing = minf(placing, (Time.get_ticks_usec() - began) / 1000.0)
			await process_frame
		_check("%s, %d parts: the wiring read in %.1f ms, a cable's places found in %.1f ms, each under 16"
			% [path.get_file(), _world.brick_count(), reading, placing], reading < 16.0 and placing < 16.0)


## The plug at the end of [param motor]'s cable.
static func _plug_of(wired: Wiring, motor: int) -> int:
	for cable: Dictionary in wired.cables:
		var ends: Array = cable["ends"]
		if ends.has("t:%d" % motor):
			for key: String in ends:
				if key.begins_with("p:"):
					return int(key.get_slice(":", 1))
	return -1


## Each FILE section of [param text] that is an LDCad path, whole.
static func _ldcad_sections(text: String) -> Array:
	var out: Array = []
	var sections: PackedStringArray = text.replace("\r\n", "\n").split("\n0 FILE ")
	for section: String in sections:
		if section.contains("!LDCAD PATH_POINT"):
			out.append(section.get_slice("\n", 0) + "\n" + section.substr(section.find("\n") + 1).left(
				section.find("0 !LDCAD GENERATED") - section.find("\n") - 1))
	return out


# -- the sets ------------------------------------------------------------------------------


func _sets(listing: String, rows_path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(listing))
	if not parsed is Dictionary or rows_path.is_empty():
		_check("--sets=%s is a listing, and --rows given" % listing, false)
		return
	_rows = FileAccess.open(rows_path, FileAccess.WRITE)
	for model: Dictionary in (parsed as Dictionary).get("sets", []):
		var file: String = str(model.get("file", ""))
		var began: int = Time.get_ticks_msec()
		var problem: String = await _open_file(file)
		print("\n%s: %d parts%s" % [str(model["set"]), _world.brick_count(), "" if problem.is_empty()
			else ", " + problem])
		if not problem.is_empty():
			_row({"set": model["set"], "error": problem})
			continue
		_index()
		var sim: Simulation = _read_sim()
		var wired: Wiring = _wiring()
		for key: int in wired.sources:
			match str(Wiring.SOURCES[wired.sources[key]]["kind"]):
				"box", "reverser":
					wired.set_to(key, "on")
				"receiver":
					wired.set_to(key, "on", 0)
					wired.set_to(key, "on", 1)
				"hub":
					wired.set_to(key, "on")
					for port: int in 6:
						wired.set_to(key, "1.0", port)
		for motor: int in wired.motors:
			await _motor_row(model, sim, wired, motor, began)
	_rows.close()


func _motor_row(model: Dictionary, sim: Simulation, wired: Wiring, motor: int, began: int) -> void:
	var power: Dictionary = wired.power_of(motor)
	var body: int = -1
	for turned: int in sim.motored:
		if int(sim.motored[turned]) == motor:
			body = turned
	var row: Dictionary = {"set": model["set"], "motor": motor, "part": wired.parts.get(motor, ""),
		"name": str((Simulation.MOTORS[wired.motors[motor]] as Array)[0]), "wired": bool(power["wired"]),
		"how": str(power["words"]) if bool(power["wired"]) else str(power["why"]),
		"run": float(power["run"]), "functions": []}
	var run: float = float(power["run"])
	if absf(run) > 1e-6 and body >= 0 and sim.can_drive(body):
		sim.drive(body)
		var at: Dictionary = sim.placed(signf(run) * REACH / TAU)
		for fn: Dictionary in model.get("functions", []):
			var control: int = _brick_for((fn.get("control", []) as Array)[0])
			if control < 0 or not fn.get("first", []).is_empty():
				continue
			var control_body: int = sim.model.body_of(control) if sim.model.parts.has(control) else -2
			if control != motor and control_body != body:
				continue
			var still: Array = []
			var wrong: Array = []
			var moved: int = 0
			for item: Dictionary in fn.get("moves", []):
				var key: int = _brick_for(item.get("part", {}))
				var against: int = _brick_for(item["against"]) if item.get("against") is Dictionary else -1
				if key >= 0 and _moved(sim, key, against, at):
					moved += 1
				else:
					still.append(str((item.get("part", {}) as Dictionary).get("ref", "?")))
			for item: Dictionary in fn.get("stays", []):
				var key: int = _brick_for(item.get("part", {}))
				var against: int = _brick_for(item["against"]) if item.get("against") is Dictionary else -1
				if key >= 0 and _moved(sim, key, against, at):
					wrong.append(str((item.get("part", {}) as Dictionary).get("ref", "?")))
			var result: String = "works" if still.is_empty() and wrong.is_empty() else (
				"partly" if moved > 0 else "no")
			(row["functions"] as Array).append({"n": fn["n"], "does": str(fn.get("does", "")).left(80),
				"result": result, "moved": moved, "of": (fn.get("moves", []) as Array).size(),
				"kinefuncs": str(fn.get("kinefuncs", ""))})
	elif absf(run) > 1e-6:
		row["note"] = "its output turns nothing Simulate can drive (body %d)" % body
	# The plug pulled off what it is on: the motor stops.
	var plug: int = _plug_of(wired, motor)
	if plug < 0:
		row["pulled"] = {"error": "no plug of its own cable to pull"}
	else:
		var brick: BrickWorld.Brick = _world.get_brick(plug)
		var lifted: Transform3D = brick.transform.translated(Vector3(0, 40, 0))
		var steps: Array = _builder.swap_bricks(PackedInt64Array([plug]), [{"part": brick.part_id,
			"color": brick.color_code, "at": lifted, "path": Assemblies.path_of(brick)}])
		_builder.record(steps, "pulled the plug")
		var pulled: Wiring = _wiring()
		pulled.settings = wired.settings.duplicate()
		var after: int = motor if pulled.motors.has(motor) else -1
		if plug == motor:
			# A motor with its cable in one part (99499c01): pulled whole, its
			# plug with it, and put back as a new part.
			for key: int in pulled.motors:
				var moved: BrickWorld.Brick = _world.get_brick(key)
				if moved != null and moved.transform.origin.distance_to(lifted.origin) < 0.1:
					after = key
		var gone: Dictionary = pulled.power_of(after) if after >= 0 else {"run": 0.0, "why": "gone"}
		row["pulled"] = {"plug": plug, "run": float(gone["run"]), "why": str(gone["why"])}
		_builder.undo()
	row["ms"] = Time.get_ticks_msec() - began
	_row(row)
	print("  %s #%d: %s; run %s; %s; pulled: %s" % [row["name"], motor, row["how"], row["run"],
		", ".join(PackedStringArray((row["functions"] as Array).map(func(f: Dictionary) -> String:
			return "fn %d %s (%d/%d, KINEFUNCS %s)" % [f["n"], f["result"], f["moved"], f["of"], f["kinefuncs"]]))),
		str(row.get("pulled", {}))])


func _row(row: Dictionary) -> void:
	_rows.store_line(JSON.stringify(row))
	_rows.flush()


func _read_sim() -> Simulation:
	var sim: Simulation = Simulation.read(_world.bricks(), _library, _store.scenery)
	sim.hold_with(_world, _builder, null)
	return sim


func _index() -> void:
	_cells.clear()
	for brick: BrickWorld.Brick in _world.bricks():
		var cell := Vector3i(brick.transform.origin.round())
		if not _cells.has(cell):
			_cells[cell] = []
		(_cells[cell] as Array).append(brick.id)


## The brick standing where Kinebrick reads [param ref] (kinefuncs_probe's).
func _brick_for(ref: Dictionary) -> int:
	var found: int = _standing(ref.get("at", []), _stem(str(ref.get("name", ""))))
	if found < 0 and ref.get("of") is Dictionary:
		found = _standing((ref["of"] as Dictionary).get("at", []), _stem(str((ref["of"] as Dictionary).get("name", ""))))
	if found < 0:
		found = _standing(ref.get("at", []), "")
	return found


func _standing(at: Array, stem: String) -> int:
	if at.size() != 16:
		return -1
	var place: Vector3 = Vector3(float(at[3]), float(at[7]), float(at[11])) * LdrModel.FLIP + _store.lift()
	var best: int = -1
	var nearest: float = NEAR
	var cell := Vector3i(place.round())
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			for dz: int in [-1, 0, 1]:
				for key: int in _cells.get(cell + Vector3i(dx, dy, dz), []):
					var brick: BrickWorld.Brick = _world.get_brick(key)
					if brick == null or (not stem.is_empty() and _stem(brick.part_id) != stem):
						continue
					var off: float = brick.transform.origin.distance_to(place)
					if off <= nearest:
						nearest = off
						best = key
	return best


static func _stem(part: String) -> String:
	var name: String = part.to_lower().trim_suffix(".dat").get_file()
	var digits: String = ""
	for c: String in name:
		if c >= "0" and c <= "9":
			digits += c
		elif not digits.is_empty():
			break
		else:
			return name
	return digits


static func _angle(basis: Basis) -> float:
	return 2.0 * acos(minf(1.0, absf(Quaternion(basis.orthonormalized()).w)))


func _rest(sim: Simulation, key: int) -> Transform3D:
	if sim.model.rest.has(key):
		return sim.model.rest[key]
	var brick: BrickWorld.Brick = _world.get_brick(key)
	return brick.transform if brick != null else Transform3D.IDENTITY


func _moved(sim: Simulation, key: int, against: int, at: Dictionary) -> bool:
	var rest: Transform3D = _rest(sim, key)
	var mine: Transform3D = (at.get(key, rest) as Transform3D) * rest.affine_inverse()
	if against >= 0:
		var theirs_rest: Transform3D = _rest(sim, against)
		var theirs: Transform3D = (at.get(against, theirs_rest) as Transform3D) * theirs_rest.affine_inverse()
		mine = theirs.affine_inverse() * mine
	var went: float = (mine * rest.origin).distance_to(rest.origin)
	return went >= MOVED or rad_to_deg(_angle(mine.basis)) >= MOVED


# -- files and frames ----------------------------------------------------------------------


func _open_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "no file %s" % path
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", path)
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 300000:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(5)
	if _world.brick_count() == 0:
		return "it opened with no parts"
	var playback: Variant = _main.get("_playback")
	if playback != null and (playback as BuildPlayback).is_playing():
		(playback as BuildPlayback).stop()
		await _frames(3)
	_builder.forget_history()
	return ""


func _save(file: String) -> String:
	if not bool(_main.call("save_model", MODELS + file)):
		print("    could not write %s" % file)
		return ""
	await _settled()
	return FileAccess.get_file_as_string(MODELS + file)


func _open(path: String) -> void:
	_main.call("_open", path)
	await _settled()


func _settled() -> void:
	for _n: int in 600:
		if _store == null or _store.awaited.is_empty():
			break
		await process_frame
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 600000:
		await process_frame
		if not Working.is_busy() and (not _panel.visible or (_panel.sim != null
				and not _panel._reading and not _panel._driving)):
			break
	await _frames(10)


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	if text.is_empty() and (answer as Dictionary).has("error"):
		text = str((answer as Dictionary)["error"])
	return text


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
