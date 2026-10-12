## Choosing a model file to open: LDraw, BrickLink Studio's .io, or LEGO
## Digital Designer's .lxf.
##
## The file is read as bytes, not as text, because an .io is a zip: read as
## text in a browser it came back mangled, and a model made in Studio — the
## most used hand-building tool there is — could not be brought in at all.
## LDraw files are text and are read as such once their bytes are in.
## What comes out is always LDraw text, for ModelStore.open_text.
class_name ModelFilePicker
extends Node

const MAX_BYTES := 16 * 1024 * 1024

signal picked(text: String, name: String)
signal failed(why: String)

## What the last file picked left out, in a sentence (an LDD part with no
## LDraw match): "" when nothing was.
var notes: String = ""

var _dialog: FileDialog
var _on_bytes: JavaScriptObject


## Ask for a file. Called straight from the click that wanted it: a browser
## opens its file chooser only while that click is still being handled.
func ask() -> void:
	if OS.has_feature("web"):
		_ask_browser()
		return
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.add_filter("*.ldr, *.mpd, *.dat, *.io, *.lxf, *.lxfml", "Models (LDraw, Studio, LDD)")
		_dialog.title = "Open a model"
		_dialog.size = Vector2i(760, 520)
		_dialog.file_selected.connect(func(path: String) -> void:
			take(FileAccess.get_file_as_bytes(path), path.get_file()))
		add_child(_dialog)
	_dialog.popup_centered()


## A file's bytes and name, made into LDraw text and handed on.
func take(bytes: PackedByteArray, file_name: String) -> void:
	if bytes.is_empty():
		failed.emit("could not read that file")
		return
	if bytes.size() > MAX_BYTES:
		failed.emit("that file is too large")
		return
	notes = ""
	match file_name.get_extension().to_lower():
		"io":
			var read: Dictionary = StudioIo.read(bytes)
			if not str(read["error"]).is_empty():
				failed.emit(str(read["error"]))
				return
			picked.emit(str(read["text"]), file_name)
		"lxf", "lxfml":
			var read: Dictionary = LddLxf.read(bytes, file_name.get_basename())
			if not str(read["error"]).is_empty():
				failed.emit(str(read["error"]))
				return
			notes = str(read["note"])
			picked.emit(str(read["text"]), file_name)
		_:
			picked.emit(bytes.get_string_from_utf8(), file_name)


func _ask_browser() -> void:
	_on_bytes = JavaScriptBridge.create_callback(_from_browser)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		failed.emit("this build cannot open files")
		return
	window.brickworksPickModelFile = _on_bytes
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.ldr,.mpd,.dat,.io,.lxf,.lxfml';
			input.style.display = 'none';
			document.body.appendChild(input);
			input.addEventListener('change', function () {
				var file = input.files && input.files[0];
				document.body.removeChild(input);
				if (!file) { window.brickworksPickModelFile('', ''); return; }
				var reader = new FileReader();
				reader.onload = function () {
					var url = String(reader.result);
					window.brickworksPickModelFile(url.substring(url.indexOf(',') + 1), file.name);
				};
				reader.onerror = function () { window.brickworksPickModelFile('', ''); };
				reader.readAsDataURL(file);
			});
			input.click();
		})();
	""", true)


func _from_browser(arguments: Array) -> void:
	if arguments.size() < 2 or str(arguments[0]).is_empty():
		failed.emit("no model chosen")
		return
	take(Marshalls.base64_to_raw(str(arguments[0])), str(arguments[1]))
