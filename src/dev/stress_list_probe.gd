## View, Stress's panel in the real scene, as a person uses it: its legend,
## its count of the joints past their working load and near it, and the
## weakest, worst first, stepped through (bench/results/walk180-2026-10-23,
## A9: on 10297-1's 3,164 parts the view drew everything pale, with no
## legend, no count and no list).
##
## On a model whose answers are worked out by hand — a 2x10 plate loaded at
## its tip on a column of 1x1s (its root and the 1x1s under it red), the same
## on 2x2s (plain), and a 2x10 lying on a tile past it (it falls) — the count
## is what weakest_joints says and what the weighing holds, the first row is
## the piece that falls and then the weakest joint, and each row clicked, and
## Next and Previous, select its part and bring it into view with what holds
## it, saying why in the words pointing at it says, and what would fix it.
## Close turns Stress off. Then 10297-1 reads "0 past working load · 0 near
## it" as weakest_joints does, its weakest joint first; each is pictured.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . --resolution 1400x900 \
##     --script src/dev/stress_list_probe.gd
##
## With `-- time FILE RUNS` it checks nothing: it opens FILE and times Stress
## turned on RUNS times, from the press to the weighing drawn, and the
## drawing alone (StressView.show_report) — for a checkout without the
## panel too, so the two can be compared. Pictures in shots/stress_list/.
extends SceneTree

const SHOTS := "res://shots/stress_list"
const HOTEL := "res://vendor/omr/files/10297-1.mpd"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _shell: Shell
var _store: ModelStore
var _socket: CommandSocket


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_store = _main.get("_store")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_main.call("clear_model")
	await _frames(10)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "time":
		await _time(args[1], int(args[2]) if args.size() > 2 else 5)
		quit(0)
		return
	await _weak_model()
	await _hotel()
	print("")
	if _failures == 0:
		print("stress list: View, Stress counts what is past its working load and near it as "
			+ "weakest_joints does, lists the weakest first, and each step selects and frames "
			+ "its part and says why; the hotel reads 0 past working load")
	else:
		print("stress list: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _weak_model() -> void:
	print("a loaded cantilever on 1x1s, on 2x2s, and a plate on a touch past it")
	var weak: Array = _column_and_cantilever("3005", Vector2(0, 0), 0.0)
	var held: Array = _column_and_cantilever("3003", Vector2(10, 130), 120.0)
	var touch_column: Array = []
	var top: float = _top(_put("3832", 80, 0.0, -130, 71))
	for _n: int in 5:
		var id: int = _put("3003", 0, top, -130, 71)
		touch_column.append(id)
		top = _top(id)
	var falls: int = _put("3832", 80, _top(_put("3068b", 0, top, -130, 71)), -130, 4)
	await _frames(5)
	_camera.frame(AABB(Vector3(-60, 0, -170), Vector3(300, 170, 360)), 1.1)
	await _frames(30)
	var panel: Variant = _panel()
	_check("before Stress, no stress panel shows",
		panel == null or not (panel as Control).visible)
	_shell.run("stress")
	await _drawn()
	var stress: StressView = _shell.stress
	panel = _panel()
	if panel == null:
		_check("with Stress on, a panel lists the weak joints (there is none)", false)
		return
	_check("with Stress on, its panel shows, under the view cube and clear of it",
		(panel as Control).visible and (panel as Control).get_global_rect().position.y
		>= (_main.get("_gizmo") as Control).get_global_rect().end.y)
	var shown: Dictionary = panel.call("fields")
	var counted: Array = _counted(stress.report)
	var said: String = await _say("weakest_joints", {})
	var heard: String = _count_in(said)
	_check("its count: \"%s\", %d red and %d amber as the weighing has them, as weakest_joints says: \"%s\""
		% [shown["count"], counted[0], counted[1], heard], shown["count"] == "%d past working load · %d near it"
		% counted and heard == shown["count"] and counted[0] == 6)
	var entries: Array = panel.get("entries")
	var plate: int = weak[1]
	_check("the first row is the plate that falls off its touch: %s" % _first_row(shown),
		not entries.is_empty() and entries[0].get("id") == falls and entries[0].get("joint") == null)
	var weakest: int = _weakest_joint(stress.report)
	var first_joint: int = 0
	for one: Variant in entries:
		if one.get("joint") != null:
			first_joint = one.get("id")
			break
	_check("...then the weakest joint (#%d, the cantilever's root #%d), as weakest_joints lists it first: %s"
		% [weakest, plate, said.get_slice("the weakest:\n", 1).get_slice("\n", 1).strip_edges()],
		first_joint == weakest and said.get_slice("the weakest:\n", 1).get_slice("\n", 0).contains(
		"#%d and what is with it" % falls) and said.get_slice("the weakest:\n", 1).get_slice("\n", 1)
		.strip_edges().begins_with("#%d " % weakest))
	var ordered: bool = true
	for n: int in range(1, entries.size()):
		if float(entries[n].get("margin")) < float(entries[n - 1].get("margin")) - 0.0001:
			ordered = false
	var listed: Dictionary = {}
	for one: Variant in entries:
		listed[one.get("id")] = true
	var plain_listed: int = 0
	for id: int in (held[0] as Array) + [held[1]]:
		if listed.has(id) and stress.margin_of(id) < StressView.CLOSE:
			plain_listed += 1
	_check("worst first, every red and amber one listed (%d rows), and nothing on the 2x2s listed weak"
		% entries.size(), ordered and listed.has(plate) and plain_listed == 0
		and entries.size() >= counted[0] + counted[1])
	await _shot("weak")

	print("stepping through it")
	var named: Dictionary = _shell.controls_by_name()
	await _click(named.get("stress_row_0"))
	shown = panel.call("fields")
	var in_view: bool = await _framed(entries[0])
	_check("clicking the first row selects the plate that falls and brings it into view: %s, %s"
		% [shown["why"], shown["fix"]], _selected_is(entries[0]) and in_view
		and shown["why"] == stress.words(falls) and shown["fix"].contains("touch")
		and shown["at"] == "1 of %d" % entries.size())
	await _shot("first_row")
	var stepped: int = 0
	var all_framed: bool = true
	for n: int in range(1, entries.size()):
		await _click(_shell.controls_by_name().get("stress_next"))
		stepped += 1
		in_view = await _framed(entries[n])
		if not (_selected_is(entries[n]) and in_view
				and (panel.call("fields") as Dictionary)["why"] == stress.words(entries[n].get("id"))):
			all_framed = false
			print("    step %d: #%d not selected and framed" % [n, entries[n].get("id")])
	_check("Next steps through all %d, each selected and in view with what holds it, saying what pointing at it says"
		% (stepped + 1), all_framed and stepped == entries.size() - 1)
	await _click(_shell.controls_by_name().get("stress_next"))
	_check("...and on past the last, back to the first", _selected_is(entries[0]))
	await _click(_shell.controls_by_name().get("stress_previous"))
	_check("Previous goes back, to the last", _selected_is(entries[-1]))
	var at: int = entries.map(func(one: Variant) -> int: return one.get("id")).find(plate)
	await _click(_shell.controls_by_name().get("stress_row_%d" % at))
	shown = panel.call("fields")
	# With nothing selected, as the status bar says the selection first.
	_select({})
	await _point_at(plate)
	var line: String = str((_shell.status.fields() as Dictionary)["line"])
	_check("the root's row says why as pointing at it does: \"%s\" / \"%s\"; and its fix: \"%s\""
		% [shown["why"], line, shown["fix"]], shown["why"] == line and line.contains("on 1 stud, margin 0.7")
		and shown["fix"].begins_with("It needs 1.4 times the hold it has: brace it, give it more studs"))
	await _shot("root")

	print("a change while it is on")
	_select({falls: true})
	_builder.remove_selection()
	_main.call("_on_model_edited")
	await _redrawn(entries.size())
	shown = panel.call("fields")
	counted = _counted(stress.report)
	_check("the plate that fell taken off, the count and the list follow: \"%s\"" % shown["count"],
		shown["count"] == "%d past working load · %d near it" % counted and counted[0] == 5
		and not (panel.get("entries") as Array).map(func(one: Variant) -> int: return one.get("id"))
			.has(falls))

	print("Close")
	await _click(_shell.controls_by_name().get("stress_close"))
	await _frames(5)
	_check("Close turns Stress off: the panel gone, every part its own colour, the menu unticked",
		not (panel as Control).visible and not _world.is_stressed() and _shell.ticked("stress") == 0)


func _hotel() -> void:
	print("10297-1 Boutique Hotel, which stands")
	if not FileAccess.file_exists(HOTEL):
		_check("%s is here" % HOTEL, false)
		return
	await _open(HOTEL)
	var began: int = Time.get_ticks_msec()
	_shell.run("stress")
	await _drawn()
	var took: int = Time.get_ticks_msec() - began
	var stress: StressView = _shell.stress
	var panel: Variant = _panel()
	if panel == null:
		_check("a panel lists the weak joints (there is none)", false)
		return
	var shown: Dictionary = panel.call("fields")
	var said: String = await _say("weakest_joints", {})
	_check("%d parts, %d joints weighed, Stress drawn %d ms after the press: \"%s\", as weakest_joints says: \"%s\""
		% [_world.brick_count() - _store.scenery.size(), stress.report.margins.size(), took,
		shown["count"], _count_in(said)], shown["count"] == "0 past working load · 0 near it"
		and _count_in(said) == shown["count"] and _counted(stress.report) == [0, 0])
	var entries: Array = panel.get("entries")
	var weakest: int = _weakest_joint(stress.report)
	_check("the list is its %d weakest, the weakest first (#%d, margin %s): %s" % [entries.size(),
		weakest, StressView.margin_words(stress.margin_of(weakest)), _first_row(shown)],
		entries.size() == 8 and entries[0].get("id") == weakest
		and said.get_slice("the weakest:\n", 1).strip_edges().begins_with("#%d " % weakest))
	await _shot("hotel")
	var framed: int = 0
	for n: int in 3:
		await _click(_shell.controls_by_name().get("stress_next"))
		var in_view: bool = await _framed(entries[n])
		if _selected_is(entries[n]) and in_view:
			framed += 1
		await _shot("hotel_%d" % (n + 1))
	shown = panel.call("fields")
	_check("Next three times: each selected and in view (%d of 3), with no fix to make: \"%s\""
		% [framed, shown["why"]], framed == 3 and shown["fix"] == "" and not shown["why"].is_empty())
	_shell.run("stress")
	await _frames(5)


## Stress on [param runs] times over [param path]: from the press to the
## weighing drawn, and the drawing alone.
func _time(path: String, runs: int) -> void:
	await _open(path)
	var pressed: Array = []
	var drawing: Array = []
	for n: int in runs:
		var began: int = Time.get_ticks_usec()
		_shell.run("stress")
		await _drawn(0)
		pressed.append((Time.get_ticks_usec() - began) / 1000.0)
		var report: Stability.Report = _shell.stress.report
		var at: int = Time.get_ticks_usec()
		_shell.stress.show_report(report)
		drawing.append((Time.get_ticks_usec() - at) / 1000.0)
		await _frames(10)
		_shell.run("stress")
		await _frames(30)
	pressed.sort()
	drawing.sort()
	print("stress time: %s, %d parts, %d runs: on in %s ms (median %.0f), drawn in %s ms (median %.1f)"
		% [path.get_file(), _world.brick_count(), runs, ", ".join(pressed.map(func(ms: float) -> String:
		return "%.0f" % ms)), pressed[runs / 2], ", ".join(drawing.map(func(ms: float) -> String:
		return "%.1f" % ms)), drawing[runs / 2]])


# -- reading it --------------------------------------------------------------------


func _panel() -> Variant:
	return _shell.stress.get("panel")


## [past, near] as the weighing has them, counted here: each joint that
## alone holds what is past it under a margin of 1 or of 2, and each piece on
## a touch past it.
func _counted(report: Stability.Report) -> Array:
	var past: int = 0
	var near: int = 0
	for id: Variant in report.margins:
		if _store.scenery.has(int(id)) or _world.get_brick(int(id)) == null:
			continue
		var ratio: float = (report.margins[id] as Balance.JointLoad).ratio
		if ratio > 1.0:
			past += 1
		elif ratio > 0.5:
			near += 1
	for risk: Stability.Risk in report.risks:
		if risk.kind == "rests on a touch":
			past += 1
	return [past, near]


func _weakest_joint(report: Stability.Report) -> int:
	var found: int = 0
	var most: float = -1.0
	for id: Variant in report.margins:
		if _store.scenery.has(int(id)) or _world.get_brick(int(id)) == null:
			continue
		var ratio: float = (report.margins[id] as Balance.JointLoad).ratio
		if ratio > most:
			most = ratio
			found = int(id)
	return found


func _count_in(said: String) -> String:
	var found: RegExMatch = RegEx.create_from_string("\\d+ past working load · \\d+ near it").search(said)
	return found.get_string() if found != null else ""


func _first_row(shown: Dictionary) -> String:
	return str((shown["rows"] as Array)[0]) if not (shown["rows"] as Array).is_empty() else "(none)"


func _selected_is(one: Variant) -> bool:
	var ids: Array = one.get("ids")
	if _builder.selection.size() != ids.size():
		return false
	for id: Variant in ids:
		if not _builder.selection.has(int(id)):
			return false
	return true


## In view: the camera turned on the part and what holds it, and the part's
## middle in the room the model is seen in, clear of the panel.
func _framed(one: Variant) -> bool:
	var box: AABB = _box(int(one.get("id")))
	if int(one.get("around")) > 0 and not _store.scenery.has(int(one.get("around"))):
		box = box.merge(_box(int(one.get("around"))))
	for id: Variant in one.get("ids"):
		box = box.merge(_box(int(id)))
	var aimed: bool = _camera.focus_now().distance_to(box.get_center()) < 1.0
	# Where it is going, not on its way there.
	for _n: int in 600:
		if _camera.focus.distance_to(_camera.focus_now()) < 0.5 \
				and absf(_camera.distance - _camera.distance_now()) < 0.5:
			break
		await process_frame
	var seen: Rect2 = _camera.seen_rect()
	var panel: Rect2 = (_panel() as Control).get_global_rect()
	var middle: Vector3 = _box(int(one.get("id"))).get_center()
	var at: Vector2 = _camera.unproject_position(middle)
	return aimed and not _camera.is_position_behind(middle) and seen.has_point(at) \
		and not panel.has_point(at)


func _box(id: int) -> AABB:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	return (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()


func _say(tool: String, arguments: Dictionary) -> String:
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": 1,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	return text


# -- the model ------------------------------------------------------------------


func _open(path: String) -> void:
	_main.call("clear_model")
	await _frames(10)
	var result: Dictionary = _store.open_text(FileAccess.get_file_as_string(path),
		path.get_file().get_basename())
	(_main.get("_bar") as ModelBar).opened.emit(int(result["placed"]))
	await _frames(60)
	# The status bar's own weighing of what was opened, done before Stress
	# asks for its own.
	for _n: int in 2000:
		await process_frame
		if int(_main.get("_stability_revision")) == _world.revision and not bool(_main.get("_weighing")):
			break


## A column of [param part] five high at [param middle] (x, z), a 2x10 plate
## out along x from its top by its end studs, and six 2x2 bricks on the
## plate's far end: [the column bottom up, the plate, the load].
func _column_and_cantilever(part: String, middle: Vector2, z_plate: float) -> Array:
	var column: Array = []
	var top: float = 0.0
	for _n: int in 5:
		var id: int = _put(part, middle.x, top, middle.y, 71)
		column.append(id)
		top = _top(id)
	var plate: int = _put("3832", 90, top, z_plate + 10.0, 1)
	top = _top(plate)
	var load: Array = []
	for _n: int in 6:
		var id: int = _put("3003", 170, top, z_plate + 10.0, 14)
		load.append(id)
		top = _top(id)
	return [column, plate, load]


func _put(part_id: String, x: float, bottom: float, z: float, colour: int) -> int:
	var part: Lbm.PartMesh = _library.mesh_for(part_id)
	var info: PartLibrary.PartInfo = _library.parts.get(part_id)
	var basis := Basis.IDENTITY
	if info.size.x < info.size.z:
		basis = Basis(Vector3.UP, PI * 0.5)
	var box: AABB = (Transform3D(basis, Vector3.ZERO) * part.bounds).abs()
	var middle: Vector3 = box.get_center()
	var at := Transform3D(basis, Vector3(roundf(x - middle.x), roundf(bottom - box.position.y),
		roundf(z - middle.z)))
	var id: int = _world.add_brick(part_id, colour, at)
	_builder.register(id, part_id, at)
	return id


func _top(id: int) -> float:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	var box: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
	return box.end.y - (4.0 if _library.parts[brick.part_id].stud_count > 0 else 0.0)


# -- the person -------------------------------------------------------------------


## Until the weighing Stress asked for has come in and been drawn.
func _drawn(settle: int = 10) -> void:
	for _n: int in 3000:
		await process_frame
		if _shell.stress.report != null and not Working.is_busy():
			break
	await _frames(settle)


## Until the panel lists something other than [param was] rows, after a change.
func _redrawn(was: int) -> void:
	for _n: int in 600:
		await process_frame
		var panel: Variant = _panel()
		if panel != null and (panel.get("entries") as Array).size() != was \
				and not bool(_main.get("_weighing")):
			break
	await _frames(10)


func _select(ids: Dictionary) -> void:
	_builder.selection.clear()
	for id: Variant in ids:
		_builder.selection[id] = true
	_builder.selection_changed.emit(_builder.selection.size())


## A click on [param control] where it is on the screen, as a hand makes it.
func _click(control: Variant) -> void:
	if not control is Control or not (control as Control).is_visible_in_tree():
		print("    no such control to click")
		return
	var at: Vector2 = (control as Control).get_global_rect().get_center()
	var scale: float = root.get_final_transform().get_scale().x
	Input.warp_mouse(at * scale)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at * scale
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(20)


## The pointer over [param id]'s middle, the system's own, as a hand moves it.
func _point_at(id: int) -> void:
	var box: AABB = _box(id)
	var at: Vector2 = _camera.unproject_position(box.get_center() + Vector3(0, box.size.y * 0.5, 0))
	var scale: float = root.get_final_transform().get_scale().x
	Input.warp_mouse(at * scale)
	var event := InputEventMouseMotion.new()
	event.position = at * scale
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var path: String = "%s/%s.png" % [SHOTS, name]
	image.save_png(ProjectSettings.globalize_path(path))
	print("    picture: shots/stress_list/%s.png" % name)
