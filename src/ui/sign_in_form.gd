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
##
## As the site's dialog has it (signinux, 2026-11-13, web/account.js), in
## the same words and order: the address and Email me a code, then "or",
## then Sign in with orangecheck, each button as tall and as wide as the
## others. The code is typed one digit to a box ([CodeBoxes]), as many as
## the deployment says it has (eight), and the last digit signs in by
## itself; a wrong or expired code shakes the row, empties it and puts the
## keys back in the first box, where a limit or no connection keeps the
## digits for another try.
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
var _code_row: CodeBoxes
var _send: Button
var _verify: Button
var _again: LinkButton
var _resend: LinkButton
var _note: Label
var _or: HBoxContainer
var _orangecheck: Button
var _orangecheck_why: Label
## What the orangecheck button started says, under it, and Cancel while the
## desktop waits on the browser.
var _oc_said: Label
var _oc_cancel: LinkButton
## Which press of the orangecheck button is the latest: an older one's
## wait, ended by a newer press, says nothing.
var _oc_try: int = 0
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
	_email.custom_minimum_size = Vector2(0, 44)
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email.keep_editing_on_text_submit = true
	_email.text_submitted.connect(func(_t: String) -> void: _ask())
	add_child(_email)

	# Each way in a 44 px button the form's width, as the site's are.
	_send = Button.new()
	_send.text = "Email me a code"
	_send.custom_minimum_size = Vector2(0, 44)
	_send.focus_mode = Control.FOCUS_NONE
	_send.pressed.connect(_ask)
	add_child(_send)

	_code_row = CodeBoxes.new()
	_code_row.filled.connect(func(_digits: String) -> void: _redeem())
	_code_row.submitted.connect(_redeem)
	add_child(_code_row)

	_verify = Button.new()
	_verify.text = "Sign in"
	_verify.custom_minimum_size = Vector2(0, 44)
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

	# Or: the second way in, apart from the first.
	_or = HBoxContainer.new()
	_or.add_theme_constant_override("separation", 10)
	for at: int in 3:
		if at == 1:
			var word := Label.new()
			word.text = "or"
			word.add_theme_font_size_override("font_size", 12)
			word.modulate = Color(1, 1, 1, 0.6)
			_or.add_child(word)
		else:
			var line := HSeparator.new()
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_or.add_child(line)
	add_child(_or)

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
	_oc_said = Label.new()
	_oc_said.add_theme_font_size_override("font_size", 12)
	_oc_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_oc_said.visible = false
	add_child(_oc_said)
	_oc_cancel = Look.link("Cancel", 12)
	_oc_cancel.visible = false
	_oc_cancel.pressed.connect(func() -> void: account.cancel_orangecheck())
	add_child(_oc_cancel)
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
		_or.visible = offered
	if _step == Step.ADDRESS:
		_email.grab_focus()
	else:
		_code_row.focus_first(true)


## The form's own controls, for the page to find (Main._tell_page).
func controls_by_name() -> Dictionary:
	# signin_code is the first box: a flow clicks it and types the whole code.
	return {"signin_email": _email, "signin_send": _send,
		"signin_code": _code_row.first_box(), "signin_code_row": _code_row,
		"signin_go": _verify, "signin_orangecheck": _orangecheck}


func _show(step: int) -> void:
	_step = step
	var asking: bool = step == Step.ADDRESS
	_email.visible = asking
	_send.visible = asking
	_code_row.visible = not asking
	_verify.visible = not asking
	_again.visible = not asking
	_resend.visible = not asking
	var offered: bool = asking and _orangecheck_offered()
	_orangecheck.visible = offered
	_orangecheck_why.visible = offered
	_or.visible = offered
	if not offered:
		_oc_said.visible = false
		_oc_cancel.visible = false
	_why.text = ("Your email address is your account. We email you a code "
		+ "to type here — there is no password, and nothing else to make."
		if asking else
		"We sent a code to %s. It works once and expires in ten minutes; "
			% _email.text.strip_edges().to_lower()
		+ "if it is not there, look in spam.")
	if not asking:
		var address: String = _email.text.strip_edges().to_lower()
		_code_row.setup(account.code_digits if account != null else 8)
		_code_row.set_label("The code sent to %s" % address)
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
	_code_row.focus_first()


func _redeem() -> void:
	if _busy or _step != Step.CODE:
		return
	var typed: String = _code_row.code()
	if not _code_row.is_full():
		# Nothing sent for a code with a box still empty.
		_say("Enter all %d digits of the code." % _code_row.count(), false)
		_code_row.focus_first(true)
		return

	_set_busy(true)
	var problem: String = await account.verify_code(_email.text.strip_edges(), typed)
	_set_busy(false)
	if problem.is_empty():
		_code_row.clear()
		_show(Step.ADDRESS)
		done.emit()
		return
	if problem == Account.WRONG_CODE:
		# Refused: shaken, emptied, the keys back in the first box.
		_code_row.clear()
		_code_row.shake()
		_code_row.focus_first()
	else:
		# A limit or no connection: the same digits, to try again.
		_code_row.focus_first(true)
	_say(problem, false)


## Whether this tab is offered orangecheck: everybody, as the deployment
## says (web/account.js orangecheckOffer, api/_oc_config.js); and on the
## desktop, only where the deployment says where to open it.
func _orangecheck_offered() -> bool:
	return account != null and account.deployment != null and account.deployment.orangecheck_for_everyone \
		and (OS.has_feature("web") or not account.deployment.orangecheck_native.is_empty())


## The mark on the orangecheck button, drawn at the pixels it is shown at.
func _draw_mark() -> void:
	_orangecheck.icon = Icons.icon_for(ORANGECHECK_MARK, MARK_TALL, Icons.density(self))


## To the site's sign-in, which comes back to this very address; on the
## desktop, orangecheck in the person's browser, waited on here. A second
## press starts again, for a browser tab closed by mistake.
##
## On the web each step says what is happening: here, that the site's
## sign-in is next; there (web/profile.js, with=orangecheck), that its button
## opens orangecheck's window and then the app again, signed in. A window
## opened from here could not answer this page, so it takes one press there.
func _to_orangecheck() -> void:
	_oc_try += 1
	var mine: int = _oc_try
	if OS.has_feature("web"):
		_oc_say("Taking you to brickworks.diy to sign in with orangecheck…", true)
		# Drawn before the page goes.
		await get_tree().process_frame
		await get_tree().process_frame
		JavaScriptBridge.eval("location.assign('/profile?then=' "
			+ "+ encodeURIComponent(location.pathname + location.search) + '&with=orangecheck')", true)
		return
	_oc_say("Finish signing in with orangecheck in your browser.", true)
	_oc_cancel.visible = true
	var problem: String = await account.sign_in_with_orangecheck()
	if mine != _oc_try:
		return
	_oc_cancel.visible = false
	if problem == Account.SUPERSEDED:
		# Cancelled here, or signed in by email meanwhile.
		_oc_said.visible = false
		return
	if problem.is_empty():
		_oc_said.visible = false
		_show(Step.ADDRESS)
		done.emit()
		return
	_oc_say(problem, false)


func _set_busy(busy: bool) -> void:
	_busy = busy
	_send.disabled = busy
	_verify.disabled = busy
	_email.editable = not busy
	_code_row.set_editable(not busy)
	_send.text = "Sending…" if busy and _step == Step.ADDRESS else "Email me a code"
	_verify.text = "Checking…" if busy and _step == Step.CODE else "Sign in"
	if busy:
		_note.visible = false


func _say(text: String, quiet: bool) -> void:
	_note.text = text
	_note.visible = true
	_note.add_theme_color_override("font_color",
		Color(1, 1, 1, 0.75) if quiet else Color(1.0, 0.55, 0.45))


## The orangecheck button's own line, under it.
func _oc_say(text: String, quiet: bool) -> void:
	_oc_said.text = text
	_oc_said.visible = true
	_oc_said.add_theme_color_override("font_color",
		Color(1, 1, 1, 0.75) if quiet else Color(1.0, 0.55, 0.45))
