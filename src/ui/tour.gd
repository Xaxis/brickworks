## Help, Take the tour: the parts of the window one at a time, each lit
## with a frame round it and a card saying what it is for.
##
## Eight cards (seven with the assistant off), Back and Next, Escape or
## Done to leave. Nothing is changed
## by taking it; it only points.
class_name Tour
extends Control

var shell: Shell

var _card: PanelContainer
var _heading: Label
var _words: Label
var _back: Button
var _next: Button
var _at: int = 0
## Where the frame is, in this control's coordinates.
var _lit: Rect2 = Rect2()


## [heading, words, what to light: a function returning a Control or null].
## The assistant's card only while it is in the window (Settings, Assistant
## (AI)): off, the tour is of the CAD and nothing else.
func _stops() -> Array:
	var stops: Array = _every_stop()
	if not shell.assistant_shown:
		stops = stops.filter(func(stop_here: Array) -> bool: return stop_here[0] != ASSISTANT_STOP)
	return stops


const ASSISTANT_STOP := "The assistant"


func _every_stop() -> Array:
	return [
		["Welcome to Brickworks",
			"A program for building with LEGO® bricks: real parts, real colours, and a model you can buy the bricks for. This tour points at each part of the window. Escape leaves it at any time.",
			func() -> Control: return null],
		["The menus",
			"Everything Brickworks can do is in these six menus, with its key beside it: open and save, edit, the view, the build, the tools, and help.",
			func() -> Control: return shell.bar.menus],
		["The toolbar",
			"The tools a click acts through. Select is where the app rests: click a part to pick it out, drag it to move it. Place puts the part in hand down, one click at a time (Q). Move, Rotate, Hinge, Clone, Paint, Hide and Delete each do their one thing to the part you click. The lit one is in use; Escape always comes back to Select.",
			func() -> Control: return shell.toolbar],
		["The parts bin",
			"Every part, by category, or found by name or number. Pick one, pick a colour under it, and click the model to put it down — and again for the next. Escape or a right click lets go of it.",
			func() -> Control: return _opened("_bin_dock")],
		["The model",
			"Right-drag turns the view, the middle button (or Shift and a right drag) slides it, the wheel zooms to the pointer — as in BrickLink Studio, or set it to work like Blender or Mecabricks in Settings. The numbers 1 to 7 look from the front, back, sides, above, below and a corner; F frames what is selected.",
			func() -> Control: return shell.app.get("_marquee").get_parent()],
		["Properties",
			"What is selected: the part and its numbers, its colour by every name it has, where it stands and what it is joined to. Type a number to move it exactly.",
			func() -> Control:
				_opened("_bin_dock")
				shell.inspector.set_open(true)
				return shell.inspector],
		["The status bar",
			"What just happened, or what the tool in use does; how many parts, whether it would stand up, what is selected, the snap and the turn step.",
			func() -> Control: return shell.status],
		[ASSISTANT_STOP,
			"Describe a model and Claude designs and builds it here, part by part — or connect your own Claude to build in this window.",
			func() -> Control: return _opened("_chat_dock")],
	]


## A side column, opened at once if it was folded, so its card has the
## panel to point at: a window with room for one column beside the model
## shows one at a time.
func _opened(dock_name: String) -> SideDock:
	var dock: SideDock = shell.app.get(dock_name)
	if not dock.is_open():
		dock.set_open(true, false)
		# Lit again once the window has laid itself out round it, and the
		# other column has folded away.
		var at: int = _at
		get_tree().create_timer(SideDock.SLIDE_SECONDS + 0.05).timeout.connect(func() -> void:
			if visible and _at == at:
				_show(at))
	return dock


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_card = PanelContainer.new()
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.13, 0.14, 0.17, 0.98)
	backing.border_color = Color(0.56, 0.74, 1.0, 0.8)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(10)
	backing.set_content_margin_all(16)
	_card.add_theme_stylebox_override("panel", backing)
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 17)
	column.add_child(_heading)
	_words = Label.new()
	_words.add_theme_font_size_override("font_size", 14)
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.custom_minimum_size = Vector2(380, 0)
	column.add_child(_words)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var leave := _button("Done", func() -> void: stop())
	row.add_child(leave)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	_back = _button("Back", func() -> void: _show(_at - 1))
	row.add_child(_back)
	_next = _button("Next", func() -> void: _show(_at + 1))
	row.add_child(_next)
	get_viewport().size_changed.connect(func() -> void:
		if visible:
			_show(_at))


func _button(words: String, does: Callable) -> Button:
	var button := Button.new()
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(76, 30)
	button.add_theme_font_size_override("font_size", 13)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(does)
	return button


func start() -> void:
	visible = true
	_show(0)


func stop() -> void:
	visible = false


func is_running() -> bool:
	return visible


func _show(at: int) -> void:
	var stops: Array = _stops()
	if at >= stops.size():
		stop()
		return
	_at = clampi(at, 0, stops.size() - 1)
	var stop_here: Array = stops[_at]
	_heading.text = "%s   (%d of %d)" % [stop_here[0], _at + 1, stops.size()]
	_words.text = stop_here[1]
	_back.disabled = _at == 0
	_next.text = "Next" if _at < stops.size() - 1 else "Finish"
	var target: Control = (stop_here[2] as Callable).call()
	_lit = Rect2()
	if target != null and target.is_visible_in_tree():
		var inverse: Transform2D = get_global_transform().affine_inverse()
		_lit = (inverse * target.get_global_rect()).grow(4.0)
	_card.reset_size()
	# The window, not this control's own size, which a control under a
	# CanvasLayer that starts hidden can still have as nothing.
	var room: Vector2 = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = room
	var card: Vector2 = _card.get_combined_minimum_size()
	var place: Vector2 = (room - card) * 0.5
	if _lit.has_area():
		# Beside what is lit, on whichever side has the room, and never
		# over it.
		var below: float = room.y - _lit.end.y
		if below >= card.y + 16.0:
			place = Vector2(_lit.get_center().x - card.x * 0.5, _lit.end.y + 12.0)
		elif _lit.position.y >= card.y + 16.0:
			place = Vector2(_lit.get_center().x - card.x * 0.5, _lit.position.y - card.y - 12.0)
		elif room.x - _lit.end.x >= card.x + 16.0:
			place = Vector2(_lit.end.x + 12.0, _lit.get_center().y - card.y * 0.5)
		elif _lit.position.x >= card.x + 16.0:
			place = Vector2(_lit.position.x - card.x - 12.0, _lit.get_center().y - card.y * 0.5)
	place.x = clampf(place.x, 12.0, maxf(room.x - card.x - 12.0, 12.0))
	place.y = clampf(place.y, 12.0, maxf(room.y - card.y - 12.0, 12.0))
	_card.position = place
	queue_redraw()


func _draw() -> void:
	var room: Vector2 = get_viewport().get_visible_rect().size
	# Everything dimmed but what is lit.
	var shade := Color(0, 0, 0, 0.45)
	if not _lit.has_area():
		draw_rect(Rect2(Vector2.ZERO, room), shade)
		return
	draw_rect(Rect2(0, 0, room.x, _lit.position.y), shade)
	draw_rect(Rect2(0, _lit.end.y, room.x, room.y - _lit.end.y), shade)
	draw_rect(Rect2(0, _lit.position.y, _lit.position.x, _lit.size.y), shade)
	draw_rect(Rect2(_lit.end.x, _lit.position.y, room.x - _lit.end.x, _lit.size.y), shade)
	draw_rect(_lit, Color(0.56, 0.74, 1.0, 0.95), false, 2.0)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	match key.keycode:
		KEY_ESCAPE:
			stop()
			get_viewport().set_input_as_handled()
		KEY_RIGHT, KEY_ENTER:
			_show(_at + 1)
			get_viewport().set_input_as_handled()
		KEY_LEFT:
			_show(_at - 1)
			get_viewport().set_input_as_handled()
