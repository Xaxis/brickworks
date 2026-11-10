## A typeface in a booklet's PDF, cut down to the letters its pages use
## (BookletPdf): a TrueType or OpenType face, with glyf or CFF outlines,
## read from its file (a collection's face by its number). Each letter's
## glyph is found in the face's Unicode map, and at the end the face is
## written holding only the glyphs used, as the glyphs of a Type0 font
## (CIDFontType2, or CIDFontType0 for CFF) with a ToUnicode map, so a
## reader draws, finds and copies the words as typed in any script the
## face has.
##
## Up to 2026-11-08 the PDF carried all of Liberation Sans, 410 KB a
## weight for some 60 letters, through WinAnsi's one byte a letter, which
## has no room for Cyrillic, Greek or Japanese: they were "?" (pdfcid).
##
## The code a page's words give a glyph is its number in the face, two
## bytes, so nothing is renumbered as the pages are written. A TrueType
## face keeps every glyph's place and empties those not used, a composite
## keeping its parts. A CFF face is written with only the glyphs used, each
## named by its old number as its CID (its charset), and its subroutines
## written in place, so it needs none.
class_name PdfType
extends RefCounted

## Whether the face was read and can go into a PDF.
var ok: bool = false
## Its PostScript name, as the PDF names it.
var name: String = ""
## Its family names (the name table's 1, 16 and 21).
var families: PackedStringArray = []
## Outlines in CFF (CIDFontType0) rather than glyf (CIDFontType2).
var cff: bool = false
## How heavy it is (OS/2's usWeightClass), 400 when it does not say.
var weight: int = 400
## The glyphs used, each with the words it reads back as: the letter it
## was first used for, the letters a glyph stands for together (an Arabic
## ligature, an emoji's sequence), or "" for one that reads as nothing (a
## second glyph of one letter).
var used: Dictionary = {}

var _bytes := PackedByteArray()
## Each table's [offset, length], by its tag.
var _tables: Dictionary = {}
var _em: float = 1000.0
var _glyphs: int = 0
var _hmetrics: int = 1
## The Unicode map's [format, where it is].
var _cmap: Array = []
var _long_loca: bool = false
## Each letter's glyph once found.
var _letters: Dictionary = {}
## The CFF table read: its INDEXes and DICTs.
var _font: Dictionary = {}
## Each CFF glyph's charstring with its subroutines in place: [bytes, draws].
var _flat: Dictionary = {}
var _out := PackedByteArray()
## The numbers on a charstring's stack: where each is in [member _out], and
## its value.
var _stack: Array[Vector2i] = []
var _stems: int = 0
var _drew: bool = false
var _failed: bool = false


## Face [param face] of the font file [param bytes], or null when it is
## not one a PDF can carry: no Unicode map, no outlines (a colour emoji's
## bitmaps), CFF2, or a maker's licence that forbids it (OS/2's fsType:
## restricted, bitmaps only, or never cut down).
static func read(bytes: PackedByteArray, face: int = 0) -> PdfType:
	var type := PdfType.new()
	return type if type._read(bytes, face) else null


## How many faces the file holds: a collection's count, else 1.
static func faces(bytes: PackedByteArray) -> int:
	if bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "ttcf":
		return (bytes[8] << 24) | (bytes[9] << 16) | (bytes[10] << 8) | bytes[11]
	return 1


## The glyph of the letter [param letter] (a code point); 0 when the face
## has none.
func glyph_of(letter: int) -> int:
	if not _letters.has(letter):
		var found: int = _lookup(letter)
		_letters[letter] = found if found < _glyphs else 0
	return _letters[letter]


## Whether glyph [param glyph] draws anything: a space draws nothing, and
## a CFF glyph this cannot follow is taken as drawing nothing.
func drawn(glyph: int) -> bool:
	if glyph <= 0 or glyph >= _glyphs:
		return false
	if cff:
		return bool(_flattened(glyph)[1])
	var span: Vector2i = _loca(glyph)
	return span.y > span.x


## Glyph [param glyph] used for the letter [param letter]: kept in the face
## written, and read back as that letter.
func use(glyph: int, letter: int) -> void:
	use_text(glyph, char(letter))


## Glyph [param glyph] used for the words [param text]: kept, and read back
## as them, where it has not been used for others before.
func use_text(glyph: int, text: String) -> void:
	if not used.has(glyph):
		used[glyph] = text


## Glyph [param glyph]'s advance, in thousandths of the size.
func width(glyph: int) -> int:
	return roundi(_u16(_at("hmtx") + mini(glyph, _hmetrics - 1) * 4) * 1000.0 / _em)


## What a PDF's font descriptor says of it, in thousandths of the size:
## {box [x0, y0, x1, y1], ascent, descent, cap}.
func metrics() -> Dictionary:
	var head: int = _at("head")
	var box: Array = [_thousandths(_i16(head + 36)), _thousandths(_i16(head + 38)),
		_thousandths(_i16(head + 40)), _thousandths(_i16(head + 42))]
	if not _tables.has("OS/2"):
		var hhea: int = _at("hhea")
		return {"box": box, "ascent": _thousandths(_i16(hhea + 4)),
			"descent": _thousandths(_i16(hhea + 6)), "cap": _thousandths(_i16(hhea + 4))}
	var os2: int = _at("OS/2")
	var ascent: int = _thousandths(_i16(os2 + 68))
	return {"box": box, "ascent": ascent, "descent": _thousandths(_i16(os2 + 70)),
		"cap": _thousandths(_i16(os2 + 88)) if _u16(os2) >= 2 else ascent}


## Its name in the PDF: six capitals naming the glyphs it holds, a "+",
## and its PostScript name, as a PDF names a face cut down.
func subset_name() -> String:
	var glyphs: Array = used.keys()
	glyphs.sort()
	var hash: int = ("%s %s" % [name, str(glyphs)]).hash() & 0x7FFFFFFF
	var tag: String = ""
	for _n: int in 6:
		tag += char(65 + hash % 26)
		hash /= 26
	return tag + "+" + name


## The PDF's /W: each glyph used, and its width.
func widths() -> String:
	var glyphs: Array = used.keys()
	glyphs.sort()
	var out := PackedStringArray()
	for glyph: int in glyphs:
		out.append("%d [%d]" % [glyph, width(glyph)])
	return " ".join(out)


## The ToUnicode map: each glyph used, the words it reads back as; one that
## reads as nothing is left out.
func to_unicode() -> PackedByteArray:
	var glyphs: Array = used.keys().filter(func(glyph: int) -> bool: return not str(used[glyph]).is_empty())
	glyphs.sort()
	var lines := PackedStringArray(["/CIDInit /ProcSet findresource begin", "12 dict begin", "begincmap",
		"/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def",
		"/CMapName /Adobe-Identity-UCS def", "/CMapType 2 def",
		"1 begincodespacerange", "<0000> <FFFF>", "endcodespacerange"])
	for first: int in range(0, glyphs.size(), 100):
		var block: Array = glyphs.slice(first, first + 100)
		lines.append("%d beginbfchar" % block.size())
		for glyph: int in block:
			var letter: PackedByteArray = str(used[glyph]).to_utf16_buffer()
			# Big-endian, as a CMap's strings are.
			for index: int in range(0, letter.size() - 1, 2):
				var low: int = letter[index]
				letter[index] = letter[index + 1]
				letter[index + 1] = low
			lines.append("<%04X> <%s>" % [glyph, letter.hex_encode().to_upper()])
		lines.append("endbfchar")
	lines.append_array(["endcmap", "CMapName currentdict /CMap defineresource pop", "end", "end"])
	return "\n".join(lines).to_ascii_buffer()


## The face cut down to the glyphs used (and glyph 0): a TrueType file, or
## a bare CFF one.
func program() -> PackedByteArray:
	return _cff_program() if cff else _true_type()


# -- reading the face ---------------------------------------------------------


func _read(bytes: PackedByteArray, face: int) -> bool:
	_bytes = bytes
	var at: int = 0
	if _tag(0) == "ttcf":
		if face < 0 or face >= _u32(8):
			return false
		at = _u32(12 + face * 4)
	if at + 12 > bytes.size():
		return false
	for index: int in _u16(at + 4):
		var record: int = at + 12 + index * 16
		var offset: int = _u32(record + 8)
		var length: int = _u32(record + 12)
		if record + 16 > bytes.size() or offset + length > bytes.size():
			return false
		_tables[_tag(record)] = [offset, length]
	for needed: String in ["head", "hhea", "hmtx", "maxp", "cmap"]:
		if not _tables.has(needed):
			return false
	cff = _tables.has("CFF ")
	if not cff and not (_tables.has("glyf") and _tables.has("loca")):
		return false
	if _tables.has("OS/2"):
		var os2: int = _at("OS/2")
		var licence: int = _u16(os2 + 8)
		# Restricted (and nothing looser beside it), bitmaps only, or never
		# cut down: the maker's word that it is not to go in a document so.
		if licence & 0x000E == 0x0002 or licence & 0x0300 != 0:
			return false
		weight = _u16(os2 + 4)
	_em = maxf(1.0, _u16(_at("head") + 18))
	_long_loca = _i16(_at("head") + 50) == 1
	_glyphs = _u16(_at("maxp") + 4)
	_hmetrics = maxi(1, _u16(_at("hhea") + 34))
	_names()
	if not _unicode_map():
		return false
	if cff and not _read_cff():
		return false
	ok = _glyphs > 0
	return ok


## The best Unicode map the face has: format 12 (every plane) over format 4.
func _unicode_map() -> bool:
	var cmap: int = _at("cmap")
	var best: int = 0
	for index: int in _u16(cmap + 2):
		var record: int = cmap + 4 + index * 8
		var platform: int = _u16(record)
		var encoding: int = _u16(record + 2)
		var table: int = cmap + _u32(record + 4)
		var format: int = _u16(table)
		if not (platform == 0 or platform == 3 and (encoding == 1 or encoding == 10)):
			continue
		var rank: int = 2 if format == 12 else (1 if format == 4 else 0)
		if rank > best:
			best = rank
			_cmap = [format, table]
	return best > 0


func _lookup(letter: int) -> int:
	var table: int = _cmap[1]
	if int(_cmap[0]) == 12:
		var low: int = 0
		var high: int = _u32(table + 12) - 1
		while low <= high:
			var middle: int = (low + high) / 2
			var group: int = table + 16 + middle * 12
			if letter < _u32(group):
				high = middle - 1
			elif letter > _u32(group + 4):
				low = middle + 1
			else:
				return _u32(group + 8) + letter - _u32(group)
		return 0
	if letter > 0xFFFF:
		return 0
	var segments: int = _u16(table + 6) / 2
	if segments <= 0:
		return 0
	var ends: int = table + 14
	var starts: int = ends + segments * 2 + 2
	var deltas: int = starts + segments * 2
	var offsets: int = deltas + segments * 2
	# The first segment ending at or after the letter.
	var low: int = 0
	var high: int = segments - 1
	while low < high:
		var middle: int = (low + high) / 2
		if _u16(ends + middle * 2) < letter:
			low = middle + 1
		else:
			high = middle
	var start: int = _u16(starts + low * 2)
	if _u16(ends + low * 2) < letter or start > letter:
		return 0
	var delta: int = _u16(deltas + low * 2)
	var offset: int = _u16(offsets + low * 2)
	if offset == 0:
		return (letter + delta) & 0xFFFF
	var glyph: int = _u16(offsets + low * 2 + offset + (letter - start) * 2)
	return (glyph + delta) & 0xFFFF if glyph != 0 else 0


## Its PostScript name and family names, from the name table.
func _names() -> void:
	if not _tables.has("name"):
		return
	var table: int = _at("name")
	var strings: int = table + _u16(table + 4)
	var postscript: String = ""
	for index: int in _u16(table + 2):
		var record: int = table + 6 + index * 12
		var platform: int = _u16(record)
		var id: int = _u16(record + 6)
		if id != 1 and id != 6 and id != 16 and id != 21:
			continue
		var raw: PackedByteArray = _bytes.slice(strings + _u16(record + 10),
			strings + _u16(record + 10) + _u16(record + 8))
		var text: String = ""
		if platform == 0 or platform == 3:
			for at: int in range(0, raw.size() - 1, 2):
				var low: int = raw[at]
				raw[at] = raw[at + 1]
				raw[at + 1] = low
			text = raw.get_string_from_utf16()
		elif platform == 1:
			text = raw.get_string_from_ascii()
		if text.is_empty():
			continue
		if id == 6:
			if postscript.is_empty():
				postscript = text
		elif not families.has(text):
			families.append(text)
	# A PDF name has no spaces or delimiters.
	for letter: String in postscript:
		var code: int = letter.unicode_at(0)
		if code > 32 and code < 127 and not "()<>[]{}/%#".contains(letter):
			name += letter
	if name.is_empty():
		name = "Type"


# -- TrueType: every glyph's place kept, those not used emptied ---------------


func _true_type() -> PackedByteArray:
	var keep: Dictionary = {}
	var waiting: Array = [0] + used.keys()
	while not waiting.is_empty():
		var glyph: int = waiting.pop_back()
		if keep.has(glyph) or glyph < 0 or glyph >= _glyphs:
			continue
		keep[glyph] = true
		waiting.append_array(_parts_of(glyph))
	var glyf := PackedByteArray()
	var loca := PackedByteArray()
	loca.resize((_glyphs + 1) * 4)
	loca.fill(0)
	var hmtx := PackedByteArray()
	hmtx.resize(_glyphs * 4)
	hmtx.fill(0)
	var from: int = _at("glyf")
	var kept: Array = keep.keys()
	kept.sort()
	var next: int = 0
	for glyph: int in _glyphs:
		if next < kept.size() and int(kept[next]) == glyph:
			next += 1
			var span: Vector2i = _loca(glyph)
			_put32(loca, glyph * 4, glyf.size())
			glyf.append_array(_bytes.slice(from + span.x, from + span.y))
			while glyf.size() % 4 != 0:
				glyf.append(0)
			var metric: int = _at("hmtx") + mini(glyph, _hmetrics - 1) * 4
			hmtx[glyph * 4] = _byte(metric)
			hmtx[glyph * 4 + 1] = _byte(metric + 1)
			var side: int = _at("hmtx") + (glyph * 4 + 2 if glyph < _hmetrics
				else _hmetrics * 4 + (glyph - _hmetrics) * 2)
			hmtx[glyph * 4 + 2] = _byte(side)
			hmtx[glyph * 4 + 3] = _byte(side + 1)
		else:
			_put32(loca, glyph * 4, glyf.size())
	_put32(loca, _glyphs * 4, glyf.size())
	var head: PackedByteArray = _table("head")
	_put32(head, 8, 0)
	head[50] = 0
	head[51] = 1
	var hhea: PackedByteArray = _table("hhea")
	hhea[34] = _glyphs >> 8
	hhea[35] = _glyphs & 0xFF
	var tables: Dictionary = {"head": head, "hhea": hhea, "maxp": _table("maxp"), "loca": loca,
		"glyf": glyf, "hmtx": hmtx,
		# A Unicode map with nothing in it: the PDF names each glyph itself,
		# and some readers want the table there.
		"cmap": PackedByteArray([0, 0, 0, 1, 0, 3, 0, 1, 0, 0, 0, 12, 0, 4, 0, 24, 0, 0, 0, 2, 0, 2, 0, 0,
			0, 0, 0xFF, 0xFF, 0, 0, 0xFF, 0xFF, 0, 1, 0, 0])}
	for copied: String in ["cvt ", "fpgm", "prep", "OS/2"]:
		if _tables.has(copied):
			tables[copied] = _table(copied)
	var post := PackedByteArray([0, 3, 0, 0])
	post.append_array(_table("post").slice(4, 32) if _tables.has("post") else PackedByteArray())
	post.resize(32)
	tables["post"] = post
	return _sfnt(tables)


## Glyph [param glyph]'s start and end in glyf.
func _loca(glyph: int) -> Vector2i:
	var loca: int = _at("loca")
	if _long_loca:
		return Vector2i(_u32(loca + glyph * 4), _u32(loca + glyph * 4 + 4))
	return Vector2i(_u16(loca + glyph * 2) * 2, _u16(loca + glyph * 2 + 2) * 2)


## The glyphs a composite glyph is made of.
func _parts_of(glyph: int) -> Array:
	var span: Vector2i = _loca(glyph)
	var at: int = _at("glyf") + span.x
	var end: int = _at("glyf") + span.y
	if span.y - span.x < 10 or _i16(at) >= 0:
		return []
	var parts: Array = []
	at += 10
	while at + 4 <= end:
		var flags: int = _u16(at)
		parts.append(_u16(at + 2))
		at += 4 + (4 if flags & 0x0001 else 2)
		if flags & 0x0008:
			at += 2
		elif flags & 0x0040:
			at += 4
		elif flags & 0x0080:
			at += 8
		if flags & 0x0020 == 0:
			break
	return parts


## A TrueType file of [param tables], tag -> its bytes.
static func _sfnt(tables: Dictionary) -> PackedByteArray:
	var tags: Array = tables.keys()
	tags.sort()
	var count: int = tags.size()
	var power: int = 1
	var exponent: int = 0
	while power * 2 <= count:
		power *= 2
		exponent += 1
	var out := PackedByteArray([0, 1, 0, 0, count >> 8, count & 0xFF, (power * 16) >> 8, (power * 16) & 0xFF,
		0, exponent, ((count - power) * 16) >> 8, ((count - power) * 16) & 0xFF])
	var offset: int = 12 + count * 16
	var body := PackedByteArray()
	for tag: String in tags:
		var data: PackedByteArray = tables[tag]
		var padded: PackedByteArray = data.duplicate()
		while padded.size() % 4 != 0:
			padded.append(0)
		var sum: int = 0
		for at: int in range(0, padded.size(), 4):
			sum = (sum + ((padded[at] << 24) | (padded[at + 1] << 16) | (padded[at + 2] << 8)
				| padded[at + 3])) & 0xFFFFFFFF
		out.append_array(tag.to_ascii_buffer())
		for value: int in [sum, offset + body.size(), data.size()]:
			out.append_array(PackedByteArray([(value >> 24) & 0xFF, (value >> 16) & 0xFF,
				(value >> 8) & 0xFF, value & 0xFF]))
		body.append_array(padded)
	out.append_array(body)
	return out


# -- CFF: only the glyphs used, their subroutines written in place ------------


func _read_cff() -> bool:
	var base: int = _at("CFF ")
	var names: Dictionary = _index(base + _byte(base + 2))
	var tops: Dictionary = _index(names["end"])
	var strings: Dictionary = _index(tops["end"])
	var globals: Dictionary = _index(strings["end"])
	if int(names["count"]) < 1 or int(tops["count"]) < 1:
		return false
	var span: Vector2i = _item(tops, 0)
	var top: Array = _dict(span.x, span.y)
	var said: Dictionary = {}
	for entry: Array in top:
		said[entry[0]] = entry[1]
	if not said.has(17) or int((said.get(1206, [2]) as Array)[0]) != 2:
		return false
	var charstrings: Dictionary = _index(base + int(said[17][0]))
	_glyphs = mini(_glyphs, int(charstrings["count"]))
	var fds: Array = []
	var cid: bool = said.has(1230)
	if cid:
		if not said.has(1236) or not said.has(1237):
			return false
		var array: Dictionary = _index(base + int(said[1236][0]))
		for index: int in int(array["count"]):
			var at: Vector2i = _item(array, index)
			fds.append(_fd(_dict(at.x, at.y), base))
	else:
		fds.append(_fd([[18, said.get(18, [0, 0]), 0, 0]], base))
	for fd: Variant in fds:
		if fd == null:
			return false
	var name_at: Vector2i = _item(names, 0)
	_font = {"base": base, "name": _bytes.slice(name_at.x, name_at.y), "top": top, "strings": strings,
		"globals": globals, "charstrings": charstrings, "fds": fds,
		"select": base + int(said[1237][0]) if cid else -1}
	return true


## A Font DICT's entries, its Private DICT and that one's subroutines:
## {dict, private (its entries), subrs (an INDEX, or {})}; null when it
## cannot be read.
func _fd(entries: Array, base: int) -> Variant:
	var private: Array = []
	var subrs: Dictionary = {}
	for entry: Array in entries:
		if int(entry[0]) != 18:
			continue
		var operands: Array = entry[1]
		if operands.size() < 2:
			return null
		var from: int = base + int(operands[1])
		private = _dict(from, from + int(operands[0]))
		for inner: Array in private:
			if int(inner[0]) == 19 and not (inner[1] as Array).is_empty():
				subrs = _index(from + int(inner[1][0]))
	return {"dict": entries, "private": private, "subrs": subrs}


func _fd_of(glyph: int) -> int:
	var at: int = _font["select"]
	if at < 0:
		return 0
	if _byte(at) == 0:
		return _byte(at + 1 + glyph)
	if _byte(at) == 3:
		var low: int = 0
		var high: int = _u16(at + 1) - 1
		while low <= high:
			var middle: int = (low + high) / 2
			var range_at: int = at + 3 + middle * 3
			if glyph < _u16(range_at):
				high = middle - 1
			elif glyph >= _u16(range_at + 3):
				low = middle + 1
			else:
				return _byte(range_at + 2)
	return 0


## Glyph [param glyph]'s charstring with every subroutine it calls written
## in place: [bytes, whether it draws]. No bytes when it does what this
## does not follow (arithmetic, an accent made of two glyphs).
func _flattened(glyph: int) -> Array:
	if _flat.has(glyph):
		return _flat[glyph]
	var fds: Array = _font["fds"]
	var fd: int = _fd_of(glyph)
	_out = PackedByteArray()
	_stack.clear()
	_stems = 0
	_drew = false
	_failed = fd >= fds.size()
	if not _failed and not _run(_item(_font["charstrings"], glyph), fds[fd]["subrs"], 0):
		_out.append(14)
	_flat[glyph] = [PackedByteArray() if _failed else _out, _drew and not _failed]
	return _flat[glyph]


## Run the charstring at [param span] into [member _out]: whether it ended
## the glyph (endchar, or a failure).
func _run(span: Vector2i, locals: Dictionary, depth: int) -> bool:
	if depth > 10:
		_failed = true
		return true
	var at: int = span.x
	while at < span.y:
		var b: int = _byte(at)
		if b >= 32 or b == 28:
			var length: int = 3 if b == 28 else (1 if b <= 246 else (2 if b <= 254 else 5))
			var value: int = 0
			if b == 28:
				value = _i16(at + 1)
			elif b <= 246:
				value = b - 139
			elif b <= 250:
				value = (b - 247) * 256 + _byte(at + 1) + 108
			elif b <= 254:
				value = -(b - 251) * 256 - _byte(at + 1) - 108
			else:
				value = _i32(at + 1) >> 16
			_stack.append(Vector2i(_out.size(), value))
			_out.append_array(_bytes.slice(at, at + length))
			at += length
			continue
		at += 1
		match b:
			10, 29:
				# callsubr, callgsubr: its number taken off, the subroutine run
				# here.
				var subrs: Dictionary = locals if b == 10 else _font["globals"]
				if _stack.is_empty() or subrs.is_empty():
					_failed = true
					return true
				var top: Vector2i = _stack.pop_back()
				_out.resize(top.x)
				var count: int = subrs["count"]
				var number: int = top.y + (107 if count < 1240 else (1131 if count < 33900 else 32768))
				if number < 0 or number >= count:
					_failed = true
					return true
				if _run(_item(subrs, number), locals, depth + 1):
					return true
			11:
				return false
			14:
				# endchar; with four more numbers it is an accent on a letter
				# (seac), two glyphs this does not follow.
				if _stack.size() >= 4:
					_failed = true
				_out.append(14)
				return true
			1, 3, 18, 23:
				_stems += _stack.size() / 2
				_out.append(b)
				_stack.clear()
			19, 20:
				# hintmask, cntrmask: stems left on the stack are vstems, and a
				# bit a stem follows.
				_stems += _stack.size() / 2
				var mask: int = (_stems + 7) / 8
				_out.append(b)
				_out.append_array(_bytes.slice(at, at + mask))
				at += mask
				_stack.clear()
			12:
				var escaped: int = _byte(at)
				at += 1
				if escaped != 0 and (escaped < 34 or escaped > 37):
					_failed = true
					return true
				_drew = _drew or escaped != 0
				_out.append(12)
				_out.append(escaped)
				_stack.clear()
			4, 5, 6, 7, 8, 21, 22, 24, 25, 26, 27, 30, 31:
				_drew = true
				_out.append(b)
				_stack.clear()
			_:
				_failed = true
				return true
	return false


func _cff_program() -> PackedByteArray:
	var glyphs: Array = used.keys().filter(func(glyph: int) -> bool: return glyph > 0)
	glyphs.sort()
	glyphs.push_front(0)
	var charstrings: Array = []
	var select := PackedByteArray([0])
	var charset := PackedByteArray([0])
	for glyph: int in glyphs:
		var flat: PackedByteArray = _flattened(glyph)[0]
		charstrings.append(flat if not flat.is_empty() else PackedByteArray([14]))
		select.append(_fd_of(glyph))
		if glyph > 0:
			# Each glyph's CID is its number in the face: the code the
			# page's words give it.
			charset.append_array(PackedByteArray([glyph >> 8, glyph & 0xFF]))
	var strings: Dictionary = _font["strings"]
	var string_items: Array = []
	for index: int in int(strings["count"]):
		var at: Vector2i = _item(strings, index)
		string_items.append(_bytes.slice(at.x, at.y))
	var adobe: int = 391 + string_items.size()
	string_items.append("Adobe".to_ascii_buffer())
	string_items.append("Identity".to_ascii_buffer())
	var fds: Array = _font["fds"]
	var privates: Array = []
	var fd_kept: Array = []
	for fd: Dictionary in fds:
		privates.append(_entries(fd["private"], [19]))
		fd_kept.append(_entries(fd["dict"], [18]) if _font["select"] >= 0 else PackedByteArray())
	# The Top DICT: Adobe-Identity-0, first as it must be, what the face's
	# own says but for where things are, then where they are now, each
	# offset five bytes so the sizes are known before the places.
	var top_kept: PackedByteArray = _entries(_font["top"], [1230, 15, 16, 17, 18, 1234, 1235, 1236, 1237, 13, 14])
	var head := PackedByteArray([1, 0, 4, 4])
	var name_index: PackedByteArray = _index_of([_font["name"]])
	var top_size: int = 17 + top_kept.size() + 7 + 6 + 6 + 7 + 7
	var top_index_size: int = _index_of([_zeros(top_size)]).size()
	var string_index: PackedByteArray = _index_of(string_items)
	var charstring_index: PackedByteArray = _index_of(charstrings)
	var charset_at: int = head.size() + name_index.size() + top_index_size + string_index.size() + 2
	var select_at: int = charset_at + charset.size()
	var charstrings_at: int = select_at + select.size()
	var array_at: int = charstrings_at + charstring_index.size()
	var dicts: Array = []
	for index: int in fds.size():
		dicts.append(_zeros((fd_kept[index] as PackedByteArray).size() + 11))
	var private_at: int = array_at + _index_of(dicts).size()
	dicts.clear()
	var private_bytes := PackedByteArray()
	for index: int in fds.size():
		var dict: PackedByteArray = (fd_kept[index] as PackedByteArray).duplicate()
		var private: PackedByteArray = privates[index]
		dict.append_array(_long(private.size()))
		dict.append_array(_long(private_at + private_bytes.size()))
		dict.append(18)
		dicts.append(dict)
		private_bytes.append_array(private)
	var top := PackedByteArray()
	top.append_array(_long(adobe))
	top.append_array(_long(adobe + 1))
	top.append_array(_long(0))
	top.append_array(PackedByteArray([12, 30]))
	top.append_array(top_kept)
	top.append_array(_long(_glyphs))
	top.append_array(PackedByteArray([12, 34]))
	top.append_array(_long(charset_at))
	top.append(15)
	top.append_array(_long(charstrings_at))
	top.append(17)
	top.append_array(_long(array_at))
	top.append_array(PackedByteArray([12, 36]))
	top.append_array(_long(select_at))
	top.append_array(PackedByteArray([12, 37]))
	var out := PackedByteArray()
	out.append_array(head)
	out.append_array(name_index)
	out.append_array(_index_of([top]))
	out.append_array(string_index)
	out.append_array(PackedByteArray([0, 0]))
	out.append_array(charset)
	out.append_array(select)
	out.append_array(charstring_index)
	out.append_array(_index_of(dicts))
	out.append_array(private_bytes)
	return out


## A CFF INDEX at [param at]: {count, size (of an offset), offsets (where
## they start), data (the byte before its first item), end}.
func _index(at: int) -> Dictionary:
	var count: int = _u16(at)
	if count == 0:
		return {"count": 0, "end": at + 2}
	var size: int = _byte(at + 2)
	var offsets: int = at + 3
	var data: int = offsets + (count + 1) * size - 1
	return {"count": count, "size": size, "offsets": offsets, "data": data,
		"end": data + _offset(offsets + count * size, size)}


## Item [param number] of INDEX [param index]: where it starts and ends.
func _item(index: Dictionary, number: int) -> Vector2i:
	var size: int = index["size"]
	var at: int = int(index["offsets"]) + number * size
	return Vector2i(int(index["data"]) + _offset(at, size), int(index["data"]) + _offset(at + size, size))


func _offset(at: int, size: int) -> int:
	var value: int = 0
	for index: int in size:
		value = (value << 8) | _byte(at + index)
	return value


## A CFF DICT's entries: [operator, operands, from, to] each, an escaped
## operator as 1200 and its second byte. A real's value is not needed (it
## is copied as it is), so it reads as 0.
func _dict(start: int, end: int) -> Array:
	var out: Array = []
	var operands: Array = []
	var from: int = start
	var at: int = start
	while at < end:
		var b: int = _byte(at)
		if b <= 21:
			var operator: int = b
			at += 1
			if b == 12:
				operator = 1200 + _byte(at)
				at += 1
			out.append([operator, operands, from, at])
			operands = []
			from = at
		elif b == 28:
			operands.append(_i16(at + 1))
			at += 3
		elif b == 29:
			operands.append(_i32(at + 1))
			at += 5
		elif b == 30:
			at += 1
			while at < end:
				var nibbles: int = _byte(at)
				at += 1
				if nibbles >> 4 == 0x0F or nibbles & 0x0F == 0x0F:
					break
			operands.append(0)
		elif b >= 32 and b <= 246:
			operands.append(b - 139)
			at += 1
		elif b >= 247 and b <= 250:
			operands.append((b - 247) * 256 + _byte(at + 1) + 108)
			at += 2
		elif b >= 251 and b <= 254:
			operands.append(-(b - 251) * 256 - _byte(at + 1) - 108)
			at += 2
		else:
			return []
	return out


## [param entries]' bytes as the face has them, but those of [param left_out].
func _entries(entries: Array, left_out: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for entry: Array in entries:
		if not left_out.has(int(entry[0])):
			out.append_array(_bytes.slice(int(entry[2]), int(entry[3])))
	return out


static func _index_of(items: Array) -> PackedByteArray:
	var count: int = items.size()
	var out := PackedByteArray([count >> 8, count & 0xFF])
	if count == 0:
		return out
	var total: int = 1
	for item: PackedByteArray in items:
		total += item.size()
	var size: int = 1 if total < 0x100 else (2 if total < 0x10000 else (3 if total < 0x1000000 else 4))
	out.append(size)
	var offset: int = 1
	for index: int in count + 1:
		for shift: int in range(size - 1, -1, -1):
			out.append((offset >> (shift * 8)) & 0xFF)
		if index < count:
			offset += (items[index] as PackedByteArray).size()
	for item: PackedByteArray in items:
		out.append_array(item)
	return out


## A number as a CFF DICT's five bytes (29 and four).
static func _long(value: int) -> PackedByteArray:
	return PackedByteArray([29, (value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF])


static func _zeros(count: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(count)
	out.fill(0)
	return out


# -- bytes --------------------------------------------------------------------


func _thousandths(units: int) -> int:
	return roundi(units * 1000.0 / _em)


func _at(tag: String) -> int:
	return int(_tables[tag][0]) if _tables.has(tag) else 0


func _table(tag: String) -> PackedByteArray:
	var span: Array = _tables[tag]
	return _bytes.slice(int(span[0]), int(span[0]) + int(span[1]))


func _tag(at: int) -> String:
	return _bytes.slice(at, at + 4).get_string_from_ascii()


func _byte(at: int) -> int:
	return _bytes[at] if at >= 0 and at < _bytes.size() else 0


func _u16(at: int) -> int:
	return (_byte(at) << 8) | _byte(at + 1)


func _i16(at: int) -> int:
	var value: int = _u16(at)
	return value - 0x10000 if value >= 0x8000 else value


func _u32(at: int) -> int:
	return (_u16(at) << 16) | _u16(at + 2)


func _i32(at: int) -> int:
	var value: int = _u32(at)
	return value - 0x100000000 if value >= 0x80000000 else value


static func _put32(bytes: PackedByteArray, at: int, value: int) -> void:
	bytes[at] = (value >> 24) & 0xFF
	bytes[at + 1] = (value >> 16) & 0xFF
	bytes[at + 2] = (value >> 8) & 0xFF
	bytes[at + 3] = value & 0xFF
