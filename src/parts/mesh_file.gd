## A 3D model file read into triangles: OBJ, STL, glTF (.gltf, .glb), PLY,
## 3MF, MagicaVoxel's VOX, or FBX.
##
## What a sculpt, a scan or a model from any 3D program is brought in as,
## for Brickify to lay in bricks. Everything is kept as triangles with
## three corners each, in the file's own units and axes: a position, a
## normal, a colour, and a place on a texture. Which way is up is the
## reader's question, not the file's — STL and 3MF from a printer and a
## VOX have Z up, glTF has Y.
##
## Read as bytes, never from a path, because in a browser there is no path:
## the file comes through the page's own picker. Files a model names beside
## itself (an OBJ's .mtl and its pictures, a .gltf's .bin) come in
## [param extras], by name.
class_name MeshFile
extends RefCounted

## What it reads, by extension.
const KINDS: PackedStringArray = ["obj", "stl", "gltf", "glb", "ply", "3mf", "vox", "fbx"]
## The same, as a person is told it.
const NAMED := "OBJ, STL, glTF, GLB, PLY, 3MF, VOX or FBX"
## Pictures an OBJ's material or a .gltf may name.
const PICTURES: PackedStringArray = ["png", "jpg", "jpeg", "webp", "tga", "bmp"]
const MAX_BYTES := 96 * 1024 * 1024
## A scan of millions of triangles is not wanted at forty studs, and
## reading one would hold the page for minutes.
const MOST_TRIANGLES := 1500000
## A VOX's voxels, and the box they are laid out in: a quarter of a solid
## 256-voxel cube, and its outside alone is brought in.
const MOST_VOXELS := 1 << 22
const MOST_VOXEL_BOX := 1 << 25
## Faces that meet at more than this are a crease, not a curve: a cube's
## chamfer meets its sides at 45 degrees, a sphere of 24 segments at 15.
const CREASE_DEGREES := 30.0

## Three corners a triangle.
var positions := PackedVector3Array()
## Each corner's normal, smooth across a curve and sharp at a crease.
var normals := PackedVector3Array()
## Each corner's colour, in sRGB: its vertex colour times its material's.
var colours := PackedColorArray()
## Each corner's place on its triangle's texture.
var uvs := PackedVector2Array()
## Each triangle's texture, an index into [member textures], or -1.
var texture_of := PackedInt32Array()
var textures: Array[Image] = []
## Whether the file gave a colour of its own anywhere: a vertex colour, a
## material that is not white, or a texture.
var coloured: bool = false
var name: String = ""
## Which way the file's maker had up, by its kind: "+Y" or "+Z".
var up: String = "+Y"
var error: String = ""


func triangle_count() -> int:
	return positions.size() / 3


func bounds() -> AABB:
	if positions.is_empty():
		return AABB()
	var box := AABB(positions[0], Vector3.ZERO)
	for p: Vector3 in positions:
		box = box.expand(p)
	return box


## The colour at a point of triangle [param t], [param b] its barycentric
## weights: the corners' colours blended, times the texture there.
func colour_at(t: int, b: Vector3) -> Color:
	var c: Color = colours[3 * t] * b.x + colours[3 * t + 1] * b.y + colours[3 * t + 2] * b.z
	var which: int = texture_of[t] if t < texture_of.size() else -1
	if which >= 0 and which < textures.size():
		var image: Image = textures[which]
		var uv: Vector2 = uvs[3 * t] * b.x + uvs[3 * t + 1] * b.y + uvs[3 * t + 2] * b.z
		var w: int = image.get_width()
		var h: int = image.get_height()
		var x: int = posmod(int(floor(uv.x * w)), w)
		var y: int = posmod(int(floor(uv.y * h)), h)
		c *= image.get_pixel(x, y)
	c.a = 1.0
	return c


## Read a model. Never null: a file that could not be read comes back with
## [member error] saying why, in words a person can act on.
static func read(bytes: PackedByteArray, file_name: String,
		extras: Dictionary = {}) -> MeshFile:
	var out := MeshFile.new()
	out.name = file_name.get_file().get_basename()
	var kind: String = file_name.get_extension().to_lower()
	if bytes.is_empty():
		out.error = "could not read %s" % file_name.get_file()
		return out
	if bytes.size() > MAX_BYTES:
		out.error = "%s is too large to bring in" % file_name.get_file()
		return out
	match kind:
		"obj":
			_obj(bytes.get_string_from_utf8(), extras, out)
		"stl":
			out.up = "+Z"
			_stl(bytes, out)
		"gltf", "glb":
			_scene(GLTFDocument.new(), GLTFState.new(), bytes, file_name, extras, out)
		"ply":
			_ply(bytes, out)
		"3mf":
			out.up = "+Z"
			ThreeMF.new(bytes, out).read()
		"vox":
			out.up = "+Z"
			_vox(bytes, out)
		"fbx":
			# By name, since a build without the engine's FBX reader would not
			# load this script at all if it were named outright.
			if not ClassDB.class_exists("FBXDocument"):
				out.error = ("%s is an FBX, which this build cannot read: open it in the "
					+ "desktop app, or save it as glTF or OBJ") % file_name.get_file()
				return out
			_scene(ClassDB.instantiate("FBXDocument"), ClassDB.instantiate("FBXState"), bytes,
				file_name, extras, out)
		_:
			out.error = refusal(file_name)
			return out
	if not out.error.is_empty():
		return out
	if out.triangle_count() == 0:
		out.error = "%s has no surfaces in it" % file_name.get_file()
		return out
	if out.triangle_count() > MOST_TRIANGLES:
		out.error = "%s has %d triangles; at most %d can be brought in" % [
			file_name.get_file(), out.triangle_count(), MOST_TRIANGLES]
		return out
	# Filled in whole where a reader gave none, not a corner at a time: a
	# scan has millions.
	if out.colours.is_empty():
		out.colours.resize(out.positions.size())
		out.colours.fill(Color.WHITE)
	while out.colours.size() < out.positions.size():
		out.colours.append(Color.WHITE)
	out.uvs.resize(out.positions.size())
	if out.texture_of.is_empty():
		out.texture_of.resize(out.triangle_count())
		out.texture_of.fill(-1)
	while out.texture_of.size() < out.triangle_count():
		out.texture_of.append(-1)
	if out.normals.size() != out.positions.size():
		out.normals = smooth_normals(out.positions, CREASE_DEGREES)
	return out


## Why a file of a kind not in [constant KINDS] is not read, in words a
## person can act on.
static func refusal(file_name: String) -> String:
	if file_name.get_extension().to_lower() in ["usdz", "usd", "usdc", "usda"]:
		return ("%s is USD, which nothing here can read: save it from your 3D program as "
			+ "glTF, FBX or OBJ") % file_name.get_file()
	return "%s is not a 3D model this can bring in — %s" % [file_name.get_file(), NAMED]


## The files a model names beside itself, as it names them: an OBJ's
## material libraries and their pictures (from [param extras] once they are
## read), a .gltf's buffers and pictures. For the desktop to read from the
## model's own folder, whose files are [param beside]; a browser is handed
## them by the person. An OBJ that names no material library takes the one
## picture beside it, if there is just one, as [method read] does.
static func companions(bytes: PackedByteArray, file_name: String,
		extras: Dictionary = {}, beside: PackedStringArray = []) -> PackedStringArray:
	var out := PackedStringArray()
	match file_name.get_extension().to_lower():
		"obj":
			for line: String in bytes.get_string_from_utf8().split("\n"):
				var said: String = line.strip_edges()
				if said.begins_with("mtllib "):
					out.append(said.substr(7).strip_edges())
			if out.is_empty():
				var pictures: PackedStringArray = []
				for file: String in beside:
					if file.get_extension().to_lower() in PICTURES:
						pictures.append(file)
				if pictures.size() == 1:
					out.append(pictures[0])
			for key: Variant in extras:
				if str(key).get_extension().to_lower() == "mtl":
					for line: String in _text_of(extras, str(key)).split("\n"):
						var words: PackedStringArray = line.strip_edges().split(" ", false)
						if not words.is_empty() and words[0] == "map_Kd":
							out.append(words[words.size() - 1])
		"gltf":
			var json: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if json is Dictionary:
				for key: String in ["buffers", "images"]:
					for entry: Variant in (json as Dictionary).get(key, []):
						if entry is Dictionary and (entry as Dictionary).has("uri") \
								and not str(entry["uri"]).begins_with("data:"):
							out.append(str(entry["uri"]).uri_decode())
	return out


# -- OBJ ----------------------------------------------------------------------


static func _obj(text: String, extras: Dictionary, out: MeshFile) -> void:
	var v := PackedVector3Array()
	var vc := PackedColorArray()
	var vt := PackedVector2Array()
	var vn := PackedVector3Array()
	var materials: Dictionary = {}   ## name -> [Color, texture index]
	var material: Array = [Color.WHITE, -1]
	var given_normals: bool = true
	## Whether each triangle gives its corners places on a picture.
	var placed := PackedByteArray()
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges().replace("\t", " ")
		if line.is_empty() or line.begins_with("#"):
			continue
		var words: PackedStringArray = line.split(" ", false)
		match words[0]:
			"v":
				if words.size() < 4:
					continue
				v.append(Vector3(words[1].to_float(), words[2].to_float(), words[3].to_float()))
				# Colour after the position, as ZBrush, MeshLab and most
				# scanners write it.
				if words.size() >= 7:
					var c := Color(words[4].to_float(), words[5].to_float(), words[6].to_float())
					if c.r > 1.0 or c.g > 1.0 or c.b > 1.0:
						c = Color8(int(c.r), int(c.g), int(c.b))
					vc.append(c)
					out.coloured = true
				else:
					vc.append(Color.WHITE)
			"vt":
				if words.size() >= 3:
					# OBJ counts v up from the foot of the picture; an Image
					# counts rows down from its head.
					vt.append(Vector2(words[1].to_float(), 1.0 - words[2].to_float()))
			"vn":
				if words.size() >= 4:
					vn.append(Vector3(words[1].to_float(), words[2].to_float(),
						words[3].to_float()))
			"mtllib":
				_mtl(_text_of(extras, line.substr(7).strip_edges()), extras, materials, out)
			"usemtl":
				material = materials.get(line.substr(7).strip_edges(), [Color.WHITE, -1])
			"f":
				var corners: Array = []
				for n: int in range(1, words.size()):
					var refs: PackedStringArray = words[n].split("/")
					var at: int = _index(refs[0], v.size())
					if at < 0:
						corners = []
						break
					var uv: int = _index(refs[1], vt.size()) if refs.size() > 1 else -1
					var normal: int = _index(refs[2], vn.size()) if refs.size() > 2 else -1
					corners.append([at, uv, normal])
				for n: int in range(1, corners.size() - 1):
					var on_picture: bool = true
					for corner: Array in [corners[0], corners[n], corners[n + 1]]:
						out.positions.append(v[int(corner[0])])
						out.colours.append(vc[int(corner[0])] * (material[0] as Color))
						out.uvs.append(vt[int(corner[1])] if int(corner[1]) >= 0 else Vector2.ZERO)
						on_picture = on_picture and int(corner[1]) >= 0
						if int(corner[2]) >= 0:
							out.normals.append(vn[int(corner[2])].normalized())
						else:
							given_normals = false
					out.texture_of.append(int(material[1]))
					placed.append(1 if on_picture else 0)
	if not given_normals:
		out.normals = PackedVector3Array()
	# One picture picked with an OBJ and named by no material is its
	# picture: Spot came as an OBJ and a PNG, no .mtl, and came in grey.
	if out.textures.is_empty():
		var pictures: PackedStringArray = []
		for key: Variant in extras:
			if str(key).get_extension().to_lower() in PICTURES:
				pictures.append(str(key))
		var image: Image = _picture(extras, pictures[0]) if pictures.size() == 1 else null
		if image != null:
			out.textures.append(image)
			for t: int in placed.size():
				if placed[t] == 1:
					out.texture_of[t] = 0
					out.coloured = true


## An OBJ index: counted from one, or back from the end when negative.
static func _index(word: String, count: int) -> int:
	if word.is_empty():
		return -1
	var n: int = word.to_int()
	var at: int = n - 1 if n > 0 else count + n
	return at if at >= 0 and at < count else -1


## A file named beside the model, found by its name whatever the folder or
## the case: a material library says "textures\Bunny.PNG" on Windows.
static func _named(extras: Dictionary, wanted: String) -> String:
	var short: String = wanted.replace("\\", "/").get_file().to_lower()
	for key: Variant in extras:
		if str(key).replace("\\", "/").get_file().to_lower() == short:
			return str(key)
	return ""


static func _text_of(extras: Dictionary, wanted: String) -> String:
	var key: String = _named(extras, wanted)
	if key.is_empty():
		return ""
	var raw: Variant = extras[key]
	if raw is PackedByteArray:
		return (raw as PackedByteArray).get_string_from_utf8()
	return str(raw)


static func _mtl(text: String, extras: Dictionary, materials: Dictionary,
		out: MeshFile) -> void:
	var current: String = ""
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges().replace("\t", " ")
		var words: PackedStringArray = line.split(" ", false)
		if words.is_empty():
			continue
		match words[0]:
			"newmtl":
				current = line.substr(7).strip_edges()
				materials[current] = [Color.WHITE, -1]
			"Kd":
				if words.size() >= 4 and materials.has(current):
					var c := Color(words[1].to_float(), words[2].to_float(), words[3].to_float())
					(materials[current] as Array)[0] = c
					if not c.is_equal_approx(Color.WHITE):
						out.coloured = true
			"map_Kd":
				if materials.has(current):
					# Options come first; the file is the last word.
					var image: Image = _picture(extras, words[words.size() - 1])
					if image != null:
						out.textures.append(image)
						(materials[current] as Array)[1] = out.textures.size() - 1
						out.coloured = true


static func _picture(extras: Dictionary, wanted: String) -> Image:
	var key: String = _named(extras, wanted)
	if key.is_empty() or not extras[key] is PackedByteArray:
		return null
	var bytes: PackedByteArray = extras[key]
	var image := Image.new()
	var err: int = ERR_FILE_UNRECOGNIZED
	match key.get_extension().to_lower():
		"png":
			err = image.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			err = image.load_jpg_from_buffer(bytes)
		"webp":
			err = image.load_webp_from_buffer(bytes)
		"tga":
			err = image.load_tga_from_buffer(bytes)
		"bmp":
			err = image.load_bmp_from_buffer(bytes)
	if err != OK or image.is_empty():
		return null
	return _readable(image)


## A picture that can be read a pixel at a time.
static func _readable(image: Image) -> Image:
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		if image.decompress() != OK:
			return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


# -- STL ----------------------------------------------------------------------


static func _stl(bytes: PackedByteArray, out: MeshFile) -> void:
	# Binary when its own count says so: plenty of binary files begin with
	# the word "solid" too.
	if bytes.size() >= 84:
		var count: int = bytes.decode_u32(80)
		if 84 + 50 * count == bytes.size():
			for t: int in count:
				var at: int = 84 + 50 * t + 12
				for corner: int in 3:
					var p: int = at + 12 * corner
					out.positions.append(Vector3(bytes.decode_float(p),
						bytes.decode_float(p + 4), bytes.decode_float(p + 8)))
			return
	var text: String = bytes.get_string_from_utf8()
	if not text.strip_edges().begins_with("solid"):
		out.error = "that STL is neither text nor binary STL"
		return
	for raw: String in text.split("\n"):
		var words: PackedStringArray = raw.strip_edges().replace("\t", " ").split(" ", false)
		if words.size() >= 4 and words[0] == "vertex":
			out.positions.append(Vector3(words[1].to_float(), words[2].to_float(),
				words[3].to_float()))
	out.positions.resize(out.positions.size() / 3 * 3)


# -- PLY ----------------------------------------------------------------------


## A PLY property's kinds, by the names a header gives them, as [method
## PlyReader.value] reads them: 0 to 7 are int8, uint8, int16, uint16,
## int32, uint32, float32 and float64.
const PLY_KINDS: Dictionary = {
	"char": 0, "int8": 0, "uchar": 1, "uint8": 1, "short": 2, "int16": 2,
	"ushort": 3, "uint16": 3, "int": 4, "int32": 4, "uint": 5, "uint32": 5,
	"float": 6, "float32": 6, "double": 7, "float64": 7}
## What a vertex's or a face's properties are, by the names scanners and
## MeshLab give them: a position, a normal, a colour.
const PLY_ROLES: Dictionary = {"x": 0, "y": 1, "z": 2, "nx": 3, "ny": 4, "nz": 5,
	"red": 6, "green": 7, "blue": 8, "r": 6, "g": 7, "b": 8,
	"diffuse_red": 6, "diffuse_green": 7, "diffuse_blue": 8}


## A PLY's elements read a value at a time, from text or from binary of
## either byte order, and never past its end: [method has] is asked first.
class PlyReader extends RefCounted:
	const SIZES: PackedInt32Array = [1, 1, 2, 2, 4, 4, 4, 8]
	## Text: every number after the header, in order.
	var numbers := PackedFloat64Array()
	var at: int = 0
	## Binary.
	var stream: StreamPeerBuffer = null
	var size: int = 0

	## Whether [param bytes] more are there in binary, or [param values]
	## more in text.
	func has(bytes: int, values: int) -> bool:
		if stream == null:
			return at + values <= numbers.size()
		return stream.get_position() + bytes <= size

	func value(kind: int) -> float:
		if stream == null:
			at += 1
			return numbers[at - 1]
		match kind:
			0:
				return stream.get_8()
			1:
				return stream.get_u8()
			2:
				return stream.get_16()
			3:
				return stream.get_u16()
			4:
				return stream.get_32()
			5:
				return stream.get_u32()
			6:
				return stream.get_float()
		return stream.get_double()

	## [param count] values of [param kind] stepped over, or false when the
	## file ends first.
	func skip(count: int, kind: int) -> bool:
		if not has(count * SIZES[kind], count):
			return false
		if stream == null:
			at += count
		else:
			stream.seek(stream.get_position() + count * SIZES[kind])
		return true


## Stanford's PLY, which scans come as: a header saying which elements the
## file holds, how many of each and their properties in order, then the
## elements in text, or in binary of either byte order. A vertex's position,
## normal and colour are read, and a face's corners, fanned into triangles,
## and its colour; anything else is stepped over by its size, so a face's
## "intensity" before its corners (the Armadillo's) is no matter.
static func _ply(bytes: PackedByteArray, out: MeshFile) -> void:
	var head: String = bytes.slice(0, mini(bytes.size(), 65536)).get_string_from_ascii()
	var stop: int = head.find("end_header")
	if not head.begins_with("ply") or stop < 0:
		out.error = "that PLY has no header saying what is in it"
		return
	var at: int = stop + 10
	if at < bytes.size() and bytes[at] == 13:
		at += 1
	if at < bytes.size() and bytes[at] == 10:
		at += 1
	var format: String = ""
	## Each [name, count, its properties], a property [name, kind, and the
	## kind of its count when it is a list, or -1].
	var elements: Array = []
	for raw: String in head.substr(0, stop).split("\n"):
		var line: String = raw.replace("\t", " ").strip_edges()
		var words: PackedStringArray = line.split(" ", false)
		if words.is_empty():
			continue
		match words[0]:
			"format":
				format = words[1] if words.size() > 1 else ""
			"element":
				if words.size() < 3 or not words[2].is_valid_int() or words[2].to_int() < 0:
					out.error = "that PLY's header says \"%s\", which is not an element and its count" \
						% line.left(60)
					return
				elements.append([words[1], words[2].to_int(), []])
			"property":
				var list: bool = words.size() >= 5 and words[1] == "list"
				var kind: String = words[3] if list else (words[1] if words.size() >= 3 else "")
				if elements.is_empty() or not PLY_KINDS.has(kind) \
						or (list and not PLY_KINDS.has(words[2])):
					out.error = "that PLY's header says \"%s\", which is not a property it can read" \
						% line.left(60)
					return
				(elements[-1][2] as Array).append([words[-1], int(PLY_KINDS[kind]),
					int(PLY_KINDS[words[2]]) if list else -1])
	var reader := PlyReader.new()
	match format:
		"ascii":
			reader.numbers = bytes.slice(at).get_string_from_ascii().replace("\r", " ") \
				.replace("\n", " ").replace("\t", " ").split_floats(" ", false)
		"binary_little_endian", "binary_big_endian":
			reader.stream = StreamPeerBuffer.new()
			reader.stream.data_array = bytes
			reader.stream.big_endian = format == "binary_big_endian"
			reader.stream.seek(at)
			reader.size = bytes.size()
		_:
			out.error = "that PLY is written as \"%s\", which is neither text nor binary PLY" \
				% format.left(40)
			return
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	## Three a triangle, into points, and each triangle's own colour.
	var corners := PackedInt32Array()
	var face_tints := PackedColorArray()
	for element: Array in elements:
		var what: String = element[0]
		var count: int = element[1]
		var properties: Array = element[2]
		var plural: String = "vertices" if what == "vertex" else what + "s"
		# What one of them takes at least, a list taking only its count.
		var least: int = 0
		var roles := PackedInt32Array()
		var scale := PackedFloat32Array()
		var indices: int = -1
		for k: int in properties.size():
			var property: Array = properties[k]
			var list: bool = int(property[2]) >= 0
			least += PlyReader.SIZES[int(property[2]) if list else int(property[1])]
			var role: int = -1 if list else int(PLY_ROLES.get(property[0], -1))
			roles.append(role)
			# A colour of whole numbers is read out of the most they hold.
			scale.append(1.0 / [127.0, 255.0, 32767.0, 65535.0, 2147483647.0, 4294967295.0,
				1.0, 1.0][int(property[1])] if role >= 6 else 1.0)
			if list and (indices < 0 or property[0] in ["vertex_indices", "vertex_index"]):
				indices = k
		if what == "vertex" and count > 3 * MOST_TRIANGLES:
			out.error = "that PLY has %d vertices; at most %d can be brought in" % [count,
				3 * MOST_TRIANGLES]
			return
		if what == "face" and count > MOST_TRIANGLES:
			out.error = "that PLY has %d faces; at most %d triangles can be brought in" % [count,
				MOST_TRIANGLES]
			return
		if not reader.has(count * least, count * properties.size()):
			out.error = "that PLY says it has %d %s, and is cut short before them" % [count, plural]
			return
		var slot := PackedFloat32Array([0, 0, 0, 0, 0, 0, 1, 1, 1])
		var normal: bool = roles.has(3) and roles.has(4) and roles.has(5)
		var tint: bool = roles.has(6) and roles.has(7) and roles.has(8)
		for _n: int in count:
			if not reader.has(least, properties.size()):
				out.error = "that PLY is cut short in its %s" % plural
				return
			var started: int = corners.size()
			for k: int in properties.size():
				var property: Array = properties[k]
				if int(property[2]) < 0:
					var value: float = reader.value(int(property[1]))
					if roles[k] >= 0:
						slot[roles[k]] = value * scale[k]
					continue
				var many: int = int(reader.value(int(property[2])))
				if what != "face" or k != indices:
					if many < 0 or not reader.skip(many, int(property[1])):
						out.error = "that PLY is cut short in its %s" % plural
						return
					continue
				# A face of any number of corners, fanned from its first.
				if many < 0 or not reader.has(many * PlyReader.SIZES[int(property[1])], many):
					out.error = "that PLY is cut short in its faces"
					return
				var first: int = 0
				var last: int = 0
				for j: int in many:
					var index: int = int(reader.value(int(property[1])))
					if j == 0:
						first = index
					elif j >= 2:
						corners.append(first)
						corners.append(last)
						corners.append(index)
					last = index
			if what == "vertex":
				points.append(Vector3(slot[0], slot[1], slot[2]))
				if normal:
					normals.append(Vector3(slot[3], slot[4], slot[5]))
				if tint:
					tints.append(Color(slot[6], slot[7], slot[8]))
			elif what == "face":
				if corners.size() > 3 * MOST_TRIANGLES:
					out.error = "that PLY has more than %d triangles, more than can be brought in" \
						% MOST_TRIANGLES
					return
				if tint:
					for _t: int in (corners.size() - started) / 3:
						face_tints.append(Color(slot[6], slot[7], slot[8]))
	if corners.is_empty() and not points.is_empty():
		out.error = ("that PLY is %d points with no surfaces between them: a scan is made a "
			+ "surface first (MeshLab's Screened Poisson does it)") % points.size()
		return
	var by_face: bool = face_tints.size() * 3 == corners.size() and not face_tints.is_empty()
	var by_vertex: bool = tints.size() == points.size() and not tints.is_empty()
	var with_normals: bool = normals.size() == points.size() and not normals.is_empty()
	for n: int in corners.size():
		var index: int = corners[n]
		if index < 0 or index >= points.size():
			out.error = "a face of that PLY names vertex %d, and it has %d" % [index, points.size()]
			out.positions = PackedVector3Array()
			return
		out.positions.append(points[index])
		if by_face:
			out.colours.append(face_tints[n / 3])
		elif by_vertex:
			out.colours.append(tints[index])
		if with_normals:
			var along: Vector3 = normals[index].normalized()
			if along == Vector3.ZERO:
				with_normals = false
				out.normals = PackedVector3Array()
			else:
				out.normals.append(along)
	out.coloured = by_face or by_vertex


# -- 3MF ----------------------------------------------------------------------


## A 3MF, what printing sites give: a zip of XML. Its root model (named by
## _rels/.rels) lists objects, each a mesh or components placing other
## objects, maybe in other model files of the zip (Bambu Studio's are);
## its build lays some of them, each placed. Colours come from what a
## triangle or its object names: a base material's display colour, a colour
## group's, or a place on a picture. Read from bytes, as the zip is in a
## browser: StudioIo's reader, every member unpacked to no more than its
## stated size, and all of them together to no more than MAX_BYTES.
class ThreeMF extends RefCounted:
	## The kinds of object a printer lays that are not the model: what a
	## slicer adds to hold it up.
	const NOT_THE_MODEL: PackedStringArray = ["support"]
	## How deep components may place components, and no deeper: one that
	## places itself would never end.
	const DEEPEST := 32

	var bytes: PackedByteArray
	var out: MeshFile
	var members: Dictionary = {}
	## What may still be unpacked, in bytes.
	var budget: int = MAX_BYTES
	## Each model file read, by its path in the zip.
	var models: Dictionary = {}
	## A picture's index in [member MeshFile.textures], by its path.
	var pictures: Dictionary = {}

	func _init(file: PackedByteArray, into: MeshFile) -> void:
		bytes = file
		out = into

	func read() -> void:
		members = StudioIo._entries(bytes)
		if members.has("error"):
			out.error = "that 3MF is not the zip a 3MF is: it is damaged, or not a 3MF"
			return
		var root: String = "3d/3dmodel.model"
		var rels: PackedByteArray = unpacked("_rels/.rels")
		if not out.error.is_empty():
			return
		var parser := XMLParser.new()
		if not rels.is_empty() and parser.open_buffer(rels) == OK:
			while parser.read() == OK:
				if parser.get_node_type() == XMLParser.NODE_ELEMENT \
						and parser.get_node_name().ends_with("Relationship") \
						and parser.get_named_attribute_value_safe("Type").ends_with("/3dmodel"):
					root = _path(parser.get_named_attribute_value_safe("Target"))
					break
		var top: ThreeMFModel = model(root)
		if top == null:
			if out.error.is_empty():
				out.error = "that 3MF has no 3D model in it"
			return
		var total: int = 0
		for item: Array in top.items:
			var each: int = triangles(item[0], int(item[1]), 0)
			if not out.error.is_empty():
				return
			total += each
			if total > MOST_TRIANGLES:
				out.error = "that 3MF lays more than %d triangles, more than can be brought in" \
					% MOST_TRIANGLES
				return
		for item: Array in top.items:
			lay(item[0], int(item[1]), item[2], 0)

	## A member's bytes, or none with [member MeshFile.error] saying why
	## when it cannot be unpacked; none and no error when there is no such
	## member.
	func unpacked(path: String) -> PackedByteArray:
		var entry: Dictionary = members.get(_path(path), {})
		if entry.is_empty():
			return PackedByteArray()
		if bool(entry["encrypted"]) or entry.has("aes"):
			out.error = "that 3MF is locked with a password"
			return PackedByteArray()
		if int(entry["size"]) > budget:
			out.error = "that 3MF unpacks to more than %s, more than can be brought in" \
				% String.humanize_size(MAX_BYTES)
			return PackedByteArray()
		budget -= int(entry["size"])
		var data: PackedByteArray = StudioIo._unpack(bytes, entry)
		if data.size() != int(entry["size"]):
			out.error = "that 3MF is damaged: %s in it does not unpack" % path.get_file()
			return PackedByteArray()
		return data

	## The model file at [param path], read once, or null.
	func model(path: String) -> ThreeMFModel:
		if models.has(path):
			return models[path]
		var xml: PackedByteArray = unpacked(path)
		var read: ThreeMFModel = null
		if not xml.is_empty():
			read = ThreeMFModel.parse(xml, path)
			if not read.error.is_empty():
				out.error = "that 3MF's %s %s" % [path.get_file(), read.error]
				read = null
		models[path] = read
		return read

	## All the triangles object [param id] of [param path] lays, its
	## components' too, counted once each: a few objects placing each other
	## by the hundred are counted without being laid.
	func triangles(path: String, id: int, depth: int) -> int:
		var file: ThreeMFModel = model(path)
		if file == null:
			if out.error.is_empty():
				out.error = "that 3MF names %s, which is not in it" % path.get_file()
			return 0
		var object: ThreeMFObject = file.objects.get(id)
		if object == null:
			out.error = "that 3MF lays object %d, which it does not have" % id
			return 0
		if depth > DEEPEST:
			out.error = "that 3MF's objects place each other in a loop"
			return 0
		if object.triangles >= 0:
			return object.triangles
		var sum: int = object.corners.size() / 3
		for part: Array in object.parts:
			sum += triangles(part[0] if not str(part[0]).is_empty() else path, int(part[1]),
				depth + 1)
			if not out.error.is_empty() or sum > MOST_TRIANGLES:
				return sum
		object.triangles = sum
		return sum

	func lay(path: String, id: int, at: Transform3D, depth: int) -> void:
		var file: ThreeMFModel = models[path]
		var object: ThreeMFObject = file.objects[id]
		if object.kind in NOT_THE_MODEL:
			return
		# Placed in a mirror, its triangles turn the other way round.
		var order: Array = [0, 2, 1] if at.basis.determinant() < 0.0 else [0, 1, 2]
		for t: int in object.corners.size() / 3:
			var group: ThreeMFSwatches = file.groups.get(object.props[4 * t])
			if object.props[4 * t] < 0:
				group = file.groups.get(object.pid)
			var first: int = object.props[4 * t + 1] if object.props[4 * t + 1] >= 0 				else object.pindex
			var picture: int = -1
			if group != null and group.texture >= 0:
				picture = texture(file, group.texture)
			for corner: int in order:
				out.positions.append(at * object.points[object.corners[3 * t + corner]])
				var which: int = object.props[4 * t + 1 + corner] if corner > 0 \
					and object.props[4 * t + 1 + corner] >= 0 else first
				var colour := Color.WHITE
				var uv := Vector2.ZERO
				if group != null and which >= 0 and which < group.colours.size():
					colour = group.colours[which]
					out.coloured = true
				if group != null and which >= 0 and which < group.uvs.size():
					uv = group.uvs[which]
				out.colours.append(colour)
				out.uvs.append(uv)
			out.texture_of.append(picture)
		for part: Array in object.parts:
			var where: String = part[0] if not str(part[0]).is_empty() else path
			lay(where, int(part[1]), at * (part[2] as Transform3D), depth + 1)

	## Texture [param id] of [param file], unpacked and read once, as an
	## index in [member MeshFile.textures], or -1.
	func texture(file: ThreeMFModel, id: int) -> int:
		var path: String = file.textures.get(id, "")
		if path.is_empty():
			return -1
		if not pictures.has(path):
			pictures[path] = -1
			var data: PackedByteArray = unpacked(path)
			var image: Image = MeshFile._picture({path: data}, path) if not data.is_empty() else null
			if image != null:
				out.textures.append(image)
				pictures[path] = out.textures.size() - 1
				out.coloured = true
			# A picture that will not unpack leaves its triangles white, and
			# is no reason to refuse the model.
			out.error = ""
		return int(pictures[path])

	## A path in the zip as StudioIo keys them.
	static func _path(path: String) -> String:
		return path.replace("\\", "/").trim_prefix("/").to_lower()


## One model file of a 3MF: its objects, colours and pictures by id, and
## what its build lays.
class ThreeMFModel extends RefCounted:
	var objects: Dictionary = {}    ## id -> ThreeMFObject
	var groups: Dictionary = {}     ## id -> ThreeMFSwatches
	var textures: Dictionary = {}   ## id -> its picture's path in the zip
	## Each [path or "", object id, Transform3D].
	var items: Array = []
	var error: String = ""

	static func parse(xml: PackedByteArray, path: String) -> ThreeMFModel:
		var read := ThreeMFModel.new()
		var parser := XMLParser.new()
		if parser.open_buffer(xml) != OK:
			read.error = "is not XML"
			return read
		var object: ThreeMFObject = null
		var group: ThreeMFSwatches = null
		while parser.read() == OK:
			if parser.get_node_type() != XMLParser.NODE_ELEMENT:
				continue
			var tag: String = parser.get_node_name()
			tag = tag.substr(tag.rfind(":") + 1)
			match tag:
				"object":
					object = ThreeMFObject.new()
					object.kind = parser.get_named_attribute_value_safe("type")
					object.pid = _number(parser, "pid", -1)
					object.pindex = _number(parser, "pindex", 0)
					read.objects[_number(parser, "id", -1)] = object
				"vertex":
					if object != null:
						object.points.append(Vector3(
							parser.get_named_attribute_value_safe("x").to_float(),
							parser.get_named_attribute_value_safe("y").to_float(),
							parser.get_named_attribute_value_safe("z").to_float()))
				"triangle":
					if object != null:
						for corner: String in ["v1", "v2", "v3"]:
							var at: int = _number(parser, corner, -1)
							if at < 0 or at >= object.points.size():
								read.error = "has a triangle naming a corner it does not have"
								return read
							object.corners.append(at)
						for key: String in ["pid", "p1", "p2", "p3"]:
							object.props.append(_number(parser, key, -1))
				"component":
					if object != null:
						object.parts.append([_linked(parser), _number(parser, "objectid", -1),
							_placed(parser)])
				"basematerials", "colorgroup", "texture2dgroup":
					group = ThreeMFSwatches.new()
					group.texture = _number(parser, "texid", -1)
					read.groups[_number(parser, "id", -1)] = group
				"base", "color":
					if group != null:
						var colour := Color.from_string(parser.get_named_attribute_value_safe(
							"displaycolor" if tag == "base" else "color"), Color.WHITE)
						colour.a = 1.0
						group.colours.append(colour)
				"tex2coord":
					if group != null:
						# Counted up from the foot of the picture, as OBJ counts.
						group.uvs.append(Vector2(
							parser.get_named_attribute_value_safe("u").to_float(),
							1.0 - parser.get_named_attribute_value_safe("v").to_float()))
				"texture2d":
					read.textures[_number(parser, "id", -1)] = ThreeMF._path(
						parser.get_named_attribute_value_safe("path"))
				"item":
					read.items.append([_linked(parser), _number(parser, "objectid", -1),
						_placed(parser)])
		for item: Array in read.items:
			if str(item[0]).is_empty():
				item[0] = path
		for one: Variant in read.objects:
			for part: Array in (read.objects[one] as ThreeMFObject).parts:
				if str(part[0]).is_empty():
					part[0] = path
		return read

	static func _number(parser: XMLParser, key: String, otherwise: int) -> int:
		var said: String = parser.get_named_attribute_value_safe(key)
		return said.to_int() if said.is_valid_int() else otherwise

	## The other model file a component or item names (3MF's production
	## extension, whatever prefix it is given), or "" for this one.
	static func _linked(parser: XMLParser) -> String:
		for n: int in parser.get_attribute_count():
			if parser.get_attribute_name(n).ends_with(":path"):
				return ThreeMF._path(parser.get_attribute_value(n))
		return ""

	## A 3MF transform, twelve numbers a row at a time: x' = x m00 + y m10
	## + z m20 + m30, so its rows are the basis's columns.
	static func _placed(parser: XMLParser) -> Transform3D:
		var m: PackedFloat64Array = parser.get_named_attribute_value_safe("transform") \
			.split_floats(" ", false)
		if m.size() != 12:
			return Transform3D.IDENTITY
		return Transform3D(Basis(Vector3(m[0], m[1], m[2]), Vector3(m[3], m[4], m[5]),
			Vector3(m[6], m[7], m[8])), Vector3(m[9], m[10], m[11]))


## A 3MF object: its own mesh, and the objects it places.
class ThreeMFObject extends RefCounted:
	var kind: String = ""
	var pid: int = -1
	var pindex: int = 0
	var points := PackedVector3Array()
	## Three a triangle, into points.
	var corners := PackedInt32Array()
	## Four a triangle: the colours it names (pid, p1, p2, p3), -1 for none.
	var props := PackedInt32Array()
	## Each [path, object id, Transform3D].
	var parts: Array = []
	## All it lays, once counted.
	var triangles: int = -1


## A 3MF's colours or places on a picture, by index: a base material's,
## a colour group's or a texture group's.
class ThreeMFSwatches extends RefCounted:
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	## The picture a texture group's places are on.
	var texture: int = -1


# -- VOX ----------------------------------------------------------------------


## MagicaVoxel's .vox: chunks inside a MAIN chunk. Each model is a SIZE
## and its voxels (XYZI: a position and a palette index a voxel); RGBA is
## the palette, or MagicaVoxel's own when there is none; and since 0.99 a
## scene of transforms (nTRN), groups (nGRP) and shapes (nSHP) places the
## models, each turned and moved about its own middle, as MagicaVoxel shows
## them, at their first frame. A hidden node or layer is left out. What comes in is the outside
## of the voxels, each face nothing covers two triangles in its voxel's
## colour, a voxel a unit cube, Z up: so Brickify reads it as any mesh, and
## a voxel is a stud when its size is the model's longest side in voxels.
static func _vox(bytes: PackedByteArray, out: MeshFile) -> void:
	if bytes.size() < 20 or bytes.slice(0, 4).get_string_from_ascii() != "VOX " \
			or bytes.slice(8, 12).get_string_from_ascii() != "MAIN":
		out.error = "that is not a MagicaVoxel .vox file"
		return
	var sizes: Array[Vector3i] = []
	var voxels: Array[PackedByteArray] = []
	var palette: PackedColorArray = _vox_palette()
	var nodes: Dictionary = {}    ## id -> [kind, attributes, what it holds]
	var hidden_layers: Dictionary = {}
	var at: int = 20 + bytes.decode_u32(12)
	while at + 12 <= bytes.size():
		var id: String = bytes.slice(at, at + 4).get_string_from_ascii()
		var size: int = bytes.decode_u32(at + 4)
		var body: int = at + 12
		if body + size > bytes.size():
			out.error = "that .vox is cut short"
			return
		var chunk: PackedByteArray = bytes.slice(body, body + size)
		match id:
			"SIZE":
				if size < 12:
					out.error = "that .vox is damaged: a model's size is cut short"
					return
				var model := Vector3i(chunk.decode_s32(0), chunk.decode_s32(4), chunk.decode_s32(8))
				if model.x < 1 or model.y < 1 or model.z < 1 or model.x > 2048 \
						or model.y > 2048 or model.z > 2048:
					out.error = "that .vox has a model %d × %d × %d voxels, which is not a size" % [
						model.x, model.y, model.z]
					return
				sizes.append(model)
			"XYZI":
				var count: int = chunk.decode_u32(0) if size >= 4 else -1
				if count < 0 or 4 + 4 * count > size:
					out.error = "that .vox is cut short in its voxels"
					return
				voxels.append(chunk.slice(4, 4 + 4 * count))
			"RGBA":
				# Its colours 0 to 254 are palette indices 1 to 255.
				for n: int in mini(255, size / 4):
					palette[n + 1] = Color8(chunk[4 * n], chunk[4 * n + 1], chunk[4 * n + 2])
			"nTRN", "nGRP", "nSHP", "LAYR":
				var node: Array = _vox_node(id, chunk)
				if node.is_empty():
					out.error = "that .vox is damaged in its scene (%s)" % id
					return
				if id == "LAYR":
					if str((node[1] as Dictionary).get("_hidden", "0")) == "1":
						hidden_layers[int(node[0])] = true
				else:
					nodes[int(node[0])] = node.slice(1)
		# A chunk's children follow its content; MAIN's are all of them.
		at = body + size + bytes.decode_u32(at + 8)
	if sizes.size() != voxels.size() or sizes.is_empty():
		out.error = "that .vox has no models in it"
		return
	# Each model as the scene places it, turned about its middle. A file
	# with no scene is from before MagicaVoxel had one, when more models
	# than one were an animation's frames: the first is the model.
	var placed: Array = []    ## [model, Transform3D, whether about its middle]
	if nodes.has(0) and str(nodes[0][0]) == "nTRN":
		var why: String = _vox_scene(nodes, hidden_layers, 0, Transform3D.IDENTITY, placed, 0,
			sizes.size())
		if not why.is_empty():
			out.error = "that .vox %s" % why
			return
	else:
		placed.append([0, Transform3D.IDENTITY, false])
	# The box every voxel is in, to lay them out in.
	var low := Vector3i.MAX
	var high := Vector3i.MIN
	var total: int = 0
	for one: Array in placed:
		var model: int = one[0]
		total += voxels[model].size() / 4
		var half: Vector3i = sizes[model] / 2 if bool(one[2]) else Vector3i.ZERO
		for corner: int in 8:
			var p := Vector3i(sizes[model].x - 1 if corner & 1 else 0,
				sizes[model].y - 1 if corner & 2 else 0, sizes[model].z - 1 if corner & 4 else 0)
			var cell := Vector3i(((one[1] as Transform3D) * Vector3(p - half)).round())
			low = low.min(cell)
			high = high.max(cell)
	if total > MOST_VOXELS:
		out.error = "that .vox has %d voxels; at most %d can be brought in" % [total, MOST_VOXELS]
		return
	if placed.is_empty() or total == 0:
		out.error = "that .vox has no voxels showing"
		return
	var box: Vector3i = high - low + Vector3i.ONE
	if box.x * box.y * box.z > MOST_VOXEL_BOX:
		out.error = "that .vox spreads over %d × %d × %d voxels; at most %d can be brought in" % [
			box.x, box.y, box.z, MOST_VOXEL_BOX]
		return
	var grid := PackedByteArray()
	grid.resize(box.x * box.y * box.z)
	var filled := PackedInt32Array()
	for one: Array in placed:
		var model: int = one[0]
		var turn: Transform3D = one[1]
		var half: Vector3i = sizes[model] / 2 if bool(one[2]) else Vector3i.ZERO
		var data: PackedByteArray = voxels[model]
		for n: int in data.size() / 4:
			var p := Vector3i(data[4 * n], data[4 * n + 1], data[4 * n + 2])
			if data[4 * n + 3] == 0 or p.x >= sizes[model].x or p.y >= sizes[model].y \
					or p.z >= sizes[model].z:
				continue
			var cell: Vector3i = Vector3i((turn * Vector3(p - half)).round()) - low
			var index: int = cell.x + box.x * (cell.y + box.y * cell.z)
			if grid[index] == 0:
				filled.append(index)
			grid[index] = data[4 * n + 3]
	# Each face no voxel covers, counted before any is made.
	var steps: PackedInt32Array = [1, -1, box.x, -box.x, box.x * box.y, -box.x * box.y]
	var faces: int = 0
	for index: int in filled:
		var cell := Vector3i(index % box.x, (index / box.x) % box.y, index / (box.x * box.y))
		for side: int in 6:
			if _vox_open(grid, box, cell, side, index + steps[side]):
				faces += 1
	if 2 * faces > MOST_TRIANGLES:
		out.error = "that .vox shows %d faces of voxels; at most %d triangles can be brought in" \
			% [faces, MOST_TRIANGLES]
		return
	for index: int in filled:
		var cell := Vector3i(index % box.x, (index / box.x) % box.y, index / (box.x * box.y))
		var colour: Color = palette[grid[index]]
		for side: int in 6:
			if not _vox_open(grid, box, cell, side, index + steps[side]):
				continue
			# Its four corners round the face, anticlockwise from outside.
			var axis: int = side / 2
			var u: int = (axis + 1) % 3
			var v: int = (axis + 2) % 3
			var square: Array[Vector3] = []
			for corner: Vector2i in ([Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
					if side % 2 == 0 else [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]):
				var p := Vector3(cell + low)
				p[axis] += 1.0 if side % 2 == 0 else 0.0
				p[u] += corner.x
				p[v] += corner.y
				square.append(p)
			var normal := Vector3.ZERO
			normal[axis] = 1.0 if side % 2 == 0 else -1.0
			for k: int in [0, 1, 2, 0, 2, 3]:
				out.positions.append(square[k])
				out.normals.append(normal)
				out.colours.append(colour)
			out.texture_of.append(-1)
			out.texture_of.append(-1)
	out.coloured = true


## Whether side [param side] of the voxel at [param cell] faces out: off the
## edge of the box, or onto an empty cell.
static func _vox_open(grid: PackedByteArray, box: Vector3i, cell: Vector3i, side: int,
		next: int) -> bool:
	var axis: int = side / 2
	var to: int = cell[axis] + (1 if side % 2 == 0 else -1)
	return to < 0 or to >= box[axis] or grid[next] == 0


## A scene chunk read: [node id, its attributes, then nTRN's child, layer
## and first frame's attributes; nGRP's children; nSHP's model], or [] when
## it is cut short. LAYR is [layer id, its attributes].
static func _vox_node(id: String, chunk: PackedByteArray) -> Array:
	if chunk.size() < 4:
		return []
	var at: Array = [4]
	var attributes: Dictionary = _vox_dict(chunk, at)
	if attributes.has("error"):
		return []
	var node: Array = [chunk.decode_u32(0), id, attributes]
	if id == "LAYR":
		return [chunk.decode_u32(0), attributes]
	var a: int = int(at[0])
	match id:
		"nTRN":
			if a + 16 > chunk.size():
				return []
			var child: int = chunk.decode_u32(a)
			var layer: int = chunk.decode_s32(a + 8)
			var frames: int = chunk.decode_u32(a + 12)
			at[0] = a + 16
			var frame: Dictionary = _vox_dict(chunk, at) if frames > 0 else {}
			if frame.has("error"):
				return []
			node.append_array([child, layer, frame])
		"nGRP":
			if a + 4 > chunk.size():
				return []
			var count: int = chunk.decode_u32(a)
			if a + 4 + 4 * count > chunk.size():
				return []
			var children: Array = []
			for n: int in count:
				children.append(chunk.decode_u32(a + 4 + 4 * n))
			node.append(children)
		"nSHP":
			if a + 8 > chunk.size() or chunk.decode_u32(a) < 1:
				return []
			node.append(chunk.decode_u32(a + 4))
	return node


## A .vox dictionary at at[0], which is moved past it: {key: value}, or
## {"error"} when it is cut short.
static func _vox_dict(chunk: PackedByteArray, at: Array) -> Dictionary:
	var a: int = int(at[0])
	if a + 4 > chunk.size():
		return {"error": true}
	var count: int = chunk.decode_u32(a)
	a += 4
	var out: Dictionary = {}
	for _n: int in count:
		var pair: PackedStringArray = []
		for _word: int in 2:
			if a + 4 > chunk.size():
				return {"error": true}
			var length: int = chunk.decode_u32(a)
			if a + 4 + length > chunk.size():
				return {"error": true}
			pair.append(chunk.slice(a + 4, a + 4 + length).get_string_from_utf8())
			a += 4 + length
		out[pair[0]] = pair[1]
	at[0] = a
	return out


## The scene under node [param id], each shape's model with where it is put
## added to [param placed]: [model, Transform3D, true]. Why not, or "".
static func _vox_scene(nodes: Dictionary, hidden_layers: Dictionary, id: int,
		above: Transform3D, placed: Array, depth: int, models: int) -> String:
	if depth > 64 or not nodes.has(id):
		return "is damaged in its scene: a node is missing, or they hold each other"
	var node: Array = nodes[id]
	var attributes: Dictionary = node[1]
	if str(attributes.get("_hidden", "0")) == "1":
		return ""
	match str(node[0]):
		"nTRN":
			if hidden_layers.has(int(node[3])):
				return ""
			var frame: Dictionary = node[4]
			var move := Vector3.ZERO
			var moved: PackedFloat64Array = str(frame.get("_t", "")).split_floats(" ", false)
			if moved.size() == 3:
				move = Vector3(moved[0], moved[1], moved[2])
			return _vox_scene(nodes, hidden_layers, int(node[2]),
				above * Transform3D(_vox_turn(int(str(frame.get("_r", "4")).to_int())), move),
				placed, depth + 1, models)
		"nGRP":
			for child: Variant in node[2]:
				var why: String = _vox_scene(nodes, hidden_layers, int(child), above, placed,
					depth + 1, models)
				if not why.is_empty():
					return why
		"nSHP":
			if int(node[2]) >= models:
				return "places model %d, which it does not have" % int(node[2])
			if placed.size() >= 65536:
				return "places more models than can be brought in"
			placed.append([int(node[2]), above, true])
	return ""


## A turn as MagicaVoxel packs it in a byte: which column the one in each
## of the first two rows is in (two bits each; the third row's is the one
## left), and each row's sign (bits 4, 5 and 6 set for minus).
static func _vox_turn(packed: int) -> Basis:
	var first: int = packed & 3
	var second: int = (packed >> 2) & 3
	if first > 2 or second > 2 or first == second:
		return Basis.IDENTITY
	var rows: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	rows[0][first] = -1.0 if packed & 16 else 1.0
	rows[1][second] = -1.0 if packed & 32 else 1.0
	rows[2][3 - first - second] = -1.0 if packed & 64 else 1.0
	return Basis(rows[0], rows[1], rows[2]).transposed()


## MagicaVoxel's own palette, for a file that brings none: index 0 empty,
## then a cube of six levels of red, green and blue (0xFF down to 0x00 by
## 0x33, red slowest, black left out), then ten levels between them of
## red, green, blue and grey (0xEE, 0xDD, 0xBB, 0xAA, 0x88, 0x77, 0x55,
## 0x44, 0x22, 0x11).
static func _vox_palette() -> PackedColorArray:
	var out := PackedColorArray([Color(0, 0, 0, 0)])
	var steps: Array[int] = [0xFF, 0xCC, 0x99, 0x66, 0x33, 0x00]
	for r: int in steps:
		for g: int in steps:
			for b: int in steps:
				if r + g + b > 0:
					out.append(Color8(r, g, b))
	var between: Array[int] = [0xEE, 0xDD, 0xBB, 0xAA, 0x88, 0x77, 0x55, 0x44, 0x22, 0x11]
	for channel: int in 4:
		for level: int in between:
			out.append(Color8(level if channel in [0, 3] else 0, level if channel in [1, 3] else 0,
				level if channel in [2, 3] else 0))
	return out


# -- glTF ---------------------------------------------------------------------


## Through Godot's own glTF reader, which every build has, the browser's
## too, or its FBX reader ([param doc] and [param state] say which). A
## .gltf with its .bin and pictures beside it is written somewhere to be
## read from, since the reader finds those by path; a .glb is whole, and so
## is an FBX unless pictures were picked with it.
static func _scene(doc: GLTFDocument, state: GLTFState, bytes: PackedByteArray,
		file_name: String, extras: Dictionary, out: MeshFile) -> void:
	var kind: String = file_name.get_extension().to_lower()
	var err: int
	var written: PackedStringArray = []
	if kind == "glb" or extras.is_empty():
		err = doc.append_from_buffer(bytes, "", state)
	else:
		var dir: String = "user://brickify_import/"
		DirAccess.make_dir_recursive_absolute(dir)
		var main: String = dir + file_name.get_file()
		written.append(main)
		_write(main, bytes)
		for key: Variant in extras:
			if extras[key] is PackedByteArray:
				var path: String = dir + str(key).replace("\\", "/").get_file()
				written.append(path)
				_write(path, extras[key])
		err = doc.append_from_file(main, state)
		for path: String in written:
			DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(dir)
	if err != OK:
		out.error = "could not read %s as %s" % [file_name.get_file(),
			"FBX" if kind == "fbx" else "glTF"]
		return
	var scene: Node = doc.generate_scene(state)
	if scene == null:
		out.error = "%s has nothing in it to bring in" % file_name.get_file()
		return
	var pictures: Dictionary = {}    ## Texture2D -> index in out.textures
	_gather(scene, Transform3D.IDENTITY, out, pictures, kind != "fbx")
	scene.free()
	# A surface without normals of its own leaves holes in the rest: all of
	# them worked out again, smooth and creased, rather than half.
	for n: Vector3 in out.normals:
		if n == Vector3.ZERO:
			out.normals = PackedVector3Array()
			break


static func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()


## [param linear]: whether the file's vertex colours are linear, as a
## glTF's are; an FBX's are sRGB, as Blender writes them by default and
## Godot leaves them.
static func _gather(node: Node, parent: Transform3D, out: MeshFile,
		pictures: Dictionary, linear: bool = true) -> void:
	var here: Transform3D = parent
	if node is Node3D:
		here = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var instance: MeshInstance3D = node
		var mesh: Mesh = instance.mesh
		var turn: Basis = here.basis.inverse().transposed()
		for s: int in mesh.get_surface_count():
			if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays: Array = mesh.surface_get_arrays(s)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
			var tints: Variant = arrays[Mesh.ARRAY_COLOR]
			var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
			var order: Variant = arrays[Mesh.ARRAY_INDEX]
			var indices := PackedInt32Array()
			if order is PackedInt32Array and not (order as PackedInt32Array).is_empty():
				indices = order
			else:
				for n: int in points.size():
					indices.append(n)
			var material: Material = instance.get_active_material(s)
			var base := Color.WHITE
			var picture: int = -1
			if material is BaseMaterial3D:
				var standard: BaseMaterial3D = material
				base = standard.albedo_color
				if not base.is_equal_approx(Color.WHITE):
					out.coloured = true
				var texture: Texture2D = standard.albedo_texture
				if texture != null:
					if not pictures.has(texture):
						var image: Image = _readable(texture.get_image())
						pictures[texture] = -1
						if image != null:
							out.textures.append(image)
							pictures[texture] = out.textures.size() - 1
					picture = int(pictures[texture])
					if picture >= 0:
						out.coloured = true
			var has_normals: bool = normals is PackedVector3Array \
				and (normals as PackedVector3Array).size() == points.size()
			var has_tints: bool = tints is PackedColorArray \
				and (tints as PackedColorArray).size() == points.size()
			var has_uv: bool = uv is PackedVector2Array \
				and (uv as PackedVector2Array).size() == points.size()
			if has_tints:
				out.coloured = true
			for n: int in range(0, indices.size() - 2, 3):
				for corner: int in 3:
					var i: int = indices[n + corner]
					out.positions.append(here * points[i])
					out.normals.append((turn * (normals as PackedVector3Array)[i]).normalized()
						if has_normals else Vector3.ZERO)
					# Vertex colours in a glTF are linear; everything here is sRGB.
					var tint: Color = Color.WHITE
					if has_tints:
						tint = (tints as PackedColorArray)[i]
						if linear:
							tint = tint.linear_to_srgb()
					out.colours.append(tint * base)
					out.uvs.append((uv as PackedVector2Array)[i] if has_uv else Vector2.ZERO)
				out.texture_of.append(picture)
	for child: Node in node.get_children():
		_gather(child, here, out, pictures, linear)


# -- normals ------------------------------------------------------------------


## A normal for every corner, for a file that gave none: the faces round a
## corner averaged where they meet at less than [param crease] degrees, and
## each face its own where they meet at more. A sphere comes out smooth and
## a chamfered cube keeps its edges, so each can be laid as itself.
static func smooth_normals(points: PackedVector3Array, crease: float) -> PackedVector3Array:
	var count: int = points.size() / 3
	var faces := PackedVector3Array()
	faces.resize(count)
	var box := AABB(points[0] if not points.is_empty() else Vector3.ZERO, Vector3.ZERO)
	for p: Vector3 in points:
		box = box.expand(p)
	var unit: float = maxf(box.get_longest_axis_size(), 0.000001) / 1048576.0
	var corners_at: Dictionary = {}    ## a welded corner -> the faces there
	for t: int in count:
		var a: Vector3 = points[3 * t]
		# Its area as its length, so a sliver counts for little.
		faces[t] = (points[3 * t + 1] - a).cross(points[3 * t + 2] - a)
		for corner: int in 3:
			var key := Vector3i((points[3 * t + corner] / unit).round())
			if not corners_at.has(key):
				corners_at[key] = PackedInt32Array()
			var list: PackedInt32Array = corners_at[key]
			list.append(t)
			corners_at[key] = list
	var limit: float = cos(deg_to_rad(crease))
	var out := PackedVector3Array()
	out.resize(points.size())
	for t: int in count:
		var own: Vector3 = faces[t].normalized()
		for corner: int in 3:
			var key := Vector3i((points[3 * t + corner] / unit).round())
			var sum := Vector3.ZERO
			for other: int in (corners_at[key] as PackedInt32Array):
				if faces[other].normalized().dot(own) >= limit:
					sum += faces[other]
			out[3 * t + corner] = sum.normalized() if sum.length_squared() > 0.0 else own
	return out
