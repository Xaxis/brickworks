## Files of the kinds MeshFile reads beside OBJ, STL and glTF, made here
## rather than downloaded so the probe knows the answer:
##
##   bunny.ply          text PLY with Windows line ends, a colour a byte a
##                      channel, as MeshLab writes a scan
##   bunny_binary.ply   binary little-endian PLY with normals and colours
##                      as fractions
##   prism.ply          binary big-endian PLY as the Stanford Armadillo is
##                      written: a byte of "intensity" before each face's
##                      corners, faces of six and four corners coloured by
##                      face, doubles for positions, an element after them
##                      nothing reads
##   shapes.3mf         a 3MF as a slicer writes one: base materials, a
##                      colour group a corner at a time, a picture, objects
##                      placed by components (one mirrored), an object in a
##                      second model file, and a support left out
##   scene.vox          MagicaVoxel: two models with their own palette, one
##                      moved and one turned by the scene, and a third
##                      hidden
##   plain.vox          one model and no palette, in MagicaVoxel's own
##   bunny.fbx          binary FBX: the bunny's vertex colours on a moved
##                      node, and a cube in a red material
##   spotty.obj, .png   an OBJ with places on a picture and no .mtl, and
##                      the picture, as Spot came
##
## All are in tests/fixtures/brickify/formats/, written again by
## mesh_formats_probe.gd -- --fixtures.
class_name MeshFormatSamples
extends RefCounted

const RED := Color8(200, 32, 32)
const BLUE := Color8(32, 48, 200)
const GREEN := Color8(32, 200, 32)
const YELLOW := Color8(240, 240, 32)


## Every fixture by its file name.
static func all() -> Dictionary:
	var bunny: MeshFile = BrickifySamples.bunny()
	return {"bunny.ply": ply_text(bunny), "bunny_binary.ply": ply_binary(bunny),
		"prism.ply": prism_ply(), "shapes.3mf": shapes_3mf(), "scene.vox": scene_vox(),
		"plain.vox": plain_vox(), "bunny.fbx": fbx(bunny), "spotty.obj": spotty_obj(),
		"spotty.png": spotty_png()}


# -- PLY ----------------------------------------------------------------------


static func ply_text(mesh: MeshFile) -> PackedByteArray:
	var lines := PackedStringArray(["ply", "format ascii 1.0",
		"comment %s, made by Brickworks' mesh formats probe (CC0)" % mesh.name,
		"element vertex %d" % mesh.positions.size(), "property float x", "property float y",
		"property float z", "property uchar red", "property uchar green", "property uchar blue",
		"element face %d" % mesh.triangle_count(), "property list uchar int vertex_indices",
		"end_header"])
	for n: int in mesh.positions.size():
		var p: Vector3 = mesh.positions[n]
		var c: Color = mesh.colours[n]
		lines.append("%.5f %.5f %.5f %d %d %d" % [p.x, p.y, p.z, c.r8, c.g8, c.b8])
	for t: int in mesh.triangle_count():
		lines.append("3 %d %d %d" % [3 * t, 3 * t + 1, 3 * t + 2])
	return ("\r\n".join(lines) + "\r\n").to_utf8_buffer()


static func ply_binary(mesh: MeshFile) -> PackedByteArray:
	var head := PackedStringArray(["ply", "format binary_little_endian 1.0",
		"comment %s, made by Brickworks' mesh formats probe (CC0)" % mesh.name,
		"element vertex %d" % mesh.positions.size()])
	for name: String in ["x", "y", "z", "nx", "ny", "nz", "red", "green", "blue"]:
		head.append("property float " + name)
	head.append_array(["element face %d" % mesh.triangle_count(),
		"property list uchar uint vertex_indices", "end_header"])
	var body := StreamPeerBuffer.new()
	body.put_data(("\n".join(head) + "\n").to_ascii_buffer())
	for n: int in mesh.positions.size():
		for value: float in [mesh.positions[n].x, mesh.positions[n].y, mesh.positions[n].z,
				mesh.normals[n].x, mesh.normals[n].y, mesh.normals[n].z, mesh.colours[n].r,
				mesh.colours[n].g, mesh.colours[n].b]:
			body.put_float(value)
	for t: int in mesh.triangle_count():
		body.put_u8(3)
		for corner: int in 3:
			body.put_u32(3 * t + corner)
	return body.data_array


## Six corners round each end and four up each side: 8 faces, fanned into
## 20 triangles, the ends red and the sides blue.
static func prism_ply() -> PackedByteArray:
	var head := PackedStringArray(["ply", "format binary_big_endian 1.0",
		"comment a six-sided prism, made by Brickworks' mesh formats probe (CC0)",
		"element vertex 12", "property double x", "property double y", "property double z",
		"element face 8", "property uchar intensity", "property list uchar int vertex_indices",
		"property uchar red", "property uchar green", "property uchar blue",
		"element edge 2", "property int vertex1", "property int vertex2", "end_header"])
	var body := StreamPeerBuffer.new()
	body.big_endian = true
	body.put_data(("\n".join(head) + "\n").to_ascii_buffer())
	for z: float in [0.0, 4.0]:
		for n: int in 6:
			body.put_double(3.0 * cos(TAU * n / 6.0))
			body.put_double(3.0 * sin(TAU * n / 6.0))
			body.put_double(z)
	var faces: Array = [[5, 4, 3, 2, 1, 0], [6, 7, 8, 9, 10, 11]]
	for n: int in 6:
		faces.append([n, (n + 1) % 6, 6 + (n + 1) % 6, 6 + n])
	for face: Array in faces:
		body.put_u8(128)
		body.put_u8(face.size())
		for corner: int in face:
			body.put_32(corner)
		var colour: Color = RED if face.size() == 6 else BLUE
		body.put_u8(colour.r8)
		body.put_u8(colour.g8)
		body.put_u8(colour.b8)
	for edge: Array in [[0, 1], [1, 2]]:
		body.put_32(edge[0])
		body.put_32(edge[1])
	return body.data_array


# -- 3MF ----------------------------------------------------------------------


## A cube ten across, its corner at the origin: [vertices XML, triangles
## XML] with [param props] on every triangle.
static func _cube_xml(props: String) -> Array:
	var vertices := PackedStringArray()
	for n: int in 8:
		vertices.append('<vertex x="%d" y="%d" z="%d"/>' % [10 * (n & 1), 5 * (n & 2),
			10 * (n >> 2)])
	var triangles := PackedStringArray()
	for t: Array in [[0, 2, 1], [1, 2, 3], [4, 5, 6], [5, 7, 6], [0, 1, 4], [1, 5, 4],
			[2, 6, 3], [3, 6, 7], [0, 4, 2], [2, 4, 6], [1, 3, 5], [3, 7, 5]]:
		triangles.append('<triangle v1="%d" v2="%d" v3="%d"%s/>' % [t[0], t[1], t[2], props])
	return ["".join(vertices), "".join(triangles)]


## 44 triangles laid, and a support that is not: two cubes red (one
## mirrored), a wedge green and yellow, a cube blue from the second file,
## and a square half red and half blue from its picture.
static func shapes_3mf() -> PackedByteArray:
	var cube: Array = _cube_xml("")
	var wedge := PackedStringArray()
	for p: Vector3i in [Vector3i(0, 0, 0), Vector3i(10, 0, 0), Vector3i(0, 10, 0),
			Vector3i(0, 0, 5), Vector3i(10, 0, 5), Vector3i(0, 10, 5)]:
		wedge.append('<vertex x="%d" y="%d" z="%d"/>' % [p.x, p.y, p.z])
	var faces := PackedStringArray()
	var n: int = 0
	for t: Array in [[0, 2, 1], [3, 4, 5], [0, 1, 4], [0, 4, 3], [1, 2, 5], [1, 5, 4],
			[2, 0, 3], [2, 3, 5]]:
		# The last triangle a colour at each corner, the rest one each.
		var props: String = ' pid="2" p1="0" p2="1" p3="0"' if n == 7 \
			else ' pid="2" p1="%d"' % (n % 2)
		faces.append('<triangle v1="%d" v2="%d" v3="%d"%s/>' % [t[0], t[1], t[2], props])
		n += 1
	var model: String = ('<?xml version="1.0" encoding="UTF-8"?>\n'
		+ '<model unit="millimeter" xml:lang="en-US" '
		+ 'xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" '
		+ 'xmlns:m="http://schemas.microsoft.com/3dmanufacturing/material/2015/02" '
		+ 'xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06">'
		+ '<metadata name="Title">Brickworks mesh formats probe (CC0)</metadata><resources>'
		+ '<basematerials id="1"><base name="Red" displaycolor="#C82020FF"/>'
		+ '<base name="Blue" displaycolor="#2030C8"/></basematerials>'
		+ '<m:colorgroup id="2"><m:color color="#20C820"/><m:color color="#F0F020FF"/>'
		+ '</m:colorgroup>'
		+ '<m:texture2d id="8" path="/3D/Texture/halves.png" contenttype="image/png"/>'
		+ '<m:texture2dgroup id="9" texid="8"><m:tex2coord u="0.1" v="0.5"/>'
		+ '<m:tex2coord u="0.4" v="0.5"/><m:tex2coord u="0.6" v="0.5"/>'
		+ '<m:tex2coord u="0.9" v="0.5"/></m:texture2dgroup>'
		+ '<object id="3" type="model" pid="1" pindex="0"><mesh><vertices>%s</vertices>'
		+ '<triangles>%s</triangles></mesh></object>'
		+ '<object id="4" type="model"><mesh><vertices>%s</vertices><triangles>%s'
		+ '</triangles></mesh></object>'
		+ '<object id="5" type="model"><components>'
		+ '<component objectid="3" transform="1 0 0 0 1 0 0 0 1 20 0 0"/>'
		+ '<component objectid="3" transform="-1 0 0 0 1 0 0 0 1 -20 0 0"/>'
		+ '</components></object>'
		+ '<object id="6" type="support" pid="1" pindex="1"><mesh><vertices>%s</vertices>'
		+ '<triangles>%s</triangles></mesh></object>'
		+ '<object id="7" type="model"><components>'
		+ '<component p:path="/3D/Objects/part.model" objectid="1" '
		+ 'transform="1 0 0 0 1 0 0 0 1 0 30 0"/></components></object>'
		+ '<object id="10" type="model"><mesh><vertices>'
		+ '<vertex x="0" y="0" z="0"/><vertex x="10" y="0" z="0"/>'
		+ '<vertex x="10" y="0" z="10"/><vertex x="0" y="0" z="10"/></vertices><triangles>'
		+ '<triangle v1="0" v2="1" v3="3" pid="9" p1="0" p2="1" p3="0"/>'
		+ '<triangle v1="1" v2="2" v3="3" pid="9" p1="3" p2="2" p3="3"/>'
		+ '</triangles></mesh></object>'
		+ '</resources><build><item objectid="5"/>'
		+ '<item objectid="4" transform="1 0 0 0 1 0 0 0 1 0 0 20"/>'
		+ '<item objectid="7"/><item objectid="6" transform="1 0 0 0 1 0 0 0 1 0 0 -40"/>'
		+ '<item objectid="10" transform="1 0 0 0 1 0 0 0 1 0 -20 0"/>'
		+ '</build></model>') % [cube[0], cube[1], "".join(wedge), "".join(faces),
			cube[0], cube[1]]
	var part: String = ('<?xml version="1.0" encoding="UTF-8"?>\n'
		+ '<model unit="millimeter" '
		+ 'xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">'
		+ '<resources><basematerials id="2"><base name="Blue" displaycolor="#2030C8FF"/>'
		+ '</basematerials><object id="1" type="model" pid="2" pindex="0"><mesh>'
		+ '<vertices>%s</vertices><triangles>%s</triangles></mesh></object></resources>'
		+ '<build/></model>') % [cube[0], cube[1]]
	var types: String = ('<?xml version="1.0" encoding="UTF-8"?>\n<Types '
		+ 'xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
		+ '<Default Extension="rels" '
		+ 'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
		+ '<Default Extension="model" '
		+ 'ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>'
		+ '<Default Extension="png" ContentType="image/png"/></Types>')
	var rels: String = ('<?xml version="1.0" encoding="UTF-8"?>\n<Relationships '
		+ 'xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
		+ '<Relationship Target="/3D/3dmodel.model" Id="rel0" '
		+ 'Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>'
		+ '</Relationships>')
	var halves := Image.create(2, 1, false, Image.FORMAT_RGB8)
	halves.set_pixel(0, 0, RED)
	halves.set_pixel(1, 0, BLUE)
	return StudioIo.zip([["[Content_Types].xml", types.to_utf8_buffer()],
		["_rels/.rels", rels.to_utf8_buffer()], ["3D/3dmodel.model", model.to_utf8_buffer()],
		["3D/Objects/part.model", part.to_utf8_buffer()],
		["3D/Texture/halves.png", halves.save_png_to_buffer()]])


# -- VOX ----------------------------------------------------------------------


## A chunk: its id, its content's size, no children, its content.
static func _chunk(id: String, content: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(id.to_ascii_buffer())
	out.resize(12)
	out.encode_u32(4, content.size())
	out.encode_u32(8, 0)
	out.append_array(content)
	return out


static func _words(values: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(4 * values.size())
	for n: int in values.size():
		out.encode_s32(4 * n, int(values[n]))
	return out


static func _dict(pairs: Dictionary) -> PackedByteArray:
	var out: PackedByteArray = _words([pairs.size()])
	for key: Variant in pairs:
		for word: String in [str(key), str(pairs[key])]:
			out.append_array(_words([word.length()]))
			out.append_array(word.to_ascii_buffer())
	return out


static func _vox(version: int, chunks: Array) -> PackedByteArray:
	var children := PackedByteArray()
	for chunk: PackedByteArray in chunks:
		children.append_array(chunk)
	var out := PackedByteArray()
	out.append_array("VOX ".to_ascii_buffer())
	out.append_array(_words([version]))
	out.append_array("MAIN".to_ascii_buffer())
	out.append_array(_words([0, children.size()]))
	out.append_array(children)
	return out


static func _model(size: Vector3i, voxels: Array) -> Array[PackedByteArray]:
	var xyzi: PackedByteArray = _words([voxels.size()])
	for voxel: Array in voxels:
		xyzi.append_array(PackedByteArray(voxel))
	return [_chunk("SIZE", _words([size.x, size.y, size.z])), _chunk("XYZI", xyzi)]


## A cube four voxels a side, its bottom layer green and the rest red,
## moved ten along x; a tower two by two by six in blue, turned a quarter
## about z and lifted three; and a third, the cube again, hidden.
static func scene_vox() -> PackedByteArray:
	var cube: Array = []
	for z: int in 4:
		for y: int in 4:
			for x: int in 4:
				cube.append([x, y, z, 2 if z == 0 else 1])
	var tower: Array = []
	for z: int in 6:
		for y: int in 2:
			for x: int in 2:
				tower.append([x, y, z, 3])
	var palette := PackedByteArray()
	palette.resize(1024)
	for n: int in 3:
		var colour: Color = [RED, GREEN, BLUE][n]
		palette.encode_u32(4 * n, colour.to_abgr32())
	var chunks: Array = []
	chunks.append(_chunk("PACK", _words([2])))
	chunks.append_array(_model(Vector3i(4, 4, 4), cube))
	chunks.append_array(_model(Vector3i(2, 2, 6), tower))
	# 0 the root, 1 its group; 2 moves the cube (3); 4 turns the tower (5);
	# 6 hides another cube (7).
	var node := func(id: int, attributes: Dictionary, rest: Array,
			frame: Dictionary = {}) -> PackedByteArray:
		var content: PackedByteArray = _words([id])
		content.append_array(_dict(attributes))
		content.append_array(_words(rest))
		if rest.size() == 4:
			content.append_array(_dict(frame))
		return content
	chunks.append(_chunk("nTRN", node.call(0, {}, [1, -1, -1, 1])))
	var group: PackedByteArray = _words([1])
	group.append_array(_dict({}))
	group.append_array(_words([3, 2, 4, 6]))
	chunks.append(_chunk("nGRP", group))
	chunks.append(_chunk("nTRN", node.call(2, {"_name": "cube"}, [3, -1, 0, 1],
		{"_t": "10 0 0"})))
	chunks.append(_chunk("nTRN", node.call(4, {"_name": "tower"}, [5, -1, 0, 1],
		{"_r": "17", "_t": "0 0 3"})))
	chunks.append(_chunk("nTRN", node.call(6, {"_hidden": "1"}, [7, -1, 0, 1],
		{"_t": "-20 0 0"})))
	for shape: Array in [[3, 0], [5, 1], [7, 0]]:
		var content: PackedByteArray = _words([shape[0]])
		content.append_array(_dict({}))
		content.append_array(_words([1, shape[1]]))
		content.append_array(_dict({}))
		chunks.append(_chunk("nSHP", content))
	var layer: PackedByteArray = _words([0])
	layer.append_array(_dict({"_name": "front"}))
	layer.append_array(_words([-1]))
	chunks.append(_chunk("LAYR", layer))
	chunks.append(_chunk("RGBA", palette))
	return _vox(200, chunks)


## Five voxels in a row in MagicaVoxel's own colours 1, 36, 216, 255 and
## 37: white, red, the first of its reds, the last of its greys, and pale
## cyan. An old file: no scene and no palette.
static func plain_vox() -> PackedByteArray:
	var chunks: Array = []
	chunks.append_array(_model(Vector3i(5, 1, 1), [[0, 0, 0, 1], [1, 0, 0, 36], [2, 0, 0, 216],
		[3, 0, 0, 255], [4, 0, 0, 37]]))
	return _vox(150, chunks)


# -- FBX ----------------------------------------------------------------------


## A value of an FBX record, typed as FBX types them: an int an I, an
## {"L": id} an L, a float a D, a String an S, an {"S": [name, class]} an
## object's name as a binary FBX writes it (the two parted by 0 and 1), and
## arrays d and i, packed with zlib as Blender and Maya pack them.
static func _fbx_value(value: Variant) -> PackedByteArray:
	var out := PackedByteArray()
	if value is Dictionary and (value as Dictionary).has("S"):
		var text: PackedByteArray = str(value["S"][0]).to_utf8_buffer()
		text.append_array(PackedByteArray([0, 1]))
		text.append_array(str(value["S"][1]).to_utf8_buffer())
		out.resize(5)
		out[0] = "S".unicode_at(0)
		out.encode_u32(1, text.size())
		out.append_array(text)
	elif value is Dictionary:
		out.resize(9)
		out[0] = "L".unicode_at(0)
		out.encode_s64(1, int(value["L"]))
	elif value is int:
		out.resize(5)
		out[0] = "I".unicode_at(0)
		out.encode_s32(1, int(value))
	elif value is float:
		out.resize(9)
		out[0] = "D".unicode_at(0)
		out.encode_double(1, float(value))
	elif value is String:
		var text: PackedByteArray = str(value).to_utf8_buffer()
		out.resize(5)
		out[0] = "S".unicode_at(0)
		out.encode_u32(1, text.size())
		out.append_array(text)
	else:
		var raw: PackedByteArray = (value as PackedFloat64Array).to_byte_array() \
			if value is PackedFloat64Array else (value as PackedInt32Array).to_byte_array()
		var packed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_DEFLATE)
		out.resize(13)
		out[0] = ("d" if value is PackedFloat64Array else "i").unicode_at(0)
		out.encode_u32(1, raw.size() / (8 if value is PackedFloat64Array else 4))
		out.encode_u32(5, 1)
		out.encode_u32(9, packed.size())
		out.append_array(packed)
	return out


## An FBX record at [param offset] in the file: [name, values, children].
static func _fbx_record(record: Array, offset: int) -> PackedByteArray:
	var name: PackedByteArray = str(record[0]).to_ascii_buffer()
	var values := PackedByteArray()
	for value: Variant in record[1]:
		values.append_array(_fbx_value(value))
	var inside := PackedByteArray()
	var start: int = offset + 13 + name.size() + values.size()
	for child: Array in record[2]:
		inside.append_array(_fbx_record(child, start + inside.size()))
	if not (record[2] as Array).is_empty() or (record[1] as Array).is_empty():
		var nothing := PackedByteArray()
		nothing.resize(13)
		inside.append_array(nothing)
	var out := PackedByteArray()
	out.resize(13)
	out.encode_u32(0, start + inside.size())
	out.encode_u32(4, (record[1] as Array).size())
	out.encode_u32(8, values.size())
	out[12] = name.size()
	out.append_array(name)
	out.append_array(values)
	out.append_array(inside)
	return out


static func _fbx_property(name: String, kind: String, values: Array) -> Array:
	return ["P", [name, kind, "", "A"] + values, []]


static func _fbx_geometry(id: int, name: String, mesh: MeshFile, colours: bool) -> Array:
	var points := PackedFloat64Array()
	var order := PackedInt32Array()
	var normals := PackedFloat64Array()
	var tints := PackedFloat64Array()
	for n: int in mesh.positions.size():
		points.append_array([mesh.positions[n].x, mesh.positions[n].y, mesh.positions[n].z])
		# The last corner of a polygon is written as its index's complement.
		order.append(n if n % 3 < 2 else -n - 1)
		normals.append_array([mesh.normals[n].x, mesh.normals[n].y, mesh.normals[n].z])
		tints.append_array([mesh.colours[n].r, mesh.colours[n].g, mesh.colours[n].b, 1.0])
	var layer: Array = [["Version", [100], []], ["LayerElement", [],
		[["Type", ["LayerElementNormal"], []], ["TypedIndex", [0], []]]]]
	var children: Array = [["Vertices", [points], []], ["PolygonVertexIndex", [order], []],
		["GeometryVersion", [124], []],
		["LayerElementNormal", [0], [["Version", [101], []], ["Name", [""], []],
			["MappingInformationType", ["ByPolygonVertex"], []],
			["ReferenceInformationType", ["Direct"], []], ["Normals", [normals], []]]]]
	if colours:
		children.append(["LayerElementColor", [0], [["Version", [101], []], ["Name", [""], []],
			["MappingInformationType", ["ByPolygonVertex"], []],
			["ReferenceInformationType", ["Direct"], []], ["Colors", [tints], []]]])
		layer.append(["LayerElement", [], [["Type", ["LayerElementColor"], []],
			["TypedIndex", [0], []]]])
	children.append(["Layer", [0], layer])
	return ["Geometry", [{"L": id}, {"S": [name, "Geometry"]}, "Mesh"], children]


## The bunny with its vertex colours on a node moved 20 along x; and a
## cube of 12 triangles in a red material on a node moved 20 the other way.
## Y up, a unit a centimetre, as Maya writes.
static func fbx(bunny: MeshFile) -> PackedByteArray:
	var cube := MeshFile.new()
	BrickifySamples._box(cube, AABB(Vector3(-3, 0, -3), Vector3(6, 6, 6)), Color.WHITE)
	var axes: Array = []
	for pair: Array in [["UpAxis", 1], ["UpAxisSign", 1], ["FrontAxis", 2], ["FrontAxisSign", 1],
			["CoordAxis", 0], ["CoordAxisSign", 1]]:
		axes.append(_fbx_property(pair[0], "int", [pair[1]]))
	axes.append(_fbx_property("UnitScaleFactor", "double", [1.0]))
	var records: Array = [
		["FBXHeaderExtension", [], [["FBXHeaderVersion", [1003], []],
			["FBXVersion", [7400], []], ["Creator", ["Brickworks mesh formats probe (CC0)"], []]]],
		["GlobalSettings", [], [["Version", [1000], []], ["Properties70", [], axes]]],
		["Objects", [], [
			_fbx_geometry(100, "bunny", bunny, true),
			["Model", [{"L": 200}, {"S": ["bunny", "Model"]}, "Mesh"], [["Version", [232], []],
				["Properties70", [], [_fbx_property("Lcl Translation", "Lcl Translation",
					[20.0, 0.0, 0.0])]]]],
			_fbx_geometry(300, "cube", cube, false),
			["Model", [{"L": 400}, {"S": ["cube", "Model"]}, "Mesh"], [["Version", [232], []],
				["Properties70", [], [_fbx_property("Lcl Translation", "Lcl Translation",
					[-20.0, 0.0, 0.0])]]]],
			["Material", [{"L": 500}, {"S": ["red", "Material"]}, ""], [["Version", [102], []],
				["ShadingModel", ["phong"], []], ["Properties70", [], [
					_fbx_property("DiffuseColor", "Color", [RED.r, RED.g, RED.b])]]]]]],
		["Connections", [], [["C", ["OO", {"L": 200}, {"L": 0}], []],
			["C", ["OO", {"L": 100}, {"L": 200}], []], ["C", ["OO", {"L": 400}, {"L": 0}], []],
			["C", ["OO", {"L": 300}, {"L": 400}], []],
			["C", ["OO", {"L": 500}, {"L": 400}], []]]]]
	var out := PackedByteArray()
	out.append_array("Kaydara FBX Binary  ".to_ascii_buffer())
	out.append_array(PackedByteArray([0, 0x1A, 0]))
	out.resize(27)
	out.encode_u32(23, 7400)
	for record: Array in records:
		out.append_array(_fbx_record(record, out.size()))
	var nothing := PackedByteArray()
	nothing.resize(13)
	out.append_array(nothing)
	return out


# -- OBJ and a picture --------------------------------------------------------


## A cube ten across whose every face is the whole picture: each face's
## first triangle falls on the picture's right half, blue, and its second
## on the left, red.
static func spotty_obj() -> PackedByteArray:
	var lines := PackedStringArray(["# a cube with a picture and no .mtl, made by Brickworks' "
		+ "mesh formats probe (CC0)"])
	for n: int in 8:
		lines.append("v %d %d %d" % [10 * (n & 1), 5 * (n & 2), 10 * (n >> 2)])
	lines.append_array(["vt 0 0", "vt 1 0", "vt 1 1", "vt 0 1"])
	for quad: Array in [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2],
			[1, 3, 7, 5]]:
		lines.append("f %d/1 %d/2 %d/3 %d/4" % [quad[0] + 1, quad[1] + 1, quad[2] + 1,
			quad[3] + 1])
	return ("\n".join(lines) + "\n").to_utf8_buffer()


static func spotty_png() -> PackedByteArray:
	var picture := Image.create(2, 1, false, Image.FORMAT_RGB8)
	picture.set_pixel(0, 0, RED)
	picture.set_pixel(1, 0, BLUE)
	return picture.save_png_to_buffer()
