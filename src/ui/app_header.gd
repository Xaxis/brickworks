## The header every mode of the app has, as the site's (web/site.css
## .site-head, docs/DESIGN_SYSTEM.md "The shell"): the mark and the name at
## the left, the app's menu and your account at the right, 60 points tall
## over a line of one, on the site's own ground. The studio's menu bar
## (ModelBar) is it on a desktop's width, its menus and the model's name
## inside it; a phone's top bar (PhoneShell) is it laid out for a finger.
##
## The owner, 2026-11-23: "when a user clicks Build it it opens the view of
## the app that doesnt have the brickworks logo in the header, which it seems
## obvious that you should build a cohesive consistent view in that regard
## when using the app, right? Same for when user closes the instruction
## manual view." Build it's step player and the viewer drew bars of their
## own, the viewer's with the word Brickworks and no mark, the step player's
## with neither. Now the header stays where it is in every mode — the
## studio, a shared model's viewer, Build it's step player, the booklet's
## page laid out by hand — and what a mode adds goes under it (ShareView's
## bar, BuildMode's top bar, the PageEditor), never in its place.
##
## On the web the mark and the name are the way home, as the site's are: the
## site's home page in this tab (a model not yet written to the browser's
## storage holds the page, src/boot/shell.html's beforeunload). The app's own
## menu is then Menu at the right, beside Account, where the site's phone
## header has its Menu. A desktop app has no home page, and its mark opens
## the app's menu, as a desktop CAD program's logo does.
##
## Sized in points (the browser's CSS pixels, a desktop's screen points), not
## the interface's units, so it is the site's 60 + 1 whatever the window's
## content scale: 66 units at a laptop's 1280 x 800, 113 on a phone.
##
## No class_name: preloaded where it is used (ModelBar, PhoneShell), as
## PressHold is, so the class list a checkout was imported with stays its own.
extends RefCounted

## Points: the site's .bar min-height and its border-bottom.
const TALL := 60.0
const LINE := 1.0
## The mark (.chip) and the name beside it (.mark, --t-h3), in points.
const MARK := 26.0
const WORD := 18.0
## A control in it: a finger's, the site's --control-h.
const TARGET := 44.0
## The gaps: the site's 16 px gutter on a phone, 24 on a wider page.
const GUTTER_NARROW := 16.0
const GUTTER := 24.0
## The site's --bg (#0b0c0e), the bar's own ground there, and --line.
const GROUND := Color(0.0431, 0.0471, 0.0549, 0.98)
const EDGE := Color(1, 1, 1, 0.08)
## --ink and --ink-soft.
const INK := Color(0.953, 0.957, 0.965)
const INK_SOFT := Color(0.706, 0.725, 0.761)

## Whether the mark goes home and the menu is Menu at the right: in a
## browser. A probe sets it to lay the web's header out on the desktop.
static var web_layout: bool = OS.has_feature("web")


## Interface units to a point in [param control]'s window, times Settings,
## Interface size, as a phone's bars are (Phone.per_point): the interface is
## scaled to the window, the site's header is in points, and a person who
## asked for a bigger interface gets a bigger header too.
static func points(control: Control) -> float:
	var across: float = Room.across()
	if control == null or not control.is_inside_tree() or across <= 0.0:
		return 1.0
	return control.get_viewport().get_visible_rect().size.x / across * ShellPrefs.interface_size()


## The header's ground: the site's, a line along its foot, and its height
## made up by the margins round a [param inside] units tall row.
static func ground(pt: float, inside: float, gutter: float) -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color = GROUND
	face.border_color = EDGE
	face.border_width_bottom = maxi(1, roundi(LINE * pt))
	face.content_margin_left = gutter * pt
	face.content_margin_right = gutter * pt
	var room: float = maxf(0.0, TALL * pt - inside)
	face.content_margin_top = floorf(room / 2.0)
	face.content_margin_bottom = ceilf(room / 2.0)
	return face


## The name's type, the site's weight of it (700) on the app's own face.
static func word_font(control: Control) -> Font:
	var bold := FontVariation.new()
	bold.base_font = control.get_theme_default_font() if control != null else ThemeDB.fallback_font
	bold.variation_embolden = 0.7
	bold.spacing_glyph = -1
	return bold


## [param button] dressed as the mark: the cube at the site's size and the
## name beside it, white, its face only a focus ring.
static func dress_mark(button: Button, pt: float) -> void:
	button.add_theme_font_override("font", word_font(button))
	button.add_theme_font_size_override("font_size", roundi(WORD * pt))
	for colour: String in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color"]:
		button.add_theme_color_override(colour, INK)
	button.add_theme_constant_override("h_separation", roundi(10.0 * pt))
	button.custom_minimum_size = Vector2(TARGET * pt, TARGET * pt)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var face := StyleBoxEmpty.new()
	face.content_margin_left = 4.0 * pt
	face.content_margin_right = 4.0 * pt
	for state: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		button.add_theme_stylebox_override(state, face)
	button.add_theme_stylebox_override("focus", FocusGuard.ring())


## [param button] as the site's header has its buttons (Menu, Sign in): a
## finger's height, the panel's ground and a line round it.
static func dress_button(button: Button, pt: float) -> void:
	button.add_theme_font_size_override("font_size", roundi(15.0 * pt))
	for colour: String in ["font_color", "font_focus_color"]:
		button.add_theme_color_override(colour, INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.custom_minimum_size = Vector2(0.0, TARGET * pt)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# A MenuButton is flat unless told: Menu drew as bare words beside
	# Account's button, with nothing to show a hover.
	button.flat = false
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = {"normal": Color(0.082, 0.090, 0.106), "hover": Color(0.110, 0.122, 0.141),
			"pressed": Color(0.110, 0.122, 0.141), "hover_pressed": Color(0.110, 0.122, 0.141)}[state]
		# The site's --line-strong: 16% white.
		face.border_color = Color(1, 1, 1, 0.16)
		face.set_border_width_all(maxi(1, roundi(pt)))
		face.set_corner_radius_all(roundi(10.0 * pt))
		face.content_margin_left = 14.0 * pt
		face.content_margin_right = 14.0 * pt
		button.add_theme_stylebox_override(state, face)


## The site's home page, in this tab, as the site's own mark goes there.
static func go_home() -> void:
	if Outside.held():
		Outside.opened.append("/")
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.assign('/')", true)
	else:
		Outside.open_link(Deployment.api_base() + "/")
