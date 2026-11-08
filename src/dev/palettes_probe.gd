## A palette of the person's own, kept for every model (docs/APP_UX6.md, palettes).
##
##   godot --path . --resolution 1280x720 --script src/dev/palettes_probe.gd
##
## The app opened as a person opens it, the bin out, everything done through
## the window: a press on a chip, a row, a menu's row, keys typed.
##
## * The bin has Palettes beside Favourites. New palette, "Castle" typed over
##   its name; twelve parts selected in the model, Add, "The selected parts,
##   each in its colour": twelve tiles, each part in its own colour; four
##   parts of a gatepost selected, Add, "The selection, as one sub-assembly",
##   "Gatepost" typed: a thirteenth tile, the sub-assembly drawn whole;
## * kept: in the file as it is written, and read by the app started again
##   (a second run of this probe, on the same data folder);
## * another model, in a window started afresh: Palettes, then Castle, two
##   presses, shows the twelve and the gatepost; a part from it is taken in
##   hand in its colour, and the gatepost held whole and put down whole, each
##   part where it stood beside the others to 0.01 LDU, as one assembly called
##   Gatepost, one undo taking it all back;
## * Favourites unchanged: the two parts kept there before, its chip's count,
##   and a right-click still keeping a part there, in a palette too;
## * two windows: another window's palette and entry kept beside this one's
##   next change; an older copy stored over this one's (the web's tabs copy
##   each other's writes a moment late) has this window's entry written back
##   within three seconds; what another window took out stays out;
## * a later build's tab beside this one (after an update): its own kind of
##   entry not shown here, and it, a word it put on the palette and one on a
##   part, all kept through this window's rename; a damaged file kept beside
##   it before this window's next change writes over it;
## * Techniques scrolled to its end lists constructions only, as Palettes
##   does (both drew the last search's tiles in under their rows).
##
## At 1280 x 720, and at 1400 x 900 with PROBE_SIZE=1400x900. Pictures go to
## shots/palettes/. Look at them.
extends SceneTree

## The twelve, each part in its colour.
const PARTS: Array = [["3001", 4], ["3003", 1], ["3004", 14], ["3010", 15], ["3020", 2],
	["3022", 71], ["3023b", 72], ["3024", 0], ["3039", 4], ["3068b", 15], ["3069b", 1], ["4070", 14]]
## The gatepost: two 2 x 2 bricks, a plate and a tile, stacked.
const POST: Array = [["3003", 71, Vector3(400, 24, 400)], ["3003", 71, Vector3(400, 48, 400)],
	["3022", 72, Vector3(400, 56, 400)], ["3068b", 15, Vector3(400, 64, 400)]]
## Add's rows and More's, as the bin numbers them.
const ADD_HELD := 0
const ADD_PARTS := 1
const ADD_ASSEMBLY := 2
const SHELF_FILE := "user://palettes_probe_shelf.cfg"
const PALETTES_FILE := "user://palettes_probe.cfg"

var _failures: int = 0
var _main: Node
var _bin: PartsBin
var _builder: Builder
var _world: BrickWorld
var _library: PartLibrary
var _camera: CadCamera
var _store: ModelStore
var _tag: String = ""
var _autosave: PackedByteArray = PackedByteArray()
var _had_autosave: bool = false
## PartShelf, asked by name: a build without palettes still runs this.
var _shelf: Script = load("res://src/ui/part_shelf.gd")
var _said: Array[String] = []


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	ShellPrefs.kept_by_a_check = _own_data_folder()
	_shelf.set("file", SHELF_FILE)
	_shelf.set("keeps", true)
	if _shelf.get("palettes_file") != null:
		_shelf.set("palettes_file", PALETTES_FILE)
	await process_frame
	if OS.get_cmdline_user_args().has("--after-restart"):
		_after_restart()
		return
	if DisplayServer.get_name() == "headless":
		print("  palettes probe: needs a window")
		quit(1)
		return
	PartShelf.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PALETTES_FILE))
	_had_autosave = FileAccess.file_exists(ModelStore.autosave())
	if _had_autosave:
		_autosave = FileAccess.get_file_as_bytes(ModelStore.autosave())
	await _open_app()
	var size: Vector2i = DisplayServer.window_get_size()
	_tag = "%dx%d" % [size.x, size.y]
	print("  the parts bin in a %s window" % _tag)

	var favourites: PackedStringArray = await _favourites_first()
	var chip: Button = _bin.controls_by_name().get("palettes")
	_check("the bin has Palettes beside Favourites (%s)" % (chip.text if chip != null else "none"),
		chip != null and _beside_favourites(chip))
	if chip == null:
		_finish()
		return
	var favourites_chip: String = _chip("Favourites").text

	await _make_castle()
	await _kept()
	await _another_model()
	await _favourites_unchanged(favourites, favourites_chip)
	await _two_windows()
	await _techniques_scrolled()
	_finish()


func _finish() -> void:
	if _shelf.get("palettes_file") != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PALETTES_FILE))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PALETTES_FILE + ".unreadable"))
	PartShelf.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SHELF_FILE))
	_put_back_autosave()
	print("")
	print("palettes probe: a palette of parts and a sub-assembly, kept and taken to another model"
		if _failures == 0 else "palettes probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


func _open_app() -> void:
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _until(func() -> bool:
		var bin: PartsBin = _main.get("_bin")
		return bin != null and int(bin.get("_offerable")) > 0, 1200)
	await _frames(60)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_bin = _main.get("_bin")
	_builder = _main.get("_builder")
	_world = _main.get("_world")
	_library = _main.get("_library")
	_camera = _main.get("_camera")
	_store = _main.get("_store")
	_store.keeps = false
	var verbs: EditVerbs = _main.get("_verbs")
	var said: Callable = verbs.say
	verbs.say = func(words: String) -> void:
		_said.append(words)
		said.call(words)
	(_main.get("_bin_dock") as SideDock).set_open(true)
	await create_timer(SideDock.SLIDE_SECONDS * 2.0).timeout
	await _frames(30)


# -- Favourites, before ---------------------------------------------------------


## Two parts kept in Favourites by a right-click each, as a person keeps them.
func _favourites_first() -> PackedStringArray:
	print("")
	print("  two parts kept in Favourites, by a right-click each")
	await _click(_chip("All").get_global_rect().get_center())
	for part: String in ["3001", "3004"]:
		await _type(part)
		var tile: Button = await _tile_of(part)
		if tile != null:
			await _right_click(tile.get_global_rect().get_center())
	await _type("")
	var kept: PackedStringArray = PartShelf.favourites().duplicate()
	_check("Favourites holds them: %s" % [kept], kept == PackedStringArray(["3001", "3004"]))
	return kept


# -- a palette made ---------------------------------------------------------------


## Castle: twelve parts in their colours and a gatepost, from the model.
func _make_castle() -> void:
	print("")
	print("  a palette of twelve parts and a sub-assembly, named Castle")
	_main.clear_model()
	await _frames(10)
	await _click(_named("palettes").get_global_rect().get_center())
	_check("Palettes, chosen, says there are none yet (\"%s\")" % _status(),
		_rows().is_empty() and _status().begins_with("No palettes yet"))
	await _shot("palettes_none")
	await _click(_named("palette new").get_global_rect().get_center())
	var field: LineEdit = _named("palette name")
	_check("New palette opens one with its name chosen, to type over (\"%s\")" % field.text,
		field.has_focus() and field.get_selected_text() == field.text and not field.text.is_empty())
	await _type_keys("Castle")
	await _key(KEY_ENTER)
	var castle: Dictionary = _palette_named("Castle")
	_check("typed over and Return: it is called Castle (%s)" % [_names()], not castle.is_empty())

	for n: int in PARTS.size():
		_put(str(PARTS[n][0]), int(PARTS[n][1]), Vector3(-200 + (n % 4) * 100, 24, -200 + (n / 4) * 100))
	var post: Array[int] = []
	for one: Array in POST:
		post.append(_put(str(one[0]), int(one[1]), one[2]))
	_camera.frame(AABB(Vector3(-260, 0, -260), Vector3(720, 120, 720)))
	await _frames(20)
	_select(_world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id) and not post.has(b.id)).map(
			func(b: BrickWorld.Brick) -> int: return b.id))
	await _from_add(ADD_PARTS)
	castle = _palette_named("Castle")
	var pairs: Array = _pairs_of(castle)
	_check("Add, The selected parts, each in its colour: the twelve kept (%d) %s" % [pairs.size(), pairs],
		_same_pairs(pairs, PARTS))
	_check("...and said: \"%s\"" % _last_said(), _last_said().begins_with("kept 12 parts in “Castle”"))
	var tiles: Array = _part_tiles()
	_check("...twelve tiles, each part in its own colour (%d) %s" % [tiles.size(), tiles],
		_same_pairs(tiles, PARTS))

	_select(post)
	await _from_add(ADD_ASSEMBLY)
	var asked: LineEdit = _bin.controls_by_name().get("name field")
	_check("Add, The selection, as one sub-assembly, asks its name (\"%s\" chosen)"
		% (asked.text if asked != null else "none"), asked != null and asked.is_visible_in_tree()
		and asked.has_focus())
	if asked != null:
		await _type_keys("Gatepost")
		await _key(KEY_ENTER)
	castle = _palette_named("Castle")
	var post_entry: Dictionary = _assembly_of(castle, "Gatepost")
	_check("typed Gatepost and Return: kept whole, %d parts (%d entries in Castle)" % [
		int(post_entry.get("count", 0)), (castle.get("entries", []) as Array).size()],
		int(post_entry.get("count", 0)) == 4 and (castle.get("entries", []) as Array).size() == 13)
	var cell: Button = _bin.controls_by_name().get("sub-assembly Gatepost")
	_check("...its tile in Castle beside the twelve", cell != null and _part_tiles().size() == 12)
	await _pictures_drawn()
	await _shot("castle")


# -- kept -------------------------------------------------------------------------


## In the file as written, and in the app started again on the same folder.
func _kept() -> void:
	print("")
	print("  Castle kept")
	var file := ConfigFile.new()
	var read: int = file.load(PALETTES_FILE)
	var listed: Array = file.get_value("palettes", "list", []) if read == OK else []
	var entries: int = (listed[0]["entries"] as Array).size() if listed.size() == 1 else 0
	_check("in the file as it is written: %d palette, %d entries" % [listed.size(), entries],
		listed.size() == 1 and str(listed[0]["name"]) == "Castle" and entries == 13)
	if not ShellPrefs.kept_by_a_check:
		_check("a data folder of this run's own to restart on (run by tools/probe.sh)", false)
		return
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://src/dev/palettes_probe.gd",
		"--", "--after-restart"], output, true)
	for line: String in "\n".join(output).split("\n"):
		if line.begins_with("  ok") or line.begins_with("  FAIL"):
			print("  " + line)
	_check("the app started again has Castle as it was (exit %d)" % code, code == 0)


## The second run: the palette read by the app as it starts.
func _after_restart() -> void:
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _until(func() -> bool:
		var bin: PartsBin = _main.get("_bin")
		return bin != null and int(bin.get("_offerable")) > 0, 1200)
	await _frames(10)
	_bin = _main.get("_bin")
	var castle: Dictionary = _palette_named("Castle")
	_check("Castle, %d entries" % (castle.get("entries", []) as Array).size(),
		(castle.get("entries", []) as Array).size() == 13)
	_check("...its twelve parts in their colours", _same_pairs(_pairs_of(castle), PARTS))
	_check("...and Gatepost, 4 parts", int(_assembly_of(castle, "Gatepost").get("count", 0)) == 4)
	var chip: Button = _bin.controls_by_name().get("palettes")
	_check("the chip counts it (\"%s\")" % (chip.text if chip != null else "none"),
		chip != null and chip.text == "Palettes 1")
	_main.queue_free()
	await _frames(4)
	quit(_failures)


# -- another model ----------------------------------------------------------------


## A window started afresh on a new model: Castle opened in two presses, a part
## taken from it, the gatepost put down whole.
func _another_model() -> void:
	print("")
	print("  another model, in a window started afresh")
	var original: Array = _post_shape(_world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return b.part_id in ["3003", "3022", "3068b"] and b.transform.origin.x > 300))
	_main.queue_free()
	await _frames(10)
	_shelf.call("forget_palettes")
	await _open_app()
	_main.clear_model()
	await _frames(10)
	_camera.frame(AABB(Vector3(-200, 0, -200), Vector3(400, 120, 400)))
	await _frames(10)
	_check("a new model, nothing on it (%d parts)" % _count(), _count() == 0)
	var presses: int = 0
	await _click(_named("palettes").get_global_rect().get_center())
	presses += 1
	var row: Button = _bin.controls_by_name().get("palette row Castle")
	_check("Palettes lists Castle (%s)" % [_rows()], row != null)
	await _shot("palettes_list")
	if row == null:
		return
	await _click(row.get_global_rect().get_center())
	presses += 1
	var tiles: Array = _part_tiles()
	var cell: Button = _bin.controls_by_name().get("sub-assembly Gatepost")
	_check("%d presses open it: its twelve parts in their colours (%d) and Gatepost" % [presses, tiles.size()],
		presses == 2 and _same_pairs(tiles, PARTS) and cell != null)
	await _pictures_drawn()
	await _shot("castle_in_another_model")

	var slope: Button = await _in_sight(_tile_keyed("3039/4"))
	if slope != null:
		await _click(slope.get_global_rect().get_center())
	_check("a part chosen from it is in hand in its own colour (%s in %d)" % [
		_builder.held_part, _bin.selected_color()], _builder.held_part == "3039" and _bin.selected_color() == 4)
	await _key(KEY_ESCAPE)

	cell = await _in_sight(_bin.controls_by_name().get("sub-assembly Gatepost"))
	await _click(cell.get_global_rect().get_center())
	await _until(func() -> bool: return _builder.is_carrying(), 300)
	var colours: Dictionary = {}
	if _builder.is_carrying():
		for item: Dictionary in _builder.carrying.items:
			colours[int(item["color"])] = int(colours.get(int(item["color"]), 0)) + 1
	_check("Gatepost chosen is held whole: %d parts, colours %s" % [
		_builder.carrying.count() if _builder.is_carrying() else 0, colours],
		_builder.is_carrying() and _builder.carrying.count() == 4 and colours == {71: 2, 72: 1, 15: 1})
	var spot: Vector2 = await _somewhere_free()
	_check("...its ghost can go down on the baseplate", spot != Vector2.INF)
	await _click(spot)
	await _frames(6)
	var down: Array = _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))
	var shape: Array = _post_shape(down)
	_check("a click puts it down whole: %d parts, each where it stood beside the others to 0.01 LDU"
		% down.size(), down.size() == 4 and _same_shape(shape, original))
	var groups: Dictionary = {}
	for brick: BrickWorld.Brick in down:
		groups[brick.group] = true
	_check("...as one assembly called Gatepost (%s)" % [groups.keys()], groups.keys() == ["Gatepost"])
	await _shot("gatepost_down")
	await _key(KEY_Z, true)
	await _frames(6)
	_check("one undo takes it all back (%d parts)" % _count(), _count() == 0)


# -- Favourites, after --------------------------------------------------------------


func _favourites_unchanged(before: PackedStringArray, chip_before: String) -> void:
	print("")
	print("  Favourites unchanged")
	_check("it still holds the two kept before: %s" % [PartShelf.favourites()],
		PartShelf.favourites() == before)
	_check("its chip says so as before (\"%s\")" % _chip("Favourites").text, _chip("Favourites").text == chip_before)
	await _click(_chip("Favourites").get_global_rect().get_center())
	var listed: Array = []
	for child: Node in (_bin.get("_grid") as GridContainer).get_children():
		listed.append(str(child.get_meta("part", "")))
	_check("Favourites lists them, in their order: %s" % [listed], listed == Array(before))
	await _click(_named("palettes").get_global_rect().get_center())
	await _click((_bin.controls_by_name()["palette row Castle"] as Button).get_global_rect().get_center())
	var tile: Button = await _in_sight(_tile_keyed("3010/15"))
	if tile != null:
		await _right_click(tile.get_global_rect().get_center())
	_check("a right-click on a palette's part keeps it in Favourites too (%s)" % [PartShelf.favourites()],
		PartShelf.favourites().has("3010") and tile != null
		and (tile.get_meta("star") as Control).visible)
	tile = await _in_sight(_tile_keyed("3010/15"))
	if tile != null:
		await _right_click(tile.get_global_rect().get_center())
	_check("...and a second takes it out again", PartShelf.favourites() == before)


# -- two windows ---------------------------------------------------------------------


## Another window's changes and this one's, in one file, nothing lost.
func _two_windows() -> void:
	print("")
	print("  two windows changing palettes")
	var castle: Dictionary = _palette_named("Castle")
	# Another window keeps Harbour and a part in Castle: its own write.
	var theirs: Array = _file_palettes()
	var gone_before: PackedStringArray = _file_gone()
	for one: Dictionary in theirs:
		if str(one["name"]) == "Castle":
			(one["entries"] as Array).append({"id": "elsewhere1", "part": "3005", "colour": 4})
	theirs.append({"id": "harbour1", "name": "Harbour", "named": 1, "entries": [
		{"id": "elsewhere2", "part": "3002", "colour": 1}]})
	await _write_file(theirs, gone_before)
	# This window keeps the part in hand: chosen from All, in yellow.
	await _click(_chip("All").get_global_rect().get_center())
	await _type("3070b")
	var tile: Button = await _tile_of("3070b")
	if tile != null:
		await _click(tile.get_global_rect().get_center())
	_bin.choose_colour(14)
	await _key(KEY_ESCAPE)
	await _click(_named("palettes").get_global_rect().get_center())
	await _click((_bin.controls_by_name()["palette row Castle"] as Button).get_global_rect().get_center())
	await _from_add(ADD_HELD)
	var names: Array = _file_names()
	var pairs: Array = _pairs_of(_file_palette("Castle"))
	_check("another window's Harbour and its part in Castle kept beside this one's 3070b: %s, Castle %d entries"
		% [names, (_file_palette("Castle").get("entries", []) as Array).size()],
		names == ["Castle", "Harbour"] and pairs.has(["3005", 4]) and pairs.has(["3070b", 14]))
	await _until(func() -> bool: return _rows().is_empty() and _part_tiles().size() == 14, 200)
	_check("...and this window shows them: Castle's %d parts" % _part_tiles().size(), _part_tiles().size() == 14)

	# An older copy stored over this one's, as a tab's copy arrives late.
	var older: Array = _file_palettes()
	for one: Dictionary in older:
		if str(one["name"]) == "Castle":
			one["entries"] = (one["entries"] as Array).filter(func(e: Dictionary) -> bool:
				return str(e.get("part", "")) != "3070b")
	older.append({"id": "moat1", "name": "Moat", "named": 2, "entries": []})
	await _write_file(older, _file_gone())
	var restored: bool = await _until_seconds(func() -> bool:
		var file_pairs: Array = _pairs_of(_file_palette("Castle"))
		return file_pairs.has(["3070b", 14]) and _file_names().has("Moat"), 3.0)
	_check("an older copy stored over this window's: its 3070b written back, and Moat kept: %s"
		% [_file_names()], restored)

	# Another window takes 3005 out.
	var taken: Array = _file_palettes()
	for one: Dictionary in taken:
		if str(one["name"]) == "Castle":
			one["entries"] = (one["entries"] as Array).filter(func(e: Dictionary) -> bool:
				return str(e.get("id", "")) != "elsewhere1")
	var gone: PackedStringArray = _file_gone()
	gone.append("elsewhere1")
	await _write_file(taken, gone)
	await _until_seconds(func() -> bool: return _tile_keyed("3005/4") == null, 3.0)
	await _from_add(ADD_HELD)
	_check("what another window took out stays out, here and in the file",
		_tile_keyed("3005/4") == null and not _pairs_of(_file_palette("Castle")).has(["3005", 4]))
	await _shot("two_windows")
	castle = _palette_named("Castle")
	_check("Castle has the gatepost still", not _assembly_of(castle, "Gatepost").is_empty())
	await _later_build()


## After an update a tab left open runs the old build beside the new one, on
## the same file: what the later build wrote, this one keeps. And a file that
## cannot be read is kept beside it before a change writes over it.
func _later_build() -> void:
	print("")
	print("  a later build's palettes, and a damaged file")
	var later: Array = _file_palettes()
	for one: Dictionary in later:
		if str(one["name"]) == "Castle":
			one["shared"] = "with the club"
			(one["entries"] as Array).append({"id": "later1", "set": "10497-1", "count": 2})
			for entry: Dictionary in one["entries"]:
				if str(entry.get("part", "")) == "3001":
					entry["note"] = "for the gate"
	await _write_file(later, _file_gone())
	await create_timer(1.5).timeout
	var tiles: int = _part_tiles().size()
	_check("a later build's entry of a kind this one does not know is not shown: %d parts, \"%s\""
		% [tiles, _status()], tiles == 13 and _status().begins_with("13 parts, 1 sub-assembly"))
	await _rename_by_typing("Castle walls")
	var walls: Dictionary = _file_palette("Castle walls")
	var whole: bool = false
	var note: String = ""
	for entry: Dictionary in walls.get("entries", []):
		if str(entry.get("id", "")) == "later1":
			whole = entry == {"id": "later1", "set": "10497-1", "count": 2}
		if str(entry.get("part", "")) == "3001":
			note = str(entry.get("note", ""))
	_check("renamed here, Castle walls keeps all a later build wrote: its entry %s, its \"shared\" (%s), 3001's note (%s)"
		% ["whole" if whole else "lost", walls.get("shared", "lost"), note if not note.is_empty() else "lost"],
		whole and str(walls.get("shared", "")) == "with the club" and note == "for the gate")

	await create_timer(1.1).timeout
	var damaged: String = "[palettes]\nlist=[{\n"
	var file := FileAccess.open(PALETTES_FILE, FileAccess.WRITE)
	file.store_string(damaged)
	file.close()
	await create_timer(1.5).timeout
	await _rename_by_typing("Castle")
	var aside: String = FileAccess.get_file_as_string(PALETTES_FILE + ".unreadable")
	var castle: Dictionary = _file_palette("Castle")
	_check("a damaged file: kept beside it as it was (%d bytes), and this window's palettes written: %s, Castle %d entries"
		% [aside.length(), _file_names(), (castle.get("entries", []) as Array).size()],
		aside == damaged and _file_names() == ["Castle", "Harbour", "Moat"]
		and (castle.get("entries", []) as Array).size() == 15)


## The open palette renamed as a person does: its name in the line chosen
## and typed over, then Return.
func _rename_by_typing(name: String) -> void:
	var field: LineEdit = _named("palette name")
	await _click(field.get_global_rect().get_center())
	await _key(KEY_A, true)
	await _type_keys(name)
	await _key(KEY_ENTER)
	await _frames(4)


# -- Techniques, scrolled ----------------------------------------------------------


## Scrolled to its end after a search, a list of rows has rows only: the
## search's tiles came in under them as the grid grew.
func _techniques_scrolled() -> void:
	print("")
	print("  Techniques and Palettes scrolled to their ends")
	await _click(_chip("All").get_global_rect().get_center())
	await _type("brick")
	await _click(_chip("Techniques").get_global_rect().get_center())
	var scroll: ScrollContainer = _bin.get("_scroll")
	for _n: int in 40:
		scroll.scroll_vertical += 400
		await _frames(3)
	var stray: int = 0
	for child: Node in (_bin.get("_grid") as GridContainer).get_children():
		if child.has_meta("part"):
			stray += 1
	_check("Techniques at its end: %d part tiles among its rows" % stray, stray == 0)
	await _click(_named("palettes").get_global_rect().get_center())
	for _n: int in 10:
		scroll.scroll_vertical += 400
		await _frames(3)
	stray = 0
	for child: Node in (_bin.get("_grid") as GridContainer).get_children():
		if child.has_meta("part"):
			stray += 1
	_check("Palettes at its end: %d part tiles among its rows" % stray, stray == 0)
	await _click(_chip("All").get_global_rect().get_center())


# -- what the bin and the file hold ----------------------------------------------------


func _palette_named(name: String) -> Dictionary:
	if _shelf.get("palettes_file") == null:
		return {}
	for one: Dictionary in _shelf.call("palettes"):
		if str(one["name"]) == name:
			return one
	return {}


func _names() -> Array:
	if _shelf.get("palettes_file") == null:
		return []
	return (_shelf.call("palettes") as Array).map(func(one: Dictionary) -> String: return str(one["name"]))


func _pairs_of(one: Dictionary) -> Array:
	var out: Array = []
	for entry: Dictionary in one.get("entries", []):
		if entry.has("part"):
			out.append([str(entry["part"]), int(entry["colour"])])
	return out


func _assembly_of(one: Dictionary, name: String) -> Dictionary:
	for entry: Dictionary in one.get("entries", []):
		if entry.has("ldraw") and str(entry["name"]) == name:
			return entry
	return {}


func _same_pairs(got: Array, wanted: Array) -> bool:
	if got.size() != wanted.size():
		return false
	for pair: Array in wanted:
		if not got.has([str(pair[0]), int(pair[1])]):
			return false
	return true


func _file_palettes() -> Array:
	var file := ConfigFile.new()
	if file.load(PALETTES_FILE) != OK:
		return []
	return (file.get_value("palettes", "list", []) as Array).duplicate(true)


func _file_gone() -> PackedStringArray:
	var file := ConfigFile.new()
	if file.load(PALETTES_FILE) != OK:
		return PackedStringArray()
	return PackedStringArray(file.get_value("palettes", "gone", PackedStringArray()))


func _file_names() -> Array:
	return _file_palettes().map(func(one: Dictionary) -> String: return str(one["name"]))


func _file_palette(name: String) -> Dictionary:
	for one: Dictionary in _file_palettes():
		if str(one["name"]) == name:
			return one
	return {}


## Written as another window writes it, a second on so its time differs.
func _write_file(palettes: Array, gone: PackedStringArray) -> void:
	await create_timer(1.1).timeout
	var file := ConfigFile.new()
	file.set_value("palettes", "list", palettes)
	file.set_value("palettes", "gone", gone)
	file.save(PALETTES_FILE)


## The part tiles of the palette open: [[part, colour], ...].
func _part_tiles() -> Array:
	var out: Array = []
	for child: Node in (_bin.get("_grid") as GridContainer).get_children():
		var key: String = str(child.get_meta("key", ""))
		if child.has_meta("part") and child.has_meta("entry") and key.contains("/"):
			out.append([key.get_slice("/", 0), int(key.get_slice("/", 1))])
	return out


func _tile_keyed(key: String) -> Button:
	for child: Node in (_bin.get("_grid") as GridContainer).get_children():
		if str(child.get_meta("key", "")) == key and child.has_meta("part"):
			return child
	return null


## [param control] scrolled into the bin's sight, as a person scrolls to it.
func _in_sight(control: Control) -> Control:
	if control != null:
		(_bin.get("_scroll") as ScrollContainer).ensure_control_visible(control)
		await _frames(4)
	return control


func _rows() -> Array:
	var out: Array = []
	for child: Node in (_bin.get("_grid") as GridContainer).get_children():
		if child.has_meta("palette_name"):
			out.append(str(child.get_meta("palette_name")))
	return out


func _status() -> String:
	return (_bin.get("_status") as Label).text


func _last_said() -> String:
	return _said.back() if not _said.is_empty() else ""


func _chip(category: String) -> Button:
	for child: Node in (_bin.get("_category_row") as FlowContainer).get_children():
		if str(child.get_meta("category", "")) == category:
			return child
	return null


func _beside_favourites(chip: Button) -> bool:
	var at: int = chip.get_index()
	return at >= 1 and str(chip.get_parent().get_child(at - 1).get_meta("category", "")) == "Favourites"


func _named(name: String) -> Control:
	return _bin.controls_by_name().get(name)


## Each tile's picture drawn, a few seconds at most.
func _pictures_drawn() -> void:
	await _until(func() -> bool:
		for child: Node in (_bin.get("_grid") as GridContainer).get_children():
			if not child.has_meta("tile"):
				continue
			var tile: ThumbTile = child.get_meta("tile")
			if tile.state != ThumbTile.State.READY or tile.texture == null:
				return false
		return true, 600)


## Add pressed, and its row chosen, as a person chooses it.
func _from_add(row: int) -> void:
	var add: MenuButton = _named("palette add")
	await _click(add.get_global_rect().get_center())
	var popup: PopupMenu = add.get_popup()
	var at: int = popup.get_item_index(row)
	_check("Add opens, its row \"%s\" there to choose" % popup.get_item_text(at),
		popup.visible and at >= 0 and not popup.is_item_disabled(at))
	popup.id_pressed.emit(row)
	popup.hide()
	await _frames(10)


# -- the model ---------------------------------------------------------------------


func _put(part: String, colour: int, at: Vector3) -> int:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)
	return brick_id


func _select(ids: Array) -> void:
	_builder.selection.clear()
	for brick_id: Variant in ids:
		_builder.selection[int(brick_id)] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


## Each brick's part, colour, turn and place from the first, sorted.
func _post_shape(bricks: Array) -> Array:
	var sorted: Array = bricks.duplicate()
	sorted.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return a.transform.origin.y < b.transform.origin.y)
	var out: Array = []
	if sorted.is_empty():
		return out
	var first: Vector3 = (sorted[0] as BrickWorld.Brick).transform.origin
	for brick: BrickWorld.Brick in sorted:
		out.append([brick.part_id, brick.color_code, brick.transform.basis, brick.transform.origin - first])
	return out


func _same_shape(a: Array, b: Array) -> bool:
	if a.size() != b.size() or a.is_empty():
		return false
	for n: int in a.size():
		if a[n][0] != b[n][0] or a[n][1] != b[n][1]:
			return false
		if not (a[n][2] as Basis).is_equal_approx(b[n][2]):
			return false
		if ((a[n][3] as Vector3) - (b[n][3] as Vector3)).length() > 0.01:
			return false
	return true


## The pointer moved over the baseplate until what is held can go down.
func _somewhere_free() -> Vector2:
	var middle: Vector2 = _camera.unproject_position(Vector3(0, 0, 0))
	for dy: int in range(-60, 61, 10):
		for dx: int in range(-60, 61, 10):
			var at: Vector2 = middle + Vector2(dx, dy)
			await _move(at)
			if _builder.can_place():
				return at
	return Vector2.INF


# -- the window, as a person uses it --------------------------------------------


## Typed into the search, as bin2_probe types.
func _type(text: String) -> void:
	var search: LineEdit = _bin.controls_by_name()["part search"]
	search.text = text
	search.text_changed.emit(text)
	await create_timer(float(PartsBin.SEARCH_DEBOUNCE) / 1000.0 + 0.1).timeout
	await _until(func() -> bool: return not _busy(), 600)
	await _frames(8)


## Keys typed into whatever has the keys.
func _type_keys(text: String) -> void:
	for letter: String in text:
		var code: int = letter.to_upper().unicode_at(0)
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = code as Key
			event.physical_keycode = code as Key
			event.unicode = letter.unicode_at(0)
			event.shift_pressed = letter != letter.to_lower()
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


func _busy() -> bool:
	return int(_bin.get("_seeking")) >= 0 or bool(_bin.get("_pending")) or bool(_bin.get("_waiting"))


## The tile of [param part], scrolled into sight; null when it is not listed.
func _tile_of(part: String) -> Button:
	var grid: GridContainer = _bin.get("_grid")
	var scroll: ScrollContainer = _bin.get("_scroll")
	for cell: Node in grid.get_children():
		if str(cell.get_meta("part", "")) == part:
			scroll.ensure_control_visible(cell)
			await _frames(4)
			return cell
	return null


func _click(at: Vector2) -> void:
	await _move(at)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at).floor()
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(6)


func _right_click(at: Vector2) -> void:
	await _move(at)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = down
		event.position = _as_event(at).floor()
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _until(done: Callable, most: int = 600) -> bool:
	for _n: int in most:
		if done.call():
			return true
		await process_frame
	return bool(done.call())


func _until_seconds(done: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if done.call():
			return true
		await process_frame
	return bool(done.call())


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(10)
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://shots/palettes/%s_%s.png" % [name, _tag])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


## Whether user:// is this run's own (probe.sh's XDG_DATA_HOME), never the
## person's.
func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _put_back_autosave() -> void:
	if _had_autosave:
		var file: FileAccess = FileAccess.open(ModelStore.autosave(), FileAccess.WRITE)
		if file != null:
			file.store_buffer(_autosave)
			file.close()
	elif FileAccess.file_exists(ModelStore.autosave()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ModelStore.autosave()))
