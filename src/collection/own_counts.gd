## The parts a person owns against what a model uses: how many of each are
## left, which ones the model has more of than they own, said for a session,
## and the bin that counts them down as the model is built (From my bricks,
## docs/APP_UX8.md #4 and unit 5, ownlimit).
##
## What they own is the pool every sum of the collection is done against
## (CollectionStore.on_hand, Collection.pool): their sets' parts, less those
## marked missing, and their loose parts, by part and colour in Collection's
## spelling. Nothing here is kept. Each count is worked out again from the
## pool and the model whenever either changes, as SetBin's are, so a part put
## down, an undo, a delete, a model opened or the collection changed on
## another device all count the same, and nothing can drift.
##
## A set kept built on a shelf is not free to build with, but nothing says
## which are: My collection keeps a set's copies and what each is missing,
## not whether it stands built (keptbuilt, docs/APP_UX7.md #7, never landed).
## So every set owned counts as loose bricks, and the bin says so
## ([constant BUILT_WORDS]) rather than count a shelf's sets silently.
class_name OwnCounts
extends RefCounted

## The word a model keeps its bin as, on its BIN line (SetBin.META), when the
## bin is the person's own bricks rather than sets by number. No set number
## is one word without a dash, so the two never meet.
const WORD := "mine"
## The bin's name on its line, and in a tile's tooltip.
const TITLE := "My bricks"
## What the bin's line says of sets kept built.
const BUILT_WORDS := "Every set you own counts, built or not: My collection cannot mark a set as kept built yet."


## What the person has to build with, from the pool ([param on_hand]). A set
## kept built would come off here, once My collection can say which are.
static func owned(on_hand: Dictionary) -> Dictionary:
	return on_hand


## How many of each part and colour are left once [param used] is taken off
## [param have]: every key of either, below nought where the model has more
## than they own.
static func left(have: Dictionary, used: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in have:
		out[key] = int(have[key]) - int(used.get(key, 0))
	for key: String in used:
		if not out.has(key):
			out[key] = -int(used[key])
	return out


## The parts [param used] has more of than [param have] holds, as What do I
## need? counts them (Collection.plan: another moulding of a part counts as
## it): each row's "short" is how many over, with what could stand in, the
## same part in a colour they have spare ("swaps") or two smaller parts in
## the colour ("combos"). Parts nobody owns on their own, stickers and the
## like (Collection.ownable), are not counted.
static func over(have: Dictionary, used: Dictionary, library: PartLibrary) -> Array:
	var needs: Dictionary = {}
	for key: String in used:
		if library == null or Collection.ownable(Collection.part_of(key), library):
			needs[key] = int(used[key])
	return Collection.plan(needs, have, library).filter(func(row: Dictionary) -> bool:
		return int(row["short"]) > 0)


## The bin of [param have]'s parts, a tile each part and colour, the most held
## first, counting down as the model uses them (PartsBin.build_from with
## [constant WORD]).
static func bin(have: Dictionary, library: PartLibrary) -> SetBin:
	var made := SetBin.new()
	made.sets = PackedStringArray([WORD])
	made.title = TITLE
	for key: String in have:
		if int(have[key]) > 0:
			made.have[key] = int(have[key])
			made.pieces += int(have[key])
	made.lay_out(library)
	return made


## What a session hears of a design held to the person's parts
## (submit_design mine=true): every part theirs, or each one it goes over and
## by how many, with what they own that could stand in. [param have] is what
## they own, [param used] what the model now uses, both by key.
static func said(have: Dictionary, used: Dictionary, library: PartLibrary, most: int = 40) -> String:
	if have.is_empty():
		return ("mine=true, but the person's collection is empty, or they are not signed in: nothing "
			+ "could be held to it. They add their sets and parts in Build, My collection.")
	var rows: Array = over(have, used, library)
	var pieces: int = 0
	for key: String in used:
		if library == null or Collection.ownable(Collection.part_of(key), library):
			pieces += int(used[key])
	var owned_pieces: int = 0
	for key: String in have:
		owned_pieces += int(have[key])
	if rows.is_empty():
		return ("From the person's own parts (mine=true): every one of its %s is in their collection "
			+ "in its colour, %s of their %s, as the bin's My bricks counts them.") % [
			Counted.of(pieces, "piece"), Counted.of(maxi(0, owned_pieces - pieces), "piece left", "pieces left"),
			Working.comma(owned_pieces)]
	var short: int = 0
	var lines := PackedStringArray()
	for row: Dictionary in rows:
		short += int(row["short"])
		if lines.size() < most:
			lines.append("  " + _row_said(row, library))
	if rows.size() > most:
		lines.append("  and %d more parts." % (rows.size() - most))
	return ("Over the person's collection (mine=true): %s it uses more of than they own, %s over "
		+ "in all:\n%s\nChange each to a part they own with edit_model (search_parts lists theirs "
		+ "first, with how many of each colour), or tell them what to get; parts_list which=\"need\" "
		+ "says what is still short.") % [Counted.of(rows.size(), "part"), Counted.of(short, "piece"),
		"\n".join(lines)]


## One part over: "3001 Brick 2 x 4 in Red: 6 used, they own 4, 2 over; they
## have it spare in Black (3)".
static func _row_said(row: Dictionary, library: PartLibrary) -> String:
	var part: String = str(row["part"])
	var stand_in := PackedStringArray()
	for swap: Dictionary in row.get("swaps", []):
		stand_in.append("%d spare in %s" % [int(swap["qty"]), _colour(int(swap["colour"]), library)])
	for combo: Dictionary in row.get("combos", []):
		var pieces := PackedStringArray()
		for piece: Array in combo["parts"]:
			pieces.append("%d x %s" % [int(piece[1]), _part(str(piece[0]), library)])
		stand_in.append("%s in its colour for %s" % [" and ".join(pieces),
			"one of them" if int(combo["qty"]) == 1 else "%d of them" % int(combo["qty"])])
	return "%s in %s: %d used, they own %d, %d over%s" % [_part(part, library),
		_colour(int(row["colour"]), library), int(row["need"]), int(row["have"]), int(row["short"]),
		"; they have " + ", ".join(stand_in) if not stand_in.is_empty() else ""]


static func _part(part: String, library: PartLibrary) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part) if library != null else null
	return "%s %s" % [part, Inventory._tidy(info.name)] if info != null else part


static func _colour(code: int, library: PartLibrary) -> String:
	return "%s (%d)" % [Collection._colour_name(code, library), code]
