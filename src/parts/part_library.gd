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
	return str(_elements.get("%s/%d" % [part_id, code], ""))


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
	## True when `colors` is known to be short. Sixty-nine Rebrickable
	## colours have no LDraw counterpart — BrickLink's "Dark Purple" is
	## LEGO's "Medium Lilac", and matching them by swatch was measured and
	## does not work — so a part made in one of them has a list that is
	## right as far as it goes. Nothing may read a gap in a short list as
	## proof the colour was never made.
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
	var code: int
	var name: String
	var rgb: Color
	var edge: Color
	var alpha: int
	var finish: String          ## solid / transparent / chrome / ...

	func is_transparent() -> bool:
		return alpha < 255


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
		var rgb: Array = entry.get("rgb", [255, 0, 255])
		var edge: Array = entry.get("edge", [0, 0, 0])
		# Stored as 0-255 sRGB; the shader linearises, so keep it raw here.
		color.rgb = Color(rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0, color.alpha / 255.0)
		color.edge = Color(edge[0] / 255.0, edge[1] / 255.0, edge[2] / 255.0)
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
	return info != null and _mesh_cache.has(info.mesh_hash)


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
	if _mesh_cache.has(info.mesh_hash):
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


## Drop cached geometry. The catalogue stays; only vertices go.
func release_geometry() -> void:
	_mesh_cache.clear()


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
	fallback.alpha = 255
	fallback.finish = "solid"
	return fallback


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
