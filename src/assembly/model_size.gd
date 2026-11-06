## How big the model is and what it weighs, as Studio's Model Info says it
## (docs/APP_UX5.md, modelinfo): "will it fit the shelf" was nowhere, in the
## window or over MCP, and a session worked it out from what it had built.
##
## The size is the box round the parts as they stand: across (x), deep (z)
## and high, in studs and plates, and in centimetres at LDraw's 0.4 mm an
## LDU. The plates count a model's height as a wall's is counted, without the
## studs on its top (Inspector's selection says it so); the centimetres take
## them in, since a shelf has to. Each part's box is its shape's own, turned
## with it: exact for every part at a right angle, and for one at another
## angle the box round its turned box.
##
## The weight is each part's grams from its shape (Stability.grams): the
## catalogue lists no part's weight (BrickLink's catalogue does, behind its
## keys and terms), and the shape's comes within 6% of the bricks that have
## been weighed. The same sum as the status bar's "52 g". A part the library
## has no entry for has neither, and is counted as left out.
##
## The baseplate under the model is the floor, not the model, as the counts
## leave it out. Worked out once a change of the model (BrickWorld.revision),
## and shared by the status bar, Properties and in_view.
class_name ModelSize
extends RefCounted

## LDraw's unit, in millimetres.
const LDU_MM := 0.4
## How far a stud stands proud of the part it is on, LDU.
const STUD_TOP := 4.0

## Round the parts measured, in LDU; nothing when none was.
var box: AABB = AABB()
var parts: int = 0
## Parts the library has no entry for: in no size and no weight.
var left_out: int = 0
var grams: float = 0.0

## The model's, kept for its revision: [world's id, revision, generation,
## the floor's parts] and what they gave. On the window's own thread only.
static var _key: Array = []
static var _kept: ModelSize = null


## The model's size and weight, the baseplate ([param scenery]) left out.
static func of_model(world: BrickWorld, library: PartLibrary, scenery: Dictionary) -> ModelSize:
	var key: Array = [world.get_instance_id(), world.revision, world.generation(), scenery.size()]
	if _kept != null and key == _key:
		return _kept
	_kept = of_bricks(world.bricks(), library, scenery)
	_key = key
	return _kept


## [param bricks]' size and weight, those in [param skip] left out.
static func of_bricks(bricks: Array, library: PartLibrary, skip: Dictionary = {}) -> ModelSize:
	var size := ModelSize.new()
	## part id -> [its box, its grams], or null when the library has none.
	var known: Dictionary = {}
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		if brick == null or skip.has(brick.id):
			continue
		var part: Variant = known.get(brick.part_id, false)
		if part is bool:
			var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
			part = [info.bounds, Stability.grams(info)] if info != null else null
			known[brick.part_id] = part
		if part == null:
			size.left_out += 1
			continue
		var here: AABB = brick.transform * (part[0] as AABB)
		size.box = here if size.parts == 0 else size.box.merge(here)
		size.parts += 1
		size.grams += float(part[1])
	return size


func is_empty() -> bool:
	return parts == 0


## The height in plates, without the studs on the top: a part's box takes
## them in, standing half a plate proud, and nobody counts them in how tall a
## wall is (Inspector._plates).
func plates_high() -> float:
	var high: float = box.size.y
	if is_equal_approx(fposmod(high, BrickLattice.PLATE), STUD_TOP):
		high -= STUD_TOP
	return high / BrickLattice.PLATE


## Across (x), deep (z) and high, in centimetres, the studs on top in.
func centimetres() -> Vector3:
	return box.size * LDU_MM / 10.0


## "16 × 9 studs, 6 plates high": across, deep, and high without the top's
## studs. "" for nothing measured.
func studs_words() -> String:
	if is_empty():
		return ""
	var high: float = plates_high()
	var across: String = "%s × %s studs" % [StatusBar.amount(box.size.x / BrickLattice.STUD),
		StatusBar.amount(box.size.z / BrickLattice.STUD)]
	if absf(high - 1.0) < 0.005:
		return across + ", 1 plate high"
	return across + ", %s plates high" % StatusBar.amount(high)


## "12.8 × 7.2 × 2.08 cm", to the tenth of a millimetre. "" for nothing.
func centimetre_words() -> String:
	if is_empty():
		return ""
	var across: Vector3 = centimetres()
	return "%s × %s × %s cm" % [cm(across.x), cm(across.z), cm(across.y)]


## Both, as the status bar says them.
func words() -> String:
	if is_empty():
		return ""
	return studs_words() + " · " + centimetre_words()


## "About 52 g", rounded as the status bar's weight is (Stability.Report).
func weight_words() -> String:
	return "About %s g" % ("%.0f" % grams)


## "1 part not in the library, not counted", or "".
func left_out_words() -> String:
	if left_out == 0:
		return ""
	return "1 part not in the library, not counted" if left_out == 1 \
		else "%d parts not in the library, not counted" % left_out


## A length in centimetres to the tenth of a millimetre: "12.8", "2.08".
static func cm(value: float) -> String:
	return String.num(value, 2)
