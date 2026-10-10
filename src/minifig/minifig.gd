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
## Everything is worked out in LDraw's axes, the axes those numbers were
## written in, and turned into the app's only at the end.
class_name Minifig
extends RefCounted

## The slots, in the order a figure is described: top to bottom, then
## what it holds.
const SLOTS: Array[String] = [
	"headwear", "head", "neck", "torso", "arms", "hands", "hips", "legs",
	"accessory"]
## Slots a figure may leave empty.
const OPTIONAL: Array[String] = ["headwear", "neck", "accessory"]
## Slots that are a colour and not a choice of part: the arms and hands
## are the same mouldings on every figure.
const COLOUR_ONLY: Array[String] = ["arms", "hands"]

const TITLES: Dictionary = {
	"headwear": "Headgear", "head": "Head", "neck": "Neck", "torso": "Torso",
	"arms": "Arms", "hands": "Hands", "hips": "Hips", "legs": "Legs",
	"accessory": "In hand",
}

const ARM_RIGHT := "3818"
const ARM_LEFT := "3819"
const HAND := "3820"
const PLAIN_HIPS := "3815b"
const PLAIN_LEGS := "3816c"     ## the right leg; the left is its pair, 3817c

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
## the two studs it stands on. The current legs' hole is 1.25 LDU
## forward of the leg's origin (3816c.dat: "Move at z=1.25 relative to
## stud grid") and 72 below the torso: 32 to the hips, 12 to the legs,
## 28 down them. Short legs hold their studs 24 under the hips, square
## under them (41879a: stud23d at 10 24 0).
const TORSO_STANDING: Array[float] = [0, -72, 1.25, 1, 0, 0, 0, 1, 0, 0, 0, 1]
const TORSO_SHORT: Array[float] = [0, -56, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]

## Where a hand closes, in the hand's own frame (3820.dat: "The centre
## of the grip is at x, y -.8229, z -9.8948"; "The Hand angle is 14.5
## degrees"). An accessory's bar is laid along this axis through this
## point; where its bar is comes from MinifigData.GRIPS.
const GRIP := Vector3(0.0, -0.8229, -9.8948)
const GRIP_AXIS := Vector3(0.0, 0.968148, 0.25038)

## LDraw's axes into the app's: a half turn about X, as LdrModel does it.
const FLIP := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, -1, 0),
	Vector3(0, 0, -1)), Vector3.ZERO)

## The colours a new figure starts in: the yellow of a classic figure,
## and the town colours of the first ones.
const START: Dictionary = {
	"headwear": 70, "head": 14, "neck": 0, "torso": 4, "arms": 4, "hands": 14,
	"hips": 1, "legs": 1, "accessory": 0,
}

var name: String = "Minifig"
## Slot -> part id. Empty for an optional slot left bare.
var parts: Dictionary = {}
## Slot -> LDraw colour code.
var colours: Dictionary = {}


func _init() -> void:
	parts = {"headwear": "3901", "head": "3626cp01", "neck": "",
		"torso": "973", "arms": ARM_RIGHT, "hands": HAND,
		"hips": PLAIN_HIPS, "legs": PLAIN_LEGS, "accessory": ""}
	colours = START.duplicate()


func copy() -> Minifig:
	var other := Minifig.new()
	other.name = name
	other.parts = parts.duplicate()
	other.colours = colours.duplicate()
	return other


# -- the parts, placed ------------------------------------------------------


## Every part of the figure, placed in the figure's own frame: the app's
## axes, the origin the middle of the top of the two studs it stands on,
## facing +Z. [{slot, part, color, at}], torso first.
##
## Given the library, a figure holding something long — a spear, a
## staff, a lance — holds it the way real figures do rather than through
## the floor: see [method _held].
func assemble(library: PartLibrary = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var torso: Transform3D = _ldraw(TORSO_SHORT if is_short() else TORSO_STANDING)
	var at := func(slot: String, part: String, local: Transform3D) -> void:
		out.append({"slot": slot, "part": part, "color": int(colours.get(slot, 16)),
			"at": FLIP * torso * local * FLIP})
	at.call("torso", str(parts["torso"]), Transform3D.IDENTITY)
	var neck: String = str(parts.get("neck", ""))
	var lift: float = float(MinifigData.NECK_LIFT.get(neck, 0)) if not neck.is_empty() else 0.0
	var head: Transform3D = _ldraw(HEAD).translated(Vector3(0, -lift, 0))
	at.call("head", str(parts["head"]), head)
	if not str(parts.get("headwear", "")).is_empty():
		at.call("headwear", str(parts["headwear"]), head)
	if not neck.is_empty():
		at.call("neck", neck, Transform3D.IDENTITY)
	var held: String = str(parts.get("accessory", ""))
	var holding: Array = _held(held, torso, library)
	at.call("arms", ARM_RIGHT, holding[0])
	at.call("arms", ARM_LEFT, _ldraw(ARM_L))
	at.call("hands", HAND, holding[1])
	at.call("hands", HAND, _ldraw(HAND_L))
	if is_short():
		at.call("legs", str(parts["legs"]), _ldraw(HIPS))
	else:
		at.call("hips", str(parts["hips"]), _ldraw(HIPS))
		at.call("legs", str(parts["legs"]), _ldraw(LEGS))
		at.call("legs", left_leg(), _ldraw(LEGS))
	if not held.is_empty():
		at.call("accessory", held, (holding[1] as Transform3D) * (holding[2] as Transform3D))
	return out


## The right arm, the right hand, and what is in it relative to that
## hand, all in LDraw's axes: [arm, hand, held].
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
## reach below the figure's feet.
func _held(held: String, torso: Transform3D, library: PartLibrary) -> Array:
	var arm: Transform3D = _ldraw(ARM_R)
	var hand: Transform3D = _ldraw(HAND_R)
	if held.is_empty():
		return [arm, hand, Transform3D.IDENTITY]
	var grip: Transform3D = in_hand(held)
	var info: PartLibrary.PartInfo = library.parts.get(held) if library != null else null
	if info == null:
		return [arm, hand, grip]
	var size: Vector3 = info.bounds.size
	var long: bool = maxf(size.x, maxf(size.y, size.z)) >= LONG
	if not long and _lowest(torso * hand * grip, info.bounds) >= 0.0:
		return [arm, hand, grip]
	var raised: Transform3D = arm * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-45.0)),
		Vector3.ZERO)
	hand = raised * arm.affine_inverse() * hand
	var low: float = _lowest(torso * hand * grip, info.bounds)
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
		var along: float = (FLIP.basis * (torso * hand).basis * GRIP_AXIS).y
		if absf(along) > 0.05:
			grip.origin += GRIP_AXIS * ((BrickLattice.CELL - low) / along)
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
func torso_local() -> Transform3D:
	return FLIP * _ldraw(TORSO_SHORT if is_short() else TORSO_STANDING) * FLIP


## Whether the legs are the short ones that are hips and legs in a
## single moulding.
func is_short() -> bool:
	return is_short_legs(str(parts.get("legs", "")))


static func is_short_legs(part_id: String) -> bool:
	return part_id.begins_with("41879") or part_id.begins_with("16709")


## The left leg that goes with the right one: 3816c with 3817c, and a
## printed pair by its print, 3816cp01 with 3817cp01.
func left_leg() -> String:
	var right: String = str(parts.get("legs", PLAIN_LEGS))
	if right.begins_with("3816"):
		return "3817" + right.substr(4)
	return right


## Every part id the figure needs, for fetching what is not to hand.
func part_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for placed: Dictionary in assemble():
		if not out.has(str(placed["part"])):
			out.append(str(placed["part"]))
	return out


## A placement as an LDraw line writes it, still in LDraw's axes.
static func _ldraw(v: Array) -> Transform3D:
	return Transform3D(
		Basis(Vector3(v[3], v[6], v[9]), Vector3(v[4], v[7], v[10]),
			Vector3(v[5], v[8], v[11])),
		Vector3(v[0], v[1], v[2]))


# -- reading a figure back off a model ---------------------------------------


## Which part of a figure a part is: a slot name, or "" for a part that
## is not one.
static func role_of(part_id: String, info: PartLibrary.PartInfo = null) -> String:
	if _matches(part_id, "^973(p\\w+)?$"):
		return "torso"
	if part_id.begins_with("3626"):
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
	if info != null:
		match info.category:
			"Minifig Headwear": return "headwear"
			"Minifig Neckwear": return "neck"
			"Minifig Accessory": return "accessory"
	return ""


## The figure's frame in the world, from its parts: [{part, at}] or
## Bricks. Null when there is no torso to read it from.
##
## Found from the torso, which every figure has exactly one of, and
## the legs, which say how far below it the studs are.
static func frame_of(placed: Array) -> Variant:
	var torso: Variant = null
	var short: bool = false
	for item: Variant in placed:
		var part: String = _part_of(item)
		if role_of(part) == "torso":
			torso = _at_of(item)
		if is_short_legs(part):
			short = true
	if torso == null:
		return null
	var shape := Minifig.new()
	if short:
		shape.parts["legs"] = "41879a"
	return (torso as Transform3D) * shape.torso_local().affine_inverse()


## Whether some parts are a figure: a torso and a head among them.
static func is_figure(placed: Array) -> bool:
	var roles: Dictionary = {}
	for item: Variant in placed:
		roles[role_of(_part_of(item))] = true
	return roles.has("torso") and roles.has("head")


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
	return info != null and info.category.begins_with("Minifig") \
		and info.category != "Minifig Accessory"


# -- what each slot can be -------------------------------------------------


static var _choices: Dictionary = {}
static var _choices_of: int = 0


## The parts that can fill a slot, best known first. Real parts only:
## not a redirect, a sticker, an alias or an assembly of other parts,
## each of which would put something on the parts list that is not an
## element anybody could buy.
static func choices(library: PartLibrary, slot: String) -> Array[PartLibrary.PartInfo]:
	if library == null:
		return []
	if _choices_of != library.get_instance_id():
		_choices.clear()
		_choices_of = library.get_instance_id()
	if _choices.has(slot):
		return _choices[slot]
	var out: Array[PartLibrary.PartInfo] = []
	var lefts: Dictionary = {}
	if slot == "legs":
		for id: String in library.parts:
			if id.begins_with("3817c"):
				lefts[id.substr(4)] = true
	for id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[id]
		if not _real(info):
			continue
		if _fits(info, slot) and (slot != "legs" or not id.begins_with("3816") \
				or lefts.has(id.substr(4))):
			out.append(info)
	out.sort_custom(_better)
	_choices[slot] = out
	return out


static func _real(info: PartLibrary.PartInfo) -> bool:
	if info.is_redirect() or not info.reachable:
		return false
	if not (info.kind == "Part" or info.kind == "Unofficial_Part"):
		return false
	var title: String = info.name.strip_edges()
	return not (title.begins_with("~") or title.begins_with("=")
		or title.begins_with("_") or title.begins_with("Figure "))


static func _fits(info: PartLibrary.PartInfo, slot: String) -> bool:
	var id: String = info.id
	match slot:
		"headwear":
			# Plumes, visors and feathers fix onto a helmet rather than a
			# head, at offsets of their own.
			return info.category == "Minifig Headwear" and not (
				info.name.contains("Visor") or info.name.contains("Plume")
				or info.name.contains("Feather"))
		"head":
			return _matches(id, "^3626[abc](p\\w+)?$")
		"torso":
			return _matches(id, "^973(p\\w+)?$")
		"hips":
			return _matches(id, "^3815b(p\\w+)?$")
		"legs":
			return _matches(id, "^3816c(p\\w+)?$") \
				or _matches(id, "^(41879a|16709)(p\\w+)?$")
		"neck":
			return info.category == "Minifig Neckwear"
		"accessory":
			return info.category == "Minifig Accessory"
	return false


static var _patterns: Dictionary = {}

static func _matches(id: String, pattern: String) -> bool:
	if not _patterns.has(pattern):
		var expression := RegEx.new()
		expression.compile(pattern)
		_patterns[pattern] = expression
	return (_patterns[pattern] as RegEx).search(id) != null


## Plain mouldings first, then what is known to be in sets, then
## official before unofficial, then by name.
static func _better(a: PartLibrary.PartInfo, b: PartLibrary.PartInfo) -> bool:
	var plain_a: bool = not a.id.contains("p")
	var plain_b: bool = not b.id.contains("p")
	if plain_a != plain_b:
		return plain_a
	if (a.in_sets > 0) != (b.in_sets > 0):
		return a.in_sets > b.in_sets
	if a.unofficial != b.unofficial:
		return not a.unofficial
	return a.name.naturalnocasecmp_to(b.name) < 0


## The part whose colours say what a slot's part comes in. A print is
## sold in the colour it was printed on, which the inventories cannot
## join to LDraw's print numbers, so its plain moulding stands in: the
## colours 3626c was made in are the colours there are heads in.
static func colours_of(library: PartLibrary, part_id: String) -> PartLibrary.PartInfo:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if info != null and info.availability_known():
		return info
	var plain: String = part_id
	if _matches(part_id, "^\\d+[a-z]?p\\w+$"):
		plain = part_id.substr(0, part_id.find("p", 3))
	# A bare torso is only ever sold with its arms on: 973c00, which is
	# LDraw's 76382.
	if plain == "973":
		plain = "76382"
	var stand_in: PartLibrary.PartInfo = library.parts.get(plain)
	if stand_in != null and stand_in.availability_known():
		return stand_in
	return info


## Which part a slot's colour is about, for marking the colours it
## comes in.
func part_for_colour(slot: String) -> String:
	match slot:
		"arms": return ARM_RIGHT
		"hands": return HAND
	return str(parts.get(slot, ""))


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


# -- a figure at random ------------------------------------------------------


## A figure nobody chose. Each slot from what can fill it, prints more
## often than not where a slot has them, and every colour one its part
## really comes in: the torso in a colour torsos are sold in (76382's,
## since 973 is never sold bare), the legs in 3816c's, the hat and what
## it holds in their own.
static func surprise(library: PartLibrary, rng: RandomNumberGenerator) -> Minifig:
	var figure := Minifig.new()
	var pick := func(slot: String, printed: bool) -> String:
		var all: Array[PartLibrary.PartInfo] = choices(library, slot)
		var pool: Array[PartLibrary.PartInfo] = all.filter(
			func(info: PartLibrary.PartInfo) -> bool:
				return info.id.contains("p") == printed and not info.unofficial)
		if pool.is_empty():
			pool = all
		return "" if pool.is_empty() else pool[rng.randi() % pool.size()].id
	figure.name = ""
	figure.colours["torso"] = _a_colour_of(library, "973", rng)
	figure.dress_torso(pick.call("torso", true))
	figure.parts["head"] = pick.call("head", true)
	figure.colours["head"] = 14
	var roll: float = rng.randf()
	if roll < 0.1:
		figure.parts["legs"] = "41879a"
	elif roll < 0.35:
		figure.parts["legs"] = pick.call("legs", true)
	else:
		figure.parts["legs"] = PLAIN_LEGS
	figure.colours["legs"] = _a_colour_of(library, PLAIN_LEGS, rng)
	figure.colours["hips"] = figure.colours["legs"] if rng.randf() < 0.7 \
		else _a_colour_of(library, PLAIN_HIPS, rng)
	figure.parts["hips"] = PLAIN_HIPS
	figure.parts["headwear"] = pick.call("headwear", false) if rng.randf() < 0.85 else ""
	figure.parts["accessory"] = pick.call("accessory", false) if rng.randf() < 0.6 else ""
	figure.parts["neck"] = pick.call("neck", false) if rng.randf() < 0.15 else ""
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
