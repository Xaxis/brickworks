## A booklet's pages saved as pictures, a PNG a page, in one zip: what
## Studio's Instruction Maker saves beside its PDF, for a page to go on a
## web page or into a document of its own.
##
## Each page is what BookletRead reads off the booklet's own page, drawn
## here as the browser draws it, at the booklet's own pictures' size (so a
## step's picture is its pixels, not stretched), and written into the zip
## before the next is drawn: one page held at a time. One zip, on the
## desktop and on the web alike, because a browser asked for 590 downloads
## at once gives one.
class_name BookletPng
extends Node

## Pixels a millimetre: the booklet's own pictures', found on its first
## page (see [method _density]), or this when it has none.
var px_per_mm: float = 4.0
var pages: int = 0
var _viewport: SubViewport
var _canvas: RID
var _read: BookletRead
var _zip: ZIPPacker
var _name: String = ""
var _fonts: Array[Font] = []
var _part_textures: Dictionary = {}
var _decided: bool = false
var _fixed: float = 0.0


## Draw at [param density] pixels a millimetre rather than the booklet's
## own (a check, drawing at the browser's own size).
func at_density(density: float) -> void:
	_fixed = density


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
	var regular := SystemFont.new()
	regular.font_names = PackedStringArray(["Helvetica Neue", "Helvetica", "Arial",
		"Liberation Sans", "Nimbus Sans", "sans-serif"])
	var bold: SystemFont = regular.duplicate()
	bold.font_weight = 700
	_fonts = [regular, bold]
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
	_part_textures.clear()


## The booklet's pictures' pixels a millimetre: its first picture's width
## over its width on the page.
func _density(page: BookletRead.Page) -> float:
	if _fixed > 0.0:
		return _fixed
	for op: Dictionary in page.ops:
		if op["k"] != "image" or str(op["src"]).is_empty():
			continue
		var uri: String = op["src"]
		if uri.begins_with("data:image/jpeg"):
			var shape: Vector3i = BookletPdf.jpeg_shape(
				Marshalls.base64_to_raw(uri.substr(uri.find(",") + 1)))
			var wide: float = (op["at"] as Rect2).size.x
			if shape.x > 0 and wide > 20.0:
				return clampf(shape.x / wide, 2.0, 12.0)
	return px_per_mm


func _page(page: BookletRead.Page) -> void:
	if not _decided:
		_decided = true
		px_per_mm = _density(page)
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
	_zip.write_file(image.save_png_to_buffer())
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
