## The model as a 3D file, for Blender and other renderers, AR, or a 3D
## printer: glTF (one .glb, or a .gltf with its data inside), OBJ with its
## MTL, or STL. File, Export, 3D model… and export_model over MCP both come
## here, through Exports.model_3d.
##
## Written here rather than by GLTFDocument.append_from_scene, which the plan
## named. Measured on 4.7.2: it writes a mesh for every MeshInstance3D (a
## thousand instances of one box came out as a thousand meshes), a
## MultiMesh comes out in one colour, and it does all of it in one call that
## no frame can be given back from. Orthanc is 9,429 parts and 2.6 million
## triangles but only 101 shapes. So here each shape is written once, every
## part is a node pointing at the mesh of its shape in its colour, which is
## glTF's own instancing and is read the same way by Blender, three.js and
## Godot, and the work gives the frame back between parts (Working.Job).
##
## OBJ and STL cannot say "this shape again", so they write every triangle
## of every part, and how many they will write is capped (most_triangles).
##
## Real size, the way each format's readers expect it: glTF and OBJ in
## metres with +Y up; STL in millimetres with +Z up, for a slicer. One LDU
## is 0.4 mm (Lbm.LDU_MM).
##
## Colours: a StandardMaterial3D per colour (material_for), from colors.json:
## the plastic's colour, a see-through colour's alpha, and its finish as
## roughness and metallic. A print drawn in the app (PartPrints) is not
## written; the part comes out in its plastic.
class_name MeshExport
extends RefCounted

const FORMATS: PackedStringArray = ["glb", "gltf", "obj", "stl"]

## How the dialog and the tool name each.
const NAMES: Dictionary = {
	"glb": "GLB (.glb)",
	"gltf": "glTF (.gltf)",
	"obj": "OBJ with its colours (.obj, .mtl)",
	"stl": "STL to 3D print (.stl)",
}

const MIME: Dictionary = {
	"glb": "model/gltf-binary", "gltf": "model/gltf+json", "obj": "model/obj",
	"mtl": "model/mtl", "stl": "model/stl", "zip": "application/zip",
}

## How many triangles OBJ and STL will write: every one of every part, as
## neither format can share a shape. Measured on Orthanc, 2,575,061
## triangles: see "3d model export" in .claude/skills/verify/features/model-io.md.
## A probe lifts them to measure past them.
static var most_triangles: Dictionary = {"obj": 1000000, "stl": 3000000}

const METRES: float = Lbm.LDU_MM / 1000.0
const MILLIMETRES: float = Lbm.LDU_MM

## The app's +Y up turned to a slicer's +Z up: a quarter turn about X, so the
## model's front faces -Y and nothing is mirrored.
const Z_UP := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))

## What a write came to.
class Made extends RefCounted:
	## [file name, PackedByteArray, mime type], in the order to hand over.
	var files: Array = []
	var parts: int = 0
	## Triangles written: every part's for OBJ and STL, each shape's once
	## for glTF.
	var triangles: int = 0
	## glTF: the shapes written, each once.
	var shapes: int = 0
	## Part id -> how many, left out for having no shape in this build.
	var left_out: Dictionary = {}
	var cancelled: bool = false
	## Why nothing was written, when nothing was.
	var refused: String = ""


## One surface of one shape, read off its mesh once.
class Shape extends RefCounted:
	var key: String = ""
	var positions: PackedVector3Array
	var normals: PackedVector3Array
	## Counter-clockwise from outside, as glTF, OBJ and STL want it: the
	## engine's own order is the other way (tools/ldraw/meshfile.py).
	var indices: PackedInt32Array
	## Its LDraw colour, or Lbm.COLOR_INHERIT for the part's own.
	var colour: int = Lbm.COLOR_INHERIT
	var two_sided: bool = false
	## For STL: three corners a triangle, and each triangle's normal.
	var corners: PackedVector3Array = PackedVector3Array()
	var faces: PackedVector3Array = PackedVector3Array()

	func triangles() -> int:
		return indices.size() / 3


var world: BrickWorld
var library: PartLibrary
var scenery: Dictionary = {}
## Reports how far it has got and is asked whether to stop; null where
## nobody is watching (a probe), which paces itself.
var job: Working.Job = null

var _shapes: Dictionary = {}       ## mesh hash -> Array[Shape]
var _pace: FramePace = null
## The glTF's binary buffer, and an OBJ's text, as they are written.
var _bin := PackedByteArray()
var _text := PackedByteArray()
var _lines := PackedStringArray()


## The parts written: everything but the scenery, in the order placed.
func bricks() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if not scenery.has(brick.id):
			out.append(brick)
	out.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
	return out


## The triangles OBJ and STL would write for [param list]: every part's.
func triangles_in(list: Array) -> int:
	var total: int = 0
	for brick: BrickWorld.Brick in list:
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part != null:
			total += part.triangle_count
	return total


## Why [param format] will not be written for this model, or "" when it will.
func refusal(format: String, list: Array = []) -> String:
	if not FORMATS.has(format):
		return "a 3D model is %s" % ", ".join(FORMATS)
	if list.is_empty():
		list = bricks()
	if list.is_empty():
		return "nothing to export"
	if most_triangles.has(format):
		var count: int = triangles_in(list)
		var most: int = int(most_triangles[format])
		if count > most:
			return ("this model is %s triangles, and an %s holds up to %s: %s has no way to "
				+ "write a shape once for all its copies. GLB writes it whole") % [
				Working.comma(count), format.to_upper(), Working.comma(most), format.to_upper()]
	return ""


## Write the model as [param format], named [param title]. A coroutine: it
## gives the frame back between parts.
func write(format: String, title: String) -> Made:
	var made := Made.new()
	var list: Array = bricks()
	made.refused = refusal(format, list)
	if not made.refused.is_empty():
		return made
	_pace = FramePace.new()
	if job != null:
		job.count(0, list.size())
	var base: String = _file_base(title)
	match format:
		"glb", "gltf":
			var built: Dictionary = await _gltf(list, title, made)
			if made.cancelled or built.is_empty():
				return made
			if format == "glb":
				made.files.append([base + ".glb", _glb(built["json"], built["bin"]), MIME["glb"]])
			else:
				var text: String = str(built["json"]).replace("\"%s\"" % DATA, "\"%s%s\"" % [
					"data:application/octet-stream;base64,", Marshalls.raw_to_base64(built["bin"])])
				made.files.append([base + ".gltf", text.to_utf8_buffer(), MIME["gltf"]])
		"obj":
			var pair: Array = await _obj(list, title, base + ".mtl", made)
			if made.cancelled or pair.is_empty():
				return made
			made.files.append([base + ".obj", pair[0], MIME["obj"]])
			made.files.append([base + ".mtl", pair[1], MIME["mtl"]])
		"stl":
			var bytes: PackedByteArray = await _stl(list, title, made)
			if made.cancelled or bytes.is_empty():
				return made
			made.files.append([base + ".stl", bytes, MIME["stl"]])
	if made.parts == 0 and made.refused.is_empty():
		made.refused = "no part of this model has its shape here yet"
		made.files.clear()
	return made


## What a colour looks like in a file: StandardMaterial3D, which is what
## glTF's metallic-roughness material is and what Godot reads one back as.
## Roughness and metallic follow the app's own plastic shader
## (plastic_body.gdshaderinc), without its flecks and grain.
static func material_for(colour: PartLibrary.BrickColor, two_sided: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = colour.name
	var rgb: Color = colour.rgb
	material.albedo_color = Color(rgb.r, rgb.g, rgb.b, 1.0)
	var see_through: bool = colour.is_transparent()
	if see_through:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = colour.alpha / 255.0
	var finish: Vector2 = Vector2(0.0, 0.1) if see_through else Vector2(0.0, 0.28)
	match colour.drawn_as:
		PartLibrary.BrickColor.Finish.CHROME:
			finish = Vector2(1.0, 0.08)
		PartLibrary.BrickColor.Finish.METAL:
			finish = Vector2(0.8, 0.32)
		PartLibrary.BrickColor.Finish.PEARL:
			finish = Vector2(0.35, 0.3)
		PartLibrary.BrickColor.Finish.SPECKLE:
			finish = Vector2(0.3, 0.3)
		PartLibrary.BrickColor.Finish.GLITTER:
			finish = Vector2(0.0, 0.15)
		PartLibrary.BrickColor.Finish.OPAL, PartLibrary.BrickColor.Finish.MILKY:
			finish = Vector2(0.0, 0.4)
		PartLibrary.BrickColor.Finish.GLOW:
			finish = Vector2(0.0, 0.36)
		PartLibrary.BrickColor.Finish.RUBBER:
			finish = Vector2(0.0, 0.75)
		PartLibrary.BrickColor.Finish.FABRIC:
			finish = Vector2(0.0, 0.95)
	material.metallic = finish.x
	material.roughness = finish.y
	if two_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## [param files], [[name, bytes, mime], …], as one zip: in a browser an OBJ
## and its MTL, which a page can hand over only one download at a time.
## Deflated a slice at a time, an OBJ being tens of megabytes.
func zip(files: Array) -> PackedByteArray:
	if _pace == null:
		_pace = FramePace.new()
	var members: Array = []
	for file: Array in files:
		var bytes: PackedByteArray = file[1]
		var packed: Array = await _deflate(bytes)
		members.append([file[0], bytes, packed[0], packed[1]])
	return StudioIo.zip(members)


## Raw deflate and the CRC-32 of [param bytes], for a zip: Godot's gzip,
## streamed, between its ten-byte header and its CRC and length.
func _deflate(bytes: PackedByteArray) -> Array:
	var gzip := StreamPeerGZIP.new()
	gzip.start_compression(false, 1 << 20)
	var out := PackedByteArray()
	var at: int = 0
	while at < bytes.size():
		var sent: Array = gzip.put_partial_data(bytes.slice(at, at + (1 << 18)))
		at += int(sent[1])
		out.append_array(_drained(gzip))
		if _pace.due():
			await _pace.next()
	gzip.finish()
	out.append_array(_drained(gzip))
	return [out.slice(10, out.size() - 8), out.decode_u32(out.size() - 8)]


static func _drained(gzip: StreamPeerGZIP) -> PackedByteArray:
	var waiting: int = gzip.get_available_bytes()
	if waiting <= 0:
		return PackedByteArray()
	return gzip.get_data(waiting)[1]


# -- shapes ---------------------------------------------------------------------


## A part's surfaces, read once per shape; empty when this build has no
## shape for it (on the web, a part still on its way).
func _shape(part_id: String) -> Array:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if info == null:
		return []
	if _shapes.has(info.mesh_hash):
		return _shapes[info.mesh_hash]
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return []
	var out: Array = []
	for n: int in part.surfaces.size():
		var mesh: ArrayMesh = part.surfaces[n]
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		# Read back from the mesh: on the web the geometry lives only on
		# the card once uploaded, and a fetched part was never kept as bytes.
		var arrays: Array = mesh.surface_get_arrays(0)
		var shape := Shape.new()
		shape.key = "%s:%d" % [info.mesh_hash, n]
		shape.positions = arrays[Mesh.ARRAY_VERTEX]
		shape.normals = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		# Every triangle turned the other way round at once: the list read
		# backwards is each triangle backwards (and the triangles in the
		# opposite order, which nothing minds). A loop here was 300 ms on a
		# baseplate's 100,000 triangles.
		indices.reverse()
		shape.indices = indices
		shape.colour = part.surface_colors[n]
		shape.two_sided = part.surface_two_sided[n] == 1
		if shape.indices.size() >= 3:
			out.append(shape)
	_shapes[info.mesh_hash] = out
	return out


## Corners and face normals, for STL.
func _unindex(shape: Shape) -> void:
	if not shape.corners.is_empty():
		return
	var count: int = shape.triangles()
	shape.corners.resize(count * 3)
	shape.faces.resize(count)
	for t: int in count:
		if t & 4095 == 4095 and _pace.due():
			await _pace.next()
		var a: Vector3 = shape.positions[shape.indices[t * 3]]
		var b: Vector3 = shape.positions[shape.indices[t * 3 + 1]]
		var c: Vector3 = shape.positions[shape.indices[t * 3 + 2]]
		shape.corners[t * 3] = a
		shape.corners[t * 3 + 1] = b
		shape.corners[t * 3 + 2] = c
		shape.faces[t] = (b - a).cross(c - a).normalized()


## Whether to stop: a Cancel, or the slice spent, which gives the frame back.
func _between_parts(done: int) -> bool:
	if job != null:
		job.count(done)
		if job.cancelled:
			return true
	if _pace.due():
		await _pace.next()
	return job != null and job.cancelled


static func _name_of(info: PartLibrary.PartInfo, part_id: String) -> String:
	if info == null:
		return part_id
	return "%s %s" % [part_id, " ".join(info.name.split(" ", false))]


static func _file_base(title: String) -> String:
	var base: String = title.to_snake_case().replace("\\", "_").replace("/", "_")
	return base if not base.is_empty() else "model"


# -- glTF -----------------------------------------------------------------------


## Where the glTF's nodes and a .gltf's data go into its text, which is
## written round them: JSON.stringify of Orthanc's whole document at once held
## the frame 300 ms, so each part's node is written as it is made.
const NODES := "@@brickworks nodes@@"
const DATA := "@@brickworks data@@"


## The glTF document as text, and its binary buffer: {"json": String, "bin":
## PackedByteArray}. Each shape's surfaces are written once; a mesh is a
## shape in one colour, sharing the shape's data; a part is a node.
func _gltf(list: Array, title: String, made: Made) -> Dictionary:
	# A part's node is its JSON as soon as it is made; an assembly's is a
	# Dictionary until the end, its children still coming.
	var nodes: Array = [{"name": title if not title.is_empty() else "Model", "children": []}]
	var meshes: Array = []
	var materials: Array = []
	var accessors: Array = []
	var views: Array = []
	_bin = PackedByteArray()
	var node_of_path: Dictionary = {"": 0}
	var accessors_of: Dictionary = {}    ## Shape.key -> [position, normal, indices]
	var mesh_of: Dictionary = {}         ## "hash:colour" -> mesh index
	var material_of: Dictionary = {}     ## "colour:two-sided" -> material index
	var done: int = 0
	for brick: BrickWorld.Brick in list:
		done += 1
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var surfaces: Array = _shape(brick.part_id)
		if surfaces.is_empty():
			made.left_out[brick.part_id] = int(made.left_out.get(brick.part_id, 0)) + 1
			continue
		var mesh_key: String = "%s:%d" % [info.mesh_hash, brick.color_code]
		if not mesh_of.has(mesh_key):
			var primitives: Array = []
			for shape: Shape in surfaces:
				if not accessors_of.has(shape.key):
					accessors_of[shape.key] = await _shape_accessors(shape, accessors, views)
					made.shapes += 1
					made.triangles += shape.triangles()
				var trio: Array = accessors_of[shape.key]
				var code: int = brick.color_code if shape.colour == Lbm.COLOR_INHERIT else shape.colour
				var material_key: String = "%d:%s" % [code, shape.two_sided]
				if not material_of.has(material_key):
					material_of[material_key] = materials.size()
					materials.append(_gltf_material(material_for(library.color(code), shape.two_sided)))
				primitives.append({"attributes": {"POSITION": trio[0], "NORMAL": trio[1]},
					"indices": trio[2], "material": material_of[material_key], "mode": 4})
			mesh_of[mesh_key] = meshes.size()
			meshes.append({"name": "%s %s" % [_name_of(info, brick.part_id),
				library.color(brick.color_code).name], "primitives": primitives})
		var parent: int = _path_node(Assemblies.path_of(brick), nodes, node_of_path)
		(nodes[parent]["children"] as Array).append(nodes.size())
		nodes.append(JSON.stringify({"name": _name_of(info, brick.part_id), "mesh": mesh_of[mesh_key],
			"matrix": _matrix(brick.transform, METRES),
			"extras": {"ldraw_part": brick.part_id, "ldraw_colour": brick.color_code}}, "", false))
		made.parts += 1
		if await _between_parts(done):
			made.cancelled = true
			return {}
	if made.parts == 0:
		return {}
	var texts := PackedStringArray()
	for node: Variant in nodes:
		if node is Dictionary:
			# glTF wants no empty list: a node with no children has none.
			if ((node as Dictionary)["children"] as Array).is_empty():
				(node as Dictionary).erase("children")
			texts.append(JSON.stringify(node, "", false))
		else:
			texts.append(node)
	while _bin.size() % 4 != 0:
		_bin.append(0)
	var doc: Dictionary = {
		"asset": {"version": "2.0", "generator": "Brickworks " + BuildInfo.version()},
		"scene": 0,
		"scenes": [{"name": (nodes[0] as Dictionary)["name"], "nodes": [0]}],
		"nodes": NODES, "meshes": meshes, "materials": materials,
		"accessors": accessors, "bufferViews": views,
		"buffers": [{"byteLength": _bin.size(), "uri": DATA}],
	}
	var text: String = JSON.stringify(doc, "", false).replace("\"%s\"" % NODES,
		"[" + ",".join(texts) + "]")
	var bin: PackedByteArray = _bin
	_bin = PackedByteArray()
	return {"json": text, "bin": bin}


## A shape's position, normal and index data into the buffer, and the three
## accessors that read it.
func _shape_accessors(shape: Shape, accessors: Array, views: Array) -> Array:
	var positions: PackedVector3Array = Transform3D(Basis.from_scale(Vector3.ONE * METRES),
		Vector3.ZERO) * shape.positions
	var low: Vector3 = positions[0]
	var high: Vector3 = positions[0]
	for n: int in positions.size():
		low = low.min(positions[n])
		high = high.max(positions[n])
		if n & 4095 == 4095 and _pace.due():
			await _pace.next()
	var trio: Array = []
	trio.append(accessors.size())
	accessors.append({"bufferView": _view(positions.to_byte_array(), 34962, views),
		"componentType": 5126, "count": positions.size(), "type": "VEC3",
		"min": [low.x, low.y, low.z], "max": [high.x, high.y, high.z]})
	trio.append(accessors.size())
	accessors.append({"bufferView": _view(shape.normals.to_byte_array(), 34962, views),
		"componentType": 5126, "count": shape.normals.size(), "type": "VEC3"})
	trio.append(accessors.size())
	accessors.append({"bufferView": _view(shape.indices.to_byte_array(), 34963, views),
		"componentType": 5125, "count": shape.indices.size(), "type": "SCALAR"})
	return trio


## Into the glTF's one buffer, kept on four bytes as glTF wants.
func _view(bytes: PackedByteArray, target: int, views: Array) -> int:
	while _bin.size() % 4 != 0:
		_bin.append(0)
	views.append({"buffer": 0, "byteOffset": _bin.size(), "byteLength": bytes.size(),
		"target": target})
	_bin.append_array(bytes)
	return views.size() - 1


## A StandardMaterial3D as glTF's: its colour turned linear, as glTF states
## colours, and its alpha, roughness and metallic.
static func _gltf_material(material: StandardMaterial3D) -> Dictionary:
	var linear: Color = material.albedo_color.srgb_to_linear()
	var out: Dictionary = {"name": material.resource_name, "pbrMetallicRoughness": {
		"baseColorFactor": [linear.r, linear.g, linear.b, material.albedo_color.a],
		"metallicFactor": material.metallic, "roughnessFactor": material.roughness}}
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		out["alphaMode"] = "BLEND"
	if material.cull_mode == BaseMaterial3D.CULL_DISABLED:
		out["doubleSided"] = true
	return out


## The node an assembly's parts go under, made with the nodes above it.
static func _path_node(path: String, nodes: Array, node_of_path: Dictionary) -> int:
	if node_of_path.has(path):
		return node_of_path[path]
	var parent: int = _path_node(Assemblies.parent_of(path), nodes, node_of_path)
	var index: int = nodes.size()
	nodes.append({"name": Assemblies.label(path), "children": []})
	(nodes[parent]["children"] as Array).append(index)
	node_of_path[path] = index
	return index


## A part's place as glTF's column-major matrix, its origin in [param scale]
## units. Noise of a turn's arithmetic is put back to the 0 it was meant as.
static func _matrix(at: Transform3D, scale: float) -> Array:
	var b: Basis = at.basis
	var o: Vector3 = at.origin * scale
	var out: Array = [b.x.x, b.x.y, b.x.z, 0.0, b.y.x, b.y.y, b.y.z, 0.0,
		b.z.x, b.z.y, b.z.z, 0.0, o.x, o.y, o.z, 1.0]
	for n: int in out.size():
		if absf(out[n]) < 1e-9:
			out[n] = 0.0
	return out


## The GLB container: a header, the JSON, the buffer, which the JSON's one
## buffer is without naming a file.
static func _glb(text: String, bin: PackedByteArray) -> PackedByteArray:
	var json: PackedByteArray = text.replace(",\"uri\":\"%s\"" % DATA, "").to_utf8_buffer()
	while json.size() % 4 != 0:
		json.append(0x20)
	var out := PackedByteArray()
	out.resize(20)
	out.encode_u32(0, 0x46546C67)
	out.encode_u32(4, 2)
	out.encode_u32(8, 12 + 8 + json.size() + 8 + bin.size())
	out.encode_u32(12, json.size())
	out.encode_u32(16, 0x4E4F534A)
	out.append_array(json)
	var head := PackedByteArray()
	head.resize(8)
	head.encode_u32(0, bin.size())
	head.encode_u32(4, 0x004E4942)
	out.append_array(head)
	out.append_array(bin)
	return out


# -- OBJ ------------------------------------------------------------------------


## The OBJ and its MTL as bytes: every part an object, its own vertices
## written where it stands, in metres.
func _obj(list: Array, title: String, mtl_name: String, made: Made) -> Array:
	_text = ("# %s, from Brickworks: %d parts, in metres, +Y up\nmtllib %s\n"
		% [title, list.size(), mtl_name]).to_utf8_buffer()
	var used: Dictionary = {}          ## material name -> StandardMaterial3D
	var base: int = 1
	var done: int = 0
	_lines.clear()
	for brick: BrickWorld.Brick in list:
		done += 1
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var surfaces: Array = _shape(brick.part_id)
		if surfaces.is_empty():
			made.left_out[brick.part_id] = int(made.left_out.get(brick.part_id, 0)) + 1
			continue
		var place := Transform3D(brick.transform.basis * METRES, brick.transform.origin * METRES)
		var turn := Transform3D(brick.transform.basis.orthonormalized(), Vector3.ZERO)
		var path: String = Assemblies.path_of(brick)
		_lines.append("o %s%s.%d" % ["" if path.is_empty() else path.replace(" ", "_") + "/",
			_name_of(info, brick.part_id).replace(" ", "_"), brick.id])
		for shape: Shape in surfaces:
			var points: PackedVector3Array = place * shape.positions
			for n: int in points.size():
				_lines.append("v %.6f %.6f %.6f" % [points[n].x, points[n].y, points[n].z])
				if n & 4095 == 4095:
					await _written_out()
			var normals: PackedVector3Array = turn * shape.normals
			for n: int in normals.size():
				_lines.append("vn %.4f %.4f %.4f" % [normals[n].x, normals[n].y, normals[n].z])
				if n & 4095 == 4095:
					await _written_out()
			var code: int = brick.color_code if shape.colour == Lbm.COLOR_INHERIT else shape.colour
			var colour: PartLibrary.BrickColor = library.color(code)
			var material_name: String = "%d_%s" % [code, colour.name.replace(" ", "_")]
			if not used.has(material_name):
				used[material_name] = material_for(colour)
			_lines.append("usemtl " + material_name)
			var at: PackedInt32Array = shape.indices
			for i: int in range(0, at.size() - 2, 3):
				var a: int = at[i] + base
				var b: int = at[i + 1] + base
				var c: int = at[i + 2] + base
				_lines.append("f %d//%d %d//%d %d//%d" % [a, a, b, b, c, c])
				if i & 8191 == 8190:
					await _written_out()
			base += shape.positions.size()
			made.triangles += shape.triangles()
		made.parts += 1
		if _lines.size() > 4096:
			await _written_out(true)
		if await _between_parts(done):
			made.cancelled = true
			_text = PackedByteArray()
			return []
	await _written_out(true)
	var obj: PackedByteArray = _text
	_text = PackedByteArray()
	return [obj, _mtl(used, title).to_utf8_buffer()]


## The OBJ's lines so far onto its bytes, when the slice is spent or
## [param now]; then the frame given back if it is spent. A baseplate is a
## hundred thousand triangles, so a slice ends inside a part as well.
func _written_out(now: bool = false) -> void:
	if not now and not _pace.due():
		return
	if not _lines.is_empty():
		_lines.append("")
		_text.append_array("\n".join(_lines).to_utf8_buffer())
		_lines.clear()
	if _pace.due():
		await _pace.next()


## The colours an OBJ names, as MTL: the colour as colors.json gives it, a
## see-through one's alpha as d, and roughness and metallic as the PBR
## extension's Pr and Pm, which Blender reads, with Ns for older readers.
static func _mtl(used: Dictionary, title: String) -> String:
	var lines := PackedStringArray(["# %s, from Brickworks" % title])
	for material_name: String in used:
		var material: StandardMaterial3D = used[material_name]
		var c: Color = material.albedo_color
		var shine: float = 1000.0 * pow(1.0 - material.roughness, 2.0)
		lines.append_array(["", "newmtl " + material_name,
			"Kd %.4f %.4f %.4f" % [c.r, c.g, c.b], "Ks 0.5000 0.5000 0.5000",
			"Ns %.1f" % shine, "d %.3f" % c.a, "Pr %.3f" % material.roughness,
			"Pm %.3f" % material.metallic, "illum 2"])
	lines.append("")
	return "\n".join(lines)


# -- STL ------------------------------------------------------------------------


## Binary STL: one mesh of every part's triangles, in millimetres, standing
## on +Z. Binary rather than text: a fifth of the size, and every slicer
## reads it.
func _stl(list: Array, title: String, made: Made) -> PackedByteArray:
	var total: int = triangles_in(list)
	var out := PackedByteArray()
	# Orthanc's is 123 MB, which takes a tenth of a second to have at all;
	# the frame is given back after it, so no slice of the work joins it.
	out.resize(84 + 50 * total)
	await _pace.next()
	var header: PackedByteArray = ("Brickworks: %s, %d parts, millimetres, Z up"
		% [title, list.size()]).to_utf8_buffer()
	# A header that begins "solid" is taken for a text STL by some readers.
	for n: int in 80:
		out[n] = header[n] if n < header.size() else 0
	var at: int = 84
	var done: int = 0
	for brick: BrickWorld.Brick in list:
		done += 1
		var surfaces: Array = _shape(brick.part_id)
		if surfaces.is_empty():
			made.left_out[brick.part_id] = int(made.left_out.get(brick.part_id, 0)) + 1
			continue
		var place := Transform3D(Z_UP * brick.transform.basis * MILLIMETRES,
			Z_UP * brick.transform.origin * MILLIMETRES)
		var turn := Transform3D(Z_UP * brick.transform.basis.orthonormalized(), Vector3.ZERO)
		var span: int = 0
		for shape: Shape in surfaces:
			await _unindex(shape)
			var corners: PackedVector3Array = place * shape.corners
			var faces: PackedVector3Array = turn * shape.faces
			for t: int in faces.size():
				var n: Vector3 = faces[t]
				var a: Vector3 = corners[t * 3]
				var b: Vector3 = corners[t * 3 + 1]
				var c: Vector3 = corners[t * 3 + 2]
				out.encode_float(at, n.x)
				out.encode_float(at + 4, n.y)
				out.encode_float(at + 8, n.z)
				out.encode_float(at + 12, a.x)
				out.encode_float(at + 16, a.y)
				out.encode_float(at + 20, a.z)
				out.encode_float(at + 24, b.x)
				out.encode_float(at + 28, b.y)
				out.encode_float(at + 32, b.z)
				out.encode_float(at + 36, c.x)
				out.encode_float(at + 40, c.y)
				out.encode_float(at + 44, c.z)
				out.encode_u16(at + 48, 0)
				at += 50
				# A baseplate is a hundred thousand triangles: a slice ends
				# inside a part as well as between them.
				if t & 4095 == 4095 and _pace.due():
					await _pace.next()
			span += faces.size()
		made.triangles += span
		made.parts += 1
		if await _between_parts(done):
			made.cancelled = true
			return PackedByteArray()
	# Parts with no shape here were counted in the total and are not written.
	out.resize(at)
	out.encode_u32(80, made.triangles)
	return out
