## Does a model on another provider design here, end to end, on a key of the person's?
##
##   godot --path . --resolution 1400x900 --script src/dev/provider_loop_probe.gd
##
## DesignerLoop (src/ai/designer_loop.gd) is the app's own client of its MCP
## tools for any provider's model; OpenAIChat speaks Chat Completions to it.
## Here the provider is tools/provider_stub.py on 127.0.0.1:9621, an
## OpenAI-compatible model that scripts what a real one does, and is as strict
## as OpenAI about what it is sent: two calls in one reply (clear the
## baseplate, look a part up), a tower submitted, looked at, saved, the fresh
## look the save asks for answered from its three pictures, saved again, and a
## last word. Its first answer is a rate limit, asked again.
##
## Then what the person is promised: the model is built, the fresh look is
## answered and the design saved; every request carried the app's own
## instructions and its whole tool list, the key reached the provider and
## nothing of it is printed, and the pictures reached the model (Chat
## Completions takes none in a tool's answer, so they follow in a user
## message). And the adapter and the key's keeping, read without a network:
## a refused key is said so and not asked again, arguments that are not JSON
## go back to the model to say again, a Claude plan's token is refused. And a
## design stopped while its request is in the air ends once, and the next
## design is not answered by the stopped one's reply.
## In a window, for the pictures. The stubs' ports are 9621 and the next,
## or -- --port=N and the next.
extends SceneTree

var _stub_port: int = _port()
## A second stub that thinks for SLOW_S seconds before every answer.
var _slow_port: int = _stub_port + 1
const SLOW_S := 4.0
const BRIEF := "A slender red tower, six bricks tall"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _assistant: Assistant
var _stub: int = -1
var _slow: int = -1
var _log: String = ""


func _initialize() -> void:
	_run()


static func _port() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			return int(argument.trim_prefix("--port="))
	return 9621


func _run() -> void:
	await process_frame
	_adapter()
	_keys()
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_assistant = _main.get("_assistant")
	(_main.get("_store") as ModelStore).keeps = false
	await _end_to_end()
	await _stopped_then_again()
	for pid: int in [_stub, _slow]:
		if pid > 0:
			OS.kill(pid)

	print("")
	print("provider loop: a model on an OpenAI-compatible provider designed, answered the "
		+ "fresh look and saved, on the person's key" if _failures == 0
		else "provider loop: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## The whole design through the stub.
func _end_to_end() -> void:
	print("\n── a design by a model on an OpenAI-compatible provider ──")
	_log = ProjectSettings.globalize_path("user://provider-stub.jsonl")
	DirAccess.remove_absolute(_log)
	# Not a key of anybody's: made here, so the stub can say it came.
	var key: String = "sk-stub-" + Crypto.new().generate_random_bytes(16).hex_encode()
	OS.set_environment("STUB_KEY", key)
	_stub = OS.create_process("python3", ["-I",
		ProjectSettings.globalize_path("res://tools/provider_stub.py"), "--port", str(_stub_port),
		"--log", _log, "--fail-first", "1"])
	OS.unset_environment("STUB_KEY")
	_check("the stub provider starts (pid %d)" % _stub, _stub > 0)
	var until: int = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until:
		await process_frame

	var provider: Provider = ProviderSettings.provider_for("openai", "gpt-6.1-sol", key,
		"http://127.0.0.1:%d/v1" % _stub_port)
	var started: bool = _main.call("design_with_provider", BRIEF, provider)
	_check("the design starts", started)
	var loop: DesignerLoop = _main.call("designer")
	var lines: Array[String] = []
	loop.progress.connect(func(note: String) -> void: lines.append(note))
	var outcome: Array = []
	loop.finished.connect(func(ok: bool, summary: String) -> void: outcome.append_array([ok, summary]))
	until = Time.get_ticks_msec() + 240000
	while outcome.is_empty() and Time.get_ticks_msec() < until:
		await process_frame
	print("  the loop said: %s" % " | ".join(lines))
	_check("it finishes well, on the model's own last word: %s" % str(outcome),
		outcome.size() == 2 and bool(outcome[0])
		and str(outcome[1]).begins_with("I built a red tower"))
	_check("the tower stands: %d parts" % _parts(), _parts() == 6)
	var eyes: Dictionary = _assistant.call("fresh_eyes").get("last")
	_check("the fresh look was asked and answered in the judge's shape: %s"
		% str(eyes.get("changes", [])), (eyes.get("changes", []) as Array).size() == 3
		and str(eyes.get("reads_as", "")) == "a red column of six bricks"
		and int(eyes.get("refused", -1)) == 0)
	_check("the design is saved with the app's models",
		FileAccess.file_exists(ModelStore.SAVE_DIR + "stub-tower.ldr"))
	_check("%d replies and %d calls, each answered" % [loop.replies(), loop.calls()],
		loop.replies() == 7 and loop.calls() == 7)
	var spend: Brain.Spend = loop.spent()
	_check("what it spent is counted from the provider's own figures: %d in, %d cached, %d out"
		% [spend.fresh, spend.cached, spend.made], spend.made == 7 * 40 and spend.cached == 7000)

	var asked: Array = _requests()
	var served: int = (_main.get("_connector").get("rpc") as CommandSocket).served_tools().size() \
		if _main.get("_connector") != null else 0
	var statuses: Array = []
	var refused: Array = []
	var whole: bool = served > 50
	for one: Dictionary in asked:
		statuses.append(int(one["status"]))
		refused.append_array(one["problems"])
		whole = whole and bool(one["key_is_stub"]) and bool(one["system_has_guide"]) \
			and int(one["tools"]) == served and str(one["model"]) == "gpt-6.1-sol"
	_check("8 requests: the rate limit, then 7 answered: %s" % str(statuses),
		statuses == [429, 200, 200, 200, 200, 200, 200, 200])
	_check("nothing in them the provider would refuse: %s" % str(refused), refused.is_empty())
	_check("each carried the key, the app's instructions and its whole tool list (%d)" % served,
		whole)
	var names: Array = asked[1]["tool_names"] if asked.size() > 1 else []
	_check("...the tool list as the app serves it, fresh_eyes and job in it",
		names.has("fresh_eyes") and names.has("job") and names.has("submit_design"))
	var same: String = _as_relay((_main.get("_connector").get("rpc") as CommandSocket).served_tools()) \
		if _main.get("_connector") != null else "no connector to ask"
	_check("...portable as ChatGPT's is: %s" % same, same.begins_with("the same"))
	var looked: Dictionary = _after(asked, 3)
	_check("view_model's picture reached the model, after its tool message: %d"
		% int(looked.get("pictures_after_tools", 0)), int(looked.get("pictures_after_tools", 0)) >= 1)
	var saved: Dictionary = _after(asked, 4)
	_check("the first save's fresh look, three pictures and the question, reached it: %d pictures"
		% int(saved.get("pictures_after_tools", 0)), int(saved.get("pictures_after_tools", 0)) == 3
		and str(saved.get("last_tools", "")).contains("fresh pair of eyes"))
	_check("the log of the run never holds the key",
		not FileAccess.get_file_as_string(_log).contains(key)
		and not " ".join(lines).contains(key))


## Stopped while a slow provider thinks: finished once, as stopped; then a
## design on the quick one goes as it should, and the stopped one's reply
## never comes back into it.
func _stopped_then_again() -> void:
	print("\n── stopped part way, then designed again ──")
	var slow_log: String = ProjectSettings.globalize_path("user://provider-slow.jsonl")
	DirAccess.remove_absolute(slow_log)
	var key: String = "sk-stub-" + Crypto.new().generate_random_bytes(16).hex_encode()
	_slow = OS.create_process("python3", ["-I",
		ProjectSettings.globalize_path("res://tools/provider_stub.py"), "--port",
		str(_slow_port), "--log", slow_log, "--delay", str(SLOW_S)])
	await _seconds(2.0)
	var loop: DesignerLoop = _main.call("designer")
	var endings: Array = []
	loop.finished.connect(func(ok: bool, summary: String) -> void: endings.append([ok, summary]))
	_check("a design on the slow provider starts", _main.call("design_with_provider", BRIEF,
		ProviderSettings.provider_for("openai", "gpt-6.1-sol", key,
			"http://127.0.0.1:%d/v1" % _slow_port)))
	await _seconds(1.0)
	_check("...and is busy while it thinks", loop.busy())
	loop.stop()
	_check("stopped: finished once, as stopped: %s" % str(endings),
		endings == [[false, "stopped"]] and not loop.busy())
	_check("another starts at once on the quick one", _main.call("design_with_provider", BRIEF,
		ProviderSettings.provider_for("openai", "gpt-6.1-sol", key,
			"http://127.0.0.1:%d/v1" % _stub_port)))
	var until: int = Time.get_ticks_msec() + 240000
	while endings.size() < 2 and Time.get_ticks_msec() < until:
		await process_frame
	# The slow reply would have landed by now, had it a way in.
	await _seconds(SLOW_S + 1.0)
	_check("it finishes on its own last word, and nothing of the stopped one's: %s"
		% str(endings), endings.size() == 2 and bool(endings[1][0])
		and str(endings[1][1]).begins_with("I built a red tower") and loop.replies() == 7)
	_check("the tower stands again: %d parts" % _parts(), _parts() == 6)


func _seconds(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


## The request made after [param replies] replies, which answers the calls of
## the last of them; {} if there was none.
func _after(asked: Array, replies: int) -> Dictionary:
	for one: Dictionary in asked:
		if int(one["replies"]) == replies and int(one["status"]) == 200:
			return one
	return {}


## Chat Completions, read and written, with no network.
func _adapter() -> void:
	print("── the Chat Completions adapter ──")
	var chat: Provider = ProviderSettings.provider_for("openai", "gpt-6.1-sol", "sk-x")
	var picture: Dictionary = {"type": "image", "mimeType": "image/png", "data": "iVBORw0KGgo="}
	var turns: Array = [
		{"role": "user", "content": [{"type": "text", "text": "a tower"}]},
		{"role": "assistant", "text": "", "calls": [
			{"id": "a", "name": "view_model", "input": {}},
			{"id": "b", "name": "search_parts", "input": {"query": "slope"}}]},
		{"role": "tool", "results": [
			{"id": "a", "name": "view_model", "error": false,
				"content": [{"type": "text", "text": "From the corner:"}, picture]},
			{"id": "b", "name": "search_parts", "error": true,
				"content": [{"type": "text", "text": "nothing like that"}]}]},
	]
	var tools: Array = [{"name": "view_model", "description": "Look.",
		"inputSchema": {"type": "object", "properties": {}}}]
	var asked: Dictionary = chat.request("rules", tools, turns)
	var body: Dictionary = JSON.parse_string(str(asked["body"]))
	var messages: Array = body["messages"]
	_check("to OpenAI's own address, the key as a bearer: %s" % str(asked["url"]),
		str(asked["url"]) == "https://api.openai.com/v1/chat/completions"
		and (asked["headers"] as PackedStringArray).has("authorization: Bearer sk-x"))
	_check("system, the brief as words, the calls, their two answers, then the picture: %s"
		% str(messages.map(func(m: Dictionary) -> String: return str(m["role"]))),
		messages.map(func(m: Dictionary) -> String: return str(m["role"]))
			== ["system", "user", "assistant", "tool", "tool", "user"]
		and messages[1]["content"] == "a tower")
	_check("a call with no words says null, its arguments as a string of JSON",
		messages[2]["content"] == null and messages[2]["tool_calls"][1]["function"]["arguments"]
			== "{\"query\":\"slope\"}" and messages[2]["tool_calls"][0]["id"] == "a")
	_check("a tool's answer is words, saying its picture follows; a failure says so: %s"
		% str(messages[3]["content"]).replace("\n", " "),
		messages[3]["tool_call_id"] == "a" and str(messages[3]["content"]).begins_with(
			"From the corner:") and str(messages[3]["content"]).contains("in the next message")
		and str(messages[4]["content"]) == "Error: nothing like that")
	_check("the picture as a data: URL, named by its call",
		str(messages[5]["content"][0]["text"]).contains("view_model (a)")
		and messages[5]["content"][1]["image_url"]["url"] == "data:image/png;base64,iVBORw0KGgo=")
	_check("the tools as functions, MCP's schema as their parameters",
		body["tools"][0]["type"] == "function" and body["tools"][0]["function"]["parameters"]
			== {"type": "object", "properties": {}} and not body.has("max_completion_tokens"))

	var refused: Provider.Reply = chat.read(401, JSON.stringify({"error": {
		"message": "Incorrect API key provided."}}).to_utf8_buffer())
	_check("a refused key is said so, and not asked again: %s" % refused.error,
		not refused.ok and not refused.again and refused.error.begins_with(
			"The provider refused the key") and refused.error.contains("Incorrect API key"))
	var limited: Provider.Reply = chat.read(429, PackedByteArray())
	_check("a rate limit is asked again", not limited.ok and limited.again)
	var garbled: Provider.Reply = chat.read(200, JSON.stringify({"choices": [{"finish_reason":
		"tool_calls", "message": {"role": "assistant", "content": null, "tool_calls": [
			{"id": "c", "type": "function", "function": {"name": "view_model",
				"arguments": "{\"from\": "}}]}}], "usage": {"prompt_tokens": 100,
		"completion_tokens": 5, "prompt_tokens_details": {"cached_tokens": 60}}})
		.to_utf8_buffer())
	_check("arguments that are not JSON are kept to send back: %s" % str(garbled.calls),
		garbled.ok and garbled.stop == "tools" and garbled.calls[0].has("unread")
		and not garbled.calls[0].has("input"))
	_check("usage read: 40 fresh, 60 cached, 5 out", garbled.spend.fresh == 40
		and garbled.spend.cached == 60 and garbled.spend.made == 5)
	var local: Provider = ProviderSettings.provider_for("ollama", "qwen3.8", "", "",
		{"max_out": 8000})
	var local_body: Dictionary = JSON.parse_string(str(local.request("r", [], [])["body"]))
	_check("a server here: no key sent, max_tokens as such servers take it",
		str(local.request("r", [], [])["url"]) == "http://127.0.0.1:11434/v1/chat/completions"
		and not (local.request("r", [], [])["headers"] as PackedStringArray).has(
			"authorization: Bearer ") and int(local_body.get("max_tokens", 0)) == 8000)


## The key, kept as OwnKey keeps Anthropic's.
func _keys() -> void:
	print("\n── the person's key ──")
	_check("a Claude plan's sign-in token is refused: %s" % ProviderSettings.problem_with(
		"openai", "sk-ant-oat01-" + "x".repeat(40)).left(60), ProviderSettings.problem_with(
		"openai", "sk-ant-oat01-" + "x".repeat(40)).contains("not an API key"))
	_check("an OpenAI key must look like one", not ProviderSettings.problem_with(
		"openai", "pk-" + "x".repeat(40)).is_empty() and ProviderSettings.problem_with(
		"openai", "sk-proj-" + "x".repeat(40)).is_empty())
	_check("a server on this machine needs none",
		ProviderSettings.problem_with("ollama", "").is_empty())
	var key: String = "sk-proj-" + "k".repeat(40)
	ProviderSettings.remember("openai", key, false)
	_check("for this visit only: used, and written nowhere",
		ProviderSettings.load_key("openai") == key
		and not FileAccess.file_exists(ProviderSettings.key_file("openai")))
	ProviderSettings.remember("openai", key, true)
	_check("kept on this device, in the app's own data, encrypted: the file holds no key",
		ProviderSettings.load_key("openai") == key and FileAccess.file_exists(
			ProviderSettings.key_file("openai")) and not FileAccess.get_file_as_string(
			ProviderSettings.key_file("openai")).contains("k".repeat(20)))
	ProviderSettings._this_visit.clear()
	_check("...and read back from it", ProviderSettings.load_key("openai") == key)
	ProviderSettings.forget("openai")
	_check("forgotten: gone", not FileAccess.file_exists(ProviderSettings.key_file("openai"))
		and ProviderSettings.load_key("openai") == OS.get_environment("OPENAI_API_KEY"))
	_check("shown only as a fingerprint: %s" % ProviderSettings.fingerprint(key),
		not ProviderSettings.fingerprint(key).contains("k".repeat(10)))


## Whether Provider.portable makes of [param tools] what the relay's portable
## (api/mcp.js) makes of them, the one rule in the two languages it runs in:
## "the same for N tools", or which differ, or why it could not be asked.
func _as_relay(tools: Array) -> String:
	var given: String = ProjectSettings.globalize_path("user://portable-tools.json")
	var ours: String = ProjectSettings.globalize_path("user://portable-ours.json")
	FileAccess.open(given, FileAccess.WRITE).store_string(JSON.stringify(tools))
	FileAccess.open(ours, FileAccess.WRITE).store_string(JSON.stringify(Provider.portable(tools)))
	var script: String = "import { readFileSync } from 'node:fs'; import { pathToFileURL } from 'node:url';" \
		+ " const [, given, ours, relay] = process.argv;" \
		+ " const { portable } = await import(pathToFileURL(relay).href);" \
		+ " const sorted = (v) => JSON.stringify(v, (k, o) => o && typeof o === 'object' && !Array.isArray(o)" \
		+ " ? Object.fromEntries(Object.keys(o).sort().map((n) => [n, o[n]])) : o);" \
		+ " const theirs = JSON.parse(readFileSync(given, 'utf8')).map(portable);" \
		+ " const mine = JSON.parse(readFileSync(ours, 'utf8'));" \
		+ " const differ = theirs.filter((t, i) => sorted(t) !== sorted(mine[i])).map((t) => t.name);" \
		+ " console.log(differ.length || theirs.length !== mine.length ? 'differ: ' + differ.join(', ')" \
		+ " : 'the same for ' + theirs.length + ' tools');"
	var said: Array = []
	var code: int = OS.execute("node", ["--input-type=module", "-e", script, given, ours,
		ProjectSettings.globalize_path("res://api/mcp.js")], said, true)
	var lines: PackedStringArray = "\n".join(said).strip_edges().split("\n")
	return lines[lines.size() - 1] if code == 0 else "node said %d: %s" % [code, "\n".join(said).left(200)]


func _requests() -> Array:
	var out: Array = []
	for line: String in FileAccess.get_file_as_string(_log).split("\n", false):
		var one: Variant = JSON.parse_string(line)
		if one is Dictionary:
			out.append(one)
	return out


func _parts() -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not _assistant.scenery.has(brick.id):
			count += 1
	return count


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
