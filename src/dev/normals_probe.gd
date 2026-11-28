## Do the parts' own normals point straight out of a round wall (meshnormals)?
##
##   godot --headless --path . --script src/dev/normals_probe.gd
##
## LDraw draws a cylinder's wall as quads all cut corner to corner the same
## way, so a corner of a 16-sided ring has a quad cut through it on one side (both
## its halves there) and half of one on the other. The meshes averaged a
## corner's faces by area, and every normal round a ring leaned 3.75 degrees
## towards the side cut through it: a stud's and
## a round brick's shading banded in every look, and Best put the normals right
## itself (PathTracer.true_normals, photoreal36). tools/ldraw/geometry.py now
## weighs each face by its angle at the corner.
##
## Here, on the meshes as the app loads them: every corner of a round wall
## (exactly two flat sides meet there, the same corner angle on each, one cut
## through it and one not) and how far its normal leans from the middle of its
## two sides, signed towards the side cut through it. Positions are stored to
## 1/64 LDU, so a side's direction is good to about 0.3 degrees and one corner
## proves little; the mean over a part's corners is the lean, the noise
## averaging away and a lean not. The parts: the 1 x 1 round brick, the 2 x 4's
## studs, the car's wheel and tyre, and every part of the car.
##
## Then Best's rounding (PathTracer.rounded) still finds the round brick's arcs
## from the normals as they come: it cuts its walls finer, as it did with the
## normals put right first.
##
## Checks: each part's mean lean under 0.1 degree; the round brick rounded to
## at least four times its triangles.
extends SceneTree

const PARTS := ["3062b", "3001", "4624", "3641"]
const CAR := "res://models/car.ldr"
## A part's mean lean, at most, in degrees: by area it was 3.75.
const LEAN_MOST := 0.1
## The two halves of one flat side agree within this (cos 2 degrees): their
## stored corners are 1/64 LDU steps.
const SAME_SIDE := 0.99939
## Best's sag on a close-up of the round brick, in LDU (StudioRender's
## PRODUCT_ROUNDING of a pixel at about 30 pixels an LDU).
const SAG := 0.02

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(words: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", words])
	if not ok:
		_failures += 1


func _run() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		_check("a catalogue", false)
		quit(1)
		return
	var ids: Array = PARTS.duplicate()
	for line: String in FileAccess.get_file_as_string(CAR).split("\n"):
		var words: PackedStringArray = line.strip_edges().split(" ", false)
		if words.size() >= 15 and words[0] == "1":
			var id: String = words[14].get_basename().to_lower()
			if not id in ids:
				ids.append(id)
	print("normals_probe: %d parts, the catalogue's %s" % [ids.size(),
		ProjectSettings.globalize_path("res://assets/generated")])
	var all_corners: int = 0
	var all_sum: float = 0.0
	var worst_part: String = ""
	var worst_mean: float = 0.0
	for id: String in ids:
		var part: Lbm.PartMesh = library.mesh_for(id)
		if part == null:
			_check("%s loaded" % id, false)
			continue
		var corners: int = 0
		var total: float = 0.0
		var widest: float = 0.0
		for surface: ArrayMesh in part.surfaces:
			for lean: float in leans(surface.surface_get_arrays(0)):
				corners += 1
				total += lean
				widest = maxf(widest, absf(lean))
		if corners == 0:
			continue
		var mean: float = total / corners
		print("    %-8s %4d round corners, mean lean %+.3f, widest %.2f degrees"
			% [id, corners, mean, widest])
		all_corners += corners
		all_sum += total
		if absf(mean) > absf(worst_mean):
			worst_mean = mean
			worst_part = id
	_check("%d round corners, %s's mean lean %+.3f degrees (all %+.3f), at most %.1f"
		% [all_corners, worst_part, worst_mean, all_sum / maxi(all_corners, 1), LEAN_MOST],
		all_corners > 500 and absf(worst_mean) < LEAN_MOST)
	_rounding(library)
	print("")
	print("%d failed" % _failures if _failures else "every check passed")
	quit(1 if _failures else 0)


## Each round-wall corner's lean, in degrees, of one surface's arrays.
static func leans(arrays: Array) -> PackedFloat32Array:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Per corner: the faces there, each [its normal, its angle there].
	var at: Array = []
	at.resize(points.size())
	for v: int in points.size():
		at[v] = []
	for t: int in indices.size() / 3:
		var ids: Array = [indices[t * 3], indices[t * 3 + 1], indices[t * 3 + 2]]
		var a: Vector3 = points[ids[0]]
		var face: Vector3 = (points[ids[1]] - a).cross(points[ids[2]] - a)
		if face.length_squared() < 1e-10:
			continue
		face = face.normalized()
		for k: int in 3:
			var here: Vector3 = points[ids[k]]
			var angle: float = (points[ids[(k + 1) % 3]] - here).angle_to(points[ids[(k + 2) % 3]] - here)
			# On the side the corner's normal faces, whichever way it is wound.
			var facing: Vector3 = face if face.dot(normals[ids[k]]) >= 0.0 else -face
			(at[ids[k]] as Array).append([facing, angle])
	var out := PackedFloat32Array()
	for v: int in points.size():
		# The faces at the corner, as sides: [normal sum, angle, faces].
		var sides: Array = []
		for face: Array in at[v]:
			var joined: bool = false
			for side: Array in sides:
				if (side[0] as Vector3).normalized().dot(face[0]) >= SAME_SIDE:
					side[0] += face[0]
					side[1] += face[1]
					side[2] += 1
					joined = true
					break
			if not joined:
				sides.append([face[0], face[1], 1])
		if sides.size() != 2 or int(sides[0][2]) + int(sides[1][2]) != 3:
			continue
		if absf(float(sides[0][1]) - float(sides[1][1])) > deg_to_rad(2.0):
			continue
		# The side with two faces here is the one cut through the corner.
		var through: int = 0 if int(sides[0][2]) == 2 else 1
		var cut: Vector3 = (sides[through][0] as Vector3).normalized()
		var beside: Vector3 = (sides[1 - through][0] as Vector3).normalized()
		var between: float = rad_to_deg(cut.angle_to(beside))
		if between < 3.0 or between > 40.0:
			continue
		var normal: Vector3 = normals[v]
		# Leaning towards the side cut through the corner is positive.
		out.append((rad_to_deg(normal.angle_to(beside)) - rad_to_deg(normal.angle_to(cut))) * 0.5)
	return out


func _rounding(library: PartLibrary) -> void:
	var part: Lbm.PartMesh = library.mesh_for("3062b")
	if part == null:
		_check("3062b loaded", false)
		return
	var before: int = 0
	var after: int = 0
	for surface: ArrayMesh in part.surfaces:
		var arrays: Array = surface.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		before += indices.size() / 3
		var made: Array = PathTracer.rounded(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL],
			indices, SAG)
		after += (made[2] as PackedInt32Array).size() / 3
	_check("Best rounds the round brick from its own normals: %d triangles, %d rounded (at least 4x)"
		% [before, after], after >= before * 4)
