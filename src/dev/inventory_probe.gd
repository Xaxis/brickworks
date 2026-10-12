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
	_check("csv header names its columns",
		rows[0].begins_with("part,element,name,"))

	world.clear()
	for id: String in ["3626bp01", "2431", "3070b"]:
		world.add_brick(id, 4, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)))
	var quoted: String = Inventory.of(world, library).to_csv()
	var balanced: bool = quoted.count("\"") % 2 == 0
	_check("quotes in the csv are balanced", balanced)
	for line: String in quoted.strip_edges().split("\n"):
		# Ten columns, unless a quoted field is hiding a comma — in
		# which case the naive split finds more, which is the bug.
		if not line.contains("\""):
			_check("a plain row has ten fields, got %d in '%s'"
				% [line.split(",").size(), line.substr(0, 40)],
				line.split(",").size() == 10)

	# What makes the list orderable rather than descriptive. A 2x4 brick
	# in red is LEGO element 300121, and without that a parts list is
	# something to search a shop for rather than something to buy.
	world.clear()
	world.add_brick("3001", 4, Transform3D.IDENTITY)
	world.add_brick("3024", 0, Transform3D(Basis.IDENTITY, Vector3(100, 0, 0)))
	# A part nothing has an element number for, which must stay blank
	# rather than read as "no such element".
	world.add_brick("3001", 9, Transform3D(Basis.IDENTITY, Vector3(200, 0, 0)))
	var ordered: Inventory = Inventory.of(world, library)
	var found: Dictionary = {}
	for lot: Inventory.Lot in ordered.lots:
		found["%s/%d" % [lot.part_id, lot.color_code]] = lot.element
	print("     3001 in red  -> '%s'" % found.get("3001/4", ""))
	print("     3024 in black-> '%s'" % found.get("3024/0", ""))
	print("     3001 in light blue -> '%s'" % found.get("3001/9", ""))
	_check("a 2x4 brick in red names element 300121",
		str(found.get("3001/4", "")) == "300121")
	_check("a 1x1 plate in black names element 302426",
		str(found.get("3024/0", "")) == "302426")
	_check("a colour with no element number stays blank, not zero",
		str(found.get("3001/9", "x")) == "")
	# And the booklet's parts list at the end prints it under each part,
	# as a set's does.
	var document := Booklet.Document.new()
	document.title = "t"
	for lot: Inventory.Lot in ordered.lots:
		var listed := Booklet.Lot.new()
		listed.key = "%s:%d" % [lot.part_id, lot.color_code]
		listed.part_id = lot.part_id
		listed.element = lot.element
		listed.colour = lot.color_name
		listed.count = lot.count
		document.lots.append(listed)
		document.parts[listed.key] = "data:,"
	document.pages.append_array(Booklet.parts_pages(document.lots, 2))
	var printed: String = Booklet.html(document)
	_check("and the booklet's parts list prints the element numbers",
		printed.contains(">300121<") and printed.contains(">302426<"))

	# LEGO's name for a colour, which is not LDraw's: the grey modern sets
	# are built in is Light Bluish Grey to LDraw and BrickLink and Medium
	# Stone Grey to LEGO. And Rebrickable's number, which its import reads.
	# A tyre in Rubber Black is a Black tyre to both, and a colour nothing
	# knows stays blank rather than borrowing a neighbour's.
	world.clear()
	world.add_brick("3001", 71, Transform3D.IDENTITY)
	world.add_brick("3001", 85, Transform3D(Basis.IDENTITY, Vector3(100, 0, 0)))
	world.add_brick("3641", 256, Transform3D(Basis.IDENTITY, Vector3(200, 0, 0)))
	world.add_brick("3001", 87, Transform3D(Basis.IDENTITY, Vector3(300, 0, 0)))
	var named: Dictionary = {}
	for lot: Inventory.Lot in Inventory.of(world, library).lots:
		named[lot.color_code] = lot
	var grey: Inventory.Lot = named.get(71)
	var lilac: Inventory.Lot = named.get(85)
	var tyre: Inventory.Lot = named.get(256)
	var paint: Inventory.Lot = named.get(87)
	_check("71 is LEGO's Medium Stone Grey, Rebrickable 71",
		grey != null and grey.lego_colour == "Medium Stone Grey"
			and grey.rebrickable_colour == 71)
	_check("85 is LEGO's Medium Lilac, Rebrickable 85 (Dark Purple)",
		lilac != null and lilac.lego_colour == "Medium Lilac"
			and lilac.rebrickable_colour == 85)
	_check("a tyre in Rubber Black is Rebrickable's Black, got %s"
		% ("none" if tyre == null else str(tyre.rebrickable_colour)),
		tyre != null and tyre.rebrickable_colour == 0
			and tyre.lego_colour == "Black")
	_check("a paint colour no Rebrickable colour is stays blank",
		paint != null and paint.rebrickable_colour == -1
			and Inventory.of(world, library).to_csv().contains(
				",Titanium,\n"))

	_flexible(library, world)

	print("")
	print("%d failed" % _failures if _failures else "the parts list adds up")
	quit(1 if _failures else 0)


## A hose laid along a bend is LDraw's segments, an end, rings and an end,
## and one hose in a shop. Somebody buying from the list has to be asked
## for the hose of the length it was laid as, under the number the shop
## lists it by, and not for thirty rings nobody sells. A chain is its links,
## which are what is sold.
func _flexible(library: PartLibrary, world: BrickWorld) -> void:
	print("\n  flexible parts, counted as they are sold")
	world.clear()
	var laid: Dictionary = {}
	laid["hose"] = _lay(world, "ribbed_hose", 180.0, "Ribbed Hose 9L#1", 0, Vector3.ZERO)
	laid["hose2"] = _lay(world, "ribbed_hose", 180.0, "Ribbed Hose 9L 2#1", 0,
		Vector3(0, 0, 200))
	laid["tube"] = _lay(world, "pneumatic_tube", 180.0, "Pneumatic Tube 9L#1", 1,
		Vector3(200, 0, 0))
	var axle: Array = Flex.lengths_of(library, "flex_axle")
	laid["axle"] = _lay(world, "flex_axle", float(axle[0]["length"]) if not axle.is_empty()
		else 515.0, "Axle Flexible 26#1", 0, Vector3(400, 0, 0))
	laid["string"] = _lay(world, "string", 816.0, "String Braided 41L#1", 0,
		Vector3(600, 0, 0))
	var sprockets: Array = []
	for x: float in [0.0, 140.0]:
		var gear: int = world.add_brick("3648b", 71, Transform3D(Basis.IDENTITY,
			Vector3(x, 60, -300)))
		sprockets.append(Flex.sprocket_of(world.get_brick(gear), library))
	var chain: Flex.Laid = Flex.lay_chain("chain", sprockets)
	for piece: Dictionary in chain.pieces:
		_in_item(world.get_brick(world.add_brick(str(piece["part"]), 0, piece["at"])),
			"Technic chain#1")
	# A ring on its own, in no item: nothing says which hose it is of, so
	# it is what it is.
	world.add_brick("71944k02", 0, Transform3D(Basis.IDENTITY, Vector3(0, 100, 0)))
	print("     laid %s, a chain of %d links" % [str(laid), chain.links])

	var stock: Inventory = Inventory.of(world, library)
	var lots: Dictionary = {}
	for lot: Inventory.Lot in stock.lots:
		lots["%s/%d" % [lot.part_id, lot.color_code]] = lot
	var counts: Dictionary = {}
	for key: String in lots:
		counts[key] = (lots[key] as Inventory.Lot).count
	print("     %d bricks in the world; the list: %s" % [world.brick_count(), str(counts)])
	_check("two 9L ribbed hoses laid along bends are two of 71917, Technic Ribbed Hose 9L",
		counts.get("71917/0", 0) == 2
			and (lots["71917/0"] as Inventory.Lot).name == "Technic Ribbed Hose 9L")
	_check("a 9L pneumatic tube is one 21826-f1, Technic Pneumatic Tube 9L",
		counts.get("21826-f1/1", 0) == 1
			and (lots["21826-f1/1"] as Inventory.Lot).name == "Technic Pneumatic Tube 9L")
	_check("a 26L flexible axle is one 72892", counts.get("72892/0", 0) == 1)
	_check("a 41L string with end studs is one 71149", counts.get("71149/0", 0) == 1)
	_check("a chain is its %d links of 3711, which are what is sold" % chain.links,
		chain.links > 10 and counts.get("3711/0", 0) == chain.links)
	_check("the ring in no item is itself, and no other segment is listed",
		counts.get("71944k02/0", 0) == 1 and not counts.has("71944k01/0")
			and not counts.has("71533k03/1") and not counts.has("71533k02/1")
			and not counts.has("u9012/0") and not counts.has("u9010/0")
			and not counts.has("71149k02/0"))
	var expected: int = 2 + 1 + 1 + 1 + chain.links + 2 + 1
	_check("%d pieces in the list for %d bricks in the world (%d)"
		% [expected, world.brick_count(), stock.pieces],
		stock.pieces == expected and world.brick_count() > expected + 100)
	_check("the counts line counts as the list does (%d)" % Inventory.pieces_in(world, library),
		Inventory.pieces_in(world, library) == stock.pieces)
	# A booklet step lists the hose once, with its first piece.
	var standing: int = 0
	var rest: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if stock.whole_of.get(brick.id, "") == "Ribbed Hose 9L#1":
			if stock.key_of(brick) == "71917:0":
				standing += 1
			elif stock.key_of(brick).is_empty():
				rest += 1
	_check("one piece of a hose stands for it in a step, its %d others for nothing" % rest,
		standing == 1 and rest == int(laid["hose"]) - 1)

	# The shops' own numbers, which LDraw records and which are not LDraw's.
	var wanted: Dictionary = {}
	for block: String in str(ShopLists.bricklink_xml(stock, library)["text"]).split("<ITEM>"):
		if block.contains("<ITEMID>"):
			wanted[block.get_slice("<ITEMID>", 1).get_slice("</ITEMID>", 0)] = \
				int(block.get_slice("<MINQTY>", 1).get_slice("</MINQTY>", 0))
	print("     BrickLink: %s" % str(wanted))
	_check("the wanted list asks BrickLink for 2 of 78c09, its ribbed hose 9L",
		wanted.get("78c09", 0) == 2 and not wanted.has("71917"))
	_check("1 of 21826, its pneumatic tube 9L", wanted.get("21826", 0) == 1)
	_check("1 of x334c01, its flexible axle 26", wanted.get("x334c01", 0) == 1)
	_check("1 of x127c40pb01, its 41L string", wanted.get("x127c40pb01", 0) == 1)
	_check("%d of 3711, the chain link" % chain.links, wanted.get("3711", 0) == chain.links)
	_check("and no segment", not wanted.has("71944k01") and not wanted.has("71533k03")
		and not wanted.has("u9012") and not wanted.has("71149k02"))
	var rebrickable: String = str(ShopLists.rebrickable_csv(stock)["text"])
	print("     Rebrickable: %s" % rebrickable.strip_edges().replace("\n", " | "))
	_check("Rebrickable's list names its own numbers: 78c09, 5102c09.375, 14226c41, 3711a",
		rebrickable.contains("\n78c09,0,2\n") and rebrickable.contains("\n5102c09.375,1,1\n")
			and rebrickable.contains("\n14226c41,0,1\n")
			and rebrickable.contains("\n3711a,0,%d\n" % chain.links))
	_check("and LDraw's where LDraw records none: 72892",
		rebrickable.contains("\n72892,0,1\n"))
	_check("a part LDraw records no shop number for keeps its own (3001)",
		library.shop_part("3001", "BrickLink") == "3001"
			and library.shop_part("3001", "Rebrickable") == "3001")
	_check("a formed tube LDraw gives no BrickLink number is listed without its -f1 (%s)"
		% library.shop_part("37461-f1", "BrickLink"),
		library.shop_part("37461-f1", "BrickLink") == "37461")

	# Saved and opened again, the hoses are the same hoses; and the count a
	# shared link shows, which the server makes from the file itself
	# (api/share.js), is the list's.
	var placements: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		var placement := LdrModel.Placement.new(brick.part_id, brick.color_code,
			brick.transform, 0)
		placement.group = brick.group
		placements.append(placement)
	var text: String = LdrModel.write_ldr(placements, "Flex probe")
	world.clear()
	for placement: LdrModel.Placement in LdrModel.parse(text, "flex probe").flatten(library.parts):
		var brick_id: int = world.add_brick(placement.part_id, placement.color_code,
			placement.transform)
		world.get_brick(brick_id).group = placement.group
		world.get_brick(brick_id).unit = placement.unit
	var reopened: Inventory = Inventory.of(world, library)
	_check("written to a file and read back, the list is the same (%d pieces, %d lots)"
		% [reopened.pieces, reopened.lot_count()],
		reopened.pieces == stock.pieces and reopened.lot_count() == stock.lot_count())
	var file_path: String = ProjectSettings.globalize_path("user://inventory_probe_flex.mpd")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var output: Array = []
	var code: int = OS.execute("node", ["--input-type=module", "-e",
		"import {checkModel} from '%s'; import {readFileSync} from 'node:fs';" \
			% ProjectSettings.globalize_path("res://api/share.js")
		+ " console.log(checkModel(readFileSync(process.argv[1], 'utf8')).parts)",
		file_path], output, true)
	var shared: String = "".join(output).strip_edges()
	_check("the share page counts it as the list does (%s, node exited %d)" % [shared, code],
		code == 0 and shared == str(stock.pieces))
	DirAccess.remove_absolute(file_path)

	# A sub-model with a brick among the rings is no hose, whatever its
	# rings are: they are what is there.
	world.clear()
	var rings: int = _lay(world, "ribbed_hose", 180.0, "Mixed#1", 0, Vector3.ZERO)
	var brick: BrickWorld.Brick = world.get_brick(world.add_brick("3001", 4, Transform3D.IDENTITY))
	brick.group = "Mixed"
	var mixed: Inventory = Inventory.of(world, library)
	_check("a hose's pieces with a brick among them are %d pieces, not a hose (%d)"
		% [rings + 1, mixed.pieces],
		mixed.pieces == rings + 1 and mixed.items.is_empty()
			and Inventory.pieces_in(world, library) == rings + 1)


## Lay [param kind] from [param from], as the flex tool does, and put its
## pieces in the world as item [param path]. How many pieces it is.
func _lay(world: BrickWorld, kind: String, real: float, path: String, colour: int,
		from: Vector3) -> int:
	var rigid: Array = Flex.KINDS[kind].get("rigid", [2.0, 2.0])
	var out: Vector3 = Vector3.UP if kind == "string" else Vector3.BACK
	var a: Flex.Port = Flex.free_port(from, out, float(rigid[0]))
	var b: Flex.Port = Flex.free_port(from + Vector3(80, 0, 0), out, float(rigid[1]))
	var laid: Flex.Laid = Flex.lay_swept(kind, a, b, real)
	for piece: Dictionary in laid.pieces:
		_in_item(world.get_brick(world.add_brick(str(piece["part"]), colour, piece["at"])), path)
	return laid.pieces.size()


## As Builder.set_path puts a brick in an assembly.
func _in_item(brick: BrickWorld.Brick, path: String) -> void:
	brick.unit = path
	brick.group = Assemblies.group_of(path)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
