## Can the assistant build sideways when the job needs it?
##
##   ANTHROPIC_API_KEY=... godot --path . --resolution 1200x800 \
##     --script src/dev/sideways_probe.gd
##
## Not in the offline suite: it runs a real design against a real key.
##
## src/dev/snot_probe.gd proves the machinery works — a part held by a
## stud pointing sideways validates, every face reads back as itself,
## the coordinates are the ones advertised. This asks the different
## question: given a job that cannot be done any other way, does the
## assistant actually reach for it?
##
## Worth asking, because across the eight models that ship there are
## two tipped parts out of five hundred and twenty-four, and both of
## those came from a file a person made. Everything the assistant has
## built is studs-up. A capability nothing reaches for is a capability
## that may as well not be there, and the only way to tell the two
## apart is to ask for something that demands it.
extends SceneTree

## Smooth means no studs, and a stud points up unless the part does
## not. There is no way to answer this brief studs-up.
const BRIEF := ("a square road sign on a post: the sign facing you "
	+ "must be smooth, with no studs showing anywhere on its face")

var _done := false
var _ok := false
var _summary := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame

	var assistant: Assistant = main.get("_assistant")
	var world: BrickWorld = main.get("_world")
	var builder: Builder = main.get("_builder")
	var store: ModelStore = main.get("_store")
	assistant.direct_key = OS.get_environment("ANTHROPIC_API_KEY")
	if assistant.direct_key.is_empty():
		print("no ANTHROPIC_API_KEY — this one talks to the model directly")
		quit(1)
		return

	assistant.finished.connect(func(good: bool, said: String) -> void:
		_done = true
		_ok = good
		_summary = said)
	assistant.progress.connect(func(note: String) -> void:
		print("      · %s" % note))
	assistant.said.connect(func(spoken: String) -> void:
		print("      \" %s" % spoken.replace("\n", "\n        ")))

	world.clear()
	builder.lattice.clear()
	assistant.forget_built()

	if not assistant.design(BRIEF):
		print("the assistant was busy")
		quit(1)
		return
	var deadline: int = Time.get_ticks_msec() + 1_800_000
	while not _done and Time.get_ticks_msec() < deadline:
		await process_frame

	print("")
	print("  %s" % _summary)

	var tipped: int = 0
	var upright: int = 0
	var faces: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if store.scenery.has(brick.id):
			continue
		var face: String = BrickLattice.face_of(brick.transform.basis)
		faces[face] = int(faces.get(face, 0)) + 1
		if face == "up":
			upright += 1
		else:
			tipped += 1

	print("  %d parts: %d studs-up, %d turned" % [
		upright + tipped, upright, tipped])
	for face: String in faces:
		print("    %-5s %d" % [face, faces[face]])

	var shot := ModelShot.new()
	shot.library = main.get("_library")
	main.add_child(shot)
	DirAccess.make_dir_recursive_absolute("user://gallery")
	for from: String in ["corner", "front"]:
		var image: Image = await shot.take(world, from, store.scenery)
		if image != null:
			image.save_png("user://gallery/sign_%s.png" % from)

	print("")
	if tipped > 0:
		print("it turned %d parts on their side to answer the brief" % tipped)
	else:
		print("FAIL every part is studs-up, for a brief that cannot be "
			+ "answered studs-up")
	quit(0 if tipped > 0 else 1)
