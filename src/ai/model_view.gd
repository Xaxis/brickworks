## Letting the assistant look at what it has made.
##
## It builds blind. check_design answers "62 bricks, buildable", which
## says the model is legal and says nothing about whether it looks like
## a car — and looking like a car is the entire job. A person building
## this would glance at it every few bricks; the assistant had no way
## to glance at all, so a design that went wrong in shape went wrong
## invisibly and stayed wrong.
##
## Drawn as text rather than rendered, for three reasons that all have
## to hold: the proxy caps a request body and the conversation is never
## pruned, so pictures would end the design partway; the example
## generator runs headless, where the viewport yields nothing; and a
## probe can assert something about characters and almost nothing about
## a JPEG.
##
## Scale is two characters to a stud across and one line to a plate up.
## A monospace character is about half as wide as it is tall, so a
## brick — one stud wide, three plates tall — comes out roughly square,
## and the proportions in the drawing are the proportions of the model.
class_name ModelView
extends RefCounted

## Past this the drawing is more than anyone can read in one go, and
## the request it rides in grows faster than the design does.
const MAX_STUDS := 48
const MAX_PLATES := 60

const ACROSS := 2   ## characters per stud
const EMPTY := "."


## A view of the world from one side.
##
## [param from] is one of top, front, back, left, right. [param skip]
## names bricks to leave out — the baseplate, which is the ground
## rather than part of what was built.
static func draw(world: BrickWorld, library: PartLibrary,
		from: String, skip: Dictionary = {}) -> String:
	var bricks: Array[BrickWorld.Brick] = []
	for brick: BrickWorld.Brick in world.bricks():
		if not skip.has(brick.id):
			bricks.append(brick)
	if bricks.is_empty():
		return "Nothing is built yet."

	# Everything in stud and plate coordinates, which is what the model
	# speaks. Cells are 2 LDU; a stud is ten of them and a plate four.
	var spans: Array[Dictionary] = []
	var low := Vector3i(999999, 999999, 999999)
	var high := Vector3i(-999999, -999999, -999999)
	for brick: BrickWorld.Brick in bricks:
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part == null:
			continue
		var box: AABB = brick.transform * part.bounds
		# Both ends pulled in by the moulding clearance, or a round
		# brick is drawn a stud wider than a square one of the same
		# size: its geometry overshoots 40 LDU by a thousandth, and
		# rounding that outward buys a whole stud of nothing.
		var slack: float = BrickLattice.CLEARANCE
		var span := {
			"x0": int(floor((box.position.x + slack) / BrickLattice.STUD)),
			"x1": int(ceil((box.end.x - slack) / BrickLattice.STUD)),
			"y0": int(floor((box.position.y + slack) / BrickLattice.PLATE)),
			"y1": int(ceil((box.end.y - slack) / BrickLattice.PLATE)),
			"z0": int(floor((box.position.z + slack) / BrickLattice.STUD)),
			"z1": int(ceil((box.end.z - slack) / BrickLattice.STUD)),
			"colour": brick.color_code,
		}
		spans.append(span)
		low = Vector3i(mini(low.x, span["x0"]), mini(low.y, span["y0"]), mini(low.z, span["z0"]))
		high = Vector3i(maxi(high.x, span["x1"]), maxi(high.y, span["y1"]), maxi(high.z, span["z1"]))
	if spans.is_empty():
		return "Nothing is built yet."

	# One letter per colour, so the drawing carries what a silhouette
	# alone cannot: where one material stops and another starts.
	var letters: Dictionary = {}
	var legend := PackedStringArray()
	const ALPHABET := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for span: Dictionary in spans:
		var code: int = int(span["colour"])
		if letters.has(code):
			continue
		var letter: String = ALPHABET[mini(letters.size(), ALPHABET.length() - 1)]
		letters[code] = letter
		var colour: PartLibrary.BrickColor = library.color(code)
		legend.append("%s = %s" % [letter, colour.name if colour != null else str(code)])

	match from:
		"top":
			return _plan(spans, letters, legend, low, high)
		"front", "back", "left", "right":
			return _elevation(spans, letters, legend, low, high, from)
	return "No view called '%s'. Use top, front, back, left or right." % from


## Looking down. Each square takes the colour of the highest brick over
## it, which is what you see from above.
static func _plan(spans: Array[Dictionary], letters: Dictionary,
		legend: PackedStringArray, low: Vector3i, high: Vector3i) -> String:
	var wide: int = mini(high.x - low.x, MAX_STUDS)
	var deep: int = mini(high.z - low.z, MAX_STUDS)
	var top: Array = []
	var best: Array = []
	for _row: int in deep:
		top.append([])
		best.append([])
		for _column: int in wide:
			top[top.size() - 1].append(EMPTY)
			best[best.size() - 1].append(-999999)

	for span: Dictionary in spans:
		for z: int in range(maxi(span["z0"], low.z), mini(span["z1"], low.z + deep)):
			for x: int in range(maxi(span["x0"], low.x), mini(span["x1"], low.x + wide)):
				var row: int = z - low.z
				var column: int = x - low.x
				if int(span["y1"]) > int(best[row][column]):
					best[row][column] = int(span["y1"])
					top[row][column] = letters[int(span["colour"])]

	var lines := PackedStringArray()
	lines.append("Looking down. %d studs across, %d deep."
		% [high.x - low.x, high.z - low.z])
	lines.append("x runs left to right from %d; z runs top to bottom from %d."
		% [low.x, low.z])
	lines.append("")
	for row: int in deep:
		var out := ""
		for column: int in wide:
			out += str(top[row][column]).repeat(ACROSS)
		lines.append(out)
	lines.append("")
	lines.append("  ".join(legend))
	return "\n".join(lines)


## Looking at a side. Each square takes the colour of the nearest brick
## behind it, which is what hides what.
static func _elevation(spans: Array[Dictionary], letters: Dictionary,
		legend: PackedStringArray, low: Vector3i, high: Vector3i,
		from: String) -> String:
	# Which axis runs across the drawing, and which way is nearer.
	var sideways: bool = from == "left" or from == "right"
	var across_low: int = low.z if sideways else low.x
	var across_high: int = high.z if sideways else high.x
	var wide: int = mini(across_high - across_low, MAX_STUDS)
	var tall: int = mini(high.y - low.y, MAX_PLATES)

	var face: Array = []
	var nearest: Array = []
	for _row: int in tall:
		face.append([])
		nearest.append([])
		for _column: int in wide:
			face[face.size() - 1].append(EMPTY)
			nearest[nearest.size() - 1].append(999999)

	for span: Dictionary in spans:
		var a0: int = int(span["z0"] if sideways else span["x0"])
		var a1: int = int(span["z1"] if sideways else span["x1"])
		# Depth into the picture, so a brick in front wins.
		var depth: int = int(span["x0"] if sideways else span["z0"])
		if from == "right" or from == "back":
			depth = -int(span["x1"] if sideways else span["z1"])

		for y: int in range(maxi(span["y0"], low.y), mini(span["y1"], low.y + tall)):
			for a: int in range(maxi(a0, across_low), mini(a1, across_low + wide)):
				# Up the page is up the model.
				var row: int = (low.y + tall - 1) - y
				var column: int = a - across_low
				if from == "right" or from == "back":
					column = wide - 1 - column
				if row < 0 or row >= tall or column < 0 or column >= wide:
					continue
				if depth < int(nearest[row][column]):
					nearest[row][column] = depth
					face[row][column] = letters[int(span["colour"])]

	var lines := PackedStringArray()
	lines.append("Looking at the %s. %d studs across, %d plates tall."
		% [from, across_high - across_low, high.y - low.y])
	lines.append("Up the page is up. Each line is one plate; three lines "
		+ "make a brick.")
	lines.append("")
	for row: int in tall:
		var out := ""
		for column: int in wide:
			out += str(face[row][column]).repeat(ACROSS)
		lines.append(out)
	lines.append("")
	lines.append("  ".join(legend))
	return "\n".join(lines)
