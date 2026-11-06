## A build party: one shared model, several phones (docs/APP_UX5.md, unit 5
## buildparty).
##
##   godot --path . --resolution 390x844 --script src/dev/buildparty_probe.gd
##   PROBE_SIZE=1024x768 tools/probe.sh buildparty_probe     a tablet
##   PROBE_SIZE=1280x720 tools/probe.sh buildparty_probe     a desktop window
##
## LEGO Builder's Build Together has several people, each on their own phone,
## join one model by a code, split its building and finish it together;
## Brickworks' Build it played one device's steps. Here the car (models/
## car.ldr, 61 parts, its 15 steps worked out) is opened as a shared link
## (api/share.js played by a stand-in, as partbypart_probe's), and the relay
## (api/together.js's build party block) by a stand-in kept in this probe that
## answers as it does. This window is phone A, driven as a finger drives it;
## phone B is a second BuildParty of the same stand-in, which says what a
## phone says (tools/web/buildparty_flow.mjs has two real phones):
##
##   1. A: Build together, Start a build: a code, in 2 taps.
##   2. B joins by the code: A's card names both within 2 s.
##   3. A: Start building: A's Build it opens on its own share at once. The car
##      dealt in two: each phone's pages hold only its own parts (every part
##      on a page's baseplate, and every part to pick up, its own), and all
##      61 once between the two.
##   4. A part done on B shows on A within 2 s ("Leo 1 of 30"), and one done
##      on A reaches B within 2 s.
##   5. A leaves mid-build (Close, Leave the build) and joins again with the
##      code kept (Join): its seat, its share and its page and part back.
##   6. A builds the rest of its share: it waits on its last page, saying
##      for whom, Next held; B finishes; A is shown the joining step within
##      2 s: every part on show, B's outlined, nothing to pick up.
##   7. Every target in the card a fingertip (44 points) on a phone.
##
## Pictures in shots/buildparty/, named by the window's size.
extends SceneTree

const CAR := "res://models/car.ldr"
const SHOTS := "res://shots/buildparty/"
const PARTS := 61
const TARGET := 44.0
const CROSS_MS := 2000.0

var _failures: int = 0
var _size: String = ""


class FakeShared extends SharedModels:
	var answer: Dictionary = {}

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func built(_id: String, _device: String, _version: int = 1) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "open": true, "you": {"signed_in": false}}}


## The relay's build party, as api/together.js answers it: parties by
## link and code, each a numbered log of what its phones said.
class Relay extends RefCounted:
	var parties: Dictionary = {}
	var asked: Array = []

	static func who(code: String, phone: String) -> String:
		return ("%s:%s" % [code, phone]).sha256_text().left(8)

	static func seats_of(ops: Array) -> Array:
		var seats: Array = []
		for op: Dictionary in ops:
			if (op["said"] as Dictionary).has("join") and not seats.has(op["phone"]):
				seats.append(op["phone"])
		return seats

	func out(code: String, ops: Array) -> Array:
		return ops.map(func(op: Dictionary) -> Dictionary:
			return {"seq": op["seq"], "who": who(code, op["phone"]), "said": op["said"]})

	func append(party: Dictionary, phone: String, said: Dictionary) -> void:
		var ops: Array = party["ops"]
		ops.append({"seq": ops.size() + 1, "phone": phone, "said": said})

	func joined(code: String, phone: String) -> Array:
		var party: Dictionary = parties[code]
		var ops: Array = party["ops"]
		return [200, {"code": code, "link": party["link"], "me": who(code, phone),
			"seat": seats_of(ops).find(phone) + 1, "ops": out(code, ops), "seq": ops.size()}]

	func answer(op: String, body: Dictionary) -> Array:
		asked.append(op)
		await (Engine.get_main_loop() as SceneTree).process_frame
		var code: String = BuildParty.clean_code(str(body.get("code", "")))
		var phone: String = str(body.get("phone", ""))
		if op == "party_start":
			code = "K7Q%d" % (parties.size() + 2)
			parties[code] = {"link": body["link"], "ops": []}
			append(parties[code], phone, {"join": {"name": body.get("name", "")}})
			return joined(code, phone)
		if not parties.has(code) or parties[code]["link"] != body.get("link"):
			return [404, {"error": "There is no build with that code on this model"}]
		var party: Dictionary = parties[code]
		var ops: Array = party["ops"]
		var seats: Array = seats_of(ops)
		var dealt: bool = ops.any(func(one: Dictionary) -> bool: return (one["said"] as Dictionary).has("deal"))
		if op == "party_join":
			if not seats.has(phone) and (dealt or seats.size() >= 4):
				return [409, {"error": "That build has started"}]
			append(party, phone, {"join": {"name": body.get("name", "")}})
			return joined(code, phone)
		if op == "party_send":
			if not seats.has(phone):
				return [403, {"error": "Join the build by its code first"}]
			var said: Dictionary = body["said"]
			if said.has("deal") and (seats[0] != phone or dealt):
				return [409, {"error": "That build is dealt already"}]
			append(party, phone, said)
			return [200, {"seq": ops.size()}]
		if op == "party_poll":
			var after: int = int(body.get("after", 0))
			var until: int = Time.get_ticks_msec() + 3000
			while ops.size() <= after and Time.get_ticks_msec() < until:
				await (Engine.get_main_loop() as SceneTree).process_frame
			return [200, {"ops": out(code, ops.slice(after)), "seq": maxi(ops.size(), after)}]
		return [400, {"error": "which op?"}]


## A phone's party, talking to the stand-in rather than the server.
class FakeParty extends "res://src/net/build_party.gd":
	var relay: Relay
	## Phone B is another device: it keeps nothing in this one's place.
	var keeps: bool = true

	func _ask(op: String, body: Dictionary, _timeout: float = 20.0) -> Array:
		return await relay.answer(op, body)

	func _keep() -> void:
		if keeps:
			super()


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	var size: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [size.x, size.y]
	var text: String = FileAccess.get_file_as_string(CAR)
	if text.is_empty():
		print("buildparty_probe: SKIPPED, no %s" % CAR)
		quit(3)
		return
	print("buildparty_probe: a %s window" % _size)
	BuildSteps._kept.clear()
	var relay := Relay.new()
	var mine := FakeParty.new()
	mine.relay = relay
	var main: Node = await _open("P4rtyC4r01", text, mine)
	var view: ShareView = main.get("_share_view")

	print("\n1. Build together, on phone A")
	var named: Dictionary = view.controls_by_name()
	_ok(named.has("view_together") and (named["view_together"] as Control).is_visible_in_tree(),
		"Build together is offered with Build it (%s)" % ("the pill over the big Build it"
			if bool(view.page_state()["party"].get("pill", false)) else "on the bar"))
	# Nothing it covers, nor anything over it: the big Build it, the
	# comments' count, the bar's buttons.
	var crossed := PackedStringArray()
	if named.has("view_together"):
		var own: Rect2 = (named["view_together"] as Control).get_global_rect()
		for other_name: String in named:
			var other_control: Control = named[other_name]
			if other_name != "view_together" and other_control.is_visible_in_tree() \
					and own.intersects(other_control.get_global_rect()):
				crossed.append(other_name)
	_ok(crossed.is_empty(), "Build together overlaps none of the viewer's %d other controls%s" % [named.size() - 1,
		"" if crossed.is_empty() else ": " + ", ".join(crossed)])
	if not named.has("view_together"):
		await _close(main)
		_finish()
		return
	var taps: int = 0
	await _tap(named["view_together"])
	taps += 1
	named = view.controls_by_name()
	_ok(named.has("party_start") and named.has("party_code") and named.has("party_join"),
		"the card: Start a build, or a code and Join (%s)" % view.page_state()["party"].get("title", ""))
	await _shot("1_card")
	await _tap(named["party_start"])
	taps += 1
	await _until(func() -> bool: return mine.live, 3000)
	var code: String = mine.code
	_ok(mine.live and code.length() == 4 and mine.seat() == 1 and taps == 2,
		"in a build in %d taps, seat %d, its code %s, said big: \"%s\"" % [taps, mine.seat(), code,
			view.page_state()["party"].get("title", "")])

	print("\n2. phone B joins by the code")
	var other := FakeParty.new()
	other.relay = relay
	other.keeps = false
	root.add_child(other)
	other.setup("P4rtyC4r01")
	other.phone = "phonebbbbbb2"
	var joined: String = await other.join(code.to_lower(), "Leo")
	var span := ProbeTime.Span.new()
	await _until(func() -> bool:
		return mine.seats.size() == 2 and str(view.page_state()["party"].get("seats", [])).contains("Leo"), 5000)
	span.end()
	var seats: Array = view.page_state()["party"].get("seats", [])
	_ok(joined.is_empty() and other.seat() == 2 and seats.size() == 2 and span.own < CROSS_MS * span.slack(),
		"B joined (seat %d, typed in lower case); A's card names both in %s: %s" % [other.seat(), span.said(), seats])
	await _shot("2_both_in")

	print("\n3. A deals it out")
	named = view.controls_by_name()
	_ok(named.has("party_deal") and not (named["party_deal"] as Button).disabled
			and (named["party_deal"] as Button).text.contains("2 phones"),
		"Start building, for 2 phones (\"%s\")" % ((named["party_deal"] as Button).text if named.has("party_deal") else "none"))
	if named.has("party_deal"):
		await _tap(named["party_deal"])
	var mode: BuildMode = main.get("_build_mode")
	await _until(func() -> bool: return mode.is_open() and bool(main.get("_party_pages")), 30000)
	await _settle()
	_ok(mode.is_open() and bool(main.get("_party_pages")) and other.dealt == 2,
		"A's Build it opens on its own share at once; B hears the deal (dealt for %d)" % other.dealt)
	var steps: Array[Instructions.Step] = (main.get("_steps") as StepsBar).steps()
	var ground: Dictionary = (main.get("_store") as ModelStore).scenery
	var shares: Array[Dictionary] = BuildParty.shares_of(steps, 2, ground)
	var all: Dictionary = {}
	var twice: int = 0
	for share: Dictionary in shares:
		for brick_id: Variant in share:
			if all.has(brick_id):
				twice += 1
			all[brick_id] = true
	_ok(shares.size() == 2 and all.size() == PARTS and twice == 0,
		"the car dealt in two: %s parts, %d between them, %d twice" % [
			" and ".join(shares.map(func(one: Dictionary) -> String: return str(one.size()))), all.size(), twice])
	var pages: BuildSteps = main.get("_build_pages")
	var world: BrickWorld = main.get("_world")
	var own: Dictionary = shares[0]
	_ok(_pages_hold_only(pages, own, ground, world),
		"every one of A's %d pages holds only A's own parts: on the baseplate, outlined and to pick up" % (pages.last() - 1))
	var theirs: BuildSteps = BuildSteps.of(world, main.get("_library"),
		BuildParty.steps_for(steps, shares[1], ground), ground)
	_ok(_pages_hold_only(theirs, shares[1], ground, null),
		"and B's %d pages only B's" % (theirs.last() - 1))
	var said: Dictionary = main.call("build_state")
	_ok(bool(mode.by_part) and (said["party"].get("chips", []) as Array).has("Leo"),
		"a part at a time, everyone along the top: %s" % [said["party"].get("chips", [])])
	await _shot("3_dealt")

	print("\n4. a part done crosses in 2 s")
	await _tap(mode.controls_by_name()["build_next"])
	await _frames(30)
	span = ProbeTime.Span.new()
	await _tap_quick(mode.controls_by_name()["build_next"])
	said = main.call("build_state")
	await _until(func() -> bool:
		return int((other.seats[0]["at"] as Dictionary).get("done", -1)) == int(main.call("build_state")["shown"]), 5000)
	span.end()
	said = main.call("build_state")
	_ok(int(said["shown"]) >= 1 and int((other.seats[0]["at"] as Dictionary).get("done", -1)) == int(said["shown"])
			and span.own < CROSS_MS * span.slack(),
		"A's Next: %d of its parts down, on B in %s (page %d part %d)" % [int(said["shown"]), span.said(),
			int(main.get("_build_page")), int(main.get("_build_part"))])
	var b_share: int = shares[1].size()
	span = ProbeTime.Span.new()
	other.tell(1, b_share, 1, 1, false)
	await _until(func() -> bool:
		return str(main.call("build_state")["party"].get("chips", [])).contains("Leo 1 of %d" % b_share), 5000)
	span.end()
	_ok(str(main.call("build_state")["party"].get("chips", [])).contains("Leo 1 of %d" % b_share)
			and span.own < CROSS_MS * span.slack(),
		"B's part done shows on A in %s: %s" % [span.said(), main.call("build_state")["party"].get("chips", [])])
	await _shot("4_progress")

	print("\n5. A leaves mid-build and joins again")
	var place: Array = [int(main.get("_build_page")), int(main.get("_build_part"))]
	await _tap(mode.controls_by_name()["build_close"])
	named = view.controls_by_name()
	_ok(not mode.is_open() and named.has("party_back") and named.has("party_leave"),
		"Close: the card, with Back to building and Leave the build")
	await _tap(named["party_leave"])
	await _until(func() -> bool: return not mine.live, 3000)
	await _until(func() -> bool: return bool(other.seats[0]["left"]), 5000)
	named = view.controls_by_name()
	_ok(not mine.live and bool(other.seats[0]["left"]) and named.has("party_join")
			and str(view.page_state()["party"].get("code_typed", "")) == code,
		"left: B is told, and A's card keeps the code (%s)" % view.page_state()["party"].get("code_typed", ""))
	await _shot("5_left")
	if named.has("party_join"):
		await _tap(named["party_join"])
	await _until(func() -> bool: return mode.is_open() and bool(main.get("_party_pages")), 30000)
	await _settle()
	var back: Array = [int(main.get("_build_page")), int(main.get("_build_part"))]
	_ok(mine.live and mine.seat() == 1 and back == place and not bool(other.seats[0]["left"]),
		"Join again: seat %d, Build it back on page %d part %d (it was on %d, %d)" % [mine.seat(), back[0],
			back[1], place[0], place[1]])

	print("\n6. A finishes, waits, and is shown the joining step")
	var last: int = (main.get("_build_pages") as BuildSteps).last()
	for _n: int in 400:
		if bool(main.get("_party_waiting")):
			break
		await _tap_quick(mode.controls_by_name()["build_next"])
	await _settle()
	said = main.call("build_state")
	_ok(bool(main.get("_party_waiting")) and str(said["caption"]) == "Your part is built"
			and str(said["note"]).begins_with("Waiting for Leo") and bool(said["party"]["next_held"]),
		"its last page built, waiting: \"%s\", \"%s\", Next held" % [said["caption"], said["note"]])
	await _until(func() -> bool: return bool((other.seats[0]["at"] as Dictionary).get("finished", false)), 5000)
	_ok(bool((other.seats[0]["at"] as Dictionary).get("finished", false)), "...and B hears A is done")
	await _shot("6_waiting")
	span = ProbeTime.Span.new()
	other.tell(b_share, b_share, theirs.last(), 0, true)
	await _until(func() -> bool: return bool(mode.party_joining), 5000)
	span.end()
	await _settle()
	said = main.call("build_state")
	var hidden: int = world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return brick.hidden and not ground.has(brick.id)).size()
	var outlined: Dictionary = (main.get("_build_pages") as BuildSteps).fresh(last)
	_ok(mode.party_joining and span.own < CROSS_MS * span.slack() and str(said["caption"]) == "Put it together"
			and hidden == 0 and int(said["lots"]) == 0 and outlined.keys().all(func(id: Variant) -> bool:
				return shares[1].has(id)) and outlined.size() == shares[1].size(),
		"the joining step in %s: \"%s\", every part on show (%d hidden), B's %d outlined, nothing to pick up" % [
			span.said(), said["caption"], hidden, outlined.size()])
	_ok(other.all_finished(), "B has everyone done too")
	await _shot("7_joining")

	print("\n7. every target a fingertip")
	await _tap(mode.controls_by_name()["build_close"])
	var targets: Dictionary = view.page_state()["party"].get("targets", {})
	var small := PackedStringArray()
	for name: String in targets:
		if float(targets[name][0]) < TARGET or float(targets[name][1]) < TARGET:
			small.append("%s %s" % [name, targets[name]])
	if bool(view.get("_narrow")):
		_ok(small.is_empty() and targets.size() >= 3,
			"%d targets in the card and the pill, each %d points or more: %s%s" % [targets.size(), int(TARGET),
				targets, "" if small.is_empty() else "; under: " + ", ".join(small)])
	else:
		print("  --    a wide window: the card's targets are the bar's size (%s)" % [targets])
	await _shot("8_card_after")
	other.queue_free()
	await _close(main)
	_finish()


## Every page but the last (the joining step) of [param pages] holds only
## [param share]'s parts: the parts it outlines and lists to pick up, and,
## with [param world], what is on its baseplate.
func _pages_hold_only(pages: BuildSteps, share: Dictionary, ground: Dictionary, world: BrickWorld) -> bool:
	var ok: bool = pages != null and pages.last() >= 2
	for page: int in range(1, pages.last() if pages != null else 0):
		for brick_id: Variant in pages.fresh(page):
			if not share.has(brick_id):
				print("  page %d outlines a part not its own: %s" % [page, brick_id])
				ok = false
		for brick_id: Variant in pages.shown(page):
			if not share.has(brick_id) and not ground.has(brick_id):
				print("  page %d has a part not its own on its baseplate: %s" % [page, brick_id])
				ok = false
	if world != null:
		for page: int in range(1, pages.last()):
			var wanted: int = 0
			for brick_id: Variant in pages.fresh(page):
				wanted += 1
			var listed: int = 0
			for lot: Dictionary in pages.lots(page):
				listed += int(lot["count"])
			if listed != wanted and pages.step_of(page) != null and not pages.step_of(page).attaches():
				print("  page %d lists %d to pick up for %d new" % [page, listed, wanted])
				ok = false
	return ok


func _open(id: String, text: String, party: Node) -> Node:
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": id, "name": "Probe Car", "author": "Probe Builder",
		"parts": PARTS, "url": "https://brickworks.diy/m/" + id, "model": text}}
	var main: Node = load("res://src/main.tscn").instantiate()
	main.set("_viewing", id)
	main.set("_shared", fake)
	main.set("_party", party)
	root.add_child(main)
	var view: ShareView = null
	for _n: int in 1200:
		await process_frame
		view = main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	_ok(view != null and view.state == "ready", "the car opened as a shared link (%s)" % (
		view.state if view != null else "no viewer"))
	var steps: StepsBar = main.get("_steps")
	var since: int = Time.get_ticks_msec()
	while steps != null and steps.is_starting() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	await _frames(20)
	return main


func _close(main: Node) -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _finish() -> void:
	print("\nbuildparty_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


## Frames until [param test] holds or [param ms] pass.
func _until(test: Callable, ms: int) -> void:
	var since: int = Time.get_ticks_msec()
	while not bool(test.call()) and Time.get_ticks_msec() - since < ms:
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _settle() -> void:
	await _frames(12)
	await RenderingServer.frame_post_draw


## A finger's tap on [param control]: down and up where it is, as a phone
## sends it (the click is emulated from it, project.godot).
func _tap(control: Control) -> void:
	await _tap_quick(control)
	await _settle()


func _tap_quick(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = _as_event(at)
		Input.parse_input_event(touch)
		await process_frame
	await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	root.get_texture().get_image().save_png("%s%s_%s.png" % [SHOTS, _size, name])


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
