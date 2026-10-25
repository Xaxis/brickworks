## The way in: nothing in Brickworks can be used until someone is signed
## in.
##
## Everyone who uses Brickworks has an account (2026-10-11), and this is
## where they make one or come back to it. It lies over the whole window,
## the builder dimmed behind it so a first-time visitor can see what they
## are signing in to, and takes every click and key until [Account] lets
## them in — then it goes, and the builder is as they left it.
##
## What it shows follows the account: "Signing you in…" while a session
## kept on this device is renewed (so a returning visitor sees that for a
## moment, not a form); the email-then-code form ([SignInForm]) for
## somebody signed out, with the reason when a session ended rather than
## being ended; and "cannot reach Brickworks" with Try again when there is
## nowhere to sign in — a first start with no connection.
##
## Then, once, the age question (2026-10-18, supabase/trust.sql): the month
## and year they were born, asked of everyone the same way, with nothing
## before the answer to say which answer opens what. The deployment keeps
## only whether that is 13 or over ([method Account.answer_age]). Under 13,
## the screen says afterwards what is and is not open to them — building,
## keeping models and sharing by link are; the gallery and anything public
## are not — and lets them in. Not asked offline, nor by a deployment from
## before the question.
##
## Not shown at all when nobody is in front of the window: a probe, a
## headless run, or a command-line run that renders, exports or designs
## and quits (Main._gate_wanted). And not when the deployment has no
## accounts (a local server, somebody's own copy): there is nothing to
## sign in to.
class_name SignInGate
extends Control

## The card's width, before the window has its say.
const WIDE := 420.0

var account: Account

var _card: PanelContainer
var _form: SignInForm
var _ended: Label
## The line saying what an account is and where the models are kept.
var _keeps: Label
var _checking: Label
var _unreachable: VBoxContainer
var _retry: Button
var _shown_form: bool = false
var _title: Label
var _age: VBoxContainer
var _months: Array[Button] = []
var _year: LineEdit
var _age_go: Button
var _age_note: Label
var _thanks: VBoxContainer
var _thanks_go: Button
## The answer was under 13 and the screen is saying what that means.
var _thanking: bool = false
var _answering: bool = false

const MONTHS: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


func setup(with_account: Account) -> void:
	account = with_account
	# Over the frame: Tab and F6 go into it, and Tab in its fields goes on to
	# the next control (FocusGuard). Every button here is in the keys' reach
	# (Access), so the way in needs no mouse.
	add_to_group(FocusGuard.OVER)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# The builder behind, dimmed: what they are signing in to.
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.08, 0.80)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	# The app's own panel: the Help panel's colours, border and corners.
	_card = PanelContainer.new()
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.98)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 26
	backing.content_margin_right = 26
	backing.content_margin_top = 22
	backing.content_margin_bottom = 22
	backing.shadow_color = Color(0, 0, 0, 0.35)
	backing.shadow_size = 18
	_card.add_theme_stylebox_override("panel", backing)
	centre.add_child(_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_card.add_child(column)

	var mark := HBoxContainer.new()
	mark.add_theme_constant_override("separation", 8)
	column.add_child(mark)
	var chip := ColorRect.new()
	chip.color = Color(0.95, 0.80, 0.22)
	chip.custom_minimum_size = Vector2(14, 14)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.add_child(chip)
	var name_label := Label.new()
	name_label.text = "Brickworks"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.modulate = Color(1, 1, 1, 0.75)
	mark.add_child(name_label)

	_title = Label.new()
	_title.text = "Sign in to start building"
	_title.add_theme_font_size_override("font_size", 20)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)

	_ended = _line("", 12, 1.0)
	_ended.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45))
	column.add_child(_ended)

	_checking = _line("Signing you in…", 14, 0.8)
	column.add_child(_checking)

	_form = SignInForm.new()
	_form.setup(account)
	column.add_child(_form)

	_unreachable = VBoxContainer.new()
	_unreachable.add_theme_constant_override("separation", 10)
	_unreachable.add_child(_line("Cannot reach Brickworks to sign in. Check "
		+ "your connection, then try again.", 13, 0.85))
	_retry = Button.new()
	_retry.text = "Try again"
	_retry.custom_minimum_size = Vector2(0, 36)
	_retry.focus_mode = Control.FOCUS_NONE
	_retry.pressed.connect(func() -> void: account.boot())
	_unreachable.add_child(_retry)
	column.add_child(_unreachable)

	_build_age(column)

	column.add_child(HSeparator.new())
	# What an account is and is not, where it is asked for.
	_keeps = _line(keeps_words(), 11, 0.6)
	column.add_child(_keeps)

	account.changed.connect(_follow)
	_follow()


## The age question, and what an answer under 13 means, said after it.
## Neutral: the same question for everyone, no hint before it of what
## either answer opens.
func _build_age(column: VBoxContainer) -> void:
	_age = VBoxContainer.new()
	_age.add_theme_constant_override("separation", 10)
	column.add_child(_age)
	_age.add_child(_line("When were you born?", 15, 0.95))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_age.add_child(grid)
	var group := ButtonGroup.new()
	for at: int in MONTHS.size():
		var month := Button.new()
		month.text = MONTHS[at]
		month.toggle_mode = true
		month.button_group = group
		month.focus_mode = Control.FOCUS_NONE
		month.custom_minimum_size = Vector2(52, 34)
		month.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		month.add_theme_font_size_override("font_size", 13)
		grid.add_child(month)
		_months.append(month)
	_year = LineEdit.new()
	_year.placeholder_text = "Year"
	_year.max_length = 4
	_year.custom_minimum_size = Vector2(0, 36)
	_year.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_year.keep_editing_on_text_submit = true
	_year.text_submitted.connect(func(_t: String) -> void: _answer())
	_age.add_child(_year)
	_age_go = Button.new()
	_age_go.text = "Carry on"
	_age_go.custom_minimum_size = Vector2(0, 36)
	_age_go.focus_mode = Control.FOCUS_NONE
	_age_go.pressed.connect(_answer)
	_age.add_child(_age_go)
	_age_note = _line("", 12, 1.0)
	_age_note.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45))
	_age_note.visible = false
	_age.add_child(_age_note)
	_age.add_child(_line("Brickworks asks everyone this once. The date itself is not kept.",
		11, 0.6))

	_thanks = VBoxContainer.new()
	_thanks.add_theme_constant_override("separation", 10)
	column.add_child(_thanks)
	_thanks.add_child(_line("Thank you. You can build here, keep your models and share "
		+ "them by link with anyone you choose.", 14, 0.9))
	_thanks.add_child(_line("The gallery, a public profile and a name shown on a link "
		+ "are for people 13 and over, so they are not open on this account.", 13, 0.75))
	_thanks_go = Button.new()
	_thanks_go.text = "Start building"
	_thanks_go.custom_minimum_size = Vector2(0, 36)
	_thanks_go.focus_mode = Control.FOCUS_NONE
	_thanks_go.pressed.connect(func() -> void:
		_thanking = false
		_follow())
	_thanks.add_child(_thanks_go)


## The month chosen, 1 to 12, or 0 for none.
## Whether the age question, and the thanks after it, were showing at the
## last _follow: the keys are put on them once, as each shows.
var _asked_shown: bool = false
var _thanks_shown: bool = false


func _month() -> int:
	for at: int in _months.size():
		if _months[at].button_pressed:
			return at + 1
	return 0


func _answer() -> void:
	if _answering:
		return
	var month: int = _month()
	var typed: String = _year.text.strip_edges()
	var this_year: int = int(Time.get_datetime_dict_from_system()["year"])
	if month == 0 or not typed.is_valid_int() or typed.length() != 4 \
			or int(typed) > this_year or int(typed) < this_year - 120:
		_age_note.text = "Choose the month, and type the year as four digits."
		_age_note.visible = true
		return
	_answering = true
	_age_go.disabled = true
	_age_note.visible = false
	var problem: String = await account.answer_age(month, int(typed))
	_answering = false
	_age_go.disabled = false
	if not problem.is_empty():
		_age_note.text = problem
		_age_note.visible = true
		return
	_thanking = account.over_13 == false
	_follow()


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


## The form's controls and Try again, for the page to find.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	if _thanks.visible:
		return {"age_done": _thanks_go}
	if _age.visible:
		var asked: Dictionary = {"age_year": _year, "age_go": _age_go}
		for at: int in _months.size():
			asked["age_month_%d" % (at + 1)] = _months[at]
		return asked
	var named: Dictionary = _form.controls_by_name()
	named["signin_retry"] = _retry
	return named


## What an account is and where the models are kept, true in every way
## they stand with it (CloudModels.standing): saved on this device and,
## signed in, with the account too (2026-10-23), so they open wherever the
## person signs in; not with it only on a deployment that keeps none. It
## said "not with your account" to somebody whose account had their model
## (walk239's A12). Claude only for a device that has the assistant
## (Settings, Assistant (AI)).
static func keeps_words() -> String:
	var where: String = "saved on this device, not with your account" \
		if CloudModels.standing == "none" \
		else "saved on this device and kept with your account, so they open wherever you sign in"
	return "An account is your email address and nothing else. Your models are %s%s" % [where,
		"; Claude runs on your own plan or API key." if ShellPrefs.assistant_shown() else "."]


func _line(text: String, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, alpha)
	return label


func _fit() -> void:
	var room: Vector2 = get_viewport_rect().size
	# In the layout for a finger, as wide in points as the desktop's card,
	# and the screen's width less a gutter each side at the most: in units
	# it was 227 points of a phone's 390, with its words grown to points
	# (TouchSizing).
	if Phone.on():
		_card.custom_minimum_size = Vector2(minf(Phone.px(get_viewport(), WIDE),
			room.x - Phone.px(get_viewport(), 2.0 * TouchSizing.GUTTER)), 0)
		return
	_card.custom_minimum_size = Vector2(minf(WIDE, room.x - 24.0), 0)


func _follow() -> void:
	var state: int = account.state
	var signed_in: bool = state == Account.State.SIGNED_IN
	var asking_age: bool = signed_in and account.age_ask and not _thanking
	var waiting: bool = signed_in and account.asking_who and not asking_age and not _thanking
	if not signed_in:
		_thanking = false
	visible = not account.lets_in() or asking_age or waiting or _thanking
	_title.text = "One question first" if asking_age else (
		"Welcome to Brickworks" if _thanking else "Sign in to start building")
	_age.visible = asking_age
	_thanks.visible = _thanking and signed_in
	_checking.visible = state == Account.State.CHECKING or waiting
	_form.visible = state == Account.State.SIGNED_OUT
	_unreachable.visible = state == Account.State.UNREACHABLE
	_keeps.text = keeps_words()
	_ended.text = account.ended
	_ended.visible = state == Account.State.SIGNED_OUT and not account.ended.is_empty()
	if _form.visible and not _shown_form:
		_shown_form = true
		_form.focus_first.call_deferred()
	if not _form.visible:
		_shown_form = false
	# The keys on the question's first control, as they are on the form's
	# field, so the keyboard alone carries on (the focus not drawn till a
	# key moves it).
	if asking_age and not _asked_shown:
		_months[0].grab_focus.call_deferred(true)
	if _thanks.visible and not _thanks_shown:
		_thanks_go.grab_focus.call_deferred(true)
	_asked_shown = asking_age
	_thanks_shown = _thanks.visible


## Every click and key that reaches here while it is up stops here: they
## are the builder's, and a shortcut pressed on the sign-in screen would
## change a model nobody can see.
func _unhandled_input(event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
