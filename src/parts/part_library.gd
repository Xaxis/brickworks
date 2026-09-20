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
		return Vector2i(int(ceil(size.x / 20.0)), int(ceil(size.z / 20.0)))


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
	info.recolourable = bool(entry.get("recolourable", true))
	info.packed = bool(entry.get("packed", true))
	info.reachable = bool(entry.get("reachable", true))
	info.moved_to = entry.get("moved_to", "")
	info.unofficial = bool(entry.get("unofficial", false))

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
func request_mesh(part_id: String) -> bool:
	var info: PartInfo = parts.get(part_id)
	if info == null:
		return false
	if _mesh_cache.has(info.mesh_hash):
		fetched.emit(part_id)
		return true
	if _fetching.has(info.mesh_hash):
		return true
	if _fetching.size() >= MAX_IN_FLIGHT:
		if not _queued_fetches.has(part_id):
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

	_fetching[info.mesh_hash] = true
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
	_fetching.erase(hash_name)
	_next_fetch()

	if code != 200 or body.is_empty():
		fetch_failed.emit(part_id, "HTTP %d" % code)
		return
	var part: Lbm.PartMesh = Lbm.parse(body, part_id)
	if part == null:
		fetch_failed.emit(part_id, "the geometry did not parse")
		return
	_mesh_cache[hash_name] = part
	fetched.emit(part_id)


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
func search(query: String, limit: int = 100) -> Array[PartInfo]:
	var needles: PackedStringArray = query.strip_edges().to_lower().split(" ", false)
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

	PartsBin._sort_for(results, query.strip_edges())
	if results.size() > limit:
		results.resize(limit)
	return results


func ids() -> PackedStringArray:
	return _ordered_ids
