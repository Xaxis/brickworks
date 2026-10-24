## Does a door go into its frame by pointing, as it does in Studio?
##
##   godot --headless --path . --script src/dev/door_probe.gd
##
## walk180 (2026-10-23): a door (60621 barred, 60616b) held over a 1 x 4 x 6
## frame (60596) stood beside the frame or on its top studs wherever it was
## pointed, never in it. The hand put a part on what the catalogue's
## connectors say, and they do not say a hinge: a door's pins are drawn as
## two bumps, which no connector reads, and its frame's holes as rounds 5
## across that nothing of the door fits. BrickNet's labels (the exact shapes)
## name both halves, as Studio's hinge connections do (JointSnap.hinges_of).
##
## Each pair here is done as a person does it: the holder down, the door,
## shutter or pane in hand, the pointer's line aimed at the holder from in
## front (Builder.update_preview), a click (Builder.place). Each must be on
## its holder's hinge, shut where real sets have it (vendor/omr's files, in
## the holder's own LDraw frame), and once down joined to it by the labels,
## held by check_design, and turned on its hinge by Grab open and back shut.
## The walk's frame is aimed at the six places the walk aimed it. And R
## opens a door in hand on its hinge; a second door over a frame that has
## one goes on the studs; a door aimed at the floor away from any frame
## stands on the floor.
##
## A frame takes a door on each hinge: a second door goes on the free one,
## swung where it has room, and a third on neither. And in a browser, where
## a part's exact shape comes after it may be down, a frame put down before
## its shape came takes a door once the shape comes. A door swept across a
## row of frames is timed a move, as bigmodel_probe times a part in hand.
extends SceneTree

## [holder, insert, what, the seats real sets have it at (the holder's LDraw
## frame: x y z, then the turn by rows), how far off one it may be (LDU)].
## 30179 has a hinge on each face, and its labels put a door's an LDU further
## in than 10184-1 draws it; 3581's labels put a shutter's an LDU in from
## where 374-1 does. 3853's hinges outside, where its shutters go, take its
## pane as well: aimed at the window's side, the pane hangs there.
const PAIRS: Array = [
	["60596", "60621", "the walk's barred door in its frame",
		[[-32, 0, 5, 1, 0, 0, 0, 1, 0, 0, 0, 1], [32, 0, 5, -1, 0, 0, 0, 1, 0, 0, 0, -1]], 0.01],
	["60596", "60616b", "the walk's smooth door in its frame",
		[[-32, 0, 5, 1, 0, 0, 0, 1, 0, 0, 0, 1], [32, 0, 5, -1, 0, 0, 0, 1, 0, 0, 0, -1]], 0.01],
	["60596", "60623", "a door with panes in its frame",
		[[-32, 0, 5, 1, 0, 0, 0, 1, 0, 0, 0, 1], [32, 0, 5, -1, 0, 0, 0, 1, 0, 0, 0, -1]], 0.01],
	["30179", "60616a", "a door in the older frame",
		[[-32, 0, 5, 1, 0, 0, 0, 1, 0, 0, 0, 1], [32, 0, 5, -1, 0, 0, 0, 1, 0, 0, 0, -1],
			[-32, 0, -5, 1, 0, 0, 0, 1, 0, 0, 0, 1], [32, 0, -5, -1, 0, 0, 0, 1, 0, 0, 0, -1]], 1.01],
	["3853", "3856", "a shutter on its window",
		[[-40, 0, -12, 0, 0, -1, 0, 1, 0, 1, 0, 0], [40, 0, -12, 0, 0, 1, 0, 1, 0, -1, 0, 0]], 0.01],
	["3853", "3854", "a pane in its window",
		[[-34, 4, -4, 0, 0, -1, 0, 1, 0, 1, 0, 0], [34, 4, -4, 0, 0, 1, 0, 1, 0, -1, 0, 0],
			[-40, 4, -12, 0, 0, -1, 0, 1, 0, 1, 0, 0], [40, 4, -12, 0, 0, 1, 0, 1, 0, -1, 0, 0]],
		0.01],
	["3581", "3582", "a shutter on its holder brick",
		[[0, 0, -13, 0, 0, 1, 0, 1, 0, -1, 0, 0], [0, 0, -13, 0, 0, -1, 0, 1, 0, 1, 0, 0]], 1.01],
]
## Where walk180 aimed at its frame, in the frame's own frame (y up from its
## foot): the opening, both posts, the hinge's corners and the top.
const WALK_SPOTS: Array = [
	["the opening", Vector3(0, 72, 10)], ["the left post", Vector3(-36, 72, 10)],
	["the right post", Vector3(36, 72, 10)], ["the top left corner", Vector3(-32, 140, 10)],
	["the bottom left corner", Vector3(-32, 6, 10)], ["the top", Vector3(0, 148, 0)],
]
const EYE := Vector3(60, 160, 320)

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

	_walk_spots()
	for pair: Array in PAIRS:
		_pair(pair)
	_opened_in_hand()
	_more_doors()
	_away_from_a_frame()
	_shape_comes_late()
	_swept_across()

	print("")
	if _failures == 0:
		print("doors: %d doors, shutters and panes each go shut onto their holder's hinge by "
			% PAIRS.size() + "pointing, are held there, and swing open and shut on it")
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


## [param part] down on the ground, its foot on the floor.
func _stand(part: String) -> int:
	var mesh: Lbm.PartMesh = _library.mesh_for(part)
	return _builder.put_part(part, 15, Transform3D(Basis.IDENTITY,
		Vector3(0, -mesh.bounds.position.y, 0)))


## Hold [param part] and aim the pointer's line from [constant EYE] at
## [param point].
func _aim(part: String, point: Vector3) -> void:
	_builder.held_part = part
	_builder.held_color = 4
	_builder.held_face = "up"
	_builder.held_rotation = 0
	_builder.update_preview(EYE, (point - EYE).normalized())


## The seat of [param seats] (LDraw, in [param holder]'s frame) the ghost is
## at, within [param slack] LDU and turned as it is, as "x y z" in the
## holder's frame; "" when it is at none.
func _seat_of(at: Transform3D, holder: int, seats: Array, slack: float) -> String:
	var frame: Transform3D = _world.get_brick(holder).transform
	for seat: Array in seats:
		var packed := PackedFloat64Array()
		for x: Variant in seat:
			packed.append(float(x))
		var want: Transform3D = frame * LdrModel.to_transform(packed)
		var same: bool = at.origin.distance_to(want.origin) <= slack
		for n: int in 3:
			same = same and (at.basis[n] - want.basis[n]).length() < 0.002
		if same:
			return "%d %d %d" % [seat[0], seat[1], seat[2]]
	return ""


## Where the ghost stands, in the holder's LDraw frame.
func _said(at: Transform3D, holder: int) -> String:
	var local: Transform3D = _world.get_brick(holder).transform.affine_inverse() * at
	var numbers: PackedFloat64Array = LdrModel.from_transform(local)
	var words: PackedStringArray = []
	for n: int in numbers.size():
		words.append(String.num(numbers[n], 2))
	return " ".join(words)


## What check_design says of the model as it stands, every brick new.
func _design_says() -> String:
	var model: Assistant.Model = _assistant._model_from_world()
	for placement: Assistant.Placement in model.placements:
		placement.id = 0
	return str(_assistant._check(model, true).get("feedback", "")).replace("\n", " / ").left(400)


## Whether BrickNet's labels join two bricks by a hinge where they stand.
func _hinged(one: int, other: int) -> bool:
	var a: BrickWorld.Brick = _world.get_brick(one)
	var b: BrickWorld.Brick = _world.get_brick(other)
	var sa: Exact.Shape = Exact.shape_for(_library, a.part_id)
	var sb: Exact.Shape = Exact.shape_for(_library, b.part_id)
	if sa == null or sb == null:
		return false
	var ia := Exact.Item.new(sa, a.transform)
	var ib := Exact.Item.new(sb, b.transform)
	for one_end: Array in ia.world():
		for other_end: Array in ib.world():
			if sa.kind[int(one_end[0])] == Exact.HINGE and sb.kind[int(other_end[0])] == Exact.HINGE \
					and Exact.meets([ia, ib], [0, one_end[0], one_end[1], one_end[2], one_end[3]],
						[1, other_end[0], other_end[1], other_end[2], other_end[3]]):
				return true
	return false


## Grab takes [param brick], turns it [param degrees] and back to where it
## began: [how far it went, the joint it turned on, what it said, where it
## came back to].
func _turned(brick: int, degrees: float) -> Array:
	var grab := Grab.new()
	grab.world = _world
	grab.builder = _builder
	grab.library = _library
	var box: AABB = _world.get_brick(brick).transform \
		* _library.mesh_for(_world.get_brick(brick).part_id).bounds
	var state: String = grab.begin(brick, box.get_center())
	if state != "moves":
		return [0.0, "", state, 0.0]
	var went: float = grab.turn_to(degrees)
	var said: String = grab.said
	var back: float = grab.turn_to(0.0)
	return [went, grab.link.kind if grab.link != null else "", said, back]


## The walk's barred door over its frame, aimed where the walk aimed it:
## each time on the frame's hinge, shut in the opening, and free to go.
func _walk_spots() -> void:
	print("\nthe walk's door over its frame, at the six places it was aimed")
	_clear()
	var frame: int = _stand("60596")
	var seats: Array = PAIRS[0][3]
	for spot: Array in WALK_SPOTS:
		_aim("60621", spot[1])
		var at: Transform3D = _builder._ghost_transform
		var seat: String = _seat_of(at, frame, seats, 0.01)
		_ok(_builder.is_on_joint() and _builder.joint_words().begins_with("the hinge of")
			and _builder.can_place() and not seat.is_empty(),
			"aimed at %s: on %s, shut at %s, %s (ghost %s)" % [spot[0],
				_builder.joint_words() if _builder.is_on_joint() else "no joint",
				seat if not seat.is_empty() else "no seat", "may go" if _builder.can_place()
					else "red", _said(at, frame)])


## One pair: aimed at the holder's middle, its left side and its top, then
## put down from the left and asked whether it is held and swings.
func _pair(pair: Array) -> void:
	var holder_id: String = pair[0]
	var insert: String = pair[1]
	print("\n%s: %s on %s" % [pair[2], insert, holder_id])
	_clear()
	var holder: int = _stand(holder_id)
	var box: AABB = _world.get_brick(holder).transform * _library.mesh_for(holder_id).bounds
	var middle: Vector3 = box.get_center()
	var side := Vector3(box.position.x + 2.0, middle.y, box.end.z)
	var spots: Array = [["its middle", Vector3(middle.x, middle.y, box.end.z)],
		["its left side", side], ["its top", Vector3(middle.x, box.end.y, middle.z)]]
	for spot: Array in spots:
		_aim(insert, spot[1])
		var at: Transform3D = _builder._ghost_transform
		var seat: String = _seat_of(at, holder, pair[3], pair[4])
		_ok(_builder.is_on_joint() and _builder.joint_words().begins_with("the hinge of")
			and _builder.can_place() and not seat.is_empty(),
			"aimed at %s: on %s, shut at %s, %s (ghost %s)" % [spot[0],
				_builder.joint_words() if _builder.is_on_joint() else "no joint",
				seat if not seat.is_empty() else "no seat",
				"may go" if _builder.can_place() else "red", _said(at, holder)])
	_aim(insert, side)
	var door: int = _builder.place()
	_ok(door != 0 and _hinged(door, holder),
		"a click puts it down, on the hinge BrickNet's labels name with the %s" % holder_id)
	if door == 0:
		return
	var said: String = _design_says()
	_ok(said.contains("buildable") and not said.contains("floating")
		and not said.contains("nothing joins") and not said.contains("overlap"),
		"check_design holds it: %s" % said)
	var one: Array = _turned(door, 60.0)
	var other: Array = _turned(door, -60.0)
	var most: float = maxf(absf(float(one[0])), absf(float(other[0])))
	_ok(str(one[1]) == "hinge" and most >= 45.0 and absf(float(one[3])) < 0.01
		and absf(float(other[3])) < 0.01,
		"Grab swings it open on its %s, %.1f° one way and %.1f° the other, and shut again (%s)"
		% [one[1] if not str(one[1]).is_empty() else "nothing", float(one[0]), float(other[0]),
			str(one[2]).left(120)])


## R on the hinge turns the door in hand open, a step at a time, and it may
## go where it does not meet the frame.
func _opened_in_hand() -> void:
	print("\nR opens a door in hand on its frame's hinge")
	_clear()
	var frame: int = _stand("60596")
	var spot := Vector3(-36, 72, 10)
	_aim("60621", spot)
	var shut: Transform3D = _builder._ghost_transform
	_builder.rotate_held(1)
	_builder.update_preview(EYE, (spot - EYE).normalized())
	var open: Transform3D = _builder._ghost_transform
	var turned: float = rad_to_deg((shut.basis * Vector3.RIGHT).signed_angle_to(
		open.basis * Vector3.RIGHT, Vector3.UP))
	var hinge: Vector3 = _world.get_brick(frame).transform * Vector3(-32, 0, -5)
	var about: float = Vector2(open.origin.x, open.origin.z).distance_to(Vector2(hinge.x, hinge.z))
	_ok(_builder.is_on_joint() and absf(absf(turned) - 45.0) < 0.5 and about < 0.01
		and _builder.can_place(),
		"R turns it %.1f° about the hinge (its origin %.3f LDU off the hinge's line), and it may go"
		% [turned, about])
	var door: int = _builder.place()
	_ok(door != 0 and _hinged(door, frame), "a click puts it down open, on the hinge")


## A second door over a frame that has one shut on its left hinge goes on
## its right one, swung clear of the first; a third has room on neither and
## goes on the studs as before.
func _more_doors() -> void:
	print("\na second and a third door over a frame with one in it")
	_clear()
	var frame: int = _stand("60596")
	_aim("60621", Vector3(-36, 72, 10))
	var first: int = _builder.place()
	_aim("60616b", Vector3(36, 72, 10))
	var at: Transform3D = _builder._ghost_transform
	var hinge: Vector3 = _world.get_brick(frame).transform * Vector3(32, 0, -5)
	_ok(first != 0 and _builder.is_on_joint() and _builder.can_place()
		and Vector2(at.origin.x, at.origin.z).distance_to(Vector2(hinge.x, hinge.z)) < 0.01,
		"aimed at the right post, the second hangs on the right hinge, swung clear (%s)"
		% _said(at, frame))
	var second: int = _builder.place()
	_aim("60623", Vector3(0, 72, 10))
	_ok(second != 0 and not _builder.is_on_joint(),
		"a third aimed at the opening is on no hinge (%s), and stands at %s" % [
			_builder.joint_words(), _builder._ghost_transform.origin])


## A door aimed at the floor beside a frame stands on the floor.
func _away_from_a_frame() -> void:
	print("\na door aimed at the floor away from a frame")
	_clear()
	_stand("60596")
	_aim("60621", Vector3(-160, 0, 60))
	_ok(not _builder.is_on_joint() and _builder.can_place(),
		"on no hinge (%s), it stands at %s" % [_builder.joint_words(),
			_builder._ghost_transform.origin])


## A frame put down before its exact shape came, as a browser fetches one
## (PartLibrary.exact_fetched): no hinge to aim at until it comes, and the
## door goes in once it has.
func _shape_comes_late() -> void:
	print("\na frame whose shape comes after it is down, as in a browser")
	_clear()
	var info: PartLibrary.PartInfo = _library.shaped_as("60596")
	var shape: Exact.Shape = Exact.shape_for(_library, "60596")
	Exact._shapes[info.mesh_hash] = null
	# Somewhere none of the frames before stood, so it is measured afresh.
	var frame: int = _builder.put_part("60596", 15, Transform3D(Basis.IDENTITY,
		Vector3(200, 144, 0)))
	var spot := Vector3(164, 72, 10)
	_aim("60621", spot)
	var before: bool = _builder.is_on_joint()
	Exact._shapes[info.mesh_hash] = shape
	_library.exact_fetched.emit(info.id)
	_aim("60621", spot)
	var seat: String = _seat_of(_builder._ghost_transform, frame, PAIRS[0][3], 0.01)
	_ok(not before and _builder.is_on_joint() and not seat.is_empty() and _builder.can_place(),
		"before its shape comes the door is on %s; after, on %s, shut at %s" % [
			"a joint" if before else "none", _builder.joint_words(),
			seat if not seat.is_empty() else "no seat"])


## A door in hand swept across a row of eight frames, a move a step, as
## bigmodel_probe sweeps a part: what aiming costs a move (Builder.
## update_preview), the median and the worst, and how many moves were on a
## hinge. Held under 2 ms a move headless, as a 2 x 4 brick's is.
func _swept_across() -> void:
	print("\na door swept across a row of eight frames")
	_clear()
	for n: int in 8:
		_builder.put_part("60596", 15, Transform3D(Basis.IDENTITY, Vector3(-280 + n * 80, 144, 0)))
	_aim("60621", Vector3(-320, 72, 10))
	var times: Array = []
	var on: int = 0
	for n: int in 80:
		var point := Vector3(-320 + n * 8, 72 + 40 * sin(n * 0.4), 10)
		var t0: int = Time.get_ticks_usec()
		_builder.update_preview(EYE, (point - EYE).normalized())
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
		if _builder.is_on_joint():
			on += 1
	times.sort()
	var median: float = times[times.size() / 2]
	_ok(median < 2.0 and on > 40, "aiming %.2f ms a move (worst %.2f), on a hinge in %d of %d moves"
		% [median, times.back(), on, times.size()])
