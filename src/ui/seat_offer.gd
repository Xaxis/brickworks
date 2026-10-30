## The offer to seat an old model's parts on their studs, made once, when
## a model that needs it is opened.
##
## Models saved before 2026-10-10 can carry parts a tenth of a stud off
## their studs (see Seating). They open looking very slightly wrong — a
## wing tip, a flag, a plant not quite on the plate — with nothing to say
## why or what to do. A command-line tool fixed the files; nobody opening
## a model in the app would know it existed.
##
## So the app says what it found and offers one thing to do about it, in
## a strip over the top of the model: seat them, or leave them. Seating
## is one step to undo, like any other edit.
class_name SeatOffer
extends PanelContainer

var builder: Builder
var world: BrickWorld
var assistant: Assistant
var scenery: Dictionary = {}
var say: Callable = func(_line: String) -> void: pass
var edited: Callable = func() -> void: pass

var _moves: Dictionary = {}
var _words: Label
var _seat: Button
var _leave: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.12, 0.14, 0.18, 0.96)
	backing.border_color = Color(0.56, 0.74, 1.0, 0.55)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 14
	backing.content_margin_right = 10
	backing.content_margin_top = 8
	backing.content_margin_bottom = 8
	add_theme_stylebox_override("panel", backing)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	_words = Label.new()
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.custom_minimum_size = Vector2(240, 0)
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.add_theme_font_size_override("font_size", 13)
	_words.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	row.add_child(_words)

	_seat = _button("Seat them on their studs", true)
	Keymap.tell(_seat, "Move each of them the fraction of a stud back onto its studs.\n"
		+ "One step: {undo|puts them back}.")
	_seat.pressed.connect(seat)
	row.add_child(_seat)
	_leave = _button("Leave them", false)
	_leave.tooltip_text = "Keep the model exactly as it was saved"
	_leave.pressed.connect(dismiss)
	row.add_child(_leave)


func _button(words: String, main: bool) -> Button:
	var button := Button.new()
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	for state: String in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		var base: Color = Color(0.29, 0.5, 0.92) if main else Color(1, 1, 1, 0.08)
		face.bg_color = base.lightened(0.12) if state == "hover" else (
			base.darkened(0.12) if state == "pressed" else base)
		face.set_corner_radius_all(6)
		face.content_margin_left = 12
		face.content_margin_right = 12
		face.content_margin_top = 6
		face.content_margin_bottom = 6
		button.add_theme_stylebox_override(state, face)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	return button


## Look at the model just opened, and offer to seat it if it needs it.
## Returns how many parts are off their studs.
func check() -> int:
	_moves = Seating.misplaced(world, builder, assistant, scenery)
	if _moves.is_empty():
		visible = false
		return 0
	var count: int = _moves.size()
	_words.text = ("%s in this model %s a fraction of a stud off %s studs, "
		+ "as models saved before 10 October 2026 can.") % [
		"One part" if count == 1 else "%d parts" % count,
		"sits" if count == 1 else "sit", "its" if count == 1 else "their"]
	visible = true
	return count


## Seat every part that needs it, as one step.
func seat() -> int:
	var moved: int = builder.move_bricks(_moves)
	_moves = {}
	visible = false
	if moved > 0:
		edited.call()
		say.call(Keymap.filled("seated %d %s on %s studs — {undo|takes it back}") % [moved,
			"part" if moved == 1 else "parts", "its" if moved == 1 else "their"])
	return moved


func dismiss() -> void:
	_moves = {}
	visible = false


func controls_by_name() -> Dictionary:
	return {"seat_parts": _seat, "leave_parts": _leave} if visible else {}
