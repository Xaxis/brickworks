## A 3D model file read into triangles: OBJ, STL, or glTF (.gltf, .glb).
##
## What a sculpt, a scan or a model from any 3D program is brought in as,
## for Brickify to lay in bricks. Everything is kept as triangles with
## three corners each, in the file's own units and axes: a position, a
## normal, a colour, and a place on a texture. Which way is up is the
## reader's question, not the file's — STL from a printer has Z up, glTF
## has Y.
##
## Read as bytes, never from a path, because in a browser there is no path:
## the file comes through the page's own picker. Files a model names beside
## itself (an OBJ's .mtl and its pictures, a .gltf's .bin) come in
## [param extras], by name.
class_name MeshFile
extends RefCounted

## What it reads, by extension.
const KINDS: PackedStringArray = ["obj", "stl", "gltf", "glb"]
## Pictures an OBJ's material or a .gltf may name.
const PICTURES: PackedStringArray = ["png", "jpg", "jpeg", "webp", "tga", "bmp"]
const MAX_BYTES := 96 * 1024 * 1024
## A scan of millions of triangles is not wanted at forty studs, and
## reading one would hold the page for minutes.
const MOST_TRIANGLES := 1500000
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
			_gltf(bytes, file_name, extras, out)
		_:
			out.error = "%s is not a 3D model this can bring in — OBJ, STL, glTF or GLB" \
				% file_name.get_file()
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
	while out.colours.size() < out.positions.size():
		out.colours.append(Color.WHITE)
	while out.uvs.size() < out.positions.size():
		out.uvs.append(Vector2.ZERO)
	while out.texture_of.size() < out.triangle_count():
		out.texture_of.append(-1)
	if out.normals.size() != out.positions.size():
		out.normals = smooth_normals(out.positions, CREASE_DEGREES)
	return out


## The files a model names beside itself, as it names them: an OBJ's
## material libraries and their pictures (from [param extras] once they are
## read), a .gltf's buffers and pictures. For the desktop to read from the
## model's own folder; a browser is handed them by the person.
static func companions(bytes: PackedByteArray, file_name: String,
		extras: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	match file_name.get_extension().to_lower():
		"obj":
			for line: String in bytes.get_string_from_utf8().split("\n"):
				var said: String = line.strip_edges()
				if said.begins_with("mtllib "):
					out.append(said.substr(7).strip_edges())
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
					for corner: Array in [corners[0], corners[n], corners[n + 1]]:
						out.positions.append(v[int(corner[0])])
						out.colours.append(vc[int(corner[0])] * (material[0] as Color))
						out.uvs.append(vt[int(corner[1])] if int(corner[1]) >= 0 else Vector2.ZERO)
						if int(corner[2]) >= 0:
							out.normals.append(vn[int(corner[2])].normalized())
						else:
							given_normals = false
					out.texture_of.append(int(material[1]))
	if not given_normals:
		out.normals = PackedVector3Array()


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


# -- glTF ---------------------------------------------------------------------


## Through Godot's own glTF reader, which every build has, the browser's
## too. A .gltf with its .bin and pictures beside it is written somewhere
## to be read from, since the reader finds those by path; a .glb is whole.
static func _gltf(bytes: PackedByteArray, file_name: String, extras: Dictionary,
		out: MeshFile) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: int
	var written: PackedStringArray = []
	if file_name.get_extension().to_lower() == "glb" or extras.is_empty():
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
		out.error = "could not read %s as glTF" % file_name.get_file()
		return
	var scene: Node = doc.generate_scene(state)
	if scene == null:
		out.error = "%s has nothing in it to bring in" % file_name.get_file()
		return
	var pictures: Dictionary = {}    ## Texture2D -> index in out.textures
	_gather(scene, Transform3D.IDENTITY, out, pictures)
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


static func _gather(node: Node, parent: Transform3D, out: MeshFile,
		pictures: Dictionary) -> void:
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
					var tint: Color = (tints as PackedColorArray)[i].linear_to_srgb() \
						if has_tints else Color.WHITE
					out.colours.append(tint * base)
					out.uvs.append((uv as PackedVector2Array)[i] if has_uv else Vector2.ZERO)
				out.texture_of.append(picture)
	for child: Node in node.get_children():
		_gather(child, here, out, pictures)


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
