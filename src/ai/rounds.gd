## A body of revolution, laid the way real sets lay one: a rocket stage, a
## lighthouse, a silo, a column, a tree trunk, a boiler, a fuselage, a
## submarine's hull — upright or lying along x or z.
##
## Every round thing built here before this was square. The owner asked
## for a Falcon Heavy and got four thousand bricks in square columns with
## polka dots on, and called it "the ugliest most retarded version";
## measured, 67% plain bricks and 9% curved against real space sets' 27%
## and 17%. LEGO never builds round that way. Its round things are round
## parts on one axis:
##
##   City rockets (60228, 60351)   cylinder halves 2 x 4 x 5 and 2 x 4 x 2,
##                                  4 x 4 round plates, 1 x 1 cones
##   Saturn V (21309)              curved bricks on studs turned out, 4 x 4
##                                  quarter-cylinder panels, cones, a fin
##                                  on a Technic pin
##   Artemis SLS (10341)           curved slopes, grille bricks, Technic
##                                  pin connectors joining the boosters
##
## and a round of each size has its parts: a 1 x 1 or 2 x 2 round brick, a
## 4 x 4 round brick or two cylinder halves, four 3 x 3 or 4 x 4 corner
## rounds round a ring tied by a round plate. Said by hand that is a part
## number and a quarter turn a piece, and the turn of a corner round is
## the thing nobody gets right (the worked example for a round tower had
## two of its four the wrong way and built a bow tie). So a design says
## the diameter and what goes up the axis, and this lays the parts:
##
##   {"pattern": "round", "at": {"x": 10, "y": 0, "z": 10}, "diameter": 4,
##    "color": 15, "stack": [
##       {"cones": 9, "color": 0},              a ring of cones under a plate
##       {"technic": true, "struts": 2},        pin holes out; beams pinned on
##       {"plates": 60},                        the body
##       {"plates": 9, "color": 0, "spokes": 4},  a band; tiles reach out
##       {"diameter": 6, "plates": 18},          wider
##       {"nose": "ogive"}]}                    and its top
##
## Each entry goes on the last, square on the same axis, so a stack is one
## piece. "axis": "x" or "z" lays the same stack on its side; "beside"
## stands more of them round it, pinned where their Technic courses meet.
## None of it knows what a rocket is: the same calls are a lighthouse's
## tower and gallery, a locomotive's boiler, a tree trunk.
class_name Rounds
extends RefCounted

## The diameters real round parts come in, in studs.
const DIAMETERS: Array[int] = [1, 2, 4, 6, 8]

## For each diameter, what a set lays a round of it in.
##
##   course   one brick tall, the whole round in one part
##   quarter  a corner round; four of them make a course, round a ring
##   plate    one plate tall, the whole round: a band, and the tie that
##            makes four quarters or two halves one piece
##   halves   a cylinder half and how many plates tall; two, back to
##            back, are a round with one seam down it
##   panel    a quarter-cylinder panel and how many plates tall
##
## Measured over set inventories since 2015: 87081 is in 388 sets (91 of
## them white), 85941 in 99 (30 white), 5152 in 36, 48092 in 352 (102
## white), 60474 in 1,402, 11213 in 621, 74611 in 90.
const PARTS: Dictionary = {
	1: {"course": "3062b", "plate": "6141", "tile": "98138"},
	2: {"course": "3941", "plate": "4032a", "tile": "14769"},
	4: {"course": "87081", "also": "6222", "plate": "60474",
		"halves": [["85941", 15], ["24593", 6]]},
	6: {"quarter": "5152", "plate": "11213"},
	8: {"quarter": "48092", "plate": "74611", "panel": ["30562", 18]},
}

## A ring of quarters is tied by a round plate at least this often, in
## courses: four corner rounds stacked on four corner rounds are four
## columns standing side by side, and they come apart.
const TIE_EVERY := 2

## The cones of a ring under a round plate: a 1 x 1 cone round the edge
## and a 2 x 2 truncated one in the middle. Wide end down, the shape of a
## bell, a nozzle, a lamp shade, a foot.
const CONE := "59900"
const WIDE_CONE := "98100"

## The ring of eight cones round a 2 x 2 middle, as cells of a 4 x 4: the
## edge of a 4 x 4 round with its corners off is an octagon of eight cells.
const RING: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 1),
	Vector2i(3, 2), Vector2i(2, 3), Vector2i(1, 3), Vector2i(0, 2), Vector2i(0, 1)]

## What a spoke carries unless told: a grille tile.
const GRILLE := "2412b"

## Which quarter turn puts a corner round's curve outward in each quarter
## of a ring — low x low z, high x low z, high x high z, low x high z — and
## which turns put a cylinder half's curve to -z and to +z. Measured off
## the parts' covers (patterns_probe asserts these against the meshes for
## 48092, 5152, 30562, 85941 and 24593), and written here because a
## browser lays a pattern before it has fetched the parts.
const QUARTER_TURNS: Array[int] = [2, 1, 0, 3]
const HALF_TURNS: Array[int] = [2, 0]

## The Technic beam a strut is, by how many holes long.
const BEAMS: Dictionary = {5: "32316", 7: "32524", 9: "40490", 11: "32525"}

## Words a design reaches for, said the way this file says them. The
## technique is general and the subject is the design's: a rocket's
## engines are cones, its landing legs struts, its grid fins spokes and
## its boosters what stands beside.
const SAID: Dictionary = {"engines": "cones", "bells": "cone_color",
	"legs": "struts", "leg_color": "strut_color", "grid_fins": "spokes",
	"fins": "spokes", "fin_color": "tile_color", "boosters": "beside",
	"cap": "nose", "top": "nose", "colour": "color"}


## Every part of a round body, or a reason in [param trouble].
##
## With "beside" it is a body and the bodies round it in one call, each
## touching it and pinned to it where their Technic courses meet, a
## friction pin across the joint: how Artemis's boosters go on its core
## (10341 carries 114 friction pins and 108 pin connectors), and how two
## or four of anything round stand as one model rather than several.
static func lay(raw: Dictionary, trouble: Array, library: PartLibrary) -> Array:
	_parts = library
	var pattern: Dictionary = _plain(raw)
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var base: int = int(round(float(pattern.get("diameter", 4))))
	if not base in DIAMETERS:
		trouble.append(_sizes_said(base))
		return []
	var colour: int = int(pattern.get("color", 15))
	var axis: String = str(pattern.get("axis", "y")).to_lower()
	if not axis in ["x", "y", "z"]:
		trouble.append("a round's axis is y (upright, the default), x or z (lying "
			+ "along it)")
		return []
	var stack: Array = pattern.get("stack", [])
	if stack.is_empty():
		stack = [{"plates": float(pattern.get("plates", pattern.get("length", 12)))}]
	# Laid upright about the axis at nought, and turned onto its side after
	# if it lies along x or z; upright, laid where it stands.
	var centre := Vector2.ZERO
	var y: float = 0.0
	if axis == "y":
		centre = Vector2(float(at.get("x", 0.0)) + base / 2.0,
			float(at.get("z", 0.0)) + base / 2.0)
		y = float(at.get("y", 0.0))

	var beside: Dictionary = {}
	if pattern.get("beside") is Dictionary:
		beside = pattern["beside"]
	var count: int = int(beside.get("count", 0 if beside.is_empty() else 2))
	if count != 0 and not count in [1, 2, 4]:
		trouble.append("beside takes one, two or four: two either side, four round")
		return []
	# Lying along x, what stands beside it stands beside it, not on it.
	var order: Array = SIDES if axis != "x" else [Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 0), Vector2i(-1, 0)]
	var sides: Array = order.slice(0, count)
	var made: Array = []
	var tops: Dictionary = {}
	var outer: Array = []
	for raw_side: Variant in sides:
		var side: Vector2i = raw_side
		var size: int = int(round(float(beside.get("diameter", base))))
		if not size in DIAMETERS or size == 1 or size % 2 != base % 2:
			trouble.append("what stands beside is %s studs across? 2, 4, 6 or 8, "
				% str(beside.get("diameter")) + "even like the body it stands by")
			return []
		var middle: Vector2 = centre + Vector2(side) * float(base + size) / 2.0
		var own: Array = beside.get("stack", stack)
		var laid: Dictionary = _stack(own, middle, y, size,
			int(beside.get("color", colour)), [-side], {}, trouble)
		if not trouble.is_empty():
			return []
		made.append_array(laid["made"])
		tops[side] = laid["top"]
		outer.append([side, laid["holes"]])
	var core: Dictionary = _stack(stack, centre, y, base, colour, sides, tops, trouble)
	if not trouble.is_empty():
		return []
	made.append_array(core["made"])
	# A friction pin across each joint, where two Technic courses meet,
	# half in each brick's hole.
	var holes: Dictionary = core["holes"]
	for pair: Array in outer:
		var side: Vector2i = pair[0]
		var theirs: Dictionary = pair[1]
		if not holes.has(side) or not theirs.has(-side):
			continue
		for one: Vector3 in holes[side]:
			for two: Vector3 in theirs[-side]:
				if is_equal_approx(one.y, two.y):
					_pin(made, (one + two) / 2.0, side)
	if made.size() > Patterns.MOST:
		trouble.append("that round would be %d parts, which is a mistake "
			% made.size() + "in the numbers rather than a body")
		return []
	if axis != "y":
		made = _on_its_side(made, axis, at, base, library)
	return made


## A pattern with every word said this file's way, its stack and what
## stands beside it too.
static func _plain(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in raw:
		var named: String = str(SAID.get(str(key), str(key)))
		var value: Variant = raw[key]
		if value is Dictionary:
			value = _plain(value)
		elif value is Array:
			var listed: Array = []
			for one: Variant in value:
				listed.append(_plain(one) if one is Dictionary else one)
			value = listed
		out[named] = value
	return out


## The four sides something can stand on, in the order they are taken:
## two go either side along x, four go round.
const SIDES: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
	Vector2i(0, -1)]
## And the order struts take the sides left free: front and back first,
## where a model is looked at.
const STRUT_SIDES: Array = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0),
	Vector2i(-1, 0)]


## One stack, bottom up, on one axis. [param joined] are the sides
## something stands beside it, pinned, where no strut goes; [param tops]
## how high each reaches. Answers its parts, where its top is, and the pin
## holes its Technic course offers by side, in LDU.
static func _stack(stack: Array, centre: Vector2, y: float, base: int, colour: int,
		joined: Array, tops: Dictionary, trouble: Array) -> Dictionary:
	var made: Array = []
	var holes: Dictionary = {}
	var state := {"d": base, "below": "", "last_d": base}
	var ended: bool = false
	for raw: Variant in stack:
		if typeof(raw) != TYPE_DICTIONARY:
			trouble.append("each entry of a round's stack is an object: "
				+ "{\"plates\": 30}, {\"cones\": 9}, {\"nose\": \"cone\"}")
			break
		var entry: Dictionary = raw
		if ended:
			trouble.append("a round's nose is the top of it — nothing goes "
				+ "on it in the same stack. Start another round there")
			break
		var tone: int = int(entry.get("color", colour))
		if entry.has("diameter"):
			var wanted: int = int(round(float(entry["diameter"])))
			if not wanted in DIAMETERS:
				trouble.append(_sizes_said(wanted))
				break
			if wanted % 2 != int(state["d"]) % 2 and wanted != 1 and int(state["d"]) != 1:
				trouble.append("a round keeps its axis: diameters in one stack "
					+ "are all even, so each stays centred on the last")
				break
			state["d"] = wanted
		var d: int = int(state["d"])
		var known: bool = false
		if entry.has("cones"):
			known = true
			y = _cones(made, centre, y, d, int(entry["cones"]), tone,
				int(entry.get("cone_color", 72)))
			state["below"] = "plate"
		var struts: int = clampi(int(entry.get("struts", 0)), 0, 4)
		if bool(entry.get("technic", false)) or struts > 0:
			known = true
			if d < 4:
				trouble.append("a Technic course needs a round 4 studs across or more, "
					+ "to have a brick at each side")
				break
			var course: Dictionary = _technic(made, centre, y, d, tone)
			# Every course's holes, side by side: a body beside is pinned at
			# each height both stacks have one, top and bottom like a real
			# booster's attach points.
			for side: Variant in course:
				if not holes.has(side):
					holes[side] = []
				(holes[side] as Array).append(course[side])
			var free: Array[Vector2i] = []
			for side: Vector2i in STRUT_SIDES:
				if not joined.has(side):
					free.append(side)
			for n: int in mini(struts, free.size()):
				_strut(made, course[free[n]], free[n],
					int(entry.get("strut_length", {4: 7, 6: 9, 8: 11}[d])),
					int(entry.get("strut_color", 0)))
			y += 3.0
			state["below"] = "course"
		if entry.has("nose"):
			known = true
			y = _nose(made, centre, y, d, str(entry["nose"]).to_lower(), tone, trouble,
				str(state["below"]))
			ended = true
		elif entry.has("plates") or entry.has("length"):
			known = true
			var plates: int = int(round(float(entry.get("plates", entry.get("length", 0)))))
			if plates < 1:
				trouble.append("a round's body entry wants plates: how tall, in plates")
				break
			var spokes: int = int(entry.get("spokes", 0))
			var body: int = plates - (1 if spokes > 0 else 0)
			if body > 0:
				y = _body(made, centre, y, d, body, tone, state)
			if spokes > 0:
				# Not on a side something still stands beside at this
				# height, and never towards the body this one stands by.
				var clear: Array[Vector2i] = []
				for side: Vector2i in SIDES:
					var by: bool = joined.has(side) and (not tops.has(side)
						or float(tops[side]) > y)
					if not by and (spokes == 4 or side.x != 0):
						clear.append(side)
				# A part number, or the grille: a design that said "tile": true
				# was asking for the default and got a part called "true".
				var tile: String = GRILLE
				if entry.get("tile") is String and not str(entry["tile"]).is_empty():
					tile = str(entry["tile"])
				y = _spokes(made, centre, y, d, tone, tile,
					int(entry.get("tile_color", 72)), clear)
				state["below"] = "plate"
		if not known:
			trouble.append("a round's stack entry says plates (a length of body), "
				+ "cones, technic, or nose — %s says none of them" % JSON.stringify(entry))
			break
	return {"made": made, "top": y, "holes": holes}


static func _sizes_said(asked: int) -> String:
	return ("a round is %d studs across? Round parts come in 1, 2, 4, 6 and 8 "
		% asked + "studs across — a 1 x 1 or 2 x 2 round brick, a 4 x 4 round "
		+ "brick or two cylinder halves, and four 3 x 3 or 4 x 4 corner rounds. "
		+ "Pick the nearest")


## The low corner of a round of [param d] studs on the axis.
static func _corner(centre: Vector2, d: int) -> Vector2:
	return centre - Vector2(d, d) / 2.0


## A length of body: the longest pieces that fit, tied into one.
static func _body(made: Array, centre: Vector2, y: float, d: int, plates: int,
		colour: int, state: Dictionary) -> float:
	var parts: Dictionary = PARTS[d]
	var low: Vector2 = _corner(centre, d)
	var left: int = plates
	var below: String = str(state["below"])
	# Wider than what it stands on: the round plate first, because a ring
	# of quarters or two halves over a narrower top has nothing under its
	# rim. And a ring always starts and ends on its plate.
	var widened: bool = int(state["last_d"]) < d
	if parts.has("quarter") and below != "plate" or widened:
		made.append(_part(str(parts["plate"]), colour, low, y))
		y += 1.0
		left -= 1
		below = "plate"
	while left > 0:
		if parts.has("halves"):
			var laid: bool = false
			for pair: Array in parts["halves"]:
				var tall: int = int(pair[1])
				# Halves stacked on halves are two columns; a plate between
				# makes the pair one piece, and costs a plate. So do halves
				# on a Technic course: their hollow is over the course's
				# middle brick, which stood loose under it, held by nothing
				# (85941's cover was its box and hid it).
				var tie: int = 1 if below == "halves" or below == "course" else 0
				if left >= tall + tie and _made_in(str(pair[0]), colour):
					if tie > 0:
						made.append(_part(str(parts["plate"]), colour, low, y))
						y += 1.0
						left -= 1
					made.append(_part(str(pair[0]), colour, low, y, HALF_TURNS[0]))
					made.append(_part(str(pair[0]), colour, low + Vector2(0, 2), y,
						HALF_TURNS[1]))
					y += float(tall)
					left -= tall
					below = "halves"
					laid = true
					break
			if laid:
				continue
		if parts.has("panel") and left >= int(parts["panel"][1]) + 1 \
				and _made_in(str(parts["panel"][0]), colour):
			_quarters(made, str(parts["panel"][0]), colour, low, d, y)
			y += float(parts["panel"][1])
			left -= int(parts["panel"][1])
			made.append(_part(str(parts["plate"]), colour, low, y))
			y += 1.0
			left -= 1
			below = "plate"
			continue
		if parts.has("quarter") and left >= 4 and _made_in(str(parts["quarter"]), colour):
			# Courses of quarters, a plate over every TIE_EVERY of them,
			# and always a plate on top.
			var courses: int = mini(TIE_EVERY, (left - 1) / 3)
			for _n: int in courses:
				_quarters(made, str(parts["quarter"]), colour, low, d, y)
				y += 3.0
				left -= 3
			made.append(_part(str(parts["plate"]), colour, low, y))
			y += 1.0
			left -= 1
			below = "plate"
			continue
		if parts.has("course") and left >= 3:
			var course: String = str(parts["course"])
			if not _made_in(course, colour) and parts.has("also") \
					and _made_in(str(parts["also"]), colour):
				course = str(parts["also"])
			made.append(_part(course, colour, low, y))
			y += 3.0
			left -= 3
			below = "course"
			continue
		made.append(_part(str(parts["plate"]), colour, low, y))
		y += 1.0
		left -= 1
		below = "plate"
	state["below"] = below
	state["last_d"] = d
	return y


static func _part(part: String, colour: int, low: Vector2, y: float,
		rot: int = 0) -> Dictionary:
	return {"part": part, "color": colour, "x": low.x, "y": y, "z": low.y,
		"rot": rot}


## Four corner rounds round a ring, each turned to face out.
static func _quarters(made: Array, part: String, colour: int, low: Vector2,
		d: int, y: float) -> void:
	var half: float = d / 2.0
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(half, 0),
		Vector2(half, half), Vector2(0, half)]
	for n: int in 4:
		made.append(_part(part, colour, low + corners[n], y, QUARTER_TURNS[n]))


## A ring of cones under a round plate, or one: engine bells, nozzles,
## lamps under a shade. They stand at [param y] on whatever is below, or on
## nothing, held by their studs in the plate, and the plate goes on them.
static func _cones(made: Array, centre: Vector2, y: float, d: int, count: int,
		plate_colour: int, cone_colour: int) -> float:
	var low: Vector2 = _corner(centre, d)
	var tone: int = cone_colour if _made_in(CONE, cone_colour) else 0
	var wide: int = cone_colour if _made_in(WIDE_CONE, cone_colour) else 0
	if d == 1:
		made.append(_part(CONE, tone, low, y))
	elif d == 2 or count == 1:
		made.append(_part(WIDE_CONE, wide, centre - Vector2(1, 1), y))
	else:
		var off: Vector2 = centre - Vector2(2, 2)
		for cell: Vector2i in RING:
			made.append(_part(CONE, tone, off + Vector2(cell), y))
		made.append(_part(WIDE_CONE, wide, centre - Vector2(1, 1), y))
	made.append(_part(str(PARTS[d]["plate"]), plate_colour, low, y + 3.0))
	return y + 4.0


## One plate of body that reaches a stud out on up to four sides, a tile
## on each reach: grid fins (grille tiles), a gallery's brackets, a ship's
## yard stubs, the rungs of a ladder up a silo. The plates are the body's
## colour; the round above stands on them as it would on a round plate.
static func _spokes(made: Array, centre: Vector2, y: float, d: int,
		body_colour: int, tile: String, tile_colour: int, sides: Array[Vector2i]) -> float:
	var c := Vector2i(int(floor(centre.x)), int(floor(centre.y)))
	var half: int = maxi(d / 2, 1)
	if d == 1:
		# A 1 x 1 round has no room to reach from.
		made.append(_part(str(PARTS[1]["plate"]), body_colour, _corner(centre, d), y))
		return y + 1.0
	# A bar two studs wide right across, reaching a stud past each side
	# that has a spoke, and an arm along z from each side of it, a stud past
	# the round where that side has one.
	var west: int = 1 if sides.has(Vector2i(-1, 0)) else 0
	var east: int = 1 if sides.has(Vector2i(1, 0)) else 0
	var long: int = d + west + east
	if BARS.has(long):
		made.append(_bar(long, body_colour, c.x - half - west, y, c.y - 1))
	else:
		# No plate is two by five, seven or nine: two plates, the one on the
		# reaching side standing a stud on the round and a stud past it.
		var near: int = {2: 1, 4: 3, 6: 4, 8: 6}[d]
		var far: int = long - near
		var from: int = c.x - half - west
		var first: int = far if west > 0 else near
		made.append(_bar(first, body_colour, from, y, c.y - 1))
		made.append(_bar(long - first, body_colour, from + first, y, c.y - 1))
	if west > 0:
		made.append({"part": tile, "color": tile_colour, "x": c.x - half - 1,
			"y": y + 1.0, "z": c.y - 1, "rot": 1})
	if east > 0:
		made.append({"part": tile, "color": tile_colour, "x": c.x + half,
			"y": y + 1.0, "z": c.y - 1, "rot": 1})
	# A 2 x 2 round is all bar: an arm across z would be all overhang, held
	# by nothing, so it has the two the bar carries.
	if half < 2:
		return y + 1.0
	var arms: Dictionary = {1: "3023b", 2: "3022", 3: "3021", 4: "3020"}
	for side: int in [-1, 1]:
		var reach: int = 1 if sides.has(Vector2i(0, side)) else 0
		var long_z: int = half - 1 + reach
		if long_z < 1:
			continue
		var z0: int = c.y - half - reach if side < 0 else c.y + 1
		made.append({"part": arms[long_z], "color": body_colour, "x": c.x - 1,
			"y": y, "z": z0, "rot": 1 if long_z > 2 else 0})
		if reach > 0:
			made.append({"part": tile, "color": tile_colour, "x": c.x - 1,
				"y": y + 1.0, "z": c.y - half - 1 if side < 0 else c.y + half,
				"rot": 0})
	return y + 1.0


## Plates two studs deep, by how long along x: what a spokes layer's bar is
## laid in.
const BARS: Dictionary = {1: "3023b", 2: "3022", 3: "3021", 4: "3020", 6: "3795",
	8: "3034", 10: "3832"}


## A plate two deep and [param long] along x, its low corner at x, z.
static func _bar(long: int, colour: int, x: int, y: float, z: int) -> Dictionary:
	# A 1 x 2 plate lies along x unturned, so turned it is two deep.
	return {"part": BARS[long], "color": colour, "x": x, "y": y, "z": z,
		"rot": 1 if long == 1 else 0}


## One course of bricks the shape of the round, with a Technic brick at
## the middle of each side whose hole runs out through that side: where a
## strut is pinned and what stands beside is joined. Answers each side's
## hole, its middle in LDU.
static func _technic(made: Array, centre: Vector2, y: float, d: int,
		colour: int) -> Dictionary:
	var low: Vector2 = _corner(centre, d)
	var holes: Dictionary = {}
	var c: float = d / 2.0
	var height: float = y * 8.0 + 14.0
	# A Technic brick 1 x 2's hole runs across it: along z laid along x
	# (rot 0), along x laid along z (rot 1); fourteen LDU up, measured.
	for side: Vector2i in SIDES:
		if side.x != 0:
			var x: float = low.x + (d - 1 if side.x > 0 else 0)
			made.append({"part": "3700", "color": colour, "x": x, "y": y,
				"z": low.y + c - 1, "rot": 1})
			holes[side] = Vector3((x + 0.5) * 20.0, height, (low.y + c) * 20.0)
		else:
			var z: float = low.y + (d - 1 if side.y > 0 else 0)
			made.append({"part": "3700", "color": colour, "x": low.x + c - 1, "y": y,
				"z": z, "rot": 0})
			holes[side] = Vector3((low.x + c) * 20.0, height, (z + 0.5) * 20.0)
	# The middle between them, so the round above stands on a whole course.
	var fill: Dictionary = {4: [["3003", 2]], 6: [["3001", 2], ["3001", 2]],
		8: [["2456", 2], ["2456", 2], ["2456", 2]]}
	var row: float = 1.0
	for one: Array in fill[d]:
		made.append({"part": str(one[0]), "color": colour, "x": low.x + 1.0,
			"y": y, "z": low.y + row, "rot": 0})
		row += float(one[1])
	return holes


## A strut: a Technic beam standing against the side of the body, pinned
## at its foot into the Technic course's hole on that side — a landing
## leg folded, a stay, a ladder rail.
static func _strut(made: Array, hole: Vector3, side: Vector2i, holes: int,
		colour: int) -> void:
	var out := Vector3(side.x, 0, side.y)
	_pin(made, hole + out * 10.0, side)
	var beam: String = str(BEAMS.get(holes, "32524"))
	holes = int(BEAMS.find_key(beam))
	# Its holes run the way the pin does, its length straight up.
	var turn: Array = _orient(Vector3.UP, out.abs(), Vector3.BACK, Vector3.UP)
	var cover: AABB = _cover(null, beam)
	# Its bottom hole on the pin's outer half: the beam's middle a stud out
	# from the brick's hole, and (holes - 1) half-studs up.
	var middle: Vector3 = hole + out * 20.0 + Vector3(0, (holes - 1) * 10.0, 0)
	made.append(_placed(cover, beam, colour, str(turn[0]), int(turn[1]), middle))


## A friction pin centred at [param middle], running along [param side].
static func _pin(made: Array, middle: Vector3, side: Vector2i) -> void:
	var along_x: bool = side.x != 0
	made.append({"part": "2780", "color": 0,
		"x": (middle.x - (20.0 if along_x else 8.0)) / 20.0,
		"y": (middle.y - 8.0) / 8.0,
		"z": (middle.z - (8.0 if along_x else 20.0)) / 20.0,
		"rot": 0 if along_x else 1})


## The face and quarter turn that carry a part's [param local_a] to
## [param world_a] (either way along it) and [param local_b] to
## [param world_b], or [] if none does.
static func _orient(local_a: Vector3, world_a: Vector3, local_b: Vector3,
		world_b: Vector3) -> Array:
	for face: String in ["up", "down", "+x", "-x", "+z", "-z"]:
		for rot: int in 4:
			var basis: Basis = BrickLattice.basis_for(face, rot)
			if absf((basis * local_a).dot(world_a)) > 0.99 \
					and (basis * local_b).dot(world_b) > 0.99:
				return [face, rot]
	return []


## A placement for a part turned by a face and a quarter turn whose own
## origin lands at [param origin] (LDU): named by the low corner of its
## turned cover, [param cover] in its own LDU, as the app names a part.
static func _placed(cover: AABB, part: String, colour: int, face: String,
		rot: int, origin: Vector3) -> Dictionary:
	var corner: Vector3 = origin + _low(BrickLattice.basis_for(face, rot), cover)
	return {"part": part, "color": colour, "x": snappedf(corner.x / 20.0, 0.001),
		"y": snappedf(corner.y / 8.0, 0.001), "z": snappedf(corner.z / 20.0, 0.001),
		"face": face, "rot": rot}


## The low corner of a box turned by a basis.
static func _low(basis: Basis, box: AABB) -> Vector3:
	var a: Vector3 = basis * box.position
	var b: Vector3 = basis * box.end
	return a.min(b)


## What a part's cover is in its own LDU: a Technic beam's worked out (a
## stud thick and wide, two LDU short of its ends), else its collision
## boxes where its geometry is to hand, else its catalogue bounds,
## cell-rounded and with the studs off the top. Close enough to name a
## corner by, which is all it is asked; a browser lays a pattern before it
## fetches the parts.
static func _cover(library: PartLibrary, part: String) -> AABB:
	var holes: Variant = BEAMS.find_key(part)
	if holes != null:
		var half: float = int(holes) * 10.0 - 2.0
		return AABB(Vector3(-10, -10, -half), Vector3(20, 20, 2.0 * half))
	if library != null:
		var mesh: Lbm.PartMesh = library.mesh_for(part)
		if mesh != null and not mesh.boxes.is_empty():
			var lo := Vector3(INF, INF, INF)
			var hi := -lo
			for box: AABB in mesh.boxes:
				lo = lo.min(box.position)
				hi = hi.max(box.end)
			return AABB(lo * mesh.cell_ldu, (hi - lo) * mesh.cell_ldu)
	var info: PartLibrary.PartInfo = library.parts.get(part) if library != null else null
	if info == null:
		return AABB()
	var lo: Vector3 = (info.bounds.position / 2.0).round() * 2.0
	var hi: Vector3 = (info.bounds.end / 2.0).round() * 2.0
	hi.y = minf(hi.y, 0.0)
	return AABB(lo, hi - lo)


## The same parts lying along x or z: each part's transform turned about
## the axis's foot by the quarter turn that takes up to x (or z), and named
## again. Lying on the ground at [param at], the axis [param base] / 2
## studs up and in.
static func _on_its_side(made: Array, axis: String, at: Dictionary, base: int,
		library: PartLibrary) -> Array:
	var turn: Basis
	var foot: Vector3
	var reach: float = base * 10.0
	if axis == "x":
		turn = Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
		foot = Vector3(float(at.get("x", 0.0)) * 20.0, float(at.get("y", 0.0)) * 8.0
			+ reach, float(at.get("z", 0.0)) * 20.0 + reach)
	else:
		turn = Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
		foot = Vector3(float(at.get("x", 0.0)) * 20.0 + reach,
			float(at.get("y", 0.0)) * 8.0 + reach, float(at.get("z", 0.0)) * 20.0)
	var out: Array = []
	for raw: Variant in made:
		var one: Dictionary = raw
		var part: String = str(one["part"])
		var cover: AABB = _cover(library, part)
		var face: String = str(one.get("face", "up"))
		var basis: Basis = BrickLattice.basis_for(face, int(one.get("rot", 0)))
		var corner := Vector3(float(one["x"]) * 20.0, float(one["y"]) * 8.0,
			float(one["z"]) * 20.0)
		var origin: Vector3 = corner - _low(basis, cover)
		var turned: Basis = turn * basis
		var named: Array = _named(turned)
		if named.is_empty():
			continue
		out.append(_placed(cover, part, int(one["color"]), str(named[0]),
			int(named[1]), foot + turn * origin))
	return out


## The face and quarter turn an orientation is, or [].
static func _named(basis: Basis) -> Array:
	for face: String in ["up", "down", "+x", "-x", "+z", "-z"]:
		for rot: int in 4:
			if BrickLattice.basis_for(face, rot).is_equal_approx(basis):
				return [face, rot]
	return []


## The 2 x 2 round plates a 6 x 6 and an 8 x 8 dish stand on, by width: each
## is hollow out to its rim, its anti-studs a plate and two plates above it
## (Shells.CROWNS), so laid straight on the round its rim sits on the studs and
## nothing joins it. It came away in the hand, a piece of its own in BrickNet's
## graph, and the check passed it until 2026-10-23.
const DISH_RISE: Dictionary = {6: 1, 8: 2}


static func _under_dish(made: Array, colour: int, two: Vector2, y: float, d: int) -> void:
	for k: int in int(DISH_RISE.get(d, 0)):
		made.append(_part("4032a", colour, two, y + k))


## The top of a round: a cone, an ogive (a dome and then a cone, as a
## fairing narrows), a dome, a flat round tile, or a point.
static func _nose(made: Array, centre: Vector2, y: float, d: int, shape: String,
		colour: int, trouble: Array, below: String = "") -> float:
	var low: Vector2 = _corner(centre, d)
	var two: Vector2 = centre - Vector2(1, 1)
	var one: Vector2 = centre - Vector2(0.5, 0.5)
	# A 4 x 4 dish stands on a 2 x 2 round's four studs; two halves have none
	# in the middle, so their round plate goes first.
	if d == 4 and below == "halves" and shape in ["ogive", "dome"]:
		made.append(_part(str(PARTS[4]["plate"]), colour, low, y))
		y += 1.0
	match shape:
		"cone", "point":
			match d:
				1:
					made.append(_part(CONE, colour, low, y))
					y += 3.0
				2:
					made.append(_part("3942c", colour, low, y))
					y += 6.0
				4:
					made.append(_part("3943b", colour, low, y))
					made.append(_part("3942c", colour, two, y + 6.0))
					y += 12.0
				6:
					_under_dish(made, colour, two, y, d)
					made.append(_part("44375b", colour, low, y))
					made.append(_part("3942c", colour, two, y + 2.0))
					y += 8.0
				8:
					_under_dish(made, colour, two, y, d)
					made.append(_part("3961", colour, low, y))
					made.append(_part("3943b", colour, centre - Vector2(2, 2), y + 3.0))
					made.append(_part("3942c", colour, two, y + 9.0))
					y += 15.0
			if shape == "point" and d > 1:
				made.append(_part(CONE, colour, one, y))
				y += 3.0
		"ogive":
			match d:
				1:
					made.append(_part(CONE, colour, low, y))
					y += 3.0
				2:
					made.append(_part("3942c", colour, low, y))
					y += 6.0
				4:
					# The dish on a 2 x 2 round's four studs, as sets stand it:
					# a 4 x 4 one's under it run into the dish's underside.
					made.append(_part("4032a", colour, two, y))
					made.append(_part("3960", colour, low, y + 1.0))
					made.append(_part("3942c", colour, two, y + 3.0))
					y += 9.0
				6:
					_under_dish(made, colour, two, y, d)
					made.append(_part("44375b", colour, low, y))
					made.append(_part("3942c", colour, two, y + 2.0))
					y += 8.0
				8:
					_under_dish(made, colour, two, y, d)
					made.append(_part("3961", colour, low, y))
					made.append(_part("3942c", colour, two, y + 3.0))
					y += 9.0
		"dome":
			# The 2 and 4 wide dishes stand on a stud or four in their middle,
			# their rims clear of the round's other studs, which run into their
			# undersides (by the parts' real shapes, 3 and 2 LDU): the 2 x 2
			# on a jumper's one stud, the 4 x 4 on a 2 x 2 round's four.
			if d == 2:
				made.append(_part("87580", colour, low, y))
				y += 1.0
			elif d == 4:
				made.append(_part("4032a", colour, two, y))
				y += 1.0
			_under_dish(made, colour, two, y, d)
			var dish: Dictionary = {1: "6141", 2: "4740", 4: "3960", 6: "44375b", 8: "3961"}
			made.append(_part(str(dish[d]), colour, low, y))
			y += {1: 1.0, 2: 1.0, 4: 2.0, 6: 2.0, 8: 3.0}[d]
		"flat":
			if PARTS[d].has("tile"):
				made.append(_part(str(PARTS[d]["tile"]), colour, low, y))
			else:
				made.append(_part(str(PARTS[d]["plate"]), colour, low, y))
			y += 1.0
		_:
			trouble.append("a round's nose is cone, ogive, dome, point or flat")
	return y


## The library the colour of a part is asked of; set once by whoever lays
## a round, because the parts it asks about are always the same few.
static var _parts: PartLibrary = null


## Whether a part was made in a colour, as far as anybody knows.
static func _made_in(part: String, colour: int) -> bool:
	if _parts == null:
		return true
	var info: PartLibrary.PartInfo = _parts.parts.get(part)
	if info == null:
		return false
	return not info.never_made_in(colour)


## Which way a part's material leans from the middle of its footprint, as
## placed at a quarter turn: by its cover where the cover says, else by its
## tubes and studs (a part whose cover is its whole box says nothing).
## What QUARTER_TURNS and HALF_TURNS were read off, and what the probe
## reads them off again.
static func lean(mesh: Lbm.PartMesh, rot: int) -> Vector2:
	var basis: Basis = BrickLattice.basis_for("up", rot)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var sum := Vector3.ZERO
	var weight: float = 0.0
	for box: AABB in mesh.boxes:
		var a: Vector3 = basis * box.position
		var b: Vector3 = basis * box.end
		lo = lo.min(a.min(b))
		hi = hi.max(a.max(b))
		var volume: float = box.size.x * box.size.y * box.size.z
		sum += basis * box.get_center() * volume
		weight += volume
	var middle: Vector3 = (lo + hi) / 2.0
	var leaning := Vector2.ZERO
	if weight > 0.0:
		var at: Vector3 = sum / weight - middle
		leaning = Vector2(at.x, at.z)
	if absf(leaning.x) < 0.5 and absf(leaning.y) < 0.5:
		var points := Vector3.ZERO
		var count: int = 0
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind in ["stud", "tube"]:
				points += basis * (connector.position / mesh.cell_ldu)
				count += 1
		if count > 0:
			var at: Vector3 = points / count - middle
			leaning = Vector2(at.x, at.z)
	return Vector2(signf(roundf(leaning.x * 10.0)), signf(roundf(leaning.y * 10.0)))
