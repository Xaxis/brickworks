## The booklet's page, the person's way (APP_UX5 #4, pagesetup): Build,
## Booklet page, Page setup… and page_setup over MCP.
##
##   godot --path . --resolution 1280x720 --script src/dev/pagesetup_probe.gd -- [--into=DIR] [--against=DIR] [--dialog-only]
##
## Windowed, on the GPU: the booklet's pictures are drawn, and its pages as
## PNGs. On booklet3's model (a Technic beam 7, an axle 4, bricks and a pod
## built on pages of its own), each booklet printed as Instructions prints
## it, its PDF read by poppler (pdfinfo, pdftoppm), its pages drawn at 300
## dots an inch (BookletPng):
##
## - The booklet's own page, nothing set: its PDF's pages 269 x 199 mm; with
##   --against=DIR (this probe's folder from a run on the commit before,
##   usual.html and usual-page-NNN.png), the booklet's file the same but for
##   its pictures, and every page the same to the pixel.
## - A4 upright, over MCP in 1 call (page_setup size= orientation= margin=
##   number=): the PDF's pages 210 x 297 mm within 0.5, every step on a page,
##   each step's picture and parts box inside its page's margins, the step
##   numbers that much taller; the axle's 1:1 guide still 32.0 mm within 0.2
##   on the PNG page and in the PDF.
## - US Letter on its side, by hand in the dialog, with a page colour: the
##   same at 279.4 x 215.9 mm, the colour read back off the PNG page and the
##   PDF's.
## - A picture behind every page (page_setup picture_data=): on every page
##   of the PNGs and the PDF, and through a step's picture round its model.
## - Kept over a save and an open, said in the file; one undo takes it off.
## - A style kept by a name, then given to the gatehouse in 2 actions (Page
##   setup…, the style): the same size, colour and step number size.
## - The dialog in the window, every control in sight: at this size, and
##   with --dialog-only alone (PROBE_SIZE=1400x900).
##
## The page setup is reached by name (load, call, get), so this runs on the
## commit before it too, and fails there where a person would.
extends SceneTree

const B3 := preload("res://src/dev/booklet3_probe.gd")
const SHEET := "res://src/assembly/booklet_sheet.gd"
const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"
const STYLE := "Probe A4 white"
## 25.4 mm an inch, at 300 dots.
const DENSITY := 300.0 / 25.4
const PT := 72.0 / 25.4

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _library: PartLibrary
var _tools: AppTools
var _out: String = ""
var _against: String = ""
## BookletSheet, where there is one.
var _sheet: GDScript = null


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	var dialog_only: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--into="):
			_out = arg.trim_prefix("--into=")
		elif arg.begins_with("--against="):
			_against = arg.trim_prefix("--against=")
		elif arg == "--dialog-only":
			dialog_only = true
	if _out.is_empty():
		_out = OS.get_user_data_dir().path_join("pagesetup_probe")
	DirAccess.make_dir_recursive_absolute(_out)
	Download.folder = _out
	BookletMaker.open_when_written = false
	_sheet = load(SHEET) as GDScript if ResourceLoader.exists(SHEET) else null
	print("pagesetup: %s, the window %s" % ["BookletSheet is here" if _sheet != null
		else "no BookletSheet", str(root.size)])
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(90)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_library = _main.get("_library")
	_tools = AppTools.new()
	_tools.app = _main
	_tools.assistant = _main.get("_assistant")
	var path: String = _out.path_join("booklet3.mpd")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(B3.MODEL)
	file.close()
	await _open(path, 18)
	# B, the timeline, as a person opens Build, Booklet page from it.
	var steps: StepsBar = _main.get("_steps")
	if not steps.visible:
		await steps.start(_world, _library, _store.scenery)
	steps.set_mode(StepsBar.AUTHORS)
	await _frames(4)
	if dialog_only:
		await _dialog_fits()
		_quit()
		return
	await _usual()
	await _a4_over_mcp()
	await _letter_by_hand()
	await _picture_behind()
	await _kept()
	await _style_to_gatehouse()
	_quit()


func _quit() -> void:
	print("")
	print("pagesetup: %s" % ("every check passed" if _failures == 0
		else "%d FAILED" % _failures))
	_main.queue_free()
	await _frames(2)
	quit(1 if _failures > 0 else 0)


func _open(path: String, parts: int) -> void:
	(_main.get("_steps") as StepsBar).stop()
	_main.call("clear_model")
	await _frames(4)
	_main.call("_open", path)
	for _n: int in 600:
		if _store.awaited.is_empty():
			break
		await process_frame
	await _frames(10)
	_check("opened %s: %d parts" % [path.get_file(), _world.brick_count()],
		_world.brick_count() == parts)


# -- the page as it is set up, read by name --------------------------------


## The model's page: {size, margin, colour, number, picture}, the booklet's
## own where there is no BookletSheet.
func _page() -> Dictionary:
	if _sheet == null:
		return {"size": Vector2(269, 199), "margin": 9.0, "colour": Color8(220, 236, 248),
			"number": 8.0, "picture": "", "said": {}}
	var sheet: Object = _sheet.call("of", _world)
	return {"size": sheet.call("size"), "margin": float(sheet.get("margin")),
		"colour": sheet.get("colour"), "number": float(sheet.get("number")),
		"picture": str(sheet.get("picture")), "said": sheet.call("said")}


# -- printing -----------------------------------------------------------------


## The booklet made from the model as it is, written out, and its PDF and
## pages: {html, pdf, document, stem, pages, sizes (each PDF page in mm)}.
func _printed(stem: String) -> Dictionary:
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var started: int = Time.get_ticks_msec()
	var html: String = await maker.make(_world, _store.scenery, "Booklet extras")
	var document: Booklet.Document = maker.document
	var steps: int = maker.plan.size()
	maker.queue_free()
	if not _check("the booklet was made (%d pages, %.1f s)" % [document.pages.size() if document
			!= null else 0, (Time.get_ticks_msec() - started) / 1000.0],
			not html.is_empty() and document != null):
		return {}
	var path: String = _out.path_join(stem + ".html")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(html)
	file.close()
	var pdf: String = _out.path_join(stem + ".pdf")
	var zip: String = _out.path_join(stem + "_pages.zip")
	var read := BookletRead.new()
	var writer := BookletPdf.new()
	writer.begin(pdf, read)
	var pages: int = await read.read_all(path, writer.page)
	writer.finish(read.title)
	var drawer := BookletPng.new()
	root.add_child(drawer)
	var drawn: int = await drawer.write(path, zip, stem)
	drawer.queue_free()
	_check("its PDF (%d pages) and its pages as PNG (%d)" % [pages, drawn],
		writer.ok() and pages > 0 and drawn == pages)
	var reader := ZIPReader.new()
	if reader.open(zip) == OK:
		for name: String in reader.get_files():
			var copy: FileAccess = FileAccess.open(_out.path_join("%s-page-%s.png" % [stem,
				name.get_basename().right(3)]), FileAccess.WRITE)
			copy.store_buffer(reader.read_file(name))
			copy.close()
		reader.close()
	OS.execute("pdftoppm", ["-r", "300", "-png", ProjectSettings.globalize_path(pdf),
		ProjectSettings.globalize_path(_out.path_join(stem + "-pdf"))])
	return {"html": html, "path": path, "pdf": pdf, "zip": zip, "document": document, "stem": stem,
		"pages": pages, "steps": steps, "sizes": _pdf_sizes(pdf)}


## Each page of the PDF at [param pdf], as poppler reads it, in mm.
static func _pdf_sizes(pdf: String) -> Array[Vector2]:
	var said: Array = []
	OS.execute("pdfinfo", ["-f", "1", "-l", "9999", ProjectSettings.globalize_path(pdf)], said)
	var out: Array[Vector2] = []
	var size := RegEx.create_from_string("Page\\s+\\d+ size:\\s+([0-9.]+) x ([0-9.]+) pts")
	for found: RegExMatch in size.search_all("\n".join(said)):
		out.append(Vector2(found.get_string(1).to_float(), found.get_string(2).to_float()) / PT)
	return out


func _png(printed: Dictionary, number: int) -> Image:
	return Image.load_from_file(_out.path_join("%s-page-%03d.png" % [printed["stem"], number]))


func _pdf_page(printed: Dictionary, number: int) -> Image:
	for width: int in [1, 2, 3]:
		var path: String = _out.path_join("%s-pdf-%s.png" % [printed["stem"],
			str(number).pad_zeros(width)])
		if FileAccess.file_exists(path):
			return Image.load_from_file(path)
	return null


## The printed booklet's pages on [param want] mm: every PDF page that size
## within 0.5 mm, every step of the plan on a page, each step's picture and
## parts box inside the page's margins, and the axle's 1:1 guide 32.0 mm.
func _on_paper(printed: Dictionary, want: Vector2, words: String) -> void:
	if printed.is_empty():
		return
	var sizes: Array[Vector2] = printed["sizes"]
	var off: int = 0
	for size: Vector2 in sizes:
		if absf(size.x - want.x) > 0.5 or absf(size.y - want.y) > 0.5:
			off += 1
	_check("%s: the PDF's %d pages are %s x %s mm within 0.5 (%d off; the first %.2f x %.2f)" % [
		words, sizes.size(), want.x, want.y, off, sizes[0].x if not sizes.is_empty() else 0.0,
		sizes[0].y if not sizes.is_empty() else 0.0],
		not sizes.is_empty() and off == 0 and sizes.size() == int(printed["pages"]))
	var png: Image = _png(printed, 2)
	_check("...its pages drawn %d x %d px, the paper at 300 dpi" % [png.get_width() if png else 0,
		png.get_height() if png else 0], png != null
		and absi(png.get_width() - roundi(want.x * DENSITY)) <= 1
		and absi(png.get_height() - roundi(want.y * DENSITY)) <= 1)
	var page: Dictionary = _page()
	var inside := Rect2(Vector2(page["margin"], page["margin"]),
		want - Vector2(page["margin"], page["margin"]) * 2.0).grow(0.05)
	# Each entry is its plan step's (BookletMaker's meta "step"): those laid
	# on a page, and those in a callout drawn inside a step's panel.
	var document: Booklet.Document = printed["document"]
	var found: Dictionary = {}
	var outside: Array = []
	for laid: Booklet.Page in document.pages:
		if not laid.kind in ["steps", "callout"]:
			continue
		for entry: Booklet.Entry in laid.entries:
			found[int(entry.get_meta("step", -1))] = true
			if entry.callout != null and entry.callout.inline:
				for inner: Booklet.Entry in entry.callout.steps:
					found[int(inner.get_meta("step", -1))] = true
			for rect: Rect2 in [entry.rect, entry.parts_rect]:
				if rect.size.x > 0.0 and not inside.encloses(rect):
					outside.append("page %d step %d %s" % [laid.number, entry.number, str(rect)])
	var missing: Array = range(int(printed["steps"])).filter(func(index: int) -> bool:
		return not found.has(index))
	_check("...every one of the %d steps on a page (%s missing)" % [int(printed["steps"]),
		str(missing) if not missing.is_empty() else "none"],
		int(printed["steps"]) > 0 and missing.is_empty())
	_check("...each step's picture and parts box inside the page's %s mm margins (%s)" % [
		str(page["margin"]), str(outside.slice(0, 3)) if not outside.is_empty() else "all"],
		outside.is_empty())
	await _axle(printed, words)
	# A reader of PDFs not this one: the pages that size, the step pictures
	# byte for byte, the fonts in it, the PNGs poppler's drawing of the PDF.
	var said: Array = []
	var into: String = ProjectSettings.globalize_path(_out.path_join(str(printed["stem"]) + "-check"))
	var code: int = OS.execute("python3", [ProjectSettings.globalize_path(
		"res://tools/booklet_pdf_check.py"), ProjectSettings.globalize_path(printed["path"]),
		ProjectSettings.globalize_path(printed["pdf"]), "--zip",
		ProjectSettings.globalize_path(printed["zip"]), "--out", into], said, true)
	for line: String in str("".join(said)).strip_edges().split("\n"):
		print("      " + line)
	_check("%s: tools/booklet_pdf_check.py passes" % words, code == 0)


## The axle 4's 1:1 guide measured on the PNG page and the PDF's.
func _axle(printed: Dictionary, words: String) -> void:
	var document: Booklet.Document = printed["document"]
	for laid: Booklet.Page in document.pages:
		for entry: Booklet.Entry in laid.entries if laid.kind == "steps" else []:
			for index: int in entry.actual.size():
				if str(entry.actual[index]["part"]) != "3705":
					continue
				var rect: Rect2 = Booklet.actual_rects(entry)[index]
				var on_png: float = B3._ink_length(_png(printed, laid.number), rect, DENSITY)
				var on_pdf: float = B3._ink_length(_pdf_page(printed, laid.number), rect, DENSITY)
				_check("%s: the axle 4's 1:1 guide on page %d is %.2f mm on the PNG, %.2f in the PDF (32.0 within 0.2)"
					% [words, laid.number, on_png, on_pdf], absf(on_png - 32.0) <= 0.2
						and absf(on_pdf - 32.0) <= 0.2)
				return
	_check("%s: the axle 4 has its 1:1 guide on a page" % words, false)


## The colour of [param image] at [param mm] on the page, as 0-255 each.
static func _at(image: Image, mm: Vector2) -> Color:
	if image == null:
		return Color(0, 0, 0, 0)
	var px := Vector2i((mm * DENSITY).round()).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	return image.get_pixelv(px)


static func _same(a: Color, b: Color, within: float = 3.0 / 255.0) -> bool:
	return absf(a.r - b.r) <= within and absf(a.g - b.g) <= within and absf(a.b - b.b) <= within


# -- the checks -----------------------------------------------------------------


## The booklet's own page, nothing set: unchanged.
func _usual() -> void:
	print("")
	print("the booklet's own page, nothing set")
	var printed: Dictionary = await _printed("usual")
	if printed.is_empty():
		return
	var sizes: Array[Vector2] = printed["sizes"]
	_check("its PDF's %d pages are 269 x 199 mm (the first %.2f x %.2f)" % [sizes.size(),
		sizes[0].x if not sizes.is_empty() else 0.0, sizes[0].y if not sizes.is_empty() else 0.0],
		not sizes.is_empty() and sizes.all(func(size: Vector2) -> bool:
			return absf(size.x - 269.0) <= 0.05 and absf(size.y - 199.0) <= 0.05))
	if _against.is_empty():
		return
	var before: String = FileAccess.get_file_as_string(_against.path_join("usual.html"))
	if not _check("the commit before's booklet is at %s" % _against, not before.is_empty()):
		return
	var pictures := RegEx.create_from_string("data:image/[a-z]+;base64,[A-Za-z0-9+/=]+")
	var now_text: String = pictures.sub(str(printed["html"]), "PICTURE", true)
	var was_text: String = pictures.sub(before, "PICTURE", true)
	var first: int = 0
	while first < mini(now_text.length(), was_text.length()) and now_text[first] == was_text[first]:
		first += 1
	_check("...its file the same as the commit before's but for its pictures (%d and %d characters%s)"
		% [now_text.length(), was_text.length(), "" if now_text == was_text
			else ", first differing at %d: %s" % [first, now_text.substr(maxi(0, first - 40), 80).c_escape()]],
		now_text == was_text)
	var differing: int = 0
	var pages_off: Array = []
	for number: int in range(1, int(printed["pages"]) + 1):
		var now: Image = _png(printed, number)
		var was: Image = Image.load_from_file(_against.path_join("usual-page-%03d.png" % number))
		if now == null or was == null or now.get_size() != was.get_size():
			pages_off.append(number)
			continue
		var off: int = 0
		for y: int in now.get_height():
			for x: int in now.get_width():
				if now.get_pixel(x, y) != was.get_pixel(x, y):
					off += 1
		if off > 0:
			pages_off.append(number)
			differing += off
	_check("...and every one of its %d pages the same to the pixel (%d pixels differ, pages %s)" % [
		int(printed["pages"]), differing, str(pages_off)], pages_off.is_empty())


## A4 upright over MCP, in 1 call.
func _a4_over_mcp() -> void:
	print("")
	print("A4 upright, over MCP in 1 call")
	var said: String = str(await _tools.run("page_setup", {"size": "A4", "orientation": "portrait",
		"margin": 12, "number": 10}))
	print("    page_setup: %s" % said)
	var page: Dictionary = _page()
	_check("page_setup size=A4 orientation=portrait margin=12 number=10: the page is %s, margins %s, numbers %s mm"
		% [str(page["size"]), str(page["margin"]), str(page["number"])],
		page["size"] == Vector2(210, 297) and is_equal_approx(page["margin"], 12.0)
		and is_equal_approx(page["number"], 10.0))
	var printed: Dictionary = await _printed("a4")
	_on_paper(printed, Vector2(210.0, 297.0), "A4 upright")
	if printed.is_empty():
		return
	# The numbers 10 mm where the booklet's own are 8: 1.25 times.
	var scales: Array = []
	for laid: Booklet.Page in (printed["document"] as Booklet.Document).pages:
		for entry: Booklet.Entry in laid.entries if laid.kind == "steps" else []:
			scales.append(snappedf(entry.number_size, 0.01))
	_check("...its step numbers 10 mm tall, or 8.13 on a small panel: 1.25 times the booklet's own (%s)"
		% str(scales), not scales.is_empty() and scales.all(func(size: float) -> bool:
			return absf(size - 10.0) <= 0.011 or absf(size - 8.125) <= 0.011))


## US Letter on its side and a page colour, by hand in the dialog.
func _letter_by_hand() -> void:
	print("")
	print("US Letter on its side, and a page colour, by hand in Page setup…")
	if not _check("Build, Booklet page has Page setup…", "booklet_page_setup" in
			(Shell.SUBMENUS.get("booklet", []) as Array) and _shell.run("booklet_page_setup")):
		return
	await _frames(6)
	var dialog: Window = _shell.get("_page_setup_dialog")
	if not _check("...it opens Page setup", dialog != null and dialog.visible):
		return
	await _fits(dialog, "page_setup_dialog")
	var paper: OptionButton = dialog.get("_paper")
	var orientation: OptionButton = dialog.get("_orientation")
	paper.select(2)
	paper.item_selected.emit(2)
	await _frames(2)
	orientation.select(0)
	orientation.item_selected.emit(0)
	await _frames(2)
	var picker: ColorPickerButton = dialog.get("_colour")
	picker.color = Color8(255, 246, 224)
	picker.popup_closed.emit()
	await _frames(2)
	var page: Dictionary = _page()
	_check("US Letter, Landscape and a colour chosen: the page %s, colour #%s" % [str(page["size"]),
		(page["colour"] as Color).to_html(false)],
		(page["size"] as Vector2).is_equal_approx(Vector2(279.4, 215.9))
		and _same(page["colour"], Color8(255, 246, 224), 0.001))
	await _shot("page_setup_letter")
	dialog.hide()
	var printed: Dictionary = await _printed("letter")
	_on_paper(printed, Vector2(279.4, 215.9), "US Letter on its side")
	if printed.is_empty():
		return
	# Read back off the page's corner, inside the margin, where nothing is.
	var corner := Vector2(4.0, 4.0)
	var on_png: Color = _at(_png(printed, 2), corner)
	var on_pdf: Color = _at(_pdf_page(printed, 2), corner)
	_check("...the page colour read back off the PNG page, #%s, and the PDF's, #%s (#fff6e0)"
		% [on_png.to_html(false), on_pdf.to_html(false)], _same(on_png, Color8(255, 246, 224))
		and _same(on_pdf, Color8(255, 246, 224)))


## A picture behind every page, over MCP, and showing through a step's picture.
func _picture_behind() -> void:
	print("")
	print("a picture behind every page")
	var image := Image.create(300, 400, false, Image.FORMAT_RGB8)
	image.fill(Color8(40, 160, 90))
	image.fill_rect(Rect2i(0, 200, 300, 200), Color8(40, 90, 160))
	var said: String = str(await _tools.run("page_setup", {"picture_data":
		Marshalls.raw_to_base64(image.save_png_to_buffer())}))
	print("    page_setup picture_data=: %s" % said)
	_check("page_setup picture_data=: a picture behind the page (%s)" % str(_page()["picture"]),
		not str(_page()["picture"]).is_empty())
	var printed: Dictionary = await _printed("behind")
	if printed.is_empty():
		return
	var green := Color8(40, 160, 90)
	var corners: Array = []
	for number: int in range(1, int(printed["pages"]) + 1):
		var png: Image = _png(printed, number)
		var at: Color = _at(png, Vector2(4.0, 40.0))
		if not _same(at, green, 6.0 / 255.0):
			corners.append(number)
	_check("...on every one of the %d PNG pages, off the page's top half's edge (%s off)" % [
		int(printed["pages"]), str(corners)], corners.is_empty())
	var pdf: Image = _pdf_page(printed, 3)
	_check("...and the PDF's (page 3: #%s)" % _at(pdf, Vector2(4.0, 40.0)).to_html(false),
		pdf != null and _same(_at(pdf, Vector2(4.0, 40.0)), green, 6.0 / 255.0))
	# Inside a step's picture, at its corner, where the model is not: the
	# picture behind, not the page's colour laid on it.
	var document: Booklet.Document = printed["document"]
	for laid: Booklet.Page in document.pages:
		if laid.kind != "steps" or laid.entries.is_empty():
			continue
		var rect: Rect2 = laid.entries[0].rect
		var spot: Vector2 = rect.position + Vector2(1.0, 1.0)
		var png: Image = _png(printed, laid.number)
		var seen: Color = _at(png, spot)
		var pdf_seen: Color = _at(_pdf_page(printed, laid.number), spot)
		var behind: Color = green if spot.y < (_page()["size"] as Vector2).y * 0.5 \
			else Color8(40, 90, 160)
		_check("...and through step %d's picture at its corner, %s mm: #%s on the PNG, #%s in the PDF"
			% [laid.entries[0].number, str(spot), seen.to_html(false), pdf_seen.to_html(false)],
			_same(seen, behind, 8.0 / 255.0) and _same(pdf_seen, behind, 8.0 / 255.0))
		break
	await _shot_file(_out.path_join("behind-page-002.png"), "behind_page")


## Saved and opened again: the page as it was set up, the same file again;
## one undo takes a change off.
func _kept() -> void:
	print("")
	print("saved and opened again")
	var was: Dictionary = _page()
	var text: String = _store.to_text("booklet3", true)
	var line: String = ""
	for one: String in text.split("\n"):
		if one.begins_with("0 !BRICKWORKS PAGE_SETUP"):
			line = one.strip_edges()
	_check("the file says the page: \"%s\"" % line.left(120), line.contains("LETTER LANDSCAPE")
		and line.contains("MARGIN 12") and line.contains("COLOUR #FFF6E0")
		and line.contains("NUMBER 10") and line.contains("PICTURE "))
	var path: String = _out.path_join("booklet3_saved.mpd")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	await _open(path, 18)
	var now: Dictionary = _page()
	_check("opened again, the page is as it was set up (%s)" % str(now["said"]).left(160),
		str(now["said"]) == str(was["said"]) and not (now["said"] as Dictionary).is_empty())
	var images: Dictionary = BookletLooks.images(_world)
	_check("...its picture with it (%d bytes of base64)" % str(images.get(now["picture"], "")).length(),
		images.has(now["picture"]))
	_check("...and saved again, the same text", _store.to_text("booklet3", true) == text)
	var undo_said: String = str(await _tools.run("page_setup", {"margin": 20}))
	print("    page_setup margin=20: %s" % undo_said)
	_check("page_setup margin=20: margins 20 mm", is_equal_approx(_page()["margin"], 20.0))
	_builder.undo()
	await _frames(2)
	_check("...one undo puts 12 back (%s)" % str(_page()["margin"]), is_equal_approx(_page()["margin"], 12.0))
	var usual: String = str(await _tools.run("page_setup", {"usual": true}))
	print("    page_setup usual=true: %s" % usual)
	_check("page_setup usual=true: the booklet's own page again, nothing said in the file",
		(_page()["said"] as Dictionary).is_empty()
		and not _store.to_text("booklet3", true).contains("PAGE_SETUP")
		and not _store.to_text("booklet3", true).contains("brickworks-page-behind"))


## A style kept, then given to the gatehouse in 2 actions.
func _style_to_gatehouse() -> void:
	print("")
	print("a style kept, and given to the gatehouse in 2 actions")
	if _sheet != null:
		_sheet.call("forget_style", STYLE)
	str(await _tools.run("page_setup", {"size": "A4", "orientation": "portrait", "colour": "#ffffff",
		"number": 11}))
	var dialog: Window = null
	if _shell.run("booklet_page_setup"):
		await _frames(6)
		dialog = _shell.get("_page_setup_dialog")
	if not _check("Page setup… opens", dialog != null and dialog.visible):
		return
	(dialog.get("_name") as LineEdit).text = STYLE
	(dialog.get("_keep") as Button).pressed.emit()
	await _frames(2)
	var styles: Dictionary = _sheet.call("styles") if _sheet != null else {}
	_check("Keep as a style: \"%s\" kept (%s)" % [STYLE, str(styles.get(STYLE, {}))],
		styles.has(STYLE))
	dialog.hide()
	var kept: Dictionary = _page()
	await _open(ProjectSettings.globalize_path(GATEHOUSE), 14)
	_check("the gatehouse opens on the booklet's own page (%s)" % str(_page()["size"]),
		(_page()["said"] as Dictionary).is_empty())
	var actions: int = 0
	if _shell.run("booklet_page_setup"):
		actions += 1
	await _frames(6)
	var list: OptionButton = dialog.get("_style")
	var index: int = -1
	for at: int in list.item_count:
		if list.get_item_text(at) == STYLE:
			index = at
	if index >= 0:
		list.select(index)
		list.item_selected.emit(index)
		actions += 1
	await _frames(2)
	await _shot("page_setup_style")
	var now: Dictionary = _page()
	_check("in %d actions (Page setup…, the style): the gatehouse's page %s, colour #%s, numbers %s mm"
		% [actions, str(now["size"]), (now["colour"] as Color).to_html(false), str(now["number"])],
		actions == 2 and now["size"] == kept["size"] and _same(now["colour"], kept["colour"], 0.001)
		and is_equal_approx(now["number"], kept["number"]))
	dialog.hide()
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(_world, _store.scenery, "Gatehouse")
	maker.queue_free()
	var sizes: Array = []
	for laid: Booklet.Page in pages:
		for entry: Booklet.Entry in laid.entries if laid.kind == "steps" else []:
			sizes.append(snappedf(entry.number_size, 0.01))
	_check("...its booklet's step numbers 11 mm, or 8.94 on a small panel (%s)" % str(sizes),
		not sizes.is_empty() and sizes.all(func(size: float) -> bool:
			return absf(size - 11.0) <= 0.011 or absf(size - 8.9375) <= 0.011))
	if _sheet != null:
		_sheet.call("forget_style", STYLE)


# -- the dialog in the window -----------------------------------------------------


## Page setup… alone, at the window's size.
func _dialog_fits() -> void:
	print("")
	print("Page setup… in a %s window" % str(root.size))
	if not _check("Page setup… opens", _shell.run("booklet_page_setup")):
		return
	await _frames(6)
	var dialog: Window = _shell.get("_page_setup_dialog")
	if _check("...as a dialog", dialog != null and dialog.visible):
		await _fits(dialog, "page_setup_dialog")


## Every control of [param dialog] inside it, and it inside the window.
func _fits(dialog: Window, name: String) -> void:
	var window := Rect2i(Vector2i.ZERO, root.size)
	var box := Rect2i(dialog.position, dialog.size)
	var out: Array = []
	var shown: int = 0
	for node: Node in dialog.find_children("*", "Control", true, false):
		var control: Control = node
		if not control.is_visible_in_tree() or control is Container or control.size.x <= 0.0:
			continue
		shown += 1
		var at := Rect2(control.get_global_rect())
		if not Rect2(Vector2.ZERO, Vector2(dialog.size)).grow(0.5).encloses(at):
			out.append("%s %s" % [control.get_class(), str(at)])
	_check("the dialog %s inside the %s window, its %d controls inside it (%s)" % [str(box),
		str(root.size), shown, str(out.slice(0, 3)) if not out.is_empty() else "all"],
		window.encloses(box) and shown > 10 and out.is_empty())
	await _shot(name)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join("%s_%dx%d.png" % [name, root.size.x, root.size.y])
	if image != null:
		image.save_png(path)
		print("    picture: %s" % ProjectSettings.globalize_path(path))


func _shot_file(path: String, what: String) -> void:
	if FileAccess.file_exists(path):
		print("    picture (%s): %s" % [what, ProjectSettings.globalize_path(path)])
