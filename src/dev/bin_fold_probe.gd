## A part's prints and stickers folded under its tile in the parts bin, by hand.
##
##   godot --path . --resolution 1280x860 --script src/dev/bin_fold_probe.gd
##
## "3008" listed Brick 1 x 8 and then dozens of its stickered versions,
## "Showing 120 of 315" (walk239 A13, 2026-10-24); Studio keeps a decorated
## part behind its plain one. Typed key by key into the bin's field, 3008,
## 3001, 3039 and 3069b each lead with the part itself, every print and
## sticker of it listed is folded under its tile behind a count, a click on
## the count opens them after the tile and another folds them, and typed with
## "print" or "sticker" they are listed as themselves, which is how the keys
## reach them (a field gives the keys back at Tab, FocusGuard). "window
## 1x2x3" puts the window with its glass beside the window. PROBE_SIZE=390x844 runs it in a narrow window. Pictures go to
## shots/bin_fold/, named for the window's width.
extends SceneTree

var _failures: int = 0
var _main: Node
var _bin: PartsBin
var _library: PartLibrary


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
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_library = _main.get("_library")
	_bin = _main.get("_bin")
	(_main.get("_bin_dock") as SideDock).set_open(true)
	await _frames(10)
	for _n: int in 600:
		if _library.search_ready():
			break
		await process_frame
	var width: int = DisplayServer.window_get_size().x

	for number: String in ["3008", "3001", "3039", "3069b"]:
		print("  %s" % number)
		await _search_for(number)
		var tiles: PackedStringArray = _bin.first_found(6)
		var variants: Array = _bin._folds.get(number, [])
		var listed: int = 0
		for info: PartLibrary.PartInfo in _bin._results:
			if info.print_of == number:
				listed += 1
		_check("%s is the first tile (%s)" % [number, ", ".join(tiles)],
			not tiles.is_empty() and tiles[0] == number)
		_check("none of its prints or stickers is a tile of its own", not _any_of(tiles, number))
		var badge: Button = _badge_of(number)
		_check("its tile counts what is folded under it: %s, %d listed with it"
			% [badge.text if badge != null else "no count", listed],
			badge != null and badge.text == "+%d" % variants.size() and variants.size() >= listed
			and listed > 0)
		await _shot("%d_%s_folded" % [width, number])
		if badge == null:
			continue
		# By the pointer, or a finger: the count opens them, and folds them.
		await _click(badge.get_global_rect().get_center())
		tiles = _bin.first_found(1 + variants.size())
		_check("the count opens them after it (%s, %d tiles)" % [", ".join(tiles.slice(0, 4)),
			tiles.size()], tiles.size() > 1 and tiles[0] == number and _any_of(tiles, number))
		await _shot("%d_%s_open" % [width, number])
		var again: Button = _badge_of(number)
		if again != null:
			await _click(again.get_global_rect().get_center())
		_check("and pressed again folds them", not _any_of(_bin.first_found(6), number))
		# By the keys: asked for, they are listed as themselves.
		var decor: String = "sticker" if number == "3008" else "print"
		await _search_for("%s %s" % [number, decor])
		tiles = _bin.first_found(6)
		_check("typed \"%s %s\", they are tiles of their own (%s)" % [number, decor,
			", ".join(tiles.slice(0, 4))], _any_of(PackedStringArray([""]) + tiles, number))
		await _shot("%d_%s_typed" % [width, number])

	print("  window 1x2x3")
	await _search_for("window 1x2x3")
	var tiles: PackedStringArray = _bin.first_found(3)
	_check("the window with its glass is beside the window (%s)" % ", ".join(tiles),
		tiles.size() >= 2 and tiles[0] == "60593" and tiles[1] == "60593c01")
	await _shot("%d_window_with_glass" % width)

	print("")
	if _failures == 0:
		print("bin fold: each part's prints and stickers under its tile, opened and folded, and typed")
	else:
		print("bin fold: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## The field cleared and [param text] typed into it key by key, as a person does.
func _search_for(text: String) -> void:
	var field: LineEdit = _bin.controls_by_name()["part search"]
	field.grab_focus()
	field.select_all()
	await _key(KEY_BACKSPACE)
	for n: int in text.length():
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper())
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	# The quiet the field waits for after the last key, and the tiles.
	await _frames(20)
	await create_timer(0.3).timeout
	await _frames(4)


## Whether a print or a sticker of [param number] is among [param tiles]: one
## the catalogue says is of it (PartInfo.print_of), as the bin folds by.
func _any_of(tiles: PackedStringArray, number: String) -> bool:
	for id: String in tiles.slice(1):
		var info: PartLibrary.PartInfo = _library.parts.get(id)
		if info != null and info.print_of == number:
			return true
	return false


func _badge_of(number: String) -> Button:
	for cell: Node in _bin._grid.get_children():
		if str(cell.get_meta("part", "")) != number:
			continue
		for inner: Node in cell.get_children():
			if inner is Button:
				return inner
	return null


func _click(at: Vector2) -> void:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	var spot: Vector2 = at * (window / rect)
	var motion := InputEventMouseMotion.new()
	motion.position = spot
	motion.global_position = spot
	Input.parse_input_event(motion)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = spot
		event.global_position = spot
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(4)


func _shot(name: String) -> void:
	await _frames(30)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/bin_fold/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/bin_fold/%s.png" % name)
