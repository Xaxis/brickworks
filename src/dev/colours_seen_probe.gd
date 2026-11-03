## How many colours a model shows, and what a session is told of it.
##
##   godot --headless --path . --script src/dev/colours_seen_probe.gd
##
## On a built model: a bench design of 7992-1, the Container Stacker
## (d5base, 274 parts), opened from its file, and the picture of it from the
## corner the judge saw (every fourth pixel of it, made whole again here).
## The app counts the colours seen in that picture as the colour read did in
## Python on the same pixels (scratch colour_read.py, 2026-11-01): six,
## Yellow, Blue, Black, Dark and Light Bluish Grey and White, Yellow 48%.
## The real sets it is measured against are City's of 141 to 359 parts, the
## set under test held out by number and name (258 sets: 8 to 12, most often
## 9, by the same file read in Python), City read off what a session says.
## Then review_model of the whole and
## look_at_model say so, with the colours City sets add a little of; look
## once more and it is not said again; a model showing as many as its sets
## is told nothing; a brief with no theme is measured by its kind.
extends SceneTree


## The loop with the request taken out. Everything else is the real one.
class Offline extends Assistant:
	func _send() -> void:
		pass


const FIXTURES := "res://tests/fixtures/colours/"
const BRIEF := "Container Stacker, in the style of LEGO® City sets: fitting in about 25 x 34 " \
	+ "studs, 170 to 280 pieces."
## What the colour read counted on these pixels: code, share of the model.
const SEEN := [[14, 0.4847], [1, 0.2641], [0, 0.0971], [72, 0.0598], [71, 0.054], [15, 0.0191]]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DesignMemory.hold_out(PackedStringArray(["7992-1"]))
	DesignMemory.hold_name("Container Stacker")
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("FAIL no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var assistant := Offline.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	await process_frame
	var ldr: LdrModel = LdrModel.load_file(FIXTURES + "container_stacker.ldr")
	for piece: LdrModel.Placement in ldr.flatten():
		var part_id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(part_id) == null:
			continue
		var id: int = world.add_brick(part_id, piece.color_code, piece.transform)
		if id != 0:
			builder.register(id, part_id, piece.transform)
	var standing: int = assistant._bricks_inside({}).size()
	_ok(standing == 274, "the design is built: %d parts" % standing)

	print("\nthe count, on the picture the judge saw")
	var small := Image.load_from_file(ProjectSettings.globalize_path(
		FIXTURES + "container_stacker_corner.png"))
	var picture: Image = small.duplicate()
	picture.resize(small.get_width() * ColoursSeen.STEP, small.get_height() * ColoursSeen.STEP,
		Image.INTERPOLATE_NEAREST)
	var palette: Dictionary = ColoursSeen.palette_of(assistant._bricks_inside({}), library)
	_ok(palette.keys().size() == 8, "its palette is its 8 solid colours: %s" % str(palette.keys()))
	var began: int = Time.get_ticks_msec()
	await assistant._count_colours(picture, assistant._model_state())
	var took: int = Time.get_ticks_msec() - began
	var counted: Dictionary = assistant._colours_shown
	var codes: Array = SEEN.map(func(pair: Array) -> int: return int(pair[0]))
	_ok(counted.get("seen", []) == codes, "seen, most first: %s, as the colour read's %s"
		% [str(counted.get("seen", [])), str(codes)])
	var worst: float = 0.0
	for pair: Array in SEEN:
		worst = maxf(worst, absf(float(counted["shares"].get(pair[0], 0.0)) - float(pair[1])))
	_ok(worst < 0.001, "...each share within 0.1%% of the read's (worst %.4f)" % worst)
	_ok(took < 3000, "counted in %d ms, a 1024 picture at every fourth pixel" % took)

	print("\nthe sets it is measured against")
	_ok(ColoursSeen.theme_in(BRIEF) >= 0 and str(ColoursSeen.sets()["themes"][
		ColoursSeen.theme_in(BRIEF)]) == "City", "the brief names City")
	_ok(ColoursSeen.parts_in(BRIEF, 280, standing) == 225, "...and 170 to 280 pieces: about 225")
	for said: Array in [["A LEGO City street sweeper, orange cab", "City"],
			["technic sports car | Corvette ZR1", "Technic"],
			["A Chicago skyline in the style of LEGO Architecture sets, after New York City", "Architecture"],
			["A BrickHeadz-style bee", "Brickheadz"], ["egyptian sphinx temple", ""]]:
		var theme: int = ColoursSeen.theme_in(str(said[0]))
		var named: String = str(ColoursSeen.sets()["themes"][theme]) if theme >= 0 else ""
		_ok(named == str(said[1]), "\"%s\" names %s" % [said[0],
			named if not named.is_empty() else "no theme"])
	var ref: Dictionary = ColoursSeen.sets_like(BRIEF, PackedStringArray(), 225, library)
	_ok(str(ref.get("by", "")) == "City sets" and int(ref.get("sets", 0)) == 258
		and int(ref.get("low", 0)) == 141 and int(ref.get("high", 0)) == 359,
		"City sets of 141 to 359 parts, 258 of them: %s" % str(ref.get("sets", 0)))
	_ok([ref.get("q1"), ref.get("median"), ref.get("q3")] == [8, 9, 12],
		"...showing 8 to 12 colours, most often 9: %s" % str([ref.get("q1"), ref.get("median"),
			ref.get("q3")]))
	var city: int = ColoursSeen.theme_in(BRIEF)
	var banded: Array = (ColoursSeen.sets()["sets"] as Array).filter(func(row: Array) -> bool:
		return int(row[2]) == city and int(row[3]) >= 225 / ColoursSeen.BAND \
			and int(row[3]) <= 225 * ColoursSeen.BAND)
	_ok(banded.size() == 259 and banded.any(func(row: Array) -> bool: return row[0] == "7992-1"),
		"the set under test is the one left out: %d City sets of that size, 7992-1 among them"
		% banded.size())

	print("\nwhat a session is told")
	# As a session's are heard: its first call's subject, then the brief it
	# passes submit_design (the tab never hears the person's words).
	assistant.heard("container stacker", true)
	assistant._words_passed = BRIEF
	var reviewed: String = _text_of(await assistant.review(""))
	var finding: String = reviewed.substr(reviewed.find("Colour: "))
	print("    " + finding.substr(0, 1400).replace("\n", "\n    "))
	_ok(reviewed.contains("Colour: from the corner it shows 6 colours over 1% of the model "
		+ "(Yellow, Blue, Black, Dark Bluish Grey, Light Bluish Grey, White)"),
		"review_model says the 6 colours it shows")
	_ok(reviewed.contains("City sets of 141 to 359 parts show 8 to 12, most often 9 (258 sets"),
		"...and what City sets of its size show")
	_ok(reviewed.contains("Red (4) in 87% of them"), "...and names Red, which they add a little of")
	_ok(not reviewed.contains("Light Bluish Grey (71) in"), "...not a colour it already shows")
	_ok(reviewed.contains("glass, which counts for none of these: Trans Red (36) in 67%"),
		"...and their glass apart")
	_ok(reviewed.contains("Don't recolour a wall"), "...and to add, not recolour")
	var looked: String = str(await assistant.use_tool("look_at_model", {}))
	_ok(looked.contains("it shows 6 colours"), "look_at_model says it too")
	var again: String = str(await assistant.use_tool("look_at_model", {}))
	_ok(not again.contains("it shows 6 colours"), "...and not again while it is the same")
	var part: String = str(await assistant.use_tool("look_at_model", {"part": "3001"}))
	_ok(not part.contains("Colour: from"), "a look at some of it says nothing of the whole's colour")

	print("\nwhen it is not short, and with no theme")
	_ok(ColoursSeen.said([14, 1, 0, 72, 71, 15, 4, 19, 2], ref, library).is_empty(),
		"a model showing 9, as many as its sets most often do, is told nothing")
	var castle: Dictionary = ColoursSeen.sets_like("A castle of about 1,200 pieces",
		PackedStringArray(["castle"]), 1200, library)
	_ok(str(castle.get("by", "")) == "Castle sets", "a castle is measured by the Castle theme "
		+ "named as a word: %s, %d sets" % [castle.get("by", ""), int(castle.get("sets", 0))])
	var pirate: Dictionary = ColoursSeen.sets_like("A pirate ship of about 600 pieces",
		PackedStringArray(["pirate"]), 600, library)
	_ok(str(pirate.get("by", "")) == "pirate sets" and int(pirate.get("sets", 0)) >= 8,
		"a brief naming no theme is measured by its kind: %s, %d sets, most often %d" % [
			pirate.get("by", ""), int(pirate.get("sets", 0)), int(pirate.get("median", 0))])
	_ok(ColoursSeen.sets_like("A thing", PackedStringArray(), 300, library).is_empty(),
		"...and with neither, nothing is said")

	print("\ncolours_seen: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _text_of(message: Variant) -> String:
	if message is String:
		return message
	var said := PackedStringArray()
	for block: Variant in message:
		if block is Dictionary and (block as Dictionary).get("type", "") == "text":
			said.append(str((block as Dictionary).get("text", "")))
	return "\n".join(said)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
