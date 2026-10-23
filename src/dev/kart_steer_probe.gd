## The kart that comes with the app, steered by Grab at its steering wheel,
## as a person steers it.
##
##   godot --path . --resolution 1280x800 --script src/dev/kart_steer_probe.gd
##
## kart195 found the kart's steering wheel spinning alone on a round brick's
## stud, joined to nothing, and its card naming a knuckle instead.
## kartlink196 built the linkage a Technic kart has: the wheel on a column
## turning in a pin with a hole across it (in a T beam on the middle cross
## member), a universal joint bent 45 degrees, a 16 tooth pinion on an axle
## in the front beam, and a 1 x 8 rack with holes that is the track rod
## between the knuckles' arms. Here:
##
##  - what the card names first for the steering is the steering wheel, on
##    its column, not a part spinning alone on its stud;
##  - pressed where it shows (GrabDrag.handle_on) and dragged round its
##    column, both front wheels turn one way, then the other way past where
##    they were built, and the back wheels never turn;
##  - at the linkage's own ratio, stage by stage: the pinion as the
##    universal joint turns it (tan of its turn = cos of the bend times tan
##    of the wheel's, the column's fork square to the bend as built), the
##    rack 8 LDU along its teeth for each tooth of the pinion's turn, and
##    each knuckle as the rack carries its arm (sin of its turn = the rack's
##    travel over the arm's 20 LDU);
##  - each drag is one undo: undone twice, every part stands where it was
##    built.
##
## Pictures from above the front, built, turned each way and put back, go to
## shots/kart_steer/.
extends SceneTree

const OUT := "res://shots/kart_steer/"
## How far the pointer takes the rim round the column, a drag.
const DRAG_DEGREES := 90.0
## The knuckles' arms, kingpin to track rod pin, LDU.
const ARM := 20.0
## How far each stage may stand from the linkage's ratio.
const ANGLE_SLACK := 0.5
const TRAVEL_SLACK := 0.15

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _grab: GrabDrag
var _store: ModelStore


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_grab = _main.get("_grab_drag")
	_store = _main.get("_store")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("── the kart steered by Grab at its steering wheel ──")
	_main.call("_open", ProjectSettings.globalize_path("res://models/kart.ldr"))
	for _n: int in 400:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(5)
	_builder.forget_history()
	_grab._ready_now()
	var bodies: Bodies = _grab.read_bodies()
	var found: Dictionary = Playable.read(bodies, _world, _library, _grab.read_mechanism())
	var named: Array = found.get("steering", [])
	_check("the kart's card says it steers, and names a part for it: %s" % str(named), not named.is_empty())
	if named.is_empty():
		_done()
		return
	var handle: int = int(named[0])
	var body: int = int(bodies.body_of[handle])
	var link: Bodies.Link = bodies.parent_link[body]
	var part_name: String = _name_of(handle)
	_check("...first its steering wheel, on its column: #%d %s, %s" % [handle, part_name, link.words()],
		part_name.contains("Steering Wheel") and link.kind == "axle")
	var wheels: Array = _of("105162")
	wheels.sort_custom(func(a: int, b: int) -> bool:
		return _world.get_brick(a).transform.origin.x > _world.get_brick(b).transform.origin.x)
	var pinions: Array = _of("4019")
	var racks: Array = _of("6630")
	_check("four wheels, a pinion and a rack: %d, %d, %d" % [wheels.size(), pinions.size(), racks.size()],
		wheels.size() == 4 and pinions.size() == 1 and racks.size() == 1)
	if wheels.size() != 4 or pinions.size() != 1 or racks.size() != 1:
		_done()
		return
	var front: Array = wheels.slice(0, 2)
	var back: Array = wheels.slice(2, 4)
	var pinion: int = pinions[0]
	var rack: int = racks[0]
	var column: Vector3 = link.axis.normalized()
	var axle: Vector3 = (_world.get_brick(pinion).transform.basis * Vector3.BACK).normalized()
	var bend: float = rad_to_deg(acos(clampf(absf(column.dot(axle)), 0.0, 1.0)))
	var line: Vector3 = (_world.get_brick(rack).transform.basis * Vector3.RIGHT).normalized()
	print("    the column stands %.1f° off the pinion's axle" % bend)
	var built: Dictionary = _snapshot()
	await _look_at_front(front)
	await _shot("1_built")

	var one: Dictionary = await _drag(body, link, handle, DRAG_DEGREES)
	var first: Dictionary = _stages(built, handle, column, pinion, axle, rack, line, front, bend)
	print("    one way: %s; %s" % [one.get("said", ""), first["said"]])
	_check("dragged one way, both front wheels turn, the same way, 5° or more",
		absf(first["wheels"][0]) >= 5.0 and absf(first["wheels"][1]) >= 5.0
		and signf(first["wheels"][0]) == signf(first["wheels"][1]))
	_check("...and the back wheels do not", _still(built, back))
	_ratio(first)
	await _shot("2_one_way")
	var first_way: float = signf(first["wheels"][0])

	var other: Dictionary = await _drag(body, link, handle, -2.0 * DRAG_DEGREES)
	var second: Dictionary = _stages(built, handle, column, pinion, axle, rack, line, front, bend)
	print("    the other way: %s; %s" % [other.get("said", ""), second["said"]])
	_check("dragged the other way, both front wheels turn past where they were built, 5° or more",
		signf(second["wheels"][0]) == -first_way and signf(second["wheels"][1]) == -first_way
		and absf(second["wheels"][0]) >= 5.0 and absf(second["wheels"][1]) >= 5.0)
	_check("...and the back wheels still do not", _still(built, back))
	_check("...the steering wheel turned the other way past where it was built",
		signf(second["wheel"]) == -signf(first["wheel"]) and absf(second["wheel"]) >= 5.0)
	_ratio(second)
	await _shot("3_other_way")

	_builder.undo()
	await _frames(5)
	_builder.undo()
	await _frames(5)
	var most: float = 0.0
	for key: Variant in built:
		var now: BrickWorld.Brick = _world.get_brick(int(key))
		if now != null:
			most = maxf(most, (built[key] as Transform3D).origin.distance_to(now.transform.origin))
			if not (built[key] as Transform3D).basis.is_equal_approx(now.transform.basis):
				most = maxf(most, 1.0)
	_check("undone twice, one undo a drag, every part where it was built (%.3f LDU at most)" % most,
		most < 0.01 and _world.brick_count() == built.size() + _store.scenery.size())
	await _shot("4_undone")
	_done()


## Where each stage of the linkage stands from where it was built: the
## steering wheel's turn on its column, the pinion's on its axle, the rack's
## travel along its teeth, each front wheel's turn about the up line, and
## each worked out from the stage before by the linkage's ratio.
func _stages(built: Dictionary, handle: int, column: Vector3, pinion: int, axle: Vector3,
		rack: int, line: Vector3, front: Array, bend: float) -> Dictionary:
	var wheel: float = _turned(built, handle, column)
	var pinion_turn: float = _turned(built, pinion, axle)
	var travel: float = ((_world.get_brick(rack).transform.origin
		- (built[rack] as Transform3D).origin)).dot(line)
	var wheels: Array = [_steered(built, front[0]), _steered(built, front[1])]
	# The universal joint: its column's fork square to the bend as built.
	var pinion_said: float = rad_to_deg(atan(cos(deg_to_rad(bend)) * tan(deg_to_rad(absf(wheel)))))
	# A tooth of the pinion's turn, a tooth of the rack's.
	var travel_said: float = absf(pinion_turn) / 360.0 * 16.0 * Racks.pitch()
	var knuckle_said: float = rad_to_deg(asin(clampf(absf(travel) / ARM, 0.0, 1.0)))
	return {"wheel": wheel, "pinion": pinion_turn, "travel": travel, "wheels": wheels,
		"pinion_said": pinion_said, "travel_said": travel_said, "knuckle_said": knuckle_said,
		"said": "the steering wheel %+.1f°, the pinion %+.1f°, the rack %+.2f LDU, the front wheels %+.1f° and %+.1f°"
			% [wheel, pinion_turn, travel, wheels[0], wheels[1]]}


## Each stage against the linkage's ratio from the stage before.
func _ratio(at: Dictionary) -> void:
	_check("...the pinion %.2f° for the wheel's %.2f° through the universal joint, %.2f° by its bend"
		% [absf(at["pinion"]), absf(at["wheel"]), at["pinion_said"]],
		absf(absf(at["pinion"]) - float(at["pinion_said"])) <= ANGLE_SLACK)
	_check("...the rack %.2f LDU for the pinion's %.2f° of 16 teeth, %.2f by 8 LDU a tooth"
		% [absf(at["travel"]), absf(at["pinion"]), at["travel_said"]],
		absf(absf(at["travel"]) - float(at["travel_said"])) <= TRAVEL_SLACK)
	var wheels: Array = at["wheels"]
	_check("...each front wheel %.2f° and %.2f° for the rack's travel on a %.0f LDU arm, %.2f° by it"
		% [absf(wheels[0]), absf(wheels[1]), ARM, at["knuckle_said"]],
		absf(absf(wheels[0]) - float(at["knuckle_said"])) <= ANGLE_SLACK
		and absf(absf(wheels[1]) - float(at["knuckle_said"])) <= ANGLE_SLACK)
	print("    the steering wheel to the front wheels: %.2f to 1" % (absf(at["wheel"])
		/ maxf(absf(wheels[0]), 0.001)))


## Pressed where [param handle] shows, the pointer taken [param degrees] round
## its column as the rim's point under it goes round, in small steps, and let
## go: {said, angle}. Round the rim and not round a circle on the page: seen
## from above the front, the column leans away, and a circle's first move
## went along its line, which the grab took for a slide.
func _drag(body: int, link: Bodies.Link, handle: int, degrees: float) -> Dictionary:
	var spot: Variant = _grab.handle_on(body, link, PackedInt64Array([handle]))
	if spot == null:
		_check("#%d shows, to take hold of" % handle, false)
		return {}
	var at: Vector2 = spot["screen"]
	var axis: Vector3 = link.axis.normalized()
	var face := Plane(axis, _world.get_brick(handle).transform.origin)
	var held: Variant = face.intersects_ray(_camera.ray_origin(at), _camera.ray_normal(at))
	if held == null:
		_check("the steering wheel's face is under the pointer", false)
		return {}
	var middle: Vector3 = link.point + axis * ((held as Vector3) - link.point).dot(axis)
	if not _grab.press(int(spot["id"]), at):
		_check("a press on #%d takes hold of it: %s" % [int(spot["id"]), _grab.last_words], false)
		return {}
	var grab: Grab = _grab.grab
	for n: int in range(1, 13):
		var round: Vector3 = ((held as Vector3) - middle).rotated(axis, deg_to_rad(degrees) * n / 12.0)
		_grab.motion(_camera.unproject_position(middle + round))
		await _frames(2)
	while grab.unchecked:
		grab.verify_step()
	var angle: float = grab.angle
	var said: String = _grab.release()
	for _n: int in 600:
		await process_frame
		if not _grab.is_grabbing() and not _grab.is_settling():
			break
	await _frames(5)
	return {"said": "%s, turned %.1f°" % [said.left(60), angle], "angle": angle}


## How far brick [param id] stands turned about [param way] from where it
## stood in [param from], degrees, signed.
func _turned(from: Dictionary, id: int, way: Vector3) -> float:
	var turn: Basis = _world.get_brick(id).transform.basis * (from[id] as Transform3D).basis.inverse()
	var q := Quaternion(turn.orthonormalized())
	var angle: float = rad_to_deg(q.get_angle())
	return angle * signf(q.get_axis().dot(way)) if angle > 0.01 else 0.0


## How far brick [param id] stands turned about the up line, degrees, signed.
func _steered(from: Dictionary, id: int) -> float:
	return _turned(from, id, Vector3.UP)


func _still(from: Dictionary, ids: Array) -> bool:
	for id: int in ids:
		if not (from[id] as Transform3D).is_equal_approx(_world.get_brick(id).transform):
			return false
	return true


func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out[brick.id] = brick.transform
	return out


func _of(part: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			out.append(brick.id)
	return out


func _name_of(id: int) -> String:
	var info: PartLibrary.PartInfo = _library.parts.get(_world.get_brick(id).part_id)
	return info.name if info != null else _world.get_brick(id).part_id


## The whole kart in view, from above its front: its front the way from the
## middle of the model to its front wheels.
func _look_at_front(front: Array) -> void:
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in _world.bricks():
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		if info == null or _store.scenery.has(brick.id):
			continue
		var here: AABB = brick.transform * info.bounds
		box = here if first else box.merge(here)
		first = false
	var ahead: Vector3 = ((_world.get_brick(front[0]).transform.origin
		+ _world.get_brick(front[1]).transform.origin) * 0.5 - box.get_center())
	ahead.y = 0.0
	_camera.frame(box, 1.1)
	_camera.look_from(ahead.normalized() * 0.8 + Vector3.UP * 1.1 + ahead.normalized().cross(Vector3.UP) * 0.35)
	var was: Transform3D = _camera.global_transform
	var still: int = 0
	for _n: int in 600:
		await process_frame
		still = still + 1 if _camera.global_transform.is_equal_approx(was) else 0
		was = _camera.global_transform
		if still >= 10:
			break


func _shot(when: String) -> void:
	var mark: Node3D = _grab.get("_mark")
	var was: bool = mark != null and mark.visible
	if mark != null:
		mark.visible = false
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path: String = OUT.path_join("kart_%s.png" % when)
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % ProjectSettings.globalize_path(path))
	if mark != null:
		mark.visible = was


func _done() -> void:
	print("")
	if _failures == 0:
		print("kart steer: the kart's steering wheel turns both front wheels each way, at its linkage's ratio")
	else:
		print("kart steer: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
