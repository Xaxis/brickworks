## A model made easier to buy (rareswap, APP_UX9 #12): its rare lots listed,
## each with a swap that is common, and the swaps picked put in as one undo.
##
## A builder who means to build a design for real meets it at the checkout:
## a part in a colour that came in two sets has two sellers, or none. Studio
## shows a price and BrickLink's Easy Buy picks sellers; neither changes the
## model. Here a lot (a part in a colour, as the parts list counts it) is
## rare when its part comes in its colour in [constant RARE_IN] sets or
## fewer by Rebrickable's inventories (PartLibrary.sets_in_colour, the parts
## bin's "rare in this colour"): none at all among them, where the part comes
## in sets in other colours. A part the inventories have in no colour is
## silence, not rarity, and is left out and counted. A sticker comes on its
## sheet and a custom part from the element maker, so neither is a lot to
## buy here.
##
## Each is offered one swap that comes in [constant COMMON_IN] sets or more:
## - the same colour in an equal part, where there is one: another mould of
##   the same number (3794a for 3794b; 3665 for 3665a, as PartLibrary's
##   mould index groups them) or, for a print, the plain part it is printed
##   on (PartInfo.print_of). Equal only where the two shapes' boxes and
##   every connection point agree, each of its kind and way, to 0.1 LDU
##   (FindReplace._points): what Find and Replace calls sitting as the old
##   one did, so nothing it holds or is held by moves. The table is the
##   catalogue's own numbers, and the shapes are the judge;
## - else the same part in the nearest colour as an eye judges it
##   (CIEDE2000), among the colours it comes in 20 sets or more, of the same
##   transparency (and a tyre's rubber kept rubber): those still in sets
##   first, as a colour LEGO stopped making is harder to find again.
## The model's look is kept first: a part in its own colour before a colour.
## A print keeps its print where the print itself is common in another
## colour; otherwise its swap is its plain part, and that is offered but not
## picked: the print was chosen, and only the builder can say it may go.
##
## The swaps are made through Find and Replace (FindReplace.replace), each
## lot's parts as the parts list counts them, sub-models and every copy of
## one following as an edit by hand does, and folded into one undo step.
class_name RareSwap
extends RefCounted

## A part in a colour in this many sets or fewer is rare in it (rarity).
const RARE_IN := PartLibrary.RARE_IN
## And in this many or more, common enough to swap to: twenty sets is twenty
## sellers' worth of parted-out stock, and Pick a Brick's shelf for most.
const COMMON_IN := 20


## One rare lot, and its swap.
class Lot extends RefCounted:
	## "part/colour", the lot's own part and colour as the model has them:
	## what replace_parts' lots= names it by.
	var key: String = ""
	var part: String = ""
	var colour: int = -1
	var name: String = ""
	var colour_name: String = ""
	## How many pieces of it the model has.
	var count: int = 0
	## In how many sets its part comes in its colour: 0 to RARE_IN.
	var sets: int = 0
	## A print or a stickered part.
	var printed: bool = false
	## A hose or tube laid in pieces and sold whole: its colour is offered,
	## never another part.
	var flexible: bool = false
	## The swap: another part ("" keeps the part) and another colour (-1
	## keeps the colour), and in how many sets it comes; 0 when there is none.
	var into_part: String = ""
	var into_colour: int = -1
	var into_sets: int = 0
	## How far the new colour is from the old, as an eye judges (CIEDE2000).
	var delta_e: float = 0.0
	## Why there is no swap, when there is none.
	var none_why: String = ""
	## Picked to swap: every one with a swap, but a print to its plain part.
	var picked: bool = false

	func offered() -> bool:
		return into_sets > 0

	## The swap drops a print.
	func drops_print() -> bool:
		return printed and not into_part.is_empty()


var library: PartLibrary
## The parts a lot's part is made in again, by mould number: built once for
## the library ([method _moulds]).
var _by_number: Dictionary = {}


func _init(from: PartLibrary = null) -> void:
	library = from


# -- what is rare ------------------------------------------------------------------


## The rare lots of [param stock] (Inventory.of the model), each with no swap
## yet ([method offer] gives it one), rarest first and then the most pieces:
## {"lots": Array of Lot, "waiting": how many lots' counts are still on
## their way (the web fetches a part's colours file when first asked),
## "unknown": how many lots' parts the inventories have in no colour,
## "lots_in": how many lots were judged}.
func rare_of(stock: Inventory) -> Dictionary:
	var out: Dictionary = {"lots": [], "waiting": 0, "unknown": 0, "lots_in": 0}
	var flexible: Dictionary = {}
	for path: Variant in stock.items:
		flexible[stock.items[path]] = true
	for lot: Inventory.Lot in stock.lots:
		if lot.custom or not _buyable(lot.part_id):
			continue
		out["lots_in"] = int(out["lots_in"]) + 1
		var sets: int = library.sets_in_colour(lot.part_id, lot.color_code)
		if sets < 0:
			out["waiting"] = int(out["waiting"]) + 1
			continue
		if sets > RARE_IN:
			continue
		if sets == 0 and not _in_any_set(lot.part_id):
			out["unknown"] = int(out["unknown"]) + 1
			continue
		var rare := Lot.new()
		rare.key = "%s/%d" % [lot.part_id, lot.color_code]
		rare.part = lot.part_id
		rare.colour = lot.color_code
		rare.name = lot.name
		rare.colour_name = lot.color_name
		rare.count = lot.count
		rare.sets = sets
		rare.flexible = flexible.has(lot)
		var info: PartLibrary.PartInfo = library.parts.get(library.resolve(lot.part_id))
		rare.printed = info != null and (info.decor() & (PartLibrary.PartInfo.PRINTED
			| PartLibrary.PartInfo.STICKERED)) != 0
		(out["lots"] as Array).append(rare)
	(out["lots"] as Array).sort_custom(func(a: Lot, b: Lot) -> bool:
		if a.sets != b.sets:
			return a.sets < b.sets
		if a.count != b.count:
			return a.count > b.count
		return a.key < b.key)
	return out


## How many of [param stock]'s lots are rare: the parts list's count.
func count_of(stock: Inventory) -> int:
	return (rare_of(stock)["lots"] as Array).size()


## A part anyone buys on its own as a lot: not a sticker, which comes on its
## sheet, nor a piece LDraw draws a bigger part with (Collection.ownable).
func _buyable(part: String) -> bool:
	return Inventory.is_piece(part, library) and Collection.ownable(part, library)


## Whether the inventories have [param part] in any set, in any colour: what
## makes a colour it is in no set in rare, rather than unknown.
func _in_any_set(part: String) -> bool:
	for code: int in library.colors:
		if library.sets_in_colour(part, code) > 0:
			return true
	return false


# -- the swap -----------------------------------------------------------------------


## [param lot] given its swap ([member Lot.into_part], [member Lot.into_colour],
## [member Lot.into_sets]) or why it has none, and picked or not. An equal
## part is judged by its shape, fetched first where it is not here
## ([param finder]'s FindReplace.shape: the web fetches what it has not got).
func offer(lot: Lot, finder: FindReplace) -> void:
	lot.into_part = ""
	lot.into_colour = -1
	lot.into_sets = 0
	lot.delta_e = 0.0
	lot.none_why = ""
	var equal: Array = [] if lot.flexible else await _equal_part(lot.part, lot.colour, finder)
	var colour: Array = _nearest_colour(lot.part, lot.colour)
	# A print keeps its print where it can: its colour before its plain part.
	var order: Array = [colour, equal] if lot.printed else [equal, colour]
	for choice: Array in order:
		if choice.is_empty():
			continue
		if choice[0] == "part":
			lot.into_part = choice[1]
		else:
			lot.into_colour = int(choice[1])
			lot.delta_e = float(choice[3])
		lot.into_sets = int(choice[2])
		break
	if not lot.offered():
		lot.none_why = _none_why(lot)
	lot.picked = lot.offered() and not lot.drops_print()


## Every lot of [param rare] (rare_of's) given its swap.
func offer_all(rare: Array, finder: FindReplace) -> void:
	for lot: Lot in rare:
		await offer(lot, finder)


## ["part", the equal part's number, its sets] for [param part] in
## [param colour]: the one that comes in it in the most sets, 20 or more; []
## for none.
func _equal_part(part: String, colour: int, finder: FindReplace) -> Array:
	var best: Array = []
	var was: Lbm.PartMesh = null
	for other: String in equal_candidates(part):
		var sets: int = library.sets_in_colour(other, colour)
		if sets < COMMON_IN or (not best.is_empty() and sets <= int(best[2])):
			continue
		if was == null:
			was = await finder.shape(part)
			if was == null:
				return []
		var shape: Lbm.PartMesh = await finder.shape(other)
		if same_shape(was, shape):
			best = ["part", other, sets]
	return best


## The parts that might be [param part] again, by the catalogue's numbers:
## the plain part a print is on, and every other mould of the part's number
## and of that plain part's (PartLibrary.MOULD_NUMBER). Its shape decides
## ([method same_shape]).
func equal_candidates(part: String) -> PackedStringArray:
	var out := PackedStringArray()
	var id: String = library.resolve(part)
	var info: PartLibrary.PartInfo = library.parts.get(id)
	if info == null:
		return out
	var bases: Array = [id]
	if not info.print_of.is_empty():
		bases.append(info.print_of)
		out.append(info.print_of)
	var moulds: Dictionary = _moulds()
	for base: String in bases:
		for other: String in moulds.get(_number_of(base), []):
			if other != id and not out.has(other):
				out.append(other)
	return out


## A part's number without its mould letter: 3794 for 3794a and 3794b.
static func _number_of(part: String) -> String:
	var found: RegExMatch = PartLibrary.MOULD_NUMBER.search(part)
	return found.get_string(1) if found != null else part


## Number -> every plain, current part of it (a mould letter or none),
## for the library: 3794 -> [3794a, 3794b].
func _moulds() -> Dictionary:
	if not _by_number.is_empty():
		return _by_number
	for id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.is_redirect() or info.custom or info.decor() != 0 or PartLibrary.is_stale(info):
			continue
		var number: String = _number_of(id)
		if not _by_number.has(number):
			_by_number[number] = []
		(_by_number[number] as Array).append(id)
	for number: String in _by_number.keys():
		if (_by_number[number] as Array).size() < 2:
			_by_number.erase(number)
	_by_number[""] = []
	return _by_number


## Whether [param shape] sits where [param was] stands as it does: the same
## box, so Find and Replace lays it in the old one's place exactly
## (FindReplace._placed), and every connection point of the same kind,
## gender, place and way, to 0.1 LDU (FindReplace._points).
static func same_shape(was: Lbm.PartMesh, shape: Lbm.PartMesh) -> bool:
	if was == null or shape == null:
		return false
	if was.bounds.size.distance_to(shape.bounds.size) >= 1.0 \
			or was.bounds.get_center().distance_to(shape.bounds.get_center()) >= 1.0:
		return false
	return FindReplace._points(was, Transform3D.IDENTITY) \
		== FindReplace._points(shape, Transform3D.IDENTITY)


## ["colour", code, sets, ΔE] for [param part]: the colour nearest
## [param colour] that it comes in 20 sets or more, of its transparency
## (rubber kept rubber), those still in sets first; [] for none.
func _nearest_colour(part: String, colour: int) -> Array:
	var want: PartLibrary.BrickColor = library.color(colour)
	var here: Vector3 = HiddenColours.lab(want.rgb)
	var rubber: bool = want.group == "rubber"
	var choices: Array = []          ## [code, sets, ΔE, still made, same transparency]
	for code: int in library.colors:
		if code == colour:
			continue
		var other: PartLibrary.BrickColor = library.colors[code]
		if not other.is_plastic() or (other.group == "rubber") != rubber \
				or not rubber and other.plain_code != code:
			continue
		var sets: int = library.sets_in_colour(part, code)
		if sets < COMMON_IN:
			continue
		choices.append([code, sets, HiddenColours.de2000(here, HiddenColours.lab(other.rgb)),
			library.is_current(code), other.is_transparent() == want.is_transparent()])
	for pass_: int in 3:
		var best: Array = []
		for choice: Array in choices:
			if pass_ < 2 and not bool(choice[4]) or pass_ == 0 and not bool(choice[3]):
				continue
			if best.is_empty() or float(choice[2]) < float(best[2]) \
					or float(choice[2]) == float(best[2]) and int(choice[0]) < int(best[0]):
				best = choice
		if not best.is_empty():
			return ["colour", int(best[0]), int(best[1]), float(best[2])]
	return []


## Why [param lot] has no swap: the most sets its part comes in, in any colour.
func _none_why(lot: Lot) -> String:
	var most: int = 0
	for code: int in library.colors:
		most = maxi(most, library.sets_in_colour(lot.part, code))
	if most < COMMON_IN:
		return "it comes in %d sets at most, in any colour" % most if most != 1 \
			else "it comes in 1 set at most, in any colour"
	return "no colour of its transparency comes in %d sets" % COMMON_IN


# -- swapping -----------------------------------------------------------------------


## The picked lots of [param rare] swapped through [param finder]'s Find and
## Replace, as one undo step: {"lots": how many lots changed, "changed": how
## many parts, "stayed": what stayed and why, a line a lot, "words": the
## step's}. Each lot's parts are the parts list's own, taken again before
## each swap: a swap inside a sub-model lays its copies again.
func swap(rare: Array, finder: FindReplace) -> Dictionary:
	var builder: Builder = finder.builder
	var depth: int = builder.history_depth()
	var lots: int = 0
	var changed: int = 0
	var stayed := PackedStringArray()
	for lot: Lot in rare:
		if not lot.picked or not lot.offered():
			continue
		var found: Dictionary = found_for(lot, finder)
		if (found["ids"] as Array).is_empty():
			if int(found.get("locked", 0)) > 0:
				stayed.append("%s: %s" % [lot.name, "; ".join(FindReplace.stay_words(found, {}))])
			continue
		var into: Dictionary = {"part": lot.into_part, "color": lot.into_colour}
		if not lot.into_part.is_empty():
			if await finder.shape(lot.into_part) == null:
				stayed.append("%s: %s's shape could not be had" % [lot.name, lot.into_part])
				continue
			# Its other hand too, which a copy a mirror places is given.
			var other: String = Mirror.counterpart(library, lot.into_part)
			if not other.is_empty():
				await finder.shape(other)
		var done: Dictionary = finder.replace(found, into)
		changed += int(done["changed"])
		if int(done["changed"]) > 0:
			lots += 1
		if not str(done.get("stayed", "")).is_empty():
			stayed.append("%s: %s" % [lot.name, str(done["stayed"])])
	var words: String = swapped_words(lots, changed)
	builder.fold_since(depth, words)
	if builder.history_depth() == depth + 1:
		builder.name_newest(words)
	return {"lots": lots, "changed": changed, "stayed": stayed, "words": words}


## "swapped 3 rare lots for common ones, 9 parts": the undo step's words.
static func swapped_words(lots: int, parts: int) -> String:
	return "swapped %s for common ones, %s" % [Counted.of(lots, "rare lot"),
		Counted.of(parts, "part")]


## [param lot]'s parts as Find and Replace finds them (FindReplace.find,
## everywhere), only those the parts list counts in it: its own part, not
## another mould a mould's number would find, and a hose's pieces for the
## hose. Locked ones are left out, and counted, as the find leaves them.
func found_for(lot: Lot, finder: FindReplace) -> Dictionary:
	var stock: Inventory = Inventory.of(finder.world, library, finder.scenery)
	var ids: Dictionary = {}
	for each: Inventory.Lot in stock.lots:
		if each.part_id == lot.part and each.color_code == lot.colour:
			for brick_id: int in each.bricks:
				ids[brick_id] = true
	var found: Dictionary = finder.find({"part": "" if lot.flexible else lot.part,
		"color": lot.colour}, "all")
	return narrowed(found, ids, finder)


## [param found] (FindReplace.find's) kept to the parts [param ids] holds, its
## counts, colours and places counted again as find counts them.
static func narrowed(found: Dictionary, ids: Dictionary, finder: FindReplace) -> Dictionary:
	var out: Dictionary = found.duplicate(true)
	var kept: Array = []
	var parts: Dictionary = {}
	var colours: Dictionary = {}
	var by_def: Dictionary = {}
	for brick_id: int in found["ids"]:
		if not ids.has(brick_id):
			continue
		kept.append(brick_id)
		var brick: BrickWorld.Brick = finder.world.get_brick(brick_id)
		parts[brick.part_id] = int(parts.get(brick.part_id, 0)) + 1
		colours[brick.color_code] = int(colours.get(brick.color_code, 0)) + 1
		var path: String = Assemblies.path_of(brick)
		var def: String = "" if path.is_empty() else Assemblies.definition(Assemblies.leaf(path))
		by_def[def] = int(by_def.get(def, 0)) + 1
	if kept.size() == (found["ids"] as Array).size():
		return out
	out["ids"] = kept
	out["parts"] = parts
	out["colours"] = colours
	for side: String in ["mirrored", "follow"]:
		var held: Dictionary = {}
		for brick_id: Variant in found[side]:
			if ids.has(brick_id):
				held[brick_id] = found[side][brick_id]
		out[side] = held
	var copies: Dictionary = {}
	for place: Dictionary in found["places"]:
		copies[place["name"]] = int(place["copies"])
	var places: Array = []
	for place: Dictionary in found["places"]:
		if by_def.has(place["name"]):
			places.append({"name": place["name"], "count": int(by_def[place["name"]]),
				"copies": int(place["copies"])})
	out["places"] = places
	var locked: Array = (found.get("locked_ids", []) as Array).filter(func(brick_id: int) -> bool:
		return ids.has(brick_id))
	out["locked_ids"] = locked
	out["locked"] = locked.size()
	return out


# -- words --------------------------------------------------------------------------


## What [param lot] is and what it becomes, as the parts list's swap row and
## a session read it: "4 × Plate 1 x 2 in Sand Blue, in 2 sets → Light Bluish
## Grey, in 3,412 sets (ΔE 9.2)"; "… → Plate 1 x 2 with Groove (3794b), the
## same shape and connections in its colour, in 312 sets"; "… → no swap in 20
## sets or more: it comes in 3 sets at most, in any colour".
func lot_words(lot: Lot) -> String:
	return from_words(lot) + " → " + into_words(lot)


## What [param lot] is: "2 × Brick 1 x 3 (3622) in Sand Blue, in 1 set". The
## parts list draws it apart from [method into_words], so each is one entry
## of the words in another language.
func from_words(lot: Lot) -> String:
	return "%d × %s (%s) in %s, %s" % [lot.count, lot.name, lot.part, lot.colour_name,
		sets_words(lot.sets)]


## "in 2 sets", "in 1 set", "in no set".
static func sets_words(sets: int) -> String:
	if sets <= 0:
		return "in no set"
	return "in 1 set" if sets == 1 else "in %s sets" % Working.comma(sets)


## What [param lot] becomes: its swap, or why it has none.
func into_words(lot: Lot) -> String:
	if not lot.offered():
		return "no swap in %d sets or more: %s" % [COMMON_IN, lot.none_why]
	if not lot.into_part.is_empty():
		var info: PartLibrary.PartInfo = library.parts.get(lot.into_part)
		var named: String = Inventory._tidy(info.name) if info != null else lot.into_part
		if lot.drops_print():
			return "the plain %s (%s), without its print, %s" % [named, lot.into_part,
				sets_words(lot.into_sets)]
		return "%s (%s), the same shape and connections in its colour, %s" % [named,
			lot.into_part, sets_words(lot.into_sets)]
	return "%s, %s (ΔE %.1f)" % [library.color(lot.into_colour).name.replace("_", " "),
		sets_words(lot.into_sets), lot.delta_e]
