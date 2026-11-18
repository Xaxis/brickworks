## Whether a posed joint holds what hangs on it: a mech's arm on its ball, a
## dragon's neck on its hinges (docs/APP_UX9.md, posehold).
##
## A friction joint holds a turning load up to its holding torque and then
## droops. No maker publishes one, so each kind's is what builders measured
## by hanging bricks on a lever until the joint gave, in data/joint_hold.json
## (written, with every step of the sum and its sources, by
## tools/joint_hold_table.py):
##
##     kind            holds     every one held   every one gave   measured
##     Technic ball    28.5 N·mm   25.8              31.2             1 joint
##     friction pin    10.4 N·mm    6.0              16.4            18 pins
##
## A small (towball or Mixel) ball, a click hinge, a friction hinge, a
## turntable and a clip on a bar have no published measurement: such a joint
## is named with what it carries and "not known", and never given a number.
##
## Balance weighs a joint that alone holds what is past it (a bridge in the
## graph of what holds what, grown from the floor): its turning load is the
## weight past it times how far that weight's middle is from the joint,
## about the joint's line for a pin or a hinge and about the ball's middle,
## whichever way, for a ball. A joint in a loop shares its load by an amount
## statics cannot say and is not weighed, as Balance leaves a stud joint in
## a bonded wall. A joint whose load passes what the median joint measured
## holds droops; past what every one measured held, a loose one may.
##
## Pure and static: the table is read once, when the class loads, so a
## worker weighing a model reads it as the main thread does.
class_name PoseHold
extends RefCounted

const TABLE := "res://data/joint_hold.json"

## The kinds Balance weighs or names, by the table's keys.
const TECHNIC_BALL := "technic_ball"
const SMALL_BALL := "small_ball"
const FRICTION_PIN := "friction_pin"
const CLICK_HINGE := "click_hinge"
const HINGE := "hinge"
const TURNTABLE := "turntable"
const CLIP := "clip"

## How near a ball's middle and its socket's are for the ball to be in it,
## LDU: Joints.BALL_SLACK for a towball, and a cell more for a Technic ball,
## whose middle the part's shape labels to its own facets.
const SMALL_SLACK := 2.0
const TECHNIC_SLACK := 4.0

## The table, read when the class loads: kind -> its row.
static var _kinds: Dictionary = _read()


static func _read() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(TABLE)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not parsed is Dictionary or not (parsed as Dictionary).get("kinds") is Dictionary:
		push_error("PoseHold: %s could not be read; every friction joint is not known" % TABLE)
		return {}
	return parsed["kinds"]


## Whether [param kind] has a measured hold.
static func known(kind: String) -> bool:
	var row: Variant = _kinds.get(kind)
	return row is Dictionary and (row as Dictionary).get("holds_n_mm") != null


## What [param kind]'s median joint holds, N·cm (Balance's unit), where one
## lets go; 0 for a kind not known.
static func holds(kind: String) -> float:
	return _figure(kind, "holds_n_mm")


## What every joint of [param kind] measured held, N·cm: the working load.
static func every_held(kind: String) -> float:
	return _figure(kind, "every_held_n_mm")


## What every joint of [param kind] measured had given way under, N·cm.
static func every_gave(kind: String) -> float:
	return _figure(kind, "every_gave_n_mm")


static func _figure(kind: String, key: String) -> float:
	if not known(kind):
		return 0.0
	return float((_kinds[kind] as Dictionary).get(key, 0.0)) / 10.0


## How many joints of [param kind] were measured.
static func measured(kind: String) -> int:
	return int((_kinds.get(kind, {}) as Dictionary).get("joints_measured", 0)) if known(kind) else 0


## [param kind] as a person says it: "Technic ball joint", "click hinge".
static func said(kind: String) -> String:
	var row: Variant = _kinds.get(kind)
	return str((row as Dictionary).get("said", kind)) if row is Dictionary else kind.replace("_", " ")


## Every kind in the table, measured first.
static func kinds() -> PackedStringArray:
	var out := PackedStringArray()
	for kind: Variant in _kinds:
		if known(str(kind)):
			out.append(str(kind))
	for kind: Variant in _kinds:
		if not known(str(kind)):
			out.append(str(kind))
	return out


## "holds 60% of what hangs on it": [param share] the joint's hold over its
## load, as a whole percent under all of it, and as times over from all of
## it: "holds 1.4 times what hangs on it". For a session; the window says a
## droop's share alone ([method percent]).
static func share_words(share: float) -> String:
	if share >= 1.0:
		return "holds %s times what hangs on it" % (Balance.studs(share) if share < 100.0 else "100+")
	return "holds %d%% of what hangs on it" % percent(share)


## A share under all of what hangs on a joint as a whole percent, 0 to 99.
static func percent(share: float) -> int:
	return clampi(floori(share * 100.0), 0, 99)


# -- what joins two parts -------------------------------------------------------


## The friction joint between two parts that no stud and no pin joins, each
## [part id, Transform3D, Lbm.PartMesh]: {kind, at (a point on its line, or
## the ball's middle, in the frame the transforms are in), way (its line;
## Vector3.ZERO for a ball, which turns any way)}, or {} for none of these
## (glue, a hose, a part seated in another).
static func joint_between(one: Array, other: Array, library: PartLibrary) -> Dictionary:
	var ball: Dictionary = ball_between(one, other, library)
	if not ball.is_empty():
		return ball
	var kind: String = _hinge_kind(str(one[0]), library)
	var theirs: String = _hinge_kind(str(other[0]), library)
	# A clip on a hinge's bar is the clip's; a turntable's is the turntable's.
	for pick: String in [TURNTABLE, CLICK_HINGE, HINGE, CLIP]:
		if kind == pick or theirs == pick:
			kind = pick
			break
	if kind.is_empty():
		return {}
	for side: Array in [one, other]:
		var line: Array = Joints.hinge_line_of(side[2])
		if not line.is_empty() and (line[1] as Vector3) != Vector3.ZERO:
			var at: Transform3D = side[1]
			return {"kind": kind, "at": at * (line[0] as Vector3),
				"way": (at.basis * (line[1] as Vector3)).normalized()}
	return {"kind": kind, "at": (one[1] as Transform3D).origin, "way": Vector3.ZERO, "lineless": true}


## A ball of one in a socket of the other, either way round: the catalogue's
## (a towball's, 16 LDU across) and those only the part's exact shape labels
## (JointSnap.balls_of: a Technic ball, 10.2 mm, and towball sockets drawn as
## solid rings).
static func ball_between(one: Array, other: Array, library: PartLibrary) -> Dictionary:
	for pair: Array in [[one, other], [other, one]]:
		for ball: Array in _ends(pair[0], library, "ball"):
			for socket: Array in _ends(pair[1], library, "socket"):
				var technic: bool = ball[1] or socket[1]
				if (ball[0] as Vector3).distance_to(socket[0]) \
						<= (TECHNIC_SLACK if technic else SMALL_SLACK):
					return {"kind": TECHNIC_BALL if technic else SMALL_BALL,
						"at": ball[0], "way": Vector3.ZERO}
	return {}


## [param side]'s balls (or sockets) where the transform puts them, each
## [middle, whether it is a Technic ball's].
static func _ends(side: Array, library: PartLibrary, kind: String) -> Array:
	var out: Array = []
	var mesh: Lbm.PartMesh = side[2]
	var at: Transform3D = side[1]
	if mesh != null:
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == kind:
				out.append([at * connector.position, false])
	if library != null:
		for end: JointSnap.End in JointSnap.balls_of(library, str(side[0])):
			if end.kind == kind:
				out.append([at * end.at, end.sub == JointSnap.TECHNIC_BALL_SUB])
	return out


## Whether a pin joint between parts so named is a click rotation joint's:
## both are of the system, a pin with its click ring (47455, "Click Rotation")
## and a rotation joint's half ball or socket (48170, 48171, "Rotation
## Joint"), which turns on teeth, not on a friction pin's ridges.
static func clicks(one_name: String, other_name: String) -> bool:
	return _of_click_rotation(one_name) and _of_click_rotation(other_name)


static func _of_click_rotation(name: String) -> bool:
	return name.contains("Click Rotation") or name.contains("Rotation Joint")


## What a part's name says it turns on: "Turntable", a locking hinge's
## teeth ("Hinge ... Locking", a Technic rotation joint's click), a friction
## hinge, a clip; "" for none.
static func _hinge_kind(part_id: String, library: PartLibrary) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part_id) if library != null else null
	if info == null:
		return ""
	var name: String = info.name
	if name.contains("Turntable"):
		return TURNTABLE
	if (name.contains("Hinge") and name.contains("Locking")) or name.contains("Rotation Joint") \
			or name.contains("Click"):
		return CLICK_HINGE
	if name.contains("Hinge"):
		return HINGE
	if name.contains("Clip"):
		return CLIP
	return ""


# -- what a weighing says ----------------------------------------------------------


## The friction joints [param report] weighed, worst first: those whose load
## passes what one of their kind holds (Balance.JointLoad.droops).
static func drooping(report: Balance.Report) -> Array:
	var out: Array = []
	if report == null:
		return out
	for one: Balance.JointLoad in report.joints:
		if one.droops():
			out.append(one)
	out.sort_custom(func(a: Balance.JointLoad, b: Balance.JointLoad) -> bool:
		return a.share() < b.share())
	return out


## How [param report]'s pose holds, a line a thing said, for the Pose panel
## (a label a line, each line its own words in every language) and a
## session: the joints that droop, each with how far over; those a loose
## joint of their kind would droop on; and how many of each kind nobody has
## measured. Empty for a model with no friction joint. [param namer] names a
## part by its id.
static func pose_words(report: Balance.Report, namer: Callable, most: int = 3) -> String:
	if report == null or report.empty:
		return ""
	var droops: Array = drooping(report)
	var maybe: Array = []
	var weighed: int = 0
	for one: Balance.JointLoad in report.joints:
		if one.hold.is_empty():
			continue
		weighed += 1
		if one.may_droop():
			maybe.append(one)
	maybe.sort_custom(func(a: Balance.JointLoad, b: Balance.JointLoad) -> bool:
		return a.loose / a.moment < b.loose / b.moment)
	var unknown: Dictionary = {}   ## kind -> how many
	for one: Dictionary in report.unweighed:
		unknown[one["kind"]] = int(unknown.get(one["kind"], 0)) + 1
	if weighed == 0 and unknown.is_empty():
		return ""
	var lines := PackedStringArray()
	if not droops.is_empty():
		lines.append("Joints that droop: %d" % droops.size())
		for one: Balance.JointLoad in droops.slice(0, most):
			lines.append(joint_words(one, namer))
		if droops.size() > most:
			lines.append("And %d more." % (droops.size() - most))
	elif weighed > 0:
		lines.append("Friction joints weighed: %d, and none droops." % weighed)
	for one: Balance.JointLoad in maybe.slice(0, 1):
		lines.append("%s on %s holds, but a loose joint of its kind may not: the loosest measured held %d%% of this." % [
			str(namer.call(one.beyond)), str(namer.call(one.held_by)), percent(one.loose / one.moment)])
	for kind: String in [SMALL_BALL, CLICK_HINGE, HINGE, TURNTABLE, CLIP]:
		if unknown.has(kind):
			lines.append(UNKNOWN_WORDS[kind] % int(unknown[kind]))
	return "\n".join(lines)


## Each kind nobody has measured, counted.
const UNKNOWN_WORDS := {
	SMALL_BALL: "Small ball joints here: %d, not weighed: no one has published what one holds.",
	CLICK_HINGE: "Click hinges here: %d, not weighed: no one has published what one holds.",
	HINGE: "Hinges here: %d, not weighed: no one has published what one holds.",
	TURNTABLE: "Turntables here: %d, not weighed: no one has published what one holds.",
	CLIP: "Clips on bars here: %d, not weighed: no one has published what one holds.",
}


## One drooping friction joint and how far over it is: "#12 (Technic Ball
## Joint) on #3 (Brick 2 x 2 with Ball Socket), 25 g past it: its Technic
## ball joint holds 60% of what hangs on it".
static func joint_words(one: Balance.JointLoad, namer: Callable) -> String:
	var who: Array = [str(namer.call(one.beyond)), str(namer.call(one.held_by)), Balance.tidy(one.grams)]
	var share: int = percent(one.share())
	if one.hold == TECHNIC_BALL:
		return "%s on %s, %s g past it: its Technic ball joint holds %d%% of what hangs on it" % (who + [share])
	if one.pins > 1:
		return "%s on %s, %s g past it: its %d friction pins hold %d%% of what hangs on them" % (
			who + [one.pins, share])
	return "%s on %s, %s g past it: its friction pin holds %d%% of what hangs on it" % (who + [share])
