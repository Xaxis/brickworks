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

const CATALOGUE_PATH := "res://assets/generated/catalogue.json"
const COLORS_PATH := "res://assets/generated/colors.json"
const PARTS_DIR := "res://assets/generated/parts/"


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
	var recolourable: bool
	var unofficial: bool
	var keywords: PackedStringArray
	var connectors: Array[Connector] = []

	## Footprint in whole studs, rounded up. Useful for sorting and for
	## the assistant's reasoning; not a substitute for real collision.
	func footprint_studs() -> Vector2i:
		return Vector2i(int(ceil(size.x / 20.0)), int(ceil(size.z / 20.0)))


## One place a part can join another.
class Connector extends RefCounted:
	var kind: String            ## stud / tube / pin_hole / axle_hole / ...
	var gender: String          ## male / female / neutral
	var position: Vector3       ## part-local, LDU
	var axis: Vector3           ## unit, pointing out of the part


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


func load_catalogue(path: String = CATALOGUE_PATH) -> bool:
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
	info.recolourable = bool(entry.get("recolourable", true))
	info.unofficial = bool(entry.get("unofficial", false))

	var size: Array = entry.get("size_ldu", [0, 0, 0])
	info.size = Vector3(size[0], size[1], size[2])
	var lo: Array = entry.get("bounds_min", [0, 0, 0])
	var hi: Array = entry.get("bounds_max", [0, 0, 0])
	var low := Vector3(lo[0], lo[1], lo[2])
	info.bounds = AABB(low, Vector3(hi[0], hi[1], hi[2]) - low)

	for word: Variant in entry.get("keywords", []):
		info.keywords.append(str(word))

	for raw: Variant in entry.get("connectors", []):
		var record: Dictionary = raw
		var connector: Connector = Connector.new()
		connector.kind = record.get("kind", "")
		connector.gender = record.get("gender", "")
		var p: Array = record.get("pos", [0, 0, 0])
		var a: Array = record.get("axis", [0, 1, 0])
		connector.position = Vector3(p[0], p[1], p[2])
		connector.axis = Vector3(a[0], a[1], a[2])
		info.connectors.append(connector)

	return info


func _load_colors() -> void:
	var file: FileAccess = FileAccess.open(COLORS_PATH, FileAccess.READ)
	if file == null:
		push_warning("part library: no colours at %s" % COLORS_PATH)
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

	var path: String = PARTS_DIR + info.mesh_hash + ".lbm"
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
