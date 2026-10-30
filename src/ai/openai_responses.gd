## OpenAI's Responses API: how OpenAI's own models are spoken to.
##
## POST {base}/responses. Chat Completions (OpenAIChat) stays the way to every
## server that copies OpenAI's API; OpenAI's own models come here, for what
## Chat Completions cannot carry (docs/PROVIDERS.md, 4.1). Its model list and
## efforts are OpenAIChat's: the same host's GET /models.
##
## Where it differs from the transcript (Provider):
##
## - The tools go flat, {type: "function", name, description, parameters,
##   strict: false}, the parameters in the portable form (Provider.portable).
##   A function in Responses is strict unless it says not, and strict refuses
##   most of the app's schemas (every property required, additionalProperties
##   false on every object).
## - A call is a function_call item named by its call_id, answered by a
##   function_call_output of the same call_id. Its arguments are a string of
##   JSON, kept "unread" when they are not, as OpenAIChat keeps them.
## - A tool's answer may hold pictures: function_call_output's output is a
##   list of input_text and input_image ("we've updated function calling to
##   support files and images as tool call outputs", 2025-09-26), so
##   view_model's picture and the fresh look's three reach the model as the
##   call's own answer.
## - A reasoning model's reasoning is items of its own, kept with the reply
##   they came in (Reply.kept) and sent back with it as they came, so the
##   model goes on from its own thinking instead of starting each turn
##   afresh. Nothing is left at OpenAI (store false), so the reasoning is
##   asked for encrypted (include reasoning.encrypted_content) and goes back
##   so. A reply whose reasoning came without it (a model the name did not
##   say reasons) goes back as its words and calls alone.
## - Effort is reasoning.effort; the most a reply may write is
##   max_output_tokens.
## - Streamed, a reply is events: its words and each call's arguments as
##   deltas while they are written, and at the end response.completed with
##   the whole response in it, which is the reply read (Items).
class_name OpenAIResponses
extends OpenAIChat

## What a reasoning item needs with store false to be sent back.
const ENCRYPTED := "reasoning.encrypted_content"


func request(system: String, tools: Array, turns: Array, stream: bool = false) -> Dictionary:
	var items: Array = []
	for turn: Dictionary in turns:
		items.append_array(_items_of(turn))
	var body: Dictionary = {"model": model, "instructions": system, "input": items, "store": false}
	if not tools.is_empty():
		body["tools"] = flat(tools)
	if params.has("reasoning_effort"):
		body["reasoning"] = {"effort": str(params["reasoning_effort"])}
	# Asked only of a model that reasons: one that does not refuses it
	# ("Encrypted content is not supported with this model").
	if params.has("reasoning_effort") or ProviderSettings.takes_effort(model):
		body["include"] = [ENCRYPTED]
	if params.has("temperature"):
		body["temperature"] = float(params["temperature"])
	if int(params.get("max_out", 0)) > 0:
		body["max_output_tokens"] = int(params["max_out"])
	if stream:
		body["stream"] = true
	var headers := PackedStringArray(["content-type: application/json"])
	if not key.is_empty():
		headers.append("authorization: Bearer " + key)
	return {"url": address("responses"), "headers": headers, "body": JSON.stringify(body)}


func reader() -> Streamer.Events:
	return Items.new()


## Responses' events: the deltas said as they come, and the response its
## last event carries (completed, incomplete or failed) as the reply.
class Items extends Streamer.Events:
	## Output index -> the name of the function called there.
	var _names: Dictionary = {}

	func take(event: Dictionary) -> Dictionary:
		var item: Variant = event.get("item")
		match str(event.get("type", "")):
			"response.output_item.added":
				if item is Dictionary and str((item as Dictionary).get("type", "")) == "function_call":
					_names[int(event.get("output_index", -1))] = str((item as Dictionary).get("name", ""))
			"response.function_call_arguments.delta":
				return {"fragments": [[str(_names.get(int(event.get("output_index", -1)), "")),
					str(event.get("delta", ""))]]}
			"response.output_text.delta":
				return {"text": str(event.get("delta", ""))}
			"response.completed", "response.incomplete", "response.failed":
				if event.get("response") is Dictionary:
					message = event["response"]
					finished = true
		return {}


## MCP's tools as Responses' functions: Chat Completions' made flat.
static func flat(tools: Array) -> Array:
	return OpenAIChat.functions(tools).map(func(one: Dictionary) -> Dictionary:
		return (one["function"] as Dictionary).merged({"type": "function", "strict": false}))


func _items_of(turn: Dictionary) -> Array:
	match str(turn.get("role", "")):
		"user":
			return [{"role": "user", "content": _parts(turn.get("content", []))}]
		"assistant":
			var kept: Variant = turn.get("kept")
			if kept is Array and not (kept as Array).is_empty():
				return _sent_back(kept)
			var out: Array = []
			if not str(turn.get("text", "")).is_empty():
				out.append({"role": "assistant", "content": str(turn["text"])})
			for call: Dictionary in turn.get("calls", []):
				out.append({"type": "function_call", "call_id": str(call["id"]),
					"name": str(call["name"]), "arguments": str(call["unread"]) if call.has("unread")
						else JSON.stringify(call.get("input", {}))})
			return out
		"tool":
			var out: Array = []
			for result: Dictionary in turn.get("results", []):
				var blocks: Array = result.get("content", [])
				var words: String = Provider.text_of(blocks)
				if bool(result.get("error", false)):
					words = "Error: " + words
				var output: Variant = words if not words.is_empty() else "(no answer)"
				var pictures: Array = Provider.images_of(blocks)
				if not pictures.is_empty():
					output = ([{"type": "input_text", "text": words}] if not words.is_empty() else []) \
						+ pictures.map(func(one: Dictionary) -> Dictionary: return _picture(one))
				out.append({"type": "function_call_output", "call_id": str(result["id"]),
					"output": output})
			return out
	return []


## A reply's own items, to send back: as they came while every reasoning item
## in them can be (it carries its encrypted content); else without the
## reasoning, and without the ids that would name it.
static func _sent_back(kept: Array) -> Array:
	var whole: bool = kept.all(func(item: Variant) -> bool:
		return not (item is Dictionary) or str((item as Dictionary).get("type", "")) != "reasoning" \
			or not str((item as Dictionary).get("encrypted_content", "")).is_empty())
	if whole:
		return kept
	var out: Array = []
	for item: Variant in kept:
		if item is Dictionary and str((item as Dictionary).get("type", "")) != "reasoning":
			var one: Dictionary = (item as Dictionary).duplicate()
			one.erase("id")
			out.append(one)
	return out


## MCP's blocks as a message's content parts: input_text and input_image.
static func _parts(blocks: Array) -> Array:
	var out: Array = []
	for block: Variant in blocks:
		if not (block is Dictionary):
			continue
		var one: Dictionary = block
		if str(one.get("type", "")) == "image":
			out.append(_picture(one))
		elif not str(one.get("text", "")).is_empty():
			out.append({"type": "input_text", "text": str(one["text"])})
	return out


static func _picture(block: Dictionary) -> Dictionary:
	return {"type": "input_image", "image_url": Provider.data_url(block), "detail": "auto"}


func read(code: int, body: PackedByteArray) -> Reply:
	var reply := Reply.new()
	var parsed: Variant = Provider.parsed(body.get_string_from_utf8())
	var answer: Dictionary = parsed if parsed is Dictionary else {}
	# A response that succeeds says "error": null; one that failed after it
	# began says its error at 200, with status "failed".
	var failed: Variant = answer.get("error")
	if code != 200 or failed is Dictionary or str(answer.get("status", "")) == "failed":
		var said: Dictionary = failed if failed is Dictionary else {}
		reply.error = Provider.refusal(code, str(said.get("message", "")))
		reply.again = Provider.transient(code) if code != 200 \
			else str(said.get("code", "")) in ["server_error", "rate_limit_exceeded"]
		return reply
	if not (answer.get("output") is Array):
		reply.error = "The provider's answer had no output in it."
		reply.again = true
		return reply
	var output: Array = answer["output"]
	var words := PackedStringArray()
	var refused: bool = false
	for raw: Variant in output:
		var item: Dictionary = raw if raw is Dictionary else {}
		match str(item.get("type", "")):
			"message":
				for part: Variant in item.get("content", []) if item.get("content") is Array else []:
					var one: Dictionary = part if part is Dictionary else {}
					if str(one.get("type", "")) == "output_text":
						words.append(str(one.get("text", "")))
					elif str(one.get("type", "")) == "refusal":
						words.append(str(one.get("refusal", "")))
						refused = true
			"function_call":
				var call: Dictionary = {"id": str(item.get("call_id", "")), "name": str(item.get("name", ""))}
				var arguments: Variant = item.get("arguments", "{}")
				var input: Variant = arguments
				if arguments is String:
					input = {} if (arguments as String).strip_edges().is_empty() \
						else Provider.parsed(arguments)
				if input is Dictionary:
					call["input"] = input
				else:
					call["unread"] = str(arguments)
				reply.calls.append(call)
	reply.text = "\n\n".join(words).strip_edges()
	reply.kept = output
	var cut: String = str((answer.get("incomplete_details") as Dictionary).get("reason", "")) \
		if answer.get("incomplete_details") is Dictionary else ""
	reply.stop = "tools" if not reply.calls.is_empty() else "refused" if refused \
		or cut == "content_filter" else "length" if cut == "max_output_tokens" else "end"
	var usage: Dictionary = answer.get("usage", {}) if answer.get("usage") is Dictionary else {}
	var details: Dictionary = usage.get("input_tokens_details", {}) \
		if usage.get("input_tokens_details") is Dictionary else {}
	reply.spend.cached = int(details.get("cached_tokens", 0))
	reply.spend.fresh = maxi(0, int(usage.get("input_tokens", 0)) - reply.spend.cached)
	reply.spend.made = int(usage.get("output_tokens", 0))
	reply.ok = true
	return reply
