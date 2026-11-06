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
## A builder who comes back to a link whose model changed at or before the
## step they had reached is told so along the top ("This model changed
## from step 3"), with that step a press away; one who had not got that far
## is not told anything (BuildSteps.changed_since).
##
## A part at a time (APP_UX4 partbypart, as BUF3D builds on a phone): a
## choice under the parts, One part or Whole step, kept on this device. One
## part puts a step down a part at a time: the next part alone in its
## colours and outlined, everything already on faded, the part's picture on
## the card with "3 of 8 in this step" under it and its name beside; Next
## (a tap, a swipe, the keys) puts the next part down and from the step's
## last goes on to the next step, and Back takes one part off. Whole step
## shows the step at once, as the booklet does, and is where a person starts:
## a booklet's steps are how LEGO® sets are built, and a child, or anyone at
## a busy step, chooses One part on the page they are on. Every target is
## a fingertip, 44 points or more.
##
## The page's comments (2026-10-18): a count at the right of the top bar,
## across from Close, for the step on the page ("2 comments", or Comment to
## add the first); tapped, the step's comments come up from the bottom of
## the model's part of the window, with a box to add one for somebody who
## may (StepComments). The cover's are the whole model's.
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
## One part or Whole step chosen: main.gd shows the page again that way.
signal by_part_changed(on: bool)

## Points.
const BUTTON := 60.0
const PICTURE := 64.0
## The one part's picture, a part at a time: the card is its own.
const PART_PICTURE := 96.0
const SWIPE := 56.0
## Points a finger may move and still tap, and how far from the progress
## bar's middle a tap is on it.
const TAP := 12.0
const BAR_REACH := 16.0
## The parts and the buttons are no wider than this.
const WIDEST := 600.0
## The least a target is, either way, in points: a fingertip (Apple's 44).
const TARGET := 44.0
## Where this device keeps One part or Whole step, in the browser.
const BY_PART_KEPT := "brickworks.build.by_part"

var thumbnails: PartThumbnails

var page: int = 0
var last: int = 0
## Building a part at a time, and on this page the part put down (from 1)
## of how many; both 0 on a page shown whole.
var by_part: bool = false
var part: int = 0
var parts: int = 0
var _caption_text: String = ""
var _note_text: String = ""
var _lots: Array[Dictionary] = []

var _top: PanelContainer
var _close: Button
var _caption: Label
var _note: Label
## The model changed from this step since this builder's place was kept,
## while they are told so; 0 when it did not.
var changed_from: int = 0
var _told_on: int = -1
var _changed: VBoxContainer
var _changed_words: Label
var _changed_go: Button
var _progress: ProgressBar
var _bottom: PanelContainer
var _callout: PanelContainer
var _strip: HFlowContainer
var _told: Label
## One part or Whole step, the two halves of one choice.
var _one_part: Button
var _whole_step: Button
var _back: Button
var _next: Button
var _tiles: Array[ThumbTile] = []
## Where a finger or the mouse went down on a bar, for a swipe; -1 none.
var _swipe_from: Vector2 = Vector2(-1, -1)
var _swipe_index: int = -1
var _pt: float = 0.0
## The comments on the page's step: the count in the top bar, the panel
## over the model.
var comments: StepComments


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	by_part = recall_by_part()
	comments = StepComments.new()
	comments.prefix = "build"
	comments.area = free_rect
	add_child(comments)
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
	_changed = VBoxContainer.new()
	_changed.visible = false
	words.add_child(_changed)
	_changed_words = Label.new()
	_changed_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_changed_words.modulate = Color(1.0, 0.86, 0.45)
	_changed_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_changed.add_child(_changed_words)
	_changed_go = _button("Go to step 1", "Build from the step the model changed at")
	_changed_go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_changed_go.pressed.connect(func() -> void:
		var wanted: int = changed_from
		_hide_changed()
		page_wanted.emit(wanted))
	_changed.add_child(_changed_go)
	# As wide as Close, so the words sit in the middle of the window; the
	# page's comments are counted in it.
	var balance := CenterContainer.new()
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance.name = "Balance"
	row.add_child(balance)
	comments.remove_child(comments.pill)
	comments.pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance.add_child(comments.pill)
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
	# What is on the card said in words, and beside it how to build: a part
	# at a time or the step whole.
	var telling := HBoxContainer.new()
	telling.name = "Telling"
	# The words take the room beside the choice; with none, the choice sits
	# in the middle, under the card.
	telling.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(telling)
	_told = Label.new()
	_told.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_told.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_told.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_told.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_told.modulate = Color(1, 1, 1, 0.78)
	telling.add_child(_told)
	var way := HBoxContainer.new()
	way.name = "Way"
	way.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	way.add_theme_constant_override("separation", 0)
	telling.add_child(way)
	var choice := ButtonGroup.new()
	_one_part = _button("One part", "Build it a part at a time: the next part alone, in its colours")
	_whole_step = _button("Whole step", "Build it a step at a time, as the booklet shows it")
	for button: Button in [_one_part, _whole_step]:
		button.toggle_mode = true
		button.button_group = choice
		way.add_child(button)
	_one_part.button_pressed = by_part
	_whole_step.button_pressed = not by_part
	_one_part.pressed.connect(choose_by_part.bind(true))
	_whole_step.pressed.connect(choose_by_part.bind(false))
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
	_changed_words.add_theme_font_size_override("font_size", roundi(16.0 * pt))
	_changed_go.add_theme_font_size_override("font_size", roundi(16.0 * pt))
	_changed_go.custom_minimum_size = Vector2(0.0, TARGET * pt)
	_changed.add_theme_constant_override("separation", roundi(10.0 * pt))
	_face(_changed_go, false)
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
	comments.fit(pt, 16.0)
	# Its words as they were, and a fingertip tall.
	comments.pill.custom_minimum_size.y = maxf(comments.pill.custom_minimum_size.y, TARGET * pt)
	(_told.get_parent() as HBoxContainer).add_theme_constant_override("separation", roundi(10.0 * pt))
	for button: Button in [_one_part, _whole_step]:
		_choice_face(button, button == _one_part)
		button.add_theme_font_size_override("font_size", roundi(16.0 * pt))
		button.custom_minimum_size = Vector2(0.0, TARGET * pt)
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


## One half of the choice: lit, pale with dark words, as a phone's
## segmented control is; the other dark. Rounded on its outer side only, so
## the two read as one control.
func _choice_face(button: Button, first: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var face := StyleBoxFlat.new()
		var lit: bool = state.contains("pressed")
		face.bg_color = Color(0.95, 0.96, 0.98) if lit else Color(1, 1, 1,
			0.2 if state == "hover" else 0.1)
		face.border_color = Color(1, 1, 1, 0.3)
		face.set_border_width_all(maxi(1, roundi(_pt)))
		var corner: int = roundi(10.0 * _pt)
		face.corner_radius_top_left = corner if first else 0
		face.corner_radius_bottom_left = corner if first else 0
		face.corner_radius_top_right = 0 if first else corner
		face.corner_radius_bottom_right = 0 if first else corner
		face.content_margin_left = 12.0 * _pt
		face.content_margin_right = 12.0 * _pt
		button.add_theme_stylebox_override(state, face)
	for state: String in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color(0.06, 0.08, 0.12))
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))


## One part (true) or Whole step chosen, by a tap or a check: kept on this
## device, and the page shown again that way.
func choose_by_part(on: bool) -> void:
	_one_part.set_pressed_no_signal(on)
	_whole_step.set_pressed_no_signal(not on)
	if on == by_part:
		return
	by_part = on
	keep_by_part(on)
	by_part_changed.emit(on)


## Whether this device builds a part at a time: in the browser's
## localStorage, as the page reached is kept (BuildSteps.remember); off the
## web, for this run only, as the viewer writes nothing to disk.
static var _by_part_here: bool = false


static func recall_by_part() -> bool:
	if OS.has_feature("web"):
		var kept: Variant = JavaScriptBridge.eval(
			"(function(){try{return localStorage.getItem(%s)||''}catch(e){return ''}})()"
			% JSON.stringify(BY_PART_KEPT), true)
		return kept is String and kept == "1"
	return _by_part_here


static func keep_by_part(on: bool) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{localStorage.setItem(%s,%s)}catch(e){}})()"
			% [JSON.stringify(BY_PART_KEPT), JSON.stringify("1" if on else "0")], true)
	else:
		_by_part_here = on


## Put a page up: its caption ("Step 3 of 24"), what else to say, and its
## parts. [param of] is the last page. A part at a time, [param at_part] of
## [param of_parts] is the part put down, and [param lots] its one part (none
## for a finished sub-assembly put on whole).
func show_page(at: int, of: int, caption: String, note: String, lots: Array[Dictionary],
		at_part: int = 0, of_parts: int = 0) -> void:
	# Told on one page and moved on from it: the builder has chosen.
	if changed_from > 0 and at != _told_on:
		_hide_changed()
	page = at
	last = of
	_caption_text = caption if at > 0 else "Ready to build"
	_note_text = note
	_lots = lots
	part = at_part if at_part > 0 else 0
	parts = of_parts if at_part > 0 else 0
	_caption.text = _caption_text
	_note.text = note if at > 0 else caption + ". Get the parts out, then press Start."
	_note.visible = not _note.text.is_empty()
	_progress.max_value = maxf(of, 1.0)
	_progress.value = at
	_back.disabled = at <= 0
	_next.text = "Start" if at == 0 else ("Finish" if at >= of and part >= parts else "Next")
	_next.tooltip_text = "The next part (right arrow, space)" if by_part \
		else "The next step (right arrow, space)"
	_back.tooltip_text = "Take the last part off (left arrow)" if by_part \
		else "The step before (left arrow)"
	_told.text = _telling(at, lots)
	_told.visible = not _told.text.is_empty()
	comments.set_step(at)
	_lay_strip()
	_shown_at = Time.get_ticks_msec()
	_pictures_ms = -1
	set_process(true)


## When the page went up, and how long after it every part's picture along
## the bottom was drawn (-1 while one is still to come): a builder picks
## the parts from them.
var _shown_at: int = 0
var _pictures_ms: int = -1


func _process(_delta: float) -> void:
	if not visible:
		set_process(false)
		return
	if not pictures_done():
		return
	_pictures_ms = Time.get_ticks_msec() - _shown_at
	set_process(false)
	# Said to the page in the frame it happens, for a check to time it from
	# the tap (tools/web/share_steps_flow.mjs).
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.brickworksPicturesDrawn = [%d, performance.now()]" % page, true)


## Whether every part on the page has its picture, or none to be had.
func pictures_done() -> bool:
	for tile: ThumbTile in _tiles:
		if is_instance_valid(tile) and tile.state == ThumbTile.State.LOADING:
			return false
	return true


func _telling(at: int, lots: Array[Dictionary]) -> String:
	if at == 0:
		return ""
	if part > 0:
		# The one part's name and colour; a sub-assembly put on whole is
		# named by the note, "Put it on".
		return "" if lots.is_empty() else "%s, %s" % [lots[0]["name"], lots[0]["colour_name"]]
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
	_callout.visible = not _lots.is_empty() or part > 0
	if part > 0 and _lots.is_empty():
		_strip.add_child(_count_words())
	for lot: Dictionary in _lots:
		var cell := VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.tooltip_text = "%d × %s, %s" % [int(lot["count"]), lot["name"], lot["colour_name"]]
		cell.add_theme_constant_override("separation", 0)
		var tile := ThumbTile.new(str(lot["part"]), int(lot["colour"]))
		tile.custom_minimum_size = Vector2.ONE * (PART_PICTURE if part > 0 else PICTURE) * _pt
		var ready: Texture2D = thumbnails.peek(tile.part_id, tile.color_code) \
			if thumbnails != null else null
		if ready != null:
			tile.show_picture(ready, false)
		cell.add_child(tile)
		var count: Label = _count_words() if part > 0 else Label.new()
		if part == 0:
			count.text = "%dx" % int(lot["count"])
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count.add_theme_font_size_override("font_size", roundi(20.0 * _pt))
			count.add_theme_color_override("font_color", Color(0.06, 0.08, 0.12))
		cell.add_child(count)
		_strip.add_child(cell)
		_tiles.append(tile)
	if thumbnails != null:
		_watch_after_this_frame()


## "3 of 8 in this step", under the part's picture on the card.
func _count_words() -> Label:
	var count := Label.new()
	count.name = "PartCount"
	count.text = "%d of %d in this step" % [part, parts]
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", roundi(18.0 * _pt))
	count.add_theme_color_override("font_color", Color(0.06, 0.08, 0.12))
	return count


## The parts' pictures asked for once the page itself is drawn: the frame a
## page is turned in draws the model and the step, and the pictures (each a
## little scene of its own, drawn and read back) come in the frames after.
## Drawn in that same frame, on a slowed phone in software, they were half
## its WebGL calls.
func _watch_after_this_frame() -> void:
	_strip_laid += 1
	var laid: int = _strip_laid
	await RenderingServer.frame_post_draw
	if laid == _strip_laid and thumbnails != null:
		thumbnails.watch(self, _tiles if visible else ([] as Array[ThumbTile]))


var _strip_laid: int = 0


## Tell the builder the model changed from step [param from] since their
## place was kept, on the page they are on, and offer that step.
func tell_changed(from: int) -> void:
	changed_from = from
	_told_on = page
	_changed_words.text = "This model changed from step %d." % from
	_changed_go.text = "Go to step %d" % from
	_changed.visible = true


func _hide_changed() -> void:
	changed_from = 0
	_told_on = -1
	_changed.visible = false


func open() -> void:
	visible = true
	_fit()


func close() -> void:
	visible = false
	comments.close()
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
		or _bottom.get_global_rect().has_point(point) or comments.covers(point))


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
	var named: Dictionary = {"build_next": _next, "build_back": _back, "build_close": _close,
		"build_parts": _callout, "build_top": _top, "build_bottom": _bottom,
		"build_progress": _progress, "build_one_part": _one_part, "build_whole_step": _whole_step}
	if _changed.is_visible_in_tree():
		named["build_changed_go"] = _changed_go
	named.merge(comments.controls_by_name())
	return named


## What the page says, for a check to read.
func page_state() -> Dictionary:
	var sizes: Dictionary = {}
	var named: Dictionary = controls_by_name()
	for name: String in ["build_next", "build_back", "build_close"]:
		var button: Button = named.get(name)
		if button != null:
			sizes[name] = [roundi(button.size.x / _pt), roundi(button.size.y / _pt)]
	# Every target on the page, as a finger has it: what can be tapped.
	var targets: Dictionary = {}
	for name: String in named:
		var control: Control = named[name]
		if control is BaseButton and control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect()
			targets[name] = [snappedf(rect.size.x / _pt, 0.1), snappedf(rect.size.y / _pt, 0.1)]
	var counted: Node = _strip.find_child("PartCount", true, false) if _strip != null else null
	return {"open": visible, "page": page, "last": last, "caption": _caption_text,
		"note": _note.text if _note.visible else "", "told": _told.text if _told.visible else "",
		"pictures_ms": _pictures_ms,
		"lots": _lots.size(), "pictures": _tiles.filter(func(tile: ThumbTile) -> bool:
			return tile.state == ThumbTile.State.READY).size(),
		"next": _next.text, "back_enabled": not _back.disabled, "points": sizes,
		"targets": targets, "by_part": by_part, "part": part, "parts": parts,
		"part_count": (counted as Label).text if counted != null else "",
		"changed_from": changed_from, "changed": _changed_words.text if _changed.visible else "",
		"caption_points": roundi(float(_caption.get_theme_font_size("font_size")) / _pt),
		"comment_step": comments.step, "party": _party_page_state()}.merged(comments.page_state())


# -- A build party's page (APP_UX5 buildparty, 2026-11-06) --------------------
#
# Building one share of a model several phones build together (BuildParty):
# under the progress bar, every phone's name in its seat's colour and how
# far along it is ("Mia 4 of 9", "Leo is done"), current within a poll of the
# relay. A phone done before the others waits on its last page, built,
# saying for whom ("Waiting for Mia: 7 of 12"), Next held; once every phone
# is done, each is shown the step that joins the shares, everybody else's
# parts outlined where they go on. main.gd says which page, and when.

var _party_row: HFlowContainer
## Showing a party's page; waiting for the others on its last; on the step
## that joins the shares.
var party_on: bool = false
var party_waiting: bool = false
var party_joining: bool = false
var _party_board: Array = []


func _party_row_made() -> void:
	if _party_row != null:
		return
	_party_row = HFlowContainer.new()
	_party_row.name = "Party"
	_party_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_party_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_row.visible = false
	(_top.get_child(0) as VBoxContainer).add_child(_party_row)


## The party on this page: [param board] each phone ({name, colour, done,
## of, finished, left, me}); [param waiting] for the others, this phone's
## share built; [param joining] the step that joins the shares. Called
## after [method show_page], and again whenever someone's progress changes.
func show_party(board: Array, waiting: bool, joining: bool) -> void:
	_party_row_made()
	party_on = true
	party_waiting = waiting
	party_joining = joining
	_party_board = board
	_party_row.visible = true
	_party_row.add_theme_constant_override("h_separation", roundi(14.0 * _pt))
	_party_row.add_theme_constant_override("v_separation", roundi(4.0 * _pt))
	for child: Node in _party_row.get_children():
		_party_row.remove_child(child)
		child.queue_free()
	for one: Variant in board:
		var chip := HBoxContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_constant_override("separation", roundi(6.0 * _pt))
		var dot := ColorRect.new()
		dot.color = one.get("colour", Color.WHITE) if one.get("colour") is Color else Color.WHITE
		dot.custom_minimum_size = Vector2.ONE * roundi(10.0 * _pt)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(dot)
		var words := Label.new()
		words.text = _chip_words(one)
		words.add_theme_font_size_override("font_size", roundi(14.0 * _pt))
		words.modulate = Color(1, 1, 1, 0.5 if bool(one.get("left", false)) else 0.92)
		chip.add_child(words)
		_party_row.add_child(chip)
	if waiting:
		_caption_text = "Your part is built"
		_caption.text = _caption_text
		_note.text = _waiting_words(board)
		_note.visible = true
		_next.text = "Waiting"
		_next.disabled = true
		_next.tooltip_text = "The step that puts everyone's parts together comes when everyone is done"
		_lots = []
		_told.visible = false
		_lay_strip()
	elif joining:
		_caption_text = "Put it together"
		_caption.text = _caption_text
		_note.text = "Everyone is done. The others' parts go on where they are outlined."
		_note.visible = true
		_next.disabled = false
		_lots = []
		_told.visible = false
		_lay_strip()
	else:
		_next.disabled = false


## Whom this phone waits for: the one still building and how far along,
## or how many are.
static func _waiting_words(board: Array) -> String:
	var others: Array = board.filter(func(one: Dictionary) -> bool:
		return not bool(one.get("me", false)) and not bool(one.get("finished", false)))
	if others.size() == 1:
		return "Waiting for %s: %d of %d" % [str(others[0].get("name", "")), int(others[0].get("done", 0)),
			int(others[0].get("of", 0))]
	return "Waiting for %d others" % others.size() if others.size() > 1 else "Waiting for the others"


## A phone along the top: "Mia 4 of 9", "Leo (you) is done", "Ana has left".
static func _chip_words(one: Dictionary) -> String:
	var who: String = str(one.get("name", ""))
	if bool(one.get("me", false)):
		who = "%s (you)" % who
	if bool(one.get("left", false)):
		return "%s has left" % who
	if bool(one.get("finished", false)):
		return "%s is done" % who
	# Not heard from since the deal: the name alone, not "0 of 0".
	if int(one.get("of", 0)) == 0:
		return who
	return "%s %d of %d" % [who, int(one.get("done", 0)), int(one.get("of", 0))]


## A party's share is built a part at a time: chosen for it, not kept as
## this device's own choice (a tap on Whole step still is).
func party_by_part() -> void:
	by_part = true
	_one_part.set_pressed_no_signal(true)
	_whole_step.set_pressed_no_signal(false)


## A page of the model built alone again: no party along the top, and this
## device's own way of building back.
func end_party() -> void:
	party_on = false
	party_waiting = false
	party_joining = false
	_party_board = []
	if _party_row != null:
		_party_row.visible = false
	if _next != null:
		_next.disabled = false
	by_part = recall_by_part()
	_one_part.set_pressed_no_signal(by_part)
	_whole_step.set_pressed_no_signal(not by_part)


func _party_page_state() -> Dictionary:
	var chips: Array = []
	if _party_row != null and _party_row.visible:
		for chip: Node in _party_row.get_children():
			chips.append((chip.get_child(1) as Label).text)
	return {"on": party_on, "waiting": party_waiting, "joining": party_joining, "chips": chips,
		"next_held": _next.disabled if _next != null else false}
