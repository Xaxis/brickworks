## Google's Gemini API, its own (not the OpenAI-compatible endpoint).
##
## POST {base}/models/{model}:generateContent with x-goog-api-key, which a
## page on brickworks.diy may call (docs/PROVIDERS.md, 4.6). Beside
## OpenAIChat for what that endpoint cannot carry: thought signatures, and
## pictures in a function's answer.
##
## Where it differs from the transcript:
##
## - The tools go as one {functionDeclarations: […]}, each MCP inputSchema
##   cut to the OpenAPI subset Gemini takes ("Only a subset of the OpenAPI
##   schema is supported", ai.google.dev/gemini-api/docs/function-calling):
##   additionalProperties and $schema go, and an object with no properties
##   is no parameters at all, which Gemini refuses otherwise.
## - The model's turn is role "model", and its parts come back exactly as they
##   were sent (Reply.kept): a part's thoughtSignature must be "sent back
##   exactly as received".
## - A function's answer is a functionResponse {name, id, response}, and its
##   pictures go in that answer's own parts as inlineData, which Gemini 3 on
##   takes ("you can include multimodal content in the function response
##   parts"): view_model's and the fresh look's pictures reach the model as
##   the call's.
## - A call's id is Gemini's own where it gives one, sent back with the
##   answer; where it gives none, one is made here (MADE) and not sent.
## - Effort is thinkingConfig's thinkingLevel; the most a reply may write is
##   maxOutputTokens.
class_name GeminiNative
extends Provider

## The start of a call id made here, never sent to Gemini.
const MADE := "gemini-call-"

## Schema words Gemini refuses in a function's parameters.
const REFUSED: Array[String] = ["additionalProperties", "$schema", "$id", "$ref", "definitions",
	"$defs", "default", "examples", "const", "patternProperties"]


func request(system: String, tools: Array, turns: Array) -> Dictionary:
	var contents: Array = []
	for turn: Dictionary in turns:
		var content: Dictionary = _content_of(turn)
		if not content.is_empty():
			contents.append(content)
	var body: Dictionary = {"systemInstruction": {"parts": [{"text": system}]},
		"contents": contents}
	if not tools.is_empty():
		body["tools"] = [{"functionDeclarations": declarations(tools)}]
	var config: Dictionary = {}
	if params.has("temperature"):
		config["temperature"] = float(params["temperature"])
	if int(params.get("max_out", 0)) > 0:
		config["maxOutputTokens"] = int(params["max_out"])
	if params.has("reasoning_effort"):
		config["thinkingConfig"] = {"thinkingLevel": str(params["reasoning_effort"])}
	if not config.is_empty():
		body["generationConfig"] = config
	return {"url": address("models/%s:generateContent" % model.trim_prefix("models/")),
		"headers": headers(), "body": JSON.stringify(body)}


func headers() -> PackedStringArray:
	return PackedStringArray(["content-type: application/json", "x-goog-api-key: " + key])


## MCP's tools as Gemini's function declarations.
static func declarations(tools: Array) -> Array:
	var out: Array = []
	for tool: Variant in tools:
		var one: Dictionary = tool
		var declared: Dictionary = {"name": str(one.get("name", "")),
			"description": str(one.get("description", ""))}
		var schema: Variant = one.get("inputSchema", one.get("input_schema", {}))
		if schema is Dictionary and not ((schema as Dictionary).get("properties", {}) as Dictionary).is_empty():
			declared["parameters"] = subset(schema)
		out.append(declared)
	return out


## [param schema] with what Gemini refuses taken out, all the way down.
static func subset(schema: Variant) -> Variant:
	if schema is Array:
		return (schema as Array).map(func(one: Variant) -> Variant: return subset(one))
	if not (schema is Dictionary):
		return schema
	var out: Dictionary = {}
	for word: Variant in schema:
		if REFUSED.has(str(word)):
			continue
		if str(word) == "properties" and schema[word] is Dictionary:
			var properties: Dictionary = {}
			for name: Variant in schema[word]:
				properties[name] = subset(schema[word][name])
			out[word] = properties
		else:
			out[word] = subset(schema[word])
	return out


func _content_of(turn: Dictionary) -> Dictionary:
	match str(turn.get("role", "")):
		"user":
			return {"role": "user", "parts": _parts(turn.get("content", []))}
		"assistant":
			# As it came: thought signatures with their parts.
			if turn.get("kept") is Array and not (turn["kept"] as Array).is_empty():
				return {"role": "model", "parts": turn["kept"]}
			var parts: Array = []
			if not str(turn.get("text", "")).is_empty():
				parts.append({"text": str(turn["text"])})
			for call: Dictionary in turn.get("calls", []):
				var asked: Dictionary = {"name": str(call["name"]), "args": call.get("input", {})}
				if not str(call["id"]).begins_with(MADE):
					asked["id"] = str(call["id"])
				parts.append({"functionCall": asked})
			return {"role": "model", "parts": parts if not parts.is_empty() else [{"text": "(nothing)"}]}
		"tool":
			var parts: Array = []
			for result: Dictionary in turn.get("results", []):
				var blocks: Array = result.get("content", [])
				var words: String = Provider.text_of(blocks)
				var answer: Dictionary = {"name": str(result.get("name", "")),
					"response": {"error" if bool(result.get("error", false)) else "result":
						words if not words.is_empty() else "(no answer)"}}
				if not str(result["id"]).begins_with(MADE):
					answer["id"] = str(result["id"])
				var pictures: Array = []
				var n: int = 0
				for picture: Dictionary in Provider.images_of(blocks):
					n += 1
					pictures.append({"inlineData": {"mimeType": str(picture.get("mimeType", "image/png")),
						"data": str(picture.get("data", "")),
						"displayName": "%s-%d.png" % [str(result.get("name", "picture")), n]}})
				if not pictures.is_empty():
					answer["parts"] = pictures
				parts.append({"functionResponse": answer})
			return {"role": "user", "parts": parts}
	return {}


## MCP's blocks as Gemini's parts.
static func _parts(blocks: Array) -> Array:
	var out: Array = []
	for block: Variant in blocks:
		if not (block is Dictionary):
			continue
		var one: Dictionary = block
		if str(one.get("type", "")) == "image":
			out.append({"inlineData": {"mimeType": str(one.get("mimeType", "image/png")),
				"data": str(one.get("data", ""))}})
		elif not str(one.get("text", "")).is_empty():
			out.append({"text": str(one["text"])})
	return out


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
	var candidates: Array = answer.get("candidates", []) if answer.get("candidates") is Array else []
	if candidates.is_empty():
		var blocked: String = str((answer.get("promptFeedback", {}) as Dictionary).get("blockReason", "")) \
			if answer.get("promptFeedback") is Dictionary else ""
		if not blocked.is_empty():
			reply.ok = true
			reply.stop = "refused"
			return reply
		reply.error = "The provider's answer had no candidate in it."
		reply.again = true
		return reply
	var candidate: Dictionary = candidates[0] if candidates[0] is Dictionary else {}
	var content: Dictionary = candidate.get("content", {}) if candidate.get("content") is Dictionary else {}
	var parts: Array = content.get("parts", []) if content.get("parts") is Array else []
	var words := PackedStringArray()
	for raw: Variant in parts:
		var part: Dictionary = raw if raw is Dictionary else {}
		if part.has("functionCall") and part["functionCall"] is Dictionary:
			var asked: Dictionary = part["functionCall"]
			var id: String = str(asked.get("id", ""))
			var call: Dictionary = {"id": id if not id.is_empty() else MADE + str(reply.calls.size() + 1),
				"name": str(asked.get("name", ""))}
			var args: Variant = asked.get("args", {})
			if args is Dictionary:
				call["input"] = args
			else:
				call["unread"] = JSON.stringify(args)
			reply.calls.append(call)
		elif part.has("text") and not bool(part.get("thought", false)):
			words.append(str(part["text"]))
	reply.text = "\n\n".join(words).strip_edges()
	reply.kept = parts
	var finish: String = str(candidate.get("finishReason", ""))
	reply.stop = "tools" if not reply.calls.is_empty() else "length" if finish == "MAX_TOKENS" \
		else "refused" if finish in ["SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "RECITATION", "SPII"] \
		else "end"
	var usage: Dictionary = answer.get("usageMetadata", {}) if answer.get("usageMetadata") is Dictionary else {}
	reply.spend.cached = int(usage.get("cachedContentTokenCount", 0))
	reply.spend.fresh = maxi(0, int(usage.get("promptTokenCount", 0)) - reply.spend.cached)
	reply.spend.made = int(usage.get("candidatesTokenCount", 0)) + int(usage.get("thoughtsTokenCount", 0))
	reply.ok = true
	return reply


func models_request() -> Dictionary:
	var out: PackedStringArray = headers()
	out.remove_at(0)
	return {"url": address("models?pageSize=1000"), "headers": out}


## The models that generate content; Gemini's list says nothing of tools or
## pictures, which Test finds out.
func read_models(code: int, body: PackedByteArray) -> Dictionary:
	var parsed: Variant = Provider.parsed(body.get_string_from_utf8())
	var answer: Dictionary = parsed if parsed is Dictionary else {}
	if code != 200 or not (answer.get("models") is Array):
		var said: Variant = answer.get("error", {})
		return {"ok": false, "models": [], "error": Provider.refusal(code,
			str((said as Dictionary).get("message", "")) if said is Dictionary else str(said))}
	var models: Array = []
	for raw: Variant in answer["models"]:
		if not (raw is Dictionary):
			continue
		var one: Dictionary = raw
		var methods: Variant = one.get("supportedGenerationMethods", [])
		if methods is Array and not (methods as Array).is_empty() \
				and not (methods as Array).has("generateContent"):
			continue
		var id: String = str(one.get("name", "")).trim_prefix("models/")
		if not id.is_empty():
			var model: Dictionary = Provider.listed(id, str(one.get("displayName", "")))
			if bool(one.get("thinking", false)):
				model["params"] = ["reasoning", "temperature"]
			models.append(model)
	return {"ok": true, "error": "", "models": models}


func efforts() -> Array:
	return ["low", "high"]
