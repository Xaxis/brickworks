## The way in: nothing in Brickworks can be used until someone is signed
## in.
##
## Everyone who uses Brickworks has an account (2026-10-11), and this is
## where they make one or come back to it. It lies over the whole window,
## the builder dimmed behind it so a first-time visitor can see what they
## are signing in to, and takes every click and key until [Account] lets
## them in — then it goes, and the builder is as they left it.
##
## What it shows follows the account: nothing at all for a returning
## visitor, whose session kept on this device lets them in at once and is
## renewed behind their model (Account.renewing: walk256's A17 waited about
## 18 s on "Signing you in…" at every load), the screen coming up only if
## the renewal is refused; "Signing you in…" while the deployment is still
## asked where to sign in, or just after a code, for the age question; the
## email-then-code form ([SignInForm]) for somebody signed out, with the
## reason when a session ended rather than being ended; and "cannot reach
## Brickworks" with Try again when there is nowhere to sign in — a first
## start with no connection.
##
## Then, once, the age question (2026-10-18, supabase/trust.sql): the month
## and year they were born, asked of everyone the same way, with nothing
## before the answer to say which answer opens what. Brickworks accounts are
## for 13 and over (2026-11-03): 13 or over, the deployment keeps only that
## ([method Account.answer_age]) and lets them in; under 13, it deletes the
## account just made, and the screen goes back to the way in, saying that
## accounts are for 13 and over and to ask a parent or guardian to sign in
## with their own email and build with them. It says so at once on this
## device from then on ([member Account.refused]), and a new account signed
## in here is not asked again. Not asked offline, nor by a deployment from
## before the question.
##
## Then, while the beta is open, a new account's welcome to it (betajoin,
## 2026-11-09): joining the beta is a step of signing up. Once, right after
## the code and the age question: what Brickworks is, that it is in beta,
## what a tester does and gets, and Join the beta testers or Not now, with
## nothing chosen for them. Join makes the account a tester at once and
## says so in place, with where things are now and Start building; Not now
## lets them in, and the deployment keeps either answer, so it is never
## asked again ([method Account.join_beta], [method Account.leave_beta]).
## The deployment says when it is due ([member Account.beta_welcome]).
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
## Accounts are for 13 and over, said to a device told so, and that the
## account just made is gone, said just after.
var _refused: VBoxContainer
var _gone: Label
var _answering: bool = false
## The beta's welcome: its words and two choices, then the thank-you after
## Join, which stays until Start building.
var _beta_mark: Label
var _welcome: VBoxContainer
var _welcome_join: Button
var _welcome_later: Button
var _welcome_note: Label
var _thanks: VBoxContainer
var _thanks_go: Button
var _thanking: bool = false
var _welcome_busy: bool = false
var _welcome_shown: bool = false
## The rule over what an account is, which the welcome leaves out.
var _rule: HSeparator

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
	# The beta named beside the name, small, in the brick's yellow: the
	# welcome's only label, not a banner.
	_beta_mark = Label.new()
	_beta_mark.text = "Open beta"
	_beta_mark.uppercase = true
	_beta_mark.add_theme_font_size_override("font_size", 11)
	_beta_mark.add_theme_color_override("font_color", Color(0.95, 0.80, 0.22))
	_beta_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_beta_mark.visible = false
	mark.add_child(_beta_mark)

	_title = Label.new()
	_title.text = "Sign in to start building"
	_title.add_theme_font_size_override("font_size", 20)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)

	_ended = _line("", 12, 1.0)
	_ended.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45))
	column.add_child(_ended)

	_refused = VBoxContainer.new()
	_refused.add_theme_constant_override("separation", 8)
	_refused.add_child(_line("Brickworks accounts are for 13 and over. Ask a parent or guardian "
		+ "to sign in with their own email and build with you.", 14, 0.95))
	_gone = _line("The account is deleted, with your email address. The date was never kept.",
		12, 0.75)
	_refused.add_child(_gone)
	_refused.add_child(_line("A parent or guardian new to Brickworks makes their account on "
		+ "their own phone or computer first, then signs in here.", 12, 0.75))
	column.add_child(_refused)

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
	_build_welcome(column)

	_rule = HSeparator.new()
	column.add_child(_rule)
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


## The beta's welcome and the thank-you after Join.
func _build_welcome(column: VBoxContainer) -> void:
	_welcome = VBoxContainer.new()
	_welcome.add_theme_constant_override("separation", 10)
	column.add_child(_welcome)
	_welcome.add_child(_line("A CAD for LEGO® models: every LDraw part, joined where the real ones "
		+ "join.", 15, 0.95))
	_welcome.add_child(_line("It is in open beta: it works, and it gets better every week with what "
		+ "builders tell us.", 13, 0.8))
	_welcome.add_child(_aside("Testers try new features first and tell us what is wrong. The "
		+ "first 100 we pick get a month of Pro."))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_welcome.add_child(row)
	_welcome_join = Button.new()
	_welcome_join.text = "Join the beta testers"
	_welcome_join.theme_type_variation = &"DefaultButton"
	_welcome_join.custom_minimum_size = Vector2(0, 38)
	_welcome_join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_welcome_join.focus_mode = Control.FOCUS_NONE
	_welcome_join.pressed.connect(_join)
	row.add_child(_welcome_join)
	_welcome_later = Button.new()
	_welcome_later.text = "Not now"
	_welcome_later.custom_minimum_size = Vector2(0, 38)
	_welcome_later.focus_mode = Control.FOCUS_NONE
	_welcome_later.pressed.connect(_not_now)
	row.add_child(_welcome_later)
	_welcome_note = _line("", 12, 1.0)
	_welcome_note.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45))
	_welcome_note.visible = false
	_welcome.add_child(_welcome_note)
	_welcome.add_child(_line("Joining agrees to the beta's terms and to emails about the beta. "
		+ "Leave any time in Account.", 11, 0.6))

	_thanks = VBoxContainer.new()
	_thanks.add_theme_constant_override("separation", 10)
	column.add_child(_thanks)
	_thanks.add_child(_line("Thank you. Report a bug whenever something is wrong, from wherever you "
		+ "are. What you send, and our answers, are kept with your account.", 14, 0.9))
	_thanks.add_child(_aside("For a month of Pro, tell us what you build on the beta's page: it "
		+ "takes a minute."))
	var about: LinkButton = Look.link("Tell us what you build", 12)
	about.uri = (Origin.here() if OS.has_feature("web") else Deployment.api_base()) + "/beta#apply"
	_thanks.add_child(about)
	_thanks_go = Button.new()
	_thanks_go.text = "Start building"
	_thanks_go.theme_type_variation = &"DefaultButton"
	_thanks_go.custom_minimum_size = Vector2(0, 38)
	_thanks_go.focus_mode = Control.FOCUS_NONE
	_thanks_go.pressed.connect(func() -> void:
		_thanking = false
		_follow())
	_thanks.add_child(_thanks_go)


## A line set apart: the tester's part, on a faint panel with the brick's
## yellow down its left edge.
func _aside(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var face := StyleBoxFlat.new()
	face.bg_color = Color(1, 1, 1, 0.05)
	face.border_color = Color(0.95, 0.80, 0.22, 0.9)
	face.border_width_left = 3
	face.corner_radius_top_right = 4
	face.corner_radius_bottom_right = 4
	face.content_margin_left = 12
	face.content_margin_right = 10
	face.content_margin_top = 8
	face.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", face)
	panel.add_child(_line(text, 13, 0.92))
	return panel


func _join() -> void:
	if _welcome_busy:
		return
	_welcome_busy = true
	_welcome_join.disabled = true
	_welcome_later.disabled = true
	_welcome_note.visible = false
	var problem: String = await account.join_beta("app")
	_welcome_busy = false
	_welcome_join.disabled = false
	_welcome_later.disabled = false
	if not problem.is_empty():
		_welcome_note.text = problem
		_welcome_note.visible = true
		return
	_thanking = true
	_follow()


func _not_now() -> void:
	if _welcome_busy:
		return
	_welcome_busy = true
	_welcome_join.disabled = true
	_welcome_later.disabled = true
	var problem: String = await account.leave_beta()
	_welcome_busy = false
	_welcome_join.disabled = false
	_welcome_later.disabled = false
	if not problem.is_empty():
		# Not kept: let in all the same. The welcome comes again at the next
		# sign-in, which is the most it can do.
		account.beta_welcome = false
	_follow()


## Whether the age question was showing at the last _follow: the keys are
## put on it once, as it shows.
var _asked_shown: bool = false


## The month chosen, 1 to 12, or 0 for none.

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
	_follow()


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


## The form's controls and Try again, for the page to find.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	if _welcome.visible:
		return {"beta_join": _welcome_join, "beta_not_now": _welcome_later}
	if _thanks.visible:
		return {"beta_start": _thanks_go}
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
	# A device told before is not asked: it waits while the new account goes.
	var asking_age: bool = signed_in and account.age_ask and not account.refused
	var waiting: bool = signed_in and (account.asking_who or (account.age_ask and account.refused)) \
		and not asking_age
	# The beta's welcome after the age question, and its thank-you.
	if not signed_in:
		_thanking = false
	var thanking: bool = signed_in and _thanking and not asking_age
	var welcoming: bool = signed_in and account.beta_welcome and not asking_age and not waiting \
		and not thanking
	visible = not account.lets_in() or asking_age or waiting or welcoming or thanking
	var told: bool = account.refused and state == Account.State.SIGNED_OUT
	_title.text = "One question first" if asking_age else (
		"Welcome to Brickworks" if welcoming else (
		"You are a beta tester" if thanking else (
		"Accounts are for 13 and over" if told else "Sign in to start building")))
	_beta_mark.visible = welcoming or thanking
	_welcome.visible = welcoming
	_thanks.visible = thanking
	_age.visible = asking_age
	_refused.visible = told
	_gone.visible = account.refused_now
	_checking.visible = state == Account.State.CHECKING or waiting
	_form.visible = state == Account.State.SIGNED_OUT
	_unreachable.visible = state == Account.State.UNREACHABLE
	_keeps.text = keeps_words()
	_keeps.visible = not (welcoming or thanking)
	_rule.visible = _keeps.visible
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
	_asked_shown = asking_age
	if welcoming and not _welcome_shown:
		_welcome_join.grab_focus.call_deferred(true)
	_welcome_shown = welcoming
	if thanking:
		_thanks_go.grab_focus.call_deferred(true)


## Every click and key that reaches here while it is up stops here: they
## are the builder's, and a shortcut pressed on the sign-in screen would
## change a model nobody can see.
func _unhandled_input(event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
