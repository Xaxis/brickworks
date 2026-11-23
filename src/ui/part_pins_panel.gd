## The comments people left on parts of this model on brickworks.diy, for
## its builder in the studio (partpins, 2026-11-23): each open one with its
## number (the dot on its part), who wrote it and when, what they said and
## where it is ("On the 2 × 4 brick, step 12", PinPlace), pressed to select
## its part and turn the view to it; Resolve, one press, folds it under
## Resolved, where Reopen brings it back. What Resolve does is the server's
## (PartPins sends it): the site shows it resolved, folded away, too.
##
## In the tool column, in its panels' look (HiddenColoursPanel's). It shows
## what it is given ([method fill]) and says what was pressed.
class_name PartPinsPanel
extends PanelContainer

## Select [param one]'s part and turn the view to it.
signal show_wanted(one: Dictionary)
## [param one] done with ([param done] true), or open again.
signal resolve_wanted(one: Dictionary, done: bool)
## Put away by Close.
signal closed

const WIDE := 360.0
## The list's rows seen at once before it scrolls, in units.
const TALLEST := 380.0

var _list: VBoxContainer
var _scroll: ScrollContainer
var _said: Label
var _close: Button
var _fold: Button
var _folded: bool = true
var _shows: Dictionary = {}
var _resolves: Dictionary = {}
var _reopens: Dictionary = {}
var _rows_said: Array = []
var _open: Array = []
var _done: Array = []
var _line_of: Callable = Callable()


func _ready() -> void:
	visible = false
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.96)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 11
	backing.content_margin_bottom = 12
	add_theme_stylebox_override("panel", backing)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Comments on parts"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close = _button(header, "Close", close, "Put the list away: the comments stay on their parts")
	var about: Label = _words(column, 12, 0.75)
	about.text = ("What people said about parts of this model on brickworks.diy, each "
		+ "numbered as its dot on the model. Press where one is to select its part.")
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_said = _words(column, 12, 0.9)
	_said.modulate = Color(1.0, 0.86, 0.45)
	_said.visible = false


func _words(into: Control, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDE, 0)
	label.modulate = Color(1, 1, 1, alpha)
	into.add_child(label)
	return label


func _button(into: Control, words: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	into.add_child(button)
	return button


func open() -> void:
	visible = true
	_said.visible = false


func close() -> void:
	visible = false
	closed.emit()


## List [param open] and [param done] (the comments on parts, open and
## resolved, oldest first), each said by [param line_of] (PartPins.line_of).
func fill(open_ones: Array, done_ones: Array, line_of: Callable) -> void:
	_open = open_ones
	_done = done_ones
	_line_of = line_of
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_shows.clear()
	_resolves.clear()
	_reopens.clear()
	_rows_said.clear()
	_fold = null
	for one: Variant in open_ones:
		_list.add_child(_row(one as Dictionary, false))
	if open_ones.is_empty():
		var none: Label = _words(_list, 12, 0.6)
		none.text = "No open comments on parts." if not done_ones.is_empty() \
			else "No comments on parts of this model yet."
	if not done_ones.is_empty():
		_fold = _button(_list, ("Resolved (%d)" % done_ones.size()) if _folded else "Hide resolved",
			func() -> void:
				_folded = not _folded
				fill(_open, _done, _line_of),
			"The comments you have dealt with: still on the site, folded away")
		_fold.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if not _folded:
			for one: Variant in done_ones:
				var row: Control = _row(one as Dictionary, true)
				row.modulate = Color(1, 1, 1, 0.6)
				_list.add_child(row)
	_hold_height.call_deferred()


func _hold_height() -> void:
	if is_instance_valid(_scroll):
		_scroll.custom_minimum_size = Vector2(WIDE, minf(_list.get_combined_minimum_size().y, TALLEST))


func _row(one: Dictionary, done: bool) -> Control:
	var line: Dictionary = _line_of.call(one) if _line_of.is_valid() else {}
	var number: int = int(line.get("number", 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dot := Label.new()
	dot.text = str(number) if number > 0 else ""
	dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.custom_minimum_size = Vector2(22, 22)
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dot.add_theme_font_size_override("font_size", 12)
	dot.add_theme_color_override("font_color", Color.WHITE)
	var round_dot := StyleBoxFlat.new()
	round_dot.bg_color = Color("#e8590c") if not done else Color(0.4, 0.42, 0.46)
	round_dot.border_color = Color.WHITE
	round_dot.set_border_width_all(2)
	round_dot.set_corner_radius_all(11)
	dot.add_theme_stylebox_override("normal", round_dot)
	row.add_child(dot)
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 2)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(middle)
	var head := Label.new()
	var who: String = str(one.get("by", "")) if one.get("by") is String else ""
	var bits: Array[String] = [who if not who.is_empty() else "A builder"]
	var when: String = StepComments._day(str(one.get("at", "")))
	if not when.is_empty():
		bits.append(when)
	if one.get("hidden") is bool and bool(one["hidden"]):
		bits.append("hidden from others")
	head.text = " · ".join(bits)
	head.modulate = Color(1, 1, 1, 0.65)
	head.add_theme_font_size_override("font_size", 11)
	middle.add_child(head)
	var body := Label.new()
	body.text = str(one.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(WIDE - 120.0, 0)
	body.add_theme_font_size_override("font_size", 13)
	middle.add_child(body)
	var where := Button.new()
	where.text = str(line.get("words", ""))
	where.flat = true
	where.alignment = HORIZONTAL_ALIGNMENT_LEFT
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	where.custom_minimum_size = Vector2(WIDE - 120.0, 0)
	where.focus_mode = Control.FOCUS_NONE
	where.add_theme_font_size_override("font_size", 12)
	where.add_theme_color_override("font_color", Color(1.0, 0.72, 0.5))
	where.add_theme_color_override("font_hover_color", Color(1.0, 0.84, 0.68))
	var pressable: bool = bool(line.get("pressable", false))
	where.disabled = not pressable
	where.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if pressable \
		else Control.CURSOR_ARROW
	where.tooltip_text = "Select its part, and turn the view to it" if pressable \
		else "Not on a part of the model as it is now: its part was changed or taken off since"
	where.pressed.connect(func() -> void: show_wanted.emit(one))
	middle.add_child(where)
	var settle := Button.new()
	settle.text = "Reopen" if done else "Resolve"
	settle.focus_mode = Control.FOCUS_NONE
	settle.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	settle.add_theme_font_size_override("font_size", 12)
	settle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	settle.tooltip_text = "Back on its part, open, on the site too" if done \
		else "Done with it: folded away as resolved, here and on the site"
	settle.pressed.connect(func() -> void:
		settle.disabled = true
		resolve_wanted.emit(one, not done))
	row.add_child(settle)
	if number > 0:
		if done:
			_reopens[number] = settle
		else:
			_resolves[number] = settle
		if pressable:
			_shows[number] = where
	_rows_said.append({"number": number, "by": head.text, "body": body.text, "where": where.text,
		"resolved": done, "pressable": pressable})
	return row


## Why the last press was not taken, in the server's words; "" says nothing.
func say(words: String) -> void:
	_said.text = words
	_said.visible = not words.is_empty()


func page_state() -> Dictionary:
	return {"open": visible, "rows": _rows_said.duplicate(true) if visible else [],
		"resolved": _done.size(), "folded": _folded, "said": _said.text if _said.visible else ""}


## What a check presses: Close, each open one's place (part_pin_N) and
## Resolve, the fold, and each resolved one's Reopen while unfolded.
func controls_by_name() -> Dictionary:
	if not is_visible_in_tree():
		return {}
	var out: Dictionary = {"part_pins_close": _close}
	if _fold != null:
		out["part_pins_resolved"] = _fold
	for number: int in _shows:
		out["part_pin_%d" % number] = _shows[number]
	for number: int in _resolves:
		out["part_pin_resolve_%d" % number] = _resolves[number]
	for number: int in _reopens:
		out["part_pin_reopen_%d" % number] = _reopens[number]
	return out
