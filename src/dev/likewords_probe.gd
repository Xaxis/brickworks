## Like this and Fits are about the part, not the last search (docs/APP_UX4.md,
## likewords).
##
##   godot --path . --resolution 1280x720 --script src/dev/likewords_probe.gd
##
## The walk built a wall from a search for "1x4 brick", whose words stayed in
## the bin: a 2 x 4 brick clicked and Like this chosen then listed only bricks,
## eight of them prints of one curved brick each a tile of its own, and no
## 2 x 4 plate in the first twelve. Fits kept the words too. The app is opened
## as a person opens it, the bin out, and everything a person does is done
## through the window:
##
## * on an empty search a 2 x 4 brick selected and Like this chosen: its first
##   12 tiles, kept to hold the rest against;
## * "1x4 brick" typed, its 1 x 4 brick's tile clicked and a wall of four put
##   down by clicks; a 2 x 4 brick on it clicked and Like this chosen: the box
##   empty and saying what words would do, the 2 x 4 plate in the first 12,
##   the first 12 as on the empty search; no two of them the same mould,
##   printed or not (a print is its plain part's mould);
## * "curved" typed while in Like this: every tile a curved part, each one of
##   the parts like it, the curved slopes of its footprint among them, and the
##   bin's foot saying "parts like Brick 2 x 4, with “curved”";
## * All chosen: "1x4 brick" back in the box and its bricks listed; Like this
##   again starts from no words;
## * Fits the same: chosen after the search, the box empty and the first 12 as
##   on an empty search; "plate" typed narrows it to plates, said; All puts
##   "1x4 brick" back.
## At 1280 x 720, and at 1400 x 900 with PROBE_SIZE=1400x900. Pictures go to
## shots/likewords/.
extends SceneTree

const BRICK := "3001"
const PLATE := "3020"
## Brick 1 x 4: the wall's.
const WALL := "3010"
const SEARCHED := "1x4 brick"
const NARROWED := "curved"
const FITS_NARROWED := "plate"
## The curved slopes of a 2 x 4's footprint, which "curved" among the parts like
## it finds (Slope Brick Curved 4 x 2, 2 x 4 without Underside Studs).
const SLOPES: Array[String] = ["93606", "61068"]
const RED := 4

var _failures: int = 0
var _main: Node
var _bin: PartsBin
var _builder: Builder
var _world: BrickWorld
var _library: PartLibrary
var _camera: CadCamera
var _verbs: EditVerbs
var _search: LineEdit
var _status: Label
## The first tiles "1x4 brick" lists in All.
var _all_found := PackedStringArray()
var _tag: String = ""
var _autosave: PackedByteArray = PackedByteArray()
var _had_autosave: bool = false
## A print's number less what LDraw adds for its print or sticker: 3001p01,
## 973pc8, 3068bd2j, 3626cpr0001.
var _print_number := RegEx.create_from_string("^([a-z]*\\d+[a-c]?)(p|d)")


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	ShellPrefs.kept_by_a_check = _own_data_folder()
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
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
	_search = _bin.controls_by_name()["part search"]
	_status = _bin.get("_status")
	var size: Vector2i = DisplayServer.window_get_size()
	_tag = "%dx%d" % [size.x, size.y]
	(_main.get("_bin_dock") as SideDock).set_open(true)
	await create_timer(SideDock.SLIDE_SECONDS * 2.0).timeout
	await _frames(30)
	print("  the parts bin in a %s window" % _tag)

	var plain_like: PackedStringArray = await _on_an_empty_search(PartsBin.LIKE)
	var plain_fits: PackedStringArray = await _on_an_empty_search(PartsBin.FITS)
	if not plain_like.is_empty() and await _wall():
		await _like_after_a_search(plain_like)
		await _narrowed()
		await _back_to_all()
		await _fits_after_a_search(plain_fits)
	_put_back_autosave()
	print("")
	print("likewords probe: Like this and Fits are about the part, not the last search"
		if _failures == 0 else "likewords probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


## A 2 x 4 brick put down and selected, nothing typed, and [param shelf] chosen:
## its first 12 tiles, which the same after a search should be.
func _on_an_empty_search(shelf: String) -> PackedStringArray:
	print("")
	print("  on an empty search, a 2 x 4 brick selected and %s chosen" % shelf)
	await _fresh()
	await _type("")
	var brick: int = _put(BRICK, RED, Transform3D(Basis.IDENTITY, Vector3(0.0, 24.0, 0.0)))
	_builder.select_brick(brick, false)
	await _frames(4)
	await _click(_chip(shelf).get_global_rect().get_center())
	await _listed(shelf)
	var twelve: PackedStringArray = _bin.first_found(12)
	print("    its first 12: %s" % _rows(twelve))
	_check("...listed (%d)" % twelve.size(), twelve.size() == 12)
	await _click(_chip("All").get_global_rect().get_center())
	await _frames(6)
	return twelve


## "1x4 brick" typed, its tile clicked, and four put down in a row by clicks;
## a 2 x 4 brick laid on them. Whether the wall was built.
func _wall() -> bool:
	print("")
	print("  \"%s\" typed and a wall built from it" % SEARCHED)
	await _fresh()
	await _type(SEARCHED)
	_all_found = _bin.first_found(8)
	var tile: Button = await _tile_of(WALL)
	_check("\"%s\" lists the 1 x 4 brick (%s)" % [SEARCHED, ", ".join(_all_found)],
		tile != null)
	if tile == null:
		return false
	await _look_at(AABB(Vector3(-200, 0, -80), Vector3(400, 60, 160)))
	for n: int in 4:
		if not _verbs.shows_ghost():
			tile = await _tile_of(WALL)
			await _click(tile.get_global_rect().get_center())
		await _click(_camera.unproject_position(Vector3(-120.0 + 80.0 * n, 0.0, 0.0)))
	await _key(KEY_ESCAPE)
	await _frames(6)
	_check("four 1 x 4 bricks put down by hand (%d)" % _count(WALL), _count(WALL) == 4)
	_check("...and \"%s\" still in the box (\"%s\")" % [SEARCHED, _search.text],
		_search.text == SEARCHED)
	# The 2 x 4 brick on the wall's middle, its studs' height above it: what
	# is clicked next.
	var top: float = 0.0
	var middle := Vector3.ZERO
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == WALL:
			var info: PartLibrary.PartInfo = _library.parts[WALL]
			top = maxf(top, (brick.transform * info.bounds).end.y - 4.0)
			middle += brick.transform.origin / float(_count(WALL))
	_put(BRICK, RED, Transform3D(Basis.IDENTITY, Vector3(middle.x, top + 24.0, middle.z)))
	await _look_at(AABB(Vector3(-200, 0, -80), Vector3(400, 80, 160)))
	await _shot("1_wall")
	return _count(WALL) >= 1


## A click on the 2 x 4 brick in the model, a click on Like this.
func _like_after_a_search(plain: PackedStringArray) -> void:
	print("")
	print("  a 2 x 4 brick clicked, then Like this")
	var brick: BrickWorld.Brick = _one(BRICK)
	await _click(_camera.unproject_position(brick.transform.origin + Vector3(0.0, -2.0, 0.0)))
	_check("one click selects the 2 x 4 brick (%s)" % [_builder.selection.keys()],
		_builder.selection.size() == 1 and _builder.selection.has(brick.id))
	await _click(_chip(PartsBin.LIKE).get_global_rect().get_center())
	await _listed(PartsBin.LIKE)
	await _shot("2_like_this_after_a_search")
	_check("Like this starts from no words: the box empty (\"%s\"), saying \"%s\""
		% [_search.text, _search.placeholder_text], _search.text.is_empty()
		and _search.placeholder_text == "Narrow these parts…")
	var twelve: PackedStringArray = _bin.first_found(12)
	print("    its first 12: %s" % _rows(twelve))
	_check("...the 2 x 4 plate (%s) in its first 12 (%d)" % [PLATE, twelve.find(PLATE) + 1],
		twelve.has(PLATE))
	_check("...the first 12 as on the empty search", twelve == plain)
	var moulds: Dictionary = {}
	var twice := PackedStringArray()
	for id: String in twelve:
		var mould: String = _mould(id)
		if moulds.has(mould):
			twice.append("%s and %s (%s)" % [moulds[mould], id, mould])
		moulds[mould] = id
	_check("no two of the first 12 tiles the same mould, printed or not%s"
		% ("" if twice.is_empty() else ": " + ", ".join(twice)), twice.is_empty() and twelve.size() == 12)
	_check("...the note says what they are like: \"%s\"" % _status.text,
		_status.text.replace("×", " x ").contains("Parts like Brick 2 x 4:"))


## "curved" typed while in Like this.
func _narrowed() -> void:
	print("")
	print("  \"%s\" typed while in Like this" % NARROWED)
	await _type(NARROWED)
	await _listed(PartsBin.LIKE)
	await _shot("3_like_this_curved")
	var shown: Array = _bin.get("_display")
	var alike := PartLike.new(_library)
	var like: Dictionary = {}
	for info: PartLibrary.PartInfo in alike.like(BRICK):
		like[info.id] = true
	var not_curved := PackedStringArray()
	var not_like := PackedStringArray()
	for info: PartLibrary.PartInfo in shown:
		if not ("%s %s" % [info.name, info.also_called]).to_lower().contains("curv"):
			not_curved.append(info.id)
		if not like.has(info.id):
			not_like.append(info.id)
	var first: PackedStringArray = _bin.first_found(12)
	print("    %d tiles, the first 12: %s" % [shown.size(), _rows(first)])
	_check("every tile a curved part (%d tiles%s)" % [shown.size(),
		"" if not_curved.is_empty() else "; not: " + ", ".join(not_curved)],
		shown.size() >= 5 and not_curved.is_empty())
	_check("...each one of the parts like the 2 x 4 brick%s" % (
		"" if not_like.is_empty() else ", not: " + ", ".join(not_like)), not_like.is_empty())
	var ids: Array = shown.map(func(info: PartLibrary.PartInfo) -> String: return info.id)
	var slopes: Array = SLOPES.filter(func(id: String) -> bool: return ids.has(id))
	_check("...the curved slopes of its footprint among them (%s of %s)" % [", ".join(slopes),
		", ".join(SLOPES)], slopes.size() == SLOPES.size())
	_check("...said: \"%s\"" % _status.text, _status.text.replace("×", " x ")
		.contains("Parts like Brick 2 x 4, with “%s”" % NARROWED))
	# Like this to Fits: Fits starts from no words too.
	await _click(_chip(PartsBin.FITS).get_global_rect().get_center())
	await _listed(PartsBin.FITS)
	_check("Fits chosen from it starts from no words too (\"%s\")" % _search.text,
		_search.text.is_empty())


## All chosen: the search typed for it back.
func _back_to_all() -> void:
	print("")
	print("  All chosen")
	await _click(_chip("All").get_global_rect().get_center())
	await _until(func() -> bool: return _bin.first_found(1).size() == 1 and not _busy(), 600)
	await _frames(10)
	var first: PackedStringArray = _bin.first_found(8)
	_check("\"%s\" back in the box (\"%s\"), saying \"%s\"" % [SEARCHED, _search.text,
		_search.placeholder_text], _search.text == SEARCHED
		and _search.placeholder_text.begins_with("Search "))
	_check("...and its parts listed as they were before Like this (%s)" % _rows(first),
		first == _all_found and first.size() == 8)
	await _shot("4_all_again")
	await _click(_chip(PartsBin.LIKE).get_global_rect().get_center())
	await _listed(PartsBin.LIKE)
	_check("Like this again starts from no words (\"%s\")" % _search.text, _search.text.is_empty())
	await _click(_chip("All").get_global_rect().get_center())
	await _frames(10)


## Fits chosen after the search, and "plate" typed in it.
func _fits_after_a_search(plain: PackedStringArray) -> void:
	print("")
	print("  Fits after the search")
	_check("\"%s\" in the box before (\"%s\")" % [SEARCHED, _search.text], _search.text == SEARCHED)
	var brick: BrickWorld.Brick = _one(BRICK)
	if not _builder.selection.has(brick.id):
		await _click(_camera.unproject_position(brick.transform.origin + Vector3(0.0, -2.0, 0.0)))
	await _click(_chip(PartsBin.FITS).get_global_rect().get_center())
	await _listed(PartsBin.FITS)
	await _shot("5_fits_after_a_search")
	var twelve: PackedStringArray = _bin.first_found(12)
	print("    its first 12: %s" % _rows(twelve))
	_check("Fits starts from no words: the box empty (\"%s\")" % _search.text,
		_search.text.is_empty() and _search.placeholder_text == "Narrow these parts…")
	_check("...the first 12 as on the empty search", twelve == plain)
	await _type(FITS_NARROWED)
	await _listed(PartsBin.FITS)
	var shown: Array = _bin.get("_display")
	var others := PackedStringArray()
	for info: PartLibrary.PartInfo in shown:
		if not info.name.to_lower().contains("plate"):
			others.append(info.id)
	print("    \"%s\": %s" % [FITS_NARROWED, _rows(_bin.first_found(8))])
	_check("\"%s\" typed narrows it to plates (%d tiles%s)" % [FITS_NARROWED, shown.size(),
		"" if others.is_empty() else "; not: " + ", ".join(others)], shown.size() >= 3 and others.is_empty())
	_check("...said: \"%s\"" % _status.text, _status.text.replace("×", " x ")
		.contains("What fits Brick 2 x 4, with “%s”" % FITS_NARROWED))
	await _shot("6_fits_plate")
	await _click(_chip("All").get_global_rect().get_center())
	await _frames(10)
	_check("All puts \"%s\" back (\"%s\")" % [SEARCHED, _search.text], _search.text == SEARCHED)


# -- the window, as a person uses it --------------------------------------------


func _chip(category: String) -> Button:
	var scroll: ScrollContainer = _bin.get("_category_scroll")
	for child: Node in (_bin.get("_category_row") as Control).get_children():
		if str(child.get_meta("category", "")) == category:
			if scroll != null:
				scroll.ensure_control_visible(child)
			return child
	return null


## Typed into the search, as bin2_probe types.
func _type(text: String) -> void:
	_search.text = text
	_search.text_changed.emit(text)
	await create_timer(float(PartsBin.SEARCH_DEBOUNCE) / 1000.0 + 0.1).timeout
	await _until(func() -> bool: return not _busy(), 600)
	await _frames(8)


## Whether the bin is still working out a list.
func _busy() -> bool:
	return int(_bin.get("_seeking")) >= 0 or bool(_bin.get("_pending")) or bool(_bin.get("_waiting")) \
		or bool(_bin.get("_like_waiting"))


func _listed(shelf: String) -> void:
	await _until(func() -> bool:
		return str(_bin.get("_category")) == shelf and not _busy() and not _bin.first_found(1).is_empty(), 600)
	await _frames(8)


func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _frames(3)
	var whole: Vector2 = _as_event(at).floor()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = whole
		event.global_position = whole
		Input.parse_input_event(event)
		await _frames(2)
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


## The tile of [param part], scrolled into sight; null when it is not listed.
func _tile_of(part: String) -> Button:
	var grid: GridContainer = _bin.get("_grid")
	var scroll: ScrollContainer = _bin.get("_scroll")
	for page: int in 30:
		for cell: Node in grid.get_children():
			if str(cell.get_meta("part", "")) == part:
				scroll.ensure_control_visible(cell)
				await _frames(4)
				return cell
		var was: Vector2i = Vector2i(scroll.scroll_vertical, grid.get_child_count())
		scroll.scroll_vertical += maxi(1, int(scroll.size.y * 0.8))
		await _frames(6)
		if Vector2i(scroll.scroll_vertical, grid.get_child_count()) == was:
			break
	return null


# -- what the bin and the model hold --------------------------------------------


func _named(part: String) -> String:
	var info: PartLibrary.PartInfo = _library.parts.get(part)
	return Inventory._tidy(info.name) if info != null else part


func _rows(ids: PackedStringArray) -> String:
	var out := PackedStringArray()
	for n: int in ids.size():
		out.append("\n      %2d %s %s" % [n + 1, ids[n], _named(ids[n])])
	return "".join(out)


## The mould [param id] is: a print's or a stickered part's plain part, or its
## number less its print's; any other part its own.
func _mould(id: String) -> String:
	var info: PartLibrary.PartInfo = _library.parts.get(id)
	if info == null or info.decor() == 0:
		return id
	if not info.print_of.is_empty():
		return info.print_of
	var found: RegExMatch = _print_number.search(id)
	return found.get_string(1) if found != null else id


## An empty model, the Select tool, nothing in hand, All chosen.
func _fresh() -> void:
	await _key(KEY_ESCAPE)
	_main.call("clear_model")
	await _frames(6)
	_builder.forget_history()
	_builder.clear_selection()
	if _verbs.mode != "select":
		_verbs.set_mode("select")
	if str(_bin.get("_category")) != "All":
		await _click(_chip("All").get_global_rect().get_center())
	await _frames(4)


func _put(part: String, colour: int, at: Transform3D) -> int:
	var id: int = _world.add_brick(part, colour, at)
	_builder.register(id, part, at)
	return id


func _one(part: String) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			return brick
	return null


func _count(part: String) -> int:
	var out: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			out += 1
	return out


func _look_at(box: AABB) -> void:
	_camera.frame(box, 1.0)
	_camera.look_from(Vector3(0.0, 0.8, 0.6).normalized())
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
	var path: String = ProjectSettings.globalize_path("res://shots/likewords/%s_%s.png" % [name, _tag])
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
