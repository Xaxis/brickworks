## A model's step count is the same everywhere a person sees it: the
## server's count of a shared file (api/_steps.js, its page, its Tested
## note) is the app's count of the steps it opens the file to (the
## timeline's "Step 12 of 87", the step player's cover, the booklet's
## cover), counted by Instructions.count.
##
##   godot --headless --path . --script src/dev/step_count_probe.gd
##
## steps206 found the castle's page said 65 steps, the 0 STEP lines of its
## first model, where the app has 399; and the orrery's 5, where the app
## has 87, with 12 sub-assemblies built on the side in 64 steps of their
## own. For each model here: shared as the app shares it (SharedPages,
## its steps carried), opened as the viewer opens it, its steps those it
## carries and those the timeline works out alike; and the server, run on
## the very text, counts what the app counts and says it in the same words.
## Five models: the orrery (sub-models, its builder's steps, sub-assemblies
## on the side), the castle (sub-models, steps worked out), the kart, the
## sports car and a real set's file written elsewhere (6680-1: sub-models
## and its builder's steps).
extends SceneTree

const MODELS: Array[String] = ["res://models/orrery.ldr", "res://models/castle.ldr",
	"res://models/kart.ldr", "res://tools/web/gallery_seeds/sports_car.ldr",
	"res://vendor/omr/files/6680-1.mpd"]

var _failures: int = 0
var _library: PartLibrary
var _store: ModelStore
var _world: BrickWorld


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
	var builder := Builder.new()
	builder.world = _world
	builder.library = _library
	get_root().add_child(builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = builder
	_store.keeps = false
	await process_frame

	var side_seen: bool = false
	for path: String in MODELS:
		var text: String = FileAccess.get_file_as_string(path)
		print("\n%s" % path.get_file())
		_ok(not text.is_empty(), "the file is there")
		if text.is_empty():
			continue
		var shared: String = await SharedPages.attach(text, _library, _store)
		_ok(shared.contains(SharedPages.HEAD), "shared, it carries its steps")
		# Opened as the viewer opens a link: the steps it carries.
		var opened: Dictionary = _store.open_text(shared, path.get_file())
		_ok(str(opened.get("error", "")).is_empty(), "opened as the viewer opens it %s" % str(opened.get("error", "")))
		var carried: Dictionary = SharedPages.read(shared, _world, _store.scenery)
		var steps: Array[Instructions.Step] = []
		steps.assign(carried.get("steps", []))
		_ok(not steps.is_empty(), "the viewer plays the steps it carries (%d pages)" % steps.size())
		if steps.is_empty():
			continue
		var app: Dictionary = Instructions.count(steps)
		var words: String = Instructions.count_words(app)
		print("  the app: %s (%d pages)" % [words, int(app["pages"])])
		side_seen = side_seen or int(app["side"]) > 0
		# Its timeline works the same steps out, where nothing is carried.
		var worked: Array = Instructions.plan(_world, _library, _store.scenery, {},
			AuthorSteps.any(_world, _store.scenery))
		_ok(Instructions.count(worked) == app,
			"...the steps its timeline works out are as many (%s)" % Instructions.count_words(Instructions.count(worked)))
		var last: Instructions.Step = steps[-1]
		_ok(last.number == int(app["steps"]),
			"...its last step says \"%s\"" % last.caption(last.number))
		var pages: BuildSteps = BuildSteps.of(_world, _library, steps, _store.scenery)
		_ok(pages.caption(0) == words, "...the step player's cover says \"%s\"" % pages.caption(0))
		_ok(SharedPages.count(shared) == app, "...and the text alone counts the same (%s)"
			% Instructions.count_words(SharedPages.count(shared)))

		var server: Dictionary = _server(shared)
		print("  the server: %s" % JSON.stringify(server))
		var count: Dictionary = server.get("count", {}) if server.get("count") is Dictionary else {}
		var same: bool = not count.is_empty()
		for key: String in ["steps", "side", "builds", "pages"]:
			same = same and int(count.get(key, -1)) == int(app[key])
		_ok(same, "the server counts what the app counts: %d steps, %d on the side in %d sub-assemblies, %d pages"
			% [int(count.get("steps", -1)), int(count.get("side", -1)), int(count.get("builds", -1)),
			int(count.get("pages", -1))])
		_ok(str(server.get("words", "")) == words, "...and says it in the same words")
		var stored: int = int(server["stored"]) if server.get("stored") is float else -1
		_ok(stored == int(app["pages"]), "...and keeps every page, which a comment is on (%d)" % stored)
		print("  before steps206 its page said %d steps: its first model's 0 STEP lines"
			% int(server.get("before", 0)))
	_ok(side_seen, "one of them builds sub-assemblies on the side")

	print("%d FAILED" % _failures if _failures else
		"the server counts a model's steps as the app counts them, in the same words")
	quit(1 if _failures else 0)


## What api/share.js makes of [param text]: checkModel's count and stored
## steps, stepCount's words, and the old count of the first model's steps.
func _server(text: String) -> Dictionary:
	var file_path: String = ProjectSettings.globalize_path("user://step_count_probe.mpd")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var output: Array = []
	var code: int = OS.execute("node", ["--input-type=module", "-e",
		("import {checkModel} from '%s'; import {countSaid} from '%s'; import {readFileSync} from 'node:fs';"
			% [ProjectSettings.globalize_path("res://api/share.js"), ProjectSettings.globalize_path("res://api/_steps.js")])
		+ " const text = readFileSync(process.argv[1], 'utf8'); const c = checkModel(text);"
		+ " let top = 0, open = false, first = true;"
		+ " for (const line of text.split(/\\r?\\n/)) { const t = line.trim();"
		+ "   if (/^0\\s+FILE\\b/i.test(t)) { if (!first) break; first = false; }"
		+ "   else if (/^0\\s+(ROT)?STEP\\b/i.test(t)) { if (open) top += 1; open = false; }"
		+ "   else if (/^1\\s/.test(t)) open = true; }"
		+ " console.log(JSON.stringify({count: c.count, words: c.count ? countSaid(c.count) : '', stored: c.steps,"
		+ " before: Math.max(1, top + (open ? 1 : 0))}))",
		file_path], output, true)
	DirAccess.remove_absolute(file_path)
	var said: String = "".join(output).strip_edges()
	var parsed: Variant = JSON.parse_string(said.get_slice("\n", said.get_slice_count("\n") - 1))
	if code != 0 or not (parsed is Dictionary):
		print("  node exited %d: %s" % [code, said.left(400)])
		return {}
	return parsed


func _ok(passed: bool, what: String) -> void:
	print(("ok   " if passed else "FAIL ") + what)
	if not passed:
		_failures += 1
