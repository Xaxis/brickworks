## Building together from the desktop's side (src/net/together.gd): do two
## copies of the app build one model at once and stay the same, and does a
## desktop copy join a session a browser started?
##
##   set -a; . ./.env; set +a
##   node tools/web/relay_server.mjs 9011 --hold=together_sessions,together_ops,together_people &
##   godot --headless --path . --script src/dev/together_probe.gd -- --api=http://127.0.0.1:9011
##
## Alone: two desktop copies in one process, each with its own world,
## builder, model store and account (throwaway ones at Resend's test
## addresses, signed in by the password grant as tools/web/session.mjs signs
## a flow's in). The first opens the house and starts a session; the second
## joins by the link and has the house part for part, its file byte for
## byte. Then 60 edits, 30 each, interleaved and made as the keys make them
## (Together.check_edit: the builder's own place, move, paint and delete)
## with undos among them; the same part moved by both at once; and once
## nothing is on its way, the same file on both. Each side's undo takes back
## its own step, and leaves a part the other changed since.
##
## With --join=<link> (tools/web/together_flow.mjs runs it so), the desktop
## joins a session a browser started, makes --edits=N of its own, and writes
## {seq, hash, waiting} to --out=FILE twice a second until the session ends;
## its account is --email (signed in by the password grant).
##
## Not in the suite: it needs the relay with .env's keys (tools/suite/out.txt).
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _api: String = ""
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool, more: String = "") -> void:
	print("  %s  %s%s" % ["ok  " if ok else "FAIL", what, "  (%s)" % more if not more.is_empty() else ""])
	if not ok:
		_failures += 1


static func _arg(name: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(name + "="):
			return argument.substr(name.length() + 1)
	return ""


func _run() -> void:
	await process_frame
	_api = _arg("--api")
	if _api.is_empty() or SignInHelper.env("SUPABASE_SECRET_KEY").is_empty():
		print("together probe: SKIPPED (needs --api= and .env's keys)")
		quit(0)
		return
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("together probe: no catalogue")
		quit(1)
		return
	_rng.seed = int(_arg("--seed")) if not _arg("--seed").is_empty() else 233
	if not _arg("--join").is_empty():
		await _join_alone()
	else:
		await _pair()
	print("")
	print("together probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)


## One copy of the app, headless: its world, builder, store and Together.
func _side(email: String) -> Dictionary:
	var world := BrickWorld.new()
	world.library = _library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	root.add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = _library
	store.builder = builder
	store.keeps = false
	var account: Account = await _signed_in(email)
	var together := Together.new()
	together.world = world
	together.builder = builder
	together.store = store
	together.account = account
	together.base_url = _api
	# Two copies in one process share a tab: neither keeps its place in it.
	together.keeps_place = false
	if not OS.get_environment("BW_BYPASS").is_empty():
		together.extra_headers = PackedStringArray(["x-vercel-protection-bypass: " + OS.get_environment("BW_BYPASS")])
	together.said.connect(func(words: String) -> void: print("        [%s] %s" % [email.get_slice("+", 1).get_slice("@", 0), words]))
	root.add_child(together)
	return {"world": world, "builder": builder, "store": store, "account": account, "together": together}


## An account signed in by the password grant, as a flow's are.
func _signed_in(email: String) -> Account:
	var account := Account.new()
	account.keeps = false
	root.add_child(account)
	var url: String = SignInHelper.env("SUPABASE_URL").rstrip("/")
	var secret: String = SignInHelper.env("SUPABASE_SECRET_KEY")
	var key: String = SignInHelper.env("SUPABASE_PUBLISHABLE_KEY")
	var hmac := HMACContext.new()
	hmac.start(HashingContext.HASH_SHA256, secret.to_utf8_buffer())
	hmac.update(("brickworks test session " + email.to_lower()).to_utf8_buffer())
	var password: String = Marshalls.raw_to_base64(hmac.finish()).replace("+", "-").replace("/", "_") \
		.replace("=", "") + "-Aa1"
	await SignInHelper.admin(root, HTTPClient.METHOD_POST, "/auth/v1/admin/users",
		JSON.stringify({"email": email, "password": password, "email_confirm": true}))
	var http := HTTPRequest.new()
	root.add_child(http)
	http.request(url + "/auth/v1/token?grant_type=password", PackedStringArray([
		"apikey: " + key, "content-type: application/json"]), HTTPClient.METHOD_POST,
		JSON.stringify({"email": email, "password": password}))
	var done: Array = await http.request_completed
	http.queue_free()
	var body: Variant = JSON.parse_string((done[3] as PackedByteArray).get_string_from_utf8())
	if not body is Dictionary or str((body as Dictionary).get("access_token", "")).is_empty():
		print("        could not sign %s in: %d" % [email, int(done[1])])
		return account
	account._url = url
	account._key = key
	account._keep(body as Dictionary)
	account.state = Account.State.SIGNED_IN
	# 13 or over, as a flow's accounts answer (tools/web/session.mjs), so it
	# may chat.
	await SignInHelper.admin(root, HTTPClient.METHOD_POST, "/rest/v1/rpc/answer_age",
		JSON.stringify({"account": account.user_id, "at_least_13": true}))
	return account


func _settle(sides: Array, ms: int = 15000) -> bool:
	# Long enough for the model's own state to be read for a change.
	var read_by: int = Time.get_ticks_msec() + Together.META_MS * 2
	while Time.get_ticks_msec() < read_by:
		await process_frame
	var until: int = Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await process_frame
		var top: int = 0
		var quiet: bool = true
		for side: Dictionary in sides:
			var together: Together = side["together"]
			quiet = quiet and together.waiting() == 0
			top = maxi(top, together.seq)
		for side: Dictionary in sides:
			quiet = quiet and (side["together"] as Together).seq == top
		if quiet:
			# One more round of polls, for anything numbered meanwhile.
			for n: int in 20:
				await process_frame
			return true
	return false


func _random_edit(together: Together, own: Array) -> Dictionary:
	var uids: Array = together.uids()
	var roll: float = _rng.randf()
	if roll < 0.3 or uids.is_empty():
		var edit: Dictionary = {"op": "place", "part": ["3001", "3003", "3004", "3010"][_rng.randi() % 4],
			"colour": [1, 2, 4, 14, 15][_rng.randi() % 5],
			"x": 400 + 80 * _rng.randi_range(0, 20), "y": 24 * _rng.randi_range(2, 8),
			"z": 400 + 80 * _rng.randi_range(0, 20)}
		var got: Dictionary = await together.check_edit(edit)
		if bool(got.get("ok", false)):
			own.append(str(got["uid"]))
		return got
	var uid: String = uids[_rng.randi() % uids.size()]
	if roll < 0.6:
		return await together.check_edit({"op": "move", "uid": uid,
			"by": [_rng.randi_range(-3, 3) * 10, _rng.randi_range(0, 2) * 12, _rng.randi_range(-3, 3) * 10]})
	if roll < 0.8:
		return await together.check_edit({"op": "paint", "uid": uid, "colour": [1, 2, 4, 14, 15, 0][_rng.randi() % 6]})
	if roll < 0.9:
		return await together.check_edit({"op": "delete", "uid": uid})
	return await together.check_edit({"op": "undo"})


func _pair() -> void:
	var stamp: int = int(Time.get_unix_time_from_system())
	var a: Dictionary = await _side("delivered+bwtogethera%d@resend.dev" % stamp)
	var b: Dictionary = await _side("delivered+bwtogetherb%d@resend.dev" % stamp)
	var ta: Together = a["together"]
	var tb: Together = b["together"]
	print("1. start and join")
	var opened: Dictionary = (a["store"] as ModelStore).open_text(
		FileAccess.get_file_as_string("res://models/house.ldr"), "Together house")
	(a["store"] as ModelStore).title = "Together house"
	_check("the owner's house opens", int(opened.get("placed", 0)) > 10, str(opened.get("placed", 0)))
	var trouble: String = await ta.start()
	_check("the owner starts a session and has a link", trouble.is_empty() and ta.live and ta.link.contains("together="),
		trouble)
	trouble = await tb.join(ta.link)
	_check("the second joins by the link", trouble.is_empty() and tb.live, trouble)
	await _settle([a, b])
	_check("both have the house, byte for byte", ta.model_hash() == tb.model_hash(),
		"%d and %d parts" % [(a["world"] as BrickWorld).brick_count(), (b["world"] as BrickWorld).brick_count()])
	_check("each is shown the other: %s" % str(tb.people.map(func(p: Dictionary) -> String: return p["name"])),
		tb.people.size() == 2)

	print("2. sixty edits, both at once")
	var mine_a: Array = []
	var mine_b: Array = []
	var made: int = 0
	for n: int in 30:
		if bool((await _random_edit(ta, mine_a)).get("ok", false)):
			made += 1
		if bool((await _random_edit(tb, mine_b)).get("ok", false)):
			made += 1
		for k: int in _rng.randi_range(0, 3):
			await process_frame
	var settled: bool = await _settle([a, b], 30000)
	_check("%d of 60 edits made; every change came back numbered" % made, settled and made > 30)
	_check("the same file on both, byte for byte", ta.model_hash() == tb.model_hash(),
		"%d and %d parts, seq %d" % [(a["world"] as BrickWorld).brick_count(), (b["world"] as BrickWorld).brick_count(), ta.seq])

	print("3. the same part moved by both at once")
	# A part of the owner's, out where nothing is in its way, on both.
	var fresh: Dictionary = await ta.check_edit({"op": "place", "part": "3001", "colour": 1, "x": -1600, "y": 96, "z": -1600})
	await _settle([a, b])
	var both: String = str(fresh.get("uid", ""))
	var got_a: Dictionary = await ta.check_edit({"op": "move", "uid": both, "by": [10, 0, 0]})
	var got_b: Dictionary = await tb.check_edit({"op": "move", "uid": both, "by": [0, 0, 30]})
	await _settle([a, b])
	var at_a: Transform3D = (a["world"] as BrickWorld).get_brick(ta.brick_of(both)).transform
	var at_b: Transform3D = (b["world"] as BrickWorld).get_brick(tb.brick_of(both)).transform
	_check("both moved it, and it ends in one place on both", bool(got_a["ok"]) and bool(got_b["ok"]) and at_a == at_b
		and ta.model_hash() == tb.model_hash(), "%s, %s, %s" % [str(at_a.origin), str(got_a), str(got_b)])

	print("4. each undo is its own")
	var placed: Dictionary = await ta.check_edit({"op": "place", "part": "3001", "colour": 4, "x": -800, "y": 0, "z": -800})
	await _settle([a, b])
	var painted: Dictionary = await tb.check_edit({"op": "paint", "uid": both, "colour": 14})
	await _settle([a, b])
	var undone: Dictionary = await ta.check_edit({"op": "undo"})
	await _settle([a, b])
	_check("the owner's undo takes back the owner's part: %s" % str(undone.get("words", "")),
		bool(undone["ok"]) and tb.brick_of(str(placed["uid"])) == 0 and ta.brick_of(str(placed["uid"])) == 0)
	_check("...and leaves the other's paint", bool(painted["ok"])
		and (b["world"] as BrickWorld).get_brick(tb.brick_of(both)).color_code == 14
		and (a["world"] as BrickWorld).get_brick(ta.brick_of(both)).color_code == 14)
	# The joiner's undo of its paint, after the owner moved that part since:
	# the paint is undone only where the part is still as the paint left it.
	var moved: Dictionary = await ta.check_edit({"op": "move", "uid": both, "by": [0, 12, 0]})
	await _settle([a, b])
	var left: Dictionary = await tb.check_edit({"op": "undo"})
	await _settle([a, b])
	_check("an undo leaves a part the other changed since: %s" % str(left.get("words", "")),
		bool(moved["ok"]) and str(left.get("words", "")).contains("left 1 part")
		and (a["world"] as BrickWorld).get_brick(ta.brick_of(both)).color_code == 14)
	_check("the same file on both after it all", ta.model_hash() == tb.model_hash())

	print("4b. the model's own state, each kind from either side")
	var sa: ModelStore = a["store"]
	var sb: ModelStore = b["store"]
	await ta.check_edit({"op": "title", "title": "Together house, renamed"})
	await _settle([a, b])
	_check("a name typed on one side is the other's: %s" % sb.title, sb.title == "Together house, renamed")
	sb.model_floor = ModelFloor.parse(ModelFloor.make(ModelFloor.BASEPLATE, 48, 48, 2).whole_words())
	await _settle([a, b], 15000)
	_check("a floor chosen on the other side is the owner's: %s" % sa.model_floor.whole_words(),
		sa.model_floor.whole_words() == sb.model_floor.whole_words())
	(b["world"] as BrickWorld).step_looks = {BookletLooks.key("", 2): {"zoom": 1.5}}
	sa.hidden_scheme = {"mode": "stages", "stages": 2}
	await _settle([a, b], 15000)
	_check("the booklet's looks and the hidden colours, each from one side, are both sides'",
		(a["world"] as BrickWorld).step_looks == {BookletLooks.key("", 2): {"zoom": 1.5}} and sb.hidden_scheme == {"mode": "stages", "stages": 2})
	_check("the same file on both, byte for byte", ta.model_hash() == tb.model_hash())
	var said: Dictionary = await ta.check_edit({"op": "chat", "text": "Roof next?"})
	await _settle([a, b])
	var heard: Array = tb.messages.map(func(m: Dictionary) -> String: return "%s: %s" % [m["name"], m["text"]])
	_check("a chat line reaches the other: %s" % str(heard), bool(said["ok"]) and heard.has("The owner: Roof next?"))

	print("5. the owner ends it")
	await ta.end()
	var until: int = Time.get_ticks_msec() + 30000
	while tb.live and Time.get_ticks_msec() < until:
		await process_frame
	_check("the other side is told, and keeps what was built", not tb.live
		and (b["world"] as BrickWorld).brick_count() == (a["world"] as BrickWorld).brick_count(), tb.ended_words)
	var gone: int = await SignInHelper.delete_accounts("delivered+bwtogether", root)
	print("  (%d throwaway accounts deleted)" % gone)


## The desktop's half of tools/web/together_flow.mjs: joined to a browser's
## session, a few edits of its own, and what it has written out as it goes.
func _join_alone() -> void:
	var email: String = _arg("--email")
	if email.is_empty():
		email = "delivered+bwtogetherd%d@resend.dev" % int(Time.get_unix_time_from_system())
	var side: Dictionary = await _side(email)
	var together: Together = side["together"]
	var out: String = _arg("--out")
	var trouble: String = await together.join(_arg("--join"))
	_check("the desktop joins the browser's session", trouble.is_empty() and together.live, trouble)
	var edits: int = int(_arg("--edits")) if not _arg("--edits").is_empty() else 0
	var own: Array = []
	var made: int = 0
	var next_edit: int = Time.get_ticks_msec() + 2000
	var written: int = 0
	var until: int = Time.get_ticks_msec() + int(_arg("--seconds") if not _arg("--seconds").is_empty() else "600") * 1000
	while together.live and Time.get_ticks_msec() < until:
		await process_frame
		if made < edits and Time.get_ticks_msec() > next_edit:
			if bool((await _random_edit(together, own)).get("ok", false)):
				made += 1
			next_edit = Time.get_ticks_msec() + 700
		if not out.is_empty() and Time.get_ticks_msec() - written > 500:
			written = Time.get_ticks_msec()
			var file := FileAccess.open(out, FileAccess.WRITE)
			file.store_string(JSON.stringify({"live": true, "seq": together.seq, "waiting": together.waiting(),
				"hash": together.model_hash(), "made": made, "parts": together.uids().size(),
				"messages": together.messages.map(func(m: Dictionary) -> String: return "%s: %s" % [m["name"], m["text"]]),
				"chat_words": together.chat_words, "healed": together.timing.get("healed", 0),
				"healed_last": together.timing.get("healed_last", [])}))
			file.close()
	if not out.is_empty():
		var file := FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify({"live": false, "seq": together.seq, "hash": together.model_hash(),
			"made": made, "ended": together.ended_words, "text": together.model_text()}))
		file.close()
	_check("made %d edits of its own, and was told the session ended" % made, made == edits and not together.live,
		together.ended_words)
