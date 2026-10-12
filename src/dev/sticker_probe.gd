## Pictures brought in and placed on any part's face, and stickers.
##
##   godot --headless --path . --script src/dev/sticker_probe.gd
##
## Pictures: an SVG logo and a photograph read in; placed on a face fitted,
## moved, turned, cropped, see-through, their background cleared, kept in
## full colour or mapped to LEGO's inks (at most so many); snapped to the
## face's edges; the starters drawn for any canvas; a dish's curved top
## and a round tile's round top printed; a photograph on a 2 x 2 tile and a
## logo on a 2 x 4 slope made into parts filed under My prints.
##
## Stickers: two 1 x 4 tiles side by side, a click on one finds the face
## of both; the sticker for it is their size less LEGO's 0.1 mm a side and
## a margin, made, stuck on through the builder (one undo takes it off), on
## the faces exactly, stuck to both tiles, peeled off and back. The model
## file carries it and a library that never saw it builds it with its
## picture. The sticker sheet is written as a PDF and a 300 dpi PNG and
## measured: the PDF rendered by pdftoppm at 600 dpi, the cut line found
## and its width and height in millimetres compared with the sticker's and
## with the real tiles' faces.
##
## Made parts go to user://sticker_probe_parts/, never the person's own.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary

const PROBE_DIR := "user://sticker_probe_parts/"
const LOGO := """<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 200 100">
<rect width="200" height="100" fill="#ffffff"/>
<circle cx="50" cy="50" r="40" fill="#c91a09"/>
<rect x="100" y="20" width="90" height="60" fill="#0055bf"/>
<path d="M30 50 L50 25 L70 50 L50 75 Z" fill="#f2cd37"/>
</svg>"""


func _initialize() -> void:
	_run()


func _run() -> void:
	_forget(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	await process_frame
	_pictures()
	_curved()
	await _stickers()
	_forget(PROBE_DIR + "elsewhere/")
	_forget(PROBE_DIR)
	if _failures == 0:
		print("\npictures go on any face and stickers on any faces, and the sheet prints true to size")
	else:
		print("\n%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


# -- pictures -------------------------------------------------------------------------


func _palette() -> Array[Color]:
	var out: Array[Color] = []
	for code: int in [0, 15, 4, 1, 14, 2, 71, 72, 70, 25, 19, 28, 320, 272, 288, 308]:
		var colour: Color = _library.color(code).rgb
		colour.a = 1.0
		out.append(colour)
	return out


## A photograph's worth of colour: a sky, a sun, a hill, every pixel a
## little different.
func _photo() -> Image:
	var photo := Image.create_empty(640, 480, false, Image.FORMAT_RGBA8)
	for y: int in 480:
		for x: int in 640:
			var sky := Color(0.35 + 0.2 * y / 480.0, 0.55 + 0.15 * y / 480.0, 0.9)
			var c: Color = sky
			if Vector2(x - 470, y - 120).length() < 60:
				c = Color(1.0, 0.85 + 0.1 * sin(x * 0.1), 0.2)
			if y > 330 + 40 * sin(x / 90.0):
				c = Color(0.2, 0.45 + 0.2 * sin(x * 0.05) * cos(y * 0.07), 0.15)
			photo.set_pixel(x, y, c)
	return photo


func _pictures() -> void:
	print("\npictures from files")
	var logo: Image = PictureFile.decode(LOGO.to_utf8_buffer(), "svg")
	_ok(logo != null and logo.get_width() == PictureFile.SVG_PIXELS and logo.get_height() == 512,
		"an SVG logo read in at %s" % (logo.get_size() if logo != null else Vector2i.ZERO))
	var photo: Image = _photo()
	var jpeg: PackedByteArray = photo.save_jpg_to_buffer(0.9)
	var read: Image = PictureFile.decode(jpeg, "png")
	_ok(read != null and read.get_size() == Vector2i(640, 480),
		"a JPEG called .png read in anyway, by trying each kind")

	var tile: Array[PartPrints.Area] = PartPrints.areas_for(_library, "3068b")
	var top: PartPrints.Area = tile[0]
	var paper := PrintPaint.new(top.size.x, top.size.y)
	var face := Rect2(top.mask.get_used_rect())
	var layer: PrintPaint.Layer = paper.add_picture(photo, face, _palette(), "Photo")
	_ok(layer.picture != null and absf(layer.picture.size_on_canvas().x - face.size.x) < 1.0
			and layer.picture.centre.is_equal_approx(face.get_center()),
		"fitted to the face: %s on a %s face" % [layer.picture.size_on_canvas(), face.size])
	var middle: Color = paper.composite().get_pixelv(Vector2i(face.get_center()))
	_ok(middle.a == 1.0, "and on the canvas")
	paper.change_picture({"centre": face.get_center() + Vector2(50, 0)})
	_ok(paper.composite().get_pixel(int(face.position.x) + 20, int(face.get_center().y)).a == 0.0,
		"moved right, its left edge is clear")
	paper.undo()
	_ok(paper.layer().picture.centre.is_equal_approx(face.get_center())
			and paper.composite().get_pixel(int(face.position.x) + 20, int(face.get_center().y)).a > 0.0,
		"undo puts it back")
	paper.change_picture({"angle": 30.0, "scale": layer.picture.scale * 0.6})
	var turned: Image = paper.composite()
	var corner_clear: bool = turned.get_pixelv(Vector2i(face.position) + Vector2i(4, 4)).a == 0.0
	_ok(corner_clear and turned.get_pixelv(Vector2i(face.get_center())).a > 0.0,
		"turned 30 degrees and smaller: the face's corner clear, its middle covered")
	paper.change_picture({"angle": 0.0, "scale": layer.picture.scale / 0.6,
		"crop": Rect2(0.5, 0.0, 0.5, 1.0)})
	_ok(absf(layer.picture.size_on_canvas().x - face.size.x * 0.5) < 1.0,
		"cropped to its right half: half as wide (%.0f)" % layer.picture.size_on_canvas().x)
	paper.change_picture({"crop": Rect2(0, 0, 1, 1), "opacity": 0.5})
	_ok(absi(paper.layer().image.get_pixelv(Vector2i(face.get_center())).a8 - 127) <= 1,
		"see-through at half: alpha %d" % paper.layer().image.get_pixelv(Vector2i(face.get_center())).a8)
	paper.change_picture({"opacity": 1.0, "lego": true})
	var inks: int = layer.picture.inks_used()
	var all_lego: bool = true
	var image: Image = paper.layer().image
	var palette: Array[Color] = _palette()
	for y: int in range(0, image.get_height(), 7):
		for x: int in range(0, image.get_width(), 7):
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.0:
				var found: bool = false
				for ink: Color in palette:
					found = found or (absi(ink.r8 - c.r8) <= 1 and absi(ink.g8 - c.g8) <= 1
						and absi(ink.b8 - c.b8) <= 1)
				all_lego = all_lego and found
	_ok(all_lego and inks > 1 and inks <= palette.size(),
		"mapped to LEGO's inks: every pixel one of the palette, %d inks" % inks)
	paper.change_picture({"inks": 3})
	_ok(layer.picture.inks_used() <= 3, "at most 3 inks: %d" % layer.picture.inks_used())
	paper.change_picture({"lego": false, "inks": 0})
	var full: int = layer.picture.inks_used()
	_ok(full > 100, "or full colour, as it is: %d colours" % full)

	var logo_paper := PrintPaint.new(top.size.x, top.size.y)
	var logo_layer: PrintPaint.Layer = logo_paper.add_picture(logo, face, palette, "Logo")
	logo_paper.change_picture({"clear_back": true})
	var corner: Vector2i = Vector2i(logo_layer.picture.corners()[0].ceil()) + Vector2i(2, 2)
	_ok(logo_paper.layer().image.get_pixelv(corner).a == 0.0
			and logo_paper.layer().image.get_pixelv(Vector2i(logo_layer.picture.centre)
				+ Vector2i(int(logo_layer.picture.size_on_canvas().x * 0.3), 0)).a > 0.0,
		"a logo's white background made clear, its colours kept")

	# Snapping, as the canvas does it under a drag.
	var canvas := PrintCanvas.new()
	canvas.show_area(top, logo_paper)
	var near: Vector2 = Vector2(face.position.x + logo_layer.picture.size_on_canvas().x * 0.5 + 3.0,
		face.get_center().y + 2.0)
	var landed: Vector2 = canvas._snap(near)
	_ok(absf(landed.x - (face.position.x + logo_layer.picture.size_on_canvas().x * 0.5)) < 0.01
			and absf(landed.y - face.get_center().y) < 0.01,
		"dragged 3 pixels off the face's left edge and 2 off its middle, it snaps to both (%s)"
			% str(canvas.snapped))
	canvas.free()

	print("\nstarters")
	var drawn: int = 0
	for kind: String in Starters.KINDS:
		for size: Vector2i in [Vector2i(410, 410), Vector2i(810, 210), Vector2i(200, 400)]:
			var starter: Image = Starters.draw(kind, size.x, size.y, _library)
			if starter.get_size() == size and not starter.is_invisible():
				drawn += 1
	_ok(drawn == Starters.KINDS.size() * 3, "%d starters drawn on square, long and tall canvases"
		% drawn)

	print("\nmade into parts")
	var made: Dictionary = PartPrints.make(_library, "3068b", tile.slice(0, 1),
		{"top": paper.composite()}, "Probe Photo")
	_ok(str(made["problem"]).is_empty() and _library.parts.has(str(made["ids"][0]))
			and _library.parts[str(made["ids"][0])].category == PartPrints.MY_PRINTS,
		"a photograph on a 2 x 2 tile: %s, under %s" % [made["ids"],
			_library.parts[str(made["ids"][0])].category if not (made["ids"] as Array).is_empty() else ""])
	var slope: Array[PartPrints.Area] = PartPrints.areas_for(_library, "3037")
	var face_of_slope: PartPrints.Area = null
	for area: PartPrints.Area in slope:
		if area.key == "slope":
			face_of_slope = area
	_ok(face_of_slope != null, "3037, the 2 x 4 slope, has its slope (%s)" % ",".join(
		slope.map(func(a: PartPrints.Area) -> String: return a.key)))
	if face_of_slope != null:
		var slope_paper := PrintPaint.new(face_of_slope.size.x, face_of_slope.size.y)
		slope_paper.add_picture(logo, Rect2(face_of_slope.mask.get_used_rect()), palette, "Logo")
		slope_paper.change_picture({"clear_back": true, "lego": true})
		var on_slope: Dictionary = PartPrints.make(_library, "3037", [face_of_slope],
			{"slope": slope_paper.composite()}, "Probe Logo")
		var id: String = str(on_slope["ids"][0]) if not (on_slope["ids"] as Array).is_empty() else ""
		var mesh: Lbm.PartMesh = _library.mesh_for(id) if not id.is_empty() else null
		var slanted: bool = mesh != null and mesh.prints.size() == 1
		if slanted:
			for n: int in mesh.prints:
				for normal: Vector3 in mesh.surfaces[n].surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
					slanted = slanted and normal.y > 0.6 and normal.z > 0.6
		_ok(slanted, "a logo on its slope, the print on the slanted face only: %s" % id)


func _curved() -> void:
	print("\nround and curved faces")
	var round: Array[PartPrints.Area] = PartPrints.areas_for(_library, "98138")
	var top: PartPrints.Area = round[0] if not round.is_empty() else null
	_ok(top != null and top.key == "top" and top.mask.get_pixel(2, 2).a == 0.0
			and top.mask.get_pixel(top.size.x / 2, top.size.y / 2).a > 0.0,
		"98138, the 1 x 1 round tile: its top, round on its canvas")
	for dish: String in ["4740", "3960"]:
		var areas: Array[PartPrints.Area] = PartPrints.areas_for(_library, dish)
		var keys: Array = areas.map(func(a: PartPrints.Area) -> String: return a.key)
		print("    %s: %s" % [dish, keys])
	var big: Array[PartPrints.Area] = PartPrints.areas_for(_library, "3960")
	var dome: PartPrints.Area = null
	for area: PartPrints.Area in big:
		if area.key == "dome" or area.key == "top":
			dome = area
			break
	_ok(dome != null and dome.key == "dome",
		"3960, the 4 x 4 dish: its curved top printed from above (%s)" % (dome.key if dome != null else "none"))
	if dome != null:
		var picture: Image = Starters.draw("dial", dome.size.x, dome.size.y, _library)
		var made: Dictionary = PartPrints.make(_library, "3960", [dome], {dome.key: picture}, "Probe Dial")
		var mesh: Lbm.PartMesh = _library.mesh_for(str(made["ids"][0])) if not (made["ids"] as Array).is_empty() \
			else null
		var faces: int = 0
		if mesh != null:
			for n: int in mesh.prints:
				faces += mesh.surfaces[n].surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
		_ok(faces > 20, "a dial on the dish: %d of its curved faces carry it" % faces)


# -- stickers -----------------------------------------------------------------------------


func _stickers() -> void:
	print("\na sticker across two tiles")
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	await process_frame
	var plate := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	builder.register(world.add_brick("3035", 72, plate), "3035", plate)
	var a := Transform3D(Basis.IDENTITY, Vector3(0, 8, -10))
	var b := Transform3D(Basis.IDENTITY, Vector3(0, 8, 10))
	var first: int = world.add_brick("2431", 4, a)
	var second: int = world.add_brick("2431", 4, b)
	builder.register(first, "2431", a)
	builder.register(second, "2431", b)
	# Looking down from in front, as the default view does.
	var eye := Vector3(5, 120, 90)
	var view_up: Vector3 = (Vector3.UP - (Vector3(5, 8, -10) - eye).normalized()
		* Vector3.UP.dot((Vector3(5, 8, -10) - eye).normalized())).normalized()
	var face: Stickers.Face = Stickers.face_at(world, _library, eye,
		(Vector3(5, 8, -10) - eye).normalized(), true, view_up)
	_ok(face != null and face.bricks.size() == 2 and face.size.is_equal_approx(Vector2(80, 40))
			and face.normal.is_equal_approx(Vector3.UP),
		"a click on one tile finds the top of both: %s LDU, %d bricks" % [
			face.size if face != null else Vector2.ZERO, face.bricks.size() if face != null else 0])
	if face == null:
		return
	_ok(face.down.is_equal_approx(Vector3.BACK) and face.right.is_equal_approx(Vector3.RIGHT),
		"seen from in front, the picture's down is towards the eye and its right is right")
	# Exactly through the middle of a tile, along the diagonal its two top
	# triangles share, from a corner: in floats such a ray slipped between
	# them and found the floor under the tiles.
	var corner_eye := Vector3(-167.1882, 170.6695, 263.051)
	var exact: Stickers.Face = Stickers.face_at(world, _library, corner_eye,
		(Vector3(0, 8, -10) - corner_eye).normalized(), true, view_up)
	_ok(exact != null and exact.size.is_equal_approx(Vector2(80, 40))
			and absf(exact.centre.y - 8.0) < 0.01,
		"a click on the very middle of a tile, the edge its two top triangles share, finds its top")
	var one: Stickers.Face = Stickers.face_at(world, _library, eye,
		(Vector3(5, 8, -10) - eye).normalized(), false, view_up)
	_ok(one != null and one.size.is_equal_approx(Vector2(80, 20)) and one.bricks.size() == 1,
		"with Shift, one tile's: %s" % (one.size if one != null else Vector2.ZERO))
	var size: Vector2 = face.sticker_size()
	_ok(size.is_equal_approx(Vector2(78.5, 38.5)),
		"the sticker is the faces less 0.1 mm a side and a 0.2 mm margin: %s LDU, %s x %s mm"
			% [size, size.x * Lbm.LDU_MM, size.y * Lbm.LDU_MM])
	var canvas: Vector2i = Stickers.canvas_for(size)
	var picture: Image = Starters.draw("number plate", canvas.x, canvas.y, _library)
	var stuck: Dictionary = Stickers.make(_library, picture, size, "Probe Plate")
	var id: String = stuck["id"]
	_ok(str(stuck["problem"]).is_empty() and id.begins_with("bw-st-")
			and _library.parts[id].category == PartPrints.MY_STICKERS
			and Stickers.is_sticker(_library, id),
		"made %s, under %s" % [id, _library.parts[id].category if _library.parts.has(id) else ""])
	var mesh: Lbm.PartMesh = _library.mesh_for(id)
	_ok(mesh != null and mesh.prints.size() == 1 and mesh.connectors.is_empty()
			and mesh.boxes.is_empty() and is_equal_approx(mesh.bounds.size.y, Stickers.THICK),
		"a film %s LDU thick, its top printed, holding nothing and in nobody's way" % (
			mesh.bounds.size.y if mesh != null else 0.0))
	var before: int = world.brick_count()
	var brick: int = Stickers.stick(builder, id, face)
	var placed: BrickWorld.Brick = world.get_brick(brick)
	_ok(brick != 0 and world.brick_count() == before + 1
			and placed.transform.origin.is_equal_approx(Vector3(0, 8, 0)),
		"stuck on at the middle of the two tiles' top: %s" % (placed.transform.origin if placed != null
			else Vector3.ZERO))
	var on: PackedInt64Array = Stickers.stuck_to(world, _library, brick)
	_ok(on.size() == 2 and on.has(first) and on.has(second),
		"stuck to both tiles (%s), which is what the booklet needs" % on)
	var printed_up: bool = false
	for n: int in mesh.prints:
		for normal: Vector3 in mesh.surfaces[n].surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
			printed_up = (placed.transform.basis * normal).dot(Vector3.UP) > 0.999
	_ok(printed_up, "its printed face turned up, out of the tiles")
	_ok(Stickers.in_model(world, _library).has(id), "the model's sticker sheet lists it")
	var listed: Inventory = Inventory.of(world, _library)
	var lot_name: String = ""
	for lot: Inventory.Lot in listed.lots:
		if lot.part_id == id:
			lot_name = lot.name
	_ok(lot_name.begins_with("Sticker 31.4 x 15.4 mm") and lot_name.ends_with("(custom element)"),
		"and the parts list: \"%s\"" % lot_name)
	var given: String = PartPrints.given_name(_library.parts[id].name)
	_ok(given == "Probe Plate" and PartPrints.given_name(_library.parts["3068b"].name).is_empty(),
		"the bin calls it by the name it was given: \"%s\"" % given)
	builder.undo()
	_ok(world.get_brick(brick) == null, "one undo takes it off")
	builder.redo()
	var again: Array = world.bricks().filter(func(x: BrickWorld.Brick) -> bool: return x.part_id == id)
	_ok(again.size() == 1, "and redo puts it back")
	builder.take_off((again[0] as BrickWorld.Brick).id)
	_ok(Stickers.in_model(world, _library).is_empty(), "peeled off")
	builder.undo()
	_ok(Stickers.in_model(world, _library).has(id), "and undone, stuck on again")

	print("\nin a model file")
	var placements: Array = []
	var used: Array = []
	for item: Variant in world.bricks():
		var x: BrickWorld.Brick = item
		placements.append(LdrModel.Placement.new(x.part_id, x.color_code, x.transform, 0))
		used.append(x.part_id)
	var text: String = LdrModel.write_ldr(placements, "Probe Stickers", "Brickworks", {},
		CustomParts.sources_for(_library, used))
	var kept: String = ProjectSettings.globalize_path("res://shots/print_sticker_probe.mpd")
	DirAccess.make_dir_recursive_absolute(kept.get_base_dir())
	var out: FileAccess = FileAccess.open(kept, FileAccess.WRITE)
	out.store_string(text)
	out.close()
	var model: LdrModel = LdrModel.parse(text, "probe.mpd")
	CustomParts.dir = PROBE_DIR + "elsewhere/"
	var fresh := PartLibrary.new()
	fresh.load_catalogue()
	var carried: Dictionary = CustomParts.take_from(fresh, model)
	var back: Lbm.PartMesh = fresh.mesh_for(id)
	_ok((carried["added"] as Array).has(id) and back != null and back.prints.size() == 1
			and back.print_files.values()[0] == mesh.print_files.values()[0],
		"read back into a library that never saw it: the sticker, its picture the same bytes")
	CustomParts.dir = PROBE_DIR

	print("\nthe sticker sheet, measured")
	var items: Array = StickerSheet.items_for(world, _library)
	_ok(items.size() == 1 and (items[0] as StickerSheet.Item).size_mm.is_equal_approx(size * 0.4),
		"one sticker on the sheet, %s mm" % ((items[0] as StickerSheet.Item).size_mm if not items.is_empty()
			else Vector2.ZERO))
	var pdf: PackedByteArray = StickerSheet.pdf(items, "Probe")
	var pdf_path: String = ProjectSettings.globalize_path("res://shots/print_stickers.pdf")
	var file: FileAccess = FileAccess.open(pdf_path, FileAccess.WRITE)
	file.store_buffer(pdf)
	file.close()
	var info: Array = []
	OS.execute("pdfinfo", [pdf_path], info, true)
	var said: String = "".join(info)
	_ok(said.contains("595.276 x 841.89 pts") or said.contains("595.28 x 841.89 pts"),
		"the PDF is one A4 page: %s" % said.get_slice("Page size:", 1).get_slice("\n", 0).strip_edges())
	var raster: String = ProjectSettings.globalize_path("res://shots/print_stickers_600")
	var code: int = OS.execute("pdftoppm", ["-r", "600", "-png", "-singlefile", pdf_path, raster], [], true)
	var rendered := Image.new()
	if code == 0 and rendered.load(raster + ".png") == OK:
		var measured: Vector2 = _cut_line(rendered, 600.0, (items[0] as StickerSheet.Item))
		var wanted: Vector2 = (items[0] as StickerSheet.Item).size_mm
		_ok(absf(measured.x - wanted.x) < 0.1 and absf(measured.y - wanted.y) < 0.1,
			"rendered at 600 dpi, its cut line is %.2f x %.2f mm, the sticker %.2f x %.2f"
				% [measured.x, measured.y, wanted.x, wanted.y])
		var real := Vector2(80.0 * Lbm.LDU_MM - 0.2, 40.0 * Lbm.LDU_MM - 0.2)
		_ok(measured.x < real.x and measured.y < real.y and real.x - measured.x < 0.6,
			"inside the two real tiles' tops, %.1f x %.1f mm, by %.2f and %.2f mm"
				% [real.x, real.y, real.x - measured.x, real.y - measured.y])
	else:
		_ok(false, "pdftoppm rendered the PDF (exit %d)" % code)
	var png: PackedByteArray = StickerSheet.png_bytes(StickerSheet.picture(items, "Probe", 300.0), 300.0)
	var png_path: String = ProjectSettings.globalize_path("res://shots/print_stickers_300dpi.png")
	var png_file: FileAccess = FileAccess.open(png_path, FileAccess.WRITE)
	png_file.store_buffer(png)
	png_file.close()
	var page := Image.new()
	page.load_png_from_buffer(png)
	_ok(absf(StickerSheet.png_dpi(png) - 300.0) < 0.05 and page.get_size() == Vector2i(2480, 3508),
		"the PNG says it is %.1f dpi and is A4 at that: %s" % [StickerSheet.png_dpi(png), page.get_size()])
	var in_png: Vector2 = _cut_line(page, 300.0, (items[0] as StickerSheet.Item))
	_ok(absf(in_png.x - size.x * 0.4) < 0.1 and absf(in_png.y - size.y * 0.4) < 0.1,
		"its cut line is %.2f x %.2f mm at 300 dpi" % [in_png.x, in_png.y])
	world.queue_free()
	builder.queue_free()


## The cut line round a sticker on a rendered sheet: from the outer edge
## of its left line to the outer edge of its right, and top to bottom,
## along lines through the sticker's middle, in mm.
func _cut_line(page: Image, dpi: float, item: StickerSheet.Item) -> Vector2:
	var per_mm: float = dpi / 25.4
	var middle := Vector2i(((item.at_mm + item.size_mm * 0.5) * per_mm).round())
	var cut := func(c: Color) -> bool: return c.b > 0.75 and c.r < 0.35 and c.g > 0.35 and c.g < 0.75
	var left: int = middle.x
	while left > 0 and not cut.call(page.get_pixel(left, middle.y)):
		left -= 1
	while left > 0 and cut.call(page.get_pixel(left - 1, middle.y)):
		left -= 1
	var right: int = middle.x
	while right < page.get_width() - 1 and not cut.call(page.get_pixel(right, middle.y)):
		right += 1
	while right < page.get_width() - 1 and cut.call(page.get_pixel(right + 1, middle.y)):
		right += 1
	var top: int = middle.y
	while top > 0 and not cut.call(page.get_pixel(middle.x, top)):
		top -= 1
	while top > 0 and cut.call(page.get_pixel(middle.x, top - 1)):
		top -= 1
	var bottom: int = middle.y
	while bottom < page.get_height() - 1 and not cut.call(page.get_pixel(middle.x, bottom)):
		bottom += 1
	while bottom < page.get_height() - 1 and cut.call(page.get_pixel(middle.x, bottom + 1)):
		bottom += 1
	# The line straddles the sticker's edge: half outside, half in. The PNG
	# draws it a pixel inside the edge.
	var line: float = 0.3 / 72.0 * dpi if dpi > 400.0 else 0.0
	return Vector2(float(right - left + 1) - line, float(bottom - top + 1) - line) / per_mm


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	for name: String in DirAccess.get_directories_at(dir):
		_forget(dir + name + "/")
	DirAccess.remove_absolute(dir)
