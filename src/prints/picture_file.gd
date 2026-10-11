## A picture file chosen by a person: a photograph, a logo, a drawing —
## PNG, JPEG, WebP, BMP or SVG — read into an [Image].
##
## On the desktop a file dialog; in a browser the page's own file picker,
## opened while the click that asked for it is still being handled (a
## browser opens one at no other time), its bytes handed back through a
## callback. An SVG is drawn at a size a print can use: its longer side
## [constant SVG_PIXELS] pixels, whatever size it says it is.
class_name PictureFile
extends Node

const MOST_BYTES := 24 * 1024 * 1024
const SVG_PIXELS := 1024

signal picked(image: Image, name: String)
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
		_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.svg", "Pictures")
		_dialog.title = "Choose a picture to print"
		_dialog.size = Vector2i(760, 520)
		_dialog.file_selected.connect(read)
		add_child(_dialog)
	_dialog.popup_centered()


## Read a picture from a path, as the dialog does once one is chosen.
func read(path: String) -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		failed.emit("could not read %s" % path.get_file())
		return
	_take(bytes, path.get_extension().to_lower(), path.get_file())


func _ask_browser() -> void:
	_on_bytes = JavaScriptBridge.create_callback(_from_browser)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		failed.emit("this build cannot open files")
		return
	window.brickworksPickPrint = _on_bytes
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = 'image/*,.svg';
			input.style.display = 'none';
			document.body.appendChild(input);
			input.addEventListener('change', function () {
				var file = input.files && input.files[0];
				document.body.removeChild(input);
				if (!file) { window.brickworksPickPrint('', '', ''); return; }
				var reader = new FileReader();
				reader.onload = function () {
					var parts = String(reader.result).split(',');
					var kind = (file.name.split('.').pop() || '').toLowerCase();
					window.brickworksPickPrint(parts[1] || '', kind, file.name);
				};
				reader.onerror = function () { window.brickworksPickPrint('', '', ''); };
				reader.readAsDataURL(file);
			});
			input.click();
		})();
	""", true)


func _from_browser(arguments: Array) -> void:
	if arguments.size() < 3 or str(arguments[0]).is_empty():
		failed.emit("no picture chosen")
		return
	_take(Marshalls.base64_to_raw(str(arguments[0])), str(arguments[1]), str(arguments[2]))


func _take(bytes: PackedByteArray, hint: String, called: String) -> void:
	if bytes.size() > MOST_BYTES:
		failed.emit("that picture is too large")
		return
	var image: Image = decode(bytes, hint)
	if image == null:
		failed.emit("%s is not a picture this can read" % called)
		return
	picked.emit(image, called)


## What kind of picture some bytes are, by their first bytes: "" when
## they say nothing known.
static func kind_of(bytes: PackedByteArray) -> String:
	if bytes.size() < 12:
		return ""
	if bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		return "png"
	if bytes[0] == 0xFF and bytes[1] == 0xD8:
		return "jpg"
	if bytes.slice(0, 4).get_string_from_ascii() == "RIFF" \
			and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		return "webp"
	if bytes[0] == 0x42 and bytes[1] == 0x4D:
		return "bmp"
	var head: String = bytes.slice(0, mini(bytes.size(), 512)).get_string_from_utf8()
	if head.contains("<svg") or head.strip_edges().begins_with("<?xml"):
		return "svg"
	return ""


## A picture from its bytes, by trying each kind rather than trusting the
## name: a .jpg that is really a PNG is common. Null when none reads it.
static func decode(bytes: PackedByteArray, hint: String = "") -> Image:
	# What the bytes say they are first, then the name, then the rest.
	var order: Array[String] = [kind_of(bytes), hint, "png", "jpg", "webp", "bmp", "svg"]
	for kind: String in order:
		var image := Image.new()
		var error: int = ERR_FILE_UNRECOGNIZED
		match kind:
			"png": error = image.load_png_from_buffer(bytes)
			"jpg", "jpeg": error = image.load_jpg_from_buffer(bytes)
			"webp": error = image.load_webp_from_buffer(bytes)
			"bmp": error = image.load_bmp_from_buffer(bytes)
			"svg":
				# Drawn once to learn its size, then at the size wanted.
				error = image.load_svg_from_buffer(bytes, 1.0)
				if error == OK and not image.is_empty():
					var longest: float = maxf(image.get_width(), image.get_height())
					error = image.load_svg_from_buffer(bytes, SVG_PIXELS / maxf(1.0, longest))
		if error == OK and not image.is_empty():
			if image.get_format() != Image.FORMAT_RGBA8:
				image.convert(Image.FORMAT_RGBA8)
			return image
	return null
