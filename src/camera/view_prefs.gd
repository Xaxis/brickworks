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

## How the view is driven, after the program a person already knows:
##
##   "studio"      BrickLink Studio, the default. Right-drag turns, the
##                 middle button and shift with the right slide, the wheel
##                 zooms to the pointer. Onshape and LDCad turn with the
##                 right button too.
##   "blender"     The middle button turns and shift with it slides.
##   "mecabricks"  A left drag on empty space turns, the right button
##                 slides and the middle button zooms.
##
## The left button acts on the model in all three: select, move, place.
## Only Mecabricks takes it for looking, and only on empty space.
const PRESETS: Array[String] = ["studio", "blender", "mecabricks"]
static var preset: String = "studio"

## Whether the middle button slides instead of turning: the preset's
## answer, kept as a variable for what already reads it.
static var middle_slides: bool = true

static var _loaded: bool = false


static func load_them() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(WHERE) != OK:
		use(preset)
		return
	invert_zoom = bool(file.get_value("view", "invert_zoom", false))
	var kept: String = str(file.get_value("view", "preset", "studio"))
	use(kept if PRESETS.has(kept) else "studio")


## Drive the view the way a preset says.
static func use(name: String) -> void:
	preset = name if PRESETS.has(name) else "studio"
	middle_slides = preset == "studio"


## Kept on this machine. Not by a probe, which would change the person's
## own settings by checking them.
static func keep() -> void:
	if OS.get_cmdline_args().has("--script"):
		return
	var file := ConfigFile.new()
	file.set_value("view", "invert_zoom", invert_zoom)
	file.set_value("view", "preset", preset)
	file.save(WHERE)


## What a drag with each button does: "turn", "slide", "zoom", or "" for
## the left button where it acts on the model. Shift gives the other of
## turning and sliding.
static func drag_verb(button: int, shift: bool = false) -> String:
	var verb: String = ""
	match button:
		MOUSE_BUTTON_RIGHT:
			verb = "slide" if preset == "mecabricks" else "turn"
		MOUSE_BUTTON_MIDDLE:
			verb = {"studio": "slide", "blender": "turn", "mecabricks": "zoom"}[preset]
		MOUSE_BUTTON_LEFT:
			verb = "turn" if preset == "mecabricks" else ""
	if shift and verb == "turn":
		return "slide"
	if shift and (verb == "slide" or verb == "zoom"):
		return "turn"
	return verb


## What the middle button does, in words, so the hint cannot disagree
## with the handler.
static func middle_verb() -> String:
	return drag_verb(MOUSE_BUTTON_MIDDLE)


## The preset's name as a person reads it.
static func preset_name(name: String) -> String:
	return {"studio": "Studio", "blender": "Blender", "mecabricks": "Mecabricks"}.get(name, name)
