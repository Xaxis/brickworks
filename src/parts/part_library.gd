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
## wire, so the web build carries a curated pack instead: every part is
## still in the catalogue and searchable, and the ones with geometry are
## the ones you can place. Whichever is present wins, web pack first.
const ASSET_ROOTS: Array[String] = [
	"res://assets/web/", "res://assets/generated/"]

var _root: String = ""


## Pick the asset root once, so the catalogue and the meshes cannot
## disagree about which build this is.
func _resolve_root() -> String:
	if not _root.is_empty():
		return _root
	for candidate: String in ASSET_ROOTS:
		if FileAccess.file_exists(candidate + "catalogue.json"):
			_root = candidate
			return _root
	_root = ASSET_ROOTS[ASSET_ROOTS.size() - 1]
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


var parts: Dictionary = {}          ## String id -> PartInfo
var colors: Dictionary = {}         ## int code -> BrickColor
var _ordered_ids: PackedStringArray = PackedStringArray()
var _mesh_cache: Dictionary = {}    ## String hash -> Lbm.PartMesh
var _missing: Dictionary = {}       ## hashes already reported, to log once

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
	var part: Lbm.PartMesh = Lbm.load_part(path)
	if part == null:
		if not _missing.has(info.mesh_hash):
			_missing[info.mesh_hash] = true
			push_warning("part library: %s has no geometry at %s" % [part_id, path])
		return null

	_mesh_cache[info.mesh_hash] = part
	return part


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


## Parts whose name or keywords contain every word of the query.
##
## Deliberately a plain substring match: it is predictable, it needs no
## index, and it runs over 19,000 short strings faster than a frame. The
## design assistant does the clever retrieval; this is for the parts bin.
func search(query: String, limit: int = 100) -> Array[PartInfo]:
	var needles: PackedStringArray = query.strip_edges().to_lower().split(" ", false)
	var results: Array[PartInfo] = []
	if needles.is_empty():
		return results

	for id: String in _ordered_ids:
		var info: PartInfo = parts[id]
		if info.is_redirect():
			continue
		var haystack: String = (info.name + " " + info.category + " " + info.id).to_lower()
		var matched: bool = true
		for needle: String in needles:
			if not haystack.contains(needle):
				matched = false
				break
		if matched:
			results.append(info)
			if results.size() >= limit:
				break
	return results


func ids() -> PackedStringArray:
	return _ordered_ids
