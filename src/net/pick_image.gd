## Getting a picture off the person's machine.
##
## Two entirely different mechanisms wearing one name. On the desktop a
## file dialog reads the bytes; in a browser a page cannot read a path at
## all, so the only way in is an <input type="file"> the person clicks
## themselves — it will not open unless a real click is still being
## handled, which is why this cannot be triggered from a timer or a
## signal that arrives later.
##
## Emits [signal picked] with a decoded image, or [signal failed] with
## something to show. Never both.
class_name PickImage
extends Node

## Bigger than any mosaic needs, and small enough that a phone
## photograph does not spend a second being decoded.
const MAX_BYTES := 24 * 1024 * 1024

signal picked(image: Image)
signal failed(why: String)

var _dialog: FileDialog
var _bridge: JavaScriptObject
var _on_bytes: JavaScriptObject


func ask() -> void:
	if OS.has_feature("web"):
		_ask_browser()
		return
	_ask_desktop()


func _ask_desktop() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.bmp", "Pictures")
		_dialog.title = "Choose a picture"
		_dialog.size = Vector2i(760, 520)
		_dialog.file_selected.connect(_read_file)
		add_child(_dialog)
	_dialog.popup_centered()


func _read_file(path: String) -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		failed.emit("could not read that file")
		return
	_decode(bytes, path.get_extension().to_lower())


## The browser. An input element is made, clicked, and thrown away; the
## bytes come back through a callback Godot owns, which has to be kept
## alive for as long as the browser might call it — a local would be
## collected the moment this function returns and the callback would
## fire into nothing.
func _ask_browser() -> void:
	_on_bytes = JavaScriptBridge.create_callback(_from_browser)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		failed.emit("this build cannot open files")
		return
	window.brickworksPickImage = _on_bytes
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = 'image/*';
			input.style.display = 'none';
			document.body.appendChild(input);
			input.addEventListener('change', function () {
				var file = input.files && input.files[0];
				document.body.removeChild(input);
				if (!file) { window.brickworksPickImage('', ''); return; }
				var reader = new FileReader();
				reader.onload = function () {
					// A data: URI, split so Godot gets the base64 alone
					// and the type it should decode it as.
					var parts = String(reader.result).split(',');
					var kind = (file.name.split('.').pop() || '').toLowerCase();
					window.brickworksPickImage(parts[1] || '', kind);
				};
				reader.onerror = function () { window.brickworksPickImage('', ''); };
				reader.readAsDataURL(file);
			});
			input.click();
		})();
	""", true)


func _from_browser(arguments: Array) -> void:
	if arguments.size() < 2 or str(arguments[0]).is_empty():
		failed.emit("no picture chosen")
		return
	_decode(Marshalls.base64_to_raw(str(arguments[0])), str(arguments[1]))


## Decode by trying, not by trusting the extension. A .jpg that is
## really a PNG is common enough, and the failure is silent — an empty
## image that lays out as nothing.
func _decode(bytes: PackedByteArray, hint: String) -> void:
	if bytes.size() > MAX_BYTES:
		failed.emit("that picture is too large")
		return

	var image := Image.new()
	var order: Array[String] = [hint, "png", "jpg", "webp", "bmp"]
	for kind: String in order:
		var error: int = ERR_FILE_UNRECOGNIZED
		match kind:
			"png": error = image.load_png_from_buffer(bytes)
			"jpg", "jpeg": error = image.load_jpg_from_buffer(bytes)
			"webp": error = image.load_webp_from_buffer(bytes)
			"bmp": error = image.load_bmp_from_buffer(bytes)
		if error == OK and not image.is_empty():
			picked.emit(image)
			return
	failed.emit("that file is not a picture this can read")
