## Does a running design look like one?
##
##   godot --headless --path . --script src/dev/chat_probe.gd
##
## A design takes minutes, and for the first minute or two nothing is on
## the baseplate. The panel used to show that as one line of small grey
## text, each step replacing the last — and watched in a browser, a real
## design on the live site read as a page that had done nothing. It was
## reported as "the assistant doesn't work at all", and it was working.
##
## So a run gets a card: what it is doing now, what it has done, how
## long it has been going, what to expect, and a way to stop it. Driven
## here through the real panel and the real loop, with the request taken
## out.
##
## And before any of that, the panel itself. There are no accounts, so
## with no key it is the key form, straight away, and nothing offers to
## sign in; with one it is the composer, with Change key at its foot.
## The key is made up and kept for this run only, so the one this
## machine may hold is never read, sent or forgotten.
extends SceneTree


class Offline extends Assistant:
	var sent: int = 0

	func _send() -> void:
		sent += 1


var _failures: int = 0

## Made up, and the right shape to pass for a key.
const PROBE_KEY := "sk-ant-api03-probe-not-a-real-key-and-never-sent-anywhere"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var assistant := Offline.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	var kept: String = OwnKey._this_visit
	OwnKey._this_visit = PROBE_KEY
	var panel := ChatPanel.new()
	get_root().add_child(panel)
	await process_frame
	panel.bind(assistant)

	print("the panel, with and without a key")
	_check(panel._composer.visible and not panel._key_form.visible,
		"with a key, it opens on the composer")
	_check(panel._out.text == "Change key" and panel._out.is_visible_in_tree(),
		"...with Change key at its foot")
	panel._show_for_key(false)
	_check(panel._key_form.visible and not panel._composer.visible,
		"with none, the key form is shown straight away")
	var offers: PackedStringArray = _saying(panel, "sign in")
	_check(offers.is_empty(), "...and nothing on the panel offers to sign in%s"
		% ("" if offers.is_empty() else ": " + ", ".join(offers)))
	# Pressed only where it cannot cost anything. Change key forgets the
	# key on this device, and on a machine that keeps one that would be
	# somebody's real key gone.
	if FileAccess.file_exists(OwnKey.WHERE):
		print("  ----  Change key not pressed: this machine keeps a key, "
			+ "and pressing it would forget that one")
	else:
		panel._show_for_key(true)
		panel._out.pressed.emit()
		_check(not OwnKey.has_key() and panel._key_form.visible
				and not panel._composer.visible,
			"Change key forgets the key and shows the form")
		OwnKey._this_visit = PROBE_KEY
	panel._show_for_key(OwnKey.has_key())

	# The desktop's other way in. Built as the app builds it where Claude
	# Code is installed; nothing is started, since nothing is sent.
	var local := ChatPanel.new()
	local.claude_code_here = true
	get_root().add_child(local)
	await process_frame
	local.bind(assistant)
	local._show_for_key(false)
	_check(local._composer.visible and local._key_form.visible
			and local._use_claude_code != null
			and local._use_claude_code.is_visible_in_tree(),
		"with Claude Code here and no key, My Claude is still offered")
	_check(local._send.disabled and not local._out.is_visible_in_tree(),
		"...with nothing to build on until it is ticked, and no Change key")
	local._use_claude_code.button_pressed = true
	_check(not local._send.disabled, "...and ticking it is enough to build")
	local.queue_free()

	print("")

	var asked: Array = []
	panel.designing.connect(func(brief: String) -> void: asked.append(brief))

	print("a design is started")
	panel._input.text = "a small red house"
	panel._on_send()
	await process_frame
	_check(asked == ["a small red house"],
		"whatever owns the baseplate hears a design is starting, first")
	_check(panel._run != null and panel._run_title.text == "Designing",
		"a card says it is designing")
	_check(not panel._run_now.text.is_empty(),
		"...and what it is doing: %s" % panel._run_now.text)
	_check(panel._run_hint.text.contains("Nothing is built until"),
		"...and what to expect, since nothing is built for a while")
	_check(panel._run_stop.visible, "...and there is a way to stop it")

	print("\nit works through steps")
	assistant.progress.emit("looking up how to do window in a wall")
	_check(panel._run_now.text == "Looking up how to do window in a wall",
		"the newest step is the one written large: %s" % panel._run_now.text)
	assistant.progress.emit("checked 120 bricks")
	var past: int = panel._run_past.get_child_count()
	_check(past >= 1 and (panel._run_past.get_child(past - 1) as Label).text
			== "· Looking up how to do window in a wall",
		"the step before it is kept beneath, done")
	for n: int in 10:
		assistant.progress.emit("step %d" % n)
	_check(panel._run_past.get_child_count() == ChatPanel.RUN_STEPS,
		"only the last %d are kept" % ChatPanel.RUN_STEPS)
	panel._run_started -= 75_000
	panel._process(0.0)
	_check(panel._run_clock.text == "1:15",
		"the clock says how long it has been going: %s" % panel._run_clock.text)
	assistant.said.emit("I'll build a small red-brick house.")
	await process_frame
	_check(panel._log.get_child(panel._log.get_child_count() - 1) == panel._run,
		"what the assistant says goes above the card, which stays last")

	print("\nit finishes")
	var card: PanelContainer = panel._run
	var title: Label = panel._run_title
	assistant._stop(true, "built 120 bricks")
	await process_frame
	_check(title.text == "Done" and panel._run == null,
		"the card says it is done: %s" % title.text)
	_check(not panel._run_stop_was(card),
		"...and the stop button goes")
	# And what can be done with it now, one press away.
	var asked_for: Array = []
	panel.steps_wanted.connect(func() -> void: asked_for.append("steps"))
	panel.parts_list_wanted.connect(func() -> void: asked_for.append("parts"))
	for button: Button in card.find_children("*", "Button", true, false):
		if button.visible and button.text in ["Build steps", "Parts list"]:
			button.pressed.emit()
	_check(asked_for == ["steps", "parts"],
		"it offers the build steps and the parts list: %s" % str(asked_for))

	print("\na change to it is not a new design")
	asked.clear()
	panel._input.text = "make the roof blue"
	panel._on_send()
	await process_frame
	_check(asked.is_empty(), "nothing is told a design is starting")
	_check(panel._run != null and panel._run_title.text == "Changing it",
		"the card says it is changing it")

	print("\nit is stopped")
	title = panel._run_title
	panel._run_stop.pressed.emit()
	await process_frame
	_check(title.text == "Stopped" and panel._run == null,
		"stopping it says so: %s" % title.text)
	_check(not panel._working and panel._send.text == "Build it",
		"...and the button is back")

	print("\nit fails")
	panel._input.text = "make it taller"
	panel._on_send()
	await process_frame
	title = panel._run_title
	var now: Label = panel._run_now
	assistant._stop(false, "Anthropic is overloaded. Try again shortly.")
	await process_frame
	_check(title.text == "Did not finish"
			and now.text == "Anthropic is overloaded. Try again shortly",
		"the card says why, in the size the run was told in: %s" % now.text)
	# Plain words first: Anthropic's own message used to replace them, so
	# a mistyped key read "invalid x-api-key" and nothing else.
	_check(Assistant._what_went_wrong(401).begins_with(Assistant.KEY_REFUSED),
		"a refused key is said plainly, so the panel can ask for another")

	print("\nthe key form")
	# Only the paths that write nothing: remembering a key, or keeping it
	# for this visit, would touch whatever key this machine has stored.
	_check(OwnKey.problem_with("sk-ant-oat01-" + "x".repeat(60)).contains(
			"subscription"),
		"a subscription's sign-in token is refused, and says why")
	_check(OwnKey.problem_with("not a key").contains("starts with"),
		"something that is not a key is refused before anything is asked")
	var form := KeyForm.new()
	get_root().add_child(form)
	form.setup()
	form.check_key = func(_key: String, done: Callable) -> void:
		done.call(401)
	var got: Array = []
	form.accepted.connect(func() -> void: got.append(true))
	form._field.text = "sk-ant-api03-" + "y".repeat(60)
	form._keep()
	await process_frame
	_check(got.is_empty() and form._note.visible
			and form._note.text.begins_with("Anthropic refused that key"),
		"a key Anthropic refuses is not taken, and the form says so")
	_check(form._field.text.length() > 0,
		"...and stays in the box to be corrected")

	print("\nyour Claude plan, through a connector")
	# A file of its own, so the address this machine keeps is never read or
	# changed. Pointed at a port nothing listens on: this checks the panel,
	# not the relay (connector_probe does that), and stays off the network.
	ClaudeConnector.where = "user://probe_claude_connector.json"
	if FileAccess.file_exists(ClaudeConnector.where):
		DirAccess.remove_absolute(ClaudeConnector.where)
	var answering := CommandSocket.new()
	answering.assistant = assistant
	get_root().add_child(answering)
	var connector := ClaudeConnector.new()
	get_root().add_child(connector)
	connector.base_url = "http://127.0.0.1:9"
	connector.rpc = answering
	var offer := ConnectorForm.new()
	get_root().add_child(offer)
	offer.setup(connector)
	_check(not offer._turn_on.button_pressed and offer._intro.visible
			and not offer._on_box.visible,
		"it starts off, saying what it is for")
	offer._turn_on.button_pressed = true
	_check(offer._address.text.begins_with("http://127.0.0.1:9/api/mcp?t=")
			and offer._address.text.length() > 60,
		"switching it on shows this tab's private address")
	_check(offer._status.text.begins_with("On. Waiting for Claude")
			and offer._on_box.visible and offer._in_view.visible,
		"...says it is waiting for Claude, with the steps, and to keep the tab in view")
	var first: String = offer._address.text
	offer._turn_on.button_pressed = false
	await process_frame
	_check(offer._address.text == first and offer._status.text.begins_with("Off"),
		"switching it off keeps the address, and says Claude cannot reach the tab")
	var next_visit := ClaudeConnector.new()
	get_root().add_child(next_visit)
	_check(next_visit.address().get_slice("?t=", 1) == first.get_slice("?t=", 1),
		"the next visit has the same address, so the connector added to Claude still works")
	next_visit.queue_free()
	offer._new_address.pressed.emit()
	offer._turn_on.button_pressed = true
	_check(not offer._address.text.is_empty() and offer._address.text != first,
		"Make a new address forgets the old one; the next is new")

	print("\nClaude connects, and builds")
	panel.use_connector(connector)
	panel._show_for_key(false)
	_check(panel._connector_form.visible and panel._scroll.visible,
		"with no key and the connector on, the panel has room for Claude's work")
	connector._used = true
	connector.called.emit("", {})
	_check(offer._status.text.begins_with("Connected — Claude reached this tab")
			and not offer._on_box.visible and offer._steps_toggle.visible,
		"Claude reaching the tab says Connected, and folds the steps away: %s"
			% offer._status.text)
	connector.called.emit("search_parts", {"query": "brick 2 x 4"})
	_check(panel._claude_card() and panel._run_title.text == "Claude is building"
			and panel._run_now.text.contains("brick 2 x 4"),
		"Claude's first call opens a card in the conversation: %s" % panel._run_now.text)
	connector.answered.emit("search_parts", true, "3001: Brick 2 x 4, covers 4x2 studs")
	_check(panel._run_now.text.contains("3001"),
		"...and the step says what came of it: %s" % panel._run_now.text)
	for n: int in 8:
		connector.called.emit("check_design", {"bricks": [1, 2, 3]})
		connector.answered.emit("check_design", n != 3, "fine" if n != 3 else "brick 2 floats")
	connector.called.emit("submit_design", {"name": "a red house", "bricks": [1, 2]})
	connector.answered.emit("submit_design", true, "Placed 2 bricks.")
	_check(panel._run_past.get_child_count() >= 9,
		"every step is kept, to scroll back through: %d" % panel._run_past.get_child_count())
	var refused: bool = false
	for line: Node in panel._run_past.get_children():
		refused = refused or (line as Label).text.contains("refused: brick 2 floats")
	_check(refused, "...a refused call says so, and why")
	panel.claude_quiet_ms = 0
	await process_frame
	await process_frame
	_check(not panel._claude_card() and panel._run_title.text == "Done",
		"when Claude goes quiet the card says Done")
	var offered := PackedStringArray()
	for button: Button in panel._log.find_children("*", "Button", true, false):
		if button.visible:
			offered.append(button.text)
	_check("Build steps" in offered and "Parts list" in offered,
		"...and offers the build steps and parts list: %s" % ", ".join(offered))
	panel.claude_quiet_ms = 90000
	connector.called.emit("view_model", {"from": "front"})
	offer._turn_on.button_pressed = false
	_check(not panel._claude_card() and panel._run_title.text == "Connector off",
		"switching it off mid-build says so on the card")
	connector.forget()
	ClaudeConnector.where = "user://claude_connector.json"

	OwnKey._this_visit = kept
	print("")
	if _failures == 0:
		print("a running design looks like one")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)


## Every piece of text on the panel that says [param words], shown or not.
static func _saying(panel: Node, words: String) -> PackedStringArray:
	var found := PackedStringArray()
	for each: Node in panel.find_children("*", "", true, false):
		if each is Label or each is Button or each is LinkButton:
			var text: String = str(each.get("text"))
			if text.to_lower().contains(words):
				found.append(text)
	return found


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)
