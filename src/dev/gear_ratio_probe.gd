## The ratio search (P1c, src/assembly/gear_ratios.gd): the trains of real
## LEGO® gears nearest a ratio, on the stud grid, each one laid out and turned
## by Mechanism to prove the ratio it claims.
##
##   godot --headless --path . --script src/dev/gear_ratio_probe.gd
##
## What it asks:
##   - the meshes the grid allows, against the spacings section 2 of
##     docs/MECHANISMS.md measured in real sets;
##   - ratios with exact answers: 1/9 is an 8 to a 24 twice, -3 a 24 to an 8;
##   - a Mars year in Earth's, which no two gears give: 15/8 in four meshes,
##     closer in six;
##   - a train between two axles 8 studs apart, and one to a point on a
##     stud's diagonal, every axle on the grid near the line;
##   - the orrery's eight trains (section 9): each planet's ring of 140 turned
##     from inside by a 12 eight studs out or a 28 seven studs out, every
##     period within 0.25% of NASA's;
##   - search_gear_ratio as a session calls it, and its refusals.
## Every train a search answers with is built here, axle by axle on the grid
## with its gears at their heights, read by Mechanism and turned: the output
## must turn as the search says to 1e-5 of itself (32-bit transforms), through
## exactly its meshes.
extends SceneTree

const Y := Vector3(0, 1, 0)
## Sidereal periods, days (Simulation.PERIODS).
const PLANETS := ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
## Earth's ring's turns per turn of the central shaft: the orrery's scale,
## 1.7332 turns of the crank to an Earth year, chosen so all eight come near
## (section 9 of docs/MECHANISMS.md).
const SCALE := 0.57698
## The pinions a ring can be turned by from inside: teeth, and where the
## pinion's axle stands from the central shaft, studs.
const PINIONS := [[12, Vector2i(8, 0)], [28, Vector2i(7, 0)]]

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
	_meshes()
	_exact()
	_mars()
	_between()
	_orrery()
	_tool()
	print("    %d trains laid out and turned by Mechanism" % _proved)
	print("")
	if _failures == 0:
		print("gear ratios: every train the search gives meshes on the grid and turns as it says, "
			+ "exact ratios found exactly, and the orrery's eight periods within 0.25% of NASA's")
	else:
		print("gear ratios: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _meshes() -> void:
	print("  the meshes the stud grid allows")
	var steps: Dictionary = GearRatios.meshes()
	var two: Array = steps.get(Vector2i(2, 0), [])
	_check("two studs apart: an 8 and a 24, a 12 and a 20, two 16s (%s)" % str(two),
		two.has([8, 24]) and two.has([12, 20]) and two.has([16, 16]) and two.has([24, 8]))
	var diagonal: Array = steps.get(Vector2i(2, 1), [])
	_check("on a stud's diagonal, 44.72 LDU for 45: a 16 and a 20, a 12 and a 24 (%s)" % str(diagonal),
		diagonal.has([16, 20]) and diagonal.has([12, 24]) and diagonal.has([8, 28]))
	_check("three studs' diagonal, 84.85 for 85: a 28 and a 40 (%s)" % str(steps.get(Vector2i(3, 3), [])),
		(steps.get(Vector2i(3, 3), []) as Array).has([28, 40]))
	var none: bool = not steps.has(Vector2i(1, 1))
	_check("one stud's diagonal, 28.28: nothing (an 8 and a 14 would be 27.5)", none)


func _exact() -> void:
	print("  ratios with exact answers")
	var trains: Array[GearRatios.Train] = GearRatios.search(1.0 / 9.0, 2)
	_check("1/9 in two meshes: %s" % _said(trains), not trains.is_empty()
		and trains[0].num == 1 and trains[0].den == 9 and trains[0].stages.size() == 2
		and absf(trains[0].error) < 1e-12)
	_prove(trains[0], "1/9")
	trains = GearRatios.search(-3.0, 1)
	_check("-3 in one mesh, a 24 driving an 8: %s" % _said(trains), not trains.is_empty()
		and trains[0].value() == -3.0 and trains[0].stages[0].drive == 24
		and trains[0].stages[0].driven == 8)
	_prove(trains[0], "-3")
	trains = GearRatios.search(3.0, 1)
	_check("+3 in one mesh is out of reach: one mesh turns it back (%s)" % _said(trains),
		trains.is_empty() or trains[0].stages.size() != 1 or trains[0].value() > 0.0)


func _mars() -> void:
	print("  a Mars year in Earth's: 686.98 / 365.256 = 1.88081, which no two gears give")
	var wanted: float = 686.98 / 365.256
	var started: int = Time.get_ticks_msec()
	var trains: Array[GearRatios.Train] = GearRatios.search(wanted, 4)
	var took: int = Time.get_ticks_msec() - started
	_check("four meshes come no nearer than 15/8, -0.31%% (%s), in %d ms" % [_said(trains), took],
		not trains.is_empty() and trains[0].num == 15 and trains[0].den == 8 and took < 5000)
	for train: GearRatios.Train in trains:
		_prove(train, "Mars")
	started = Time.get_ticks_msec()
	trains = GearRatios.search(wanted, 6)
	took = Time.get_ticks_msec() - started
	_check("six come within 0.05%% (%s), in %d ms" % [_said(trains), took],
		not trains.is_empty() and absf(trains[0].error) < 0.0005 and took < 20000)
	for train: GearRatios.Train in trains:
		_prove(train, "Mars in six")


func _between() -> void:
	print("  trains between two axles")
	for to: Vector2i in [Vector2i(8, 0), Vector2i(8, 2), Vector2i(0, -5)]:
		var started: int = Time.get_ticks_msec()
		var trains: Array[GearRatios.Train] = GearRatios.search(0.25, 4, to, 1)
		var took: int = Time.get_ticks_msec() - started
		var lands: bool = not trains.is_empty()
		for train: GearRatios.Train in trains:
			var axles: Array[Vector2i] = train.axles()
			lands = lands and axles[-1] == to and _near_line(axles, to, 1)
		_check("a quarter, the output %s from the input: %s, every axle on the grid within a stud "
			% [str(to), _said(trains)] + "of the line, in %d ms" % took, lands and took < 8000)
		for train: GearRatios.Train in trains:
			_prove(train, "to %s" % str(to))


func _orrery() -> void:
	print("  the orrery's eight trains: a ring of 140 per planet, turned from inside")
	var worst: float = 0.0
	var said := PackedStringArray()
	var started: int = Time.get_ticks_msec()
	for planet: String in PLANETS:
		var ring: float = SCALE * float(Simulation.PERIODS["earth"]) / float(Simulation.PERIODS[planet])
		var best: GearRatios.Train = null
		var pinion: int = 0
		for one: Array in PINIONS:
			var trains: Array[GearRatios.Train] = GearRatios.search(ring * 140.0 / float(one[0]), 4,
				one[1], 1)
			if not trains.is_empty() and (best == null
					or absf(log(1.0 + trains[0].error)) < absf(log(1.0 + best.error))):
				best = trains[0]
				pinion = int(one[0])
		if best == null:
			_check("%s: a train" % planet, false)
			continue
		_prove(best, planet)
		var period: float = float(Simulation.PERIODS[planet]) / float(Simulation.PERIODS["earth"])
		var made: float = SCALE / (best.value() * float(pinion) / 140.0)
		var error: float = made / period - 1.0
		worst = maxf(worst, absf(error))
		said.append("%s: %s years for %s (%+.3f%%), the %d's train %d/%d %s" % [planet.capitalize(),
			Simulation.figure(made), Simulation.figure(period), error * 100.0, pinion, best.num,
			best.den, _said([best])])
	print("    " + "\n    ".join(said))
	_check("every planet's year within 0.25%% of NASA's, the worst %.3f%%, in %d ms" % [worst * 100.0,
		Time.get_ticks_msec() - started], worst < 0.0025)


func _tool() -> void:
	print("  search_gear_ratio, as a session calls it")
	var said: String = Assistant.gear_ratio_said({"period": 9.0, "stages": 2})
	print("    " + said.replace("\n", "\n    "))
	_check("period=9 says 1/9 with its gears by part", said.contains("= 1/9")
		and said.contains("3647") and said.contains("3648b"))
	said = Assistant.gear_ratio_said({"ratio": 1.88081, "to": [8, 0], "within": 1})
	_check("to= says where each axle stands: %s" % said.get_slice("\n", 1),
		said.contains("at (8, 0)") and said.contains("1. "))
	_check("no ratio is a refusal that says what to give", Assistant.gear_ratio_said({}).begins_with("Give ratio="))
	_check("a gear the table does not have is refused", Assistant.gear_ratio_said({"ratio": 2.0,
		"gears": [8, 13]}).begins_with("gears= takes"))


# -- proving a train -------------------------------------------------------------


## Lay [param train] out: an upright axle on each grid point in a beam,
## the gears of mesh n five plates above mesh n - 1, and turn its input:
## the output must turn as the train says, through as many meshes as it
## has. Each axle is three studs long, reaching its own two gears and its
## beam and no further: a 40's four other axle holes, a stud from its
## middle, key any axle that reaches into them, as they would in the bricks.
func _prove(train: GearRatios.Train, what: String) -> void:
	var list: Array = []
	var held: Array = []
	var up := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	var flat := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	var points: Array[Vector2i] = [Vector2i.ZERO]
	points.append_array(train.axles())
	var axles: Array[int] = []
	for k: int in points.size():
		var at := Vector3(points[k].x * 20.0, 40.0 * k, points[k].y * 20.0)
		held.append(_add(list, "32523", Transform3D(Basis.IDENTITY, at + Vector3(0, -5, 0))))
		axles.append(_add(list, "4519", Transform3D(up, at + Vector3(0, 20, 0))))
	for n: int in train.stages.size():
		var stage: GearRatios.Stage = train.stages[n]
		var height: float = 40.0 * float(n + 1)
		for side: Array in [[points[n], stage.drive], [points[n + 1], stage.driven]]:
			var point: Vector2i = side[0]
			_add(list, str(GearRatios.PARTS[int(side[1])]), Transform3D(flat,
				Vector3(point.x * 20.0, height, point.y * 20.0)))
	var model: Mechanism = Mechanism.build(list, held)
	var input: int = model.body_of(axles[0])
	var output: int = model.body_of(axles[-1])
	var result: Dictionary = model.solve({input: 1.0})
	var turned: float = model.spin(output, Y) / model.spin(input, Y) if result["ok"] else NAN
	# To 1e-5 of itself: the parts stand where 32-bit transforms put them,
	# and six meshes on diagonals come out 1.8808119 for 2304/1225. A mesh
	# read at one gear's pitch circle was 1e-2 out on a diagonal.
	var ok: bool = result["ok"] and model.couplings.size() == train.stages.size() \
		and absf(turned / train.value() - 1.0) < 1e-5
	if not ok:
		_check("%s: the train laid out turns as it says (%s for %s; %d meshes for %d; %s)" % [what,
			str(turned), str(train.value()), model.couplings.size(), train.stages.size(),
			result["said"]], false)
		print(model.couplings_said())
		print(model.describe())
	else:
		_proved += 1


var _proved: int = 0


func _add(list: Array, part: String, at: Transform3D) -> int:
	var key: int = list.size() + 1
	list.append({"key": key, "part": part, "at": at, "mesh": _library.mesh_for(part)})
	return key


static func _near_line(axles: Array[Vector2i], to: Vector2i, within: int) -> bool:
	var unit: Vector2 = Vector2(to).normalized()
	for at: Vector2i in axles:
		var off: float = absf(Vector2(at).dot(Vector2(-unit.y, unit.x)))
		if off > float(within) + 1e-6:
			return false
	return true


static func _said(trains: Array) -> String:
	if trains.is_empty():
		return "none"
	var out := PackedStringArray()
	for train: GearRatios.Train in trains:
		var meshes := PackedStringArray()
		for stage: GearRatios.Stage in train.stages:
			meshes.append("%d>%d" % [stage.drive, stage.driven])
		out.append("%d/%d %+.4f%% [%s]" % [train.num, train.den, train.error * 100.0, " ".join(meshes)])
	return "; ".join(out)
