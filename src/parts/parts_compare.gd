## What one set or model shares with another, piece by piece (APP_UX6 #7,
## comparesets): the parts in both, the parts in only one, by part and
## colour, and what to buy to build the second from the first.
##
## Rebrickable's set compare is its most used question, "can I build this
## from that set?"; Brickworks compared a model only with its own saves
## (ModelDiff) and with the whole collection (What do I need?). A side here is
## any of a set (its inventory, SetInventories), a saved model or an example
## (its file, read as What can I build? reads it), or the model open now (its
## parts list, as What do I need? reads it), each in Collection.key_of's
## spelling, so a part LDraw renumbered and a tyre in Rubber Black compare as
## what a shop sells.
##
## The sums are Collection.allocate's, as What do I need? does them: each
## piece of B is matched to one of A, its own part and colour first, then
## another moulding of it in that colour (3794a for 3794b). So every piece of
## A is either in both or only in A, and every piece of B in both or only in
## B, and the counts add up to each side's pieces exactly. What is only in B
## is the list to buy, and it leaves through the shops' own writers
## (ShopLists, by Exports.stock_list), a part in a direct colour in the
## colour still made nearest it.
class_name PartsCompare
extends RefCounted

const OPEN := "open"
const SET := "set"
const MODEL := "model"


## One side: what it is, its name, and its parts.
class Side extends RefCounted:
	## [constant OPEN], [constant SET] or [constant MODEL].
	var kind: String = ""
	## As a person reads it: "7140-1 X-wing Fighter (1999)", "Car".
	var name: String = ""
	## As a file and a tab name it: "7140-1", "Car".
	var short: String = ""
	## Collection.key_of's "part/colour" -> how many.
	var counts: Dictionary = {}
	var pieces: int = 0
	## A set's spare parts, which are not counted, as Rebrickable's compare
	## leaves them out; the open model's stickers and made parts, which no
	## shop sells on their own (Collection.ownable), likewise.
	var not_counted: int = 0
	## Why it could not be read; empty when it was.
	var trouble: String = ""

	func ok() -> bool:
		return trouble.is_empty()

	func _sum() -> void:
		pieces = 0
		for key: String in counts:
			pieces += int(counts[key])


var a: Side
var b: Side
## B's key -> how many of B's pieces A has too: its own, or another moulding.
var both: Dictionary = {}
## A's key -> the pieces of it B does not use.
var only_a: Dictionary = {}
## B's key -> the pieces of it A lacks: to build B from A, buy these.
var only_b: Dictionary = {}
## B's key -> [[A's key, pieces]]: counted in both as another moulding.
var moulds: Dictionary = {}


## [param from] against [param to]: what they share, and what [param to]
## needs beyond [param from].
static func between(from: Side, to: Side) -> PartsCompare:
	var out := PartsCompare.new()
	out.a = from
	out.b = to
	var shared: Dictionary = Collection.allocate(to.counts, from.counts)
	for key: String in to.counts:
		var had: int = int(shared["have"].get(key, 0))
		if had > 0:
			out.both[key] = had
		if int(to.counts[key]) > had:
			out.only_b[key] = int(to.counts[key]) - had
	for key: String in shared["spare"]:
		if int(shared["spare"][key]) > 0:
			out.only_a[key] = int(shared["spare"][key])
	out.moulds = shared["moulds"]
	return out


static func total(counts: Dictionary) -> int:
	var sum: int = 0
	for key: String in counts:
		sum += int(counts[key])
	return sum


## Whether every piece of each side is counted once: in both, or in it alone.
func adds_up() -> bool:
	return total(both) + total(only_a) == a.pieces and total(both) + total(only_b) == b.pieces


## The list to buy to build B from A, as a parts list the shops' writers take.
func to_buy(library: PartLibrary) -> Inventory:
	return Inventory.of_counts(only_b, library)


## "120 pieces in both; 165 only in 7140-1; 451 only in 9493-1".
func summary() -> String:
	return "%s in both; %d only in %s; %d only in %s" % [Counted.of(total(both), "piece"),
		total(only_a), a.short, total(only_b), b.short]


## The file a to-buy list is written as: "car_from_7140_1".
func file_name() -> String:
	return ("%s from %s" % [b.short, a.short]).replace("-", " ").to_snake_case()


## What it says to a session (parts_list which="compare"): the sides, the
## counts, then each list by part and colour, at most [param most] lots a list.
func said(library: PartLibrary, most: int = 30) -> String:
	var lines := PackedStringArray()
	lines.append("%s against %s, by part and colour:" % [side_words(a), side_words(b)])
	var lists: Array = [["In both", both], ["Only in " + a.short, only_a],
		["Only in %s: to build it from %s, buy these" % [b.short, a.short], only_b]]
	for list: Array in lists:
		var counts: Dictionary = list[1]
		lines.append("  %s: %s in %s." % [list[0], Counted.of(total(counts), "piece"),
			Counted.of(counts.size(), "lot")])
	if only_b.is_empty():
		lines.append("%s has every piece %s needs: nothing to buy." % [a.short, b.short])
	for n: int in lists.size():
		var stock: Inventory = Inventory.of_counts(lists[n][1], library)
		if stock.lots.is_empty():
			continue
		lines.append("%s:" % lists[n][0])
		for lot: Inventory.Lot in stock.lots.slice(0, most):
			lines.append("  %3d x %s %s, %s%s%s" % [lot.count, lot.part_id, lot.name, lot.color_name,
				" (element %s)" % lot.element if not lot.element.is_empty() else "",
				mould_words(Collection.key_of(lot.part_id, lot.color_code)) if n == 0 else ""])
		if stock.lots.size() > most:
			lines.append("  and %d more lots: limit= for more." % (stock.lots.size() - most))
	return "\n".join(lines)


## A side as a sentence names it: "7140-1 X-wing Fighter (1999, 285 pieces;
## 1 spare not counted)".
static func side_words(side: Side) -> String:
	var not_counted: String = ""
	if side.not_counted > 0:
		not_counted = "; %d %s not counted" % [side.not_counted,
			("spare" if side.not_counted == 1 else "spares") if side.kind == SET
			else "stickers and made parts"]
	var named: String = side.name
	if named.ends_with(")"):
		return "%s, %s%s)" % [named.trim_suffix(")"), Counted.of(side.pieces, "piece"), not_counted]
	return "%s (%s%s)" % [named, Counted.of(side.pieces, "piece"), not_counted]


## " (as 3794a in A)" for a piece of B counted in both as another moulding.
func mould_words(key: String) -> String:
	var other: Array = moulds.get(key, [])
	if other.is_empty():
		return ""
	var said := PackedStringArray()
	for pair: Array in other:
		said.append("%d as %s" % [int(pair[1]), Collection.part_of(str(pair[0]))])
	return " (%s in %s)" % [", ".join(said), a.short]


# -- the sides ---------------------------------------------------------------------


## The model open now, as What do I need? counts it (Collection.needs_of).
static func of_open(world: BrickWorld, library: PartLibrary, scenery: Dictionary,
		title: String) -> Side:
	var side := Side.new()
	side.kind = OPEN
	side.name = title if not title.is_empty() and title != ModelStore.UNTITLED \
		else "the model open now"
	side.short = side.name
	var stock: Inventory = Inventory.of(world, library, scenery)
	side.counts = Collection.needs_of(stock, library)
	side._sum()
	side.not_counted = stock.pieces - side.pieces
	if side.pieces == 0:
		side.trouble = "nothing is built yet"
	return side


## A saved model or an example, by its file, as What can I build? reads it
## (Collection.needs_of_ldraw).
static func of_file(path: String, named: String, library: PartLibrary) -> Side:
	var side := Side.new()
	side.kind = MODEL
	side.name = named
	side.short = named
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		side.trouble = "%s could not be read" % named
		return side
	side.counts = Collection.needs_of_ldraw(text, library)
	side._sum()
	if side.pieces == 0:
		side.trouble = "%s has no parts anybody can own" % named
	return side


## A set, by its number ("7140", "7140-1"), from its inventory: every part
## in it but its spares. None of a set under test (DesignMemory.holds): its
## parts list is a bench session's answer.
static func of_set(number: String, inventories: SetInventories, library: PartLibrary) -> Side:
	var side := Side.new()
	side.kind = SET
	var normal: String = SetInventories.normal(number)
	side.name = normal
	side.short = normal
	if normal.is_empty():
		side.trouble = "no set number was given"
		return side
	if DesignMemory.holds(normal):
		side.trouble = "set %s is under test in this run, so its parts are not compared" % normal
		return side
	if inventories == null:
		side.trouble = "this app has no set inventories"
		return side
	var found: Dictionary = await inventories.lookup(PackedStringArray([normal]))
	var record: Variant = found.get(normal)
	if typeof(record) != TYPE_DICTIONARY:
		side.trouble = inventories.trouble if not inventories.trouble.is_empty() \
			else "no set %s is in the set inventories" % normal
		return side
	var title: String = str((record as Dictionary).get("n", ""))
	if DesignMemory.holds(normal, title):
		side.trouble = "set %s is under test in this run, so its parts are not compared" % normal
		return side
	var year: int = int((record as Dictionary).get("y", 0))
	side.name = "%s %s%s" % [normal, title, " (%d)" % year if year > 0 else ""]
	for row: Variant in (record as Dictionary).get("p", []):
		var lot: Array = row
		var key: String = Collection.key_of(str(lot[0]), int(lot[1]), library)
		side.counts[key] = int(side.counts.get(key, 0)) + int(lot[2])
	for row: Variant in (record as Dictionary).get("s", []):
		side.not_counted += int((row as Array)[2])
	side._sum()
	return side


## A side by what a session calls it: "open" (or "") for the model open now,
## a set number ("7140", "7140-1", "set 7140"), or a saved model's or an
## example's name ("model Car" when the name is a number).
static func side_for(said: String, store: ModelStore, world: BrickWorld, library: PartLibrary,
		inventories: SetInventories) -> Side:
	var words: String = said.strip_edges()
	var lower: String = words.to_lower()
	if lower in ["", "open", "the open model", "this model", "the model open now"]:
		return of_open(world, library, store.scenery, store.title)
	if lower.begins_with("set ") or lower.begins_with("set:"):
		return await of_set(words.substr(4).strip_edges(), inventories, library)
	var as_model: bool = lower.begins_with("model ") or lower.begins_with("model:")
	var name: String = words.substr(6).strip_edges() if as_model else words
	if not as_model and _set_number.search(lower) != null:
		return await of_set(words, inventories, library)
	for entry: ModelStore.Entry in store.list_saved() + store.list_examples():
		if entry.name.to_lower() == name.to_lower():
			return of_file(entry.path, entry.name, library)
	var side := Side.new()
	side.kind = MODEL
	side.name = name
	side.short = name
	side.trouble = ("no saved model or example is called \"%s\": open_model lists them; a set "
		+ "is its number, as 7140") % name
	return side


## A set's number as people type it: 7140, 7140-1, 10497-1, 41999b-1.
static var _set_number: RegEx = RegEx.create_from_string("^\\d{3,7}[a-z]?(-\\d+)?$")
