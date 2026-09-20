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

var _rail: Button
var _holder: Control
var _open: bool = true
var _full_width: float = 0.0
var _tween: Tween

signal toggled(open: bool)


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
	_rail.flat = true
	_rail.pressed.connect(toggle)

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


func toggle() -> void:
	set_open(not _open)


func set_open(open: bool, animate: bool = true) -> void:
	if open == _open:
		return
	_open = open
	_update_rail()

	var target: float = _full_width if open else 0.0
	if _tween and _tween.is_running():
		_tween.kill()
	if not animate:
		_holder.custom_minimum_size.x = target
		toggled.emit(_open)
		return

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_holder, "custom_minimum_size:x", target, SLIDE_SECONDS)
	_tween.finished.connect(func() -> void: toggled.emit(_open))


func _update_rail() -> void:
	# An arrow pointing the way a click will send the panel, so the
	# control says what it does without a label.
	var folds_left: bool = (edge == Edge.LEFT) == _open
	_rail.text = "❮" if folds_left else "❯"
	_rail.tooltip_text = ("Hide this panel" if _open else "Show this panel")
