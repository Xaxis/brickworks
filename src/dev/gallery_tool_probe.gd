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
## its licence and its picture as an image block; every model on the first
## page opened in turn, each with what its owner wrote, its kind and its
## licence as the list says it (the project's seed models, on a fresh
## gallery); a link that is not one,
## and one never shared; and the baseplate exactly as it was. Then each
## licence's words, from answers played here (FakeGallery), since what a
## session may do with a model is the point of saying whose it is.
##
## And from answers played here too, the gallery's newer questions
## (2026-10-19): Top builds and Most built, each model's builds, what moves
## in it and its Tested mark; Parts I own refused to nobody signed in and
## asked with the person's session once they are; the front's pick, small
## builds and what they can build now; a model nobody built said so, and
## one opened saying how many built it, its Tested mark, its comments and
## photos of real builds, and how to open a copy (open_model link=); a
## list naming its designer's handle, and designer= reading their page,
## with where the person follows them. -- --played runs only these and the
## licences, with no server:
##
##   godot --headless --path . --script src/dev/gallery_tool_probe.gd -- --played
extends SceneTree

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0


## The tool, its requests answered here: a model with each licence.
class FakeGallery extends GalleryTool:
	var licence: Variant = null
	## How many built each model to its last step.
	var built: int = 3
	## What was asked, and with which session.
	var asked: Array = []

	func _ask(path: String, _most: int, token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		asked.append([path, token])
		var racer: Dictionary = {"id": "Fake000002", "name": "Played Racer", "author": "Played Builder",
			"parts": 93, "licence": "cc-by-4.0", "views": 9, "likes": 2, "remixes": 1, "builds": built,
			"technic": false, "tested": true, "moves": ["steering", "boom"],
			"by": {"handle": "played", "name": "Played Builder"}}
		if path.begins_with("/api/people?op=comments&id="):
			return {"code": 200, "bytes": JSON.stringify({"count": 2, "open": true, "comments": [
				{"by": "Ann", "handle": "ann", "body": "Built it twice!\nLove it", "at": "2026-10-18T10:00:00Z"},
				{"by": "Played Builder", "handle": "played", "by_owner": true, "body": "Thank you",
					"at": "2026-10-18T11:00:00Z"},
				{"by": "Hidden", "hidden": true, "body": "not shown", "at": "2026-10-18T12:00:00Z"}]}).to_utf8_buffer()}
		if path.begins_with("/api/people?op=photos&id="):
			return {"code": 200, "bytes": JSON.stringify({"photos": [{"id": "p1"}]}).to_utf8_buffer()}
		if path == "/api/people?op=profile&handle=played":
			return {"code": 200, "bytes": JSON.stringify({"handle": "played", "name": "Played Builder",
				"bio": "I build racers.", "url": "https://brickworks.diy/u/played", "designer": {"models": 1,
				"builds": 3, "remixes": 1, "comments": 2, "tested": 1, "likes": 2, "followers": 5},
				"models": [racer.merged({"comments": 2})], "more": false}).to_utf8_buffer()}
		if path.begins_with("/api/people?op=profile"):
			return {"code": 404, "bytes": JSON.stringify({"error": "nobody has that handle"}).to_utf8_buffer()}
		if path.begins_with("/api/share?op=list"):
			var card: Dictionary = racer.duplicate()
			if not token.is_empty():
				card["owned"] = {"pieces": 93, "have": 80, "share": 80.0 / 93.0}
			return {"code": 200, "bytes": JSON.stringify({"models": [card], "more": false}).to_utf8_buffer()}
		if path.begins_with("/api/share?op=shelves"):
			var front: Dictionary = {"pick": {"chosen": false, "week": {"builds": 3, "remixes": 1},
				"model": racer}, "small": {"label": "Small, under 200 parts", "models": [racer]}}
			if not token.is_empty():
				front["ready"] = {"models": [racer], "more": false}
			return {"code": 200, "bytes": JSON.stringify(front).to_utf8_buffer()}
		if path.begins_with("/api/share?id="):
			var body: Dictionary = {"id": "Fake000001", "name": "Played Tower", "author": "Played Builder",
				"parts": 3, "licence": licence, "url": "https://brickworks.diy/m/Fake000001",
				"description": "A tower.", "tags": ["tower"], "kind": "castle", "builds": built,
				"tested": {"tested": true, "line": "builds step by step · stands on its own"},
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
	if "--played" in OS.get_cmdline_user_args():
		await _played()
		_done()
		return
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
	var first_page: String = said
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
	# Every model a session finds on the first page reads as what its page
	# says: its words, its kind and tags, and its licence as the list has it.
	print("── every model on the first page ──")
	for line: String in first_page.split("\n"):
		var each: String = line.get_slice("(", 1).get_slice(")", 0)
		if not line.contains(" — ") or not SharedModels.is_id(each):
			continue
		said = _text(await _call({"open": each, "picture": false}))
		var licence: String = said.get_slice("Licence: ", 1).get_slice(" —", 0)
		_check("%s\n        %s\n        %s · %s" % [said.get_slice("\n", 0).left(110),
			said.get_slice("About it: ", 1).get_slice("\n", 0) if said.contains("About it: ") else "(nothing said about it)",
			said.get_slice("Kind: ", 1).get_slice("\n", 0) if said.contains("Kind: ") else "no kind",
			licence], said.contains("/m/%s" % each) and said.contains("Read-only")
			and (line.contains(licence) if licence != "none chosen" else line.contains("no licence chosen")))
	_check("the baseplate is as it was (%d parts)" % world.brick_count(), world.brick_count() == before)
	var shell: Shell = _main.get("_shell")
	shell.read_only = true
	said = _text(await _call({"q": "castle"}))
	_check("in a tab showing a shared model, still answered", said.begins_with("The gallery at "))
	shell.read_only = false

	await _played()
	_done()


## Each licence's words, and the gallery's newer questions, from answers
## played here (FakeGallery): no server.
func _played() -> void:
	var said: String
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

	print("── Top builds, what moves, Parts I own, the front ──")
	var offered: Array = (GalleryTool.definition()["input_schema"]["properties"]["sort"] as Dictionary)["enum"]
	_check("the sorts offered are the gallery's: %s" % [offered], offered == ["newest", "views", "likes",
		"remixes", "builds", "top", "owned"])
	_check("and the front is offered", (GalleryTool.definition()["input_schema"]["properties"] as Dictionary).has("shelves"))
	fake.asked.clear()
	said = _text_of(await fake.run({"sort": "top"}))
	_check("Top builds, said how it weighs: %s" % said.get_slice("\n", 0), said.contains("Top builds first")
		and str(fake.asked[0][0]).contains("sort=top") and str(fake.asked[0][1]).is_empty())
	_check("each model with its builds, what moves and its mark: %s" % said.get_slice("\n", 1),
		said.contains("built 3 times") and said.contains("moves: steering, boom") and said.contains("Tested"))
	said = _text_of(await fake.run({"sort": "builds"}))
	_check("Most built: %s" % said.get_slice("\n", 0), said.contains("most built first"))
	# A model nobody built says so: a session read the count left out at
	# nought as one the list did not give (mcpwalk2, t1).
	fake.built = 0
	said = _text_of(await fake.run({"sort": "builds", "size": "small"}))
	_check("a model nobody built says so: %s" % said.get_slice("\n", 1).left(140),
		said.get_slice("\n", 1).contains("not built yet"))
	said = _text_of(await fake.run({"open": "Fake000001", "picture": false}))
	_check("...and opened, says nobody has built it, and its Tested mark: %s"
		% said.get_slice("Nobody", 1).get_slice("\n", 0).left(60),
		said.contains("Nobody has built it to its last step yet.")
		and said.contains("Tested: builds step by step · stands on its own."))
	fake.built = 3
	said = _text_of(await fake.run({"open": "Fake000001", "picture": false}))
	_check("opened, how many built it: %s" % said.get_slice("Built to", 1).get_slice("\n", 0),
		said.contains("Built to its last step 3 times."))
	_check("...and how to open a copy of it, as Open in Brickworks does",
		said.contains("open_model link=Fake000001"))
	# Who made it, what people said and built, and what is the person's own
	# to do: a session asked could say none of it (mcpwalk2, t5).
	_check("...its comments, newest first, the hidden one left out: %s" % said.get_slice("Comments: ", 1).get_slice("\n", 0),
		said.contains("Comments: 2; the newest, as people wrote them:\n  Played Builder (@played) (its designer): \"Thank you\"\n  Ann (@ann): \"Built it twice! Love it\"")
		and not said.contains("not shown"))
	_check("...the photos of real builds: %s" % said.get_slice("Photos of real builds: ", 1).get_slice("\n", 0),
		said.contains("Photos of real builds: 1, on its page."))
	_check("...and that liking, commenting and following are the person's own",
		said.contains("following its designer are the person's own"))
	said = _text_of(await fake.run({"sort": "top"}))
	_check("a list names the designer's handle: %s" % said.get_slice("\n", 1).left(80),
		said.contains("by Played Builder (@played)"))
	said = _text_of(await fake.run({"designer": "@Played"}))
	_check("a designer's page: %s" % said.get_slice("\n", 0), said.begins_with(
		"Played Builder (@played, https://brickworks.diy/u/played): I build racers."))
	_check("...what their models earned: %s" % said.get_slice("\n", 1), said.get_slice("\n", 1)
		== "What their models earned: 1 models, built 3 times, 1 remixes, 1 Tested, 2 comments, 2 likes, 5 followers.")
	_check("...their models, Top builds first, with comments", said.contains("Their models, Top builds first:\n- Played Racer")
		and said.contains("· 2 comments"))
	_check("...and where the person follows them", said.contains("Follow is on the designer's page, https://brickworks.diy/u/played"))
	said = _text_of(await fake.run({"designer": "nobody-here"}))
	_check("a handle nobody has: %s" % said, said == "Nobody has the handle @nobody-here.")
	said = _text_of(await fake.run({"designer": "not a handle!"}))
	_check("a handle that is not one: %s" % said.left(60), said.begins_with("designer is a designer's handle"))
	fake.asked.clear()
	var account: Account = _main.get("_account")
	var was: Account.State = account.state
	account.state = Account.State.SIGNED_OUT
	said = _text_of(await fake.run({"sort": "owned"}))
	_check("Parts I own, to nobody signed in: told to sign in, nothing asked: %s" % said.left(70),
		said.contains("signs in") and fake.asked.is_empty())
	said = _text_of(await fake.run({"shelves": true}))
	_check("the front: this week's pick, why, and its moves: %s" % said.get_slice("\n", 1).left(110),
		said.contains("This week's pick (built 3 times this week, remixed once this week): Played Racer")
		and said.get_slice("\n", 1).contains("moves: steering, boom"))
	_check("the small builds: %s" % said.get_slice("\n", 2), said.contains("Small builds (Small, under 200 parts)"))
	_check("and, signed out, what signing in would add", said.contains("Signed in with a collection"))
	account.email = "probe.gallery@example.com"
	account._access = "probe.gallery.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	fake.asked.clear()
	said = _text_of(await fake.run({"sort": "owned"}))
	_check("Parts I own, signed in: asked as them, mine=1, each card's share: %s" % said.get_slice("\n", 1).left(140),
		str(fake.asked[0][0]).contains("mine=1") and str(fake.asked[0][0]).contains("sort=owned")
		and str(fake.asked[0][1]) == "probe.gallery.signed.in" and said.contains("you own 80 of its 93 pieces"))
	said = _text_of(await fake.run({"shelves": true}))
	_check("the front, signed in: what they can build now", said.contains("You can build now")
		and str(fake.asked[-1][0]).contains("op=shelves&mine=1"))
	account._access = ""
	account.state = was


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
