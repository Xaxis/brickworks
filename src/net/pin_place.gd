## Which part a comment pinned to a part is on (partpins, 2026-11-23): the
## rule web/card.js pinPlace keeps for the model's page, its 3D view and the
## server, here for the app's viewer and the studio, with the same numbers.
## tests/fixtures/pins/pairs.json holds what the page's rule said of real
## version pairs, and src/dev/partpins_probe.gd holds this to it, case for
## case.
##
## A pin keeps the part as the file of its version had it (api/_comments.js):
## its number, colour, where it stood (at, LDraw's coordinates, LDU), how it
## was turned (turn, [method turn_of]'s), the line that placed it, where the
## others of its number and colour stood within [constant NEAR] of it (near;
## full false when there were more than [constant MOST]), and which parts of
## another number or colour stood where it stood (with: a window's glass in
## its frame). Shown on a model, it is on:
##   - the part of its number and colour standing where it stood (within
##     [constant SLACK]), turned as it was where others of its kind stood
##     there too (a ring of curved parts about one point): the same part;
##   - else, when nothing new stands there and every one of its neighbours
##     of its kind is still where it was, the one part of its number and
##     colour within [constant REACH] that was not one of them: moved since;
##   - else on no part: it is listed as said on its version, never on a part
##     it was not made on (a part recoloured, swapped, taken off, or moved
##     beside another of its kind that moved too).
class_name PinPlace
extends RefCounted

const SLACK := 2.0
const REACH := 20.0
const NEAR := 24.0
const MOST := 48
## How far apart two turns' numbers may be and still be the same turn.
const TURNED := 0.05
## LDraw's axes to the app's, and back: diag(1, -1, -1) (LdrModel.FLIP).
const _FLIP: Array[float] = [1.0, -1.0, -1.0]


## A part's number as the rule compares two: lower case, without a folder or
## ".dat".
static func part_of(id: Variant) -> String:
	var named: String = str(id if id != null else "").strip_edges().to_lower().replace("\\", "/")
	var slash: int = named.rfind("/")
	if slash >= 0:
		named = named.substr(slash + 1)
	if named.ends_with(".dat") or named.ends_with(".ldr"):
		named = named.substr(0, named.length() - 4)
	return named


## [param v] as JavaScript's Number() reads the values an answer holds:
## numbers, numeric strings ("" and spaces 0), true 1, false and null 0;
## NAN for anything else.
static func _number(v: Variant) -> float:
	if v == null:
		return 0.0
	if v is float or v is int:
		return float(v)
	if v is bool:
		return 1.0 if v else 0.0
	if v is String:
		var text: String = (v as String).strip_edges()
		if text.is_empty():
			return 0.0
		return text.to_float() if text.is_valid_float() else NAN
	return NAN


## A number as JavaScript writes it in a template, for a kind's colour.
static func _written(n: float) -> String:
	if is_nan(n):
		return "NaN"
	if is_inf(n):
		return "Infinity" if n > 0.0 else "-Infinity"
	if n == floorf(n) and absf(n) < 1e15:
		return str(int(n))
	return str(n)


## A part's kind as the rule compares two: its number and its colour
## (card.js kindOf).
static func _kind(part: Variant, colour: float) -> String:
	return "%s %s" % [part_of(part), _written(colour)]


static func _kind_of(one: Dictionary) -> String:
	return _kind(one.get("part"), _number(one["colour"]) if one.has("colour") else NAN)


## A point from an answer's [x, y, z] as JavaScript subtracts its numbers:
## the first three, each as Number() reads it (NAN past the end). [] for
## what is not a list.
static func _loose(given: Variant) -> PackedFloat64Array:
	if not given is Array:
		return PackedFloat64Array()
	var out := PackedFloat64Array()
	for k: int in 3:
		out.append(_number((given as Array)[k]) if k < (given as Array).size() else NAN)
	return out


## A pin's own place: three numbers, each finite, or [] for none.
static func point_of(given: Variant) -> PackedFloat64Array:
	if given is Vector3:
		return PackedFloat64Array([(given as Vector3).x, (given as Vector3).y, (given as Vector3).z])
	if not given is Array or (given as Array).size() != 3:
		return PackedFloat64Array()
	var out: PackedFloat64Array = _loose(given)
	for n: float in out:
		if is_nan(n) or is_inf(n):
			return PackedFloat64Array()
	return out


## Math.hypot of the difference, in doubles: a Vector3 holds 32-bit floats,
## and the rule's edges (2, 20 and 26 LDU) are compared as the page does.
static func _apart(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	var x: float = a[0] - b[0]
	var y: float = a[1] - b[1]
	var z: float = a[2] - b[2]
	return sqrt(x * x + y * y + z * z)


## Whether [param a] (a pin's turn, nine numbers, or null) and [param b] (a
## part's, as the answer has it) are the same turn: true when either is
## missing (card.js sameTurn).
static func _same_turn(a: Variant, b: Variant) -> bool:
	if a == null or b == null or (b is bool and not b) \
			or ((b is float or b is int) and (float(b) == 0.0 or is_nan(float(b)))) \
			or (b is String and (b as String).is_empty()):
		return true
	if not b is Array:
		return false
	for k: int in (a as Array).size():
		var theirs: float = _number((b as Array)[k]) if k < (b as Array).size() else NAN
		if not absf(_number((a as Array)[k]) - theirs) <= TURNED:
			return false
	return true


## Math.round's: the nearest whole number, a half up.
static func _round(v: float) -> float:
	var down: float = floorf(v)
	return down + 1.0 if v - down >= 0.5 else down


## How a part is turned, as a pin keeps it (card.js pinTurn): LDraw's nine
## numbers (a b c d e f g h i, a row at a time), each column made a unit, a
## mirrored part's first column turned back, each to four places. Null for
## nine that are not numbers.
static func turn_of(nine: Array) -> Variant:
	if nine.size() != 9:
		return null
	var r: Array[float] = []
	for v: Variant in nine:
		var n: float = _number(v)
		if is_nan(n) or is_inf(n):
			return null
		r.append(n)
	for c: int in 3:
		var n: float = sqrt(r[c] * r[c] + r[3 + c] * r[3 + c] + r[6 + c] * r[6 + c])
		if n == 0.0 or is_nan(n):
			n = 1.0
		for k: int in 3:
			r[k * 3 + c] /= n
	var det: float = r[0] * (r[4] * r[8] - r[5] * r[7]) - r[1] * (r[3] * r[8] - r[5] * r[6]) \
		+ r[2] * (r[3] * r[7] - r[4] * r[6])
	if det < 0.0:
		for k: int in [0, 3, 6]:
			r[k] = -r[k]
	var out: Array = []
	for v: float in r:
		out.append(_round(v * 1e4) / 1e4 + 0.0)
	return out


## [method turn_of] of how [param basis] (the app's axes) turns a part in
## LDraw's: F·B·F with F diag(1, -1, -1), B a row at a time (its element at
## row r, column c is basis[c][r]).
static func turn_of_basis(basis: Basis) -> Variant:
	var nine: Array = []
	for row: int in 3:
		for column: int in 3:
			nine.append(_FLIP[row] * float(basis[column][row]) * _FLIP[column])
	return turn_of(nine)


## Where [param pin] (an answer's pin: {part, colour, at, turn, near, full,
## with}) is among [param bricks] ([{part, colour, at, turn}], a model's
## parts, at in LDraw's coordinates as [x, y, z] or a Vector3, turn
## [method turn_of]'s or none): {index, moved}, or {} for on none.
## web/card.js pinPlace, line for line.
static func place(pin: Variant, bricks: Array) -> Dictionary:
	if not pin is Dictionary:
		return {}
	var said: Dictionary = pin
	var at: PackedFloat64Array = point_of(said.get("at"))
	if at.is_empty():
		return {}
	var kind: String = _kind_of(said)
	var near: Array[PackedFloat64Array] = []
	if said.get("near") is Array:
		for p: Variant in said["near"]:
			if p is Array and (p as Array).size() == 3:
				near.append(_loose(p))
	# Others of its kind where it stood: then only its turn tells it apart.
	var twins: bool = false
	for p: PackedFloat64Array in near:
		twins = twins or _apart(p, at) <= SLACK
	var turn: Variant = said["turn"] if said.get("turn") is Array and (said["turn"] as Array).size() == 9 \
		else null
	var beside: Dictionary = {}
	if said.get("with") is Array:
		for one: Variant in said["with"]:
			var pair: Array = []
			if one is Array:
				pair = one
			elif one is String:
				for k: int in mini((one as String).length(), 2):
					pair.append((one as String)[k])
			beside[_kind(pair[0] if pair.size() > 0 else null,
				_number(pair[1]) if pair.size() > 1 else NAN)] = true
	var stand: Array[PackedFloat64Array] = []
	var kept: int = -1
	var kept_off: float = INF
	var other: bool = false
	var same: Array[int] = []
	for i: int in bricks.size():
		var one: Variant = bricks[i]
		var where_one: PackedFloat64Array = PackedFloat64Array()
		if one is Dictionary:
			where_one = point_of((one as Dictionary)["at"]) if (one as Dictionary).get("at") is Vector3 \
				else _loose((one as Dictionary).get("at"))
		stand.append(where_one)
		if where_one.is_empty():
			continue
		var off: float = _apart(where_one, at)
		var theirs: String = _kind_of(one as Dictionary)
		var alike: bool = theirs == kind
		if off <= SLACK:
			if not alike:
				if not beside.has(theirs):
					other = true
			elif (not twins or _same_turn(turn, (one as Dictionary).get("turn"))) and off < kept_off:
				kept = i
				kept_off = off
		if alike and off <= NEAR + SLACK:
			same.append(i)
	if kept >= 0:
		return {"index": kept, "moved": false}
	var full: Variant = said.get("full")
	if other or twins or (full is bool and full == false):
		return {}
	for p: PackedFloat64Array in near:
		var still: bool = false
		for i: int in same:
			if _apart(stand[i], p) <= SLACK:
				still = true
				break
		if not still:
			return {}
	var moved: Array[int] = []
	for i: int in same:
		var off: float = _apart(stand[i], at)
		if not (off > SLACK and off <= REACH):
			continue
		var was_another: bool = false
		for p: PackedFloat64Array in near:
			if _apart(stand[i], p) <= SLACK:
				was_another = true
				break
		if not was_another:
			moved.append(i)
	return {"index": moved[0], "moved": true} if moved.size() == 1 else {}


## A model's parts as the rule reads them: [{id, part, colour, at, turn}],
## at [x, y, z] where each stands in the file's coordinates: where it stands
## as built (BrickWorld.home_of, a section broken out put back), less
## [param lift], flipped as PinnedComments flips it, to a thousandth of an
## LDU; turn how it is turned there ([method turn_of_basis]). The ground it
## stands on ([param scenery]) is not the model's.
static func bricks_of(world: BrickWorld, lift: Vector3, scenery: Dictionary = {}) -> Array:
	var out: Array = []
	if world == null:
		return out
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var home: Transform3D = world.home_of(brick)
		var at: Vector3 = (home.origin - lift) * LdrModel.FLIP
		out.append({"id": brick.id, "part": brick.part_id, "colour": brick.color_code,
			"at": [snappedf(at.x, 0.001), snappedf(at.y, 0.001), snappedf(at.z, 0.001)],
			"turn": turn_of_basis(home.basis)})
	return out


## A part's name said after "the": "2 × 4 brick" for a plain "Brick 2 x 4",
## else its name as it is, each "x" between two numbers a "×". "" for none.
static func part_said(name: String) -> String:
	var named: String = RegEx.create_from_string("\\s+").sub(name.strip_edges(), " ", true)
	var times := RegEx.create_from_string("(\\d)\\s*[xX]\\s*(?=\\d)")
	named = times.sub(named, "$1 × ", true)
	var plain := RegEx.create_from_string(
		"(?i)^(brick|plate|tile|slope|panel|wedge plate|round brick|round plate|round tile)\\s+(\\d+(?: × \\d+){1,2})$")
	var found: RegExMatch = plain.search(named)
	if found != null:
		return "%s %s" % [found.get_string(2), found.get_string(1).to_lower()]
	return named


## Where a pinned comment is, in words: "on the 2 × 4 brick, step 12", "on
## the 2 × 4 brick", "on a part, step 12" or "on a part", [param name] the
## part's name as the catalogue has it ("" while it is not known).
static func said(name: String, step: int) -> String:
	var part: String = part_said(name)
	if not part.is_empty() and step > 0:
		return "on the %s, step %d" % [part, step]
	if not part.is_empty():
		return "on the %s" % part
	return "on a part, step %d" % step if step > 0 else "on a part"


## A pinned comment's line where it is shown: on its part ([param placed],
## place's answer), moved since or not, or, on none here, on its version.
static func where(name: String, step: int, placed: Dictionary, version: int) -> String:
	if placed.is_empty():
		return "on version %d" % maxi(version, 1)
	return said(name, step) + (", moved since" if bool(placed.get("moved", false)) else "")
