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
## And the booklet the designer's way, as Studio's and LPub3D's are
## (booklook): a cover of their own, its title, a line under it, a picture
## of the model or of their own and a line of their words; words of theirs
## at the head and the foot of every page; the parts box's frame, fill and
## corners, the step number's colour, and the colour round the new parts.
##
## In the file: "0 !BRICKWORKS PAGE_SETUP A4 PORTRAIT MARGIN 12 COLOUR
## #FFFFFF NUMBER 10 PARTS 1.25 PICTURE brickworks-page-behind.jpg", each
## part only when it is not the booklet's own, the picture as LDraw's
## embedded file beside the pictures its pages show (BookletLooks "|data");
## then "BOX_FRAME #C0392B BOX_FILL #FFF4D6 BOX_CORNERS 4 NUMBER_COLOUR
## #1E7B34 OUTLINE_COLOUR #7B2CBF COVER_PICTURE brickworks-page-cover.jpg"
## on it, and each of the person's words on a line of its own, as typed:
## "0 !BRICKWORKS PAGE_TEXT TITLE The Gatehouse", SUBTITLE, COVER_LINE,
## HEADER and FOOTER. A build before these reads none of them and is not
## misled by any: its PAGE_SETUP's words are none of theirs, and PAGE_TEXT
## is a line it passes over.
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
## Pixels a millimetre of paper: the finest the booklet draws its steps'
## pictures (BookletMaker.px_per_mm, 127 dots an inch; fewer on the web and
## in a long booklet). A picture behind the pages covers the page
## (Booklet: background-size cover, centred), and is kept at this over the
## largest page either way up, whatever paper it is chosen on, since the
## paper can be changed after and the picture it came from is gone: its
## shorter side [constant LONGEST] mm at this. Up to 2026-11-06 every one
## was kept 1400 px long, 3.5 px a mm on an upright A4 page; for a day it
## was kept for the paper it was chosen on (ps2review).
const PX_PER_MM := 5.0
## A picture that lets something show through is a PNG, which for a
## photograph is many times a JPEG's bytes, in every autosave of the model
## and its file: one over this many bytes is made smaller, a step at a
## time, down to [constant SEE_THROUGH_LEAST] px on its longest side, the
## most a picture on a page is kept at (PageEditor.add_image). Up to
## 2026-11-06 one could be 5 MB of the file (psreview).
const SEE_THROUGH_BYTES := 1024 * 1024
const SEE_THROUGH_LEAST := 900
## Where the named styles are kept, on this computer or in this browser: a
## small file each, and each picture once, by what it is, beside them. One
## file for them all (up to 2026-11-06) was written whole by every keep, so
## two tabs keeping a style each wrote the other's away, a file that could
## not be read was written over, and every Page setup… read every picture.
const STYLES_DIR := "user://page_styles"
const STYLE_PICTURES := "user://page_styles/pictures"
## That one file: read where it is until a style is next kept or taken
## away, which moves its styles into [constant STYLES_DIR] and takes it
## away; never written, and left as it is when it cannot be read. Only
## looking (Page setup…'s list, page_setup with nothing asked) changes
## nothing: up to 2026-11-07 it moved them (ps2review).
const STYLES_FILE := "user://page_styles.cfg"
## A file on its way: written under its name and [constant PART] until it is
## whole, so no window reads half of it; a picture no style seemed to show,
## moved aside under its name and [constant ASIDE] while the styles are read
## again ([method _drop_unshown_pictures]). Either left by a window that
## stopped halfway is dealt with [constant LEFT_S] seconds on.
const PART := ".part"
const ASIDE := ".aside"
const LEFT_S := 3600

## booklook: the cover's picture of the person's own, by its name among the
## model's pictures (BookletLooks IMAGE_PREFIX, kept as the one behind the
## pages is).
const COVER_NAME := "brickworks-page-cover"
## The booklet's own parts box (Booklet's stylesheet --box-line, --box and
## the .box's corners, in mm), its step number's ink, and the band of
## orange round the new parts (booklet_ink's new_colour, 1.0 0.52 0.06).
const BOX_FRAME := Color8(61, 111, 151)
const BOX_FILL := Color8(188, 218, 241)
const BOX_CORNERS := 2.2
const CORNERS_RANGE := Vector2(0.0, 8.0)
const NUMBER_COLOUR := Color8(21, 25, 30)
const OUTLINE_COLOUR := Color8(255, 133, 15)
## The colours a person may give, each with the booklet's own.
const COLOURS: Dictionary = {"box_frame": BOX_FRAME, "box_fill": BOX_FILL,
	"number_colour": NUMBER_COLOUR, "outline_colour": OUTLINE_COLOUR}
## The words a person may give: the cover's title (the model's name when
## none), the line under it, the line of their words on the cover, and the
## words at the head and the foot of every page. One line each, of at most
## [constant TEXT_MOST] letters.
const TEXTS: Array[String] = ["title", "subtitle", "cover_line", "header", "footer"]
const TEXT_MOST := 120

var paper: String = "booklet"
var portrait: bool = false
var margin: float = MARGIN
var colour: Color = PAGE_COLOUR
## The picture behind every page: its name among the model's pictures, ""
## for none, and its data URI, for the booklet's file.
var picture: String = ""
var picture_uri: String = ""
## Its file names a picture behind the pages that it does not carry
## ([method of]).
var missing: bool = false
## The step number's height in mm, and the parts boxes' pictures' scale.
var number: float = NUMBER
var parts: float = 1.0
## booklook: the person's words ([constant TEXTS]), "" where they gave none.
var title: String = ""
var subtitle: String = ""
var cover_line: String = ""
var header: String = ""
var footer: String = ""
## The cover's picture of their own: its name among the model's pictures,
## "" for the model drawn as the booklet draws it; its data URI; and its
## file naming one it does not carry, as [member missing] says of the one
## behind the pages.
var cover_picture: String = ""
var cover_uri: String = ""
var cover_missing: bool = false
var box_frame: Color = BOX_FRAME
var box_fill: Color = BOX_FILL
var box_corners: float = BOX_CORNERS
var number_colour: Color = NUMBER_COLOUR
var outline_colour: Color = OUTLINE_COLOUR


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
	for field: String in TEXTS:
		if not str(get(field)).is_empty():
			out[field] = str(get(field))
	if not cover_picture.is_empty():
		out["cover_picture"] = cover_picture
	for field: String in COLOURS:
		if not same_colour(get(field), COLOURS[field]):
			out[field] = "#" + (get(field) as Color).to_html(false)
	if not is_equal_approx(box_corners, BOX_CORNERS):
		out["box_corners"] = box_corners
	return out


## Whether the cover is the person's own: a title, a line or a picture of
## theirs on it. The booklet's own cover has its BRICKWORKS badge, which
## theirs does not (Booklet._cover).
func own_cover() -> bool:
	return not (title + subtitle + cover_line + cover_picture).is_empty()


## Whether two colours are one, as a file's #RRGGBB says them.
static func same_colour(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.5 / 255.0 and absf(a.g - b.g) < 0.5 / 255.0 \
		and absf(a.b - b.b) < 0.5 / 255.0


## The step number's colour as a page's style says it: "" for the booklet's
## own ink.
func number_style() -> String:
	return "" if same_colour(number_colour, NUMBER_COLOUR) else "color:#" + number_colour.to_html(false)


## The pictures a page set up as [param kept] ([method said]'s) shows, by
## their names among the model's pictures: the one behind the pages and the
## cover's.
static func pictures_named(kept: Variant) -> Array[String]:
	var out: Array[String] = []
	if kept is Dictionary:
		for field: String in ["picture", "cover_picture"]:
			if not str((kept as Dictionary).get(field, "")).is_empty():
				out.append(str(kept[field]))
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
			"title", "subtitle", "cover_line", "header", "footer":
				set(field, one_line(value))
			"cover_picture":
				cover_picture = str(value).strip_edges().to_lower() if value != null else ""
				if cover_picture.is_empty():
					cover_uri = ""
			"box_frame", "box_fill", "number_colour", "outline_colour", "number_color", \
					"outline_color":
				var key: String = field.replace("_color", "_colour")
				var text: String = str(value).strip_edges() if value != null else ""
				if text.is_empty() or text == "usual":
					set(key, COLOURS[key])
				elif Color.html_is_valid(text):
					var given: Color = Color.html(text)
					given.a = 1.0
					set(key, given)
				else:
					wrong.append("%s= is a colour like \"#ffffff\", or \"usual\"" % key)
			"box_corners":
				if _number(value):
					box_corners = snappedf(clampf(float(value), CORNERS_RANGE.x, CORNERS_RANGE.y), 0.1)
				else:
					wrong.append("box_corners= is how round the parts box's corners are, in mm, %d to %d"
						% [CORNERS_RANGE.x, CORNERS_RANGE.y])
	return "; ".join(wrong)


## [param value] as a line of a person's words: one line, as typed but for
## its breaks and tabs (each a space) and the spaces round it, and no longer
## than [constant TEXT_MOST].
static func one_line(value: Variant) -> String:
	if value == null:
		return ""
	var text: String = RegEx.create_from_string("[\\x{00}-\\x{1f}\\x{7f}]").sub(str(value), " ", true)
	return text.strip_edges().left(TEXT_MOST).strip_edges()


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
## they have not, its picture's data URI from the model's pictures. A
## picture its file names and does not carry (another program saved it
## without it, or it was not a PNG or a JPEG: BookletLooks.kept_pictures)
## keeps its name, so the page says so and a save keeps saying it, and is
## drawn as the page's colour ([member missing]). Up to 2026-11-06 it was
## dropped in silence and the page was plain colour.
static func of(world: BrickWorld) -> BookletSheet:
	var kept: Variant = BookletLooks.booklet(world).get("sheet", {})
	var out: BookletSheet = from(kept if kept is Dictionary else {})
	if not out.picture.is_empty():
		var bytes: String = str(BookletLooks.images(world).get(out.picture, ""))
		out.picture_uri = picture_uri_of(out.picture, bytes) if not bytes.is_empty() else ""
		out.missing = out.picture_uri.is_empty()
	if not out.cover_picture.is_empty():
		var bytes: String = str(BookletLooks.images(world).get(out.cover_picture, ""))
		out.cover_uri = picture_uri_of(out.cover_picture, bytes) if not bytes.is_empty() else ""
		out.cover_missing = out.cover_uri.is_empty()
	return out


static func picture_uri_of(name: String, base64: String) -> String:
	return "data:%s;base64,%s" % ["image/png" if name.ends_with(".png") else "image/jpeg", base64]


## [param image] as a picture behind the pages is kept: as sharp as the
## largest page draws it at [constant PX_PER_MM], never made bigger, and
## its long side no more than the widest page shows of it; a JPEG, or a PNG
## where it lets something show through, that one no more than [constant
## SEE_THROUGH_BYTES] unless it is down to [constant SEE_THROUGH_LEAST] px.
## [name, base64].
static func picture_of(image: Image) -> Array:
	var k: float = minf(1.0, LONGEST * PX_PER_MM / minf(image.get_width(), image.get_height()))
	if k < 1.0:
		image.resize(maxi(1, roundi(image.get_width() * k)), maxi(1, roundi(image.get_height() * k)),
			Image.INTERPOLATE_LANCZOS)
	# Covering a page from its middle, a picture longer for its width than
	# the widest page is for its own shows only that much of its middle on
	# any page: past the most that can be, a panorama's far ends, which are
	# in no booklet, are cut rather than the whole made smaller (up to
	# 2026-11-07 a 16000 x 1000 one was 1888 KB in the file, ps2review).
	var widest: float = 1.0
	for kind: Array in PAPERS.values():
		widest = maxf(widest, (kind[0] as Vector2).x / (kind[0] as Vector2).y)
	var size := Vector2i(image.get_width(), image.get_height())
	if maxi(size.x, size.y) > ceili(widest * LONGEST * PX_PER_MM):
		var shown := Vector2i(mini(size.x, ceili(size.y * widest)), mini(size.y, ceili(size.x * widest)))
		image = image.get_region(Rect2i((size - shown) / 2, shown))
	return _kept(image, PICTURE_NAME)


## [param image] as the cover's picture of the person's own is kept: shown
## whole on the cover, so its longest side no more than the longest page
## shows at [constant PX_PER_MM], never made bigger; a JPEG, or a PNG where
## it lets something show through, as [method picture_of] keeps one.
## [name, base64].
static func cover_of(image: Image) -> Array:
	var k: float = minf(1.0, LONGEST * PX_PER_MM / maxf(image.get_width(), image.get_height()))
	if k < 1.0:
		image.resize(maxi(1, roundi(image.get_width() * k)), maxi(1, roundi(image.get_height() * k)),
			Image.INTERPOLATE_LANCZOS)
	return _kept(image, COVER_NAME)


## [param image] under [param name]: a JPEG, or a PNG no more than
## [constant SEE_THROUGH_BYTES] unless it is down to [constant
## SEE_THROUGH_LEAST] px where it lets something show through.
static func _kept(image: Image, name: String) -> Array:
	if image.detect_alpha() == Image.ALPHA_NONE:
		return ["%s.jpg" % name, Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.86))]
	var bytes: PackedByteArray = image.save_png_to_buffer()
	while bytes.size() > SEE_THROUGH_BYTES and maxi(image.get_width(), image.get_height()) > SEE_THROUGH_LEAST:
		var longest: int = maxi(image.get_width(), image.get_height())
		var step: float = maxf(0.8, float(SEE_THROUGH_LEAST) / float(longest))
		image.resize(maxi(1, roundi(image.get_width() * step)), maxi(1, roundi(image.get_height() * step)),
			Image.INTERPOLATE_LANCZOS)
		bytes = image.save_png_to_buffer()
	return ["%s.png" % name, Marshalls.raw_to_base64(bytes)]


## How a picture behind the pages, [param base64], is kept, in words: "a
## JPEG, 412 KB in the file", its bytes there as LDraw's !DATA writes them
## (base64 in lines of 76 behind "0 !: ").
static func picture_words(base64: String) -> String:
	return "%s, %d KB in the file" % ["a PNG" if BookletLooks.picture_kind(base64) == "png"
		else "a JPEG", picture_kb(base64)]


static func picture_kb(base64: String) -> int:
	return maxi(1, roundi((base64.length() + ceili(base64.length() / 76.0) * 6) / 1024.0))


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
	for field: String in COLOURS:
		if not same_colour(get(field), COLOURS[field]):
			words.append("%s #%s" % [field.to_upper(), (get(field) as Color).to_html(false).to_upper()])
	if not is_equal_approx(box_corners, BOX_CORNERS):
		words.append("BOX_CORNERS %s" % BookletLooks._number(box_corners))
	if not cover_picture.is_empty():
		words.append("COVER_PICTURE %s" % cover_picture)
	return " ".join(words)


## The person's words as their file's lines say them, each after "0
## !BRICKWORKS PAGE_TEXT": ["TITLE The Gatehouse", "FOOTER © 2026 A.
## Builder"], none for none.
func text_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for field: String in TEXTS:
		if not str(get(field)).is_empty():
			out.append("%s %s" % [field.to_upper(), str(get(field))])
	return out


## The page its file's line says ([param words], after PAGE_SETUP), as
## [method said] keeps it.
static func read_words(words: PackedStringArray) -> Dictionary:
	var out := BookletSheet.new()
	out._read_words(words)
	return out.said()


## The page [param kept] says ([method said]'s), with what a line of its
## file says: [param kind] PAGE_SETUP, its [param words] after that; or
## PAGE_TEXT, its first word which of the person's words it is and [param
## rest] the words themselves, as written. Its lines may come in any order.
static func read_line(kind: String, words: PackedStringArray, rest: String,
		kept: Variant) -> Dictionary:
	var out: BookletSheet = from(kept if kept is Dictionary else {})
	if kind == "PAGE_TEXT":
		if not words.is_empty() and words[0].to_lower() in TEXTS:
			out.change({words[0].to_lower(): rest})
	else:
		out._read_words(words)
	return out.said()


func _read_words(words: PackedStringArray) -> void:
	var at: int = 0
	var named: Array = ["MARGIN", "COLOUR", "NUMBER", "PARTS", "PICTURE", "BOX_CORNERS",
		"COVER_PICTURE"] + COLOURS.keys().map(func(field: String) -> String: return field.to_upper())
	while at < words.size():
		var word: String = words[at].to_upper()
		var next: String = words[at + 1] if at + 1 < words.size() else ""
		if not paper_of(word).is_empty():
			paper = paper_of(word)
		elif word in ["PORTRAIT", "LANDSCAPE"]:
			portrait = word == "PORTRAIT"
		elif word in named and not next.is_empty():
			change({word.to_lower(): next})
			at += 1
		at += 1


## How it reads, for a person and a session: "A4 upright, margins 12 mm, a
## white page, step numbers 10 mm".
func words() -> String:
	var out := PackedStringArray()
	out.append("%s %s, %s x %s mm" % [{"booklet": "the booklet's own page", "a4": "A4",
		"letter": "US Letter", "a5": "A5"}[paper], "upright" if portrait else "on its side",
		BookletLooks._number(size().x), BookletLooks._number(size().y)])
	out.append("margins %s mm" % BookletLooks._number(margin))
	if missing:
		out.append("page colour #%s, the picture behind every page (%s) missing from the file"
			% [colour.to_html(false), picture])
	elif not picture_uri.is_empty():
		out.append("a picture behind every page (%s)" % picture_words(
			picture_uri.substr(picture_uri.find(",") + 1)))
	elif not picture.is_empty():
		out.append("a picture behind every page")
	else:
		out.append("page colour #%s" % colour.to_html(false))
	out.append("step numbers %s mm" % BookletLooks._number(number))
	if not is_equal_approx(parts, 1.0):
		out.append("parts boxes' pictures at %sx" % BookletLooks._number(parts))
	# booklook: what the designer made their own.
	if own_cover():
		var cover := PackedStringArray()
		if not title.is_empty():
			cover.append("titled “%s”" % title)
		if not subtitle.is_empty():
			cover.append("“%s” under it" % subtitle)
		if cover_missing:
			cover.append("its picture (%s) missing from the file" % cover_picture)
		elif not cover_uri.is_empty():
			cover.append("their own picture (%s)" % picture_words(cover_uri.substr(cover_uri.find(",") + 1)))
		elif not cover_picture.is_empty():
			cover.append("their own picture")
		if not cover_line.is_empty():
			cover.append("the line “%s”" % cover_line)
		out.append("a cover of their own, %s" % ", ".join(cover))
	if not header.is_empty():
		out.append("“%s” at the head of every page" % header)
	if not footer.is_empty():
		out.append("“%s” at the foot of every page" % footer)
	var box := PackedStringArray()
	if not same_colour(box_frame, BOX_FRAME):
		box.append("framed #%s" % box_frame.to_html(false))
	if not same_colour(box_fill, BOX_FILL):
		box.append("filled #%s" % box_fill.to_html(false))
	if not is_equal_approx(box_corners, BOX_CORNERS):
		box.append("corners %s mm" % BookletLooks._number(box_corners))
	if not box.is_empty():
		out.append("parts boxes %s" % " and ".join(box))
	if not same_colour(number_colour, NUMBER_COLOUR):
		out.append("step numbers in #%s" % number_colour.to_html(false))
	if not same_colour(outline_colour, OUTLINE_COLOUR):
		out.append("new parts outlined in #%s" % outline_colour.to_html(false))
	return ", ".join(out)


# -- styles: a page set up, kept by a name for another model ---------------


## The styles kept, by name: {name: said fields, with "picture" its
## picture's name when it has one}. Each read from its own small file, and
## those the one file kept before read from it where it is; nothing is
## written. The pictures stay where they are until one is given
## ([method style]).
static func styles() -> Dictionary:
	var out: Dictionary = {}
	var old: Variant = _old_styles()
	for name: String in (old as Dictionary if old is Dictionary else {}):
		out[name] = (old[name][0] as Dictionary).duplicate()
	for record: Dictionary in _style_records():
		out[str(record["name"])] = (record["page"] as Dictionary).duplicate()
	return out


## The style [param name] as it is given to a model: its said fields, and
## with a picture its bytes as "picture_data" (base64); "picture_lost" true
## when its picture could not be read; the cover's picture the same, as
## "cover_picture_data" and "cover_lost". {} when there is no such style.
## Nothing is written.
static func style(name: String) -> Dictionary:
	var record: Variant = _read_style(_style_path(name))
	if not record is Dictionary:
		var old: Variant = _old_styles()
		if not old is Dictionary or not (old as Dictionary).has(name.strip_edges()):
			return {}
		var kept: Array = old[name.strip_edges()]
		var page: Dictionary = (kept[0] as Dictionary).duplicate()
		if not str(kept[1]).is_empty():
			page["picture_data"] = kept[1]
		return page
	var out: Dictionary = (record["page"] as Dictionary).duplicate()
	for kept: Array in [["picture_file", "picture_data", "picture_lost"],
			["cover_file", "cover_picture_data", "cover_lost"]]:
		var picture_file: String = str(record.get(kept[0], ""))
		if picture_file.is_empty():
			continue
		var bytes: PackedByteArray = _picture_bytes(picture_file)
		if bytes.is_empty():
			out[kept[2]] = true
		else:
			out[kept[1]] = Marshalls.raw_to_base64(bytes)
	return out


## [param sheet] kept as the style [param name], its picture's bytes
## [param picture_data] with it (base64) so another model can have it too:
## one small file for the style, the picture once beside the others by
## what it is, so styles sharing a picture keep it once. A style of that
## name already kept is replaced, and its picture taken away when no style
## shows it now. The cover's picture of the person's own, [param
## cover_data], the same. Returns what went wrong, "" when kept.
static func save_style(name: String, sheet: BookletSheet, picture_data: String,
		cover_data: String = "") -> String:
	name = name.strip_edges()
	if name.is_empty():
		return "a style needs a name"
	_move_old_styles()
	var failed: String = _write_style(name, sheet.said(), picture_data if not sheet.picture.is_empty() else "",
		cover_data if not sheet.cover_picture.is_empty() else "")
	_drop_unshown_pictures()
	return failed


## The style [param name] taken away, and any picture no other style shows.
## Returns what went wrong, "" when it is gone.
static func remove_style(name: String) -> String:
	_move_old_styles()
	var path: String = _style_path(name)
	if not FileAccess.file_exists(path):
		return "no page style is called \"%s\"" % name
	if DirAccess.remove_absolute(path) != OK:
		return "the page style \"%s\" could not be removed" % name
	_drop_unshown_pictures()
	return ""


## Where the style [param name] is kept: by its name's hash, which any name
## a person types makes a file name of.
static func _style_path(name: String) -> String:
	return STYLES_DIR.path_join(name.strip_edges().sha256_text().left(24) + ".json")


static func _read_style(path: String) -> Variant:
	var text: PackedByteArray = _bytes_of(path)
	if text.is_empty() and not FileAccess.file_exists(path):
		# Never there, or taken away by another window as it was listed.
		return null
	var record: Variant = JSON.parse_string(text.get_string_from_utf8())
	if not record is Dictionary or not (record as Dictionary).get("name") is String \
			or not (record as Dictionary).get("page") is Dictionary \
			or not (record as Dictionary).get("picture_file", "") is String \
			or not (record as Dictionary).get("cover_file", "") is String:
		push_warning("a page style could not be read: %s" % path)
		return null
	return record


## Every style's record that can be read; [param unread] counts those that
## cannot.
static func _style_records(unread: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(STYLES_DIR):
		return out
	for file_name: String in DirAccess.get_files_at(STYLES_DIR):
		if not file_name.ends_with(".json"):
			continue
		var record: Variant = _read_style(STYLES_DIR.path_join(file_name))
		if record is Dictionary:
			out.append(record)
		else:
			unread.append(file_name)
	return out


## The style written, its picture first and written whole every time it
## is kept, so a style never names a picture that is not there and a
## browser's other tab, taking it away, sees it is in use again (shell.html
## stores what a tab changed). Then the picture written again if it has
## gone since: another window taking away the pictures no style shows may
## have read the styles before this one was there.
static func _write_style(name: String, page: Dictionary, picture_data: String,
		cover_data: String = "") -> String:
	DirAccess.make_dir_recursive_absolute(STYLE_PICTURES)
	var record: Dictionary = {"name": name, "page": page.duplicate()}
	## [path, bytes] of each picture written.
	var written: Array = []
	# The one behind the pages, and the cover's (booklook).
	for kept: Array in [["picture_file", "picture", picture_data],
			["cover_file", "cover_picture", cover_data]]:
		var data: String = kept[2]
		if data.is_empty() or BookletLooks.picture_kind(data).is_empty():
			(record["page"] as Dictionary).erase(kept[1])
			continue
		var picture_file: String = "%s.%s" % [data.sha256_text().left(32),
			"png" if BookletLooks.picture_kind(data) == "png" else "jpg"]
		var path: String = STYLE_PICTURES.path_join(picture_file)
		var bytes: PackedByteArray = Marshalls.base64_to_raw(data)
		if not _write_whole(path, bytes):
			return "the style's picture could not be kept"
		record[kept[0]] = picture_file
		written.append([path, bytes])
	if not _write_whole(_style_path(name), (JSON.stringify(record, "\t") + "\n").to_utf8_buffer()):
		return "the style could not be kept"
	for picture: Array in written:
		if not FileAccess.file_exists(str(picture[0])) and not _write_whole(str(picture[0]), picture[1]):
			return "the style's picture could not be kept"
	return ""


## [param bytes] at [param path], written under a name of their own until
## they are all there.
static func _write_whole(path: String, bytes: PackedByteArray) -> bool:
	var part: String = _passing(path, PART)
	var file: FileAccess = FileAccess.open(part, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	if DirAccess.rename_absolute(part, path) != OK:
		DirAccess.remove_absolute(part)
		return false
	TabSession.writing(path)
	return true


## [param path] with [param ending], when and a number of its own between:
## a name for it on its way ([constant PART], [constant ASIDE]).
static func _passing(path: String, ending: String) -> String:
	return "%s.%d-%d%s" % [path, int(Time.get_unix_time_from_system()), randi() % 1000000, ending]


## How many seconds ago [param file_name], a name [method _passing] made,
## was made.
static func _passing_age(file_name: String) -> int:
	return int(Time.get_unix_time_from_system()) \
		- int(file_name.get_basename().get_extension().get_slice("-", 0))


## A kept picture's bytes: from beside the styles, or, while a window
## taking away the pictures no style shows has it moved aside, from there.
## Empty when it is gone.
static func _picture_bytes(picture_file: String) -> PackedByteArray:
	# Twice: moved aside as it was opened, or put back as it was looked for.
	for _look: int in 2:
		var bytes: PackedByteArray = _bytes_of(STYLE_PICTURES.path_join(picture_file))
		if not bytes.is_empty():
			return bytes
		for file_name: String in DirAccess.get_files_at(STYLE_PICTURES) \
				if DirAccess.dir_exists_absolute(STYLE_PICTURES) else PackedStringArray():
			if file_name.ends_with(ASIDE) and file_name.get_basename().get_basename() == picture_file:
				bytes = _bytes_of(STYLE_PICTURES.path_join(file_name))
				if not bytes.is_empty():
					return bytes
	return PackedByteArray()


## A file's bytes, empty when it is not there (gone as it was looked for).
static func _bytes_of(path: String) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


## The pictures the styles show, by file name; null while any style cannot
## be read, whose picture it may be.
static func _shown_pictures() -> Variant:
	var unread: Array = []
	var shown: Dictionary = {}
	for record: Dictionary in _style_records(unread):
		shown[str(record.get("picture_file", ""))] = true
		shown[str(record.get("cover_file", ""))] = true
	return shown if unread.is_empty() else null


## The pictures no style shows, taken away. Another window may be keeping
## a style on one at that moment, its style not written yet; so each is
## moved aside first, where that window's keep finds it gone and writes it
## again ([method _write_style]) and [method style] still reads it, the
## styles are read again, and each one shows now put back. Up to
## 2026-11-07 a style kept in one window as another took a style away lost
## its picture, 896 times in 3000 (ps2review).
static func _drop_unshown_pictures() -> void:
	var shown: Variant = _shown_pictures()
	if shown == null or not DirAccess.dir_exists_absolute(STYLE_PICTURES):
		return
	var aside: Dictionary = {}
	for file_name: String in DirAccess.get_files_at(STYLE_PICTURES):
		var path: String = STYLE_PICTURES.path_join(file_name)
		if file_name.ends_with(PART) or file_name.ends_with(ASIDE):
			# Left by a window that stopped halfway: never a whole picture,
			# or one moved aside and not put back.
			if _passing_age(file_name) > LEFT_S:
				if file_name.ends_with(PART):
					DirAccess.remove_absolute(path)
				else:
					aside[path] = file_name.get_basename().get_basename()
		elif not (shown as Dictionary).has(file_name):
			var moved: String = _passing(path, ASIDE)
			if DirAccess.rename_absolute(path, moved) == OK:
				aside[moved] = file_name
	if aside.is_empty():
		return
	shown = _shown_pictures()
	for moved: String in aside:
		var path: String = STYLE_PICTURES.path_join(str(aside[moved]))
		if shown != null and not (shown as Dictionary).has(str(aside[moved])):
			DirAccess.remove_absolute(moved)
		elif FileAccess.file_exists(path):
			# Written again by the window keeping it: the same bytes.
			DirAccess.remove_absolute(moved)
		else:
			DirAccess.rename_absolute(moved, path)


## The styles the one file kept before, by name, that no file of their own
## has replaced since: {name: [said fields, its picture's base64 or ""]}.
## Read where it is, nothing written; {} when there is no such file, null
## when it cannot be read.
static func _old_styles() -> Variant:
	if not FileAccess.file_exists(STYLES_FILE):
		return {}
	var file := ConfigFile.new()
	if file.load(STYLES_FILE) != OK:
		if not FileAccess.file_exists(STYLES_FILE):
			return {}  # Moved by another window as it was read.
		push_warning("the page styles kept in %s could not be read; it is left as it is" % STYLES_FILE)
		return null
	var out: Dictionary = {}
	for name: String in file.get_sections():
		var kept: Variant = file.get_value(name, "style", {})
		if not kept is Dictionary or FileAccess.file_exists(_style_path(name)):
			continue
		var page: Dictionary = (kept as Dictionary).duplicate()
		var picture_data: String = str(page.get("picture_data", ""))
		page.erase("picture_data")
		page = from(page).said()
		if BookletLooks.picture_kind(picture_data).is_empty():
			picture_data = ""
			page.erase("picture")
		out[name] = [page, picture_data]
	return out


## The styles the one file kept before (up to 2026-11-06), each moved into
## a file of its own, and the old file taken away once all of them are:
## done as a style is next kept or taken away, never by looking. Left as it
## is when it cannot be read: never written over.
static func _move_old_styles() -> void:
	var old: Variant = _old_styles()
	if not old is Dictionary or not FileAccess.file_exists(STYLES_FILE):
		return
	var moved: bool = true
	for name: String in old:
		if not _write_style(name, old[name][0], old[name][1]).is_empty() \
				or not _read_style(_style_path(name)) is Dictionary:
			moved = false
	if moved:
		DirAccess.remove_absolute(STYLES_FILE)
