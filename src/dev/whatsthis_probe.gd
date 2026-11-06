## Help, What's This? and where the part in hand goes, on the status bar
## (docs/APP_UX4.md, unit 10: whatsthis).
##
##   godot --path . --resolution 1280x720 --script src/dev/whatsthis_probe.gd
##   tools/probe.sh whatsthis_probe
##   ... -- --shots=DIR    the pictures there, not in shots/whatsthis/
##
## Every question is asked as a person asks it: Shift+F1 pressed, then a
## click on the control, the move, press and release sent to the window.
## The bar, each line by its number:
## 1. every toolbar button, bin chip, Properties field (one part selected)
##    and panel button (the parts bin's, Properties', the model tree's, the
##    assistant's, the status bar's and the side panels' rails) answers with
##    words, in the bubble beside it: none empty past its name, none the
##    same as another's, each its own or those of what it is part of, never
##    only the panel's it is in; the bubble just under, over or beside it,
##    in the window, no taller than its words. The bin's part tiles and colour swatches
##    are its contents, each named by its part or colour, not its buttons;
## 2. the click does nothing else: the control under it never hears the
##    press or the release, and nothing of the model, the selection, the
##    tool, the part in hand, the bin's chip, the panels, the camera, the
##    keys' focus or the windows open changes. One click with no question
##    first, on the Move tool, shows the check sees a click that does;
## 3. while a part is in hand, the status bar's x, z and height are where it
##    then lands, to the stud and plate: a 2 x 4 brick aimed at four places
##    either side of the middle, on the ground or on what is in the way, and
##    at another brick's top, a 1 x 2 plate turned, aimed at the ground and
##    at that top, and two parts carried as a copy (Ctrl+D), each read off
##    the bar, put down with a click and measured; nothing in hand, nothing
##    said.
## And: Help, What's This? is a row of the Help menu with Shift+F1, under
## each of the four key presets, kept for itself as F1 is and no other
## action's; Esc, a right click and Shift+F1 again each leave without
## asking; the status bar asks while it waits; and every new word reads in
## German, French and Spanish.
##
## The data folder is the run's own (probe.sh gives one).
extends SceneTree

const SHIFT := KEY_MASK_SHIFT

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _verbs: EditVerbs
var _camera: CadCamera
var _library: PartLibrary
var _bin: PartsBin
var _shots: String = ""
var _size: String = ""
## Whether this build has What's This at all: on one from before, the
## questions are not asked, and their lines fail.
var _asks: bool = false
## What the control under a click heard of it.
var _heard: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ShellPrefs.kept_by_a_check = _own_data_folder()
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.substr(8)
	if _shots.is_empty():
		_shots = ProjectSettings.globalize_path("res://shots/whatsthis")
	DirAccess.make_dir_recursive_absolute(_shots)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_world = _main.get("_world")
		if _world != null and _world.brick_count() > 1 and _main.get("_shell") != null:
			break
	if _world == null or _main.get("_shell") == null:
		print("  whatsthis probe: SKIPPED — the window did not come up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_bin = _main.get("_bin")
	(_main.get("_store") as ModelStore).keeps = false
	Keymap.reset()
	Keymap.use("brickworks")
	_main.call("set_assistant", true)
	await _frames(30)
	var window := Vector2i(DisplayServer.window_get_size())
	_size = "%dx%d" % [window.x, window.y]
	print("  a %s window" % _size)

	_the_row()
	await _leaving()
	await _answers()
	await _place()
	_languages()

	Keymap.use("brickworks")
	Keymap.reset()
	print("")
	if _failures == 0:
		print("whatsthis probe: all checks passed")
	else:
		print("whatsthis probe: %d check(s) FAILED" % _failures)
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- Help, What's This? ------------------------------------------------------------

func _the_row() -> void:
	print("\n  Help, What's This?, Shift+F1")
	_asks = _shell.command("whats_this") != null
	_check("a command What's This? (none: a person has no way to ask what a control does but "
		+ "its tooltip, and most panels' controls have none)", _asks)
	if not _asks:
		return
	var help: MenuButton = _shell.menu("Help")
	var popup: PopupMenu = help.get_popup() if help != null else null
	var at: int = popup.get_item_index(_shell.menu_id("whats_this")) if popup != null else -1
	_check("...a row of the Help menu (%s)" % (popup.get_item_text(at) if at >= 0 else "none"), at >= 0)
	for preset: String in Keymap.PRESETS:
		Keymap.use(preset)
		var key: int = Keymap.key_of("whats_this")
		var others: Array = []
		for action: String in Keymap.actions():
			if action != "whats_this" and Keymap.key_of(action) == SHIFT | KEY_F1:
				others.append(action)
		if popup != null and at >= 0:
			popup.about_to_popup.emit()
		var shown: int = popup.get_item_accelerator(at) if at >= 0 else 0
		_check("%s: its key %s, shown on the row (%s), no other action's%s" % [preset,
			Keymap.listed("whats_this"), Shell.key_text(shown),
			"" if others.is_empty() else ": also " + ", ".join(others)],
			key == SHIFT | KEY_F1 and shown == Shell.menu_accel(key) and others.is_empty())
	Keymap.use("brickworks")
	_check("...kept for itself, as F1 is: %s" % Keymap.why_not("whats_this", KEY_MASK_ALT | KEY_W),
		not Keymap.settable("whats_this")
		and not Keymap.why_not("select_all", SHIFT | KEY_F1).is_empty())


## The question, and three ways to leave it unasked.
func _leaving() -> void:
	if not _asks:
		return
	print("\n  asked, and left unasked")
	await _ask()
	var asker: Node = _asker()
	_check("Shift+F1: the next click is a question (%s)" % ("asking" if _asking() else "not asking"),
		_asking())
	var line: String = str(_shell.status.fields()["line"])
	_check("...the status bar says so: \"%s\"" % line, line.begins_with("What's This"))
	# Over a button, outlined, the pointer marked: pictured.
	var undo: Control = _shell.toolbar.controls_by_name().get("tool_undo")
	await _move(_rect(undo).get_center())
	await _shot("asking")
	await _key(KEY_ESCAPE)
	_check("...Esc leaves it unasked (%s)" % ("still asking" if _asking() else "left"),
		not _asking() and not bool(asker.call("answering")))
	await _ask()
	var mode: String = _verbs.mode
	await _press(_rect(undo).get_center(), MOUSE_BUTTON_RIGHT)
	_check("...so does a right click, and it does nothing else (the tool %s)" % _verbs.mode,
		not _asking() and not bool(asker.call("answering")) and _verbs.mode == mode)
	await _ask()
	await _ask()
	_check("...and Shift+F1 again", not _asking())
	_check("...and the status bar says what it said before: \"%s\"" % _shell.status.fields()["line"],
		not str(_shell.status.fields()["line"]).begins_with("What's This"))


# -- 1 and 2: every control answers, and does nothing else ---------------------------

func _answers() -> void:
	print("\n  1, 2: every control asked about answers, and does nothing else")
	if not _asks:
		_check("1: every toolbar button, bin chip, Properties field and panel button answers with words "
			+ "(no What's This to ask with)", false)
		_check("2: the click does nothing else (no What's This to ask with)", false)
		return
	var bin_dock: SideDock = _main.get("_bin_dock")
	var props_dock: SideDock = SideDock.of(_shell.inspector)
	var chat_dock: SideDock = _main.get("_chat_dock")
	# Each panel open in turn, as a person opens it: in a window that shows
	# one column at a time the others are their rails.
	var phases: Array = [
		["toolbar button", "", _toolbar],
		["bin chip", "bin", _chips],
		["panel button", "bin", _buttons_in.bind(bin_dock)],
		["Properties field", "properties", _fields],
		["panel button", "properties", _buttons_in.bind(props_dock)],
		["panel button", "assistant", _buttons_in.bind(chat_dock)],
		["panel button", "", _buttons_in.bind(_shell.status)],
	]
	var said: Dictionary = {}   ## answer -> what said it
	var seen: Dictionary = {}   ## each control asked once
	var counts: Dictionary = {}   ## kind -> [asked, answered]
	var quiet: int = 0
	var asked: int = 0
	var bad: Array = []
	var loud: Array = []
	var shot_of: Dictionary = {"toolbar button": "answer_toolbar", "bin chip": "answer_chip",
		"Properties field": "answer_field", "panel button": "answer_panel"}
	var pictured: Dictionary = {}
	for phase: Array in phases:
		var kind: String = phase[0]
		await _open_panel(str(phase[1]), bin_dock, props_dock, chat_dock)
		var controls: Array = (phase[2] as Callable).call()
		if not counts.has(kind):
			counts[kind] = [0, 0]
		for control: Control in controls:
			if seen.has(control) or not is_instance_valid(control) or not control.is_visible_in_tree():
				continue
			seen[control] = true
			await _into_sight(control)
			var answer: Dictionary = await _ask_about(control)
			asked += 1
			counts[kind][0] += 1
			var named: String = _named(control)
			if not answer["quiet"]:
				loud.append("%s %s: %s" % [kind, named, answer["did"]])
			else:
				quiet += 1
			var words: String = str(answer["words"])
			var whole: String = str(answer["said"])
			if words.strip_edges().is_empty():
				bad.append("%s %s said nothing past its name (\"%s\")" % [kind, named, whole])
				continue
			# Its own words, or those of what it is part of: not the panel's,
			# which say only where it is.
			var about: Variant = answer["about"]
			if about == null or about is SideDock or not (about == control
					or (about as Node).is_ancestor_of(control) or control.is_ancestor_of(about)):
				bad.append("%s %s answered for %s, not itself: \"%s\"" % [kind, named,
					"nothing" if about == null else (about as Node).get_class() + " " + str((about as Node).name),
					whole.replace("\n", " / ")])
				continue
			if said.has(whole):
				bad.append("%s %s said what %s said: \"%s\"" % [kind, named, said[whole], whole.replace("\n", " / ")])
				continue
			if not str(answer["placed"]).is_empty():
				bad.append("%s %s: its bubble %s" % [kind, named, answer["placed"]])
				continue
			said[whole] = "%s %s" % [kind, named]
			counts[kind][1] += 1
			if not pictured.has(kind):
				pictured[kind] = true
				await _shot(shot_of[kind])
			await _dismiss()
	for kind: String in counts:
		_check("1: %d %ss asked, each answered with words of its own: %d" % [counts[kind][0], kind,
			counts[kind][1]], counts[kind][0] > 0 and counts[kind][0] == counts[kind][1])
	for line: String in bad:
		print("      %s" % line)
	_check("1: none empty past its name, none the same as another's (%d asked, %d said alike or nothing)"
		% [asked, bad.size()], bad.is_empty() and asked > 0)
	for line: String in loud:
		print("      %s" % line)
	_check("2: each click did nothing else (%d of %d quiet)" % [quiet, asked], loud.is_empty() and asked > 0)
	# And a click with no question first, which does: the check sees it.
	var move: Control = _shell.toolbar.controls_by_name().get("tool_mode_move")
	var before: Dictionary = _state()
	_listen(move)
	await _click(_rect(move).get_center())
	var heard: bool = not _heard.is_empty()
	_unlisten(move)
	var changed: Array = _changes(before, _state())
	_check("2: ...the same check, on a click on the Move tool with no question first, sees it act "
		+ "(heard: %s; changed: %s)" % [heard, ", ".join(changed)], heard and not changed.is_empty())
	_verbs.set_mode("select")
	_builder.selection.clear()
	_builder.selection_changed.emit(0)
	await _frames(10)


## One question: Shift+F1, a click on [param control], the answer read.
func _ask_about(control: Control) -> Dictionary:
	await _dismiss()
	_release_focus()
	await _frames(2)
	var before: Dictionary = _state()
	await _ask()
	var spot: Vector2 = _spot(control)
	_listen(control)
	await _click(spot)
	await _frames(3)
	_unlisten(control)
	var asker: Node = _asker()
	var said: String = str(asker.get("said")) if bool(asker.call("answering")) else ""
	var about: Variant = asker.get("said_of") if bool(asker.call("answering")) else null
	if about != null and not is_instance_valid(about):
		about = null
	# The bubble beside what it is about, just under it or just over it, in
	# the window, and only as tall as its words.
	var placed: String = ""
	if about != null:
		var bubble: Rect2 = asker.call("bubble_rect")
		var near: Rect2 = _rect(about as Control)
		var room: Rect2 = root.get_visible_rect()
		if not room.encloses(bubble):
			placed = "out of the window (%s)" % bubble
		elif bubble.size.y > room.size.y * 0.4:
			placed = "%d px tall" % int(bubble.size.y)
		elif absf(bubble.position.y - near.end.y - 6.0) > 1.0 and absf(near.position.y - bubble.end.y - 6.0) > 1.0 \
				and absf(bubble.position.x - near.end.x - 6.0) > 1.0 and absf(near.position.x - bubble.end.x - 6.0) > 1.0:
			placed = "not beside it (%s, it %s)" % [bubble, near]
	var changed: Array = _changes(before, _state())
	if not _heard.is_empty():
		changed.push_front("it heard %s" % ", ".join(_heard))
	var lines: PackedStringArray = said.split("\n")
	# The words past its name: a one-line answer is a name alone.
	var words: String = "\n".join(lines.slice(1)) if lines.size() > 1 else ""
	return {"said": said, "words": words, "about": about, "placed": placed,
		"quiet": changed.is_empty(), "did": ", ".join(changed)}


## A point of [param control] in sight: its middle, or the middle of what
## of it is in sight.
func _spot(control: Control) -> Vector2:
	var rect: Rect2 = _rect(control)
	var room: Rect2 = root.get_visible_rect()
	var clip: Node = control.get_parent()
	while clip != null:
		if clip is Control and (clip as Control).clip_contents:
			room = room.intersection(_rect(clip as Control))
		clip = clip.get_parent()
	var seen: Rect2 = rect.intersection(room)
	return seen.get_center() if seen.has_area() else rect.get_center()


func _into_sight(control: Control) -> void:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer:
			(node as ScrollContainer).ensure_control_visible(control)
			await _frames(4)
			return
		node = node.get_parent()


func _toolbar() -> Array:
	var out: Array = []
	for control: Control in _shell.toolbar.controls_by_name().values():
		if not control in out and control.is_visible_in_tree():
			out.append(control)
	return out


func _chips() -> Array:
	var row: Node = _bin.get("_category_row")
	var out: Array = []
	for child: Node in row.get_children():
		if child is Button and (child as Button).visible:
			out.append(child)
	return out


func _fields() -> Array:
	var out: Array = []
	for spin: Node in _shell.inspector.find_children("*", "SpinBox", true, false):
		if (spin as Control).is_visible_in_tree():
			out.append(spin)
	return out


## One side panel open, as its rail opens it, and what it shows: the
## properties with one part selected; "" for none in particular.
func _open_panel(which: String, bin_dock: SideDock, props_dock: SideDock, chat_dock: SideDock) -> void:
	await _dismiss()
	match which:
		"bin":
			bin_dock.set_open(true, false)
		"properties":
			props_dock.set_open(true, false)
			_shell.inspector.set_open(true)
			if _builder.selection.is_empty():
				for brick: BrickWorld.Brick in _world.bricks():
					if _builder.select_brick(brick.id, false):
						break
		"assistant":
			if chat_dock != null:
				chat_dock.set_open(true, false)
		_:
			return
	await _frames(30)


## A panel's own buttons: everything pressable in it but the bin's chips,
## part tiles and colour swatches, in sight.
func _buttons_in(place: Node) -> Array:
	var out: Array = []
	if place == null:
		return out
	var grid: Node = _bin.get("_grid")
	var chips: Node = _bin.get("_category_row")
	for node: Node in place.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node
		if not button.is_visible_in_tree() or button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if grid.is_ancestor_of(button) or chips.is_ancestor_of(button) or button is PartsBin.Swatch:
			continue
		if _rect(button).size.x < 4.0 or _rect(button).size.y < 4.0:
			continue
		if not root.get_visible_rect().encloses(_rect(button).grow(-1.0)):
			continue
		out.append(button)
	return out


# -- what a click could have done ---------------------------------------------------

func _state() -> Dictionary:
	var bin_dock: SideDock = _main.get("_bin_dock")
	var chat_dock: SideDock = _main.get("_chat_dock")
	var windows: int = 0
	for sub: Window in root.get_embedded_subwindows():
		if sub.visible and not Tooltips.is_tooltip(sub):
			windows += 1
	var selected: Array = _builder.selection.keys()
	selected.sort()
	var turned: Transform3D = _camera.global_transform
	return {
		"parts": _world.brick_count(), "history": _builder.history_depth(),
		"selection": str(selected), "tool": _verbs.mode, "snap": _verbs.snap,
		"turn step": _verbs.turn_step, "in hand": "%s %s" % [_builder.held_part, _builder.is_carrying()],
		"chip": str(_bin.get("_category")), "search": str((_bin.get("_search") as LineEdit).text),
		"panels": "%s %s %s %s" % [bin_dock.is_open(), chat_dock.is_open() if chat_dock != null else false,
			SideDock.of(_shell.inspector).is_open(), _shell.inspector.is_open()],
		"camera": "%s %s" % [turned.origin.snapped(Vector3.ONE * 0.01), turned.basis.get_euler().snapped(Vector3.ONE * 0.001)],
		"focus": str(root.gui_get_focus_owner()),
		"windows": windows,
		"list": str((_bin.get("_list") as BaseButton).button_pressed),
	}


func _changes(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []
	for key: String in before:
		if str(before[key]) != str(after[key]):
			out.append("%s %s -> %s" % [key, before[key], after[key]])
	return out


func _listen(control: Control) -> void:
	_heard = []
	control.gui_input.connect(_hear)
	for node: Node in control.find_children("*", "Control", true, false):
		(node as Control).gui_input.connect(_hear)
	if control is BaseButton:
		(control as BaseButton).pressed.connect(_pressed)


func _unlisten(control: Control) -> void:
	if control.gui_input.is_connected(_hear):
		control.gui_input.disconnect(_hear)
	for node: Node in control.find_children("*", "Control", true, false):
		if (node as Control).gui_input.is_connected(_hear):
			(node as Control).gui_input.disconnect(_hear)
	if control is BaseButton and (control as BaseButton).pressed.is_connected(_pressed):
		(control as BaseButton).pressed.disconnect(_pressed)


func _hear(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_heard.append("a %s" % ("press" if event.is_pressed() else "release"))


func _pressed() -> void:
	_heard.append("pressed")


# -- 3: where the part in hand goes ------------------------------------------------

func _place() -> void:
	print("\n  3: where the part in hand goes, on the status bar")
	var fields: Dictionary = _shell.status.fields()
	if not fields.has("place"):
		_check("3: the status bar says where the part in hand goes (it does not: its fields are %s)"
			% ", ".join(fields.keys()), false)
		return
	_main.call("clear_model")
	_verbs.set_mode("select")
	_camera.frame(AABB(Vector3(-120, 0, -120), Vector3(240, 60, 240)))
	await _still()
	_check("3: nothing in hand, nothing said (\"%s\")" % _shell.status.fields()["place"],
		str(_shell.status.fields()["place"]).is_empty())
	await _hold("3001")
	# Where the pointer is aimed: the part goes where the builder puts it
	# from there, on what is in the way or beside it, and that is measured.
	var cases: Array = [["aimed at the ground right of the middle", Vector3(60, 0, 20)],
		["aimed at the ground behind and left", Vector3(-80, 0, -40)],
		["aimed at the ground in front", Vector3(0, 0, 100)],
		["aimed at the middle", Vector3(0, 0, 0)]]
	var first: int = 0
	for one: Array in cases:
		var made: int = await _put(str(one[0]), _screen(one[1]))
		if first == 0:
			first = made
	# On top of the first.
	if first != 0:
		var top: Vector3 = _top_of(first)
		await _put("aimed at the top of the first brick", _screen(top), "place_on_brick")
	# Turned a quarter, a 1 x 2 plate, half studs across.
	await _hold("3023")
	await _key(KEY_R)
	await _put("a 1 x 2 plate turned, aimed at the ground in front and right", _screen(Vector3(80, 0, 60)))
	if first != 0:
		await _put("a 1 x 2 plate turned, aimed at the top of the first brick", _screen(_top_of(first)))
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _frames(6)
	# Two parts carried as a copy.
	var two: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if two.size() < 2 and brick.part_id == "3001":
			two.append(brick.id)
	_builder.selection.clear()
	for id: int in two:
		_builder.select_brick(id, true)
	await _frames(6)
	await _key(KEY_D, true)
	await _frames(10)
	_check("3: two parts in hand, carried (Ctrl+D)", _builder.is_carrying())
	if _builder.is_carrying():
		await _put("two bricks carried, aimed at the ground in front and left", _screen(Vector3(-100, 0, 100)), "place_carried", true)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_builder.selection.clear()
	_builder.selection_changed.emit(0)
	_verbs.set_mode("select")
	await _frames(10)
	_check("3: put away, nothing said (\"%s\")" % _shell.status.fields()["place"],
		str(_shell.status.fields()["place"]).is_empty())


## The pointer at [param at], the bar read, a click there, and what was put
## down measured against what the bar said. The id of the first part put.
func _put(what: String, at: Vector2, picture: String = "", carried: bool = false) -> int:
	await _move(at + Vector2(3, 0))
	await _move(at)
	await _frames(6)
	var said: String = str(_shell.status.fields()["place"])
	if not picture.is_empty() or what.begins_with("aimed at the ground right"):
		await _shot(picture if not picture.is_empty() else "place_ground")
	var told: Variant = _read(said)
	var before: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		before[brick.id] = true
	await _click_whole(at)
	await _frames(6)
	var made: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not before.has(brick.id):
			made.append(brick)
	if made.is_empty() or told == null:
		_check("3: %s: the bar said \"%s\"; %s" % [what, said,
			"nothing was put down" if made.is_empty() else "which is no place"], false)
		return 0
	var box := AABB()
	var low: float = INF
	for n: int in made.size():
		var brick: BrickWorld.Brick = made[n]
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		var here: AABB = brick.transform * part.bounds
		box = here if n == 0 else box.merge(here)
		low = minf(low, part.lowest_at(brick.transform))
	var landed := Vector3(box.get_center().x / BrickLattice.STUD, low / BrickLattice.PLATE,
		box.get_center().z / BrickLattice.STUD)
	var read: Vector3 = told
	var near: bool = absf(read.x - landed.x) < 0.006 and absf(read.y - landed.y) < 0.006 \
		and absf(read.z - landed.z) < 0.006
	_check("3: %s: the bar said \"%s\"; %s landed with its middle at x %s, z %s studs, its foot %s plates up"
		% [what, said, "it" if made.size() == 1 else "the %d" % made.size(),
			_n(landed.x), _n(landed.z), _n(landed.y)], near)
	if carried:
		return made[0].id
	return made[0].id


## "x 2½, z −1 studs · 3 plates up" as (x, plates, z); null for no place.
func _read(said: String) -> Variant:
	var found: RegExMatch = RegEx.create_from_string(
		r"^x (\S+), z (\S+) studs · (?:(on the ground)|(\S+) plates? (up|down))$").search(said)
	if found == null:
		return null
	var height: float = 0.0
	if found.get_string(3).is_empty():
		height = _number(found.get_string(4)) * (1.0 if found.get_string(5) == "up" else -1.0)
	return Vector3(_number(found.get_string(1)), height, _number(found.get_string(2)))


func _number(text: String) -> float:
	var sign: float = -1.0 if text.begins_with("−") else 1.0
	var rest: String = text.trim_prefix("−")
	var value: float = 0.0
	for quarter: Array in [["¼", 0.25], ["½", 0.5], ["¾", 0.75]]:
		if rest.ends_with(str(quarter[0])):
			rest = rest.trim_suffix(str(quarter[0]))
			value = float(quarter[1])
	return sign * (value + (float(rest) if not rest.is_empty() else 0.0))


func _n(value: float) -> String:
	return String.num(value, 2)


func _hold(part: String) -> void:
	_main.call("_on_part_chosen", part)
	for _n: int in 600:
		if _library.mesh_for(part) != null:
			break
		await process_frame
	await _frames(10)


func _top_of(brick_id: int) -> Vector3:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var box: AABB = brick.transform * _library.mesh_for(brick.part_id).bounds
	return Vector3(box.get_center().x, box.end.y, box.get_center().z)


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


## Until the camera stops moving: a frame eases there over many frames, and
## a point worked out while it moves is another point when the click lands.
func _still() -> void:
	var last: Transform3D = _camera.global_transform
	var same: int = 0
	for _n: int in 600:
		await process_frame
		var now: Transform3D = _camera.global_transform
		same = same + 1 if now.is_equal_approx(last) else 0
		last = now
		if same >= 5:
			return


# -- the new words in each language --------------------------------------------------

func _languages() -> void:
	print("\n  the new words in German, French and Spanish")
	if not _asks:
		_check("the new words translated (no What's This to have words)", false)
		return
	var words: Array = [
		"What's This?", "Click any button, field or panel next to hear what it does, without doing it",
		"What's This: click any button, field or panel to hear what it does · Esc to stop",
		"Only the Brick parts in the bin: 12 of them",
		"Parts of every kind in the bin, not one kind alone; with a search typed, all it finds",
		"Greyed now: Select a part first", "Greyed now", "In use now", "On now", "Off now",
		"The model", "A click here does what the tool in use does:",
		"x 2½, z −1 studs · 3 plates up", "x 0, z 4 studs · on the ground",
		"x −1, z ½ studs · 1 plate up", "x 1, z 1 studs · 2 plates down",
		"x 1, z 1 studs · 1 plate down",
		"Where the part in hand goes if put down now: studs across (x) and back (z) from the middle of the floor, and plates up from the ground",
		"Greyed now: Nothing to undo yet", "Greyed now: Nothing to redo",
		WhatsThis.RAIL_OPEN, WhatsThis.RAIL_FOLDED, WhatsThis.PANEL,
		WhatsThis.NAMED_ONLY % "Assistant",
		"Sends what is written above to the assistant, which designs it and builds it in the model; with parts chosen over the box, it works on those",
		"Checks the key pasted above with Anthropic and keeps it, so the assistant designs on your own Anthropic account",
		"Opens Anthropic's Console in the browser, at the page where an account makes its keys",
		"Shows how the Claude desktop and mobile apps add Brickworks, with the address to paste",
		"Shows this browser's own address, to add to Claude by hand: the way before Claude could sign in",
	]
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		var missing: Array = []
		for english: String in words:
			var drawn: String = TranslationServer.translate(english)
			# A number is kept as it is ("2½", "−1"), and is no word.
			var kept: Array = Language.left_in_english(english).filter(func(w: Variant) -> bool:
				var rest: String = str(w)
				for mark: String in "0123456789½¼¾−-.,: ":
					rest = rest.replace(mark, "")
				return not rest.is_empty())
			if drawn == english or not kept.is_empty():
				missing.append("\"%s\"%s" % [english, " (kept " + str(kept) + ")" if not kept.is_empty() else ""])
		_check("%s: each of the %d reads in the language%s" % [code, words.size(),
			"" if missing.is_empty() else ", but not " + "; ".join(missing)], missing.is_empty())
	Language.apply("en")


# -- the pointer and the keys ----------------------------------------------------------

func _asker() -> Node:
	return _main.get_node_or_null("WhatsThis")


## Esc while the bubble or the question is up, which it takes; else none,
## which would let go of the selection.
func _dismiss() -> void:
	var asker: Node = _asker()
	if asker != null and (bool(asker.get("asking")) or bool(asker.call("answering"))):
		await _key(KEY_ESCAPE)


func _asking() -> bool:
	var asker: Node = _asker()
	return asker != null and bool(asker.get("asking"))


## Shift+F1, as a person presses it.
func _ask() -> void:
	await _key(KEY_F1, false, true)


func _release_focus() -> void:
	var focused: Control = root.gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _named(control: Control) -> String:
	var words: String = ""
	for property: String in ["text", "accessibility_name", "tooltip_text"]:
		var value: Variant = control.get(property)
		if typeof(value) == TYPE_STRING and not str(value).strip_edges().is_empty():
			words = str(value).strip_edges().get_slice("\n", 0).left(40)
			break
	return "%s \"%s\"" % [control.get_class(), words]


func _as_event(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _click(at: Vector2) -> void:
	await _move(at)
	await _click_whole(at)


func _press(at: Vector2, which: MouseButton) -> void:
	await _move(at)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = which
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)


## A press and a release in whole pixels, as a browser sends them.
func _click_whole(at: Vector2) -> void:
	var whole: Vector2 = _as_event(at).floor()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		if down:
			event.button_mask = MOUSE_BUTTON_MASK_LEFT
		event.position = whole
		event.global_position = whole
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)


func _key(code: Key, command: bool = false, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(_shots.path_join("%s_%s.png" % [name, _size]))


func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _check(what: String, held: bool) -> void:
	print("  %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1
