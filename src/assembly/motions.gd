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
##
## A track is one joint and its keys: a time, a place (degrees turned, or
## studs slid, from where the model was built) and how it gets there (EASE,
## LINEAR or HOLD). A driver turns its joint so many times over so long,
## from wherever it stands, and what it drives through gears, racks and
## linkages goes with it as Grab couples it.
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


class Motion extends RefCounted:
	var name: String = ""
	## The motion this one follows, "" for none.
	var after: String = ""
	## How long it runs, at least, seconds: its keys may end sooner.
	var seconds: float = 0.0
	var tracks: Array = []
	## A driver: its joint turned [member turns] times over [member
	## driver_seconds]; null for none.
	var driver: Joint = null
	var turns: float = 0.0
	var driver_seconds: float = 0.0

	func length() -> float:
		var most: float = seconds
		for track: Track in tracks:
			most = maxf(most, track.length())
		if driver != null:
			most = maxf(most, driver_seconds)
		return maxf(most, 0.0)

	## Every joint it moves.
	func joints() -> Array:
		var out: Array = []
		for track: Track in tracks:
			if not out.has(track.joint):
				out.append(track.joint)
		if driver != null and not out.has(driver):
			out.append(driver)
		return out


var list: Array = []
## Every joint any motion moves, each once: tracks of two motions on one
## joint share it, so its AT is one.
var joints: Array = []
## Where every part stood when the file was read, brick id -> Transform3D:
## a joint read from a file is measured from it once its sides are found.
## Shared by copies; empty for motions made in this session.
var snapshot: Dictionary = {}


func is_empty() -> bool:
	return list.is_empty()


func named(name: String) -> Motion:
	for motion: Motion in list:
		if motion.name.to_lower() == name.strip_edges().to_lower():
			return motion
	return null


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
		if motion.driver != null:
			made.driver = map.get(motion.driver, motion.driver.copy())
		for track: Track in motion.tracks:
			var kept := Track.new()
			kept.joint = map.get(track.joint, track.joint.copy())
			kept.keys = track.keys.duplicate(true)
			made.tracks.append(kept)
		out.list.append(made)
	return out


## The motions in order of play: each after the one it follows, the rest
## as listed. [param from] (a name) gives the sequence it is in, from its
## first: every motion linked to it by AFTER.
func sequence(from: String) -> Array:
	var start: Motion = named(from)
	if start == null:
		return []
	var seen: Dictionary = {start: true}
	while not start.after.is_empty() and named(start.after) != null and not seen.has(named(start.after)):
		start = named(start.after)
		seen[start] = true
	var out: Array = [start]
	var at: Motion = start
	while true:
		var next: Motion = null
		for motion: Motion in list:
			if motion.after.to_lower() == at.name.to_lower() and not out.has(motion):
				next = motion
				break
		if next == null:
			break
		out.append(next)
		at = next
	return out


# -- the lines in the file --------------------------------------------------------


## The motion lines, without line breaks, in the order they are written.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for motion: Motion in list:
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
	return out


## [param text] with [param lines] in the head of its main model, after its
## floor's line (ModelFloor) where it has one, in place of any motion lines
## it had: written the same every time, so a model saved twice is the same
## file.
static func written_into(text: String, motion_lines: PackedStringArray) -> String:
	if motion_lines.is_empty() and not text.contains(META):
		return text
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		if not line.begins_with(META):
			kept.append(line)
	if motion_lines.is_empty():
		return "\n".join(kept)
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
	head.append_array(motion_lines)
	head.append_array(kept.slice(at))
	return "\n".join(head)


## The motions a model's text carries, read at the edge: a line of the
## wrong shape is left out, and said in [member unread].
static func read(text: String) -> Motions:
	var out := Motions.new()
	if not text.contains(META):
		return out
	var tracks: Dictionary = {}   ## "motion|n" -> Track
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if not line.begins_with(META):
			continue
		# 0 !BRICKWORKS MOTION_TRACK "name" ...
		var words: PackedStringArray = tokens(line)
		if words.size() < 4 or words[3].strip_edges().is_empty():
			out.unread.append(line)
			continue
		var name: String = words[3].strip_edges()
		var motion: Motion = out.named(name)
		if motion == null:
			motion = Motion.new()
			motion.name = name
			out.list.append(motion)
		var rest: PackedStringArray = words.slice(4)
		var ok: bool = true
		match words[2]:
			"MOTION":
				ok = _read_motion(motion, rest)
			"MOTION_TRACK":
				var track: Track = _read_track(out, rest)
				ok = track != null
				if ok:
					motion.tracks.append(track)
					tracks["%s|%s" % [name.to_lower(), rest[0]]] = track
			"MOTION_KEY":
				ok = rest.size() >= 4 and tracks.has("%s|%s" % [name.to_lower(), rest[0]]) \
					and rest[1].is_valid_float() and rest[2].is_valid_float() and rest[3] in HOWS
				if ok:
					(tracks["%s|%s" % [name.to_lower(), rest[0]]] as Track).add_key(
						clampf(rest[1].to_float(), 0.0, MOST_SECONDS), rest[2].to_float(), rest[3])
			"MOTION_DRIVER":
				ok = _read_driver(out, motion, rest)
			_:
				ok = false
		if not ok:
			out.unread.append(line)
	# A motion that moves nothing is nothing.
	out.list = out.list.filter(func(one: Motion) -> bool:
		return not one.tracks.is_empty() or one.driver != null)
	out._tidy_joints()
	return out


## Lines read and left out, as they were: a motion line of the wrong shape.
var unread := PackedStringArray()


static func _read_motion(motion: Motion, rest: PackedStringArray) -> bool:
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
	var snapped: float = snappedf(value, pow(10.0, -places))
	if is_equal_approx(snapped, roundf(snapped)):
		return str(int(roundf(snapped)))
	return String.num(snapped, places)
