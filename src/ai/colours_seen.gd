## How many colours a model shows, against what real sets of its kind show.
##
## The judge reads colour off the pictures, the design's beside the real
## set's. What separated the designs it called the set's equal in colour
## from those it called worse was how many colours the picture showed
## against the set's own (DESIGN_SCORES.md, "The colour read", 2026-11-01):
## real sets show about eight over 1% of the model, the designs fewer, and
## three levers that told a session to vary its colour moved nothing. This
## counts them in the picture the app already takes, as the judge sees them,
## and says how far short a design is of the sets of its theme or kind and
## its part count, and which colours those sets add a little of.
##
## A colour is seen when 1% of the model's pixels are nearest it, of the
## model's own solid colours as drawn (PartLibrary.shown_for), a face lit
## 0.7 to 1.1 times its colour; a pixel near none (an edge, a print, glass)
## is no colour's. Every fourth pixel of the corner picture: against the
## judge's three pictures read at half size, r 0.99, off by 0.2 on average.
##
## A real set's count is read off its parts list (tools/set_colours.py):
## its solid colours at 1.5% of its parts or more, which agrees with its
## pictures at r 0.84. Sets of the brief's theme and part count predict a
## held-out set's own count at r 0.84, off by 1.3; sets of its kind by a
## word of their names at r 0.62 on the 15 of 44 that have one, and sets of
## its part count alone not at all (r -0.21). So the theme first, the kind
## (as how_real_sets_build_this reads it) where a brief names no theme, and
## nothing where neither finds enough sets.
class_name ColoursSeen
extends RefCounted

const FILE := "res://assets/knowledge/set_colours.json.gz"
## A colour is seen over this share of the model's pixels.
const SEEN := 0.01
## A pixel is the model's when a channel is this far off the background, 0-255.
const OFF := 18
## How much darker and lighter than its colour a face is drawn.
const DARKEST := 0.7
const LIGHTEST := 1.1
## Farther than this from every colour of the model's, 0-255: no colour's.
const NEAR := 40.0
## Every fourth pixel: 256 x 256 of the 1024 drawn.
const STEP := 4
## A set's colour is seen at this many of every thousand of its parts.
const SET_SEEN := 15
## And added "at a small share" under this many.
const SMALL := 100
## Sets of the part count: within this factor of it, or this wider one when
## too few are; and at least this many sets, or nothing is said.
const BAND := 1.6
const WIDER := 2.5
const FEWEST := 8
## A colour is named when this share of the sets show it.
const NAMED := 0.3
const MOST_NAMED := 5

static var _read: Dictionary = {}
static var _tried: bool = false


## {"model": pixels of the model counted, "seen": [codes, most first],
## "shares": {code: share of the model's pixels}} of [param image], a
## picture of the model on a flat background, by [param palette] {code:
## Color as drawn}, every [param step]th pixel each way. Reads only its
## arguments: run on a worker.
static func count(image: Image, palette: Dictionary, step: int = STEP) -> Dictionary:
	var out: Dictionary = {"model": 0, "seen": [], "shares": {}}
	if image == null or image.is_empty() or palette.is_empty():
		return out
	var picture: Image = image
	if picture.get_format() != Image.FORMAT_RGB8:
		picture = image.duplicate()
		picture.convert(Image.FORMAT_RGB8)
	var data: PackedByteArray = picture.get_data()
	var width: int = picture.get_width()
	var codes: Array = palette.keys()
	var colours := PackedFloat32Array()
	var squared := PackedFloat32Array()
	for code: Variant in codes:
		var colour: Color = palette[code]
		var rgb := Vector3(colour.r, colour.g, colour.b) * 255.0
		colours.append_array([rgb.x, rgb.y, rgb.z])
		squared.append(maxf(rgb.length_squared(), 1.0))
	var back := Vector3i(data[0], data[1], data[2])
	var tally := PackedInt32Array()
	tally.resize(codes.size())
	var model: int = 0
	var near: float = NEAR * NEAR
	for y: int in range(0, picture.get_height(), step):
		for x: int in range(0, width, step):
			var at: int = (y * width + x) * 3
			var r: int = data[at]
			var g: int = data[at + 1]
			var b: int = data[at + 2]
			if absi(r - back.x) <= OFF and absi(g - back.y) <= OFF and absi(b - back.z) <= OFF:
				continue
			model += 1
			var best: int = -1
			var least: float = near
			for k: int in codes.size():
				var cr: float = colours[k * 3]
				var cg: float = colours[k * 3 + 1]
				var cb: float = colours[k * 3 + 2]
				var lit: float = clampf((r * cr + g * cg + b * cb) / squared[k], DARKEST, LIGHTEST)
				var dr: float = r - lit * cr
				var dg: float = g - lit * cg
				var db: float = b - lit * cb
				var off: float = dr * dr + dg * dg + db * db
				if off <= least:
					least = off
					best = k
			if best >= 0:
				tally[best] += 1
	out["model"] = model
	if model == 0:
		return out
	var seen: Array = []
	for k: int in codes.size():
		var share: float = float(tally[k]) / model
		out["shares"][codes[k]] = share
		if share >= SEEN:
			seen.append(codes[k])
	seen.sort_custom(func(a: Variant, b: Variant) -> bool:
		return float(out["shares"][a]) > float(out["shares"][b]))
	out["seen"] = seen
	return out


## The model's solid colours as drawn, {code: Color}: what count() reads a
## picture of it by. Transparent ones are left out, as glass is no colour's.
static func palette_of(bricks: Array, library: PartLibrary) -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		if out.has(brick.color_code):
			continue
		var colour: PartLibrary.BrickColor = library.color(brick.color_code)
		if not colour.is_transparent():
			out[brick.color_code] = colour.shown
	return out


## set_colours.json.gz: {"themes": [name], "sets": [[number, name, theme,
## parts, [[code, per mille]]]]}, or {} where this build has none.
static func sets() -> Dictionary:
	if not _tried and (not OS.has_feature("web") or FileAccess.file_exists(FILE)):
		_tried = true
		_read = RealSnippets.read(FILE)
	return _read


## Fetched on the web, where the build leaves it out of the pack. Awaited.
static func ensure(host: Node) -> void:
	if _tried or not OS.has_feature("web") or FileAccess.file_exists(FILE):
		return
	_tried = true
	_read = RealSnippets.parse(await RealSnippets.fetch(host, FILE.get_file()))


## The theme [param said] names: its index in [param among], sets()'s themes
## when none are given, or -1. Named as one first ("LEGO® City sets", "a LEGO
## City street sweeper", "Technic-style"), else as a word ("technic sports
## car"), the earliest in what was said. What a session says reads its
## brief's theme so in 41 to 42 of 44 bench designs and another in none
## (2026-11-01): the brief it passes submit_design, its calls' subjects, its
## design's description.
static func theme_in(said: String, among: Array = []) -> int:
	var low: String = said.to_lower()
	var themes: Array = among if not among.is_empty() else sets().get("themes", [])
	for ways: Array in [["\\blego\\S*\\s+%s\\b", "\\b%s[- ]style\\b", "\\b%s sets?\\b"], ["\\b%s\\b"]]:
		var first: int = -1
		var at: int = 0x7FFFFFFF
		for n: int in themes.size():
			var name: String = _escaped(str(themes[n]).to_lower())
			for way: String in ways:
				var found: RegExMatch = RegEx.create_from_string(way % name).search(low)
				if found != null and (found.get_start() < at or (found.get_start() == at
						and str(themes[n]).length() > str(themes[first]).length())):
					at = found.get_start()
					first = n
		if first >= 0:
			return first
	return -1


static func _escaped(text: String) -> String:
	var out: String = ""
	for character: String in text:
		out += "\\" + character if "\\^$.|?*+()[]{}".contains(character) else character
	return out


## The part count [param said] names, "350 to 580 pieces" as the middle of
## it; else [param asked], else [param standing].
static func parts_in(said: String, asked: int, standing: int) -> int:
	var found: RegExMatch = RegEx.create_from_string(
		"(?i)\\b(\\d{2,5})\\s*(?:to|-|–)\\s*(\\d{2,5})\\s*(?:parts|pieces|bricks)\\b").search(said)
	if found != null:
		return (int(found.get_string(1)) + int(found.get_string(2))) / 2
	return asked if asked > 0 else standing


## What real sets of the theme [param said] names (theme_in), or else of one
## of [param kinds], and of about [param parts] parts show, none of them under
## test (DesignMemory.holds): {"by": "City sets", "low", "high": their part
## counts, "sets", "q1", "median", "q3": their colours seen, "colours":
## [[code, share of the sets that show it, per mille of their parts]],
## "glass": the same of transparent colours}. {} when too few are known.
static func sets_like(said: String, kinds: PackedStringArray, parts: int,
		library: PartLibrary) -> Dictionary:
	var rows: Array = sets().get("sets", [])
	if rows.is_empty() or parts <= 0:
		return {}
	var picked: Array = []
	var by: String = ""
	var theme: int = theme_in(said)
	if theme >= 0:
		picked = _of_size(rows.filter(func(row: Variant) -> bool:
			return int((row as Array)[2]) == theme), parts)
		by = "%s sets" % str(sets()["themes"][theme])
	if picked.size() < FEWEST:
		for kind: String in kinds:
			picked = _of_size(rows.filter(func(row: Variant) -> bool:
				return name_words(str((row as Array)[1])).has(kind)), parts)
			by = "%s sets" % kind
			if picked.size() >= FEWEST:
				break
	if picked.size() < FEWEST:
		return {}
	var counts: Array[int] = []
	var shown: Dictionary = {}
	var low: int = 0x7FFFFFFF
	var high: int = 0
	for row: Array in picked:
		low = mini(low, int(row[3]))
		high = maxi(high, int(row[3]))
		var seen: int = 0
		for pair: Variant in row[4]:
			var code: int = int((pair as Array)[0])
			var mille: int = int((pair as Array)[1])
			var glass: bool = library.color(code).is_transparent()
			if not glass and mille >= SET_SEEN:
				seen += 1
			if glass or mille >= SET_SEEN:
				if not shown.has(code):
					shown[code] = []
				(shown[code] as Array).append(mille)
		counts.append(seen)
	counts.sort()
	var colours: Array = []
	var glass: Array = []
	for code: int in shown:
		var milles: Array = shown[code]
		milles.sort()
		var entry: Array = [code, float(milles.size()) / picked.size(), int(milles[milles.size() / 2])]
		if library.color(code).is_transparent():
			glass.append(entry)
		elif int(entry[2]) < SMALL:
			colours.append(entry)
	var most_first := func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1])
	colours.sort_custom(most_first)
	glass.sort_custom(most_first)
	return {"by": by, "low": low, "high": high, "sets": picked.size(),
		"q1": counts[counts.size() / 4], "median": counts[counts.size() / 2],
		"q3": counts[counts.size() * 3 / 4], "colours": colours, "glass": glass}


## Of [param rows], those within BAND of [param parts] parts (WIDER when too
## few are) that are not under test.
static func _of_size(rows: Array, parts: int) -> Array:
	var out: Array = []
	for wide: float in [BAND, WIDER]:
		out = rows.filter(func(row: Variant) -> bool:
			var n: int = int((row as Array)[3])
			return n >= parts / wide and n <= parts * wide \
				and not DesignMemory.holds(str((row as Array)[0]), str((row as Array)[1])))
		if out.size() >= FEWEST:
			break
	return out


## A set's name as its kind is read off it (tools/rebrickable.py kinds):
## its lowercased words of three letters or more, no numbers.
static func name_words(name: String) -> PackedStringArray:
	var out := PackedStringArray()
	for found: RegExMatch in RegEx.create_from_string("[a-z0-9]+").search_all(name.to_lower()):
		var word: String = found.get_string()
		if word.length() >= 3 and not word.is_valid_int():
			out.append(word)
	return out


## The finding, when the model shows fewer colours than the sets' usual
## count: how many it shows and they show, and the colours they add a little
## of that it does not show. "" when it is not short, or nothing is known.
static func said(seen: Array, ref: Dictionary, library: PartLibrary) -> String:
	if ref.is_empty() or seen.size() >= int(ref["median"]):
		return ""
	var named := func(code: int) -> String:
		return "%s (%d)" % [library.color(code).name, code]
	var shows := PackedStringArray()
	for code: Variant in seen:
		shows.append(str(library.color(int(code)).name))
	var lines := PackedStringArray()
	lines.append(("Colour: from the corner it shows %d colours over 1%% of the model (%s); "
		% [seen.size(), ", ".join(shows)])
		+ ("%s of %d to %d parts show %d to %d, most often %d (%d sets, none under test). "
			% [ref["by"], ref["low"], ref["high"], ref["q1"], ref["q3"], ref["median"], ref["sets"]])
		+ "A design showing fewer than its set is scored lower for colour.")
	var adds := PackedStringArray()
	for entry: Array in ref["colours"]:
		if seen.has(int(entry[0])) or float(entry[1]) < NAMED or adds.size() >= MOST_NAMED:
			continue
		adds.append("%s in %d%% of them, about %s%% of their parts" % [named.call(int(entry[0])),
			roundi(float(entry[1]) * 100), String.num(float(entry[2]) / 10.0, 1)])
	if not adds.is_empty():
		lines.append("What those sets add a little of, which it does not show: "
			+ "; ".join(adds) + ".")
	var glass := PackedStringArray()
	for entry: Array in ref["glass"]:
		if float(entry[1]) >= NAMED and glass.size() < 3:
			glass.append("%s in %d%%" % [named.call(int(entry[0])), roundi(float(entry[1]) * 100)])
	if not glass.is_empty():
		lines.append("And glass, which counts for none of these: %s of them." % ", ".join(glass))
	lines.append("Add them as real sets do, in small parts where something happens: trim, "
		+ "a window frame, a sign, a lamp, a second grey in a recess or under an overhang. "
		+ "Don't recolour a wall, a roof or a hull: the big masses keep their colour.")
	return "\n".join(lines)
