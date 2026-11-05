## The parts bin's Like this: the parts of a part's footprint and kind, and a
## swap from them in three actions (docs/APP_UX.md B5).
##
##   godot --path . --resolution 1400x900 --script src/dev/likethis_probe.gd
##   tools/probe.sh likethis_phone_probe     laid out for a phone, 390 x 844
##   tools/probe.sh likethis_tablet_probe    laid out for a tablet, 1024 x 768
##
## Fits answered what goes on a part; nothing answered what could stand in its
## place, so a person swapping a 2 x 4 brick for a 2 x 4 plate, a tile or a
## printed one searched for it by name. Studio has Find alternatives and a
## Replace that offers parts of a similar size. The app is opened as a person
## opens it, the bin out, and everything is done through the window:
##
## * a Like this chip in the bin, beside Fits;
## * ten parts across kinds, written before the change and not tuned on it,
##   each put down and selected: a 2 x 4 brick, a 1 x 2 plate, a 2 x 2 tile, a
##   45 degree slope, a 1 x 1 round plate, a Technic beam, a printed minifig
##   torso, a printed tile, a wheel and a window. The first five tiles under
##   Like this are each of its footprint and kind, as a builder names them
##   (the names are printed), a printed part's own plain part first; and the
##   2 x 4 brick's Plate 2 x 4 within its first 12 tiles;
## * three actions: a click selects a 2 x 4 brick of a sub-model's step 2 in
##   the model, a click chooses Like this, a double-click on the 2 x 4 plate's
##   tile swaps it where it stood, in its colour, step and sub-model; one step
##   to undo, and the list still the brick's for the next try;
## * three selected, a double-click on the 2 x 4 tile's tile swaps all three,
##   one step to undo.
## Laid out for a finger (the phone and tablet scripts, or --phone): the chip
## is a fingertip (Phone.TARGET points) in the parts sheet, and a tap on a tile
## swaps the selection. Pictures go to shots/likethis/.
extends SceneTree

## [the part, what it is, what the first five tiles' names say: its
## footprint and kind as a builder names them].
const TEN: Array = [
	["3001", "a 2 x 4 brick", "^brick 2 x 4(?! x)\\b"],
	["3023b", "a 1 x 2 plate", "^plate 1 x 2(?! x)\\b"],
	["3068b", "a 2 x 2 tile", "^tile 2 x 2( with| without|$)"],
	["3039", "a 45 degree slope, 2 x 2", "^slope brick 45 2 x 2\\b"],
	["6141", "a 1 x 1 round plate", "^plate 1 x 1 round\\b"],
	["32523", "a Technic beam 3", "^technic beam (1 x )?3\\b"],
	["973pc8", "a printed minifig torso", "^minifig torso\\b"],
	["3069bpc1", "a printed 1 x 2 tile", "^tile 1 x 2( with| without|$)"],
	["55981", "a 14 x 18 wheel", "^wheel rim 14 x 18\\b"],
	["60592", "a 1 x 2 x 2 window", "^window 1 x 2\\b"],
]
const BRICK := "3001"
## Plate 2 x 4 and Tile 2 x 4: what a 2 x 4 brick is swapped for.
const PLATE := "3020"
const TILE := "87079"
const RED := 4
## The chip's name, as the bin says it: written out, so the probe runs on a
## bin without it and fails at the chip.
const LIKE := "Like this"
const PATH := "Wall#1"
const STEP := 2

var _failures: int = 0
var _main: Node
var _bin: PartsBin
var _builder: Builder
var _world: BrickWorld
var _library: PartLibrary
var _camera: CadCamera
var _verbs: EditVerbs
var _phone: bool = false
var _tag: String = ""
var _acts: int = 0
var _autosave: PackedByteArray = PackedByteArray()
var _had_autosave: bool = false


func _initialize() -> void:
	_run()


## "phone" or "tablet" for a script that is this one in another window
## (likethis_phone_probe, likethis_tablet_probe); "" here.
func _finger() -> String:
	return ""


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	ShellPrefs.kept_by_a_check = _own_data_folder()
	_phone = _finger() != "" or OS.get_cmdline_user_args().has("--phone")
	if _phone:
		# The layout for a finger, as a phone's or a tablet's browser gets it.
		Phone._on = 1
		Phone._wide = _finger() == "tablet"
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
	var size: Vector2i = DisplayServer.window_get_size()
	_tag = "%dx%d%s" % [size.x, size.y, ("_" + (_finger() if _finger() != "" else "phone")) if _phone else ""]
	if not _phone:
		(_main.get("_bin_dock") as SideDock).set_open(true)
		await create_timer(SideDock.SLIDE_SECONDS * 2.0).timeout
		await _frames(30)
	print("  the parts bin in a %s window%s" % [_tag, ", laid out for a finger" if _phone else ""])

	if _phone:
		await _by_finger()
	elif await _the_chip() != null:
		await _ten()
		await _swap()
	_put_back_autosave()
	print("")
	print("likethis probe: Like this lists a part's footprint and kind, and swaps from it"
		if _failures == 0 else "likethis probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


## The chip, beside Fits.
func _the_chip() -> Button:
	var chip: Button = _chip()
	var fits: Button = _chip(PartsBin.FITS)
	_check("a Like this chip in the bin's row beside Fits (%s)" % (
		"\"%s\"" % chip.text if chip != null else "none"), chip != null and fits != null
		and chip.get_index() == fits.get_index() + 1)
	if chip != null:
		_check("...in sight, the size of the chips beside it (%s, Fits %s)" % [
			chip.size, fits.size], chip.is_visible_in_tree()
			and chip.size.y >= fits.size.y - 0.5)
	return chip


func _chip(category: String = LIKE) -> Button:
	for child: Node in (_bin.get("_category_row") as Control).get_children():
		if str(child.get_meta("category", "")) == category:
			return child
	return null


## Ten parts across kinds, each put down and selected.
func _ten() -> void:
	print("")
	print("  ten parts across kinds, each put down and selected; Like this chosen for the first")
	var within: int = 0
	for n: int in TEN.size():
		var part: String = TEN[n][0]
		await _fresh()
		var id: int = _put(part, RED, Transform3D(Basis.IDENTITY, Vector3(0.0, 24.0, 0.0)))
		var asked: int = Time.get_ticks_msec()
		_builder.select_brick(id, false)
		await _frames(2)
		if n == 0:
			await _click(_chip().get_global_rect().get_center())
		var listed: bool = await _until(func() -> bool:
			return not bool(_bin.get("_like_waiting")) and str(_bin.get("_like_of")) == part \
				and not _bin.first_found(1).is_empty(), 600)
		var took: int = Time.get_ticks_msec() - asked
		var first: PackedStringArray = _bin.first_found(5)
		var wanted := RegEx.create_from_string(TEN[n][2])
		var said := PackedStringArray()
		var all: bool = listed and first.size() == 5
		for each: String in first:
			var name: String = _named(each)
			# An assembly LDraw draws whole is the part it is built on, as
			# the bin lists it beside that part: its name is often its
			# tyre's or its glass's (51377c01, a 14 x 18 rim with a tyre, is
			# "Wheel Centre Large Wide 8 Spokes with Tyre ...").
			var whole_of: String = (_library.parts[each] as PartLibrary.PartInfo).whole_of
			var judged: String = name if whole_of.is_empty() else _named(whole_of)
			said.append("%s %s%s" % [each, name, "" if whole_of.is_empty()
				else "  (built on %s %s)" % [whole_of, judged]])
			all = all and wanted.search(judged.to_lower()) != null
		var plain: PartLibrary.PartInfo = _library.parts[part].folds_under()
		if plain != null:
			all = all and first[0] == plain.id
		if all:
			within += 1
		print("  %s  %-8s %s (%d ms):" % ["ok  " if all else "FAIL", part, TEN[n][1], took])
		print("          %s" % "\n          ".join(said))
		if n == 0:
			var status: Label = _bin.get("_status")
			_check("...the bin's foot names what they are like: \"%s\"" % status.text,
				status.text.replace("×", " x ").contains("Brick 2 x 4"))
			# The swaps made most are brick, plate and tile of one footprint:
			# the plate in the first two rows, not after the rare moulds.
			var twelve: PackedStringArray = _bin.first_found(12)
			var rows := PackedStringArray()
			for at: int in twelve.size():
				rows.append("%2d %s %s" % [at + 1, twelve[at], _named(twelve[at])])
			print("        its first 12 tiles:\n          %s" % "\n          ".join(rows))
			_check("...Plate 2 x 4 (%s) within its first 12 tiles (%d)" % [PLATE, twelve.find(PLATE) + 1],
				twelve.has(PLATE))
			await _shot("brick_2x4")
	_failures += TEN.size() - within
	print("  %d of %d with their first five of their footprint and kind" % [within, TEN.size()])
	_builder.clear_selection()
	await _frames(4)


## A click selects, a click chooses Like this, a double-click swaps.
func _swap() -> void:
	print("")
	print("  three actions: a 2 x 4 brick clicked in the model, Like this, a double-click on the plate")
	await _fresh()
	_bin.show_category("All")
	# Three bricks a stud apart on the studs (a 2 x 4 is 80 LDU along x and
	# 40 across, so its middle is on a stud's edge), the middle one
	# a sub-model's, since a click on a sub-model's part selects the whole of
	# it; all three in step 2.
	var bricks: Array[int] = []
	for x: float in [-100.0, 0.0, 100.0]:
		var brick: int = _put(BRICK, RED, Transform3D(Basis.IDENTITY, Vector3(x, 24.0, 0.0)))
		if x == 0.0:
			# On the builder, not Builder: the class's own set_path is the
			# script's resource path.
			_builder.set_path(_world.get_brick(brick), PATH)
		_world.get_brick(brick).step = STEP
		bricks.append(brick)
	await _look_at(AABB(Vector3(-150, 0, -30), Vector3(300, 30, 80)))
	var middle: BrickWorld.Brick = _world.get_brick(bricks[1])
	var was: Transform3D = middle.transform
	var bottom: float = _bottom(middle)
	_acts = 0
	await _click(_camera.unproject_position(was.origin + Vector3(0.0, -2.0, 0.0)))
	_check("one click selects the middle brick (%s)" % [_builder.selection.keys()],
		_builder.selection.size() == 1 and _builder.selection.has(bricks[1]))
	await _click(_chip().get_global_rect().get_center())
	await _until(func() -> bool:
		return not bool(_bin.get("_like_waiting")) and not _bin.first_found(1).is_empty(), 600)
	await _frames(6)
	await _shot("like_this")
	var tile: Button = await _tile_of(PLATE)
	_check("Like this lists the 2 x 4 plate for it (%s)" % ", ".join(_bin.first_found(12)),
		tile != null)
	if tile == null:
		return
	var depth: int = _builder.history_depth()
	await _double_click(tile.get_global_rect().get_center())
	await _frames(10)
	var made: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == PLATE:
			made = brick
	var where: bool = made != null and Vector2(made.transform.origin.x, made.transform.origin.z) \
		.distance_to(Vector2(was.origin.x, was.origin.z)) < 0.5 and absf(_bottom(made) - bottom) < 0.5 \
		and made.transform.basis.is_equal_approx(was.basis)
	_check("three actions (%d): the brick is a 2 x 4 plate where it stood, on what it stood on (%s)"
		% [_acts, made.transform.origin if made != null else "none"], _acts == 3 and where)
	_check("...in its colour (%d), its step (%d) and its sub-model (%s)" % [
		made.color_code if made != null else -1, made.step if made != null else -1,
		Assemblies.path_of(made) if made != null else ""], made != null and made.color_code == RED
		and made.step == STEP and Assemblies.path_of(made) == PATH)
	_check("...the other two as they were (%d 2 x 4 bricks)" % _count(BRICK), _count(BRICK) == 2)
	_check("one step to undo (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	_check("the list still the brick's, for the next try (%s first)" % ", ".join(_bin.first_found(2)),
		str(_bin.get("_like_of")) == BRICK and _bin.first_found(1) == PackedStringArray([BRICK]))
	await _look_at(AABB(Vector3(-150, 0, -30), Vector3(300, 30, 80)))
	await _shot("swapped")
	await _key(KEY_Z, true)
	await _frames(6)
	var back: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == BRICK and brick.transform.origin.distance_to(was.origin) < 0.5:
			back = brick
	_check("Ctrl+Z puts the brick back, in its colour, step and sub-model (%d bricks, %d plates)"
		% [_count(BRICK), _count(PLATE)], back != null and _count(BRICK) == 3 and _count(PLATE) == 0
		and back.color_code == RED and back.step == STEP and Assemblies.path_of(back) == PATH)

	print("")
	print("  the three selected, a double-click on the tile")
	_builder.clear_selection()
	for brick: BrickWorld.Brick in _world.bricks():
		_builder.select_brick(brick.id, true)
	await _frames(6)
	tile = await _tile_of(TILE)
	if tile == null:
		_check("Like this lists the 2 x 4 tile (%s)" % ", ".join(_bin.first_found(20)), false)
		return
	depth = _builder.history_depth()
	_acts = 0
	await _double_click(tile.get_global_rect().get_center())
	await _frames(10)
	var kept: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		var path: String = PATH if absf(brick.transform.origin.x) < 0.5 else ""
		if brick.part_id == TILE and brick.color_code == RED and brick.step == STEP \
				and Assemblies.path_of(brick) == path:
			kept += 1
	_check("one action (%d): all three are 2 x 4 tiles, in red, step %d, the middle one in %s (%d of 3)"
		% [_acts, STEP, PATH, kept], _acts == 1 and kept == 3 and _count(BRICK) == 0)
	_check("one step to undo (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	await _key(KEY_Z, true)
	await _frames(6)
	_check("Ctrl+Z puts the three bricks back (%d)" % _count(BRICK), _count(BRICK) == 3)


## Laid out for a finger: the chip in the parts sheet, a fingertip, and a tap
## on a tile swaps the selection.
func _by_finger() -> void:
	var phone: PhoneShell = _main.get("_phone")
	_check("the layout for a finger is made", phone != null)
	if phone == null:
		return
	await _fresh()
	var brick: int = _put(BRICK, RED, Transform3D(Basis.IDENTITY, Vector3(0.0, 24.0, 0.0)))
	_builder.select_brick(brick, false)
	await _frames(4)
	var sheet: PhoneShell.Sheet = phone.get("_parts")
	sheet.open("half")
	await create_timer(1.0).timeout
	await _frames(20)
	var chip: Button = _chip()
	var finger: float = Phone.px(root, Phone.TARGET)
	_check("a Like this chip in the parts sheet, a fingertip (%s, %.0f wanted)" % [
		chip.size if chip != null else Vector2.ZERO, finger], chip != null
		and chip.is_visible_in_tree() and chip.size.x >= finger - 0.5 and chip.size.y >= finger - 0.5)
	if chip == null:
		return
	_acts = 0
	await _chip_in_sight(chip)
	await _tap(chip.get_global_rect().get_center())
	await _until(func() -> bool:
		return not bool(_bin.get("_like_waiting")) and not _bin.first_found(1).is_empty(), 600)
	await _frames(6)
	await _shot("phone_like_this")
	var tile: Button = await _tile_of(PLATE)
	_check("Like this lists the 2 x 4 plate (%s)" % ", ".join(_bin.first_found(12)), tile != null)
	if tile == null:
		return
	var depth: int = _builder.history_depth()
	await _tap(tile.get_global_rect().get_center())
	await _frames(10)
	_check("a tap on its tile swaps the brick for it (%d taps, %d plates, %d bricks), one step to undo"
		% [_acts, _count(PLATE), _count(BRICK)], _acts == 2 and _count(PLATE) == 1
		and _count(BRICK) == 0 and _builder.history_depth() == depth + 1)
	_check("...the sheet still open for the next (%s)" % sheet.state, sheet.is_open())
	await _shot("phone_swapped")


# -- the window, as a person uses it --------------------------------------------


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


## A finger down and up where it is.
func _tap(at: Vector2) -> void:
	var whole: Vector2 = _as_event(at).floor()
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = whole
		Input.parse_input_event(touch)
		await _frames(3)
	_acts += 1


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


# -- what the bin and the model hold --------------------------------------------


func _named(part: String) -> String:
	var info: PartLibrary.PartInfo = _library.parts.get(part)
	return Inventory._tidy(info.name) if info != null else part


## The tile of [param part], scrolled into sight; null when it is not listed.
## The list is scrolled on, as a finger or the wheel scrolls it, until the
## tile is made: the bin makes its first 32 and the rest as they come in sight.
func _tile_of(part: String) -> Button:
	var grid: GridContainer = _bin.get("_grid")
	var scroll: ScrollContainer = _bin.get("_scroll")
	for page: int in 60:
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


## A chip in sight in the row of chips, which scrolls: a tablet's column
## shows one row of them, the rest a flick away.
func _chip_in_sight(chip: Button) -> void:
	(_bin.get("_category_scroll") as ScrollContainer).ensure_control_visible(chip)
	await _frames(4)


## The underside of a brick's box, where it stands.
func _bottom(brick: BrickWorld.Brick) -> float:
	var info: PartLibrary.PartInfo = _library.parts[brick.part_id]
	return (brick.transform * info.bounds).position.y


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
	var out: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			out += 1
	return out


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
	var path: String = ProjectSettings.globalize_path("res://shots/likethis/%s_%s.png" % [name, _tag])
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
