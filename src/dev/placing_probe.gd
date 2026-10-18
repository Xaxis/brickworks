## What the ghost shows is where the part goes: awkward parts aimed by the
## pointer and clicked, each put-down compared with its ghost exactly.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
##     --resolution 1400x900 --script src/dev/placing_probe.gd
##
## Every click is sent as a browser sends one: the move to the fraction of a
## pixel, the press and the release in whole pixels, cut down. A click aims
## before it puts, and aimed there it once put the plane's clip plates a
## stud forward and 2 LDU up from their ghosts (Main._true_point). Then a
## clip plate, a bar in its clip, a hinge, slopes, a Technic pin, and
## 8841-1's Technic plates swung on their pins onto an axle at 66.4
## degrees, off every one of the 24 turns (Builder._closings). Pictures in
## shots/placing/, the rows in shots/placing/placing.json.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _rows: Array = []


func _initialize() -> void:
	_run()


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
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_store = _main.get("_store")
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
	if only.is_empty() or only == "tile":
		await _from_its_tile()
	if only.is_empty() or only == "edge":
		await _edge()
	if only.is_empty() or only == "parts":
		await _awkward()
	if only.is_empty() or only == "balance":
		await _balance()
	if only.is_empty() or only == "wheels":
		await _wheels()
	if only.is_empty() or only == "wholeset":
		await _whole_sets()
	var path: String = ProjectSettings.globalize_path("res://shots/placing/placing.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_rows, " "))
	file.close()
	print("")
	print("placing: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- from its tile ----------------------------------------------------------------


## A part taken by a click on its tile, then the pointer moved onto the
## model in one move and in two: the ghost under the pointer, where a click
## there puts it. In the browser the ghost stayed where the first of two
## moves had aimed it (2026-10-16).
func _from_its_tile() -> void:
	print("  a part taken by its tile, the pointer moved onto the model")
	_main.call("clear_model")
	_camera.frame(AABB(Vector3(-100, 0, -100), Vector3(200, 40, 200)))
	await _frames(30)
	var bin: PartsBin = _main.get("_bin")
	for steps: int in [1, 2]:
		for number: String in ["3022", "3023"]:
			await _click(bin._search.get_global_rect().get_center())
			await _key(KEY_A, true)
			await _type(number)
			await create_timer(0.4).timeout
			await _frames(4)
			if bin._grid.get_child_count() == 0:
				_check("the search lists %s" % number, false)
				continue
			var tile: Vector2 = (bin._grid.get_child(0) as Control).get_global_rect().get_center()
			await _click(tile)
			for _n: int in 600:
				if _library.mesh_for(number) != null:
					break
				await process_frame
			await _frames(30)
			var target: Vector2 = _screen(Vector3(20, 0, 20))
			for n: int in steps:
				var event := InputEventMouseMotion.new()
				event.position = _as_event(tile.lerp(target, float(n + 1) / steps))
				event.global_position = event.position
				Input.parse_input_event(event)
			await _frames(6)
			var ghost: Variant = _builder.ghost_place()
			var under: Vector3 = _builder.ghost_transform().origin
			var ok: bool = ghost != null \
				and _camera.unproject_position(under).distance_to(target) < 60.0
			_check("%s from its tile, %d move%s onto the model: its ghost under the pointer (%s, at %s on screen, the pointer at %s)"
				% [number, steps, "" if steps == 1 else "s", ghost,
					_camera.unproject_position(under).round() if ghost != null else "-",
					target.round()], ok)


# -- across an edge -------------------------------------------------------------


## The smallest case of the browser's: one clip plate over the front edge
## of a 2 x 2 plate, the pointer stepped across it a third of a pixel at a
## time. In the browser before the fix, 16 of 35 clicks put it somewhere
## other than its ghost.
func _edge() -> void:
	print("  a clip plate stepped across a plate's edge, a third of a pixel at a time")
	_main.call("clear_model")
	_put_ldr("3022", 15, [0, -8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	_camera.frame(AABB(Vector3(-60, 0, -60), Vector3(120, 40, 120)))
	await _frames(40)
	await _hold("4081b")
	await _frames(4)
	var a: Vector2 = _screen(Vector3(0, 8, -20))
	var b: Vector2 = _screen(Vector3(0, 8, 20))
	var edge: Vector2 = a if a.y > b.y else b
	var tried: int = 0
	var differ: Array = []
	var d: float = -6.0
	while d <= 6.0:
		var row: Dictionary = await _aim_and_put(edge + Vector2(0.41, d), true)
		if row.get("put") != null:
			tried += 1
			if not bool(row["same"]):
				differ.append("%s: ghost %s, put %s" % [row["at"], row["ghost"], row["put"]])
		d += 0.35
	_rows.append({"case": "edge", "tried": tried, "differ": differ.size()})
	_check("each of %d clicks across the edge put the clip plate where its ghost stood (%d elsewhere%s)"
		% [tried, differ.size(), (": " + differ[0]) if not differ.is_empty() else ""],
		tried >= 10 and differ.is_empty())


# -- awkward parts ----------------------------------------------------------------


func _awkward() -> void:
	print("  awkward parts, each by its ghost")
	# The plane's step 4: two clip plates, each turned a quarter, the clip
	# over the edge of the plate under it.
	_main.call("clear_model")
	_put_ldr("3034", 7, [0, -8, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0])
	_put_ldr("3022", 15, [0, -16, -60, 0, 0, 1, 0, 1, 0, -1, 0, 0])
	_camera.frame(AABB(Vector3(-100, 0, -100), Vector3(200, 40, 200)))
	await _frames(40)
	await _hold("4081b")
	var clip: int = 0
	for want: Array in [[-10, -24, -50, 0, 0, 1, 0, 1, 0, -1, 0, 0],
			[10, -24, -50, 0, 0, -1, 0, 1, 0, 1, 0, 0]]:
		var at: Transform3D = _ldr(want)
		await _turn_to(at.basis)
		var made: int = await _one("4081b clip plate", _screen(at.origin - Vector3(0, 8, 0)), at)
		if clip == 0:
			clip = made
	# A bar in that clip, by the clip.
	if clip != 0:
		await _hold("87994")
		await _frames(4)
		var bore: JointSnap.End = _site_of(clip, "bore")
		if bore != null:
			await _one("87994 bar in the clip", _screen(bore.middle()), null, true)
		else:
			_check("the clip plate has a clip to aim at", false)
	await _shot("clip_and_bar")

	# A hinge, its top on its base; slopes; a Technic pin in a hole.
	_main.call("clear_model")
	_put_ldr("3020", 7, [0, -8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	_put_ldr("3020", 7, [0, -8, 40, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	_camera.frame(AABB(Vector3(-60, 0, -80), Vector3(120, 60, 120)))
	await _frames(40)
	await _hold("3937")
	await _turn_to(Basis.IDENTITY)
	var base: int = await _one("3937 hinge base", _screen(Vector3(-30, 8, 0)))
	if base != 0:
		await _hold("3938")
		await _one("3938 hinge top on its base", _screen(_top_of(base)))
	await _hold("3040b")
	await _one("3040b slope", _screen(Vector3(20, 8, 0)))
	await _hold("3039")
	await _turn_to(BrickLattice.basis_for("up", 1))
	await _one("3039 slope, turned", _screen(Vector3(0, 8, -40)))
	await _hold("3700")
	await _turn_to(Basis.IDENTITY)
	var beam: int = await _one("3700 Technic brick", _screen(Vector3(30, 8, -40)))
	if beam != 0:
		await _hold("3673")
		var hole: JointSnap.End = _site_of(beam, "pin_hole")
		if hole != null:
			await _one("3673 Technic pin in its hole", _screen(hole.at), null, true)
		else:
			_check("the Technic brick has a hole to aim at", false)
	await _shot("hinge_slopes_pin")

	# A corner plate round what stands in its missing corner: 8643-1's step 2
	# lays two 2420s on its 4 x 4 plate, their missing corners round the arm
	# of a wheel holder (6157) beside it. By its box a 2420 stood on the arm,
	# a plate up; by its cover it lies on the plate (Builder._sinks_by).
	_main.call("clear_model")
	_put_ldr("3031", 8, [0, -8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	_put_ldr("6157", 0, [0, -16, -60, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	_camera.frame(AABB(Vector3(-60, 0, -60), Vector3(120, 40, 160)))
	await _frames(40)
	await _hold("2420")
	var corner: Lbm.PartMesh = _library.mesh_for("2420")
	for want: Array in [[-10, -16, -30, -1, 0, 0, 0, 1, 0, 0, 0, -1],
			[10, -16, -30, 0, 0, 1, 0, 1, 0, -1, 0, 0]]:
		var at: Transform3D = _ldr(want)
		await _turn_to(at.basis)
		# At its corner stud, the plate's own origin, on the plate under it.
		var foot: Vector3 = at.origin + Vector3(0, (at * corner.bounds).abs().position.y
			- at.origin.y, 0)
		await _one("2420 corner plate round the wheel holder's arm", _screen(foot), at)
	await _shot("corner_plate")

	# ...but only where it is held by its sockets: 5762-1's 4488 stands on
	# a wedge plate by the block under half of it, where its sockets are,
	# the other half a plate over the wing; the wedge's cover is short of
	# its slanted edge under that block, and lowered by its cover the 4488
	# sank a plate into the wing (Builder._seated_by_sockets).
	_main.call("clear_model")
	_put_ldr("54384", 15, [80, -16, -10, 0, 0, 1, 0, 1, 0, -1, 0, 0])
	_camera.frame(AABB(Vector3(0, 0, -60), Vector3(160, 50, 140)))
	await _frames(40)
	await _hold("4488")
	var nacelle: Transform3D = _ldr([80, -32, -40, 0, 0, 1, 0, 1, 0, -1, 0, 0])
	await _turn_to(nacelle.basis)
	# Aimed between its sockets, at the bottom of the block they are under,
	# and moved across by where its ghost stands, as the build flow aims.
	var at_sockets: Vector2 = _screen(nacelle * Vector3(10, -16, 0))
	for _n: int in 4:
		await _move(at_sockets)
		if _builder.ghost_place() == null:
			break
		var ghost: Vector3 = _builder.ghost_transform().origin
		if Vector2(ghost.x, ghost.z).distance_to(Vector2(nacelle.origin.x, nacelle.origin.z)) < 0.5:
			break
		at_sockets += _screen(Vector3(nacelle.origin.x, ghost.y, nacelle.origin.z)) - _screen(ghost)
	await _one("4488 on the wedge plate by its sockets, not sunk into it", at_sockets, nacelle)
	await _shot("on_its_sockets")

	# Below the ground, held by the model: a bracket on the edge of the plate
	# the model is built up from, its arm hanging 4 LDU past the plate's
	# underside, as 8643-1's front bracket (2436a) hangs. Its ghost stood on
	# its arm, a plate up; it goes where it is aimed, and the model rises to
	# stand on it, one undo with the put (Builder._held_below_ground,
	# _stand_on_the_ground).
	_main.call("clear_model")
	var plate: int = _put_ldr("3031", 8, [0, -8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	_camera.frame(AABB(Vector3(-60, -10, -60), Vector3(120, 50, 140)))
	await _frames(40)
	await _hold("2436a")
	await _turn_to(Basis.IDENTITY)
	var hung: Transform3D = _ldr([0, -16, -30, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	var aim: Vector2 = _screen(hung.origin - Vector3(0, 8, 0))
	await _move(aim + Vector2(0, 1))
	await _move(aim)
	var shown: Transform3D = _builder.ghost_transform()
	_check("2436a bracket: its ghost hangs below the ground where the set has it (%s, %s)" % [
		_ldr_of(shown), "may go" if _builder.can_place() else "red"],
		_builder.ghost_place() != null and _builder.can_place()
		and _near(shown, hung, 0.05, 0.002))
	var before: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		before[brick.id] = true
	await _click_whole(aim)
	var bracket: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not before.has(brick.id):
			bracket = brick.id
	_check("...and a click puts it down", bracket != 0)
	if bracket != 0:
		var up := Vector3(0, 4, 0)
		var base_at: Vector3 = _world.get_brick(plate).transform.origin
		var bracket_at: Vector3 = _world.get_brick(bracket).transform.origin
		_check("...and the model rose 4 LDU to stand on it (plate at %s, bracket at %s)" % [
			base_at, bracket_at], base_at.is_equal_approx(Vector3(0, 8, 0) + up)
			and bracket_at.is_equal_approx(hung.origin + up))
		await _key(KEY_ESCAPE)
		await _key(KEY_Z, true)
		_check("one undo takes the bracket off and the model down again (plate at %s, %d parts)" % [
			_world.get_brick(plate).transform.origin, _world.brick_count()],
			_world.get_brick(plate).transform.origin.is_equal_approx(Vector3(0, 8, 0))
			and _world.get_brick(bracket) == null)
	await _shot("below_the_ground")


## 8841-1 Balance's step 4: two Technic plates (4262) hang from an axle in
## the end of a Technic brick, their lower holes on two pins. Each is off
## the 24 turns (cos 0.4: 66.4 degrees) and off the whole LDU. The axle
## and the pins are put as the file has them; each plate is aimed at its
## pin, and swung onto the axle where it also joins (Builder._closings),
## T for the other way on when the first is not the file's.
func _balance() -> void:
	print("  8841-1's Technic plates, swung on their pins onto the axle")
	_main.call("clear_model")
	_put_ldr("3895", 4, [-140, -288, 30, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	_put_ldr("3705", 0, [-240, -278, 30, 0, 0, -1, 0, 1, 0, 1, 0, 0])
	var pins: Array = [
		_put_ldr("4459", 0, [-280, -186.35, 20, 0, 1, 0, 0, 0, 1, 1, 0, 0]),
		_put_ldr("4459", 0, [-200, -186.35, 40, 0, 1, 0, 0, 0, 1, 1, 0, 0])]
	_camera.frame(AABB(Vector3(-320, 150, -80), Vector3(200, 160, 120)))
	await _frames(40)
	await _hold("4262")
	await _turn_to(Basis.IDENTITY)
	var plates: Array = [
		[-259.9985, -232.1751, 10, -0.4, 0, 0.9165, 0.9165, 0, 0.4, 0, 1, 0],
		[-220.0015, -232.1751, 50, 0.4, 0, -0.9165, 0.9165, 0, 0.4, 0, -1, 0]]
	for n: int in plates.size():
		var want: Transform3D = _ldr(plates[n])
		var pin: JointSnap.End = _nearest_site(pins[n], want)
		if pin == null:
			var kinds: Array = JointSnap.sites_in(_world, _library) \
				.filter(func(s: JointSnap.End) -> bool: return s.brick == int(pins[n])) \
				.map(func(s: JointSnap.End) -> String: return s.kind)
			_check("the pin has an end to aim at (brick %d: %s; the plate's ends %d)" % [pins[n],
				kinds, JointSnap.ends_of(_library.mesh_for(_builder.held_part)).size()], false)
			continue
		var point: Vector2 = _screen(pin.aimed(Vector3.ZERO, Vector3.FORWARD))
		await _move(point + Vector2(0, 1))
		await _move(point)
		var presses: int = 0
		while not _near(_builder.ghost_transform(), want, 0.05, 0.002) and presses < 12:
			await _key(KEY_T)
			presses += 1
			await _move(point + Vector2(0, 1))
			await _move(point)
		var ghost: Transform3D = _builder.ghost_transform()
		_check("4262 #%d: its ghost on the pin stands where the file has it, swung onto the axle (%s, wanted %s; %d T; %s)"
			% [n + 1, _ldr_of(ghost), _ldr_of(want), presses,
				"may go" if _builder.can_place() else "red"],
			_builder.ghost_place() != null and _near(ghost, want, 0.05, 0.002)
			and _builder.can_place())
		await _one("4262 Technic plate #%d, swung onto the axle" % (n + 1), point, want, true)
	await _shot("balance")


## 8643-1's wheels: a 6157's wheel pins with a rim on each (51719, as the
## file has them, the left one turned the other way), and a tyre (50951)
## aimed at each rim's middle: its ghost round the rim, centred and square,
## T for the other way round, where the file has it. And a wheel that comes
## with its tyre on (4624c01) aimed at a wheel pin of another 6157, and at
## the end of an axle in a Technic brick's hole (3482c01, whose hub takes
## an axle).
func _wheels() -> void:
	print("  8643-1's tyres on their rims, and wheels with tyres on pins and axles")
	_main.call("clear_model")
	_put_ldr("6157", 0, [0, -48, 160, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	_put_ldr("51719", 0, [-40, -43, 160, 0, 0, 1, 0, 1, 0, -1, 0, 0])
	_put_ldr("51719", 0, [40, -43, 160, 0, 0, -1, 0, 1, 0, 1, 0, 0])
	var holder: int = _put_ldr("6157", 0, [0, -48, 80, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	_put_ldr("3700", 4, [0, -64, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	var axle: int = _put_ldr("3705", 0, [0, -54, -30, 0, 0, 1, 0, 1, 0, -1, 0, 0])
	_camera.frame(AABB(Vector3(-70, 20, -180), Vector3(140, 50, 260)))
	await _frames(40)
	await _hold("50951")
	await _turn_to(Basis.IDENTITY)
	for want: Array in [[-40, -43, 160, 0, 0, -1, 0, 1, 0, 1, 0, 0],
			[40, -43, 160, 0, 0, -1, 0, 1, 0, 1, 0, 0]]:
		var at: Transform3D = _ldr(want)
		var rim: JointSnap.End = null
		for site: JointSnap.End in JointSnap.sites_in(_world, _library):
			if site.kind == "rim" and site.at.distance_to(at.origin) < 1.0:
				rim = site
		if rim == null:
			_check("the rim at %s has a rim to aim a tyre at" % _ldr_of(at), false)
			continue
		var point: Vector2 = _screen(rim.aimed(Vector3.ZERO, Vector3.FORWARD))
		await _move(point + Vector2(0, 1))
		await _move(point)
		# R about the rim (45 degrees a press), T over to its other way round.
		var presses: int = 0
		while not _near(_builder.ghost_transform(), at, 0.05, 0.002) and presses < 18:
			await _key(KEY_T if presses % 9 == 8 else KEY_R)
			presses += 1
			await _move(point + Vector2(0, 1))
			await _move(point)
		var said: String = _builder.joint_words()
		_check("50951 tyre: its ghost round the rim, centred and square, where the file has it (%s, wanted %s; %d keys; on %s; %s)"
			% [_ldr_of(_builder.ghost_transform()), _ldr_of(at), presses, said,
				"may go" if _builder.can_place() else "red"],
			_builder.ghost_place() != null and _near(_builder.ghost_transform(), at, 0.05, 0.002)
			and _builder.can_place() and said.begins_with("the rim of"))
		await _one("50951 tyre round its rim", point, at, true)
	# A wheel with its tyre on, onto a wheel pin.
	await _hold("4624c01")
	await _turn_to(Basis.IDENTITY)
	var pin: JointSnap.End = null
	for site: JointSnap.End in JointSnap.sites_in(_world, _library):
		if site.brick == holder and site.kind == "shaft" and site.at.x < -30.0 \
				and (pin == null or site.reach > pin.reach):
			pin = site
	if pin == null:
		_check("the 6157 has a wheel pin to aim a wheel at", false)
	else:
		await _one("4624c01 wheel with its tyre, on a wheel pin", _screen(pin.aimed(
			_camera.global_position, (pin.middle() - _camera.global_position).normalized())),
			null, true)
	# ...and onto an axle, by its hub's axle hole.
	await _hold("3482c01")
	await _turn_to(Basis.IDENTITY)
	# Its end out of the brick, not the one at the brick's far face.
	var tip: JointSnap.End = null
	for site: JointSnap.End in JointSnap.sites_in(_world, _library):
		if site.brick == axle and site.kind == "axle" \
				and (tip == null or site.at.z > tip.at.z):
			tip = site
	if tip == null:
		_check("the axle has an end to aim a wheel at", false)
	else:
		await _one("3482c01 wheel with its tyre, on an axle", _screen(tip.aimed(
			Vector3.ZERO, Vector3.FORWARD)), null, true)
	await _shot("wheels")


# -- one part -----------------------------------------------------------------------


## Aim at [param at], see the ghost, click as a browser clicks, and check
## the part went where the ghost stood (and, given [param want], where the
## file has it). The new brick's id, or 0.
## What stopped the three sets of docs/CADTASK.md being built whole, each by
## its ghost where the set's file has it (wholeset2-2026-10-18).
func _whole_sets() -> void:
	print("  what stopped a whole set, each by its ghost")
	# 5762-1's tail fin on three jumper plates' middle studs, half a stud off
	# every other stud, and the slope on its own stud (Builder.
	# _on_studs_off_the_grid). By the grid it stood half a stud aside.
	_main.call("clear_model")
	_put_ldr("3020", 25, [0, -24, 110, 0, 0, -1, 0, 1, 0, 1, 0, 0])
	for z: int in [90, 110, 130]:
		_put_ldr("3794a", 25, [0, -32, z, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	_camera.frame(AABB(Vector3(-60, 0, -170), Vector3(120, 80, 120)))
	await _frames(40)
	await _hold("4286")
	await _turn_to(Basis.IDENTITY)
	var fin: Transform3D = _ldr([0, -56, 130, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	var jumper: Vector3 = _ldr([0, -32, 110, 1, 0, 0, 0, 1, 0, 0, 0, 1]).origin
	var put_fin: int = await _one("4286 on three jumpers' middle studs", _screen(jumper + Vector3(4, 0, 0)), fin)
	if put_fin != 0:
		await _hold("50746")
		await _turn_to(Basis.IDENTITY)
		await _one("50746 on the fin's stud", _screen(_top_of(put_fin)), fin)
	await _shot("jumper_fin")

	# 8643-1's cab roof, a curved slope whose flared sides make it 58.5 LDU
	# across, on the two 1 x 4 bricks of the cab: by its box and the sockets
	# laid on it it stood half a stud aside (Builder._on_its_own_grid).
	_main.call("clear_model")
	_put_ldr("3010", 0, [-10, -48, 80, 0, 0, -1, 0, 1, 0, 1, 0, 0])
	_put_ldr("3010", 0, [10, -48, 80, 0, 0, -1, 0, 1, 0, 1, 0, 0])
	_camera.frame(AABB(Vector3(-60, 0, -160), Vector3(120, 80, 160)))
	await _frames(40)
	await _hold("50948")
	await _turn_to(Basis.IDENTITY)
	var roof: Transform3D = _ldr([0, -56, 110, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	await _one("50948 cab roof on two 1 x 4 bricks", _screen(Vector3(-6, 48, roof.origin.z)), roof)
	await _shot("cab_roof")

	# 8841-1's top beam: a 1 x 12 Technic brick beside the 1 x 2 at its
	# middle, under the end of the 1 x 4 over them, aimed at the 1 x 2's
	# side. Its middle in the cell beside the face it stood half in the 1 x 2;
	# then up on the 1 x 4 over its end (Builder._out_from_face, _settle).
	_main.call("clear_model")
	_put_ldr("3701", 4, [0, -128, 10, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	_put_ldr("3700", 1, [0, -104, 10, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	_camera.frame(AABB(Vector3(-280, 40, -40), Vector3(320, 120, 80)))
	_camera.look_from(Vector3(-0.8, 0.25, 0.55).normalized())
	await _frames(60)
	await _hold("3895")
	await _turn_to(Basis.IDENTITY)
	var beam: Transform3D = _ldr([-140, -104, 10, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	await _one("3895 beside the 1 x 2, under the 1 x 4's end", _screen(Vector3(-19.5, 84, -10)), beam)
	await _shot("beam_beside")

	# 8841-1's belt wheel halfway along its axle, aimed at the axle there: a
	# hole went on an axle only flush with its tip (JointSnap.ways, End.back).
	_main.call("clear_model")
	var axle: int = _put_ldr("3706", 0, [0, -102, 1, 0, 0, -1, 0, 1, 0, 1, 0, 0])
	_camera.frame(AABB(Vector3(-60, 60, -80), Vector3(120, 80, 160)))
	_camera.look_from(Vector3(0.9, 0.3, 0.2).normalized())
	await _frames(60)
	await _hold("4185")
	var wheel: Transform3D = _ldr([0, -102, 10, 0, -1, 0, -1, 0, 0, 0, 0, -1])
	var row: Dictionary = await _aim_and_put(_screen(wheel.origin + Vector3(0, 6, 0)), false)
	var made: BrickWorld.Brick = _world.get_brick(int(row.get("id", 0))) if row.get("put") != null else null
	_check("4185 belt wheel halfway along its axle: put on the axle where it was aimed (ghost %s, wanted %s)"
		% [row.get("ghost"), _ldr_of(wheel)], made != null and bool(row.get("on_joint", false))
		and made.transform.origin.distance_to(wheel.origin) < 0.05 and axle != 0)
	await _shot("wheel_on_axle")


func _one(name: String, at: Vector2, want: Variant = null, joint: bool = false) -> int:
	await _move(at + Vector2(0, 1))
	var row: Dictionary = await _aim_and_put(at, false)
	row["case"] = name
	if want != null:
		row["want"] = _ldr_of(want)
	_rows.append(row)
	if row.get("put") == null:
		_check("%s: a ghost that may go where it was aimed (%s)" % [name,
			"red" if row.get("ghost") != null else "no ghost"], false)
		return 0
	var ok: bool = bool(row["same"])
	if joint:
		ok = ok and bool(row["on_joint"])
	if want != null:
		ok = ok and _near(_world.get_brick(int(row["id"])).transform, want, 0.05, 0.002)
	_check("%s: put down where its ghost stood%s%s (ghost %s, put %s)" % [name,
		", on its joint" if joint else "", ", as the file has it" if want != null else "",
		row["ghost"], row["put"]], ok)
	return int(row["id"])


## The pointer moved to [param at] to the fraction of a pixel; the ghost
## read; the press and release sent in whole pixels, cut down, as a browser
## sends them. Undone after when [param undo].
func _aim_and_put(at: Vector2, undo: bool) -> Dictionary:
	await _move(at)
	var row: Dictionary = {"at": "%.2f,%.2f" % [at.x, at.y]}
	if _builder.ghost_place() == null or not _builder.can_place():
		row["ghost"] = _ldr_of(_builder.ghost_transform()) if _builder.ghost_place() != null else null
		row["put"] = null
		return row
	var shown: Transform3D = _builder.ghost_transform()
	row["ghost"] = _ldr_of(shown)
	row["on_joint"] = _builder.is_on_joint()
	var before: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		before[brick.id] = true
	await _click_whole(at)
	var made: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if not before.has(brick.id):
			made = brick
	if made == null:
		row["put"] = null
		return row
	row["id"] = made.id
	row["put"] = _ldr_of(made.transform)
	row["same"] = _near(made.transform, shown, 0.01, 0.0005)
	if undo:
		await _key(KEY_Z, true)
	return row


static func _near(a: Transform3D, b: Transform3D, place: float, turn: float) -> bool:
	if a.origin.distance_to(b.origin) > place:
		return false
	for n: int in 3:
		if (a.basis[n] - b.basis[n]).length() > turn:
			return false
	return true


# -- helpers --------------------------------------------------------------------------


func _hold(part: String) -> void:
	_main.call("_on_part_chosen", part)
	# Its shape is read when it is first taken.
	for _n: int in 600:
		if _library.mesh_for(part) != null:
			break
		await process_frame


## Turned to [param basis] by T and R, as a person turns a part in hand.
func _turn_to(basis: Basis) -> void:
	for _n: int in 6:
		if _builder.held_face == "up":
			break
		await _key(KEY_T)
	for _n: int in 4:
		if BrickLattice.basis_for(_builder.held_face, _builder.held_rotation) \
				.is_equal_approx(basis):
			break
		await _key(KEY_R)


func _site_of(brick_id: int, kind: String) -> JointSnap.End:
	for site: JointSnap.End in JointSnap.sites_in(_world, _library):
		if site.brick == brick_id and site.kind == kind:
			return site
	return null


## The end of [param brick_id] nearest any end of the part in hand placed
## at [param want]: the pin a plate's hole goes on.
func _nearest_site(brick_id: int, want: Transform3D) -> JointSnap.End:
	var mine: Array = JointSnap.ends_of(_library.mesh_for(_builder.held_part))
	var best: JointSnap.End = null
	var best_d: float = INF
	for site: JointSnap.End in JointSnap.sites_in(_world, _library):
		if site.brick != brick_id:
			continue
		for end: JointSnap.End in mine:
			var d: float = (want * end.at).distance_to(site.aimed(Vector3.ZERO, Vector3.FORWARD))
			if d < best_d:
				best_d = d
				best = site
	return best


func _top_of(brick_id: int) -> Vector3:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var box: AABB = brick.transform * _library.mesh_for(brick.part_id).bounds
	return Vector3(box.get_center().x, box.end.y, box.get_center().z)


func _ldr(v: Array) -> Transform3D:
	var packed := PackedFloat64Array()
	for x: Variant in v:
		packed.append(float(x))
	return LdrModel.to_transform(packed)


## A pose as an LDraw line has it: x y z, then the matrix by rows, rounded.
func _ldr_of(at: Transform3D) -> String:
	var numbers: PackedFloat64Array = LdrModel.from_transform(at)
	var words: PackedStringArray = []
	for n: int in numbers.size():
		words.append(String.num(numbers[n], 3 if n < 3 else 4))
	return " ".join(words)


func _put_ldr(part: String, colour: int, v: Array) -> int:
	var where: Transform3D = _ldr(v)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)
	return brick_id


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


## A move, to the fraction of a pixel, as a browser's pointermove is.
func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _click(at: Vector2) -> void:
	await _move(at)
	await _click_whole(at)


func _type(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper())
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


## A press and a release in whole pixels, cut down, as a browser's
## mousedown and mouseup are: no move between.
func _click_whole(at: Vector2) -> void:
	var whole: Vector2 = _as_event(at).floor()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = whole
		event.global_position = whole
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)


func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/placing/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/placing/%s.png" % name)
