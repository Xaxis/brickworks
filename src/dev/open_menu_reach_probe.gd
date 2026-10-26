## Can every command in File › Open's menu be reached with forty models saved?
##
##   godot --path . --resolution 1280x800 --script src/dev/open_menu_reach_probe.gd
##   PROBE_SIZE=768x1024 tools/probe.sh open_menu_reach_probe --tablet
##   PROBE_SIZE=390x844 tools/probe.sh open_menu_reach_probe --phone
##
## fling272b (2026-10-26): with more than a dozen saves, Open's menu grew
## its list until "Rename or delete saved models…", after the saves, was
## past the bottom of the window: no finger, pointer or key reached it, so
## a person with many saves could rename or delete none of them.
##
## Here forty models are saved, and Open's menu is opened as a person opens
## it, with the pointer high, in the middle and low in the window: the menu
## is inside the window; every command in it (not a save) is on the screen
## as it opens; the arrows reach each of them, each shown inside the window
## when it is reached; Up from the top comes round to the last; Enter on
## Rename or delete opens Saved models; and Escape puts the menu away.
## --tablet and --phone lay the window out for a finger, as a touch screen
## in a browser does, a phone's at a browser's scale.
extends SceneTree

const SAVES := 40

var _failures: int = 0
var _main: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--phone") or args.has("--tablet"):
		Phone._on = 1
		Phone._wide = args.has("--tablet")
	_save_many()
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	# A phone draws at a browser's scale (Main.screen_factor, web): a
	# desktop's window draws its layout half as big, which no phone does.
	if Phone.on() and not Phone.wide() and not OS.has_feature("web"):
		var main_script: GDScript = _main.get_script()
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
	await _frames(20)
	var room: Rect2 = root.get_visible_rect()
	print("\n  the window: %d x %d (%s)" % [roundi(room.size.x), roundi(room.size.y),
		"a tablet's layout" if Phone.wide() else "a phone's layout" if Phone.on() else "the desktop's"])
	var bar: ModelBar = _main.get("_bar")
	var shell: Shell = _main.get("_shell")
	for high: float in [0.08, 0.5, 0.92]:
		await _open_menu(shell, bar, Vector2(room.size.x * 0.3, room.size.y * high))
	print("")
	if _failures == 0:
		print("every command in File › Open's menu is reached with %d models saved" % SAVES)
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## Forty saves, in this run's own data folder.
func _save_many() -> void:
	DirAccess.make_dir_recursive_absolute(ModelStore.SAVE_DIR)
	var text: String = FileAccess.get_file_as_string("res://models/house.ldr")
	for n: int in SAVES:
		var file := FileAccess.open(ModelStore.saved_path("Saved model %02d" % (n + 1)), FileAccess.WRITE)
		file.store_string(text)
		file.close()


func _open_menu(shell: Shell, bar: ModelBar, pointer: Vector2) -> void:
	root.warp_mouse(pointer)
	await _frames(3)
	shell.run("open")
	await _frames(10)
	var menu: PopupMenu = bar.get("_saves")
	print("\n  File › Open, the pointer at %d, %d" % [roundi(pointer.x), roundi(pointer.y)])
	if not _check("the menu is open", menu.visible):
		return
	var room: Rect2 = root.get_visible_rect().grow(1.0)
	var rect := Rect2(Vector2(menu.position), Vector2(menu.size))
	_check("the menu is inside the window (%s in %s)" % [_say(rect), _say(root.get_visible_rect())],
		room.encloses(rect))
	var commands: Array[int] = []
	for id: int in [ModelBar.IMPORT, ModelBar.LIBRARY, ModelBar.MANAGE]:
		commands.append(menu.get_item_index(id))
	_check("it has its three commands and %d saves (%d rows)" % [SAVES, menu.item_count],
		not commands.has(-1) and menu.item_count > SAVES + commands.size())
	if commands.has(-1):
		menu.hide()
		return
	for index: int in commands:
		var shown: Rect2 = _item_on_screen(menu, index)
		_check("\"%s\" is in the window as the menu opens (%s)" % [_words(menu, index), _say(shown)],
			shown.size.y > 0.0 and room.encloses(shown))
	# The arrows, from the top: every row reached, and shown when it is.
	var reached: Dictionary = {}
	var hidden: PackedStringArray = []
	for _n: int in menu.item_count + 2:
		await _key(KEY_DOWN)
		var at: int = menu.get_focused_item()
		if at == -1 or reached.has(at):
			continue
		var shown: Rect2 = _item_on_screen(menu, at)
		reached[at] = true
		if shown.size.y <= 0.0 or not room.encloses(shown):
			hidden.append("\"%s\" at %s" % [_words(menu, at), _say(shown)])
	var rows: int = _enabled(menu).size()
	_check("Down reaches all %d of its rows (%d), its commands among them" % [rows, reached.size()],
		reached.size() == rows and commands.all(func(index: int) -> bool: return reached.has(index)))
	_check("...each in the window when it is reached (%d not%s)" % [hidden.size(),
		": " + ", ".join(hidden.slice(0, 3)) if hidden.size() > 0 else ""], hidden.is_empty())
	# Up from the first comes round to the last.
	var first: int = _enabled(menu).front()
	var last: int = _enabled(menu).back()
	for _n: int in menu.item_count + 2:
		if menu.get_focused_item() == first or not menu.visible:
			break
		await _key(KEY_UP)
	await _key(KEY_UP)
	var bottom: Rect2 = _item_on_screen(menu, last)
	_check("Up from the first comes round to the last, \"%s\", in the window (%s)" % [
		_words(menu, last), _say(bottom)],
		menu.get_focused_item() == last and bottom.size.y > 0.0 and room.encloses(bottom))
	# Enter on Rename or delete: Saved models.
	var manage: int = menu.get_item_index(ModelBar.MANAGE)
	for _n: int in menu.item_count + 2:
		if menu.get_focused_item() == manage or not menu.visible:
			break
		await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _frames(10)
	var saved: Window = _main.get("_saved_models") as Window
	_check("Enter on Rename or delete opens Saved models", saved != null and saved.visible)
	if saved != null and saved.visible:
		saved.hide()
		await _frames(5)
	# Escape puts it away.
	shell.run("open")
	await _frames(10)
	await _key(KEY_DOWN)
	await _key(KEY_ESCAPE)
	_check("Escape puts the menu away", not menu.visible)
	if menu.visible:
		menu.hide()
	await _frames(5)


## The rows that can be picked: not a heading or a line.
func _enabled(menu: PopupMenu) -> Array[int]:
	var out: Array[int] = []
	for index: int in menu.item_count:
		if not menu.is_item_separator(index) and not menu.is_item_disabled(index):
			out.append(index)
	return out


func _words(menu: PopupMenu, index: int) -> String:
	return menu.get_item_text(index).substr(0, 28)


## The menu's own scroll, which holds its rows.
func _scroll_of(node: Node) -> ScrollContainer:
	for child: Node in node.get_children(true):
		if child is ScrollContainer:
			return child
		var found: ScrollContainer = _scroll_of(child)
		if found != null:
			return found
	return null


## Where row [param index] is on the window as the menu shows it now,
## scrolled as it is: what of it its scroll shows, an empty rect for none.
func _item_on_screen(menu: PopupMenu, index: int) -> Rect2:
	var scroll: ScrollContainer = _scroll_of(menu)
	if scroll == null:
		return Rect2()
	var font: Font = menu.get_theme_font("font")
	var size: int = menu.get_theme_font_size("font_size")
	var row: float = font.get_height(size) + float(menu.get_theme_constant("v_separation"))
	var y: float = 0.0
	for n: int in index:
		if menu.is_item_separator(n):
			y += row if not menu.get_item_text(n).is_empty() else \
				float(menu.get_theme_constant("separator_outline_size")) + row * 0.5
		else:
			y += row
	var view: Rect2 = scroll.get_global_rect()
	var local := Rect2(view.position.x, view.position.y + y - float(scroll.scroll_vertical), view.size.x, row)
	local = local.intersection(view)
	if local.size.y < row * 0.5:
		return Rect2()
	var scale: float = menu.content_scale_factor
	return Rect2(Vector2(menu.position) + local.position * scale, local.size * scale)


func _say(rect: Rect2) -> String:
	return "%d,%d %dx%d" % [roundi(rect.position.x), roundi(rect.position.y),
		roundi(rect.size.x), roundi(rect.size.y)]


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _frames(2)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
