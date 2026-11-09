## Every control a person can press, type in or choose from has a name a
## screen reader can say, in English and in German.
##
##   godot --path . --resolution 1400x900 --script src/dev/a11y_names_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh a11y_names_probe
##   ... -- openers=settings,keys   of the menus' commands, only these
##   ... -- --shots=DIR             a picture of each dialog and panel walked, kept there
##
## Godot 4.7 tells a screen reader about the interface through AccessKit:
## each control's accessibility_name, or for a button its words, for a
## field its placeholder (Control._get_accessibility_name and its
## overrides, which this follows). A button with no words and no name is
## read by its tooltip, and here a tooltip is help: "3001\nBrick 2 x 4\n2 x 4
## studs, 1 brick\nRight-click to keep it in Favourites…" is a paragraph
## read out every time the tile is reached. So a name read from a tooltip of
## more than one line is counted as no name. A choice (OptionButton) says
## what is chosen as its words: that is its value, and its name is what it
## chooses, so a choice needs a name of its own ("Fill: Plates").
##
## Each control is read in English and in German: as Language.apply("de")
## puts German in the TranslationServer, its words (Language.Words) read
## through as Godot reads them, a name through tr() and a button's words
## and a field's placeholder through atr(), without putting the window in
## German each time (the whole window is laid out again then, 2 s a time,
## 400 s a run). A button with neither words nor a name Godot reads by its
## tooltip as it is, in English, though the app has the German: that is
## no name in German. Nor is a name a screen reader alone hears (an
## accessibility_name) with no German at all, unless it is a name of
## something (a part's, a colour's, a model's, an address); words drawn on
## screen are the languages probe's to check. At the end the window is put
## in German as Settings puts it, and the launch, My collection and
## Settings are read again through the engine itself.
##
## Through the way in, as a person comes: the sign-in screen up over the
## app (gate_for_probe), walked, then a throwaway account signed in (made
## with the admin key and a password, as a11y_modal_probe does) and the
## account deleted at the end. Needs .env.
##
## Then the whole scene from launch, a selection's properties, the bin's
## tabs, every dialog and panel the menus open (OPENERS, which
## a11y_modal_probe walks too, and MORE), those that ask for a part
## selected, the ways a11y_modal_probe brings a dialog up (New's question,
## Import's chooser, Save as and its "replace it?", the Reference picture),
## the ones dialog_look_probe opens by hand (the photo search's question and
## chooser, Print's chooser, Saved models and its questions, the other
## choosers, the 3D export's question, a sub-assembly's name, a section's
## report, the menus), every other dialog and menu in the window popped up
## as dialog_look_probe pops them, and the Settings with its AI page. Each
## visible control with no name is counted once, however often it was
## seen. Every menu's every item is read too, open or not. It fails with
## the count and a line for each, and passes at none.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _bin: PartsBin
var _shots: String = ""
var _email: String = ""
var _password: String = ""
## instance id -> a line saying what it is, for each control with no name
var _unnamed: Dictionary = {}
## the same, for each with no name in German
var _unnamed_de: Dictionary = {}
## instance ids of every operable control seen, named or not
var _seen: Dictionary = {}
## What has been walked, by name, for the summary.
var _walked: PackedStringArray = []
## Windows already popped up and walked, by instance id.
var _windows_walked: Dictionary = {}
## The app's German, as Language.apply("de") makes it.
var _de: Translation
## Every LDraw colour's name, in English: a colour is said by its name.
var _colours: Dictionary = {}
## Whether the window is in German now, for the last walks.
var _in_german: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Godot's own Save dialog, never the platform's: this shell's session
	# bus is the owner's, and theirs would open on their screen.
	SaveTo.native = false
	_main = load("res://src/main.tscn").instantiate()
	# The sign-in screen over the app, as a person opening it meets it.
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	for _n: int in 30:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_shell = _main.get("_shell")
	_bin = _main.get("_bin")
	var words: Language.Words = Language.Words.new(load("res://locale/de.po") as Translation)
	words.locale = "de"
	words.capitals = "de" in Language.CAPITALISED
	words.thousands = str(Language.THOUSANDS["de"])
	_de = words
	if not await _way_in():
		await _finish()
		return
	var store: ModelStore = _main.get("_store")
	store.keeps = false
	var library: PartLibrary = _main.get("_library")
	for code: int in library.colors:
		_colours[(library.colors[code] as PartLibrary.BrickColor).name] = true
	_main.call("clear_model")
	await _frames(6)
	_walk_all("launch")

	# A part on the model, selected, so the properties show it.
	var builder: Builder = _main.get("_builder")
	var world: BrickWorld = _main.get("_world")
	var where := Transform3D(Basis.IDENTITY, Vector3(0, 24, 0))
	var brick: int = world.add_brick("3001", 4, where)
	builder.register(brick, "3001", where)
	builder.select_brick(brick, false)
	await _frames(6)
	_walk_all("a selection")
	for name: String in WITH_A_SELECTION + MORE_WITH_A_SELECTION:
		builder.select_brick(brick, false)
		await _frames(2)
		await _open_and_walk(name)

	# The bin's tabs, each in turn.
	for tab: String in [PartsBin.RECENT, PartsBin.FAVOURITES, PartsBin.TECHNIQUES]:
		_bin.call("show_category", tab)
		await _frames(8)
		_walk_all("the bin's " + tab)
	_bin.call("show_category", "All")
	await _frames(4)

	# Every dialog and panel the menus open, one at a time, put away
	# before the next.
	# A few by name, after --: openers=settings,keys.
	var openers: Array[String] = OPENERS + MORE
	var all: bool = true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("openers="):
			openers.assign(arg.trim_prefix("openers=").split(",", false))
			all = false
	for name: String in openers:
		await _open_and_walk(name)
	# Settings, AI, its whole form shown: another AI chosen.
	if openers.has("settings"):
		var settings: ControlsDialog = _main.get("_controls")
		settings.open_ai()
		settings.ai.who_key.button_pressed = true
		await _frames(12)
		_walk_all("settings, AI")
		settings.ai.who_claude.button_pressed = true
		settings.visible = false
		await _frames(4)
	if all:
		await _ways(builder, brick)
		await _by_hand()
		await _everything_else()

	# Then the window in German, as Settings puts it, and read again through
	# the engine: the launch, My collection, Settings.
	if all:
		Language.choose("de")
		_in_german = true
		await _frames(12)
		_walk_all("launch, in German")
		for name: String in ["collection", "settings"]:
			await _open_and_walk(name)
		Language.choose("en")
		_in_german = false
		await _frames(6)

	print("a11y names probe: walked %d: %s" % [_walked.size(), ", ".join(_walked)])
	_say_unnamed("have no name", _unnamed)
	_say_unnamed("have no name in German", _unnamed_de)
	_check("every control a person can operate has a name (%d of %d have none)"
		% [_unnamed.size(), _seen.size()], _unnamed.is_empty())
	_check("...and has one in German (%d of %d have none)"
		% [_unnamed_de.size(), _seen.size()], _unnamed_de.is_empty())
	_check("the walk reached past the menus' commands: %d walked" % _walked.size(),
		not all or _walked.size() >= OPENERS.size() + MORE.size())
	await _finish()


func _say_unnamed(what: String, lines_by_id: Dictionary) -> void:
	if lines_by_id.is_empty():
		return
	print("a11y names probe: %d of %d controls a person can operate %s:"
		% [lines_by_id.size(), _seen.size(), what])
	var lines: Array = lines_by_id.values()
	lines.sort()
	for line: String in lines:
		print("    " + line)


## The commands that open a dialog or a panel, as the menus run them.
## Nothing that opens the system's file chooser or leaves the app.
## a11y_modal_probe walks these too.
const OPENERS: Array[String] = [
	"settings", "keys", "about", "save_as", "library", "versions", "render",
	"pose", "instructions", "share", "clear", "account", "select_find",
	"timeline", "parts_list", "collection",
	"collection_need", "collection_build", "minifig", "mosaic", "brickify",
	"part_maker", "print_part", "sticker", "measure", "simulate",
	"hidden_colours", "panel_outliner", "stress", "cut", "floor_custom",
]

## And those that ask for a part selected first.
const WITH_A_SELECTION: Array[String] = ["make_submodel", "printed_versions", "flex"]

## The menus' other dialogs and panels, which this probe alone walks: Find
## a command, Send feedback, Build together, Comments, Compare, the render
## queue, the booklet's page setup, Go to step, a view kept, the parts the
## model needs, the panels, and the assistant's own and its connector.
const MORE: Array[String] = [
	"palette", "feedback", "together", "comments", "compare", "compare_sets",
	"render_queue", "booklet_page_setup", "step_to", "save_view", "export_3d",
	"panel_parts", "panel_properties", "panel_keys", "panel_assistant", "connector",
	"tour",
]

## With a part selected: Pattern and Replace.
const MORE_WITH_A_SELECTION: Array[String] = ["pattern", "replace", "mirror"]


func _open_and_walk(name: String) -> void:
	var before: Dictionary = _shown()
	if not _shell.run(name):
		print("  (%s cannot be run now)" % name)
		return
	var until: int = Time.get_ticks_msec() + 5000
	await _frames(12)
	while _shown().size() <= before.size() and Time.get_ticks_msec() < until:
		await process_frame
	await _frames(4)
	_walk_all(name)
	await _shot(name)
	# Its work done before it is put away (Colour the hidden parts draws its
	# pictures): a coroutine still waiting at quit broke the heap on exit.
	await _idle()
	await _put_away(before)


## Put away: Escape first, as a person would; then anything still up
## that was not before. A dialog is closed as its window's close button
## closes it, so whoever awaits its answer hears "cancelled" (SaveTo.ask
## left waiting held its dialog in a static, and the heap broke at exit).
func _put_away(before: Dictionary) -> void:
	_key(KEY_ESCAPE)
	await _frames(4)
	for id: int in _shown():
		if before.has(id):
			continue
		var thing: Object = instance_from_id(id)
		if thing is AcceptDialog and (thing as Window).visible:
			(thing as Window).close_requested.emit()
		if thing is Window and (thing as Window).visible:
			(thing as Window).hide()
		elif thing is CanvasItem:
			(thing as CanvasItem).visible = false
	await _frames(4)


## The ways a11y_modal_probe brings a dialog up besides the menus'
## commands: New over a part taken off asks first; Import's chooser
## (Godot's own); Save as's "replace it?" over a file already there; the
## Reference picture, with a picture.
func _ways(builder: Builder, brick: int) -> void:
	builder.select_brick(brick, false)
	await _frames(2)
	builder.remove_selection()
	await _frames(4)
	await _open_and_walk("new")
	await _open_and_walk("import_ldraw")
	var reference: ReferenceImage = _main.get("_reference")
	reference.take(Image.load_from_file(
		ProjectSettings.globalize_path("res://tools/release/best_car.png")), "car")
	await _open_and_walk("reference")
	# Save as, and its question over a file already there.
	var before: Dictionary = _shown()
	if _shell.run("save_as"):
		await _frames(12)
		var chooser: FileDialog = SaveTo.showing
		if chooser != null and chooser.visible:
			var path: String = chooser.current_dir.path_join(chooser.current_file)
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_string("0 a file already there\n")
				file.close()
				chooser.get_ok_button().pressed.emit()
				await _frames(12)
				_walk_all("save_as, replace it?")
				await _shot("save_as_replace")
				for sub: Window in root.get_embedded_subwindows():
					if sub is ConfirmationDialog and sub.visible and chooser.is_ancestor_of(sub):
						(sub as ConfirmationDialog).get_cancel_button().pressed.emit()
						sub.hide()
				await _frames(4)
				DirAccess.remove_absolute(path)
		await _idle()
		await _put_away(before)


## What dialog_look_probe opens by hand: the parts bin's camera's question
## and its chooser, Print's chooser, Saved models with its Delete and
## Rename questions, the other choosers, a sub-assembly's name, a section's
## report, the menus.
func _by_hand() -> void:
	# The parts bin's camera: the question, then the chooser. The picture
	# chosen goes nowhere: Brickognize is a third party.
	var button: Button = _bin.get("_photo_button")
	if button != null:
		button.pressed.emit()
		await _frames(10)
		var told: Window = _bin.get("_telling")
		if told != null and told.visible:
			await _walk_window(told, "the photo search's question")
			var picker: Node = _bin.get("_picker")
			for link: Dictionary in picker.get_signal_connection_list("picked"):
				picker.disconnect("picked", link["callable"])
			(told as AcceptDialog).get_ok_button().pressed.emit()
			await _frames(10)
			var chooser: FileDialog = picker.get("_dialog")
			if chooser != null and chooser.visible:
				await _walk_window(chooser, "the photo chooser")
			told.hide()
	var files: Node = PictureFile.new()
	root.add_child(files)
	files.call("ask")
	await _frames(10)
	var print_chooser: FileDialog = files.get("_dialog")
	if print_chooser != null and print_chooser.visible:
		await _walk_window(print_chooser, "Print's chooser")
	files.queue_free()
	await _frames(4)
	# Saved models, and its questions.
	var saved: AcceptDialog = _main.get("_saved_models")
	saved.call("open")
	await _frames(10)
	if saved.visible:
		_walk_all("saved models")
		await _shot("saved_models")
		for question_name: String in ["_confirm_delete", "_rename"]:
			var question: Window = saved.get(question_name)
			if question != null:
				await _walk_window(question, "saved models' " + question_name.trim_prefix("_"))
		saved.hide()
	# The other choosers: Open a model from a file, Brickify's, the
	# collection's list.
	var bar: Node = _main.get("_bar")
	bar.call("_import")
	await _frames(10)
	var model: FileDialog = (bar.get("_picker") as Node).get("_dialog")
	if model != null and model.visible:
		await _walk_window(model, "the Open-a-model chooser")
	var brickify: Node = _main.get("_brickify")
	if brickify != null:
		(brickify.get("_picker") as Node).call("ask")
		await _frames(10)
		var mesh: FileDialog = (brickify.get("_picker") as Node).get("_dialog")
		if mesh != null and mesh.visible:
			await _walk_window(mesh, "Brickify's chooser")
	var lists: Node = _shell.collection.get("_picker")
	lists.call("ask", ".csv,.txt")
	await _frames(10)
	var text: FileDialog = lists.get("_dialog")
	if text != null and text.visible:
		await _walk_window(text, "the collection's chooser")
	# A sub-assembly's name; a section's report.
	var verbs: Node = _main.get("_verbs")
	verbs.call("_ask_name", "rename", "Rename the sub-assembly", "Rename",
		"What is it called? Every copy of it is renamed.", "Probe")
	await _frames(10)
	var naming: Window = verbs.get("_naming")
	if naming != null and naming.visible:
		await _walk_window(naming, "a sub-assembly's name")
	_shell.sections.call("_open_dialog", {"name": "Probe section", "parts": 0})
	await _frames(10)
	var report: Window = _shell.sections.get("_dialog")
	if report != null and report.visible:
		await _walk_window(report, "a section's report")
	# The menus: File's, and a part's.
	var menus: Array = _shell.get("_menus")
	var file_menu: MenuButton = menus[0]
	file_menu.show_popup()
	await _frames(10)
	_walk_all("the File menu")
	file_menu.get_popup().hide()
	_shell.open_context(Vector2(700, 400))
	await _frames(10)
	if _shell.context != null and _shell.context.visible:
		_walk_all("a part's menu")
		_shell.context.hide()
	await _frames(4)


## Every other dialog and menu in the window, popped up and walked, as
## dialog_look_probe pops them.
func _everything_else() -> void:
	var found: Array[Window] = []
	var walk: Array[Node] = [root]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		for n: int in node.get_child_count(true):
			walk.append(node.get_child(n, true))
		var window := node as Window
		if window == null or window == root or _windows_walked.has(window.get_instance_id()):
			continue
		if Tooltips.is_tooltip(window) or not window.is_inside_tree():
			continue
		if window is AcceptDialog or window is PopupPanel:
			found.append(window)
	for window: Window in found:
		if not is_instance_valid(window) or not window.is_inside_tree():
			continue
		if window is AcceptDialog:
			(window as AcceptDialog).popup_centered()
		else:
			(window as Popup).popup(Rect2i(Vector2i(420, 140), Vector2i.ZERO))
		await _walk_window(window, _named(window))
		window.hide()
		await _frames(2)
	print("  %d more dialogs found in the window and walked" % found.size())


## [param window], up already, walked, then put away.
func _walk_window(window: Window, what: String) -> void:
	_windows_walked[window.get_instance_id()] = true
	await _frames(5)
	_walk_all(what)
	await _shot(what)
	window.hide()
	await _frames(2)


func _named(window: Window) -> String:
	return window.title if not window.title.is_empty() \
		else "%s %s in %s" % [window.get_class(), window.name, window.get_parent().name]


## The windows and the panels of the shell that are showing, by id: what
## an opener put up is what is here after it and was not before.
func _shown() -> Dictionary:
	var out: Dictionary = {}
	_gather_shown(root, out, 0)
	return out


func _gather_shown(node: Node, out: Dictionary, depth: int) -> void:
	if node is Window and node != root:
		if (node as Window).visible:
			out[node.get_instance_id()] = true
			_windows_walked[node.get_instance_id()] = true
		return
	if depth > 6:
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is CanvasItem:
		out[node.get_instance_id()] = true
	for child: Node in node.get_children(true):
		_gather_shown(child, out, depth + 1)


## Every operable control in sight read in English and in German, or in
## German alone through the engine once the window is in German.
func _walk_all(when: String) -> void:
	_walked.append(when)
	_walk(root, when)
	_read_menus(root, when)


func _walk(node: Node, when: String) -> void:
	if node is Window and node != root and not (node as Window).visible:
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Control:
		var control: Control = node
		if _operable(control) and control.size.x >= 1.0 and control.size.y >= 1.0:
			_judge(control, when)
	for child: Node in node.get_children(true):
		_walk(child, when)


func _judge(control: Control, when: String) -> void:
	var id: int = control.get_instance_id()
	_seen[id] = true
	var line: String = "%s  %s  [%s]  " % [when, control.get_class(), _where(control)]
	if not _in_german:
		var english: String = spoken(control).strip_edges()
		if english.is_empty():
			if not _unnamed.has(id):
				_unnamed[id] = line + control.tooltip_text.get_slice("\n", 0).left(50)
			return
	if _unnamed_de.has(id):
		return
	var why: String = _no_german(control)
	if not why.is_empty():
		_unnamed_de[id] = line + why


## Why [param control] has no name a screen reader says in German, or "".
func _no_german(control: Control) -> String:
	var german: String = (spoken(control) if _in_german else spoken(control, _german)).strip_edges()
	if german.is_empty():
		return "none"
	var tip: String = control.tooltip_text.strip_edges()
	if _by_tooltip(control) and not _german(tip).is_empty() and _german(tip) != tip:
		return "said in English: “%s”, its tooltip, which Godot reads as it is" % tip.left(60)
	# A name a screen reader alone hears, as it was set: read so while the
	# window is in English.
	var given: String = _given(control) if not _in_german else ""
	if _has_words(given) and not _a_name(given):
		if String(_de.call(&"find", given)).is_empty():
			return "no German for “%s”" % given.left(60)
	return ""


## [param text] as the app's German says it, or as it is where it has none
## (tr()'s way).
func _german(text: String) -> String:
	var said: String = String(_de.call(&"find", text))
	return said if not said.is_empty() else text


## Every item of every menu in the tree, open or not.
func _read_menus(node: Node, when: String) -> void:
	if node is PopupMenu:
		var menu: PopupMenu = node
		for index: int in menu.item_count:
			if menu.is_item_separator(index):
				continue
			var key: String = "%d:%d" % [menu.get_instance_id(), index]
			_seen[key] = true
			if menu.get_item_text(index).strip_edges().is_empty() and not _unnamed.has(key):
				_unnamed[key] = "%s  menu item %d  [%s]  %s" % [when, index, _where(menu),
					menu.get_item_tooltip(index).get_slice("\n", 0).left(50)]
	for child: Node in node.get_children(true):
		_read_menus(child, when)


static func _has_words(text: String) -> bool:
	return RegEx.create_from_string(r"\p{L}{2,}").search(text) != null


## A name kept as it is in every language: a part's (its number after it,
## "Brick 2 x 4 with Car Grille Pattern, 3001p11"), a colour's, a model's
## or one a person gave (Language.keep_name), an address, a file, a
## number. What the interface writes itself has an entry.
func _a_name(text: String) -> bool:
	return _colours.has(text) or Language._is_kept_name(text) or text.begins_with("“") \
		or text.contains("@") or text.contains("://") \
		or RegEx.create_from_string(r", [0-9]+[a-z0-9]*$|\.[a-z0-9]{2,4}$|^[\w.-]+\.[a-z]{2,}/").search(text) != null


## What a person can press, type in or choose from, or what takes the
## keyboard's focus. A scroll bar is the scroll it is in. A control drawn by
## the app and pressed (the view cube and its arrows) shows the pointing
## hand, as a button does. Text a screen reader alone can stop on (Godot's
## labels, FOCUS_ACCESSIBILITY) is read as what it says.
static func _operable(control: Control) -> bool:
	if control is ScrollBar:
		return false
	# A menu's rows are said each by its words, read below (_read_menus);
	# the engine's control that draws them is the menu itself.
	if control.get_class() == "PopupMenuItems":
		return false
	# A spin box's field is said by the spin box's name.
	if control is LineEdit and control.get_parent() is SpinBox:
		return false
	if (control is Label or control is RichTextLabel) \
			and control.focus_mode == Control.FOCUS_ACCESSIBILITY:
		return false
	return control is BaseButton or control is LineEdit or control is TextEdit \
		or control is ItemList or control is Tree or control is Slider \
		or control is SpinBox or control is TabBar \
		or control.focus_mode != Control.FOCUS_NONE \
		or (control.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
			and control.mouse_filter == Control.MOUSE_FILTER_STOP)


## What a screen reader is told a control is called, in the language in
## use, as Godot 4.7 works it out (scene/gui/control.cpp, button.cpp,
## line_edit.cpp, text_edit.cpp): accessibility_name through tr(), a
## button's words and a field's placeholder through atr(), a button's
## tooltip as it is. But a tooltip of more than one line is help, not a
## name; and a choice's words are its value, not its name. With
## [param say], the words are said through it instead of the engine's
## translation (a language other than the window's).
static func spoken(control: Control, say: Callable = Callable()) -> String:
	# Through the engine's tr() as the property reads it: as it was set
	# while the window is in English, where [param say] says it.
	var given: String = control.accessibility_name
	if say.is_valid() and not given.is_empty():
		given = str(say.call(given))
	if given.is_empty() and not control.accessibility_labeled_by_nodes.is_empty():
		var labels: PackedStringArray = []
		for path: NodePath in control.accessibility_labeled_by_nodes:
			var label: Node = control.get_node_or_null(path)
			if label is Label:
				var words: String = (label as Label).text
				labels.append(str(say.call(words)) if say.is_valid() else label.atr(words))
		given = " ".join(labels)
	var drawn := func(words: String) -> String:
		if words.is_empty() or not control.can_auto_translate():
			return words
		return control.atr(words) if not say.is_valid() else str(say.call(words))
	if control is OptionButton:
		return given
	if control is Button or control is LinkButton:
		var words: String = drawn.call(str(control.get("text")))
		if not words.is_empty():
			return words if given.is_empty() or given == words else given + ": " + words
		if _by_tooltip(control):
			return control.tooltip_text
		return given
	if control is LineEdit or control is TextEdit:
		var placeholder: String = drawn.call(str(control.get("placeholder_text")))
		return placeholder if given.is_empty() else given
	if control is Label:
		return drawn.call((control as Label).text) if given.is_empty() else given
	if control is TabBar:
		var bar: TabBar = control
		if not given.is_empty():
			return given
		for index: int in bar.tab_count:
			if bar.get_tab_title(index).is_empty():
				return ""
		return "tabs" if bar.tab_count > 0 else ""
	return given


## The name [param control] was given: its accessibility_name, or its
## labels' words (accessibility_labeled_by_nodes). The property reads
## through tr(), so while the window is in English this is as it was set.
static func _given(control: Control) -> String:
	var given: String = control.accessibility_name
	if given.is_empty() and not control.accessibility_labeled_by_nodes.is_empty():
		var labels: PackedStringArray = []
		for path: NodePath in control.accessibility_labeled_by_nodes:
			var label: Node = control.get_node_or_null(path)
			if label is Label:
				labels.append((label as Label).text)
		given = " ".join(labels)
	return given


## Whether Godot names [param control] by its tooltip: a button with no
## words and no name, and a tooltip of one line (one of more is help).
static func _by_tooltip(control: Control) -> bool:
	if not (control is Button or control is LinkButton) or control is OptionButton:
		return false
	return str(control.get("text")).is_empty() and _given(control).is_empty() \
		and not control.tooltip_text.strip_edges().is_empty() \
		and control.tooltip_text.strip_edges().split("\n").size() == 1


## The control's owner, by its class (the nearest scripted node above it
## with a class name), and its last steps down to it.
func _where(control: Node) -> String:
	var owner_name: String = ""
	var up: Node = control
	while up != null and owner_name.is_empty():
		var script: Script = up.get_script()
		if script != null and not script.get_global_name().is_empty():
			owner_name = script.get_global_name()
		up = up.get_parent()
	var parts: PackedStringArray = str(control.get_path()).split("/")
	return "%s %s" % [owner_name, "/".join(parts.slice(maxi(parts.size() - 2, 0)))]


# -- the way in -----------------------------------------------------------------


## The sign-in screen walked, then a throwaway account signed in and the
## screen gone.
func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	if not _check("the sign-in screen is over the app as it opens", gate != null and gate.visible):
		return false
	await _frames(6)
	_walk_all("the sign-in screen")
	await _shot("sign_in")
	_email = SignInHelper.throwaway("a11ynames")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	return _check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)


## Signed in with a password grant on an account the admin key made: the
## token bucket, not a code's verify (mosaic_window_probe).
func _sign_in(account: Account, email: String) -> String:
	_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


# -- helpers ----------------------------------------------------------------------


func _shot(name: String) -> void:
	if _shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var file: String = name.to_lower().replace(" ", "_").replace(",", "").replace("'", "") \
		.replace("?", "").replace("/", "_").replace("“", "").replace("”", "").left(60)
	picture.save_png(_shots.path_join("%03d_%s.png" % [_walked.size(), file]))


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)


## Until the app says it is busy with nothing (Working), and Colour the
## hidden parts has drawn its pictures, a minute at most.
func _idle() -> void:
	var hidden: HiddenColoursPanel = _main.get("_hidden_colours")
	for _n: int in 3600:
		if not Working.is_busy() and (hidden == null or not bool(hidden.get("_working"))):
			return
		await process_frame


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	if _failures == 0:
		print("a11y names probe: all checks passed")
	else:
		print("a11y names probe: %d checks failed" % _failures)
	quit(1 if _failures > 0 else 0)
