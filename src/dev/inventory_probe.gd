## Check the parts list against models whose contents are known.
##
##   godot --headless --path . --script src/dev/inventory_probe.gd
##
## A parts list is the one output somebody spends money against. Getting
## a count wrong means a build that stops three bricks short, so the
## arithmetic is checked rather than eyeballed — including the two things
## a naive count gets wrong: that the same part in two colours is two
## lots, and that the baseplate is not part of the build.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)

	# Nine bricks: six red 2x4, two blue 2x4, one red 1x1. Three lots.
	world.clear()
	for i: int in 6:
		world.add_brick("3001", 4, Transform3D(Basis.IDENTITY, Vector3(0, i * 24.0, 0)))
	for i: int in 2:
		world.add_brick("3001", 1, Transform3D(Basis.IDENTITY, Vector3(100, i * 24.0, 0)))
	world.add_brick("3005", 4, Transform3D(Basis.IDENTITY, Vector3(200, 0, 0)))

	var stock: Inventory = Inventory.of(world, library)
	_check("nine pieces, got %d" % stock.pieces, stock.pieces == 9)
	_check("three lots, got %d" % stock.lot_count(), stock.lot_count() == 3)
	_check("the biggest lot is first (%d)" % stock.lots[0].count,
		stock.lots[0].count == 6)
	_check("the same part in two colours is two lots",
		stock.lots[0].part_id == stock.lots[1].part_id
		and stock.lots[0].color_code != stock.lots[1].color_code)

	# A part's colours must be adjacent. Scattering them down the page
	# means reading the whole list to find how many of a part are needed.
	var seen: Dictionary = {}
	var broken := ""
	var previous := ""
	for lot: Inventory.Lot in stock.lots:
		if lot.part_id != previous:
			if seen.has(lot.part_id):
				broken = lot.part_id
			seen[lot.part_id] = true
			previous = lot.part_id
	_check("each part's colours sit together%s"
		% ("" if broken.is_empty() else " — %s is split" % broken),
		broken.is_empty())
	_check("names are tidied, got '%s'" % stock.lots[0].name,
		not stock.lots[0].name.contains("  "))
	_check("weight is reported, got '%s'" % stock.weight(), stock.grams > 0.0)

	# The baseplate is scenery, not a part of the build.
	var plate_id: int = world.add_brick("3811", 2, Transform3D.IDENTITY)
	var with_plate: Inventory = Inventory.of(world, library)
	var without: Inventory = Inventory.of(world, library, {plate_id: true})
	_check("counting the baseplate gives %d" % with_plate.pieces,
		with_plate.pieces == 10)
	_check("skipping it gives %d again" % without.pieces, without.pieces == 9)

	# The CSV has to survive a part name with a comma in it, which the
	# library has plenty of.
	var csv: String = stock.to_csv()
	var rows: PackedStringArray = csv.strip_edges().split("\n")
	_check("csv has a header and one row per lot, got %d" % rows.size(),
		rows.size() == stock.lot_count() + 1)
	_check("csv header names its columns", rows[0].begins_with("part,name,"))

	world.clear()
	for id: String in ["3626bp01", "2431", "3070b"]:
		world.add_brick(id, 4, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)))
	var quoted: String = Inventory.of(world, library).to_csv()
	var balanced: bool = quoted.count("\"") % 2 == 0
	_check("quotes in the csv are balanced", balanced)
	for line: String in quoted.strip_edges().split("\n"):
		# Seven columns, unless a quoted field is hiding a comma — in
		# which case the naive split finds more, which is the bug.
		if not line.contains("\""):
			_check("a plain row has seven fields, got %d in '%s'"
				% [line.split(",").size(), line.substr(0, 40)],
				line.split(",").size() == 7)

	print("")
	print("%d failed" % _failures if _failures else "the parts list adds up")
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
