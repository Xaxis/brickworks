## The words a person means find the part (docs/APP_UX6.md, words6).
##
##   godot --path . --resolution 1400x900 --script src/dev/words6_probe.gd
##
## The app opened as a person opens it, the bin out, everything done through
## the window and over MCP as a session asks (CommandSocket.answer_rpc):
##
## * "plate 1 x 1" and "1x1 plate" typed into the bin list 3024, Plate 1 x 1,
##   first, where 6141, Plate 1 x 1 Round, led for its use in more sets; and
##   search_parts puts it first too;
## * the walk's 30 words (docs/app_ux6/appux_walk.gd) put the part they put
##   first on pre261 first still, in the bin and over MCP alike; the three
##   whose wanted part is not first (jumper, macaroni, bracket) list it no
##   lower than they did;
## * a tile's tooltip says the studs on top, not its box: 87087 "1 x 1, a stud
##   on one side", 4733 "1 x 1, studs on four sides", 30414 "4 x 1, studs on
##   one side", where they read 1 x 2, 2 x 2 and 4 x 2; and a brick's height
##   as a brick, a plate's as a plate (they read "4 plates" and "2 plates");
##   the same as a screen reader says it, and in the bin's list of rows;
## * F1's keys sheet, "cut away" typed into its box: the rows of the box, the
##   sphere and the cylinder kept, each saying what it cuts away by.
##
## At 1400 x 900, and at 1280 x 720 with PROBE_SIZE=1280x720. Pictures go to
## shots/words6/. Look at them.
extends SceneTree

## The walk's 30 words, each with the part pre261 lists first for it in the
## bin (appux6's walk, 2026-11-07) and the part the walk wants, with the place
## pre261 lists it at where that is not first.
const WALK: Array = [
	["2x4", "3001"], ["brick 2x4", "3001"], ["2 x 4 brick", "3001"], ["1x2 plate", "3023b"],
	["plate 2x2", "3022"], ["3001", "3001"], ["300121", "3001"], ["slope 45 2x2", "3039"],
	["cheese slope", "54200"], ["tile 1x2", "3069b"], ["grille", "2412b"],
	["jumper", "15573", "3794b", 6], ["headlight", "4070"], ["round 1x1", "6141"],
	["hinge", "3937"], ["clip", "15712"], ["technic pin", "2780"], ["axle 4", "3705"],
	["liftarm 7", "32524"], ["beam 7", "32524"], ["window", "60592"], ["door", "60596"],
	["wheel", "6014b"], ["minifig head", "3626c"], ["torso", "973"],
	["macaroni", "27925", "25269", 14], ["snot", "4070"], ["bracket", "44728", "99781", 4],
	["log", "30136"], ["arch", "3659"],
]
## What a person means by these: the plain 1 x 1 plate.
const PLATE_WORDS: Array[String] = ["plate 1 x 1", "1x1 plate"]
const PLATE := "3024"
## Each part's tile's size line, as its tooltip says it.
const SIZES: Dictionary = {
	"87087": "1 x 1, a stud on one side, 1 brick",
	"4733": "1 x 1, studs on four sides, 1 brick",
	"30414": "4 x 1, studs on one side, 1 brick",
	"3001": "4 x 2 studs, 1 brick",
	"3024": "1 x 1 studs, 1 plate",
}
## The cut shapes' rows on the keys sheet, by what each says.
const CUT_ROWS: Array[String] = ["cut away by a box", "cut away by a sphere",
	"cut away by a cylinder"]

var _failures: int = 0
var _main: Node
var _bin: PartsBin
var _library: PartLibrary
var _search: LineEdit
var _socket: CommandSocket
var _tag: String = ""
var _autosave: PackedByteArray = PackedByteArray()
var _had_autosave: bool = false
var _next: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	ShellPrefs.kept_by_a_check = _own_data_folder()
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("  words6 probe: needs a window")
		quit(1)
		return
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
	_library = _main.get("_library")
	_search = _bin.controls_by_name()["part search"]
	var size: Vector2i = DisplayServer.window_get_size()
	_tag = "%dx%d" % [size.x, size.y]
	(_main.get("_bin_dock") as SideDock).set_open(true)
	await create_timer(SideDock.SLIDE_SECONDS * 2.0).timeout
	await _frames(30)
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	print("  the parts bin in a %s window" % _tag)

	await _plate_words()
	await _walk_words()
	await _tooltips()
	await _keys_sheet()

	_socket.queue_free()
	_put_back_autosave()
	print("")
	print("words6 probe: the words a person means find the part"
		if _failures == 0 else "words6 probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


# -- the search ---------------------------------------------------------------------


## "plate 1 x 1" and "1x1 plate", in the bin and over MCP: Plate 1 x 1 first.
func _plate_words() -> void:
	print("")
	print("  a 1 x 1 plate asked for")
	for words: String in PLATE_WORDS:
		var listed: PackedStringArray = await _listed(words, 5)
		_check("the bin, \"%s\": %s" % [words, _rows(listed)], not listed.is_empty() and listed[0] == PLATE)
		if words == PLATE_WORDS[0]:
			await _shot("bin_plate_1x1")
		var said: PackedStringArray = await _mcp_found(words, 5)
		_check("search_parts \"%s\": %s" % [words, ", ".join(said)], not said.is_empty() and said[0] == PLATE)


## The walk's 30 words: the part each put first on pre261 first still, in the
## bin and over MCP alike; the wanted parts not first no lower than they were.
func _walk_words() -> void:
	print("")
	print("  the walk's 30 words")
	var same: int = 0
	var agree: int = 0
	var moved := PackedStringArray()
	var differ := PackedStringArray()
	for row: Array in WALK:
		var words: String = row[0]
		var listed: PackedStringArray = await _listed(words, 40)
		var first: String = listed[0] if not listed.is_empty() else "-"
		var said: PackedStringArray = await _mcp_found(words, 1)
		var told: String = said[0] if not said.is_empty() else "-"
		var line: String = "\"%s\": bin %s (pre261 %s), MCP %s" % [words, first, row[1], told]
		if row.size() > 2:
			var at: int = listed.find(str(row[2])) + 1
			line += "; %s %s (was %d)" % [row[2], ("at %d" % at) if at > 0 else "not in 40", int(row[3])]
			if at <= 0 or at > int(row[3]):
				moved.append("%s %s at %d" % [words, row[2], at])
		print("    " + line)
		if first == str(row[1]):
			same += 1
		else:
			moved.append("%s: %s" % [words, first])
		if first == told:
			agree += 1
		else:
			differ.append("%s: bin %s, MCP %s" % [words, first, told])
	_check("%d of %d put pre261's part first still, the three not first no lower%s" % [same,
		WALK.size(), "" if moved.is_empty() else "; changed: " + "; ".join(moved)],
		same == WALK.size() and moved.is_empty())
	_check("%d of %d put the same part first in the bin and over MCP%s" % [agree, WALK.size(),
		"" if differ.is_empty() else "; not: " + "; ".join(differ)], agree == WALK.size())


## [param words] typed into the bin, and the first [param most] parts it lists.
func _listed(words: String, most: int) -> PackedStringArray:
	await _type(words)
	var out := PackedStringArray()
	for info: PartLibrary.PartInfo in _bin.get("_results"):
		if out.size() >= most:
			break
		out.append(info.id)
	return out


## search_parts [param words], as a session asks: the parts its answer lists,
## first first, at most [param most].
func _mcp_found(words: String, most: int) -> PackedStringArray:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": "search_parts",
		"arguments": {"query": words, "limit": most}}})
	var out := PackedStringArray()
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		for line: String in str(block.get("text", "")).split("\n"):
			var id: String = line.strip_edges().get_slice(":", 0)
			if line.contains(": ") and _library.parts.has(id) and out.size() < most:
				out.append(id)
	return out


# -- a tile's tooltip -----------------------------------------------------------


## Each part of SIZES searched by its number: its tile's tooltip, what a screen
## reader says of it, and its row's size in the bin's list.
func _tooltips() -> void:
	print("")
	print("  a tile's tooltip: the studs on top, and those on its sides")
	for part: String in SIZES:
		await _type(part)
		var tile: Button = await _tile_of(part)
		if tile == null:
			_check("%s has a tile" % part, false)
			continue
		var said: String = tile.tooltip_text.get_slice("\n", 2)
		_check("%s, %s: \"%s\"" % [part, _named(part), said], said == str(SIZES[part]))
		_check("...and a screen reader hears it so: \"%s\"" % tile.accessibility_description,
			tile.accessibility_description == str(SIZES[part]))
		if part == "87087":
			await _hover(tile)
			await _shot("tooltip_87087")
	# The bin's list of rows says the same size.
	await _type("87087")
	var list: Button = _bin.get("_list")
	if list != null and not list.button_pressed:
		list.button_pressed = true
	await create_timer(0.3).timeout
	await _until(func() -> bool: return not _busy(), 600)
	await _frames(20)
	var cell: String = _row_size("87087")
	_check("its row in the list: \"%s\"" % cell, cell == "1×1")
	await _shot("list_87087")
	if list != null:
		list.button_pressed = false
	await create_timer(0.3).timeout
	await _until(func() -> bool: return not _busy(), 600)
	await _frames(10)
	await _type("")


## The size a list row of [param part] shows, "1×1", or "".
func _row_size(part: String) -> String:
	for label: Node in (_bin as Node).find_children("*", "Label", true, false):
		if (label as Label).text != part or not (label as Label).is_visible_in_tree():
			continue
		for other: Node in label.get_parent().get_children():
			if other is Label and (other as Label).text.contains("×"):
				return (other as Label).text
	return ""


## The pointer rested on [param tile], as a person's does, until its tooltip
## shows.
func _hover(tile: Control) -> void:
	var at: Vector2 = tile.get_global_rect().get_center()
	for step: int in 3:
		var motion := InputEventMouseMotion.new()
		motion.position = _as_event(at + Vector2(step, 0))
		motion.global_position = motion.position
		Input.parse_input_event(motion)
		await _frames(2)
	await create_timer(1.5).timeout
	await _frames(10)


# -- the keys sheet --------------------------------------------------------------


## F1, and "cut away" typed into the sheet's box: the box's, the sphere's and
## the cylinder's rows kept, each saying what it cuts away by.
func _keys_sheet() -> void:
	print("")
	print("  F1's keys sheet, \"cut away\" typed")
	var sheet: ControlsDialog = _main.get("_controls")
	await _key(KEY_F1)
	await _frames(20)
	_check("F1 opens the keys sheet", sheet.visible)
	var find: LineEdit = sheet.get("_find")
	find.text = "cut away"
	find.text_changed.emit(find.text)
	await _frames(10)
	var kept := PackedStringArray()
	for row: Node in sheet.find_children("*", "HBoxContainer", true, false):
		if row.get_child_count() == 3 and row.get_child(2) is Label \
				and row.get_child(1) is CenterContainer and (row as Control).is_visible_in_tree():
			kept.append((row.get_child(2) as Label).text)
	print("    kept: %s" % "; ".join(kept))
	for words: String in CUT_ROWS:
		_check("\"%s\" is kept" % words, kept.has(words))
	var none: Label = sheet.get("_none")
	_check("...and the sheet does not say no key says it", none == null or not none.visible)
	await _shot("keys_cut_away")
	await _key(KEY_ESCAPE)
	await _frames(6)


# -- the window, as a person uses it --------------------------------------------


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


func _named(part: String) -> String:
	var info: PartLibrary.PartInfo = _library.parts.get(part)
	return Inventory._tidy(info.name) if info != null else part


func _rows(ids: PackedStringArray) -> String:
	var out := PackedStringArray()
	for id: String in ids:
		out.append("%s %s" % [id, _named(id)])
	return " | ".join(out)


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
	var path: String = ProjectSettings.globalize_path("res://shots/words6/%s_%s.png" % [name, _tag])
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
