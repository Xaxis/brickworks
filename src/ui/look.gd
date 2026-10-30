## The few things every panel draws the same way: a link, a tick box, one
## of a choice, a switch, and the engine's own dialogs and menus.
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
## The face of the app's panels and its edge (LibraryDialog._build), which
## [method dialogs] gives the engine's windows.
const FACE := Color(0.10, 0.11, 0.13, 0.98)
const EDGE := Color(1, 1, 1, 0.14)
## The edge round a button of the engine's, so it is seen to be one: the
## tick boxes' outline (UNCHECKED), at least 3:1 on every face the app has
## (WCAG 1.4.11), and still so where the window is drawn smaller than the
## app is laid out for and a line of one unit is spread over two pixels.
## The engine's fill alone, black at 60% on the dark face, was 1.0:1, and
## "Start a session", Cancel, Join read as words (contrast270, 2026-10-26).
const OUTLINE := Color(0.83, 0.85, 0.89)
## A dialog's default button (its OK), and the app's own strong ones
## (Render picture): white words at least 4.5:1 on it, it at least 3:1 on
## the face. Render's blue was 3.4:1 under its words.
const STRONG := Color(0.20, 0.42, 0.85)
const STRONG_HOVER := Color(0.21, 0.44, 0.88)
const STRONG_DOWN := Color(0.17, 0.36, 0.75)
## One of a choice that is chosen (a tab, a segment): the accent, at least
## 3:1 on the face; at 38% it was 2.0:1.
const CHOSEN := Color(0.36, 0.6, 1.0, 0.65)
## A menu's row under the pointer or the keyboard's focus: a dark fill,
## edged in [constant ACCENT], which is what is seen to move (9:1 on the
## face). The engine's highlight was the grey of a greyed row's words, so a
## greyed row with the focus read as a blank bar (APP_UX A2): read off the
## window, its words were 3.2:1 on it, and a greyed row's 1.9:1 on the face.
const ROW_LIT := Color(0.13, 0.16, 0.22)
## A row's words, a little whiter than the engine's, so a greyed row is
## seen to be one beside it.
const ROW_WORDS := Color(0.95, 0.95, 0.96)
## A greyed row's words, and every row's key: dimmer than a row that can be
## used, and 7:1 or better on the face and on [constant ROW_LIT] both, so
## that the window's own pixels, where 12-unit words are spread thin, still
## read 4.5:1 or better (keysheet_probe).
const GREYED := Color(0.72, 0.74, 0.78)

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


## The engine's own windows in the look of the app's panels (LibraryDialog,
## RenderDialog): their dark face, faint edge and round corners for every
## dialog's frame, title bar and body (an AcceptDialog, a
## ConfirmationDialog, a FileDialog, and the questions a FileDialog asks
## itself), every menu (the menu bar's, a part's, a list's), and on the
## desktop every popup (the colour picker's). Put in the default theme
## before the first window is made, as the tick boxes are, so it reaches
## every one without touching any; sizes stay the engine's, so nothing in
## them moves. The engine's grey sat beside panels in the app's face: the
## photo search's question, Build together and the choosers (walk256 DS1,
## 2026-10-25), Versions, Saved models and every question the app asks.
## The menus are the app's face on the web too, with their rows (menus()):
## a greyed row must read with the focus on it there as well.
static func dialogs() -> void:
	var theme: Theme = ThemeDB.get_default_theme()
	_face(theme, "embedded_border", "Window", true)
	_face(theme, "embedded_unfocused_border", "Window", true)
	_face(theme, "panel", "AcceptDialog", false)
	_face(theme, "panel", "PopupMenu", true)
	if not OS.has_feature("web"):
		_face(theme, "panel", "PopupPanel", true)
	menus(theme)


## Every menu's rows, in each state a row has, at 4.5:1 or better on what is
## behind them (keysheet_probe reads them off the window): a row, its key,
## one greyed, and each with the pointer or the focus on it.
static func menus(theme: Theme) -> void:
	var engine := theme.get_stylebox("hover", "PopupMenu") as StyleBoxFlat
	if engine == null or engine.has_meta(&"look"):
		return
	var lit := engine.duplicate() as StyleBoxFlat
	lit.bg_color = ROW_LIT
	lit.border_color = ACCENT
	lit.set_border_width_all(1)
	lit.set_corner_radius_all(3)
	lit.set_meta(&"look", true)
	theme.set_stylebox("hover", "PopupMenu", lit)
	theme.set_color("font_color", "PopupMenu", ROW_WORDS)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_color("font_disabled_color", "PopupMenu", GREYED)
	theme.set_color("font_accelerator_color", "PopupMenu", GREYED)


## Every button of the engine's edged with [constant OUTLINE], inside its
## own box, so nothing moves; and every dialog's default button, its OK
## where it has others beside it, in [constant STRONG], told apart from
## them (a ConfirmationDialog's, a FileDialog's). In the default theme
## before the first button is made, as [method dialogs] is.
static func buttons() -> void:
	var theme: Theme = ThemeDB.get_default_theme()
	# And a tab not chosen, which the colour picker's modes are drawn as
	# (RGB, HSV, Linear: 1.2:1), and the print designer's areas.
	var states: Dictionary = {"Button": ["normal", "hover", "pressed"],
		"OptionButton": ["normal", "hover", "pressed"], "MenuButton": ["normal", "hover", "pressed"],
		"TabContainer": ["tab_unselected", "tab_hovered"], "TabBar": ["tab_unselected", "tab_hovered"]}
	for type: String in states:
		for state: String in states[type]:
			var engine := theme.get_stylebox(state, type) as StyleBoxFlat
			if engine == null or engine.has_meta(&"look"):
				continue
			var edged := engine.duplicate() as StyleBoxFlat
			edged.border_color = OUTLINE
			edged.set_border_width_all(1)
			edged.set_meta(&"look", true)
			theme.set_stylebox(state, type, edged)
	if theme.is_type_variation(&"DefaultButton", &"Button"):
		return
	theme.set_type_variation(&"DefaultButton", &"Button")
	var fills: Dictionary = {"normal": STRONG, "hover": STRONG_HOVER, "pressed": STRONG_DOWN}
	for state: String in fills:
		var face := theme.get_stylebox(state, "Button").duplicate() as StyleBoxFlat
		face.bg_color = fills[state]
		face.set_border_width_all(0)
		theme.set_stylebox(state, &"DefaultButton", face)
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		theme.set_color(item, &"DefaultButton", Color(1, 1, 1))
	(Engine.get_main_loop() as SceneTree).node_added.connect(_default_marked)


## A question's default button marked as such, as the question is made.
static func _default_marked(node: Node) -> void:
	var asked := node as ConfirmationDialog
	if asked != null:
		asked.get_ok_button().theme_type_variation = &"DefaultButton"


## [param theme]'s [param item] of [param type] in the panels' face, with
## their edge and corners when [param edged]; once.
static func _face(theme: Theme, item: String, type: String, edged: bool) -> void:
	var engine := theme.get_stylebox(item, type) as StyleBoxFlat
	if engine == null or engine.has_meta(&"look"):
		return
	var face := engine.duplicate() as StyleBoxFlat
	face.bg_color = FACE
	face.border_color = EDGE
	face.set_border_width_all(1 if edged else 0)
	if edged:
		face.set_corner_radius_all(6)
	face.set_meta(&"look", true)
	theme.set_stylebox(item, type, face)


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
