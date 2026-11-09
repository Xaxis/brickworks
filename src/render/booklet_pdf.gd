## A booklet saved as a PDF, written here a page at a time, with no
## browser and no library: what Studio's Instruction Maker saves.
##
## A booklet became a PDF only by printing its page from a browser, which
## a person had to know to do, and which turned anything not a JPEG into a
## picture many times its size (BookletMaker._data_uri). Here each page is
## what BookletRead reads off the booklet's own page: the step pictures
## are the booklet's own JPEGs, in the file as they are (DCTDecode); a
## part's picture is in the file once, however many pages show it; and
## the boxes, arrows and words are drawn as PDF draws them, so a step
## number or a part's element number is words a reader can find and copy,
## sharp at any size. Words or a picture its designer turned are turned
## about the same middle (cm), and faded ones drawn as faint (an ExtGState's
## /ca), as the browser draws them. The words are set in Liberation Sans, which has
## Helvetica's widths letter for letter (the widths the booklet lays its
## words out by, BookletRead), and the type itself is in the file, cut
## down to the letters the pages use (PdfType), so every reader draws the
## same letters whether it has Helvetica or not, in Cyrillic and Greek as
## in Latin. A letter it has none of (Japanese, say) is set in the type
## the booklet's page draws it in, the system's own (BookletPng), carried
## the same way, and an emoji in Noto Emoji, which the app carries for it
## in outline (the page's are in colour, which no PDF type holds); only a
## letter no type here has is "?", and named.
##
## Each line is shaped by the engine's text server as the page's is
## (TextServer: the Unicode bidi algorithm, then each run's glyphs), set
## left to right as the booklet's page sets every line: so Hebrew and
## Arabic print right to left, Arabic's letters joined in the forms they
## take beside each other, and an emoji made of several (a ZWJ sequence)
## as its one glyph. Those glyphs are what the line shows, each where the
## shaping puts it, and each reads back (the ToUnicode map) as the letters
## it stands for, so a reader finds the words as typed; up to 2026-11-09
## each letter was its own glyph in the order typed, and a Hebrew step name
## printed backwards (snreview). A line drawn one glyph a letter, left to
## right (Latin, Greek, Cyrillic, Japanese), is written as it was before,
## a letter at a time at the type's own widths.
## The page is the booklet's, 269 x 199 mm, which fits A4 and US Letter
## turned on their side (Booklet), or the paper its designer set it up on
## (BookletSheet), the PDF's page that paper's size; a picture behind the
## page is in the file once, and a step's picture over it keeps what it
## lets show through (an SMask).
##
## Written as it goes, into its file or (on the web) into memory to be
## downloaded: each page's pictures and words, then the page; and at the
## end the list of pages and where each object is.
class_name BookletPdf
extends RefCounted

## Points (a PDF's unit) to a millimetre.
const PT := 72.0 / 25.4

var pages: int = 0
## Bytes written so far.
var size: int = 0
var _file: FileAccess = null
var _bytes := PackedByteArray()
var _offsets: Dictionary = {}
var _next: int = 5
var _kids := PackedStringArray()
## A part's picture's object by its class and the colour it is laid on.
var _parts: Dictionary = {}
## The picture behind the pages, made the first time a page has it:
## [object number, size in pixels].
var _behind: Array = []
var _read: BookletRead
var _ok: bool = true
## The letters no type here can print ("?" in the PDF), each once, in the
## order met: said by the export ([method missed_said]), not left as "?" in
## silence (blreview, 2026-11-07). Since pdfcid (2026-11-08) these are only
## letters neither the app's type nor the system's has: an emoji, or
## Japanese on the web, which has no system type to read.
var missed: PackedStringArray = []
## The most of them [method missed_said] names.
const MISSED_NAMED := 16
## The emoji's face: Noto Emoji 3.000 at its regular weight (SIL Open
## Font License 1.1, assets/fonts/NotoEmoji-OFL.txt), in outline, which a
## PDF can carry as it carries the type.
const EMOJI := "res://assets/fonts/NotoEmoji-Regular.ttf"
## The size a line is shaped at, in pixels. The faces it is shaped in are
## placed to a 64th of a pixel and not hinted, so a glyph's place comes
## back to 1/4096 of the words' size, the type's own measure and not a
## screen's; and a glyph shaped is drawn into the engine's cache at it,
## which a size near a PDF's own thousand made 40 ms a line.
const SHAPED_AT := 64

const _CATALOG := 1
const _PAGES := 2
const _FONT := 3
const _BOLD := 4

## The type, regular and bold: its file (SIL Open Font License 1.1,
## assets/fonts/OFL.txt) and its PostScript name.
const TYPE: Array = [["res://assets/fonts/LiberationSans-Regular.ttf", "LiberationSans"],
	["res://assets/fonts/LiberationSans-Bold.ttf", "LiberationSans-Bold"]]
## WinAnsi's codes above 127 that are not Latin-1's, by their character:
## the reader's own Helvetica's, where the type cannot be read.
const MORE := {0x20AC: 0x80, 0x2026: 0x85, 0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93,
	0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97, 0x2122: 0x99}

## The type, regular and bold, read (PdfType); null where it could not be,
## and its words then go to the reader's Helvetica.
var _types: Array = [null, null]
## The app's fonts of that type, to ask which system type draws a letter
## they have none of, as the booklet's page draws it.
var _faces: Array = [null, null]
## The system's faces the words needed: [PdfType, its name on a page, its
## object] each, by "path#face"; [] for a file that could not be used.
var _system_faces: Dictionary = {}
## The system's faces by the font Godot falls back to (its family, weight,
## stretch, style and face): [PdfType, name, object], or [].
var _system_fonts: Dictionary = {}
## The system's faces the page being written uses: name -> object.
var _page_fonts: Dictionary = {}
## The faces each line is shaped in ([method _shaper]): the type, regular
## and bold, then the emoji's; and their engine's RIDs, to know a glyph's.
var _shapers: Array = [null, null, null]
var _shaper_rids: Array = [[], [], []]
## Each line as shaped ([method _shape]), by its weight and words.
var _lines: Dictionary = {}


## Start a PDF going to [param path], or into memory when it is "" (take
## it with [method finish]). False when the file cannot be written.
func begin(path: String, read: BookletRead) -> bool:
	_read = read
	if not path.is_empty():
		_file = FileAccess.open(path, FileAccess.WRITE)
		if _file == null:
			return false
	_put(PackedByteArray([37, 80, 68, 70, 45, 49, 46, 52, 10, 37, 226, 227, 207, 211, 10]))
	for which: int in 2:
		_faces[which] = load(str(TYPE[which][0])) as FontFile
		_types[which] = _font(_FONT + which, TYPE[which])
		_shapers[which] = _shaper(_faces[which], true)
	_shapers[2] = _shaper(load(EMOJI) as FontFile, false)
	for which: int in 3:
		if _shapers[which] != null:
			_shaper_rids[which] = (_shapers[which] as FontFile).get_rids()
	return true


## A face of [param source]'s own to shape lines in: not hinted and placed
## to a 64th of a pixel ([constant SHAPED_AT]), the system's faces the
## engine falls back to taking the same from it where [param fallback]
## (the emoji's has none: it is asked alone). Null without a source.
static func _shaper(source: FontFile, fallback: bool) -> FontFile:
	if source == null or source.data.is_empty():
		return null
	var made := FontFile.new()
	made.data = source.data
	made.hinting = TextServer.HINTING_NONE
	made.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
	made.allow_system_fallback = fallback
	return made


## The type [param type] ([file, name]) for font [param number], read to
## be written at the end with the glyphs the pages used (PdfType). A file
## the app cannot read falls back to the reader's own Helvetica, as the PDF
## was before, and says so: null then.
func _font(number: int, type: Array) -> PdfType:
	var source: FontFile = _faces[number - _FONT]
	var read: PdfType = PdfType.read(source.data) if source != null else null
	if read == null:
		push_error("BookletPdf: %s cannot be read; the PDF's words are left to the reader's Helvetica"
			% type[0])
		_object(number, "<< /Type /Font /Subtype /Type1 /BaseFont /%s /Encoding /WinAnsiEncoding >>"
			% ("Helvetica-Bold" if number == _BOLD else "Helvetica"))
		return null
	read.name = str(type[1])
	return read


## Type [param type] written as font [param number]: a Type0 font whose
## glyphs are its own (CIDFontType2, or CIDFontType0 for CFF), named by
## their numbers in it (Identity-H), holding only those used, with a
## ToUnicode map so a reader finds and copies the words as typed.
func _write_type(number: int, type: PdfType) -> void:
	var named: String = type.subset_name()
	var program: PackedByteArray = type.program()
	var file: int = _new()
	_stream(file, ("/Subtype /CIDFontType0C" if type.cff else "/Length1 %d" % program.size())
		+ " /Filter /FlateDecode", program.compress(FileAccess.COMPRESSION_DEFLATE))
	var metrics: Dictionary = type.metrics()
	var box: Array = metrics["box"]
	var descriptor: int = _new()
	_object(descriptor, ("<< /Type /FontDescriptor /FontName /%s /Flags 4 /FontBBox [%d %d %d %d] "
		+ "/ItalicAngle 0 /Ascent %d /Descent %d /CapHeight %d /StemV %d /%s %d 0 R >>") % [
		named, box[0], box[1], box[2], box[3], metrics["ascent"], metrics["descent"], metrics["cap"],
		140 if type.weight >= 600 else 80, "FontFile3" if type.cff else "FontFile2", file])
	var glyphs: int = _new()
	_object(glyphs, ("<< /Type /Font /Subtype /%s /BaseFont /%s /CIDSystemInfo << /Registry (Adobe) "
		+ "/Ordering (Identity) /Supplement 0 >> /FontDescriptor %d 0 R /DW 1000 /W [%s]%s >>") % [
		"CIDFontType0" if type.cff else "CIDFontType2", named, descriptor, type.widths(),
		"" if type.cff else " /CIDToGIDMap /Identity"])
	var unicode: int = _new()
	_stream(unicode, "/Filter /FlateDecode", type.to_unicode().compress(FileAccess.COMPRESSION_DEFLATE))
	_object(number, ("<< /Type /Font /Subtype /Type0 /BaseFont /%s /Encoding /Identity-H "
		+ "/DescendantFonts [%d 0 R] /ToUnicode %d 0 R >>") % [named, glyphs, unicode])


## Letter [param code] in the type, bold or not: [the font's name on the
## page, its bytes in the words]; [] when the type has none of it and it
## draws something (_other). A space it has none of is its space, and a
## letter that draws nothing at all (a joiner, a variation selector) is
## nothing, as the page draws them. Where the type cannot be read, the
## reader's Helvetica's WinAnsi byte.
func _own(code: int, bold: bool) -> Array:
	var own: String = "F2" if bold else "F1"
	var type: PdfType = _types[1 if bold else 0]
	if type == null:
		var byte: PackedByteArray = win_ansi(char(code))
		if byte[0] == 0x3F and code != 0x3F:
			_miss(code)
		return [own, byte]
	if _unseen(code):
		return [own, PackedByteArray()]
	var glyph: int = type.glyph_of(code)
	var blank: bool = _blank(code)
	if glyph > 0 and (blank or type.drawn(glyph)):
		type.use(glyph, code)
		return [own, _code(glyph)]
	if blank:
		glyph = type.glyph_of(0x20)
		type.use(glyph, 0x20)
		return [own, _code(glyph)]
	return []


## Letter [param code], which the type has none of, in [param found], the
## system's face Godot draws it in on the page ([PdfType, name, object]
## or []): or "?" in the type, named ([member missed]).
func _other(code: int, bold: bool, found: Array) -> Array:
	if not found.is_empty():
		var face: PdfType = found[0]
		var glyph: int = face.glyph_of(code)
		if glyph > 0 and face.drawn(glyph):
			face.use(glyph, code)
			_page_fonts[found[1]] = found[2]
			return [found[1], _code(glyph)]
	_miss(code)
	var type: PdfType = _types[1 if bold else 0]
	var mark: int = type.glyph_of(0x3F)
	type.use(mark, 0x3F)
	return ["F2" if bold else "F1", _code(mark)]


## [param text] shaped in [param fonts] at [param size] as a line of the
## booklet's page is: left to right, as its page sets every line (it says
## no direction), the bidi algorithm turning a run of Hebrew or Arabic
## about. Its glyphs, left to right (TextServer.shaped_text_get_glyphs).
static func shaped(text: String, fonts: Array, size: int) -> Array:
	var server: TextServer = TextServerManager.get_primary_interface()
	var line: RID = server.create_shaped_text(TextServer.DIRECTION_LTR)
	var rids: Array[RID] = []
	rids.assign(fonts)
	server.shaped_text_add_string(line, text, rids, size)
	var glyphs: Array = server.shaped_text_get_glyphs(line)
	server.free_rid(line)
	return glyphs


## Whether [param glyphs] are one a letter, in the letters' order, left to
## right: what setting a letter at a time draws.
static func plain(glyphs: Array) -> bool:
	var last: int = -1
	for glyph: Dictionary in glyphs:
		var start: int = glyph["start"]
		if int(glyph["flags"]) & TextServer.GRAPHEME_IS_RTL or int(glyph["end"]) - start != 1 or start <= last:
			return false
		last = start
	return true


## [param text] shaped in the type, bold or not, and the emoji's face and
## the system's after it, as the page shapes it (BookletPng): its glyphs
## left to right, each with its "face" ([PdfType, name, object], or []
## where none here can go in the PDF). Where the engine took an emoji from
## a colour face, which a PDF cannot carry, its cluster is shaped again in
## the emoji's own. Each line once a PDF.
func _shape(text: String, bold: bool) -> Array:
	var key: String = ("b" if bold else "r") + text
	if _lines.has(key):
		return _lines[key]
	var which: int = 1 if bold else 0
	var out: Array = []
	if _shapers[which] == null:
		_lines[key] = out
		return out
	var fonts: Array = (_shaper_rids[which] as Array) + (_shaper_rids[2] as Array)
	var glyphs: Array = shaped(text, fonts, SHAPED_AT)
	var at: int = 0
	while at < glyphs.size():
		var cluster: Array = [glyphs[at]]
		while at + cluster.size() < glyphs.size() and _same_cluster(glyphs[at + cluster.size()], glyphs[at]):
			cluster.append(glyphs[at + cluster.size()])
		at += cluster.size()
		var lacking: bool = false
		for glyph: Dictionary in cluster:
			glyph["face"] = _face(glyph, bold)
			lacking = lacking or (glyph["face"] as Array).is_empty()
		if lacking and _shapers[2] != null and _draws(text, cluster):
			cluster = _in_emoji(text, cluster)
		out.append_array(cluster)
	_lines[key] = out
	return out


## Whether [param cluster]'s letters draw anything (not only spaces and
## joiners).
static func _draws(text: String, cluster: Array) -> bool:
	for at: int in range(int(cluster[0]["start"]), int(cluster[0]["end"])):
		var code: int = text.unicode_at(at)
		if not _unseen(code) and not _blank(code):
			return true
	return false


static func _same_cluster(one: Dictionary, other: Dictionary) -> bool:
	return int(one["start"]) == int(other["start"]) and int(one["end"]) == int(other["end"])


## [param cluster]'s letters shaped again in the emoji's face alone: its
## glyphs in their places, faced, or [param cluster] as it was where that
## face lacks one of them.
func _in_emoji(text: String, cluster: Array) -> Array:
	var start: int = cluster[0]["start"]
	var again: Array = shaped(text.substr(start, int(cluster[0]["end"]) - start), _shaper_rids[2], SHAPED_AT)
	if again.is_empty():
		return cluster
	for glyph: Dictionary in again:
		if int(glyph["index"]) == 0 or not (_shaper_rids[2] as Array).has(glyph["font_rid"]):
			return cluster
		glyph["start"] = int(glyph["start"]) + start
		glyph["end"] = int(glyph["end"]) + start
		glyph["face"] = _emoji_face()
		if (glyph["face"] as Array).is_empty():
			return cluster
	return again


## The face [param glyph] is in, as the PDF carries it: [PdfType, name on
## a page, object], or [] where it is in none (no face has its letter) or in
## one no PDF can carry (a colour emoji's, a face the system will not let
## be cut down).
func _face(glyph: Dictionary, bold: bool) -> Array:
	var by: RID = glyph["font_rid"]
	if int(glyph["index"]) == 0 or not by.is_valid():
		return []
	var which: int = 1 if bold else 0
	if (_shaper_rids[which] as Array).has(by):
		return [_types[which], "F2" if bold else "F1", _BOLD if bold else _FONT] \
			if _types[which] != null else []
	if (_shaper_rids[2] as Array).has(by):
		return _emoji_face()
	if OS.has_feature("web"):
		return []
	var server: TextServer = TextServerManager.get_primary_interface()
	var family: String = server.font_get_name(by)
	var key: String = "%s %d %d %d %d" % [family, server.font_get_weight(by), server.font_get_stretch(by),
		server.font_get_style(by), server.font_get_face_index(by)]
	if not _system_fonts.has(key):
		_system_fonts[key] = _system_face(OS.get_system_font_path(family, server.font_get_weight(by),
			server.font_get_stretch(by), server.font_get_style(by) & TextServer.FONT_ITALIC != 0),
			server.font_get_face_index(by), family)
	return _system_fonts[key]


## The emoji's face in the PDF, read the first time a page has an emoji:
## [PdfType, name, object], or [] when it cannot be read.
func _emoji_face() -> Array:
	if not _system_faces.has(EMOJI):
		_system_faces[EMOJI] = []
		var type: PdfType = PdfType.read((_shapers[2] as FontFile).data)
		if type != null:
			_system_faces[EMOJI] = _named(type)
	return _system_faces[EMOJI]


## [param type] given its name on a page, after the faces before it, and
## its object.
func _named(type: PdfType) -> Array:
	return [type, "F%d" % (3 + _system_faces.values().filter(
		func(entry: Array) -> bool: return not entry.is_empty()).size()), _new()]


## The face [param face] of the system's font file [param path], the one
## of family [param family] where the file holds several: [PdfType, name,
## object], or [].
func _system_face(path: String, face: int, family: String) -> Array:
	var key: String = "%s#%d" % [path, face]
	if _system_faces.has(key):
		return _system_faces[key]
	_system_faces[key] = []
	if path.is_empty() or not FileAccess.file_exists(path):
		return []
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var type: PdfType = PdfType.read(bytes, face)
	if type == null or not type.families.has(family):
		for other: int in PdfType.faces(bytes):
			var named: PdfType = PdfType.read(bytes, other)
			if named != null and named.families.has(family):
				type = named
				break
	if type == null:
		return []
	_system_faces[key] = _named(type)
	return _system_faces[key]


## A letter no page shows, nor a reader reads: a joiner, a direction
## mark, a variation selector, a soft hyphen.
static func _unseen(code: int) -> bool:
	return code == 0xAD or code >= 0x200B and code <= 0x200F or code >= 0x2060 and code <= 0x2064 \
		or code >= 0xFE00 and code <= 0xFE0F or code == 0xFEFF or code >= 0xE0100 and code <= 0xE01EF


## Whether [param letters] are some and all unseen ([method _unseen]).
static func _unseen_all(letters: String) -> bool:
	for at: int in letters.length():
		if not _unseen(letters.unicode_at(at)):
			return false
	return not letters.is_empty()


## A letter that draws nothing: a space, a break, a control.
static func _blank(code: int) -> bool:
	return code <= 0x20 or code >= 0x7F and code <= 0xA0 or code == 0x1680 \
		or code >= 0x2000 and code <= 0x200A or code == 0x2028 or code == 0x2029 \
		or code == 0x202F or code == 0x205F or code == 0x3000


func _miss(code: int) -> void:
	var letter: String = char(code)
	if not letter.strip_edges().is_empty() and not missed.has(letter):
		missed.append(letter)


## A glyph's number as the words give it: two bytes (Identity-H).
static func _code(glyph: int) -> PackedByteArray:
	return PackedByteArray([glyph >> 8, glyph & 0xFF])


## One page of the booklet, as read (BookletRead.feed).
func page(drawn: BookletRead.Page) -> void:
	var content := PackedStringArray()
	_page_fonts.clear()
	content.append("%s 0 0 %s 0 %s cm 1 J 1 j" % [_n(PT), _n(-PT), _n(drawn.size.y * PT)])
	var images := PackedStringArray()
	var faded: Dictionary = {}
	for op: Dictionary in drawn.ops:
		var how: String = _how(op, faded)
		if not how.is_empty():
			content.append("q " + how)
		match op["k"]:
			"rect":
				_rect(content, op)
			"text":
				_text(content, op)
			"path":
				_path(content, op)
			"image":
				var placed: Array = _image(op)
				if placed.is_empty():
					continue
				var at: Rect2 = placed[1]
				images.append("/I%d %d 0 R" % [placed[0], placed[0]])
				content.append("q %s 0 0 %s %s %s cm /I%d Do Q" % [_n(at.size.x), _n(-at.size.y),
					_n(at.position.x), _n(at.end.y), placed[0]])
		if not how.is_empty():
			content.append("Q")
	var stream: PackedByteArray = "\n".join(content).to_ascii_buffer()
	var squeezed: PackedByteArray = stream.compress(FileAccess.COMPRESSION_DEFLATE)
	var contents: int = _new()
	_stream(contents, "/Filter /FlateDecode", squeezed)
	var number: int = _new()
	_object(number, ("<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %s %s] /Contents %d 0 R "
		+ "/Resources << /Font << /F1 %d 0 R /F2 %d 0 R%s >> /XObject << %s >>%s >> >>") % [
		_PAGES, _n(drawn.size.x * PT), _n(drawn.size.y * PT), contents, _FONT, _BOLD,
		"".join(PackedStringArray(_page_fonts.keys().map(func(named: String) -> String:
			return " /%s %d 0 R" % [named, _page_fonts[named]]))),
		" ".join(_unique(images)), (" /ExtGState << %s >>" % " ".join(faded.values()))
			if not faded.is_empty() else ""])
	_kids.append("%d 0 R" % number)
	pages += 1


## What [param op] is drawn under beyond the page's own: faded (a graphics
## state of [param faded], name -> its dictionary, made the first time a
## page fades that much) and turned about its pivot. "" for neither.
static func _how(op: Dictionary, faded: Dictionary) -> String:
	var how := PackedStringArray()
	if op.has("alpha"):
		var percent: int = roundi(float(op["alpha"]) * 100.0)
		faded["A%d" % percent] = "/A%d << /ca %s /CA %s >>" % [percent, _n(percent / 100.0),
			_n(percent / 100.0)]
		how.append("/A%d gs" % percent)
	if op.has("turn") and op.has("pivot"):
		# Clockwise on the page, which runs downward: what the browser's
		# rotate() turns by.
		var angle: float = deg_to_rad(float(op["turn"]))
		var pivot: Vector2 = op["pivot"]
		var turned: Vector2 = pivot - pivot.rotated(angle)
		how.append("%s %s %s %s %s %s cm" % [_n(cos(angle)), _n(sin(angle)), _n(-sin(angle)),
			_n(cos(angle)), _n(turned.x), _n(turned.y)])
	return " ".join(how)


## The end of the file: its pages, its title, and where each object is.
## Returns the file in memory when it was written there; empty when it was
## written to a file, or could not be (see [method ok]).
func finish(title: String) -> PackedByteArray:
	for which: int in 2:
		if _types[which] != null:
			_write_type(_FONT + which, _types[which])
	var written: Dictionary = {}
	for found: Array in _system_faces.values():
		if not found.is_empty() and not written.has(found[2]):
			written[found[2]] = true
			_write_type(found[2], found[0])
	_object(_PAGES, "<< /Type /Pages /Count %d /Kids [%s] >>" % [pages, " ".join(_kids)])
	_object(_CATALOG, "<< /Type /Catalog /Pages %d 0 R >>" % _PAGES)
	var info: int = _new()
	_object(info, "<< /Title <%s> /Producer (Brickworks) /Creator (Brickworks) >>" % _utf16(title))
	var at: int = size
	var table := PackedStringArray(["xref", "0 %d" % _next, "0000000000 65535 f "])
	for number: int in range(1, _next):
		table.append("%010d 00000 n " % int(_offsets.get(number, 0)))
	table.append("trailer")
	table.append("<< /Size %d /Root %d 0 R /Info %d 0 R >>" % [_next, _CATALOG, info])
	table.append("startxref")
	table.append(str(at))
	table.append("%%EOF\n")
	_put("\n".join(table).to_ascii_buffer())
	if _file != null:
		_ok = _ok and _file.get_error() == OK
		_file.close()
		_file = null
		return PackedByteArray()
	return _bytes


## Whether everything went into the file.
func ok() -> bool:
	return _ok


func _new() -> int:
	_next += 1
	return _next - 1


func _put(bytes: PackedByteArray) -> void:
	if _file != null:
		_ok = _file.store_buffer(bytes) and _ok
	else:
		_bytes.append_array(bytes)
	size += bytes.size()


func _object(number: int, body: String) -> void:
	_offsets[number] = size
	_put(("%d 0 obj\n%s\nendobj\n" % [number, body]).to_ascii_buffer())


func _stream(number: int, dictionary: String, data: PackedByteArray) -> void:
	_offsets[number] = size
	_put(("%d 0 obj\n<< %s /Length %d >>\nstream\n" % [number, dictionary, data.size()]).to_ascii_buffer())
	_put(data)
	_put("\nendstream\nendobj\n".to_ascii_buffer())


## A picture's object and where it goes: [number, Rect2], or [] when it
## could not be read. A JPEG goes in as it is; anything else is laid on
## the colour behind it, as the page shows it, and kept without loss.
func _image(op: Dictionary) -> Array:
	var part: String = op["part"]
	var at: Rect2 = op["at"]
	var on: Color = op["on"]
	if bool(op.get("cover", false)):
		# The picture behind the page: in the file once, covering the page as
		# a browser's background-size: cover covers it, the page cutting it.
		if _behind.is_empty():
			_behind = _picture(str(op["src"]), on)
			if _behind.is_empty():
				_behind = [0]
		if _behind.size() < 2:
			return []
		var natural: Vector2 = _behind[1]
		var scale: float = maxf(at.size.x / maxf(natural.x, 1.0), at.size.y / maxf(natural.y, 1.0))
		var covering: Vector2 = natural * scale
		return [_behind[0], Rect2(at.get_center() - covering * 0.5, covering)]
	if not part.is_empty():
		var key: String = part + on.to_html(false)
		if not _parts.has(key):
			var source: String = str(_read.parts.get(part, ""))
			var made: Array = _picture(source, on) if not source.is_empty() else []
			_parts[key] = made
		var kept: Array = _parts[key]
		if kept.is_empty():
			return []
		# Fitted inside its box and stood on its foot (background-size:
		# contain, position: center bottom).
		var natural: Vector2 = kept[1]
		var scale: float = minf(at.size.x / maxf(natural.x, 1.0), at.size.y / maxf(natural.y, 1.0))
		var fitted: Vector2 = natural * scale
		return [kept[0], Rect2(Vector2(at.position.x + (at.size.x - fitted.x) * 0.5,
			at.end.y - fitted.y), fitted)]
	var made: Array = _picture(str(op["src"]), on)
	return [made[0], at] if not made.is_empty() else []


## [object number, size in pixels] of the picture in data URI [param uri],
## laid on [param on], or, where that has no colour, keeping what it lets
## show through as its soft mask.
func _picture(uri: String, on: Color) -> Array:
	var comma: int = uri.find(",")
	if not uri.begins_with("data:") or comma < 0:
		return []
	var bytes: PackedByteArray = Marshalls.base64_to_raw(uri.substr(comma + 1))
	if uri.begins_with("data:image/jpeg"):
		var shape: Vector3i = jpeg_shape(bytes)
		if shape.x > 0:
			var number: int = _new()
			_stream(number, ("/Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace %s "
				+ "/BitsPerComponent 8 /Filter /DCTDecode") % [shape.x, shape.y,
				"/DeviceGray" if shape.z == 1 else "/DeviceRGB"], bytes)
			return [number, Vector2(shape.x, shape.y)]
	var image := Image.new()
	var error: int = ERR_FILE_UNRECOGNIZED
	if uri.begins_with("data:image/webp"):
		error = image.load_webp_from_buffer(bytes)
	elif uri.begins_with("data:image/png"):
		error = image.load_png_from_buffer(bytes)
	elif uri.begins_with("data:image/jpeg"):
		error = image.load_jpg_from_buffer(bytes)
	if error != OK or image.is_empty():
		return []
	image.convert(Image.FORMAT_RGBA8)
	var mask: String = ""
	if on.a <= 0.0 and image.detect_alpha() != Image.ALPHA_NONE:
		var alpha := PackedByteArray()
		alpha.resize(image.get_width() * image.get_height())
		var rgba: PackedByteArray = image.get_data()
		for index: int in alpha.size():
			alpha[index] = rgba[index * 4 + 3]
		var soft: int = _new()
		_stream(soft, ("/Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceGray "
			+ "/BitsPerComponent 8 /Filter /FlateDecode") % [image.get_width(), image.get_height()],
			alpha.compress(FileAccess.COMPRESSION_DEFLATE))
		mask = " /SMask %d 0 R" % soft
		image.convert(Image.FORMAT_RGB8)
	else:
		var laid := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
		laid.fill(Color(on, 1.0))
		laid.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		laid.convert(Image.FORMAT_RGB8)
		image = laid
	var number: int = _new()
	_stream(number, ("/Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB "
		+ "/BitsPerComponent 8 /Filter /FlateDecode%s") % [image.get_width(), image.get_height(), mask],
		image.get_data().compress(FileAccess.COMPRESSION_DEFLATE))
	return [number, Vector2(image.get_width(), image.get_height())]


## A JPEG's width, height and colour channels, from its frame header;
## zero when it has none.
static func jpeg_shape(bytes: PackedByteArray) -> Vector3i:
	var at: int = 2
	while at + 9 < bytes.size():
		if bytes[at] != 0xFF:
			return Vector3i.ZERO
		var marker: int = bytes[at + 1]
		if marker == 0xFF:
			at += 1
			continue
		var length: int = (bytes[at + 2] << 8) | bytes[at + 3]
		if marker >= 0xC0 and marker <= 0xCF and marker != 0xC4 and marker != 0xC8 and marker != 0xCC:
			return Vector3i((bytes[at + 7] << 8) | bytes[at + 8], (bytes[at + 5] << 8) | bytes[at + 6],
				bytes[at + 9])
		at += 2 + length
	return Vector3i.ZERO


func _rect(content: PackedStringArray, op: Dictionary) -> void:
	var at: Rect2 = op["at"]
	var fill: Color = op["fill"]
	var line: Color = op["line"]
	var width: float = op["width"]
	var radius: float = op["radius"]
	if fill.a > 0.0:
		content.append("%s rg %s f" % [_rgb(fill), _rounded(at, radius)])
	# The edge inside the box, as a browser draws a border.
	if line.a > 0.0 and width > 0.0:
		content.append("%s RG %s w %s S" % [_rgb(line), _n(width),
			_rounded(at.grow(-width * 0.5), maxf(0.0, radius - width * 0.5))])


## Words: as shaped ([method _shape]), a letter at a time where that is
## one glyph a letter left to right ([method _letters]), else glyph by
## glyph ([method _glyphs]).
func _text(content: PackedStringArray, op: Dictionary) -> void:
	var text: String = str(op["text"])
	var bold: bool = op["bold"]
	# Where the type cannot be read its words are the reader's Helvetica's,
	# a letter at a time (_own).
	var line: Array = _shape(text, bold) if _types[1 if bold else 0] != null else []
	if line.is_empty() or plain(line):
		_letters(content, op, line)
	else:
		_glyphs(content, op, line)


## Words, each run of letters in one face shown in it: the type's own
## (_own), else the face the line was shaped in for it (_other), at the
## faces' own widths and the words' spacing (Tc).
func _letters(content: PackedStringArray, op: Dictionary, line: Array) -> void:
	var at: Vector2 = op["at"]
	var size: String = _n(op["size"])
	var text: String = str(op["text"])
	var shown := PackedStringArray()
	var font: String = ""
	var run := PackedByteArray()
	var bold: bool = op["bold"]
	var drawn_by: Array = []
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		var placed: Array = _own(code, bold)
		if placed.is_empty():
			if drawn_by.is_empty():
				drawn_by.resize(text.length())
				drawn_by.fill([])
				for glyph: Dictionary in line:
					drawn_by[int(glyph["start"])] = glyph["face"]
			placed = _other(code, bold, drawn_by[index])
		if placed[0] != font and not run.is_empty():
			shown.append("/%s %s Tf <%s> Tj" % [font, size, run.hex_encode()])
			run = PackedByteArray()
		font = placed[0]
		run.append_array(placed[1])
	if not run.is_empty():
		shown.append("/%s %s Tf <%s> Tj" % [font, size, run.hex_encode()])
	content.append("BT %s Tc 1 0 0 -1 %s %s Tm %s rg %s ET" % [_n(op["spacing"]), _n(at.x), _n(at.y),
		_rgb(op["colour"]), " ".join(shown)])


## A shaped line ([param line]) glyph by glyph, left to right, each where
## the shaping puts it: from the faces' own widths (/W) by a TJ's move, and
## raised or lowered where it says (a mark over its letter, Ts). The words'
## spacing goes after each cluster of glyphs, a letter as the page sees it.
## Each glyph reads back as the letters it stands for ([method _reads]); a
## cluster no face here has is "?", its letters named ([member missed]).
func _glyphs(content: PackedStringArray, op: Dictionary, line: Array) -> void:
	var size: float = op["size"]
	var scale: float = size / SHAPED_AT
	var spacing: float = op["spacing"]
	var text: String = str(op["text"])
	var bold: bool = op["bold"]
	var at: Vector2 = op["at"]
	var shown := PackedStringArray()
	var array := PackedStringArray()
	var font: String = ""
	var rise: float = 0.0
	# Where the line's pen is, as shaped, and where the PDF's is: mm from
	# the line's start.
	var pen: float = 0.0
	var written: float = 0.0
	var index: int = 0
	while index < line.size():
		var cluster: Array = [line[index]]
		while index + cluster.size() < line.size() and _same_cluster(line[index + cluster.size()], line[index]):
			cluster.append(line[index + cluster.size()])
		index += cluster.size()
		var placed: Array = _reads(text, cluster, bold)
		for each: int in cluster.size():
			var glyph: Dictionary = cluster[each]
			var offset: Vector2 = glyph["offset"]
			var x: float = pen + offset.x * scale
			pen += float(glyph["advance"]) * scale
			var how: Array = placed[each]
			if how.is_empty():
				continue
			var lift: float = -offset.y * scale
			if how[0] != font or absf(lift - rise) > 0.0005:
				if not array.is_empty():
					shown.append("[%s] TJ" % " ".join(array))
					array.clear()
				if how[0] != font:
					font = how[0]
					shown.append("/%s %s Tf" % [font, _n(size)])
				if absf(lift - rise) > 0.0005:
					rise = lift
					shown.append("%s Ts" % _n(rise))
			if absf(x - written) > 0.0005:
				array.append(_n((written - x) * 1000.0 / size))
			array.append("<%s>" % (how[1] as PackedByteArray).hex_encode())
			written = x + int(how[2]) * size / 1000.0
		pen += spacing
	if not array.is_empty():
		shown.append("[%s] TJ" % " ".join(array))
	if absf(rise) > 0.0005:
		shown.append("0 Ts")
	content.append("BT 0 Tc 1 0 0 -1 %s %s Tm %s rg %s ET" % [_n(at.x), _n(at.y), _rgb(op["colour"]),
		" ".join(shown)])


## How each glyph of [param cluster] (one letter as the page sees it, or a
## few drawn as one) is written: [the face's name on the page, its bytes,
## its width in thousandths] each, or [] for a glyph left out. A glyph that
## is a letter's own in its face reads back as that letter; the rest of the
## cluster's letters go with the first glyph that is none's own (a joined
## form, a ligature, an emoji's sequence) and the others read as nothing.
## A cluster no face has is the type's "?", its letters named.
func _reads(text: String, cluster: Array, bold: bool) -> Array:
	var start: int = cluster[0]["start"]
	var letters: String = text.substr(start, int(cluster[0]["end"]) - start)
	var out: Array = []
	var faced: bool = true
	for glyph: Dictionary in cluster:
		faced = faced and not (glyph["face"] as Array).is_empty()
	if not faced:
		var drawn: bool = _draws(text, cluster)
		for letter: int in letters.length():
			var code: int = letters.unicode_at(letter)
			if not _unseen(code) and not _blank(code):
				_miss(code)
		for glyph: Dictionary in cluster:
			out.append([])
		var type: PdfType = _types[1 if bold else 0]
		if drawn and type != null:
			var mark: int = type.glyph_of(0x3F)
			type.use(mark, 0x3F)
			out[0] = ["F2" if bold else "F1", _code(mark), type.width(mark)]
		return out
	# The letters each glyph is the face's own glyph of.
	var owned: Dictionary = {}
	var rest: Array = []
	for glyph: Dictionary in cluster:
		var face: PdfType = (glyph["face"] as Array)[0]
		var mine: int = -1
		for letter: int in letters.length():
			if not owned.has(letter) and face.glyph_of(letters.unicode_at(letter)) == int(glyph["index"]):
				owned[letter] = true
				mine = letter
				break
		rest.append(mine)
	var left := ""
	for letter: int in letters.length():
		if not owned.has(letter):
			left += letters[letter]
	# The glyphs in the letters' order: a run right to left is drawn last
	# letter first.
	var order: Array = range(cluster.size())
	if int(cluster[0]["flags"]) & TextServer.GRAPHEME_IS_RTL:
		order.reverse()
	var reads: Array = []
	reads.resize(cluster.size())
	for each: int in order:
		if int(rest[each]) >= 0:
			reads[each] = letters[int(rest[each])]
		else:
			reads[each] = left
			left = ""
	# A glyph the shaping hid, advancing nothing for letters that show
	# nothing (a variation selector, a joiner the face has no sequence for:
	# its space glyph), is left out and its letters read with the glyph
	# before it, or after it where it is first. Written, its width would
	# fill the gap after the cluster that a reader reads a space by.
	var kept: int = -1
	var carried: String = ""
	for each: int in order:
		if float(cluster[each]["advance"]) == 0.0 and _unseen_all(str(reads[each])):
			if kept >= 0:
				reads[kept] += reads[each]
			else:
				carried += reads[each]
			reads[each] = null
		else:
			reads[each] = carried + str(reads[each])
			carried = ""
			kept = each
	for each: int in cluster.size():
		if reads[each] == null:
			out.append([])
			continue
		var glyph: Dictionary = cluster[each]
		var found: Array = glyph["face"]
		var face: PdfType = found[0]
		face.use_text(int(glyph["index"]), reads[each])
		if not (found[1] == "F1" or found[1] == "F2"):
			_page_fonts[found[1]] = found[2]
		out.append([found[1], _code(int(glyph["index"])), face.width(int(glyph["index"]))])
	return out


func _path(content: PackedStringArray, op: Dictionary) -> void:
	var fill: Color = op["fill"]
	var line: Color = op["line"]
	var shape := PackedStringArray()
	for points: PackedVector2Array in op["lines"]:
		for index: int in points.size():
			shape.append("%s %s %s" % [_n(points[index].x), _n(points[index].y), "m" if index == 0 else "l"])
		if op["closed"]:
			shape.append("h")
	if shape.is_empty():
		return
	var path: String = " ".join(shape)
	var stroke: String = "%s RG %s w %s S" % [_rgb(line), _n(op["width"]), path] if line.a > 0.0 else ""
	var filled: String = "%s rg %s f" % [_rgb(fill), path] if fill.a > 0.0 and op["closed"] else ""
	if op["stroke_first"]:
		content.append(stroke)
		content.append(filled)
	else:
		content.append(filled)
		content.append(stroke)


## A box with round corners as a path: four lines and four quarter curves.
static func _rounded(at: Rect2, radius: float) -> String:
	var r: float = minf(radius, minf(at.size.x, at.size.y) * 0.5)
	var x0: float = at.position.x
	var y0: float = at.position.y
	var x1: float = at.end.x
	var y1: float = at.end.y
	if r <= 0.01:
		return "%s %s %s %s re" % [_n(x0), _n(y0), _n(at.size.x), _n(at.size.y)]
	var c: float = r * 0.4477
	return " ".join([
		"%s %s m" % [_n(x0 + r), _n(y0)],
		"%s %s l" % [_n(x1 - r), _n(y0)],
		"%s %s %s %s %s %s c" % [_n(x1 - c), _n(y0), _n(x1), _n(y0 + c), _n(x1), _n(y0 + r)],
		"%s %s l" % [_n(x1), _n(y1 - r)],
		"%s %s %s %s %s %s c" % [_n(x1), _n(y1 - c), _n(x1 - c), _n(y1), _n(x1 - r), _n(y1)],
		"%s %s l" % [_n(x0 + r), _n(y1)],
		"%s %s %s %s %s %s c" % [_n(x0 + c), _n(y1), _n(x0), _n(y1 - c), _n(x0), _n(y1 - r)],
		"%s %s l" % [_n(x0), _n(y0 + r)],
		"%s %s %s %s %s %s c h" % [_n(x0), _n(y0 + c), _n(x0 + c), _n(y0), _n(x0 + r), _n(y0)]])


## What the export says of the letters its type could not print, "" when
## there were none: "; its type cannot print 城, 堡, … (31 letters), so they
## are ? in the PDF: the booklet's page shows them".
func missed_said() -> String:
	if missed.is_empty():
		return ""
	var named: Array = Array(missed.slice(0, MISSED_NAMED))
	return "; its type cannot print %s%s, so %s ? in the PDF: the booklet's page shows %s" % [
		", ".join(named), (", … (%d letters)" % missed.size()) if missed.size() > MISSED_NAMED else "",
		"it is" if missed.size() == 1 else "they are", "it" if missed.size() == 1 else "them"]


## Words in the reader's Helvetica's encoding (WinAnsi), where the type
## cannot be read: Latin-1, and the dashes, quotes, ellipsis and trademark
## sign; "?" for anything else (said: [member missed]).
static func win_ansi(text: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(text.length())
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code < 0x80 or code >= 0xA0 and code <= 0xFF:
			out[index] = code
		else:
			out[index] = int(MORE.get(code, 0x3F))
	return out


static func _utf16(text: String) -> String:
	var bytes: PackedByteArray = text.to_utf16_buffer()
	# Big-endian, after its mark, as a PDF's text string is.
	var out := PackedByteArray([0xFE, 0xFF])
	for index: int in range(0, bytes.size() - 1, 2):
		out.append(bytes[index + 1])
		out.append(bytes[index])
	return out.hex_encode()


static func _unique(names: PackedStringArray) -> PackedStringArray:
	var seen: Dictionary = {}
	for name: String in names:
		seen[name] = true
	return PackedStringArray(seen.keys())


static func _rgb(colour: Color) -> String:
	return "%s %s %s" % [_n(colour.r), _n(colour.g), _n(colour.b)]


static func _n(value: float) -> String:
	return String.num(value, 3)
