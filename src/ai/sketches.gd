## Sketch first: three cheap massings before a full design.
##
## A small house costs eleven minutes and $2.40 at high effort, and whether
## the brief was understood is learnt only once that is paid. Three massings
## under 150 parts each, said in one turn on the cheaper model (Brain's
## sketch_model), let the person choose a silhouette first; the full design
## is then built from the one they chose, at their own model and effort.
##
## This is what the three are held as, measured by and told apart by. The
## loop that asks for them is Assistant.sketch, the tool that takes them is
## submit_design's sketch, and the cards they are chosen from are
## ChatPanel._on_sketches.
class_name Sketches
extends RefCounted

## How many make a choice, and the most parts one may have. A sketch is
## the masses at their sizes: past this it is a design, at a design's price.
const COUNT := 3
const MOST_PARTS := 150

## Two sketches are one idea when every size is within this share of the
## other's and their outlines, seen from the front, the side and above,
## overlap at least this much. Three lighthouses that are each a white
## column 6 studs round and 40 plates tall are one choice, not three.
const SAME_SIZE := 0.15
const SAME_OUTLINE := 0.7


## One sketch, held and not built.
class Sketch extends RefCounted:
	var number: int = 0
	var name: String = ""
	var description: String = ""
	## Assistant.Model: what it would put down if chosen.
	var model: RefCounted = null
	## submit_design's input as it came, to hand the full design.
	var args: Dictionary = {}
	## What _checked said of it.
	var report: Dictionary = {}
	## Its picture from a corner, or null where nothing can be drawn.
	var picture: Image = null
	## The same as a content block for Claude, or {} without one.
	var block: Dictionary = {}
	## The model drawn as letters, when there is no picture.
	var letters: String = ""
	## Studs across, studs deep and plates tall.
	var size := Vector3.ZERO
	## View -> the cells it covers, from its own corner: see [method measure].
	var outline: Dictionary = {}
	var parts: int = 0

	func holds() -> bool:
		return bool(report.get("ok", false))

	## "8 x 8 studs, 40 plates tall".
	func measures() -> String:
		return Sketches.words(size)


## How big it is and what it covers, read off [param world], a world holding
## only the sketch: {"size": Vector3(studs across, studs deep, plates tall),
## "outline": {"front": cells, "side": cells, "top": cells}}, each cell a
## stud by a plate (a stud by a stud from above), counted from the model's
## own lowest corner so two sketches standing in different places compare.
static func measure(world: BrickWorld) -> Dictionary:
	var box: AABB = world.model_bounds()
	var views: Dictionary = {"front": {}, "side": {}, "top": {}}
	for brick: BrickWorld.Brick in world.bricks():
		var info: PartLibrary.PartInfo = world.library.parts.get(brick.part_id)
		if info == null:
			continue
		var here: AABB = (brick.transform * info.bounds).abs()
		# Up is -y: heights are counted from the ground, the box's end.
		var low := Vector3(here.position.x - box.position.x, box.end.y - here.end.y,
			here.position.z - box.position.z)
		var high := Vector3(here.end.x - box.position.x, box.end.y - here.position.y,
			here.end.z - box.position.z)
		var x0: int = floori(low.x / 20.0 + 0.05)
		var x1: int = maxi(ceili(high.x / 20.0 - 0.05), x0 + 1)
		var z0: int = floori(low.z / 20.0 + 0.05)
		var z1: int = maxi(ceili(high.z / 20.0 - 0.05), z0 + 1)
		var y0: int = floori(low.y / 8.0 + 0.05)
		var y1: int = maxi(ceili(high.y / 8.0 - 0.05), y0 + 1)
		for y: int in range(y0, y1):
			for x: int in range(x0, x1):
				views["front"][Vector2i(x, y)] = true
			for z: int in range(z0, z1):
				views["side"][Vector2i(z, y)] = true
		for x: int in range(x0, x1):
			for z: int in range(z0, z1):
				views["top"][Vector2i(x, z)] = true
	return {"size": Vector3(box.size.x / 20.0, box.size.z / 20.0, box.size.y / 8.0),
		"outline": views}


## Whether two sketches are the same idea at nearly the same size.
static func alike(one: Sketch, other: Sketch) -> bool:
	for axis: int in 3:
		var a: float = one.size[axis]
		var b: float = other.size[axis]
		if absf(a - b) > SAME_SIZE * maxf(maxf(a, b), 1.0):
			return false
	return overlap(one, other) >= SAME_OUTLINE


## How much of their outlines two sketches share, from 0 to 1: the three
## views' overlap over their union, averaged.
static func overlap(one: Sketch, other: Sketch) -> float:
	var total: float = 0.0
	for view: String in ["front", "side", "top"]:
		var mine: Dictionary = one.outline.get(view, {})
		var theirs: Dictionary = other.outline.get(view, {})
		var both: int = 0
		for cell: Vector2i in mine:
			if theirs.has(cell):
				both += 1
		var either: int = mine.size() + theirs.size() - both
		total += float(both) / either if either > 0 else 1.0
	return total / 3.0


## The pairs among [param held] that are one idea, each [first, second] by
## number, in order.
static func alike_pairs(held: Array) -> Array:
	var pairs: Array = []
	for n: int in held.size():
		for m: int in range(n + 1, held.size()):
			if alike(held[n], held[m]):
				pairs.append([(held[n] as Sketch).number, (held[m] as Sketch).number])
	return pairs


static func words(size: Vector3) -> String:
	return "%d x %d studs, %d plates tall" % [roundi(size.x), roundi(size.y),
		roundi(size.z)]
