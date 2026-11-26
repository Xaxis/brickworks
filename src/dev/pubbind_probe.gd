## pubbind: an act pressed on one model is that model's from the press to the
## server's answer. Another model opened while it works is never sent in its
## place, never given what the server answered, and the share panel shows the
## model on the baseplate (SharePanel._show_model, _follow_model).
##
## Every case runs the app (src/main.tscn) with the server stubbed, so nothing
## leaves the box:
##   steps      Publish on A (160 parts, its own link), B (its own link) opened
##              while the steps are worked out and tested: nothing is sent, B
##              keeps its link, "Not published: another model was opened."
##   server     the same, B opened while the server answers: A is sent under
##              its own link, B is given nothing, the status says so with the
##              link; and again with a B that has no link
##   author     B opened while the profile's name is asked for (after the
##              steps, before the send): nothing is sent
##   normal     no open: A is sent under its own link and is given the answer's
##   follows    A's words typed in the panel, C opened: the panel shows C's name
##              and no words of A's, and Publish sends C under C's name
##   ask        Ask in Talk on A, which publishes first; B opened while the
##              server answers: nothing is asked
##   unpublish  Take down on A, B opened while the server answers: A's link is
##              taken down, B's state and link are untouched
##   clear      Clear asked on A, B opened while the question is up: B is not
##              emptied
##   assistant  a design run's reply arriving after its world was cleared (as an
##              open clears it): nothing is built, the run ends saying so; and
##              the same reply with no clear builds
##
##   godot --headless --path . --script src/dev/pubbind_probe.gd -- [--cases=a,b]
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
		return {"code": 201, "body": {"thread": {"id": 1}, "path": "/talk/t/1"}}

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
		"unpublish", "clear", "assistant"])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cases="):
			cases = arg.trim_prefix("--cases=").split(",", false)
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
	_panel.set("shared", _fake)
	var account: Account = _panel.get("account")
	account.state = Account.State.SIGNED_IN
	account.set("_access", "pb-token")
	account.set("_expires_at", Time.get_unix_time_from_system() + 3600.0)
	account.renewing = false
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
	_ok(status.text.begins_with("Not published: another model was opened."),
		"the status says so: \"%s\"" % status.text.left(120))
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
	_ok(status.text.begins_with("Not published: another model was opened."), "the status says so: \"%s\""
		% status.text.left(120))
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
	_ok(status.text == "Not asked: another model was opened.", "the status says so: \"%s\"" % status.text.left(120))
	_ok(_store.share_id == B_LINK, "B keeps its own link (%s)" % _store.share_id)


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
	_ok(status.text.ends_with("Another model was opened meanwhile."), "the status says so: \"%s\"" % status.text.left(140))


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


## A on the baseplate with its own link, the panel open on it, the server's
## record emptied.
func _start_on_a() -> void:
	_fake.hold = Callable()
	_fake.hold_on = ""
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
