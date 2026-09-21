## How the view is driven, for the hands that disagree about it.
##
## Two settings, not a binding editor. A full editor is a lot of screen
## and a lot of ways to end up with no working controls at all; these
## are the two things people actually arrive with an opinion about,
## because they are the two that differ between the tools they already
## use.
##
## Kept on this machine rather than on the account: which way a wheel
## should go is a fact about the mouse in front of you, and somebody who
## sets it on a trackpad laptop does not want it applied to their desk.
class_name ViewPrefs
extends RefCounted

const WHERE := "user://controls.cfg"

## Which way the wheel goes. Off means scrolling away from you moves
## you in, which is what a mouse does everywhere. Trackpad users who
## have turned on natural scrolling often want the other one, and the
## macOS setting is invisible from in here.
static var invert_zoom: bool = false

## Whether the middle button slides instead of turning.
##
## The one binding the CAD tools genuinely disagree on. Fusion and
## Onshape slide with it; Blender and SolidWorks turn with it. Shift
## always does the other, so both gestures stay reachable either way.
static var middle_slides: bool = false

static var _loaded: bool = false


static func load_them() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(WHERE) != OK:
		return
	invert_zoom = bool(file.get_value("view", "invert_zoom", false))
	middle_slides = bool(file.get_value("view", "middle_slides", false))


static func keep() -> void:
	var file := ConfigFile.new()
	file.set_value("view", "invert_zoom", invert_zoom)
	file.set_value("view", "middle_slides", middle_slides)
	file.save(WHERE)


## What the middle button does, in words, so the hint cannot disagree
## with the handler.
static func middle_verb() -> String:
	return "slide" if middle_slides else "turn"
