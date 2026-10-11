## Where a ray first meets a set of triangles, each taken a hundredth of an
## LDU larger than it is. A ray exactly along the edge two triangles share
## — a click in the middle of a tile, whose top is two triangles meeting on
## its diagonal — slips between them in floating point, and the engine's
## TriangleMesh.intersect_ray then found the tile's far side, or the floor
## under it, depending on the last bit of the ray (2026-10-11: a sticker
## meant for two tiles went on the floor under them). Grown, the two
## overlap along the edge and one of them is met.
##
## [Grid] buckets the triangles in cubes so a short ray — how thick a wall
## is — tests only those near it.
class_name Rays
extends RefCounted

## How much larger each triangle is taken to be, in LDU.
const GROW := 0.01


## The nearest point where a ray meets a triangle of [param faces] (three
## corners a triangle): {"position", "normal", "face"}, or empty.
static func nearest(faces: PackedVector3Array, from: Vector3, toward: Vector3,
		reach: float = INF) -> Dictionary:
	var dir: Vector3 = toward.normalized()
	var best: float = reach
	var found: int = -1
	var at := Vector3.ZERO
	for t: int in faces.size() / 3:
		var a: Vector3 = faces[t * 3]
		var b: Vector3 = faces[t * 3 + 1]
		var c: Vector3 = faces[t * 3 + 2]
		# Each triangle a hundredth of an LDU larger all round: a ray
		# through the middle of a tile meets the diagonal its two top
		# triangles share, and in floats it slipped between them and found
		# the tile's far side — or the floor under it.
		var middle: Vector3 = (a + b + c) / 3.0
		a += (a - middle).normalized() * GROW
		b += (b - middle).normalized() * GROW
		c += (c - middle).normalized() * GROW
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, dir, a, b, c)
		if hit == null:
			continue
		var d: float = from.distance_to(hit)
		if d < best:
			best = d
			found = t
			at = hit
	if found < 0:
		return {}
	var n: Vector3 = (faces[found * 3 + 1] - faces[found * 3]).cross(
		faces[found * 3 + 2] - faces[found * 3])
	return {"position": at, "normal": n.normalized(), "face": found, "distance": best}


## Triangles bucketed in cubes of [member cell] LDU.
class Grid extends RefCounted:
	var cell: float = 4.0
	var faces := PackedVector3Array()
	var buckets: Dictionary = {}     ## Vector3i -> Array of triangle indices

	func _init(of: PackedVector3Array, size: float = 4.0) -> void:
		faces = of
		cell = size
		for t: int in faces.size() / 3:
			var box := AABB(faces[t * 3], Vector3.ZERO).expand(faces[t * 3 + 1]).expand(faces[t * 3 + 2])
			var lo := Vector3i((box.position / cell).floor())
			var hi := Vector3i((box.end / cell).floor())
			for x: int in range(lo.x, hi.x + 1):
				for y: int in range(lo.y, hi.y + 1):
					for z: int in range(lo.z, hi.z + 1):
						var key := Vector3i(x, y, z)
						if not buckets.has(key):
							buckets[key] = []
						(buckets[key] as Array).append(t)

	## The nearest hit within [param reach] of [param from], testing only
	## the triangles in the cubes the ray passes through.
	func nearest(from: Vector3, toward: Vector3, reach: float) -> Dictionary:
		var dir: Vector3 = toward.normalized()
		var tried: Dictionary = {}
		var best: float = reach
		var found: Dictionary = {}
		var steps: int = ceili(reach / (cell * 0.5)) + 1
		for n: int in steps:
			var p: Vector3 = from + dir * minf(reach, n * cell * 0.5)
			var key := Vector3i((p / cell).floor())
			for dx: int in [-1, 0, 1]:
				for dy: int in [-1, 0, 1]:
					for dz: int in [-1, 0, 1]:
						var near := key + Vector3i(dx, dy, dz)
						if tried.has(near):
							continue
						tried[near] = true
						for t: int in buckets.get(near, []):
							var a: Vector3 = faces[t * 3]
							var b: Vector3 = faces[t * 3 + 1]
							var c: Vector3 = faces[t * 3 + 2]
							var middle: Vector3 = (a + b + c) / 3.0
							var hit: Variant = Geometry3D.ray_intersects_triangle(from, dir,
								a + (a - middle).normalized() * GROW,
								b + (b - middle).normalized() * GROW,
								c + (c - middle).normalized() * GROW)
							if hit == null:
								continue
							var d: float = from.distance_to(hit)
							if d < best:
								best = d
								found = {"position": hit, "face": t, "distance": d}
		return found
