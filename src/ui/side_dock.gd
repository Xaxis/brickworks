## A panel that folds away to the edge it lives on.
##
## Both side panels are wide, and most of the time you are looking at the
## model rather than at them. Folding one should give its width back to
## the viewport immediately and be a single obvious click to undo — not a
## menu item, not a drag handle you have to find.
##
## So the panel keeps a slim rail at its edge whether it is open or shut.
## The rail is always there, always in the same place, and says which way
## it will move with an arrow that turns. Shut, the rail is all that is
## left, and the viewport has the space.
class_name SideDock
extends HBoxContainer

## Which edge this dock is pinned to. The rail sits on the inner side,
## and the arrow points the way a click will send the panel.
enum Edge { LEFT, RIGHT }

const RAIL_WIDTH := 26
const SLIDE_SECONDS := 0.22

var edge: int = Edge.LEFT
var content: Control
## What the panel is, written down the rail while it is folded: in a
## window that shows one column at a time the other is only its rail, and
## a pair of chevrons did not say what was behind it.
var title: String = ""

var _rail: Button
var _arrow: Chevron
var _holder: Control
var _open: bool = true
var _full_width: float = 0.0
var _tween: Tween

signal toggled(open: bool)
## Before an open begins, so the other column can make room for this one
## in a window with room for only one (Main._fit_panels).
signal opening


## How wide the panel is when open. Changing it while open resizes it,
## which is what a window being resized has to do.
func set_open_width(width: float) -> void:
	_full_width = width
	if _open:
		_holder.custom_minimum_size.x = width


func open_width() -> float:
	return _full_width


func setup(inner: Control, on_edge: int, width: float) -> void:
	edge = on_edge
	content = inner
	_full_width = width
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_PASS

	_holder = Control.new()
	_holder.custom_minimum_size = Vector2(width, 0)
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.clip_contents = true
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(inner)

	_rail = Button.new()
	_rail.custom_minimum_size = Vector2(RAIL_WIDTH, 0)
	_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rail.focus_mode = Control.FOCUS_NONE
	# Not flat. A flat Button draws no background at all and ignores the
	# styleboxes below, which left the rail as an arrow floating over the
	# viewport with nothing to aim at — findable only by someone who
	# already knew it was there, and invisible over a pale model.
	_rail.pressed.connect(toggle)

	_arrow = Chevron.new()
	_rail.add_child(_arrow)

	# The rail is always on the inner side, so it stays put when the
	# panel folds rather than travelling with it.
	# Styled after the edge is known, since the rail's border sits on its
	# inner side.
	_style_rail()
	if edge == Edge.LEFT:
		add_child(_holder)
		add_child(_rail)
	else:
		add_child(_rail)
		add_child(_holder)
	_update_rail()


func _style_rail() -> void:
	# The rail has to be findable without being loud. A vertical strip a
	# shade lighter than the panel, with a line down its inner edge, reads
	# as a grab handle at a glance and disappears when you are not looking
	# for it.
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color(0.17, 0.18, 0.21, 0.94)
	idle.border_color = Color(1, 1, 1, 0.13)
	if edge == Edge.LEFT:
		idle.border_width_right = 1
	else:
		idle.border_width_left = 1

	var hover: StyleBoxFlat = idle.duplicate()
	hover.bg_color = Color(0.27, 0.30, 0.36, 0.98)
	hover.border_color = Color(1, 1, 1, 0.3)

	for state: String in ["normal", "pressed", "focus"]:
		_rail.add_theme_stylebox_override(state, idle)
	_rail.add_theme_stylebox_override("hover", hover)
	_rail.add_theme_font_size_override("font_size", 15)
	_rail.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_rail.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))


func is_open() -> bool:
	return _open


## The strip that opens and folds the panel, for the page to find
## (Main._tell_page): on a phone it is the only way to the panel.
func rail() -> Control:
	return _rail


func toggle() -> void:
	set_open(not _open)


func set_open(open: bool, animate: bool = true) -> void:
	if open == _open:
		return
	if open:
		opening.emit()
	_open = open
	_update_rail()
	# Shown from the start of an open, hidden at the end of a fold. A
	# folded panel was only clipped to nothing: its fields could still
	# take the keys, and the page was told its buttons were there, off
	# the window's edge, for a browser test to click at.
	if open:
		content.visible = true

	var target: float = _full_width if open else 0.0
	if _tween and _tween.is_running():
		_tween.kill()
	if not animate:
		_holder.custom_minimum_size.x = target
		_settled()
		return

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_holder, "custom_minimum_size:x", target, SLIDE_SECONDS)
	_tween.finished.connect(_settled)


func _settled() -> void:
	content.visible = _open
	toggled.emit(_open)


func _update_rail() -> void:
	# An arrow pointing the way a click will send the panel, so the
	# control says what it does without a label. Doubled when the panel
	# is away, because then the rail is the only thing left of it and has
	# to read as a thing to click rather than as a stray mark.
	_arrow.points_left = (edge == Edge.LEFT) == _open
	_arrow.doubled = not _open
	_arrow.words = "" if _open else title
	_arrow.queue_redraw()
	var what: String = title if not title.is_empty() else "this panel"
	_rail.tooltip_text = ("Hide " if _open else "Show ") + what


## The chevron, drawn rather than typeset.
##
## It was the characters U+276E and U+276F, which the desktop found in a
## system font and the browser did not — there is no fallback there, so
## on the web both rails showed a missing-glyph box. Two lines and an
## arc have no such problem, and they scale with the rail.
class Chevron extends Control:
	var points_left: bool = true
	var doubled: bool = false
	## Written down the rail under the chevrons, top to bottom.
	var words: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var middle: Vector2 = size * 0.5
		var tint := Color(1, 1, 1, 0.92 if doubled else 0.72)
		if doubled:
			_chevron(middle + Vector2(0, -5), tint)
			_chevron(middle + Vector2(0, 5), tint)
		else:
			_chevron(middle, tint)
		if not words.is_empty():
			const SIZE := 12
			var font: Font = get_theme_default_font()
			# Turned a quarter: the line runs down the rail, and the
			# letters stand to the right of it, so it is moved left by
			# half their height to sit in the middle.
			draw_set_transform(Vector2(middle.x - SIZE * 0.36, middle.y + 20.0), PI * 0.5)
			draw_string(font, Vector2.ZERO, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SIZE,
				Color(1, 1, 1, 0.66))
			draw_set_transform(Vector2.ZERO, 0.0)

	func _chevron(at: Vector2, tint: Color) -> void:
		const REACH := 3.5
		const HALF := 4.5
		var lean: float = -REACH if points_left else REACH
		draw_polyline(PackedVector2Array([
			at + Vector2(-lean, -HALF), at + Vector2(lean, 0.0),
			at + Vector2(-lean, HALF)]), tint, 1.6, true)
