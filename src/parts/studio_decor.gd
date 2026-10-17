## BrickLink Studio's prints and decorations, read into LDraw's and written
## back out in Studio's.
##
## Studio does not use LDraw's !TEXMAP. A decorated part in an .io — one of
## its catalogue's prints, a sticker (which Studio files as the part with the
## sticker on, 2431pb0038 for LDraw's 2431d01), or a part made in its Part
## Designer — carries its picture inside the part's own lines:
##
##   0 PE_TEX_PATH <path>          which faces: -1 this file and everything
##                                 in it; otherwise 0-based indices that
##                                 count only the type-1 lines, file by file
##                                 down ("1": this file's second subfile)
##   0 PE_TEX_INFO [16 numbers] <base64 PNG>
##                                 the picture, on one line; with 16 numbers
##                                 before it, a projection box (x y z and a
##                                 matrix as a type-1 line has them, then
##                                 the picture's min and max on the box)
##   3 <c> <9 numbers> <u v u v u v>   a face with its own picture
##                                 coordinates, v up from the picture's foot
##
## The most specific path wins. A face with coordinates takes the picture as
## they say; one without, under a projection box, takes it as the box casts
## it, when it meets the box or faces the box's -Y. (Read from Studio's own
## parts in an .io saved by Studio 2.25.2 — set 31213's lips, a tile whose
## two top faces carry 0.045 to 0.955 — and from ldr_tools'
## pe_tex_info.rs, reverse-engineered from Studio's Assembly-CSharp.dll,
## whose box arithmetic this follows line for line.) Where these are: Part
## Designer's own parts in CustomParts/<name>.dat, and every part the model
## uses inlined, flattened, in model2.ldr, in BrickLink's colour numbers
## (-1 its main colour); model.ldr only names them, a Studio print by
## BrickLink's number with bl_ before it (bl_3068pb2483).
##
## Read ([method carried]): every part model.ldr names that is Studio's — a
## bl_ part, or one from CustomParts — is flattened from its source with its
## pictures, and written as an LDraw part with each picture's faces in a
## PLANAR !TEXMAP block and the picture as a !DATA section, appended to the
## model text. An affine map of a triangle's coordinates is exactly a PLANAR
## projection (its gradients across the face are the projection's axes), so
## faces sharing one map share one block, and a decal's box is one block
## for all its faces. The model then opens as one that carries its parts
## (CustomParts.take_from) and [PartPrints] draws them, as any print.
##
## Written ([method studio_text]): a print or a sticker made here, its
## TEXMAP blocks turned back into faces with coordinates, each picture's
## faces in a subfile of their own named by a PE_TEX_PATH, for CustomParts/
## in an exported .io. Whether Studio itself draws them has not been seen:
## there is no Studio on this machine.
##
## Everything is in LDraw's own axes.
class_name StudioDecor
extends RefCounted

## The line a part read from Studio carries, and the parts bin's place for it.
const FROM_STUDIO := "0 // From BrickLink Studio:"
const CATEGORY := "From Studio"
## How deep subfiles are followed, as PartForge does.
const DEEPEST := 32


## A part flattened: its faces, the pictures on them, and what could not be
## read.
class Flat extends RefCounted:
	## Each face: {"points": [Vector3 x3], "colour": int, "two_sided": bool,
	## "texture": index or -1, "uv": [Vector2 x3] in the picture's terms, v
	## down from its top as TEXMAP has it, or []}.
	var faces: Array = []
	## Each edge: [Vector3, Vector3].
	var edges: Array = []
	## Subfiles kept as references, written as they are: [colour, Transform3D,
	## name, inverted].
	var kept: Array = []
	## The pictures, PNG bytes, by texture index; an empty one did not decode.
	var pictures: Array[PackedByteArray] = []
	var title: String = ""
	## An Array: a packed array reached through another object is a copy,
	## and appending to it appends to nothing.
	var notes: Array = []


## A picture of a part's, as PE_TEX_INFO gave it.
class StudioTexture extends RefCounted:
	var index: int = 0
	var path: Array = []
	## The box it is cast from, or null for one taken from faces' own
	## coordinates: a type-1 line's twelve numbers, and min and max.
	var box: Variant = null
	var low := Vector2.ZERO
	var high := Vector2.ONE


# -- reading --------------------------------------------------------------------------


## The sections of an MPD text: lowercase file name -> its lines, the FILE
## and NOFILE lines left out.
static func sections(text: String) -> Dictionary:
	var out: Dictionary = {}
	var current: String = ""
	var lines: Array = []
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 FILE "):
			if not current.is_empty():
				out[current] = PackedStringArray(lines)
			current = line.substr(7).strip_edges().to_lower()
			lines = []
			continue
		if line.begins_with("0 NOFILE"):
			if not current.is_empty():
				out[current] = PackedStringArray(lines)
			current = ""
			lines = []
			continue
		if not current.is_empty():
			lines.append(line)
	if not current.is_empty():
		out[current] = PackedStringArray(lines)
	return out


## [param model] (model.ldr) with every Studio part it names appended as an
## LDraw part with its pictures: from [param custom] (CustomParts/, name ->
## text) and [param model2] (model2.ldr, BrickLink's numbers). {"text", "read":
## the names carried, "notes": what was left out and why}.
static func carried(model: String, model2: String, custom: Dictionary) -> Dictionary:
	var own: Dictionary = sections(model)
	var wanted: Array = []
	for raw: String in model.split("\n"):
		var tokens: PackedStringArray = raw.strip_edges().replace("\t", " ").split(" ", false)
		if tokens.size() < 15 or tokens[0] != "1":
			continue
		var name: String = " ".join(tokens.slice(14)).strip_edges().to_lower().replace("\\", "/")
		if own.has(name) or wanted.has(name):
			continue
		# Studio's own: a bl_ part, or one of the file's custom parts. Any
		# other is LDraw's, and the library has it or has not.
		if name.get_file().begins_with("bl_") or _custom_has(custom, name.get_file()):
			wanted.append(name)
	if wanted.is_empty():
		return {"text": model, "read": PackedStringArray(), "notes": PackedStringArray()}
	var studio: Dictionary = sections(model2) if not model2.is_empty() else {}
	# Part Designer's files are MPDs of their own (0 FILE first), or plain.
	var designed: Dictionary = {}
	for file_name: String in custom:
		var text: String = custom[file_name]
		var inside: Dictionary = sections(text)
		if inside.is_empty():
			inside[file_name.get_file().to_lower()] = text.split("\n")
		designed.merge(inside)
		designed[file_name.get_file().to_lower()] = inside.values()[0]
	var appended := PackedStringArray()
	var read := PackedStringArray()
	var notes := PackedStringArray()
	for name: String in wanted:
		var bare: String = name.get_file()
		var source: Dictionary = {}
		var bricklink: bool = false
		var found: String = ""
		# model2.ldr's copy first: flattened by Studio itself, with the
		# coordinates its projection gave every face.
		for candidate: String in [bare, bare.trim_prefix("bl_")]:
			if found.is_empty() and studio.has(candidate) \
					and (bare.begins_with("bl_") or designed.has(bare)):
				found = candidate
				source = studio
				bricklink = true
		if found.is_empty() and designed.has(bare):
			found = bare
			source = designed
		if found.is_empty():
			continue
		var id: String = bare.get_basename()
		var made: Dictionary = to_ldraw(id, found, source, bricklink, studio)
		if not str(made["problem"]).is_empty():
			notes.append("%s: %s" % [id, made["problem"]])
			continue
		appended.append("0 FILE %s.dat" % id)
		appended.append(str(made["text"]).strip_edges())
		appended.append("0 NOFILE")
		var pictures: Dictionary = made["pictures"]
		for picture: String in pictures:
			var encoded: String = Marshalls.raw_to_base64(pictures[picture])
			appended.append("0 !DATA " + picture)
			for at: int in range(0, encoded.length(), 76):
				appended.append("0 !: " + encoded.substr(at, 76))
		read.append(id)
		for said: Variant in made["notes"]:
			notes.append(str(said))
	if appended.is_empty():
		return {"text": model, "read": read, "notes": notes}
	var head: String = model.strip_edges()
	# A model.ldr with no FILE line of its own (Studio 2.2) is one first.
	if not head.begins_with("0 FILE"):
		head = "0 FILE model.ldr\n" + head + "\n0 NOFILE"
	return {"text": head + "\n" + "\n".join(appended) + "\n", "read": read, "notes": notes}


## model2.ldr's sections while a part is read: the parts it uses, flattened by
## Studio, for the subfiles the library cannot give.
static var _studio_copy: Dictionary = {}


## Whether PartForge can read [param name] itself: one of the primitives the
## app ships, or a file of the checkout's LDraw library.
static func _forge_reads(name: String) -> bool:
	var key: String = PartForge.normalise(name)
	return FileAccess.file_exists(PartForge.BUNDLED + key) \
		or not PartForge.library_path(key).is_empty()


## Whether CustomParts/ holds [param file_name], at its top or in a folder.
static func _custom_has(custom: Dictionary, file_name: String) -> bool:
	for path: String in custom:
		if path.get_file().to_lower() == file_name:
			return true
	return false


## One of Studio's parts, [param name] in [param source] (lowercase name ->
## lines), as an LDraw part called [param id]: {"text", "pictures": file name
## -> PNG bytes, "notes", "problem"}. [param bricklink]: its colours are
## BrickLink's numbers, as model2.ldr's are.
static func to_ldraw(id: String, name: String, source: Dictionary, bricklink: bool,
		studio_copy: Dictionary = {}) -> Dictionary:
	_studio_copy = studio_copy
	var flat := Flat.new()
	_walk(flat, source, name, Transform3D.IDENTITY, 16, [], [], false, bricklink, true, 0)
	if flat.faces.is_empty() and flat.kept.is_empty():
		return {"text": "", "pictures": {}, "notes": flat.notes,
			"problem": "it has no faces to build"}
	var pictures: Dictionary = {}
	for n: int in flat.pictures.size():
		if not flat.pictures[n].is_empty():
			pictures["%s-%d.png" % [id, n + 1]] = flat.pictures[n]
	return {"text": _part_text(id, name, flat), "pictures": pictures, "notes": flat.notes,
		"problem": ""}


## Flatten file [param name] into [param flat], placed by [param at] (into the
## root file's axes), its colour 16 [param colour], [param path] the subfile
## indices down to it, [param textures] those declared above it.
static func _walk(flat: Flat, source: Dictionary, name: String, at: Transform3D, colour: int,
		path: Array, textures: Array, inverted: bool, bricklink: bool, culling: bool,
		depth: int) -> void:
	if depth > DEEPEST:
		return
	var lines: PackedStringArray = source.get(name, PackedStringArray())
	var mine: Array = textures.duplicate()
	var tex_path: Array = path.duplicate()
	var ccw: bool = true
	var certified: bool = false
	var clip: bool = true
	var invert_next: bool = false
	var flipped: bool = inverted != (at.basis.determinant() < 0.0)
	var subfile: int = 0
	for raw: String in lines:
		var line: String = raw.strip_edges()
		if line.is_empty():
			continue
		var tokens: PackedStringArray = line.replace("\t", " ").split(" ", false)
		match tokens[0]:
			"0":
				if tokens.size() < 2:
					continue
				var keyword: String = tokens[1].to_upper()
				if keyword == "PE_TEX_PATH":
					var numbers: Array = []
					for word: String in tokens.slice(2):
						numbers.append(word.to_int())
					tex_path = path.duplicate()
					if numbers != [-1]:
						tex_path.append_array(numbers)
				elif keyword == "PE_TEX_INFO" and tokens.size() >= 3:
					var texture := StudioTexture.new()
					texture.index = flat.pictures.size()
					texture.path = tex_path.duplicate()
					if tokens.size() >= 19:
						var box := PackedFloat64Array()
						for word: String in tokens.slice(2, 14):
							box.append(word.to_float())
						texture.box = box
						texture.low = Vector2(tokens[14].to_float(), tokens[15].to_float())
						texture.high = Vector2(tokens[16].to_float(), tokens[17].to_float())
					flat.pictures.append(_png(tokens[tokens.size() - 1]))
					if flat.pictures[texture.index].is_empty():
						flat.notes.append("a picture of %s is not a PNG and was left off" % name)
					mine.append(texture)
				elif keyword == "BFC":
					var said: String = " ".join(tokens.slice(2)).to_upper()
					if said.contains("NOCERTIFY"):
						certified = false
					elif said.contains("CERTIFY"):
						certified = true
					if said.contains("INVERTNEXT"):
						invert_next = true
					if said.contains("NOCLIP"):
						clip = false
					elif said.contains("CLIP"):
						clip = true
					if said.contains("CCW"):
						ccw = true
					elif said.contains("CW"):
						ccw = false
				elif flat.title.is_empty() and depth == 0 and not keyword.begins_with("!") \
						and not keyword.begins_with("PE_") and not keyword.ends_with(":") \
						and not keyword in ["BFC", "BL_ITEM_NO", "BL_ITEM_KEY", "ISSUBMODEL",
							"FLEXIBLETYPE", "BL_CATEGORYINDEX", "RENDERANGLEOFFSET",
							"ISASSEMBLY", "FLEXIBLEBRICKCONTROLPOINTUNITLENGTH", "//"]:
					flat.title = " ".join(tokens.slice(1))
			"1":
				if tokens.size() < 15:
					continue
				var numbers := PackedFloat64Array()
				for word: String in tokens.slice(2, 14):
					numbers.append(word.to_float())
				var child: Transform3D = at * _placed(numbers)
				var child_name: String = " ".join(tokens.slice(14)).to_lower().replace("\\", "/")
				var child_path: Array = path.duplicate()
				child_path.append(subfile)
				subfile += 1
				var child_colour: int = _colour(tokens[1].to_int(), colour, bricklink)
				var child_inverted: bool = inverted != invert_next
				invert_next = false
				var known: String = _found(source, child_name)
				var readable: bool = _forge_reads(child_name)
				if known.is_empty() and _textured_under(mine, child_path) and readable:
					# Faces a picture goes on: flattened from the library itself
					# where the checkout has it, so the box can be cast on them.
					source[child_name] = PartForge._read_library(PartForge.normalise(child_name)) \
						.split("\n")
					known = child_name
				if known.is_empty() and (not readable or _textured_under(mine, child_path)) \
						and not _found(_studio_copy, child_name).is_empty():
					# A part the library cannot give here (the web build has no
					# LDraw files), from Studio's own copy in model2.ldr, in its
					# BrickLink numbers.
					_walk(flat, _studio_copy, _found(_studio_copy, child_name), child, child_colour,
						child_path, mine, child_inverted, true, culling and certified and clip,
						depth + 1)
					continue
				if known.is_empty():
					if _textured_under(mine, child_path):
						flat.notes.append("the picture on %s was left off: its shape is not in the file"
							% child_name)
					flat.kept.append([child_colour, child, child_name, child_inverted])
					continue
				_walk(flat, source, known, child, child_colour, child_path, mine, child_inverted,
					bricklink, culling and certified and clip, depth + 1)
			"2":
				if tokens.size() < 8:
					continue
				flat.edges.append([at * _v(tokens, 2), at * _v(tokens, 5)])
			"3", "4":
				var corners: int = 3 if tokens[0] == "3" else 4
				if tokens.size() < 2 + corners * 3:
					continue
				var points: Array[Vector3] = []
				for k: int in corners:
					points.append(_v(tokens, 2 + k * 3))
				var uvs: Array[Vector2] = []
				if tokens.size() >= 2 + corners * 5:
					for k: int in corners:
						var o: int = 2 + corners * 3 + k * 2
						uvs.append(Vector2(tokens[o].to_float(), tokens[o + 1].to_float()))
				var face_colour: int = _colour(tokens[1].to_int(), colour, bricklink)
				var two_sided: bool = not (culling and certified and clip)
				# Wound counter-clockwise, as the file's are once BFC is said.
				var reverse: bool = (not ccw) != flipped
				var pieces: Array = [[0, 1, 2]] if corners == 3 else [[0, 1, 2], [0, 2, 3]]
				for piece: Array in pieces:
					var p: Array[Vector3] = [points[piece[0]], points[piece[1]], points[piece[2]]]
					var t: Array[Vector2] = []
					if not uvs.is_empty():
						t.assign([uvs[piece[0]], uvs[piece[1]], uvs[piece[2]]])
					if reverse:
						p.reverse()
						t.reverse()
					_face(flat, mine, path, at, p, t, face_colour, two_sided)


## A face of a file placed by [param at]: its picture, if one is on it, and its
## corners in the root's axes.
static func _face(flat: Flat, textures: Array, path: Array, at: Transform3D, points: Array[Vector3],
		uvs: Array[Vector2], colour: int, two_sided: bool) -> void:
	var texture: StudioTexture = _active(textures, path)
	var picture: Array = []
	if texture != null and not flat.pictures[texture.index].is_empty():
		if uvs.size() == 3:
			picture = uvs
		elif texture.box != null:
			picture = _cast(texture, at, points)
	var placed: Array = [at * points[0], at * points[1], at * points[2]]
	var face: Dictionary = {"points": placed, "colour": colour, "two_sided": two_sided,
		"texture": -1, "uv": []}
	if not picture.is_empty():
		face["texture"] = texture.index
		# Studio's v runs up from the picture's foot, TEXMAP's down from its top.
		face["uv"] = [Vector2(picture[0].x, 1.0 - picture[0].y),
			Vector2(picture[1].x, 1.0 - picture[1].y), Vector2(picture[2].x, 1.0 - picture[2].y)]
	flat.faces.append(face)


## The picture a face of the file at [param path] takes: the most specific of
## [param textures] whose path its file's begins with.
static func _active(textures: Array, path: Array) -> StudioTexture:
	var best: StudioTexture = null
	for texture: StudioTexture in textures:
		if texture.path.size() > path.size():
			continue
		if path.slice(0, texture.path.size()) != texture.path:
			continue
		if best == null or texture.path.size() >= best.path.size():
			best = texture
	return best


## Whether a picture of [param textures] may land on faces under the subfile
## at [param path]: one on it, above it or inside it.
static func _textured_under(textures: Array, path: Array) -> bool:
	for texture: StudioTexture in textures:
		var n: int = mini(texture.path.size(), path.size())
		if path.slice(0, n) == texture.path.slice(0, n):
			return true
	return false


## The picture's coordinates of a face cast from a texture's box, or [] for
## a face it is not cast on: Studio's InitMatrixWithTargetPartMatrix,
## IsIntersecting, CheckFaceNormalWithTextureNormal and GetUV, as ldr_tools
## has them. [param points] are in the file's own axes, [param at] places
## the file.
static func _cast(texture: StudioTexture, at: Transform3D, points: Array[Vector3]) -> Array:
	var box: Transform3D = at * _placed(texture.box)
	var extents := Vector3(box.basis.x.length(), box.basis.y.length(), box.basis.z.length()) * 0.5
	if extents.x <= 0.0 or extents.y <= 0.0 or extents.z <= 0.0:
		return []
	# The box's frame with its scale taken out, its mirroring kept.
	var frame := Transform3D(Basis(box.basis.x.normalized(), box.basis.y.normalized(),
		box.basis.z.normalized()), box.origin)
	var into: Transform3D = frame.affine_inverse() * at
	var local: Array[Vector3] = [into * points[0], into * points[1], into * points[2]]
	var facing: Vector3 = (local[1] - local[0]).cross(local[2] - local[1])
	var down: bool = facing.length() > 0.0 and facing.normalized().dot(Vector3(0, -1, 0)) > 0.0001
	if not down and not _meets_box(local, extents):
		return []
	var span: Vector2 = texture.high - texture.low
	if absf(span.x) < 1e-9 or absf(span.y) < 1e-9:
		return []
	var out: Array = []
	for p: Vector3 in local:
		out.append((Vector2(p.x, -p.z) - texture.low) / span)
	return out


## Whether a triangle meets a box round the origin with these half sides:
## the separating axis test, as Studio's IsIntersecting does it.
static func _meets_box(t: Array[Vector3], half: Vector3) -> bool:
	var edges: Array[Vector3] = [t[1] - t[0], t[2] - t[1], t[0] - t[2]]
	for e: Vector3 in edges:
		for test: Array in [[Vector3(0, -e.z, e.y), half.y * absf(e.z) + half.z * absf(e.y)],
				[Vector3(e.z, 0, -e.x), half.x * absf(e.z) + half.z * absf(e.x)],
				[Vector3(-e.y, e.x, 0), half.x * absf(e.y) + half.y * absf(e.x)]]:
			var axis: Vector3 = test[0]
			var a: float = t[0].dot(axis)
			var b: float = t[1].dot(axis)
			var c: float = t[2].dot(axis)
			if maxf(-maxf(a, maxf(b, c)), minf(a, minf(b, c))) > float(test[1]):
				return false
	for dim: int in 3:
		var lo: float = minf(t[0][dim], minf(t[1][dim], t[2][dim]))
		var hi: float = maxf(t[0][dim], maxf(t[1][dim], t[2][dim]))
		if hi < -half[dim] or lo > half[dim]:
			return false
	var normal: Vector3 = edges[0].cross(edges[1])
	return normal.dot(t[0]) <= normal.abs().dot(half)


## A file name in [param source], as written or with its folder (s/, 48/)
## left off; "" when it is not there.
static func _found(source: Dictionary, name: String) -> String:
	if source.has(name):
		return name
	if source.has(name.get_file()):
		return name.get_file()
	return ""


## A type-1 line's twelve numbers as a transform, in LDraw's axes.
static func _placed(n: PackedFloat64Array) -> Transform3D:
	return Transform3D(Basis(Vector3(n[3], n[6], n[9]), Vector3(n[4], n[7], n[10]),
		Vector3(n[5], n[8], n[11])), Vector3(n[0], n[1], n[2]))


static func _v(tokens: PackedStringArray, at: int) -> Vector3:
	return Vector3(tokens[at].to_float(), tokens[at + 1].to_float(), tokens[at + 2].to_float())


## A colour code as LDraw has it: 16 the colour above, BrickLink's numbers
## (model2.ldr's; -1 its main colour) in LDraw's.
static func _colour(code: int, above: int, bricklink: bool) -> int:
	if bricklink:
		if code == -1 or code == 16:
			return above
		return int(PartLibrary.by_bricklink.get(code, above))
	return above if code == 16 else code


## A base64 PNG, decoded, or empty when it is not one.
static func _png(encoded: String) -> PackedByteArray:
	if encoded.length() < 16 or not PictureFile.BASE64.search(encoded.trim_suffix("=").trim_suffix("=")):
		return PackedByteArray()
	var bytes: PackedByteArray = Marshalls.base64_to_raw(encoded)
	return bytes if PictureFile.kind_of(bytes) == "png" else PackedByteArray()


# -- the LDraw part ---------------------------------------------------------------------


## The part text: each picture's faces in PLANAR TEXMAP blocks, one per map
## they share, then the plain faces, the edges and the subfiles kept.
static func _part_text(id: String, name: String, flat: Flat) -> String:
	var out := PackedStringArray()
	var title: String = flat.title if not flat.title.is_empty() else id
	out.append("0 " + title)
	out.append("0 Name: %s.dat" % id)
	out.append("0 Author: BrickLink Studio, read by Brickworks")
	out.append("0 !LDRAW_ORG Unofficial_Part")
	out.append("")
	out.append("0 BFC CERTIFY CCW")
	out.append("")
	out.append("%s from=%s" % [FROM_STUDIO, name.replace(" ", "_")])
	out.append("0 // Its pictures as Studio cast them (PE_TEX_INFO), each in a PLANAR")
	out.append("0 // TEXMAP block that gives every face the coordinates Studio gave it.")
	var blocks: Dictionary = {}           ## key -> [texture, points, faces]
	var order: Array = []
	var plain: Array = []
	for face: Dictionary in flat.faces:
		if int(face["texture"]) < 0:
			plain.append(face)
			continue
		var map: Array = _map_of(face["points"], face["uv"])
		if map.is_empty():
			plain.append(face)
			continue
		var key: String = "%d|%s" % [int(face["texture"]), _key_of(map)]
		if not blocks.has(key):
			blocks[key] = [int(face["texture"]), map, []]
			order.append(key)
		(blocks[key][2] as Array).append(face)
	for key: String in order:
		var block: Array = blocks[key]
		var points: Array = block[1]
		var words := PackedStringArray(["0 !TEXMAP START PLANAR"])
		for p: Vector3 in points:
			words.append_array([_n(p.x), _n(p.y), _n(p.z)])
		words.append("%s-%d.png" % [id, int(block[0]) + 1])
		out.append("")
		out.append(" ".join(words))
		_write(out, block[2])
		out.append("0 !TEXMAP END")
	out.append("")
	_write(out, plain)
	for edge: Array in flat.edges:
		var a: Vector3 = edge[0]
		var b: Vector3 = edge[1]
		out.append("2 24 %s %s %s %s %s %s" % [_n(a.x), _n(a.y), _n(a.z), _n(b.x), _n(b.y), _n(b.z)])
	for kept: Array in flat.kept:
		var at: Transform3D = kept[1]
		if bool(kept[3]):
			out.append("0 BFC INVERTNEXT")
		out.append("1 %d %s %s %s %s %s %s %s %s %s %s %s %s %s" % [int(kept[0]),
			_n(at.origin.x), _n(at.origin.y), _n(at.origin.z),
			_n(at.basis.x.x), _n(at.basis.y.x), _n(at.basis.z.x),
			_n(at.basis.x.y), _n(at.basis.y.y), _n(at.basis.z.y),
			_n(at.basis.x.z), _n(at.basis.y.z), _n(at.basis.z.z), kept[2]])
	out.append("0")
	return "\n".join(out) + "\n"


static func _write(out: PackedStringArray, faces: Array) -> void:
	var open: bool = false
	for face: Dictionary in faces:
		var sided: bool = bool(face["two_sided"])
		if sided and not open:
			out.append("0 BFC NOCLIP")
			open = true
		elif not sided and open:
			out.append("0 BFC CLIP")
			open = false
		var words := PackedStringArray(["3", str(int(face["colour"]))])
		for p: Vector3 in face["points"]:
			words.append_array([_n(p.x), _n(p.y), _n(p.z)])
		out.append(" ".join(words))
	if open:
		out.append("0 BFC CLIP")


## The PLANAR TEXMAP points that give a triangle's corners [param uv]: the
## affine map across its face, u = g.p + cu and v = h.p + cv, with g and h in
## its plane, is the projection whose first point is where u and v are 0 and
## whose second and third are g / |g|^2 and h / |h|^2 on from it. [] for a
## triangle whose coordinates do not span the picture.
static func _map_of(points: Array, uv: Array) -> Array:
	var a: Vector3 = points[0]
	var e1: Vector3 = (points[1] as Vector3) - a
	var e2: Vector3 = (points[2] as Vector3) - a
	var g11: float = e1.dot(e1)
	var g12: float = e1.dot(e2)
	var g22: float = e2.dot(e2)
	var det: float = g11 * g22 - g12 * g12
	if absf(det) < 1e-12:
		return []
	var gradients: Array[Vector3] = []
	for axis: int in 2:
		var d1: float = (uv[1] as Vector2)[axis] - (uv[0] as Vector2)[axis]
		var d2: float = (uv[2] as Vector2)[axis] - (uv[0] as Vector2)[axis]
		var alpha: float = (g22 * d1 - g12 * d2) / det
		var beta: float = (g11 * d2 - g12 * d1) / det
		gradients.append(e1 * alpha + e2 * beta)
	var g: Vector3 = gradients[0]
	var h: Vector3 = gradients[1]
	if g.length_squared() < 1e-14 or h.length_squared() < 1e-14:
		return []
	var cu: float = (uv[0] as Vector2).x - g.dot(a)
	var cv: float = (uv[0] as Vector2).y - h.dot(a)
	# The first point: in the plane of g and h, where both are 0.
	var gg: float = g.dot(g)
	var gh: float = g.dot(h)
	var hh: float = h.dot(h)
	var under: float = gg * hh - gh * gh
	if absf(under) < 1e-14:
		return []
	var s: float = (-cu * hh + cv * gh) / under
	var t: float = (-cv * gg + cu * gh) / under
	var p1: Vector3 = g * s + h * t
	return [p1, p1 + g / gg, p1 + h / hh]


## A map's key, for faces that share one: its points to a thousandth of an
## LDU, which a picture drawn ten pixels to the LDU does not see.
static func _key_of(map: Array) -> String:
	var words := PackedStringArray()
	for p: Vector3 in map:
		for k: int in 3:
			words.append(str(snappedf(p[k], 0.001) + 0.0))
	return ",".join(words)


static func _n(value: float) -> String:
	return PartEditor._n(value)


# -- writing ------------------------------------------------------------------------------


## A part with pictures made here (a print, a sticker, a part read from Studio)
## as Studio carries one: its TEXMAP blocks' faces with the coordinates their
## projection gives them, each picture's faces in a subfile of their own, that
## picture in a PE_TEX_INFO named by the PE_TEX_PATH of that subfile; the rest
## of its lines as they are. For CustomParts/<id>.dat in an .io. [param
## pictures] is file name -> PNG bytes.
static func studio_text(id: String, text: String, pictures: Dictionary) -> String:
	## Picture name -> its faces' lines, with coordinates. Arrays: a packed array
	## read out of a Dictionary is a copy, and appending to it appends to nothing.
	var by_picture: Dictionary = {}
	var picture_order: Array = []
	var rest := PackedStringArray()
	var area: PartPrints.Area = null
	var picture: String = ""
	var title: String = ""
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		var tokens: PackedStringArray = line.replace("\t", " ").split(" ", false)
		if title.is_empty() and tokens.size() > 1 and tokens[0] == "0" \
				and not tokens[1].begins_with("!") and not tokens[1].ends_with(":") \
				and tokens[1] != "BFC" and tokens[1] != "//":
			title = " ".join(tokens.slice(1))
			continue
		if line.begins_with("0 !TEXMAP START") and tokens.size() >= 14:
			var numbers := PackedFloat64Array()
			for n: int in range(4, 13):
				numbers.append(tokens[n].to_float())
			var cylinder: bool = tokens[3].to_upper() == "CYLINDRICAL"
			area = PartPrints._area_of({"method": tokens[3].to_upper(), "points": numbers,
				"angle": tokens[13].to_float() if cylinder else 0.0})
			picture = tokens[tokens.size() - 1].to_lower()
			if not by_picture.has(picture):
				by_picture[picture] = ["0 BFC CERTIFY CCW"]
				picture_order.append(picture)
			continue
		if line.begins_with("0 !TEXMAP END"):
			area = null
			continue
		if line.begins_with("0 !TEXMAP") or line.begins_with("0 !:") or line.begins_with("0 Name:") \
				or line.begins_with("0 Author:"):
			continue
		if area != null and tokens.size() > 0 and tokens[0] in ["3", "4"]:
			var corners: int = 3 if tokens[0] == "3" else 4
			if tokens.size() < 2 + corners * 3:
				continue
			var points: Array[Vector3] = []
			for k: int in corners:
				points.append(_v(tokens, 2 + k * 3))
			var pieces: Array = [[0, 1, 2]] if corners == 3 else [[0, 1, 2], [0, 2, 3]]
			for piece: Array in pieces:
				var words := PackedStringArray(["3", tokens[1]])
				for k: int in piece:
					var p: Vector3 = points[k]
					words.append_array([_n(p.x), _n(p.y), _n(p.z)])
				for k: int in piece:
					var at: Vector2 = area.uv(points[k])
					# TEXMAP's v runs down from the top; Studio's up from the foot.
					words.append_array([_n(at.x), _n(1.0 - at.y)])
				(by_picture[picture] as Array).append(" ".join(words))
			continue
		if area != null and line.begins_with("0 BFC"):
			(by_picture[picture] as Array).append(line)
			continue
		if not line.begins_with("0 BFC CERTIFY"):
			rest.append(line)
	var out := PackedStringArray()
	out.append("0 FILE %s.dat" % id)
	out.append("0 " + (title if not title.is_empty() else id))
	out.append("0 Name:  %s.dat" % id)
	out.append("0 Author:  Brickworks")
	out.append("0 BFC CERTIFY CCW")
	var named: Dictionary = {}
	for key: String in pictures:
		named[key.to_lower()] = pictures[key]
	for n: int in picture_order.size():
		var bytes: PackedByteArray = named.get(picture_order[n], PackedByteArray())
		if bytes.is_empty():
			continue
		out.append("0 PE_TEX_PATH %d" % n)
		out.append("0 PE_TEX_INFO " + Marshalls.raw_to_base64(bytes))
	# The pictures' subfiles first, so their indices are the PE_TEX_PATHs.
	for n: int in picture_order.size():
		out.append("1 16 0 0 0 1 0 0 0 1 0 0 0 1 %s-tex%d.dat" % [id, n])
	for line: String in rest:
		if not line.is_empty() and line != "0":
			out.append(line)
	out.append("0 NOFILE")
	for n: int in picture_order.size():
		out.append("0 FILE %s-tex%d.dat" % [id, n])
		out.append_array(PackedStringArray(by_picture[picture_order[n]]))
		out.append("0 NOFILE")
	return "\r\n".join(out) + "\r\n"
