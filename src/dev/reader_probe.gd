## Does the reassembled answer match the answer that was sent?
##
##   godot --headless --path . --script src/dev/reader_probe.gd
##
## The streaming reader has one job that matters: what comes out at the
## end must be indistinguishable from an unstreamed reply, because the
## next turn sends it back and a mangled transcript is refused in ways
## that are hard to read.
##
## Its failures are all quiet ones. A truncated stream that reports
## success. A character mangled because it straddled a chunk boundary. A
## thinking signature lost, which the API notices and nobody else does.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	# A reply with everything in it: prose, thinking with a signature,
	# and a tool call whose arguments arrive in pieces.
	var events: Array[String] = [
		'{"type":"message_start","message":{"id":"msg_1","type":"message",'
			+ '"role":"assistant","model":"claude-opus-5","content":[],'
			+ '"usage":{"input_tokens":10,"output_tokens":0}}}',
		'{"type":"content_block_start","index":0,'
			+ '"content_block":{"type":"thinking","thinking":""}}',
		'{"type":"content_block_delta","index":0,'
			+ '"delta":{"type":"thinking_delta","thinking":"a roof of "}}',
		'{"type":"content_block_delta","index":0,'
			+ '"delta":{"type":"thinking_delta","thinking":"slopes"}}',
		'{"type":"content_block_delta","index":0,'
			+ '"delta":{"type":"signature_delta","signature":"sig123=="}}',
		'{"type":"content_block_stop","index":0}',
		'{"type":"content_block_start","index":1,'
			+ '"content_block":{"type":"text","text":""}}',
		'{"type":"content_block_delta","index":1,'
			+ '"delta":{"type":"text_delta","text":"Une maison — "}}',
		'{"type":"content_block_delta","index":1,'
			+ '"delta":{"type":"text_delta","text":"café au lait 🧱"}}',
		'{"type":"content_block_stop","index":1}',
		'{"type":"content_block_start","index":2,"content_block":'
			+ '{"type":"tool_use","id":"tu_1","name":"submit_design","input":{}}}',
		'{"type":"content_block_delta","index":2,"delta":'
			+ '{"type":"input_json_delta","partial_json":"{\\"name\\":\\"H"}}',
		'{"type":"content_block_delta","index":2,"delta":'
			+ '{"type":"input_json_delta","partial_json":"ouse\\",\\"bricks\\":[]}"}}',
		'{"type":"content_block_stop","index":2}',
		'{"type":"message_delta","delta":{"stop_reason":"tool_use"},'
			+ '"usage":{"output_tokens":42}}',
		'{"type":"message_stop"}',
	]

	var whole: String = ""
	for event: String in events:
		whole += "event: x\ndata: %s\n\n" % event

	# Split every which way, including through the middle of the three
	# byte characters, which is where the reader used to lose them.
	for chunk: int in [1, 3, 7, 64, 100000]:
		_feed_in(whole.to_utf8_buffer(), chunk)

	# And a stream that stops in the middle must not report success.
	# Cut at an event boundary, not in the middle of one: a half-written
	# JSON object is a different failure and it complains on the console
	# every time, which trains people to ignore the console.
	var cut: int = whole.rfind("\n\n", whole.find('"message_delta"')) + 2
	var truncated := Streamer.Reader.new()
	_pour(truncated, whole.substr(0, cut).to_utf8_buffer(), 40)
	if truncated.finished:
		_failures += 1
		print("  FAIL  a stream cut short reported itself finished")
	else:
		print("  ok    a stream cut short does not report itself finished")

	# An error event is not a finished answer either.
	var failed := Streamer.Reader.new()
	_pour(failed, ('event: error\ndata: {"type":"error","error":'
		+ '{"type":"overloaded_error","message":"Overloaded"}}\n\n')
		.to_utf8_buffer(), 20)
	if failed.finished or failed.started:
		_failures += 1
		print("  FAIL  an error event counted as an answer")
	else:
		print("  ok    an error event is not an answer")

	print("")
	if _failures == 0:
		print("the answer survives being sent in pieces")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _feed_in(bytes: PackedByteArray, chunk: int) -> void:
	var reader := Streamer.Reader.new()
	_pour(reader, bytes, chunk)

	if not reader.finished:
		_failures += 1
		print("  FAIL  in %d-byte pieces: never finished" % chunk)
		return

	var content: Array = reader.message.get("content", [])
	var trouble: PackedStringArray = _wrong(content, reader.message)
	if trouble.is_empty():
		print("  ok    in %s pieces: three blocks, intact" % (
			"whole" if chunk > 1000 else "%d-byte" % chunk))
	else:
		_failures += 1
		print("  FAIL  in %d-byte pieces:" % chunk)
		for line: String in trouble:
			print("        " + line)


## Bytes in, through the same splitting the reader does over the wire.
func _pour(reader: Streamer.Reader, bytes: PackedByteArray,
		chunk: int) -> void:
	var pending := PackedByteArray()
	var at: int = 0
	while at < bytes.size():
		pending.append_array(bytes.slice(at, mini(at + chunk, bytes.size())))
		at += chunk
		var cut: int = Streamer._last_break(pending)
		if cut < 0:
			continue
		for block: String in pending.slice(0, cut) \
				.get_string_from_utf8().split("\n\n", false):
			_take(reader, block)
		pending = pending.slice(cut + 2)
	for block: String in pending.get_string_from_utf8().split("\n\n", false):
		_take(reader, block)


func _take(reader: Streamer.Reader, block: String) -> void:
	for line: String in block.split("\n", false):
		if not line.begins_with("data:"):
			continue
		var parsed: Variant = JSON.parse_string(line.substr(5).strip_edges())
		if typeof(parsed) == TYPE_DICTIONARY:
			reader.take(parsed)


func _wrong(content: Array, message: Dictionary) -> PackedStringArray:
	var trouble := PackedStringArray()
	if content.size() != 3:
		trouble.append("%d blocks, wanted 3" % content.size())
		return trouble

	var thinking: Dictionary = content[0]
	if thinking.get("thinking", "") != "a roof of slopes":
		trouble.append("thinking is %s" % thinking.get("thinking", ""))
	# The signature is what the API checks and what nobody else would
	# notice going missing.
	if thinking.get("signature", "") != "sig123==":
		trouble.append("signature is %s" % thinking.get("signature", ""))

	var text: Dictionary = content[1]
	if text.get("text", "") != "Une maison — café au lait 🧱":
		trouble.append("text came back as: %s" % text.get("text", ""))

	var tool: Dictionary = content[2]
	if tool.get("name", "") != "submit_design":
		trouble.append("tool is %s" % tool.get("name", ""))
	var input: Variant = tool.get("input")
	if typeof(input) != TYPE_DICTIONARY or input.get("name", "") != "House":
		trouble.append("tool input is %s" % [input])

	if message.get("stop_reason", "") != "tool_use":
		trouble.append("stop_reason is %s" % message.get("stop_reason", ""))
	return trouble
