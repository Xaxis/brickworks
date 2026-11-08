## The model as a 3MF for a 3D printer that prints in several colours: File,
## Export, 3D model… and export_model's "3mf", through MeshExport.write
## (APP_UX6 #18, print3mf).
##
## One object for each colour a part is placed in, each in that colour: a
## base material whose displaycolor is the colour's RGB as PartLibrary.color
## gives it (a see-through colour's alpha after it), which is how the 3MF
## core states a colour. A slicer gives each object, or each part of one
## object when it loads them as one, its own filament, so a colour is one
## choice to make, not one a part. In millimetres, standing on Z as a
## slicer's bed does, with the model's box in the printer's positive octant
## and its lowest point on the bed, which is where the core says a model
## should be (3.3); each object is an item of the build with that move as
## its transform.
##
## A part's colours: a surface in the part's own colour (16) goes to the
## object of the colour it is placed in. A surface moulded in a colour of
## its own that closes round a volume (3829c01's steering wheel, black on
## a stand of any colour) is a solid of that colour, and goes to that
## colour's object. One that does not (a print on a tile, a face on a head)
## is painted on the part's body: its triangles stay in the body's object,
## each naming its own colour (a triangle's pid and p1), which a slicer that
## reads a triangle's colour paints and any other prints in the body's.
## Measured on 1,135 moulded-colour surfaces of 400 parts: a print has a
## third or more of its edges open and points one way; a solid has a
## twentieth (where a stud stands on a face, unstitched) and points no way.
##
## Every triangle counter-clockwise seen from outside, as 3MF wants: the
## app's shapes are read as MeshExport reads them for glTF, OBJ and STL, a
## part placed mirrored is turned back, and a surface from an LDraw file
## that is not BFC-certified (4.5% of parts have one) has no front known,
## so it is turned to agree with its certified neighbours across their
## edges, and what none reaches so the volume it closes is positive.
##
## Vertices are one per place within a part (the app's meshes have two
## where a crease gives a corner two normals), as the core's edges are by
## vertex. Parts are not stitched to each other, and a part is as LDraw
## draws it: closed, but a stud stands on a top face that runs on under it,
## which every slicer fills as the solid it is.
class_name Mesh3mf
extends RefCounted

const CORE := "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
const MODEL_PART := "3D/3dmodel.model"
const CONTENT_TYPES := ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	+ "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
	+ "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
	+ "<Default Extension=\"model\" ContentType=\"application/vnd.ms-package.3dmanufacturing-3dmodel+xml\"/>"
	+ "</Types>\n")
const RELATIONSHIPS := ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	+ "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
	+ "<Relationship Target=\"/" + MODEL_PART + "\" Id=\"rel0\" "
	+ "Type=\"http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel\"/>"
	+ "</Relationships>\n")

## The base materials' resource id; the objects follow it.
const MATERIALS_ID := 1

## A moulded-colour surface is a solid of its own when no more than this
## share of its edges is open (a stud on a face) and its triangles' areas,
## as vectors, cancel to within this share of their sum (it points no way).
const SOLID_OPEN := 0.1
const SOLID_POINTING := 0.05

## Whether two-sided surfaces are turned to face out; a probe turns it
## off to see what they are as LDraw draws them.
static var face_out: bool = true


## Some of a part's triangles that go to one object: its body (the
## surfaces in the part's own colour, and the prints on them), or a solid
## moulded in a colour of its own.
class Piece extends RefCounted:
	## Lbm.COLOR_INHERIT for the colour the part is placed in.
	var colour: int = Lbm.COLOR_INHERIT
	## One a place, in LDU on the app's axes.
	var positions := PackedVector3Array()
	## Three a triangle, counter-clockwise from outside.
	var triangles := PackedInt32Array()
	## A triangle's own colour, painted on it; Lbm.COLOR_INHERIT for the
	## piece's.
	var painted := PackedInt32Array()
	## The colours painted on it, each once.
	var paints := PackedInt32Array()


var maker: MeshExport
var _pieces: Dictionary = {}       ## mesh hash -> Array[Piece]


func _init(by: MeshExport) -> void:
	maker = by


## The 3MF's bytes: a zip of its content types, its relationship and its
## model. A coroutine, as MeshExport.write is.
func write(list: Array, title: String, made: MeshExport.Made) -> PackedByteArray:
	# Which object each piece of each part goes to.
	var by_colour: Dictionary = {}     ## colour -> Array of [brick, Piece]
	var painted: Dictionary = {}       ## every colour painted on a part
	var done: int = 0
	for brick: BrickWorld.Brick in list:
		done += 1
		var pieces: Array = await _pieces_of(brick.part_id)
		if pieces.is_empty():
			made.left_out[brick.part_id] = int(made.left_out.get(brick.part_id, 0)) + 1
			continue
		made.parts += 1
		for piece: Piece in pieces:
			var colour: int = brick.color_code if piece.colour == Lbm.COLOR_INHERIT else piece.colour
			if not by_colour.has(colour):
				by_colour[colour] = []
			(by_colour[colour] as Array).append([brick, piece])
			for code: int in piece.paints:
				if code != colour:
					painted[code] = true
		if await maker._between_parts(done):
			made.cancelled = true
			return PackedByteArray()
	if by_colour.is_empty():
		return PackedByteArray()
	var colours: Array = by_colour.keys()
	colours.sort()
	var materials: Array = colours.duplicate()
	var extra: Array = painted.keys().filter(func(code: int) -> bool: return not by_colour.has(code))
	extra.sort()
	materials.append_array(extra)
	var material_of: Dictionary = {}
	for n: int in materials.size():
		material_of[materials[n]] = n

	var lines: PackedStringArray = maker._lines
	lines.clear()
	maker._text = PackedByteArray()
	lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	lines.append("<model unit=\"millimeter\" xmlns=\"%s\">" % CORE)
	lines.append(" <metadata name=\"Title\">%s</metadata>" % _escaped(title))
	lines.append(" <metadata name=\"Application\">Brickworks %s</metadata>" % _escaped(BuildInfo.version()))
	lines.append(" <resources>")
	lines.append("  <basematerials id=\"%d\">" % MATERIALS_ID)
	for code: int in materials:
		var colour: PartLibrary.BrickColor = maker.library.color(code)
		lines.append("   <base name=\"%s\" displaycolor=\"%s\"/>" % [_escaped(colour.name),
			display_colour(colour)])
	lines.append("  </basematerials>")

	var entries: int = 0
	for colour: int in colours:
		entries += (by_colour[colour] as Array).size()
	if maker.job != null:
		maker.job.count(0, entries)
	done = 0
	var low := Vector3.INF
	var high := -Vector3.INF
	for n: int in colours.size():
		var colour: int = colours[n]
		var placed: Array = by_colour[colour]
		lines.append("  <object id=\"%d\" type=\"model\" name=\"%s\" pid=\"%d\" pindex=\"%d\">" % [
			MATERIALS_ID + 1 + n, _escaped(maker.library.color(colour).name), MATERIALS_ID,
			material_of[colour]])
		lines.append("   <mesh>")
		lines.append("    <vertices>")
		var bases := PackedInt32Array()
		var count: int = 0
		for entry: Array in placed:
			var brick: BrickWorld.Brick = entry[0]
			var piece: Piece = entry[1]
			bases.append(count)
			var points: PackedVector3Array = _place(brick) * piece.positions
			for i: int in points.size():
				var p: Vector3 = points[i]
				low = low.min(p)
				high = high.max(p)
				lines.append("     <vertex x=\"%.4f\" y=\"%.4f\" z=\"%.4f\"/>" % [p.x, p.y, p.z])
				if i & 4095 == 4095:
					await maker._written_out()
			count += points.size()
			await maker._written_out()
		lines.append("    </vertices>")
		lines.append("    <triangles>")
		for e: int in placed.size():
			var brick: BrickWorld.Brick = placed[e][0]
			var piece: Piece = placed[e][1]
			var base: int = bases[e]
			# Placed mirrored, a part's triangles turn the other way round.
			var mirrored: bool = brick.transform.basis.determinant() < 0.0
			var at: PackedInt32Array = piece.triangles
			for t: int in at.size() / 3:
				var a: int = at[t * 3] + base
				var b: int = at[t * 3 + (2 if mirrored else 1)] + base
				var c: int = at[t * 3 + (1 if mirrored else 2)] + base
				var own: int = piece.painted[t]
				if own != Lbm.COLOR_INHERIT and own != colour:
					lines.append("     <triangle v1=\"%d\" v2=\"%d\" v3=\"%d\" pid=\"%d\" p1=\"%d\"/>" % [
						a, b, c, MATERIALS_ID, material_of[own]])
				else:
					lines.append("     <triangle v1=\"%d\" v2=\"%d\" v3=\"%d\"/>" % [a, b, c])
				if t & 4095 == 4095:
					await maker._written_out()
			made.triangles += at.size() / 3
			done += 1
			if lines.size() > 4096:
				await maker._written_out(true)
			if await maker._between_parts(done):
				made.cancelled = true
				maker._text = PackedByteArray()
				lines.clear()
				return PackedByteArray()
		lines.append("    </triangles>")
		lines.append("   </mesh>")
		lines.append("  </object>")
	lines.append(" </resources>")
	# Each object moved as one, so the model's box starts at the bed's
	# corner and its lowest point is on the bed.
	var move: String = "1 0 0 0 1 0 0 0 1 %.4f %.4f %.4f" % [-low.x, -low.y, -low.z]
	lines.append(" <build>")
	for n: int in colours.size():
		lines.append("  <item objectid=\"%d\" transform=\"%s\"/>" % [MATERIALS_ID + 1 + n, move])
	lines.append(" </build>")
	lines.append("</model>")
	await maker._written_out(true)
	var model: PackedByteArray = maker._text
	maker._text = PackedByteArray()
	made.colours = colours.size()
	return await maker.zip([["[Content_Types].xml", CONTENT_TYPES.to_utf8_buffer()],
		["_rels/.rels", RELATIONSHIPS.to_utf8_buffer()], [MODEL_PART, model]])


## A colour as a base material's displaycolor: its RGB, and a see-through
## colour's alpha after it.
static func display_colour(colour: PartLibrary.BrickColor) -> String:
	var rgb: String = "#" + colour.rgb.to_html(false).to_upper()
	if colour.is_transparent():
		rgb += "%02X" % clampi(colour.alpha, 0, 255)
	return rgb


## Where a part's points go: millimetres, the app's +Y up turned to +Z up.
static func _place(brick: BrickWorld.Brick) -> Transform3D:
	return Transform3D(MeshExport.Z_UP * brick.transform.basis * MeshExport.MILLIMETRES,
		MeshExport.Z_UP * brick.transform.origin * MeshExport.MILLIMETRES)


static func _escaped(text: String) -> String:
	return text.xml_escape(true)


# -- a part's pieces ---------------------------------------------------------------


## A part's pieces, made once per shape; empty when this build has no shape
## for it.
func _pieces_of(part_id: String) -> Array:
	var info: PartLibrary.PartInfo = maker.library.parts.get(part_id)
	if info == null:
		return []
	if _pieces.has(info.mesh_hash):
		return _pieces[info.mesh_hash]
	var surfaces: Array = maker._shape(part_id)
	var out: Array = []
	var body: Array = []
	for shape: MeshExport.Shape in surfaces:
		if shape.colour != Lbm.COLOR_INHERIT and await solid(shape.positions, shape.indices):
			out.append(await _piece([shape], shape.colour))
		else:
			body.append(shape)
	if not body.is_empty():
		# A part with no surface in its own colour is the colour most of its
		# body is in.
		var colour: int = Lbm.COLOR_INHERIT
		var most: Dictionary = {}
		for shape: MeshExport.Shape in body:
			if shape.colour == Lbm.COLOR_INHERIT:
				most.clear()
				break
			most[shape.colour] = int(most.get(shape.colour, 0)) + shape.triangles()
		for code: int in most:
			if colour == Lbm.COLOR_INHERIT or int(most[code]) > int(most[colour]):
				colour = code
		out.push_front(await _piece(body, colour))
	_pieces[info.mesh_hash] = out
	return out


## Surfaces made one piece in [param colour]: their places welded, their
## degenerate triangles dropped (3MF wants a triangle's three corners
## distinct), and two-sided ones turned to face out.
func _piece(shapes: Array, colour: int) -> Piece:
	var piece := Piece.new()
	piece.colour = colour
	var at: Dictionary = {}            ## Vector3i in 1/64 LDU -> index
	var known := PackedByteArray()
	var unknown: bool = false
	for shape: MeshExport.Shape in shapes:
		var index := PackedInt32Array()
		index.resize(shape.positions.size())
		for i: int in shape.positions.size():
			var key := Vector3i((shape.positions[i] * 64.0).round())
			if not at.has(key):
				at[key] = piece.positions.size()
				piece.positions.append(shape.positions[i])
			index[i] = at[key]
			if i & 4095 == 4095 and maker._pace.due():
				await maker._pace.next()
		var own: int = Lbm.COLOR_INHERIT if shape.colour == colour else shape.colour
		if own != Lbm.COLOR_INHERIT and not piece.paints.has(own):
			piece.paints.append(own)
		var corners: PackedInt32Array = shape.indices
		for t: int in corners.size() / 3:
			var a: int = index[corners[t * 3]]
			var b: int = index[corners[t * 3 + 1]]
			var c: int = index[corners[t * 3 + 2]]
			if a == b or b == c or a == c:
				continue
			piece.triangles.append_array([a, b, c])
			piece.painted.append(own)
			known.append(0 if shape.two_sided else 1)
		unknown = unknown or shape.two_sided
	if unknown and face_out:
		await _face_out(piece, known)
	return piece


## Whether a moulded-colour surface is a solid of its own (see the class
## notes), from its places and its triangles.
func solid(positions: PackedVector3Array, indices: PackedInt32Array) -> bool:
	var weld: Dictionary = {}
	var edges: Dictionary = {}
	var pointing := Vector3.ZERO
	var area: float = 0.0
	for t: int in indices.size() / 3:
		var ids := PackedInt32Array()
		for corner: int in 3:
			var key := Vector3i((positions[indices[t * 3 + corner]] * 64.0).round())
			if not weld.has(key):
				weld[key] = weld.size()
			ids.append(weld[key])
		for e: int in 3:
			var lo: int = mini(ids[e], ids[(e + 1) % 3])
			var hi: int = maxi(ids[e], ids[(e + 1) % 3])
			var edge: int = (lo << 32) | hi
			edges[edge] = int(edges.get(edge, 0)) + 1
		var a: Vector3 = positions[indices[t * 3]]
		var face: Vector3 = (positions[indices[t * 3 + 1]] - a).cross(positions[indices[t * 3 + 2]] - a)
		pointing += face
		area += face.length()
		if t & 4095 == 4095 and maker._pace.due():
			await maker._pace.next()
	if edges.is_empty() or area <= 0.0:
		return false
	var open: int = 0
	for edge: int in edges:
		if int(edges[edge]) % 2 == 1:
			open += 1
	return float(open) / edges.size() <= SOLID_OPEN and pointing.length() <= SOLID_POINTING * area


## The piece's two-sided triangles turned to face out: across an edge two
## triangles share, the second goes the way the first does (the edge's
## corners the other way round), starting from the certified ones; any
## the certified never reach are turned together so the volume they close
## about the piece's middle is positive.
func _face_out(piece: Piece, known: PackedByteArray) -> void:
	var corners: PackedInt32Array = piece.triangles
	var count: int = corners.size() / 3
	var edges: Dictionary = {}          ## lo << 32 | hi -> PackedInt32Array of triangles
	for t: int in count:
		for e: int in 3:
			var a: int = corners[t * 3 + e]
			var b: int = corners[t * 3 + (e + 1) % 3]
			var edge: int = (mini(a, b) << 32) | maxi(a, b)
			if not edges.has(edge):
				edges[edge] = PackedInt32Array()
			edges[edge].append(t)
		if t & 4095 == 4095 and maker._pace.due():
			await maker._pace.next()
	var decided: PackedByteArray = known.duplicate()
	var queue := PackedInt32Array()
	for t: int in count:
		if known[t] == 1:
			queue.append(t)
	_spread(corners, edges, decided, queue)
	var middle := Vector3.ZERO
	for p: Vector3 in piece.positions:
		middle += p
	middle /= maxf(piece.positions.size(), 1)
	for seed: int in count:
		if decided[seed] == 1:
			continue
		decided[seed] = 1
		var reached: PackedInt32Array = _spread(corners, edges, decided, PackedInt32Array([seed]))
		var volume: float = 0.0
		for t: int in reached:
			var a: Vector3 = piece.positions[corners[t * 3]] - middle
			var b: Vector3 = piece.positions[corners[t * 3 + 1]] - middle
			var c: Vector3 = piece.positions[corners[t * 3 + 2]] - middle
			volume += a.dot(b.cross(c))
		if volume < 0.0:
			for t: int in reached:
				_turn(corners, t)
		if maker._pace.due():
			await maker._pace.next()
	piece.triangles = corners


## From each triangle in [param queue], every undecided one sharing an edge
## with it (and only it) turned its way and decided, and on from those.
## The triangles reached, the queue's own among them.
static func _spread(corners: PackedInt32Array, edges: Dictionary, decided: PackedByteArray,
		queue: PackedInt32Array) -> PackedInt32Array:
	var reached := PackedInt32Array()
	var next: int = 0
	while next < queue.size():
		var t: int = queue[next]
		next += 1
		reached.append(t)
		for e: int in 3:
			var a: int = corners[t * 3 + e]
			var b: int = corners[t * 3 + (e + 1) % 3]
			var sharing: PackedInt32Array = edges[(mini(a, b) << 32) | maxi(a, b)]
			if sharing.size() != 2:
				continue
			var u: int = sharing[0] if sharing[1] == t else sharing[1]
			if u == t or decided[u] == 1:
				continue
			# The same edge the same way round in both: u faces the other way.
			for f: int in 3:
				if corners[u * 3 + f] == a and corners[u * 3 + (f + 1) % 3] == b:
					_turn(corners, u)
					break
			decided[u] = 1
			queue.append(u)
	return reached


static func _turn(corners: PackedInt32Array, t: int) -> void:
	var b: int = corners[t * 3 + 1]
	corners[t * 3 + 1] = corners[t * 3 + 2]
	corners[t * 3 + 2] = b
