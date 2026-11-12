## Plays a model's motions (Motions) through Grab, the one model of what
## moves (docs/MOTIONS.md): each track's joint is taken hold of as
## move_part takes it, and turned or slid to its keys a frame at a time, so
## it stops where it meets the model, drives the gears, racks and linkages
## a drag drives, and says where it stopped and on what. Played to keep, the
## model is left where the motion ends, one step to undo; played to look
## (define_motion's check, a render), nothing changes.
##
## It also finds a motion's joints again (by its sub-assembly's name, or
## its part's number, colour and place), measures where each stands from
## where the model was built (so a model saved with its doors open opens
## them no further), and proposes motions from what moves (Playable's
## words: doors, steering, a boom, a turntable, gears, a rack).
##
## Tracks are played each on its own joint's Grab, begun on the model as it
## stands: one carried by another (an arm on a turntable) is carried by it
## in the frames, but tested for room as if the other stood still, and two
## tracks are not tested against each other.
class_name MotionPlayer
extends RefCounted

## A joint this far short of where it was asked has stopped: degrees, studs.
const SHORT_DEG := 0.5
const SHORT_STUDS := GrabDrag.SHORT_STUDS
## A part found again by its number and colour this near where its ref
## says, LDU: a fifth of a stud.
const PLACE_SLACK := Motions.PLACE_SLACK
## Frames a second a motion is played at when it is not rendered.
const PLAY_FPS := 12
## A loop is turned at most this far in one step, degrees, or slid this
## far, studs: asked 11° at once, 8808-1's steering loop drifted along its
## column's free slide, and turned 90° and -90° and back it stood 1.28 LDU
## out (3° steps: 0.001 LDU).
const LOOP_STEP_DEG := 3.0
const LOOP_STEP_STUDS := 0.25

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var store: ModelStore
var grabbing: GrabDrag
## What each motion was last found to do: its name, lower case -> words.
var results: Dictionary = {}
## How far each driven motion's driver turned when last played forward and
## kept, degrees: played backwards it turns back as far, so a driver that
## stopped at a rack's end comes back to where it began. Name, lower case.
var _driven: Dictionary = {}
var _suggested: Array = []
var _suggested_at: int = -1


## The model's motions, made when it has none yet. What was said of the
## last model's (results, a driver's turn, suggestions) goes with it.
func motions() -> Motions:
	if _generation != world.generation():
		_generation = world.generation()
		results.clear()
		_driven.clear()
		_suggested_at = -1
	if world.motions == null:
		world.motions = Motions.new()
	return world.motions


var _generation: int = -1


# -- finding a joint --------------------------------------------------------------


## The parts [param joint]'s ref finds now, the part it takes hold of
## first; [] when it finds nothing (the part was taken off).
func parts_of(joint: Motions.Joint) -> Array:
	if joint.by == "assembly":
		var ids: Array = grabbing.named_parts(joint.assembly)
		if not ids.is_empty():
			joint.lead = int(ids[0])
		return ids
	# The part it took hold of, by its id: found as the model was read
	# (ModelStore), or as it was made here, and followed when an undo put
	# it back as another id. Recoloured, it is the same part.
	joint.lead = _carried(joint.lead)
	var lead: BrickWorld.Brick = world.get_brick(joint.lead) if joint.lead != 0 else null
	if lead != null and lead.part_id == joint.part:
		return [lead.id]
	# Else by its number, colour and place, as the file has it: a part that
	# arrived after the model opened (the web fetches some).
	var best: int = Motions.part_at(joint, world, store.lift() if store != null else Vector3.ZERO)
	if best != 0:
		joint.lead = best
		return [best]
	return []


## [param id], a part's id, followed to the id an undo or redo put it back
## as (Builder.renumber); where the model stood as the file was read goes
## with it. [param id] itself while it is there.
func _carried(id: int) -> int:
	if id == 0 or builder == null or world.get_brick(id) != null:
		return id
	var now: int = builder._live(id)
	if now == id or world.get_brick(now) == null:
		return id
	var snapshot: Dictionary = motions().snapshot
	if snapshot.has(id) and not snapshot.has(now):
		snapshot[now] = snapshot[id]
	return now


## What [param joint] is called: its sub-assembly, else "#80".
func joint_name(joint: Motions.Joint) -> String:
	if joint.by == "assembly":
		return Assemblies.label(joint.assembly)
	return "#%d" % joint.lead if joint.lead != 0 else "the %s" % joint.part


## Its name with what it is: "#80 (the Technic Steering Wheel)".
func joint_words(joint: Motions.Joint) -> String:
	if joint.by == "assembly" or joint.lead == 0 or world.get_brick(joint.lead) == null:
		return joint_name(joint)
	var info: PartLibrary.PartInfo = library.parts.get(world.get_brick(joint.lead).part_id)
	return "#%d (%s)" % [joint.lead, Inventory._tidy(info.name) if info != null else joint.part]


## What a ref that finds nothing says: "its hinge is gone: no Door 1 x 3 x 1
## (3821, colour 4) where it was".
func gone_words(joint: Motions.Joint) -> String:
	if joint.by == "assembly":
		return "its joint is gone: the model has no sub-assembly %s" % joint.assembly
	var info: PartLibrary.PartInfo = library.parts.get(joint.part)
	return "its joint is gone: no %s (%s, colour %d) where it was" % [
		Inventory._tidy(info.name) if info != null else "part", joint.part, joint.colour]


## A joint for a motion, from a part or a sub-assembly as move_part names it
## ("#80", "Door Left"): the one the model's motions already have for it,
## else a new one, measured where it stands (kept once a motion that moves
## it is: Motions.put). A String saying why when it does not move, or moves
## only on a ball. [param slide]: slid along its line rather than turned.
## [param named]: a part in a sub-assembly that moves alike is kept by the
## sub-assembly's name, which survives the part being moved.
func joint_named(asked: String, slide: bool = false, named: bool = true) -> Variant:
	var found: Variant = _joint_and_held(asked, slide, named)
	return found if found is String else (found as Array)[0]


## [joint, the Grab begun on it], or why not.
func _joint_and_held(asked: String, slide: bool, named: bool) -> Variant:
	var taken: Variant = grabbing.held_for_session(asked)
	if taken is String:
		return "%s: %s" % [asked, taken]
	var held: Grab = taken
	if held.mode == "ball" and not slide:
		return ("%s turns on a ball, every way: a motion turns a joint about its line or slides "
			+ "it along one. Name a part on a hinge, a pin, an axle or a turntable.") % asked
	if slide and not held.can_slide():
		return "%s does not slide: nothing it is on is longer than the hole it is in." % asked
	var joint := Motions.Joint.new()
	joint.mode = "slide" if slide or held.mode == "slide" else "turn"
	var ids: Array = grabbing.named_parts(asked)
	var text: String = asked.strip_edges().trim_prefix("#")
	if text.is_valid_int():
		_as_part(joint, int(text))
		# The sub-assembly the file gives it, when taking that moves the same.
		var path: String = Assemblies.path_of(world.get_brick(int(text)))
		if named and not path.is_empty() and _moves_alike(held, path):
			joint.by = "assembly"
			joint.assembly = path
	else:
		joint.by = "assembly"
		joint.assembly = asked.strip_edges()
		joint.lead = int(ids[0])
	var kept: Motions.Joint = motions().find_joint(joint)
	if kept != null:
		return [kept, held]
	var built: float = held.from_built()
	joint.at = 0.0 if is_nan(built) else (built / BrickLattice.STUD if joint.mode == "slide" else built)
	_measure(joint, held, false)
	return [joint, held]


func _as_part(joint: Motions.Joint, id: int) -> void:
	var brick: BrickWorld.Brick = world.get_brick(id)
	joint.by = "part"
	joint.lead = id
	joint.part = brick.part_id
	joint.colour = brick.color_code
	joint.place = (brick.transform.origin - (store.lift() if store != null else Vector3.ZERO)) \
		* LdrModel.FLIP


## Whether the sub-assembly at [param path], taken whole, moves on the same
## joint as [param held] and the same parts: a name a file keeps.
func _moves_alike(held: Grab, path: String) -> bool:
	var ids: Array = grabbing.named_parts(path)
	if ids.is_empty():
		return false
	var other: Variant = grabbing.held_of(ids, path)
	if not (other is Grab):
		return false
	var them: Grab = other
	return them.link == held.link and them.moving.size() == held.moving.size() \
		and them.moving.keys().all(func(key: int) -> bool: return held.moving.has(key))


# -- where a joint stands --------------------------------------------------------------


## Where [param joint] stands now, from where the model was built: degrees
## about its line, or studs along it. What the motion last knew when its
## part is gone, or has not moved since it was measured.
func at_now(joint: Motions.Joint) -> float:
	var ids: Array = parts_of(joint)
	if ids.is_empty():
		return joint.at
	if not joint.measured:
		var was: Variant = motions().snapshot.get(int(ids[0]))
		var lead: BrickWorld.Brick = world.get_brick(int(ids[0]))
		if was == null or (was as Transform3D).is_equal_approx(lead.transform):
			return joint.at
		_measure(joint, grabbing.picked_of(ids), true)
		if not joint.measured:
			return joint.at
	joint.ours = _carried(joint.ours)
	joint.theirs = _carried(joint.theirs)
	var ours: BrickWorld.Brick = world.get_brick(joint.ours)
	var theirs: BrickWorld.Brick = world.get_brick(joint.theirs)
	if ours == null or theirs == null:
		joint.measured = false
		return joint.at
	return joint.at + _between(joint.base_rel, theirs.transform.affine_inverse() * ours.transform,
		joint.line, joint.mode)


## [param joint]'s AT brought up to where it stands now, and measured from
## there: what is written into the file (ModelStore.motion_rebase).
func rebase(joint: Motions.Joint) -> void:
	var now: float = at_now(joint)
	joint.at = now
	if joint.measured:
		joint.ours = _carried(joint.ours)
		joint.theirs = _carried(joint.theirs)
		var ours: BrickWorld.Brick = world.get_brick(joint.ours)
		var theirs: BrickWorld.Brick = world.get_brick(joint.theirs)
		if ours == null or theirs == null:
			# Its part taken off: what it last knew stands, to be found again.
			joint.measured = false
			return
		joint.base_rel = theirs.transform.affine_inverse() * ours.transform


## The joint's two sides found from [param held] (begun or picked): a part
## of each, and its line in the second's frame. [param from_file]: measured
## from where the parts stood as the file was read, when the snapshot has
## them; else from now.
func _measure(joint: Motions.Joint, held: Grab, from_file: bool) -> void:
	if held.state != "moves" or held.link == null or held.link.axis == Vector3.ZERO \
			or not held.bodies.members.has(held.body) \
			or not held.bodies.members.has(held.link.other(held.body)):
		return
	var ours: int = int((held.bodies.members[held.body] as PackedInt64Array)[0])
	var theirs: int = int((held.bodies.members[held.link.other(held.body)] as PackedInt64Array)[0])
	var mine: BrickWorld.Brick = world.get_brick(ours)
	var across: BrickWorld.Brick = world.get_brick(theirs)
	if mine == null or across == null:
		return
	joint.ours = ours
	joint.theirs = theirs
	joint.line = (across.transform.basis.orthonormalized().inverse() * held.link.axis.normalized()).normalized()
	var snapshot: Dictionary = motions().snapshot
	if from_file and snapshot.has(ours) and snapshot.has(theirs):
		joint.base_rel = (snapshot[theirs] as Transform3D).affine_inverse() * (snapshot[ours] as Transform3D)
	else:
		joint.base_rel = across.transform.affine_inverse() * mine.transform
	joint.measured = true


## How far [param now] has turned (or slid) from [param base] about [param
## line], in the frame both are in: degrees, or studs. As Grab.from_built.
static func _between(base: Transform3D, now: Transform3D, line: Vector3, mode: String) -> float:
	if mode == "slide":
		return (now.origin - base.origin).dot(line) / BrickLattice.STUD
	var turned: Basis = now.basis.orthonormalized() * base.basis.orthonormalized().inverse()
	var square: Vector3 = (Vector3.UP if absf(line.y) < 0.9 else Vector3.RIGHT).cross(line).normalized()
	var to: Vector3 = turned * square
	return rad_to_deg(atan2(line.dot(square.cross(to)), square.dot(to)))


# -- playing ---------------------------------------------------------------------------


## One joint as a motion plays it.
class Item extends RefCounted:
	var joint: Motions.Joint
	var name: String = ""
	## [[t, place, how]], as a Track's, in the time it is played.
	var track: Motions.Track
	var grab: Grab
	## The grab's turn (degrees) or slide (studs) is a place less this.
	var shift: float = 0.0
	var from: float = 0.0
	var to: float = 0.0
	## The furthest short of where it was asked, and where and why then:
	## with the part it met (a brick id, 0 when none).
	var short_by: float = 0.0
	var stop_words: String = ""
	var met: int = 0
	var driver: bool = false
	## The least and most it reached on the way.
	var low: float = INF
	var high: float = -INF
	## A path's: "wheel" (turned as it rolls) or "steer" (turned into the
	## corners); "" for a track's or a driver's.
	var role: String = ""
	# A wheel's, as it stood when taken hold of: its axle's middle and line
	# (LDU, the world's), its tyre's radius, the part it is found by, which
	# way along its line is ahead (+1 or -1), and how far it has rolled by
	# how far along the path (LDU, at every ROLL_STEP of the way).
	var centre := Vector3.ZERO
	var axis := Vector3.ZERO
	var radius: float = 0.0
	var lead: int = 0
	var ahead: float = 1.0
	var rolls := PackedFloat64Array()


## What playing a motion did.
class Played extends RefCounted:
	var name: String = ""
	var reverse: bool = false
	var fps: int = 12
	var seconds: float = 0.0
	## Each frame: brick id -> Transform3D of every part it moves.
	var frames: Array = []
	## The moments the motion's keys are at, seconds, in its played time.
	var key_times: Array = []
	var items: Array = []
	## Why a joint did not play: lines.
	var refused := PackedStringArray()
	var kept: int = 0
	## How the model stands where it ends, when kept: "it stands".
	var standing: String = ""
	# Being worked out (begin, advance): what carries another first, how
	# many frames, and the next to work out.
	var order: Array = []
	var count: int = 0
	var next: int = 0
	## The longest one frame took to work out, ms.
	var frame_ms: float = 0.0
	## A path's (unit drive): where the whole model goes, every part of the
	## model as it stood ([id, Transform3D]), the steering's place by how far
	## along (LDU), and each part where the joints put it in the last frame,
	## before the path moved it.
	var drive: Drive = null
	var parts: Array = []
	var steering: Motions.Track = null
	var local_last: Dictionary = {}
	## What the steering could not reach: words, or "".
	var steer_words: String = ""
	## Its legs said (Motions.Path.said).
	var path_said: String = ""
	## The steering tried (MotionPlayer._steer_tried), each place with
	## where it carries each steered wheel.
	var tried: Array = []

	func stopped() -> bool:
		for item: Item in items:
			if not item.stop_words.is_empty():
				return true
		return false

	## Whether any joint moved on the way, wherever it ended.
	func went() -> bool:
		if drive != null and drive.total > 0.0:
			return true
		for item: Item in items:
			if item.high - item.low > (MotionPlayer.SHORT_DEG if item.joint.mode == "turn"
					else MotionPlayer.SHORT_STUDS):
				return true
		return false


## A path as it is played (unit drive): where the model's middle goes, on
## the ground, from where the model stands. Its legs from [member pivot]
## (the middle of the back axle on the ground), [member forward] the way the
## model faces and [member left] its left, level: each leg [kind, sign,
## length LDU, radius LDU, where it begins along the path LDU].
class Drive extends RefCounted:
	var pivot := Vector3.ZERO
	var forward := Vector3(0.0, 0.0, 1.0)
	var left := Vector3(1.0, 0.0, 0.0)
	var legs: Array = []
	## How far its middle goes, LDU, over [member seconds].
	var total: float = 0.0
	var seconds: float = 1.0
	var how: String = "EASE"
	## Played from its end to its start: the model, standing where the path
	## ends, goes back along it.
	var reverse: bool = false

	func _init(path: Motions.Path, from: Vector3, facing: Vector3, backwards: bool) -> void:
		pivot = from
		forward = Vector3(facing.x, 0.0, facing.z).normalized()
		left = Vector3.UP.cross(forward).normalized()
		seconds = maxf(path.seconds, 0.1)
		how = path.how
		reverse = backwards
		for leg: Array in path.legs:
			var kind: String = str(leg[0])
			var amount: float = float(leg[1])
			var radius: float = float(leg[2]) * BrickLattice.STUD
			var length: float = absf(amount) * BrickLattice.STUD if kind == "STRAIGHT" \
				else deg_to_rad(absf(amount)) * radius
			legs.append([kind, signf(amount) if kind == "STRAIGHT" else (1.0 if kind == "LEFT" else -1.0),
				length, radius, total])
			total += length

	## How far along it is at [param t] seconds, LDU: from 0 to the whole way,
	## EASE gathering speed over its first fifth and slowing over its last
	## (the same speed between, as a car drives), LINEAR the same speed all
	## the way. Backwards, from the whole way to 0.
	func along(t: float) -> float:
		var u: float = clampf(t / seconds, 0.0, 1.0)
		if reverse:
			u = 1.0 - u
		if how != "EASE":
			return total * u
		var ramp: float = MotionPlayer.DRIVE_RAMP
		var top: float = total / (1.0 - ramp)
		if u < ramp:
			return top * u * u / (2.0 * ramp)
		if u <= 1.0 - ramp:
			return top * (u - ramp * 0.5)
		return total - top * (1.0 - u) * (1.0 - u) / (2.0 * ramp)

	## The moment it is [param s] LDU along, seconds: the inverse of along.
	func moment(s: float) -> float:
		var low: float = 0.0
		var high: float = seconds
		for _n: int in 40:
			var middle: float = (low + high) * 0.5
			if (along(middle) < s) != reverse:
				low = middle
			else:
				high = middle
		return (low + high) * 0.5

	## Where the model's middle stands [param s] LDU along and which way it
	## faces, from where it began: [x ahead, y to its left, turned left by
	## radians].
	func flat(s: float) -> Vector3:
		var x: float = 0.0
		var y: float = 0.0
		var heading: float = 0.0
		for leg: Array in legs:
			var on: float = clampf(s - float(leg[4]), 0.0, float(leg[2]))
			if on <= 0.0 and s < float(leg[4]):
				break
			if str(leg[0]) == "STRAIGHT":
				x += float(leg[1]) * on * cos(heading)
				y += float(leg[1]) * on * sin(heading)
				continue
			var way: float = float(leg[1])
			var radius: float = float(leg[3])
			var cx: float = x - way * radius * sin(heading)
			var cy: float = y + way * radius * cos(heading)
			heading += way * on / radius
			x = cx + way * radius * sin(heading)
			y = cy - way * radius * cos(heading)
		return Vector3(x, y, heading)

	## The whole model's move [param s] LDU along, from where it began.
	func pose(s: float) -> Transform3D:
		var at: Vector3 = flat(s)
		var to: Vector3 = pivot + forward * at.x + left * at.y
		return Transform3D(Basis(Vector3.UP, at.z), to) * Transform3D(Basis.IDENTITY, -pivot)

	## The whole model's move at [param t] seconds, from where it stands.
	func moved(t: float) -> Transform3D:
		return at_along(along(t))

	## The whole model's move [param s] LDU along, from where it stands:
	## backwards, the path's end is where it stands, and [param s] back
	## along it from there. The path is laid from where it stands, so the
	## way back is the move to its start and then the way along from there,
	## in that order: the other order ends in the same place by another way.
	func at_along(s: float) -> Transform3D:
		return pose(total).affine_inverse() * pose(s) if reverse else pose(s)

	## Which leg [param s] LDU along is on, its number; the last past the end.
	func leg_at(s: float) -> int:
		for n: int in legs.size():
			if s < float(legs[n][4]) + float(legs[n][2]):
				return n
		return legs.size() - 1


## Called once a path has moved the model, kept, with all it went over
## ([method drive_box]): the window lays its floor under it (Main).
var driven: Callable = Callable()


## What a path suggested for a model on wheels is called.
const DRIVE_NAME := "Drive and turn left"
## How fast a path is driven when it is given no time, studs a second.
const DRIVE_SPEED := 10.0
## The share of a path's time an eased one gathers speed in, and slows in.
const DRIVE_RAMP := 0.2
## A wheel's part this far from its line or less is on it, LDU; its axle's
## line this near level or nearer is level (its up part, of 1).
const ON_THE_AXLE := 4.0
const LEVEL := 0.3
## A wheel whose tyre's bottom is this near the lowest's, or nearer, stands
## on the ground, LDU: a plate's height.
const ON_THE_GROUND := 8.0
## Wheels this near the back one along the way it faces, or nearer, are on
## the back axle, LDU.
const SAME_AXLE := 20.0
## A path's first leg, and its corner, when it is given none (APP_UX6 #12):
## a 32-stud straight, then a quarter turn to the left.
const DRIVE_STRAIGHT := 32.0
const DRIVE_CORNER := 90.0
## The share of the most the steering reaches a corner it is given asks.
const STEER_SHARE := 0.75
## How far the steering takes to turn into a corner and out of it, at most,
## studs along the path; and at least.
const STEER_RAMP_MOST := 3.0
const STEER_RAMP_LEAST := 0.5
## How often along a path a wheel's roll is worked out, LDU.
const ROLL_STEP := 2.0


## Play [param motion] a frame at a time, [param reverse] from its end to
## its start (a driver turned back as far as it last went), at [param fps]. With
## [param keep] the model is left where it ends, one step to undo, called
## [param words]; otherwise nothing changes.
func play(motion: Motions.Motion, reverse: bool = false, fps: int = PLAY_FPS, keep: bool = false,
		words: String = "") -> Played:
	var played: Played = begin(motion, reverse, fps)
	advance(played)
	finish(played, keep, words)
	return played


## [param motion]'s joints taken hold of to be played, its frames not yet
## worked out: [method advance] works them out, a few at a time if need
## be, and [method finish] keeps it or not. Nothing changes until then.
func begin(motion: Motions.Motion, reverse: bool = false, fps: int = PLAY_FPS) -> Played:
	motions()
	var played := Played.new()
	played.name = motion.name
	played.reverse = reverse
	played.fps = fps
	var length: float = motion.length()
	played.seconds = length
	var tracks: Array = motion.tracks.duplicate()
	var driven: Motions.Track = null
	if motion.driver != null:
		# Turned from wherever it stands, so many times; back as many, reversed.
		driven = Motions.Track.new()
		driven.joint = motion.driver
		var start: float = at_now(motion.driver)
		var turn: float = 360.0 * motion.turns
		if reverse:
			turn = -float(_driven.get(motion.name.to_lower(), turn))
		driven.add_key(0.0, start, "LINEAR")
		driven.add_key(motion.driver_seconds, start + turn, "LINEAR")
		tracks.append(driven)
	for track: Motions.Track in tracks:
		var item: Item = _item_for(track, track == driven)
		if item.grab == null:
			played.refused.append("%s: %s" % [item.name, item.stop_words])
			continue
		played.items.append(item)
	var times: Dictionary = {}
	for item: Item in played.items:
		item.shift = _shift_for(item, length if reverse and not item.driver else 0.0)
	for track: Motions.Track in motion.tracks:
		for key: Array in track.keys:
			times[snappedf(length - float(key[0]) if reverse else float(key[0]), 0.001)] = true
	if motion.path != null:
		_begin_drive(played, motion.path, reverse)
		for n: int in played.drive.legs.size():
			if n > 0:
				times[snappedf(played.drive.moment(float(played.drive.legs[n][4])), 0.001)] = true
		times[snappedf(played.drive.seconds, 0.001)] = true
	played.key_times = times.keys()
	played.key_times.sort()
	if played.items.is_empty() and played.drive == null:
		return played
	# What carries another first: its parts are turned by both.
	played.order = played.items.duplicate()
	played.order.sort_custom(func(a: Item, b: Item) -> bool: return a.grab.moving.size() > b.grab.moving.size())
	played.count = maxi(roundi(length * float(fps)), 1) + 1
	return played


## [param played]'s next frames worked out, one at least, and then each
## that would end by Time.get_ticks_usec() [param until] if it took as long
## as the last (every one when 0): whether every frame is worked out.
func advance(played: Played, until: int = 0) -> bool:
	var length: float = played.seconds
	while played.next < played.count:
		var began: int = Time.get_ticks_usec()
		var t: float = minf(float(played.next) / float(played.fps), length)
		for item: Item in played.items:
			if not item.role.is_empty():
				continue
			var when: float = t if item.driver or not played.reverse else length - t
			_step(item, item.track.place_at(when))
		if played.drive != null:
			played.frames.append(_drive_frame(played, t))
		else:
			played.frames.append(_composed(played.order))
		played.next += 1
		var now: int = Time.get_ticks_usec()
		played.frame_ms = maxf(played.frame_ms, (now - began) / 1000.0)
		# Not begun past the slice: a frame begun just inside it, on a phone
		# slowed four times 46 to 66 ms, made a 40 ms slice 80 to 98 ms
		# (play_flow).
		if until > 0 and now + (now - began) >= until:
			break
	return played.next >= played.count


## [param played], every frame worked out, said: with [param keep] the
## model left where it ends, one step called [param words].
func finish(played: Played, keep: bool = false, words: String = "") -> void:
	if played.items.is_empty() and played.drive == null:
		return
	var length: float = played.seconds
	var reverse: bool = played.reverse
	for item: Item in played.items:
		item.to = item.track.place_at(length if item.driver or not reverse else 0.0) \
			if item.stop_words.is_empty() and item.role.is_empty() else _reached(item)
	if keep and not played.frames.is_empty():
		# A path's tracks kept where its last frame put them before the path
		# moved the model, and then the whole model moved: one step. Its
		# wheels' spin and its steering are not kept: they come to rest as
		# they were, and a kept drive is a rigid move of the whole model, so
		# a file keeps every sub-model's lines (drivereview F2). Kept, the
		# wheels made each copy of a sub-model placed twice its own.
		var kept_items: Array = played.order.filter(func(item: Item) -> bool: return item.role.is_empty())
		var last: Dictionary = played.frames.back()
		if played.drive != null:
			last = {}
			for item: Item in kept_items:
				for key: Variant in item.grab.placed:
					if played.local_last.has(key):
						last[key] = played.local_last[key]
		played.standing = grabbing.standing_with(last)
		for item: Item in kept_items:
			for key: Variant in item.grab.placed:
				if last.has(key):
					item.grab.placed[key] = last[key]
		var depth: int = builder.history_depth()
		var said_as: String = words if not words.is_empty() else "played %s" % Motions.quoted(played.name)
		var grabs: Array = kept_items.map(func(item: Item) -> Grab: return item.grab)
		played.kept = grabbing.keep_held(grabs, said_as) if not grabs.is_empty() else 0
		if played.drive != null:
			played.kept += _keep_driven(played, said_as)
			builder.fold_since(depth, said_as)
			if driven.is_valid():
				driven.call(drive_box(played))
		for item: Item in played.items:
			if item.driver and not reverse:
				_driven[played.name.to_lower()] = item.to - item.from
			elif item.driver:
				_driven.erase(played.name.to_lower())
	results[played.name.to_lower()] = said(played)


## What playing motions one after another did (play_in_order).
class Run extends RefCounted:
	## Each motion as it played (Played), in order.
	var played: Array = []
	## Every frame of them all, each with every part any of them moves
	## where it stands at that moment (MotionRender.whole_frames).
	var frames: Array = []
	## Each motion's own frames, as played.
	var each: Array = []

	## How the model stands where the last that moved left it.
	func standing() -> String:
		for k: int in range(played.size() - 1, -1, -1):
			if not (played[k] as Played).standing.is_empty():
				return (played[k] as Played).standing
		return ""

	func went() -> bool:
		return played.any(func(one: Played) -> bool: return one.went())

	func stopped() -> bool:
		return played.any(func(one: Played) -> bool: return one.stopped())


## [param order] (Motions.Motion, each a motion of its own: Motions.flat)
## played and kept one after another, each [param reverse]d, so each begins
## where the one before left the model: one step called [param words]. A
## sequence, Play all, a link's press of a sequence.
func play_in_order(order: Array, reverse: bool, words: String, fps: int = PLAY_FPS) -> Run:
	var paced: Paced = pace(order, reverse, words, fps)
	while not pace_on(paced, 0.0):
		pass
	return paced.run


## How long a paced run waits for the joints to be read on a worker, when
## no read is under way, before it reads them itself, ms.
const READ_WAIT_MS := 1000


## play_in_order's work, done a slice at a time ([method pace_on]): a
## link's press on a phone worked out two gates' 25 frames at once, 713 ms
## of one frame with the CPU slowed four times.
class Paced extends RefCounted:
	var order: Array = []
	var reverse: bool = false
	var words: String = ""
	var fps: int = 12
	var run := Run.new()
	## The history's depth when it began: folded to one step at the end.
	var depth: int = 0
	## The motion being worked out, and its number in the order.
	var at: int = 0
	var playing: Played = null
	var done: bool = false
	## How many slices it took, the longest of them and all of them, ms;
	## and the longest of what cannot be cut: a motion's joints taken hold
	## of, one frame, a motion kept.
	var slices: int = 0
	var longest_ms: float = 0.0
	var total_ms: float = 0.0
	var hold_ms: float = 0.0
	var frame_ms: float = 0.0
	var keep_ms: float = 0.0
	## When it began, or its last motion was kept, ms.
	var kept_at: int = 0
	## Whether it is kept, one step; false to work its frames out alone,
	## nothing changed (a link's motion played over and over, drawn only).
	## One motion only: a sequence's next begins where the last was kept.
	var keep: bool = true
	## Worked out whole on a worker ([method pace_off_frame]): its task, -1
	## for none; and whether it was, once.
	var task: int = -1
	var off_frame: bool = false
	## Whether parts that arrive are held back until it is one step
	## (ModelStore.hold_landings).
	var holding: bool = false


func pace(order: Array, reverse: bool, words: String, fps: int = PLAY_FPS) -> Paced:
	var paced := Paced.new()
	paced.order = order
	paced.reverse = reverse
	paced.words = words
	paced.fps = fps
	paced.depth = builder.history_depth()
	paced.kept_at = Time.get_ticks_msec()
	return paced


## [param paced] worked on for about [param budget_ms] (all of it when 0),
## a motion's joints taken hold of, a frame or a motion kept at least:
## whether it is all played and kept, one step, as play_in_order keeps it.
func pace_on(paced: Paced, budget_ms: float) -> bool:
	if paced.done:
		return true
	var began: int = Time.get_ticks_usec()
	var until: int = began + int(budget_ms * 1000.0) if budget_ms > 0.0 else 0
	while until == 0 or Time.get_ticks_usec() < until:
		if paced.playing == null:
			# A motion begins where the model stands, the next where the
			# last left it, its joints read again after a change: on a
			# worker where there are threads, waited for here rather than
			# read in this frame, where the house's 211 parts just after a
			# Reset took 96 ms of one (share_play_probe).
			# Read here only when no read is under way a second on.
			if until > 0 and paced.at < paced.order.size() and not grabbing.is_ready() and grabbing.reads_ahead() \
					and (grabbing.is_reading() or Time.get_ticks_msec() - paced.kept_at < READ_WAIT_MS):
				grabbing.read_soon()
				break
			if paced.at >= paced.order.size():
				for frames: Array in MotionRender.whole_frames(paced.run.each):
					paced.run.frames.append_array(frames)
				if paced.keep:
					builder.fold_since(paced.depth, paced.words)
				# One step now: what arrived while it was made is put down.
				_let_landings_go(paced)
				paced.done = true
				break
			var held_at: int = Time.get_ticks_usec()
			paced.playing = begin(paced.order[paced.at], paced.reverse, paced.fps)
			paced.hold_ms = maxf(paced.hold_ms, (Time.get_ticks_usec() - held_at) / 1000.0)
			continue
		if not advance(paced.playing, until):
			break
		paced.frame_ms = maxf(paced.frame_ms, paced.playing.frame_ms)
		var kept_at: int = Time.get_ticks_usec()
		finish(paced.playing, paced.keep or paced.order.size() > 1, paced.words if paced.order.size() == 1 else "")
		paced.keep_ms = maxf(paced.keep_ms, (Time.get_ticks_usec() - kept_at) / 1000.0)
		paced.kept_at = Time.get_ticks_msec()
		paced.run.played.append(paced.playing)
		paced.run.each.append(paced.playing.frames)
		paced.playing = null
		paced.at += 1
		# Kept, with more to come in the same step: a part put down before
		# the next is kept would be moved by it as one of the parts that
		# step moves itself, and its undo would leave it where it landed
		# (ModelStore.hold_landings).
		if paced.keep and paced.at < paced.order.size() and store != null and not paced.holding:
			paced.holding = true
			store.hold_landings(true)
	var spent: float = (Time.get_ticks_usec() - began) / 1000.0
	paced.slices += 1
	paced.longest_ms = maxf(paced.longest_ms, spent)
	paced.total_ms += spent
	return paced.done


## [param paced] worked out whole on a worker, not a slice a frame, when it
## keeps nothing (Paced.keep false: a link's motion, drawn over and over):
## whether it is done, asked each frame until it is. In a browser drawing in
## software a frame of a model just opened is 0.3 to 1.3 s, and the house's
## gates, 25 frames of 15 to 40 ms of work each, were worked out a slice a
## frame: 7 to 31 frames, 1 to 6 s after the press (playweb, 2026-11-07).
## On a worker the frames wait for none of it. What it reads stands still meanwhile, as for a section
## let go (GrabDrag.hold_still): a press waits for it, and parts that arrive
## are held aside. The joints are read first, never on the worker. Kept, or
## where there are no threads, [method pace_on]'s slices of [param
## budget_ms].
func pace_off_frame(paced: Paced, budget_ms: float) -> bool:
	if paced.task >= 0:
		if not WorkerThreadPool.is_task_completed(paced.task):
			return false
		drop(paced)
		return paced.done
	# Once only: what a worker left undone (a script error) goes on here.
	if paced.done or paced.keep or paced.off_frame or OS.has_feature("nothreads"):
		return pace_on(paced, budget_ms)
	if not grabbing.is_ready():
		if grabbing.reads_ahead():
			grabbing.read_soon()
			return false
		return pace_on(paced, budget_ms)
	paced.off_frame = true
	grabbing.hold_still(true)
	library.begin_reading()
	# Ahead of the shapes and geometry read a few at a time meanwhile: at low
	# priority the house's gates moved 2.1 s after the press for 0.16 s of
	# work, at high 0.3 s (playweb, 2026-11-07).
	paced.task = WorkerTasks.add(func() -> void:
		Exact.noting_worker = OS.get_thread_caller_id()
		pace_on(paced, 0.0)
		Exact.noting_worker = -1, true, "work out a link's motion")
	library.reading_in(paced.task)
	return false


## Parts held back while [param paced] was being made put down, now that it
## is one step or is dropped.
func _let_landings_go(paced: Paced) -> void:
	if paced.holding:
		paced.holding = false
		if store != null:
			store.hold_landings(false)


## [param paced]'s worker, if it has one, waited for and let go: what it
## read may change again. Before anything changes the model under it. And
## what arrived while it was being made put down: dropped, its steps are
## taken back after this, and an undo carries what landed late.
func drop(paced: Paced) -> void:
	if paced != null:
		_let_landings_go(paced)
	if paced == null or paced.task < 0:
		return
	WorkerTasks.collect(paced.task)
	library.end_reading(paced.task)
	paced.task = -1
	grabbing.hold_still(false)


## [param track]'s joint taken hold of for playing: an Item with its Grab,
## or with none and why in its stop words.
func _item_for(track: Motions.Track, driver: bool) -> Item:
	var item := Item.new()
	item.joint = track.joint
	item.track = track
	item.driver = driver
	var ids: Array = parts_of(track.joint)
	item.name = joint_name(track.joint)
	if ids.is_empty():
		item.stop_words = gone_words(track.joint)
		return item
	var taken: Variant = grabbing.held_of(ids, item.name)
	if taken is String:
		item.stop_words = str(taken)
		return item
	var held: Grab = taken
	if track.joint.mode == "slide":
		if not held.can_slide():
			item.stop_words = "it does not slide: nothing it is on is longer than the hole it is in"
			return item
		held.use_slide()
	elif held.mode == "slide" and held.linkage != null and not held.linkage.racks.is_empty():
		item.stop_words = grabbing.held_loop_words(held)
		return item
	elif held.mode != "turn":
		item.stop_words = "it %s; a motion turns this joint" % (
			"slides" if held.mode == "slide" else "turns on a ball")
		return item
	item.grab = held
	item.from = at_now(track.joint)
	return item


## What [param item]'s grab's turn is less than a place, the first place it
## is asked for being its track's at [param first_t].
static func _shift_for(item: Item, first_t: float) -> float:
	if item.joint.mode != "turn":
		return item.from
	# A whole turn either way is the same place: not turned round once to
	# get to it (a turntable keyed 0 to 360, played again).
	var first: float = item.track.place_at(first_t)
	return first - wrapf(first - item.from, -180.0, 180.0)


## Move [param item]'s joint towards [param place], as far as it has room,
## and note how far short it stopped.
func _step(item: Item, place: float) -> void:
	var held: Grab = item.grab
	var from: float = held.shift / BrickLattice.STUD if item.joint.mode == "slide" else held.angle
	var to: float = place - item.shift
	var steps: int = 1
	if held.linkage != null:
		steps = maxi(ceili(absf(to - from) / (LOOP_STEP_STUDS if item.joint.mode == "slide"
			else LOOP_STEP_DEG)), 1)
	for n: int in range(1, steps + 1):
		var value: float = lerpf(from, to, float(n) / float(steps))
		if item.joint.mode == "slide":
			held.slide_to(value * BrickLattice.STUD)
		else:
			held.turn_to(value)
	var reached: float = _reached(item)
	item.low = minf(item.low, reached)
	item.high = maxf(item.high, reached)
	var asked: float = place
	var detent: float = held.link.detent if held.link != null and item.joint.mode == "turn" else 0.0
	if detent > 0.0:
		# A click hinge stands on its clicks: the nearest is not short of it.
		asked = roundf((place - item.shift) / detent) * detent + item.shift
	var short: float = absf(asked - reached)
	var least: float = SHORT_DEG if item.joint.mode == "turn" else SHORT_STUDS
	if short > least and short > item.short_by + least:
		item.short_by = short
		item.stop_words = "%s stops at %s of the %s asked, where %s" % [item.name,
			_place_words(reached, item), _place_words(asked, item), _why_stopped(held)]
		item.met = int(held.blocked_by[1]) if held.blocked_by.size() == 2 else 0


func _reached(item: Item) -> float:
	if item.joint.mode == "slide":
		return item.grab.shift / BrickLattice.STUD + item.shift
	return item.grab.angle + item.shift


static func _place_words(value: float, item: Item) -> String:
	if item.joint.mode == "slide":
		return "%s studs" % Balance.studs(value)
	return "%d°" % roundi(value)


## What stopped [param held], in words: what met what, a loop that goes no
## further, a hose pulled to its length.
static func _why_stopped(held: Grab) -> String:
	if not held.stretch_words.is_empty():
		return "%s holds it, pulled to its full length" % held.stretch_words
	var met: String = GrabDrag._met_words(held)
	if not met.is_empty():
		return met
	if held.loop_short:
		return "its loop goes no further (%s)" % (held.linkage.said() if held.linkage != null else "a loop")
	return "it meets the model"


## The frame as every item stands: each item's parts where it puts them,
## a part two items move turned by both, the outer first.
static func _composed(order: Array) -> Dictionary:
	var out: Dictionary = {}
	for item: Item in order:
		var held: Grab = item.grab
		for key: Variant in held.placed:
			var to: Transform3D = held.placed[key]
			if out.has(key) and held.rest.has(key):
				out[key] = (out[key] as Transform3D) * (held.rest[key] as Transform3D).affine_inverse() * to
			else:
				out[key] = to
	return out


## What a play did, said: each joint from where to where, or where it
## stopped and on what; what would not play and why.
func said(played: Played) -> String:
	var lines := PackedStringArray()
	if played.drive != null:
		lines.append(_drive_words(played))
	for item: Item in played.items:
		if not item.role.is_empty():
			continue
		var least: float = SHORT_DEG if item.joint.mode == "turn" else SHORT_STUDS
		var between: String = ""
		if item.low < minf(item.from, item.to) - least or item.high > maxf(item.from, item.to) + least:
			between = " by way of %s and %s" % [_place_words(item.low, item), _place_words(item.high, item)]
		var slid: String = GrabDrag.slid_words(item.grab)
		if not slid.is_empty():
			slid = ", and " + slid
		if item.stop_words.is_empty():
			lines.append("%s went from %s to %s%s, clear all the way%s" % [item.name,
				_place_words(item.from, item), _place_words(item.to, item), between, slid])
		else:
			lines.append("%s; it ends at %s%s%s" % [item.stop_words, _place_words(item.to, item), slid,
				_own_words(played, item)])
	for line: String in played.refused:
		lines.append(line)
	return "; ".join(lines)


## [param joint] taken hold of to be moved by hand (the motions panel's
## slider for it): an Item whose grab moves it from where it stands, or
## with none and why in its stop words. [method step_to] moves it.
func hold(joint: Motions.Joint) -> Item:
	var track := Motions.Track.new()
	track.joint = joint
	var item: Item = _item_for(track, false)
	if item.grab != null:
		track.add_key(0.0, item.from)
		item.shift = item.from
	return item


## [param item]'s joint moved towards [param place] as far as it has room,
## and where it got to; its stop words say where and on what it stopped,
## if it did, this time.
func step_to(item: Item, place: float) -> float:
	item.short_by = 0.0
	item.stop_words = ""
	_step(item, place)
	return _reached(item)


## The joints a drag moves that have room to, each once, as a motion takes
## them (a part, or the sub-assembly that moves alike): what the motions
## panel offers a slider for, [param most] at most. What Playable names (a
## door, the steering, a boom) first, by the part it names, then the rest,
## biggest first. A ball is not offered, nor a joint with no room to move
## 10° (or half a stud) either way as a motion moves it (a wheel its arch
## holds, an arm a loop holds). Tried on its Grab, nothing changes; kept
## while the model has the same parts (a pose moves no joint in or out).
func movable(most: int = 16) -> Array:
	motions()
	var key: Array = [world.generation(), world.brick_count()]
	if key == _movable_for:
		return _movable
	_movable = []
	_movable_for = key
	grabbing.read_now()
	var bodies: Bodies = grabbing.read_bodies()
	if bodies == null:
		return _movable
	var named: Dictionary = {}   ## a part Playable names -> its order
	for ids: Variant in Playable.read(bodies, world, library, grabbing.read_mechanism()).values():
		for id: Variant in ids:
			if not named.has(int(id)):
				named[int(id)] = named.size()
	var moving: Array = []   ## [order, parts, body, the part to take it by]
	for body: Variant in bodies.parent_link:
		if bodies.flexible.has(body):
			continue
		var ids: PackedInt64Array = bodies.members.get(body, PackedInt64Array())
		if ids.is_empty():
			continue
		var by: int = int(ids[0])
		var order: int = 1 << 20
		for id: int in ids:
			if named.has(id) and int(named[id]) < order:
				order = int(named[id])
				by = id
		moving.append([order, ids.size(), int(body), by])
	moving.sort_custom(func(x: Array, y: Array) -> bool:
		return int(x[0]) < int(y[0]) or (int(x[0]) == int(y[0]) and int(x[1]) > int(y[1])))
	for one: Array in moving:
		if _movable.size() >= most:
			break
		var found: Variant = joint_named("#%d" % int(one[3]), false, true)
		if found is String:
			continue
		var joint: Motions.Joint = found
		if _movable.any(func(other: Motions.Joint) -> bool: return other == joint or other.same_ref(joint)):
			continue
		if not moves_at_all(joint):
			continue
		_movable.append(joint)
	return _movable


var _movable: Array = []
var _movable_for: Array = []


## Whether [param joint] has room to move 10° (or half a stud) one way or
## the other, held as a motion holds it.
func moves_at_all(joint: Motions.Joint) -> bool:
	var item: Item = hold(joint)
	if item.grab == null:
		return false
	var way: float = 10.0 if joint.mode == "turn" else 0.5
	var least: float = SHORT_DEG if joint.mode == "turn" else SHORT_STUDS
	return absf(step_to(item, item.from + way) - item.from) >= least \
		or absf(step_to(item, item.from - way) - item.from) >= least


## When [param item] stopped on a part another track of the same motion
## moves: why, and what to do. Each track is tested as if the others stood
## still, so a session's "Extend the telescope" that opened the dome and
## then turned the wheel stopped on the shut dome, and it took the dome to
## have opened too late.
func _own_words(played: Played, item: Item) -> String:
	if item.met == 0:
		return ""
	for other: Item in played.items:
		if other != item and other.grab != null and other.grab.moving.has(item.met):
			return (" (what it meets is moved by %s, another joint of this motion: a motion's joints are "
				+ "each tested as if the others stood still, so make that a motion of its own and this one after= it; "
				+ "play_motion sequence=true plays them in order, each from where the last left the "
				+ "model)") % other.name
	return ""


# -- a path: the whole model driven, its wheels turning (unit drive) -------------------------


## [param played]'s path made ready: its wheels and steering taken hold of
## as a track's joint is, the way the model faces and the middle of its back
## axle found from where they stand, the steering's place along the path
## worked out, and every part of the model noted, to be moved along it.
func _begin_drive(played: Played, path: Motions.Path, reverse: bool) -> void:
	var wheels: Array = []
	var steer: Item = null
	for joint: Motions.Joint in path.wheels + ([path.steer] if path.steer != null else []):
		var track := Motions.Track.new()
		track.joint = joint
		track.add_key(0.0, 0.0)
		var item: Item = _item_for(track, false)
		if item.grab == null:
			played.refused.append("%s: %s" % [item.name, item.stop_words])
			continue
		if joint == path.steer:
			item.role = "steer"
			item.shift = item.from
			steer = item
			played.items.append(item)
			continue
		if not _wheel_shape(item):
			played.refused.append("%s: it does not turn on a level line through its wheel, so it does not roll"
				% item.name)
			continue
		item.role = "wheel"
		item.shift = 0.0
		item.from = 0.0
		wheels.append(item)
		played.items.append(item)
	var layout: Array = _layout(wheels, steer)
	played.drive = Drive.new(path, layout[0], layout[1], reverse)
	played.path_said = path.said()
	var scenery: Dictionary = store.scenery if store != null else {}
	for brick: BrickWorld.Brick in world.bricks():
		if not scenery.has(brick.id):
			played.parts.append([brick.id, brick.transform])
	if steer != null:
		played.steering = _steering_for(played.drive, path, wheels, steer, played)
	for item: Item in wheels:
		_roll_table(played, item)


## Whether [param item]'s grab turns a wheel on a level line through it, and
## if so its axle's middle, line, radius and lead noted on it: the wheels and
## tyres it turns whose middles are on its line, their middle on the line,
## the biggest's radius (its tyre's), as each part's box says, across the
## line.
func _wheel_shape(item: Item) -> bool:
	var held: Grab = item.grab
	if held.mode != "turn" or held.axis == Vector3.ZERO:
		return false
	var line: Vector3 = held.axis.normalized()
	if absf(line.y) > LEVEL:
		return false
	var along: float = 0.0
	var count: int = 0
	var radius: float = 0.0
	var lead: int = 0
	for key: Variant in held.moving:
		var brick: BrickWorld.Brick = world.get_brick(int(key))
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		if info == null or not Playable.wheel_named(info.name):
			continue
		var at: Transform3D = held.rest.get(int(key), brick.transform)
		var middle: Vector3 = at * info.bounds.get_center()
		var off: Vector3 = middle - held.pivot
		if (off - line * off.dot(line)).length() > ON_THE_AXLE:
			continue
		# Across the line in the part's own frame: its box's two other sides.
		var own: Vector3 = (at.basis.inverse() * line).abs()
		var on: int = 0 if own.x >= own.y and own.x >= own.z else (1 if own.y >= own.z else 2)
		for side: int in 3:
			if side != on:
				radius = maxf(radius, info.bounds.size[side] * 0.5 * at.basis[side].length())
		along += off.dot(line)
		count += 1
		if lead == 0:
			lead = int(key)
	if count == 0 or radius <= 0.0:
		return false
	item.centre = held.pivot + line * (along / float(count))
	item.axis = line
	item.radius = radius
	item.lead = lead
	return true


## Where the path begins and the way the model faces, from its wheels as
## they stand: [the middle of its back axle on the ground, the way it
## faces]. Its sides are the line of an axle the steering does not turn,
## else of any; ahead is towards the steered wheels, else the first wheel
## kept (the front, as they were found: [method find_wheels]), else LDraw's
## front (-Z). With no wheels, the middle of the model's foot.
func _layout(wheels: Array, steer: Item) -> Array:
	var front := Vector3(0.0, 0.0, -1.0) * LdrModel.FLIP
	if wheels.is_empty():
		var box: AABB = _model_box()
		return [Vector3(box.get_center().x, box.position.y, box.get_center().z), front]
	var fixed: Array = wheels.filter(func(one: Item) -> bool: return not _steered(one, steer))
	var steered: Array = wheels.filter(func(one: Item) -> bool: return _steered(one, steer))
	var side: Vector3 = ((fixed[0] if not fixed.is_empty() else wheels[0]) as Item).axis
	var facing: Vector3 = Vector3.UP.cross(Vector3(side.x, 0.0, side.z).normalized()).normalized()
	var middle := Vector3.ZERO
	for one: Item in wheels:
		middle += one.centre / float(wheels.size())
	var toward: Vector3 = front
	if not fixed.is_empty() and not steered.is_empty():
		toward = _middle_of(steered) - _middle_of(fixed)
	elif (wheels[0] as Item).centre.distance_to(middle) > SAME_AXLE * 0.5:
		toward = (wheels[0] as Item).centre - middle
	if facing.dot(toward) < 0.0:
		facing = -facing
	var back: Array = fixed if not fixed.is_empty() else wheels
	var last: float = INF
	for one: Item in back:
		last = minf(last, one.centre.dot(facing))
	var axle: Array = back.filter(func(one: Item) -> bool: return one.centre.dot(facing) <= last + SAME_AXLE)
	var ground: float = INF
	for one: Item in wheels:
		ground = minf(ground, one.centre.y - one.radius)
	var pivot: Vector3 = _middle_of(axle)
	pivot.y = ground
	for one: Item in wheels:
		var heading: Vector3 = Vector3.UP.cross(one.axis)
		one.ahead = 1.0 if heading.dot(facing) >= 0.0 else -1.0
	return [pivot, facing]


static func _middle_of(items: Array) -> Vector3:
	var out := Vector3.ZERO
	for one: Item in items:
		out += one.centre / float(maxi(items.size(), 1))
	return out


## Whether the steering turns [param wheel] (it carries its lead part).
static func _steered(wheel: Item, steer: Item) -> bool:
	return steer != null and steer.grab != null and steer.grab.moving.has(wheel.lead)


## Whether every corner of [param box] is in [param camera]'s sight.
static func box_in_view(camera: Camera3D, box: AABB) -> bool:
	for n: int in 8:
		if not camera.is_position_in_frustum(box.get_endpoint(n)):
			return false
	return true


## All [param played]'s path takes the model over, from where it stands
## to where it ends, its corners too: its parts' bounds at a dozen of its
## frames and its last. An empty box where it has no path. What a view is
## framed on, and a floor laid under, so the model never drives out of
## either.
func drive_box(played: Played) -> AABB:
	var box := AABB()
	if played == null or played.drive == null or played.frames.is_empty():
		return box
	var first: bool = true
	var count: int = played.frames.size()
	var stride: int = maxi(1, count / 12)
	var at: int = 0
	while true:
		var frame: Dictionary = played.frames[at]
		for key: Variant in frame:
			var brick: BrickWorld.Brick = world.get_brick(int(key))
			var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
			if info == null:
				continue
			var one: AABB = (frame[key] as Transform3D) * info.bounds
			box = one if first else box.merge(one)
			first = false
		if at == count - 1:
			break
		at = mini(at + stride, count - 1)
	return box


func _model_box() -> AABB:
	var box := AABB()
	var first: bool = true
	var scenery: Dictionary = store.scenery if store != null else {}
	for brick: BrickWorld.Brick in world.bricks():
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null or scenery.has(brick.id):
			continue
		var one: AABB = brick.transform * info.bounds
		box = one if first else box.merge(one)
		first = false
	return box


## One frame of a path at [param t] seconds: the steering turned to its
## place along the way, each wheel turned as far as it has rolled (its
## axle's travel along the way its tyre points, over its tyre's radius,
## the steering carrying it), and then every part of the model moved along
## the path from where the joints put it.
func _drive_frame(played: Played, t: float) -> Dictionary:
	var drive: Drive = played.drive
	var s: float = drive.along(t)
	var whole: Transform3D = drive.moved(t)
	var wheels: Array = []
	for item: Item in played.items:
		if item.role == "steer" and played.steering != null:
			_step(item, played.steering.place_at(s))
		elif item.role == "wheel":
			wheels.append(item)
	# Each wheel turned as far as it has rolled by here, from where it
	# began: by how far along it is, not frame by frame, so backwards
	# undoes it exactly. Rolled ahead, a wheel turns about its line the way
	# that keeps its bottom still on the ground: about UP x heading.
	var began: float = drive.total if drive.reverse else 0.0
	for item: Item in wheels:
		var heading: Vector3 = Vector3.UP.cross(item.axis) * item.ahead
		var spin: float = signf(item.axis.dot(Vector3.UP.cross(heading)))
		_step(item, rad_to_deg((_rolled(item, s, drive) - _rolled(item, began, drive)) / item.radius) * spin)
	var local: Dictionary = _composed(played.order)
	played.local_last = local
	var out: Dictionary = {}
	for one: Array in played.parts:
		out[one[0]] = whole * (local.get(one[0], one[1]) as Transform3D)
	return out


## [param item]'s roll worked out along [param played]'s path, at every
## ROLL_STEP: how far its middle has gone along the way its tyre points
## (the mean of the ways at each end of a step), the steering carrying it
## as it was tried. Backwards, the same way laid from its end.
func _roll_table(played: Played, item: Item) -> void:
	var drive: Drive = played.drive
	var count: int = maxi(ceili(drive.total / ROLL_STEP), 1)
	item.rolls = PackedFloat64Array()
	item.rolls.resize(count + 1)
	var rolled: float = 0.0
	var last := Vector3.ZERO
	var last_heading := Vector3.ZERO
	for j: int in count + 1:
		var shape: Array = _wheel_at(played, item, drive.total * float(j) / float(count))
		var heading: Vector3 = Vector3.UP.cross(shape[1] as Vector3).normalized() * item.ahead
		if j > 0:
			rolled += ((shape[0] as Vector3) - last).dot((heading + last_heading).normalized())
		item.rolls[j] = rolled
		last = shape[0]
		last_heading = heading


## How far [param item] has rolled [param s] LDU along, from its table.
static func _rolled(item: Item, s: float, drive: Drive) -> float:
	var count: int = item.rolls.size() - 1
	if count < 1 or drive.total <= 0.0:
		return 0.0
	var at: float = clampf(s / drive.total, 0.0, 1.0) * float(count)
	var j: int = mini(floori(at), count - 1)
	return lerpf(item.rolls[j], item.rolls[j + 1], at - float(j))


## Where [param item]'s middle is and its line points [param s] LDU along
## [param played]'s path: [middle, line], the world's.
func _wheel_at(played: Played, item: Item, s: float) -> Array:
	var whole: Transform3D = played.drive.at_along(s)
	var centre: Vector3 = item.centre
	var line: Vector3 = item.axis
	var tried: Array = played.tried
	if played.steering != null and tried.size() >= 2 and (tried[0][2] as Dictionary).has(item.lead):
		var steer: Item = null
		for one: Item in played.items:
			if one.role == "steer":
				steer = one
		var place: float = played.steering.place_at(s) - steer.from
		var k: int = 0
		while k < tried.size() - 2 and place > float(tried[k + 1][0]):
			k += 1
		var a: Array = tried[k]
		var b: Array = tried[k + 1]
		var w: float = clampf((place - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
		var at_a: Array = (a[2] as Dictionary)[item.lead]
		var at_b: Array = (b[2] as Dictionary)[item.lead]
		line = (at_a[0] as Vector3).lerp(at_b[0] as Vector3, w).normalized()
		centre = (at_a[1] as Vector3).lerp(at_b[1] as Vector3, w)
	return [whole * centre, (whole.basis * line).normalized()]


## The model moved where [param played]'s path ends, every part of it by one
## rigid move squared and rounded as a file writes it (Motions.tidied), as a
## grab keeps the parts it moves (Grab.commit): no part left behind, its
## joints read where they stand from where they were built as before. The
## move is kept with the motions (Motions.moved), so someone else's file is
## written with only its main model's lines moved. Returns how many parts
## moved.
func _keep_driven(played: Played, words: String) -> int:
	# Its end as the file writes it, in the file's coordinates, then back
	# where the model stands: every part moved by the one tidied move.
	var lift := Transform3D(Basis.IDENTITY, store.lift() if store != null else Vector3.ZERO)
	var in_file: Transform3D = Motions.tidied(lift.affine_inverse() * played.drive.moved(played.drive.seconds) * lift)
	if in_file.is_equal_approx(Transform3D.IDENTITY):
		return 0
	var whole: Transform3D = lift * in_file * lift.affine_inverse()
	var moving := Grab.new()
	moving.world = world
	moving.builder = builder
	moving.library = library
	# Every part of the model as it is now, those that landed while it
	# played as well (ModelStore.place_awaited): one put down after the play
	# began was left where the model had stood.
	var scenery: Dictionary = store.scenery if store != null else {}
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		moving.rest[brick.id] = brick.transform
		moving.placed[brick.id] = whole * brick.transform
	var had: Motions = motions().copy()
	var moved: int = moving.commit(words)
	if moved > 0:
		# Where the model went, kept with its motions: an undo takes both back.
		motions().moved = in_file * motions().moved
		builder.record([{"undo": "motions", "motions": had}], words)
	grabbing.edited.call()
	return moved


## The steering's place along [param drive], LDU -> degrees from where it
## was built: straight on the straights, and in each corner as far as
## brings the steered wheels' middle to point along it (each wheel's own
## line through the corner's middle, Ackermann's), turned in and out over a
## few studs at the corner's ends. Found by trying the steering on its own
## Grab, nothing changed: what it cannot reach is said in [param played].
func _steering_for(drive: Drive, path: Motions.Path, wheels: Array, steer: Item, played: Played) -> Motions.Track:
	var steered: Array = wheels.filter(func(one: Item) -> bool: return _steered(one, steer))
	if steered.is_empty():
		return null
	var tried: Array = _steer_tried(steer, steered, drive)
	if tried.size() < 2:
		return null
	played.tried = tried
	var straight: float = _steer_for_yaw(tried, 0.0)
	var track := Motions.Track.new()
	var values: Array = []   ## each leg's place
	var short := PackedStringArray()
	for n: int in drive.legs.size():
		var leg: Array = drive.legs[n]
		if str(leg[0]) == "STRAIGHT":
			values.append(straight)
			continue
		var wanted: float = _corner_yaw(steered, drive, float(leg[1]), float(leg[3]))
		var angle: float = _steer_for_yaw(tried, wanted)
		var reached: float = _yaw_at(tried, angle)
		if absf(reached - wanted) > deg_to_rad(1.0):
			short.append("the %s corner asks the front wheels %d°, and the steering reaches %d°" % [
				str(leg[0]).to_lower(), roundi(rad_to_deg(absf(wanted))), roundi(rad_to_deg(absf(reached)))])
		values.append(angle)
	played.steer_words = "; ".join(short)
	# Keys by how far along: each leg's place from a little after it begins
	# to a little before it ends, turned between; where it stands at both
	# ends, so backwards brings it back exactly.
	track.add_key(0.0, steer.from, "EASE")
	for n: int in drive.legs.size():
		var leg: Array = drive.legs[n]
		var start: float = float(leg[4])
		var length: float = float(leg[2])
		var ramp: float = clampf(length * 0.25, STEER_RAMP_LEAST * BrickLattice.STUD,
			STEER_RAMP_MOST * BrickLattice.STUD) * 0.5
		var first: float = minf(start + ramp, start + length * 0.5)
		var then: float = maxf(start + length - ramp, start + length * 0.5)
		track.add_key(first, steer.from + float(values[n]), "EASE")
		track.add_key(then, steer.from + float(values[n]), "EASE")
	track.add_key(drive.total, steer.from, "EASE")
	return track


## The steering tried from where it stands to as far as it goes each way, a
## few places between: [[degrees turned, the steered wheels' middle turned
## left from ahead, radians, {each steered wheel's lead: [its line, its
## middle] where it carries it}]], in order of degrees.
func _steer_tried(steer: Item, steered: Array, drive: Drive) -> Array:
	var taken: Variant = grabbing.held_of(parts_of(steer.joint), steer.name)
	if taken is String:
		return []
	var held: Grab = taken
	var most: float = 120.0 if _named_like(int(parts_of(steer.joint)[0]), "Steering Wheel") else 45.0
	var one: float = held.turn_to(most)
	held.turn_to(0.0)
	var other: float = held.turn_to(-most)
	var out: Array = []
	for k: int in 9:
		var asked: float = lerpf(other, one, float(k) / 8.0)
		var reached: float = held.turn_to(asked)
		var yaw: float = 0.0
		var carried: Dictionary = {}
		for wheel: Item in steered:
			var carry := Transform3D.IDENTITY
			if held.placed.has(wheel.lead) and held.rest.has(wheel.lead):
				carry = (held.placed[wheel.lead] as Transform3D) * (held.rest[wheel.lead] as Transform3D).affine_inverse()
			var line: Vector3 = (carry.basis * wheel.axis).normalized()
			var heading: Vector3 = Vector3.UP.cross(line) * wheel.ahead
			yaw += atan2(heading.dot(drive.left), heading.dot(drive.forward)) / float(steered.size())
			carried[wheel.lead] = [line, carry * wheel.centre]
		if out.is_empty() or reached > float(out.back()[0]) + 0.01:
			out.append([reached, yaw, carried])
	held.turn_to(0.0)
	return out


## The steered wheels' middle turned left from ahead (radians) that a
## corner [param way] (1 left, -1 right) of [param radius] LDU asks: each
## wheel's own line through the corner's middle.
static func _corner_yaw(steered: Array, drive: Drive, way: float, radius: float) -> float:
	var sum: float = 0.0
	for wheel: Item in steered:
		var off: Vector3 = wheel.centre - drive.pivot
		sum += way * atan2(off.dot(drive.forward), radius - way * off.dot(drive.left))
	return sum / float(steered.size())


## The steering's degrees that turn the wheels [param yaw], read off what
## was [param tried] between the two nearest; as far as it goes past them.
static func _steer_for_yaw(tried: Array, yaw: float) -> float:
	var best: float = float(tried[0][0])
	var nearest: float = INF
	for k: int in tried.size() - 1:
		var a: Array = tried[k]
		var b: Array = tried[k + 1]
		var low: float = minf(float(a[1]), float(b[1]))
		var high: float = maxf(float(a[1]), float(b[1]))
		if yaw >= low and yaw <= high and high > low:
			return lerpf(float(a[0]), float(b[0]), (yaw - float(a[1])) / (float(b[1]) - float(a[1])))
	for one: Array in tried:
		if absf(float(one[1]) - yaw) < nearest:
			nearest = absf(float(one[1]) - yaw)
			best = float(one[0])
	return best


static func _yaw_at(tried: Array, angle: float) -> float:
	for k: int in tried.size() - 1:
		var a: Array = tried[k]
		var b: Array = tried[k + 1]
		if angle >= float(a[0]) and angle <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (angle - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001))
	return float(tried[0][1]) if angle < float(tried[0][0]) else float(tried.back()[1])


## The model's wheels that stand on the ground, each a joint as a motion
## takes it (an axle and the wheels it turns, once), the front first: those
## the steering turns, else those to LDraw's front (-Z). A wheel or a tyre
## by its name (Playable.wheel_named) on a level line through it; a spare
## wheel on the back, or one off the ground, is not one. Tried on its Grab,
## nothing changes.
func find_wheels() -> Array:
	motions()
	grabbing.read_now()
	var scenery: Dictionary = store.scenery if store != null else {}
	var seen: Dictionary = {}
	var found: Array = []   ## Item, its joint
	for brick: BrickWorld.Brick in world.bricks():
		if seen.has(brick.id) or scenery.has(brick.id):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null or not Playable.wheel_named(info.name):
			continue
		var taken: Variant = grabbing.held_of([brick.id], "#%d" % brick.id)
		if taken is String:
			seen[brick.id] = true
			continue
		var item := Item.new()
		item.grab = taken
		for key: Variant in item.grab.moving:
			seen[int(key)] = true
		if not _wheel_shape(item):
			continue
		var joint: Variant = joint_named("#%d" % item.lead, false, true)
		if joint is String:
			continue
		item.joint = joint
		found.append(item)
	var ground: float = INF
	for item: Item in found:
		ground = minf(ground, item.centre.y - item.radius)
	found = found.filter(func(item: Item) -> bool: return item.centre.y - item.radius <= ground + ON_THE_GROUND)
	var steer: Item = _steering_item()
	var front := Vector3(0.0, 0.0, -1.0) * LdrModel.FLIP
	found.sort_custom(func(a: Item, b: Item) -> bool:
		var first: bool = _steered(a, steer)
		if first != _steered(b, steer):
			return first
		return a.centre.dot(front) > b.centre.dot(front) + 0.01)
	return found.map(func(item: Item) -> Motions.Joint: return item.joint)


## The steering as a path turns it (Playable's: a steering wheel, else its
## arms), taken hold of; null where the model has none that turns.
func _steering_item() -> Item:
	var bodies: Bodies = grabbing.read_bodies()
	if bodies == null:
		return null
	var found: Dictionary = Playable.read(bodies, world, library, grabbing.read_mechanism())
	if not found.has("steering"):
		return null
	var joint: Variant = joint_named("#%d" % int((found["steering"] as Array)[0]), false, false)
	if not (joint is Motions.Joint):
		return null
	var track := Motions.Track.new()
	track.joint = joint
	var item: Item = _item_for(track, false)
	return item if item.grab != null else null


## A path for the model as it stands: [param legs] (Motions.leg_of's; when
## empty, a 32-stud straight and a quarter turn to the left on the tightest
## corner its steering takes well), over [param seconds] (at 10 studs a
## second when 0), [param how] it starts and stops; its wheels and steering
## found ([method find_wheels]). Nothing changes.
func drive_path(legs: Array = [], seconds: float = 0.0, how: String = "EASE") -> Motions.Path:
	var path := Motions.Path.new()
	path.how = how
	path.wheels = find_wheels()
	var steer: Item = _steering_item()
	if steer != null and not path.wheels.is_empty():
		path.steer = steer.joint
	path.legs = legs.duplicate(true) if not legs.is_empty() else [["STRAIGHT", DRIVE_STRAIGHT, 0.0],
		["LEFT", DRIVE_CORNER, corner_radius(path)]]
	path.seconds = seconds if seconds > 0.0 else clampf(ceilf(path.studs() / DRIVE_SPEED), 1.0,
		Motions.MOST_SECONDS)
	return path


## The tightest corner the model takes well, studs round, measured at the
## middle of its back axle: where its steering, a quarter short of the
## most it turns, points its front wheels through the corner's middle; with
## no steering, twice from its back axle to its front (16 studs with no
## wheels).
func corner_radius(path: Motions.Path) -> float:
	var probe := Motions.Motion.new()
	probe.path = Motions.Path.new()
	probe.path.wheels = path.wheels
	probe.path.steer = path.steer
	probe.path.legs = [["STRAIGHT", 1.0, 0.0]]
	probe.path.seconds = 1.0
	var played := Played.new()
	_begin_drive(played, probe.path, false)
	var wheels: Array = played.items.filter(func(one: Item) -> bool: return one.role == "wheel")
	var steer: Item = null
	for one: Item in played.items:
		if one.role == "steer":
			steer = one
	if wheels.is_empty():
		return 16.0
	var reach: float = 0.0
	for one: Item in wheels:
		reach = maxf(reach, (one.centre - played.drive.pivot).dot(played.drive.forward))
	var steered: Array = wheels.filter(func(one: Item) -> bool: return _steered(one, steer))
	if steer != null and not steered.is_empty():
		var tried: Array = _steer_tried(steer, steered, played.drive)
		var most: float = 0.0
		for one: Array in tried:
			most = maxf(most, absf(float(one[1])))
		if most > deg_to_rad(3.0) and reach > 0.0:
			return clampf(ceilf(reach / tan(most * STEER_SHARE) / BrickLattice.STUD), Motions.LEAST_RADIUS,
				Motions.MOST_RADIUS)
	return clampf(ceilf(maxf(reach * 2.0 / BrickLattice.STUD, 8.0)), Motions.LEAST_RADIUS, Motions.MOST_RADIUS)


## What turns as [param path] rolls, said: "3 wheels turn as it rolls
## (#73, #81, #75), and #80 steers it into the corners."
func path_words(path: Motions.Path) -> String:
	var names := PackedStringArray()
	for joint: Motions.Joint in path.wheels:
		names.append(joint_name(joint) if not parts_of(joint).is_empty() else gone_words(joint))
	var wheels: String = "No wheel turns as it rolls: none stands on the ground on a level axle" \
		if names.is_empty() else ("1 wheel turns as it rolls (%s)" % names[0] if names.size() == 1
			else "%d wheels turn as it rolls (%s)" % [names.size(), ", ".join(names)])
	if path.steer == null:
		return "%s." % wheels
	return "%s, and %s steers it into the corners." % [wheels, joint_name(path.steer)
		if not parts_of(path.steer).is_empty() else gone_words(path.steer)]


## A path from a session's path= ({"legs": [{"straight": 32}, {"left": 90,
## "radius": 24}], "seconds": 7, "eased": true}), read at the edge, its
## wheels and steering found; or why not. A turn's radius when omitted is
## the tightest corner the model takes well (corner_radius).
func path_from(given: Dictionary) -> Variant:
	# Each word and each value checked for what it is: a leg of [1] or
	# seconds of {} stopped the script, and a word path= has no was let by
	# (drivereview F7).
	for key: Variant in given:
		if not str(key) in ["legs", "seconds", "eased"]:
			return "path= takes legs=, seconds= and eased=, not %s=." % str(key)
	var legs: Array = []
	var asked: Variant = given.get("legs", [])
	if not (asked is Array):
		return "path= legs= is a list: [{\"straight\": 32}, {\"left\": 90}]."
	# Its wheels and steering found once; its corner only when one asks it.
	var path: Motions.Path = drive_path([["STRAIGHT", DRIVE_STRAIGHT, 0.0]])
	var corner: float = -1.0
	for raw: Variant in asked:
		if not (raw is Dictionary):
			return "Each leg is {\"straight\": studs}, or {\"left\": degrees} or {\"right\": degrees} with radius= studs."
		var leg: Dictionary = raw
		var kind: String = ""
		for word: Variant in leg:
			if not str(word) in ["straight", "left", "right", "radius"]:
				return "A leg takes straight=, left= or right=, and radius=, not %s=." % str(word)
		for word: String in ["straight", "left", "right"]:
			if leg.has(word):
				if not kind.is_empty():
					return "A leg is one of straight, left or right: %s has two." % JSON.stringify(leg)
				kind = word
		if kind.is_empty():
			return "A leg is {\"straight\": studs}, {\"left\": degrees} or {\"right\": degrees}: not %s." % JSON.stringify(leg)
		if not _is_number(leg[kind]):
			return "A leg's %s= is a number of %s, not %s." % [kind, "studs" if kind == "straight" else "degrees",
				JSON.stringify(leg[kind])]
		var radius: float = 0.0
		if kind == "straight":
			if leg.has("radius"):
				return "A straight has no radius=: only a turn, left= or right=, has one."
		elif leg.has("radius"):
			if not _is_number(leg["radius"]):
				return "A turn's radius= is a number of studs, not %s." % JSON.stringify(leg["radius"])
			radius = float(leg["radius"])
		else:
			if corner < 0.0:
				corner = corner_radius(path)
			radius = corner
		var made: Variant = Motions.leg_of(kind, float(leg[kind]), radius)
		if made is String:
			return "%s%s." % [str(made).left(1).to_upper(), str(made).substr(1)]
		legs.append(made)
	if legs.size() > Motions.MOST_LEGS:
		return "A path has at most %d legs, not %d." % [Motions.MOST_LEGS, legs.size()]
	path.legs = legs if not legs.is_empty() else [["STRAIGHT", DRIVE_STRAIGHT, 0.0],
		["LEFT", DRIVE_CORNER, corner if corner > 0.0 else corner_radius(path)]]
	if given.has("seconds"):
		if not _is_number(given["seconds"]):
			return "path= seconds= is a number of seconds, not %s." % JSON.stringify(given["seconds"])
		var seconds: Variant = Motions.path_seconds_of(float(given["seconds"]))
		if seconds is String:
			return "path= seconds=: %s (left out, it goes at %d studs a second)." % [str(seconds),
				int(DRIVE_SPEED)]
		path.seconds = seconds
	else:
		path.seconds = clampf(ceilf(path.studs() / DRIVE_SPEED), 1.0, Motions.MOST_SECONDS)
	if given.has("eased") and not (given["eased"] is bool):
		return "path= eased= is true or false, not %s." % JSON.stringify(given["eased"])
	path.how = "EASE" if bool(given.get("eased", true)) else "LINEAR"
	return path


## Whether [param value], read from a session's JSON, is a number: not a
## true or false, a list or words.
static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


## What a path did, said: how far the model went, each wheel's turns, the
## steering, and what would not roll.
func _drive_words(played: Played) -> String:
	var lines := PackedStringArray()
	var drive: Drive = played.drive
	lines.append("the model drove %s%s (%s studs in all)" % [played.path_said,
		" backwards to where it began" if played.reverse else "", Balance.studs(drive.total / BrickLattice.STUD)])
	var turned := PackedStringArray()
	for item: Item in played.items:
		if item.role != "wheel":
			continue
		if not item.stop_words.is_empty():
			turned.append(item.stop_words)
			continue
		turned.append("%s %s times" % [item.name, Motions.num(absf(_reached(item)) / 360.0, 2)])
	if not turned.is_empty():
		lines.append("its wheels turned as they rolled, once for each round of their tyres: %s" % ", ".join(turned))
	else:
		lines.append("no wheel of it rolls (a wheel or a tyre on a level axle, on the ground)")
	for item: Item in played.items:
		if item.role == "steer":
			lines.append("%s steered it into the corners, by way of %s and %s%s" % [item.name,
				_place_words(item.low, item), _place_words(item.high, item),
				(" (%s)" % played.steer_words) if not played.steer_words.is_empty() else ""])
	return "; ".join(lines)


# -- suggested from what moves -------------------------------------------------------------


## Motions proposed from what moves, as its link's card says it (Playable):
## the doors opened, the steering turned each way, the boom lifted, the
## turntable turned round, the gears and a rack driven. Each moved only as
## far as it has room, found by trying it (nothing changes). Kept per
## revision of the model.
func suggest() -> Array:
	motions()
	if _suggested_at == world.revision:
		return _suggested
	_suggested = []
	_suggested_at = world.revision
	grabbing.read_now()
	var bodies: Bodies = grabbing.read_bodies()
	if bodies == null:
		return _suggested
	var found: Dictionary = Playable.read(bodies, world, library, grabbing.read_mechanism())
	if found.has("doors"):
		var doors: Array = (found["doors"] as Array).slice(0, 4)
		var motion := _motion("Open the door" if doors.size() == 1 else "Open the doors")
		for id: Variant in doors:
			var room: Array = _room("#%d" % int(id), 90.0)
			if room.is_empty():
				continue
			# The way it opens is the way it has room: a door is built shut
			# against its frame.
			var way: float = float(room[1]) if absf(float(room[1])) > absf(float(room[2])) else float(room[2])
			# A rail with a little play is not a door to open.
			if absf(way) >= 15.0:
				_track(motion, room[0], [[0.0, 0.0], [2.0, roundf(way)]])
		_offer(motion)
	if found.has("steering"):
		var id: int = int((found["steering"] as Array)[0])
		var wheel: bool = _named_like(id, "Steering Wheel")
		var room: Array = _room("#%d" % id, 90.0 if wheel else 30.0)
		if not room.is_empty():
			var reach: float = minf(absf(float(room[1])), absf(float(room[2])))
			if reach >= 3.0:
				var motion := _motion("Steer left and right")
				_track(motion, room[0], [[0.0, 0.0], [1.0, reach], [3.0, -reach], [4.0, 0.0]])
				_offer(motion)
	if found.has("boom"):
		var id: int = int((found["boom"] as Array)[0])
		var up: Array = _room("#%d" % id, 45.0, true)
		if not up.is_empty() and absf(float(up[1])) >= 5.0:
			var motion := _motion("Lift the boom")
			_track(motion, up[0], [[0.0, 0.0], [2.0, float(up[1])]])
			_offer(motion)
	if found.has("turntable"):
		var id: int = int((found["turntable"] as Array)[0])
		var room: Array = _room("#%d" % id, 360.0)
		if not room.is_empty():
			var motion := _motion("Turn the turntable")
			if absf(float(room[1])) >= 359.0:
				_track(motion, room[0], [[0.0, 0.0], [6.0, 360.0]], "LINEAR")
			else:
				_track(motion, room[0], [[0.0, 0.0], [2.0, float(room[1])], [6.0, float(room[2])],
					[8.0, 0.0]])
			_offer(motion)
	for kind: String in ["gears", "rack"]:
		if not found.has(kind):
			continue
		var id: int = int((found[kind] as Array)[0])
		var joint: Variant = joint_named("#%d" % id, false, false)
		if joint is Motions.Joint:
			var motion := _motion("Turn the gears" if kind == "gears" else "Drive the rack")
			motion.driver = joint
			motion.turns = 1.0
			motion.driver_seconds = 4.0
			_offer(motion)
	# On wheels: driven 32 studs and round a corner to the left, its wheels
	# turning as they roll and its steering into the corner (unit drive).
	var path: Motions.Path = drive_path()
	if not path.wheels.is_empty():
		var drive := _motion(DRIVE_NAME)
		drive.path = path
		_offer(drive)
	return _suggested


func _motion(name: String) -> Motions.Motion:
	var motion := Motions.Motion.new()
	motion.name = name
	return motion


func _offer(motion: Motions.Motion) -> void:
	if not motion.tracks.is_empty() or motion.driver != null or motion.path != null:
		_suggested.append(motion)


func _track(motion: Motions.Motion, joint: Motions.Joint, keys: Array, how: String = "EASE") -> void:
	var track := Motions.Track.new()
	track.joint = joint
	for key: Array in keys:
		track.add_key(float(key[0]), joint.at + float(key[1]), how)
	motion.tracks.append(track)


## Whether part [param id]'s name has [param words] in it.
func _named_like(id: int, words: String) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(id)
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
	return info != null and info.name.contains(words)


## How far [param asked]'s joint has room to turn each way, up to [param
## most] degrees, trying it on its Grab (nothing changes): [joint, the most
## one way, the most the other], or [] when it does not turn. [param lifts]:
## the first is the way its weight rises, the second unused.
func _room(asked: String, most: float, lifts: bool = false) -> Array:
	var found: Variant = _joint_and_held(asked, false, false)
	if found is String:
		return []
	var joint: Motions.Joint = (found as Array)[0]
	var held: Grab = (found as Array)[1]
	if held.mode != "turn":
		return []
	if lifts:
		held.turn_to(5.0)
		var way: float = 1.0 if _height(held.placed) > _height(held.rest) else -1.0
		held.turn_to(0.0)
		return [joint, held.turn_to(most * way), 0.0]
	var one: float = held.turn_to(most)
	held.turn_to(0.0)
	var other: float = held.turn_to(-most)
	return [joint, one, other]


## The mean height of [param placed]'s parts, LDU.
static func _height(placed: Dictionary) -> float:
	var sum: float = 0.0
	for key: Variant in placed:
		sum += (placed[key] as Transform3D).origin.y
	return sum / maxf(float(placed.size()), 1.0)
