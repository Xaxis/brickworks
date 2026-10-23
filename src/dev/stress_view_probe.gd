## View, Stress in the real scene, as a person uses it: the View menu's
## Stress turned on over a column of 1x1s carrying a loaded 2x10 cantilever
## and the same cantilever on a column of 2x2s. The first reads red at its
## root and every 1x1 under it, the second plain, everything else faded in
## its own colour. Pointing at the plate says what it carries and on what,
## its menu offers Ask Claude to brace this and the plain plate's does not,
## and that asks about the joint with its numbers written in. Off again,
## every part is its own colour and nothing was painted. Then two real sets,
## which stand, read one part red at most, and the big model a session
## designed shows where it leans on its walls; each pictured, and what reads
## red seen through the rest.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . --resolution 1400x900 \
##     --script src/dev/stress_view_probe.gd
##
## Pictures in shots/stress/.
extends SceneTree

const SHOTS := "res://shots/stress"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _shell: Shell
var _store: ModelStore


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _check_on(ok: bool, what: String) -> bool:
	if not ok:
		_check(what, false)
	return ok


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
	_main.call("clear_model")
	await _frames(10)
	await _cantilevers()
	await _sets()
	print("")
	if _failures == 0:
		print("stress view: View, Stress tints the loaded cantilever's root red and the 2x2s' "
			+ "plain, says what the plate carries, offers bracing only where it is weak, "
			+ "paints nothing, and shows a real set and a big model")
	else:
		print("stress view: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _cantilevers() -> void:
	print("a loaded cantilever on 1x1s, and on 2x2s")
	var weak: Array = _column_and_cantilever("3005", Vector2(0, 0), 0.0)
	var held: Array = _column_and_cantilever("3003", Vector2(10, 130), 120.0)
	var plate: int = weak[1]
	var plain_plate: int = held[1]
	var colours: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		colours[brick.id] = brick.color_code
	await _frames(5)
	_camera.frame(AABB(Vector3(-40, 0, -40), Vector3(260, 170, 220)), 1.1)
	await _frames(30)
	var revision: int = _world.revision

	var view: PopupMenu = _view_menu()
	_check("the View menu has Stress, under X-ray, unticked",
		view != null and _shell.item_index(view, "stress") == _shell.item_index(view, "xray") + 1
		and _shell.ticked("stress") == 0 and _shell.can("stress"))
	_shell.run("stress")
	await _tinted()
	var stress: StressView = _shell.stress
	_check("...and on, it is ticked and the model is weighed (%d joints)" % (
		stress.report.margins.size() if stress.report != null else -1),
		_shell.ticked("stress") == 1 and stress.report != null and _world.is_stressed())
	var tints: Dictionary = _world.stressed_ids()
	_check("the plate on the 1x1s reads red at its root (margin %s)" % StressView.margin_words(
		stress.margin_of(plate)), tints.get(plate) == StressView.RED)
	var column_red: int = 0
	for n: int in range(1, (weak[0] as Array).size()):
		if tints.get(weak[0][n]) == StressView.RED:
			column_red += 1
	_check("...and the 1x1s it stands on, each carrying it on one stud (%d of %d)" % [column_red,
		(weak[0] as Array).size() - 1], column_red == (weak[0] as Array).size() - 1)
	var plain: int = 0
	for id: int in (held[0] as Array) + [plain_plate] + (held[2] as Array):
		if not tints.has(id):
			plain += 1
	_check("the same cantilever on 2x2s reads plain, every part (%d of %d; its root's margin %s)"
		% [plain, (held[0] as Array).size() + 1 + (held[2] as Array).size(),
		StressView.margin_words(stress.margin_of(plain_plate))], plain == (held[0] as Array).size()
		+ 1 + (held[2] as Array).size())
	await _shot("cantilevers")

	print("pointing at the plates")
	(_shell.status.message as Label).text = ""
	await _point_at(plate)
	var line: String = str((_shell.status.fields() as Dictionary)["line"])
	_check("pointing at the red plate, the status bar says what it carries: \"%s\"" % line,
		line.contains("Plate 2 x 10: carries") and line.contains("on 1 stud, margin 0.7"))
	await _shot("pointing")
	await _point_at(plain_plate)
	line = str((_shell.status.fields() as Dictionary)["line"])
	_check("...and at the plain one: \"%s\"" % line, line.contains("on 4 studs, margin"))

	print("its menu")
	_select({plate: true})
	_main.call("set_assistant", false)
	_shell.open_context(Vector2(600, 400))
	await _frames(3)
	_check("with the assistant off (Settings), no part's menu asks Claude anything",
		_shell.item_index(_shell.context, "brace") == -1)
	_shell.context.hide()
	_main.call("set_assistant", true)
	await _frames(5)
	_shell.open_context(Vector2(600, 400))
	await _frames(3)
	var offered: int = _shell.item_index(_shell.context, "brace")
	_check("a red part's menu offers Ask Claude to brace this, under Ask Claude about this… (%d)"
		% offered, offered != -1 and offered == _shell.item_index(_shell.context, "ask_claude") + 1)
	_shell.context.hide()
	_select({plain_plate: true})
	_shell.open_context(Vector2(600, 400))
	await _frames(3)
	_check("a plain part's does not", _shell.item_index(_shell.context, "brace") == -1)
	_shell.context.hide()
	_select({plate: true})
	if _check_on(_shell.assistant_shown, "the assistant is on"):
		_shell.run("brace")
		await _frames(10)
		var chat: ChatPanel = _main.get("_chat")
		var asked: String = (chat.get("_input") as TextEdit).text
		_check("Ask Claude to brace this selects the plate and the 1x1 under it, and asks about "
			+ "them with the joint's numbers: \"%s\"" % asked, _builder.selection.size() == 2
			and _builder.selection.has(plate) and _builder.selection.has(weak[0][4])
			and asked.begins_with("Brace this: the Plate 2 x 10 carries")
			and asked.contains("margin 0.7"))
		await _shot("brace")
		chat.stop_asking_about()
		(chat.get("_input") as TextEdit).text = ""
	_main.call("set_assistant", false)
	_select({})

	print("off again")
	_shell.run("stress")
	await _frames(10)
	var painted: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if colours.get(brick.id, -1) != brick.color_code:
			painted += 1
	var own: BrickWorld.Brick = _world.get_brick(plate)
	_check("off, nothing is tinted or faded and the plate is drawn its own blue",
		not _world.is_stressed() and _world.stressed_ids().is_empty() and _world._shown_colour(
		own, _library.color(own.color_code)).is_equal_approx(_library.color(own.color_code).shown))
	_check("no part was painted (%d), and the model's revision never moved (%d)" % [painted,
		_world.revision - revision], painted == 0 and _world.revision == revision)
	await _shot("off")


## Real sets and the big model a session designed, as File, Open opens
## each, with Stress on: how many read red and amber, and each pictured.
## The sets stand, so one part red at most: 21318-1's is a branch of leaves
## 6 studs out on a bar in one side stud, 9 g, three quarters of the stud's
## working load and a quarter of where it lets go. Orthanc's inner cores
## stand on 1x1 round columns and lean on the walls round them, held by no
## joint.
func _sets() -> void:
	print("real sets, and the big model")
	for each: Array in [["res://vendor/omr/files/75969-1.mpd", 0],
			["res://vendor/omr/files/21318-1.mpd", 1], ["res://models/orthanc.ldr", -1]]:
		var path: String = each[0]
		if not FileAccess.file_exists(path):
			_check("%s is here" % path, false)
			continue
		_main.call("clear_model")
		await _frames(10)
		var result: Dictionary = _store.open_text(FileAccess.get_file_as_string(path),
			path.get_file().get_basename())
		(_main.get("_bar") as ModelBar).opened.emit(int(result["placed"]))
		await _frames(60)
		var began: int = Time.get_ticks_msec()
		_shell.run("stress")
		await _tinted()
		var red: int = 0
		for id: int in _world.stressed_ids():
			if _world.stressed_ids()[id] == StressView.RED:
				red += 1
		var parts: int = _world.brick_count() - _store.scenery.size()
		_check("%s: %d parts, %d joints weighed, %d red and %d amber, tinted %d ms after Stress"
			% [path.get_file(), parts, _shell.stress.report.margins.size() if _shell.stress.report
			!= null else -1, red, _world.stressed_ids().size() - red, Time.get_ticks_msec() - began],
			_shell.stress.report != null and (int(each[1]) < 0 or red <= int(each[1])))
		await _frames(20)
		await _shot(path.get_file().get_basename())
		if red > 0:
			# What reads red inside it, seen through the rest (X-ray).
			var inside: Dictionary = {}
			for id: int in _world.stressed_ids():
				inside[id] = true
			_select(inside)
			_shell.see_inside.set_xray(true)
			_camera.frame(_main.call("_selection_bounds"), 1.6)
			await _frames(30)
			await _shot(path.get_file().get_basename() + "_inside")
			_shell.see_inside.set_xray(false)
			_select({})
		_shell.run("stress")
		await _frames(10)


# -- the model ------------------------------------------------------------------


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


func _view_menu() -> PopupMenu:
	for button: MenuButton in _shell.get("_menus"):
		if button.text == "View":
			return button.get_popup()
	return null


## Until the weighing Stress asked for has come in and been drawn.
func _tinted() -> void:
	for _n: int in 3000:
		await process_frame
		if _shell.stress.report != null and not Working.is_busy():
			break
	await _frames(10)


func _select(ids: Dictionary) -> void:
	_builder.selection.clear()
	for id: Variant in ids:
		_builder.selection[id] = true
	_builder.selection_changed.emit(_builder.selection.size())


## The pointer over [param id]'s middle, the system's own, as a hand moves it.
func _point_at(id: int) -> void:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	var box: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
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
	print("    picture: shots/stress/%s.png" % name)
