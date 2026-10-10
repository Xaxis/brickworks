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

	_use = Button.new()
	_use.text = "Use this key"
	_use.custom_minimum_size = Vector2(0, 34)
	_use.pressed.connect(_keep)
	add_child(_use)

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


func focus_field() -> void:
	if _field != null:
		_field.grab_focus()


func _keep() -> void:
	var problem: String = OwnKey.remember(_field.text)
	if not problem.is_empty():
		_note.text = problem
		_note.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		_note.visible = true
		_field.grab_focus()
		return
	# Cleared from the box as well as accepted: leaving a key sitting in
	# a field is one screenshot away from being someone else's.
	_field.text = ""
	_note.visible = false
	accepted.emit()
