## Parts made to sit inside another, and where real sets put them: a pane
## in a window frame, a door in a door frame.
##
## The builder forgives the overlap of an insert seated in its frame when a
## part is put down by hand, and the assistant when it checks a design.
## Both read the one rule; this is the core's copy of the assistant's
## (Assistant.NESTS, Assistant._seated_in), so putting a pane in a window
## by hand does not load the assistant (Later). tests/test_later.py fails
## when the two differ: the table, and the rule's body, line for line.
##
## Measured over the LDraw model repository's sets on 2026-10-09 and
## 2026-10-10; see Assistant.NESTS for the counts each seat was read from.
## Insert -> [frame, x, y, z, quarter turns about the frame's up] in the
## frame's own LDraw coordinates. Only there is the overlap forgiven, to
## within an LDU: a pane anywhere else is a fault as before.
class_name Nests
extends RefCounted

const NESTS: Dictionary = {
	"60601": [["60592", 0, 0, 0, 0]],
	"60602": [["60593", 0, 0, 0, 0]],
	"38320": [["60592", 0, 0, 0, 0]],
	"57895": [["60596", 0, 4, 5, 0], ["60596", 0, 4, 5, 2],
		["57894", 0, 4, -3, 0], ["57894", 0, 4, -3, 2]],
	"60623": [["60596", -32, 0, 5, 0], ["60596", 32, 0, 5, 2]],
	"60616a": [["60596", -32, 0, 5, 0], ["60596", 32, 0, 5, 2]],
	"60616b": [["60596", -32, 0, 5, 0], ["60596", 32, 0, 5, 2]],
	"60603": [["60594", 0, 8, 5, 2], ["60594", 0, 8, 4, 0]],
	"60608": [["60594", -32, 4, 4, 3], ["60594", 32, 4, 4, 1]],
	"60607": [["60594", -32, 4, 4, 3], ["60594", 32, 4, 4, 1]],
	"86210": [["60594", 0, 8, 4, 0], ["60594", 0, 8, 2, 2]],
	"3854": [["6556", -34, 4, 5, 3], ["6556", 34, 4, 5, 1], ["6556", -34, 4, 3, 3],
		["60594", -34, 4, 4, 3], ["60594", 34, 4, 4, 1]],
}


## Whether [param insert] at [param at_insert] sits in [param frame] at
## [param at_frame] where real sets seat it. Part ids resolved.
static func _seated_in(insert: String, at_insert: Transform3D,
		frame: String, at_frame: Transform3D) -> bool:
	if not NESTS.has(insert):
		return false
	var f: PackedFloat64Array = LdrModel.from_transform(at_frame)
	var g: PackedFloat64Array = LdrModel.from_transform(at_insert)
	# The insert in the frame's own coordinates: its offset carried back
	# through the frame's turn, and the turn between the two.
	var offset := Vector3(g[0] - f[0], g[1] - f[1], g[2] - f[2])
	var rows: Array = [Vector3(f[3], f[4], f[5]), Vector3(f[6], f[7], f[8]),
		Vector3(f[9], f[10], f[11])]
	var local := Vector3.ZERO
	var turn: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	for k: int in 3:
		local += (rows[k] as Vector3) * offset[k]
	var theirs: Array = [Vector3(g[3], g[4], g[5]), Vector3(g[6], g[7], g[8]),
		Vector3(g[9], g[10], g[11])]
	for i: int in 3:
		for k: int in 3:
			turn[i] = (turn[i] as Vector3) + Vector3(
				(rows[k] as Vector3)[i] * (theirs[k] as Vector3).x,
				(rows[k] as Vector3)[i] * (theirs[k] as Vector3).y,
				(rows[k] as Vector3)[i] * (theirs[k] as Vector3).z)
	for raw: Variant in NESTS[insert]:
		var seat: Array = raw
		if str(seat[0]) != frame:
			continue
		if local.distance_to(Vector3(seat[1], seat[2], seat[3])) > 1.01:
			continue
		# A quarter turn q about LDraw's up: cos in the corners, sin
		# off them.
		var angle: float = int(seat[4]) * PI * 0.5
		var want: Array = [Vector3(cos(angle), 0, sin(angle)),
			Vector3(0, 1, 0), Vector3(-sin(angle), 0, cos(angle))]
		var same: bool = true
		for i: int in 3:
			if not (turn[i] as Vector3).is_equal_approx(want[i] as Vector3):
				same = false
		if same:
			return true
	return false


## A section's turn from its yaw, pitch and roll in degrees, as the
## assistant turns one (Assistant.Section.turned): the Properties panel's
## tilt and roll read back the same as a section's.
static func turned(yaw_deg: float, pitch_deg: float, roll_deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg)) \
		* Basis(Vector3.RIGHT, -deg_to_rad(pitch_deg)) \
		* Basis(Vector3.BACK, deg_to_rad(roll_deg))


## The yaw, pitch and roll that make [param basis], in degrees
## (Assistant.Section.angles_of).
static func angles_of(basis: Basis) -> Vector3:
	var e: Vector3 = basis.orthonormalized().get_euler(EULER_ORDER_YXZ)
	return Vector3(rad_to_deg(e.y), -rad_to_deg(e.x), rad_to_deg(e.z))
