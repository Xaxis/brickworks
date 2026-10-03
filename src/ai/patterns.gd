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
##   fill     a footprint, tiled with the largest plates that fit
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
static func _fill(pattern: Dictionary, trouble: Array) -> Array:
	var shape: String = str(pattern.get("shape", "rectangle")).to_lower()
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var low_x: int = int(round(float(at.get("x", 0.0))))
	var low_z: int = int(round(float(at.get("z", 0.0))))
	var y: float = float(at.get("y", 0.0))
	var across: int = int(round(float(pattern.get("across", 0))))
	var deep: int = int(round(float(pattern.get("deep", 0))))
	var colour: int = int(pattern.get("color", pattern.get("colour", 71)))
	if across < 1 or deep < 1 or across * deep > MOST:
		trouble.append("fill wants across and deep, both at least 1 and "
			+ "not more than %d studs between them" % MOST)
		return []

	var wanted: Dictionary = {}
	for x: int in range(low_x, low_x + across):
		for z: int in range(low_z, low_z + deep):
			match shape:
				"rectangle":
					wanted[Vector2i(x, z)] = true
				"ellipse":
					# Measured at the middle of each stud, so a circle
					# comes out round rather than lozenge-shaped.
					var u: float = (float(x - low_x) + 0.5) / (float(across) / 2.0) - 1.0
					var v: float = (float(z - low_z) + 0.5) / (float(deep) / 2.0) - 1.0
					if u * u + v * v <= 1.0:
						wanted[Vector2i(x, z)] = true
				_:
					trouble.append("fill knows rectangle and ellipse")
					return []
	if wanted.is_empty():
		trouble.append("that fill covers nothing")
		return []

	var made: Array = []
	for tile: Variant in TILES:
		var one: Array = tile
		var wide: int = one[0]
		var tall: int = one[1]
		for key: Variant in wanted.keys():
			var cell: Vector2i = key
			if not wanted.has(cell):
				continue
			var fits: bool = true
			for dx: int in wide:
				for dz: int in tall:
					if not wanted.has(cell + Vector2i(dx, dz)):
						fits = false
						break
				if not fits:
					break
			if not fits:
				continue
			for dx: int in wide:
				for dz: int in tall:
					wanted.erase(cell + Vector2i(dx, dz))
			made.append({"part": one[2], "color": colour,
				"x": cell.x, "y": y, "z": cell.y, "rot": one[3]})
	return made
