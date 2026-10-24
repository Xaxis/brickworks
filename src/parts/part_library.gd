## The catalogue of every part, and the geometry cache behind it.
##
## Two separate things live here on purpose. The [b]catalogue[/b] is small,
## always resident, and answers questions about parts — what exists, how big
## it is, where its studs are. The [b]geometry[/b] is large, loaded only for
## parts actually placed, and thrown away under memory pressure.
##
## That split is what makes a 19,000 part library usable. Browsing the
## catalogue, searching it, and letting the design assistant reason over it
## all touch metadata only; a few megabytes of JSON rather than a gigabyte
## of vertices.
class_name PartLibrary
extends RefCounted

## Where the assets live. The full library is 875 MB of geometry, which
## is fine to ship in a desktop binary and out of the question over the
## wire, so the web build carries a curated pack of 881 parts instead.
##
## Which one wins depends on the build, and getting that backwards is
## expensive: preferring the pack everywhere meant the desktop app — with
## the whole library sitting on disk beside it — offered 881 parts, and
## the design assistant noticed before I did, reporting that "search is
## returning a thin slice of the catalogue".
const FULL_ROOT := "res://assets/generated/"
const PACK_ROOT := "res://assets/web/"

var _root: String = ""


## Pick the asset root once, so the catalogue and the meshes cannot
## disagree about which build this is.
func _resolve_root() -> String:
	if not _root.is_empty():
		return _root
	# The full library first everywhere it exists; the pack is what the
	# web build ships and the only thing it has.
	# Written out rather than as a ternary: a conditional array literal is
	# untyped, and assigning it to Array[String] is an error at runtime.
	var order: Array[String] = []
	if OS.has_feature("web"):
		order = [PACK_ROOT, FULL_ROOT]
	else:
		order = [FULL_ROOT, PACK_ROOT]
	for candidate: String in order:
		if FileAccess.file_exists(candidate + "catalogue.json"):
			_root = candidate
			return _root
	_root = FULL_ROOT
	return _root


## The kinds of real set a brief is describing, most specific first.
##
## Matching a brief's words against the names of fifteen thousand real
## sets, which is crude and works: "a medieval fire station" finds the
## fire kind, and what fire sets are built from is a tap, a steering
## stand and trans-blue.
##
## Most specific first — fewest sets — because the narrow kind is the
## informative one. "castle" over 175 sets says more than "house" over
## 208, and a brief that matches both wants the castle.
func kinds_for(words: String, most: int = 3) -> Array:
	if kinds.is_empty():
		return []
	var found: Array = []
	var seen: Dictionary = {}
	var place: int = 0
	# A brief says castles and the catalogue says castle; it says spaceship
	# where the catalogue, reading real set names, says space. Whole words
	# only (SubjectWords): any kind a word began with was taken, so a
	# planetarium and an orrery's planets were the plane kind, tail planes
	# and jet engines. A word made of two may be two kinds, what it is
	# first: a firetruck is a truck, then fire's; and so are two words side
	# by side, a fire truck, in a phrase: "a castle, tower" is two things.
	for phrase: PackedStringArray in SubjectWords.phrases(words):
		for read: PackedStringArray in SubjectWords.kinds_of_phrase(phrase, kinds):
			place += 1
			var within: float = 0.0
			for form: String in read:
				if seen.has(form):
					continue
				seen[form] = true
				var entry: Dictionary = (kinds[form] as Dictionary).duplicate()
				entry["kind"] = form
				entry["place"] = place + within
				within += 1.0 / (read.size() + 1)
				found.append(entry)
	# In the order the brief names them, because a brief names its subject
	# first and its features after. Fewest sets first was the rule, and
	# "a large space cruiser with ... two engine pods" came back as engine,
	# cruiser and pod: fire-engine ladders and X-Pod storage tubs, with
	# space pushed out for having more sets. Generic words that once
	# needed the specific rule are a word list now (NOT_A_KIND).
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["place"]) < float(b["place"]))
	if found.size() > most:
		found.resize(most)
	return found


## What a real set of this many parts is made of, or an empty Dictionary
## when nothing is known or the model is smaller than any real set.
func normal_for(parts: int) -> Dictionary:
	for band: Variant in set_norms:
		var entry: Dictionary = band
		if parts >= int(entry.get("from", 0)) \
				and parts < int(entry.get("to", 0)):
			return entry
	return {}


## The LEGO element number for a part in a colour, or "" when there is
## none.
##
## Empty is the common case and means nothing is known: the table has
## 40,474 pairs and real sets contain millions, so a design is still
## perfectly buildable without one. It must never be shown as though the
## element did not exist.
func element_for(part_id: String, code: int) -> String:
	if not _looked_for_elements:
		_looked_for_elements = true
		var path: String = _resolve_root() + "elements.json"
		if FileAccess.file_exists(path):
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			if file != null:
				var raw: Variant = JSON.parse_string(file.get_as_text())
				file.close()
				if typeof(raw) == TYPE_DICTIONARY:
					var pairs: Variant = (raw as Dictionary).get("pairs", {})
					if typeof(pairs) == TYPE_DICTIONARY:
						_elements = pairs
	var found: String = str(_elements.get("%s/%d" % [part_id, plain_code(code)], ""))
	# LDraw draws cloth twice, flat as it is sold (50231) and as it is
	# worn (50231c01 "Cape Cloth (Formed)"); Rebrickable lists the element
	# once, by its flat number. A figure wears the worn drawing.
	var info: PartInfo = parts.get(part_id)
	if found.is_empty() and info != null and info.name.contains("(Formed") \
			and part_id.length() > 3 and part_id[-3] == "c" and part_id.right(2).is_valid_int():
		return element_for(part_id.left(-3), code)
	return found


## The colour a part in this code is filed under by LEGO and Rebrickable:
## a rubber or canvas variant's ordinary colour, otherwise the code
## itself. A tyre drawn in Rubber Black is a Black tyre to a shop.
func plain_code(code: int) -> int:
	var found: BrickColor = colors.get(code)
	return found.plain_code if found != null else code


## The colour [param part] was made in nearest [param code] as an eye judges
## (CIEDE2000, Brickify.de2000), a transparent one for a transparent colour
## where it was made in any: what a design is given in place of a colour the
## catalogue knows the part was never made in (PartInfo.never_made_in, as the
## Tested mark asks it). [param code] itself where it was, where nothing is
## known, and for a code that is no colour a part can be.
func made_nearest(part: String, code: int) -> int:
	var info: PartInfo = parts.get(part)
	var want: BrickColor = colors.get(code)
	if info == null or want == null or not want.is_plastic() or not info.never_made_in(code):
		return code
	var here: Vector3 = HiddenColours.lab(want.rgb)
	var best: int = code
	var gap: float = INF
	for alike: bool in [true, false]:
		for made: int in info.colors:
			var colour: BrickColor = colors.get(made)
			if colour == null or not colour.is_plastic() \
					or alike and colour.is_transparent() != want.is_transparent():
				continue
			var apart: float = Brickify.de2000(here, HiddenColours.lab(colour.rgb))
			if apart < gap:
				gap = apart
				best = made
		if best != code:
			break
	return best


## BrickLink's colour numbers -> LDraw's plain colour for each, filled as the
## colours load: for reading a Studio file's model2.ldr.
static var by_bricklink: Dictionary = {}


## The colour number a BrickLink wanted list or catalogue page names this
## code by: its plain colour's (a Rubber Black tyre is a Black one), or -1
## where BrickLink has none known, which is left off and never guessed.
func bricklink_colour(code: int) -> int:
	var found: BrickColor = colors.get(plain_code(code))
	return found.bricklink if found != null else -1


## The number [param shop] ("BrickLink" or "Rebrickable") lists a part
## under: the one LDraw records for it ("BrickLink 78c09", a ribbed hose
## 9L that LDraw numbers 71917), else LDraw's own, less a formed shape's
## "-f1", which is the same part to a shop.
func shop_part(part_id: String, shop: String) -> String:
	var info: PartInfo = parts.get(part_id)
	if info != null:
		var prefix: String = shop + " "
		for word: String in info.keywords:
			if word.begins_with(prefix) and word.get_slice_count(" ") == 2:
				return word.get_slice(" ", 1)
	var formed: int = part_id.rfind("-f")
	if formed > 0 and part_id.substr(formed + 2).is_valid_int():
		return part_id.substr(0, formed)
	return part_id


## The part here a shop's number names, or "": the part that carries it as
## its "BrickLink 3062" keyword (3062b; LDraw records the shop's number where
## it is not LDraw's own), else the part numbered so, else the same mould
## under a letter, as the part made now in that shape (current). How a
## photo's BrickLink numbers become parts (Brickognize).
func by_shop(number: String, shop: String = "BrickLink") -> String:
	var wanted: String = number.strip_edges().to_lower()
	if wanted.is_empty():
		return ""
	if not _by_shop.has(shop):
		var named: Dictionary = {}
		var prefix: String = shop.to_lower() + " "
		for id: String in parts:
			var info: PartInfo = parts[id]
			if info.is_redirect():
				continue
			for word: String in info.keywords:
				if word.to_lower().begins_with(prefix) and word.get_slice_count(" ") == 2:
					var theirs: String = word.get_slice(" ", 1).to_lower()
					# Two parts named so: the shorter number, the plain mould.
					if not named.has(theirs) or id.length() < str(named[theirs]).length():
						named[theirs] = id
		_by_shop[shop] = named
	var found: String = str((_by_shop[shop] as Dictionary).get(wanted, ""))
	if found.is_empty():
		for id: String in [wanted, wanted + "b", wanted + "a", wanted + "c"]:
			if parts.has(id):
				found = id
				break
	return "" if found.is_empty() else current(found)


## Shop -> {its number, in lower case -> the part here} (by_shop).
var _by_shop: Dictionary = {}


## What a part is, without its geometry.
class PartInfo extends RefCounted:
	var id: String              ## LDraw number, e.g. "3001"
	var name: String            ## "Brick  2 x  4"
	var category: String
	var kind: String            ## Part / Shortcut / Part Alias / ...
	var mesh_hash: String       ## names the .lbm file
	var triangles: int
	var size: Vector3           ## LDU
	var bounds: AABB
	var stud_count: int
	var socket_count: int
	var box_count: int
	var recolourable: bool
	var unofficial: bool
	## False when this build ships no geometry for the part, which is the
	## normal case on the web for anything outside the pack.
	var packed: bool = true
	## False when the part cannot be had at all in this build — not
	## shipped and not served. The difference matters: an unpacked part
	## is a short wait, an unreachable one is a dead end, and only the
	## second should be hidden.
	var reachable: bool = true
	## When this id is only a redirect, the part it was renamed to. 1,160
	## entries in the library are stubs like "~Moved to 3665": they render
	## correctly, because each forwards to its target, but they are not
	## things anyone should be offered.
	var moved_to: String = ""
	## And where the stub puts that part, in the stub's own frame: a turn or
	## a shift for 68 of them (3139, a tyre, forwards to 3139b a quarter
	## turn round), the identity for the rest.
	var moved_by: Transform3D = Transform3D.IDENTITY

	## The one colour LDraw draws it in whatever it is placed in, for one of
	## its "physical colour" parts (303923, a slope brick in blue, kept for
	## old files); -1 for every other part.
	var fixed_colour: int = -1

	func is_redirect() -> bool:
		return not moved_to.is_empty()

	## The colours LEGO really moulded this part in, as LDraw codes, and
	## the subset still appearing in sets since PartLibrary.recent_since.
	## Empty means nobody knows: two thirds of the library has no
	## inventory data behind it, so emptiness is never evidence.
	var colors: PackedInt32Array
	var colors_recent: PackedInt32Array
	## How many catalogued sets this part is in. Zero means nobody knows
	## — four fifths of the library does not join to a set inventory — so
	## it may never be read as "never used", only as "not known to be a
	## staple". What a name cannot tell you: 3062b, the 1x1 round brick,
	## is in 4,496 sets and 71075a is in seventeen, and both are named
	## like the ordinary thing.
	var in_sets: int = 0
	## In how many sets the set inventories have it, and how many pieces of
	## it they hold in all (assets/ldraw/part_usage.json): prints and a
	## figure's parts too, which in_sets does not reach. Zero is silence.
	var used_in: int = 0
	var pieces: int = 0
	## For an assembly LDraw draws whole ("Window 1 x 2 x 3 without Sill w/
	## Trans-Clear Glass (Complete)", 60593c01), the part it is built on:
	## 60593. Empty for every other part.
	var whole_of: String = ""
	var _whole: PartInfo = null
	## Which listing of the parts bin it was last in (PartsBin._fold), so a
	## print is folded under its part only when the part is listed too.
	var listed_in: int = 0

	## The part it is a print, a stickered version or an assembly of, or null.
	func folds_under() -> PartInfo:
		return _plain if _plain != null else _whole

	## How much real sets use it: the sets it is in and, for half as much,
	## the pieces of it they hold, each counted logarithmically, since a part
	## in ten sets against one in a hundred matters and five thousand against
	## nine does not. 2780, the black friction pin, is in as many sets as
	## 43093 and in two and a half times its pieces. An assembly no set lists
	## whole, which the inventories list as its parts, is used as its part is.
	## Zero when nothing is known, which is never evidence of disuse.
	func commonness() -> float:
		var sets: int = maxi(used_in, in_sets)
		if sets <= 0:
			# A hair under its part's, so the part itself is listed first.
			return 0.0 if _whole == null else _whole.commonness() * 0.999
		return log(1.0 + sets) + 0.5 * log(1.0 + maxi(pieces, sets))
	## The years this part first and last appeared in a catalogued set.
	var first_year: int = 0
	var last_year: int = 0
	## True when `colors` is known to be short: the part was made in a
	## Rebrickable colour the join cannot name in LDraw terms (HO, vintage,
	## Clikits and the like — sixty-one of them), or its list comes from
	## element numbers alone with no set inventory behind it. Nothing may
	## read a gap in a short list as proof the colour was never made.
	var colors_partial: bool = false

	## Whether anything is known about what this part was moulded in.
	func availability_known() -> bool:
		return not colors.is_empty()

	## Whether this part is known *never* to have been made in a colour.
	## Deliberately hard to get a true out of: it wants a colour list
	## that is both present and complete. Everything else is silence,
	## because telling a designer a part does not exist in a colour it
	## does exist in costs more than saying nothing.
	func never_made_in(code: int) -> bool:
		if colors.is_empty() or colors_partial:
			return false
		return not colors.has(code)

	## Whether the part has been in a set recently enough to buy. Only
	## meaningful when something is known about it at all.
	func still_made() -> bool:
		return not colors_recent.is_empty()
	var keywords: PackedStringArray
	## The words set inventories name it by that its name does not have
	## (assets/ldraw/part_names.json): "curved macaroni" on 27507, Tile 4 x 4
	## Corner Round. Searched as its name is.
	var also_called: String = ""
	## Counts by connector kind. The connectors themselves live in the
	## .lbm beside the geometry and arrive with it; keeping them here took
	## the catalogue past 25 MB, to answer questions about parts nobody
	## had placed.
	var connector_counts: Dictionary = {}
	## True for a part made in the element maker rather than moulded by
	## LEGO. Its category is "Custom", so the bin shows them together;
	## [member ldraw_category] is what its own header says it is.
	var custom: bool = false
	var ldraw_category: String = ""
	## Where a custom part shipped in the catalogue keeps its LDraw source,
	## under the asset root (tools/build_custom.py --into).
	var source_path: String = ""
	## For a model file's own copy of a part LEGO made, drawn as that part
	## is (CustomParts.copy_of): the part's id, whose joints, cover and
	## exact shape it is read with. Empty for every other part.
	var copy_of: String = ""

	## What kind of part this is to the LDraw world: a custom tile is a
	## Tile, whatever the bin files it under.
	func family_category() -> String:
		return ldraw_category if custom and not ldraw_category.is_empty() else category

	func has_connector(kind: String) -> bool:
		return int(connector_counts.get(kind, 0)) > 0

	## What is on the part besides plastic, as bits: a print, which LDraw
	## names a Pattern; a sticker put on it, which LDraw files as a Sticker
	## Shortcut; or, alone, a sticker itself. Forty-nine parts have a print
	## and a sticker both.
	const PRINTED := 1
	const STICKERED := 2
	const STICKER := 4

	## Which of those it is, read from what LDraw calls it, 0 for plain.
	func decor() -> int:
		if _decor < 0:
			_decor = PartLibrary.decor_of(name, category)
		return _decor

	## The plain part a print or a stickered part is a version of: 3623
	## for 3623pt1, 3068b for 3068bd2j. Empty for a plain part and for the
	## 584 decorated parts whose plain part the catalogue does not have.
	var print_of: String = ""
	var _plain: PartInfo = null
	var _printed: String = ""
	var _decor: int = -1

	## What is printed or stuck on it: the words of its name the plain
	## part's has not got, '"PORSCHE" First Half' for 3623pt1, or what
	## follows the first "with" when there is no plain part.
	##
	## Not the name less the plain one's from the front: 1995p01 is "Flame
	## / Vapor Trail 3 x 12 with Axle Hole and Bright Light Yellow Marbled
	## Core", 1995 the same without the colour, and the whole name left in
	## made it a print of a flame.
	func printed() -> String:
		if not _printed.is_empty() or decor() == 0:
			return _printed
		var words: PackedStringArray = name.split(" ", false)
		if _plain != null:
			var plain_words: PackedStringArray = _plain.name.to_lower().split(" ", false)
			var kept := PackedStringArray()
			for word: String in words:
				if not plain_words.has(word.to_lower()):
					kept.append(word)
			words = kept
		elif name.contains(" with "):
			words = name.substr(name.find(" with ")).split(" ", false)
		if not words.is_empty() and words[0].to_lower() == "with":
			words = words.slice(1)
		if not words.is_empty() \
				and words[-1].to_lower() in ["pattern", "patt.", "sticker", "stickers"]:
			words = words.slice(0, -1)
		_printed = " ".join(words)
		return _printed
	var _own: String = ""
	var _keyed: String = ""

	## The words a search finds it by, lowercase: its number, name and
	## category, and "print" or "sticker" for what is on it, which LDraw's
	## names say as Pattern and Sticker and a builder says as print.
	func own_words() -> String:
		if _own.is_empty():
			_own = own_words_now()
		return _own

	## [method own_words] worked out and not kept: what the search's index is
	## made of on a thread of its own, which must write nothing a part holds.
	func own_words_now() -> String:
		var on: int = PartLibrary.decor_of(name, category)
		var words: String = "%s %s %s" % [id, name, category]
		if on & PRINTED:
			words += " print"
		if on & (STICKERED | STICKER):
			words += " sticker"
		return words.to_lower()

	## Its !KEYWORDS, lowercase: what it was made for ("Porsche", "Speed
	## Champions"), the sets it came in and its numbers at the shops, less
	## the shops' names. "brick" is in every one of those, and with them
	## a search for "brick" found 17,039 parts where it had found 3,633.
	func keyword_words() -> String:
		if _keyed.is_empty() and not keywords.is_empty():
			_keyed = keyword_words_now()
		return _keyed

	## [method keyword_words] worked out and not kept (own_words_now).
	func keyword_words_now() -> String:
		var words := PackedStringArray()
		for keyword: String in keywords:
			var word: String = keyword.to_lower()
			for shop: String in NOT_WORDS:
				if word.begins_with(shop):
					word = word.substr(shop.length())
					break
			words.append(word)
		return " ".join(words)

	const NOT_WORDS: Array[String] = ["bricklink ", "rebrickable ", "brickowl ",
		"brick owl ", "brickset ", "set "]

	## Footprint in whole studs, rounded up. Useful for sorting and for
	## the assistant's reasoning; not a substitute for real collision.
	func footprint_studs() -> Vector2i:
		return Vector2i(
			maxi(1, ceili((size.x - BrickLattice.CLEARANCE) / 20.0)),
			maxi(1, ceili((size.z - BrickLattice.CLEARANCE) / 20.0)))


## A colour the palette knows about.
class BrickColor extends RefCounted:
	## How the plastic is drawn. The shader reads this number per brick
	## (plastic_body.gdshaderinc, FINISH_*), so the two lists are one list
	## and the order matters.
	enum Finish {
		PLASTIC, CHROME, METAL, PEARL, SPECKLE, GLITTER, OPAL, GLOW,
		FLUORESCENT, RUBBER, FABRIC, MILKY,
	}

	var code: int
	var name: String
	var rgb: Color
	## The colour the renderer draws, which is rgb but for black: see
	## PartLibrary.shown_for(). Drawing only — a parts list, an export and
	## the mosaic's matching all keep to rgb.
	var shown: Color
	var edge: Color
	var alpha: int
	var finish: String          ## solid / transparent / chrome / ...
	## The LDConfig section it is declared in: "solid", "transparent",
	## "rubber", "internal common material", ...
	var group: String = ""
	## LEGO's own name and numbers, from LDConfig: LDraw's Light Bluish
	## Grey is LEGO's Medium Stone Grey, 194. Empty where LDConfig gives
	## none.
	var lego_name: String = ""
	var lego_ids: PackedInt32Array = PackedInt32Array()
	## Rebrickable's number for it, or -1 where the join reaches none.
	var rebrickable_id: int = -1
	## BrickLink's number for it (colors.json, from
	## tools/bricklink_colours.py), or -1 where BrickLink has none known.
	var bricklink: int = -1
	## The years it was in catalogued sets, and in how many. Zero when
	## nothing is known, which is never evidence it was not made.
	var first_year: int = 0
	var last_year: int = 0
	var sets: int = 0
	## In sets of the last couple of years, by Rebrickable's inventories.
	var current: bool = false
	## For a rubber or canvas colour, the ordinary colour it is — what a
	## shop and Rebrickable file a black tyre under. Otherwise its own code.
	var plain_code: int = 0
	## LDConfig's LUMINANCE, 0-255: how much the plastic gives off light.
	var luminance: int = 0
	## The second colour in the plastic — a speckle's or a glitter's
	## flecks — and how much of the surface it covers. From LDConfig's
	## MATERIAL line; black and nothing for most colours.
	var fleck: Color = Color.BLACK
	var fleck_fraction: float = 0.0
	var drawn_as: int = Finish.PLASTIC
	## What BrickWorld hands the shader for every brick in this colour:
	## the fleck colour, and the finish number plus the fleck fraction in
	## the fourth channel. Packed once here rather than per brick.
	var instance_custom: Color = Color(0, 0, 0, 0)

	## Fill in instance_custom from the finish and the fleck. The fraction
	## is kept below one so the finish number survives in the integer
	## part, which the Compatibility renderer carries as a half float.
	func pack_finish() -> void:
		instance_custom = Color(fleck.r, fleck.g, fleck.b,
			float(drawn_as) + minf(fleck_fraction, 0.95))

	## Whether it is drawn see-through. Glow-in-the-dark plastic is filed
	## at alpha 245 and is milky-opaque in the hand ("Glow In Dark
	## Opaque" is its name); drawn transparent it was a ghost of a brick.
	func is_transparent() -> bool:
		return alpha < 255 and not (drawn_as == Finish.GLOW and alpha >= 240)

	## What it is, said the way a builder would: "chrome", "glitter".
	func finish_name() -> String:
		if drawn_as == Finish.PLASTIC and is_transparent():
			return "transparent"
		return FINISH_NAMES[drawn_as]

	## Whether a part can be this colour. 16 and 24 are LDraw's "inherit"
	## codes, and the rest of LDConfig's internal section is sticker film
	## and electrical contacts; "obsolete" is a code LDraw retired. They
	## are in the palette because LDConfig declares them, and nothing
	## should be built in them.
	func is_plastic() -> bool:
		return group != "internal common material" and group != "obsolete"


const FINISH_NAMES: Array[String] = [
	"solid", "chrome", "metallic", "pearl", "speckle", "glitter",
	"opal", "glow in the dark", "fluorescent", "rubber", "fabric", "milky",
]


## What the renderer draws for a palette value: the value itself, except
## for black.
##
## LDraw's black is #1B2A34 and LEGO's own is #05131D, both blue-blacks,
## chosen so black reads as black on a screen with nothing around it.
## Lit, which every face in the app is, the dark is what the light lifts
## and the blue is what is left: a black tower read as navy. So plastic
## both dark and nearly grey — which is the black family and nothing
## else in the palette — keeps its lightness and loses most of its tint.
## A real colour that is dark is not nearly grey: Dark Blue and Dark
## Brown are untouched.
static func shown_for(rgb: Color) -> Color:
	var lab: Vector3 = Mosaic._oklab(rgb)
	if lab.x >= 0.35 or Vector2(lab.y, lab.z).length() >= 0.04:
		return rgb
	var drawn: Color = Mosaic._from_oklab(
		Vector3(lab.x, lab.y * 0.25, lab.z * 0.25)).linear_to_srgb()
	return Color(clampf(drawn.r, 0.0, 1.0), clampf(drawn.g, 0.0, 1.0),
		clampf(drawn.b, 0.0, 1.0), rgb.a)


## How a colour's plastic is drawn, from what LDConfig says of it.
##
## LDConfig names chrome, metal, pearl, rubber and the rest as finishes,
## and carries glitter and speckle as a MATERIAL with its own colour.
## Two it does not name, and both are visibly their own plastic: the
## trans-neon colours fluoresce, and milky white scatters light like a
## lampshade. Those are known by name, which is how LEGO tells them apart.
static func finish_for(finish: String, name: String, material_kind: String) -> int:
	match finish:
		"chrome":
			return BrickColor.Finish.CHROME
		"metal":
			return BrickColor.Finish.METAL
		"pearlescent":
			return BrickColor.Finish.PEARL
		"speckle":
			return BrickColor.Finish.SPECKLE
		"glitter":
			return BrickColor.Finish.GLITTER
		"opalescent":
			return BrickColor.Finish.OPAL
		"glow":
			return BrickColor.Finish.GLOW
		"rubber":
			return BrickColor.Finish.RUBBER
		"fabric":
			return BrickColor.Finish.FABRIC
	if material_kind == "glitter":
		return BrickColor.Finish.GLITTER
	if material_kind == "speckle":
		return BrickColor.Finish.SPECKLE
	if name.contains("Neon"):
		return BrickColor.Finish.FLUORESCENT
	if name.contains("Milky"):
		return BrickColor.Finish.MILKY
	return BrickColor.Finish.PLASTIC


## Where a part's geometry is fetched from when this build does not
## carry it. Set at start-up: on the web it is the deployment root, or
## wherever the deployment says the geometry lives, because the library
## is larger than a deployment can hold as files.
var remote_parts: String = "":
	set(value):
		remote_parts = value
		if not value.is_empty():
			_release_waiting()

## Parts asked for before the deployment said where geometry lives.
var _waiting: PackedStringArray = PackedStringArray()

var parts: Dictionary = {}          ## String id -> PartInfo
var colors: Dictionary = {}         ## int code -> BrickColor
var _ordered_ids: PackedStringArray = PackedStringArray()
## The year from which PartInfo.colors_recent counts as current, and
## where the availability data came from. Zero when the catalogue was
## built without it, which a clone that has not fetched the tables is.
var recent_since: int = 0
var availability_source: String = ""
## What a real LEGO set of a given size is made of, measured over every
## catalogued set. Each band is {from, to, sets, lots, shapes,
## most_of_one, colours}. Empty when the catalogue was built without the
## Rebrickable tables.
var set_norms: Array = []
## Word -> what real sets of that kind are built from:
## {sets, parts: [[id, lift]], colors: [[code, lift]], props: [...]}.
## A "kind" is a word in a real set's name, which is crude and is also
## what a brief says. Lift rather than count, so the answer is what is
## characteristic of castle sets and not the plates every set is made
## of. Empty when the catalogue was built without the Rebrickable
## tables.
var kinds: Dictionary = {}
var kinds_measured_over: int = 0
## Part and colour -> the LEGO element number to order, read from
## elements.json the first time anything asks. Its own file and loaded
## on demand because it is 0.8 MB that only a parts list needs, where
## the catalogue is loaded at start-up by everything.
var _elements: Dictionary = {}
var _looked_for_elements: bool = false
var _mesh_cache: Dictionary = {}    ## String hash -> Lbm.PartMesh
var _missing: Dictionary = {}       ## hashes already reported, to log once
## hash -> the part ids that asked for it, while it is fetched or waits to be
## asked again ([constant RETRY_AFTER]), so nothing fetches twice.
var _fetching: Dictionary = {}
## Waiting their turn. The parts bin asks for a thumbnail per visible
## cell, so without a ceiling a single scroll opens a hundred connections
## at once and every one of them finishes later than it would have.
var _queued_fetches: PackedStringArray = PackedStringArray()
var _fetch_host: Node = null

## Emitted when a part fetched from the network is ready to place.
signal fetched(part_id: String)
## Emitted when one cannot be had at all, asked again where that may help.
signal fetch_failed(part_id: String, reason: String)

## Emitted once the catalogue is parsed and the library is usable.
signal loaded(part_count: int)


func load_catalogue(path: String = "") -> bool:
	if path.is_empty():
		path = _resolve_root() + "catalogue.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("part library: no catalogue at %s — run tools/build_meshes.py" % path)
		return false

	var raw: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("part library: catalogue at %s is not valid JSON" % path)
		return false

	var document: Dictionary = raw
	var norms: Dictionary = document.get("set_norms", {})
	var bands: Variant = norms.get("bands", [])
	if typeof(bands) == TYPE_ARRAY:
		set_norms = bands
	var builds: Dictionary = document.get("kinds", {})
	var by_word: Variant = builds.get("kinds", {})
	if typeof(by_word) == TYPE_DICTIONARY:
		kinds = by_word
		kinds_measured_over = int(builds.get("measured_over", 0))
	var made: Dictionary = document.get("availability", {})
	recent_since = int(made.get("recent_since", 0))
	availability_source = str(made.get("source", ""))
	var entries: Array = document.get("parts", [])
	for entry: Variant in entries:
		var info: PartInfo = _read_part(entry)
		parts[info.id] = info
		_ordered_ids.append(info.id)
	_index_prints()
	_read_names()
	_read_usage()
	_index_wholes()
	_search_index = null
	_current_lock.lock()
	_current_of.clear()
	_current_lock.unlock()

	_load_colors()
	loaded.emit(parts.size())
	return true


## What set inventories call each part, where LDraw's name says otherwise
## (tools/part_names.py). Without the file a part is searched by its own name.
const NAMES := "res://assets/ldraw/part_names.json"


func _read_names() -> void:
	if not FileAccess.file_exists(NAMES):
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(NAMES))
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var words: Dictionary = (raw as Dictionary).get("words", {})
	for id: Variant in words:
		var info: PartInfo = parts.get(id)
		if info != null:
			info.also_called = str(words[id])


## How much the set inventories use each part (tools/part_usage.py). Without
## the file the catalogue's in_sets is all a search knows.
const USAGE := "res://assets/ldraw/part_usage.json"


func _read_usage() -> void:
	if not FileAccess.file_exists(USAGE):
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(USAGE))
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var used: Dictionary = (raw as Dictionary).get("parts", {})
	for id: Variant in used:
		var info: PartInfo = parts.get(id)
		var pair: Variant = used[id]
		if info != null and pair is Array and (pair as Array).size() == 2:
			info.used_in = int(pair[0])
			info.pieces = int(pair[1])


## A part with the number of another and cNN after it is that part made
## whole: 60593c01 the window 60593 with its glass, 56145c03 a rim with its
## tyre, 73194c01 a door with its glass. Only of a plain part LDraw keeps for
## use, and not of a sticker (a sticker "formed" to a slope is one too).
static var WHOLE_NUMBER := RegEx.create_from_string("^(.+?)c\\d\\d$")

## Part -> the assemblies built on it, by number.
var _wholes: Dictionary = {}


func _index_wholes() -> void:
	_wholes.clear()
	for id: String in _ordered_ids:
		if not id.contains("c"):
			continue
		var found: RegExMatch = WHOLE_NUMBER.search(id)
		if found == null:
			continue
		var info: PartInfo = parts[id]
		var base: PartInfo = parts.get(found.get_string(1))
		if base == null or base.is_redirect() or info.is_redirect() or base.decor() != 0 \
				or is_stale(base) or is_stale(info) or base.category.begins_with("Sticker"):
			continue
		info.whole_of = base.id
		info._whole = base
		if not _wholes.has(base.id):
			_wholes[base.id] = []
		(_wholes[base.id] as Array).append(id)


## The assemblies LDraw draws whole that are built on [param id]: 60593c01
## for 60593. Empty for most parts.
func wholes_of(id: String) -> PackedStringArray:
	return PackedStringArray(_wholes.get(id, []))


func _read_part(entry: Dictionary) -> PartInfo:
	var info: PartInfo = PartInfo.new()
	info.id = entry.get("id", "")
	info.name = entry.get("name", "")
	info.category = entry.get("category", "")
	info.kind = entry.get("kind", "Part")
	info.mesh_hash = entry.get("mesh", "")
	info.triangles = int(entry.get("triangles", 0))
	info.stud_count = int(entry.get("stud_count", 0))
	info.socket_count = int(entry.get("socket_count", 0))
	info.box_count = int(entry.get("box_count", 0))
	var counts: Variant = entry.get("connector_counts", {})
	if typeof(counts) == TYPE_DICTIONARY:
		info.connector_counts = counts
	info.in_sets = int(entry.get("in_sets", 0))
	info.recolourable = bool(entry.get("recolourable", true))
	var fixed: Array = entry.get("fixed_colors", [])
	if fixed.size() == 1 and not info.recolourable and info.kind.contains("Physical_Colour"):
		info.fixed_colour = int(fixed[0])
	info.packed = bool(entry.get("packed", true))
	info.reachable = bool(entry.get("reachable", true))
	info.moved_to = entry.get("moved_to", "")
	var moved_by: Variant = entry.get("moved_by", [])
	if moved_by is Array and (moved_by as Array).size() == 12:
		info.moved_by = LdrModel.to_transform(PackedFloat64Array(moved_by))
	info.unofficial = bool(entry.get("unofficial", false))
	info.custom = bool(entry.get("custom", false))
	info.ldraw_category = str(entry.get("ldraw_category", ""))
	info.source_path = str(entry.get("source", ""))
	for code: Variant in entry.get("colors", []):
		info.colors.append(int(code))
	for code: Variant in entry.get("colors_recent", []):
		info.colors_recent.append(int(code))
	info.colors_partial = bool(entry.get("colors_partial", false))
	var span: Array = entry.get("years", [])
	if span.size() == 2:
		info.first_year = int(span[0])
		info.last_year = int(span[1])

	var size: Array = entry.get("size_ldu", [0, 0, 0])
	info.size = Vector3(size[0], size[1], size[2])
	var lo: Array = entry.get("bounds_min", [0, 0, 0])
	var hi: Array = entry.get("bounds_max", [0, 0, 0])
	var low := Vector3(lo[0], lo[1], lo[2])
	info.bounds = AABB(low, Vector3(hi[0], hi[1], hi[2]) - low)

	for word: Variant in entry.get("keywords", []):
		info.keywords.append(str(word))

	return info


func _load_colors() -> void:
	var colors_path: String = _resolve_root() + "colors.json"
	var file: FileAccess = FileAccess.open(colors_path, FileAccess.READ)
	if file == null:
		push_warning("part library: no colours at %s" % colors_path)
		return
	var raw: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(raw) != TYPE_ARRAY:
		return

	for item: Variant in raw:
		var entry: Dictionary = item
		var color: BrickColor = BrickColor.new()
		color.code = int(entry.get("code", 0))
		color.name = entry.get("name", "")
		color.alpha = int(entry.get("alpha", 255))
		color.finish = entry.get("finish", "solid")
		color.luminance = int(entry.get("luminance", 0))
		var rgb: Array = entry.get("rgb", [255, 0, 255])
		var edge: Array = entry.get("edge", [0, 0, 0])
		# Stored as 0-255 sRGB; the shader linearises, so keep it raw here.
		color.rgb = Color(rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0, color.alpha / 255.0)
		color.shown = shown_for(color.rgb)
		color.edge = Color(edge[0] / 255.0, edge[1] / 255.0, edge[2] / 255.0)
		# A colors.json from before these fields existed reads as all
		# plastic and nothing known, which is what it was.
		color.group = str(entry.get("group", ""))
		color.lego_name = str(entry.get("lego_name", ""))
		for number: Variant in entry.get("lego_ids", []):
			color.lego_ids.append(int(number))
		color.rebrickable_id = int(entry.get("rebrickable_id", -1))
		color.bricklink = int(entry.get("bricklink", -1))
		var years: Array = entry.get("years", [0, 0])
		color.first_year = int(years[0])
		color.last_year = int(years[1])
		color.sets = int(entry.get("sets", 0))
		color.current = bool(entry.get("current", false))
		color.plain_code = int(entry.get("plain_code", color.code))
		# BrickLink's number back to LDraw's plain colour: a Studio file's
		# model2.ldr is in BrickLink's numbers (StudioDecor).
		if color.bricklink >= 0 and (not by_bricklink.has(color.bricklink)
				or color.plain_code == color.code):
			by_bricklink[color.bricklink] = color.code

		var material_kind: String = ""
		var material: Variant = entry.get("material", null)
		if typeof(material) == TYPE_DICTIONARY:
			var stuff: Dictionary = material
			material_kind = str(stuff.get("kind", ""))
			var fleck: Variant = stuff.get("rgb", null)
			if typeof(fleck) == TYPE_ARRAY and (fleck as Array).size() >= 3:
				var parts_of: Array = fleck
				color.fleck = Color(parts_of[0] / 255.0, parts_of[1] / 255.0,
					parts_of[2] / 255.0)
			color.fleck_fraction = clampf(float(stuff.get("fraction", 0.0)), 0.0, 1.0)
		color.drawn_as = finish_for(color.finish, color.name, material_kind)
		color.pack_finish()
		colors[color.code] = color


## Geometry for a part, loading it on first use.
##
## Returns null when the part has no mesh on disk, which happens for parts
## the build skipped; callers should treat that as "cannot place" rather
## than as an error worth stopping for.
func mesh_for(part_id: String) -> Lbm.PartMesh:
	var info: PartInfo = parts.get(part_id)
	if info == null:
		return null
	if _mesh_cache.has(info.mesh_hash):
		return _mesh_cache[info.mesh_hash]
	if _custom_meshes.has(info.mesh_hash):
		return _custom_meshes[info.mesh_hash]
	if _readers > 0:
		# A reader on another thread only reads: what it needs was loaded
		# before it began (Assistant._checked), and loading here would
		# write the cache it is reading. Loaded while another reader was
		# out, it is in _arrived, read under the lock the main thread
		# writes it under: until 2026-10-20 a worker saw none of it, and
		# readers overlap. 10179-1 opened while Grab read the model before
		# it, so its 214 new parts waited there through the weighing and
		# the next Grab read, and Suggest sections' worker read 1,665 of
		# its 5,266 parts: no pin, axle or clip, a 3,517-part section.
		if not _on_main_thread():
			_arrived_lock.lock()
			var waiting: Lbm.PartMesh = _arrived.get(info.mesh_hash)
			_arrived_lock.unlock()
			return waiting
		if _arrived.has(info.mesh_hash):
			return _arrived[info.mesh_hash]

	var path: String = _on_disk(info.mesh_hash)
	if path.is_empty():
		# Not in this build. Start fetching it; the caller gets null now
		# and a [signal fetched] shortly.
		request_mesh(part_id)
		return null

	var part: Lbm.PartMesh = Lbm.load_part(path)
	if part == null:
		if not _missing.has(info.mesh_hash):
			_missing[info.mesh_hash] = true
			push_warning("part library: %s has no geometry at %s" % [part_id, path])
		return null

	_keep(info.mesh_hash, part)
	return part


## Where the web build keeps the part of its working set the first screen
## does not draw, once the page has fetched it: index.parts.bin beside the
## build (tools/web_pack.py), each part written into the engine's files here
## as it arrives (src/boot/shell.html). Read as the pack is, so a part of it
## is to hand from then on, offline too; before, it is fetched on its own.
const LATER := "/later/"


## Parts of the later part asked for while it was on its way, held for it
## ([method request_mesh]) and asked for again once it is written in, or has
## failed, or [constant LATER_WAIT_MS] has gone by.
var _for_later: PackedStringArray = PackedStringArray()
## What the page last said of the later part (window.brickworksLater):
## "coming", or "" once it is written in, has failed for good or never was.
var _later: String = "?"
var _later_asked_at: int = -LATER_ASK_MS
## When the first part was held for it.
var _later_held_at: int = 0
const LATER_ASK_MS := 100
## The longest a part is held for the later part before it is fetched alone.
const LATER_WAIT_MS := 15000


## Whether the web build's later part is on its way: the page has asked for
## it, not written it in and not given up. Asked of the page at most every
## [constant LATER_ASK_MS].
func _later_coming() -> bool:
	if not OS.has_feature("web") or _later.is_empty():
		return false
	var now: int = Time.get_ticks_msec()
	if now - _later_asked_at >= LATER_ASK_MS:
		_later_asked_at = now
		var said: Variant = JavaScriptBridge.eval(
			"(function (l) { return l && l.asked && !l.written && !l.gave_up ? 'coming' : ''; })"
			+ "(window.brickworksLater)", true)
		_later = str(said) if said != null else ""
	return not _later.is_empty()


## Ask again for the parts held for the later part once it is no longer on
## its way, or has been waited for long enough.
func _watch_later() -> void:
	if _later_held_at == 0:
		_later_held_at = Time.get_ticks_msec()
	if _fetch_host == null or not _fetch_host.is_inside_tree() or _later_watched:
		return
	_later_watched = true
	_fetch_host.get_tree().create_timer(LATER_ASK_MS / 1000.0, true, false, true).timeout.connect(func() -> void:
		_later_watched = false
		if _later_coming() and Time.get_ticks_msec() - _later_held_at < LATER_WAIT_MS:
			_watch_later()
			return
		# Written in, failed or too slow: each read from it, or fetched.
		_later = ""
		_later_held_at = 0
		var held: PackedStringArray = _for_later.duplicate()
		_for_later.clear()
		for part_id: String in held:
			request_mesh(part_id, true))
var _later_watched: bool = false


## The file [param hash_name]'s geometry is read from in this build: the
## pack's, or the web build's later part of it once it has come, or "".
func _on_disk(hash_name: String) -> String:
	var path: String = _resolve_root() + "parts/" + hash_name + ".lbm"
	if FileAccess.file_exists(path):
		return path
	if OS.has_feature("web") and FileAccess.file_exists(LATER + hash_name + ".lbm"):
		return LATER + hash_name + ".lbm"
	return ""


# -- read from another thread ----------------------------------------------
#
# Checking a big design is seconds of work, and on the web the page has one
# thread: the owner's 4,242-part Falcon Heavy held it for 31 s a check. So the
# check runs on a worker (Assistant._checked), reading this library. A
# Dictionary written on one thread while another reads it can be read in the
# middle of growing, so while any reader is out nothing it reads is written:
# geometry that arrives waits in _arrived, and a part being made or the cache
# being dropped waits for the readers to finish (_wait_for_readers) — a
# moment, and only when the two meet. A reader whose answer can be done
# without is told to stop first (reading_in's stop): the status bar's
# weighing of a 4,139-part set held the next file's hose 11 s, waiting to be
# added, for a weight about to be thrown away.


## Readers on other threads now. Changed only on the main thread.
var _readers: int = 0
## Geometry that arrived while a reader was out: hash -> Lbm.PartMesh.
## Written on the main thread under [member _arrived_lock], which a reader
## on a worker takes to read it.
var _arrived: Dictionary = {}
var _arrived_lock := Mutex.new()
## The WorkerThreadPool tasks reading, for _wait_for_readers.
var _reading_tasks: Array[int] = []
## task -> what ends it early, for the readers that can be.
var _stops: Dictionary = {}


## Called before a reader's task is started, so nothing is written between
## starting it and its first read. Name the task with [method reading_in].
func begin_reading() -> void:
	_readers += 1


## [param stop], when given, ends the task early, and is called on the main
## thread when something it reads must be written.
func reading_in(task: int, stop: Callable = Callable()) -> void:
	_reading_tasks.append(task)
	if stop.is_valid():
		_stops[task] = stop


## After the task has been waited for.
func end_reading(task: int = -1) -> void:
	_reading_tasks.erase(task)
	_stops.erase(task)
	_readers = maxi(0, _readers - 1)
	if _readers > 0:
		return
	_mesh_cache.merge(_arrived)
	_arrived_lock.lock()
	_arrived.clear()
	_arrived_lock.unlock()


## Whether a worker is reading the library now: what changes it waits for
## that to finish ([method _wait_for_readers]). Those that can be ended early
## are asked to end, as a change asks them. Main thread only.
func being_read() -> bool:
	for task: int in _stops:
		(_stops[task] as Callable).call()
	for task: int in _reading_tasks:
		if not WorkerThreadPool.is_task_completed(task):
			return true
	return false


## Until every reader's task has finished, so what they read can be written.
## Main thread only.
func _wait_for_readers() -> void:
	for task: int in _stops:
		(_stops[task] as Callable).call()
	for task: int in _reading_tasks:
		while not WorkerThreadPool.is_task_completed(task):
			OS.delay_usec(500)


static func _on_main_thread() -> bool:
	return OS.get_thread_caller_id() == OS.get_main_thread_id()


func _keep(hash_name: String, part: Lbm.PartMesh) -> void:
	if _readers > 0:
		_arrived_lock.lock()
		_arrived[hash_name] = part
		_arrived_lock.unlock()
	else:
		_mesh_cache[hash_name] = part


## Where HTTPRequest nodes are parented. The library is a RefCounted and
## has no tree of its own, so whoever owns it lends one.
func set_fetch_host(host: Node) -> void:
	_fetch_host = host
	if not _for_later.is_empty():
		_watch_later()


## True when this build has the part's geometry to hand.
func is_resident(part_id: String) -> bool:
	var info: PartInfo = parts.get(part_id)
	return info != null and (_mesh_cache.has(info.mesh_hash)
		or _custom_meshes.has(info.mesh_hash) or _arrived.has(info.mesh_hash))


## True while the part's geometry has been asked for and has not arrived:
## being fetched, queued behind other fetches, or waiting to be told
## where to fetch it from. Not true of a part that failed, which is not
## coming at all.
func is_on_its_way(part_id: String) -> bool:
	var info: PartInfo = parts.get(part_id)
	if info == null or _mesh_cache.has(info.mesh_hash) \
			or _arrived.has(info.mesh_hash):
		return false
	return (_fetching.has(info.mesh_hash) or _queued_fetches.has(part_id)
		or _waiting.has(part_id) or _for_later.has(part_id))


## Ask for a part this build did not ship.
##
## The web build carries a working set of a few hundred parts, because
## the whole library is a gigabyte and nobody waits for that before
## placing their first brick. Everything else is a request away: the
## catalogue lists all 29,479 either way, so search and the design
## assistant see the entire library, and what is missing is bytes rather
## than knowledge.
##
## Returns false when the part cannot be fetched at all. Listen for
## [signal fetched].
## [param urgent] is for the part someone just clicked, as against the
## thumbnails filling in behind them. Without it the held part queues
## behind six previews nobody asked for, and the ghost does not appear
## until they are done — the one wait in the whole app that is felt.
func request_mesh(part_id: String, urgent: bool = false) -> bool:
	var info: PartInfo = parts.get(part_id)
	if info == null:
		return false
	if _mesh_cache.has(info.mesh_hash) or _custom_meshes.has(info.mesh_hash) \
			or _arrived.has(info.mesh_hash):
		fetched.emit(part_id)
		return true
	# Come with the web build's later parts since it was asked for: read,
	# not fetched again.
	if not _fetching.has(info.mesh_hash) and OS.has_feature("web") \
			and FileAccess.file_exists(LATER + info.mesh_hash + ".lbm"):
		var here: Lbm.PartMesh = Lbm.load_part(LATER + info.mesh_hash + ".lbm")
		if here != null:
			_keep(info.mesh_hash, here)
			fetched.emit(part_id)
			return true
	# One of them, while they are on their way whole: held for them rather
	# than fetched alone. The bin's first pictures were asked for in the
	# frames before the page could write them in, and fetched one by one.
	if info.packed and not _fetching.has(info.mesh_hash) and _later_coming() \
			and _on_disk(info.mesh_hash).is_empty():
		if not _for_later.has(part_id):
			_for_later.append(part_id)
		_watch_later()
		return true
	if _fetching.has(info.mesh_hash):
		# Already on its way for somebody else. Join them, or this part
		# is told "coming" and never told it came.
		#
		# Fetches are deduplicated by geometry, and different parts
		# share geometry all the time — a brick and its printed
		# variant, a part and the same part under another number. The
		# request carried only the first asker's id, so everyone else
		# heard a fetched() for a part they had not asked about and
		# went on waiting for one that never came.
		var waiting: Array = _fetching[info.mesh_hash]
		if not waiting.has(part_id):
			waiting.append(part_id)
		return true
	if int(_open.get("lbm", 0)) >= MAX_IN_FLIGHT:
		if urgent:
			_urgent[part_id] = true
		if _queued_fetches.has(part_id):
			# Already waiting. Promote it rather than queue it twice.
			if urgent:
				_queued_fetches.remove_at(_queued_fetches.find(part_id))
				_queued_fetches.insert(0, part_id)
		elif urgent:
			_queued_fetches.insert(0, part_id)
		else:
			_queued_fetches.append(part_id)
		return true
	if _fetch_host == null or not _fetch_host.is_inside_tree():
		return false

	# Nothing may go out before the deployment has said where the
	# geometry lives. It bit immediately: the bin asks for thumbnails the
	# moment it opens, those requests beat the probe, and they fell back
	# to /parts/ next to the app — where the catch-all route answers with
	# the landing page. HTML, status 200, and the only complaint was
	# "does not start with LBM1".
	if OS.has_feature("web") and remote_parts.is_empty():
		if not _waiting.has(part_id):
			_waiting.append(part_id)
		return true

	_fetching[info.mesh_hash] = [part_id]
	if not _ask(_remote_root() + info.mesh_hash + ".lbm",
			_on_fetched.bind(info.mesh_hash, part_id)):
		_fetching.erase(info.mesh_hash)
		fetch_failed.emit(part_id, "could not start the request")
		return false
	return true


## How many part fetches may be open at once. Enough to keep the link
## busy, few enough that a scroll does not queue a hundred of them behind
## each other in the browser's own connection limit. Sixteen, not six,
## since the store answers over HTTP/2, one connection for them all, and
## each is polled once a frame: a big set's own parts were most of its open
## (walk180, A8).
const MAX_IN_FLIGHT := 16


## Ask now for the geometry of each of [param part_ids] this build has not
## got, ahead of the parts bin's pictures: the parts of a model being
## opened, fetched while the rest of its open goes on (ModelStore
## .open_text_fetched). With [param first], ahead of those too, as asked
## already or not. A part this build has on disk is read when it is first
## asked for, as before. How many were asked for.
func want(part_ids: Array, first: bool = false) -> int:
	var asked: int = 0
	for part_id: String in part_ids:
		var info: PartInfo = parts.get(part_id)
		if info == null or is_resident(part_id) or (is_on_its_way(part_id) and not first) \
				or not _on_disk(info.mesh_hash).is_empty():
			continue
		request_mesh(part_id, true)
		asked += 1
	return asked

## Seconds to wait before asking again for what failed in a way that may
## pass ([method may_pass]): three more tries, 20 s in all. Nothing asked
## again until 2026-10-20: on a loaded box the release's browser check
## opened a 29-part crane whose 3709b timed out once, and it was never put
## down and nothing said so (m115's preview). A phone's connection drops
## the same way.
const RETRY_AFTER: Array[float] = [2.0, 6.0, 12.0]

## Requests open now, by what they fetch ("lbm", "bwx"): what
## [constant MAX_IN_FLIGHT] counts. One waiting to be asked again holds no
## connection, so it holds no place either.
var _open: Dictionary = {}

## Fetches asked again after a fault, since start-up. Probes read it.
var retries: int = 0


## Whether a fetch that ended so may succeed asked again: no answer at all
## (code 0: a timeout, a cut connection, a host not reached), a timeout
## (408), too many requests (429), or the server's own fault (5xx). A 404,
## or the bucket's 400 for an object it has not got, is an answer.
static func may_pass(result: int, code: int) -> bool:
	return result != HTTPRequest.RESULT_SUCCESS or code == 0 or code == 408 \
		or code == 429 or code >= 500


## Fetch [param url], and call [param done] with (code, body) once, with an
## answer that asking again would not change or the last of
## [constant RETRY_AFTER]'s tries. The one way geometry and exact shapes are
## fetched, and so the parts bin's pictures. False when no request could be
## sent.
func _ask(url: String, done: Callable, tries: int = 0) -> bool:
	if _fetch_host == null or not _fetch_host.is_inside_tree():
		return false
	var request := HTTPRequest.new()
	_fetch_host.add_child(request)
	var kind: String = url.get_extension()
	request.request_completed.connect(func(result: int, code: int,
			_headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		_open[kind] = int(_open.get(kind, 1)) - 1
		if may_pass(result, code) and tries < RETRY_AFTER.size() \
				and _fetch_host != null and _fetch_host.is_inside_tree():
			retries += 1
			_fetch_host.get_tree().create_timer(RETRY_AFTER[tries], true, false, true) \
				.timeout.connect(func() -> void:
					if not _ask(url, done, tries + 1):
						done.call(0, PackedByteArray()))
			# Its place is free while it waits. When the wait is over it goes
			# out whether or not there is room: it was asked for first.
			_next_fetch()
			_next_exact()
			return
		done.call(code, body))
	if request.request(url) != OK:
		request.queue_free()
		return false
	_open[kind] = int(_open.get(kind, 0)) + 1
	return true


## Start the next waiting fetch, if there is room.
func _next_fetch() -> void:
	while not _queued_fetches.is_empty() and int(_open.get("lbm", 0)) < MAX_IN_FLIGHT:
		var part_id: String = _queued_fetches[0]
		_queued_fetches.remove_at(0)
		_urgent.erase(part_id)
		request_mesh(part_id)


## Waiting parts somebody clicked, which nothing reordering the queue may
## put behind anything else.
var _urgent: Dictionary = {}


## Fetch these next, in this order, ahead of everything else waiting
## except a part somebody clicked.
##
## The parts bin's previews ask for geometry as their tiles come into
## sight, and the queue is first come first served, so after a fast
## scroll the screen being looked at waited behind every part asked for
## on the way to it. Only reorders: what is left behind is still fetched,
## after.
func prefer(part_ids: PackedStringArray) -> void:
	if _queued_fetches.size() < 2 or part_ids.is_empty():
		return
	var waiting: Dictionary = {}
	for part_id: String in _queued_fetches:
		waiting[part_id] = true
	var placed: Dictionary = {}
	var order := PackedStringArray()
	for part_id: String in _queued_fetches:
		if _urgent.has(part_id):
			order.append(part_id)
			placed[part_id] = true
	for part_id: String in part_ids:
		if waiting.has(part_id) and not placed.has(part_id):
			order.append(part_id)
			placed[part_id] = true
	for part_id: String in _queued_fetches:
		if not placed.has(part_id):
			order.append(part_id)
	_queued_fetches = order


## Send the requests that arrived before there was anywhere to send them.
func _release_waiting() -> void:
	if _waiting.is_empty():
		return
	var held: PackedStringArray = _waiting.duplicate()
	_waiting.clear()
	for part_id: String in held:
		request_mesh(part_id)


## Absolute, always. A relative URL is not merely resolved differently
## here — HTTPRequest rejects it outright, so every on-demand part
## failed to load in the browser and looked like a part the build did
## not have.
func _remote_root() -> String:
	if not remote_parts.is_empty():
		return remote_parts if remote_parts.ends_with("/") else remote_parts + "/"
	return Origin.here() + "/parts/"


func _on_fetched(code: int, body: PackedByteArray, hash_name: String,
		part_id: String) -> void:
	# Taken before the entry goes, not looked up after it.
	var asked_for: Array = _fetching.get(hash_name, [part_id])
	_fetching.erase(hash_name)
	_next_fetch()

	if code != 200 or body.is_empty():
		for asked: String in asked_for:
			fetch_failed.emit(asked, "HTTP %d" % code)
		return
	var part: Lbm.PartMesh = Lbm.parse(body, part_id)
	if part == null:
		for asked: String in asked_for:
			fetch_failed.emit(asked, "the geometry did not parse")
		return
	_keep(hash_name, part)
	# Everyone who asked for this geometry, not only whoever asked
	# first.
	for asked: String in asked_for:
		fetched.emit(asked)


## Ask for a part's exact shape (Exact, tools/build_exact.py) where this build
## did not ship it: the web build's, fetched from beside the geometry as
## <hash>.bwx. A part BrickNet does not have answers 404, which is kept as
## "none" so it is not asked again; a fault that may pass is asked again
## first, as geometry is ([method _ask]). Listen for [signal exact_fetched].
func request_exact(part_id: String) -> bool:
	var info: PartInfo = shaped_as(part_id)
	if info == null or info.mesh_hash.is_empty():
		return false
	part_id = info.id
	if _fetching_exact.has(info.mesh_hash) or _exact_waiting.has(part_id):
		return true
	if _fetch_host == null or not _fetch_host.is_inside_tree():
		return false
	if OS.has_feature("web") and remote_parts.is_empty():
		return false
	# A check of a big design asks for a shape a part: a few at a time, as
	# the geometry is fetched, the rest in turn.
	if int(_open.get("bwx", 0)) >= MAX_IN_FLIGHT:
		_exact_waiting.append(part_id)
		return true
	_fetching_exact[info.mesh_hash] = true
	if not _ask(_remote_root() + info.mesh_hash + ".bwx",
			_on_fetched_exact.bind(info.mesh_hash, part_id)):
		_fetching_exact.erase(info.mesh_hash)
		Exact.keep(info.mesh_hash, PackedByteArray())
		return false
	return true


## Exact shapes being fetched, or waiting to be asked again: hash -> true;
## and parts waiting their turn.
var _fetching_exact: Dictionary = {}
var _exact_waiting: PackedStringArray = PackedStringArray()

## Emitted when a part's exact shape has been fetched or found not to exist.
signal exact_fetched(part_id: String)


## The exact shapes of these parts fetched next, ahead of the others still
## waiting their turn: a motion's press waits for its own (main.gd). Only
## reorders.
func prefer_exact(part_ids: Array) -> void:
	var first := PackedStringArray()
	for part_id: Variant in part_ids:
		var info: PartInfo = shaped_as(str(part_id))
		if info != null and _exact_waiting.has(info.id) and not first.has(info.id):
			first.append(info.id)
	if first.is_empty():
		return
	for part_id: String in _exact_waiting:
		if not first.has(part_id):
			first.append(part_id)
	_exact_waiting = first


## Whether a part's exact shape is still on its way.
func is_exact_on_its_way(part_id: String) -> bool:
	var info: PartInfo = shaped_as(part_id)
	return info != null and (_fetching_exact.has(info.mesh_hash) or _exact_waiting.has(info.id))


## The part whose exact shape [param part_id] has: itself, or for a model
## file's own copy of a part LEGO made, that part (PartInfo.copy_of).
func shaped_as(part_id: String) -> PartInfo:
	var info: PartInfo = parts.get(part_id)
	if info != null and not info.copy_of.is_empty():
		return parts.get(info.copy_of)
	return info


func _on_fetched_exact(code: int, body: PackedByteArray, hash_name: String,
		part_id: String) -> void:
	_fetching_exact.erase(hash_name)
	Exact.keep(hash_name, body if code == 200 else PackedByteArray())
	exact_fetched.emit(part_id)
	_next_exact()


## Start the next exact shape waiting, if there is room.
func _next_exact() -> void:
	while not _exact_waiting.is_empty() and int(_open.get("bwx", 0)) < MAX_IN_FLIGHT:
		var next: String = _exact_waiting[0]
		_exact_waiting.remove_at(0)
		request_exact(next)


## Drop cached geometry. The catalogue stays; only vertices go. A made
## part's stay too: there is nowhere to fetch one back from.
func release_geometry() -> void:
	_wait_for_readers()
	_mesh_cache.clear()


## Parts made in the element maker, or carried into a model file from
## someone else's: id -> the LDraw source, which goes out with any model
## that uses the part. Their geometry is kept apart from the cache.
var custom: Dictionary = {}
var _custom_meshes: Dictionary = {}

## Emitted when a made part joins the library, or is replaced.
signal custom_added(part_id: String)


## Put a made part beside the catalogue's, or replace one made before.
func add_custom(info: PartInfo, mesh: Lbm.PartMesh, source: String) -> void:
	_wait_for_readers()
	if not parts.has(info.id):
		_ordered_ids.append(info.id)
	parts[info.id] = info
	custom[info.id] = source
	_search_lock.lock()
	_search_index = null
	_search_lock.unlock()
	_mesh_cache.erase(info.mesh_hash)
	_custom_meshes[info.mesh_hash] = mesh
	custom_added.emit(info.id)


## The LDraw source of a custom part, from this session's or the
## catalogue's, or "" for a part LEGO made.
func custom_source(part_id: String) -> String:
	if custom.has(part_id):
		return custom[part_id]
	var info: PartInfo = parts.get(part_id)
	if info == null or not info.custom or info.source_path.is_empty():
		return ""
	var path: String = _resolve_root() + info.source_path
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func cached_mesh_count() -> int:
	return _mesh_cache.size()


func color(code: int) -> BrickColor:
	var found: BrickColor = colors.get(code)
	if found != null:
		return found
	# Unknown codes render magenta rather than silently picking grey, so a
	# bad colour in a model is visible instead of plausible.
	var fallback: BrickColor = BrickColor.new()
	fallback.code = code
	fallback.name = "Unknown %d" % code
	fallback.rgb = Color.MAGENTA
	fallback.shown = Color.MAGENTA
	fallback.alpha = 255
	fallback.finish = "solid"
	return fallback


## How many parts were made in a colour: x since recent_since, y ever.
## Counted over every part's availability the first time anything asks.
var _colour_use: Dictionary = {}


func colour_use(code: int) -> Vector2i:
	if _colour_use.is_empty():
		for id: String in _ordered_ids:
			var info: PartInfo = parts[id]
			for made: int in info.colors:
				var was: Vector2i = _colour_use.get(made, Vector2i.ZERO)
				_colour_use[made] = Vector2i(was.x, was.y + 1)
			for made: int in info.colors_recent:
				var was: Vector2i = _colour_use.get(made, Vector2i.ZERO)
				_colour_use[made] = Vector2i(was.x + 1, was.y)
		# So an empty answer is not mistaken for "not counted yet".
		_colour_use[-1] = Vector2i.ZERO
	return _colour_use.get(code, Vector2i.ZERO)


## Whether a colour is in LEGO's palette now: in a set since
## recent_since.
##
## The colour's own years decide when the colour data carries them.
## Otherwise it is current if any part has been in a set in it since
## then. A colour no part's list mentions is not called current — the
## join cannot place sixty-nine of Rebrickable's colours, so silence is
## not knowing — and a catalogue built with no availability at all
## calls everything current rather than nothing.
func is_current(code: int) -> bool:
	var color_of: BrickColor = colors.get(code)
	if color_of == null:
		return false
	if color_of.last_year > 0 and recent_since > 0:
		return color_of.last_year >= recent_since
	if recent_since == 0:
		return true
	return colour_use(code).x > 0


## Parts whose name, category, id or keywords contain every word of the
## query (PartLibrary.matched).
##
## A plain substring match: predictable, no index, and it scans 24,731
## short strings faster than a frame. What it must not do is stop at the
## first N matches in catalogue order — those are whatever sorts first
## numerically, which is never what was wanted. It collects everything,
## ranks, and then takes the top of the list.
## What a builder calls a part, against what LDraw calls it.
##
## The library's names are not the words people use, and the difference
## is not small. A wedge plate is filed as "Wedge 4 x 6" — searching
## "wedge plate" finds one part out of two hundred, and it is a 2 x 16
## triple with an axle hole. A cheese slope is "Slope Brick 31 1 x 1".
## A jumper is a plate "with 1 Centre Stud". None of those words appear
## in the name a designer would type.
##
## An assistant that takes the first result never discovers this; it
## just builds with the wrong part, or decides the library does not have
## one. The saucer of a starship is wedge plates, so the cost of the gap
## is the whole shape.
const ALSO_KNOWN_AS: Dictionary = {
	# Measured, not guessed: of the 203 parts with "wedge" in the name,
	# 126 are three and a half plates tall — wedge *bricks*. The one
	# plate wedges, the ones a saucer or a swept wing is made of, are all
	# filed as "Wing": 61 of them, Wing 2 x 2 through Wing 6 x 12. So
	# "wedge plate" pointed at the wrong family entirely, and the word
	# that reaches the right one is one no builder says out loud. A wedge
	# brick is asked as it is said: the Wedge family, brick tall (PartSearch
	# reads brick, plate and tile as a height in another family).
	"wedge plate": "wing",
	"minifigure": "minifig",
	"cheese slope": "slope brick 31 1 x 1",
	"jumper plate": "with 1 centre stud",
	"snot brick": "with stud on 1 side",
	"stud on side": "with stud on 1 side",
	"headlight brick": "brick 1 x 1 with headlight",
	"curved slope": "slope brick curved",
	"inverted slope": "slope brick inverted",
	"cheese": "slope brick 31 1 x 1",
	"jumper": "with 1 centre stud",
	# A builder says print, LDraw says Pattern, and the index says print
	# for every part LDraw names a Pattern (PartInfo.own_words). So
	# "porsche print" finds 3623pt1, which it did not: no name has the
	# word print in it (2026-10-13). Listed as themselves for the plural.
	"print": "print",
	"printed": "print",
	"pattern": "print",
	"patterned": "print",
	"sticker": "sticker",
	"stickered": "sticker",
	"decal": "sticker",
}


## How a part answers the words of a query: not at all, by its own name,
## number and category, or only with its !KEYWORDS too.
const NOT_MATCHED := 0
const BY_NAME := 1
const BY_KEYWORDS := 2


## Whether every word is in the part's own words, or failing that in
## them and its keywords.
##
## The keywords were in the catalogue all along and nothing read them:
## 15068pt2, a turbo printed on a Porsche, says Porsche only there. But a
## part found only through its keywords answers the query less directly
## than one whose name does, and the search lists those after
## (PartsBin._sort_for). A plain query keeps the answers it had, in the
## order it had them, with any new ones below.
static func matched(info: PartInfo, needles: PackedStringArray) -> int:
	var own: String = info.own_words()
	var by: int = BY_NAME
	for needle: String in needles:
		if own.contains(needle):
			continue
		if not info.keyword_words().contains(needle):
			return NOT_MATCHED
		by = BY_KEYWORDS
	return by


## A print, a stickered part or a sticker, from what LDraw calls it.
##
## The name and not the number. LDraw ends every print's name with
## "Pattern", where a p in the number is also a part moulded in two
## colours: 61406p06 is a plate with a tooth whose tip is sand green.
## A Sticker Shortcut is a part with its stickers on; the Sticker
## category is the stickers themselves. One of your own is filed under
## My prints or My stickers.
static func decor_of(name: String, category: String) -> int:
	if category == "Sticker" or category == PartPrints.MY_STICKERS:
		return PartInfo.STICKER
	var lowered: String = name.to_lower()
	var on: int = 0
	# The plain contains first: every part is read at start-up, a third of
	# them say either word, and a regular expression is the slow part.
	if category == PartPrints.MY_PRINTS or (lowered.contains("patt")
			and PATTERN_WORD.search(lowered) != null
			and not lowered.contains("without pattern")):
		on |= PartInfo.PRINTED
	if category == "Sticker Shortcut" or (lowered.contains("sticker")
			and STICKER_WORD.search(lowered) != null):
		on |= PartInfo.STICKERED
	return on


static var PATTERN_WORD := RegEx.create_from_string("\\bpatt(ern|\\.)")
static var STICKER_WORD := RegEx.create_from_string("\\bstickers?\\b")
## The plain part's number in a print's or a stickered part's: 3623 in
## 3623pt1, 3068b in 3068bd2j, 3626c in 3626cp01. Minifig._family's
## pattern, with a sticker's d beside a print's p.
static var DECORATED_NUMBER := RegEx.create_from_string(
	"^([a-z]?\\d+[a-z]?(?:-f\\d)?)[pd][0-9a-z]+$")

## Plain part -> its prints and stickered versions, by number.
var _prints: Dictionary = {}


## Which plain part each print is of, and what is printed on it.
##
## By number first, which most parts fail at once: this runs as the
## catalogue loads, on the web too.
func _index_prints() -> void:
	_prints.clear()
	for id: String in _ordered_ids:
		var found: RegExMatch = DECORATED_NUMBER.search(id)
		if found == null:
			continue
		var info: PartInfo = parts[id]
		if (info.decor() & (PartInfo.PRINTED | PartInfo.STICKERED)) == 0 \
				or info.is_redirect():
			continue
		var plain: PartInfo = parts.get(found.get_string(1))
		# A print whose own code starts with its p or d: 3039pd0 reads as a
		# print of a 3039p no catalogue has, and is a print of 3039.
		if plain == null and found.get_string(1).right(1) in ["p", "d"]:
			plain = parts.get(found.get_string(1).left(-1))
		if plain == null or plain.is_redirect() or plain.decor() != 0:
			continue
		info.print_of = plain.id
		info._plain = plain
		if not _prints.has(plain.id):
			_prints[plain.id] = []
		(_prints[plain.id] as Array).append(id)


## The prints and stickered versions of a plain part: the prints first,
## then the most used, then by number. 3623 has eleven prints.
func prints_of(plain: String) -> Array[PartInfo]:
	var out: Array[PartInfo] = []
	for id: Variant in _prints.get(plain, []):
		var info: PartInfo = parts.get(id)
		if info != null and info.reachable:
			out.append(info)
	out.sort_custom(func(a: PartInfo, b: PartInfo) -> bool:
		var a_print: bool = (a.decor() & PartInfo.PRINTED) != 0
		var b_print: bool = (b.decor() & PartInfo.PRINTED) != 0
		if a_print != b_print:
			return a_print
		if a.in_sets != b.in_sets:
			return a.in_sets > b.in_sets
		return a.id.naturalnocasecmp_to(b.id) < 0)
	return out


## A size as people type it: "2x4", "1 x2", "2×4".
static var SIZE_TYPED := RegEx.create_from_string("(\\d)\\s*[x×]\\s*(?=\\d)")


## The query in the library's own words.
##
## Longest phrase first, so "cheese slope" is not taken apart by the
## entry for "cheese" before it has been recognised.
##
## And a size spelled the way LDraw spells it, "2 x 4". Nearly everyone
## types "2x4", and the words of a query are matched one by one, so
## "brick 2x4" looked for the text "2x4" in "Brick  2 x  4" and the bin
## said nothing matches (brickworks.diy at dd5c10c, 2026-10-12).
static func in_ldraw_words(query: String) -> String:
	var text: String = " %s " % SIZE_TYPED.sub(query.strip_edges().to_lower(), "$1 x ", true)
	var phrases: Array = ALSO_KNOWN_AS.keys()
	phrases.sort_custom(func(a: String, b: String) -> bool:
		return a.length() > b.length())
	for phrase: String in phrases:
		# And the plural, which is what somebody types when they want
		# more than one of something. "wedge plates" missed the table
		# over a trailing letter and went to the library untranslated.
		for said: String in [phrase, phrase + "s"]:
			if text.contains(" %s " % said):
				text = text.replace(" %s " % said,
					" %s " % ALSO_KNOWN_AS[phrase])
	return text.strip_edges()


## The parts real sets are most often made of, most used first.
##
## Not a taste. It is the catalogue's own in_sets, counted over every
## catalogued set inventory, and it says something a designer does not
## guess: a LEGO set is mostly plates and tiles. The 2x4 brick everybody
## pictures is twenty-second.
##
## Redirects are left out, or the list leads with the same part twice
## under two numbers.
func staples(most: int = 30) -> Array[PartInfo]:
	var ranked: Array[PartInfo] = []
	for id: String in _ordered_ids:
		var info: PartInfo = parts[id]
		if info.in_sets > 0 and not info.is_redirect():
			ranked.append(info)
	ranked.sort_custom(func(a: PartInfo, b: PartInfo) -> bool:
		return a.in_sets > b.in_sets)
	if ranked.size() > most:
		ranked.resize(most)
	return ranked


## The parts that answer a builder's query, best first (PartSearch): ranked
## by how much of it each has, so a word the catalogue does not use lowers
## a part and never hides it, and then by how much sets use it. With
## [param every_word], only the parts that have every word; a [param limit]
## under zero is every part that answers. Without [param loose], a word is
## matched whole and as written, never as the start of one or misspelt.
func search(query: String, limit: int = 100, every_word: bool = false,
		loose: bool = true) -> Array[PartInfo]:
	var found: Array[PartInfo] = _finder().find(in_ldraw_words(query), limit, every_word, loose)
	_collect_preparing()
	# A number LDraw keeps only for old files, typed: the part made now in its
	# shape, first (current), as the index leaves the old one out.
	var typed: String = query.strip_edges().to_lower()
	if superseded(typed):
		var twin: PartInfo = parts.get(current(typed))
		if twin != null:
			found.erase(twin)
			found.push_front(twin)
			if limit >= 0 and found.size() > limit:
				found.resize(limit)
	return found


## The words of [param query] that no part has, by name, keyword or the
## words sets name it by.
func unknown_words(query: String) -> PackedStringArray:
	return _finder().unknown(in_ldraw_words(query))


var _search_index: PartSearch = null
var _search_lock := Mutex.new()


## Whether the search's index is made: a search asked now does not wait.
func search_ready() -> bool:
	_search_lock.lock()
	var made: bool = _search_index != null
	_search_lock.unlock()
	if made:
		_collect_preparing()
	return made


## Make the search's index now, on a thread of its own where there are
## threads, so the first key typed in the parts bin is not the one that waits
## the second it takes. A search asked meanwhile waits for it (_finder).
func prepare_search() -> void:
	if (OS.has_feature("web") and not OS.has_feature("threads")) or _preparing >= 0 \
			or search_ready():
		return
	_preparing = WorkerTasks.add(func() -> void: _finder(), false, "index the parts for search")


## The task making the index (prepare_search), until it is let go of.
var _preparing: int = -1


func _collect_preparing() -> void:
	if _preparing >= 0 and _on_main_thread() and WorkerThreadPool.is_task_completed(_preparing):
		WorkerTasks.collect(_preparing)
		_preparing = -1


## The word index, made at the first search: under a second over the whole
## catalogue, once, where every search read all of it (a tenth of a second a
## search, 2026-10-22). A part made in the app makes it again.
func _finder() -> PartSearch:
	_search_lock.lock()
	if _search_index == null:
		# Not a part LDraw keeps only for old files where one made now is
		# the same shape (current): search offered 3660a beside 3660c.
		var offered := PackedStringArray()
		for id: String in _ordered_ids:
			if not superseded(id):
				offered.append(id)
		_search_index = PartSearch.new(parts, offered)
	var index: PartSearch = _search_index
	_search_lock.unlock()
	return index


## The part a number actually means today.
##
## LDraw keeps a stub for every number it has retired — 4073 is now
## "~Moved to 6141" — and those stubs render perfectly well, because
## the stub's geometry is a reference to the part it moved to. So a
## model built on an old number looks right and is wrong underneath:
## the parts list offers "~Moved to 3023b" where the name should be,
## the booklet says it, and anyone reading either to buy the bricks is
## handed a sentence instead of a part.
##
## Search already declines to suggest them. This is for the numbers
## that arrive another way: out of somebody else's .ldr, or out of a
## model that knows 4073 from memory.
func resolve(part_id: String) -> String:
	var at: String = part_id
	# Chains exist — a number moved once can move again — and a cycle
	# in somebody's data should not be an infinite loop.
	for _hop: int in 8:
		var info: PartInfo = parts.get(at)
		if info == null or not info.is_redirect():
			return at
		if not parts.has(info.moved_to):
			return at
		at = info.moved_to
	return at


## Where [method resolve]'s part goes for one placed at the identity by
## [param part_id]: the turns and shifts of every stub on the way. A part
## opened by its old number is the new one placed there, so a file's 3139
## tyres, renamed 3139b where they stood, stood turned across their own
## axles: drawn right, since the stub's geometry is the new part turned,
## and checked, read back and saved wrong.
func moved_by(part_id: String) -> Transform3D:
	var at: String = part_id
	var by := Transform3D.IDENTITY
	for _hop: int in 8:
		var info: PartInfo = parts.get(at)
		if info == null or not info.is_redirect() or not parts.has(info.moved_to):
			return by
		by = by * info.moved_by
		at = info.moved_to
	return by


## The part a design places for [param part_id]: [method resolve]'s, and for
## one LDraw keeps only for old files, the part made now of the same shape
## and size. A design that knew 3660 from memory built a tug of nineteen
## 3660a, "~Slope Brick 45 2 x 2 Inverted without Inner Stopper Ring
## (Obsolete)", which the parts list and the BrickLink order then carried
## (walk180, 2026-10-23); 3660c is that slope as it is moulded today. An
## alias ("=Tail 2 x 3 x 2 Fin") is the part it names, drawn the same; an
## obsolete mould or a "~" part is the current part of its family (its name
## up to "with") in the same box, the closest named, then the most used.
## One with no such twin is itself. A part LDraw draws in one colour only
## (303923, a slope brick in blue) is the part it draws, placed in that
## colour ([method current_colour]): 3039 in blue. Only for what a design
## places, and for a file opened only such a part in one colour: otherwise it
## keeps the numbers its maker wrote.
func current(part_id: String) -> String:
	var at: String = resolve(part_id)
	# A stub that turns its part (3139 a quarter round to 3139b) is placed
	# through BrickWorld, which turns it; renamed here it would not be.
	if moved_by(part_id) != Transform3D.IDENTITY:
		return part_id
	_current_lock.lock()
	if _current_of.is_empty():
		_index_current()
	var twin: String = str(_current_of.get(at, at))
	_current_lock.unlock()
	return twin


## The colour [method current] places [param part_id] in, for a part LDraw
## draws in one colour only, kept for old files: 1 (blue) for 303923, which is
## 3039 in blue. -1 for every other part, which keeps the colour it is given.
## A design placing 241901, a white 3 x 6 plate, was given 2419 in its own
## red, and a file's 303923 opened as itself, for its parts list and its
## BrickLink order to carry.
func current_colour(part_id: String) -> int:
	_current_lock.lock()
	if _current_of.is_empty():
		_index_current()
	var colour: int = int(_colour_of.get(resolve(part_id), -1))
	_current_lock.unlock()
	return colour


## Whether [param part_id] is a part LDraw keeps only for old files that
## [method current] places as another: what a search leaves out.
func superseded(part_id: String) -> bool:
	_current_lock.lock()
	if _current_of.is_empty():
		_index_current()
	var twin: String = str(_current_of.get(part_id, part_id))
	_current_lock.unlock()
	return twin != part_id


## Whether LDraw keeps [param info] only for old files: an alias, an
## obsolete mould, a "~" part (which LDraw files as not to be used alone).
static func is_stale(info: PartInfo) -> bool:
	if info == null or info.is_redirect() or info.custom:
		return false
	var name: String = info.name.strip_edges()
	return name.begins_with("~") or name.begins_with("=") \
		or info.category == "Obsolete" or name.contains("(Obsolete)")


## What a part is before what it is with: "slope brick 45 2 x 2 inverted" for
## every 3660, "window 1 x 3 x 2 classic" for 31b and 31bc01.
static func family_of(info: PartInfo) -> String:
	var name: String = info.name.to_lower().replace("(obsolete)", "").replace("(complete)", "")
	name = name.lstrip("~=_ ")
	for cut: String in [" with ", " without ", " ("]:
		var found: int = name.find(cut)
		if found > 0:
			name = name.substr(0, found)
	return " ".join(name.split(" ", false))


var _current_of: Dictionary = {}
var _current_lock := Mutex.new()


func _index_current() -> void:
	# The stale parts first, by a look at their names, so that only a current
	# part sharing one's mesh or box is read further: a second's work over
	# every part's name was a tenth of that.
	var stale: Array[PartInfo] = []
	var meshes: Dictionary = {}
	var boxes: Dictionary = {}
	for id: String in _ordered_ids:
		var info: PartInfo = parts[id]
		if is_stale(info):
			stale.append(info)
			meshes[info.mesh_hash] = true
			for key: String in _sizes_near(info):
				boxes[key] = true
	var by_mesh: Dictionary = {}
	var by_family: Dictionary = {}
	for id: String in _ordered_ids:
		var info: PartInfo = parts[id]
		if info.is_redirect() or info.custom or not info.reachable or is_stale(info):
			continue
		if meshes.has(info.mesh_hash):
			if not by_mesh.has(info.mesh_hash):
				by_mesh[info.mesh_hash] = []
			(by_mesh[info.mesh_hash] as Array).append(info)
		if boxes.has(_size_key(info.size)):
			var family: String = family_of(info)
			if not by_family.has(family):
				by_family[family] = []
			(by_family[family] as Array).append(info)
	for info: PartInfo in stale:
		var id: String = info.id
		var twins: Array = by_mesh.get(info.mesh_hash, [])
		# A print only by its drawing: another print of the mould in the same
		# box is another picture (3626bp30's messy hair is not 3626bp7g's glasses).
		if twins.is_empty() and info.decor() == 0:
			for other: PartInfo in by_family.get(family_of(info), []):
				if other.decor() == 0 \
						and other.bounds.position.distance_to(info.bounds.position) <= 1.0 \
						and other.bounds.end.distance_to(info.bounds.end) <= 1.0:
					twins.append(other)
		var best: PartInfo = null
		var best_score: float = -1.0
		var words: PackedStringArray = _name_words(info)
		var says: PackedStringArray = _clauses(info)
		for other: PartInfo in twins:
			var theirs: PackedStringArray = _name_words(other)
			var shared: int = 0
			for word: String in words:
				if theirs.has(word):
					shared += 1
			# What it is with or without first: 3660a is "without Inner
			# Stopper Ring", as 3660c is and 7261, "with Inner Stopper
			# Ring without Bottom Stud", is not, though its words are closer.
			var agreed: int = 0
			for clause: String in _clauses(other):
				if says.has(clause):
					agreed += 1
			var score: float = agreed + float(shared) / float(maxi(1, words.size() + theirs.size() - shared))
			# Of two named alike, the one sets use, and the one made now.
			score += (0.01 if other.in_sets > 0 else 0.0) + (0.005 if other.still_made() else 0.0)
			if score > best_score or (is_equal_approx(score, best_score) and best != null
					and other.in_sets > best.in_sets):
				best_score = score
				best = other
		_current_of[id] = best.id if best != null else id
	_index_colours()
	# Marked as built even where nothing is stale.
	_current_of[""] = ""


## The parts LDraw draws in one colour (PartInfo.fixed_colour) -> that
## colour, [method _index_current]'s with them: each is the part it draws, in
## that colour. The catalogue says what each draws only by its geometry, so
## it is the part of the same box and the same triangles that takes any
## colour, the current before one kept for old files, the plain mould before
## a print, then the one named most alike (2419 for 241901, "~_Plate 3 x 6
## without Corners White", over its alias 43127), then the most used; and that
## part's own current twin. One whose drawing no part made now has (73587, a
## hinge stick and its base as one) is itself.
var _colour_of: Dictionary = {}


func _index_colours() -> void:
	_colour_of.clear()
	var drawn: Dictionary = {}    ## box and triangles -> the parts drawn so
	for id: String in _ordered_ids:
		if (parts[id] as PartInfo).fixed_colour >= 0:
			drawn[_drawn_key(parts[id])] = []
	if drawn.is_empty():
		return
	for id: String in _ordered_ids:
		var info: PartInfo = parts[id]
		if info.recolourable and not info.kind.contains("Physical_Colour") and not info.is_redirect() \
				and not info.custom and drawn.has(_drawn_key(info)):
			(drawn[_drawn_key(info)] as Array).append(info)
	for id: String in _ordered_ids:
		var info: PartInfo = parts[id]
		if info.fixed_colour < 0:
			continue
		var words: PackedStringArray = _name_words(info)
		var best: PartInfo = null
		var best_score: float = -1.0
		for other: PartInfo in drawn[_drawn_key(info)]:
			var shared: int = 0
			for word: String in _name_words(other):
				if words.has(word):
					shared += 1
			var score: float = (4.0 if not is_stale(other) else 0.0) \
				+ (2.0 if other.decor() == 0 else 0.0) + shared * 0.01 + other.in_sets * 1e-7
			if score > best_score:
				best_score = score
				best = other
		var now: String = str(_current_of.get(best.id, best.id)) if best != null else ""
		# Only for a part made now: one drawing only an alias kept for old
		# files has (4298609's helmet, 30124) is itself.
		if now.is_empty() or is_stale(parts[now]):
			continue
		_colour_of[id] = info.fixed_colour
		_current_of[id] = now


## A part's box to the LDU and its triangles: what a part drawn in one colour
## shares with the part it draws.
static func _drawn_key(info: PartInfo) -> String:
	return "%s %s %d" % [Vector3i(info.bounds.position.round()), Vector3i(info.bounds.end.round()),
		info.triangles]


## A size to four LDU, and the sizes a part within one LDU of [param info]'s
## may be filed under.
static func _size_key(size: Vector3) -> String:
	return "%d %d %d" % [floori(size.x / 4.0), floori(size.y / 4.0), floori(size.z / 4.0)]


static func _sizes_near(info: PartInfo) -> PackedStringArray:
	var out := PackedStringArray()
	for dx: float in [-2.0, 0.0, 2.0]:
		for dy: float in [-2.0, 0.0, 2.0]:
			for dz: float in [-2.0, 0.0, 2.0]:
				var key: String = _size_key(info.size + Vector3(dx, dy, dz))
				if not out.has(key):
					out.append(key)
	return out


## What a name says a part is with and without, a clause each: "without
## inner stopper ring", "with flat bottom pin", "with small holes".
static func _clauses(info: PartInfo) -> PackedStringArray:
	var out := PackedStringArray()
	var name: String = " ".join(info.name.to_lower().replace("(obsolete)", "").replace(",", " ")
		.lstrip("~=_ ").split(" ", false))
	var keyword: String = ""
	var clause := PackedStringArray()
	for word: String in (name + " with").split(" ", false):
		if word == "with" or word == "without" or (word == "and" and not keyword.is_empty()):
			if not keyword.is_empty() and not clause.is_empty():
				out.append(keyword + " " + " ".join(clause))
			clause = PackedStringArray()
			if word != "and":
				keyword = word
		elif not keyword.is_empty():
			clause.append(word)
	return out


static func _name_words(info: PartInfo) -> PackedStringArray:
	var out := PackedStringArray()
	var name: String = info.name.to_lower().replace("(obsolete)", "").lstrip("~=_ ")
	for word: String in name.split(" ", false):
		if not word in ["x", "with", "and", "the"] and not out.has(word):
			out.append(word)
	return out


func ids() -> PackedStringArray:
	return _ordered_ids
