## Does Save as PDF in the booklet save the booklet, page for page?
##
##   godot --path . --resolution 1280x800 --script src/dev/booklet_pdf_probe.gd -- [--model=FILE] [--into=DIR] [--html=FILE]
##
## Needs a window: the booklet's pictures are drawn, and so are its pages
## as PNGs. FILE is res://models/castle.ldr unless named; DIR is where
## the booklet, its PDF and its pages' zip are left to be looked at (the
## probe's own folder unless named). --html=FILE saves a booklet already
## made, from its file, without drawing one (BookletPdf and BookletPng on
## their own).
##
## The booklet became a PDF only by printing its page from a browser. So
## this presses Instructions as a person does and answers where to save
## it, and once the booklet is whole in the browser (a reader of its own
## standing in, as booklet_stream_probe's), presses the booklet's Save as
## PDF and Save pages as PNG, as the browser does (POST /save?pdf to the
## app that serves it), and answers where each goes:
##
##   does each ask where to save it, write it there, and say so in the
##   booklet and in the status bar?
##   is the PDF the booklet, read by a reader that is not ours (poppler,
##   and pypdf where it is installed: tools/booklet_pdf_check.py)? Its
##   page count, each page's size, each page's step pictures the
##   booklet's own JPEGs byte for byte, its title and parts list words
##   a reader finds.
##   does the PDF carry its type (pdffonts: every font embedded)?
##   is the zip a PNG a page, the first and the last the booklet's own
##   pages (the checker draws those from the PDF and compares), each 300
##   dots an inch in its pixels and in its pHYs? On the web (where the
##   zip is handed over from memory), 300 up to 134 pages, finer than the
##   web's own pictures beyond?
##   how long did each take, and how big is each?
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _bar: ModelBar
var _url: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	var model: String = "res://models/castle.ldr"
	var out: String = OS.get_user_data_dir().path_join("booklet_pdf_probe")
	var html: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			model = arg.trim_prefix("--model=")
		elif arg.begins_with("--into="):
			out = arg.trim_prefix("--into=")
		elif arg.begins_with("--html="):
			html = arg.trim_prefix("--html=")
	DirAccess.make_dir_recursive_absolute(out)
	if not html.is_empty():
		await _from_file(html, out)
		_quit()
		return
	SaveTo.native = false
	SaveTo.open_with = func(uri: String) -> Error:
		if uri.begins_with("http://"):
			_url = uri
		return OK
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_shell = _main.get("_shell")
		_bar = _main.get("_bar")
		if _shell != null and _bar != null:
			break
	await _frames(30)
	_main.call("_open", model)
	_main.call("_lay_baseplate")
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(60)
	var world: BrickWorld = _main.get("_world")
	print("  %s: %d parts" % [model.get_file(), world.brick_count()])

	var path: String = out.path_join(model.get_file().get_basename() + "_instructions.html")
	_check("Instructions can be pressed", _shell.run("instructions"))
	if not _check("Instructions asks where to save the booklet", await _answer(path)):
		_quit()
		return
	var started: int = Time.get_ticks_msec()
	var said: String = ""
	var until: int = Time.get_ticks_msec() + 1500000
	while Time.get_ticks_msec() < until:
		await process_frame
		said = _bar.status_text()
		if said.begins_with("the booklet is open") or said.begins_with("no browser") \
				or said.begins_with("could not") or said.begins_with("stopped") \
				or said.begins_with("nothing"):
			break
	var drawn: float = (Time.get_ticks_msec() - started) / 1000.0
	print("  the booklet drawn in %.1f s: %s" % [drawn, said])
	if not _check("the booklet is open in the browser, served by the app (%s)" % _url,
			said.begins_with("the booklet is open") and _url.begins_with("http://127.0.0.1:")):
		_quit()
		return
	var head: String = FileAccess.get_file_as_string(path).substr(0, 20000)
	_check("the booklet's bar has Print, Save as PDF and Save pages as PNG",
		head.contains(">Print</button>") and head.contains(">Save as PDF</button>")
		and head.contains(">Save pages as PNG</button>"))

	var pdf: String = out.path_join(model.get_file().get_basename() + "_instructions.pdf")
	var zip: String = out.path_join(model.get_file().get_basename() + "_instructions_pages.zip")
	var timed: Dictionary = {}
	for kind: String in ["pdf", "png"]:
		var to: String = pdf if kind == "pdf" else zip
		DirAccess.remove_absolute(to)
		var reply: Array = [null]
		var asked: StreamPeerTCP = _press(kind)
		var answered := func() -> void:
			reply[0] = _reply_of(asked)
		if not _check("Save %s asks where to save it" % kind.to_upper(), await _answer(to, answered)):
			continue
		var pressed: int = Time.get_ticks_msec()
		until = Time.get_ticks_msec() + 600000
		while reply[0] == null and Time.get_ticks_msec() < until:
			await process_frame
			reply[0] = _reply_of(asked)
		timed[kind] = (Time.get_ticks_msec() - pressed) / 1000.0
		var line: String = str(reply[0])
		print("  %s: %s" % [kind, line])
		_check("the booklet is told where the %s went (%s)" % [kind, line],
			line.begins_with("wrote ") and line.ends_with(to))
		_check("...and so is the status bar", _bar.status_text() == line)
		_check("...and the file is there, with no .part beside it",
			FileAccess.file_exists(to) and not FileAccess.file_exists(to + ".part"))
	print("  saved: the PDF in %.1f s, %.1f MB; the pages in %.1f s, %.1f MB (the booklet %.1f MB)"
		% [float(timed.get("pdf", -1.0)), _mb(pdf), float(timed.get("png", -1.0)), _mb(zip), _mb(path)])
	_checked(path, pdf, zip, out)
	_quit()


## Save [param html]'s PDF and pages straight from its file.
func _from_file(html: String, out: String) -> void:
	var stem: String = html.get_file().get_basename()
	var pdf: String = out.path_join(stem + ".pdf")
	var zip: String = out.path_join(stem + "_pages.zip")
	var started: int = Time.get_ticks_msec()
	var read := BookletRead.new()
	var writer := BookletPdf.new()
	_check("the PDF can be begun", writer.begin(pdf, read))
	var pages: int = await read.read_all(html, writer.page)
	writer.finish(read.title)
	var pdf_s: float = (Time.get_ticks_msec() - started) / 1000.0
	_check("the PDF was written (%d pages)" % pages, writer.ok() and pages > 0)
	started = Time.get_ticks_msec()
	var drawer := BookletPng.new()
	root.add_child(drawer)
	var drawn: int = await drawer.write(html, zip, stem)
	var png_s: float = (Time.get_ticks_msec() - started) / 1000.0
	_check("the pages were drawn (%d)" % drawn, drawn == pages and drawer.pages == pages)
	print("  %s: %d pages; the PDF in %.1f s, %.1f MB; the pages in %.1f s, %.1f MB (the booklet %.1f MB), %.2f px a mm"
		% [html.get_file(), pages, pdf_s, _mb(pdf), png_s, _mb(zip), _mb(html), drawer.px_per_mm])
	drawer.queue_free()
	_checked(html, pdf, zip, out)


## The checker, a reader of PDFs that is not this one, on what was saved.
func _checked(html: String, pdf: String, zip: String, out: String) -> void:
	# On the web the zip is handed over from memory: 300 dots an inch up to
	# 134 pages, finer than the web's own pictures (3.6 px a mm) beyond.
	var dpi: Array = [14, 134, 324, 1405].map(func(pages: int) -> int:
		return roundi(BookletPng.web_density(pages) * 25.4))
	_check("on the web, pages at %s dots an inch for 14, 134, 324 and 1,405 pages" % str(dpi),
		dpi[0] == 300 and dpi[1] == 300 and dpi[2] < 300 and dpi[3] >= 3.6 * 25.4)
	var said: Array = []
	var code: int = OS.execute("python3", [ProjectSettings.globalize_path(
		"res://tools/booklet_pdf_check.py"), html, pdf, "--zip", zip, "--out", out], said, true)
	for line: String in str("".join(said)).strip_edges().split("\n"):
		print("  " + line)
	_check("tools/booklet_pdf_check.py passes", code == 0)


## The booklet's Save button pressed, as its page asks the app (Booklet
## .SAVE_SCRIPT): POST /save?KIND.
func _press(kind: String) -> StreamPeerTCP:
	var rest: String = _url.trim_prefix("http://")
	var host: String = rest.get_slice("/", 0)
	var peer := StreamPeerTCP.new()
	peer.connect_to_host(host.get_slice(":", 0), host.get_slice(":", 1).to_int())
	peer.set_meta("request", ("POST /save?%s HTTP/1.1\r\nHost: %s\r\nContent-Length: 0\r\n\r\n"
		% [kind, host]).to_utf8_buffer())
	peer.set_meta("read", PackedByteArray())
	return peer


## The app's answer to [param peer], once it has all come; null until then.
func _reply_of(peer: StreamPeerTCP) -> Variant:
	peer.poll()
	var status: StreamPeerTCP.Status = peer.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED and peer.has_meta("request"):
		peer.put_data(peer.get_meta("request"))
		peer.remove_meta("request")
	var read: PackedByteArray = peer.get_meta("read")
	if status == StreamPeerTCP.STATUS_CONNECTED and peer.get_available_bytes() > 0:
		read.append_array(peer.get_partial_data(peer.get_available_bytes())[1])
		peer.set_meta("read", read)
	if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
		var text: String = read.get_string_from_utf8()
		return text.get_slice("\r\n\r\n", 1) if text.contains("\r\n\r\n") else ""
	return null


## Answer the Save dialog with [param path], once it is up, polling
## [param meanwhile] each frame. Whether it came up.
func _answer(path: String, meanwhile: Callable = Callable()) -> bool:
	var dialog: FileDialog = null
	var until: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < until and dialog == null:
		await process_frame
		if meanwhile.is_valid():
			meanwhile.call()
		if SaveTo.showing != null and SaveTo.showing.visible:
			dialog = SaveTo.showing
	if dialog == null:
		return false
	dialog.current_dir = path.get_base_dir()
	dialog.current_file = path.get_file()
	await _frames(2)
	dialog.get_ok_button().pressed.emit()
	return true


static func _mb(path: String) -> float:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return file.get_length() / 1048576.0 if file != null else -1.0


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


## Every way out: the system's own opener put back first, as a lambda of
## this script's left in SaveTo's static breaks the heap at exit.
func _quit() -> void:
	SaveTo.open_with = Callable(Outside, "open_link")
	print("booklet_pdf_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
