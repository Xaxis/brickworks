## The wiring review's repros (wreview-2026-11-22), kept as a check of the
## fixes (wfix): Wiring read off real files and off placed parts, headless and
## pure (no app, no library). Not a suite probe.
##   godot --headless --path . --script src/dev/wires_repro.gd -- FILE...
## Each FILE: every motor said with every source switched on, the time of
## the read, what was turned by hand and why, the cables and the loose plugs.
## A motor the old read ran (before 455144b85, every motor turned by hand)
## must still turn: by its cable, or by hand when no cable of it is drawn;
## it stops only where its cable really is pulled (F2), said. Then the
## synthetic cases S1-S6, N1, N3, N5 and 9 V (F5), each checked; exit 1 on
## any FAIL.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	for path: String in OS.get_cmdline_user_args():
		_file(path)
	_synthetic()
	print("\nwires_repro: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> bool:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


static func _read(bricks: Array) -> Wiring:
	return Wiring.read(bricks, Simulation.motors_in(bricks, null))


static func _bricks_of(path: String) -> Array:
	var model: LdrModel = LdrModel.load_file(path)
	var out: Array = []
	if model == null:
		return out
	var id: int = 1
	for placement: LdrModel.Placement in model.flatten({}):
		var brick := BrickWorld.Brick.new(id, placement.part_id, placement.color_code, placement.transform)
		brick.unit = placement.unit
		brick.group = placement.group
		if placement.mirrored:
			brick.set_meta("mirrored", true)
		out.append(brick)
		id += 1
	return out


func _file(path: String) -> void:
	var bricks: Array = _bricks_of(path)
	var best: float = INF
	var wired: Wiring = null
	for _n: int in 5:
		var began: int = Time.get_ticks_usec()
		wired = _read(bricks)
		best = minf(best, (Time.get_ticks_usec() - began) / 1000.0)
	var mirrored: int = 0
	for brick: BrickWorld.Brick in bricks:
		if brick.has_meta("mirrored") and wired.parts.has(brick.id):
			mirrored += 1
	print("\n== %s: %d parts, Wiring.read %.2f ms (best of 5); %d motors, %d sources, %d cables, %d loose, %d wiring parts mirrored"
		% [path.get_file(), bricks.size(), best, wired.motors.size(), wired.sources.size(), wired.cables.size(),
			wired.loose.size(), mirrored])
	wired.set_all("on")
	var counts: Dictionary = {"runs": 0, "by hand": 0, "stopped": 0}
	for motor: int in wired.motors:
		var power: Dictionary = wired.power_of(motor)
		var state: String = "by hand" if bool(power["by_hand"]) or not wired.has_power() else (
			"runs" if absf(float(power["run"])) > 1e-6 else "stopped")
		counts[state] = int(counts[state]) + 1
		print("   [%s] %s" % [state, wired.motor_line(motor)])
	print("   motors: %d run by their cables, %d turn by hand, %d stopped" % [counts["runs"], counts["by hand"],
		counts["stopped"]])
	# A motor stopped must be stopped by a real cable: drawn, its plug on
	# something or loose where a plug of it is.
	for motor: int in wired.motors:
		var power: Dictionary = wired.power_of(motor)
		if wired.has_power() and not bool(power["by_hand"]) and absf(float(power["run"])) < 1e-6:
			print("     stopped #%d: %s" % [motor, str(power["why"])])
	for cable: Dictionary in wired.cables:
		print("   cable %s: %s (%s)" % [str(cable["how"]), str(cable["ends"]), str(cable["path"])])
	for key: String in wired.loose:
		var point: Wiring.Point = wired.points[key]
		print("   loose %s (%s in %s): %s" % [key, wired.parts.get(point.brick, "?"),
			Assemblies.path_of(_find(bricks, point.brick)), wired.loose[key]])


static func _find(bricks: Array, id: int) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in bricks:
		if brick.id == id:
			return brick
	return null


static func _brick(id: int, part: String, at: Transform3D, unit: String = "") -> BrickWorld.Brick:
	var brick := BrickWorld.Brick.new(id, part, 0, at)
	if not unit.is_empty():
		brick.unit = unit
		brick.group = Assemblies.group_of(unit)
	return brick


## Where a plug goes on [param part]'s contacts [param index] (wires_probe's _plug_on).
static func _plug_on(part: String, at: Transform3D, index: int, turn: float = 0.0, lift: float = 0.0) -> Transform3D:
	var row: Array = (Wiring.CONTACTS[Wiring.SAME.get(part, part)] as Array)[index]
	var holder := BrickWorld.Brick.new(0, part, 0, at)
	var frame: Array = Wiring._frame(holder, row)
	var up: Vector3 = frame[2]
	var x: Vector3 = (frame[1] as Vector3).rotated(up, deg_to_rad(turn + (45.0 if str(row[0]) == "9v" else 0.0)))
	var raise: float = (Wiring.PLUG_UP if str(row[0]) != "pu" else 0.0) + lift
	return Transform3D(Basis(x, up, x.cross(up)), (frame[0] as Vector3) + up * raise)


static func _part_for_own_plug(part: String, plug: Transform3D, index: int = 0) -> Transform3D:
	var row: Array = (Wiring.OWN_PLUGS[part] as Array)[index]
	var local := BrickWorld.Brick.new(0, part, 0, Transform3D.IDENTITY)
	var frame: Array = Wiring._frame(local, row)
	var x: Vector3 = frame[1]
	var up: Vector3 = frame[2]
	var own := Transform3D(Basis(x, up, x.cross(up)), frame[0])
	return plug * own.affine_inverse()


func _say(what: String, wired: Wiring, motor: int) -> Dictionary:
	var power: Dictionary = wired.power_of(motor)
	print("   %s: wired=%s run=%s by_hand=%s | %s" % [what, str(power["wired"]), str(power["run"]),
		str(power["by_hand"]), wired.motor_line(motor)])
	return power


func _synthetic() -> void:
	print("\n== synthetic")
	var box_at := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	# S1. A sub-model holding an M motor (no cable), two beams, and the plug
	# of some other cable on the box: no cable piece, so no cable; the motor
	# turns by hand.
	var plug_at: Transform3D = _plug_on("58119", box_at, 0)
	var s1: Array = [_brick(1, "58119", box_at), _brick(2, "58120", Transform3D(Basis.IDENTITY, Vector3(300, 0, 0)), "Gearbox#1"),
		_brick(3, "58124c01", plug_at, "Gearbox#1"), _brick(4, "32524", Transform3D(Basis.IDENTITY, Vector3(300, 40, 0)), "Gearbox#1"),
		_brick(5, "32524", Transform3D(Basis.IDENTITY, Vector3(300, 80, 0)), "Gearbox#1")]
	var w1: Wiring = _read(s1)
	w1.set_to(1, "on")
	var p1: Dictionary = _say("S1 motor + an unrelated plug + 2 beams in one sub-model, plug on the box", w1, 2)
	_check("S1: no cable piece, no cable: it turns by hand", bool(p1["by_hand"]) and float(p1["run"]) == 0.0)
	# S2. A plug on the box in a sub-model with a 1x1 brick 4 LDU from a bare
	# motor's outlet: a brick is no cable piece.
	var motor_at := Transform3D(Basis.IDENTITY, Vector3(0, 0, 400))
	var outlet: Vector3 = motor_at * ((Wiring.OUTLETS["58120"][0] as Vector3) * LdrModel.FLIP)
	var s2: Array = [_brick(1, "58119", box_at), _brick(2, "58120", motor_at),
		_brick(3, "58124c01", plug_at, "Battery pack#1"),
		_brick(4, "3005", Transform3D(Basis.IDENTITY, outlet + Vector3(0, 4, 0)), "Battery pack#1")]
	var w2: Wiring = _read(s2)
	w2.set_to(1, "on")
	var p2: Dictionary = _say("S2 a plug on the box in a sub-model with a 1x1 brick 4 LDU from a bare motor's outlet", w2, 2)
	_check("S2: a brick near an outlet is no cable: it turns by hand", bool(p2["by_hand"]))
	# The same with a cable piece at the outlet: a laid cable, which runs.
	s2[3] = _brick(4, "u9190", Transform3D(Basis.IDENTITY, outlet + Vector3(0, 1, 0)), "Battery pack#1")
	var w2b: Wiring = _read(s2)
	w2b.set_to(1, "forward")
	var p2b: Dictionary = _say("S2b the same with a cable piece at the outlet", w2b, 2)
	_check("S2b: a cable piece at the outlet: laid, it runs", absf(float(p2b["run"])) > 0.5)
	# S3/N1. A motor's plug stacked on an IR receiver's own (input) plug on
	# the box: the box's power straight through; off, said as the box's.
	var receiver_at: Transform3D = _part_for_own_plug("58123c01", plug_at)
	var own_top: Transform3D = plug_at.translated_local(Vector3(0, Wiring.PLUG_UP, 0))
	var s3: Array = [_brick(1, "58119", box_at), _brick(5, "58123c01", receiver_at),
		_brick(2, "58120c01", _part_for_own_plug("58120c01", own_top))]
	var w3: Wiring = _read(s3)
	var p3: Dictionary = _say("S3 on the receiver's own plug's top, box off", w3, 2)
	_check("N1: off, said as the box's, not a receiver's output (%s)" % str(p3["why"]),
		str(p3["why"]).contains("battery box") and not str(p3["why"]).contains("output"))
	w3.set_to(1, "on")
	_check("S3: box on, it runs", absf(float(_say("S3 box on", w3, 2)["run"])) > 0.5)
	# S4/N1. A Powered Up plug turned half round in a hub's port.
	var hub_at := Transform3D(Basis.IDENTITY, Vector3(0, 0, 800))
	var port: Transform3D = _plug_on("22127", hub_at, 0, 180.0)
	var w4: Wiring = _read([_brick(7, "22127", hub_at), _brick(2, "22169c01", _part_for_own_plug("22169c01", port))])
	w4.set_to(7, "on")
	var p4: Dictionary = _say("S4 a PU plug turned half round in port 1", w4, 2)
	_check("N1: said turned half round, one way only (%s)" % str(p4["why"]),
		str(p4["why"]).contains("half round") and not str(p4["why"]).contains("quarter"))
	# S5. The receiver's own plug on the box turned half round: a receiver
	# runs its outputs the same whichever way its power comes.
	var half: Transform3D = _plug_on("58119", box_at, 0, 180.0)
	var receiver_half: Transform3D = _part_for_own_plug("58123c01", half)
	var w5: Wiring = _read([_brick(1, "58119", box_at), _brick(5, "58123c01", receiver_half),
		_brick(2, "58120c01", _part_for_own_plug("58120c01", _plug_on("58123c01", receiver_half, 0)))])
	w5.set_to(1, "on")
	w5.set_to(5, "forward", 0)
	_check("S5: red lever forward, it runs forward",
		is_equal_approx(float(_say("S5 receiver's own plug half round on the box", w5, 2)["run"]), 1.0))
	# F2: a motor whose own plug is on nothing turns by hand; one whose own
	# plug is on the box and then pulled stops, said.
	var w6: Wiring = _read([_brick(1, "58119", box_at),
		_brick(2, "58120c01", Transform3D(Basis.IDENTITY, Vector3(500, 0, 500)))])
	w6.set_all("on")
	_check("F2: an own plug on nothing: by hand, said (%s)" % str(w6.power_of(2)["why"]),
		bool(w6.power_of(2)["by_hand"]))
	# F2: LSynth's run in the motor's own sub-model (8258).
	var lsynth: Array = [_brick(1, "58119", box_at), _brick(2, "58120", Transform3D(Basis.IDENTITY, Vector3(200, 0, 0)), "8258 - Motor.ldr#1"),
		_brick(3, "58124c01", plug_at, "8258 - Motor.ldr#1"),
		_brick(4, "8258 - LS70.dat", Transform3D(Basis.IDENTITY, Vector3(100, 10, 0)), "8258 - Motor.ldr#1"),
		_brick(5, "2780", Transform3D(Basis.IDENTITY, Vector3(220, 20, 0)), "8258 - Motor.ldr#1")]
	var w7: Wiring = _read(lsynth)
	w7.set_to(1, "forward")
	_check("F2: an LSynth run beside the motor's own parts reads as its cable (%s)" % w7.motor_line(2),
		absf(float(w7.power_of(2)["run"])) > 0.5)
	_mirrored()
	_nine_volt()
	_laid_back()


## N3: the whole model mirrored reads the same as it stands.
func _mirrored() -> void:
	var box_at := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var mirror := Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)
	for turn: float in [0.0, 180.0]:
		var straight: Array = [_brick(1, "58119", box_at), _brick(2, "58120", Transform3D(Basis.IDENTITY, Vector3(200, 0, 0)), "cable#1"),
			_brick(3, "58124c01", _plug_on("58119", box_at, 0, turn), "cable#1"),
			_brick(4, "u9190", Transform3D(Basis.IDENTITY, Vector3(100, 20, 0)), "cable#1")]
		var mirrored: Array = straight.map(func(b: BrickWorld.Brick) -> BrickWorld.Brick:
			return _brick(b.id, b.part_id, mirror * b.transform, b.unit))
		var a: Wiring = _read(straight)
		var b: Wiring = _read(mirrored)
		a.set_to(1, "forward")
		b.set_to(1, "forward")
		_check("N3: mirrored, the plug turned %d°: runs the same (%s, %s)" % [int(turn), a.power_of(2)["run"],
			b.power_of(2)["run"]], float(a.power_of(2)["run"]) != 0.0
			and is_equal_approx(float(a.power_of(2)["run"]), float(b.power_of(2)["run"])))


## F5: 9 V. A 4760c01 box and a 9 V wire to a 71427's contacts, each of a
## plug's four quarter turns; 2838c01 under its own contacts' plug; a
## 58124c02 on 9 V contacts with a Power Functions plug on its top; and a
## 75652 whole wire from the box to the motor.
func _nine_volt() -> void:
	var box_at := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var motor_at := Transform3D(Basis.IDENTITY, Vector3(300, 0, 0))
	var runs: Array = []
	for turn: float in [0.0, 90.0, 180.0, 270.0]:
		var bricks: Array = [_brick(1, "4760c01", box_at), _brick(2, "71427", motor_at),
			_brick(3, "5306", _plug_on("4760c01", box_at, 0), "wire#1"),
			_brick(4, "5306", _plug_on("71427", motor_at, 0, turn), "wire#1"),
			_brick(5, "993", Transform3D(Basis.IDENTITY, Vector3(150, 30, 0)), "wire#1")]
		var wired: Wiring = _read(bricks)
		wired.set_to(1, "forward")
		runs.append(float(wired.power_of(2)["run"]))
		if turn == 0.0:
			_say("9V a wire box to motor, facing", wired, 2)
	_check("9 V: a plug on 9 V contacts runs at each quarter turn, two ways forward, two back (%s)" % str(runs),
		runs.all(func(r: float) -> bool: return absf(r) > 0.5) and runs.filter(func(r: float) -> bool: return r > 0.0).size() == 2)
	var box: Wiring = _read([_brick(1, "4760c01", box_at), _brick(2, "71427", motor_at)])
	box.set_all("on")
	_check("9 V: a motor with nothing on its contacts turns by hand (%s)" % str(box.power_of(2)["why"]),
		bool(box.power_of(2)["by_hand"]))
	_check("9 V: the box is a source, off/forward/back", box.sources.has(1)
		and (Wiring.SOURCES[box.sources[1]]["switch"] as Array).size() == 3)
	# 58124c02 on the 9 V box, a PF motor's own plug on its top.
	var adapter: Transform3D = _plug_on("4760c01", box_at, 0)
	var top: Transform3D = adapter.translated_local(Vector3(0, Wiring.PLUG_UP, 0))
	var mixed: Wiring = _read([_brick(1, "4760c01", box_at), _brick(6, "58124c02", adapter),
		_brick(7, "58120c01", _part_for_own_plug("58120c01", top))])
	mixed.set_to(1, "forward")
	_check("9 V: 58124c02 on 9 V contacts, a Power Functions plug on its top: runs (%s)"
		% mixed.motor_line(7), absf(float(mixed.power_of(7)["run"])) > 0.5)
	# 75652, a whole wire: one plug on the box, the other on the motor.
	var near: Transform3D = _plug_on("4760c01", box_at, 0)
	var wire_at: Transform3D = _part_for_own_plug("75652", near, 0)
	var wire := _brick(8, "75652", wire_at)
	var far: Array = Wiring._frame(wire, (Wiring.OWN_PLUGS["75652"] as Array)[1])
	print("   9V 75652's other plug stands at %s" % str(far[0]))
	var whole: Wiring = _read([_brick(1, "4760c01", box_at), wire])
	_check("9 V: 75652 is one wire of two plugs", whole.cables.any(func(c: Dictionary) -> bool:
		return str(c["how"]) == "its own" and (c["ends"] as Array).size() == 2))


## S6/F4/N5. A Power Functions cable laid as Flex lays one (an M motor's
## outlet to a box's contacts), its pieces read back as a reopen, an undo or
## MCP reads them: an item with two ends; and an LDCad extension wire's path.
func _laid_back() -> void:
	var box_at := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var motor_at := Transform3D(Basis.IDENTITY, Vector3(120, 0, 160))
	var probe: Wiring = _read([_brick(1, "58119", box_at), _brick(2, "58120", motor_at)])
	var contacts: Wiring.Point = probe.points["c:1:0"]
	var terminal: Wiring.Point = probe.points["t:2"]
	var on := Flex.Anchor.new()
	on.brick = 1
	on.kind = "contacts"
	on.at = contacts.at
	on.axis = contacts.up
	on.x = contacts.x
	var out := Flex.Anchor.new()
	out.brick = 2
	out.kind = "outlet"
	out.at = terminal.at
	out.axis = terminal.x
	var lengths: Array = Flex.lengths_between(null, "pf_cable", ["outlet", "contacts"])
	_check("S4: a motor's outlet offers its own cable's length only (%s)" % str(lengths.map(
		func(one: Dictionary) -> String: return str(one["id"]))), lengths.size() == 1
		and str(lengths[0]["id"]) == "pf20")
	_check("S3: outlet to outlet refused (%s)" % Flex.cable_ends_refusal("pf_cable", "outlet", "outlet"),
		not Flex.cable_ends_refusal("pf_cable", "outlet", "outlet").is_empty())
	_check("S3: contacts to contacts an extension wire (8886, 8871)",
		Flex.cable_ends_refusal("pf_cable", "contacts", "contacts").is_empty()
		and Flex.lengths_between(null, "pf_cable", ["contacts", "contacts"]).size() == 2)
	_check("S3: Powered Up has no extension wire (%s)" % Flex.cable_ends_refusal("pu_cable", "contacts", "contacts"),
		not Flex.cable_ends_refusal("pu_cable", "contacts", "contacts").is_empty())
	var laid: Flex.Laid = Flex.lay_swept("pf_cable", Flex.port_for("pf_cable", out, 1, 0),
		Flex.port_for("pf_cable", on, 1, 1), 500.0)
	var bricks: Array = [_brick(1, "58119", box_at), _brick(2, "58120", motor_at)]
	var parts: Array = []
	var pieces: Array = []
	var id: int = 10
	for piece: Dictionary in laid.pieces:
		bricks.append(_brick(id, str(piece["part"]), piece["at"], "Power Functions cable#1"))
		parts.append(str(piece["part"]))
		pieces.append({"part": str(piece["part"]), "at": piece["at"], "color": 0, "id": id})
		id += 1
	print("   S6 laid: %d pieces (%s), %.0f LDU, warnings %s" % [laid.pieces.size(),
		", ".join(PackedStringArray(parts.slice(parts.size() - 2))), laid.length, str(laid.warnings)])
	var wired: Wiring = _read(bricks)
	wired.set_to(1, "on")
	_check("S6: read as the motor's cable, it runs", absf(float(_say("S6 laid", wired, 2)["run"])) > 0.5)
	_check("F4: Flex.kind_of(its parts) = '%s'" % Flex.kind_of(parts), Flex.kind_of(parts) == "pf_cable")
	var ends: Array = Flex.ends_of_item("pf_cable", pieces)
	var tips_ok: bool = ends.size() == 2 and (ends[0] as Flex.Port).tip.distance_to(terminal.at) < 1.0
	_check("F4: two ends read off its pieces, the outlet's first at the outlet (%d ends)" % ends.size(), tips_ok)
	_check("F4: an item among the bricks (%s)" % str(Flex.items_among(bricks).keys()),
		Flex.items_among(bricks).has("Power Functions cable#1"))
	# N5: an LDCad Power Functions extension wire's path: two plugs and its skin.
	CustomParts.skins["wire-flex"] = "wire.ldr"
	_check("N5: an LDCad extension wire's path (two plugs and its skin) is a pf_cable item",
		Flex.kind_of(["58124c01", "58124c01", "wire-flex"]) == "pf_cable")
	_check("N5: a path of other parts is no cable", Flex.kind_of(["58124c01", "3005"]).is_empty())
	CustomParts.skins.erase("wire-flex")
