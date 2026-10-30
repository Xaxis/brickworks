## Decorated parts — prints and stickers — brought in, swapped and carried
## out: a picture given as its own data, a Studio file's prints, stickers and
## Part Designer decal, the printed versions the LEGO Group made of a part,
## LDraw's own stickers laid on a face, and an .io written with ours in
## Studio's form and read back.
##
##   godot --headless --path . --script src/dev/decor_probe.gd
##   godot --headless --path . --script src/dev/decor_probe.gd -- --real=<a Studio .io>
##
## Pictures as data (PictureFile.from_data): a PNG and a JPEG as base64,
## wrapped at 76, URL-safe, unpadded, as a data: URI, an SVG percent-encoded;
## refused, each saying what it is: a PDF, a GIF, a phone's HEIC, a web page,
## a cut-short PNG, words that are not base64, a data:application/pdf URI,
## and more than 2 MiB.
##
## A Studio file: tests/fixtures/studio/decor_2025.io (make_fixtures.py, in
## the shape of set 31213's Studio 2.25.2 file, whose lips are a print Studio
## drew itself): every part placed, nothing named missing; its catalogue print
## and its stickered tile (bl_…) from model2.ldr and its Part Designer part
## from CustomParts/, each with its picture on surfaces of its own, the
## picture's bytes as the file's, and the coordinates at the faces' corners
## those the file gave (0.045 to 0.955, turned to TEXMAP's v), the decal's
## box cast on the tile's top only; bl_3001 the library's own 3001. With
## --real, a Studio file of one's own: every part placed and each print drawn.
##
## The way out: a print and a sticker made here, written for an .io's
## CustomParts/ with PE_TEX lines (StudioDecor.studio_text) and read back as
## Studio's: the same pictures and, at every corner, the same coordinates.
##
## Printed versions: a plain 2 x 2 tile has hundreds; Make, Printed
## versions… offers the plain part first and then them; one chosen swaps the
## tile where it stands, in its colour, one undo; the plain one swaps back; a
## part that is no version is refused.
##
## LDraw's stickers: a sticker in hand over a tile lies on its top, its middle
## on the top's middle, R turning it about the face; put down, it is stuck to
## the tile (Stickers.stuck_to), and PrintStudio.stick_part_on does the same
## from a side's name.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _studio: PrintStudio

const DECOR := "res://tests/fixtures/studio/decor_2025.io"
const PRINT := "bl_3068pb9001"
const STICKERED := "bl_2431pb9002"
const DESIGNED := "m1a2b3c4_2025408_170000"


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	CustomParts.dir = OS.get_user_data_dir().path_join("decor_probe_parts/")
	CustomParts.keeps = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_studio = _main.get("_studio")
	_pictures_as_data()
	await _studio_file()
	await _the_way_out()
	await _printed_versions()
	await _ldraw_stickers()
	var real: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--real="):
			real = argument.substr(7)
	if not real.is_empty():
		await _real_file(real)
	print("")
	if _failures == 0:
		print("decor: a picture given as data prints, a Studio file's prints, stickers and "
			+ "decal open drawn, ours go out in Studio's form and come back the same, a part "
			+ "swaps for its printed versions, and LDraw's stickers lie on the face")
	else:
		print("decor: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- a picture given as its own data ------------------------------------------------------


func _pictures_as_data() -> void:
	print("── pictures given as data ──")
	var picture := Image.create_empty(48, 32, false, Image.FORMAT_RGBA8)
	picture.fill(Color(0.8, 0.1, 0.05))
	picture.fill_rect(Rect2i(0, 0, 24, 32), Color(1, 1, 1))
	var png: PackedByteArray = picture.save_png_to_buffer()
	var jpeg: PackedByteArray = picture.save_jpg_to_buffer(0.9)
	var plain: String = Marshalls.raw_to_base64(png)
	var cases: Array = [
		["a PNG as base64", plain],
		["a JPEG as base64", Marshalls.raw_to_base64(jpeg)],
		["a PNG as a data: URI", "data:image/png;base64," + plain],
		["base64 wrapped at 76, as base64 -w 76 writes it", _wrapped(plain)],
		["URL-safe base64 with its padding left off",
			plain.replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")],
		["an SVG as a percent-encoded data: URI", "data:image/svg+xml," + (
			"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 48 32'><rect width='48' "
			+ "height='32' fill='#c91a09'/></svg>").uri_encode()],
	]
	for case: Array in cases:
		var read: Dictionary = PictureFile.from_data(case[1])
		var image: Image = read.get("image")
		_check("%s reads: %s" % [case[0], "%dx%d" % [image.get_width(), image.get_height()]
			if image != null else str(read.get("error", ""))],
			image != null and absf(float(image.get_width()) / image.get_height() - 1.5) < 0.01)
	var heic := PackedByteArray([0, 0, 0, 24])
	heic.append_array("ftypheic".to_ascii_buffer())
	heic.append_array(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]))
	var cut: PackedByteArray = png.slice(0, 40)
	var refused: Array = [
		["a PDF", Marshalls.raw_to_base64("%PDF-1.7\n1 0 obj << >> endobj\n".to_ascii_buffer()),
			"is a PDF"],
		["a GIF", Marshalls.raw_to_base64("GIF89a\u0001\u0000\u0001\u0000\u0000\u0000\u0000;"
			.to_utf8_buffer()), "is a GIF"],
		["a phone's HEIC", Marshalls.raw_to_base64(heic), "HEIC"],
		["a web page", Marshalls.raw_to_base64("<!DOCTYPE html><html><body>hi</body></html>"
			.to_utf8_buffer()), "a web page"],
		["a PNG cut short", Marshalls.raw_to_base64(cut), "cut short or damaged"],
		["words that are not base64", "here is the picture you asked for!", "not base64"],
		["a data: URI of a PDF", "data:application/pdf;base64," + plain, "application/pdf data"],
		["more than 2 MiB", "A".repeat(PictureFile.MOST_DATA_BYTES * 4 / 3 + 400), "at most 2"],
		["nothing", "   ", "empty"],
	]
	for case: Array in refused:
		var read: Dictionary = PictureFile.from_data(case[1])
		var why: String = str(read.get("error", ""))
		_check("%s is refused, saying so: %s" % [case[0], why.left(90)],
			not read.has("image") and why.contains(str(case[2])))


static func _wrapped(text: String) -> String:
	var lines := PackedStringArray()
	for at: int in range(0, text.length(), 76):
		lines.append(text.substr(at, 76))
	return "\n".join(lines) + "\n"


# -- a Studio file's own --------------------------------------------------------------------


func _studio_file() -> void:
	print("── a Studio file's prints, sticker and Part Designer decal ──")
	var read: Dictionary = StudioIo.read(FileAccess.get_file_as_bytes(DECOR))
	var carried: PackedStringArray = read.get("studio_parts", PackedStringArray())
	_check("decor_2025.io reads, carrying Studio's own: %s" % ", ".join(carried),
		str(read["error"]).is_empty() and carried.has(PRINT) and carried.has(STICKERED)
			and carried.has(DESIGNED) and str(read["note"]).is_empty())
	var opened: Dictionary = _store.open_text(str(read["text"]), "decor_2025")
	_check("every part placed, none named missing: %d placed, missing %s" % [
		int(opened["placed"]), opened.get("missing_ids", {})],
		int(opened["placed"]) == 4 and int(opened["missing"]) == 0)
	var by_part: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			by_part[brick.part_id] = brick
	_check("bl_3001 is the library's own 3001, in red: %s" % ", ".join(by_part.keys()),
		by_part.has("3001") and (by_part["3001"] as BrickWorld.Brick).color_code == 4
			and not by_part.has("bl_3001"))
	var corners_print: Array = [[Vector3(-20, 0, 20), Vector2(0.045, 0.045)],
		[Vector3(20, 0, 20), Vector2(0.955, 0.045)], [Vector3(20, 0, -20), Vector2(0.955, 0.955)],
		[Vector3(-20, 0, -20), Vector2(0.045, 0.955)]]
	_decorated(PRINT, "the catalogue print", _picture_in("model2.ldr", "3068pb9001.dat"),
		corners_print, 15, by_part)
	var corners_sticker: Array = [[Vector3(-40, 0, 10), Vector2(0.045, 0.045)],
		[Vector3(40, 0, -10), Vector2(0.955, 0.955)]]
	_decorated(STICKERED, "the stickered tile, as Studio files a sticker",
		_picture_in("model2.ldr", "2431pb9002.dat"), corners_sticker, 0, by_part)
	var info: PartLibrary.PartInfo = _library.parts.get(STICKERED)
	_check("...which the library calls stickered and files under %s" % (
		info.category if info != null else "nothing"), info != null
		and info.decor() & PartLibrary.PartInfo.STICKERED != 0
		and info.category == StudioDecor.CATEGORY)
	var corners_decal: Array = [[Vector3(-20, 0, 20), Vector2(0, 0)],
		[Vector3(20, 0, 20), Vector2(1, 0)], [Vector3(20, 0, -20), Vector2(1, 1)]]
	_decorated(DESIGNED, "the Part Designer decal, cast by its box",
		_picture_in("customparts/%s.dat" % DESIGNED, DESIGNED + ".dat"), corners_decal, 14, by_part)
	# The box casts on faces turned up into it: the tile's sides meet the box
	# but run along its axis, the bottom is outside it.
	var mesh: Lbm.PartMesh = _library.mesh_for(DESIGNED)
	var printed: int = 0
	var lowest: float = INF
	if mesh != null:
		for n: int in mesh.surfaces.size():
			if mesh.prints.get(n) != null:
				printed += 1
				for p: Vector3 in (mesh.surfaces[n].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
						as PackedVector3Array):
					lowest = minf(lowest, p.y)
	_check("...on the tile's top alone, one surface at its top: %d printed, lowest at %s"
		% [printed, lowest], printed == 1 and absf(lowest) < 0.01)


## A part read from the Studio file: placed in its colour, its picture the
## file's, and at each of [param corners] (LDraw's axes) the coordinates
## given (TEXMAP's: v down from the top).
func _decorated(id: String, what: String, expected: PackedByteArray, corners: Array, colour: int,
		by_part: Dictionary) -> void:
	var brick: BrickWorld.Brick = by_part.get(id)
	var mesh: Lbm.PartMesh = _library.mesh_for(id)
	_check("%s is placed as %s, in colour %d" % [what, id, colour],
		brick != null and brick.color_code == colour and mesh != null)
	if mesh == null:
		return
	var pictures: Array = mesh.print_files.values()
	_check("...its picture the file's own bytes (%d of them)" % expected.size(),
		pictures.size() == 1 and pictures[0] == expected)
	var found := PackedStringArray()
	var all: bool = true
	for corner: Array in corners:
		var at: Variant = _uv_at(mesh, corner[0])
		found.append("%s" % [at])
		all = all and at != null and (at as Vector2).distance_to(corner[1]) < 0.002
	_check("...the coordinates at its corners those the file gave: %s" % ", ".join(found), all)


## The picture a part of the fixture carries, read straight off its member's
## text: the last word of the first PE_TEX_INFO after its FILE line.
static func _picture_in(member: String, file_name: String) -> PackedByteArray:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(DECOR)
	var text: String = StudioIo._text_of(StudioIo._unpack(bytes, StudioIo._entries(bytes)[member]))
	var inside: bool = false
	for line: String in text.split("\n"):
		if line.strip_edges() == "0 FILE " + file_name:
			inside = true
		elif inside and line.begins_with("0 PE_TEX_INFO"):
			var words: PackedStringArray = line.strip_edges().split(" ")
			return Marshalls.base64_to_raw(words[words.size() - 1])
	return PackedByteArray()


## The coordinates a printed surface of [param mesh] has at the point [param
## ldraw] (LDraw's axes), or null where none has a corner there.
static func _uv_at(mesh: Lbm.PartMesh, ldraw: Vector3) -> Variant:
	var app := Vector3(ldraw.x, -ldraw.y, -ldraw.z)
	for n: int in mesh.surfaces.size():
		if mesh.prints.get(n) == null:
			continue
		var arrays: Array = mesh.surfaces[n].surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for v: int in points.size():
			if points[v].distance_to(app) < 0.01:
				return uvs[v]
	return null


# -- the way out -------------------------------------------------------------------------------


func _the_way_out() -> void:
	print("── ours, carried out in Studio's form and read back ──")
	_main.call("clear_model")
	var tile: int = _builder.put_part("3068b", 15, Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
	var areas: Array[PartPrints.Area] = PartPrints.areas_for(_library, "3068b")
	var drawn := Image.create_empty(areas[0].size.x, areas[0].size.y, false, Image.FORMAT_RGBA8)
	drawn.fill(Color(0.05, 0.3, 0.7))
	drawn.fill_rect(Rect2i(0, 0, areas[0].size.x / 2, areas[0].size.y / 3), Color(1, 0.8, 0.1))
	var made: Dictionary = PartPrints.make(_library, "3068b", areas, {areas[0].key: drawn},
		"Probe Out", false)
	var print_id: String = str((made["ids"] as Array)[0]) if not (made["ids"] as Array).is_empty() \
		else ""
	_builder.put_part(print_id, 15, Transform3D(Basis.IDENTITY, Vector3(60, 8, 0)))
	var face: Stickers.Face = _studio._face_on(_world.get_brick(tile), "up", false)
	var film := Image.create_empty(Stickers.canvas_for(face.sticker_size()).x,
		Stickers.canvas_for(face.sticker_size()).y, false, Image.FORMAT_RGBA8)
	film.fill(Color(0.9, 0.1, 0.1))
	var sticker: Dictionary = Stickers.make(_library, film, face.sticker_size(), "Probe Out", false)
	Stickers.stick(_builder, str(sticker["id"]), face)
	var parts: Dictionary = Exports.studio_parts(_world, _library)
	_check("a print and a sticker made here go to CustomParts/: %s" % ", ".join(parts.keys()),
		parts.has(print_id + ".dat") and parts.has(str(sticker["id"]) + ".dat"))
	var text: String = await _store.text_for_file("decor_out", "")
	var bytes: PackedByteArray = StudioIo.pack(text, PackedByteArray(), 3, parts)
	var entries: Dictionary = StudioIo._entries(bytes)
	for id: String in [print_id, str(sticker["id"])]:
		var member: String = "customparts/%s.dat" % id
		var written: String = StudioIo._text_of(StudioIo._unpack(bytes, entries.get(member, {})))\
			if entries.has(member) else ""
		_check("%s in the .io's CustomParts/, its picture a PE_TEX_INFO named by a PE_TEX_PATH"
			% id, written.contains("0 PE_TEX_PATH 0") and written.contains("0 PE_TEX_INFO iVBOR")
				and not written.contains("!TEXMAP"))
		# Read back as Studio's own: the same picture, the same coordinates.
		var back: Dictionary = StudioDecor.to_ldraw(id + "-back", id + ".dat",
			StudioDecor.sections(written), false)
		var added: Dictionary = CustomParts.add(_library, str(back["text"]), id + "-back", false,
			back["pictures"])
		var original: Lbm.PartMesh = _library.mesh_for(id)
		var again: Lbm.PartMesh = _library.mesh_for(id + "-back")
		var same: bool = str(added["problem"]).is_empty() and again != null and original != null \
			and again.print_files.values() == original.print_files.values()
		var compared: int = 0
		var worst: float = 0.0
		if same:
			for n: int in original.surfaces.size():
				if original.prints.get(n) == null:
					continue
				var arrays: Array = original.surfaces[n].surface_get_arrays(0)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				for v: int in points.size():
					var p: Vector3 = points[v]
					var there: Variant = _uv_at(again, Vector3(p.x, -p.y, -p.z))
					compared += 1
					worst = maxf(worst, 9.0 if there == null else (there as Vector2).distance_to(uvs[v]))
		_check("...read back as Studio's: the same picture, and at all %d printed corners the "
			% compared + "same coordinates (at worst %.4f off)" % worst,
			same and compared > 0 and worst < 0.002)
	# The whole file opens again, ours drawn from model.ldr's TEXMAP.
	_main.call("clear_model")
	var read: Dictionary = StudioIo.read(bytes)
	var opened: Dictionary = _store.open_text(str(read["text"]), "decor_out")
	_check("...and the .io opens here again whole: %d parts, missing %s" % [int(opened["placed"]),
		opened.get("missing_ids", {})], int(opened["placed"]) == 3 and int(opened["missing"]) == 0)


# -- the LEGO Group's printed versions --------------------------------------------------------


func _printed_versions() -> void:
	print("── printed versions ──")
	_main.call("clear_model")
	var at := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(20, 8, -20))
	var tile: int = _builder.put_part("3068b", 1, at)
	var versions: Array[PartLibrary.PartInfo] = _studio.versions_of("3068b")
	_check("a plain 2 x 2 tile has its printed versions: %d" % versions.size(), versions.size() > 100)
	var words: Array[PartLibrary.PartInfo] = _studio.versions_of("3068b", "control")
	_check("...narrowed by words, \"control\": %d" % words.size(),
		not words.is_empty() and words.size() < versions.size())
	_builder.selection.clear()
	_builder.selection[tile] = true
	_check("Make, Printed versions… is offered for it", _studio.offers_versions())
	_studio.open_versions()
	var offered: PackedStringArray = _studio.versions.offered()
	_check("...and opens on the plain part, then its versions: %s…" % ", ".join(offered.slice(0, 3)),
		_studio.versions.visible and offered.size() > 2 and offered[0] == "3068b")
	_studio.versions.close()
	var chosen: String = versions[0].id
	var depth: int = _builder.history_depth()
	var said: String = await _studio.swap_to(PackedInt64Array([tile]), chosen)
	var now: BrickWorld.Brick = _world.get_brick(_studio.last_placed)
	_check("swapped for %s where it stood, in its blue: %s" % [chosen, said],
		now != null and now.part_id == chosen and now.color_code == 1
			and now.transform.is_equal_approx(at) and _world.get_brick(tile) == null)
	_check("...one undo step", _builder.history_depth() == depth + 1)
	_check("...and the printed one is a version of the plain one: %s" % _studio.plain_of(chosen),
		_studio.plain_of(chosen) == "3068b" and _studio.versions_of(chosen).size() == versions.size())
	said = await _studio.swap_to(PackedInt64Array([now.id]), "3068b")
	var plain: BrickWorld.Brick = _world.get_brick(_studio.last_placed)
	_check("...and back to plain: %s" % said, plain != null and plain.part_id == "3068b"
		and plain.transform.is_equal_approx(at))
	said = await _studio.swap_to(PackedInt64Array([plain.id]), "3001")
	_check("a part that is no version of it is refused: %s" % said.left(70),
		said.contains("is not a version") and _world.get_brick(plain.id) != null)


# -- LDraw's stickers, laid on a face ---------------------------------------------------------


func _ldraw_stickers() -> void:
	print("── LDraw's stickers, on a face ──")
	_main.call("clear_model")
	var tile: int = _builder.put_part("3068b", 15, Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
	var sticker: String = "003428d"
	var info: PartLibrary.PartInfo = _library.parts.get(sticker)
	_check("%s is one of LDraw's stickers: %s" % [sticker, info.name if info != null else "none"],
		info != null and Stickers.sticks(_library, sticker) and _library.mesh_for(sticker) != null)
	_builder.held_part = sticker
	_builder.held_color = 15
	_builder.held_rotation = 0
	_builder.view_up = Vector3.FORWARD
	_builder.update_preview(Vector3(3, 200, 2), Vector3.DOWN)
	var ghost: Transform3D = _builder._ghost_transform
	_check("in hand over the tile it lies on its top, in the middle: %s" % ghost.origin,
		_builder.can_place() and ghost.origin.is_equal_approx(Vector3(0, 8, 0))
			and ghost.basis.y.normalized().is_equal_approx(Vector3.UP))
	var across: Vector3 = ghost.basis.x
	_builder.rotate_held(1)
	_builder.update_preview(Vector3(3, 200, 2), Vector3.DOWN)
	_check("...R turns it a quarter about the face",
		absf(_builder._ghost_transform.basis.x.normalized().dot(across.normalized())) < 0.01
			and _builder._ghost_transform.basis.y.normalized().is_equal_approx(Vector3.UP))
	_builder.rotate_held(-1)
	_builder.update_preview(Vector3(3, 200, 2), Vector3.DOWN)
	var put: int = _builder.place()
	_check("...put down, it is stuck to the tile: %s" % [Stickers.stuck_to(_world, _library, put)],
		put != 0 and Stickers.stuck_to(_world, _library, put) == PackedInt64Array([tile]))
	_builder.update_preview(Vector3(5000, 200, 5000), Vector3.DOWN)
	_check("...and where there is no face, it goes nowhere", not _builder.can_place())
	var brick: int = _builder.put_part("3001", 4, Transform3D(Basis.IDENTITY, Vector3(100, 0, 0)))
	var said: String = await _studio.stick_part_on(brick, "-z", "003435c", 15)
	var film: BrickWorld.Brick = _world.get_brick(_studio.last_placed)
	_check("stick_part_on lays one on a brick's front: %s" % said, said.begins_with("Stuck")
		and film != null and film.transform.basis.y.normalized().is_equal_approx(Vector3.FORWARD)
		and Stickers.stuck_to(_world, _library, film.id) == PackedInt64Array([brick]))
	said = await _studio.stick_part_on(brick, "-z", "3001", 15)
	_check("...and a part that is no sticker is refused: %s" % said.left(60),
		said.contains("is not a sticker"))
	_builder.held_part = "3001"


# -- a Studio file of one's own -----------------------------------------------------------------


func _real_file(path: String) -> void:
	print("── %s ──" % path.get_file())
	_main.call("clear_model")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var read: Dictionary = StudioIo.read(bytes)
	var opened: Dictionary = _store.open_text(str(read["text"]), path.get_file().get_basename())
	var total: int = 0
	var entries: Dictionary = StudioIo._entries(bytes)
	if entries.has(".info"):
		var info: Variant = JSON.parse_string(StudioIo._text_of(StudioIo._unpack(bytes,
			entries[".info"])).replace("\r", ""))
		if info is Dictionary:
			total = int((info as Dictionary).get("total_parts", 0))
	_check("it opens: %d of %d placed, missing %s; Studio's own: %s" % [int(opened["placed"]),
		total, opened.get("missing_ids", {}), ", ".join(read.get("studio_parts", []))],
		int(opened["placed"]) >= total and int(opened["missing"]) == 0)
	for id: String in read.get("studio_parts", PackedStringArray()):
		var mesh: Lbm.PartMesh = _library.mesh_for(id)
		if mesh == null or not _library.parts.has(id) or not _library.parts[id].custom:
			continue
		_check("%s is drawn with %d picture%s" % [id, mesh.print_files.size(),
			"" if mesh.print_files.size() == 1 else "s"], not mesh.print_files.is_empty()
			or not str(_library.custom_source(id)).contains("TEXMAP"))
