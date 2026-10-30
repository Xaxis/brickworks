## A set's parts in the bin, and the assistant's brief drafted, as a set's
## page on the site opens the app (sets364): /app?parts=10497-1 and
## &assistant=on&brief=..., which the shell hands Main as --parts and --brief.
##
##   godot --path . --resolution 1280x860 --script src/dev/set_parts_probe.gd -- --assistant=on
##
## Main is given the set and the brief before it is up, as its address gives
## them. Once it has opened: the bin shows 10497-1 Galaxy Explorer's parts,
## the most used first (its first tile the part the set has most of, from
## its inventory in assets/generated/sets/), each tile counting how many the
## set has, its status line naming the set; the assistant's box holds the
## brief, not sent; and a search gives the bin back to every part. A set
## nobody has heard of is said so, and the bin is left as it was.
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
	for row: Array in (found.get(SET, {}) as Dictionary).get("p", []):
		var id: String = library.resolve(str(row[0]))
		counts[id] = int(counts.get(id, 0)) + int(row[2])
	var most: String = ""
	for id: String in counts:
		var info: PartLibrary.PartInfo = library.parts.get(id)
		if info == null or not info.reachable:
			continue
		if most.is_empty() or int(counts[id]) > int(counts[most]) or (int(counts[id]) == int(counts[most]) and id < most):
			most = id
	_check("the set's inventory is here (%d kinds of part)" % counts.size(), counts.size() > 50)

	var shown: String = bin.set_showing() if bin != null else ""
	_check("the bin shows the set's parts: \"%s\"" % shown, shown == "10497-1 Galaxy Explorer")
	var tiles: PackedStringArray = bin.first_found(6)
	_check("its first tile is what the set has most of (%s, %d of it): %s" % [most, int(counts.get(most, 0)),
		", ".join(tiles)], not tiles.is_empty() and tiles[0] == most)
	var every: bool = true
	for id: String in tiles:
		every = every and counts.has(id)
	_check("every tile is one of the set's parts", every)
	var status: Label = bin.get("_status")
	_check("its status line names the set: \"%s\"" % status.text, status.text.contains("10497-1 Galaxy Explorer"))
	var label: String = ""
	for cell: Node in bin.get("_grid").get_children():
		for child: Node in cell.find_children("*", "Label", true, false):
			if (child as Label).text.begins_with(most + "  ×"):
				label = (child as Label).text
	_check("its tile counts how many the set has: \"%s\"" % label, label == "%s  ×%d" % [most, int(counts[most])])

	# The bin asking again by itself, as it does when the web build's
	# catalogue arrives after the set was shown: the set stays.
	bin.populate()
	await process_frame
	_check("the bin asking again by itself keeps the set (%s)" % ", ".join(bin.first_found(4)),
		bin.set_showing() == "10497-1 Galaxy Explorer" and bin.first_found(1) == PackedStringArray([most]))

	var chat: ChatPanel = main.get("_chat")
	_check("the assistant's box holds the brief, not sent", chat != null and chat.drafted() == BRIEF)

	bin.call("_on_search_typed", "brick 2 x 4")
	await process_frame
	_check("a search gives the bin back to every part", bin.set_showing().is_empty()
		and not status.text.contains("Galaxy Explorer"))

	main.set("_bin_set", "nosuch-99")
	await main.call("_maybe_fill_bin")
	_check("a set nobody has heard of leaves the bin as it was", bin.set_showing().is_empty())

	if _failures == 0:
		print("set parts probe: the set's parts in the bin, and the brief drafted")
	else:
		print("set parts probe: %d failed" % _failures)
	quit(1 if _failures else 0)
