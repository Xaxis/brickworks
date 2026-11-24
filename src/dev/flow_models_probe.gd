## The models the browser flows publish (tests/fixtures/flow_models, read by
## tools/web/flow_models.mjs), each still what the app writes today: its
## steps worked out again by SharedPages, as the Share panel does, from the
## text it carries without them, and written byte for byte the same; for one
## kept with a finding, what Tested finds the same, but for the app's version
## and the time it took. And the run's token a flow puts in its text changes
## nothing but where the text is named: with another token the app writes the
## same steps and finds the same, its head naming the new text, which is the
## text with the token put in as flowModel puts it, and the viewer uses them.
##
##   godot --headless --path . --script src/dev/flow_models_probe.gd
##   godot --headless --path . --script src/dev/flow_models_probe.gd -- --write
##
## --write writes each again as the app writes it today. A change to what
## the app writes fails this until they are written again and committed:
## a flow on a web-lane train never runs godot (its tree is not imported),
## so a model left stale would publish steps the app no longer makes.
extends SceneTree

const DIR := "res://tests/fixtures/flow_models/"
## As tools/web/flow_models.mjs has it.
const TOKEN := "runtoken"
const OTHER := "0a1b2c3d"
## What a finding says that is not of the model: the app's version, and the
## time the tests took.
const NOT_OF_THE_MODEL := ["app", "ms"]

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	var write: bool = OS.get_cmdline_user_args().has("--write")
	var names: Array[String] = []
	for file: String in DirAccess.get_files_at(DIR):
		if file.ends_with(".ldr"):
			names.append(file.get_basename())
	names.sort()
	_ok(names.size() >= 10, "the flows' models: %s" % ", ".join(names))
	for name: String in names:
		await _model(name, write)
	print("%d FAILED" % _failures if _failures else
		"every model the browser flows publish is what the app writes today, whatever the run's token")
	quit(1 if _failures else 0)


func _model(name: String, write: bool) -> void:
	print("\n%s" % name)
	var path: String = DIR + name + ".ldr"
	var kept: String = FileAccess.get_file_as_string(path)
	var finding_path: String = DIR + name + ".tested.json"
	var tested: bool = FileAccess.file_exists(finding_path)
	var bare: String = SharedPages.strip(kept)
	var began: int = Time.get_ticks_msec()
	var made: Dictionary = await SharedPages.attach_tested(bare, _library, _store, null, tested)
	var text: String = str(made["text"])
	if write:
		_put(path, text)
		if tested:
			_put(finding_path, JSON.stringify(made["tested"]))
		_ok(text.contains(SharedPages.HEAD), "written, its steps carried (%d ms)" % (Time.get_ticks_msec() - began))
		return
	_ok(text == kept, "its steps as the app writes them today (%d ms, %d steps)%s"
		% [Time.get_ticks_msec() - began, _steps(text), _first_difference(kept, text)])
	var kept_finding: Variant = {}
	if tested:
		kept_finding = JSON.parse_string(FileAccess.get_file_as_string(finding_path))
		var today: String = _said(made["tested"], NOT_OF_THE_MODEL)
		_ok(today == _said(kept_finding, NOT_OF_THE_MODEL), "what the app finds of it today, the same: %s" % today.left(240))
	if not bare.contains(TOKEN):
		return
	# The run's token, as flowModel puts it in: the bare text's alone, and the
	# head naming the new text.
	var mine: String = bare.replace(TOKEN, OTHER)
	var expected: String = mine + kept.substr(bare.length()).replace(
		"\"model\":\"%s\"" % SharedPages.fingerprint(kept), "\"model\":\"%s\"" % SharedPages.fingerprint(mine))
	var again: Dictionary = await SharedPages.attach_tested(mine, _library, _store, null, tested)
	_ok(str(again["text"]) == expected, "with another token (%s), the same steps, the head naming the new text%s"
		% [OTHER, _first_difference(expected, str(again["text"]))])
	if tested:
		var found: Dictionary = again["tested"]
		_ok(_said(found, NOT_OF_THE_MODEL + ["model"]) == _said(kept_finding, NOT_OF_THE_MODEL + ["model"])
			and str(found.get("model", "")) == Tested.fingerprint(expected),
			"...and the same finding, naming the new text")
	_store.open_text(expected, "shared")
	var plate: int = _world.add_brick("3811", 2, Transform3D(Basis(), Vector3(0, 0, 0)))
	_store.scenery = {plate: true} if plate != 0 else {}
	_ok(not SharedPages.read(expected, _world, _store.scenery).is_empty(),
		"...which the viewer uses, opening the text")


## [param finding] without [param leave_out], as JSON with its keys sorted:
## read back from JSON first, so a count the app holds as an int and one
## read from the file as a float say the same.
func _said(finding: Variant, leave_out: Array) -> String:
	var copy: Variant = JSON.parse_string(JSON.stringify(finding))
	if not copy is Dictionary:
		return "(not a finding)"
	for key: String in leave_out:
		copy.erase(key)
	return JSON.stringify(copy, "", true)


func _steps(text: String) -> int:
	var at: int = text.find(SharedPages.HEAD)
	if at < 0:
		return 0
	var head: Variant = JSON.parse_string(text.substr(at + SharedPages.HEAD.length()).get_slice("\n", 0))
	return int(head.get("steps", 0)) if head is Dictionary else 0


## Where [param b] first differs from [param a], line by line, or "".
func _first_difference(a: String, b: String) -> String:
	if a == b:
		return ""
	var left: PackedStringArray = a.split("\n")
	var right: PackedStringArray = b.split("\n")
	for n: int in maxi(left.size(), right.size()):
		var one: String = left[n] if n < left.size() else "(none)"
		var two: String = right[n] if n < right.size() else "(none)"
		if one != two:
			return ": line %d kept %s, written %s" % [n + 1, one.strip_edges().left(100), two.strip_edges().left(100)]
	return ": the same lines, other bytes"


func _put(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
