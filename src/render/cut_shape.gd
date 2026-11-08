## A cut-away by a box, a sphere or a cylinder standing upright (SeeInside),
## as StudWorx cuts one: what is inside it is not drawn, and the faces it
## cuts through are drawn filled in the part's colour (plastic_body's cap,
## cut_shape.gdshaderinc), so a wall cut through reads as a wall. Each fills
## [member room]: a sphere is round in it and a cylinder round across it,
## because SeeInside keeps the room square where the shape must be.
##
## The cut-away's plane (BrickWorld.set_cut) is the fourth shape, and either
## is kept with the model as a line LDraw readers pass over ([constant META]),
## in the file's own coordinates: it comes back when the file opens, and the
## parts themselves are never changed. The booklet and Render draw worlds of
## their own, which never have it.
class_name CutShape
extends RefCounted

const PLANE := 0
const BOX := 1
const SPHERE := 2
const CYLINDER := 3
## As the meta line says each.
const KINDS: Array[String] = ["plane", "box", "sphere", "cylinder"]
const AXES: Array[String] = ["x", "y", "z"]

const META := "0 !BRICKWORKS CUT_AWAY "

var kind: int = BOX
## What it fills, in the world, LDU.
var room: AABB = AABB()


func _init(of_kind: int = BOX, fills: AABB = AABB()) -> void:
	kind = of_kind
	room = fills


## Whether [param point] is inside it, where nothing is drawn.
func contains(point: Vector3) -> bool:
	var half: Vector3 = room.size * 0.5
	if half.x <= 0.0 or half.y <= 0.0 or half.z <= 0.0:
		return false
	var d: Vector3 = (point - room.get_center()) / half
	match kind:
		SPHERE:
			return d.length_squared() < 1.0
		CYLINDER:
			return d.x * d.x + d.z * d.z < 1.0 and absf(d.y) < 1.0
	return absf(d.x) < 1.0 and absf(d.y) < 1.0 and absf(d.z) < 1.0


## Which side of it a part's [param box] is: -1 wholly outside, drawn whole;
## 1 wholly inside, not drawn; 0 across its surface, drawn cut. A part's box
## is round the part, so a part counted inside is inside, one counted
## outside is outside, and one across may be either: it is drawn cut, and
## the shader takes off only what is in.
func side_of(box: AABB) -> int:
	var half: Vector3 = room.size * 0.5
	if half.x <= 0.0 or half.y <= 0.0 or half.z <= 0.0:
		return -1
	# In the room's own measure, where it is a unit box, ball or drum.
	var low: Vector3 = (box.position - room.get_center()) / half
	var high: Vector3 = (box.end - room.get_center()) / half
	if high.x <= -1.0 or low.x >= 1.0 or high.y <= -1.0 or low.y >= 1.0 \
			or high.z <= -1.0 or low.z >= 1.0:
		return -1
	# The point of the box nearest the middle, and the one furthest.
	var near := Vector3(clampf(0.0, low.x, high.x), clampf(0.0, low.y, high.y),
		clampf(0.0, low.z, high.z))
	var far := Vector3(maxf(absf(low.x), absf(high.x)), maxf(absf(low.y), absf(high.y)),
		maxf(absf(low.z), absf(high.z)))
	match kind:
		SPHERE:
			if near.length_squared() >= 1.0:
				return -1
			return 1 if far.length_squared() < 1.0 else 0
		CYLINDER:
			if near.x * near.x + near.z * near.z >= 1.0:
				return -1
			return 1 if far.x * far.x + far.z * far.z < 1.0 and far.y < 1.0 else 0
	return 1 if far.x < 1.0 and far.y < 1.0 and far.z < 1.0 else 0


## [param material]'s cut (cut_shape.gdshaderinc's uniforms): at [param
## plane], or by [param shape] when there is one.
static func set_into(material: ShaderMaterial, plane: Plane, shape: CutShape) -> void:
	material.set_shader_parameter("cut_plane",
		Vector4(plane.normal.x, plane.normal.y, plane.normal.z, plane.d))
	material.set_shader_parameter("cut_shape", PLANE if shape == null else shape.kind)
	if shape != null:
		material.set_shader_parameter("cut_centre", shape.room.get_center())
		material.set_shader_parameter("cut_half", shape.room.size * 0.5)


# -- kept with the model ---------------------------------------------------------
#
# The line is JSON, in the file's coordinates (LDraw's: y down, z towards the
# viewer, the model where the file has it):
#   {"shape": "box", "from": [x, y, z], "to": [x, y, z], "ghosts": false}
#   {"shape": "plane", "axis": "y", "at": -41, "away": -1, "ghosts": false}
# "away" is the side of the plane taken off, along the file's axis.


## [param text] with the cut [param scheme] says written into it, and any it
## had taken out; with an empty scheme, only taken out.
static func written_into(text: String, scheme: Dictionary) -> String:
	var lines: PackedStringArray = text.split("\n")
	var kept := PackedStringArray()
	for line: String in lines:
		if not line.begins_with(META):
			kept.append(line)
	if scheme.is_empty():
		return "\n".join(kept)
	kept.insert(mini(1, kept.size()), META + JSON.stringify(scheme))
	return "\n".join(kept)


## The cut [param text] keeps, as [method written_into] was given it; empty
## when it keeps none, or one this cannot read.
static func read(text: String) -> Dictionary:
	var at: int = text.find(META)
	if at < 0:
		return {}
	var end: int = text.find("\n", at)
	var raw: Variant = JSON.parse_string(text.substr(at + META.length(),
		(end if end >= 0 else text.length()) - at - META.length()).strip_edges())
	if not (raw is Dictionary):
		return {}
	var said: Dictionary = raw
	var shape: String = str(said.get("shape", ""))
	if not shape in KINDS:
		return {}
	var ghosts: bool = bool(said.get("ghosts", false))
	if shape == "plane":
		var axis: String = str(said.get("axis", ""))
		var where: Variant = said.get("at")
		var away: Variant = said.get("away")
		if not axis in AXES or not (where is float or where is int) \
				or not (away is float or away is int) or absf(float(away)) != 1.0:
			return {}
		return {"shape": shape, "axis": axis, "at": float(where), "away": int(away),
			"ghosts": ghosts}
	var from: Variant = _point(said.get("from"))
	var to: Variant = _point(said.get("to"))
	if from == null or to == null:
		return {}
	var box := AABB(from, Vector3.ZERO).expand(to)
	if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
		return {}
	return {"shape": shape, "from": [box.position.x, box.position.y, box.position.z],
		"to": [box.end.x, box.end.y, box.end.z], "ghosts": ghosts}


static func _point(said: Variant) -> Variant:
	if not (said is Array) or (said as Array).size() != 3:
		return null
	var out := Vector3.ZERO
	for n: int in 3:
		var value: Variant = (said as Array)[n]
		if not (value is float or value is int) or is_nan(float(value)) \
				or is_inf(float(value)):
			return null
		out[n] = float(value)
	return out
