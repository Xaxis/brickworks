## Does the design loop see how a model is built, as tools/style.py does?
##
##   godot --headless --path . --script src/dev/style_probe.gd
##
## Hand-made cases first, where the answer is not in doubt: a brick
## studs-up is not built sideways and one on its side is; a quarter turn
## is square and an eighth is not; a pair either side of the middle is
## symmetric and a pair on one side is not. Then the advice, on two real
## models: the first Orthanc this built, which the owner judged too
## square and too symmetric, must be told so, and a real LEGO set must
## not be — advice that fires on the sets it is measured against is
## advice to ignore.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	if Style.norms().get("part_kinds", {}).is_empty():
		print("no style norms: run tools/style.py norms")
		quit(1)
		return
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	print("what a part is")
	_check(Style.kinds_of("3001").contains("p") and Style.kinds_of("3001").contains("u"),
		"a 2x4 brick is plain, and has an up: %s" % Style.kinds_of("3001"))
	_check(Style.kinds_of("3040b").contains("s"), "a 1x2 slope is a slope")
	_check(Style.kinds_of("99207").contains("n"), "a bracket turns studs sideways")

	print("\nhow it is built")
	var box := AABB(Vector3(-40, -24, -20), Vector3(80, 24, 40))
	var up := Transform3D(Basis(), Vector3.ZERO)
	var side := Transform3D(Basis(Vector3(1, 0, 0), PI / 2.0), Vector3.ZERO)
	var eighth := Transform3D(Basis(Vector3(0, 1, 0), PI / 4.0), Vector3.ZERO)
	var flat: Dictionary = Style.measure([["3001", 4, up, box]])
	_check(is_zero_approx(float(flat["snot"])) and is_zero_approx(float(flat["angled"])),
		"a brick studs-up is neither sideways nor angled")
	_check(is_equal_approx(float(Style.measure([["3001", 4, side, box]])["snot"]), 1.0),
		"...on its side it is sideways")
	_check(is_equal_approx(float(Style.measure([["3001", 4, eighth, box]])["angled"]), 1.0),
		"...and turned an eighth it is angled")
	var pair: Dictionary = Style.measure([
		["3001", 4, Transform3D(Basis(), Vector3(-200, 0, 0)), box],
		["3001", 4, Transform3D(Basis(), Vector3(200, 0, 0)), box]])
	_check(is_equal_approx(float(pair["symmetry"]), 1.0), "a pair either side of the middle is mirrored")
	# An L, in two colours: no plane mirrors all three. (A straight row is
	# its own mirror across its centre line, whatever its colours.)
	var lopsided: Dictionary = Style.measure([
		["3001", 4, Transform3D(Basis(), Vector3(0, 0, 0)), box],
		["3001", 4, Transform3D(Basis(), Vector3(200, 0, 0)), box],
		["3001", 1, Transform3D(Basis(), Vector3(0, 0, 200)), box]])
	_check(float(lopsided["symmetry"]) < 1.0,
		"...and an L in two colours is not: %.2f" % float(lopsided["symmetry"]))

	print("\nwhich sets a brief is measured against")
	_check(Style.group_for("The Tower of Orthanc at Isengard") == "fantasy",
		"Orthanc against fantasy sets")
	_check(Style.group_for("a red sports car") == "vehicles", "a car against vehicles")

	print("\nthe advice, on real models")
	var orthanc: String = await _advice_for(library,
		"res://src/dev/fixtures/orthanc_square.ldr", "The Tower of Orthanc")
	_check(orthanc.contains("sideways") and orthanc.contains("plain")
			and orthanc.contains("mirrored"),
		"the square Orthanc is told it is square, plain and mirrored")
	# And, a tower with nothing at an angle, of the call shaped like a tower:
	# run 14 built four piers round a core square, by hand, with the prism
	# named here only "for a tower, a pier or a turret".
	_check(orthanc.contains("\"piers\"") and orthanc.contains("clustered"),
		"...and, being a tower, told of the clustered prism by name")
	var hull: String = await _advice_for(library,
		"res://src/dev/fixtures/orthanc_square.ldr", "a cargo barge")
	_check(not hull.contains("\"piers\""),
		"...which a brief that is not a tower is not told of")
	var real: String = await _advice_for(library,
		"res://models/castle.ldr", "a medieval castle")
	_check(not real.contains("mirrored"),
		"the shipped castle is not called over-symmetric (the tool reads it 55%)")
	print("  (the shipped castle: %s)" % ("nothing to say" if real.is_empty()
		else real.get_slice("\n", 1).strip_edges()))

	print("\nthe advice knows what the subject is")
	# The owner's Falcon Heavy was told "a prism with piers, for a tower like
	# this one" (its description named the launch tower) and restyle_model,
	# which dresses a plain wall in round tiles: polka dots on a rocket. The
	# same square model, said to be a rocket by its launch tower:
	var rocket: String = await _advice_for(library,
		"res://src/dev/fixtures/orthanc_square.ldr",
		"A Falcon Heavy rocket from SpaceX as a detailed LEGO display model, beside its launch tower")
	_check(not rocket.contains("\"piers\"") and not rocket.contains("restyle_model")
			and rocket.contains("round pattern"),
		"a rocket by its tower is told of the round pattern, not of piers or restyle_model")
	var car: String = await _advice_for(library,
		"res://src/dev/fixtures/orthanc_square.ldr", "a red sports car")
	_check(car.contains("wedge plates") and car.contains("hinge")
			and not car.contains("restyle_model"),
		"a car is told of wedge plates and a hinged section")
	var owl: String = await _advice_for(library,
		"res://src/dev/fixtures/orthanc_square.ldr", "a barn owl on a branch")
	_check(owl.contains("living thing") and not owl.contains("restyle_model"),
		"an owl is told of curves and hinged wings")
	var traits: Dictionary = Style.traits_of("A steam locomotive and its tender")
	_check(traits.has("round") and traits.has("vehicle"),
		"a steam locomotive is a vehicle and round (its boiler): %s" % str(traits.keys()))
	_check(not Style.traits_of("a carriage in scarlet").has("vehicle"),
		"...and a word inside a word is not one: no car in a scarlet carriage")
	# A body of round bricks is shaped by its curves; a rocket of them was
	# told it was a pile of bricks for having nothing on its side.
	var round: String = Style.advice({"parts": 400, "snot": 0.02, "angled": 0.0,
		"curve": 0.7, "shaped": 0.75, "plain": 0.05, "symmetry": 0.8}, "space",
		"a rocket")
	_check(not round.contains("sideways") and not round.contains("turned to an angle"),
		"a model shaped by its curves is not told it is square: %s"
			% ("nothing said" if round.is_empty() else round.get_slice("\n", 1)))

	print("\nthe touches nobody asks for")
	# 95% of real sets of 300 parts or more carry a printed or stickered
	# part, 94% something that moves; every design the owner judged had
	# neither. A plain model is told; one with a printed tile and a hinge is
	# not.
	var assistant := Assistant.new()
	assistant.library = library
	get_root().add_child(assistant)
	var bare := Assistant.Model.new()
	for n: int in 320:
		bare.placements.append(Assistant.Placement.from_dict({"part": "3001",
			"color": 15, "x": (n % 16) * 4, "y": (n / 16) * 3, "z": 0, "rot": 0}))
	var told: String = assistant._touches(bare)
	_check(told.contains("printed") and told.contains("moves") and told.contains("add_minifig"),
		"a 320-part model with neither is told of both, and of a figure")
	bare.placements.append(Assistant.Placement.from_dict({"part": "3069bp01",
		"color": 15, "x": 0, "y": 60, "z": 0, "rot": 0}))
	_check(assistant._touches(bare).contains("moves") and not assistant._touches(bare).contains("printed"),
		"...with a printed tile, only of what moves")
	bare.placements.append(Assistant.Placement.from_dict({"part": "3937",
		"color": 0, "x": 4, "y": 60, "z": 0, "rot": 0}))
	_check(assistant._touches(bare).is_empty(), "...and with a hinge too, of nothing")
	assistant.queue_free()

	await _three_faults(library)

	print("")
	if _failures == 0:
		print("a model is measured for how it is built")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## The three faults that made the homepage's Orthanc "the ugliest piece of
## shit I've ever seen", as advice any subject gets: lit windows in a grid,
## a face of plain dark bricks, a tall shaft with no profile. Each fires on
## a case made to have it and not on its fix; none fires on any model this
## app ships. (Measured too, outside the suite: all three fire on run 18's
## Orthanc and on none of eight real sets from LDraw's repository, among
## them Big Ben's grid of trans-brown windows and Tower Bridge's panes.)
func _three_faults(library: PartLibrary) -> void:
	print("\nthe faults of the homepage's Orthanc, as any subject's")
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
	# A black shaft 4 x 4 and 90 courses: dark, plain and straight.
	var shaft: Array = []
	for course: int in 90:
		for one: Array in [[0, 0, 0], [2, 0, 0], [0, 2, 0], [2, 2, 0]]:
			shaft.append({"part": "3003", "color": 0, "x": one[0], "y": course * 3,
				"z": one[1], "rot": 0})
	var said: String = _advice_of(assistant, "a tower", shaft)
	_check(said.contains("reads as a hole") and said.contains("straight shaft"),
		"a black 4 x 4 shaft of plain bricks is told it is a hole and has no profile")
	var grey: Array = []
	for one: Dictionary in shaft:
		var lighter: Dictionary = one.duplicate()
		lighter["color"] = 71
		grey.append(lighter)
	_check(not _advice_of(assistant, "a tower", grey).contains("reads as a hole"),
		"...the same in light grey is not a hole")
	_check(not _advice_of(assistant, "a rocket", shaft).contains("straight shaft"),
		"...and a rocket's straightness is its shape")
	var tapered: Array = []
	for course: int in 90:
		var inset: int = course / 30
		for x: int in range(inset, 8 - inset, 2):
			for z: int in range(inset, 8 - inset, 2):
				tapered.append({"part": "3003", "color": 71, "x": x, "y": course * 3,
					"z": z, "rot": 0})
	_check(not _advice_of(assistant, "a tower", tapered).contains("straight shaft"),
		"...a tower that steps in has a profile")
	# Four columns of six lit windows: rows of them, at the same heights.
	var lit: Array = [{"part": "3710", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0}]
	for row: int in 6:
		for n: int in 4:
			lit.append({"part": "3005", "color": 46, "x": n, "y": 1 + row * 3,
				"z": 0, "rot": 0})
	_check(_advice_of(assistant, "a house", lit).contains("office block"),
		"lit windows in rows are an office block")
	var smoked: Array = []
	for one: Dictionary in lit:
		var dark: Dictionary = one.duplicate()
		if dark["part"] == "3005":
			dark["color"] = 40
		smoked.append(dark)
	_check(not _advice_of(assistant, "a house", smoked).contains("office block"),
		"...the same in dark glass are not")
	var quiet := PackedStringArray()
	# A shipped model the check is right to fault goes here with the fault.
	# Run 18's Orthanc was an office block; run 4, on the landing page since
	# 2026-10-12, has no lit windows but is still 58% plain black, and its
	# detail pass scattered its dressing one part at a time. The check is
	# right about both, so it is the true case here until a run fixes them.
	var faulty: Dictionary = {"orthanc.ldr": "reads as a hole"}
	var named := PackedStringArray()
	var here: DirAccess = DirAccess.open("res://models")
	for file: String in here.get_files():
		if not file.ends_with(".ldr"):
			continue
		var store := ModelStore.new()
		store.world = world
		store.builder = builder
		store.library = library
		store.keeps = false
		world.clear()
		store.open("res://models/" + file)
		var model: Assistant.Model = assistant._model_from_world()
		var report: Dictionary = assistant._check(model, true)
		var advice: String = "\n".join(report.get("advice", []))
		if faulty.has(file):
			if advice.contains(str(faulty[file])):
				named.append(file)
			continue
		if advice.contains("office block") or advice.contains("reads as a hole") \
				or advice.contains("straight shaft"):
			quiet.append(file)
	_check(quiet.is_empty(), "...and none of the three is said of any other model this app ships%s"
		% ("" if quiet.is_empty() else ": " + ", ".join(quiet)))
	_check(named.size() == faulty.size(),
		"...and each model known to have one is called it: %s"
		% (", ".join(named) if not named.is_empty() else "none known"))
	assistant.queue_free()
	builder.queue_free()
	world.queue_free()


func _advice_of(assistant: Assistant, brief: String, bricks: Array) -> String:
	assistant._brief = brief
	var model: Assistant.Model = assistant._read_model({"bricks": bricks})
	return "\n".join(assistant._check(model, true).get("advice", []))


## The style advice for a model on disk, measured from its bricks as a
## design is.
func _advice_for(library: PartLibrary, path: String, brief: String) -> String:
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.builder = builder
	store.library = library
	store.keeps = false
	await process_frame
	if not store.open(path):
		print("  could not open %s" % path)
		return ""
	var parts: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh != null:
			parts.append([brick.part_id, brick.color_code, brick.transform, mesh.bounds])
	var found: Dictionary = Style.measure(parts)
	print("  %s: %d parts, %d%% sideways, %d%% angled, %d%% plain, %d%% mirrored" % [
		path.get_file(), int(found.get("parts", 0)), int(found.get("snot", 0) * 100),
		int(found.get("angled", 0) * 100), int(found.get("plain", 0) * 100),
		int(found.get("symmetry", 0) * 100)])
	world.queue_free()
	builder.queue_free()
	return Style.advice(found, Style.group_for(brief), brief)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)
