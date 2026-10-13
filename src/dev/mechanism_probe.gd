## Mechanisms, phase P1a: gear trains read off the parts and turned, through
## src/assembly/mechanism.gd (docs/MECHANISMS.md). Every case is checked
## against its tooth counts.
##
##   godot --headless --path . --script src/dev/mechanism_probe.gd   (no pictures)
##   godot --path . --resolution 1400x900 --script src/dev/mechanism_probe.gd
##
## What it turns:
##   - exact ratios where the lattice stands gears off their pitch: a worm
##     on a 28 tooth turntable 46 LDU off for 45 turns it 1/28, not 1/28.8,
##     and says it is 1 LDU loose; the turntable's base, resting on a plate
##     by its studs, is held with the plate; an 8 to a 40 and a 12 to a 36
##     three studs apart; a 20 to a 16 idler to a 20 on two stud diagonals
##     (44.72 for 45), the output turning exactly as the input;
##   - a real set, the windmill of LEGO® set 8020 (vendor/omr, tools/omr.py fetch): a
##     24 tooth gear drives an 8, whose axle's crown gear drives another 8
##     on the sails' axle, 9:1. Skipped, and said, without the file.
##   - an 8 driving a 24 on two axles in a beam;
##   - the same two axles also joined 16 to 16, which cannot turn;
##   - a worm driving a 24;
##   - a two-planet orrery: Earth's arm on the central axle, Mars's on a
##     turntable round it, both from one crank;
##   - a 12 inside a ring of four quarter rings (24121), carried round it:
##     the inner mesh, and a quarter's arc reaching only so far; and a
##     quarter held by nothing, turning on its rim;
##   - a chain from a 24 to an 8: the same way round, 3:1;
##   - a gearbox: a driving ring between two clutch gears, in neutral and
##     pushed into each;
##   - a differential (62821): two freedoms, and Willis's relation, the
##     sides' rates summing to twice the casing's, whatever drives it.
## With a display the windmill and the orrery are drawn turning
## (shots/mechanism/, frames and a WebP), the angles read back off the
## renderer's copy of the model. Real sets with the most gears are read by
## src/dev/mechanism_sets.gd.
extends SceneTree

const Z := Vector3(0, 0, 1)
const Y := Vector3(0, 1, 0)

var _failures: int = 0
var _library: PartLibrary


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_table()
	await _windmill()
	_eight_to_twenty_four()
	_locked()
	_worm()
	await _orrery()
	_ring()
	_chain()
	_gearbox()
	_differential()
	_exact()
	print("")
	if _failures == 0:
		print("mechanism: gear trains read off the parts, every ratio its tooth counts', a "
			+ "locked train named, a ring, a chain, a gearbox and a differential turned")
	else:
		print("mechanism: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## The parts of a hand-built case before they are read: what goes into
## Mechanism.build, and each part's colour for drawing it.
class Kit extends RefCounted:
	var library: PartLibrary
	var list: Array = []
	var colours: Dictionary = {}
	var held: Array = []

	func _init(from: PartLibrary) -> void:
		library = from

	func add(part_id: String, at: Transform3D, colour: int = 71) -> int:
		var key: int = list.size() + 1
		list.append({"key": key, "part": part_id, "at": at, "mesh": library.mesh_for(part_id)})
		colours[key] = colour
		return key

	## A beam 3 round each point given, its holes along [param way],
	## grounded: the bearings a hand-built train turns in.
	func bearings(points: Array, way: Vector3) -> void:
		for point: Vector3 in points:
			# 32523's holes run along its local y, its length along z.
			var basis := Basis.IDENTITY
			if way.is_equal_approx(Vector3(0, 0, 1)):
				basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
			elif way.is_equal_approx(Vector3.RIGHT):
				basis = Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
			held.append(add("32523", Transform3D(basis, point)))

	func build() -> Mechanism:
		return Mechanism.build(list, held)


# -- the cases ----------------------------------------------------------------


## The table is there, and the connector fixes are in the catalogue this
## run reads: without them the 24 tooth gears float.
func _table() -> void:
	print("  the gear table and the parts it names")
	var gears: Dictionary = Mechanism.table().get("gears", {})
	_check("the table reads, %d gears" % gears.size(), gears.size() > 50)
	var missing: PackedStringArray = []
	for id: String in gears:
		if not _library.parts.has(id):
			missing.append(id)
	_check("every gear in it is in the catalogue (%s)" % (", ".join(missing) if not missing.is_empty()
		else "all"), missing.is_empty())
	var unseated: PackedStringArray = []
	for id: String in gears:
		var mesh: Lbm.PartMesh = _library.mesh_for(id)
		var spec: Dictionary = gears[id]
		if mesh == null or str(spec.get("hole", "none")) == "none":
			continue
		var model := Mechanism.build([{"part": id, "at": Transform3D.IDENTITY, "mesh": mesh}])
		if not model.unseated.is_empty():
			unseated.append(id)
	_check("every gear with a hole has it on its axis in the catalogue's connectors (%s; a "
		% (", ".join(unseated) if not unseated.is_empty() else "all do") + "catalogue built "
		+ "before connectivity.py read them needs tools/merge_subbuild.py)", unseated.is_empty())


const WINDMILL := "res://vendor/omr/files/8020-1_Windmill.mpd"


func _windmill() -> void:
	print("  a real set: 8020's windmill (OMR)")
	if not FileAccess.file_exists(WINDMILL):
		print("    (no %s: tools/omr.py fetch brings the sets; skipped)" % WINDMILL)
		return
	var kit := Kit.new(_library)
	for placement: LdrModel.Placement in LdrModel.load_file(WINDMILL).flatten():
		kit.add(placement.part_id, placement.transform, placement.color_code)
	var model: Mechanism = kit.build()
	print("    %s" % model.summary())
	_check("57 parts read (%d)" % model.parts.size(), model.parts.size() == 57)
	var big: Mechanism.Gear = model.gears_of("3648a")[0]
	var crown: Mechanism.Gear = model.gears_of("3650a")[0]
	var sails: Mechanism.Gear = null
	for gear: Mechanism.Gear in model.gears_of("10928"):
		if gear.body != crown.body:
			sails = gear
	_check("two meshes: the 24 with an 8, and the crown at right angles with the other 8 (%s)"
		% model.couplings_said(), model.couplings.size() == 2)
	var result: Dictionary = model.solve({big.body: 1.0})
	print(model.describe())
	_check("it turns (%s)" % result["said"], result["ok"])
	var crank: float = model.spin(big.body, big.axis)
	var middle: float = model.spin(crown.body, crown.axis)
	if sails == null:
		_check("an 8 on the sails' axle", false)
		return
	var out: float = model.spin(sails.body, sails.axis)
	_check("the crown's axle turns 24/8 = 3 times the crank's, the other way (%.6f)" % (middle / crank),
		absf(middle / crank + 3.0) < 1e-6)
	_check("the sails' axle turns 3 x 3 = 9 times the crank's (%.6f)" % absf(out / crank),
		absf(absf(out / crank) - 9.0) < 1e-6)
	# The sails are 3709b plates threaded on their axle by round holes: free
	# to spin on it, so they follow it, as friction has them do.
	var sail_plate: int = model.first_key("3709b")
	_check("the sail plates go round with their axle (free on it, followed)",
		model.body_of(sail_plate) != model.ground and model.follows(sail_plate, sails.key))
	_check("the frame stays where it is (%d of its parts)" % (model.bodies[model.ground] as Array).size(),
		(model.bodies[model.ground] as Array).size() >= 30)
	_check("nothing with a gear in it floats (%d)" % model.floating_gears().size(),
		model.floating_gears().is_empty())
	var still: Dictionary = model.pose(0.0)
	var moved: int = 0
	for key: int in still:
		if not _near(still[key], model.rest[key]):
			moved += 1
	_check("at 0 nothing has moved (%d)" % moved, moved == 0)
	await _draw("windmill", model, kit.colours, 16, deg_to_rad(2.5), big.key,
		[[sails.key, 9.0, "the sails"]])


func _eight_to_twenty_four() -> void:
	print("  an 8 driving a 24")
	var kit := Kit.new(_library)
	kit.bearings([Vector3(0, 0, 0), Vector3(0, 40, 0)], Z)
	var axle_a: int = kit.add("3706", Transform3D(_turn_x_to(Z), Vector3(0, 0, 30)))
	kit.add("3706", Transform3D(_turn_x_to(Z), Vector3(0, 40, 30)))
	var small: int = kit.add("3647", Transform3D(Basis.IDENTITY, Vector3(0, 0, 50)))
	var large: int = kit.add("3648a", Transform3D(Basis.IDENTITY, Vector3(0, 40, 50)))
	var model: Mechanism = kit.build()
	print("    %s" % model.summary())
	var result: Dictionary = model.solve({model.body_of(axle_a): 1.0})
	print(model.describe())
	var a: Mechanism.Gear = model.gear_at(small)
	var b: Mechanism.Gear = model.gear_at(large)
	var ratio: float = model.spin(b.body, b.axis) / model.spin(a.body, a.axis)
	_check("one mesh, and it turns (%s; %s)" % [model.couplings_said(), result["said"]],
		model.couplings.size() == 1 and result["ok"])
	_check("the 24 turns a third as fast, the other way (%.6f)" % ratio, absf(ratio + 1.0 / 3.0) < 1e-5)


func _locked() -> void:
	print("  the same two axles, also joined 16 to 16")
	var kit := Kit.new(_library)
	kit.bearings([Vector3(0, 0, 0), Vector3(0, 40, 0)], Z)
	var axle_a: int = kit.add("3706", Transform3D(_turn_x_to(Z), Vector3(0, 0, 30)))
	kit.add("3706", Transform3D(_turn_x_to(Z), Vector3(0, 40, 30)))
	kit.add("3647", Transform3D(Basis.IDENTITY, Vector3(0, 0, 50)))
	kit.add("3648a", Transform3D(Basis.IDENTITY, Vector3(0, 40, 50)))
	kit.add("94925", Transform3D(Basis.IDENTITY, Vector3(0, 0, 75)))
	kit.add("94925", Transform3D(Basis.IDENTITY, Vector3(0, 40, 75)))
	var model: Mechanism = kit.build()
	print("    %s" % model.summary())
	var result: Dictionary = model.solve({model.body_of(axle_a): 1.0})
	print(model.describe())
	_check("two meshes, 3:1 and 1:1 between the same two axles (%s)" % model.couplings_said(),
		model.couplings.size() == 2)
	_check("it is locked, and says so (%s)" % result["said"], not result["ok"] and result["locked"])
	_check("...naming both meshes as the ones that fight (%s)" % str(result["culprits"]),
		(result["culprits"] as Array).size() == 2)


func _worm() -> void:
	print("  a worm driving a 24")
	var kit := Kit.new(_library)
	# The worm's axle along x through two beams, the 24's along z below it.
	kit.bearings([Vector3(-40, 0, 0), Vector3(40, 0, 0)], Vector3.RIGHT)
	kit.bearings([Vector3(0, -40, -30)], Z)
	var worm_axle: int = kit.add("3706", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)))
	kit.add("3705", Transform3D(_turn_x_to(Z), Vector3(0, -40, -20)))
	# 4716's axis is its local z: turned to run along x.
	var worm: int = kit.add("4716", Transform3D(_turn_z_to(Vector3.RIGHT), Vector3.ZERO))
	var wheel: int = kit.add("3648a", Transform3D(Basis.IDENTITY, Vector3(0, -40, 0)))
	var model: Mechanism = kit.build()
	print("    %s" % model.summary())
	var result: Dictionary = model.solve({model.body_of(worm_axle): 1.0})
	print(model.describe())
	var w: Mechanism.Gear = model.gear_at(worm)
	var g: Mechanism.Gear = model.gear_at(wheel)
	var ratio: float = model.spin(g.body, g.axis) / model.spin(w.body, w.axis)
	_check("one mesh, a worm's, and it turns (%s; %s)" % [model.couplings_said(), result["said"]],
		model.couplings.size() == 1 and result["ok"])
	_check("the 24 turns once for 24 turns of the worm (1/%.4f)" % (1.0 / absf(ratio)),
		absf(absf(ratio) - 1.0 / 24.0) < 1e-5)


## Mars goes round once for every 1.8808 of Earth's: NASA's sidereal
## periods, 686.98 and 365.256 days.
const MARS_YEARS := 686.98 / 365.256


func _orrery() -> void:
	print("  a two-planet orrery: Earth on the central axle, Mars on a turntable, one crank")
	var kit := Kit.new(_library)
	# The frame: a beam lying flat, its holes up, and the turntable's base on
	# it (held to the frame in the real thing; said so here).
	var frame: int = kit.add("32524", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 71)
	var base: int = kit.add("99009", Transform3D(Basis.IDENTITY, Vector3(0, 39, 0)), 72)
	kit.held = [frame, base]
	var up := _turn_z_to(Y)
	# The central axle, Earth's: a 20 below the beam, Earth's arm and the sun on top.
	kit.add("3707", Transform3D(_turn_x_to(Y), Vector3(0, 40, 0)), 71)
	kit.add("32269", Transform3D(up, Vector3(0, -20, 0)), 72)
	var earth_arm: int = kit.add("6632", Transform3D(Basis.IDENTITY, Vector3(0, 80, 0)), 1)
	kit.add("3704", Transform3D(_turn_x_to(Y), Vector3(0, 100, -40)), 0)
	var earth: int = kit.add("3941", Transform3D(Basis.IDENTITY, Vector3(0, 114, -40)), 1)
	kit.add("3941", Transform3D(Basis.IDENTITY, Vector3(0, 118, 0)), 14)
	# The crank's axle, three studs off: a 28 meshing the 20 below, a 20 the
	# turntable's 28 above. It stops short of Mars's arm, which sweeps over it.
	var crank: int = kit.add("3706", Transform3D(_turn_x_to(Y), Vector3(0, -11, 60)), 71)
	kit.add("46372", Transform3D(up, Vector3(0, -20, 60)), 72)
	kit.add("32269", Transform3D(up, Vector3(0, 39, 60)), 72)
	# Mars's arm: the turntable's top, a beam pinned across it.
	var top: int = kit.add("99010", Transform3D(Basis.IDENTITY, Vector3(0, 39, 0)), 72)
	var across := Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
	var mars_arm: int = kit.add("32524", Transform3D(across, Vector3(0, 59, 30)), 4)
	var along_z := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	kit.add("2780", Transform3D(along_z, Vector3(20, 59, 20)), 0)
	kit.add("2780", Transform3D(along_z, Vector3(-20, 59, 20)), 0)
	var model: Mechanism = kit.build()
	print("    %s" % model.summary())
	_check("two meshes: 20 with 28 below, 20 with the turntable's 28 above (%s)"
		% model.couplings_said(), model.couplings.size() == 2)
	var result: Dictionary = model.solve({model.body_of(crank): 1.0})
	print(model.describe())
	_check("it turns from the crank (%s)" % result["said"], result["ok"])
	var turn: float = model.spin(model.body_of(crank), Y)
	var earth_rate: float = model.spin(model.body_of(earth_arm), Y) / turn
	var mars_rate: float = model.spin(model.body_of(mars_arm), Y) / turn
	_check("Earth's arm turns 28/20 = 1.4 times the crank, the other way (%.6f)" % earth_rate,
		absf(earth_rate + 1.4) < 1e-5)
	_check("Mars's arm turns 20/28 of the crank, the other way: round the sun as Earth goes (%.6f)"
		% mars_rate, absf(mars_rate + 20.0 / 28.0) < 1e-5)
	var years: float = earth_rate / mars_rate
	var error: float = (years / MARS_YEARS - 1.0) * 100.0
	_check("a Mars year is %.4f Earth years here, against 1.8808: %+.1f%%, (28/20)^2 the nearest "
		% [years, error] + "two meshes of these gears give", absf(years - 1.96) < 1e-5 and absf(error) < 5.0)
	_check("Earth rides its arm, the arm's pins hold Mars's beam to the turntable",
		model.body_of(earth) == model.body_of(earth_arm) and model.body_of(mars_arm) == model.body_of(top))
	_check("the frame and the turntable's base stay (%s)" % ("yes" if model.body_of(base) == model.ground else "no"),
		model.body_of(base) == model.ground and model.body_of(frame) == model.ground)
	# One Earth year is 1/1.4 of a crank turn; draw two of them.
	await _draw("orrery", model, kit.colours, 24, TAU / 1.4 * 2.0 / 24.0, crank,
		[[earth_arm, 1.4, "Earth's arm"], [mars_arm, 20.0 / 28.0, "Mars's arm"]])


## The four quarter rings stand still, a 12 tooth double bevel inside them
## on an arm that goes round their middle. The 12's teeth roll round the
## 140 inside: relative to its arm it turns 140/12 the other way, and in
## all (140 - 12)/12. With one quarter only, on the far side, it meshes
## with nothing.
func _ring() -> void:
	print("  a 12 carried round inside four quarter rings of 35 (140 in all)")
	for whole: bool in [true, false]:
		var kit := Kit.new(_library)
		var frame: int = kit.add("32525", Transform3D(Basis.IDENTITY, Vector3(0, -40, 0)))
		kit.held = [frame]
		for n: int in (4 if whole else 1):
			# A quarter's teeth go round its own -x -z corner: turned 5/8 of a
			# turn, the first one's arc is centred on +x, where the arm is. The
			# lone one is turned half round from there, to -x.
			var turn: float = PI * 1.25 + PI * 0.5 * float(n) if whole else PI * 0.25
			kit.held.append(kit.add("24121", Transform3D(Basis(Y, turn), Vector3(0, 0, 0)), 14))
		# The arm: a beam 9 from the middle out along +x, turning on the
		# central axle, which turns in the frame.
		var along_x := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))
		var arm: int = kit.add("40490", Transform3D(along_x, Vector3(80, 30, 0)), 4)
		var centre: int = kit.add("3706", Transform3D(_turn_x_to(Y), Vector3(0, 0, 0)))
		# The 12 at 175 - 15 = 160 out, on an axle through the arm's end.
		kit.add("3705", Transform3D(_turn_x_to(Y), Vector3(160, 10, 0)))
		var pinion: int = kit.add("32270", Transform3D(_turn_z_to(Y), Vector3(160, 0, 0)), 72)
		var model: Mechanism = kit.build()
		print("    %s" % model.summary())
		var result: Dictionary = model.solve({model.body_of(arm): 1.0})
		var gear: Mechanism.Gear = model.gear_at(pinion)
		if whole:
			print(model.describe())
			_check("one mesh, on the ring's inside (%s; %s)" % [model.couplings_said(), result["said"]],
				model.couplings.size() == 1 and model.couplings[0].how == "ring" and result["ok"])
			var relative: float = model.joint_of(gear.body).rate if model.joint_of(gear.body) != null \
				else 0.0
			var whole_rate: float = model.spin(gear.body, Y) / model.spin(model.body_of(arm), Y)
			_check("on its arm the 12 turns 140/12 = 11.6667 times the arm, the other way (%.6f)"
				% relative, absf(relative + 140.0 / 12.0) < 1e-5)
			_check("in all it turns (140 - 12)/12 = 10.6667 times the arm, the other way (%.6f)"
				% whole_rate, absf(whole_rate + 128.0 / 12.0) < 1e-5)
			# Nothing decides whether the arm turns on its axle or the axle with
			# the arm; the one nearer the ground is the one left still.
			var axle: int = model.body_of(centre)
			_check("the central axle, which nothing turns, stays still under its arm (%.6f)"
				% model.spin(axle, Y), absf(model.spin(axle, Y)) < 1e-9)
		else:
			_check("one quarter on the far side: no mesh (%s), and the 12 is left free (%s)"
				% [model.couplings_said(), result["said"]], model.couplings.is_empty()
				and (result["free"] as Array).has(gear.body))
	# A quarter held by nothing, the 12 on an axle in a beam: carried round
	# its rim as 42055's bucket wheel is, it turns about its own centre,
	# 12/140 of the 12 and the same way.
	var kit := Kit.new(_library)
	kit.bearings([Vector3(160, 30, 0)], Y)
	var drive: int = kit.add("3705", Transform3D(_turn_x_to(Y), Vector3(160, 10, 0)))
	kit.add("32270", Transform3D(_turn_z_to(Y), Vector3(160, 0, 0)), 72)
	var loose: int = kit.add("24121", Transform3D(Basis(Y, PI * 1.25), Vector3.ZERO), 14)
	var model: Mechanism = kit.build()
	var result: Dictionary = model.solve({model.body_of(drive): 1.0})
	var joint: Mechanism.Joint = model.joint_of(model.body_of(loose))
	var ratio: float = model.spin(model.body_of(loose), Y) / model.spin(model.body_of(drive), Y)
	_check("a quarter held by nothing turns on its rim about its centre, 12/140 = 0.085714 of the "
		+ "12 and the same way (%.6f; %s)" % [ratio, result["said"]], joint != null
		and joint.what == "rim" and absf(ratio - 12.0 / 140.0) < 1e-6)


## A chain laid round a 24 and an 8 by Flex, as the flex tool lays one: the
## 8 turns three times for each turn of the 24, the same way round.
func _chain() -> void:
	print("  a chain from a 24 to an 8")
	var kit := Kit.new(_library)
	kit.bearings([Vector3(0, 0, -20), Vector3(120, 0, -20)], Z)
	var drive: int = kit.add("3705", Transform3D(_turn_x_to(Z), Vector3(0, 0, 0)))
	kit.add("3705", Transform3D(_turn_x_to(Z), Vector3(120, 0, 0)))
	var big: int = kit.add("3648a", Transform3D(Basis.IDENTITY, Vector3(0, 0, 10)), 72)
	var small: int = kit.add("3647", Transform3D(Basis.IDENTITY, Vector3(120, 0, 10)), 72)
	var sprockets: Array = []
	for one: Array in [[big, Vector3(0, 0, 10), 12], [small, Vector3(120, 0, 10), 4]]:
		var sprocket := Flex.Sprocket.new()
		sprocket.brick = one[0]
		sprocket.centre = one[1]
		sprocket.axis = Z
		sprocket.links = one[2]
		sprocket.radius = Flex.CHAIN_PITCH * 0.5 / sin(PI / float(sprocket.links))
		sprockets.append(sprocket)
	var laid: Flex.Laid = Flex.lay_chain("chain", sprockets)
	for piece: Dictionary in laid.pieces:
		kit.add(str(piece["part"]), piece["at"], 0)
	var model: Mechanism = kit.build()
	print("    %s; %d links" % [model.summary(), laid.pieces.size()])
	var result: Dictionary = model.solve({model.body_of(drive): 1.0})
	var a: Mechanism.Gear = model.gear_at(big)
	var b: Mechanism.Gear = model.gear_at(small)
	_check("one chain on two sprockets (%d links), and it turns (%s; %s)" % [laid.pieces.size(),
		model.couplings_said(), result["said"]], model.chains.size() == 1
		and model.chains[0].sprockets.size() == 2 and model.couplings.size() == 1 and result["ok"])
	var ratio: float = model.spin(b.body, Z) / model.spin(a.body, Z)
	_check("the 8 turns 12/4 = 3 times the 24, the same way (%.6f)" % ratio, absf(ratio - 3.0) < 1e-5)


## Two clutch gears on one axle, turning on it, a driving ring on a ridged
## joiner keyed between them: a 24 meshing an 8 below, a 16 meshing a 16.
## The ring in the middle drives neither; pushed into one, it drives
## that one.
func _gearbox() -> void:
	print("  a gearbox: a driving ring between a 24 and a 16 with clutches")
	for shift: float in [0.0, 10.0, -10.0]:
		var kit := Kit.new(_library)
		kit.bearings([Vector3(0, 0, -70), Vector3(0, 0, 70), Vector3(0, 40, -70),
			Vector3(0, 40, 70)], Z)
		var input: int = kit.add("3708", Transform3D(_turn_x_to(Z), Vector3(0, 0, 0)))
		kit.add("3708", Transform3D(_turn_x_to(Z), Vector3(0, 40, 0)))
		kit.add("2471", Transform3D(Basis.IDENTITY, Vector3(0, 0, -40)), 72)
		kit.add("18946", Transform3D(Basis.IDENTITY, Vector3(0, 0, 40)), 72)
		kit.add("18948", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 0)
		var ring: int = kit.add("18947", Transform3D(Basis.IDENTITY, Vector3(0, 0, shift)), 71)
		var low: int = kit.add("3647", Transform3D(Basis.IDENTITY, Vector3(0, 40, -40)), 72)
		kit.add("94925", Transform3D(Basis.IDENTITY, Vector3(0, 40, 40)), 72)
		var model: Mechanism = kit.build()
		var result: Dictionary = model.solve({model.body_of(input): 1.0})
		var out: Mechanism.Gear = model.gear_at(low)
		var rate: float = model.spin(out.body, Z)
		var driven: int = int(model.shifts[0][1]) if not model.shifts.is_empty() else -1
		var said: String = "%s; %s; the output %.6f" % [model.couplings_said(), result["said"], rate]
		if shift == 0.0:
			print("    %s" % model.summary())
			_check("in the middle the ring drives neither gear, and the output is free (%s)" % said,
				driven == 0 and result["ok"] and (result["free"] as Array).has(out.body))
		elif shift > 0.0:
			_check("pushed into the 16, the output turns 16/16 = 1 the other way (%s)" % said,
				driven != 0 and (model.parts[driven] as Mechanism.Piece).part == "18946"
				and absf(rate + 1.0) < 1e-6 and model.body_of(ring) == model.body_of(input)
				and not (result["free"] as Array).has(out.body))
		else:
			_check("pushed into the 24, the output turns 24/8 = 3 the other way (%s)" % said,
				driven != 0 and (model.parts[driven] as Mechanism.Piece).part == "2471"
				and absf(rate + 3.0) < 1e-6)


## A 62821 differential as 42082 has one: its casing turning on the two
## half axles, a 6589 on each, one planet on the casing's stub, and a 20
## double bevel driving the casing's 28. Two freedoms: one driver leaves
## one free. Whatever drives it, Willis's relation holds: the sides' rates
## sum to twice the casing's.
func _differential() -> void:
	print("  a differential (62821), its two freedoms and Willis's relation")
	var kit := Kit.new(_library)
	kit.bearings([Vector3(0, 0, -60), Vector3(0, 0, 60)], Z)
	kit.bearings([Vector3(0, -80, 0)], Y)
	var casing: int = kit.add("62821", Transform3D.IDENTITY, 0)
	var left: int = kit.add("4519", Transform3D(_turn_x_to(Z), Vector3(0, 0, 40)))
	var right: int = kit.add("4519", Transform3D(_turn_x_to(Z), Vector3(0, 0, -40)))
	kit.add("6589", Transform3D(Basis.IDENTITY, Vector3(0, 0, 17)), 19)
	kit.add("6589", Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)),
		Vector3(0, 0, -17)), 19)
	var planet: int = kit.add("6589", Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0),
		Vector3(0, 1, 0)), Vector3(0, 17, 0)), 19)
	var pinion_axle: int = kit.add("4519", Transform3D(_turn_x_to(Y), Vector3(0, -60, 0)))
	kit.add("18575", Transform3D(Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0)),
		Vector3(0, -40, 0)), 72)
	var model: Mechanism = kit.build()
	print("    %s" % model.summary())
	print(model.describe())
	_check("three meshes: the planet with each side, the pinion with the casing (%s)"
		% model.couplings_said(), model.couplings.size() == 3
		and model.couplings_said().count("right angle") == 3)
	var c: int = model.body_of(casing)
	var l: int = model.body_of(left)
	var r: int = model.body_of(right)
	var p: int = model.body_of(pinion_axle)
	_check("the planet turns on the casing's stub (%s)" % model.parts_said(model.body_of(planet)),
		model.joint_of(model.body_of(planet)) != null
		and model.joint_of(model.body_of(planet)).what == "stub")
	var one: Dictionary = model.solve({p: 1.0})
	_check("one driver leaves one freedom, the sides and the planet undecided (%s)" % one["said"],
		one["ok"] and int(one["freedoms"]) == 1 and (one["free"] as Array).has(l)
		and (one["free"] as Array).has(r) and not (one["free"] as Array).has(c))
	var casing_rate: float = model.spin(c, Z)
	_check("the pinion turns the casing 20/28 of a turn (%.6f)" % casing_rate,
		absf(absf(casing_rate) - 20.0 / 28.0) < 1e-6)
	var worst: float = 0.0
	var said: PackedStringArray = []
	for drive: Array in [[p, 1.0, l, 0.0], [l, 1.0, r, 1.0], [l, 1.0, r, -1.0], [l, 0.3, r, 2.0],
			[p, 1.0, r, 0.5]]:
		var both: Dictionary = model.solve({int(drive[0]): float(drive[1]), int(drive[2]): float(drive[3])})
		if not both["ok"] or not (both["free"] as Array).is_empty():
			worst = INF
			said.append("(%s)" % both["said"])
			continue
		var sides: float = model.spin(l, Z) + model.spin(r, Z)
		var twice: float = 2.0 * model.spin(c, Z)
		worst = maxf(worst, absf(sides - twice))
		said.append("%.3f + %.3f = 2 x %.3f" % [model.spin(l, Z), model.spin(r, Z), model.spin(c, Z)])
	# To a millionth: the parts stand where 32-bit transforms put them, so
	# a lever arm of 17 LDU is 17.000001.
	_check("two drivers decide it, and the sides sum to twice the casing every time, to %s (%s)"
		% [str(worst), "; ".join(said)], worst < 1e-6)
	var held: Dictionary = model.solve({p: 1.0, l: 0.0})
	_check("one side held, the other turns twice the casing (%.6f, %.6f)" % [model.spin(r, Z),
		model.spin(c, Z)], held["ok"] and absf(model.spin(r, Z) - 2.0 * model.spin(c, Z)) < 1e-6
		and absf(model.spin(r, Z)) > 0.1)


## The ratio is the teeth's however far within the slack the lattice stands
## two gears off their pitch, and a mesh further off than real sets stand
## theirs is said to be. Read at one gear's pitch circle, as it was, the
## worm turned the 28 once in 28.8 and the idler train's output 1.0257 for
## 1; every check below but the 8 to the 40 and the 12 to the 36, which
## stand at their pitch, fails on that.
func _exact() -> void:
	print("  exact ratios where the 2 LDU lattice stands gears off their pitch")
	# A worm along x into the 28 teeth of a turntable whose base rests on a
	# 6 x 10 plate's studs: 46 LDU off the turntable's axis, for the worm's
	# 10 and the top's 35. Only the worm's bearings and the plate are held.
	var kit := Kit.new(_library)
	var plate: int = kit.add("3033", Transform3D.IDENTITY, 72)
	var foot: float = _stud_foot("3033")
	var base_mesh: Lbm.PartMesh = _library.mesh_for("99009")
	var level: float = foot - base_mesh.bounds.position.y
	var base: int = kit.add("99009", Transform3D(Basis.IDENTITY, Vector3(0, level, 0)), 0)
	var top: int = kit.add("99010", Transform3D(Basis.IDENTITY, Vector3(0, level, 0)), 71)
	kit.held = [plate]
	kit.bearings([Vector3(-40, level, 46), Vector3(40, level, 46)], Vector3.RIGHT)
	var axle: int = kit.add("3706", Transform3D(Basis.IDENTITY, Vector3(0, level, 46)))
	var worm: int = kit.add("4716", Transform3D(_turn_z_to(Vector3.RIGHT), Vector3(0, level, 46)))
	var model: Mechanism = kit.build()
	print("    %s" % model.summary())
	_check("the turntable's base, resting on the plate's studs, is held with it (%s)"
		% model.parts_said(model.body_of(base)), model.body_of(base) == model.ground)
	var result: Dictionary = model.solve({model.body_of(axle): 1.0})
	var w: Mechanism.Gear = model.gear_at(worm)
	var ratio: float = model.spin(model.body_of(top), Y) / model.spin(w.body, w.axis)
	_check("a worm 46 LDU off a 28 tooth turntable turns it once in 28 turns, exactly "
		+ "(1/%.6f; %s)" % [1.0 / absf(ratio) if ratio != 0.0 else INF, result["said"]],
		result["ok"] and absf(absf(ratio) - 1.0 / 28.0) < 1e-6)
	var off: Array[Mechanism.Coupling] = model.off_spacing()
	_check("...and says it stands off its spacing (%s)" % (off[0].off_said() if not off.is_empty()
		else "nothing said"), off.size() == 1 and off[0].off_said() == "46 LDU apart for 45, 1 LDU loose")
	var bricks: Array = []
	for entry: Dictionary in kit.list:
		bricks.append(BrickWorld.Brick.new(int(entry["key"]), str(entry["part"]), 71, entry["at"]))
	var held: Dictionary = {}
	for key: int in kit.held:
		held[key] = true
	var read: Simulation = Simulation.read(bricks, _library, held)
	read.drive(read.model.body_of(axle))
	var trouble: String = "\n".join(read.trouble_lines())
	_check("...in what Simulate and simulate_mechanism say: %s" % trouble.replace("\n", " | "),
		trouble.contains("Off their spacing") and trouble.contains("46 LDU apart for 45, 1 LDU loose")
		and not trouble.contains("Floating"))

	# An 8 to a 40 and a 12 to a 36, each three studs apart: 1/5 and 1/3.
	for pair: Array in [["3647", "3649", 1.0 / 5.0], ["69778", "32498", 1.0 / 3.0]]:
		kit = Kit.new(_library)
		kit.bearings([Vector3(0, 0, 0), Vector3(60, 0, 0)], Z)
		var input: int = kit.add("3706", Transform3D(_turn_x_to(Z), Vector3(0, 0, 30)))
		kit.add("3706", Transform3D(_turn_x_to(Z), Vector3(60, 0, 30)))
		var small: int = kit.add(str(pair[0]), Transform3D(Basis.IDENTITY, Vector3(0, 0, 50)))
		var large: int = kit.add(str(pair[1]), Transform3D(Basis.IDENTITY, Vector3(60, 0, 50)))
		model = kit.build()
		result = model.solve({model.body_of(input): 1.0})
		ratio = model.spin(model.gear_at(large).body, Z) / model.spin(model.gear_at(small).body, Z)
		_check("%s to %s three studs apart: %.6f, -%s" % [model.gear_at(small).teeth,
			model.gear_at(large).teeth, ratio, Simulation.figure(float(pair[2]))],
			result["ok"] and absf(ratio + float(pair[2])) < 1e-6 and model.off_spacing().is_empty())

	# The idler train on two stud diagonals: a 20, a 16 two studs along and
	# one up from it (44.72 for 45), a 20 two along and one down again.
	kit = Kit.new(_library)
	var spots: Array = [Vector3(0, 0, 0), Vector3(40, 20, 0), Vector3(80, 0, 0)]
	kit.bearings(spots, Z)
	var axles: Array[int] = []
	for spot: Vector3 in spots:
		axles.append(kit.add("3706", Transform3D(_turn_x_to(Z), spot + Vector3(0, 0, 30))))
	var first: int = kit.add("69779", Transform3D(Basis.IDENTITY, spots[0] + Vector3(0, 0, 50)))
	var idler: int = kit.add("4019", Transform3D(Basis.IDENTITY, spots[1] + Vector3(0, 0, 50)))
	var last: int = kit.add("69779", Transform3D(Basis.IDENTITY, spots[2] + Vector3(0, 0, 50)))
	model = kit.build()
	result = model.solve({model.body_of(axles[0]): 1.0})
	var turn: float = model.spin(model.gear_at(first).body, Z)
	var through: float = model.spin(model.gear_at(idler).body, Z) / turn
	ratio = model.spin(model.gear_at(last).body, Z) / turn
	_check("a 20 to a 16 idler to a 20 on two stud diagonals: the idler %.6f (-20/16), the "
		% through + "output %.6f, as the input (%s)" % [ratio, model.couplings_said()],
		result["ok"] and model.couplings.size() == 2 and absf(through + 1.25) < 1e-6
		and absf(ratio - 1.0) < 1e-6)
	_check("...and a stud's diagonal, 0.28 LDU short, is not said to be off its spacing",
		model.off_spacing().is_empty())


## Where a part's studs stand on it, along its up: their foot.
func _stud_foot(part_id: String) -> float:
	for connector: Lbm.Connector in _library.mesh_for(part_id).connectors:
		if connector.kind == "stud" and connector.gender == "male":
			return connector.position.y
	return _library.mesh_for(part_id).bounds.end.y


# -- drawing it ---------------------------------------------------------------


## Draw [param frames] frames, the driver turned [param step] radians a
## frame, and read back off the renderer's copy that each of [param outputs]
## ([key, ratio, words]) turns ratio times as far a frame as [param input]
## (in size: the sign of a mesh at right angles depends on which way round
## its axes are read).
func _draw(name: String, model: Mechanism, colours: Dictionary, frames: int, step: float,
		input: int, outputs: Array) -> void:
	if not StudioRender.possible():
		print("    (headless: nothing drawn)")
		return
	var world := BrickWorld.new()
	world.library = _library
	root.add_child(world)
	var ids: Dictionary = {}   ## key -> brick id
	for key: int in model.parts:
		var piece: Mechanism.Piece = model.parts[key]
		ids[key] = world.add_brick(piece.part, int(colours.get(key, 71)), piece.at)
	await process_frame
	var renderer := StudioRender.new()
	root.add_child(renderer)
	renderer.library = _library
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = Vector2i(480, 360)
	settings.contact_shadow = false
	settings.view = "hero"
	var poses: Array = []
	for n: int in frames:
		var placed: Dictionary = model.pose(step * float(n))
		var by_id: Dictionary = {}
		for key: int in placed:
			by_id[ids[key]] = placed[key]
		poses.append(by_id)
	var box := AABB()
	var first: bool = true
	for placed: Dictionary in poses:
		for brick_id: int in placed:
			var part: Lbm.PartMesh = _library.mesh_for(world.get_brick(brick_id).part_id)
			if part == null:
				continue
			var here: AABB = ((placed[brick_id] as Transform3D) * part.bounds).abs()
			box = here if first else box.merge(here)
			first = false
	var watched: Array = [[input, 1.0, "the driver"]]
	watched.append_array(outputs)
	var seen: Array = []   ## per frame, each watched part's angle about its axis
	var pictures: Array = []
	var done: int = await renderer.animate(world, settings, frames,
		func(n: int) -> Dictionary: return poses[n],
		func(_n: int) -> float: return 0.0, box,
		func(_n: int, image: Image) -> void:
			var angles: Array = []
			for one: Array in watched:
				var key: int = one[0]
				var turned: Basis = renderer.staged_transform(ids[key]).basis \
					* (model.rest[key] as Transform3D).basis.inverse()
				angles.append(_about(turned, model.joint_axis(model.body_of(key))))
			seen.append(angles)
			pictures.append(image))
	_check("%s: every frame drawn (%d of %d)" % [name, done, frames], done == frames)
	for w: int in range(1, watched.size()):
		var worst: float = 0.0
		for n: int in range(1, seen.size()):
			var a: float = wrapf(float(seen[n][0]) - float(seen[n - 1][0]), -180.0, 180.0)
			var b: float = wrapf(float(seen[n][w]) - float(seen[n - 1][w]), -180.0, 180.0)
			worst = maxf(worst, absf(absf(b) - absf(a) * float(watched[w][1])))
		_check("%s: in every frame drawn %s turns %.4f times the driver's step, to %.4f°"
			% [name, watched[w][2], float(watched[w][1]), worst], seen.size() == frames and worst < 0.01)
	if pictures.size() > 1:
		_check("%s: the pictures change as it turns (%.4f)" % [name, _difference(pictures[0], pictures[1])],
			_difference(pictures[0], pictures[1]) > 0.0005)
	var folder: String = ProjectSettings.globalize_path("res://shots/mechanism")
	DirAccess.make_dir_recursive_absolute(folder)
	var webp := AnimatedWebP.new(8)
	for n: int in pictures.size():
		(pictures[n] as Image).save_png(folder.path_join("%s_%02d.png" % [name, n]))
		webp.add(pictures[n])
	var file: FileAccess = FileAccess.open(folder.path_join("%s.webp" % name), FileAccess.WRITE)
	if file != null:
		file.store_buffer(webp.bytes())
		file.close()
	print("    pictures: shots/mechanism/%s_00..%02d.png and %s.webp" % [name, pictures.size() - 1, name])
	renderer.queue_free()
	world.queue_free()
	await process_frame


# -- fixtures ------------------------------------------------------------------


## A turn taking local x (an axle's length) to [param way].
static func _turn_x_to(way: Vector3) -> Basis:
	if way.is_equal_approx(Vector3.RIGHT):
		return Basis.IDENTITY
	if way.is_equal_approx(Y):
		return Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	return Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))


## A turn taking local z (a gear's axis) to [param way].
static func _turn_z_to(way: Vector3) -> Basis:
	if way.is_equal_approx(Z):
		return Basis.IDENTITY
	if way.is_equal_approx(Y):
		return Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	return Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))


## How far a rotation turns about [param axis], degrees.
static func _about(turn: Basis, axis: Vector3) -> float:
	var across: Vector3 = (Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).cross(axis).normalized()
	var turned: Vector3 = turn * across
	return rad_to_deg(atan2(axis.dot(across.cross(turned)), across.dot(turned)))


static func _near(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.01 and a.basis.x.distance_to(b.basis.x) < 1e-5 \
		and a.basis.y.distance_to(b.basis.y) < 1e-5 and a.basis.z.distance_to(b.basis.z) < 1e-5


static func _difference(a: Image, b: Image) -> float:
	var total: float = 0.0
	var count: int = 0
	for y: int in range(0, a.get_height(), 3):
		for x: int in range(0, a.get_width(), 3):
			var one: Color = a.get_pixel(x, y)
			var two: Color = b.get_pixel(x, y)
			total += absf(one.r - two.r) + absf(one.g - two.g) + absf(one.b - two.b)
			count += 1
	return total / float(maxi(count, 1))
