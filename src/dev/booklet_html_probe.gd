## The booklet saved as web pages (Instructions, Save as web page;
## BookletHtml): one long page or a page a step, light or dark.
##
##   godot --path . --resolution 1280x720 --script src/dev/booklet_html_probe.gd -- [--into=DIR]
##   godot --headless --path . --script src/dev/booklet_html_probe.gd -- --by-hand
##
## By hand (headless, --by-hand, and first in a window): a booklet made by hand, written by Booklet as Instructions
## writes one (a cover, a part of the model starting, a step of two parts
## with where one is kept, a named step, a callout on pages of its own built
## twice, a step with a callout in its box, a step that could not be drawn,
## a picture of the designer's, the finished model and the parts pages),
## read back and saved four ways. Checked as a reader meets them:
## - the long page has every step once, in order, each with its picture
##   and its parts' counts, the part of the model where it starts, the
##   callout's own steps under its name, and the callout's pictures in the
##   step it goes on; the designer's picture is no step's;
## - the zip has its contents and a page for each step, and every
##   Previous, Contents and Next on them goes to a file in the zip;
## - dark is dark round the cards, light is light, the cards the booklet's
##   page colour in both;
## - no script, and a policy that loads nothing from outside; a title of
##   < & " written escaped, and a picture that is not data left out.
## Then, in a window: the gatehouse's booklet made by Instructions and saved
## by Main.save_booklet_as("html-long-dark") and ("html-steps-light"), as
## the booklet's Save as web page asks for it: every step of the booklet in
## each, each with its picture. The files are left in DIR (default
## user://booklet_html_probe) to be looked at.
extends SceneTree

const TITLE := "Gate <House> & \"Hill\""
const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"

var _failures: int = 0
var _out: String = ""
var _png: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	var real: bool = DisplayServer.get_name() != "headless"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--into="):
			_out = arg.trim_prefix("--into=")
		elif arg == "--by-hand":
			real = false
	if _out.is_empty():
		_out = OS.get_user_data_dir().path_join("booklet_html_probe")
	DirAccess.make_dir_recursive_absolute(_out)
	var image := Image.create(12, 8, false, Image.FORMAT_RGB8)
	image.fill(Color(0.8, 0.2, 0.1))
	_png = "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())
	_by_hand()
	if real:
		await _real()
	print("")
	print("booklet_html: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


static func _writer() -> RefCounted:
	return load("res://src/render/booklet_html.gd").new()


## A picture as a step's, told apart from the others by its pixel's red.
func _picture(red: int) -> String:
	var image := Image.create(12, 8, false, Image.FORMAT_RGB8)
	image.fill(Color8(red, 40, 40))
	return "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())


func _lot(key: String, name: String, count: int, place: String = "") -> Booklet.Lot:
	var lot := Booklet.Lot.new()
	lot.key = key
	lot.part_id = key.get_slice(":", 0)
	lot.name = name
	lot.colour = "Red"
	lot.count = count
	lot.place = place
	lot.size = Vector2(10, 8)
	return lot


func _entry(number: int, image: String, lots: Array, at: Vector2) -> Booklet.Entry:
	var entry := Booklet.Entry.new()
	entry.number = number
	entry.rect = Rect2(at, Vector2(110, 80))
	entry.image = image
	for lot: Booklet.Lot in lots:
		entry.lots.append(lot)
	if not lots.is_empty():
		entry.parts_rect = Rect2(at + Vector2(0, 0), Vector2(60, 20))
		entry.parts_width = 60.0
	entry.number_at = at + Vector2(0, 24)
	return entry


## The booklet by hand, written by Booklet, read back and saved four ways.
func _by_hand() -> void:
	print("\n  a booklet by hand, saved as web pages")
	var document := Booklet.Document.new()
	document.title = TITLE
	document.pieces = 12
	document.steps = 4
	document.credits = "Part geometry from the LDraw™ Parts Library, © the LDraw community. LEGO® is a trademark of the LEGO Group."
	var brick := _lot("3001:4", "Brick 2 x 4", 2)
	var plate := _lot("3022:1", "Plate 2 x 2 & <wide>", 1, "drawer 3")
	document.lots.append(brick)
	document.lots.append(plate)
	document.parts[brick.key] = _picture(10)
	document.parts[plate.key] = _picture(20)
	document.images["mine.png"] = _picture(250)
	var cover := Booklet.Page.new()
	cover.kind = "cover"
	cover.number = 1
	cover.pictures = [[_picture(200), Rect2(20, 40, 200, 120)]]
	var first := Booklet.Page.new()
	first.number = 2
	first.banner = "Part 1 · the base"
	first.entries.append(_entry(1, _picture(101), [brick, plate], Vector2(10, 20)))
	var named := _entry(2, _picture(102), [brick], Vector2(140, 20))
	named.name = "Build the wall"
	first.entries.append(named)
	# A callout on pages of its own, built twice: its first page opens with
	# the finished assembly.
	var tower := Booklet.Callout.new()
	tower.name = "tower"
	tower.times = 2
	tower.preview_box = Rect2(200, 20, 50, 50)
	tower.preview_cell = Rect2(202, 22, 46, 46)
	tower.preview_image = _picture(150)
	var own := Booklet.Page.new()
	own.kind = "callout"
	own.number = 3
	own.times = 2
	own.frame = Rect2(5, 5, 259, 180)
	own.preview = tower
	own.entries.append(_entry(1, _picture(151), [plate], Vector2(10, 20)))
	own.entries.append(_entry(2, _picture(152), [], Vector2(140, 20)))
	var second := Booklet.Page.new()
	second.number = 4
	var boxed := _entry(3, _picture(103), [brick], Vector2(10, 20))
	var inline := Booklet.Callout.new()
	inline.name = "door"
	inline.times = 2
	inline.box = Rect2(60, 60, 60, 40)
	inline.cells.append(Rect2(62, 62, 26, 36))
	inline.cells.append(Rect2(92, 62, 26, 36))
	inline.images = PackedStringArray([_picture(160), _picture(161)])
	inline.steps.append(Booklet.Entry.new())
	inline.steps.append(Booklet.Entry.new())
	boxed.callout = inline
	# A 1:1 guide, whose ring says a length in a step number's type.
	boxed.actual = [{"size": Vector2(20, 4), "studs": 8, "name": "Axle 8", "image": _picture(170)}]
	second.entries.append(boxed)
	# A step that could not be drawn, and a picture of the designer's over it.
	var undrawn := _entry(4, "", [plate], Vector2(140, 20))
	undrawn.notes = [{"image": "mine.png", "at": [150, 120, 30, 20]}]
	second.entries.append(undrawn)
	var finished := Booklet.Page.new()
	finished.kind = "finished"
	finished.number = 5
	finished.pictures = [[_picture(210), Rect2(20, 20, 200, 150)]]
	for page: Booklet.Page in [cover, first, own, second, finished]:
		document.pages.append(page)
	document.pages.append_array(Booklet.parts_pages(document.lots, 6))
	var booklet: String = Booklet.html(document)
	_write(_out.path_join("booklet.html"), booklet)

	var read: RefCounted = _writer()
	read.call("read_text", booklet)
	var steps: Array = read.get("steps")
	var said := PackedStringArray()
	for step: Dictionary in steps:
		said.append("%s%d" % [(str(step["within"]) + ":") if not str(step["within"]).is_empty() else "",
			int(step["number"])])
	_check("read: the six steps in the booklet's order, the callout's own under its name (%s)"
		% ", ".join(said), said == PackedStringArray(["1", "2", "tower:1", "tower:2", "3", "4"]))
	if steps.size() != 6:
		return
	_check("...each with its own picture, the undrawn none", steps.slice(0, 5).all(
		func(step: Dictionary) -> bool: return str(step["picture"]).begins_with("data:image/png"))
		and str(steps[5]["picture"]).is_empty() and steps[0]["picture"] == _picture(101)
		and steps[2]["picture"] == _picture(151))
	_check("...step 1's parts: 2x the brick, 1x the plate from drawer 3 (%s)" % [steps[0]["parts"]],
		(steps[0]["parts"] as Array).size() == 2 and int(steps[0]["parts"][0]["count"]) == 2
		and int(steps[0]["parts"][1]["count"]) == 1
		and str(steps[0]["parts"][1]["place"]) == "from drawer 3"
		and str(steps[0]["parts"][1]["title"]).begins_with("Plate 2 x 2 & <wide>"))
	_check("...step 2 named, step 1 starting the base (%s, %s)" % [steps[1]["name"], steps[0]["banner"]],
		str(steps[1]["name"]) == "Build the wall" and str(steps[0]["banner"]) == "Part 1 · the base"
		and str(steps[1]["banner"]).is_empty())
	_check("...the tower built twice; step 3's door callout, 2x, its two pictures, the designer's picture in no step",
		int(steps[2]["build"]) == 2 and (steps[4]["callout"] as Array) == [_picture(160), _picture(161)]
		and int(steps[4]["times"]) == 2 and steps.all(func(step: Dictionary) -> bool:
			return not (step["callout"] as Array).has(_picture(250)) and step["picture"] != _picture(250)))
	_check("...the cover, the finished model, both parts and the credits", read.get("cover") == _picture(200)
		and read.get("finished") == _picture(210) and (read.get("inventory") as Array).size() == 2
		and str(read.get("credits")).begins_with("Part geometry") and str(read.get("counts")) == "12 pieces · 4 steps")

	for theme: String in ["light", "dark"]:
		var long: String = read.call("long_page", theme)
		_write(_out.path_join("long_%s.html" % theme), long)
		_page_safe("the long page, %s" % theme, long, theme)
		var at: int = -1
		var in_order: bool = true
		for red: int in [101, 102, 151, 152, 103]:
			var found: int = long.find(_picture(red))
			in_order = in_order and found > at and long.count(_picture(red)) == 1
			at = found
		_check("...%s: every step's picture once, in order" % theme, in_order)
		_check("...%s: six steps, the base's banner once, the tower's steps under its name" % theme,
			long.count("<article class=\"step") == 6 and long.count("Part 1 · the base") == 1
			and long.count("<span class=\"of\">tower ×2</span>") == 2)
		_check("...%s: the counts 2x and 1x, the place, a part picture as a rule for each part used" % theme,
			long.contains("<b>2x</b>") and long.contains("<b>1x</b><small>from drawer 3</small>")
			and long.count("{background-image:url(data:image/png") == 2)
	var dark: String = read.call("long_page", "dark")
	var light: String = read.call("long_page", "light")
	_check("dark: the page says dark, light says light, the cards the booklet's page colour in both",
		dark.contains("<html lang=\"en\" class=\"dark\">") and dark.contains("content=\"dark\"")
		and light.contains("<html lang=\"en\" class=\"light\">")
		and dark.contains("--card: #dcecf8") and light.contains("--card: #dcecf8"))

	for theme: String in ["light", "dark"]:
		var zip_path: String = _out.path_join("steps_%s.zip" % theme)
		var written: int = _save_zip(read, zip_path, theme)
		var reader := ZIPReader.new()
		if not _check("a page a step, %s: written (%d steps)" % [theme, written],
				written == 6 and reader.open(zip_path) == OK):
			continue
		var files: PackedStringArray = reader.get_files()
		_check("...the zip: the contents and six step pages (%s)" % ", ".join(files),
			files.size() == 7 and files.has("index.html") and files.has("step-001.html")
			and files.has("step-006.html"))
		var broken := PackedStringArray()
		for file: String in files:
			var text: String = reader.read_file(file).get_string_from_utf8()
			if file == "step-003.html":
				_write(_out.path_join("step-003_%s.html" % theme), text)
			_page_safe("...%s" % file, text, theme, false)
			for found: RegExMatch in RegEx.create_from_string("href=\"([^\"]+)\"").search_all(text):
				if not files.has(found.get_string(1)):
					broken.append("%s -> %s" % [file, found.get_string(1)])
		_check("...every link goes to a file in the zip (%s)" % ", ".join(broken), broken.is_empty())
		var third: String = reader.read_file("step-003.html").get_string_from_utf8()
		_check("...step-003 is the tower's first step: Previous step-002, Next step-004, 3 of 6",
			third.contains("<a href=\"step-002.html\" rel=\"prev\">Previous</a>")
			and third.contains("href=\"step-004.html\" rel=\"next\">Next</a>")
			and third.contains("<link rel=\"prev\" href=\"step-002.html\">")
			and third.contains("<span>3 of 6</span>") and third.contains(_picture(151))
			and not third.contains(_picture(101)))
		var last: String = reader.read_file("step-006.html").get_string_from_utf8()
		_check("...the last step ends at the finished model, and its Next goes to the contents",
			last.contains(_picture(210)) and last.contains("href=\"index.html\" rel=\"next\">Finished</a>"))
		var index: String = reader.read_file("index.html").get_string_from_utf8()
		_check("...the contents links all six steps and starts at step-001",
			index.count("<li><a href=\"step-") == 6 and index.contains("href=\"step-001.html\" rel=\"next\">Start building</a>")
			and index.contains("Step 2: Build the wall") and index.contains("tower, step 1"))
		reader.close()

	# A hand-made booklet whose step picture is not data: it is left out.
	var crafted: String = booklet.replace(_picture(101), "https://example.com/x.png")
	var again: RefCounted = _writer()
	again.call("read_text", crafted)
	var long_again: String = again.call("long_page", "light")
	_check("a step picture that is not data is left out of the page",
		not long_again.contains("example.com") and (again.get("steps") as Array).size() == 6)


## [param text] a page that stands alone and runs nothing.
func _page_safe(what: String, text: String, theme: String, say: bool = true) -> void:
	var ok: bool = not text.containsn("<script") and text.contains(
		"default-src 'none'; style-src 'unsafe-inline'; img-src data:") \
		and not text.contains("<House>") and text.contains("Gate &lt;House&gt; &amp; &quot;Hill&quot;") \
		and text.contains("class=\"%s\"" % theme) and not text.contains("src=\"http") \
		and not text.contains("url(http")
	if say or not ok:
		_check("%s: no script, nothing from outside, the title escaped" % what, ok)


func _save_zip(read: RefCounted, path: String, theme: String) -> int:
	var zip := ZIPPacker.new()
	if zip.open(path) != OK:
		return -1
	var steps: Array = read.get("steps")
	for index: int in steps.size():
		zip.start_file(str(read.call("step_file", index)))
		zip.write_file(str(read.call("step_page", index, theme)).to_utf8_buffer())
		zip.close_file()
	zip.start_file("index.html")
	zip.write_file(str(read.call("contents", theme)).to_utf8_buffer())
	zip.close_file()
	zip.close()
	return steps.size()


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# -- the real thing --------------------------------------------------------


func _real() -> void:
	print("\n  the gatehouse's booklet, saved by Save as web page")
	Download.folder = _out
	BookletMaker.open_when_written = false
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 90:
		await process_frame
	var playback: Variant = main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	var store: ModelStore = main.get("_store")
	(main.get("_steps") as StepsBar).stop()
	main.call("clear_model")
	for _n: int in 4:
		await process_frame
	main.call("_open", ProjectSettings.globalize_path(GATEHOUSE))
	for _n: int in 600:
		if store.awaited.is_empty():
			break
		await process_frame
	for _n: int in 10:
		await process_frame
	var booklet: String = _out.path_join("gatehouse_instructions.html")
	var made: String = str(await main.call("_export_booklet", booklet))
	if not _check("the booklet made (%s)" % made.left(120), made.begins_with("wrote")):
		return
	var text: String = FileAccess.get_file_as_string(booklet)
	var pictures: int = text.count("alt=\"Step ")
	_check("...with its Save as web page in its bar", text.contains("id=\"save-html\"")
		and text.contains("<option value=\"steps\">A page per step</option>")
		and text.contains("<option value=\"dark\">Dark</option>"))
	var long_path: String = _out.path_join("gatehouse_web.html")
	var said: String = str(await main.call("save_booklet_as", "html-long-dark", long_path))
	var long: String = FileAccess.get_file_as_string(long_path)
	_check("one long page, dark: %s" % said.left(140), said.begins_with("wrote")
		and long.contains("class=\"dark\""))
	_check("...every step's picture the booklet has (%d of %d), each once" % [
		long.count("<img class=\"picture\""), pictures], pictures > 0
		and long.count("<img class=\"picture\"") == pictures)
	var zip_path: String = _out.path_join("gatehouse_web.zip")
	said = str(await main.call("save_booklet_as", "html-steps-light", zip_path))
	var reader := ZIPReader.new()
	var opened: bool = reader.open(zip_path) == OK
	var files: PackedStringArray = reader.get_files() if opened else PackedStringArray()
	_check("a page a step, light: %s (%d files)" % [said.left(140), files.size()],
		said.begins_with("wrote") and files.has("index.html") and files.size() >= pictures + 1)
	if opened:
		var shown: int = 0
		for file: String in files:
			var page: String = reader.read_file(file).get_string_from_utf8()
			shown += page.count("<img class=\"picture\"")
			if file == "step-002.html":
				_write(_out.path_join("gatehouse_step-002.html"), page)
			if file == "index.html":
				_write(_out.path_join("gatehouse_index.html"), page)
		_check("...each step's picture on its own page (%d of %d)" % [shown, pictures], shown == pictures)
		reader.close()
	main.queue_free()
	for _n: int in 2:
		await process_frame
