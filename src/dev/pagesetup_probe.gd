## The booklet's page, the person's way (APP_UX5 #4, pagesetup): Build,
## Booklet page, Page setup… and page_setup over MCP.
##
##   godot --path . --resolution 1280x720 --script src/dev/pagesetup_probe.gd -- [--into=DIR] [--against=DIR] [--dialog-only]
##   (--list-styles, headless: the styles kept, as a new start reads them, and quit;
##   --race-remove=N, headless: another window keeping and taking away a style N times)
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
## And what pagesetup2 made of psreview's items 2-4:
## - The app's own model, its steps worked out by the app: its page set up,
##   picture and all, as it was when it is saved and opened again (lost at
##   every open before).
## - A file whose page names a picture it does not carry (another program
##   saved it without, or it is not a PNG or a JPEG): said in Page setup…,
##   by page_setup and booklet_layout; the page printed in its colour; a
##   save and a change keep it named; Take off takes it off.
## - A 4000 x 3000 photograph behind the booklet's own page kept as a JPEG
##   of 1980 x 1485, A4's 297 mm at 5 px a mm either way up; chosen on A5
##   and the paper then made A4 upright, still 5 px a mm; a 16000 x 1000
##   panorama kept to what a page shows of its middle; a see-through one a
##   PNG of no more than 1 MB or 900 px; its size in the file said by
##   page_setup and in Page setup….
## - Someone else's file, its steps marked worked, with its page set up and
##   a step's note: saved with nothing changed, byte for byte; the note and
##   its picture kept through a change and Usual.
## - Two styles of one picture keep it once; one taken away in Page
##   setup… (Remove…), the other by page_setup remove_style= (a call
##   refused for another field taking nothing), both gone in a new start of
##   the app and their picture with them; a style replaced 5 times keeping
##   its last picture alone; the styles one file kept before listed and
##   given where they are, nothing written by looking, moved into their own
##   by the next keep; that file left byte for byte when it cannot be read.
## - A model shared with its page set up says it, and carries its steps.
## - Two windows on one user folder, one keeping styles on a picture as the
##   other keeps and takes away its own on it: none read back without it.
##
## The page setup is reached by name (load, call, get), so this runs on the
## commit before it too, and fails there where a person would.
extends SceneTree

const B3 := preload("res://src/dev/booklet3_probe.gd")
const SHEET := "res://src/assembly/booklet_sheet.gd"
const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"
const STYLE := "Probe A4 white"
## Written by the other window of _two_windows as it starts.
const RACE_STARTED := "user://pagesetup_race_started"
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
	# A new start of the app, for the styles it reads (_new_start).
	if "--list-styles" in OS.get_cmdline_user_args():
		var kept: Dictionary = (load(SHEET) as GDScript).call("styles") if ResourceLoader.exists(SHEET) else {}
		for name: String in kept:
			print("STYLE " + name)
		quit(0)
		return
	# Another window on the same user folder, keeping a style on one picture
	# and taking it away, again and again (_two_windows).
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--race-remove="):
			var styles: GDScript = load(SHEET) as GDScript
			var sheet: Object = styles.call("from", {"picture": "brickworks-page-behind.jpg"})
			var picture: String = _race_picture()
			_write(RACE_STARTED, "")
			for _n: int in int(arg.trim_prefix("--race-remove=")):
				styles.call("save_style", "Probe race other", sheet, picture)
				styles.call("remove_style", "Probe race other")
			quit(0)
			return
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
	await _own_steps_worked()
	await _foreign_worked_notes()
	await _shared_keeps_page()
	await _missing_picture()
	await _picture_bound()
	await _styles_kept()
	await _two_windows()
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
	# The foot of every page, the parts list's credits with it: inside the
	# margins, on the PNG page and the PDF's. (Its line ran off an upright
	# A4 page, the trademark notice with it.)
	var off_edge: Array = []
	for number: int in range(1, int(printed["pages"]) + 1):
		for drawn: Image in [_png(printed, number), _pdf_page(printed, number)]:
			var right: float = _rightmost_ink(drawn, want.y - float(page["margin"]) - 16.0,
				want.y - float(page["margin"]) + 2.0)
			if right > want.x - float(page["margin"]) + 0.5:
				off_edge.append("page %d: ink to %.1f mm" % [number, right])
	_check("...every page's foot, the credits too, inside the right margin (%s)" % (
		str(off_edge.slice(0, 3)) if not off_edge.is_empty() else "all"), off_edge.is_empty())
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


## How far across [param image] its rightmost ink is (darker than half
## white), in mm, between [param top] and [param bottom] mm down.
static func _rightmost_ink(image: Image, top: float, bottom: float) -> float:
	if image == null:
		return INF
	var from: int = clampi(roundi(top * DENSITY), 0, image.get_height() - 1)
	var to: int = clampi(roundi(bottom * DENSITY), 0, image.get_height() - 1)
	for x: int in range(image.get_width() - 1, -1, -1):
		for y: int in range(from, to, 2):
			if image.get_pixel(x, y).get_luminance() < 0.5:
				return x / DENSITY
	return 0.0


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
	# Inside a step's picture, at its corners, where the model is not and
	# nothing is laid over it (its parts box, number, 1:1 guides, callout):
	# the picture behind, not the page's colour laid on it.
	var document: Booklet.Document = printed["document"]
	var seen_through: Array = []
	var not_through: Array = []
	var page_colour: Color = _page()["colour"]
	for laid: Booklet.Page in document.pages:
		if laid.kind != "steps":
			continue
		for entry: Booklet.Entry in laid.entries:
			var over: Array = [entry.parts_rect, Booklet.number_rect(entry)]
			over.append_array(Booklet.actual_rects(entry))
			if entry.callout != null:
				over.append(entry.callout.box)
			var inner: Rect2 = entry.rect.grow(-1.5)
			for spot: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y),
					Vector2(inner.position.x, inner.end.y), inner.end]:
				if over.any(func(rect: Rect2) -> bool: return rect.grow(1.0).has_point(spot)):
					continue
				var behind: Color = green if spot.y < (_page()["size"] as Vector2).y * 0.5 \
					else Color8(40, 90, 160)
				var seen: Color = _at(_png(printed, laid.number), spot)
				var pdf_seen: Color = _at(_pdf_page(printed, laid.number), spot)
				var where: String = "page %d step %d at %s: #%s, #%s" % [laid.number, entry.number,
					str(spot), seen.to_html(false), pdf_seen.to_html(false)]
				if _same(seen, behind, 8.0 / 255.0) and _same(pdf_seen, behind, 8.0 / 255.0):
					seen_through.append(where)
				# The page's colour laid over the picture where the step's
				# picture is: what must not be. (A spot on the model is
				# neither.)
				elif _same(seen, page_colour, 8.0 / 255.0) or _same(pdf_seen, page_colour, 8.0 / 255.0) \
						or not _same(seen, pdf_seen, 24.0 / 255.0):
					not_through.append(where)
	_check("...and through the steps' pictures, at their corners clear of what is laid on them: %d spots show it on the PNG and the PDF, %d the page's colour instead (%s)"
		% [seen_through.size(), not_through.size(),
			str(not_through.slice(0, 3)) if not not_through.is_empty() else str(seen_through.slice(0, 2))],
		seen_through.size() >= 4 and not_through.is_empty())
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
	_forget(STYLE)
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
	_forget(STYLE)


# -- pagesetup2: kept, said, small, and styles taken away ---------------------------


## A style taken away: remove_style where there is one, forget_style (the
## probe's own, before it) where not.
func _forget(name: String) -> void:
	if _sheet == null:
		return
	if _has(_sheet, "remove_style"):
		_sheet.call("remove_style", name)
	elif _has(_sheet, "forget_style"):
		_sheet.call("forget_style", name)


## How many arguments [param script]'s [param method] takes, -1 when it has
## none of that name.
static func _arguments(script: GDScript, method: String) -> int:
	if script == null:
		return -1
	for one: Dictionary in script.get_script_method_list():
		if str(one["name"]) == method:
			return (one["args"] as Array).size()
	return -1


static func _has(script: GDScript, method: String) -> bool:
	return _arguments(script, method) >= 0


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## booklet3 with [param lines] after its first author line.
static func _b3_with(lines: String) -> String:
	var at: int = B3.MODEL.find("0 Author: A. Builder\n") + "0 Author: A. Builder\n".length()
	return B3.MODEL.substr(0, at) + lines + B3.MODEL.substr(at)


func _page_dialog() -> Window:
	if not _shell.run("booklet_page_setup"):
		return null
	await _frames(6)
	return _shell.get("_page_setup_dialog")


## The app's own model, its steps worked out by the app: its page set up,
## picture and guide and all, saved and opened again.
func _own_steps_worked() -> void:
	print("")
	print("the app's own model, its steps worked out by the app, saved and opened again")
	var path: String = _out.path_join("own_worked.mpd")
	_write(path, B3.MODEL.replace("0 Author: A. Builder", "0 Author: Brickworks"))
	await _open(path, 18)
	var image := Image.create(300, 400, false, Image.FORMAT_RGB8)
	image.fill(Color8(200, 60, 40))
	var said: String = str(await _tools.run("page_setup", {"size": "A4", "orientation": "portrait",
		"margin": 12, "picture_data": Marshalls.raw_to_base64(image.save_png_to_buffer())}))
	print("    page_setup: %s" % said)
	var was: Dictionary = _page()
	var saved: String = _out.path_join("own_worked_saved.mpd")
	_check("set up (%s) and saved: %s" % [str(was["said"]).left(120), saved.get_file()],
		not (was["said"] as Dictionary).is_empty() and _store.save_file(saved, "own_worked"))
	var text: String = FileAccess.get_file_as_string(saved)
	_check("...the file is the app's own, its steps not marked the author's, and says the page",
		text.contains("0 Author: Brickworks") and not text.contains(LdrModel.AUTHORED_META)
		and text.contains("PAGE_SETUP A4 PORTRAIT"))
	await _open(saved, 18)
	var now: Dictionary = _page()
	_check("opened again, the page as it was set up (%s; was %s)" % [str(now["said"]).left(120),
		str(was["said"]).left(120)], str(now["said"]) == str(was["said"]))
	_check("...its picture with it", not str(now["picture"]).is_empty()
		and BookletLooks.images(_world).has(now["picture"]))


## Someone else's file, its steps marked worked (the app wrote it whole),
## with its page set up and a step's note and picture: saved with nothing
## changed, the file byte for byte; its page changed and then set back to
## the booklet's own, the note and its picture kept (ps2review: the first
## save took them).
func _foreign_worked_notes() -> void:
	print("")
	print("someone else's file, its steps marked worked, its page set up and a step note")
	var note: String = "0 !BRICKWORKS TEXT 20 20 80 30 6 Hello step two\n" \
		+ "0 !BRICKWORKS IMAGE 120 20 40 30 brickworks-page-1.png\n"
	var clear := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	clear.fill(Color(0.2, 0.4, 0.9, 0.5))
	var red := Image.create(64, 48, false, Image.FORMAT_RGB8)
	red.fill(Color8(200, 60, 40))
	var text: String = _b3_with(LdrModel.WORKED_META + "\n"
		+ "0 !BRICKWORKS PAGE_SETUP A4 PORTRAIT MARGIN 12 PICTURE brickworks-page-behind.jpg\n")
	var first: int = text.find("0 STEP\n")
	var second: int = text.find("0 STEP\n", first + 1)
	text = text.substr(0, second) + note + text.substr(second) \
		+ _data("brickworks-page-1.png", Marshalls.raw_to_base64(clear.save_png_to_buffer())) \
		+ _data("brickworks-page-behind.jpg", Marshalls.raw_to_base64(red.save_jpg_to_buffer(0.9)))
	var path: String = _out.path_join("foreign_worked.mpd")
	_write(path, text)
	await _open(path, 18)
	var saved: String = _out.path_join("foreign_worked_saved.mpd")
	_store.save_file(saved, "foreign_worked")
	var back: String = FileAccess.get_file_as_string(saved)
	_check("opened (%s) and saved with nothing changed: the file byte for byte, the app's own lines aside (%s)"
		% [str(_page()["said"]).left(80), "same" if _app_lines_out(back) == _app_lines_out(text)
		else "TEXT %d, IMAGE %d, !DATA %d" % [_lines_with(back, "!BRICKWORKS TEXT"),
		_lines_with(back, "!BRICKWORKS IMAGE"), _lines_with(back, "0 !DATA")]],
		_app_lines_out(back) == _app_lines_out(text))
	await _tools.run("page_setup", {"margin": 15})
	_store.save_file(saved, "foreign_worked")
	back = FileAccess.get_file_as_string(saved)
	_check("margin 15, saved: MARGIN 15, the note and both pictures kept (TEXT %d, IMAGE %d, !DATA %d)"
		% [_lines_with(back, "!BRICKWORKS TEXT"), _lines_with(back, "!BRICKWORKS IMAGE"),
		_lines_with(back, "0 !DATA")], back.contains("MARGIN 15") and _lines_with(back, "!BRICKWORKS TEXT") == 1
		and _lines_with(back, "!BRICKWORKS IMAGE") == 1 and _lines_with(back, "0 !DATA") == 2)
	await _tools.run("page_setup", {"usual": true})
	_store.save_file(saved, "foreign_worked")
	back = FileAccess.get_file_as_string(saved)
	_check("the booklet's own page, saved: no PAGE_SETUP, its picture gone, the note and its picture kept (TEXT %d, !DATA %d)"
		% [_lines_with(back, "!BRICKWORKS TEXT"), _lines_with(back, "0 !DATA")],
		not back.contains("PAGE_SETUP") and not back.contains("!DATA brickworks-page-behind")
		and _lines_with(back, "!BRICKWORKS TEXT") == 1 and back.contains("0 !DATA brickworks-page-1.png"))


## A model shared with its page set up: the shared file says the page, and
## carries its steps (SharedPages.strip took every line beginning
## "0 !BRICKWORKS PAGE" up to ps2review, PAGE_SETUP with them).
func _shared_keeps_page() -> void:
	print("")
	print("a model shared with its page set up")
	var path: String = _out.path_join("shared.mpd")
	_write(path, B3.MODEL)
	await _open(path, 18)
	await _tools.run("page_setup", {"size": "A4", "orientation": "portrait", "margin": 14})
	var shared: String = await SharedPages.attach(_store.to_text("shared", true), _library, _store)
	var again: String = await SharedPages.attach(shared, _library, _store)
	_check("the shared file says the page (%d PAGE_SETUP) and carries its steps (%s), shared again the same"
		% [_lines_with(shared, "PAGE_SETUP A4 PORTRAIT MARGIN 14"), str(SharedPages.count(shared)).left(80)],
		_lines_with(shared, "PAGE_SETUP A4 PORTRAIT MARGIN 14") == 1 and not SharedPages.count(shared).is_empty()
		and again == shared)


static func _data(name: String, base64: String) -> String:
	var out: String = "0 !DATA %s\n" % name
	for at: int in range(0, base64.length(), 76):
		out += "0 !: %s\n" % base64.substr(at, 76)
	return out


static func _lines_with(text: String, word: String) -> int:
	var n: int = 0
	for line: String in text.split("\n"):
		if line.contains(word):
			n += 1
	return n


## [param text] without the lines every save of the app writes (its title,
## the floor it stands on).
static func _app_lines_out(text: String) -> String:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if not line.begins_with("0 !BRICKWORKS TITLE ") and not line.begins_with("0 !BRICKWORKS FLOOR "):
			out.append(line)
	return "\n".join(out)


## A file whose page names a picture it does not carry.
func _missing_picture() -> void:
	print("")
	print("a file naming a picture behind its pages that it does not carry")
	var path: String = _out.path_join("missing.mpd")
	_write(path, _b3_with("0 !BRICKWORKS PAGE_SETUP A4 PORTRAIT COLOUR #FFF6E0 PICTURE brickworks-page-behind.jpg\n"))
	await _open(path, 18)
	var status: String = str(await _tools.run("page_setup", {}))
	print("    page_setup: %s" % status)
	_check("page_setup says the picture is missing from the file", status.contains("missing from the file")
		and status.contains("brickworks-page-behind.jpg"))
	var dialog: Window = await _page_dialog()
	var label: Label = dialog.get("_picture") if dialog != null else null
	var take_off: Button = dialog.get("_take_off") if dialog != null else null
	_check("Page setup… says so: \"%s\", and Take off can take it off" % (label.text if label else "?"),
		label != null and label.text == "Missing from the file" and take_off != null and not take_off.disabled)
	if dialog != null:
		await _shot("page_setup_missing")
		dialog.hide()
	var layout: String = str(await _tools.run("booklet_layout", {}))
	_check("booklet_layout says so", layout.contains("missing from the file"))
	var printed: Dictionary = await _printed("missing")
	if not printed.is_empty():
		var on_png: Color = _at(_png(printed, 2), Vector2(4.0, 4.0))
		_check("...its pages printed in the page's colour, #%s (#fff6e0)" % on_png.to_html(false),
			_same(on_png, Color8(255, 246, 224)))
	var margin: String = str(await _tools.run("page_setup", {"margin": 15}))
	print("    page_setup margin=15: %s" % margin)
	var text: String = _store.to_text("missing", true)
	_check("a change (margin 15) is made, and a save still names the picture",
		is_equal_approx(_page()["margin"], 15.0) and text.contains("PICTURE brickworks-page-behind.jpg"))
	dialog = await _page_dialog()
	take_off = dialog.get("_take_off") if dialog != null else null
	if take_off != null:
		take_off.pressed.emit()
		await _frames(2)
	if dialog != null:
		dialog.hide()
	var after: String = str(await _tools.run("page_setup", {}))
	_check("Take off: no picture named, nothing said missing, none in the file",
		str(_page()["picture"]).is_empty() and not after.contains("missing")
		and not _store.to_text("missing", true).contains("PICTURE"))
	# And one the file carries that is not a PNG or a JPEG, left out at the
	# edge (BookletLooks.kept_pictures).
	_write(path, _b3_with("0 !BRICKWORKS PAGE_SETUP A4 PORTRAIT PICTURE brickworks-page-behind.jpg\n")
		+ "0 !DATA brickworks-page-behind.jpg\n0 !: PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==\n")
	await _open(path, 18)
	var edge: String = str(await _tools.run("page_setup", {}))
	_check("one that is not a PNG or a JPEG: left out, and said missing too (%s)" % edge.left(140),
		edge.contains("missing from the file") and BookletLooks.images(_world).is_empty())


## The picture behind the pages, kept no bigger than its page needs.
func _picture_bound() -> void:
	print("")
	print("a big picture behind the pages, kept to the page")
	var path: String = _out.path_join("bound.mpd")
	_write(path, B3.MODEL)
	await _open(path, 18)
	var photo := Image.create(4000, 3000, false, Image.FORMAT_RGB8)
	photo.fill(Color8(90, 130, 200))
	photo.fill_rect(Rect2i(0, 1500, 4000, 1500), Color8(70, 150, 80))
	photo.fill_rect(Rect2i(1800, 900, 400, 1200), Color8(230, 220, 200))
	var said: String = str(await _tools.run("page_setup", {"picture_data":
		Marshalls.raw_to_base64(photo.save_jpg_to_buffer(0.9))}))
	print("    page_setup picture_data= (4000 x 3000): %s" % said)
	var data: String = str(BookletLooks.images(_world).get(_page()["picture"], ""))
	var kept := Image.new()
	var read: int = kept.load_jpg_from_buffer(Marshalls.base64_to_raw(data))
	_check("a 4000 x 3000 photograph behind the booklet's own 269 x 199 mm page: a JPEG of %d x %d px (1980 x 1485: A4's 297 mm at 5 px a mm, either way up), %d KB"
		% [kept.get_width(), kept.get_height(), data.length() / 1024],
		read == OK and BookletLooks.picture_kind(data) == "jpeg" and absi(kept.get_width() - 1980) <= 1
		and absi(kept.get_height() - 1485) <= 1)
	_check("...page_setup says its size in the file (\"%s\")" % said.substr(said.find("a picture behind")).left(60),
		said.contains("KB in the file"))
	var dialog: Window = await _page_dialog()
	var label: Label = dialog.get("_picture") if dialog != null else null
	_check("...and Page setup…: \"%s\"" % (label.text if label else "?"), label != null
		and label.text.begins_with("A JPEG, ") and label.text.ends_with("KB in the file"))
	if dialog != null:
		dialog.hide()
	# Chosen on A5 on its side, the paper then made A4 upright: still drawn
	# at 5 px a mm (ps2review: 2.65, kept for the A5 page).
	await _tools.run("page_setup", {"size": "A5", "orientation": "landscape",
		"picture_data": Marshalls.raw_to_base64(photo.save_jpg_to_buffer(0.9))})
	await _tools.run("page_setup", {"size": "A4", "orientation": "portrait"})
	data = str(BookletLooks.images(_world).get(_page()["picture"], ""))
	kept.load_jpg_from_buffer(Marshalls.base64_to_raw(data))
	var drawn: float = minf(kept.get_width() / 210.0, kept.get_height() / 297.0)
	_check("chosen on A5 on its side, the paper then A4 upright: %d x %d, drawn at %.2f px a mm (5)"
		% [kept.get_width(), kept.get_height(), drawn], drawn >= 4.99)
	# A panorama: only what a page can show of its middle kept (ps2review: 15920 x 995, 1888 KB).
	var pano := Image.create(16000, 1000, false, Image.FORMAT_RGB8)
	for x: int in range(0, 16000, 500):
		pano.fill_rect(Rect2i(x, 0, 500, 1000), Color.from_hsv(x / 16000.0, 0.6, 0.8))
	var two: bool = _arguments(_sheet, "picture_of") == 2
	var wide: Array = _sheet.call("picture_of", pano, Vector2(269.0, 199.0)) if two \
		else _sheet.call("picture_of", pano)
	var wide_image := Image.new()
	wide_image.load_jpg_from_buffer(Marshalls.base64_to_raw(str(wide[1])))
	var every: bool = true
	for paper: Vector2 in [Vector2(269, 199), Vector2(297, 210), Vector2(279.4, 215.9), Vector2(210, 148)]:
		for page: Vector2 in [paper, Vector2(paper.y, paper.x)]:
			# What of the panorama the page shows, covering it from its middle, in its px.
			every = every and wide_image.get_width() >= floori(page.x / page.y * 1000.0) \
				and wide_image.get_height() >= mini(1000, floori(page.y / page.x * 16000.0))
	var wide_kb: int = int(_sheet.call("picture_kb", str(wide[1])))
	_check("a 16000 x 1000 panorama: %d x %d, %d KB in the file (at most 1419 x 1000), every page's share of it whole"
		% [wide_image.get_width(), wide_image.get_height(), wide_kb], wide_image.get_width() <= 1419
		and wide_image.get_height() == 1000 and every and wide_kb < 1024)
	# Chosen for an upright A4 page in the same call: kept for every paper.
	var upright := Image.create(3000, 4000, false, Image.FORMAT_RGB8)
	upright.fill(Color8(200, 180, 90))
	await _tools.run("page_setup", {"size": "A4", "orientation": "portrait",
		"picture_data": Marshalls.raw_to_base64(upright.save_jpg_to_buffer(0.9))})
	data = str(BookletLooks.images(_world).get(_page()["picture"], ""))
	kept.load_jpg_from_buffer(Marshalls.base64_to_raw(data))
	_check("a 3000 x 4000 one for an upright A4 page in the same call: %d x %d (1485 x 1980)"
		% [kept.get_width(), kept.get_height()], absi(kept.get_width() - 1485) <= 1
		and absi(kept.get_height() - 1980) <= 1)
	# See-through: random colour and see-through in every pixel, a PNG's worst.
	var noise := Image.create_from_data(1600, 1200, false, Image.FORMAT_RGBA8,
		Crypto.new().generate_random_bytes(1600 * 1200 * 4))
	var clear: Array = _sheet.call("picture_of", noise, Vector2(269.0, 199.0)) if two \
		else _sheet.call("picture_of", noise)
	var png := Image.new()
	png.load_png_from_buffer(Marshalls.base64_to_raw(str(clear[1])))
	var bytes: int = Marshalls.base64_to_raw(str(clear[1])).size()
	_check("a see-through 1600 x 1200 photograph of noise: a PNG of %d x %d, %d KB (at most 1024 KB, or 900 px long)"
		% [png.get_width(), png.get_height(), bytes / 1024], str(clear[0]).ends_with(".png")
		and (bytes <= 1024 * 1024 or maxi(png.get_width(), png.get_height()) <= 900))
	var opaque := Image.create_from_data(800, 600, false, Image.FORMAT_RGB8,
		Crypto.new().generate_random_bytes(800 * 600 * 3))
	opaque.convert(Image.FORMAT_RGBA8)
	var solid: Array = _sheet.call("picture_of", opaque, Vector2(269.0, 199.0)) if two \
		else _sheet.call("picture_of", opaque)
	_check("one with a see-through channel that shows nothing through: a JPEG (%s)" % str(solid[0]),
		str(solid[0]).ends_with(".jpg"))


## The style files, by name.
func _style_files() -> PackedStringArray:
	return DirAccess.get_files_at("user://page_styles") if DirAccess.dir_exists_absolute(
		"user://page_styles") else PackedStringArray()


## The style files' folder's pictures, by name.
func _style_pictures() -> PackedStringArray:
	var folder: String = "user://page_styles/pictures"
	return DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray()


## The styles a new start of the app reads: this probe, run again headless
## on the same user folder, saying them.
func _new_start() -> PackedStringArray:
	var said: Array = []
	OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://src/dev/pagesetup_probe.gd", "--", "--list-styles"], said, true)
	var names := PackedStringArray()
	for line: String in "\n".join(said).split("\n"):
		if line.begins_with("STYLE "):
			names.append(line.trim_prefix("STYLE ").strip_edges())
	return names


## Styles: a picture two share kept once, taken away in Page setup… and
## over MCP, gone in a new start; the styles one file kept before moved;
## that file left as it was when it cannot be read.
func _styles_kept() -> void:
	print("")
	print("styles: a picture kept once, styles taken away, and the styles kept before")
	if not _check("BookletSheet is here", _sheet != null):
		return
	for name: String in (_sheet.call("styles") as Dictionary).keys():
		_forget(name)
	var image := Image.create(400, 300, false, Image.FORMAT_RGB8)
	image.fill(Color8(120, 40, 160))
	await _tools.run("page_setup", {"size": "A5", "picture_data":
		Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.9))})
	await _tools.run("page_setup", {"save_as": "Probe one"})
	await _tools.run("page_setup", {"colour": "#ffffff", "save_as": "Probe two"})
	var styles: Dictionary = _sheet.call("styles")
	_check("two styles kept with one picture (%s): the picture kept once (%d file)" % [
		", ".join(styles.keys()), _style_pictures().size()], styles.has("Probe one")
		and styles.has("Probe two") and _style_pictures().size() == 1)
	var files: PackedStringArray = DirAccess.get_files_at("user://page_styles") \
		if DirAccess.dir_exists_absolute("user://page_styles") else PackedStringArray()
	var small: bool = files.size() == 2
	for file_name: String in files:
		small = small and FileAccess.get_file_as_bytes("user://page_styles".path_join(file_name)).size() < 2048
	_check("...each style a small file of its own, its picture not in it (%s)" % ", ".join(files), small)
	var dialog: Window = await _page_dialog()
	var remove: MenuButton = dialog.get("_remove") if dialog != null else null
	var confirm: ConfirmationDialog = dialog.get("_confirm") if dialog != null else null
	var index: int = -1
	if remove != null:
		for at: int in remove.get_popup().item_count:
			if remove.get_popup().get_item_text(at) == "Probe one":
				index = at
	if _check("Page setup…, Remove…: \"Probe one\" listed", index >= 0 and confirm != null):
		remove.get_popup().index_pressed.emit(index)
		await _frames(2)
		await _shot("page_setup_remove")
		_check("...asked first: \"%s\"" % confirm.dialog_text, confirm.visible
			and confirm.dialog_text.contains("Probe one"))
		confirm.confirmed.emit()
		await _frames(2)
		confirm.hide()
	if dialog != null:
		dialog.hide()
	styles = _sheet.call("styles")
	_check("...taken away: %s left; the picture \"Probe two\" shows still kept (%d)" % [
		", ".join(styles.keys()), _style_pictures().size()], not styles.has("Probe one")
		and styles.has("Probe two") and _style_pictures().size() == 1)
	# A call refused for another field takes nothing away (ps2review: the
	# style was gone and the answer said only the refusal).
	var refused: String = str(await _tools.run("page_setup", {"remove_style": "Probe two", "size": "B5"}))
	_check("page_setup remove_style= with size=B5: refused (%s), the style still kept" % refused.left(60),
		(_sheet.call("styles") as Dictionary).has("Probe two"))
	# Replaced with another picture each time: its last picture alone kept
	# (ps2review: 6 pictures for 2 styles after 5).
	var shown_before: int = _style_pictures().size()
	for n: int in 5:
		var other := Image.create(64, 48, false, Image.FORMAT_RGB8)
		other.fill(Color8(n * 40, 90, 20))
		await _tools.run("page_setup", {"picture_data": Marshalls.raw_to_base64(other.save_jpg_to_buffer(0.9)),
			"save_as": "Probe two"})
	_check("\"Probe two\" replaced 5 times, a new picture each: pictures kept %d (%d before)"
		% [_style_pictures().size(), shown_before], _style_pictures().size() == 1)
	var said: String = str(await _tools.run("page_setup", {"remove_style": "Probe two"}))
	print("    page_setup remove_style=\"Probe two\": %s" % said)
	styles = _sheet.call("styles")
	_check("page_setup remove_style=: taken away, and the picture no style shows with it (%d)"
		% _style_pictures().size(), not styles.has("Probe two") and _style_pictures().is_empty())
	var restart: PackedStringArray = _new_start()
	_check("a new start of the app reads neither (%s)" % ", ".join(restart),
		not restart.has("Probe one") and not restart.has("Probe two"))
	# The styles one file kept, as pagesetup kept them.
	var old := ConfigFile.new()
	var picture: String = Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.9))
	old.set_value("Probe old", "style", {"paper": "a5", "portrait": true,
		"picture": "brickworks-page-behind.jpg", "picture_data": picture})
	old.save("user://page_styles.cfg")
	var one_file: PackedByteArray = FileAccess.get_file_as_bytes("user://page_styles.cfg")
	# Only looking writes nothing (ps2review: the list moved them, writing
	# files and taking the one file away).
	var dialog_list: Window = await _page_dialog()
	if dialog_list != null:
		dialog_list.hide()
	var looked: String = str(await _tools.run("page_setup", {}))
	styles = _sheet.call("styles")
	_check("a style the one file kept: listed (%s; page_setup: %s), the one file byte for byte, no file written (%d, %d)"
		% [", ".join(styles.keys()), looked.substr(looked.find("Styles kept")).left(60),
		_style_files().size(), _style_pictures().size()], styles.has("Probe old")
		and looked.contains("Probe old")
		and FileAccess.get_file_as_bytes("user://page_styles.cfg") == one_file
		and _style_files().is_empty() and _style_pictures().is_empty())
	await _tools.run("page_setup", {"style": "Probe old"})
	_check("...and given to the model whole, picture and all (%s), nothing written"
		% str(_page()["said"]).left(120), _page()["size"] == Vector2(148, 210)
		and BookletLooks.images(_world).get(_page()["picture"], "") == picture
		and FileAccess.get_file_as_bytes("user://page_styles.cfg") == one_file and _style_files().is_empty())
	await _tools.run("page_setup", {"save_as": "Probe next"})
	_check("a style kept next: the one file's moved into a file of its own, that file gone (%s)"
		% ", ".join(_style_files()), _style_files().size() == 2
		and not FileAccess.file_exists("user://page_styles.cfg") and _style_pictures().size() == 1)
	_forget("Probe next")
	var broken := PackedByteArray([0x5b, 0x62, 0x72, 0x6f, 0x6b, 0x65, 0x6e, 0x0a, 0x00, 0xff, 0x3d])
	var file: FileAccess = FileAccess.open("user://page_styles.cfg", FileAccess.WRITE)
	file.store_buffer(broken)
	file.close()
	var kept: String = str(await _tools.run("page_setup", {"save_as": "Probe new"}))
	print("    page_setup save_as=\"Probe new\": %s" % kept)
	_check("a one file of styles that cannot be read: left byte for byte, and a style kept beside it",
		FileAccess.get_file_as_bytes("user://page_styles.cfg") == broken
		and (_sheet.call("styles") as Dictionary).has("Probe new"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://page_styles.cfg"))
	for name: String in ["Probe old", "Probe new"]:
		_forget(name)


## Two windows on one user folder: this one keeping a style on a picture,
## reading it back and taking it away, while the other (this probe again,
## headless, --race-remove) keeps and takes away a style on the same
## picture. ps2review: 896 of 3000 read back with their picture gone.
func _two_windows() -> void:
	print("")
	print("two windows on one user folder: styles kept in one as the other takes one away")
	if not _check("BookletSheet is here", _sheet != null):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RACE_STARTED))
	var pid: int = OS.create_process(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://src/dev/pagesetup_probe.gd",
		"--", "--race-remove=4000"])
	var until: int = Time.get_ticks_msec() + 30000
	while not FileAccess.file_exists(RACE_STARTED) and OS.is_process_running(pid) \
			and Time.get_ticks_msec() < until:
		await _frames(1)
	var started: bool = FileAccess.file_exists(RACE_STARTED)
	var sheet: Object = _sheet.call("from", {"picture": "brickworks-page-behind.jpg"})
	var picture: String = _race_picture()
	var kept: int = 0
	var lost: int = 0
	while started and OS.is_process_running(pid) and kept < 20000:
		var name: String = "Probe race %d" % kept
		_sheet.call("save_style", name, sheet, picture)
		var back: Dictionary = _sheet.call("style", name)
		if bool(back.get("picture_lost", false)) or str(back.get("picture_data", "")) != picture:
			lost += 1
		_sheet.call("remove_style", name)
		kept += 1
	if OS.is_process_running(pid):
		OS.kill(pid)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RACE_STARTED))
	_check("%d styles kept here as the other window kept and took away its own 4000 times: %d read back without their picture, %d pictures left"
		% [kept, lost, _style_pictures().size()], started and kept >= 200 and lost == 0
		and _style_pictures().is_empty())


## The one picture both windows of _two_windows keep styles on.
static func _race_picture() -> String:
	var image := Image.create(400, 300, false, Image.FORMAT_RGB8)
	image.fill(Color8(30, 60, 90))
	image.fill_rect(Rect2i(100, 80, 200, 140), Color8(220, 200, 60))
	return Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.9))


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
