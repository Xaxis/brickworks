## A model's sticker sheet, to print on sticker paper and cut out: every
## sticker the model uses, at its true size, with a cut line round each.
##
## Two ways out. A PDF of one A4 page, whose page and every sticker are
## sized in points from millimetres (72 to the inch, 25.4 mm to the inch),
## so printed at "actual size" a sticker is the size of the faces it goes
## on, to the hundredth of a millimetre the arithmetic carries; each
## sticker is its own picture at the resolution it was drawn (ten pixels to
## the LDU: 635 dpi). And a PNG at 300 dpi or more, its PNG header saying
## so (a pHYs chunk), for printers that take pictures. Both carry a 50 mm
## scale bar, so a printout can be checked with a ruler before it is cut.
##
## A sticker's size is its part's (Stickers): the faces it covers less
## LEGO's 0.1 mm a side and a margin, so it sits inside the real part's
## face, as LEGO's own stickers do.
class_name StickerSheet
extends RefCounted

const PAGE_MM := Vector2(210.0, 297.0)
const MARGIN_MM := 12.0
const GAP_MM := 6.0
const LABEL_MM := 2.6
const POINTS_PER_MM := 72.0 / 25.4
## The cut line's colour: a blue a cutting machine and an eye both find.
const CUT := Color(0.0, 0.55, 0.95)
const SCALE_BAR_MM := 50.0


## One sticker on the sheet.
class Item extends RefCounted:
	var picture: Image
	var size_mm := Vector2.ZERO
	var label: String = ""
	## Where it goes on the page, from its top left, in mm (layout()).
	var at_mm := Vector2.ZERO


## The stickers of a model, one item for each placed: [Item].
static func items_for(world: BrickWorld, library: PartLibrary) -> Array:
	var out: Array = []
	var used: Dictionary = Stickers.in_model(world, library)
	var ids: Array = used.keys()
	ids.sort()
	for id: String in ids:
		var picture: Image = _picture(library, id)
		var size: Vector2 = Stickers.size_of(library, id) * Lbm.LDU_MM
		var info: PartLibrary.PartInfo = library.parts.get(id)
		for n: int in (used[id] as PackedInt64Array).size():
			var item := Item.new()
			item.picture = picture
			item.size_mm = size
			item.label = "%s  %s x %s mm" % [_title(info.name if info != null else id),
				String.num(size.x, 1), String.num(size.y, 1)]
			out.append(item)
	return out


## A sticker's picture, from its built part.
static func _picture(library: PartLibrary, id: String) -> Image:
	var mesh: Lbm.PartMesh = library.mesh_for(id)
	if mesh != null:
		for name: String in mesh.print_files:
			var picture := Image.new()
			if picture.load_png_from_buffer(mesh.print_files[name]) == OK:
				return picture
	return Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)


static func _title(name: String) -> String:
	var cut: int = name.find(" mm, ")
	return name.substr(cut + 5) if cut > 0 else name


## Lay the items out across the page from its top left, in rows, each with
## room for its label under it. Returns how many fit.
static func layout(items: Array) -> int:
	var x: float = MARGIN_MM
	var y: float = MARGIN_MM + 14.0
	var row: float = 0.0
	var placed: int = 0
	for item: Item in items:
		if x + item.size_mm.x > PAGE_MM.x - MARGIN_MM and x > MARGIN_MM:
			x = MARGIN_MM
			y += row + LABEL_MM + GAP_MM
			row = 0.0
		if y + item.size_mm.y + LABEL_MM > PAGE_MM.y - MARGIN_MM:
			break
		item.at_mm = Vector2(x, y)
		x += item.size_mm.x + GAP_MM
		row = maxf(row, item.size_mm.y)
		placed += 1
	return placed


# -- the PDF ---------------------------------------------------------------------------


## The sheet as a PDF of one A4 page.
static func pdf(items: Array, title: String) -> PackedByteArray:
	var placed: int = layout(items)
	var objects: Array[PackedByteArray] = []
	# 1 catalogue, 2 pages, 3 page, 4 font, 5 contents, then the images.
	objects.append("<< /Type /Catalog /Pages 2 0 R >>".to_ascii_buffer())
	objects.append("<< /Type /Pages /Kids [3 0 R] /Count 1 >>".to_ascii_buffer())
	var images := PackedStringArray()
	var image_objects: Array[PackedByteArray] = []
	var drawn: Dictionary = {}      ## picture -> its name, each drawn once
	var names := PackedStringArray()
	for n: int in placed:
		var item: Item = items[n]
		if not drawn.has(item.picture):
			var name: String = "Im%d" % (drawn.size() + 1)
			drawn[item.picture] = name
			images.append("/%s %d 0 R" % [name, 6 + image_objects.size()])
			image_objects.append(_image_object(item.picture))
		names.append(drawn[item.picture])
	var page_w: float = PAGE_MM.x * POINTS_PER_MM
	var page_h: float = PAGE_MM.y * POINTS_PER_MM
	var page: String = ("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %s %s] /Resources << "
		+ "/Font << /F1 4 0 R >> /XObject << %s >> >> /Contents 5 0 R >>") % [_pt(page_w),
		_pt(page_h), " ".join(images)]
	objects.append(page.to_ascii_buffer())
	objects.append("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>".to_ascii_buffer())
	var ops := PackedStringArray()
	ops.append("BT /F1 11 Tf %s %s Td (%s) Tj ET" % [_pt(MARGIN_MM * POINTS_PER_MM),
		_pt(page_h - (MARGIN_MM + 4.0) * POINTS_PER_MM),
		_escape("%s: stickers. Print at actual size (100%%), not fitted to the page." % title)])
	# The scale bar: 50 mm, ticked every 10.
	var bar_y: float = page_h - (MARGIN_MM + 9.0) * POINTS_PER_MM
	var bar_x: float = MARGIN_MM * POINTS_PER_MM
	ops.append("0 0 0 RG 0.5 w %s %s m %s %s l S" % [_pt(bar_x), _pt(bar_y),
		_pt(bar_x + SCALE_BAR_MM * POINTS_PER_MM), _pt(bar_y)])
	for tick: int in 6:
		var tx: float = bar_x + tick * 10.0 * POINTS_PER_MM
		ops.append("%s %s m %s %s l S" % [_pt(tx), _pt(bar_y), _pt(tx), _pt(bar_y + 2.0 * POINTS_PER_MM)])
	ops.append("BT /F1 7 Tf %s %s Td (50 mm) Tj ET" % [_pt(bar_x + (SCALE_BAR_MM + 2.0) * POINTS_PER_MM),
		_pt(bar_y)])
	for n: int in placed:
		var item: Item = items[n]
		var w: float = item.size_mm.x * POINTS_PER_MM
		var h: float = item.size_mm.y * POINTS_PER_MM
		var x: float = item.at_mm.x * POINTS_PER_MM
		var y: float = page_h - (item.at_mm.y + item.size_mm.y) * POINTS_PER_MM
		# The picture filling the sticker exactly: an image is drawn into
		# the unit square, scaled by the cm matrix.
		ops.append("q %s 0 0 %s %s %s cm /%s Do Q" % [_pt(w), _pt(h), _pt(x), _pt(y), names[n]])
		ops.append("%s %s %s RG 0.3 w %s %s %s %s re S" % [_pt(CUT.r), _pt(CUT.g), _pt(CUT.b),
			_pt(x), _pt(y), _pt(w), _pt(h)])
		ops.append("BT /F1 6 Tf %s %s Td (%s) Tj ET" % [_pt(x),
			_pt(y - (LABEL_MM - 0.4) * POINTS_PER_MM), _escape(item.label)])
	var content: PackedByteArray = "\n".join(ops).to_ascii_buffer()
	var stream: PackedByteArray = ("<< /Length %d >>\nstream\n" % content.size()).to_ascii_buffer()
	stream.append_array(content)
	stream.append_array("\nendstream".to_ascii_buffer())
	objects.append(stream)
	objects.append_array(image_objects)
	var out := "%PDF-1.4\n%âãÏÓ\n".to_utf8_buffer()
	var offsets := PackedInt64Array()
	for n: int in objects.size():
		offsets.append(out.size())
		out.append_array(("%d 0 obj\n" % (n + 1)).to_ascii_buffer())
		out.append_array(objects[n])
		out.append_array("\nendobj\n".to_ascii_buffer())
	var xref: int = out.size()
	out.append_array(("xref\n0 %d\n0000000000 65535 f \n" % (objects.size() + 1)).to_ascii_buffer())
	for offset: int in offsets:
		out.append_array(("%010d 00000 n \n" % offset).to_ascii_buffer())
	out.append_array(("trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n"
		% [objects.size() + 1, xref]).to_ascii_buffer())
	return out


## A picture as a PDF image: on white (sticker paper is white), RGB, its
## bytes deflated (zlib's format, which is FlateDecode's).
static func _image_object(picture: Image) -> PackedByteArray:
	var flat := Image.create_empty(picture.get_width(), picture.get_height(), false,
		Image.FORMAT_RGBA8)
	flat.fill(Color.WHITE)
	var copy: Image = picture.duplicate()
	if copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)
	flat.blend_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), Vector2i.ZERO)
	flat.convert(Image.FORMAT_RGB8)
	var packed: PackedByteArray = flat.get_data().compress(FileAccess.COMPRESSION_DEFLATE)
	var head := ("<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB "
		+ "/BitsPerComponent 8 /Filter /FlateDecode /Length %d >>\nstream\n") % [flat.get_width(),
		flat.get_height(), packed.size()]
	var out: PackedByteArray = head.to_ascii_buffer()
	out.append_array(packed)
	out.append_array("\nendstream".to_ascii_buffer())
	return out


static func _pt(value: float) -> String:
	return String.num(value, 4)


static func _escape(text: String) -> String:
	var out: String = ""
	for character: String in text:
		if character in ["(", ")", "\\"]:
			out += "\\" + character
		elif character.unicode_at(0) < 128:
			out += character
		else:
			out += "-" if character in ["—", "–"] else "?"
	return out


# -- the PNG -----------------------------------------------------------------------


## The sheet as a picture at [param dpi], the same layout as the PDF.
static func picture(items: Array, title: String, dpi: float = 300.0) -> Image:
	var placed: int = layout(items)
	var per_mm: float = dpi / 25.4
	var page := Image.create_empty(roundi(PAGE_MM.x * per_mm), roundi(PAGE_MM.y * per_mm), false,
		Image.FORMAT_RGBA8)
	page.fill(Color.WHITE)
	var px := func(mm: float) -> int: return roundi(mm * per_mm)
	PrintPaint.write(page, Vector2(px.call(MARGIN_MM), px.call(MARGIN_MM + 4.0)),
		"%s: stickers. Print at actual size (100%%) and %d dpi." % [title, int(dpi)],
		maxi(8, px.call(3.6)), Color.BLACK)
	var bar_y: int = px.call(MARGIN_MM + 9.0)
	var bar_x: int = px.call(MARGIN_MM)
	var line: int = maxi(1, px.call(0.18))
	page.fill_rect(Rect2i(bar_x, bar_y, px.call(SCALE_BAR_MM), line), Color.BLACK)
	for tick: int in 6:
		page.fill_rect(Rect2i(bar_x + px.call(tick * 10.0), bar_y - px.call(2.0), line, px.call(2.0)),
			Color.BLACK)
	PrintPaint.write(page, Vector2(bar_x + px.call(SCALE_BAR_MM + 2.0), bar_y + px.call(1.0)),
		"50 mm", maxi(8, px.call(2.5)), Color.BLACK)
	for n: int in placed:
		var item: Item = items[n]
		var at := Vector2i(px.call(item.at_mm.x), px.call(item.at_mm.y))
		var size := Vector2i(px.call(item.at_mm.x + item.size_mm.x) - at.x,
			px.call(item.at_mm.y + item.size_mm.y) - at.y)
		var art: Image = item.picture.duplicate()
		if art.get_format() != Image.FORMAT_RGBA8:
			art.convert(Image.FORMAT_RGBA8)
		art.resize(maxi(1, size.x), maxi(1, size.y), Image.INTERPOLATE_LANCZOS)
		page.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), at)
		# The cut line, a pixel on the sticker's edge all round.
		page.fill_rect(Rect2i(at.x, at.y, size.x, 1), CUT)
		page.fill_rect(Rect2i(at.x, at.y + size.y - 1, size.x, 1), CUT)
		page.fill_rect(Rect2i(at.x, at.y, 1, size.y), CUT)
		page.fill_rect(Rect2i(at.x + size.x - 1, at.y, 1, size.y), CUT)
		PrintPaint.write(page, Vector2(at.x, at.y + size.y + px.call(LABEL_MM - 0.4)), item.label,
			maxi(8, px.call(2.0)), Color(0.2, 0.2, 0.2))
	return page


## The picture as PNG bytes that say their resolution: a pHYs chunk after
## the header, in pixels per metre, which is how a PNG says its dpi.
static func png_bytes(page: Image, dpi: float) -> PackedByteArray:
	var bytes: PackedByteArray = page.save_png_to_buffer()
	var per_metre: int = roundi(dpi / 0.0254)
	var chunk := PackedByteArray()
	chunk.append_array("pHYs".to_ascii_buffer())
	for value: int in [per_metre, per_metre]:
		chunk.append_array([(value >> 24) & 0xff, (value >> 16) & 0xff, (value >> 8) & 0xff,
			value & 0xff])
	chunk.append(1)
	var length := PackedByteArray([0, 0, 0, 9])
	var crc: int = _crc32(chunk)
	var tail := PackedByteArray([(crc >> 24) & 0xff, (crc >> 16) & 0xff, (crc >> 8) & 0xff,
		crc & 0xff])
	# After the signature (8 bytes) and IHDR (4 + 4 + 13 + 4 = 25).
	var out: PackedByteArray = bytes.slice(0, 33)
	out.append_array(length)
	out.append_array(chunk)
	out.append_array(tail)
	out.append_array(bytes.slice(33))
	return out


static var _crc_table := PackedInt64Array()


static func _crc32(bytes: PackedByteArray) -> int:
	if _crc_table.is_empty():
		_crc_table.resize(256)
		for n: int in 256:
			var c: int = n
			for _k: int in 8:
				c = (0xEDB88320 ^ (c >> 1)) if (c & 1) else (c >> 1)
			_crc_table[n] = c
	var crc: int = 0xFFFFFFFF
	for value: int in bytes:
		crc = _crc_table[(crc ^ value) & 0xff] ^ (crc >> 8)
	return crc ^ 0xFFFFFFFF


## The dpi a PNG says it is, from its pHYs chunk, or 0.
static func png_dpi(bytes: PackedByteArray) -> float:
	var at: int = 8
	while at + 8 <= bytes.size():
		var length: int = (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3]
		var kind: String = bytes.slice(at + 4, at + 8).get_string_from_ascii()
		if kind == "pHYs":
			var o: int = at + 8
			var per_metre: int = (bytes[o] << 24) | (bytes[o + 1] << 16) | (bytes[o + 2] << 8) | bytes[o + 3]
			return per_metre * 0.0254
		at += 12 + length
	return 0.0
