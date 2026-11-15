## The parts bin held to the person's own bricks, and a session's design
## held to them too (docs/APP_UX8.md #4 and unit 5, ownlimit).
##
##   godot --path . --resolution 1280x720 --script src/dev/ownlimit_probe.gd [-- --shots=DIR]
##
## A collection of set 7140-1 and 12 loose lots, kept on this device
## (CollectionStore.where), its sets' parts read from their inventories as
## the app reads them. Then:
## - My collection's What I own offers Build from my bricks; pressed, the bin
##   is "My bricks": a tile for each part and colour the pool holds, each
##   counting the pool's number from the bin's first frame;
## - a wall of eight Red 2 x 4 bricks put down from its tile one at a time,
##   then four more on it: at every step every tile counts exactly the pool
##   less the model (OwnCounts.left, worked out here from the model), and the
##   line says the pieces left of the pool's;
## - the twelfth, the last owned: its tile "none left", greyed, and the bin
##   says the last is down; the thirteenth: "1 over" on its tile and the line,
##   the bin says it is past the 12 owned, and the parts list marks its row
##   "1 over"; Undo gives it back, saying nothing;
## - saved, the model keeps "mine" on its BIN line; the bin put back to every
##   part and the model opened again, the bin is My bricks with the model
##   counted;
## - a lot added to the collection (another device's change, read here) is
##   in its tile at once; the collection gone (signed out), the bin says
##   nothing is in it, and back, the counts are back;
## - a recount over 3,000 parts against the pool takes under 5 ms of the
##   app's own time (ProbeTime, its slack on a busy box);
## - over the command socket, as a session calls it: parts_list need tells of
##   submit_design mine=true; a small car of owned parts, mine=true, is said
##   to be every part theirs; one with a 13th Red 2 x 4 and two Bright Green 2 x 2s
##   names exactly those, by how many over.
## Each count is read from what the tile says.
extends SceneTree

const SET := "7140-1"
const SAVED := "Ownlimit Probe"
## Red 2 x 4: the wall's brick, 12 owned loose and none in 7140.
const WALL := "3001/4"
## The 12 loose lots: part, LDraw colour, how many.
const LOTS: Array = [
	["3001", 4, 12], ["3020", 0, 4], ["3021", 4, 4], ["4600", 0, 2], ["4624", 71, 4],
	["3641", 0, 4], ["3004", 15, 6], ["3023", 15, 6], ["3024", 47, 4], ["3069b", 0, 4],
	["3010", 1, 4], ["3062b", 14, 2],
]

var _failures: int = 0
var _shots: String = ""
var _main: Node
var _bin: PartsBin
var _builder: Builder
var _shell: Shell
var _socket: CommandSocket
var _next: int = 0
## What the bin said for the status bar, in order.
var _heard: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _until(done: Callable, most: int = 600) -> bool:
	for _n: int in most:
		if done.call():
			return true
		await process_frame
	return bool(done.call())


func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	await _frames(20)
	DirAccess.make_dir_recursive_absolute(_shots)
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = "%s/ownlimit_%s_%dx%d.png" % [_shots, name, size.x, size.y]
	root.get_texture().get_image().save_png(path)
	print("  shot  %s" % path)


func _cell(key: String) -> Button:
	for cell: Node in (_bin.get("_grid") as GridContainer).get_children():
		if str(cell.get_meta("key", "")) == key:
			return cell
	return null


## What the tile of [param key] says after its name: "×12", "none left".
func _count_on(key: String) -> String:
	var cell: Button = _cell(key)
	if cell == null:
		return "(no tile)"
	var label: Label = cell.get_meta("name_label")
	var words: String = label.text.replace("\n", " ")
	var count: RegExMatch = RegEx.create_from_string("(×\\d+|none left|\\d+ over)$").search(words)
	return count.get_string(1) if count != null else words


func _line() -> String:
	var named: Dictionary = _bin.controls_by_name()
	return "%s: %s" % [(named["set words"] as Label).text, (named["set count"] as Label).text]


## Take the tile of [param key] as a click does and put its part down at
## [param x], [param z]: the new brick's id, or 0.
func _put_down(key: String, x: float, z: float) -> int:
	var cell: Button = _cell(key)
	if cell == null:
		return 0
	cell.pressed.emit()
	var part: String = Collection.part_of(key)
	var library: PartLibrary = _main.get("_library")
	await _until(func() -> bool: return library.is_resident(part), 600)
	await _frames(2)
	_builder.update_preview(Vector3(x, 400.0, z), Vector3.DOWN)
	return _builder.place()


## Every tile against the pool less the model, worked out here: the tiles
## that say otherwise, and how many tiles there are.
func _miscounted(pool: Dictionary) -> Array:
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var library: PartLibrary = _main.get("_library")
	var left: Dictionary = OwnCounts.left(pool, SetBin.used_in(world, store.scenery, library))
	var wrong := PackedStringArray()
	var tiles: int = 0
	for cell: Node in (_bin.get("_grid") as GridContainer).get_children():
		var key: String = str(cell.get_meta("key", ""))
		if key.is_empty():
			continue
		tiles += 1
		if _count_on(key) != PartsBin.count_words(int(left.get(key, 0))):
			wrong.append("%s says %s, %d left" % [key, _count_on(key), int(left.get(key, 0))])
	return [wrong, tiles]


func _collection() -> Collection:
	var mine := Collection.new()
	mine.sets = [{"set": SET, "qty": 1, "spares": false, "src": "hand"}]
	for lot: Array in LOTS:
		mine.parts.append({"part": lot[0], "colour": lot[1], "qty": lot[2], "src": "hand"})
	return mine


func _take(store: CollectionStore, mine: Collection) -> void:
	store.collection = mine
	await store.refresh_pool()
	store.changed.emit()
	await _frames(3)


func _call(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var out := PackedStringArray()
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
			out.append(str(block["text"]))
	# What the session heard, its start, for a failure to be read.
	print("    %s said: %s" % [tool, "\n".join(out).left(600).replace("\n", " | ")])
	return "\n".join(out)


## A tower of [param bricks] ([part, colour] each), stacked from the ground.
static func _tower(bricks: Array) -> Array:
	var out: Array = []
	var y: int = 0
	for one: Array in bricks:
		out.append({"part": one[0], "color": one[1], "x": 0, "y": y, "z": 0, "rot": 0})
		y += 1 if str(one[0]) in ["3020", "3021", "3023", "3024", "3069b", "4600"] else 3
	return out


func _run() -> void:
	CollectionStore.where = OS.get_temp_dir().path_join("brickworks_ownlimit_%d.json" % OS.get_process_id())
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _until(func() -> bool:
		var bin: PartsBin = _main.get("_bin")
		return bin != null and int(bin.get("_offerable")) > 0, 1200)
	await _frames(30)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_bin = _main.get("_bin")
	_builder = _main.get("_builder")
	_shell = _main.get("_shell")
	_bin.said.connect(func(line: String) -> void: _heard.append(line))
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var library: PartLibrary = _main.get("_library")
	var dock: Variant = _main.get("_bin_dock")
	if dock != null and not dock.is_open():
		dock.set_open(true)
	world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	store.scenery.clear()
	await _frames(5)

	print("\na collection of %s and %d loose lots" % [SET, LOTS.size()])
	var dialog: CollectionDialog = _shell.collection
	var owner: CollectionStore = dialog.store
	await _take(owner, _collection())
	var pool: Dictionary = owner.on_hand
	var record: Dictionary = owner.records.get(SET, {})
	var set_pieces: int = 0
	for row: Variant in record.get("p", []):
		set_pieces += int((row as Array)[2])
	var loose: int = 0
	for lot: Array in LOTS:
		loose += int(lot[2])
	_check("the pool is %s's %d pieces and the %d loose: %d" % [SET, set_pieces, loose,
		owner.pieces_on_hand()], set_pieces > 0 and owner.pieces_on_hand() == set_pieces + loose)
	_check("12 Red 2 x 4 bricks are owned, none of them 7140's: %d" % int(pool.get(WALL, 0)),
		int(pool.get(WALL, 0)) == 12)

	print("\nBuild from my bricks, in My collection")
	dialog.open("own")
	await _frames(5)
	var go: Button = dialog.controls_by_name().get("collection_build_mine")
	_check("What I own offers Build from my bricks", go != null and go.is_visible_in_tree())
	await _shot("collection")
	if go != null:
		go.pressed.emit()
	# The counts with the bin's first frame: the tiles made by the press,
	# read before any frame has passed.
	var first: Array = _miscounted(pool)
	_check("the bin is My bricks at once: \"%s\", the panel closed" % _bin.set_showing(),
		_bin.set_showing() == OwnCounts.TITLE and not dialog.visible)
	_check("its first tiles count the pool from the frame they are made (%d tiles, %d wrong%s)" % [
		first[1], (first[0] as Array).size(), ": " + str(first[0][0]) if not (first[0] as Array).is_empty() else ""],
		int(first[1]) > 0 and (first[0] as Array).is_empty())
	_bin.call("_show_more", 100000)
	await _frames(3)
	var shown: Array = _miscounted(pool)
	var kinds: int = 0
	var library_shows: int = 0
	for key: String in pool:
		var info: PartLibrary.PartInfo = library.parts.get(Collection.part_of(key))
		if int(pool[key]) > 0:
			kinds += 1
			if info != null and info.reachable and not info.is_redirect():
				library_shows += 1
	_check("a tile for each part and colour owned that this build draws: %d of %d, %d wrong" % [
		shown[1], library_shows, (shown[0] as Array).size()],
		int(shown[1]) == library_shows and (shown[0] as Array).is_empty())
	var all_pieces: int = owner.pieces_on_hand()
	_check("the line: \"%s\"" % _line(), _line() == "%s: %s of %s left" % [OwnCounts.TITLE,
		PartsBin._comma(all_pieces), PartsBin._comma(all_pieces)])
	_check("its hint says every set counts, built or not",
		(_bin.controls_by_name()["set words"] as Label).tooltip_text.contains(OwnCounts.BUILT_WORDS))
	await _shot("mine")

	print("\na wall of eight, then four on it: every tile, every step")
	var steps_right: int = 0
	var worst: String = ""
	for n: int in 12:
		var x: float = 80.0 * (n % 8) if n < 8 else 80.0 * (n - 8) * 2.0
		var placed: int = await _put_down(WALL, x, 40.0)
		await _until(func() -> bool: return _count_on(WALL) == PartsBin.count_words(11 - n), 60)
		var counted: Array = _miscounted(pool)
		var line_ok: bool = _line().contains("%s of %s left" % [PartsBin._comma(all_pieces - n - 1),
			PartsBin._comma(all_pieces)])
		if placed != 0 and (counted[0] as Array).is_empty() and line_ok:
			steps_right += 1
		elif worst.is_empty():
			worst = "step %d (brick %d): %s; %s" % [n + 1, placed, ", ".join(counted[0] as Array).left(160), _line()]
	_check("at each of the 12 steps every tile reads the pool less the model, and the line (%d of 12%s)" % [
		steps_right, "; " + worst if not worst.is_empty() else ""], steps_right == 12)
	var wall_tile: Control = _cell(WALL).get_meta("tile")
	_check("the twelfth down, its tile says \"%s\", greyed (%.2f)" % [_count_on(WALL), wall_tile.modulate.a],
		_count_on(WALL) == "none left" and wall_tile.modulate.a < 0.6)
	_check("...and the bin says the last is down: \"%s\"" % (_heard[-1] if not _heard.is_empty() else ""),
		not _heard.is_empty() and _heard[-1] == "the last Brick 2 x 4 in Red you own is down")
	_check("nothing was said before the last (%d said)" % _heard.size(), _heard.size() == 1)
	await _shot("none_left")

	print("\nthe thirteenth, past the 12 owned")
	var thirteenth: int = await _put_down(WALL, 80.0 * 7, 40.0)
	await _until(func() -> bool: return _count_on(WALL) == "1 over", 60)
	_check("put down (brick %d), its tile says \"%s\"" % [thirteenth, _count_on(WALL)],
		thirteenth != 0 and _count_on(WALL) == "1 over")
	_check("...the line: \"%s\"" % _line(), _line().ends_with(", 1 over"))
	_check("...and the bin says it is past them: \"%s\"" % (_heard[-1] if not _heard.is_empty() else ""),
		_heard.size() == 2 and _heard[-1] == "Brick 2 x 4 in Red: past the 12 you own, 1 over")
	_main.call("_toggle_parts")
	await _frames(3)
	var parts_list: InventoryPanel = _main.get("_inventory")
	var row_over: String = ""
	var rows_over: int = 0
	for made: Array in parts_list.get("_made"):
		var lot: Inventory.Lot = made[0]
		if parts_list.over_of(lot) > 0:
			rows_over += 1
			for label: Node in (made[1] as Button).find_children("*", "Label", true, false):
				if (label as Label).text.ends_with(" over"):
					row_over = "%s %d: %s" % [lot.part_id, lot.color_code, (label as Label).text]
	_check("the parts list marks its row, and only its row: %s (%d rows over)" % [row_over, rows_over],
		row_over == "3001 4: 1 over" and rows_over == 1)
	await _shot("parts_list_over")
	_main.call("_toggle_parts")
	_shell.run("undo")
	await _until(func() -> bool: return _count_on(WALL) == "none left", 60)
	_check("Undo gives it back: %s, the line \"%s\", nothing said (%d)" % [_count_on(WALL), _line(),
		_heard.size()], _count_on(WALL) == "none left" and not _line().contains("over") and _heard.size() == 2)

	print("\nthe choice is kept with the model")
	var path: String = ModelStore.saved_path(SAVED)
	_check("saved as \"%s\"" % SAVED, store.save_as(SAVED))
	var text: String = FileAccess.get_file_as_string(path)
	_check("its file keeps the bin as mine: %s" % SetBin.read(text),
		SetBin.read(text) == PackedStringArray([OwnCounts.WORD]))
	(_bin.controls_by_name()["all parts back"] as Button).pressed.emit()
	await _frames(3)
	_check("All parts gives back the whole library", _bin.set_showing().is_empty())
	var opened: int = store.open(path)
	await _until(func() -> bool: return _bin.set_showing() == OwnCounts.TITLE, 600)
	_bin.call("_show_more", 100000)
	await _until(func() -> bool: return _count_on(WALL) == "none left", 60)
	var reopened: Array = _miscounted(pool)
	_check("opened again (%d parts), the bin is My bricks with the model counted: %s, %d wrong" % [
		opened, _count_on(WALL), (reopened[0] as Array).size()],
		opened == 12 and _count_on(WALL) == "none left" and (reopened[0] as Array).is_empty())
	_check("opening it said nothing (%d)" % _heard.size(), _heard.size() == 2)

	print("\nthe collection changes under it")
	var more: Collection = _collection()
	more.parts[0]["qty"] = 13
	await _take(owner, more)
	await _until(func() -> bool: return _count_on(WALL) == "×1", 60)
	_check("a 13th Red 2 x 4 owned (another device's change): its tile says %s" % _count_on(WALL),
		_count_on(WALL) == "×1")
	await _take(owner, Collection.new())
	await _frames(3)
	_check("the collection gone (signed out): \"%s\"" % _line(),
		_line() == "%s: nothing in your collection" % OwnCounts.TITLE)
	await _take(owner, _collection())
	_bin.call("_show_more", 100000)
	await _until(func() -> bool: return _count_on(WALL) == "none left", 60)
	var back: Array = _miscounted(owner.on_hand)
	_check("back, the counts are back: %s, %d wrong" % [_count_on(WALL), (back[0] as Array).size()],
		_count_on(WALL) == "none left" and (back[0] as Array).is_empty())
	_check("nothing was said of the collection changing (%d)" % _heard.size(), _heard.size() == 2)
	DirAccess.remove_absolute(path)

	print("\nwhat a recount costs over 3,000 parts")
	world.clear()
	_builder.lattice.clear()
	var keys: Array = pool.keys()
	for n: int in 3000:
		var key: String = keys[n % keys.size()]
		world.add_brick(Collection.part_of(key), Collection.colour_of(key),
			Transform3D(Basis.IDENTITY, Vector3(20.0 * (n % 60), 24.0 * (n / 3600), 20.0 * ((n / 60) % 60))))
	var spans: Array = []
	for _n: int in 7:
		var span := ProbeTime.Span.new()
		_bin.call("_recount", false)
		spans.append(span.end())
	spans.sort_custom(func(a: ProbeTime.Span, b: ProbeTime.Span) -> bool: return a.own < b.own)
	var middle: ProbeTime.Span = spans[3]
	_check("a recount of My bricks against 3,000 parts: %s, the median of 7, under %.0f ms" % [
		middle.said(), 5.0 * middle.slack()], middle.own < 5.0 * middle.slack())
	world.clear()
	_builder.lattice.clear()
	_builder.forget_history()

	print("\nover the command socket, as a session calls it")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await _frames(2)
	# Plates and bricks stacked from one corner, studs in holes, with no
	# 4600 (its pins stand proud): a design that does not hold is not laid.
	var car: Array = _tower([["3020", 0], ["3001", 4], ["3001", 4], ["3021", 4], ["3020", 0]])
	var built: String = await _call("submit_design", {"name": "Small car", "description": "a small car", "floor": "none",
		"bricks": car, "mine": true})
	_check("submit_design mine=true of owned parts: built, and every part theirs: %s" % (
		_line_with(built, "mine=true")).left(160),
		built.begins_with("Built") and built.contains("From the person's own parts (mine=true): every one of its 5 pieces"))
	var after: String = await _call("parts_list", {"which": "need"})
	_check("parts_list need reads the collection and tells of mine=true",
		after.contains("submit_design mine=true") and after.contains("They own every piece"))
	var over: Array = [["3020", 0]]
	for _n: int in 13:
		over.append(["3001", 4])
	over.append(["3003", 10])
	over.append(["3003", 10])
	var too_many: String = await _call("submit_design", {"name": "Small car", "description": "a small car", "floor": "none",
		"bricks": _tower(over), "mine": true})
	var red: String = _line_with(too_many, "3001 Brick 2 x 4 in Red")
	var lime: String = _line_with(too_many, "3003 Brick 2 x 2 in Bright Green")
	_check("of 13 Red 2 x 4s and two Bright Green 2 x 2s: \"%s\"" % _line_with(too_many, "mine=true").left(140),
		too_many.contains("Over the person's collection (mine=true): 2 parts it uses more of than they own, 3 pieces over"))
	_check("...naming the Red 2 x 4: %s" % red.strip_edges(), red.contains("13 used, they own 12, 1 over"))
	_check("...and the Bright Green 2 x 2: %s" % lime.strip_edges(), lime.contains("2 used, they own 0, 2 over"))
	var without: String = await _call("submit_design", {"name": "Small car", "description": "a small car", "floor": "none",
		"bricks": car})
	_check("without mine, nothing is said of the collection", not without.contains("mine=true"))
	await _call("clear_model", {})
	_socket.stop()

	DirAccess.remove_absolute(CollectionStore.where)
	if _failures == 0:
		print("ownlimit probe: the bin and a session's design held to the person's own bricks")
	else:
		print("ownlimit probe: %d failed" % _failures)
	quit(1 if _failures else 0)


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return ""
