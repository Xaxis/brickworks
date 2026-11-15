## The code from the email typed one digit to a box (signinux, 2026-11-13),
## as every site that emails a one-time code asks for it, and as the site's
## own sign-in does (web/code-boxes.js): a row of boxes, centred, each
## sized for a thumb, a wider gap at the middle of a long code (four and
## four for the deployment's eight digits).
##
## A digit typed fills its box and moves on, the next box's digit selected
## so a digit typed replaces it; Backspace empties a box, or on an empty one
## steps back and empties that; Left and Right move; anything but a digit is
## refused. A paste anywhere in the row (Ctrl or Cmd+V) fills every box from
## the first with the clipboard's digits, spaces and dashes dropped; so does
## a whole code arriving in one box at once (a password manager's fill, the
## browser's or the phone's paste). The number keys on a phone's keyboard.
## [signal filled] once the last box has its digit: the form signs in then,
## with nobody having to look for the button.
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


## [param text]'s digits put in the boxes from the first, as a paste or a
## password manager's fill does; the keys in the box after the last digit,
## and [signal filled] when every box has one.
func paste(text: String) -> void:
	var digits: String = _digits(text)
	if digits.is_empty():
		return
	_fill_from(0, digits.left(_boxes.size()))


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
	one.grab_focus()
	# Selected, so a digit typed replaces the one there.
	one.select_all()
	one.caret_column = one.text.length()


## [param digits] put one to a box from [param at] on.
func _fill_from(at: int, digits: String) -> void:
	_setting = true
	var put: int = at
	for c: String in digits:
		if put >= _boxes.size():
			break
		_boxes[put].text = c
		put += 1
	_setting = false
	_focus(mini(put, _boxes.size() - 1))
	if is_full():
		filled.emit(code())


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
	_fill_from(at, c)


func _set_box(at: int, text: String) -> void:
	_setting = true
	_boxes[at].text = text
	_setting = false


## Whatever reached a box without passing _key (a paste, a fill, a phone's
## keyboard): its digits, one to a box from here on, or a whole code from
## the first box.
func _typed(text: String, at: int) -> void:
	if _setting:
		return
	var digits: String = _digits(text)
	if digits.length() > _boxes.size():
		digits = digits.right(_boxes.size())
	if digits.is_empty():
		_set_box(at, "")
		return
	if digits.length() == _boxes.size():
		_fill_from(0, digits)
	else:
		_fill_from(at, digits)
