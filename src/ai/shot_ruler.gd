## Studs written on the picture, so a position can be read off it.
##
## A render shows a designer what it has built and gives it no way to say
## where anything is. It can see that the nacelle sits too far forward
## and has to guess by how much, in a unit the picture does not carry —
## so it guesses, places, checks, and guesses again.
##
## The fix is the oldest one in drawing: put a ruler on it. Two lines
## along the model's near corner, ticked and numbered in studs, drawn by
## projecting world positions through the same camera that took the
## picture, so a number on the image is the number to write in a
## placement.
##
## Taken from Brick-Composer (arXiv 2606.05445), which renders its
## assembly states with coordinate ticks for the same reason and found
## it among the things that most improved placement.
class_name ShotRuler
extends Control

## Studs between ticks. Every stud on a sixty stud ship is a smear.
const STEPS: Array[int] = [1, 2, 5, 10, 20, 50, 100]
## About this many ticks on a side, whatever the model's size.
const WANTED := 8

var camera: Camera3D = null
## The model's bounds in LDU, as the shot framed it.
var bounds: AABB = AABB()
## LDU per stud and per plate, so this file needs no lattice.
const STUD := 20.0

var _ink := Color(0.22, 0.25, 0.30, 0.85)
var _pale := Color(0.22, 0.25, 0.30, 0.35)


func _draw() -> void:
	if camera == null or bounds.size.length() <= 0.0:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var size: int = 20

	# Along the bottom of the model, at its near corner, so the rulers
	# lie on the ground beside it rather than across it.
	var low: Vector3 = bounds.position
	var high: Vector3 = bounds.position + bounds.size
	# One spacing for both axes, from the longer of them. Ticking x
	# every five and z every two reads as two different rulers and
	# invites the numbers to be compared as if they were the same.
	var step: int = _step_for(ceili(maxf(
		bounds.size.x, bounds.size.z) / STUD))
	_rule(font, size, Vector3(low.x, low.y, low.z),
		Vector3(high.x, low.y, low.z), 0, "x", step)
	_rule(font, size, Vector3(low.x, low.y, low.z),
		Vector3(low.x, low.y, high.z), 2, "z", step)


## One ruler, from one corner of the base to another.
func _rule(font: Font, size: int, from: Vector3, to: Vector3,
		axis: int, named: String, step: int) -> void:
	var first: int = floori(from[axis] / STUD)
	var last: int = ceili(to[axis] / STUD)
	if last <= first:
		return

	var a: Vector2 = camera.unproject_position(from)
	var b: Vector2 = camera.unproject_position(to)
	if not _on_screen(a) and not _on_screen(b):
		return
	draw_line(a, b, _pale, 1.5, true)

	# The axis named once, at the far end, so the numbers are not
	# ambiguous on an isometric view where x and z both run diagonally.
	draw_string(font, b + Vector2(6, 6), named,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size + 2, _ink)

	var at: int = int(floor(float(first) / step)) * step
	while at <= last:
		if at >= first:
			var point: Vector3 = from
			point[axis] = float(at) * STUD
			var screen: Vector2 = camera.unproject_position(point)
			if _on_screen(screen):
				draw_line(screen + Vector2(0, -4), screen + Vector2(0, 4),
					_ink, 1.5, true)
				draw_string(font, screen + Vector2(-10, 20), str(at),
					HORIZONTAL_ALIGNMENT_LEFT, -1, size, _ink)
		at += step


## A tick spacing that gives about eight of them.
static func _step_for(studs: int) -> int:
	for step: int in STEPS:
		if studs / step <= WANTED:
			return step
	return STEPS[STEPS.size() - 1]


func _on_screen(at: Vector2) -> bool:
	# Generous, because a tick a little outside is still worth drawing
	# the line to.
	return at.x > -200.0 and at.y > -200.0 \
		and at.x < size.x + 200.0 and at.y < size.y + 200.0
