## The app on a phone: built for a finger, not the desktop shrunk.
##
## walk180 found a phone given the desktop at half size: toolbar buttons
## 14 points across, colour swatches 9, a parts drawer over half the model
## that stayed open, and words for a mouse ("right-click", "Shift-drag").
## LEGO Builder is made for a phone and Mecabricks works by touch.
##
## So where Phone.on() says this is a phone, this replaces the menus, the
## toolbar, the key strip and the status line (Main hides them), laid out
## in points through Phone.px:
##
##   along the top    the model's name, Undo and Redo
##   along the foot   one row of what a phone builder reaches for: Parts,
##                    Colour, Turn, Tip, Select, Delete, and More, where
##                    every command of every menu is
##   over the model   a line in touch words of what a finger does now, or
##                    what was just said; Fit in the corner
##   sheets           the parts bin (Main's own, larger), swiped up to half
##                    or the whole screen; the colours, big swatches; More;
##                    and a part's own actions, a finger held on it, which
##                    are the desktop's right-click menu
##
## Every button runs what the desktop's does (Shell's commands, EditVerbs,
## the bin's own pick and swatch), so building behaves the same: only the
## controls change. Every target is at least Phone.TARGET points and no
## text under Phone.LEAST_TEXT.
##
## On a tablet (Phone.wide) the same, laid out wide: the sheets are panels
## down the sides between the bars, as the desktop's columns are, the parts
## on the left and the colours, More and a part's actions on the right. The
## parts stay open while the model is built beside them, and the model is
## framed in the room they leave (model_room); where there is no room for
## both sides, one opening puts the other away until it goes. The row's
## buttons keep their size, in the middle.
class_name PhoneShell
extends Control

var app: Node
var shell: Shell
var bin: PartsBin
## Laid out wide, for a tablet (Phone.wide).
var wide: bool = false

## Points to units, when the chrome was last laid out.
var _k: float = 1.0
var _top: PanelContainer
var _row: PanelContainer
var _pill: PanelContainer
var _pill_words: Label
var _fit: Button
var _name: LineEdit
var _colour_button: Button
var _tool_buttons: Dictionary = {}
var _sheets: Array[Sheet] = []
var _parts: Sheet
var _colours: Sheet
var _more: Sheet
var _context: Sheet
var _said: String = ""
var _said_until: int = 0
var _all_colours: bool = false
## The sheet opened last, which the page is told of first.
var _newest: Sheet
var _look_again_at: int = 0

const TOP := 52.0
const ROW := 72.0
## A tablet's panel, across: the parts bin's own width and its margins.
const SIDE := 400.0
## The least a tablet's panels leave the model across.
const MODEL_LEAST := 300.0
## A tablet's row button, across, and its name field.
const WIDE_TOOL := 96.0
const WIDE_NAME := 320.0
const BACK := Color(0.11, 0.12, 0.14, 0.97)
const LIT := Color(0.36, 0.6, 1.0, 0.38)

## The row along the foot: [what, word, icon].
const TOOLS: Array = [
	["parts", "Parts", "build"],
	["colour", "Colour", ""],
	["turn", "Turn", "rotate"],
	["tip", "Tip", "tip"],
	["select", "Select", "pointer"],
	["delete", "Delete", "delete"],
	["more", "More", ""],
]


func _ready() -> void:
	_pin(self, 0.0, 0.0, 1.0, 1.0, Rect2())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	get_viewport().size_changed.connect(_rebuild, CONNECT_DEFERRED)
	set_process(true)


func p(points: float) -> float:
	return points * _k


## Laid out again for a new size (a phone turned): the bin and the name
## field are Main's and the bar's, taken out first and put back.
func _rebuild() -> void:
	var k: float = Phone.per_point(get_viewport())
	if absf(k - _k) < 0.01 * _k:
		# The same points to the unit, as after Settings, Interface size,
		# which scales the window and its units alike: only the row's share
		# of the width has changed.
		_share_row()
		return
	if bin.get_parent() != null:
		bin.get_parent().remove_child(bin)
	if _name.get_parent() != null:
		_name.get_parent().remove_child(_name)
	# What was open opens again, laid out for the new size.
	var was: Array = []
	for sheet: Sheet in _sheets:
		if sheet.is_open() and sheet != _context:
			was.append([sheet.title, sheet.state])
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_sheets.clear()
	_tool_buttons.clear()
	_build()
	for one: Array in was:
		var sheet: Sheet = {"Parts": _parts, "Colour": _colours, "More": _more}.get(one[0])
		if sheet == _colours:
			_fill_colours()
		elif sheet == _more:
			_fill_more()
		_make_room(sheet)
		sheet.open(str(one[1]))


func _build() -> void:
	_k = Phone.per_point(get_viewport())
	wide = Phone.wide()
	_name = (app.get("_bar") as ModelBar).get("_name")

	# Along the top: the name, Undo, Redo.
	_top = _bar_panel()
	_pin(_top, 0.0, 0.0, 1.0, 0.0, Rect2(0, 0, 0, p(TOP)))
	add_child(_top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", ceili(p(6)))
	_top.add_child(top_row)
	if _name.get_parent() != null:
		_name.get_parent().remove_child(_name)
	_name.custom_minimum_size = Vector2(p(WIDE_NAME if wide else 120.0), p(Phone.TARGET))
	_name.size_flags_horizontal = Control.SIZE_FILL if wide else Control.SIZE_EXPAND_FILL
	_name.add_theme_font_size_override("font_size", ceili(p(16)))
	_name.tooltip_text = ""
	top_row.add_child(_name)
	if wide:
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_child(gap)
	for one: Array in [["undo", "undo"], ["redo", "redo"]]:
		var button: Button = _icon_button(str(one[1]), p(Phone.TARGET + 4.0))
		button.name = "phone_" + str(one[0])
		var what: String = str(one[0])
		button.pressed.connect(func() -> void: shell.run(what))
		top_row.add_child(button)
		_tool_buttons[what] = button

	# Along the foot: one row.
	_row = _bar_panel()
	_pin(_row, 0.0, 1.0, 1.0, 1.0, Rect2(0, -p(ROW), 0, 0))
	add_child(_row)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 0)
	if wide:
		tools.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_child(tools)
	for tool: Array in TOOLS:
		var button: Button = _tool(str(tool[0]), str(tool[1]), str(tool[2]))
		if wide:
			button.size_flags_horizontal = Control.SIZE_FILL
			button.custom_minimum_size.x = p(WIDE_TOOL)
		tools.add_child(button)
	_share_row()

	# What a finger does now, over the model's foot.
	_pill = PanelContainer.new()
	var pill_face := StyleBoxFlat.new()
	pill_face.bg_color = Color(0.09, 0.10, 0.12, 0.86)
	pill_face.set_corner_radius_all(ceili(p(16)))
	pill_face.content_margin_left = p(12)
	pill_face.content_margin_right = p(12)
	pill_face.content_margin_top = p(6)
	pill_face.content_margin_bottom = p(6)
	_pill.add_theme_stylebox_override("panel", pill_face)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill_words = Label.new()
	_pill_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pill_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pill_words.max_lines_visible = 2
	_pill_words.add_theme_font_size_override("font_size", ceili(p(13)))
	_pill_words.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_pill_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(_pill_words)
	add_child(_pill)

	# Fit, in the model's top corner, where the view cube is on a desktop.
	_fit = _icon_button("fit", p(Phone.TARGET + 4.0))
	_fit.name = "phone_fit"
	var round_face := StyleBoxFlat.new()
	round_face.bg_color = Color(0.11, 0.12, 0.14, 0.78)
	round_face.set_corner_radius_all(ceili(p(24)))
	for state: String in ["normal", "hover", "pressed"]:
		_fit.add_theme_stylebox_override(state, round_face)
	_pin(_fit, 1.0, 0.0, 1.0, 0.0, Rect2(-p(12 + 48), p(TOP + 12), -p(12), p(TOP + 12 + 48)))
	# A tablet's beside the panel on the right, when it is open (_lay_pill).
	if wide:
		_pin(_fit, 0.0, 0.0, 0.0, 0.0, Rect2(0, p(TOP + 12), p(48), p(TOP + 12 + 48)))
	_fit.pressed.connect(func() -> void: shell.run("fit"))
	add_child(_fit)

	_parts = _sheet("Parts", false)
	# The bin heads itself "Parts", with its own buttons beside.
	_parts.set_shown_title("")
	_parts.body.add_child(bin)
	bin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A part picked is in hand: the sheet goes, and the model is all there.
	if not bin.part_chosen.is_connected(_part_picked):
		bin.part_chosen.connect(_part_picked)
	_colours = _sheet("Colour", true)
	_more = _sheet("More", true)
	_context = _sheet("This part", true)
	_lay_pill()


## Anchors left, top, right, bottom and the offsets from them, as
## Rect2(left, top, right, bottom): set together, so none is moved to keep
## the control where it was before it had a size.
static func _pin(control: Control, left: float, top: float, right: float, bottom: float,
		offsets: Rect2) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = offsets.position.x
	control.offset_top = offsets.position.y
	control.offset_right = offsets.size.x
	control.offset_bottom = offsets.size.y


func _part_picked(_part_id: String) -> void:
	# A tablet's stays, beside the model, for the next.
	if wide:
		return
	if _parts != null and _parts.is_open() and not bin.is_dragging_part():
		_parts.close()


## A bar's backing, the desktop's own colour.
func _bar_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var face := StyleBoxFlat.new()
	face.bg_color = BACK
	face.border_color = Color(1, 1, 1, 0.08)
	face.border_width_bottom = 1
	face.border_width_top = 1
	face.content_margin_left = p(8)
	face.content_margin_right = p(8)
	face.content_margin_top = p(4)
	face.content_margin_bottom = p(4)
	panel.add_theme_stylebox_override("panel", face)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


func _faces(button: Button, corner: float) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var face := StyleBoxFlat.new()
		face.bg_color = {"normal": Color(1, 1, 1, 0.0), "hover": Color(1, 1, 1, 0.0),
			"pressed": LIT, "hover_pressed": LIT, "disabled": Color(1, 1, 1, 0.0),
			"focus": Color(1, 1, 1, 0.0)}[state]
		face.set_corner_radius_all(int(corner))
		face.content_margin_left = p(2)
		face.content_margin_right = p(2)
		face.content_margin_top = p(2)
		face.content_margin_bottom = p(2)
		button.add_theme_stylebox_override(state, face)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.9))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))


func _icon_button(icon: String, across: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(across, across)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faces(button, p(10))
	button.icon = Icons.texture_for(Toolbar.TOOLS + icon + ".svg", p(26), Icons.density(self))
	if button.icon != null:
		button.add_theme_constant_override("icon_max_width",
			roundi(button.icon.get_width() / Icons.density(self)))
	return button


## One of the row's buttons: a picture over a word.
func _tool(what: String, word: String, icon: String) -> Button:
	var button := Button.new()
	button.name = "phone_" + what
	button.text = word
	# Said by its word, shown or not (_share_row).
	button.accessibility_name = word
	button.set_meta("word", word)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A fingertip wide, or its share of the row (_share_row).
	button.custom_minimum_size = Vector2(_row_share(), p(ROW - 10))
	button.add_theme_font_size_override("font_size", ceili(p(12)))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.clip_text = true
	_faces(button, p(10))
	if not icon.is_empty():
		button.icon = Icons.texture_for(Toolbar.TOOLS + icon + ".svg", p(24), Icons.density(self))
		if button.icon != null:
			button.add_theme_constant_override("icon_max_width",
				roundi(button.icon.get_width() / Icons.density(self)))
	else:
		# Colour and More draw their own picture over the word.
		var drawn := RowPicture.new()
		drawn.kind = what
		drawn.phone = self
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PhoneShell._pin(drawn, 0.0, 0.0, 1.0, 1.0, Rect2())
		button.add_child(drawn)
		# Room above the word for the picture, in the window's units.
		var blank := Image.create(1, maxi(1, roundi(p(24))), false, Image.FORMAT_RGBA8)
		button.icon = ImageTexture.create_from_image(blank)
		if what == "colour":
			_colour_button = button
	button.pressed.connect(_chose.bind(what))
	_tool_buttons[what] = button
	return button


## A fingertip each, or an equal share of the window's width where seven
## fingertips are wider than the phone: a big Settings, Interface size ran
## Delete and More off its right edge (app_a11y_flow).
func _row_share() -> float:
	# The row inside its bar's margins (_bar_panel), in whole units: a share
	# of the window's whole width put More 14 px past its edge.
	var inside: float = get_viewport().get_visible_rect().size.x - p(8) * 2.0
	return minf(p(Phone.TARGET), floorf(inside / TOOLS.size()))


## Each its share, and its word under its picture where the word fits the
## share; where one does not, the row is pictures alone, each still said by
## its word (accessibility_name) and named in its tooltip. "Colo" and
## "Selec", cut short at 150%, read as typos.
func _share_row() -> void:
	var share: float = _row_share()
	var fits: bool = true
	for tool: Array in TOOLS:
		var button: Button = _tool_buttons.get(str(tool[0]))
		if button == null:
			continue
		button.custom_minimum_size.x = share
		var font: Font = button.get_theme_font("font")
		var wide: float = font.get_string_size(str(tool[1]), HORIZONTAL_ALIGNMENT_LEFT, -1,
			button.get_theme_font_size("font_size")).x + p(2) * 2.0
		fits = fits and wide <= share
	for tool: Array in TOOLS:
		var button: Button = _tool_buttons.get(str(tool[0]))
		if button != null:
			button.text = str(tool[1]) if fits else ""
			button.tooltip_text = "" if fits else str(tool[1])


## What a button of the row does: the desktop's own command or verb.
func _chose(what: String) -> void:
	var builder: Builder = app.get("_builder")
	var verbs: EditVerbs = app.get("_verbs")
	match what:
		"parts":
			_toggle(_parts, "half")
		"colour":
			# All of them at once, without scrolling: a colour is a quick
			# choice, and the sheet goes with it.
			_fill_colours()
			_toggle(_colours, "full")
		"more":
			_fill_more()
			_toggle(_more, "full")
		"turn":
			verbs.press("rotate")
			app.call("_refresh_preview")
		"tip":
			if not builder.selection.is_empty() and not builder.is_carrying():
				verbs.tip_selection(1)
			else:
				verbs.press("tip")
				app.call("_refresh_preview")
		"select":
			# What a right click does: lets go of what is in hand.
			app.call("_right_click")
		"delete":
			if not builder.selection.is_empty():
				shell.run("delete")
			else:
				shell.run("mode_delete" if verbs.mode != "delete" else "mode_select")


func _toggle(sheet: Sheet, how: String) -> void:
	if sheet.is_open():
		sheet.close()
		return
	# The drawer down the left, where a tablet's parts go: folded for them.
	var dock: SideDock = app.get("_bin_dock")
	if wide and sheet == _parts and dock != null and dock.is_open():
		_parts_for_dock = false
		dock.set_open(false)
	_make_room(sheet)
	sheet.open(how)


## Whether the model tree's drawer put the parts panel away, for it to
## come back as the drawer folds.
var _parts_for_dock: bool = false


## The desktop's drawer down the left, with the model tree and the
## properties in it (Shell._toggle_section): on a tablet it opened over the
## parts panel, both on one side of the model. So it takes the panel's
## place while it is open, and gives it back as it folds.
func dock_toggled(open: bool) -> void:
	if not wide or _parts == null:
		return
	if not open:
		if _parts_for_dock:
			_parts_for_dock = false
			_make_room(_parts)
			_parts.open("side")
		return
	if _parts.is_open():
		_parts_for_dock = true
		_parts.close(false)
	# And a panel on the right, where the drawer and it would leave the
	# model too little between them, as two panels do (_make_room).
	var dock: SideDock = app.get("_bin_dock")
	for sheet: Sheet in _sheets:
		if sheet.is_open() and sheet.edge == "right" and dock != null \
				and get_viewport().get_visible_rect().size.x - sheet.size.x - dock.open_width() < p(MODEL_LEAST):
			sheet.close(false)


## The other sheets put away for one about to open: every one on a phone;
## on a tablet the one on its side, and the far side's too where the model
## would be left too little between them, kept to come back as this goes.
func _make_room(sheet: Sheet) -> void:
	for other: Sheet in _sheets:
		if other == sheet or not other.is_open():
			continue
		if not wide or other.edge == sheet.edge:
			if wide and sheet.set_aside == null:
				sheet.set_aside = other.set_aside
			other.close(false)
		elif get_viewport().get_visible_rect().size.x - other.size.x - p(SIDE) < p(MODEL_LEAST):
			other.close(false)
			sheet.set_aside = other


## A sheet from the foot of the screen, over the row.
func _sheet(title: String, scrolls: bool) -> Sheet:
	var sheet := Sheet.new()
	sheet.phone = self
	sheet.title = title
	sheet.scrolls = scrolls
	if wide:
		sheet.edge = "left" if title == "Parts" else "right"
	add_child(sheet)
	_sheets.append(sheet)
	return sheet


func _process(_delta: float) -> void:
	# Turned round, the browser can give its new width (Room) a moment
	# after the canvas has its new size, and a layout made between them is
	# in the wrong points: a tablet's came out three quarters size. Looked
	# at again twice a second, which does nothing while nothing changed.
	if Time.get_ticks_msec() >= _look_again_at:
		_look_again_at = Time.get_ticks_msec() + 500
		app.call("_match_screen_density")
		_rebuild()
	_lay_pill()
	_show_tools()
	# A tooltip a finger raised: the desktop's words for a mouse, over what
	# the finger is on (walk180's "Right-click to keep it in Favourites").
	for sub: Window in get_window().get_embedded_subwindows():
		if Tooltips.is_tooltip(sub) and sub.visible:
			sub.hide()
			sub.queue_free()


## What is lit and what can be pressed, from the verbs' state.
func _show_tools() -> void:
	if shell == null:
		return
	var builder: Builder = app.get("_builder")
	var verbs: EditVerbs = app.get("_verbs")
	if builder == null or verbs == null or _tool_buttons.is_empty():
		return
	var holding: bool = verbs.shows_ghost() or builder.is_carrying()
	var selected: bool = not builder.selection.is_empty()
	_lit("select", verbs.mode == "select" and not holding)
	_lit("delete", verbs.mode == "delete")
	_lit("parts", _parts.is_open())
	_lit("colour", _colours.is_open())
	_lit("more", _more.is_open())
	(_tool_buttons["turn"] as Button).disabled = not (holding or selected)
	(_tool_buttons["tip"] as Button).disabled = not (holding or selected)
	(_tool_buttons["undo"] as Button).disabled = not shell.can("undo")
	(_tool_buttons["redo"] as Button).disabled = not shell.can("redo")


func _lit(what: String, on: bool) -> void:
	var button: Button = _tool_buttons.get(what)
	if button == null:
		return
	if not button.toggle_mode:
		button.toggle_mode = true
	if button.button_pressed != on:
		button.set_pressed_no_signal(on)


## The line over the model: what was just said, for a few seconds, else
## what a finger does now.
func say(words: String) -> void:
	if words.strip_edges().is_empty():
		return
	var said: String = Phone.touch_words(words)
	# How many are selected and nothing more: the hint says it, and what a
	# finger does with them.
	if said.ends_with(" selected") and said.trim_suffix(" selected").is_valid_int():
		return
	_said = said
	_said_until = Time.get_ticks_msec() + 4000


func hint() -> String:
	if Time.get_ticks_msec() < _said_until:
		return _said
	var builder: Builder = app.get("_builder")
	var verbs: EditVerbs = app.get("_verbs")
	if builder == null or verbs == null:
		return ""
	var library: PartLibrary = app.get("_library")
	if verbs.shows_ghost():
		var info: PartLibrary.PartInfo = library.parts.get(builder.held_part)
		var name: String = Inventory._tidy(info.name) if info != null else builder.held_part
		return "Tap to put %s down · drag turns the view · two fingers turn and zoom" % name
	if builder.is_carrying():
		return "Tap where it goes · Select puts it back"
	match verbs.mode:
		"delete":
			return "Tap a part to take it off · Select when done"
		"paint":
			return "Tap a part to paint it"
	if not builder.selection.is_empty():
		var count: int = builder.selection.size()
		return "%d selected · drag it to move · Colour paints it · hold for more" % count \
			if count > 1 else "Selected · drag it to move · Colour paints it · hold it for more"
	return "Parts to pick one · tap a part to select · drag turns the view · pinch zooms"


func _lay_pill() -> void:
	if _pill == null:
		return
	var words: String = hint()
	if _pill_words.text != words:
		_pill_words.text = words
	var room: Vector2 = get_viewport().get_visible_rect().size
	# Over the model's own room: on a tablet, between its panels.
	var free: Rect2 = model_room(Rect2(Vector2.ZERO, room))
	var widest: float = minf(free.size.x - p(24), p(380))
	var font: Font = _pill_words.get_theme_font("font")
	var line: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(p(13))).x
	var inner: float = minf(line + p(2), widest - p(24))
	# Each set only when it is another: laid out every frame, a value set
	# again, or set to nothing and back, is the whole window drawn again
	# (IdleDraw), and a tablet drawing in software drew it every frame.
	if _pill_words.custom_minimum_size.x != inner:
		_pill_words.custom_minimum_size.x = inner
	var size_now: Vector2 = _pill.get_combined_minimum_size()
	if _pill.size != size_now:
		_pill.size = size_now
	var at := Vector2(free.position.x + (free.size.x - size_now.x) * 0.5,
		room.y - p(ROW) - p(10) - size_now.y)
	var steps: Control = app.get("_steps")
	if steps != null and steps.is_visible_in_tree():
		at.y = minf(at.y, steps.get_global_rect().position.y - size_now.y - p(6))
	if _pill.position != at:
		_pill.position = at
	# A phone's sheets cover it; a tablet's panels stand beside it.
	var shown: bool = not words.is_empty() and (wide or not _any_open())
	if _pill.visible != shown:
		_pill.visible = shown
	if wide:
		_lay_beside(free)


## A tablet's Fit and the notices strip over the model kept in the model's
## room: Fit beside the panel on the right and under the strip, and what
## the strip says in the middle of the room rather than under a panel.
func _lay_beside(free: Rect2) -> void:
	var notices: Control = app.get("_notices")
	var top: float = p(TOP + 12)
	if notices != null:
		var face: StyleBoxFlat = notices.get_theme_stylebox("panel") as StyleBoxFlat
		var room: float = get_viewport().get_visible_rect().size.x
		if face != null and (face.content_margin_left != free.position.x
				or face.content_margin_right != room - free.end.x):
			face.content_margin_left = free.position.x
			face.content_margin_right = room - free.end.x
		if notices.is_visible_in_tree():
			top = maxf(top, notices.get_global_rect().end.y + p(8))
	var fit_at := Vector2(free.end.x - p(12 + 48), top)
	if _fit.position != fit_at:
		_fit.position = fit_at


func _any_open() -> bool:
	for sheet: Sheet in _sheets:
		if sheet.is_open():
			return true
	return false


## The part of [param rect] a tablet's open panels leave the model: all of
## it on a phone, whose sheets come and go over it.
func model_room(rect: Rect2) -> Rect2:
	if not wide:
		return rect
	for sheet: Sheet in _sheets:
		if not sheet.is_open():
			continue
		var side: Rect2 = sheet.get_global_rect()
		if sheet.edge == "left":
			var cut: float = clampf(side.end.x - rect.position.x, 0.0, rect.size.x)
			rect.position.x += cut
			rect.size.x -= cut
		elif sheet.edge == "right":
			rect.size.x = clampf(side.position.x - rect.position.x, 0.0, rect.size.x)
	return rect


## Whether a point is on the phone's own controls, for Main to leave alone.
func covers(point: Vector2) -> bool:
	for control: Control in [_top, _row, _fit]:
		if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return true
	for sheet: Sheet in _sheets:
		if sheet.is_open() and sheet.get_global_rect().has_point(point):
			return true
	return false


## How much of the window's top and foot the bars take, in units: the
## model's column keeps clear of them (Main).
func top_height() -> float:
	return p(TOP)


func foot_height() -> float:
	return p(ROW)


## A finger held on the model: the desktop's menu on a part, as a sheet.
func open_context(words: String) -> void:
	_fill_context(words)
	if not _context.is_open():
		_make_room(_context)
	_context.open("fit")


func _fill_context(words: String) -> void:
	_context.set_title(words)
	_context.clear()
	var builder: Builder = app.get("_builder")
	var library: PartLibrary = app.get("_library")
	for item: String in shell._shown(Shell.ON_A_PART):
		if item == "-":
			continue
		var command: Shell.Command = shell.command(item)
		if command == null:
			continue
		var label: String = command.words
		if item == "select_connected":
			label = "Select everything joined to it"
		elif item == "paint":
			label = "Paint with %s" % library.color(builder.held_color).name
		_context.add_row(label, item)


## Every menu's commands, under the menu's name, a row each.
func _fill_more() -> void:
	_more.clear()
	for menu: Array in Shell.MENUS:
		_more.add_heading(str(menu[0]))
		_more_rows(menu[1] as Array, "")


func _more_rows(items: Array, under: String) -> void:
	var seen: Dictionary = {}
	for item: String in shell._shown(items):
		if item == "-" or seen.has(item):
			continue
		seen[item] = true
		if item.begins_with(">"):
			var kind: String = item.substr(1)
			if Shell.SUBMENUS.has(kind):
				var words: String = {"import": "Import", "export": "Export",
					"select_by": "Select by", "cut_away": "Cut along", "steps": "Build steps",
					"booklet": "Booklet page", "floor": "Floor",
					"floor_colour": "Baseplate colour"}.get(kind, kind)
				_more_rows(Shell.SUBMENUS[kind] as Array, words)
			continue
		var command: Shell.Command = shell.command(item)
		if command == null:
			continue
		var label: String = command.words
		if not under.is_empty():
			label = "%s: %s" % [under, label]
		_more.add_row(label, item)


## The colours, big: the current ones by group, or every one.
func _fill_colours() -> void:
	_colours.clear()
	var library: PartLibrary = app.get("_library")
	var app_paints: bool = bool(app.call("_swatch_paints"))
	_colours.add_note("Paints the selection" if app_paints else "For the part you put down next")
	var chosen: int = bin.selected_color()
	for group: Array in PartsBin.GROUPS:
		var colors: Array[PartLibrary.BrickColor] = []
		for code: int in library.colors:
			var color: PartLibrary.BrickColor = library.colors[code]
			if code in PartsBin.NOT_A_COLOUR or not (group[1] as Array).has(color.drawn_as):
				continue
			var wanted: Variant = group[2]
			if wanted != null and bool(wanted) != color.is_transparent():
				continue
			if not _all_colours and not library.is_current(code):
				continue
			colors.append(color)
		if colors.is_empty():
			continue
		colors.sort_custom(PartsBin._in_palette_order)
		_colours.add_heading(str(group[0]))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", ceili(p(6)))
		flow.add_theme_constant_override("v_separation", ceili(p(6)))
		for color: PartLibrary.BrickColor in colors:
			var swatch := PartsBin.Swatch.new(color)
			swatch.custom_minimum_size = Vector2(p(Phone.TARGET + 2.0), p(Phone.TARGET + 2.0))
			swatch.set_pressed_no_signal(color.code == chosen)
			swatch.name = "swatch_%d" % color.code
			var code: int = color.code
			swatch.pressed.connect(func() -> void:
				bin.choose_colour(code)
				_colours.close())
			flow.add_child(swatch)
		_colours.add_control(flow)
	var everything := Button.new()
	everything.text = "Only the current colours" if _all_colours else "Every colour"
	everything.custom_minimum_size = Vector2(0, p(Phone.TARGET + 4.0))
	everything.add_theme_font_size_override("font_size", ceili(p(15)))
	everything.focus_mode = Control.FOCUS_NONE
	everything.pressed.connect(func() -> void:
		_all_colours = not _all_colours
		_fill_colours())
	_colours.add_control(everything)


## Where a browser check finds the phone's controls, by name.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {}
	for what: String in _tool_buttons:
		out["phone_" + what] = _tool_buttons[what]
	out["phone_fit"] = _fit
	out["phone_name"] = _name
	for sheet: Sheet in _sheets:
		if not sheet.is_open():
			continue
		var key: String = "phone_sheet_" + sheet.title.to_lower().replace(" ", "_")
		out[key] = sheet.handle
		out[key + "_done"] = sheet.done
		out[key.replace("phone_sheet_", "phone_panel_")] = sheet
		for row: Control in sheet.rows():
			out["phone_row_" + str(row.get_meta("command", row.name))] = row
		for swatch: Control in sheet.swatches():
			out["phone_swatch_%d" % int(swatch.get_meta("code"))] = swatch
	return out


## What the page is told about the phone: which sheet is open and how
## tall, for the browser check (tools/web/phone_flow.mjs).
func state() -> Dictionary:
	var open: String = ""
	var how: String = ""
	var titles: Array = []
	for sheet: Sheet in _sheets:
		if sheet.is_open():
			open = sheet.title
			how = sheet.state
			titles.append(sheet.title)
	# Two at once, on a tablet: the one opened last.
	if _newest != null and _newest.is_open():
		open = _newest.title
		how = _newest.state
	return {"sheet": open, "sheet_state": how, "sheets": titles, "wide": wide, "hint": hint()}


## A picture drawn over a row button's word, where there is no icon: the
## colour in hand, or More's three dots.
class RowPicture extends Control:
	var kind: String = ""
	var phone: PhoneShell
	## The colour drawn last. Drawn again only when the colour in hand is
	## another (a resize draws it anyway): it was drawn every frame, and a
	## frame drawn for nothing is the whole window drawn (IdleDraw). On a
	## tablet in a browser drawing in software that was 2 to 5 s a frame for
	## as long as the app was open, frozen from the moment it showed
	## (m174's tablet check, page.screenshot waiting 30 s for a frame).
	var _drawn: Variant = null

	func _process(_delta: float) -> void:
		if kind == "colour" and _colour() != _drawn:
			queue_redraw()

	func _colour() -> Color:
		var library: PartLibrary = phone.app.get("_library")
		var builder: Builder = phone.app.get("_builder")
		return Color(library.color(builder.held_color).shown, 1.0)

	func _draw() -> void:
		var middle := Vector2(size.x * 0.5, phone.p(4) + phone.p(12))
		if kind == "colour":
			var colour: Color = _colour()
			_drawn = colour
			draw_circle(middle, phone.p(11), Color(1, 1, 1, 0.85))
			draw_circle(middle, phone.p(9.5), colour)
		else:
			for n: int in 3:
				draw_circle(middle + Vector2(phone.p(7) * (n - 1), 0), phone.p(2.2),
					Color(1, 1, 1, 0.9))


## A sheet that comes up from the foot of the screen: half of it, all of
## it, or as tall as what it holds. Its handle is dragged up and down, and
## let go it settles at the nearest, or goes if it was pulled most of the
## way down. On a tablet, a panel down one side between the bars instead.
class Sheet extends PanelContainer:
	var phone: PhoneShell
	var title: String = ""
	var scrolls: bool = true
	## closed, half, full or fit; side for a tablet's panel.
	var state: String = "closed"
	## foot, or a tablet's left or right.
	var edge: String = "foot"
	## The panel this one put away for its room, back when this goes.
	var set_aside: Sheet
	var body: VBoxContainer
	var handle: Control
	var done: Button
	var _list: VBoxContainer
	var _title: Label
	var _drag_from: float = -1.0
	var _drag_height: float = 0.0
	var _height: float = 0.0

	func _ready() -> void:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_STOP
		var face := StyleBoxFlat.new()
		face.bg_color = Color(0.12, 0.13, 0.155, 0.985)
		face.border_color = Color(1, 1, 1, 0.12)
		if edge == "foot":
			face.border_width_top = 1
			face.corner_radius_top_left = ceili(phone.p(14))
			face.corner_radius_top_right = ceili(phone.p(14))
		else:
			# Its edge to the model, as a desktop column has.
			face.border_width_right = 1 if edge == "left" else 0
			face.border_width_left = 1 if edge == "right" else 0
		face.content_margin_left = phone.p(10)
		face.content_margin_right = phone.p(10)
		face.content_margin_bottom = phone.p(8)
		add_theme_stylebox_override("panel", face)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", ceili(phone.p(4)))
		add_child(column)
		# The handle: the grip and the title, dragged to size the sheet.
		var head := HBoxContainer.new()
		head.custom_minimum_size = Vector2(0, phone.p(Phone.TARGET + 4.0))
		head.mouse_filter = Control.MOUSE_FILTER_STOP
		head.gui_input.connect(_head_input)
		column.add_child(head)
		handle = head
		# The grip: a short rounded line at its top middle. A tablet's
		# panel is not dragged.
		if edge == "foot":
			head.draw.connect(func() -> void:
				var wide: float = phone.p(36)
				head.draw_rect(Rect2(Vector2((head.size.x - wide) * 0.5, phone.p(3)),
					Vector2(wide, phone.p(5))), Color(1, 1, 1, 0.35)))
		_title = Label.new()
		_title.text = title
		_title.add_theme_font_size_override("font_size", ceili(phone.p(17)))
		_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_title.clip_text = true
		_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(_title)
		done = Button.new()
		done.text = "Done"
		done.focus_mode = Control.FOCUS_NONE
		done.custom_minimum_size = Vector2(phone.p(72), phone.p(Phone.TARGET))
		done.add_theme_font_size_override("font_size", ceili(phone.p(16)))
		done.pressed.connect(close)
		head.add_child(done)
		body = VBoxContainer.new()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(body)
		if scrolls:
			var scroll := ScrollContainer.new()
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			body.add_child(scroll)
			_list = VBoxContainer.new()
			_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_list.add_theme_constant_override("separation", ceili(phone.p(2)))
			scroll.add_child(_list)
		get_viewport().size_changed.connect(_place, CONNECT_DEFERRED)
		# A panel is as tall as the room between the bars, which what it
		# holds is laid out to only once it is shown: hidden, the bin's
		# rows of parts wanted 1,800 units, and the panel kept that.
		if edge != "foot":
			minimum_size_changed.connect(_place, CONNECT_DEFERRED)

	func set_title(words: String) -> void:
		title = words
		_title.text = words

	## What the head says, where that is not its name.
	func set_shown_title(words: String) -> void:
		_title.text = words

	func is_open() -> bool:
		return state != "closed"

	func open(how: String = "half") -> void:
		state = how if edge == "foot" else "side"
		visible = true
		_height = _height_for(how)
		phone._newest = self
		_place()

	## Put away, and what it put away for its room given back unless
	## [param give_back] is false (another taking its place).
	func close(give_back: bool = true) -> void:
		state = "closed"
		visible = false
		var back: Sheet = set_aside
		set_aside = null
		if give_back and back != null and not back.is_open():
			back.open("side")

	func _room() -> Vector2:
		return get_viewport().get_visible_rect().size

	func _height_for(how: String) -> float:
		var room: Vector2 = _room()
		var full: float = room.y - phone.p(PhoneShell.TOP) - phone.p(8)
		match how:
			"full":
				return full
			"fit":
				var wants: float = phone.p(Phone.TARGET + 24.0)
				if _list != null:
					wants += _list.get_combined_minimum_size().y
				return clampf(wants, room.y * 0.3, full)
		return room.y * 0.5

	func _place() -> void:
		if state == "closed":
			return
		var room: Vector2 = _room()
		PhoneShell._pin(self, 0.0, 0.0, 0.0, 0.0, Rect2())
		if state == "side":
			var top: float = phone.p(PhoneShell.TOP)
			var tall: float = room.y - top - phone.p(PhoneShell.ROW)
			custom_minimum_size = Vector2(phone.p(PhoneShell.SIDE), tall)
			size = Vector2(get_combined_minimum_size().x, tall)
			position = Vector2(0.0 if edge == "left" else room.x - size.x, top)
			return
		var wide: float = minf(room.x, phone.p(560))
		position = Vector2((room.x - wide) * 0.5, room.y - _height)
		size = Vector2(wide, _height)
		custom_minimum_size = Vector2(wide, _height)

	func _head_input(event: InputEvent) -> void:
		if edge != "foot":
			return
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button != null and button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_drag_from = button.global_position.y
				_drag_height = _height
			elif _drag_from >= 0.0:
				_drag_from = -1.0
				_settle()
			return
		var moved: InputEventMouseMotion = event as InputEventMouseMotion
		if moved != null and _drag_from >= 0.0 and (moved.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			# The event's units are the window's; the sheet's are the same.
			var by: float = (moved.global_position.y - _drag_from)
			_height = clampf(_drag_height - by, phone.p(60), _height_for("full"))
			_place()

	## Let go: the nearest of half and the whole screen, or away.
	func _settle() -> void:
		var room: Vector2 = _room()
		var half: float = _height_for("half")
		var full: float = _height_for("full")
		if absf(_height - _drag_height) < phone.p(8):
			_height = _drag_height
			_place()
			return
		if _height < room.y * 0.28:
			close()
		elif _height < (half + full) * 0.5:
			state = "half"
			_height = half
			_place()
		else:
			state = "full"
			_height = full
			_place()

	func clear() -> void:
		if _list == null:
			return
		for child: Node in _list.get_children():
			_list.remove_child(child)
			child.queue_free()

	func add_control(control: Control) -> void:
		_list.add_child(control)

	func add_heading(words: String) -> void:
		var label := Label.new()
		label.text = words
		label.add_theme_font_size_override("font_size", ceili(phone.p(13)))
		label.add_theme_color_override("font_color", Color(0.62, 0.74, 1.0, 0.95))
		label.custom_minimum_size = Vector2(0, phone.p(30))
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(label)

	func add_note(words: String) -> void:
		var label := Label.new()
		label.text = words
		label.add_theme_font_size_override("font_size", ceili(phone.p(13)))
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(label)

	## A row that runs one of Shell's commands: greyed where it would do
	## nothing, lit where it is on.
	func add_row(words: String, command: String) -> void:
		var row := Button.new()
		row.text = words
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		row.clip_text = true
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.custom_minimum_size = Vector2(0, phone.p(Phone.TARGET + 4.0))
		row.add_theme_font_size_override("font_size", ceili(phone.p(16)))
		row.set_meta("command", command)
		row.name = "row_" + command
		# A finger dragged over the rows scrolls the list (TouchSizing).
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var on: int = phone.shell.ticked(command)
		for state_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var face := StyleBoxFlat.new()
			face.bg_color = Color(1, 1, 1, 0.045) if on != 1 else Color(0.36, 0.6, 1.0, 0.28)
			if state_name == "pressed":
				face.bg_color = Color(1, 1, 1, 0.14)
			face.set_corner_radius_all(ceili(phone.p(8)))
			face.content_margin_left = phone.p(14)
			face.content_margin_right = phone.p(14)
			row.add_theme_stylebox_override(state_name, face)
		row.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.32))
		row.disabled = not phone.shell.can(command)
		row.pressed.connect(func() -> void:
			close()
			phone.shell.run(command))
		_list.add_child(row)

	func swatches() -> Array[Control]:
		var out: Array[Control] = []
		if _list != null:
			for child: Node in _list.get_children():
				if child is HFlowContainer:
					for swatch: Node in child.get_children():
						if swatch.has_meta("code"):
							out.append(swatch)
		return out

	func rows() -> Array[Control]:
		var out: Array[Control] = []
		if _list != null:
			for child: Node in _list.get_children():
				if child is Button and child.has_meta("command"):
					out.append(child)
		return out

