extends SceneTree
## Where Brickify's time goes: the probe's bunny at forty studs, laid a few
## times, and any models named, each with its phases, and what one check
## costs alone and weighed.
##
##   godot --headless --path . --script src/dev/brickify_phases.gd -- ROUNDS [FILE:STUDS:UP[:plain] ...]

var _library: PartLibrary
var _checker: Assistant


func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var rounds: int = int(args[0]) if args.size() > 0 else 3
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = _library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	root.add_child(builder)
	_checker = Assistant.new()
	_checker.library = _library
	_checker.world = world
	_checker.builder = builder
	await process_frame
	for id: String in Brickify.parts_needed(_library):
		_library.mesh_for(id)
	var models: Array = [["bunny-40", BrickifySamples.bunny(), 40, "+Y", rounds, true]]
	for n: int in range(1, args.size()):
		var bits: PackedStringArray = args[n].split(":")
		var plain: bool = bits.size() > 3 and bits[3] == "plain"
		models.append([bits[0].get_file().get_basename() + "-" + bits[1] + ("-plain" if plain else ""),
			_read(bits[0]), int(bits[1]), bits[2], 1, not plain])
	for one: Array in models:
		var result: Dictionary = {}
		for r: int in int(one[4]):
			var options := Brickify.Options.new()
			options.studs = int(one[2])
			options.up = str(one[3])
			options.smooth = bool(one[5])
			var t0: int = Time.get_ticks_msec()
			result = Brickify.build(one[1], options, _checker)
			var took: int = Time.get_ticks_msec() - t0
			if result.has("error"):
				print("PHASES %s: %s" % [one[0], result["error"]])
				break
			var report: Dictionary = result["report"]
			print("PHASES %s" % JSON.stringify({"model": one[0], "round": r, "ms": took,
				"parts": (result["model"] as Assistant.Model).placements.size(),
				"mended": int(report.get("mended", 0)), "tied": int(report.get("tied", 0)),
				"left_out": str(report.get("left_out", [])),
				"phases": result["ms"]}))
		if result.has("model"):
			var model: Assistant.Model = result["model"]
			var t1: int = Time.get_ticks_msec()
			var alone: Dictionary = _checker._check(model, true, false)
			var a: int = Time.get_ticks_msec() - t1
			t1 = Time.get_ticks_msec()
			_checker._check(model, true, true)
			var b: int = Time.get_ticks_msec() - t1
			print("PHASES %s check: alone %d ms, weighed %d ms, exact %s ms" % [one[0], a, b,
				alone.get("exact_ms", "?")])
	print("brickify_phases: done")
	quit(0)


func _read(path: String) -> MeshFile:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var extras: Dictionary = {}
	for _round: int in 2:
		for wanted: String in MeshFile.companions(bytes, path.get_file(), extras):
			var beside: String = path.get_base_dir().path_join(
				wanted.replace("\\", "/")).simplify_path()
			if FileAccess.file_exists(beside):
				extras[wanted] = FileAccess.get_file_as_bytes(beside)
	return MeshFile.read(bytes, path.get_file(), extras)
