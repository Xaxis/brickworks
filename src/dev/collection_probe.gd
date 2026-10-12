## My collection: the sums, checked with numbers chosen to have one answer.
##
##   godot --headless --path . --script src/dev/collection_probe.gd
##
## A shortfall is a shopping list, so its arithmetic is checked rather than
## eyeballed: which sets expand to what (against tools/collection_data.py,
## whose own test checks it against Rebrickable's raw tables), what a model
## needs, what is short, what could stand in without a spare piece being
## promised twice, how much of a model is owned, the wanted list that
## leaves, and the copy kept on this device. Then the assistant's side: a
## brief that asks for the person's collection is told what they own, and
## its part search puts what they own first.
##
## Writes nothing in the app's own directory: the copy on this device goes
## to a file of the probe's own in the system's temporary directory, and is
## removed.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("FAIL no catalogue")
		quit(1)
		return
	await _expansion(library)
	_keys(library)
	_shortfall(library)
	_combinations(library)
	_wanted_list(library)
	await _example_car(library)
	await _official_models(library)
	await _local_copy(library)
	await _rebrickable()
	_assistant(library)
	if _failures == 0:
		print("collection probe: every sum came out as it should")
	else:
		print("collection probe: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(good: bool, what: String) -> void:
	print(("  ok   " if good else "  FAIL ") + what)
	if not good:
		_failures += 1


func _expansion(library: PartLibrary) -> void:
	print("\nsets into parts")
	# The same sum as tools/collection_data.py shard_of, worked there.
	_ok(SetInventories.shard_of("10237-1") == 244 and SetInventories.shard_of("6020-1") == 183
		and SetInventories.shard_of("75192-1") == 184,
		"the shard rule agrees with the Python one (244, 183, 184)")
	_ok(SetInventories.normal("10237") == "10237-1" and SetInventories.normal(" 6020-1 ") == "6020-1",
		"a set typed without its version is the first one")
	var inventories := SetInventories.new()
	root.add_child(inventories)
	var found: Dictionary = await inventories.lookup(PackedStringArray(["6020-1", "10237-1", "0-0"]))
	_ok(found.has("6020-1") and found.has("10237-1") and not found.has("0-0"),
		"two real sets are found and a made-up one is not (%s)" % inventories.trouble)
	if not found.has("6020-1") or not found.has("10237-1"):
		return
	var shop: Dictionary = found["6020-1"]
	var shop_pieces: int = 0
	for row: Variant in shop["p"]:
		shop_pieces += int((row as Array)[2])
	_ok(str(shop["n"]) == "Magic Shop" and shop_pieces == 47 and (shop["p"] as Array).size() == 33,
		"6020-1 Magic Shop is 47 pieces in 33 lots (got %d in %d)" % [shop_pieces, (shop["p"] as Array).size()])
	# Two Magic Shops, one Orthanc with its spares counted, and a few loose
	# bricks, two of them a colour the shop also has.
	# The shop's first lot is owned loose as well, five more of it.
	var first: Array = (shop["p"] as Array)[0]
	var mine := Collection.new()
	mine.sets = [{"set": "6020-1", "qty": 2, "spares": false},
		{"set": "10237-1", "qty": 1, "spares": true}, {"set": "0-0", "qty": 1, "spares": false}]
	mine.parts = [{"part": str(first[0]), "colour": int(first[1]), "qty": 5}]
	var on_hand: Dictionary = mine.pool(found, library)
	var orthanc: Dictionary = found["10237-1"]
	var orthanc_pieces: int = 0
	for row: Variant in (orthanc["p"] as Array) + orthanc.get("s", []):
		orthanc_pieces += int((row as Array)[2])
	var total: int = 0
	for key: String in on_hand:
		total += int(on_hand[key])
	_ok(total == 2 * 47 + orthanc_pieces + 5,
		"the pool is two shops, Orthanc with spares and five loose bricks: %d (got %d)"
		% [2 * 47 + orthanc_pieces + 5, total])
	_ok(mine.unknown_sets == PackedStringArray(["0-0"]),
		"a set with no inventory is named, not guessed (%s)" % ", ".join(mine.unknown_sets))
	# The loose ones and the sets' own are one lot, not three.
	var key: String = Collection.key_of(str(first[0]), int(first[1]), library)
	var in_orthanc: int = 0
	for row: Variant in (orthanc["p"] as Array) + orthanc.get("s", []):
		var lot: Array = row
		if Collection.key_of(str(lot[0]), int(lot[1]), library) == key:
			in_orthanc += int(lot[2])
	_ok(int(on_hand.get(key, 0)) == 5 + 2 * int(first[2]) + in_orthanc,
		"%s: five loose, %d in each shop and %d in Orthanc make one lot of %d (got %d)"
		% [key, int(first[2]), in_orthanc, 5 + 2 * int(first[2]) + in_orthanc, int(on_hand.get(key, 0))])
	inventories.queue_free()


func _keys(library: PartLibrary) -> void:
	print("\none spelling for both sides")
	_ok(Collection.key_of("4073", 4, library) == "6141/4",
		"a retired number is compared as the part it moved to (4073 is 6141)")
	_ok(Collection.key_of("3001.DAT".trim_suffix(".DAT"), 4, library) == "3001/4",
		"case does not matter")
	var rubber: int = -1
	for code: int in library.colors:
		var colour: PartLibrary.BrickColor = library.colors[code]
		if colour.plain_code != code and colour.plain_code == 0:
			rubber = code
			break
	_ok(rubber < 0 or Collection.key_of("4084", rubber, library) == "4084/0",
		"a tyre in a rubber black is a black tyre (%d)" % rubber)


func _needs() -> Dictionary:
	return {"3001/4": 6, "3001/1": 2, "3010/4": 3, "3005/14": 1}


func _pool() -> Dictionary:
	return {"3001/4": 4, "3001/15": 5, "3004/4": 4, "3005/14": 3}


func _shortfall(_library: PartLibrary) -> void:
	print("\nwhat is short")
	var rows: Array = Collection.shortfall(_needs(), _pool())
	var short: Dictionary = {}
	for row: Dictionary in rows:
		short[row["key"]] = int(row["short"])
	_ok(short == {"3001/4": 2, "3001/1": 2, "3010/4": 3},
		"two red 2 x 4s, two blue 2 x 4s and three red 1 x 4s are short (%s)" % str(short))
	_ok(str(rows[0]["key"]) == "3010/4", "the biggest shortfall first")
	_ok(not short.has("3005/14"), "a part owned three times over is not short")
	var cover: Dictionary = Collection.coverage(_needs(), _pool())
	_ok(int(cover["pieces"]) == 12 and int(cover["owned"]) == 5 and int(cover["missing"]) == 7,
		"12 pieces, 5 owned, 7 missing (%s)" % str(cover))
	_ok(is_equal_approx(float(cover["exact"]), 5.0 / 12.0)
		and is_equal_approx(float(cover["any_colour"]), 9.0 / 12.0),
		"5/12 in its own colour, 9/12 in any colour (%.3f, %.3f)"
		% [float(cover["exact"]), float(cover["any_colour"])])
	# Another moulding stands in before anything is short: two jumpers with
	# a groove for three without, each given once.
	var jumpers: Array = Collection.shortfall({"3794a/15": 3, "3794b/15": 1},
		{"3794b/15": 3})
	_ok(jumpers.size() == 1 and str(jumpers[0]["key"]) == "3794a/15" and int(jumpers[0]["short"]) == 1
		and jumpers[0]["moulds"] == [["3794b/15", 2]],
		"3794b stands in for 3794a, after the model's own 3794b is counted (%s)" % str(jumpers))
	_ok(Collection.family_of("3626bp01") == "3626bp01" and Collection.family_of("3069b") == "3069",
		"a print is only itself; a moulding letter is not")
	var everything: Dictionary = Collection.coverage(_needs(), {"3001/4": 9, "3001/1": 9,
		"3010/4": 9, "3005/14": 9})
	_ok(is_equal_approx(float(everything["exact"]), 1.0) and int(everything["missing"]) == 0,
		"owning more than enough is all of it, not more")


func _combinations(library: PartLibrary) -> void:
	print("\nwhat could stand in")
	var rows: Array = Collection.plan(_needs(), _pool(), library)
	var by_key: Dictionary = {}
	for row: Dictionary in rows:
		by_key[row["key"]] = row
	# White 2 x 4s: five spare, four wanted across two shortfalls.
	var red: Dictionary = by_key["3001/4"]
	var blue: Dictionary = by_key["3001/1"]
	_ok(red["swaps"] == [{"colour": 15, "qty": 2}] and blue["swaps"] == [{"colour": 15, "qty": 2}],
		"both 2 x 4 shortfalls are offered white ones (%s, %s)" % [str(red["swaps"]), str(blue["swaps"])])
	_ok(int(red["left"]) == 0 and int(blue["left"]) == 0, "...and that covers both")
	# Red 1 x 4s: no other colour, but four red 1 x 2s, two to a 1 x 4.
	var long: Dictionary = by_key["3010/4"]
	_ok(long["swaps"].is_empty(), "no 1 x 4 in another colour is offered when there is none")
	_ok(long["combos"] == [{"parts": [["3004", 2]], "qty": 2}],
		"two red 1 x 2s stand in for a red 1 x 4, twice (%s)" % str(long["combos"]))
	_ok(int(long["left"]) == 1, "...leaving one still to find")
	# A spare is promised once: three shortfalls of the same part and only
	# three spare in another colour.
	var tight: Array = Collection.plan({"3003/4": 2, "3003/1": 2}, {"3003/14": 3}, library)
	var offered: int = 0
	for row: Dictionary in tight:
		for swap: Dictionary in row["swaps"]:
			offered += int(swap["qty"])
	_ok(offered == 3, "three spare pieces are offered three times, not four (%d)" % offered)
	# A 2 x 4 can also be two 1 x 4s side by side.
	var wide: Array = Collection.plan({"3001/0": 1}, {"3010/0": 2}, library)
	_ok((wide[0]["combos"] as Array).size() == 1
		and wide[0]["combos"][0]["parts"] == [["3010", 2]],
		"a 2 x 4 from two 1 x 4s (%s)" % str(wide[0]["combos"]))


func _wanted_list(library: PartLibrary) -> void:
	print("\nthe wanted list that leaves")
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	for i: int in 6:
		world.add_brick("3001", 4, Transform3D(Basis.IDENTITY, Vector3(0, i * 24.0, 0)))
	for i: int in 3:
		world.add_brick("3010", 4, Transform3D(Basis.IDENTITY, Vector3(100, i * 24.0, 0)))
	world.add_brick("3005", 14, Transform3D(Basis.IDENTITY, Vector3(200, 0, 0)))
	var stock: Inventory = Inventory.of(world, library)
	var needs: Dictionary = Collection.needs_of(stock, library)
	_ok(needs == {"3001/4": 6, "3010/4": 3, "3005/14": 1},
		"a model's needs are its parts list (%s)" % str(needs))
	var rows: Array = Collection.shortfall(needs, _pool())
	var short: Inventory = Collection.shortfall_stock(stock, rows, library)
	_ok(short.pieces == 5 and short.lots.size() == 2,
		"the shortfall is 5 pieces in 2 lots (%d in %d)" % [short.pieces, short.lots.size()])
	var xml: String = str(ShopLists.bricklink_xml(short, library)["text"])
	_ok(xml.contains("<ITEMID>3001</ITEMID>") and xml.contains("<MINQTY>2</MINQTY>")
		and xml.contains("<ITEMID>3010</ITEMID>") and xml.contains("<MINQTY>3</MINQTY>")
		and not xml.contains("3005"),
		"the BrickLink wanted list asks for 2 of 3001 and 3 of 3010, and not the owned 3005")
	var csv: String = str(ShopLists.rebrickable_csv(short)["text"])
	_ok(csv.begins_with("Part,Color,Quantity") and csv.contains("3001,4,2") and csv.contains("3010,4,3"),
		"the Rebrickable CSV says the same")
	_ok(Collection.bricklink_page("3001", 4, library).ends_with("?P=3001&idColor=5"),
		"a part's BrickLink page names BrickLink's red (%s)" % Collection.bricklink_page("3001", 4, library))
	world.queue_free()


## The example car, owned as collection_flow.mjs owns it on the live site:
## the fixture's eleven lots and the Magic Shop. Its BrickLink wanted list
## carried 21 of the 26 short lots, because the hand-made colour table had
## no number for the car's Light Grey, Dark Grey and Trans Light Blue.
func _example_car(library: PartLibrary) -> void:
	print("\nthe example car's wanted list")
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	for piece: LdrModel.Placement in LdrModel.load_file("res://models/car.ldr").flatten(library.parts):
		var id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(id) != null:
			world.add_brick(id, piece.color_code, piece.transform)
	var stock: Inventory = Inventory.of(world, library)
	var mine := Collection.new()
	# tests/fixtures/collection/rebrickable_parts.csv, less its [No Color]
	# row. Rebrickable's 0, 4 and 15 are LDraw's.
	for row: Array in [["3023", 4, 4], ["3623", 4, 2], ["3641", 0, 4], ["3004", 4, 2],
			["3005", 4, 1], ["3020", 0, 1], ["3021", 4, 1], ["3710", 0, 1], ["3788", 4, 2],
			["3001", 15, 6], ["3010", 4, 3]]:
		mine.parts.append({"part": row[0], "colour": row[1], "qty": row[2]})
	mine.sets = [{"set": "6020-1", "qty": 1, "spares": false}]
	var inventories := SetInventories.new()
	root.add_child(inventories)
	var found: Dictionary = await inventories.lookup(mine.set_numbers())
	var plan: Array = Collection.plan(Collection.needs_of(stock, library),
		mine.pool(found, library), library)
	var short: Inventory = Collection.shortfall_stock(stock, plan, library)
	_ok(stock.pieces == 61 and short.lots.size() == 26,
		"the car is 61 pieces and 26 lots are short (%d, %d)" % [stock.pieces, short.lots.size()])
	var made: Dictionary = ShopLists.bricklink_xml(short, library)
	_ok(int(made["lots"]) == short.lots.size() and int(made["left_out"]) == 0,
		"the BrickLink wanted list carries all %d short lots (%d, %d left off: %s)"
		% [short.lots.size(), int(made["lots"]), int(made["left_out"]),
			", ".join(made.get("colours_left", PackedStringArray()))])
	var whole: Dictionary = ShopLists.bricklink_xml(stock, library)
	_ok(int(whole["left_out"]) == 0,
		"and so does the whole car's, all %d lots (%d left off)"
		% [stock.lots.size(), int(whole["left_out"])])
	# Pearl Red, LDraw 176, is held back (tools/bricklink_colours.py): it is
	# left off and named, never given a guessed number.
	world.add_brick("3001", 176, Transform3D(Basis.IDENTITY, Vector3(400, 0, 0)))
	var held: Dictionary = ShopLists.bricklink_xml(Inventory.of(world, library), library)
	var said: String = ShopLists.why_left_off(held, "bricklink")
	_ok(int(held["left_out"]) == 1 and said == "BrickLink has no number for Pearl Red",
		"a colour with no BrickLink number is left off and named (%d: %s)"
		% [int(held["left_out"]), said])
	inventories.queue_free()
	world.queue_free()


func _official_models(library: PartLibrary) -> void:
	print("\nofficial models, counted as the app counts them")
	var inventories := SetInventories.new()
	root.add_child(inventories)
	var models: Array = await inventories.official_models()
	_ok(models.size() > 100, "the official set models are listed (%d)" % models.size())
	var checked: int = 0
	for model: Dictionary in models:
		if checked >= 3:
			break
		var path: String = "res://vendor/omr/files/" + str(model["file"])
		if not FileAccess.file_exists(path):
			continue
		var counted: Dictionary = Collection.needs_of_ldraw(FileAccess.get_file_as_string(path), library)
		_ok(counted == model["needs"], "%s counts the same opened as listed (%d lots)"
			% [str(model["name"]), counted.size()])
		checked += 1
	if checked == 0:
		print("  --   vendor/omr is not here to recount from")
	# Owning a set should cover most of that set's own LDraw model: the two
	# are counted from different sources (Rebrickable's inventory, the
	# model's own file) and this is where they meet.
	var compared: int = 0
	var exact: float = 0.0
	for model: Dictionary in models:
		if compared >= 20 or str(model["file"]).contains("_"):
			continue
		var found: Dictionary = await inventories.lookup(PackedStringArray([str(model["set"])]))
		if not found.has(str(model["set"])):
			continue
		var mine := Collection.new()
		mine.sets = [{"set": str(model["set"]), "qty": 1, "spares": true}]
		var cover: Dictionary = Collection.coverage(model["needs"], mine.pool(found, library))
		exact += float(cover["exact"])
		compared += 1
	# Measured 2026-10-12 at 83% over the first twenty: the rest is where
	# the model's author and Rebrickable disagree, not the join — a colour
	# read differently (Light Grey for Light Bluish Grey), a hinge drawn as
	# its two halves where Rebrickable lists the pair, a hose or a chain
	# drawn link by link, hands drawn apart from the torso they come on.
	_ok(compared > 0 and exact / compared > 0.8,
		"owning a set covers most of its own official model: %.0f%% on average over %d"
		% [100.0 * exact / maxi(1, compared), compared])
	inventories.queue_free()


func _local_copy(library: PartLibrary) -> void:
	print("\nthe copy on this device")
	var kept: String = OS.get_temp_dir().path_join("brickworks_collection_probe_%d.json" % OS.get_process_id())
	CollectionStore.where = kept
	var mine := Collection.new()
	mine.sets = [{"set": "6020-1", "qty": 1, "spares": false}]
	mine.parts = [{"part": "3001", "colour": 4, "qty": 3}]
	CollectionStore._write_local(mine.to_json())
	var store := CollectionStore.new()
	store.library = library
	root.add_child(store)
	await process_frame
	_ok(store.collection.set_numbers() == PackedStringArray(["6020-1"])
		and store.collection.loose_pieces() == 3, "the copy is read back as it was kept")
	var said: String = await store.load_collection()
	_ok(store.offline and said.contains("copy on this device"),
		"signed out, it works from the copy and says so (%s)" % said)
	_ok(store.pieces_on_hand() == 47 + 3, "...with the set expanded (%d)" % store.pieces_on_hand())
	store.queue_free()
	DirAccess.remove_absolute(kept)
	_ok(not FileAccess.file_exists(kept), "and the probe's copy is gone")


func _rebrickable() -> void:
	print("\na Rebrickable account, against a stand-in")
	# tests/fixtures/collection/fake_rebrickable.py answers in Rebrickable's
	# documented shape; the real one needs a person's own key.
	const PORT := 8798
	var server: int = OS.create_process("python3", [ProjectSettings.globalize_path(
		"res://tests/fixtures/collection/fake_rebrickable.py"), str(PORT)])
	_ok(server > 0, "the stand-in is started (%d)" % server)
	await create_timer(1.5).timeout
	var account := RebrickableAccount.new()
	account.api = "http://127.0.0.1:%d/api/v3" % PORT
	account.pace = 0.1
	root.add_child(account)
	var got: Dictionary = await account.read("good-key", "tok")
	_ok(str(got["error"]).is_empty() and got["sets"] == [["6020-1", 2, false], ["10237-1", 1, true]],
		"a user token reads both pages of sets, with how many and the spares (%s)" % str(got["sets"]))
	_ok(got["parts"] == [["3001", 4, 12], ["3023", 71, 5]],
		"...and the loose parts, in Rebrickable's numbers for the server to map (%s)" % str(got["parts"]))
	var signed: Dictionary = await account.read("good-key", "", "builder", "secret pass")
	_ok(str(signed["error"]).is_empty() and (signed["sets"] as Array).size() == 2,
		"a username and password are traded for a token once (%s)" % str(signed["error"]))
	var wrong: Dictionary = await account.read("bad-key", "tok")
	_ok(str(wrong["error"]) == "Rebrickable refused that key or token",
		"a key Rebrickable refuses is said so (%s)" % str(wrong["error"]))
	var nobody: Dictionary = await account.read("good-key", "", "builder", "guess")
	_ok(str(nobody["error"]).contains("Invalid username or password"),
		"a wrong password is Rebrickable's own words (%s)" % str(nobody["error"]))
	var keyless: Dictionary = await account.read("", "tok")
	_ok(str(keyless["error"]).contains("API key"), "no key asks for one first")
	account.queue_free()
	OS.kill(server)


func _assistant(library: PartLibrary) -> void:
	print("\nthe assistant, asked to use the collection")
	_ok(Collection.wanted_in("A small red house, using only my collection")
		and Collection.wanted_in("a car from the parts I own")
		and not Collection.wanted_in("a small red house"),
		"a brief that asks for the collection is heard, and one that does not is not")
	var assistant := Assistant.new()
	assistant.library = library
	root.add_child(assistant)
	assistant.owned = {"3010/4": 30, "3010/0": 4, "3001/15": 12}
	var opening: Array = assistant.opening_for("a wall from my collection")
	var told: String = ""
	for block: Dictionary in opening:
		told += str(block.get("text", "")) + "\n"
	_ok(told.contains("only from the person's own collection") and told.contains("46 pieces"),
		"the brief arrives with what they own (46 pieces)")
	_ok(told.contains("Red (30)"), "...and their colours, most first")
	assistant._brief = "a wall from my collection"
	var found: String = assistant._search("brick 1 x 4", 8)
	var first: String = found.get_slice("\n", 0)
	print("     %s" % first)
	_ok(first.begins_with("3010:") and first.contains("you own 34: Red 30, Black 4"),
		"search_parts leads with the 1 x 4 they own and says how many of each colour")
	assistant._brief = "a wall"
	var plain: String = assistant._search("brick 1 x 4", 8)
	_ok(not plain.contains("you own"), "a brief that did not ask hears nothing about it")
	assistant.queue_free()
