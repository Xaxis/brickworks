## Two gears put down by hand mesh, and turning one turns the other by
## their teeth.
##
##   godot --headless --path . --script src/dev/gear_mesh_probe.gd
##
## walk180 (2026-10-23, item 3): two 24s on axles three studs apart, each
## pointed onto its axle, went on a stud apart in depth. Sliding one into
## line was refused ("2 parts on its axle: not moved"), turning one did not
## turn the other, and nothing said why. Here each pair is built in the
## editor's own placing path: the frame put down and locked, each axle
## pointed into its hole and each gear pointed onto its axle, the second
## half a stud or more from where it meshes (Builder.update_preview, place).
## Grab then turns the first gear 30° as a drag turns it, and the second
## must stand turned by the tooth counts: spur gears of 8, 12, 16, 20, 24, 36
## and 40 side by side, bevels of 12 and 20 at right angles, a worm and a 24,
## and a 24 on an axle in a crossblock. Then pairs that cannot mesh must say
## why (too far apart, square spurs, a part in the way), and a 24 put down
## out of line must slide along its axle into mesh and turn its partner.
##
## In a window (godot --path . --resolution 1400x900 --script
## src/dev/gear_mesh_probe.gd) it builds in the app itself, and pictures of
## each pair as built and turned go to the folder GEAR_MESH_OUT names
## (bench/results/gears186 by default).
extends SceneTree

var OUT: String = OS.get_environment("GEAR_MESH_OUT") if OS.has_environment("GEAR_MESH_OUT") \
	else "/mnt/Projects/brickworks/bench/results/gears186"

## The frames, as [part, Transform3D] each, put down and locked.
const UP := 72.0
## Each pair: [name, frame, [axle part, the hole aimed at, the way the pointer
## comes from], the same for the second axle, [gear, a point on its axle it is
## aimed at], the same for the second, the second's turn for the first's,
## whether it turns the other way]. The first gear is turned, but a worm,
## put down first, is turned however it is listed.
var PAIRS: Array = [
	["an 8 and a 24", "line", ["3706", Vector3(0, 62, 0)], ["3706", Vector3(40, 62, 0)],
		["3647", Vector3(0, 62, 30)], ["3648b", Vector3(40, 62, 46)], 8.0 / 24.0, true],
	["a 24 and a 24, three studs apart as walk180 built them", "line", ["3706", Vector3(-20, 62, 0)],
		["3706", Vector3(40, 62, 0)], ["3648b", Vector3(-20, 62, 30)], ["3648b", Vector3(40, 62, 50)],
		1.0, true],
	["a 16 and a 16", "line", ["3706", Vector3(0, 62, 0)], ["3706", Vector3(40, 62, 0)],
		["4019", Vector3(0, 62, 30)], ["4019", Vector3(40, 62, 14)], 1.0, true],
	["a 12 and a 20", "line", ["3706", Vector3(0, 62, 0)], ["3706", Vector3(40, 62, 0)],
		["69778", Vector3(0, 62, 30)], ["69779", Vector3(40, 62, 50)], 12.0 / 20.0, true],
	["a 36 double bevel and a 12 double bevel", "line", ["3706", Vector3(0, 62, 0)],
		["3706", Vector3(60, 62, 0)], ["32498", Vector3(0, 62, 30)], ["32270", Vector3(60, 62, 52)],
		3.0, true],
	["a 40 and an 8", "line", ["3706", Vector3(0, 62, 0)], ["3706", Vector3(60, 62, 0)],
		["3649", Vector3(0, 62, 30)], ["3647", Vector3(60, 62, 12)], 5.0, true],
	["a 12 bevel and a 12 bevel at right angles", "square", ["4519", Vector3(-20, 62, 0)],
		["3705", Vector3(-90, 62, 60), Vector3(1, 0, 0)], ["6589", Vector3(-20, 62, 36)],
		["6589", Vector3(-30, 62, 60)], 1.0, false],
	["a 20 bevel and a 12 bevel at right angles", "square", ["4519", Vector3(-20, 62, 0)],
		["3705", Vector3(-90, 62, 60), Vector3(1, 0, 0)], ["32198a", Vector3(-20, 62, 34)],
		["6589", Vector3(-40, 62, 60)], 20.0 / 12.0, false],
	["a 12 double bevel and a 20 double bevel at right angles", "square", ["4519", Vector3(-20, 62, 0)],
		["3705", Vector3(-90, 62, 60), Vector3(1, 0, 0)], ["32270", Vector3(-20, 62, 24)],
		["32269", Vector3(-36, 62, 60)], 12.0 / 20.0, false],
	["a worm and a 24", "worm", ["3706", Vector3(-20, 62, 0)],
		["3706", Vector3(-90, 102, 60), Vector3(1, 0, 0)], ["4716", Vector3(-6, 102, 60)],
		["3648b", Vector3(-20, 62, 52)], 1.0 / 24.0, false],
	["a 24 on an axle in a crossblock, and a 24", "crossblock", ["3706", Vector3(0, 62, 0)],
		["3706", Vector3(0, 122, 40)], ["3648b", Vector3(0, 62, 66)], ["3648b", Vector3(0, 122, 80)],
		1.0, true],
]

var _failures: int = 0
var _passed: int = 0
var _main: Node = null
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _drag: GrabDrag
var _camera: CadCamera = null
var _windowed: bool = false


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if ok:
		_passed += 1
	else:
		_failures += 1


func _run() -> void:
	await process_frame
	_windowed = DisplayServer.get_name() != "headless"
	if _windowed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		DirAccess.make_dir_recursive_absolute(OUT)
		_main = load("res://src/main.tscn").instantiate()
		root.add_child(_main)
		for _n: int in 120:
			await process_frame
		var playback: Node = _main.get("_playback")
		if playback != null:
			playback.call("stop")
		_world = _main.get("_world")
		_builder = _main.get("_builder")
		_library = _main.get("_library")
		_drag = _main.get("_grab_drag")
		_camera = _main.get("_camera")
	else:
		_library = PartLibrary.new()
		if not _library.load_catalogue():
			print("gear_mesh: SKIPPED, no catalogue")
			quit(3)
			return
		_world = BrickWorld.new()
		_world.library = _library
		root.add_child(_world)
		_builder = Builder.new()
		_builder.world = _world
		_builder.library = _library
		root.add_child(_builder)
		_drag = GrabDrag.new()
		_drag.world = _world
		_drag.builder = _builder
		_drag.library = _library
		root.add_child(_drag)
	await process_frame
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
	for pair: Array in PAIRS:
		if only.is_empty() or str(pair[0]).contains(only):
			await _pair(pair)
	if only.is_empty() or only == "why":
		await _why_not()
	if only.is_empty() or only == "slide":
		await _slide_into_mesh()
	print("")
	print("gear_mesh: %s" % ("all %d checks passed" % _passed if _failures == 0
		else "%d of %d checks FAILED" % [_failures, _failures + _passed]))
	quit(1 if _failures > 0 else 0)


# -- building by hand ------------------------------------------------------------


func _clear() -> void:
	if _main != null:
		_main.call("clear_model")
	else:
		_world.clear()
		_builder.lattice.clear()
	_builder.locked.clear()
	await process_frame


## The frame a pair stands in, put down and locked so it stays: a Technic
## brick 1 x 8 whose holes run front to back at y 62 ("line"); with a
## second, turned square, its holes running across at z 20 to 140 ("square",
## at y 62; "worm", 40 higher); or with a crossblock on a locked axle, its pin
## hole at (0, 122, 40) running front to back, three studs above the
## brick's middle hole ("crossblock").
func _frame(kind: String) -> void:
	var parts: Array = [["3702", Transform3D(Basis.IDENTITY, Vector3(0, UP, 0))]]
	var across := Basis(Vector3.UP, PI * 0.5)
	match kind:
		"square":
			parts.append(["3702", Transform3D(across, Vector3(-90, UP, 80))])
		"worm":
			parts.append(["3702", Transform3D(across, Vector3(-90, UP + 40.0, 80))])
		"crossblock":
			# Its axle hole on a locked axle along x at y 102, its pin hole 20
			# above, front to back.
			var flip := Basis(Vector3.RIGHT, PI)
			parts.append(["3705", Transform3D(Basis.IDENTITY, Vector3(0, 102, 40))])
			parts.append(["6536", Transform3D(flip, Vector3(0, 102, 40))])
	for one: Array in parts:
		var id: int = _builder.put_part(str(one[0]), 71, one[1])
		_builder.locked[id] = true


## Aim the part [param part_id] in hand at [param at] from in front and above
## (or from [param side], a way out from it), and put it down where its
## ghost is. 0 when it would not go down.
func _point(part_id: String, at: Vector3, side: Vector3 = Vector3(0, 0, 1)) -> int:
	_builder.held_part = part_id
	_builder.held_color = 72 if Mechanism.spec_of(part_id).is_empty() else 71
	var from: Vector3 = at + side.normalized() * 300.0 + Vector3(0, 120, 0) \
		+ side.cross(Vector3.UP).normalized() * 30.0
	_builder.update_preview(from, (at - from).normalized())
	var said: String = _builder.joint_words()
	_said_last = said
	var id: int = _builder.place()
	print("    %s pointed at %s: %s, %s" % [part_id, at, "put down at %s" % _world.get_brick(id).transform.origin
		if id != 0 else "NOT put down", said])
	return id


func _pair(pair: Array) -> void:
	var name: String = pair[0]
	print("\n%s" % name)
	await _clear()
	_frame(pair[1])
	var axles: Array = []
	for n: int in [2, 3]:
		var aim: Array = pair[n]
		axles.append(_point(aim[0], aim[1], aim[2] if aim.size() > 2 else Vector3(0, 0, 1)))
	var first: int = _point(pair[4][0], pair[4][1])
	var second: int = _point(pair[5][0], pair[5][1])
	var second_words: String = _said_last
	_check("%s: both axles and both gears go down by pointing" % name,
		not axles.has(0) and first != 0 and second != 0)
	if first == 0 or second == 0:
		return
	if not _meshed(first, second):
		# Square gears: the second seats where it meshes, and says the
		# first must be slid along its axle to where it meshes; slid there,
		# it stops in mesh.
		print("    the second says: %s" % second_words)
		await _slide(name, first, second)
	_check("%s: the two mesh" % name, _meshed(first, second))
	await _turn(name, first, second, float(pair[6]), bool(pair[7]))


## Whether the gear reading finds [param one] and [param other] in mesh.
func _meshed(one: int, other: int) -> bool:
	_drag._ready_now()
	if _drag._mechanism == null:
		return false
	for coupling: Mechanism.Coupling in _drag._mechanism.couplings:
		if coupling.one.key in [one, other] and coupling.other.key in [one, other]:
			return true
	return false


## Grab [param key] and drag it along its axle, a step at a time, to where it
## meshes [param partner] and a little past: it stops in mesh.
func _slide(name: String, key: int, partner: int) -> float:
	var grab: Grab = _new_grab()
	grab.begin(key, _world.get_brick(key).transform.origin)
	var place: Variant = grab.get("mesh_places")
	grab.use_slide()
	place = grab.get("mesh_places")
	if place == null or (place as Array).is_empty():
		_check("%s: dragged along its axle, the first gear finds where it meshes (%s)" % [name,
			"nothing" if place == null else "none"], false)
		return NAN
	var target: float = float((place as Array)[0][0])
	var shift: float = 0.0
	for n: int in range(1, 11):
		shift = grab.slide_to(target * n / 10.0 + signf(target) * 1.5)
	grab.commit(grab.step_words())
	print("    slid: %s" % grab.step_words())
	return shift


func _new_grab() -> Grab:
	_drag._ready_now()
	var grab := Grab.new()
	grab.world = _world
	grab.builder = _builder
	grab.library = _library
	grab.bodies = _drag._bodies
	grab.shared_mechanism = _drag._mechanism
	return grab


## Grab [param first] and turn it 30° as a drag turns it: [param second]
## turns [param ratio] as far, the other way when [param opposite].
func _turn(name: String, first: int, second: int, ratio: float, opposite: bool) -> void:
	if _world.get_brick(second).part_id == "4716":
		# A gear cannot turn its worm: the worm is turned.
		var worm: int = second
		second = first
		first = worm
	var grab: Grab = _new_grab()
	var state: String = grab.begin(first, _world.get_brick(first).transform.origin)
	if state != "moves":
		_check("%s: the first gear turns on its axle (%s: %s)" % [name, state, grab.why], false)
		return
	if _windowed:
		await _shot(name, "1_built")
	grab.turn_to(30.0)
	# Both about the driver's axis, as the eye sees them turn: a gear may
	# be put on its axle either way round.
	var about: Vector3 = _axis_of(grab, first)
	var driven_about: Vector3 = _axis_of(grab, second)
	if absf(about.dot(driven_about)) > 0.99:
		driven_about = about
	var driver: float = _turned(grab, first, about)
	var turned: float = _turned(grab, second, driven_about)
	if OS.has_environment("GEAR_MESH_DEBUG"):
		print("    DEBUG rest %s\n    placed %s\n    driver rest %s placed %s; mechanism %s" % [grab.rest.get(second), grab.placed.get(second),
			grab.rest.get(first), grab.placed.get(first), grab.mechanism.describe() if grab.mechanism != null else "none"])
	var wanted: float = absf(driver) * ratio
	var words: Variant = grab.get("mesh_words")
	_check("%s: turned %.1f°, the second turns %.3f° for %s%.3f° (%s)%s" % [name, driver, turned,
		"-" if opposite else "±", wanted, "coupled" if grab.coupled.has(second) else "NOT coupled",
		"" if words == null or str(words).is_empty() else "; " + str(words)],
		grab.coupled.has(second) and absf(driver) > 29.9 and absf(absf(turned) - wanted) < 0.05
		and (not opposite or turned * driver < 0.0))
	if _windowed:
		_world.set_drawn(grab.drawn())
		await _shot(name, "2_turned")
		_world.set_drawn({})


## [param key]'s gear axis where it stood when grabbed.
func _axis_of(grab: Grab, key: int) -> Vector3:
	var rest: Transform3D = grab.rest.get(key, _world.get_brick(key).transform)
	var spec: Dictionary = Mechanism.spec_of(_world.get_brick(key).part_id)
	return (rest.basis * Mechanism._axis_of(spec.get("axis", "z"))).normalized()


## How far [param key] stands turned about [param axis] in [param grab]'s
## pose, degrees.
func _turned(grab: Grab, key: int, axis: Vector3) -> float:
	if not grab.placed.has(key) or not grab.rest.has(key):
		return 0.0
	var rest: Transform3D = grab.rest[key]
	var turn: Basis = (grab.placed[key] as Transform3D).basis * rest.basis.inverse()
	var across: Vector3 = (Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).cross(axis).normalized()
	var to: Vector3 = turn * across
	return rad_to_deg(atan2(axis.dot(across.cross(to)), across.dot(to)))


# -- when they cannot mesh ----------------------------------------------------------


## Pairs that cannot mesh say why, as the second is put down and as the first
## is turned: axles a stud too far apart, spur gears square to each other,
## and a bush on the axle where the second would mesh.
func _why_not() -> void:
	print("\nwhy two gears do not mesh")
	await _clear()
	_frame("line")
	_point("3706", Vector3(-40, 62, 0))
	_point("3706", Vector3(40, 62, 0))
	var first: int = _point("3648b", Vector3(-40, 62, 30))
	_point("3648b", Vector3(40, 62, 30))
	var placing: String = _last_words
	_check("two 24s four studs apart: putting the second down says they are too far apart (%s)" % placing,
		placing.contains("too far"))
	_check("...and turning the first says why the second does not turn (%s)" % _turn_words(first),
		_turn_words(first).contains("too far"))
	await _clear()
	_frame("square")
	_point("4519", Vector3(-20, 62, 0))
	_point("3705", Vector3(-90, 62, 60), Vector3(1, 0, 0))
	first = _point("3648b", Vector3(-20, 62, 26))
	_point("3648b", Vector3(-54, 62, 60))
	placing = _last_words
	_check("two 24s on axles square to each other: putting the second down says spur gears mesh on parallel axles (%s)"
		% placing, placing.contains("parallel"))
	await _clear()
	_frame("line")
	_point("3706", Vector3(-20, 62, 0))
	_point("3706", Vector3(40, 62, 0))
	_point("3648b", Vector3(-20, 62, 30))
	_point("3713", Vector3(40, 62, 30))
	var second: int = _point("3648b", Vector3(40, 62, 46))
	placing = _last_words
	_check("a bush where the second 24 would mesh: it says the bush is in the way (%s)" % placing,
		placing.contains("in the way"))


## What the joint words said as the last part was put down.
var _said_last: String = ""
var _last_words: String:
	get:
		return _said_last


## Grab [param key], turn it 30°, and what it says of the gears beside it.
func _turn_words(key: int) -> String:
	var grab: Grab = _new_grab()
	grab.begin(key, _world.get_brick(key).transform.origin)
	grab.turn_to(30.0)
	var words: Variant = grab.get("mesh_words")
	return "" if words == null else str(words)


# -- slid into mesh ----------------------------------------------------------------


## A 24 put down out of line with the 24 beside it (aimed 2.5 studs off,
## past where a gear in hand seats in mesh) is said to mesh nothing there,
## slides along its axle when dragged along it, stops in mesh, and then
## turning the other turns it.
func _slide_into_mesh() -> void:
	print("\na 24 slid along its axle into mesh")
	await _clear()
	_frame("line")
	_point("3706", Vector3(-20, 62, 0))
	_point("3706", Vector3(40, 62, 0))
	var first: int = _point("3648b", Vector3(-20, 62, 30))
	var second: int = _point("3648b", Vector3(40, 62, 82))
	_check("a 24 aimed 2.5 studs out of line goes down there, said to mesh nothing there (%s)" % _last_words,
		second != 0 and _last_words.contains("meshing nothing"))
	if first == 0 or second == 0:
		return
	var from: Vector3 = _world.get_brick(second).transform.origin
	var grab: Grab = _new_grab()
	grab.begin(second, from)
	if _windowed:
		await _shot("slide", "1_out_of_line")
	grab.use_slide()
	var target: float = (_world.get_brick(first).transform.origin - from).dot(grab.axis)
	# The pointer drawn along the axle in steps, past the mesh by a little.
	var shift: float = 0.0
	for n: int in range(1, 11):
		shift = grab.slide_to(target * n / 10.0 + 1.5)
	var moved: int = grab.commit(grab.step_words())
	var now: Vector3 = _world.get_brick(second).transform.origin
	var axle_moved: bool = false
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3706" and absf(brick.transform.origin.x - 40.0) < 1.0:
			axle_moved = absf(brick.transform.origin.z - 50.0) > 0.01
	_check("dragged along its axle it slides %.2f LDU along the axle to %s, the axle staying (%s): %s"
		% [shift, now, "the axle moved" if axle_moved else "the axle stayed", grab.step_words()],
		moved > 0 and not axle_moved and absf(now.z - _world.get_brick(first).transform.origin.z) < 0.01)
	if _windowed:
		await _shot("slide", "2_in_mesh")
	await _turn("slid into mesh", first, second, 1.0, true)


func _shot(name: String, when: String) -> void:
	if _camera != null:
		var box := AABB()
		var any: bool = false
		var store: ModelStore = _main.get("_store")
		for brick: BrickWorld.Brick in _world.bricks():
			var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
			# The pair, not the floor it stands over.
			if info == null or store != null and store.scenery.has(brick.id):
				continue
			var one: AABB = brick.transform * info.bounds
			box = one if not any else box.merge(one)
			any = true
		if any:
			_camera.frame(box)
	for _n: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = OUT.path_join("%s_%s.png" % [name.replace(" ", "_").replace(",", ""), when])
	image.save_png(path)
	print("    picture: %s" % path)
