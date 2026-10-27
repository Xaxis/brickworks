## A way in for a session that is not the one inside the app.
##
## The app already holds a design loop: a model proposes placements, the
## real catalogue and the real collision lattice answer, and what holds
## together goes on the baseplate. All of that is reachable through
## [method Assistant.use_tool]. The only thing tying it to Anthropic is
## who is calling.
##
## So this listens on a local port and hands the same tools to whoever
## connects — in practice a Claude Code session, through
## [code]tools/brickworks_mcp.py[/code], which speaks MCP on its stdin
## and relays to here. A person with a session already open then builds
## in Brickworks without pasting an API key into it, and watches the
## bricks land in the window while they do.
##
## Deliberately small: one JSON object per line, in and out.
##
##   in   {"id": 7, "tool": "search_parts", "input": {"query": "wedge"}}
##   out  {"id": 7, "ok": true, "content": [{"type": "text", ...}]}
##   out  {"id": 7, "ok": false, "error": "..."}
##
## [code]{"tool": "__tools__"}[/code] answers with the tool list and
## [code]{"tool": "__about__"}[/code] with how to design well here, so
## the relay never carries a copy of either that could go stale.
##
## 127.0.0.1 only, and off unless asked for. An open port that drives the
## app is not something to have running by default, and binding the
## wildcard address would offer it to the network.
class_name CommandSocket
extends Node

## Where it listens when no port is given. Chosen high and odd enough to
## be nobody else's default; parallel sessions should pass their own.
const PORT := 8787

## A line longer than this is a client that is not speaking the protocol.
## Without a ceiling, a stray stream of bytes with no newline in it grows
## the buffer until the app dies.
const LONGEST_LINE := 1 << 22

## Raised when a client connects or leaves, so the window can say so.
signal attached(how_many: int)

## What a client asked for, for the status line. Not the answer: an
## answer can be a megabyte of PNG.
signal asked(tool: String)

var assistant: Assistant
## The app itself, for the two things only it can do.
var app: Node = null

## Calls from outside at their work now, on any socket (the port's, and the
## web connector's). What one puts down is the session's, and Main shows it
## whole rather than assembling it (BuildPlayback), so the model on screen
## is the one the answer describes. A design Claude submitted to a tab in
## view went on going up for 2.5 s after Claude was told it was built: on a
## graphics card that is 150 frames (tools/web/arrival_check.mjs, 2026-10-13).
static var _at_work: int = 0


## Whether a call from outside is at its work now.
static func at_work() -> bool:
	return _at_work > 0

## One connection, with everything about it in one place.
##
## Held as objects rather than as parallel arrays indexed by position.
## Position is not stable: a client that goes while another is mid-tool
## shifts every index after it, and the answer to the request in flight
## is then written to whoever moved into that slot — a picture of the
## model arriving on a connection that asked for a search, and nothing
## at all arriving on the one that is waiting.
class Client extends RefCounted:
	var peer: StreamPeerTCP
	var buffer := PackedByteArray()
	## Decided from the first bytes and never revisited: a line of JSON
	## begins with a brace, an HTTP request with a verb. One port serves
	## both, so a shipped app needs no helper process to be an MCP
	## server and the shell tools keep the protocol they had.
	var speaks_http: bool = false
	var decided: bool = false
	## True while a tool is still being awaited for this client. A tool
	## may take seconds — fetching geometry, drawing a picture — and a
	## second request arriving meanwhile must not be answered first.
	var busy: bool = false
	## Set when the connection has gone, so a tool that finishes after
	## that has something to check rather than writing into nothing.
	var gone: bool = false


var _server := TCPServer.new()
var _clients: Array[Client] = []
var _port := PORT

## One tool at a time, across every client.
##
## Each client already answers its own requests in order. That is not
## enough: a session may open several connections and send a call down
## each at the same moment — Claude Code does, three look_at_model in
## one breath — and the app is one app. One baseplate, one lattice, one
## thing that takes pictures. Two picture takers sharing a viewport
## interleave their waits and at least one never gets the frame it was
## waiting for, so its call sits there until the relay gives up three
## minutes later. That is not a hypothetical: a real design run of the
## USS Voyager reported "the renderer keeps timing out" and spent its
## last ten minutes unable to look at what it had built.
var _in_hand: int = 0
## How long a queued call will wait before saying so. The relay gives up
## at three minutes, and a message is better than its silence. A
## variable rather than a constant so that a probe can shorten it:
## waiting a hundred seconds to watch a deadline fire is not a check
## anybody will run.
var queued_for: float = 100.0


## Start listening. Returns false, and says why, when the port is taken —
## which on this machine usually means another session got there first.
func listen(port: int = PORT) -> bool:
	_port = port
	var error: Error = _server.listen(port, "127.0.0.1")
	if error != OK:
		push_error("command socket: port %d is not available (%s). " % [
			port, error_string(error)]
			+ "Another Brickworks is probably listening; pass --mcp=PORT.")
		return false
	print("command socket: listening on 127.0.0.1:%d" % port)
	return true


func stop() -> void:
	for client: Client in _clients:
		client.gone = true
		client.peer.disconnect_from_host()
	_clients.clear()
	_server.stop()


func port() -> int:
	return _port


func _process(_delta: float) -> void:
	if not _server.is_listening():
		return
	while _server.is_connection_available():
		var client := Client.new()
		client.peer = _server.take_connection()
		# Nagle's algorithm batches small writes, which for a protocol
		# of one small line per answer means the answer sits in a buffer
		# until something else is sent.
		client.peer.set_no_delay(true)
		_clients.append(client)
		attached.emit(_clients.size())
	for i in range(_clients.size() - 1, -1, -1):
		var client: Client = _clients[i]
		if not _pump(client):
			client.gone = true
			_clients.remove_at(i)
			attached.emit(_clients.size())


## Read what a client sent and answer any whole line in it. Returns
## false when the client has gone.
func _pump(client: Client) -> bool:
	client.peer.poll()
	if client.peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var waiting: int = client.peer.get_available_bytes()
	if waiting > 0:
		var got: Array = client.peer.get_data(waiting)
		if got[0] != OK:
			return false
		client.buffer.append_array(got[1])
	if client.buffer.size() > LONGEST_LINE:
		push_error("command socket: a client sent %d bytes with no newline"
			% client.buffer.size())
		return false
	# One at a time, in order. The rest of the buffer waits.
	if client.busy:
		return true

	if not client.decided and client.buffer.size() >= 4:
		var opening: String = client.buffer.slice(0, 8).get_string_from_utf8()
		client.speaks_http = (opening.begins_with("POST ")
			or opening.begins_with("GET ") or opening.begins_with("OPTIONS ")
			or opening.begins_with("HEAD ") or opening.begins_with("DELETE "))
		client.decided = true
	if client.speaks_http:
		return _pump_http(client)

	var newline: int = client.buffer.find(10)
	if newline < 0:
		return true
	var line: String = client.buffer.slice(0, newline).get_string_from_utf8()
	client.buffer = client.buffer.slice(newline + 1)
	if line.strip_edges().is_empty():
		return true
	client.busy = true
	_answer(client, line)
	return true


# -- MCP over HTTP -------------------------------------------------------
#
# The same tools, spoken the way an MCP client expects, so Claude Code
# attaches to the app directly:
#
#   claude --mcp-config '{"mcpServers":{"brickworks":
#     {"type":"http","url":"http://127.0.0.1:8787/mcp"}}}'
#
# One request, one response: every tool here answers once, which is the
# shape the spec calls a plain JSON response rather than an event stream.
# Except when the tools have changed since the session listed them
# (2026-10-13): the app was updated, and the session, still attached to the
# same port, would go on with the old list for good. Each session is handed
# an id at initialize that carries a short hash of the list it was given
# ([method tools_listed]), so even an app started since knows; its next
# request is answered as an event stream with
# notifications/tools/list_changed ahead of the answer, or, for a client
# that takes JSON alone, with the same said in words at the end of a call's
# answer. Once each time.


## A whole request, or nothing yet. Returns false when the client has gone.
##
## Counted in bytes, because Content-Length is. Counted in characters, a
## body with one accented letter in it is one short for ever: the app
## waits for a byte that never comes, and the session that sent it waits
## ten minutes to be told it timed out. That was a tower of Orthanc whose
## notes put "the palantír" on the summit: every call without an accent
## worked, and both submits with one never arrived.
func _pump_http(client: Client) -> bool:
	var blank: int = _find_bytes(client.buffer, "\r\n\r\n")
	var gap: int = 4
	if blank < 0:
		blank = _find_bytes(client.buffer, "\n\n")
		gap = 2
	if blank < 0:
		return true
	var head: String = client.buffer.slice(0, blank).get_string_from_utf8()
	var wanted: int = 0
	for line: String in head.split("\n"):
		var at: String = line.strip_edges().to_lower()
		if at.begins_with("content-length:"):
			wanted = at.split(":")[1].strip_edges().to_int()
	var body_from: int = blank + gap
	if client.buffer.size() - body_from < wanted:
		return true
	var body: String = client.buffer.slice(body_from,
		body_from + wanted).get_string_from_utf8()
	# Whatever came after this request is the start of the next one.
	client.buffer = client.buffer.slice(body_from + wanted)
	client.busy = true
	_serve_http(client, head, body)
	return true


static func _find_bytes(haystack: PackedByteArray, needle: String) -> int:
	var wanted: PackedByteArray = needle.to_ascii_buffer()
	var first: int = wanted[0]
	var at: int = haystack.find(first)
	while at >= 0 and at + wanted.size() <= haystack.size():
		if haystack.slice(at, at + wanted.size()) == wanted:
			return at
		at = haystack.find(first, at + 1)
	return -1


func _serve_http(client: Client, head: String, body: String) -> void:
	var first: String = head.split("\n")[0].strip_edges()
	var session: String = _header(head, "mcp-session-id")
	var streams: bool = _header(head, "accept").contains("text/event-stream")
	if _from_a_web_page(head):
		_http(client, 403, JSON.stringify({"error": "This port is for programs "
			+ "on this computer, such as Claude Code. Web pages may not use it."}))
		return
	if first.begins_with("OPTIONS"):
		_http(client, 204, "")
		return
	if first.begins_with("GET") and streams:
		# A client asking for a stream of its own, which the spec answers
		# with 405 when there is none: the word that the tools changed
		# comes with an answer instead.
		_http(client, 405, "")
		return
	if not first.begins_with("POST"):
		# A browser pointed at the port, or a health check.
		_http(client, 200, JSON.stringify({"app": "brickworks",
			"mcp": "post JSON-RPC here"}))
		return

	var parsed: Variant = JSON.parse_string(body)
	if not (parsed is Dictionary):
		_http(client, 400, JSON.stringify({"jsonrpc": "2.0", "id": null,
			"error": {"code": -32700, "message": "not JSON"}}))
		return
	var request: Dictionary = parsed
	var method: String = str(request.get("method", ""))
	var answer: Variant = await answer_rpc(request)
	if answer == null:
		# A notification has no id and wants no answer.
		_http(client, 202, "")
		return
	if client.gone:
		return
	var listed: String = tools_listed()
	if method == "initialize":
		# The id says which list this session is about to be given.
		session = "%s.%s" % [Crypto.new().generate_random_bytes(12).hex_encode(), listed]
		_given[session] = listed
		_http(client, 200, JSON.stringify(answer), "Mcp-Session-Id: %s\r\n" % session)
		return
	if session.is_empty():
		_http(client, 200, JSON.stringify(answer))
		return
	if method == "tools/list":
		_given[session] = listed
		_told[session] = listed
	elif _to_be_told(session, listed) and (streams or method == "tools/call"):
		_told[session] = listed
		if streams:
			_http_events(client, [{"jsonrpc": "2.0", "method": "notifications/tools/list_changed"},
				answer])
			return
		var result: Variant = (answer as Dictionary).get("result")
		if result is Dictionary and (result as Dictionary).get("content") is Array:
			((result as Dictionary)["content"] as Array).append({"type": "text", "text": CHANGED_WORDS})
	_http(client, 200, JSON.stringify(answer))


## Whether a request came from a web page rather than a program here.
##
## The port answered every origin, so any page open in a browser while the
## app listened could drive it — clear the baseplate, or save over a file
## anywhere it liked. A browser puts an Origin on every request a page
## makes and Claude Code, curl and Python put none, so an Origin is the
## page. And a Host that is not this machine is a name pointed at it
## (DNS rebinding), which is a page too.
static func _from_a_web_page(head: String) -> bool:
	for line: String in head.split("\n"):
		var at: String = line.strip_edges().to_lower()
		if at.begins_with("origin:"):
			return true
		if at.begins_with("host:"):
			var host: String = at.substr(5).strip_edges()
			if host.begins_with("["):
				host = host.substr(0, host.find("]") + 1)
			elif host.contains(":"):
				host = host.substr(0, host.find(":"))
			if not host in ["127.0.0.1", "localhost", "[::1]"]:
				return true
	return false


## One JSON-RPC request answered, or null for a notification, which wants
## none. The desktop's HTTP port and the web's connector relay
## (src/net/claude_connector.gd) both come here, so the two cannot answer the
## protocol differently.
func answer_rpc(request: Dictionary) -> Variant:
	var method: String = str(request.get("method", ""))
	var sent_id: Variant = request.get("id")
	var params: Dictionary = request.get("params", {}) as Dictionary
	if sent_id == null:
		return null

	if method == "initialize":
		var wanted: Variant = params.get("protocolVersion")
		return _result(sent_id, {
			"protocolVersion": wanted if wanted is String else PROTOCOL,
			# The list changes when the app is updated: see "MCP over HTTP",
			# and the relay's own (api/mcp.js) for the web.
			"capabilities": {"tools": {"listChanged": true}},
			"serverInfo": {"name": "brickworks", "version": "1"},
			"instructions": assistant.guidance() if assistant != null else "",
		})
	if method == "ping":
		return _result(sent_id, {})
	if method == "tools/list":
		return _result(sent_id, {"tools": served_tools()})
	if method == "tools/call":
		var name: String = str(params.get("name", ""))
		var input: Dictionary = params.get("arguments", {}) as Dictionary
		if name.is_empty() or assistant == null:
			return _result(sent_id, {"isError": true, "content": [
				{"type": "text", "text": "no tool named"}]})
		# The viewer's own, from the card in Claude (ViewerTools): read at
		# once, whoever has the app, and none of the app's tools.
		if ViewerTools.handles(name):
			await _until_whole()
			return _result(sent_id, await _viewer().answer(name, input,
				jobs.running() != null or _in_hand > 0))
		asked.emit(name)
		var call := ToolJobs.Entry.new()
		var called: Array = await _call(name, input, call, chat_of(params))
		if not bool(called[1]):
			return _result(sent_id, {"isError": true, "content": [
				{"type": "text", "text": QUEUED_OUT}]})
		var content: Array = _as_content(called[0])
		# A run kept to a list of parts (PartsOnly): whatever laid a part off
		# it, the session hears of it after the call that left it there.
		var barred: String = PartsOnly.on_model(assistant.world, assistant.scenery,
			assistant.library)
		if not barred.is_empty():
			content.append({"type": "text", "text": barred})
		# A newer build is live than this tab's (NewerBuild): Claude is told
		# once, as the person is by the banner.
		if not _told_newer and not NewerBuild.live().is_empty():
			_told_newer = true
			content.append({"type": "text", "text": NEWER_WORDS})
		var result: Dictionary = {"content": content, "isError": false}
		# For a client that shows the model beside the call (ModelViews),
		# asked for by the relay: the content above is the same either way.
		if ModelViews.asked(params):
			var meta: Dictionary = await _viewer_meta(name, input, call)
			if not meta.is_empty():
				result["_meta"] = meta
		return _result(sent_id, result)
	if method in ["resources/list", "prompts/list"]:
		return _result(sent_id, {"resources": [], "prompts": []})
	return {"jsonrpc": "2.0", "id": sent_id,
		"error": {"code": -32601, "message": "no method %s" % method}}


var _views := ModelViews.new()
var _viewer_tools: ViewerTools = null

## Where a call's _meta says which job it is, for the card in Claude: {id,
## tool, done, input (its from and name)}. On the answer that started one,
## so the card beside that call follows it to its end, and on the job
## tool's.
const JOB_KEY := "brickworks/job"


## What a viewer is given with [param name]'s answer (asked for by the
## relay, for a client that shows pages). A call that became a job carries
## nothing of the model yet, only which job; the job tool's answer, once
## the job is done, carries what the call's own would have (ModelViews),
## drawn once for that job. [param call] is the call's own entry: its id is
## set when it became a job.
func _viewer_meta(name: String, input: Dictionary, call: ToolJobs.Entry) -> Dictionary:
	if name == ToolJobs.TOOL:
		var job: ToolJobs.Entry = jobs.asked_about(input)
		if job == null:
			return {}
		var meta: Dictionary = {JOB_KEY: _job_said(job)}
		if job.finished and job.answer != null and ModelViews.TOOLS.has(job.tool):
			if job.shown.is_empty():
				job.shown = await _shown(job.tool)
			if not job.shown.is_empty():
				meta[ModelViews.KEY] = job.shown
		return meta
	if not ModelViews.TOOLS.has(name):
		return {}
	if call.id > 0:
		return {JOB_KEY: _job_said(call)}
	var shown: Dictionary = await _shown(name)
	return {ModelViews.KEY: shown} if not shown.is_empty() else {}


## Of what the call was asked, only what the card shows (the side a picture
## is from, the model's name): a design's bricks are no business of _meta's.
static func _job_said(job: ToolJobs.Entry) -> Dictionary:
	var asked: Dictionary = {}
	for key: String in ["from", "name"]:
		if job.input.get(key) is String:
			asked[key] = job.input[key]
	return {"id": job.id, "tool": job.tool, "done": job.finished, "input": asked}


## What the viewer is shown of the model after [param name]'s call: {} when
## the call became a job (the model is still being built) or the app is
## another call's, rather than wait for it. [param whole]: the turntable,
## for a viewer that cannot draw in 3D.
func _shown(name: String, whole: bool = false) -> Dictionary:
	if assistant == null or jobs.running() != null or _in_hand > 0:
		return {}
	_in_hand += 1
	var shown: Dictionary = await _views.of(assistant, name, whole)
	_hand_back()
	return shown


func _viewer() -> ViewerTools:
	if _viewer_tools == null:
		_viewer_tools = ViewerTools.new()
		_viewer_tools.pictures = func() -> Dictionary: return await _shown("look_at_model", true)
	_viewer_tools.assistant = assistant
	_viewer_tools.app = app
	_viewer_tools.scenes = _views.scene
	return _viewer_tools


var _told_newer: bool = false
const NEWER_WORDS := ("Brickworks has been updated since this tab opened. The tab goes on "
	+ "working, but saves nothing to the person's saved models until it reloads: ask them to "
	+ "press Reload, above the model, when it suits them. The model comes back as it is, and "
	+ "the new version's tools with it.")


static func _result(sent_id: Variant, result: Dictionary) -> Dictionary:
	return {"jsonrpc": "2.0", "id": sent_id, "result": result}


## The tools, as tools/list gives them.
func served_tools() -> Array:
	var listed: Array = []
	for one: Dictionary in catalogue():
		listed.append({
			"name": one.get("name", ""),
			"description": one.get("description", ""),
			"inputSchema": one.get("input_schema", {}),
			"annotations": one.get("annotations", {}),
		})
	return listed


## Every tool a session is served, in the app's own shape, each with its
## MCP annotations ([constant HINTS]): what __tools__ answers, and so what
## tools/mcp_tools.json and tools/brickworks_mcp.py carry.
func catalogue() -> Array:
	var listed: Array = []
	if assistant == null:
		return listed
	for tool: Variant in assistant.tool_catalogue() + _own_tools():
		var one: Dictionary = (tool as Dictionary).duplicate()
		one["annotations"] = annotations(str(one.get("name", "")))
		listed.append(one)
	return listed


## What each tool does to the person's work, said to every client with the
## list as MCP's tool annotations: a title, and whether it only looks
## (readOnlyHint), can take work away (destructiveHint), does no more when
## called twice alike (idempotentHint) and fetches from outside Brickworks
## (openWorldHint). Claude reads them in deciding what to ask the person
## about; what the person has chosen in Claude stands over them. One row
## per tool served — mcp_sync_probe fails on a tool without one — and
## read_only_probe calls every tool that looks and holds it to changing
## nothing. The relay's own two, tabs and select_tab, say theirs in
## api/mcp.js.
##   look    changes nothing: not the model, not a file
##   file    writes a file (a picture, an export); the model is unchanged
##   add     changes the model, taking nothing the person built away
##   remove  can take parts away, or put something in the model's place
## And after the kind: "again", called twice alike it does no more than
## once; "world", it fetches from outside Brickworks.
const HINTS := {
	"search_parts": ["Search the parts", "look"],
	"check_design": ["Check a design", "look"],
	"read_guide": ["Read the design guide", "look"],
	"show_technique": ["Show a technique", "look"],
	"find_techniques": ["Find how real sets built it", "look"],
	"find_parts_like": ["Find parts by their look", "look"],
	"place_technique": ["Place a real set's piece", "add"],
	"settle_feature": ["Settle a feature's piece", "add"],
	"plan_scale": ["Plan the scale", "look"],
	"find_reference": ["Find pictures of the real thing", "look", "world"],
	"how_real_sets_build_this": ["What real sets of its kind use", "look"],
	"attachment_points": ["Where a part attaches", "look"],
	"search_gear_ratio": ["Find a gear train", "look"],
	# Lays the person's plain bricks again as ribs, bands and panels.
	"restyle_model": ["Restyle the walls", "remove"],
	"add_rooms": ["Add furnished rooms", "add"],
	"edit_model": ["Edit the model", "remove"],
	"look_at_model": ["List what is built", "look"],
	"view_model": ["Look at the model", "look"],
	"settle_surface": ["Settle the surface pass", "add"],
	"submit_design": ["Build a design", "remove"],
	"add_minifig": ["Add a minifigure", "add"],
	"make_part": ["Make a new part", "add"],
	# It replaces what is on the baseplate.
	"make_art": ["Lay a picture as Brick Art", "remove"],
	"look_at_picture": ["See the chosen picture", "look"],
	"selection": ["What is selected", "look"],
	"edit_selection": ["Change the selection", "remove"],
	"where_to_attach": ["Where the selection takes a part", "look"],
	"choose_sketch": ["Choose a sketch", "remove"],
	# The feature and surface passes lay pieces, for settle_feature and
	# settle_surface to keep or take off again.
	"review_model": ["Review the model", "add"],
	"clear_model": ["Clear the baseplate", "remove", "again"],
	# A file, and the next feature's piece laid: never over the person's.
	"save_model": ["Save the model", "add"],
	"set_floor": ["Set what it stands on", "add", "again"],
	"edit_steps": ["Edit the build steps", "add"],
	"booklet_layout": ["Read the booklet's pages", "look"],
	"edit_booklet": ["Set how a booklet step is printed", "add"],
	"lay_flex": ["Lay a hose, tube or chain", "add"],
	"pose_model": ["Pose a joint", "add", "again"],
	"move_part": ["Move a part on its joint", "add", "again"],
	"animate_model": ["Animate the model", "add"],
	"list_motions": ["List the model's motions", "look"],
	# Its motions are lines in the model's file: one step to undo.
	"define_motion": ["Keep a motion in the model", "add", "again"],
	"play_motion": ["Play a motion", "add", "again"],
	"render_motion": ["Render a motion", "file"],
	"simulate_mechanism": ["Simulate the mechanism", "file"],
	"undo": ["Undo or redo", "remove"],
	# In place of the model, and with discard_changes its unsaved changes.
	"open_model": ["Open a model", "remove"],
	"parts_list": ["List the parts", "look"],
	"render_model": ["Render a picture", "file"],
	"export_model": ["Export the model", "file"],
	"brickify": ["Brickify a 3D model", "add", "world"],
	"print_part": ["Print on a part", "add", "world"],
	"make_unique": ["Make a copy unique", "add"],
	"suggest_sections": ["Suggest sections", "look"],
	"make_sections": ["Make the sections", "add"],
	# Moves a section's parts away from the model, or back; one step each.
	"break_out_section": ["Break out a section", "add"],
	"evaluate_section": ["Evaluate a section", "look"],
	"weakest_joints": ["Weigh the weakest joints", "look"],
	# Recolours parts nobody sees, after the person says yes; one step.
	"colour_hidden_parts": ["Colour the hidden parts", "add"],
	"gallery": ["Search the gallery", "look", "world"],
	# cancel=true stops only the session's own job.
	"job": ["Follow a long job", "look"],
}
const KINDS: Array[String] = ["look", "file", "add", "remove"]


## [param name]'s annotations, from its row in [constant HINTS]; {} for a
## tool with none.
static func annotations(name: String) -> Dictionary:
	var row: Array = HINTS.get(name, [])
	if row.size() < 2:
		return {}
	var kind: String = str(row[1])
	var said: Dictionary = {"title": str(row[0]), "readOnlyHint": kind == "look",
		"openWorldHint": "world" in row}
	# Meaningful, MCP says, only for a tool that changes something.
	if kind != "look":
		said["destructiveHint"] = kind == "remove"
		said["idempotentHint"] = "again" in row
	return said


## Whether a call to [param name] leaves the model as it was (it looks, or
## writes a file), so no record of the model is taken for it.
static func leaves_the_model(name: String) -> bool:
	var row: Array = HINTS.get(name, [])
	return row.size() >= 2 and str(row[1]) in ["look", "file"]


## Which tools this app serves, in short: a hash of [method served_tools],
## compared and never shown. Worked out once a frame at most.
func tools_listed() -> String:
	var frame: int = Engine.get_process_frames()
	if _listed_on != frame or _listed.is_empty():
		_listed_on = frame
		_listed = JSON.stringify(served_tools()).sha256_text().substr(0, 16)
	return _listed


var _listed: String = ""
var _listed_on: int = -1
## Each HTTP session's list as it was last given it, and as it was last
## told it had changed to, by its id.
var _given: Dictionary = {}
var _told: Dictionary = {}

const CHANGED_WORDS := ("Brickworks has been updated since this session listed its tools, "
	+ "and its tools have changed. List them again to see the new ones; in Claude Code, /mcp "
	+ "reconnects.")


## Whether a session is to be told its tools have changed: the list it was
## given (as its id says, for one this app did not hand out) is not the one
## served now, and it has not been told of this one.
func _to_be_told(session: String, listed: String) -> bool:
	var given: String = str(_given.get(session, session.get_slice(".", 1) if session.contains(".") else ""))
	return not given.is_empty() and given != listed and str(_told.get(session, "")) != listed


## One header's value from a request's head, or "".
static func _header(head: String, name: String) -> String:
	for line: String in head.split("\n"):
		var at: int = line.find(":")
		if at > 0 and line.substr(0, at).strip_edges().to_lower() == name:
			return line.substr(at + 1).strip_edges()
	return ""


## Messages as an event stream: the spec's way for a server to say
## something of its own before its answer.
func _http_events(client: Client, messages: Array) -> void:
	var events: String = ""
	for message: Variant in messages:
		events += "event: message\ndata: %s\n\n" % JSON.stringify(message)
	_http(client, 200, events, "", "text/event-stream")


func _http(client: Client, code: int, body: String, extra: String = "",
		type: String = "application/json") -> void:
	var reason: String = {200: "OK", 202: "Accepted", 204: "No Content",
		400: "Bad Request", 403: "Forbidden", 405: "Method Not Allowed"}.get(code, "OK")
	var bytes: PackedByteArray = body.to_utf8_buffer()
	var head: String = ("HTTP/1.1 %d %s\r\n" % [code, reason]
		+ "Content-Type: %s\r\n" % type
		+ "Content-Length: %d\r\n" % bytes.size()
		+ extra
		+ "Connection: keep-alive\r\n\r\n")
	if not client.gone:
		client.peer.put_data(head.to_utf8_buffer())
		if bytes.size() > 0:
			client.peer.put_data(bytes)
	client.busy = false


## The MCP version this speaks when a client does not name one.
const PROTOCOL := "2025-06-18"


# -- the line protocol ---------------------------------------------------


func _answer(client: Client, line: String) -> void:
	var asked_for: Variant = JSON.parse_string(line)
	if not (asked_for is Dictionary):
		_reply(client, -1, false, "that line is not a JSON object")
		return
	var request: Dictionary = asked_for
	var id: int = int(request.get("id", -1))
	var tool: String = str(request.get("tool", ""))
	var input: Dictionary = request.get("input", {}) as Dictionary

	if tool == "__tools__":
		if assistant == null:
			_reply(client, id, false, "the app has no assistant")
			return
		_send(client, {"id": id, "ok": true, "tools": catalogue()})
		return
	if tool == "__about__":
		if assistant == null:
			_reply(client, id, false, "the app has no assistant")
			return
		_send(client, {"id": id, "ok": true,
			"instructions": assistant.guidance()})
		return
	if tool == "__ping__":
		_send(client, {"id": id, "ok": true, "app": "brickworks",
			"port": _port, "clients": _clients.size()})
		return
	if assistant == null:
		_reply(client, id, false, "the app has no assistant")
		return
	if tool.is_empty():
		_reply(client, id, false, "no tool named")
		return

	asked.emit(tool)
	var called: Array = await _call(tool, input)
	if not bool(called[1]):
		_reply(client, id, false, QUEUED_OUT)
		return
	# The client may have gone while a tool was drawing a picture.
	if client.gone:
		return
	_send(client, {"id": id, "ok": true, "content": _as_content(called[0])})


const QUEUED_OUT := ("Another call is still running — the app does one at a time. "
	+ "Send them one after another.")

## The long calls a session made: see src/net/tool_jobs.gd.
var jobs := ToolJobs.new()


## One tool call, from either protocol: [its answer, whether it ran]. It
## did not run only when another call held the app for longer than
## [member queued_for].
##
## A call that can outlast the session's wait is a job (ToolJobs): one
## known to be long at once, any other once it has run for 20 s. It keeps
## the app until the work ends. While a job holds the app every other call
## is told so at once, and [code]job[/code] says how it is going.
func _call(name: String, input: Dictionary, entry: ToolJobs.Entry = null, chat: String = "") -> Array:
	if name == ToolJobs.TOOL:
		return [await jobs.answer(input), true]
	if entry == null:
		entry = ToolJobs.Entry.new()
	entry.input = input
	var holding: ToolJobs.Entry = jobs.running()
	if holding != null:
		return [jobs.busy(holding), true]
	# A review or a save reads Claude's parts before any tool of the
	# assistant's runs (Assistant._run_tool follows them too).
	if assistant != null:
		assistant.follow_renumbering()
	_doing = ""
	if assistant != null and not assistant.progress.is_connected(_heard):
		assistant.progress.connect(_heard)
	var doing: Callable = func() -> String:
		return (_doing.left(1).to_upper() + _doing.substr(1) + "…") if not _doing.is_empty() \
			else "Working on Claude's %s…" % name
	if name in ["clear_model", "save_model", "review_model"]:
		return [await jobs.call_tool(name, {}, func(_work: Working.Job) -> Variant:
			# One step too: a review lays a feature's piece, saving can hand
			# the next feature back laid, and clearing takes everything off.
			await _until_whole()
			var before: Dictionary = _before_change(name)
			var held: Dictionary = _held()
			_at_work += 1
			assistant.chat = chat
			var said: Variant = await _run_own(name, input)
			assistant.chat = ""
			_at_work -= 1
			_one_step(name, before, chat)
			_hand_and_view_back(held)
			return said, doing, entry), true]
	if not await _take_a_turn():
		holding = jobs.running()
		return [jobs.busy(holding), true] if holding != null else [null, false]
	var long: Dictionary = ToolJobs.long_call(name, input, app)
	# Refused before it began (a model shared to look at, the designer busy):
	# the refusal is the answer.
	if _the_app_tools().has(name) and not _the_app_tools().refusal(name, input).is_empty():
		long = {}
	return [await jobs.call_tool(name, long, func(work: Working.Job) -> Variant:
		# Cancelled in the moment before it began: a renderer told to stop
		# before it starts forgets it was told.
		var answer: Variant = "Cancelled before it began: nothing was done."
		await _until_whole()
		if work == null or not work.cancelled:
			answer = await _run(name, input, work, chat)
		_hand_back()
		return answer, doing, entry), true]


## What the assistant last said it was doing, for the words of a call that
## becomes a job part way.
var _doing: String = ""


func _heard(note: String) -> void:
	_doing = note


## A tool that takes the app's turn: the window's commands (AppTools), told
## the Working job it reports to when it is a job, or the assistant's. What
## it changes is one step of the history (see [method _one_step]).
func _run(name: String, input: Dictionary, work: Working.Job, chat: String = "") -> Variant:
	# A design going down on the example a first visit opens on: the example
	# off first, before the call's step begins (Assistant.make_room), so the
	# design is a model of its own and its Undo leaves that model empty.
	if name == "submit_design" and assistant != null:
		assistant.make_room(str(input.get("name", "")))
	var before: Dictionary = _before_change(name)
	var held: Dictionary = _held()
	var answer: Variant
	_at_work += 1
	assistant.chat = chat
	if _the_app_tools().has(name):
		_the_app_tools().chat = chat
		answer = await _the_app_tools().run(name, input, work)
		_the_app_tools().chat = ""
	else:
		answer = await assistant.use_tool(name, input)
	assistant.chat = ""
	_at_work -= 1
	_one_step(name, before, chat)
	_hand_and_view_back(held)
	return answer


## What the person holds and sees as a call begins (Main.hand_and_view), {}
## with no window.
func _held() -> Dictionary:
	return app.call("hand_and_view") if app != null and app.has_method("hand_and_view") else {}


## Nothing of the call's left in the person's hand, and a model it changed
## in view (Main.after_session_call).
func _hand_and_view_back(held: Dictionary) -> void:
	if not held.is_empty():
		app.call("after_session_call", held)


## The ones whose change is no step of the history: undo walks it, and
## opening a model begins another.
const NOT_A_STEP: Array[String] = ["undo", "open_model", ToolJobs.TOOL]


## The model as it stood before a call, for its change to be one step of
## the history; {} for a call that only looks.
func _before_change(name: String) -> Dictionary:
	if assistant == null or assistant.builder == null or assistant.world == null \
			or leaves_the_model(name) or name in NOT_A_STEP:
		return {}
	var builder: Builder = assistant.builder
	var last: Dictionary = builder.last_step()
	return {"depth": builder.history_depth(), "last": last,
		"size": (last.get("steps", []) as Array).size(),
		"was": SelectionScope.snapshot(assistant.world, assistant.scenery),
		"kept": builder.steps_now()[0], "generation": assistant.world.generation()}


## Whatever a call from outside changed, as one step of the history, named
## as Claude's. An edit_model from a session went into no history at all, so
## the person's Undo after it took back their own last part and left
## Claude's edit standing. A call that keeps its own history (the window's
## commands, an edit about a selection) has its steps folded into one, with
## whatever it changed that they do not name; any other has the difference
## made one step.
func _one_step(name: String, before: Dictionary, chat: String = "") -> void:
	if before.is_empty():
		return
	var builder: Builder = assistant.builder
	if builder.history_depth() > int(before["depth"]):
		# A session's first design lays its parts with no step and then keeps
		# the floor it chose as one: only the floor's was folded, so undoing
		# everything after two small designs left 55 and 8 parts on the bare
		# baseplate. Named by the call's own steps only, not by the redo they
		# cleared, which names a design laid again part for part. Kept below
		# them, as it came first: redone after the floor, the floor was laid
		# round nothing, and a baseplate part of the build came back scenery.
		ClaudeStep.record(builder, assistant.world, assistant.scenery, {"was": before["was"],
			"steps": [before["kept"], builder.steps_now()[1]],
			"generation": before["generation"], "words": "Claude's %s" % name.replace("_", " ")},
			int(before["depth"]))
		builder.fold_since(int(before["depth"]))
		_mark(builder, chat)
		_laid(builder.last_step())
		return
	var last: Dictionary = builder.last_step()
	if not last.is_empty() and is_same(last, before["last"]) \
			and (last.get("steps", []) as Array).size() != int(before["size"]):
		return
	var steps: Array = SelectionScope.steps_back(before["was"], assistant.world,
		assistant.scenery)
	if not steps.is_empty():
		builder.record(steps, "Claude's %s (%s)" % [name.replace("_", " "),
			SelectionScope.words_for(steps)])
		_mark(builder, chat)
		_laid(builder.last_step())


## A call that put parts down makes the model one made with the assistant
## (ModelStore.made_with): a session's parts are Claude's, as the panel's are.
func _laid(step: Dictionary) -> void:
	var store: ModelStore = app.get("_store") if app != null else null
	if store != null and ClaudeStep.lays(step):
		store.laid_by("assistant")


## Which Claude chat made the newest step (the relay names the chat on a
## call's _meta, api/mcp.js): with two chats in one tab, one chat's undo
## does not take back the other's (AppTools._undo). Kept in the step
## itself, which is the history's own record of it.
const CHAT_KEY := "brickworks/chat"


static func chat_of(params: Dictionary) -> String:
	var meta: Variant = params.get("_meta")
	if not meta is Dictionary or not (meta as Dictionary).get(CHAT_KEY) is Dictionary:
		return ""
	return str(((meta as Dictionary)[CHAT_KEY] as Dictionary).get("chat", ""))


static func _mark(builder: Builder, chat: String) -> void:
	var last: Dictionary = builder.last_step()
	if not chat.is_empty() and not last.is_empty():
		last["by"] = chat


## Wait until no other tool is running, then take the app.
##
## Returns false if the wait ran out, in which case nothing was taken
## and the caller must answer rather than carry on.
##
## Measured in seconds and not in frames. A headless app runs frames in
## microseconds, so a frame count is no wait at all there and a long one
## in a window — the same mistake cost a day on the reference finder.
func _take_a_turn() -> bool:
	if _in_hand == 0:
		_in_hand += 1
		return true
	var until: float = Time.get_unix_time_from_system() + queued_for
	# Frames, not the signal. Waiting on _handed_back alone looks
	# tidier and silently drops the deadline: if whoever holds the app
	# never finishes, the signal never comes, the line above is never
	# reached again and the queue waits for ever — which is the hang
	# this was written to stop, moved one layer down. A frame always
	# comes.
	while _in_hand > 0:
		# A job holds the app for minutes: said at once, not waited out.
		if Time.get_unix_time_from_system() > until or jobs.running() != null:
			return false
		await get_tree().process_frame
	_in_hand += 1
	return true


## A model being laid over frames (ModelStore.laying), waited for until it is
## all down: no tool reads half of it as the model, or changes it. A call
## that waits long becomes a job (ToolJobs.call_tool).
func _until_whole() -> void:
	var store: ModelStore = app.get("_store") if app != null else null
	while store != null and store.laying:
		await get_tree().process_frame


func _hand_back() -> void:
	_in_hand = maxi(0, _in_hand - 1)


## The rest of the window's commands, for a session: src/net/app_tools.gd.
var _app_tools: AppTools = null


func _the_app_tools() -> AppTools:
	if _app_tools == null:
		_app_tools = AppTools.new()
	_app_tools.app = app
	_app_tools.assistant = assistant
	return _app_tools


## Tools an outside session needs and the design loop does not.
##
## The loop clears the baseplate itself when a design begins, and never
## saves — the person does that from the window. A session driving from
## outside has neither moment, so without these it would build into
## whatever was already standing and leave no file behind. And the rest
## of what the window does (AppTools): the floor, the build steps, hoses,
## posing, undo, opening, the parts list, rendering, exporting.
func _own_tools() -> Array:
	return _socket_tools() + _the_app_tools().definitions() + [ToolJobs.definition()]


func _socket_tools() -> Array:
	return [
		{
			"name": "review_model",
			"description": ("Look a built model over the way Brickworks' own "
				+ "designer does after a design stands: with no assembly, the "
				+ "whole model measured against real LEGO® sets of its size and "
				+ "kind — shapes, colours, the one-off pieces, how coarse — and "
				+ "what to check it for; with an assembly named in "
				+ "submit_design, that one close up, measured, with the parts "
				+ "real sets of the kind use that it has none of; with a feature "
				+ "(eyes, beak, wheel arches, grille), the best real set's piece "
				+ "for it laid by the app where it goes, with a picture, to settle "
				+ "with settle_feature; with surface, the surface pass — the app "
				+ "tiles the open stud fields, slopes the staircases (plate steps "
				+ "two at a time), rounds a body's hard top edges, skins its plain "
				+ "flanks and textures a building's plain walls on the model, to "
				+ "settle each with "
				+ "settle_surface; with creative, the creative pass — three touches "
				+ "proposed for this subject and the best one or two added. Call it "
				+ "after submit_design, then once per feature, then once per "
				+ "assembly, working each before the next, then surface, then "
				+ "creative last."),
			"input_schema": {
				"type": "object",
				"properties": {
					"assembly": {"type": "string", "description":
						"an assembly's name as given in submit_design; omit "
						+ "for the whole model"},
					"feature": {"type": "string", "description":
						"a feature the subject is known by, as listed in "
						+ "submit_design's features"},
					"surface": {"type": "boolean", "description":
						"true for the surface pass, once the features and "
						+ "assemblies have had their turns"},
					"creative": {"type": "boolean", "description":
						"true for the creative pass, after the surface pass"},
				},
				"additionalProperties": false,
			},
		},
		{
			"name": "clear_model",
			"description": ("Take everything off the baseplate and start "
				+ "from bare ground. Do this before building something "
				+ "new, or the new thing is built into the old one."),
			"input_schema": {
				"type": "object", "properties": {},
				"additionalProperties": false,
			},
		},
		{
			"name": "save_model",
			"description": ("Write what is on the baseplate to an LDraw "
				+ ".ldr file in this app's models, where its Open finds it "
				+ "and other LDraw tools can read it. A name, not a path; "
				+ "it will not write over a model the person saved."),
			"input_schema": {
				"type": "object",
				"properties": {
					"name": {"type": "string", "description":
						"the file's name, such as orthanc.ldr"},
				},
				"required": ["name"],
				"additionalProperties": false,
			},
		},
	]


## Every tool name this port serves, the assistant's and its own.
##
## Used to tell Claude Code what it may call: a headless session is
## allowed exactly these and nothing else, so it cannot read or write a
## file, and a design run has no reason to.
func tool_names() -> PackedStringArray:
	var names := PackedStringArray()
	if assistant != null:
		for tool: Variant in assistant.tool_catalogue():
			names.append(str((tool as Dictionary).get("name", "")))
	for tool: Variant in _own_tools():
		names.append(str((tool as Dictionary).get("name", "")))
	return names


## What this session saved, so it may save again over its own and never
## over the person's.
var _saved_here: Dictionary = {}


## A file name for a model out of whatever was asked for: the last part of
## a path, in characters a file system takes, ending .ldr. Empty if there
## is nothing usable left.
static func _model_file(asked: String) -> String:
	var name: String = asked.strip_edges().replace("\\", "/").get_file()
	var kept: String = ""
	for character: String in name:
		kept += character if (character.is_valid_identifier() or character in "0123456789 -_." \
			or character.unicode_at(0) > 127) else "-"
	kept = kept.strip_edges().lstrip(".")
	if kept.to_lower().ends_with(".ldr"):
		kept = kept.substr(0, kept.length() - 4)
	if kept.is_empty():
		return ""
	return kept + ".ldr"


## A coroutine: reviewing the whole model checks it, which a big model does
## on a worker thread (Assistant._checked) while the app goes on drawing.
## The window's other commands (AppTools) are not these: they wait their
## turn as the assistant's tools do (_call), since a render, a hose and a
## pose all draw or change the one model. A String, or the blocks of an
## answer with a picture in it.
func _run_own(tool: String, input: Dictionary) -> Variant:
	if tool == "review_model" and assistant != null:
		if bool(input.get("surface", false)):
			return await assistant.surface_review()
		return await assistant.review(str(input.get("assembly", "")),
			str(input.get("feature", "")), bool(input.get("creative", false)))
	# Not until its features are settled: saving handed the next one back
	# only after the file was written, and every session then ended.
	if tool == "save_model" and assistant != null:
		var held: Variant = await assistant.save_gate()
		if not (held is String and (held as String).is_empty()):
			return held
	if app == null:
		return "This app cannot do that from outside."
	match tool:
		"clear_model":
			# The person asked about part of their model: clearing it is not
			# an answer to that, and cannot be undone.
			if assistant != null and assistant.asked_about_selection():
				return ("Not now — the person asked about the parts they selected, "
					+ "and clearing would take their whole model off. Change those "
					+ "parts with edit_selection.")
			# One undo puts it back (_call): the person's model, cleared by a
			# session, was gone for good.
			app.clear_model()
			return "The baseplate is bare. undo puts it back."
		"save_model":
			# A name in the app's own models, never a path. It wrote
			# wherever it was told: a design run put orthanc.ldr in the
			# directory the app was started from, and anything able to
			# reach the port could have written over any file at all.
			var file: String = _model_file(str(input.get("name",
				input.get("path", ""))))
			if file.is_empty():
				return "Give the model a file name, such as orthanc.ldr."
			var path: String = ModelStore.SAVE_DIR + file
			if FileAccess.file_exists(path) and not _saved_here.has(path):
				return ("There is already a model called %s, which this "
					+ "session did not write. Choose another name.") % file
			# Its named assemblies go into the file as sub-models, as this
			# app's own run tags them as it ends: a stand named to stand
			# apart is an item the person sees, and a check of the file
			# takes it as one.
			if assistant != null:
				assistant._tag_assemblies()
			if not app.save_model(path):
				return "Could not write %s." % file
			_saved_here[path] = true
			var written: String = "Written to %s, with the app's models (%s)." % [file,
				ProjectSettings.globalize_path(path)]
			if assistant != null:
				written = Assistant._joined(written, assistant.save_advice())
			# A run's last act is to save: so saving hands back the next
			# assembly it has not looked at closely, if there is one.
			var more: Variant = ""
			if assistant != null:
				more = await assistant.next_review()
			return Assistant._joined(written, more)
	return "No tool called %s." % tool


## What a tool handed back, as content blocks.
##
## Tools answer with a String, or with the array of blocks Anthropic
## accepts in a tool result — which carries a picture as
## [code]{"type": "image", "source": {"data": ...}}[/code]. MCP wants
## [code]{"type": "image", "data": ..., "mimeType": ...}[/code], so the
## shapes are translated here rather than in the relay: the relay should
## not have to know how this app happens to talk to Anthropic.
func _as_content(answer: Variant) -> Array:
	if answer is String:
		return [{"type": "text", "text": answer}]
	if not (answer is Array):
		return [{"type": "text", "text": str(answer)}]
	var blocks: Array = []
	for block: Variant in answer as Array:
		if not (block is Dictionary):
			blocks.append({"type": "text", "text": str(block)})
			continue
		var one: Dictionary = block
		if str(one.get("type", "")) == "image":
			var source: Dictionary = one.get("source", {}) as Dictionary
			blocks.append({
				"type": "image",
				"data": str(source.get("data", "")),
				"mimeType": str(source.get("media_type", "image/png")),
			})
		else:
			blocks.append({"type": "text", "text": str(one.get("text", ""))})
	return blocks


func _reply(client: Client, id: int, ok: bool, message: String) -> void:
	_send(client, {"id": id, "ok": ok, "error": message})


func _send(client: Client, answer: Dictionary) -> void:
	if not client.gone:
		var line: PackedByteArray = (
			JSON.stringify(answer) + "\n").to_utf8_buffer()
		# Said, not swallowed. A client that cannot be written to is one
		# whose request is never answered, and the only sign of it from
		# the other end is a session that waits for three minutes.
		var sent: Error = client.peer.put_data(line)
		if sent != OK:
			push_error("command socket: could not answer (%s)"
				% error_string(sent))
	client.busy = false
