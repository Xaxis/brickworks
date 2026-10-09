## Does a model read as a set, or merely stand up?
##
##   godot --headless --path . --script src/dev/variety_probe.gd
##
## The checker can say a model holds together. Whether it reads as a set
## was resting on taste until it was measured: every catalogued LEGO set,
## banded by size, says how many part-and-colour lots it has, how many
## different shapes, and how many of one piece is normal. A real set of
## five hundred parts has about a hundred and fifty lots and a hundred
## and twenty shapes, and uses at most two dozen of any one brick.
##
## models/station.ldr is the fixture because it is what provoked this.
## Five hundred and thirty five parts, forty five lots, thirty shapes
## and eighty six of one brick: the right size, the wrong texture, and
## nothing in the system said so.
extends SceneTree

const SHAPES: Array[String] = ["10247", "10313", "109373", "11002", "11203", "11211", "11212", "11213", "11290", "11301", "11399", "11458", "11476", "11833", "122c01", "122c02", "13269", "13547", "13548", "14413", "14417", "14716", "15070", "15071", "15092", "15108", "15208", "15397", "15400", "15403", "15411", "15444", "15456", "15469", "15533", "15573", "15624", "15625", "15672", "15706", "16968", "17114", "1745", "17485", "1750", "18601", "18646", "18649", "18674", "18677", "18759", "18892", "18897", "18922", "18975", "18980", "20310", "2048", "20952", "20953", "21445", "22885", "22886", "22888", "22889", "22890", "2310", "2341", "2342", "2356", "2357", "23949", "2397", "2401", "2415", "2419", "2420", "24201", "2434", "2444", "2445", "2449", "2450", "2453a", "2453b", "2454a", "2454b", "2456", "2458", "2462", "2463", "2464", "2465", "2476a", "2476b", "24866", "2508", "25195", "2539", "2540", "2577", "25893a", "26047", "2605c01", "2612", "2628", "2629", "2639", "2653", "2655", "26597", "26599", "26601", "26604", "27255", "27259", "27261", "27266", "2752", "27928"]

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	await process_frame

	print("\nwhat the catalogue knows about real sets")
	_ok(library.set_norms.size() >= 4,
		"the norms are there (%d bands)" % library.set_norms.size())
	var middle: Dictionary = library.normal_for(500)
	_ok(int(middle.get("sets", 0)) > 500,
		"a 500 part model is measured against %d real sets"
		% int(middle.get("sets", 0)))
	_ok(int(middle.get("lots", 0)) > 100 and int(middle.get("shapes", 0)) > 80,
		"which have about %d lots and %d shapes"
		% [int(middle.get("lots", 0)), int(middle.get("shapes", 0))])
	_ok(library.normal_for(3).is_empty(),
		"and a three brick model is measured against nothing")

	print("\nthe fire station, which is the right size and the wrong texture")
	var station: Assistant.Model = _read(library, "res://models/station.ldr")
	var said: String = assistant._variety(station)
	print("     %s" % said.replace("\n", "\n     "))
	_ok(said.contains("part-and-colour"), "its thin spread of lots is named")
	_ok(said.contains("shapes"), "...and its few shapes")
	_ok(said.contains("of one part"), "...and the brick it used eighty-six of")
	_ok(said.contains("real sets of this size"),
		"...and how many real sets that is measured over")

	# Advice, never a fault: a repetitive model is still buildable, and
	# refusing one would throw away a design that is merely plain.
	var report: Dictionary = assistant._check(station, true)
	_ok(bool(report.get("ok", false)) or str(report.get("summary", "")).contains("problem"),
		"the design is still judged on whether it holds together")

	print("\nand what it must not fire on")
	# The check this was missing, and it cost the whole threshold.
	#
	# Six tenths of the median shapes and twice the median repeat read
	# like a tolerance and were not one: measured against the same
	# inventories the norms come from, they fired on 29 to 34 per cent
	# of real LEGO sets, band by band. A third of real sets told they
	# are repetitive is noise. The thresholds are the fifth and
	# ninety-fifth percentiles now, at 7-11%.
	var middling: Dictionary = library.normal_for(500)
	_ok(int(middling.get("shapes_thin", 0)) > 0
			and int(middling.get("most_of_one_high", 0)) > 0,
		"the norms carry the tails as well as the medians (thin below %d "
			% int(middling.get("shapes_thin", 0))
			+ "shapes, high above %d of one)"
			% int(middling.get("most_of_one_high", 0)))
	_ok(int(middling.get("shapes_thin", 0))
			< int(middling.get("shapes", 0)) * 0.6,
		"and the thin end is stricter than six tenths of the median was")
	# A set at the median of real sets must be left entirely alone.
	var ordinary := Assistant.Model.new()
	for n: int in 500:
		var put := Assistant.Placement.new()
		put.part = SHAPES[n % int(middling.get("shapes", 117))]
		put.color = [4, 1, 2, 14, 15, 0, 71, 72, 70, 28,
			288, 484, 191, 212, 226, 308, 320, 326][n % 18]
		ordinary.placements.append(put)
	_ok(assistant._variety(ordinary).is_empty(),
		"a model with a real set's own median spread is not remarked on")
	# And one repeating a part as much as a normal real set does. 58 of
	# one piece is the ninetieth percentile for this size: common, and
	# the old rule called it repetitive at 48.
	var repeated := Assistant.Model.new()
	for n: int in 500:
		var put := Assistant.Placement.new()
		put.part = "3001" if n < 58 else SHAPES[n % SHAPES.size()]
		put.color = [4, 1, 2, 14, 15, 0, 71, 72, 70,
			28, 288, 484, 191, 212, 226, 308, 320, 326][n % 18]
		repeated.placements.append(put)
	_ok(not assistant._variety(repeated).contains("of one part"),
		"nor one using 58 of a piece, which nine real sets in ten are under")

	print("\na model with the spread of a real set")
	var rich := Assistant.Model.new()
	for n: int in 400:
		var put := Assistant.Placement.new()
		put.part = SHAPES[n % SHAPES.size()]
		put.color = [4, 1, 2, 14, 15, 0, 71, 72, 70, 28,
			288, 484, 191, 212, 226, 308, 320, 326][(n / 7) % 18]
		rich.placements.append(put)
	_ok(assistant._variety(rich).is_empty(), "is left alone")

	print("")
	if _failures == 0:
		print("a model is measured against what a set of its size really is")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _read(library: PartLibrary, path: String) -> Assistant.Model:
	var model := Assistant.Model.new()
	var ldr: LdrModel = LdrModel.load_file(path)
	if ldr == null:
		return model
	for piece: LdrModel.Placement in ldr.flatten():
		var put := Assistant.Placement.new()
		put.part = piece.part_id.to_lower().trim_suffix(".dat")
		put.color = piece.color_code
		model.placements.append(put)
	return model


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
