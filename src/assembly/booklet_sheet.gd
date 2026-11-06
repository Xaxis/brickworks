## The booklet's page as its designer set it up (Build, Booklet page, Page
## setup…, or page_setup over MCP): its paper and which way up, its
## margins, its colour or a picture behind every page, and how big the step
## numbers and the parts boxes are drawn. Kept with the model (BookletLooks,
## the booklet's "sheet"), and saved by a name to give another model in a
## choice ([method styles]), as Studio's Page Setup and Global Style and
## StudWorx's page presets are.
##
## The booklet's own page is 269 x 199 mm on its side, which fits A4 and
## US Letter turned on their side with a margin to spare, so one file prints
## on both (Booklet). A person printing on A4 or Letter upright, or on A5,
## or sharing instructions in their own colours, sets it here; the booklet
## is laid out on that page, and its PDF's pages are that paper's size.
##
## In the file: "0 !BRICKWORKS PAGE_SETUP A4 PORTRAIT MARGIN 12 COLOUR
## #FFFFFF NUMBER 10 PARTS 1.25 PICTURE brickworks-page-behind.jpg", each
## part only when it is not the booklet's own, the picture as LDraw's
## embedded file beside the pictures its pages show (BookletLooks "|data").
class_name BookletSheet
extends RefCounted

## The papers, each on its side, in mm, and how it is said: as the paper is
## named, its short side first, the booklet's own as it is printed.
const PAPERS: Dictionary = {
	"booklet": [Vector2(269.0, 199.0), "Booklet, 269 x 199 mm"],
	"a4": [Vector2(297.0, 210.0), "A4, 210 x 297 mm"],
	"letter": [Vector2(279.4, 215.9), "US Letter, 8.5 x 11 in"],
	"a5": [Vector2(210.0, 148.0), "A5, 148 x 210 mm"],
}
## The longest side any paper has: where a place on a page is kept to.
const LONGEST := 297.0
## The booklet's own: its light blue page, the margin round it, its step
## number's height in mm.
const PAGE_COLOUR := Color8(220, 236, 248)
const MARGIN := 9.0
const NUMBER := 8.0
## What each may be set to.
const MARGIN_RANGE := Vector2(5.0, 30.0)
const NUMBER_RANGE := Vector2(4.0, 20.0)
const PARTS_RANGE := Vector2(0.5, 2.0)
## The name its picture is kept under in the model's file (BookletLooks
## IMAGE_PREFIX, so the file's other pictures' rules keep it).
const PICTURE_NAME := "brickworks-page-behind"
## The longest side, in pixels, a picture behind the pages is kept at:
## A4 at 120 dots an inch, a page's background and not its subject.
const PICTURE_MOST := 1400
## Where the named styles are kept, on this computer or in this browser.
const STYLES_FILE := "user://page_styles.cfg"

var paper: String = "booklet"
var portrait: bool = false
var margin: float = MARGIN
var colour: Color = PAGE_COLOUR
## The picture behind every page: its name among the model's pictures, ""
## for none, and its data URI, for the booklet's file.
var picture: String = ""
var picture_uri: String = ""
## The step number's height in mm, and the parts boxes' pictures' scale.
var number: float = NUMBER
var parts: float = 1.0


## The page, in mm, as it is printed.
func size() -> Vector2:
	var flat: Vector2 = (PAPERS.get(paper, PAPERS["booklet"]) as Array)[0]
	return Vector2(flat.y, flat.x) if portrait else flat


## How much bigger than the booklet's own a step number is drawn.
func number_scale() -> float:
	return number / NUMBER


## Whether this is the booklet's own page in every way.
func usual() -> bool:
	return said().is_empty()


## What a page is laid on: its colour, or nothing where a picture is behind
## it, which a step's picture must let show through.
func behind() -> Color:
	return Color(0, 0, 0, 0) if not picture_uri.is_empty() else colour


## As kept with the model: each field that is not the booklet's own.
func said() -> Dictionary:
	var out: Dictionary = {}
	if paper != "booklet":
		out["paper"] = paper
	if portrait:
		out["portrait"] = true
	if not is_equal_approx(margin, MARGIN):
		out["margin"] = margin
	if not colour.is_equal_approx(PAGE_COLOUR):
		out["colour"] = "#" + colour.to_html(false)
	if not picture.is_empty():
		out["picture"] = picture
	if not is_equal_approx(number, NUMBER):
		out["number"] = number
	if not is_equal_approx(parts, 1.0):
		out["parts"] = parts
	return out


## A page set up as [param kept] says ([method said]'s fields, or a session's:
## size a paper's name, orientation "portrait" or "landscape"), each checked
## and kept in range; a field it does not have is the booklet's own.
static func from(kept: Dictionary) -> BookletSheet:
	var out := BookletSheet.new()
	out.change(kept)
	return out


## Each field [param fields] has set, checked; what it does not have kept.
## Returns what was wrong with any, "" when nothing was.
func change(fields: Dictionary) -> String:
	var wrong := PackedStringArray()
	for field: String in fields:
		var value: Variant = fields[field]
		match field:
			"paper", "size":
				var named: String = paper_of(str(value))
				if named.is_empty():
					wrong.append("size= is %s" % ", ".join(PAPERS.keys().map(
						func(key: String) -> String: return "\"%s\"" % key)))
				else:
					paper = named
			"portrait":
				portrait = bool(value)
			"orientation":
				if str(value).to_lower() in ["portrait", "landscape"]:
					portrait = str(value).to_lower() == "portrait"
				else:
					wrong.append("orientation= is \"portrait\" or \"landscape\"")
			"margin", "margins":
				if _number(value):
					margin = snappedf(clampf(float(value), MARGIN_RANGE.x, MARGIN_RANGE.y), 0.1)
				else:
					wrong.append("margin= is mm, %d to %d" % [MARGIN_RANGE.x, MARGIN_RANGE.y])
			"colour", "color":
				var text: String = str(value).strip_edges()
				if text.is_empty() or text == "usual":
					colour = PAGE_COLOUR
				elif Color.html_is_valid(text):
					colour = Color.html(text)
					colour.a = 1.0
				else:
					wrong.append("colour= is a colour like \"#ffffff\", or \"usual\"")
			"picture":
				picture = str(value).strip_edges().to_lower() if value != null else ""
				if picture.is_empty():
					picture_uri = ""
			"number":
				if _number(value):
					number = snappedf(clampf(float(value), NUMBER_RANGE.x, NUMBER_RANGE.y), 0.1)
				else:
					wrong.append("number= is the step number's height in mm, %d to %d"
						% [NUMBER_RANGE.x, NUMBER_RANGE.y])
			"parts":
				if _number(value):
					parts = snappedf(clampf(float(value), PARTS_RANGE.x, PARTS_RANGE.y), 0.05)
				else:
					wrong.append("parts= is how big the parts boxes' pictures are, %s to %s"
						% [PARTS_RANGE.x, PARTS_RANGE.y])
	return "; ".join(wrong)


static func _number(value: Variant) -> bool:
	return value is float or value is int or (value is String and str(value).is_valid_float())


## A paper's key from how a person or a session says it ("A4", "US
## Letter", "letter", "booklet"), "" when it is none of them.
static func paper_of(said: String) -> String:
	var key: String = said.strip_edges().to_lower().replace("us ", "").replace(" ", "")
	if key in ["own", "usual", "brickworks"]:
		key = "booklet"
	return key if PAPERS.has(key) else ""


## The model's page, as its designer set it up: the booklet's own when
## they have not, its picture's data URI from the model's pictures.
static func of(world: BrickWorld) -> BookletSheet:
	var kept: Variant = BookletLooks.booklet(world).get("sheet", {})
	var out: BookletSheet = from(kept if kept is Dictionary else {})
	if not out.picture.is_empty():
		var bytes: String = str(BookletLooks.images(world).get(out.picture, ""))
		out.picture_uri = picture_uri_of(out.picture, bytes) if not bytes.is_empty() else ""
		if out.picture_uri.is_empty():
			out.picture = ""
	return out


static func picture_uri_of(name: String, base64: String) -> String:
	return "data:%s;base64,%s" % ["image/png" if name.ends_with(".png") else "image/jpeg", base64]


## [param image] as a picture behind the pages is kept: no longer than
## [constant PICTURE_MOST] pixels; a JPEG, or a PNG where it lets something
## show through. [name, base64].
static func picture_of(image: Image) -> Array:
	var longest: int = maxi(image.get_width(), image.get_height())
	if longest > PICTURE_MOST:
		var k: float = float(PICTURE_MOST) / float(longest)
		image.resize(maxi(1, roundi(image.get_width() * k)), maxi(1, roundi(image.get_height() * k)),
			Image.INTERPOLATE_LANCZOS)
	var clear: bool = image.detect_alpha() != Image.ALPHA_NONE
	var bytes: PackedByteArray = image.save_png_to_buffer() if clear \
		else image.save_jpg_to_buffer(0.86)
	return ["%s.%s" % [PICTURE_NAME, "png" if clear else "jpg"], Marshalls.raw_to_base64(bytes)]


## The words of its file's line, after "0 !BRICKWORKS PAGE_SETUP": "" for
## the booklet's own page.
func line_words() -> String:
	var words := PackedStringArray()
	if paper != "booklet" or portrait:
		words.append(paper.to_upper())
		words.append("PORTRAIT" if portrait else "LANDSCAPE")
	if not is_equal_approx(margin, MARGIN):
		words.append("MARGIN %s" % BookletLooks._number(margin))
	if not colour.is_equal_approx(PAGE_COLOUR):
		words.append("COLOUR #%s" % colour.to_html(false).to_upper())
	if not is_equal_approx(number, NUMBER):
		words.append("NUMBER %s" % BookletLooks._number(number))
	if not is_equal_approx(parts, 1.0):
		words.append("PARTS %s" % BookletLooks._number(parts))
	if not picture.is_empty():
		words.append("PICTURE %s" % picture)
	return " ".join(words)


## The page its file's line says ([param words], after PAGE_SETUP), as
## [method said] keeps it.
static func read_words(words: PackedStringArray) -> Dictionary:
	var out := BookletSheet.new()
	var at: int = 0
	while at < words.size():
		var word: String = words[at].to_upper()
		var next: String = words[at + 1] if at + 1 < words.size() else ""
		if not paper_of(word).is_empty():
			out.paper = paper_of(word)
		elif word in ["PORTRAIT", "LANDSCAPE"]:
			out.portrait = word == "PORTRAIT"
		elif word in ["MARGIN", "COLOUR", "NUMBER", "PARTS", "PICTURE"] and not next.is_empty():
			out.change({word.to_lower(): next})
			at += 1
		at += 1
	return out.said()


## How it reads, for a person and a session: "A4 upright, margins 12 mm, a
## white page, step numbers 10 mm".
func words() -> String:
	var out := PackedStringArray()
	out.append("%s %s, %s x %s mm" % [{"booklet": "the booklet's own page", "a4": "A4",
		"letter": "US Letter", "a5": "A5"}[paper], "upright" if portrait else "on its side",
		BookletLooks._number(size().x), BookletLooks._number(size().y)])
	out.append("margins %s mm" % BookletLooks._number(margin))
	out.append(("a picture behind every page" if not picture.is_empty()
		else "page colour #%s" % colour.to_html(false)))
	out.append("step numbers %s mm" % BookletLooks._number(number))
	if not is_equal_approx(parts, 1.0):
		out.append("parts boxes' pictures at %sx" % BookletLooks._number(parts))
	return ", ".join(out)


# -- styles: a page set up, kept by a name for another model ---------------


## The styles kept, by name: {name: {said fields, "picture_data": base64
## (with "picture" its name) when it has a picture}}.
static func styles() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(STYLES_FILE) != OK:
		return {}
	var out: Dictionary = {}
	for name: String in file.get_sections():
		var kept: Variant = file.get_value(name, "style", {})
		if kept is Dictionary:
			out[name] = kept
	return out


## [param sheet] kept as the style [param name], its picture's bytes
## [param picture_data] with it (base64) so another model can have it too.
## Returns what went wrong, "" when it was kept.
static func save_style(name: String, sheet: BookletSheet, picture_data: String) -> String:
	name = name.strip_edges()
	if name.is_empty():
		return "a style needs a name"
	var file := ConfigFile.new()
	file.load(STYLES_FILE)
	var kept: Dictionary = sheet.said()
	if not sheet.picture.is_empty() and not picture_data.is_empty():
		kept["picture_data"] = picture_data
	else:
		kept.erase("picture")
	file.set_value(name, "style", kept)
	return "" if file.save(STYLES_FILE) == OK else "the style could not be kept"


static func forget_style(name: String) -> void:
	var file := ConfigFile.new()
	if file.load(STYLES_FILE) == OK and file.has_section(name):
		file.erase_section(name)
		file.save(STYLES_FILE)
