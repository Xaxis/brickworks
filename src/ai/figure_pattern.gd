## A character said once — a person, a four-legged animal, or a head on a
## neck — laid as a real set lays a brick-built one: every limb, the head and
## the tail on a working joint, posed, in its colours, sized to the brief.
##
## Why it is one call. Of eight character sessions told of the joints in
## every reply (2026-10-15, docs/BRICKBENCH.md "figures on joints"), two
## posed a limb. Each chose how to build at its first submit, with a shape or
## a stack of round bricks it could write in one entry, and an armature it had
## to lay and then dress cost it more than the body it already had. So the
## jointed body is the cheap one: a pattern beside "shape", which a session
## already reaches for, that lays the whole character with its joints, every
## part named for the session to build on (attach to "head.stud[0]") or to
## pose again (edit_model with a joint's align or yaw).
##
## The joints are the armatures' (Techniques "jointed figure", "jointed
## animal"), as BrickBench's verify.py passes them: arms on ball shoulders
## (14417) as a ball-and-socket chain (14419 then 14418) aimed by align, the
## head on a jumper's centre stud (87580) turned by yaw, an animal's head on a
## ball neck (22890 under 14418) and its tail a clip plate (63868) on a bar
## plate (60478). What is added is the body round them at the brief's size:
## legs, hips and torso stacked to its height, a chest wide enough at the
## larger size for curved shoulders between the joints, sleeves, hands, hair,
## feet with toes, a seat for a seated figure, and the pose said in words.
##
## What comes back is the design itself — bricks with names and attaches —
## for the reader to take as a session's own, as [Shells] does: nothing here
## is checked, the check is.
class_name FigurePattern
extends RefCounted

## The kinds, by the words a session may use for them.
const KINDS: Dictionary = {"person": "person", "figure": "person", "human": "person",
	"man": "person", "woman": "person", "humanoid": "person", "robot": "person",
	"statue": "person", "animal": "animal", "creature": "animal", "quadruped": "animal",
	"dog": "animal", "four legs": "animal", "head": "head", "bust": "head", "neck": "head"}

## Arm poses: [upper arm, forearm], each [out, up, forward] — out away from
## the body's side, mirrored for the other arm — and a yaw for the upper arm
## where a level one would otherwise meet its shoulder plate.
const ARM_POSES: Dictionary = {
	"down": [[0.32, -0.94, 0.1], [0.2, -0.85, 0.48], 0.0],
	"bent": [[0.35, 0.0, 0.94], [0.1, 0.6, 0.8], 90.0],
	"forward": [[0.35, 0.0, 0.94], [0.1, 0.05, 0.99], 90.0],
	"raised": [[0.5, 0.86, 0.0], [0.17, 0.98, 0.0], 0.0],
	"out": [[0.94, 0.34, 0.0], [0.85, 0.5, 0.15], 0.0],
}
## Words a pose may be said in, to one of ARM_POSES. A ball plate's socket
## folds only so far before it meets the plate it is on (measured: a forearm
## bent back past the upper arm, a fist to the chin, meets it by 1.4 to 2.7
## LDU; solved to reach the chin or the knee, the socket's rim meets the
## shoulder plate and the elbow folds into itself by 1 to 4 LDU, 2026-10-16),
## so those are said as the nearest pose that builds.
const POSE_WORDS: Dictionary = {"down": "down", "side": "down", "at side": "down",
	"hanging": "down", "rest": "down", "bent": "bent", "elbow": "bent", "holding": "bent",
	"forward": "forward", "reaching": "forward", "reach": "forward", "pointing": "forward",
	"point": "forward", "raised": "raised", "up": "raised", "waving": "raised", "wave": "raised",
	"overhead": "raised", "out": "out", "spread": "out", "outstretched": "out", "wide": "out",
	"to chin": "bent", "chin": "bent", "thinking": "bent", "fist to chin": "bent",
	"on knee": "forward", "knee": "forward", "on lap": "forward", "lap": "forward"}

## Torso lean forward, in degrees. A lean is a hinge (3937 under 3938) at the
## waist, the torso and all on it built on the hinge's top, so everything over
## the waist leans as one; past LEAN_MOST its front edge meets the hips.
const LEANS: Dictionary = {"forward": 25.0, "hunched": 25.0, "bowing": 25.0, "stooped": 25.0,
	"bent over": 30.0, "slightly forward": 12.0}
const LEAN_MOST := 30.0


## Plates up a leg's bricks are, and the parts of each size: [leg, hips,
## torso, how wide the torso is, the end studs the shoulders take, the stud
## the neck takes].
const SIZES: Dictionary = {
	1: {"leg": "3004", "leg_rot": 1, "leg_w": 1, "legs_at": [0, 3], "hips": "3020",
		"torso": "3001", "wide": 4, "left_stud": 1, "right_stud": 6, "neck_stud": 3,
		"foot": "3623", "foot_rot": 1},
	2: {"leg": "3003", "leg_rot": 0, "leg_w": 2, "legs_at": [0, 4], "hips": "3795",
		"torso": "2456", "wide": 6, "left_stud": 1, "right_stud": 10, "neck_stud": 5,
		"foot": "3021", "foot_rot": 1},
}

## A person this tall (plates, feet to crown) and taller is built at the larger
## size; an animal this long (studs) and longer.
const LARGE_PERSON := 34.0
const LARGE_ANIMAL := 7.0

const SKIN := 78        # Light Nougat
const HAIR := 70        # Reddish Brown
const JOINT := 72       # Dark Bluish Grey: 14417, 14419 and 22890 come in it
const SOCKET := 71      # Light Bluish Grey: 14418 does
## An eye is a round tile printed with a black eye and its highlight
## (98138p07) on a stud turned out, as Creator animals and BrickHeadz have
## theirs: white, so the print reads as an eye, not a hole.
const EYE := "98138p07"
const EYES := 15
const NOSE := 0
## The colours a bar plate (60478) is sold in: a tail's bar takes the body's
## colour when it is one of them, as a set's would.
const BAR_COLOURS: Array = [0, 1, 3, 4, 10, 14, 15, 19, 27, 28, 70, 71, 72, 78, 84, 191, 212,
	226, 272, 288, 321, 323, 378, 379, 484]


## The bricks of one character pattern, its names begun with [param prefix]
## ("" for the first), and what it came to: {"bricks", "said"}; {} with the
## reason in [param trouble] when it cannot be laid as said.
static func lay(pattern: Dictionary, trouble: Array, prefix: String = "") -> Dictionary:
	var said_kind: String = str(pattern.get("kind", "person")).strip_edges().to_lower()
	var kind: String = str(KINDS.get(said_kind, ""))
	if kind.is_empty():
		trouble.append("figure: kind is \"person\", \"animal\" or \"head\", not \"%s\"" % said_kind)
		return {}
	var at: Dictionary = pattern.get("at", {}) if pattern.get("at") is Dictionary else {}
	var origin := Vector3(roundf(float(at.get("x", 0.0))), roundf(float(at.get("y", 0.0))),
		roundf(float(at.get("z", 0.0))))
	var colours: Dictionary = pattern.get("colors", pattern.get("colours", {})) \
		if (pattern.get("colors", pattern.get("colours", {})) is Dictionary) else {}
	var main: int = int(pattern.get("color", pattern.get("colour", 1)))
	var out: Dictionary
	match kind:
		"person":
			out = _person(pattern, origin, main, colours, prefix, trouble)
		"animal":
			out = _animal(pattern, origin, main, colours, prefix, trouble)
		_:
			out = _head(pattern, origin, main, colours, prefix)
	if out.is_empty():
		return {}
	return out


## A colour from the pattern's colors by any of [param keys], else [param fallback].
static func _colour(colours: Dictionary, keys: Array, fallback: int) -> int:
	for key: String in keys:
		if colours.has(key):
			return int(colours[key])
	return fallback


## A pose word said for [param limb] in the pattern's pose, as one of ARM_POSES.
static func _arm_pose(pose: Dictionary, limb: String, fallback: String) -> Variant:
	var said: Variant = pose.get(limb, fallback)
	if said is Array and (said as Array).size() in [2, 3]:
		return said
	var word: String = str(said).strip_edges().to_lower()
	return str(POSE_WORDS.get(word, word if ARM_POSES.has(word) else ""))


## [out, up, forward] as the model's direction, for the arm on the low-x side
## ([param side] -1) or the high-x side (1).
static func _way(v: Array, side: float) -> Array:
	var d := Vector3(float(v[0]) * side, float(v[1]), float(v[2])).normalized()
	return [snappedf(d.x, 0.0001), snappedf(d.y, 0.0001), snappedf(d.z, 0.0001)]


static func _at(brick: Dictionary, origin: Vector3) -> Dictionary:
	brick["x"] = float(brick["x"]) + origin.x
	brick["y"] = float(brick["y"]) + origin.y
	brick["z"] = float(brick["z"]) + origin.z
	return brick


## A person facing +z, its right side at low x: feet with toes, legs, hips, a
## torso of bricks, arms on ball shoulders posed by words, hands, a head on a
## jumper's stud turned by its yaw, with a face and hair; seated, on a seat of
## its own; leaning, its torso on a hinge at the waist.
static func _person(pattern: Dictionary, origin: Vector3, main: int, colours: Dictionary,
		prefix: String, trouble: Array) -> Dictionary:
	var height: float = clampf(float(pattern.get("height", 30.0)), 20.0, 60.0)
	var size: int = 2 if height >= LARGE_PERSON else 1
	var s: Dictionary = SIZES[size]
	var pose: Dictionary = pattern.get("pose", {}) if pattern.get("pose") is Dictionary else {}
	var seated: bool = bool(pose.get("seated", pattern.get("seated", false)))
	var skin: int = _colour(colours, ["skin", "hands", "face"], SKIN)
	var shirt: int = _colour(colours, ["torso", "shirt", "body", "top"], main)
	var legs_c: int = _colour(colours, ["legs", "trousers", "pants"], main)
	var feet_c: int = _colour(colours, ["feet", "shoes", "boots"], legs_c)
	var hair_c: int = _colour(colours, ["hair", "hat"], HAIR)
	var head_c: int = _colour(colours, ["head"], skin)
	var sleeve_c: int = _colour(colours, ["arms", "sleeves"], shirt)
	var eye_c: int = _colour(colours, ["eyes"], EYES)
	# The ball parts come in greys only; tiles over them carry the sleeve.
	var joint_c: int = _colour(colours, ["joints"], JOINT)
	var arm_words := {}
	for limb: String in ["right arm", "left arm"]:
		var p: Variant = _arm_pose(pose, limb, "forward" if seated else "down")
		if p is String and (p as String).is_empty():
			trouble.append("figure: the %s's pose is one of %s, or [[out, up, forward] of the "
				% [limb, ", ".join(PackedStringArray(ARM_POSES.keys()))]
				+ "upper arm, the same of the forearm]; not %s" % JSON.stringify(pose.get(limb)))
			return {}
		arm_words[limb] = p
	var lean_said: Variant = pose.get("lean", pose.get("torso", pattern.get("lean", null)))
	var lean: Dictionary = _lean(lean_said)
	if lean.has("error"):
		trouble.append("figure: %s" % lean["error"])
		return {}
	var n: String = prefix
	var bricks: Array = []
	var wide: int = int(s["wide"])
	var leg_w: int = int(s["leg_w"])
	# Heights, in plates: feet 1, legs and hips, torso of bricks, neck 1, head 3
	# (two of them at the larger size), hair 1. Legs and torso share the rest,
	# the legs a little more, as a person's are.
	var head_plates: int = 6
	var rest: float = height - 1.0 - 1.0 - 1.0 - head_plates - 1.0
	var courses: int = maxi(4, roundi(rest / 3.0))
	var torso_n: int = maxi(2, floori(courses * 0.45))
	var leg_n: int = maxi(2, courses - torso_n)
	var y: float = 0.0
	var seat_said: String = ""
	if seated:
		# A seat on a plate of its own; shins and feet stand in front of it as
		# tall as it is; each thigh is two layers of plates lying forward from
		# the seat's back over its knee, apart as the legs are, and the torso
		# stands on the hips across their back. One slab of plates for both
		# read as a table with a person behind it.
		var shin_n: int = maxi(2, ceili(leg_n * 0.55))
		var seat_c: int = _colour(colours, ["seat", "block", "rock"], 72)
		var deep: int = 4 if size == 1 else 6
		var thigh: String = "3666" if size == 1 else "3034"     # 1x6, 2x8: the seat and the knee
		var over: String = "3710" if size == 1 else "3795"      # 1x4, 2x6: in front of the hips
		bricks.append(_at({"part": "3031" if size == 1 else "3958", "color": seat_c,
			"x": 0, "y": 0, "z": 0, "rot": 0, "name": "%sseat" % n}, origin))
		for i: int in shin_n:
			for row: int in deep / 2:
				# Each course's bricks shifted a row from the one under it's.
				var shift: int = 0 if i % 2 == 0 else 1
				if shift == 1 and row == deep / 2 - 1:
					continue
				bricks.append(_at({"part": "3001" if size == 1 else "2456", "color": seat_c,
					"x": 0, "y": 1 + 3 * i, "z": row * 2 + shift, "rot": 0}, origin))
			if i % 2 == 1:
				for z: int in [0, deep - 1]:
					bricks.append(_at({"part": "3010" if size == 1 else "3009", "color": seat_c,
						"x": 0, "y": 1 + 3 * i, "z": z, "rot": 0}, origin))
		var top: float = 1.0 + 3.0 * shin_n
		for leg: int in 2:
			var lx: int = int(s["legs_at"][leg])
			bricks.append(_at({"part": s["foot"], "color": feet_c, "x": lx, "y": 0,
				"z": deep, "rot": s["foot_rot"], "name": "%s%s foot" % [n, ["right", "left"][leg]]},
				origin))
			for i: int in shin_n:
				bricks.append(_at({"part": s["leg"], "color": legs_c, "x": lx, "y": 1 + 3 * i,
					"z": deep, "rot": s["leg_rot"]}, origin))
		for leg: int in 2:
			var lx: int = int(s["legs_at"][leg])
			var side: String = ["right", "left"][leg]
			bricks.append(_at({"part": thigh, "color": legs_c, "x": lx, "y": top, "z": 0,
				"rot": 1, "name": "%s%s thigh" % [n, side]}, origin))
			bricks.append(_at({"part": over, "color": legs_c, "x": lx, "y": top + 1, "z": 2,
				"rot": 1, "name": "%s%s knee" % [n, side]}, origin))
		y = top + 1.0
		seat_said = ", seated on a block of %d courses (its \"seat\"), thighs forward on it" % shin_n
	else:
		for leg: int in 2:
			var lx: int = int(s["legs_at"][leg])
			# A foot a stud longer than the leg, its toe forward.
			bricks.append(_at({"part": s["foot"], "color": feet_c, "x": lx, "y": 0,
				"z": 0, "rot": s["foot_rot"], "name": "%s%s foot" % [n, ["right", "left"][leg]]},
				origin))
			for i: int in leg_n:
				bricks.append(_at({"part": s["leg"], "color": legs_c, "x": lx, "y": 1 + 3 * i,
					"z": 0, "rot": s["leg_rot"],
					"name": "%s%s leg" % [n, ["right", "left"][leg]] if i == leg_n - 1 else ""},
					origin))
		y = 1.0 + 3.0 * leg_n
	var hips_z: int = 0
	bricks.append(_at({"part": s["hips"], "color": legs_c, "x": 0, "y": y, "z": hips_z,
		"rot": 0, "name": "%ships" % n}, origin))
	y += 1.0
	var leaning: bool = absf(float(lean.get("degrees", 0.0))) > 0.01
	if leaning:
		# A hinge course in place of the torso's first: hinge bricks (3937) along
		# the back of the hips, their tops (3938) turned forward by the lean, and
		# the torso built up on the tops, so it folds over the hips' front rather
		# than off their back. Leaning back or to a side turns the base round,
		# and the torso with it, which the shoulders' studs do not follow yet.
		var degrees: float = float(lean["degrees"])
		for k: int in wide / 2:
			var base_name: String = "%swaist%s" % [n, "" if k == 0 else " %d" % (k + 1)]
			bricks.append(_at({"part": "3937", "color": legs_c, "x": 2 * k, "y": y,
				"z": hips_z, "rot": 0, "name": base_name}, origin))
			bricks.append({"part": "3938", "color": shirt,
				"name": "%swaist top%s" % [n, "" if k == 0 else " %d" % (k + 1)],
				"attach": {"to": "%s.hinge[0]" % base_name, "by": "hinge[0]", "yaw": -degrees}})
		bricks.append({"part": s["torso"], "color": shirt, "name": "%storso" % n
			if torso_n > 2 else "%schest" % n,
			"attach": {"to": "%swaist top.open[0]" % n, "by": "hole[1]"}})
		for i: int in range(2, torso_n):
			var below: String = "%storso" % n if i == 2 else "%storso %d" % [n, i - 1]
			bricks.append({"part": s["torso"], "color": shirt,
				"name": "%schest" % n if i == torso_n - 1 else "%storso %d" % [n, i],
				"attach": {"to": "%s.stud[0]" % below, "by": "hole[0]"}})
	else:
		for i: int in torso_n:
			bricks.append(_at({"part": s["torso"], "color": shirt, "x": 0, "y": y + 3 * i,
				"z": hips_z, "rot": 0, "name": "%schest" % n if i == torso_n - 1 else ""}, origin))
	y += 3.0 * torso_n
	# Shoulders: ball plates on the chest's end studs, balls out past its sides,
	# each covered by a tile in the sleeve's colour, as a set hides a joint's
	# grey under the colour of what it is in.
	bricks.append({"part": "14417", "color": joint_c, "name": "%sright shoulder" % n,
		"attach": {"to": "%schest.stud[%d]" % [n, s["left_stud"]], "by": "hole[0]", "yaw": 90}})
	bricks.append({"part": "14417", "color": joint_c, "name": "%sleft shoulder" % n,
		"attach": {"to": "%schest.stud[%d]" % [n, s["right_stud"]], "by": "hole[0]", "yaw": 270}})
	for side_word: String in ["right", "left"]:
		bricks.append({"part": "3069b", "color": sleeve_c, "name": "%s%s shoulder top" % [n, side_word],
			"attach": {"to": "%s%s shoulder.open[0]" % [n, side_word], "by": "hole[0]"}})
	if size == 2:
		# Curved shoulders on the studs between the joints and the neck.
		for k: int in 2:
			bricks.append({"part": "11477", "color": shirt, "attach": {"to": "%schest.stud[%d]"
				% [n, [2, 8][k]], "by": "hole[1]"}})
	# Arms: upper arm in its sleeve, forearm, hand.
	for side_n: int in 2:
		var limb: String = ["right arm", "left arm"][side_n]
		var side: float = -1.0 if side_n == 0 else 1.0
		var side_word: String = ["right", "left"][side_n]
		var words: Variant = arm_words[limb]
		var upper_way: Array
		var fore_way: Array
		var yaw: float = 0.0
		if words is Array:
			upper_way = _way(words[0], side)
			fore_way = _way(words[1], side)
			yaw = float(words[2]) if (words as Array).size() > 2 else 0.0
		else:
			var p: Array = ARM_POSES[words]
			upper_way = _way(p[0], side)
			fore_way = _way(p[1], side)
			yaw = float(p[2])
		var arm_attach: Dictionary = {"to": "%s%s shoulder.ball[0]" % [n, side_word],
			"by": "ball[1]", "align": ["-x", upper_way]}
		if yaw != 0.0:
			arm_attach["yaw"] = yaw
		bricks.append({"part": "14419", "color": joint_c, "name": "%s%s upper arm" % [n, side_word],
			"attach": arm_attach})
		bricks.append({"part": "3069b", "color": sleeve_c, "name": "%s%s sleeve" % [n, side_word],
			"attach": {"to": "%s%s upper arm.open[0]" % [n, side_word], "by": "hole[0]"}})
		bricks.append({"part": "14418", "color": SOCKET if joint_c == JOINT else joint_c,
			"name": "%s%s forearm" % [n, side_word], "attach": {
				"to": "%s%s upper arm.ball[0]" % [n, side_word], "by": "ball[0]",
				"align": ["-x", fore_way]}})
		bricks.append({"part": "3070b", "color": sleeve_c,
			"attach": {"to": "%s%s forearm.open[1]" % [n, side_word], "by": "hole[0]"}})
		bricks.append({"part": "3062b", "color": skin, "name": "%s%s hand" % [n, side_word],
			"attach": {"to": "%s%s forearm.open[0]" % [n, side_word], "by": "tube[0]"}})
	# The head on a jumper's centre stud, turned by its yaw, with its face.
	var turn: float = float(pose.get("head", 0.0)) if str(pose.get("head", "0")).is_valid_float() \
		else 0.0
	bricks.append({"part": "87580", "color": skin, "name": "%sneck" % n,
		"attach": {"to": "%schest.stud[%d]" % [n, s["neck_stud"]], "by": "hole[1]"}})
	bricks.append_array(_head_on(n, "%sneck.open[0]" % n, turn, head_c, hair_c, eye_c,
		_has_face(pattern)))
	var tall: float = y + 1.0 + head_plates + 1.0
	var lean_word: String = ""
	if leaning:
		lean_word = ", leaning forward %d° on a hinge at the waist (\"waist\")" \
			% roundi(float(lean["degrees"]))
	return {"bricks": bricks, "said": ("figure: a person %d plates tall%s%s, facing +z, its "
		% [roundi(tall), seat_said, lean_word] + "right side at low x; arms on ball shoulders "
		+ "(%s %s, %s %s), " % ["right arm", _word(arm_words["right arm"]), "left arm",
			_word(arm_words["left arm"])]
		+ "head on a jumper's stud with eyes. Its parts are named to build on and pose again: %s"
		% _names(bricks))}


## Whether the pattern wants a face laid: "face": false or "none" leaves it to
## the session (a helmet, a mask, a head seen from behind).
static func _has_face(pattern: Dictionary) -> bool:
	var said: Variant = pattern.get("face", true)
	return not (said is bool and not said) and not ["none", "no", "false", "off"].has(
		str(said).strip_edges().to_lower())


## A torso lean said, as {"degrees": forward}, or {"error"}: a word of
## LEANS or degrees, 0 to LEAN_MOST.
static func _lean(said: Variant) -> Dictionary:
	if said == null or (said is String and (said as String).strip_edges().is_empty()):
		return {"degrees": 0.0}
	if said is float or said is int or str(said).is_valid_float():
		return {"degrees": clampf(float(said), 0.0, LEAN_MOST)}
	var word: String = str(said).strip_edges().to_lower().trim_prefix("leaning ").trim_prefix(
		"lean ")
	if ["none", "upright", "straight", "no"].has(word):
		return {"degrees": 0.0}
	if not LEANS.has(word):
		return {"error": "a lean is forward (%s), or degrees forward up to %d; not %s"
			% [", ".join(PackedStringArray(LEANS.keys())), roundi(LEAN_MOST),
				JSON.stringify(said)]}
	return {"degrees": float(LEANS[word])}


## A head on [param on] (a jumper's centre stud), turned by [param turn]: a
## round brick, and over it a course of a brick with two studs on one side
## (11211) at the front, the way the head faces, carrying two printed eyes
## (98138p07), the back of the head behind it in the hair's colour, the hair
## over both. Two eyes a stud apart on side studs is how a BrickHeadz figure
## has its face.
static func _head_on(n: String, on: String, turn: float, skin: int, hair_c: int, eye_c: int,
		face: bool) -> Array:
	var out: Array = []
	out.append({"part": "3941", "color": skin, "name": "%shead" % n,
		"attach": {"to": on, "by": "tube[0]", "yaw": turn}})
	out.append({"part": "11211" if face else "3004", "color": skin, "name": "%sface" % n,
		"attach": {"to": "%shead.stud[0]" % n, "by": "hole[0]"}})
	out.append({"part": "3004", "color": hair_c, "name": "%sback of head" % n,
		"attach": {"to": "%shead.stud[1]" % n, "by": "hole[0]"}})
	if face:
		for k: int in 2:
			out.append({"part": EYE, "color": eye_c, "name": "%s%s eye" % [n, ["right", "left"][k]],
				"attach": {"to": "%sface.open[%d]" % [n, k], "by": "tube[0]"}})
	out.append({"part": "4032b", "color": hair_c, "name": "%shair" % n,
		"attach": {"to": "%sface.stud[0]" % n, "by": "hole[0]"}})
	return out


static func _word(words: Variant) -> String:
	return "as aimed" if words is Array else str(words)


static func _names(bricks: Array) -> String:
	var names := PackedStringArray()
	for brick: Dictionary in bricks:
		var name: String = str(brick.get("name", ""))
		if not name.is_empty():
			names.append("\"%s\"" % name)
	return ", ".join(names) + "."


## A four-legged animal facing -x (its side to the front camera): legs, a body
## of bricks with curved slopes along its back at the larger size, the head on
## a ball neck aimed by "head" ([out, up, forward] or a word), its eyes on the
## sides of its head and a nose on its muzzle, the tail on a bar raised by
## "tail".
static func _animal(pattern: Dictionary, origin: Vector3, main: int, colours: Dictionary,
		prefix: String, trouble: Array) -> Dictionary:
	var length: float = clampf(float(pattern.get("length", 6.0)), 4.0, 12.0)
	var size: int = 2 if length >= LARGE_ANIMAL else 1
	var pose: Dictionary = pattern.get("pose", {}) if pattern.get("pose") is Dictionary else {}
	var body_c: int = _colour(colours, ["body"], main)
	var legs_c: int = _colour(colours, ["legs"], body_c)
	var head_c: int = _colour(colours, ["head"], body_c)
	var tail_c: int = _colour(colours, ["tail"], body_c)
	var joint_c: int = _colour(colours, ["joints"], JOINT)
	var eye_c: int = _colour(colours, ["eyes"], EYES)
	var nose_c: int = _colour(colours, ["nose", "muzzle"], NOSE)
	var n: String = prefix
	var bricks: Array = []
	var long: int = 4 if length < 5.0 else (6 if length < 7.0 else 8)
	var body_part: String = {4: "3001", 6: "2456", 8: "3007"}[long]
	var leg_n: int = clampi(roundi(length * 0.4), 2, 4)
	var deep: int = 2 if size == 1 else 4
	# Legs at the four corners, round at the larger size.
	var leg_part: String = "3005" if size == 1 else "3941"
	var leg_w: int = 1 if size == 1 else 2
	var names_legs: Array = ["right foreleg", "left foreleg", "right hind leg", "left hind leg"]
	var k: int = 0
	for lx: int in [0, long - leg_w]:
		for lz: int in [deep - leg_w, 0]:
			for i: int in leg_n:
				bricks.append(_at({"part": leg_part, "color": legs_c, "x": lx, "y": 3 * i,
					"z": lz, "rot": 0, "name": "%s%s" % [n, names_legs[k]] if i == leg_n - 1 else ""},
					origin))
			k += 1
	var y: float = 3.0 * leg_n
	# The body: one course of bricks, two side by side at the larger size, a
	# second course over them crossing the joint.
	if size == 1:
		bricks.append(_at({"part": body_part, "color": body_c, "x": 0, "y": y, "z": 0, "rot": 0,
			"name": "%sbody" % n}, origin))
	else:
		for row: int in 2:
			bricks.append(_at({"part": body_part, "color": body_c, "x": 0, "y": y, "z": row * 2,
				"rot": 0, "name": "%sbody" % n if row == 0 else ""}, origin))
		bricks.append(_at({"part": body_part, "color": body_c, "x": 0, "y": y + 3, "z": 1,
			"rot": 0, "name": "%sback" % n}, origin))
	# The neck: a ball plate past the front, the head on its socket.
	var top: String = "%sbody" % n if size == 1 else "%sback" % n
	var head_way: Variant = pose.get("head", [-0.94, 0.34, 0.0])
	var head_dir: Array = [-0.94, 0.34, 0.0]
	match str(head_way).to_lower():
		"up", "raised":
			head_dir = [-0.6, 0.8, 0.0]
		"down", "grazing", "low":
			head_dir = [-0.7, -0.7, 0.0]
		"forward", "level":
			head_dir = [-1.0, 0.05, 0.0]
		"left":
			head_dir = [-0.7, 0.3, 0.65]
		"right":
			head_dir = [-0.7, 0.3, -0.65]
	if head_way is Array and (head_way as Array).size() == 3:
		head_dir = head_way
	bricks.append({"part": "22890", "color": joint_c, "name": "%sneck" % n,
		"attach": {"to": "%s.stud[1]" % top, "by": "hole[1]", "yaw": 180}})
	# The neck's grey plate under a tile of the body's colour.
	bricks.append({"part": "3069b", "color": body_c, "name": "%sneck top" % n,
		"attach": {"to": "%sneck.open[0]" % n, "by": "hole[0]"}})
	bricks.append({"part": "14418", "color": SOCKET if joint_c == JOINT else joint_c, "name": "%sjaw" % n, "attach": {
		"to": "%sneck.ball[0]" % n, "by": "ball[0]", "align": ["-x", _way(head_dir, 1.0)]}})
	# The head: a brick on the jaw, its front stud the muzzle with a nose on
	# it, and over its back stud a brick with studs on two opposite sides,
	# an eye on each, so the eyes look out of the sides of the head as a
	# Creator animal's do.
	bricks.append({"part": "3004", "color": head_c, "name": "%shead" % n,
		"attach": {"to": "%sjaw.open[0]" % n, "by": "hole[0]"}})
	bricks.append({"part": "47905", "color": head_c, "name": "%scrown" % n,
		"attach": {"to": "%shead.stud[1]" % n, "by": "hole[0]"}})
	if _has_face(pattern):
		for e: int in 2:
			bricks.append({"part": EYE, "color": eye_c, "name": "%s%s eye" % [n, ["right", "left"][e]],
				"attach": {"to": "%scrown.open[%d]" % [n, e], "by": "tube[0]"}})
		bricks.append({"part": "98138", "color": nose_c, "name": "%snose" % n,
			"attach": {"to": "%shead.stud[0]" % n, "by": "tube[0]"}})
	# The tail: a bar plate past the back, a clip plate on it, raised.
	var tail_said: Variant = pose.get("tail", "raised")
	var tail_yaw: float = 210.0
	match str(tail_said).to_lower():
		"down", "drooping", "low":
			tail_yaw = 150.0
		"level", "straight":
			tail_yaw = 180.0
		"up", "high":
			tail_yaw = 240.0
	if str(tail_said).is_valid_float():
		tail_yaw = 180.0 + float(tail_said)
	var rump_stud: int = 6 if long == 4 else (10 if long == 6 else 14)
	bricks.append({"part": "60478", "color": body_c if BAR_COLOURS.has(body_c) else joint_c,
		"name": "%srump" % n,
		"attach": {"to": "%s.stud[%d]" % [top, rump_stud], "by": "hole[1]"}})
	bricks.append({"part": "63868", "color": tail_c, "name": "%stail" % n,
		"attach": {"to": "%srump.bar[0]" % n, "by": "clip[0]", "flip": true, "yaw": tail_yaw}})
	bricks.append({"part": "3069b", "color": tail_c,
		"attach": {"to": "%stail.stud[0]" % n, "by": "hole[0]"}})
	return {"bricks": bricks, "said": ("figure: a four-legged animal %d studs long, its head "
		% long + "toward -x on a ball neck, eyes on its sides and a nose on its muzzle, and its "
		+ "tail on a bar. Its parts are named to build on and pose again: %s" % _names(bricks))}


## A head on a neck that turns and nods, for a bust, a thing with a head, a
## creature that is only its head: a column of round bricks from at, a jumper
## on its top, the head on the jumper's stud turned by "head", with its face.
static func _head(pattern: Dictionary, origin: Vector3, main: int, colours: Dictionary,
		prefix: String) -> Dictionary:
	var n: String = prefix
	var neck_c: int = _colour(colours, ["neck"], main)
	var head_c: int = _colour(colours, ["head", "skin", "face"], SKIN)
	var hair_c: int = _colour(colours, ["hair", "hat"], HAIR)
	var eye_c: int = _colour(colours, ["eyes"], EYES)
	var tall: int = clampi(roundi(float(pattern.get("height", 9.0)) / 3.0), 1, 12)
	var bricks: Array = []
	for i: int in tall:
		bricks.append(_at({"part": "3941", "color": neck_c, "x": 0, "y": 3 * i, "z": 0, "rot": 0,
			"name": "%sneck" % n if i == tall - 1 else ""}, origin))
	var pose: Dictionary = pattern.get("pose", {}) if pattern.get("pose") is Dictionary else {}
	var turn: float = float(pose.get("head", 0.0)) if str(pose.get("head", "0")).is_valid_float() \
		else 0.0
	bricks.append({"part": "87580", "color": head_c, "name": "%schin" % n,
		"attach": {"to": "%sneck.stud[1]" % n, "by": "hole[1]"}})
	bricks.append_array(_head_on(n, "%schin.open[0]" % n, turn, head_c, hair_c, eye_c,
		_has_face(pattern)))
	return {"bricks": bricks, "said": ("figure: a head on a neck %d plates tall, the head turned "
		% (3 * tall) + "on a jumper's stud (its yaw in edit_model turns it), its face toward +z. "
		+ "Its parts are named to build on: %s" % _names(bricks))}
