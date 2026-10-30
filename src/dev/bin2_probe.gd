## The parts bin by colour, and the obvious part in one action (docs/APP_UX2.md,
## bin2).
##
##   godot --path . --resolution 1280x720 --script src/dev/bin2_probe.gd
##
## Studio hides the parts not made in the colour chosen and shows or hides
## printed parts at a button; LDCad replaces the selection with a part
## double-clicked in its bin; Bricksmith's Insert Related adds the part that
## goes on the selection in one command. Brickworks' bin did none of them, had
## no list view, and "1x4 brick" listed two Spring Shooters among its first
## eight tiles (appux2, 2026-10-30). The app is opened as a person opens it,
## the bin out, and everything is done through the window:
##
## * Sand Green chosen and "Only parts made in it" ticked: every tile in sight,
##   24 or more, is a part the catalogue has in Sand Green (its own colours or
##   another mould's), where before the tick some were not;
## * a part's prints opened under it, one click on Prints hides every printed
##   and stickered tile and every count of them folded, and leaves its plain
##   parts;
## * List: 20 rows or more in sight, each its part's name, number, size and
##   the colours it was made in, and a click on one takes its part;
## * three 1 x 2 bricks selected, a double-click on the masonry brick's tile
##   swaps all three where they stand: one action, one step to undo, the Select
##   tool back with the three selected;
## * a Technic beam selected and Fits chosen, a double-click on the pin's tile
##   puts a pin in one of its holes, joined to it as a real pin is (Joints), one
##   action and one step; a second double-click, a second pin in another hole;
## * "1x4 brick" typed: the first eight tiles are all bricks.
##
## Also at 1400 x 900 (PROBE_SIZE=1400x900). Pictures go to shots/bin2/.
extends SceneTree

const SAND_GREEN := 378
## Wedges: half the first 24 are not made in Sand Green, and 53 are.
const SAND_GREEN_ASKED := "wedge"
const BRICK := "3004"
## Brick 1 x 2 with Embossed Bricks, "masonry" as builders say.
const MASONRY := "98283"
const BEAM := "32316"
const PIN := "2780"
## The bar's least: tiles in sight at 1280 x 720, and the list's rows.
const TILES_LEAST := 24
const ROWS_LEAST := 20

var _failures: int = 0
var _main: Node
var _bin: PartsBin
var _builder: Builder
var _world: BrickWorld
var _library: PartLibrary
var _camera: CadCamera
var _verbs: EditVerbs
var _tag: String = ""
var _acts: int = 0
var _autosave: PackedByteArray = PackedByteArray()
var _had_autosave: bool = false


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
	# The app opens and autosaves this machine's own model: put back as it was.
	_had_autosave = FileAccess.file_exists(ModelStore.autosave())
	if _had_autosave:
		_autosave = FileAccess.get_file_as_bytes(ModelStore.autosave())
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
	_verbs = _main.get("_verbs")
	(_main.get("_bin_dock") as SideDock).set_open(true)
	await create_timer(SideDock.SLIDE_SECONDS * 2.0).timeout
	await _frames(30)
	var size: Vector2i = DisplayServer.window_get_size()
	_tag = "%dx%d" % [size.x, size.y]
	print("  the parts bin in a %s window" % _tag)
	await _shot("opened")

	await _by_colour()
	await _prints()
	await _list()
	await _replace()
	await _fits()
	await _family()

	_put_back_autosave()
	print("")
	print("bin2 probe: the bin by colour, and the obvious part in one action" if _failures == 0
		else "bin2 probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


## Sand Green, then "Only parts made in it": every tile in sight made in it.
func _by_colour() -> void:
	print("")
	print("  \"%s\" typed, Sand Green chosen, then only the parts made in it" % SAND_GREEN_ASKED)
	_bin.show_category("All")
	await _type(SAND_GREEN_ASKED)
	_bin.choose_colour(SAND_GREEN)
	await _frames(10)
	var before: Array = _not_made(_in_sight())
	var only: CheckBox = _bin.controls_by_name()["only made in it"]
	_check("\"%s\" is on the colour panel, in sight" % only.text, only.is_visible_in_tree()
		and _on_screen(only))
	await _click(only.get_global_rect().get_center())
	await _frames(10)
	var sight: Array = _in_sight()
	var wrong: Array = _not_made(sight)
	print("    before the tick, %d of the tiles in sight were not made in Sand Green (%s)"
		% [before.size(), ", ".join(PackedStringArray(before.slice(0, 6)))])
	print("    they read: %s" % " | ".join(_bin.tile_names(8)))
	_check("ticked: %d tiles in sight, %d of them not made in Sand Green (24 or more, none)"
		% [sight.size(), wrong.size()], sight.size() >= TILES_LEAST and wrong.is_empty()
		and not before.is_empty())
	var status: Label = _bin.get("_status")
	_check("the status line says so: \"%s\"" % status.text.get_slice("\n", 0),
		status.text.contains("made in Sand Green"))
	await _shot("made_in_sand_green")
	# The whole catalogue, the search cleared: still none but Sand Green's.
	await _type("")
	sight = _in_sight()
	wrong = _not_made(sight)
	_check("the search cleared: %d tiles in sight, %d of them not made in Sand Green"
		% [sight.size(), wrong.size()], sight.size() >= TILES_LEAST and wrong.is_empty())
	# Red: the parts listed again for it.
	_bin.choose_colour(4)
	await _frames(6)
	_check("Red chosen, the parts made in Red are listed: \"%s\"" % status.text.get_slice("\n", 0),
		status.text.contains("made in Red") and _in_sight().size() >= TILES_LEAST)
	await _click(only.get_global_rect().get_center())
	await _frames(6)
	_check("cleared, the bin is every part again (%d tiles in sight)" % _in_sight().size(),
		not only.button_pressed and _in_sight().size() >= TILES_LEAST)


## A part's prints opened under it, then Prints cleared: no printed tile left.
func _prints() -> void:
	print("")
	print("  \"tile 1x2\", its prints opened, then Prints cleared")
	await _type("tile 1x2")
	var first: Button = _grid().get_child(0)
	var part: String = str(first.get_meta("part"))
	var badge: Button = null
	for inner: Node in first.get_children():
		if inner is Button:
			badge = inner
	_check("its first tile, %s, has prints folded under it (%s)" % [first.get_meta("part"),
		badge.text if badge != null else "none"], badge != null)
	if badge != null:
		await _click(badge.get_global_rect().get_center())
		await _frames(10)
	var printed_before: int = _printed_tiles()
	var folded_before: int = _printed_folded()
	print("    %d printed tiles in the list, %d more folded" % [printed_before, folded_before])
	await _shot("prints_shown")
	var prints: CheckBox = _bin.controls_by_name()["prints"]
	_check("Prints is at the bin's foot, in sight", prints.is_visible_in_tree() and _on_screen(prints))
	_acts = 0
	await _click(prints.get_global_rect().get_center())
	await _frames(10)
	var plain: PackedStringArray = _bin.first_found(4)
	_check("one click (%d): %d printed tiles and %d folded become none (%d and %d)"
		% [_acts, printed_before, folded_before, _printed_tiles(), _printed_folded()],
		_acts == 1 and printed_before > 0 and _printed_tiles() == 0 and _printed_folded() == 0)
	_check("the plain parts stay, %s first: %s" % [part, ", ".join(plain)],
		not plain.is_empty() and plain[0] == part)
	await _shot("prints_hidden")
	await _click(prints.get_global_rect().get_center())
	await _frames(6)


## List: twenty rows and more, each the part's name, number, size and colours.
func _list() -> void:
	print("")
	print("  the bin as a list")
	await _type("")
	_bin.show_category("All")
	var list: Button = _bin.controls_by_name()["list"]
	_check("List is at the bin's foot, in sight", list.is_visible_in_tree() and _on_screen(list))
	await _click(list.get_global_rect().get_center())
	await _frames(12)
	var scroll: ScrollContainer = _bin.get("_scroll")
	var view: Rect2 = scroll.get_global_rect().grow(0.5)
	var rows: Array[Button] = []
	for cell: Node in _grid().get_children():
		if cell is Button and view.encloses((cell as Button).get_global_rect()):
			rows.append(cell)
	var told: int = 0
	var shown := PackedStringArray()
	for row: Button in rows:
		var info: PartLibrary.PartInfo = _library.parts[str(row.get_meta("part"))]
		var words := PackedStringArray()
		for label: Node in row.find_children("*", "Label", true, false):
			words.append((label as Label).text)
		var studs: Vector2i = info.footprint_studs()
		var colours: String = "" if info.colors.is_empty() else Counted.of(info.colors.size(), "colour")
		if words.size() == 4 and RegEx.create_from_string("[A-Za-z]{3}").search(words[0]) != null \
				and words[1] == info.id and words[2] == "%d×%d" % [studs.x, studs.y] \
				and words[3] == colours:
			told += 1
		if shown.size() < 5:
			shown.append(" · ".join(words))
	print("    rows read: %s" % " | ".join(shown))
	_check("%d rows in sight (%d or more)" % [rows.size(), ROWS_LEAST], rows.size() >= ROWS_LEAST)
	_check("each says its part's name, number, size and colours made (%d of %d)" % [told,
		rows.size()], told == rows.size() and told > 0)
	await _shot("list")
	if rows.size() >= 3:
		var third: Button = rows[2]
		await _click(third.get_global_rect().get_center())
		await _frames(6)
		_check("a click on a row takes its part in hand (%s, holding %s)" % [third.get_meta("part"),
			_builder.held_part], _builder.held_part == str(third.get_meta("part")))
	await _key(KEY_ESCAPE)
	await _click(list.get_global_rect().get_center())
	await _frames(8)
	_check("List again, the tiles are back (%d in sight)" % _in_sight().size(),
		_in_sight().size() >= TILES_LEAST)


## Three bricks selected, a double-click on the masonry brick's tile.
func _replace() -> void:
	print("")
	print("  three 1 x 2 bricks selected, a double-click on masonry")
	await _fresh()
	var bricks: Array[int] = []
	var places: Array[Transform3D] = []
	for x: float in [-60.0, 0.0, 60.0]:
		var at := Transform3D(Basis.IDENTITY, Vector3(x, 24.0, 10.0))
		bricks.append(_put(BRICK, 4, at))
		places.append(at)
	await _look_at(AABB(Vector3(-80, 0, -40), Vector3(180, 30, 80)))
	_bin.choose_colour(4)
	for n: int in bricks.size():
		_builder.select_brick(bricks[n], n > 0)
	await _frames(6)
	_check("the three are selected, and the bin is told (%s)" % [_bin.get("_chosen_parts")],
		_builder.selection.size() == 3 and not (_bin.get("_chosen_parts") as Dictionary).is_empty())
	await _type("masonry")
	var tile: Button = await _tile_of(MASONRY)
	_check("\"masonry\" lists %s" % MASONRY, tile != null)
	if tile == null:
		return
	var depth: int = _builder.history_depth()
	_acts = 0
	await _double_click(tile.get_global_rect().get_center())
	await _frames(10)
	var swapped: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id != MASONRY or brick.color_code != 4:
			continue
		for at: Transform3D in places:
			if brick.transform.origin.distance_to(at.origin) < 0.5:
				swapped += 1
	_check("one action (%d): the three are masonry bricks where they stood (%d of 3)"
		% [_acts, swapped], _acts == 1 and swapped == 3 and _count(BRICK) == 0)
	_check("one step to undo (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	var selected: int = 0
	for brick_id: int in _builder.selection:
		if _world.get_brick(brick_id) != null and _world.get_brick(brick_id).part_id == MASONRY:
			selected += 1
	_check("the Select tool again (%s), the three swapped selected (%d)" % [_verbs.mode, selected],
		_verbs.mode == "select" and selected == 3)
	await _shot("replaced")
	await _key(KEY_Z, true)
	await _frames(6)
	_check("Ctrl+Z puts the three 1 x 2s back (%d)" % _count(BRICK), _count(BRICK) == 3
		and _count(MASONRY) == 0)


## A beam selected, Fits, a double-click on the pin.
func _fits() -> void:
	print("")
	print("  a Technic beam selected, Fits, a double-click on the pin")
	await _fresh()
	var beam: int = _put(BEAM, 0, Transform3D(Basis.IDENTITY, Vector3(10.0, 60.0, 0.0)))
	await _look_at(AABB(Vector3(-60, 30, -40), Vector3(140, 60, 80)))
	_bin.choose_colour(0)
	_builder.select_brick(beam, false)
	await _frames(6)
	await _type("")
	var chip: Button = null
	for child: Node in (_bin.get("_category_row") as Control).get_children():
		if str(child.get_meta("category", "")) == PartsBin.FITS:
			chip = child
	await _click(chip.get_global_rect().get_center())
	await _frames(10)
	var first: PackedStringArray = _bin.first_found(5)
	_check("Fits lists what fits the beam, the pin among the first five (%s)" % ", ".join(first),
		first.has(PIN))
	var tile: Button = await _tile_of(PIN)
	if tile == null:
		return
	var depth: int = _builder.history_depth()
	_acts = 0
	await _double_click(tile.get_global_rect().get_center())
	await _frames(10)
	var pins: Array[int] = _ids_of(PIN)
	var joined: Array = _joined(pins[0]) if pins.size() == 1 else []
	_check("one action (%d): a pin, joined to the beam as a pin in its hole is (%s)"
		% [_acts, joined], _acts == 1 and pins.size() == 1 and joined.has(beam))
	_check("one step to undo (%d), the beam still selected for the next"
		% (_builder.history_depth() - depth), _builder.history_depth() == depth + 1
		and _builder.selection.has(beam) and _verbs.mode == "select")
	var status: Label = (_main.get("_shell") as Shell).bar.get("_status")
	print("    said: %s" % (status.text if status != null else ""))
	tile = await _tile_of(PIN)
	if tile != null:
		await _double_click(tile.get_global_rect().get_center())
		await _frames(10)
	pins = _ids_of(PIN)
	var apart: bool = pins.size() == 2 and _world.get_brick(pins[0]).transform.origin.distance_to(
		_world.get_brick(pins[1]).transform.origin) >= 10.0
	_check("a second double-click, a second pin in another hole (%d pins, %s)" % [pins.size(),
		"apart" if apart else "not apart"], apart and _joined(pins[1]).has(beam))
	await _look_at(AABB(Vector3(-60, 30, -40), Vector3(140, 60, 80)))
	await _shot("pins_from_fits")
	await _key(KEY_Z, true)
	await _key(KEY_Z, true)
	await _frames(6)
	_check("two Ctrl+Z take both pins off (%d)" % _ids_of(PIN).size(), _ids_of(PIN).is_empty())
	_bin.show_category("All")


## "1x4 brick" typed: bricks only in the first eight tiles.
func _family() -> void:
	print("")
	print("  \"1x4 brick\" typed")
	await _type("1x4 brick")
	var first: PackedStringArray = _bin.first_found(8)
	var names: PackedStringArray = _bin.tile_names(8)
	var bricks: int = 0
	var word := RegEx.create_from_string("\\bbrick\\b")
	for id: String in first:
		if word.search(Inventory._tidy(_library.parts[id].name).to_lower()) != null:
			bricks += 1
	print("    the first eight: %s" % " | ".join(names))
	_check("%d of the first eight tiles are bricks (8): %s" % [bricks, ", ".join(first)],
		first.size() == 8 and bricks == 8)
	await _shot("1x4_brick")
	await _type("")


# -- the window, as a person uses it --------------------------------------------


func _type(text: String) -> void:
	var search: LineEdit = _bin.controls_by_name()["part search"]
	search.text = text
	search.text_changed.emit(text)
	await create_timer(float(PartsBin.SEARCH_DEBOUNCE) / 1000.0 + 0.1).timeout
	await _frames(8)


func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _frames(3)
	await _press(at, false)
	_acts += 1


## Two presses as one double-click: the second press says so, as the window
## says it of a real one.
func _double_click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _frames(3)
	await _press(at, false)
	await _press(at, true)
	_acts += 1


func _press(at: Vector2, double: bool) -> void:
	var whole: Vector2 = _as_event(at).floor()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.double_click = double and down
		event.position = whole
		event.global_position = whole
		Input.parse_input_event(event)
		await _frames(2)


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


func _on_screen(control: Control) -> bool:
	return root.get_visible_rect().encloses(control.get_global_rect())


# -- what the bin and the model hold --------------------------------------------


func _grid() -> GridContainer:
	return _bin.get("_grid")


## The parts of the tiles wholly inside what the bin's list shows.
func _in_sight() -> Array:
	var view: Rect2 = (_bin.get("_scroll") as ScrollContainer).get_global_rect().grow(0.5)
	var out: Array = []
	for cell: Node in _grid().get_children():
		if cell is Button and cell.has_meta("part") \
				and view.encloses((cell as Button).get_global_rect()):
			out.append(str(cell.get_meta("part")))
	return out


## Of [param parts], those the catalogue does not have in [param code]: in
## none of its colours nor its other moulds'. Read here, not by the bin.
func _not_made(parts: Array, code: int = SAND_GREEN) -> Array:
	return parts.filter(func(id: String) -> bool:
		var info: PartLibrary.PartInfo = _library.parts[id]
		return not (info.colors.has(code) or info.mould_colors.has(code)))


## Printed and stickered parts folded under the list's tiles.
func _printed_folded() -> int:
	var out: int = 0
	for under: Array in (_bin.get("_folds") as Dictionary).values():
		for info: PartLibrary.PartInfo in under:
			if info.decor() != 0:
				out += 1
	return out


## Printed and stickered tiles in the list, shown or not yet scrolled to.
func _printed_tiles() -> int:
	var out: int = 0
	for info: PartLibrary.PartInfo in _bin.get("_display"):
		if info.decor() != 0:
			out += 1
	return out


## The tile of [param part], scrolled into sight; null when it is not listed.
func _tile_of(part: String) -> Button:
	for cell: Node in _grid().get_children():
		if str(cell.get_meta("part", "")) == part:
			(_bin.get("_scroll") as ScrollContainer).ensure_control_visible(cell)
			await _frames(4)
			return cell
	return null


## An empty model, the Select tool, nothing in hand.
func _fresh() -> void:
	await _key(KEY_ESCAPE)
	_main.call("clear_model")
	await _frames(6)
	_builder.forget_history()
	_builder.clear_selection()
	if _verbs.mode != "select":
		_verbs.set_mode("select")
	await _frames(4)


func _put(part: String, colour: int, at: Transform3D) -> int:
	var id: int = _world.add_brick(part, colour, at)
	_builder.register(id, part, at)
	return id


func _count(part: String) -> int:
	return _ids_of(part).size()


func _ids_of(part: String) -> Array[int]:
	var out: Array[int] = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			out.append(brick.id)
	return out


## The bricks [param brick_id] is joined to by a pin, an axle or a round.
func _joined(brick_id: int) -> Array:
	var entries: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		entries.append([brick.id, brick.transform, _library.mesh_for(brick.part_id)])
	var held: Dictionary = (Joints.both_ways(entries).get(brick_id, {}) as Dictionary).duplicate()
	held.merge(Joints.rounds(entries).get(brick_id, {}))
	return held.keys()


func _look_at(box: AABB) -> void:
	_camera.frame(box, 1.0)
	_camera.look_from(Vector3(0.35, 0.6, 0.75).normalized())
	await create_timer(1.5).timeout
	await _frames(10)


func _until(done: Callable, most: int = 600) -> bool:
	for _n: int in most:
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
	var path: String = ProjectSettings.globalize_path("res://shots/bin2/%s_%s.png" % [name, _tag])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


func _put_back_autosave() -> void:
	if _had_autosave:
		var file: FileAccess = FileAccess.open(ModelStore.autosave(), FileAccess.WRITE)
		if file != null:
			file.store_buffer(_autosave)
			file.close()
	elif FileAccess.file_exists(ModelStore.autosave()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ModelStore.autosave()))
