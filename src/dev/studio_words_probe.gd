## Every word the studio shows while it is used is in the person's language
## (langsweep). The languages probe reads what the app shows at rest; the
## words made at the moment, from a part's name or a count ("placed %s",
## "undid: %s", "Editing %s · its copy follows"), it never met, and in German
## the undo toast read "rückgängig gemacht: placed Plate 1 x 2". Here, in
## English, German, French and Spanish, through a part put down, moved,
## undone, redone, a put inside a sub-assembly with a copy (its banner), a
## delete and a save:
## - every line said (the status line, a phone's toast) and every word shown
##   (labels, buttons, tooltips, the busy line, History's rows) has its
##   translation, and is drawn so, with nothing left in English but names (a
##   part's, a colour's, the model's, a sub-model's), keys and brands;
## - what is read is written to --words-to=FILE, so a change can show the
##   English drawn byte for byte as before.
## The desktop's layout, then a phone's in a run of its own (its row's words,
## its line over the model), unless --phone asks for the phone's alone.
##
##   godot --headless --path . --script src/dev/studio_words_probe.gd
##   godot --headless --path . --script src/dev/studio_words_probe.gd -- --phone
##   ... -- --words-to=FILE   each language's lines read, as lang<TAB>english<TAB>drawn
extends SceneTree

const LANGUAGES: Array[String] = ["en", "de", "fr", "es"]
## Brands and names drawn as they are in every language.
const BRANDS: Array[String] = ["Brickworks", "Claude", "Claude Code", "BrickLink", "Rebrickable", "LDraw",
	"LEGO®", "Studio", "Mecabricks", "LeoCAD"]

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
var _verbs: EditVerbs
var _shell: Shell
var _bar: ModelBar
var _tree: Assemblies
var _bin: PartsBin
var _phone: bool = false
var _lang: String = "en"
var _doing: String = ""
var _words_to: String = ""
## lang -> [english, drawn] read, for --words-to.
var _read: Array = []
## What was said in the language, this step: the status line's every line.
var _said: Array[String] = []
## Each language's lines not in it, by the step they were read at.
var _english: Dictionary = {}
var _names: Dictionary = {}
var _plain_names: Dictionary = {}
var _KEY: RegEx = RegEx.create_from_string(
	r"^((?i:Ctrl|Shift|Alt|Cmd|Option)[+-])*(Ctrl|Shift|Alt|Cmd|Option|[A-Z0-9]|F\d+|Esc|Enter|Space|Tab|Delete|Backspace|Home|End|Page Up|Page Down|Up|Down|Left|Right|\W)$")
var _JOINS: RegEx = RegEx.create_from_string(r" · | — |\. |; | › |\n|: ")
var _LETTER: RegEx = RegEx.create_from_string(r"\p{L}")
var _MEASURE: RegEx = RegEx.create_from_string(r"^-?\d+([.,]\d+)? ?(s|ms|mm|cm|m|°|%|px|g|kg|LDU)$")


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--phone":
			_phone = true
		elif argument.begins_with("--words-to="):
			_words_to = argument.trim_prefix("--words-to=")
	if _phone:
		Phone._on = 1
		Phone._wide = false
	Account.where = "user://probe_session.json"
	Account._clear()
	ShellPrefs.put("first_build", "skipped")
	ShellPrefs.put("assistant_offered", true)
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	if _phone and DisplayServer.get_name() == "headless":
		# A phone's window at the scale the app gives it, as treedrag's.
		root.size = Vector2i(390, 844)
		await _frames(10)
		var phone: Variant = _main.get("_phone")
		if phone is Node:
			(phone as Node).set("holds_scale", true)
		root.content_scale_factor = (_main.get_script() as GDScript).sized_factor(390.0, 844.0,
			true, ShellPrefs.interface_size(), true)
		await _frames(30)
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_store = _main.get("_store")
	_verbs = _main.get("_verbs")
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	_bin = _main.get("_bin")
	_tree = _shell.assemblies
	_main.call("clear_model")
	Carry.clipboard = []
	_bar.said.connect(func(text: String) -> void:
		_said.append(Phone.touch_words(text) if Phone.on() else text))
	print("\nstudio_words: %s, window %s" % ["a phone's layout" if Phone.on() else "the desktop's",
		str(root.get_visible_rect().size)])

	# A wing of two parts on a plate, made a sub-assembly and copied: inside
	# it the banner says its copy follows (wide150's model).
	_put("3001", 1, Vector3(0, 24, 0))
	_put("3034", 14, Vector3(-100, 8, -40))
	_put("3004", 4, Vector3(-120, 32, -40))
	await _frames(3)
	_select_only([_world.bricks()[1].id, _world.bricks()[2].id])
	await _key(KEY_G, true)
	_verbs._name_field.text = "Wing"
	_verbs._naming.hide()
	_verbs._naming.confirmed.emit()
	await _frames(3)
	_select_only(Array(_tree.ids_under("Wing#1")))
	await _key(KEY_D, true)
	await _frames(3)
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	_check("a wing and its copy (%s)" % str(_tree.paths()), _tree.ids_under("Wing#2").size() == 2)
	var title: String = "Words probe phone" if _phone else "Words probe"
	_check("saved as %s" % title, _store.save_as(title))
	_gather_names()

	for lang: String in LANGUAGES:
		await _walk(lang)

	if not _words_to.is_empty():
		var file: FileAccess = FileAccess.open(_words_to, FileAccess.WRITE)
		for line: Array in _read:
			file.store_line("\t".join(PackedStringArray([str(line[0]), str(line[1]).c_escape(),
				str(line[2]).c_escape()])))
		file.close()
		print("  the lines read: %s" % _words_to)
	# Then a phone's layout, which only a run started so has.
	if not _phone:
		print("\n  a phone's layout, in a run of its own:")
		var output: Array = []
		var asked: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://src/dev/studio_words_probe.gd", "--", "--phone"]
		if not _words_to.is_empty():
			asked.append("--words-to=" + _words_to.get_basename() + "_phone." + _words_to.get_extension())
		var code: int = OS.execute(OS.get_executable_path(), asked, output, true)
		for line: String in "\n".join(output).split("\n"):
			if line.begins_with("  ") or line.begins_with("studio_words"):
				print("  " + line)
		_check("the phone's run passed (exit %d)" % code, code == 0)
	print("")
	if _failures == 0:
		print("studio_words: every word shown and said is in de, fr and es")
	else:
		print("studio_words: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## One language: chosen as Settings chooses it, then the studio used.
func _walk(lang: String) -> void:
	_lang = lang
	_english.clear()
	Language.choose(lang)
	await _frames(20)
	_camera.frame(AABB(Vector3(-240, 0, -200), Vector3(480, 80, 360)), 1.6)
	await _frames(10)
	print("\n  -- %s" % lang)
	await _step("at rest", func() -> void: pass)

	# A part in hand, then put down on the ground by a click.
	var depth: int = _builder.history_depth()
	await _step("a part in hand", func() -> void:
		_bin._on_part("3023")
		await _frames(10)
		await _move(_screen(Vector3(60, 0, 60))))
	await _step("a put", func() -> void:
		var at: Vector2 = _screen(Vector3(60, 0, 60))
		await _move(at + Vector2(1, 0))
		await _click(at + Vector2(1, 0))
		await _frames(10)
		await _key(KEY_ESCAPE))
	_check("%s: a part put down (%d steps, %d before)" % [lang, _builder.history_depth(), depth],
		_builder.history_depth() > depth)
	var put: int = _world.bricks().back().id
	# Moved by a key, as a person nudges the selection.
	await _step("a move", func() -> void:
		_builder.clear_selection()
		_builder.select_brick(put, false)
		await _frames(3)
		await _key(KEY_LEFT))
	await _step("an undo", func() -> void:
		await _key(KEY_Z, true))
	await _step("a redo", func() -> void:
		_shell.run("redo")
		await _frames(10))
	await _step("History's rows", func() -> void: pass, _history_rows())

	# Inside the wing, whose copy follows: the banner, a put and its undo.
	await _step("inside the wing", func() -> void:
		_builder.clear_selection()
		_verbs.assemblies.enter("Wing#1")
		await _frames(10))
	await _step("a put inside the wing", func() -> void:
		_bin._on_part("3023")
		await _frames(10)
		var inside: Vector2 = _screen(Vector3(-60, 8, -40))
		await _move(inside)
		await _move(inside + Vector2(1, 0))
		await _click(inside + Vector2(1, 0))
		await _frames(10)
		await _key(KEY_ESCAPE))
	await _step("an undo inside the wing", func() -> void:
		await _key(KEY_Z, true))
	await _step("out of the wing", func() -> void:
		await _key(KEY_ESCAPE)
		_verbs.assemblies.leave_to("")
		await _frames(10))

	# The part put down, deleted, and the model saved.
	await _step("a delete", func() -> void:
		_builder.clear_selection()
		if _world.get_brick(put) != null:
			_builder.select_brick(put, false)
		await _frames(3)
		await _key(KEY_DELETE))
	await _step("a save", func() -> void:
		_shell.run("save")
		await _frames(30))
	# Ask the builders' line with one to four parts picked, at a step and of
	# the whole model, and where a pin on each is: words made from a part's
	# name and its colour's (greenreds; "the 2 × 4 brick" was English).
	await _step("Ask's line and a pin's place", func() -> void: pass, _ask_and_pin_words())
	if lang == "en":
		return
	var lines: PackedStringArray = []
	for english: String in _english:
		lines.append(_english[english])
	_check("%s: every word shown and said through the walk is in the language%s" % [lang,
		"" if lines.is_empty() else "; %d in English:\n      %s" % [lines.size(), "\n      ".join(lines)]],
		lines.is_empty())


## [param act] done, then every word said while it was and every word shown
## after it read; [param more], words shown elsewhere (History's rows).
func _step(name: String, act: Callable, more: Array = []) -> void:
	_doing = name
	_said.clear()
	await act.call()
	await _frames(4)
	var seen: Array = _said.map(func(text: String) -> Array: return [text, _bar])
	seen.append_array(_shown())
	for text: String in more:
		seen.append([text, null])
	var phone: Variant = _main.get("_phone")
	if phone is PhoneShell:
		seen.append([(phone as PhoneShell).hint(), phone])
	var had: Dictionary = {}
	for one: Array in seen:
		var english: String = one[0]
		if english.strip_edges().is_empty() or had.has(english):
			continue
		had[english] = true
		var drawn: String = (one[1] as Node).atr(english) if is_instance_valid(one[1]) \
			else (Language.says(english) if _lang != "en" else english)
		if drawn.is_empty():
			drawn = english
		_read.append([_lang, english, drawn])
		if _lang == "en":
			continue
		var left: Array[String] = _left_in_english(english, drawn)
		# Each once, at the step it was first read at.
		if not left.is_empty() and not _english.has(english):
			_english[english] = "%s: \"%s\" (%s)" % [name, english.replace("\n", " / ").left(90),
				", ".join(left)]


## The model's parts picked one, two, three and four at a time, as Ask the
## builders reads them (main.gd's _ask_context), its line at step 3 and of
## the whole model; and a pin's place on each part, at a step and not,
## moved since or not, as the pins panel words it (PartPins).
func _ask_and_pin_words() -> Array:
	var out: Array = []
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		ids.append(brick.id)
	for count: int in [1, 2, 3, 4]:
		if count > ids.size():
			break
		_select_only(ids.slice(0, count))
		var asked: Dictionary = _main.call("_ask_context")
		for step: int in [0, 3]:
			out.append(SharePanel.about_words(step, asked["parts"]))
	_builder.clear_selection()
	var library: PartLibrary = _main.get("_library")
	# The model's, one PartPins says whole ("on the Plate 1 x 2 with Door
	# Rail"), and none known.
	var names: Array = ["Plate 1 x 2 with Door Rail", ""]
	for id: int in ids:
		var info: PartLibrary.PartInfo = library.parts.get(_world.get_brick(id).part_id)
		if info != null and not names.has(info.name):
			names.push_front(info.name)
	for name: String in names:
		for step: int in [0, 12]:
			for moved: bool in [false, true]:
				var words: String = PinPlace.where(name, step, {"moved": moved}, 1)
				out.append(words.substr(0, 1).to_upper() + words.substr(1))
	return out


## What of [param english] is drawn in English, but for names, keys and
## brands: all of it where it has no translation, else what its pattern's
## places or its lines keep, else nothing; and drawn otherwise than its
## translation, all of it.
func _left_in_english(english: String, drawn: String) -> Array[String]:
	var out: Array[String] = []
	var said: String = Language.says(english)
	if said.is_empty():
		if not _is_name(english):
			out.append("no entry")
		return out
	for kept: String in Language.left_in_english(english):
		if not _is_name(kept):
			out.append(kept)
	if out.is_empty() and drawn != said and drawn == english:
		out.append("drawn in English")
	return out


## Every word a shown control has, but a typed field's, a list's and a
## tree's rows (names) and a control drawn as it is.
func _shown() -> Array:
	var out: Array = []
	_shown_under(root, out)
	return out


func _shown_under(node: Node, out: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Window and node != root and (not (node as Window).visible or Tooltips.is_tooltip(node as Window)):
		return
	if node is ItemList or node is Tree or node.has_meta(&"names") \
			or node.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED:
		return
	var texts: Array[String] = []
	if node is Window and node != root:
		texts.append((node as Window).title)
	if node is Label:
		texts.append((node as Label).text)
	elif node is RichTextLabel:
		texts.append((node as RichTextLabel).text)
	elif node is Button:
		texts.append((node as Button).text)
	elif node is LineEdit:
		texts.append((node as LineEdit).placeholder_text)
	if node is Control:
		texts.append((node as Control).tooltip_text)
	for text: String in texts:
		if _LETTER.search(text) != null and text.length() > 1:
			out.append([text, node])
	for child: Node in node.get_children(true):
		_shown_under(child, out)


## History's rows as the Edit menu fills them.
func _history_rows() -> Array:
	var menu := PopupMenu.new()
	root.add_child(menu)
	_shell._fill_history(menu)
	var rows: Array = []
	for n: int in menu.item_count:
		rows.append(menu.get_item_text(n))
	menu.queue_free()
	return rows


func _gather_names() -> void:
	for brand: String in BRANDS:
		_names[brand] = true
	_names[_store.title] = true
	_names[_bar.model_name()] = true
	for path: String in _tree.paths():
		_names[Assemblies.label(path)] = true
		_names[Assemblies.leaf(path)] = true
	var library: PartLibrary = _main.get("_library")
	for code: int in library.colors:
		var colour: PartLibrary.BrickColor = library.colors[code]
		_names[colour.name] = true
		_names[colour.name.replace("_", " ")] = true
	for part_id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[part_id]
		_plain_names[_plain(info.name)] = true
		_plain_names[_plain(PartsBin.tile_name(info))] = true
		_plain_names[_plain(Inventory._tidy(info.name))] = true


## Whether [param text] is names alone: each part a join divides it into a
## name, a part's number, a key, a measure or no word at all.
func _is_name(text: String) -> bool:
	if _plain_names.has(_plain(text.replace("\n", " "))) or _names.has(text.strip_edges()):
		return true
	for piece: String in _JOINS.sub(text.strip_edges(), "\n", true).split("\n"):
		piece = piece.strip_edges().trim_prefix("“").trim_suffix("”").trim_suffix(".")
		if piece.is_empty() or _LETTER.search(piece) == null or _names.has(piece) \
				or _plain_names.has(_plain(piece)) or _KEY.search(piece) != null \
				or _MEASURE.search(piece) != null:
			continue
		var library: PartLibrary = _main.get("_library")
		if library.parts.has(piece):
			continue
		return false
	return true


func _plain(name: String) -> String:
	var out: String = name.to_lower().replace("×", " x ").replace("minifig ", "")
	return " ".join(out.split(" ", false))


func _put(part: String, colour: int, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(root.size)
	return at * (window / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


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
