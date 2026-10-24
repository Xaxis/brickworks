## Text fields give the keys back.
##
## The owner: "When the user names a build (renames it), the text input
## never loses focus and can't control the CAD controls." Godot keeps a
## field focused after Enter, and a click on the 3D view lands on no
## control, so nothing took the focus away: every shortcut and every view
## key went into the field until something else was clicked — and the
## app's own key handler stands aside for a focused field, as it must
## while somebody is typing.
##
## So, for every field in the app, the model's name, the part search, the
## assistant's brief, the properties' numbers, the minifigure's name and
## any added later: Enter (where a field has nothing else to do with it),
## Tab, Escape and a press anywhere outside the field end the typing.
## Escape also puts back what the field said when the typing began, or what
## Enter last kept, in a field marked for it (``revert_on_escape``), which
## the model's name is.
##
## And the controls Tab reaches that are not fields (the toolbar, the bin's
## tiles and colours, the view cube: [method by_keyboard]) have the keys only
## while Tab or the arrows put them there. A click on one does what it does
## and leaves the keys with the model, as before: a tile kept after a click
## walked its arrows round the grid, and Right never reached the timeline
## (the CAD task test, 2026-10-16); a button kept took the space bar.
class_name FocusGuard
extends Node

## Marks a control that Tab and the arrows reach, and a click does not keep.
const BY_KEYBOARD := &"by_keyboard"


## [param control] in the keyboard's order: Tab and the arrows reach it, and
## a press of Return or the space bar there is a click. A click still leaves
## the keys with the model.
static func by_keyboard(control: Control) -> void:
	control.focus_mode = Control.FOCUS_ALL
	control.set_meta(BY_KEYBOARD, true)


## The ring round a control the keys are on, drawn only when Tab or the
## arrows put them there (a control a click reached draws no focus).
static func ring(corner: int = 5) -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Look.ACCENT
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(corner)
	ring.set_expand_margin_all(1)
	return ring


## Whether the keys are with a control a person moved to with Tab or the
## arrows, or is typing in: then they are its, and not the model's.
static func keys_with_a_control(viewport: Viewport) -> bool:
	var focused: Control = viewport.gui_get_focus_owner()
	if focused == null:
		return false
	return focused is LineEdit or focused is TextEdit or focused.has_focus(true)

## What a field said when it took the focus, for Escape.
var _before: Dictionary = {}     ## instance id -> String


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus)


## A keyboard control a click gave the keys to, to give them back to the
## model once the click is over. Let go while the button was still down,
## the click was no click: a button cancels a press when it loses the keys
## (BaseButton, NOTIFICATION_FOCUS_EXIT), and the bin's tabs did nothing
## (bin_techniques_probe).
var _clicked: Control


func _on_focus(control: Control) -> void:
	# Taken by a click (its focus hidden), a keyboard control lets go again
	# when the button comes up.
	if control.has_meta(BY_KEYBOARD) and not control.has_focus(true):
		_clicked = control
		return
	var field: LineEdit = control as LineEdit
	if field == null:
		return
	_before[field.get_instance_id()] = field.text
	# Enter keeps what was typed, at once.
	if not field.text_submitted.is_connected(_kept.bind(field)):
		field.text_submitted.connect(_kept.bind(field))
	# Enter ends a one-line field's typing, after the field has done what
	# Enter does there (renamed, searched, moved a part).
	if not field.text_submitted.is_connected(_submitted.bind(field)):
		field.text_submitted.connect(_submitted.bind(field), CONNECT_DEFERRED)


## What Enter kept is what an Escape after it puts back.
##
## The engine hands over every key that came since the last frame at the
## start of the next, in order, and the field lets go after Enter only at the
## end of that frame. A busy tab's frame is longer than half a second, so a
## name typed, Enter, and Escape a moment later to give the keys back came in
## one frame: the Escape found the field still typing and put back the name
## the typing began with. The name was typed and entered, and then lost (a
## release check's rename, tools/web/tabs_flow.mjs, at a load of 40 to 60).
func _kept(text: String, field: LineEdit) -> void:
	_before[field.get_instance_id()] = text


func _submitted(_text: String, field: LineEdit) -> void:
	if is_instance_valid(field) and field.has_focus() \
			and not bool(field.get_meta("keep_focus_on_enter", false)):
		field.release_focus()


func _let_go(control: Control) -> void:
	if is_instance_valid(control) and control.has_focus() and not control.has_focus(true):
		control.release_focus()


func _input(event: InputEvent) -> void:
	# The click that gave a keyboard control the keys is over once its button
	# comes up, and that release is the control's first.
	var up: InputEventMouseButton = event as InputEventMouseButton
	if up != null and not up.pressed and is_instance_valid(_clicked):
		_let_go.call_deferred(_clicked)
		_clicked = null
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null:
		_tab_in(event)
		return
	# F6, the key every desktop app and browser moves between its panes
	# with: from a control the keys go back to the model, and the next F6
	# comes back to where they were.
	var key_pressed: InputEventKey = event as InputEventKey
	if key_pressed != null and key_pressed.pressed and not key_pressed.echo \
			and key_pressed.keycode == KEY_F6 \
			and (focused.has_meta(BY_KEYBOARD) or focused is LineEdit or focused is TextEdit):
		_back_to = focused
		focused.release_focus()
		get_viewport().set_input_as_handled()
		return
	if focused.has_meta(BY_KEYBOARD):
		# A press of the pointer anywhere gives the keys back to the model.
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed:
			focused.release_focus()
		return
	if not (focused is LineEdit or focused is TextEdit):
		return
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed:
		# Anywhere else: the 3D view, a panel, another button. The press
		# goes on to whatever it landed on.
		if not focused.get_global_rect().has_point(press.position):
			focused.release_focus()
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			var field: LineEdit = focused as LineEdit
			focused.release_focus()
			if field != null and bool(field.get_meta("revert_on_escape", false)):
				var was: Variant = _before.get(field.get_instance_id())
				if was != null and field.text != str(was):
					field.text = str(was)
					field.text_changed.emit(field.text)
				# The name put back is all this Escape was for.
				get_viewport().set_input_as_handled()
			# Anywhere else it goes on, to close the dialog the field is in
			# (the minifigure builder's search) as it always did.
		KEY_TAB:
			# A field of more than one line may want Tab; a one-line field
			# never does here. The keys go back to the model, which is the
			# stop after the field: the next Tab goes on from it.
			if focused is LineEdit:
				_left = focused
				focused.release_focus()
				get_viewport().set_input_as_handled()


## Into the interface with nothing focused, as it is from launch and after a
## click on the model: at its first control (with Shift, its last), or on
## from the control the keys last left. The window's own Tab starts from a
## control at its top, and the app's top is the 3D scene, so it did nothing.
##
## F6 does it always. Tab does it while a screen reader is running
## (AccessKit active): otherwise Tab is the app's own key, the panels folded
## and brought back, as it has been (Main._tab_columns).
func _tab_in(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_left = null
		_back_to = null
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo \
			or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if not (key.keycode == KEY_F6
			or (key.keycode == KEY_TAB and get_tree().is_accessibility_enabled())):
		return
	var back: Control = _back_to if is_instance_valid(_back_to) else null
	_back_to = null
	if back != null and back.is_visible_in_tree() and back.focus_mode != Control.FOCUS_NONE:
		back.grab_focus()
		_left = null
		get_viewport().set_input_as_handled()
		return
	var from: Control = interface_top
	if is_instance_valid(_left) and _left.is_visible_in_tree():
		from = _left
	_left = null
	if from == null or not from.is_visible_in_tree():
		return
	var next: Control = from.find_prev_valid_focus() if key.shift_pressed \
		else from.find_next_valid_focus()
	if next != null:
		next.grab_focus()
		get_viewport().set_input_as_handled()


## Where Tab goes in from: the interface's outermost control (Shell).
var interface_top: Control
## The field Tab gave the keys back from, for the next Tab to go on from.
var _left: Control
## The control F6 took the keys from, for the next F6 to give them back to.
var _back_to: Control
