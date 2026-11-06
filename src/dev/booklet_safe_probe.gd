## A model file's words and pictures never put script into a booklet.
##
##   godot --headless --path . --script src/dev/booklet_safe_probe.gd
##
## A booklet is HTML, and on the web it is written into a tab of the
## site's own, with its storage and its sign-in. Its words and pictures
## come from the model's file, which anyone may have made and shared. A
## page's picture went into its HTML as the file had it (src="..."), so
## data that was not base64 could break out of the attribute (2026-11-06,
## psreview). Checked here, headless, with strings made to break out of
## each place the booklet writes a file's or a person's text: the edge
## (BookletLooks.read keeps a picture only when it is a PNG or a JPEG in
## base64), each sink escaped for where it goes, and the policy the
## booklet carries first, which runs nothing but its own Print and Save.
## The crafted strings set a harmless flag; none of them is run here.
extends SceneTree

## Out of a double-quoted attribute, and a tag of its own.
const OUT_OF_QUOTES := "\" onerror=\"window.__booksafe=1\" x=\""
const A_TAG := "<img src=x onerror=window.__booksafe=1>"
## Out of a style's url(), and out of the style element.
const OUT_OF_URL := "x);}</style><img src=x onerror=window.__booksafe=1><style>{"
const OUT_OF_STYLE := "red;background:url(x)\"><img src=x onerror=window.__booksafe=1>"

var _failures: int = 0


func _initialize() -> void:
	var png: String = _picture(true)
	var jpeg: String = _picture(false)
	_kinds(png, jpeg)
	_read(png, jpeg)
	_written(png)
	print("%d failed" % _failures if _failures else "booklet safe: all passed")
	quit(1 if _failures else 0)


func _picture(clear: bool) -> String:
	var image := Image.create(8, 6, false, Image.FORMAT_RGBA8 if clear else Image.FORMAT_RGB8)
	image.fill(Color(0.8, 0.2, 0.1, 0.5 if clear else 1.0))
	return Marshalls.raw_to_base64(image.save_png_to_buffer() if clear
		else image.save_jpg_to_buffer(0.8))


## The edge: what a picture from a file is.
func _kinds(png: String, jpeg: String) -> void:
	print("\n  what a page's picture is")
	_check("a PNG in base64 is a png", BookletLooks.picture_kind(png) == "png")
	_check("a JPEG in base64 is a jpeg", BookletLooks.picture_kind(jpeg) == "jpeg")
	var webp: String = Marshalls.raw_to_base64(Image.create(4, 4, false, Image.FORMAT_RGB8)
		.save_webp_to_buffer())
	for bad: Array in [["a PNG with an attribute after it", png + OUT_OF_QUOTES],
			["a PNG with a tag after it", png + A_TAG],
			["a PNG with a space in it", png.substr(0, 8) + " " + png.substr(8)],
			["a PNG cut short of a whole quad", png.substr(0, png.length() - 1)],
			["the breakout alone", OUT_OF_QUOTES],
			["base64 of words, not a picture", Marshalls.utf8_to_base64("not a picture at all")],
			["a WebP, which pages do not take from a file", webp],
			["nothing", ""]]:
		_check("%s is no picture" % bad[0], BookletLooks.picture_kind(bad[1]).is_empty())
	var kept: Dictionary = BookletLooks.kept_pictures({"a.png": png, "b.png": png + A_TAG,
		"c.jpg": jpeg})
	_check("kept_pictures keeps the PNG and the JPEG, not the other (%s)" % [kept.keys()],
		kept.keys() == ["a.png", "c.jpg"])


## A crafted file read: the good picture kept, the others left out, the
## rest of the file read as before.
func _read(png: String, jpeg: String) -> void:
	print("\n  a file whose pictures break out, read")
	var lines := PackedStringArray(["0 Crafted", "0 Name: crafted.ldr", "0 Author: someone",
		"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"0 !BRICKWORKS IMAGE 10 10 40 30 brickworks-page-1.png",
		"0 !BRICKWORKS IMAGE 60 10 40 30 brickworks-page-2.png",
		"0 !BRICKWORKS IMAGE 110 10 40 30 brickworks-page-3.jpg",
		"0 !BRICKWORKS TEXT 10 60 80 10 4 " + A_TAG,
		"0 STEP"])
	for named: Array in [["brickworks-page-1.png", png], ["brickworks-page-2.png", png + OUT_OF_QUOTES],
			["brickworks-page-3.jpg", jpeg]]:
		lines.append("0 !DATA " + named[0])
		var data: String = named[1]
		for at: int in range(0, data.length(), 76):
			lines.append("0 !: " + data.substr(at, 76))
	var looks: Dictionary = BookletLooks.read("\n".join(lines), {}, "crafted.ldr")
	var pictures: Dictionary = looks.get(BookletLooks.DATA, {})
	_check("the PNG and the JPEG kept (%s)" % [pictures.keys()],
		pictures.keys() == ["brickworks-page-1.png", "brickworks-page-3.jpg"])
	_check("each kept as the file had it", str(pictures.get("brickworks-page-1.png", "")) == png
		and str(pictures.get("brickworks-page-3.jpg", "")) == jpeg)
	var notes: Array = []
	for name: String in looks:
		if looks[name] is Dictionary:
			notes.append_array((looks[name] as Dictionary).get("notes", []))
	_check("the rest read as before: three pictures' places and the words (%d notes)" % notes.size(),
		notes.size() == 4)


## The sinks: every place the booklet writes a file's or a person's text,
## given strings made to break out of it.
func _written(png: String) -> void:
	print("\n  a booklet written with them")
	var document := Booklet.Document.new()
	document.title = A_TAG
	document.credits = A_TAG
	var lot := Booklet.Lot.new()
	lot.key = "3001:4"
	lot.part_id = "3001" + OUT_OF_QUOTES
	lot.name = A_TAG
	lot.colour = OUT_OF_QUOTES
	lot.element = A_TAG
	lot.count = 1
	lot.size = Vector2(10, 8)
	document.lots.append(lot)
	document.parts[lot.key] = "data:image/png;base64," + png + OUT_OF_URL
	var plain := Booklet.Lot.new()
	plain.key = "3003:1"
	plain.part_id = "3003"
	plain.name = "Brick 2 x 2"
	plain.colour = "Blue"
	plain.count = 2
	document.lots.append(plain)
	document.parts[plain.key] = "data:image/png;base64," + png
	document.images["good.png"] = "data:image/png;base64," + png
	document.images["bad.png"] = "data:image/png;base64," + png + OUT_OF_QUOTES
	var page := Booklet.Page.new()
	page.number = 2
	page.banner = A_TAG
	var entry := Booklet.Entry.new()
	entry.number = 1
	entry.rect = Rect2(20, 20, 120, 90)
	entry.image = "data:image/png;base64," + png + OUT_OF_QUOTES
	entry.note = A_TAG
	entry.marks = [{"label": A_TAG, "name": A_TAG, "rgb": OUT_OF_STYLE}]
	entry.colours = [{"name": A_TAG, "rgb": OUT_OF_STYLE}]
	entry.notes = [{"image": "good.png", "at": [10, 10, 40, 30]},
		{"image": "bad.png", "at": [60, 10, 40, 30]},
		{"text": A_TAG, "at": [10, 60, 80, 10]}]
	page.entries.append(entry)
	document.pages.append(page)
	document.pages.append_array(Booklet.parts_pages(document.lots, 3))
	var written: String = Booklet.html(document)

	_check("the policy is the first thing after the charset", written.begins_with(
		"<!doctype html>\n<html lang=\"en\">\n<meta charset=\"utf-8\">\n"
		+ "<meta http-equiv=\"Content-Security-Policy\" content=\"" + Booklet.policy() + "\">"))
	var policy: String = Booklet.policy()
	_check("...which allows no script but the booklet's own, by its hash (%s)" % policy,
		policy.contains("default-src 'none'") and policy.contains("script-src 'sha256-")
		and not policy.contains("script-src 'unsafe")
		and policy.contains("img-src data:") and policy.contains("base-uri 'none'"))
	_check("...whose hash is its script's", policy.contains(
		Marshalls.raw_to_base64(Booklet.SAVE_JS.sha256_buffer())))
	_check("one script, the booklet's own", written.count("<script") == 1
		and written.contains(Booklet.SAVE_SCRIPT))
	_check("no inline handler: Print has its click from the script",
		not written.contains("onclick=") and not written.contains("onerror=\""))
	_check("no tag of the file's: each said as words", not written.contains("<img src=x")
		and written.count("&lt;img src=x onerror=window.__booksafe=1&gt;") >= 7)
	_check("no attribute broken out of", not written.contains(OUT_OF_QUOTES)
		and not written.contains("\" x=\""))
	_check("no style broken out of", not written.contains("url(x)")
		and not written.contains("</style><img") and written.count("</style>") == 1)
	_check("the colours that were not colours drawn grey",
		written.contains("background:#888888\"></i>") and not written.contains("red;background"))
	_check("the good picture shown, as it was given", written.contains(
		"src=\"data:image/png;base64,%s\" alt=\"A picture of the designer's\"" % png))
	_check("the step's and the page's pictures that broke out left out",
		written.count("<img ") == 1)
	_check("the part's picture whose address broke out left out of the stylesheet",
		not written.contains(".p0{background-image"))
	_check("...and the good one's kept", written.contains(
		".p1{background-image:url(data:image/png;base64,%s)}" % png))


func _check(what: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1
