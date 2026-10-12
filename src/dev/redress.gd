## Dress a saved model again through restyle_model, as a session would, and
## write what it comes to.
##
##   godot --headless --path . --script src/dev/redress.gd -- IN.ldr OUT.ldr ['{"style": "panels"}']
##
## IN may also be a design's submit_design input as JSON, built first. The
## input may also say "restyle": false, to underpin only, and "drop": parts
## to take out first, each {"part", "x", "y", "z"} as look_at_model says it.
## Then whatever would not stand up is underpinned (see [method underpin]).
##
## Prints, before and after: the parts, the share of the model that is plain
## bricks and plates in its commonest dark colour, the dressing over dark walls
## and how much of it is scattered one by one, and the check's verdict. The
## Orthanc on the landing page (run 4) was told it was 58% plain black and
## speckled; this is how it is dressed again without being designed again.
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: -- IN.ldr OUT.ldr ['{restyle_model input}']")
		quit(2)
		return
	var input: Dictionary = {}
	if args.size() > 2:
		input = JSON.parse_string(args[2]) as Dictionary
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
	if path.ends_with(".json"):
		# A design's own submission, built first as a session would build it.
		var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var built: Variant = await assistant.use_tool("submit_design", design)
		print("built %s: %s" % [path.get_file(), str(built).substr(0, 200)])
	else:
		print("opened %d parts from %s" % [store.open(path), path.get_file()])
	print("before: %s" % measured(assistant))
	# A part a run left standing on its own, said by what and where it is.
	var drop: Array = input.get("drop", []) as Array
	input.erase("drop")
	if not drop.is_empty():
		var taken: Array = []
		for placement: Assistant.Placement in assistant._model_from_world().placements:
			for one: Variant in drop:
				var wanted: Dictionary = one
				if placement.part == str(wanted["part"]) and Vector3(placement.x, placement.y,
						placement.z).distance_to(Vector3(float(wanted["x"]), float(wanted["y"]),
						float(wanted["z"]))) < 0.5:
					taken.append(placement.id)
		var dropped: Variant = await assistant.use_tool("edit_model", {"remove": taken})
		print("dropped %d: %s" % [taken.size(), str(dropped).get_slice("\n", 0)])
	# A model already dressed is only underpinned.
	var restyle: bool = bool(input.get("restyle", true))
	input.erase("restyle")
	if restyle:
		var answer: Variant = await assistant.use_tool("restyle_model", input)
		var said: String = answer if answer is String else ""
		if answer is Array:
			for block: Variant in answer:
				if block is Dictionary and str((block as Dictionary).get("type")) == "text":
					said += str(block["text"]) + "\n"
		print("restyle_model: %s" % said.strip_edges().substr(0, 1200))
		print("after: %s" % measured(assistant))
	print("underpinned: %s" % await underpin(assistant))
	print("stands: %s" % stands(assistant))
	var out: String = args[1]
	if not out.begins_with("/"):
		out = ProjectSettings.globalize_path("res://") + out
	print("wrote %s: %s" % [out, store.export_to(out, path.get_file().get_basename())])
	quit(0)


## Whether what stands would stand up, as the app's status bar says it:
## "stands up" or its weak joints.
static func stands(assistant: Assistant) -> String:
	var stability := Stability.new()
	stability.library = assistant.library
	stability.lattice = assistant.builder.lattice
	var report: Stability.Report = stability.check(assistant.world)
	var said: String = report.summary()
	for risk: Stability.Risk in report.risks:
		var brick: BrickWorld.Brick = assistant.world.get_brick(risk.brick_id)
		said += "; %s at %s" % [risk.message, brick.transform.origin if brick != null else "?"]
	return said


## A brick that carries a load on a sliver of what is under it, over a void, is
## given a column under it: in every stud it covers with nothing under it, 1 x 1
## bricks and plates down to whatever is below, or the ground, through
## edit_model so it is checked. The run 4 Orthanc stood the foot of its core's
## face in each cleft between its piers over a hole in the plinth, touching a
## ledge tile at one edge cell, and the app read "1 weak joint (overloaded)":
## the face above, 88 g, on that sliver of a tile, which holds 80.
static func underpin(assistant: Assistant) -> String:
	var lattice: BrickLattice = assistant.builder.lattice
	var world: BrickWorld = assistant.world
	var stability := Stability.new()
	stability.library = assistant.library
	stability.lattice = lattice
	var report: Stability.Report = stability.check(world)
	if report.risks.is_empty():
		return "nothing to underpin: %s" % report.summary()
	var adds: Array = []
	var done: Dictionary = {}    ## stud x,z -> true
	for risk: Stability.Risk in report.risks:
		var weak: BrickWorld.Brick = world.get_brick(risk.brick_id)
		if weak == null:
			continue
		var lid: PackedInt32Array = BrickLattice.moved_by(lattice.boxes_of(weak.id),
			Vector3i(0, 1, 0))
		for over: int in lattice.near_bounds(lid, weak.id):
			if BrickLattice.shared_cells(lid, lattice.boxes_of(over)) <= 0:
				continue
			var colour: int = world.get_brick(over).color_code
			var corners: Array = BrickLattice.corners_in(lattice.boxes_of(over))
			var low: Vector3i = corners[0]
			var high: Vector3i = corners[1]
			var cells: int = BrickLattice.CELLS_PER_STUD
			for sx: int in range(floori(float(low.x) / cells), ceili(float(high.x) / cells)):
				for sz: int in range(floori(float(low.z) / cells), ceili(float(high.z) / cells)):
					if done.has(Vector2i(sx, sz)):
						continue
					var x0: int = sx * cells
					var z0: int = sz * cells
					var samples: Array = []
					for cx: int in [x0 + 1, x0 + 5, x0 + 8]:
						for cz: int in [z0 + 1, z0 + 5, z0 + 8]:
							samples.append(Vector2i(cx, cz))
					# Over this stud, wholly.
					if not samples.all(func(at: Vector2i) -> bool:
							return lattice.brick_at(Vector3i(at.x, low.y, at.y)) == over):
						continue
					# Empty under it, all the way down to what is there.
					var floor_y: int = low.y
					while floor_y > 0 and samples.all(func(at: Vector2i) -> bool:
							return lattice.brick_at(Vector3i(at.x, floor_y - 1, at.y)) == 0):
						floor_y -= 1
					var gap: int = low.y - floor_y
					if gap <= 0 or gap % BrickLattice.CELLS_PER_PLATE != 0:
						continue
					done[Vector2i(sx, sz)] = true
					var plates: int = gap / BrickLattice.CELLS_PER_PLATE
					var y: int = floor_y / BrickLattice.CELLS_PER_PLATE
					while plates > 0:
						var brick: bool = plates >= 3
						adds.append({"part": "3005" if brick else "3024", "color": colour,
							"x": sx, "y": y, "z": sz, "rot": 0})
						y += 3 if brick else 1
						plates -= 3 if brick else 1
	if adds.is_empty():
		return "no void under the weak joints' loads to fill: %s" % report.summary()
	var answer: Variant = await assistant.use_tool("edit_model", {"add": adds})
	var said: String = answer if answer is String else ""
	if answer is Array:
		for block: Variant in answer:
			if block is Dictionary and str((block as Dictionary).get("type")) == "text":
				said += str(block["text"])
	return "%d parts in %d columns: %s" % [adds.size(), done.size(), said.get_slice("\n", 0)]


## Parts, plain dark share, dressing scattered, and the check, of what stands.
static func measured(assistant: Assistant) -> String:
	var model: Assistant.Model = assistant._model_from_world()
	var dark: Dictionary = {}
	for placement: Assistant.Placement in model.placements:
		if assistant._is_dark(placement.color) and Style.kinds_of(placement.part).contains("p"):
			dark[placement.color] = int(dark.get(placement.color, 0)) + 1
	var most: int = 0
	var colour: int = -1
	for code: int in dark:
		if int(dark[code]) > most:
			most = int(dark[code])
			colour = code
	var specks: Dictionary = assistant.call("_speckle_marks", model) \
		if assistant.has_method("_speckle_marks") else {"marks": [], "scattered": []}
	var report: Dictionary = assistant._check(model, true)
	return "%d parts, %d%% plain %s, %d of %d dressing marks scattered, %s, %d piece%s" % [
		model.placements.size(), roundi(100.0 * most / maxf(1.0, model.placements.size())),
		assistant._colour_name(colour), (specks["scattered"] as Array).count(true),
		(specks["marks"] as Array).size(), report["summary"], int(report.get("pieces", 0)),
		"" if int(report.get("pieces", 0)) == 1 else "s"]
