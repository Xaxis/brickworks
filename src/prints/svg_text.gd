## The words in an SVG turned into outlines, so they are drawn.
##
## Godot draws an SVG with ThorVG, built here without a font loader: every
## <text> is dropped without a word. walk239 (2026-10-24, M12): a session
## printed a menu board and a "TACOS" roof sign with print_part, the board
## came out plain black and the sign wordless, and the answer was "Printed
## it where it stands". So before an SVG is drawn, each <text> (its
## <tspan>s too) is set in the app's own font by the text server, shaped
## with its kerning, and each glyph's outline written as a <path> in the
## text's place, with the text's fill, stroke and transform. What no font
## here has a glyph for, and text on a path, cannot be drawn: [method
## outline] says so, and print_part refuses rather than print without it.
class_name SvgText
extends RefCounted

## The size glyphs are shaped and outlined at, px; scaled to the text's.
const AT := 256
## Pixels to the unit, for the font-size units an SVG may give.
const UNITS := {"px": 1.0, "pt": 4.0 / 3.0, "pc": 16.0, "mm": 96.0 / 25.4, "cm": 96.0 / 2.54,
	"in": 96.0, "em": 16.0, "rem": 16.0}
## What a <text> passes on to the outline drawn in its place.
const KEPT := ["id", "class", "fill", "fill-opacity", "stroke", "stroke-width",
	"stroke-opacity", "stroke-linejoin", "stroke-linecap", "opacity", "transform", "style",
	"visibility", "display", "clip-path", "mask", "filter"]
## What text inherits from the elements round it, and their defaults.
const INHERITED := {"font-size": "16", "font-weight": "normal", "font-style": "normal",
	"text-anchor": "start", "dominant-baseline": "auto", "letter-spacing": "0",
	"font-family": ""}


## [param svg] with its text as outlines: {"svg": the SVG, "texts": how many
## <text> it had, "words": what they say, "undrawn": what could not be
## drawn (empty when all of it was)}. An SVG with no <text> comes back as it
## was.
static func outline(svg: String) -> Dictionary:
	var out := {"svg": svg, "texts": 0, "words": PackedStringArray(), "undrawn": PackedStringArray()}
	if not svg.contains("<text"):
		return out
	var bytes: PackedByteArray = svg.to_utf8_buffer()
	var parser := XMLParser.new()
	if parser.open_buffer(bytes) != OK:
		return out
	var pieces: Array = []   ## [from byte, to byte, what goes there]
	var words := PackedStringArray()
	var undrawn := PackedStringArray()
	var stack: Array = []    ## the inherited text properties of each open element
	var props: Dictionary = INHERITED.duplicate()
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var name: String = parser.get_node_name()
				var own: Dictionary = _attributes(parser)
				var mine: Dictionary = _inherit(props, own)
				if name == "text":
					var start: int = parser.get_node_offset()
					var read: Dictionary = _read_text(parser, mine, own)
					out["texts"] = int(out["texts"]) + 1
					if not str(read["words"]).is_empty():
						words.append(str(read["words"]))
					undrawn.append_array(read["undrawn"])
					# Past the '>' of its closing tag (or of itself, when empty):
					# the parser gives where that tag's node starts.
					pieces.append([start, bytes.find(62, int(read["end"])) + 1, str(read["paths"])])
				elif not parser.is_empty():
					stack.append(props)
					props = mine
			XMLParser.NODE_ELEMENT_END:
				if not stack.is_empty():
					props = stack.pop_back()
	out["words"] = words
	out["undrawn"] = undrawn
	if pieces.is_empty():
		return out
	var made := PackedByteArray()
	var at: int = 0
	for piece: Array in pieces:
		made.append_array(bytes.slice(at, int(piece[0])))
		made.append_array(str(piece[2]).to_utf8_buffer())
		at = int(piece[1])
	made.append_array(bytes.slice(at))
	out["svg"] = made.get_string_from_utf8()
	return out


static func _attributes(parser: XMLParser) -> Dictionary:
	var out: Dictionary = {}
	for n: int in parser.get_attribute_count():
		out[parser.get_attribute_name(n)] = parser.get_attribute_value(n)
	# CSS in style= wins over attributes, as a browser has it.
	for one: String in str(out.get("style", "")).split(";", false):
		var pair: PackedStringArray = one.split(":", true, 1)
		if pair.size() == 2:
			out[pair[0].strip_edges()] = pair[1].strip_edges()
	return out


static func _inherit(props: Dictionary, own: Dictionary) -> Dictionary:
	var out: Dictionary = props.duplicate()
	for key: String in INHERITED:
		if own.has(key) and str(own[key]) != "inherit":
			out[key] = own[key]
	if own.has("font-size"):
		out["font-size"] = str(_size(str(own["font-size"]), float(_size(str(props["font-size"]), 16.0))))
	if own.has("font"):
		# The shorthand: "bold 24px sans-serif".
		for word: String in str(own["font"]).split(" ", false):
			if word in ["bold", "bolder", "600", "700", "800", "900"]:
				out["font-weight"] = word
			elif word in ["italic", "oblique"]:
				out["font-style"] = word
			elif word[0].is_valid_int() and not word.is_valid_int():
				out["font-size"] = str(_size(word, 16.0))
	return out


## A font-size in px: "24", "24px", "18pt", "1.5em" of [param parent].
static func _size(given: String, parent: float) -> float:
	var text: String = given.strip_edges().to_lower()
	if text.ends_with("%"):
		return parent * text.trim_suffix("%").to_float() / 100.0
	for unit: String in UNITS:
		if text.ends_with(unit):
			var scale: float = parent if unit == "em" else float(UNITS[unit])
			return text.trim_suffix(unit).to_float() * scale
	return text.to_float() if text.is_valid_float() else parent


## One <text> read to its end: its runs set as outlines. {"paths": the
## markup put in its place, "end": the byte after it, "words", "undrawn"}.
static func _read_text(parser: XMLParser, props: Dictionary, own: Dictionary) -> Dictionary:
	var runs: Array = []   ## [words, props, attributes of the element it is in, new chunk at x/y or null]
	var undrawn := PackedStringArray()
	var at: Array = [_first(own, "x"), _first(own, "y"), _first(own, "dx"), _first(own, "dy")]
	var frames: Array = [[props, own]]
	var end: int = parser.get_node_offset()
	if not parser.is_empty():
		var depth: int = 1
		var pending: Array = at
		while depth > 0 and parser.read() == OK:
			match parser.get_node_type():
				XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
					var top: Array = frames.back()
					# A tspan's own fill and the rest go on its path; the text's
					# are on the group round them all.
					runs.append([_entities(parser.get_node_data()), top[0],
						top[1] if frames.size() > 1 else {}, pending.duplicate()])
					pending = [null, null, null, null]
				XMLParser.NODE_ELEMENT:
					var name: String = parser.get_node_name()
					var mine: Dictionary = _attributes(parser)
					if name == "textPath":
						undrawn.append("text on a path (<textPath>)")
					if parser.is_empty():
						continue
					depth += 1
					frames.append([_inherit((frames.back() as Array)[0], mine), mine])
					if name == "tspan":
						# Its own place, over the text's where the text's is not
						# used yet: <text x y><tspan>… starts at the text's x, y.
						var given: Array = [_first(mine, "x"), _first(mine, "y"), _first(mine, "dx"),
							_first(mine, "dy")]
						for n: int in 4:
							if given[n] != null:
								pending[n] = given[n]
				XMLParser.NODE_ELEMENT_END:
					depth -= 1
					if frames.size() > 1:
						frames.pop_back()
		end = parser.get_node_offset()
	# Spaces as SVG has them by default: runs of white space as one space,
	# none at either end of the text.
	var words: String = ""
	for run: Array in runs:
		var flat: String = str(run[0]).replace("\n", " ").replace("\r", " ").replace("\t", " ")
		while flat.contains("  "):
			flat = flat.replace("  ", " ")
		if words.ends_with(" ") and flat.begins_with(" "):
			flat = flat.substr(1)
		run[0] = flat
		# A line set at a place of its own reads after a space.
		var placed: bool = (run[3] as Array)[0] != null or (run[3] as Array)[1] != null
		if placed and not words.is_empty() and not words.ends_with(" ") and not flat.begins_with(" "):
			words += " "
		words += flat
	var laid: Dictionary = _lay(runs, own, props)
	undrawn.append_array(laid["undrawn"])
	return {"paths": laid["paths"], "end": end, "words": words.strip_edges(), "undrawn": undrawn}


## The first of a list attribute ("10 20 30" gives 10), or null.
static func _first(attributes: Dictionary, key: String) -> Variant:
	if not attributes.has(key):
		return null
	var list: PackedStringArray = str(attributes[key]).replace(",", " ").split(" ", false)
	return list[0].to_float() if not list.is_empty() else null


static func _entities(text: String) -> String:
	var out: String = text.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"") \
		.replace("&apos;", "'").replace("&nbsp;", " ")
	var numbered := RegEx.create_from_string("&#(x?)([0-9a-fA-F]+);")
	for found: RegExMatch in numbered.search_all(out):
		var code: int = found.get_string(2).hex_to_int() if found.get_string(1) == "x" \
			else found.get_string(2).to_int()
		out = out.replace(found.get_string(), String.chr(code))
	return out.replace("&amp;", "&")


## The runs of one <text> set as outlines, chunk by chunk (each new x or y
## starts one, as SVG anchors them): {"paths": markup, "undrawn": what had no
## glyph}.
static func _lay(runs: Array, own: Dictionary, props: Dictionary) -> Dictionary:
	var undrawn := PackedStringArray()
	var pen := Vector2(0.0, 0.0)
	var chunks: Array = []   ## each: {"anchor", "width", "paths": [[d, attributes]]}
	var chunk: Dictionary = {}
	for n: int in runs.size():
		var run: Array = runs[n]
		var words: String = run[0]
		var mine: Dictionary = run[1]
		var place: Array = run[3]
		if n == 0 or place[0] != null or place[1] != null:
			if place[0] != null:
				pen.x = float(place[0])
			if place[1] != null:
				pen.y = float(place[1])
			chunk = {"anchor": str(mine["text-anchor"]), "start": pen.x, "paths": []}
			chunks.append(chunk)
		if place[2] != null:
			pen.x += float(place[2])
		if place[3] != null:
			pen.y += float(place[3])
		if n == 0:
			words = words.lstrip(" ")
		if n == runs.size() - 1:
			words = words.rstrip(" ")
		if words.is_empty():
			continue
		var drawn: Dictionary = _glyphs(words, mine, pen)
		undrawn.append_array(drawn["missing"])
		pen = drawn["pen"]
		if not str(drawn["d"]).is_empty():
			(chunk["paths"] as Array).append([str(drawn["d"]), run[2]])
		chunk["end"] = pen.x
	var paths := PackedStringArray()
	for one: Dictionary in chunks:
		var width: float = float(one.get("end", one["start"])) - float(one["start"])
		var shift: float = -width * 0.5 if one["anchor"] == "middle" \
			else (-width if one["anchor"] == "end" else 0.0)
		for path: Array in one["paths"]:
			var inner: Dictionary = path[1]
			var d: String = str(path[0])
			paths.append("<path%s%s fill-rule=\"nonzero\" d=\"%s\"/>" % [
				_kept(inner, false),
				" transform=\"translate(%s 0)\"" % _num(shift) if absf(shift) > 0.0005 else "", d])
	var body: String = "".join(paths)
	# The text's own fill, stroke and transform on a group round its runs,
	# each run's own on its path.
	return {"paths": "<g%s>%s</g>" % [_kept(own, true), body], "undrawn": undrawn}


## The attributes of [param attributes] an outline keeps, as markup; the
## transform only when [param transform].
static func _kept(attributes: Dictionary, transform: bool) -> String:
	var out: String = ""
	for key: String in KEPT:
		if not attributes.has(key) or (key == "transform" and not transform):
			continue
		var value: String = str(attributes[key])
		if key == "style":
			# Fonts said in style= mean nothing to a path.
			var kept := PackedStringArray()
			for one: String in value.split(";", false):
				if not one.strip_edges().begins_with("font") and not one.strip_edges().begins_with("text-") \
						and not one.strip_edges().begins_with("dominant-baseline") \
						and not one.strip_edges().begins_with("letter-spacing"):
					kept.append(one.strip_edges())
			value = ";".join(kept)
			if value.is_empty():
				continue
		out += " %s=\"%s\"" % [key, value.xml_escape(true)]
	return out


## [param words] in [param props]'s font from [param pen] on the baseline:
## {"d": the path data, "pen": where the next glyph goes, "missing": what
## has no glyph}.
static func _glyphs(words: String, props: Dictionary, pen: Vector2) -> Dictionary:
	var size: float = _size(str(props["font-size"]), 16.0)
	var scale: float = size / AT
	var font: Font = _font(props)
	var server: TextServer = TextServerManager.get_primary_interface()
	var shaped: RID = server.create_shaped_text()
	server.shaped_text_add_string(shaped, words, font.get_rids(), AT)
	var glyphs: Array = server.shaped_text_get_glyphs(shaped)
	var spacing: float = _size(str(props["letter-spacing"]), size) \
		if str(props["letter-spacing"]) != "normal" else 0.0
	var baseline: float = 0.0
	match str(props["dominant-baseline"]):
		"middle", "central":
			baseline = (font.get_ascent(AT) - font.get_descent(AT)) * 0.5 * scale
		"hanging", "text-before-edge", "text-top":
			baseline = font.get_ascent(AT) * scale
		"text-after-edge", "ideographic", "text-bottom":
			baseline = -font.get_descent(AT) * scale
	var d := PackedStringArray()
	var missing := PackedStringArray()
	var x: float = pen.x
	for glyph: Dictionary in glyphs:
		var face: RID = glyph["font_rid"]
		var index: int = int(glyph["index"])
		var repeat: int = int(glyph.get("repeat", 1))
		var flags: int = int(glyph.get("flags", 0))
		var space: bool = flags & TextServer.GRAPHEME_IS_SPACE != 0 \
			or flags & TextServer.GRAPHEME_IS_VIRTUAL != 0
		if not face.is_valid() or index == 0 or flags & TextServer.GRAPHEME_IS_EMBEDDED_OBJECT != 0:
			if not space:
				var from: int = int(glyph.get("start", 0))
				missing.append("\"%s\" (no font here has a letter for it)"
					% words.substr(from, maxi(1, int(glyph.get("end", from + 1)) - from)))
		else:
			var origin := Vector2(x + float(glyph.get("x_off", 0.0)) * scale,
				pen.y + baseline + float(glyph.get("y_off", 0.0)) * scale)
			for _n: int in repeat:
				d.append(_contours(server, face, index, origin, scale))
		x += (float(glyph["advance"]) * scale + spacing) * repeat
	server.free_rid(shaped)
	return {"d": "".join(d), "pen": Vector2(x, pen.y), "missing": missing}


## The app's font, made bold or slanted as the text asks.
static func _font(props: Dictionary) -> Font:
	var base: Font = ThemeDB.fallback_font
	var weight: String = str(props["font-weight"]).to_lower()
	var bold: bool = weight in ["bold", "bolder"] or (weight.is_valid_int() and weight.to_int() >= 600)
	var slanted: bool = str(props["font-style"]).to_lower() in ["italic", "oblique"]
	if not bold and not slanted:
		return base
	var font := FontVariation.new()
	font.base_font = base
	if bold:
		font.variation_embolden = 0.6
	if slanted:
		font.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	return font


## One glyph's outline as path data, its origin at [param origin], scaled.
## The text server gives each contour's points with FreeType's tags: on
## the curve, a quadratic's control point (two in a row have an on-curve
## point between them), or a cubic's; y down, as SVG has it.
static func _contours(server: TextServer, face: RID, index: int, origin: Vector2,
		scale: float) -> String:
	var outline: Dictionary = server.font_get_glyph_contours(face, AT, index)
	if outline.is_empty():
		return ""
	var points: PackedVector3Array = outline["points"]
	var ends: PackedInt32Array = outline["contours"]
	var d := PackedStringArray()
	var start: int = 0
	for last: int in ends:
		var ring: Array = []
		for n: int in range(start, last + 1):
			ring.append(points[n])
		start = last + 1
		if ring.size() < 2:
			continue
		# Begin on a point on the curve; between two control points where
		# there is none.
		var first: int = -1
		for n: int in ring.size():
			if int((ring[n] as Vector3).z) == TextServer.CONTOUR_CURVE_TAG_ON:
				first = n
				break
		if first < 0:
			var a: Vector3 = ring[0]
			var b: Vector3 = ring[1]
			ring.push_front(Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, TextServer.CONTOUR_CURVE_TAG_ON))
			first = 0
		ring = ring.slice(first) + ring.slice(0, first)
		var to := func(p: Vector3) -> String:
			return "%s %s" % [_num(origin.x + p.x * scale), _num(origin.y + p.y * scale)]
		d.append("M" + to.call(ring[0]))
		var n: int = 1
		while n < ring.size():
			var p: Vector3 = ring[n]
			var tag: int = int(p.z)
			if tag == TextServer.CONTOUR_CURVE_TAG_ON:
				d.append("L" + to.call(p))
				n += 1
			elif tag == TextServer.CONTOUR_CURVE_TAG_OFF_CONIC:
				var control: Vector3 = p
				n += 1
				while true:
					if n >= ring.size():
						d.append("Q%s %s" % [to.call(control), to.call(ring[0])])
						break
					var next: Vector3 = ring[n]
					if int(next.z) == TextServer.CONTOUR_CURVE_TAG_ON:
						d.append("Q%s %s" % [to.call(control), to.call(next)])
						n += 1
						break
					var middle := Vector3((control.x + next.x) * 0.5, (control.y + next.y) * 0.5, 1.0)
					d.append("Q%s %s" % [to.call(control), to.call(middle)])
					control = next
					n += 1
			else:
				var c2: Vector3 = ring[n + 1] if n + 1 < ring.size() else ring[0]
				var stop: Vector3 = ring[n + 2] if n + 2 < ring.size() else ring[0]
				d.append("C%s %s %s" % [to.call(p), to.call(c2), to.call(stop)])
				n += 3
		d.append("Z")
	return "".join(d)


static func _num(value: float) -> String:
	return String.num(value, 2)
