## The booklet, the designer's way (APP_UX6 #5, booklook): a cover of their
## own, words at the head and foot of every page, the parts box's frame,
## fill and corners, the step numbers' colour and the colour round the new
## parts, by Build, Booklet page, Page setup… and page_setup over MCP.
##
##   godot --path . --resolution 1280x720 --script src/dev/booklook_probe.gd -- [--into=DIR] [--against=DIR] [--dialog-only]
##
## Windowed, on the GPU: the booklet's pictures are drawn, and its pages as
## PNGs. On the gatehouse (tests/fixtures/steps/gatehouse.mpd), each booklet
## printed as Instructions prints it, its PDF read by poppler (pdftotext,
## pdfimages, pdftoppm at 300 dots an inch) and its pages drawn at 300
## (BookletPng):
##
## - The booklet's own, nothing set: with --against=DIR (this probe's
##   folder from a run on the commit before: usual.html, usual-page-NNN.png,
##   usual-pdf-N.png), its file the same but for its pictures, and every
##   PNG page and every page of its PDF as poppler draws it the same to the
##   pixel.
## - A cover of the person's own, set by hand in Page setup…'s Cover tab
##   (a title, a line under it, a picture of theirs, a line of their words):
##   read back off the PDF (pdftotext's words, pdfimages' JPEG the model's
##   own byte for byte) and off the PNG cover (the picture's four colours
##   where it is fitted, no badge, each line of words inked as wide as its
##   words are, where they are; poppler's drawing of the PDF's cover the
##   same).
## - The step numbers' colour and the new parts' outline by hand in the
##   Steps tab; a header, a footer and the parts box's frame, fill and
##   corners over MCP in 1 call.
## - The footer on every page, the header on every page but the cover: in
##   each page's PDF words and inked on each PNG page.
## - Every parts box framed in the chosen colour and filled in the chosen
##   fill, its corners rounder, with 0 px of the old frame's or fill's
##   colour, on the PNG pages and the PDF's.
## - Every step number in the chosen colour, 0 px of the old ink; every
##   step picture's new parts outlined in the chosen colour, 0 px of the old
##   orange (which the booklet's own has).
## - tools/booklet_pdf_check.py passing.
## - Kept over a save and an open, each in the file; one undo.
## - Kept as a style, then given to booklet3's model in 2 actions (Page
##   setup…, the style): every field, the cover's picture byte for byte, and
##   its booklet's cover and footer read back off its PDF.
## - page_setup with nothing says it all.
## - Page setup…'s three tabs, each inside the window with every control in
##   sight: at this size, and with --dialog-only alone (PROBE_SIZE=1400x900).
##
## What booklook adds is reached by name (get, call), so this runs on the
## commit before too, and fails there where a person would.
extends SceneTree

const B3 := preload("res://src/dev/booklet3_probe.gd")
const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"
const STYLE := "Probe booklook"
const DENSITY := 300.0 / 25.4

const TITLE := "The Gatehouse of Probe Hill"
const SUBTITLE := "A gate for a small castle"
const LINE := "Designed by A. Builder, 2026"
const HEADER := "The Gatehouse: building instructions"
const FOOTER := "© 2026 Probe Builds. Not for resale."
const FRAME := Color8(192, 57, 43)
const FILL := Color8(255, 244, 214)
const CORNERS := 4.0
const NUMBER := Color8(30, 123, 52)
const OUTLINE := Color8(123, 44, 191)
## The booklet's own, which none of these may leave a pixel of.
const OLD_FRAME := Color8(61, 111, 151)
const OLD_FILL := Color8(188, 218, 241)
const OLD_INK := Color8(21, 25, 30)
const OLD_OUTLINE := Color8(255, 133, 15)
## How near the old orange a pixel is counted as it: the gatehouse's yellow
## parts shade to (215-232, 165-173, 0-55), 32 or more from it in a channel,
## which 40 counted (78 px on its styled pages, the same 35 on its own).
const OLD_OUTLINE_NEAR := 28.0 / 255.0
const BADGE := Color8(208, 49, 45)
## The cover's picture of the person's own: four colours, a quarter each.
const QUARTERS: Array = [Color8(220, 40, 40), Color8(40, 170, 70), Color8(40, 80, 200),
	Color8(240, 200, 40)]

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
## The old orange counted in the booklet's own step pictures.
var _usual_orange: int = -1


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
		_out = OS.get_user_data_dir().path_join("booklook_probe")
	DirAccess.make_dir_recursive_absolute(_out)
	Download.folder = _out
	BookletMaker.open_when_written = false
	print("booklook: the window %s, %s" % [str(root.size), "BookletSheet has a cover"
		if "cover_picture" in BookletSheet.new() else "BookletSheet has no cover"])
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
	_forget(STYLE)
	await _open(ProjectSettings.globalize_path(GATEHOUSE), 14)
	if dialog_only:
		await _dialog_fits()
		_quit()
		return
	await _usual()
	await _dialog_fits()
	await _set_up()
	var printed: Dictionary = await _printed("styled")
	await _cover_read_back(printed, BookletLooks.images(_world))
	await _every_page(printed)
	_boxes(printed)
	_numbers_and_outline(printed)
	_pdf_check(printed, "the gatehouse's booklet")
	await _kept()
	await _style_to_other()
	_quit()


func _quit() -> void:
	_forget(STYLE)
	print("")
	print("booklook: %s" % ("every check passed" if _failures == 0
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


func _sheet() -> BookletSheet:
	return BookletSheet.of(_world)


## A field of the model's page by name: null where the build has none.
func _field(name: String) -> Variant:
	return _sheet().get(name)


## The same colour, as the file keeps it (two hex digits a channel); the
## probe's own, so it loads on the commit before, which has no
## BookletSheet.same_colour.
static func _same(a: Variant, b: Color) -> bool:
	return a is Color and (a as Color).to_html(false) == b.to_html(false)


## A style taken away, where it is kept.
func _forget(name: String) -> void:
	if BookletSheet.styles().has(name):
		BookletSheet.remove_style(name)


# -- printing -----------------------------------------------------------------


## The booklet made from the model as it is, written out, its PDF and its
## pages: {html, path, pdf, zip, document, stem, pages, read (BookletRead
## pages by number)}.
func _printed(stem: String) -> Dictionary:
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var started: int = Time.get_ticks_msec()
	var html: String = await maker.make(_world, _store.scenery, _shell.bar.model_name())
	var document: Booklet.Document = maker.document
	maker.queue_free()
	if not _check("%s: the booklet was made (%d pages, %.1f s)" % [stem, document.pages.size()
			if document != null else 0, (Time.get_ticks_msec() - started) / 1000.0],
			not html.is_empty() and document != null):
		return {}
	var path: String = _out.path_join(stem + ".html")
	_write(path, html)
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
	_check("...its PDF (%d pages) and its pages as PNG (%d)" % [pages, drawn],
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
	var laid: Dictionary = {}
	BookletRead.new().read_file(path, func(page: BookletRead.Page) -> void: laid[page.number] = page)
	return {"html": html, "path": path, "pdf": pdf, "zip": zip, "document": document, "stem": stem,
		"pages": pages, "read": laid}


func _png(printed: Dictionary, number: int) -> Image:
	return Image.load_from_file(_out.path_join("%s-page-%03d.png" % [printed["stem"], number]))


func _pdf_page(printed: Dictionary, number: int) -> Image:
	for width: int in [1, 2, 3]:
		var path: String = _out.path_join("%s-pdf-%s.png" % [printed["stem"],
			str(number).pad_zeros(width)])
		if FileAccess.file_exists(path):
			return Image.load_from_file(path)
	return null


## The words poppler reads off page [param number] of the PDF.
func _pdf_words(printed: Dictionary, number: int) -> String:
	var said: Array = []
	OS.execute("pdftotext", ["-f", str(number), "-l", str(number), "-layout",
		ProjectSettings.globalize_path(printed["pdf"]), "-"], said)
	return "".join(said)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _at(image: Image, mm: Vector2) -> Color:
	if image == null:
		return Color(0, 0, 0, 0)
	var px := Vector2i((mm * DENSITY).round()).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	return image.get_pixelv(px)


static func _near(a: Color, b: Color, within: float) -> bool:
	return absf(a.r - b.r) <= within and absf(a.g - b.g) <= within and absf(a.b - b.b) <= within


## How many pixels of [param image] inside [param rect] (mm), every
## [param stride]th, are [param colour] within [param within], but for
## those in any of [param skip].
static func _count(image: Image, rect: Rect2, colour: Color, within: float, skip: Array = [],
		stride: int = 1) -> int:
	if image == null:
		return -1
	var from := Vector2i((rect.position * DENSITY).floor()).clamp(Vector2i.ZERO, image.get_size())
	var to := Vector2i((rect.end * DENSITY).ceil()).clamp(Vector2i.ZERO, image.get_size())
	var found: int = 0
	for y: int in range(from.y, to.y, stride):
		for x: int in range(from.x, to.x, stride):
			if not _near(image.get_pixel(x, y), colour, within):
				continue
			var mm := Vector2(x, y) / DENSITY
			if skip.any(func(out: Rect2) -> bool: return out.has_point(mm)):
				continue
			found += 1
	return found


# -- the booklet's own, unchanged ---------------------------------------------


func _usual() -> void:
	print("")
	print("the booklet's own, nothing set")
	var said: Variant = _sheet().said()
	_check("the gatehouse's page is the booklet's own (%s)" % str(said), (said as Dictionary).is_empty())
	var printed: Dictionary = await _printed("usual")
	if printed.is_empty():
		return
	_usual_orange = _outline_count(printed, OLD_OUTLINE, OLD_OUTLINE_NEAR)
	print("    the booklet's own orange round the new parts: %d px in its step pictures" % _usual_orange)
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
	for kind: String in ["page", "pdf"]:
		var off: Array = []
		var differing: int = 0
		var compared: int = 0
		for number: int in range(1, int(printed["pages"]) + 1):
			var now: Image = _png(printed, number) if kind == "page" else _pdf_page(printed, number)
			var was: Image = null
			if kind == "page":
				was = Image.load_from_file(_against.path_join("usual-page-%03d.png" % number))
			else:
				for width: int in [1, 2, 3]:
					var path: String = _against.path_join("usual-pdf-%s.png" % str(number).pad_zeros(width))
					if FileAccess.file_exists(path):
						was = Image.load_from_file(path)
			if now == null or was == null or now.get_size() != was.get_size() \
					or now.get_format() != was.get_format():
				off.append(number)
				continue
			compared += 1
			if now.get_data() == was.get_data():
				continue
			off.append(number)
			for y: int in now.get_height():
				for x: int in now.get_width():
					if now.get_pixel(x, y) != was.get_pixel(x, y):
						differing += 1
		_check("...every one of its %d %s the same to the pixel (%d compared, %d pixels differ, pages %s)"
			% [int(printed["pages"]), "PNG pages" if kind == "page" else "PDF pages as poppler draws them",
				compared, differing, str(off)], off.is_empty() and compared == int(printed["pages"]))


# -- Page setup… in the window ---------------------------------------------------


func _page_dialog() -> Window:
	if not _shell.run("booklet_page_setup"):
		return null
	await _frames(6)
	return _shell.get("_page_setup_dialog")


## Each of Page setup…'s tabs inside the window, every control inside it.
func _dialog_fits() -> void:
	print("")
	print("Page setup… in a %s window" % str(root.size))
	var dialog: Window = await _page_dialog()
	if not _check("Page setup… opens", dialog != null and dialog.visible):
		return
	var tabs: Variant = dialog.get("_tabs")
	if not _check("...in tabs (%s)" % ("%d" % (tabs as TabContainer).get_tab_count() if tabs is TabContainer
			else "none"), tabs is TabContainer and (tabs as TabContainer).get_tab_count() == 3):
		await _fits(dialog, "page_setup")
		dialog.hide()
		return
	for index: int in 3:
		(tabs as TabContainer).current_tab = index
		await _frames(4)
		await _fits(dialog, "page_setup_%s" % (tabs as TabContainer).get_tab_title(index).to_lower())
	(tabs as TabContainer).current_tab = 0
	dialog.hide()


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
	_check("%s: the dialog %s inside the %s window, its %d controls inside it (%s)" % [name,
		str(box), str(root.size), shown, str(out.slice(0, 3)) if not out.is_empty() else "all"],
		window.encloses(box) and shown > 6 and out.is_empty())
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join("%s_%dx%d.png" % [name, root.size.x, root.size.y])
	if image != null:
		image.save_png(path)
		print("    picture: %s" % ProjectSettings.globalize_path(path))


## The cover's picture of the person's own: 800 x 500, a colour a quarter.
static func _quarters() -> Image:
	var image := Image.create(800, 500, false, Image.FORMAT_RGB8)
	for index: int in 4:
		image.fill_rect(Rect2i((index % 2) * 400, (index / 2) * 250, 400, 250), QUARTERS[index])
	return image


## The cover and the steps' colours by hand in Page setup…; the head, foot
## and parts box over MCP in 1 call.
func _set_up() -> void:
	print("")
	print("the cover and the steps' colours by hand, the rest over MCP")
	var dialog: Window = await _page_dialog()
	if not _check("Page setup… opens", dialog != null and dialog.visible):
		return
	var tabs: Variant = dialog.get("_tabs")
	if tabs is TabContainer:
		(tabs as TabContainer).current_tab = 1
		await _frames(3)
	for typed: Array in [["_title", TITLE], ["_subtitle", SUBTITLE], ["_cover_line", LINE]]:
		var edit: Variant = dialog.get(typed[0])
		if edit is LineEdit:
			(edit as LineEdit).text = typed[1]
			(edit as LineEdit).text_submitted.emit(typed[1])
			await _frames(2)
	var picker: Variant = dialog.get("_picker")
	if picker is PickImage and dialog.get("_picking") != null:
		dialog.set("_picking", "cover")
		(picker as PickImage).picked.emit(_quarters())
		await _frames(3)
	await _shot("page_setup_cover_set")
	if tabs is TabContainer:
		(tabs as TabContainer).current_tab = 2
		await _frames(3)
	for picked: Array in [["_number_colour", NUMBER], ["_outline", OUTLINE]]:
		var button: Variant = dialog.get(picked[0])
		if button is ColorPickerButton:
			(button as ColorPickerButton).color = picked[1]
			(button as ColorPickerButton).popup_closed.emit()
			await _frames(2)
	await _shot("page_setup_steps_set")
	dialog.hide()
	var said: String = str(await _tools.run("page_setup", {"header": HEADER, "footer": FOOTER,
		"box_frame": "#" + FRAME.to_html(false), "box_fill": "#" + FILL.to_html(false),
		"box_corners": CORNERS}))
	print("    page_setup header= footer= box_frame= box_fill= box_corners=: %s" % said)
	var sheet: BookletSheet = _sheet()
	var cover: String = str(_field("cover_picture"))
	_check("by hand: the cover's title, line under it and line of words (%s / %s / %s), and its picture (%s, %d bytes of base64)"
		% [str(_field("title")), str(_field("subtitle")), str(_field("cover_line")), cover,
			str(BookletLooks.images(_world).get(cover, "")).length()],
		_field("title") == TITLE and _field("subtitle") == SUBTITLE and _field("cover_line") == LINE
		and cover.begins_with("brickworks-page-cover") and BookletLooks.images(_world).has(cover))
	_check("...the step numbers #%s and the outline #%s" % [_hex(_field("number_colour")),
		_hex(_field("outline_colour"))], _field("number_colour") is Color
		and _same(_field("number_colour"), NUMBER) and _field("outline_colour") is Color
		and _same(_field("outline_colour"), OUTLINE))
	_check("over MCP in 1 call: the header, the footer, the parts box #%s on #%s, corners %s mm"
		% [_hex(_field("box_frame")), _hex(_field("box_fill")), str(_field("box_corners"))],
		_field("header") == HEADER and _field("footer") == FOOTER and _field("box_frame") is Color
		and _same(_field("box_frame"), FRAME)
		and _same(_field("box_fill"), FILL)
		and is_equal_approx(float(_field("box_corners")), CORNERS))
	var told: String = str(await _tools.run("page_setup", {}))
	print("    page_setup: %s" % told)
	_check("page_setup with nothing says the cover, the header and footer and the colours",
		told.contains(TITLE) and told.contains(FOOTER) and told.contains(HEADER)
		and told.contains(FRAME.to_html(false)) and told.contains(OUTLINE.to_html(false)))
	print("    %s" % sheet.words())


static func _hex(colour: Variant) -> String:
	return (colour as Color).to_html(false) if colour is Color else "none"


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join("%s_%dx%d.png" % [name, root.size.x, root.size.y])
	if image != null:
		image.save_png(path)
		print("    picture: %s" % ProjectSettings.globalize_path(path))


# -- the cover, read back ----------------------------------------------------------


func _cover_read_back(printed: Dictionary, pictures: Dictionary) -> void:
	print("")
	print("the cover, read back off the PDF and the PNG")
	if printed.is_empty():
		return
	var words: String = _pdf_words(printed, 1)
	_check("the PDF's cover says the title, the line under it and the line of words (%s)"
		% words.strip_edges().replace("\n", " | ").left(200),
		words.contains(TITLE) and words.contains(SUBTITLE) and words.contains(LINE))
	# The picture in the PDF as it is in the model, a JPEG passed through.
	var cover: String = str(_field("cover_picture"))
	var kept: PackedByteArray = Marshalls.base64_to_raw(str(pictures.get(cover, "")))
	var prefix: String = ProjectSettings.globalize_path(_out.path_join(str(printed["stem"]) + "-cover"))
	OS.execute("pdfimages", ["-f", "1", "-l", "1", "-j", ProjectSettings.globalize_path(printed["pdf"]),
		prefix])
	var found: Array = []
	for file_name: String in DirAccess.get_files_at(_out):
		if file_name.begins_with(str(printed["stem"]) + "-cover"):
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_out.path_join(file_name))
			found.append([file_name, bytes.size(), bytes == kept])
	_check("...its picture the model's own JPEG, byte for byte (%d bytes; in the PDF: %s)" % [kept.size(),
		str(found)], not kept.is_empty() and found.any(func(one: Array) -> bool: return bool(one[2])))
	var sheet: BookletSheet = _sheet()
	var area: Rect2 = Booklet.cover_area(sheet)
	var natural := Vector2(800, 500)
	var shown: Vector2 = natural * minf(area.size.x / natural.x, area.size.y / natural.y)
	var fitted := Rect2(area.get_center() - shown * 0.5, shown)
	for kind: String in ["PNG", "PDF"]:
		var image: Image = _png(printed, 1) if kind == "PNG" else _pdf_page(printed, 1)
		var read: Array = []
		var right: bool = image != null
		for index: int in 4:
			var at: Vector2 = fitted.position + fitted.size * Vector2(0.25 + 0.5 * (index % 2),
				0.25 + 0.5 * (index / 2))
			var colour: Color = _at(image, at)
			read.append("#" + colour.to_html(false))
			right = right and _near(colour, QUARTERS[index], 16.0 / 255.0)
		_check("...the %s cover's picture where it is fitted, %s: its four colours (%s)" % [kind,
			str(fitted).replace("(", "").replace(")", ""), ", ".join(read)], right)
		var badge: int = _count(image, Rect2(0, 0, sheet.size().x, 30), BADGE, 24.0 / 255.0)
		_check("...no BRICKWORKS badge on the %s cover (%d px of its red)" % [kind, badge], badge == 0)
		var page: BookletRead.Page = (printed["read"] as Dictionary).get(1)
		for said: String in [TITLE, SUBTITLE, LINE]:
			var op: Dictionary = _text_op(page, said)
			var span: Vector2 = _ink_span(image, op)
			var want := Vector2(float(op.get("x", 0.0)), float(op.get("x", 0.0)) + float(op.get("wide", 0.0)))
			_check("...\"%s\" inked on the %s cover from %.1f to %.1f mm (its words %.1f to %.1f)"
				% [said, kind, span.x, span.y, want.x, want.y], not op.is_empty()
				and absf(span.x - want.x) <= 1.2 and absf(span.y - want.y) <= 1.2)


## The line of words [param said] on [param page] (BookletRead): {x, wide,
## baseline, size, colour}; {} where it is not there.
static func _text_op(page: BookletRead.Page, said: String) -> Dictionary:
	if page == null:
		return {}
	for op: Dictionary in page.ops:
		if op["k"] == "text" and str(op["text"]) == said:
			return {"x": (op["at"] as Vector2).x, "baseline": (op["at"] as Vector2).y,
				"size": float(op["size"]), "colour": op["colour"], "wide": Helvetica.text_width(said,
					float(op["size"]), bool(op["bold"]), float(op["spacing"]))}
	return {}


## From where to where across [param image], in mm, a line of words
## ([method _text_op]) is inked in its colour, between its letters' tops
## and its baseline.
static func _ink_span(image: Image, op: Dictionary) -> Vector2:
	if image == null or op.is_empty():
		return Vector2(-99, -99)
	var size: float = op["size"]
	var top: int = roundi((float(op["baseline"]) - size * 0.7) * DENSITY)
	var bottom: int = roundi(float(op["baseline"]) * DENSITY)
	# Within 3 mm of where its words are: the page's other words in its
	# grey, and the edges of its number, are not its.
	var left: int = maxi(0, roundi((float(op["x"]) - 3.0) * DENSITY))
	var right: int = mini(image.get_width(), roundi((float(op["x"]) + float(op["wide"]) + 3.0) * DENSITY))
	var least: int = image.get_width()
	var most: int = -1
	for y: int in range(maxi(0, top), mini(image.get_height(), bottom)):
		for x: int in range(left, right):
			if _near(image.get_pixel(x, y), op["colour"], 0.2):
				least = mini(least, x)
				most = maxi(most, x)
	return Vector2(least, most + 1) / DENSITY if most >= 0 else Vector2(-99, -99)


# -- every page ------------------------------------------------------------------


func _every_page(printed: Dictionary) -> void:
	print("")
	print("the header and the footer on every page")
	if printed.is_empty():
		return
	var count: int = int(printed["pages"])
	var no_footer: Array = []
	var no_header: Array = []
	var not_inked: Array = []
	for number: int in range(1, count + 1):
		var words: String = _pdf_words(printed, number)
		if not words.contains(FOOTER):
			no_footer.append(number)
		if number > 1 and not words.contains(HEADER):
			no_header.append(number)
		var page: BookletRead.Page = (printed["read"] as Dictionary).get(number)
		for said: String in [FOOTER] + ([HEADER] if number > 1 else []):
			var op: Dictionary = _text_op(page, said)
			for image: Image in [_png(printed, number), _pdf_page(printed, number)]:
				var span: Vector2 = _ink_span(image, op)
				if op.is_empty() or absf(span.x - float(op["x"])) > 1.0 \
						or absf(span.y - float(op["x"]) - float(op["wide"])) > 1.0:
					not_inked.append("page %d %s: %.1f-%.1f, its words at %.1f" % [number,
						said.left(10), span.x, span.y, float(op.get("x", -1.0))])
	_check("the footer in the PDF's words of every one of its %d pages (%s without)" % [count,
		str(no_footer)], count > 1 and no_footer.is_empty())
	_check("...the header on every page but the cover (%s without)" % str(no_header),
		no_header.is_empty())
	_check("...each inked where its words are, as wide as they are, on every PNG page and the PDF's (%s)"
		% (str(not_inked.slice(0, 3)) if not not_inked.is_empty() else "all"), not_inked.is_empty())


## Every step's parts box on the steps' and callouts' pages: [[page number,
## the box, the part pictures in it]].
static func _parts_boxes(document: Booklet.Document) -> Array:
	var out: Array = []
	for laid: Booklet.Page in document.pages:
		if not laid.kind in ["steps", "callout"]:
			continue
		for entry: Booklet.Entry in laid.entries:
			if entry.lots.is_empty():
				continue
			var cells: Array = []
			var y: float = entry.parts_rect.position.y + Booklet.PAD
			for row: Array in Booklet._rows(entry.lots, entry.parts_width):
				var x: float = entry.parts_rect.position.x + Booklet.PAD
				var tallest: float = float(row[2])
				for lot: Booklet.Lot in row[0]:
					var cell: float = maxf(lot.size.x, Booklet.QUANTITY * 2.0)
					cells.append(Rect2(Vector2(x + (cell - lot.size.x) * 0.5, y + tallest - lot.size.y),
						lot.size).grow(0.3))
					x += cell + Booklet.PAD
				y += tallest + Booklet.QUANTITY + 1.0
			out.append([laid.number, entry.parts_rect, cells])
	return out


func _boxes(printed: Dictionary) -> void:
	print("")
	print("the parts boxes")
	if printed.is_empty():
		return
	var boxes: Array = _parts_boxes(printed["document"])
	var page: Color = (printed["document"] as Booklet.Document).sheet.colour
	for kind: String in ["PNG", "PDF"]:
		var wrong_frame: Array = []
		var wrong_fill: Array = []
		var square: Array = []
		var old: int = 0
		for box: Array in boxes:
			var image: Image = _png(printed, box[0]) if kind == "PNG" else _pdf_page(printed, box[0])
			var rect: Rect2 = box[1]
			var edge: float = 0.35 * 0.5
			for at: Vector2 in [Vector2(rect.get_center().x, rect.position.y + edge),
					Vector2(rect.get_center().x, rect.end.y - edge),
					Vector2(rect.position.x + edge, rect.get_center().y),
					Vector2(rect.end.x - edge, rect.get_center().y)]:
				if not _near(_at(image, at), FRAME, 30.0 / 255.0):
					wrong_frame.append("p%d #%s" % [box[0], _at(image, at).to_html(false)])
			var inside := Vector2(rect.get_center().x, rect.position.y + 1.1)
			if not _near(_at(image, inside), FILL, 8.0 / 255.0):
				wrong_fill.append("p%d #%s" % [box[0], _at(image, inside).to_html(false)])
			# Inside the old corners' 2.2 mm round (1.84 mm from its middle) and
			# outside the new 4 (4.38 mm from its): the page's own colour.
			var corner: Color = _at(image, rect.position + Vector2(0.9, 0.9))
			if not _near(corner, page, 12.0 / 255.0):
				square.append("p%d #%s" % [box[0], corner.to_html(false)])
			old += _count(image, rect.grow(0.6), OLD_FRAME, 10.0 / 255.0, box[2])
			old += _count(image, rect.grow(0.6), OLD_FILL, 10.0 / 255.0, box[2])
		_check("%s: every one of the %d parts boxes framed #%s (%s wrong)" % [kind, boxes.size(),
			FRAME.to_html(false), str(wrong_frame.slice(0, 3))], not boxes.is_empty() and wrong_frame.is_empty())
		_check("...filled #%s (%s wrong)" % [FILL.to_html(false), str(wrong_fill.slice(0, 3))],
			wrong_fill.is_empty())
		_check("...its corners %s mm round, the page's colour at the old corner (%s not)" % [CORNERS,
			str(square.slice(0, 3))], square.is_empty())
		_check("...with 0 px of the old frame's or fill's colour in them (%d)" % old, old == 0)


## The step pictures' pixels of [param colour], every other one each way.
func _outline_count(printed: Dictionary, colour: Color, near: float = 40.0 / 255.0) -> int:
	var document: Booklet.Document = printed["document"]
	var found: int = 0
	for laid: Booklet.Page in document.pages:
		if not laid.kind in ["steps", "callout"]:
			continue
		var image: Image = _png(printed, laid.number)
		for entry: Booklet.Entry in laid.entries:
			if entry.rect.size.x > 0.0:
				found += _count(image, entry.rect, colour, near, [], 2)
	return found


func _numbers_and_outline(printed: Dictionary) -> void:
	print("")
	print("the step numbers and the new parts' outline")
	if printed.is_empty():
		return
	var document: Booklet.Document = printed["document"]
	var wrong: Array = []
	var numbers: int = 0
	for laid: Booklet.Page in document.pages:
		if not laid.kind in ["steps", "callout"]:
			continue
		var image: Image = _png(printed, laid.number)
		for entry: Booklet.Entry in laid.entries:
			var rect: Rect2 = Booklet.number_rect(entry)
			var coloured: int = _count(image, rect, NUMBER, 40.0 / 255.0)
			var inked: int = _count(image, rect, OLD_INK, 12.0 / 255.0)
			numbers += 1
			if coloured < 20 or inked > 0:
				wrong.append("step %d: %d px #%s, %d of the old ink" % [entry.number, coloured,
					NUMBER.to_html(false), inked])
	_check("every one of the %d step numbers #%s, 0 px of the old ink (%s)" % [numbers,
		NUMBER.to_html(false), str(wrong.slice(0, 3)) if not wrong.is_empty() else "all"],
		numbers > 0 and wrong.is_empty())
	var orange: int = _outline_count(printed, OLD_OUTLINE, OLD_OUTLINE_NEAR)
	var outline: int = _outline_count(printed, OUTLINE)
	_check("the new parts outlined #%s in the step pictures (%d px), 0 px of the old orange (%d; the booklet's own had %d)"
		% [OUTLINE.to_html(false), outline, orange, _usual_orange], orange == 0 and outline > 200
		and _usual_orange > 200)


func _pdf_check(printed: Dictionary, words: String) -> void:
	if printed.is_empty():
		return
	var said: Array = []
	var into: String = ProjectSettings.globalize_path(_out.path_join(str(printed["stem"]) + "-check"))
	var code: int = OS.execute("python3", [ProjectSettings.globalize_path(
		"res://tools/booklet_pdf_check.py"), ProjectSettings.globalize_path(printed["path"]),
		ProjectSettings.globalize_path(printed["pdf"]), "--zip",
		ProjectSettings.globalize_path(printed["zip"]), "--out", into], said, true)
	for line: String in str("".join(said)).strip_edges().split("\n"):
		print("      " + line)
	_check("%s: tools/booklet_pdf_check.py passes" % words, code == 0)


# -- kept, and given to another model -------------------------------------------------


func _kept() -> void:
	print("")
	print("saved and opened again")
	var was: Dictionary = _sheet().said()
	var pictures: Dictionary = BookletLooks.images(_world).duplicate()
	var text: String = _store.to_text("gatehouse", true)
	var setup: String = ""
	var texts: Array = []
	for one: String in text.split("\n"):
		if one.begins_with("0 !BRICKWORKS PAGE_SETUP"):
			setup = one.strip_edges()
		elif one.begins_with("0 !BRICKWORKS PAGE_TEXT"):
			texts.append(one.strip_edges())
	_check("the file says the page: \"%s\"" % setup.left(160), setup.contains("BOX_FRAME #C0392B")
		and setup.contains("BOX_FILL #FFF4D6") and setup.contains("BOX_CORNERS 4")
		and setup.contains("NUMBER_COLOUR #1E7B34") and setup.contains("OUTLINE_COLOUR #7B2CBF")
		and setup.contains("COVER_PICTURE brickworks-page-cover"))
	_check("...and the words, a line each, as typed (%s)" % str(texts),
		texts.has("0 !BRICKWORKS PAGE_TEXT TITLE " + TITLE)
		and texts.has("0 !BRICKWORKS PAGE_TEXT SUBTITLE " + SUBTITLE)
		and texts.has("0 !BRICKWORKS PAGE_TEXT COVER_LINE " + LINE)
		and texts.has("0 !BRICKWORKS PAGE_TEXT HEADER " + HEADER)
		and texts.has("0 !BRICKWORKS PAGE_TEXT FOOTER " + FOOTER))
	var path: String = _out.path_join("gatehouse_saved.mpd")
	_write(path, text)
	await _open(path, 14)
	var now: Dictionary = _sheet().said()
	_check("opened again, the page as it was set up (%s)" % str(now).left(200),
		str(now) == str(was) and now.size() >= 11)
	var cover: String = str(now.get("cover_picture", ""))
	_check("...the cover's picture with it, the same bytes", not cover.is_empty()
		and str(BookletLooks.images(_world).get(cover, "")) == str(pictures.get(cover, "-")))
	_check("...and saved again, the same text", _store.to_text("gatehouse", true) == text)
	print("    page_setup footer=: %s" % str(await _tools.run("page_setup", {"footer": "Another foot"})))
	_check("page_setup footer=: the footer changed", _field("footer") == "Another foot")
	_builder.undo()
	await _frames(2)
	_check("...one undo puts it back (%s)" % str(_field("footer")), _field("footer") == FOOTER)


func _style_to_other() -> void:
	print("")
	print("kept as a style, and given to booklet3's model in 2 actions")
	var kept: Dictionary = _sheet().said()
	var pictures: Dictionary = BookletLooks.images(_world).duplicate()
	var dialog: Window = await _page_dialog()
	if not _check("Page setup… opens", dialog != null and dialog.visible):
		return
	(dialog.get("_name") as LineEdit).text = STYLE
	(dialog.get("_keep") as Button).pressed.emit()
	await _frames(2)
	var style: Dictionary = BookletSheet.style(STYLE)
	_check("Keep as a style: \"%s\" kept with every field and the cover's picture (%d fields, %s)" % [
		STYLE, style.size(), "its picture" if style.has("cover_picture_data") else "no picture"],
		BookletSheet.styles().has(STYLE) and style.has("cover_picture_data") and style.has("footer"))
	dialog.hide()
	var path: String = _out.path_join("booklet3.mpd")
	_write(path, B3.MODEL)
	await _open(path, 18)
	_check("booklet3's model opens on the booklet's own page (%s)" % str(_sheet().said()),
		_sheet().said().is_empty())
	var actions: int = 0
	if _shell.run("booklet_page_setup"):
		actions += 1
	await _frames(6)
	var list: OptionButton = dialog.get("_style")
	for at: int in list.item_count:
		if list.get_item_text(at) == STYLE:
			list.select(at)
			list.item_selected.emit(at)
			actions += 1
	await _frames(2)
	dialog.hide()
	var now: Dictionary = _sheet().said()
	var cover: String = str(now.get("cover_picture", ""))
	_check("in %d actions (Page setup…, the style): every field the gatehouse's (%s)" % [actions,
		str(now).left(200)], actions == 2 and str(now) == str(kept))
	_check("...and its cover's picture, byte for byte",
		not cover.is_empty() and str(BookletLooks.images(_world).get(cover, "")) == str(pictures.get(cover, "-")))
	var printed: Dictionary = await _printed("other")
	if printed.is_empty():
		return
	var first: String = _pdf_words(printed, 1)
	var without: Array = []
	for number: int in range(1, int(printed["pages"]) + 1):
		if not _pdf_words(printed, number).contains(FOOTER):
			without.append(number)
	_check("...its booklet's cover says its title and line, and the footer is on all %d pages (%s without)"
		% [int(printed["pages"]), str(without)], first.contains(TITLE) and first.contains(LINE)
		and without.is_empty())
	_numbers_and_outline(printed)
	_pdf_check(printed, "booklet3's booklet")
