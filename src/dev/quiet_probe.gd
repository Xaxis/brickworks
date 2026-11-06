## APP_UX4 unit 9, quiet: what stood in a person's way goes, as a person
## meets it, every act a click or a key sent to the window.
##
##   godot --path . --resolution 1280x720 --script src/dev/quiet_probe.gd
##   PROBE_SIZE=1400x900 tools/probe.sh quiet_probe
##
## The bar (docs/APP_UX4.md, the units, row 9):
## 1. The first build's offer goes once a person has put down 3 parts by
##    hand, or opened a model of theirs or the car, and is still offered on a
##    first empty baseplate. A first visit offers it by itself over the car;
##    a part put down, and a second, leave it; the third takes it away. Help,
##    Take the tour offers it again (the walk's way to it), and File, Open of
##    a model saved here takes it away; so does the car opened from File,
##    Open's examples; File, New keeps it over the empty baseplate. And a
##    first visit that starts on an empty baseplate (a new window) is offered
##    it by itself: a run of its own, in a window of its own, on a data
##    folder of its own.
## 2. The render queue closes with Escape, and Settings, Cut away's strip and
##    every dialog opened after it are drawn over it. Drawn over is read off
##    the window's own picture: where what opened lies over the queue's
##    corner, the picture is the same with the queue up as with it hidden.
##    Escape with a part selected puts the queue away first, as it does the
##    other panels over the model, and the selection with the next press.
##    Cut away's strip and the queue's own buttons are both in sight, and
##    "every dialog" is every dialog the menus open that the walk opened, and
##    the rest that open in the window (not a system file picker).
## 3. At 1280 x 720 with the assistant open (and, as the walk had it, a
##    tool's panel beside the model: Stress), View › Split is offered and
##    shows two views of 320 points or more; the assistant folds to its tab
##    while the split is on, as the menu's tooltip says, and opens again
##    when it is off.
##
## The data folder is the run's own (probe.sh gives one): a first visit is
## one with nothing kept. Pictures go to shots/quiet/<width>x<height>/.
extends SceneTree

const SHOTS := "res://shots/quiet/"
## The share of a dialog's pixels over the queue that may differ with the
## queue up and hidden: a caret's blink, a hover's tint. Drawn under the
## queue, a dark dialog under the dark queue differs where either has words,
## 15% and more; the cut strip over the model, 92% (pre261).
const MOST_CHANGED := 0.02
## How far apart a pixel's channels may be and still be the same pixel: a
## panel at 90% over the queue lets a tenth of it through, and the parts
## list and the keys sheet showed the queue's words faintly so, drawn over
## it as they were (1% and 1.4% of pixels past 0.08, pre261).
const SAME := 0.15
## The views Split shows, each at least, in points (the bar's).
const LEAST_POINTS := 320.0
## Every dialog the walk opened (docs/app_ux4/appux_walk.gd, DIALOGS), and
## the rest of the menus' that open in the window. Not those that open the
## system's file picker straight away (the imports, a picture to trace or
## print), which would open on a desktop, not in this window; nor Build,
## Instructions…, which on the desktop opens nothing in the window and
## writes the booklet as a file (APP_UX4), and after which this run's Godot
## aborts at its quit ("corrupted size vs. prev_size", the walk's exit 134
## since appux2: the booklet drawn, even waited out, then quit, headless).
const DIALOGS: Array[String] = ["timeline", "share", "together", "settings",
	"keys", "export_3d", "versions", "collection", "minifig", "part_maker", "flex", "stress",
	"parts_list", "panel_outliner", "stability", "brickify", "mosaic", "connector", "tour",
	"library", "compare", "pattern", "measure", "render", "pose", "palette", "feedback",
	"account", "clear", "comments", "collection_need", "collection_build", "select_find",
	"step_to", "simulate", "hidden_colours"]

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
var _bin: PartsBin
var _first: FirstBuild
var _out: String = ""
## Where the pointer is, in the window's pixels, for each move's relative.
var _pointer: Vector2 = Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	var first_empty: bool = OS.get_cmdline_user_args().has("--first-empty")
	var own_folder: bool = _own_data_folder()
	ShellPrefs.kept_by_a_check = own_folder
	# A person in front of the window, as a first visit has one.
	FirstBuild.offered_for_probe = true
	if DisplayServer.get_name() == "headless":
		print("  quiet probe: needs a window")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var size: Vector2i = DisplayServer.window_get_size()
	_out = "%s%dx%d/" % [SHOTS, size.x, size.y]
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_world = _main.get("_world")
		if _world != null and _main.get("_shell") != null \
				and (first_empty or _world.brick_count() > 1):
			break
	if _world == null or _main.get("_shell") == null:
		print("  quiet probe: SKIPPED — the window did not come up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_store = _main.get("_store")
	_bin = _main.get("_bin")
	_first = _shell.first_build
	var library: PartLibrary = _main.get("_library")
	for _n: int in 600:
		if library.search_ready():
			break
		await process_frame
	if first_empty:
		await _offered_on_empty()
	else:
		print("  a %d x %d window, %s units across" % [size.x, size.y,
			root.get_visible_rect().size.x])
		if not own_folder:
			_check("a data folder of this run's own, for a first visit (run by tools/probe.sh)", false)
		await _offer_by_hand()
		await _offer_asked_for()
		await _first_empty_baseplate(own_folder)
		await _split_with_the_assistant()
		await _queue_escape()
		await _queue_under_settings_and_cut()
		# Last: it leaves panels open behind it.
		await _queue_under_every_dialog()
	print("")
	if _failures == 0:
		print("quiet probe: all checks passed")
	else:
		print("quiet probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


# -- 1. the first build's offer ------------------------------------------------------

## A first visit: offered by itself over the car; three parts put down by
## hand, and it goes.
func _offer_by_hand() -> void:
	print("\n  1. the first build's offer, on a first visit")
	for _n: int in 1200:
		if _first.step_name() == "offer":
			break
		await process_frame
	await _frames(10)
	var cars: int = _parts()
	_check("a first visit is offered it by itself, over the car's %d parts (%s)"
		% [cars, _first.step_name()], _first.step_name() == "offer"
		and bool(_first.get("_by_itself")) and cars > 0)
	await _shot("1_offered")
	var box: AABB = _main.call("_built_bounds")
	var spots: Array[Vector3] = []
	for n: int in 3:
		spots.append(Vector3(box.end.x + 60.0, 0.0, box.get_center().z + (n - 1) * 60.0))
	for n: int in 3:
		if not (_main.get("_verbs") as EditVerbs).shows_ghost():
			await _click(_any_tile())
		await _click(_camera.unproject_position(spots[n]))
		var still: bool = _first.step_name() == "offer"
		if n < 2:
			_check("part %d put down by hand (%d parts): still offered (%s)"
				% [n + 1, _parts() - cars, _first.step_name()], _parts() == cars + n + 1 and still)
		else:
			_check("part 3 put down by hand (%d parts): the offer is gone (%s)"
				% [_parts() - cars, _first.step_name()], _parts() == cars + 3 and not still
				and not _first.is_visible_in_tree())
	_check("...kept as offered, so it is not offered again (%s)" % ShellPrefs.value("first_build"),
		ShellPrefs.value("first_build") == "offered")
	await _key(KEY_ESCAPE)
	await _shot("1_gone_after_three")


## Help, Take the tour offers it again (the walk's way to it): a model of the
## person's opened, or the car, takes it away; File, New keeps it.
func _offer_asked_for() -> void:
	print("\n  1. the offer from Help, then a model opened")
	# Still up (it did not go), it is put away first: Help's is the one the
	# walk found over the model.
	if _first.is_running():
		await _click(_offer_button("first_build_skip"))
	_check("this model saved here, as a model of the person's",
		_store.save_as("Quiet wall"))
	await _frames(10)
	await _from_menu("Help", "tour")
	_check("Help, Take the tour offers it (%s)" % _first.step_name(), _first.step_name() == "offer")
	await _open_listed("Quiet wall")
	_check("File, Open of a model saved here (%s, %d parts): the offer is gone (%s)"
		% [_store.title, _parts(), _first.step_name()],
		_store.title == "Quiet wall" and _parts() > 0 and not _first.is_running())
	await _from_menu("Help", "tour")
	_check("Help offers it again (%s)" % _first.step_name(), _first.step_name() == "offer")
	await _open_listed("car")
	_check("the car opened from File, Open's examples (%s, %d parts): the offer is gone (%s)"
		% [_store.title, _parts(), _first.step_name()], _parts() > 0 and not _first.is_running())
	await _from_menu("Help", "tour")
	await _from_menu("File", "new")
	await _settle()
	_check("File, New, an empty baseplate (%d parts): still offered (%s)"
		% [_parts(), _first.step_name()], _parts() == 0 and _first.step_name() == "offer")
	await _shot("1_offered_on_new")
	await _click(_offer_button("first_build_skip"))
	_check("...and Skip ends it", not _first.is_running())


## A first visit that starts on an empty baseplate (a new window): its own
## run, in a window of its own, on a data folder of its own.
func _first_empty_baseplate(own_folder: bool) -> void:
	print("\n  1. a first visit on an empty baseplate, in a run of its own")
	if not own_folder:
		_check("a data folder of this run's own to make another in", false)
		return
	var data: String = OS.get_environment("XDG_DATA_HOME")
	var fresh: String = data.path_join("first-empty")
	DirAccess.make_dir_recursive_absolute(fresh)
	var size: Vector2i = DisplayServer.window_get_size()
	OS.set_environment("XDG_DATA_HOME", fresh)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--path",
		ProjectSettings.globalize_path("res://"), "--resolution", "%dx%d" % [size.x, size.y],
		"--script", "res://src/dev/quiet_probe.gd", "--", "--first-empty",
		TabSession.NEW_WINDOW], output, true)
	OS.set_environment("XDG_DATA_HOME", data)
	for line: String in "\n".join(output).split("\n"):
		if line.begins_with("  ok") or line.begins_with("  FAIL"):
			print("  " + line)
	_check("that run passed (exit %d)" % code, code == 0)


func _offered_on_empty() -> void:
	var until: int = Time.get_ticks_msec() + FirstBuild.LOOK_WAIT_MS + 6000
	while Time.get_ticks_msec() < until and not bool(_first.get("_decided")):
		await process_frame
	await _frames(30)
	_check("a first visit on an empty baseplate (%d parts, \"%s\") is offered it by itself (%s)"
		% [_parts(), _store.title, _first.step_name()], _parts() == 0
		and _first.step_name() == "offer" and bool(_first.get("_by_itself")))
	await _shot("1_offered_on_empty")


# -- 2. the render queue gives way -------------------------------------------------

## The queue's panel: by its group, or where it was before it had one (the
## HUD), for a run on the code before.
func _queue() -> Control:
	var queue: Control = root.get_tree().get_first_node_in_group("render_queue") as Control
	if queue == null:
		queue = _main.get_node_or_null("HUD/RenderQueue") as Control
	return queue


func _queue_open() -> bool:
	var queue: Control = _queue()
	return queue != null and queue.is_visible_in_tree()


## Opened from File as a person opens it: the menu, then its row.
func _open_queue() -> void:
	if not _queue_open():
		await _from_menu("File", "render_queue")
		await _frames(20)


func _queue_escape() -> void:
	print("\n  2. the render queue")
	await _open_listed("car")
	await _settle()
	# As the walk had it: Settings seen before the queue is first opened, so
	# the queue is made after it. Over Settings' foot at 1400 x 900 then.
	_shell.run("settings")
	await _frames(40)
	await _key(KEY_ESCAPE)
	var settings: Control = _main.get("_controls_made")
	_check("Settings seen and put away before the queue is opened",
		settings != null and not settings.is_visible_in_tree())
	await _open_queue()
	_check("File, Render queue… opens its panel", _queue_open())
	await _shot("2_queue")
	await _key(KEY_ESCAPE)
	_check("Escape closes it", not _queue_open())
	# With a part selected: the panel goes first, as the other panels over
	# the model do, and the selection with the next press. The part clicked
	# is the highest, its top in sight.
	await _open_queue()
	await _click(_camera.unproject_position(_top_of_model()))
	var selected: int = _builder.selection.size()
	await _key(KEY_ESCAPE)
	_check("with %d part selected, Escape closes the queue first (selection %d)"
		% [selected, _builder.selection.size()], selected > 0 and not _queue_open()
		and _builder.selection.size() == selected)
	await _key(KEY_ESCAPE)
	_check("...and the next press the selection", _builder.selection.is_empty())


func _queue_under_settings_and_cut() -> void:
	await _open_queue()
	_shell.run("settings")
	await _frames(40)
	var settings: Control = _main.get("_controls_made")
	_check("Settings opened after it", settings != null and settings.is_visible_in_tree())
	if settings != null:
		var covered: Array = await _covered([settings.get_global_rect()])
		_check("Settings is drawn over the queue: %s" % covered[1], float(covered[0]) <= MOST_CHANGED)
	await _shot("2_queue_and_settings")
	await _key(KEY_ESCAPE)
	await _open_queue()
	_shell.run("cut")
	await _settle()
	var strip: Control = _shell.see_inside.bar
	_check("Cut away's strip is up", strip.is_visible_in_tree())
	var covered: Array = await _covered([strip.get_global_rect()])
	_check("Cut away's strip is drawn over the queue: %s" % covered[1],
		float(covered[0]) <= MOST_CHANGED)
	var hidden: Array[String] = []
	var queue: RenderQueue = _queue() as RenderQueue
	for name: String in queue.controls_by_name():
		var button: Control = queue.controls_by_name()[name]
		if button.get_global_rect().intersects(strip.get_global_rect()) \
				or not root.get_visible_rect().encloses(button.get_global_rect()):
			hidden.append(name)
	_check("...and the queue's own buttons in sight beside it (%s)"
		% ("all" if hidden.is_empty() else "not " + ", ".join(hidden)), hidden.is_empty())
	await _shot("2_queue_and_cut")
	_shell.run("cut")
	await _frames(10)
	await _key(KEY_ESCAPE)


## Each dialog opened with the queue up: what it puts in the window where
## the queue is, drawn over it.
func _queue_under_every_dialog() -> void:
	print("\n  2. every dialog opened after the queue")
	var opened: int = 0
	var over: Array[String] = []
	var under: Array[String] = []
	var greyed: Array[String] = []
	# Those that took room from the model's: the queue moved or narrowed to
	# stay in what was left, a picture of each.
	var gave_way: Array[String] = []
	var one: BrickWorld.Brick = _model_bricks()[0]
	for name: String in DIALOGS:
		if _shell.command(name) == null:
			continue
		await _open_queue()
		# Some ask for a part selected.
		if _builder.selection.is_empty():
			_builder.selection[one.id] = true
			_builder.selection_changed.emit(1)
			await _frames(4)
		if not _shell.can(name):
			greyed.append(name)
			continue
		var before: Dictionary = _shown()
		var was: Rect2 = _queue().get_global_rect()
		_shell.run(name)
		await _frames(60)
		var queue: Control = _queue()
		if _queue_open() and not queue.get_global_rect().is_equal_approx(was):
			gave_way.append("%s (%.0f to %.0f wide)" % [name, was.size.x,
				queue.get_global_rect().size.x])
			await _shot("2_gave_way_%s" % name)
		var rects: Array[Rect2] = []
		var fresh: Array[Node] = _newly_shown(before)
		for node: Node in fresh:
			for panel: Node in _panels_in(node):
				var rect: Rect2 = _rect_of(panel)
				if rect.intersects(queue.get_global_rect()) and _queue_open():
					rects.append(rect)
		opened += 1 if not fresh.is_empty() else 0
		if not rects.is_empty():
			var covered: Array = await _covered(rects)
			if float(covered[0]) <= MOST_CHANGED:
				over.append(name)
			else:
				under.append("%s (%s)" % [name, covered[1]])
				await _shot("2_under_%s" % name)
		await _close(fresh)
	print("    %d opened something; %d of them lay over the queue's corner; greyed here: %s"
		% [opened, over.size() + under.size(), ", ".join(greyed)])
	_check("every one that lay over the queue drawn over it (%d: %s)" % [over.size(),
		", ".join(over)], under.is_empty() and not over.is_empty())
	if not under.is_empty():
		print("    drawn under the queue: %s" % "; ".join(under))
	print("    the queue gave way to: %s" % ("; ".join(gave_way) if not gave_way.is_empty()
		else "none"))


## Every Control in the window shown now, and every window: instance id ->
## node.
func _shown() -> Dictionary:
	var out: Dictionary = {}
	for node: Node in root.find_children("*", "", true, false):
		if node is Window and (node as Window).visible:
			out[node.get_instance_id()] = node
		elif node is Control and (node as Control).is_visible_in_tree():
			out[node.get_instance_id()] = node
	return out


## What a command put up: each control or window shown now and not before,
## whose parent was shown before (the root of what opened).
func _newly_shown(before: Dictionary) -> Array[Node]:
	var now: Dictionary = _shown()
	var queue: Control = _queue()
	var out: Array[Node] = []
	for id: int in now:
		if before.has(id):
			continue
		var node: Node = now[id]
		if queue != null and (node == queue or queue.is_ancestor_of(node)):
			continue
		var parent: Node = node.get_parent()
		if parent != null and now.has(parent.get_instance_id()) \
				and not before.has(parent.get_instance_id()):
			continue
		out.append(node)
	return out


## The panels in what opened: a window, or a control that takes the clicks
## on it or draws a panel behind its words; the first of these down each
## branch. An overlay that draws a frame or a line and takes no click is
## not a panel, and the queue shows through it as the model does.
func _panels_in(node: Node) -> Array[Node]:
	if node is Window:
		return [node]
	var control: Control = node as Control
	if control == null or not control.is_visible_in_tree():
		return []
	if control.mouse_filter == Control.MOUSE_FILTER_STOP or control is PanelContainer \
			or control is Panel:
		return [node]
	var out: Array[Node] = []
	for child: Node in node.get_children():
		out.append_array(_panels_in(child))
	return out


## Where a control or an embedded window lies, in the window's units: a
## window with its title.
func _rect_of(node: Node) -> Rect2:
	if node is Window:
		var window := node as Window
		var title: float = float(window.get_theme_constant("title_height", "Window")) \
			if not window.borderless else 0.0
		return Rect2(Vector2(window.position) - Vector2(0, title),
			Vector2(window.size) + Vector2(0, title))
	if node is Control:
		return (node as Control).get_global_rect()
	return Rect2()


## Put away what a command opened: Escape, as a person would, then what is
## still up hidden. The queue is opened again for the next.
func _close(opened: Array[Node]) -> void:
	await _key(KEY_ESCAPE)
	for node: Node in opened:
		if not is_instance_valid(node):
			continue
		if node is Window and (node as Window).visible:
			(node as Window).hide()
		elif node is CanvasItem and (node as CanvasItem).visible:
			(node as CanvasItem).hide()
	await _frames(10)


## How much of [param rects] (window units) the queue changes: the share of
## their pixels that differ between the window with the queue up and with
## it hidden, where they lie over it, and those words. [share, words].
func _covered(rects: Array) -> Array:
	var queue: Control = _queue()
	if queue == null or not queue.is_visible_in_tree():
		return [1.0, "the queue is not up"]
	var shown: Image = await _picture()
	queue.visible = false
	var hidden: Image = await _picture()
	queue.visible = true
	await _frames(4)
	var scale: Vector2 = Vector2(shown.get_size()) / root.get_visible_rect().size
	var looked: int = 0
	var changed: int = 0
	for rect: Rect2 in rects:
		var both: Rect2 = rect.intersection(queue.get_global_rect())
		if not both.has_area():
			continue
		var from: Vector2i = Vector2i((both.position * scale).floor())
		var to: Vector2i = Vector2i((both.end * scale).ceil()).min(shown.get_size())
		for y: int in range(maxi(from.y, 0), to.y, 2):
			for x: int in range(maxi(from.x, 0), to.x, 2):
				looked += 1
				var a: Color = shown.get_pixel(x, y)
				var b: Color = hidden.get_pixel(x, y)
				if maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) > SAME:
					changed += 1
	if looked == 0:
		return [0.0, "it does not lie over the queue"]
	var share: float = float(changed) / looked
	return [share, "%d of %d pixels over the queue's corner changed by it (%.1f%%)"
		% [changed, looked, share * 100.0]]


func _picture() -> Image:
	await _frames(6)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


# -- 3. Split at a laptop's size with the assistant open -----------------------------

func _split_with_the_assistant() -> void:
	print("\n  3. View, Split with the assistant open")
	# The car: Stress shows nothing on an empty baseplate.
	await _open_listed("car")
	await _settle()
	var split: SplitView = _main.get("_split")
	var chat: SideDock = _main.get("_chat_dock")
	# Settings' switch, and its column open as its tab opens it.
	_main.call("set_assistant", true)
	await _settle()
	if not chat.is_open():
		await _click(chat.rail().get_global_rect().get_center())
		await _settle()
	_check("the assistant is open down the right (%.0f units)" % chat.size.x, chat.is_open())
	# As the walk had it: a tool's panel beside the model too.
	await _stress(true)
	await _split_on_and_off(split, chat, "with Stress's panel beside the model")
	await _stress(false)
	await _split_on_and_off(split, chat, "alone")
	var popup: PopupMenu = _shell.menu("View").get_popup()
	var tip: String = popup.get_item_tooltip(popup.get_item_index(_shell.menu_id("split_view")))
	_check("View › Split's tooltip says the one choice: \"%s\"" % tip,
		tip.contains("the right-hand column folds to its tab"))


## View, Stress on or off, its panel with it.
func _stress(on: bool) -> void:
	if _shell.stress.panel.is_visible_in_tree() != on:
		_shell.run("stress")
		await _settle()
	var column: Control = _main.get("_tool_column")
	_check("Stress %s, the tools' column %s" % ["on" if on else "off",
		"shown" if column.visible else "away"], _shell.stress.panel.is_visible_in_tree() == on
		and column.visible == on)


func _split_on_and_off(split: SplitView, chat: SideDock, how: String) -> void:
	var across: float = root.get_visible_rect().size.x
	var points: float = Room.across() / maxf(across, 1.0)
	print("    %s: the model's column %.0f units, two views need %.0f" % [how, split.room(),
		split.least()])
	_check("View › Split offered %s (%s)" % [how, _shell.why_not("split_view")],
		_shell.can("split_view"))
	await _key(KEY_F8)
	await _settle()
	var main_view: float = split.beside_of.size.x * points
	var second: float = split.size.x * points
	_check("F8 shows two views of %.0f and %.0f points, each %.0f or more" % [main_view, second,
		LEAST_POINTS], split.is_showing() and main_view >= LEAST_POINTS
		and second >= LEAST_POINTS)
	await _shot("3_split_%s" % how.split(" ")[0].replace("'", ""))
	var folded: bool = not chat.is_open()
	print("    the assistant %s while it is on" % ("folded to its tab" if folded else "stays open"))
	_check("...the assistant's tab still there to open it (%s)" % chat.rail().is_visible_in_tree(),
		chat.visible and chat.rail().is_visible_in_tree())
	await _key(KEY_F8)
	await _settle()
	_check("F8 again: one view, the assistant open again as it was",
		not split.is_showing() and chat.is_open())


# -- the model, the menus, and acts -----------------------------------------------------

func _parts() -> int:
	return _model_bricks().size()


## The middle of the top of the model's highest part.
func _top_of_model() -> Vector3:
	var library: PartLibrary = _main.get("_library")
	var best: AABB = AABB()
	var high: float = -INF
	for brick: BrickWorld.Brick in _model_bricks():
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var box: AABB = brick.transform * mesh.bounds
		if box.end.y > high:
			high = box.end.y
			best = box
	return Vector3(best.get_center().x, best.end.y, best.get_center().z)


func _model_bricks() -> Array:
	return _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(brick.id))


## File, Open… and the row naming [param named]: a model saved here, or an
## example by its file's name.
func _open_listed(named: String) -> void:
	await _from_menu("File", "open")
	var saves: PopupMenu = (_main.get("_bar") as ModelBar).get("_saves")
	var entries: Array = (_main.get("_bar") as ModelBar).get("_entries")
	var id: int = -1
	for n: int in entries.size():
		var entry: ModelStore.Entry = entries[n]
		if entry.name == named or entry.path.get_file().get_basename() == named:
			id = n
			break
	_check("File, Open lists %s" % named, saves.visible and id >= 0)
	if id < 0:
		saves.hide()
		return
	saves.id_pressed.emit(id)
	saves.hide()
	for _n: int in 600:
		await process_frame
		if not _store.laying and _parts() > 0:
			break
	await _settle()


func _offer_button(name: String) -> Vector2:
	var found: Dictionary = _first.controls_by_name()
	if not found.has(name):
		_check("%s is shown" % name, false)
		return Vector2.ZERO
	return (found[name] as Control).get_global_rect().get_center()


## A tile of the bin's in sight: a 2 x 4 brick if there is one.
func _any_tile() -> Vector2:
	var scroll: Control = _bin.controls_by_name()["parts list"]
	var first: Button = null
	for tile: Node in _bin.find_children("*", "Button", true, false):
		var button := tile as Button
		if str(button.get_meta("part", "")).is_empty() or not button.is_visible_in_tree() \
				or not scroll.get_global_rect().encloses(button.get_global_rect()):
			continue
		if str(button.get_meta("part")) == "3001":
			return button.get_global_rect().get_center()
		if first == null:
			first = button
	_check("the bin shows a part", first != null)
	return first.get_global_rect().get_center() if first != null else Vector2.ZERO


func _as_event(at: Vector2) -> Vector2:
	return at * (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size)


func _move(at: Vector2, mask: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	motion.relative = motion.position - _pointer
	_pointer = motion.position
	motion.button_mask = mask
	Input.parse_input_event(motion)
	await _frames(3)


func _press(button: MouseButton, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_press(MOUSE_BUTTON_LEFT, at, true)
	await _frames(2)
	_press(MOUSE_BUTTON_LEFT, at, false)
	await _frames(8)


func _key(code: Key) -> void:
	var down: InputEventKey = Keymap.press_of(code)
	Input.parse_input_event(down)
	await process_frame
	var up: InputEventKey = down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(10)


## A command from a menu on the bar, opened with a click and its row chosen.
func _from_menu(title: String, command: String) -> void:
	var menu: MenuButton = _shell.menu(title)
	await _click(menu.get_global_rect().get_center())
	var popup: PopupMenu = menu.get_popup()
	var at: int = _shell.menu_id(command)
	if not (popup.visible and popup.get_item_index(at) >= 0):
		_check("%s opens, with %s in it" % [title, command], false)
	popup.id_pressed.emit(at)
	popup.hide()
	await _frames(10)


func _settle() -> void:
	await create_timer(0.6).timeout
	await _frames(6)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out + name + ".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s%s.png" % [_out.trim_prefix("res://"), name])
