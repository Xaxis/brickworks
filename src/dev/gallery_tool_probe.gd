## Can a session search the gallery and read a model in it, and only read?
##
##   BRICKWORKS_API=http://127.0.0.1:8790 godot --headless --path . --script src/dev/gallery_tool_probe.gd
##   (tools/web/relay_server.mjs 8790 running with .env sourced, or a deployment
##   that needs no bypass)
##
## The gallery tool (src/net/gallery_tool.gd) called as the connector and
## the desktop's MCP port call it — CommandSocket.answer_rpc, tools/call —
## on the real scene, against the real list (api/share.js through
## BRICKWORKS_API): offered in tools/list with the gallery's own kinds; a
## page of models with their link ids, credits, licences and counts; a
## search and a kind; refusals that say what is wrong; a model opened as a
## reference with its size, its parts by kind, the most used, its credit,
## its licence and its picture as an image block; a link that is not one,
## and one never shared; and the baseplate exactly as it was. Then each
## licence's words, from answers played here (FakeGallery), since what a
## session may do with a model is the point of saying whose it is.
extends SceneTree

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0


## The tool, its requests answered here: a model with each licence.
class FakeGallery extends GalleryTool:
	var licence: Variant = null

	func _ask(path: String, _most: int) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		if path.begins_with("/api/share?id="):
			var body: Dictionary = {"id": "Fake000001", "name": "Played Tower", "author": "Played Builder",
				"parts": 3, "licence": licence, "url": "https://brickworks.diy/m/Fake000001",
				"description": "A tower.", "tags": ["tower"], "kind": "castle",
				"model": "0 Played\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
					+ "1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat\n"}
			return {"code": 200, "bytes": JSON.stringify(body).to_utf8_buffer()}
		return {"code": 404, "bytes": PackedByteArray()}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	print("the gallery tool, against %s" % Deployment.api_base())
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	var world: BrickWorld = _main.get("_world")
	var before: int = world.brick_count()

	var listed: Dictionary = await _rpc("tools/list", {})
	var tool: Dictionary = {}
	for one: Dictionary in listed.get("tools", []):
		if str(one["name"]) == "gallery":
			tool = one
	var schema: Dictionary = (tool.get("inputSchema", tool.get("input_schema", {})) as Dictionary)
	var kinds: Array = ((schema.get("properties", {}) as Dictionary).get("kind", {}) as Dictionary).get("enum", [])
	_check("tools/list offers gallery, its kinds the gallery's own (%d)" % kinds.size(),
		not tool.is_empty() and kinds == Array(ModelKinds.ids()))

	print("── searching ──")
	var said: String = _text(await _call({}))
	_check("a page of the gallery, newest first: %s" % said.get_slice("\n", 0),
		said.begins_with("The gallery at ") and said.contains("newest first") and said.contains(" parts"))
	var first: String = said.get_slice("\n", 1)
	var id: String = first.get_slice("(", 1).get_slice(")", 0)
	_check("each line a model with its link id, credit, licence and counts: %s" % first.left(120),
		SharedModels.is_id(id) and first.contains("views") and (first.contains("no licence chosen")
			or first.contains("CC BY") or first.contains("All rights reserved")))
	_check("and how to read one, crediting its builder", said.contains("gallery open=<id>")
		and said.contains("credit them"))
	said = _text(await _call({"q": "castle"}))
	_check("a search: %s" % said.get_slice("\n", 1).left(80), said.contains("\"castle\"")
		and said.to_lower().contains("castle") and not said.contains("A barn owl"))
	said = _text(await _call({"kind": "space", "sort": "views"}))
	_check("a kind, most viewed first: %s" % said.get_slice("\n", 0), said.contains("space")
		and said.contains("most viewed first"))
	said = _text(await _call({"q": "no such model qqzx"}))
	_check("nothing found, said so: %s" % said, said.ends_with("nothing matches."))
	for wrong: Array in [[{"kind": "spaceship"}, "kind is one of"], [{"size": "huge"}, "size is"],
			[{"sort": "best"}, "sort is"], [{"open": "../../x"}, "ten letters"],
			[{"open": "QQQQQQQQQQ"}, "not shared any more"]]:
		said = _text(await _call(wrong[0]))
		_check("%s: \"%s\"" % [JSON.stringify(wrong[0]), said.left(70)], said.contains(str(wrong[1])))

	print("── reading one ──")
	var opened: Dictionary = await _call({"open": id})
	said = _text(opened)
	var image: Dictionary = {}
	for block: Dictionary in opened.get("content", []):
		if str(block.get("type", "")) == "image":
			image = block
	_check("opened: %s" % said.get_slice("\n", 0).left(100), said.contains("/m/%s" % id) and said.contains(" parts."))
	for wanted: String in ["Licence:", "sub-assemblies", "Size:", "Its parts by kind:", "The most used:", "Read-only"]:
		_check("...%s" % wanted, said.contains(wanted))
	_check("...and its picture, as an image block (%s, %d characters)" % [image.get("mimeType", "none"),
		str(image.get("data", "")).length()], str(image.get("mimeType", "")).begins_with("image/")
		and str(image.get("data", "")).length() > 500)
	var bare: Dictionary = await _call({"open": id, "picture": false})
	_check("picture=false leaves it out", (bare.get("content", []) as Array).all(
		func(block: Dictionary) -> bool: return str(block.get("type", "")) != "image"))
	_check("the baseplate is as it was (%d parts)" % world.brick_count(), world.brick_count() == before)
	var shell: Shell = _main.get("_shell")
	shell.read_only = true
	said = _text(await _call({"q": "castle"}))
	_check("in a tab showing a shared model, still answered", said.begins_with("The gallery at "))
	shell.read_only = false

	print("── each licence, said ──")
	var fake := FakeGallery.new()
	fake.app = _main
	for pair: Array in [["cc-by-4.0", "CC BY 4.0 — anyone may share it, change it and build on it, crediting Played Builder"],
			["cc-by-sa-4.0", "must share what they make under CC BY-SA 4.0 too"],
			["all-rights-reserved", "do not copy it into a model you make or share without their leave"],
			[null, "none chosen — learn from it; do not copy it"]]:
		fake.licence = pair[0]
		said = _text_of(await fake.run({"open": "Fake000001", "picture": false}))
		_check("%s: \"%s\"" % [pair[0], str(pair[1]).left(60)], said.contains(str(pair[1])))
	fake.licence = "cc-by-4.0"
	said = _text_of(await fake.run({"open": "Fake000001", "picture": false}))
	_check("its own words, kind and tags: %s" % said.get_slice("\n", 1), said.contains("About it: A tower.")
		and said.contains("Kind: Castles and fantasy; tags: tower"))
	_check("its size and parts by kind, read from its file: %s" % said.get_slice("Size: ", 1).get_slice("\n", 0),
		said.contains("Size: ") and said.contains("studs") and said.contains("bricks tall")
		and said.contains("Its parts by kind: Brick 3"))
	_check("the most used part named: %s" % said.get_slice("The most used: ", 1).left(60),
		said.contains("2 x 3001 Brick 2 x 4"))
	_done()


func _call(arguments: Dictionary) -> Dictionary:
	return await _rpc("tools/call", {"name": "gallery", "arguments": arguments})


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


static func _text_of(answer: Variant) -> String:
	if answer is String:
		return answer
	var text: String = ""
	for block: Variant in answer as Array:
		if block is Dictionary:
			text += str((block as Dictionary).get("text", ""))
	return text


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _done() -> void:
	print("a session can search the gallery and read a model in it, and only read" if _failures == 0
		else "%d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)
