## A part put down by the floor never moves the model, and two gears on a
## Technic brick standing on the floor turn each other by hand.
##
##   godot --headless --path . --script src/dev/floor_gears_probe.gd
##
## In a window (godot --path . --resolution 1400x900 --script
## src/dev/floor_gears_probe.gd) with FLOOR_GEARS_OUT=DIR, pictures of the
## gears as put down and as turned go there.
##
## walk239 (2026-10-24, A14 and A6): a 24 on an axle in a Technic brick on
## the baseplate reaches 18 LDU below the floor. Put down, the whole model
## rose 18 LDU to stand on it (Builder._stand_on_the_ground): the brick came
## off the baseplate's studs, the build was a loose body standing on its
## gear, the first drag on the gear carried it ("no room there") and the
## second tipped the whole build onto its end. Here, in the app with its
## floor, as a person does it: a Technic brick 1 x 8 on the floor, two axles
## pointed into its holes three studs apart and a 24 pointed onto each
## (Builder.update_preview, place). Every part put down stays where it went,
## nothing else moves, and no part says the model rose; one undo takes the
## last gear off and nothing else. Then the first gear is pressed as a drag
## presses it (GrabDrag.press): it is grabbed on its axle, not carried, and
## turned 30 degrees it turns the other 30 the other way.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _drag: GrabDrag
var _camera: CadCamera
## What the status line said.
var _heard: Array = []
## How far the model rose as parts were put down, and what each put said.
var _rose: float = 0.0
var _said: String = ""
## The floor's top: a brick standing on it has its origin a brick up.
const BRICK := 24.0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	Engine.max_fps = 0
	CustomParts.keeps = false
	CustomParts.dir = "user://floor_gears_probe_parts/"
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_drag = _main.get("_grab_drag")
	_camera = _main.get("_camera")
	(_main.get("_bar") as ModelBar).said.connect(func(words: String) -> void: _heard.append(words))
	_main.call("clear_model")
	await _quiet()
	print("  the floor: %d part(s) of scenery" % _store.scenery.size())
	_check("the model stands on a baseplate floor", not _store.scenery.is_empty())

	# The brick on the floor, its holes front to back 10 LDU under its top.
	# On the baseplate's studs: a stud wide, its middle half a stud off zero.
	var brick: int = _builder.put_part("3702", 19, Transform3D(Basis.IDENTITY, Vector3(0, BRICK, 10)))
	var hole_y: float = BRICK - 10.0
	var axles: Array = [_point("3706", Vector3(-20, hole_y, 10)), _point("3706", Vector3(40, hole_y, 10))]
	var kept: Dictionary = _where_all()
	var first: int = _point("3648b", Vector3(-20, hole_y, 40))
	var along: float = _world.get_brick(first).transform.origin.z if first != 0 else 30.0
	var second: int = _point("3648b", Vector3(40, hole_y, along))
	var said: String = _builder.joint_words()
	_check("the brick, both axles and both 24s go down by pointing (%s)" % [[brick, axles, first, second]],
		brick != 0 and not axles.has(0) and first != 0 and second != 0)
	if first == 0 or second == 0:
		_end()
		return
	var low: float = _lowest(second)
	_check("the second 24 reaches below the floor where it went (its lowest at %.1f LDU)" % low,
		low < -10.0)
	var moved: Array = []
	for id: int in kept:
		if _world.get_brick(id) == null or not (_world.get_brick(id).transform as Transform3D) \
				.is_equal_approx(kept[id]):
			moved.append(id)
	_check("putting the 24s down moved nothing else: %d of %d parts moved (the brick at %s)" % [
		moved.size(), kept.size(), _world.get_brick(brick).transform.origin],
		moved.is_empty() and _world.get_brick(brick).transform.origin.is_equal_approx(
			Vector3(0, BRICK, 10)))
	_check("nothing says the model rose (%s)" % _said, not _said.contains("rose") and _rose == 0.0)
	_check("the two 24s mesh (%s)" % said, said.contains("in mesh"))
	var below: Array = _heard.filter(func(words: String) -> bool: return words.contains("floor") \
		or words.contains("rose"))
	_check("the status line says how far below the floor it reaches, and that the model stays (%s)"
		% [below], not below.is_empty() and str(below.back()).contains("18 LDU below the floor")
		and str(below.back()).contains("stays"))

	# One undo takes the gear off, and only the gear.
	_builder.undo()
	await _frames(2)
	var after_undo: Array = []
	for id: int in kept:
		if _world.get_brick(id) == null or not (_world.get_brick(id).transform as Transform3D) \
				.is_equal_approx(kept[id]):
			after_undo.append(id)
	_check("one undo takes the second 24 off and leaves the rest where it was (%d moved)" % after_undo.size(),
		_world.get_brick(second) == null and after_undo.is_empty())
	_builder.redo()
	await _frames(2)
	second = 0
	for one: BrickWorld.Brick in _world.bricks():
		if one.part_id == "3648b" and absf(one.transform.origin.x - 40.0) < 1.0:
			second = one.id
	_check("...and redo puts it back", second != 0)
	if second == 0:
		_end()
		return

	# Pressed as a drag presses it: grabbed on its axle, then turned.
	_camera.frame(AABB(Vector3(-80, -20, -40), Vector3(160, 60, 120)))
	await _frames(4)
	var centre: Vector3 = _world.get_brick(first).transform.origin
	var screen: Vector2 = _camera.unproject_position(centre + Vector3(0, 0, 4))
	var pressed: bool = _drag.press(first, screen)
	var grab: Grab = _drag.grab
	_check("a press on the first 24 grabs it on its axle, not carries it (%s)" % [
		"grabbed" if grab != null else "not grabbed: %s" % _drag.last_words],
		pressed and grab != null and grab.moving.has(first) and not grab.moving.has(brick))
	if grab == null:
		_end()
		return
	await _shot("1_put_down")
	grab.turn_to(30.0)
	var about: Vector3 = _axis_of(grab, first)
	var driver: float = _turned(grab, first, about)
	var driven: float = _turned(grab, second, about)
	_check("turned %.1f degrees, the second 24 turns %.1f the other way, the brick staying" % [
		driver, driven], absf(driver) > 29.9 and absf(absf(driven) - absf(driver)) < 0.05
		and driver * driven < 0.0 and not grab.moving.has(brick))
	_world.set_drawn(grab.drawn())
	await _shot("2_turned")
	_world.set_drawn({})
	_end()


## In a window with FLOOR_GEARS_OUT set, a picture of the view there.
func _shot(name: String) -> void:
	var out: String = OS.get_environment("FLOOR_GEARS_OUT")
	if out.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("    picture: %s" % out.path_join(name + ".png"))


func _end() -> void:
	print("")
	print("floor_gears: %s" % ("all checks passed" if _failures == 0
		else "%d check(s) FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## Aim [param part_id] at [param at] from in front and above, and put it
## down where its ghost is: the brick id, or 0.
func _point(part_id: String, at: Vector3) -> int:
	_builder.held_part = part_id
	_builder.held_color = 72 if Mechanism.spec_of(part_id).is_empty() else 322
	var side := Vector3(0, 0, 1)
	var from: Vector3 = at + side * 300.0 + Vector3(0, 120, 0) + side.cross(Vector3.UP) * 30.0
	_builder.update_preview(from, (at - from).normalized())
	var shown: Transform3D = _builder.ghost_transform()
	var id: int = _builder.place()
	# Builder.risen until walk239's fix, gone since.
	var rose: Variant = _builder.get("risen")
	_rose += float(rose) if rose != null else 0.0
	_said += _builder.history_words(1)[0] + "; " if id != 0 else ""
	print("    %s pointed at %s: %s (ghost at %s), %s" % [part_id, at,
		"put down at %s" % _world.get_brick(id).transform.origin if id != 0 else "NOT put down",
		shown.origin, _builder.joint_words()])
	return id


func _where_all() -> Dictionary:
	var out: Dictionary = {}
	for one: BrickWorld.Brick in _world.bricks():
		out[one.id] = one.transform
	return out


func _lowest(id: int) -> float:
	var one: BrickWorld.Brick = _world.get_brick(id)
	return (_main.get("_library") as PartLibrary).mesh_for(one.part_id).lowest_at(one.transform)


func _axis_of(grab: Grab, key: int) -> Vector3:
	var rest: Transform3D = grab.rest.get(key, _world.get_brick(key).transform)
	var spec: Dictionary = Mechanism.spec_of(_world.get_brick(key).part_id)
	return (rest.basis * Mechanism._axis_of(spec.get("axis", "z"))).normalized()


func _turned(grab: Grab, key: int, axis: Vector3) -> float:
	if not grab.placed.has(key) or not grab.rest.has(key):
		return 0.0
	var rest: Transform3D = grab.rest[key]
	var turn: Basis = (grab.placed[key] as Transform3D).basis * rest.basis.inverse()
	var across: Vector3 = (Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).cross(axis).normalized()
	var to: Vector3 = turn * across
	return rad_to_deg(atan2(axis.dot(across.cross(to)), across.dot(to)))


func _quiet() -> void:
	var calm: int = 0
	for _n: int in 600:
		var t0: int = Time.get_ticks_usec()
		await process_frame
		if Working.is_busy() or Time.get_ticks_usec() - t0 > 50000:
			calm = 0
		else:
			calm += 1
		if calm >= 10:
			return


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
