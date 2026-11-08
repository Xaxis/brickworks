## How wide words are in Helvetica and Helvetica Bold, the booklet's own
## type: as a page is laid out (Booklet) and as it is read back to be drawn
## (BookletRead). In the core, so that laying out a page does not load the
## booklet's reader with it (Later).
class_name Helvetica
extends RefCounted

## Helvetica's widths, and Helvetica Bold's, for " " to "~", in thousandths
## of the size (the fonts' own AFM).
const WIDTHS := [278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278,
	278, 556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556, 1015,
	667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778, 667, 778, 722,
	667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556, 333, 556, 556, 500, 556,
	556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, 556, 556, 333, 500, 278, 556, 500,
	722, 500, 500, 500, 334, 260, 334, 584]
const BOLD_WIDTHS := [278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333,
	278, 278, 556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 333, 333, 584, 584, 584, 611,
	975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778, 667, 778,
	722, 667, 611, 722, 667, 944, 667, 667, 611, 333, 278, 333, 584, 556, 333, 556, 611, 556,
	611, 556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611, 611, 611, 389, 556, 333, 611,
	556, 778, 556, 556, 500, 389, 280, 389, 584]


## The letters a page draws a whole em wide whatever the type, from the
## fallback a browser finds for them: East Asian wide and fullwidth letters
## (Unicode's East Asian Width W and F) and emoji, [first, last] each. Up to
## 2026-11-07 each was taken as 556, an average Latin letter, and a title of
## 30 CJK letters was laid out at 10 mm and drawn 315 mm across a 269 mm
## page (blreview).
const WIDE: Array = [[0x1100, 0x115F], [0x231A, 0x231B], [0x2329, 0x232A], [0x23E9, 0x23EC],
	[0x2600, 0x27BF], [0x2B1B, 0x2B1C], [0x2E80, 0x303E], [0x3041, 0x33FF], [0x3400, 0x4DBF],
	[0x4E00, 0x9FFF], [0xA000, 0xA4CF], [0xA960, 0xA97F], [0xAC00, 0xD7A3], [0xF900, 0xFAFF],
	[0xFE10, 0xFE19], [0xFE30, 0xFE6F], [0xFF00, 0xFF60], [0xFFE0, 0xFFE6], [0x1F000, 0x1FAFF],
	[0x20000, 0x3FFFD]]
## And those it draws no width at all: joiners, variation selectors, marks
## that sit on the letter before.
const NONE: Array = [[0x0300, 0x036F], [0x200B, 0x200F], [0x20D0, 0x20FF], [0xFE00, 0xFE0F],
	[0xE0100, 0xE01EF]]


## How wide [param text] is in Helvetica (or its bold) at [param size].
static func text_width(text: String, size: float, bold: bool, spacing: float = 0.0) -> float:
	var table: Array = BOLD_WIDTHS if bold else WIDTHS
	var sum: int = 0
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code >= 32 and code <= 126:
			sum += int(table[code - 32])
		elif code < 0x0300:
			sum += 556
		elif _within(code, WIDE):
			sum += 1000
		elif not _within(code, NONE):
			sum += 556
	return sum * size / 1000.0 + spacing * text.length()


static func _within(code: int, ranges: Array) -> bool:
	for span: Array in ranges:
		if code >= int(span[0]) and code <= int(span[1]):
			return true
	return false
