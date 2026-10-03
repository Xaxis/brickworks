## Saying what a shape is, rather than counting out every brick in it.
##
## A design writes placements one at a time, which is the arithmetic a
## language model is worst at. An ellipse twenty studs across is a
## hundred and fifty plates written by hand; a wall mirrored down the
## middle is every brick said twice and one of them wrong, which is why
## there is a check for exactly that; and four thousand parts cannot be
## said in one reply at all.
##
## None of that is a limit on what can be built. It is a limit on what
## can be *dictated*. So the design says the shape and this works out the
## bricks:
##
##   repeat   the same bricks again, stepped
##   mirror   what is there, reflected — symmetry by construction
##   fill     a footprint, tiled with the largest plates that fit, and
##            with walls, layers and a taper: a dome, a cone, a tube, a
##            hull or a bowl, said in one object
##
## Three verbs, and between them a saucer, a hull, a colonnade and a
## staggered wall stop being arithmetic. The idea is the one behind
## ldraw-nova, which has its agents write generator scripts rather than
## coordinates: the model is good at saying what a thing is and bad at
## counting it out. This does the same without running anybody's code —
## a pattern is data, checked and expanded here, so nothing arrives that
## the app did not make itself.
class_name Patterns
extends RefCounted

## Plates that can tile a footprint, largest first, as [across, deep,
## part, quarter turns]. Only plain plates: a fill is structure, and
## anything with a feature on it is a decision the design should make.
const TILES: Array = [
	[6, 4, "3032", 0], [4, 6, "3032", 1], [4, 4, "3031", 0],
	[6, 2, "3795", 0], [2, 6, "3795", 1], [4, 2, "3020", 0],
	[2, 4, "3020", 1], [3, 2, "3021", 0], [2, 3, "3021", 1],
	[2, 2, "3022", 0], [4, 1, "3710", 0], [1, 4, "3710", 1],
	[3, 1, "3623", 0], [1, 3, "3623", 1], [2, 1, "3023", 0],
	[1, 2, "3023", 1], [1, 1, "3024", 0],
]

## The same, in bricks, for a layer three plates high.
##
## A wall is built of bricks and a floor of plates, and the difference
## is not cosmetic: layers three plates apart tiled in plates leave two
## plates of air between every course, so the second layer floats and
## so does everything above it. The first version of this offered a
## round tower and a hull in the prompt and both came back refused.
##
## Two studs wide before one, at the same area: a course of 1x8s is a
## wall one brick thick with nothing bonding it to the course above.
const COURSES: Array = [
	[10, 2, "3006", 0], [2, 10, "3006", 1],
	[8, 2, "3007", 0], [2, 8, "3007", 1],
	[6, 2, "2456", 0], [2, 6, "2456", 1],
	[4, 2, "3001", 0], [2, 4, "3001", 1],
	[8, 1, "3008", 0], [1, 8, "3008", 1],
	[3, 2, "3002", 0], [2, 3, "3002", 1],
	[6, 1, "3009", 0], [1, 6, "3009", 1],
	[2, 2, "3003", 0],
	[4, 1, "3010", 0], [1, 4, "3010", 1],
	[3, 1, "3622", 0], [1, 3, "3622", 1],
	[2, 1, "3004", 0], [1, 2, "3004", 1],
	[1, 1, "3005", 0],
]

## A pattern that would make more bricks than this is a mistake in the
## numbers, and expanding it would hang the app rather than refuse.
const MOST := 4000


## Every brick the patterns make, or an error in [param trouble].
##
## [param already] is what the design wrote out by hand, because mirror
## works on what is already there.
static func expand(raw_patterns: Array, already: Array,
		trouble: Array, library: PartLibrary = null) -> Array:
	var made: Array = []
	for raw: Variant in raw_patterns:
		if typeof(raw) != TYPE_DICTIONARY:
			trouble.append("a pattern has to be an object")
			continue
		var pattern: Dictionary = raw
		var kind: String = str(pattern.get("pattern", "")).to_lower()
		var from: Array = already + made
		match kind:
			"repeat":
				made.append_array(_repeat(pattern, trouble))
			"mirror":
				made.append_array(_mirror(pattern, from, trouble, library))
			"fill":
				made.append_array(_fill(pattern, trouble))
			_:
				trouble.append("no pattern called \"%s\" — there is "
					% kind + "repeat, mirror and fill")
		if made.size() > MOST:
			trouble.append("that would be %d bricks or more, which is a "
				% made.size() + "mistake in the numbers rather than a model")
			return []
	return made


## The same bricks again, stepped each time.
static func _repeat(pattern: Dictionary, trouble: Array) -> Array:
	var times: int = int(pattern.get("times", 0))
	if times < 1 or times > MOST:
		trouble.append("repeat wants times between 1 and %d" % MOST)
		return []
	var bricks: Array = pattern.get("bricks", [])
	if bricks.is_empty():
		trouble.append("repeat wants the bricks to repeat")
		return []
	var step: Dictionary = pattern.get("step", {}) as Dictionary
	var by := Vector3(float(step.get("x", 0.0)), float(step.get("y", 0.0)),
		float(step.get("z", 0.0)))
	if by == Vector3.ZERO:
		trouble.append("repeat wants a step — otherwise every copy lands "
			+ "on the one before it")
		return []

	var made: Array = []
	for n: int in times:
		for raw: Variant in bricks:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var brick: Dictionary = (raw as Dictionary).duplicate()
			brick["x"] = float(brick.get("x", 0.0)) + by.x * n
			brick["y"] = float(brick.get("y", 0.0)) + by.y * n
			brick["z"] = float(brick.get("z", 0.0)) + by.z * n
			made.append(brick)
	return made


## What is already there, reflected.
##
## The whole point: a wing said once cannot be a stud out on one side,
## and most of what gets built has two sides.
static func _mirror(pattern: Dictionary, already: Array,
		trouble: Array, library: PartLibrary) -> Array:
	var axis: String = str(pattern.get("about", "x")).to_lower()
	if axis != "x" and axis != "z":
		trouble.append("mirror is about x or about z")
		return []
	if not pattern.has("at"):
		trouble.append("mirror wants \"at\", the line to reflect about, "
			+ "in studs")
		return []
	var at: float = float(pattern["at"])
	# Its own bricks if it names any, otherwise everything so far.
	var source: Array = pattern.get("bricks", [])
	if source.is_empty():
		source = already
	if source.is_empty():
		trouble.append("mirror has nothing to reflect")
		return []

	var made: Array = []
	for raw: Variant in source:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var brick: Dictionary = (raw as Dictionary).duplicate()
		# Reflected about the line, and the part's own width taken off.
		#
		# A placement names its low corner, so the mirror of a corner is
		# the *far* corner reflected — which is the near corner of the
		# reflection minus how wide the part is along that axis. Getting
		# this wrong puts a four-stud brick three studs out of place, and
		# it looks like a mirror that nearly worked.
		var width: float = _spans(library, str(brick.get("part", "")),
			int(brick.get("rot", 0)), axis)
		if axis == "x":
			brick["x"] = 2.0 * at - float(brick.get("x", 0.0)) - width
		else:
			brick["z"] = 2.0 * at - float(brick.get("z", 0.0)) - width
		# A left-handed part has a right-handed twin, and reflecting one
		# without swapping them gives two left wings.
		var swap: String = _handed_twin(str(brick.get("part", "")))
		if not swap.is_empty():
			brick["part"] = swap
		made.append(brick)
	return made


## How many studs a part covers along one axis, as placed.
##
## A quarter turn swaps its footprint, which is the whole reason this
## cannot be read off the part alone.
static func _spans(library: PartLibrary, part: String, rot: int,
		axis: String) -> float:
	if library == null:
		return 1.0
	var info: PartLibrary.PartInfo = library.parts.get(part)
	if info == null:
		return 1.0
	var footprint: Vector2i = info.footprint_studs()
	var across: int = footprint.x
	var deep: int = footprint.y
	if rot % 2 == 1:
		var swap: int = across
		across = deep
		deep = swap
	return float(across if axis == "x" else deep)


## The other hand of a part, where it has one.
##
## Wedge plates and wedges come in pairs and a mirror that keeps the same
## number gives a model two left wings — which looks exactly like a model
## with two right wings until somebody looks at it.
const HANDED: Dictionary = {
	"41769b": "41770b", "41770b": "41769b",
	"41769a": "41770a", "41770a": "41769a",
	"43722b": "43723b", "43723b": "43722b",
	"43722a": "43723a", "43723a": "43722a",
	"24307": "24299", "24299": "24307",
	"41767": "41768", "41768": "41767",
	"6564": "6565", "6565": "6564",
	"43710": "43711", "43711": "43710",
	"29120": "29119", "29119": "29120",
}


static func _handed_twin(part: String) -> String:
	return str(HANDED.get(part, ""))


## A footprint, tiled with the largest plates that fit.
##
## A hundred and fifty one-by-ones is not a design decision, it is an
## afternoon. This lays the same area in seventeen plates, which is what
## a person would have reached for.
##
## Three keys turn one footprint into a solid:
##
##   wall     leave the middle out — an ellipse with a wall is a round
##            tower, a rectangle with one is a room
##   layers   the same footprint again, going up
##   shrink   studs off each layer, so the stack tapers
##
## Which is how a saucer section gets said. A dome is layers with a
## positive shrink; a cone is the same with fewer studs to start from; a
## hull is layers with no shrink at all; and a bowl is a wall with
## layers. None of these were sayable before, and each of them is a
## shape a model built here needs and used to write out plate by plate
## until it ran out of reply.
static func _fill(pattern: Dictionary, trouble: Array) -> Array:
	var shape: String = str(pattern.get("shape", "rectangle")).to_lower()
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var low_x: int = int(round(float(at.get("x", 0.0))))
	var low_z: int = int(round(float(at.get("z", 0.0))))
	var y: float = float(at.get("y", 0.0))
	var across: int = int(round(float(pattern.get("across", 0))))
	var deep: int = int(round(float(pattern.get("deep", 0))))
	var colour: int = int(pattern.get("color", pattern.get("colour", 71)))
	var wall: int = int(round(float(pattern.get("wall", 0))))
	var layers: int = int(round(float(pattern.get("layers", 1))))
	# A plate is one high, so that is what a layer steps by unless the
	# design says otherwise — three for courses of bricks.
	var rise: float = float(pattern.get("rise", 1.0))
	var shrink: int = int(round(float(pattern.get("shrink", 0))))

	if across < 1 or deep < 1 or across * deep > MOST:
		trouble.append("fill wants across and deep, both at least 1 and "
			+ "not more than %d studs between them" % MOST)
		return []
	if shape != "rectangle" and shape != "ellipse":
		trouble.append("fill knows rectangle and ellipse. A ring or a "
			+ "tube is an ellipse with a wall; a dome is one with "
			+ "layers and a shrink")
		return []
	if layers < 1 or layers > MOST:
		trouble.append("layers has to be at least 1")
		return []
	if not is_equal_approx(rise, 1.0) and not is_equal_approx(rise, 3.0):
		trouble.append("rise is 1 for layers of plates or 3 for courses "
			+ "of bricks. Anything between leaves air between the "
			+ "layers, and a layer over air is floating")
		return []
	if shrink % 2 != 0:
		# Half a stud off each side is not a position a plate can take,
		# and taking the whole stud off one side walks the stack
		# sideways as it rises — which on a saucer is a lean.
		trouble.append("shrink has to be an even number of studs, so "
			+ "that each layer stays centred over the one below. Use "
			+ "two for a steep taper and four for a steeper one")
		return []

	var made: Array = []
	## What the layer below covers, so that nothing is laid in mid-air.
	var below: Dictionary = {}
	for layer: int in layers:
		var off: int = shrink * layer
		var wide: int = across - off
		var long: int = deep - off
		if wide < 1 or long < 1:
			# The taper has come to a point, which is the top of a cone
			# and not a mistake.
			break
		var here: Dictionary = _footprint(shape,
			low_x + off / 2, low_z + off / 2, wide, long, wall)
		if here.is_empty():
			if layer == 0:
				trouble.append("that fill covers nothing")
				return []
			break
		var laid: Dictionary = {}
		made.append_array(_tile(here, y + rise * float(layer), colour,
			COURSES if is_equal_approx(rise, 3.0) else TILES,
			below, laid))
		below = laid
		if made.size() > MOST:
			trouble.append("that fill would be %d bricks, which is a "
				% made.size() + "mistake in the numbers rather than a "
				+ "shape. Fewer layers, or a bigger shrink")
			return []
	return made


## Which studs a footprint covers.
##
## [param wall] leaves the middle out: the same shape, [param wall]
## studs in on every side, taken away again. Nought is solid.
static func _footprint(shape: String, low_x: int, low_z: int,
		across: int, deep: int, wall: int) -> Dictionary:
	var wanted: Dictionary = {}
	for x: int in range(low_x, low_x + across):
		for z: int in range(low_z, low_z + deep):
			if _inside(shape, x, z, low_x, low_z, across, deep):
				wanted[Vector2i(x, z)] = true
	if wall < 1:
		return wanted
	var inner_across: int = across - wall * 2
	var inner_deep: int = deep - wall * 2
	if inner_across < 1 or inner_deep < 1:
		# Thicker than the shape is wide, so all of it is wall.
		return wanted
	for x: int in range(low_x + wall, low_x + wall + inner_across):
		for z: int in range(low_z + wall, low_z + wall + inner_deep):
			if _inside(shape, x, z, low_x + wall, low_z + wall,
					inner_across, inner_deep):
				wanted.erase(Vector2i(x, z))
	return wanted


## Is a stud inside the shape?
##
## Measured at the middle of each stud, so a circle comes out round
## rather than lozenge-shaped.
static func _inside(shape: String, x: int, z: int, low_x: int, low_z: int,
		across: int, deep: int) -> bool:
	if shape != "ellipse":
		return true
	var u: float = (float(x - low_x) + 0.5) / (float(across) / 2.0) - 1.0
	var v: float = (float(z - low_z) + 0.5) / (float(deep) / 2.0) - 1.0
	return u * u + v * v <= 1.0


## A set of studs, laid in the largest parts that cover it.
##
## [param below] is what the layer underneath covers. Where there is
## one, every part laid here has to reach it: a layer that flares
## outward has studs over nothing at its rim, and a plate lying wholly
## in that overhang is a floating brick. Reaching inward instead turns
## the same studs into an overhanging plate that is held, which is how
## a bowl is actually built. Studs that no part can reach are left
## unlaid — there is nothing to build them on.
##
## [param laid] comes back holding what was covered, to be the next
## layer's [param below].
static func _tile(wanted: Dictionary, y: float, colour: int,
		tiles: Array, below: Dictionary, laid: Dictionary) -> Array:
	var made: Array = []
	for tile: Variant in tiles:
		var one: Array = tile
		var wide: int = one[0]
		var tall: int = one[1]
		for key: Variant in wanted.keys():
			var cell: Vector2i = key
			if not wanted.has(cell):
				continue
			var fits: bool = true
			var held: bool = below.is_empty()
			for dx: int in wide:
				for dz: int in tall:
					var at: Vector2i = cell + Vector2i(dx, dz)
					if not wanted.has(at):
						fits = false
						break
					if below.has(at):
						held = true
				if not fits:
					break
			if not fits or not held:
				continue
			for dx: int in wide:
				for dz: int in tall:
					wanted.erase(cell + Vector2i(dx, dz))
					laid[cell + Vector2i(dx, dz)] = true
			made.append({"part": one[2], "color": colour,
				"x": cell.x, "y": y, "z": cell.y, "rot": one[3]})
	return made
