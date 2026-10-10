## Can a picture of what is wanted get INTO the conversation?
##
##   godot --headless --path . --script src/dev/reference_probe.gd
##
## The assistant designed a named real subject entirely from its own
## memory of it. The loop can say a model is buildable and can look at
## what it built, but nothing in it could say "that is not what a
## Voyager looks like", because pictures only ever went out.
##
## And the obvious way to supply one would have failed after a single
## turn: every picture in the conversation was replaced with the line
## "(a view of an earlier draft)" to keep the conversation small, which
## would have thrown away the one thing in it that knew the subject —
## and relabelled it as the model's own work.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var assistant := Assistant.new()
	assistant.library = library
	get_root().add_child(assistant)
	await process_frame

	# Nothing is listening on this port, so the request fails a moment
	# later and the conversation it built can still be read.
	assistant.stream_replies = false
	assistant.endpoint = "http://127.0.0.1:1/none"
	# Made up. Nothing is sent without a key, and this one goes nowhere
	# but that port.
	assistant.direct_key = "sk-ant-probe"

	var picture := Image.create(64, 48, false, Image.FORMAT_RGB8)
	picture.fill(Color(0.2, 0.4, 0.9))
	_check("a picture can be handed in at all",
		assistant.remember_reference(picture))

	assistant.design("a starship")
	_check("it rides at the head of the conversation",
		_pictures_in(assistant._messages[0]) == 1)
	_check("and the brief is still there too",
		_text_in(assistant._messages[0]).contains("starship"))

	# A render of a draft, arriving later the way one really does.
	assistant._messages.append({"role": "user", "content": [
		{"type": "image", "source": {"type": "base64",
			"media_type": "image/png", "data": "x"}}]})

	# Kept while there are few: rewriting an earlier message every turn
	# meant nothing after it could be read back from the cache.
	assistant._forget_old_pictures()
	_check("a draft is kept while the pictures are few",
		_pictures_in(assistant._messages[1]) == 1)

	# And once they add up, every draft goes in one sweep.
	assistant._messages.append({"role": "user", "content": [
		{"type": "image", "source": {"type": "base64",
			"media_type": "image/png",
			"data": "x".repeat(Assistant.MOST_PICTURE_BYTES)}}]})
	assistant._forget_old_pictures()
	_check("the reference is still a picture afterwards",
		_pictures_in(assistant._messages[0]) == 1)
	_check("...while the views of drafts are not",
		_pictures_in(assistant._messages[1]) == 0
			and _pictures_in(assistant._messages[2]) == 0)

	print("")
	if _failures == 0:
		print("a reference gets in and stays in")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


static func _pictures_in(message: Dictionary) -> int:
	var content: Variant = message.get("content")
	if typeof(content) != TYPE_ARRAY:
		return 0
	var found: int = 0
	for block: Variant in content:
		if typeof(block) == TYPE_DICTIONARY \
				and block.get("type", "") == "image":
			found += 1
	return found


static func _text_in(message: Dictionary) -> String:
	var content: Variant = message.get("content")
	if typeof(content) != TYPE_ARRAY:
		return str(content)
	var out: String = ""
	for block: Variant in content:
		if typeof(block) == TYPE_DICTIONARY:
			out += str(block.get("text", ""))
	return out


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
