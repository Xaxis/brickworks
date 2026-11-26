## pubbind: an act pressed on one model is that model's from the press to the
## server's answer. Another model opened while it works is never sent in its
## place, never given what the server answered, and the share panel shows the
## model on the baseplate (SharePanel._show_model, _follow_model).
##
## Every case runs the app (src/main.tscn) with the server stubbed, so nothing
## leaves the box:
##   steps      Publish on A (160 parts, its own link), B (its own link) opened
##              while the steps are worked out and tested: nothing is sent, B
##              keeps its link, "“pb wall” was not published: another model
##              was opened."
##   server     the same, B opened while the server answers: A is sent under
##              its own link, B is given nothing, the status says so with the
##              link; and again with a B that has no link
##   author     B opened while the profile's name is asked for (after the
##              steps, before the send): nothing is sent
##   normal     no open: A is sent under its own link and is given the answer's
##   follows    A's words typed in the panel, C opened: the panel shows C's name
##              and no words of A's, and Publish sends C under C's name
##   ask        Ask in Talk on A, which publishes first; B opened while the
##              server answers: nothing is asked, and the status says where A
##              was published
##   ask_fail   Ask in Talk on A, published as it is, with words typed for A;
##              B opened while Talk answers, Talk refuses (pubreview F1): the
##              panel shows B with none of A's words, the status names A, and
##              Publish then sends B as B
##   ask_moved  the same, Talk takes it: the status names A and says where
##              its question is; Open the thread is not shown with B
##   enter_server  Enter on A, B opened while the publish is answered
##              (pubreview F2): A is published, nothing is entered, and the
##              status says so of A by name
##   enter_enter  Enter on A, B opened while the entry is answered (pubreview
##              F3): A's link is entered, B is not shown as entered, and the
##              status says it of A alone, none of B's words glued on
##   unpublish  Take down on A, B opened while the server answers: A's link is
##              taken down, B's state and link are untouched
##   clear      Clear asked on A, B opened while the question is up: B is not
##              emptied
##   assistant  a design run's reply arriving after its world was cleared (as an
##              open clears it): nothing is built, the run ends saying so; and
##              the same reply with no clear builds
## Each status said of A once B is open is drawn in German, French and
## Spanish too, with nothing left in English but names and links.
##
##   godot --headless --path . --script src/dev/pubbind_probe.gd -- [--cases=a,b]
## In a window (godot --path . --resolution 1280x800 ...), --pictures=DIR
## keeps the window as each line said of A shows, as DIR/<case>.png.
extends SceneTree

const PROBE_DIR := "user://pubbind_probe/"
const A_LINK := "pbAAAAAAAA"
const B_LINK := "pbBBBBBBBB"
const ANSWER_LINK := "pbNNNNNNNN"
const WATCHDOG := 3600.0

const B_TEXT := """0 FILE pb_other.ldr
0 pubbind other
0 Name: pb_other.ldr
0 !BRICKWORKS SHARE pbBBBBBBBB
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"""

const C_TEXT := """0 FILE pb_plain.ldr
0 pubbind plain
0 Name: pb_plain.ldr
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"""


## The server, stubbed: what each call was sent, and a hold run inside the
## call that is armed (the moment another model is opened).
class FakeShared extends SharedModels:
	var bodies: Array = []
	var asks: Array = []
	var downs: Array = []
	var enters: Array = []
	var ask_code: int = 201
	var hold: Callable = Callable()
	var hold_on: String = ""

	func _held(call: String) -> void:
		if hold_on == call and hold.is_valid():
			hold_on = ""
			await hold.call()

	func publish(_token: String, body: Dictionary) -> Dictionary:
		bodies.append(body.duplicate())
		await _held("publish")
		return {"code": 201, "body": {"id": ANSWER_LINK, "url": "https://example.invalid/m/" + ANSWER_LINK,
			"version": 2, "updated": true, "parts": 160}}

	func mine(_token: String) -> Dictionary:
		await _held("mine")
		return {"code": 200, "body": {"shared": []}}

	func talk_ask(_token: String, body: Dictionary) -> Dictionary:
		asks.append(body.duplicate())
		await _held("talk_ask")
		if ask_code != 201:
			return {"code": ask_code, "body": {"error": "Talk is down"}}
		return {"code": 201, "body": {"thread": {"id": 1}, "path": "/talk/t/1"}}

	func enter(_token: String, model: String, way: String) -> Dictionary:
		enters.append([model, way])
		await _held("enter")
		return {"code": 201, "body": {}}

	func talk_asks(_token: String, _model: String) -> Dictionary:
		return {"code": 200, "body": {"asks": []}}

	func unpublish(_token: String, id: String) -> Dictionary:
		downs.append(id)
		await _held("unpublish")
		return {"code": 200, "body": {}}

	func challenge_entry(_token: String, _model: String) -> Dictionary:
		return {"code": 200, "body": {}}


## An assistant whose turns are put in by hand (second_design_probe).
class Offline extends Assistant:
	func _send() -> void:
		pass


var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _store: ModelStore
var _builder: Builder
var _panel: Node
var _fake: FakeShared
var _paths: Dictionary = {}
## Where the window is kept as each line said of A shows (--pictures=DIR).
var _pictures: String = ""


func _initialize() -> void:
	_run()


func _ok(ok: bool, what: String) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	create_timer(WATCHDOG).timeout.connect(func() -> void:
		print("pubbind_probe: FAILED, not finished in %d s" % int(WATCHDOG))
		quit(1))
	# Anything not stubbed fails at once rather than reaching a server.
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var cases: PackedStringArray = PackedStringArray(["steps", "server", "author", "normal", "follows", "ask",
		"ask_fail", "ask_moved", "enter_server", "enter_enter", "unpublish", "clear", "assistant"])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cases="):
			cases = arg.trim_prefix("--cases=").split(",", false)
		elif arg.begins_with("--pictures="):
			_pictures = arg.trim_prefix("--pictures=")
	DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	_paths["a"] = _write("pb_a.ldr", _wall_text())
	_paths["b"] = _write("pb_other.ldr", B_TEXT)
	_paths["c"] = _write("pb_plain.ldr", C_TEXT)
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(240)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_store = _main.get("_store")
	_builder = _main.get("_builder")
	_panel = _main.get("_share_panel")
	if not _ok(_panel != null, "the share panel is made"):
		quit(1)
		return
	_fake = FakeShared.new()
	# In the tree, as Main's own: what it does not stub asks 127.0.0.1:9 and
	# is refused. Main's too, so the month's challenge line is made (a run's
	# line is made only with a probe's own SharedModels) and an ask's pins
	# are asked of it.
	root.add_child(_fake)
	_panel.set("shared", _fake)
	_main.set("_shared", _fake)
	_main.call("_make_challenge_line")
	_sign_in()
	if "steps" in cases:
		await _case_steps()
	if "server" in cases:
		await _case_server("b")
		await _case_server("c")
	if "author" in cases:
		await _case_author()
	if "normal" in cases:
		await _case_normal()
	if "follows" in cases:
		await _case_follows()
	if "ask" in cases:
		await _case_ask()
	if "ask_fail" in cases:
		await _case_ask_talk(false)
	if "ask_moved" in cases:
		await _case_ask_talk(true)
	if "enter_server" in cases:
		await _case_enter("publish")
	if "enter_enter" in cases:
		await _case_enter("enter")
	if "unpublish" in cases:
		await _case_unpublish()
	if "clear" in cases:
		await _case_clear()
	if "assistant" in cases:
		await _case_assistant()
	print("\npubbind_probe: %d failed" % _failures)
	quit(1 if _failures > 0 else 0)


# -- the cases --------------------------------------------------------------


func _case_steps() -> void:
	print("\nsteps: Publish on A, B opened while its steps are worked out and tested")
	await _start_on_a()
	var status: Label = _panel.get("_status")
	var done: Array = [false]
	var run: Callable = func() -> void:
		await _panel.call("publish")
		done[0] = true
	run.call()
	for _n: int in 40000:
		if done[0] or status.text.begins_with("Working out its steps"):
			break
		await process_frame
	var during: String = status.text
	await _open("b")
	var opened_during: bool = not done[0]
	print("  the status when B was opened: \"%s\"; the publish still running: %s" % [during, opened_during])
	await _until(done)
	_ok(opened_during and during.begins_with("Working out its steps"), "B was opened while the steps were worked out")
	_ok(_fake.bodies.is_empty(), "nothing was sent (%d publish(es))" % _fake.bodies.size())
	_ok(_store.share_id == B_LINK, "B keeps its own link (%s)" % _store.share_id)
	_ok(status.text == "“pb wall” was not published: another model was opened.",
		"the status says so of A by name: \"%s\"" % status.text.left(120))
	_in_languages(status.text, ["pb wall"])
	await _picture("steps")
	_ok((_panel.get("_name") as LineEdit).text == _store.title,
		"the panel shows B's name (\"%s\")" % (_panel.get("_name") as LineEdit).text)
	_ok(str(_panel.get("state")) != "publishing" and not (_panel.get("_publish") as Button).disabled,
		"Publish can be pressed again (state %s)" % _panel.get("state"))


func _case_server(other: String) -> void:
	var named: String = "B" if other == "b" else "C (no link)"
	print("\nserver: Publish on A, %s opened while the server answers" % named)
	await _start_on_a()
	var status: Label = _panel.get("_status")
	_fake.hold = func() -> void: await _open(other)
	_fake.hold_on = "publish"
	await _panel.call("publish")
	var body: Dictionary = _fake.bodies[0] if not _fake.bodies.is_empty() else {}
	_ok(_fake.bodies.size() == 1, "one publish was sent (%d)" % _fake.bodies.size())
	_ok(str(body.get("id", "")) == A_LINK, "under A's own link (%s)" % str(body.get("id", "(none)")))
	_ok(str(body.get("model", "")).contains("pubbind wall"), "with A's text")
	var want: String = B_LINK if other == "b" else ""
	_ok(_store.share_id == want, "%s is given nothing: its link is \"%s\"" % [named, _store.share_id])
	_ok(status.text.begins_with("Published “pb wall” at example.invalid/m/%s, but another model was opened meanwhile"
		% ANSWER_LINK), "the status says where A went: \"%s\"" % status.text.left(160))
	_ok((_panel.get("_name") as LineEdit).text == _store.title, "the panel shows %s's name" % named)
	_ok(str(_panel.get("_published_for")) != ANSWER_LINK, "the panel does not hold A's link as the one published")


func _case_author() -> void:
	print("\nauthor: Publish on A credited with no name yet, B opened while the name is asked for")
	await _start_on_a()
	var status: Label = _panel.get("_status")
	var credit: CheckBox = _panel.get("_credit")
	credit.button_pressed = true
	(_panel.get("_author") as LineEdit).text = ""
	await _frames(5)
	_fake.hold = func() -> void: await _open("b")
	_fake.hold_on = "mine"
	await _panel.call("publish")
	_ok(_fake.hold_on.is_empty(), "B was opened while the name was asked for")
	_ok(_fake.bodies.is_empty(), "nothing was sent (%d)" % _fake.bodies.size())
	_ok(_store.share_id == B_LINK, "B keeps its own link (%s)" % _store.share_id)
	_ok(status.text == "“pb wall” was not published: another model was opened.",
		"the status says so of A by name: \"%s\"" % status.text.left(120))
	credit.button_pressed = false


func _case_normal() -> void:
	print("\nnormal: Publish on A, nothing opened")
	await _start_on_a()
	var status: Label = _panel.get("_status")
	await _panel.call("publish")
	var body: Dictionary = _fake.bodies[0] if not _fake.bodies.is_empty() else {}
	_ok(_fake.bodies.size() == 1 and str(body.get("id", "")) == A_LINK, "A is sent under its own link")
	_ok(_store.share_id == ANSWER_LINK, "and given the link the server answered (%s)" % _store.share_id)
	_ok(status.text.begins_with("Version 2 is up at this link"), "the status: \"%s\"" % status.text.left(100))


func _case_follows() -> void:
	print("\nfollows: A's words typed in the panel, C opened, Publish")
	await _start_on_a()
	(_panel.get("_name") as LineEdit).text = "Named for A"
	(_panel.get("_about") as TextEdit).text = "words typed for A"
	(_panel.get("_tags") as LineEdit).text = "for-a"
	await _open("c")
	_ok((_panel.get("_name") as LineEdit).text == _store.title,
		"the panel shows C's name (\"%s\")" % (_panel.get("_name") as LineEdit).text)
	_ok((_panel.get("_about") as TextEdit).text.is_empty() and (_panel.get("_tags") as LineEdit).text.is_empty(),
		"and none of A's words")
	await _panel.call("publish")
	var body: Dictionary = _fake.bodies[0] if not _fake.bodies.is_empty() else {}
	_ok(str(body.get("name", "")) == _store.title.get_basename() or str(body.get("name", "")) == _store.title,
		"C is published under its own name (\"%s\")" % str(body.get("name", "")))
	_ok(str(body.get("description", "")).is_empty() and not body.has("id"), "with none of A's words or link")


func _case_ask() -> void:
	print("\nask: Ask in Talk on A, which publishes first; B opened while the server answers")
	await _start_on_a()
	var status: Label = _panel.get("_status")
	_fake.hold = func() -> void: await _open("b")
	_fake.hold_on = "publish"
	await _panel.call("ask_builders")
	_ok(_fake.hold_on.is_empty(), "B was opened while A was published")
	_ok(_fake.asks.is_empty(), "nothing was asked (%d)" % _fake.asks.size())
	_ok(str(_panel.get("ask_state")) == "failed", "the question failed (%s)" % _panel.get("ask_state"))
	_ok(status.text == ("“pb wall” was published at example.invalid/m/%s, but the question about it was not asked: "
		+ "another model was opened.") % ANSWER_LINK, "the status says so of A by name, and where it went: \"%s\""
		% status.text.left(160))
	_in_languages(status.text, ["pb wall", "example.invalid/m/" + ANSWER_LINK])
	_ok(_store.share_id == B_LINK, "B keeps its own link (%s)" % _store.share_id)


## Ask in Talk on A, published as it is, with A's words typed in the panel;
## B opened while Talk answers. Talk refuses ([param taken] false) or takes it.
func _case_ask_talk(taken: bool) -> void:
	print("\nask_%s: Ask in Talk on A, B opened while Talk answers, which %s" % ["moved" if taken else "fail",
		"takes the question" if taken else "refuses; then Publish"])
	await _start_on_a()
	(_panel.get("_about") as TextEdit).text = "words typed for A"
	(_panel.get("_tags") as LineEdit).text = "for-a"
	_panel.set("state", "published")
	_panel.set("_published_for", A_LINK)
	_panel.set("_published_revision", _world.revision)
	_panel.set("_checked_for", A_LINK)
	_panel.set("ask_state", "idle")
	var status: Label = _panel.get("_status")
	_fake.asks.clear()
	_fake.ask_code = 201 if taken else 500
	_fake.hold = func() -> void: await _open("b")
	_fake.hold_on = "talk_ask"
	await _panel.call("ask_builders")
	await _frames(5)
	var ask: Dictionary = _fake.asks[0] if not _fake.asks.is_empty() else {}
	var named: String = (_panel.get("_name") as LineEdit).text
	print("  asked %d about %s; the panel names \"%s\", its words \"%s\"; ask_state %s; status \"%s\""
		% [_fake.asks.size(), str(ask.get("model", "(none)")), named, (_panel.get("_about") as TextEdit).text,
			_panel.get("ask_state"), status.text.left(160)])
	_ok(_fake.hold_on.is_empty(), "B was opened while Talk answered")
	_ok(_fake.asks.size() == 1 and str(ask.get("model", "")) == A_LINK, "the question went about A's link only")
	_ok(_store.share_id == B_LINK, "B keeps its own link (%s)" % _store.share_id)
	_ok(named == _store.title, "the panel shows B's name (\"%s\")" % named)
	_ok((_panel.get("_about") as TextEdit).text.is_empty() and (_panel.get("_tags") as LineEdit).text.is_empty(),
		"and none of A's words or tags")
	_ok(not (_panel.get("_ask_open") as Control).visible, "Open the thread is not shown for B")
	var ask_button: Button = _panel.get("_ask")
	_ok(not ask_button.disabled and ask_button.text == "Ask in Talk", "Ask in Talk can be pressed for B")
	if taken:
		_ok(str(_panel.get("ask_state")) == "asked", "the question is asked (%s)" % _panel.get("ask_state"))
		_ok(status.text.begins_with("The question about “pb wall” is in Talk's Help at ")
			and status.text.ends_with("/talk/t/1. Another model was opened meanwhile."),
			"the status says where A's question is: \"%s\"" % status.text.left(160))
		_in_languages(status.text, ["pb wall", status.text.get_slice(" at ", 1).get_slice(". ", 0)])
		await _picture("ask_moved")
	else:
		_ok(status.text == "The question about “pb wall” was not asked: Talk is down",
			"the status says so of A by name, with Talk's words: \"%s\"" % status.text.left(160))
		_in_languages(status.text, ["pb wall", "Talk is down"])
		await _picture("ask_fail")
		# Publish pressed next, on B: B as B, never under A's name or words.
		_fake.bodies.clear()
		await _panel.call("publish")
		var body: Dictionary = _fake.bodies[0] if not _fake.bodies.is_empty() else {}
		print("  Publish then sent %d: name \"%s\", words \"%s\", tags \"%s\", link %s"
			% [_fake.bodies.size(), str(body.get("name", "")), str(body.get("description", "")),
				str(body.get("tags", "")), str(body.get("id", "(none)"))])
		_ok(_fake.bodies.size() == 1 and str(body.get("id", "")) == B_LINK
			and str(body.get("model", "")).contains("pubbind other"), "Publish sends B under B's link")
		_ok(str(body.get("name", "")) in [_store.title, _store.title.get_basename()]
			and str(body.get("description", "")).is_empty()
			and str(body.get("tags", "")).is_empty(), "under B's name, with none of A's words or tags")
	_fake.ask_code = 201
	_panel.set("ask_state", "idle")


## Enter on A, B opened while the server answers [param during]: the
## publish ("publish") or the entry ("enter").
func _case_enter(during: String) -> void:
	print("\nenter_%s: Enter on A, B opened while the %s is answered" % ["server" if during == "publish" else "enter",
		"publish" if during == "publish" else "entry"])
	await _start_on_a()
	# Made a moment after the studio starts (Later.make): waited for.
	var line: Node = null
	for _n: int in 2000:
		line = _panel.get("challenge_line")
		if line != null:
			break
		await process_frame
	if not _ok(line != null, "the challenge line is made"):
		return
	line.set("challenge", ChallengeRules.rules_in({"code": 200, "body": {"challenge": {"id": 9,
		"title": "Probe Challenge", "page": "https://example.invalid/c/probe", "entering": true,
		"starts_on": "2026-11-01", "ends_on": "2026-12-31", "entries_until": "2026-12-31", "rules": {}}}}))
	_panel.set("entry", {})
	(_panel.get("_author") as LineEdit).text = "Probe Person"
	(_panel.get("_enter_row") as Control).visible = true
	(_panel.get("_enter") as Button).disabled = false
	var status: Label = _panel.get("_status")
	_fake.enters.clear()
	_fake.hold = func() -> void: await _open("b")
	_fake.hold_on = during
	await _panel.call("publish_and_enter")
	await _frames(5)
	var body: Dictionary = _fake.bodies[0] if not _fake.bodies.is_empty() else {}
	print("  sent %d publish(es) %s, entries %s; on the baseplate %s, its link %s; entry %s; status \"%s\""
		% [_fake.bodies.size(), str(body.get("id", "(none)")), str(_fake.enters), _store.title, _store.share_id,
			str(_panel.get("entry")), status.text.left(220)])
	_ok(_fake.hold_on.is_empty(), "B was opened while the %s was answered" % during)
	_ok(_fake.bodies.size() == 1 and str(body.get("id", "")) == A_LINK
		and str(body.get("model", "")).contains("pubbind wall"), "A is published under its own link")
	_ok(_store.share_id == B_LINK, "B keeps its own link (%s)" % _store.share_id)
	_ok((_panel.get("entry") as Dictionary).is_empty(), "B is not shown as entered (%s)" % str(_panel.get("entry")))
	_ok((_panel.get("_name") as LineEdit).text == _store.title,
		"the panel shows B's name (\"%s\")" % (_panel.get("_name") as LineEdit).text)
	_ok(str(_panel.get("entering")).is_empty(), "Enter is not left Entering…")
	if during == "publish":
		_ok(_fake.enters.is_empty(), "nothing is entered (%s)" % str(_fake.enters))
		_ok(status.text == "“pb wall” was published at example.invalid/m/%s but not entered: another model was opened."
			% ANSWER_LINK, "the status says A was published and not entered, by name: \"%s\"" % status.text.left(200))
		_in_languages(status.text, ["pb wall", "example.invalid/m/" + ANSWER_LINK])
	else:
		_ok(_fake.enters.size() == 1 and str(_fake.enters[0][0]) == ANSWER_LINK,
			"A's link as published is entered, once (%s)" % str(_fake.enters))
		_ok(status.text == "“pb wall” was entered in Probe Challenge, built by hand. It is on the challenge's page: "
			+ "example.invalid/c/probe. Another model was opened meanwhile.",
			"the status says A was entered, by name, with none of B's words: \"%s\"" % status.text.left(220))
		_in_languages(status.text, ["pb wall", "Probe Challenge", "example.invalid/c/probe"])
	await _picture("enter_" + during)
	line.set("challenge", {})
	_panel.set("entry", {})
	(_panel.get("_author") as LineEdit).text = ""


func _case_unpublish() -> void:
	print("\nunpublish: Take down on A, B opened while the server answers")
	await _start_on_a()
	_panel.set("state", "published")
	var status: Label = _panel.get("_status")
	_fake.hold = func() -> void: await _open("b")
	_fake.hold_on = "unpublish"
	await _panel.call("unpublish")
	_ok(_fake.downs == [A_LINK], "A's link was taken down (%s)" % str(_fake.downs))
	_ok(str(_panel.get("state")) != "unpublished", "B is not shown as taken down (%s)" % _panel.get("state"))
	_ok(_store.share_id == B_LINK, "B keeps its own link (%s)" % _store.share_id)
	_ok(status.text == "“pb wall” was taken down: its link now says it is no longer shared. Another model was opened meanwhile.",
		"the status says so of A by name: \"%s\"" % status.text.left(140))
	_in_languages(status.text, ["pb wall"])
	await _picture("unpublish")


func _case_clear() -> void:
	print("\nclear: Clear asked on A, B opened while the question is up")
	await _start_on_a()
	var bar: Node = _main.get("_bar")
	bar.call("_ask_to_clear")
	await _frames(3)
	await _open("b")
	var parts: int = _world.brick_count()
	await bar.call("_on_clear")
	await _frames(3)
	(bar.get("_confirm") as AcceptDialog).hide()
	_ok(_world.brick_count() == parts and parts > 0, "B is not emptied (%d parts, %d before)" % [_world.brick_count(), parts])
	_ok(_store.share_id == B_LINK, "B keeps its own link (%s)" % _store.share_id)
	_ok(str(bar.call("status_text")).contains("not cleared: another model was opened"),
		"the bar says so: \"%s\"" % str(bar.call("status_text")))


func _case_assistant() -> void:
	print("\nassistant: a design's reply arriving after its model was put away")
	var world := BrickWorld.new()
	world.library = _main.get("_library")
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = world.library
	root.add_child(builder)
	var assistant := Offline.new()
	assistant.library = world.library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	await process_frame
	var ended: Array = []
	assistant.finished.connect(func(ok: bool, summary: String) -> void: ended.append([ok, summary]))
	_ok(assistant.design("a red wall"), "a design starts")
	world.add_brick("3001", 15, Transform3D.IDENTITY)
	world.clear()
	await _reply(assistant, [_tool("submit_design", {"name": "Wall", "description": "a red wall",
		"bricks": _wall_bricks(), "features": []})])
	_ok(world.brick_count() == 0, "nothing was built on what is there now (%d parts)" % world.brick_count())
	_ok(not assistant.is_busy(), "the run ended")
	# Its words as written, so this runs on a tree before them too.
	_ok(not ended.is_empty() and not bool(ended[0][0])
		and str(ended[0][1]).begins_with("stopped: another model was opened"), "saying why: %s" % str(ended))
	ended.clear()
	assistant.forget_built()
	assistant.forget_conversation()
	_ok(assistant.design("a red wall"), "a design starts again, nothing cleared")
	await _reply(assistant, [_tool("submit_design", {"name": "Wall", "description": "a red wall",
		"bricks": _wall_bricks(), "features": []})])
	_ok(world.brick_count() > 0, "the reply builds (%d parts)" % world.brick_count())
	if assistant.is_busy():
		assistant._stop(true, "done")
	assistant.queue_free()
	builder.queue_free()
	world.queue_free()
	await _frames(3)


# -- helpers ----------------------------------------------------------------


## The window as it is now, as [param name].png in --pictures=DIR, in a run
## with a window; and the status line's words in German drawn the same.
func _picture(name: String) -> void:
	if _pictures.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(_pictures)
	for code: String in ["en", "de"]:
		Language.apply(code)
		await _frames(4)
		await RenderingServer.frame_post_draw
		var path: String = _pictures.path_join("%s_%s.png" % [name, code])
		root.get_texture().get_image().save_png(path)
		print("  picture: %s" % path)
	Language.apply("en")


## [param text] drawn in German, French and Spanish, with nothing left in
## English but [param names] (a model's, a link, a challenge's, a server's
## words); then English again.
func _in_languages(text: String, names: Array) -> void:
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		var drawn: String = Language.says(text)
		var stray: Array = Language.left_in_english(text).filter(func(words: Variant) -> bool:
			return not str(words).strip_edges().trim_suffix(".") in names)
		_ok(not drawn.is_empty() and drawn != text and stray.is_empty(), "in %s: \"%s\"%s" % [code, drawn.left(160),
			"" if stray.is_empty() else " (left in English: %s)" % str(stray)])
	Language.apply("en")


## Signed in, as the panel and Main hold the account, with a token good for
## an hour: afresh each case, for the account's own start, answered late
## with nothing kept on this device, signs it out partway through a run.
func _sign_in() -> void:
	for held: Variant in [_panel.get("account"), _main.get("_account")]:
		if held is Account:
			var account: Account = held
			account.state = Account.State.SIGNED_IN
			account.set("_access", "pb-token")
			account.set("_expires_at", Time.get_unix_time_from_system() + 3600.0)
			account.renewing = false


## A on the baseplate with its own link, the panel open on it, the server's
## record emptied.
func _start_on_a() -> void:
	_fake.hold = Callable()
	_fake.hold_on = ""
	_sign_in()
	await _open("a")
	_fake.bodies.clear()
	_fake.asks.clear()
	_fake.downs.clear()
	if not _panel.visible:
		_panel.call("open")
	else:
		_panel.call("_show_model")
	await _frames(5)
	_panel.set("state", "idle")
	(_panel.get("_name") as LineEdit).text = "pb wall"


## Open [param which] as File, Open does, and wait until it is whole.
func _open(which: String) -> void:
	var path: String = ProjectSettings.globalize_path(_paths[which])
	_main.call("_open", path)
	for _n: int in 3000:
		await process_frame
		if _store.awaited.is_empty() and not _store.laying and _world.brick_count() > 0:
			break
	await _frames(3)


func _until(done: Array) -> void:
	for _n: int in 200000:
		if done[0]:
			return
		await process_frame


func _reply(assistant: Assistant, content: Array) -> void:
	var body: String = JSON.stringify({"content": content, "stop_reason": "end_turn"})
	await assistant._on_response([HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), body.to_utf8_buffer()])


func _tool(name: String, input: Dictionary) -> Dictionary:
	return {"type": "tool_use", "id": "t%d" % randi(), "name": name, "input": input}


func _wall_bricks() -> Array:
	var out: Array = []
	for x: int in [0, 4, 8]:
		out.append({"part": "3001", "color": 4, "x": x, "y": 0, "z": 0, "rot": 0})
	return out


## A: 160 bricks in a wall of 8 by 20 courses, with its own link.
func _wall_text() -> String:
	var lines := PackedStringArray(["0 FILE pb_a.ldr", "0 pubbind wall", "0 Name: pb_a.ldr",
		"0 !BRICKWORKS SHARE " + A_LINK])
	for course: int in 20:
		for at: int in 8:
			lines.append("1 %d %d %d 0 1 0 0 0 1 0 0 0 1 3001.dat" % [4 if course % 2 == 0 else 1, at * 80 + (40 if course % 2 == 1 else 0), -24 * course])
	lines.append("0 NOFILE")
	return "\n".join(lines) + "\n"


func _write(name: String, text: String) -> String:
	var path: String = PROBE_DIR + name
	var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	out.store_string(text)
	out.close()
	return path


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
