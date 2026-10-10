## Where someone puts in their own Anthropic key.
##
## The wording matters more than the widget. Being asked for an API key
## by a web page is, correctly, something people are wary of, and the
## only useful answer is to say exactly where it goes and exactly where
## it stays — in the place they are being asked, not in a policy
## document nobody opens.
##
## So: it goes to Anthropic and nowhere else, it is kept on this device,
## and there is a button that removes it. All three are on screen.
class_name KeyForm
extends VBoxContainer

var _field: LineEdit
var _note: Label
var _use: Button
var _remember: CheckBox

## Asks Anthropic whether a key works, then calls back with the HTTP code
## (0 when nothing answered). Replaceable, so a probe can answer instead.
var check_key: Callable = _ask_anthropic

signal accepted()


## What a design costs and how long it takes at the default settings,
## measured rather than guessed, 2026-10-09, Opus 5.5: "a small red house"
## at high effort took 684 s and $2.42 for 260 parts, at medium 249 s and
## $0.72 for 127; castles at high took 30-46 minutes and $5-10.
const EXPECT := ("Anthropic bills it per design. At the default setting a "
	+ "small house took 11 minutes and $2.40, a castle 45 minutes and $5–10; "
	+ "medium effort is about a third.")


func setup() -> void:
	add_theme_constant_override("separation", 8)

	# What it is, before what it needs. This opened on "The assistant runs
	# on your own Anthropic key", in eleven-point grey at the foot of an
	# empty panel — the one feature the app is built around, introduced
	# as a billing arrangement.
	var title := Label.new()
	title.text = "Design with Claude"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	var what := Label.new()
	what.text = ("Describe a model and Claude designs it brick by brick, "
		+ "checking every brick holds. Watch it build, then ask for "
		+ "changes or carry on by hand.")
	what.add_theme_font_size_override("font_size", 13)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(what)

	# Two ways in, side by side in the reading order, each under its own
	# heading. Before, the key's form ran to seven paragraphs and the
	# other way, the person's Claude plan, started below the fold.
	add_child(_line("With your Anthropic API key", 14, 1.0))

	_field = LineEdit.new()
	_field.placeholder_text = "Paste your key: sk-ant-…"
	_field.secret = true
	_field.custom_minimum_size = Vector2(0, 34)
	_field.text_submitted.connect(func(_t: String) -> void: _keep())
	add_child(_field)

	_remember = CheckBox.new()
	_remember.text = "Remember it on this device"
	_remember.button_pressed = true
	_remember.add_theme_font_size_override("font_size", 12)
	_remember.tooltip_text = ("Kept so you need not paste it again, where "
		+ "other programs running as you could read it. Untick to keep it "
		+ "for this visit only — the right choice on a shared computer.")
	add_child(_remember)

	_use = Button.new()
	_use.text = "Use this key"
	_use.custom_minimum_size = Vector2(0, 34)
	_use.pressed.connect(_keep)
	add_child(_use)

	# Right under the button that caused it. At the foot of the form it
	# was below two paragraphs, and read as one more of them.
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 12)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	add_child(_note)
	# A note is about the last key pasted. Shown again later, the form
	# starts clean rather than answering a question nobody just asked.
	visibility_changed.connect(func() -> void:
		if visible:
			_note.visible = false)

	# Where it goes and the safest key to give it, in one breath: its own,
	# in a workspace with a spend limit. The Console does both; nobody
	# does them unless told.
	add_child(_line("Sent only to Anthropic, never to us. Safest is a key "
		+ "just for this, in a Console workspace with a spend limit.", 11, 0.65))
	add_child(_line(EXPECT, 11, 0.65))

	var where := LinkButton.new()
	where.text = "No key yet? Get one at console.anthropic.com"
	where.uri = "https://console.anthropic.com/settings/keys"
	where.add_theme_font_size_override("font_size", 12)
	where.modulate = Color(0.65, 0.8, 1.0, 1.0)
	add_child(where)


func _line(text: String, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, alpha)
	return label


func controls_by_name() -> Dictionary:
	return {"key_field": _field, "use_key": _use}


func focus_field() -> void:
	if _field != null:
		_field.grab_focus()


func _keep() -> void:
	var problem: String = OwnKey.problem_with(_field.text)
	if not problem.is_empty():
		_say(problem, true)
		_field.grab_focus()
		return
	# Asked before it is kept. A key with a typo used to be accepted here
	# and refused only when a design was sent, minutes and a brief later.
	var key: String = _field.text.strip_edges()
	_use.disabled = true
	_use.text = "Checking it with Anthropic…"
	check_key.call(key, func(code: int) -> void:
		_use.disabled = false
		_use.text = "Use this key"
		if code == 401 or code == 403:
			_say("Anthropic refused that key. Check it at "
				+ "console.anthropic.com and paste it again.", true)
			_field.grab_focus()
			return
		OwnKey.remember(key, _remember.button_pressed)
		# Cleared from the box as well as accepted: leaving a key sitting
		# in a field is one screenshot away from being someone else's.
		_field.text = ""
		if code == 200:
			_note.visible = false
		else:
			# Kept anyway: nothing answered is not the same as no, and a
			# key that is fine should not be refused for a dropped call.
			_say("Could not reach Anthropic to check it; it will be tried "
				+ "when you design.", false)
		accepted.emit())


func _say(text: String, wrong: bool) -> void:
	_note.text = text
	_note.add_theme_color_override("font_color",
		Color(1.0, 0.55, 0.45) if wrong else Color(1, 1, 1, 0.75))
	_note.visible = true


## The models list costs nothing and needs only a working key, so it is
## the question to ask. Straight to Anthropic, as every request with the
## key is, and never anywhere else.
func _ask_anthropic(key: String, done: Callable) -> void:
	var http := HTTPRequest.new()
	# Generous: a slow phone, or a browser drawing in software on a busy
	# machine, took longer than fifteen seconds to hear the answer, and a
	# check that gives up keeps the key unchecked.
	http.timeout = 30.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int,
			_headers: PackedStringArray, _body: PackedByteArray) -> void:
		http.queue_free()
		done.call(code if result == HTTPRequest.RESULT_SUCCESS else 0))
	var headers := PackedStringArray(["x-api-key: " + key,
		"anthropic-version: 2023-06-01"])
	if OS.has_feature("web"):
		headers.append("anthropic-dangerous-direct-browser-access: true")
	if http.request("https://api.anthropic.com/v1/models?limit=1",
			headers) != OK:
		http.queue_free()
		done.call(0)
