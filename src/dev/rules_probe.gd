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
