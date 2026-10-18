## What a model stands on: a baseplate, a grid on the ground, or nothing.
##
## Every model stood on a 32 x 32 dark green baseplate that nobody chose,
## and nobody could take away. That is right for a diorama and wrong for a
## car: a real car set has no plate in the box, and a picture of one on a
## green square reads as a car parked on a lawn. Studio, LDD and Mecabricks
## start on a plain floor and make a baseplate a part like any other;
## LeoCAD has a grid floor. So each model says which it wants:
##
##   BASEPLATE  a real baseplate under it, of a size and a colour that
##              baseplates are made in. Scenery (ModelStore.scenery): not
##              saved, not counted, until the person makes it part of the
##              model (FloorLayer.adopt).
##   GRID       no plate: a faint ground with a line between every stud,
##              the stud lattice a first part lands on, as Studio's floor.
##   NONE       empty space. Parts still rest on the ground at y = 0.
##
## Written into the model file as a meta line other programs ignore, the
## way the shared link is (ModelStore.SHARE_META):
##
##   0 !BRICKWORKS FLOOR BASEPLATE 32 32 288
##   0 !BRICKWORKS FLOOR GRID
##   0 !BRICKWORKS FLOOR NONE
class_name ModelFloor
extends RefCounted

const BASEPLATE := "baseplate"
const GRID := "grid"
const NONE := "none"
const KINDS: Array[String] = [BASEPLATE, GRID, NONE]

const META := "0 !BRICKWORKS FLOOR "

## The sizes the View menu offers by name, in studs: the three square
## baseplates LEGO sells (3867, 3811, 4186).
const SIZES: Array[int] = [16, 32, 48]
## The least and most a custom size may be, in studs a side. Real
## baseplates are cut in eights, so a custom size is too (see plates).
const LEAST := 8
const MOST := 192

## The colours baseplates are made in, by LDraw code, as LDraw names them:
## grass, the newer bright grass, the old dark one, sand and desert, road
## and pavement greys, sand green, water, snow, space and the classic grey.
const COLOURS: Array = [
	[2, "Green"], [10, "Bright Green"], [288, "Dark Green"], [19, "Tan"],
	[28, "Dark Tan"], [71, "Light Bluish Grey"], [72, "Dark Bluish Grey"],
	[378, "Sand Green"], [1, "Blue"], [15, "White"], [0, "Black"], [7, "Light Grey"],
]

## A plate in one piece for these sizes, across x deep in studs: every
## plain baseplate LDraw has, so a size any of them is comes as that part.
## x is along x, the part's own long side as LDraw draws it.
const ONE_PIECE: Dictionary = {
	Vector2i(16, 16): "3867", Vector2i(32, 32): "3811", Vector2i(48, 48): "4186",
	Vector2i(50, 50): "782", Vector2i(32, 16): "3857", Vector2i(16, 8): "3865",
	Vector2i(24, 8): "3497", Vector2i(32, 8): "4187", Vector2i(24, 16): "3334",
	Vector2i(40, 24): "3645",
}

var kind: String = BASEPLATE
## Studs along x and along z.
var across: int = 32
var deep: int = 32
## An LDraw colour code.
var colour: int = 288


static func make(what: String, wide: int = 32, long: int = 32, code: int = 288) -> ModelFloor:
	var made := ModelFloor.new()
	made.kind = what if what in KINDS else BASEPLATE
	made.across = clampi(wide, LEAST, MOST)
	made.deep = clampi(long, LEAST, MOST)
	made.colour = code
	return made


func copy() -> ModelFloor:
	return ModelFloor.make(kind, across, deep, colour)


func same_as(other: ModelFloor) -> bool:
	return other != null and to_meta() == other.to_meta()


func is_plate() -> bool:
	return kind == BASEPLATE


## The meta line, without its line break.
func to_meta() -> String:
	if kind == BASEPLATE:
		return "%s%s %d %d %d" % [META, kind.to_upper(), across, deep, colour]
	return META + kind.to_upper()


## What the meta line said after FLOOR, read back; null for anything that
## is not one, so a file edited by hand cannot leave a model on nothing.
static func parse(words: String) -> ModelFloor:
	var said: PackedStringArray = words.strip_edges().split(" ", false)
	if said.is_empty():
		return null
	var what: String = said[0].to_lower()
	if not what in KINDS:
		return null
	# A grid or no floor saved says only that; the history keeps the size
	# and colour it last had as well (whole_words), so a baseplate put back
	# comes back as it was.
	if said.size() < 4 or not said[1].is_valid_int() or not said[2].is_valid_int() \
			or not said[3].is_valid_int():
		return ModelFloor.make(what)
	return ModelFloor.make(what, said[1].to_int(), said[2].to_int(), said[3].to_int())


## Every word of it, the size and colour too whatever the kind: what the
## history keeps (FloorLayer.state).
func whole_words() -> String:
	return "%s %d %d %d" % [kind.to_upper(), across, deep, colour]


## The floor a model's text says it stands on, or null when it says none.
static func read(text: String) -> ModelFloor:
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^0 !BRICKWORKS FLOOR (.*)$").search(text)
	return parse(found.get_string(1)) if found != null else null


## [param text] with the floor's line in the head of its model: after the
## title, the name and the author, before the first blank line (or the
## first part, in a file written elsewhere). Any floor line it had goes.
## Before a ROTSTEP that turns the first step, which the booklet's lines put
## before the first part: after it, each save moved the line past it.
func written_into(text: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	var kept := PackedStringArray()
	for line: String in lines:
		if not line.begins_with(META):
			kept.append(line)
	var at: int = kept.size()
	for n: int in kept.size():
		var line: String = kept[n].strip_edges()
		if n > 0 and (line.is_empty() or line.begins_with("1 ") or line.begins_with("0 FILE")
				or line == "0 STEP" or line.to_upper().begins_with("0 ROTSTEP")):
			at = n
			break
	kept.insert(at, to_meta())
	return "\n".join(kept)


## In words, for a menu or a line in the status bar.
func words() -> String:
	match kind:
		GRID:
			return "Grid floor"
		NONE:
			return "No floor"
	return "Baseplate %d × %d, %s" % [across, deep, colour_name(colour)]


static func colour_name(code: int) -> String:
	for pair: Array in COLOURS:
		if int(pair[0]) == code:
			return str(pair[1])
	return "colour %d" % code


## The floor new models get: the person's setting (Settings), or the dark
## green 32 x 32 every model had before there was a choice.
static func preferred() -> ModelFloor:
	var kept: ModelFloor = parse(str(ShellPrefs.value("new_floor")))
	return kept if kept != null else ModelFloor.make(BASEPLATE)


static func prefer(chosen: ModelFloor) -> void:
	ShellPrefs.put("new_floor", chosen.to_meta().trim_prefix(META))


## The real baseplates that make a W x D floor, each [part id, centre in
## LDU from the floor's middle, turned a quarter]. One part where LDraw has
## a plate that size; otherwise cut into the plates LEGO sells, so a floor
## made part of the model is parts a shop has.
##
## Custom sizes are cut in eights. Each side is split into runs of 32, 24
## and 16 studs (any multiple of eight from 16 up is, and 8 is a run of
## its own), and every pair of runs is a plate LDraw has or two that are:
## 24 x 24 is 16 x 24 and 8 x 24, 24 x 32 is 16 x 32 and 8 x 32.
func plates() -> Array:
	if across == 50 and deep == 50:
		return [["782", Vector3.ZERO, false]]
	var wide: int = _eights(across)
	var long: int = _eights(deep)
	var one: Array = _piece(wide, long)
	if not one.is_empty():
		return [[one[0], Vector3.ZERO, one[1]]]
	var out: Array = []
	var x0: float = -wide * BrickLattice.STUD * 0.5
	for run_x: int in _runs(wide):
		var z0: float = -long * BrickLattice.STUD * 0.5
		for run_z: int in _runs(long):
			for cut: Array in _cut(run_x, run_z):
				# [part, x and z of its corner within the cell, its size, turned]
				var corner: Vector2i = cut[1]
				var size: Vector2i = cut[2]
				var middle := Vector3(
					x0 + (corner.x + size.x * 0.5) * BrickLattice.STUD, 0.0,
					z0 + (corner.y + size.y * 0.5) * BrickLattice.STUD)
				out.append([cut[0], middle, cut[3]])
			z0 += run_z * BrickLattice.STUD
		x0 += run_x * BrickLattice.STUD
	return out


## The size a side of [param studs] is laid at: the nearest whole eight.
static func _eights(studs: int) -> int:
	return maxi(int(round(studs / 8.0)) * 8, LEAST)


## The size this floor is laid at, in studs: what a custom size comes to
## once it is cut into real plates.
func laid_size() -> Vector2i:
	if across == 50 and deep == 50:
		return Vector2i(50, 50)
	return Vector2i(_eights(across), _eights(deep))


## A one-piece baseplate of this size: [part, turned], or [].
static func _piece(wide: int, long: int) -> Array:
	if ONE_PIECE.has(Vector2i(wide, long)):
		return [ONE_PIECE[Vector2i(wide, long)], false]
	if ONE_PIECE.has(Vector2i(long, wide)):
		return [ONE_PIECE[Vector2i(long, wide)], true]
	return []


## A side cut into runs of 32, 24, 16 and 8 studs.
static func _runs(studs: int) -> Array[int]:
	var out: Array[int] = []
	var left: int = studs
	while left > 48:
		out.append(32)
		left -= 32
	match left:
		48: out.append_array([32, 16])
		40: out.append_array([24, 16])
		32, 24, 16, 8: out.append(left)
	return out


## One cell of runs as plates: [[part, corner in studs, size, turned]].
static func _cut(wide: int, long: int) -> Array:
	var one: Array = _piece(wide, long)
	if not one.is_empty():
		return [[one[0], Vector2i.ZERO, Vector2i(wide, long), one[1]]]
	# A side of 24 is a strip of 16 and one of 8.
	if wide == 24:
		return _shifted(_cut(16, long), Vector2i.ZERO) + _shifted(_cut(8, long), Vector2i(16, 0))
	if long == 24:
		return _shifted(_cut(wide, 16), Vector2i.ZERO) + _shifted(_cut(wide, 8), Vector2i(0, 16))
	# 8 x 8 is the one size no baseplate comes in: half of a 16 x 8 would
	# do, and is not a part. Two of 8 x 8 make a 16 x 8 where the runs
	# allow, which _runs arranges; a lone one is a plate, 41539.
	return [["41539", Vector2i.ZERO, Vector2i(wide, long), false]]


static func _shifted(cuts: Array, by: Vector2i) -> Array:
	var out: Array = []
	for cut: Array in cuts:
		out.append([cut[0], (cut[1] as Vector2i) + by, cut[2], cut[3]])
	return out


## The floor a baseplate brick of this part is, by its size: its studs
## along x and z as it lies.
static func size_of(info: PartLibrary.PartInfo, basis: Basis) -> Vector2i:
	if info == null:
		return Vector2i.ZERO
	var size: Vector3 = (basis.orthonormalized() * info.size).abs()
	return Vector2i(int(round(size.x / BrickLattice.STUD)), int(round(size.z / BrickLattice.STUD)))
