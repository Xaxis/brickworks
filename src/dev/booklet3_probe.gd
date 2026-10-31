## Studio's booklet extras (APP_UX3, booklet3), set the two ways the owner
## sets them, and read off the printed page.
##
##   godot --path . --resolution 1280x720 --script src/dev/booklet3_probe.gd -- [--into=DIR] [--before]
##
## Windowed, on the GPU: the booklet's pictures are drawn. On a model made
## here (booklet3.mpd): a Technic beam 7 on its side, an axle 4 through its
## end hole sideways, three bricks of three colours, eight grey bricks, and
## a pod of five steps put on them, built on pages of its own.
##
## - Over MCP, as a session calls it: edit_booklet pull=2 on the axle's step,
##   colours=true on the bricks' step; each one undo, said in the file
##   ("0 !BRICKWORKS PULL 2", "... COLOURS ON"), kept through a save and an
##   open. By hand: Build, Booklet page, Colour guide on the beam's step and
##   again, on and off.
## - The pulled-out axle: drawn 2 studs (40 LDU) out along its own line,
##   away from the beam it goes into, not up; the step's new parts drawn
##   where it was pulled to; a red arrow from it pointing in.
## - The 1:1 guides the booklet gives the first beam and the first axle:
##   measured on the 300 dpi PNG page and on the PDF drawn by poppler at 300
##   dpi, the axle 4 is 32.0 mm and the beam 7 56.0 mm, within 0.2 mm, the
##   ring saying 4 and 7. actual_size=false takes one off, "auto" puts it back.
## - The colour guide lists the step's colours, in the booklet, the PDF's
##   words and booklet_layout.
## - The pod's first page shows it finished in its corner, nothing on it.
## - booklet_layout says each.
##
## --before writes the booklet as it was made before these (no setting, and
## only what the booklet already had) for a picture to hold beside.
## Pages it writes to DIR: booklet3.html, .pdf, _pages.zip, and each page as
## page-NNN.png (300 dpi) and pdf-NNN.png (poppler) to look at.
extends SceneTree

const MODEL := """0 FILE booklet3.ldr
0 Booklet extras
0 Name: booklet3.ldr
0 Author: A. Builder
1 71 0 -9 0 0 1 0 -1 0 0 0 0 1 32524.dat
0 STEP
1 0 30 -9 -60 1 0 0 0 1 0 0 0 1 3705.dat
0 STEP
1 4 120 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 120 -32 -10 1 0 0 0 1 0 0 0 1 3023.dat
1 14 190 -24 0 1 0 0 0 1 0 0 0 1 3005.dat
0 STEP
1 72 260 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
1 72 300 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
1 72 340 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
1 72 380 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
1 72 260 -24 40 1 0 0 0 1 0 0 0 1 3003.dat
1 72 300 -24 40 1 0 0 0 1 0 0 0 1 3003.dat
1 72 340 -24 40 1 0 0 0 1 0 0 0 1 3003.dat
1 72 380 -24 40 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 16 260 -24 0 1 0 0 0 1 0 0 0 1 pod.ldr
0 STEP
0 NOFILE
0 FILE pod.ldr
0 Pod
0 Name: pod.ldr
0 Author: A. Builder
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 15 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 2 0 -72 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 1 0 -96 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 4 0 -104 0 1 0 0 0 1 0 0 0 1 3022.dat
0 NOFILE
"""

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _steps: StepsBar
var _library: PartLibrary
var _tools: AppTools
var _out: String = ""
var _before: bool = false


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
		elif arg == "--before":
			_before = true
	if _out.is_empty():
		_out = OS.get_user_data_dir().path_join("booklet3_probe")
	DirAccess.make_dir_recursive_absolute(_out)
	Download.folder = _out
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
	_steps = _main.get("_steps")
	_library = _main.get("_library")
	var path: String = _out.path_join("booklet3.mpd")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(MODEL)
	file.close()
	await _open(path)
	if not await _start_timeline():
		_quit()
		return
	if _before:
		print("")
		print("the booklet as it was, nothing set")
		await _printed("before")
		_quit()
		return
	_tools = AppTools.new()
	_tools.app = _main
	_tools.assistant = _main.get("_assistant")
	await _set_by_session()
	await _set_by_hand()
	var printed: Dictionary = await _printed("booklet3")
	if not printed.is_empty():
		_pulled(printed)
		_actual_size(printed)
		_colours(printed)
		_preview(printed)
	await _actual_off_and_back()
	await _layout_said()
	await _reopened()
	_quit()


func _quit() -> void:
	print("")
	print("booklet3: %s" % ("every check passed" if _failures == 0
		else "%d FAILED" % _failures))
	_main.queue_free()
	await _frames(2)
	quit(1 if _failures > 0 else 0)


func _open(path: String) -> void:
	_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	_main.call("_open", path)
	for _n: int in 600:
		if _store.awaited.is_empty():
			break
		await process_frame
	await _frames(10)
	_check("opened %s: %d parts, the author's steps" % [path.get_file(), _world.brick_count()],
		_world.brick_count() == 18 and AuthorSteps.any(_world, _store.scenery))


func _start_timeline() -> bool:
	if not _steps.visible:
		await _steps.start(_world, _library, _store.scenery)
	_steps.set_mode(StepsBar.AUTHORS)
	await _frames(4)
	var plan: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery, {}, true)
	var numbers: Array = []
	for step: Instructions.Step in plan:
		if step.callout_step == 0:
			numbers.append(step.number)
	return _check("the model's own steps are 1 to 5 (%s), the pod built in five of its own"
		% str(numbers), numbers == [1, 2, 3, 4, 5])


func _brick(part: String) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			return brick
	return null


## The look of the step [param part] is put on in.
func _look_of(part: String) -> Dictionary:
	var brick: BrickWorld.Brick = _brick(part)
	return BookletLooks.of(_world, Assemblies.path_of(brick), brick.step) if brick != null else {}


## Over MCP, as a session calls it: the axle's step pulled out 2 studs, the
## bricks' step's colours listed; each one undo, said in the file.
func _set_by_session() -> void:
	print("")
	print("set over MCP, as a session calls edit_booklet")
	var said: String = str(await _tools.run("edit_booklet", {"step": 2, "pull": 2}))
	print("    pull=2: %s" % said)
	var text: String = _store.to_text("booklet3", true)
	_check("edit_booklet pull=2 on the axle's step: \"0 !BRICKWORKS PULL 2\" in its step",
		text.contains("0 !BRICKWORKS PULL 2\n") or text.contains("0 !BRICKWORKS PULL 2\r"))
	_builder.undo()
	await _frames(2)
	_check("...one undo takes it off", not _store.to_text("booklet3", true).contains("PULL"))
	_builder.redo()
	await _frames(2)
	_check("...and redo puts it back", _store.to_text("booklet3", true).contains("PULL 2"))
	said = str(await _tools.run("edit_booklet", {"step": 3, "colours": true}))
	print("    colours=true: %s" % said)
	_check("edit_booklet colours=true on the bricks' step: \"... COLOURS ON\"",
		_store.to_text("booklet3", true).contains("0 !BRICKWORKS COLOURS ON"))
	said = str(await _tools.run("edit_booklet", {"step": 2, "pull": "far"}))
	_check("pull= a word is refused, saying what it takes (\"%s\")" % said,
		said.begins_with("pull= is"))


## By hand: Build, Booklet page, Colour guide on the beam's step lists its
## colour, and again takes it off.
func _set_by_hand() -> void:
	print("")
	print("set by hand, Build, Booklet page")
	var menu: Array = Shell.SUBMENUS.get("booklet", [])
	_check("Build, Booklet page has Pull out the selected parts, Colour guide, 1:1 guide "
		+ "and Sub-model preview", ["booklet_pull", "booklet_colours", "booklet_actual_size",
			"booklet_preview"].all(func(id: String) -> bool:
				return id in menu and _shell._commands.has(id)))
	_steps.refresh(1)
	await _frames(2)
	_check("the timeline is on step 1", _steps.booklet_step() != null
		and _steps.booklet_step().number == 1)
	_check("Colour guide can be pressed on step 1", _shell.run("booklet_colours"))
	await _frames(4)
	var look: Dictionary = _look_of("32524")
	_check("...and step 1 lists its colours (%s)" % str(look), bool(look.get("colours", false)))
	_shell.run("booklet_colours")
	await _frames(4)
	_check("...pressed again it does not", not _look_of("32524").has("colours"))


## The booklet made from the model as it is, written out, and its PDF and
## pages: {html, pdf, zip, maker's measured, document}.
func _printed(stem: String) -> Dictionary:
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var html: String = await maker.make(_world, _store.scenery, "Booklet extras")
	var measured: Array = maker.measured.duplicate()
	var document: Booklet.Document = maker.document
	maker.queue_free()
	if not _check("the booklet was made (%d pages)" % (document.pages.size() if document != null
			else 0), not html.is_empty() and document != null):
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
	var density: float = drawer.px_per_mm
	drawer.queue_free()
	_check("its PDF (%d pages) and its pages as PNG (%d, %.1f dots an inch)" % [pages, drawn,
		density * 25.4], writer.ok() and pages > 0 and drawn == pages)
	# Each page to look at: the 300 dpi PNG, and the PDF as poppler draws it.
	var reader := ZIPReader.new()
	if reader.open(zip) == OK:
		for name: String in reader.get_files():
			var bytes: PackedByteArray = reader.read_file(name)
			var number: String = name.get_basename().right(3)
			var copy: FileAccess = FileAccess.open(_out.path_join("%s-page-%s.png" % [stem, number]),
				FileAccess.WRITE)
			copy.store_buffer(bytes)
			copy.close()
		reader.close()
	OS.execute("pdftoppm", ["-r", "300", "-png", ProjectSettings.globalize_path(pdf),
		ProjectSettings.globalize_path(_out.path_join(stem + "-pdf"))])
	return {"html": html, "pdf": pdf, "zip": zip, "measured": measured, "document": document,
		"stem": stem, "pages": pages}


func _entry(printed: Dictionary, number: int, kind: String = "steps") -> Array:
	var document: Booklet.Document = printed["document"]
	for page: Booklet.Page in document.pages:
		if page.kind != kind:
			continue
		for entry: Booklet.Entry in page.entries:
			if entry.number == number:
				return [entry, page]
	return []


## The axle drawn 2 studs out along its own line, away from the beam, with
## an arrow pointing in.
func _pulled(printed: Dictionary) -> void:
	print("")
	print("the axle pulled out (Studio's buffer exchange)")
	var axle: BrickWorld.Brick = _brick("3705")
	var beam: BrickWorld.Brick = _brick("32524")
	var found: Array = (printed["measured"] as Array).filter(func(one: Dictionary) -> bool:
		return str(one.get("what")) == "pulled")
	if not _check("the axle's step pulled one part out (%d)" % found.size(),
			found.size() == 1 and axle != null and beam != null):
		return
	var one: Dictionary = found[0]
	var by: Vector3 = one["by"]
	var line: Vector3 = axle.transform.basis.x.normalized()
	var away: Vector3 = axle.transform.origin - beam.transform.origin
	print("    moved by %s LDU; the axle's line %s; the arrow %s to %s mm" % [by.snapped(
		Vector3.ONE * 0.01), line.snapped(Vector3.ONE * 0.001), (one["arrow"][0] as Vector2).snapped(
		Vector2.ONE * 0.1), (one["arrow"][1] as Vector2).snapped(Vector2.ONE * 0.1)])
	_check("it sits 2 studs out: %.2f LDU (40)" % by.length(), absf(by.length() - 40.0) < 0.01)
	_check("...along its own line (%.4f of it), not up" % absf(by.normalized().dot(line)),
		absf(by.normalized().dot(line)) > 0.999 and absf(by.normalized().dot(Vector3.UP)) < 0.01)
	_check("...away from the beam it goes into", by.dot(away) > 0.0)
	var arrow: Array = one["arrow"]
	var pointing: Vector2 = (arrow[1] as Vector2) - (arrow[0] as Vector2)
	var inward: Vector2 = (one["home"] as Vector2) - (one["out"] as Vector2)
	_check("its arrow points in: %.3f along the way back (%.1f mm long)" % [
		pointing.normalized().dot(inward.normalized()), pointing.length()],
		pointing.normalized().dot(inward.normalized()) > 0.95 and pointing.length() >= 5.0)
	var drawn: Array = (printed["measured"] as Array).filter(func(m: Dictionary) -> bool:
		return str(m.get("what")) == "new parts of step 2")
	_check("the step's new part is drawn where it was pulled to (%s holds %s)" % [
		str(drawn[0]["drawn"]) if not drawn.is_empty() else "nothing", str(one["out"])],
		not drawn.is_empty() and (drawn[0]["drawn"] as Rect2).grow(0.5).has_point(one["out"]))
	var at: Array = _entry(printed, 2)
	var html: String = printed["html"]
	var section: String = _section_of(html, int(at[1].number) if not at.is_empty() else -1)
	_check("its page prints the red arrow", section.contains("stroke=\"#d01012\""))


## The 1:1 guides measured on the printed pages.
func _actual_size(printed: Dictionary) -> void:
	print("")
	print("the 1:1 guides, measured on the pages")
	for want: Array in [[1, "32524", "7", 56.0], [2, "3705", "4", 32.0]]:
		var at: Array = _entry(printed, int(want[0]))
		if not _check("step %d is on a page" % int(want[0]), not at.is_empty()):
			continue
		var entry: Booklet.Entry = at[0]
		var page: Booklet.Page = at[1]
		var index: int = -1
		for n: int in entry.actual.size():
			if str(entry.actual[n]["part"]) == str(want[1]):
				index = n
		if not _check("step %d has a 1:1 guide of the %s, its ring saying %s (%s)" % [entry.number,
				want[1], want[2], str(entry.actual.map(func(g: Dictionary) -> String:
					return "%s:%s" % [g["part"], g["studs"]]))],
				index >= 0 and str(entry.actual[index]["studs"]) == str(want[2])
				and not str(entry.actual[index]["image"]).is_empty()):
			continue
		var rect: Rect2 = Booklet.actual_rects(entry)[index]
		var png := Image.load_from_file(_out.path_join("%s-page-%03d.png" % [printed["stem"],
			page.number]))
		var density: float = BookletPng.DPI / 25.4
		var on_png: float = _ink_length(png, rect, density)
		_check("the %s's guide on the 300 dpi PNG page measures %.2f mm (%.1f, within 0.2)" % [
			want[1], on_png, float(want[3])], absf(on_png - float(want[3])) <= 0.2)
		var pdf := _pdf_page(printed, page.number)
		var on_pdf: float = _ink_length(pdf, rect, density)
		_check("...and in the PDF, drawn by poppler at 300 dpi: %.2f mm" % on_pdf,
			absf(on_pdf - float(want[3])) <= 0.2)
		var section: String = _section_of(printed["html"], page.number)
		_check("...the page prints it with \"1:1\" over it and %s in its ring" % want[2],
			section.contains(">1:1</div>") and section.contains("alt=\"1:1: ")
			and section.contains(">%s</div>" % want[2]))


## The PDF's page [param number] as poppler drew it at 300 dpi.
func _pdf_page(printed: Dictionary, number: int) -> Image:
	for width: int in [1, 2, 3]:
		var path: String = _out.path_join("%s-pdf-%s.png" % [printed["stem"],
			str(number).pad_zeros(width)])
		if FileAccess.file_exists(path):
			return Image.load_from_file(path)
	return null


## How long the part drawn in [param rect] (page mm) is across: the columns
## with ink in them (darker than 75% white) on [param image], drawn at
## [param density] pixels a mm, first to last.
static func _ink_length(image: Image, rect: Rect2, density: float) -> float:
	if image == null:
		return -1.0
	var area := Rect2i(Vector2i((rect.position * density).floor()),
		Vector2i((rect.size * density).ceil())).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var first: int = -1
	var last: int = -1
	for x: int in range(area.position.x, area.end.x):
		var dark: int = 0
		for y: int in range(area.position.y, area.end.y):
			if image.get_pixel(x, y).get_luminance() < 0.75:
				dark += 1
		if dark >= 2:
			if first < 0:
				first = x
			last = x
	return (last - first + 1) / density if first >= 0 else 0.0


## The step's colours listed under its number, in the booklet and the PDF.
func _colours(printed: Dictionary) -> void:
	print("")
	print("the colour guide")
	var at: Array = _entry(printed, 3)
	if not _check("step 3 is on a page", not at.is_empty()):
		return
	var entry: Booklet.Entry = at[0]
	var names: Array = entry.colours.map(func(c: Dictionary) -> String: return str(c["name"]))
	var wanted: Array = []
	for lot: Booklet.Lot in entry.lots:
		if not lot.colour in wanted:
			wanted.append(lot.colour)
	_check("it lists the step's colours, each once: %s (its parts %s)" % [str(names), str(wanted)],
		names.size() == 3 and wanted.size() == 3 and names.all(func(n: String) -> bool:
			return n in wanted))
	var section: String = _section_of(printed["html"], (at[1] as Booklet.Page).number)
	_check("...printed on its page, a chip each",
		names.all(func(n: String) -> bool: return section.contains("></i>%s</div>" % n)))
	var words: Array = []
	OS.execute("pdftotext", ["-f", str((at[1] as Booklet.Page).number), "-l",
		str((at[1] as Booklet.Page).number), ProjectSettings.globalize_path(printed["pdf"]), "-"],
		words)
	var text: String = "".join(words)
	_check("...and in the PDF's words", names.all(func(n: String) -> bool: return text.contains(n)))
	var others: Array = []
	for page: Booklet.Page in (printed["document"] as Booklet.Document).pages:
		for one: Booklet.Entry in page.entries:
			if not one.colours.is_empty() and one.number != 3:
				others.append(one.number)
	_check("no other step lists its colours (%s)" % str(others), others.is_empty())


## The pod's first own page shows it finished in its corner, nothing on it.
func _preview(printed: Dictionary) -> void:
	print("")
	print("the sub-model preview")
	var first: Booklet.Page = null
	for page: Booklet.Page in (printed["document"] as Booklet.Document).pages:
		if page.kind == "callout" and first == null:
			first = page
	if not _check("the pod is built on pages of its own", first != null):
		return
	var callout: Booklet.Callout = first.preview
	if not _check("its first page shows it finished", callout != null
			and not callout.preview_image.is_empty()):
		return
	_check("...in a box inside its frame (%s in %s)" % [callout.preview_box, first.frame],
		first.frame.encloses(callout.preview_box))
	var on: Array = []
	for thing: Dictionary in Booklet.things_on(first):
		if Booklet.overlaps(thing["rect"], 0.0, callout.preview_box, 0.0):
			on.append("step %d's %s" % [(thing["entry"] as Booklet.Entry).number, thing["kind"]])
	_check("...nothing on it (%s)" % (", ".join(on) if not on.is_empty() else "nothing"),
		on.is_empty())
	_check("...printed (\"The Pod, finished\")", _section_of(printed["html"],
		first.number).contains("alt=\"The %s, finished\"" % callout.name))
	var later: int = 0
	for page: Booklet.Page in (printed["document"] as Booklet.Document).pages:
		if page.kind == "callout" and page != first and page.preview != null:
			later += 1
	_check("...on its first page alone", later == 0)


## actual_size=false takes the beam's guide off; "auto" puts it back.
func _actual_off_and_back() -> void:
	print("")
	print("actual_size= over MCP")
	var said: String = str(await _tools.run("edit_booklet", {"step": 1, "actual_size": false}))
	var pages: Array[Booklet.Page] = await _laid()
	_check("actual_size=false: step 1 has no 1:1 guide (\"%s\")" % said,
		_guides_of(pages, 1).is_empty())
	said = str(await _tools.run("edit_booklet", {"step": 1, "actual_size": "auto"}))
	pages = await _laid()
	_check("actual_size=\"auto\": the beam's back (%s)" % str(_guides_of(pages, 1)),
		_guides_of(pages, 1) == ["32524"])
	said = str(await _tools.run("edit_booklet", {"step": 3, "actual_size": ["3001"]}))
	pages = await _laid()
	_check("actual_size=[\"3001\"]: step 3 has a 1:1 guide of its 2 x 4 brick (%s)"
		% str(_guides_of(pages, 3)), _guides_of(pages, 3) == ["3001"])
	_builder.undo()
	await _frames(2)


func _laid() -> Array[Booklet.Page]:
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(_world, _store.scenery, "Booklet extras")
	maker.queue_free()
	return pages


func _guides_of(pages: Array[Booklet.Page], number: int) -> Array:
	for page: Booklet.Page in pages:
		for entry: Booklet.Entry in page.entries:
			if entry.number == number and page.kind == "steps":
				return entry.actual.map(func(g: Dictionary) -> String: return str(g["part"]))
	return []


func _layout_said() -> void:
	print("")
	print("booklet_layout")
	var said: String = str(await _tools.run("booklet_layout", {}))
	for line: String in said.split("\n"):
		if line.begins_with("  page"):
			print("    " + line.strip_edges())
	_check("says the axle pulled out, the 1:1 guides, the colours and the pod shown first",
		said.contains("pulled out 2 studs with an arrow in")
		and said.contains("a 1:1 guide of the Technic Axle")
		and said.contains("a 1:1 guide of the Technic Beam")
		and said.contains("its colours listed:") and said.contains("shown finished first"))


## Saved and opened again, the looks are as set.
func _reopened() -> void:
	print("")
	print("saved and opened again")
	var text: String = _store.to_text("booklet3", true)
	var path: String = _out.path_join("booklet3_saved.mpd")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	await _open(path)
	var two: Dictionary = _look_of("3705")
	var three: Dictionary = _look_of("3001")
	_check("step 2 pulls its parts out 2 studs (%s), step 3 lists its colours (%s)" % [
		str(two.get("pull")), str(three.get("colours"))],
		two.get("pull") is Dictionary and is_equal_approx(float(two["pull"]["studs"]), 2.0)
		and bool(three.get("colours", false)))
	_check("...and saved again, the same text", _store.to_text("booklet3", true) == text)


## The booklet's page numbered [param number], as written.
static func _section_of(html: String, number: int) -> String:
	var at: int = html.find("id=\"page-%d\"" % number)
	if at < 0:
		return ""
	var end: int = html.find("</section>", at)
	return html.substr(at, end - at)
