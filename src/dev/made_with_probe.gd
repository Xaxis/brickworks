## Does the app know who laid a model's parts, to say it as it publishes?
##
##   godot --headless --path . --script src/dev/made_with_probe.gd
##
## docs/SOCIAL.md D7 and U16 (2026-10-24): a card says Hand-built or With the
## assistant, and the gallery filters by it. It was read from the tags
## (ai-designed, brickify), so a hand-built model tagged ai-designed was
## marked as the assistant's and an untagged design of Claude's as
## hand-built. Now the app says it (ModelStore.made_with, sent by SharePanel
## as made_with): "hand" for a model begun empty here with every part laid by
## a person, "assistant" once Claude laid any, "brickify" once Brickify did
## and Claude never, and nothing for a model from a file that does not say.
##
## Here, in the app as it opens: the baseplate cleared is hand-built, and
## stays so as the person lays a part; a session's call that lays a part (as
## the connector makes it, CommandSocket.answer_rpc) makes it the
## assistant's; the panel's designer laying a design or keeping a step that
## lays parts does too (Assistant.built, Assistant.laid_parts); Brickify's
## parts make it Brickify's, unless Claude's were laid; a part only moved or
## painted is still whoever laid it (ClaudeStep.lays). It goes with the
## model's text (0 !BRICKWORKS MADE) through a save and an open, and a text
## without it says nothing; named as a design stands, it keeps what it was;
## cleared, it is hand-built again.
##
## On base (rel-m164, 87d93fad) there is no made_with: every check fails.
extends SceneTree

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _world: BrickWorld
var _builder: Builder
var _socket: CommandSocket
var _sent: int = 0


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
	_store = _main.get("_store")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	if not "made_with" in _store:
		_ok(false, "the store says who laid its parts (ModelStore.made_with): it has no such thing")
		_finish()
		return

	print("\nlaid by hand")
	_main.call("clear_model")
	await process_frame
	_ok(_store.made_with == "hand", "the baseplate cleared, the model is hand-built (%s)" % _store.made_with)
	_builder.held_part = "3001"
	_builder.held_color = 4
	_builder.update_preview(Vector3(-200.0, 400.0, -200.0), Vector3.DOWN)
	var theirs: int = _builder.place()
	_ok(theirs != 0 and _store.made_with == "hand",
		"the person lays a part: still hand-built (%s)" % _store.made_with)

	print("\na session lays a part")
	var said: String = await _call("edit_model", {"add": [{"part": "3001", "color": 1,
		"x": 12, "y": 0, "z": 8, "rot": 0}]})
	var parts: int = _world.brick_count() - _store.scenery.size()
	_ok(parts == 2 and _store.made_with == "assistant",
		"Claude's edit_model lays one: made with the assistant (%s, %d parts; %s)"
		% [_store.made_with, parts, said.left(80)])
	_ok(ClaudeStep.lays(_builder.last_step()), "...its one step is one that lays a part")

	print("\nwhat a step lays")
	_ok(not ClaudeStep.lays({"undo": "recolor", "brick": 1, "color": 4})
		and not ClaudeStep.lays({"undo": "group", "steps": [{"undo": "move", "brick": 1,
			"transform": Transform3D.IDENTITY}]})
		and not ClaudeStep.lays({"undo": "add", "part": "3001", "color": 4}),
		"a part painted, moved or taken off lays nothing")
	_ok(ClaudeStep.lays({"undo": "group", "steps": [{"undo": "recolor", "brick": 1, "color": 4},
		{"undo": "group", "steps": [{"undo": "remove", "brick": 2}]}]}),
		"a part put down, however deep in its step, lays one")

	print("\nkept with the model")
	var text: String = ModelStore.with_share(_store.to_text("Made With Probe"), "", "", 0, {},
		_store.made_with)
	_ok(text.contains("\n0 !BRICKWORKS MADE assistant\n") and ModelStore.made_in(text) == "assistant",
		"its text says so on a line of its own")
	_ok(not _store.to_text("Made With Probe").contains("!BRICKWORKS MADE"),
		"...never in what is published or exported (to_text)")
	_main.call("clear_model")
	_ok(_store.made_with == "hand", "cleared again: hand-built (%s)" % _store.made_with)
	var opened: Dictionary = _store.open_text(text, "Made With Probe")
	await process_frame
	_ok(str(opened.get("error", "")).is_empty() and _store.made_with == "assistant",
		"opened from that text: made with the assistant again (%s)" % _store.made_with)
	_store.open_text(_store.to_text("Made With Probe"), "Made With Probe")
	await process_frame
	_ok(_store.made_with == "", "opened from a text that does not say: nobody can vouch for it (\"%s\")"
		% _store.made_with)
	_ok(ModelStore.made_in("0 FILE x.ldr\n0 !BRICKWORKS MADE robots\n") == "",
		"a line saying something else is not believed")
	_ok(ModelStore._without_app_lines(text).find("!BRICKWORKS MADE") < 0,
		"...and someone else's file written back gets the line once, not twice")

	print("\nBrickify and the assistant")
	_main.call("clear_model")
	_store.laid_by("brickify")
	_ok(_store.made_with == "brickify", "Brickify lays a model: made with Brickify (%s)" % _store.made_with)
	_store.laid_by("assistant")
	_store.laid_by("brickify")
	_ok(_store.made_with == "assistant", "Claude lays parts too: the assistant's, and Brickify after "
		+ "does not take it back (%s)" % _store.made_with)
	_store.laid_by("hand")
	_ok(_store.made_with == "assistant", "a hand never takes it back either (%s)" % _store.made_with)
	_store.open_text(_store.to_text("Made With Probe"), "Made With Probe")
	await process_frame
	_store.laid_by("brickify")
	_ok(_store.made_with == "brickify", "a model nobody could vouch for, Brickify lays parts in: at least "
		+ "Brickify's (%s)" % _store.made_with)

	print("\nthe panel's designer")
	_main.call("clear_model")
	var assistant: Assistant = _main.get("_assistant")
	assistant.built.emit(0)
	_ok(_store.made_with == "hand", "a design that laid nothing leaves it hand-built (%s)" % _store.made_with)
	assistant.built.emit(12)
	_ok(_store.made_with == "assistant", "a design laid: made with the assistant (%s)" % _store.made_with)
	_main.call("clear_model")
	_builder.update_preview(Vector3(-200.0, 400.0, -200.0), Vector3.DOWN)
	_builder.place()
	assistant.laid_parts.emit()
	_ok(_store.made_with == "assistant", "a request's step that lays parts: made with the assistant (%s)"
		% _store.made_with)
	# Named as the design stands (Main._on_titled), over parts already laid.
	_store.begin("A Probe Tower")
	_ok(_store.made_with == "assistant", "named as it stands, its parts are still Claude's (%s)"
		% _store.made_with)
	_main.call("clear_model")
	_ok(_store.made_with == "hand", "and begun empty again, hand-built (%s)" % _store.made_with)
	_finish()


func _call(tool: String, input: Dictionary) -> String:
	_sent += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _sent,
		"method": "tools/call", "params": {"name": tool, "arguments": input}})
	var out := PackedStringArray()
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		out.append(str((block as Dictionary).get("text", "")))
	return " ".join(out)


func _ok(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILED" % _failures if _failures else "the app knows who laid a model's parts")
	_main.queue_free()
	await process_frame
	quit(1 if _failures else 0)
