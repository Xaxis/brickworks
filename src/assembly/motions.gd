## A model's own named movements: "Open the doors", "Steer left and right",
## "Lift the boom" (docs/MOTIONS.md). Each moves the model's real joints as
## Grab reads them, and lives in the model's file as LDraw meta lines,
## which other programs read past:
##
##   0 !BRICKWORKS MOTION "Open the doors" AFTER "" SECONDS 2
##   0 !BRICKWORKS MOTION_TRACK "Open the doors" 1 TURN AT 0 JOINT PART 3821 4 -50 -24 -100
##   0 !BRICKWORKS MOTION_KEY "Open the doors" 1 0 0 EASE
##   0 !BRICKWORKS MOTION_KEY "Open the doors" 1 2 90 EASE
##   0 !BRICKWORKS MOTION_TRACK "Open the doors" 2 TURN AT 0 JOINT ASSEMBLY "Door Right"
##   0 !BRICKWORKS MOTION_DRIVER "Turn the crank" TURNS 3 SECONDS 4 AT 0 JOINT PART 4185 71 0 -40 60
##   0 !BRICKWORKS MOTION "Show it all" SEQUENCE "Open the doors" "Turn the crank"
##   0 !BRICKWORKS MOTION "Drive and turn left" AFTER "" SECONDS 7
##   0 !BRICKWORKS MOTION_PATH "Drive and turn left" SECONDS 7 EASE STRAIGHT 32 LEFT 90 RADIUS 24
##   0 !BRICKWORKS MOTION_WHEEL "Drive and turn left" AT 0 JOINT PART 3482 71 70 0 -70
##   0 !BRICKWORKS MOTION_STEER "Drive and turn left" AT 0 JOINT PART 3829c01 0 0 -24 -60
##
## A path moves the whole model (unit drive, docs/APP_UX6.md #12): along its
## legs, each a straight (studs; less than 0 backwards) or a turn left or right
## (degrees, on a radius in studs, measured at the middle of its back axle),
## from where it stands, over its seconds, eased at its start and its end or
## not. Its wheels, each a joint, turn as they roll, each once round for every
## round of its own tyre it goes along the ground; its steering, a joint, is
## turned into each corner. What it moves is kept where it ends, as a track's.
##
## A track is one joint and its keys: a time, a place (degrees turned, or
## studs slid, from where the model was built) and how it gets there (EASE,
## LINEAR or HOLD). A driver turns its joint so many times over so long,
## from wherever it stands, and what it drives through gears, racks and
## linkages goes with it as Grab couples it. A sequence is a motion made of
## motions, by name: each played from where the one before left the model,
## and backwards in reverse order.
##
## A joint is found again by its ref: a sub-assembly by name, else the part
## the motion takes hold of, by its number, colour and place (LDraw's
## coordinates, LDU, in the whole model). AT is where the joint stood from
## where it was built when the file was written, so a model saved with its
## doors open still opens them to 90°, not 90° further. Pure: the player
## (MotionPlayer) finds, measures and moves the joints.
class_name Motions
extends RefCounted

const META := "0 !BRICKWORKS MOTION"
const HOWS: Array[String] = ["EASE", "LINEAR", "HOLD"]
## The longest a motion may run, seconds.
const MOST_SECONDS := 120.0
## The most of a link's ?motion= read, characters: a long name, and more.
const MOST_LINK_WORDS := 120
## A path's legs: a straight, or a turn either way.
const LEGS: Array[String] = ["STRAIGHT", "LEFT", "RIGHT"]
## The most legs a path has, and the longest a leg (studs) and the widest a
## turn (degrees, studs round): a file of the wrong shape is not read.
const MOST_LEGS := 32
const MOST_LEG_STUDS := 1000.0
const MOST_TURN_DEG := 360.0
## A turn's least radius, studs: a car's turning circle, not a spin.
const LEAST_RADIUS := 1.0
const MOST_RADIUS := 1000.0
## A path's shortest, seconds: what its line is read back as at the least.
const LEAST_PATH_SECONDS := 0.1
## How near a part must be to a joint's place to be its part, LDU: a file's
## numbers are rounded, and a part read and written again is never further
## off than this.
const PLACE_SLACK := 4.0


class Joint extends RefCounted:
	## "assembly" or "part".
	var by: String = "part"
	var assembly: String = ""
	var part: String = ""
	var colour: int = 0
	## LDraw's coordinates in the model, LDU.
	var place := Vector3.ZERO
	## "turn" or "slide".
	var mode: String = "turn"
	## Where it stood from where it was built, degrees or studs, when
	## [member base_rel] was measured (or, read from a file, when it was
	## written).
	var at: float = 0.0
	# Not written: what the player found and measures from.
	## The part it takes hold of, as found; 0 before.
	var lead: int = 0
	## Where that part stood when [member at] was true.
	var lead_base := Transform3D.IDENTITY
	var has_lead_base: bool = false
	## The joint's two sides, a part of each, and its line in the second's
	## frame; [member base_rel] is the first against the second when [member
	## at] was true. measured is false until they are found.
	var ours: int = 0
	var theirs: int = 0
	var line := Vector3.ZERO
	var base_rel := Transform3D.IDENTITY
	var measured: bool = false

	func ref_words() -> String:
		if by == "assembly":
			return "ASSEMBLY %s" % Motions.quoted(assembly)
		return "PART %s %d %s %s %s" % [part, colour, Motions.num(place.x, 2), Motions.num(place.y, 2),
			Motions.num(place.z, 2)]

	func same_ref(other: Joint) -> bool:
		return other != null and ref_words() == other.ref_words() and mode == other.mode

	func copy() -> Joint:
		var out := Joint.new()
		for field: String in ["by", "assembly", "part", "colour", "place", "mode", "at", "lead",
				"lead_base", "has_lead_base", "ours", "theirs", "line", "base_rel", "measured"]:
			out.set(field, get(field))
		return out


class Track extends RefCounted:
	var joint: Joint
	## [[seconds, place, how], ...] in time order.
	var keys: Array = []

	func add_key(t: float, place: float, how: String = "EASE") -> void:
		for n: int in keys.size():
			if absf(float(keys[n][0]) - t) < 0.001:
				keys[n] = [t, place, how]
				return
		keys.append([t, place, how])
		keys.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

	func length() -> float:
		return float(keys.back()[0]) if not keys.is_empty() else 0.0

	## Where it stands at [param t] seconds: its first key's place before
	## it, its last's after; between, the way the later key says: EASE the
	## monotone cubic through the eased keys (PoseAnimation's, which never
	## swings past a key), LINEAR a straight line, HOLD where the earlier key
	## left it until the later one's moment.
	func place_at(t: float) -> float:
		if keys.is_empty():
			return 0.0
		if t <= float(keys[0][0]) or keys.size() == 1:
			return float(keys[0][1])
		if t >= float(keys.back()[0]):
			return float(keys.back()[1])
		var k: int = 0
		while k < keys.size() - 2 and t > float(keys[k + 1][0]):
			k += 1
		var a: Array = keys[k]
		var b: Array = keys[k + 1]
		match str(b[2]):
			"HOLD":
				return float(a[1])
			"LINEAR":
				var span: float = float(b[0]) - float(a[0])
				return lerpf(float(a[1]), float(b[1]), (t - float(a[0])) / span) if span > 0.0 \
					else float(b[1])
		var eased := PoseAnimation.new()
		for key: Array in keys:
			eased.add_key(float(key[0]), {"x": float(key[1])})
		return eased.angle_at("x", t)


## Where the whole model goes: its legs in order, over [member seconds],
## [member how] it starts and stops, the wheels that turn as it rolls and the
## steering turned into its corners.
class Path extends RefCounted:
	## [[kind, amount, radius]]: "STRAIGHT" studs (less than 0, backwards),
	## or "LEFT"/"RIGHT" degrees on a radius of studs.
	var legs: Array = []
	var seconds: float = 0.0
	## EASE: it gathers speed and slows to a stop; LINEAR: the same speed
	## all the way.
	var how: String = "EASE"
	## Each wheel's joint (an axle and what turns with it), the front first.
	var wheels: Array = []
	## The steering's joint, or null.
	var steer: Joint = null

	## How far its middle goes, studs.
	func studs() -> float:
		var out: float = 0.0
		for leg: Array in legs:
			out += absf(float(leg[1])) if str(leg[0]) == "STRAIGHT" \
				else deg_to_rad(absf(float(leg[1]))) * float(leg[2])
		return out

	func copy() -> Path:
		var out := Path.new()
		out.legs = legs.duplicate(true)
		out.seconds = seconds
		out.how = how
		out.wheels = wheels.duplicate()
		out.steer = steer
		return out

	## Its legs as the file writes them: "STRAIGHT 32 LEFT 90 RADIUS 24".
	func leg_words() -> String:
		var words := PackedStringArray()
		for leg: Array in legs:
			if str(leg[0]) == "STRAIGHT":
				words.append("STRAIGHT %s" % Motions.num(float(leg[1]), 2))
			else:
				words.append("%s %s RADIUS %s" % [leg[0], Motions.num(float(leg[1]), 2),
					Motions.num(float(leg[2]), 2)])
		return " ".join(words)

	## Its legs said: "32 studs straight, then 90° left on a 24-stud radius".
	func said() -> String:
		var words := PackedStringArray()
		for leg: Array in legs:
			if str(leg[0]) == "STRAIGHT":
				var studs: float = float(leg[1])
				words.append(("%s studs straight" if studs >= 0.0 else "%s studs backwards")
					% Motions.num(absf(studs), 1))
			else:
				words.append(("%s° left on a %s-stud radius" if str(leg[0]) == "LEFT"
					else "%s° right on a %s-stud radius") % [Motions.num(float(leg[1]), 1),
					Motions.num(float(leg[2]), 1)])
		# Each a pattern of the languages' own, ", then " between.
		var out: String = words[words.size() - 1] if not words.is_empty() else ""
		for n: int in range(words.size() - 2, -1, -1):
			out = "%s, then %s" % [words[n], out]
		return out


## A path's leg read at the edge: [kind, amount, radius], or why not. Each
## number snapped to the hundredth the file writes it to before it is
## judged, so what is kept is what was checked: a straight of 0.004 studs
## was kept as 0 and a radius of 0.996 refused as "not 1" (drivereview F3,
## F7).
static func leg_of(kind: String, amount: float, radius: float = 0.0) -> Variant:
	kind = kind.strip_edges().to_upper()
	if not kind in LEGS:
		return "a leg is straight, left or right, not %s" % kind.to_lower()
	var snapped: float = snappedf(amount, 0.01) if is_finite(amount) else INF
	if kind == "STRAIGHT":
		if snapped == 0.0 or absf(snapped) > MOST_LEG_STUDS:
			return "a straight goes 0.01 to %d studs (less than 0 backwards), not %s" % [
				int(MOST_LEG_STUDS), given(amount)]
		return [kind, snapped, 0.0]
	if snapped <= 0.0 or snapped > MOST_TURN_DEG:
		return "a turn goes 0.01 to %d degrees, not %s" % [int(MOST_TURN_DEG), given(amount)]
	var across: float = snappedf(radius, 0.01) if is_finite(radius) else INF
	if across < LEAST_RADIUS or across > MOST_RADIUS:
		return "a turn's radius is %s to %d studs, not %s" % [num(LEAST_RADIUS, 1), int(MOST_RADIUS),
			given(radius)]
	return [kind, snapped, across]


## A path's seconds read at the edge, snapped to the thousandth the file
## writes them to: the seconds, or why not. One that snaps to nothing is
## refused, not written as 0 and read back as some other length.
static func path_seconds_of(seconds: float) -> Variant:
	var snapped: float = snappedf(seconds, 0.001) if is_finite(seconds) else INF
	if snapped < LEAST_PATH_SECONDS or snapped > MOST_SECONDS:
		return "a path takes %s to %d seconds, not %s" % [num(LEAST_PATH_SECONDS, 1), int(MOST_SECONDS),
			given(seconds)]
	return snapped


## A number as it was given, for words that say why it was refused: as
## many places as it has, up to six, and a huge one in powers of ten.
static func given(value: float) -> String:
	if not is_finite(value) or absf(value) >= 1e15:
		return String.num_scientific(value)
	return num(value, 6)


class Motion extends RefCounted:
	var name: String = ""
	## The motion this one follows, "" for none. Kept for the files that
	## have it: a sequence names an order now (docs/MOTIONS.md, unit 5).
	var after: String = ""
	## A sequence: the motions it plays, by name, in order; empty for a
	## motion of its own tracks or driver. A name the model has no motion
	## of is kept, and said when played.
	var sequence := PackedStringArray()
	## How long it runs, at least, seconds: its keys may end sooner.
	var seconds: float = 0.0
	var tracks: Array = []
	## A driver: its joint turned [member turns] times over [member
	## driver_seconds]; null for none.
	var driver: Joint = null
	var turns: float = 0.0
	var driver_seconds: float = 0.0
	## Where the whole model goes, or null (unit drive).
	var path: Path = null

	func length() -> float:
		var most: float = seconds
		for track: Track in tracks:
			most = maxf(most, track.length())
		if driver != null:
			most = maxf(most, driver_seconds)
		if path != null:
			most = maxf(most, path.seconds)
		return maxf(most, 0.0)

	func is_sequence() -> bool:
		return not sequence.is_empty()

	## Every joint it moves.
	func joints() -> Array:
		var out: Array = []
		for track: Track in tracks:
			if not out.has(track.joint):
				out.append(track.joint)
		if driver != null and not out.has(driver):
			out.append(driver)
		if path != null:
			for joint: Joint in path.wheels + ([path.steer] if path.steer != null else []):
				if not out.has(joint):
					out.append(joint)
		return out


var list: Array = []
## Every joint any motion moves, each once: tracks of two motions on one
## joint share it, so its AT is one.
var joints: Array = []
## Where every part stood when the file was read, brick id -> Transform3D:
## a joint read from a file is measured from it once its sides are found.
## Shared by copies; empty for motions made in this session.
var snapshot: Dictionary = {}
## Where the paths kept since the model was read have moved it whole, in
## the file's coordinates (LdrModel.to_transform's, the model not lifted):
## a kept drive is one rigid move of the whole model (drivereview F2), so a
## file of someone else's is written with its model's own lines moved and
## every sub-model's lines as they were ([method moved_into]).
var moved := Transform3D.IDENTITY


func is_empty() -> bool:
	return list.is_empty()


## Whether there is anything to write: a motion, or a line read and kept.
func has_lines() -> bool:
	return not list.is_empty() or not unread.is_empty()


## The part of [param world] [param joint]'s ref names, by its number and
## colour, the nearest within PLACE_SLACK of its place (LDraw's
## coordinates, the model [param lift] above them as it stands); 0 for none.
## Looked for once the model is built from its file, before anything moves
## (ModelStore): found later by where the file had it, a part a drive or a
## hand had moved was not found, and its joint was written as it had been
## read, where its part no longer was (drivereview F1).
static func part_at(joint: Joint, world: BrickWorld, lift: Vector3) -> int:
	if joint.by != "part" or world == null:
		return 0
	var want: Vector3 = joint.place * LdrModel.FLIP + lift
	var best: int = 0
	var nearest: float = PLACE_SLACK
	for brick: BrickWorld.Brick in world.bricks():
		if brick.part_id != joint.part or brick.color_code != joint.colour:
			continue
		var off: float = brick.transform.origin.distance_to(want)
		if off < nearest:
			nearest = off
			best = brick.id
	return best


## A whole model's move as a file writes it: turned square snapped square,
## its place to a thousandth of an LDU, so every part of the model moves
## alike and no line is written with a float's noise (-0.00000004).
static func tidied(at: Transform3D) -> Transform3D:
	var basis: Basis = at.basis.orthonormalized()
	var square: Basis = BrickLattice.snap_basis(basis)
	if square.is_equal_approx(basis):
		basis = square
	return Transform3D(basis, Vector3(snappedf(at.origin.x, 0.001), snappedf(at.origin.y, 0.001),
		snappedf(at.origin.z, 0.001)))


## [param text], an LDraw file, with its whole model moved by [param whole]
## (the file's coordinates): each line of its main model that places a part
## or a sub-model, and no other. A sub-model placed twice, or mirrored,
## stays as its author wrote it, and so does every other line.
static func moved_into(text: String, whole: Transform3D) -> String:
	if whole.is_equal_approx(Transform3D.IDENTITY):
		return text
	# In doubles, on the line's own numbers: by way of a Transform3D (floats)
	# an author's 0.988 came back as 0.98799998. A turn by a quarter is a
	# signed shuffle of the line's numbers, so they come back as written.
	var w: PackedFloat64Array = LdrModel.from_transform(whole)
	var lines: PackedStringArray = text.split("\n")
	var in_main: bool = false
	for n: int in lines.size():
		var words: PackedStringArray = LdrModel._fields(lines[n].strip_edges())
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() in ["FILE", "NOFILE", "!DATA"]:
			# The main model is the first FILE's section, or a file of none.
			if in_main or words[1].to_upper() != "FILE":
				break
			in_main = true
			continue
		if words.size() < 15 or words[0] != "1":
			continue
		var numbers := PackedFloat64Array()
		for k: int in range(2, 14):
			if not words[k].is_valid_float():
				break
			numbers.append(words[k].to_float())
		if numbers.size() != 12:
			continue
		lines[n] = "1 %s %s %s%s" % [words[1], LdrModel.numbers_text(_composed(w, numbers)),
			" ".join(words.slice(14)), "\r" if lines[n].ends_with("\r") else ""]
	return "\n".join(lines)


## A type-1 line's twelve numbers (x y z, then the rotation by rows) moved by
## another's: its rotation turned by w's, its place turned and then moved.
static func _composed(w: PackedFloat64Array, v: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(12)
	for row: int in 3:
		out[row] = w[row] + w[3 + row * 3] * v[0] + w[4 + row * 3] * v[1] + w[5 + row * 3] * v[2]
		for column: int in 3:
			out[3 + row * 3 + column] = (w[3 + row * 3] * v[3 + column] + w[4 + row * 3] * v[6 + column]
				+ w[5 + row * 3] * v[9 + column])
	return out


func named(name: String) -> Motion:
	for motion: Motion in list:
		if motion.name.to_lower() == name.strip_edges().to_lower():
			return motion
	return null


## The motion a link asks for (?motion=): by its name in any case, by the
## name as a link writes it ("open-the-gates", [method slug]), or by words
## found in one motion's name alone ("boom" for "Lift the boom"); null for
## none, or for words in more than one.
func for_link(asked: String) -> Motion:
	var exact: Motion = named(asked)
	if exact != null:
		return exact
	var wanted: String = slug(asked)
	if wanted.is_empty():
		return null
	for motion: Motion in list:
		if slug(motion.name) == wanted:
			return motion
	var words: PackedStringArray = wanted.split("-")
	var found: Array = list.filter(func(motion: Motion) -> bool:
		var has: PackedStringArray = slug(motion.name).split("-")
		return Array(words).all(func(word: String) -> bool: return has.has(word)))
	return found[0] if found.size() == 1 else null


## A motion's name as a link writes it: small letters and digits, in any
## script, a hyphen between words ("Open the gates" is "open-the-gates").
static func slug(name: String) -> String:
	return RegEx.create_from_string("[^\\p{L}\\p{N}]+").sub(name.to_lower(), "-", true).strip_edges() \
		.trim_prefix("-").trim_suffix("-")


## What a link's ?motion= says, checked at the edge: words on one line, cut
## short; "" for none or for anything else.
static func link_words(text: String) -> String:
	var words: String = text.strip_edges().left(MOST_LINK_WORDS)
	return "" if RegEx.create_from_string("[\\x00-\\x1f\\x7f]").search(words) != null else words


## The joint already kept that is [param joint]'s, or [param joint] itself,
## now kept.
func joint_for(joint: Joint) -> Joint:
	var kept: Joint = find_joint(joint)
	if kept != null:
		return kept
	joints.append(joint)
	return joint


## The joint kept that is [param joint]'s (the same ref, or the same part
## found), or null.
func find_joint(joint: Joint) -> Joint:
	for kept: Joint in joints:
		if kept == joint or kept.same_ref(joint) \
				or (kept.lead != 0 and kept.lead == joint.lead and kept.mode == joint.mode):
			return kept
	return null


## [param motion] in place of the one of its name, or added; its joints the
## ones kept where they are the same.
func put(motion: Motion) -> void:
	for track: Track in motion.tracks:
		track.joint = joint_for(track.joint)
	if motion.driver != null:
		motion.driver = joint_for(motion.driver)
	if motion.path != null:
		motion.path.wheels = motion.path.wheels.map(func(one: Joint) -> Joint: return joint_for(one))
		if motion.path.steer != null:
			motion.path.steer = joint_for(motion.path.steer)
	_drop_unread(motion.name)
	for n: int in list.size():
		if (list[n] as Motion).name.to_lower() == motion.name.to_lower():
			list[n] = motion
			_tidy_joints()
			return
	list.append(motion)
	_tidy_joints()


func remove(name: String) -> bool:
	for n: int in list.size():
		if (list[n] as Motion).name.to_lower() == name.strip_edges().to_lower():
			list.remove_at(n)
			_tidy_joints()
			_drop_unread(name)
			return true
	return false


## A joint no motion moves any longer is not kept.
func _tidy_joints() -> void:
	var used: Array = []
	for motion: Motion in list:
		for joint: Joint in motion.joints():
			if not used.has(joint):
				used.append(joint)
	joints = joints.filter(func(one: Joint) -> bool: return used.has(one))


## A copy for the history: its own motions, tracks and joints, the joints
## shared between its tracks as they are here.
func copy() -> Motions:
	var out := Motions.new()
	out.snapshot = snapshot
	out.unread = unread.duplicate()
	out.unread_why = unread_why.duplicate()
	out.moved = moved
	var map: Dictionary = {}
	for joint: Joint in joints:
		map[joint] = joint.copy()
		out.joints.append(map[joint])
	for motion: Motion in list:
		var made := Motion.new()
		made.name = motion.name
		made.after = motion.after
		made.seconds = motion.seconds
		made.turns = motion.turns
		made.driver_seconds = motion.driver_seconds
		made.sequence = motion.sequence.duplicate()
		if motion.driver != null:
			made.driver = map.get(motion.driver, motion.driver.copy())
		if motion.path != null:
			made.path = motion.path.copy()
			made.path.wheels = motion.path.wheels.map(func(one: Joint) -> Joint: return map.get(one, one.copy()))
			if motion.path.steer != null:
				made.path.steer = map.get(motion.path.steer, motion.path.steer.copy())
		for track: Track in motion.tracks:
			var kept := Track.new()
			kept.joint = map.get(track.joint, track.joint.copy())
			kept.keys = track.keys.duplicate(true)
			made.tracks.append(kept)
		out.list.append(made)
	return out


## The motions in order of play: each after the one it follows, the rest
## as listed. [param from] (a name) gives the chain it is in, from its
## first: every motion linked to it by AFTER (a file's; a sequence is
## never in a chain).
func sequence(from: String) -> Array:
	var start: Motion = named(from)
	if start == null:
		return []
	if start.is_sequence():
		return [start]
	var seen: Dictionary = {start: true}
	while not start.after.is_empty() and _chained(named(start.after)) and not seen.has(named(start.after)):
		start = named(start.after)
		seen[start] = true
	var out: Array = [start]
	var at: Motion = start
	while true:
		var next: Motion = null
		for motion: Motion in list:
			if not motion.is_sequence() and motion.after.to_lower() == at.name.to_lower() and not out.has(motion):
				next = motion
				break
		if next == null:
			break
		out.append(next)
		at = next
	return out


static func _chained(motion: Motion) -> bool:
	return motion != null and not motion.is_sequence()


## Every motion in order of play (Play all): each chain from its first,
## each motion after the one it follows, the chains as their first
## motions are listed. Not the sequences: what they play is here already.
func in_order() -> Array:
	var out: Array = []
	for motion: Motion in list:
		if out.has(motion) or motion.is_sequence():
			continue
		for one: Motion in sequence(motion.name):
			if not out.has(one):
				out.append(one)
	return out


## The motions [param motion] plays, in order: itself, or a sequence's
## members, a sequence in it played through; [param reverse] in reverse
## order. [param missing] gets each name it gives that the model has no
## motion of, or that would play the sequence inside itself, as words.
func played_by(motion: Motion, reverse: bool = false, missing: Array = []) -> Array:
	var out: Array = []
	_play_into(motion, out, [], missing)
	if reverse:
		out.reverse()
	return out


func _play_into(motion: Motion, out: Array, within: Array, missing: Array) -> void:
	if not motion.is_sequence():
		out.append(motion)
		return
	within.append(motion)
	for name: String in motion.sequence:
		var one: Motion = named(name)
		if one == null:
			missing.append("%s: the model has no motion %s" % [quoted(motion.name), quoted(name)])
		elif within.has(one):
			missing.append("%s: %s would play %s inside itself" % [quoted(motion.name), quoted(name),
				quoted(one.name)])
		else:
			_play_into(one, out, within, missing)
	within.pop_back()


## How long [param motion] runs, seconds: a sequence its members' lengths
## together.
func seconds_of(motion: Motion) -> float:
	var total: float = 0.0
	for one: Motion in played_by(motion):
		total += one.length()
	return total


## [param order] with every sequence in it played through (played_by),
## each [param reverse]d.
func flat(order: Array, reverse: bool = false, missing: Array = []) -> Array:
	var out: Array = []
	for motion: Motion in order:
		out.append_array(played_by(motion, reverse, missing))
	return out


## A name no motion has: [param words], or with a number after it.
func free_name(words: String) -> String:
	if named(words) == null:
		return words
	var n: int = 2
	while named("%s %d" % [words, n]) != null:
		n += 1
	return "%s %d" % [words, n]


# -- the lines in the file --------------------------------------------------------


## The motion lines, without line breaks, in the order they are written.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for motion: Motion in list:
		if motion.is_sequence():
			var names := PackedStringArray()
			for one: String in motion.sequence:
				names.append(quoted(one))
			out.append("%s %s SEQUENCE %s" % [META, quoted(motion.name), " ".join(names)])
			continue
		out.append('%s %s AFTER %s SECONDS %s' % [META, quoted(motion.name), quoted(motion.after),
			num(motion.length(), 3)])
		for n: int in motion.tracks.size():
			var track: Track = motion.tracks[n]
			out.append("%s_TRACK %s %d %s AT %s JOINT %s" % [META, quoted(motion.name), n + 1,
				track.joint.mode.to_upper(), num(track.joint.at, 2), track.joint.ref_words()])
			for key: Array in track.keys:
				out.append("%s_KEY %s %d %s %s %s" % [META, quoted(motion.name), n + 1,
					num(float(key[0]), 3), num(float(key[1]), 2), str(key[2])])
		if motion.driver != null:
			out.append("%s_DRIVER %s TURNS %s SECONDS %s AT %s JOINT %s" % [META, quoted(motion.name),
				num(motion.turns, 3), num(motion.driver_seconds, 3), num(motion.driver.at, 2),
				motion.driver.ref_words()])
		if motion.path != null:
			out.append("%s_PATH %s SECONDS %s %s %s" % [META, quoted(motion.name), num(motion.path.seconds, 3),
				motion.path.how, motion.path.leg_words()])
			for wheel: Joint in motion.path.wheels:
				out.append("%s_WHEEL %s AT %s JOINT %s" % [META, quoted(motion.name), num(wheel.at, 2),
					wheel.ref_words()])
			if motion.path.steer != null:
				out.append("%s_STEER %s AT %s JOINT %s" % [META, quoted(motion.name),
					num(motion.path.steer.at, 2), motion.path.steer.ref_words()])
	# And the lines this could not read, as the file had them.
	out.append_array(unread)
	return out


## [param text] with [param lines] in the head of its main model, after its
## floor's line (ModelFloor) where it has one, in place of any motion lines
## it had: written the same every time, so a model saved twice is the same
## file.
static func written_into(text: String, motion_lines: PackedStringArray) -> String:
	if motion_lines.is_empty() and not text.contains(META):
		return text
	# Each line ended as the file's are: a CRLF file's motion lines went out
	# in LF alone (drivereview, keeptext5 note e).
	var eol: String = "\r" if text.split("\n", true, 1)[0].ends_with("\r") else ""
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		if not line.strip_edges().begins_with(META):
			kept.append(line)
	if motion_lines.is_empty():
		return "\n".join(kept)
	var ended := PackedStringArray()
	for line: String in motion_lines:
		ended.append(line + eol)
	var at: int = -1
	for n: int in kept.size():
		if kept[n].begins_with(ModelFloor.META):
			at = n + 1
			break
	if at < 0:
		at = kept.size()
		for n: int in kept.size():
			var line: String = kept[n].strip_edges()
			if n > 0 and (line.is_empty() or line.begins_with("1 ") or line.begins_with("0 FILE")
					or line == "0 STEP" or line.to_upper().begins_with("0 ROTSTEP")):
				at = n
				break
	var head: PackedStringArray = kept.slice(0, at)
	head.append_array(ended)
	head.append_array(kept.slice(at))
	return "\n".join(head)


## The motions a model's text carries, read at the edge. A line this
## cannot read is left out of the motions, kept as it is in [member unread]
## to be written back, and said ([method unread_words]): its own reason, or
## that the motion it is part of moves nothing this reads (drivereview F5:
## six lines a save dropped without a word). A key, wheel or steering line
## is read after every track and path, so the order the lines are in does
## not matter (F4).
static func read(text: String) -> Motions:
	var out := Motions.new()
	if not text.contains(META):
		return out
	var tracks: Dictionary = {}   ## "motion|n" -> Track
	var later: Array = []         ## [n, line, words]: keys, wheels and steering
	var lines_of: Dictionary = {} ## Motion -> [[n, line, part]]: the lines read into it
	var refused: Array = []       ## [n, line, motion name, why, rank]
	var text_lines: PackedStringArray = text.split("\n")
	for n: int in text_lines.size():
		var raw: String = text_lines[n].trim_suffix("\r")
		var line: String = raw.strip_edges()
		if not line.begins_with(META):
			continue
		# 0 !BRICKWORKS MOTION_TRACK "name" ...
		var words: PackedStringArray = tokens(line)
		if words.size() < 4 or words[3].strip_edges().is_empty():
			refused.append([n, raw, "", "a motion line with no motion's name", 0])
			continue
		if words[2] in ["MOTION_KEY", "MOTION_WHEEL", "MOTION_STEER"]:
			later.append([n, raw, words])
			continue
		var name: String = words[3].strip_edges()
		var motion: Motion = out.named(name)
		if motion == null:
			motion = Motion.new()
			motion.name = name
			out.list.append(motion)
		var rest: PackedStringArray = words.slice(4)
		var why: String = ""
		match words[2]:
			"MOTION":
				if not _read_motion(motion, rest):
					why = "its MOTION line is not one this reads"
			"MOTION_TRACK":
				var track: Track = _read_track(out, rest)
				if track == null:
					why = "a track line this does not read"
				else:
					motion.tracks.append(track)
					tracks["%s|%s" % [name.to_lower(), rest[0]]] = track
			"MOTION_DRIVER":
				if not _read_driver(out, motion, rest):
					why = "a driver line this does not read"
			"MOTION_PATH":
				why = "it has two path lines" if motion.path != null else _read_path(motion, rest)
			_:
				why = "%s is not a motion line this reads" % words[2]
		if why.is_empty():
			if not lines_of.has(motion):
				lines_of[motion] = []
			(lines_of[motion] as Array).append([n, raw, words[2]])
		else:
			refused.append([n, raw, name, why, 0])
	for entry: Array in later:
		var words: PackedStringArray = entry[2]
		var name: String = words[3].strip_edges()
		var motion: Motion = out.named(name)
		var rest: PackedStringArray = words.slice(4)
		var why: String = ""
		if words[2] == "MOTION_KEY":
			var key: String = "%s|%s" % [name.to_lower(), rest[0] if not rest.is_empty() else ""]
			if not tracks.has(key):
				why = "a key of a track it does not have"
			elif rest.size() < 4 or not rest[1].is_valid_float() or not rest[2].is_valid_float() \
					or not rest[3] in HOWS:
				why = "a key line this does not read"
			else:
				(tracks[key] as Track).add_key(clampf(rest[1].to_float(), 0.0, MOST_SECONDS),
					rest[2].to_float(), rest[3])
		else:
			# AT deg JOINT ref..., with its motion's path.
			var joint: Joint = _read_ref(rest.slice(3)) if rest.size() >= 4 and rest[0] == "AT" \
				and rest[1].is_valid_float() and rest[2] == "JOINT" else null
			if motion == null or motion.path == null:
				why = "a wheel or steering line with no path read"
			elif joint == null:
				why = "a wheel or steering line this does not read"
			elif words[2] == "MOTION_STEER" and motion.path.steer != null:
				why = "it has two steering lines"
			else:
				joint.at = rest[1].to_float()
				joint = out.joint_for(joint)
				if words[2] == "MOTION_STEER":
					motion.path.steer = joint
				elif not motion.path.wheels.has(joint):
					motion.path.wheels.append(joint)
		if why.is_empty():
			if not lines_of.has(motion):
				lines_of[motion] = []
			(lines_of[motion] as Array).append([int(entry[0]), str(entry[1]), words[2]])
		else:
			refused.append([int(entry[0]), str(entry[1]), name, why, 1])
	# A sequence has no tracks of its own: those lines are not read.
	for one: Motion in out.list:
		if one.is_sequence() and (not one.tracks.is_empty() or one.driver != null or one.path != null):
			one.tracks.clear()
			one.driver = null
			one.path = null
			var kept: Array = []
			for read_line: Array in lines_of.get(one, []):
				if str(read_line[2]) == "MOTION":
					kept.append(read_line)
				else:
					refused.append([int(read_line[0]), str(read_line[1]), one.name,
						"a sequence plays motions, and moves nothing of its own", 1])
			lines_of[one] = kept
	# A motion that moves nothing and plays nothing is nothing: its lines,
	# read or not, are kept as they are.
	for one: Motion in out.list:
		if not one.tracks.is_empty() or one.driver != null or one.path != null or one.is_sequence():
			continue
		for read_line: Array in lines_of.get(one, []):
			refused.append([int(read_line[0]), str(read_line[1]), one.name,
				"nothing it moves was read", 2])
	out.list = out.list.filter(func(one: Motion) -> bool:
		return not one.tracks.is_empty() or one.driver != null or one.path != null or one.is_sequence())
	out._tidy_joints()
	refused.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	# Each motion's lines said once, by the first of its own reasons.
	var why_of: Dictionary = {}   ## name -> [rank, why]
	var count_of: Dictionary = {} ## name -> lines
	for one: Array in refused:
		out.unread.append(str(one[1]))
		var name: String = str(one[2])
		count_of[name] = int(count_of.get(name, 0)) + 1
		if not why_of.has(name) or int(one[4]) < int((why_of[name] as Array)[0]):
			why_of[name] = [int(one[4]), str(one[3])]
	for name: String in why_of:
		var why: String = str((why_of[name] as Array)[1])
		var lines: int = int(count_of[name])
		if name.is_empty():
			out.unread_why.append(why)
		elif lines == 1:
			out.unread_why.append("%s: %s" % [quoted(name), why])
		else:
			out.unread_why.append("%s (%d lines): %s" % [quoted(name), lines, why])
	return out


## Lines read and left out, as they were (without a line end): written back
## after the motion lines ([method lines]) so a save loses none of them.
var unread := PackedStringArray()
## Why, a motion at a time, in words: '"Drive" (5 lines): a path has at most
## 32 legs, not 33'.
var unread_why := PackedStringArray()


## The lines [member unread] has, said where an open says what it left out:
## "3 motion lines not read, kept in the file as they are: ..."; "" for none.
func unread_words() -> String:
	if unread.is_empty():
		return ""
	var said: String = "1 motion line not read, kept in the file as it is" if unread.size() == 1 \
		else "%d motion lines not read, kept in the file as they are" % unread.size()
	return "%s: %s" % [said, "; ".join(unread_why)]


## The lines of [member unread] that name the motion [param name], or only
## those that do not.
func _unread_naming(name: String, naming: bool) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in unread:
		var words: PackedStringArray = tokens(line.strip_edges())
		var names: bool = words.size() >= 4 and words[3].strip_edges().to_lower() == name.strip_edges().to_lower()
		if names == naming:
			out.append(line)
	return out


## A refused line belongs to the motion it names: it is the file's while
## that motion is, and goes with it once the motion is made again or taken
## out here (an undo brings both back). Kept, it would be read into the
## motion made again at the next open: a second path line read as the path
## of a motion whose path was taken out.
func _drop_unread(name: String) -> void:
	var kept: PackedStringArray = _unread_naming(name, false)
	if kept.size() == unread.size():
		return
	unread = kept
	unread_why = PackedStringArray(Array(unread_why).filter(func(why: String) -> bool:
		return not why.begins_with(quoted(name) + " (") and not why.begins_with(quoted(name) + ":")))


## [param was] renamed [param now] in the lines of [member unread] that
## name it, so they stay with it.
func rename_unread(was: String, now: String) -> void:
	for n: int in unread.size():
		var line: String = unread[n]
		var words: PackedStringArray = tokens(line.strip_edges())
		if words.size() < 4 or words[3].strip_edges().to_lower() != was.strip_edges().to_lower():
			continue
		# The name's own words, quoted or not, after its keyword.
		var from: int = line.find(words[2]) + words[2].length()
		var at: int = line.find('"%s"' % words[3], from)
		var length: int = words[3].length() + 2
		if at < 0:
			at = line.find(words[3], from)
			length = words[3].length()
		if at >= 0:
			unread[n] = line.left(at) + quoted(now) + line.substr(at + length)
	for n: int in unread_why.size():
		var head: String = quoted(was)
		if unread_why[n].begins_with(head + ":") or unread_why[n].begins_with(head + " ("):
			unread_why[n] = quoted(now) + unread_why[n].substr(head.length())


static func _read_motion(motion: Motion, rest: PackedStringArray) -> bool:
	if not rest.is_empty() and rest[0] == "SEQUENCE":
		var names: PackedStringArray = rest.slice(1)
		if names.is_empty() or Array(names).any(func(one: String) -> bool: return one.strip_edges().is_empty()):
			return false
		motion.sequence = names
		return true
	var n: int = 0
	while n + 1 < rest.size():
		match rest[n]:
			"AFTER":
				motion.after = rest[n + 1]
			"SECONDS":
				if not rest[n + 1].is_valid_float():
					return false
				motion.seconds = clampf(rest[n + 1].to_float(), 0.0, MOST_SECONDS)
			_:
				return false
		n += 2
	return n == rest.size()


static func _read_track(into: Motions, rest: PackedStringArray) -> Track:
	# n MODE AT deg JOINT ref...
	if rest.size() < 6 or not rest[0].is_valid_int() or not rest[1].to_lower() in ["turn", "slide"] \
			or rest[2] != "AT" or not rest[3].is_valid_float() or rest[4] != "JOINT":
		return null
	var joint: Joint = _read_ref(rest.slice(5))
	if joint == null:
		return null
	joint.mode = rest[1].to_lower()
	joint.at = rest[3].to_float()
	var track := Track.new()
	track.joint = into.joint_for(joint)
	return track


static func _read_driver(into: Motions, motion: Motion, rest: PackedStringArray) -> bool:
	# TURNS n SECONDS s AT deg JOINT ref...
	if rest.size() < 8 or rest[0] != "TURNS" or not rest[1].is_valid_float() or rest[2] != "SECONDS" \
			or not rest[3].is_valid_float() or rest[4] != "AT" or not rest[5].is_valid_float() \
			or rest[6] != "JOINT":
		return false
	var joint: Joint = _read_ref(rest.slice(7))
	if joint == null:
		return false
	joint.at = rest[5].to_float()
	motion.driver = into.joint_for(joint)
	motion.turns = rest[1].to_float()
	motion.driver_seconds = clampf(rest[3].to_float(), 0.1, MOST_SECONDS)
	return true


## SECONDS s EASE|LINEAR legs...: each leg STRAIGHT studs, or LEFT|RIGHT
## degrees RADIUS studs. "" when it is read into [param motion], else why not.
static func _read_path(motion: Motion, rest: PackedStringArray) -> String:
	if rest.size() < 5 or rest[0] != "SECONDS" or not rest[1].is_valid_float() or not rest[2] in ["EASE", "LINEAR"]:
		return "its path line is not one this reads"
	var seconds: Variant = path_seconds_of(rest[1].to_float())
	if seconds is String:
		return str(seconds)
	var path := Path.new()
	path.seconds = seconds
	path.how = rest[2]
	var n: int = 3
	while n < rest.size():
		var leg: Variant = null
		if rest[n] == "STRAIGHT" and n + 1 < rest.size() and rest[n + 1].is_valid_float():
			leg = leg_of(rest[n], rest[n + 1].to_float())
			n += 2
		elif rest[n] in ["LEFT", "RIGHT"] and n + 3 < rest.size() and rest[n + 1].is_valid_float() \
				and rest[n + 2] == "RADIUS" and rest[n + 3].is_valid_float():
			leg = leg_of(rest[n], rest[n + 1].to_float(), rest[n + 3].to_float())
			n += 4
		elif rest[n] in ["LEFT", "RIGHT"]:
			return "a turn of its path has no RADIUS"
		else:
			return "its path has %s where a leg goes" % rest[n].to_lower()
		if leg is String:
			return str(leg)
		path.legs.append(leg)
	if path.legs.size() > MOST_LEGS:
		return "a path has at most %d legs, not %d" % [MOST_LEGS, path.legs.size()]
	motion.path = path
	return ""


static func _read_ref(words: PackedStringArray) -> Joint:
	var joint := Joint.new()
	if words.size() == 2 and words[0] == "ASSEMBLY" and not words[1].strip_edges().is_empty():
		joint.by = "assembly"
		joint.assembly = words[1]
		return joint
	if words.size() == 6 and words[0] == "PART" and words[2].is_valid_int() and words[3].is_valid_float() \
			and words[4].is_valid_float() and words[5].is_valid_float():
		joint.by = "part"
		joint.part = words[1]
		joint.colour = words[2].to_int()
		joint.place = Vector3(words[3].to_float(), words[4].to_float(), words[5].to_float())
		return joint
	return null


## A line's words, a "quoted" word whole and without its quotes.
static func tokens(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var n: int = 0
	var size: int = line.length()
	while n < size:
		while n < size and (line[n] == " " or line[n] == "\t"):
			n += 1
		if n >= size:
			break
		if line[n] == '"':
			var end: int = line.find('"', n + 1)
			if end < 0:
				end = size
			out.append(line.substr(n + 1, end - n - 1))
			n = end + 1
		else:
			var end: int = n
			while end < size and line[end] != " " and line[end] != "\t":
				end += 1
			out.append(line.substr(n, end - n))
			n = end
	return out


## A name in quotes, its own quotes made single.
static func quoted(words: String) -> String:
	return '"%s"' % words.replace('"', "'").replace("\n", " ").strip_edges()


## A number written the same every time: at most [param places] decimals,
## no trailing zeros, no "-0".
static func num(value: float, places: int) -> String:
	if not is_finite(value) or absf(value) >= 1e15:
		# A whole number past what an int holds: 1e30 was said as
		# -9223372036854775808 (drivereview F7).
		return String.num_scientific(value)
	var snapped: float = snappedf(value, pow(10.0, -places))
	if is_equal_approx(snapped, roundf(snapped)):
		return str(int(roundf(snapped)))
	return String.num(snapped, places)
