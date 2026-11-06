## How big a 3D model comes out in bricks, and the choices it is laid with:
## what Make, Brickify a 3D model's panel shows before anything is laid.
##
## Apart from [Brickify] so the panel opens without it. Brickify names the
## assistant it lays with, so naming it compiled 4.3 MB of code, 91 scripts,
## as the panel opened: 2.0 s on a browser's first use (leaves, 2026-11-05).
## The panel compiles Brickify as a model is laid, under the job's bar.
class_name BrickifySize
extends RefCounted

## Plates to a stud's width, as a brick is tall.
const PLATES := 2.5
const LEAST_STUDS := 6
const MOST_STUDS := 64
## Which way the file's up is, each turned to stand on the baseplate.
const UPS: PackedStringArray = ["+Y", "+Z", "-Z", "+X", "-X", "-Y"]
## The colours a model is laid in: solid colours LEGO makes now, in
## hundreds of sets each, so the slopes and bricks it asks for exist in
## them. Not the mosaic's palette, whose transparent and pearl colours are
## for a picture of plates: a red cube came out in trans-red.
const PALETTE: Array[int] = [15, 71, 72, 0, 4, 320, 5, 29, 353, 26, 25, 484, 191, 14, 226,
	27, 326, 10, 2, 288, 330, 378, 3, 323, 322, 321, 212, 73, 1, 272, 379, 30, 31, 85,
	19, 28, 84, 92, 78, 70, 308]


## The turn that stands a model with [param up] on the baseplate.
static func turn_for(up: String) -> Basis:
	match up:
		"+Z":
			return Basis(Vector3.RIGHT, -PI / 2.0)
		"-Z":
			return Basis(Vector3.RIGHT, PI / 2.0)
		"+X":
			return Basis(Vector3.BACK, PI / 2.0)
		"-X":
			return Basis(Vector3.BACK, -PI / 2.0)
		"-Y":
			return Basis(Vector3.RIGHT, PI)
	return Basis.IDENTITY


## How big it comes out from its bounds, stood up already: studs across,
## plates up, studs along.
static func size_in(box: AABB, studs: int) -> Vector3i:
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest <= 0.0:
		return Vector3i.ZERO
	var scale: float = float(studs) / longest
	return Vector3i(maxi(1, ceili(box.size.x * scale - 0.001)),
		maxi(1, ceili(box.size.y * scale * PLATES - 0.001)),
		maxi(1, ceili(box.size.z * scale - 0.001)))


## The model's bounds turned by [param turn].
static func turned_bounds(mesh: MeshFile, turn: Basis) -> AABB:
	if mesh.positions.is_empty():
		return AABB()
	var box := AABB(turn * mesh.positions[0], Vector3.ZERO)
	for p: Vector3 in mesh.positions:
		box = box.expand(turn * p)
	return box
