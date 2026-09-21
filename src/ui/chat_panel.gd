## The conversation with the design assistant.
##
## Describe what you want, watch it get built, ask for a change. The
## panel shows what the assistant is doing while it works — which part it
## is looking up, what a check came back with, which repair attempt it is
## on — because a design takes minutes and a spinner for that long is
## indistinguishable from a hang.
class_name ChatPanel
extends PanelContainer

const PLACEHOLDER := "Describe something to build…"

## Openers offered on an empty conversation. Concrete rather than clever:
## they show the kind of thing that works, including the two levers that
## matter most, size and subject.
const SUGGESTIONS: Array[String] = [
	"a small lighthouse on a rocky base",
	"a red sports car, about 60 pieces",
	"a medieval gatehouse with a portcullis",
	"a park bench and a tree",
]

var assistant: Assistant
var account: Account

var _log: VBoxContainer
var _scroll: ScrollContainer
var _input: TextEdit
var _send: Button
var _status: Label
var _suggestions: VBoxContainer
var _composer: VBoxContainer
var _gate: SignInForm
var _key_form: KeyForm
var _showing_sign_in: bool = false
var _footer: HBoxContainer
var _meter: Label
var _spinner_at: int = 0
var _working: bool = false
var _settings: HBoxContainer
var _which: OptionButton
var _how_hard: OptionButton
## What the last design cost, kept so it survives the status line being
## overwritten by whatever happens next.
var _bill: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(340, 0)
	_build()
	set_process(true)


func _build() -> void:
	# An opaque backing, or the model shows through the text. Slightly
	# translucent so the viewport still reads as continuous behind it.
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.11, 0.12, 0.14, 0.94)
	backing.content_margin_left = 10
	backing.content_margin_right = 10
	backing.content_margin_top = 10
	backing.content_margin_bottom = 10
	add_theme_stylebox_override("panel", backing)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "Assistant"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var clear := Button.new()
	clear.text = "New"
	clear.tooltip_text = "Start a fresh conversation"
	clear.add_theme_font_size_override("font_size", 11)
	clear.pressed.connect(_on_clear)
	header.add_child(clear)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_log = VBoxContainer.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("separation", 10)
	_scroll.add_child(_log)

	_suggestions = VBoxContainer.new()
	_suggestions.add_theme_constant_override("separation", 4)
	_log.add_child(_suggestions)
	_show_suggestions()

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.modulate = Color(1, 1, 1, 0.62)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	# The composer and the sign-in form occupy the same place and only one
	# is ever shown. Keeping them as siblings rather than rebuilding the
	# bottom of the panel means a half-typed prompt survives a session
	# expiring mid-sentence.
	_composer = VBoxContainer.new()
	_composer.add_theme_constant_override("separation", 6)
	root.add_child(_composer)

	_input = TextEdit.new()
	_input.placeholder_text = PLACEHOLDER
	_input.custom_minimum_size = Vector2(0, 64)
	_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_input.gui_input.connect(_on_input_key)
	_composer.add_child(_input)

	_send = Button.new()
	_send.text = "Build it"
	_send.pressed.connect(_on_send)
	_composer.add_child(_send)

	_build_settings()

	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 8)
	_composer.add_child(_footer)

	_meter = Label.new()
	_meter.add_theme_font_size_override("font_size", 10)
	_meter.modulate = Color(1, 1, 1, 0.5)
	_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(_meter)

	var out := Button.new()
	out.text = "Sign out"
	out.flat = true
	out.add_theme_font_size_override("font_size", 10)
	out.modulate = Color(1, 1, 1, 0.5)
	out.text = "Sign out"
	out.pressed.connect(func() -> void:
		# A key of your own is the only thing to leave behind when there
		# is no account; when there is both, the button means both.
		OwnKey.forget()
		if account != null:
			await account.sign_out()
		_showing_sign_in = false
		_on_account_changed())
	_footer.add_child(out)

	_gate = SignInForm.new()
	root.add_child(_gate)

	_key_form = KeyForm.new()
	_key_form.setup()
	_key_form.accepted.connect(func() -> void:
		_showing_sign_in = false
		_on_account_changed()
		_input.grab_focus())
	_key_form.sign_in_wanted.connect(func() -> void:
		# Only where there is something behind it. On a build with no
		# accounts the link hid the key form and showed nothing in its
		# place, with no way back short of restarting.
		if account == null or not account.available:
			_status.text = ("There are no accounts on this build. A key "
				+ "of your own is the way in.")
			return
		_showing_sign_in = true
		_on_account_changed())
	root.add_child(_key_form)


## Which Claude, and how hard it thinks.
##
## A row rather than a menu behind a gear, because both settings change
## what a design costs by a factor of ten and a setting that changes the
## bill should not be hidden.
##
## Effort disappears entirely on a model that does not take it. Showing
## it greyed out would be showing a control that does nothing, and
## Haiku refuses the parameter outright — so the honest thing is for
## there to be no control to reach for.
func _build_settings() -> void:
	_settings = HBoxContainer.new()
	_settings.add_theme_constant_override("separation", 6)
	_composer.add_child(_settings)

	_which = OptionButton.new()
	_which.add_theme_font_size_override("font_size", 11)
	_which.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_which.tooltip_text = "Which Claude designs for you"
	for choice: Brain.Choice in Brain.all():
		_which.add_item(choice.name)
		_which.set_item_metadata(_which.item_count - 1, choice.id)
		_which.set_item_tooltip(_which.item_count - 1, choice.blurb)
	_which.item_selected.connect(func(at: int) -> void:
		Brain.choose(str(_which.get_item_metadata(at)))
		_show_settings())
	_settings.add_child(_which)

	_how_hard = OptionButton.new()
	_how_hard.add_theme_font_size_override("font_size", 11)
	_how_hard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_how_hard.tooltip_text = ("How long it thinks before answering. "
		+ "More is better and slower and dearer.")
	for level: String in Brain.EFFORTS:
		_how_hard.add_item(level)
		_how_hard.set_item_tooltip(_how_hard.item_count - 1,
			str(Brain.EFFORT_BLURBS.get(level, "")))
	_how_hard.item_selected.connect(func(at: int) -> void:
		Brain.set_effort(Brain.EFFORTS[at]))
	_settings.add_child(_how_hard)

	_show_settings()


## Put the row in step with what is saved. Called after a change as
## well as at the start, because choosing a model can take the effort
## control away.
func _show_settings() -> void:
	if _which == null:
		return
	var chosen: String = Brain.chosen()
	for n: int in _which.item_count:
		if str(_which.get_item_metadata(n)) == chosen:
			_which.selected = n
	var choice: Brain.Choice = Brain.find(chosen)
	_how_hard.visible = choice.effort
	if choice.effort:
		_how_hard.selected = maxi(Brain.EFFORTS.find(Brain.effort()), 0)


func bind(to: Assistant) -> void:
	assistant = to
	assistant.said.connect(_on_said)
	assistant.progress.connect(_on_progress)
	assistant.finished.connect(_on_finished)
	assistant.built.connect(_on_built)
	assistant.spent.connect(_on_spent)


## Why this cannot be sent, or empty when it can.
##
## One place, so the button, the Enter key and the opening suggestions
## all get the same answer. They used to disagree: the button knew
## about the monthly limit, Enter did not, and the suggestions were
## live during the account probe — so clicking one before the probe
## answered started a conversation that could not run and spent an
## opener on it.
func _why_not() -> String:
	if OwnKey.has_key():
		return ""
	if account == null:
		return ""
	if account.state == Account.State.UNKNOWN:
		return "One moment — still checking your account."
	if not account.signed_in():
		return "Sign in, or paste a key of your own, to use the assistant."
	if account.designs_left() <= 0:
		return ("That is this month's designs used up. The builder and "
			+ "the catalogue keep working.")
	return ""


## What the design that just ran cost.
##
## Tokens and money both. The tokens are what was actually spent and
## are true for ever; the money is this app's arithmetic on published
## prices, which go out of date. Showing only the money would be
## claiming more precision than there is, and showing only the tokens
## would be answering a question nobody asked.
##
## Arrives before [signal finished], so it is stored rather than
## written straight to the status line — the line is about to be
## overwritten by whatever happened.
func _on_spent(model_id: String, tokens: Brain.Spend) -> void:
	var choice: Brain.Choice = Brain.find(model_id)
	var cached: String = (" · %s of it cached"
		% Brain.in_tokens(tokens.cached) if tokens.cached > 0 else "")
	_bill = "%s · %s in, %s out%s · about %s" % [
		choice.name,
		Brain.in_tokens(tokens.total_in()),
		Brain.in_tokens(tokens.made),
		cached,
		Brain.in_money(Brain.cost(model_id, tokens)),
	]


## Hand the panel the account it should follow. Optional: a build with no
## accounts behind it never calls this, and the panel then shows the
## composer as it always did.
func watch(with_account: Account) -> void:
	account = with_account
	_gate.setup(account)
	_gate.done.connect(func() -> void: _input.grab_focus())
	account.changed.connect(_on_account_changed)
	_on_account_changed()


func _on_account_changed() -> void:
	if account == null:
		return
	if account.state == Account.State.UNKNOWN:
		# Still asking. Nothing here is right yet, and announcing "not
		# available" would be a verdict passed before the question was
		# put — which it did, for the second or so the probe takes.
		_composer.visible = false
		_gate.visible = false
		_key_form.visible = false
		_status.text = ""
		return

	# Three ways to be allowed to design, and they are not equal. A key
	# of the person's own is the ordinary one: it costs us nothing and
	# needs no account. Our own key answers for one account. Everything
	# else gets the field to paste a key into.
	var own_key: bool = OwnKey.has_key()
	var included: bool = account.signed_in() and account.assistant_included()
	var allowed: bool = own_key or included

	# Signing in worked, so stop asking for a code.
	#
	# An ordinary account does not include the assistant — there is no
	# payment system yet, so everyone but the master account runs on a
	# key of their own. That left "allowed" false after a perfectly
	# successful sign-in, and the form stayed on screen asking for the
	# same code it had just accepted. A success that looks exactly like
	# a failure is worse than a failure: the second attempt is given
	## the same code, which is by then expired, and now it really has
	# failed.
	if _showing_sign_in and account.signed_in():
		_showing_sign_in = false

	# And where there are no accounts at all, there is nothing behind
	# that link. Offering it and then showing an empty panel with no way
	# back is the worst of the three possible answers.
	if not account.available:
		_showing_sign_in = false

	_composer.visible = allowed
	_key_form.visible = not allowed and not _showing_sign_in
	_gate.visible = not allowed and _showing_sign_in and account.available
	# The openers only mean anything if pressing one would do something.
	# They used to run a design for a visitor with no key and no account,
	# which spent the panel's one explanation of what the assistant is
	# for on a request that was never going to run — and answered with
	# "sign in", six lines above a form saying to paste a key.
	_suggestions.visible = allowed and not assistant.has_conversation()

	if allowed:
		_send.disabled = _working
		if own_key:
			# No count to show: Anthropic is billing them directly and
			# we could not count it if we wanted to.
			_meter.text = "your own key · %s" % OwnKey.fingerprint()
			_status.text = ""
		else:
			var left: int = account.designs_left()
			_meter.text = "%d of %d designs left this month" % [
				left, account.budget]
			if left == 0:
				_status.text = ("That is this month's designs used up. "
					+ "The builder and the catalogue keep working.")
				_send.disabled = true
		return

	# Signed in, and still needing a key. Say so, or the form reads as
	# the sign-in having done nothing.
	if account.signed_in() and not included:
		_status.text = ("Signed in as %s. The assistant runs on a key "
			% account.email + "of your own for now — paste one below "
			+ "and it works straight away.")
		return
	if not account.available and not _showing_sign_in:
		_status.text = ""
		return
	_status.text = ""


func _show_suggestions() -> void:
	for child: Node in _suggestions.get_children():
		child.queue_free()

	var hint := Label.new()
	hint.text = "Try one of these, or write your own:"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_suggestions.add_child(hint)

	for text: String in SUGGESTIONS:
		var button := Button.new()
		button.text = text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_suggestion.bind(text))
		_suggestions.add_child(button)


func _on_suggestion(text: String) -> void:
	_input.text = text
	_on_send()


func _on_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed or key.keycode != KEY_ENTER:
		return
	# Enter sends; shift-enter is a newline, as in every chat box.
	if key.shift_pressed:
		return
	_input.accept_event()
	_on_send()


func _on_send() -> void:
	if assistant == null or _working:
		return
	var text: String = _input.text.strip_edges()
	if text.is_empty():
		return
	# Asked here rather than trusted to the button.
	#
	# The monthly limit existed only as _send.disabled, which Enter in
	# the brief box goes nowhere near and which _on_finished clears the
	# moment a design ends. So the last allowed design re-enabled the
	# button, and the next one went to the proxy to be refused — paying
	# a round trip and a wait to be told what was already known.
	var why: String = _why_not()
	if not why.is_empty():
		_status.text = why
		return

	_suggestions.visible = false
	_input.text = ""
	_add(text, _Role.PERSON)
	_working = true
	_send.disabled = true
	_send.text = "Working…"

	# A first request designs; a later one revises what is already there.
	# Asked of the assistant rather than counted off the transcript: the
	# old test was whether the log had more than two children, which was
	# true only by an accident of how many rows a message adds, and the
	# way it fails is to throw the conversation away mid-build.
	if assistant.has_conversation():
		assistant.revise(text)
	else:
		assistant.design(text)


func _on_clear() -> void:
	# Ends the conversation, not the model. This used to call
	# clear_built(), so a button labelled "New" with the tooltip "Start
	# a fresh conversation" silently deleted every brick the assistant
	# had placed — somebody's evening, gone, with nothing said and
	# nothing to undo.
	#
	# The assistant still remembers which bricks were its own, so asking
	# for something else afterwards replaces them as it always did.
	if assistant:
		assistant.cancel()
		assistant.forget_conversation()
	_bill = ""
	for child: Node in _log.get_children():
		if child != _suggestions:
			child.queue_free()
	_show_suggestions()
	_status.text = ""
	_working = false
	_send.disabled = false
	_send.text = "Build it"
	# Whether the openers belong on screen is the same question as
	# whether the composer does, so it is asked in one place rather than
	# set true here and decided there.
	if account != null:
		_on_account_changed()
	else:
		_suggestions.visible = true


enum _Role { PERSON, ASSISTANT, NOTE }


func _add(text: String, role: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	match role:
		_Role.PERSON:
			label.add_theme_font_size_override("font_size", 13)
			var panel := PanelContainer.new()
			var style := StyleBoxFlat.new()
			style.bg_color = Color(1, 1, 1, 0.07)
			style.content_margin_left = 8
			style.content_margin_right = 8
			style.content_margin_top = 6
			style.content_margin_bottom = 6
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			panel.add_theme_stylebox_override("panel", style)
			panel.add_child(label)
			_log.add_child(panel)
		_Role.NOTE:
			label.add_theme_font_size_override("font_size", 11)
			label.modulate = Color(1, 1, 1, 0.5)
			_log.add_child(label)
		_:
			label.add_theme_font_size_override("font_size", 13)
			_log.add_child(label)

	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _on_said(text: String) -> void:
	_add(text, _Role.ASSISTANT)


func _on_progress(note: String) -> void:
	_status.text = note


func _on_built(brick_count: int) -> void:
	_add("Built %d brick%s." % [
		brick_count, "" if brick_count == 1 else "s"], _Role.NOTE)


func _on_finished(ok: bool, summary: String) -> void:
	_working = false
	# Not unconditionally. The design that just ended may have been the
	# last one this month, and re-enabling the button wipes the line
	# that says so.
	_send.disabled = not _why_not().is_empty()
	_send.text = "Build it"
	# The bill goes in either way. A design that failed after three
	# repairs is the one you most want the cost of, and leaving it off
	# would mean the only runs anyone is billed for silently are the
	# ones that went wrong.
	var line: String = summary
	if not _bill.is_empty():
		line = "%s\n%s" % [summary, _bill] if ok else _bill
		_bill = ""
	if ok:
		_status.text = line
	else:
		_add(summary, _Role.NOTE)
		_status.text = line if line != summary else ""
	# And if that was the last one, say so where the count was.
	var why: String = _why_not()
	if not why.is_empty():
		_status.text = "%s\n%s" % [_status.text, why] \
			if not _status.text.is_empty() else why


func _process(_delta: float) -> void:
	if not _working:
		return
	# A design runs for minutes. Something has to move, or it reads as a
	# hang; a dot cycle on the status line is enough and costs nothing.
	var now: int = Time.get_ticks_msec()
	if now - _spinner_at < 420:
		return
	_spinner_at = now
	var base: String = _status.text.rstrip(".")
	if base.is_empty():
		return
	var dots: int = (now / 420) % 4
	_status.text = base + ".".repeat(dots)
