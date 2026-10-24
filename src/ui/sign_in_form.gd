## Signing in, in two steps and without a password.
##
## There is no password anywhere in this app. A password is a thing to
## choose badly, reuse, forget and then reset by email — which is the
## same email, one step later and less securely. So the email is the
## whole of it: ask for a code, type the code.
##
## One form, not two. There is no separate sign-up: a code sent to an
## address nobody has used before makes the account when it is redeemed,
## so there is nothing for a person to choose between.
##
## What is shown never says whether an address has an account. The
## server answers the same way either way, and so does this — otherwise
## a sign-in form becomes a way of asking who is a member.
class_name SignInForm
extends VBoxContainer

enum Step { ADDRESS, CODE }

## orangecheck's mark, mono in white as the button's words are
## (@orangecheck/mark 0.3.0, tools/web/vendor_orangecheck.sh), drawn 14
## units tall and 28 wide, as orangecheck's own button draws it beside 16 px
## words, with its clear space (a quarter of its width) to them.
const ORANGECHECK_MARK := "res://assets/ui/orangecheck-mark-mono-white.svg"
const MARK_TALL := 14.0

var account: Account

var _why: Label
var _email: LineEdit
var _code: LineEdit
var _send: Button
var _verify: Button
var _again: LinkButton
var _resend: LinkButton
var _note: Label
var _orangecheck: Button
var _orangecheck_why: Label
var _step: int = Step.ADDRESS
var _busy: bool = false

signal done


func setup(with_account: Account) -> void:
	account = with_account
	add_theme_constant_override("separation", 8)

	_why = Label.new()
	_why.add_theme_font_size_override("font_size", 13)
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.modulate = Color(1, 1, 1, 0.8)
	add_child(_why)

	_email = LineEdit.new()
	_email.placeholder_text = "you@example.com"
	# Said as what it asks for: its placeholder is an example, not a name.
	_email.accessibility_name = "Email"
	_email.custom_minimum_size = Vector2(0, 36)
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email.keep_editing_on_text_submit = true
	_email.text_submitted.connect(func(_t: String) -> void: _ask())
	add_child(_email)

	_send = Button.new()
	_send.text = "Email me a code"
	_send.custom_minimum_size = Vector2(0, 36)
	_send.focus_mode = Control.FOCUS_NONE
	_send.pressed.connect(_ask)
	add_child(_send)

	_code = LineEdit.new()
	_code.placeholder_text = "The code from the email"
	_code.custom_minimum_size = Vector2(0, 40)
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.add_theme_font_size_override("font_size", 18)
	_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_code.keep_editing_on_text_submit = true
	_code.text_submitted.connect(func(_t: String) -> void: _redeem())
	add_child(_code)

	_verify = Button.new()
	_verify.text = "Sign in"
	_verify.custom_minimum_size = Vector2(0, 36)
	_verify.focus_mode = Control.FOCUS_NONE
	_verify.pressed.connect(_redeem)
	add_child(_verify)

	# Right under the button that caused it, so it reads as the answer.
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 12)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	add_child(_note)

	var links := HFlowContainer.new()
	links.add_theme_constant_override("h_separation", 16)
	add_child(links)
	_resend = Look.link("Send a new code", 12)
	_resend.pressed.connect(_ask)
	links.add_child(_resend)
	_again = Look.link("Use a different address", 12)
	_again.pressed.connect(func() -> void:
		_show(Step.ADDRESS)
		_email.grab_focus())
	links.add_child(_again)

	# orangecheck too, as the deployment offers it (2026-10-23,
	# api/orangecheck.js). On the web its window cannot answer this page,
	# which keeps the isolation the engine's threads need, so the button
	# takes the person to the site's sign-in, which brings them back here
	# signed in (web/profile.js). On the desktop (2026-10-24) it opens in
	# the person's own browser, which hands a code back to this app
	# (Account.sign_in_with_orangecheck).
	_orangecheck = Button.new()
	_orangecheck.text = "Sign in with orangecheck"
	# orangecheck's mark before the words, and its 44 px target
	# (2026-10-24, the owner's step 4).
	_orangecheck.add_theme_constant_override("icon_max_width", roundi(MARK_TALL * 2.0))
	_orangecheck.add_theme_constant_override("h_separation", roundi(MARK_TALL / 2.0))
	_orangecheck.custom_minimum_size = Vector2(0, 44)
	_orangecheck.focus_mode = Control.FOCUS_NONE
	_orangecheck.pressed.connect(_to_orangecheck)
	add_child(_orangecheck)
	_orangecheck_why = Label.new()
	_orangecheck_why.text = ("A Bitcoin wallet, email, Google or GitHub. "
		+ "Brickworks gets an id for you, not your address.")
	_orangecheck_why.add_theme_font_size_override("font_size", 12)
	_orangecheck_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_orangecheck_why.modulate = Color(1, 1, 1, 0.75)
	add_child(_orangecheck_why)
	_draw_mark()

	_show(Step.ADDRESS)


func focus_first() -> void:
	# Shown again now the deployment has answered whether it offers
	# orangecheck to everybody, its mark drawn for the screen it is on.
	_draw_mark()
	if _step == Step.ADDRESS:
		var offered: bool = _orangecheck_offered()
		_orangecheck.visible = offered
		_orangecheck_why.visible = offered
	if _step == Step.ADDRESS:
		_email.grab_focus()
	else:
		_code.grab_focus()


## The form's own controls, for the page to find (Main._tell_page).
func controls_by_name() -> Dictionary:
	return {"signin_email": _email, "signin_send": _send,
		"signin_code": _code, "signin_go": _verify, "signin_orangecheck": _orangecheck}


func _show(step: int) -> void:
	_step = step
	var asking: bool = step == Step.ADDRESS
	_email.visible = asking
	_send.visible = asking
	_code.visible = not asking
	_verify.visible = not asking
	_again.visible = not asking
	_resend.visible = not asking
	var offered: bool = asking and _orangecheck_offered()
	_orangecheck.visible = offered
	_orangecheck_why.visible = offered
	_why.text = ("Your email address is your account. We email you a code "
		+ "to type here — there is no password, and nothing else to make."
		if asking else
		"We sent a code to %s. It works once and expires in ten minutes; "
			% _email.text.strip_edges().to_lower()
		+ "if it is not there, look in spam.")
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
		_show(Step.ADDRESS)
		_say("Enter the email address to sign in with.", false)
		_email.grab_focus()
		return

	var again: bool = _step == Step.CODE
	_set_busy(true)
	if again:
		_say("Sending a new code…", true)
	var problem: String = await account.request_code(address)
	_set_busy(false)
	if not problem.is_empty():
		_say(problem, false)
		return
	# Moves on whether or not an account existed, because the answer is
	# the same either way and the person is now waiting for an email.
	_show(Step.CODE)
	if again:
		_say("Sent a new code. Use the newest one.", true)
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
		_code.text = ""
		_show(Step.ADDRESS)
		done.emit()
		return
	_say(problem, false)
	_code.grab_focus()


## Whether this tab is offered orangecheck: everybody, as the deployment
## says (web/account.js orangecheckOffer, api/_oc_config.js); and on the
## desktop, only where the deployment says where to open it.
func _orangecheck_offered() -> bool:
	return account != null and account.deployment != null and account.deployment.orangecheck_for_everyone \
		and (OS.has_feature("web") or not account.deployment.orangecheck_native.is_empty())


## The mark on the orangecheck button, drawn at the pixels it is shown at.
func _draw_mark() -> void:
	_orangecheck.icon = Icons.texture_for(ORANGECHECK_MARK, MARK_TALL, Icons.density(self))


## To the site's sign-in, which comes back to this very address; on the
## desktop, orangecheck in the person's browser, waited on here. A second
## press starts again, for a browser tab closed by mistake.
func _to_orangecheck() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.assign('/profile?then=' "
			+ "+ encodeURIComponent(location.pathname + location.search))", true)
		return
	_say("Finish signing in with orangecheck in your browser.", true)
	var problem: String = await account.sign_in_with_orangecheck()
	if problem == Account.SUPERSEDED:
		return
	if problem.is_empty():
		_show(Step.ADDRESS)
		done.emit()
		return
	_say(problem, false)


func _set_busy(busy: bool) -> void:
	_busy = busy
	_send.disabled = busy
	_verify.disabled = busy
	_email.editable = not busy
	_code.editable = not busy
	_send.text = "Sending…" if busy and _step == Step.ADDRESS else "Email me a code"
	_verify.text = "Checking…" if busy and _step == Step.CODE else "Sign in"
	if busy:
		_note.visible = false


func _say(text: String, quiet: bool) -> void:
	_note.text = text
	_note.visible = true
	_note.add_theme_color_override("font_color",
		Color(1, 1, 1, 0.75) if quiet else Color(1.0, 0.55, 0.45))
