## Brickworks with the assistant off: a complete CAD with nothing of AI in
## it, and the assistant back whole when it is turned on again (Settings,
## Assistant (AI): ShellPrefs.assistant_shown, Main.set_assistant).
##
##   godot --path . --resolution 1280x800 --script src/dev/noai_probe.gd
##   godot --path . --resolution 1280x800 --script src/dev/noai_probe.gd -- --assistant=on
##
## Why: a builder on Reddit, 2026-10-13, of the assistant: "looks worryingly
## AI… a LOT of us… building freely and building things that are not AI
## designed". Someone who never wants AI must never have to see it.
##
## The first run: the parts bin open, the model in view, no assistant
## anywhere, and one button offering it, "Show the assistant", which one
## press turns on, remembered, with its column open — what Settings does.
##
## Off: no AI by name — the assistant's column and rail, its panel, Ask
## Claude in Edit and on a part, View, Assistant and Tools, Claude connector,
## the Brick Art brief and Design with Claude, Claude in Account — and none
## by text: every control shown in the window, every row of every menu and
## submenu and of the menu on a part, the tour's cards, About, the keys
## list, the status bar, the parts list, Check stability's and Simulate's
## words, Brick Art, Account, My collection and the sign-in screen are
## searched for Claude, assistant, AI, Sketch first and Anthropic.
## Ctrl+K on a selection does nothing, and the connector cannot be switched
## on. The first visit's button brings every one of those back; Settings
## takes them away again by a click, saying the connections are off with
## it, and brings them back.
##
## With -- --assistant=on, as /app?assistant=on is on the web: the app
## opens with the assistant on, remembered, its column open, and no button.
##
## A short build with it off: parts put down by clicks on the baseplate, a
## step made of some of them, the booklet and the LDraw and a GLB written
## to a folder of the probe's own, none of them with a word of AI in it.
##
## Pictures in shots/noai/. Files in user://noai_probe_out/, removed.
extends SceneTree

const SHOTS := "res://shots/noai/"
const OUT := "user://noai_probe_out/"
## What AI is called anywhere a person reads it.
const AI_WORDS := "Claude|[Aa]ssistant|\\bAI\\b|Sketch first|Anthropic"

var _failures: int = 0
var _main: Node
var _ai: RegEx


func _initialize() -> void:
	_run()


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	_ai = RegEx.create_from_string(AI_WORDS)
	_forget(OUT)
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	# The first visit's line, which a probe sees only when it asks for it.
	_main.set("offer_for_probe", true)
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	await _frames(20)

	if OS.get_cmdline_user_args().has("--assistant=on"):
		await _from_the_address()
	else:
		await _first_run()
		await _nothing_of_ai("on the first visit")
		await _press_the_offer()
		await _all_of_it_back("from_the_button")
		await _turn("off")
		await _nothing_of_ai("off in Settings")
		await _turn("on")
		await _all_of_it_back("from_settings")
		await _turn("off")
		await _build_by_hand()

	_forget(OUT)
	print("")
	print("no AI: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- the first run ------------------------------------------------------------


func _first_run() -> void:
	print("\nthe first run")
	var bin: SideDock = _main.get("_bin_dock")
	var chat: SideDock = _main.get("_chat_dock")
	_ok((_main.get("_shell") as Shell).get("assistant_shown") == false,
		"a first visit builds by hand: the assistant is off")
	_ok(bin.is_open() and bin.content.is_visible_in_tree(),
		"it opens on the parts bin (columns \"%s\")" % _main.get("_columns"))
	_ok(not chat.is_visible_in_tree(), "...and no assistant column, nor its rail")
	var view: Rect2 = (_main.get("_over_model") as Control).get_global_rect()
	var camera: CadCamera = _main.get("_camera")
	var bounds: AABB = _main.call("_built_bounds")
	var middle: Vector2 = camera.unproject_position(bounds.get_center())
	_ok(bounds.size.length() > 0.0 and view.grow(-20.0).has_point(middle),
		"the model is in view, in the middle of its column (%s in %s)" % [
			str(middle.round()), str(view.position.round())])
	var offer: Control = _main.get("_offer")
	var show: Button = _main.get("_offer_show")
	_ok(offer != null and offer.is_visible_in_tree() and show != null
		and show.is_visible_in_tree() and show.text == "Show the assistant",
		"one button offers it: \"%s\"" % (show.text if show != null else _texts_in(offer).strip_edges()))
	_ok(ShellPrefs.value("assistant_offered") == true,
		"...once: kept as offered, so the next visit has no button")
	await _shot("1_first_run")


## The first visit's button, pressed: what Settings, Assistant does.
func _press_the_offer() -> void:
	print("
the first visit's button, pressed")
	var show: Button = _main.get("_offer_show")
	_ok(show != null and show.is_visible_in_tree(), "Show the assistant is there to press")
	if show == null:
		return
	await _click(show.get_global_rect().get_center())
	await _frames(int(SideDock.SLIDE_SECONDS * 60) + 20)
	var offer: Control = _main.get("_offer")
	_ok((_main.get("_shell") as Shell).get("assistant_shown") == true
		and ShellPrefs.value("assistant") == "on",
		"one press turns the assistant on, kept as this device's (%s)" % ShellPrefs.value("assistant"))
	_ok(not offer.visible, "...and the button is gone")


## As /app?assistant=on: on before anything is built, remembered, its
## column open, and no button offering what is already there.
func _from_the_address() -> void:
	print("
opened with --assistant=on, as /app?assistant=on")
	var chat: SideDock = _main.get("_chat_dock")
	_ok((_main.get("_shell") as Shell).get("assistant_shown") == true
		and ShellPrefs.value("assistant") == "on",
		"the assistant is on, kept as this device's (%s)" % ShellPrefs.value("assistant"))
	_ok(chat.is_visible_in_tree() and chat.rail().is_visible_in_tree() and chat.is_open(),
		"its column is open, with its rail (columns \"%s\")" % _main.get("_columns"))
	var offer: Control = _main.get("_offer")
	_ok(offer != null and not offer.visible, "and no button offers it")
	_ok((_main.get("_connector") as ClaudeConnector).get("held") == false,
		"the connector can be switched on")
	await _shot("8_from_the_address")


# -- nothing of AI ------------------------------------------------------------


func _nothing_of_ai(when: String) -> void:
	print("\nnothing of AI, %s" % when)
	var shell: Shell = _main.get("_shell")
	var chat: SideDock = _main.get("_chat_dock")
	var panel: Control = _main.get("_chat")
	_ok(not chat.is_visible_in_tree() and not chat.rail().is_visible_in_tree()
		and not panel.is_visible_in_tree(),
		"no assistant column, rail or panel: its key, Sketch first and the connector's switch with it")
	for name: String in ["ask_claude", "panel_assistant", "connector"]:
		_ok(shell.menu_id(name) < 0 and not shell.can(name),
			"%s is in no menu and cannot run" % name)
	var found: PackedStringArray = _ai_in_window()
	_ok(found.is_empty(), "not a word of AI in anything the window shows%s" % _listed(found))
	found = _ai_in_menus()
	_ok(found.is_empty(), "nor in any row of any menu or submenu%s" % _listed(found))

	# The menu on a part.
	var builder: Builder = _main.get("_builder")
	var part: int = _a_part()
	builder.selection.clear()
	builder.selection[part] = true
	builder.selection_changed.emit(1)
	shell.open_context(Vector2(400, 300))
	await _frames(4)
	var context: PopupMenu = shell.get("context")
	found = _ai_in_popup(context)
	_ok(context != null and context.item_count > 0 and found.is_empty(),
		"the menu on a part: %s%s" % [_rows(context), _listed(found)])
	await _shot("2_right_click_%s" % when.replace(" ", "_"))
	if context != null:
		context.hide()
	# Ctrl+K, the key Ask Claude had.
	await _key(KEY_K, true)
	await _frames(6)
	_ok(not chat.visible and not chat.is_open(), "Ctrl+K on a selection does nothing")
	builder.selection.clear()
	builder.selection_changed.emit(0)

	# Brick Art.
	var mosaic: MosaicDialog = _main.get("_mosaic")
	mosaic.show_for(_picture())
	await _frames(8)
	var named: Dictionary = mosaic.controls_by_name()
	_ok(not (named["mosaic_claude"] as Control).is_visible_in_tree()
		and not (named["mosaic_brief"] as Control).is_visible_in_tree(),
		"Brick Art has no brief for Claude and no Design with Claude")
	found = _ai_in(mosaic)
	_ok(found.is_empty(), "...and no word of AI%s" % _listed(found))
	await _shot("3_brick_art_%s" % when.replace(" ", "_"))
	mosaic.visible = false

	# Account, My collection, Help.
	var account: AccountPanel = _main.get("_account_panel")
	account.open()
	await _frames(4)
	found = _ai_in(account)
	_ok(account.visible and found.is_empty(), "Account says nothing of Claude%s" % _listed(found))
	account.visible = false
	shell.collection.open("own")
	await _frames(4)
	found = _ai_in(shell.collection)
	_ok(found.is_empty(), "nor My collection%s" % _listed(found))
	shell.collection.close()
	var stops: Array = shell.tour.call("_stops")
	var tour: String = "\n".join(stops.map(func(stop: Array) -> String:
		return "%s %s" % [stop[0], stop[1]]))
	_ok(_ai.search(tour) == null, "the tour is of the CAD alone, %d cards" % stops.size())
	shell.call("_show_about")
	var about: AcceptDialog = shell.get("_about")
	_ok(_ai.search(about.dialog_text) == null, "About says nothing of it")
	about.hide()
	var keys: PackedStringArray = []
	for binding: ControlsHint.Binding in ControlsHint.for_keyboard():
		keys.append("%s %s" % [" ".join(binding.keys), binding.verb])
	_ok(_ai.search("\n".join(keys)) == null, "nor the keys list, %d keys" % keys.size())
	var gate := SignInGate.new()
	gate.setup(_main.get("_account"))
	root.add_child(gate)
	await _frames(2)
	found = _ai_in(gate)
	_ok(found.is_empty(), "nor the sign-in screen%s" % _listed(found))
	gate.queue_free()

	# The CAD's own tools, read for any word of it. Check stability as Tools
	# runs it, awaited: through Shell.run a debug build stops the menu's
	# lambda at the coroutine it hands back ("Trying to call an async
	# function without await"), which is the same before this change.
	await shell.call("_check_stability")
	await _frames(10)
	var said: String = (shell.status.message.text if shell.status != null else "")
	_ok(not said.is_empty() and _ai.search(said) == null,
		"Check stability says what it found and nothing of AI: \"%s\"" % said.left(70))
	shell.run("parts_list")
	await _frames(20)
	var parts_list: Control = _main.get("_inventory")
	found = _ai_in(parts_list)
	_ok(parts_list.is_visible_in_tree() and found.is_empty(),
		"the parts list%s" % _listed(found))
	_main.call("_toggle_parts")
	await _frames(4)
	shell.run("simulate")
	await _frames(30)
	var simulate: Control = _main.get("_simulate")
	found = _ai_in(simulate)
	_ok(simulate.is_visible_in_tree() and found.is_empty(), "Simulate mechanism%s" % _listed(found))
	await _shot("4_simulate_%s" % when.replace(" ", "_"))
	simulate.visible = false
	await _frames(10)

	var connector: ClaudeConnector = _main.get("_connector")
	connector.start()
	connector.connect_claude()
	await _frames(2)
	_ok(connector.get("held") == true and not connector.is_on(),
		"the connector is held off and cannot be switched on")


# -- turning it on and off ----------------------------------------------------


## Settings, Assistant (AI), chosen by a click as a person chooses it.
func _turn(to: String) -> void:
	print("\nSettings, Assistant (AI): %s" % to)
	var shell: Shell = _main.get("_shell")
	shell.run("settings")
	await _frames(10)
	var settings: Control = _main.get("_controls")
	var named: Dictionary = settings.call("controls_by_name") if settings.has_method("controls_by_name") else {}
	var choice: Control = named.get("assistant_" + to)
	_ok(choice != null and choice.is_visible_in_tree(), "Settings has the choice: %s" % (
		(choice as Button).text if choice != null else "none"))
	if choice == null:
		return
	await _click(choice.get_global_rect().get_center())
	await _frames(20)
	_ok(shell.get("assistant_shown") == (to == "on") and ShellPrefs.value("assistant") == to,
		"chosen, and kept as this device's (%s)" % ShellPrefs.value("assistant"))
	var note: String = _texts_in(settings)
	if to == "off":
		_ok(note.contains("Claude connections are off while the assistant is off"),
			"Settings says Claude connections are off while the assistant is off")
	await _shot("5_settings_%s" % to)
	await _click((named["settings_done"] as Control).get_global_rect().get_center())
	await _frames(int(SideDock.SLIDE_SECONDS * 60) + 20)


func _all_of_it_back(how: String) -> void:
	print("\nall of it back, %s" % how.replace("_", " "))
	var shell: Shell = _main.get("_shell")
	var chat: SideDock = _main.get("_chat_dock")
	_ok(chat.is_visible_in_tree() and chat.rail().is_visible_in_tree() and chat.is_open(),
		"the assistant's column is back, open, with its rail")
	for name: String in ["ask_claude", "panel_assistant", "connector"]:
		_ok(shell.menu_id(name) >= 0, "%s is in its menu again" % name)
	var builder: Builder = _main.get("_builder")
	builder.selection.clear()
	builder.selection[_a_part()] = true
	builder.selection_changed.emit(1)
	shell.open_context(Vector2(400, 300))
	await _frames(4)
	var context: PopupMenu = shell.get("context")
	_ok(context != null and context.get_item_text(0) == "Ask Claude about this…",
		"the menu on a part asks Claude again: %s" % _rows(context))
	context.hide()
	chat.set_open(false)
	await _frames(int(SideDock.SLIDE_SECONDS * 60) + 10)
	await _key(KEY_K, true)
	await _frames(int(SideDock.SLIDE_SECONDS * 60) + 10)
	var panel: ChatPanel = _main.get("_chat")
	_ok(chat.is_open() and panel._chip.visible, "Ctrl+K asks about the selection again")
	await _shot("6_assistant_back_%s" % how)
	builder.selection.clear()
	builder.selection_changed.emit(0)
	var mosaic: MosaicDialog = _main.get("_mosaic")
	mosaic.show_for(_picture())
	await _frames(8)
	_ok((mosaic.controls_by_name()["mosaic_claude"] as Control).is_visible_in_tree(),
		"Brick Art has Design with Claude again")
	mosaic.visible = false
	var account: AccountPanel = _main.get("_account_panel")
	_ok(account.get("_claude_box").visible, "Account has its Claude section again")
	var stops: Array = shell.tour.call("_stops")
	_ok(stops.any(func(stop: Array) -> bool: return stop[0] == "The assistant"),
		"the tour has the assistant's card again, %d cards" % stops.size())
	shell.call("_show_about")
	_ok((shell.get("_about") as AcceptDialog).dialog_text.contains("with the assistant"),
		"About says it builds by hand or with the assistant")
	(shell.get("_about") as AcceptDialog).hide()
	_ok((_main.get("_connector") as ClaudeConnector).get("held") == false,
		"the connector can be switched on again")


# -- a short build with it off -------------------------------------------------


func _build_by_hand() -> void:
	print("\na short build, by hand")
	var shell: Shell = _main.get("_shell")
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var builder: Builder = _main.get("_builder")
	var camera: CadCamera = _main.get("_camera")
	_main.call("clear_model")
	await _frames(10)
	camera.set_view("isometric")
	camera.frame(AABB(Vector3(-120, 0, -120), Vector3(240, 48, 240)))
	await _frames(6)
	_main.call("_on_part_chosen", "3001")
	await _frames(20)
	var before: int = world.brick_count() - store.scenery.size()
	for at: Vector3 in [Vector3(-40, 0, 0), Vector3(40, 0, 0), Vector3(0, 0, 60)]:
		var point: Vector2 = camera.unproject_position(at)
		await _move(point)
		await _click(point)
		await _frames(4)
	var placed: int = world.brick_count() - store.scenery.size() - before
	_ok(placed == 3, "three bricks put down by clicks on the baseplate (%d)" % placed)
	await _key(KEY_ESCAPE)
	var ids: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if not store.scenery.has(brick.id):
			ids.append(brick.id)
	var said: String = shell.change_steps("new", ids.slice(0, 1), null)
	_ok(said.begins_with("made a new step") and AuthorSteps.any(world, store.scenery),
		"a step made of one of them: %s" % said)
	await _shot("7_built_by_hand")
	var folder: String = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var exports: Exports = _main.get("_exports")
	exports.folder = folder
	var booklet: String = folder.path_join("by_hand_instructions.html")
	var wrote: String = await _main.call("_export_booklet", booklet)
	var html: String = FileAccess.get_file_as_string(booklet)
	_ok(wrote.begins_with("wrote ") and html.length() > 1000,
		"the booklet: %s" % wrote)
	_ok(_ai.search(html) == null, "...with no word of AI in it")
	var bar: ModelBar = _main.get("_bar")
	wrote = await bar.export_now(folder)
	var path: String = wrote.trim_prefix("wrote ")
	var ldr: String = FileAccess.get_file_as_string(path)
	_ok(wrote.begins_with("wrote ") and ldr.count("3001.dat") == 3,
		"the LDraw file, three bricks in it: %s" % wrote.get_file())
	_ok(_ai.search(ldr) == null, "...with no word of AI in it")
	wrote = await exports.model_3d("glb")
	_ok(wrote.begins_with("wrote ") or wrote.contains(".glb"), "a GLB: %s" % wrote.get_file())
	var found: PackedStringArray = _ai_in_window()
	_ok(found.is_empty(), "and still nothing of AI in the window%s" % _listed(found))


# -- reading the window -------------------------------------------------------


## Every visible control's words, by where it is, that name AI.
func _ai_in_window() -> PackedStringArray:
	var found := PackedStringArray()
	for child: Node in root.get_children():
		found.append_array(_ai_in(child))
	return found


func _ai_in(node: Node) -> PackedStringArray:
	var found := PackedStringArray()
	# The first visit's one button offering the assistant is allowed its name.
	if node == null or node == _main.get("_offer"):
		return found
	if node is Control:
		var control: Control = node
		if not control.is_visible_in_tree():
			return found
		for property: String in ["text", "placeholder_text", "tooltip_text"]:
			var value: Variant = control.get(property)
			if typeof(value) == TYPE_STRING and _ai.search(str(value)) != null:
				found.append("%s %s: %s" % [control.get_class(), property, str(value).left(60)])
	elif node is Window and not (node as Window).visible:
		return found
	for child: Node in node.get_children():
		found.append_array(_ai_in(child))
	return found


## Every row of every menu on the bar, open or not.
func _ai_in_menus() -> PackedStringArray:
	var found := PackedStringArray()
	var shell: Shell = _main.get("_shell")
	for title: String in ["File", "Edit", "View", "Build", "Tools", "Help"]:
		var button: MenuButton = shell.menu(title)
		if button != null:
			found.append_array(_ai_in_popup(button.get_popup()))
	return found


func _ai_in_popup(popup: PopupMenu) -> PackedStringArray:
	var found := PackedStringArray()
	if popup == null:
		return found
	for index: int in popup.item_count:
		for words: String in [popup.get_item_text(index), popup.get_item_tooltip(index)]:
			if _ai.search(words) != null:
				found.append("%s: %s" % [popup.name, words.left(60)])
	for child: Node in popup.get_children():
		if child is PopupMenu:
			found.append_array(_ai_in_popup(child))
	return found


func _texts_in(node: Node) -> String:
	if node == null:
		return ""
	var out: String = ""
	var value: Variant = node.get("text")
	if typeof(value) == TYPE_STRING:
		out += str(value) + " "
	for child: Node in node.get_children():
		out += _texts_in(child)
	return out


func _rows(popup: PopupMenu) -> String:
	if popup == null:
		return "none"
	var rows := PackedStringArray()
	for index: int in popup.item_count:
		if not popup.is_item_separator(index):
			rows.append(popup.get_item_text(index))
	return ", ".join(rows)


static func _listed(found: PackedStringArray) -> String:
	return "" if found.is_empty() else " — " + "; ".join(found.slice(0, 6))


func _a_part() -> int:
	var store: ModelStore = _main.get("_store")
	for brick: BrickWorld.Brick in (_main.get("_world") as BrickWorld).bricks():
		if not store.scenery.has(brick.id):
			return brick.id
	return 0


static func _picture() -> Image:
	var image := Image.create(48, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.3, 0.8))
	image.fill_rect(Rect2i(12, 8, 24, 16), Color(0.95, 0.8, 0.1))
	return image


# -- driving it ---------------------------------------------------------------


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
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
		event.ctrl_pressed = command
		event.pressed = down
		Input.parse_input_event(event)
		await _frames(2)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(SHOTS + name + ".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/noai/%s.png" % name)


static func _forget(folder: String) -> void:
	var path: String = ProjectSettings.globalize_path(folder)
	if not DirAccess.dir_exists_absolute(path):
		return
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
