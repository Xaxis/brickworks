## Models to brickify, made here rather than downloaded: a sphere, a cube
## with chamfered edges, and a low-poly bunny, each with the colours and
## normals a real file would carry, and each written out as the file kind a
## person would bring it in as — the sphere an STL from a printer (Z up, no
## colour), the cube a GLB with a material colour, the bunny an OBJ with
## vertex colours. Made in code so the probe knows the answer: a sphere is
## round all over, a cube's chamfers are flat at forty-five degrees.
##
## The bunny is also tests/fixtures/brickify/bunny.obj, which the browser
## flow brings in through the page's file picker (brickify_probe.gd --
## --fixtures writes it again).
class_name BrickifySamples
extends RefCounted


## A sphere of [param radius], [param segments] round and [param rings]
## from pole to pole, Z up as a printer has it.
static func sphere(radius: float = 10.0, segments: int = 32, rings: int = 20) -> MeshFile:
	var out := MeshFile.new()
	out.name = "sphere"
	out.up = "+Z"
	_ellipsoid(out, Vector3.ZERO, Vector3.ONE * radius, segments, rings, Color.WHITE,
		Basis(Vector3.RIGHT, PI / 2.0))
	return out


## A cube of [param side] with every edge cut off at forty-five degrees,
## [param chamfer] in from each face: six faces, twelve chamfers and eight
## corners, each flat, in one colour.
static func chamfered_cube(side: float = 10.0, chamfer: float = 2.5,
		colour: Color = Color(0.8, 0.1, 0.1)) -> MeshFile:
	var out := MeshFile.new()
	out.name = "chamfered cube"
	var h: float = side / 2.0
	var k: float = h - chamfer
	# The six faces.
	for axis: int in 3:
		for sign: float in [-1.0, 1.0]:
			var quad: Array[Vector3] = []
			for corner: Vector2 in [Vector2(-k, -k), Vector2(k, -k), Vector2(k, k), Vector2(-k, k)]:
				quad.append(_place(axis, sign * h, corner.x, corner.y))
			_quad(out, quad, colour)
	# The twelve chamfers, between each pair of faces.
	for a: int in 3:
		for b: int in range(a + 1, 3):
			var c: int = 3 - a - b
			for sa: float in [-1.0, 1.0]:
				for sb: float in [-1.0, 1.0]:
					var quad: Array[Vector3] = []
					for end: float in [-k, k]:
						var p := Vector3.ZERO
						p[a] = sa * h
						p[b] = sb * k
						p[c] = end
						quad.append(p)
					for end: float in [k, -k]:
						var p := Vector3.ZERO
						p[a] = sa * k
						p[b] = sb * h
						p[c] = end
						quad.append(p)
					_quad(out, quad, colour)
	# The eight corners.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				_triangle(out, Vector3(sx * h, sy * k, sz * k), Vector3(sx * k, sy * h, sz * k),
					Vector3(sx * k, sy * k, sz * h), colour, Vector3.ZERO)
	# Flat: every corner's normal is its face's.
	out.normals = PackedVector3Array()
	for t: int in out.triangle_count():
		var n: Vector3 = (out.positions[3 * t + 1] - out.positions[3 * t]).cross(
			out.positions[3 * t + 2] - out.positions[3 * t]).normalized()
		for _corner: int in 3:
			out.normals.append(n)
	out.coloured = true
	return out


## A low-poly bunny: a white body, head, tail and feet, pink ears and nose,
## black eyes, sitting on its feet and facing +Z, Y up.
static func bunny() -> MeshFile:
	var out := MeshFile.new()
	out.name = "bunny"
	var white := Color(0.95, 0.95, 0.93)
	var pink := Color(0.95, 0.55, 0.65)
	var black := Color(0.06, 0.06, 0.06)
	_ellipsoid(out, Vector3(0, 5.0, 0), Vector3(4.0, 4.0, 5.5), 16, 10, white)
	_ellipsoid(out, Vector3(0, 9.2, 4.2), Vector3(3.0, 2.9, 3.2), 16, 10, white)
	for side: float in [-1.0, 1.0]:
		_ellipsoid(out, Vector3(side * 1.4, 13.5, 3.4), Vector3(0.9, 3.4, 0.6), 12, 8, pink,
			Basis(Vector3.BACK, -side * 0.22))
		_ellipsoid(out, Vector3(side * 2.3, 0.9, 2.6), Vector3(1.3, 0.9, 2.3), 12, 8, white)
		_ellipsoid(out, Vector3(side * 1.55, 10.0, 6.75), Vector3(0.55, 0.6, 0.45), 10, 6, black)
	_ellipsoid(out, Vector3(0, 9.0, 7.35), Vector3(0.55, 0.45, 0.4), 10, 6, pink)
	_ellipsoid(out, Vector3(0, 5.5, -5.6), Vector3(1.5, 1.5, 1.4), 12, 8, white)
	out.coloured = true
	return out


# -- files --------------------------------------------------------------------


## As an OBJ, with each vertex's colour after it and its normal.
static func to_obj(mesh: MeshFile) -> String:
	var lines := PackedStringArray(["# %s, made by Brickworks' brickify probe (CC0)" % mesh.name])
	for n: int in mesh.positions.size():
		var p: Vector3 = mesh.positions[n]
		var c: Color = mesh.colours[n]
		lines.append("v %.4f %.4f %.4f %.3f %.3f %.3f" % [p.x, p.y, p.z, c.r, c.g, c.b])
	for n: int in mesh.normals.size():
		var v: Vector3 = mesh.normals[n]
		lines.append("vn %.4f %.4f %.4f" % [v.x, v.y, v.z])
	for t: int in mesh.triangle_count():
		lines.append("f %d//%d %d//%d %d//%d" % [3 * t + 1, 3 * t + 1, 3 * t + 2, 3 * t + 2,
			3 * t + 3, 3 * t + 3])
	return "\n".join(lines) + "\n"


## As a binary STL, as a printer's slicer writes it: positions only.
static func to_stl(mesh: MeshFile) -> PackedByteArray:
	var count: int = mesh.triangle_count()
	var bytes := PackedByteArray()
	bytes.resize(84 + 50 * count)
	bytes.encode_u32(80, count)
	for t: int in count:
		var at: int = 84 + 50 * t
		var a: Vector3 = mesh.positions[3 * t]
		var n: Vector3 = (mesh.positions[3 * t + 1] - a).cross(mesh.positions[3 * t + 2] - a).normalized()
		for k: int in 3:
			bytes.encode_float(at + 4 * k, n[k])
		for corner: int in 3:
			var p: Vector3 = mesh.positions[3 * t + corner]
			for k: int in 3:
				bytes.encode_float(at + 12 + 12 * corner + 4 * k, p[k])
	return bytes


## As a GLB, through Godot's own glTF writer: one surface in one material
## of the mesh's first colour, with its normals.
static func to_glb(mesh: MeshFile) -> PackedByteArray:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t: int in mesh.triangle_count():
		# Godot winds its front faces the other way round from glTF and from
		# these, and turns them back on the way out.
		for corner: int in [0, 2, 1]:
			tool.set_normal(mesh.normals[3 * t + corner])
			tool.add_vertex(mesh.positions[3 * t + corner])
	var material := StandardMaterial3D.new()
	material.albedo_color = mesh.colours[0]
	tool.set_material(material)
	var root := Node3D.new()
	root.name = mesh.name.replace(" ", "_")
	var instance := MeshInstance3D.new()
	instance.name = "body"
	instance.mesh = tool.commit()
	root.add_child(instance)
	instance.owner = root
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_scene(root, state)
	var bytes: PackedByteArray = doc.generate_buffer(state)
	root.free()
	return bytes


# -- making -------------------------------------------------------------------


static func _ellipsoid(out: MeshFile, centre: Vector3, radii: Vector3, segments: int,
		rings: int, colour: Color, turn: Basis = Basis.IDENTITY) -> void:
	var grid: Array = []
	var normal_of: Array = []
	for r: int in rings + 1:
		var row: Array[Vector3] = []
		var normals: Array[Vector3] = []
		var theta: float = PI * float(r) / float(rings)
		for s: int in segments:
			var phi: float = TAU * float(s) / float(segments)
			var unit := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			row.append(centre + turn * (unit * radii))
			normals.append((turn * (unit / radii)).normalized())
		grid.append(row)
		normal_of.append(normals)
	for r: int in rings:
		for s: int in segments:
			var s2: int = (s + 1) % segments
			var a: Vector3 = grid[r][s]
			var b: Vector3 = grid[r][s2]
			var c: Vector3 = grid[r + 1][s2]
			var d: Vector3 = grid[r + 1][s]
			var na: Vector3 = normal_of[r][s]
			var nb: Vector3 = normal_of[r][s2]
			var nc: Vector3 = normal_of[r + 1][s2]
			var nd: Vector3 = normal_of[r + 1][s]
			if r > 0:
				_smooth_triangle(out, [a, b, c], [na, nb, nc], colour, centre)
			if r < rings - 1:
				_smooth_triangle(out, [a, c, d], [na, nc, nd], colour, centre)


## A body and a piece apart from it: a box, and a cube over it a stud clear
## of its top and nothing between, Y up. Joined, the cube is still there;
## dropped, as Brickify once dropped every piece but the largest, it is not.
## [member MeshFile.name] "floating"; the cube is the last 12 triangles.
static func floating() -> MeshFile:
	var out := MeshFile.new()
	out.name = "floating"
	out.coloured = true
	_box(out, AABB(Vector3(0, 0, 0), Vector3(12, 6, 8)), Color(0.15, 0.35, 0.75))
	_box(out, AABB(Vector3(4.5, 7.2, 2.5), Vector3(3, 3, 3)), Color(0.85, 0.2, 0.15))
	return out


## A post with a block out past one side of it, which tips: a 2 x 2 post six
## tall and on it a block eight long reaching six past the post's edge, Y up.
## A set stands such a thing on a stand. [member MeshFile.name] "overhang".
static func overhang() -> MeshFile:
	var out := MeshFile.new()
	out.name = "overhang"
	_box(out, AABB(Vector3(0, 0, 0), Vector3(2, 6, 2)), Color.WHITE)
	_box(out, AABB(Vector3(0, 6, -1), Vector3(9, 2.4, 4)), Color.WHITE)
	return out


## A closed box, its faces flat and wound to face out.
static func _box(out: MeshFile, box: AABB, colour: Color) -> void:
	var centre: Vector3 = box.get_center()
	var h: Vector3 = box.size / 2.0
	for axis: int in 3:
		for sign: float in [-1.0, 1.0]:
			var corners: Array[Vector3] = []
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p := Vector3.ZERO
				p[axis] = sign * h[axis]
				p[(axis + 1) % 3] = corner.x * h[(axis + 1) % 3]
				p[(axis + 2) % 3] = corner.y * h[(axis + 2) % 3]
				corners.append(centre + p)
			var normal := Vector3.ZERO
			normal[axis] = sign
			for t: Array in [[0, 1, 2], [0, 2, 3]]:
				_triangle(out, corners[t[0]], corners[t[1]], corners[t[2]], colour, centre)
				for _n: int in 3:
					out.normals.append(normal)


static func _smooth_triangle(out: MeshFile, corners: Array, normals: Array, colour: Color,
		centre: Vector3) -> void:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var order: Array[int] = [0, 1, 2]
	if (b - a).cross(c - a).dot((a + b + c) / 3.0 - centre) < 0.0:
		order = [0, 2, 1]
	for n: int in order:
		out.positions.append(corners[n])
		out.normals.append(normals[n])
		out.colours.append(colour)
		out.uvs.append(Vector2.ZERO)
	out.texture_of.append(-1)


## A triangle wound to face away from [param centre].
static func _triangle(out: MeshFile, a: Vector3, b: Vector3, c: Vector3, colour: Color,
		centre: Vector3) -> void:
	if (b - a).cross(c - a).dot((a + b + c) / 3.0 - centre) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
	for p: Vector3 in [a, b, c]:
		out.positions.append(p)
		out.colours.append(colour)
		out.uvs.append(Vector2.ZERO)
	out.texture_of.append(-1)


static func _quad(out: MeshFile, quad: Array[Vector3], colour: Color) -> void:
	_triangle(out, quad[0], quad[1], quad[2], colour, Vector3.ZERO)
	_triangle(out, quad[0], quad[2], quad[3], colour, Vector3.ZERO)


## A point on the face across [param axis] at [param at], with the other
## two coordinates [param u] and [param v] in order.
static func _place(axis: int, at: float, u: float, v: float) -> Vector3:
	var p := Vector3.ZERO
	p[axis] = at
	p[(axis + 1) % 3] = u
	p[(axis + 2) % 3] = v
	return p
