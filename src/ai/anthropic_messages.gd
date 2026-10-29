## Anthropic's Messages API, on the person's own Anthropic key.
##
## POST {base}/messages, as the in-app assistant speaks it (Assistant._send):
## x-api-key and anthropic-version, and on the web the header that lets a
## page call it (docs/PROVIDERS.md, 4.6). This is the designer loop's way to
## it, beside OpenAIChat: the app's MCP tools, the transcript (Provider) and
## nothing of the in-app assistant's own loop.
##
## Where it differs from the transcript:
##
## - The tools go as {name, description, input_schema}, MCP's inputSchema
##   untouched.
## - A tool's answer may hold pictures: tool_result blocks take image blocks,
##   so view_model's picture and the fresh look's three go back in the
##   answer itself, where the model reads them as the call's.
## - A reply's thinking blocks carry signatures that must come back exactly as
##   they were: the reply's whole content is kept (Reply.kept) and sent back
##   as the assistant's turn, untouched.
## - The system prompt and the tools are marked for the cache, and the
##   conversation's last block with them (the top-level mark, as the
##   assistant sends it), so a design pays for its 42,000 tokens of tools once.
## - max_tokens is required: the person's "most a reply may write", else
##   32,000, which every current Claude takes.
## - Effort is output_config's, with adaptive thinking, only where the person
##   chose one (the settings offer it where ProviderSettings.takes_effort);
##   a temperature is not sent with thinking, which refuses one.
class_name AnthropicMessages
extends Provider

const VERSION := "2023-06-01"
const MOST_OUT := 32000


func request(system: String, tools: Array, turns: Array) -> Dictionary:
	var messages: Array = []
	for turn: Dictionary in turns:
		var message: Dictionary = _message_of(turn)
		if not message.is_empty():
			messages.append(message)
	var body: Dictionary = {"model": model,
		"max_tokens": int(params.get("max_out", MOST_OUT)) if int(params.get("max_out", 0)) > 0
			else MOST_OUT,
		"system": [{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
		"messages": messages, "cache_control": {"type": "ephemeral"}}
	if not tools.is_empty():
		body["tools"] = declarations(tools)
	var thinking: bool = params.has("reasoning_effort")
	if thinking:
		body["output_config"] = {"effort": str(params["reasoning_effort"])}
		body["thinking"] = {"type": "adaptive"}
	elif params.has("temperature"):
		body["temperature"] = float(params["temperature"])
	return {"url": address("messages"), "headers": headers(), "body": JSON.stringify(body)}


func headers() -> PackedStringArray:
	var out := PackedStringArray(["content-type: application/json",
		"x-api-key: " + key, "anthropic-version: " + VERSION])
	if OS.has_feature("web"):
		out.append("anthropic-dangerous-direct-browser-access: true")
	return out


## MCP's tools as Anthropic's.
static func declarations(tools: Array) -> Array:
	var out: Array = []
	for tool: Variant in tools:
		var one: Dictionary = tool
		var schema: Variant = one.get("inputSchema", one.get("input_schema", {}))
		if not (schema is Dictionary) or (schema as Dictionary).is_empty():
			schema = {"type": "object", "properties": {}}
		out.append({"name": str(one.get("name", "")), "description": str(one.get("description", "")),
			"input_schema": schema})
	return out


func _message_of(turn: Dictionary) -> Dictionary:
	match str(turn.get("role", "")):
		"user":
			return {"role": "user", "content": _blocks(turn.get("content", []))}
		"assistant":
			# The reply as it came, thinking and its signatures with it.
			if turn.get("kept") is Array and not (turn["kept"] as Array).is_empty():
				return {"role": "assistant", "content": turn["kept"]}
			var content: Array = []
			if not str(turn.get("text", "")).is_empty():
				content.append({"type": "text", "text": str(turn["text"])})
			for call: Dictionary in turn.get("calls", []):
				content.append({"type": "tool_use", "id": str(call["id"]), "name": str(call["name"]),
					"input": call.get("input", {})})
			if content.is_empty():
				content.append({"type": "text", "text": "(nothing)"})
			return {"role": "assistant", "content": content}
		"tool":
			var content: Array = []
			for result: Dictionary in turn.get("results", []):
				var blocks: Array = _blocks(result.get("content", []))
				content.append({"type": "tool_result", "tool_use_id": str(result["id"]),
					"content": blocks if not blocks.is_empty() else [{"type": "text",
						"text": "(no answer)"}],
					"is_error": bool(result.get("error", false))})
			return {"role": "user", "content": content}
	return {}


## MCP's blocks as Anthropic's: words as they are, a picture as base64.
static func _blocks(blocks: Array) -> Array:
	var out: Array = []
	for block: Variant in blocks:
		if not (block is Dictionary):
			continue
		var one: Dictionary = block
		if str(one.get("type", "")) == "image":
			out.append({"type": "image", "source": {"type": "base64",
				"media_type": str(one.get("mimeType", "image/png")), "data": str(one.get("data", ""))}})
		elif not str(one.get("text", "")).is_empty():
			out.append({"type": "text", "text": str(one["text"])})
	return out


func read(code: int, body: PackedByteArray) -> Reply:
	var reply := Reply.new()
	var parsed: Variant = Provider.parsed(body.get_string_from_utf8())
	var answer: Dictionary = parsed if parsed is Dictionary else {}
	if code != 200 or str(answer.get("type", "")) == "error":
		var said: Variant = answer.get("error", {})
		reply.error = Provider.refusal(code, str((said as Dictionary).get("message", ""))
			if said is Dictionary else str(said))
		# 529 is Anthropic's "overloaded", which passes.
		reply.again = Provider.transient(code)
		return reply
	if not (answer.get("content") is Array):
		reply.error = "The provider's answer had no content in it."
		reply.again = true
		return reply
	var content: Array = answer["content"]
	var words := PackedStringArray()
	for raw: Variant in content:
		var block: Dictionary = raw if raw is Dictionary else {}
		match str(block.get("type", "")):
			"text":
				words.append(str(block.get("text", "")))
			"tool_use":
				var input: Variant = block.get("input", {})
				var call: Dictionary = {"id": str(block.get("id", "")), "name": str(block.get("name", ""))}
				if input is Dictionary:
					call["input"] = input
				else:
					call["unread"] = JSON.stringify(input)
				reply.calls.append(call)
	reply.text = "\n\n".join(words).strip_edges()
	reply.kept = content
	reply.stop = "tools" if not reply.calls.is_empty() else {"max_tokens": "length",
		"refusal": "refused"}.get(str(answer.get("stop_reason", "")), "end")
	var usage: Dictionary = answer.get("usage", {}) if answer.get("usage") is Dictionary else {}
	reply.spend.cached = int(usage.get("cache_read_input_tokens", 0))
	reply.spend.fresh = int(usage.get("input_tokens", 0)) \
		+ int(usage.get("cache_creation_input_tokens", 0))
	reply.spend.made = int(usage.get("output_tokens", 0))
	reply.ok = true
	return reply


func models_request() -> Dictionary:
	var out: PackedStringArray = headers()
	out.remove_at(0)
	return {"url": address("models?limit=1000"), "headers": out}


## Every Claude since the third calls tools and sees pictures.
func read_models(code: int, body: PackedByteArray) -> Dictionary:
	var parsed: Variant = Provider.parsed(body.get_string_from_utf8())
	var answer: Dictionary = parsed if parsed is Dictionary else {}
	if code != 200 or not (answer.get("data") is Array):
		var said: Variant = answer.get("error", {})
		return {"ok": false, "models": [], "error": Provider.refusal(code,
			str((said as Dictionary).get("message", "")) if said is Dictionary else str(said))}
	var models: Array = []
	for raw: Variant in answer["data"]:
		if raw is Dictionary and not str((raw as Dictionary).get("id", "")).is_empty():
			var model: Dictionary = Provider.listed(str(raw["id"]), str(raw.get("display_name", "")))
			model["tools"] = true
			model["pictures"] = true
			models.append(model)
	return {"ok": true, "error": "", "models": models}


func efforts() -> Array:
	return ["low", "medium", "high", "xhigh", "max"]
