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

## Wedge plates, which LDraw files under "Wing": one plate thick, left
## and right handed, largest first.
##
## Their shapes are not written down here. A wedge's top studs sit only
## on the part of its footprint it really covers, so the shape is read
## off the part itself — and the handedness falls out of that, which it
## has to, because a table of hypotenuse directions typed by hand is how
## a model ends up with two left wings.
##
## Measured, Wing 4 x 4 Left:
##
##   ###.
##   ###.
##   ##..
##   #...
const WEDGES: Array = [
	"3933", "3934",        # Wing 4 x 8
	"3544", "3545",        # Wing 3 x 8
	"48208", "48205",      # Wing 4 x 6
	"54384", "54383",      # Wing 3 x 6
	"3936", "3935",        # Wing 4 x 4
	"78443", "78444",      # Wing 2 x 6
	"41770a", "41769a",    # Wing 2 x 4
	"43723a", "43722a",    # Wing 2 x 3
	"24299", "24307",      # Wing 2 x 2
]

## "part rot" -> [across, deep, Dictionary of Vector2i], worked out once
## from the parts themselves.
static var _wedge_shapes: Dictionary = {}
## The same shapes by their normalised cell set, so the mirror of a
## placement can be looked up rather than derived. Measured: all 72
## shapes have a twin in here, which is what makes it possible to lay
## wedges in pairs and never leave a saucer lopsided.
static var _wedge_prints: Dictionary = {}

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
				made.append_array(_fill(pattern, trouble, library))
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
static func _fill(pattern: Dictionary, trouble: Array,
		library: PartLibrary) -> Array:
	var shape: String = str(pattern.get("shape", "rectangle")).to_lower()
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var low_x: int = int(round(float(at.get("x", 0.0))))
	var low_z: int = int(round(float(at.get("z", 0.0))))
	var y: float = float(at.get("y", 0.0))
	var across: int = int(round(float(pattern.get("across", 0))))
	var deep: int = int(round(float(pattern.get("deep", 0))))
	var colour: int = int(pattern.get("color", pattern.get("colour", 71)))
	var wall: int = int(round(float(pattern.get("wall", 0))))
	# A second colour for the outside stud of every layer.
	#
	# Measured on three starships the assistant built: 90, 93 and 95 per
	# cent of their parts in one colour, against 31 to 59 for the eight
	# a person built. The rules already say to vary the colour with
	# purpose and it does not, the same way it never reached for a wedge
	# until the fill laid them — so the fill traces the outline instead.
	# One stud of a darker shade around each layer is what hull plating
	# and panel lines look like, and it costs the design nothing to ask
	# for.
	var edge_colour: int = int(pattern.get("edge_color",
		pattern.get("edge_colour", -1)))
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
		var at_y: float = y + rise * float(layer)
		# The outline, worked out before anything is laid and used only
		# to choose colours afterwards.
		#
		# Laying it as its own ring was the first attempt and it broke
		# the model: the wedge pass needs the whole layer to know what
		# is outside the shape, so given a one-stud ring it judged the
		# interior to be outside and cut straight through it — 32
		# overlaps and 20 bricks reading as floating behind them. A
		# colour must never decide where a part goes.
		var rim_of: Dictionary = _rim(here) if edge_colour >= 0 else {}
		var from_here: int = made.size()
		# Wedges first, and only where a diagonal is what the edge is:
		# an ellipse, laid in plates. A plate laid first takes the cells
		# a wedge needed, a rectangle has no diagonal, and there is no
		# wedge one brick tall.
		if shape == "ellipse" and is_equal_approx(rise, 1.0):
			made.append_array(_lay_wedges(here, at_y, colour, below, laid,
				library))
		var tiles: Array = COURSES if is_equal_approx(rise, 3.0) else TILES
		if not rim_of.is_empty():
			# A wedge that sits wholly on the outline belongs to it.
			_colour_the_rim(made, from_here, rim_of, edge_colour, library)
			# Then the outline's own plates, before the ones filling the
			# middle: laid largest-first the big plates span the edge and
			# the middle both, so almost nothing ends up wholly on the
			# edge and the second colour never shows. Measured, that way
			# round: one hundred per cent in one colour becoming
			# ninety-five.
			#
			# The wedges above were laid against the whole layer, which
			# is what they need to know where the shape ends. The tiler
			# only fills a set of studs and does not care.
			var ring: Dictionary = {}
			for edge_cell: Variant in rim_of:
				if here.has(edge_cell):
					ring[edge_cell] = true
					here.erase(edge_cell)
			if not ring.is_empty():
				made.append_array(_tile(ring, at_y, edge_colour, tiles,
					below, laid))
		made.append_array(_tile(here, at_y, colour, tiles, below, laid))
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


## Give the parts that lie wholly on the outline their own colour.
##
## After the geometry and never before it. Every cell a part covers has
## to be an outline cell, so a plate reaching into the middle keeps the
## main colour and a one-by-one on the edge does not — which is what
## makes it read as plating rather than as a stripe.
static func _colour_the_rim(made: Array, from: int, rim: Dictionary,
		edge_colour: int, library: PartLibrary) -> void:
	var shapes: Dictionary = wedge_shapes(library)
	for n: int in range(from, made.size()):
		var one: Dictionary = made[n]
		var cells: Array[Vector2i] = []
		var named: String = "%s %d" % [str(one["part"]),
			int(one.get("rot", 0))]
		var corner := Vector2i(int(one["x"]), int(one["z"]))
		if shapes.has(named):
			for key: Variant in (shapes[named][2] as Dictionary):
				cells.append(corner + (key as Vector2i))
		else:
			var info: PartLibrary.PartInfo = library.parts.get(
				str(one["part"])) if library != null else null
			if info == null:
				continue
			var footprint: Vector2i = info.footprint_studs()
			var wide: int = footprint.x
			var deep: int = footprint.y
			if int(one.get("rot", 0)) % 2 == 1:
				var swap: int = wide
				wide = deep
				deep = swap
			for i: int in wide:
				for j: int in deep:
					cells.append(corner + Vector2i(i, j))
		if cells.is_empty():
			continue
		var all_edge: bool = true
		for at: Vector2i in cells:
			if not rim.has(at):
				all_edge = false
				break
		if all_edge:
			one["color"] = edge_colour


## The outside stud of a footprint: every cell with a gap beside it.
##
## Four neighbours and not eight, so a diagonal step counts as inside.
## Eight would take the whole of a narrow shape and leave nothing for
## the middle colour to fill.
static func _rim(cells: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in cells:
		var at: Vector2i = key
		if not cells.has(at + Vector2i(1, 0)) \
				or not cells.has(at + Vector2i(-1, 0)) \
				or not cells.has(at + Vector2i(0, 1)) \
				or not cells.has(at + Vector2i(0, -1)):
			out[at] = true
	return out


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


## Every wedge shape, in every quarter turn, worked out once.
static func wedge_shapes(library: PartLibrary) -> Dictionary:
	if not _wedge_shapes.is_empty():
		return _wedge_shapes
	for part: Variant in WEDGES:
		var base: Array = _studs_of(library, str(part))
		if base.is_empty():
			continue
		for rot: int in 4:
			var turned: Array = _turned(base, rot)
			var named: String = "%s %d" % [str(part), rot]
			_wedge_shapes[named] = turned
			var mark: String = fingerprint(turned[2])
			if not _wedge_prints.has(mark):
				_wedge_prints[mark] = named
	return _wedge_shapes


## The shape that is this one reflected, as "part rot", or "".
##
## Looked up by the cells rather than worked out from handedness, so
## nothing here has to know which wedge is the left hand of which.
static func wedge_mirror_of(library: PartLibrary, named: String) -> String:
	wedge_shapes(library)
	var shape: Array = _wedge_shapes.get(named, [])
	if shape.is_empty():
		return ""
	return str(_wedge_prints.get(fingerprint(_reflect(shape[2])), ""))


## Which studs a wedge has, in cells from the low corner of its
## footprint — which is the corner a placement names.
##
## A stud at the footprint's minimum is cell nought, and a handed pair
## differs only in which side the cut is on: 3936 reaches to +37 of a
## +40 box and 3935 starts at -37 of a -40 one, so the same arithmetic
## gives one shape and its mirror without being told about either.
static func _studs_of(library: PartLibrary, part: String) -> Array:
	var info: PartLibrary.PartInfo = library.parts.get(part) if library != null \
		else null
	var mesh: Lbm.PartMesh = library.mesh_for(part) if library != null else null
	if info == null or mesh == null:
		return []
	var footprint: Vector2i = info.footprint_studs()
	var cells: Dictionary = {}
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "stud" or connector.gender != "male":
			continue
		# Upward studs only. One on a side belongs to a different part
		# and a different problem.
		if connector.axis.normalized().dot(Vector3.UP) < 0.9:
			continue
		var at := Vector2i(
			int(floor((connector.position.x - mesh.bounds.position.x) / 20.0)),
			int(floor((connector.position.z - mesh.bounds.position.z) / 20.0)))
		if at.x < 0 or at.y < 0 or at.x >= footprint.x or at.y >= footprint.y:
			continue
		cells[at] = true
	# Nothing read, or it fills its own box — in which case a plate does
	# the same job and is a plate.
	if cells.is_empty() or cells.size() >= footprint.x * footprint.y:
		return []
	return [footprint.x, footprint.y, cells]


## A shape turned. Measured against the real placement transform:
## a quarter turn sends (i, j) to (j, across - 1 - i).
static func _turned(shape: Array, rot: int) -> Array:
	var across: int = shape[0]
	var deep: int = shape[1]
	var cells: Dictionary = shape[2]
	for _turn: int in posmod(rot, 4):
		var next: Dictionary = {}
		for key: Variant in cells:
			var at: Vector2i = key
			next[Vector2i(at.y, across - 1 - at.x)] = true
		cells = next
		var swap: int = across
		across = deep
		deep = swap
	return [across, deep, cells]


## A shape reflected across its own width.
static func _reflect(cells: Dictionary) -> Dictionary:
	var widest: int = 0
	for key: Variant in cells:
		widest = maxi(widest, (key as Vector2i).x)
	var out: Dictionary = {}
	for key: Variant in cells:
		var at: Vector2i = key
		out[Vector2i(widest - at.x, at.y)] = true
	return out


## A set of cells as one comparable string, shifted so its lowest cell
## is at nought. Two shapes are the same shape when these match.
static func fingerprint(cells: Dictionary) -> String:
	var low := Vector2i(0x7FFFFFFF, 0x7FFFFFFF)
	for key: Variant in cells:
		var at: Vector2i = key
		low = Vector2i(mini(low.x, at.x), mini(low.y, at.y))
	var said := PackedStringArray()
	for key: Variant in cells:
		var at: Vector2i = key
		said.append("%d,%d" % [at.x - low.x, at.y - low.y])
	said.sort()
	return "|".join(said)


## Lay wedges wherever the shape of a wedge is the shape of the edge.
##
## Before the plates, because a plate laid first takes the cells a wedge
## needed. Only on an ellipse laid in plates: a rectangle has no
## diagonal and a wedge at each of its corners would round them off,
## and there is no wedge one brick tall.
##
## A wedge belongs where every stud it has is wanted and every cell it
## does not cover is outside the shape — that is what makes its cut
## follow the edge rather than slice through the middle. And it is laid
## with its mirror or not at all, because a saucer with one cut corner
## is the fault the checker calls out first and the thing a person sees.
##
## Three things here were learned by getting them wrong:
##
## - studs are not the body. A wedge's tapered half fills cells it has
##   no stud on, so reserving only the studded ones let two wedges put
##   their tapers in the same place: fourteen overlaps on one flat
##   ellipse, every one wedge against wedge. The whole box is reserved
##   and only the studs are claimed as covered.
## - the fits test needs the shape as it was, not as it is left. Against
##   a shrinking set the second wedge mistakes the first one's studs for
##   the outside of the shape and cuts through them.
## - positions are tried over the whole box, not over the wanted cells.
##   A right hand's corner cell is never one of its own studs, so taking
##   a wanted cell for the corner can only ever place left hands.
static func _lay_wedges(wanted: Dictionary, y: float, colour: int,
		below: Dictionary, laid: Dictionary, library: PartLibrary) -> Array:
	var shapes: Dictionary = wedge_shapes(library)
	if shapes.is_empty() or wanted.is_empty():
		return []
	var whole: Dictionary = wanted.duplicate()
	var taken: Dictionary = {}
	var low := Vector2i(0x7FFFFFFF, 0x7FFFFFFF)
	var high := Vector2i(-0x7FFFFFFF, -0x7FFFFFFF)
	for key: Variant in whole:
		var at: Vector2i = key
		low = Vector2i(mini(low.x, at.x), mini(low.y, at.y))
		high = Vector2i(maxi(high.x, at.x), maxi(high.y, at.y))
	# The two lines a wedge's family reflects about: the shape's own
	# middle across and its middle deep.
	#
	# Both, not one. Pairing about x alone laid eight wedges on an
	# ellipse and the checker answered "a mirror of itself about its
	# width, except for brick 6 and brick 7" — a correct pair, about
	# the other axis. A saucer is symmetric both ways, so the unit is
	# not a pair but the whole family a placement belongs to under both
	# reflections: one, two or four, all of them or none.
	var across_axis: int = low.x + high.x
	var deep_axis: int = low.y + high.y

	var order: Array = shapes.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		var one: int = (shapes[a][2] as Dictionary).size()
		var two: int = (shapes[b][2] as Dictionary).size()
		return one > two if one != two else a < b)

	var made: Array = []
	for named: String in order:
		var shape: Array = shapes[named]
		for corner_x: int in range(low.x - int(shape[0]) + 1, high.x + 1):
			for corner_z: int in range(low.y - int(shape[1]) + 1, high.y + 1):
				var corner := Vector2i(corner_x, corner_z)
				var mine: Dictionary = _cells_at(shape, corner)
				if not _wedge_fits(shape, corner, whole, wanted, taken):
					continue
				var family: Array = _family_of(shapes, named, shape,
					corner, mine, across_axis, deep_axis)
				if family.is_empty():
					continue
				var all_fit: bool = true
				for one: Variant in family:
					var member: Array = one
					if not _wedge_fits(shapes[member[0]], member[1], whole,
							wanted, taken):
						all_fit = false
						break
					if not below.is_empty() and not _reaches(
							_cells_at(shapes[member[0]], member[1]), below):
						all_fit = false
						break
				if not all_fit:
					continue
				for n: int in family.size():
					for m: int in range(n + 1, family.size()):
						if _overlaps(shapes[family[n][0]], family[n][1],
								shapes[family[m][0]], family[m][1]):
							all_fit = false
				if not all_fit:
					continue
				for one: Variant in family:
					var member: Array = one
					_claim(shapes[member[0]], member[1], wanted, laid, taken)
					made.append(_placement(member[0], shapes[member[0]],
						member[1], y, colour))
	return made


## Every wedge that has to go in with this one, itself included.
##
## A placement, its reflection across the shape's middle, its reflection
## the other way, and the one diagonally opposite. Where a reflection
## lands on the placement itself the family is smaller, which is what
## happens to a wedge sitting across a middle line.
##
## Empty if any of the four is not a shape this family has — which
## cannot happen for a wedge, measured, because all seventy-two shapes
## have a mirror twin, but a missing one would mean laying an
## unanswerable wedge and that is the fault worth refusing.
static func _family_of(shapes: Dictionary, named: String, shape: Array,
		corner: Vector2i, mine: Dictionary, across_axis: int,
		deep_axis: int) -> Array:
	var family: Array = [[named, corner]]
	var seen: Dictionary = {"%s %d %d" % [named, corner.x, corner.y]: true}
	for turn: int in 3:
		var reflected: Dictionary = {}
		for key: Variant in mine:
			var at: Vector2i = key
			reflected[Vector2i(
				across_axis - at.x if turn != 1 else at.x,
				deep_axis - at.y if turn != 0 else at.y)] = true
		var twin: String = str(_wedge_prints.get(fingerprint(reflected), ""))
		if twin.is_empty():
			return []
		var pair: Array = shapes[twin]
		var where: Vector2i = _corner_for(pair, reflected)
		if not _same(_cells_at(pair, where), reflected):
			return []
		var mark: String = "%s %d %d" % [twin, where.x, where.y]
		if seen.has(mark):
			continue
		seen[mark] = true
		family.append([twin, where])
	return family


## The cells a shape covers, placed at a corner.
static func _cells_at(shape: Array, corner: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in shape[2]:
		out[corner + (key as Vector2i)] = true
	return out


## Where a shape has to sit for its cells to be this set.
static func _corner_for(shape: Array, cells: Dictionary) -> Vector2i:
	var low := Vector2i(0x7FFFFFFF, 0x7FFFFFFF)
	for key: Variant in cells:
		var at: Vector2i = key
		low = Vector2i(mini(low.x, at.x), mini(low.y, at.y))
	var own := Vector2i(0x7FFFFFFF, 0x7FFFFFFF)
	for key: Variant in shape[2]:
		var at: Vector2i = key
		own = Vector2i(mini(own.x, at.x), mini(own.y, at.y))
	return low - own


## Is this wedge right here? Every stud wanted and still free, every
## cell it does not cover outside the shape, and nothing of another
## wedge's body in its box.
static func _wedge_fits(shape: Array, corner: Vector2i, whole: Dictionary,
		wanted: Dictionary, taken: Dictionary) -> bool:
	var cells: Dictionary = shape[2]
	for i: int in int(shape[0]):
		for j: int in int(shape[1]):
			var at: Vector2i = corner + Vector2i(i, j)
			if taken.has(at):
				return false
			var ours: bool = cells.has(Vector2i(i, j))
			if ours != whole.has(at):
				return false
			if ours and not wanted.has(at):
				return false
	return true


## Reserve a wedge's whole box and claim the studs it covers.
static func _claim(shape: Array, corner: Vector2i, wanted: Dictionary,
		laid: Dictionary, taken: Dictionary) -> void:
	for i: int in int(shape[0]):
		for j: int in int(shape[1]):
			taken[corner + Vector2i(i, j)] = true
	for key: Variant in shape[2]:
		var at: Vector2i = corner + (key as Vector2i)
		wanted.erase(at)
		laid[at] = true


## Do two placed wedges want any of the same cells?
static func _overlaps(one: Array, here: Vector2i, two: Array,
		there: Vector2i) -> bool:
	for i: int in int(one[0]):
		for j: int in int(one[1]):
			var at: Vector2i = here + Vector2i(i, j)
			if at.x >= there.x and at.x < there.x + int(two[0]) \
					and at.y >= there.y and at.y < there.y + int(two[1]):
				return true
	return false


## Does any of this reach the layer below?
static func _reaches(cells: Dictionary, below: Dictionary) -> bool:
	for key: Variant in cells:
		if below.has(key):
			return true
	return false


static func _same(one: Dictionary, two: Dictionary) -> bool:
	if one.size() != two.size():
		return false
	for key: Variant in one:
		if not two.has(key):
			return false
	return true


static func _placement(named: String, shape: Array, corner: Vector2i,
		y: float, colour: int) -> Dictionary:
	var said: PackedStringArray = named.split(" ")
	return {"part": said[0], "color": colour, "x": corner.x, "y": y,
		"z": corner.y, "rot": said[1].to_int()}


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
