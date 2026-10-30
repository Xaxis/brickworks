## Building from a set's parts: what a set has, by part and colour, and
## how many of each are left once the model's own are taken off, as
## LDCad's bins and Studio's set palettes keep them, for building something
## else from a set a person owns (Rebrickable's alternate builds).
##
## Several sets are one bin with their counts added: two sets combined, or
## every set in a collection. The counts left are never kept: each time the
## model changes they are worked out again from the model and the sets
## ([method used_in], [method left]), so a part put down, an undo, a delete,
## a model opened all count the same and nothing can drift.
##
## In Collection's spelling (Collection.key_of: the number a part means
## today, the colour a shop files it under), so a tyre placed in Rubber
## Black counts against the set's Black tyres.
class_name SetBin
extends RefCounted

## The choice, kept in the model's file after its first line, as the
## app's other lines are (ModelStore.with_share): the sets by number, one
## word a copy.
const META := "0 !BRICKWORKS BIN "

## The sets, one entry a copy: ["10497-1"], or ["10497-1", "31120-1"].
var sets: PackedStringArray = PackedStringArray()
## Which sets, in words: "10497-1 Galaxy Explorer".
var title: String = ""
## Part and colour -> how many the sets hold.
var have: Dictionary = {}
## The keys of [member have] a bin can show, the most held first, then by
## part and colour: the order its tiles stay in as the counts change.
var order: PackedStringArray = PackedStringArray()
## How many pieces the sets hold in all, and how many of them are of
## parts this build cannot draw.
var pieces: int = 0
var unshown: int = 0


## A bin of [param numbers]' parts, from their records ([param records]:
## set number -> SetInventories' {"n", "p": [[part, colour, qty]]}). Null
## when none of them has a record. A number given twice is two copies.
static func make(numbers: PackedStringArray, records: Dictionary, library: PartLibrary) -> SetBin:
	var bin := SetBin.new()
	var copies: Dictionary = {}
	for number: String in numbers:
		if not records.has(number):
			continue
		bin.sets.append(number)
		copies[number] = int(copies.get(number, 0)) + 1
		for row: Variant in (records[number] as Dictionary).get("p", []):
			if not row is Array or (row as Array).size() < 3:
				continue
			var lot: Array = row
			var key: String = Collection.key_of(str(lot[0]), int(lot[1]), library)
			bin.have[key] = int(bin.have.get(key, 0)) + int(lot[2])
			bin.pieces += int(lot[2])
	if bin.sets.is_empty():
		return null
	var named := PackedStringArray()
	for number: String in copies:
		var words: String = ("%s %s" % [number, str((records[number] as Dictionary).get("n", ""))]).strip_edges()
		named.append(words if int(copies[number]) == 1 else "%d × %s" % [int(copies[number]), words])
	bin.title = named[0] if named.size() == 1 else (" and ".join(named) if named.size() == 2
		else "%d sets" % bin.sets.size())
	var shown: Array = []
	for key: String in bin.have:
		var info: PartLibrary.PartInfo = library.parts.get(Collection.part_of(key)) if library != null else null
		if library != null and (info == null or not info.reachable or info.is_redirect()):
			bin.unshown += int(bin.have[key])
			continue
		shown.append(key)
	var held: Dictionary = bin.have
	shown.sort_custom(func(a: String, b: String) -> bool:
		return int(held[a]) > int(held[b]) if int(held[a]) != int(held[b]) else a < b)
	bin.order = PackedStringArray(shown)
	return bin


## The parts [param world] is built of, by part and colour, its baseplate
## ([param scenery]) left out.
static func used_in(world: BrickWorld, scenery: Dictionary, library: PartLibrary) -> Dictionary:
	# Counted by part and colour as the bricks have them, and only then put
	# in Collection's spelling, a kind at a time: spelled out for every
	# brick, the counts over 3,000 parts took 5 ms.
	var raw: Dictionary = {}     ## part -> colour -> how many
	for item: Variant in world.bricks():
		var brick: BrickWorld.Brick = item
		if scenery.has(brick.id):
			continue
		var by_colour: Variant = raw.get(brick.part_id)
		if by_colour == null:
			by_colour = {}
			raw[brick.part_id] = by_colour
		(by_colour as Dictionary)[brick.color_code] = (by_colour as Dictionary).get(brick.color_code, 0) + 1
	var used: Dictionary = {}
	for part: String in raw:
		var by_colour: Dictionary = raw[part]
		for colour: int in by_colour:
			var key: String = Collection.key_of(part, colour, library)
			used[key] = int(used.get(key, 0)) + int(by_colour[colour])
	return used


## How many of [param key] are left once [param used] is taken off: below
## nought when the model has more of it than the sets.
func left(key: String, used: Dictionary) -> int:
	return int(have.get(key, 0)) - int(used.get(key, 0))


## The whole bin against [param used]: {"left": pieces left of what the
## sets hold, "over": pieces the model has past them, its parts the sets
## have none of among them (stickers and the like, which nobody owns on
## their own, not counted: Collection.ownable)}.
func tally(used: Dictionary, library: PartLibrary) -> Dictionary:
	var still: int = 0
	for key: String in have:
		still += maxi(0, left(key, used))
	var over: int = 0
	for key: String in used:
		var past: int = -left(key, used)
		if past > 0 and (library == null or Collection.ownable(Collection.part_of(key), library)):
			over += past
	return {"left": still, "over": over}


## The sets a model's [param text] says its bin was built from, or none.
static func read(text: String) -> PackedStringArray:
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^0 !BRICKWORKS BIN ([0-9A-Za-z. -]{1,600})\\s*$").search(text)
	var out := PackedStringArray()
	if found == null:
		return out
	for word: String in found.get_string(1).split(" ", false):
		var number: String = SetInventories.normal(word)
		if RegEx.create_from_string("^[0-9a-z.]+-[0-9]+$").search(number) != null and out.size() < 50:
			out.append(number)
	return out


## [param text] with [param numbers] on a line after its first, inside
## the model itself for an .mpd, as ModelStore.with_share writes its own;
## as it is for none.
static func written_into(text: String, numbers: PackedStringArray) -> String:
	if numbers.is_empty():
		return text
	var line: String = META + " ".join(numbers) + "\n"
	var cut: int = text.find("\n")
	if cut < 0:
		return text + "\n" + line
	return text.substr(0, cut + 1) + line + text.substr(cut + 1)
