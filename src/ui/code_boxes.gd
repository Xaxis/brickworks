## The code from the email typed one digit to a box (signinux, 2026-11-13),
## as every site that emails a one-time code asks for it, and as the site's
## own sign-in does (web/code-boxes.js): a row of boxes, centred, each
## sized for a thumb, a wider gap at the middle of a long code (four and
## four for the deployment's eight digits).
##
## A digit typed fills its box and moves on, the next box's digit selected
## so a digit typed replaces it; Backspace empties a box, or on an empty one
## steps back and empties that; Left and Right move; anything but a digit is
## refused. A paste anywhere in the row (Ctrl or Cmd+V), and anything that
## arrives in one box at once (a password manager's fill, the browser's or
## the phone's paste), are read by the site's rule ([method read_code]): a
## whole code is laid from the first box and sent; anything else is laid
## and waits. The number keys on a phone's keyboard. [signal filled] for the
## last digit in, the one that fills the row or one typed into its last box
## (sent again after a limit kept the digits): the form signs in then, with
## nobody having to look for the button. A digit changed in the middle of a
## full row waits for the rest of the change.
##
## Its own layout rather than an HBoxContainer: the boxes narrow to fit a
## phone's card (down to [constant NARROW]) instead of pushing it wider, and
## the shake that says a code was refused moves the row whatever re-lays it.
class_name CodeBoxes
extends Container

## Every box filled: [param code] is its digits.
signal filled(code: String)
## Return pressed in a box.
signal submitted

## A box's widest and narrowest, and its height: a thumb's.
const WIDE := 44.0
const NARROW := 30.0
const TALL := 48.0
const GAP := 6.0
## Between the halves of a long code.
const MIDDLE := 16.0

var _boxes: Array[LineEdit] = []
## Each box's digit as this last left it, for a fill to be told from it.
var _held: PackedStringArray = []
var _editable: bool = true
## Set while this sets a box's text, so its text_changed is not taken for
## somebody's typing.
var _setting: bool = false
## Where the shake has the row, across its centre.
var shake_offset: float = 0.0:
	set(value):
		shake_offset = value
		queue_sort()
var _shaking: Tween


func _init() -> void:
	setup(8)


## A row of [param count] boxes, empty.
func setup(count: int) -> void:
	count = clampi(count, 4, 12)
	if count == _boxes.size():
		clear()
		return
	for box: LineEdit in _boxes:
		box.queue_free()
	_boxes.clear()
	for at: int in count:
		var box := LineEdit.new()
		box.alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_theme_font_size_override("font_size", 22)
		# As narrow as the row lays it: a LineEdit is four "M"s wide by
		# itself, 92 px at this size, and eight of them ran off the card.
		box.add_theme_constant_override("minimum_character_width", 0)
		# Each box drawn whole, as a box: the engine's field is a faint fill
		# that an empty row all but vanished into on the card.
		box.add_theme_stylebox_override("normal", _face(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.3), 1, true))
		box.add_theme_stylebox_override("read_only", _face(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.16), 1, true))
		box.add_theme_stylebox_override("focus", _face(Color(0, 0, 0, 0), Look.ACCENT, 2, false))
		box.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		box.select_all_on_focus = true
		box.keep_editing_on_text_submit = true
		box.caret_blink = true
		# Said as which digit it is: its neighbours look the same.
		box.accessibility_name = "Digit %d of %d" % [at + 1, count]
		box.gui_input.connect(_key.bind(at))
		box.text_changed.connect(_typed.bind(at))
		box.text_submitted.connect(func(_t: String) -> void: submitted.emit())
		add_child(box)
		_boxes.append(box)
	_keep_held()
	update_minimum_size()
	queue_sort()


func count() -> int:
	return _boxes.size()


## The digits typed, in order, with nothing for a box still empty.
func code() -> String:
	var digits: String = ""
	for box: LineEdit in _boxes:
		digits += box.text
	return digits


func is_full() -> bool:
	return code().length() == _boxes.size()


func first_box() -> LineEdit:
	return _boxes[0]


func box(at: int) -> LineEdit:
	return _boxes[at]


## The box the keys are in, or -1.
func focused_at() -> int:
	for at: int in _boxes.size():
		if _boxes[at].has_focus():
			return at
	return -1


func clear() -> void:
	_setting = true
	for one: LineEdit in _boxes:
		one.text = ""
	_setting = false
	_keep_held()


## The keys in the first box, or with [param empty] the first empty one.
func focus_first(empty: bool = false) -> void:
	if not is_inside_tree() or _boxes.is_empty():
		return
	var at: int = 0
	if empty:
		at = mini(code().length(), _boxes.size() - 1)
	_focus(at)


func set_editable(on: bool) -> void:
	_editable = on
	for one: LineEdit in _boxes:
		one.editable = on


## The row named for a screen reader, as one group: "The code sent to …".
func set_label(words: String) -> void:
	accessibility_name = words
	for one: LineEdit in _boxes:
		one.accessibility_description = words


## [param text] pasted, read by [method read_code]: a whole code laid from
## the first box and sent ([signal filled]); anything else laid from the
## first box and not sent. The keys in the box after the last digit.
func paste(text: String) -> void:
	_lay(read_code(text, _boxes.size()), 0)


## The code in [param text] for a row of [param count] boxes, read as the
## site reads it (web/code-boxes.js readCode): {"code", "whole"}. A run of
## exactly [param count] digits, one space or dash allowed inside ("1234
## 5678", "1234-5678") and no other digit joined to it, is the code, whole:
## sent at once, the email's own words around it or not. Anything else (too
## few digits, too many, "123456789") is its first [param count] digits,
## laid for the person to look at, never sent by itself (sifix, 2026-11-15:
## a box's own paste sent the last eight of nine, Ctrl+V the first eight).
static func read_code(text: String, count: int) -> Dictionary:
	var runs := RegEx.create_from_string("[0-9]+(?:[ -][0-9]+)*")
	for found: RegExMatch in runs.search_all(text):
		var parts: PackedStringArray = found.get_string().replace("-", " ").split(" ")
		var joined: String = "".join(parts)
		if parts.size() <= 2 and joined.length() == count:
			return {"code": joined, "whole": true}
	return {"code": _digits(text).left(count), "whole": false}


## The gentle shake that says a code was refused: about a third of a
## second, side to side, settling where it was. Still under Settings,
## Reduce motion.
func shake() -> void:
	if _shaking != null and _shaking.is_valid():
		_shaking.kill()
	shake_offset = 0.0
	if ShellPrefs.reduce_motion() or not is_inside_tree():
		return
	_shaking = create_tween()
	for x: float in [-8.0, 7.0, -5.0, 3.0, 0.0]:
		_shaking.tween_property(self, "shake_offset", x, 0.06)


func _get_minimum_size() -> Vector2:
	var n: int = _boxes.size()
	return Vector2(n * NARROW + _gaps(n), TALL)


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var n: int = _boxes.size()
	if n == 0:
		return
	var wide: float = clampf(floorf((size.x - _gaps(n)) / n), NARROW, WIDE)
	var x: float = floorf((size.x - (wide * n + _gaps(n))) / 2.0) + shake_offset
	var half: int = floori(n / 2.0)
	for at: int in n:
		fit_child_in_rect(_boxes[at], Rect2(x, 0.0, wide, TALL))
		x += wide + (MIDDLE if at == half - 1 and _halves(n) else GAP)


func _gaps(n: int) -> float:
	if n < 2:
		return 0.0
	return GAP * (n - 1) + ((MIDDLE - GAP) if _halves(n) else 0.0)


## A long even code is read in halves, as the email prints it.
func _halves(n: int) -> bool:
	return n >= 6 and n % 2 == 0


## A box's face: [param fill], an edge [param width] px in [param edge],
## round corners; [param center] false for the focus ring drawn over it.
static func _face(fill: Color, edge: Color, width: int, center: bool) -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color = fill
	face.draw_center = center
	face.border_color = edge
	face.set_border_width_all(width)
	face.set_corner_radius_all(8)
	face.set_content_margin_all(2)
	return face


static func _digits(text: String) -> String:
	var digits: String = ""
	for c: String in text:
		if c >= "0" and c <= "9":
			digits += c
	return digits


func _focus(at: int) -> void:
	var one: LineEdit = _boxes[clampi(at, 0, _boxes.size() - 1)]
	if one.is_inside_tree():
		one.grab_focus()
	# Selected, so a digit typed replaces the one there.
	one.select_all()
	one.caret_column = one.text.length()


## [param digits] put one to a box from [param at] on, the keys after the
## last; with [param send], [signal filled] if every box has its digit.
func _fill_from(at: int, digits: String, send: bool) -> void:
	_setting = true
	var put: int = at
	for c: String in digits:
		if put >= _boxes.size():
			break
		_boxes[put].text = c
		put += 1
	_setting = false
	_keep_held()
	_focus(mini(put, _boxes.size() - 1))
	if send and _editable and is_full():
		filled.emit(code())


## A digit typed into box [param at]: the last digit in sends the code, the
## one that fills the row or one typed into its last box.
func _type_digit(at: int, digit: String) -> void:
	var was_full: bool = is_full()
	_fill_from(at, digit, not was_full or at == _boxes.size() - 1)


## A code read by [method read_code] laid in the boxes: a whole one from the
## first box and sent, even into a full row (a paste after a limit kept the
## digits is somebody sending it); anything else from [param at] (the first
## box when it is a row's worth), not sent.
func _lay(read: Dictionary, at: int) -> bool:
	var digits: String = read["code"]
	if digits.is_empty():
		return false
	var whole: bool = read["whole"]
	_fill_from(0 if whole or digits.length() >= _boxes.size() else at, digits, whole)
	return true


func _keep_held() -> void:
	_held.resize(_boxes.size())
	for at: int in _boxes.size():
		_held[at] = _boxes[at].text


## The keys, before the box's own handling of them (a Control's gui_input
## signal comes first, and accepting the event ends it there).
func _key(event: InputEvent, at: int) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var box: LineEdit = _boxes[at]
	var chord: bool = key.ctrl_pressed or key.meta_pressed or key.alt_pressed
	if key.is_action("ui_paste", true) or (chord and key.keycode == KEY_V):
		# Read here where the clipboard can be read at once; on the web the
		# box's own paste, which the browser hands it, fans out in _typed.
		if not OS.has_feature("web"):
			var pasted: String = DisplayServer.clipboard_get()
			if not _digits(pasted).is_empty():
				box.accept_event()
				if _editable:
					paste(pasted)
				return
		box.select_all()
		return
	if chord:
		return
	match key.keycode:
		KEY_BACKSPACE:
			box.accept_event()
			if not _editable:
				return
			if not box.text.is_empty():
				_set_box(at, "")
			elif at > 0:
				_set_box(at - 1, "")
				_focus(at - 1)
			return
		KEY_DELETE:
			box.accept_event()
			if _editable:
				_set_box(at, "")
			return
		KEY_LEFT:
			box.accept_event()
			_focus(at - 1)
			return
		KEY_RIGHT:
			box.accept_event()
			_focus(at + 1)
			return
		KEY_HOME:
			box.accept_event()
			_focus(0)
			return
		KEY_END:
			box.accept_event()
			_focus(_boxes.size() - 1)
			return
		KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_ESCAPE:
			# The box's own, and the window's: Return signs in, Tab moves on.
			return
	if key.unicode == 0:
		return
	# A character: a digit takes the box and moves on; anything else is
	# refused, here, before the box would show it.
	box.accept_event()
	if not _editable:
		return
	var c: String = char(key.unicode)
	if not (c >= "0" and c <= "9"):
		return
	_type_digit(at, c)


func _set_box(at: int, text: String) -> void:
	_setting = true
	_boxes[at].text = text
	_setting = false
	_keep_held()


## Whatever reached a box without passing _key (a paste, a fill, a phone's
## keyboard), read by the paste's rule: a whole code from the first box,
## sent; a few digits from here on; one digit as if typed. A fill put after
## the box's own digit ("5" then "12345678") is what came, not the nine.
func _typed(text: String, at: int) -> void:
	if _setting:
		return
	var was: String = _held[at] if at < _held.size() else ""
	var came: String = text
	if not was.is_empty() and text.length() > was.length():
		if text.begins_with(was):
			came = text.substr(was.length())
		elif text.ends_with(was):
			came = text.left(text.length() - was.length())
	var read: Dictionary = read_code(text, _boxes.size())
	if not read["whole"]:
		read = read_code(came, _boxes.size())
	var digits: String = read["code"]
	if read["whole"] or digits.length() > 1:
		_lay(read, at)
	elif not digits.is_empty():
		_type_digit(at, digits)
	else:
		# Emptied, or nothing but letters: the box as it was, or empty.
		_set_box(at, "" if text.is_empty() else was)
