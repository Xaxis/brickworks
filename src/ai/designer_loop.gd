## Designing with any provider's model, on the person's own key.
##
## Claude designs here as a client of the app's MCP tools: claude.ai through
## the connector, or Claude Code on this machine through the port (ClaudeCode).
## This is the same client, in the app, for every other model: it asks the
## app's own MCP server (CommandSocket.answer_rpc, in process: no port, no
## relay) for its instructions and its tools, hands them to the provider
## (Provider, one adapter per API), runs each call the model makes through
## answer_rpc exactly as a call from Claude runs, and hands the answers back,
## until the model stops calling. So the model is given what Claude is given,
## word for word and tool for tool, and the app answers it as it answers
## Claude: the fresh look at a new design's first save (FreshEyes) included.
## No Claude path changes for it.
##
## Desktop first: the requests go from this machine to the provider's own
## address, with the key the person gave (ProviderSettings). The web build
## can run the same loop where the provider answers a page (docs/PROVIDERS.md
## says which do).
class_name DesignerLoop
extends Node

## Said as it works, for the chat panel or a log.
signal progress(note: String)
## What the model wrote back in words.
signal said(text: String)
## ok, and a sentence about how it went.
signal finished(ok: bool, summary: String)

## What the app's MCP server is, in process.
var rpc: CommandSocket
## Who designs.
var provider: Provider
## Replies a design may take: a design from outside makes 70 to 200 calls
## (docs/BRICKBENCH.md), several to a reply when the model calls in parallel.
var most_replies: int = 200
## Pictures kept in the conversation. Every view_model is three, and every
## one is sent again with every request after it; past twice this many, all
## but the newest this many are taken out at once, so the start of the
## conversation, which a provider caches, changes seldom.
var keep_pictures: int = 6
## Characters the conversation may run to before the older answers are cut
## short (a token is about four). The app's tools alone are about 42,000
## tokens; a model with less room than this needs a smaller figure.
var most_chars: int = 1_000_000
## Times a refusal that may pass (a dropped connection, a rate limit, the
## provider's own fault) is asked again.
var tries: int = 4
## Seconds one reply may take: a reasoning model at high effort thinks for
## minutes before it answers.
var reply_timeout: float = 600.0

## What the model is told before the app's own instructions. The model is
## not Claude Code, which brings a frame of its own: this is the least of
## one, and the instructions below it are the app's, as every client gets.
const FRAME := ("You design a LEGO® model in Brickworks, an app open on the person's "
	+ "computer, through the app's tools: what you build appears in their window as you go. "
	+ "The person's request is the first message. Work through the tools as the app's "
	+ "instructions below say, and keep on until the model is built, looked over and saved "
	+ "with save_model. Then answer in two or three sentences saying what you built, with no "
	+ "tool call: that ends the design.")

var _turns: Array = []
var _system: String = ""
var _tools: Array = []
var _running: bool = false
var _replies: int = 0
var _calls: int = 0
var _spend := Brain.Spend.new()
## The request in the air, one of its own each time: a stopped run's request
## is freed, never reused, so its reply cannot reach the next run.
var _http: HTTPRequest = null
## Which run is current: every wait of a run checks it is still this one.
var _run_number: int = 0
var _next_id: int = 0
var _job_line := RegEx.create_from_string("^(Started job|The app is busy with job) (\\d+)")


## True while a design runs.
func busy() -> bool:
	return _running


## Start one, on [member provider], through [member rpc]. Finishes with
## [signal finished], as ClaudeCode does.
func design(brief: String) -> void:
	if _running:
		return
	if provider == null or rpc == null:
		await get_tree().process_frame
		finished.emit(false, "No provider is chosen.")
		return
	_running = true
	_run_number += 1
	var run: int = _run_number
	_replies = 0
	_calls = 0
	_spend = Brain.Spend.new()
	_turns = []
	# A frame first: the app answers initialize and tools/list at once, so
	# the first word below was said before the panel, which follows the run
	# as this returns (Main), was listening.
	await get_tree().process_frame
	if not _live(run):
		return
	var hello: Dictionary = await _ask_app("initialize", {
		"protocolVersion": CommandSocket.PROTOCOL, "capabilities": {},
		"clientInfo": {"name": "brickworks-designer", "version": "1"}})
	var listed: Dictionary = await _ask_app("tools/list", {})
	if not _live(run):
		return
	_tools = listed.get("tools", []) if listed.get("tools") is Array else []
	if _tools.is_empty():
		_end(false, "The app served no tools.")
		return
	_system = FRAME + "\n\n" + str(hello.get("instructions", ""))
	_turns.append({"role": "user", "content": [{"type": "text", "text": brief}]})
	progress.emit("%s is reading the brief" % who())
	await _run(run)


## Stop, as soon as the reply or call in hand ends. What is built stays.
func stop() -> void:
	if not _running:
		return
	if _http != null:
		_http.cancel_request()
		_http.queue_free()
		_http = null
	_end(false, "stopped")


## Who designs, by the name a person knows the model by ("GPT-6.1 Sol"):
## the history's steps and the toolbar say it (docs/PROVIDERS.md, P8).
func who() -> String:
	return ProviderSettings.model_name(provider.model) if provider != null else ""


## The toolbar's line while it designs, as ClaudeTabView.badge gives Claude's
## chats: [text, colour, tooltip].
func badge() -> Array:
	return ["%s working" % who(), ClaudeTabView.WORKING,
		"%s is designing in this window, on your own key. Stop is on its card in the "
			% who() + "assistant's column."]


## Tokens spent so far, as the provider reports them.
func spent() -> Brain.Spend:
	return _spend


## Replies the model has made so far.
func replies() -> int:
	return _replies


## Tool calls the app has answered so far.
func calls() -> int:
	return _calls


## The conversation so far, in the transcript's shape (Provider), for a
## probe or a log.
func transcript() -> Array:
	return _turns


## Whether run [param run] is still the one going.
func _live(run: int) -> bool:
	return _running and run == _run_number


func _run(run: int) -> void:
	while _live(run):
		if _replies >= most_replies:
			_end(false, "Stopped after %d replies with the model still going." % _replies)
			return
		_trim()
		var reply: Provider.Reply = await _reply(run)
		if not _live(run):
			return
		if not reply.ok:
			_end(false, reply.error)
			return
		_replies += 1
		_spend.fresh += reply.spend.fresh
		_spend.cached += reply.spend.cached
		_spend.made += reply.spend.made
		_turns.append({"role": "assistant", "text": reply.text, "calls": reply.calls,
			"kept": reply.kept})
		if not reply.text.is_empty():
			said.emit(reply.text)
		if reply.calls.is_empty():
			match reply.stop:
				"length":
					_end(false, "The model's reply was cut off by its output limit.")
				"refused":
					_end(false, "The provider's content filter stopped the reply.")
				_:
					_end(true, reply.text if not reply.text.is_empty() else "finished")
			return
		var results: Array = []
		for call: Dictionary in reply.calls:
			var answered: Dictionary = await _answer(call)
			if not _live(run):
				return
			results.append(answered)
		_turns.append({"role": "tool", "results": results})


## One reply from the provider, asked again while its refusal may pass.
func _reply(run: int) -> Provider.Reply:
	var reply: Provider.Reply = null
	for attempt: int in tries:
		if attempt > 0:
			progress.emit("%s; asking again" % reply.error.left(120))
			await get_tree().create_timer(2.0 * pow(2.0, attempt - 1)).timeout
			if not _live(run):
				return reply
		var asked: Dictionary = provider.request(_system, _tools, _turns)
		var http := HTTPRequest.new()
		http.timeout = reply_timeout
		add_child(http)
		_http = http
		var reply_raw: Array = [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(),
			PackedByteArray()]
		if http.request(str(asked["url"]), asked["headers"], HTTPClient.METHOD_POST,
				str(asked["body"])) == OK:
			reply_raw = await http.request_completed
		if _http == http:
			_http = null
			http.queue_free()
		var code: int = int(reply_raw[1]) if int(reply_raw[0]) == HTTPRequest.RESULT_SUCCESS else 0
		reply = provider.read(code, reply_raw[3])
		if reply.ok or not reply.again:
			return reply
	return reply


## One call the model made, answered by the app as a call from Claude is.
func _answer(call: Dictionary) -> Dictionary:
	var name: String = str(call.get("name", ""))
	var answered: Dictionary = {"id": call["id"], "name": name}
	if call.has("unread"):
		answered["content"] = [{"type": "text", "text": ("The arguments were not one JSON "
			+ "object: %s. Call %s again with its arguments as one JSON object."
			% [str(call["unread"]).left(200), name])}]
		answered["error"] = true
		return answered
	progress.emit(name.replace("_", " "))
	var result: Dictionary = await _call_app(name, call.get("input", {}))
	var content: Array = result.get("content", []) if result.get("content") is Array else []
	# A call the app made a job (ToolJobs): waited for here, so the model is
	# handed the call's own answer and spends no turns asking after it.
	var job: RegExMatch = _job_line.search(Provider.text_of(content))
	if job != null:
		var done: Dictionary = await _wait_for(int(job.get_string(2)))
		if job.get_string(1) == "Started job":
			result = done
		else:
			result = await _call_app(name, call.get("input", {}))
		content = result.get("content", []) if result.get("content") is Array else []
	_calls += 1
	answered["content"] = content if not content.is_empty() \
		else [{"type": "text", "text": "(no answer)"}]
	answered["error"] = bool(result.get("isError", false))
	return answered


## The job tool asked until job [param id] has ended: its answer.
func _wait_for(id: int) -> Dictionary:
	var result: Dictionary = {}
	for _n: int in 40:
		progress.emit("waiting for job %d" % id)
		result = await _call_app(ToolJobs.TOOL, {"id": id})
		if not Provider.text_of(result.get("content", [])).contains(") is still going"):
			break
	return result


## A call, named as the model's own: its step in the history and the words
## of its job say who made it (CommandSocket.who_of).
func _call_app(name: String, input: Variant) -> Dictionary:
	return await _ask_app("tools/call", {"name": name,
		"arguments": input if input is Dictionary else {},
		"_meta": {CommandSocket.WHO_KEY: who()}})


## One JSON-RPC request to the app's MCP server: its result, or {} (and an
## isError answer for a call) when it refused.
func _ask_app(method: String, params: Dictionary) -> Dictionary:
	_next_id += 1
	var answer: Variant = await rpc.answer_rpc({"jsonrpc": "2.0", "id": _next_id,
		"method": method, "params": params})
	if answer is Dictionary and (answer as Dictionary).get("result") is Dictionary:
		return (answer as Dictionary)["result"]
	var why: String = str(((answer as Dictionary).get("error", {}) as Dictionary)
		.get("message", "no answer")) if answer is Dictionary else "no answer"
	return {"isError": true, "content": [{"type": "text", "text": why}]}


## The conversation kept to its room: old pictures out, and past
## [member most_chars], the older answers cut short. Done in steps, not a
## little every turn, so what a provider has cached of its start stays.
func _trim() -> void:
	var pictures: Array = []   ## [the blocks array, index] of each picture, oldest first
	for turn: Dictionary in _turns:
		for blocks: Array in _blocks_of(turn):
			for n: int in blocks.size():
				if blocks[n] is Dictionary and str(blocks[n].get("type", "")) == "image":
					pictures.append([blocks, n])
	if pictures.size() > keep_pictures * 2:
		for one: Array in pictures.slice(0, pictures.size() - keep_pictures):
			(one[0] as Array)[int(one[1])] = {"type": "text",
				"text": "(a picture shown earlier, no longer kept)"}
	var size: int = 0
	for turn: Dictionary in _turns:
		for blocks: Array in _blocks_of(turn):
			size += Provider.text_of(blocks).length()
	if size <= most_chars:
		return
	# The newest dozen turns whole; before them every answer to its start.
	for turn: Dictionary in _turns.slice(0, maxi(1, _turns.size() - 12)):
		if str(turn.get("role", "")) != "tool":
			continue
		for result: Dictionary in turn["results"]:
			var text: String = Provider.text_of(result["content"])
			if text.length() > 600:
				result["content"] = [{"type": "text", "text": text.left(400)
					+ " … (cut short: an older answer, kept to its start)"}]


static func _blocks_of(turn: Dictionary) -> Array:
	if turn.get("content") is Array:
		return [turn["content"]]
	var out: Array = []
	for result: Dictionary in turn.get("results", []):
		out.append(result["content"])
	return out


func _end(ok: bool, summary: String) -> void:
	if not _running:
		return
	_running = false
	finished.emit(ok, summary)
