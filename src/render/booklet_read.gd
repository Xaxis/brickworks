## A booklet's pages read back from the booklet itself, as what to draw:
## boxes, pictures, words and lines in page millimetres, for its PDF
## (BookletPdf) and its pages as pictures (BookletPng).
##
## The booklet is one web page (Booklet), written a page at a time as it
## is drawn, and that page is what a person has: in their browser, and in
## the file they saved. So the PDF is made from it, a page at a time, and
## not by drawing the booklet again, which takes minutes where this takes
## seconds; and only one page is held at once, however long the booklet.
##
## It reads what Booklet writes and nothing else: each page a <section>,
## each thing on it a box, a picture, a part's picture or a line of words
## placed by --x, --y, --w, --h, and the arrows, the turn sign and the
## progress bar in an SVG over it all. Whatever else is in the file is
## passed over. The looks are its stylesheet's (Booklet._head), as the
## browser draws them; a line of words is placed as the browser places it,
## with Helvetica's widths (the page's own font, or one the same width).
class_name BookletRead
extends RefCounted

## A page, as what is drawn on it in order: see [method feed].
class Page extends RefCounted:
	var number: int = 0
	var kind: String = ""
	## {k: "rect", at, fill, line, width, radius}: a box, its edge inside it.
	## {k: "image", at, src (a data URI), part (its class, for a part's
	##   picture, which is fitted into at and stood on its foot), on (the
	##   colour behind it)}.
	## {k: "text", at (the start of its baseline), size, text, bold, colour,
	##   spacing}: one line.
	## {k: "path", lines ([PackedVector2Array]), closed, fill, line, width,
	##   stroke_first}: a colour with no alpha is not drawn.
	var ops: Array[Dictionary] = []
	## The step pictures' sources in the order they are on the page, for a
	## check that the PDF has them as they are.
	var pictures: PackedStringArray = PackedStringArray()

## The booklet's title, as its <title> has it.
var title: String = ""
## Each part's picture by its class (".p12"): a data URI.
var parts: Dictionary = {}
var _section: String = ""
var _inside: bool = false

const PAGE_COLOUR := Color8(220, 236, 248)
const INK := Color8(21, 25, 30)
## A line of words whose line is as high as it is (line-height 1) has its
## baseline this far down, in its size: Helvetica's ascent less half of
## what its ascent and descent pass the line by.
const BASELINE := 0.8464
const ASCENT_DESCENT := 1.117

## The boxes of the stylesheet's classes: fill, edge, edge width, corner.
const LOOKS: Dictionary = {
	"box": [Color8(188, 218, 241), Color8(61, 111, 151), 0.35, 2.2],
	"co": [Color8(255, 243, 200), Color8(52, 57, 63), 0.4, 2.6],
	"frame": [Color8(255, 248, 222), Color8(52, 57, 63), 0.5, 3.5],
	"ban": [Color8(35, 82, 124), Color(0, 0, 0, 0), 0.0, 2.0],
}

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

static var _attribute := RegEx.create_from_string("([\\w:-]+)=\"([^\"]*)\"")
static var _rule := RegEx.create_from_string("\\.(p\\d+)\\{background-image:url\\(([^)]*)\\)\\}")
static var _number := RegEx.create_from_string("-?[0-9]*\\.?[0-9]+(?:e-?[0-9]+)?")
static var _path_token := RegEx.create_from_string("[MLQAZmlqaz]|-?[0-9]*\\.?[0-9]+(?:e-?[0-9]+)?")


## Every page of the booklet [param from], the path of its file or the
## document of the browser tab it is in, handed to [param each] as it is
## read: one page held at a time. A frame for the window every [param pace]
## pages (none on the web, where a tab out of view is given no frames, and
## what is asked from the booklet's own tab is done at once). Returns the
## pages read, -1 when there was nothing to read.
func read_all(from: Variant, each: Callable, pace: int = 0) -> int:
	var count: int = 0
	if from is JavaScriptObject:
		var document: JavaScriptObject = from
		var styles: JavaScriptObject = document.querySelectorAll("style")
		for index: int in int(styles.length):
			feed("<style>%s</style>" % str((styles.item(index) as JavaScriptObject).textContent))
		feed("<title>%s</title>" % str(document.title).replace("&", "&amp;"))
		var sections: JavaScriptObject = document.querySelectorAll("section.page")
		for index: int in int(sections.length):
			for page: Page in feed(str((sections.item(index) as JavaScriptObject).outerHTML)):
				each.call(page)
				count += 1
		return count if count > 0 else -1
	var file: FileAccess = FileAccess.open(str(from), FileAccess.READ)
	if file == null:
		return -1
	var tree := Engine.get_main_loop() as SceneTree
	while not file.eof_reached():
		for page: Page in feed(file.get_line() + "\n"):
			each.call(page)
			count += 1
			if pace > 0 and count % pace == 0:
				await tree.process_frame
	return count if count > 0 else -1


## The next piece of the booklet: a line of its file, or a page of it as a
## browser has it. Returns the pages this piece finished, each read whole.
func feed(text: String) -> Array[Page]:
	var done: Array[Page] = []
	while not text.is_empty():
		if not _inside:
			var start: int = text.find("<section")
			_head(text if start < 0 else text.substr(0, start))
			if start < 0:
				break
			_inside = true
			_section = ""
			text = text.substr(start)
		var end: int = text.find("</section>")
		if end < 0:
			_section += text
			break
		_section += text.substr(0, end)
		done.append(_page(_section))
		_section = ""
		_inside = false
		text = text.substr(end + "</section>".length())
	return done


## The file outside its pages: its title, and the parts' pictures, a rule
## each.
func _head(text: String) -> void:
	var at: int = text.find("<title>")
	if at >= 0:
		var end: int = text.find("</title>", at)
		if end > at:
			title = _unescaped(text.substr(at + 7, end - at - 7))
	if text.contains("background-image"):
		for found: RegExMatch in _rule.search_all(text):
			parts[found.get_string(1)] = found.get_string(2)


func _page(html: String) -> Page:
	var page := Page.new()
	page.ops.append({"k": "rect", "at": Rect2(Vector2.ZERO, Booklet.PAGE), "fill": PAGE_COLOUR,
		"line": Color(0, 0, 0, 0), "width": 0.0, "radius": 0.0})
	var at: int = 0
	## The line of words open: {kind, vars, style, runs}.
	var words: Dictionary = {}
	var svg: bool = false
	while true:
		var open: int = html.find("<", at)
		if open < 0:
			break
		if not words.is_empty() and open > at:
			(words["runs"] as Array).append(_unescaped(html.substr(at, open - at)))
		var close: int = html.find(">", open)
		if close < 0:
			break
		var tag: String = html.substr(open + 1, close - open - 1)
		at = close + 1
		var name: String = tag.get_slice(" ", 0).trim_suffix("/").to_lower()
		if name == "/div" and not words.is_empty():
			_words(page, words)
			words = {}
			continue
		if name == "/svg":
			svg = false
			continue
		if name.begins_with("/") or name.begins_with("!"):
			continue
		var attributes: Dictionary = _attributes(tag)
		if svg:
			_svg(page, name, attributes)
			continue
		var kind: PackedStringArray = str(attributes.get("class", "")).split(" ", false)
		match name:
			"section":
				page.kind = kind[1] if kind.size() > 1 else ""
				page.number = str(attributes.get("id", "")).trim_prefix("page-").to_int()
			"svg":
				svg = true
			"div":
				var style: Dictionary = _style(str(attributes.get("style", "")))
				if kind.has("t"):
					words = {"kind": kind, "style": style, "runs": []}
				else:
					_box(page, kind, style)
			"img":
				var style: Dictionary = _style(str(attributes.get("style", "")))
				var source: String = str(attributes.get("src", ""))
				page.ops.append({"k": "image", "at": _rect(style), "src": source, "part": "",
					"on": _behind(page, _rect(style).get_center())})
				page.pictures.append(source)
			"i":
				var style: Dictionary = _style(str(attributes.get("style", "")))
				if kind.has("chip") and not words.is_empty():
					(words["runs"] as Array).append({"chip": _colour(str(style.get("background", "#888")))})
				elif kind.has("pt") and kind.size() > 1:
					page.ops.append({"k": "image", "at": _rect(style), "src": "", "part": kind[1],
						"on": _behind(page, _rect(style).get_center())})
			"br":
				if not words.is_empty():
					(words["runs"] as Array).append("\n")
	return page


static func _attributes(tag: String) -> Dictionary:
	var out: Dictionary = {}
	for found: RegExMatch in _attribute.search_all(tag):
		out[found.get_string(1)] = found.get_string(2).replace("&quot;", "\"").replace("&amp;", "&")
	return out


## An inline style: each property, and each --x, --y, --w, --h, --s as a
## number; calc(N * var(--mm)) is N.
static func _style(style: String) -> Dictionary:
	var out: Dictionary = {}
	for part: String in style.split(";", false):
		var colon: int = part.find(":")
		if colon < 0:
			continue
		var key: String = part.substr(0, colon).strip_edges()
		var value: String = part.substr(colon + 1).strip_edges()
		out[key] = value
	return out


static func _mm(value: Variant) -> float:
	var text: String = str(value)
	var found: RegExMatch = _number.search(text)
	return found.get_string().to_float() if found != null else 0.0


static func _rect(style: Dictionary) -> Rect2:
	return Rect2(_mm(style.get("--x", 0)), _mm(style.get("--y", 0)),
		_mm(style.get("--w", 0)), _mm(style.get("--h", 0)))


static func _colour(text: String) -> Color:
	text = text.strip_edges()
	if text.is_empty() or text == "none":
		return Color(0, 0, 0, 0)
	if text.begins_with("#"):
		return Color.html(text)
	if text.begins_with("rgb"):
		var numbers: Array = _number.search_all(text).map(func(m: RegExMatch) -> float:
			return m.get_string().to_float())
		if numbers.size() >= 3:
			return Color(numbers[0] / 255.0, numbers[1] / 255.0, numbers[2] / 255.0,
				numbers[3] if numbers.size() > 3 else 1.0)
	return Color.from_string(text, INK)


## The colour behind [param point]: the last box drawn under it, a picture
## laid on it (a part's on its parts box) taking that colour where it has
## no colour of its own.
static func _behind(page: Page, point: Vector2) -> Color:
	for index: int in range(page.ops.size() - 1, -1, -1):
		var op: Dictionary = page.ops[index]
		if op["k"] == "rect" and (op["fill"] as Color).a > 0.0 and (op["at"] as Rect2).has_point(point):
			return op["fill"]
	return PAGE_COLOUR


func _box(page: Page, kind: PackedStringArray, style: Dictionary) -> void:
	var at: Rect2 = _rect(style)
	var fill := Color(0, 0, 0, 0)
	var line := Color(0, 0, 0, 0)
	var width: float = 0.0
	var radius: float = 0.0
	for name: String in kind:
		if LOOKS.has(name):
			var look: Array = LOOKS[name]
			fill = look[0]
			line = look[1]
			width = look[2]
			radius = look[3]
	if style.has("background"):
		fill = _colour(str(style["background"]))
	if style.has("border-radius"):
		radius = _mm(style["border-radius"])
	# A ring drawn round the box (box-shadow: 0 0 0 W colour): a box that
	# much bigger behind it.
	if style.has("box-shadow"):
		var shadow: String = str(style["box-shadow"])
		var ring: float = _mm(shadow.get_slice("calc(", 1)) if shadow.contains("calc(") else 0.0
		var colour: Color = _colour(shadow.get_slice(")", shadow.get_slice_count(")") - 1))
		page.ops.append({"k": "rect", "at": at.grow(ring), "fill": colour,
			"line": Color(0, 0, 0, 0), "width": 0.0, "radius": radius + ring})
	page.ops.append({"k": "rect", "at": at, "fill": fill, "line": line, "width": width,
		"radius": radius})


## A line of words (or a note's lines), as the browser sets it: from its
## top at --y, its size --s, wrapped at its width where its kind wraps,
## right-aligned where it says so.
func _words(page: Page, words: Dictionary) -> void:
	var kind: PackedStringArray = words["kind"]
	var style: Dictionary = words["style"]
	var size: float = _mm(style.get("--s", 4))
	var origin := Vector2(_mm(style.get("--x", 0)), _mm(style.get("--y", 0)))
	var bold: bool = kind.has("n") or kind.has("q")
	var colour: Color = Color8(59, 70, 82) if kind.has("e") else INK
	var spacing: float = -0.02 * size if kind.has("n") else 0.0
	var width: float = _mm(style["width"]) if style.has("width") else 0.0
	var high: float = 1.0
	var wrap: float = 0.0
	var pad := Vector2.ZERO
	if kind.has("note"):
		colour = Color8(122, 74, 0)
		pad = Vector2(1.6, 1.0)
		wrap = width - pad.x * 2.0
	elif kind.has("tx"):
		high = 1.2
		wrap = width
	if style.has("color"):
		colour = _colour(str(style["color"]))
	var lines: Array = _lines(words["runs"], size, bold, spacing, wrap, kind.has("tx"))
	if kind.has("note"):
		page.ops.append({"k": "rect", "at": Rect2(origin, Vector2(width,
			lines.size() * size + pad.y * 2.0)), "fill": Color8(255, 241, 214),
			"line": Color(0, 0, 0, 0), "width": 0.0, "radius": 1.4})
	var right: bool = str(style.get("text-align", "")) == "right" and width > 0.0
	var down: float = (high - ASCENT_DESCENT) * 0.5 + (BASELINE - (1.0 - ASCENT_DESCENT) * 0.5)
	for index: int in lines.size():
		var line: Array = lines[index]
		var x: float = origin.x + pad.x
		if right:
			x += width - _line_width(line, size, bold, spacing)
		var baseline: float = origin.y + pad.y + (down + index * high) * size
		for run: Variant in line:
			if run is Dictionary:
				var chip: Color = run["chip"]
				page.ops.append({"k": "rect", "at": Rect2(x, baseline + 0.3 - 2.4, 2.4, 2.4),
					"fill": chip, "line": chip.darkened(0.3), "width": 0.2, "radius": 0.5})
				x += 3.4
				continue
			var text: String = str(run)
			if text.is_empty():
				continue
			page.ops.append({"k": "text", "at": Vector2(x, baseline), "size": size,
				"text": text, "bold": bold, "colour": colour, "spacing": spacing})
			x += text_width(text, size, bold, spacing)


## The runs of a line of words cut into lines: at each "\n", and, when
## [param wrap] is more than none, between words where a line would be
## wider. Spaces run together but where [param keep] (white-space:
## pre-wrap).
static func _lines(runs: Array, size: float, bold: bool, spacing: float, wrap: float,
		keep: bool) -> Array:
	var lines: Array = [[]]
	for run: Variant in runs:
		if run is Dictionary:
			(lines[-1] as Array).append(run)
			continue
		var text: String = str(run)
		if not keep and wrap > 0.0:
			text = text.replace("\n", " ").replace("\t", " ")
		var rows: PackedStringArray = text.split("\n")
		for row_index: int in rows.size():
			if row_index > 0:
				lines.append([])
			var row: String = rows[row_index]
			if not keep:
				while row.contains("  "):
					row = row.replace("  ", " ")
			if wrap <= 0.0:
				(lines[-1] as Array).append(row)
				continue
			for word: String in row.split(" ", true):
				var line: Array = lines[-1]
				var said: String = (" " if not line.is_empty() and line[-1] is String else "") + word
				if not line.is_empty() and _line_width(line, size, bold, spacing) \
						+ text_width(said, size, bold, spacing) > wrap + 0.01:
					lines.append([word])
					continue
				if not line.is_empty() and line[-1] is String:
					line[-1] = str(line[-1]) + said
				else:
					line.append(word)
	# Spaces that begin or end a line take no room (white-space: normal).
	if not keep:
		for line: Array in lines:
			if not line.is_empty() and line[0] is String:
				line[0] = str(line[0]).lstrip(" ")
			if not line.is_empty() and line[-1] is String:
				line[-1] = str(line[-1]).rstrip(" ")
	return lines


static func _line_width(line: Array, size: float, bold: bool, spacing: float) -> float:
	var width: float = 0.0
	for run: Variant in line:
		width += 3.4 if run is Dictionary else text_width(str(run), size, bold, spacing)
	return width


## How wide [param text] is in Helvetica (or its bold) at [param size].
static func text_width(text: String, size: float, bold: bool, spacing: float = 0.0) -> float:
	var table: Array = BOLD_WIDTHS if bold else WIDTHS
	var sum: int = 0
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		sum += int(table[code - 32]) if code >= 32 and code <= 126 else 556
	return sum * size / 1000.0 + spacing * text.length()


## What the SVG over the page draws: the progress bar's rects, the arrows'
## lines and heads, the turn sign's rings.
func _svg(page: Page, name: String, attributes: Dictionary) -> void:
	var fill: Color = _colour(str(attributes.get("fill", "#000")))
	var line: Color = _colour(str(attributes.get("stroke", "none")))
	var width: float = str(attributes.get("stroke-width", "1")).to_float()
	match name:
		"rect":
			var at := Rect2(str(attributes.get("x", "0")).to_float(), str(attributes.get("y", "0")).to_float(),
				str(attributes.get("width", "0")).to_float(), str(attributes.get("height", "0")).to_float())
			var radius: float = str(attributes.get("rx", "0")).to_float()
			# An SVG edge is drawn on the edge, half in and half out.
			if line.a > 0.0:
				at = at.grow(width * 0.5)
				radius += width * 0.5
			page.ops.append({"k": "rect", "at": at, "fill": fill, "line": line,
				"width": width if line.a > 0.0 else 0.0, "radius": radius})
		"polyline":
			var points := PackedVector2Array()
			var numbers: PackedFloat64Array = _numbers(str(attributes.get("points", "")))
			for index: int in range(0, numbers.size() - 1, 2):
				points.append(Vector2(numbers[index], numbers[index + 1]))
			page.ops.append({"k": "path", "lines": [points], "closed": false, "fill": fill,
				"line": line, "width": width, "stroke_first": false})
		"path":
			var drawn: Array = _path(str(attributes.get("d", "")))
			page.ops.append({"k": "path", "lines": drawn[0], "closed": drawn[1], "fill": fill,
				"line": line, "width": width,
				"stroke_first": str(attributes.get("paint-order", "")) == "stroke"})


static func _numbers(text: String) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for found: RegExMatch in _number.search_all(text):
		out.append(found.get_string().to_float())
	return out


## An SVG path's M, L, Q, A and Z, as Booklet writes them (absolute), each
## curve as short straight lines: [[PackedVector2Array], closed].
static func _path(d: String) -> Array:
	var lines: Array = []
	var points := PackedVector2Array()
	var closed: bool = false
	var at := Vector2.ZERO
	var command: String = ""
	var tokens := PackedStringArray()
	for found: RegExMatch in _path_token.search_all(d):
		tokens.append(found.get_string())
	var index: int = 0
	while index < tokens.size():
		var token: String = tokens[index]
		if "MLQAZmlqaz".contains(token):
			command = token.to_upper()
			index += 1
			if command == "Z":
				closed = true
			continue
		var wanted: int = {"M": 2, "L": 2, "Q": 4, "A": 7}.get(command, 0)
		if wanted == 0 or index + wanted > tokens.size():
			index += 1
			continue
		var p := PackedFloat64Array()
		for n: int in wanted:
			p.append(tokens[index + n].to_float())
		index += wanted
		match command:
			"M":
				if points.size() > 1:
					lines.append(points)
				at = Vector2(p[0], p[1])
				points = PackedVector2Array([at])
				command = "L"
			"L":
				at = Vector2(p[0], p[1])
				points.append(at)
			"Q":
				var control := Vector2(p[0], p[1])
				var to := Vector2(p[2], p[3])
				for step: int in range(1, 17):
					var t: float = step / 16.0
					points.append(at.lerp(control, t).lerp(control.lerp(to, t), t))
				at = to
			"A":
				var to := Vector2(p[5], p[6])
				points.append_array(_arc(at, to, Vector2(p[0], p[1]), p[2], p[3] != 0.0, p[4] != 0.0))
				at = to
	if points.size() > 1:
		lines.append(points)
	return [lines, closed]


## An SVG elliptical arc from [param from] to [param to] as points (SVG
## 1.1's F.6.5, its centre from its ends), not counting [param from].
static func _arc(from: Vector2, to: Vector2, radii: Vector2, turned: float, large: bool,
		sweep: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rx: float = absf(radii.x)
	var ry: float = absf(radii.y)
	if rx == 0.0 or ry == 0.0:
		out.append(to)
		return out
	var phi: float = deg_to_rad(turned)
	var half: Vector2 = ((from - to) * 0.5).rotated(-phi)
	var grow: float = half.x * half.x / (rx * rx) + half.y * half.y / (ry * ry)
	if grow > 1.0:
		rx *= sqrt(grow)
		ry *= sqrt(grow)
	var top: float = rx * rx * ry * ry - rx * rx * half.y * half.y - ry * ry * half.x * half.x
	var bottom: float = rx * rx * half.y * half.y + ry * ry * half.x * half.x
	var k: float = sqrt(maxf(0.0, top / bottom)) * (-1.0 if large == sweep else 1.0)
	var centre_turned := Vector2(k * rx * half.y / ry, -k * ry * half.x / rx)
	var centre: Vector2 = centre_turned.rotated(phi) + (from + to) * 0.5
	var start_way := Vector2((half.x - centre_turned.x) / rx, (half.y - centre_turned.y) / ry)
	var end_way := Vector2((-half.x - centre_turned.x) / rx, (-half.y - centre_turned.y) / ry)
	var start: float = start_way.angle()
	var swept: float = fposmod(end_way.angle() - start, TAU)
	if not sweep:
		swept -= TAU
	var steps: int = maxi(8, int(absf(swept) / TAU * 48.0))
	for step: int in range(1, steps + 1):
		var angle: float = start + swept * step / steps
		out.append(Vector2(cos(angle) * rx, sin(angle) * ry).rotated(phi) + centre)
	return out


static func _unescaped(text: String) -> String:
	if not text.contains("&"):
		return text
	return (text.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"")
		.replace("&#39;", "'").replace("&nbsp;", " ").replace("&amp;", "&"))
