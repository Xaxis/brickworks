## A minifigure: which real part fills each slot, in which colour, and
## exactly where each one sits.
##
## A figure is nine or ten parts and almost none of them is on the stud
## grid. An arm hangs 15.552 LDU out from the middle of the torso, turned
## 9.782 degrees to follow its slope; a hand is turned 45 degrees in the
## arm; the current legs sit 1.25 LDU behind the studs they stand on.
## Guess any of that and the figure reads as broken at a glance. So none
## of it is guessed: every number below is the LDraw library's own,
## where it is written down, and was checked against the 517 figures in
## the 105 real sets of LDraw's model repository (tools/minifig.py
## measure, which prints the agreement joint by joint).
##
## Every minifigure part in the catalogue is offered in some slot —
## heads of every mould, torsos, legs, skirts, capes, visors, what goes
## on the back and in either hand. Which slot is the catalogue's own
## category where LDraw has one for it, and LDraw's naming where it files
## the part under plain "Minifig" (slot_for). The parts the standard
## joints do not fit — a battle droid's arms, a hook for a hand, a wooden
## leg, a baby's arms — sit where the library's own assemblies put them
## (MinifigData.PLACES, from tools/minifig.py data).
##
## Everything is worked out in LDraw's axes, the axes those numbers were
## written in, and turned into the app's only at the end.
class_name Minifig
extends RefCounted

## The slots, in the order a figure is described: top to bottom, then
## what it holds.
const SLOTS: Array[String] = [
	"headwear", "hat_extra", "head", "neck", "back", "cape", "torso", "arms",
	"hands", "hips", "hipwear", "legs", "footwear", "accessory", "accessory_left"]
## Slots a figure may leave empty: everything but the torso its frame is
## found from. A head may go too, for a body moulded with one (Gollum).
const OPTIONAL: Array[String] = [
	"headwear", "hat_extra", "head", "neck", "back", "cape", "arms", "hands",
	"hips", "hipwear", "legs", "footwear", "accessory", "accessory_left"]
## What the figure holds rather than wears, one slot a hand.
const HELD: Array[String] = ["accessory", "accessory_left"]

const TITLES: Dictionary = {
	"headwear": "Headgear", "hat_extra": "Headgear extra", "head": "Head",
	"neck": "Neck", "back": "Back", "cape": "Cape", "torso": "Torso",
	"arms": "Arms", "hands": "Hands", "hips": "Hips", "hipwear": "Skirt, tail",
	"legs": "Legs", "footwear": "Feet", "accessory": "In right hand",
	"accessory_left": "In left hand",
}

const ARM_RIGHT := "3818"
const ARM_LEFT := "3819"
const HAND := "3820"
const PLAIN_HIPS := "3815b"
const PLAIN_LEGS := "3816c"     ## the right leg; the left is its pair, 3817c
const PLAIN_LEFT_LEG := "3817c"

# -- where the parts go ------------------------------------------------------
#
# Each is twelve numbers the way an LDraw type-1 line writes them: x y z,
# then the rotation by rows. All relative to the torso's origin, which is
# the middle of its top, in LDraw's axes: +Y down, the figure facing -Z.

## 3818.dat: "Place at -15.552 9 0 relative to torso ... rotate 9.782
## about z axis to align with slope of torso", and line 2 of 76382.dat,
## the library's own torso with arms and hands. 114 of 517 real figures
## exactly, 243 more at the same shoulder with the arm raised, 95 at
## (-15.5, 8, 0): the convention of an older generator.
const ARM_R: Array[float] = [-15.552, 9, 0, 0.985, -0.17, 0, 0.17, 0.985, 0, 0, 0, 1]
const ARM_L: Array[float] = [15.552, 9, 0, 0.985, 0.17, 0, -0.17, 0.985, 0, 0, 0, 1]
## 76382.dat lines 4 and 5. Which is the arm's own frame times a 45
## degree turn about X, 5 LDU in and 18.89 down the arm. Of 520 real
## right hands, 68 sit in their arm exactly so and 322 more within 1 LDU
## (set 10184 has (-23.86, 26.6, -10.32), 0.5 LDU off); 124 are turned.
const HAND_R: Array[float] = [-23.69, 26.774, -9.898,
	0.985, -0.12, 0.12, 0.17, 0.696, -0.696, 0, 0.707, 0.707]
const HAND_L: Array[float] = [23.69, 26.774, -9.898,
	0.985, 0.12, -0.12, -0.17, 0.696, -0.696, 0, 0.707, 0.707]
## Where real figures put the head: 304 of 517 exactly and 364 of the
## 405 that wear nothing at the neck. A neck accessory lifts it by its
## collar (MinifigData.NECK_LIFT); the head sits on the torso otherwise.
const HEAD: Array[float] = [0, -24, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
## Not written in the library. 481 of 496 real figures, and every one
## of the 19 with the short legs that are hips and legs in one part.
const HIPS: Array[float] = [0, 32, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
## 3816c.dat: "Move down 12 units to align with hips", as 10679b.dat
## does it. 378 of 495 real figures; 108 more are sitting or walking.
const LEGS: Array[float] = [0, 44, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
## The torso in the figure's own frame, whose origin is the middle of
## the two studs it stands on, for the figure every other shape is
## measured against: the current legs' hole is 1.25 LDU forward of the
## leg's origin (3816c.dat: "Move at z=1.25 relative to stud grid") and
## 72 below the torso: 32 to the hips, 12 to the legs, 28 down them.
## Short legs hold their studs 24 under the hips, square under them
## (41879a: stud23d at 10 24 0). Any other legs stand where their own
## geometry ends (_stance), which gives these two back exactly.
const TORSO_STANDING: Array[float] = [0, -72, 1.25, 1, 0, 0, 0, 1, 0, 0, 0, 1]
const TORSO_SHORT: Array[float] = [0, -56, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
## Half the distance between a figure's two studs: where each foot is.
const FOOT_APART := 10.0

## Where a hand closes, in the hand's own frame (3820.dat: "The centre
## of the grip is at x, y -.8229, z -9.8948"; "The Hand angle is 14.5
## degrees"). An accessory's bar is laid along this axis through this
## point; where its bar is comes from MinifigData.GRIPS.
const GRIP := Vector3(0.0, -0.8229, -9.8948)
const GRIP_AXIS := Vector3(0.0, 0.968148, 0.25038)

## Where a cloth cape hangs from: the top of the torso's back, which it
## lies over (973.dat: the back face is at z 10).
const SHOULDERS := Vector3(0.0, 0.0, 10.5)

## LDraw's axes into the app's: a half turn about X, as LdrModel does it.
const FLIP := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, -1, 0),
	Vector3(0, 0, -1)), Vector3.ZERO)

## The colours a new figure starts in: the yellow of a classic figure,
## and the town colours of the first ones. A part chosen for a slot that
## is not made in its colour comes in one it is (fitting_colour).
const START: Dictionary = {
	"headwear": 70, "hat_extra": 47, "head": 14, "neck": 0, "back": 0, "cape": 4,
	"torso": 4, "arms": 4, "hands": 14, "hips": 1, "hipwear": 0, "legs": 1,
	"footwear": 0, "accessory": 0, "accessory_left": 0,
}

var name: String = "Minifig"
## Slot -> part id. Empty for an optional slot left bare.
var parts: Dictionary = {}
## Slot -> LDraw colour code.
var colours: Dictionary = {}


func _init() -> void:
	parts = {"headwear": "3901", "hat_extra": "", "head": "3626cp01", "neck": "",
		"back": "", "cape": "", "torso": "973", "arms": ARM_RIGHT, "hands": HAND,
		"hips": PLAIN_HIPS, "hipwear": "", "legs": PLAIN_LEGS, "footwear": "",
		"accessory": "", "accessory_left": ""}
	colours = START.duplicate()


func copy() -> Minifig:
	var other := Minifig.new()
	other.name = name
	other.parts = parts.duplicate()
	other.colours = colours.duplicate()
	return other


func part(slot: String) -> String:
	return str(parts.get(slot, ""))


# -- the parts, placed ------------------------------------------------------


## Every part of the figure, placed in the figure's own frame: the app's
## axes, the origin the middle of the top of the two studs it stands on,
## facing +Z. [{slot, part, color, at}], torso first.
##
## Given the library, a figure holding something long — a spear, a
## staff, a lance — holds it the way real figures do rather than through
## the floor (see [method _held]), stands on whatever its legs end in,
## and a cape long enough to reach the ground is worn higher.
## Without one (part_ids) the places are the standard joints'.
func assemble(library: PartLibrary = null) -> Array[Dictionary]:
	# A print or a mould made in the app goes where the part it was made
	# from goes: the figure is put together from those, and they are
	# swapped back in at the end.
	var made: Dictionary = _made_here()
	if not made.is_empty():
		return _swapped_back(_stand_in(made).assemble(library), made, library)
	if library != null:
		_index(library)
	var local: Array[Dictionary] = []
	var put := func(slot: String, part_id: String, at: Transform3D) -> void:
		if not part_id.is_empty():
			local.append({"slot": slot, "part": part_id, "at": at})
	var torso_id: String = part("torso")
	put.call("torso", torso_id, Transform3D.IDENTITY)

	# What the figure stands on decides where everything is over the
	# studs, and where a long thing in a hand or a long cape has to stop.
	var lower: Dictionary = _lower(library)
	for item: Dictionary in lower["parts"]:
		put.call(item["slot"], item["part"], item["at"])
	var stance: Transform3D = lower["stance"]

	# The head, on whatever is round the neck.
	var lift: float = 0.0
	for slot: String in ["neck", "back", "cape"]:
		lift = maxf(lift, float(MinifigData.NECK_LIFT.get(worn_as(library, part(slot)), 0)))
	var head_at: Variant = _place(torso_id, part("head"), "c")
	var head: Transform3D = (head_at if head_at != null else _seated(library, part("head"))) \
		.translated(Vector3(0, -lift, 0))
	put.call("head", part("head"), head)
	# Headgear is drawn for the classic head, whose origin is its top:
	# it goes where that head's top would be, whatever head is under it.
	var hat: Transform3D = (head_at if head_at != null else _ldraw(HEAD)) \
		.translated(Vector3(0, -lift, 0))
	put.call("headwear", part("headwear"), hat)
	put.call("hat_extra", part("hat_extra"),
		hat * _on_headgear(part("hat_extra"), part("headwear")))
	put.call("neck", part("neck"), _worn(part("neck")))
	if not part("back").is_empty():
		put.call("back", part("back"),
			_clear_of_ground(library, part("back"), _worn(part("back")), stance))
	if not part("cape").is_empty():
		var cape: String = worn_as(library, part("cape"))
		put.call("cape", cape, _cape(library, cape, stance))

	# The arms, the hands on them, and what each hand holds.
	var arms: Dictionary = _arm_parts(library)
	var hands: Dictionary = _hand_parts(library)
	for side: String in ["r", "l"]:
		var arm: String = arms[side]
		if arm.is_empty():
			continue
		var arm_at: Transform3D = _arm_at(torso_id, arm, side)
		var hand: String = hands[side]
		var hand_at: Variant = _hand_at(torso_id, arm, arm_at, hand, side)
		if hand_at != null and not hand.is_empty() \
				and not _has_socket(library, arm, arm_at, hand, hand_at):
			hand_at = null
		var holds: String = part("accessory" if side == "r" else "accessory_left")
		var natural: Transform3D = hand_at if hand_at != null \
			else arm_at * _standard_hand_in_arm(side)
		var holding: Array = _held(holds, arm_at, natural, stance, library)
		put.call("arms", arm, holding[0])
		if hand_at != null and not hand.is_empty():
			put.call("hands", hand, holding[1])
		if not holds.is_empty():
			put.call("accessory" if side == "r" else "accessory_left", holds,
				(holding[1] as Transform3D) * (holding[2] as Transform3D))

	var out: Array[Dictionary] = []
	for item: Dictionary in local:
		var slot: String = item["slot"]
		var colour: int = int(colours.get(slot, 16))
		# The plain arm, hand or leg opposite one with no pair of its own
		# (a hook, a wooden leg) keeps the colour it had.
		if PAIRED.has(slot) and str(item["part"]) != part(slot) \
				and colours.has(slot + OTHER):
			colour = int(colours[slot + OTHER])
		out.append({"slot": slot, "part": item["part"], "color": colour,
			"at": FLIP * stance * (item["at"] as Transform3D) * FLIP})
	return out


## The hips, legs and whatever is on the feet, relative to the torso,
## and where the torso stands over the studs: {parts, stance}.
##
## The torso stands as high over the studs as its legs reach below it,
## and as far back as their feet are forward of it, both from the legs'
## own geometry: 72 and 1.25 for the current legs, 56 and 0 for the
## short ones, which are the numbers real sets use. Footwear raises it
## by what is under the sole. Without the library, the standard legs'.
func _lower(library: PartLibrary) -> Dictionary:
	var found: Array[Dictionary] = []
	var torso_id: String = part("torso")
	var legs: String = part("legs")
	var one_piece: bool = _one_piece(library, legs)
	if not one_piece and not part("hips").is_empty():
		var hips_at: Variant = _place(torso_id, part("hips"), "c")
		found.append({"slot": "hips", "part": part("hips"),
			"at": hips_at if hips_at != null else _ldraw(HIPS)})
	var placed_legs: Array[Dictionary] = []
	if not legs.is_empty():
		if one_piece and not _narrow(library, legs):
			var at: Variant = _place_on(torso_id, legs, "c")
			if at == null:
				var anywhere: Variant = _place("", legs, "c")
				at = _hung(library, legs, anywhere if anywhere != null else _ldraw(HIPS))
			placed_legs.append({"slot": "legs", "part": legs, "at": at})
		else:
			var pair: Dictionary = _leg_parts(library)
			# Legs joined in one moulding with no hips of their own (43220,
			# which springs go into) are one part, not one each side.
			var joined: bool = pair["r"] == pair["l"] and _side(library, legs) == "c" \
				and library != null and not _narrow(library, legs) \
				and _place(torso_id, legs, "r") == null
			for side: String in ["r", "l"]:
				var leg: String = pair[side]
				if leg.is_empty() or joined and side == "l":
					continue
				var at: Variant = _place_on(torso_id, leg, side)
				if at == null:
					var anywhere: Variant = _place("", leg, side)
					var standard: Transform3D = _hung(library, leg,
						anywhere if anywhere != null else _ldraw(LEGS))
					if anywhere == null and _side(library, leg) == "c" and _narrow(library, leg):
						standard.origin.x = -FOOT_APART if side == "r" else FOOT_APART
					at = standard
				placed_legs.append({"slot": "legs", "part": leg, "at": at})
			# Legs in pieces: springs with the legs they go into, and those
			# legs with their springs, where 43743-f1 puts them.
			for other: Array in MinifigData.LEGS_WITH.get(legs, []):
				placed_legs.append({"slot": "legs", "part": str(other[0]),
					"at": _ldraw(other[1])})
	found.append_array(placed_legs)
	# A skirt, a tail or a belt at the hips' joint, LDraw's convention for
	# hipwear, a cloth one as it is worn (worn_as). Cloth with no worn
	# drawing hangs down the back from the waist once it is known where
	# the ground is, below: nobody stands on it.
	var hipwear: String = worn_as(library, part("hipwear"))
	var hung_hipwear: bool = _is_flat(_info(library, hipwear))
	if not hipwear.is_empty() and not hung_hipwear:
		found.append({"slot": "hipwear", "part": hipwear, "at": _ldraw(HIPS)})

	# Where the figure ends: its legs' lowest point (or its hips', if they
	# reach lower, as they do over a pair of springs), the torso's when
	# it has neither, and how far forward its feet are.
	var ground: float = 72.0 if not _is_short_legs(legs) else 56.0
	var foot_z: float = -1.25 if not _is_short_legs(legs) else 0.0
	if library != null:
		var standing_on: Array[Dictionary] = placed_legs
		if standing_on.is_empty():
			standing_on = found.duplicate()
			standing_on.append({"part": torso_id, "at": Transform3D.IDENTITY})
		var reach: Array = _reach(library, standing_on)
		if not reach.is_empty():
			ground = reach[0]
			foot_z = reach[1]
			var hips: Array = _reach(library, found.filter(func(item: Dictionary) -> bool:
				return item["slot"] == "hips"))
			if not hips.is_empty():
				ground = maxf(ground, float(hips[0]))
			# Legs bent at an angle (43220 with the bent springs) stand a
			# cell up: a turned part's cover is rounded out to whole cells,
			# as a held spear's is.
			if standing_on.any(func(item: Dictionary) -> bool:
					return not BrickLattice.is_square_to_grid((item["at"] as Transform3D).basis)):
				ground += BrickLattice.CELL
	var footwear: String = part("footwear")
	if not footwear.is_empty():
		var info: PartLibrary.PartInfo = _info(library, footwear)
		# Every footwear part in the library is drawn with the stud a foot
		# goes on at its origin, the top it stands on at y 0 (a ski's
		# binding and a snowshoe's rim reach higher, round the foot): the
		# foot's sole on it, and under it whatever is under the origin.
		var under: float = 0.0
		var wide: bool = false
		if info != null:
			under = -info.bounds.position.y
			wide = info.bounds.size.x >= 30.0
		var feet: Array[float] = [-FOOT_APART, FOOT_APART]
		if wide:
			feet = [0.0]
		for x: float in feet:
			found.append({"slot": "footwear", "part": footwear,
				"at": Transform3D(Basis.IDENTITY, Vector3(x, ground, foot_z))})
		# Standing on what is under the sole, right on the ground: the
		# lattice keeps a cover off its cells inside the part
		# (BrickLattice.within), so a flipper 3 LDU thick no longer reads
		# as a cell into the plate it stands on.
		ground += under
	var stance := Transform3D(Basis.IDENTITY, Vector3(0, -ground, -foot_z))
	if not hipwear.is_empty() and hung_hipwear:
		# From the waist, at the back of the hips: tuxedo tails.
		found.append({"slot": "hipwear", "part": hipwear, "at": _hung_clear(library, hipwear,
			_hung_flat(_info(library, hipwear),
				_ldraw(HIPS).origin + Vector3(0, -11.0, SHOULDERS.z)), stance)})
	return {"parts": found, "stance": stance}


## The lowest point of some placed parts and the middle of where they
## reach front to back, in LDraw's axes: [ground, z], or [] if none of
## them is known.
static func _reach(library: PartLibrary, placed: Array) -> Array:
	var low: float = -INF
	var front: float = INF
	var back: float = -INF
	for item: Dictionary in placed:
		var info: PartLibrary.PartInfo = library.parts.get(str(item["part"]))
		if info == null:
			continue
		var at: Transform3D = item["at"]
		for n: int in 8:
			var corner: Vector3 = info.bounds.position + Vector3(
				info.bounds.size.x if n & 1 else 0.0, info.bounds.size.y if n & 2 else 0.0,
				info.bounds.size.z if n & 4 else 0.0)
			# The catalogue's boxes are in the app's axes.
			var here: Vector3 = at * (FLIP.basis * corner)
			low = maxf(low, here.y)
			front = minf(front, here.z)
			back = maxf(back, here.z)
	if low == -INF:
		return []
	return [low, (front + back) * 0.5]


## Where a part sits relative to the torso, on a side, by what the
## library's own assemblies do with it: with this torso, with any torso,
## or null for the standard joint.
static func _place(torso_id: String, part_id: String, side: String) -> Variant:
	var found: Variant = _place_on(torso_id, part_id, side)
	return found if found != null else _place_on("*", part_id, side)


## Where the library puts a part with this torso family alone.
static func _place_on(torso_id: String, part_id: String, side: String) -> Variant:
	if part_id.is_empty() or torso_id.is_empty():
		return null
	var key: String = _family(part_id)
	var by_part: Dictionary = MinifigData.PLACES.get(
		torso_id if torso_id == "*" else _family(torso_id), {})
	var by_side: Dictionary = by_part.get(key, by_part.get(part_id, {}))
	if by_side.has(side):
		return _ldraw(by_side[side])
	return null


## Where a head sits: its neck socket over the torso's neck post, the
## socket's opening on the shoulders (MinifigData.SEATS, measured off the
## head's geometry; 24 under the origin for the classic heads, so the
## standard HEAD). A head with no socket to find sits on its own
## lowest point.
static func _seated(library: PartLibrary, head: String) -> Transform3D:
	var standard: Transform3D = _ldraw(HEAD)
	if head.is_empty():
		return standard
	var family: String = _family(head)
	var seat: Variant = MinifigData.SEATS.get(family, MinifigData.SEATS.get(head))
	if seat == null:
		if family.begins_with("3626") or family == "28621":
			return standard
		var info: PartLibrary.PartInfo = _info(library, head)
		if info == null:
			return standard
		seat = -info.bounds.position.y
	var at: Transform3D = standard
	at.origin.y = standard.origin.y + 24.0 - float(seat)
	return at


## A headgear extra relative to the head. Where an assembly of the
## library puts it on the helmet it is worn with, if it is; a visor
## turns where its helmet takes one (MinifigData.PIVOTS, measured off
## both parts' pins and dimples), and one drawn about its own pivot on a
## helmet that does not say goes where the classic helmet takes it
## (3842a/b, y 5: the helmet most visors are for); anything else at the
## head's own origin, LDraw's convention for a part drawn in place.
static func _on_headgear(part_id: String, hat: String = "") -> Transform3D:
	if part_id.is_empty():
		return Transform3D.IDENTITY
	var found: Array = MinifigData.EXTRAS.get(_family(part_id), MinifigData.EXTRAS.get(part_id, []))
	if found.size() == 13 and (hat.is_empty() or _family(hat) == _family(str(found[0]))):
		return _ldraw(found.slice(1))
	var own: Array = MinifigData.PIVOTS.get(_family(part_id), [])
	if own.size() != 2:
		return _ldraw(found.slice(1)) if found.size() == 13 else Transform3D.IDENTITY
	var on_hat: Array = MinifigData.PIVOTS.get(_family(hat), []) if not hat.is_empty() else []
	var at_origin: bool = absf(float(own[0])) < 0.5 and absf(float(own[1])) < 0.5
	if on_hat.size() != 2:
		if not at_origin:
			return Transform3D.IDENTITY
		on_hat = MinifigData.PIVOTS.get("3842b", [5.0, 0.0])
	return Transform3D(Basis.IDENTITY, Vector3(0.0, float(on_hat[0]) - float(own[0]),
		float(on_hat[1]) - float(own[1])))


## Something round the neck or on the back: at the torso's origin, the
## LDraw convention and where 85 of 87 real figures put theirs, turned
## the way real figures wear it where they turn it (the quiver).
static func _worn(part_id: String) -> Transform3D:
	var turn: float = float(MinifigData.TURNED.get(part_id, 0))
	if turn == 0.0:
		return Transform3D.IDENTITY
	return Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), Vector3.ZERO)


## A cape, from the shoulders. One moulded or formed to hang sits at the
## torso's origin, as real figures wear 4524 and 99464c01; a cloth one
## LDraw draws flat and has no worn drawing of (worn_as) hangs straight
## down against the back from the top of the torso (_hung_flat). Either,
## if it is longer than the figure is tall — a full cape on a child — is
## raised until it clears the ground, not swung out behind: a cape held
## out at an angle reads as something broken, not as cloth.
func _cape(library: PartLibrary, part_id: String, stance: Transform3D) -> Transform3D:
	var info: PartLibrary.PartInfo = _info(library, part_id)
	if info == null:
		return Transform3D.IDENTITY
	if _is_flat(info):
		return _hung_clear(library, part_id, _hung_flat(info, SHOULDERS), stance)
	# Sitting on the shoulders by its own collar, as the head sits on it:
	# 4524 two LDU up in all nine real figures wearing it, as 50231c02 is
	# in 9471's Eomer.
	var collar: float = float(MinifigData.NECK_LIFT.get(part_id, 0))
	return _hung_clear(library, part_id,
		Transform3D(Basis.IDENTITY, Vector3(0.0, -collar, 0.0)), stance)


## LDraw draws cloth twice: flat, as it is sold (50231 "Cape Cloth"), and
## as it is worn (50231c01 "Cape Cloth (Formed)"). Real sets' files dress
## their figures in the worn drawing — every cloth cape on a figure in the
## 105 sets of vendor/omr is one (522, 50231c02, 99464c01), and none is
## flat. So a flat cloth on a figure is drawn as the library's first worn
## drawing of it, where it has one and it is to hand; the part chosen
## otherwise. The parts list counts it as the element it is
## (PartLibrary.element_for).
static func worn_as(library: PartLibrary, part_id: String) -> String:
	var info: PartLibrary.PartInfo = _info(library, part_id)
	if info == null or not _is_flat(info):
		return part_id
	var formed: PartLibrary.PartInfo = library.parts.get(part_id + "c01")
	if formed != null and formed.name.contains("(Formed") and _real(formed) \
			and _worn_by_a_figure(formed):
		return formed.id
	return part_id


## Cloth as LDraw draws it to be sold: a sheet less than a cell thick.
static func _is_flat(info: PartLibrary.PartInfo) -> bool:
	return info != null and info.bounds.size.y < 2.0


## Whether a worn drawing of cloth is one a figure wears: hanging down
## no lower than a classic figure's feet (70 LDU under the shoulders, a
## cell clear) and no further out in front than behind. Not every one
## is: 50231c03 is the cape hung as a curtain, 106700c01 a robe 13 studs
## long, and u9661c01 is drawn folded the way the flat sheet lies, out
## in front of whoever wore it.
static func _worn_by_a_figure(info: PartLibrary.PartInfo) -> bool:
	# The catalogue's box is in the app's axes: -y is down, +z in front.
	return -info.bounds.position.y <= 70.0 \
		and info.bounds.end.z <= -info.bounds.position.z + 2.0


## The flat drawing a worn one is of, 50231c01 -> 50231, by LDraw's
## numbering of them; "" for a part that is not a worn drawing of cloth.
static func flat_of(info: PartLibrary.PartInfo) -> String:
	if info == null or not info.name.contains("(Formed"):
		return ""
	if not _patterns.has("formed"):
		var expression := RegEx.new()
		expression.compile("^(.+)c\\d\\d$")
		_patterns["formed"] = expression
	var found: RegExMatch = (_patterns["formed"] as RegEx).search(info.id)
	return found.get_string(1) if found != null else ""


## A sheet hung down the back, raised until its hem is a cell of the
## lattice above the ground — the lattice's whole cells, so its origin
## stays on them. Hung square to the grid, its cover is its own box.
static func _hung_clear(library: PartLibrary, part_id: String, at: Transform3D,
		stance: Transform3D) -> Transform3D:
	if library == null:
		return at
	var reach: Array = _reach(library, [{"part": part_id, "at": at}])
	if reach.is_empty():
		return at
	var over: float = float(reach[0]) - (-stance.origin.y - BrickLattice.CELL)
	if over > 0.0:
		at.origin.y -= ceilf(over / BrickLattice.CELL - 0.001) * BrickLattice.CELL
	return at


## Something hanging from the shoulders on the back — a backpack hanging
## open — swung back about them, 5 degrees at a time, until it ends a
## cell of the lattice above the ground the figure stands on.
static func _clear_of_ground(library: PartLibrary, part_id: String, at: Transform3D,
		stance: Transform3D) -> Transform3D:
	if library == null:
		return at
	# Two cells clear once swung: a turned part's cover is rounded out to
	# whole cells all round.
	var ground: float = -stance.origin.y - BrickLattice.CELL
	for step: int in 19:
		if step == 1:
			ground -= BrickLattice.CELL
		var swung := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(5.0 * step)), Vector3.ZERO)
		var tried: Transform3D = Transform3D(Basis.IDENTITY, SHOULDERS) * swung \
			* Transform3D(Basis.IDENTITY, -SHOULDERS) * at
		var reach: Array = _reach(library, [{"part": part_id, "at": tried}])
		if reach.is_empty() or float(reach[0]) <= ground:
			return tried
	return at


## A sheet of cloth LDraw draws flat, as it is sold — in X-Z, with the
## hole it hangs by at its origin — hung straight down from a point: a
## quarter turn about X takes its long side down. One the same length
## both sides of its hole (a tabard) hangs with as much above the point
## as a cape has, 13 LDU.
static func _hung_flat(info: PartLibrary.PartInfo, from: Vector3) -> Transform3D:
	# The catalogue's box is in the app's axes: its -Z is LDraw's +Z.
	var front: float = -(info.bounds.position.z + info.bounds.size.z)
	var back: float = -info.bounds.position.z
	var down: bool = absf(front) >= absf(back)
	var turn := Basis(Vector3.RIGHT, deg_to_rad(90.0 if down else -90.0))
	var above: float = back if down else -front
	var lift: float = maxf(0.0, above - 13.5) if absf(front + back) < 10.0 else 0.0
	return Transform3D(turn, from + Vector3(0, lift, 0))


## The arm part on each side: {r, l}. A sided arm and its pair, the
## same moulding both sides where it has no side or the library uses it
## on both, the plain arm opposite one that has no pair.
func _arm_parts(library: PartLibrary) -> Dictionary:
	return _pair(library, part("arms"), ARM_RIGHT, ARM_LEFT)


func _leg_parts(library: PartLibrary) -> Dictionary:
	return _pair(library, part("legs"), PLAIN_LEGS, PLAIN_LEFT_LEG)


func _pair(library: PartLibrary, chosen: String, right: String, left: String) -> Dictionary:
	if chosen.is_empty():
		return {"r": "", "l": ""}
	var side: String = _side(library, chosen)
	var torso_id: String = part("torso")
	if side == "c" or _place(torso_id, chosen, "r") != null and _place(torso_id, chosen, "l") != null:
		return {"r": chosen, "l": chosen}
	var other: String = partner(library, chosen)
	if side == "r":
		return {"r": chosen, "l": other if not other.is_empty() else left}
	return {"r": other if not other.is_empty() else right, "l": chosen}


## The hand part on each side. The plain hand both sides; a sided one
## (a boxing glove) and its pair; a hand with no side — a hook, a
## harpoon — where the library puts it, and on the left where it says
## nothing, the right keeping a hand to hold things with.
func _hand_parts(library: PartLibrary) -> Dictionary:
	var chosen: String = part("hands")
	if chosen.is_empty() or chosen == HAND:
		return {"r": chosen, "l": chosen}
	var side: String = _side(library, chosen)
	if side != "c":
		return _pair(library, chosen, HAND, HAND)
	# On the side of the arm it goes on, where it goes on one.
	var needs: Array = MinifigData.ON_ARMS.get(_family(chosen), [])
	if not needs.is_empty():
		return {"r": chosen, "l": HAND} if _side(library, str(needs[0])) == "r" \
			else {"r": HAND, "l": chosen}
	var on_right: bool = _place("", chosen, "r") != null
	var on_left: bool = _place("", chosen, "l") != null
	if on_right and on_left:
		return {"r": chosen, "l": chosen}
	if on_right:
		return {"r": chosen, "l": HAND}
	return {"r": HAND, "l": chosen}


func _arm_at(torso_id: String, arm: String, side: String) -> Transform3D:
	var at: Variant = _place(torso_id, arm, side)
	if at != null:
		return at
	return _ldraw(ARM_R if side == "r" else ARM_L)


static func _standard_hand_in_arm(side: String) -> Transform3D:
	if side == "r":
		return _ldraw(ARM_R).affine_inverse() * _ldraw(HAND_R)
	return _ldraw(ARM_L).affine_inverse() * _ldraw(HAND_L)


## Where a hand sits, with its arm hanging, relative to the torso; null
## for an arm with no hand to take (a wing, a clip, a hand moulded on).
static func _hand_at(torso_id: String, arm: String, arm_at: Transform3D, hand: String,
		side: String) -> Variant:
	# A hand that goes on an arm of its own, on it where the arm says.
	var needs: Array = MinifigData.ON_ARMS.get(_family(hand), [])
	if needs.size() == 13 and _family(arm) == _family(str(needs[0])):
		return arm_at * _ldraw(needs.slice(1))
	var on_arm: Variant = MinifigData.HANDS.get(_family(arm))
	if on_arm is Dictionary and (on_arm as Dictionary).is_empty():
		return null
	if on_arm == null and _hand_moulded_on(arm):
		return null
	if hand.is_empty():
		return arm_at * _standard_hand_in_arm(side)
	# What the library does with this hand and this torso (a baby's).
	var with_torso: Dictionary = MinifigData.PLACES.get(_family(torso_id), {})
	var exact: Dictionary = with_torso.get(_family(hand), {})
	if exact.has(side):
		return _ldraw(exact[side])
	if on_arm is Dictionary and (on_arm as Dictionary).has(side):
		return arm_at * _ldraw(on_arm[side])
	# A hand of its own shape (a hook) where the library puts it on the
	# plain arm, carried by whatever arm it is on.
	var anywhere: Dictionary = (MinifigData.PLACES.get("*", {}) as Dictionary).get(_family(hand), {})
	if anywhere.has(side):
		var plain: Transform3D = _ldraw(ARM_R if side == "r" else ARM_L)
		return arm_at * plain.affine_inverse() * _ldraw(anywhere[side])
	return arm_at * _standard_hand_in_arm(side)


## Whether an arm has a socket for a hand where the standard joint puts
## one, by the two parts' own connectors: the hand's peg in a bore of the
## arm that fits it ([method Joints.rounds]). Asked only of a hand at the
## standard joint, which no table of the library's says is right for this
## arm: a Barraki's arm ends in a claw of its own, Dug's arm is what he
## walks on and a mutant dog's is a leg, and a plain hand hung on any of
## them was held by nothing. Where a part is not to hand, it is put on.
static func _has_socket(library: PartLibrary, arm: String, arm_at: Transform3D,
		hand: String, hand_at: Transform3D) -> bool:
	if library == null:
		return true
	var side: String = "r" if arm_at.origin.x < 0.0 else "l"
	if not (arm_at * _standard_hand_in_arm(side)).is_equal_approx(hand_at):
		return true
	var arm_mesh: Lbm.PartMesh = library.mesh_for(arm)
	var hand_mesh: Lbm.PartMesh = library.mesh_for(hand)
	if arm_mesh == null or hand_mesh == null:
		return true
	var entries: Array = [[0, FLIP * arm_at * FLIP, arm_mesh], [1, FLIP * hand_at * FLIP, hand_mesh]]
	return Joints.rounds(entries).has(1) or Joints.both_ways(entries).has(1)


## An arm with its hand moulded on, or a clip where a hand would be, by
## LDraw's name for it, where the library has no assembly to say: "Arm
## Long Curved with Hand", "Mechanical Arm Straight with Clips".
static func _hand_moulded_on(arm: String) -> bool:
	if not _slot_of.has(arm) or _family(arm) in [ARM_RIGHT, ARM_LEFT, "16000", "16001"]:
		return false
	return _matches(_by_id_name(arm), "\\b(with (Integral |Fixed )?Hand|Clips?|Shoulder)\\b")


static var _names: Dictionary = {}

static func _by_id_name(part_id: String) -> String:
	return str(_names.get(part_id, ""))


## An arm, its hand, and what is in the hand relative to that hand, all
## relative to the torso in LDraw's axes: [arm, hand, held].
##
## With the arm hanging, as every figure here stands, the hand's grip
## points down and back, so a short thing — a sword, a torch — is held
## blade up and forward and a long one goes through the floor. Real
## figures hold a long one with the forearm level: 3818.dat's "-45 =
## lower arm horizontal", which is the raised arm of 34 real figures in
## the model repository (6059's, 6062's and 6073's castle soldiers among
## them), and a shaft along the grip slid through the hand until its end
## is on the ground, as 6059's spear is. So that is what happens to
## anything as long as a figure is tall, and to anything else that would
## reach below the figure's feet. Either hand: the left is the same
## moulding, so it closes on the same grip.
func _held(held: String, arm: Transform3D, hand: Transform3D, stance: Transform3D,
		library: PartLibrary) -> Array:
	if held.is_empty():
		return [arm, hand, Transform3D.IDENTITY]
	var grip: Transform3D = in_hand(held)
	var info: PartLibrary.PartInfo = library.parts.get(held) if library != null else null
	if info == null:
		return [arm, hand, grip]
	var size: Vector3 = info.bounds.size
	var long: bool = maxf(size.x, maxf(size.y, size.z)) >= LONG
	if not long and _lowest(stance * hand * grip, info.bounds) >= 0.0:
		return [arm, hand, grip]
	var raised: Transform3D = arm * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-45.0)),
		Vector3.ZERO)
	hand = raised * arm.affine_inverse() * hand
	var low: float = _lowest(stance * hand * grip, info.bounds)
	# Upright: as long along its grip as a figure is tall — a spear, not
	# a lance, which is long across it.
	var bar: Array = MinifigData.GRIPS.get(held, [0.0, 0.0, 0.0, 0.0, 1.0, 0.0])
	var upright: bool = _extent(info.bounds, FLIP.basis * Vector3(bar[3], bar[4], bar[5])) >= LONG
	if low < 0.0 or upright:
		# Slid along the grip, as a shaft slides through a closed hand,
		# until its lowest point is on the ground under the figure — a
		# cell of the lattice above it, since a turned part's cover is
		# rounded out to whole cells and would otherwise reach into
		# whatever the figure stands on.
		var along: float = (FLIP.basis * (stance * hand).basis * GRIP_AXIS).y
		if absf(along) > 0.05:
			var slide: float = (BrickLattice.CELL - low) / along
			# Stood on the ground, no further than the bar the hand is on:
			# a spear's shaft goes through it to the ground, and a
			# greatsword's hilt stops at the guard and the pommel. Slid
			# on, the hand closed on the flat of the blade, which nothing
			# holds. Out of the floor, as far as that takes.
			if bar.size() >= 8 and low >= 0.0:
				slide = clampf(slide, -float(bar[7]), -float(bar[6]))
			grip.origin += GRIP_AXIS * slide
	return [raised, hand, grip]


## How long a thing has to be to be held like a spear: about a figure's
## height. A sword (80 LDU) hangs, a spear (146) stands.
const LONG := 100.0


## How far a box reaches along a direction.
static func _extent(bounds: AABB, direction: Vector3) -> float:
	var lo: float = INF
	var hi: float = -INF
	for n: int in 8:
		var corner: Vector3 = bounds.position + Vector3(
			bounds.size.x if n & 1 else 0.0, bounds.size.y if n & 2 else 0.0,
			bounds.size.z if n & 4 else 0.0)
		var along: float = corner.dot(direction.normalized())
		lo = minf(lo, along)
		hi = maxf(hi, along)
	return hi - lo


## The lowest point of a part's box, in the app's axes, placed by a
## transform in LDraw's.
static func _lowest(placed: Transform3D, bounds: AABB) -> float:
	var at: Transform3D = FLIP * placed * FLIP
	var low: float = INF
	for n: int in 8:
		var corner: Vector3 = bounds.position + Vector3(
			bounds.size.x if n & 1 else 0.0, bounds.size.y if n & 2 else 0.0,
			bounds.size.z if n & 4 else 0.0)
		low = minf(low, (at * corner).y)
	return low


## Where an accessory sits in the hand that holds it, in LDraw's axes:
## its bar laid along the hand's grip, through the middle of the grip.
## The turn is the least that lines the two up, so a part drawn the
## LDraw way — handle along Y, business end up — comes out as real sets
## hold it, blade forward and up.
static func in_hand(part_id: String) -> Transform3D:
	var grip: Array = MinifigData.GRIPS.get(part_id, [0.0, 0.0, 0.0, 0.0, 1.0, 0.0])
	var bar := Vector3(grip[0], grip[1], grip[2])
	var along := Vector3(grip[3], grip[4], grip[5]).normalized()
	var turn := Basis.IDENTITY
	var axis: Vector3 = along.cross(GRIP_AXIS)
	if axis.length() > 1e-6:
		turn = Basis(axis.normalized(), atan2(axis.length(), along.dot(GRIP_AXIS)))
	elif along.dot(GRIP_AXIS) < 0.0:
		turn = Basis(Vector3.RIGHT, PI)
	return Transform3D(turn, GRIP - turn * bar)


## The torso's placement in the figure's frame, in the app's axes: what
## a figure's frame is found from once it is in a model.
func torso_local(library: PartLibrary = null) -> Transform3D:
	var made: Dictionary = _made_here()
	if not made.is_empty():
		return _stand_in(made).torso_local(library)
	return FLIP * (_lower(library)["stance"] as Transform3D) * FLIP


# -- parts made in the app ------------------------------------------------------
#
# A print drawn in the print designer is the plain part with a picture on
# it, and a mould is a part sculpted from another with its connections
# where they were: each stands, joins and is held exactly as the part it
# was made from. PartPrints.bases says which that is.


## The slots holding a part made here: slot -> its id.
func _made_here() -> Dictionary:
	var out: Dictionary = {}
	for slot: String in parts:
		var id: String = str(parts[slot])
		if PartPrints.bases.has(id):
			out[slot] = id
	return out


## This figure with the parts they were made from in place of the parts
## made here.
func _stand_in(made: Dictionary) -> Minifig:
	var other: Minifig = copy()
	for slot: String in made:
		other.parts[slot] = PartPrints.base_of(made[slot])
	return other


## A figure put together from the parts made here's originals, with the
## parts made here put back: each where its original is, and the other
## side of a pair made together (a printed pair of legs) where its plain
## other side is.
func _swapped_back(placed: Array[Dictionary], made: Dictionary,
		library: PartLibrary) -> Array[Dictionary]:
	for item: Dictionary in placed:
		var slot: String = item["slot"]
		if not made.has(slot):
			continue
		var id: String = made[slot]
		if str(item["part"]) == PartPrints.base_of(id):
			item["part"] = id
			continue
		var other: String = made_with(library, id, str(item["part"]))
		if not other.is_empty():
			item["part"] = other
	return placed


## The tag that tells one print or mould from another: the end of its id.
static func _tag(id: String) -> String:
	return id.get_slice("-", id.get_slice_count("-") - 1)


## The part made together with [param id] from [param original]: the left
## leg of a printed pair whose right leg is [param id], its hips. "" when
## none was.
static func made_with(library: PartLibrary, id: String, original: String) -> String:
	var tag: String = id.get_slice("-", id.get_slice_count("-") - 1)
	for other: String in PartPrints.bases:
		if other != id and str(PartPrints.bases[other]) == original \
				and other.ends_with("-" + tag) \
				and (library == null or library.parts.has(other)):
			return other
	return ""


## Whether the legs are hips and legs in a single moulding (and so the
## hips slot has nothing to hold).
func is_short() -> bool:
	return _is_short_legs(part("legs"))


func legs_take_hips(library: PartLibrary) -> bool:
	return not _one_piece(library, part("legs"))


static func is_short_legs(part_id: String) -> bool:
	return _is_short_legs(part_id)


static func _is_short_legs(part_id: String) -> bool:
	return part_id.begins_with("41879") or part_id.begins_with("16709")


## Hips and legs in one moulding, which take no hips of their own:
## short legs, skirts moulded on, mermaid tails, droid legs. Told by
## their geometry, which reaches up to the hips' top (11 LDU above their
## joint; separate legs reach 8.75), or by LDraw's name for them.
static func _one_piece(library: PartLibrary, part_id: String) -> bool:
	if part_id.is_empty():
		return false
	var info: PartLibrary.PartInfo = _info(library, part_id)
	if info == null:
		return _is_short_legs(part_id)
	if _matches(_short_name(info.name), "^(Hips|Lower Body|Centaur Body)\\b"):
		return true
	return info.bounds.position.y + info.bounds.size.y >= 10.5


## Legs drawn from their feet up (a battle droid's, a Martian's), which
## the library puts only on their own bodies: on anybody else's, hung
## from where the hips' top is (21 LDU under the torso's top, 11 over
## the hips' joint) rather than up inside the torso.
static func _hung(library: PartLibrary, part_id: String, standard: Transform3D) -> Transform3D:
	var info: PartLibrary.PartInfo = _info(library, part_id)
	if info == null:
		return standard
	var top: float = -(info.bounds.position.y + info.bounds.size.y)
	if top >= -11.5:
		return standard
	var hung: Transform3D = standard
	hung.origin.y = _ldraw(HIPS).origin.y - 11.0 - top
	return hung


## A leg narrower than a pair of legs, worn one each side.
static func _narrow(library: PartLibrary, part_id: String) -> bool:
	var info: PartLibrary.PartInfo = _info(library, part_id)
	return info != null and info.bounds.size.x < 26.0


## The left leg that goes with the right one: 3816c with 3817c, and a
## printed pair by its print, 3816cp01 with 3817cp01.
func left_leg(library: PartLibrary = null) -> String:
	if library != null:
		return str(_leg_parts(library)["l"])
	var right: String = str(parts.get("legs", PLAIN_LEGS))
	if right.begins_with("3816"):
		return "3817" + right.substr(4)
	return right


## Every part id the figure needs, for fetching what is not to hand.
## Without a library, the one the slots were last sorted from: a figure
## off the builder is fetched with the pairs it will really be put
## together with (20461bp00's left leg is 20460bp00, not 3817c).
func part_ids(library: PartLibrary = null) -> PackedStringArray:
	if library == null and _indexed != null:
		library = _indexed.get_ref() as PartLibrary
	var out := PackedStringArray()
	for placed: Dictionary in assemble(library):
		if not out.has(str(placed["part"])):
			out.append(str(placed["part"]))
	return out


## A placement as an LDraw line writes it, still in LDraw's axes.
static func _ldraw(v: Array) -> Transform3D:
	return Transform3D(
		Basis(Vector3(v[3], v[6], v[9]), Vector3(v[4], v[7], v[10]),
			Vector3(v[5], v[8], v[11])),
		Vector3(v[0], v[1], v[2]))


static func _info(library: PartLibrary, part_id: String) -> PartLibrary.PartInfo:
	if library == null or part_id.is_empty():
		return null
	return library.parts.get(part_id)


# -- reading a figure back off a model ---------------------------------------


## Which part of a figure a part is: a slot name, or "" for a part that
## is not one. The slot it would be offered in, so whatever the builder
## can put on a figure is known as part of one when read back. Without
## the library's index, by the part numbers of the standard mouldings.
static func role_of(part_id: String, info: PartLibrary.PartInfo = null) -> String:
	if info != null:
		var slot: String = slot_for(info)
		if not slot.is_empty():
			return "accessory" if slot == "accessory_left" else slot
	if _slot_of.has(part_id):
		return _slot_of[part_id]
	# And the mouldings real sets' files still use under their old
	# numbers (3815, 3816, 3817), which are not offered.
	if _matches(part_id, "^973(p\\w+)?$"):
		return "torso"
	if part_id.begins_with("3626") or part_id.begins_with("28621"):
		return "head"
	if part_id.begins_with(ARM_RIGHT) or part_id.begins_with(ARM_LEFT):
		return "arms"
	if part_id == HAND:
		return "hands"
	if part_id.begins_with("3815"):
		return "hips"
	if part_id.begins_with("3816") or part_id.begins_with("3817") \
			or is_short_legs(part_id):
		return "legs"
	return ""


## The figure's frame in the world, from its parts: [{part, at}] or
## Bricks. Null when there is no torso to read it from.
##
## Found from the torso, which every figure has exactly one of, and
## what it stands on — legs and footwear — which say how far below it
## the studs are, worked out the way the figure was assembled.
static func frame_of(placed: Array, library: PartLibrary = null) -> Variant:
	if library != null:
		_index(library)
	var torso: Variant = null
	var shape := Minifig.new()
	shape.parts["hips"] = ""
	shape.parts["legs"] = ""
	var legs: Array[String] = []
	for item: Variant in placed:
		var part_id: String = _part_of(item)
		match role_of(part_id):
			"torso":
				torso = _at_of(item)
				shape.parts["torso"] = part_id
			"legs":
				legs.append(part_id)
			"hips":
				shape.parts["hips"] = part_id
			"footwear":
				shape.parts["footwear"] = part_id
	if torso == null:
		return null
	# The leg the figure was described by: a one-piece pair, or the right
	# leg of a pair (its left is found from it again).
	for leg: String in legs:
		if library == null or _side(library, leg) != "l":
			shape.parts["legs"] = leg
			break
	if (shape.parts["legs"] as String).is_empty() and not legs.is_empty():
		shape.parts["legs"] = legs[0]
	return (torso as Transform3D) * shape.torso_local(library).affine_inverse()


## Whether some parts are a figure: a torso and a head among them, or a
## torso moulded with its own head and legs (Gollum, a bundled baby).
static func is_figure(placed: Array, library: PartLibrary = null) -> bool:
	if library != null:
		_index(library)
	var roles: Dictionary = {}
	var torso: String = ""
	for item: Variant in placed:
		var part_id: String = _part_of(item)
		var role: String = role_of(part_id)
		roles[role] = true
		if role == "torso":
			torso = part_id
	if not roles.has("torso"):
		return false
	return roles.has("head") or (library != null and placed.size() >= 1
		and _whole_body(library, torso))


static func _part_of(item: Variant) -> String:
	if item is BrickWorld.Brick:
		return (item as BrickWorld.Brick).part_id
	return str((item as Dictionary).get("part", ""))


static func _at_of(item: Variant) -> Transform3D:
	if item is BrickWorld.Brick:
		return (item as BrickWorld.Brick).transform
	return (item as Dictionary).get("at", Transform3D.IDENTITY)


## A part that is a figure's body or what it wears, which a set's own
## parts list does not count. Rebrickable keeps those in each figure's
## inventory and out of the set's: over its downloaded inventories,
## 12,423 heads are in figure inventories and 2,851 in sets', 14,278
## torsos and 1,111, and not one sword, shield, bow or pickaxe is in a
## figure's. So what a figure holds is a set part and the rest is not,
## and a model's variety is measured the same way.
static func is_body_part(info: PartLibrary.PartInfo) -> bool:
	if info == null:
		return false
	var slot: String = slot_for(info)
	return not slot.is_empty() and not HELD.has(slot)


# -- which slot a part fills -------------------------------------------------
#
# The catalogue's own category first, where LDraw has one for the slot —
# headwear, neckwear, hipwear, footwear, accessories — and LDraw's names
# for the rest, which it files under plain "Minifig": every head, torso,
# arm, hand, hip and leg, of every mould. tools/minifig.py has the same
# rule, to know which parts to work its tables out for.

## What fixes onto headgear rather than a head: visors, plumes, feathers.
const HAT_EXTRA_NAMES := "^(Helmet Visor|Visor|Plume|Feathers|Helmet Ornament|Crown Tiara|Cap Aviator Goggles|Hair Decoration|Helmet Floodlight|Carrot Nose)\\b"
## What is worn on the back rather than round the neck.
const BACK_NAMES := "^(Airtanks|Jet-Pack|Jetpack|Backpack|Arrow Quiver|Scuba Tank|Wings|Eagle Wing|Bat Wing|Container D-Basket|Sack|Scabbard|Neck Bracket|Bracket|Breathing Apparatus|Fire Helmet Breathing Hose|Ninja Turtle Shell)\\b"
## LDraw's names for the body, in the order they are tried: "Mechanical
## Head and Torso" is a torso, "Hips and Legs" are legs.
const NAME_RULES: Array = [
	["hat_extra", "^Helmet Visor\\b"],
	["torso", "^Mechanical Head and Torso\\b"],
	["head", "^(Head|Baby Head|Martian Head|Mechanical Head)\\b"],
	["headwear", "^(Hat|Helmet|Hair|Cap|Headdress|Crown|Mask|Hood)\\b"],
	["arms", "^(Arm|Mechanical Arm|Skeleton Arm|Mechanical Shoulder|Body Dug Arm)\\b"],
	["hands", "^(Hand|Boxing Glove)\\b"],
	["legs", "^(Leg|Legs|Robot Leg|Mechanical Leg|Mechanical Legs|Skeleton Leg|Martian Legs|Hips and Legs|Hips and Skirt|Lower Body|Centaur Body|Hips Mermaid|Hips Ghost|Hips Genie|Hips Snake|Hips with Tentacles)\\b"],
	["hips", "^Hips\\b"],
	["neck", "^(Armour|Breastplate)\\b"],
	["torso", "^(Torso|Mechanical Torso|Mechanical Cuboid Torso|Skeleton Torso|Body|Baby Body|Bundled Baby|Gollum|Figure Sebulba|Mutant Fish)\\b"],
]


## Which slot a part is offered in, or "" for a part that is not a
## minifigure's: anything in a "Minifig" category or named "Minifig ...".
## The left hand is offered what the right is.
static func slot_for(info: PartLibrary.PartInfo) -> String:
	if info == null:
		return ""
	var full: String = _plain(info.name)
	if not (info.category.begins_with("Minifig") or full.begins_with("Minifig ")
			or full.begins_with("Keychain Minifig ")):
		return ""
	var short: String = _short_name(full)
	match info.category:
		"Minifig Headwear":
			return "hat_extra" if _matches(short, HAT_EXTRA_NAMES) else "headwear"
		"Minifig Neckwear":
			if _matches(short, "^Cape\\b"):
				return "cape"
			return "back" if _matches(short, BACK_NAMES) else "neck"
		"Minifig Hipwear":
			return "hipwear"
		"Minifig Footwear":
			return "footwear"
		"Minifig Accessory":
			return "accessory"
		"Sheet Fabric":
			return "hipwear" if _matches(short, "^(Skirt|Tuxedo Tails)\\b") else "cape"
	for rule: Array in NAME_RULES:
		if _matches(short, str(rule[1])):
			return str(rule[0])
	return "accessory"


static func _plain(text: String) -> String:
	var out: String = text.strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out


## A part's name without what every minifigure part's name says.
static func _short_name(text: String) -> String:
	return _plain(text).trim_prefix("Keychain ").trim_prefix("Minifig ")


## A printed part's plain mould: 3816cp0b -> 3816c, 973pbn -> 973. The
## same as tools/minifig.py family().
static func _family(part_id: String) -> String:
	if not _patterns.has("family"):
		var expression := RegEx.new()
		expression.compile("^([a-z]?\\d+[a-z]?(?:-f\\d)?)(p[0-9a-z]+)?$")
		_patterns["family"] = expression
	var found: RegExMatch = (_patterns["family"] as RegEx).search(part_id)
	return found.get_string(1) if found != null else part_id


## Which side a part is for: "r" for a right arm or leg, "l" for a left,
## "c" for one that is the same both sides. Its geometry first — a
## right leg is modelled off to -X of its origin, whatever its name says
## (3817cp8i is a left leg LDraw calls right) — and its name for parts
## that are symmetric to look at (a boxing glove).
static func _side(library: PartLibrary, part_id: String) -> String:
	var info: PartLibrary.PartInfo = _info(library, part_id)
	if info == null:
		if part_id.begins_with("3818") or part_id.begins_with("3816"):
			return "r"
		if part_id.begins_with("3819") or part_id.begins_with("3817"):
			return "l"
		return "c"
	return side_of(info)


static func side_of(info: PartLibrary.PartInfo) -> String:
	var centre: float = info.bounds.position.x + info.bounds.size.x * 0.5
	if centre < -1.0:
		return "r"
	if centre > 1.0:
		return "l"
	var full: String = _plain(info.name)
	if _matches(full, "\\bRight\\b"):
		return "r"
	if _matches(full, "\\bLeft\\b"):
		return "l"
	return "c"


# -- what each slot can be -------------------------------------------------


static var _index_of: int = 0
static var _indexed: WeakRef = null
static var _slot_of: Dictionary = {}       ## part id -> slot, every real minifig part
static var _by_name: Dictionary = {}       ## plain name -> part id
static var _choices: Dictionary = {}       ## slot -> Array[PartInfo]
static var _partners: Dictionary = {}      ## part id -> the other side's part id
static var _family_pairs: Dictionary = {}  ## right family -> left family and back
static var _paired: Dictionary = {}        ## part id -> true, offered as another's pair
static var _index_made: int = -1           ## how many made parts the library had


## Sort every real minifigure part of a library into its slot, once.
## [param sorted] is [method _sort_into]'s, when it has been done already.
static func _index(library: PartLibrary, sorted: Array = []) -> void:
	# Again when parts have been made since: a print drawn a moment ago is
	# offered in its slot.
	if library == null or _indexed_for(library):
		return
	var found: Array = sorted
	if found.is_empty():
		found = []
		_sort_into(found, library, null)
	_index_made = library.custom.size()
	_slot_of.clear()
	_by_name.clear()
	_names.clear()
	_choices.clear()
	_partners.clear()
	_family_pairs.clear()
	_paired.clear()
	_slot_of.merge(found[0])
	_by_name.merge(found[1])
	_names.merge(found[2])
	_index_of = library.get_instance_id()
	_indexed = weakref(library)
	# The pairs, by name — "Minifig Leg Right with ..." and "Minifig Leg
	# Left with ..." — and by mould, which pairs the prints whose two
	# halves LDraw names differently (3816cp30 "Rags", 3817cp30 "Rags and
	# Patch") by the print number they share.
	for id: String in _slot_of:
		if not (_slot_of[id] in ["arms", "legs", "hands"]):
			continue
		var other: String = _named_pair(library, id)
		if not other.is_empty():
			_family_pairs[_family(id)] = _family(other)
	for id: String in _slot_of:
		if not (_slot_of[id] in ["arms", "legs", "hands"]):
			continue
		var info: PartLibrary.PartInfo = library.parts[id]
		if side_of(info) != "r":
			continue
		var other: String = partner(library, id)
		if not other.is_empty():
			_paired[other] = true


static func _indexed_for(library: PartLibrary) -> bool:
	return _index_of == library.get_instance_id() and _index_made == library.custom.size()


## The library's figure parts by slot, by plain name and by short name, into
## [param sorted]; a slice at a time with a [param pace]. Every part of the
## library is looked at: in one go it was most of the 200 ms the first figure
## asked about cost on the desktop, and the first was asked inside the
## Timeline's sub-assembly search on Orthanc, or by the autosave after
## Brickify (2026-10-15).
static func _sort_into(sorted: Array, library: PartLibrary, pace: FramePace) -> void:
	var slot_of: Dictionary = {}
	var by_name: Dictionary = {}
	var names: Dictionary = {}
	# The names first: the library may gain a part while this waits.
	for id: String in library.parts.keys():
		if pace != null and pace.due():
			await pace.next()
		var info: PartLibrary.PartInfo = library.parts.get(id)
		if info == null:
			continue
		if not _real(info):
			continue
		var slot: String = slot_for(info)
		if slot.is_empty():
			continue
		slot_of[id] = slot
		by_name[_plain(info.name)] = id
		names[id] = _short_name(info.name)
	sorted.assign([slot_of, by_name, names])


## [method _index] over frames, its long part a slice at a time: the app
## warms it a moment after it starts (Main._ready), and the Timeline waits on
## it before asking which sub-models are figures.
static func index_paced(library: PartLibrary) -> void:
	if library == null or _indexed_for(library):
		return
	var made: int = library.custom.size()
	var sorted: Array = []
	await _sort_into(sorted, library, FramePace.new())
	# A part made meanwhile is not in it: sorted again, at once.
	if library.custom.size() != made:
		sorted = []
	_index(library, sorted)


static func _named_pair(library: PartLibrary, id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(id)
	var side: String = side_of(info)
	if side == "c":
		return ""
	var full: String = _plain(info.name)
	var wanted: String = "Left" if side == "r" else "Right"
	if not _patterns.has("side"):
		var expression := RegEx.new()
		expression.compile("\\b(Right|Left)\\b")
		_patterns["side"] = expression
	var found: RegExMatch = (_patterns["side"] as RegEx).search(full)
	if found == null:
		return ""
	var swapped: String = full.substr(0, found.get_start()) + wanted + full.substr(found.get_end())
	var other: String = str(_by_name.get(swapped, ""))
	if other.is_empty() or _slot_of.get(other) != _slot_of.get(id):
		return ""
	var other_side: String = side_of(library.parts[other])
	return other if other_side != side else ""


## The part that goes on the other side: a leg's or arm's pair, by name
## or by the print the two halves share, or the plain mould of the pair,
## or "" when there is none (a wooden leg, which the plain left leg
## goes with).
static func partner(library: PartLibrary, part_id: String) -> String:
	if library == null:
		# Without the library, the plain moulds' own pairs by number.
		for pair: Array in [["3816", "3817"], ["3818", "3819"]]:
			if part_id.begins_with(pair[0]):
				return str(pair[1]) + part_id.substr(4)
			if part_id.begins_with(pair[1]):
				return str(pair[0]) + part_id.substr(4)
		return ""
	_index(library)
	if _partners.has(part_id):
		return _partners[part_id]
	var found: String = _named_pair(library, part_id)
	if found.is_empty():
		var family: String = _family(part_id)
		var other_family: String = str(_family_pairs.get(family, ""))
		if not other_family.is_empty():
			var printed: String = other_family + part_id.substr(family.length())
			if _slot_of.has(printed) and printed != part_id:
				found = printed
			elif _slot_of.has(other_family):
				found = other_family
	_partners[part_id] = found
	return found


## The parts that can fill a slot, plain moulds first. Real parts only:
## not a redirect, a sticker, an alias or an assembly of other parts,
## each of which would put something on the parts list that is not an
## element anybody could buy. A left arm or leg that is the pair of a
## right one comes with it rather than on its own.
static func choices(library: PartLibrary, slot: String) -> Array[PartLibrary.PartInfo]:
	if library == null:
		return []
	_index(library)
	if _choices.has(slot):
		return _choices[slot]
	var wanted: String = "accessory" if slot == "accessory_left" else slot
	var out: Array[PartLibrary.PartInfo] = []
	# How many sets each is in: a worn drawing of cloth is in as many as
	# the cloth, which the inventories know only by its flat number.
	var sets: Dictionary = {}
	for id: String in _slot_of:
		if _slot_of[id] == wanted and not _paired.has(id):
			var info: PartLibrary.PartInfo = library.parts[id]
			out.append(info)
			var flat: PartLibrary.PartInfo = library.parts.get(flat_of(info))
			sets[id] = flat.in_sets if info.in_sets == 0 and flat != null else info.in_sets
	out.sort_custom(_better.bind(slot, sets))
	_choices[slot] = out
	return out


## How a slot's choices are grouped for browsing: by mould for the body
## (the 858 torsos on 973 together, then the droids' and the skeletons'),
## by kind for what is worn or held, which LDraw names first ("Minifig
## Weapon Sword ...", "Minifig Hat Wizard ..."). [{key, label, count}],
## the biggest first.
static func groups(library: PartLibrary, slot: String) -> Array[Dictionary]:
	var counts: Dictionary = {}
	var labels: Dictionary = {}
	var order: Array[String] = []
	for info: PartLibrary.PartInfo in choices(library, slot):
		var key: String = group_of(info, slot)
		if not counts.has(key):
			counts[key] = 0
			order.append(key)
			labels[key] = _group_label(library, info, key, slot)
		counts[key] = int(counts[key]) + 1
	var out: Array[Dictionary] = []
	for key: String in order:
		out.append({"key": key, "label": labels[key], "count": counts[key]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["count"]) != int(b["count"]):
			return int(a["count"]) > int(b["count"])
		return str(a["label"]).naturalnocasecmp_to(str(b["label"])) < 0)
	return out


## The slots grouped by mould rather than by kind.
const BY_MOULD: Array[String] = ["head", "torso", "arms", "hands", "hips", "legs"]


static func group_of(info: PartLibrary.PartInfo, slot: String) -> String:
	if info.custom:
		return MADE_HERE
	if BY_MOULD.has(slot):
		return _family(info.id)
	var words: PackedStringArray = _short_name(info.name).split(" ", false)
	return words[0] if not words.is_empty() else ""


## The group the prints and moulds made here are in, whatever the slot.
const MADE_HERE := "made here"


static func _group_label(library: PartLibrary, info: PartLibrary.PartInfo, key: String,
		slot: String) -> String:
	if key == MADE_HERE:
		return "My prints and moulds"
	if not BY_MOULD.has(slot):
		return key
	var plain: PartLibrary.PartInfo = library.parts.get(key)
	var named: String = _short_name(plain.name if plain != null else info.name)
	# A print's name says what is printed; the mould's says what it is.
	var cut: int = named.find(" with ")
	if plain == null and cut > 0:
		named = named.substr(0, cut)
	return "%s (%s)" % [named, key]


## Every real minifigure part, with the slot it is available in —
## offered there, or as the pair of a part that is.
static func offered(library: PartLibrary) -> Dictionary:
	_index(library)
	var out: Dictionary = {}
	for id: String in _slot_of:
		out[id] = _slot_of[id]
	return out


static func _real(info: PartLibrary.PartInfo) -> bool:
	if info.is_redirect() or not info.reachable:
		return false
	if not (info.kind == "Part" or info.kind == "Unofficial_Part"):
		return false
	var title: String = info.name.strip_edges()
	return not (title.begins_with("~") or title.begins_with("=")
		or title.begins_with("_") or title.begins_with("Figure "))


static var _patterns: Dictionary = {}

static func _matches(id: String, pattern: String) -> bool:
	if not _patterns.has(pattern):
		var expression := RegEx.new()
		expression.compile(pattern)
		_patterns[pattern] = expression
	return (_patterns[pattern] as RegEx).search(id) != null


## What is worn as LDraw draws it before cloth drawn flat, as it is
## sold, and in the Cape slot the worn drawings of cloth capes first of
## all — the cape on a figure in a real set's file. Then plain mouldings,
## then the mould real figures use most, then what is known to be in
## sets (`sets`, by id), official before unofficial, then by name, the
## worn drawings of one cloth in LDraw's order (50231c01 before its
## floating c02). So a slot of nine hundred torsos opens on the plain
## one, a slot of heads on the classic heads before the Muppets, and the
## Cape slot on the cloth cape of 258 sets as figures wear it.
static func _better(a: PartLibrary.PartInfo, b: PartLibrary.PartInfo, slot: String = "",
		sets: Dictionary = {}) -> bool:
	# What was made here first: a print drawn for this figure is the one
	# being looked for.
	if a.custom != b.custom:
		return a.custom
	var worn_a: int = _worn_rank(a, slot)
	var worn_b: int = _worn_rank(b, slot)
	if worn_a != worn_b:
		return worn_a < worn_b
	var plain_a: bool = _family(a.id) == a.id
	var plain_b: bool = _family(b.id) == b.id
	if plain_a != plain_b:
		return plain_a
	var classic_a: bool = CLASSIC.has(_family(a.id))
	var classic_b: bool = CLASSIC.has(_family(b.id))
	if classic_a != classic_b:
		return classic_a
	var in_a: int = int(sets.get(a.id, a.in_sets))
	var in_b: int = int(sets.get(b.id, b.in_sets))
	if (in_a > 0) != (in_b > 0):
		return in_a > in_b
	if in_a != in_b and plain_a:
		return in_a > in_b
	if a.unofficial != b.unofficial:
		return not a.unofficial
	var cloth_a: String = flat_of(a)
	if not cloth_a.is_empty() and cloth_a == flat_of(b):
		return a.id.naturalnocasecmp_to(b.id) < 0
	return a.name.naturalnocasecmp_to(b.name) < 0


## 0 for a worn drawing of a cape a figure wears (_worn_by_a_figure), 2
## for cloth drawn flat, 1 for the rest; all one in the slots that are
## not cloth.
static func _worn_rank(info: PartLibrary.PartInfo, slot: String) -> int:
	if not (slot in ["cape", "hipwear"]):
		return 1
	if _is_flat(info):
		return 2
	if slot == "cape" and not flat_of(info).is_empty() and _worn_by_a_figure(info):
		return 0
	return 1


## The moulds of the figure every figure starts as, which open their
## slots: a slot of nine hundred torsos opens on 973, not on a droid.
const CLASSIC: Array[String] = ["3626c", "973", ARM_RIGHT, HAND, PLAIN_HIPS, PLAIN_LEGS]


## The part whose colours say what a slot's part comes in. A print is
## sold in the colour it was printed on, which the inventories cannot
## join to LDraw's print numbers, so its plain moulding stands in: the
## colours 3626c was made in are the colours there are heads in.
static func colours_of(library: PartLibrary, part_id: String) -> PartLibrary.PartInfo:
	# A print or mould made here comes in what its original comes in.
	if PartPrints.bases.has(part_id):
		return colours_of(library, PartPrints.base_of(part_id))
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if info != null and info.availability_known():
		return info
	# A worn drawing of cloth comes in the colours the cloth does: 50231c01
	# in 50231's.
	var cloth: PartLibrary.PartInfo = library.parts.get(flat_of(info))
	if cloth != null and cloth.availability_known():
		return cloth
	var plain: String = _family(part_id)
	# A bare torso is only ever sold with its arms on: 973c00, which is
	# LDraw's 76382.
	if plain == "973":
		plain = "76382"
	var stand_in: PartLibrary.PartInfo = library.parts.get(plain)
	if stand_in != null and stand_in.availability_known():
		return stand_in
	return info


## A colour for a part just put in a slot: the slot's own if the part
## is made in it or nothing is known, otherwise the one it is most made
## in now — so a plume does not arrive in the clear plastic of the visor
## that was there before it.
static func fitting_colour(library: PartLibrary, part_id: String, current: int) -> int:
	var info: PartLibrary.PartInfo = colours_of(library, part_id) \
		if not part_id.is_empty() else null
	if info == null or not info.availability_known() or info.colors.has(current):
		return current
	var known: PackedInt32Array = info.colors_recent if not info.colors_recent.is_empty() \
		else info.colors
	var best: int = known[0]
	var most: int = -1
	for code: int in known:
		var use: int = library.colour_use(code).x
		if use > most:
			most = use
			best = code
	return best


## Which part a slot's colour is about, for marking the colours it
## comes in.
func part_for_colour(slot: String) -> String:
	return part(slot)


## A printed torso comes with arms and hands in particular colours: what
## the library's own torso assemblies give it, or the torso's colour and
## yellow.
func dress_torso(torso: String) -> void:
	parts["torso"] = torso
	var hands: Array = MinifigData.TORSO_HANDS.get(torso, [-1, 14])
	# 16 in an assembly is "the colour the assembly is placed in", which
	# for a torso assembly is the torso's.
	var own := func(code: int) -> int:
		return int(colours["torso"]) if code < 0 or code == 16 else code
	colours["arms"] = own.call(int(hands[0]))
	colours["hands"] = own.call(int(hands[1]))


## Put a part in a slot, and with it what the part needs: a torso its
## printed arm colours, and an odd body the parts the library's complete
## figure has with it — a battle droid torso its droid head, arms and
## legs, and no hips or hands — where the figure has the plain ones; a
## body moulded down to the ground no legs. Choosing the plain torso
## again gives the plain parts back. The other way round too, where the
## library only ever attaches a part to another: a battle droid's head
## brings its body, printed legs their printed hips, springs the legs and
## hips they go into, a prosthetic hand the arm it goes on.
func choose(library: PartLibrary, slot: String, part_id: String) -> void:
	var was_colour: int = int(colours.get(slot, 16))
	if library != null and not part_id.is_empty():
		colours[slot] = fitting_colour(library, part_id, was_colour)
	var was: String = part(slot)
	if slot == "torso":
		dress_torso(part_id)
		_fit_body(library, was, part_id)
	else:
		parts[slot] = part_id
	match slot:
		"head":
			# A head with no socket for the neck post, which the library
			# only puts on its own body — a battle droid's clips onto its
			# torso's bar, and a plain torso has none — brings that body,
			# as the body brings it.
			var body: String = str(MinifigData.HEADS_ON.get(_family(part_id), ""))
			if not body.is_empty() and _family(part("torso")) == "973":
				choose(library, "torso", body)
		"legs":
			_fit_hips(library, was, part_id)
		"hands":
			_fit_arm(was, part_id)
		"arms":
			# An arm the hand cannot go on: the plain hand back.
			var needs: Array = MinifigData.ON_ARMS.get(_family(part("hands")), [])
			if not needs.is_empty() and _family(part_id) != _family(str(needs[0])):
				parts["hands"] = HAND
	if PAIRED.has(slot) and library != null:
		if _has_plain_partner(library, slot):
			if not colours.has(slot + OTHER):
				colours[slot + OTHER] = was_colour
		else:
			colours.erase(slot + OTHER)


## Slots whose part goes on both sides, and the colour key of the plain
## part opposite one that has no pair.
const PAIRED: Array[String] = ["arms", "hands", "legs"]
const OTHER := "_other"


## Whether the part in a paired slot is one side only, with the plain
## part on the other: a hook, a robot arm, a wooden leg.
func _has_plain_partner(library: PartLibrary, slot: String) -> bool:
	var chosen: String = part(slot)
	if chosen.is_empty():
		return false
	var sides: Dictionary = {}
	match slot:
		"arms": sides = _arm_parts(library)
		"hands": sides = _hand_parts(library)
		_: sides = _leg_parts(library)
	return (sides["r"] != chosen or sides["l"] != chosen) \
		and partner(library, chosen).is_empty()


## Legs with the hips the library's own assemblies put them with
## (MinifigData.LEG_HIPS): a printed pair the hips printed to match
## (3816cpx0 with 3815bpx0, as 73200bpx0 has them), in the colour the
## assembly gives them (3816cp30's are reddish brown); springs the hips
## they go into (43221, as 43743-f1). Only over plain hips or the ones
## the legs before brought: hips somebody chose stay.
func _fit_hips(library: PartLibrary, was: String, legs: String) -> void:
	# Hips printed with the legs, one print over both (PartPrints), come
	# and go with them.
	if PartPrints.bases.has(part("hips")) and PartPrints.bases.has(was) \
			and _tag(part("hips")) == _tag(was):
		parts["hips"] = PartPrints.base_of(part("hips"))
	if PartPrints.bases.has(legs):
		var printed: String = made_with(library, legs, part("hips"))
		if not printed.is_empty():
			parts["hips"] = printed
			return
	var before: Array = MinifigData.LEG_HIPS.get(was, [])
	var after: Array = MinifigData.LEG_HIPS.get(legs, [])
	var now: String = part("hips")
	var by_legs: bool = not before.is_empty() and str(before[0]) == now
	if not (by_legs or now == PLAIN_HIPS):
		return
	if after.is_empty():
		parts["hips"] = PLAIN_HIPS
		return
	parts["hips"] = str(after[0])
	var colour: int = int(after[1])
	colours["hips"] = int(colours["legs"]) if colour < 0 else colour
	if library != null:
		colours["hips"] = fitting_colour(library, part("hips"), int(colours["hips"]))


## A hand the library puts on an arm of its own brings that arm
## (MinifigData.ON_ARMS): the prosthetic hand 5059 goes on the stump
## 6828, where 6828.dat's HELP line says, and on no other — on a plain
## arm it pointed back up it. Over a plain arm or one the hand before
## brought; the plain arm back when the hand goes.
func _fit_arm(was: String, hand: String) -> void:
	var before: Array = MinifigData.ON_ARMS.get(_family(was), [])
	var after: Array = MinifigData.ON_ARMS.get(_family(hand), [])
	var now: String = part("arms")
	var by_hand: bool = not before.is_empty() and str(before[0]) == now
	if not (by_hand or now == ARM_RIGHT):
		return
	if not after.is_empty():
		parts["arms"] = str(after[0])
	elif by_hand:
		parts["arms"] = ARM_RIGHT


func _fit_body(library: PartLibrary, was: String, torso: String) -> void:
	var before: Dictionary = body_of(library, was)
	var after: Dictionary = body_of(library, torso)
	var plain: Dictionary = {"head": "3626cp01", "arms": ARM_RIGHT, "hands": HAND,
		"hips": PLAIN_HIPS, "legs": PLAIN_LEGS}
	for slot: String in plain:
		var now: String = part(slot)
		# Only over what the figure had because of the body before it, or
		# a plain part: a printed head somebody chose stays on a droid's
		# neck if they put it there afterwards.
		var by_body: bool = before.has(slot) and str(before[slot]) == now
		var plain_now: bool = now == plain[slot] or (slot == "head" and (now.is_empty()
			or _family(now) in ["3626c", "3626b", "3626a", "28621"]))
		if not (by_body or plain_now):
			continue
		if after.has(slot):
			parts[slot] = str(after[slot])
		elif by_body or now.is_empty():
			parts[slot] = plain[slot]


## What a torso brings with it, slot -> part, "" for a slot it fills
## itself or leaves empty: the library's complete figure where it has
## one (MinifigData.BODIES: a battle droid's head, arms and legs);
## arms moulded on where LDraw's name says so (17, "Torso with Integral
## Arms"); a head where it says "Head and Torso"; and no hips or legs for
## a body that stands on its own — one moulded down to the ground, or
## drawn from its feet up, as Sebulba, Gollum and the babies are. One
## drawn from its feet up and as tall as a figure is the whole figure,
## head and arms and all.
static func body_of(library: PartLibrary, torso: String) -> Dictionary:
	var out: Dictionary = (MinifigData.BODIES.get(_family(torso), {}) as Dictionary).duplicate()
	var assembled: bool = not out.is_empty()
	var info: PartLibrary.PartInfo = _info(library, torso)
	if info == null:
		return out
	var short: String = _short_name(info.name)
	if _matches(short, "\\bArms\\b"):
		out["arms"] = ""
		out["hands"] = ""
	if _matches(short, "\\bHead and Torso\\b"):
		out["head"] = ""
	# In LDraw's axes: how far it reaches above its origin and below it.
	var top: float = -(info.bounds.position.y + info.bounds.size.y)
	var bottom: float = -info.bounds.position.y
	# A complete figure in the library with no head: the head is moulded
	# on, if the body reaches up where a head would be (41889, the super
	# battle droid).
	if out.has("legs") and not out.has("head") and top <= -30.0:
		out["head"] = ""
	var babe: bool = _matches(short, "^(Baby Body|Bundled Baby)\\b")
	var alone: bool = not out.has("legs") and (top <= -30.0 or babe)
	if alone or bottom >= 60.0:
		for slot: String in ["hips", "legs"]:
			if not out.has(slot):
				out[slot] = ""
	if alone and (top <= -45.0 or short.begins_with("Bundled Baby") or assembled):
		for slot: String in ["head", "arms", "hands"]:
			if not out.has(slot):
				out[slot] = ""
	return out


static func _whole_body(library: PartLibrary, part_id: String) -> bool:
	var body: Dictionary = body_of(library, part_id)
	return str(body.get("legs", "x")).is_empty() and str(body.get("head", "x")).is_empty()


# -- a figure at random ------------------------------------------------------


## A figure nobody chose. Each slot from what can fill it, prints more
## often than not where a slot has them, and every colour one its part
## really comes in: the torso in a colour torsos are sold in (76382's,
## since 973 is never sold bare), the legs in 3816c's, the hat and what
## it holds in their own. The body is a classic one — odd bodies are
## there to be chosen, not to be dealt.
static func surprise(library: PartLibrary, rng: RandomNumberGenerator) -> Minifig:
	var figure := Minifig.new()
	var pick := func(slot: String, printed: bool, family: String) -> String:
		var all: Array[PartLibrary.PartInfo] = choices(library, slot)
		var pool: Array[PartLibrary.PartInfo] = all.filter(
			func(info: PartLibrary.PartInfo) -> bool:
				return (_family(info.id) != info.id) == printed and not info.unofficial \
					and (family.is_empty() or _family(info.id) == family))
		if pool.is_empty():
			pool = all
		return "" if pool.is_empty() else pool[rng.randi() % pool.size()].id
	figure.name = ""
	figure.colours["torso"] = _a_colour_of(library, "973", rng)
	figure.dress_torso(pick.call("torso", true, "973"))
	figure.parts["head"] = pick.call("head", true, "3626c" if rng.randf() < 0.5 else "3626b")
	figure.colours["head"] = 14
	var roll: float = rng.randf()
	if roll < 0.1:
		figure.parts["legs"] = "41879a"
	elif roll < 0.35:
		figure.parts["legs"] = pick.call("legs", true, PLAIN_LEGS)
	else:
		figure.parts["legs"] = PLAIN_LEGS
	figure.colours["legs"] = _a_colour_of(library, PLAIN_LEGS, rng)
	figure.colours["hips"] = figure.colours["legs"] if rng.randf() < 0.7 \
		else _a_colour_of(library, PLAIN_HIPS, rng)
	figure.parts["hips"] = PLAIN_HIPS
	figure.parts["headwear"] = pick.call("headwear", false, "") if rng.randf() < 0.85 else ""
	figure.parts["accessory"] = pick.call("accessory", false, "") if rng.randf() < 0.6 else ""
	figure.parts["neck"] = pick.call("neck", false, "") if rng.randf() < 0.15 else ""
	for slot: String in ["headwear", "accessory", "neck"]:
		figure.colours[slot] = _a_colour_of(library, str(figure.parts[slot]), rng)
	return figure


## One of the colours a part really comes in, or black: weighted by how
## many parts are made in it now, so a figure comes out in the colours
## figures are, and never in a glow-in-the-dark one nobody would pick.
static func _a_colour_of(library: PartLibrary, part_id: String,
		rng: RandomNumberGenerator) -> int:
	var info: PartLibrary.PartInfo = colours_of(library, part_id) \
		if not part_id.is_empty() else null
	if info == null or not info.availability_known():
		return 0
	var known: PackedInt32Array = info.colors_recent if not info.colors_recent.is_empty() \
		else info.colors
	var codes: Array[int] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for code: int in known:
		var colour: PartLibrary.BrickColor = library.colors.get(code)
		if colour == null or colour.is_transparent() \
				or colour.drawn_as != PartLibrary.BrickColor.Finish.PLASTIC:
			continue
		var weight: float = float(maxi(1, library.colour_use(code).x))
		codes.append(code)
		weights.append(weight)
		total += weight
	if codes.is_empty():
		return known[0]
	var roll: float = rng.randf() * total
	for n: int in codes.size():
		roll -= weights[n]
		if roll <= 0.0:
			return codes[n]
	return codes[-1]


# -- keeping figures ---------------------------------------------------------


## Where kept figures live: user://, which is the browser's own storage on
## the web. A probe points it somewhere of its own, so a check run on
## this machine never touches the figures its owner kept.
static var shelf_file: String = "user://minifigs.json"


func to_dict() -> Dictionary:
	return {"name": name, "parts": parts.duplicate(), "colours": colours.duplicate()}


static func from_dict(raw: Dictionary) -> Minifig:
	var figure := Minifig.new()
	figure.name = str(raw.get("name", "Minifig"))
	var given_parts: Dictionary = raw.get("parts", {})
	var given_colours: Dictionary = raw.get("colours", {})
	for slot: String in SLOTS:
		if given_parts.has(slot):
			figure.parts[slot] = str(given_parts[slot])
		if given_colours.has(slot):
			figure.colours[slot] = int(given_colours[slot])
	for slot: String in PAIRED:
		if given_colours.has(slot + OTHER):
			figure.colours[slot + OTHER] = int(given_colours[slot + OTHER])
	return figure


## The figures kept so far, newest first.
static func shelf(path: String = "") -> Array[Minifig]:
	if path.is_empty():
		path = shelf_file
	var out: Array[Minifig] = []
	if not FileAccess.file_exists(path):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return out
	for raw: Variant in (parsed as Dictionary).get("figures", []):
		if raw is Dictionary:
			out.append(from_dict(raw))
	return out


## Keep a figure, replacing one of the same name.
static func keep(figure: Minifig, path: String = "") -> bool:
	if path.is_empty():
		path = shelf_file
	var kept: Array[Minifig] = shelf(path).filter(func(other: Minifig) -> bool:
		return other.name != figure.name)
	kept.push_front(figure.copy())
	return _write_shelf(kept, path)


static func forget(name_of: String, path: String = "") -> bool:
	if path.is_empty():
		path = shelf_file
	return _write_shelf(shelf(path).filter(func(other: Minifig) -> bool:
		return other.name != name_of), path)


static func _write_shelf(figures: Array, path: String) -> bool:
	var raw: Array = []
	for figure: Minifig in figures:
		raw.append(figure.to_dict())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"figures": raw}, "\t"))
	file.close()
	return true
