## Building from a set's parts (docs/APP_UX.md B10): the bin becomes one
## set's parts, by part and colour, each counting how many are left.
##
##   godot --path . --resolution 1280x720 --script src/dev/setbin_probe.gd -- --shots=DIR
##
## At 1400x900 too: PROBE_SIZE=1400x900 tools/probe.sh setbin_probe. A set's
## number typed into the search is offered on the line at the bin's top, and
## Build from it makes the bin 10497-1 Galaxy Explorer's parts. Then:
##   - the tiles are exactly the set's part-and-colour kinds (40 or more), each
##     counting the inventory's number, read from the set's own inventory;
##   - a tile taken puts its part in hand in its colour, and the part put down
##     takes one from its count and from the line's; Undo gives it back, and so
##     does Delete;
##   - a part with one in the set, put down, says "none left" and is greyed;
##     it can still be put down, and then says "1 over", as the line does;
##   - saved, the model keeps the choice; the bin put back to every part, the
##     saved model opened makes it the set's again, with what it uses counted.
## Each count is read from what the tile says, so a bin whose counts never
## changed fails at the first part put down.
extends SceneTree

const SET := "10497-1"
const TITLE := "10497-1 Galaxy Explorer"
const SAVED := "Setbin Probe"

var _failures: int = 0
var _shots: String = ""
var _main: Node
var _bin: PartsBin
var _builder: Builder
var _shell: Shell


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


## Wait until [param done] says so, for [param most] frames at most.
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
	var path: String = "%s/setbin_%s_%dx%d.png" % [_shots, name, size.x, size.y]
	root.get_texture().get_image().save_png(path)
	print("  shot  %s" % path)


## What the tile of [param key] says after its name: "×12", "none left".
func _count_on(key: String) -> String:
	var cell: Button = _cell(key)
	if cell == null:
		return "(no tile)"
	var label: Label = cell.get_meta("name_label")
	var words: String = label.text.replace("\n", " ")
	# At the end of its name, which may have a × of its own: "Plate 1×1
	# with Clip  ×3".
	var count: RegExMatch = RegEx.create_from_string("(×\\d+|none left|\\d+ over)$").search(words)
	return count.get_string(1) if count != null else words


## The model's parts, its baseplate left out.
func _down(world: BrickWorld, store: ModelStore) -> int:
	return world.brick_count() - store.scenery.size()


func _cell(key: String) -> Button:
	for cell: Node in (_bin.get("_grid") as GridContainer).get_children():
		if str(cell.get_meta("key", "")) == key:
			return cell
	return null


## The set's line at the bin's top, as it reads.
func _line() -> String:
	return (_bin.controls_by_name()["set words"] as Label).text


## Take the tile of [param key] as a click does, and put its part down at
## [param x], [param z] on the ground: the new brick's id, or 0.
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


func _run() -> void:
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
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var library: PartLibrary = _main.get("_library")
	var dock: Variant = _main.get("_bin_dock")
	if dock != null and not dock.is_open():
		dock.set_open(true)
	# An empty model on the bare ground: what is counted is what is put down here.
	world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	store.scenery.clear()
	_builder.held_color = 4
	_bin.choose_colour(4)
	await _frames(5)

	# The set's own inventory, read here, part and colour -> how many.
	var books := SetInventories.new()
	root.add_child(books)
	var found: Dictionary = await books.lookup(PackedStringArray([SET]))
	var want: Dictionary = {}
	var pieces: int = 0
	for row: Array in (found.get(SET, {}) as Dictionary).get("p", []):
		var key: String = Collection.key_of(str(row[0]), int(row[1]), library)
		var info: PartLibrary.PartInfo = library.parts.get(Collection.part_of(key))
		pieces += int(row[2])
		if info == null or not info.reachable or info.is_redirect():
			continue
		want[key] = int(want.get(key, 0)) + int(row[2])
	_check("the set's inventory has %d kinds of part and colour, 40 or more" % want.size(),
		want.size() >= 40)

	print("\na set's number typed into the search is offered")
	var search: LineEdit = _bin.controls_by_name()["part search"]
	search.text = SET
	search.text_changed.emit(SET)
	var go: Button = _bin.controls_by_name()["set build"]
	var offered: bool = await _until(func() -> bool: return go.is_visible_in_tree(), 600)
	_check("the set's line offers it: \"%s\" [%s]" % [_line(), go.text],
		offered and _line().begins_with(TITLE) and go.text == "Build from it")
	await _shot("offered")
	var began: int = Time.get_ticks_usec()
	go.pressed.emit()
	await _until(func() -> bool: return _bin.set_showing() == TITLE, 600)
	print("  (the set's bin was shown %.1f ms after Build from it)" % ((Time.get_ticks_usec() - began) / 1000.0))
	_check("the bin builds from it: \"%s\"" % _bin.set_showing(), _bin.set_showing() == TITLE)
	_check("the search is let go, so all of the set shows", search.text.is_empty())

	print("\nthe bin is exactly the set's parts by part and colour, with its counts")
	_bin.call("_show_more", 100000)
	await _frames(3)
	var shown: Dictionary = {}
	var miscounted := PackedStringArray()
	for cell: Node in (_bin.get("_grid") as GridContainer).get_children():
		var key: String = str(cell.get_meta("key", ""))
		if key.is_empty():
			continue
		shown[key] = true
		if _count_on(key) != "×%d" % int(want.get(key, -1)):
			miscounted.append("%s says %s, the set has %d" % [key, _count_on(key), int(want.get(key, -1))])
	var missing := PackedStringArray()
	for key: String in want:
		if not shown.has(key):
			missing.append(key)
	var extra := PackedStringArray()
	for key: String in shown:
		if not want.has(key):
			extra.append(key)
	_check("%d tiles, one for each of the set's %d kinds (missing %s, extra %s)" % [shown.size(),
		want.size(), ", ".join(missing.slice(0, 4)), ", ".join(extra.slice(0, 4))],
		shown.size() == want.size() and missing.is_empty() and extra.is_empty())
	_check("each tile counts what the inventory says (%d wrong%s)" % [miscounted.size(),
		": " + miscounted[0] if not miscounted.is_empty() else ""], miscounted.is_empty())
	var first: Button = _cell(_bin.counts_shown(1).keys()[0])
	var first_tile: ThumbTile = first.get_meta("tile")
	_check("a tile is drawn in its own colour: %s in %d" % [first_tile.part_id, first_tile.color_code],
		first_tile.color_code == Collection.colour_of(str(first.get_meta("key"))))
	_check("the line names the set and what is left: \"%s\"" % _line(),
		_line() == "%s: %s of %s left" % [TITLE, PartsBin._comma(pieces), PartsBin._comma(pieces)])
	await _shot("chosen")

	# A plate or a brick the set has several of, in a colour not in hand, and
	# one it has a single one of.
	var many: String = ""
	var single: String = ""
	for key: String in want:
		var info: PartLibrary.PartInfo = library.parts.get(Collection.part_of(key))
		if info.category not in ["Plate", "Brick", "Tile"]:
			continue
		if many.is_empty() and int(want[key]) >= 2 and Collection.colour_of(key) != 4:
			many = key
		if single.is_empty() and int(want[key]) == 1:
			single = key
	_check("a part it has several of (%s, %d) and one it has one of (%s)" % [many,
		int(want.get(many, 0)), single], not many.is_empty() and not single.is_empty())
	var has: int = int(want.get(many, 0))

	print("\na part put down takes one from its count; Undo and Delete give it back")
	var placed: int = await _put_down(many, 40.0, 40.0)
	_check("taking its tile puts %s in hand in its colour (%d, in hand %d)" % [many,
		Collection.colour_of(many), _builder.held_color],
		_builder.held_part == Collection.part_of(many) and _builder.held_color == Collection.colour_of(many))
	await _until(func() -> bool: return _count_on(many) != "×%d" % has, 30)
	_check("put down (brick %d), its tile says %s, one fewer than %d" % [placed, _count_on(many), has],
		placed != 0 and _count_on(many) == "×%d" % (has - 1))
	_check("...and the line: \"%s\"" % _line(), _line().contains(
		"%s of %s left" % [PartsBin._comma(pieces - 1), PartsBin._comma(pieces)]))
	_shell.run("undo")
	await _until(func() -> bool: return _count_on(many) == "×%d" % has, 60)
	_check("Undo gives it back: %s, %d parts down" % [_count_on(many), _down(world, store)],
		_count_on(many) == "×%d" % has and _down(world, store) == 0)
	placed = await _put_down(many, 40.0, 40.0)
	await _until(func() -> bool: return _count_on(many) == "×%d" % (has - 1), 60)
	_check("put down again: %s" % _count_on(many), _count_on(many) == "×%d" % (has - 1))
	_builder.select_brick(placed, false)
	_shell.run("delete")
	await _until(func() -> bool: return _count_on(many) == "×%d" % has, 60)
	_check("Delete gives it back: %s, %d parts down" % [_count_on(many), _down(world, store)],
		_count_on(many) == "×%d" % has and _down(world, store) == 0)

	print("\na part used up is greyed and still put down, and then the bin says 1 over")
	var one: int = await _put_down(single, 120.0, 40.0)
	await _until(func() -> bool: return _count_on(single) == "none left", 60)
	var single_tile: Control = _cell(single).get_meta("tile")
	(_bin.get("_scroll") as ScrollContainer).ensure_control_visible(_cell(single))
	_check("its one put down, its tile says \"%s\", greyed (%.2f)" % [_count_on(single),
		single_tile.modulate.a], one != 0 and _count_on(single) == "none left" and single_tile.modulate.a < 0.6)
	await _shot("none_left")
	var two: int = await _put_down(single, 200.0, 40.0)
	await _until(func() -> bool: return _count_on(single) == "1 over", 60)
	_check("it can still be put down (brick %d): its tile says \"%s\"" % [two, _count_on(single)],
		two != 0 and _count_on(single) == "1 over")
	_check("...and the line says so: \"%s\"" % _line(), _line().ends_with(", 1 over"))
	await _shot("over")

	print("\nthe choice is kept with the model")
	var path: String = ModelStore.saved_path(SAVED)
	_check("saved as \"%s\"" % SAVED, store.save_as(SAVED))
	var text: String = FileAccess.get_file_as_string(path)
	_check("its file keeps the set: %s" % SetBin.read(text), SetBin.read(text) == PackedStringArray([SET]))
	(_bin.controls_by_name()["all parts back"] as Button).pressed.emit()
	await _frames(3)
	_check("All parts gives back the whole library", _bin.set_showing().is_empty()
		and not (_bin.controls_by_name()["set words"] as Label).is_visible_in_tree())
	var opened: int = store.open(path)
	await _until(func() -> bool: return _bin.set_showing() == TITLE, 600)
	_bin.call("_show_more", 100000)
	await _until(func() -> bool: return _count_on(single) == "1 over", 60)
	_check("opened again (%d parts), the bin is the set's: \"%s\"" % [opened, _bin.set_showing()],
		opened == 2 and _bin.set_showing() == TITLE)
	_check("...with what the model uses counted: %s, %s" % [_count_on(single), _line()],
		_count_on(single) == "1 over" and _line().ends_with(", 1 over"))
	DirAccess.remove_absolute(path)

	if _failures == 0:
		print("setbin probe: a set's parts, counted down as they are used, kept with the model")
	else:
		print("setbin probe: %d failed" % _failures)
	quit(1 if _failures else 0)
