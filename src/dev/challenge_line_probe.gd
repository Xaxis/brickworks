## The month's challenge in the studio (challengestudio, 2026-11-23): one
## small line with the model's other notices naming it and its days left;
## pressed, its rules ticked live on the model; Hide for this challenge in
## one press; and Share's Enter, which publishes and enters in one press.
##
##   ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 390x844 \
##     --script src/dev/challenge_line_probe.gd
##   PROBE_SIZE=1280x800 tools/probe.sh challenge_line_probe    (and 430x932, 768x1024, 1920x1080)
##
## No network: api/people.js ?op=challenge_rules, ?op=enter and
## ?op=challenge_entry and api/share.js's publish are played by FakeShared,
## each answered as its endpoint answers, as text off the wire, so the app's
## own reading (ChallengeRules.rules_in) is what is tested. Nothing is given
## on the command line: main.gd reads its own arguments. At 500 points
## across or fewer it is laid out as a phone's browser has the app.
##
## The model is models/house.ldr, and the rules are made from it, so each
## can be kept or broken by a part: at most one part fewer than it has, the
## parts of a set that has one of its lots one short, and Tested.
##
##   1. The line: "Microscale · 8 days left · 0 of 3 rules kept", inside the
##      window, over none of the bars, never over the model as it is drawn
##      (its rect against the model's box on screen, shut and open), and
##      named for a screen reader, its Hide too.
##   2. Pressed: each rule ticked on the model, each failed one saying what
##      to change (Take 1 part away; Swap or take away 1 more ... than the set
##      has); Tested not known, with Test it.
##   3. Share: "Enter Microscale" greyed, saying what to change; Publish one
##      press as ever, and it enters nothing.
##   4. A part taken away: the parts rule kept within two seconds, the line
##      saying 1 of 3; then the challenge's set given the lot it was short:
##      2 of 3; Tested found by a publish: 3 of 3.
##   5. Share: Enter Microscale, its way (Built by hand), one press: published
##      listed with the name, then ?op=enter with the way, and the status
##      line saying it is in and where. Share's Enter then says it is in.
##   6. Hide: gone in one press, gone again when the challenge is asked again;
##      the next challenge said.
##
## Pictures in shots/challenge_line/: line-<w>.png, rules-<w>.png, enter-<w>.png.
extends SceneTree

const SHOTS := "res://shots/challenge_line/"
const TODAY := "2026-11-23"
const PAGE := "https://brickworks.diy/challenge?id=77"

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _library: PartLibrary
var _line: Control
var _width: int = 0


## api/people.js and api/share.js as they answer, by the request's path.
class FakeShared extends SharedModels:
	## ?op=challenge_rules's challenge, null for none.
	var challenge: Variant = null
	var asked: int = 0
	var published: Array[Dictionary] = []
	var entered: Array[Dictionary] = []
	var order: Array[String] = []

	func _fetch(path: String, method: int, _token: String, body: String) -> Dictionary:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		await tree.process_frame
		if path.begins_with("/api/people?op=challenge_rules"):
			asked += 1
			return _wire(200, {"ready": true, "challenge": challenge})
		if path.begins_with("/api/people?op=challenge_entry"):
			return _wire(200, {"entry": null})
		if path.begins_with("/api/people?op=enter") and method == HTTPClient.METHOD_POST:
			var sent: Variant = JSON.parse_string(body)
			entered.append(sent if sent is Dictionary else {})
			order.append("enter")
			return _wire(201, {"entered": true, "challenge": 77, "title": "Microscale",
				"way": (sent as Dictionary).get("way", "hand") if sent is Dictionary else "hand"})
		if path == "/api/share?op=mine":
			return _wire(200, {"shared": [], "credit": {"name": "Probe Designer"}})
		if path == "/api/share" and method == HTTPClient.METHOD_POST:
			var sent: Variant = JSON.parse_string(body)
			if not sent is Dictionary:
				return _wire(400, {"error": "not JSON"})
			published.append(sent)
			order.append("publish")
			var given: String = str((sent as Dictionary).get("id", "Ch4llEnTry"))
			return _wire(200 if (sent as Dictionary).has("id") else 201, {"id": given,
				"url": "https://brickworks.diy/m/" + given, "embed": SharedModels.embed_for(given), "parts": 7,
				"updated": (sent as Dictionary).has("id"), "listed": (sent as Dictionary).get("listed") == true,
				"version": 1, "said": ""})
		return _wire(404, {"error": "not here"})

	static func _wire(code: int, body: Dictionary) -> Dictionary:
		return {"code": code, "body": JSON.parse_string(JSON.stringify(body))}


func _initialize() -> void:
	_run()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  challenge_line probe: needs a window")
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	_width = DisplayServer.window_get_size().x
	if _width <= 500:
		Phone._on = 1
		Phone._wide = false
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var fake := FakeShared.new()
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_shared", fake)
	_main.set("challenge_today_for_probe", TODAY)
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		if _main.get("_world") != null and _main.get("_shell") != null:
			break
	if _main.get("_shell") == null:
		print("  challenge_line probe: SKIPPED, the window did not come up")
		quit(3)
		return
	await _frames(60)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_store = _main.get("_store")
	_library = _main.get("_library")
	print("\n  a %d x %d window, %s" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y,
		"laid out for a phone" if _main.get("_phone") != null else "the desktop's layout"])
	var account: Account = _main.get("_account")
	await account.deployment.wait()
	account.email = "probe@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	var drawer: SideDock = _main.get("_bin_dock")
	if drawer != null and drawer.is_open():
		drawer.set_open(false)

	# The model, and rules made from it.
	_main.call("_open", "res://models/house.ldr")
	await _frames(30)
	var facts: Dictionary = ChallengeRules.facts_of(await _store.text_for_rules(), _library)
	var parts: int = int(facts.get("parts", 0))
	var needs: Dictionary = facts.get("needs", {})
	var biggest: String = ""
	for key: String in needs:
		if biggest.is_empty() or int(needs[key]) > int(needs[biggest]):
			biggest = key
	print("  house.ldr: %d parts, %d lots, the biggest %s x%d" % [parts, needs.size(), biggest, int(needs.get(biggest, 0))])
	if not _check("the house is read for its rules", parts > 2 and int(needs.get(biggest, 0)) >= 2):
		_finish()
		return
	var short_lots: Array = []
	var full_lots: Array = []
	for key: String in needs:
		var part: String = key.get_slice("/", 0)
		var colour: int = int(key.get_slice("/", 1))
		full_lots.append([part, colour, int(needs[key])])
		short_lots.append([part, colour, int(needs[key]) - (1 if key == biggest else 0)])
	fake.challenge = _challenge(77, parts - 1, short_lots, true)

	# 1. The line.
	var asked: int = fake.asked
	_line = await _until_line()
	if not _check("the line is made and shown (%d asked)" % (fake.asked - asked), _line != null and _line.visible):
		_finish()
		return
	await _until_ticked()
	var state: Dictionary = _line.call("page_state")
	var text: String = state["text"]
	_check("it names the challenge and its days left: \"%s\"" % text, text.begins_with("Microscale")
		and text.contains("8 days left") and text.contains("0 of 3 rules kept"))
	var named: Dictionary = _line.call("controls_by_name")
	var toggle: Button = named.get("challenge_line")
	var hide: Button = named.get("challenge_hide")
	_check("named for a screen reader: \"%s\"; its Hide \"%s\"" % [toggle.accessibility_name, hide.accessibility_name],
		toggle.accessibility_name.begins_with("This month's challenge, Microscale: 8 days left. Show its rules")
		and hide.accessibility_name == "Hide the line for Microscale")
	await _layout("shut")
	await _shot("line-%d.png" % _width)

	# 2. Pressed: its rules.
	await _press(toggle, "the line")
	await _frames(10)
	state = _line.call("page_state")
	var rows: Dictionary = {}
	for row: Dictionary in state["rows"]:
		rows[row["rule"]] = row
	print("  its rules: %s" % "; ".join(state["rows"].map(func(one: Dictionary) -> String:
		return "%s %s%s" % [one["state"], one["words"], (" (" + str(one["fix"]) + ")") if not str(one["fix"]).is_empty() else ""])))
	_check("shown under it", bool(state["open"]))
	_check("the parts: \"%s\", saying \"%s\"" % [rows.get("parts", {}).get("words", ""), rows.get("parts", {}).get("fix", "")],
		rows.get("parts", {}).get("state") == "no" and str(rows["parts"]["words"]) == "%d of %d parts" % [parts, parts - 1]
		and str(rows["parts"]["fix"]).begins_with("Take 1 part away"))
	_check("the set: \"%s\", saying \"%s\"" % [rows.get("set", {}).get("words", ""), rows.get("set", {}).get("fix", "")],
		rows.get("set", {}).get("state") == "no" and str(rows["set"]["words"]).begins_with("Only parts from set 6075-2")
		and str(rows["set"]["fix"]).begins_with("Swap or take away 1 more ") and str(rows["set"]["fix"]).contains("(%s)"
			% biggest.get_slice("/", 0)))
	_check("Tested not known yet, with Test it: \"%s\"" % rows.get("tested", {}).get("fix", ""),
		rows.get("tested", {}).get("state") == "unknown" and (_line.call("controls_by_name") as Dictionary).has("challenge_test"))
	var said_names := PackedStringArray()
	for found: Node in _line.find_children("rule_*", "Label", true, false):
		said_names.append((found as Label).accessibility_name)
	_check("each rule named for a screen reader with whether it is kept (%s)" % " | ".join(said_names),
		said_names.size() == 3 and said_names[0].contains("not kept"))
	await _layout("open")
	await _shot("rules-%d.png" % _width)

	# 3. Share: Enter greyed, Publish as ever.
	var share: SharePanel = await _open_share()
	if not _check("Share opens", share != null and share.visible):
		_finish()
		return
	await _frames(10)
	var shown: Dictionary = share.page_state()
	_check("Share says \"%s\", greyed: \"%s\"" % [shown["enter_text"], shown["enter_line"]], bool(shown["enter_shown"])
		and str(shown["enter_text"]) == "Enter Microscale" and bool(shown["enter_disabled"])
		and str(shown["enter_line"]).begins_with("Not yet: Take 1 part away"))
	var publish: Button = share.controls_by_name()["share_publish"]
	_check("Publish one press as ever", publish.visible and not publish.disabled)
	share.visible = false
	await _frames(5)

	# 4. Live: a part taken away, the set given its lot, Tested found.
	var world: BrickWorld = _main.get("_world")
	var one_brick: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in world.bricks():
		if not _store.scenery.has(brick.id):
			one_brick = brick
			break
	var began: int = Time.get_ticks_msec()
	world.remove_brick(one_brick.id)
	var kept_in: int = -1
	for _n: int in 400:
		await process_frame
		var now: Dictionary = _line.call("page_state")
		if int(now["checked_revision"]) == world.revision and (now["checked"] as Dictionary).get("parts", {}).get("ok") == true:
			kept_in = Time.get_ticks_msec() - began
			break
	state = _line.call("page_state")
	_check("a part taken away: the parts rule kept in %d ms, the line \"%s\"" % [kept_in, state["text"]],
		kept_in >= 0 and kept_in <= 2000 and str(state["text"]).contains("1 of 3 rules kept"))
	# The set the model now keeps (its lots less the part taken away count less).
	var now_facts: Dictionary = ChallengeRules.facts_of(await _store.text_for_rules(), _library)
	var now_lots: Array = []
	for key: String in now_facts["needs"]:
		now_lots.append([key.get_slice("/", 0), int(key.get_slice("/", 1)), int(now_facts["needs"][key])])
	fake.challenge = _challenge(77, parts - 1, now_lots, true)
	_line.call("ask")
	await _until_ticked(func(s: Dictionary) -> bool: return str(s["text"]).contains("2 of 3 rules kept"))
	state = _line.call("page_state")
	_check("the set's lot given: \"%s\"" % state["text"], str(state["text"]).contains("2 of 3 rules kept"))
	var tests: Dictionary = {}
	for test: String in ["stands", "steps", "parts", "whole"]:
		tests[test] = {"ok": true, "why": ""}
	_line.call("found_tested", tests, world.revision)
	await _frames(5)
	state = _line.call("page_state")
	_check("Tested found by a publish: \"%s\"" % state["text"], str(state["text"]).contains("3 of 3 rules kept")
		and bool(state["passes"]))

	# 5. Enter, one press.
	share = await _open_share()
	await _frames(10)
	shown = share.page_state()
	var enter: Button = share.controls_by_name().get("share_enter")
	var way: OptionButton = share.controls_by_name().get("share_way")
	_check("Share says \"%s\" with its way \"%s\": \"%s\"" % [shown["enter_text"],
		way.get_item_text(way.selected) if way != null else "", shown["enter_line"]],
		str(shown["enter_text"]) == "Enter Microscale" and not bool(shown["enter_disabled"])
		and way != null and way.get_item_text(way.selected) == "Built by hand"
		and str(shown["enter_line"]).begins_with("Enter lists it in the gallery"))
	_check("Enter named for a screen reader (%s)" % enter.tooltip_text, not enter.text.is_empty())
	await _shot("enter-%d.png" % _width)
	var presses: int = 0
	await _press(enter, "Enter")
	presses += 1
	for _n: int in 600:
		await process_frame
		if not fake.entered.is_empty() and str(share.page_state()["enter_said"]) != "":
			break
	shown = share.page_state()
	var sent: Dictionary = fake.published[-1] if not fake.published.is_empty() else {}
	_check("one press: published (%s) then entered (%s), in that order (%s)" % [JSON.stringify({"listed": sent.get("listed"),
		"author": sent.get("author")}), JSON.stringify(fake.entered), ", ".join(fake.order)],
		presses == 1 and fake.order == ["publish", "enter"] and sent.get("listed") == true
		and not str(sent.get("author", "")).is_empty() and str(fake.entered[0].get("way", "")) == "hand"
		and str(fake.entered[0].get("model", "")) == "Ch4llEnTry")
	_check("it says so: \"%s\"" % shown["status"], str(shown["status"]).contains(
		"Entered in Microscale, built by hand. It is on the challenge's page: brickworks.diy/challenge?id=77."))
	_check("Share's Enter then says it is in: \"%s\"" % shown["enter_line"], not bool(shown["enter_shown"])
		and str(shown["enter_line"]).begins_with("In Microscale, built by hand."))
	await _shot("entered-%d.png" % _width)
	share.visible = false
	await _frames(5)

	# 6. Hide.
	_line.set("where", "user://challenge_line_probe.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://challenge_line_probe.cfg"))
	named = _line.call("controls_by_name")
	await _press(named["challenge_hide"], "Hide")
	await _frames(5)
	_check("Hide: gone in one press", not _line.visible)
	_line.call("ask")
	await _frames(20)
	_check("asked again, still hidden for this challenge", not _line.visible)
	fake.challenge = _challenge(78, 0, [], false, "Castles in the air")
	_line.call("ask")
	await _frames(20)
	_check("the next challenge said: \"%s\"" % _line.call("page_state")["text"], _line.visible
		and str(_line.call("page_state")["text"]).begins_with("Castles in the air"))
	_finish()


## The challenge as ?op=challenge_rules answers it.
func _challenge(id: int, most: int, lots: Array, tested: bool, title: String = "Microscale") -> Dictionary:
	return {"id": id, "title": title, "brief": "A whole place at the smallest scale.",
		"starts_on": "2026-11-01", "ends_on": "2026-11-30", "entries_until": null, "entering": true, "test": false,
		"page": PAGE, "rules": {"most_parts": most if most > 0 else null,
			"set": {"number": "6075-2", "name": "Wolfpack Tower", "lots": lots, "from": "challenge"} if not lots.is_empty() else null,
			"tested": tested}, "rules_said": []}


## The line once Main has made it (CHALLENGE_LINE_AFTER) and it is shown.
func _until_line() -> Control:
	for _n: int in 900:
		await process_frame
		var line: Variant = _main.get("_challenge_line")
		if line is Control and (line as Control).visible:
			return line
	return _main.get("_challenge_line")


## Until the line has ticked the model as it is ([param done] says when).
func _until_ticked(done: Callable = Callable()) -> void:
	var world: BrickWorld = _main.get("_world")
	for _n: int in 600:
		await process_frame
		var state: Dictionary = _line.call("page_state")
		if int(state["checked_revision"]) == world.revision and (not done.is_valid() or done.call(state)):
			break
	await _frames(5)


## The line inside the window, over none of the bars, and never over the
## model as it is drawn: its rect against the model's box on screen.
func _layout(how: String) -> void:
	await _frames(5)
	var window: Rect2 = root.get_visible_rect()
	var rect: Rect2 = _line.get_global_rect()
	_check("%s, the line inside the window (%s in %s)" % [how, rect, window.size], rect.position.x >= window.position.x - 0.5
		and rect.end.x <= window.end.x + 0.5 and rect.position.y >= -0.5 and rect.end.y <= window.end.y + 0.5)
	var bars: Array = [["the menus", _main.get("_bar")], ["the toolbar", (_main.get("_shell") as Shell).toolbar]]
	var phone: Variant = _main.get("_phone")
	if phone != null:
		bars.append_array([["the phone's top bar", phone.get("_top")], ["its row of tools", phone.get("_row")],
			["its Fit", phone.get("_fit")]])
	for pair: Array in bars:
		var bar: Control = pair[1]
		if bar == null or not bar.is_visible_in_tree():
			continue
		_check("%s, over none of %s" % [how, pair[0]], not rect.grow(-1.0).intersects(bar.get_global_rect()))
	var camera: Camera3D = _main.get("_camera")
	var box: AABB = _main.call("_built_bounds")
	var drawn := Rect2(camera.unproject_position(box.get_endpoint(0)), Vector2.ZERO)
	for n: int in range(1, 8):
		drawn = drawn.expand(camera.unproject_position(box.get_endpoint(n)))
	var over: Rect2 = rect.intersection(drawn)
	var overlap: float = over.get_area() if rect.intersects(drawn) else 0.0
	_check("%s, never over the model: the line %s, the model drawn in %s, %d square points over it" % [how,
		rect, drawn, roundi(overlap)], overlap < 1.0 and drawn.get_area() > 0.0)


func _open_share() -> SharePanel:
	var shell: Shell = _main.get("_shell")
	if not shell.run("share"):
		_main.call("_share_wanted")
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 5000:
		var made: SharePanel = _main.get("_share_panel_made")
		if made != null and made.visible:
			return made
		await process_frame
	return _main.get("_share_panel_made")


## A press where [param control] is drawn, as a finger or the mouse gives
## it; said, and made by its signal, when the press did not reach it (a
## control out of reach is one failure, not every check after it).
func _press(control: BaseButton, what: String) -> void:
	await _frames(2)
	var at: Vector2 = control.get_global_rect().get_center()
	var heard: Array = [false]
	var listen := func() -> void: heard[0] = true
	control.pressed.connect(listen)
	var scale: Vector2 = Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	if Phone.on():
		for down: bool in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.position = at * scale
			touch.pressed = down
			Input.parse_input_event(touch)
			await _frames(3)
	else:
		var move := InputEventMouseMotion.new()
		move.position = at * scale
		Input.parse_input_event(move)
		await _frames(2)
		for down: bool in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = at * scale
			click.pressed = down
			Input.parse_input_event(click)
			await _frames(2)
	if control.pressed.is_connected(listen):
		control.pressed.disconnect(listen)
	if not _check("%s heard the press at %s" % [what, at], heard[0]):
		control.pressed.emit()
	await _frames(3)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var image: Image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(ProjectSettings.globalize_path(SHOTS + name))
		print("  wrote shots/challenge_line/%s" % name)


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _finish() -> void:
	print("")
	if _failures == 0:
		print("the month's challenge is said over the model, its rules ticked as it is built, and entered from Share in one press")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
