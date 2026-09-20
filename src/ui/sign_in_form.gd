## The sign-in panel, shown where the composer normally sits.
##
## It appears in exactly one place — above the assistant — and it says so,
## because a sign-in box that turns up without explanation reads as a
## paywall over the whole app. It is not: everything else is already
## working behind it, and the form says that in as many words.
##
## One form does both jobs. Asking someone to decide between "sign in"
## and "create an account" before they have typed anything is a decision
## they cannot make yet, so the fields come first and the two buttons sit
## under them.
class_name SignInForm
extends VBoxContainer

var account: Account

var _email: LineEdit
var _password: LineEdit
var _sign_in: Button
var _create: Button
var _note: Label
var _busy: bool = false

signal done


func setup(with_account: Account) -> void:
	account = with_account
	add_theme_constant_override("separation", 6)

	var why := Label.new()
	why.text = ("The assistant designs with a model that costs money to "
		+ "run, so it needs an account. Building, the catalogue, saving "
		+ "and loading stay free and need none.")
	why.add_theme_font_size_override("font_size", 11)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.modulate = Color(1, 1, 1, 0.62)
	add_child(why)

	_email = LineEdit.new()
	_email.placeholder_text = "you@example.com"
	# So a password manager and the browser's autofill recognise it in the
	# web build, and so typing an address does not open the build's own
	# single-key shortcuts.
	_email.keep_editing_on_text_submit = true
	_email.text_submitted.connect(func(_t: String) -> void: _attempt(false))
	add_child(_email)

	_password = LineEdit.new()
	_password.placeholder_text = "password"
	_password.secret = true
	_password.text_submitted.connect(func(_t: String) -> void: _attempt(false))
	add_child(_password)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	_sign_in = Button.new()
	_sign_in.text = "Sign in"
	_sign_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sign_in.pressed.connect(func() -> void: _attempt(false))
	row.add_child(_sign_in)

	_create = Button.new()
	_create.text = "Create account"
	_create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create.pressed.connect(func() -> void: _attempt(true))
	row.add_child(_create)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 11)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	add_child(_note)


func focus_first() -> void:
	if _email != null:
		_email.grab_focus()


func _attempt(creating: bool) -> void:
	if _busy or account == null:
		return
	var address: String = _email.text.strip_edges()
	var secret: String = _password.text

	# Checked here as well as on the server, because a round trip to be
	# told the field is empty is a round trip nobody needed.
	if address.is_empty() or not address.contains("@"):
		_say("Enter the email address to use.", false)
		_email.grab_focus()
		return
	if secret.length() < 10 and creating:
		_say("A new password needs at least ten characters.", false)
		_password.grab_focus()
		return
	if secret.is_empty():
		_say("Enter your password.", false)
		_password.grab_focus()
		return

	_set_busy(true)
	var problem: String = (await account.sign_up(address, secret) if creating
		else await account.sign_in(address, secret))
	_set_busy(false)

	if problem.is_empty():
		_password.text = ""
		done.emit()
		return
	_say(problem, false)
	_password.grab_focus()


func _set_busy(busy: bool) -> void:
	_busy = busy
	_sign_in.disabled = busy
	_create.disabled = busy
	_email.editable = not busy
	_password.editable = not busy
	if busy:
		_say("Checking…", true)


func _say(text: String, quiet: bool) -> void:
	_note.text = text
	_note.visible = true
	_note.add_theme_color_override("font_color",
		Color(1, 1, 1, 0.6) if quiet else Color(1.0, 0.55, 0.45))
