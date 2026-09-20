## What you would have to buy to build this for real.
##
## A model on screen is a design; a pile of bricks on a table is a build,
## and the thing standing between them is a list. Which parts, in which
## colours, how many of each. Without it the only way to source a design
## is to turn it around and count, which nobody is going to do for four
## hundred pieces.
##
## A "lot" here is what a shop calls one: a part in a colour. Two red 2x4
## bricks and one blue 2x4 are two lots and three pieces, and the
## distinction matters because a lot is what you actually order.
##
## The baseplate is left out by default, for the same reason it is not a
## build step: you are standing the model on it, not building it.
class_name Inventory
extends RefCounted


## One part, in one colour, and how many of it.
class Lot extends RefCounted:
	var part_id: String
	var name: String
	var color_code: int
	var color_name: String
	var count: int = 0
	## Grams for one of them, from the same shell model the stability
	## check uses. Derived rather than looked up, and it runs a little
	## light on longer parts — see Stability.grams.
	var each_grams: float = 0.0

	func total_grams() -> float:
		return each_grams * count


var lots: Array[Lot] = []
var pieces: int = 0
var grams: float = 0.0


func lot_count() -> int:
	return lots.size()


## Take stock of everything in the world.
##
## [param skip] names bricks that are not part of the build — the
## baseplate. Pass an empty dictionary to count it too.
static func of(world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}) -> Inventory:
	var inventory := Inventory.new()
	var by_key: Dictionary = {}

	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id):
			continue
		var key: String = "%s:%d" % [brick.part_id, brick.color_code]
		var lot: Lot = by_key.get(key)
		if lot == null:
			var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
			var color: PartLibrary.BrickColor = library.color(brick.color_code)
			lot = Lot.new()
			lot.part_id = brick.part_id
			lot.name = _tidy(info.name if info != null else brick.part_id)
			lot.color_code = brick.color_code
			lot.color_name = color.name if color != null else "colour %d" % brick.color_code
			lot.each_grams = Stability.grams(info) if info != null else 0.0
			by_key[key] = lot
			inventory.lots.append(lot)
		lot.count += 1
		inventory.pieces += 1
		inventory.grams += lot.each_grams

	# Grouped by part, and the parts ordered by how many of them there
	# are altogether.
	#
	# Sorting on the lot count alone looked right and was not: a 2 x 2
	# brick in four colours became four rows scattered down the page,
	# and finding out how many 2 x 2 bricks a model needs meant reading
	# the whole list. You look a part up once and want all its colours
	# together — that is what a shop's catalogue does and what a parts
	# drawer does.
	var per_part: Dictionary = {}
	for lot: Lot in inventory.lots:
		per_part[lot.part_id] = int(per_part.get(lot.part_id, 0)) + lot.count

	inventory.lots.sort_custom(func(a: Lot, b: Lot) -> bool:
		var a_total: int = int(per_part[a.part_id])
		var b_total: int = int(per_part[b.part_id])
		if a_total != b_total:
			return a_total > b_total
		# Same size of group: keep a part's own rows adjacent, which
		# sorting by the group total alone does not guarantee.
		if a.part_id != b.part_id:
			return a.name < b.name if a.name != b.name else a.part_id < b.part_id
		if a.count != b.count:
			return a.count > b.count
		# Ties by name, so the same model always lists the same way — a
		# list that reshuffles between exports cannot be diffed.
		return a.color_name < b.color_name)
	return inventory


## LDraw pads names into columns — "Brick  2 x  4" — which reads as a
## typo anywhere the column is not there.
static func _tidy(raw: String) -> String:
	var name: String = raw.strip_edges()
	while name.contains("  "):
		name = name.replace("  ", " ")
	return name


## For a spreadsheet, or for pasting into a shop's bulk-add box.
##
## The colour goes out as both the LDraw number and its name. The number
## is exact and the name is what a shop's own list is keyed on, and
## neither alone is enough: LDraw codes mean nothing to a seller, and
## colour names differ enough between catalogues that a name on its own
## can be guessed wrong.
func to_csv() -> String:
	var rows := PackedStringArray()
	rows.append("part,name,ldraw_colour,colour,quantity,grams_each,grams_total")
	for lot: Lot in lots:
		rows.append("%s,%s,%d,%s,%d,%.2f,%.2f" % [
			_csv(lot.part_id), _csv(lot.name), lot.color_code,
			_csv(lot.color_name), lot.count, lot.each_grams, lot.total_grams()])
	return "\n".join(rows) + "\n"


static func _csv(field: String) -> String:
	if field.contains(",") or field.contains("\"") or field.contains("\n"):
		return "\"%s\"" % field.replace("\"", "\"\"")
	return field


## The same thing to read rather than to parse.
func to_text(title: String = "Model") -> String:
	var lines := PackedStringArray()
	lines.append("%s — %d pieces in %d lots, %s" % [
		title, pieces, lots.size(), weight()])
	lines.append("")
	for lot: Lot in lots:
		lines.append("%4d x  %-9s %-34s %s" % [
			lot.count, lot.part_id, lot.name.substr(0, 34), lot.color_name])
	return "\n".join(lines) + "\n"


## Grams under a kilo, kilograms over it. A model is usually the first
## and a large one is the second, and "1348 g" reads worse than "1.35 kg".
func weight() -> String:
	if grams < 1000.0:
		return "%.0f g" % grams
	return "%.2f kg" % (grams / 1000.0)
