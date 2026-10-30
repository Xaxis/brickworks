## A set's parts in the bin, and the assistant's brief drafted, as a set's
## page on the site opens the app (sets364): /app?parts=10497-1 and
## &assistant=on&brief=..., which the shell hands Main as --parts and --brief.
##
##   godot --path . --resolution 1280x860 --script src/dev/set_parts_probe.gd -- --assistant=on
##
## Main is given the set and the brief before it is up, as its address gives
## them. Once it has opened: the bin builds from 10497-1 Galaxy Explorer's
## parts (SetBin), by part and colour, the most used first (its first tile
## the part and colour the set has most of, from its inventory in
## assets/generated/sets/), each tile counting how many the set has, the
## line at its top naming the set; the assistant's box holds the brief, not
## sent; a search picks among the set's parts, and All parts gives the bin
## back to every part. A set nobody has heard of is said so, and the bin is
## left as it was. setbin_probe counts them down as parts are put down.
extends SceneTree

const SET := "10497-1"
const BRIEF := "Design something new with the parts of LEGO® set 10497-1 Galaxy Explorer."

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://src/main.tscn").instantiate()
	main.set("_bin_set", SET)
	main.set("_brief_draft", BRIEF)
	root.add_child(main)
	var bin: PartsBin = null
	for _n: int in 1200:
		await process_frame
		bin = main.get("_bin")
		if bin != null and not bin.set_showing().is_empty():
			break
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	var library: PartLibrary = main.get("_library")

	# What the set has most of, from its own inventory, as the bin counts it.
	var books := SetInventories.new()
	root.add_child(books)
	var found: Dictionary = await books.lookup(PackedStringArray([SET]))
	var counts: Dictionary = {}
	var parts: Dictionary = {}
	for row: Array in (found.get(SET, {}) as Dictionary).get("p", []):
		var key: String = Collection.key_of(str(row[0]), int(row[1]), library)
		counts[key] = int(counts.get(key, 0)) + int(row[2])
		parts[Collection.part_of(key)] = true
	var most_key: String = ""
	for key: String in counts:
		var info: PartLibrary.PartInfo = library.parts.get(Collection.part_of(key))
		if info == null or not info.reachable:
			continue
		if most_key.is_empty() or int(counts[key]) > int(counts[most_key]) \
				or (int(counts[key]) == int(counts[most_key]) and key < most_key):
			most_key = key
	var most: String = Collection.part_of(most_key)
	_check("the set's inventory is here (%d kinds of part and colour)" % counts.size(), counts.size() > 50)

	var shown: String = bin.set_showing() if bin != null else ""
	_check("the bin shows the set's parts: \"%s\"" % shown, shown == "10497-1 Galaxy Explorer")
	var tiles: PackedStringArray = bin.first_found(6)
	_check("its first tile is what the set has most of (%s, %d of it): %s" % [most_key,
		int(counts.get(most_key, 0)), ", ".join(tiles)], not tiles.is_empty() and tiles[0] == most
		and str(bin.counts_shown(1)[0][0]) == most_key)
	var every: bool = true
	for id: String in tiles:
		every = every and parts.has(id)
	_check("every tile is one of the set's parts", every)
	var status: Label = bin.controls_by_name()["set words"]
	_check("the line at its top names the set: \"%s\"" % status.text, status.text.contains("10497-1 Galaxy Explorer")
		and status.is_visible_in_tree())
	# Its tile names it and counts it: "Plate 1×2  ×12" (appux371 A4 put
	# the part's name where its number was).
	var label: String = ""
	for cell: Node in bin.get("_grid").get_children():
		if str(cell.get_meta("key", "")) != most_key:
			continue
		for child: Node in cell.find_children("*", "Label", true, false):
			label = (child as Label).text
	# The count on the name's last line when it fits there, else under it;
	# the name in pieces where it is cut, its number after it where another
	# tile's reads the same (PartsBin._tell_apart).
	var named: String = PartsBin.tile_name(bin.library.parts[most])
	var words: String = " ".join(label.replace("\n", " ").split(" ", false))
	var at: int = 0
	var pieces: PackedStringArray = words.get_slice(" ×", 0).trim_suffix(" " + most).split("…", false)
	for n: int in pieces.size():
		var piece_at: int = named.find(pieces[n].strip_edges(), at)
		at = piece_at + pieces[n].strip_edges().length() if piece_at >= 0 and (n > 0 or piece_at == 0) else -1
		if at < 0:
			break
	_check("its tile names it and counts how many the set has: \"%s\"" % words,
		words.ends_with(" ×%d" % int(counts[most_key])) and at >= 0)

	# The bin asking again by itself, as it does when the web build's
	# catalogue arrives after the set was shown: the set stays.
	bin.populate()
	await process_frame
	_check("the bin asking again by itself keeps the set (%s)" % ", ".join(bin.first_found(4)),
		bin.set_showing() == "10497-1 Galaxy Explorer" and bin.first_found(1) == PackedStringArray([most]))

	var chat: ChatPanel = main.get("_chat")
	_check("the assistant's box holds the brief, not sent", chat != null and chat.drafted() == BRIEF)

	bin.call("_on_search_typed", "brick")
	await process_frame
	var bricks: PackedStringArray = bin.first_found(400)
	var among: bool = not bricks.is_empty()
	for id: String in bricks:
		among = among and parts.has(id)
	_check("a search picks among the set's parts (%d tiles: %s)" % [bricks.size(),
		", ".join(bricks.slice(0, 4))], among and bin.set_showing() == "10497-1 Galaxy Explorer")
	(bin.controls_by_name()["all parts back"] as Button).pressed.emit()
	await process_frame
	_check("All parts gives the bin back to every part", bin.set_showing().is_empty()
		and not status.is_visible_in_tree())

	main.set("_bin_set", "nosuch-99")
	await main.call("_maybe_fill_bin")
	_check("a set nobody has heard of leaves the bin as it was", bin.set_showing().is_empty())

	if _failures == 0:
		print("set parts probe: the set's parts in the bin, and the brief drafted")
	else:
		print("set parts probe: %d failed" % _failures)
	quit(1 if _failures else 0)
