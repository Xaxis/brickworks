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
## properties, the dialogs' own); what the parts bin, the properties and the
## assistant's panel say, and the lines along the foot, with a part
## selected and with none (the properties also with two parts selected and
## with a sub-assembly selected whole), but the names of parts, colours and Claude's
## models; the keys sheet; Settings; and the first build's every line,
## which Help, Take the tour shows. Then, in each of German, French and
## Spanish:
## - every one of them has its translation (Language.says), none left in
##   English, words made at the moment matched as patterns;
## - and the control that shows it draws it so (its atr), so nothing is
##   kept out of the translation, and none keeps words of the interface in
##   English (Language.left_in_english) but names and keys;
## - Find a command finds Save by its name in the language, and by "save";
## - the Library's themes: those that are words by their own entries
##   (context "theme"), the product lines' and licences' names as they are;
## - a release's version line ("released 2026-10-31"), in Settings and About;
## - a count of thousands, the Library's sets, grouped as the language groups
##   it (1.575, 1 575);
## - Render's backdrop "White" reads the language's word, by its own entry
##   (msgctxt "backdrop"), while LDraw's colour White stays White; and a
##   sub-model named Car reads Car in the model tree and in a line that
##   names it ("opened Car — 61 bricks");
## - in German, the longest words, at 1280 x 720: every menu at most 25
##   rows and 60% of the window's height (palette's bar), each inside the
##   window, and every control the page asks for (Main._page_controls, as
##   fit_check reads them) on the page, the menu bar's and the toolbar's
##   last included; and the toolbar's widest tooltips laid out as wide as
##   Tooltips lets one be, measured in German.
## - German chosen in Settings, as a person chooses it, and the app started
##   again in a run of its own on the same data folder: German still, and
##   drawn so, and --about says its line in German. English chosen again
##   draws English.
##
## The data folder is the run's own (probe.sh gives one), where the choice is
## written as the app writes it.
extends SceneTree

const LANGUAGES: Array[String] = ["de", "fr", "es"]
## What each groups a count's thousands with, where English has a comma:
## 1.575 in German and Spanish, 1 575 in French (a no-break space).
const THOUSANDS: Dictionary = {"de": ".", "fr": "\u00a0", "es": "."}

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
## A key's name, kept in every language: Ctrl-C, Shift+H, F1, Esc.
## The status line lowers a modifier before its key (Keymap.listed_key):
## ctrl-shift-Z.
var _KEY: RegEx = RegEx.create_from_string(
	r"^((?i:Ctrl|Shift|Alt|Cmd|Option)[+-])*(Ctrl|Shift|Alt|Cmd|Option|[A-Z0-9]|F\d+|Esc|Enter|Space|Tab|Delete|Backspace|Home|End|Page Up|Page Down|Up|Down|Left|Right|\W)$")
## A file's name or its path, which a status line names as it is.
var _FILE: RegEx = RegEx.create_from_string(r"^\S*[/\\]\S*$|^[^/\\]+\.[a-z0-9]{2,4}$")
## The part put down to have a selection, and its menu.
var _brick: int = 0
## Names, drawn as they are in any language: the colours', the part's,
## Claude's models'.
var _names: Dictionary = {}


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
	# A release's version line in Settings and About ("Brickworks 0.12.0,
	# released 2026-10-31 (91910f5)"), which a build run from source never
	# shows; its commit is a name.
	BuildInfo._stamp = {"date": "2026-10-31", "commit": "91910f5"}
	BuildInfo._read = true
	_names["91910f5"] = true
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
		await _gather_status()
		await _gather_dialogs()
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
	# A number, a percentage or a sign alone is the same in any language, as
	# a key's letter is, and a part's or a colour's name.
	if not RegEx.create_from_string(r"\p{L}").search(text) or text.length() == 1 \
			or RegEx.create_from_string(r"^F\d+$").search(text) or _is_name(text):
		return
	if not _words.has(kind):
		_words[kind] = []
	for had: Array in _words[kind]:
		if had[0] == text:
			return
	(_words[kind] as Array).append([text, drawn])


## Names, as _plain has them: every part's, however a list writes it.
var _plain_names: Dictionary = {}
var _JOINS: RegEx = RegEx.create_from_string(r" · | — |\. |; | › |\n")
var _ROWS: RegEx = RegEx.create_from_string(r" · | — |\n")
var _ADDRESS: RegEx = RegEx.create_from_string(
	r"^(https?://\S+|[\w.-]+\.(org|com|diy|io|net|ai)(/\S*)?|[^@\s]+@[^@\s]+)$")
## A file dialog's patterns ("*.ldr, *.mpd"), a licence's own name, a
## copyright line, and the app's name with its version ("Brickworks 0.10.0,
## Linux 24.04, forward_plus, 1280 × 720", what feedback sends): names.
var _GLOBS: RegEx = RegEx.create_from_string(r"^\*\.[a-z0-9]+(, \*\.[a-z0-9]+)*$")
var _LEGAL: RegEx = RegEx.create_from_string(
	r"^(Copyright \(c\) .*|MIT License|SIL Open Font License [\d.]+|CC BY(-SA)? [\d.]+|CC0 [\d.]+|CCAL [\d.]+)$")
var _VERSIONED: RegEx = RegEx.create_from_string(r"^Brickworks \d+\.\d+")
## A number and its unit's sign ("30 s", "24 mm"), and a count of a part
## ("1 × Brick 2 x 4"), as every language writes them.
var _MEASURE: RegEx = RegEx.create_from_string(r"^-?\d+([.,]\d+)? ?(s|ms|mm|cm|m|°|%|px|g|kg|LDU)$")
var _COUNTED: RegEx = RegEx.create_from_string(r"^\d+ × (.+)$")


## Whether [param text] is names alone, which every language draws as they
## are: each of its lines, and each part of a line where a join divides
## it, a name (a part's, a colour's, a model's, a set's), a part's number,
## a key, a file, an address, or no word at all. A part's name may have its
## number after it in brackets, or before it ("3001p0a Snout, Fangs and
## Whiskers Pattern"), as the lists write them.
func _is_name(text: String) -> bool:
	# A tile's name wrapped onto two lines ("Plate 2×2\nCorner").
	if _plain_names.has(_plain(text.replace("\n", " "))):
		return true
	# Its lines and the parts " · " and " — " join first, as a name may have
	# a full stop in it ("Head Alien E. T. (27956) · 2"), then every join.
	return _names_between(text, _ROWS) or _names_between(text, _JOINS)


func _names_between(text: String, joins: RegEx) -> bool:
	for piece: String in joins.sub(text.strip_edges(), "\n", true).split("\n"):
		piece = piece.strip_edges()
		# A name may end in a full stop of its own ("Head Alien E. T."),
		# else the stop ends a sentence.
		if _names.has(piece) or _plain_names.has(_plain(piece)):
			continue
		piece = piece.trim_suffix(".")
		if piece.is_empty() or not RegEx.create_from_string(r"\p{L}").search(piece) \
				or _names.has(piece) or _KEY.search(piece) or _FILE.search(piece) \
				or _ADDRESS.search(piece) or _plain_names.has(_plain(piece)) \
				or _GLOBS.search(piece) or _LEGAL.search(piece) or _VERSIONED.search(piece):
			continue
		var bracketed: RegExMatch = RegEx.create_from_string(r"^(.*) \(([^()]+)\)$").search(piece)
		var counted: RegExMatch = _COUNTED.search(piece)
		if _MEASURE.search(piece) or _numbered(piece, "") \
				or _numbered(piece.get_slice(" ", 0), piece.substr(piece.find(" ") + 1)) \
				or bracketed != null and _numbered(bracketed.get_string(2), bracketed.get_string(1)) \
				or counted != null and _plain_names.has(_plain(counted.get_string(1))):
			continue
		return false
	return true


## Whether [param shown] is part [param id]'s name, or the end of it as a
## list shortens it ("Head - Hollow Stud" of "Keychain Minifig Head -
## Hollow Stud"), with the number beside it, or a part's number alone
## ([param shown] empty). Not any words by a number: "1" and "12" are
## parts' numbers too, and counts.
func _numbered(id: String, shown: String) -> bool:
	var library: PartLibrary = _main.get("_library") if _main != null else null
	if library == null or not library.parts.has(id):
		return false
	if shown.is_empty():
		return true
	var plain: String = _plain(shown)
	return _plain_names.has(plain) \
		or _plain((library.parts[id] as PartLibrary.PartInfo).name).ends_with(" " + plain)


## [param name] as names are compared: lower case, one space between words,
## sizes written one way (1 x 2), and without "Minifig", which a figure's
## lists leave off.
func _plain(name: String) -> String:
	var out: String = name.to_lower().replace("×", " x ").replace("minifig ", "")
	return " ".join(out.split(" ", false))


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
	_brick = world.add_brick("3001", 4, where)
	builder.register(_brick, "3001", where)
	builder.select_brick(_brick, false)
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
	# What the panels say, and the lines along the foot, with a part
	# selected and with none, the assistant's panel open: but the names of
	# the parts, on the bin's tiles and the properties, and of the colours.
	var library: PartLibrary = _main.get("_library")
	for code: int in library.colors:
		var colour: PartLibrary.BrickColor = library.colors[code]
		_names[colour.name] = true
		_names["%s (%d)" % [colour.name, code]] = true
		if not colour.lego_name.is_empty():
			_names["LEGO® %s%s" % [colour.lego_name.replace("_", " "),
				(" %d" % colour.lego_ids[0]) if not colour.lego_ids.is_empty() else ""]] = true
	_names[Inventory._tidy((library.parts["3001"] as PartLibrary.PartInfo).name)] = true
	for model: Dictionary in Brain.CHOICES:
		_names[str(model["name"])] = true
	# And a shop's, on the button that sends a list to it.
	for name: String in ["Claude", "Claude Code", "BrickLink"]:
		_names[name] = true
	var bin: PartsBin = _main.get("_bin")
	for selected: bool in [true, false]:
		if not selected:
			builder.clear_selection()
			await _frames(6)
		for dock_name: String in ["_bin_dock", "_props_dock"]:
			var dock: SideDock = _main.get(dock_name)
			if dock != null:
				_walk("panels", dock, [bin.get("_grid")])
		# ...and the column on the right open, the model tree and all the
		# properties, which take the properties from under the bin.
		var right: SideDock = _main.get("_props_dock")
		if right != null and not right.is_open():
			right.set_open(true, false)
			await _frames(10)
			_walk("panels", right, [])
		_walk("the foot's lines", _shell.status, [])
		_walk("the foot's lines", _main.get("_hint"), [])
	# The properties of several parts selected, and of a sub-assembly
	# selected whole, which say other things (its parts, Edit inside, Make
	# unique); the sub-assembly made for it and taken back.
	var right_dock: SideDock = _main.get("_props_dock")
	for brick: BrickWorld.Brick in world.bricks():
		if brick.id != _brick:
			builder.select_brick(_brick, false)
			builder.select_brick(brick.id, true)
			break
	await _frames(6)
	_walk("panels", right_dock, [])
	builder.select_brick(_brick, false)
	_names["Probe group"] = true
	if not _shell.assemblies.make("Probe group").is_empty():
		# Once the properties say it, as a person reads them.
		for _n: int in 120:
			if str(_shell.inspector.get("_title").text) == "Probe group":
				break
			await process_frame
		_check("the properties of a sub-assembly selected whole read (%s)" %
			str(_shell.inspector.get("_title").text),
			str(_shell.inspector.get("_title").text) == "Probe group")
		_walk("panels", right_dock, [])
		_shell.run("undo")
		await _frames(4)
	builder.clear_selection()
	await _frames(4)
	# The tiles' tooltips, a few of them, whose name and number are names
	# and the rest words of the interface; and a fold's count's.
	var tiles: int = 0
	for tile: Node in (bin.get("_grid") as Node).find_children("*", "Button", true, false):
		var tip: String = (tile as Button).tooltip_text
		if tiles < 6 and (tile.has_meta("part") or (tile as Button).text.begins_with("+")):
			_add("panels", tip, tile)
			tiles += 1
	# The view cube's faces, which it draws itself.
	var cube: ViewCube = _main.get("_gizmo")
	if cube != null:
		for face: Dictionary in ViewCube.FACES:
			_add("panels", str(face["name"]), cube)
	var chat: SideDock = _main.get("_chat_dock")
	if chat != null:
		chat.set_open(true, false)
		await _frames(10)
		_walk("panels", chat, [])
		chat.set_open(false, false)
		await _frames(4)
	var named: Dictionary = _main.call("_page_controls")
	for name: String in ["outliner", "properties"]:
		if named.get(name) is Button:
			var header: Button = named[name]
			_add("panel titles", header.text, header)
			_add("panel titles", header.tooltip_text, header)
	# The model tree's first row, the model itself: the rows under it are
	# its sub-models, named by whoever built it.
	var top: TreeItem = (_shell.outliner.get("_tree") as Tree).get_root()
	if top != null:
		_add("panels", top.get_text(0), _shell.outliner)
		_add("panels", top.get_tooltip_text(0), _shell.outliner)
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
	# And with the assistant off, whose note says what that leaves out; on
	# again after, as the rest of the walk reads it.
	_main.call("set_assistant", false)
	controls.call("_show_assistant_choice")
	await _frames(6)
	_walk("settings", controls.get("_settings"), [controls.language_choice,
		controls.get("_version")])
	_main.call("set_assistant", true)
	controls.call("_show_assistant_choice")
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


# -- the status line and the dialogs -------------------------------------------

## The status line's answer to the commonest things a person does, each done
## as the menus or the keys do it: what the bar says (ModelBar.said), what
## Working shows while it lasts, and the line each tool and Check stability
## leave there.
func _gather_status() -> void:
	var bar: ModelBar = _main.get("_bar")
	var builder: Builder = _main.get("_builder")
	var verbs: EditVerbs = _shell.verbs
	var heard: Array[String] = []
	var hear: Callable = func(text: String) -> void:
		if not text.is_empty() and not heard.has(text):
			heard.append(text)
	bar.said.connect(hear)
	var watch: Callable = func() -> void:
		for job: Working.Job in Working._jobs:
			hear.call(job.words)
		hear.call(_shell.balance_line())
	process_frame.connect(watch)
	var store: ModelStore = _main.get("_store")
	_names[store.title] = true
	_names[bar.model_name()] = true
	# Every part's name, as LDraw, a tile and a list write it.
	var library: PartLibrary = _main.get("_library")
	for part_id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[part_id]
		_plain_names[_plain(info.name)] = true
		_plain_names[_plain(PartsBin.tile_name(info))] = true
		_plain_names[_plain(Inventory._tidy(info.name))] = true
		# And as a hose's list and a figure's slots shorten it.
		_plain_names[_plain(Flex.item_name("", library, part_id))] = true
		_plain_names[_plain(MinifigDialog._short(info.name))] = true
	# Each on the part put down, selected.
	var on_it: Callable = func() -> void:
		builder.select_brick(_brick, false)
	var nothing: Callable = func() -> void:
		builder.clear_selection()
	var steps: Array = [
		[nothing, "undo"], [nothing, "redo"], [nothing, "copy"], [nothing, "hide"],
		[nothing, "paste"], [nothing, "swing"], [nothing, "mirror"],
		[on_it, "copy"], [on_it, "paste"], [on_it, "put_away"], [on_it, "duplicate"],
		[on_it, "put_away"], [on_it, "hide"], [nothing, "show_all"], [on_it, "isolate"],
		[nothing, "show_all"], [on_it, "lock"], [nothing, "unlock"], [on_it, "paint"],
		[on_it, "mirror"], [nothing, "undo"], [nothing, "redo"], [on_it, "swing"],
		[on_it, "select_colour"], [on_it, "select_part"], [on_it, "select_alike"],
		[on_it, "select_connected"], [on_it, "select_submodel"], [on_it, "cut_parts"],
		[nothing, "undo"], [on_it, "delete"], [nothing, "undo"], [on_it, "split_parts"],
		[nothing, "undo"], [on_it, "merge_parts"], [nothing, "stability"], [nothing, "measure"],
		[nothing, "measure"], [nothing, "ortho"], [nothing, "ortho"], [nothing, "hold"],
		[nothing, "rotate_held"], [nothing, "tip_held"], [nothing, "put_away"],
		[nothing, "save"], [nothing, "reseat"], [on_it, "step_new"], [nothing, "undo"],
		[nothing, "select_all"], [nothing, "select_none"], [on_it, "make_unique"]]
	for tool: String in ["select", "move", "rotate", "hinge", "connect", "clone", "paint", "hide",
			"delete", "orbit", "pan", "zoom"]:
		steps.append([nothing, "tool " + tool])
	for step: Array in steps:
		(step[0] as Callable).call()
		await _frames(2)
		var what: String = step[1]
		match what:
			"put_away":
				verbs.put_away()
			"hold":
				_main.call("_on_part_chosen", "3001")
			_:
				if what.begins_with("tool "):
					_shell.run("mode_" + what.trim_prefix("tool "))
					await _frames(3)
					hear.call(verbs.hint())
					if _shell.stress != null:
						hear.call(_shell.stress.line())
				else:
					_shell.run(what)
		# Until any work it began is done, as a person waits for it.
		for _n: int in 600:
			await process_frame
			if Working._jobs.is_empty() and not BookletMaker.busy:
				break
		await _frames(4)
		hear.call(verbs.hint())
	verbs.put_away()
	verbs.set_mode("select")
	builder.clear_selection()
	await _frames(4)
	process_frame.disconnect(watch)
	bar.said.disconnect(hear)
	var hint: Label = _shell.status.get("_hint")
	for text: String in heard:
		_add("status lines", text, hint)
	print("  the status line said %d things over %d actions" % [heard.size(), steps.size()])


## The dialogs a person meets in a first hour, as the commands that open
## them: each opened with the part selected, the words it shows read, and
## closed again.
const DIALOGS: Array[String] = ["sign_in", "sign_in_code", "sign_in_waiting",
	"sign_in_unreachable", "sign_in_age", "sign_in_thanks", "open", "open_file", "library", "save_as", "versions",
	"compare", "export_3d", "render", "render_queue", "pose", "share", "together", "comments",
	"account", "pattern", "select_find", "find_colour", "flex", "reference", "parts_list",
	"collection", "collection_need", "collection_build", "make_submodel", "step_to", "timeline",
	"minifig", "mosaic", "brickify", "part_maker", "print_part", "sticker", "simulate",
	"hidden_colours", "connector", "feedback", "about", "floor_custom", "palette", "clear", "new"]

## The dialogs pictured in each language (--shots).
const PICTURED: Array[String] = ["sign_in", "sign_in_code", "clear", "save_as", "versions", "render",
	"share", "parts_list", "about", "export_3d", "library"]


func _gather_dialogs() -> void:
	var store: ModelStore = _main.get("_store")
	for entry: ModelStore.Entry in store.list_examples() + store.list_saved():
		_names[entry.name] = true
	# About's credits: whose work, and the links to it.
	for one: Dictionary in Credits.LIST:
		_names[str(one["name"])] = true
		for link: Array in one["links"]:
			_names[str(link[0])] = true
	var counts: Dictionary = {}
	for name: String in DIALOGS:
		var shown: Array = await _show(name)
		# What can I build?'s models and sets are names.
		var collection: CollectionDialog = _shell.collection
		if collection != null:
			for candidate: Dictionary in collection.get("_ranked"):
				_names[str(candidate["name"])] = true
				# A set's model is "Micro Wheels — Forklift", its two names.
				for piece: String in str(candidate["name"]).split(" — "):
					_names[piece.strip_edges()] = true
		# The Library's makers, as its cards credit them ("by %s · CCAL 2.0").
		for card: Dictionary in ([] if _shell.library_dialog == null else _shell.library_dialog.get("_shown")):
			var by: String = str(card["credit"]).get_slice(" · ", 0)
			if by.begins_with("by "):
				_names[by.trim_prefix("by ")] = true
		if name == "library":
			# Reached, its sets and their themes, or the run proves nothing
			# of them (they come from the store).
			var library: LibraryDialog = _shell.library_dialog
			var themes: int = (library.get("_theme") as OptionButton).item_count - 1
			_check("the Library's sets and themes reached (%d themes, %d sets shown)" % [themes,
				(library.get("_shown") as Array).size()],
				themes > 0 and not (library.get("_shown") as Array).is_empty())
		var read: int = 0
		for pair: Array in shown[1]:
			if not _is_data(pair[0]):
				_add("dialogs", str(pair[1]), pair[0])
				read += 1
		counts[name] = read
		await _close(name, shown[0])
	print("  dialogs read: %s" % ", ".join(counts.keys().map(func(n: String) -> String:
		return "%s %d" % [n, counts[n]])))


## The dialog [param name] opened with the part selected: [what it put on
## screen, as the nodes newly shown whose parents were shown already; each
## word newly shown, as [node, word]].
func _show(name: String) -> Array:
	(_main.get("_builder") as Builder).select_brick(_brick, false)
	if name == "find_colour":
		# Its colours are in the parts' column, shut first so that they
		# count as what it showed.
		(_main.get("_bin_dock") as SideDock).set_open(false, false)
	await _frames(3)
	var before: Dictionary = _visible_now()
	await _open_dialog(name)
	await _frames(20)
	for _n: int in 300:
		if Working._jobs.is_empty():
			break
		await process_frame
	await _frames(4)
	var after: Dictionary = _visible_now()
	var opened: Array[Node] = []
	var words: Array = []
	for key: String in after:
		if before.has(key):
			continue
		var pair: Array = after[key]
		var node: Node = pair[0]
		if pair[1] != null:
			words.append(pair)
		elif node is Window or node.get_parent() == null \
				or before.has(_seen_key(node.get_parent(), null)):
			# A window anywhere in it, a file chooser under a node of its
			# own, closed with it.
			opened.append(node)
	return [opened, words]


func _open_dialog(name: String) -> void:
	var bar: ModelBar = _main.get("_bar")
	match name:
		"sign_in", "sign_in_code", "sign_in_waiting", "sign_in_unreachable", "sign_in_age", \
				"sign_in_thanks":
			await _open_sign_in(name)
		"save_as":
			# The web's own; the desktop's is the platform's Save dialog.
			(_shell.get("_save_as") as Window).popup_centered()
		"open_file":
			bar.call("_import")
		"library":
			# Its sets once they come from the store, as a person waits for
			# them: their names, themes and makers are read as names, every
			# run alike, not only when the store answered in time.
			_shell.run("library")
			for _n: int in 900:
				if not (_shell.library_dialog.get("_shown") as Array).is_empty():
					break
				await process_frame
		"timeline":
			_main.call("_toggle_steps")
		"new":
			# Asked only over a change not saved: one made first (the part
			# selected taken off, put back after), else it would start a new
			# model. A mirror of a 2 x 4 is the same 2 x 4, nothing changed.
			_shell.run("delete")
			await _frames(4)
			if (_main.get("_store") as ModelStore).has_unsaved_work():
				_shell.run("new")
			else:
				print("    new: not asked, as nothing is unsaved")
		_:
			if not _shell.run(name):
				print("    %s: not run (%s)" % [name, _shell.why_not(name)])


## The way in, which a probe's window never shows (Main._gate_wanted): made
## on the app's own account for each of its faces, as the account's state
## would show it, the state put back at once so that nothing else follows
## it. Mistakes the form answers itself are made, the field left empty.
var _gate: SignInGate


func _open_sign_in(name: String) -> void:
	var account: Account = _main.get("_account")
	_gate = SignInGate.new()
	_gate.setup(account)
	_main.get_node("HUD").add_child(_gate)
	var was: Array = [account.state, account.age_ask]
	account.state = {"sign_in_waiting": Account.State.CHECKING,
		"sign_in_unreachable": Account.State.UNREACHABLE, "sign_in_age": Account.State.SIGNED_IN,
		"sign_in_thanks": Account.State.SIGNED_IN}.get(name, Account.State.SIGNED_OUT)
	account.age_ask = name == "sign_in_age"
	_gate.set("_thanking", name == "sign_in_thanks")
	_gate.call("_follow")
	account.state = was[0]
	account.age_ask = was[1]
	var form: SignInForm = _gate.get("_form")
	# The form's own start, which shows orangecheck as the deployment says.
	await _frames(2)
	match name:
		"sign_in":
			# orangecheck as a deployment that offers it shows it.
			(form.get("_orangecheck") as Control).visible = true
			(form.get("_orangecheck_why") as Control).visible = true
			form.call("_ask")
		"sign_in_code":
			(form.get("_email") as LineEdit).text = "builder@example.org"
			form.call("_show", SignInForm.Step.CODE)
			form.call("_redeem")
		"sign_in_age":
			_gate.call("_answer")


## What [param opened] for [param name] put on screen, closed again.
func _close(name: String, opened: Array[Node]) -> void:
	if name == "timeline":
		_main.call("_toggle_steps")
	for node: Node in opened.duplicate():
		if is_instance_valid(node) and not node is Window:
			for window: Node in node.find_children("*", "Window", true, false):
				if (window as Window).visible:
					opened.append(window)
	for node: Node in opened:
		if not is_instance_valid(node):
			continue
		if node is Window:
			(node as Window).hide()
		elif node.has_method("close"):
			node.call("close")
		elif node is Control and node.get_parent() != null and not node.get_parent() is Container:
			(node as Control).visible = false
	# What a dialog opened that is not under it: a file chooser of its own
	# (brickify's), the hose tool's panel, and the panels in the side dock.
	for chooser: Node in root.find_children("*", "FileDialog", true, false):
		(chooser as Window).hide()
	var flex: Node = _main.get("_flex")
	if flex != null and bool(flex.get("active")):
		flex.call("leave")
	for panel_name: String in ["_hidden_colours", "_pose", "_simulate"]:
		var panel: Control = _main.get(panel_name)
		if panel != null and panel.visible:
			panel.call("close")
	if _gate != null:
		_gate.queue_free()
		_gate = null
	await _frames(6)
	if name == "new":
		_shell.run("undo")
		await _frames(4)
	(_main.get("_builder") as Builder).clear_selection()
	_shell.verbs.put_away()
	_shell.verbs.set_mode("select")
	await _frames(3)


## Every visible node, and every word shown on one, as keys: a node alone
## (the second of its pair null) and a node's word.
func _visible_now() -> Dictionary:
	var out: Dictionary = {}
	_visible_under(root, out)
	return out


func _visible_under(node: Node, out: Dictionary) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Window and node != root and (not (node as Window).visible
			or Tooltips.is_tooltip(node as Window)):
		return
	out[_seen_key(node, null)] = [node, null]
	for text: String in _texts_of(node):
		out[_seen_key(node, text)] = [node, text]
	for child: Node in node.get_children(true):
		_visible_under(child, out)


func _seen_key(node: Node, text: Variant) -> String:
	return "%d|%s" % [node.get_instance_id(), "" if text == null else "|" + str(text)]


## The words [param node] shows itself, as _walk reads them, and a window's
## title, a menu button's rows, a spin box's ends and a tab's title.
func _texts_of(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is PopupMenu:
		for n: int in (node as PopupMenu).item_count:
			out.append((node as PopupMenu).get_item_text(n))
			out.append((node as PopupMenu).get_item_tooltip(n))
	if node is Window:
		out.append((node as Window).title)
		return out.filter(func(text: String) -> bool: return not text.strip_edges().is_empty())
	if node is Label:
		out.append((node as Label).text)
	elif node is RichTextLabel:
		out.append((node as RichTextLabel).text)
	elif node is OptionButton:
		for n: int in (node as OptionButton).item_count:
			if (node as OptionButton).get_item_auto_translate_mode(n) != Node.AUTO_TRANSLATE_MODE_DISABLED:
				out.append((node as OptionButton).get_item_text(n))
	elif node is MenuButton:
		out.append((node as MenuButton).text)
		var popup: PopupMenu = (node as MenuButton).get_popup()
		for n: int in popup.item_count:
			out.append(popup.get_item_text(n))
			out.append(popup.get_item_tooltip(n))
	elif node is Button:
		out.append((node as Button).text)
	elif node is LinkButton:
		out.append((node as LinkButton).text)
	elif node is LineEdit:
		out.append((node as LineEdit).placeholder_text)
	elif node is TextEdit:
		out.append((node as TextEdit).placeholder_text)
	elif node is TabBar:
		for n: int in (node as TabBar).tab_count:
			out.append((node as TabBar).get_tab_title(n))
	elif node is SpinBox:
		out.append((node as SpinBox).prefix)
		out.append((node as SpinBox).suffix)
	if node is Control:
		out.append((node as Control).tooltip_text)
	return out.filter(func(text: String) -> bool: return not text.strip_edges().is_empty())


## Whether [param node] shows data rather than the interface's words: a
## typed field's own text, the rows of a list (models, sets, parts, people),
## a file's name in the file chooser.
func _is_data(node: Node) -> bool:
	if node is LineEdit and not (node as LineEdit).editable:
		return false
	# Set to be drawn as it is, its words a name (a sub-model's, a set's): a
	# control's own choice, as a dialog kept out of translation whole is not.
	if node.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED:
		return true
	var at: Node = node
	while at != null:
		if at is ItemList or at is Tree:
			return true
		if at.has_meta(&"names") or str(at.name) in ["cards", "results", "rows"]:
			return true
		at = at.get_parent()
	return false


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
	elif node is LinkButton:
		_add(kind, (node as LinkButton).text, node)
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
			# Names learnt after it was read (the parts', by _gather_status):
			# "1 × Brick 2 x 4\n1 × Tyre 6/ 50 x 8 Offset Tread".
			if said.is_empty() and _is_name(english):
				same += 1
				continue
			if said.is_empty():
				lacking.append(english)
				(_missing[code] as Array).append([english, english])
				continue
			# Translated but for words it keeps in English that are not a
			# name or a key: a pattern's place, or a line, with no entry.
			var left: Array[String] = []
			for kept: String in Language.left_in_english(english):
				if not _is_name(kept):
					left.append(kept)
			if not left.is_empty():
				lacking.append("%s (%s)" % [english, ", ".join(left)])
				for kept: String in left:
					(_missing[code] as Array).append([kept, english])
				continue
			if said == english:
				same += 1
			var drawn: Variant = word[1]
			if is_instance_valid(drawn) and (drawn as Node).atr(english) != said:
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
	# Find a command finds it by the words it is drawn with, and by English's.
	var typed: String = {"de": "speichern", "fr": "enregistrer", "es": "guardar"}[code]
	var found: Array[String] = _shell.palette.matches(typed)
	var english: Array[String] = _shell.palette.matches("save")
	_check("%s: Find a command, \"%s\" finds Save first (%s), and \"save\" still does (%s)" % [
		code, typed, ", ".join(found.slice(0, 3)), ", ".join(english.slice(0, 3))],
		not found.is_empty() and found[0] == "save" and not english.is_empty() and english[0] == "save")
	await _two_senses(code)
	await _themes(code)
	var version: String = BuildInfo.describe()
	_check("%s: a release's version line, in Settings and About, reads \"%s\"" % [code,
		Language.says(version)], " released " in version and not Language.says(version).is_empty())
	await _pictures(code)


## The Library's themes as LEGO's own sites in each language have them:
## those that are words (ModelLibrary.THEME_WORDS) by their entries in the
## context "theme", in the list and in every theme the library's sets have
## ("City > Police"); the rest, product lines' and licences' names, as they
## are; the list in the language's order. The list pictured open.
func _themes(code: String) -> void:
	var shown: Array = await _show("library")
	var library: LibraryDialog = _shell.library_dialog
	var choice: OptionButton = library.get("_theme")
	var lacking: Array[String] = []
	var wrong: Array[String] = []
	var kept: Array[String] = []
	var unordered: Array[String] = []
	for n: int in range(1, choice.item_count):
		if n > 1 and choice.get_item_text(n) < choice.get_item_text(n - 1):
			unordered.append("%s after %s" % [choice.get_item_text(n), choice.get_item_text(n - 1)])
		var english: String = str(choice.get_item_metadata(n))
		var said: String = english
		if english in ModelLibrary.THEME_WORDS:
			said = Language.says(english, "theme")
			if said.is_empty():
				lacking.append(english)
				continue
		else:
			kept.append(english)
		if choice.get_item_text(n) != said:
			wrong.append("%s drawn \"%s\"" % [english, choice.get_item_text(n)])
	var words: Dictionary = {}
	for model: Dictionary in library.books.get("_models"):
		for part: String in ModelLibrary.tidy(str(model.get("theme", ""))).split(" > "):
			if part in ModelLibrary.THEME_WORDS:
				words[part] = true
	for part: String in words:
		if Language.says(part, "theme").is_empty() and not part in lacking:
			lacking.append(part)
	_check("%s: the Library's %d themes, %d names kept (%s, ...) and the rest translated, " % [code,
		choice.item_count - 1, kept.size(), ", ".join(kept.slice(0, 5))]
		+ "with the %d words in its sets' themes, in the language's order%s" % [words.size(),
		"" if lacking.is_empty() and wrong.is_empty() and unordered.is_empty()
			else "; lacking %s; %s; %s" % [lacking, wrong, unordered.slice(0, 3)]],
		choice.item_count > 1 and lacking.is_empty() and wrong.is_empty() and unordered.is_empty())
	if not _shots.is_empty():
		choice.show_popup()
		await _frames(8)
		await _shot("%s_library_themes" % code)
		choice.get_popup().hide()
		await _frames(3)
	# Its count of sets, in the thousands: "1,575 of 1,575 sets".
	var status: Label = library.get("_status")
	var counted: RegExMatch = RegEx.create_from_string(r"\d{1,3}(,\d{3})+").search(status.text)
	var drawn: String = status.atr(status.text)
	_check("%s: a count of thousands grouped as the language groups it (\"%s\" drawn \"%s\")" % [
		code, status.text, drawn], counted != null
		and counted.get_string().replace(",", str(THOUSANDS[code])) in drawn
		and not counted.get_string() in drawn)
	await _close("library", shown[0])


## A word with a second sense, and a name that is a word too: Render's
## backdrop "White" is the language's (its entry by context) while LDraw's
## colour White stays a name; a sub-model named Car stays Car in the model
## tree, though the parts' columns say Car in the language.
func _two_senses(code: String) -> void:
	var shown: Array = await _show("render")
	var render: RenderDialog = _main.get("_render")
	var white: Button = render.controls_by_name()["render_bg_white"]
	var backdrop: String = TranslationServer.translate("White", "backdrop")
	var colour: String = TranslationServer.translate("White")
	_check("%s: Render's backdrop reads \"%s\", its own entry, and the colour White \"%s\"" % [
		code, white.text, colour], white.text == backdrop and backdrop != "White" and colour == "White")
	await _close("render", shown[0])
	# The model tree open in the column on the right, where a person reads it
	# (folded, it is not worked out).
	(_main.get("_props_dock") as SideDock).set_open(true, false)
	_shell.outliner.set_open(true)
	(_main.get("_builder") as Builder).select_brick(_brick, false)
	var made: String = _shell.assemblies.make("Car")
	await _frames(10)
	if not _shots.is_empty():
		await _shot("%s_model_tree_submodel" % code)
	var row: TreeItem = null
	var rows: Array[String] = []
	var top: TreeItem = (_shell.outliner.get("_tree") as Tree).get_root()
	for under: TreeItem in ([] if top == null else top.get_children()):
		rows.append(under.get_text(0))
		if under.get_text(0) == "Car":
			row = under
	_check("%s: the model tree's sub-model Car reads Car (the parts' word is \"%s\"; rows %s)" % [
		code, Language.says("Car"), rows], not made.is_empty() and row != null
		and Language.says("Car") != "Car"
		and row.get_auto_translate_mode(0) == Node.AUTO_TRANSLATE_MODE_DISABLED)
	# And where a line of the interface names it, as the status bar does a
	# model just opened.
	var opened: String = Language.says("opened Car — 61 bricks")
	_check("%s: \"opened Car — 61 bricks\" reads \"%s\", the name kept" % [code, opened],
		"Car" in opened and not Language.says("Car") in opened)
	_shell.run("undo")
	await _frames(4)


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
	# The panels open, the part selected.
	for dock_name: String in ["_bin_dock", "_props_dock"]:
		var dock: SideDock = _main.get(dock_name)
		if dock != null:
			dock.set_open(true, false)
	(_main.get("_builder") as Builder).select_brick(_brick, false)
	await _frames(10)
	await _shot("%s_panels" % code)
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
	for name: String in PICTURED:
		var shown: Array = await _show(name)
		await _shot("%s_dialog_%s" % [code, name])
		await _close(name, shown[0])
	# And the status line after an action.
	(_main.get("_builder") as Builder).select_brick(_brick, false)
	_shell.run("copy")
	await _frames(8)
	await _shot("%s_status_copied" % code)
	(_main.get("_builder") as Builder).clear_selection()


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
	await _german_tooltips()
	await _shot("de_whole")


## The toolbar's widest tooltips in German rested on until they show: each
## laid out at most Tooltips.WIDEST wide, measured as drawn, not as the
## English it was given, and inside the window.
func _german_tooltips() -> void:
	var widest: Array = []
	for name: String in _shell.toolbar.controls_by_name():
		var tool: Control = _shell.toolbar.controls_by_name()[name]
		if tool.tooltip_text.is_empty() or not tool.is_visible_in_tree():
			continue
		var font: Font = tool.get_theme_default_font()
		var longest: float = 0.0
		for line: String in tool.atr(tool.tooltip_text).split("\n"):
			longest = maxf(longest, font.get_string_size(line).x)
		widest.append([longest, tool])
	widest.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var room: Rect2 = root.get_visible_rect()
	var shown: int = 0
	var worst: float = 0.0
	var wrong: Array[String] = []
	for entry: Array in widest.slice(0, 5):
		var tool: Control = entry[1]
		var tip: Window = await _tooltip_of(tool)
		if tip == null:
			wrong.append("%s showed none" % tool.name)
			continue
		await _frames(4)
		shown += 1
		var rect := Rect2(Vector2(tip.position), Vector2(tip.size))
		worst = maxf(worst, rect.size.x)
		if rect.size.x > Tooltips.WIDEST + 40.0 or not room.grow(1.0).encloses(rect):
			wrong.append("%s [%d, %d, %d, %d]" % [tool.name, rect.position.x, rect.position.y,
				rect.size.x, rect.size.y])
		if worst == rect.size.x:
			await _shot("de_tooltip")
	_move(_away())
	await _frames(6)
	_check("the toolbar's 5 widest tooltips in German shown (%d), each at most %d wide with its edges (widest %d), inside the window%s" % [
		shown, Tooltips.WIDEST + 40.0, worst, "" if wrong.is_empty() else ": " + ", ".join(wrong)],
		shown == 5 and wrong.is_empty())


## [param control] rested on until its tooltip is up, as tooltip_probe does.
func _tooltip_of(control: Control) -> Window:
	_move(_away())
	await _frames(3)
	var rect: Rect2 = control.get_screen_transform() * Rect2(Vector2.ZERO, control.size)
	var at := Vector2(rect.get_center().x, rect.end.y - minf(3.0, rect.size.y / 2.0))
	_move(at)
	await _frames(3)
	_move(at + Vector2(1, 0))
	var until: int = Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < until:
		await process_frame
		for sub: Window in root.get_embedded_subwindows():
			if Tooltips.is_tooltip(sub) and sub.visible:
				return sub
	return null


## Over the model, where nothing has a tooltip.
func _away() -> Vector2:
	return root.get_visible_rect().size * Vector2(0.55, 0.62)


## The pointer moved, as an event and, on Xvfb, for real (tooltip_probe's
## _move says why).
func _move(at: Vector2) -> void:
	var event_at: Vector2 = root.get_final_transform() * at
	if OS.get_environment("XAUTHORITY").contains("xvfb-run"):
		Input.warp_mouse(event_at)
	var event := InputEventMouseMotion.new()
	event.position = event_at
	event.global_position = event_at
	Input.parse_input_event(event)


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
		# --about, which a person reporting a bug runs from a terminal, in the
		# language chosen too: a build from source's line, with no stamp.
		var about: Array = []
		OS.execute(OS.get_executable_path(), ["--headless", "--path",
			ProjectSettings.globalize_path("res://"), "--", "--about"], about, true)
		var said: String = ""
		for line: String in "\n".join(about).split("\n"):
			if line.begins_with("Brickworks "):
				said = line
		var english: String = "Brickworks %s, development build" % BuildInfo.version()
		_check("--about says \"%s\", German as chosen" % said,
			said == Language.says(english) and said != english)
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
		for pair: Array in _missing[code]:
			var english: String = pair[0]
			# The words it was found in, where it is a part of them.
			if pair[1] != english:
				out.store_line("#. in: %s" % str(pair[1]).c_escape().replace("\\'", "'"))
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
