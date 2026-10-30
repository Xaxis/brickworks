## The app's own menu, from the mark at the far left of the menu bar
## (ModelBar.mark, Shell.APP_MENU): the owner asked whether the app should
## carry the logo, and it does the way CAD programs do (brand373,
## 2026-10-29).
##
##   godot --path . --resolution 1280x800 --script src/dev/app_menu_probe.gd
##   PROBE_SIZE=390x844 tools/probe.sh app_menu_probe --browser
##
## The mark is the first thing in the menu bar, at its left, in the app's
## colours; it takes room nobody had and pushes nothing: at the window's own
## width and at every narrower one down to a narrow browser's 720 units
## across, the bar stays one line, and the bar and the toolbar under it are
## where they were, the same size and showing the same tools, as with the
## app's name in words where the mark is now. Its name beside it while
## there is room, the mark alone where there is not.
##
## Clicked, it opens About Brickworks, the website, the docs and Account (in
## a browser, Back to brickworks.diy too: tools/web/app_menu_flow.mjs);
## Down and Return there open About. By keys alone: F6 from the model goes
## to it first, with its name and tooltip, and Return opens it. Its rows
## keep their commands after the assistant is turned on, as the toolbar's
## Select by does: from 2026-10-13 until brand373 a menu made again gave
## its commands' ids to others, and Select by colour ran the Help menu's
## Documentation for whoever started with the assistant off.
##
## --browser draws the window at a browser's scale (Main.screen_factor,
## web): a phone-width browser with a mouse has 720 units across.
## Pictures in shots/app_menu/.
extends SceneTree

const DESKTOP_ROWS: Array = ["About Brickworks", "-", "Brickworks website", "Documentation", "-",
	"Account…"]

var _failures: int = 0
## The addresses the app asked to open (Shell.open_link).
var _opened: Array[String] = []
var _main: Node
var _shell: Shell
var _bar: ModelBar


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
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Started with the assistant off, as a person who chose so starts: the
	# menus are made again when it is turned on.
	ShellPrefs.put("assistant", "off")
	ShellPrefs.put("assistant_offered", true)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	(_main.get("_store") as ModelStore).keeps = false
	_main.call("clear_model")
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	# A link chosen opens nothing: this shell carries the owner's desktop, and
	# a row that ran Documentation opened a browser on the owner's screen.
	_shell.open_link = func(address: String) -> Error:
		_opened.append(address)
		return OK
	# The width is the probe's from here: Main's own look at the window would
	# put its factor back.
	for link: Dictionary in root.size_changed.get_connections():
		var call: Callable = link["callable"]
		if call.get_method() == &"_match_screen_density":
			root.size_changed.disconnect(call)
	var main_script: GDScript = _main.get_script()
	var window := Vector2(DisplayServer.window_get_size())
	var own: float = main_script.sized_factor(window.x, window.y,
		OS.get_cmdline_user_args().has("--browser"), 1.0)
	root.content_scale_factor = own
	await _frames(20)

	var mark: MenuButton = _bar.mark
	if not _check("the menu bar has the mark", mark != null and mark.is_visible_in_tree()):
		_finish()
		return
	# Drawn at the screen's density: so many pixels, 18 units tall whatever
	# the density (ModelBar.MARK_TALL).
	var tall: float = mark.icon.get_height() / Icons.density(mark) if mark.icon != null else 0.0
	_check("...a picture, %s pixels, %.1f units tall" % [
		str(mark.icon.get_size()) if mark.icon != null else "none", tall],
		absf(tall - ModelBar.MARK_TALL) < 1.5)
	_check("...named for a screen reader: \"%s\", \"%s\"" % [mark.accessibility_name,
		mark.accessibility_description], mark.accessibility_name == "Brickworks"
		and mark.accessibility_description.contains("About"))
	_check("...with a tooltip: \"%s\"" % mark.tooltip_text.replace("\n", " / "),
		mark.tooltip_text.begins_with("Brickworks\n"))

	# The window's own width, then narrower, to a narrow browser's.
	var widths: Array[float] = [root.get_visible_rect().size.x]
	for across: float in [1100.0, 900.0, 800.0, 720.0]:
		if across < widths[0] - 1.0:
			widths.append(across)
	for across: float in widths:
		root.content_scale_factor = own * widths[0] / across
		await _frames(12)
		await _at_width(mark)
	await _name_gives_way(mark)
	root.content_scale_factor = own
	await _frames(12)

	await _menu_by_click(mark)
	await _menu_by_keys(mark)
	await _ids_kept()
	_finish()


## The mark first, at the bar's left, the bar one line; and the bar and
## the toolbar as they were before it.
func _at_width(mark: MenuButton) -> void:
	var room: Vector2 = root.get_visible_rect().size
	var row: Control = mark.get_parent()
	var first: Control = null
	var lines: Dictionary = {}
	for child: Node in row.get_children():
		var control: Control = child as Control
		if control == null or not control.visible:
			continue
		if first == null:
			first = control
		lines[roundi(control.position.y)] = true
	var with_it: Array = _layout()
	# Before the mark the row began with the app's name, in words: put back,
	# in its place, for the bar as it was.
	var name := Label.new()
	name.text = "Brickworks"
	name.add_theme_font_size_override("font_size", 14)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.custom_minimum_size = Vector2(0, 28)
	mark.visible = false
	row.add_child(name)
	row.move_child(name, 0)
	await _frames(6)
	var without: Array = _layout()
	name.free()
	mark.visible = true
	await _frames(6)
	print("    %d x %d units: the mark %s, the toolbar showing %d controls" % [room.x, room.y,
		"and its name" if not mark.text.is_empty() else "alone", with_it[2]])
	_check("...the mark first in the bar, at its left (%d), the bar one line (%d)" % [
		mark.position.x, lines.size()], first == mark and mark.position.x < 1.0 and lines.size() == 1)
	_check("...the bar's height, the toolbar's top and the tools it shows as they were with the name in words: %s, %s" % [
		str(with_it), str(without)], with_it == without)
	await _shot("bar_%d" % roundi(room.x))


## At the narrowest, with this tab's Claude line showing too, the name
## goes and the mark stays, the bar one line; the line gone, it is back.
func _name_gives_way(mark: MenuButton) -> void:
	_bar.show_claude_tab(["Tab 3", Color(0.55, 0.57, 0.6), "Claude knows this tab as 3."])
	await _frames(12)
	var lines: Dictionary = {}
	for child: Node in mark.get_parent().get_children():
		if child is Control and (child as Control).visible:
			lines[roundi((child as Control).position.y)] = true
	_check("at %d units with this tab's Claude line, the mark alone (\"%s\"), the bar one line (%d)" % [
		root.get_visible_rect().size.x, mark.text, lines.size()], mark.text.is_empty() and lines.size() == 1)
	await _shot("bar_%d_claude_tab" % roundi(root.get_visible_rect().size.x))
	_bar.show_claude_tab(["", Color.TRANSPARENT, ""])
	await _frames(12)
	_check("...and the line gone, its name is back (\"%s\")" % mark.text, mark.text == "Brickworks")


## The bar's height, the toolbar's top and how many of its controls show.
func _layout() -> Array:
	var shown: int = 0
	for control: Control in _shell.toolbar.controls_by_name().values():
		if control.is_visible_in_tree():
			shown += 1
	return [roundi(_bar.size.y), roundi(_shell.toolbar.global_position.y), shown]


func _menu_by_click(mark: MenuButton) -> void:
	var menu: PopupMenu = mark.get_popup()
	await _click(mark.get_global_rect().get_center())
	await _frames(8)
	var rows: Array = _rows(menu)
	_check("clicked, the mark opens its menu: %s" % ", ".join(rows), menu.visible and rows == DESKTOP_ROWS)
	_check("...under the mark, inside the window (%s)" % str(menu.position),
		menu.position.y >= int(mark.get_screen_position().y) and menu.position.x >= 0)
	_check("...Back to brickworks.diy is a browser's alone (%s, %s)" % [
		_shell.command("back_to_site").words, Shell.APP_MENU.back()],
		Shell.APP_MENU.back() == "back_to_site" and not _shell.can("back_to_site")
		and _shell.command("back_to_site").words == "Back to brickworks.diy")
	await _shot("menu_open", menu)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _frames(10)
	var about: AcceptDialog = _shell.get("_about")
	_check("Down and Return there open About Brickworks", about.visible)
	await _shot("about")
	about.hide()
	await _frames(6)
	_check("...and the menu has gone", not menu.visible)
	for row: int in [2, 3]:
		_opened.clear()
		menu.id_pressed.emit(menu.get_item_id(row))
		await _frames(6)
		_check("%s opens %s" % [menu.get_item_text(row), ", ".join(_opened)], _opened.size() == 1
			and _opened[0].begins_with("https://brickworks.diy")
			and (row == 2 or _opened[0].begins_with(DocsPages.SITE)))


func _menu_by_keys(mark: MenuButton) -> void:
	var menu: PopupMenu = mark.get_popup()
	root.gui_release_focus()
	await _frames(4)
	await _key(KEY_F6)
	var on: Control = root.gui_get_focus_owner()
	_check("by keys: F6 from the model goes to the mark first (%s)" % (
		on.accessibility_name if on != null else "nothing"), on == mark)
	await _key(KEY_ENTER)
	await _frames(6)
	_check("...Return opens its menu, its first row lit (%d)" % menu.get_focused_item(),
		menu.visible and menu.get_focused_item() == 0)
	await _key(KEY_ESCAPE)
	await _frames(6)
	_check("...and Escape puts it away", not menu.visible)
	root.gui_release_focus()


## The assistant turned on makes the menus again; every row of the app's
## menu and of the toolbar's Select by still runs its own command.
func _ids_kept() -> void:
	_main.call("set_assistant", true)
	await _frames(10)
	var wrong: Array[String] = []
	var ids: Array = _shell.get("_ids")
	var select_by: PopupMenu = (_shell.toolbar.controls_by_name()["tool_select"] as MenuButton).get_popup()
	var popups: Array[PopupMenu] = [_bar.mark.get_popup(), select_by]
	var wanted: Array = [Shell.APP_MENU, Shell.SUBMENUS["select_by"] + ["-", "select_all", "select_none"]]
	for n: int in popups.size():
		var names: Array = _shell._shown(wanted[n]).filter(func(s: String) -> bool: return s != "-")
		var at: int = 0
		for index: int in popups[n].item_count:
			if popups[n].is_item_separator(index):
				continue
			var id: int = popups[n].get_item_id(index)
			var runs: String = str(ids[id]) if id >= 0 and id < ids.size() else "nothing"
			if at >= names.size() or runs != str(names[at]):
				wrong.append("%s runs %s" % [popups[n].get_item_text(index), runs])
			at += 1
	_check("with the assistant turned on, every row of the app's menu and of Select by runs its own command%s" % (
		"" if wrong.is_empty() else ": " + ", ".join(wrong)), wrong.is_empty())
	await _click(_bar.mark.get_global_rect().get_center())
	await _frames(8)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _frames(10)
	var about: AcceptDialog = _shell.get("_about")
	_check("...and the menu's first row still opens About", about.visible)
	about.hide()


func _rows(menu: PopupMenu) -> Array:
	var out: Array = []
	for index: int in menu.item_count:
		out.append("-" if menu.is_item_separator(index) else menu.get_item_text(index))
	return out


## The top of the window (the menu bar and the toolbar), and with a menu
## open, down to its foot.
func _shot(name: String, menu: PopupMenu = null) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var scale: float = float(image.get_width()) / root.get_visible_rect().size.x
	var foot: float = (_shell.toolbar.global_position.y + _shell.toolbar.size.y + 8.0) * scale
	# A menu open, or a dialog, is shown whole: the window's picture holds
	# what is embedded in it.
	if (menu == null or not menu.visible) and name != "about":
		image = image.get_region(Rect2i(0, 0, image.get_width(), mini(roundi(foot), image.get_height())))
	var path: String = ProjectSettings.globalize_path("res://shots/app_menu/%s%s.png" % [
		name, "_browser" if OS.get_cmdline_user_args().has("--browser") else ""])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s" % path)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = Vector2(1, 0)
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(4)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _finish() -> void:
	if _failures == 0:
		print("app menu probe: all checks passed")
	else:
		print("app menu probe: %d checks failed" % _failures)
	quit(1 if _failures > 0 else 0)
