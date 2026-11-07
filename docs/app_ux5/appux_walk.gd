## appux371's walk, rerun by appux2, appux3, appux4 and then appux5 on
## pre261 (docs/APP_UX2.md to APP_UX5.md): a person's first hour, timed,
## counted and pictured. Research only, not in the suite. Kept here under a
## .gdignore; copy it to src/dev/ to run it through tools/probe.sh
## (PROBE_SIZE=1280x720 for a laptop's window). SECTION is counts, menus,
## search, wall, turns, dialogs, round2, round3 or round4. Pictures go to
## shots/appux/<width>x<height>/.
##
## appux5 added `round4` (the status bar and Properties with the car open
## and nothing selected, the render queue put away by Escape and Settings
## over it, What's This on a toolbar button, the place of a part in hand,
## Cut away by a box, Pattern's In a grid, the parts list's Pick a Brick
## button, Into this model, and whether track ends are known).
##
## appux4 added `round3` (Move to step… by its key and a typed number, the
## step keys, Render's Building and the render queue, whether Best is path
## traced, the booklet page's extras, Settings' language, Like this by two
## clicks, Cut away, the first build's offer after building by hand, and
## the keys of the commands round three's "Next" list named).
##
## appux3 added `round2` (a colour key on three parts, Split and Merge by
## their keys, View › Split, the reference picture, the new panels) and the
## first eight tiles "1x4 brick" lists.
##
## appux2 added `counts` (tiles in sight and named, commands with a key, the
## keys sheet's rows in sight, Render from the palette) and rewrote the turn
## in a wall: since A3, R there puts the part in hand, turned.
##
##   godot --path . --resolution 1400x900 --script src/dev/appux_walk.gd -- [only=SECTION]
extends SceneTree

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Shell
var _bin: PartsBin
var _events: int = 0
var _out: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var size: Vector2i = DisplayServer.window_get_size()
	_out = "res://shots/appux/%dx%d/" % [size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var t0: int = Time.get_ticks_msec()
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	print("WALK boot_120_frames_ms %d" % (Time.get_ticks_msec() - t0))
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_bin = _main.get("_bin")
	await _frames(60)
	await _shot("00_first_open")
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
	if only == "" or only == "counts":
		await _counts()
	if only == "" or only == "menus":
		await _menus()
	if only == "" or only == "search":
		await _search_quality()
	if only == "" or only == "wall":
		await _first_wall()
	if only == "" or only == "turns":
		await _turns()
	if only == "" or only == "dialogs":
		await _dialogs()
	if only == "" or only == "round2":
		await _round2()
	if only == "" or only == "round3":
		await _round3()
	if only == "" or only == "round4":
		await _round4()
	if only == "gaps":
		await _gaps()
	print("WALK done")
	quit(0)


func _menus() -> void:
	var menus: Array = _shell.get("_menus")
	for menu: MenuButton in menus:
		menu.show_popup()
		await _frames(20)
		var popup: PopupMenu = menu.get_popup()
		var items: int = popup.item_count
		var greyed: int = 0
		var keyed: int = 0
		for n: int in items:
			if popup.is_item_disabled(n):
				greyed += 1
			if popup.get_item_accelerator(n) != 0:
				keyed += 1
		print("WALK menu %s items=%d greyed=%d with_key=%d height=%d" % [menu.text, items,
			greyed, keyed, popup.size.y])
		await _shot("menu_" + menu.text.to_lower())
		popup.hide()
		await _frames(5)
	# The right-click menu on a part of the example.
	var bricks: Array = _model()
	if not bricks.is_empty():
		var at: Vector2 = _camera.unproject_position((bricks[0] as BrickWorld.Brick).transform.origin)
		_shell.open_context(at)
		await _frames(20)
		var context: PopupMenu = _shell.context
		print("WALK context items=%d" % context.item_count)
		await _shot("menu_context")
		context.hide()
		await _frames(5)


## A builder's words, and the part they mean.
const QUERIES: Array = [
	["2x4", "3001"], ["brick 2x4", "3001"], ["2 x 4 brick", "3001"], ["1x2 plate", "3023"],
	["plate 2x2", "3022"], ["3001", "3001"], ["300121", "3001"], ["slope 45 2x2", "3039"],
	["cheese slope", "54200"], ["tile 1x2", "3069b"], ["grille", "2412b"], ["jumper", "3794b"],
	["headlight", "4070"], ["round 1x1", "4073"], ["hinge", ""], ["clip", ""],
	["technic pin", "2780"], ["axle 4", "3705"], ["liftarm 7", "32524"], ["beam 7", "32524"],
	["window", ""], ["door", ""], ["wheel", ""], ["minifig head", "3626"], ["torso", ""],
	["macaroni", "25269"], ["snot", ""], ["bracket", "99781"], ["log", "30136"], ["arch", ""],
]


func _search_quality() -> void:
	var search: LineEdit = _bin.get("_search")
	for pair: Array in QUERIES:
		var query: String = pair[0]
		await _click(search.get_global_rect().get_center())
		await _key(KEY_A, true)
		var start: int = Time.get_ticks_usec()
		await _type(query)
		var typed: int = Time.get_ticks_usec()
		await create_timer(0.35).timeout
		await _frames(3)
		var results: Array = _bin.get("_results")
		var top: Array = []
		var rank: int = -1
		for n: int in mini(results.size(), 40):
			var id: String = _id_of(results[n])
			if id == str(pair[1]) and rank < 0:
				rank = n + 1
			if n < 5:
				top.append("%s %s" % [id, _name_of(id)])
		print("WALK search %-14s want=%-6s rank=%s total=%d typing_ms=%d top=%s" % [
			"\"%s\"" % query, pair[1], str(rank) if rank > 0 else "-", results.size(),
			(typed - start) / 1000, " | ".join(top)])
		if query in ["2x4", "hinge", "window", "cheese slope"]:
			await _shot("search_" + query.replace(" ", "_"))
	await _click(search.get_global_rect().get_center())
	await _key(KEY_A, true)
	await _key(KEY_BACKSPACE)


func _id_of(result: Variant) -> String:
	if result is String:
		return result
	if result is Object and (result as Object).get("id") != null:
		return str((result as Object).get("id"))
	if result is Dictionary:
		return str((result as Dictionary).get("id", ""))
	return str(result)


func _name_of(id: String) -> String:
	var info: PartLibrary.PartInfo = _library.parts.get(id)
	return info.name if info != null else ""


## Four 1 x 4 bricks in a row and four more on them, half a brick along:
## the events a person spends, and the frames.
func _first_wall() -> void:
	_main.call("clear_model")
	await _frames(30)
	_camera.frame(AABB(Vector3(-200, -40, -120), Vector3(400, 120, 240)))
	await _frames(40)
	_events = 0
	var start: int = Time.get_ticks_msec()
	var search: LineEdit = _bin.get("_search")
	await _click(search.get_global_rect().get_center())
	await _type("1x4 brick")
	await create_timer(0.35).timeout
	await _frames(4)
	var grid: GridContainer = _bin.get("_grid")
	var first: Control = grid.get_child(0)
	print("WALK wall first tile %s" % str(first.get_meta("part", "?")))
	var eight: Array = []
	for n: int in mini(8, grid.get_child_count()):
		var id: String = str(grid.get_child(n).get_meta("part", "?"))
		eight.append("%s %s" % [id, _name_of(id)])
	print("WALK wall \"1x4 brick\" first eight: %s" % " | ".join(eight))
	await _shot("search_1x4_brick")
	await _click(first.get_global_rect().get_center())
	await _frames(6)
	print("WALK wall in hand=%s after %d events" % [_builder.is_carrying(), _events])
	var placed: int = 0
	for row: int in 2:
		for n: int in 4:
			var at := Vector3(-120 + n * 80 + row * 40, row * 24, 0)
			var spot: Vector2 = _camera.unproject_position(at + Vector3(0, 24, 0))
			await _move(spot)
			await _move(spot + Vector2(1, 0))
			await _click(spot + Vector2(1, 0))
			placed += 1
	await _key(KEY_ESCAPE)
	print("WALK wall parts=%d events=%d ms=%d" % [_count(), _events, Time.get_ticks_msec() - start])
	await _shot("wall")
	# A ghost swept across the model: the frame times a hand feels.
	await _key(KEY_Q)
	var worst: int = 0
	var total: int = 0
	for n: int in 40:
		var spot: Vector2 = _camera.unproject_position(Vector3(-160 + n * 8, 48, 0))
		var t: int = Time.get_ticks_usec()
		await _move(spot)
		var spent: int = Time.get_ticks_usec() - t
		worst = maxi(worst, spent)
		total += spent
	print("WALK ghost sweep mean_ms=%.1f worst_ms=%.1f (3 frames each)" % [total / 40000.0,
		worst / 1000.0])
	await _shot("ghost_over_wall")
	await _key(KEY_ESCAPE)


func _turns() -> void:
	if _count() == 0:
		await _first_wall()
	var one: BrickWorld.Brick = _model()[0]
	_builder.clear_selection()
	_builder.selection[one.id] = true
	_builder.selection_changed.emit(1)
	await _frames(10)
	_shell.set_turn_step(15)
	await _frames(5)
	# appux2: since A3 a turn with no room puts the part in hand, turned.
	# The actions to have it down turned: R, then aim and click.
	var before: int = _count()
	_events = 0
	await _key(KEY_R)
	if _world.get_brick(one.id) == null and _builder.is_carrying():
		var spot: Vector2 = _camera.unproject_position(Vector3(-120, 24, 160))
		await _move(spot)
		await _click(spot + Vector2(1, 0))
		var newest: BrickWorld.Brick = null
		for brick: BrickWorld.Brick in _model():
			if newest == null or brick.id > newest.id:
				newest = brick
		print("WALK turn in a wall: R put it in hand; down after %d events (+1 aim), parts %d->%d, yaw=%.1f" % [
			_events, before, _count(), rad_to_deg(newest.transform.basis.get_euler().y)])
		await _shot("turn_in_wall_down")
		await _key(KEY_ESCAPE)
		_builder.clear_selection()
		_builder.selection[newest.id] = true
		_builder.selection_changed.emit(1)
	else:
		var b: Basis = _world.get_brick(one.id).transform.basis
		print("WALK turn 1xR at 15 deg in the wall: yaw=%.1f carrying=%s" % [
			rad_to_deg(b.get_euler().y), _builder.is_carrying()])
	await _frames(10)
	var shown_before: bool = _bin._scroll.is_visible_in_tree()
	_shell.run("show_properties")
	await _frames(30)
	var hidden: Array = _fields_out_of_sight()
	print("WALK properties with a part selected: %d fields out of sight %s; bin shown before=%s after=%s" % [
		hidden.size(), str(hidden), shown_before, _bin._scroll.is_visible_in_tree()])
	await _frames(30)
	await _shot("turned_15_properties")
	_shell.run("mode_rotate")
	await _frames(30)
	await _shot("rotate_tool")
	_shell.run("mode_select")
	_shell.run("mode_move")
	await _frames(30)
	await _shot("move_tool")
	_shell.run("mode_select")
	await _frames(5)


const DIALOGS: Array = ["instructions", "timeline", "share", "together", "settings", "keys",
	"export_3d", "versions", "collection", "minifig", "part_maker", "flex", "stress",
	"parts_list", "panel_outliner", "stability", "brickify", "mosaic", "connector", "tour",
	"library", "compare", "pattern", "measure"]


func _dialogs() -> void:
	_main.call("clear_model")
	await _frames(10)
	var opened: int = 0
	if only_dialogs_turn:
		await _free_turn()
		_main.call("clear_model")
		await _frames(10)
	if _count() == 0:
		var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(
			"res://models/car.ldr"))
		var bar: ModelBar = _main.get("_bar")
		await bar.open_text_with_progress(text, "car")
	await _frames(60)
	print("WALK dialogs on %d parts (%s)" % [_count(), opened])
	_main.call("set_assistant", true)
	await _frames(40)
	await _shot("assistant_on")
	for name: String in DIALOGS:
		if _shell.command(name) == null:
			print("WALK dialog %s: no such command" % name)
			continue
		if not _shell.can(name):
			print("WALK dialog %s: greyed" % name)
			continue
		var t: int = Time.get_ticks_msec()
		_shell.run(name)
		await _frames(90)
		print("WALK dialog %s opened, %d ms incl 90 frames" % [name, Time.get_ticks_msec() - t])
		await _shot("dialog_" + name)
		await _close_all()


var only_dialogs_turn: bool = true


## A brick alone on the floor, turned three times at the 15 degree step.
func _free_turn() -> void:
	_main.call("clear_model")
	await _frames(10)
	var where := Transform3D(Basis.IDENTITY, Vector3(0, 24, 0))
	var brick_id: int = _world.add_brick("3001", 4, where)
	_builder.register(brick_id, "3001", where)
	_builder.clear_selection()
	_builder.selection[brick_id] = true
	_builder.selection_changed.emit(1)
	_camera.frame(AABB(Vector3(-120, 0, -120), Vector3(240, 80, 240)))
	await _frames(20)
	_shell.set_turn_step(15)
	for n: int in 3:
		await _key(KEY_R)
	var b: Basis = _world.get_brick(brick_id).transform.basis
	print("WALK free turn 3xR at 15 deg: yaw=%.1f" % rad_to_deg(b.get_euler().y))
	await _shot("free_turn_45")
	_shell.run("mode_rotate")
	await _frames(20)
	await _shot("free_rotate_tool")
	_shell.run("mode_select")
	await _frames(5)


## appux3: pictures of the gaps APP_UX3 plans for, on the car.
func _gaps() -> void:
	var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(
		"res://models/car.ldr"))
	var bar: ModelBar = _main.get("_bar")
	await bar.open_text_with_progress(text, "car")
	await _frames(60)
	await _close_all()
	# The steps: a part picked and the timeline on its author's steps.
	var one: BrickWorld.Brick = _model()[5]
	_builder.clear_selection()
	_builder.selection[one.id] = true
	_builder.selection_changed.emit(1)
	_shell.run("timeline")
	await _frames(60)
	print("WALK gaps timeline: step keys earlier=%s later=%s" % [_shell.key_words("step_earlier"),
		_shell.key_words("step_later")])
	await _shot("gap_steps_timeline")
	_shell.run("timeline")
	await _frames(20)
	# Render: what it makes.
	_shell.run("render")
	await _frames(60)
	await _shot("gap_render_kinds")
	await _close_all()
	# The parts list: counts, element numbers, no price.
	_shell.run("parts_list")
	await _frames(60)
	await _shot("gap_parts_list_no_price")
	await _close_all()
	# The booklet.
	_shell.run("instructions")
	await _frames(240)
	await _shot("gap_booklet_page")
	await _close_all()
	# Settings: no language.
	_shell.run("settings")
	await _frames(60)
	await _shot("gap_settings_no_language")
	await _close_all()
	# The part menu: Mirror, Split and Merge are the window's alone.
	var at: Vector2 = _camera.unproject_position(one.transform.origin)
	_shell.open_context(at)
	await _frames(20)
	await _shot("gap_part_menu_window_only")
	_shell.context.hide()
	await _frames(5)
	print("WALK gaps done")


## appux3: round two's features as a person meets them, on the car.
func _round2() -> void:
	if _count() == 0:
		var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(
			"res://models/car.ldr"))
		var bar: ModelBar = _main.get("_bar")
		await bar.open_text_with_progress(text, "car")
		await _frames(60)
	await _close_all()
	# A favourite colour on three selected parts: Shift+5 is Red out of the box.
	var three: Array = _model().slice(0, 3)
	_builder.clear_selection()
	for brick: BrickWorld.Brick in three:
		_builder.selection[brick.id] = true
	_builder.selection_changed.emit(3)
	await _frames(10)
	_events = 0
	await _key(KEY_5, false, true)
	await _frames(10)
	var red: int = 0
	for brick: BrickWorld.Brick in three:
		if _world.get_brick(brick.id) != null and _world.get_brick(brick.id).color_code == 4:
			red += 1
	print("WALK colour key: %d of 3 red after %d key presses (key words %s)" % [red, _events,
		_shell.key_words("favourite_5")])
	await _shot("colour_key_red")
	_builder.undo()
	await _frames(5)
	# Split a 2 x 4 plate, then merge it back, by their keys.
	_main.call("clear_model")
	await _frames(10)
	var where := Transform3D(Basis.IDENTITY, Vector3(0, 8, 0))
	var plate: int = _world.add_brick("3020", 4, where)
	_builder.register(plate, "3020", where)
	_builder.clear_selection()
	_builder.selection[plate] = true
	_builder.selection_changed.emit(1)
	_camera.frame(AABB(Vector3(-80, 0, -80), Vector3(160, 40, 160)))
	await _frames(20)
	_events = 0
	await _key(KEY_S, false, false, true)
	await _frames(20)
	print("WALK split 3020 by %s: %d parts after %d key presses" % [_shell.key_words("split_parts"),
		_count(), _events])
	await _shot("split_plate")
	_shell.run("select_all")
	await _frames(5)
	_events = 0
	await _key(KEY_M, false, false, true)
	await _frames(20)
	var kinds: Array = []
	for brick: BrickWorld.Brick in _model():
		kinds.append(brick.part_id)
	print("WALK merge by %s: %d parts %s after %d key presses" % [_shell.key_words("merge_parts"),
		_count(), str(kinds), _events])
	# View › Split, and how much of the window each view keeps.
	var text2: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(
		"res://models/car.ldr"))
	_main.call("clear_model")
	var bar2: ModelBar = _main.get("_bar")
	await bar2.open_text_with_progress(text2, "car")
	await _frames(60)
	var split: Control = _main.get("_split")
	print("WALK split view: offered=%s key=%s" % [_shell.can("split_view"), _shell.key_words("split_view")])
	if _shell.can("split_view"):
		_shell.run("split_view")
		await _frames(40)
		print("WALK split view showing=%s rect=%s window=%s" % [split.call("is_showing"),
			str(split.get_global_rect()), str(root.get_visible_rect().size)])
		await _shot("split_view")
		_shell.run("split_view")
		await _frames(10)
	for name: String in ["reference", "simulate", "compare", "printed_versions", "pose",
			"collection_need", "find_colour"]:
		if _shell.command(name) == null or not _shell.can(name):
			print("WALK round2 %s: %s" % [name, "no such command" if _shell.command(name) == null else "greyed"])
			continue
		var t: int = Time.get_ticks_msec()
		_shell.run(name)
		await _frames(60)
		print("WALK round2 %s opened, %d ms incl 60 frames, key=%s" % [name, Time.get_ticks_msec() - t,
			_shell.key_words(name)])
		await _shot("round2_" + name)
		await _close_all()
	# Steps: how many presses move a part five steps later.
	print("WALK step keys: earlier=%s later=%s new=%s merge=%s delete=%s prev=%s next=%s" % [
		_shell.key_words("step_earlier"), _shell.key_words("step_later"), _shell.key_words("step_new"),
		_shell.key_words("step_merge"), _shell.key_words("step_delete"), _shell.key_words("step_prev"),
		_shell.key_words("step_next")])


## appux4: round three's features as a person meets them, on the car.
func _round3() -> void:
	# The first build's offer, after a person has built a wall by hand and
	# opened the car and the panels (APP_UX3 "Next": it goes once a person
	# has built by hand).
	print("WALK round3 first build offer showing=%s" % _shell.first_build.visible)
	_main.call("clear_model")
	await _frames(10)
	var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(
		"res://models/car.ldr"))
	var bar: ModelBar = _main.get("_bar")
	await bar.open_text_with_progress(text, "car")
	await _frames(60)
	await _close_all()
	# steps3: a part moved to the last step by Move to step…, its key and
	# the number typed, read back off the plan the booklet is made from.
	var plan: Array = Instructions.plan(_world, _library, _store.scenery, {}, true)
	var one: BrickWorld.Brick = _model()[5]
	var from: int = _step_of(plan, one.id)
	var last: int = (plan[-1] as Instructions.Step).number if not plan.is_empty() else 0
	_builder.clear_selection()
	_builder.selection[one.id] = true
	_builder.selection_changed.emit(1)
	await _frames(10)
	var key: String = _shell.key_words("step_to")
	_events = 0
	if key == "Alt+T":
		await _key(KEY_T, false, false, true)
	else:
		_events += 1
		_shell.run("step_to")
	await _frames(20)
	await _shot("round3_move_to_step")
	await _type(str(last))
	await _key(KEY_ENTER)
	await _frames(20)
	var after: int = _step_of(Instructions.plan(_world, _library, _store.scenery, {}, true), one.id)
	print("WALK round3 move to step (%s): a part from step %d to %d of %d after %d events (%d of them the number's keys)" % [
		key if key != "" else "no key", from, after, last, _events, str(last).length()])
	_builder.undo()
	await _frames(10)
	print("WALK round3 step keys: to=%s earlier=%s later=%s merge=%s delete=%s prev=%s next=%s new=%s close=%s" % [
		_shell.key_words("step_to"), _shell.key_words("step_earlier"), _shell.key_words("step_later"),
		_shell.key_words("step_merge"), _shell.key_words("step_delete"), _shell.key_words("step_prev"),
		_shell.key_words("step_next"), _shell.key_words("step_new"), _shell.key_words("step_close")])
	# The timeline, with the part selected: its row of steps takes a drop.
	_shell.run("timeline")
	await _frames(60)
	await _shot("round3_timeline")
	_shell.run("timeline")
	await _frames(20)
	await _close_all()
	# buildvideo and pathtrace: what Render makes, and whether Best traces.
	_shell.run("render")
	await _frames(60)
	var render: Control = _main.get("_render")
	var building: bool = render != null and render.get("_building_button") != null
	print("WALK round3 render: building offered=%s; Best path traced here=%s (%s)" % [building,
		PathTracer.available(), "" if PathTracer.available() else PathTracer.why_not()])
	await _shot("round3_render")
	await _close_all()
	var t: int = Time.get_ticks_msec()
	_shell.run("render_queue")
	await _frames(60)
	print("WALK round3 render queue opened, %d ms incl 60 frames, key=%s" % [Time.get_ticks_msec() - t,
		_shell.key_words("render_queue")])
	await _shot("round3_render_queue")
	await _close_all()
	# booklet3: the booklet page's extras, on the menu and their keys.
	var extras: Array = []
	for name: String in ["booklet_pull", "booklet_colours", "booklet_actual_size", "booklet_preview"]:
		extras.append("%s %s key=%s" % [name, "offered" if _shell.command(name) != null else "missing",
			_shell.key_words(name)])
	print("WALK round3 booklet extras: %s" % ", ".join(extras))
	t = Time.get_ticks_msec()
	_shell.run("instructions")
	await _frames(240)
	print("WALK round3 instructions on the car: %d ms incl 240 frames" % (Time.get_ticks_msec() - t))
	await _shot("round3_instructions")
	await _close_all()
	# languages: Settings' Language row.
	_shell.run("settings")
	await _frames(60)
	var choices: Array = []
	for node: Node in root.find_children("*", "OptionButton", true, false):
		var option := node as OptionButton
		var items: Array = []
		for n: int in option.item_count:
			items.append(option.get_item_text(n))
		if "Deutsch" in items:
			choices = items
	print("WALK round3 settings language: %s" % (", ".join(choices) if not choices.is_empty() else "none"))
	await _shot("round3_settings_language")
	await _close_all()
	# Cut away: a plane through the model (StudWorx cuts with a box, a
	# sphere or a cylinder).
	_shell.run("cut")
	await _frames(30)
	print("WALK round3 cut away key=%s" % _shell.key_words("cut"))
	await _shot("round3_cut_away")
	_shell.run("cut")
	await _frames(10)
	# B5 Like this: a 2 x 4 brick clicked, the chip clicked, the tiles.
	_main.call("clear_model")
	await _frames(10)
	var where := Transform3D(Basis.IDENTITY, Vector3(0, 24, 0))
	var brick: int = _world.add_brick("3001", 4, where)
	_builder.register(brick, "3001", where)
	_builder.clear_selection()
	_camera.frame(AABB(Vector3(-120, 0, -80), Vector3(240, 60, 160)))
	await _frames(30)
	_events = 0
	await _click(_camera.unproject_position(where.origin + Vector3(0, -2, 0)))
	var chip: Button = null
	for child: Node in (_bin.get("_category_row") as Control).get_children():
		if str(child.get_meta("category", "")) == "Like this":
			chip = child
	if chip != null and chip.is_visible_in_tree():
		await _click(chip.get_global_rect().get_center())
		for _n: int in 300:
			if not bool(_bin.get("_like_waiting")) and not _bin.first_found(1).is_empty():
				break
			await process_frame
		await _frames(10)
		var found: PackedStringArray = _bin.first_found(12)
		var named: Array = []
		for id: String in found:
			named.append("%s %s" % [id, _name_of(id)])
		print("WALK round3 like this: selected=%s after %d clicks, %d tiles in sight; first twelve: %s; 3020 at %s" % [
			_builder.selection.has(brick), _events, _tiles_in_sight().size(), " | ".join(named),
			str(found.find("3020") + 1) if found.has("3020") else "-"])
	else:
		print("WALK round3 like this: no chip in sight")
	await _shot("round3_like_this")
	_bin.show_category("All")
	await _frames(10)
	# APP_UX3's "Next": the keys of the commands it named, Pattern's kinds.
	var next: Array = []
	for name: String in ["reference", "simulate", "pose", "measure", "render", "instructions",
			"pattern", "split_view", "timeline"]:
		next.append("%s=%s" % [name, _shell.key_words(name) if _shell.key_words(name) != "" else "none"])
	print("WALK round3 keys: %s" % ", ".join(next))
	var kinds: Array = []
	for kind: Array in PatternDialog.KINDS:
		kinds.append(kind[0])
	print("WALK round3 pattern kinds: %s" % ", ".join(kinds))


## appux5: round four's features as a person meets them, on the car.
func _round4() -> void:
	await _close_all()
	_main.call("clear_model")
	await _frames(10)
	var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(
		"res://models/car.ldr"))
	var bar: ModelBar = _main.get("_bar")
	await bar.open_text_with_progress(text, "car")
	await _frames(60)
	await _close_all()
	_builder.clear_selection()
	_builder.selection_changed.emit(0)
	await _frames(20)
	# What the window says of the whole model, nothing selected: Studio's
	# Model Info gives its size in studs and centimetres and a weight.
	var fields: Dictionary = _shell.status.fields()
	print("WALK round4 status bar, car open, nothing selected: counts=\"%s\" selected=\"%s\" settings=\"%s\" line=\"%s\"" % [
		fields.get("counts", ""), fields.get("selected", ""), fields.get("settings", ""), fields.get("line", "")])
	var words: Array = []
	if _shell.inspector != null and _shell.inspector._scroll.is_visible_in_tree():
		for label: Node in _shell.inspector._body.find_children("*", "Label", true, false):
			if (label as Label).is_visible_in_tree() and (label as Label).text.strip_edges() != "":
				words.append((label as Label).text.strip_edges().left(60))
	print("WALK round4 properties, nothing selected: %s" % (" | ".join(words) if not words.is_empty() else "not open"))
	await _shot("round4_nothing_selected")
	# quiet: the render queue put away by Escape, and Settings drawn over it.
	_shell.run("render_queue")
	await _frames(60)
	var queue: Control = _main.get_node_or_null("HUD/RenderQueue") as Control
	var up: bool = queue != null and queue.is_visible_in_tree()
	await _key(KEY_ESCAPE)
	await _frames(20)
	print("WALK round4 render queue: open=%s, after Escape open=%s" % [up,
		queue != null and queue.is_visible_in_tree()])
	_shell.run("render_queue")
	await _frames(40)
	_shell.run("settings")
	await _frames(60)
	await _shot("round4_settings_over_queue")
	await _close_all()
	if queue != null and queue.is_visible_in_tree():
		await _key(KEY_ESCAPE)
		await _frames(10)
	# whatsthis: Shift+F1, then a click on a toolbar button.
	var move: Control = _shell.toolbar.controls_by_name().get("tool_mode_move")
	if move != null and move.is_visible_in_tree():
		_events = 0
		await _key(KEY_F1, false, true)
		await _frames(10)
		await _click(move.get_global_rect().get_center())
		await _frames(20)
		var asker: Node = _main.get_node_or_null("WhatsThis")
		var said: String = str(asker.get("said")) if asker != null else ""
		print("WALK round4 what's this (%s) on the Move button after %d events: \"%s\"; the mode is still %s" % [
			_shell.key_words("whats_this"), _events, said.replace("\n", " / ").left(240),
			_shell.verbs.mode if _shell.verbs != null else "?"])
		await _shot("round4_whats_this")
		await _key(KEY_ESCAPE)
		await _frames(10)
	else:
		print("WALK round4 what's this: no Move button in sight")
	# The place of a part in hand, on the status bar (LeoCAD).
	var search: LineEdit = _bin.get("_search")
	await _click(search.get_global_rect().get_center())
	await _key(KEY_A, true)
	await _type("2x4")
	await create_timer(0.35).timeout
	await _frames(4)
	var grid: GridContainer = _bin.get("_grid")
	if grid.get_child_count() > 0:
		await _click((grid.get_child(0) as Control).get_global_rect().get_center())
		await _frames(6)
		var over: Vector2 = _camera.unproject_position(Vector3(0, 60, 0))
		await _move(over)
		await _move(over + Vector2(1, 0))
		await _frames(10)
		print("WALK round4 in hand=%s, the status bar's place: \"%s\"" % [_builder.is_carrying(),
			_shell.status.fields().get("place", "")])
		await _shot("round4_place_in_hand")
		await _key(KEY_ESCAPE)
		await _frames(10)
	await _click(search.get_global_rect().get_center())
	await _key(KEY_A, true)
	await _key(KEY_BACKSPACE)
	await _frames(10)
	# cutshapes: Cut away by a box, from the menu.
	var see: Object = _shell.get("see_inside")
	if _shell.command("cut_box") != null and _shell.can("cut_box"):
		var t: int = Time.get_ticks_msec()
		_shell.run("cut_box")
		await _frames(60)
		print("WALK round4 cut away by a box: %d ms incl 60 frames, keys box=%s sphere=%s cylinder=%s; says \"%s\"" % [
			Time.get_ticks_msec() - t, _shell.key_words("cut_box"), _shell.key_words("cut_sphere"),
			_shell.key_words("cut_cylinder"), _shell.status.fields().get("message", "")])
		await _shot("round4_cut_box")
		if see != null and see.has_method("set_cut"):
			see.call("set_cut", false)
		await _frames(10)
	else:
		print("WALK round4 cut away by a box: %s" % ("greyed" if _shell.command("cut_box") != null else "no such command"))
	# grid: Pattern's In a grid, on one brick of the car.
	var one: BrickWorld.Brick = _model()[5]
	_builder.clear_selection()
	_builder.selection[one.id] = true
	_builder.selection_changed.emit(1)
	await _frames(10)
	_events = 0
	await _key(KEY_D, true, true)
	await _frames(30)
	var dialog: PatternDialog = _shell.pattern_dialog
	var grid_button: Button = dialog.controls_by_name().get("pattern_grid") if dialog != null else null
	if dialog != null and dialog.is_open() and grid_button != null:
		await _click(Vector2(dialog.position) + grid_button.get_global_rect().get_center())
		await _frames(30)
		print("WALK round4 pattern (%s): In a grid chosen=%s after %d events" % [_shell.key_words("pattern"),
			dialog.kind == "grid", _events])
		await _shot("round4_pattern_grid")
	else:
		print("WALK round4 pattern: open=%s, In a grid offered=%s" % [dialog != null and dialog.is_open(),
			grid_button != null])
	await _close_all()
	# picklist: the parts list's buttons, LEGO Pick a Brick among them.
	_shell.run("parts_list")
	await _frames(60)
	var shops: Array = []
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and (button.text.contains("Pick a Brick")
				or button.text.contains("BrickLink") or button.text.contains("Rebrickable")):
			shops.append(button.text)
	print("WALK round4 parts list's shops: %s; File, Export, Pick a Brick key=%s" % [", ".join(shops),
		_shell.key_words("export_pickabrick")])
	await _shot("round4_parts_list")
	await _close_all()
	# intomodel: File, Import, Into this model…; the library's Put in this model.
	print("WALK round4 into this model: offered=%s greyed=%s key=%s" % [_shell.command("import_into") != null,
		_shell.command("import_into") != null and not _shell.can("import_into"), _shell.key_words("import_into")])
	# tracks: whether the app knows where a train track ends.
	var classes: Array = []
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")).to_lower().contains("track"):
			classes.append(str(entry["class"]))
	print("WALK round4 track classes: %s; track_ends.json %s" % [", ".join(classes) if not classes.is_empty() else "none",
		"present" if FileAccess.file_exists("res://assets/ldraw/track_ends.json") else "absent"])
	# What still has no key, of the commands a builder reaches for.
	var keyless: Array = []
	for name: String in ["render", "instructions", "render_queue", "reference", "parts_list",
			"import_into", "export_pickabrick", "cut", "cut_box", "pattern", "split_view", "library"]:
		keyless.append("%s=%s" % [name, _shell.key_words(name) if _shell.key_words(name) != "" else "none"])
	print("WALK round4 keys: %s" % ", ".join(keyless))


func _step_of(plan: Array, id: int) -> int:
	for step: Instructions.Step in plan:
		if step.brick_ids.has(id):
			return step.number
	return -1


## appux2: the counts appux371's plan set bars on, read as a person meets them.
func _counts() -> void:
	var named: int = 0
	var tiles: Array = _tiles_in_sight()
	for tile: Control in tiles:
		for label: Node in tile.find_children("*", "Label", true, false):
			if (label as Label).text.strip_edges().length() > 3 and (label as Label).is_visible_in_tree():
				named += 1
				break
	print("WALK bin tiles in sight=%d named=%d bin_open=%s properties_open=%s" % [tiles.size(), named,
		_bin._scroll.is_visible_in_tree(), _shell.inspector._scroll.is_visible_in_tree()])
	var commands: Dictionary = _shell.get("_commands")
	var keyless: Array = []
	for name: String in commands:
		if _shell.key_words(name) == "":
			keyless.append(name)
	keyless.sort()
	print("WALK commands total=%d with_key=%d without=%d" % [commands.size(),
		commands.size() - keyless.size(), keyless.size()])
	print("WALK commands without a key: %s" % ", ".join(keyless))
	var sheet: Control = _main.get("_controls")
	_events = 0
	await _key(KEY_F1)
	await _frames(20)
	var rows: Array = []
	for row: Node in sheet.find_children("*", "HBoxContainer", true, false):
		if row.get_child_count() == 3 and row.get_child(2) is Label and row.get_child(1) is CenterContainer:
			rows.append(row)
	var seen: int = 0
	var room := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for row: Control in rows:
		if not row.is_visible_in_tree():
			continue
		var scroll: Control = row.get_parent()
		while scroll != null and not scroll is ScrollContainer:
			scroll = scroll.get_parent()
		var window: Rect2 = scroll.get_global_rect().intersection(room) if scroll != null else room
		if window.grow(0.5).encloses(row.get_global_rect()):
			seen += 1
	print("WALK keys sheet rows in sight=%d of %d" % [seen, rows.size()])
	await _shot("keys_sheet")
	await _key(KEY_ESCAPE)
	await _frames(10)
	_events = 0
	await _key(KEY_SLASH, true)
	await _frames(10)
	await _type("ren")
	await _frames(10)
	await _shot("palette_ren")
	await _key(KEY_ENTER)
	await _frames(30)
	var render: Control = _main.get("_render")
	print("WALK palette: Render open=%s after %d key presses" % [render != null and render.visible, _events])
	await _close_all()


func _tiles_in_sight() -> Array:
	var out: Array = []
	var scroll: ScrollContainer = _bin._scroll
	if not scroll.is_visible_in_tree():
		return out
	var window: Rect2 = scroll.get_global_rect()
	for cell: Node in _bin._grid.get_children():
		var tile := cell as Control
		if tile != null and tile.visible and window.encloses(tile.get_global_rect()):
			out.append(tile)
	return out


func _fields_out_of_sight() -> Array:
	var out: Array = []
	var inspector: Inspector = _shell.inspector
	var scroll: ScrollContainer = inspector._scroll
	if not scroll.is_visible_in_tree():
		return ["the whole panel"]
	var window: Rect2 = scroll.get_global_rect().intersection(Rect2(Vector2.ZERO,
		root.get_visible_rect().size))
	for node: Node in inspector._body.find_children("*", "Control", true, false):
		var field := node as Control
		if not (field is SpinBox or field is Button) or not field.is_visible_in_tree():
			continue
		if not window.grow(0.5).encloses(field.get_global_rect()):
			out.append(field.name)
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if bar.max_value - bar.page > 1.0:
		out.append("%d units behind the scroller" % (bar.max_value - bar.page))
	return out


func _close_all() -> void:
	# The library and the collection are panels over the model, not windows.
	for panel_name: String in ["library_dialog", "collection"]:
		var panel: Node = _shell.get(panel_name)
		if panel is CanvasItem and (panel as CanvasItem).visible:
			(panel as CanvasItem).hide()
	for window: Window in _windows(root):
		if window != root and window.visible:
			window.hide()
	await _key(KEY_ESCAPE)
	await _frames(10)


func _windows(node: Node) -> Array:
	var out: Array = []
	for child: Node in node.get_children():
		if child is Window:
			out.append(child)
		out.append_array(_windows(child))
	return out


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


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
	_events += 1
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _key(code: Key, command: bool = false, shift: bool = false, alt: bool = false) -> void:
	_events += 1
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.shift_pressed = shift
		event.alt_pressed = alt
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _type(text: String) -> void:
	for n: int in text.length():
		_events += 1
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out + name + ".png")
	image.save_png(path)
	print("WALK shot %s" % path)
