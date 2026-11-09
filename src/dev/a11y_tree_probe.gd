## A screen reader can browse the whole window, a panel put away is gone from
## what it reads, and each dialog is where it says it is (a11ytree).
##
##   godot --path . --resolution 1280x720 --script src/dev/a11y_tree_probe.gd
##   tools/probe.sh a11y_tree_probe
##   PROBE_SIZE=1400x900 tools/probe.sh a11y_tree_probe
##   ... -- --only=browse,away,boxes   some parts only (a list, by commas)
##   ... -- --shots=DIR                a picture of each step, kept there
##   ... -- --dump=DIR                 the app's tree and what browsing reached, as JSON
##
## Read as a screen reader reads it, as a11y_modal_probe does: the app run
## again in a D-Bus session of its own where tools/a11y_tree.py says a screen
## reader is on, so Godot's own "auto" accessibility comes on, and the tree
## read back over AT-SPI. Through the way in first (gate_for_probe, a
## throwaway account signed in and deleted at the end; needs .env), a part
## selected so the properties show.
##
## browse: the window walked from its root down through each element's
## children as AT-SPI lists them, as a screen reader browses it (Orca's
## flat review, its structural navigation). It reaches the menus, the
## toolbar, the parts bin and its search, the view (its cube and the
## buttons round it), the properties and the status line, each where it is
## on screen, in that order. On pre261 the walk stopped at Model name:
## AccessKit 0.22 (accesskit_consumer 0.38, iterators.rs
## next_filtered_sibling) ends a list of children where an element of no
## role and no children (a spacer) comes before a hidden one that has
## children, and the top bar had one, its spacer and then the hidden Claude
## tab. And the view had nothing in it a screen reader lists: its cube and
## buttons were plain controls, which AccessKit passes by.
##
## away: each panel the menus open over the model, put away as a person
## does (Escape, else its command again), is gone from the tree the frame
## it was hidden in: nothing of it found where it was, pointing or
## browsing, and a dialog brought up there (Clear the baseplate?) is what
## pointing at it finds. Read with the app held at the end of that frame,
## at a person's 30 frames a second. On pre261 the panels stayed:
## CanvasItem::set_visible never told AccessKit a panel was hidden.
##
## boxes: each dialog brought up is read back where it is drawn, within
## 2 px (pointed at, as Orca's mouse review finds it), and so is a menu of
## the bar's (browsed to: pointing at a menu finds what is under it, as the
## engine hit-tests a window below what comes after it in the tree); and
## of every window the main window has made, up or not, those the engine
## would say are elsewhere are each placed again (src/ui/placed_window.gd).
## On pre261 a menu or a dialog under controls not at the window's corner
## was said to be that far from where it was drawn (Window's
## get_accessibility_transform undoes only its parent's own offset).
extends SceneTree

const READER := "res://tools/a11y_tree.py"
const PROBE := "res://src/dev/a11y_tree_probe.gd"
## The script that places a window again (src/ui/access_tree.gd), where it is.
const PLACING := "res://src/ui/placed_window.gd"
## The commands that open a dialog or a panel, as a11y_names_probe opens them.
const NAMES := preload("res://src/dev/a11y_names_probe.gd")
## How long the reader may take over one read.
const READ_MS := 120000
## How near a box must be to where it is drawn, in the window's pixels.
const NEAR := 2.0
## The roles a window has in the tree.
const WINDOWS: Array[String] = ["dialog", "frame", "window", "alert", "file chooser", "color chooser"]
## The parts of the window browsing must reach, in the order a person reads
## them.
const REGIONS: Array[String] = ["menus", "toolbar", "parts bin", "view", "properties", "status line"]

var _failures: int = 0
var _main: Node
var _shell: Shell
var _dir: String = ""
var _shots: String = ""
var _dump: String = ""
var _asked: int = 0
var _xid: int = 0
var _email: String = ""
var _password: String = ""
var _only: PackedStringArray = []


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=")
		elif argument.begins_with("--dir="):
			_dir = argument.trim_prefix("--dir=")
		elif argument.begins_with("--dump="):
			_dump = argument.trim_prefix("--dump=")
		elif argument.begins_with("--only="):
			_only = argument.trim_prefix("--only=").split(",", false)
	if OS.get_cmdline_user_args().has("--child"):
		_child()
	else:
		_parent()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _wanted(part: String) -> bool:
	return _only.is_empty() or _only.has(part)


# -- the parent: the app run again where a screen reader is on --------------


func _parent() -> void:
	if DisplayServer.get_name() != "X11":
		print("a11y_tree_probe: not run: a screen reader's tree is read over X11's AT-SPI "
			+ "(run it as its header says)")
		quit(3)
		return
	var folder: String = OS.get_user_data_dir().path_join("a11y_tree")
	DirAccess.make_dir_recursive_absolute(folder)
	for old: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(old))
	var size: Vector2i = DisplayServer.window_get_size()
	var arguments := PackedStringArray(["--", "python3", "-I",
		ProjectSettings.globalize_path(READER), folder, "--", OS.get_executable_path(),
		"--resolution", "%dx%d" % [size.x, size.y], "--path", ProjectSettings.globalize_path("res://"),
		"--script", PROBE, "--", "--child", "--dir=" + folder])
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only=") or argument.begins_with("--shots=") \
				or argument.begins_with("--dump="):
			arguments.append(argument)
	print("a11y_tree: in a %d x %d window" % [size.x, size.y])
	var said: Array = []
	var code: int = OS.execute("dbus-run-session", arguments, said, true)
	var output: String = "".join(said)
	print(output)
	var failed: int = 0
	for line: String in output.split("\n"):
		if line.begins_with("  FAIL"):
			failed += 1
	_check("the app's tree was read where a screen reader is on, on a bus of the run's own",
		output.contains("a screen reader said to be on"))
	_check("the run came to its end and passed: exit %d, %d checks failed" % [code, failed],
		code == 0 and failed == 0 and output.contains("a11y_tree: all checks passed"))
	if output.contains("SCRIPT ERROR") or output.contains("Parse Error"):
		_check("the run had no script error", false)
	print("a11y_tree: %s" % ("PASS" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures > 0 else 0)


# -- the child: the app, as a person with a screen reader meets it ---------


func _child() -> void:
	Account.where = "user://probe_session.json"
	Account._clear()
	SaveTo.native = false
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	for _n: int in 30:
		await process_frame
	var playback: Variant = _main.get("_playback")
	if playback != null:
		playback.stop()
	_shell = _main.get("_shell")
	_xid = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	print("    accessibility on in the app: %s" % is_accessibility_enabled())
	if not await _way_in():
		await _finish()
		return
	# The keys given to the window, as a click on it gives them on a
	# desktop: Xvfb has no window manager to.
	await _ask({"do": "away", "xid": _xid})
	# A part selected, so the properties show what it is and where.
	_select_a_part()
	await _frames(20)
	await _idle()
	if not _dump.is_empty():
		await _write_dump("start")
	if _wanted("browse"):
		await _browse()
	if _wanted("away"):
		await _panels_away()
	if _wanted("boxes"):
		await _boxes()
	await _finish()


func _select_a_part() -> void:
	var builder: Builder = _main.get("_builder")
	var store: ModelStore = _main.get("_store")
	for brick: BrickWorld.Brick in (_main.get("_world") as BrickWorld).bricks():
		if not store.scenery.has(brick.id):
			builder.select_brick(brick.id, false)
			return


# -- browse -----------------------------------------------------------------


## What browsing must reach, region by region: each a list of controls on
## screen, by their place in the window's pixels.
func _targets() -> Dictionary:
	var out: Dictionary = {}
	var bar: ModelBar = _main.get("_bar")
	var menus: Array = [bar.mark]
	for button: Node in bar.menus.get_children():
		if button is Control and (button as Control).is_visible_in_tree():
			menus.append(button)
	out["menus"] = menus
	var tools: Array = []
	for control: Variant in _shell.toolbar.controls_by_name().values():
		if control is Control and (control as Control).is_visible_in_tree():
			tools.append(control)
	out["toolbar"] = tools
	var bin: PartsBin = _main.get("_bin")
	var parts: Array = [bin.get("_search")]
	var tile: Control = _first_tile(bin)
	if tile != null:
		parts.append(tile)
	out["parts bin"] = parts
	# The view: its cube and the buttons round it, the view's own controls.
	var view: Array = []
	for node: Node in _all_under(_main.get("_over_model") as Control):
		if (node is ViewCube or node.get_parent() is ViewCube) and (node as Control).is_visible_in_tree() \
				and not (node.get_parent() is ViewCube and str(node.get("kind")) == "pan"):
			view.append(node)
	out["view"] = view
	# The properties of the part selected: where it is and how it is turned.
	var properties: Array = []
	for key: String in ["_x", "_y", "_z", "_yaw"]:
		var field: Variant = _shell.inspector.get(key)
		if field is Control and (field as Control).is_visible_in_tree():
			properties.append(field)
	out["properties"] = properties
	out["status line"] = [_shell.status.get("_hint")]
	return out


## The bin's first part shown, a tile a person could press.
static func _first_tile(bin: PartsBin) -> Control:
	var seen: Rect2 = bin.get_global_rect()
	for node: Node in _all_under(bin):
		var button: Button = node as Button
		if button != null and button.is_visible_in_tree() and button.accessibility_name.contains(", ") \
				and seen.encloses(button.get_global_rect()):
			return button
	return null


func _browse() -> void:
	print("  browse: the window from its root, through the children AT-SPI lists")
	var targets: Dictionary = _targets()
	var tree: Dictionary = await _ask({"do": "browse"})
	if tree.has("error"):
		_check("browse: the tree was read (%s)" % tree["error"], false)
		return
	var reached: Array = tree.get("reached", [])
	print("    %d elements reached in %d ms" % [reached.size(), int(tree.get("ms", 0))])
	if not _dump.is_empty():
		_write_json("browse_start.json", tree)
	await _shot("browse")
	# Reading order as the window is laid out: the bars along the top, then
	# the columns left to right, each top to bottom (at 1400 x 900 the
	# properties sit under the bin), then the status line.
	var areas: Dictionary = {}
	for region: String in REGIONS:
		var area := Rect2()
		for control: Control in targets.get(region, []):
			var box: Rect2 = _pixels(control.get_global_rect())
			area = box if area.size == Vector2.ZERO else area.merge(box)
		areas[region] = area
	var columns: Array = ["parts bin", "view", "properties"]
	columns.sort_custom(func(a: String, b: String) -> bool:
		var one: Rect2 = areas[a]
		var two: Rect2 = areas[b]
		if one.end.x <= two.position.x + 1.0 or two.end.x <= one.position.x + 1.0:
			return one.position.x < two.position.x
		return one.position.y < two.position.y)
	var order_wanted: Array = ["menus", "toolbar"] + columns + ["status line"]
	var firsts: Array[int] = []
	for region: String in order_wanted:
		var wanted: Array = targets.get(region, [])
		if wanted.is_empty():
			_check("browse: %s is on screen to be reached" % region, false)
			firsts.append(-1)
			continue
		var found: Array[String] = []
		var missing: Array[String] = []
		var first: int = -1
		for control: Control in wanted:
			var at: int = _reached_at(reached, _pixels(control.get_global_rect()))
			if at < 0:
				missing.append(_called(control))
			else:
				found.append("“%s” %s" % [reached[at][2], reached[at][1]])
				first = at if first < 0 else mini(first, at)
		firsts.append(first)
		_check("browse reaches %s: %d of %d (%s)%s" % [region, found.size(), wanted.size(),
			", ".join(found.slice(0, 4)) + (" …" if found.size() > 4 else ""),
			"; not reached: " + ", ".join(missing) if not missing.is_empty() else ""],
			missing.is_empty())
	var order: bool = not firsts.has(-1)
	for n: int in range(1, firsts.size()):
		if firsts[n] >= 0 and firsts[n - 1] >= 0 and firsts[n] < firsts[n - 1]:
			order = false
	_check("browse reaches them in reading order, %s (at %s of %d)" % [", ".join(order_wanted),
		", ".join(firsts.map(func(n: int) -> String: return str(n))), reached.size()], order)
	if reached.size() > 0:
		var last: Array = reached[reached.size() - 1]
		print("    the last reached: %s “%s”" % [last[1], str(last[2]).left(40)])


## Where in [param reached] an element is drawn over [param box], -1 if none.
static func _reached_at(reached: Array, box: Rect2) -> int:
	for n: int in reached.size():
		var at: Array = reached[n][3]
		var seen := Rect2(at[0], at[1], at[2], at[3])
		if _same_box(seen, box):
			return n
	return -1


static func _same_box(a: Rect2, b: Rect2) -> bool:
	return absf(a.position.x - b.position.x) <= NEAR + 1.0 and absf(a.position.y - b.position.y) <= NEAR + 1.0 \
		and absf(a.end.x - b.end.x) <= NEAR + 1.0 and absf(a.end.y - b.end.y) <= NEAR + 1.0


## A rect of the app's drawing in the window's own pixels, as the reader
## reads them (canvas_items stretch, the person's size).
func _pixels(rect: Rect2) -> Rect2:
	var to_pixels: Transform2D = root.get_final_transform()
	return Rect2(to_pixels * rect.position, to_pixels.basis_xform(rect.size))


static func _called(control: Control) -> String:
	if not control.accessibility_name.is_empty():
		return control.accessibility_name
	if control is Button and not (control as Button).text.is_empty():
		return (control as Button).text
	return "%s %s" % [control.get_class(), control.name]


# -- away -------------------------------------------------------------------


## The panels the menus open over the model (a11y_names_probe's openers
## that open no window of their own).
func _panels_away() -> void:
	print("  away: each panel put away is gone from the tree the frame after")
	# Frames as a person's are, a sixtieth of a second or longer: the engine
	# sends AccessKit the tree at most 60 times a second
	# (accessibility/general/updates_per_second), so a probe's frame of a
	# millisecond would wait on that, not on the app.
	Engine.max_fps = 30
	var gone: int = 0
	var tried: Array[String] = []
	for way: String in NAMES.OPENERS:
		if way in ["clear", "about", "save_as"] or way in NAMES.WITH_A_SELECTION:
			continue
		var outcome: String = await _away(way)
		if outcome.is_empty():
			continue
		tried.append(way)
		if outcome == "gone":
			gone += 1
	Engine.max_fps = 0
	_check("away: every panel put away was gone from the tree the frame after: %d of %d (%s)"
		% [gone, tried.size(), ", ".join(tried)], tried.size() > 0 and gone == tried.size())


## One panel brought up, put away, and the tree read the frame after.
## "gone", "stayed", or "" when it is no panel over the model.
func _away(way: String) -> String:
	var before: Dictionary = _shown()
	if not _shell.run(way):
		return ""
	var until: int = Time.get_ticks_msec() + 5000
	await _frames(12)
	while _shown().size() <= before.size() and Time.get_ticks_msec() < until:
		await process_frame
	await _frames(6)
	await _idle()
	var panel: Control = _new_panel(before)
	if panel == null:
		await _put_away(before)
		return ""
	var face: Rect2 = _pixels(panel.get_global_rect())
	var parts: Array[Rect2] = [face]
	for node: Node in _all_under(panel):
		var control: Control = node as Control
		if control != null and control.is_visible_in_tree() and control.size.x >= 4.0 \
				and control.size.y >= 4.0:
			parts.append(_pixels(control.get_global_rect()))
	await _shot("away_%s_up" % way)
	# Where it was in the window: a panel taller than the window scrolls.
	var seen: Rect2 = face.intersection(Rect2(Vector2.ZERO, Vector2(DisplayServer.window_get_size())))
	var centre: Vector2 = seen.get_center()
	var points: Array = [[centre.x, centre.y], [seen.position.x + 12.0, seen.position.y + 12.0],
		[seen.end.x - 12.0, seen.end.y - 12.0]]
	# Read once the frame it was hidden in is drawn, with the app held there:
	# what AccessKit had been sent by the end of that frame, no later one.
	var hidden_at: Array[int] = [-1]
	var read: Array[Dictionary] = [{}]
	var read_now := func() -> void:
		read[0] = _ask_now({"do": "browse", "points": points})
	var on_hidden := func() -> void:
		if hidden_at[0] < 0 and not panel.is_visible_in_tree():
			hidden_at[0] = Engine.get_process_frames()
			RenderingServer.frame_post_draw.connect(read_now, CONNECT_ONE_SHOT)
	panel.visibility_changed.connect(on_hidden)
	# Put away as a person does: Escape, else its command again.
	var how: String = "Escape"
	_key(KEY_ESCAPE)
	await _frames(3)
	if panel.is_visible_in_tree():
		how = "its command again"
		_shell.run(way)
		await _frames(3)
	if panel.is_visible_in_tree():
		print("    %s: neither Escape nor its command put it away: hidden by hand" % way)
		how = "by hand"
		(_ancestor_panel(panel)).visible = false
	for _n: int in 600:
		if not read[0].is_empty():
			break
		await process_frame
	if panel.visibility_changed.is_connected(on_hidden):
		panel.visibility_changed.disconnect(on_hidden)
	var tree: Dictionary = read[0] if not read[0].is_empty() \
		else {"error": "it was never put away"}
	if tree.has("error"):
		_check("away %s: the tree was read (%s)" % [way, tree["error"]], false)
		return "stayed"
	# The window itself (its frame) is under everything: not a part of it.
	var still: Array[String] = []
	for hit: Dictionary in tree.get("hits", []):
		var chain: Array = hit.get("chain", [])
		if not chain.is_empty() and str(chain[0]["role"]) != "frame" and _within_any(chain[0], parts):
			still.append("pointed at (%d, %d): %s “%s” %s" % [int(hit["at"][0]), int(hit["at"][1]),
				chain[0]["role"], str(chain[0]["name"]).left(30), chain[0].get("box")])
	var browsed: Array[String] = []
	for element: Array in tree.get("reached", []):
		var at: Array = element[3]
		var box := Rect2(at[0], at[1], at[2], at[3])
		if str(element[1]) == "frame" or box.size.x <= 0.0:
			continue
		for part: Rect2 in parts:
			if _same_box(box, part):
				browsed.append("%s “%s” %s" % [element[1], str(element[2]).left(24), _rect_words(box)])
				break
	if not browsed.is_empty():
		still.append("%d of its parts browsed: %s" % [browsed.size(), ", ".join(browsed.slice(0, 4))])
	var ok: bool = still.is_empty()
	_check("away %s: put away (%s, frame %d), gone the frame after%s" % [way, how, hidden_at[0],
		"" if ok else ": " + "; ".join(still)], ok)
	await _put_away(before)
	# A dialog brought up where it was: pointing at it finds the dialog.
	await _dialog_where_it_was(way)
	return "gone" if ok else "stayed"


func _dialog_where_it_was(way: String) -> void:
	var before: Dictionary = _shown()
	if not _shell.run("clear"):
		return
	await _frames(12)
	var dialog: Window = null
	for sub: Window in root.get_embedded_subwindows():
		if sub.visible and sub is ConfirmationDialog:
			dialog = sub
	if dialog == null:
		print("    (no Clear the baseplate? came up)")
		await _put_away(before)
		return
	var title: String = dialog.tr(dialog.title)
	var face: Rect2 = _pixels(Rect2(Vector2(dialog.position), Vector2(dialog.size)))
	var bar: float = dialog.get_theme_constant("title_height") * root.get_final_transform().get_scale().y
	var points: Array = [[face.get_center().x, face.get_center().y],
		[face.get_center().x, face.position.y - bar / 2.0]]
	var tree: Dictionary = await _ask({"do": "read", "points": points})
	var found: Array[String] = []
	var reached: int = 0
	for hit: Dictionary in tree.get("hits", []):
		var chain: Array = hit.get("chain", [])
		found.append(_said(chain))
		for node: Dictionary in chain:
			if str(node.get("role")) in WINDOWS and str(node.get("name")) == title:
				reached += 1
				break
	_check("away %s, then “%s” where it was: pointing at it finds the dialog, %d of %d points (%s)"
		% [way, title, reached, points.size(), " / ".join(found)], reached == points.size())
	await _put_away(before)


static func _within_any(node: Dictionary, parts: Array[Rect2]) -> bool:
	var at: Array = node.get("box", [0, 0, 0, 0])
	var box := Rect2(at[0], at[1], at[2], at[3])
	for part: Rect2 in parts:
		if _same_box(box, part):
			return true
	return false


## The largest control shown that was not before: the panel a way opened.
func _new_panel(before: Dictionary) -> Control:
	var best: Control = null
	for id: int in _shown():
		if before.has(id):
			continue
		var control: Control = instance_from_id(id) as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if best == null or control.size.x * control.size.y > best.size.x * best.size.y:
			best = control
	return best


## The outermost control of [param panel] the app shows and hides as one.
static func _ancestor_panel(panel: Control) -> Control:
	var at: Control = panel
	while at.get_parent() is Control and not (at.get_parent() is Container) and at.visible:
		at = at.get_parent()
	return at


# -- boxes ------------------------------------------------------------------


func _boxes() -> void:
	print("  boxes: each dialog says it is where it is drawn")
	# Every window of the main window made by now, dialogs and menus, up or
	# not: those the engine would say are elsewhere (the transforms of the
	# nodes they are under, as Godot 4.7.2 gives them) must each be placed
	# again in their own update (src/ui/placed_window.gd).
	var placing: Script = load(PLACING) as Script if ResourceLoader.exists(PLACING) else null
	var made: Array[Window] = []
	_gather_windows(root, made)
	var off: Array[String] = []
	var put_right: int = 0
	for dialog: Window in made:
		var said: Rect2 = _said_box(dialog)
		var drawn: Rect2 = _pixels(Rect2(Vector2(dialog.position), Vector2(dialog.size)))
		var by: Vector2 = said.position - drawn.position
		if by.length() <= NEAR:
			continue
		if placing != null and dialog.get_script() == placing:
			put_right += 1
		else:
			off.append("“%s” (%s under %s) by (%d, %d)" % [_spoken(dialog), dialog.get_class(),
				dialog.get_parent().name, int(by.x), int(by.y)])
	_check("boxes: of the %d windows made, %d the engine says are elsewhere are each placed again%s"
		% [made.size(), put_right + off.size(), "" if off.is_empty()
			else "; %d not: %s" % [off.size(), ", ".join(off.slice(0, 6)) + (" …" if off.size() > 6 else "")]],
		off.is_empty() and made.size() > 0)
	# A menu brought up, its box read over AT-SPI: found by browsing, where
	# pointing finds what is under it (the engine hit-tests a window drawn
	# over the app below what comes after it in the tree).
	await _menu_box()
	# And each brought up, read back over AT-SPI.
	var ways: Array[String] = ["about", "new", "import_ldraw", "save_as", "reference"]
	for name: String in NAMES.OPENERS + NAMES.WITH_A_SELECTION:
		if not ways.has(name):
			ways.append(name)
	var read: int = 0
	var near: int = 0
	for way: String in ways:
		var outcome: int = await _box_of(way)
		if outcome >= 0:
			read += 1
			near += outcome
	_check("boxes: every dialog brought up was read where it is drawn: %d of %d" % [near, read],
		read > 0 and near == read)


## The box the engine says [param dialog] has, in the window's pixels: the
## transforms AccessKit composes from the window's root down to it, each
## node's as Godot gives it (Control: its own transform; an embedded
## window: Window::get_accessibility_transform; any other node: none).
func _said_box(dialog: Window) -> Rect2:
	var chain: Array[Node] = []
	var at: Node = dialog.get_parent()
	while at != null and at != root:
		chain.push_front(at)
		at = at.get_parent()
	var composed: Transform2D = root.get_final_transform()
	for node: Node in chain:
		if node is Control:
			composed = composed * (node as Control).get_transform()
	var parent_own: Transform2D = _accessibility_transform(dialog.get_parent())
	var window_tr := Transform2D(0.0, Vector2(dialog.position))
	window_tr = window_tr.scaled_local(Vector2.ONE * dialog.content_scale_factor)
	var own: Transform2D = parent_own.affine_inverse() * window_tr
	var whole: Transform2D = composed * own
	var size: Vector2 = Vector2(dialog.size) / dialog.content_scale_factor
	return Rect2(whole * Vector2.ZERO, whole.basis_xform(size))


## Node::get_accessibility_transform as Godot 4.7.2 has it (scene/main/node.cpp,
## control.h, window.cpp).
func _accessibility_transform(node: Node) -> Transform2D:
	if node == null or node == root:
		return Transform2D()
	if node is Control:
		return (node as Control).get_transform()
	return _accessibility_transform(node.get_parent())


## Every dialog under [param node] that the main window draws.
func _gather_windows(node: Node, out: Array[Window]) -> void:
	for child: Node in node.get_children(true):
		if child is Window:
			# A window's own questions are placed by the window they are in:
			# the main window's are judged here.
			out.append(child as Window)
			continue
		if child is Node3D and child.get_child_count() > 64:
			continue
		_gather_windows(child, out)


## One dialog brought up and its box read over AT-SPI: 1 when where it is
## drawn, 0 when not, -1 when the way brings up no dialog.
func _box_of(way: String) -> int:
	var before: Dictionary = _shown()
	var builder: Builder = _main.get("_builder")
	if way == "new" or way in NAMES.WITH_A_SELECTION:
		_select_a_part()
		await _frames(4)
		if way == "new":
			builder.remove_selection()
			await _frames(4)
	if way == "reference":
		var reference: ReferenceImage = _main.get("_reference")
		reference.take(Image.load_from_file(
			ProjectSettings.globalize_path("res://tools/release/best_car.png")), "car")
	if not _shell.run(way):
		return -1
	var until: int = Time.get_ticks_msec() + 5000
	await _frames(12)
	while _shown().size() <= before.size() and Time.get_ticks_msec() < until:
		await process_frame
	await _frames(6)
	var over: Array[Window] = []
	for sub: Window in root.get_embedded_subwindows():
		if sub.visible and not sub.get_flag(Window.FLAG_POPUP) and sub.get_parent() != null \
				and not before.has(sub.get_instance_id()):
			over.append(sub)
	if over.is_empty():
		await _idle()
		await _put_away(before)
		return -1
	var points: Array = []
	for sub: Window in over:
		var face: Rect2 = _pixels(Rect2(Vector2(sub.position), Vector2(sub.size)))
		points.append([face.get_center().x, face.get_center().y])
	var tree: Dictionary = await _ask({"do": "read", "points": points})
	var all_near: bool = true
	var lines: Array[String] = []
	var boxes: Array = []
	for n: int in over.size():
		var sub: Window = over[n]
		var drawn: Rect2 = _pixels(Rect2(Vector2(sub.position), Vector2(sub.size)))
		var hits: Array = tree.get("hits", [])
		var chain: Array = (hits[n] as Dictionary).get("chain", []) if n < hits.size() else []
		var node: Dictionary = {}
		for element: Dictionary in chain:
			if str(element.get("role")) in WINDOWS and str(element.get("name")) == _spoken(sub):
				node = element
				break
		if node.is_empty():
			lines.append("“%s” not found where it is drawn (found: %s)" % [_spoken(sub), _said(chain)])
			all_near = false
			continue
		var at: Array = node.get("box", [0, 0, 0, 0])
		var said := Rect2(at[0], at[1], at[2], at[3])
		boxes.append([drawn, said])
		var near: bool = absf(said.position.x - drawn.position.x) <= NEAR \
			and absf(said.position.y - drawn.position.y) <= NEAR \
			and absf(said.size.x - drawn.size.x) <= NEAR and absf(said.size.y - drawn.size.y) <= NEAR
		all_near = all_near and near
		lines.append("“%s” (%s) drawn at %s, said at %s" % [_spoken(sub), sub.get_class(),
			_rect_words(drawn), _rect_words(said)])
	await _shot_boxes("box_%s" % way, boxes)
	_check("boxes %s: %s" % [way, "; ".join(lines)], all_near)
	await _idle()
	await _put_away(before)
	return 1 if all_near else 0


## The bar's first menu brought up and its box read by browsing: the
## element of its size, where it is said to be against where it is drawn.
func _menu_box() -> void:
	var bar: ModelBar = _main.get("_bar")
	var button: MenuButton = null
	for child: Node in bar.menus.get_children():
		if child is MenuButton and (child as MenuButton).is_visible_in_tree():
			button = child
			break
	if button == null:
		_check("boxes: a menu of the bar is there to bring up", false)
		return
	button.show_popup()
	await _frames(12)
	var popup: PopupMenu = button.get_popup()
	var drawn: Rect2 = _pixels(Rect2(Vector2(popup.position), Vector2(popup.size)))
	var tree: Dictionary = await _ask({"do": "browse"})
	var best: Array = []
	for element: Array in tree.get("reached", []):
		var at: Array = element[3]
		var box := Rect2(at[0], at[1], at[2], at[3])
		if absf(box.size.x - drawn.size.x) <= NEAR + 1.0 and absf(box.size.y - drawn.size.y) <= NEAR + 1.0:
			if best.is_empty() or box.position.distance_to(drawn.position) \
					< Rect2(best[3][0], best[3][1], best[3][2], best[3][3]).position.distance_to(drawn.position):
				best = element
	var said := Rect2()
	if not best.is_empty():
		said = Rect2(best[3][0], best[3][1], best[3][2], best[3][3])
		await _shot_boxes("box_menu", [[drawn, said]])
	var near: bool = not best.is_empty() and said.position.distance_to(drawn.position) <= NEAR
	_check("boxes: the %s menu, drawn at %s, is said at %s" % [button.text, _rect_words(drawn),
		_rect_words(said) if not best.is_empty() else "nowhere (no element of its size reached)"], near)
	popup.hide()
	await _frames(4)


static func _rect_words(rect: Rect2) -> String:
	return "(%d, %d) %d x %d" % [roundi(rect.position.x), roundi(rect.position.y),
		roundi(rect.size.x), roundi(rect.size.y)]


# -- dump -------------------------------------------------------------------


func _write_dump(label: String) -> void:
	var nodes: Array = []
	_dump_node(root, 0, nodes)
	_write_json("godot_%s.json" % label, {"nodes": nodes,
		"to_pixels": [root.get_final_transform().x.x, root.get_final_transform().origin.x,
			root.get_final_transform().origin.y]})
	var tree: Dictionary = await _ask({"do": "browse"})
	_write_json("browse_%s_raw.json" % label, tree)


func _dump_node(node: Node, depth: int, out: Array) -> void:
	var entry: Dictionary = {"d": depth, "class": node.get_class(), "name": str(node.name),
		"children": node.get_child_count(true)}
	if node.get_script() != null:
		var script: Script = node.get_script()
		entry["script"] = script.get_global_name() if not script.get_global_name().is_empty() \
			else script.resource_path.get_file()
	if node is CanvasItem:
		entry["visible"] = (node as CanvasItem).visible
		entry["in_tree"] = (node as CanvasItem).is_visible_in_tree()
	if node is Control:
		var control: Control = node
		entry["a11y"] = control.accessibility_name
		entry["box"] = _box_list(_pixels(control.get_global_rect()))
		entry["local"] = [control.position.x, control.position.y]
		if control is Container:
			entry["region"] = (control as Container).accessibility_region
		entry["clip"] = control.clip_contents
	if node is Window:
		entry["visible"] = (node as Window).visible
		entry["title"] = (node as Window).title
	out.append(entry)
	if node is Node3D and node.get_child_count() > 64:
		entry["skipped"] = true
		return
	for child: Node in node.get_children(true):
		_dump_node(child, depth + 1, out)


static func _box_list(rect: Rect2) -> Array:
	return [snappedf(rect.position.x, 0.1), snappedf(rect.position.y, 0.1),
		snappedf(rect.size.x, 0.1), snappedf(rect.size.y, 0.1)]


func _write_json(file_name: String, data: Variant) -> void:
	if _dump.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_dump)
	var file: FileAccess = FileAccess.open(_dump.path_join(file_name), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, " "))
		file.close()


# -- shared -----------------------------------------------------------------


static func _spoken(window: Window) -> String:
	return window.accessibility_name if not window.accessibility_name.is_empty() \
		else window.tr(window.title)


static func _said(chain: Array) -> String:
	var words: PackedStringArray = []
	for node: Dictionary in chain:
		words.append("%s “%s”%s" % [node.get("role"), str(node.get("name")).left(40),
			" MODAL" if bool(node.get("modal")) else ""])
	return " < ".join(words) if not words.is_empty() else "nothing"


## One ask of the reader, and its answer, the app running meanwhile.
func _ask(what: Dictionary) -> Dictionary:
	var answer: String = _send(what)
	var until: int = Time.get_ticks_msec() + READ_MS
	while not FileAccess.file_exists(answer) and Time.get_ticks_msec() < until:
		await process_frame
	return _answer(answer)


## One ask of the reader with the app held where it is: no frame drawn, no
## tree sent, until the answer is in. What AccessKit had at this frame.
func _ask_now(what: Dictionary) -> Dictionary:
	var answer: String = _send(what)
	var until: int = Time.get_ticks_msec() + READ_MS
	while not FileAccess.file_exists(answer) and Time.get_ticks_msec() < until:
		OS.delay_msec(20)
	return _answer(answer)


func _send(what: Dictionary) -> String:
	_asked += 1
	var path: String = _dir.path_join("ask_%d.json" % _asked)
	var file: FileAccess = FileAccess.open(path + ".part", FileAccess.WRITE)
	file.store_string(JSON.stringify(what))
	file.close()
	DirAccess.rename_absolute(path + ".part", path)
	return _dir.path_join("tree_%d.json" % _asked)


func _answer(answer: String) -> Dictionary:
	if not FileAccess.file_exists(answer):
		return {"error": "the reader gave no answer in %d s" % (READ_MS / 1000)}
	var read: Variant = JSON.parse_string(FileAccess.get_file_as_string(answer))
	if not read is Dictionary:
		return {"error": "the reader's answer did not read"}
	var tree: Dictionary = read
	var asked: Dictionary = tree.get("asked", {})
	if asked.has("away"):
		print("    %s" % asked["away"])
	return tree


## Put away: Escape first, then anything still up that was not before
## (a11y_modal_probe).
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


func _shown() -> Dictionary:
	var out: Dictionary = {}
	_gather_shown(root, out, 0)
	return out


func _gather_shown(node: Node, out: Dictionary, depth: int) -> void:
	if node is Window and node != root:
		if (node as Window).visible:
			out[node.get_instance_id()] = true
		return
	if depth > 6:
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is CanvasItem:
		out[node.get_instance_id()] = true
	for child: Node in node.get_children(true):
		_gather_shown(child, out, depth + 1)


static func _all_under(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in node.get_children(true):
		out.append(child)
		out.append_array(_all_under(child))
	return out


func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("a11ytree")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


## Signed in with a password grant on an account the admin key made
## (mosaic_window_probe, a11y_modal_probe).
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


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)


func _idle() -> void:
	var hidden: Node = _main.get("_hidden_colours")
	for _n: int in 3600:
		if not Working.is_busy() and (hidden == null or not bool(hidden.get("_working"))):
			return
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_shots)
	await _frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join("a11y_tree_%s.png" % name))


## A picture with each dialog's box drawn over it: where it is drawn in
## green, where it is said to be in red.
func _shot_boxes(name: String, boxes: Array) -> void:
	if _shots.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_shots)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	# The texture is the viewport's, in its own pixels; the boxes are the
	# window's.
	var scale: Vector2 = Vector2(image.get_size()) / Vector2(DisplayServer.window_get_size())
	for pair: Array in boxes:
		_outline(image, Rect2((pair[0] as Rect2).position * scale, (pair[0] as Rect2).size * scale),
			Color(0.2, 1.0, 0.3))
		_outline(image, Rect2((pair[1] as Rect2).position * scale, (pair[1] as Rect2).size * scale),
			Color(1.0, 0.2, 0.2))
	image.save_png(_shots.path_join("a11y_tree_%s.png" % name))


static func _outline(image: Image, rect: Rect2, colour: Color) -> void:
	var r := Rect2i(rect.position.round(), rect.size.round())
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	for edge: Rect2i in [Rect2i(r.position, Vector2i(r.size.x, 2)),
			Rect2i(Vector2i(r.position.x, r.end.y - 2), Vector2i(r.size.x, 2)),
			Rect2i(r.position, Vector2i(2, r.size.y)),
			Rect2i(Vector2i(r.end.x - 2, r.position.y), Vector2i(2, r.size.y))]:
		var inside: Rect2i = edge.intersection(bounds)
		if inside.has_area():
			image.fill_rect(inside, colour)


func _finish() -> void:
	if not _email.is_empty():
		# Every throwaway of this probe's: one a run cut short left too.
		var gone: int = await SignInHelper.delete_accounts("delivered+bwa11ytree", root)
		print("    (removed %d throwaway account(s))" % gone)
	print("a11y_tree: %s" % ("all checks passed" if _failures == 0 else "%d checks failed" % _failures))
	quit(1 if _failures > 0 else 0)
