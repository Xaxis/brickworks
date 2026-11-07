## How big the model is and what it weighs, as Studio's Model Info says it
## (docs/APP_UX5.md, modelinfo): "will it fit the shelf" was nowhere, in the
## window or over MCP, and a session worked it out from what it had built.
##
## The size is the box round the parts as they stand: across (x), deep (z)
## and high, in studs and plates, and in centimetres at LDraw's 0.4 mm an
## LDU. Each part's box is its shape's own, turned with it: exact for every
## part at a right angle, and for one at another angle the box round its
## turned box. The centimetres take in everything, the studs on top too, as
## a shelf has to. The plates count the height as a wall's is counted, without
## the studs on its top: the highest of each part's body, a part standing
## upright with studs on its top (its box 4 LDU over its origin, as LDraw
## draws a stud) counted to its top face, any other to its top. Read off the
## height alone ("4 over a whole plate is a stud"), a wheel 36 LDU tall was
## 4 plates.
##
## The weight is each part's grams from its shape (Stability.grams): the
## catalogue lists no part's weight (BrickLink's catalogue does, behind its
## keys and terms), and the shape's comes within 6% of the bricks that have
## been weighed. A part the library has no entry for has neither, and is
## counted as left out.
##
## A part whose shape is not here yet (on the web, fetched after the model
## opens; ModelStore.awaited) is in the model all the same: measured and
## weighed from the catalogue, which has every part's box, so the size and
## the weight are the whole model's from the first frame. Weighed from the
## shapes loaded so far, the status bar's weight was a sum that grew as they
## came (docs/APP_UX6.md, weighsure).
##
## The baseplate under the model is the floor, not the model, as the counts
## leave it out. Worked out once a change of the model (BrickWorld.revision),
## and shared by the status bar (its size and its weight), Properties and
## in_view: one weight for one model.
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
## The highest of the parts' bodies, the studs on an upright part's top left
## off, LDU.
var body_top: float = 0.0

## The model's, kept for its revision: [world's id, revision, generation,
## the floor's parts, the parts on their way] and what they gave. On the
## window's own thread only.
static var _key: Array = []
static var _kept: ModelSize = null


## The model's size and weight, the baseplate ([param scenery]) left out,
## and the parts on their way ([param coming], [method coming]) in.
static func of_model(world: BrickWorld, library: PartLibrary, scenery: Dictionary,
		coming: Array = []) -> ModelSize:
	var key: Array = [world.get_instance_id(), world.revision, world.generation(), scenery.size(),
		coming.size()]
	if _kept != null and key == _key:
		return _kept
	var bricks: Array = world.bricks()
	# Measured as a part down is: by the number it will land as, where it
	# will land (BrickWorld._place).
	for placement: LdrModel.Placement in coming:
		bricks.append(BrickWorld.Brick.new(0, library.resolve(placement.part_id),
			placement.color_code, placement.transform * library.moved_by(placement.part_id)))
	_kept = of_bricks(bricks, library, scenery)
	_key = key
	return _kept


## The parts of [param store]'s model still on their way, put down as each
## arrives (ModelStore.awaited): the open model's, none once the world has
## been cleared since.
static func coming(store: ModelStore) -> Array:
	if store == null or store.world == null or store.awaited.is_empty() \
			or store._awaited_in != store.world.generation():
		return []
	return store.awaited


## [param bricks]' size and weight, those in [param skip] left out. Kept in
## locals, a part's numbers looked up once: 10,101 of Orthanc's parts are
## measured on every change of it.
static func of_bricks(bricks: Array, library: PartLibrary, skip: Dictionary = {}) -> ModelSize:
	## part id -> [its box, its grams, whether its studs are its top], or
	## null when the library has none.
	var known: Dictionary = {}
	var box := AABB()
	var top: float = -INF
	var count: int = 0
	var missing: int = 0
	var grams: float = 0.0
	for brick: BrickWorld.Brick in bricks:
		if brick == null or skip.has(brick.id):
			continue
		var part: Variant = known.get(brick.part_id, false)
		if part is bool:
			var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
			part = null if info == null else [info.bounds, Stability.grams(info),
				info.stud_count > 0 and is_equal_approx(info.bounds.end.y, STUD_TOP)]
			known[brick.part_id] = part
		if part == null:
			missing += 1
			continue
		var here: AABB = brick.transform * (part[0] as AABB)
		box = here if count == 0 else box.merge(here)
		var body: float = here.end.y
		if part[2] and brick.transform.basis.y.y > 0.999:
			body -= STUD_TOP
		top = maxf(top, body)
		count += 1
		grams += float(part[1])
	var size := ModelSize.new()
	size.box = box
	size.parts = count
	size.left_out = missing
	size.grams = grams
	size.body_top = top if count > 0 else 0.0
	return size


func is_empty() -> bool:
	return parts == 0


## The height in plates, without the studs on the top (body_top): nobody
## counts them in how tall a wall is.
func plates_high() -> float:
	return (body_top - box.position.y) / BrickLattice.PLATE


## Across (x), deep (z) and high, in centimetres, the studs on top in.
func centimetres() -> Vector3:
	return box.size * LDU_MM / 10.0


## "4.5 × 10.8 studs, 15 plates high" (the car): across, deep, and high
## without the top's studs, in one style (StatusBar.amounts): "4½ × 8 studs"
## only where every number is a whole quarter. "" for nothing measured.
func studs_words() -> String:
	if is_empty():
		return ""
	var said: PackedStringArray = StatusBar.amounts([box.size.x / BrickLattice.STUD,
		box.size.z / BrickLattice.STUD, plates_high()])
	var across: String = "%s × %s studs" % [said[0], said[1]]
	if said[2] == "1":
		return across + ", 1 plate high"
	return across + ", %s plates high" % said[2]


## "3.60 × 8.64 × 4.96 cm", to the tenth of a millimetre. "" for nothing.
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


## "About 52 g", Properties' words for the status bar's "52 g" ([method
## grams_words]).
func weight_words() -> String:
	return "About %s" % grams_words()


## "52 g", to the gram, as the status bar says it beside the counts.
func grams_words() -> String:
	return "%s g" % ("%.0f" % grams)


## "1 part not in the library, not counted", or "".
func left_out_words() -> String:
	if left_out == 0:
		return ""
	return "1 part not in the library, not counted" if left_out == 1 \
		else "%d parts not in the library, not counted" % left_out


## A length in centimetres to the tenth of a millimetre, two places always:
## "12.80", "2.08". "3.6 × 8.64" put one place beside two.
static func cm(value: float) -> String:
	return "%.2f" % value
