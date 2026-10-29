## Can this model design here? Two real, minimal calls to find out.
##
## A design is nothing but tool calls, and the app's eyes (view_model, and the
## fresh look at a new design's first save) are pictures. A provider's
## listing seldom says whether a model has either, so Settings, AI's Test
## asks the model itself, through the same adapter a design would use
## (Provider), with the person's own key and settings:
##
##   1. one tool and a request to call it: tools work when a call to it
##      comes back;
##   2. a small picture of one colour and a request to name it: pictures work
##      when the right colour comes back. Six colours to choose from, so a
##      model that cannot see and guesses is seldom right.
##
## Two requests, not one, so a model the provider refuses pictures for is
## still found to call tools. Each is a few hundred tokens: less than a cent.
class_name ModelTest
extends Node

## The colours the picture may be, by the word the model should answer.
const COLOURS: Dictionary = {"red": Color(0.86, 0.1, 0.1), "green": Color(0.1, 0.65, 0.2),
	"blue": Color(0.1, 0.25, 0.9), "yellow": Color(0.98, 0.85, 0.1),
	"black": Color(0.02, 0.02, 0.02), "white": Color(0.98, 0.98, 0.98)}
const TOOL := "record_answer"
## Seconds each request may take: a reasoning model at high effort thinks.
var timeout: float = 120.0


## Ask [param provider]'s model. {ok, tools, pictures, words, detail}: ok
## when the provider answered at all; words the line the panel shows
## ("tools ✓, pictures ✗: …"); detail what came back, in words.
func run(provider: Provider) -> Dictionary:
	var tools: Dictionary = await _tools(provider)
	var pictures: Dictionary = await _pictures(provider)
	var out: Dictionary = {"ok": bool(tools["answered"]) or bool(pictures["answered"]),
		"tools": bool(tools["works"]), "pictures": bool(pictures["works"])}
	if not bool(tools["answered"]) and not bool(pictures["answered"]) \
			and str(tools["said"]) == str(pictures["said"]):
		# The same refusal twice (a wrong key, an unknown model): said once.
		out["words"] = str(tools["said"])
		out["detail"] = ""
		return out
	out["words"] = summary(out["tools"], out["pictures"])
	out["detail"] = " ".join(PackedStringArray([str(tools["said"]), str(pictures["said"])])).strip_edges()
	return out


## The line the panel shows for what Test found.
static func summary(tools: bool, pictures: bool) -> String:
	var marks: String = "tools %s, pictures %s" % [mark(tools), mark(pictures)]
	if not tools:
		return marks + ": this model cannot design here, since a design is all tool calls"
	if not pictures:
		return marks + ": fresh eyes and view_model won't work with this model"
	return marks + ": this model can design here"


## A tick or a cross, where the font draws them. The app's font has neither,
## and on the desktop the system's fonts fill in; a browser's page has no
## such fallback, so there it is words.
static func mark(yes: bool) -> String:
	if OS.has_feature("web"):
		return "yes" if yes else "no"
	return "✓" if yes else "✗"


func _tools(provider: Provider) -> Dictionary:
	var tool: Dictionary = {"name": TOOL, "description": "Record your answer to the person's question.",
		"inputSchema": {"type": "object", "properties": {"answer": {"type": "string",
			"description": "The answer, in one word."}}, "required": ["answer"]}}
	var reply: Provider.Reply = await _ask(provider, "Answer by calling the tool, not in words.",
		[tool], [{"role": "user", "content": [{"type": "text",
			"text": "Call %s with the answer \"ready\"." % TOOL}]}])
	if not reply.ok:
		return {"answered": false, "works": false, "said": reply.error}
	for call: Dictionary in reply.calls:
		if str(call.get("name", "")) == TOOL:
			return {"answered": true, "works": true, "said": ""}
	return {"answered": true, "works": false, "said": "Asked to call a tool, it answered in words%s."
		% (": \"%s\"" % reply.text.left(80) if not reply.text.is_empty() else "")}


func _pictures(provider: Provider) -> Dictionary:
	var names: Array = COLOURS.keys()
	var colour: String = str(names[randi() % names.size()])
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(COLOURS[colour])
	var picture: Dictionary = {"type": "image", "mimeType": "image/png",
		"data": Marshalls.raw_to_base64(image.save_png_to_buffer())}
	var reply: Provider.Reply = await _ask(provider, "Answer in one word.", [],
		[{"role": "user", "content": [{"type": "text", "text": ("What colour is this picture? "
			+ "Answer with one word: %s." % ", ".join(PackedStringArray(names)))}, picture]}])
	if not reply.ok:
		return {"answered": false, "works": false,
			"said": "Sent a picture, the provider answered: %s" % reply.error}
	# By whole words: "coloured" holds "red".
	var words: Array = RegEx.create_from_string("[a-z]+").search_all(reply.text.to_lower()).map(
		func(found: RegExMatch) -> String: return found.get_string())
	var named: Array = names.filter(func(one: String) -> bool: return words.has(one))
	if named == [colour]:
		return {"answered": true, "works": true, "said": ""}
	return {"answered": true, "works": false, "said": "Shown a %s square, it said \"%s\"."
		% [colour, reply.text.left(60)]}


## One request through [param provider]'s adapter: its reply, read.
func _ask(provider: Provider, system: String, tools: Array, turns: Array) -> Provider.Reply:
	var asked: Dictionary = provider.request(system, tools, turns)
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)
	var answer: Array = [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
	if http.request(str(asked["url"]), asked["headers"], HTTPClient.METHOD_POST,
			str(asked["body"])) == OK:
		answer = await http.request_completed
	http.queue_free()
	return provider.read(int(answer[1]) if int(answer[0]) == HTTPRequest.RESULT_SUCCESS else 0,
		answer[3])


## The provider's models: read_models' {ok, error, models}.
func models(provider: Provider) -> Dictionary:
	var asked: Dictionary = provider.models_request()
	if asked.is_empty():
		return {"ok": false, "error": "This provider cannot list its models.", "models": []}
	var http := HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	var answer: Array = [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
	if http.request(str(asked["url"]), asked["headers"]) == OK:
		answer = await http.request_completed
	http.queue_free()
	return provider.read_models(int(answer[1]) if int(answer[0]) == HTTPRequest.RESULT_SUCCESS
		else 0, answer[3])
