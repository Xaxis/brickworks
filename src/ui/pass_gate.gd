## The screen for a desktop build the signed-in account does not cover
## ([DesktopPass], docs/PLANS.md §4 step 4): "This version of the desktop
## app comes with Pro," with See Pro, Open the web app and Sign in with
## another account, and where the models on this computer are kept, since
## the web app opens them (File, Open). Check again asks the deployment
## once more, after a renewal.
##
## It lies over the whole window as [SignInGate] does, in the same card,
## and only at start: once the app is open it stays open (DesktopPass).
## It never deletes or locks a file. Under it while the deployment is
## asked, "Checking your plan…".
class_name PassGate
extends Control

const WIDE := 440.0

var pass_check: DesktopPass

var _card: PanelContainer
var _title: Label
var _lines: VBoxContainer
var _buttons: VBoxContainer
var _see_pro: Button
var _web: Button
var _other: Button
var _again: Button


func setup(with_pass: DesktopPass) -> void:
	pass_check = with_pass
	add_to_group(FocusGuard.OVER)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.08, 0.80)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	# SignInGate's card: the Help panel's colours, border and corners.
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

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)

	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 8)
	_lines.add_child(_line("Every version released while an account has Pro stays that account's, "
		+ "for good. The web app is free, in any browser.", 13, 0.85))
	_lines.add_child(_line(models_words(), 12, 0.7))
	column.add_child(_lines)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	column.add_child(_buttons)
	_see_pro = _button("See Pro", func() -> void: OS.shell_open(Deployment.api_base() + "/plans"))
	_web = _button("Open the web app", func() -> void: OS.shell_open(Deployment.api_base() + "/app"))
	_other = _button("Sign in with another account", func() -> void: pass_check.account.sign_out())
	_again = _button("Check again", func() -> void: pass_check.recheck())

	pass_check.changed.connect(_follow)
	pass_check.account.changed.connect(_follow)
	_follow()


## Where the models on this computer are, and what opens them.
static func models_words() -> String:
	return "Your models on this computer stay in %s. The web app opens them: File, Open." \
		% ProjectSettings.globalize_path(ModelStore.SAVE_DIR)


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


## Its buttons, for a probe to find.
func controls_by_name() -> Dictionary:
	if not visible or not _buttons.visible:
		return {}
	return {"pass_see_pro": _see_pro, "pass_web": _web, "pass_other": _other, "pass_again": _again}


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(pressed)
	_buttons.add_child(button)
	return button


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
	visible = pass_check.blocks()
	var closed: bool = pass_check.verdict == DesktopPass.Verdict.CLOSED
	_title.text = "This version of the desktop app comes with Pro." if closed else "Checking your plan…"
	_lines.visible = closed
	_buttons.visible = closed


## Every click and key that reaches here while it is up stops here.
func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
