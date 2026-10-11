## Who is signed in, and the way out.
##
## Opened from Account on the toolbar. Says which address this is, whether
## Brickworks could confirm it just now (the desktop keeps working offline
## once signed in, and says so here rather than pretending), what the
## account holds — the address, not the models — and signs out. Signing
## out switches off this tab's Claude connector, because the connector
## belongs to the account.
##
## The owner's account (MASTER_EMAIL) also gets a link to the admin page,
## on the web, where the page is.
class_name AccountPanel
extends PanelContainer

## How big it would like to be, before the window has its say.
const WIDE := 420.0
const TALL := 290.0

var account: Account

var _who: Label
var _state: Label
var _admin: LinkButton
var _sign_out: Button
var _done: Button

## The person asked to sign out; the app switches the connector off and
## the sign-in screen comes back.
signal sign_out_wanted()


func setup(with_account: Account) -> void:
	account = with_account
	visible = false
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.98)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 18
	backing.content_margin_right = 18
	backing.content_margin_top = 15
	backing.content_margin_bottom = 15
	add_theme_stylebox_override("panel", backing)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var title := Label.new()
	title.text = "Your account"
	title.add_theme_font_size_override("font_size", 15)
	column.add_child(title)

	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 14)
	_who.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	column.add_child(_who)

	_state = _line("", 12, 0.7)
	column.add_child(_state)

	column.add_child(_line("Your account is your email address. Your models "
		+ "are saved on this device, not with it — export one as LDraw to "
		+ "take it elsewhere. A Claude connector you switch on belongs to "
		+ "this account.", 12, 0.7))

	_admin = Look.link("Accounts and connectors (admin)", 12)
	_admin.uri = "/admin.html"
	column.add_child(_admin)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_sign_out = Button.new()
	_sign_out.text = "Sign out"
	_sign_out.custom_minimum_size = Vector2(0, 34)
	_sign_out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sign_out.focus_mode = Control.FOCUS_NONE
	_sign_out.tooltip_text = ("Sign out of Brickworks on this device. Your "
		+ "models stay here; Claude's connector in this tab switches off.")
	_sign_out.pressed.connect(func() -> void:
		visible = false
		sign_out_wanted.emit())
	row.add_child(_sign_out)
	_done = Button.new()
	_done.text = "Done"
	_done.custom_minimum_size = Vector2(0, 34)
	_done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_done.focus_mode = Control.FOCUS_NONE
	_done.pressed.connect(func() -> void: visible = false)
	row.add_child(_done)

	account.changed.connect(_follow)
	_follow()


func open() -> void:
	_follow()
	visible = not visible


## Its controls, for the page to find.
func controls_by_name() -> Dictionary:
	return {"sign_out": _sign_out, "account_done": _done} if visible else {}


func _line(text: String, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, alpha)
	return label


func _follow() -> void:
	if not account.signed_in():
		visible = false
	_who.text = "Signed in as %s" % account.email if not account.email.is_empty() \
		else "Signed in"
	_state.text = ("Brickworks could not be reached just now, so this is "
		+ "the account kept on this device. It is checked again when "
		+ "Brickworks can be reached." if account.offline
		else "Signed in on this device until you sign out.")
	# The admin page is a page of the site, so only where the site is.
	_admin.visible = account.master and OS.has_feature("web")
	if _admin.visible:
		_admin.uri = Origin.here() + "/admin.html"


## Escape closes it, like the other panels.
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()
