## A picture file chosen by a person: a photograph, a logo, a drawing —
## PNG, JPEG, WebP, BMP or SVG — read into an [Image].
##
## On the desktop a file dialog; in a browser the page's own file picker,
## opened while the click that asked for it is still being handled (a
## browser opens one at no other time), its bytes handed back through a
## callback. An SVG is drawn at a size a print can use: its longer side
## [constant SVG_PIXELS] pixels, whatever size it says it is.
##
## And a picture given as its own data ([method from_data]): base64, or a
## data: URI, which is how a session hands over a picture the person gave
## it in the conversation (print_part's picture_data).
class_name PictureFile
extends Node

const MOST_BYTES := 24 * 1024 * 1024
const SVG_PIXELS := 1024
## The most a picture given as data may be, decoded. The call carrying it
## is one line of JSON, and the desktop's socket takes a line of at most
## 4 MiB (CommandSocket.LONGEST_LINE) and the connector's relay a request
## of at most 4.5 MB (Vercel's limit on a function's body): 2 MiB is
## 2.8 MB of base64, inside both with room for the rest of the call.
const MOST_DATA_BYTES := 2 * 1024 * 1024
## What can be read, said in a refusal.
const KINDS_WORDS := "a PNG, JPEG, WebP, BMP or SVG"

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
		failed.emit("%s is %s; a picture is at most %s" % [called,
			String.humanize_size(bytes.size()), String.humanize_size(MOST_BYTES)])
		return
	var image: Image = decode(bytes, hint)
	if image == null:
		failed.emit(not_read(bytes, called))
		return
	picked.emit(image, called)


## Why [param bytes], called [param called], did not read as a picture: what
## they are instead, when that can be told, and what would do.
static func not_read(bytes: PackedByteArray, called: String) -> String:
	var kind: String = kind_of(bytes)
	if not kind.is_empty():
		return "%s begins as a%s %s but could not be read: it is cut short or damaged" % [
			called, "n" if kind == "svg" else "", kind.to_upper()]
	var found: String = what_it_is(bytes)
	return "%s is %s, not a picture this can read: give %s" % [called,
		found if not found.is_empty() else "not a picture", KINDS_WORDS]


## What some bytes that are no picture this reads are, by their first
## bytes, for a refusal to say: "a PDF", "a GIF", or "" when they say
## nothing known.
static func what_it_is(bytes: PackedByteArray) -> String:
	if bytes.size() < 4:
		return "empty" if bytes.is_empty() else ""
	var head: PackedByteArray = bytes.slice(0, 4)
	if head == "%PDF".to_ascii_buffer():
		return "a PDF"
	if head == "GIF8".to_ascii_buffer():
		return "a GIF"
	if head == PackedByteArray([0x50, 0x4B, 3, 4]):
		return "a zip"
	if head == PackedByteArray([0x49, 0x49, 0x2A, 0]) or head == PackedByteArray([0x4D, 0x4D, 0, 0x2A]):
		return "a TIFF"
	if bytes.size() >= 12 and bytes.slice(4, 8).get_string_from_ascii() == "ftyp":
		var brand: String = bytes.slice(8, 12).get_string_from_ascii()
		if brand.begins_with("heic") or brand.begins_with("heix") or brand.begins_with("mif1"):
			return "a HEIC photograph (a phone's), which this cannot read"
		if brand.begins_with("avif"):
			return "an AVIF, which this cannot read"
		return "a video"
	if bytes[0] == 0 and bytes[1] == 0 and bytes[2] == 1 and bytes[3] == 0:
		return "an icon (.ico)"
	var text: String = bytes.slice(0, mini(bytes.size(), 256)).get_string_from_utf8() \
		.strip_edges().to_lower()
	if text.begins_with("<!doctype html") or text.begins_with("<html"):
		return "a web page"
	if text.begins_with("{") or text.begins_with("["):
		return "JSON"
	return ""


## A picture given as its own data — base64 (a PNG, JPEG, WebP, BMP or SVG,
## its lines wrapped or not, URL-safe or not) or a data: URI
## (data:image/png;base64,…, or an SVG percent-encoded) — read into an
## [Image]: {"image": Image, "bytes": its size} or {"error": why not, said
## for whoever gave it}. At most [constant MOST_DATA_BYTES]; anything that
## is not a picture is refused by what it is.
static func from_data(given: String) -> Dictionary:
	var text: String = given.strip_edges()
	if text.is_empty():
		return {"error": "picture_data is empty: give the picture's bytes as base64"}
	var plain: bool = false
	if text.substr(0, 5).to_lower() == "data:":
		var comma: int = text.find(",")
		if comma < 0:
			return {"error": "that data: URI has no comma before its data"}
		var header: String = text.substr(5, comma - 5).to_lower()
		var media: String = header.get_slice(";", 0).strip_edges()
		if not media.is_empty() and not media.begins_with("image/"):
			return {"error": "that is %s data, not a picture: give %s" % [media, KINDS_WORDS]}
		plain = not header.contains(";base64")
		text = text.substr(comma + 1)
	var bytes: PackedByteArray
	if plain:
		bytes = text.uri_decode().to_utf8_buffer()
	else:
		# Wrapped lines (base64 -w 76), URL-safe letters, and padding left off.
		var packed: String = text.replace("\r", "").replace("\n", "").replace(" ", "") \
			.replace("\t", "").replace("-", "+").replace("_", "/")
		if packed.begins_with("<"):
			return {"error": "that is markup, not base64: give an SVG as svg= instead"}
		var size: int = packed.trim_suffix("=").trim_suffix("=").length() * 3 / 4
		if size > MOST_DATA_BYTES:
			return {"error": _too_large(size)}
		if not BASE64.search(packed):
			return {"error": "picture_data is not base64: give the picture's bytes as base64, or a data: URI"}
		while packed.length() % 4 != 0:
			packed += "="
		bytes = Marshalls.base64_to_raw(packed)
		if bytes.is_empty():
			return {"error": "picture_data could not be decoded as base64"}
	if bytes.size() > MOST_DATA_BYTES:
		return {"error": _too_large(bytes.size())}
	var kind: String = kind_of(bytes)
	if kind.is_empty():
		return {"error": not_read(bytes, "That picture_data")}
	var image: Image = _decode_as(bytes, kind)
	if image == null:
		return {"error": not_read(bytes, "That picture_data")}
	return {"image": image, "bytes": bytes.size()}


static var BASE64 := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")


static func _too_large(size: int) -> String:
	return ("That picture is %s; a picture given as data is at most %s (the call that carries "
		+ "it is limited). Give a smaller one, or picture_url= a link to it.") % [
		String.humanize_size(size), String.humanize_size(MOST_DATA_BYTES)]


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
		var image: Image = _decode_as(bytes, kind)
		if image != null:
			return image
	return null


## A picture from its bytes read as one kind ("png", "jpg", …), in RGBA8,
## or null.
static func _decode_as(bytes: PackedByteArray, kind: String) -> Image:
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
	if error != OK or image.is_empty():
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image
