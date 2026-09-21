## The model's answer as it is written, not once it is finished.
##
## A design of two hundred bricks takes a minute or two to come back.
## Waiting for the whole message and then showing it means the person
## watches a spinner for the part that is actually interesting — the
## model deciding, brick by brick, what the thing is made of. Anthropic
## will stream that; it arrives as server-sent events, one fragment of
## JSON at a time.
##
## [HTTPRequest] cannot read a response before it ends, so this drives
## [HTTPClient] by hand. In exchange the caller gets the fragments as
## they land AND, at the end, exactly the same body a plain request
## would have returned — so everything downstream of the answer is
## untouched by the fact that it arrived in pieces.
class_name Streamer
extends Node

## A piece of a tool call's arguments, as written. Not valid JSON on its
## own; whoever wants to act on it early has to cope with that.
signal fragment(tool_name: String, piece: String)
## Prose, as written.
signal spoke(piece: String)
## The whole thing, shaped as [HTTPRequest] would have shaped it:
## result, code, headers, body.
signal done(reply: Array)

## How long to wait with nothing arriving before giving up. Generous:
## adaptive thinking can spend a while before the first token, and the
## cost of being impatient is a design thrown away at random.
const QUIET_SECONDS := 120.0


static func split_url(url: String) -> Dictionary:
	var tls: bool = url.begins_with("https://")
	var mark: int = url.find("://")
	var rest: String = url.substr(mark + 3) if mark >= 0 else url
	var slash: int = rest.find("/")
	var authority: String = rest if slash < 0 else rest.substr(0, slash)
	var path: String = "/" if slash < 0 else rest.substr(slash)
	var port: int = 443 if tls else 80
	var colon: int = authority.rfind(":")
	if colon > 0:
		port = int(authority.substr(colon + 1))
		authority = authority.substr(0, colon)
	return {"host": authority, "port": port, "tls": tls, "path": path}


## Stop reading and give nothing back.
##
## The caller is awaiting [signal done]; leaving it awaiting for ever
## would leak the turn, so a stop is reported like any other failure and
## whoever asked for it is expected to have already decided what the
## model should look like.
func stop() -> void:
	_stopped = true


var _stopped: bool = false


func run(url: String, headers: PackedStringArray, body: String) -> void:
	var where: Dictionary = split_url(url)
	var client := HTTPClient.new()
	var tls: TLSOptions = TLSOptions.client() if where["tls"] else null
	if client.connect_to_host(where["host"], where["port"], tls) != OK:
		_fail("could not reach %s" % where["host"])
		return

	var deadline: int = _in(QUIET_SECONDS)
	while client.get_status() in [
			HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		client.poll()
		await get_tree().process_frame
		if _stopped:
			_fail("cancelled")
			return
		if Time.get_ticks_msec() > deadline:
			_fail("timed out connecting to %s" % where["host"])
			return
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		_fail("could not connect to %s" % where["host"])
		return

	var sent: PackedStringArray = headers.duplicate()
	sent.append("accept: text/event-stream")
	if client.request(HTTPClient.METHOD_POST, where["path"], sent, body) != OK:
		_fail("could not send the request")
		return

	deadline = _in(QUIET_SECONDS)
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		await get_tree().process_frame
		if _stopped:
			_fail("cancelled")
			return
		if Time.get_ticks_msec() > deadline:
			_fail("timed out waiting for an answer")
			return

	if not client.has_response():
		_fail("no answer")
		return

	var code: int = client.get_response_code()
	var reply_headers := PackedStringArray(client.get_response_headers())

	# An error comes back as plain JSON rather than as a stream, and the
	# caller already knows how to read one of those. Hand it over whole.
	if code != 200:
		var raw := PackedByteArray()
		deadline = _in(QUIET_SECONDS)
		while client.get_status() == HTTPClient.STATUS_BODY:
			client.poll()
			var piece: PackedByteArray = client.read_response_body_chunk()
			if piece.is_empty():
				await get_tree().process_frame
				if Time.get_ticks_msec() > deadline:
					break
			else:
				deadline = _in(QUIET_SECONDS)
				raw.append_array(piece)
		done.emit([HTTPRequest.RESULT_SUCCESS, code, reply_headers, raw])
		return

	var reader := Reader.new()
	# Kept as bytes rather than decoded chunk by chunk. A character
	# outside ASCII is two to four bytes and the network splits where it
	# likes, so decoding each chunk on its own turns any character
	# unlucky enough to straddle a boundary into a replacement
	# character — in the middle of the model's prose, or of a part
	# number, and there is no way to tell afterwards.
	#
	# Events are separated by a blank line, and a newline byte cannot
	# appear inside a multi-byte character, so splitting on bytes and
	# decoding whole events is safe.
	var pending := PackedByteArray()
	deadline = _in(QUIET_SECONDS)
	while client.get_status() == HTTPClient.STATUS_BODY:
		if _stopped:
			_fail("cancelled")
			return
		client.poll()
		var piece: PackedByteArray = client.read_response_body_chunk()
		if piece.is_empty():
			await get_tree().process_frame
			if Time.get_ticks_msec() > deadline:
				_fail("the answer stopped part way through")
				return
			continue
		deadline = _in(QUIET_SECONDS)
		pending.append_array(piece)
		# Anything after the last blank line is half an event and waits
		# for the rest of itself.
		var cut: int = _last_break(pending)
		if cut < 0:
			continue
		for block: String in pending.slice(0, cut) \
				.get_string_from_utf8().split("\n\n", false):
			_feed(reader, block)
		pending = pending.slice(cut + 2)

	for block: String in pending.get_string_from_utf8().split("\n\n", false):
		_feed(reader, block)

	# Finished, not merely started.
	#
	# The test used to be "did a message_start arrive", which is true a
	# second into every request — so a connection dropped three minutes
	# later came back as a successful HTTP 200 whose message had no
	# content at all. That skipped the retry that exists for exactly
	# this, and put an assistant message with an empty content array
	# into the transcript, which the API refuses on the next turn and on
	# every turn after it.
	if not reader.finished:
		_fail("the answer stopped part way through")
		return
	done.emit([HTTPRequest.RESULT_SUCCESS, code, reply_headers,
		JSON.stringify(reader.message).to_utf8_buffer()])


## Where the last blank line is, in bytes. -1 when there is not one yet.
static func _last_break(bytes: PackedByteArray) -> int:
	for n: int in range(bytes.size() - 2, -1, -1):
		if bytes[n] == 10 and bytes[n + 1] == 10:
			return n
	return -1


func _feed(reader: Reader, block: String) -> void:
	for line: String in block.split("\n", false):
		if not line.begins_with("data:"):
			continue
		var parsed: Variant = JSON.parse_string(
			line.substr(5).strip_edges())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var out: Dictionary = reader.take(parsed)
		if out.has("text"):
			spoke.emit(str(out["text"]))
		if out.has("fragment"):
			fragment.emit(str(out["tool"]), str(out["fragment"]))


static func _in(seconds: float) -> int:
	return Time.get_ticks_msec() + int(seconds * 1000.0)


func _fail(why: String) -> void:
	done.emit([HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(),
		JSON.stringify({"error": {"message": why}}).to_utf8_buffer()])


## Puts the pieces back into the message they came from.
##
## The point is that what comes out is indistinguishable from an
## unstreamed reply — same blocks, same order, same thinking
## signatures. Anything less and the next turn sends back a mangled
## transcript, which the API rejects in ways that are hard to read.
class Reader extends RefCounted:
	var message: Dictionary = {}
	var started: bool = false
	## Set only by message_stop. What tells a complete answer from a
	## connection that died in the middle of one.
	var finished: bool = false
	var _blocks: Array = []
	## Index -> the tool arguments so far, as text. They arrive as JSON
	## in fragments and are only parseable once the block closes.
	var _partial: Dictionary = {}

	func take(event: Dictionary) -> Dictionary:
		match str(event.get("type", "")):
			"message_start":
				message = event.get("message", {}).duplicate(true)
				message["content"] = []
				_blocks = []
				started = true
			"content_block_start":
				var block: Dictionary = event.get(
					"content_block", {}).duplicate(true)
				var index: int = int(event.get("index", _blocks.size()))
				while _blocks.size() <= index:
					_blocks.append({})
				_blocks[index] = block
				if block.get("type", "") == "tool_use":
					_partial[index] = ""
					block["input"] = {}
			"content_block_delta":
				return _delta(event)
			"content_block_stop":
				var index: int = int(event.get("index", -1))
				if _partial.has(index):
					var text: String = str(_partial[index]).strip_edges()
					# A tool taking no arguments sends no fragments at
					# all rather than "{}". Parsing the empty string
					# gives the right answer and complains about it in
					# the console every time, which buries anything
					# real.
					var parsed: Variant = (JSON.parse_string(text)
						if not text.is_empty() else {})
					_blocks[index]["input"] = (parsed
						if typeof(parsed) == TYPE_DICTIONARY else {})
					_partial.erase(index)
			"message_delta":
				var delta: Dictionary = event.get("delta", {})
				for key: String in delta:
					message[key] = delta[key]
				if event.has("usage"):
					message["usage"] = event["usage"]
			"message_stop":
				message["content"] = _blocks
				finished = true
			"error":
				# Not finished: an error event means the answer is not
				# coming, and saying so is what makes the caller retry
				# rather than carry on with half a transcript.
				message = {"error": event.get("error", {})}
				started = false
		return {}

	func _delta(event: Dictionary) -> Dictionary:
		var index: int = int(event.get("index", -1))
		if index < 0 or index >= _blocks.size():
			return {}
		var delta: Dictionary = event.get("delta", {})
		var block: Dictionary = _blocks[index]
		match str(delta.get("type", "")):
			"text_delta":
				var piece: String = str(delta.get("text", ""))
				block["text"] = str(block.get("text", "")) + piece
				return {"text": piece}
			"thinking_delta":
				block["thinking"] = (str(block.get("thinking", ""))
					+ str(delta.get("thinking", "")))
			"signature_delta":
				block["signature"] = (str(block.get("signature", ""))
					+ str(delta.get("signature", "")))
			"input_json_delta":
				var piece: String = str(delta.get("partial_json", ""))
				_partial[index] = str(_partial.get(index, "")) + piece
				return {"tool": str(block.get("name", "")),
					"fragment": piece}
		return {}
