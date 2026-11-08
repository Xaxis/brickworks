## Does Save as PDF in the booklet save the booklet, page for page, in
## the letters it was written in?
##
##   godot --path . --resolution 1280x800 --script src/dev/booklet_pdf_probe.gd -- [--model=FILE] [--into=DIR] [--html=FILE] [--against=DIR] [--words-only]
##
## Needs a window: the booklet's pictures are drawn, and so are its pages
## as PNGs. FILE is res://models/castle.ldr unless named; DIR is where
## the booklet, its PDF and its pages' zip are left to be looked at (the
## probe's own folder unless named). --html=FILE saves a booklet already
## made, from its file, without drawing one (BookletPdf and BookletPng on
## their own).
##
## Through the way in first, as a person comes: the sign-in screen up over
## the app (gate_for_probe), a throwaway account signed in (made with the
## admin key and a password, so no code is spent at the per-IP limit), the
## screen gone; the account deleted at the end. Needs .env (SUPABASE_URL,
## SUPABASE_SECRET_KEY).
##
## Words beyond Latin (APP_UX7 #13 pdfcid): booklook's dialog_a given a
## cover title in Cyrillic and a footer in Greek by page_setup and a note
## in Japanese on step 1 by edit_booklet, as a person's Claude gives them,
## then Instructions and Save as PDF as above. Does pdftotext read each
## back exactly as typed, with no "?", wherever the app's fonts (its own
## type, and the system's Godot draws a letter in where that has none)
## have the letters, and does the export name none missing? Is every font
## embedded, cut down and mapped to Unicode (pdffonts)? Godot draws
## Japanese in Droid Sans Fallback here, a TrueType face; Noto Sans CJK, a
## CFF face as a Mac's Hiragino is, is given the note by hand and read the
## same, drawn by poppler and by Ghostscript where poppler draws Droid.
## --words-only stops there. --against=DIR (the commit before's --into):
## its castle booklet's PDF written again from its own file, each page the
## same at 300 dots an inch to the pixel, the file no more than 10% bigger.
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
var _email: String = ""

## The words in three scripts, and what each is on the booklet.
const TITLE := "Крепость у моря — сборка"
const FOOTER := "Οδηγίες συναρμολόγησης"
const NOTE := "城の門を組み立てる、二つ目の手順"
const FIXTURE := "res://tests/fixtures/booklook/dialog_a.ldr"


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
	var against: String = ""
	var words_only: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			model = arg.trim_prefix("--model=")
		elif arg.begins_with("--into="):
			out = arg.trim_prefix("--into=")
		elif arg.begins_with("--html="):
			html = arg.trim_prefix("--html=")
		elif arg.begins_with("--against="):
			against = arg.trim_prefix("--against=")
		elif arg == "--words-only":
			words_only = true
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
	Account.where = "user://probe_session.json"
	Account._clear()
	_main = load("res://src/main.tscn").instantiate()
	# The sign-in screen over the app, as a person opening it meets it.
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		_shell = _main.get("_shell")
		_bar = _main.get("_bar")
		if bool(_main.get("_built")) and _shell != null and _bar != null:
			break
	await _frames(30)
	if not await _way_in():
		_quit()
		return
	await _words(out)
	if words_only:
		_quit()
		return

	print("")
	print("the castle's booklet")
	_main.call("_open", model)
	_main.call("_lay_baseplate")
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(60)
	var world: BrickWorld = _main.get("_world")
	print("  %s: %d parts" % [model.get_file(), world.brick_count()])
	var made: Dictionary = await _booklet(out.path_join(model.get_file().get_basename() + "_instructions.html"))
	if not made.is_empty():
		print("  saved: the PDF in %.1f s, %.1f MB; the pages in %.1f s, %.1f MB (the booklet %.1f MB)"
			% [float(made["pdf_s"]), _mb(made["pdf"]), float(made["png_s"]), _mb(made["zip"]),
				_mb(made["path"])])
		_checked(made["path"], made["pdf"], made["zip"], out)
	if not against.is_empty():
		await _same_as_before(against, out)
	_quit()


## Instructions pressed, the booklet saved at [param path] and opened in
## the browser, then its Save as PDF and Save pages as PNG pressed, as the
## browser presses them: {path, pdf, zip, pdf_line, png_line, pdf_s,
## png_s}, or {} when the booklet never opened.
func _booklet(path: String) -> Dictionary:
	_check("Instructions can be pressed", _shell.run("instructions"))
	if not _check("Instructions asks where to save the booklet", await _answer(path)):
		return {}
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
		return {}
	var head: String = FileAccess.get_file_as_string(path).substr(0, 20000)
	_check("the booklet's bar has Print, Save as PDF and Save pages as PNG",
		head.contains(">Print</button>") and head.contains(">Save as PDF</button>")
		and head.contains(">Save pages as PNG</button>"))

	var stem: String = path.get_basename()
	var made: Dictionary = {"path": path, "pdf": stem + ".pdf", "zip": stem + "_pages.zip"}
	for kind: String in ["pdf", "png"]:
		var to: String = made["pdf"] if kind == "pdf" else made["zip"]
		DirAccess.remove_absolute(to)
		var reply: Array = [null]
		var asked: StreamPeerTCP = _press(kind)
		var answered := func() -> void:
			reply[0] = _reply_of(asked)
		made[kind + "_line"] = ""
		made[kind + "_s"] = -1.0
		if not _check("Save %s asks where to save it" % kind.to_upper(), await _answer(to, answered)):
			continue
		var pressed: int = Time.get_ticks_msec()
		until = Time.get_ticks_msec() + 600000
		while reply[0] == null and Time.get_ticks_msec() < until:
			await process_frame
			reply[0] = _reply_of(asked)
		made[kind + "_s"] = (Time.get_ticks_msec() - pressed) / 1000.0
		var line: String = str(reply[0])
		made[kind + "_line"] = line
		print("  %s: %s" % [kind, line])
		_check("the booklet is told where the %s went (%s)" % [kind, line.left(160)],
			line.begins_with("wrote ") and (line.ends_with(to) or line.contains(to + "; ")))
		_check("...and so is the status bar", _bar.status_text() == line)
		_check("...and the file is there, with no .part beside it",
			FileAccess.file_exists(to) and not FileAccess.file_exists(to + ".part"))
	return made


## The words in Cyrillic, Greek and Japanese, through the person's way to
## a PDF, read back by poppler.
func _words(out: String) -> void:
	print("")
	print("a cover title in Cyrillic, a footer in Greek and a step note in Japanese (pdfcid)")
	var model: String = out.path_join("words.ldr")
	var copy: FileAccess = FileAccess.open(model, FileAccess.WRITE)
	copy.store_buffer(FileAccess.get_file_as_bytes(FIXTURE))
	copy.close()
	_main.call("_open", model)
	var store: Object = _main.get("_store")
	for _n: int in 600:
		if (store.get("awaited") as Array).is_empty():
			break
		await process_frame
	await _frames(10)
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	print("    page_setup: %s" % str(await tools.run("page_setup", {"title": TITLE, "footer": FOOTER})).left(200))
	print("    edit_booklet: %s" % str(await tools.run("edit_booklet", {"step": 1, "text": {"words": NOTE,
		"x": 20.0, "y": 150.0, "w": 150.0, "h": 12.0, "size": 6.0}})).left(200))
	var made: Dictionary = await _booklet(out.path_join("words_instructions.html"))
	if made.is_empty():
		return
	var pdf: String = ProjectSettings.globalize_path(made["pdf"])
	var lacking: PackedStringArray = _lacking(TITLE + FOOTER + NOTE)
	print("    letters no font of the app's has here: %s" % ("none" if lacking.is_empty() else " ".join(lacking)))
	var line: String = made["pdf_line"]
	var named: bool = line.contains("cannot print")
	_check("the export names none missing that the app's fonts have (%s)" % (line.substr(line.find(";"))
		if named else "names none"), line.begins_with("wrote ") and named == not lacking.is_empty()
		and Array(lacking).all(func(letter: String) -> bool: return line.contains(letter)))
	var said: Array = []
	OS.execute("pdftotext", [pdf, "-"], said)
	var words: String = "".join(said)
	var marks: int = 0
	for typed: Array in [["cover title in Cyrillic", TITLE], ["footer in Greek", FOOTER],
			["step note in Japanese", NOTE]]:
		var expected: String = typed[1]
		for letter: String in lacking:
			marks += expected.count(letter)
			expected = expected.replace(letter, "?")
		_check("pdftotext reads the %s as typed: \"%s\"" % [typed[0], expected], words.contains(expected))
	_check("...with %d \"?\" in the whole PDF's words (%d where the app's fonts lack the letter)"
		% [words.count("?"), marks], words.count("?") == marks)
	_fonts(pdf, "the words' PDF")
	OS.execute("pdftoppm", ["-r", "150", "-png", pdf, ProjectSettings.globalize_path(out.path_join("words-pdf"))])
	_checked(made["path"], made["pdf"], made["zip"], out)
	await _cff(made["path"], out)


## The letters of [param text] no font of the app's has: neither its own
## type nor the system's that Godot draws a letter in where that has none
## (BookletPng draws the page so).
func _lacking(text: String) -> PackedStringArray:
	var font: FontFile = load("res://assets/fonts/LiberationSans-Regular.ttf")
	var server: TextServer = TextServerManager.get_primary_interface()
	var out := PackedStringArray()
	for letter: String in text:
		if letter.strip_edges().is_empty() or font.has_char(letter.unicode_at(0)) or out.has(letter):
			continue
		var shaped: RID = server.create_shaped_text()
		server.shaped_text_add_string(shaped, letter, font.get_rids(), 16)
		var glyphs: Array = server.shaped_text_get_glyphs(shaped)
		server.free_rid(shaped)
		if glyphs.is_empty() or int(glyphs[0]["index"]) == 0 or not (glyphs[0]["font_rid"] as RID).is_valid():
			out.append(letter)
	return out


## pdffonts on [param pdf]: every font in it, cut down, with a map to
## Unicode. Its lines.
func _fonts(pdf: String, what: String) -> PackedStringArray:
	var said: Array = []
	OS.execute("pdffonts", [pdf], said)
	var lines := PackedStringArray()
	var right: int = 0
	var each := RegEx.create_from_string("^(\\S+)\\s+(.+?)\\s+(Identity-H|WinAnsi|Custom|Builtin)\\s+(yes|no)\\s+(yes|no)\\s+(yes|no)\\s+\\d+\\s+\\d+\\s*$")
	for row: String in "".join(said).split("\n"):
		var found: RegExMatch = each.search(row)
		if found == null:
			continue
		lines.append("%s (%s)" % [found.get_string(1), found.get_string(2).strip_edges()])
		if found.get_string(4) == "yes" and found.get_string(5) == "yes" and found.get_string(6) == "yes":
			right += 1
	_check("%s: every font embedded, cut down to its letters and mapped to Unicode (%d of %s)"
		% [what, right, ", ".join(lines)], right > 0 and right == lines.size())
	return lines


## The note set in a CFF face by hand, as the system's Japanese is on a
## Mac (Hiragino) or most Linux desktops (Noto Sans CJK): Godot finds Droid
## Sans Fallback, TrueType, first here.
func _cff(html: String, out: String) -> void:
	var path: String = OS.get_system_font_path("Noto Sans CJK JP", 400, 100, false)
	if path.is_empty() or not ["ttc", "otc", "otf"].has(path.get_extension().to_lower()):
		print("    no CFF face with Japanese here (%s): the CFF check left out" % path)
		return
	var read := BookletRead.new()
	var writer := BookletPdf.new()
	var pdf: String = ProjectSettings.globalize_path(out.path_join("words_cff.pdf"))
	writer.begin(pdf, read)
	if not _check("BookletPdf takes a system face (%s)" % path.get_file(), writer.has_method("_system_face")):
		writer.finish("")
		return
	var found: Array = writer.call("_system_face", path, 0, "Noto Sans CJK JP")
	if not _check("...Noto Sans CJK JP read from it, CFF", not found.is_empty() and bool((found[0] as Object).get("cff"))):
		writer.finish("")
		return
	# Given in place of the face Godot draws the note in, by its file.
	var server: TextServer = TextServerManager.get_primary_interface()
	var font: FontFile = load(BookletPdf.TYPE[0][0])
	var shaped: RID = server.create_shaped_text()
	server.shaped_text_add_string(shaped, NOTE, font.get_rids(), 16)
	var by: RID = server.shaped_text_get_glyphs(shaped)[0]["font_rid"]
	server.free_rid(shaped)
	var drawn_in: String = OS.get_system_font_path(server.font_get_name(by), server.font_get_weight(by),
		server.font_get_stretch(by), false)
	(writer.get("_system_faces") as Dictionary)["%s#%d" % [drawn_in, server.font_get_face_index(by)]] = found
	print("    the note's face, %s (%s), given as Noto Sans CJK JP" % [server.font_get_name(by), drawn_in])
	await read.read_all(html, writer.page)
	writer.finish(read.title)
	var faces: PackedStringArray = _fonts(pdf, "the CFF PDF")
	_check("...one of them the CFF face (CID Type 0C)", Array(faces).any(func(face: String) -> bool:
		return face.contains("NotoSansCJK") and face.contains("Type 0C")))
	var said: Array = []
	OS.execute("pdftotext", [pdf, "-"], said)
	_check("pdftotext reads the note in the CFF face as typed", "".join(said).contains(NOTE))
	# Drawn by two readers: poppler, and Ghostscript, each saying nothing amiss.
	for reader: Array in [["poppler", "pdftoppm", ["-r", "150", "-png", pdf,
			ProjectSettings.globalize_path(out.path_join("words_cff-pdf"))]],
			["Ghostscript", "gs", ["-q", "-dNOPAUSE", "-dBATCH", "-sDEVICE=png16m", "-r150",
				"-sOutputFile=" + ProjectSettings.globalize_path(out.path_join("words_cff-gs-%d.png")), pdf]]]:
		var heard: Array = []
		var code: int = OS.execute(reader[1], reader[2], heard, true)
		var noise: String = "".join(heard).strip_edges()
		_check("%s draws it, saying nothing amiss (%s)" % [reader[0], noise.left(120) if not noise.is_empty()
			else "exit %d" % code], code == 0 and noise.is_empty())
	# The note's letters where Droid's are: the same page, each letter an em.
	var note: Array = [0, Rect2()]
	var counted: Array = [0]
	read = BookletRead.new()
	read.read_file(html, func(laid: BookletRead.Page) -> void:
		counted[0] += 1
		for op: Dictionary in laid.ops:
			if op["k"] == "text" and str(op["text"]) == NOTE:
				var size: float = op["size"]
				var at: Vector2 = op["at"]
				note[0] = counted[0]
				note[1] = Rect2(at.x, at.y - size, NOTE.length() * size, size * 1.3))
	var cff_ink: Rect2 = _ink(out.path_join("words_cff-pdf"), note[0], note[1])
	var droid_ink: Rect2 = _ink(out.path_join("words-pdf"), note[0], note[1])
	_check("the note's ink on page %d in the CFF face where Droid's is: %s against %s px at 150 dpi"
		% [note[0], str(cff_ink), str(droid_ink)], int(note[0]) > 0 and cff_ink.has_area()
		and absf(cff_ink.position.x - droid_ink.position.x) < 12.0 and absf(cff_ink.end.x - droid_ink.end.x) < 12.0
		and absf(cff_ink.position.y - droid_ink.position.y) < 12.0)


## Where the note's letters are on page [param number] of the pictures
## pdftoppm drew at 150 dpi as [param stem]-N.png: the box of the dark
## pixels inside [param box] (mm, where BookletRead lays the note), in
## pixels.
func _ink(stem: String, number: int, box: Rect2) -> Rect2:
	var image: Image = null
	for width: int in [1, 2, 3]:
		var path: String = ProjectSettings.globalize_path("%s-%s.png" % [stem, str(number).pad_zeros(width)])
		if FileAccess.file_exists(path):
			image = Image.load_from_file(path)
	if image == null:
		return Rect2()
	var per_mm: float = 150.0 / 25.4
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for y: int in range(roundi(box.position.y * per_mm), mini(image.get_height(), roundi(box.end.y * per_mm))):
		for x: int in range(roundi(box.position.x * per_mm), mini(image.get_width(), roundi(box.end.x * per_mm))):
			if image.get_pixel(x, y).get_luminance() < 0.5:
				low = low.min(Vector2(x, y))
				high = high.max(Vector2(x, y))
	return Rect2(low, high - low) if high.x >= low.x else Rect2()


## The commit before's castle booklet ([param against]) written again as
## a PDF from its own file: each page the same at 300 dots an inch to the
## pixel as its PDF, and the file no more than 10% bigger.
func _same_as_before(against: String, out: String) -> void:
	print("")
	print("a Latin booklet against the commit before's PDF of it (%s)" % against)
	var html: String = against.path_join("castle_instructions.html")
	var before: String = against.path_join("castle_instructions.pdf")
	if not _check("the commit before's booklet and its PDF are there", FileAccess.file_exists(html)
			and FileAccess.file_exists(before)):
		return
	var now: String = out.path_join("castle_again.pdf")
	var read := BookletRead.new()
	var writer := BookletPdf.new()
	writer.begin(now, read)
	var pages: int = await read.read_all(html, writer.page)
	writer.finish(read.title)
	# Each page drawn by poppler and hashed, pdftoppm run itself: OS.execute
	# asked for output goes through popen with every argument in double
	# quotes, so a bash -c script's $1 and $(...) were the outer shell's,
	# empty, and no page was hashed at all.
	var ppm: String = ProjectSettings.globalize_path(out.path_join("page-at300"))
	var differ: Array = []
	var hashed: int = 0
	for number: int in range(1, pages + 1):
		var sums: Array = []
		for pdf: String in [before, now]:
			DirAccess.remove_absolute(ppm + ".ppm")
			OS.execute("pdftoppm", ["-r", "300", "-f", str(number), "-l", str(number), "-singlefile",
				ProjectSettings.globalize_path(pdf), ppm])
			sums.append(FileAccess.get_sha256(ppm + ".ppm") if FileAccess.file_exists(ppm + ".ppm") else "")
		if sums[0] != "" and sums[1] != "":
			hashed += 1
		if sums[0] == "" or sums[0] != sums[1]:
			differ.append(number)
	DirAccess.remove_absolute(ppm + ".ppm")
	var pixels: int = 0
	for number: int in differ.slice(0, 2):
		for pdf: String in [before, now]:
			OS.execute("pdftoppm", ["-r", "300", "-f", str(number), "-l", str(number), "-singlefile", "-png",
				ProjectSettings.globalize_path(pdf), ProjectSettings.globalize_path(pdf.get_basename() + "-at300")])
		var a: Image = Image.load_from_file(ProjectSettings.globalize_path(before.get_basename() + "-at300.png"))
		var b: Image = Image.load_from_file(ProjectSettings.globalize_path(now.get_basename() + "-at300.png"))
		if a != null and b != null and a.get_size() == b.get_size():
			for y: int in a.get_height():
				for x: int in a.get_width():
					if a.get_pixel(x, y) != b.get_pixel(x, y):
						pixels += 1
	_check("each of its %d pages the same at 300 dots an inch to the pixel (%d drawn both ways, %d differ%s)" % [
		pages, hashed, differ.size(), (": pages %s, %d pixels on the first two" % [str(differ.slice(0, 8)),
		pixels]) if not differ.is_empty() else ""], pages > 0 and hashed == pages and differ.is_empty())
	var size_was: int = FileAccess.get_file_as_bytes(before).size()
	var size_now: int = FileAccess.get_file_as_bytes(now).size()
	_check("its file no more than 10%% bigger: %.1f KB against %.1f KB (%+.1f%%)" % [size_now / 1024.0,
		size_was / 1024.0, (size_now - size_was) * 100.0 / maxf(1.0, size_was)],
		size_was > 0 and size_now <= size_was * 1.10)


## Through the sign-in screen as a person: a throwaway account signed in,
## the screen gone.
func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("pdfcid")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


## Signed in with a password grant on an account the admin key made: the
## token bucket, not a code's verify, which is 1 per 10 s for every agent.
func _sign_in(account: Account, email: String) -> String:
	var password: String = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


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
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("  (removed %d throwaway account(s))" % gone)
	print("booklet_pdf_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
