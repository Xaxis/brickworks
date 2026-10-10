## Does the catalogue know what LEGO actually made?
##
##   godot --headless --path . --script src/dev/availability_probe.gd
##
## LDraw models geometry and nothing else. It will render a wedge plate
## in sand green that was never moulded, and a design that trusts the
## picture produces a parts list nobody can buy. Rebrickable's set
## inventories are the other half, and tools/rebrickable.py joins them.
##
## The join is 79% complete, which is the whole difficulty: two thirds
## of what it cannot answer is prints and stickers it is right to skip,
## and 700 parts have a colour list known to be short — made in one of
## sixty-one Rebrickable colours LDraw has no counterpart for, or known
## only from element numbers. So the thing this probe cares about most is
## not coverage. It is that silence stays silent — that "nobody knows"
## never comes out as "never made", in either the search line or the
## checker — and, since the colour join was fixed, that the most used
## parts are no longer all short, which had made the checker silent.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	_check_catalogue(library)
	_check_the_join(library)
	_check_silence(library)
	_check_the_search_line(library)
	await _check_the_checker(library)

	print("")
	if _failures == 0:
		print("the catalogue knows what was made, and says nothing when it does not")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _check_catalogue(library: PartLibrary) -> void:
	print("\nwhat the catalogue carries")
	_ok(library.recent_since >= 2015,
		"a year from which a colour counts as current (%d)" % library.recent_since)
	_ok(not library.availability_source.is_empty(),
		"and where the answer came from (%s)" % library.availability_source)

	var known: int = 0
	var partial: int = 0
	var retired: int = 0
	for part_id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[part_id]
		if not info.availability_known():
			continue
		known += 1
		if info.colors_partial:
			partial += 1
		if not info.still_made():
			retired += 1
	print("     %d parts with a colour list, %d of them short, %d retired"
		% [known, partial, retired])
	# Measured at 6,419. A floor rather than the number, so a library
	# update that adds parts does not fail the probe, but losing the
	# join altogether does.
	_ok(known > 6000, "six thousand of them at least")
	_ok(partial > 0, "and the short ones are marked, not quietly dropped")

	# The 2x4 brick, which has been made in everything.
	var brick: PartLibrary.PartInfo = library.parts.get("3001")
	_ok(brick != null and brick.colors.size() > 60,
		"3001 in more than sixty colours (%d)" % [0 if brick == null else brick.colors.size()])
	_ok(brick != null and brick.first_year > 1900 and brick.last_year >= 2020,
		"and in sets from %d to %d" % [
			0 if brick == null else brick.first_year,
			0 if brick == null else brick.last_year])

	# A redirect still answers, because the AI writes either number.
	# 43722 is "~Moved to 43722a" and is the wedge plate 2x3 right.
	var moved: PartLibrary.PartInfo = library.parts.get("43722")
	_ok(moved != null and moved.availability_known(),
		"a retired part number inherits its target's colours (43722)")


## The point of the whole exercise: a gap must not read as a denial.
func _check_silence(library: PartLibrary) -> void:
	print("\nwhat it refuses to claim")

	# A printed tile. Nothing is known, and nothing may be inferred.
	var printed: PartLibrary.PartInfo = library.parts.get("3068p10")
	_ok(printed != null and not printed.availability_known(),
		"a printed part has no colour list")
	_ok(printed != null and not printed.never_made_in(2),
		"...and so is never said to be unavailable in anything")

	# 3001's list is short, because it was made in Glitter Milky White
	# (a 1999-2005 colour) and nothing can name that colour in LDraw terms.
	var brick: PartLibrary.PartInfo = library.parts.get("3001")
	_ok(brick != null and brick.colors_partial, "3001's list is known to be short")
	# Light Violet, which is nameable in LDraw terms and is genuinely
	# not in 3001's list. An earlier version of this check used Dark
	# Orange, which 3001 *was* made in — so removing the short-list
	# guard altogether still passed it, and the check proved nothing.
	_ok(brick != null and not brick.colors.has(20),
		"...and Light Violet is not on it")
	_ok(brick != null and not brick.never_made_in(20),
		"...so it is still never said to be unavailable in that")

	# 3030, Plate 4x10, has a complete list and is not in Dark Orange.
	var plate: PartLibrary.PartInfo = library.parts.get("3030")
	_ok(plate != null and not plate.colors_partial and plate.colors.size() > 30,
		"3030's list is complete (%d colours)" % [0 if plate == null else plate.colors.size()])
	_ok(plate != null and plate.never_made_in(484),
		"...so Dark Orange, which it never came in, can be said so")
	_ok(plate != null and not plate.never_made_in(plate.colors[0]),
		"...and a colour it did come in is not")


func _check_the_search_line(library: PartLibrary) -> void:
	print("\nthe one line the model reads about a part")
	var assistant := Assistant.new()
	assistant.library = library
	get_root().add_child(assistant)

	var current: String = assistant._describe(library.parts["3001"])
	print("     %s" % current)
	_ok(current.contains("made in") and current.contains("colour"),
		"a part in production says how many colours it comes in")

	# 3934, Wing 4x8 Right, last appeared in a set in 2004.
	var gone: String = assistant._describe(library.parts["3934"])
	print("     %s" % gone)
	_ok(gone.contains("retired") and gone.contains("2004"),
		"a retired part says when it was last in a set")

	# A part made in only a couple of colours: the count alone is no use
	# there, because which two decides the colour of whatever is built
	# from it. 10928 is the 8-tooth reinforced gear, in dark bluish grey.
	var scarce: String = assistant._describe(library.parts["10928"])
	print("     %s" % scarce)
	_ok(scarce.contains("Dark Bluish Grey"),
		"a part made in few colours names them instead of counting")
	_ok(not current.contains("Black,"),
		"...and one made in many does not recite thirty-seven")

	# And the model is told the line means something. Reporting a colour
	# the model has no reason to act on is a line of tokens for nothing.
	var rules: String = assistant._system_prompt()
	_ok(rules.contains("really moulded") or rules.contains("really made in"),
		"the rules say the colours on a search result are real")
	_ok(rules.contains("not parts that were never sold"),
		"...and that a part with no colour note is unknown, not unavailable")

	# 3137c is in-review geometry with no record of ever being sold. The
	# unofficial flag was loaded and never read anywhere, so this read
	# exactly like a mass-produced brick.
	var unreviewed: String = assistant._describe(library.parts["3137c"])
	print("     %s" % unreviewed)
	_ok(unreviewed.contains("unreviewed"),
		"in-review geometry with no record says so")

	var unknown: String = assistant._describe(library.parts["3068p10"])
	_ok(not unknown.contains("made in") and not unknown.contains("retired"),
		"a part nothing is known about says nothing about colours")
	assistant.get_parent().remove_child(assistant)
	assistant.free()


func _check_the_checker(library: PartLibrary) -> void:
	print("\nwhat a design is told")
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	await process_frame

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

	# Eight 4x10 plates in Dark Orange, which they were never made in.
	var wrong := Assistant.Model.new()
	for row: int in 8:
		var put := Assistant.Placement.new()
		put.part = "3030"
		put.color = 484
		put.x = 0.0
		put.y = float(row)
		put.z = 0.0
		wrong.placements.append(put)
	var said: String = assistant._never_made(wrong)
	print("     %s" % said.replace("\n", "\n     "))
	_ok(said.contains("3030") and said.contains("Dark Orange"),
		"the part and the colour it cannot be had in")
	_ok(said.contains("8 bricks"),
		"how many bricks say it, so one mistake is one line")
	_ok(said.contains("It comes in"),
		"and what to use instead")

	# The same design in a colour it was made in says nothing at all.
	for put: Assistant.Placement in wrong.placements:
		put.color = library.parts["3030"].colors[0]
	_ok(assistant._never_made(wrong).is_empty(),
		"a design in a colour that exists is not nagged")

	# And the whole way through check_design, which is how the model
	# actually hears it. Advice, so the design still passes: a colour is
	# fixable and the geometry is sound, and failing a design over a join
	# that knows 79% of the library would be the join overreaching.
	for put: Assistant.Placement in wrong.placements:
		put.color = 484
	var report: Dictionary = assistant._check(wrong, true)
	var feedback: String = str(report.get("feedback", ""))
	_ok(feedback.contains("Dark Orange"),
		"check_design passes the colour on to the model")
	_ok(bool(report.get("ok", false)),
		"...as advice, so a sound design still passes")

	# Nor is one built from parts nothing is known about.
	var quiet := Assistant.Model.new()
	var odd := Assistant.Placement.new()
	odd.part = "3068p10"
	odd.color = 484
	quiet.placements.append(odd)
	_ok(assistant._never_made(quiet).is_empty(),
		"nor is one built from parts nobody has data for")

	# A tyre drawn in Rubber Black. Rebrickable files it under Black, so
	# asked as Rubber Black it is "never made" — every tyre in every real
	# set drawn in LDraw was told so, 95 of them in the model repository.
	var tyres := Assistant.Model.new()
	var tyre := Assistant.Placement.new()
	tyre.part = "3641"
	tyre.color = 256
	tyres.placements.append(tyre)
	var known: PartLibrary.PartInfo = library.parts.get("3641")
	_ok(known != null and known.colors.has(0) and not known.colors.has(256),
		"3641, a tyre, is recorded in Black and never in Rubber Black")
	_ok(assistant._never_made(tyres).is_empty(),
		"...and drawn in Rubber Black it is not told it was never made")

	_check_colours_refused(assistant)
	await _check_a_recolour_refused(assistant, world, builder)


## The join itself, read through what the app loads.
func _check_the_join(library: PartLibrary) -> void:
	print("\nwhich LDraw colour each Rebrickable colour is")
	# Rebrickable's 85 "Dark Purple" is LDraw 85, renamed Medium Lilac
	# since: the colour of 17,000 Rebrickable parts, which the join
	# matched by name and so never found.
	var brick: PartLibrary.PartInfo = library.parts.get("3001")
	_ok(brick != null and brick.colors.has(85),
		"3001 was made in 85, Medium Lilac (Rebrickable's Dark Purple)")
	var lilac: PartLibrary.BrickColor = library.colors.get(85)
	_ok(lilac != null and lilac.rebrickable_id == 85
			and lilac.lego_name == "Medium Lilac" and lilac.current,
		"85 carries Rebrickable 85, LEGO's name and that it is current")
	# The new 2026 colour is LEGO's "Blue Violet", which is LDraw 431. It
	# had been matched by name to LDraw 89, which is LEGO's Medium Royal
	# Blue from 2004 and Rebrickable's 89 by its id.
	var violet: PartLibrary.BrickColor = library.colors.get(431)
	var royal: PartLibrary.BrickColor = library.colors.get(89)
	_ok(violet != null and violet.rebrickable_id == 1147 and violet.current,
		"431 is Rebrickable's 2026 Blue Violet, and current")
	_ok(royal != null and royal.rebrickable_id == 89 and not royal.current,
		"...and 89 is Rebrickable's Royal Blue, last in a set in %d"
			% (0 if royal == null else royal.last_year))
	var light_grey: PartLibrary.BrickColor = library.colors.get(7)
	var modern: PartLibrary.BrickColor = library.colors.get(71)
	_ok(light_grey != null and not light_grey.current
			and modern != null and modern.current
			and modern.lego_name == "Medium Stone Grey",
		"7 is retired (last %d) and 71 current, LEGO's Medium Stone Grey"
			% (0 if light_grey == null else light_grey.last_year))
	var main: PartLibrary.BrickColor = library.colors.get(16)
	_ok(main != null and not main.is_plastic()
			and modern != null and modern.is_plastic(),
		"16 is in the palette and is not a colour a part can be")

	# What it was all for: 49 of the 50 most used parts had a short list,
	# so never_made_in said nothing about any of them.
	var short: int = 0
	var staples: Array[PartLibrary.PartInfo] = library.staples(50)
	for info: PartLibrary.PartInfo in staples:
		if info.colors_partial:
			short += 1
	_ok(staples.size() == 50 and short <= 3,
		"%d of the 50 most used parts have a short list (was 49)" % short)


## A brick in a colour no part can be fails the check, and says why.
func _check_colours_refused(assistant: Assistant) -> void:
	for pair: Array in [[16, "a code LDraw uses inside part files"],
			[9999, "not an LDraw colour"]]:
		var odd := Assistant.Model.new()
		odd.placements.append(Assistant.Placement.from_dict(
			{"part": "3001", "color": pair[0], "x": 0, "y": 0, "z": 0}))
		var report: Dictionary = assistant._check(odd, true)
		var said: String = str(report.get("feedback", ""))
		_ok(not bool(report.get("ok", true)) and said.contains("no such colour")
				and said.contains(str(pair[1])),
			"a brick in %d is refused: %s" % [pair[0],
				said.substr(said.find("no such colour"), 110).replace("\n", " ")])
	_ok(str(assistant._check(_one_brick(71), true).get("summary", ""))
			.contains("buildable"),
		"...and the same brick in 71 is buildable")
	# The colour of a brick that gives none.
	_ok(Assistant.Placement.from_dict({"part": "3001"}).color == 71,
		"a brick that names no colour is Light Bluish Grey, not retired 7")

	# The palette the rules give is the data's: current colours only,
	# with their names, and none of the ones sets stopped using.
	var rules: String = assistant._system_prompt()
	var block: String = rules.substr(rules.find("COLOUR"))
	block = block.substr(0, block.find("AT AN ANGLE"))
	print("     " + block.substr(block.find("  plain"), 150).replace("\n", " "))
	_ok(block.contains("71 Light Bluish Grey") and block.contains("353 Coral")
			and block.contains("315 Flat Silver"),
		"the rules list current colours by name, Coral and Flat Silver too")
	_ok(not block.contains("7 Light Grey") and not block.contains("8 Dark Grey"),
		"...and not the greys LEGO retired")


func _one_brick(code: int) -> Assistant.Model:
	var model := Assistant.Model.new()
	model.placements.append(Assistant.Placement.from_dict(
		{"part": "3001", "color": code, "x": 0, "y": 0, "z": 0}))
	return model


## An edit that asks to recolour into a colour that does not exist is
## refused whole, rather than carried out in magenta.
func _check_a_recolour_refused(assistant: Assistant, world: BrickWorld,
		builder: Builder) -> void:
	world.clear()
	var mesh: Lbm.PartMesh = assistant.library.mesh_for("3001")
	var spot: Assistant.Placement = Assistant.Placement.from_dict(
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0})
	var where: Transform3D = assistant._transform(spot, mesh)
	var made: int = world.add_brick("3001", 4, where)
	builder.register(made, "3001", where)
	var answer: Variant = await assistant.use_tool("edit_model",
		{"recolor": [{"bricks": [made], "color": 24}]})
	var said: String = str(answer) if answer is String else "a picture"
	var brick: BrickWorld.Brick = world.get_brick(made)
	_ok(said.begins_with("Not applied") and said.contains("24"),
		"recolouring to 24 is refused: %s" % said.substr(0, 100))
	_ok(brick != null and brick.color_code == 4,
		"...and the brick is still red")
