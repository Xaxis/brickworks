## Does a person's own AI key reach anything but its provider?
##
##   tools/probe.sh key_leak_probe
##   godot --path . --resolution 1400x900 --script src/dev/key_leak_probe.gd
##   ... -- --plant     the key written into the model's name as well, which
##                      every place below that carries the name must then
##                      find: the search's red (exits 1, saying where)
##
## Made-up keys, never real ones: an Anthropic key in the assistant's column
## (OwnKey) and an OpenAI key in Settings, AI (ProviderSettings), both kept on
## this device (here the encrypted file: a probe reaches no keyring,
## tools/probe.sh), and a third for this visit only. Then the app does what it
## does with a model, and everything it wrote, would send or shows is searched
## for the keys as written, in hex and in base64 (a fingerprint, a few
## characters of each end, is what may be shown):
## - the files: the model saved and its autosave and versions, every export
##   (LDraw, BrickLink, Rebrickable, Studio, a picture, the booklet), and
##   every file in the app's data folder, its log among them;
## - what would be sent: a share's body (SharePanel.publish, answered here),
##   Send feedback's with every part ticked, the log's last lines among them,
##   and Build together's waiting changes (Together.check_alone);
## - the MCP, as the relay and the desktop's port carry it: initialize's
##   instructions, tools/list, and every read-only tool's answer;
## - the clipboard, after Copy link;
## - the screen: every word drawn in the window, tooltips and placeholders
##   too, with Settings, AI open on a key typed and shown, then kept.
## Then Forget leaves no copy, and This visit only writes nothing.
extends SceneTree

const SHARE_PROBE := preload("res://src/dev/share_view_probe.gd")

var _failures: int = 0
var _plant: bool = false
var _main: Node
var _socket: CommandSocket
var _store: ModelStore
var _next: int = 0
var _keys: PackedStringArray = []
## What would leave the app, by where: searched at the end.
var _sent: Dictionary = {}
var _out: String = ""


func _initialize() -> void:
	_plant = OS.get_cmdline_user_args().has("--plant")
	_run()


func _run() -> void:
	await process_frame
	var anthropic: String = _key("sk-ant-api03-")
	var openai: String = _key("sk-proj-")
	var visit: String = _key("sk-proj-")
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_shared", SHARE_PROBE.FakeShared.new())
	root.add_child(_main)
	await _frames(200)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_store = _main.get("_store")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_out = OS.get_user_data_dir().path_join("key_leak_probe")
	DirAccess.make_dir_recursive_absolute(_out)
	(_main.get("_exports") as Exports).folder = _out

	print("── keys given ──")
	_check("an Anthropic key kept for the assistant's column", OwnKey.remember(anthropic).is_empty())
	_check("an OpenAI key kept in Settings, AI",
		ProviderSettings.remember("openai", openai, true).is_empty())
	_check("another for this visit only",
		ProviderSettings.remember("custom", visit, false).is_empty())
	ProviderSettings.set_who(ProviderSettings.WHO_KEY)
	ProviderSettings.choose("openai", "gpt-6.1-sol")
	_check("each kept in its own encrypted file",
		FileAccess.get_file_as_bytes(OwnKey.WHERE).slice(0, 4).get_string_from_ascii()
			== KeyStore.ENCRYPTED and FileAccess.get_file_as_bytes(
			ProviderSettings.key_file("openai")).slice(0, 4).get_string_from_ascii()
			== KeyStore.ENCRYPTED)

	await _a_model()
	await _files()
	await _mcp()
	await _share()
	await _feedback()
	_together()
	await _screen()
	_search()
	_forget()
	_this_visit_only()

	print("")
	if _plant:
		print("planted: the search %s the key it was given" % ("FOUND" if _failures > 0 else "MISSED"))
	elif _failures == 0:
		print("the keys went nowhere: in no file, no answer, nothing sent and nothing shown")
	else:
		print("%d FAILURE(S)" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _key(prefix: String) -> String:
	var key: String = "%sLEAKCHECK%s" % [prefix, Crypto.new().generate_random_bytes(20).hex_encode()]
	_keys.append(key)
	return key


## The first example, opened as a person opens it, with a name of its own.
func _a_model() -> void:
	print("\n── a model ──")
	var examples: Array[ModelStore.Entry] = _store.list_examples()
	await _say("open_model", {"name": examples[0].name, "discard_changes": true})
	await _frames(30)
	_store.title = "Leak check" if not _plant else "Leak check %s" % _keys[0]
	var world: BrickWorld = _main.get("_world")
	_check("the example open, %d parts" % world.brick_count(), world.brick_count() > 5)


func _files() -> void:
	print("\n── saved and exported ──")
	_check("saved", _store.save_as(_store.title.validate_filename()))
	_store.write_now()
	for format: String in ["ldraw", "bricklink", "rebrickable", "studio", "picture", "instructions"]:
		var said: String = await _say("export_model", {"format": format})
		_check("exported %s: %s" % [format, said.left(90).replace("\n", " ")],
			said.begins_with("Wrote"))


## Everything the MCP says, as a session over the relay or the desktop's port
## hears it.
func _mcp() -> void:
	print("\n── the MCP ──")
	var answers: Array = []
	_next += 1
	answers.append(await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {},
		"clientInfo": {"name": "key_leak_probe", "version": "1"}}}))
	_next += 1
	var listed: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/list", "params": {}})
	answers.append(listed)
	var called: int = 0
	for name: String in CommandSocket.HINTS.keys():
		if not bool(CommandSocket.annotations(name).get("readOnlyHint", false)):
			continue
		_next += 1
		answers.append(await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
			"method": "tools/call", "params": {"name": name, "arguments": {}}}))
		called += 1
	_sent["the MCP's answers"] = JSON.stringify(answers)
	_check("initialize, tools/list and %d read-only tools answered" % called, called > 10)


func _share() -> void:
	print("\n── shared ──")
	var account: Account = _main.get("_account")
	await account.deployment.wait()
	account.email = "delivered+keyleak@resend.dev"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	var shell: Shell = _main.get("_shell")
	var panel: SharePanel = _main.get("_share_panel")
	shell.run("share")
	await _frames(30)
	await panel.publish()
	await _frames(10)
	var fake: Variant = _main.get("_shared")
	var bodies: Array = fake.published
	_sent["the share's body"] = JSON.stringify(bodies)
	_check("a share published, its body kept to search (%d bytes)"
		% str(_sent["the share's body"]).length(), not bodies.is_empty())
	var copy: Node = panel.controls_by_name().get("share_copy_link")
	if copy is Button:
		(copy as Button).pressed.emit()
	await _frames(3)
	_sent["the clipboard"] = DisplayServer.clipboard_get()
	_check("Copy link put the link on the clipboard: %s" % str(_sent["the clipboard"]).left(60),
		str(_sent["the clipboard"]).contains("/m/"))
	panel.hide()


func _feedback() -> void:
	print("\n── feedback ──")
	var shell: Shell = _main.get("_shell")
	shell.run("feedback")
	await _frames(12)
	var dialog: FeedbackDialog = shell.feedback
	if not _check("Send feedback… is up", dialog != null and dialog.visible):
		return
	dialog.send = func(_asked: Dictionary, _token: String) -> Dictionary: return {"code": 200}
	var controls: Dictionary = dialog.controls_by_name()
	for name: String in ["feedback_version", "feedback_model", "feedback_log"]:
		(controls[name] as CheckBox).button_pressed = true
	await _frames(3)
	var body: Dictionary = dialog.body()
	_sent["feedback's body"] = JSON.stringify(body)
	_check("feedback with the version, the model and the log's last lines",
		body.has("details") and body.has("model") and body.has("log"))
	dialog.hide()


func _together() -> void:
	print("\n── Build together ──")
	var together: Together = _main.get("_together")
	together.check_alone([])
	# Every part of the model, as a change sent to the others.
	together.call("_queue", together.call("_diff", null))
	_sent["Build together's changes"] = JSON.stringify([together.get("_pending"),
		together.call("_meta_now"), together.call("_pointer_now")])
	_check("Build together's changes and where it points, kept to search", true)


## Every word drawn: with the assistant's column up, and Settings, AI open on
## a key typed, shown with Show, then kept.
func _screen() -> void:
	print("\n── the screen ──")
	var shell: Shell = _main.get("_shell")
	shell.run("settings")
	await _frames(10)
	var controls: ControlsDialog = _main.get("_controls")
	controls.open_ai()
	await _frames(10)
	var ai: AiSettings = controls.ai
	ai.show_key.button_pressed = true
	ai.key_field.grab_focus()
	ai.key_field.text = _keys[1]
	ai.key_field.text_changed.emit(_keys[1])
	await _frames(3)
	var shown: String = _words(root)
	_check("typed and shown, the key is on the screen (the search can see the screen)",
		_found_in(shown.to_utf8_buffer()))
	ai.key_field.text_submitted.emit(ai.key_field.text)
	await _frames(5)
	_sent["the screen, the key kept"] = _words(root)
	_check("kept, it is cleared from the field and shown only as a fingerprint: \"%s\""
		% ai.key_field.placeholder_text, ai.key_field.text.is_empty()
		and ai.key_field.placeholder_text.contains(ProviderSettings.fingerprint(_keys[1])))
	controls.hide()
	await _frames(5)
	_sent["the screen"] = _words(root)


## The words of every control under [param at], hidden or not.
func _words(at: Node) -> String:
	var words := PackedStringArray()
	for node: Node in at.find_children("*", "Control", true, false):
		for property: String in ["text", "placeholder_text", "tooltip_text"]:
			var value: Variant = node.get(property)
			if value is String and not (value as String).is_empty():
				words.append(value)
	return "\n".join(words)


func _search() -> void:
	print("\n── searched ──")
	for where: String in _sent:
		var found: bool = _found_in(str(_sent[where]).to_utf8_buffer())
		_check("%s: no key%s" % [where, " — FOUND" if found else ""], not found)
	var looked: int = 0
	var found_in: PackedStringArray = []
	for path: String in _all_files("user://"):
		if FileAccess.get_size(path) > 40_000_000:
			continue
		looked += 1
		if _found_in(FileAccess.get_file_as_bytes(path)):
			found_in.append(path.trim_prefix("user://"))
	var logs: bool = not DirAccess.get_files_at("user://logs").is_empty()
	var exported: int = DirAccess.get_files_at(_out).size()
	_check("in none of the %d files the app wrote (its log and %d exports among them)%s"
		% [looked, exported, ": " + ", ".join(found_in) if not found_in.is_empty() else ""],
		found_in.is_empty() and logs and exported >= 5)


func _forget() -> void:
	print("\n── Forget ──")
	OwnKey.forget()
	ProviderSettings.forget("openai")
	ProviderSettings.forget("custom")
	KeyStore._held.clear()
	_check("no copy left: no file, nothing read back",
		not FileAccess.file_exists(OwnKey.WHERE)
		and not FileAccess.file_exists(ProviderSettings.key_file("openai"))
		and OwnKey.load_key().is_empty() and not OwnKey.has_key()
		and ProviderSettings.load_key("openai") == OS.get_environment("OPENAI_API_KEY")
		and ProviderSettings.load_key("custom").is_empty())


func _this_visit_only() -> void:
	print("\n── This visit only ──")
	var before: Dictionary = _snapshot()
	var anthropic: String = _key("sk-ant-api03-")
	var groq: String = _key("gsk_")
	_check("kept for the visit", OwnKey.remember(anthropic, false).is_empty()
		and ProviderSettings.remember("groq", groq, false).is_empty()
		and OwnKey.load_key() == anthropic and ProviderSettings.load_key("groq") == groq)
	var after: Dictionary = _snapshot()
	var changed := PackedStringArray()
	for path: String in after:
		if before.get(path, "") != after[path]:
			changed.append(path)
	for path: String in before:
		if not after.has(path):
			changed.append(path)
	_check("...and nothing written: no file made or changed%s"
		% (": " + ", ".join(changed) if not changed.is_empty() else ""), changed.is_empty())
	OwnKey.forget()
	ProviderSettings.forget("groq")


## Every file of the app's data and its digest, the log aside (it grows as
## the probe prints).
func _snapshot() -> Dictionary:
	var seen: Dictionary = {}
	for path: String in _all_files("user://"):
		if not path.begins_with("user://logs"):
			seen[path] = FileAccess.get_md5(path)
	return seen


func _found_in(bytes: PackedByteArray) -> bool:
	var text: String = bytes.get_string_from_ascii()
	for key: String in _keys:
		for form: String in [key, key.substr(13), key.to_utf8_buffer().hex_encode(),
				Marshalls.utf8_to_base64(key).trim_suffix("=").trim_suffix("=")]:
			if text.contains(form):
				return true
	return false


func _all_files(at: String) -> PackedStringArray:
	var all: PackedStringArray = []
	for name: String in DirAccess.get_files_at(at):
		all.append(at.path_join(name))
	for name: String in DirAccess.get_directories_at(at):
		all.append_array(_all_files(at.path_join(name)))
	return all


func _say(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var result: Dictionary = (answer as Dictionary).get("result", {})
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	var job: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(text)
	if job == null:
		return text
	for _n: int in 120:
		await _frames(10)
		var polled: String = await _say("job", {"id": int(job.get_string(1))})
		if not polled.contains(" is still going"):
			return polled.substr(polled.find("\n") + 1) if polled.contains("\n") else polled
	return "job never ended"


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	if ok:
		print("  ok    %s" % what)
		return true
	_failures += 1
	print("  FAIL  %s" % what)
	return false
