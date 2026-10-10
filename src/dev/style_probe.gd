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
	var real: String = await _advice_for(library,
		"res://models/castle.ldr", "a medieval castle")
	_check(not real.contains("mirrored"),
		"the shipped castle is not called over-symmetric (the tool reads it 55%)")
	print("  (the shipped castle: %s)" % ("nothing to say" if real.is_empty()
		else real.get_slice("\n", 1).strip_edges()))

	print("")
	if _failures == 0:
		print("a model is measured for how it is built")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


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
	return Style.advice(found, Style.group_for(brief))


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)
