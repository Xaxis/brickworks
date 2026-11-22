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
##      Control+ hub's port; an extension wire between. A motor with no cable
##      drawn turns by hand, and a plug beside any other part is no cable
##      (S1). The same model mirrored reads the same (N3). 9 V: a 4760c01
##      box, a 5306 wire to a 71427 motor's contacts, forward and turned half
##      round; a 58124c02 on 9 V contacts takes a Power Functions plug.
##   2. In the app: a box and an M motor placed, and a Power Functions cable
##      laid from the motor's outlet to the box by lay_flex (MCP, as a
##      session lays one): its plug on the box, the cable 500 LDU (its real
##      20 cm), one undo; read by Wiring as the motor's cable; saved, opened
##      again and saved: the file byte for byte, the cable's sub-model the
##      same and still the motor's cable; simulate_mechanism power=on says the
##      motor runs; undo takes the cable away and the motor is not wired.
##      After the reopen the cable is an item (F4): found by name, laid again
##      by lay_flex item=, Reshape reads its two ends and offers Turn the plug;
##      outlet to outlet refused, a taken box said (S3, S5); reversed= on a
##      hose refused (N7).
##   3. 42042's L motor through Simulate as a person drives it: the box
##      clicked on through the real click (EditVerbs.click on the part under
##      the pointer), the motor plays at 390 rpm and turns its train; Play
##      with the box off switches it on and runs; a selection made otherwise
##      flips no switch (N6); the plug pulled off the box, it stops and says
##      why; undone, it runs again. And 42042's file saved untouched: each
##      LDCad cable path in it byte for byte.
##   4. The wiring read, and where a cable's ends may go, each under 16 ms
##      (the best of five) on Orthanc and on 42042.
##
## With --sets, each set of LISTING (tools/wires_sets.py) opened as File,
## Open opens it: each motor's cable read as its booklet wires it, the boxes
## (and receivers' levers, hubs' ports) switched on by a click on the part in
## Simulate (the rest of a receiver's levers by the row's buttons), each function whose
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


## The motors among [param bricks], as Simulate reads them.
static func _motors(bricks: Array) -> Dictionary:
	return Simulation.motors_in(bricks, null)


static func _read(bricks: Array) -> Wiring:
	return Wiring.read(bricks, _motors(bricks))


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
	# 9 V contacts are read on their diagonal: a plug stands square on the
	# studs, an eighth of a turn from it, facing forward either way.
	var x: Vector3 = (frame[1] as Vector3).rotated(up, deg_to_rad(turn + (45.0 if str(row[0]) == "9v" else 0.0)))
	var raise: float = (Wiring.PLUG_UP if str(row[0]) != "pu" else 0.0) + lift
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
			_brick(4, "u9190", Transform3D(Basis.IDENTITY, Vector3(100, 20, 0)), "cable#1")]
		var wired: Wiring = _read(bricks)
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
	var bare: Wiring = _read([_brick(1, "58119", box_at), _brick(2, "58120", motor_at)])
	bare.set_to(1, "forward")
	_check("a motor with no cable: turns by hand, said (%s)" % str(bare.power_of(2)["why"]),
		not bool(bare.power_of(2)["wired"]) and bool(bare.power_of(2)["by_hand"])
		and str(bare.power_of(2)["why"]).contains("no cable"))
	# S1: a plug and a motor in one sub-model with a brick between are no
	# cable: only cable pieces make one.
	var fake: Wiring = _read([_brick(1, "58119", box_at), _brick(2, "58120", motor_at, "frame#1"),
		_brick(3, "58124c01", _plug_on("58119", box_at, 0), "frame#1"),
		_brick(4, "3005", Transform3D(Basis.IDENTITY, Vector3(100, 20, 0)), "frame#1")])
	fake.set_to(1, "forward")
	_check("a plug, a motor and a brick in one sub-model: no cable, the motor by hand (%s)"
		% str(fake.power_of(2)["why"]), bool(fake.power_of(2)["by_hand"])
		and float(fake.power_of(2)["run"]) == 0.0)
	# N3: the whole model mirrored reads the same.
	var mirror := Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)
	for turn: float in [0.0, 180.0]:
		var straight: Array = [_brick(1, "58119", box_at), _brick(2, "99499", motor_at, "cable#1"),
			_brick(3, "58124c01", _plug_on("58119", box_at, 0, turn), "cable#1"),
			_brick(4, "u9190", Transform3D(Basis.IDENTITY, Vector3(100, 20, 0)), "cable#1")]
		var mirrored: Array = straight.map(func(b: BrickWorld.Brick) -> BrickWorld.Brick:
			return _brick(b.id, b.part_id, mirror * b.transform, b.unit))
		var a: Wiring = _read(straight)
		var b: Wiring = _read(mirrored)
		a.set_to(1, "forward")
		b.set_to(1, "forward")
		_check("mirrored, the plug %s: runs the same (%s, %s)" % ["facing" if turn == 0.0 else "turned half round",
			a.power_of(2)["run"], b.power_of(2)["run"]], float(a.power_of(2)["run"]) != 0.0
			and is_equal_approx(float(a.power_of(2)["run"]), float(b.power_of(2)["run"])))
	# The receiver: its own cable's plug on the box, the motor on its red output.
	var receiver_at: Transform3D = _part_for_own_plug("58123c01", _plug_on("58119", box_at, 0))
	var bricks: Array = [_brick(1, "58119", box_at), _brick(5, "58123c01", receiver_at),
		_brick(2, "58120c01", _part_for_own_plug("58120c01", _plug_on("58123c01", receiver_at, 0)))]
	var through: Wiring = _read(bricks)
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
	var flipped: Wiring = _read([_brick(1, "58119", box_at), _brick(6, "61929c01", reverser_at),
		_brick(2, "58121c01", _part_for_own_plug("58121c01", _plug_on("61929c01", reverser_at, 0)))])
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
	var hub: Wiring = _read([_brick(7, "22127", hub_at),
		_brick(2, "22169c01", _part_for_own_plug("22169c01", plug_in))])
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
	var extended: Wiring = _read([_brick(1, "58119", box_at), wire_brick,
		_brick(2, "58120c01", _part_for_own_plug("58120c01", on_far))])
	extended.set_to(1, "forward")
	_check("through an extension wire: it runs (%s)" % str(extended.power_of(2)["words"]),
		is_equal_approx(absf(float(extended.power_of(2)["run"])), 1.0))
	_nine_volt()


## 9 V (F5): a 4760c01 box, a 9 V wire (two 5306 plugs and its 993 run, a
## sub-model) from the box's contacts to a 71427 motor's own, forward and
## turned half round; the box's switch worked; and a 58124c02 on the box's
## contacts with a Power Functions motor's plug on its top.
func _nine_volt() -> void:
	var box_at := Transform3D(Basis.IDENTITY, Vector3(0, 0, -600))
	var motor_at := Transform3D(Basis.IDENTITY, Vector3(300, 0, -600))
	for turn: float in [0.0, 180.0]:
		var bricks: Array = [_brick(11, "4760c01", box_at), _brick(12, "71427", motor_at),
			_brick(13, "5306", _plug_on("4760c01", box_at, 0, 0.0), "wire#9"),
			_brick(14, "5306", _plug_on("71427", motor_at, 0, turn), "wire#9"),
			_brick(15, "993", Transform3D(Basis.IDENTITY, Vector3(150, 30, -600)), "wire#9")]
		var wired: Wiring = _read(bricks)
		var off: Dictionary = wired.power_of(12)
		_check("9 V: a wire from the box to the motor's contacts, the box off: wired and still (%s)"
			% str(off["why"]), bool(off["wired"]) and float(off["run"]) == 0.0)
		wired.work(11)
		var sign: float = 1.0 if turn == 0.0 else -1.0
		_check("9 V: the box's switch worked once, the plug %s: it runs %s (%s)" % [
			"facing" if turn == 0.0 else "turned half round", "forward" if sign > 0.0 else "back",
			str(wired.power_of(12)["words"])], is_equal_approx(float(wired.power_of(12)["run"]), sign))
	# A 9 V motor with nothing on its contacts turns by hand.
	var alone: Wiring = _read([_brick(11, "4760c01", box_at), _brick(12, "71427", motor_at)])
	_check("9 V: a motor with nothing on its contacts turns by hand (%s)" % str(alone.power_of(12)["why"]),
		bool(alone.power_of(12)["by_hand"]))
	# 58124c02: its 9 V bottom on the box, a Power Functions motor's own plug on its top.
	var adapter: Transform3D = _plug_on("4760c01", box_at, 0)
	var top: Transform3D = adapter.translated_local(Vector3(0, Wiring.PLUG_UP, 0))
	var mixed: Wiring = _read([_brick(11, "4760c01", box_at), _brick(16, "58124c02", adapter),
		_brick(17, "58120c01", _part_for_own_plug("58120c01", top))])
	mixed.set_to(11, "forward")
	_check("9 V: a 58124c02 on the box's contacts, a Power Functions motor's plug on its top: it runs (%s)"
		% str(mixed.power_of(17)["words"] if mixed.motors.has(17) else "no motor"),
		mixed.motors.has(17) and absf(float(mixed.power_of(17)["run"])) > 0.5)


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
		elif brick.part_id == "u9190":
			pieces += 1
	var length: float = Flex.item_length("pf_cable", _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return b.part_id == "u9190").map(func(b: BrickWorld.Brick) -> Dictionary:
			return {"part": b.part_id, "at": b.transform}))
	_check("its plug and %d pieces of cable in one sub-assembly (%s), %.0f LDU long, the real 20 cm's 500" % [
		pieces, item, length], plug >= 0 and pieces > 1 and not item.is_empty() and absf(length - 500.0) < 15.0)
	var wired: Wiring = _wiring()
	wired.set_to(box, "forward")
	var power: Dictionary = wired.power_of(motor)
	_check("read as the motor's cable, its plug on the box: runs with the box on (%s)" % str(power["words"]),
		bool(power["wired"]) and is_equal_approx(float(power["run"]), 1.0))
	_check("lay_flex says what the cable wires", said.contains(": wired "))
	# S3: outlet to outlet is no cable, in lay_flex as in the hand tool.
	var third: int = _place("58120", Transform3D(Basis.IDENTITY, Vector3(240, 0, 160)), 71)
	var outlets: String = await _say("lay_flex", {"kind": "pf_cable", "from": {"brick": third},
		"to": {"brick": motor}})
	_check("outlet to outlet refused, said (%s)" % outlets, not outlets.begins_with("Laid")
		and outlets.contains("two outlets"))
	# N7: reversed= on a hose is refused, not ignored.
	var hose: String = await _say("lay_flex", {"kind": "ribbed_hose", "from": {"brick": third},
		"to": {"brick": motor}, "reversed": true})
	_check("reversed= on a hose refused (%s)" % hose, hose.contains("reversed="))
	_builder.swap_bricks(PackedInt64Array([third]), [])
	# A second motor's cable on the first's plug, its plug turned half round.
	var other: int = _place("58120", Transform3D(Basis.IDENTITY, Vector3(-120, 0, 160)), 71)
	var stacked: String = await _say("lay_flex", {"kind": "pf_cable", "from": {"brick": other},
		"to": {"brick": box}})
	_check("the box's contacts taken, a second cable is not put on it, and said why (%s)" % stacked,
		not stacked.begins_with("Laid") and stacked.contains("give to= that plug"))
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
	await _item_after_reopen()
	var told: String = await _say("simulate_mechanism", {"power": "on"})
	_check("simulate_mechanism power=on says the motor's cable and that it runs",
		told.contains("Power (a motor whose cable is drawn runs only when it reaches")
		and told.contains("runs forward at 100%") and told.contains("runs back at 100%"))
	if not told.contains("runs forward"):
		print(told.left(1500))
	# Undo, on the file as laid: the cable goes, and the motor is not wired.
	await _open(MODELS + "wires_laid.ldr")
	_builder.forget_history()
	var cable_ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "u9190" or brick.part_id == "58124c01":
			cable_ids.append(brick.id)
	var steps: Array = _builder.swap_bricks(PackedInt64Array(cable_ids), [])
	_builder.record(steps, "took the cable out")
	var gone: Wiring = _wiring()
	gone.set_to(box_again if _world.get_brick(box_again) != null else box, "forward")
	var unwired: bool = true
	for key: int in gone.motors:
		unwired = unwired and not bool(gone.power_of(key)["wired"])
	_check("the cable taken out: the motor is not wired, it turns by hand", unwired and not gone.motors.is_empty())
	_builder.undo()
	var back: Wiring = _wiring()
	var runs: bool = false
	for key: int in back.sources:
		back.set_to(key, "forward")
	for key: int in back.motors:
		runs = runs or float(back.power_of(key)["run"]) > 0.0
	_check("undone: the cable is back and the motor runs", runs)


func _wiring() -> Wiring:
	return Wiring.read_with(_world.bricks(), _library)


## F4: a laid cable after a reopen is an item as a hose is: found among the
## items, Reshape reads its two ends and its length and offers Turn the
## plug, lay_flex item= lays it again (one undo, and redo), and the motor is
## still its motor's.
func _item_after_reopen() -> void:
	var items: Dictionary = Flex.items_in(_world)
	var cables: Array = items.keys().filter(func(path: String) -> bool:
		return str((items[path] as Dictionary)["kind"]) == "pf_cable")
	_check("opened again: both cables are items (%s)" % ", ".join(PackedStringArray(cables.map(
		func(path: String) -> String: return Assemblies.label(path)))), cables.size() == 2)
	if cables.is_empty():
		return
	var flex: FlexTool = _main.get("_flex")
	var path: String = cables[0]
	var reshaped: bool = flex.reshape(path)
	var ends: Array = flex._ends.map(func(end: Dictionary) -> String: return str(end.get("kind", "")))
	_check("Reshape reads its ends (%s), its length %s, and offers Turn the plug" % [", ".join(
		PackedStringArray(ends)), flex._real_id], reshaped and ends.has("outlet") and ends.has("contacts")
		and flex._turn_plug.visible and flex._real_id == "pf20")
	flex.leave()
	await _frames(3)
	var named: String = Assemblies.label(path)
	var plug_end: int = -1
	var motor_end: int = -1
	var wired: Wiring = _wiring()
	for cable: Dictionary in wired.cables:
		if str(cable["path"]) == path:
			for key: String in cable["ends"]:
				if key.begins_with("p:"):
					var on: int = -1
					for join: Array in wired.joins:
						if str(join[0]) == key and str(join[4]) == "seat":
							on = (wired.points[str(join[1])] as Wiring.Point).brick
					plug_end = on
				elif key.begins_with("t:"):
					motor_end = int(key.get_slice(":", 1))
	var depth: int = _builder.history_depth()
	var again: String = await _say("lay_flex", {"kind": "pf_cable", "item": named,
		"from": {"brick": motor_end}, "to": {"brick": plug_end}, "reversed": true})
	_check("lay_flex item=%s lays it again, turned half round, one undo (%s)" % [named, again.left(160)],
		again.begins_with("Laid") and _builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(3)
	_check("undone: the cable as it was", Flex.items_in(_world).size() == 2)
	_builder.redo()
	await _frames(3)
	_check("redone: laid again", Flex.items_in(_world).size() == 2)
	_builder.undo()
	await _frames(3)


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
	await _main.call("open_simulate")
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
	# N6: the box selected some other way (the tree, a session): no switch.
	_builder.select_brick(box, false)
	await _frames(5)
	_check("the box selected otherwise: its switch not worked (%s)" % _panel._switch_words(box, 0),
		_panel.wiring.switch_index(box) == 0)
	_builder.clear_selection()
	# The box clicked, as a person clicks it: the part under the pointer.
	var clicked: String = _click_on(box)
	await _settled()
	await _frames(30)
	_check("the box clicked through the real click (%s): selected nothing" % clicked,
		clicked.begins_with("clicked") and _builder.selection.is_empty())
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
	# The box worked round to off, and Play: it switches the box on and runs,
	# as a person pressing Play wants (F2).
	while _panel.wiring.switch_index(box) != 0:
		_panel.work_switch(box, 0)
	await _settled()
	if _panel.playing:
		_panel.play()
	_panel.play()
	await _frames(10)
	_check("the box off, Play: switches it on and runs (%s)" % _panel._status.text,
		_panel.playing and _panel._power_rate != 0.0 and _panel.wiring.switch_index(box) != 0)
	_panel.close()


## Click [param brick] as a person does: the camera turned to it from a
## side it shows, and EditVerbs.click at a point of the screen where the
## part under the pointer is it. "clicked ..." or why not.
func _click_on(brick_id: int) -> String:
	var verbs: EditVerbs = _main.get("_verbs")
	var camera: CadCamera = verbs.camera
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	if brick == null or camera == null:
		return "no part or no camera"
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var box: AABB = brick.transform * mesh.bounds if mesh != null \
		else AABB(brick.transform.origin - Vector3.ONE * 10.0, Vector3.ONE * 20.0)
	var centre: Vector3 = box.get_center()
	var kept: Transform3D = camera.global_transform
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	var ways: Array = [Vector3.UP, Vector3(1, 1, 1), Vector3(-1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
		Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3(1, -1, 1), Vector3(-1, -1, -1),
		Vector3.DOWN]
	for way: Vector3 in ways:
		var eye: Vector3 = centre + way.normalized() * 3000.0
		camera.look_at_from_position(eye, centre, Vector3.FORWARD if absf(way.normalized().y) > 0.99 else Vector3.UP)
		var corners: Array = []
		for n: int in 8:
			corners.append(camera.unproject_position(box.get_endpoint(n)))
		var low: Vector2 = corners[0]
		var high: Vector2 = corners[0]
		for corner: Vector2 in corners:
			low = low.min(corner)
			high = high.max(corner)
		for i: int in 7:
			for j: int in 7:
				var at := Vector2(lerpf(low.x, high.x, (i + 0.5) / 7.0), lerpf(low.y, high.y, (j + 0.5) / 7.0))
				if at.x < 0.0 or at.y < 0.0 or at.x > size.x or at.y > size.y:
					continue
				if verbs.brick_at(at) == brick_id:
					var took: bool = verbs.click(at, false)
					camera.global_transform = kept
					return "clicked from %s at %s, %s" % [way, at.round(), "taken" if took else "not taken"]
	camera.global_transform = kept
	return "hidden from every side"


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
		# Each source switched on in Simulate by a click on the part, as a
		# person does (F3); a receiver's other lever by the row's button.
		await _main.call("open_simulate")
		await _settled()
		var clicks: Array = []
		if _panel.wiring != null:
			for key: int in _panel.wiring.sources:
				var kind: String = str(Wiring.SOURCES[_panel.wiring.sources[key]]["kind"])
				var how: String = _click_on(key)
				await _frames(3)
				clicks.append({"source": key, "part": _panel.wiring.parts.get(key, ""),
					"in": Assemblies.path_of(_world.get_brick(key)), "click": how,
					"said": _panel._switch_words(key, 0)})
				print("  %s #%d (%s): %s; %s" % [kind, key, _panel.wiring.parts.get(key, ""), how,
					_panel._switch_words(key, 0)])
				if kind == "receiver":
					for output: int in 2:
						if _panel.wiring.lever_index(key, output) == 0:
							_panel.work_switch(key, output)
				elif _panel.wiring.switch_index(key) == 0 and kind != "hub":
					_panel.work_switch(key, 0)
				elif kind == "hub" and not bool(_panel.wiring.settings.get(key, false)):
					_panel.work_switch(key, 0)
			wired.settings = _panel.wiring.settings.duplicate()
		_row({"set": model["set"], "clicks": clicks})
		_panel.close()
		await _frames(3)
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
