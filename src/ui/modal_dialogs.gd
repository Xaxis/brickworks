## Closing the window closes the app, whatever dialog is up, and a screen
## reader still hears each dialog as modal.
##
## The engine drops a close request (the title bar's X, Alt+F4, the session
## ending, Cmd+Q) sent to a window that has an exclusive child: Window's
## _event_callback, "has an exclusive child, can't get events until child is
## closed". Every AcceptDialog is exclusive from the start, and so is each of
## its kinds (ConfirmationDialog, FileDialog), with the main window as its
## parent: with Open's file chooser, Save as, an export's Save dialog or any
## question up, the X did nothing until it was answered (desktop018, in 0.18.0
## and 0.19.0). The platform's own Save dialog, where a desktop has one, is
## no window of the app's, which is why that one never held it.
##
## A window is its parent's exclusive child only while it is transient to
## it (Window::_set_transient_exclusive_child), so that tie is what is cut:
## a dialog that would hold the main window is made not transient the frame
## it is up, and keeps its exclusive flag. The engine tells a screen reader
## a window is modal by that flag (Window's accessibility update sets
## FLAG_MODAL to it), so every dialog is still heard as one: making them
## not exclusive instead (dialogclose, 2026-11-07) left every dialog a plain
## window to a screen reader, its place in the app said nowhere (a11ymodal).
## Nothing else a person meets hangs on that tie for a window shown inside
## the main one: the keys stay in the dialog when the window loses them and
## gets them back (a11y_modal_probe, About away and back).
##
## While a dialog is up, this node, the main window's last, takes every
## event the main window would have refused, as the engine did: what is
## aimed at the dialog still reaches it, and nothing behind it moves. A
## press beside it gives the dialog the keys again, which the engine did
## only for a screen reader. A dialog's own questions (a file chooser's
## "replace it?") stay transient and exclusive to the dialog, and a window
## left not exclusive on purpose (Reference picture: the model stays to
## hand while it is open) is left as it is.
class_name ModalDialogs
extends Node

static var _windows: Dictionary = {}

## The windows cut from the main one here: each holds it while it is up.
## Untyped: one freed is read back to be let go.
var _held: Array = []


## Every dialog of [param window], the main one, holding it without keeping
## its close request from it.
static func for_the_app(window: Window) -> void:
	if _windows.has(window.get_instance_id()):
		return
	_windows[window.get_instance_id()] = true
	var holder := ModalDialogs.new()
	holder.name = "ModalDialogs"
	window.add_child.call_deferred(holder)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var window: Window = get_window()
	for sub: Window in window.get_embedded_subwindows():
		if sub.exclusive and sub.transient and sub.get_parent() != null \
				and sub.get_parent().get_window() == window:
			# Each popup makes it transient again (Window.popup).
			sub.transient = false
			if not _held.has(sub):
				_held.append(sub)
	# First to hear an event: the last of the window's nodes.
	if up() != null and get_index() != window.get_child_count() - 1:
		window.move_child(self, -1)


func _input(event: InputEvent) -> void:
	var dialog: Window = up()
	if dialog == null:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.is_pressed() and not dialog.has_focus():
		dialog.grab_focus()


## The dialog holding the main window, the last up; null when none is.
func up() -> Window:
	for n: int in range(_held.size() - 1, -1, -1):
		if not is_instance_valid(_held[n]):
			_held.remove_at(n)
			continue
		var dialog: Window = _held[n]
		if dialog.visible and dialog.is_inside_tree():
			return dialog
	return null
