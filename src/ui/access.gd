## Names a screen reader would otherwise be without, in the parts of the
## interface Godot builds itself.
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


func _on_added(node: Node) -> void:
	if node is FileDialog:
		_name_dialog.call_deferred(node)


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
