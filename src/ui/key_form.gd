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


func setup() -> void:
	add_theme_constant_override("separation", 7)

	var why := Label.new()
	why.text = ("The assistant runs on your own Anthropic key. Paste one "
		+ "and it works straight away.")
	why.add_theme_font_size_override("font_size", 11)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.modulate = Color(1, 1, 1, 0.72)
	add_child(why)

	_field = LineEdit.new()
	_field.placeholder_text = "sk-ant-…"
	_field.secret = true
	_field.text_submitted.connect(func(_t: String) -> void: _keep())
	add_child(_field)

	_use = Button.new()
	_use.text = "Use this key"
	_use.pressed.connect(_keep)
	add_child(_use)

	# The three facts, in the order people want them.
	var terms := Label.new()
	terms.text = ("It goes from this machine straight to Anthropic — never "
		+ "to us, so there is nothing of yours on our server to log or "
		+ "leak. It is kept on this device so you need not type it again, "
		+ "and anything else running as you can read it. Forget it and "
		+ "nothing of it remains. Anthropic bills you for what it uses.")
	terms.add_theme_font_size_override("font_size", 10)
	terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terms.modulate = Color(1, 1, 1, 0.46)
	add_child(terms)

	var where := LinkButton.new()
	where.text = "Get a key from console.anthropic.com"
	where.uri = "https://console.anthropic.com/settings/keys"
	where.add_theme_font_size_override("font_size", 10)
	where.modulate = Color(1, 1, 1, 0.55)
	add_child(where)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 11)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	add_child(_note)

	var instead := LinkButton.new()
	instead.text = "Or sign in, if the assistant is included for your account"
	instead.add_theme_font_size_override("font_size", 10)
	instead.modulate = Color(1, 1, 1, 0.42)
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
