## The small faults a finger met, left by phonewalk, fingertools and
## phonepanels (docs/app_ux8/phonewalk.md; unit smalls2), on a phone.
##
##   godot --path . --resolution 390x844 --script src/dev/smalls2_probe.gd [-- --shots=DIR --only=…]
##
## Laid out for a phone at a browser's scale (as phonepanels_probe holds
## it), driven by fingers as the window hands them over (InputEventScreen
## Touch and ScreenDrag; the engine raises its own click from them, as a
## phone's browser does). Each act counts its presses as tools/web/
## phonewalk_flow.mjs counts them. No account: nothing here is an account's.
## 1. more: More's commands the walk reached for (PhoneShell.QUICK) each in
##    sight as More opens, a fingertip each way, run in two taps: Cut away
##    on and Check stability said, More and the row each.
## 2. timeline: on the car as it first opens, the timeline from More's row:
##    its row of steps and its Booklet row shown (steps_bar start(), which
##    set them only on a change of order); its Lay out the page… a
##    fingertip each way, and a tap on it opens the page editor.
## 3. select: a part tapped, Select tapped while lit, two more tapped: three
##    selected, said in the line over the model; one of them tapped again
##    takes it out; a tap on nothing keeps them; Select again ends it and a
##    tap selects one alone. Three painted in 6 taps at most (the desktop's
##    4: the walk's 9 one at a time).
## 4. line: the line over the model laid out as ever while the probe holds
##    the scale (PhoneShell.holds_scale): six seconds after "opened Car —
##    61 bricks", with Motions open, it says what a finger does now and
##    stands clear of the panel.
## 5. words: every line drawn on the screen with Simulate's panel open, the
##    ruler out and the part's actions up says no click, right-click or
##    hover; Simulate's own lines and Measure's as a finger reads them.
## Pictures in --shots=DIR (else user://smalls2). Exits non-zero when a
## check fails.
extends SceneTree

const CAR := "res://models/car.ldr"
## A fingertip, points: Phone.TARGET, read to half a point.
const LEAST := Phone.TARGET - 0.5
## The commands More is to have in two taps, as the walk names them.
const WALKED: Array[String] = ["render", "instructions", "stability", "cut", "measure", "simulate",
	"pose", "select_all", "timeline"]
## A mouse's words, which a finger has no use for.
const MOUSE := "\\b([Cc]lick(s|ed|ing)?|[Rr]ight[- ]click|[Hh]over(s|ed|ing)?)\\b"

var _failures: int = 0
var _only: PackedStringArray = []
var _main: Node
var _camera: CadCamera
var _world: BrickWorld
var _builder: Builder
var _shell: Shell
var _store: ModelStore
var _verbs: EditVerbs
var _bar: ModelBar
var _phone: Node
var _out: String = "user://smalls2"
var _presses: int = 0
## Whether the shell was left to lay itself out (holds_scale), or stopped.
var _holds: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("smalls2_probe: needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	ShellPrefs.kept_by_a_check = _own_data_folder()
	Phone._on = 1
	Phone._wide = false
	Input.emulate_touch_from_mouse = true
	Account.where = "user://probe_session.json"
	Account._clear()
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
	# A phone draws at a browser's scale, as phonepanels_probe holds it: the
	# shell told to leave the scale alone where it can be (holds_scale),
	# else stopped, as the probes before it were.
	_phone = _main.get("_phone")
	_holds = _phone != null and "holds_scale" in _phone
	if _holds:
		_phone.set("holds_scale", true)
	elif _phone != null:
		_phone.set_process(false)
	for link: Dictionary in root.size_changed.get_connections():
		var call: Callable = link["callable"]
		if call.get_method() == &"_match_screen_density":
			root.size_changed.disconnect(call)
	var main_script: GDScript = _main.get_script()
	root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
		ShellPrefs.interface_size(), true)
	await _frames(20)
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_shell = _main.get("_shell")
	_store = _main.get("_store")
	_verbs = _main.get("_verbs")
	_bar = _main.get("_bar")
	_store.keeps = false
	var size: Vector2i = DisplayServer.window_get_size()
	print("smalls2_probe: a %d x %d window laid out for a phone, %.3f units to the point; the shell %s"
		% [size.x, size.y, _pt(), "holds the scale and lays out as ever" if _holds else "stopped"])
	if not _check("the phone's layout is made, and the camera takes fingers as a phone's",
			_phone != null and _camera.phone):
		await _finish()
		return
	if not await _open(CAR):
		await _finish()
		return
	if _runs("more"):
		print("\n1. More's commands in two taps")
		await _more()
	if _runs("timeline"):
		print("\n2. the timeline on a model as it first opens")
		await _open(CAR)
		await _timeline()
	if _runs("select"):
		print("\n3. adding to the selection by finger")
		await _open(CAR)
		await _select()
	if _runs("line"):
		print("\n4. the line over the model, with Motions open")
		await _open(CAR)
		await _line()
	if _runs("words"):
		print("\n5. a finger's words")
		await _open(CAR)
		await _words()
	await _finish()


func _runs(section: String) -> bool:
	return _only.is_empty() or _only.has(section)


# -- 1. More ---------------------------------------------------------------------


func _more() -> void:
	await _tap(_middle(_named("phone_more")))
	await _frames(10)
	var named: Dictionary = _phone.call("controls_by_name")
	var panel: Control = named.get("phone_panel_more") as Control
	if not _check("More opens (%s)" % _sheet(), panel != null and _sheet() == "More"):
		return
	await _shot("1_more")
	var list: Rect2 = _list_rect(panel)
	var missing: Array[String] = []
	var hidden: Array[String] = []
	var small: Array[String] = []
	for command: String in WALKED:
		var tile: Control = named.get("phone_quick_" + command) as Control
		if tile == null or not tile.is_visible_in_tree():
			missing.append(command)
			continue
		var r: Rect2 = tile.get_global_rect()
		if not list.grow(1.0).encloses(r):
			hidden.append(command)
		if minf(r.size.x, r.size.y) / _pt() < LEAST:
			small.append("%s %.0f x %.0f" % [command, r.size.x / _pt(), r.size.y / _pt()])
	_check("each of the walk's commands a row of its own as More opens (%s)"
		% ("all %d" % WALKED.size() if missing.is_empty() else "none for " + ", ".join(missing)),
		missing.is_empty())
	_check("each in sight without a drag (%s)" % ("all" if hidden.is_empty() else
		"under the fold: " + ", ".join(hidden)), missing.is_empty() and hidden.is_empty())
	_check("each a fingertip each way (%s)" % ("all" if small.is_empty() else ", ".join(small)),
		missing.is_empty() and small.is_empty())
	# Cut away, by its row: More and the row.
	var see: SeeInside = _shell.see_inside
	var was: bool = see.cutting
	_presses = 1
	if named.has("phone_quick_cut"):
		await _tap(_middle(named["phone_quick_cut"]))
		await _frames(10)
	_check("Cut away from More in %d taps (the desktop's K, 1; at most 2): cutting %s, was %s"
		% [_presses, see.cutting, was], see.cutting and not was and _presses <= 2)
	if see.cutting:
		_shell.run("cut")
		await _frames(5)
	# Check stability, said: More and the row.
	_presses = 0
	await _tap(_middle(_named("phone_more")))
	await _frames(10)
	var said: String = ""
	var row: Control = _phone.call("controls_by_name").get("phone_quick_stability") as Control
	if row != null:
		_bar.say("")
		await _tap(_middle(row))
		for _n: int in 600:
			await process_frame
			said = _bar.status_text()
			if not said.is_empty():
				break
	_check("Check stability from More in %d taps (the desktop's 1; at most 2): said \"%s\""
		% [_presses, said.left(80)], row != null and not said.is_empty() and _presses <= 2)
	await _frames(10)


## The part of a sheet its rows are drawn in: under its head, above its foot.
func _list_rect(panel: Control) -> Rect2:
	var r: Rect2 = panel.get_global_rect()
	var head: Control = _phone.call("controls_by_name").get("phone_sheet_more") as Control
	if head != null:
		var top: float = head.get_global_rect().end.y
		r = Rect2(r.position.x, top, r.size.x, r.end.y - top)
	var screen: Rect2 = root.get_visible_rect()
	return r.intersection(screen)


# -- 2. the timeline -----------------------------------------------------------------


func _timeline() -> void:
	var steps: StepsBar = _main.get("_steps")
	if steps.visible:
		_shell.run("timeline")
		await _frames(10)
	_presses = 0
	await _tap(_middle(_named("phone_more")))
	await _frames(10)
	var row: Control = _phone.call("controls_by_name").get("phone_quick_timeline") as Control
	if row == null:
		# The base's: the row in Build, More closed as its row closes it.
		var done: Control = _phone.call("controls_by_name").get("phone_sheet_more_done") as Control
		if done != null:
			await _tap(_middle(done))
			_presses -= 1
		_shell.run("timeline")
	else:
		await _tap(_middle(row))
	for _n: int in 600:
		await process_frame
		if steps.visible and steps.current_step() != null:
			break
	await _frames(20)
	_check("the timeline from More's row in %d taps (the desktop's B, 1; at most 2)" % _presses,
		steps.visible and row != null and _presses <= 2)
	await _shot("2_timeline")
	var named: Dictionary = steps.controls_by_name()
	var lay: Control = named.get("booklet_lay_out") as Control
	var looks: bool = lay != null and lay.is_visible_in_tree()
	_check("its Booklet row is shown on a model as it first opens (order %s)"
		% str(steps.page_state().get("order", "")), looks)
	if not looks and lay != null:
		# Shown as a person can bring it: another order and back.
		steps.set_mode(1)
		steps.set_mode(0)
		await _frames(20)
		looks = lay.is_visible_in_tree()
		print("    shown once another order was chosen and this one again: %s" % looks)
	if not looks:
		return
	var r: Rect2 = lay.get_global_rect()
	_check("Lay out the page… is a fingertip each way (%.0f x %.0f points)" % [r.size.x / _pt(),
		r.size.y / _pt()], minf(r.size.x, r.size.y) / _pt() >= LEAST)
	# The timeline above the phone's row of tools, and Lay out the page… on
	# the screen in it: under the row, a tap on it was the row's.
	var foot: Control = _phone.get("_row") as Control
	var bottom: float = steps.get_global_rect().end.y
	_check("the timeline ends above the row of tools (%.0f, the row from %.0f points)" % [bottom / _pt(),
		foot.get_global_rect().position.y / _pt()], bottom <= foot.get_global_rect().position.y + 1.0)
	_check("Lay out the page… is on the screen, over nothing (%.0f, %.0f points)" % [r.get_center().x / _pt(),
		r.get_center().y / _pt()], root.get_visible_rect().has_point(r.get_center())
		and not _phone.call("covers", r.get_center()))
	var editor: PageEditor = _main.get("_page_editor")
	_presses = 0
	var heard: Array = [false]
	(lay as BaseButton).button_down.connect(func() -> void: heard[0] = true)
	await _tap(r.get_center())
	for _n: int in 300:
		await process_frame
		if editor.is_open():
			break
	_check("a tap on Lay out the page… opens the page editor (%d tap)" % _presses, editor.is_open())
	if not editor.is_open():
		print("    the button heard the press: %s; what takes a press there: %s" % [heard[0],
			_who_at(r.get_center())])
	# Where the timeline lies against the foot's row: its own room and what
	# it wants, each row of it, and the column round it.
	var column: Control = steps.get_parent_control()
	print("    window %s; the column %s; the timeline %s wanting %s" % [root.get_visible_rect().size,
		column.get_global_rect(), steps.get_global_rect(), steps.get_combined_minimum_size()])
	for child: Node in column.get_children():
		if child is Control and (child as Control).visible:
			print("      %s %s wants %s" % [child.name, (child as Control).get_global_rect(),
				(child as Control).get_combined_minimum_size()])
	for line: Node in steps.get_child(0).get_children():
		if line is Control and (line as Control).visible:
			print("      timeline: %s %s wants %s" % [line.get_class(), (line as Control).get_global_rect(),
				(line as Control).get_combined_minimum_size()])
	await _frames(20)
	await _shot("2_page_editor")
	if editor.is_open():
		var done: Control = editor.controls_by_name().get("page_done") as Control
		if done != null:
			await _tap(_middle(done))
		await _frames(10)
	if steps.visible:
		_shell.run("timeline")
		await _frames(10)


# -- 3. adding to the selection ------------------------------------------------------------


func _select() -> void:
	var parts: Array = _parts_on_screen(3)
	if not _check("three parts of the car on the screen apart (%d)" % parts.size(), parts.size() >= 3):
		return
	var ids: Array = parts.map(func(p: Array) -> int: return int(p[0]))
	_builder.clear_selection()
	await _frames(4)
	_presses = 0
	await _tap(parts[0][1])
	_check("a tap selects one (%d)" % _builder.selection.size(), _builder.selection.size() == 1
		and _builder.selection.has(ids[0]))
	await _tap(_middle(_named("phone_select")))
	var adding: bool = bool(_verbs.get("adding"))
	var hint: String = str((_phone.call("state") as Dictionary).get("hint", ""))
	_check("Select, tapped while lit, adds by tap: the line says \"%s\"" % hint,
		adding and "add" in hint and "Select" in hint)
	await _tap(parts[1][1])
	await _tap(parts[2][1])
	_check("two more tapped: %d selected (%s)" % [_builder.selection.size(), ids],
		_builder.selection.size() == 3 and ids.all(func(id: int) -> bool: return _builder.selection.has(id)))
	await _shot("3_three_selected")
	hint = str((_phone.call("state") as Dictionary).get("hint", ""))
	_check("the line says how many: \"%s\"" % hint, hint.begins_with("3 selected"))
	var taps: int = _presses
	# Painted: Colour and a swatch.
	var code: int = _paint_code()
	await _tap(_middle(_named("phone_colour")))
	await _frames(10)
	var swatch: Control = _phone.call("controls_by_name").get("phone_swatch_%d" % code) as Control
	if swatch != null:
		await _tap(_middle(swatch))
		await _frames(10)
	var painted: int = ids.filter(func(id: int) -> bool:
		return _world.get_brick(id) != null and _world.get_brick(id).color_code == code).size()
	_check("three painted in %d taps (the desktop's 4; at most 8): %d of 3" % [_presses, painted],
		painted == 3 and _presses <= 8)
	# One taken out, a tap on nothing, Select again.
	await _tap(parts[1][1])
	_check("a part tapped again is taken out (%d selected)" % _builder.selection.size(),
		_builder.selection.size() == 2 and not _builder.selection.has(ids[1]))
	await _tap(_empty_spot())
	_check("a tap on nothing keeps them (%d selected)" % _builder.selection.size(),
		_builder.selection.size() == 2)
	await _tap(_middle(_named("phone_select")))
	_check("Select again ends it", not bool(_verbs.get("adding")))
	await _tap(parts[2][1])
	_check("then a tap selects one alone (%d)" % _builder.selection.size(),
		_builder.selection.size() == 1 and _builder.selection.has(ids[2]))
	_check("taps before Colour: %d (a part, Select, two parts)" % taps, taps == 4)
	_builder.clear_selection()


## A colour none of the parts has, from the Colour sheet's.
func _paint_code() -> int:
	for code: int in [1, 4, 2, 14]:
		var any: bool = false
		for id: int in _builder.selection:
			var brick: BrickWorld.Brick = _world.get_brick(id)
			if brick != null and brick.color_code == code:
				any = true
		if not any:
			return code
	return 1


## [param count] parts of the model, each with a point on the screen where a
## tap finds it, at least 30 points from each other: [id, point].
func _parts_on_screen(count: int) -> Array:
	var out: Array = []
	var view: Rect2 = _view().grow(-12.0 * _pt())
	var library: PartLibrary = _main.get("_library")
	for brick: BrickWorld.Brick in _world.bricks():
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var at: Vector2 = _camera.screen_of(brick.transform * mesh.bounds.get_center())
		var apart: bool = out.all(func(p: Array) -> bool:
			return (p[1] as Vector2).distance_to(at) > _pt() * 30.0)
		if apart and view.has_point(at) and _verbs.brick_at(at) == brick.id \
				and not _phone.call("covers", at):
			out.append([brick.id, at])
			if out.size() >= count:
				return out
	return out


func _empty_spot() -> Vector2:
	var view: Rect2 = _view()
	for k: int in 20:
		var at := Vector2(view.position.x + view.size.x * 0.1, view.position.y + view.size.y * (0.15 + k * 0.03))
		if _verbs.brick_at(at) == 0 and not _phone.call("covers", at):
			return at
	return view.position + Vector2(10, 10) * _pt()


# -- 4. the line over the model --------------------------------------------------------------


func _line() -> void:
	_bar.say("opened Car — 61 bricks")
	await _frames(5)
	var pill: Label = _phone.get("_pill_words")
	print("    said: \"%s\"; the line reads \"%s\"" % [_bar.status_text(), pill.text])
	await create_timer(6.0).timeout
	_shell.run("pose")
	await _frames(30)
	var column: Control = _main.get("_tool_column")
	var panel: Rect2 = column.get_global_rect() if column != null and column.is_visible_in_tree() else Rect2()
	var box: Control = _phone.get("_pill")
	var now: String = pill.text
	print("    six seconds on, Motions open (%s): the line reads \"%s\" at %s" % [panel, now,
		box.get_global_rect() if box.visible else "nowhere"])
	await _shot("4_line_over_motions")
	_check("the line no longer says what was said six seconds ago (\"%s\")" % now,
		not now.begins_with("opened Car"))
	_check("and stands clear of the panel", not box.visible or panel.size == Vector2.ZERO
		or not box.get_global_rect().intersects(panel))
	_shell.run("pose")
	await _frames(10)


# -- 5. a finger's words -------------------------------------------------------------------------


func _words() -> void:
	var mouse: RegEx = RegEx.create_from_string(MOUSE)
	# Simulate's own lines, as the panel writes them.
	for line: String in ["Driver: Crank (#9 46372), the model marks it. Click an axle or a crank to drive that instead.",
			"Driver: Earth (#15 6632), clicked. Click an axle or a crank to drive that instead.",
			"That part does not turn on anything here: click an axle or a crank.",
			"measuring — click two points; U or Esc puts the ruler away"]:
		var drawn: String = _drawn(line)
		_check("drawn for a finger: \"%s\"" % drawn, mouse.search(drawn) == null and not "taped" in drawn)
	# A part's and a set's names are names.
	for name: String in ["Hinge Plate 1 x 4 with Two Pins and Click Hinge", "Click & Build Watch",
			"We Just Click", "Brick 1 x 2 with Click Rotation Pin"]:
		_check("a name kept: \"%s\"" % _drawn(name), _drawn(name) == name)
	# The ruler: what the bar says, as drawn.
	_shell.run("measure")
	await _frames(20)
	var ruler: String = _bar.status_text()
	_check("the ruler out, the bar says \"%s\" (drawn \"%s\")" % [ruler, _drawn(ruler)],
		mouse.search(_drawn(ruler)) == null)
	_shell.run("measure")
	await _frames(10)
	# Simulate's panel open on the car, and every line on the screen.
	_shell.run("simulate")
	for _n: int in 300:
		await process_frame
	await _shot("5_simulate")
	var said: Array[String] = []
	_sweep(root, mouse, said)
	_check("every line drawn with Simulate open says no click, right-click or hover (%s)"
		% ("none" if said.is_empty() else "; ".join(said.slice(0, 6))), said.is_empty())
	_shell.run("simulate")
	await _frames(10)


## What [param text] is drawn as: through the TranslationServer, as a
## control draws its words.
func _drawn(text: String) -> String:
	return String(TranslationServer.translate(text))


func _sweep(node: Node, mouse: RegEx, said: Array[String]) -> void:
	var control: Control = node as Control
	if control != null and not control.is_visible_in_tree():
		return
	var text: String = ""
	if node is Label:
		text = (node as Label).text
	elif node is Button:
		text = (node as Button).text
	elif node is RichTextLabel:
		text = (node as RichTextLabel).get_parsed_text()
	if not text.is_empty():
		var drawn: String = _drawn(text) if control.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else text
		if mouse.search(drawn) != null:
			said.append("%s \"%s\"" % [node.name, drawn.left(70)])
	for child: Node in node.get_children():
		_sweep(child, mouse, said)


# -- the rest ------------------------------------------------------------------------------


## The controls a press at [param at] could reach, the last drawn last:
## each one's path, its layer and its filter.
func _who_at(at: Vector2) -> Array:
	var out: Array = []
	var walk: Array[Node] = [root]
	while not walk.is_empty():
		var node: Node = walk.pop_front()
		for child: Node in node.get_children():
			walk.append(child)
		var control := node as Control
		if control == null or not control.is_visible_in_tree() \
				or control.mouse_filter == Control.MOUSE_FILTER_IGNORE \
				or not control.get_global_rect().has_point(at):
			continue
		var layer: CanvasLayer = null
		var up: Node = control.get_parent()
		while up != null and layer == null:
			layer = up as CanvasLayer
			up = up.get_parent()
		out.append("%s (layer %d, %s)" % [String(control.get_path()).trim_prefix("/root/").right(60),
			layer.layer if layer != null else 0,
			["stop", "pass", "ignore"][control.mouse_filter]])
	return out


func _named(name: String) -> Control:
	return _phone.call("controls_by_name").get(name) as Control


func _open(path: String) -> bool:
	var real: String = ProjectSettings.globalize_path(path)
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", real)
	for _n: int in 900:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0 and not _store.laying:
			break
	await _frames(40)
	_camera.frame(_world_box(), 1.1)
	await _settle()
	return _check("%s open (%d parts)" % [path.get_file(), _world.brick_count()], _world.brick_count() > 0)


func _world_box() -> AABB:
	var box := AABB()
	var first: bool = true
	for id: int in _world._bricks:
		var at: Vector3 = _world.get_brick(id).transform.origin
		box = AABB(at, Vector3.ZERO) if first else box.expand(at)
		first = false
	return box.grow(40.0)


func _middle(control: Control) -> Vector2:
	return control.get_global_rect().get_center() if control != null else Vector2(-100, -100)


func _tap(at: Vector2) -> void:
	_presses += 1
	_touch(0, at, true)
	await _frames(2)
	_touch(0, at, false)
	await _frames(8)


func _touch(index: int, at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _pt() -> float:
	return Phone.per_point(root)


func _view() -> Rect2:
	return (_main.call("model_cover") as Dictionary)["view"]


func _sheet() -> String:
	return str((_phone.call("state") as Dictionary).get("sheet", "")) if _phone != null else ""


func _settle() -> void:
	var last := Transform3D()
	var still: int = 0
	for _n: int in 600:
		await process_frame
		if _camera.global_transform.is_equal_approx(last):
			still += 1
			if still >= 3:
				break
		else:
			still = 0
		last = _camera.global_transform
	await RenderingServer.frame_post_draw


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out.path_join(name + ".png"))
	if image != null and image.save_png(path) == OK:
		print("    picture: %s" % path)


func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _finish() -> void:
	print("")
	print("smalls2_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
