## File, Comments…: the comments pinned to this model's parts
## (PinnedComments), and a new one on the part selected.
##
## A field and Pin for the part selected (the first, when several are);
## then each comment, numbered as its mark on the model is, with who wrote
## it, Show (the view turned to its part, the part selected) and Resolve,
## one click. Resolved ones are kept, listed under Show resolved with Open
## again. Each is one undo. In a session the others see them as they are
## pinned (Together), and an account under 13 is told why it may not pin
## one there, as with chat. The look of Build together, the panel beside it.
class_name PinsDialog
extends AcceptDialog

var together: Together
var store: ModelStore
var builder: Builder
var world: BrickWorld
var camera: CadCamera

var _note: Label
var _field: LineEdit
var _pin: Button
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _show_resolved: CheckBox
var _resolves: Array[Button] = []
## The list's rows in sight at once; more scroll.
const ROWS_TALL := 6
const WIDTH := 460
## What the list was last drawn from, so it is drawn again only on a change.
var _drawn: String = ""


func _ready() -> void:
	title = "Comments"
	ok_button_text = "Close"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(column)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(WIDTH, 0)
	column.add_child(_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_field = LineEdit.new()
	_field.placeholder_text = "Say something about this part"
	_field.max_length = PinnedComments.TEXT_MOST
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.text_submitted.connect(func(_text: String) -> void: _on_pin())
	row.add_child(_field)
	_pin = Button.new()
	_pin.text = "Pin"
	_pin.focus_mode = Control.FOCUS_NONE
	_pin.tooltip_text = "Pin it to the part selected, for everyone who builds this model"
	_pin.pressed.connect(_on_pin)
	row.add_child(_pin)
	column.add_child(row)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_rows)
	column.add_child(_scroll)
	_show_resolved = CheckBox.new()
	_show_resolved.text = "Show resolved"
	_show_resolved.focus_mode = Control.FOCUS_NONE
	_show_resolved.toggled.connect(func(_on: bool) -> void: fill())
	column.add_child(_show_resolved)


func _process(_delta: float) -> void:
	# Pinned, resolved or taken back by the others, or by Undo: drawn again.
	if visible and _words() != _drawn:
		fill()


## Open, the field ready for a comment on the part selected.
func open() -> void:
	_field.text = ""
	fill()
	popup_centered()
	_hold_height.call_deferred()
	if _target() != 0 and not _pin.disabled:
		_field.grab_focus.call_deferred()


func _hold_height() -> void:
	if is_instance_valid(_scroll):
		var line: float = maxf(float(_pin.get_combined_minimum_size().y), 28.0)
		_scroll.custom_minimum_size.y = ROWS_TALL * line + (ROWS_TALL - 1) * 4.0


## The part a new comment goes on: the first selected, or 0.
func _target() -> int:
	var chosen: Array = builder.selection.keys()
	chosen.sort()
	for brick_id: Variant in chosen:
		if world.get_brick(int(brick_id)) != null and not store.scenery.has(int(brick_id)):
			return int(brick_id)
	return 0


func _words() -> String:
	var said := PackedStringArray([str(_target()), str(_show_resolved.button_pressed),
		together.comment_words() if together != null else ""])
	for pin: PinnedComments.Pin in store.pins.list:
		said.append("%s|%s|%s|%s" % [pin.id, pin.text, pin.by, pin.resolved])
	return "\n".join(said)


## What it says and lists, as the model's comments are now.
func fill() -> void:
	_drawn = _words()
	for child: Node in _rows.get_children():
		child.queue_free()
	_resolves.clear()
	var target: int = _target()
	var why: String = together.comment_words() if together != null else ""
	if why.contains("13"):
		why = "Comments in a session are for people 13 and over, as chat is."
	var brick: BrickWorld.Brick = world.get_brick(target) if target != 0 else null
	if not why.is_empty():
		_note.text = why
	elif brick != null:
		_note.text = "A comment on %s, kept with the model: in its file, the autosave and a shared link, and seen by whoever builds it with you." % _part_name(brick.part_id)
	else:
		_note.text = "Select a part, then write a comment on it. Comments are kept with the model and seen by whoever builds it with you."
	_field.editable = brick != null and why.is_empty()
	_pin.disabled = not _field.editable
	var shown: int = 0
	var resolved: int = 0
	var n: int = 0
	for pin: PinnedComments.Pin in store.pins.list:
		n += 1
		if pin.resolved:
			resolved += 1
			if not _show_resolved.button_pressed:
				continue
		_rows.add_child(_row(pin, n, why))
		shown += 1
	if shown == 0:
		var none := Label.new()
		none.text = "No comments yet." if store.pins.list.is_empty() else "Every comment is resolved."
		none.modulate = Look.GREYED
		_rows.add_child(none)
	_show_resolved.text = "Show resolved (%d)" % resolved
	_show_resolved.visible = resolved > 0


func _row(pin: PinnedComments.Pin, number: int, why: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var words := Label.new()
	words.text = "%d.  %s%s" % [number, (pin.by + ": ") if not pin.by.is_empty() else "", pin.text]
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pin.resolved:
		words.modulate = Look.GREYED
	elif not pin.tint.is_empty():
		words.add_theme_color_override("font_color", Color(pin.tint).lightened(0.35))
	row.add_child(words)
	var show := Button.new()
	show.text = "Show"
	show.focus_mode = Control.FOCUS_NONE
	show.tooltip_text = "Turn the view to its part, and select it"
	show.pressed.connect(func() -> void: _show(pin.id))
	row.add_child(show)
	var settle := Button.new()
	settle.text = "Open again" if pin.resolved else "Resolve"
	settle.focus_mode = Control.FOCUS_NONE
	settle.disabled = not why.is_empty()
	settle.tooltip_text = why if not why.is_empty() else ("Back on the model" if pin.resolved
		else Keymap.filled(PinsView.RESOLVE_TIP, true))
	settle.pressed.connect(func() -> void:
		together.resolve_comment(pin.id, not pin.resolved)
		fill())
	row.add_child(settle)
	if not pin.resolved:
		_resolves.append(settle)
	return row


func _part_name(part: String) -> String:
	var info: PartLibrary.PartInfo = builder.library.parts.get(part) if builder.library != null else null
	return Inventory._tidy(info.name) if info != null else part


func _on_pin() -> void:
	var target: int = _target()
	if target == 0 or _field.text.strip_edges().is_empty() or _pin.disabled:
		return
	if together.pin_comment(target, _field.text) != null:
		_field.text = ""
		fill()


## The view turned to [param id]'s part, as it stands, and the part selected.
func _show(id: String) -> void:
	var pin: PinnedComments.Pin = store.pins.named(id)
	if pin == null:
		return
	var point: Vector3 = PinnedComments.point_of(pin, world, store.lift())
	var aim: Dictionary = camera.aim()
	aim["focus"] = [point.x, point.y, point.z]
	camera.aim_at(aim)
	if pin.brick != 0:
		builder.clear_selection()
		builder.select_brick(pin.brick, false)


## What a check presses.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var out: Dictionary = {"pins_close": get_ok_button(), "pins_field": _field, "pins_pin": _pin}
	for n: int in _resolves.size():
		out["pins_resolve_%d" % (n + 1)] = _resolves[n]
	return out
