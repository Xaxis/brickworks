## Ask the builders, from the studio (askhelp, 2026-11-23): the Share panel's
## question to Talk's Help about the step open, with the parts picked, and the
## answers on parts coming back to light those parts in the open studio.
##
##   godot --path . --resolution 1280x800 --script src/dev/askhelp_probe.gd
##   ... -- --pictures=DIR   the Share panel's Ask, and a part an answer lit with its notice
##   PROBE_SIZE=390x844 tools/probe.sh askhelp_probe -- --pictures=DIR   laid out for a phone
##
## No network: FakeShared answers as api/people.js does (op=talk_ask,
## op=talk_asks) and api/share.js (publish, mine). The model is written here:
## 12 parts in 3 rows, a row a step, each in a colour of its own, so the part
## a body or an answer means is known from its colour.
##
## (a) Signed in, the model with its link open, the timeline on a step and two
##     parts picked: the toolbar's Share (on a phone More, then Share) shows
##     Ask the builders with the step's question and the two parts in words;
##     Ask in Talk publishes it first (this panel has not published it as it
##     is), as finished since the link is, then sends the model, the version
##     it made, the step, the two parts each with its colour and place, the
##     title and the question; the status says it is asked and Open the thread
##     opens its address. Asked again unchanged, nothing is published again;
##     asked about a work in progress changed since, it is published as work
##     in progress, never finished by asking.
## (b) The watch: with a question and no answer it asks again on its own
##     (every few seconds here; every 20, as the server says, in the app); an
##     answer on a known part lights it within one ask, its dot drawn, the
##     builder's selection and the view left as they were, a notice naming
##     who answered; a second answer lights its part too; Show selects and
##     frames the newest and its light goes; Got it lets the rest go; the list
##     says "in Talk" and Done puts one away here, sending nothing; no
##     questions left, it stops asking.
##
## One PASS or FAIL line per check; it exits 1 on any FAIL.
extends SceneTree

## The link's id. Not ID: inside FakeShared, SharedModels' own ID is meant.
const LINK := "Pr0beAskX1"
const TOKEN := "probe.ask.token"
const COLOURS: Array[int] = [1, 2, 4, 14, 15, 19, 25, 26, 27, 28, 70, 71]
const ROWS: Array[String] = ["3001", "3003", "3020"]
const THREAD := 77
const PATH := "/talk/t/77-how-should-i-build-step-2"
const URL := "http://127.0.0.1:9" + PATH
## How often the probe's watch asks again: a few seconds, not the app's 20.
const EVERY := 1.5

var _failures: int = 0
var _main: Node
var _pictures: String = ""
var _size: String = ""
var _phone: bool = false
var _taps: int = 0
var _placed: Dictionary = {}
var _part_of_colour: Dictionary = {}
## Set at the studio's last line: a script error ends a coroutine where it
## is, and its caller goes on, so a run cut short would read as passed.
var _reached_end: bool = false


class FakeShared extends SharedModels:
	var published: Array[Dictionary] = []
	var asked: Array[Dictionary] = []
	var asks_asked: int = 0
	var asks_answer: Array = []
	var resolved_calls: Array = []
	## The link was published once before this visit.
	var version: int = 1
	var wip_now: bool = false

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 404, "body": {"error": "not here"}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"model": LINK, "ready": true, "version": version, "newest": version,
			"open": true, "replies": true, "pins": true, "count": 0, "comments": [],
			"you": {"signed_in": true, "may_write": true, "why_not": "", "owner": true}}}

	func mine(_token: String) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"shared": [{"id": LINK, "published": true, "listed": wip_now,
			"barred": false, "wip": wip_now, "name": "Probe Ask"}],
			"credit": {"name": "Probe Builder", "handle": "probe-builder"}}}

	func publish(_token: String, body: Dictionary) -> Dictionary:
		published.append(body.duplicate())
		await (Engine.get_main_loop() as SceneTree).process_frame
		version += 1
		var as_wip: bool = bool(body.get("wip", false))
		var finished: bool = wip_now and not as_wip
		wip_now = as_wip
		return {"code": 200, "body": {"id": LINK, "url": "http://127.0.0.1:9/m/" + LINK, "parts": 12,
			"listed": bool(body.get("listed", false)), "version": version, "updated": true,
			"author": "Probe Builder" if body.has("author") else null, "wip": as_wip, "finished": finished,
			"said": ""}}

	func talk_ask(token: String, body: Dictionary) -> Dictionary:
		asked.append(body.merged({"token": token}))
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 201, "body": {"thread": {"id": THREAD, "title": body.get("title")},
			"post": {"id": 700 + asked.size()},
			"ask": {"model": body.get("model"), "version": body.get("version"), "step": body.get("step"),
				"parts": body.get("parts")},
			"path": PATH, "url": URL, "every": 20}}

	func talk_asks(_token: String, model: String) -> Dictionary:
		asks_asked += 1
		await (Engine.get_main_loop() as SceneTree).process_frame
		if model != LINK:
			return {"code": 403, "body": {"error": "Only its builder sees a model's questions."}}
		return {"code": 200, "body": {"asks": asks_answer.duplicate(true), "open": true, "every": 20}}

	func resolve_pin(_token: String, id: int, resolved: bool) -> Dictionary:
		resolved_calls.append([id, resolved])
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 404, "body": {"error": "There is no such comment."}}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	for given: String in OS.get_cmdline_user_args():
		if given.begins_with("--pictures="):
			_pictures = given.substr("--pictures=".length())
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	await _the_studio()
	_check(_reached_end, "the run reached its end")
	_finish()


## 12 parts, 4 across and 3 deep, a row a step, each its own colour, with
## its link's meta line.
func _model_text() -> String:
	var lines: PackedStringArray = PackedStringArray(["0 Probe Ask", "0 Name: probe_ask.ldr",
		"0 Author: Brickworks", ModelStore.SHARE_META + LINK])
	var n: int = 0
	for row: int in ROWS.size():
		for column: int in 4:
			var colour: int = COLOURS[n]
			var at := [float((column - 2) * 120 + 60), 0.0, float((row - 1) * 80)]
			_placed[colour] = at
			_part_of_colour[colour] = ROWS[row]
			lines.append("1 %d %d %d %d 1 0 0 0 1 0 0 0 1 %s.dat" % [colour, int(at[0]), int(at[1]),
				int(at[2]), ROWS[row]])
			n += 1
		lines.append("0 STEP")
	return "\n".join(lines) + "\n"


func _the_studio() -> void:
	var fake := FakeShared.new()
	# A window a phone's size is laid out for one, as the web build lays out a
	# phone's browser (Phone.on is the web's alone).
	var window: Vector2i = DisplayServer.window_get_size()
	if mini(window.x, window.y) < int(Phone.NARROW):
		Phone._on = 1
		Phone._wide = false
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_shared", fake)
	root.add_child(_main)
	for _n: int in 240:
		await process_frame
	# A phone draws at a browser's scale, as twist_probe holds it.
	if _main.get("_phone") != null:
		(_main.get("_phone") as Node).set_process(false)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
		await _settle()
	var account: Account = _main.get("_account")
	var store: ModelStore = _main.get("_store")
	var bar: ModelBar = _main.get("_bar")
	var builder: Builder = _main.get("_builder")
	var world: BrickWorld = _main.get("_world")
	var shell: Shell = _main.get("_shell")
	await account.deployment.wait()
	account.email = "delivered+askhelp-app@resend.dev"
	account._access = TOKEN
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.over_13 = true
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	var opened: Dictionary = store.open_text(_model_text(), "probe_ask")
	bar.opened.emit(int(opened["placed"]))
	for _n: int in 600:
		await process_frame
		if store.awaited.is_empty():
			break
	await _settle()
	var playback: Node = _main.get("_playback")
	if playback != null and playback.has_method("stop"):
		playback.call("stop")
	_phone = _main.get("_phone") != null
	print("\n(a) ask the builders (%s%s)" % [_size, ", a phone's layout" if _phone else ""])
	_check(store.share_id == LINK and fake.asks_asked >= 1 and _main.get("_part_pins") == null,
		"opened with its link and signed in, its questions are asked for once (%d), none, nothing made"
			% fake.asks_asked)

	# The timeline on its second step, two of that step's parts picked.
	var steps: StepsBar = _main.get("_steps")
	await steps.start(world, _main.get("_library"), store.scenery)
	var since: int = Time.get_ticks_msec()
	while steps.is_starting() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	steps.go_to_found(1)
	await _settle()
	var step: int = int(_main.call("_timeline_page"))
	var picked: Array[int] = []
	for colour: int in [COLOURS[4], COLOURS[6]]:
		picked.append(_brick_coloured(world, colour))
	builder.clear_selection()
	for id: int in picked:
		builder.select_brick(id, true)
	await _settle()
	_check(step >= 1 and builder.selection.size() == 2,
		"the timeline on step %d, %d parts picked" % [step, builder.selection.size()])

	var share_at: Control = await _share_button()
	_check(share_at != null, "Share is %s" % ("on the toolbar" if not _phone else "in More"))
	if share_at == null:
		return
	await _press(share_at)
	await _settle()
	var panel: SharePanel = _main.get("_share_panel")
	for _n: int in 60:
		await process_frame
	var named: Dictionary = panel.controls_by_name()
	var said: Dictionary = panel.page_state().get("ask", {})
	var ask: Button = named.get("share_ask")
	var question: LineEdit = named.get("share_question")
	var want_question: String = "How should I build step %d?" % step
	_check(panel.visible and ask != null and ask.is_visible_in_tree() and not ask.disabled
		and question != null and question.text == want_question,
		"the panel asks \"%s\" with %s" % [question.text if question != null else "", "Ask in Talk" if ask != null else "no button"])
	var about: String = str(said.get("about", ""))
	_check(about.begins_with("Asks in Talk's Help about step %d, with the " % step) and about.contains(" and the ")
		and about.contains("2 × 2 brick") and about.ends_with("lit in 3D."),
		"the parts in words: \"%s\"" % about)
	if ask == null:
		return
	await _into_view(ask)
	await _picture("ask_panel")

	var taps_to_ask: int = _taps + 1
	await _press(ask)
	await _asked(panel, 1)
	var sent: Dictionary = fake.asked[0] if not fake.asked.is_empty() else {}
	_check(fake.published.size() == 1 and fake.published[0].get("wip", false) == false
		and str(fake.published[0].get("id", "")) == LINK,
		"published first as finished, as its link is (%d sent, wip %s)" % [fake.published.size(),
			fake.published[0].get("wip") if not fake.published.is_empty() else "-"])
	var parts: Array = sent.get("parts", []) if sent.get("parts") is Array else []
	var colours: Array = parts.map(func(one: Dictionary) -> int: return int(one.get("colour", -1)))
	colours.sort()
	var places: bool = parts.size() == 2
	for one: Dictionary in parts:
		var colour: int = int(one.get("colour", -1))
		places = places and str(one.get("part", "")) == str(_part_of_colour.get(colour, "")) \
			and _near(one.get("at"), _placed.get(colour, [])) and one.has("turn")
	var want_colours: Array = [COLOURS[4], COLOURS[6]]
	want_colours.sort()
	_check(str(sent.get("model", "")) == LINK and int(sent.get("version", 0)) == fake.version
		and int(sent.get("step", 0)) == step and str(sent.get("token", "")) == TOKEN,
		"sent as the builder: model %s, version %s of %d, step %s" % [sent.get("model"), sent.get("version"),
			fake.version, sent.get("step")])
	_check(places and colours == want_colours,
		"the two parts picked, each with its colour and place: %s" % [parts])
	_check(str(sent.get("title", "")) == want_question and str(sent.get("body", "")) == want_question,
		"its title and question: \"%s\" / \"%s\"" % [sent.get("title"), sent.get("body")])
	said = panel.page_state().get("ask", {})
	var open_thread: Button = panel.controls_by_name().get("share_ask_open")
	_check(str(said.get("state", "")) == "asked" and str(panel.page_state().get("status", "")).begins_with(
		"Asked in Talk's Help, step %d in 3D with 2 parts lit." % step) and open_thread != null,
		"the status says so: \"%s\", with Open the thread" % panel.page_state().get("status", ""))
	_check(taps_to_ask <= 3, "a question in Talk %d taps from the studio" % taps_to_ask)
	if open_thread != null:
		Outside.opened.clear()
		await _press(open_thread)
		_check(Outside.opened == [URL] and _taps <= 4,
			"Open the thread opens %s (%d taps from the studio)" % [Outside.opened, _taps])

	# Asked again unchanged: no new version.
	await _press(ask)
	await _asked(panel, 2)
	_check(fake.asked.size() == 2 and fake.published.size() == 1
		and int(fake.asked[1].get("version", 0)) == fake.version,
		"asked again unchanged, nothing is published again (%d published, version %s)"
			% [fake.published.size(), fake.asked[1].get("version") if fake.asked.size() > 1 else "-"])
	# A work in progress, changed since: published as one.
	fake.wip_now = true
	panel.set("_checked_for", "")
	panel.set("_published_revision", -1)
	await _press(ask)
	await _asked(panel, 3)
	_check(fake.asked.size() == 3 and fake.published.size() == 2 and fake.published[1].get("wip", false) == true,
		"a work in progress changed since is published as work in progress first (wip %s)"
			% [fake.published[1].get("wip") if fake.published.size() > 1 else "-"])

	# Enter in the box and a press of Ask in Talk while the sign-in is still
	# being renewed: asked once (self_attack, partplaces F1).
	question.text = "Which plate holds the sails?"
	account.renewing = true
	question.text_submitted.emit(question.text)
	await _press(ask)
	account.renewing = false
	account._confirmed.emit()
	await _asked(panel, 4)
	await _seconds(1.0)
	_check(fake.asked.size() == 4 and str(fake.asked[-1].get("body", "")) == "Which plate holds the sails?",
		"Enter and Ask in Talk at once ask once (%d asks, 4 wanted)" % fake.asked.size())
	# A question longer than Talk takes: refused with words, never cut.
	question.text = "x".repeat(4001)
	await _press(ask)
	await _settle()
	_check(fake.asked.size() == 4 and panel.ask_state == "failed" and panel.ask_said.contains("4,000")
		and question.text.length() == 4001,
		"a question of 4,001 characters is refused in words, kept whole (%d asks, \"%s\")"
			% [fake.asked.size(), panel.ask_said])
	question.text = ""

	print("\n(b) the answers, watched")
	var pins: Control = _main.call("_part_pins_now")
	pins.set("every_for_probe", EVERY)
	var bare: Dictionary = _an_ask([])
	fake.asks_answer = [bare]
	var before: int = fake.asks_asked
	pins.call("set_asks", [] as Array, 20.0, LINK)
	_main.call("_look_for_asks")
	for _n: int in 30:
		await process_frame
	var watching: Dictionary = pins.page_state()
	await _seconds(EVERY * 2.5)
	_check(int(watching.get("asks", 0)) == 1 and bool(watching.get("polling", false))
		and fake.asks_asked - before >= 3,
		"a question and no answer: asked again on its own (%d asks)" % (fake.asks_asked - before))

	panel.visible = false
	builder.clear_selection()
	builder.select_brick(_brick_coloured(world, COLOURS[0]), false)
	var camera: Camera3D = _main.get("_camera")
	await _camera_still()
	var view_was: Transform3D = camera.global_transform
	var chosen_was: Array = builder.selection.keys()
	var first_brick: int = _brick_coloured(world, COLOURS[4])
	fake.asks_answer = [_an_ask([_an_answer(901, "Bea Builder", COLOURS[4], "Its tab goes under the 1 × 2 plate.")])]
	var waited: float = await _until(func() -> bool:
		return (pins.page_state().get("answers_lit", []) as Array) == [first_brick], EVERY * 3.0)
	var state: Dictionary = pins.page_state()
	_check((state.get("answers_lit", []) as Array) == [first_brick] and waited >= 0.0,
		"an answer on a part lights it within one ask (%.1f s, lit %s, meant #%d)" % [waited,
			state.get("answers_lit"), first_brick])
	_check((pins.get("_dots") as Dictionary).has(-901), "its dot is drawn")
	_check(str(state.get("answer_notice", "")) == "New answer on a part in Talk, from Bea Builder"
		and pins.controls_by_name().has("answers_notice_show"),
		"the notice names who answered: \"%s\", with Show" % state.get("answer_notice", ""))
	_check(builder.selection.keys() == chosen_was and camera.global_transform.is_equal_approx(view_was),
		"the builder's selection and the view are left as they were")
	await _picture("answer_lit")

	var second_brick: int = _brick_coloured(world, COLOURS[6])
	fake.asks_answer = [_an_ask([_an_answer(901, "Bea Builder", COLOURS[4], "Its tab goes under the 1 × 2 plate."),
		_an_answer(902, "Cy Stacks", COLOURS[6], "Turn this one round first.")])]
	waited = await _until(func() -> bool:
		return (pins.page_state().get("answers_lit", []) as Array).size() == 2, EVERY * 3.0)
	state = pins.page_state()
	var lit: Array = state.get("answers_lit", [])
	lit.sort()
	var both: Array = [first_brick, second_brick]
	both.sort()
	_check(lit == both and str(state.get("answer_notice", "")) == "New answer on a part in Talk, from Cy Stacks",
		"a second answer lights its part too (%.1f s): %s, \"%s\"" % [waited, lit, state.get("answer_notice", "")])

	var show: Control = pins.controls_by_name().get("answers_notice_show")
	if show != null:
		await _press(show)
		await _camera_still()
	_check(show != null and builder.selection.keys() == [second_brick] and _framed(second_brick)
		and (pins.page_state().get("answers_lit", []) as Array) == [first_brick],
		"Show selects and frames the newest, and its light goes (%s, lit %s)" % [builder.selection.keys(),
			pins.page_state().get("answers_lit")])
	var got_it: Control = pins.controls_by_name().get("answers_notice_close")
	if got_it != null:
		await _press(got_it)
	_check(got_it != null and (pins.page_state().get("answers_lit", []) as Array).is_empty(),
		"Got it lets the rest go")

	# The timeline put away, as one is before turning to the list.
	steps.stop()
	await _settle()
	pins.call("open_list")
	await _settle()
	await _picture("answers_list")
	var rows: Array = (pins.page_state().get("list", {}) as Dictionary).get("rows", [])
	var talk_rows: Array = rows.filter(func(row: Dictionary) -> bool: return bool(row.get("talk", false)))
	_check(talk_rows.size() == 2 and str((talk_rows[0] as Dictionary).get("by", "")).contains("in Talk")
		and str((talk_rows[0] as Dictionary).get("settle", "")) == "Done",
		"the list says them in Talk, with Done: %s" % [talk_rows.map(func(row: Dictionary) -> String:
			return "%s / %s" % [row.get("by"), row.get("settle")])])
	var done: Control = pins.controls_by_name().get("part_pin_resolve_%d" % int((talk_rows[0] as Dictionary).get("number", 0))) \
		if not talk_rows.is_empty() else null
	# Pressed, the list is filled again and its buttons freed: whether there
	# was one is kept first.
	var had_done: bool = done != null
	if done != null:
		await _into_view(done)
		await _press(done)
	_check(had_done and fake.resolved_calls.is_empty() and int(pins.page_state().get("open", 0)) == 1,
		"Done puts one away here and sends nothing (%s, %d open)" % [fake.resolved_calls,
			int(pins.page_state().get("open", 0))])

	# The app's own pace: as the server says, inside the minute.
	pins.set("every_for_probe", 0.0)
	pins.call("set_asks", fake.asks_answer.duplicate(true), 20.0, LINK)
	var app_every: float = float(pins.page_state().get("every", 0.0))
	_check(is_equal_approx(app_every, 20.0), "in the app it asks every %.0f s, as the server says" % app_every)
	pins.set("every_for_probe", EVERY)
	pins.call("set_asks", fake.asks_answer.duplicate(true), 20.0, LINK)

	fake.asks_answer = []
	await _until(func() -> bool: return not bool(pins.page_state().get("polling", true)), EVERY * 3.0)
	var stopped_at: int = fake.asks_asked
	await _seconds(EVERY * 3.0)
	_check(not bool(pins.page_state().get("polling", true)) and fake.asks_asked == stopped_at
		and int(pins.page_state().get("asks", 1)) == 0,
		"no questions left, it stops asking (%d asks since)" % (fake.asks_asked - stopped_at))

	# Words typed about one model are never asked about another: a new one
	# begun puts the box back to its first question (self_attack,
	# hubprogram F1).
	var share_box: LineEdit = question
	share_box.text = "Why does the tower lean?"
	store.begin("Another model")
	await _settle()
	_check(share_box.text != "Why does the tower lean?" and share_box.text.begins_with("How should I build")
		and panel.ask_state == "idle",
		"another model begun, the box starts afresh (\"%s\")" % share_box.text)
	_reached_end = true
	_main.queue_free()
	for _n: int in 10:
		await process_frame


func _an_ask(answers: Array) -> Dictionary:
	return {"thread": THREAD, "title": "How should I build step 2?", "path": PATH, "at": "2026-11-23T12:00:00+00:00",
		"last_at": "2026-11-23T12:00:00+00:00", "locked": false,
		"ask": {"model": LINK, "version": 2, "step": 2, "parts": [], "name": "Probe Ask"}, "answers": answers}


func _an_answer(id: int, by: String, colour: int, body: String) -> Dictionary:
	return {"id": id, "body": body, "at": "2026-11-23T12:0%d:00+00:00" % (id % 10), "edited_at": null, "by": by,
		"handle": by.to_lower().replace(" ", "-"), "mine": false, "by_starter": false,
		"pin": {"part": _part_of_colour.get(colour, "3001"), "colour": colour, "at": _placed.get(colour, []),
			"turn": null, "section": "", "line": 5, "near": [], "full": true}}


# -- helpers ---------------------------------------------------------------------

## Share as a person reaches it: the toolbar's, or on a phone More, then its
## Share.
func _share_button() -> Control:
	if not _phone:
		var shell: Shell = _main.get("_shell")
		return shell.toolbar.controls_by_name().get("tool_share") if shell.toolbar != null else null
	var phone: Control = _main.get("_phone")
	var more: Control = phone.call("controls_by_name").get("phone_more")
	if more == null:
		return null
	await _press(more)
	await _settle()
	return phone.call("controls_by_name").get("phone_quick_share")


func _asked(panel: SharePanel, n: int) -> void:
	var fake: FakeShared = _main.get("_shared")
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 60000:
		await process_frame
		if fake.asked.size() >= n and panel.ask_state in ["asked", "failed"]:
			break
		if panel.ask_state == "failed":
			break
	if panel.ask_state == "failed":
		print("       the panel said: %s" % panel.ask_said)
	await _settle()


## Seconds until [param ok] holds, at most [param most]; -1 when it never did.
func _until(ok: Callable, most: float) -> float:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(most * 1000.0):
		if bool(ok.call()):
			return (Time.get_ticks_msec() - since) / 1000.0
		await process_frame
	return -1.0


func _seconds(seconds: float) -> void:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(seconds * 1000.0):
		await process_frame


func _brick_coloured(world: BrickWorld, colour: int) -> int:
	for brick: BrickWorld.Brick in world.bricks():
		if brick.color_code == colour:
			return brick.id
	return 0


static func _near(given: Variant, want: Array) -> bool:
	if not given is Array or (given as Array).size() != 3 or want.size() != 3:
		return false
	for i: int in 3:
		if absf(float(given[i]) - float(want[i])) > 0.01:
			return false
	return true


## Whether the view is on [param brick_id]: its middle well inside the
## model's room, and the part not lost in it.
func _framed(brick_id: int) -> bool:
	var world: BrickWorld = _main.get("_world")
	var camera: Camera3D = _main.get("_camera")
	var library: PartLibrary = _main.get("_library")
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return false
	var box: AABB = (brick.transform * library.mesh_for(brick.part_id).bounds).abs()
	if camera.is_position_behind(box.get_center()):
		return false
	var room: Rect2 = _main.call("_model_rect")
	var at: Vector2 = camera.unproject_position(box.get_center())
	var across: float = camera.unproject_position(box.position).distance_to(camera.unproject_position(box.end))
	return at.distance_to(room.get_center()) < minf(room.size.x, room.size.y) * 0.2 \
		and across > minf(room.size.x, room.size.y) * 0.04


## The view come to rest: unmoved for 300 ms, 5 s at the most.
func _camera_still() -> void:
	var camera: Camera3D = _main.get("_camera")
	var last: Transform3D = camera.global_transform
	var since: int = Time.get_ticks_msec()
	var still_since: int = since
	while Time.get_ticks_msec() - since < 5000:
		await process_frame
		var now: Transform3D = camera.global_transform
		if now.origin.distance_to(last.origin) > 0.001 or not now.basis.is_equal_approx(last.basis):
			still_since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - still_since > 300:
			break
		last = now
	await _settle()


func _into_view(control: Control) -> void:
	var up: Node = control.get_parent()
	while up != null and not up is ScrollContainer:
		up = up.get_parent()
	if up != null:
		(up as ScrollContainer).ensure_control_visible(control)
		for _n: int in 3:
			await process_frame


func _settle() -> void:
	for _n: int in 20:
		await process_frame
	await RenderingServer.frame_post_draw


## Pressed where it is on screen: a finger's tap on a phone's layout, the
## mouse's click on a desktop's.
func _press(control: Control) -> void:
	_taps += 1
	var at: Vector2 = control.get_global_rect().get_center()
	if _phone:
		for down: bool in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.pressed = down
			touch.position = _as_event(at)
			Input.parse_input_event(touch)
			await process_frame
		await _settle()
		return
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	motion.relative = Vector2(1, 0)
	Input.parse_input_event(motion)
	await process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


## A picture, windowed and asked for (--pictures=DIR): <size>_<name>.png.
func _picture(name: String) -> void:
	if _pictures.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_pictures)
	var image: Image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		var file: String = _pictures.path_join("%s_%s.png" % [_size, name])
		image.save_png(file)
		print("     wrote %s" % file)


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILED" % _failures if _failures else "ask the builders: every check passed")
	quit(1 if _failures else 0)
