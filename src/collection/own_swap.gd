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
##   see-through and finish exactly (RareSwap.keeps_finish, rareswap's own
##   rule): no chrome, pearl, metallic, milky, fluorescent or see-through for
##   a solid, nor the reverse, nor metallic for pearl, and never conductive
##   plastic or an ink;
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
## passed over. A lot's swap changes only the lot's own parts (decided for
## osreview H2): a group that would change a part of another lot, a left
## wing's mirrored twin that is a right wing, is passed over and said so,
## rather than charged to the twin's own part and colour, which would swap
## another lot's pieces under this one's words and count; the twin's lot is
## offered its own swap. The swaps are made through Find and Replace in one
## change of the model (FindReplace.replace_all), one undo step; a part
## lifted and still in hand is put back where it was first, as Escape puts
## it (FindReplace.put_back_held), and never lost.
##
## The model is looked at once for an offer or a swap, not once a lot
## (osreview H3: two looks a lot were 474 ms of one frame on Orthanc and
## Use what I own took 31.8 s on 10179): each lot's parts from its own ids,
## the copies' frames read once (and kept from the list to Use what I own
## while the model is as it was), the copies counted once, and how copies
## lie on each other kept across every plan, and from the list to Use what I
## own too while the model is as it was. An offer or a swap goes on a slice
## of a frame at a time (FramePace, one for the whole act, every part judged
## counted against it), the status bar saying so once a slice is spent
## (Working), and the model asked after every wait whether it changed.
## Still one frame: the change itself, every lot's replace and the copies'
## follow in one change of the model (160 to 184 ms on Orthanc and 10179 at
## load 60 to 66, smalls12i1). Made a lot at a time and folded into one
## step, as RareSwap.swap makes its own, each lot's change laid every copy
## it touched on the others again: every frame of it was worse, 260 to 350
## ms on Orthanc and up to 680 ms on 10179, and the whole 3.8 and 17 s.
class_name OwnSwap
extends RefCounted

## What a lot's swap is when its pieces' groups would change another lot's
## parts (osreview H2).
const TWIN_WORDS := "none you own for these alone: a swap would change their twins in other copies, which are another lot"


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
	## The part and colour of the person's its swap takes from, as
	## CollectionStore.on_hand keys them.
	var from_key: String = ""
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
	## Its parts' ids as the parts list counted them when the lot was made:
	## what an offer finds them by, with the model as it was.
	var bricks: Array = []
	## Its swap was passed over only because each group of its pieces holds
	## another lot's part (TWIN_WORDS).
	var twins: bool = false

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
## RareSwap's matcher: its equal parts.
var _rare: RareSwap
## The one look at the model an offer or a swap makes ([method _look]): the
## model as it was looked at, its copies' frames (FindReplace._frames_for of
## every part, read once on first need), and FindReplace.plan's cache.
var _looked_as: Array = []
var _frames: Variant = null
## How many copies the model has of each sub-model (FindReplace's
## _copies_by_definition), read once a look; with the frames, kept from the
## list to Use what I own while the model is as it was ([member _kept_as]).
var _copies: Variant = null
var _kept_as: Array = []
var _cache: Dictionary = {}
## Each lot's parts as found, by its key, for the model as looked at.
var _found: Dictionary = {}
## The last [method pieces_for] passed over a group only because it held
## another lot's part.
var _twinned: bool = false
## The act going on, an offer or a swap ([method _begin]): its slices of a
## frame, what the status bar says once one is spent, and the job saying it,
## begun only then (as the parts list's fill begins its own), so a small
## model's act says nothing.
var _pace: FramePace = null
var _doing: String = ""
var _job: Working.Job = null


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
	var free: Dictionary = _spare(shared)
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
		short.bricks = Array(lot.bricks)
		short.flexible = flexible.has(lot)
		var info: PartLibrary.PartInfo = library.parts.get(library.resolve(lot.part_id))
		short.printed = info != null and (info.decor() & (PartLibrary.PartInfo.PRINTED
			| PartLibrary.PartInfo.STICKERED)) != 0
		lots.append(short)
	lots.sort_custom(func(a: Lot, b: Lot) -> bool:
		if a.short() != b.short():
			return a.short() > b.short()
		return a.key < b.key)
	return {"lots": lots, "pieces": pieces, "owned": owned, "free": free, "needs": needs}


## What is free of [param on_hand] now for the model [param short]
## (short_of's) was counted for: key -> pieces owned and not used by it.
static func free_now(short: Dictionary, on_hand: Dictionary) -> Dictionary:
	return _spare(Collection.allocate(short.get("needs", {}), on_hand))


static func _spare(shared: Dictionary) -> Dictionary:
	var free: Dictionary = {}
	for key: String in shared["spare"]:
		if int(shared["spare"][key]) > 0:
			free[key] = int(shared["spare"][key])
	return free


## Whether a picked swap of [param lots] takes more than [param free]
## (free_now's) has of what it takes: the collection changed since the
## swaps were worked out (osreview M1: 4 went in of a part no longer owned).
static func stale(lots: Array, free: Dictionary) -> bool:
	var takes: Dictionary = {}
	for lot: Lot in lots:
		if lot.picked and lot.offered():
			takes[lot.from_key] = int(takes.get(lot.from_key, 0)) + lot.takes
	for key: String in takes:
		if int(takes[key]) > int(free.get(key, 0)):
			return true
	return false


## The share of the model's pieces the person owns, as mine=true counts it:
## [param short] is [method short_of]'s.
static func share(short: Dictionary) -> float:
	return float(short["owned"]) / float(short["pieces"]) if int(short["pieces"]) > 0 else 1.0


# -- the swap -----------------------------------------------------------------------


## Every lot of [param lots] given its swap from [param free] (short_of's,
## used up as each is chosen, the biggest shortfall first), picked when it
## keeps the look. A part's shape is fetched first where it is not here
## ([param finder]'s FindReplace.shape: the web fetches what it has not got).
## The work goes on a slice of a frame at a time, the status bar saying so;
## where the model changes meanwhile, it is looked at again and the lot
## being worked out is worked out afresh in it.
func offer_all(lots: Array, free: Dictionary, finder: FindReplace) -> void:
	_begin("Finding a part or colour of yours for each…")
	_look(finder)
	var left: Dictionary = free.duplicate()
	var by_family: Dictionary = {}       ## a part's family -> the free keys of it
	for key: String in left:
		var family: String = Collection.family_of(Collection.part_of(key))
		if not by_family.has(family):
			by_family[family] = []
		(by_family[family] as Array).append(key)
	await _prepare(finder)
	var n: int = 0
	while n < lots.size():
		if _changed(finder):
			_look(finder)
			await _prepare(finder)
			continue
		var lot: Lot = lots[n]
		lot.into_part = ""
		lot.into_colour = -1
		lot.takes = 0
		lot.free = 0
		lot.delta_e = 0.0
		lot.more_points = 0
		lot.nearest = []
		lot.twins = false
		lot.from_key = ""
		var choices: Array = _colour_choices(lot, left, by_family)
		if not lot.flexible:
			choices.append_array(await _part_choices(lot, left, finder))
		# Those that keep the look first: a print's plain part only where none
		# of them can be had.
		choices.sort_custom(_better)
		var twinned: bool = false
		for choice: Array in choices:
			if _changed(finder):
				break
			var into: Dictionary = {"part": choice[1] if choice[0] == "part" else "",
				"color": int(choice[1]) if choice[0] == "colour" else -1}
			var took: Array = await pieces_for(lot, into, mini(int(choice[3]), lot.short()), int(choice[3]),
				finder)
			if _changed(finder):
				break
			if took.is_empty():
				twinned = twinned or _twinned
				continue
			if choice[0] == "part":
				lot.into_part = str(choice[1])
				lot.more_points = int(choice[4])
			else:
				lot.into_colour = int(choice[1])
				lot.delta_e = float(choice[4])
			lot.takes = took.size()
			lot.free = int(choice[3])
			lot.from_key = str(choice[2])
			left[str(choice[2])] = int(left[str(choice[2])]) - lot.takes
			break
		# Nothing of it taken yet: worked out again in the model as it now is.
		if _changed(finder):
			continue
		if not lot.offered():
			lot.twins = twinned
			lot.nearest = _nearest(lot, left, by_family)
		lot.picked = keeps_look(lot)
		n += 1
		await _paced(finder)
	_end()


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
## free in [param left], close and of its see-through and finish exactly
## (RareSwap.keeps_finish): each
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
		if not RareSwap.keeps_finish(want, library.color(code)):
			continue
		var delta: float = HiddenColours.de2000(here, HiddenColours.lab(library.color(code).rgb))
		if delta > RareSwap.CLOSE_DE:
			continue
		out.append(["colour", code, key, spare, delta, false, mini(spare, lot.short())])
	return out


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
## as Find and Replace finds them ([method found_for]), taken a copy group at
## a time as FindReplace.plan groups them (a part in a copy changes with its
## twin in every other copy), the model's own parts before those in copies;
## a group with no room, locked, bigger than what is left, or holding a part
## of another lot (osreview H2: a left wing's mirrored twin, a right wing
## the person owns none of, went Light Grey under the left wing's count) is
## passed over. A part of the model's own in no mirror's copy is a group of
## one, a colour put on it where it stands with no plan. The ids, each once;
## [] for none, and where the model changed while the act's slices of a
## frame went on ([method _paced]).
func pieces_for(lot: Lot, into: Dictionary, need: int, most: int, finder: FindReplace) -> Array:
	_twinned = false
	if need <= 0 or most <= 0:
		return []
	var found: Dictionary = found_for(lot, finder)
	var ids: Array = found["ids"]
	if ids.is_empty():
		return []
	var swaps_part: bool = not str(into.get("part", "")).is_empty()
	if swaps_part and await finder.shape(str(into["part"])) == null:
		return []
	var mine: Dictionary = {}
	for brick_id: int in ids:
		mine[brick_id] = true
	var following: Dictionary = found.get("follow", {})
	var followed: Dictionary = {}
	for brick_id: int in following:
		followed[int(following[brick_id])] = true
	var own: Array = []
	var own_ids: Dictionary = {}
	var copied: Array = []
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = finder.world.get_brick(brick_id)
		if brick != null and Assemblies.path_of(brick).is_empty():
			own.append(brick_id)
			own_ids[brick_id] = true
		else:
			copied.append(brick_id)
	var taken: Dictionary = {}
	var seen: Dictionary = {}            ## the parts of a group already judged
	var passed_twins: bool = false
	for brick_id: int in own + copied:
		if taken.size() >= need:
			break
		# Every part counted against the act's slice, those passed over too,
		# and the model asked after the wait: [] where it changed (the caller
		# asks too, and works the lot out again or stops).
		if not await _paced(finder):
			return []
		if seen.has(brick_id):
			continue
		var alone: bool = not swaps_part and not following.has(brick_id) and not followed.has(brick_id) \
			and own_ids.has(brick_id)
		var group: Array = [brick_id] if alone \
			else _changed_by(finder.plan(RareSwap.narrowed(found, {brick_id: true}, finder), into, _cache))
		for each: int in group:
			seen[each] = true
		seen[brick_id] = true
		if group.is_empty() or taken.size() + group.size() > most \
				or group.any(func(each: int) -> bool: return taken.has(each)):
			continue
		if group.any(func(each: int) -> bool: return not mine.has(each)):
			passed_twins = true
			continue
		for each: int in group:
			taken[each] = true
	_twinned = taken.is_empty() and passed_twins
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
## counts in it; locked ones left out and counted. Found from the ids the
## lot was made with, among the model as [method _look] looked at it, once
## a lot; where one of them is gone or changed, from the parts list's count
## taken again.
func found_for(lot: Lot, finder: FindReplace) -> Dictionary:
	if _found.has(lot.key):
		return _found[lot.key]
	var bricks: Array = []
	var asked: String = "" if lot.flexible else lot.part
	for brick_id: int in lot.bricks:
		var brick: BrickWorld.Brick = finder.world.get_brick(brick_id)
		if brick == null or brick.color_code != lot.colour \
				or not asked.is_empty() and not finder.same_part(brick.part_id, asked):
			bricks.clear()
			break
		bricks.append(brick)
	if bricks.is_empty():
		var stock: Inventory = Inventory.of(finder.world, library, finder.scenery)
		for each: Inventory.Lot in stock.lots:
			if each.part_id == lot.part and each.color_code == lot.colour:
				for brick_id: int in each.bricks:
					bricks.append(finder.world.get_brick(brick_id))
	if _copies == null:
		_copies = finder._copies_by_definition()
	if _frames == null:
		_frames = finder._frames_for(finder.world.bricks(), _copies)
	var found: Dictionary = finder.find_among(bricks.filter(func(brick: BrickWorld.Brick) -> bool:
		return brick != null and not finder.scenery.has(brick.id)), {"part": asked, "color": lot.colour},
		"all", _frames, _copies)
	_found[lot.key] = found
	return found


## The model looked at for an offer or a swap: where it changed since the
## last look, what was kept of it is let go, so [method found_for] finds each
## lot again in the model as it now is and FindReplace.plan lays copies on
## each other again. Where it has not (Use what I own pressed on the list
## just worked out), each lot as found and how the copies lie on each other
## are kept: let go, the swap laid each copy a lot touches on every other
## copy again (FindReplace._copy_on), a whole frame's work for a big one.
func _look(finder: FindReplace) -> void:
	_looked_as = _model_of(finder)
	if _kept_as != _looked_as:
		_frames = null
		_copies = null
		_cache = {}
		_found = {}
	_kept_as = _looked_as


## The model's copies counted, and its copies' frames read a slice of a
## frame at a time (FindReplace.frames_paced_for), each counted against the
## act's slice: each is a call over the whole model, and the frames were one
## frame of 0.96 s on 10179 (osfix).
func _prepare(finder: FindReplace) -> void:
	if _copies == null:
		await _paced(finder)
		_copies = finder._copies_by_definition()
	if _frames == null:
		await _paced(finder)
		_frames = await finder.frames_paced_for(finder.world.bricks(), _copies)
	# FindReplace.plan's own count of them, not read again.
	if not _cache.has("copies"):
		_cache["copies"] = _copies
		_cache["matches"] = {}
		_cache["copied"] = {}
	await _paced(finder)


## The act begun: its slices of a frame, and what the status bar says once
## one is spent ([method _paced]).
func _begin(words: String) -> void:
	_end()
	_pace = FramePace.new()
	_doing = words


## The act done, and the status bar's words for it taken back.
func _end() -> void:
	if _job != null:
		_job.end()
		_job = null
	_pace = null


## The frame given back where the act's slice is spent, the status bar saying
## what goes on from then: whether the model is still as [method _look]
## looked at it (no act going on, true).
func _paced(finder: FindReplace) -> bool:
	if _pace == null:
		return true
	if _pace.due():
		if _job == null:
			_job = Working.begin(_doing)
		await _pace.next()
	return not _changed(finder)


## Whether the model changed since [method _look] looked at it.
func _changed(finder: FindReplace) -> bool:
	return _model_of(finder) != _looked_as


## What the model is, as [method _look] keeps it: whether it has changed
## since.
static func _model_of(finder: FindReplace) -> Array:
	return [finder.world.generation(), finder.world.revision]


# -- swapping -----------------------------------------------------------------------


## Said when the model changed while a swap was worked out across frames.
const CHANGED_WORDS := "the model changed while the swaps were worked out: nothing swapped, look at the swaps again"


## The picked lots of [param lots] swapped through [param finder]'s Find and
## Replace, as one undo step: {"lots": how many lots changed, "changed": how
## many parts, "stayed": what stayed and why, a line a lot, "words": the
## step's, "put_back": how many parts in hand went back first}. Each lot's
## parts are found in the model as it stands (as the list found them, where
## it has not changed since), worked out a slice of a frame at a time with
## the status bar saying so, and changed together in one change of the
## model (FindReplace.replace_all), no more of a lot's than its swap was
## given. A model changed in between is left as it is and said ([constant
## CHANGED_WORDS]).
func swap(lots: Array, finder: FindReplace) -> Dictionary:
	var builder: Builder = finder.builder
	var put_back: int = finder.put_back_held()
	var swapped: int = 0
	var changed: int = 0
	var stayed := PackedStringArray()
	var out: Dictionary = {"lots": 0, "changed": 0, "stayed": stayed, "words": swapped_words(0, 0),
		"put_back": maxi(put_back, 0)}
	if put_back < 0:
		stayed.append(FindReplace.HELD_WORDS)
		return out
	_begin("Swapping in the parts you own…")
	# Its own, should an offer begin and end meanwhile (_begin, _end).
	var pace: FramePace = _pace
	_look(finder)
	var jobs: Array = []
	await _prepare(finder)
	for lot: Lot in lots:
		if _changed(finder):
			break
		if not lot.picked or not lot.offered():
			continue
		var into: Dictionary = {"part": lot.into_part, "color": lot.into_colour}
		if not lot.into_part.is_empty():
			var other: String = Mirror.counterpart(library, lot.into_part)
			if not other.is_empty():
				await finder.shape(other)
		var ids: Array = await pieces_for(lot, into, lot.takes, lot.takes, finder)
		if _changed(finder):
			break
		if ids.is_empty():
			var found: Dictionary = found_for(lot, finder)
			stayed.append("%s: %s" % [lot.name, "; ".join(FindReplace.stay_words(found, {}))
				if int(found.get("locked", 0)) > 0 else "no room for it"])
			continue
		var kept: Dictionary = {}
		for brick_id: int in ids:
			kept[brick_id] = true
		var narrowed: Dictionary = RareSwap.narrowed(found_for(lot, finder), kept, finder)
		jobs.append({"found": narrowed, "into": into, "made": finder.plan(narrowed, into, _cache), "lot": lot})
		await _paced(finder)
	# The change in a frame of its own, none of the working out added to it.
	if _job == null:
		_job = Working.begin(_doing)
	await pace.next()
	if _changed(finder):
		_end()
		stayed.append(CHANGED_WORDS)
		return out
	var done: Array = finder.replace_all(jobs)
	for n: int in done.size():
		changed += int(done[n]["changed"])
		if int(done[n]["changed"]) > 0:
			swapped += 1
		if not str(done[n].get("stayed", "")).is_empty():
			stayed.append("%s: %s" % [(jobs[n]["lot"] as Lot).name, str(done[n]["stayed"])])
	var words: String = swapped_words(swapped, changed)
	if changed > 0:
		builder.name_newest(words)
	_look(finder)
	_end()
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
		if lot.twins:
			return TWIN_WORDS
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
