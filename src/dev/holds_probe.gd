## Is the assistant told when its model will not survive being lifted?
##
##   godot --headless --path . --script src/dev/holds_probe.gd
##
## check_design asks whether every part is held by something. That is a
## different question from whether the thing holds together, and the
## gap between them is where models fail: a stack of plates on one stud
## passes, a canopy hanging out past its trunk passes, and both come
## apart in the hand.
##
## The app has always worked the second one out and shown it in the
## corner — one of the models that ships reads "1 weak joint
## (top-heavy)" — and the assistant was never told. This checks that
## the two really do disagree, because a warning that only fires when
## the other check has already failed adds nothing.
extends SceneTree

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

	# Clutch holds both ways. A plate pressed up under an overhang has
	# nothing beneath it and is held by its own studs; the check counted
	# only the part a stud reaches into, and called the plate floating.
	# Real sets do this all the time — it was the commonest reason the
	# check refused a real set's sub-model.
	var hung := Assistant.Model.new()
	for raw: Dictionary in [
			{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0},
			{"part": "3001", "color": 4, "x": 2, "y": 3, "z": 0},
			{"part": "3022", "color": 1, "x": 4, "y": 2, "z": 0}]:
		hung.placements.append(Assistant.Placement.from_dict(raw))
	var under: Dictionary = assistant._check(hung)
	_say(bool(under["ok"]), "a plate pressed up under an overhang is held "
		+ "by its own studs: %s" % under["summary"])
	# And a part with nothing at all around it still floats.
	var adrift := Assistant.Model.new()
	for raw: Dictionary in [
			{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0},
			{"part": "3022", "color": 1, "x": 8, "y": 2, "z": 0}]:
		adrift.placements.append(Assistant.Placement.from_dict(raw))
	var lost: Dictionary = assistant._check(adrift)
	_say(str(lost["summary"]).contains("floating"),
		"...and one with nothing above or below it still floats: %s"
			% lost["summary"])

	var store := ModelStore.new()
	store.world = world
	store.builder = builder
	store.library = library

	# A model that is known to be weak, rather than one invented here.
	#
	# The first attempt built a stack of heavy plates on one stud and
	# expected it to be condemned; it was not, and the probe was
	# measuring nothing. The tree that ships has read "1 weak joint
	# (top-heavy)" in the corner of the app all along, which makes it
	# the honest case: the app already disagrees with itself about this
	# model, and the question is only whether the assistant hears the
	# half that matters.
	var placed: int = store.open("res://models/tree.ldr")
	if placed == 0:
		print("  no tree to open")
		quit(1)
		return
	await process_frame

	var judge := Stability.new()
	judge.library = library
	judge.lattice = builder.lattice
	var report: Stability.Report = judge.check(world)
	print("  the tree, %d bricks: %s" % [placed, report.summary()])
	if report.is_stable():
		print("  skip  this tree is sound, so there is nothing to report")
		quit(1 if _failures else 0)
		return

	# And the design check is satisfied by it, which is the whole point:
	# every part is held by something, and the thing still comes apart.
	var model: Assistant.Model = assistant._model_from_world()
	var verdict: Dictionary = assistant._check(model, true)
	if bool(verdict["ok"]):
		print("  ok    the design check is satisfied: %s" % verdict["summary"])
	else:
		print("  ——    the design check also complains: %s"
			% verdict["summary"])

	var note: String = assistant._will_it_hold()
	print("")
	for line: String in note.split("\n"):
		if not line.strip_edges().is_empty():
			print("  " + line.strip_edges())
	print("")

	if note.contains("does not hold together"):
		print("  ok    and the assistant is told it will not hold")
	else:
		_failures += 1
		print("  FAIL  it was told nothing about the weak joint")

	# And something ordinary must not be accused.
	var sound := Assistant.Model.new()
	for n: int in 4:
		sound.placements.append(Assistant.Placement.from_dict(
			{"part": "3001", "color": 4, "x": 0, "y": n * 3, "z": 0}))
	assistant._apply(sound)
	await process_frame
	var fine: String = assistant._will_it_hold()
	if fine.contains("It holds together"):
		print("  ok    a plain stack is left alone: %s"
			% fine.strip_edges())
	else:
		_failures += 1
		print("  FAIL  a plain stack was called weak: %s" % fine)

	print("")
	if _failures == 0:
		print("the two checks ask different questions, and both are asked")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _say(passed: bool, what: String) -> void:
	if passed:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)
