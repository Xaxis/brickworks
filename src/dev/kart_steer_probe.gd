## The kart that comes with the app, steered by Grab as a person steers it.
##
##   godot --path . --resolution 1280x800 --script src/dev/kart_steer_probe.gd
##
## models175 seated the kart's steering wheel on its round brick's stud, and
## its card then named the wheel for the steering: turned, it spun alone on
## its stud and no front wheel turned (mcp_walk_probe, kart195). The wheel
## was never joined to the knuckles, so the card names a knuckle again, as
## it did before (Playable.read). Here:
##
##  - what the card names for the steering is not a part spinning alone on
##    its stud;
##  - pressed where it shows (GrabDrag.handle_on) and dragged round its
##    joint, both front wheels turn one way, then the other way past where
##    they were built, and the back wheels never turn;
##  - each drag is one undo: undone twice, every part stands where it was
##    built.
##
## Pictures from above the front, built, turned each way and put back, go to
## shots/kart_steer/.
extends SceneTree

const OUT := "res://shots/kart_steer/"
## How far the pointer goes round the joint's middle on the screen, a drag.
const DRAG_DEGREES := 50.0

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
	print("── the kart steered by Grab ──")
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
	_check("...not a part spinning alone on its stud: #%d %s, %s" % [handle, part_name, link.words()],
		not (link.kind == "stud" and (bodies.members[body] as PackedInt64Array).size() == 1))
	var wheels: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "105162":
			wheels.append(brick.id)
	# The front wheels hang on the knuckles the card names: the two nearest them.
	var knuckles: Array = named
	var near_knuckle := func(id: int) -> float:
		var at: Vector3 = _world.get_brick(id).transform.origin
		var least: float = INF
		for knuckle: int in knuckles:
			least = minf(least, at.distance_to(_world.get_brick(knuckle).transform.origin))
		return least
	wheels.sort_custom(func(a: int, b: int) -> bool: return near_knuckle.call(a) < near_knuckle.call(b))
	_check("four wheels and two knuckles: %d, %d" % [wheels.size(), knuckles.size()],
		wheels.size() == 4 and knuckles.size() == 2)
	if wheels.size() != 4 or knuckles.size() != 2:
		_done()
		return
	var front: Array = wheels.slice(0, 2)
	var back: Array = wheels.slice(2, 4)
	var built: Dictionary = _snapshot()
	await _look_at_front(knuckles)
	await _shot("1_built")

	var one: Dictionary = await _drag(body, link, handle, DRAG_DEGREES)
	var turned: Array = [_steered(built, front[0]), _steered(built, front[1])]
	print("    one way: %s; the front wheels %+.1f° and %+.1f°, the back %+.1f° and %+.1f°" % [
		one.get("said", ""), turned[0], turned[1], _steered(built, back[0]), _steered(built, back[1])])
	_check("dragged one way, both front wheels turn, the same way, 5° or more",
		absf(turned[0]) >= 5.0 and absf(turned[1]) >= 5.0 and signf(turned[0]) == signf(turned[1]))
	_check("...and the back wheels do not", _still(built, back))
	await _shot("2_one_way")
	var first_way: float = signf(turned[0])

	var other: Dictionary = await _drag(body, link, handle, -2.0 * DRAG_DEGREES)
	var back_turned: Array = [_steered(built, front[0]), _steered(built, front[1])]
	print("    the other way: %s; the front wheels %+.1f° and %+.1f°" % [other.get("said", ""),
		back_turned[0], back_turned[1]])
	_check("dragged the other way, both front wheels turn past where they were built, 5° or more",
		signf(back_turned[0]) == -first_way and signf(back_turned[1]) == -first_way
		and absf(back_turned[0]) >= 5.0 and absf(back_turned[1]) >= 5.0)
	_check("...and the back wheels still do not", _still(built, back))
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


## Pressed where [param handle] shows, the pointer taken [param degrees] round
## its joint's middle on the screen in small steps, and let go:
## {said, angle}.
func _drag(body: int, link: Bodies.Link, handle: int, degrees: float) -> Dictionary:
	var spot: Variant = _grab.handle_on(body, link, PackedInt64Array([handle]))
	if spot == null:
		_check("#%d shows, to take hold of" % handle, false)
		return {}
	var at: Vector2 = spot["screen"]
	var pivot: Vector2 = spot.get("pivot", at + Vector2(0, 30))
	var off: Vector2 = at - pivot
	if off.length() < 12.0:
		off = Vector2(0, -30)
	if not _grab.press(int(spot["id"]), at):
		_check("a press on #%d takes hold of it: %s" % [int(spot["id"]), _grab.last_words], false)
		return {}
	var grab: Grab = _grab.grab
	for n: int in range(1, 13):
		_grab.motion(pivot + off.rotated(deg_to_rad(degrees) * n / 12.0))
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


## How far brick [param id] stands turned about the up line from where it
## stood in [param from], degrees, signed.
func _steered(from: Dictionary, id: int) -> float:
	var turn: Basis = _world.get_brick(id).transform.basis * (from[id] as Transform3D).basis.inverse()
	var q := Quaternion(turn.orthonormalized())
	var angle: float = rad_to_deg(q.get_angle())
	return angle * signf(q.get_axis().y) if angle > 0.01 else 0.0


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


func _name_of(id: int) -> String:
	var info: PartLibrary.PartInfo = _library.parts.get(_world.get_brick(id).part_id)
	return info.name if info != null else _world.get_brick(id).part_id


## The whole kart in view, from above its front: its front the way from the
## middle of the model to its knuckles.
func _look_at_front(knuckles: Array) -> void:
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in _world.bricks():
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		if info == null or _store.scenery.has(brick.id):
			continue
		var here: AABB = brick.transform * info.bounds
		box = here if first else box.merge(here)
		first = false
	var ahead: Vector3 = ((_world.get_brick(knuckles[0]).transform.origin
		+ _world.get_brick(knuckles[1]).transform.origin) * 0.5 - box.get_center())
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
		print("kart steer: the kart's card names a part that steers it, and Grab turns both front wheels each way")
	else:
		print("kart steer: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
