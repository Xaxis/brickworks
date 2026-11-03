## Connect your AI: one chooser for every assistant, each added in the fewest
## steps it allows, and the tab saying who works in it (U3,
## docs/ANY_ASSISTANT.md).
##
##   godot --path . --resolution 1400x900 --script src/dev/connect_any_probe.gd
##   ... -- --shots=DIR      the assistant's panel pictured at each step
##   PROBE_SIZE=1024x768 tools/probe.sh connect_any_probe -- --shots=DIR
##
## The owner (2026-11-02): connecting ChatGPT, Gemini or any provider should
## be as easy as Claude, and the workflows as alike as they can be. Here, in
## the real app's assistant panel, as a person goes:
## - the chooser lists every assistant of assets/assistants.json, in its
##   order, Claude first and chosen;
## - each one chosen and Connect pressed does its own way, read back from
##   what it handed the system (Outside, which a probe's run keeps) and the
##   clipboard: claude.ai's form, Cursor's and VS Code's install links, each
##   filled in; Claude Code's, Codex's and Gemini CLI's command copied; the
##   address copied and ChatGPT's, Gemini's, Le Chat's, Perplexity's and
##   Grok's own page opened; the address alone for another app; and its
##   steps and who may, from the table, shown beside;
## - New chat for this tab, for Claude (claude.ai's new chat), ChatGPT (its
##   page, the first message copied) and Codex (its command copied);
## - a call the relay names ChatGPT's (_meta brickworks/who) is ChatGPT's in
##   the panel's line, the tab's chats, the toolbar's line, the card in the
##   conversation and the history; a call that names no one stays Claude's;
## - Another AI chosen in Settings, AI leaves Connect your AI on screen: the
##   connector and a model on a key are two different things.
## Signed in with a session that needs no renewing, to a deployment on a
## port this probe holds and never answers: nothing leaves the machine.
extends SceneTree

const TABLE := "res://assets/assistants.json"

var _failures: int = 0
var _main: Node
var _shots: String = ""
var _size: String = ""
var _held := TCPServer.new()


func _initialize() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	if DisplayServer.get_name() == "headless":
		print("  no window — this probe needs one")
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	ShellPrefs.put("assistant", "on")
	ShellPrefs.put("assistant_offered", true)
	ShellPrefs.put("first_build", "skipped")
	await process_frame
	_size = "%dx%d" % [root.size.x, root.size.y]
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	var account: Account
	for _n: int in 900:
		await process_frame
		account = _main.get("_account")
		if account != null and account.state != Account.State.CHECKING \
				and _main.get("_chat") != null:
			break
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	(_main.get("_store") as ModelStore).keeps = false
	if _held.listen(0, "127.0.0.1") != OK:
		print("  could not hold a port")
		quit(1)
		return
	# Start-up's question to the deployment is asked three more times before
	# the account settles (Deployment.RETRY_AFTER), and settling signs out
	# whoever was signed in meanwhile, which stops the connector: signed in
	# by hand only after it.
	if account.deployment != null:
		await account.deployment.wait()
	await _frames(4)
	var connector: Node = _main.get("_connector")
	var deployment: String = "http://127.0.0.1:%d" % _held.get_local_port()
	connector.set("base_url", deployment)
	account.keeps = false
	account.email = "probe@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	var dock: SideDock = _main.get("_chat_dock")
	dock.set_open(true, false)
	await _frames(30)
	var chat: Node = _main.get("_chat")
	var form: Control = chat.get("_connector_form")
	if form == null:
		_check(false, "the assistant's panel has its Connect section")
		quit(1)
		return

	print("\nthe chooser")
	var table: Array = _table()
	var names := PackedStringArray()
	for one: Variant in table:
		names.append(str((one as Dictionary).get("name", "")))
	_check(names.size() >= 11 and names[0] == "Claude"
			and Array(names).has("ChatGPT") and Array(names).has("Gemini")
			and Array(names).has("Codex") and Array(names).has("Cursor"),
		"the table lists the assistants, Claude first: %s" % ", ".join(names))
	var chooser: OptionButton = form.get("_choice") as OptionButton
	var listed := PackedStringArray()
	if chooser != null:
		for n: int in chooser.item_count:
			if not chooser.is_item_separator(n):
				listed.append(chooser.get_item_text(n))
	_check(chooser != null and chooser.is_visible_in_tree() and listed == names
			and chooser.get_item_text(chooser.selected) == "Claude",
		"Connect your AI lists the table's assistants in its order, Claude chosen: %s"
			% ", ".join(listed))
	_check(_words(form).to_lower().contains("connect your ai"), "...under its title, Connect your AI")
	await _shot("1_chooser", form)
	if chooser != null:
		await _click(chooser)
		await _shot("2_chooser_open", chooser)
		chooser.get_popup().hide()
		await _frames(4)

	print("\neach one's own way, in the fewest steps it allows")
	var address: String = deployment + "/api/mcp"
	var expected: Dictionary = _ways(address)
	for one: Variant in table:
		var it: Dictionary = one
		var id: String = str(it.get("id", ""))
		if chooser == null or not expected.has(id):
			_check(expected.has(id), "%s is one this probe knows the way for" % id)
			continue
		_choose(chooser, str(it["name"]))
		await _frames(4)
		var button: Button = form.get("_connect") as Button
		DisplayServer.clipboard_set("")
		var before: int = Outside.opened.size()
		await _click(button)
		var want: Dictionary = expected[id]
		var opened: String = Outside.opened.back() if Outside.opened.size() > before else ""
		var copied: String = DisplayServer.clipboard_get()
		_check(opened == str(want["opened"]) and copied == str(want["copied"]),
			"%s: \"%s\" opens %s, copies %s" % [it["name"], button.text,
				opened if not opened.is_empty() else "nothing", copied])
		var said: String = _words(form)
		var missing := PackedStringArray()
		for step: Variant in it.get("steps", []):
			if not said.contains(str(step)):
				missing.append(str(step))
		if not str(it.get("plan", "")).is_empty() and not said.contains(str(it["plan"])):
			missing.append(str(it["plan"]))
		_check(missing.is_empty() and bool(connector.call("is_on")),
			"...its steps and who may beside it, and this tab listening%s"
				% ("" if missing.is_empty() else "; missing: " + " | ".join(missing)))
		if id in ["chatgpt", "codex", "cursor"]:
			await _shot("3_%s" % id, form)

	print("\nnew chat for this tab")
	var tab_view: Control = form.get("_tab_view") as Control
	var start: Button = tab_view.get("_start") as Button if tab_view != null else null
	var first: String = str(connector.call("first_message"))
	for case: Array in [["Claude", "https://claude.ai/new?q=" + first.uri_encode(), first],
			["ChatGPT", "https://chatgpt.com/", first],
			["Codex", "", "codex \"%s\"" % first]]:
		_choose(chooser, case[0])
		await _frames(4)
		DisplayServer.clipboard_set("")
		var before: int = Outside.opened.size()
		if start != null and start.is_visible_in_tree():
			await _click(start)
		var opened: String = Outside.opened.back() if Outside.opened.size() > before else ""
		_check(start != null and opened == case[1] and DisplayServer.clipboard_get() == case[2],
			"%s: New chat for this tab opens %s and copies %s" % [case[0],
				opened if not opened.is_empty() else "nothing", DisplayServer.clipboard_get()])

	print("\nthe caller, named")
	_choose(chooser, "Claude")
	var builder: Builder = _main.get("_builder")
	var reply: HTTPRequest = connector.get("_reply") as HTTPRequest
	if reply != null:
		# The answer goes to the held port, which never answers: given up on
		# soon, as the relay would have had it.
		reply.timeout = 1.0
	var since: String = Time.get_datetime_string_from_system(true) + "Z"
	await connector.call("_answer", "", _call(1, _tower(3, 0), {"brickworks/who": "ChatGPT",
		"brickworks/chat": {"chat": "gpt-1", "since": since}}))
	await _frames(6)
	var tab: String = str(connector.call("tab"))
	var badge: Array = ClaudeTabView.badge(connector)
	var status: String = str(chat.call("connector_status"))
	var tab_words: String = str(tab_view.call("words")) if tab_view != null else ""
	var card: String = (chat.get("_run_title") as Label).text if chat.get("_run_title") != null else ""
	var history: PackedStringArray = builder.history_words(1)
	_check(status.begins_with("ChatGPT is building — 1 call"), "the panel's line: %s" % status)
	_check(tab_words.contains("A ChatGPT chat is working here"), "the tab's chats: %s"
		% tab_words.replace("\n", " / "))
	_check(str(badge[0]) == "ChatGPT working · tab %s" % tab, "the toolbar's line: %s" % badge[0])
	_check(card == "ChatGPT is building", "the card in the conversation: %s" % card)
	_check(not history.is_empty() and history[0].begins_with("ChatGPT's submit design"),
		"the history: %s" % str(history))
	await _shot("4_chatgpt_working", form)
	await connector.call("_answer", "", _call(2, _tower(3, 40), {"brickworks/chat":
		{"chat": "c-2", "since": since}}))
	await _frames(6)
	history = builder.history_words(1)
	tab_words = str(tab_view.call("words")) if tab_view != null else ""
	badge = ClaudeTabView.badge(connector)
	_check(not history.is_empty() and history[0].begins_with("Claude's submit design")
			and tab_words.contains("ChatGPT, since") and tab_words.contains("Claude, since"),
		"a call that names no one stays Claude's, each chat named: %s; %s"
			% [str(history), tab_words.replace("\n", " / ")])
	_check(str(badge[0]) == "2 chats · tab %s" % tab, "...and the toolbar counts both: %s" % badge[0])

	print("\nAnother AI, on a key, leaves Connect your AI on screen")
	var controls: Node = _main.get("_controls")
	(_main.get("_shell") as Shell).run("settings")
	await _frames(10)
	(controls.get("ai_open") as BaseButton).pressed.emit()
	await _frames(10)
	var ai: Node = controls.get("ai")
	(ai.get("who_key") as CheckBox).button_pressed = true
	await _frames(10)
	_check(ProviderSettings.who() == ProviderSettings.WHO_KEY and form.is_visible_in_tree()
			and (form.get("_connect") as Button).is_visible_in_tree(),
		"Another AI chosen: Connect your AI still shown (%s)" % form.is_visible_in_tree())
	await _shot("5_another_ai", form)
	(ai.get("who_claude") as CheckBox).button_pressed = true
	await _frames(4)
	controls.set("visible", false)

	connector.call("stop")
	_held.stop()
	print("\n%s" % ("connect your AI: every assistant its own way, the caller named"
		if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## The table, as the app is given it.
func _table() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	return (parsed as Dictionary).get("assistants", []) if parsed is Dictionary else []


## What each one's Connect hands the system and puts on the clipboard, said
## here as each maker documents it (docs/ANY_ASSISTANT.md B.1), not read
## from the table: the table is what is under test.
func _ways(address: String) -> Dictionary:
	var cursor: String = Marshalls.utf8_to_base64(JSON.stringify({"url": address}))
	var vscode: String = JSON.stringify({"name": "brickworks", "type": "http", "url": address})
	return {
		"claude": {"opened": "https://claude.ai/customize/connectors?modal=add-custom-connector"
			+ "&connectorName=Brickworks&connectorUrl=" + address.uri_encode(), "copied": address},
		"chatgpt": {"opened": "https://chatgpt.com/plugins", "copied": address},
		"gemini": {"opened": "https://gemini.google.com/app", "copied": address},
		"le_chat": {"opened": "https://chat.mistral.ai/", "copied": address},
		"perplexity": {"opened": "https://www.perplexity.ai/computer/plugins", "copied": address},
		"grok": {"opened": "https://grok.com/connectors", "copied": address},
		"claude_code": {"opened": "", "copied": "claude mcp add --transport http brickworks " + address},
		"codex": {"opened": "", "copied": "codex mcp add brickworks --url %s && codex mcp login brickworks"
			% address},
		"gemini_cli": {"opened": "", "copied": "gemini mcp add --transport http brickworks " + address},
		"cursor": {"opened": "cursor://anysphere.cursor-deeplink/mcp/install?name=brickworks&config="
			+ cursor.uri_encode(), "copied": address},
		"vscode": {"opened": "vscode:mcp/install?" + vscode.uri_encode(), "copied": address},
		"other": {"opened": "", "copied": address},
	}


## [param named] chosen, as the chooser's list sends a choice.
func _choose(chooser: OptionButton, named: String) -> void:
	if chooser == null:
		return
	for n: int in chooser.item_count:
		if not chooser.is_item_separator(n) and chooser.get_item_text(n) == named:
			chooser.select(n)
			chooser.item_selected.emit(n)
			return


## A tool call as the relay hands it to the tab.
func _call(id: int, arguments: Dictionary, meta: Dictionary) -> Dictionary:
	return {"id": id, "request": {"jsonrpc": "2.0", "id": 100 + id, "method": "tools/call",
		"params": {"name": "submit_design", "arguments": arguments, "_meta": meta}}}


func _tower(height: int, x: int) -> Dictionary:
	var bricks: Array = []
	for n: int in height:
		bricks.append({"part": "3003", "color": 4, "x": x, "y": 3 * n, "z": 10, "rot": 0})
	return {"name": "A red tower", "description": "a red tower", "floor": "none", "bricks": bricks}


## Every word [param under] shows, a line each.
func _words(under: Node) -> String:
	var said := PackedStringArray()
	for node: Node in under.find_children("*", "", true, false):
		if node is Label and (node as Label).is_visible_in_tree():
			said.append((node as Label).text)
		elif node is Button and (node as Button).is_visible_in_tree():
			said.append((node as Button).text)
		elif node is LineEdit and (node as LineEdit).is_visible_in_tree():
			said.append((node as LineEdit).text)
	return "\n".join(said)


## A click on [param control] where it is drawn, as the mouse sends one,
## scrolled into view first.
func _click(control: Control) -> void:
	if control == null:
		return
	_into_view(control)
	await _frames(4)
	var at: Vector2 = control.get_global_rect().get_center() \
		* (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size)
	if OS.get_environment("XAUTHORITY").contains("xvfb-run"):
		Input.warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await _frames(3)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.pressed = pressed
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
		await _frames(2)
	await _frames(4)


func _into_view(control: Control) -> void:
	var up: Node = control.get_parent()
	while up != null and not up is ScrollContainer:
		up = up.get_parent()
	if up != null:
		(up as ScrollContainer).ensure_control_visible(control)


func _shot(named: String, near: Control) -> void:
	if _shots.is_empty():
		return
	if near != null:
		_into_view(near)
	await _frames(6)
	await RenderingServer.frame_post_draw
	var path: String = _shots.path_join("%s_%s.png" % [named, _size])
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
