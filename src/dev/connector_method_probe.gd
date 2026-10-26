## Does a chat that reaches a tab through Claude's connector hear how to work
## here, once, and begin its own subject?
##
##   godot --headless --path . --script src/dev/connector_method_probe.gd
##
## The owner designs with their own Claude in claude.ai, and whether claude.ai
## shows a server's instructions was never measured; the bench's sessions,
## which Claude Code shows them, all followed HOW TO WORK (design281,
## 2026-10-26). So the tab says the method itself (ClaudeConnector._taught):
## ahead of a chat's first answer, after the relay's line naming the tab, and
## never again in that sitting, which a word said in every answer would undo
## (pose174). Each chat has its own sitting, a call naming no chat (a tab's own
## address) has one too, and a chat quiet for half an hour begins another. The
## panel's copy of the answer is the tool's alone.
##
## And a chat's first design call begins its subject, as the bench's brief does
## (Assistant.heard(brief, true)): a lighthouse asked for after a pirate ship of
## 300 parts is a lighthouse with no count, not both.
##
## On the code before 2026-10-26 the tab added nothing to an answer and had
## none of this to call, so the probe does not load. The whole path, relay and
## Claude Code, is proven by tools/bench/realset.py --via relay.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var assistant := Assistant.new()
	get_root().add_child(assistant)
	var socket := CommandSocket.new()
	socket.assistant = assistant
	get_root().add_child(socket)
	ClaudeConnector.where = "user://probe_connector_method.json"
	var connector := ClaudeConnector.new()
	connector.rpc = socket
	get_root().add_child(connector)

	print("\nthe method, once a sitting")
	var first: Dictionary = _answer("look")
	var sent: Variant = connector._taught(connector._sitting(_call("a1b2", "look_at_model")),
		"look_at_model", first)
	var said: Array = _texts(sent)
	_check(said.size() == 2 and str(said[0]) == Assistant.METHOD and str(said[1]) == "look",
		"a chat's first answer says how to work, then the tool's own words")
	_check(_texts(first) == ["look"], "...and the answer the panel shows is the tool's alone")
	said = _texts(connector._taught(connector._sitting(_call("a1b2", "search_parts")),
		"search_parts", _answer("found")))
	_check(said == ["found"], "its second answer does not say it again")
	said = _texts(connector._taught(connector._sitting(_call("c3d4", "plan_scale")),
		"plan_scale", _answer("scale")))
	_check(said.size() == 2 and str(said[0]) == Assistant.METHOD, "another chat is told once too")
	said = _texts(connector._taught(connector._sitting(_call("", "plan_scale")),
		"plan_scale", _answer("scale")))
	var again: Array = _texts(connector._taught(connector._sitting(_call("", "view_model")),
		"view_model", _answer("view")))
	_check(said.size() == 2 and again == ["view"],
		"a tab's own address, naming no chat, is told once")
	var refused: Variant = {"jsonrpc": "2.0", "id": 1, "error": {"code": -32603, "message": "no"}}
	var sitting: Dictionary = connector._sitting(_call("e5f6", "look_at_model"))
	_check(connector._taught(sitting, "look_at_model", refused) == refused
		and _texts(connector._taught(connector._sitting(_call("e5f6", "look_at_model")),
			"look_at_model", _answer("look"))).size() == 2,
		"an answer with nothing to carry it waits for the next")
	(connector._sittings["a1b2"] as Dictionary)["last"] = \
		Time.get_ticks_msec() - ClaudeConnector.QUIET_MS - 1000
	said = _texts(connector._taught(connector._sitting(_call("a1b2", "look_at_model")),
		"look_at_model", _answer("look")))
	_check(said.size() == 2, "a chat quiet for half an hour is told again, as a new sitting")
	_check(Assistant.METHOD.length() < 1500,
		"the method is %d characters, a few lines" % Assistant.METHOD.length())

	print("\na chat's first design call begins its subject")
	assistant.heard("a pirate ship with three masts", true)
	assistant._count_asked(300, Assistant.PARTS_ABOUT)
	connector._begin(connector._sitting(_call("g7h8", "look_at_model")), "look_at_model", {})
	_check(assistant._subject_of().contains("pirate ship") and assistant._parts_asked == 300,
		"a look begins nothing")
	connector._begin(connector._sitting(_call("g7h8", "how_real_sets_build_this")),
		"how_real_sets_build_this", {"subject": "lighthouse"})
	_check(assistant._heard_fresh == "lighthouse" and not assistant._subject_of().contains("pirate")
		and assistant._parts_asked == 0,
		"how_real_sets_build_this begins the lighthouse, with no pirate ship and no count: %s"
			% assistant._subject_of().strip_edges())
	assistant.heard("lamp room", false)
	connector._begin(connector._sitting(_call("g7h8", "plan_scale")), "plan_scale",
		{"subject": "tower"})
	_check(assistant._heard_fresh == "lighthouse" and assistant._subject_of().contains("lamp room"),
		"its next subject call begins nothing again")
	connector._begin(connector._sitting(_call("i9j0", "submit_design")), "submit_design",
		{"name": "Tokyo skyline", "description": "towers by the bay"})
	_check(assistant._heard_fresh == "Tokyo skyline. towers by the bay"
		and not assistant._subject_of().contains("lighthouse"),
		"another chat's first submit begins its own: %s" % assistant._heard_fresh)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(ClaudeConnector.where))
	print("\n%s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures > 0 else 0)


## A tool call as the relay hands it to the tab, from [param chat].
static func _call(chat: String, tool: String) -> Dictionary:
	var params: Dictionary = {"name": tool, "arguments": {}}
	if not chat.is_empty():
		params["_meta"] = {"brickworks/chat": {"chat": chat, "since": "2026-10-26T06:00:00Z"}}
	return {"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": params}


static func _answer(words: String) -> Dictionary:
	return {"jsonrpc": "2.0", "id": 1, "result": {"isError": false,
		"content": [{"type": "text", "text": words}]}}


static func _texts(answer: Variant) -> Array:
	var out: Array = []
	if answer is Dictionary and (answer as Dictionary).get("result") is Dictionary:
		for block: Variant in ((answer as Dictionary)["result"] as Dictionary).get("content", []):
			out.append(str((block as Dictionary).get("text", "")))
	return out


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)
