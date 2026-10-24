## Every button within reach of the keys, and names a screen reader would
## otherwise be without, in the parts of the interface Godot builds itself.
##
## A button made with no focus (FOCUS_NONE, as most of the app's are, so a
## click did not leave the space bar on it) joins the keyboard's order as it
## is made (FocusGuard.by_keyboard): Tab and the arrows reach it, Return
## presses it, and a click still leaves the keys with the model. So every
## dialog's buttons and the sign-in screen's can be used without a mouse,
## whoever made them and whenever.
##
## Every control the app makes says its own name (accessibility_name, or its
## words). Godot's own file dialog, which the desktop shows to choose a
## picture, a model or a place to save, names all but three of its parts:
## the two buttons that move a favourite folder up and down, which have
## only an arrow, and the bars between its panes. They are named here as
## each dialog is made, whoever makes it.
class_name Access
extends Node


func _ready() -> void:
	get_tree().node_added.connect(_on_added)
	# And those made before this was.
	_reach_all.call_deferred(get_tree().root)


static func _reach_all(node: Node) -> void:
	for child: Node in node.get_children(true):
		if child is BaseButton:
			_within_reach(child)
		_reach_all(child)


func _on_added(node: Node) -> void:
	if node is FileDialog:
		_name_dialog.call_deferred(node)
	elif node is BaseButton:
		_within_reach.call_deferred(node)


## After whoever made it has set it up: a focus set once it was added counts.
static func _within_reach(button: BaseButton) -> void:
	if is_instance_valid(button) and not button.has_meta(FocusGuard.BY_KEYBOARD) \
			and button.focus_mode in [Control.FOCUS_NONE, Control.FOCUS_ACCESSIBILITY]:
		FocusGuard.by_keyboard(button)


static func _name_dialog(dialog: FileDialog) -> void:
	if not is_instance_valid(dialog):
		return
	var arrows: Array[String] = ["Move the favourite up", "Move the favourite down"]
	for part: Node in _all_under(dialog):
		var control: Control = part as Control
		if control == null or not control.accessibility_name.is_empty():
			continue
		if control.get_class() == "SplitContainerDragger":
			control.accessibility_name = "Drag to share the room between the panes"
		elif control is Button and (control as Button).text.is_empty() \
				and control.tooltip_text.is_empty() and not arrows.is_empty():
			control.accessibility_name = arrows.pop_front()


static func _all_under(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in node.get_children(true):
		out.append(child)
		out.append_array(_all_under(child))
	return out
