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


## How wide [param text] is in Helvetica (or its bold) at [param size].
static func text_width(text: String, size: float, bold: bool, spacing: float = 0.0) -> float:
	var table: Array = BOLD_WIDTHS if bold else WIDTHS
	var sum: int = 0
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		sum += int(table[code - 32]) if code >= 32 and code <= 126 else 556
	return sum * size / 1000.0 + spacing * text.length()
