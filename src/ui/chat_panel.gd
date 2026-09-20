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
		_showing_sign_in = true
		_on_account_changed())
	root.add_child(_key_form)


func bind(to: Assistant) -> void:
	assistant = to
	assistant.said.connect(_on_said)
	assistant.progress.connect(_on_progress)
	assistant.finished.connect(_on_finished)
	assistant.built.connect(_on_built)


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

	_composer.visible = allowed
	_key_form.visible = not allowed and not _showing_sign_in
	_gate.visible = not allowed and _showing_sign_in and account.available

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
	if assistant:
		assistant.cancel()
		assistant.clear_built()
	for child: Node in _log.get_children():
		if child != _suggestions:
			child.queue_free()
	_suggestions.visible = true
	_show_suggestions()
	_status.text = ""
	_working = false
	_send.disabled = false
	_send.text = "Build it"


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
	_send.disabled = false
	_send.text = "Build it"
	if ok:
		_status.text = summary
	else:
		_add(summary, _Role.NOTE)
		_status.text = ""


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
