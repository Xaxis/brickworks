## Reader for the .lbm part geometry files written by tools/build_meshes.py.
##
## The format is deliberately close to what [ArrayMesh] wants, so loading a
## part is a read and two [code]PackedArray[/code] copies rather than a parse.
## The layout is documented in tools/ldraw/meshfile.py; keep the two in step.
##
## Coordinates are already in the application's convention: +Y up, right
## handed, and one unit is one LDU, which is 0.4 mm exactly. Nothing here
## flips anything.
##
## Positions arrive as 16-bit counts of a fixed step — 1/64 LDU for all but
## a handful of very long parts — and normals as octahedral pairs. Decoding
## is a multiply and a fold, which is cheaper than the bandwidth the floats
## would have cost.
class_name Lbm
extends RefCounted

const MAGIC := 0x334D424C  # "LBM3" little-endian
const HEADER_SIZE := 44
const CONNECTOR_SIZE := 26
const BOX_SIZE := 12
const SOCKET_SIZE := 8

## Wire order of connector kinds and genders; append only.
const KINDS: PackedStringArray = [
	"stud", "tube", "ridge", "axle", "axle_hole", "pin", "pin_hole",
	"clip", "bar", "ball", "socket"]
const GENDERS: PackedStringArray = ["male", "female", "neutral"]
const VERTEX_SIZE := 10
const I16_MAX := 32767.0
const SURFACE_TWO_SIDED := 1

## LDraw's "current colour" code. A surface with this colour takes the
## colour the part is placed in; any other code is moulded in and fixed.
const COLOR_INHERIT := 16

## One unit is one LDU.
const LDU_MM := 0.4


## Geometry for a single part, ready to hand to the renderer.
##
## Each surface is its own single-surface [ArrayMesh] rather than one mesh
## with several surfaces. That is because a [MultiMesh] applies one instance
## colour to everything it draws: a printed head has to put its recolourable
## plastic and its fixed-colour print into separate MultiMeshes or the print
## takes the colour of the head. Most parts have exactly one surface, where
## the two arrangements are identical.
class Connector extends RefCounted:
	var kind: String
	var gender: String
	var position: Vector3   ## part-local, LDU
	var axis: Vector3       ## unit, pointing out of the part


class PartMesh extends RefCounted:
	var surfaces: Array[ArrayMesh] = []
	var bounds: AABB
	## Where this part can join others.
	var connectors: Array[Connector] = []
	## Collision cover in whole lattice cells: Vector3i position and size.
	var boxes: Array[AABB] = []
	## Underside positions that accept a stud, in LDU.
	var sockets: PackedVector2Array = PackedVector2Array()
	## The occupancy lattice these boxes are measured in, in LDU.
	var cell_ldu: float = 2.0
	## Per surface, the LDraw colour code it is moulded in. Entries equal to
	## [constant COLOR_INHERIT] are recoloured per instance.
	var surface_colors: PackedInt32Array = PackedInt32Array()
	var surface_two_sided: PackedByteArray = PackedByteArray()
	var triangle_count: int = 0

	## True when the part has at least one surface that follows the colour
	## it is placed in, which is every ordinary brick.
	func is_recolourable() -> bool:
		for code: int in surface_colors:
			if code == COLOR_INHERIT:
				return true
		return false

	func surface_count() -> int:
		return surfaces.size()


## Read a part from disk. Returns null and pushes an error if the file is
## missing or malformed, because a bad part must not take the app down.
static func load_part(path: String) -> PartMesh:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("lbm: cannot open %s (%d)" % [path, FileAccess.get_open_error()])
		return null
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return parse(bytes, path)


## Parse a part from bytes, which is what the web build does after a fetch.
static func parse(bytes: PackedByteArray, source: String = "<memory>") -> PartMesh:
	if bytes.size() < 32:
		push_error("lbm: %s is too short to be a part" % source)
		return null
	if bytes.decode_u32(0) != MAGIC:
		push_error("lbm: %s does not start with LBM1" % source)
		return null

	var surface_count: int = bytes.decode_u16(6)
	if surface_count <= 0:
		push_error("lbm: %s declares no surfaces" % source)
		return null

	var scale: float = bytes.decode_float(8)
	if scale <= 0.0:
		push_error("lbm: %s has an invalid quantisation scale" % source)
		return null
	var inv_scale: float = 1.0 / scale

	var part: PartMesh = PartMesh.new()
	var lo := Vector3(bytes.decode_float(12), bytes.decode_float(16), bytes.decode_float(20))
	var hi := Vector3(bytes.decode_float(24), bytes.decode_float(28), bytes.decode_float(32))
	part.bounds = AABB(lo, hi - lo)

	var connector_count: int = bytes.decode_u16(36)
	var box_count: int = bytes.decode_u16(38)
	var socket_count: int = bytes.decode_u16(40)
	part.cell_ldu = float(bytes.decode_u16(42)) / 16.0

	var offset: int = HEADER_SIZE
	for surface_index: int in surface_count:
		if offset + 12 > bytes.size():
			push_error("lbm: %s truncated at surface %d" % [source, surface_index])
			return null

		var color: int = bytes.decode_s16(offset)
		var flags: int = bytes.decode_u16(offset + 2)
		var vertex_count: int = bytes.decode_u32(offset + 4)
		var index_count: int = bytes.decode_u32(offset + 8)
		offset += 12

		var vertex_bytes: int = vertex_count * VERTEX_SIZE
		var index_stride: int = 2 if vertex_count <= 0xFFFF else 4
		if offset + vertex_bytes + index_count * index_stride > bytes.size():
			push_error("lbm: %s truncated in surface %d body" % [source, surface_index])
			return null

		var positions := PackedVector3Array()
		var normals := PackedVector3Array()
		positions.resize(vertex_count)
		normals.resize(vertex_count)
		var cursor: int = offset
		for v: int in vertex_count:
			positions[v] = Vector3(
				float(bytes.decode_s16(cursor)) * inv_scale,
				float(bytes.decode_s16(cursor + 2)) * inv_scale,
				float(bytes.decode_s16(cursor + 4)) * inv_scale)
			normals[v] = _oct_decode(
				bytes.decode_s16(cursor + 6),
				bytes.decode_s16(cursor + 8))
			cursor += VERTEX_SIZE
		offset += vertex_bytes

		var indices := PackedInt32Array()
		indices.resize(index_count)
		if index_stride == 2:
			for i: int in index_count:
				indices[i] = bytes.decode_u16(offset + i * 2)
		else:
			for i: int in index_count:
				indices[i] = bytes.decode_u32(offset + i * 4)
		offset += index_count * index_stride

		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices

		var surface_mesh := ArrayMesh.new()
		surface_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		# The bounds come from the file, which knows the real extent;
		# letting Godot recompute them costs a pass over every vertex.
		surface_mesh.custom_aabb = part.bounds
		part.surfaces.append(surface_mesh)

		part.surface_colors.append(color)
		part.surface_two_sided.append(1 if (flags & SURFACE_TWO_SIDED) != 0 else 0)
		part.triangle_count += index_count / 3

	# The connectivity rides along with the geometry because it is wanted
	# at the same moment: when a part is first placed, never before.
	for _c: int in connector_count:
		if offset + CONNECTOR_SIZE > bytes.size():
			push_error("lbm: %s truncated in connectors" % source)
			return part
		var connector: Connector = Connector.new()
		var kind_index: int = bytes.decode_u8(offset)
		var gender_index: int = bytes.decode_u8(offset + 1)
		connector.kind = KINDS[kind_index] if kind_index < KINDS.size() else ""
		connector.gender = GENDERS[gender_index] if gender_index < GENDERS.size() else ""
		connector.position = Vector3(
			bytes.decode_float(offset + 2),
			bytes.decode_float(offset + 6),
			bytes.decode_float(offset + 10))
		connector.axis = Vector3(
			bytes.decode_float(offset + 14),
			bytes.decode_float(offset + 18),
			bytes.decode_float(offset + 22))
		part.connectors.append(connector)
		offset += CONNECTOR_SIZE

	for _b: int in box_count:
		if offset + BOX_SIZE > bytes.size():
			push_error("lbm: %s truncated in boxes" % source)
			return part
		part.boxes.append(AABB(
			Vector3(bytes.decode_s16(offset),
				bytes.decode_s16(offset + 2),
				bytes.decode_s16(offset + 4)),
			Vector3(bytes.decode_s16(offset + 6),
				bytes.decode_s16(offset + 8),
				bytes.decode_s16(offset + 10))))
		offset += BOX_SIZE

	for _s: int in socket_count:
		if offset + SOCKET_SIZE > bytes.size():
			push_error("lbm: %s truncated in sockets" % source)
			return part
		part.sockets.append(Vector2(
			bytes.decode_float(offset), bytes.decode_float(offset + 4)))
		offset += SOCKET_SIZE

	return part


## Unfold an octahedral-encoded normal.
##
## The unit sphere is projected onto an octahedron whose lower half is
## folded out into the square, so two numbers carry a direction with no
## bits wasted on lengths that cannot occur. Inverse of oct_encode() in
## tools/ldraw/meshfile.py.
static func _oct_decode(qx: int, qy: int) -> Vector3:
	var x: float = float(qx) / I16_MAX
	var y: float = float(qy) / I16_MAX
	var z: float = 1.0 - absf(x) - absf(y)
	if z < 0.0:
		var fx: float = (1.0 - absf(y)) * (1.0 if x >= 0.0 else -1.0)
		var fy: float = (1.0 - absf(x)) * (1.0 if y >= 0.0 else -1.0)
		x = fx
		y = fy
	return Vector3(x, y, z).normalized()
