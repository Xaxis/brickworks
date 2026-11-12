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
## Then a model that drives (drvcheck3 T): the racer, its drive kept,
## undone and redone on each side, with its rims still on their way to the
## one that joined (its own parts fetched from a host here, the rims held
## back past the 90 s a join waits): every rim lands once, in its tyre, on
## both, its wheel joints found, and the same file on both. --only=drive runs
## that alone.
##
## Not in the suite: it needs the relay with .env's keys (tools/suite/out.txt).
extends SceneTree

const RACER := "res://vendor/omr/files/8808-1.mpd"
const RIM := "3482"
const HOST_PORT := 9862

var _failures: int = 0
var _library: PartLibrary
var _api: String = ""
var _rng := RandomNumberGenerator.new()
var _host := TCPServer.new()
var _host_port: int = 0
var _host_peers: Array[Dictionary] = []
var _held_back: Dictionary = {}
var _held_peers: Array = []


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
	elif _arg("--only") == "drive":
		await _drive_together()
		var gone: int = await SignInHelper.delete_accounts("delivered+bwtogether", root)
		print("  (%d throwaway accounts deleted)" % gone)
	else:
		await _pair()
	print("")
	print("together probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)


## One copy of the app, headless: its world, builder, store, view and
## Together; [param signed] an account already signed in, else one made.
func _side(email: String, signed: Account = null, library: PartLibrary = null) -> Dictionary:
	if library == null:
		library = _library
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = library
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
	await _drive_together()
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


# -- a model that drives, its rims on their way to one side (drvcheck3 T) ------


## What plays [param side]'s motions, as Main makes it (_make_motions).
func _player(side: Dictionary) -> MotionPlayer:
	var world: BrickWorld = side["world"]
	var store: ModelStore = side["store"]
	var drag := GrabDrag.new()
	drag.world = world
	drag.builder = side["builder"]
	drag.library = world.library
	drag.camera = side["camera"]
	drag.scenery = store.scenery
	var assemblies := Assemblies.new()
	assemblies.world = world
	drag.assemblies = assemblies
	root.add_child(drag)
	var player := MotionPlayer.new()
	player.world = world
	player.builder = side["builder"]
	player.library = world.library
	player.store = store
	player.grabbing = drag
	store.motion_rebase = func(joint: Motions.Joint) -> void: player.rebase(joint)
	return player


## Each rim of [param side]'s model, how far it stands from the nearest part
## that is no rim (its tyre), sorted.
static func _rims_in_tyres(side: Dictionary) -> Array:
	var world: BrickWorld = side["world"]
	var scenery: Dictionary = (side["store"] as ModelStore).scenery
	var out: Array = []
	for rim: BrickWorld.Brick in world.bricks():
		if rim.part_id != RIM:
			continue
		var nearest: float = INF
		for other: BrickWorld.Brick in world.bricks():
			if other.part_id != RIM and not scenery.has(other.id):
				nearest = minf(nearest, other.transform.origin.distance_to(rim.transform.origin))
		out.append(snappedf(nearest, 0.01))
	out.sort()
	return out


static func _same_list(one: Array, other: Array) -> bool:
	if one.size() != other.size() or one.is_empty():
		return false
	for n: int in one.size():
		if absf(float(one[n]) - float(other[n])) > 0.05:
			return false
	return true


## The drive's joints [param player] finds parts for, of how many.
static func _joints_found(player: MotionPlayer) -> Array:
	var motion: Motions.Motion = player.motions().named(MotionPlayer.DRIVE_NAME)
	if motion == null:
		return [0, 0]
	var joints: Array = motion.joints()
	return [joints.filter(func(one: Motions.Joint) -> bool: return not player.parts_of(one).is_empty()).size(),
		joints.size()]


## Where the drive's parts stand on [param side]: every part, every rim, how
## far each rim is from its tyre, the drive's joints found.
func _standing(name: String, side: Dictionary, player: MotionPlayer) -> String:
	var world: BrickWorld = side["world"]
	var rims: int = world.bricks().filter(func(one: BrickWorld.Brick) -> bool: return one.part_id == RIM).size()
	var found: Array = _joints_found(player)
	return "%s: %d parts, %d rims (%d on their way), rims from their tyres %s, joints %d of %d" % [name,
		world.brick_count(), rims, (side["together"] as Together).get("_awaiting").size(),
		", ".join(_rims_in_tyres(side).map(func(n: float) -> String: return "%.2f" % n)), found[0], found[1]]


func _host_up() -> bool:
	_host_port = HOST_PORT
	while _host.listen(_host_port, "127.0.0.1") != OK:
		_host_port += 1
		if _host_port > 9869:
			return false
	process_frame.connect(_host_tick)
	return true


func _host_tick() -> void:
	while _host.is_connection_available():
		_host_peers.append({"peer": _host.take_connection(), "got": PackedByteArray()})
	for client: Dictionary in _host_peers.duplicate():
		var peer: StreamPeerTCP = client["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_host_peers.erase(client)
			continue
		var available: int = peer.get_available_bytes()
		if available > 0:
			client["got"] = (client["got"] as PackedByteArray) + (peer.get_data(available)[1] as PackedByteArray)
		var text: String = (client["got"] as PackedByteArray).get_string_from_ascii()
		if not text.contains("\r\n\r\n"):
			continue
		_host_peers.erase(client)
		var file: String = text.get_slice(" ", 1).get_file()
		if _held_back.has(file):
			_held_peers.append([peer, file])
		else:
			_host_answer(peer, file)


func _host_answer(peer: StreamPeerTCP, file: String) -> void:
	var folder: String = "parts/" if file.ends_with(".lbm") else "exact/"
	var body: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/generated/" + folder + file)
	var how: int = 200 if not body.is_empty() else 404
	peer.put_data(("HTTP/1.1 %d %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [how,
		"OK" if how == 200 else "Not Found", body.size()]).to_ascii_buffer())
	if not body.is_empty():
		peer.put_data(body)
	peer.disconnect_from_host()


## How many of [param a]'s parts [param b] has elsewhere, or not at all: a
## part on its way to [param b] where its session state has it.
static func _apart(a: Dictionary, b: Dictionary) -> int:
	var ta: Together = a["together"]
	var tb: Together = b["together"]
	var waiting: Dictionary = tb.get("_awaiting")
	var count: int = 0
	for brick: BrickWorld.Brick in (a["world"] as BrickWorld).bricks():
		var uid: String = ta.uid_of(brick.id)
		var there: BrickWorld.Brick = (b["world"] as BrickWorld).get_brick(tb.brick_of(uid))
		var at: Variant = there.transform if there != null \
			else (Together.transform_of((waiting[uid] as Array)[2]) if waiting.has(uid) else null)
		if at == null or not (at as Transform3D).is_equal_approx(brick.transform):
			count += 1
	return count


## Where one part (the owner's first) and the whole move stand on each side.
static func _where_both(a: Dictionary, b: Dictionary) -> String:
	var ta: Together = a["together"]
	var tb: Together = b["together"]
	var uid: String = ta.uid_of((a["world"] as BrickWorld).bricks()[0].id)
	var out := PackedStringArray()
	for side: Dictionary in [a, b]:
		var together: Together = side["together"]
		var world: BrickWorld = side["world"]
		var brick: BrickWorld.Brick = world.get_brick(together.brick_of(uid))
		var moved: Transform3D = world.motions.moved if world.motions != null else Transform3D.IDENTITY
		out.append("%s at %s, moved %s %s, base %s" % [uid, brick.transform.origin if brick != null else "nowhere",
			moved.basis.x, moved.origin, (together.get("_moved_base") as Transform3D).origin])
	return " | ".join(out)


## The parts [param together]'s next redo would leave: as it has each, and as
## the redo wants it.
static func _print_left(together: Together) -> void:
	var steps: Array = together.get("_redo")
	if steps.is_empty():
		print("    (no redo step)")
		return
	var step: Dictionary = steps.back()
	var shown: Dictionary = together.get("_shown")
	var left := PackedStringArray()
	for uid: String in step["back"]:
		if shown.get(uid) != (step["forward"] as Dictionary)[uid]:
			left.append("%s: %s | %s" % [uid, str(shown.get(uid)).left(160), str((step["forward"] as Dictionary)[uid]).left(160)])
	print("    the redo would leave %d of %d: %s" % [left.size(), (step["back"] as Dictionary).size(), "; ".join(left)])


## The first lines [param a] and [param b] differ in, said.
static func _differ(a: String, b: String) -> String:
	var one: PackedStringArray = a.split("\n")
	var other: PackedStringArray = b.split("\n")
	var said := PackedStringArray()
	for n: int in maxi(one.size(), other.size()):
		var x: String = one[n] if n < one.size() else "(none)"
		var y: String = other[n] if n < other.size() else "(none)"
		if x != y:
			said.append("line %d: %s | %s" % [n + 1, x, y])
			if said.size() >= 6:
				break
	return "; ".join(said)


## The racer with its drive opened by one side and started; the other, its
## own parts fetched from a host here, joining with the rims held back past
## the wait of a join, so they are on their way to it all through: the drive
## kept, undone and redone by the one they are on their way to, then by the
## owner; then the rims let go. Building together's undo put the motions
## back without the drive's whole move, so after a redo the rims landed where
## the model had stood (drvcheck3 T); and each rim was put down twice where it
## came late, once by the model's own file and once by the session.
func _drive_together() -> void:
	print("7. a drive kept, undone and redone together, its rims on their way to the one who joined")
	var stamp: int = int(Time.get_unix_time_from_system())
	var theirs := PartLibrary.new()
	if not theirs.load_catalogue() or not _host_up():
		_check("a library of its own and a parts host for the one who joins", false)
		return
	theirs._root = "user://no_parts/"
	theirs.set_fetch_host(root)
	theirs.remote_parts = "http://127.0.0.1:%d/" % _host_port
	_held_back[(theirs.parts[RIM] as PartLibrary.PartInfo).mesh_hash + ".lbm"] = true
	var a: Dictionary = await _side("delivered+bwtogetherc%d@resend.dev" % stamp)
	var b: Dictionary = await _side("delivered+bwtogetherd%d@resend.dev" % stamp, null, theirs)
	var sb: ModelStore = b["store"]
	theirs.fetched.connect(func(part_id: String) -> void: sb.place_awaited(part_id))
	var ta: Together = a["together"]
	var tb: Together = b["together"]
	var pa: MotionPlayer = _player(a)
	var pb: MotionPlayer = _player(b)
	var sa: ModelStore = a["store"]
	var opened: Dictionary = sa.open_text(FileAccess.get_file_as_string(RACER), "Racer")
	sa.title = "Racer"
	while sa.laying:
		await process_frame
	var drive: Motions.Motion = null
	for one: Motions.Motion in pa.suggest():
		if one.name == MotionPlayer.DRIVE_NAME:
			drive = one
	if drive == null:
		_check("the racer opens and is offered its drive", false, str(opened.get("placed", 0)))
		return
	pa.motions().put(drive)
	var whole: int = (a["world"] as BrickWorld).brick_count()
	var in_tyres: Array = _rims_in_tyres(a)
	print("    the owner's racer: %d parts, rims from their tyres %s" % [whole,
		", ".join(in_tyres.map(func(n: float) -> String: return "%.2f" % n))])
	var trouble: String = await ta.start()
	_check("the owner starts a session on the racer and its drive", trouble.is_empty() and ta.live, trouble)
	var began: int = Time.get_ticks_msec()
	trouble = await tb.join(ta.link)
	await _settle([a, b])
	var waiting: int = (b["world"] as BrickWorld).bricks().filter(func(one: BrickWorld.Brick) -> bool:
		return one.part_id == RIM).size()
	_check("the other joins in %d s with its %d rims still on their way (%d of %d parts down)" % [
		(Time.get_ticks_msec() - began) / 1000, in_tyres.size(), (b["world"] as BrickWorld).brick_count(), whole],
		trouble.is_empty() and tb.live and waiting == 0
		and (b["world"] as BrickWorld).brick_count() == whole - in_tyres.size(), trouble)
	var start: Transform3D = Transform3D.IDENTITY
	for keeper: Array in [["the one who joined", b, pb, tb], ["the owner", a, pa, ta]]:
		var player: MotionPlayer = keeper[2]
		var together: Together = keeper[3]
		player.play(player.motions().named(MotionPlayer.DRIVE_NAME), false, MotionPlayer.PLAY_FPS, true)
		await _settle([a, b])
		print("    kept by %s: %s; %s" % [keeper[0], _standing("the owner", a, pa), _standing("the other", b, pb)])
		print("    %s" % _where_both(a, b))
		var went: Transform3D = (a["world"] as BrickWorld).motions.moved
		var apart: int = _apart(a, b)
		_check("T: kept by %s, the owner's rims are in their tyres, the model where it went on both (%d apart)"
			% [keeper[0], apart], _same_list(_rims_in_tyres(a), in_tyres) and apart == 0
			and not went.is_equal_approx(start))
		start = went
		var undone: Dictionary = await together.check_edit({"op": "undo"})
		await _settle([a, b])
		print("    undone (%s): %s; %s" % [undone.get("words", ""), _standing("the owner", a, pa),
			_standing("the other", b, pb)])
		print("    %s" % _where_both(a, b))
		_print_left(together)
		var redone: Dictionary = await together.check_edit({"op": "redo"})
		await _settle([a, b])
		print("    %s" % _where_both(a, b))
		print("    redone (%s): %s; %s" % [redone.get("words", ""), _standing("the owner", a, pa),
			_standing("the other", b, pb)])
		apart = _apart(a, b)
		_check("T: undone and redone by %s (%s), the owner's rims in their tyres, the model where it went on both (%d apart)"
			% [keeper[0], redone.get("words", ""), apart], bool(undone.get("ok", false))
			and bool(redone.get("ok", false)) and not str(redone.get("words", "")).contains("left")
			and _same_list(_rims_in_tyres(a), in_tyres) and apart == 0
			and (a["world"] as BrickWorld).motions.moved.is_equal_approx(went))
		# Past Together.OVERTAKEN_MS before the other's turn.
		var calm: int = Time.get_ticks_msec() + Together.OVERTAKEN_MS + 500
		while Time.get_ticks_msec() < calm:
			await process_frame
	# The rims let go: each lands once, in its tyre, on the side it was
	# on its way to, and the owner has no more than it had.
	_held_back.clear()
	for held: Array in _held_peers:
		_host_answer(held[0], str(held[1]))
	_held_peers.clear()
	var until: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < until and (not tb.get("_awaiting").is_empty() or not sb.awaited.is_empty()):
		await process_frame
	await _settle([a, b])
	for side: Array in [["the owner", a, pa], ["the one who joined", b, pb]]:
		var found: Array = _joints_found(side[2])
		var world: BrickWorld = (side[1] as Dictionary)["world"]
		print("    the rims landed: %s" % _standing(side[0], side[1], side[2]))
		_check("T: %s has the racer's %d parts, each rim once and in its tyre, and the drive's %d joints"
			% [side[0], whole, found[1]], world.brick_count() == whole
			and _same_list(_rims_in_tyres(side[1]), in_tyres) and found[0] == found[1] and found[1] > 0,
			"%d parts, joints %d of %d" % [world.brick_count(), found[0], found[1]])
	var text_a: String = ta.model_text()
	var text_b: String = tb.model_text()
	_check("T: the same file on both", text_a == text_b, _differ(text_a, text_b))
	if text_a != text_b:
		var apart := PackedStringArray()
		for brick: BrickWorld.Brick in (a["world"] as BrickWorld).bricks():
			var uid: String = ta.uid_of(brick.id)
			var there: BrickWorld.Brick = (b["world"] as BrickWorld).get_brick(tb.brick_of(uid))
			if there == null or not there.transform.is_equal_approx(brick.transform):
				apart.append("%s %s %s | %s" % [uid, brick.part_id, brick.transform.origin,
					there.transform.origin if there != null else "none"])
		print("    parts not alike on both: %d: %s" % [apart.size(), "; ".join(apart.slice(0, 6))])
		# Where each stands: one part by its uid, and the whole move, on each.
		for side: Array in [["the owner", a], ["the one who joined", b]]:
			var together: Together = (side[1] as Dictionary)["together"]
			var world: BrickWorld = (side[1] as Dictionary)["world"]
			var uid: String = ta.uid_of((a["world"] as BrickWorld).bricks()[0].id)
			var brick: BrickWorld.Brick = world.get_brick(together.brick_of(uid))
			print("    %s: %s at %s, Motions.moved %s, lift %s" % [side[0], uid,
				brick.transform.origin if brick != null else "nowhere",
				world.motions.moved if world.motions != null else "none", ((side[1] as Dictionary)["store"] as ModelStore).lift()])
	await ta.end()
	process_frame.disconnect(_host_tick)
	_host.stop()
