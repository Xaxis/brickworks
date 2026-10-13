## May this model go on the landing page?
##
##   godot --headless --path . --script src/dev/candidate_probe.gd -- MODEL.ldr [ON_THE_PAGE.ldr]
##
## What the page shows is what the owner judges the app by, and the app's own
## status bar said the run 4 Orthanc there had "1 weak joint (overloaded)", and
## its own check that it was 58% plain black, a hole. A candidate passes only
## if it opens whole, is buildable in one piece, stands up as the status bar
## reckons it, and the check says none of a picture's faults of it — a hole,
## speckle, an office block, a straight shaft, sky through a slit, a yard —
## that the model on the page (models/orthanc.ldr unless said) does not have.
## Exits 0 when it may, 1 when it may not, saying why.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- MODEL.ldr")
		quit(2)
		return
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
	var store := ModelStore.new()
	store.world = world
	store.builder = builder
	store.library = library
	store.keeps = false
	var path: String = args[0]
	if not path.begins_with("res://") and not path.begins_with("/"):
		path = ProjectSettings.globalize_path("res://") + path
	var opened: Dictionary = store.open_text(FileAccess.get_file_as_string(path), path.get_file())
	print("  %s" % path.get_file())
	_check("it opens whole: %d parts, none of them missing from the library (%d)"
		% [int(opened.get("placed", 0)), int(opened.get("missing", 0))],
		int(opened.get("placed", 0)) > 0 and int(opened.get("missing", 0)) == 0)
	# Judged as a design, not as the person's own: a piece of theirs apart
	# from a design is theirs to leave, and every part of an opened file is.
	var candidate: Assistant.Model = assistant._model_from_world()
	for placement: Assistant.Placement in candidate.placements:
		placement.mine = true
	var report: Dictionary = assistant._check(candidate, true)
	# One piece, or a model and the items named to stand apart from it (a
	# stand, a sign, a figure): the file's sub-models name them.
	var items: PackedStringArray = report.get("items", PackedStringArray())
	_check("it is buildable, in one piece: %s, %d piece%s%s" % [report["summary"],
		int(report.get("pieces", 0)), "" if int(report.get("pieces", 0)) == 1 else "s",
		"" if items.is_empty() else " (apart as named: %s)" % ", ".join(items)],
		bool(report["ok"]) and int(report.get("pieces", 0)) - int(report.get("named", 0)) == 1)
	var stability := Stability.new()
	stability.library = library
	stability.lattice = builder.lattice
	var stands: Stability.Report = stability.check(world)
	var weakest: String = ""
	if stands.weakest != null:
		weakest = ": " + stands.weakest.message
	_check("it stands up: %s%s" % [stands.summary(), weakest], stands.is_stable())
	var advice: String = "\n".join(PackedStringArray(report.get("advice", [])))
	# A picture's faults: none the model on the page now does not have. Run 4
	# is still called a hole; a candidate that is too says so, and may still
	# go up if it is better by eye, which is the owner's call.
	var page: String = args[1] if args.size() > 1 else "res://models/orthanc.ldr"
	store.open(page)
	var shown: Dictionary = assistant._check(assistant._model_from_world(), true)
	var before: String = "\n".join(PackedStringArray(shown.get("advice", [])))
	for fault: Array in [["reads as a hole", "a dark face with nothing on it"],
			["speckle", "dressing scattered over a dark wall"],
			["office block", "lit windows in rows"],
			["straight shaft", "no profile"],
			["Sky shows through", "sky through a slit"],
			["Its base is", "a yard for a base"]]:
		if advice.contains(fault[0]) and before.contains(fault[0]):
			print("    still %s, as %s is" % [fault[1], page.get_file()])
			continue
		_check("the check does not call it %s" % fault[1], not advice.contains(fault[0]))
	print("  %s" % ("a candidate" if _failures == 0 else "not a candidate: %d fault%s"
		% [_failures, "" if _failures == 1 else "s"]))
	quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("    ok    " + what)
	else:
		_failures += 1
		print("    FAIL  " + what)
