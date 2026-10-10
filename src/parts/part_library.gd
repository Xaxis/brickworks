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
	for word: String in words.to_lower().split(" ", false):
		place += 1
		var bare: String = ""
		for ch: String in word:
			if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
				bare += ch
		# A brief says castles and the catalogue says castle. And a
		# brief says spaceship where the catalogue, which is reading
		# real set names, says space — so a kind that the word begins
		# with counts too, at four letters or more. Four because
		# "car" would otherwise match "cargo" and "cart", and a
		# prefix that short says nothing.
		var tries: Array[String] = [bare, bare.trim_suffix("s"),
			bare.trim_suffix("es")]
		for at: int in range(bare.length() - 1, 3, -1):
			tries.append(bare.substr(0, at))
		for form: String in tries:
			if form.length() < 3 or seen.has(form) or not kinds.has(form):
				continue
			seen[form] = true
			var entry: Dictionary = (kinds[form] as Dictionary).duplicate()
			entry["kind"] = form
			entry["place"] = place
			found.append(entry)
			break
	# In the order the brief names them, because a brief names its subject
	# first and its features after. Fewest sets first was the rule, and
	# "a large space cruiser with ... two engine pods" came back as engine,
	# cruiser and pod: fire-engine ladders and X-Pod storage tubs, with
	# space pushed out for having more sets. Generic words that once
	# needed the specific rule are a word list now (NOT_A_KIND).
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["place"]) < int(b["place"]))
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
	return str(_elements.get("%s/%d" % [part_id, plain_code(code)], ""))


## The colour a part in this code is filed under by LEGO and Rebrickable:
## a rubber or canvas variant's ordinary colour, otherwise the code
## itself. A tyre drawn in Rubber Black is a Black tyre to a shop.
func plain_code(code: int) -> int:
	var found: BrickColor = colors.get(code)
	return found.plain_code if found != null else code


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

	## What kind of part this is to the LDraw world: a custom tile is a
	## Tile, whatever the bin files it under.
	func family_category() -> String:
		return ldraw_category if custom and not ldraw_category.is_empty() else category

	func has_connector(kind: String) -> bool:
		return int(connector_counts.get(kind, 0)) > 0

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
var _fetching: Dictionary = {}      ## hash -> true, so nothing fetches twice
## Waiting their turn. The parts bin asks for a thumbnail per visible
## cell, so without a ceiling a single scroll opens a hundred connections
## at once and every one of them finishes later than it would have.
var _queued_fetches: PackedStringArray = PackedStringArray()
var _fetch_host: Node = null

## Emitted when a part fetched from the network is ready to place.
signal fetched(part_id: String)
## Emitted when one cannot be had at all.
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

	_load_colors()
	loaded.emit(parts.size())
	return true


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
	info.packed = bool(entry.get("packed", true))
	info.reachable = bool(entry.get("reachable", true))
	info.moved_to = entry.get("moved_to", "")
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
		var years: Array = entry.get("years", [0, 0])
		color.first_year = int(years[0])
		color.last_year = int(years[1])
		color.sets = int(entry.get("sets", 0))
		color.current = bool(entry.get("current", false))
		color.plain_code = int(entry.get("plain_code", color.code))

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

	var path: String = _resolve_root() + "parts/" + info.mesh_hash + ".lbm"
	if not FileAccess.file_exists(path):
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

	_mesh_cache[info.mesh_hash] = part
	return part


## Where HTTPRequest nodes are parented. The library is a RefCounted and
## has no tree of its own, so whoever owns it lends one.
func set_fetch_host(host: Node) -> void:
	_fetch_host = host


## True when this build has the part's geometry to hand.
func is_resident(part_id: String) -> bool:
	var info: PartInfo = parts.get(part_id)
	return info != null and (_mesh_cache.has(info.mesh_hash)
		or _custom_meshes.has(info.mesh_hash))


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
	if _mesh_cache.has(info.mesh_hash) or _custom_meshes.has(info.mesh_hash):
		fetched.emit(part_id)
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
	if _fetching.size() >= MAX_IN_FLIGHT:
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
	var request := HTTPRequest.new()
	_fetch_host.add_child(request)
	request.request_completed.connect(
		_on_fetched.bind(request, info.mesh_hash, part_id))

	var url: String = _remote_root() + info.mesh_hash + ".lbm"
	if request.request(url) != OK:
		_fetching.erase(info.mesh_hash)
		request.queue_free()
		fetch_failed.emit(part_id, "could not start the request")
		return false
	return true


## How many part fetches may be open at once. Enough to keep the link
## busy, few enough that a scroll does not queue a hundred of them behind
## each other in the browser's own connection limit.
const MAX_IN_FLIGHT := 6


## Start the next waiting fetch, if there is room.
func _next_fetch() -> void:
	while not _queued_fetches.is_empty() and _fetching.size() < MAX_IN_FLIGHT:
		var part_id: String = _queued_fetches[0]
		_queued_fetches.remove_at(0)
		request_mesh(part_id)


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


func _on_fetched(
	_result: int, code: int, _headers: PackedStringArray,
	body: PackedByteArray, request: HTTPRequest, hash_name: String,
	part_id: String
) -> void:
	request.queue_free()
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
	_mesh_cache[hash_name] = part
	# Everyone who asked for this geometry, not only whoever asked
	# first.
	for asked: String in asked_for:
		fetched.emit(asked)


## Drop cached geometry. The catalogue stays; only vertices go. A made
## part's stay too: there is nowhere to fetch one back from.
func release_geometry() -> void:
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
	if not parts.has(info.id):
		_ordered_ids.append(info.id)
	parts[info.id] = info
	custom[info.id] = source
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


## Parts whose name, category or id contains every word of the query.
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
	# that reaches the right one is one no builder says out loud.
	"wedge plate": "wing",
	"wedge brick": "wedge",
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
}


## The query in the library's own words.
##
## Longest phrase first, so "cheese slope" is not taken apart by the
## entry for "cheese" before it has been recognised.
static func in_ldraw_words(query: String) -> String:
	var text: String = " %s " % query.strip_edges().to_lower()
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


func search(query: String, limit: int = 100) -> Array[PartInfo]:
	var asked: String = in_ldraw_words(query)
	var needles: PackedStringArray = asked.split(" ", false)
	var results: Array[PartInfo] = []
	if needles.is_empty():
		return results

	for id: String in _ordered_ids:
		var info: PartInfo = parts[id]
		if info.is_redirect():
			continue
		var haystack: String = (
			info.name + " " + info.category + " " + info.id).to_lower()
		var matched: bool = true
		for needle: String in needles:
			if not haystack.contains(needle):
				matched = false
				break
		if matched:
			results.append(info)

	# Ranked against the translated words too, or a query the library
	# does not use its own words for scores nothing and the order falls
	# back to whatever the catalogue happened to be in.
	PartsBin._sort_for(results, asked)
	if results.size() > limit:
		results.resize(limit)
	return results


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


func ids() -> PackedStringArray:
	return _ordered_ids
