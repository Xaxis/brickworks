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
## Escape also puts back what the field said when the typing began, in a
## field marked for it (``revert_on_escape``), which the model's name is.
class_name FocusGuard
extends Node

## What a field said when it took the focus, for Escape.
var _before: Dictionary = {}     ## instance id -> String


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus)


func _on_focus(control: Control) -> void:
	var field: LineEdit = control as LineEdit
	if field == null:
		return
	_before[field.get_instance_id()] = field.text
	# Enter ends a one-line field's typing, after the field has done what
	# Enter does there (renamed, searched, moved a part).
	if not field.text_submitted.is_connected(_submitted.bind(field)):
		field.text_submitted.connect(_submitted.bind(field), CONNECT_DEFERRED)


func _submitted(_text: String, field: LineEdit) -> void:
	if is_instance_valid(field) and field.has_focus() \
			and not bool(field.get_meta("keep_focus_on_enter", false)):
		field.release_focus()


func _input(event: InputEvent) -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
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
			# never does here.
			if focused is LineEdit:
				focused.release_focus()
				get_viewport().set_input_as_handled()
