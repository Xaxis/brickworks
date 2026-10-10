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
signal sign_in_wanted()


## What a design costs and how long it takes at the default settings,
## measured rather than guessed, 2026-10-09, Opus 5.5: "a small red house"
## at high effort took 684 s and $2.42 for 260 parts, at medium 249 s and
## $0.72 for 127; castles at high took 30-46 minutes and $5-10.
const EXPECT := ("Anthropic bills your key for what each design uses. At "
	+ "the default setting a small house took 11 minutes and $2.40, a castle "
	+ "45 minutes and $5–10. Medium effort is about a third of the time and "
	+ "cost, with less detail.")


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
	what.text = ("Describe a model — “a lighthouse on a rocky base” — and "
		+ "the assistant designs it brick by brick, checking every brick "
		+ "holds. Watch it build, then ask for changes or carry on by hand.")
	what.add_theme_font_size_override("font_size", 13)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(what)

	var how := Label.new()
	how.text = "It runs on your own Anthropic API key. " + EXPECT
	how.add_theme_font_size_override("font_size", 12)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.modulate = Color(1, 1, 1, 0.75)
	add_child(how)

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
	_remember.tooltip_text = ("Untick to keep it for this visit only — "
		+ "the right choice on a computer someone else uses.")
	add_child(_remember)

	_use = Button.new()
	_use.text = "Use this key"
	_use.custom_minimum_size = Vector2(0, 34)
	_use.pressed.connect(_keep)
	add_child(_use)

	# The safest key to give any app, this one included: its own, in a
	# workspace with a spend limit, set to expire. Anthropic's Console
	# does all three; nobody does them unless told.
	var safer := Label.new()
	safer.text = ("Safest: make a key just for Brickworks, in a Console "
		+ "workspace with a monthly spend limit, set to expire. Then the "
		+ "most it can ever cost is the limit you chose.")
	safer.add_theme_font_size_override("font_size", 12)
	safer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safer.modulate = Color(1, 1, 1, 0.75)
	add_child(safer)

	# The three facts, in the order people want them.
	var terms := Label.new()
	terms.text = ("It goes from this machine straight to Anthropic — never "
		+ "to us, so there is nothing of yours on our server to log or "
		+ "leak. It is kept on this device so you need not type it again, "
		+ "and anything else running as you can read it. Forget it and "
		+ "nothing of it remains. Anthropic bills you for what it uses.")
	terms.add_theme_font_size_override("font_size", 11)
	terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terms.modulate = Color(1, 1, 1, 0.6)

	var where := LinkButton.new()
	where.text = "No key yet? Get one at console.anthropic.com"
	where.uri = "https://console.anthropic.com/settings/keys"
	where.add_theme_font_size_override("font_size", 12)
	where.modulate = Color(0.65, 0.8, 1.0, 1.0)
	add_child(where)
	add_child(terms)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 11)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	add_child(_note)

	var instead := LinkButton.new()
	instead.text = "Or sign in, if the assistant is included for your account"
	instead.add_theme_font_size_override("font_size", 11)
	instead.modulate = Color(1, 1, 1, 0.55)
	instead.pressed.connect(func() -> void: sign_in_wanted.emit())
	add_child(instead)


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
	http.timeout = 15.0
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
