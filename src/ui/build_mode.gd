## Build it: a shared model as a step player, for someone building it with
## real bricks at a table, the phone or tablet propped beside the pile.
##
## The whole window is the step: its number and how far along along the
## top, the model in the middle — what is already built drawn faded and
## the step's new parts in full colour, outlined — and along the bottom
## the parts to pick up, each a picture with "2x" under it as a booklet's
## callout has, over a big Back and a bigger Next. A swipe across either
## bar turns the page too; on the model a finger turns the view and two
## pinch it, as everywhere else (CadCamera).
##
## Sized in points, not in the interface's units: a phone draws about 720
## units across 390 points, so a 46-unit button there is 25 points, and a
## finger needs about twice that. Words at arm's length are 20 points and
## up.
##
## This only shows a page and says what was pressed; main.gd turns the
## page (BuildSteps says what is on it) and keeps the place.
class_name BuildMode
extends Control

signal next_wanted
signal back_wanted
signal close_wanted
## A page tapped on the progress bar: the steps lie along it.
signal page_wanted(page: int)

## Points.
const BUTTON := 60.0
const PICTURE := 64.0
const SWIPE := 56.0
## Points a finger may move and still tap, and how far from the progress
## bar's middle a tap is on it.
const TAP := 12.0
const BAR_REACH := 16.0
## The parts and the buttons are no wider than this.
const WIDEST := 600.0

var thumbnails: PartThumbnails

var page: int = 0
var last: int = 0
var _caption_text: String = ""
var _note_text: String = ""
var _lots: Array[Dictionary] = []

var _top: PanelContainer
var _close: Button
var _caption: Label
var _note: Label
var _progress: ProgressBar
var _bottom: PanelContainer
var _callout: PanelContainer
var _strip: HFlowContainer
var _told: Label
var _back: Button
var _next: Button
var _tiles: Array[ThumbTile] = []
## Where a finger or the mouse went down on a bar, for a swipe; -1 none.
var _swipe_from: Vector2 = Vector2(-1, -1)
var _swipe_index: int = -1
var _pt: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_top()
	_build_bottom()
	get_viewport().size_changed.connect(_fit)
	_fit()


func _build_top() -> void:
	_top = PanelContainer.new()
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.gui_input.connect(_swiped.bind(_top))
	add_child(_top)
	var column := VBoxContainer.new()
	_top.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	_close = _button("Close", "Back to the whole model (Esc)")
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(func() -> void: close_wanted.emit())
	row.add_child(_close)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_caption)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.modulate = Color(1.0, 0.86, 0.45)
	words.add_child(_note)
	# As wide as Close, so the words sit in the middle of the window.
	var balance := Control.new()
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance.name = "Balance"
	row.add_child(balance)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_progress)


func _build_bottom() -> void:
	_bottom = PanelContainer.new()
	_bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom.gui_input.connect(_swiped.bind(_bottom))
	add_child(_bottom)
	var column := VBoxContainer.new()
	_bottom.add_child(column)
	# The parts, on a pale card, as a booklet's callout is: dark parts and
	# light ones both read on it, where the window's dark grey lost black.
	# The width of the bar: shrunk to its contents, a flow is as narrow as
	# its widest part, and the parts went down a phone one under another.
	_callout = PanelContainer.new()
	_callout.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_callout)
	_strip = HFlowContainer.new()
	_strip.alignment = FlowContainer.ALIGNMENT_CENTER
	_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	_callout.add_child(_strip)
	_told = Label.new()
	_told.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_told.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_told.modulate = Color(1, 1, 1, 0.78)
	column.add_child(_told)
	var row := HBoxContainer.new()
	column.add_child(row)
	_back = _button("Back", "The step before (left arrow)")
	_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back.size_flags_stretch_ratio = 2.0
	_back.pressed.connect(func() -> void: back_wanted.emit())
	row.add_child(_back)
	_next = _button("Next", "The next step (right arrow, space)")
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.size_flags_stretch_ratio = 3.0
	_next.pressed.connect(func() -> void: next_wanted.emit())
	row.add_child(_next)


func _button(words: String, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


## Interface units to a point: the interface is scaled to the window, and
## a finger and an eye are not.
func points() -> float:
	var across: float = Room.across()
	var room: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() \
		else Vector2(1600, 900)
	return room.x / across if across > 0.0 else 1.0


func _fit() -> void:
	_pt = points()
	var pt: float = _pt
	var dark := StyleBoxFlat.new()
	dark.bg_color = Color(0.09, 0.10, 0.12, 0.94)
	dark.set_content_margin_all(10.0 * pt)
	dark.content_margin_top = 8.0 * pt
	dark.content_margin_bottom = 8.0 * pt
	_top.add_theme_stylebox_override("panel", dark)
	var under: StyleBoxFlat = dark.duplicate()
	under.content_margin_bottom = 12.0 * pt
	_bottom.add_theme_stylebox_override("panel", under)
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.82, 0.88, 0.95)
	card.border_color = Color(0.55, 0.66, 0.80)
	card.set_border_width_all(maxi(1, roundi(1.5 * pt)))
	card.set_corner_radius_all(roundi(8.0 * pt))
	card.set_content_margin_all(8.0 * pt)
	_callout.add_theme_stylebox_override("panel", card)
	_strip.add_theme_constant_override("h_separation", roundi(10.0 * pt))
	_strip.add_theme_constant_override("v_separation", roundi(6.0 * pt))
	(_top.get_child(0) as VBoxContainer).add_theme_constant_override("separation", roundi(6.0 * pt))
	var column: VBoxContainer = _bottom.get_child(0)
	column.add_theme_constant_override("separation", roundi(8.0 * pt))
	# A phone's width, and no wider: across a desktop window Next was a
	# bar 800 points long, and the parts a row lost in the middle of it.
	var room: float = get_viewport().get_visible_rect().size.x if is_inside_tree() else 1600.0
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.custom_minimum_size = Vector2(minf(room - 20.0 * pt, WIDEST * pt), 0.0)
	for row: Node in [_close.get_parent(), _next.get_parent()]:
		(row as HBoxContainer).add_theme_constant_override("separation", roundi(10.0 * pt))
	_caption.add_theme_font_size_override("font_size", roundi(24.0 * pt))
	_note.add_theme_font_size_override("font_size", roundi(16.0 * pt))
	_told.add_theme_font_size_override("font_size", roundi(14.0 * pt))
	for button: Button in [_close, _back, _next]:
		_face(button, button == _next)
		button.add_theme_font_size_override("font_size", roundi((22.0 if button != _close else 18.0) * pt))
		button.custom_minimum_size = Vector2((88.0 if button == _close else 0.0) * pt, BUTTON * pt)
	var balance: Control = _close.get_parent().get_node("Balance")
	balance.custom_minimum_size = Vector2(88.0 * pt, 0.0)
	_progress.custom_minimum_size = Vector2(0.0, 6.0 * pt)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)
	track.set_corner_radius_all(roundi(3.0 * pt))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.80, 0.18)
	fill.set_corner_radius_all(roundi(3.0 * pt))
	_progress.add_theme_stylebox_override("background", track)
	_progress.add_theme_stylebox_override("fill", fill)
	_lay_strip()


func _face(button: Button, bright: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var face := StyleBoxFlat.new()
		if bright:
			face.bg_color = {"normal": Color(0.78, 0.06, 0.18), "hover": Color(0.88, 0.14, 0.26),
				"pressed": Color(0.66, 0.04, 0.14), "disabled": Color(0.35, 0.12, 0.16)}[state]
		else:
			face.bg_color = Color(1, 1, 1, {"normal": 0.12, "hover": 0.2, "pressed": 0.28,
				"disabled": 0.04}[state])
			face.border_color = Color(1, 1, 1, 0.2)
			face.set_border_width_all(maxi(1, roundi(_pt)))
		face.set_corner_radius_all(roundi(10.0 * _pt))
		face.content_margin_left = 14.0 * _pt
		face.content_margin_right = 14.0 * _pt
		button.add_theme_stylebox_override(state, face)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))


## Put a page up: its caption ("Step 3 of 24"), what else to say, and its
## parts. [param of] is the last page.
func show_page(at: int, of: int, caption: String, note: String, lots: Array[Dictionary]) -> void:
	page = at
	last = of
	_caption_text = caption if at > 0 else "Ready to build"
	_note_text = note
	_lots = lots
	_caption.text = _caption_text
	_note.text = note if at > 0 else caption + ". Get the parts out, then press Start."
	_note.visible = not _note.text.is_empty()
	_progress.max_value = maxf(of, 1.0)
	_progress.value = at
	_back.disabled = at <= 0
	_next.text = "Start" if at == 0 else ("Finish" if at >= of else "Next")
	_told.text = _telling(at, lots)
	_told.visible = not _told.text.is_empty()
	_lay_strip()


func _telling(at: int, lots: Array[Dictionary]) -> String:
	if at == 0:
		return ""
	if lots.is_empty():
		return "No new parts"
	var pieces: int = 0
	for lot: Dictionary in lots:
		pieces += int(lot["count"])
	if lots.size() == 1:
		var only: Dictionary = lots[0]
		return "%d × %s, %s" % [int(only["count"]), only["name"], only["colour_name"]]
	return "%d parts" % pieces


func _lay_strip() -> void:
	if _strip == null:
		return
	for child: Node in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()
	_tiles.clear()
	_callout.visible = not _lots.is_empty()
	for lot: Dictionary in _lots:
		var cell := VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.tooltip_text = "%d × %s, %s" % [int(lot["count"]), lot["name"], lot["colour_name"]]
		cell.add_theme_constant_override("separation", 0)
		var tile := ThumbTile.new(str(lot["part"]), int(lot["colour"]))
		tile.custom_minimum_size = Vector2(PICTURE, PICTURE) * _pt
		var ready: Texture2D = thumbnails.peek(tile.part_id, tile.color_code) \
			if thumbnails != null else null
		if ready != null:
			tile.show_picture(ready, false)
		cell.add_child(tile)
		var count := Label.new()
		count.text = "%dx" % int(lot["count"])
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", roundi(20.0 * _pt))
		count.add_theme_color_override("font_color", Color(0.06, 0.08, 0.12))
		cell.add_child(count)
		_strip.add_child(cell)
		_tiles.append(tile)
	if thumbnails != null:
		thumbnails.watch(self, _tiles if visible else ([] as Array[ThumbTile]))


func open() -> void:
	visible = true
	_fit()


func close() -> void:
	visible = false
	if thumbnails != null:
		thumbnails.watch(self, [] as Array[ThumbTile])


func is_open() -> bool:
	return visible


## The part of the window the model is seen in while a page is up: between
## the two bars, for the camera to frame the step in (CadCamera.seen).
func free_rect() -> Rect2:
	var room: Rect2 = get_global_rect()
	var top: float = _top.get_global_rect().end.y
	var bottom: float = _bottom.get_global_rect().position.y
	return Rect2(room.position.x, top, room.size.x, maxf(bottom - top, 1.0))


func covers(point: Vector2) -> bool:
	return visible and (_top.get_global_rect().has_point(point)
		or _bottom.get_global_rect().has_point(point))


## A finger, or the mouse, drawn across a bar: to the left is Next, to the
## right Back. Across, and far enough, so a tap that wobbles is still a tap.
## A finger's own events only: the click emulated from it is the same
## finger again.
func _swiped(event: InputEvent, panel: Control) -> void:
	var down: bool = false
	var up: bool = false
	var at: Vector2
	var index: int = 0
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		down = touch.pressed
		up = not touch.pressed
		at = touch.position
		index = touch.index
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.device == InputEvent.DEVICE_ID_EMULATION \
				or button.button_index != MOUSE_BUTTON_LEFT:
			return
		down = button.pressed
		up = not button.pressed
		at = button.position
		index = -2
	elif event is InputEventScreenDrag:
		# A bar's own: a drag begun on it never turns the model behind.
		accept_event()
		return
	else:
		return
	# The bar's own coordinates; a page that moves the bar between the two
	# would be no page turned anyway.
	if down:
		_swipe_from = at
		_swipe_index = index
		return
	if not up or index != _swipe_index or _swipe_from.x < 0.0:
		return
	var moved: Vector2 = at - _swipe_from
	_swipe_from = Vector2(-1, -1)
	_swipe_index = -1
	if moved.length() < TAP * _pt and panel == _top:
		_tapped_bar(panel.get_global_rect().position + at)
		return
	if absf(moved.x) < SWIPE * _pt or absf(moved.x) < absf(moved.y) * 1.5:
		return
	accept_event()
	if moved.x < 0.0:
		next_wanted.emit()
	else:
		back_wanted.emit()


## A tap on the progress bar, or a fingertip from it: the step under it, the
## bar being the steps from the first to the last, each its share. The bar
## is drawn thin; the finger is not.
func _tapped_bar(point: Vector2) -> void:
	var bar: Rect2 = _progress.get_global_rect()
	if last <= 0 or bar.size.x <= 0.0 or absf(point.y - bar.get_center().y) > BAR_REACH * _pt:
		return
	accept_event()
	page_wanted.emit(clampi(ceili((point.x - bar.position.x) / bar.size.x * last), 1, last))


func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	return {"build_next": _next, "build_back": _back, "build_close": _close,
		"build_parts": _callout, "build_top": _top, "build_bottom": _bottom,
		"build_progress": _progress}


## What the page says, for a check to read.
func page_state() -> Dictionary:
	var sizes: Dictionary = {}
	for name: String in ["build_next", "build_back", "build_close"]:
		var button: Button = controls_by_name().get(name)
		if button != null:
			sizes[name] = [roundi(button.size.x / _pt), roundi(button.size.y / _pt)]
	return {"open": visible, "page": page, "last": last, "caption": _caption_text,
		"note": _note.text if _note.visible else "", "told": _told.text if _told.visible else "",
		"lots": _lots.size(), "pictures": _tiles.filter(func(tile: ThumbTile) -> bool:
			return tile.state == ThumbTile.State.READY).size(),
		"next": _next.text, "back_enabled": not _back.disabled, "points": sizes,
		"caption_points": roundi(float(_caption.get_theme_font_size("font_size")) / _pt)}
