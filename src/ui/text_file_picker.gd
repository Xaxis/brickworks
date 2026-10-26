## Choosing a text file to read in: a Rebrickable CSV, a BrickLink XML.
##
## The same two ways ModelFilePicker has, for a different kind of file: a
## file dialog on the desktop, and on the web an <input type=file> clicked
## straight from the press that asked, since a browser opens its chooser
## only while that press is still being handled.
class_name TextFilePicker
extends Node

const MAX_BYTES := 4 * 1024 * 1024

signal picked(text: String, name: String)
signal failed(why: String)

## What the chooser offers, as an <input accept>: ".csv,.xml".
var accept: String = ".csv,.xml,.txt"
var _dialog: FileDialog
var _on_text: JavaScriptObject


func ask(offer: String = "") -> void:
	if not offer.is_empty():
		accept = offer
	if OS.has_feature("web"):
		_ask_browser()
		return
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.title = "Choose a file"
		_dialog.size = Vector2i(760, 520)
		_dialog.file_selected.connect(func(path: String) -> void:
			_take(FileAccess.get_file_as_bytes(path), path.get_file()))
		add_child(_dialog)
	_dialog.clear_filters()
	var patterns := PackedStringArray()
	for extension: String in accept.split(",", false):
		patterns.append("*" + extension.strip_edges())
	_dialog.add_filter(", ".join(patterns), "Collection files")
	OpenFrom.ask(_dialog, "list")


func _take(bytes: PackedByteArray, file_name: String) -> void:
	if bytes.is_empty():
		failed.emit("could not read that file")
		return
	if bytes.size() > MAX_BYTES:
		failed.emit("that file is too large")
		return
	picked.emit(bytes.get_string_from_utf8(), file_name)


func _ask_browser() -> void:
	_on_text = JavaScriptBridge.create_callback(_from_browser)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		failed.emit("this build cannot open files")
		return
	window.brickworksPickTextFile = _on_text
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = %s;
			input.style.display = 'none';
			document.body.appendChild(input);
			input.addEventListener('change', function () {
				var file = input.files && input.files[0];
				document.body.removeChild(input);
				if (!file) { window.brickworksPickTextFile('', ''); return; }
				var reader = new FileReader();
				reader.onload = function () {
					var url = String(reader.result);
					window.brickworksPickTextFile(url.substring(url.indexOf(',') + 1), file.name);
				};
				reader.onerror = function () { window.brickworksPickTextFile('', ''); };
				reader.readAsDataURL(file);
			});
			input.click();
		})();
	""" % JSON.stringify(accept), true)


func _from_browser(arguments: Array) -> void:
	if arguments.size() < 2 or str(arguments[0]).is_empty():
		failed.emit("no file chosen")
		return
	_take(Marshalls.base64_to_raw(str(arguments[0])), str(arguments[1]))
