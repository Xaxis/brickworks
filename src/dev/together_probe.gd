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
## copy that comes back in its place, and on both sides after; and one on
## its way as the app quits, sent in the quit. Last, a model
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
	# A scheme as the panel makes one (HiddenColours.Plan.scheme): another
	# side's is read only in that shape.
	var scheme: Dictionary = {"mode": "stages", "groups": [{"label": "Stage 2", "colour": 14, "also": [71],
		"sections": ["Stage 2"]}]}
	sa.hidden_scheme = scheme.duplicate(true)
	await _settle([a, b], 15000)
	_check("the booklet's looks and the hidden colours, each from one side, are both sides'",
		(a["world"] as BrickWorld).step_looks == {BookletLooks.key("", 2): {"zoom": 1.5}} and sb.hidden_scheme == scheme)
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
	await _sub_lines(a, b)
	await _copies_at_once(a, b)
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
	var trouble: String = await tc.join(TogetherLink.kept_secret(), true)
	await _settle([a, back], 30000)
	_check("the copy back in its place sends them again, and both have them: %s" % str(tc.timing.get("restored", 0)),
		trouble.is_empty() and ta.brick_of(str(placed.get("uid", ""))) != 0
		and (a["world"] as BrickWorld).get_brick(ta.brick_of(red)).color_code == 15
		and (a["world"] as BrickWorld).get_brick(ta.brick_of(blue)).transform.origin.x > -2000.0
		and ta.model_hash() == tc.model_hash(), trouble)

	print("4f. the app quits with a change on its way")
	# Held, as above, so only the quit itself can send it: the copy taken out
	# of the tree, as the app's quit takes it (Together._exit_tree).
	await tc.check_edit({"op": "hold", "on": true})
	var last: Dictionary = await tc.check_edit({"op": "place", "part": "3003", "colour": 4, "x": -1200, "y": 48, "z": 800})
	var queued: int = tc.waiting()
	var quitting: int = Time.get_ticks_msec()
	tc.get_parent().remove_child(tc)
	var quit_ms: int = Time.get_ticks_msec() - quitting
	var took: int = await _within(func() -> bool: return ta.brick_of(str(last.get("uid", ""))) != 0, 10000)
	_check("a change on its way as the app quits (%d waiting) is sent in the quit (%d ms), the owner has it %d ms after"
		% [queued, quit_ms, took], bool(last.get("ok", false)) and queued >= 1 and took >= 0
		and quit_ms <= Together.GOODBYE_MS + 500)
	var again: Dictionary = await _side("", b["account"] as Account)
	var td: Together = again["together"]
	td.keeps_place = true
	trouble = await td.join(TogetherLink.kept_secret(), true)
	await _settle([a, again], 30000)
	_check("...and the app opened again is back in, with nothing left to send again (%d restored)"
		% int(td.timing.get("restored", 0)), trouble.is_empty() and ta.model_hash() == td.model_hash()
		and int(td.timing.get("restored", 0)) == 0, trouble)
	tc.queue_free()
	td.keeps_place = false
	return again


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


## A sub-model's own lights and views (BrickWorld.section_lines) are both
## sides': renamed on one side, the other writes them in it too, as each
## side's save writes the whole model; its last copy taken off on one side,
## both let them go with it, so a sub-model made again of that name on the
## other has none of them. Up to 2026-11-11 nothing carried them: a sub-model
## renamed on one side was written unlit on the other, and the lines of one
## taken off waited there for whatever next took its name.
func _sub_lines(a: Dictionary, b: Dictionary) -> void:
	print("5c. a sub-model's lights and views, renamed and taken off on one side")
	var ta: Together = a["together"]
	var tb: Together = b["together"]
	var green: String = "0 !BRICKWORKS LIGHT " + JSON.stringify({"kind": "point", "at": [0, -50, 0],
		"aim": [0, 1, 0], "colour": "#00ff00", "strength": 1, "size": 4, "shadows": true})
	var blue: String = green.replace("#00ff00", "#0000aa")
	var view: String = "0 !BRICKWORKS VIEW " + JSON.stringify({"name": "sub view", "yaw": 10,
		"pitch": -20, "distance": 300, "focus": [0, 0, 0]})
	var text: String = "\n".join(PackedStringArray(["0 FILE main.ldr", "0 Together lit",
		"0 Name: main.ldr", "0 Author: Brickworks", "1 16 100 0 0 1 0 0 0 1 0 0 0 1 sub.ldr",
		"1 16 -100 0 0 1 0 0 0 1 0 0 0 1 lamp.ldr", "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 NOFILE",
		"0 FILE sub.ldr", "0 Sub", "0 Name: sub.ldr", "0 Author: Brickworks", green, view,
		"1 14 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat", "0 NOFILE", "0 FILE lamp.ldr", "0 Lamp",
		"0 Name: lamp.ldr", "0 Author: Brickworks", blue, "1 2 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"0 NOFILE", ""]))
	# Main's own part after its copies, as the app writes it: each side
	# numbers its parts in the order it read them, and the order a file lists
	# copies follows those numbers (AuthorSteps.first_under), so a Make on one
	# side of a file read in another order lists its copies the other way.
	(a["store"] as ModelStore).open_text(text, "Together lit")
	(a["store"] as ModelStore).title = "Together lit"
	var trouble: String = await ta.start()
	if trouble.is_empty():
		trouble = await tb.join(ta.link)
	await _settle([a, b])
	var tree := Assemblies.new()
	tree.world = a["world"]
	tree.builder = a["builder"]
	tree.library = _library
	tree.scenery = (a["store"] as ModelStore).scenery
	var sub: String = ""
	for path: String in tree.paths():
		if Assemblies.definition(path) == "Sub":
			sub = path
	tree.rename(sub, "Engine")
	await _settle([a, b])
	var theirs: String = tb.model_text()
	var engine: String = theirs.substr(theirs.find("0 FILE engine.ldr"))
	_check("Sub renamed Engine on the owner's side: the other writes its light and view in Engine, "
		+ "and the two files are one", trouble.is_empty() and theirs.find("0 FILE engine.ldr") > 0
		and engine.contains("#00ff00") and engine.contains("sub view") and not theirs.contains("0 FILE sub.ldr")
		and ta.model_hash() == tb.model_hash(), trouble if not trouble.is_empty()
		else "%d light lines on the other side" % theirs.count("!BRICKWORKS LIGHT"))
	# Lamp's one part taken off on the other side, as Delete takes it.
	var gone: Dictionary = {}
	for brick: BrickWorld.Brick in (b["world"] as BrickWorld).bricks():
		if brick.color_code == 2:
			gone = await tb.check_edit({"op": "delete", "uid": tb.uid_of(brick.id)})
	await _settle([a, b])
	var held: Dictionary = {}
	for brick: BrickWorld.Brick in (a["world"] as BrickWorld).bricks():
		if brick.color_code == 4:
			held[brick.id] = true
	(a["builder"] as Builder).selection = held
	var made: String = tree.make("Lamp")
	await _settle([a, b])
	var lamp_lit: Array = [ta.model_text().contains("#0000aa"), tb.model_text().contains("#0000aa"),
		(a["world"] as BrickWorld).section_lines.has("Lamp"), (b["world"] as BrickWorld).section_lines.has("Lamp")]
	_check("Lamp's last copy taken off on the other side (%s): a Lamp made of another part on the "
		% str(gone.get("ok", false)) + "owner's (%s) has none of its light, on either side" % made,
		bool(gone.get("ok", false)) and made == "Lamp#1" and not lamp_lit[0] and not lamp_lit[1]
		and ta.model_hash() == tb.model_hash(), "its light in the owner's file and the other's %s, "
		% [lamp_lit.slice(0, 2)] + "Lamp's lines kept on each side %s, the files apart at %s"
		% [lamp_lit.slice(2), _apart(ta.model_text(), tb.model_text())])
	await ta.end()
	var until: int = Time.get_ticks_msec() + 30000
	while tb.live and Time.get_ticks_msec() < until:
		await process_frame


## Each copy of a lit sub-model is its own: where its lights stand goes with
## it ("~frame:<path>", Together._frame_words), so two people moving two
## copies at once both keep theirs, on both sides; a copy taken apart on one
## side while the other copy moves on the other, both undone, leaves one
## light; and a sub-model's lines longer than a session takes are said once,
## the rest still sent. Up to 2026-11-12 one key held every copy's frame:
## the later move put the other copy's lights back where they had been, 12
## LDU off its parts on both sides (pc2check T6), and the undos left the
## taken-apart copy's light in the model's beside its sub-model's (T7).
func _copies_at_once(a: Dictionary, b: Dictionary) -> void:
	print("5d. two copies of a lit sub-model, one moved on each side at once; one taken apart while the other moves;"
		+ " one taken apart on each side")
	var ta: Together = a["together"]
	var tb: Together = b["together"]
	var green: String = "0 !BRICKWORKS LIGHT " + JSON.stringify({"kind": "point", "at": [0, -50, 0],
		"aim": [0, 1, 0], "colour": "#00ff00", "strength": 1, "size": 4, "shadows": true})
	var text: String = "\n".join(PackedStringArray(["0 FILE main.ldr", "0 Together copies",
		"0 Name: main.ldr", "0 Author: Brickworks", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 sub.ldr",
		"1 16 0 0 400 -1 0 0 0 1 0 0 0 1 sub.ldr", "1 4 -600 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 NOFILE",
		"0 FILE sub.ldr", "0 Sub", "0 Name: sub.ldr", "0 Author: Brickworks", green,
		"1 14 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat", "1 15 60 0 40 1 0 0 0 1 0 0 0 1 3001.dat", "0 NOFILE", ""]))
	var heard: Array = []
	var hear: Callable = func(words: String) -> void: heard.append(words)
	ta.said.connect(hear)
	for round: int in 3:
		(a["store"] as ModelStore).open_text(text, "Together copies")
		(a["store"] as ModelStore).title = "Together copies"
		var trouble: String = await ta.start()
		if trouble.is_empty():
			trouble = await tb.join(ta.link)
		await _settle([a, b])
		var trees: Array = []
		for side: Dictionary in [a, b]:
			var tree := Assemblies.new()
			tree.world = side["world"]
			tree.builder = side["builder"]
			tree.library = _library
			tree.scenery = (side["store"] as ModelStore).scenery
			trees.append(tree)
		var copies: Array = [_subs(trees[0]), _subs(trees[1])]
		if round == 0:
			var was: Dictionary = (a["world"] as BrickWorld).section_frames.duplicate()
			var parts_was: Dictionary = _yellow_at(trees[0])
			_nudge(a, trees[0], str(copies[0][1]), Vector3i(6, 0, 0))
			_nudge(b, trees[1], str(copies[1][0]), Vector3i(0, 0, -6))
			await _settle([a, b], 30000)
			var parts_now: Dictionary = _yellow_at(trees[0])
			var followed: Array = []
			for side: Dictionary in [a, b]:
				var frames: Dictionary = (side["world"] as BrickWorld).section_frames
				for path: String in was:
					followed.append(frames.has(path) and parts_now.has(path) and ((frames[path] as Transform3D)
						.origin - (was[path] as Transform3D).origin).is_equal_approx(
						(parts_now[path] as Vector3) - (parts_was[path] as Vector3)))
			_check("each side moves one copy at once: on both sides each copy's lights stand where its "
				+ "own parts went, the two files one", trouble.is_empty() and followed.size() == 4
				and not followed.has(false) and ta.model_hash() == tb.model_hash(), trouble
				if not trouble.is_empty() else "%s; apart at %s" % [followed, _apart(ta.model_text(),
				tb.model_text())])
		elif round == 2:
			# One after the other: the first undone finds the model's lights
			# changed since, and goes back whole or not at all, said; the
			# second's goes. Up to 2026-11-12 its parts went back without its
			# lights, and the light was there twice (pc2check T7_3).
			var first: int = (trees[0] as Assemblies).ungroup(str(copies[0][0]))
			(a["store"] as ModelStore).looks_follow_edit()
			await _settle([a, b], 30000)
			var second: int = (trees[1] as Assemblies).ungroup(str(copies[1][1]))
			(b["store"] as ModelStore).looks_follow_edit()
			await _settle([a, b], 30000)
			var said: String = ta.undo()
			await _settle([a, b], 30000)
			var held: Array = [_subs(trees[0]).size(), _subs(trees[1]).size()]
			var again: String = tb.undo()
			await _settle([a, b], 30000)
			var lit: Array = [ta.model_text().count("#00ff00"), tb.model_text().count("#00ff00")]
			_check("a copy taken apart on each side, one after the other (%d, %d parts), the first undone: "
				% [first, second] + "held back whole and said (%s), its parts still apart (%s copies of Sub); "
				% [said, held] + "the second undone (%s): Sub's light and the first's, the two files one"
				% again, trouble.is_empty() and first > 0 and second > 0
				and said == "undid nothing: somebody else changed %s since" % TogetherWords.state_named("~lights")
				and held == [0, 0] and again.begins_with("undid") and not again.begins_with("undid nothing")
				and _subs(trees[0]).size() == 1 and _subs(trees[1]).size() == 1 and lit == [2, 2]
				and ta.model_hash() == tb.model_hash(), trouble if not trouble.is_empty()
				else "%s lights; apart at %s" % [lit, _apart(ta.model_text(), tb.model_text())])
		else:
			var gone: int = (trees[0] as Assemblies).ungroup(str(copies[0][0]))
			(a["store"] as ModelStore).looks_follow_edit()
			_nudge(b, trees[1], str(copies[1][1]), Vector3i(6, 0, 0))
			await _settle([a, b], 30000)
			var undone: Array = [tb.undo()]
			await _settle([a, b], 30000)
			undone.append(ta.undo())
			await _settle([a, b], 30000)
			var lit: Array = [ta.model_text().count("#00ff00"), tb.model_text().count("#00ff00")]
			_check("a copy taken apart on one side (%d parts) while the other moves on the other, both "
				% gone + "undone (%s): one light, on both sides, the two files one" % [undone], trouble.is_empty()
				and gone > 0 and lit == [1, 1] and ta.model_hash() == tb.model_hash(),
				trouble if not trouble.is_empty() else "%s lights; apart at %s" % [lit,
				_apart(ta.model_text(), tb.model_text())])
			# Its lines past what a session takes: said once, a part moved with
			# them still reaches the other side.
			var big := PackedStringArray((a["world"] as BrickWorld).section_lines["Sub"])
			for n: int in 64:
				big.append("0 !BRICKWORKS VIEW " + JSON.stringify({"distance": 300, "focus": [0, 0, n],
					"name": "view %d %s" % [n, "x".repeat(3300)], "pitch": -20, "yaw": 10}))
			heard.clear()
			Assemblies.set_lines(a["builder"], {"Sub": big})
			_nudge(a, trees[0], str(_subs(trees[0])[0]), Vector3i(0, 0, 6))
			await _settle([a, b], 30000)
			var long_said: Array = heard.filter(func(words: String) -> bool:
				return words == TogetherWords.too_long("~sublines:Sub"))
			_check("Sub's lines past what a session takes: said once (%d), a move made with them still "
				% long_said.size() + "reaches the other side", long_said.size() == 1
				and _yellow_at(trees[0]) == _yellow_at(trees[1]) and not heard.any(func(words: String) -> bool:
					return words.begins_with("Could not reach")), str(heard))
		await ta.end()
		var until: int = Time.get_ticks_msec() + 30000
		while tb.live and Time.get_ticks_msec() < until:
			await process_frame
	ta.said.disconnect(hear)


## The copies of Sub in [param tree], by path.
static func _subs(tree: Assemblies) -> Array:
	var out: Array = Array(tree.paths()).filter(func(path: String) -> bool:
		return Assemblies.definition(Assemblies.leaf(path)) == "Sub")
	out.sort()
	return out


## Where each copy of Sub's yellow 3003 stands, by the copy's path.
static func _yellow_at(tree: Assemblies) -> Dictionary:
	var out: Dictionary = {}
	for path: String in _subs(tree):
		for brick: BrickWorld.Brick in tree.bricks_under(path):
			if brick.color_code == 14:
				out[path] = brick.transform.origin
	return out


## The copy at [param path] on [param side] moved by [param by], as the arrow keys move it.
static func _nudge(side: Dictionary, tree: Assemblies, path: String, by: Vector3i) -> void:
	var builder: Builder = side["builder"]
	var selection: Dictionary = {}
	for id: int in tree.ids_under(path):
		selection[id] = true
	builder.selection = selection
	builder.move_selection(by)
	(side["store"] as ModelStore).looks_follow_edit()
	builder.clear_selection()


## Where [param mine] and [param theirs] first differ: "line N: mine / theirs",
## or "none".
static func _apart(mine: String, theirs: String) -> String:
	var a: PackedStringArray = mine.split("\n")
	var b: PackedStringArray = theirs.split("\n")
	for n: int in maxi(a.size(), b.size()):
		if n >= a.size() or n >= b.size() or a[n] != b[n]:
			return "line %d: %s / %s" % [n, a[n] if n < a.size() else "-", b[n] if n < b.size() else "-"]
	return "none"


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
	# Ended by the owner, not refused: refused, it still had its edits made
	# and passed, and only the flow's checks after said the desktop was gone.
	_check("made %d edits of its own, and was told the owner ended the session" % made, made == edits
		and not together.live and together.ended_words.begins_with("The owner ended the session"), together.ended_words)
