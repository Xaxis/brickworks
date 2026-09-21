## The verbs a finger cannot otherwise reach.
##
## Placing and removing have gestures — a tap and a hold — and turning
## the view has one too. Everything else in this app is a key, and a
## phone has no keys: rotating the part you are about to place, laying
## it on its side, and undoing were simply unavailable, with the strip
## along the bottom listing five things where a desktop is told twenty.
##
## So they get buttons, and only where there is no keyboard to press
## instead. Forty-six points tall, because they are targets for a
## fingertip: forty-four is what Apple asks for and what everyone else
## has settled near, and the previous on-screen control this app added
## was nine pixels across.
##
## Words, not symbols. The turn and undo arrows — U+27F3 and U+21B6 —
## are not in the font this ships, and a character the font does not
## have draws as an empty box. The same mistake was made here once
## before with the chevrons and the play and pause marks, and the
## lesson is the one that keeps having to be relearned: a glyph is only
## a picture if somebody drew it.
class_name TouchTools
extends VBoxContainer

## Big enough to hit without looking.
const TARGET := 46.0

signal chose(what: String)


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_PASS
	for tool: Array in [
		["rotate", "Turn", "Turn the part a quarter"],
		["tip", "Tip", "Lay the part on its side"],
		["undo", "Undo", "Undo"],
		["redo", "Redo", "Redo"],
	]:
		_add(str(tool[0]), str(tool[1]), str(tool[2]))


## Whether this build wants them at all.
##
## A touchscreen and no room for a keyboard. A laptop with a touchscreen
## has both, and putting finger-sized buttons over its viewport would be
## taking space from somebody who has a keyboard beside them.
static func wanted() -> bool:
	if not DisplayServer.is_touchscreen_available():
		return false
	return Room.across() < 1100.0


func _add(what: String, word: String, says: String) -> void:
	var button := Button.new()
	button.text = word
	button.tooltip_text = says
	button.custom_minimum_size = Vector2(TARGET * 1.5, TARGET)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)

	# Its own look, because the toolbar style is made for a row of words
	# at the top of a window and these are discs over a model.
	for state: String in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = (Color(0.16, 0.17, 0.20, 0.92) if state != "pressed"
			else Color(0.30, 0.32, 0.38, 0.96))
		face.set_corner_radius_all(int(TARGET * 0.5))
		face.content_margin_left = 6
		face.content_margin_right = 6
		button.add_theme_stylebox_override(state, face)

	button.pressed.connect(func() -> void: chose.emit(what))
	add_child(button)
