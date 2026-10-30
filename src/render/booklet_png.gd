## A booklet's pages saved as pictures, a PNG a page, in one zip: what
## Studio's Instruction Maker saves beside its PDF, for a page to go on a
## web page or into a document of its own.
##
## Each page is what BookletRead reads off the booklet's own page, drawn
## here as the browser draws it, at 300 dots an inch, what a page is
## printed at, and said so in the PNG (its pHYs): the words, lines and
## boxes are as sharp as print, and a step's picture is the booklet's own,
## drawn smooth to that size. The words are set in the type the PDF
## carries (BookletPdf.TYPE), so a page reads alike on every computer and
## on the web, which has no Helvetica of its own. Each is written into the
## zip before the next is drawn: one page held at a time. One zip, on the
## desktop and on the web alike, because a browser asked for 590 downloads
## at once gives one.
class_name BookletPng
extends Node

## Dots an inch a page is drawn at.
const DPI := 300.0
## The most pixels a booklet's pages are drawn in on the web, all told,
## where the zip is handed to the browser whole, from memory: 134 pages at
## 300 dots an inch. A longer booklet is drawn as fine as that allows (the
## castle's 324 pages at 193 dots an inch), and a zip of Orthanc's at 300
## is not left to run the tab out of memory.
const WEB_MOST_PIXELS := 1.0e9
## Pixels a millimetre a page is drawn at.
var px_per_mm: float = DPI / 25.4
var pages: int = 0
var _viewport: SubViewport
var _canvas: RID
var _read: BookletRead
var _zip: ZIPPacker
var _name: String = ""
var _fonts: Array[Font] = []
var _part_textures: Dictionary = {}
var _dpi_chunk := PackedByteArray()
var _fixed: bool = false


## Draw at [param density] pixels a millimetre rather than at 300 dots an
## inch (a check, drawing at the browser's own size).
func at_density(density: float) -> void:
	px_per_mm = density
	_fixed = true


## Pixels a millimetre for [param pages] pages on the web: 300 dots an
## inch, or as fine as WEB_MOST_PIXELS allows.
static func web_density(pages: int) -> float:
	var area: float = Booklet.PAGE.x * Booklet.PAGE.y * maxf(1.0, pages)
	return minf(DPI / 25.4, sqrt(WEB_MOST_PIXELS / area))


## Every page of the booklet [param from] (a file's path, or a browser
## tab's document, as BookletRead.read_all) into the zip at [param to],
## each named [param name]-001.png and on. Returns the pages written, -1
## when nothing could be.
func write(from: Variant, to: String, name: String, pace: int = 0) -> int:
	_read = BookletRead.new()
	_zip = ZIPPacker.new()
	if _zip.open(to) != OK:
		return -1
	# A PNG is as small as it will be: squeezed again it takes longer for
	# nothing.
	_zip.compression_level = ZIPPacker.COMPRESSION_NONE
	_name = name
	if from is JavaScriptObject and not _fixed:
		var sections: JavaScriptObject = (from as JavaScriptObject).querySelectorAll("section.page")
		px_per_mm = web_density(int(sections.length))
	_fonts = []
	for type: Array in BookletPdf.TYPE:
		_fonts.append(load(str(type[0])) as Font)
	_dpi_chunk = dpi_chunk(px_per_mm)
	var count: int = await _read.read_all(from, _page, pace)
	_zip.close()
	_free()
	return count


func _free() -> void:
	if _canvas.is_valid():
		RenderingServer.free_rid(_canvas)
		_canvas = RID()
	if is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = null
	_part_textures.clear()


## A PNG's pHYs chunk saying it is [param density] pixels a millimetre,
## for a program that prints or places it to size it by.
static func dpi_chunk(density: float) -> PackedByteArray:
	var body := PackedByteArray("pHYs".to_ascii_buffer())
	var per_metre: int = roundi(density * 1000.0)
	for at: int in 2:
		for shift: int in [24, 16, 8, 0]:
			body.append((per_metre >> shift) & 0xFF)
	body.append(1)
	var out := PackedByteArray([0, 0, 0, 9])
	out.append_array(body)
	var crc: int = _crc32(body)
	for shift: int in [24, 16, 8, 0]:
		out.append((crc >> shift) & 0xFF)
	return out


## PNG's CRC (ISO 3309) of [param bytes], bit by bit: a chunk of a few
## bytes, once a save.
static func _crc32(bytes: PackedByteArray) -> int:
	var crc: int = 0xFFFFFFFF
	for byte: int in bytes:
		crc ^= byte
		for bit: int in 8:
			crc = (crc >> 1) ^ (0xEDB88320 if crc & 1 else 0)
	return crc ^ 0xFFFFFFFF


## [param png] with [param chunk] after its header (IHDR, the first 33
## bytes with the signature), where pHYs goes.
static func _with_chunk(png: PackedByteArray, chunk: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = png.slice(0, 33)
	out.append_array(chunk)
	out.append_array(png.slice(33))
	return out


func _page(page: BookletRead.Page) -> void:
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.size = Vector2i((Booklet.PAGE * px_per_mm).round())
		_viewport.transparent_bg = false
		_viewport.disable_3d = true
		_viewport.msaa_2d = Viewport.MSAA_4X
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_viewport)
		_canvas = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(_canvas, _viewport.find_world_2d().canvas)
	RenderingServer.canvas_item_clear(_canvas)
	var kept: Array = []
	for op: Dictionary in page.ops:
		match op["k"]:
			"rect":
				_rect(op)
			"text":
				_text(op)
			"path":
				_path(op)
			"image":
				var texture: Texture2D = _texture(op)
				if texture == null:
					continue
				kept.append(texture)
				RenderingServer.canvas_item_add_texture_rect(_canvas, _placed(op, texture),
					texture.get_rid())
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	# Drawn now, not at the next frame: asked from a browser tab in front,
	# the app's own is out of view and is given none.
	RenderingServer.force_draw(false)
	var image: Image = _viewport.get_texture().get_image()
	kept.clear()
	if image == null or image.is_empty():
		return
	image.convert(Image.FORMAT_RGB8)
	_zip.start_file("%s-%03d.png" % [_name, page.number])
	_zip.write_file(_with_chunk(image.save_png_to_buffer(), _dpi_chunk))
	_zip.close_file()
	pages += 1


func _px(mm: Vector2) -> Vector2:
	return mm * px_per_mm


func _rect(op: Dictionary) -> void:
	var at: Rect2 = op["at"]
	var box := StyleBoxFlat.new()
	box.bg_color = op["fill"]
	box.anti_aliasing = true
	box.set_corner_radius_all(roundi(float(op["radius"]) * px_per_mm))
	var line: Color = op["line"]
	if line.a > 0.0 and float(op["width"]) > 0.0:
		box.border_color = line
		box.set_border_width_all(maxi(1, roundi(float(op["width"]) * px_per_mm)))
	box.draw(_canvas, Rect2(_px(at.position), _px(at.size)))


func _text(op: Dictionary) -> void:
	var font: Font = _fonts[1 if op["bold"] else 0]
	var size: int = maxi(1, roundi(float(op["size"]) * px_per_mm))
	var at: Vector2 = _px(op["at"])
	var text: String = op["text"]
	var spacing: float = float(op["spacing"]) * px_per_mm
	if absf(spacing) < 0.3:
		font.draw_string(_canvas, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, op["colour"])
		return
	# Letter by letter where the letters are set closer (a step number).
	for index: int in text.length():
		var letter: String = text[index]
		font.draw_char(_canvas, at, letter.unicode_at(0), size, op["colour"])
		at.x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing


func _path(op: Dictionary) -> void:
	var fill: Color = op["fill"]
	var line: Color = op["line"]
	var width: float = maxf(1.0, float(op["width"]) * px_per_mm)
	var shapes: Array = []
	for points: PackedVector2Array in op["lines"]:
		var scaled := PackedVector2Array()
		for point: Vector2 in points:
			scaled.append(point * px_per_mm)
		shapes.append(scaled)
	var stroke := func() -> void:
		if line.a <= 0.0:
			return
		for scaled: PackedVector2Array in shapes:
			var drawn: PackedVector2Array = scaled
			if op["closed"] and scaled.size() > 2:
				drawn = scaled.duplicate()
				drawn.append(scaled[0])
			RenderingServer.canvas_item_add_polyline(_canvas, drawn, PackedColorArray([line]),
				width, true)
	var filled := func() -> void:
		if fill.a <= 0.0 or not op["closed"]:
			return
		for scaled: PackedVector2Array in shapes:
			if scaled.size() >= 3:
				RenderingServer.canvas_item_add_polygon(_canvas, scaled, PackedColorArray([fill]))
	if op["stroke_first"]:
		stroke.call()
		filled.call()
	else:
		filled.call()
		stroke.call()


func _texture(op: Dictionary) -> Texture2D:
	var part: String = op["part"]
	if not part.is_empty():
		if not _part_textures.has(part):
			_part_textures[part] = _decoded(str(_read.parts.get(part, "")))
		return _part_textures[part]
	return _decoded(str(op["src"]))


static func _decoded(uri: String) -> Texture2D:
	var comma: int = uri.find(",")
	if not uri.begins_with("data:") or comma < 0:
		return null
	var bytes: PackedByteArray = Marshalls.base64_to_raw(uri.substr(comma + 1))
	var image := Image.new()
	var error: int = ERR_FILE_UNRECOGNIZED
	if uri.begins_with("data:image/jpeg"):
		error = image.load_jpg_from_buffer(bytes)
	elif uri.begins_with("data:image/webp"):
		error = image.load_webp_from_buffer(bytes)
	elif uri.begins_with("data:image/png"):
		error = image.load_png_from_buffer(bytes)
	if error != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


## Where a picture goes in pixels: its box, or, for a part's, fitted
## inside it and stood on its foot.
func _placed(op: Dictionary, texture: Texture2D) -> Rect2:
	var at: Rect2 = op["at"]
	if str(op["part"]).is_empty():
		return Rect2(_px(at.position), _px(at.size))
	var natural := Vector2(texture.get_width(), texture.get_height())
	var scale: float = minf(at.size.x / maxf(natural.x, 1.0), at.size.y / maxf(natural.y, 1.0))
	var fitted: Vector2 = natural * scale
	return Rect2(_px(Vector2(at.position.x + (at.size.x - fitted.x) * 0.5, at.end.y - fitted.y)),
		_px(fitted))
