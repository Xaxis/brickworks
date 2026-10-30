## A number typed while something is in hand, or straight after R or T: a
## move, a turn or a tilt by exactly that much, shown in hand as it is
## typed, and put down with Enter as one step to undo. Blender's G, X, 12;
## SketchUp's distance typed during a move; Onshape's typed triad value;
## Figma's sums in a field (docs/APP_UX.md, B1). A place the pointer cannot
## say was typed into Properties, about 25 actions a part.
##
## This is the field and what it reads. What is moved, and how, is its
## owner's ([member preview], [member apply], [member cancel], set by
## EditVerbs), so a later tool that wants a typed number (Connect's slide
## along its joint, a handle's drag) gives the field its own three.
##
## The states, and what moves between them:
##
##   closed  --a digit, "." or "-" while [member may_open] says yes-->  open
##   open    --a key that edits the text-->  open, read again, shown
##   open    --Enter, and it has room-->  closed: put down (apply)
##   open    --Enter, and no room, or the text says nothing-->  open, red
##   open    --Esc, or Backspace with nothing left-->  closed: as it was (cancel)
##   open    --what was in hand let go of (a right click, a tool)-->  closed
##
## It sees every key before the interface and the model do. While open it
## takes them all, so a digit is never a view and a "-" never a zoom; while
## closed, only the one that opens it, and none while a text box has the
## keys. Only the keys' characters are read, which a browser gives as the
## desktop does: nothing here asks the system for anything.
##
## What is read ([method parse]): terms, each an axis or a verb, a number
## and a unit, in either order, with or without spaces between:
##   "12"            12 studs the way the ghost last went;
##   "3x", "x 3"     3 studs along x;  "z -2" back 2;
##   "y 3p", "2b y"  up 3 plates, 2 bricks;  "y 7l", "y 7 ldu", "5mm"  exact;
##   "r 23.58"       a turn in degrees, about the joint or the upright;
##   "t 30"          a tilt in degrees, forwards as the view looks;
##   "x 40/2+1"      sums, as Figma's fields take;
##   "x2 y-1p"       several at once.
## A number alone after R is a turn, after T a tilt, and takes the place of
## R's or T's own step.
class_name TypedEntry
extends PanelContainer

## Whether a key may open the field now: something in hand, or R or T
## just pressed. Its owner makes ready to be moved as it says yes.
var may_open: Callable = func() -> bool: return false
## What a number alone is as the field opens ([member verb]), and the way
## a move alone goes ([member way]).
var opened_as: Callable = func() -> String: return "move"
var going: Callable = func() -> Vector3: return Vector3.ZERO
## Show what was typed in hand: given [method parse]'s answer, returns ""
## when it has room, or in words why not.
var preview: Callable = func(_typed: Dictionary) -> String: return ""
## Do it, the field closing: true when it was done.
var apply: Callable = func(_typed: Dictionary) -> bool: return false
## Leave it as it was before anything was typed.
var cancel: Callable = func() -> void: pass
## Whether what the field moves is still in hand; the field closes when not.
var still_held: Callable = func() -> bool: return true
## Where what is in hand stands on the screen, which the field opens
## under (or over) rather than on: an empty rect for anywhere.
var clear_of: Callable = func() -> Rect2: return Rect2()

## What a number alone is: "move", "turn" (after R) or "tilt" (after T).
var verb: String = "move"
## The way a move alone goes (Builder.last_way), a unit vector or zero.
var way: Vector3 = Vector3.ZERO
## What has been typed.
var text: String = ""
## What it was last read as.
var typed: Dictionary = {}

## A length's unit, in LDU: a stud by default, on every axis.
const LENGTHS: Dictionary = {"": 20.0, "s": 20.0, "stud": 20.0, "studs": 20.0,
	"p": 8.0, "plate": 8.0, "plates": 8.0, "b": 24.0, "brick": 24.0, "bricks": 24.0,
	"l": 1.0, "ldu": 1.0, "mm": 2.5}
const ANGLES: Dictionary = {"": 1.0, "d": 1.0, "deg": 1.0, "°": 1.0}
const AXES: Array[String] = ["x", "y", "z"]
## The red of a refusal, at least 4.5:1 on the field's face.
const REFUSED := Color(1.0, 0.5, 0.47)
const SAID := Color(0.78, 0.8, 0.84)

var _shown: Label
var _meaning: Label


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := StyleBoxFlat.new()
	face.bg_color = Look.FACE
	face.border_color = Look.EDGE
	face.set_border_width_all(1)
	face.set_corner_radius_all(4)
	face.content_margin_left = 8
	face.content_margin_right = 8
	face.content_margin_top = 4
	face.content_margin_bottom = 5
	add_theme_stylebox_override("panel", face)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	_shown = Label.new()
	_shown.name = "Typed"
	_shown.add_theme_font_size_override("font_size", 16)
	row.add_child(_shown)
	# The caret drawn, not a character: the web build's font has no "▏",
	# and showed a box for it.
	var caret := ColorRect.new()
	caret.name = "Caret"
	caret.color = SAID
	caret.custom_minimum_size = Vector2(2, 18)
	caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caret)
	_meaning = Label.new()
	_meaning.name = "Meaning"
	_meaning.add_theme_font_size_override("font_size", 12)
	column.add_child(_meaning)
	accessibility_name = "Typed move"


func is_open() -> bool:
	return visible


## Open on this key if it is a digit, "." or "-", no text box has the keys
## and [member may_open] says so. True when it opened (the key is the
## field's first character).
func try_open(key: InputEventKey) -> bool:
	if visible or not key.pressed or key.echo or key.ctrl_pressed or key.meta_pressed \
			or key.alt_pressed:
		return false
	var c: String = _character(key)
	if c.is_empty() or not (c.is_valid_int() or c == "." or c == "-"):
		return false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return false
	verb = str(opened_as.call())
	if not bool(may_open.call()):
		return false
	way = going.call()
	text = c
	visible = true
	_place_near(get_viewport().get_mouse_position())
	_read()
	return true


## Close without doing anything more: what was in hand is let go of, or
## was put down by a click (EditVerbs).
func close() -> void:
	visible = false
	text = ""
	typed = {}


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null:
		return
	if not visible:
		if try_open(key):
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if not key.pressed:
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_submit()
			return
		KEY_ESCAPE:
			close()
			cancel.call()
			return
		KEY_BACKSPACE:
			if text.is_empty():
				close()
				cancel.call()
				return
			text = text.substr(0, text.length() - 1)
			_read()
			return
	var c: String = _character(key)
	if not c.is_empty() and _takes(c):
		text += c
		_read()


func _process(_delta: float) -> void:
	if visible and not bool(still_held.call()):
		close()


func _submit() -> void:
	if typed.is_empty() or not str(typed.get("error", "")).is_empty():
		_say(str(typed.get("error", "type a number")) if not typed.is_empty()
			else "type a number", true)
		return
	var refused: String = preview.call(typed)
	if not refused.is_empty():
		_say(refused, true)
		return
	var done: Dictionary = typed
	close()
	if not bool(apply.call(done)):
		cancel.call()


## Read the text again, show it in hand, and say what it does.
func _read() -> void:
	typed = parse(text, verb, way)
	_shown.text = text
	if not str(typed["error"]).is_empty():
		_say(str(typed["error"]), true)
		return
	if bool(typed["empty"]):
		_say(_hint(), false)
		return
	var refused: String = preview.call(typed)
	if refused.is_empty():
		_say("%s — Enter puts it down" % typed["words"], false)
	else:
		_say("%s — %s" % [typed["words"], refused], true)


func _say(words: String, red: bool) -> void:
	_meaning.text = words
	_meaning.add_theme_color_override("font_color", REFUSED if red else SAID)
	reset_size()


func _hint() -> String:
	match verb:
		"turn":
			return "degrees to turn it"
		"tilt":
			return "degrees to tilt it"
	return "studs, then x, y or z (p plates, b bricks, l LDU)"


## Beside the pointer, inside the window.
func _place_near(at: Vector2) -> void:
	reset_size()
	var room: Vector2 = get_viewport_rect().size
	var size_now: Vector2 = get_combined_minimum_size()
	var y: float = at.y + 18.0
	var keep: Rect2 = clear_of.call()
	if keep.has_area():
		# Under what is in hand, or over it where the window ends: the field
		# on the ghost hid what the number was moving.
		y = keep.end.y + 10.0
		if y + size_now.y > room.y - 8.0:
			y = keep.position.y - size_now.y - 10.0
	position = Vector2(clampf(at.x + 18.0, 0.0, maxf(room.x - size_now.x - 220.0, 0.0)),
		clampf(y, 0.0, maxf(room.y - size_now.y - 8.0, 0.0)))


static func _character(key: InputEventKey) -> String:
	if key.unicode > 31:
		return String.chr(key.unicode).to_lower()
	# The keypad's digits, where a key event carries no character.
	if key.keycode >= KEY_KP_0 and key.keycode <= KEY_KP_9:
		return str(key.keycode - KEY_KP_0)
	match key.keycode:
		KEY_KP_PERIOD: return "."
		KEY_KP_SUBTRACT: return "-"
		KEY_KP_ADD: return "+"
		KEY_KP_MULTIPLY: return "*"
		KEY_KP_DIVIDE: return "/"
	return ""


static func _takes(c: String) -> bool:
	return c.length() == 1 and ("0123456789.+-*/() ,°".contains(c) or (c >= "a" and c <= "z"))


# -- reading what was typed -------------------------------------------------


## What [param text] says, read whole: {move (LDU along the model's axes),
## turn and tilt (degrees), words (what it does, plainly), error ("" or
## what is wrong), empty (nothing yet)}. [param verb] is what a number
## alone is, and [param going] the way a move alone goes.
static func parse(text: String, verb: String = "move", going: Vector3 = Vector3.ZERO) -> Dictionary:
	var out: Dictionary = {"move": Vector3.ZERO, "turn": 0.0, "tilt": 0.0, "words": "",
		"error": "", "empty": true}
	var terms: Array = []
	var term: Dictionary = {}
	var s: String = text.to_lower()
	var n: int = 0
	while n < s.length():
		var c: String = s[n]
		if c == " " or c == ",":
			n += 1
			continue
		if c == "°" or (c >= "a" and c <= "z"):
			var word: String = ""
			while n < s.length() and (s[n] == "°" or (s[n] >= "a" and s[n] <= "z")):
				word += s[n]
				n += 1
			for piece: String in _words_in(word):
				if piece in ["x", "y", "z", "r", "t"]:
					# After a number with no axis yet, it is that number's.
					if term.has("value") and not term.has("axis"):
						term["axis"] = piece
					else:
						if term.has("value"):
							terms.append(term)
						term = {"axis": piece}
				elif LENGTHS.has(piece) or ANGLES.has(piece):
					if not term.has("value") or term.has("unit"):
						out["error"] = "a number before “%s”" % piece
						return out
					term["unit"] = piece
				else:
					out["error"] = "“%s” is not x, y, z, r, t or a unit" % word
					return out
			continue
		var sum: String = ""
		while n < s.length() and "0123456789.+-*/()".contains(s[n]):
			sum += s[n]
			n += 1
		if sum.is_empty():
			out["error"] = "“%s” is not a number" % c
			return out
		var value: Variant = _sum(sum)
		if value == null:
			# Still being typed ("3+", "-"): nothing yet, not wrong.
			if sum.right(1) in ["+", "-", "*", "/", "(", "."]:
				return out
			out["error"] = "“%s” is not a number" % sum
			return out
		if term.has("value"):
			terms.append(term)
			term = {}
		term["value"] = float(value)
	if term.has("value"):
		terms.append(term)
	elif not term.is_empty():
		# An axis with nothing after it yet.
		return out
	var words := PackedStringArray()
	for each: Dictionary in terms:
		var axis: String = str(each.get("axis", ""))
		var unit: String = str(each.get("unit", ""))
		var value: float = float(each["value"])
		var kind: String = "move" if axis in AXES else ("turn" if axis == "r"
			else ("tilt" if axis == "t" else verb))
		if kind == "move":
			if not LENGTHS.has(unit):
				out["error"] = "“%s” is not a length" % unit
				return out
			var along: Vector3 = Vector3.ZERO
			if axis in AXES:
				along[AXES.find(axis)] = 1.0
			elif going != Vector3.ZERO:
				along = going
			else:
				out["error"] = "which way? add x, y or z"
				return out
			out["move"] = (out["move"] as Vector3) + along * value * float(LENGTHS[unit])
		else:
			if not ANGLES.has(unit):
				out["error"] = "a %s is in degrees" % kind
				return out
			out[kind] = float(out[kind]) + value
	var move: Vector3 = out["move"]
	for i: int in 3:
		if not is_zero_approx(move[i]):
			words.append("%s %s" % [AXES[i], _length_words(move[i], i == 1)])
	if not is_zero_approx(float(out["turn"])):
		words.append("turn %s°" % _num(float(out["turn"]), true))
	if not is_zero_approx(float(out["tilt"])):
		words.append("tilt %s°" % _num(float(out["tilt"]), true))
	out["empty"] = terms.is_empty()
	out["words"] = ", ".join(words) if not words.is_empty() else "nothing"
	return out


## A run of letters as the words it holds: "x", "ldu", or a unit and an
## axis run together ("py": "p", "y"), or an axis and a unit ("yp").
static func _words_in(word: String) -> PackedStringArray:
	if word in ["x", "y", "z", "r", "t"] or LENGTHS.has(word) or ANGLES.has(word):
		return PackedStringArray([word])
	var last: String = word.right(1)
	if last in ["x", "y", "z", "r", "t"] and LENGTHS.has(word.left(-1)):
		return PackedStringArray([word.left(-1), last])
	var first: String = word.left(1)
	if first in ["x", "y", "z", "r", "t"] and (LENGTHS.has(word.substr(1)) or ANGLES.has(word.substr(1))):
		return PackedStringArray([first, word.substr(1)])
	return PackedStringArray([word])


## A move along an axis, in the words a builder uses: whole studs, whole
## plates (up and down) or LDU.
static func _length_words(ldu: float, upright: bool) -> String:
	if is_equal_approx(fposmod(ldu, 20.0), 0.0) or is_equal_approx(fposmod(ldu, 20.0), 20.0):
		var studs: int = roundi(ldu / 20.0)
		if not upright or posmod(studs * 20, 8) != 0:
			return "%+d stud%s" % [studs, "" if absi(studs) == 1 else "s"]
	if upright and (is_equal_approx(fposmod(ldu, 8.0), 0.0) or is_equal_approx(fposmod(ldu, 8.0), 8.0)):
		var plates: int = roundi(ldu / 8.0)
		return "%+d plate%s" % [plates, "" if absi(plates) == 1 else "s"]
	return "%s LDU" % _num(ldu, true)


static func _num(value: float, signed: bool) -> String:
	var shown: String = String.num(snappedf(value, 0.001), 3)
	return ("+" + shown) if signed and value > 0.0 else shown


## A sum of numbers: + - * / and brackets, as a field in Figma takes. Null
## when it is not one. Only these are read: nothing typed is run as code.
static func _sum(text: String) -> Variant:
	var reader := _Sum.new(text)
	var value: Variant = reader.expression()
	if value == null or reader.at != text.length():
		return null
	return value


class _Sum extends RefCounted:
	var text: String
	var at: int = 0

	func _init(what: String) -> void:
		text = what

	func expression() -> Variant:
		var total: Variant = term()
		while total != null and at < text.length() and text[at] in ["+", "-"]:
			var sign: String = text[at]
			at += 1
			var next: Variant = term()
			if next == null:
				return null
			total = float(total) + float(next) if sign == "+" else float(total) - float(next)
		return total

	func term() -> Variant:
		var total: Variant = factor()
		while total != null and at < text.length() and text[at] in ["*", "/"]:
			var sign: String = text[at]
			at += 1
			var next: Variant = factor()
			if next == null or (sign == "/" and is_zero_approx(float(next))):
				return null
			total = float(total) * float(next) if sign == "*" else float(total) / float(next)
		return total

	func factor() -> Variant:
		if at >= text.length():
			return null
		if text[at] in ["+", "-"]:
			var sign: String = text[at]
			at += 1
			var inner: Variant = factor()
			return null if inner == null else (float(inner) if sign == "+" else -float(inner))
		if text[at] == "(":
			at += 1
			var inside: Variant = expression()
			if inside == null or at >= text.length() or text[at] != ")":
				return null
			at += 1
			return inside
		var digits: String = ""
		while at < text.length() and ("0123456789.".contains(text[at])):
			digits += text[at]
			at += 1
		if digits.is_empty() or digits == "." or digits.count(".") > 1:
			return null
		return digits.to_float()
