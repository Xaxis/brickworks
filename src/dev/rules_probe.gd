## The rules a design has to satisfy, and what it is told when it does
## not.
##
##   godot --headless --path . --script src/dev/rules_probe.gd
##
## A design for "a windmill with four sails and a tapering tower" spent
## three turns probing the coordinate system, wrote "rotation behaves
## oddly in this checker", and rebuilt with rot 0 throughout — so the
## windmill had no sails. The rotation arithmetic is not the problem:
## the footprint swaps and the corner stays, exactly as the prompt
## promises. Something about what it was told sent it the other way.
##
## This builds the arrangement a windmill needs — four arms turned about
## the same hub — and prints the verdict verbatim, which is the thing
## neither the design log nor the chat panel ever shows.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
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

	print("  the same wall, built four ways round")
	print("")
	# A 1x4 brick standing on a 2x2 post, turned a quarter at a time.
	# Every one of these is the same shape in a different direction, so
	# any of them being refused while the others pass is a fault in the
	# turning and not in the model.
	for rot: int in 4:
		_say(assistant, "a 1x4 lying on a post, rot=%d" % rot, [
			{"part": "3003", "color": 1, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3010", "color": 4, "x": 0, "y": 3, "z": 0,
				"rot": rot},
		])

	print("")
	print("  four arms about one hub, which is what a windmill needs")
	# Each arm overlaps the hub by one stud, which is what actually
	# holds a sail on. The crossing pair sits on top of the first pair —
	# at y=9, not y=7, because a brick is three plates tall and occupies
	# all three. Getting that wrong is what makes a turned part look
	# like it landed in the wrong place.
	_say(assistant, "four 1x6 arms, each gripping the hub", [
		{"part": "3003", "color": 1, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3003", "color": 1, "x": 0, "y": 3, "z": 0, "rot": 0},
		{"part": "3009", "color": 15, "x": 1, "y": 6, "z": 0, "rot": 0},
		{"part": "3009", "color": 15, "x": -5, "y": 6, "z": 1, "rot": 0},
		{"part": "3009", "color": 15, "x": 0, "y": 9, "z": 1, "rot": 1},
		{"part": "3009", "color": 15, "x": 1, "y": 9, "z": -5, "rot": 1},
	])

	print("")
	print("  one arm sticking out on its own, which must still be held")
	_say(assistant, "a single 1x6 gripping the hub by one stud", [
		{"part": "3003", "color": 1, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3009", "color": 15, "x": 1, "y": 3, "z": 0, "rot": 0},
	])

	print("")
	print("  a staircase where an edge was meant")
	# The single most visible difference between a model that looks
	# designed and one that looks like graph paper, and nothing used to
	# notice it. An ellipse of 1 x 1 plates is the shape that started it:
	# a starship saucer built the only way the assistant knew.
	var ellipse: Array = []
	for x in range(-8, 8):
		for z in range(-6, 6):
			if (float(x) + 0.5) * (float(x) + 0.5) / 64.0 \
					+ (float(z) + 0.5) * (float(z) + 0.5) / 36.0 <= 1.0:
				ellipse.append({"part": "3024", "color": 71,
					"x": x, "y": 0, "z": z, "rot": 0})
	var stepped: Dictionary = _verdict(assistant, ellipse)
	_check_says("a stepped ellipse is told about wedge plates",
		stepped, "wedge plate")
	# Advice, not a fault. A stepped outline is exactly right for stairs
	# and for a ziggurat, so it must never be the thing that makes a
	# design fail — it is said and the design still stands.
	if bool(stepped.get("ok", false)):
		print("  ok    ...and the design still passes, %s"
			% stepped["summary"])
	else:
		_failures += 1
		print("  FAIL  the advice was counted as a problem: %s"
			% stepped["summary"])

	# And it must stay quiet otherwise, or it is noise and gets ignored.
	# A plain wall has no diagonal in it at all.
	var wall: Array = []
	for x in range(0, 8):
		for y in range(0, 3):
			wall.append({"part": "3001", "color": 4,
				"x": x * 2, "y": y * 3, "z": 0, "rot": 0})
	_check_quiet("a plain wall is not nagged about its outline",
		_verdict(assistant, wall), "steps its way")

	# And the staircase has to be found when it is one course of a
	# model rather than the whole of it.
	#
	# This is the case that was silently missed. The check flattened
	# every brick into a single plan view, so a ship whose saucer is a
	# staircase and whose hull is wider than the saucer had the hull's
	# straight edge for an outline and no staircase anywhere in it.
	# Measured on a real 144-part Voyager: not one wedge in it, not one
	# word said. A slab under the ellipse here does the same hiding.
	var hidden: Array = []
	for x in range(-9, 9):
		for z in range(-7, 7):
			hidden.append({"part": "3024", "color": 7,
				"x": x, "y": 0, "z": z, "rot": 0})
	for one: Variant in ellipse:
		var up: Dictionary = (one as Dictionary).duplicate()
		up["y"] = 1
		hidden.append(up)
	_check_says("a staircase one course up, under a wider slab, is "
		+ "still found", _verdict(assistant, hidden), "wedge plate")

	# A round tower is round. The lattice approximates it as steps, and
	# saying so would be a complaint about the measuring.
	var round_tower: Array = []
	for y in range(0, 8):
		round_tower.append({"part": "3941", "color": 4,
			"x": 0, "y": y * 3, "z": 0, "rot": 0})
	_check_quiet("a round tower is not called stepped",
		_verdict(assistant, round_tower), "steps its way")

	print("")
	print("  one layer, which nothing can hold together")
	# The commonest shape of early draft, and the count on its own reads
	# as a fault in the arrangement rather than as the one thing it is:
	# nothing on top of it. Side-by-side plates are flush against each
	# other everywhere and joined nowhere, so "do not touch" — which is
	# what this used to say — sent anyone reading it looking for a gap
	# that is not there.
	var slab: Array = []
	for at: int in range(0, 6):
		slab.append({"part": "3020", "color": 71,
			"x": at * 2, "y": 0, "z": 0, "rot": 0})
	var flat: Dictionary = _verdict(assistant, slab)
	_check_says("a single layer is told why it is in pieces", flat,
		"one layer is always like this")
	_check_quiet("...and not told they fail to touch", flat,
		"do not touch")
	# And two courses is not one layer. The test used to be whether the
	# model stood less than a brick tall, and two courses of plates is
	# two thirds of a brick — so a disc tiled in two layers, which is the
	# first thing anybody does to make a disc hold together, was told to
	# add the layer it already had.
	var twice: Array = []
	for layer: int in 2:
		for at: int in range(0, 6):
			twice.append({"part": "3020", "color": 71,
				"x": at * 2, "y": layer, "z": 0, "rot": 0})
	_check_quiet("two courses of plates are not called one layer",
		_verdict(assistant, twice), "one layer is always like this")

	print("")
	print("  a line the model would come apart along")
	# The checker knew whether a model was in one piece. It did not know
	# whether that piece would survive being picked up, and the oldest
	# way to get that wrong is to stack bricks with their joints in a
	# column. Staggering is the first thing anyone is taught and the
	# first thing a model built out of neat rectangles forgets.
	var aligned: Array = []
	for course: int in 5:
		for at: int in [0, 4]:
			aligned.append({"part": "3001", "color": 4,
				"x": at, "y": course * 3, "z": 0, "rot": 0})
	var split: Dictionary = _verdict(assistant, aligned)
	_check_says("a wall whose joints line up is told so",
		split, "Nothing bridges the line")
	if bool(split.get("ok", false)):
		print("  ok    ...and it is still buildable, %s" % split["summary"])
	else:
		_failures += 1
		print("  FAIL  the advice was counted as a problem: %s"
			% split["summary"])

	# The same wall with the courses staggered, which must say nothing.
	var staggered: Array = []
	for course: int in 5:
		if course % 2 == 0:
			for at: int in [0, 4]:
				staggered.append({"part": "3001", "color": 4,
					"x": at, "y": course * 3, "z": 0, "rot": 0})
		else:
			staggered.append({"part": "3003", "color": 4,
				"x": 0, "y": course * 3, "z": 0, "rot": 0})
			staggered.append({"part": "3001", "color": 4,
				"x": 2, "y": course * 3, "z": 0, "rot": 0})
			staggered.append({"part": "3003", "color": 4,
				"x": 6, "y": course * 3, "z": 0, "rot": 0})
	_check_quiet("the same wall, staggered, is not nagged",
		_verdict(assistant, staggered), "Nothing bridges")

	print("")
	print("  a wing that does not match its opposite")
	# Half-built-then-mirrored is how anything with two sides gets made,
	# and one brick wrong in the mirroring is the commonest way it goes
	# wrong. It is invisible in a list of placements and it is the first
	# thing a person sees.
	_check_quiet("a symmetric aeroplane is not nagged",
		_verdict(assistant, _aeroplane(false)), "mirror of itself")
	var bent: Dictionary = _verdict(assistant, _aeroplane(true))
	_check_says("...and one brick moved is pointed at", bent,
		"mirror of itself")
	# Named, because "it is not symmetric" about a four hundred brick
	# model is a sentence nobody can act on.
	_check_says("...by number", bent, "brick 23")

	print("")
	print("  the rules themselves")
	# These moved here from a second validator, in Python, that used to
	# sit behind tools/design.py. It built studs-up and only studs-up,
	# and the two had already drifted — so the designs it passed were
	# not the designs this one passes. It is gone; the rules it checked
	# are checked here, against the validator that survives.
	_refused(assistant, "a part that does not exist", [
			{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "99999zz", "color": 4, "x": 0, "y": 3, "z": 0,
				"rot": 0},
		], "99999zz")
	_refused(assistant, "a brick below the ground", [
			{"part": "3001", "color": 4, "x": 0, "y": -3, "z": 0,
				"rot": 0},
		], "ground")
	_refused(assistant, "a brick floating in the air", [
			{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3001", "color": 4, "x": 0, "y": 6, "z": 0, "rot": 0},
		], "nothing holding it")
	_say(assistant, "two bricks abutting, which is not overlapping", [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3001", "color": 4, "x": 4, "y": 0, "z": 0, "rot": 0},
	])
	# A brick is three plates. The course above one at y=0 is y=3, and
	# three plates stack into the same height.
	_say(assistant, "a brick, and the course above it at y=3", [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3001", "color": 1, "x": 0, "y": 3, "z": 0, "rot": 0},
	])
	_say(assistant, "three plates filling the same three", [
		{"part": "3020", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3020", "color": 1, "x": 0, "y": 1, "z": 0, "rot": 0},
		{"part": "3020", "color": 4, "x": 0, "y": 2, "z": 0, "rot": 0},
	])

	print("")
	print("  and when a course is put at the wrong height")
	# The mistake that started this: y counts plates and a brick is
	# three of them, so the course above a brick at y=6 starts at y=9.
	# Being told only "overlaps brick 1" leaves that sum to be redone by
	# whoever reads it, and redoing it wrong is what makes a turned part
	# look like it landed somewhere strange.
	_refused(assistant, "a second course one plate up instead of three",
		[
			{"part": "3001", "color": 1, "x": 0, "y": 6, "z": 0, "rot": 0},
			{"part": "3001", "color": 4, "x": 0, "y": 7, "z": 0, "rot": 1},
		],
		"the course above it starts at y=9")

	print("")
	print("  a face that is not one of the six")
	_refused(assistant, "an invented face says so rather than standing "
		+ "the part up", [
			{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0,
				"rot": 0, "face": "tilted30"},
		], "face cannot carry an angle")

	print("")
	print("  a reply that ran out of room is not an empty design")
	# A tool call cut off mid-placement parses as a design with nothing
	# in it. Told "no parts", the model hunts for a geometry fault that
	# is not there and spends a repair on it; three of those end the
	# run. What actually happened is that the design was too long to say
	# in one reply, and only that wording leads anywhere useful.
	var nothing := Assistant.Model.new()
	var plain: Dictionary = assistant._check(nothing)
	_check_says("an empty design says so", plain, "no parts in it")
	assistant._ran_out_of_room = true
	var cut: Dictionary = assistant._check(nothing)
	_check_says("a cut-off one says it was too long", cut,
		"too long to send in one piece")

	print("")
	print("  and that the fill lays the wedges itself")
	# It will not reach for them. Three runs, two different prompts,
	# twenty-six to thirty-two kinds of part each, and zero wings or
	# slopes in any of them — while the checker said the outline was a
	# staircase and show_technique held a worked smooth diagonal. So the
	# tool does it, and the prompt has to say so or the one thing that
	# solves it goes unused.
	var about_fill: String = assistant.guidance()
	_check_text("the prompt says fill lays wedges along an ellipse",
		about_fill, "wedge plates along an ellipse")
	_check_text("...and what that buys, in parts", about_fill,
		"thirteen parts this way")

	print("")
	print("  what the design is told to read")
	# The numbers only help if it knows they are there. Every look
	# carries them now, and the prompt has to say so, or they are three
	# lines of text above a picture that gets looked at instead.
	var told: String = assistant.guidance()
	_check_text("the prompt says the numbers come with the picture", told,
		"read the numbers beside the picture")
	# Phrases that do not cross a line break: the prompt is wrapped, and
	# a check for words either side of a newline fails on the wrapping
	# rather than on the words.
	_check_text("...and what they settle", told, "an impression")
	_check_text("...and that the plan wins when they disagree", told,
		"sizes are right and the model is wrong")

	print("")
	print("  choosing a scale, and being held to it")
	# Measured: given the list of scales, a run picked one *below* the
	# smallest on it and built a 43-stud Voyager where the list said 69,
	# which came to 144 parts against 297 for the same brief before the
	# list existed. The arithmetic was right. The model was sparing
	# itself the typing, and a model built too small to read is the one
	# fault no amount of revising gets out of it.
	var picked: String = assistant._plan_scale(
		{"subject": "the USS Voyager", "longest_metres": 344.0})
	_check_text("a long subject gets a scale and a size in studs", picked,
		"studs")
	_check_text("...and is told to build it at that size", picked,
		"Build it at that size")
	_check_text("...and not to shrink it to save itself writing", picked,
		"save yourself writing")
	_check_text("...and that the patterns do the writing", picked,
		"patterns do the writing")
	var vague: String = assistant._plan_scale({"subject": "a lighthouse"})
	_check_text("and without a length it asks for one", vague,
		"longest_metres")

	print("")
	if _failures == 0:
		print("the rules hold, and a refusal says enough to act on")
	else:
		print("%d WRONG" % _failures)
	quit(1 if _failures else 0)


## A placement that must be refused, and whose reason must contain a
## given phrase.
##
## The phrase matters as much as the refusal. A reason that only names
## what was hit sends the reader back to the arithmetic that got them
## there, and a design that redid it wrong concluded rotation was
## broken and built a windmill with no sails.
func _refused(assistant: Assistant, what: String, bricks: Array,
		must_say: String) -> void:
	var model := Assistant.Model.new()
	for raw: Variant in bricks:
		model.placements.append(Assistant.Placement.from_dict(raw))
	var verdict: Dictionary = assistant._check(model)
	var feedback: String = str(verdict["feedback"])
	if bool(verdict["ok"]):
		_failures += 1
		print("  FAIL  %s was accepted" % what)
		return
	if not feedback.contains(must_say):
		_failures += 1
		print("  FAIL  %s was refused without saying '%s'"
			% [what, must_say])
		print("        " + feedback.replace("\n", "\n        "))
		return
	print("  ok    %s — refused, and the reason says '%s'"
		% [what, must_say])


func _check_says(what: String, verdict: Dictionary, phrase: String) -> void:
	var feedback: String = str(verdict.get("feedback", ""))
	if feedback.contains(phrase):
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s — said: %s" % [what, feedback])


## A fuselage with a wing either side, and optionally one wing brick
## moved a stud out — which is the whole of what this is for.
func _aeroplane(bent: bool) -> Array:
	var out: Array = []
	for at: int in range(0, 10):
		out.append({"part": "3024", "color": 4, "x": at, "y": 0, "z": 4, "rot": 0})
		out.append({"part": "3024", "color": 4, "x": at, "y": 0, "z": 5, "rot": 0})
	for at: int in range(3, 7):
		for side: int in [2, 7]:
			var z: int = side
			if bent and side == 7 and at == 5:
				z = 8
			out.append({"part": "3024", "color": 1, "x": at, "y": 0, "z": z, "rot": 0})
	return out


## The verdict on a list of bricks, without printing it.
func _verdict(assistant: Assistant, bricks: Array) -> Dictionary:
	var model := Assistant.Model.new()
	for raw: Variant in bricks:
		model.placements.append(Assistant.Placement.from_dict(raw))
	return assistant._check(model)


## The opposite of _check_says: a phrase that must NOT be there.
##
## Advice that fires on everything is noise, and noise is read past. The
## check that it stays quiet matters as much as the check that it speaks.
## A plain answer that has to contain a phrase.
func _check_text(what: String, said: String, phrase: String) -> void:
	if said.contains(phrase):
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s — said: %s" % [what, said.substr(0, 300)])


func _check_quiet(what: String, verdict: Dictionary, phrase: String) -> void:
	var feedback: String = str(verdict.get("feedback", ""))
	if not feedback.contains(phrase):
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s — said: %s" % [what, feedback])


func _say(assistant: Assistant, what: String, bricks: Array) -> void:
	var model := Assistant.Model.new()
	for raw: Variant in bricks:
		model.placements.append(Assistant.Placement.from_dict(raw))
	var verdict: Dictionary = assistant._check(model)
	if bool(verdict["ok"]):
		print("  ok    %s — %s" % [what, verdict["summary"]])
		return
	_failures += 1
	print("  REFUSED  %s" % what)
	print("        " + str(verdict["feedback"]).replace("\n", "\n        "))
