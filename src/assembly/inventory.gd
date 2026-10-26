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
	## LEGO's own name for the colour, from LDConfig: what LDraw and
	## BrickLink call Light Bluish Grey, LEGO calls Medium Stone Grey, and
	## LEGO's name is what its own shop and a Pick a Brick order use.
	## Empty where LDConfig gives none.
	var lego_colour: String = ""
	## Rebrickable's number for the colour, which is what its parts-list
	## import reads. -1 where the colour join reaches none. BrickLink's
	## numbers are not on disk anywhere, so there are none here: a
	## guessed one would order the wrong colour.
	var rebrickable_colour: int = -1
	var count: int = 0
	## The LEGO element number, which is what a shop or a warehouse
	## actually picks: "Brick 2 x 4 in Bright Red" is a description,
	## 300121 is the thing you can order. Empty where the index has no
	## entry, which is most of the library — never shown as a dash or a
	## zero, because that reads as "no such element".
	var element: String = ""
	## The colour as six hex digits, for anywhere that wants markup
	## rather than a Color.
	var rgb_hex: String = "888888"
	## Grams for one of them, from the same shell model the stability
	## check uses. Derived rather than looked up, and it runs a little
	## light on longer parts — see Stability.grams.
	var each_grams: float = 0.0
	## Made in the element maker: not a part anyone can order.
	var custom: bool = false
	## The numbers BrickLink and Rebrickable list the part under, which
	## are not always LDraw's (PartLibrary.shop_part).
	var bricklink_id: String = ""
	var rebrickable_id: String = ""
	## The bricks counted in it, by id: a hose's every piece, for a lot that
	## is one. What the parts list selects when its row is clicked.
	var bricks: PackedInt64Array = []

	func total_grams() -> float:
		return each_grams * count


var lots: Array[Lot] = []
var pieces: int = 0
## The bricks of the model that are no piece of their own (is_piece): the
## cable segments and the like a bigger part is drawn with.
var drawn_in_pieces: int = 0
var _not_pieces: Dictionary = {}
var grams: float = 0.0
## The flexible items counted as one part: item path -> its Lot, and each
## of their bricks -> its item's path. A hose laid along a bend is an end,
## thirty rings and an end in the model and one hose in a shop.
var items: Dictionary = {}
var whole_of: Dictionary = {}
## item path -> the id of its first piece, which stands for it in a step.
var _first: Dictionary = {}


func lot_count() -> int:
	return lots.size()


## Take stock of everything in the world.
##
## [param skip] names bricks that are not part of the build — the
## baseplate. Pass an empty dictionary to count it too.
##
## A ribbed hose, a pneumatic tube, a flexible axle or a string laid along
## a bend is counted as the one part LEGO sells, of the length it was laid
## as: ordering its segments would order parts nobody makes. A chain or a
## tread is its links, which are what is sold.
static func of(world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}) -> Inventory:
	var inventory := Inventory.new()
	var by_key: Dictionary = {}

	var whole: Dictionary = _sold_whole(world, library, skip)
	for path: String in whole:
		var item: Dictionary = whole[path]
		var lot: Lot = inventory._add(by_key, library, str(item["part"]), int(item["color"]))
		inventory.items[path] = lot
		var first: int = -1
		for brick: BrickWorld.Brick in item["bricks"]:
			lot.bricks.append(brick.id)
			inventory.whole_of[brick.id] = path
			if first < 0 or brick.id < first:
				first = brick.id
		inventory._first[path] = first
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id) or inventory.whole_of.has(brick.id):
			continue
		if not is_piece(brick.part_id, library):
			inventory.drawn_in_pieces += 1
			inventory._not_pieces[brick.id] = true
			continue
		inventory._add(by_key, library, brick.part_id, brick.color_code).bricks.append(brick.id)

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


## The lot a brick is counted in, by its "part:colour" key. A flexible
## item's first piece stands for the whole of it and the rest are "", so a
## booklet step lists the hose once, where it goes in.
func key_of(brick: BrickWorld.Brick) -> String:
	if _not_pieces.has(brick.id):
		return ""
	var path: String = str(whole_of.get(brick.id, ""))
	if path.is_empty():
		return "%s:%d" % [brick.part_id, brick.color_code]
	if int(_first[path]) != brick.id:
		return ""
	var lot: Lot = items[path]
	return "%s:%d" % [lot.part_id, lot.color_code]


## How many pieces [method of] would count, without making the list: what
## the counts line says, the toast when a model opens and an opened model's
## answer over MCP.
static func pieces_in(world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}) -> int:
	return pieces_among(world.bricks(), library, skip)


## [method pieces_in] of [param bricks]: one count of a model's parts, the
## one a builder means, whether it stands in the world or is a file read.
static func pieces_among(bricks: Array, library: PartLibrary, skip: Dictionary = {}) -> int:
	var whole: Dictionary = _sold_whole_among(bricks, library, skip)
	var count: int = whole.size()
	var in_whole: Dictionary = {}
	for path: String in whole:
		for brick: BrickWorld.Brick in whole[path]["bricks"]:
			in_whole[brick.id] = true
	for brick: BrickWorld.Brick in bricks:
		if not skip.has(brick.id) and not in_whole.has(brick.id) \
				and is_piece(brick.part_id, library):
			count += 1
	return count


## A model file's part count, as [method pieces_in] counts it once the file is
## opened, without opening it: what the Library's card says of a model
## (tools/library_build.py, from collection_models' "c"), and its box beside
## it. Read as opening reads it (ModelStore._open_into): the parts the file
## carries and its hoses' skins join the library first
## (CustomParts.take_into), so what each is, a piece or a bit of one, is
## read from what they are there; its sub-models expanded; a reference the
## library has no part for (a primitive placed straight into the model) is
## not drawn, and not counted. Read by its first lines alone, the D11 counted
## 13 primitives and 12 of its own parts the catalogue names with a ~, and
## 10179-1 none of its three hoses.
static func count_of_text(text: String, library: PartLibrary) -> int:
	var model: LdrModel = LdrModel.parse(text, "model")
	if model == null:
		return 0
	CustomParts.take_into([], library, model, null)
	var bricks: Array = []
	for placement: LdrModel.Placement in model.flatten(library.parts):
		var part: String = library.resolve(ModelStore.studio_part(placement.part_id, library))
		if not library.parts.has(part):
			continue
		var brick := BrickWorld.Brick.new(bricks.size() + 1, part, placement.color_code,
			placement.transform)
		brick.group = placement.group
		brick.unit = placement.unit
		bricks.append(brick)
	return pieces_among(bricks, library)


## Whether a part is a piece a builder takes out of the box, as a model's
## part count counts it: not one of the bits LDraw draws a bigger part with
## and names with a ~ (a motor's cable as 1,300 ribbon segments, a hose's
## centre), nor a hose or a string drawn link by link (Flexible_Section),
## unless the ~ only says the number moved. The Cat D11 opened as 6,793
## parts, 2,891 of them its four motors' cable segments, where its box holds
## 3,853 (walk256's D11). Collection.ownable, less its stickers, which are in
## the model and on the box's sheet.
static func is_piece(part_id: String, library: PartLibrary) -> bool:
	if library == null:
		return true
	var info: PartLibrary.PartInfo = library.parts.get(library.resolve(part_id))
	if info == null:
		return true
	return info.category == "Sticker" or Collection.ownable(part_id, library)


## The flexible items sold as one part: item path -> {"part", "color",
## "bricks"}. The colour is its pieces' own, the most of them where a file
## has them in two.
static func _sold_whole(world: BrickWorld, library: PartLibrary,
		skip: Dictionary) -> Dictionary:
	return _sold_whole_among(world.bricks(), library, skip)


static func _sold_whole_among(bricks: Array, library: PartLibrary,
		skip: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var laid: Dictionary = Flex.items_among(bricks, skip)
	for path: String in laid:
		var item: Dictionary = laid[path]
		var pieces: Array = []
		var colours: Dictionary = {}
		for brick: BrickWorld.Brick in item["bricks"]:
			pieces.append({"part": brick.part_id, "at": brick.transform})
			colours[brick.color_code] = int(colours.get(brick.color_code, 0)) + 1
		var part: String = Flex.real_part(library, str(item["kind"]), pieces)
		if part.is_empty():
			continue
		var colour: int = int(colours.keys()[0])
		for code: int in colours:
			if int(colours[code]) > int(colours[colour]):
				colour = code
		out[path] = {"part": part, "color": colour, "bricks": item["bricks"]}
	return out


## One more of a part in a colour, in its lot.
func _add(by_key: Dictionary, library: PartLibrary, part_id: String, color_code: int) -> Lot:
	var key: String = "%s:%d" % [part_id, color_code]
	var lot: Lot = by_key.get(key)
	if lot == null:
		var info: PartLibrary.PartInfo = library.parts.get(part_id)
		var color: PartLibrary.BrickColor = library.color(color_code)
		lot = Lot.new()
		lot.part_id = part_id
		lot.name = _tidy(info.name if info != null else part_id)
		# A made part has no element number and no shop to buy it from:
		# the list says so rather than leaving it to look like one LEGO
		# makes.
		if info != null and info.custom:
			lot.name += " (custom element)"
			lot.custom = true
		lot.color_code = color_code
		lot.color_name = color.name if color != null else "colour %d" % color_code
		if color != null:
			lot.rgb_hex = "%02x%02x%02x" % [
				int(color.rgb.r * 255.0), int(color.rgb.g * 255.0),
				int(color.rgb.b * 255.0)]
			# A tyre in Rubber Black is sold as a Black one.
			var plain: PartLibrary.BrickColor = library.color(
				library.plain_code(color_code))
			lot.lego_colour = plain.lego_name
			lot.rebrickable_colour = plain.rebrickable_id
		lot.each_grams = Stability.grams(info) if info != null else 0.0
		lot.element = library.element_for(part_id, color_code)
		lot.bricklink_id = library.shop_part(part_id, "BrickLink")
		lot.rebrickable_id = library.shop_part(part_id, "Rebrickable")
		by_key[key] = lot
		lots.append(lot)
	lot.count += 1
	pieces += 1
	grams += lot.each_grams
	return lot


## LDraw pads names into columns — "Brick  2 x  4" — which reads as a
## typo anywhere the column is not there.
static func _tidy(raw: String) -> String:
	var name: String = raw.strip_edges()
	while name.contains("  "):
		name = name.replace("  ", " ")
	return name


## For a spreadsheet, or for pasting into a shop's bulk-add box.
##
## The colour goes out as the LDraw number and its name, LEGO's name for
## it, and Rebrickable's number. The LDraw number is exact and the name
## is what a shop's own list is keyed on, and neither alone is enough:
## LDraw codes mean nothing to a seller, and colour names differ enough
## between catalogues that a name on its own can be guessed wrong — the
## same grey is Light Bluish Grey to BrickLink and Medium Stone Grey to
## LEGO. The two added columns go last, so a reader of the first eight
## still finds them where they were. Blank where unknown.
func to_csv() -> String:
	var rows := PackedStringArray()
	rows.append("part,element,name,ldraw_colour,colour,quantity,"
		+ "grams_each,grams_total,lego_colour,rebrickable_colour")
	for lot: Lot in lots:
		rows.append("%s,%s,%s,%d,%s,%d,%.2f,%.2f,%s,%s" % [
			_csv(lot.part_id), lot.element, _csv(lot.name), lot.color_code,
			_csv(lot.color_name), lot.count, lot.each_grams, lot.total_grams(),
			_csv(lot.lego_colour),
			"" if lot.rebrickable_colour < 0 else str(lot.rebrickable_colour)])
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
		lines.append("%4d x  %-9s %-8s %-32s %s" % [
			lot.count, lot.part_id, lot.element,
			lot.name.substr(0, 32), lot.color_name])
	return "\n".join(lines) + "\n"


## Grams under a kilo, kilograms over it. A model is usually the first
## and a large one is the second, and "1348 g" reads worse than "1.35 kg".
func weight() -> String:
	if grams < 1000.0:
		return "%.0f g" % grams
	return "%.2f kg" % (grams / 1000.0)
