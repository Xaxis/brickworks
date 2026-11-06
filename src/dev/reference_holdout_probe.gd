## Does a bench's run ever show a session a picture of bricks?
##
##   godot --headless --path . --script src/dev/reference_holdout_probe.gd
##   godot --headless --path . --script src/dev/reference_holdout_probe.gd -- --live --pictures=DIR
##
## tools/bench/realset.py judges a design against a real set and holds the set
## out (--held-out, --held-out-name; holdout_probe). find_reference left out a
## picture whose title named the set, and nothing else built of bricks: for
## Gandalf Arrives, 9469-1, Commons gave "A Wizard Is Never Late Lego diorama by
## Flounder's Bricks, 2020", a builder's model of the same scene; for the United
## States Capitol Building, 21030-1, "LEGO US Capitol"; for the Arc de Triomphe,
## 21036-1, "Arc de triomph.jpg", which only its categories call LEGO
## Architecture. Each is a model of the subject in bricks: the answer the design
## is judged against, whatever it is called.
##
## Asked as a session asks over MCP (the tab's connector, CommandSocket
## answer_rpc), on the app's scene, with Commons' answers to those three
## searches as Commons gave them (fixtures/commons_held.json, recorded
## 2026-11-05) and no picture fetched. A person's references first, nothing held
## out: the same pictures as ever, bricks among them. Then the three sets held
## out as the bench holds them: no picture of bricks, and what is not bricks
## still comes. And while they are held out,
## no link is fetched (brickify url=, print_part picture_url=) and no builder's
## own gallery model is opened (open_model link=). --live asks Commons itself;
## --pictures=DIR writes every picture a session was shown there.
extends SceneTree

const FIXTURE := "res://src/dev/fixtures/commons_held.json"
## Each subject: the set as the bench holds it, what its session asked, and the
## pictures of bricks Commons answered with.
const CASES := [
	{"set": "9469-1", "name": "Gandalf Arrives", "asked": "Gandalf Arrives",
		"bricks": ["A Wizard Is Never Late Lego diorama by Flounder's Bricks, 2020.png"]},
	{"set": "21030-1", "name": "United States Capitol Building",
		"asked": "LEGO United States Capitol Building", "bricks": ["LEGO US Capitol.jpg"]},
	{"set": "21036-1", "name": "Arc de Triomphe", "asked": "LEGO Arc de Triomphe",
		"bricks": ["Arc de triomph.jpg", "P1060363 (14424840201).jpg"]},
]
## A builder's own model in the gallery, as the site answers ?id= for it.
const OWN := {"name": "A vintage tractor and hay trailer", "author": "Brickworks", "parts": 140,
	"licence": "cc-by", "model": "0 A vintage tractor and hay trailer\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"}

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _sent: int = 0
var _live: bool = false
var _out: String = ""


## Commons' search, answered as Commons answered it; every picture a small
## grey frame, nothing fetched.
class Canned extends ReferenceFinder:
	var answers: Dictionary = {}

	func look_for(subject: String) -> void:
		_asked = subject.strip_edges()
		_pictures = []
		_pending = []
		var request := HTTPRequest.new()
		_owner().add_child(request)
		_on_searched(0, 200, PackedStringArray(),
			JSON.stringify(answers.get(_asked, {})).to_utf8_buffer(), request)

	func _fetch_next() -> void:
		for one: Dictionary in _pending:
			var frame := Image.create(320, 200, false, Image.FORMAT_RGB8)
			frame.fill(Color(0.6, 0.6, 0.6))
			_pictures.append({"bytes": frame.save_png_to_buffer(), "title": one["title"],
				"credit": one["credit"], "colours": {}})
		_pending = []
		if _pictures.is_empty():
			missed.emit("the pictures could not be fetched")
		else:
			found.emit(_pictures)


## The gallery's own deployment, answering ?id= with [constant OWN].
class Gallery extends SharedModels:
	func fetch(_id: String, _version: int = 0) -> Dictionary:
		return {"code": 200, "body": OWN.duplicate()}


func _initialize() -> void:
	_run()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		_live = _live or argument == "--live"
		if argument.begins_with("--pictures="):
			_out = argument.trim_prefix("--pictures=")
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	if _main.get("_store") == null or _main.get("_connector") == null:
		print("FAIL the app did not come up")
		quit(1)
		return
	(_main.get("_store") as ModelStore).keeps = false
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var assistant: Assistant = _main.get("_assistant")
	if not _live:
		var canned := Canned.new()
		canned.answers = (JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) as Dictionary)["answers"]
		assistant.add_child(canned)
		assistant._finder = canned
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)

	print("── a person's references: nothing held out ──")
	for one: Dictionary in CASES:
		var shown: Dictionary = await _shown(str(one["asked"]), "person-" + str(one["set"]))
		var bricks: PackedStringArray = _among(shown["titles"], one["bricks"])
		_ok(not bricks.is_empty() or _live, "\"%s\": %d pictures, as ever, bricks among them: %s" % [
			one["asked"], shown["images"], " | ".join(shown["titles"])])
	var linked: String = (_socket._the_app_tools() as AppTools).refusal("brickify",
		{"url": "https://example.invalid/tractor.obj"})
	_ok(linked.is_empty(), "brickify url= goes ahead%s" % (": " + linked if not linked.is_empty() else ""))

	print("── a bench's run: the three sets held out by number and name ──")
	var sets := PackedStringArray()
	for one: Dictionary in CASES:
		sets.append(str(one["set"]))
	DesignMemory.hold_out(sets)
	for one: Dictionary in CASES:
		DesignMemory.hold_name(str(one["name"]))
	for one: Dictionary in CASES:
		var shown: Dictionary = await _shown(str(one["asked"]), str(one["set"]))
		var bricks: PackedStringArray = _among(shown["titles"], one["bricks"])
		_ok(bricks.is_empty(), "\"%s\" (%s): no picture of bricks: %s" % [one["asked"], one["set"],
			"shown " + " | ".join(bricks) if not bricks.is_empty() else "none"])
		print("        shown %d: %s" % [shown["images"], " | ".join(shown["titles"])
			if not shown["titles"].is_empty() else shown["text"].left(200)])
		if int(shown["images"]) == 0:
			_ok(str(shown["text"]).contains("ask for the real thing"),
				"...and the session is told to ask for the real thing by its own name")
		if one["set"] == "9469-1":
			_ok(int(shown["images"]) > 0, "...and the pictures not of bricks still come: %d"
				% shown["images"])
	var world: BrickWorld = _main.get("_world")
	var brick: int = world.bricks()[0].id if not world.bricks().is_empty() else 1
	for asked: Dictionary in [{"tool": "brickify", "input": {"url": "https://example.invalid/tractor.obj"}},
			{"tool": "print_part", "input": {"brick": brick, "picture_url": "https://example.invalid/set.png"}}]:
		var said: String = await _call(str(asked["tool"]), asked["input"])
		_ok(said.contains("no link is fetched"), "%s with a link fetches nothing: %s" % [asked["tool"],
			said.left(110)])
	_main.set("_shared", _gallery())
	var opened: String = await _call("open_model", {"link": "AbCdE12345", "discard_changes": true})
	_ok(opened.contains("builder's own model"), "open_model link= opens no builder's own model: %s"
		% opened.left(110))

	print("")
	print("reference holdout: a scored design is shown no picture of bricks, and a person's "
		+ "references are as they were" if _failures == 0 else "reference holdout: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _gallery() -> SharedModels:
	var gallery := Gallery.new()
	_main.add_child(gallery)
	return gallery


## find_reference over MCP: the titles it named, how many pictures, its words.
## Each picture written to --pictures as <tag>-<n>.png.
func _shown(asked: String, tag: String) -> Dictionary:
	_sent += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _sent,
		"method": "tools/call", "params": {"name": "find_reference", "arguments": {"subject": asked}}})
	var titles := PackedStringArray()
	var said := PackedStringArray()
	var images: int = 0
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		var one: Dictionary = block
		if str(one.get("type", "")) == "image":
			images += 1
			if not _out.is_empty():
				var file := FileAccess.open(_out.path_join("%s-%d.png" % [tag, images]), FileAccess.WRITE)
				file.store_buffer(Marshalls.base64_to_raw(str(one.get("data", ""))))
				file.close()
			continue
		var text: String = str(one.get("text", ""))
		said.append(text)
		if text.contains(" — ") and not text.contains("Wikimedia Commons. Check"):
			titles.append(text.get_slice(" — ", 0).strip_edges())
	return {"titles": titles, "images": images, "text": " ".join(said)}


func _call(tool: String, input: Dictionary) -> String:
	_sent += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _sent,
		"method": "tools/call", "params": {"name": tool, "arguments": input}})
	var out := PackedStringArray()
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		out.append(str((block as Dictionary).get("text", "")))
	return " ".join(out)


## Which of [param bricks] are among [param titles].
static func _among(titles: PackedStringArray, bricks: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for title: String in titles:
		if bricks.has(title):
			out.append(title)
	return out


func _ok(passed: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", what])
	if not passed:
		_failures += 1
