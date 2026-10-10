## Does the element maker still make the files the tests measured, and
## does the app build them into the part the mesh pipeline does?
##
##   godot --headless --path . --script src/dev/element_files_probe.gd
##   godot --headless --path . --script src/dev/element_files_probe.gd -- --write
##
## Two halves, both against files in tests/fixtures/elements/.
##
## The .dat files there are what tests/test_elements.py measures in Python —
## stud positions, heights, walls, the parser reading them back, the real
## part each standard size should equal. Those measurements are only worth
## anything while the maker still writes those bytes, so the first half
## makes every element in specs.txt again and fails on any difference.
## --write rewrites them, after which the Python suite has to pass again.
##
## pipeline.json is what tools/build_custom.py got by putting the same files
## through tools/build_meshes.py's own conversion: the connectors the
## primitives give, the collision boxes the voxeliser gives, the sockets
## underneath. The app cannot run Python — a desktop build has none and a
## browser certainly does not — so it builds a made part itself
## (PartForge), and the second half holds every number it gets against the
## pipeline's. A part made in the app is then the part the pipeline would
## have made, which is the claim the rest of the app relies on.
extends SceneTree

const DIR := "res://tests/fixtures/elements/"

var _failures: int = 0


func _initialize() -> void:
	var write: bool = OS.get_cmdline_user_args().has("--write")
	var specs: Array[ElementMaker.Spec] = _specs()
	print("%d elements in specs.txt" % specs.size())
	_ok(specs.size() >= 10, "the fixture list is there")

	print("\nthe maker still makes the files that were measured")
	for spec: ElementMaker.Spec in specs:
		_check_file(spec, write)

	if not write:
		var ids: PackedStringArray = PackedStringArray()
		for spec: ElementMaker.Spec in specs:
			ids.append(ElementMaker.id_for(spec))
		print("\nthe app builds each made part into the part tools/build_meshes.py makes,")
		print("from only the primitives it ships")
		# From the primitives the app ships and nothing else, as a browser
		# or an exported desktop build has to.
		_check_pipeline(ids, DIR, false)
		# And parts the library has, from its own files, when this checkout
		# has the library: a port that only ever saw the maker's output
		# could be right about exactly the shapes the maker draws. 3700,
		# a Technic brick, is left out on purpose: its hole's two faces are
		# not merged here (see PartForge).
		if DirAccess.dir_exists_absolute(PartForge.LIBRARY + "parts"):
			print("\n...and so are parts from the library's own files")
			_check_pipeline(LIBRARY_PARTS, PartForge.LIBRARY + "parts/", true)
		else:
			print("\n  --    no vendor/ldraw here, so the library's own parts are not checked")

	print("")
	if _failures == 0:
		print("the maker makes the measured files, and the app builds them as the pipeline does")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _specs() -> Array[ElementMaker.Spec]:
	var out: Array[ElementMaker.Spec] = []
	var text: String = FileAccess.get_file_as_string(DIR + "specs.txt")
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		out.append(ElementMaker.from_words(line))
	return out


func _check_file(spec: ElementMaker.Spec, write: bool) -> void:
	var id: String = ElementMaker.id_for(spec)
	var made: String = ElementMaker.dat(spec)
	_ok(not made.is_empty(), "%s can be made (%s)" % [id, ElementMaker.problem(spec)
		if made.is_empty() else ElementMaker.title_for(spec)])
	var path: String = DIR + id + ".dat"
	if write:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(made)
		file.close()
		print("        wrote %s" % path)
		return
	var kept: String = FileAccess.get_file_as_string(path)
	_ok(kept == made, "%s.dat is byte for byte what the maker makes" % id)
	var back: ElementMaker.Spec = ElementMaker.parse_spec(made)
	_ok(back != null and back.to_words() == spec.to_words(),
		"%s reads back as the spec that made it" % id)


## Official parts that pipeline.json also holds, every kind of primitive the
## common parts are drawn with: stud groups, logos, hollow studs, corners,
## a stud on the side.
const LIBRARY_PARTS: PackedStringArray = ["3001", "3005", "3023b", "3068b", "3039",
	"3298", "3062b", "3040b", "3660a", "4286", "3024", "3070b", "6141", "2357",
	"3045", "87087"]


## The app's own build of each file, against the pipeline's.
func _check_pipeline(ids: PackedStringArray, folder: String, library: bool) -> void:
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(DIR + "pipeline.json"))
	if typeof(raw) != TYPE_DICTIONARY:
		_ok(false, "pipeline.json is there (tools/build_custom.py --summary)")
		return
	var built: Dictionary = (raw as Dictionary).get("parts", {})
	for id: String in ids:
		var theirs: Dictionary = built.get(id, {})
		if theirs.is_empty():
			_ok(false, "%s is in pipeline.json" % id)
			continue
		var started: int = Time.get_ticks_msec()
		var forged: PartForge.Result = PartForge.build(
			FileAccess.get_file_as_string(folder + id + ".dat"), id, {}, library)
		var took: int = Time.get_ticks_msec() - started
		if forged == null or not forged.problem.is_empty():
			_ok(false, "%s builds in the app (%s)" % [id,
				"nothing" if forged == null else forged.problem])
			continue
		var ours: Dictionary = forged.summary()
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(forged.lbm)
		ours["lbm_sha256"] = hashing.finish().hex_encode()
		var differ: PackedStringArray = PackedStringArray()
		for key: String in ["bounds_min", "bounds_max", "connectors", "boxes",
				"sockets", "triangles", "cells", "lbm_sha256"]:
			if _canon(ours.get(key)) != _canon(theirs.get(key)):
				differ.append(key)
		_ok(differ.is_empty(), "%s: %d connectors, %d boxes, %d sockets, %d cells — %s (%d ms)"
			% [id, (ours["connectors"] as Array).size(), (ours["boxes"] as Array).size(),
			(ours["sockets"] as Array).size(), int(ours["cells"]),
			"the same .lbm, byte for byte" if differ.is_empty()
				else "differs in " + ", ".join(differ), took])
		if not differ.is_empty():
			for key: String in differ:
				print("          ours   %s: %s" % [key, _canon(ours.get(key)).left(300)])
				print("          theirs %s: %s" % [key, _canon(theirs.get(key)).left(300)])


## A value as text, every number to three places: Godot reads every JSON
## number as a float, so 20 and 20.0 have to be the same thing here.
static func _canon(value: Variant) -> String:
	if typeof(value) == TYPE_ARRAY:
		var parts := PackedStringArray()
		for item: Variant in value:
			parts.append(_canon(item))
		return "[" + ",".join(parts) + "]"
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return "%.3f" % (float(value) + 0.0)
	return str(value)
