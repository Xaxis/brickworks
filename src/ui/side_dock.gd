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
## What the panel is, written down the rail under its icon: in a window
## that shows one column at a time the other is only its rail, and a pair
## of chevrons did not say what was behind it.
var title: String = ""
## Its icon at the top of the rail, drawn: "parts" (a brick), "properties"
## (three sliders) or "assistant" (a spark).
var icon: String = ""
## What showing or hiding it does, for the rail's tooltip: "the parts bin".
var holds: String = ""

var _rail: Button
## The strip the rail stands in, at the panel's inner edge: shared with the
## panels this one shares its edge with (share_edge), their rails one over
## another.
var _rails: VBoxContainer
## The panels on this edge with this one, of which one is open at a time.
var _edge_mates: Array[SideDock] = []
var _arrow: Chevron
var _open_idle: StyleBoxFlat
var _open_hover: StyleBoxFlat
var _folded_idle: StyleBoxFlat
var _folded_hover: StyleBoxFlat
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


## On a phone (PhoneShell): the rail shows only while the panel is open, as
## its way out, and is a fingertip wide. Folded, the phone's own bars lead
## to the panel. Nothing changes on a desktop, which never calls this.
var _phone_rail: float = 0.0


## The panel and its rail also stop [param foot] above the screen's foot,
## where the phone's row of tools lies over them: the assistant's Connect
## Claude went under it at 844 x 390, with no scrolling that could bring it
## out.
func set_phone_rail(width: float, foot: float = 0.0) -> void:
	_phone_rail = width
	content.offset_bottom = -foot
	var under := Control.new()
	under.custom_minimum_size.y = foot
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rails.add_child(under)
	_update_rail()


## The dock [param inside] is in, or null: for a command that shows a
## section of a column (Shell's View, Properties) to open the column it is
## in, wherever the window put it.
static func of(inside: Node) -> SideDock:
	var at: Node = inside
	while at != null and not at is SideDock:
		at = at.get_parent()
	return at as SideDock


## Share the edge [param first] is on: this panel's rail goes under its
## rail, in one strip, and one of the two is open at a time, as the tabs of
## one column. Opening one while the other is open swaps them where they
## stand, without a slide: the column stays, and what is in it changes.
## This panel is then only its holder, laid after [param first]'s.
func share_edge(first: SideDock) -> void:
	_rails.remove_child(_rail)
	first._rails.add_child(_rail)
	remove_child(_rails)
	_rails.queue_free()
	_rails = first._rails
	for mate: SideDock in first._edge_mates:
		mate._edge_mates.append(self)
		_edge_mates.append(mate)
	first._edge_mates.append(self)
	_edge_mates.append(first)
	# Hidden (the assistant turned off), its rail goes with it.
	visibility_changed.connect(func() -> void: _rail.visible = visible)


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

	_rails = VBoxContainer.new()
	_rails.add_theme_constant_override("separation", 0)
	_rails.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rails.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_rails.add_child(_rail)
	if edge == Edge.LEFT:
		add_child(_holder)
		add_child(_rails)
	else:
		add_child(_rails)
		add_child(_holder)
	_update_rail()


func _style_rail() -> void:
	# The rail has to be findable without being loud. A vertical strip a
	# shade lighter than the panel, with a line down its inner edge, reads
	# as a grab handle at a glance and disappears when you are not looking
	# for it.
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color(0.17, 0.18, 0.21, 0.94)
	# The line 3:1 on the panel (Look.OUTLINE), so the rail is seen to be
	# something to press: at 13% white it and the strip were 2.0:1.
	idle.border_color = Look.OUTLINE
	if edge == Edge.LEFT:
		idle.border_width_right = 1
	else:
		idle.border_width_left = 1

	var hover: StyleBoxFlat = idle.duplicate()
	hover.bg_color = Color(0.27, 0.30, 0.36, 0.98)
	hover.border_color = Color(1, 1, 1, 0.3)

	# Folded, it is all there is of the panel, and has to be seen at a
	# glance: tinted, with the accent down its inner edge.
	_folded_idle = idle.duplicate()
	_folded_idle.bg_color = Color(0.17, 0.21, 0.29, 0.97)
	_folded_idle.border_color = Color(0.56, 0.74, 1.0, 0.75)
	if edge == Edge.LEFT:
		_folded_idle.border_width_right = 2
	else:
		_folded_idle.border_width_left = 2
	_folded_hover = _folded_idle.duplicate()
	_folded_hover.bg_color = Color(0.24, 0.30, 0.40, 1.0)
	_open_idle = idle
	_open_hover = hover

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
		# The other tab of this column out: swapped where it stands.
		for mate: SideDock in _edge_mates:
			if mate.is_open():
				mate.set_open(false, false)
				animate = false
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
	if _phone_rail > 0.0:
		_rail.visible = _open
		_rail.custom_minimum_size.x = _phone_rail
	# An arrow pointing the way a click will send the panel, so the
	# control says what it does without a label. Doubled when the panel
	# is away, because then the rail is the only thing left of it and has
	# to read as a thing to click rather than as a stray mark.
	_arrow.points_left = (edge == Edge.LEFT) == _open
	_arrow.doubled = not _open
	_arrow.words = title
	_arrow.icon = icon
	_arrow.lit = not _open
	_arrow.queue_redraw()
	if _folded_idle != null:
		for state: String in ["normal", "pressed", "focus"]:
			_rail.add_theme_stylebox_override(state, _open_idle if _open else _folded_idle)
		_rail.add_theme_stylebox_override("hover", _open_hover if _open else _folded_hover)
	var what: String = holds if not holds.is_empty() else "this panel"
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
	## Written down the rail under the icon, top to bottom.
	var words: String = ""
	## "parts" or "assistant": which icon tops the rail.
	var icon: String = ""
	## Brighter, and the icon in the accent colour: the panel is folded.
	var lit: bool = false

	const ACCENT := Color(0.56, 0.74, 1.0)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSLATION_CHANGED:
			queue_redraw()

	func _draw() -> void:
		var middle: Vector2 = size * 0.5
		var tint := Color(1, 1, 1, 0.92 if doubled else 0.72)
		if doubled:
			_chevron(middle + Vector2(0, -5), tint)
			_chevron(middle + Vector2(0, 5), tint)
		else:
			_chevron(middle, tint)
		var top := Vector2(middle.x, 24.0)
		var ink: Color = ACCENT if lit else Color(1, 1, 1, 0.6)
		match icon:
			"parts":
				_brick(top, ink)
			"properties":
				_sliders(top, ink)
			"assistant":
				_spark(top, ink)
		if not words.is_empty():
			const SIZE := 13
			var font: Font = get_theme_default_font()
			# Turned a quarter: the line runs down the rail, and the
			# letters stand to the right of it, so it is moved left by
			# half their height to sit in the middle.
			draw_set_transform(Vector2(middle.x - SIZE * 0.36, top.y + 20.0), PI * 0.5)
			# In the language in use (Language), as a label's words are.
			draw_string(font, Vector2.ZERO, atr(words), HORIZONTAL_ALIGNMENT_LEFT, -1.0, SIZE,
				Color(1, 1, 1, 0.92 if lit else 0.6))
			draw_set_transform(Vector2.ZERO, 0.0)

	## A 1 x 2 brick, side on: the parts bin.
	func _brick(at: Vector2, ink: Color) -> void:
		draw_rect(Rect2(at + Vector2(-7, -2), Vector2(14, 8)), ink)
		draw_rect(Rect2(at + Vector2(-5.5, -5), Vector2(4, 3)), ink)
		draw_rect(Rect2(at + Vector2(1.5, -5), Vector2(4, 3)), ink)

	## Three sliders, each with its knob: the model tree and the properties.
	func _sliders(at: Vector2, ink: Color) -> void:
		for row: int in 3:
			var y: float = at.y - 5.0 + row * 5.0
			draw_line(Vector2(at.x - 7.0, y), Vector2(at.x + 7.0, y), ink, 1.4, true)
			draw_circle(Vector2(at.x + [3.0, -3.5, 1.0][row], y), 2.2, ink)

	## A four-pointed spark, and a small one by it: the assistant.
	func _spark(at: Vector2, ink: Color) -> void:
		for one: Array in [[at + Vector2(-1, 1), 7.5], [at + Vector2(5, -5), 3.2]]:
			var c: Vector2 = one[0]
			var r: float = one[1]
			var w: float = r * 0.28
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(w, -w),
				c + Vector2(r, 0), c + Vector2(w, w), c + Vector2(0, r), c + Vector2(-w, w),
				c + Vector2(-r, 0), c + Vector2(-w, -w)]), ink)

	func _chevron(at: Vector2, tint: Color) -> void:
		const REACH := 3.5
		const HALF := 4.5
		var lean: float = -REACH if points_left else REACH
		draw_polyline(PackedVector2Array([
			at + Vector2(-lean, -HALF), at + Vector2(lean, 0.0),
			at + Vector2(-lean, HALF)]), tint, 1.6, true)
