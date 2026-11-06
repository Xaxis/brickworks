## Can Technic be built by hand?
##
##   godot --headless --path . --script src/dev/technic_hand_probe.gd
##
## The checker has known pins, axles and clips for a long time; the hand
## did not. A part in hand went on the studs or against a face, so a pin
## could not be aimed into a hole at all, a beam could not go onto pins
## and a clip could not go on a bar. Each case here is done the way a
## person does it: the part in hand, the pointer's line aimed at the
## connector (Builder.update_preview), a click (Builder.place). Then the
## parts are asked whether they are joined (Joints), and check_design is
## asked about the same model, so the hand and the checker cannot come to
## different answers about one placement.
##
## And the other way: the same pin a stud off is refused by both.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant


func _initialize() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	get_root().add_child(_assistant)
	await process_frame

	_a_pin_in_a_brick()
	_an_axle_and_a_gear()
	_a_beam_on_two_pins()
	_a_clip_on_a_bar()
	_a_clip_on_a_handle()
	_a_bar_in_a_clip()
	_turning_on_a_joint()

	print("")
	if _failures == 0:
		print("by hand: a pin into a hole, an axle through a beam with a gear on it, "
			+ "a beam onto two pins, a clip on a bar, a clip on a plate's handle and a "
			+ "bar in a clip, each joined, and check_design agrees")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _clear() -> void:
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()


## A part put down where it is said to go, as a design or a file would.
func _put(part: String, at: Transform3D) -> int:
	return _builder.put_part(part, 4, at)


## Hold a part and aim the pointer's line from [param from] at [param point].
func _aim(part: String, point: Vector3, from: Vector3) -> void:
	_builder.held_part = part
	_builder.held_color = 0
	_builder.held_face = "up"
	_builder.held_rotation = 0
	_builder.update_preview(from, (point - from).normalized())


## Aim again from the same place, after a key.
func _again(point: Vector3, from: Vector3) -> void:
	_builder.update_preview(from, (point - from).normalized())


func _on_joint() -> bool:
	return _builder.has_method("is_on_joint") and bool(_builder.call("is_on_joint"))


## Whether a part has room at a place by the builder's rule.
func _room(part: String, at: Transform3D) -> bool:
	if _builder.has_method("room_for"):
		return bool(_builder.call("room_for", part, at, true))
	return not _builder.lattice.collides_boxes(
		_builder.boxes_for(_library.mesh_for(part), at))


## The part ids each brick is joined to by a pin, an axle or a round.
func _joined(brick_id: int) -> Array:
	var entries: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		entries.append([brick.id, brick.transform, _library.mesh_for(brick.part_id)])
	var held: Dictionary = (Joints.both_ways(entries).get(brick_id, {}) as Dictionary).duplicate()
	held.merge(Joints.rounds(entries).get(brick_id, {}))
	var out: Array = []
	for other: int in held:
		out.append(other)
	return out


## What check_design says of the model as it stands, as a design of its
## own (every brick counted as new, so an overlap is not excused as one
## already there).
func _design_says() -> String:
	var model: Assistant.Model = _assistant._model_from_world()
	for placement: Assistant.Placement in model.placements:
		placement.id = 0
	return str(_assistant._check(model, true).get("feedback", "")).replace("\n", " / ").left(300)


## How many cells two bricks' covers share.
func _shared(one: int, other: int) -> int:
	return BrickLattice.shared_cells(_builder.lattice.boxes_of(one),
		_builder.lattice.boxes_of(other))


func _ghost() -> Transform3D:
	return _builder._ghost_transform


## The pin in hand aimed at 3700's hole, from in front and a little above:
## it goes in, collar at the mouth, and is joined to the brick.
func _a_pin_in_a_brick() -> void:
	print("\na pin into a Technic brick's hole")
	_clear()
	# On the ground: 3700 is 24 LDU tall under its origin, its hole 10
	# under the top and running along z, its mouths at z = -10 and +10.
	var brick: int = _put("3700", Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	var hole := Vector3(0, 14, 0)
	var eye := Vector3(40, 90, 300)
	_aim("3673", hole, eye)
	var at: Transform3D = _ghost()
	var along: Vector3 = (at.basis * Vector3.RIGHT).normalized()
	_ok(_on_joint() and _builder.can_place(),
		"aimed at the hole, the ghost is on it and may go (%s, %s)" % [_on_joint(),
			_builder.can_place()])
	_ok(at.origin.distance_to(Vector3(0, 14, 10)) < 0.01 and absf(along.z) > 0.999,
		"its collar at the near mouth, along the hole: %s" % at)
	var pin: int = _builder.place()
	_ok(pin != 0 and _joined(pin).has(brick), "a click puts it in, joined to the brick")
	var said: String = _design_says()
	_ok(not said.contains("overlap"), "check_design passes the same model: %s" % said)

	# The same pin a stud along: half in the brick's wall.
	_builder.remove_brick_id(pin)
	var off: Transform3D = at.translated(Vector3(BrickLattice.STUD, 0, 0))
	_ok(not _room("3673", off), "the same pin a stud off is refused by hand")
	_builder.put_part("3673", 0, off)
	said = _design_says()
	_ok(said.contains("overlap"), "...and by check_design: %s" % said)


## An axle through a half beam's axle hole, from above, and a gear put on
## its top.
func _an_axle_and_a_gear() -> void:
	print("\nan axle through a beam's axle hole, and a gear on it")
	_clear()
	# 6632 flat on the ground: 10 thick, its axle holes upright at x=0, z=0
	# and z=-40.
	var beam: int = _put("6632", Transform3D(Basis.IDENTITY, Vector3(0, 5, 0)))
	_aim("3705", Vector3(0, 5, 0), Vector3(20, 300, 60))
	var at: Transform3D = _ghost()
	var along: Vector3 = (at.basis * Vector3.RIGHT).normalized()
	_ok(_on_joint() and _builder.can_place() and absf(along.y) > 0.999
		and Vector2(at.origin.x, at.origin.z).length() < 0.01,
		"the axle stands in the hole, upright, and may go: %s" % at)
	var axle: int = _builder.place()
	_ok(axle != 0 and _joined(axle).has(beam), "a click puts it through, joined to the beam")
	var top: float = (at * Vector3(39.5, 0, 0)).y if along.y > 0 else (at * Vector3(-39.5, 0, 0)).y
	_aim("3647", Vector3(0, top - 5, 0), Vector3(-40, top + 200, 80))
	at = _ghost()
	_ok(_on_joint() and _builder.can_place(),
		"a gear aimed at the axle's top goes onto it: %s" % at)
	var gear: int = _builder.place()
	_ok(gear != 0 and _joined(gear).has(axle), "a click puts it on, joined to the axle")
	var said: String = _design_says()
	_ok(not said.contains("overlap"), "check_design passes the same model: %s" % said)


## Two pins in a beam, and a second beam aimed at one of them: it goes on
## both.
func _a_beam_on_two_pins() -> void:
	print("\na beam onto two pins")
	_clear()
	# 32523 flat on the ground: 20 thick, holes upright at z = -20, 0, 20.
	var base: int = _put("32523", Transform3D(Basis.IDENTITY, Vector3(0, 10, 0)))
	var pins: Array = []
	for z: float in [-20.0, 0.0]:
		_aim("3673", Vector3(0, 10, z), Vector3(30, 300, z + 50))
		pins.append(_builder.place())
	_ok(pins[0] != 0 and pins[1] != 0 and _joined(pins[0]).has(base)
		and _joined(pins[1]).has(base), "two pins go into its holes from above")
	_aim("32523", Vector3(0, 30, -20), Vector3(40, 300, 40))
	var at: Transform3D = _ghost()
	_ok(_on_joint() and _builder.can_place(),
		"the second beam, aimed at a pin, goes on: %s" % at)
	var top: int = _builder.place()
	var joined: Array = _joined(top)
	_ok(top != 0 and joined.has(pins[0]) and joined.has(pins[1]),
		"a click puts it on both pins (joined to %s)" % [joined])
	var said: String = _design_says()
	_ok(not said.contains("overlap"), "check_design passes the same model: %s" % said)


## A bar aimed at the hollow stud of a round brick stands in it, and a clip
## aimed at the bar goes on it where the pointer is along it. A bar in a
## loop, a plate's handle, is [method _a_clip_on_a_handle].
func _a_clip_on_a_bar() -> void:
	print("\na clip on a bar")
	_clear()
	# 3062b on the ground: its hollow stud a clip's size, 4 across, from
	# its top at 28 down to 20.
	var brick: int = _put("3062b", Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	_aim("30374", Vector3(0, 24, 0), Vector3(30, 300, 120))
	var at: Transform3D = _ghost()
	_ok(_on_joint() and _builder.can_place() and absf(at.origin.x) < 0.01
		and absf(at.origin.z) < 0.01, "a bar aimed at the hollow stud stands in it: %s" % at)
	var bar: int = _builder.place()
	_ok(bar != 0 and _joined(bar).has(brick), "a click puts it in, joined to the brick")
	# A bar in a hollow stud is the overlap a real joint has: the bar's
	# cover and the stud's ring share cells, all inside the stud, which
	# check_design forgives (Joints.rounds) and so must the hand.
	var shared: int = _shared(bar, brick)
	_ok(shared > 0, "the bar and the brick share %d cells inside the stud, and it is let in"
		% shared)
	var stood: Transform3D = at
	_aim("4085c", Vector3(0, 60, 0), Vector3(40, 140, 300))
	at = _ghost()
	_ok(_on_joint() and _builder.can_place(), "a clip aimed at the bar goes on: %s" % at)
	var clip: int = _builder.place()
	_ok(clip != 0 and _joined(clip).has(bar), "a click puts it on, joined to the bar")
	var said: String = _design_says()
	_ok(not said.contains("overlap"), "check_design passes the same model: %s" % said)

	# And nothing more: the same clip two LDU off the bar's line is a clip
	# pressed into the side of the bar, and the same bar two LDU off the
	# stud's line is a bar pushed into the stud's wall.
	_builder.remove_brick_id(clip)
	var beside: Transform3D = at.translated(Vector3(2, 0, 0))
	_ok(not _room("4085c", beside), "the same clip 2 LDU off the bar's line is refused by hand")
	_builder.put_part("4085c", 0, beside)
	said = _design_says()
	_ok(said.contains("overlap"), "...and by check_design: %s" % said)
	_builder.undo()
	_builder.remove_brick_id(bar)
	beside = stood.translated(Vector3(2, 0, 0))
	_ok(not _room("30374", beside), "the same bar 2 LDU off the stud's line is refused by hand")
	_builder.put_part("30374", 0, beside)
	said = _design_says()
	# The check seats a part a few LDU off its joint onto it (since
	# 2026-10-14), which is not passing it where it was put either.
	_ok(said.contains("overlap") or said.contains("Seated"), "...and by check_design: %s" % said)


## A clip on a plate's handle. 2540's bar runs beside the plate between
## two arms, and in the plate's own layers the plate's edge, the arms and
## the bar close a ring the fill filled, so the bar was buried in cover
## (tools/ldraw/occupancy.bars). Held out from the handle a clip still
## went on, its open side to the plate; turned up or down, its jaw on the
## plate's side went into the filled loop and was refused, by hand and by
## check_design alike.
func _a_clip_on_a_handle() -> void:
	print("\na clip on a plate's handle")
	_clear()
	# 2540 on two 1 x 2 bricks, so a clip hung below its handle is off the
	# ground: its plate 8 tall, the bar of its handle 4 across, along x at
	# z = 20 and 2 under the top, with an arm from x = 6 to 12 each side and
	# the bar free between them.
	_put("3004", Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	_put("3004", Transform3D(Basis.IDENTITY, Vector3(0, 48, 0)))
	var plate: int = _put("2540", Transform3D(Basis.IDENTITY, Vector3(0, 56, 0)))
	var middle := Vector3(0, 54, 20)
	var eye := Vector3(40, 190, 300)
	_aim("4085c", middle, eye)
	_ok(_on_joint() and _builder.joint_words().contains("Handle"),
		"a clip aimed at the handle is on it: %s" % _builder.joint_words())

	# Each quarter turn about the bar (R turns a clip an eighth): which way
	# the clip's plate, 20 in front of its bore, points, and whether it fits.
	var fits: Dictionary = {}
	var turns: Dictionary = {}
	for q: int in 4:
		var stem: Vector3 = (_ghost().basis * Vector3.FORWARD).normalized()
		var called: String = "up" if stem.y > 0.9 else "down" if stem.y < -0.9 \
			else "out" if stem.z > 0.9 else "in" if stem.z < -0.9 else "%s" % stem
		fits[called] = _builder.can_place()
		turns[called] = q
		_builder.rotate_held(2)
		_again(middle, eye)
	_ok(fits.get("out", false) and fits.get("up", false) and fits.get("down", false),
		"its plate out from the handle, up or down, it has room: %s" % [fits])
	_ok(fits.has("in") and not fits["in"],
		"...and not with its plate pushed into the plate's own: %s" % [fits])

	# Turned until its plate stands up, and a click.
	_builder.rotate_held(2 * int(turns.get("up", 0)))
	_again(middle, eye)
	var at: Transform3D = _ghost()
	var clip: int = _builder.place()
	_ok(clip != 0 and _joined(clip).has(plate),
		"a click puts it on standing up, joined to the handle: %s" % at)
	var said: String = _design_says()
	_ok(said.contains("4 bricks, buildable") and not said.contains("overlap"),
		"check_design says the four are buildable: %s" % said)

	# Off the bar's line toward the plate: a clip pushed into the bar.
	_builder.remove_brick_id(clip)
	var beside: Transform3D = at.translated(Vector3(0, 0, -2))
	_ok(not _room("4085c", beside), "the same clip 2 LDU off the bar's line is refused by hand")
	_builder.put_part("4085c", 0, beside)
	said = _design_says()
	# Refused, or seated on the bar it missed: not passed where it was put.
	_ok(said.contains("overlap") or said.contains("Seated"), "...and by check_design: %s" % said)


## A bar aimed at a clip: through it, joined.
func _a_bar_in_a_clip() -> void:
	print("\na bar in a clip")
	_clear()
	# 4085c on the ground: its clip upright, 20 behind the plate's middle.
	var clip: int = _put("4085c", Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
	_aim("87994", Vector3(0, 4, 20), Vector3(40, 300, 200))
	var at: Transform3D = _ghost()
	_ok(_on_joint() and _builder.can_place(), "a bar aimed at the clip goes in: %s" % at)
	var bar: int = _builder.place()
	_ok(bar != 0 and _joined(bar).has(clip), "a click puts it in, joined to the clip")
	var said: String = _design_says()
	_ok(not said.contains("overlap"), "check_design passes the same model: %s" % said)


## R turns a part about the joint it is on: a pin by an eighth, an axle in
## its cross by a quarter. T puts a pin in from the other face.
func _turning_on_a_joint() -> void:
	print("\nturning on a joint")
	_clear()
	_put("3700", Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	var hole := Vector3(0, 14, 0)
	var eye := Vector3(40, 90, 300)
	_aim("3673", hole, eye)
	var before: Transform3D = _ghost()
	_builder.rotate_held(1)
	_again(hole, eye)
	var after: Transform3D = _ghost()
	var turned: float = rad_to_deg((before.basis * Vector3.UP).angle_to(after.basis * Vector3.UP))
	_ok(_on_joint() and absf(turned - 45.0) < 0.5
		and (after.basis * Vector3.RIGHT).is_equal_approx(before.basis * Vector3.RIGHT)
		and after.origin.is_equal_approx(before.origin),
		"R turns a pin 45 degrees about the hole, where it is (%.1f)" % turned)
	_ok(_builder.can_place(), "...and it may still go in")
	# Turned, the pin's cover keeps every cell it touches and runs into
	# the brick round the hole: let pass, as check_design lets a pin in
	# the hole it lines up with pass.
	var rolled: int = _builder.place()
	var shared: int = _shared(rolled, 1)
	_ok(shared > 0, "turned, the pin and the brick share %d cells, and it is let in" % shared)
	_builder.undo()
	_builder.tip_held(1)
	_again(hole, eye)
	var flipped: Transform3D = _ghost()
	_ok(flipped.origin.distance_to(Vector3(0, 14, -10)) < 0.01,
		"T puts it in from the far face: %s" % flipped.origin)

	_clear()
	_put("6632", Transform3D(Basis.IDENTITY, Vector3(0, 5, 0)))
	var from := Vector3(20, 300, 60)
	_aim("3705", Vector3(0, 5, 0), from)
	before = _ghost()
	_builder.rotate_held(1)
	_again(Vector3(0, 5, 0), from)
	after = _ghost()
	turned = rad_to_deg((before.basis * Vector3.UP).angle_to(after.basis * Vector3.UP))
	_ok(absf(turned - 90.0) < 0.5, "R turns an axle in its cross a quarter (%.1f)" % turned)
