## The comments pinned to parts, drawn on the model (PinnedComments): a round
## mark in its writer's colour over its part, numbered as Edit, Comments…
## lists them. Pressed, a card says who wrote it and what, with Resolve,
## one click. Resolved ones are not drawn; the Comments panel lists them.
##
## Over the model's column (Main's model area), under the panels beside it,
## and a mark whose part is behind the camera or out of the column is not
## drawn. Placed again each frame only while there are marks to place.
##
## Not drawn on a model shared by link and opened to look at (its page's
## View in 3D): they are notes to whoever builds it, kept in its file, which
## a copy opened in the app has.
class_name PinsView
extends Control

var store: ModelStore
var world: BrickWorld
var camera: Camera3D
## For a session's rule (Together.comment_words) and the actions, which
## record their undo. An account under 13 is sent no one else's comments in
## a session (api/together.js), so what is here is its own to read.
var together: Together
## All comments… on the card: Main opens the Comments panel.
signal list_wanted

const MARK := 22.0
const CARD_WIDTH := 280.0
const DEFAULT_TINT := Color("#4c6ef5")
## Resolve's tooltip, its Undo key filled from the keymap (Keymap.filled).
const RESOLVE_TIP := "Done with it: kept with the model, out of the view ({undo|brings it back})"

## pin id -> its mark.
var _marks: Dictionary = {}
var _card: PopupPanel
var _card_who: Label
var _card_words: Label
var _card_resolve: Button
var _card_pin: String = ""


func _ready() -> void:
	name = "Pins"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = PopupPanel.new()
	_card.name = "PinCard"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_card_who = Label.new()
	column.add_child(_card_who)
	_card_words = Label.new()
	_card_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_words.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	column.add_child(_card_words)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_card_resolve = Button.new()
	_card_resolve.text = "Resolve"
	_card_resolve.focus_mode = Control.FOCUS_NONE
	_card_resolve.tooltip_text = Keymap.filled(RESOLVE_TIP, true)
	_card_resolve.pressed.connect(_resolve_shown)
	row.add_child(_card_resolve)
	var all := Button.new()
	all.text = "All comments"
	all.flat = true
	all.focus_mode = Control.FOCUS_NONE
	all.pressed.connect(func() -> void:
		_card.hide()
		list_wanted.emit())
	row.add_child(all)
	column.add_child(row)
	_card.add_child(column)
	add_child(_card)


func _process(_delta: float) -> void:
	if store == null or world == null or camera == null:
		return
	var shown: Dictionary = {}
	var lift: Vector3 = store.lift()
	var area: Rect2 = Rect2(Vector2.ZERO, size)
	var n: int = 0
	for pin: PinnedComments.Pin in [] if store.read_only else store.pins.list:
		n += 1
		if pin.resolved:
			continue
		var point: Vector3 = PinnedComments.point_of(pin, world, lift)
		if camera.is_position_behind(point):
			continue
		var at: Vector2 = camera.unproject_position(point) - get_global_rect().position
		if not area.grow(-MARK / 2.0).has_point(at):
			continue
		var mark: Button = _marks.get(pin.id)
		if mark == null:
			mark = _mark(pin.id)
			_marks[pin.id] = mark
		_paint(mark, pin, n)
		mark.position = (at - Vector2(MARK, MARK) / 2.0).round()
		shown[pin.id] = true
	for id: String in _marks.keys():
		if not shown.has(id):
			(_marks[id] as Button).queue_free()
			_marks.erase(id)
	if _card.visible and store.pins.named(_card_pin) == null:
		_card.hide()


func _mark(id: String) -> Button:
	var mark := Button.new()
	mark.name = "Pin_" + id
	mark.focus_mode = Control.FOCUS_NONE
	mark.custom_minimum_size = Vector2(MARK, MARK)
	mark.size = Vector2(MARK, MARK)
	mark.add_theme_font_size_override("font_size", 12)
	mark.pressed.connect(func() -> void: open_card(id))
	add_child(mark)
	return mark


func _paint(mark: Button, pin: PinnedComments.Pin, number: int) -> void:
	var words: String = str(number)
	if mark.text == words and mark.get_meta("tint", "") == pin.tint:
		return
	mark.text = words
	mark.set_meta("tint", pin.tint)
	var colour: Color = Color(pin.tint) if not pin.tint.is_empty() else DEFAULT_TINT
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var face := StyleBoxFlat.new()
		face.bg_color = colour.lightened(0.15) if state == "hover" else colour
		face.set_corner_radius_all(int(MARK / 2.0))
		face.border_color = Color.WHITE
		face.set_border_width_all(2)
		mark.add_theme_stylebox_override(state, face)
	for which: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		mark.add_theme_color_override(which, Color.WHITE)
	mark.tooltip_text = "%s: %s" % [_who(pin), pin.text.left(80)]


## Who wrote [param pin], in words.
static func _who(pin: PinnedComments.Pin) -> String:
	return pin.by if not pin.by.is_empty() else "A comment"


## The card for the comment [param id], beside its mark.
func open_card(id: String) -> void:
	var pin: PinnedComments.Pin = store.pins.named(id)
	if pin == null:
		return
	_card_pin = id
	_card_who.text = _who(pin) + ("  ·  " + pin.when.left(10) if not pin.when.is_empty() else "")
	if not pin.tint.is_empty():
		_card_who.add_theme_color_override("font_color", Color(pin.tint).lightened(0.25))
	else:
		_card_who.remove_theme_color_override("font_color")
	_card_words.text = pin.text
	var why: String = together.comment_words() if together != null else ""
	_card_resolve.disabled = not why.is_empty()
	_card_resolve.tooltip_text = why if not why.is_empty() \
		else Keymap.filled(RESOLVE_TIP, true)
	var mark: Button = _marks.get(id)
	var at: Vector2 = mark.get_screen_position() + Vector2(MARK + 6, -4) if mark != null \
		else get_screen_position() + size / 2.0
	_card.reset_size()
	_card.popup(Rect2i(Vector2i(at), Vector2i(int(CARD_WIDTH), 0)))


func _resolve_shown() -> void:
	if together != null and together.resolve_comment(_card_pin):
		_card.hide()


## How many marks are drawn now, and the card's Resolve while it is open: for
## a probe.
func marks_shown() -> int:
	return _marks.size()


func mark_of(id: String) -> Button:
	return _marks.get(id)


func card_resolve() -> Button:
	return _card_resolve if _card.visible else null


## What a check presses: each mark by its number in the list, and the card's
## Resolve while it is open.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {}
	var n: int = 0
	for pin: PinnedComments.Pin in store.pins.list:
		n += 1
		var mark: Button = _marks.get(pin.id)
		if mark != null and mark.is_visible_in_tree():
			out["pin_mark_%d" % n] = mark
	if _card.visible:
		out["pin_resolve"] = _card_resolve
	return out
