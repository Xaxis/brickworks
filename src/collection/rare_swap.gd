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
## A swap the builder did not choose never changes how the model looks
## (rsfix, after rsreview found 31 of 54 gallery swaps over ΔE 20, all of
## them picked: a Tan head of hair made Black, a see-through part opaque).
## So each lot is offered one swap that comes in [constant COMMON_IN] sets or
## more, and only one that keeps the look starts picked:
## - the same colour in an equal part, where there is one: the plain part a
##   print is on (PartInfo.print_of) first, then another mould of the same
##   number (3794a for 3794b, as PartLibrary.moulds_of groups them), those
##   still made in the colour first. Equal where the two shapes' boxes agree
##   and the new one has every connection point of the old, each of its
##   kind and way, to 0.1 LDU (FindReplace._points): what Find and Replace
##   calls sitting as the old one did, so nothing it holds or is held by
##   moves. One with more points holds all the old one held and more (3665b
##   for 3665a, its stopper ring), and is said to. A print's own plain part
##   still made in its colour is offered in more than RARE_IN sets: it is the
##   same part, and what sets list is the print (3626c for 3626cpbb, not the
##   1975 mould 3626a). Picked, but for a print's plain part: the print was
##   chosen, and only the builder can say it may go;
## - else another colour, which never starts picked unless it is close
##   ([constant CLOSE_DE] or nearer by CIEDE2000) and of the same
##   see-through and finish exactly ([method keeps_finish]): a see-through
##   part stays see-through, a milky one milky and a chrome one chrome,
##   which are chosen on purpose.
##   The colours ranked by same transparency, then same finish, then close,
##   then still made, then nearest; a rubber tyre kept rubber. One source
##   colour goes to one colour across the model's lots where their parts
##   allow, the one the most of its pieces come in, so a fox's nine Orange
##   lots do not go four ways. A swap across transparency or finish is
##   offered only where no colour of the same comes in 20 sets, and says so.
## The words say "a close colour" or "a different colour", and "not
## see-through" or "loses its chrome" where it does.
##
## The swaps are made through Find and Replace (FindReplace.replace), each
## lot's parts as the parts list counts them, sub-models and every copy of
## one following as an edit by hand does, and folded into one undo step. A
## part lifted and still in hand is put back where it was first, as Escape
## puts it (FindReplace.put_back_held).
class_name RareSwap
extends RefCounted

## A part in a colour in this many sets or fewer is rare in it (rarity).
const RARE_IN := PartLibrary.RARE_IN
## And in this many or more, common enough to swap to: twenty sets is twenty
## sellers' worth of parted-out stock, and Pick a Brick's shelf for most.
const COMMON_IN := 20
## A colour this near (CIEDE2000) or nearer keeps the model's look, and may
## start picked. Under it are the swaps builders make without a second look:
## the old greys to the new (Light Grey to Light Bluish Grey 5.7, Dark Grey
## to Dark Bluish Grey 6.1) and Brown to Reddish Brown (8.3). Just over it
## the pairs an eye tells apart at a glance: Yellow and Bright Light Orange
## 10.2, Reddish Brown and Dark Brown 11.3, Black and Dark Blue 12.1, Sand
## Blue and Light Bluish Grey 13.9 (measured over colors.json's current solid
## colours, rsfix 2026-11-18).
const CLOSE_DE := 10.0
## How long an offer waits for a candidate's colours file (the web fetches
## one the first time it is asked), as replace_parts waits for a lot's own.
const WAIT_MS := 20000
## A frame's share of the offers' work, in µs: the rest goes on in the
## next frame, so the swaps' list never holds a frame (rsreview F6: 317 ms).
const SLICE_US := 8000

## A see-through colour this clear or clearer (its alpha under it) is seen
## through; one over it, a lens filed see-through but near black (Trans
## Black IR Lens, 245) or milky plastic (240), is clouded, and a swap keeps
## the one for the other no more than it makes either opaque.
const CLEAR_BELOW := 200


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
	## A part swap's connection points beyond the old part's, all of which it
	## has: 0 for the same points.
	var more_points: int = 0
	## Why there is no swap, when there is none.
	var none_why: String = ""
	## Picked to swap: one that keeps the look ([method keeps_look]), or one
	## the builder or a session's lots= picked.
	var picked: bool = false
	## A candidate's set count was still on its way when it was offered (the
	## web): offered again when it comes.
	var waited: bool = false
	## Its colours of 20 sets or more, while the swaps are worked out:
	## [code, sets, ΔE, still made, same transparency, same finish].
	var choices: Array = []

	func offered() -> bool:
		return into_sets > 0

	## The swap drops a print.
	func drops_print() -> bool:
		return printed and not into_part.is_empty()

	## A colour swap no more than CLOSE_DE away.
	func close() -> bool:
		return into_colour >= 0 and delta_e <= CLOSE_DE


var library: PartLibrary


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
		if sets == 0 and library.most_sets(lot.part_id) <= 0:
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


# -- the swap -----------------------------------------------------------------------


## [param lot] given its swap ([member Lot.into_part], [member Lot.into_colour],
## [member Lot.into_sets]) or why it has none, and picked or not: alone, as
## [method offer_all] gives a model's.
func offer(lot: Lot, finder: FindReplace) -> void:
	await offer_all([lot], finder)


## Every lot of [param rare] (rare_of's) given its swap, picked when it keeps
## the look. An equal part is judged by its shape, fetched first where it is
## not here ([param finder]'s FindReplace.shape: the web fetches what it has
## not got), and every count the offers read is asked for first and waited
## on, for up to WAIT_MS (rsreview F3: on the web a candidate whose colours
## file was on its way read as none, and 3070a was offered nothing).
func offer_all(rare: Array, finder: FindReplace) -> void:
	await _counts_here(rare)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var slice: int = Time.get_ticks_usec()
	var by_colour: Dictionary = {}       ## a colour -> its lots wanting another colour
	var plain: Dictionary = {}           ## a print -> its plain part, for when no colour keeps it
	for lot: Lot in rare:
		lot.into_part = ""
		lot.into_colour = -1
		lot.into_sets = 0
		lot.delta_e = 0.0
		lot.more_points = 0
		lot.none_why = ""
		lot.waited = _waiting(lot) > 0
		lot.choices = _colour_choices(lot.part, lot.colour)
		var equal: Array = [] if lot.flexible else await _equal_part(lot, finder)
		if not equal.is_empty() and not lot.printed:
			_take(lot, equal)
		else:
			if not equal.is_empty():
				plain[lot] = equal
			if not by_colour.has(lot.colour):
				by_colour[lot.colour] = []
			(by_colour[lot.colour] as Array).append(lot)
		if Time.get_ticks_usec() - slice > SLICE_US:
			await tree.process_frame
			slice = Time.get_ticks_usec()
	for colour: int in by_colour:
		_share_colours(by_colour[colour])
	for lot: Lot in rare:
		if not lot.offered() and plain.has(lot):
			# A print no colour of its own finish keeps: its plain part,
			# before a colour across a finish.
			_take(lot, plain[lot])
		if not lot.offered():
			_take(lot, _crossing(lot))
		if not lot.offered():
			lot.none_why = _none_why(lot)
		lot.picked = keeps_look(lot)
		lot.choices = []


## Whether [param lot]'s swap leaves the model looking as it did, and so may
## start picked: the same shape in its colour (not a print's plain part), or
## a close colour of the same see-through and finish ([method keeps_finish]).
func keeps_look(lot: Lot) -> bool:
	if not lot.offered() or lot.drops_print():
		return false
	if not lot.into_part.is_empty():
		return true
	return lot.close() and keeps_finish(library.color(lot.colour), library.color(lot.into_colour))


## [param lot] given [param choice]: ["part", id, sets, more points] or
## ["colour", code, sets, ΔE]; nothing for [].
static func _take(lot: Lot, choice: Array) -> void:
	if choice.is_empty():
		return
	if choice[0] == "part":
		lot.into_part = choice[1]
		lot.more_points = int(choice[3])
	else:
		lot.into_colour = int(choice[1])
		lot.delta_e = float(choice[3])
	lot.into_sets = int(choice[2])


## Whether a swap from [param want] to [param other] keeps its kind of
## plastic, the one rule rareswap's and ownswap's (OwnSwap) swaps keep
## (osreview H1: a family that put milky and fluorescent with solid and
## metallic with pearl let 42 pairs within ΔE 10 cross, 3 Milky White
## round plates made Trans-Clear and picked): [param other] a plastic a part
## is moulded in ([method swaps_to]); seen through alike
## ([method same_see_through]); and drawn alike, its finish exactly
## (BrickColor.drawn_as: solid, chrome, metallic, pearl, speckle, glitter,
## opal, glow, fluorescent, rubber, fabric and milky each its own).
static func keeps_finish(want: PartLibrary.BrickColor, other: PartLibrary.BrickColor) -> bool:
	return want != null and swaps_to(other) and same_see_through(want, other) \
		and want.drawn_as == other.drawn_as


## Whether a swap may go to [param colour]: a plastic a part is moulded in.
## Not a sticker's film, an electrical contact, a magnet or a retired code
## (BrickColor.is_plastic), nor conductive plastic (Conductive Black, filed
## with the pearls, made to carry current) or a printing ink (LDConfig's
## fluorescent paint), which no part is bought in: Metallic Dark Grey went
## Conductive Black at ΔE 0.0 (osreview H1).
static func swaps_to(colour: PartLibrary.BrickColor) -> bool:
	return colour != null and colour.is_plastic() and colour.group != "fluorescent paint" \
		and not colour.name.contains("Conductive")


## Whether [param a] and [param b] are seen through alike: both see-through
## or neither, and of those both clear or both clouded ([constant
## CLEAR_BELOW]).
static func same_see_through(a: PartLibrary.BrickColor, b: PartLibrary.BrickColor) -> bool:
	return a.is_transparent() == b.is_transparent() and _clear(a) == _clear(b)


static func _clear(colour: PartLibrary.BrickColor) -> bool:
	return colour.is_transparent() and colour.alpha < CLEAR_BELOW


# -- the counts first --------------------------------------------------------------


## How many of the counts [param lot]'s offer reads are still on their way:
## its own part's, and each equal part's in its colour. Asking is what sends
## for them.
func _waiting(lot: Lot) -> int:
	var waiting: int = 1 if library.most_sets(lot.part) < 0 else 0
	if not lot.flexible:
		for other: String in equal_candidates(lot.part):
			if library.sets_in_colour(other, lot.colour) < 0:
				waiting += 1
	return waiting


## Every count [param rare]'s offers read asked for, and waited on until none
## is on its way or WAIT_MS have gone; at once where all are here, as on the
## desktop, which reads its files from its own disk.
func _counts_here(rare: Array) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var until: int = Time.get_ticks_msec() + WAIT_MS
	while true:
		var waiting: int = 0
		for lot: Lot in rare:
			waiting += _waiting(lot)
		if waiting == 0 or Time.get_ticks_msec() >= until:
			return
		await tree.process_frame


# -- an equal part --------------------------------------------------------------------


## ["part", the equal part's number, its sets, its points beyond the old
## part's] for [param lot]: the print's own plain part first, then those
## still made in its colour, then the most sets; [] for none.
func _equal_part(lot: Lot, finder: FindReplace) -> Array:
	var info: PartLibrary.PartInfo = library.parts.get(library.resolve(lot.part))
	var print_of: String = info.print_of if info != null else ""
	var ranked: Array = []           ## [part, sets, its print's plain part, still made]
	for other: String in equal_candidates(lot.part):
		var sets: int = library.sets_in_colour(other, lot.colour)
		var made: bool = still_made(other, lot.colour)
		if sets >= COMMON_IN or other == print_of and made and sets > RARE_IN:
			ranked.append([other, sets, other == print_of, made])
	if ranked.is_empty():
		return []
	ranked.sort_custom(func(a: Array, b: Array) -> bool:
		if a[2] != b[2]:
			return a[2]
		if a[3] != b[3]:
			return a[3]
		if a[1] != b[1]:
			return a[1] > b[1]
		return a[0] < b[0])
	var was: Lbm.PartMesh = await finder.shape(lot.part)
	if was == null:
		return []
	for choice: Array in ranked:
		var more: int = fits(was, await finder.shape(choice[0]))
		if more >= 0:
			return ["part", choice[0], choice[1], more]
	return []


## Whether [param part] is still made in [param colour]: in a set of the
## last couple of years in it, by the catalogue (PartInfo.colors_recent).
func still_made(part: String, colour: int) -> bool:
	var info: PartLibrary.PartInfo = library.parts.get(library.resolve(part))
	if info == null:
		return false
	var color: PartLibrary.BrickColor = library.color(colour)
	return info.colors_recent.has(colour) or color != null and info.colors_recent.has(color.plain_code)


## The parts that might be [param part] again, by the catalogue's numbers:
## the plain part a print is on, and every other plain mould of the part's
## number and of that plain part's (PartLibrary.moulds_of). Its shape
## decides ([method fits]).
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
	for base: String in bases:
		for other: String in library.moulds_of(_number_of(base)):
			if other == id or out.has(other):
				continue
			var mould: PartLibrary.PartInfo = library.parts.get(other)
			if mould == null or mould.custom or mould.decor() != 0 or PartLibrary.is_stale(mould):
				continue
			out.append(other)
	return out


## A part's number without its mould letter: 3794 for 3794a and 3794b.
static func _number_of(part: String) -> String:
	var found: RegExMatch = PartLibrary.MOULD_NUMBER.search(part)
	return found.get_string(1) if found != null else part


## Whether [param shape] sits where [param was] stands as it does: how many
## connection points it has beyond the old one's, or -1 where it does not
## sit so. The same box, so Find and Replace lays it in the old one's place
## exactly (FindReplace._placed), and every connection point of the old one
## of the same kind, gender, place and way, to 0.1 LDU (FindReplace._points):
## what the old one held it holds.
static func fits(was: Lbm.PartMesh, shape: Lbm.PartMesh) -> int:
	if was == null or shape == null:
		return -1
	if was.bounds.size.distance_to(shape.bounds.size) >= 1.0 \
			or was.bounds.get_center().distance_to(shape.bounds.get_center()) >= 1.0:
		return -1
	var has: Dictionary = {}
	var points: PackedStringArray = FindReplace._points(shape, Transform3D.IDENTITY)
	for point: String in points:
		has[point] = int(has.get(point, 0)) + 1
	var needs: PackedStringArray = FindReplace._points(was, Transform3D.IDENTITY)
	for point: String in needs:
		if int(has.get(point, 0)) <= 0:
			return -1
		has[point] = int(has[point]) - 1
	return points.size() - needs.size()


## The same box and every connection point the same: [method fits] with
## none more.
static func same_shape(was: Lbm.PartMesh, shape: Lbm.PartMesh) -> bool:
	return fits(was, shape) == 0


# -- a colour -----------------------------------------------------------------------


## [param part]'s colours of 20 sets or more but [param colour] itself:
## [code, sets, ΔE from it, still made, seen through alike, the same finish
## (BrickColor.drawn_as)], a rubber tyre's rubber kept rubber; never one no
## swap goes to ([method swaps_to]).
func _colour_choices(part: String, colour: int) -> Array:
	var want: PartLibrary.BrickColor = library.color(colour)
	if want == null:
		return []
	var here: Vector3 = HiddenColours.lab(want.rgb)
	var rubber: bool = want.group == "rubber"
	var out: Array = []
	for code: int in library.colors:
		if code == colour:
			continue
		var other: PartLibrary.BrickColor = library.colors[code]
		if not swaps_to(other) or (other.group == "rubber") != rubber \
				or not rubber and other.plain_code != code:
			continue
		var sets: int = library.sets_in_colour(part, code)
		if sets < COMMON_IN:
			continue
		out.append([code, sets, HiddenColours.de2000(here, HiddenColours.lab(other.rgb)),
			library.is_current(code), same_see_through(want, other), other.drawn_as == want.drawn_as])
	return out


## The lots of one colour ([param lots]) each given a colour of the same
## transparency and finish, one colour for as many of them as their parts
## allow: a close one first, then the one the most of their pieces come in,
## then one still made, then the nearest. Those whose parts come in none of
## the first get the next, so a colour goes as few ways as it must.
func _share_colours(lots: Array) -> void:
	var left: Array = lots.filter(func(lot: Lot) -> bool: return not lot.offered())
	while not left.is_empty():
		var tally: Dictionary = {}       ## code -> [pieces, ΔE, still made, sets of the first]
		for lot: Lot in left:
			for choice: Array in lot.choices:
				if not bool(choice[4]) or not bool(choice[5]):
					continue
				var code: int = int(choice[0])
				if not tally.has(code):
					tally[code] = [0, float(choice[2]), bool(choice[3])]
				tally[code][0] = int(tally[code][0]) + lot.count
		var best: int = -1
		for code: int in tally:
			if best < 0 or _before(code, tally[code], best, tally[best]):
				best = code
		if best < 0:
			return
		var still: Array = []
		for lot: Lot in left:
			var took: bool = false
			for choice: Array in lot.choices:
				if int(choice[0]) == best:
					_take(lot, ["colour", best, int(choice[1]), float(choice[2])])
					took = true
			if not took:
				still.append(lot)
		left = still


## Whether colour [param a] ([pieces, ΔE, still made]) goes before [param b]
## for a source colour's lots: close first, then the most pieces, then still
## made, then the nearest, then the lower code.
static func _before(a: int, of_a: Array, b: int, of_b: Array) -> bool:
	var close_a: bool = float(of_a[1]) <= CLOSE_DE
	var close_b: bool = float(of_b[1]) <= CLOSE_DE
	if close_a != close_b:
		return close_a
	if int(of_a[0]) != int(of_b[0]):
		return int(of_a[0]) > int(of_b[0])
	if bool(of_a[2]) != bool(of_b[2]):
		return bool(of_a[2])
	if float(of_a[1]) != float(of_b[1]):
		return float(of_a[1]) < float(of_b[1])
	return a < b


## ["colour", code, sets, ΔE] for a lot no colour of its own transparency
## and finish takes: the best across them, the same transparency first, then
## the same finish, then still made, then the nearest; [] for none. Offered,
## never picked, and said ([method into_words]).
static func _crossing(lot: Lot) -> Array:
	var best: Array = []
	for choice: Array in lot.choices:
		if best.is_empty():
			best = choice
			continue
		var key_a: Array = [bool(choice[4]), bool(choice[5]), bool(choice[3])]
		var key_b: Array = [bool(best[4]), bool(best[5]), bool(best[3])]
		var better: bool = false
		var decided: bool = false
		for n: int in 3:
			if key_a[n] != key_b[n]:
				better = key_a[n]
				decided = true
				break
		if not decided:
			better = float(choice[2]) < float(best[2]) \
				or float(choice[2]) == float(best[2]) and int(choice[0]) < int(best[0])
		if better:
			best = choice
	if best.is_empty():
		return []
	return ["colour", int(best[0]), int(best[1]), float(best[2])]


## Why [param lot] has no swap: the most sets this very part comes in, in any
## colour, and that no other mould of it sits as it does in 20 sets (the
## count is its own, not its number's: 3665b holds 3665a's place in 537).
func _none_why(lot: Lot) -> String:
	var most: int = maxi(library.most_sets(lot.part), 0)
	if most < COMMON_IN:
		var said: String = ("%s itself comes in %d sets at most, in any colour" % [lot.part, most]) \
			if most != 1 else "%s itself comes in 1 set at most, in any colour" % lot.part
		if not lot.flexible and not equal_candidates(lot.part).is_empty():
			said += "; no other mould of it sits as it does in %d sets or more" % COMMON_IN
		return said
	return "no colour of its transparency comes in %d sets" % COMMON_IN


# -- swapping -----------------------------------------------------------------------


## The picked lots of [param rare] swapped through [param finder]'s Find and
## Replace, as one undo step: {"lots": how many lots changed, "changed": how
## many parts, "stayed": what stayed and why, a line a lot, "words": the
## step's, "put_back": how many parts in hand went back first}. Each lot's
## parts are the parts list's own, taken again before each swap: a swap
## inside a sub-model lays its copies again.
func swap(rare: Array, finder: FindReplace) -> Dictionary:
	var builder: Builder = finder.builder
	# A part in hand, back where it was first: it is then found and swapped
	# with the rest of its lot, where a step laid over its lift lost it.
	var put_back: int = finder.put_back_held()
	var depth: int = builder.history_depth()
	var lots: int = 0
	var changed: int = 0
	var stayed := PackedStringArray()
	if put_back < 0:
		stayed.append(FindReplace.HELD_WORDS)
	for lot: Lot in rare:
		if put_back < 0 or not lot.picked or not lot.offered():
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
	return {"lots": lots, "changed": changed, "stayed": stayed, "words": words,
		"put_back": maxi(put_back, 0)}


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
## counts, colours and places counted again as find counts them. What it
## holds is [param found]'s own where it is kept whole, and read only: an
## offer narrows a lot to each of its copy groups in turn (OwnSwap).
static func narrowed(found: Dictionary, ids: Dictionary, finder: FindReplace) -> Dictionary:
	var out: Dictionary = found.duplicate()
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
## a session read it: "4 × Plate 1 x 2 (3023) in Sand Blue, in 2 sets → Light
## Bluish Grey, in 3,412 sets (ΔE 13.9); a different colour"; "… → Plate 1 x
## 2 with Groove (3794b), the same shape and connections in its colour, in
## 312 sets"; "… → no swap in 20 sets or more: 3665a itself comes in 2 sets
## at most, in any colour".
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


## What [param lot] becomes: its swap, or why it has none. A colour's says
## whether it is close and what it changes besides, each after "; ".
func into_words(lot: Lot) -> String:
	if not lot.offered():
		return "no swap in %d sets or more: %s" % [COMMON_IN, lot.none_why]
	if not lot.into_part.is_empty():
		var info: PartLibrary.PartInfo = library.parts.get(lot.into_part)
		var named: String = Inventory._tidy(info.name) if info != null else lot.into_part
		if lot.drops_print():
			return ("the plain %s (%s), without its print, %s" % [named, lot.into_part,
				sets_words(lot.into_sets)]) + ("; still made in its colour"
				if lot.into_sets < COMMON_IN else "")
		if lot.more_points == 1:
			return "%s (%s), the same shape in its colour, holding all its connections and 1 more, %s" \
				% [named, lot.into_part, sets_words(lot.into_sets)]
		if lot.more_points > 1:
			return "%s (%s), the same shape in its colour, holding all its connections and %d more, %s" \
				% [named, lot.into_part, lot.more_points, sets_words(lot.into_sets)]
		return "%s (%s), the same shape and connections in its colour, %s" % [named,
			lot.into_part, sets_words(lot.into_sets)]
	var was: PartLibrary.BrickColor = library.color(lot.colour)
	var now: PartLibrary.BrickColor = library.color(lot.into_colour)
	var notes := PackedStringArray(["a close colour" if lot.close() else "a different colour"])
	if was != null and now != null:
		# Opaque against see-through first, then clear against clouded.
		var seen: bool = was.is_transparent() if was.is_transparent() != now.is_transparent() \
			else _clear(was)
		if not same_see_through(was, now):
			notes.append("not see-through" if seen else "see-through")
		if was.drawn_as != now.drawn_as:
			notes.append("loses its %s" % was.finish_name()
				if was.drawn_as != PartLibrary.BrickColor.Finish.PLASTIC
				else "becomes %s" % now.finish_name())
	return "%s, %s (ΔE %.1f); %s" % [now.name.replace("_", " ") if now != null else str(lot.into_colour),
		sets_words(lot.into_sets), lot.delta_e, "; ".join(notes)]
