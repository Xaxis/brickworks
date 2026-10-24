## Whether this is a phone, and how big a fingertip's point is here.
##
## A phone was the desktop shrunk: the window drawn about 720 units across
## (Main.screen_factor), so a 26-unit toolbar button came out 14 CSS pixels
## and a 17-unit colour swatch 9 (walk180, P1). The desktop's panels and
## dialogs still want those units, and keep them; what a finger touches is
## laid out in points instead, through [method px].
##
## Only where touch is the main input and the screen is narrow both ways
## round: a laptop with a touchscreen has a mouse beside it and keeps the
## desktop layout to the pixel, and a phone held sideways is still a phone.
##
## A tablet too (tablet247): it was given the desktop driven by fingers,
## targets 24 to 37 points, tooltips that never come and nothing for a
## right click, and the desktop's toolbar alone at 44 points a button is
## wider than any tablet. So it gets this layout laid out wide ([method
## wide]): the parts down the left, the rest down the right, the model
## between them.
class_name Phone
extends RefCounted

## A screen narrower than this in its short direction, in points.
const NARROW := 600.0

## What Apple asks for, and what everyone else has settled near.
const TARGET := 44.0

## The smallest text a phone shows, in points.
const LEAST_TEXT := 12.0

## A short side from NARROW up to this is a tablet's: an iPad mini's 744
## to an iPad Pro's 1032, Android's 800. Past it, the desktop.
const TABLET := 1100.0

static var _on: int = -1
static var _wide: bool = false
static var _keys: RegEx


## Whether the phone layout is wanted: decided once, at start.
static func on() -> bool:
	if _on == -1:
		_on = 1 if _wanted() else 0
	return _on == 1


## Whether it is laid out wide, for a tablet: decided with [method on].
static func wide() -> bool:
	return on() and _wide


## The content scale for a tablet this many points across and down: 720
## units across its short side whichever way round it is held, as a
## portrait one has (Main.screen_factor), so a point is as many units
## turned as it was, and what was laid out in points stays in points.
static func tablet_factor(across: float, down: float) -> float:
	var stretched: float = minf(across / 1600.0, down / 900.0)
	return clampf(minf(across, down) / 720.0 / stretched, 1.0, 3.0)


static func _wanted() -> bool:
	if not OS.has_feature("web") or not DisplayServer.is_touchscreen_available():
		return false
	# The main pointer coarse and no fine one: a finger, with no mouse.
	var coarse: Variant = JavaScriptBridge.eval(
		"matchMedia('(pointer: coarse)').matches && !matchMedia('(any-pointer: fine)').matches", true)
	if not bool(coarse):
		return false
	var short: float = minf(Room.across(), Room.down())
	_wide = short >= NARROW
	return short < TABLET


## Interface units to the point now: the window's width in units over its
## width in points.
static func per_point(viewport: Viewport) -> float:
	var across: float = Room.across()
	if across <= 0.0:
		return 1.0
	return viewport.get_visible_rect().size.x / across


## [param points] in the interface's units.
static func px(viewport: Viewport, points: float) -> float:
	return points * per_point(viewport)


## The desktop's words for a mouse and keys said for a finger.
static func touch_words(text: String) -> String:
	var out: String = text
	# A tail of keys to press, where there are none ("1 selected — Ctrl-C
	# copies, X moves..."): what it says before them.
	if _keys == null:
		_keys = RegEx.create_from_string("\\b(Ctrl|Cmd|Alt|Shift|Esc|Enter|Space|Tab)\\b|(^|[ ,(])[A-Z]([ ,)]|$)")
	var dash: int = out.find(" — ")
	if dash != -1 and _keys.search(out.substr(dash + 3)) != null:
		out = out.substr(0, dash)
	for pair: Array in [["Right-click", "Hold"], ["right-click", "hold"], ["right click", "hold"],
			["Double-click", "Double-tap"], ["double-click", "double-tap"],
			["Shift-click", "Tap"], ["Shift-drag", "Two fingers"], ["Ctrl-drag", "Drag"],
			["Click", "Tap"], ["click", "tap"], ["the pointer", "your finger"],
			[" — Esc when done", ""], ["Esc or a hold lets go", "Select lets go"]]:
		out = out.replace(str(pair[0]), str(pair[1]))
	return out
