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
const SHORT_STUDS := 0.05
## A part found again by its number and colour this near where its ref
## says, LDU: a fifth of a stud.
const PLACE_SLACK := 4.0
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
	var lead: BrickWorld.Brick = world.get_brick(joint.lead) if joint.lead != 0 else null
	if lead != null and lead.part_id == joint.part and lead.color_code == joint.colour:
		return [lead.id]
	# Again by its number, colour and place: a file opened, or the part put
	# back by an undo as another number.
	var want: Vector3 = joint.place * LdrModel.FLIP + (store.lift() if store != null else Vector3.ZERO)
	var best: int = 0
	var nearest: float = PLACE_SLACK
	for brick: BrickWorld.Brick in world.bricks():
		if brick.part_id != joint.part or brick.color_code != joint.colour:
			continue
		var off: float = brick.transform.origin.distance_to(want)
		if off < nearest:
			nearest = off
			best = brick.id
	if best != 0:
		joint.lead = best
		return [best]
	return []


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

	func stopped() -> bool:
		for item: Item in items:
			if not item.stop_words.is_empty():
				return true
		return false

	## Whether any joint moved on the way, wherever it ended.
	func went() -> bool:
		for item: Item in items:
			if item.high - item.low > (MotionPlayer.SHORT_DEG if item.joint.mode == "turn"
					else MotionPlayer.SHORT_STUDS):
				return true
		return false


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
	played.key_times = times.keys()
	played.key_times.sort()
	if played.items.is_empty():
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
			var when: float = t if item.driver or not played.reverse else length - t
			_step(item, item.track.place_at(when))
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
	if played.items.is_empty():
		return
	var length: float = played.seconds
	var reverse: bool = played.reverse
	for item: Item in played.items:
		item.to = item.track.place_at(length if item.driver or not reverse else 0.0) \
			if item.stop_words.is_empty() else _reached(item)
	if keep:
		var last: Dictionary = played.frames.back()
		played.standing = grabbing.standing_with(last)
		for item: Item in played.order:
			for key: Variant in item.grab.placed:
				if last.has(key):
					item.grab.placed[key] = last[key]
		var grabs: Array = played.order.map(func(item: Item) -> Grab: return item.grab)
		played.kept = grabbing.keep_held(grabs, words if not words.is_empty()
			else "played %s" % Motions.quoted(played.name))
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
			# worker for a big model (any model in a link's viewer), waited
			# for here rather than read in this frame, where the house's 211
			# parts just after a Reset took 96 ms of one (share_play_probe).
			# Read here only when no read is under way a second on.
			if until > 0 and paced.at < paced.order.size() and not grabbing.is_ready() and grabbing.reads_ahead() \
					and (grabbing.is_reading() or Time.get_ticks_msec() - paced.kept_at < READ_WAIT_MS):
				grabbing.read_soon()
				break
			if paced.at >= paced.order.size():
				for frames: Array in MotionRender.whole_frames(paced.run.each):
					paced.run.frames.append_array(frames)
				builder.fold_since(paced.depth, paced.words)
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
		finish(paced.playing, true, paced.words if paced.order.size() == 1 else "")
		paced.keep_ms = maxf(paced.keep_ms, (Time.get_ticks_usec() - kept_at) / 1000.0)
		paced.kept_at = Time.get_ticks_msec()
		paced.run.played.append(paced.playing)
		paced.run.each.append(paced.playing.frames)
		paced.playing = null
		paced.at += 1
	var spent: float = (Time.get_ticks_usec() - began) / 1000.0
	paced.slices += 1
	paced.longest_ms = maxf(paced.longest_ms, spent)
	paced.total_ms += spent
	return paced.done


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
	for item: Item in played.items:
		var least: float = SHORT_DEG if item.joint.mode == "turn" else SHORT_STUDS
		var between: String = ""
		if item.low < minf(item.from, item.to) - least or item.high > maxf(item.from, item.to) + least:
			between = " by way of %s and %s" % [_place_words(item.low, item), _place_words(item.high, item)]
		var slid: String = slid_words(item.grab)
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


## What a turn drove along a rack, said: "the Technic Gear Rack 1 x 4
## (#170) slid 4.4 studs toward +x, and 23 parts with it". A session asked
## to turn the observatory's wheel was told only that the wheel turned 612°,
## and had to work out that the telescope slid. Empty when [param held]
## drives no rack, or its rack stood still.
static func slid_words(held: Grab) -> String:
	if held == null or held.linkage == null or held.bodies == null:
		return ""
	var out := PackedStringArray()
	for mesh: Racks.Pinion in held.linkage.racks:
		if not held.placed.has(mesh.rack) or not held.rest.has(mesh.rack):
			continue
		var moved: Vector3 = (held.placed[mesh.rack] as Transform3D).origin \
			- (held.rest[mesh.rack] as Transform3D).origin
		if moved.length() < SHORT_STUDS * BrickLattice.STUD:
			continue
		var with: int = 0
		for key: Variant in held.placed:
			if int(key) != mesh.rack and held.rest.has(key) and ((held.placed[key] as Transform3D).origin
					- (held.rest[key] as Transform3D).origin).distance_to(moved) < 0.5:
				with += 1
		out.append("%s slid %s studs %s%s" % [held.bodies._part_named(mesh.rack),
			Balance.studs(moved.length() / BrickLattice.STUD), _toward(moved),
			(", and %d part%s with it" % [with, "" if with == 1 else "s"]) if with > 0 else ""])
	return ", ".join(out)


## "toward +x", "up": the way [param moved] goes most.
static func _toward(moved: Vector3) -> String:
	var most: int = moved.abs().max_axis_index()
	if most == Vector3.AXIS_Y:
		return "up" if moved.y > 0.0 else "down"
	return "toward %s%s" % ["+" if moved[most] > 0.0 else "-", "x" if most == Vector3.AXIS_X else "z"]


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
	return _suggested


func _motion(name: String) -> Motions.Motion:
	var motion := Motions.Motion.new()
	motion.name = name
	return motion


func _offer(motion: Motions.Motion) -> void:
	if not motion.tracks.is_empty() or motion.driver != null:
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
