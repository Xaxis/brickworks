## A model rebuilt from the parts its builder owns (ownswap, APP_UX10 #2): each
## lot of the open model they own too few of, with the swap from their own
## parts that keeps its look, or "none you own", and the swaps put in as one
## undo.
##
## A builder with a collection and a gallery model wants to build it
## tonight, not after an order. Rebrickable matches sets against a
## collection; no tool changes a model's parts to the ones a person has.
## What they own is the pool every sum of the collection is done against
## (CollectionStore.on_hand), and a lot is short as submit_design mine=true
## and the bin's My bricks count it (OwnCounts.over, Collection.allocate):
## its own part in its own colour first, then another moulding of it in that
## colour, each piece given once, and only what is left over is free to swap
## in. The swaps use it up as they are chosen, the biggest shortfall first,
## so two lots never both take the last three of one part.
##
## The swap is rareswap's matcher with the collection as its pool, and it
## never changes how the model looks (self_attack, rsreview F1):
## - an equal part in the lot's own colour (RareSwap.equal_candidates and
##   RareSwap.fits: the same box, and every connection point of the old one,
##   so nothing it holds or is held by moves), another mould first; a
##   print's plain part only where nothing else is, and never picked, as the
##   print was chosen and only the builder can say it may go;
## - else the same part, or a moulding of it, in the nearest colour they own
##   ([constant RareSwap.CLOSE_DE] or nearer by CIEDE2000) of the same
##   transparency and finish family (RareSwap.family): no chrome, pearl,
##   metallic or see-through for a solid, nor the reverse;
## - else none they own, and what they have of it said.
## Of those, the one that covers the most of what is short; then the same
## colour before another; then the nearest.
##
## A part hidden inside the model is held to the same rule as one on show
## (decided for ownswap): what is hidden is measured only by drawing the
## model from 256 sides on the graphics card (SeenParts), seconds on Orthanc
## and not at all without one, so the swaps would differ by machine; the
## booklet shows the inside while it is built, in the colours the model
## has; and Hidden colours already recolours the inside on purpose, where the
## builder chooses it. What do I need? still offers any colour they own.
##
## Only the pieces short change: of 10 Red bricks with 7 owned, 3 go to the
## swap and 7 stay, the fewest parts changed. A part in a copy of a
## sub-model changes with its twin in every other copy or not at all (Find
## and Replace's rule), so the pieces are taken a copy group at a time, as
## FindReplace.plan groups them, and a group bigger than what is free is
## passed over. The swaps are made through Find and Replace, folded into one
## undo step; a part lifted and still in hand is put back where it was
## first, as Escape puts it (FindReplace.put_back_held), and never lost.
class_name OwnSwap
extends RefCounted

## A frame's share of the work, in µs, as RareSwap's: the rest goes on in the
## next frame, so the list never holds a frame on Orthanc.
const SLICE_US := 8000


## One lot the person owns too few of, and its swap.
class Lot extends RefCounted:
	## "part/colour", the lot's own part and colour as the model has them:
	## what replace_parts mine=true lots= names it by.
	var key: String = ""
	var part: String = ""
	var colour: int = -1
	var name: String = ""
	var colour_name: String = ""
	## How many pieces of it the model has, and of those how many the person
	## owns (its part in its colour, or another moulding of it).
	var count: int = 0
	var owned: int = 0
	## A print or a stickered part.
	var printed: bool = false
	## A hose or tube laid in pieces and sold whole: never another part.
	var flexible: bool = false
	## The swap: another part ("" keeps the part) and another colour (-1 keeps
	## it); how many of the lot's pieces it changes; how many of it the person
	## has free for it before it is made.
	var into_part: String = ""
	var into_colour: int = -1
	var takes: int = 0
	var free: int = 0
	## How far the new colour is from the old, as an eye judges (CIEDE2000).
	var delta_e: float = 0.0
	## A part swap's connection points beyond the old part's: 0 for the same.
	var more_points: int = 0
	## The nearest the person owns of it that is not a swap, for the words of
	## one with none: [colour code, ΔE, how many], or [].
	var nearest: Array = []
	## Swapped by "Use what I own": every swap that keeps the look, a print's
	## plain part only where the builder or a session's lots= picks it.
	var picked: bool = false
	## The panel's rareswap list reads this of its rows: nothing waits here.
	var waited: bool = false

	func short() -> int:
		return count - owned

	func offered() -> bool:
		return takes > 0

	## The swap drops a print.
	func drops_print() -> bool:
		return printed and not into_part.is_empty()

	## How many are still not owned once the swap is in.
	func missing_after() -> int:
		return maxi(0, short() - takes) if offered() else short()


var library: PartLibrary
## RareSwap's matcher: its equal parts and its colours' families.
var _rare: RareSwap


func _init(from: PartLibrary = null) -> void:
	library = from
	_rare = RareSwap.new(from)


# -- what is short ----------------------------------------------------------------


## The lots of the model ([param world], [param scenery] left out) the person
## owns too few of against [param on_hand] (CollectionStore.on_hand), the
## biggest shortfall first, each with no swap yet ([method offer_all]):
## {"lots": Array of Lot, "pieces": the pieces mine=true counts, "owned": of
## those how many are theirs, "free": key -> pieces owned and not used by the
## model, the pool the swaps take from}. [param stock] is the model's
## Inventory where the caller has it already (the parts list's), else it is
## made here.
func short_of(world: BrickWorld, scenery: Dictionary, on_hand: Dictionary,
		stock: Inventory = null) -> Dictionary:
	var used: Dictionary = SetBin.used_in(world, scenery, library)
	var needs: Dictionary = {}
	var pieces: int = 0
	for key: String in used:
		if Collection.ownable(Collection.part_of(key), library):
			needs[key] = int(used[key])
			pieces += int(used[key])
	var shared: Dictionary = Collection.allocate(needs, on_hand)
	var have: Dictionary = (shared["have"] as Dictionary).duplicate()
	var owned: int = 0
	for key: String in have:
		owned += int(have[key])
	var free: Dictionary = {}
	for key: String in shared["spare"]:
		if int(shared["spare"][key]) > 0:
			free[key] = int(shared["spare"][key])
	if stock == null:
		stock = Inventory.of(world, library, scenery)
	var flexible: Dictionary = {}
	for path: Variant in stock.items:
		flexible[stock.items[path]] = true
	var lots: Array = []
	for lot: Inventory.Lot in stock.lots:
		if lot.custom:
			continue
		var key: String = Collection.key_of(lot.part_id, lot.color_code, library)
		if not needs.has(key):
			continue
		# Lots that share a spelling (an old number and its new one) share
		# what is owned of it, the first lot first.
		var mine: int = mini(lot.count, int(have.get(key, 0)))
		have[key] = int(have.get(key, 0)) - mine
		if mine >= lot.count:
			continue
		var short := Lot.new()
		short.key = "%s/%d" % [lot.part_id, lot.color_code]
		short.part = lot.part_id
		short.colour = lot.color_code
		short.name = lot.name
		short.colour_name = lot.color_name
		short.count = lot.count
		short.owned = mine
		short.flexible = flexible.has(lot)
		var info: PartLibrary.PartInfo = library.parts.get(library.resolve(lot.part_id))
		short.printed = info != null and (info.decor() & (PartLibrary.PartInfo.PRINTED
			| PartLibrary.PartInfo.STICKERED)) != 0
		lots.append(short)
	lots.sort_custom(func(a: Lot, b: Lot) -> bool:
		if a.short() != b.short():
			return a.short() > b.short()
		return a.key < b.key)
	return {"lots": lots, "pieces": pieces, "owned": owned, "free": free}


## The share of the model's pieces the person owns, as mine=true counts it:
## [param short] is [method short_of]'s.
static func share(short: Dictionary) -> float:
	return float(short["owned"]) / float(short["pieces"]) if int(short["pieces"]) > 0 else 1.0


# -- the swap -----------------------------------------------------------------------


## Every lot of [param lots] given its swap from [param free] (short_of's,
## used up as each is chosen, the biggest shortfall first), picked when it
## keeps the look. A part's shape is fetched first where it is not here
## ([param finder]'s FindReplace.shape: the web fetches what it has not got).
## The work goes on across frames ([constant SLICE_US]).
func offer_all(lots: Array, free: Dictionary, finder: FindReplace) -> void:
	var left: Dictionary = free.duplicate()
	var by_family: Dictionary = {}       ## a part's family -> the free keys of it
	for key: String in left:
		var family: String = Collection.family_of(Collection.part_of(key))
		if not by_family.has(family):
			by_family[family] = []
		(by_family[family] as Array).append(key)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var slice: int = Time.get_ticks_usec()
	for lot: Lot in lots:
		lot.into_part = ""
		lot.into_colour = -1
		lot.takes = 0
		lot.free = 0
		lot.delta_e = 0.0
		lot.more_points = 0
		lot.nearest = []
		var choices: Array = _colour_choices(lot, left, by_family)
		if not lot.flexible:
			choices.append_array(await _part_choices(lot, left, finder))
		# Those that keep the look first: a print's plain part only where none
		# of them can be had.
		choices.sort_custom(_better)
		for choice: Array in choices:
			var into: Dictionary = {"part": choice[1] if choice[0] == "part" else "",
				"color": int(choice[1]) if choice[0] == "colour" else -1}
			var took: Array = await pieces_for(lot, into, mini(int(choice[3]), lot.short()), int(choice[3]),
				finder)
			if took.is_empty():
				continue
			if choice[0] == "part":
				lot.into_part = str(choice[1])
				lot.more_points = int(choice[4])
			else:
				lot.into_colour = int(choice[1])
				lot.delta_e = float(choice[4])
			lot.takes = took.size()
			lot.free = int(choice[3])
			left[str(choice[2])] = int(left[str(choice[2])]) - lot.takes
			break
		if not lot.offered():
			lot.nearest = _nearest(lot, left, by_family)
		lot.picked = keeps_look(lot)
		if Time.get_ticks_usec() - slice > SLICE_US:
			await tree.process_frame
			slice = Time.get_ticks_usec()


## Whether [param lot]'s swap leaves the model looking as it did, and so is
## picked: every swap offered is the same shape in its colour or a close
## colour of its finish, but a print's plain part.
static func keeps_look(lot: Lot) -> bool:
	return lot.offered() and not lot.drops_print()


## The order choices are tried in: what keeps the look before a print's
## plain part, then the most of the shortfall covered, then the same colour,
## then the nearest, then the key.
static func _better(a: Array, b: Array) -> bool:
	if bool(a[5]) != bool(b[5]):
		return not bool(a[5])
	var cover_a: int = int(a[6])
	var cover_b: int = int(b[6])
	if cover_a != cover_b:
		return cover_a > cover_b
	if (a[0] == "part") != (b[0] == "part"):
		return a[0] == "part"
	var near_a: float = 0.0 if a[0] == "part" else float(a[4])
	var near_b: float = 0.0 if b[0] == "part" else float(b[4])
	if near_a != near_b:
		return near_a < near_b
	return str(a[2]) < str(b[2])


## The colours of [param lot]'s part, or a moulding of it, the person has
## free in [param left], close and of its transparency and finish: each
## ["colour", code, its key, free, ΔE, false, how much of the shortfall it
## covers].
func _colour_choices(lot: Lot, left: Dictionary, by_family: Dictionary) -> Array:
	var out: Array = []
	var want: PartLibrary.BrickColor = library.color(lot.colour)
	if want == null:
		return out
	var here: Vector3 = HiddenColours.lab(want.rgb)
	var plain: int = library.plain_code(lot.colour)
	for key: String in by_family.get(Collection.family_of(library.resolve(lot.part)), []):
		var spare: int = int(left.get(key, 0))
		var code: int = Collection.colour_of(key)
		if spare <= 0 or code == plain:
			continue
		var other: PartLibrary.BrickColor = library.color(code)
		if not matches_finish(want, other):
			continue
		var delta: float = HiddenColours.de2000(here, HiddenColours.lab(other.rgb))
		if delta > RareSwap.CLOSE_DE:
			continue
		out.append(["colour", code, key, spare, delta, false, mini(spare, lot.short())])
	return out


## Whether [param other] keeps [param want]'s kind of plastic: of it, not a
## sticker's or a fabric's; rubber for rubber; see-through for see-through;
## and the same finish family (RareSwap.family: solid, pearl and metallic,
## chrome, glitter, opal, glow).
static func matches_finish(want: PartLibrary.BrickColor, other: PartLibrary.BrickColor) -> bool:
	if want == null or other == null or not other.is_plastic():
		return false
	if (other.group == "rubber") != (want.group == "rubber"):
		return false
	return other.is_transparent() == want.is_transparent() and RareSwap.family(other) == RareSwap.family(want)


## The parts equal to [param lot]'s in its colour that the person has free
## in [param left]: each ["part", number, its key, free, points beyond the
## old part's, whether it drops a print, how much of the shortfall it
## covers], judged by their shapes (RareSwap.fits).
func _part_choices(lot: Lot, left: Dictionary, finder: FindReplace) -> Array:
	var out: Array = []
	var candidates: Array = []
	for other: String in _rare.equal_candidates(lot.part):
		var key: String = Collection.key_of(other, lot.colour, library)
		if int(left.get(key, 0)) > 0:
			candidates.append([other, key])
	if candidates.is_empty():
		return out
	var was: Lbm.PartMesh = await finder.shape(lot.part)
	if was == null:
		return out
	for each: Array in candidates:
		var more: int = RareSwap.fits(was, await finder.shape(str(each[0])))
		if more < 0:
			continue
		var spare: int = int(left[str(each[1])])
		out.append(["part", each[0], each[1], spare, more, lot.printed, mini(spare, lot.short())])
	return out


## What the person owns of [param lot]'s part, or a moulding of it, in another
## colour that is no swap: the nearest, [code, ΔE, how many free], or [].
func _nearest(lot: Lot, left: Dictionary, by_family: Dictionary) -> Array:
	var want: PartLibrary.BrickColor = library.color(lot.colour)
	if want == null:
		return []
	var here: Vector3 = HiddenColours.lab(want.rgb)
	var best: Array = []
	for key: String in by_family.get(Collection.family_of(library.resolve(lot.part)), []):
		var spare: int = int(left.get(key, 0))
		var other: PartLibrary.BrickColor = library.color(Collection.colour_of(key))
		if spare <= 0 or other == null:
			continue
		var delta: float = HiddenColours.de2000(here, HiddenColours.lab(other.rgb))
		if best.is_empty() or delta < float(best[1]):
			best = [Collection.colour_of(key), delta, spare]
	return best


# -- the pieces a swap changes ------------------------------------------------------


## The parts of [param lot] that [param into] ({"part", "color"}) changes to
## cover [param need] of it with no more than [param most] changed: its parts
## as Find and Replace finds them (RareSwap.found_for), taken a copy group at
## a time as FindReplace.plan groups them (a part in a copy changes with its
## twin in every other copy), the model's own parts before those in copies;
## a group with no room, locked or bigger than what is left is passed over.
## The ids, each once; [] for none.
func pieces_for(lot: Lot, into: Dictionary, need: int, most: int, finder: FindReplace) -> Array:
	if need <= 0 or most <= 0:
		return []
	var found: Dictionary = found_for(lot, finder)
	var ids: Array = found["ids"]
	if ids.is_empty():
		return []
	if not str(into.get("part", "")).is_empty() and await finder.shape(str(into["part"])) == null:
		return []
	# The lot planned once as a whole: every one of them where all are short
	# and there is enough for them; else what can change at all.
	var whole: Array = _changed_by(finder.plan(found, into))
	if need >= ids.size() and not whole.is_empty() and whole.size() <= most:
		return whole
	var can: Dictionary = {}
	for brick_id: int in whole:
		can[brick_id] = true
	var following: Dictionary = found.get("follow", {})
	var order: Array = ids.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool:
		var in_a: bool = not Assemblies.path_of(finder.world.get_brick(a)).is_empty()
		var in_b: bool = not Assemblies.path_of(finder.world.get_brick(b)).is_empty()
		if in_a != in_b:
			return not in_a
		return ids.find(a) < ids.find(b))
	var taken: Dictionary = {}
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var slice: int = Time.get_ticks_usec()
	for brick_id: int in order:
		if taken.size() >= need:
			break
		if taken.has(brick_id) or not can.has(brick_id):
			continue
		# A part of the model's own, in no sub-model and followed by no
		# mirror, is a group of one, with room as the whole plan found it (with
		# fewer changed there is no less room); one in a sub-model is planned
		# alone, with the twins its copies' follow reaches.
		var brick: BrickWorld.Brick = finder.world.get_brick(brick_id)
		var alone: bool = brick != null and Assemblies.path_of(brick).is_empty() \
			and not following.has(brick_id) and not following.values().has(brick_id)
		var group: Array = [brick_id] if alone \
			else _changed_by(finder.plan(RareSwap.narrowed(found, {brick_id: true}, finder), into))
		if group.is_empty() or taken.size() + group.size() > most \
				or group.any(func(each: int) -> bool: return taken.has(each)):
			continue
		for each: int in group:
			taken[each] = true
		if Time.get_ticks_usec() - slice > SLICE_US:
			await tree.process_frame
			slice = Time.get_ticks_usec()
	return taken.keys()


## Every part a FindReplace.plan changes: those changed where they stand, those
## that follow their copy, and the twins the copies' follow reaches.
static func _changed_by(planned: Dictionary) -> Array:
	var out: Array = []
	for change: Dictionary in planned["changes"]:
		out.append(int(change["brick"]))
	for brick_id: int in planned["follow"]:
		out.append(brick_id)
	for brick_id: int in planned["followers"]:
		if not out.has(brick_id):
			out.append(brick_id)
	return out


## [param lot]'s parts as Find and Replace finds them, as RareSwap.found_for
## finds a rare lot's: its own part in its colour, those the parts list
## counts in it; locked ones left out and counted.
func found_for(lot: Lot, finder: FindReplace) -> Dictionary:
	var stock: Inventory = Inventory.of(finder.world, library, finder.scenery)
	var ids: Dictionary = {}
	for each: Inventory.Lot in stock.lots:
		if each.part_id == lot.part and each.color_code == lot.colour:
			for brick_id: int in each.bricks:
				ids[brick_id] = true
	var found: Dictionary = finder.find({"part": "" if lot.flexible else lot.part, "color": lot.colour}, "all")
	return RareSwap.narrowed(found, ids, finder)


# -- swapping -----------------------------------------------------------------------


## The picked lots of [param lots] swapped through [param finder]'s Find and
## Replace, as one undo step: {"lots": how many lots changed, "changed": how
## many parts, "stayed": what stayed and why, a line a lot, "words": the
## step's, "put_back": how many parts in hand went back first}. Each lot's
## parts are found again before its swap (a swap inside a sub-model lays its
## copies again), and no more of them change than its swap was given.
func swap(lots: Array, finder: FindReplace) -> Dictionary:
	var builder: Builder = finder.builder
	var put_back: int = finder.put_back_held()
	var depth: int = builder.history_depth()
	var swapped: int = 0
	var changed: int = 0
	var stayed := PackedStringArray()
	if put_back < 0:
		stayed.append(FindReplace.HELD_WORDS)
	for lot: Lot in lots:
		if put_back < 0 or not lot.picked or not lot.offered():
			continue
		var into: Dictionary = {"part": lot.into_part, "color": lot.into_colour}
		if not lot.into_part.is_empty():
			var other: String = Mirror.counterpart(library, lot.into_part)
			if not other.is_empty():
				await finder.shape(other)
		var ids: Array = await pieces_for(lot, into, lot.takes, lot.takes, finder)
		if ids.is_empty():
			var found: Dictionary = found_for(lot, finder)
			stayed.append("%s: %s" % [lot.name, "; ".join(FindReplace.stay_words(found, {}))
				if int(found.get("locked", 0)) > 0 else "no room for it"])
			continue
		var kept: Dictionary = {}
		for brick_id: int in ids:
			kept[brick_id] = true
		var done: Dictionary = finder.replace(RareSwap.narrowed(found_for(lot, finder), kept, finder), into)
		changed += int(done["changed"])
		if int(done["changed"]) > 0:
			swapped += 1
		if not str(done.get("stayed", "")).is_empty():
			stayed.append("%s: %s" % [lot.name, str(done["stayed"])])
	var words: String = swapped_words(swapped, changed)
	builder.fold_since(depth, words)
	if builder.history_depth() == depth + 1:
		builder.name_newest(words)
	return {"lots": swapped, "changed": changed, "stayed": stayed, "words": words,
		"put_back": maxi(put_back, 0)}


## "swapped 3 lots for parts you own, 9 parts": the undo step's words.
static func swapped_words(lots: int, parts: int) -> String:
	return "swapped %s for parts you own, %s" % [Counted.of(lots, "lot"), Counted.of(parts, "part")]


# -- words --------------------------------------------------------------------------


## What [param lot] is and what it becomes, as the parts list's row and a
## session read it.
func lot_words(lot: Lot) -> String:
	return from_words(lot) + " → " + into_words(lot)


## What [param lot] is: "4 × Brick 2 x 4 (3001) in Light Bluish Grey, you own
## 1". The list draws it apart from [method into_words], so each is one
## entry of the words in another language.
func from_words(lot: Lot) -> String:
	return "%d × %s (%s) in %s, %s" % [lot.count, lot.name, lot.part, lot.colour_name,
		owned_words(lot.owned)]


## "you own none", "you own 1", "you own 3".
static func owned_words(owned: int) -> String:
	return "you own none" if owned <= 0 else "you own %s" % Working.comma(owned)


## What [param lot] becomes, or why nothing it can: "Light Grey (ΔE 5.7), a
## close colour: 3 of your 5 free"; "Plate 1 x 2 with Groove (3794b), the
## same shape and connections in its colour: 3 of your 4 free"; "none you
## own: the nearest you have of it is Black (ΔE 38.2), 12 free". A swap that
## covers only some says how many are still missing, after "; ".
func into_words(lot: Lot) -> String:
	if not lot.offered():
		if lot.nearest.is_empty():
			return "none you own: you have none of it in any colour to spare"
		return "none you own: the nearest you have of it is %s (ΔE %.1f), not close" % [
			_colour_named(int(lot.nearest[0])), float(lot.nearest[1])]
	var said: String = ""
	if not lot.into_part.is_empty():
		var info: PartLibrary.PartInfo = library.parts.get(lot.into_part)
		var named: String = Inventory._tidy(info.name) if info != null else lot.into_part
		if lot.drops_print():
			said = "the plain %s (%s) in its colour, without its print" % [named, lot.into_part]
		elif lot.more_points > 0:
			said = "%s (%s), the same shape in its colour, holding all its connections and more" % [named,
				lot.into_part]
		else:
			said = "%s (%s), the same shape and connections in its colour" % [named, lot.into_part]
	else:
		said = "%s (ΔE %.1f), a close colour" % [_colour_named(lot.into_colour), lot.delta_e]
	said += ": %s" % taken_words(lot.takes, lot.free)
	if lot.missing_after() > 0:
		said += "; %s still missing" % Working.comma(lot.missing_after())
	return said


## "3 of your 5 free", "all 3 of yours free".
static func taken_words(takes: int, free: int) -> String:
	if takes >= free:
		return "all %s of yours free" % Working.comma(free) if free != 1 else "the 1 of yours free"
	return "%s of your %s free" % [Working.comma(takes), Working.comma(free)]


func _colour_named(code: int) -> String:
	var colour: PartLibrary.BrickColor = library.color(code)
	return colour.name.replace("_", " ") if colour != null else str(code)


## What is still missing once the swaps are in, by lots and pieces: "4 lots,
## 9 pieces"; "" for none. [param lots] is short_of's after them.
static func missing_words(short: Dictionary) -> String:
	var pieces: int = 0
	for lot: Lot in short["lots"]:
		pieces += lot.short()
	if pieces == 0:
		return ""
	return "%s, %s" % [Counted.of((short["lots"] as Array).size(), "lot"), Counted.of(pieces, "piece")]


## "62% of its 1,204 pieces are yours (746)": the owned share, as mine=true
## counts it.
static func share_words(short: Dictionary) -> String:
	return "%d%% of its %s are yours (%s)" % [int(floor(share(short) * 100.0)),
		Counted.of(int(short["pieces"]), "piece"), Working.comma(int(short["owned"]))]
