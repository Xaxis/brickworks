## What is the assistant actually told when it turns a part?
##
##   godot --headless --path . --script src/dev/rot_probe.gd
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
	if _failures == 0:
		print("nothing above refused a part for being turned")
	else:
		print("%d REFUSED" % _failures)
	quit(1 if _failures else 0)


## A placement that must be refused, and must say something useful
## about why. A refusal that only names what was hit sends the reader
## back to the arithmetic that got them here.
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
		print("  FAIL  %s was refused without saying where it ends" % what)
		print("        " + feedback.replace("\n", "\n        "))
		return
	print("  ok    %s — refused, and says where it ends" % what)
	print("        " + feedback.strip_edges().replace("\n", "\n        "))


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
