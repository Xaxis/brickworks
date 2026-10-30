## OpenAI's Chat Completions, and every server that speaks it.
##
## POST {base}/chat/completions. OpenAI itself, and OpenRouter, Groq,
## Together, Mistral, DeepSeek, Gemini's compatibility endpoint, Ollama,
## LM Studio and vLLM on the person's own machine: one adapter, a different
## base address and key (ProviderSettings.PRESETS).
##
## Where it differs from the transcript (Provider):
##
## - The tools go as {"type": "function", "function": {name, description,
##   parameters}}, MCP's inputSchema as the parameters in the portable form
##   ChatGPT is given too (Provider.portable): every array says what its items
##   are, which OpenAI refuses a request without ("array schema missing
##   items"). Not strict mode, which would refuse most of the app's schemas
##   (every property required, additionalProperties false on every object).
## - A call's arguments come as a string of JSON, which a weaker model can get
##   wrong: such a call is kept as "unread" and answered with what was wrong,
##   so the model can say it again.
## - A tool's answer is text only. Chat Completions documents no picture in a
##   role "tool" message (developers.openai.com/api/docs/guides/function-calling
##   says how for Responses alone), so the pictures of a turn's answers follow
##   them in one user message, each named by the call it came from. view_model
##   and the fresh look's three pictures reach the model that way.
class_name OpenAIChat
extends Provider


func request(system: String, tools: Array, turns: Array) -> Dictionary:
	var messages: Array = [{"role": "system", "content": system}]
	for turn: Dictionary in turns:
		messages.append_array(_messages_of(turn))
	var body: Dictionary = {"model": model, "messages": messages}
	if not tools.is_empty():
		body["tools"] = functions(tools)
	if params.has("reasoning_effort"):
		body["reasoning_effort"] = str(params["reasoning_effort"])
	if params.has("temperature"):
		body["temperature"] = float(params["temperature"])
	if params.has("max_out"):
		# OpenAI's own models take max_completion_tokens and refuse
		# max_tokens; most servers that copy the API know only max_tokens.
		body["max_completion_tokens" if base_url.contains("api.openai.com")
			else "max_tokens"] = int(params["max_out"])
	var headers := PackedStringArray(["content-type: application/json"])
	if not key.is_empty():
		headers.append("authorization: Bearer " + key)
	return {"url": address("chat/completions"), "headers": headers,
		"body": JSON.stringify(body)}


## MCP's tools as functions, portable.
static func functions(tools: Array) -> Array:
	var out: Array = []
	for tool: Variant in Provider.portable(tools):
		var one: Dictionary = tool
		var schema: Variant = one.get("inputSchema", one.get("input_schema", {}))
		if not (schema is Dictionary) or (schema as Dictionary).is_empty():
			schema = {"type": "object", "properties": {}}
		out.append({"type": "function", "function": {"name": str(one.get("name", "")),
			"description": str(one.get("description", "")), "parameters": schema}})
	return out


func _messages_of(turn: Dictionary) -> Array:
	match str(turn.get("role", "")):
		"user":
			return [{"role": "user", "content": _content(turn.get("content", []))}]
		"assistant":
			var said: Dictionary = {"role": "assistant",
				"content": str(turn.get("text", "")) if not str(turn.get("text", "")).is_empty()
					or (turn.get("calls", []) as Array).is_empty() else null}
			var calls: Array = []
			for call: Dictionary in turn.get("calls", []):
				calls.append({"id": str(call["id"]), "type": "function", "function": {
					"name": str(call["name"]),
					"arguments": str(call["unread"]) if call.has("unread")
						else JSON.stringify(call.get("input", {}))}})
			if not calls.is_empty():
				said["tool_calls"] = calls
			return [said]
		"tool":
			var out: Array = []
			var pictures: Array = []
			for result: Dictionary in turn.get("results", []):
				var blocks: Array = result.get("content", [])
				var images: Array = Provider.images_of(blocks)
				var words: String = Provider.text_of(blocks)
				if not images.is_empty():
					words += ("\n\n" if not words.is_empty() else "") + (
						"(%d picture%s, in the next message.)" % [images.size(),
							"" if images.size() == 1 else "s"])
					pictures.append({"type": "text", "text":
						"The picture%s %s (%s) answered with:" % ["" if images.size() == 1
							else "s", str(result.get("name", "")), str(result["id"])]})
					pictures.append_array(images)
				if bool(result.get("error", false)):
					words = "Error: " + words
				out.append({"role": "tool", "tool_call_id": str(result["id"]),
					"content": words if not words.is_empty() else "(no answer)"})
			if not pictures.is_empty():
				out.append({"role": "user", "content": _content(pictures)})
			return out
	return []


## A user message's content: a string when it is words alone, which every
## server takes; parts when there is a picture in it.
static func _content(blocks: Array) -> Variant:
	if Provider.images_of(blocks).is_empty():
		return Provider.text_of(blocks)
	var parts: Array = []
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "image":
			parts.append({"type": "image_url", "image_url": {"url": Provider.data_url(block)}})
		else:
			parts.append({"type": "text", "text": str(block.get("text", ""))})
	return parts


func read(code: int, body: PackedByteArray) -> Reply:
	var reply := Reply.new()
	var parsed: Variant = Provider.parsed(body.get_string_from_utf8())
	var answer: Dictionary = parsed if parsed is Dictionary else {}
	if code != 200 or answer.has("error"):
		var said: Variant = answer.get("error", {})
		reply.error = Provider.refusal(code, str((said as Dictionary).get("message", ""))
			if said is Dictionary else str(said))
		reply.again = Provider.transient(code)
		return reply
	var choices: Array = answer.get("choices", []) if answer.get("choices") is Array else []
	if choices.is_empty() or not ((choices[0] as Dictionary).get("message") is Dictionary):
		reply.error = "The provider's answer had no message in it."
		reply.again = true
		return reply
	var message: Dictionary = (choices[0] as Dictionary)["message"]
	var content: Variant = message.get("content")
	if content is String:
		reply.text = (content as String).strip_edges()
	elif content is Array:
		reply.text = Provider.text_of(content).strip_edges()
	var n: int = 0
	for raw: Variant in message.get("tool_calls", []) if message.get("tool_calls") is Array else []:
		var function: Dictionary = (raw as Dictionary).get("function", {}) as Dictionary
		n += 1
		# Some local servers send no id; the answer has to name one.
		var id: String = str((raw as Dictionary).get("id", ""))
		var call: Dictionary = {"id": id if not id.is_empty() else "call_%d" % n,
			"name": str(function.get("name", ""))}
		var arguments: Variant = function.get("arguments", "{}")
		var input: Variant = arguments
		if arguments is String:
			input = {} if (arguments as String).strip_edges().is_empty() \
				else Provider.parsed(arguments)
		if input is Dictionary:
			call["input"] = input
		else:
			call["unread"] = str(arguments)
		reply.calls.append(call)
	var finish: String = str((choices[0] as Dictionary).get("finish_reason", ""))
	reply.stop = "tools" if not reply.calls.is_empty() else {"length": "length",
		"content_filter": "refused"}.get(finish, "end")
	var usage: Dictionary = answer.get("usage", {}) if answer.get("usage") is Dictionary else {}
	var details: Dictionary = usage.get("prompt_tokens_details", {}) \
		if usage.get("prompt_tokens_details") is Dictionary else {}
	reply.spend.cached = int(details.get("cached_tokens", 0))
	reply.spend.fresh = maxi(0, int(usage.get("prompt_tokens", 0)) - reply.spend.cached)
	reply.spend.made = int(usage.get("completion_tokens", 0))
	reply.ok = true
	return reply


## GET {base}/models: every OpenAI-compatible server has it, Ollama's and
## LM Studio's included. OpenRouter's says per model what it takes.
func models_request() -> Dictionary:
	var headers := PackedStringArray()
	if not key.is_empty():
		headers.append("authorization: Bearer " + key)
	return {"url": address("models"), "headers": headers}


func read_models(code: int, body: PackedByteArray) -> Dictionary:
	var parsed: Variant = Provider.parsed(body.get_string_from_utf8())
	var answer: Dictionary = parsed if parsed is Dictionary else {}
	if code != 200 or not (answer.get("data") is Array):
		var said: Variant = answer.get("error", {})
		return {"ok": false, "models": [], "error": Provider.refusal(code,
			str((said as Dictionary).get("message", "")) if said is Dictionary else str(said))}
	var models: Array = []
	for raw: Variant in answer["data"]:
		if not (raw is Dictionary) or str((raw as Dictionary).get("id", "")).is_empty():
			continue
		var one: Dictionary = raw
		var model: Dictionary = Provider.listed(str(one["id"]), str(one.get("name", "")))
		# OpenRouter's: supported_parameters, and architecture's input
		# modalities. Nobody else says, and silence is not a no.
		if one.get("supported_parameters") is Array:
			var takes: Array = one["supported_parameters"]
			model["params"] = takes
			model["tools"] = takes.has("tools")
		var architecture: Variant = one.get("architecture")
		if architecture is Dictionary and (architecture as Dictionary).get("input_modalities") is Array:
			model["pictures"] = ((architecture as Dictionary)["input_modalities"] as Array).has("image")
		models.append(model)
	return {"ok": true, "error": "", "models": models}


## OpenAI's own take minimal and xhigh as well; the servers that copy the
## API take low, medium and high where they take it at all.
func efforts() -> Array:
	return ["minimal", "low", "medium", "high", "xhigh"] if base_url.contains("api.openai.com") \
		else ["low", "medium", "high"]
