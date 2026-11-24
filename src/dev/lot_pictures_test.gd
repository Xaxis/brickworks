## LotPictures and PartThumbnails.take_sheet read a file of lots as the
## server draws it (api/_lot_pictures.js): its index, each lot's square, and a
## picture to hand at once for every lot it holds, none for one it does not
## (partpics, 2026-11-24).
##
##   node tools/web/lot_pictures_try.mjs MODEL.ldr SHEET.png
##   godot --headless --path . --script src/dev/lot_pictures_test.gd -- --sheet=SHEET.png
extends SceneTree

var _failed: int = 0


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failed += 1


func _init() -> void:
	var path: String = ""
	for one: String in OS.get_cmdline_user_args():
		if one.begins_with("--sheet="):
			path = one.trim_prefix("--sheet=")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_check("the file is read (%d bytes)" % bytes.size(), bytes.size() > 0)
	var index: Dictionary = LotPictures.index_of(bytes)
	var lots: Array = index.get("lots", [])
	_check("its index names %d lots, %d px squares, %d across" % [lots.size(), int(index.get("tile", 0)),
		int(index.get("across", 0))], lots.size() > 0 and int(index.get("tile", 0)) == 96)
	_check("a file with no index is none", LotPictures.index_of(bytes.slice(0, 33)).is_empty()
		and LotPictures.index_of(PackedByteArray([1, 2, 3])).is_empty())
	var thumbnails := PartThumbnails.new()
	_check("nothing is to hand before the file", thumbnails.peek(str(lots[0][0]), int(lots[0][1])) == null)
	var taken: int = thumbnails.take_sheet(bytes)
	_check("the file is taken: %d lots" % taken, taken == lots.size())
	var all: bool = true
	var drawn: int = 0
	for lot: Variant in lots:
		var picture: Texture2D = thumbnails.peek(str(lot[0]), int(lot[1]))
		if picture == null or picture.get_width() != 96:
			all = false
			continue
		var image: Image = picture.get_image()
		# Something of the part in its square: its middle row not all clear.
		for x: int in 96:
			if image.get_pixel(x, 48).a > 0.5:
				drawn += 1
				break
	_check("every lot's picture is to hand at once, 96 px", all)
	_check("and each has its part in it (%d of %d)" % [drawn, lots.size()], drawn == lots.size())
	_check("printed asks take it too", thumbnails.peek(str(lots[0][0]), int(lots[0][1]), true) != null)
	_check("a lot it does not hold is not to hand", thumbnails.peek("3001", 999999) == null)
	_check("the first lot's picture is its own square, not the next one's",
		thumbnails.peek(str(lots[0][0]), int(lots[0][1])).get_image().get_data()
			!= thumbnails.peek(str(lots[1][0]), int(lots[1][1])).get_image().get_data())
	_check("a broken file is refused and keeps what was taken",
		thumbnails.take_sheet(bytes.slice(0, bytes.size() / 2)) == 0
			and thumbnails.peek(str(lots[-1][0]), int(lots[-1][1])) != null)
	thumbnails.free()
	print("lot_pictures_test: %s" % ("PASS" if _failed == 0 else "%d FAIL" % _failed))
	quit(1 if _failed > 0 else 0)
