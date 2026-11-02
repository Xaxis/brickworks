## What the exact check (ExactCheck) costs a check of a big model.
##
##   godot --headless --path . --script src/dev/exact_cost_probe.gd -- [MODEL.ldr ...]
##
## Each model (by default the 535-part station and the 9,431-part Orthanc)
## is opened, read back as a session's model is, and checked three ways:
## as it stands (what an edit's check carries along), with one brick added
## on top (an edit), and as a whole new design (submit_design of all of it).
## Each says the check's time and the exact check's share of it. The check
## of anything over 300 parts runs on a worker (Assistant._checked), so this
## is time waited for, not a frame held; freeze_probe times the frames.
## Fails when an edit to the biggest model spends more than EDIT_BUDGET_MS
## of its own in the exact check: the exact check's time less its share of
## what the main thread waited for a CPU over the whole check, and three
## times the budget at a load past the box's cores (ProbeTime).
extends SceneTree

const EDIT_BUDGET_MS := 3000.0

var _failed: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var files: Array = Array(OS.get_cmdline_user_args())
	if files.is_empty():
		files = ["res://models/station.ldr", "res://models/orthanc.ldr"]
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("FAIL: no catalogue")
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
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	await process_frame
	for path: String in files:
		store.open_text(FileAccess.get_file_as_string(path), path.get_file())
		var model: Assistant.Model = assistant._model_from_world()
		var shaped: int = 0
		for placement: Assistant.Placement in model.placements:
			if Exact.shape_for(library, placement.part) != null:
				shaped += 1
		print("%s: %d parts, %d with an exact shape" % [path.get_file(),
			model.placements.size(), shaped])
		_time(assistant, model, "  as it stands")
		var top: float = 0.0
		for placement: Assistant.Placement in model.placements:
			top = maxf(top, placement.y)
		var edited: Assistant.Model = assistant._model_from_world()
		edited.placements.append(Assistant.Placement.from_dict({"part": "3001", "color": 4,
			"x": 0, "y": ceilf(top) + 3, "z": 0}))
		var edit: Array = _time(assistant, edited, "  an edit, one brick added")
		var span: ProbeTime.Span = edit[1]
		var budget: float = EDIT_BUDGET_MS * span.slack()
		if path.get_file() == "orthanc.ldr" and float(edit[0]) > budget:
			_failed += 1
			print("  FAIL an edit's exact check took %.0f ms of its own, over %.0f (%s)"
				% [float(edit[0]), budget, span.said()])
		var fresh: Assistant.Model = assistant._model_from_world()
		for placement: Assistant.Placement in fresh.placements:
			placement.id = 0
		_time(assistant, fresh, "  as a whole new design")
	if _failed == 0:
		print("ok   each edit's own exact check is under %.0f ms" % EDIT_BUDGET_MS)
	else:
		print("exact cost probe: %d FAILED" % _failed)
	quit(1 if _failed > 0 else 0)


## Checks [param model] once, says how long and how much of it the exact check
## took; returns the exact check's ms of its own, less its share of the main
## thread's wait for a CPU, and the whole check's span.
func _time(assistant: Assistant, model: Assistant.Model, label: String) -> Array:
	var span := ProbeTime.Span.new()
	var report: Dictionary = assistant._check(model, true)
	span.end()
	var exact_ms: float = float(report.get("exact_ms", 0.0))
	var found: Dictionary = report.get("exact", {})
	var on := PackedStringArray()
	var spent: Dictionary = report.get("exact_on", {})
	for what: Variant in spent:
		on.append("%s %d" % [what, int(spent[what]) / 1000])
	var own: float = exact_ms * span.own / maxf(span.ms, 0.001)
	print("%s: %.0f ms, of it the exact check %.0f ms, %.0f of its own (%s); %d collisions, %d not held; %s; %s"
		% [label, span.ms, exact_ms, own, ", ".join(on), (found.get("collision", []) as Array).size(),
			(found.get("not held", []) as Array).size(), str(report.get("summary", "")).left(90),
			span.said()])
	return [own, span]
