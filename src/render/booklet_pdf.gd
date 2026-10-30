## A booklet saved as a PDF, written here a page at a time, with no
## browser and no library: what Studio's Instruction Maker saves.
##
## A booklet became a PDF only by printing its page from a browser, which
## a person had to know to do, and which turned anything not a JPEG into a
## picture many times its size (BookletMaker._data_uri). Here each page is
## what BookletRead reads off the booklet's own page: the step pictures
## are the booklet's own JPEGs, in the file as they are (DCTDecode); a
## part's picture is in the file once, however many pages show it; and
## the boxes, arrows and words are drawn as PDF draws them, so a step
## number or a part's element number is words a reader can find and copy,
## sharp at any size. The words are set in Liberation Sans, which has
## Helvetica's widths letter for letter (the widths the booklet lays its
## words out by, BookletRead), and the type itself is in the file, so
## every reader draws the same letters whether it has Helvetica or not.
## The page is the booklet's, 269 x 199 mm, which fits A4 and US Letter
## turned on their side (Booklet).
##
## Written as it goes, into its file or (on the web) into memory to be
## downloaded: each page's pictures and words, then the page; and at the
## end the list of pages and where each object is.
class_name BookletPdf
extends RefCounted

## Points (a PDF's unit) to a millimetre.
const PT := 72.0 / 25.4

var pages: int = 0
## Bytes written so far.
var size: int = 0
var _file: FileAccess = null
var _bytes := PackedByteArray()
var _offsets: Dictionary = {}
var _next: int = 5
var _kids := PackedStringArray()
## A part's picture's object by its class and the colour it is laid on.
var _parts: Dictionary = {}
var _read: BookletRead
var _ok: bool = true

const _CATALOG := 1
const _PAGES := 2
const _FONT := 3
const _BOLD := 4

## The type, regular and bold: its file (SIL Open Font License 1.1,
## assets/fonts/OFL.txt) and its PostScript name.
const TYPE: Array = [["res://assets/fonts/LiberationSans-Regular.ttf", "LiberationSans"],
	["res://assets/fonts/LiberationSans-Bold.ttf", "LiberationSans-Bold"]]
## WinAnsi's codes above 127 that are not Latin-1's, by their character.
const MORE := {0x20AC: 0x80, 0x2026: 0x85, 0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93,
	0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97, 0x2122: 0x99}


## Start a PDF going to [param path], or into memory when it is "" (take
## it with [method finish]). False when the file cannot be written.
func begin(path: String, read: BookletRead) -> bool:
	_read = read
	if not path.is_empty():
		_file = FileAccess.open(path, FileAccess.WRITE)
		if _file == null:
			return false
	_put(PackedByteArray([37, 80, 68, 70, 45, 49, 46, 52, 10, 37, 226, 227, 207, 211, 10]))
	_font(_FONT, TYPE[0])
	_font(_BOLD, TYPE[1])
	return true


## The type [param type] ([file, name]) as font [param number], the whole
## TrueType file in the PDF. A file the app cannot read falls back to the
## reader's own Helvetica, as the PDF was before, and says so.
func _font(number: int, type: Array) -> void:
	var source: FontFile = load(str(type[0])) as FontFile
	var bytes: PackedByteArray = source.data if source != null else PackedByteArray()
	var metrics: Dictionary = font_metrics(bytes)
	if metrics.is_empty():
		push_error("BookletPdf: %s cannot be read; the PDF's words are left to the reader's Helvetica"
			% type[0])
		_object(number, "<< /Type /Font /Subtype /Type1 /BaseFont /%s /Encoding /WinAnsiEncoding >>"
			% ("Helvetica-Bold" if number == _BOLD else "Helvetica"))
		return
	var file: int = _new()
	_stream(file, "/Length1 %d /Filter /FlateDecode" % bytes.size(),
		bytes.compress(FileAccess.COMPRESSION_DEFLATE))
	var descriptor: int = _new()
	var box: Array = metrics["box"]
	_object(descriptor, ("<< /Type /FontDescriptor /FontName /%s /Flags 32 /FontBBox [%d %d %d %d] "
		+ "/ItalicAngle 0 /Ascent %d /Descent %d /CapHeight %d /StemV %d /FontFile2 %d 0 R >>") % [
		type[1], box[0], box[1], box[2], box[3], metrics["ascent"], metrics["descent"],
		metrics["cap"], 140 if number == _BOLD else 80, file])
	_object(number, ("<< /Type /Font /Subtype /TrueType /BaseFont /%s /FirstChar 32 /LastChar 255 "
		+ "/Widths [%s] /Encoding /WinAnsiEncoding /FontDescriptor %d 0 R >>") % [type[1],
		" ".join(PackedStringArray((metrics["widths"] as Array).map(
			func(width: int) -> String: return str(width)))), descriptor])


## What a PDF is told of TrueType [param bytes], in thousandths of its em:
## {box [x0, y0, x1, y1], ascent, descent, cap, widths} with a width for
## each code from 32 to 255 as WinAnsi reads it. Empty when it is not one.
static func font_metrics(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 12:
		return {}
	var tables: Dictionary = {}
	for index: int in _u16(bytes, 4):
		var at: int = 12 + index * 16
		if at + 16 > bytes.size():
			return {}
		tables[bytes.slice(at, at + 4).get_string_from_ascii()] = _u32(bytes, at + 8)
	for needed: String in ["head", "hhea", "hmtx", "cmap", "OS/2"]:
		if not tables.has(needed):
			return {}
	var head: int = tables["head"]
	var em: float = maxf(1.0, _u16(bytes, head + 18))
	var thousandths := func(units: int) -> int: return roundi(units * 1000.0 / em)
	var os2: int = tables["OS/2"]
	var glyphs: Dictionary = _glyphs(bytes, tables["cmap"])
	var hmetrics: int = maxi(1, _u16(bytes, int(tables["hhea"]) + 34))
	var widths: Array = []
	for code: int in range(32, 256):
		var character: int = code
		for unicode: int in MORE:
			if MORE[unicode] == code:
				character = unicode
		var glyph: int = mini(int(glyphs.get(character, 0)), hmetrics - 1)
		widths.append(thousandths.call(_u16(bytes, int(tables["hmtx"]) + glyph * 4)))
	return {"box": [thousandths.call(_i16(bytes, head + 36)), thousandths.call(_i16(bytes, head + 38)),
			thousandths.call(_i16(bytes, head + 40)), thousandths.call(_i16(bytes, head + 42))],
		"ascent": thousandths.call(_i16(bytes, os2 + 68)),
		"descent": thousandths.call(_i16(bytes, os2 + 70)),
		"cap": thousandths.call(_i16(bytes, os2 + 88)), "widths": widths}


## The glyph of each character WinAnsi has, from the font's Unicode map
## (cmap's Windows Unicode table, format 4): character -> glyph.
static func _glyphs(bytes: PackedByteArray, cmap: int) -> Dictionary:
	var table: int = -1
	for index: int in _u16(bytes, cmap + 2):
		var record: int = cmap + 4 + index * 8
		if _u16(bytes, record) == 3 and _u16(bytes, record + 2) == 1:
			table = cmap + _u32(bytes, record + 4)
	if table < 0 or _u16(bytes, table) != 4:
		return {}
	var segments: int = _u16(bytes, table + 6) / 2
	var ends: int = table + 14
	var starts: int = ends + segments * 2 + 2
	var deltas: int = starts + segments * 2
	var offsets: int = deltas + segments * 2
	var wanted: Array = range(32, 256) + MORE.keys()
	var out: Dictionary = {}
	for character: int in wanted:
		for segment: int in segments:
			if _u16(bytes, ends + segment * 2) < character:
				continue
			var start: int = _u16(bytes, starts + segment * 2)
			if start > character:
				break
			var delta: int = _u16(bytes, deltas + segment * 2)
			var offset: int = _u16(bytes, offsets + segment * 2)
			var glyph: int = character
			if offset != 0:
				glyph = _u16(bytes, offsets + segment * 2 + offset + (character - start) * 2)
			if glyph != 0:
				out[character] = (glyph + delta) & 0xFFFF
			break
	return out


static func _u16(bytes: PackedByteArray, at: int) -> int:
	return (bytes[at] << 8) | bytes[at + 1] if at + 1 < bytes.size() else 0


static func _i16(bytes: PackedByteArray, at: int) -> int:
	var value: int = _u16(bytes, at)
	return value - 0x10000 if value >= 0x8000 else value


static func _u32(bytes: PackedByteArray, at: int) -> int:
	return (_u16(bytes, at) << 16) | _u16(bytes, at + 2)


## One page of the booklet, as read (BookletRead.feed).
func page(drawn: BookletRead.Page) -> void:
	var content := PackedStringArray()
	content.append("%s 0 0 %s 0 %s cm 1 J 1 j" % [_n(PT), _n(-PT), _n(Booklet.PAGE.y * PT)])
	var images := PackedStringArray()
	for op: Dictionary in drawn.ops:
		match op["k"]:
			"rect":
				_rect(content, op)
			"text":
				_text(content, op)
			"path":
				_path(content, op)
			"image":
				var placed: Array = _image(op)
				if placed.is_empty():
					continue
				var at: Rect2 = placed[1]
				images.append("/I%d %d 0 R" % [placed[0], placed[0]])
				content.append("q %s 0 0 %s %s %s cm /I%d Do Q" % [_n(at.size.x), _n(-at.size.y),
					_n(at.position.x), _n(at.end.y), placed[0]])
	var stream: PackedByteArray = "\n".join(content).to_ascii_buffer()
	var squeezed: PackedByteArray = stream.compress(FileAccess.COMPRESSION_DEFLATE)
	var contents: int = _new()
	_stream(contents, "/Filter /FlateDecode", squeezed)
	var number: int = _new()
	_object(number, ("<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %s %s] /Contents %d 0 R "
		+ "/Resources << /Font << /F1 %d 0 R /F2 %d 0 R >> /XObject << %s >> >> >>") % [
		_PAGES, _n(Booklet.PAGE.x * PT), _n(Booklet.PAGE.y * PT), contents, _FONT, _BOLD,
		" ".join(_unique(images))])
	_kids.append("%d 0 R" % number)
	pages += 1


## The end of the file: its pages, its title, and where each object is.
## Returns the file in memory when it was written there; empty when it was
## written to a file, or could not be (see [method ok]).
func finish(title: String) -> PackedByteArray:
	_object(_PAGES, "<< /Type /Pages /Count %d /Kids [%s] >>" % [pages, " ".join(_kids)])
	_object(_CATALOG, "<< /Type /Catalog /Pages %d 0 R >>" % _PAGES)
	var info: int = _new()
	_object(info, "<< /Title <%s> /Producer (Brickworks) /Creator (Brickworks) >>" % _utf16(title))
	var at: int = size
	var table := PackedStringArray(["xref", "0 %d" % _next, "0000000000 65535 f "])
	for number: int in range(1, _next):
		table.append("%010d 00000 n " % int(_offsets.get(number, 0)))
	table.append("trailer")
	table.append("<< /Size %d /Root %d 0 R /Info %d 0 R >>" % [_next, _CATALOG, info])
	table.append("startxref")
	table.append(str(at))
	table.append("%%EOF\n")
	_put("\n".join(table).to_ascii_buffer())
	if _file != null:
		_ok = _ok and _file.get_error() == OK
		_file.close()
		_file = null
		return PackedByteArray()
	return _bytes


## Whether everything went into the file.
func ok() -> bool:
	return _ok


func _new() -> int:
	_next += 1
	return _next - 1


func _put(bytes: PackedByteArray) -> void:
	if _file != null:
		_ok = _file.store_buffer(bytes) and _ok
	else:
		_bytes.append_array(bytes)
	size += bytes.size()


func _object(number: int, body: String) -> void:
	_offsets[number] = size
	_put(("%d 0 obj\n%s\nendobj\n" % [number, body]).to_ascii_buffer())


func _stream(number: int, dictionary: String, data: PackedByteArray) -> void:
	_offsets[number] = size
	_put(("%d 0 obj\n<< %s /Length %d >>\nstream\n" % [number, dictionary, data.size()]).to_ascii_buffer())
	_put(data)
	_put("\nendstream\nendobj\n".to_ascii_buffer())


## A picture's object and where it goes: [number, Rect2], or [] when it
## could not be read. A JPEG goes in as it is; anything else is laid on
## the colour behind it, as the page shows it, and kept without loss.
func _image(op: Dictionary) -> Array:
	var part: String = op["part"]
	var at: Rect2 = op["at"]
	var on: Color = op["on"]
	if not part.is_empty():
		var key: String = part + on.to_html(false)
		if not _parts.has(key):
			var source: String = str(_read.parts.get(part, ""))
			var made: Array = _picture(source, on) if not source.is_empty() else []
			_parts[key] = made
		var kept: Array = _parts[key]
		if kept.is_empty():
			return []
		# Fitted inside its box and stood on its foot (background-size:
		# contain, position: center bottom).
		var natural: Vector2 = kept[1]
		var scale: float = minf(at.size.x / maxf(natural.x, 1.0), at.size.y / maxf(natural.y, 1.0))
		var fitted: Vector2 = natural * scale
		return [kept[0], Rect2(Vector2(at.position.x + (at.size.x - fitted.x) * 0.5,
			at.end.y - fitted.y), fitted)]
	var made: Array = _picture(str(op["src"]), on)
	return [made[0], at] if not made.is_empty() else []


## [object number, size in pixels] of the picture in data URI [param uri].
func _picture(uri: String, on: Color) -> Array:
	var comma: int = uri.find(",")
	if not uri.begins_with("data:") or comma < 0:
		return []
	var bytes: PackedByteArray = Marshalls.base64_to_raw(uri.substr(comma + 1))
	if uri.begins_with("data:image/jpeg"):
		var shape: Vector3i = jpeg_shape(bytes)
		if shape.x > 0:
			var number: int = _new()
			_stream(number, ("/Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace %s "
				+ "/BitsPerComponent 8 /Filter /DCTDecode") % [shape.x, shape.y,
				"/DeviceGray" if shape.z == 1 else "/DeviceRGB"], bytes)
			return [number, Vector2(shape.x, shape.y)]
	var image := Image.new()
	var error: int = ERR_FILE_UNRECOGNIZED
	if uri.begins_with("data:image/webp"):
		error = image.load_webp_from_buffer(bytes)
	elif uri.begins_with("data:image/png"):
		error = image.load_png_from_buffer(bytes)
	elif uri.begins_with("data:image/jpeg"):
		error = image.load_jpg_from_buffer(bytes)
	if error != OK or image.is_empty():
		return []
	image.convert(Image.FORMAT_RGBA8)
	var laid := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	laid.fill(Color(on, 1.0))
	laid.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	laid.convert(Image.FORMAT_RGB8)
	var number: int = _new()
	_stream(number, ("/Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB "
		+ "/BitsPerComponent 8 /Filter /FlateDecode") % [laid.get_width(), laid.get_height()],
		laid.get_data().compress(FileAccess.COMPRESSION_DEFLATE))
	return [number, Vector2(laid.get_width(), laid.get_height())]


## A JPEG's width, height and colour channels, from its frame header;
## zero when it has none.
static func jpeg_shape(bytes: PackedByteArray) -> Vector3i:
	var at: int = 2
	while at + 9 < bytes.size():
		if bytes[at] != 0xFF:
			return Vector3i.ZERO
		var marker: int = bytes[at + 1]
		if marker == 0xFF:
			at += 1
			continue
		var length: int = (bytes[at + 2] << 8) | bytes[at + 3]
		if marker >= 0xC0 and marker <= 0xCF and marker != 0xC4 and marker != 0xC8 and marker != 0xCC:
			return Vector3i((bytes[at + 7] << 8) | bytes[at + 8], (bytes[at + 5] << 8) | bytes[at + 6],
				bytes[at + 9])
		at += 2 + length
	return Vector3i.ZERO


func _rect(content: PackedStringArray, op: Dictionary) -> void:
	var at: Rect2 = op["at"]
	var fill: Color = op["fill"]
	var line: Color = op["line"]
	var width: float = op["width"]
	var radius: float = op["radius"]
	if fill.a > 0.0:
		content.append("%s rg %s f" % [_rgb(fill), _rounded(at, radius)])
	# The edge inside the box, as a browser draws a border.
	if line.a > 0.0 and width > 0.0:
		content.append("%s RG %s w %s S" % [_rgb(line), _n(width),
			_rounded(at.grow(-width * 0.5), maxf(0.0, radius - width * 0.5))])


func _text(content: PackedStringArray, op: Dictionary) -> void:
	var at: Vector2 = op["at"]
	var spacing: float = op["spacing"]
	content.append("BT /%s %s Tf %s Tc 1 0 0 -1 %s %s Tm %s rg <%s> Tj ET" % [
		"F2" if op["bold"] else "F1", _n(op["size"]), _n(spacing), _n(at.x), _n(at.y),
		_rgb(op["colour"]), win_ansi(str(op["text"])).hex_encode()])


func _path(content: PackedStringArray, op: Dictionary) -> void:
	var fill: Color = op["fill"]
	var line: Color = op["line"]
	var shape := PackedStringArray()
	for points: PackedVector2Array in op["lines"]:
		for index: int in points.size():
			shape.append("%s %s %s" % [_n(points[index].x), _n(points[index].y), "m" if index == 0 else "l"])
		if op["closed"]:
			shape.append("h")
	if shape.is_empty():
		return
	var path: String = " ".join(shape)
	var stroke: String = "%s RG %s w %s S" % [_rgb(line), _n(op["width"]), path] if line.a > 0.0 else ""
	var filled: String = "%s rg %s f" % [_rgb(fill), path] if fill.a > 0.0 and op["closed"] else ""
	if op["stroke_first"]:
		content.append(stroke)
		content.append(filled)
	else:
		content.append(filled)
		content.append(stroke)


## A box with round corners as a path: four lines and four quarter curves.
static func _rounded(at: Rect2, radius: float) -> String:
	var r: float = minf(radius, minf(at.size.x, at.size.y) * 0.5)
	var x0: float = at.position.x
	var y0: float = at.position.y
	var x1: float = at.end.x
	var y1: float = at.end.y
	if r <= 0.01:
		return "%s %s %s %s re" % [_n(x0), _n(y0), _n(at.size.x), _n(at.size.y)]
	var c: float = r * 0.4477
	return " ".join([
		"%s %s m" % [_n(x0 + r), _n(y0)],
		"%s %s l" % [_n(x1 - r), _n(y0)],
		"%s %s %s %s %s %s c" % [_n(x1 - c), _n(y0), _n(x1), _n(y0 + c), _n(x1), _n(y0 + r)],
		"%s %s l" % [_n(x1), _n(y1 - r)],
		"%s %s %s %s %s %s c" % [_n(x1), _n(y1 - c), _n(x1 - c), _n(y1), _n(x1 - r), _n(y1)],
		"%s %s l" % [_n(x0 + r), _n(y1)],
		"%s %s %s %s %s %s c" % [_n(x0 + c), _n(y1), _n(x0), _n(y1 - c), _n(x0), _n(y1 - r)],
		"%s %s l" % [_n(x0), _n(y0 + r)],
		"%s %s %s %s %s %s c h" % [_n(x0), _n(y0 + c), _n(x0 + c), _n(y0), _n(x0 + r), _n(y0)]])


## Words in the font's encoding (WinAnsi): Latin-1, and the dashes,
## quotes, ellipsis and trademark sign; "?" for anything else.
static func win_ansi(text: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(text.length())
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code < 0x80 or code >= 0xA0 and code <= 0xFF:
			out[index] = code
		else:
			out[index] = int(MORE.get(code, 0x3F))
	return out


static func _utf16(text: String) -> String:
	var bytes: PackedByteArray = text.to_utf16_buffer()
	# Big-endian, after its mark, as a PDF's text string is.
	var out := PackedByteArray([0xFE, 0xFF])
	for index: int in range(0, bytes.size() - 1, 2):
		out.append(bytes[index + 1])
		out.append(bytes[index])
	return out.hex_encode()


static func _unique(names: PackedStringArray) -> PackedStringArray:
	var seen: Dictionary = {}
	for name: String in names:
		seen[name] = true
	return PackedStringArray(seen.keys())


static func _rgb(colour: Color) -> String:
	return "%s %s %s" % [_n(colour.r), _n(colour.g), _n(colour.b)]


static func _n(value: float) -> String:
	return String.num(value, 3)
