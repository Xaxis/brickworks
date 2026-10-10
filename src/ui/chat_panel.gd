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
var _reference: Button

## Somebody wants to hand in a picture of what they are asking for.
signal reference_wanted

## How many references are in hand, so the button can say so.
func references_are(count: int) -> void:
	if _reference == null:
		return
	_reference.text = ("Add a picture of it" if count == 0
		else "%d picture%s of it" % [count, "" if count == 1 else "s"])
	_reference.modulate = Color(1, 1, 1, 0.6 if count == 0 else 0.95)
var _send: Button
var _status: Label
var _suggestions: VBoxContainer
var _composer: VBoxContainer
var _gate: SignInForm
var _key_form: KeyForm
var _showing_sign_in: bool = false
var _footer: HBoxContainer
var _meter: Label
## "Change key" when a key of one's own is all there is, "Sign out" when
## there is an account. It was "Sign out" either way, which is not what
## anyone looks for to replace a key.
var _out: Button
var _spinner_at: int = 0
var _working: bool = false
var _settings: HBoxContainer
var _which: OptionButton
var _how_hard: OptionButton
## What the last design cost, kept so it survives the status line being
## overwritten by whatever happens next.
var _bill: String = ""

## A design is about to start from nothing, rather than revise one.
## Emitted before the assistant is asked, so whatever owns the baseplate
## can make room first.
signal designing(brief: String)

## The card a running design is shown on, while it runs.
##
## A design takes minutes. Before this it showed one line of 11-point
## grey text at the foot of the panel, each step replacing the last, and
## nothing on the baseplate until the first brick was written — which on
## Opus at high effort is a minute and a half of thinking and looking
## things up. Watched in the browser, that is a page that has done
## nothing, and it was reported as "the assistant doesn't work at all".
var _run: PanelContainer = null
var _run_title: Label
var _run_clock: Label
var _run_now: Label
var _run_past: VBoxContainer
var _run_stop: Button
var _run_hint: Label
var _run_started: int = 0
## Steps kept on the card, oldest dropped first.
const RUN_STEPS := 6


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

	# A picture of what is wanted, before a word of the brief.
	#
	# Asked for a named real thing, the assistant works from its own
	# memory of what that thing looks like and nothing in the loop can
	# disagree. A photograph is the one input that can.
	_reference = Button.new()
	_reference.text = "Add a picture of it"
	_reference.flat = true
	_reference.focus_mode = Control.FOCUS_NONE
	_reference.add_theme_font_size_override("font_size", 11)
	_reference.modulate = Color(1, 1, 1, 0.6)
	_reference.tooltip_text = ("A photo or drawing of the thing you want "
		+ "built. Its proportions get measured off this rather than "
		+ "remembered.")
	_reference.pressed.connect(func() -> void: reference_wanted.emit())
	_composer.add_child(_reference)

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
	_out = out
	out.text = "Sign out"
	out.flat = true
	out.add_theme_font_size_override("font_size", 11)
	out.modulate = Color(1, 1, 1, 0.7)
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

	# Only where it would work. An option that needs a program the
	# person has not got is worse than no option: it reads as the app
	# being broken rather than as something they could install.
	if claude_code_here:
		_use_claude_code = CheckBox.new()
		_use_claude_code.text = "My Claude"
		_use_claude_code.add_theme_font_size_override("font_size", 11)
		_use_claude_code.tooltip_text = ("Design with the Claude Code on "
			+ "this machine, on your own Claude subscription. No key, no "
			+ "account, nothing billed here — and the session can reach "
			+ "this app's bricks and nothing else on your computer.")
		_use_claude_code.toggled.connect(func(_on: bool) -> void:
			# The model and effort pickers belong to the loop inside the
			# app; the Claude on this machine brings its own.
			_show_settings()
			_status.text = ("Your own Claude will design it."
				if designing_locally() else ""))
		_settings.add_child(_use_claude_code)

	_show_settings()


## Put the row in step with what is saved. Called after a change as
## well as at the start, because choosing a model can take the effort
## control away.
func _show_settings() -> void:
	# The model and effort belong to the loop inside the app. When the
	# person's own Claude is doing the designing, it chooses its own.
	if _which != null and _use_claude_code != null:
		var mine: bool = designing_locally()
		_which.disabled = mine
		_how_hard.disabled = mine
		_send.disabled = _why_not() != ""
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


## Designing on the person's own Claude subscription instead of on a key
## or an account. Set by the app when this machine has Claude Code; the
## panel shows the choice only then, because offering something that is
## not installed is worse than not offering it.
var claude_code_here: bool = false
signal design_locally(brief: String)
var _use_claude_code: CheckBox = null


## True when the person has asked for their own Claude to do it.
func designing_locally() -> bool:
	return _use_claude_code != null and _use_claude_code.button_pressed


## A run that never started, said in the panel rather than swallowed.
func gave_up(why: String) -> void:
	_status.text = why
	_working = false
	_send.disabled = false
	_send.text = "Build it"


## The same three handlers the assistant's signals use, so a design run
## looks the same in the panel whichever side of the window it is on.
func follow(session: ClaudeCode) -> void:
	if not session.progress.is_connected(_on_progress):
		session.progress.connect(_on_progress)
		session.said.connect(_on_said)
		session.finished.connect(_on_finished)


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
	# Nothing to pay for and nothing to sign into: the thinking is being
	# done by the Claude the person already has, on their own machine.
	if designing_locally():
		return ""
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
	# With nothing to show, the conversation took the panel's height and
	# pushed the key form to its foot under an empty dark field. Folded
	# away, the form is the first thing under the title.
	_scroll.visible = allowed or (assistant != null
		and assistant.has_conversation())
	_gate.visible = not allowed and _showing_sign_in and account.available
	# The openers only mean anything if pressing one would do something.
	# They used to run a design for a visitor with no key and no account,
	# which spent the panel's one explanation of what the assistant is
	# for on a request that was never going to run — and answered with
	# "sign in", six lines above a form saying to paste a key.
	_suggestions.visible = allowed and not assistant.has_conversation()

	if _out != null:
		_out.text = "Sign out" if account.signed_in() else "Change key"
		_out.tooltip_text = ("Forget the key on this device and sign out"
			if account.signed_in() else "Forget this key and paste another")
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
	_status.text = ""
	var fresh: bool = assistant == null or not assistant.has_conversation()
	if fresh:
		designing.emit(text)
	_open_run(fresh)

	if designing_locally():
		design_locally.emit(text)
		return

	# A first request designs; a later one revises what is already there.
	# Asked of the assistant rather than counted off the transcript: the
	# old test was whether the log had more than two children, which was
	# true only by an accident of how many rows a message adds, and the
	# way it fails is to throw the conversation away mid-build.
	var started: bool = (assistant.revise(text)
		if assistant.has_conversation() else assistant.design(text))
	if not started:
		# Refused because one is already running. The composer is meant
		# to be disabled then, so this is the belt to that braces — but
		# saying nothing would leave a brief typed, sent and vanished.
		_status.text = "Still working on the last one."
		_working = false
		_send.disabled = false
		_send.text = "Build it"
		_close_run("Did not start", "")


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
	_run = null
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

	# What the assistant says while it works goes above its card, so the
	# card stays where the eye already is.
	if _run != null and is_instance_valid(_run) and role != _Role.PERSON:
		_log.move_child(_run, _log.get_child_count() - 1)

	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


## A line from the app rather than from either side of the conversation.
func note(text: String) -> void:
	_add(text, _Role.NOTE)


func _on_said(text: String) -> void:
	_add(text, _Role.ASSISTANT)


func _on_progress(note: String) -> void:
	if _run == null or not is_instance_valid(_run):
		_status.text = note
		return
	# The step that was current becomes history, and the newest is the
	# one written large.
	var was: String = _run_now.text
	if not was.is_empty() and was != _starting_line():
		var line := Label.new()
		line.text = "· " + was
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 12)
		line.modulate = Color(1, 1, 1, 0.55)
		_run_past.add_child(line)
		while _run_past.get_child_count() > RUN_STEPS:
			var oldest: Node = _run_past.get_child(0)
			_run_past.remove_child(oldest)
			oldest.queue_free()
	_run_now.text = _sentence(note)


## A progress note as it reads on the card: capitalised, no trailing dots.
static func _sentence(note: String) -> String:
	var text: String = note.strip_edges().rstrip(".…")
	if text.is_empty():
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)


func _starting_line() -> String:
	return "Reading the brief"


## Put a card for this run at the foot of the conversation.
func _open_run(fresh: bool) -> void:
	_run = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.45, 0.85, 0.12)
	style.border_color = Color(0.4, 0.6, 1.0, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_run.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_run.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	_run_title = Label.new()
	_run_title.text = "Designing" if fresh else "Changing it"
	_run_title.add_theme_font_size_override("font_size", 14)
	_run_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_run_title)
	_run_clock = Label.new()
	_run_clock.text = "0:00"
	_run_clock.add_theme_font_size_override("font_size", 14)
	_run_clock.modulate = Color(1, 1, 1, 0.7)
	top.add_child(_run_clock)

	_run_now = Label.new()
	_run_now.text = _starting_line()
	_run_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_run_now.add_theme_font_size_override("font_size", 13)
	column.add_child(_run_now)

	_run_past = VBoxContainer.new()
	_run_past.add_theme_constant_override("separation", 2)
	column.add_child(_run_past)

	# What to expect, said once, because the honest answer to "is it
	# doing anything" is that it takes a while.
	_run_hint = Label.new()
	_run_hint.text = _expect()
	_run_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_run_hint.add_theme_font_size_override("font_size", 11)
	_run_hint.modulate = Color(1, 1, 1, 0.6)
	column.add_child(_run_hint)

	_run_stop = Button.new()
	_run_stop.text = "Stop"
	_run_stop.tooltip_text = "Stop, and put back what was there before"
	_run_stop.pressed.connect(func() -> void:
		if assistant != null:
			assistant.cancel())
	column.add_child(_run_stop)

	_log.add_child(_run)
	_run_started = Time.get_ticks_msec()


## How long a design takes at the chosen setting, said plainly.
func _expect() -> String:
	var effort: String = "high"
	if _how_hard != null and _how_hard.visible and _how_hard.selected >= 0:
		effort = _how_hard.get_item_text(_how_hard.selected).to_lower()
	# Measured on Opus 5.5, "a small red house": high took 4 minutes to its
	# first check and 11 to finish; medium 2 and 4. Castles at high, 30-46.
	var span: String = ("At this setting a small house took about 4 minutes "
		+ "to its first bricks and 11 to finish; a castle, 45")
	if effort.begins_with("medium"):
		span = ("At this setting a small house took about 2 minutes to its "
			+ "first bricks and 4 to finish")
	elif effort.begins_with("low"):
		span = "This setting is the quickest, and the plainest"
	return ("Nothing is built until it has planned the model. %s. You can "
		% span + "keep building, or look around, while it works.")


## The run is over: say how it ended and how long it took.
func _close_run(how: String, summary: String) -> void:
	if _run == null or not is_instance_valid(_run):
		_run = null
		return
	_run_title.text = how
	_run_clock.text = _elapsed()
	if not summary.is_empty():
		_run_now.text = summary
	_run_stop.visible = false
	_run_hint.visible = false
	_run = null


func _elapsed() -> String:
	var seconds: int = (Time.get_ticks_msec() - _run_started) / 1000
	return "%d:%02d" % [seconds / 60, seconds % 60]


func _on_built(brick_count: int) -> void:
	_add("Built %d brick%s." % [
		brick_count, "" if brick_count == 1 else "s"], _Role.NOTE)


func _on_finished(ok: bool, summary: String) -> void:
	_working = false
	var on_card: bool = _run != null and is_instance_valid(_run)
	if summary == "cancelled":
		_close_run("Stopped", "Stopped. What was there before is back.")
	else:
		_close_run("Done" if ok else "Did not finish", _sentence(summary))
	# A refused key will be refused again. Forget it and ask for another,
	# rather than leave it in place to fail the next brief the same way.
	if not ok and summary.begins_with(Assistant.KEY_REFUSED) \
			and OwnKey.has_key():
		OwnKey.forget()
		_on_account_changed()
		_status.text = "Paste a working key to carry on."
		_send.text = "Build it"
		return
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
		# On the card when there is one, in the size the rest of the run
		# was told in; a line of its own only when there was no card.
		if not on_card:
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
	if _run != null and is_instance_valid(_run):
		_run_clock.text = _elapsed()
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
