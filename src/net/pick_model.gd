## Getting an LDraw file off the person's machine.
##
## The same two mechanisms as [PickImage] and for the same reason: on
## the desktop a file dialog reads bytes off a path; in a browser a page
## cannot see a path at all, so the only way in is an
## <input type="file"> the person clicks themselves, which will not open
## unless a real click is still being handled.
##
## Emits [signal picked] with the file's text and its name, or
## [signal failed] with something to show. Never both.
class_name PickModel
extends Node

## An .ldr of any reasonable model is tens of kilobytes. A megabyte is
## already a model of tens of thousands of parts; ten is somebody
## opening the wrong file.
const MAX_BYTES := 10 * 1024 * 1024

signal picked(text: String, name: String)
signal failed(why: String)

var _dialog: FileDialog
var _on_bytes: JavaScriptObject


func ask() -> void:
	if OS.has_feature("web"):
		_ask_browser()
		return
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.add_filter("*.ldr, *.mpd, *.dat", "LDraw models")
		_dialog.title = "Open a model"
		_dialog.size = Vector2i(760, 520)
		_dialog.file_selected.connect(func(path: String) -> void:
			var text: String = FileAccess.get_file_as_string(path)
			if text.is_empty():
				failed.emit("could not read that file")
			else:
				picked.emit(text, path.get_file()))
		add_child(_dialog)
	_dialog.popup_centered()


func _ask_browser() -> void:
	_on_bytes = JavaScriptBridge.create_callback(_from_browser)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		failed.emit("this build cannot open files")
		return
	window.brickworksPickModel = _on_bytes
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.ldr,.mpd,.dat,text/plain';
			input.style.display = 'none';
			document.body.appendChild(input);
			input.addEventListener('change', function () {
				var file = input.files && input.files[0];
				document.body.removeChild(input);
				if (!file) { window.brickworksPickModel('', ''); return; }
				var reader = new FileReader();
				reader.onload = function () {
					window.brickworksPickModel(String(reader.result), file.name);
				};
				reader.onerror = function () { window.brickworksPickModel('', ''); };
				reader.readAsText(file);
			});
			input.click();
		})();
	""", true)


func _from_browser(arguments: Array) -> void:
	if arguments.size() < 2 or str(arguments[0]).is_empty():
		failed.emit("no model chosen")
		return
	var text: String = str(arguments[0])
	if text.length() > MAX_BYTES:
		failed.emit("that file is too large")
		return
	picked.emit(text, str(arguments[1]))
