## A second design in one session keeps its own subject; a revision keeps
## the first's.
##
##   godot --headless --path . --script src/dev/second_design_probe.gd
##
## A person asks for an owl head, then a house roof, in one chat with no
## Clear between. The house was read by the owl's subject: its check said a
## creature with nothing on a joint, read_guide "shapes" opened on figures,
## and the session's house roof was sent back to be laid as a jointed owl
## (surface_probe met it, surface108). Asked instead to make the owl's head
## bigger, the app's own designer forgot it was an owl: the revision's words
## replaced the brief.
##
## Over MCP as a person's own Claude calls it (CommandSocket.answer_rpc,
## tools/call), on the real scene; then the app's own designer, driven
## through its loop's _on_response with replies written here, as
## features_probe is, so it runs without the network.
extends SceneTree


## The loop with the request taken out. Everything else is the real one.
class Offline extends Assistant:
	func _send() -> void:
		pass


## What a check, a review or a guide says of a character with nothing on a
## joint (Assistant._on_joints_said, _for_the_subject).
const ON_JOINTS := "nothing in it is on a joint"
const A_CHARACTER := "This subject is a figure, a creature or a character"

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	await _over_mcp()
	await _in_the_app()
	_done()


## A person's own Claude: an owl head, the owl's head bigger, a house roof.
func _over_mcp() -> void:
	var assistant: Assistant = _main.get("_assistant")
	print("\nover MCP: an owl head, then its head bigger, then a house roof, no Clear")
	_check("the session starts on a bare baseplate",
		(await _say("clear_model", {})).begins_with("The baseplate is bare"))
	await _say("plan_scale", {"subject": "owl head"})
	var said: String = await _say("submit_design", _design("Owl head",
		"a great horned owl's head, its ear tufts up", _head(1)))
	_check("the owl head is built: %s" % said.get_slice("\n", 0), said.begins_with("Built"))
	_check("...and told of its joints, as a part of a creature", said.contains(ON_JOINTS))

	print("  \"make the owl's head bigger\"")
	said = await _say("submit_design", _design("Owl head",
		"a great horned owl's head, bigger, its ear tufts up", _head(2)))
	_check("the bigger head is built: %s" % said.get_slice("\n", 0), said.begins_with("Built"))
	_check("...still told of its joints: the revision is still an owl", said.contains(ON_JOINTS))
	_check("...and read_guide \"shapes\" still opens on the character",
		(await _say("read_guide", {"section": "shapes"})).begins_with(A_CHARACTER))

	print("  \"now build a house roof\"")
	await _say("plan_scale", {"subject": "house roof"})
	said = await _say("submit_design", _design("House roof", "a red roof on white walls",
		_roof()))
	print("    " + said.substr(0, 300).replace("\n", "\n    "))
	_check("the house roof is built, not sent back as an owl", said.begins_with("Built"))
	_check("...and not told of joints", not said.contains(ON_JOINTS))
	_check("...read_guide \"shapes\" no longer opens on a character",
		not (await _say("read_guide", {"section": "shapes"})).begins_with(A_CHARACTER))
	var about: String = assistant._subject_of()
	_check("...and what the checks read as its subject names no owl: \"%s\""
		% about.strip_edges(), not about.to_lower().contains("owl"))


## The app's own designer, in one conversation in its panel.
func _in_the_app() -> void:
	var world := BrickWorld.new()
	world.library = _main.get("_library")
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = world.library
	root.add_child(builder)
	var assistant := Offline.new()
	assistant.library = world.library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	await process_frame

	print("\nthe app's designer: an owl head, then \"make it bigger\"")
	_check("the design starts", assistant.design("an owl head"))
	await _reply(assistant, [_tool("submit_design", _design("Owl head",
		"a great horned owl's head", _head(1)))])
	_check("the owl head stands and is told of its joints",
		assistant._looked_back and _last(assistant).contains(ON_JOINTS))
	assistant._stop(true, "done")
	_check("the revision starts in the same conversation", assistant.has_conversation()
		and assistant.revise("make it bigger"))
	await _reply(assistant, [_tool("read_guide", {"section": "shapes"})])
	_check("before it submits, the guide still reads it as a character: \"%s\""
		% assistant._subject_of().strip_edges(), _last(assistant).begins_with(A_CHARACTER))
	await _reply(assistant, [_tool("submit_design", _design("Owl head",
		"a great horned owl's head, bigger", _head(2)))])
	_check("the bigger head stands, still told of its joints",
		assistant._looked_back and _last(assistant).contains(ON_JOINTS))
	assistant._stop(true, "done")

	print("\ncleared; an owl head looked up and built, then \"now build a house roof\"")
	world.clear()
	builder.lattice.clear()
	assistant.forget_built()
	assistant.forget_conversation()
	_check("the design starts", assistant.design("an owl head"))
	await _reply(assistant, [_tool("plan_scale", {"subject": "owl head"}),
		_tool("submit_design", _design("Owl head", "a great horned owl's head", _head(1)))])
	_check("the owl head stands", assistant._looked_back and _last(assistant).contains(ON_JOINTS))
	assistant._stop(true, "done")
	_check("the next request starts in the same conversation",
		assistant.revise("now build a house roof"))
	await _reply(assistant, [_tool("submit_design", _design("House roof",
		"a red roof on white walls", _roof()))])
	var look: String = _last(assistant)
	_check("the house roof stands", assistant._looked_back and world.brick_count() == _roof().size())
	_check("...and is not told of joints", not look.contains(ON_JOINTS))
	var about: String = assistant._subject_of()
	_check("...what its checks read as its subject names no owl: \"%s\"" % about.strip_edges(),
		not about.to_lower().contains("owl"))
	assistant._stop(true, "done")

	print("\nNew in the panel, the model kept: \"a lighthouse\"")
	assistant.forget_conversation()
	_check("a fresh design starts", assistant.design("a lighthouse"))
	about = assistant._subject_of()
	_check("its subject is the lighthouse alone: \"%s\"" % about.strip_edges(),
		about.strip_edges() == "a lighthouse")
	assistant._stop(true, "done")


# -- fixtures --------------------------------------------------------------


func _design(name: String, description: String, bricks: Array) -> Dictionary:
	return {"name": name, "description": description, "bricks": bricks, "features": []}


## A tan head of 2 x 2 bricks, [param courses] high, under a 6 x 6 plate
## with its top tiled.
func _head(courses: int) -> Array:
	var out: Array = []
	for course: int in courses:
		for x: int in [0, 2, 4]:
			for z: int in [0, 2, 4]:
				out.append({"part": "3003", "color": 19, "x": x, "y": course * 3, "z": z,
					"rot": 0})
	out.append({"part": "3958", "color": 19, "x": 0, "y": courses * 3, "z": 0, "rot": 0})
	for z: int in [0, 2, 4]:
		out.append({"part": "69729", "color": 19, "x": 0, "y": courses * 3 + 1, "z": z,
			"rot": 0})
	return out


## A red 6 x 8 plate on a course of white 2 x 2 bricks.
func _roof() -> Array:
	var out: Array = []
	for x: int in [0, 2, 4, 6]:
		for z: int in [0, 2, 4]:
			out.append({"part": "3003", "color": 15, "x": x, "y": 0, "z": z, "rot": 0})
	out.append({"part": "3036", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0})
	return out


# -- helpers ---------------------------------------------------------------


func _say(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get(
			"content", []):
		text += str(block.get("text", ""))
	return text


func _reply(assistant: Assistant, content: Array) -> void:
	var body: String = JSON.stringify({"content": content, "stop_reason": "end_turn"})
	await assistant._on_response([HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(), body.to_utf8_buffer()])


func _tool(name: String, input: Dictionary) -> Dictionary:
	return {"type": "tool_use", "id": "t%d" % randi(), "name": name, "input": input}


## The words of the last message the loop sent, wherever they sit in it.
func _last(assistant: Assistant) -> String:
	if assistant._messages.is_empty():
		return ""
	return _words(assistant._messages.back().get("content"))


func _words(content: Variant) -> String:
	if typeof(content) == TYPE_STRING:
		return content
	var said := PackedStringArray()
	if content is Array:
		for block: Variant in content:
			if block is Dictionary:
				var one: Dictionary = block
				if one.get("type", "") == "text":
					said.append(str(one.get("text", "")))
				elif one.get("type", "") == "tool_result":
					said.append(_words(one.get("content")))
	return "\n".join(said)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _done() -> void:
	print("a second design keeps its own subject, a revision the first's" if _failures == 0
		else "%d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)
