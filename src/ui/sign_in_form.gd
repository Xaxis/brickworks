## Signing in, in two steps and without a password.
##
## There is no password anywhere in this app. A password is a thing to
## choose badly, reuse, forget and then reset by email — which is the
## same email, one step later and less securely. So the email is the
## whole of it: ask for a code, type the code.
##
## One form, not two. There is no separate sign-up: a code sent to an
## address nobody has used before makes the account when it is redeemed,
## so there is nothing for a person to choose between and nothing for us
## to keep in step.
##
## What is shown never says whether an address has an account. The
## server answers the same way either way, and so does this — otherwise
## a sign-in form becomes a way of asking who is a member.
class_name SignInForm
extends VBoxContainer

enum Step { ADDRESS, CODE }

var account: Account

var _why: Label
var _email: LineEdit
var _code: LineEdit
var _send: Button
var _verify: Button
var _again: LinkButton
var _note: Label
var _step: int = Step.ADDRESS
var _busy: bool = false

signal done


func setup(with_account: Account) -> void:
	account = with_account
	add_theme_constant_override("separation", 6)

	_why = Label.new()
	_why.add_theme_font_size_override("font_size", 11)
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.modulate = Color(1, 1, 1, 0.62)
	add_child(_why)

	_email = LineEdit.new()
	_email.placeholder_text = "you@example.com"
	_email.keep_editing_on_text_submit = true
	_email.text_submitted.connect(func(_t: String) -> void: _ask())
	add_child(_email)

	_send = Button.new()
	_send.text = "Email me a code"
	_send.pressed.connect(_ask)
	add_child(_send)

	_code = LineEdit.new()
	_code.placeholder_text = "the code from the email"
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.keep_editing_on_text_submit = true
	_code.text_submitted.connect(func(_t: String) -> void: _redeem())
	add_child(_code)

	_verify = Button.new()
	_verify.text = "Sign in"
	_verify.pressed.connect(_redeem)
	add_child(_verify)

	_again = LinkButton.new()
	_again.text = "Use a different address"
	_again.add_theme_font_size_override("font_size", 10)
	_again.modulate = Color(1, 1, 1, 0.5)
	_again.pressed.connect(func() -> void: _show(Step.ADDRESS))
	add_child(_again)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 11)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	add_child(_note)

	_show(Step.ADDRESS)


func focus_first() -> void:
	if _step == Step.ADDRESS:
		_email.grab_focus()
	else:
		_code.grab_focus()


func _show(step: int) -> void:
	_step = step
	var asking: bool = step == Step.ADDRESS
	_email.visible = asking
	_send.visible = asking
	_code.visible = not asking
	_verify.visible = not asking
	_again.visible = not asking
	_why.text = ("No password. We email you a code and you type it in."
		if asking else
		"Check %s for a code. It works once and expires in ten minutes."
			% _email.text.strip_edges())
	if not asking:
		_code.text = ""
	_note.visible = false


func _ask() -> void:
	if _busy:
		return
	var address: String = _email.text.strip_edges()
	# Checked here as well as on the server, because a round trip to be
	# told the field is empty is a round trip nobody needed.
	if address.is_empty() or not address.contains("@") or not address.contains("."):
		_say("Enter the email address to use.", false)
		_email.grab_focus()
		return

	_set_busy(true)
	var problem: String = await account.request_code(address)
	_set_busy(false)
	if not problem.is_empty():
		_say(problem, false)
		return
	# Moves on whether or not an account existed, because the answer is
	# the same either way and the person is now waiting for an email.
	_show(Step.CODE)
	_code.grab_focus()


func _redeem() -> void:
	if _busy:
		return
	var typed: String = _code.text.strip_edges()
	if typed.is_empty():
		_say("Enter the code from the email.", false)
		_code.grab_focus()
		return

	_set_busy(true)
	var problem: String = await account.verify_code(_email.text.strip_edges(), typed)
	_set_busy(false)
	if problem.is_empty():
		done.emit()
		return
	_say(problem, false)
	_code.grab_focus()


func _set_busy(busy: bool) -> void:
	_busy = busy
	_send.disabled = busy
	_verify.disabled = busy
	_email.editable = not busy
	_code.editable = not busy
	if busy:
		_say("Sending…" if _step == Step.ADDRESS else "Checking…", true)


func _say(text: String, quiet: bool) -> void:
	_note.text = text
	_note.visible = true
	_note.add_theme_color_override("font_color",
		Color(1, 1, 1, 0.6) if quiet else Color(1.0, 0.55, 0.45))
