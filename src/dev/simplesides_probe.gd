## simplesides: in Simple no part goes down in the air, whatever face of a
## part a drop or a drag is aimed at (lead, after simple4: a 2 x 4 let go on
## a brick's side stood 16 LDU up, joined to nothing, live in rel-m352).
##
## A little scene on Simple's plate (a 2 x 4, a 2 x 4 on it, a 1 x 2 plate,
## a 2 x 2 slope, a 1 x 1 round brick), seen from four sides, high and low.
## Over each part's picture a grid of points, 7 x 7 over its box on the screen
## and a little past its edges: at each, with a 2 x 4 and then a 1 x 1 in
## hand, Simple's aim as a finger's drag aims it (SimpleLayer._aim): where it
## offers a ghost, the ghost stands on the plate or on a part under it. Every
## fourth point a 2 x 4 let go there from the tray, and every eighth a part
## of the scene dragged there by a finger: what goes down stands, then Undo.
## Counts the points aimed, the ghosts offered, the drops and drags made, and
## those in the air: a foot over the plate's face with no part under it
## there (its box over the foot's level, across its footprint). None is a
## pass; Undo gives the scene back byte for byte.
##
##   PROBE_SIZE=390x844 tools/probe.sh simplesides_probe
##   PROBE_SIZE=1280x800 tools/probe.sh simplesides_probe -- --desktop
##   tools/probe.sh simplesides_probe -- --headless-ok [--desktop]
##
## godot --path . --resolution 390x844 --script src/dev/simplesides_probe.gd
## godot --headless --path . --script src/dev/simplesides_probe.gd -- --headless-ok
## Exits non-zero when a check fails.
extends "res://src/dev/simplereview4_probe.gd"

## Where the camera looks from: [words, direction].
const VIEWS: Array = [
	["front, high", Vector3(0.3, 0.75, 1.0)],
	["right, low", Vector3(1.0, 0.18, 0.25)],
	["back, low", Vector3(-0.35, 0.2, -1.0)],
	["left, level", Vector3(-1.0, 0.06, 0.4)],
]
const GRID := 7

var _aimed_n: int = 0
var _offered_n: int = 0
var _drops: int = 0
var _drags: int = 0
var _in_air_seen: Array = []


func _run() -> void:
	if not await _start("sides"):
		return
	print("\n== sides")
	await _case_sides()
	quit(1 if _failures else 0)


func _case_sides() -> void:
	await _to_simple()
	await _fresh()
	var scene: Array = await _build_scene()
	if not _check("the scene put down in Simple (%s)" % str(scene), scene.size() == 5 and not scene.has(0)):
		return
	var text: String = _store.to_text()
	for view: Array in VIEWS:
		_camera.look_from(view[1] as Vector3)
		await _settle()
		await _sweep(str(view[0]), scene)
	_simple.call("_put_hand_away")
	await _frames(2)
	_check("points aimed over the parts' pictures (%d), ghosts offered there (%d)" % [_aimed_n, _offered_n],
		_aimed_n >= 400 and _offered_n >= 100)
	_check("drops let go there (%d), parts dragged there (%d)" % [_drops, _drags], _drops >= 20 and _drags >= 4)
	for line: String in _in_air_seen.slice(0, 12):
		_note2("  in the air: %s" % line)
	_check("none in the air: %d of %d ghosts, %d drops and %d drags" % [_in_air_seen.size(), _offered_n,
		_drops, _drags], _in_air_seen.is_empty())
	_check("every drop and drag undone: the scene as it was, byte for byte", _store.to_text() == text)


## The scene's parts by id: a red 2 x 4, a blue 2 x 4 on it, a yellow 1 x 2
## plate, a green 2 x 2 slope, a white 1 x 1 round brick.
func _build_scene() -> Array:
	var out: Array = []
	var red: int = await _drop("3001", 4, _base_point(-0.3, 0.0))
	await _seat_done()
	out.append(red)
	out.append(await _drop("3001", 1, _top_point(red)) if red != 0 else 0)
	await _seat_done()
	out.append(await _drop("3023b", 14, _base_point(0.3, -0.25)))
	await _seat_done()
	out.append(await _drop("3039", 2, _base_point(0.25, 0.3)))
	await _seat_done()
	out.append(await _drop("3062b", 15, _base_point(-0.1, -0.4)))
	await _seat_done()
	_builder.clear_selection()
	await _frames(2)
	return out


## A part of the tray let go at [param at] by Simple's own calls, in a window
## as headless (the tile's drag is not what is tried): its id, 0 for none.
func _drop(part: String, colour: int, at: Vector2) -> int:
	if int(_simple.call("chosen_colour")) != colour:
		_simple.call("_on_swatch", colour)
	_simple.call("_take", part)
	_simple.call("_drop_from_tray", at, at)
	await _frames(3)
	var put: Array = (_simple.get("last_drop") as Dictionary).get("put", [])
	return int(put[0]) if not put.is_empty() else 0


func _sweep(view: String, scene: Array) -> void:
	var seen_before: int = _in_air_seen.size()
	var aimed_before: int = _aimed_n
	var offered_before: int = _offered_n
	var room: Rect2 = root.get_visible_rect()
	var n: int = 0
	for id: int in scene:
		var rect: Rect2 = _screen_box(_box_of(id)).grow(Phone.px(root, 6.0))
		for i: int in GRID:
			for j: int in GRID:
				var at: Vector2 = rect.position + rect.size * Vector2((i + 0.5) / GRID, (j + 0.5) / GRID)
				if not room.has_point(at):
					continue
				for part: String in ["3001", "3005"]:
					_simple.call("_take", part)
					_simple.call("_aim", at)
					_aimed_n += 1
					if _builder.has_preview():
						_offered_n += 1
						var box: AABB = _simple.call("_ghost_box")
						if _in_air(box, 0):
							_in_air_seen.append("%s: the ghost of %s aimed at %s, foot %.0f at %s" % [view, part,
								str(at.round()), box.position.y, str(Vector2(box.position.x, box.position.z))])
					_builder.hide_preview()
				n += 1
				if n % 4 == 0:
					await _try_drop(view, at)
				if n % 8 == 0:
					await _try_drag(view, scene, at)
			await process_frame
	_note2("[%s] %d points aimed, %d ghosts offered, %d in the air" % [view, _aimed_n - aimed_before,
		_offered_n - offered_before, _in_air_seen.size() - seen_before])


func _try_drop(view: String, at: Vector2) -> void:
	var id: int = await _drop("3001", 14, at)
	if id == 0:
		return
	await _seat_done()
	_drops += 1
	var box: AABB = _box_of(id)
	if _in_air(box, id):
		_in_air_seen.append("%s: a 2 x 4 let go at %s, foot %.0f at %s" % [view, str(at.round()), box.position.y,
			str(Vector2(box.position.x, box.position.z))])
	await _undo_one(id)


## A part of the scene dragged by a finger to aim at [param at]: the plate,
## or whatever the finger comes down on where it is seen.
func _try_drag(view: String, scene: Array, at: Vector2) -> void:
	var from: Vector2 = _top_point(int(scene[2]))
	var finger: Vector2 = at + Vector2(0.0, Phone.px(root, float(_simple.get("lift_points"))))
	_simple.call("_press", from, 0)
	for k: int in range(1, 9):
		_simple.call("_drag", from.lerp(finger, k / 8.0))
		await process_frame
	_simple.call("_release", finger)
	await _frames(3)
	var moved: Array = (_simple.get("last_drop") as Dictionary).get("put", [])
	if moved.is_empty() or str((_simple.get("last_drop") as Dictionary).get("from", "")) != "model":
		return
	await _seat_done()
	_drags += 1
	for id: Variant in moved:
		var box: AABB = _box_of(int(id))
		if _in_air(box, int(id)):
			_in_air_seen.append("%s: part %d dragged to aim at %s, foot %.0f at %s" % [view, int(id),
				str(at.round()), box.position.y, str(Vector2(box.position.x, box.position.z))])
	await _undo_one(0)


func _undo_one(made: int) -> void:
	await _press_button("undo")
	await _frames(2)
	if made != 0 and _world.get_brick(made) != null:
		_note2("  Undo left part %d" % made)
	_builder.clear_selection()


## Whether a part of box [param box] stands in the air: its foot over the
## plate's face, and no other part (not [param skip]) across its footprint
## whose box reaches the foot's level from under it.
func _in_air(box: AABB, skip: int) -> bool:
	var face: float = _floor_box().end.y - 4.0
	var foot: float = box.position.y
	if foot <= face + 1.0:
		return false
	var inner := Rect2(box.position.x + 0.5, box.position.z + 0.5, box.size.x - 1.0, box.size.z - 1.0)
	for id: Variant in _plain_ids():
		if int(id) == skip:
			continue
		var other: AABB = _box_of(int(id))
		if not inner.intersects(Rect2(other.position.x, other.position.z, other.size.x, other.size.z)):
			continue
		if other.position.y < foot - 0.5 and other.end.y >= foot - 0.5:
			return false
	return true
