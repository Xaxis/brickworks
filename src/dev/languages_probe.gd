## The interface in German, French and Spanish (APP_UX3 9, languages).
##
##   godot --path . --resolution 1280x720 --script src/dev/languages_probe.gd
##   ... -- --shots=DIR      each language's menus, keys, Settings and first build pictured there
##   ... -- --missing=FILE   the words each language lacks, as .po entries to translate
##
## What a person reads, gathered from the running app in English: every row
## of every menu (the bar's, its submenus, the app's menu, the toolbar's
## Select by and the menu on a part) and each row's tooltip; every toolbar
## tooltip; the panels' titles (the columns' rails, the model tree, the
## properties, the dialogs' own); the keys sheet; Settings; and the first
## build's every line, which Help, Take the tour shows. Then, in each of
## German, French and Spanish:
## - every one of them has its translation (Language.says), none left in
##   English, words made at the moment matched as patterns;
## - and the control that shows it draws it so (its atr), so nothing is
##   kept out of the translation;
## - in German, the longest words, at 1280 x 720: every menu at most 25
##   rows and 60% of the window's height (palette's bar), each inside the
##   window, and every control the page asks for (Main._page_controls, as
##   fit_check reads them) on the page, the menu bar's and the toolbar's
##   last included.
## - German chosen in Settings, as a person chooses it, and the app started
##   again in a run of its own on the same data folder: German still, and
##   drawn so. English chosen again draws English.
##
## The data folder is the run's own (probe.sh gives one), where the choice is
## written as the app writes it.
extends SceneTree

const LANGUAGES: Array[String] = ["de", "fr", "es"]

var _failures: int = 0
var _main: Node
var _shell: Shell
var _shots: String = ""
var _missing_to: String = ""
var _size: String = ""
## What is checked, by kind: kind -> Array of [english, the control that
## draws it, or null].
var _words: Dictionary = {}
## The words each language lacks, for --missing.
var _missing: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	var after_restart: bool = OS.get_cmdline_user_args().has("--after-restart")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
		if arg.begins_with("--missing="):
			_missing_to = arg.trim_prefix("--missing=")
	var own_folder: bool = _own_data_folder()
	ShellPrefs.kept_by_a_check = own_folder
	if not after_restart and DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	if not after_restart:
		# The assistant on, so its rows are read too; offered already, so its
		# offer is not over the model.
		ShellPrefs.put("assistant", "on")
		ShellPrefs.put("assistant_offered", true)
		ShellPrefs.put("first_build", "skipped")
	BookletMaker.open_when_written = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_shell = _main.get("_shell")
		if _shell != null and _shell.toolbar != null and _main.get("_controls") != null:
			break
	if _shell == null or _shell.toolbar == null:
		print("  languages probe: SKIPPED — the window did not come up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	(_main.get("_store") as ModelStore).keeps = false
	await _frames(30)
	if after_restart:
		_after_restart()
	else:
		var window := Vector2i(DisplayServer.window_get_size())
		_size = "%dx%d" % [window.x, window.y]
		var bar: ModelBar = _main.get("_bar")
		var placed: int = await bar.open_with_progress("res://models/car.ldr")
		bar.opened.emit(placed)
		await _frames(60)
		print("languages probe at %s, the car's %d parts" % [_size, placed])
		_check("the app starts in English, as it is written (%s)" % Language.current(),
			Language.current() == "en")
		await _gather()
		for code: String in LANGUAGES:
			await _in(code)
		await _german_fits()
		await _chosen_and_kept(own_folder)
		if not _missing_to.is_empty():
			_write_missing()
	print("")
	if _failures == 0:
		print("languages probe: all checks passed")
	else:
		print("languages probe: %d check(s) FAILED" % _failures)
	Language.apply("en")
	_main.queue_free()
	await _frames(3)
	quit(1 if _failures > 0 else 0)


## Whether user:// is this run's own (probe.sh's XDG_DATA_HOME), never the
## person's.
func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


# -- what a person reads --------------------------------------------------------

func _add(kind: String, text: String, drawn: Node) -> void:
	# A number, a percentage or a sign alone is the same in any language.
	if not RegEx.create_from_string(r"\p{L}").search(text):
		return
	if not _words.has(kind):
		_words[kind] = []
	for had: Array in _words[kind]:
		if had[0] == text:
			return
	(_words[kind] as Array).append([text, drawn])


func _gather() -> void:
	var bar: ModelBar = _main.get("_bar")
	for button: MenuButton in _shell.get("_menus"):
		_add("menu rows", button.text, button)
		_rows(button.get_popup())
	_rows(bar.mark.get_popup())
	var tools: Dictionary = _shell.toolbar.controls_by_name()
	var select: Variant = tools.get("tool_select")
	if select is MenuButton:
		_rows((select as MenuButton).get_popup())
	# The menu on a part, for the part selected.
	var builder: Builder = _main.get("_builder")
	var world: BrickWorld = _main.get("_world")
	var where := Transform3D(Basis.IDENTITY, Vector3(200, 24, 200))
	var brick: int = world.add_brick("3001", 4, where)
	builder.register(brick, "3001", where)
	builder.select_brick(brick, false)
	await _frames(4)
	_shell.open_context(Vector2(400, 300))
	await _frames(4)
	if _shell.context != null:
		_rows(_shell.context)
		_shell.context.hide()

	for name: String in tools:
		var tool: Control = tools[name]
		_add("toolbar tooltips", tool.tooltip_text, tool)
		if tool is OptionButton:
			for n: int in (tool as OptionButton).item_count:
				_add("toolbar tooltips", (tool as OptionButton).get_item_text(n), tool)

	for dock_name: String in ["_bin_dock", "_props_dock", "_chat_dock"]:
		var dock: SideDock = _main.get(dock_name)
		if dock == null:
			continue
		_add("panel titles", dock.title, dock)
		_add("panel titles", dock.rail().tooltip_text, dock.rail())
	var named: Dictionary = _main.call("_page_controls")
	for name: String in ["outliner", "properties"]:
		if named.get(name) is Button:
			var header: Button = named[name]
			_add("panel titles", header.text, header)
			_add("panel titles", header.tooltip_text, header)
	for window: Node in _main.find_children("*", "Window", true, false):
		if not Tooltips.is_tooltip(window as Window) and not window is PopupMenu:
			_add("panel titles", (window as Window).title, window)

	var controls: ControlsDialog = _main.get("_controls")
	controls.open_keys()
	await _frames(10)
	_add("panel titles", (controls.get("_title") as Label).text, controls.get("_title"))
	for binding: ControlsHint.Binding in controls.bindings():
		_add("keys sheet", binding.verb, controls)
		_add("keys sheet", binding.section, controls)
	var find: LineEdit = controls.get("_find")
	_add("keys sheet", find.placeholder_text, find)
	_add("keys sheet", controls.keys_reset.text, controls.keys_reset)
	_add("keys sheet", controls.keys_reset.tooltip_text, controls.keys_reset)
	_add("keys sheet", (controls.get("_said") as Label).text, controls.get("_said"))
	for label: Node in (controls.get("_find_row") as Control).find_children("*", "Label", true, false):
		_add("keys sheet", (label as Label).text, label)
	await _shot("keys_en")

	controls.open()
	await _frames(10)
	_add("panel titles", (controls.get("_title") as Label).text, controls.get("_title"))
	_walk("settings", controls.get("_settings"), [controls.language_choice,
		controls.get("_version")])
	_add("settings", (controls.get("_done") as Button).text, controls.get("_done"))
	controls.visible = false
	await _frames(4)

	var first: FirstBuild = _shell.first_build
	for card: Array in first.cards():
		_add("first build and tour", str(card[0]), first)
		_add("first build and tour", str(card[1]), first)
	for button: String in ["_go", "_skip"]:
		_add("first build and tour", (first.get(button) as Button).text, first.get(button))
		_add("first build and tour", (first.get(button) as Button).tooltip_text, first.get(button))
	_add("first build and tour", "Done", first.get("_go"))

	var counts: PackedStringArray = []
	for kind: String in _words:
		counts.append("%s %d" % [kind, (_words[kind] as Array).size()])
	print("  read in English: %s" % ", ".join(counts))


## A menu's rows and their tooltips, and its submenus', but for the models
## and the changes Open recent and History list.
func _rows(popup: PopupMenu) -> void:
	for n: int in popup.item_count:
		if popup.is_item_separator(n):
			continue
		_add("menu rows", popup.get_item_text(n), popup)
		_add("menu tooltips", popup.get_item_tooltip(n), popup)
		var sub: PopupMenu = popup.get_item_submenu_node(n)
		if sub != null and not str(sub.name) in ["recent", "history"]:
			_rows(sub)


## Every word shown under [param node], but in [param skipped]: the language
## names and the build's version, which are names.
func _walk(kind: String, node: Node, skipped: Array) -> void:
	if node in skipped:
		return
	if node is Control and not (node as Control).visible:
		return
	if node is Label:
		_add(kind, (node as Label).text, node)
	elif node is OptionButton:
		for n: int in (node as OptionButton).item_count:
			_add(kind, (node as OptionButton).get_item_text(n), node)
	elif node is Button:
		_add(kind, (node as Button).text, node)
	elif node is LineEdit:
		_add(kind, (node as LineEdit).placeholder_text, node)
	if node is Control:
		_add(kind, (node as Control).tooltip_text, node)
	for child: Node in node.get_children():
		_walk(kind, child, skipped)


# -- in each language ------------------------------------------------------------

func _in(code: String) -> void:
	Language.apply(code)
	await _frames(6)
	print("\n  %s" % code)
	_check("%s is in use (%s)" % [code, Language.current()], Language.current() == code)
	_missing[code] = []
	var same: int = 0
	for kind: String in _words:
		var lacking: Array[String] = []
		var undrawn: Array[String] = []
		for word: Array in _words[kind]:
			var english: String = word[0]
			var said: String = Language.says(english)
			if said.is_empty():
				lacking.append(english)
				(_missing[code] as Array).append(english)
				continue
			if said == english:
				same += 1
			var drawn: Node = word[1]
			if drawn != null and drawn.atr(english) != said:
				undrawn.append(english)
		_check("%s: every one of %d %s translated%s" % [code, (_words[kind] as Array).size(), kind,
			"" if lacking.is_empty() else "; %d not: %s" % [lacking.size(), _some(lacking)]],
			lacking.is_empty())
		if not undrawn.is_empty():
			_check("%s: ...and drawn so (%d drawn in English: %s)" % [code, undrawn.size(),
				_some(undrawn)], false)
	print("    (%d the same as the English, as names are)" % same)
	# What a person sees, in each.
	var file: MenuButton = _shell.get("_menus")[0]
	print("    File reads \"%s\", its first row \"%s\"" % [file.atr(file.text),
		file.get_popup().atr(file.get_popup().get_item_text(0))])
	await _pictures(code)


func _some(words: Array[String]) -> String:
	var shown: Array[String] = []
	for word: String in words.slice(0, 6):
		shown.append("\"%s\"" % word.c_escape().left(60))
	return ", ".join(shown) + (" and %d more" % (words.size() - 6) if words.size() > 6 else "")


func _pictures(code: String) -> void:
	if _shots.is_empty():
		return
	for title: int in [0, 2, 3]:
		var button: MenuButton = _shell.get("_menus")[title]
		button.show_popup()
		await _frames(8)
		await _shot("%s_menu_%d" % [code, title])
		button.get_popup().hide()
		await _frames(3)
	var controls: ControlsDialog = _main.get("_controls")
	controls.open_keys()
	await _frames(10)
	await _shot("%s_keys" % code)
	controls.open()
	await _frames(10)
	await _shot("%s_settings" % code)
	controls.visible = false
	_shell.first_build.start()
	await _frames(10)
	await _shot("%s_first_build" % code)
	_shell.first_build.stop()
	await _frames(4)


# -- German, the longest words: the window still fits ---------------------------

func _german_fits() -> void:
	var room: Rect2 = root.get_visible_rect()
	var buttons: Array[MenuButton] = []
	for button: MenuButton in _shell.get("_menus"):
		buttons.append(button)
	buttons.append((_main.get("_bar") as ModelBar).mark)
	# Each menu as English has it, to tell what the language changed.
	Language.apply("en")
	await _frames(6)
	var english: Array[Vector2] = []
	for button: MenuButton in buttons:
		english.append(await _opened(button))
	Language.apply("de")
	await _frames(10)
	print("\n  German at %s" % _size)
	var tallest: float = 0.0
	var worst: String = ""
	for n: int in buttons.size():
		var button: MenuButton = buttons[n]
		var named: String = button.atr(button.text) if n < buttons.size() - 1 else "the app's menu"
		var popup: PopupMenu = button.get_popup()
		var size: Vector2 = await _opened(button)
		var placed := Rect2(Vector2(popup.position), size)
		var low: bool = size.y <= room.size.y * 0.6
		# Over 60% in English too is the menu's own, not the language's:
		# said, and held to English's height.
		var as_english: bool = not low and english[n].y > room.size.y * 0.6 and size.y <= english[n].y
		if size.y > tallest:
			tallest = size.y
			worst = named
		_check("%s: %d rows, %d of %d high (at most 25 and 60%%%s), %d wide (%d in English), inside the window" % [
			named, popup.item_count, size.y, roundi(room.size.y),
			"; %d in English too, the menu's own" % english[n].y if as_english else "", size.x, english[n].x],
			popup.item_count <= 25 and (low or as_english) and room.grow(1.0).encloses(placed))
	print("    the tallest, %s: %d (%d%%)" % [worst, tallest, roundi(100.0 * tallest / room.size.y)])
	# The bar: its menus and everything after them inside the window.
	var bar: ModelBar = _main.get("_bar")
	var last: float = 0.0
	for child: Node in bar.find_children("*", "Control", true, false):
		var control: Control = child as Control
		if control.is_visible_in_tree() and control.size.x > 0.0 and control is Button:
			last = maxf(last, control.get_global_rect().end.x)
	_check("the menu bar's last control ends at %d, inside %d" % [last, room.size.x],
		last > 0.0 and last <= room.size.x + 1.0)
	var off: Array[String] = []
	var named: Dictionary = _main.call("_page_controls")
	for name: String in named:
		var control: Control = named[name] as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var middle: Vector2 = control.get_global_rect().get_center()
		if not room.has_point(middle):
			off.append("%s at %d,%d" % [name, middle.x, middle.y])
	_check("every control the page asks for on it (%d; off: %s)" % [named.size(),
		"none" if off.is_empty() else ", ".join(off)], off.is_empty())
	var controls: ControlsDialog = _main.get("_controls")
	for face: String in ["keys", "settings"]:
		if face == "keys":
			controls.open_keys()
		else:
			controls.open()
		await _frames(10)
		var rect: Rect2 = controls.get_global_rect()
		_check("the %s in German inside the window ([%d, %d, %d, %d])" % [face, rect.position.x,
			rect.position.y, rect.size.x, rect.size.y], room.grow(1.0).encloses(rect))
	controls.visible = false
	await _frames(4)
	await _shot("de_whole")


# -- chosen in Settings, and kept ------------------------------------------------

func _chosen_and_kept(own_folder: bool) -> void:
	Language.apply("en")
	await _frames(4)
	print("\n  chosen in Settings")
	var controls: ControlsDialog = _main.get("_controls")
	_shell.run("settings")
	await _frames(10)
	var choice: OptionButton = controls.language_choice
	_check("Settings has Language, its choices in their own words (%s)" % ", ".join(
		range(choice.item_count).map(func(n: int) -> String: return choice.get_item_text(n))),
		choice.is_visible_in_tree() and choice.item_count == 4
		and choice.get_item_text(1) == "Deutsch" and choice.atr("Deutsch") == "Deutsch")
	choice.select(1)
	choice.item_selected.emit(1)
	await _frames(6)
	var file: MenuButton = _shell.get("_menus")[0]
	_check("Deutsch chosen: German in use and kept (%s, kept %s); File reads \"%s\"" % [
		Language.current(), ShellPrefs.value("language"), file.atr(file.text)],
		Language.current() == "de" and ShellPrefs.value("language") == "de"
		and file.atr(file.text) == Language.says("File") and file.atr(file.text) != "File")
	await _shot("de_settings_chosen")
	controls.visible = false
	if not own_folder:
		_check("a data folder of this run's own to keep the choice in (run by tools/probe.sh)",
			false)
	else:
		print("\n  the app started again")
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path",
			ProjectSettings.globalize_path("res://"), "--script", "res://src/dev/languages_probe.gd",
			"--", "--after-restart"], output, true)
		for line: String in "\n".join(output).split("\n"):
			if line.begins_with("  ok") or line.begins_with("  FAIL"):
				print("  " + line)
		_check("a run of its own, on the same data folder, passed (exit %d)" % code, code == 0)
	# And back: English chosen draws English.
	_shell.run("settings")
	await _frames(6)
	choice.select(0)
	choice.item_selected.emit(0)
	await _frames(6)
	_check("English chosen again: File reads \"%s\", kept %s" % [file.atr(file.text),
		ShellPrefs.value("language")], Language.current() == "en" and file.atr(file.text) == "File"
		and ShellPrefs.value("language") == "en")
	controls.visible = false


func _after_restart() -> void:
	var file: MenuButton = _shell.get("_menus")[0]
	var row: String = file.get_popup().get_item_text(0)
	_check("German still, as chosen before the restart (%s); File reads \"%s\", its first row \"%s\"" % [
		Language.current(), file.atr(file.text), file.get_popup().atr(row)],
		Language.current() == "de" and file.atr(file.text) != "File"
		and file.get_popup().atr(row) != row)
	_check("...while the menus' own words are English, as every check reads them (%s)" % file.text,
		file.text == "File")


# -- helpers ---------------------------------------------------------------------

func _write_missing() -> void:
	var out := FileAccess.open(_missing_to, FileAccess.WRITE)
	for code: String in _missing:
		out.store_line("# %s: %d" % [code, (_missing[code] as Array).size()])
		for english: String in _missing[code]:
			out.store_line("msgid \"%s\"\nmsgstr \"\"\n" % english.c_escape().replace("\\'", "'"))
	out.close()
	print("  the missing words written to %s" % _missing_to)


## [param button]'s menu opened and closed again: its size while open.
func _opened(button: MenuButton) -> Vector2:
	button.show_popup()
	await _frames(8)
	var size := Vector2(button.get_popup().size)
	button.get_popup().hide()
	await _frames(3)
	return size


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(named: String) -> void:
	if _shots.is_empty():
		return
	await RenderingServer.frame_post_draw
	var path: String = _shots.path_join("%s_%s.png" % [named, _size])
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)
