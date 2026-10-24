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
class_name Phone
extends RefCounted

## A screen narrower than this in its short direction, in points.
const NARROW := 600.0

## What Apple asks for, and what everyone else has settled near.
const TARGET := 44.0

## The smallest text a phone shows, in points.
const LEAST_TEXT := 12.0

static var _on: int = -1


## Whether the phone layout is wanted: decided once, at start.
static func on() -> bool:
	if _on == -1:
		_on = 1 if _wanted() else 0
	return _on == 1


static func _wanted() -> bool:
	if not OS.has_feature("web") or not DisplayServer.is_touchscreen_available():
		return false
	# The main pointer coarse and no fine one: a finger, with no mouse.
	var coarse: Variant = JavaScriptBridge.eval(
		"matchMedia('(pointer: coarse)').matches && !matchMedia('(any-pointer: fine)').matches", true)
	if not bool(coarse):
		return false
	return minf(Room.across(), Room.down()) < NARROW


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
	for pair: Array in [["Right-click", "Hold"], ["right-click", "hold"], ["right click", "hold"],
			["Double-click", "Double-tap"], ["double-click", "double-tap"],
			["Shift-click", "Tap"], ["Shift-drag", "Two fingers"], ["Ctrl-drag", "Drag"],
			["Click", "Tap"], ["click", "tap"], ["the pointer", "your finger"],
			[" — Esc when done", ""], ["Esc or a hold lets go", "Select lets go"]]:
		out = out.replace(str(pair[0]), str(pair[1]))
	return out
