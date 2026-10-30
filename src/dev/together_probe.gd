## Building together from the desktop's side (src/net/together.gd): do two
## copies of the app build one model at once and stay the same, and does a
## desktop copy join a session a browser started?
##
##   set -a; . ./.env; set +a
##   node tools/web/relay_server.mjs 9011 --hold=together_sessions,together_ops,together_people,together_snapshot_parts &
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
## Then what each sees of the other (B8): the parts one selects outlined
## on the other side in its colour, Follow taking the other's view with it
## until it is moved, and the time a pointer takes to cross; a comment
## pinned to a part on one side seen on the other, resolved there, and
## still on its part after the file is written and opened again; changes
## held on their way when a copy goes (a page reloaded) sent again by the
## copy that comes back in its place, and on both sides after. Last, a model
## of 25,600 parts, its snapshot over 4 MB, starts a session in parts and
## the other has it byte for byte (--big=no leaves that out; it needs
## supabase/together_big.sql, or the relay holding together_snapshot_parts).
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


## One copy of the app, headless: its world, builder, store, view and
## Together; [param signed] an account already signed in, else one made.
func _side(email: String, signed: Account = null) -> Dictionary:
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
	var account: Account = signed if signed != null else await _signed_in(email)
	var camera := CadCamera.new()
	root.add_child(camera)
	var together := Together.new()
	together.world = world
	together.builder = builder
	together.store = store
	together.account = account
	together.camera = camera
	together.base_url = _api
	# Two copies in one process share a tab: neither keeps its place in it.
	together.keeps_place = false
	if not OS.get_environment("BW_BYPASS").is_empty():
		together.extra_headers = PackedStringArray(["x-vercel-protection-bypass: " + OS.get_environment("BW_BYPASS")])
	together.said.connect(func(words: String) -> void: print("        [%s] %s" % [email.get_slice("+", 1).get_slice("@", 0), words]))
	root.add_child(together)
	return {"world": world, "builder": builder, "store": store, "account": account, "together": together,
		"camera": camera}


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

	await _seeing(a, b)
	await _pins(a, b)
	b = await _reload(a, b)
	tb = b["together"]

	print("5. the owner ends it")
	await ta.end()
	var until: int = Time.get_ticks_msec() + 30000
	while tb.live and Time.get_ticks_msec() < until:
		await process_frame
	_check("the other side is told, and keeps what was built", not tb.live
		and (b["world"] as BrickWorld).brick_count() == (a["world"] as BrickWorld).brick_count(), tb.ended_words)
	await _again(a, b)
	if _arg("--big") != "no":
		await _big(a, b)
	var gone: int = await SignInHelper.delete_accounts("delivered+bwtogether", root)
	print("  (%d throwaway accounts deleted)" % gone)


## Until [param test] is true or [param ms] pass; how long it took, or -1.
func _within(test: Callable, ms: int = 5000) -> int:
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < ms:
		if test.call():
			return Time.get_ticks_msec() - began
		await process_frame
	return -1


func _who_of(side: Dictionary) -> String:
	return str((side["together"] as Together).me().get("who", ""))


func _seeing(a: Dictionary, b: Dictionary) -> void:
	print("4c. where each other is working")
	var ta: Together = a["together"]
	var tb: Together = b["together"]
	var a_who: String = _who_of(a)
	# A's selection, two parts, outlined on B's side in A's colour.
	var two: Array = ta.uids().slice(0, 2)
	await ta.check_edit({"op": "select", "uids": two})
	var took: int = await _within(func() -> bool: return int(tb.selections_shown().get(a_who, 0)) == 2)
	_check("the owner's two selected parts are outlined on the other side in %s, in %d ms"
		% [tb.colour_of(a_who).to_html(false), took], took >= 0 and tb.colour_of(a_who) == ta.colour_of(a_who))
	await ta.check_edit({"op": "select", "uids": []})
	took = await _within(func() -> bool: return int(tb.selections_shown().get(a_who, 0)) == 0)
	_check("...and gone there once nothing is selected", took >= 0)
	# Pointers: where the owner points, moved twenty times.
	var times: Array = []
	for n: int in 20:
		var here := Vector3(40.0 * n, 24.0, -40.0 * n)
		ta.pointer_at = func() -> Variant: return here
		var seen: int = await _within(func() -> bool:
			var them: Dictionary = tb._person(a_who)
			return them.get("at") is Array and is_equal_approx(float(them["at"][0]), here.x), 5000)
		if seen >= 0:
			times.append(seen)
		await process_frame
	times.sort()
	_check("the owner's pointer crosses 20 of 20 times: p50 %d ms, p95 %d ms" % [
		times[times.size() / 2] if not times.is_empty() else -1,
		times[mini(times.size() - 1, int(times.size() * 0.95))] if not times.is_empty() else -1],
		times.size() == 20 and int(times[mini(times.size() - 1, int(times.size() * 0.95))]) < 1000)
	ta.pointer_at = Callable()
	# Follow: B's view goes where A's goes, until B moves it.
	var view := {"yaw": 0.7, "pitch": -0.4, "distance": 900.0, "focus": [40.0, 30.0, -20.0], "size": 0.0}
	await ta.check_edit({"op": "view", "view": view})
	var trouble: String = (await tb.check_edit({"op": "follow", "who": a_who})).get("words", "")
	var cam_b: CadCamera = b["camera"]
	took = await _within(func() -> bool: return Together._same_view(cam_b.aim(), (a["camera"] as CadCamera).aim()))
	_check("Follow on the owner's name takes the other's view to the owner's, in %d ms" % took,
		trouble.is_empty() and took >= 0 and tb.following == a_who, trouble)
	view["yaw"] = 1.9
	view["focus"] = [-200.0, 30.0, 100.0]
	await ta.check_edit({"op": "view", "view": view})
	took = await _within(func() -> bool: return Together._same_view(cam_b.aim(), (a["camera"] as CadCamera).aim()))
	_check("...and follows it as the owner turns, in %d ms" % took, took >= 0)
	cam_b.aim_at({"yaw": -1.0, "pitch": -0.2, "distance": 700.0, "focus": [0.0, 0.0, 0.0], "size": 0.0})
	took = await _within(func() -> bool: return tb.following.is_empty(), 2000)
	view["yaw"] = 2.6
	await ta.check_edit({"op": "view", "view": view})
	await _within(func() -> bool: return false, 1500)
	_check("the other moving the view stops it, and the owner's next turn moves it no more",
		took >= 0 and not Together._same_view(cam_b.aim(), (a["camera"] as CadCamera).aim()))


func _pins(a: Dictionary, b: Dictionary) -> void:
	print("4d. a comment pinned to a part")
	var ta: Together = a["together"]
	var tb: Together = b["together"]
	var on: String = ta.uids()[3]
	var pinned: Dictionary = await ta.check_edit({"op": "pin", "uid": on, "text": "Is this wall tall enough?"})
	var id: String = str(pinned.get("id", ""))
	await _settle([a, b])
	var there: PinnedComments.Pin = (b["store"] as ModelStore).pins.named(id)
	_check("pinned on one side, it is on the other, on the same part", bool(pinned.get("ok", false))
		and there != null and tb.uid_of(there.brick) == on and there.text == "Is this wall tall enough?",
		str(pinned))
	_check("...and in both files, byte for byte", ta.model_hash() == tb.model_hash()
		and ta.model_text().contains(PinnedComments.META))
	var resolved: Dictionary = await tb.check_edit({"op": "resolve", "id": id})
	await _settle([a, b])
	var here: PinnedComments.Pin = (a["store"] as ModelStore).pins.named(id)
	_check("resolved on the other side, it is resolved on the owner's", bool(resolved.get("ok", false))
		and here != null and here.resolved and ta.model_hash() == tb.model_hash())
	# Both pin at once: both kept.
	var one: Dictionary = await ta.check_edit({"op": "pin", "uid": ta.uids()[4], "text": "Roof next"})
	var two: Dictionary = await tb.check_edit({"op": "pin", "uid": tb.uids()[5], "text": "Door here?"})
	await _settle([a, b])
	_check("two pinned at once, both kept on both sides: %d and %d" % [(a["store"] as ModelStore).pins.list.size(),
		(b["store"] as ModelStore).pins.list.size()], (a["store"] as ModelStore).pins.named(str(one.get("id"))) != null
		and (a["store"] as ModelStore).pins.named(str(two.get("id"))) != null and ta.model_hash() == tb.model_hash())
	# Written and opened again: on its part still.
	var text: String = ta.model_text()
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
	store.open_text(text, "again")
	var again: PinnedComments.Pin = store.pins.named(id)
	var brick: BrickWorld.Brick = world.get_brick(PinnedComments.find(again, world, store.lift())) if again != null else null
	var was: BrickWorld.Brick = (a["world"] as BrickWorld).get_brick(ta.brick_of(on))
	_check("the file opened again has the three, the first resolved and on its part",
		store.pins.list.size() == 3 and again != null and again.resolved and brick != null and was != null
		and brick.part_id == was.part_id and brick.transform.origin.is_equal_approx(was.transform.origin - (a["store"] as ModelStore).lift() + store.lift()))
	world.queue_free()
	builder.queue_free()


## A copy going in the middle of a change, as a page reloaded does, and one
## coming back in its place: the changes it held are sent then.
func _reload(a: Dictionary, b: Dictionary) -> Dictionary:
	print("4e. a page goes with changes on their way, and comes back")
	var ta: Together = a["together"]
	var tb: Together = b["together"]
	TabSession.use("tgthrbk")
	DirAccess.make_dir_recursive_absolute(TabSession.ROOT + "tgthrbk")
	tb.keeps_place = true
	tb._keep_place()
	# Two parts of the owner's, out where nothing is in their way.
	var red: String = str((await ta.check_edit({"op": "place", "part": "3001", "colour": 4, "x": -2000, "y": 48, "z": 0})).get("uid", ""))
	var blue: String = str((await ta.check_edit({"op": "place", "part": "3001", "colour": 1, "x": -2000, "y": 48, "z": 400})).get("uid", ""))
	await _settle([a, b])
	await tb.check_edit({"op": "hold", "on": true})
	var placed: Dictionary = await tb.check_edit({"op": "place", "part": "3003", "colour": 2, "x": -1200, "y": 48, "z": 400})
	var painted: Dictionary = await tb.check_edit({"op": "paint", "uid": red, "colour": 15})
	var moved: Dictionary = await tb.check_edit({"op": "move", "uid": blue, "by": [10, 0, 0]})
	var waiting: int = tb.waiting()
	# Gone: no word to the server, nothing more sent.
	tb._polling += 1
	tb.live = false
	tb.set_process(false)
	await _within(func() -> bool: return false, 1500)
	_check("three changes held on their way when the copy goes (%d waiting); the owner has none of them" % waiting,
		bool(placed["ok"]) and bool(painted["ok"]) and bool(moved["ok"]) and waiting >= 3
		and ta.brick_of(str(placed.get("uid", ""))) == 0)
	var back: Dictionary = await _side("", b["account"] as Account)
	var tc: Together = back["together"]
	tc.keeps_place = true
	var trouble: String = await tc.join(Together.kept_secret(), true)
	await _settle([a, back], 30000)
	_check("the copy back in its place sends them again, and both have them: %s" % str(tc.timing.get("restored", 0)),
		trouble.is_empty() and ta.brick_of(str(placed.get("uid", ""))) != 0
		and (a["world"] as BrickWorld).get_brick(ta.brick_of(red)).color_code == 15
		and (a["world"] as BrickWorld).get_brick(ta.brick_of(blue)).transform.origin.x > -2000.0
		and ta.model_hash() == tc.model_hash(), trouble)
	tc.keeps_place = false
	return back


## A session begun again on the model as the last one left it, with build
## steps of its own (a part put in a step of its own, as edit_steps's
## "new" does), in one request and in parts.
func _again(a: Dictionary, b: Dictionary) -> void:
	print("5b. a session begun again on the model as it is now")
	var ta: Together = a["together"]
	var tb: Together = b["together"]
	var world: BrickWorld = a["world"]
	# Someone else's file (the car's author's), written back as it was with
	# what changed: a part moved, one put in a step of its own.
	(a["store"] as ModelStore).open_text(FileAccess.get_file_as_string("res://models/car.ldr"), "Together car")
	(a["store"] as ModelStore).title = "Together car"
	for brick: BrickWorld.Brick in world.bricks():
		brick.step = 0
	world.bricks()[3].step = 1
	var moving: BrickWorld.Brick = world.bricks()[5]
	world.move_brick(moving.id, moving.transform.translated(Vector3(0, 0, 40)))
	world.revision += 1
	for in_parts: bool in [false, true]:
		ta.parts_above = 1000 if in_parts else 3_500_000
		ta.part_chars = 10_000 if in_parts else 2_000_000
		var trouble: String = await ta.start()
		if trouble.is_empty():
			trouble = await tb.join(ta.link)
		await _settle([a, b], 30000)
		var mine: PackedStringArray = ta.model_text().split("\n")
		var theirs: PackedStringArray = tb.model_text().split("\n")
		var apart: int = -1
		for n: int in maxi(mine.size(), theirs.size()):
			if n >= mine.size() or n >= theirs.size() or mine[n] != theirs[n]:
				apart = n
				break
		_check("%s: the other joins and has it byte for byte, its steps too (%d STEP lines)" % [
			"in %d parts" % int(ta.timing.get("parts", 0)) if in_parts else "in one request",
			ta.model_text().count("0 STEP")], trouble.is_empty() and ta.model_hash() == tb.model_hash(),
			trouble if not trouble.is_empty() else "line %d: %s / %s" % [apart,
				mine[apart] if apart >= 0 and apart < mine.size() else "-",
				theirs[apart] if apart >= 0 and apart < theirs.size() else "-"])
		await ta.end()
		var until: int = Time.get_ticks_msec() + 30000
		while tb.live and Time.get_ticks_msec() < until:
			await process_frame
	ta.parts_above = 3_500_000
	ta.part_chars = 2_000_000


## A model whose snapshot is over 4 MB starts a session, in parts.
func _big(a: Dictionary, b: Dictionary) -> void:
	print("6. a model over 4 MB")
	var ta: Together = a["together"]
	var tb: Together = b["together"]
	var lines := PackedStringArray(["0 Big plate field", "0 Name: big.ldr", "0 Author: Brickworks"])
	for x: int in 160:
		for z: int in 160:
			lines.append("1 %d %d 0 %d 1 0 0 0 1 0 0 0 1 3024.dat" % [[1, 4, 14, 2][(x + z) % 4], x * 20, z * 20])
	var opened: Dictionary = (a["store"] as ModelStore).open_text("\n".join(lines) + "\n", "Big plate field")
	(a["store"] as ModelStore).title = "Big plate field"
	var began: int = Time.get_ticks_msec()
	var trouble: String = await ta.start()
	var snapshot: int = JSON.stringify({"text": ta.model_text()}).length()
	_check("%d parts, a snapshot over 4 MB, start a session in %d parts in %d ms" % [int(opened.get("placed", 0)),
		int(ta.timing.get("parts", 0)), Time.get_ticks_msec() - began], trouble.is_empty() and ta.live
		and int(ta.timing.get("parts", 0)) >= 2, trouble)
	if not ta.live:
		return
	began = Time.get_ticks_msec()
	trouble = await tb.join(ta.link)
	await _settle([a, b], 60000)
	_check("the other joins and has it byte for byte, in %d ms (%d parts read)" % [Time.get_ticks_msec() - began,
		int(tb.timing.get("parts", 0))], trouble.is_empty() and tb.live
		and (b["world"] as BrickWorld).brick_count() == (a["world"] as BrickWorld).brick_count()
		and ta.model_hash() == tb.model_hash(), trouble)
	var moved: Dictionary = await tb.check_edit({"op": "move", "uid": ta.uids()[100], "by": [0, 8, 0]})
	await _settle([a, b], 30000)
	_check("...and a change on it crosses", bool(moved.get("ok", false)) and ta.model_hash() == tb.model_hash())
	await ta.end()
	print("  (snapshot text alone %d characters)" % snapshot)


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
			# The file as of the change it last put down, beside the line, so
			# a check that finds it apart can say how.
			var text_now: String = together.model_text()
			var beside := FileAccess.open(out + ".ldr", FileAccess.WRITE)
			beside.store_string(text_now)
			beside.close()
			var file := FileAccess.open(out, FileAccess.WRITE)
			file.store_string(JSON.stringify({"live": true, "seq": together.seq, "waiting": together.waiting(),
				"hash": text_now.sha256_text(), "made": made, "parts": together.uids().size(),
				"messages": together.messages.map(func(m: Dictionary) -> String: return "%s: %s" % [m["name"], m["text"]]),
				"chat_words": together.chat_words, "healed": together.timing.get("healed", 0),
				"healed_last": together.timing.get("healed_last", []),
				"pins": (together.store.pins.list as Array).map(func(pin: PinnedComments.Pin) -> String: return pin.text)}))
			file.close()
	if not out.is_empty():
		var file := FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify({"live": false, "seq": together.seq, "hash": together.model_hash(),
			"made": made, "ended": together.ended_words, "text": together.model_text()}))
		file.close()
	_check("made %d edits of its own, and was told the session ended" % made, made == edits and not together.live,
		together.ended_words)
