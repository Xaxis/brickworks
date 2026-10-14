## The few things every panel draws the same way: a link, a tick box, one
## of a choice and a switch.
##
## The app has no theme of its own and every panel styles itself, which
## is fine until two panels need the same thing to look like the same
## thing. Three did not:
##
## A tick box with no tick in it was the engine's own dark square, drawn
## on a panel of nearly the same dark: "Invert zoom direction" in Help
## read as a sentence, not as something to press. The switch for "Or with
## your Claude plan" was a grey dot on nothing. So their pictures are
## drawn here, outlined, and put in the default theme before the first
## panel is made, which reaches every CheckBox and CheckButton without
## touching any of them.
##
## And the secondary actions in the assistant panel ("Added Brickworks to
## Claude before? Use that address") were flat buttons in body text: the
## owner could not tell they were links. A link is now one thing, made by
## [method link], the same blue and underline as "No key yet?".
class_name Look
extends RefCounted

## Links, ticks and a switch that is on.
const ACCENT := Color(0.56, 0.74, 1.0)
const ACCENT_HOVER := Color(0.78, 0.87, 1.0)

const UNCHECKED := """<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
<rect x="1.75" y="1.75" width="12.5" height="12.5" rx="2.5" fill="#ffffff" fill-opacity="0.06"
 stroke="#d4d9e2" stroke-opacity="0.78" stroke-width="1.5"/></svg>"""
const CHECKED := """<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
<rect x="1" y="1" width="14" height="14" rx="3" fill="#8fbcff"/>
<path d="M4.3 8.2 L6.9 10.8 L11.8 5.4" fill="none" stroke="#0f1520" stroke-width="2"
 stroke-linecap="round" stroke-linejoin="round"/></svg>"""
## One of a choice (a CheckBox in a ButtonGroup): Settings, Assistant (AI)
## had a chosen ring beside the engine's unchosen one, which was nothing.
const RADIO_UNCHECKED := """<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
<circle cx="8" cy="8" r="6.25" fill="#ffffff" fill-opacity="0.06"
 stroke="#d4d9e2" stroke-opacity="0.78" stroke-width="1.5"/></svg>"""
const RADIO_CHECKED := """<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
<circle cx="8" cy="8" r="7" fill="#8fbcff"/>
<circle cx="8" cy="8" r="3" fill="#0f1520"/></svg>"""
const SWITCH_OFF := """<svg xmlns="http://www.w3.org/2000/svg" width="34" height="18">
<rect x="1.75" y="2.75" width="30.5" height="12.5" rx="6.25" fill="#ffffff" fill-opacity="0.07"
 stroke="#d4d9e2" stroke-opacity="0.7" stroke-width="1.5"/>
<circle cx="9" cy="9" r="4" fill="#d4d9e2"/></svg>"""
const SWITCH_ON := """<svg xmlns="http://www.w3.org/2000/svg" width="34" height="18">
<rect x="1" y="2" width="32" height="14" rx="7" fill="#5f9bff"/>
<circle cx="25" cy="9" r="4.75" fill="#ffffff"/></svg>"""

## "Type/item" in the theme -> [the SVG, drawn faded for disabled]
const PICTURES: Dictionary = {
	"CheckBox/unchecked": [UNCHECKED, false],
	"CheckBox/checked": [CHECKED, false],
	"CheckBox/unchecked_disabled": [UNCHECKED, true],
	"CheckBox/checked_disabled": [CHECKED, true],
	"CheckBox/radio_unchecked": [RADIO_UNCHECKED, false],
	"CheckBox/radio_checked": [RADIO_CHECKED, false],
	"CheckBox/radio_unchecked_disabled": [RADIO_UNCHECKED, true],
	"CheckBox/radio_checked_disabled": [RADIO_CHECKED, true],
	"CheckButton/unchecked": [SWITCH_OFF, false],
	"CheckButton/checked": [SWITCH_ON, false],
	"CheckButton/unchecked_disabled": [SWITCH_OFF, true],
	"CheckButton/checked_disabled": [SWITCH_ON, true],
	"CheckButton/unchecked_mirrored": [SWITCH_OFF, false],
	"CheckButton/checked_mirrored": [SWITCH_ON, false],
	"CheckButton/unchecked_disabled_mirrored": [SWITCH_OFF, true],
	"CheckButton/checked_disabled_mirrored": [SWITCH_ON, true],
}

static var _textures: Dictionary = {}   ## theme item -> ImageTexture
static var _drawn_at: float = 0.0


## Put the pictures in the default theme, drawn for the density this
## viewport is shown at (see [method Icons.density]). Again whenever that
## changes: the textures are redrawn in place, so every box already made
## follows without being told.
static func apply(viewport: Viewport) -> void:
	var density: float = maxf(absf(viewport.get_final_transform().get_scale().y), 0.25)
	if absf(density - _drawn_at) < 0.01:
		return
	_drawn_at = density
	var theme: Theme = ThemeDB.get_default_theme()
	for item: String in PICTURES:
		var how: Array = PICTURES[item]
		var drawn := Image.new()
		if drawn.load_svg_from_string(how[0], density) != OK:
			continue
		drawn.convert(Image.FORMAT_RGBA8)
		if how[1]:
			_fade(drawn, 0.4)
		var units := Vector2i(_svg_size(how[0]))
		var texture: ImageTexture = _textures.get(item)
		if texture == null:
			texture = ImageTexture.create_from_image(drawn)
			_textures[item] = texture
			var parts: PackedStringArray = item.split("/")
			theme.set_icon(parts[1], parts[0], texture)
		else:
			texture.set_image(drawn)
		# Drawn with as many pixels as it is shown with, measured in units.
		texture.set_size_override(units)


## A link: blue, underlined, and only as wide as its words, so a click
## beside it is not a click on it.
static func link(text: String, font_size: int = 12) -> LinkButton:
	var made := LinkButton.new()
	made.text = text
	made.focus_mode = Control.FOCUS_NONE
	made.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	made.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", ACCENT)
	made.add_theme_color_override("font_focus_color", ACCENT)
	made.add_theme_color_override("font_hover_color", ACCENT_HOVER)
	made.add_theme_color_override("font_pressed_color", ACCENT_HOVER)
	made.add_theme_color_override("font_hover_pressed_color", ACCENT_HOVER)
	return made


static func _fade(image: Image, alpha: float) -> void:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			c.a *= alpha
			image.set_pixel(x, y, c)


static func _svg_size(svg: String) -> Vector2:
	var found := RegEx.create_from_string("width=\"(\\d+)\" height=\"(\\d+)\"").search(svg)
	return Vector2(float(found.get_string(1)), float(found.get_string(2))) \
		if found != null else Vector2(16, 16)
