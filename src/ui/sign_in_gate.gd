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
var _checking: Label
var _unreachable: VBoxContainer
var _retry: Button
var _shown_form: bool = false


func setup(with_account: Account) -> void:
	account = with_account
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

	var title := Label.new()
	title.text = "Sign in to start building"
	title.add_theme_font_size_override("font_size", 20)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

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

	column.add_child(HSeparator.new())
	# What an account is and is not, where it is asked for.
	column.add_child(_line("An account is your email address and nothing "
		+ "else. Your models are saved on this device, not with your "
		+ "account; Claude runs on your own plan or API key.", 11, 0.6))

	account.changed.connect(_follow)
	_follow()


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


## The form's controls and Try again, for the page to find.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var named: Dictionary = _form.controls_by_name()
	named["signin_retry"] = _retry
	return named


func _line(text: String, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, alpha)
	return label


func _fit() -> void:
	var room: Vector2 = get_viewport_rect().size
	_card.custom_minimum_size = Vector2(minf(WIDE, room.x - 24.0), 0)


func _follow() -> void:
	var state: int = account.state
	visible = not account.lets_in()
	_checking.visible = state == Account.State.CHECKING
	_form.visible = state == Account.State.SIGNED_OUT
	_unreachable.visible = state == Account.State.UNREACHABLE
	_ended.text = account.ended
	_ended.visible = state == Account.State.SIGNED_OUT and not account.ended.is_empty()
	if _form.visible and not _shown_form:
		_shown_form = true
		_form.focus_first.call_deferred()
	if not _form.visible:
		_shown_form = false


## Every click and key that reaches here while it is up stops here: they
## are the builder's, and a shortcut pressed on the sign-in screen would
## change a model nobody can see.
func _unhandled_input(event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
