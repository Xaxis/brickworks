## What a person owns, and the sums done with it.
##
## A collection is what somebody said they have: sets by number, and
## loose parts by part, colour and how many. Everything here is in LDraw's
## numbers — api/collection.js maps every import into them before it is
## kept — so a part the model uses and a part in the drawer can be
## compared directly.
##
## The sums, all pure, so a probe checks them with numbers it chose:
##
##   pool        the sets expanded through their inventories, plus the
##               loose parts: part and colour -> how many are on hand
##   shortfall   what a model needs that the pool cannot give
##   plan        the same, with what could stand in: the part in another
##               colour that is spare, or two smaller parts in the right
##               colour that make the same footprint
##   coverage    how much of a model the pool already holds, for ranking
##               what could be built
##
## A part is compared by the number it means today (PartLibrary.resolve:
## LDraw retires numbers and keeps a stub) and a colour by the one a shop
## files it under (PartLibrary.plain_code: a tyre in Rubber Black is a
## Black tyre), on both sides, so the two ends of a comparison cannot be
## spelled differently.
class_name Collection
extends RefCounted

## [{"set": "10237-1", "qty": 1, "spares": false}, ...]
var sets: Array = []
## [{"part": "3001", "colour": 4, "qty": 12}, ...]
var parts: Array = []
## When the account last kept it, as the server says; empty when never.
var updated_at: String = ""

## Set numbers [method pool] was given no inventory for, last time.
var unknown_sets: PackedStringArray = PackedStringArray()


static func from_json(data: Variant) -> Collection:
	var made := Collection.new()
	if typeof(data) != TYPE_DICTIONARY:
		return made
	var body: Dictionary = data
	for entry: Variant in body.get("sets", []):
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("set", "")) != "":
			made.sets.append({"set": str(entry["set"]), "qty": maxi(1, int(entry.get("qty", 1))),
				"spares": bool(entry.get("spares", false))})
	for entry: Variant in body.get("parts", []):
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("part", "")) != "":
			made.parts.append({"part": str(entry["part"]), "colour": int(entry.get("colour", 0)),
				"qty": maxi(1, int(entry.get("qty", 1)))})
	var when: Variant = body.get("updated_at")
	made.updated_at = str(when) if when != null else ""
	return made


func to_json() -> Dictionary:
	return {"sets": sets, "parts": parts, "updated_at": updated_at}


func is_empty() -> bool:
	return sets.is_empty() and parts.is_empty()


func set_numbers() -> PackedStringArray:
	var out := PackedStringArray()
	for entry: Dictionary in sets:
		out.append(str(entry["set"]))
	return out


func loose_pieces() -> int:
	var total: int = 0
	for entry: Dictionary in parts:
		total += int(entry["qty"])
	return total


## The one spelling of a part and a colour that both sides are compared by.
static func key_of(part: String, colour: int, library: PartLibrary = null) -> String:
	var id: String = part.to_lower()
	var code: int = colour
	if library != null:
		id = library.resolve(id)
		code = library.plain_code(colour)
	return "%s/%d" % [id, code]


static func part_of(key: String) -> String:
	return key.get_slice("/", 0)


static func colour_of(key: String) -> int:
	return int(key.get_slice("/", 1))


## Everything on hand: part and colour -> how many.
##
## [param inventories] is set number -> its record from
## tools/collection_data.py ({"n", "y", "p": [[part, colour, qty]], "s"}).
## A set with no record is counted in [member unknown_sets] and adds
## nothing, rather than being guessed at.
func pool(inventories: Dictionary, library: PartLibrary = null) -> Dictionary:
	var on_hand: Dictionary = {}
	unknown_sets = PackedStringArray()
	for entry: Dictionary in parts:
		_add(on_hand, key_of(str(entry["part"]), int(entry["colour"]), library), int(entry["qty"]))
	for entry: Dictionary in sets:
		var record: Variant = inventories.get(str(entry["set"]))
		if typeof(record) != TYPE_DICTIONARY:
			unknown_sets.append(str(entry["set"]))
			continue
		var times: int = int(entry["qty"])
		var rows: Array = (record as Dictionary).get("p", [])
		if bool(entry.get("spares", false)):
			rows = rows + (record as Dictionary).get("s", [])
		for row: Variant in rows:
			var lot: Array = row
			_add(on_hand, key_of(str(lot[0]), int(lot[1]), library), int(lot[2]) * times)
	return on_hand


static func _add(into: Dictionary, key: String, count: int) -> void:
	into[key] = int(into.get(key, 0)) + count


## What a model needs, in the same spelling as [method pool]: part and
## colour -> how many. From the parts list the app already makes.
static func needs_of(stock: Inventory, library: PartLibrary = null) -> Dictionary:
	var needs: Dictionary = {}
	for lot: Inventory.Lot in stock.lots:
		if lot.custom or (library != null and not ownable(lot.part_id, library)):
			continue
		_add(needs, key_of(lot.part_id, lot.color_code, library), lot.count)
	return needs


## Whether anybody owns [param part] on its own. Not a sticker, which comes
## on its set's sheet; not a link of a chain or a hose drawn link by link
## (LDraw's Flexible_Section); and not one of the pieces LDraw draws a
## bigger part with and names with a ~ (a train wheel's axle, a motor's
## case, a hose's centre section), unless the ~ only says the number moved
## or is obsolete. A model drawing them needs the whole thing, which no
## parts list names. A number LDraw moved is judged by the one it means
## today: OMR files draw pneumatic tubes in segments under their old
## numbers. api/_owned.js deriveOwnedFacts is the same rule.
static func ownable(part: String, library: PartLibrary) -> bool:
	var info: PartLibrary.PartInfo = library.parts.get(library.resolve(part))
	if info == null or info.category == "Sticker" or info.kind.contains("Flexible_Section"):
		return false
	return not info.name.begins_with("~") or info.is_redirect() or info.name.contains("(Obsolete)")


## What a model file needs, read with the app's own LDraw reader so a
## model counts the same here as it does when opened.
static func needs_of_ldraw(text: String, library: PartLibrary = null) -> Dictionary:
	var needs: Dictionary = {}
	var model: LdrModel = LdrModel.parse(text, "model")
	if model == null:
		return needs
	var known: Dictionary = library.parts if library != null else {}
	for placement: LdrModel.Placement in model.flatten(known):
		# Not a part anyone can own: a primitive drawn straight into the
		# model (a hose as a run of cylinders), a sub-model the file names
		# and does not carry, or a piece nobody has on its own ([method
		# ownable]). Counting them made a set's own model look a quarter
		# missing to the person who owns the set.
		if library != null and not ownable(placement.part_id, library):
			continue
		_add(needs, key_of(placement.part_id, placement.color_code, library), 1)
	return needs


## Another moulding of one part, written as one more letter on its number:
## 3794a and 3794b are the jumper plate without and with its groove, 3660a
## the inverted slope before its stopper ring. Either builds the model, so
## one stands in for the other before anything is called short. A number
## with more after the letter (3626bp01, 973pr1234c01) is a print or an
## assembly, and is only ever itself.
const _MOULD := "^([ux]?\\d+)[a-z]$"
static var _mould: RegEx = RegEx.create_from_string(_MOULD)


static func family_of(part: String) -> String:
	var found: RegExMatch = _mould.search(part)
	return found.get_string(1) if found != null else part


## What of the pool goes to the model, piece by piece: its own part in its
## own colour first, then another moulding of it in that colour, each piece
## given once.
##
## {"have": {key -> pieces covered}, "spare": {key -> pieces left over},
##  "moulds": {key -> [[other key, pieces]]}}
static func allocate(needs: Dictionary, on_hand: Dictionary) -> Dictionary:
	var spare: Dictionary = on_hand.duplicate()
	var have: Dictionary = {}
	for key: String in needs:
		var take: int = mini(int(needs[key]), int(spare.get(key, 0)))
		have[key] = take
		if take > 0:
			spare[key] = int(spare[key]) - take
	var siblings: Dictionary = {}
	for key: String in spare:
		if int(spare[key]) <= 0:
			continue
		var family: String = "%s/%d" % [family_of(part_of(key)), colour_of(key)]
		if family != key:
			if not siblings.has(family):
				siblings[family] = []
			(siblings[family] as Array).append(key)
	var moulds: Dictionary = {}
	var keys: Array = needs.keys()
	keys.sort()
	for key: String in keys:
		var left: int = int(needs[key]) - int(have[key])
		if left <= 0:
			continue
		var family: String = "%s/%d" % [family_of(part_of(key)), colour_of(key)]
		for other: String in siblings.get(family, []) + ([family] if spare.has(family) and family != key else []):
			if left <= 0:
				break
			if other == key:
				continue
			var take: int = mini(left, int(spare.get(other, 0)))
			if take <= 0:
				continue
			spare[other] = int(spare[other]) - take
			have[key] = int(have[key]) + take
			left -= take
			if not moulds.has(key):
				moulds[key] = []
			(moulds[key] as Array).append([other, take])
	return {"have": have, "spare": spare, "moulds": moulds}


## What is short: [{"key", "part", "colour", "need", "have", "short",
## "moulds"}], the biggest shortfall first, then by part. "moulds" names
## the other mouldings counted as had.
static func shortfall(needs: Dictionary, on_hand: Dictionary, given: Dictionary = {}) -> Array:
	var shared: Dictionary = given if not given.is_empty() else allocate(needs, on_hand)
	var out: Array = []
	for key: String in needs:
		var need: int = int(needs[key])
		var have: int = int(shared["have"].get(key, 0))
		if have < need:
			out.append({"key": key, "part": part_of(key), "colour": colour_of(key),
				"need": need, "have": have, "short": need - have,
				"moulds": shared["moulds"].get(key, [])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["short"]) != int(b["short"]):
			return int(a["short"]) > int(b["short"])
		return str(a["key"]) < str(b["key"]))
	return out


## How much of a model is already on hand.
##
## {"pieces", "owned", "exact": 0-1, "any_colour": 0-1, "missing"}:
## exact counts a piece only in its own colour (in either moulding);
## any_colour counts the shape in whatever colour it is owned, which is
## what a builder willing to swap colours has.
static func coverage(needs: Dictionary, on_hand: Dictionary) -> Dictionary:
	var shared: Dictionary = allocate(needs, on_hand)
	var pieces: int = 0
	var owned: int = 0
	var need_by_part: Dictionary = {}
	for key: String in needs:
		var need: int = int(needs[key])
		pieces += need
		owned += int(shared["have"].get(key, 0))
		_add(need_by_part, family_of(part_of(key)), need)
	var have_by_part: Dictionary = {}
	for key: String in on_hand:
		var part: String = family_of(part_of(key))
		if need_by_part.has(part):
			_add(have_by_part, part, int(on_hand[key]))
	var shaped: int = 0
	for part: String in need_by_part:
		shaped += mini(int(need_by_part[part]), int(have_by_part.get(part, 0)))
	return {"pieces": pieces, "owned": owned, "missing": pieces - owned,
		"exact": float(owned) / pieces if pieces > 0 else 0.0,
		"any_colour": float(maxi(shaped, owned)) / pieces if pieces > 0 else 0.0}


## An official model's parts as its own set holds them.
##
## The Official Model Repository draws a set by hand from its instructions,
## and Rebrickable counts the box, and the two often say one piece two
## ways: a colour read differently (Light Grey for Light Bluish Grey, an
## old code for Flat Silver), an alias, an assembly drawn as its parts or
## listed as them (a figure's arms and hands apart from its torso, a lever
## and its base), another mould or print of the same shape (one of the
## Siege Tower's soldiers drawn with another's torso). Counted as drawn, the
## Turbo Track Racer's own model was 96% buildable from the Turbo Track
## Racer and the Siege Tower's 84% from the Siege Tower.
##
## So each piece drawn is matched to a piece of the set, each given once:
## the same part and colour; another mould of it ([method family_of]); its
## parts, where it is drawn as an assembly or an alias and the set has
## them; the set's assembly or alias, where it is drawn as the parts; the
## same part in another colour the set has left; another part of the same
## shape (category, size and studs) in its colour. What none of these
## finds stays as drawn, and shows as missing to the person who owns the
## set: the model draws more than the box holds.
##
## [param needs] and [param held] are key -> count in [method key_of]'s
## spelling; [param made_of] is an LDraw shortcut's or alias's number ->
## [[part, colour]], 16 for the colour it is placed in (empty for anything
## else). Returns the model's needs in the set's keys.
static func as_its_set(needs: Dictionary, held: Dictionary, made_of: Callable,
		library: PartLibrary) -> Dictionary:
	var left: Dictionary = held.duplicate()
	var inside: Dictionary = {}   ## what the assemblies given hold that nothing drawn took yet
	var out: Dictionary = {}
	var short: Dictionary = {}
	for key: String in _sorted(needs):
		var take: int = mini(int(needs[key]), int(left.get(key, 0)))
		if take > 0:
			_add(out, key, take)
			left[key] = int(left[key]) - take
		if int(needs[key]) > take:
			short[key] = int(needs[key]) - take
	var mould := func(key: String, other: String) -> bool:
		return colour_of(other) == colour_of(key) and family_of(part_of(other)) == family_of(part_of(key))
	_match(short, out, left, inside, mould, false)
	for key: String in _sorted(short):
		var pieces: Dictionary = _pieces(key, made_of, library)
		var count: int = int(short.get(key, 0))
		if pieces.is_empty() or count <= 0:
			continue
		short.erase(key)
		for piece: String in pieces:
			var want: int = int(short.get(piece, 0)) + int(pieces[piece]) * count
			var take: int = mini(want, int(left.get(piece, 0)))
			if take > 0:
				_add(out, piece, take)
				left[piece] = int(left[piece]) - take
			if want > take:
				short[piece] = want - take
			else:
				short.erase(piece)
	for whole: String in _sorted(left):
		var pieces: Dictionary = {} if int(left[whole]) <= 0 else _pieces(whole, made_of, library)
		while not pieces.is_empty() and int(left[whole]) > 0 \
				and pieces.keys().any(func(piece: String) -> bool: return short.has(piece)):
			left[whole] = int(left[whole]) - 1
			_add(out, whole, 1)
			for piece: String in pieces:
				var used: int = mini(int(pieces[piece]), int(short.get(piece, 0)))
				if used > 0:
					short[piece] = int(short[piece]) - used
					if int(short[piece]) <= 0:
						short.erase(piece)
				if int(pieces[piece]) > used:
					_add(inside, piece, int(pieces[piece]) - used)
	_match(short, out, left, inside, mould, false)
	_match(short, out, left, inside, func(key: String, other: String) -> bool:
		return family_of(part_of(other)) == family_of(part_of(key)), true)
	_match(short, out, left, inside, func(key: String, other: String) -> bool:
		if colour_of(other) != colour_of(key):
			return false
		var shape: Variant = _shape(part_of(key), library)
		return shape != null and shape == _shape(part_of(other), library), true)
	for key: String in short:
		_add(out, key, int(short[key]))
	return out


static func _sorted(counts: Dictionary) -> Array:
	var keys: Array = counts.keys()
	keys.sort()
	return keys


## Gives what is short of [param left] (taking a piece of the set) and of
## [param inside] (a piece an assembly already given holds), the pieces
## [param fits] allows; the most plentiful first when [param most_first].
static func _match(short: Dictionary, out: Dictionary, left: Dictionary, inside: Dictionary,
		fits: Callable, most_first: bool) -> void:
	for key: String in _sorted(short):
		for from: Dictionary in [inside, left]:
			var others: Array = []
			for other: String in from:
				if other != key and int(from[other]) > 0 and fits.call(key, other):
					others.append(other)
			others.sort_custom(func(a: String, b: String) -> bool:
				if most_first and int(from[a]) != int(from[b]):
					return int(from[a]) > int(from[b])
				return a < b)
			for other: String in others:
				var take: int = mini(int(short.get(key, 0)), int(from[other]))
				if take <= 0:
					break
				from[other] = int(from[other]) - take
				short[key] = int(short[key]) - take
				if is_same(from, left):
					_add(out, other, take)
		if int(short.get(key, 0)) <= 0:
			short.erase(key)


## An assembly's or alias's pieces: key -> count, through nested
## shortcuts, its stickers left off (they come on the sheet). Empty for a
## part, and for an assembly with a piece nobody owns on its own (a train
## wheel's axle), which is then the one piece.
static func _pieces(key: String, made_of: Callable, library: PartLibrary, depth: int = 0) -> Dictionary:
	var info: PartLibrary.PartInfo = library.parts.get(part_of(key))
	if depth > 6 or info == null or not (info.kind.contains("Shortcut") or info.kind.contains("Alias")):
		return {}
	var out: Dictionary = {}
	for pair: Variant in made_of.call(part_of(key)):
		var child: String = library.resolve(str(pair[0]))
		var code: int = colour_of(key) if int(pair[1]) in [16, 24] else int(pair[1])
		var found: PartLibrary.PartInfo = library.parts.get(child)
		if found != null and found.category == "Sticker":
			continue
		if not ownable(child, library):
			return {}
		var at: String = key_of(child, code, library)
		var below: Dictionary = _pieces(at, made_of, library, depth + 1)
		if below.is_empty():
			_add(out, at, 1)
		for piece: String in below:
			_add(out, piece, int(below[piece]))
	return out


## What a part is shaped like, for another mould or print of it: its
## category, its size to the LDU and its studs. A number the catalogue
## does not have (Rebrickable's for a print LDraw has not drawn) is shaped
## like the part it is a print of.
static var _base: RegEx = RegEx.create_from_string("^[ux]?\\d+[a-z]?")


static func _shape(part: String, library: PartLibrary) -> Variant:
	var info: PartLibrary.PartInfo = library.parts.get(part)
	if info == null:
		var found: RegExMatch = _base.search(part)
		if found != null:
			info = library.parts.get(found.get_string(), library.parts.get(family_of(found.get_string())))
	if info == null:
		return null
	return [info.category, Vector3i(info.size.round()), info.stud_count]


## The shortfall, with what could stand in for each piece that is short.
##
## Each row of [method shortfall], plus "swaps" — [{"colour", "qty"}]: the
## same part in another colour, out of what the model does not itself use —
## and "combos" — [{"parts": [[part, each]], "qty"}]: two smaller bricks,
## plates or tiles in the needed colour that cover the same footprint (a
## 1 x 4 from two 1 x 2s, a 2 x 4 from two 1 x 4s) — and "left", what is
## still short after both. A spare piece is promised once: the largest
## shortfall is offered first, and what it is offered is no longer spare.
## [param library] names the bricks for the combinations; without one
## there are none.
static func plan(needs: Dictionary, on_hand: Dictionary, library: PartLibrary = null) -> Array:
	var shared: Dictionary = allocate(needs, on_hand)
	var spare: Dictionary = {}
	for key: String in shared["spare"]:
		if int(shared["spare"][key]) > 0:
			spare[key] = int(shared["spare"][key])
	var by_part: Dictionary = {}
	for key: String in spare:
		var part: String = part_of(key)
		if not by_part.has(part):
			by_part[part] = []
		(by_part[part] as Array).append(key)
	var sizes: Dictionary = _sizes(library)
	var rows: Array = shortfall(needs, on_hand, shared)
	for row: Dictionary in rows:
		var left: int = int(row["short"])
		var swaps: Array = []
		var others: Array = by_part.get(str(row["part"]), [])
		others.sort_custom(func(a: String, b: String) -> bool:
			return int(spare.get(a, 0)) > int(spare.get(b, 0)))
		for other: String in others:
			if left <= 0:
				break
			var take: int = mini(left, int(spare.get(other, 0)))
			if take <= 0:
				continue
			spare[other] = int(spare[other]) - take
			left -= take
			swaps.append({"colour": colour_of(other), "qty": take})
		var combos: Array = []
		if left > 0:
			for split: Array in _splits(str(row["part"]), sizes):
				if left <= 0:
					break
				var each: Dictionary = {}
				for piece: String in split:
					each[piece] = int(each.get(piece, 0)) + 1
				var can: int = left
				for piece: String in each:
					can = mini(can, int(spare.get(key_of(piece, int(row["colour"])), 0)) / int(each[piece]))
				if can <= 0:
					continue
				var named: Array = []
				for piece: String in each:
					var at: String = key_of(piece, int(row["colour"]))
					spare[at] = int(spare[at]) - can * int(each[piece])
					named.append([piece, int(each[piece])])
				combos.append({"parts": named, "qty": can})
				left -= can
		row["swaps"] = swaps
		row["combos"] = combos
		row["left"] = left
	return rows


## Plain bricks, plates and tiles by size: "Brick/1/4" -> "3010", the one
## real sets use most where LDraw draws several.
static var _sized: Dictionary = {}
static var _sized_for: PartLibrary = null
static var _size_of: Dictionary = {}

static func _sizes(library: PartLibrary) -> Dictionary:
	if library == null:
		return {}
	if _sized_for == library:
		return _sized
	_sized = {}
	_size_of = {}
	_sized_for = library
	var plain := RegEx.create_from_string("^(Brick|Plate|Tile) +(\\d+) +x +(\\d+)( +with +Groove)?$")
	var best: Dictionary = {}
	for id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.is_redirect():
			continue
		var found: RegExMatch = plain.search(info.name.strip_edges())
		if found == null:
			continue
		var across: int = mini(found.get_string(2).to_int(), found.get_string(3).to_int())
		var along: int = maxi(found.get_string(2).to_int(), found.get_string(3).to_int())
		var size: String = "%s/%d/%d" % [found.get_string(1), across, along]
		if not best.has(size) or info.in_sets > int(best[size]):
			best[size] = info.in_sets
			_sized[size] = id
	for size: String in _sized:
		_size_of[_sized[size]] = size
	return _sized


## Two smaller pieces of the same kind that cover a part's footprint:
## along its length first (a 1 x 6 from a 1 x 4 and a 1 x 2), then across
## it (a 2 x 4 from two 1 x 4s). The even split first, then the rest.
static func _splits(part: String, sizes: Dictionary) -> Array:
	var size: String = str(_size_of.get(part, ""))
	if size.is_empty():
		return []
	var kind: String = size.get_slice("/", 0)
	var across: int = size.get_slice("/", 1).to_int()
	var along: int = size.get_slice("/", 2).to_int()
	var out: Array = []
	for first: int in range(along / 2, 0, -1):
		var a: String = str(sizes.get(_size_key(kind, across, first), ""))
		var b: String = str(sizes.get(_size_key(kind, across, along - first), ""))
		if not a.is_empty() and not b.is_empty():
			out.append([a, b])
	for first: int in range(across / 2, 0, -1):
		var a: String = str(sizes.get(_size_key(kind, first, along), ""))
		var b: String = str(sizes.get(_size_key(kind, across - first, along), ""))
		if not a.is_empty() and not b.is_empty():
			out.append([a, b])
	return out


static func _size_key(kind: String, one: int, other: int) -> String:
	return "%s/%d/%d" % [kind, mini(one, other), maxi(one, other)]


## The shortfall as a parts list of its own, so it leaves through the same
## wanted-list and Rebrickable writers a whole model does (ShopLists).
## [param stock] is the model's parts list, which carries every lot's
## names and numbers; each lot comes out at the count that is short.
static func shortfall_stock(stock: Inventory, rows: Array, library: PartLibrary = null) -> Inventory:
	var short: Dictionary = {}
	for row: Dictionary in rows:
		short[str(row["key"])] = int(row["short"])
	var out := Inventory.new()
	var given: Dictionary = {}
	for lot: Inventory.Lot in stock.lots:
		var key: String = key_of(lot.part_id, lot.color_code, library)
		var wanted: int = int(short.get(key, 0)) - int(given.get(key, 0))
		if lot.custom or wanted <= 0:
			continue
		var copy := Inventory.Lot.new()
		for field: String in ["part_id", "name", "color_code", "color_name", "lego_colour",
				"rebrickable_colour", "element", "rgb_hex", "each_grams", "custom",
				"bricklink_id", "rebrickable_id"]:
			copy.set(field, lot.get(field))
		copy.count = mini(wanted, lot.count)
		given[key] = int(given.get(key, 0)) + copy.count
		out.lots.append(copy)
		out.pieces += copy.count
		out.grams += copy.total_grams()
	return out


## BrickLink's catalogue page for a part, under BrickLink's number for it
## (PartLibrary.shop_part), in a colour where BrickLink has a number for
## it. Linked rather than priced: BrickLink's prices are
## behind its API's sign-up and its terms, and a page is what a buyer
## wants anyway.
static func bricklink_page(part: String, colour: int, library: PartLibrary = null) -> String:
	var number: int = library.bricklink_colour(colour) if library != null else -1
	var listed: String = library.shop_part(part, "BrickLink") if library != null else part
	var url: String = "https://www.bricklink.com/v2/catalog/catalogitem.page?P=%s" % listed.uri_encode()
	if number >= 0:
		url += "&idColor=%d" % number
	return url


## The few words a design brief uses to ask for the person's own parts.
const ONLY_MINE := ["my collection", "my own parts", "parts i own", "parts i have",
	"bricks i own", "bricks i have", "what i own", "what i have"]


## Whether a brief asks to be built from what the person owns.
static func wanted_in(brief: String) -> bool:
	var said: String = brief.to_lower()
	for words: String in ONLY_MINE:
		if said.contains(words):
			return true
	return false


## part -> {colour -> how many}, out of a pool.
static func by_part(on_hand: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in on_hand:
		var part: String = part_of(key)
		if not out.has(part):
			out[part] = {}
		(out[part] as Dictionary)[colour_of(key)] = int(on_hand[key])
	return out


## Search results with the parts the person owns first, each group in the
## order the search ranked it. The assistant's part ranking (search_parts)
## calls this for a brief that asks to be built from the collection.
static func owned_first(found: Array[PartLibrary.PartInfo], on_hand: Dictionary) -> Array[PartLibrary.PartInfo]:
	var held: Dictionary = by_part(on_hand)
	var mine: Array[PartLibrary.PartInfo] = []
	var rest: Array[PartLibrary.PartInfo] = []
	for info: PartLibrary.PartInfo in found:
		if held.has(info.id):
			mine.append(info)
		else:
			rest.append(info)
	return mine + rest


## What the search line says about a part and the person's collection:
## ", you own 14: Red 8, Black 6" or ", not in your collection".
static func owned_note(part: String, on_hand: Dictionary, library: PartLibrary = null) -> String:
	var colours: Dictionary = by_part(on_hand).get(part, {})
	if colours.is_empty():
		return ", not in your collection"
	var codes: Array = colours.keys()
	codes.sort_custom(func(a: int, b: int) -> bool: return int(colours[a]) > int(colours[b]))
	var named := PackedStringArray()
	var total: int = 0
	for code: int in codes:
		total += int(colours[code])
		if named.size() < 6:
			named.append("%s %d" % [_colour_name(code, library), int(colours[code])])
	return ", you own %d: %s" % [total, ", ".join(named)]


## What a run asked to use the person's collection is told with the brief:
## how much there is, and the colours and parts there are most of.
static func brief_note(on_hand: Dictionary, library: PartLibrary = null) -> String:
	var by_colour: Dictionary = {}
	var by_shape: Dictionary = {}
	var total: int = 0
	for key: String in on_hand:
		var count: int = int(on_hand[key])
		total += count
		_add(by_colour, str(colour_of(key)), count)
		_add(by_shape, part_of(key), count)
	var colours: Array = by_colour.keys()
	colours.sort_custom(func(a: String, b: String) -> bool: return int(by_colour[a]) > int(by_colour[b]))
	var shapes: Array = by_shape.keys()
	shapes.sort_custom(func(a: String, b: String) -> bool: return int(by_shape[a]) > int(by_shape[b]))
	var colour_words := PackedStringArray()
	for code: String in colours.slice(0, 12):
		colour_words.append("%s (%d)" % [_colour_name(int(code), library), int(by_colour[code])])
	var shape_words := PackedStringArray()
	for part: String in shapes.slice(0, 20):
		var info: PartLibrary.PartInfo = library.parts.get(part) if library != null else null
		shape_words.append("%s %s (%d)" % [part,
			Inventory._tidy(info.name) if info != null else "", int(by_shape[part])])
	return ("Build this only from the person's own collection: %d pieces in %d lots. "
		+ "Use parts and colours they own; search_parts lists what they own first and "
		+ "says how many of each colour. Where the design needs more of a part than they "
		+ "have, use another part they own in the same colour, or the same part in a colour "
		+ "they have spare.\nTheir colours, most first: %s.\nTheir most plentiful parts: %s.") % [
		total, on_hand.size(), ", ".join(colour_words), ", ".join(shape_words)]


static func _colour_name(code: int, library: PartLibrary) -> String:
	var found: PartLibrary.BrickColor = library.color(code) if library != null else null
	return found.name.replace("_", " ") if found != null else "colour %d" % code
