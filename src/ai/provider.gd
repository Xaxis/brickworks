## One model provider's chat API, as the designer loop needs it.
##
## The loop (DesignerLoop) speaks to every provider the same way: a system
## prompt, the app's tools as MCP lists them, and a transcript of turns in one
## shape of its own. An adapter turns that into one provider's request and
## reads its reply back into the same shape. Anthropic's Messages, OpenAI's
## Chat Completions and Responses, and Google's Gemini each differ in where
## the tools go, how a call and its answer are paired, and whether a picture
## may sit in a tool's answer; all of that is the adapter's and nothing else's.
##
## The transcript, oldest first:
##
##   {"role": "user", "content": [block, …]}
##   {"role": "assistant", "text": "…", "calls": [{"id", "name", "input"}],
##       "kept": <the provider's own, sent back as it came: reasoning items,
##                thought signatures>}
##   {"role": "tool", "results": [{"id", "name", "content": [block, …],
##       "error": bool}]}
##
## A block is MCP's own content block, as CommandSocket.answer_rpc answers:
## {"type": "text", "text"} or {"type": "image", "data": base64, "mimeType"}.
## So a tool's answer goes into the transcript exactly as the app gave it.
##
## The person's key is held here for the length of a run and goes nowhere
## but the provider's own address (ProviderSettings says whose and where).
class_name Provider
extends RefCounted

## The model, by the provider's own id ("gpt-6.1-sol").
var model: String = ""
## Where requests go, without the endpoint's own path: "https://api.openai.com/v1".
var base_url: String = ""
## The person's key; empty for a server on this machine that takes none.
var key: String = ""
## What the person set beyond the model: {"reasoning_effort": "high",
## "temperature": 0.2, "max_out": 32000}. Only what is set is sent.
var params: Dictionary = {}


## What one reply said, in the transcript's shape.
class Reply extends RefCounted:
	var ok: bool = false
	## What went wrong, in words for the person, when not ok.
	var error: String = ""
	## Whether asking again may help: the connection, a rate limit, the
	## provider's own fault. A refused key or an unknown model will not.
	var again: bool = false
	var text: String = ""
	## [{"id", "name", "input"}], input a Dictionary, or {"id", "name",
	## "unread": "<what came>"} when the arguments were not a JSON object.
	var calls: Array = []
	## The provider's own, to send back with this turn (Provider docs above).
	var kept: Variant = null
	## "tools" (it called some), "end" (it has finished), "length" (cut off
	## by the output limit) or "refused" (a content filter).
	var stop: String = "end"
	var spend := Brain.Spend.new()


## The request for one turn: {url, headers (PackedStringArray), body (String)}.
## [param tools] as MCP's tools/list gives them.
func request(_system: String, _tools: Array, _turns: Array) -> Dictionary:
	return {}


## Its reply, read. [param code] is the HTTP status, 0 when no answer came.
func read(_code: int, _body: PackedByteArray) -> Reply:
	var reply := Reply.new()
	reply.error = "this provider has no adapter yet"
	return reply


## What a person is told of a refusal, by HTTP status, when the provider's
## own words say nothing better.
static func refusal(code: int, said: String) -> String:
	var words: String = {
		0: "No answer came from the provider",
		400: "The provider refused the request",
		401: "The provider refused the key",
		403: "The key is not allowed to use this model",
		404: "The provider does not know this model, or the address is wrong",
		408: "The provider took too long",
		413: "The request is bigger than the provider takes",
		429: "The provider says too many requests, or the account is out of credit",
	}.get(code, "The provider answered %d" % code if code < 500
		else "The provider had a fault of its own (%d)" % code)
	return words + (": " + said.strip_edges().left(300) if not said.strip_edges().is_empty() else ".")


## Whether a refusal with [param code] may pass if asked again.
static func transient(code: int) -> bool:
	return code == 0 or code == 408 or code == 429 or code >= 500


## The text of [param blocks], joined.
static func text_of(blocks: Array) -> String:
	var out := PackedStringArray()
	for block: Variant in blocks:
		if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
			out.append(str((block as Dictionary).get("text", "")))
	return "\n\n".join(out)


## The pictures in [param blocks].
static func images_of(blocks: Array) -> Array:
	return blocks.filter(func(block: Variant) -> bool:
		return block is Dictionary and str((block as Dictionary).get("type", "")) == "image")


## [param text] as JSON, or null, quietly: a refusal's empty body and a weaker
## model's broken arguments are expected here, and JSON.parse_string says each
## in the console as an engine error, which buries anything real.
static func parsed(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


## A picture block as a data: address.
static func data_url(block: Dictionary) -> String:
	return "data:%s;base64,%s" % [str(block.get("mimeType", "image/png")), str(block.get("data", ""))]


## base_url and [param path] with one slash between them.
func address(path: String) -> String:
	return base_url.strip_edges().trim_suffix("/") + "/" + path.trim_prefix("/")
