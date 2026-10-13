## A model shared by link, open to look at: /app?view=<id>, which the
## page's shell hands the app as --view=<id>.
##
## The same app, in a read-only mode, rather than a second renderer: the
## model as the builder draws it, turned with the mouse, its steps
## scrubbed on the timeline, the booklet and the parts list as the builder
## makes them. What this adds is the frame round it — the model's name,
## who made it if they said, its part count, and Open in Brickworks — and
## the words for a link that is loading, taken down or wrong.
##
## Everything that edits is out of reach from here; main.gd says how
## (_enter_view), and no sign-in is asked for. A visitor who wants the
## model for their own presses Open in Brickworks, which signs them in and
## copies it into their models (/app?copy=<id>).
class_name ShareView
extends Control

signal steps_wanted
signal booklet_wanted
signal parts_wanted
signal copy_wanted

## loading, parts, ready, gone, failed.
var state: String = "loading"
var model_name: String = ""
var author: String = ""
var parts: int = 0
var link: String = ""

var _bar: PanelContainer
var _name: Label
var _about: Label
var _steps: Button
var _booklet: Button
var _parts: Button
var _copy: Button
var _card: PanelContainer
var _card_title: Label
var _card_words: Label
var _card_button: Button
var _card_action: Callable = Callable()
var _hover: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bar()
	_build_card()
	_hover = Label.new()
	_hover.add_theme_font_size_override("font_size", 12)
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.06, 0.07, 0.09, 0.86)
	pill.set_corner_radius_all(4)
	pill.content_margin_left = 7
	pill.content_margin_right = 7
	pill.content_margin_top = 2
	pill.content_margin_bottom = 3
	_hover.add_theme_stylebox_override("normal", pill)
	_hover.visible = false
	add_child(_hover)


func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.09, 0.10, 0.12, 0.95)
	backing.border_color = Color(1, 1, 1, 0.10)
	backing.border_width_bottom = 1
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 8
	backing.content_margin_bottom = 8
	_bar.add_theme_stylebox_override("panel", backing)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_bar.add_child(row)

	var home := Look.link("Brickworks", 13)
	home.tooltip_text = "Brickworks: design LEGO® models in your browser"
	home.pressed.connect(func() -> void: OS.shell_open(Deployment.api_base() + "/"))
	home.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(home)

	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.clip_contents = true
	row.add_child(words)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 16)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.text = "A shared model"
	words.add_child(_name)
	_about = Label.new()
	_about.add_theme_font_size_override("font_size", 12)
	_about.modulate = Color(1, 1, 1, 0.7)
	_about.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(_about)

	_steps = _button(row, "Steps", "Step through the build (B)")
	_steps.pressed.connect(func() -> void: steps_wanted.emit())
	_booklet = _button(row, "Booklet", "The building instructions, page by page, to read or print")
	_booklet.pressed.connect(func() -> void: booklet_wanted.emit())
	_parts = _button(row, "Parts list", "Every part, with BrickLink and Rebrickable lists (P)")
	_parts.pressed.connect(func() -> void: parts_wanted.emit())
	_copy = _button(row, "Open in Brickworks",
		"Sign in and get a copy of your own to change — the shared one stays as it is")
	var bright := StyleBoxFlat.new()
	bright.bg_color = Color(0.78, 0.06, 0.18)
	bright.set_corner_radius_all(5)
	bright.content_margin_left = 12
	bright.content_margin_right = 12
	bright.content_margin_top = 5
	bright.content_margin_bottom = 5
	_copy.add_theme_stylebox_override("normal", bright)
	var lit: StyleBoxFlat = bright.duplicate()
	lit.bg_color = Color(0.88, 0.14, 0.26)
	_copy.add_theme_stylebox_override("hover", lit)
	_copy.add_theme_stylebox_override("pressed", lit)
	_copy.pressed.connect(func() -> void: copy_wanted.emit())
	for button: Button in [_steps, _booklet, _parts, _copy]:
		button.disabled = true


func _button(row: Container, words: String, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_face(button)
	row.add_child(button)
	return button


## A face of its own, as the timeline's buttons have: drawn flat, the bar
## read as a line of words and not as things to press.
static func _face(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(1, 1, 1, {"normal": 0.08, "hover": 0.16, "pressed": 0.24,
			"disabled": 0.03}[state])
		face.border_color = Color(1, 1, 1, 0.16)
		face.set_border_width_all(1)
		face.set_corner_radius_all(5)
		face.content_margin_left = 12
		face.content_margin_right = 12
		face.content_margin_top = 5
		face.content_margin_bottom = 5
		button.add_theme_stylebox_override(state, face)


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.custom_minimum_size = Vector2(420, 0)
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.97)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 22
	backing.content_margin_right = 22
	backing.content_margin_top = 18
	backing.content_margin_bottom = 18
	_card.add_theme_stylebox_override("panel", backing)
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)
	_card_title = Label.new()
	_card_title.add_theme_font_size_override("font_size", 17)
	_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A width to wrap at: measured before layout, a label counts every word
	# as a line and the card came out taller than the window.
	_card_title.custom_minimum_size = Vector2(376, 0)
	column.add_child(_card_title)
	_card_words = Label.new()
	_card_words.custom_minimum_size = Vector2(376, 0)
	_card_words.add_theme_font_size_override("font_size", 13)
	_card_words.modulate = Color(1, 1, 1, 0.75)
	_card_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_card_words)
	_card_button = Button.new()
	_card_button.focus_mode = Control.FOCUS_NONE
	_card_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_face(_card_button)
	_card_button.pressed.connect(func() -> void:
		if _card_action.is_valid():
			_card_action.call())
	column.add_child(_card_button)


func _say(title: String, words: String, button: String = "", action: Callable = Callable()) -> void:
	_card.visible = true
	_card_title.text = title
	_card_words.text = words
	_card_words.visible = not words.is_empty()
	_card_button.text = button
	_card_button.visible = not button.is_empty()
	_card_action = action
	# Sized to what it now says, and kept in the middle.
	_card.reset_size()
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func loading() -> void:
	state = "loading"
	_say("Opening the shared model…", "")


func arriving(left: int) -> void:
	state = "parts"
	_say("Fetching its parts…", "%d still on their way." % left)


## The model is open: its name and the rest along the top.
func show_model(shown_name: String, shown_author: String, part_count: int, at: String) -> void:
	model_name = shown_name
	author = shown_author
	parts = part_count
	link = at
	_name.text = shown_name
	_about.text = "%s part%s%s" % [_count(part_count), "" if part_count == 1 else "s",
		(" · by " + shown_author) if not shown_author.is_empty() else ""]


func ready_to_look() -> void:
	state = "ready"
	_card.visible = false
	for button: Button in [_steps, _booklet, _parts, _copy]:
		button.disabled = false


func gone(title: String, words: String) -> void:
	state = "gone"
	_name.text = title
	_about.text = ""
	# Nothing to step through, read or copy.
	for button: Button in [_steps, _booklet, _parts, _copy]:
		button.visible = false
	_say(title, words, "Go to Brickworks",
		func() -> void: OS.shell_open(Deployment.api_base() + "/"))


func failed(words: String, again: Callable) -> void:
	state = "failed"
	_say("This model did not open", words, "Try again", again)


## Name the part under the pointer beside it, or nothing.
func hover(words: String, at: Vector2) -> void:
	_hover.visible = not words.is_empty()
	if not _hover.visible:
		return
	_hover.text = words
	_hover.reset_size()
	var spot: Vector2 = at + Vector2(16, 18)
	spot.x = minf(spot.x, size.x - _hover.size.x - 6.0)
	spot.y = minf(spot.y, size.y - _hover.size.y - 6.0)
	_hover.position = spot


## The bar along the top, put at the head of [param column] in place of
## the builder's own bars, so the model's view starts below it.
func put_bar_in(column: Control) -> void:
	column.add_child(_bar)
	column.move_child(_bar, 0)


static func _count(n: int) -> String:
	var digits: String = str(n)
	var out: String = ""
	for index: int in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			out += ","
		out += digits[index]
	return out


func covers(point: Vector2) -> bool:
	return (_bar.is_visible_in_tree() and _bar.get_global_rect().has_point(point)) \
		or (_card.is_visible_in_tree() and _card.get_global_rect().has_point(point))


func controls_by_name() -> Dictionary:
	var named: Dictionary = {"view_steps": _steps, "view_booklet": _booklet,
		"view_parts": _parts, "view_copy": _copy}
	if _card.visible and _card_button.visible:
		named["view_card_button"] = _card_button
	return named


func page_state() -> Dictionary:
	return {"state": state, "name": model_name, "author": author, "parts": parts,
		"link": link, "title": _card_title.text if _card.visible else "",
		"says": _card_words.text if _card.visible else "", "hover": _hover.text if _hover.visible else ""}
