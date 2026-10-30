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
var _reference: LinkButton

## Somebody wants to hand in a picture of what they are asking for.
signal reference_wanted

## How many references are in hand, so the button can say so.
func references_are(count: int) -> void:
	if _reference == null:
		return
	_reference.text = ("Add a picture of it" if count == 0
		else "%d picture%s of it" % [count, "" if count == 1 else "s"])
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
var _out: LinkButton
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
## The offer on the card of a big model built in sections: its hidden parts
## coloured by section, as big sets are inside. Only offered: pressing it
## opens the preview (HiddenColoursPanel), and nothing changes until the
## person applies it there.
signal hidden_colours_wanted
## Whether the model just built is one to offer that for: Main's.
var offers_hidden_colours: Callable = func() -> bool: return false

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
## How many past steps a card keeps. The app's own design shows the last
## few; Claude's every one, since the card is the only record of what it did.
var _run_keep: int = RUN_STEPS
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
	clear.pressed.connect(new_chat)
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

	# What the next request is about, when it is about a selection: a chip
	# over the brief, taken off with its cross.
	_chip = PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0.95, 0.35, 0.75, 0.16)
	chip_style.border_color = Color(0.95, 0.35, 0.75, 0.6)
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(10)
	chip_style.content_margin_left = 10
	chip_style.content_margin_right = 4
	chip_style.content_margin_top = 2
	chip_style.content_margin_bottom = 2
	_chip.add_theme_stylebox_override("panel", chip_style)
	_chip.visible = false
	var chip_row := HBoxContainer.new()
	_chip.add_child(chip_row)
	_chip_words = Label.new()
	_chip_words.add_theme_font_size_override("font_size", 12)
	_chip_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chip_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_row.add_child(_chip_words)
	_chip_clear = Button.new()
	_chip_clear.text = "×"
	_chip_clear.flat = true
	_chip_clear.focus_mode = Control.FOCUS_NONE
	_chip_clear.tooltip_text = "Ask about the whole model instead"
	_chip_clear.pressed.connect(stop_asking_about)
	chip_row.add_child(_chip_clear)
	_composer.add_child(_chip)

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
	_reference = Look.link("Add a picture of it", 12)
	_reference.tooltip_text = ("A photo or drawing of the thing you want "
		+ "built. Its proportions get measured off this rather than "
		+ "remembered.")
	_reference.pressed.connect(func() -> void: reference_wanted.emit())
	_composer.add_child(_reference)

	_send = Button.new()
	_send.text = "Build it"
	_send.pressed.connect(_on_send)
	_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var send_row := HBoxContainer.new()
	send_row.add_theme_constant_override("separation", 8)
	_composer.add_child(send_row)
	send_row.add_child(_send)

	# Three quick massings to choose from before a full design is paid for
	# (Assistant.sketch): on by default for a first design, and not there
	# for a change to one, which has a model to work from already.
	_sketch_first = CheckBox.new()
	_sketch_first.text = "Sketch first"
	_sketch_first.button_pressed = true
	_sketch_first.add_theme_font_size_override("font_size", 12)
	_sketch_first.tooltip_text = ("Three quick massing sketches to choose from, "
		+ "on a cheaper Claude, before the full design is begun.")
	send_row.add_child(_sketch_first)

	_build_settings()

	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 8)
	_composer.add_child(_footer)

	_which_key = Label.new()
	_which_key.add_theme_font_size_override("font_size", 11)
	_which_key.modulate = Color(1, 1, 1, 0.6)
	_which_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Another AI's line names its provider and model, longer than the column.
	_which_key.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_child(_which_key)

	_out = Look.link("Change key", 11)
	_out.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_out.tooltip_text = "Forget this key and paste another"
	_out.pressed.connect(func() -> void:
		if designing_elsewhere():
			ai_settings_wanted.emit()
			return
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
				if designing_locally() else "")
			# With no key, ticked is what makes the button usable at all.
			_send.disabled = _working or not (OwnKey.has_key() or designing_locally()))
		_settings.add_child(_use_claude_code)

	_show_settings()


## Put the row in step with what is saved. Called after a change as
## well as at the start, because choosing a model can take the effort
## control away.
func _show_settings() -> void:
	# Claude's model, effort and My Claude are Claude's: another AI has its
	# own, in Settings, AI.
	if _settings != null:
		_settings.visible = not designing_elsewhere()
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

## Designing with another AI on the person's own key, chosen in Settings, AI
## (ProviderSettings.who): the brief goes to Main's DesignerLoop, as a brief
## goes to Claude Code, and the run is followed the same way.
signal design_elsewhere(brief: String)
## Stop pressed on such a run's card.
signal stop_elsewhere
## The way to Settings, AI, from the foot of the column.
signal ai_settings_wanted


## True when another AI on the person's own key designs.
func designing_elsewhere() -> bool:
	return ProviderSettings.who() == ProviderSettings.WHO_KEY


## Who designs changed in Settings, AI: the column follows.
func refresh_designer() -> void:
	_show_settings()
	_show_for_key(OwnKey.has_key())
	# The words that ask it name it.
	if not _working:
		_send.text = _send_words()
	if _chip != null and _chip.visible:
		_input.placeholder_text = ABOUT_PLACEHOLDER.replace("Claude", ProviderSettings.designer_name())


## Words put in the brief's box for the person to send or change, never
## sent here (/app?brief=, a set's page's Design with these parts).
func draft(text: String) -> void:
	_input.text = text
	focus_brief()


## What the brief's box holds.
func drafted() -> String:
	return _input.text


## The brief's box, ready to type in.
func focus_brief() -> void:
	if _composer.visible:
		# After the column has opened round it.
		_input.grab_focus.call_deferred()


## True when the person has asked for their own Claude to do it.
func designing_locally() -> bool:
	return _use_claude_code != null and _use_claude_code.button_pressed


## A run that never started, said in the panel rather than swallowed.
func gave_up(why: String) -> void:
	_status.text = why
	_working = false
	_send.disabled = false
	_send.text = _send_words()


## The same three handlers the assistant's signals use, so a design run
## looks the same in the panel whichever side of the window it is on.
## [param ends] says the run's end in place of the session's own: a design
## made twice ends when the better of the two stands (BestOfTwo). The
## session is Claude Code's, or another AI's (DesignerLoop): both say the
## same three things.
func follow(session: Node, ends: Signal = Signal()) -> void:
	var progress := Signal(session, &"progress")
	var finished := Signal(session, &"finished")
	if not progress.is_connected(_on_progress):
		progress.connect(_on_progress)
		Signal(session, &"said").connect(_on_said)
	var end: Signal = finished if ends.is_null() else ends
	if not ends.is_null() and finished.is_connected(_on_finished):
		finished.disconnect(_on_finished)
	if not end.is_connected(_on_finished):
		end.connect(_on_finished)


func bind(to: Assistant) -> void:
	assistant = to
	assistant.said.connect(_on_said)
	assistant.progress.connect(_on_progress)
	assistant.finished.connect(_on_finished)
	assistant.built.connect(_on_built)
	assistant.spent.connect(_on_spent)
	assistant.focus_edited.connect(_on_focus_edited)
	assistant.room_asked.connect(_on_room_asked)
	assistant.sketches_ready.connect(_on_sketches)
	assistant.sketch_chosen.connect(_on_sketch_chosen)


# -- asking about the selection ----------------------------------------------


const ABOUT_PLACEHOLDER := ("What should Claude do with them? \"Make this curved\", "
	+ "\"add detail\", \"recolour it in tan\", \"why is this not stable?\"")
var _chip: PanelContainer
var _chip_words: Label
var _chip_clear: Button
## The card asking the person for more room, while it waits.
var _room_card: PanelContainer = null


## Ask about these parts (Edit, Ask Claude about this…, or the menu on a
## part): the next request is about them, and Claude may change only them
## and the room round them. [param words] are the request, written in for
## the person to send (Ask Claude to brace this).
func ask_about(selected: Array, words: String = "") -> void:
	if assistant == null:
		return
	# Not the room of a request still being worked on.
	if _working:
		_status.text = "Still working on the last one."
		return
	if not assistant.focus_on(selected, true).is_empty():
		_status.text = "Select the parts to ask about first."
		return
	_show_chip()
	_input.placeholder_text = ABOUT_PLACEHOLDER.replace("Claude", ProviderSettings.designer_name())
	if not words.is_empty():
		_input.text = words
	# With no key, the Claude on this machine is the way to ask that works.
	if not OwnKey.has_key() and claude_code_here and _use_claude_code != null \
			and not _use_claude_code.button_pressed:
		_use_claude_code.button_pressed = true
	if OwnKey.has_key() or claude_code_here:
		_input.grab_focus()
	elif _connector_form != null and _connector_form.is_on():
		note("Ask Claude in your chat about the %d selected part%s. It sees what is "
			% [assistant.focus.ids.size(), "" if assistant.focus.ids.size() == 1 else "s"]
			+ "selected here and changes only that.")
	else:
		_status.text = ("Paste a key of your own, or connect Claude, to ask about "
			+ "the selection.")


## Back to asking about the whole model.
func stop_asking_about() -> void:
	if assistant != null and not _working:
		assistant.unfocus()
	_chip.visible = false
	_input.placeholder_text = PLACEHOLDER
	if not _working:
		_send.text = _send_words()
	_show_sketch_first()


## Whether the next request is about a selection.
func asking_about() -> bool:
	return _chip != null and _chip.visible and assistant != null \
		and assistant._focus_alive()


func _show_chip() -> void:
	var count: int = assistant.focus.ids.size() if assistant.focus != null else 0
	_chip_words.text = "About %d selected part%s" % [count, "" if count == 1 else "s"]
	_chip.visible = count > 0
	if not _working:
		_send.text = _send_words()
	_show_sketch_first()


## What the button says: a request about a selection asks whoever designs
## (Claude, or the model on the person's key), a brief builds.
func _send_words() -> String:
	return "Ask %s" % ProviderSettings.designer_name() if _chip != null and _chip.visible \
		else "Build it"


# -- sketch first ---------------------------------------------------------------


var _sketch_first: CheckBox
## The three cards on show, and what the sketches cost, for the bill of the
## design chosen from them.
var _sketch_cards: VBoxContainer = null
var _sketch_buttons: Array[Button] = []
var _sketch_bill: String = ""


## Sketch first is offered where a request would start a design from
## nothing: not for a change to one, nor about a selection.
func _show_sketch_first() -> void:
	if _sketch_first == null:
		return
	_sketch_first.visible = not _working and not (_chip != null and _chip.visible) \
		and (assistant == null or not assistant.has_conversation())


## How long sketching takes, said on its card.
func _sketch_expect() -> String:
	var model: Brain.Choice = Brain.find(Brain.sketch_model())
	var effort: String = Brain.sketch_effort()
	return ("Three quick massing sketches on %s%s, to choose from before the full "
		% [model.name, " at %s effort" % effort if not effort.is_empty() else ""]
		+ "design. Nothing is built until you choose one.")


## The sketches are in. The app's own: its card says what they cost, and
## each sketch is a card to choose from. A session's from outside: the same
## cards, without the buttons, while it chooses.
func _on_sketches(sketches: Array, model_id: String, tokens: Brain.Spend, ours: bool) -> void:
	if ours:
		_working = false
		var cost: String = ""
		if not tokens.is_empty():
			_sketch_bill = Brain.in_money(Brain.cost(model_id, tokens))
			cost = " The sketches cost %s: %s · %s in, %s out." % [_sketch_bill,
				Brain.find(model_id).name, Brain.in_tokens(tokens.total_in()),
				Brain.in_tokens(tokens.made)]
		_close_run("%d sketches" % sketches.size(),
			"Choose one below to design in full.%s" % cost)
		_send.disabled = not _why_not().is_empty()
		_send.text = _send_words()
		_show_sketch_first()
		_status.text = ""
	if _sketch_cards != null and is_instance_valid(_sketch_cards):
		_sketch_cards.name = "sketches_before"
	_sketch_cards = VBoxContainer.new()
	_sketch_cards.name = "sketches"
	_sketch_cards.add_theme_constant_override("separation", 6)
	var head := Label.new()
	head.text = ("Choose the one that is closest to what you want:" if ours
		else "Claude sketched %d ideas and is choosing one:" % sketches.size())
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_size_override("font_size", 12)
	_sketch_cards.add_child(head)
	_sketch_buttons = []
	for one: Sketches.Sketch in sketches:
		_sketch_cards.add_child(_sketch_card(one, ours))
	_log.add_child(_sketch_cards, true)
	if _run != null and is_instance_valid(_run):
		_log.move_child(_run, _log.get_child_count() - 1)
	_follow_the_card()


func _sketch_card(one: Sketches.Sketch, choosable: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "sketch_%d" % one.number
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.border_color = Color(1, 1, 1, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	if one.picture != null:
		var picture := TextureRect.new()
		picture.name = "picture"
		picture.texture = ImageTexture.create_from_image(one.picture)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(112, 112)
		row.add_child(picture)
	var column := VBoxContainer.new()
	column.name = "words"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	row.add_child(column)
	var named := Label.new()
	named.text = "%d. %s" % [one.number, one.name]
	named.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	named.add_theme_font_size_override("font_size", 13)
	column.add_child(named)
	var measured := Label.new()
	measured.text = "%d parts · %s%s" % [one.parts, one.measures(),
		"" if one.holds() else " · does not hold yet"]
	measured.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	measured.add_theme_font_size_override("font_size", 11)
	measured.modulate = Color(1, 1, 1, 0.6)
	column.add_child(measured)
	if not one.description.is_empty():
		var said := Label.new()
		said.text = one.description
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		said.add_theme_font_size_override("font_size", 11)
		said.modulate = Color(1, 1, 1, 0.75)
		column.add_child(said)
	if choosable:
		var choose := Button.new()
		choose.name = "choose"
		choose.text = "Design this one"
		choose.focus_mode = Control.FOCUS_NONE
		var number: int = one.number
		choose.pressed.connect(func() -> void: _choose_sketch(number))
		column.add_child(choose)
		_sketch_buttons.append(choose)
	return card


## A card's button: that sketch goes down, and the full design begins from it
## at the model and effort chosen in the row below.
func _choose_sketch(number: int) -> void:
	if _working or assistant == null:
		return
	for button: Button in _sketch_buttons:
		button.disabled = true
	_working = true
	_send.disabled = true
	_send.text = "Working…"
	_show_sketch_first()
	_open_run(true)
	_run_title.text = "Designing from sketch %d" % number
	var why: String = await assistant.choose_sketch(number)
	if not why.is_empty():
		_working = false
		_send.disabled = not _why_not().is_empty()
		_send.text = _send_words()
		_close_run("Did not start", why)
		_show_sketch_first()


## One was chosen (0: none, the sketches dropped for a whole design): said
## on its card, and the rest faded.
func _on_sketch_chosen(number: int) -> void:
	if _sketch_cards == null or not is_instance_valid(_sketch_cards):
		return
	for button: Button in _sketch_buttons:
		button.disabled = true
	for child: Node in _sketch_cards.get_children():
		if not child is PanelContainer:
			continue
		var chosen: bool = child.name == "sketch_%d" % number
		(child as Control).modulate = Color(1, 1, 1, 1.0 if chosen else 0.45)
		if chosen:
			var mark := Label.new()
			mark.name = "chosen"
			mark.text = "Chosen"
			mark.add_theme_font_size_override("font_size", 11)
			mark.modulate = Color(0.55, 0.85, 1.0)
			child.find_child("words", true, false).add_child(mark)


## A change to the selection landed: what it did, and the room before and
## after, side by side.
func _on_focus_edited(words: String, before: Image, after: Image) -> void:
	if _chip.visible:
		_show_chip()
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	var said := Label.new()
	said.text = "Changed the selection: %s. Edit, Undo takes the request back." % words
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.add_theme_font_size_override("font_size", 12)
	card.add_child(said)
	if before != null or after != null:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for pair: Array in [["Before", before], ["After", after]]:
			if pair[1] == null:
				continue
			var column := VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var named := Label.new()
			named.text = pair[0]
			named.add_theme_font_size_override("font_size", 11)
			named.modulate = Color(1, 1, 1, 0.65)
			column.add_child(named)
			var picture := TextureRect.new()
			picture.name = pair[0]
			picture.texture = ImageTexture.create_from_image(pair[1])
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.custom_minimum_size = Vector2(0, 120)
			column.add_child(picture)
			row.add_child(column)
		card.add_child(row)
	# Named for a probe to find it, "changed2" and on after the first.
	card.name = "changed"
	_log.add_child(card, true)
	if _run != null and is_instance_valid(_run):
		_log.move_child(_run, _log.get_child_count() - 1)
	_follow_the_card()


## Claude asks to change more than the selection's room: the person says.
func _on_room_asked(why: String, where: String) -> void:
	if _room_card != null and is_instance_valid(_room_card):
		_room_card.queue_free()
	_room_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.65, 0.2, 0.14)
	style.border_color = Color(0.95, 0.65, 0.2, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	_room_card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_room_card.add_child(column)
	var said := Label.new()
	said.text = ("Claude asks to change more than the selection: %s.
It would work in %s."
		% [why.rstrip("."), where])
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.add_theme_font_size_override("font_size", 12)
	column.add_child(said)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	var card: PanelContainer = _room_card
	for pair: Array in [["Allow", true], ["Keep to the selection", false]]:
		var button := Button.new()
		button.text = pair[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var yes: bool = pair[1]
		button.pressed.connect(func() -> void:
			assistant.answer_room(yes)
			row.queue_free()
			said.text += "\n" + ("Allowed." if yes else "Kept to the selection.")
			if _room_card == card:
				_room_card = null)
		row.add_child(button)
	_log.add_child(_room_card)
	if _run != null and is_instance_valid(_run):
		_log.move_child(_run, _log.get_child_count() - 1)
	_follow_the_card()


## Why this cannot be sent, or empty when it can.
##
## One place, so the button, the Enter key and the opening suggestions
## all get the same answer. They used to disagree, and a suggestion
## clicked at the wrong moment started a conversation that could not
## run and spent an opener on it.
func _why_not() -> String:
	# Nothing to pay for: the thinking is being done by the Claude the
	# person already has, on their own machine.
	if designing_elsewhere():
		return ProviderSettings.not_ready()
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
## there is not. The assistant runs on a key of the person's own (their
## Brickworks account pays for nothing), so the form is shown straight
## away rather than after anything is asked of a server.
##
## Told whether there is a key rather than asking, so a probe can see
## both layouts without touching the key this machine holds.
func _show_for_key(has_key: bool) -> void:
	# Another AI chosen in Settings, AI, designs with its own key: the brief
	# box is for it, and Claude's key form and connector stand aside.
	var elsewhere: bool = designing_elsewhere()
	has_key = has_key or elsewhere
	# On a desktop with Claude Code the brief box stays: "My Claude" sits
	# in it, and is a way to design that needs no key.
	_composer.visible = has_key or claude_code_here
	_footer.visible = has_key
	_show_sketch_first()
	# While Claude is connected on the person's plan, the key's form is a
	# way they are not using; it folds to one line rather than sitting
	# under Claude's card for the whole build.
	var plan_on: bool = _connector_form != null and _connector_form.is_on()
	_key_form.visible = not has_key and (not plan_on or _key_wanted)
	if _key_instead != null:
		_key_instead.visible = not has_key and plan_on and not _key_wanted
	if _connector_form != null:
		_connector_form.alone(not _key_form.visible)
	# The other way in, offered beside the key, and kept on screen while it
	# is on so the address and what Claude is doing stay in view.
	if _connector_form != null:
		_connector_form.visible = not has_key or _connector_form.is_on()
	# With nothing to show, the conversation took the panel's height and
	# pushed the key form to its foot under an empty dark field. Folded
	# away, the form is the first thing under the title.
	# The same with the connector on: it kept the empty field open for
	# Claude's card, and the steps to connect sat at the panel's foot under
	# a blank space two-thirds of its height. The card opens it when Claude
	# first calls (_on_claude_called).
	var talking: bool = assistant != null and assistant.has_conversation()
	_scroll.visible = has_key or claude_code_here or talking or _logged() \
		or _claude_card()
	# The openers only mean anything if pressing one would do something.
	# They used to run a design for a visitor with no key, which spent
	# the panel's one explanation of what the assistant is for on a
	# request that was never going to run.
	_suggestions.visible = has_key and not talking
	_status.text = ""
	_send.disabled = _working or not (has_key or designing_locally())
	_out.text = "Change" if elsewhere else "Change key"
	_out.tooltip_text = ("Settings, AI: who designs, the provider, model and key" if elsewhere
		else "Forget this key and paste another")
	if elsewhere:
		var kept: Dictionary = ProviderSettings.chosen()
		var id: String = str(kept["provider"])
		var key: String = ProviderSettings.load_key(id)
		_which_key.text = "%s · %s%s" % [str(ProviderSettings.PRESETS[id]["name"]),
			str(kept["model"]), " · your key %s" % ProviderSettings.fingerprint(key)
			if not key.is_empty() else ""]
		var why: String = ProviderSettings.not_ready()
		_send.disabled = _working or not why.is_empty()
		_status.text = why
	elif has_key:
		# No count to show: Anthropic is billing them directly and we
		# could not count it if we wanted to.
		_which_key.text = "your own key · %s" % OwnKey.fingerprint()


## Whether the conversation holds anything yet: a card, a note, a line.
func _logged() -> bool:
	for child: Node in _log.get_children():
		if child != _suggestions and not child.is_queued_for_deletion():
			return true
	return false


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

	# About a selection: the chip says so, and the parts must still be there.
	var about: bool = asking_about()
	if _chip.visible and not about:
		stop_asking_about()
		_status.text = "The parts asked about are gone. Select them and ask again."
		return
	var count: int = assistant.focus.ids.size() if about else 0
	# Three massings first, if this starts a design and the box is ticked.
	var sketching: bool = not about and _sketch_first.visible \
		and _sketch_first.button_pressed

	_suggestions.visible = false
	_input.text = ""
	_add(("About %d selected part%s: %s" % [count, "" if count == 1 else "s", text])
		if about else text, _Role.PERSON)
	_working = true
	_send.disabled = true
	_send.text = "Working…"
	_status.text = ""
	# Never a fresh design about a selection: the model round it stays.
	var fresh: bool = not about and (assistant == null or not assistant.has_conversation())
	if fresh:
		designing.emit(text)
	_open_run(fresh, (func() -> void: stop_elsewhere.emit()) if designing_elsewhere()
		else Callable())
	_show_sketch_first()
	# A brief typed instead of choosing: the cards still showing are past.
	for button: Button in _sketch_buttons:
		button.disabled = true
	if about:
		_run_title.text = "Changing the selection"
	if sketching:
		_run_title.text = "Sketching three ideas"
		_run_hint.text = _sketch_expect()

	if designing_elsewhere():
		design_elsewhere.emit(Assistant.selection_brief(text, count) if about
			else Assistant.sketch_brief(text) if sketching else text)
		return
	if designing_locally():
		design_locally.emit(Assistant.selection_brief(text, count) if about
			else Assistant.sketch_brief(text) if sketching else text)
		return

	if about:
		if not assistant.about_selection(text):
			_status.text = "Still working on the last one."
			_working = false
			_send.disabled = false
			_send.text = _send_words()
			_close_run("Did not start", "")
		return

	# A first request designs; a later one revises what is already there.
	# Asked of the assistant rather than counted off the transcript: the
	# old test was whether the log had more than two children, which was
	# true only by an accident of how many rows a message adds, and the
	# way it fails is to throw the conversation away mid-build.
	var started: bool = (assistant.sketch(text) if sketching
		else assistant.revise(text) if assistant.has_conversation()
		else assistant.design(text))
	if not started:
		# Refused because one is already running. The composer is meant
		# to be disabled then, so this is the belt to that braces — but
		# saying nothing would leave a brief typed, sent and vanished.
		_status.text = "Still working on the last one."
		_working = false
		_send.disabled = false
		_send.text = _send_words()
		_close_run("Did not start", "")


## Send [param text] as though it had been typed: how the mosaic dialog's
## Design with Claude starts a run, the same run whichever way the person
## designs. Empty when it went, otherwise why it could not.
func ask(text: String) -> String:
	if _working:
		return "Still working on the last one."
	var why: String = _why_not()
	if not why.is_empty():
		_status.text = why
		return why
	_input.text = text
	_on_send()
	return ""


func new_chat() -> void:
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
		assistant.unfocus()
	stop_asking_about()
	_bill = ""
	_sketch_bill = ""
	_sketch_cards = null
	_sketch_buttons = []
	_run = null
	for child: Node in _log.get_children():
		if child != _suggestions:
			child.queue_free()
	_show_suggestions()
	_status.text = ""
	_working = false
	_send.disabled = false
	_send.text = _send_words()
	_show_sketch_first()
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
	# A call from Claude runs through the same tools, which say what they
	# are doing; its card already has that step, said once.
	if _claude_busy and _claude_card():
		return
	_step(note)


func _step(note: String) -> void:
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
		while _run_past.get_child_count() > _run_keep:
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


## Put a card for this run at the foot of the conversation. Stop cancels
## the app's own design unless something else is given to do.
func _open_run(fresh: bool, stop: Callable = Callable()) -> void:
	_run_keep = RUN_STEPS
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
		if stop.is_valid():
			stop.call()
		elif assistant != null:
			assistant.cancel())
	column.add_child(_run_stop)

	_log.add_child(_run)
	_run_started = Time.get_ticks_msec()


## How long a design takes at the chosen setting, said plainly.
func _expect() -> String:
	if designing_elsewhere():
		return ("A design is 70 to 200 tool calls; how long that takes is the model's and "
			+ "the provider's. You can keep building, or look around, while it works.")
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
func _close_run(how: String, summary: String, built: bool = false,
		then: String = "Ask for a change below, or carry on building it by hand.") -> void:
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
		next.text = then
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
		if offers_hidden_colours.call():
			var offer := Button.new()
			offer.text = "Colour the hidden parts by section…"
			offer.tooltip_text = ("As big sets do: the parts nobody sees once it is finished, "
				+ "a colour for each section, so you can find your place while building. "
				+ "A preview first; nothing changes until you say so.")
			offer.focus_mode = Control.FOCUS_NONE
			offer.pressed.connect(func() -> void: hidden_colours_wanted.emit())
			_run_stop.get_parent().add_child(offer)
	_run = null


## The controls a person uses to design, by name, for whatever drives the
## app from outside to find them as a person would: by where they are.
## Offer the Claude connector, below the key form.
func use_connector(connector: ClaudeConnector) -> void:
	_connector_form = ConnectorForm.new()
	_connector_form.setup(connector)
	_key_form.get_parent().add_child(_connector_form)
	_key_form.get_parent().move_child(_connector_form, _key_form.get_index() + 1)
	_key_instead = Look.link("Use your own API key instead", 11)
	_key_instead.pressed.connect(func() -> void:
		_key_wanted = true
		_show_for_key(OwnKey.has_key()))
	_key_form.get_parent().add_child(_key_instead)
	_key_form.get_parent().move_child(_key_instead, _connector_form.get_index() + 1)
	connector.listening.connect(func(on: bool, _address: String) -> void:
		if not on and _claude_card():
			_close_claude("Connector off", "Switched off. Claude cannot reach "
				+ "this tab until it is switched on again.")
		_show_for_key(OwnKey.has_key()))
	connector.called.connect(_on_claude_called)
	connector.answered.connect(_on_claude_answered)
	# Claude connected to the account, or disconnected: the plan is, or is
	# no longer, the way in use.
	connector.connections_changed.connect(func(_now: Array) -> void:
		_show_for_key(OwnKey.has_key()))
	_connector = connector
	_show_for_key(OwnKey.has_key())


## The connector's line about where Claude stands, as the panel shows it.
func connector_status() -> String:
	return _connector_form._status.text if _connector_form != null \
		and _connector_form._state_row.visible else ""


## Claude on the person's plan, building through the connector: its calls
## on a card like the app's own designs get, every step kept with what came
## of it, so the panel says what Claude is doing and scrolls back through
## all it did. Before, the only sign was a count in small type under the
## connector, and nothing on the panel moved when Claude connected.
var _connector: ClaudeConnector = null
var _key_instead: LinkButton = null
var _key_wanted: bool = false
var _claude_on: bool = false
var _claude_busy: bool = false
var _claude_built: bool = false
var _claude_last: int = 0
## How long Claude can be quiet before its card says it is done. It thinks
## between calls, sometimes for a minute; a probe shortens this.
var claude_quiet_ms: int = 90000


func _claude_card() -> bool:
	return _claude_on and _run != null and is_instance_valid(_run)


func _on_claude_called(tool: String, arguments: Dictionary, _chat: String = "") -> void:
	if tool.is_empty():
		return
	_claude_last = Time.get_ticks_msec()
	var step: String = ConnectorForm.said(tool, arguments)
	# The app's own design has the card; say it alongside instead.
	if _working:
		note("Claude: " + step)
		return
	if not _claude_card():
		_claude_on = true
		_claude_built = false
		_open_run(true, func() -> void:
			if _connector != null:
				_connector.stop(true))
		_run_keep = 500
		_run_title.text = "Claude is building"
		_run_now.text = ""
		_run_hint.text = ("Claude, on your plan, is calling Brickworks from "
			+ "your chat. Each step shows here and the model appears on the "
			+ "baseplate, in view or not.")
		_run_stop.text = "Stop Claude in this tab"
		_run_stop.tooltip_text = ("Claude's next call is refused. What it "
			+ "has built stays.")
		_show_for_key(OwnKey.has_key())
	_claude_busy = true
	_run_clock.text = _elapsed()
	_step(step)
	_follow_the_card()


func _on_claude_answered(tool: String, ok: bool, text: String) -> void:
	if tool.is_empty() or not _claude_card():
		return
	_claude_busy = false
	_claude_last = Time.get_ticks_msec()
	_run_clock.text = _elapsed()
	if ok and tool in ["submit_design", "edit_model"]:
		_claude_built = true
	# What came of it, in its first line: a part number, a scale, a count
	# of bricks placed, or why it was refused.
	var first: String = text.strip_edges().split("\n")[0].strip_edges()
	if first.length() > 150:
		first = first.substr(0, 147) + "..."
	if not first.is_empty():
		_run_now.text = "%s — %s%s" % [_run_now.text, "" if ok else "refused: ", first]
	_follow_the_card()


func _close_claude(how: String, summary: String) -> void:
	var built: bool = _claude_built
	_claude_on = false
	_claude_busy = false
	_close_run(how, summary, built,
		"Ask Claude for a change in your chat, or carry on building it by hand.")


## Keep the newest step in view as the card grows.
func _follow_the_card() -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func controls_by_name() -> Dictionary:
	var named: Dictionary = {"brief": _input, "build": _send,
		"change_key": _out, "sketch_first": _sketch_first}
	if designing_elsewhere():
		named["ai_change"] = _out
	# Each sketch's button, by its card: sketch_1 to sketch_3.
	for button: Button in _sketch_buttons:
		if is_instance_valid(button) and not button.disabled:
			var card: Node = button.get_parent()
			while card != null and not str(card.name).begins_with("sketch_"):
				card = card.get_parent()
			if card != null:
				named[str(card.name)] = button
	if _key_form != null:
		named.merge(_key_form.controls_by_name())
	if _connector_form != null:
		named.merge(_connector_form.controls_by_name())
	if _run != null and is_instance_valid(_run):
		named["stop"] = _run_stop
	named["about"] = _chip_clear
	if _room_card != null and is_instance_valid(_room_card):
		for button: Button in _room_card.find_children("*", "Button", true, false):
			named["room_allow" if button.text == "Allow" else "room_refuse"] = button
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
	# The chip taken off while it ran: the next request is about the model.
	if not _chip.visible and assistant != null:
		assistant.unfocus()
	var on_card: bool = _run != null and is_instance_valid(_run)
	if summary == "cancelled":
		_close_run("Stopped", "Stopped. What was there before is back.")
	elif summary == "stopped":
		# Another AI's run: each call it made is a step of its own in the
		# history, so what it built stays, and undo takes it back.
		_close_run("Stopped", "Stopped. What it built so far stays; undo takes it back.")
	else:
		_close_run("Done" if ok else "Did not finish", _sentence(summary), ok)
	# A refused key will be refused again. Forget it and ask for another,
	# rather than leave it in place to fail the next brief the same way.
	if not ok and summary.begins_with(Assistant.KEY_REFUSED) \
			and OwnKey.has_key():
		OwnKey.forget()
		_show_for_key(OwnKey.has_key())
		_status.text = "Paste a working key to carry on."
		_send.text = _send_words()
		return
	# Not unconditionally: the key may have been changed while it ran.
	_send.disabled = not _why_not().is_empty()
	_send.text = _send_words()
	_show_sketch_first()
	# The bill goes in either way. A design that failed after three
	# repairs is the one you most want the cost of, and leaving it off
	# would mean the only runs anyone is billed for silently are the
	# ones that went wrong.
	var line: String = summary
	if not _bill.is_empty():
		# And the sketches it was chosen from, which were paid for too.
		if not _sketch_bill.is_empty():
			_bill += " · the sketches before it, %s" % _sketch_bill
			_sketch_bill = ""
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
	# Claude's card has its clock set as each call comes and goes, not every
	# second: a label changed is the whole window drawn again, and in a
	# browser drawing in software that was a frame of 12 to 15 CPU-seconds a
	# second, the drawing never at rest while Claude worked, and every
	# picture Claude asked for waiting behind it (2026-10-16).
	if _claude_card():
		# Quiet for long enough, with nothing in hand: Claude has finished,
		# or stopped to talk to the person.
		if not _claude_busy and Time.get_ticks_msec() - _claude_last > claude_quiet_ms:
			_close_claude("Done" if _claude_built else "Claude stopped",
				"Claude has stopped calling for now." if _claude_built
				else "Claude has stopped calling. Ask it to build in your chat.")
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
