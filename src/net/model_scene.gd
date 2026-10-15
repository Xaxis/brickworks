## The model, packed for the viewer Claude shows beside a call (MCP Apps):
## which part, in which colour, where and turned how, for every brick.
##
## The viewer (api/_viewer.js, built from tools/viewer/) draws the real
## model in 3D from this and each part's own geometry, the .lbm file this
## app loads, fetched from where this app fetches it: so what rides in an
## answer is a few bytes a brick, and the geometry is fetched once and kept
## by the browser for good, its name being its hash. tools/viewer/scene.js
## reads it; keep the two in step.
##
##   v        1
##   of       what the model was: "world:generation:revision"
##   root     where the geometry is: root + hash + ".lbm"
##   site     this app's address, for the viewer's Open in Brickworks
##   step     LDU per position unit, origin [x, y, z] LDU
##   meshes   [[part, hash ("" for a part made here), name, min xyz, max xyz]]
##   colours  [[code, name, "rrggbb", alpha]]
##   count    bricks; bricks, the columns below, deflated (zlib), base64:
##              u32 the brick's id less the one before it (look_at_model's #)
##              u16 mesh, u16 colour, u8 flags (1: scenery), a pad byte when
##              count is odd, i16 x y z, i16 quaternion x y z w (x 32767)
class_name ModelScene
extends RefCounted

const SCENERY := 1

## The packed model of the world as it last stood, and what it was of.
var _kept_of: String = ""
var _kept: Dictionary = {}


## What the model is now, as the viewer compares it: a changed model is
## another string.
static func of(world: BrickWorld) -> String:
	return "%d:%d:%d" % [world.get_instance_id(), world.generation(), world.revision]


## The model, packed; the same Dictionary again until it changes.
func pack(world: BrickWorld, library: PartLibrary, scenery: Dictionary) -> Dictionary:
	var now: String = of(world)
	if now == _kept_of and not _kept.is_empty():
		return _kept
	_kept = packed(world, library, scenery)
	_kept_of = now
	return _kept


static func packed(world: BrickWorld, library: PartLibrary, scenery: Dictionary) -> Dictionary:
	var bricks: Array = world.bricks()
	bricks.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
	var n: int = bricks.size()
	var meshes: Array = []
	var mesh_of: Dictionary = {}
	var colours: Array = []
	var colour_of: Dictionary = {}
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for brick: BrickWorld.Brick in bricks:
		low = low.min(brick.transform.origin)
		high = high.max(brick.transform.origin)
	if n == 0:
		low = Vector3.ZERO
		high = Vector3.ZERO
	var origin: Vector3 = ((low + high) * 0.5).round()
	var reach: float = maxf((high - origin).abs()[(high - origin).abs().max_axis_index()],
		(origin - low).abs()[(origin - low).abs().max_axis_index()])
	var step: float = 0.25
	while reach / step > 32000.0:
		step *= 2.0

	var size: int = n * 4 + n * 2 + n * 2 + n + (n % 2) + n * 6 + n * 8
	var out := PackedByteArray()
	out.resize(size)
	var at_mesh: int = n * 4
	var at_colour: int = at_mesh + n * 2
	var at_flags: int = at_colour + n * 2
	var at_place: int = at_flags + n + (n % 2)
	var at_turn: int = at_place + n * 6
	var last_id: int = 0
	for k: int in n:
		var brick: BrickWorld.Brick = bricks[k]
		out.encode_u32(k * 4, brick.id - last_id)
		last_id = brick.id
		if not mesh_of.has(brick.part_id):
			mesh_of[brick.part_id] = meshes.size()
			meshes.append(_mesh_row(library, brick.part_id))
			for fixed: int in _fixed_colours(library, brick.part_id):
				_colour_index(library, fixed, colours, colour_of)
		out.encode_u16(at_mesh + k * 2, int(mesh_of[brick.part_id]))
		out.encode_u16(at_colour + k * 2, _colour_index(library, brick.color_code, colours, colour_of))
		out.encode_u8(at_flags + k, SCENERY if scenery.has(brick.id) else 0)
		var place: Vector3 = (brick.transform.origin - origin) / step
		for axis: int in 3:
			out.encode_s16(at_place + (axis * n + k) * 2, clampi(roundi(place[axis]), -32767, 32767))
		var turn: Quaternion = brick.transform.basis.orthonormalized().get_rotation_quaternion()
		var parts: Array[float] = [turn.x, turn.y, turn.z, turn.w]
		for c: int in 4:
			out.encode_s16(at_turn + (c * n + k) * 2, clampi(roundi(parts[c] * 32767.0), -32767, 32767))
	var root: String = library.remote_parts if library != null else ""
	if root.is_empty():
		root = Origin.here() + "/parts/"
	elif not root.ends_with("/"):
		root += "/"
	var site: String = Origin.here()
	return {
		"v": 1,
		"of": of(world),
		"root": root,
		"site": site if not site.is_empty() else Deployment.HOSTED,
		"step": step,
		"origin": [origin.x, origin.y, origin.z],
		"meshes": meshes,
		"colours": colours,
		"count": n,
		"bricks": Marshalls.raw_to_base64(out.compress(FileAccess.COMPRESSION_DEFLATE)),
	}


static func _mesh_row(library: PartLibrary, part_id: String) -> Array:
	var info: PartLibrary.PartInfo = library.parts.get(part_id) if library != null else null
	if info == null:
		return [part_id, "", part_id, -10, -24, -10, 10, 0, 10]
	var box: AABB = info.bounds
	var made: bool = info.custom or library.custom.has(part_id)
	return [part_id, "" if made else info.mesh_hash, Inventory._tidy(info.name),
		box.position.x, box.position.y, box.position.z, box.end.x, box.end.y, box.end.z]


## The colours a part is moulded in apart from the one it is placed in: a
## printed face, a tyre's rubber. Read off its geometry where it is loaded.
static func _fixed_colours(library: PartLibrary, part_id: String) -> PackedInt32Array:
	var fixed := PackedInt32Array()
	if library == null or not library.is_resident(part_id):
		return fixed
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	if mesh == null:
		return fixed
	for code: int in mesh.surface_colors:
		if code != Lbm.COLOR_INHERIT and not fixed.has(code):
			fixed.append(code)
	return fixed


static func _colour_index(library: PartLibrary, code: int, colours: Array, colour_of: Dictionary) -> int:
	if colour_of.has(code):
		return int(colour_of[code])
	var name: String = "Colour %d" % code
	var rgb := Color.MAGENTA
	var alpha: int = 255
	if code >= 0x2000000:
		# A direct colour: 0x2RRGGBB.
		rgb = Color.hex((code & 0xFFFFFF) << 8 | 0xFF)
		name = "#%06X" % (code & 0xFFFFFF)
	elif library != null:
		var colour: PartLibrary.BrickColor = library.color(code)
		rgb = colour.shown
		alpha = colour.alpha
		name = colour.name.replace("_", " ")
	colour_of[code] = colours.size()
	colours.append([code, name, rgb.to_html(false), alpha])
	return int(colour_of[code])
