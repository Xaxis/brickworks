## Whether this is a phone, and how big a fingertip's point is here.
##
## A phone was the desktop shrunk: the window drawn about 720 units across
## (Main.screen_factor), so a 26-unit toolbar button came out 14 CSS pixels
## and a 17-unit colour swatch 9 (walk180, P1). The desktop's panels and
## dialogs still want those units, and keep them; what a finger touches is
## laid out in points instead, through [method px].
##
## Where touch is the main input and the screen is narrow both ways round:
## a laptop with a touchscreen has a mouse beside it and keeps the desktop
## layout to the pixel, and a phone held sideways is still a phone.
##
## And in any browser window a phone's size, whatever points at it. The
## desktop's frame needs about 720 units across and 620 down: in 390 x 844
## points that is 0.54 of a pixel to the unit, so the mark was 9 x 15
## pixels, a toolbar button 16 and the words 6 (phone, 2026-10-30); in
## 844 x 390 it had 480 units down, and Settings and the assistant's rail
## ran off the foot. No pointer makes those readable, and this layout's
## points work for a mouse as for a finger.
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

## A window's long side under this, its short one under NARROW, is a
## phone's whatever points at it: the largest phone is 430 x 932. A laptop's
## browser 1280 x 590 (1080p at 150%) keeps the desktop.
const PHONE_LONG := 1000.0

## A short side from NARROW up to this is a tablet's: an iPad mini's 744
## to an iPad Pro's 1032, Android's 800. Past it, the desktop.
const TABLET := 1100.0

static var _on: int = -1
static var _wide: bool = false
static var _keys: RegEx
## A mouse's words, whole, with their endings: made at the class's load,
## read by the drawn words from any thread (finger_words).
static var _clicks: RegEx = RegEx.create_from_string(
	"(?i)\\b(right[- ]click|double[- ]click|shift[- ]click|click)(s|ed|ing)?\\b")
## The translation that says every English line drawn for a finger, once
## it is in (speak_to_a_finger).
static var _finger: TouchWords = null


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
	if not OS.has_feature("web"):
		return false
	var short: float = minf(Room.across(), Room.down())
	if short < NARROW and maxf(Room.across(), Room.down()) < PHONE_LONG:
		return true
	if not DisplayServer.is_touchscreen_available():
		return false
	# The main pointer coarse and no fine one: a finger, with no mouse.
	var coarse: Variant = JavaScriptBridge.eval(
		"matchMedia('(pointer: coarse)').matches && !matchMedia('(any-pointer: fine)').matches", true)
	if not bool(coarse):
		return false
	_wide = short >= NARROW
	return short < TABLET


## Interface units to the point now: the window's width in units over its
## width in points, and Settings, Interface size on top. A phone's controls
## are laid out in points, so without it they kept their size whatever the
## choice: the window's scale grew, and their units shrank to match.
static func per_point(viewport: Viewport) -> float:
	var across: float = Room.across()
	if across <= 0.0:
		return 1.0
	return viewport.get_visible_rect().size.x / across * ShellPrefs.interface_size()


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
	return finger_words(out)


## A mouse's words said for a finger, the rest as it is: a click is a tap,
## clicked tapped (not "taped", as "Driver: Earth, clicked" came out), a
## right click a hold, a Shift-drag two fingers, the pointer your finger.
## [method touch_words] for a line said at the moment, which drops its
## keys too; this for every line drawn (TouchWords).
static func finger_words(text: String) -> String:
	if text.is_empty():
		return text
	var out: String = ""
	var at: int = 0
	for found: RegExMatch in _clicks.search_all(text):
		# A name, not a word for a mouse: a capital one goes only before a
		# word in small letters ("Click an axle"), not in a part's or a
		# set's name ("Hinge Plate with Click Hinge", "Click & Build
		# Watch", "We Just Click", "THREE CLICKS").
		var word: String = found.get_string(1)
		if word.left(1) != word.left(1).to_lower():
			var next: String = text.substr(found.get_end(), 2)
			if next.length() < 2 or next[0] != " " or next[1] == next[1].to_upper():
				continue
		var mouse: String = word.to_lower()
		var ending: String = found.get_string(2)
		var finger: String = "hold" if mouse.begins_with("right") \
			else "double-tap" if mouse.begins_with("double") else "tap"
		if finger == "hold":
			finger = {"s": "holds", "ed": "held", "ing": "holding"}.get(ending, "hold")
		elif not ending.is_empty():
			finger += {"s": "s", "ed": "ped", "ing": "ping"}[ending]
		if word.left(1) != word.left(1).to_lower():
			finger = finger.left(1).to_upper() + finger.substr(1)
		out += text.substr(at, found.get_start() - at) + finger
		at = found.get_end()
	out += text.substr(at)
	for pair: Array in [["Shift-drag", "Two fingers"], ["Ctrl-drag", "Drag"],
			["the pointer", "your finger"], [" — Esc when done", ""],
			["Esc or a hold lets go", "Select lets go"]]:
		out = out.replace(str(pair[0]), str(pair[1]))
	return out


## Every English line the window draws said for a finger from now on: a
## panel's own status and hint lines (Simulate's "Click an axle or a crank
## to drive that instead"), a dialog's, a tooltip's, as the bar's line over
## the model already was (PhoneShell.say). Godot draws a control's words
## through the TranslationServer, as a language's are (Language), so one
## translation for English says them all, the next line written included.
## A probe or a browser check reading a control's text still reads its
## English as it was written. Another language's words are its own.
static func speak_to_a_finger() -> void:
	if _finger != null:
		return
	_finger = TouchWords.new()
	_finger.locale = "en"
	TranslationServer.add_translation(_finger)


## What [param text] is drawn as for a finger: for a check of the words.
static func drawn(text: String) -> String:
	return String(TranslationServer.translate(text)) if _finger != null else text


class TouchWords extends Translation:
	var _found: Dictionary = {}
	var _lock := Mutex.new()

	func _get_message(src_message: StringName, context: StringName) -> StringName:
		if not String(context).is_empty():
			return &""
		var text: String = String(src_message)
		_lock.lock()
		var known: Variant = _found.get(text)
		_lock.unlock()
		if known == null:
			var said: String = Phone.finger_words(text)
			known = said if said != text else ""
			_lock.lock()
			if _found.size() > 20000:
				_found.clear()
			_found[text] = known
			_lock.unlock()
		return StringName(known)
