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
var _key_form: KeyForm
var _footer: HBoxContainer
## Which key is in use, by its fingerprint, never the key itself.
var _which_key: Label
## "Change key". It once said "Sign out", which is not what anyone looks
## for to replace a key.
var _out: Button
## Design on a Claude plan instead of a key: see [ConnectorForm].
var _connector_form: ConnectorForm
var _spinner_at: int = 0
var _working: bool = false
var _settings: HBoxContainer
var _which: OptionButton
var _how_hard: OptionButton
## What the last design cost, kept so it survives the status line being
## overwritten by whatever happens next.
var _bill: String = ""

## The finished model's build steps, or its parts list, asked for from
## the card that says it is done — the two things a set is besides the
## model, one button away at the moment someone has one.
signal steps_wanted
signal parts_list_wanted

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
	clear.text = "New chat"
	clear.tooltip_text = "Start a fresh conversation. The model stays."
	clear.add_theme_font_size_override("font_size", 12)
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
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1, 1, 1, 0.72)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	# The composer and the key form occupy the same place and only one is
	# ever shown. Siblings rather than a rebuilt bottom half, so a
	# half-typed brief survives the key being changed.
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
	_reference.add_theme_font_size_override("font_size", 12)
	_reference.modulate = Color(1, 1, 1, 0.7)
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

	_which_key = Label.new()
	_which_key.add_theme_font_size_override("font_size", 11)
	_which_key.modulate = Color(1, 1, 1, 0.6)
	_which_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(_which_key)

	_out = Button.new()
	_out.text = "Change key"
	_out.tooltip_text = "Forget this key and paste another"
	_out.flat = true
	_out.add_theme_font_size_override("font_size", 11)
	_out.modulate = Color(1, 1, 1, 0.7)
	_out.pressed.connect(func() -> void:
		OwnKey.forget()
		_show_for_key(OwnKey.has_key()))
	_footer.add_child(_out)

	_key_form = KeyForm.new()
	_key_form.setup()
	_key_form.accepted.connect(func() -> void:
		_show_for_key(OwnKey.has_key())
		_input.grab_focus())
	root.add_child(_key_form)

	_show_for_key(OwnKey.has_key())


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
	_which.add_theme_font_size_override("font_size", 12)
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
	_how_hard.add_theme_font_size_override("font_size", 12)
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


## Designing on the person's own Claude subscription instead of on a
## key. Set by the app when this machine has Claude Code; the
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
## all get the same answer. They used to disagree, and a suggestion
## clicked at the wrong moment started a conversation that could not
## run and spent an opener on it.
func _why_not() -> String:
	# Nothing to pay for: the thinking is being done by the Claude the
	# person already has, on their own machine.
	if designing_locally():
		return ""
	if OwnKey.has_key():
		return ""
	return "Paste a key of your own to use the assistant."


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


## The composer when there is a key to design with, the key form when
## there is not. There are no accounts, so a key of the person's own is
## the only way in from here, and the form is shown straight away rather
## than after anything is asked of a server.
##
## Told whether there is a key rather than asking, so a probe can see
## both layouts without touching the key this machine holds.
func _show_for_key(has_key: bool) -> void:
	# On a desktop with Claude Code the brief box stays: "My Claude" sits
	# in it, and is a way to design that needs no key.
	_composer.visible = has_key or claude_code_here
	_footer.visible = has_key
	_key_form.visible = not has_key
	# The other way in, offered beside the key, and kept on screen while it
	# is on so the address and what Claude is doing stay in view.
	if _connector_form != null:
		_connector_form.visible = not has_key or _connector_form.is_on()
	# With nothing to show, the conversation took the panel's height and
	# pushed the key form to its foot under an empty dark field. Folded
	# away, the form is the first thing under the title.
	var talking: bool = assistant != null and assistant.has_conversation()
	_scroll.visible = has_key or claude_code_here or talking
	# The openers only mean anything if pressing one would do something.
	# They used to run a design for a visitor with no key, which spent
	# the panel's one explanation of what the assistant is for on a
	# request that was never going to run.
	_suggestions.visible = has_key and not talking
	_status.text = ""
	_send.disabled = _working or not (has_key or designing_locally())
	if has_key:
		# No count to show: Anthropic is billing them directly and we
		# could not count it if we wanted to.
		_which_key.text = "your own key · %s" % OwnKey.fingerprint()


func _show_suggestions() -> void:
	for child: Node in _suggestions.get_children():
		child.queue_free()

	var hint := Label.new()
	hint.text = "Try one of these, or write your own:"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.65)
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
	# Asked here rather than trusted to the button, which Enter in the
	# brief box goes nowhere near.
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
	_show_for_key(OwnKey.has_key())


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
			label.add_theme_font_size_override("font_size", 12)
			label.modulate = Color(1, 1, 1, 0.6)
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
	_run_hint.add_theme_font_size_override("font_size", 12)
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
func _close_run(how: String, summary: String, built: bool = false) -> void:
	if _run == null or not is_instance_valid(_run):
		_run = null
		return
	_run_title.text = how
	_run_clock.text = _elapsed()
	if not summary.is_empty():
		_run_now.text = summary
	_run_stop.visible = false
	_run_hint.visible = false
	if built:
		# What can be done with it now, said where the eye already is.
		var next := Label.new()
		next.text = "Ask for a change below, or carry on building it by hand."
		next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		next.add_theme_font_size_override("font_size", 12)
		next.modulate = Color(1, 1, 1, 0.75)
		_run_stop.get_parent().add_child(next)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for pair: Array in [["Build steps", steps_wanted],
				["Parts list", parts_list_wanted]]:
			var button := Button.new()
			button.text = pair[0]
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.focus_mode = Control.FOCUS_NONE
			var wanted: Signal = pair[1]
			button.pressed.connect(func() -> void: wanted.emit())
			row.add_child(button)
		_run_stop.get_parent().add_child(row)
	_run = null


## The controls a person uses to design, by name, for whatever drives the
## app from outside to find them as a person would: by where they are.
## Offer the Claude connector, below the key form.
func use_connector(connector: ClaudeConnector) -> void:
	_connector_form = ConnectorForm.new()
	_connector_form.setup(connector)
	_key_form.get_parent().add_child(_connector_form)
	_key_form.get_parent().move_child(_connector_form, _key_form.get_index() + 1)
	connector.listening.connect(func(_on: bool, _address: String) -> void:
		_show_for_key(OwnKey.has_key()))
	_show_for_key(OwnKey.has_key())


func controls_by_name() -> Dictionary:
	var named: Dictionary = {"brief": _input, "build": _send,
		"change_key": _out}
	if _key_form != null:
		named.merge(_key_form.controls_by_name())
	if _connector_form != null:
		named.merge(_connector_form.controls_by_name())
	if _run != null and is_instance_valid(_run):
		named["stop"] = _run_stop
	return named


## Whether a closed card's Stop button is still showing. For the probe.
func _run_stop_was(card: PanelContainer) -> bool:
	for button: Button in card.find_children("*", "Button", true, false):
		if button.text == "Stop" and button.visible:
			return true
	return false


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
		_close_run("Done" if ok else "Did not finish", _sentence(summary), ok)
	# A refused key will be refused again. Forget it and ask for another,
	# rather than leave it in place to fail the next brief the same way.
	if not ok and summary.begins_with(Assistant.KEY_REFUSED) \
			and OwnKey.has_key():
		OwnKey.forget()
		_show_for_key(OwnKey.has_key())
		_status.text = "Paste a working key to carry on."
		_send.text = "Build it"
		return
	# Not unconditionally: the key may have been changed while it ran.
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
