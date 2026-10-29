## Do Anthropic's Messages and Gemini's own API design here, as Chat
## Completions does?
##
##   godot --path . --resolution 1400x900 --script src/dev/provider_apis_probe.gd
##
## AnthropicMessages and GeminiNative, each one file beside OpenAIChat
## (docs/PROVIDERS.md, P3). First each read and written with no network:
## where the tools go, a tool's answer with its picture in it, the reply's
## own blocks sent back untouched (Anthropic's thinking and its signature,
## Gemini's thoughtSignature), the effort, the most out, a refusal. Then each
## against tools/provider_stub.py on 127.0.0.1:9661, as strict as that API
## (its header says how): a whole design through the app's own 61 tools (the
## tower built, the fresh look asked with its three pictures in the tool's
## answer and answered, saved, its first answer a rate limit), Test (tools
## and pictures; pictures refused), and the provider's list of its models.
## In a window, for the pictures.
extends SceneTree

const PORT := 9661
const BRIEF := "A slender red tower, six bricks tall"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _assistant: Assistant
var _stub: int = -1
var _log: String = ""
var _key: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_anthropic_offline()
	_gemini_offline()
	_key = "sk-ant-stub-" + Crypto.new().generate_random_bytes(16).hex_encode()
	_log = ProjectSettings.globalize_path("user://apis-stub.jsonl")
	OS.set_environment("STUB_KEY", _key)
	_stub = OS.create_process("python3", ["-I",
		ProjectSettings.globalize_path("res://tools/provider_stub.py"), "--port", str(PORT),
		"--log", _log, "--fail-first", "1"])
	OS.unset_environment("STUB_KEY")
	_check("the stub provider starts (pid %d)" % _stub, _stub > 0)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_assistant = _main.get("_assistant")
	(_main.get("_store") as ModelStore).keeps = false
	await _design("anthropic", "http://127.0.0.1:%d/v1" % PORT)
	await _design("gemini_native", "http://127.0.0.1:%d/v1beta" % PORT)
	await _tests("anthropic", "http://127.0.0.1:%d/v1" % PORT)
	await _tests("gemini_native", "http://127.0.0.1:%d/v1beta" % PORT)
	_check("the key in no line the stub kept", not FileAccess.get_file_as_string(_log).contains(_key))
	if _stub > 0:
		OS.kill(_stub)
	print("")
	print("provider apis: Anthropic's Messages and Gemini's own API designed, tested and listed"
		if _failures == 0 else "provider apis: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


const PICTURE := {"type": "image", "mimeType": "image/png", "data": "iVBORw0KGgo="}


## The transcript every adapter is read against: two calls, their answers,
## one with a picture and one an error.
func _turns(kept: Variant) -> Array:
	return [{"role": "user", "content": [{"type": "text", "text": "a tower"}]},
		{"role": "assistant", "text": "", "kept": kept, "calls": [
			{"id": "a", "name": "view_model", "input": {}},
			{"id": "b", "name": "search_parts", "input": {"query": "slope"}}]},
		{"role": "tool", "results": [
			{"id": "a", "name": "view_model", "error": false,
				"content": [{"type": "text", "text": "From the corner:"}, PICTURE]},
			{"id": "b", "name": "search_parts", "error": true,
				"content": [{"type": "text", "text": "nothing like that"}]}]}]


const TOOLS: Array = [{"name": "view_model", "description": "Look.",
	"inputSchema": {"type": "object", "properties": {}}},
	{"name": "search_parts", "description": "Find.", "inputSchema": {"type": "object",
		"additionalProperties": false, "properties": {"query": {"type": "string"},
			"near": {"type": "object", "additionalProperties": false,
				"properties": {"x": {"type": "number", "default": 0}}}}}}]


func _anthropic_offline() -> void:
	print("── Anthropic's Messages, read and written ──")
	var made: Provider = ProviderSettings.provider_for("anthropic", "claude-sonnet-5-5", "sk-ant-x",
		"", {"reasoning_effort": "high", "temperature": 0.5})
	var thinking: Array = [{"type": "thinking", "thinking": "hmm", "signature": "sig"},
		{"type": "tool_use", "id": "a", "name": "view_model", "input": {}},
		{"type": "tool_use", "id": "b", "name": "search_parts", "input": {"query": "slope"}}]
	var asked: Dictionary = made.request("rules", TOOLS, _turns(thinking))
	var body: Dictionary = JSON.parse_string(str(asked["body"]))
	var headers: PackedStringArray = asked["headers"]
	_check("to Anthropic's own address, with x-api-key and its version: %s" % asked["url"],
		asked["url"] == "https://api.anthropic.com/v1/messages" and headers.has("x-api-key: sk-ant-x")
		and headers.has("anthropic-version: 2023-06-01"))
	_check("the system and the conversation marked for the cache; max_tokens there",
		body["system"][0]["cache_control"]["type"] == "ephemeral" and body.has("cache_control")
		and int(body["max_tokens"]) == AnthropicMessages.MOST_OUT)
	_check("effort as output_config's, with adaptive thinking, and no temperature with it",
		body["output_config"] == {"effort": "high"} and body["thinking"] == {"type": "adaptive"}
		and not body.has("temperature"))
	_check("the tools as input_schema, untouched", body["tools"][1]["input_schema"]
		== _as_sent(TOOLS[1]["inputSchema"]) and body["tools"][1]["name"] == "search_parts")
	var messages: Array = body["messages"]
	_check("the reply sent back as it came, its thinking and signature with it",
		messages[1]["role"] == "assistant" and messages[1]["content"] == thinking)
	var answers: Array = messages[2]["content"]
	_check("each call answered by a tool_result, the picture inside its answer, the error said",
		messages[2]["role"] == "user" and answers[0]["type"] == "tool_result"
		and answers[0]["tool_use_id"] == "a" and answers[0]["content"][1]["type"] == "image"
		and answers[0]["content"][1]["source"] == {"type": "base64", "media_type": "image/png",
			"data": "iVBORw0KGgo="} and bool(answers[1]["is_error"]) and not bool(answers[0]["is_error"]))
	var cool: Provider = ProviderSettings.provider_for("anthropic", "claude-haiku-4-5", "sk-ant-x", "",
		{"temperature": 0.5, "max_out": 9000})
	var cool_body: Dictionary = JSON.parse_string(str(cool.request("r", [], _turns(null))["body"]))
	_check("no effort: a temperature, the most out as max_tokens, no thinking",
		is_equal_approx(float(cool_body["temperature"]), 0.5) and int(cool_body["max_tokens"]) == 9000
		and not cool_body.has("thinking") and cool_body["messages"][1]["content"][0]["type"] == "tool_use")
	var reply: Provider.Reply = made.read(200, JSON.stringify({"content": thinking + [
		{"type": "text", "text": "Looking."}], "stop_reason": "tool_use", "usage": {"input_tokens": 30,
		"cache_creation_input_tokens": 10, "cache_read_input_tokens": 60, "output_tokens": 5}})
		.to_utf8_buffer())
	_check("a reply read: its calls, its words, its blocks kept, its tokens",
		reply.ok and reply.stop == "tools" and reply.calls.size() == 2 and reply.text == "Looking."
		and reply.kept == thinking + [{"type": "text", "text": "Looking."}] and reply.spend.fresh == 40
		and reply.spend.cached == 60 and reply.spend.made == 5)
	var refused: Provider.Reply = made.read(401, JSON.stringify({"type": "error", "error": {
		"type": "authentication_error", "message": "invalid x-api-key"}}).to_utf8_buffer())
	var busy: Provider.Reply = made.read(529, PackedByteArray())
	_check("a refused key said and not asked again; overloaded asked again: %s" % refused.error,
		not refused.ok and not refused.again and refused.error.contains("invalid x-api-key")
		and not busy.ok and busy.again)


func _gemini_offline() -> void:
	print("\n── Gemini's own API, read and written ──")
	var made: Provider = ProviderSettings.provider_for("gemini_native", "gemini-4-argon", "AIza-x", "",
		{"reasoning_effort": "high", "max_out": 8000, "temperature": 0.2})
	var kept: Array = [{"functionCall": {"name": "view_model", "args": {}, "id": "a"},
		"thoughtSignature": "sig"}, {"functionCall": {"name": "search_parts",
			"args": {"query": "slope"}}}]
	var turns: Array = _turns(kept)
	turns[1]["calls"][1]["id"] = GeminiNative.MADE + "2"
	turns[2]["results"][1]["id"] = GeminiNative.MADE + "2"
	var asked: Dictionary = made.request("rules", TOOLS, turns)
	var body: Dictionary = JSON.parse_string(str(asked["body"]))
	_check("to the model's own generateContent, with x-goog-api-key: %s" % asked["url"],
		asked["url"] == ("https://generativelanguage.googleapis.com/v1beta/models/"
			+ "gemini-4-argon:generateContent") and (asked["headers"] as PackedStringArray).has(
			"x-goog-api-key: AIza-x"))
	var declared: Array = body["tools"][0]["functionDeclarations"]
	_check("the schema cut to Gemini's subset, all the way down; no parameters for none",
		not declared[0].has("parameters") and not declared[1]["parameters"].has("additionalProperties")
		and not declared[1]["parameters"]["properties"]["near"].has("additionalProperties")
		and not declared[1]["parameters"]["properties"]["near"]["properties"]["x"].has("default")
		and declared[1]["parameters"]["properties"]["query"] == {"type": "string"})
	_check("effort as thinkingLevel, the most out and the temperature in generationConfig",
		body["generationConfig"] == _as_sent({"thinkingConfig": {"thinkingLevel": "high"},
			"maxOutputTokens": 8000, "temperature": 0.2})
		and body["systemInstruction"]["parts"][0]["text"] == "rules")
	var contents: Array = body["contents"]
	_check("the model's turn sent back as it came, its thought signature with it",
		contents[1]["role"] == "model" and contents[1]["parts"] == kept)
	var answers: Array = contents[2]["parts"]
	_check("each call answered by name, Gemini's id sent back and ours not, the picture inside",
		contents[2]["role"] == "user" and answers[0]["functionResponse"]["id"] == "a"
		and answers[0]["functionResponse"]["name"] == "view_model"
		and answers[0]["functionResponse"]["parts"][0]["inlineData"]["data"] == "iVBORw0KGgo="
		and not answers[1]["functionResponse"].has("id")
		and answers[1]["functionResponse"]["response"] == {"error": "nothing like that"})
	var reply: Provider.Reply = made.read(200, JSON.stringify({"candidates": [{"content": {
		"role": "model", "parts": [{"text": "thinking", "thought": true}, {"text": "Looking."}] + kept},
		"finishReason": "STOP"}], "usageMetadata": {"promptTokenCount": 100,
		"cachedContentTokenCount": 60, "candidatesTokenCount": 5, "thoughtsTokenCount": 3}})
		.to_utf8_buffer())
	_check("a reply read: its words without its thoughts, its calls, ids made where none came",
		reply.ok and reply.stop == "tools" and reply.text == "Looking." and reply.calls.size() == 2
		and reply.calls[0]["id"] == "a" and str(reply.calls[1]["id"]).begins_with(GeminiNative.MADE)
		and reply.spend.fresh == 40 and reply.spend.cached == 60 and reply.spend.made == 8)
	var cut: Provider.Reply = made.read(200, JSON.stringify({"candidates": [{"content": {"parts": [
		{"text": "half"}]}, "finishReason": "MAX_TOKENS"}]}).to_utf8_buffer())
	var refused: Provider.Reply = made.read(400, JSON.stringify({"error": {"code": 400,
		"message": "API key not valid.", "status": "INVALID_ARGUMENT"}}).to_utf8_buffer())
	_check("cut off said as such; a refusal said and not asked again: %s" % refused.error,
		cut.ok and cut.stop == "length" and not refused.ok and not refused.again
		and refused.error.contains("API key not valid"))


## A whole design on [param id]'s adapter, through the stub.
func _design(id: String, base: String) -> void:
	print("\n── a design on %s, against the strict stub ──" % id)
	var before: int = _requests().size()
	var provider: Provider = ProviderSettings.provider_for(id, "stub-sees", _key, base,
		{"reasoning_effort": "high"})
	_check("the design starts", _main.call("design_with_provider", BRIEF, provider))
	var loop: DesignerLoop = _main.call("designer")
	var outcome: Array = []
	var ended := func(ok: bool, summary: String) -> void: outcome.append_array([ok, summary])
	loop.finished.connect(ended)
	await _until(func() -> bool: return not outcome.is_empty(), 240.0)
	loop.finished.disconnect(ended)
	_check("it finishes on the model's own last word: %s" % str(outcome), outcome.size() == 2
		and bool(outcome[0]) and str(outcome[1]).begins_with("I built a red tower"))
	_check("the tower stands: %d parts" % _parts(), _parts() == 6)
	var eyes: Dictionary = _assistant.call("fresh_eyes").get("last")
	_check("the fresh look was asked and answered in the judge's shape",
		(eyes.get("changes", []) as Array).size() == 3
		and str(eyes.get("reads_as", "")) == "a red column of six bricks")
	_check("saved", FileAccess.file_exists(ModelStore.SAVE_DIR + "stub-tower.ldr"))
	var asked: Array = _requests().slice(before)
	var statuses: Array = asked.map(func(one: Dictionary) -> int: return int(one["status"]))
	var refused: Array = []
	var whole: bool = true
	for one: Dictionary in asked:
		refused.append_array(one["problems"])
		whole = whole and bool(one["key_is_stub"]) and bool(one["system_has_guide"]) \
			and int(one["tools"]) > 50
	# The stub's one rate limit is the first request it is sent: Anthropic's.
	_check("%s7 answered: %s" % ["the rate limit asked again, then " if id == "anthropic" else "",
		str(statuses)], statuses == [429, 200, 200, 200, 200, 200, 200, 200] if id == "anthropic"
		else statuses == [200, 200, 200, 200, 200, 200, 200])
	_check("nothing the API would refuse (signatures back, calls answered in order, schema "
		+ "Gemini takes): %s" % str(refused), refused.is_empty())
	_check("each with the key in the API's own header, the app's instructions and all its tools",
		whole and not asked.is_empty())
	var looked: Dictionary = _after(asked, 3)
	var saved: Dictionary = _after(asked, 4)
	_check("view_model's picture inside its answer: %d; the fresh look's three inside its: %d"
		% [int(looked.get("pictures_in_answers", 0)), int(saved.get("pictures_in_answers", 0))],
		int(looked.get("pictures_in_answers", 0)) >= 1 and int(saved.get("pictures_in_answers", 0)) == 3
		and str(saved.get("last_tools", "")).contains("fresh pair of eyes"))


## Test and the model list on [param id]'s adapter.
func _tests(id: String, base: String) -> void:
	print("\n── Test and the list, on %s ──" % id)
	var tester := ModelTest.new()
	root.add_child(tester)
	var sees: Dictionary = await tester.run(ProviderSettings.provider_for(id, "stub-sees", _key, base))
	var blind: Dictionary = await tester.run(ProviderSettings.provider_for(id, "stub-blind", _key, base))
	_check("a model that sees: %s" % sees["words"], sees["words"] == ModelTest.summary(true, true))
	_check("one refused pictures: %s (%s)" % [blind["words"], blind["detail"]],
		blind["words"] == ModelTest.summary(true, false)
		and str(blind["detail"]).contains("does not support image input"))
	var listed: Dictionary = await tester.models(ProviderSettings.provider_for(id, "", _key, base))
	var ids: Array = (listed["models"] as Array).map(func(one: Dictionary) -> String: return one["id"])
	_check("its models listed with the key: %s" % str(ids), bool(listed["ok"])
		and ids == ["stub-sees", "stub-blind", "stub-notools", "gpt-6.1-sol"])
	var wrong: Dictionary = await tester.models(ProviderSettings.provider_for(id, "", "not-the-key", base))
	_check("a wrong key's list refused, in words: %s" % str(wrong["error"]).left(80),
		not bool(wrong["ok"]) and str(wrong["error"]).contains("refused the key"))
	tester.queue_free()


## [param value] as it reads back from a request's JSON (every number a float).
static func _as_sent(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _after(asked: Array, replies: int) -> Dictionary:
	for one: Dictionary in asked:
		if int(one.get("replies", -1)) == replies and int(one["status"]) == 200:
			return one
	return {}


func _requests() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(_log):
		return out
	for line: String in FileAccess.get_file_as_string(_log).split("\n", false):
		var one: Variant = JSON.parse_string(line)
		if one is Dictionary and not bool((one as Dictionary).get("listed", false)):
			out.append(one)
	return out


func _parts() -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not _assistant.scenery.has(brick.id):
			count += 1
	return count


func _until(done: Callable, seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while not bool(done.call()) and Time.get_ticks_msec() < until:
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
