## Do the server's lot pictures look like the app's own?
##
##   node tools/web/lot_pictures_try.mjs MODEL.ldr SHEET.png
##   godot --path . --resolution 1400x900 --script src/dev/lot_look_probe.gd -- --sheet=SHEET.png [--pictures=DIR]
##
## Run as PROBE_COMPAT=1 tools/probe.sh lot_look_probe --sheet=..., on the
## Compatibility renderer the web runs.
##
## A shared model's lots are shown from one file the server draws
## (api/_lot_pictures.js, partpics), next to pictures the app draws itself
## (PartThumbnails: a lot the file lacks, the bin, the parts list of a model
## opened from a file). Drawn as the site's Parts list drew them, they were
## half as light as the app's (a review, 2026-11-24: see-through parts 0.48,
## plates with studs 0.51, in linear light). Here each lot of the file is
## drawn by the app as well, in the Compatibility renderer the web runs, and
## the two are held side by side: how light the part is (its pixels' mean
## linear luminance), and how much of the square it fills.
##
## The bar: for opaque and for see-through lots alike, the file's lightness
## is within 0.8-1.25 of the app's at the median, and 95% of lots within
## 0.6-1.6 (a black tyre is 0.53: the app's plastic shader shows the studio
## in it, which a plain light does not); the part fills about as much of its
## square (0.6-1.6). Printed
## parts are said apart and held to nothing: the file shows their print, and
## the app's step pictures do not.
## Pictures, the app's beside the file's, go to --pictures (default
## user://lot_look_probe).
extends SceneTree

## The most lots compared: a sheet's first ones.
const MOST := 128
## The calibration brick, and colours drawn as it besides the file's: the
## commonest solids, light to dark, and see-through ones.
const BRICK := "3005"
const CALIBRATION: Array[int] = [0, 1, 2, 4, 5, 14, 15, 19, 25, 28, 70, 71, 72, 73, 84, 85, 191, 272, 288, 308,
	320, 326, 379, 484, 33, 34, 36, 40, 41, 42, 43, 46, 47]

var _failed: int = 0
var _main: Node


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failed += 1


func _run() -> void:
	var sheet_path: String = ""
	var pictures: String = "user://lot_look_probe"
	for one: String in OS.get_cmdline_user_args():
		if one.begins_with("--sheet="):
			sheet_path = one.trim_prefix("--sheet=")
		elif one.begins_with("--pictures="):
			pictures = one.trim_prefix("--pictures=")
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(sheet_path)
	var index: Dictionary = LotPictures.index_of(bytes)
	var sheet := Image.new()
	if bytes.is_empty() or index.is_empty() or sheet.load_png_from_buffer(bytes) != OK:
		_check("the file %s is read, with its index" % sheet_path, false)
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var thumbs: PartThumbnails = _main.get("_thumbnails")
	var library: PartLibrary = _main.get("_library")
	if thumbs == null or library == null or library.parts.is_empty():
		_check("the app is up, with its catalogue and its pictures", false)
		quit(1)
		return
	print("  renderer: %s" % RenderingServer.get_current_rendering_method())
	var tile: int = int(index["tile"])
	var across: int = int(index["across"])
	var lots: Array = (index["lots"] as Array).slice(0, MOST)
	var drawn: Dictionary = {}
	for _n: int in 2400:
		for lot: Variant in lots:
			var key: String = "%s:%d" % [lot[0], int(lot[1])]
			if drawn.has(key):
				continue
			var got: Texture2D = thumbs.request(str(lot[0]), int(lot[1]))
			if got != null:
				drawn[key] = got.get_image()
		if drawn.size() >= lots.size():
			break
		await process_frame
	_check("the app drew %d of the %d lots compared" % [drawn.size(), lots.size()], drawn.size() >= lots.size() - 2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pictures))
	var rows: Array = []
	for n: int in lots.size():
		var lot: Array = lots[n]
		var key: String = "%s:%d" % [lot[0], int(lot[1])]
		if not drawn.has(key):
			continue
		var app: Image = drawn[key]
		app.convert(Image.FORMAT_RGBA8)
		var ours: Image = sheet.get_region(Rect2i((n % across) * tile, (n / across) * tile, tile, tile))
		var a: Vector2 = _light_and_fill(app)
		var b: Vector2 = _light_and_fill(ours)
		if a.y <= 0.0 or b.y <= 0.0 or a.x <= 0.0:
			continue
		var colour: PartLibrary.BrickColor = library.color(int(lot[1]))
		var trans: bool = colour != null and colour.is_transparent()
		var info: PartLibrary.PartInfo = library.parts.get(str(lot[0]))
		rows.append({"key": key, "light": b.x / a.x, "fill": b.y / a.y, "trans": trans,
			"app": a.x, "ours": b.x, "printed": info != null and not info.print_of.is_empty()})
		var pair := Image.create(tile * 2, tile, false, Image.FORMAT_RGBA8)
		pair.fill(Color(0.82, 0.87, 0.95))
		pair.blend_rect(app, Rect2i(0, 0, tile, tile), Vector2i.ZERO)
		pair.blend_rect(ours, Rect2i(0, 0, tile, tile), Vector2i(tile, 0))
		var name: String = "%02d_%s" % [n, key.replace(":", "_")]
		pair.save_png(ProjectSettings.globalize_path(pictures).path_join(name + ".png"))
		app.save_png(ProjectSettings.globalize_path(pictures).path_join(name + "_app.png"))
	# A printed part is drawn with its print in the file, and without it in
	# the step's pictures the app draws (peek's printed is false there):
	# said, and held to nothing.
	for row: Dictionary in rows.filter(func(row: Dictionary) -> bool: return bool(row["printed"])):
		print("    printed, its print in the file only: %s light %.2f fill %.2f" % [row["key"], row["light"],
			row["fill"]])
	rows = rows.filter(func(row: Dictionary) -> bool: return not bool(row["printed"]))
	for trans: bool in [false, true]:
		var some: Array = rows.filter(func(row: Dictionary) -> bool: return bool(row["trans"]) == trans)
		var kind: String = "see-through" if trans else "opaque"
		if some.is_empty():
			print("  (no %s lots in this file)" % kind)
			continue
		var lights: Array = some.map(func(row: Dictionary) -> float: return float(row["light"]))
		var fills: Array = some.map(func(row: Dictionary) -> float: return float(row["fill"]))
		lights.sort()
		fills.sort()
		var middle: float = lights[lights.size() / 2]
		var within: int = lights.filter(func(x: float) -> bool: return x >= 0.6 and x <= 1.6).size()
		_check("%s lots (%d): the file's lightness %.2f of the app's at the median, %.2f-%.2f, %d within 0.6-1.6"
			% [kind, some.size(), middle, lights[0], lights[-1], within],
			middle >= 0.8 and middle <= 1.25 and within >= ceili(some.size() * 0.95))
		_check("%s lots: the part fills %.2f of what it fills in the app's, %.2f-%.2f"
			% [kind, fills[fills.size() / 2], fills[0], fills[-1]], fills[0] >= 0.6 and fills[-1] <= 1.6)
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["light"]) < float(y["light"]))
	for row: Dictionary in rows.slice(0, 4) + rows.slice(maxi(rows.size() - 3, 4)):
		print("    %-14s light %.2f (app %.3f, file %.3f) fill %.2f%s" % [row["key"], row["light"], row["app"],
			row["ours"], row["fill"], " see-through" if row["trans"] else ""])
	# A 1 x 1 brick in each of many colours, kept as the app draws it: its
	# three faces are three known normals, which is what the server's light
	# is measured against (tools/web/lot_light_fit.py).
	var codes: Array[int] = []
	for lot: Variant in lots:
		if not codes.has(int(lot[1])):
			codes.append(int(lot[1]))
	for code: int in CALIBRATION:
		if not codes.has(code) and library.color(code) != null:
			codes.append(code)
	var calibrated: Dictionary = {}
	for _n: int in 2400:
		for code: int in codes:
			if not calibrated.has(code):
				var got: Texture2D = thumbs.request(BRICK, code)
				if got != null:
					calibrated[code] = got.get_image()
		if calibrated.size() >= codes.size():
			break
		await process_frame
	for code: int in calibrated:
		(calibrated[code] as Image).save_png(ProjectSettings.globalize_path(pictures).path_join("cal_%d.png" % code))
	print("  %d calibration bricks drawn" % calibrated.size())
	print("  pictures in %s" % ProjectSettings.globalize_path(pictures))
	print("lot_look_probe: %s" % ("PASS" if _failed == 0 else "%d FAIL" % _failed))
	quit(1 if _failed > 0 else 0)


## A picture's part: the mean linear luminance of the pixels it covers, and
## how much of the square they are.
static func _light_and_fill(image: Image) -> Vector2:
	var sum: float = 0.0
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var lin: Color = c.srgb_to_linear()
			sum += 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
			count += 1
	var all: int = image.get_width() * image.get_height()
	return Vector2(sum / maxf(count, 1.0), float(count) / float(all))
