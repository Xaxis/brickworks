## Does search_parts find the shaping part a builder means, in a builder's words?
##
##   godot --headless --path . --script src/dev/shaping_search_probe.gd
##
## After `--`, `--parts-only=FILE` keeps the search to a list, as BrickBench's
## designs are kept to BrickNet's parts (src/parts/parts_only.gd).
##
## BrickBench on m147 lost 22 of 24 verdicts to BrickAgent, whose bodies are
## large curved parts where ours are boxes (docs/BRICKBENCH.md, 2026-10-22).
## Four of six sessions searched for the shaping part and were told it did
## not exist: "tile 2x2 macaroni curved" said No parts match, where
## "tile 2 x 2 corner round" finds 27925. Every word had to be in a part's
## name or keywords, so one word the catalogue does not use hid the part, and
## keywords matched inside other words ("4" in "LegoID 6410654").
##
## Each row is what a builder types, taken from the design sessions'
## transcripts or from how sets describe the shape, and the parts any one of
## which an expert would want among the first five search_parts lists.
extends SceneTree

## The searches of the m147 round that came back empty, or with a print or a
## sticker, and the part BrickAgent's build used. Every one must pass.
const BENCH155: Array = [
	["dome bottom 2 x 2 round inverted", ["24947"]],
	["tile 2x2 macaroni curved", ["27925"]],
	["tile 2x2 round corner quarter", ["27925"]],
	["tile round corner 4 x 4 macaroni", ["27507"]],
	["slope curved 1 x 3 or 1 x 4 double ear", ["93273"]],
	["brick 1x4 with 4 studs on one side", ["30414"]],
	["spiky hair", ["22388"]],
]

## Builders' words for the shapes sets are made of: from earlier sessions'
## searches (search_parts as Claude called it), and from the names set
## inventories give the parts (macaroni, quarter, half circle, pyramid).
const BUILDERS: Array = [
	["macaroni tile 2x2", ["27925"]],
	["tile 2 x 2 curved macaroni", ["27925"]],
	["rounded corner tile 3x3", ["79393"]],
	["round corner plate macaroni large", ["30565", "6003"]],
	["plate round corner quarter circle", ["79491", "30565", "6003"]],
	["plate round corner 6 x 6", ["6003"]],
	["rounded plate 2 x 2 corner", ["79491"]],
	["brick round corner 2 x 2 macaroni", ["85080", "3063b"]],
	["quarter round brick 2x2", ["85080", "3063b", "5852"]],
	["macaroni brick 4x4", ["48092", "2577"]],
	["corner round brick 4 x 4", ["2577", "48092"]],
	["tile round 1 x 1 quarter", ["25269"]],
	["tile 1 x 1 half circle", ["24246"]],
	["tile 1 x 2 rounded ends", ["1126", "35480"]],
	["plate 1 x 2 rounded ends", ["35480"]],
	["quarter dome", ["1871", "87375"]],
	["round 2x2 dome bottom", ["15395", "24947"]],
	["inverted dome 2x2", ["15395", "24947"]],
	["ovoid", ["24947"]],
	["brick round 2 x 2 x 1 1/3 inverted", ["24947"]],
	["brick round 2 x 2 dome top", ["3262", "30367c", "30367b"]],
	["round bowl 4 x 4", ["3960", "87081", "2577", "35394"]],
	["round brick 4 x 4", ["87081"]],
	["cylinder half", ["68013", "24593", "85941"]],
	["slope curved 2 x 1 inverted", ["24201"]],
	["curved slope inverted 4 x 1", ["13547"]],
	["brick curved 2 x 1 no studs", ["11477"]],
	["curved slope 1 x 4 double", ["93273"]],
	["slope curved 3 x 1", ["50950"]],
	["curved slope 2 x 2", ["15068"]],
	["pyramid slope 1x1", ["22388"]],
	["slope 1 x 1 quadruple convex", ["22388"]],
	["brick 1x2 with studs on one side", ["11211"]],
	["2x2 bracket inverted 99207", ["99207"]],
	["wedge plate 4 x 2", ["51739", "41769", "41770"]],
]

## Searches of the m147 sessions that found their part, and what they found
## first: they must still find it first.
const SAME_FIRST: Array = [
	["dish 2 x 2 inverted", "4740"], ["30367", "30367c"],
	["plate round corner 2 x 2", "79491"], ["plate round 4 x 4", "30565"],
	["brick round corner 4 x 4", "48092"], ["brick 1 x 4 studs on side", "30414"],
	["turntable 2 x 2 plate", "3679"], ["plate 1x1 tooth", "49668"],
	["tile 1x2 grille", "2412b"], ["47456", "47456"], ["87087", "87087"],
	# Or the same eye on the round tile sets use now, 14769, in 100 sets where
	# the old mould's print is in none known (search242 ranks by use).
	["tile round 2x2 eye print", "4150p0a", "14769p01"],
]

const WITHIN := 5

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var assistant := Assistant.new()
	assistant.library = library
	get_root().add_child(assistant)
	print("  parts only: %s" % (PartsOnly.named() if PartsOnly.active() else "no, the whole library"))
	# The first search makes the word index.
	var indexing: int = Time.get_ticks_usec()
	library.search("brick", 1)
	print("  the word index made in %d ms" % ((Time.get_ticks_usec() - indexing) / 1000))

	print("  the m147 round's failed searches")
	var bench_hits: int = _score(assistant, BENCH155, true)
	print("")
	print("  builders' words")
	var hits: int = _score(assistant, BUILDERS, false)
	var all_rows: int = BENCH155.size() + BUILDERS.size()
	var all_hits: int = bench_hits + hits
	print("  %d of %d in the first %d (%d%%); the m147 round's %d of %d" % [all_hits, all_rows,
		WITHIN, roundi(100.0 * all_hits / all_rows), bench_hits, BENCH155.size()])
	if all_hits * 10 < all_rows * 9:
		_fail("under 90% of the builders' searches find their part")

	# On the round's own list, first as it was; in the whole library, where
	# more parts answer, among the first five.
	print("")
	print("  searches that found their part still find it %s" % ("first"
		if PartsOnly.active() else "in the first %d" % WITHIN))
	for row: Array in SAME_FIRST:
		var ids: PackedStringArray = _listed(assistant._search(row[0], WITHIN))
		var first: String = ids[0] if not ids.is_empty() else "nothing"
		var meant: String = row[1]
		for one: Variant in row.slice(2):
			if ids.has(str(one)) and not ids.has(meant):
				meant = str(one)
		if first != meant and (PartsOnly.active() or not ids.has(meant)):
			_fail("%s -> %s, where it found %s first" % [row[0], ", ".join(ids), row[1]])
		else:
			print("  ok    %-36s %s at %d" % [row[0], meant, ids.find(meant) + 1])

	# As fast as it was: one design makes dozens of searches.
	var started: int = Time.get_ticks_usec()
	for _round: int in 3:
		for row: Array in BENCH155 + BUILDERS:
			assistant._search(row[0], 8)
	var batch_ms: float = (Time.get_ticks_usec() - started) / 3000.0
	print("")
	print("  a batch of %d searches: %d ms, %.1f ms a search" % [all_rows, roundi(batch_ms),
		batch_ms / all_rows])

	assistant.queue_free()
	print("")
	if _failures == 0:
		print("search_parts finds the shaping part a builder means")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## How many rows find one of their parts among the first WITHIN, each said.
func _score(assistant: Assistant, rows: Array, every_one: bool) -> int:
	var hits: int = 0
	for row: Array in rows:
		var ids: PackedStringArray = _listed(assistant._search(row[0], WITHIN))
		var at: int = -1
		for wanted: String in row[1]:
			if ids.has(wanted):
				at = ids.find(wanted) if at < 0 else mini(at, ids.find(wanted))
		if at >= 0:
			hits += 1
			print("  ok    %-40s %s at %d" % [row[0], ids[at], at + 1])
		elif every_one:
			_fail("%s -> %s, wanted one of %s" % [row[0], ", ".join(ids), str(row[1])])
		else:
			print("  miss  %-40s %s, wanted one of %s" % [row[0], ", ".join(ids), str(row[1])])
	return hits


## The part numbers a search_parts answer lists, in order.
static func _listed(said: String) -> PackedStringArray:
	var ids := PackedStringArray()
	for line: String in said.split("\n"):
		var cut: int = line.find(":")
		if cut > 0 and cut < 14 and not line.substr(0, cut).contains(" "):
			ids.append(line.substr(0, cut))
	return ids


func _fail(message: String) -> void:
	_failures += 1
	print("  FAIL  " + message)
