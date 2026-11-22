## The new parts' outline as wide as its designer sets it, 1 to 72 px
## (APP_UX11 pagetools, StudWorx's Highlight Width), printed as shown and in
## the PDF too, one undo, kept in the model's file.
##
##   godot --path . --resolution 1280x720 --script src/dev/outline_width_probe.gd -- [--into=DIR]
##
## Windowed, on the GPU: the band is drawn.
##
## - The page's outline_width read and written as its file's PAGE_SETUP
##   says it (OUTLINE_WIDTH 12), kept in range (1 to 72), a wrong one said,
##   the booklet's own 3 never written.
## - Page setup…'s Steps tab: an Outline width row, the dialog inside a
##   1280 x 720 window with every control in sight; a width typed there one
##   undo, and page_setup outline_width= over MCP the same.
## - Saved and opened again the same text; the autosave's text opened again
##   the same page; a width changed after a reopen changes that one line.
## - Drawn by BookletStudio as a booklet draws a step: a lone 1 x 1 plate,
##   new, at widths 1, 3, 12 and 72, measured on 360 rays out from its
##   middle: the band on every ray (no gaps) and as thick as its width in
##   the picture's pixels (5 a millimetre); the booklet's own 3 drawn by its
##   own rings, and the exact band at 3 within a quarter of it.
## - A booklet of the gatehouse at 12: its step pictures' orange more than
##   twice the booklet's own, and its PDF's first steps page, drawn by
##   poppler at 5 px a millimetre, the same.
extends SceneTree

const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"
const WIDTHS: Array[int] = [1, 3, 12, 72]

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _library: PartLibrary
var _tools: AppTools
var _out: String = ""


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
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--into="):
			_out = arg.trim_prefix("--into=")
	if _out.is_empty():
		_out = OS.get_user_data_dir().path_join("outline_width_probe")
	DirAccess.make_dir_recursive_absolute(_out)
	BookletMaker.open_when_written = false
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
	_sheet_words()
	await _open(ProjectSettings.globalize_path(GATEHOUSE), 14)
	await _dialog()
	await _mcp()
	await _kept()
	await _drawn()
	await _booklet()
	_quit()


func _quit() -> void:
	print("")
	print("outline_width: %s" % ("every check passed" if _failures == 0
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


func _width() -> int:
	return BookletSheet.of(_world).outline_width


func _history() -> int:
	return _builder._history.size()


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# -- the page's words ------------------------------------------------------------


func _sheet_words() -> void:
	print("")
	print("the page's outline width, as its file says it")
	var twelve: BookletSheet = BookletSheet.from({"outline_width": 12})
	_check("12: said %s, its line \"%s\"" % [str(twelve.said()), twelve.line_words()],
		twelve.said() == {"outline_width": 12} and twelve.line_words() == "OUTLINE_WIDTH 12")
	var read: Dictionary = BookletSheet.read_words(PackedStringArray(["A4", "OUTLINE_COLOUR",
		"#7B2CBF", "OUTLINE_WIDTH", "12"]))
	_check("read back from \"A4 OUTLINE_COLOUR #7B2CBF OUTLINE_WIDTH 12\": %s" % str(read),
		int(read.get("outline_width", 0)) == 12 and str(read.get("outline_colour", "")) == "#7b2cbf"
		and not read.has("unread"))
	var own: BookletSheet = BookletSheet.from({"outline_width": 3})
	_check("the booklet's own 3: nothing said, nothing written (%s, \"%s\")" % [str(own.said()),
		own.line_words()], own.said().is_empty() and own.line_words().is_empty())
	var low: BookletSheet = BookletSheet.from({"outline_width": 0})
	var high: BookletSheet = BookletSheet.from({"outline_width": 500})
	var wrong := BookletSheet.new()
	var said: String = wrong.change({"outline_width": "wide"})
	_check("kept in range: 0 is %d, 500 is %d; \"wide\" said (%s) and the width kept at %d"
		% [low.outline_width, high.outline_width, said, wrong.outline_width],
		low.outline_width == 1 and high.outline_width == 72 and said.contains("1 to 72")
		and wrong.outline_width == 3)
	_check("said in words: %s" % twelve.words().right(60), twelve.words().contains("12 px wide"))


# -- Page setup… and MCP ----------------------------------------------------------


func _dialog() -> void:
	print("")
	print("Page setup…'s Outline width in a %s window" % str(root.size))
	if not _shell.run("booklet_page_setup"):
		_check("Page setup… opens", false)
		return
	await _frames(6)
	var dialog: Window = _shell.get("_page_setup_dialog")
	if not _check("Page setup… opens", dialog != null and dialog.visible):
		return
	var tabs: TabContainer = dialog.get("_tabs")
	tabs.current_tab = 2
	await _frames(4)
	var spin: Variant = dialog.get("_outline_width")
	if not _check("its Steps tab has an Outline width, 1 to 72 px, showing %s" % (str((spin as SpinBox).value)
			if spin is SpinBox else "none"), spin is SpinBox and (spin as SpinBox).is_visible_in_tree()
			and (spin as SpinBox).min_value == 1 and (spin as SpinBox).max_value == 72
			and int((spin as SpinBox).value) == 3):
		dialog.hide()
		return
	var window := Rect2i(Vector2i.ZERO, root.size)
	var box := Rect2i(dialog.position, dialog.size)
	var out: Array = []
	for node: Node in dialog.find_children("*", "Control", true, false):
		var control: Control = node
		if not control.is_visible_in_tree() or control is Container or control.size.x <= 0.0:
			continue
		if not Rect2(Vector2.ZERO, Vector2(dialog.size)).grow(0.5).encloses(Rect2(control.get_global_rect())):
			out.append("%s %s" % [control.get_class(), str(control.get_global_rect())])
	_check("...the dialog %s inside the window, every control of the Steps tab inside it (%s)"
		% [str(box), str(out.slice(0, 3)) if not out.is_empty() else "all"],
		window.encloses(box) and out.is_empty())
	var history: int = _history()
	(spin as SpinBox).value = 24
	await _frames(3)
	await _shot("page_setup_outline_width")
	_check("24 typed: the page's width %d, one undo (%d)" % [_width(), _history() - history],
		_width() == 24 and _history() == history + 1)
	dialog.hide()
	_builder.undo()
	await _frames(2)
	_check("...undone: %d again" % _width(), _width() == 3)


func _mcp() -> void:
	print("")
	print("page_setup outline_width= over MCP")
	var history: int = _history()
	var said: String = str(await _tools.run("page_setup", {"outline_width": 12}))
	print("    page_setup outline_width=12: %s" % said)
	_check("12: the page's width %d, one undo (%d), said" % [_width(), _history() - history],
		_width() == 12 and _history() == history + 1 and said.contains("12 px wide"))
	var told: String = str(await _tools.run("page_setup", {"outline_width": 0}))
	_check("0 kept in range: %d (%s)" % [_width(), told.left(80)], _width() == 1)
	_builder.undo()
	await _frames(2)
	_check("...undone: 12 again (%d)" % _width(), _width() == 12)


# -- kept --------------------------------------------------------------------------


func _setup_line(text: String) -> String:
	for one: String in text.split("\n"):
		if one.begins_with("0 !BRICKWORKS PAGE_SETUP"):
			return one.strip_edges()
	return ""


func _kept() -> void:
	print("")
	print("saved and opened again")
	var text: String = _store.to_text("gatehouse", true)
	var line: String = _setup_line(text)
	_check("the file says the width: \"%s\"" % line, line == "0 !BRICKWORKS PAGE_SETUP OUTLINE_WIDTH 12")
	var path: String = _out.path_join("ow_saved.mpd")
	_write(path, text)
	var autosaved: String = _store.to_text("gatehouse", false)
	await _open(path, 14)
	_check("opened again: 12 (%d)" % _width(), _width() == 12)
	var again: String = _store.to_text("gatehouse", true)
	_check("...and saved again, the same text, byte for byte (%d bytes)" % again.length(),
		again == text)
	var auto_path: String = _out.path_join("ow_autosave.ldr")
	_write(auto_path, autosaved)
	_check("the autosave's text says it too", _setup_line(autosaved) == line)
	await _open(auto_path, 14)
	_check("...the autosave opened again: 12 (%d), saved as the save was" % _width(),
		_width() == 12 and _setup_line(_store.to_text("gatehouse", true)) == line)
	await _open(path, 14)
	await _tools.run("page_setup", {"outline_width": 30})
	var changed: String = _store.to_text("gatehouse", true)
	var was: PackedStringArray = text.split("\n")
	var now: PackedStringArray = changed.split("\n")
	var differ: Array = []
	for index: int in mini(was.size(), now.size()):
		if was[index] != now[index]:
			differ.append(now[index])
	_check("30 after the reopen: that one line changed, nothing else (%s)" % str(differ),
		was.size() == now.size() and differ == ["0 !BRICKWORKS PAGE_SETUP OUTLINE_WIDTH 30"])


# -- drawn ---------------------------------------------------------------------------


## A lone 1 x 1 plate, new, beside a brick, drawn as a booklet draws a step
## at [param width] (0: the booklet's own path): the picture.
func _plate_at(studio: BookletStudio, made: BookletStudio.Stage, view: BookletStudio.View,
		size: Vector2i, width: float) -> Image:
	studio.new_width = width
	var shot: BookletStudio.Shot = await studio.shoot(made, 2, 2, view, size)
	await studio.finished(shot)
	return shot.image


## The band's orange, or a pixel of it blended at its edges with the ink
## line or the page as the picture is cut down to its size: orange's hue,
## red over green over blue by a margin the red plate, the blue brick, the
## ink and the page are not.
static func _orange(image: Image, x: int, y: int) -> bool:
	var c: Color = image.get_pixel(x, y)
	return c.a > 0.3 and c.r - c.g > 0.15 and c.g - c.b > 0.1 and c.r > 0.4


static func _count(image: Image) -> int:
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if _orange(image, x, y):
				count += 1
	return count


## On 360 rays out from [param middle]: how many met the band, a pixel of
## it beside the ray (of the four it passes between: a band a pixel wide on
## a slant is a staircase of corners, which a ray read at the nearest pixel
## slips through), and the band's thickness on each ray, first to last
## orange pixel at the nearest, sorted: {met, thick}.
static func _rays(image: Image, middle: Vector2) -> Dictionary:
	var thick: Array = []
	var met: int = 0
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	for degree: int in 360:
		var way := Vector2.from_angle(deg_to_rad(degree))
		var first: float = -1.0
		var last: float = -1.0
		var beside: bool = false
		var r: float = 0.0
		while true:
			var point: Vector2 = middle + way * r
			var at: Vector2i = Vector2i(point.round())
			if not bounds.has_point(at):
				break
			if _orange(image, at.x, at.y):
				if first < 0.0:
					first = r
				last = r
			var corner: Vector2i = Vector2i(point.floor())
			for near: Vector2i in [corner, corner + Vector2i(1, 0), corner + Vector2i(0, 1),
					corner + Vector2i(1, 1)]:
				if not beside and bounds.has_point(near) and _orange(image, near.x, near.y):
					beside = true
			r += 0.25
		if beside:
			met += 1
		if first >= 0.0:
			thick.append(last - first + 1.0)
	thick.sort()
	return {"met": met, "thick": thick}


func _drawn() -> void:
	print("")
	print("drawn: a lone 1 x 1 plate, new, at each width")
	var studio := BookletStudio.new()
	studio.library = _library
	studio.mark_new = true
	root.add_child(studio)
	await _frames(2)
	# The plate well clear of the brick, so its band is its own all round.
	var made: BookletStudio.Stage = studio.stage([[1, "3001", 1, Transform3D.IDENTITY],
		[2, "3024", 4, Transform3D(Basis.IDENTITY, Vector3(320.0, 0.0, 0.0))]])
	var plate: Rect2 = BookletStudio.extent([made.boxes[1]], BookletStudio.FRONT)
	# 30 px across the plate in a picture 400 square: room for 72 px all round.
	var size := Vector2i(400, 400)
	var scale: float = 30.0 / maxf(plate.size.x, 1.0)
	var view := BookletStudio.View.new(BookletStudio.FRONT, plate.get_center(), scale)
	var middle: Vector2 = view.project(made.boxes[1].get_center(), Vector2(size))
	var counts: Dictionary = {}
	var own: Image = await _plate_at(studio, made, view, size, 0.0)
	if own != null:
		own.save_png(_out.path_join("plate_own.png"))
		counts["own"] = _count(own)
	for width: int in WIDTHS:
		# As BookletMaker gives it: the designer's pixels at 5 a millimetre,
		# here drawn at 5 a millimetre.
		var image: Image = await _plate_at(studio, made, view, size, float(width))
		if not _check("width %d: drawn" % width, image != null):
			continue
		image.save_png(_out.path_join("plate_%d.png" % width))
		counts[width] = _count(image)
		var found: Dictionary = _rays(image, middle)
		var rays: Array = found["thick"]
		var median: float = float(rays[rays.size() / 2]) if not rays.is_empty() else 0.0
		# Drawn at twice the size and cut down, the band's two edges are each
		# half a pixel of orange blended with the ink or the page, which a
		# count of first to last pixel takes in: its width and one.
		var within: float = maxf(1.0, float(width) * 0.08)
		_check("width %d: the band met by %d of 360 rays, %.1f px thick at the median (%s to %s; its width and the pixel its blended edges make), %d px of orange"
			% [width, found["met"], median, str(rays[0]) if not rays.is_empty() else "-",
				str(rays[-1]) if not rays.is_empty() else "-", counts[width]],
			int(found["met"]) == 360 and absf(median - float(width + 1)) <= within)
	_check("the band grows with its width: %s" % str(counts),
		counts.get(1, 0) < counts.get(3, 0) and counts.get(3, 0) < counts.get(12, 0)
		and counts.get(12, 0) < counts.get(72, 0))
	var exact: int = int(counts.get(3, 0))
	var rings: int = int(counts.get("own", 0))
	_check("the booklet's own band (%d px, its own rings) and the exact one at 3 (%d px) within a quarter"
		% [rings, exact], rings > 0 and absf(float(exact - rings)) <= rings * 0.25)
	studio.forget(made)
	studio.queue_free()
	await _frames(2)


# -- a booklet and its PDF --------------------------------------------------------------


## The gatehouse's booklet at [param width]: {orange (its step pictures'),
## pdf_orange (its first steps page in the PDF at 5 px a mm), pdf_page}.
func _printed(width: int) -> Dictionary:
	await _tools.run("page_setup", {"outline_width": width})
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var html: String = await maker.make(_world, _store.scenery, "gatehouse")
	var document: Booklet.Document = maker.document
	maker.queue_free()
	if not _check("width %d: the booklet was made (%d pages)" % [width, document.pages.size()
			if document != null else 0], not html.is_empty() and document != null):
		return {}
	var orange: int = 0
	var first_steps: int = -1
	for page: Booklet.Page in document.pages:
		if page.kind != "steps":
			continue
		if first_steps < 0:
			first_steps = page.number
		for entry: Booklet.Entry in page.entries:
			var uri: String = entry.image
			var image := Image.new()
			var bytes: PackedByteArray = Marshalls.base64_to_raw(uri.get_slice(",", 1))
			var read: int = image.load_jpg_from_buffer(bytes) if uri.begins_with("data:image/jpeg") \
				else (image.load_webp_from_buffer(bytes) if uri.begins_with("data:image/webp")
				else image.load_png_from_buffer(bytes))
			if read == OK:
				image.convert(Image.FORMAT_RGBA8)
				orange += _count(image)
	var path: String = _out.path_join("ow_%d.html" % width)
	_write(path, html)
	var pdf: String = _out.path_join("ow_%d.pdf" % width)
	var read_back := BookletRead.new()
	var writer := BookletPdf.new()
	writer.begin(pdf, read_back)
	await read_back.read_all(path, writer.page)
	writer.finish(read_back.title)
	var stem: String = ProjectSettings.globalize_path(_out.path_join("ow_%d_pdf" % width))
	OS.execute("pdftoppm", ["-r", "127", "-f", str(first_steps), "-l", str(first_steps), "-png",
		"-singlefile", ProjectSettings.globalize_path(pdf), stem])
	var page_image: Image = Image.load_from_file(stem + ".png")
	if page_image != null:
		page_image.convert(Image.FORMAT_RGBA8)
	return {"orange": orange, "pdf_orange": _count(page_image) if page_image != null else -1,
		"pdf_page": stem + ".png"}


func _booklet() -> void:
	print("")
	print("the gatehouse's booklet at 3 and at 12, and its PDF")
	var own: Dictionary = await _printed(3)
	var wide: Dictionary = await _printed(12)
	if own.is_empty() or wide.is_empty():
		return
	_check("the step pictures at 12: %d px of orange, the booklet's own %d" % [wide["orange"],
		own["orange"]], int(own["orange"]) > 100 and int(wide["orange"]) > int(own["orange"]) * 2)
	_check("its PDF's first steps page at 5 px a mm: %d px of orange at 12, %d at 3 (%s)"
		% [wide["pdf_orange"], own["pdf_orange"], wide["pdf_page"]],
		int(own["pdf_orange"]) > 20 and int(wide["pdf_orange"]) > int(own["pdf_orange"]) * 2)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join("%s_%dx%d.png" % [name, root.size.x, root.size.y])
	if image != null:
		image.save_png(path)
		print("    picture: %s" % ProjectSettings.globalize_path(path))
