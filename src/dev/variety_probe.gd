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

## Real part numbers to build fixtures from, read off the catalogue. A
## typed list of 120 ran out the day the median for 500 parts became 123,
## and a script error does not end a probe — it sits there.
var _shapes: Array[String] = []

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
	var ids: Array = library.parts.keys()
	ids.sort()
	for id: String in ids.slice(0, 400):
		_shapes.append(id)

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

	print("\nand the design is told while it can still act on it")
	# The check was computing this and throwing it away on exactly the
	# designs that needed it: a design that fails gets feedback carrying
	# both faults and advice, and a design that holds together went
	# straight to the final look — which says whether it would survive
	# being picked up and lists visual faults, and never once mentioned
	# that the model was made of too few different things.
	var judged: Dictionary = assistant._check(station, true)
	var measured: Array = judged.get("advice", [])
	var all_of_it: String = " ".join(PackedStringArray(measured))
	_ok(not measured.is_empty(),
		"the check hands back what it measured, not only the faults")
	_ok(all_of_it.contains("different shapes"),
		"...including the texture, so the last look can show it")
	_ok(Assistant.CRITIQUE.contains("One shape doing the work of twenty"),
		"and the critique names monotony among the things to check by name")
	_ok(Assistant.CRITIQUE.contains("not more bricks"),
		"...and says the way out is a different piece, not more of them")

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
		put.part = _shapes[n % int(middling.get("shapes", 117))]
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
		put.part = "3001" if n < 58 else _shapes[n % _shapes.size()]
		put.color = [4, 1, 2, 14, 15, 0, 71, 72, 70,
			28, 288, 484, 191, 212, 226, 308, 320, 326][n % 18]
		repeated.placements.append(put)
	_ok(not assistant._variety(repeated).contains("of one part"),
		"nor one using 58 of a piece, which nine real sets in ten are under")

	print("\na model with the spread of a real set")
	var rich := Assistant.Model.new()
	for n: int in 400:
		var put := Assistant.Placement.new()
		put.part = _shapes[n % _shapes.size()]
		put.color = [4, 1, 2, 14, 15, 0, 71, 72, 70, 28,
			288, 484, 191, 212, 226, 308, 320, 326][(n / 7) % 18]
		rich.placements.append(put)
	_ok(assistant._variety(rich).is_empty(), "is left alone")

	print("\na big model, measured against big models rather than mosaics")
	# The castle that got to 1,828 parts with 30 shapes and 320 of one
	# brick, and was told nothing. Sets of that size were measured with
	# the mosaics, LEGO Art and bulk tubs among them, so the thin end was
	# 21 shapes — 2,305 tiles in two shapes is a set — and 660 of one.
	var castle := Assistant.Model.new()
	for n: int in 1828:
		var put := Assistant.Placement.new()
		put.part = "3010" if n < 320 else _shapes[n % 29]
		put.color = [71, 72, 19, 28, 70, 2, 4, 0][n % 8]
		castle.placements.append(put)
	var big: Dictionary = library.normal_for(1828)
	var verdict: String = assistant._variety(castle)
	print("     %s" % verdict.replace("\n", "\n     "))
	_ok(verdict.contains("30 different shapes"),
		"30 shapes in 1,828 parts is thin (below %d, where the median is %d)"
			% [int(big.get("shapes_thin", 0)), int(big.get("shapes", 0))])
	_ok(int(big.get("most_of_one_high", 0)) < 600,
		"and the most of one piece a big set uses is not a mosaic's (%d)"
			% int(big.get("most_of_one_high", 0)))

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
