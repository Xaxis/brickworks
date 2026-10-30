## File, Compare with… and Versions…' Compare, as a person uses them: a model
## of 65 parts saved, then 3 parts added, 2 taken off, 1 moved 2 studs, 1
## turned 90° and 1 recoloured, and compared with the save. Pictures before,
## during and after in shots/compare/.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
##     --resolution 1400x900 --script src/dev/compare_probe.gd
##
## And at a laptop's size: PROBE_SIZE=1280x720 tools/probe.sh compare_probe.
##
## What counts: the panel's counts are exactly 3 added, 2 removed, 2 moved
## and 1 recoloured; each change is drawn in its colour, read from what the
## world tints and the ghosts it draws, and from the pixels where the view
## frames it; Next visits all 8; Esc puts every part's look and the view back
## as they were, the history as deep and the model still unsaved. Ten 1 x 1
## bricks in a row with one moved to the end are 1 moved. Inside a
## sub-assembly being edited only that is compared, and the panel says so. A
## 5,000-part model compares in under a second. A comparison that found
## nothing fails every count.
extends SceneTree

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Shell
var _compare: CompareView
var _failures: int = 0
var _tag: String = ""


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
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_compare = _shell.compare
	var size: Vector2i = DisplayServer.window_get_size()
	_tag = "%dx%d" % [size.x, size.y]
	await _eight_changes()
	await _ten_in_a_row()
	await _inside_a_sub_assembly()
	await _five_thousand()
	print("")
	print("compare: %s" % ("3 added, 2 removed, 2 moved and 1 recoloured, each in its colour, "
		+ "stepped through and put back; one moved of ten alike; inside a sub-assembly; 5,000 "
		+ "parts in under a second" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- 65 parts and eight changes ------------------------------------------------


func _eight_changes() -> void:
	print("eight changes, at %s" % _tag)
	_main.call("clear_model")
	await _frames(6)
	# A floor of sixty 2 x 2 bricks, ten by six, and five parts on it.
	var colours: Array[int] = [15, 71, 19, 72]
	for row: int in 6:
		for column: int in 10:
			_put("3003", colours[(row + column) % colours.size()], column * 40.0 - 180.0, 0.0,
				row * 40.0 - 100.0)
	var turned: int = _put("3004", 4, -100.0, 24.0, -60.0)
	var moved: int = _put("3001", 1, -20.0, 24.0, 20.0)
	var painted: int = _put("3003", 14, 100.0, 24.0, -60.0)
	var gone: Array[int] = [_put("3003", 2, 140.0, 24.0, 60.0), _put("3003", 2, -140.0, 24.0, 60.0)]
	_builder.forget_history()
	_check("the model has %d parts" % _parts(), _parts() == 65)
	_store.save_as("Compare probe")
	await _frames(4)
	var kept: Array[ModelVersions.Version] = _store.versions()
	_check("its save is kept as a version (%d)" % kept.size(), kept.size() >= 1)
	# The eight changes, each as a person makes it: one undo step each.
	var added: Array[int] = []
	for x: float in [-180.0, 20.0, 180.0]:
		added.append(_builder.put_part("3003", 25, _at("3003", x, 24.0, 100.0)))
	for id: int in gone:
		_builder.remove_brick_id(id)
	var from: Transform3D = _world.get_brick(moved).transform
	_builder.move_bricks({moved: from.translated(Vector3(40.0, 0.0, 0.0))})
	var facing: Transform3D = _world.get_brick(turned).transform
	_builder.move_bricks({turned: Transform3D(Basis(Vector3.UP, PI * 0.5) * facing.basis,
		facing.origin)})
	_builder.paint_brick(painted, 1)
	await _frames(6)
	_check("the three added are down (%s)" % [added], not added.has(0))
	_check("one moved 2 studs, one turned 90° where it stands",
		_world.get_brick(moved).transform.origin.is_equal_approx(from.origin + Vector3(40, 0, 0))
		and not _world.get_brick(turned).transform.basis.is_equal_approx(facing.basis))
	var depth: int = _builder.history_depth()
	_check("eight steps to undo (%d)" % depth, depth == 8)
	_check("the model is not saved as it stands", _store.has_unsaved_work())
	# The view a person has, and how every part looks in it.
	_camera.frame(_bounds().grow(30.0), 1.1)
	_camera.look_from(Vector3(0.35, 0.75, 0.6).normalized())
	await _settled()
	var looks: Dictionary = _looks()
	var aim: Dictionary = _camera.aim()
	var before: Image = await _shot("before")
	# File, Compare with…, from the menu, and the newest save's Compare.
	var file_menu: PopupMenu = _shell.menu("File").get_popup()
	_check("File has Compare with…, after Versions…", _shell.menu_id("compare") >= 0
		and file_menu.get_item_index(_shell.menu_id("compare"))
			== file_menu.get_item_index(_shell.menu_id("versions")) + 1)
	file_menu.id_pressed.emit(_shell.menu_id("compare"))
	await _frames(10)
	var dialog: Dictionary = _shell.versions.page_state()
	_check("it lists the saves to compare with (%d rows, comparing %s)" % [
		(dialog["rows"] as Array).size(), dialog["comparing"]], bool(dialog["open"])
		and bool(dialog["comparing"]) and not (dialog["rows"] as Array).is_empty())
	var controls: Dictionary = _shell.controls_by_name()
	_check("each row offers Compare and, comparing, not Open", controls.has("version_compare_1")
		and not controls.has("version_open_1"))
	var began: int = Time.get_ticks_usec()
	(controls["version_compare_1"] as Button).pressed.emit()
	print("    compared in %.1f ms" % ((Time.get_ticks_usec() - began) / 1000.0))
	await _frames(10)
	_check("the panel is open over the model", _compare.is_open() and _compare.is_visible_in_tree())
	var counts: Dictionary = _compare.diff.counts() if _compare.diff != null else {}
	print("    counts %s" % [counts])
	print(_indent(_compare.said()))
	_check("3 added", int(counts.get(ModelDiff.ADDED, 0)) == 3)
	_check("2 removed", int(counts.get(ModelDiff.REMOVED, 0)) == 2)
	_check("2 moved or turned", int(counts.get(ModelDiff.MOVED, 0)) == 2)
	_check("1 recoloured", int(counts.get(ModelDiff.RECOLOURED, 0)) == 1)
	var said: Dictionary = _compare.fields()
	_check("the panel says them: %s" % [(said["counts"] as Dictionary).values()],
		str(said["counts"][ModelDiff.ADDED]).begins_with("3 added")
		and str(said["counts"][ModelDiff.REMOVED]).begins_with("2 removed")
		and str(said["counts"][ModelDiff.MOVED]).begins_with("2 moved")
		and str(said["counts"][ModelDiff.RECOLOURED]).begins_with("1 recoloured"))
	# Each drawn in its colour: the world's tints and the ghosts.
	var tints: Dictionary = _world.stressed_ids()
	var tinted_right: bool = _world.is_stressed()
	for id: int in added:
		tinted_right = tinted_right and tints.get(id) == CompareView.ADDED
	tinted_right = tinted_right and tints.get(moved) == CompareView.MOVED \
		and tints.get(turned) == CompareView.MOVED and tints.get(painted) == CompareView.RECOLOURED
	_check("added green, moved and turned amber, recoloured violet", tinted_right)
	_check("everything else faded: %d tinted of %d" % [tints.size(), _world.brick_count()],
		tints.size() == 6)
	var ghosts: BrickWorld = _compare.ghosts()
	var codes: Dictionary = {}
	if ghosts != null:
		for one: BrickWorld.Brick in ghosts.bricks():
			codes[one.color_code] = int(codes.get(one.color_code, 0)) + 1
	_check("two red ghosts where the removed stood, two faint ones where the moved were: %s"
		% [codes], int(codes.get(CompareView.REMOVED_GHOST, 0)) == 2
		and int(codes.get(CompareView.MOVED_GHOST, 0)) == 2
		and ghosts.xray_ids().size() == 2)
	_check("no ghost is a part of the model (%d parts)" % _parts(), _parts() == 66)
	await _settled()
	await _shot("compared")
	# Next, eight times: every change once, each framed, in its colour there.
	var visited: Dictionary = {}
	var hues: Dictionary = {}
	var focus_moved: int = 0
	for _n: int in 8:
		var focus: Vector3 = _camera.focus_now()
		await _click((_shell.controls_by_name()["compare_next"] as Button).get_global_rect().get_center())
		await _settled()
		var change: ModelDiff.Change = _compare.diff.changes[_compare.chosen]
		visited[_compare.chosen] = true
		if not _camera.focus_now().is_equal_approx(focus):
			focus_moved += 1
		var hue: String = await _hue_of(change)
		hues[change.kind] = hues.get(change.kind, []) + [hue]
		if _n == 0 or change.kind == ModelDiff.REMOVED:
			await _shot("step_%d_%s" % [_n + 1, change.kind])
	print("    %s; the panel says %s; compared %d time%s" % [hues, _compare.fields()["at"],
		_compare.compared, "" if _compare.compared == 1 else "s"])
	_check("compared once, with nothing changed meanwhile", _compare.compared == 1)
	_check("Next visits all 8 (%d), the view framing each (%d moved it)" % [visited.size(),
		focus_moved], visited.size() == 8 and focus_moved >= 7)
	var all_right: bool = true
	for kind: String in hues:
		for hue: String in hues[kind]:
			all_right = all_right and hue == kind
	_check("in the picture each is its colour where the view frames it", all_right
		and hues.size() == 4)
	# Esc: as it was. A part selected, which Esc would let go of next.
	_shell.verbs.select_found([moved])
	var selected: int = _builder.selection.size()
	await _key(KEY_ESCAPE)
	await _frames(6)
	_check("Esc closes it", not _compare.is_open() and not _world.is_stressed()
		and _world.stressed_ids().is_empty())
	_check("...and nothing under it heard that Esc: the selection kept (%d of %d)" % [
		_builder.selection.size(), selected], selected == 1 and _builder.selection.size() == selected)
	_builder.clear_selection()
	await _settled()
	_check("the ghosts are gone", _compare.ghosts() == null
		and _world.get_node_or_null("compare_ghosts") == null)
	var same_looks: bool = _looks() == looks
	_check("every part's colour and place as they were", same_looks)
	_check("the history as deep (%d)" % _builder.history_depth(), _builder.history_depth() == depth)
	_check("the model still not saved", _store.has_unsaved_work())
	var back: Dictionary = _camera.aim()
	_check("the view back where it was", (back["focus"] as Array) == (aim["focus"] as Array)
		and is_equal_approx(float(back["distance"]), float(aim["distance"])))
	var after: Image = await _shot("closed")
	var differs: float = _difference(before, after)
	_check("the picture as before it opened (%.2f%% of the model's pixels differ)" % differs,
		differs < 1.0)
	# And from Versions…, closed by the panel's own Close.
	_shell.versions.open()
	await _frames(6)
	controls = _shell.controls_by_name()
	_check("Versions… offers Open and Compare on each row", controls.has("version_open_1")
		and controls.has("version_compare_1"))
	(controls["version_compare_1"] as Button).pressed.emit()
	await _frames(6)
	_check("Compare there compares", _compare.is_open() and _compare.diff != null
		and _compare.diff.changes.size() == 8)
	# An edit while it is open is compared again, and so is its undo.
	_builder.remove_brick_id(added[0])
	await create_timer(0.8).timeout
	await _frames(4)
	var edited: Dictionary = _compare.diff.counts()
	_builder.undo()
	await create_timer(0.8).timeout
	await _frames(4)
	_check("an edit meanwhile is compared again (%s), and its undo (%s)" % [edited,
		_compare.diff.counts()], int(edited[ModelDiff.ADDED]) == 2
		and _compare.diff.counts() == {ModelDiff.ADDED: 3, ModelDiff.REMOVED: 2,
			ModelDiff.MOVED: 2, ModelDiff.RECOLOURED: 1}
		and _builder.history_depth() == depth)
	await _click((_shell.controls_by_name()["compare_close"] as Button).get_global_rect().get_center())
	await _frames(6)
	_check("Close closes it, every part as it was", not _compare.is_open()
		and not _world.is_stressed() and _looks() == looks
		and _builder.history_depth() == depth and _store.has_unsaved_work())
	# What a session reads, opening nothing.
	var tools := AppTools.new()
	tools.app = _main
	var read: String = await tools.run("open_model", {"versions": true, "version": 1})
	print(_indent(read))
	_check("open_model versions=true version=1 says the same, opening nothing",
		read.contains("3 added, 2 removed, 2 moved, 1 recoloured") and _parts() == 66
		and _builder.history_depth() == depth and not _compare.is_open())


# -- ten alike -----------------------------------------------------------------


func _ten_in_a_row() -> void:
	print("ten 1 x 1 bricks in a row, one moved to the end")
	# By ModelDiff alone, as the matching is.
	var was: Array = []
	var now: Array = []
	for n: int in 10:
		var at := Transform3D(Basis.IDENTITY, Vector3(n * 20.0, 0.0, 0.0))
		was.append(ModelDiff.Part.new("3005", 4, at))
		if n != 3:
			now.append(ModelDiff.Part.new("3005", 4, at, n + 1))
	now.append(ModelDiff.Part.new("3005", 4, Transform3D(Basis.IDENTITY, Vector3(200.0, 0.0, 0.0)), 4))
	var diff: ModelDiff = ModelDiff.between(was, now)
	_check("matched: %s" % diff.summary(), diff.counts() == {ModelDiff.ADDED: 0,
		ModelDiff.REMOVED: 0, ModelDiff.MOVED: 1, ModelDiff.RECOLOURED: 0})
	# And on the baseplate, saved and compared from the menu.
	_main.call("clear_model")
	await _frames(6)
	var row: Array[int] = []
	for n: int in 10:
		row.append(_put("3005", 4, n * 20.0 - 90.0, 0.0, 0.0))
	_builder.forget_history()
	_store.save_as("Compare row")
	await _frames(4)
	var brick: BrickWorld.Brick = _world.get_brick(row[3])
	_builder.move_bricks({row[3]: brick.transform.translated(Vector3(140.0, 0.0, 0.0))})
	await _frames(4)
	_compare.open_with(_store.versions()[0])
	await _frames(6)
	_check("on the baseplate: %s" % _compare.diff.summary(), _compare.diff.counts() == {
		ModelDiff.ADDED: 0, ModelDiff.REMOVED: 0, ModelDiff.MOVED: 1, ModelDiff.RECOLOURED: 0}
		and _world.stressed_ids().size() == 1 and _world.stressed_ids().has(row[3]))
	_compare.close()
	await _frames(4)


# -- inside a sub-assembly -----------------------------------------------------


func _inside_a_sub_assembly() -> void:
	print("inside a sub-assembly being edited")
	var text := PackedStringArray([
		"0 FILE main.ldr", "0 Compare sub", "0 Author: Brickworks",
		"1 16 -60 0 0 1 0 0 0 1 0 0 0 1 left.ldr",
		"1 16 60 0 0 1 0 0 0 1 0 0 0 1 right.ldr",
		"0 NOFILE",
		"0 FILE left.ldr", "0 Left",
		"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat",
		"1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat",
		"0 NOFILE",
		"0 FILE right.ldr", "0 Right",
		"1 1 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat",
		"1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat",
		"0 NOFILE"])
	_main.call("clear_model")
	await _frames(4)
	var result: Dictionary = _store.open_text("\n".join(text), "Compare sub")
	_shell.bar.opened.emit(int(result.get("placed", 0)))
	await _frames(6)
	_store.save_as("Compare sub")
	await _frames(4)
	var left: Array[int] = []
	var right: Array[int] = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		if Assemblies.path_of(brick).begins_with("Left"):
			left.append(brick.id)
		elif Assemblies.path_of(brick).begins_with("Right"):
			right.append(brick.id)
	_check("two sub-assemblies of two parts (%d, %d)" % [left.size(), right.size()],
		left.size() == 2 and right.size() == 2)
	if left.size() != 2 or right.size() != 2:
		return
	_builder.paint_brick(left[0], 14)
	_builder.paint_brick(right[0], 14)
	var path: String = Assemblies.path_of(_world.get_brick(right[0]))
	_shell.assemblies.enter(path)
	await _frames(4)
	_compare.open_with(_store.versions()[0])
	await _frames(6)
	var said: Dictionary = _compare.fields()
	print("    inside %s: %s; %s" % [path, _compare.diff.summary(), said["inside"]])
	_check("only the one being edited is compared, and the panel says so",
		_compare.diff.counts()[ModelDiff.RECOLOURED] == 1 and _compare.diff.changes.size() == 1
		and _compare.diff.changes[0].now.id == right[0] and str(said["inside"]).contains("Right"))
	await _shot("inside")
	_compare.close()
	_shell.assemblies.enter("")
	_compare.open_with(_store.versions()[0])
	await _frames(4)
	_check("left, the whole model: %s" % _compare.diff.summary(),
		_compare.diff.counts()[ModelDiff.RECOLOURED] == 2 and str(_compare.fields()["inside"]).is_empty())
	_compare.close()
	await _frames(4)


# -- 5,000 parts ---------------------------------------------------------------


func _five_thousand() -> void:
	print("5,000 parts")
	_main.call("clear_model")
	await _frames(4)
	for layer: int in 2:
		for row: int in 50:
			for column: int in 50:
				_world.add_brick("3024", [15, 71, 4, 1][(row + column + layer) % 4],
					Transform3D(Basis.IDENTITY, Vector3(column * 20.0 - 490.0, layer * 8.0 + 8.0,
						row * 20.0 - 490.0)))
	await _frames(4)
	_check("%d parts" % _parts(), _parts() == 5000)
	_store.save_as("Compare big")
	await _frames(4)
	# Ten changes.
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			ids.append(brick.id)
	for n: int in 4:
		var brick: BrickWorld.Brick = _world.get_brick(ids[n * 600 + 2500])
		_world.move_brick(brick.id, brick.transform.translated(Vector3(0.0, 40.0, 0.0)))
	for n: int in 3:
		_world.remove_brick(ids[n * 700 + 100])
	for n: int in 3:
		_world.add_brick("3005", 14, Transform3D(Basis.IDENTITY, Vector3(n * 40.0, 48.0, 0.0)))
	await _frames(4)
	var began: int = Time.get_ticks_usec()
	_compare.open_with(_store.versions()[0])
	var opened_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	await process_frame
	await RenderingServer.frame_post_draw
	var drawn_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	print("    matched in %.0f ms, compared in %.0f ms, drawn %.0f ms after the press: %s" % [
		_compare.diff.matched_ms, opened_ms, drawn_ms, _compare.diff.summary()])
	_check("a 5,000-part model compares in under a second (%.0f ms)" % opened_ms,
		opened_ms < 1000.0 and _compare.diff.counts() == {ModelDiff.ADDED: 3,
			ModelDiff.REMOVED: 3, ModelDiff.MOVED: 4, ModelDiff.RECOLOURED: 0})
	_compare.close()
	await _frames(4)


# -- helpers -------------------------------------------------------------------


func _parts() -> int:
	return _world.brick_count() - _store.scenery.size()


## Where [param part_id] stands with the middle of its footprint at [param x],
## [param z] and the bottom of its body at [param bottom], LDU.
func _at(part_id: String, x: float, bottom: float, z: float) -> Transform3D:
	var part: Lbm.PartMesh = _library.mesh_for(part_id)
	var box: AABB = part.bounds.abs()
	var middle: Vector3 = box.get_center()
	return Transform3D(Basis.IDENTITY, Vector3(roundf(x - middle.x), roundf(bottom - box.position.y),
		roundf(z - middle.z)))


func _put(part_id: String, colour: int, x: float, bottom: float, z: float) -> int:
	var at: Transform3D = _at(part_id, x, bottom, z)
	var id: int = _world.add_brick(part_id, colour, at)
	_builder.register(id, part_id, at)
	return id


func _bounds() -> AABB:
	var box := AABB()
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var here: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		box = here if box.size == Vector3.ZERO else box.merge(here)
	return box


## Every brick's part, colour and place, by id.
func _looks() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = [brick.part_id, brick.color_code, brick.transform]
	return out


## Which change's colour the picture has where [param change] is: the middle
## of the top of the part now, or of the ghost where it was.
func _hue_of(change: ModelDiff.Change) -> String:
	var lift: Vector3 = _store.lift()
	var at: Transform3D
	var part_id: String
	if change.now != null and change.kind != ModelDiff.REMOVED:
		at = _world.get_brick(change.now.id).transform
		part_id = change.now.part_id
	else:
		at = Transform3D(Basis.IDENTITY, lift) * change.was.at
		part_id = change.was.part_id
	var box: AABB = (at * _library.mesh_for(part_id).bounds).abs()
	var top := Vector3(box.get_center().x, box.end.y - 6.0, box.get_center().z)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var point: Vector2 = _as_event(_camera.unproject_position(top))
	var sum := Color(0, 0, 0)
	var count: int = 0
	for dx: int in range(-3, 4):
		for dy: int in range(-3, 4):
			var x: int = clampi(int(point.x) + dx, 0, image.get_width() - 1)
			var y: int = clampi(int(point.y) + dy, 0, image.get_height() - 1)
			sum += image.get_pixel(x, y)
			count += 1
	var c := Color(sum.r / count, sum.g / count, sum.b / count)
	var hue: String = "faded"
	if c.b < c.r * 0.6 and c.g > c.r * 0.6 and c.g < c.r * 0.95:
		hue = ModelDiff.MOVED
	elif c.r > c.g * 1.4 and c.r > c.b * 1.4:
		hue = ModelDiff.REMOVED
	elif c.g > c.r * 1.15 and c.g > c.b * 1.1:
		hue = ModelDiff.ADDED
	elif c.b > c.g * 1.15 and c.r > c.g * 1.05:
		hue = ModelDiff.RECOLOURED
	print("    %s at %s: %s (%s)" % [change.kind, point.round(), c.to_html(false), hue])
	return hue


## Of the model's part of the window (the middle, clear of the panels), how
## much of it differs between two pictures, percent of pixels.
func _difference(a: Image, b: Image) -> float:
	if a == null or b == null or a.get_size() != b.get_size():
		return 100.0
	var size: Vector2i = a.get_size()
	var differ: int = 0
	var all: int = 0
	for y: int in range(size.y / 4, size.y * 3 / 4, 2):
		for x: int in range(size.x / 4, size.x * 3 / 4, 2):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			all += 1
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.06:
				differ += 1
	return 100.0 * differ / maxf(all, 1)


func _indent(text: String) -> String:
	return "    " + text.replace("\n", "\n    ")


func _shot(name: String) -> Image:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/compare/%s_%s.png" % [name, _tag])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/compare/%s_%s.png" % [name, _tag])
	return image


## The view eased to where it was sent: it eases by the clock, and frames
## come faster than a screen's here.
func _settled() -> void:
	await create_timer(1.5).timeout
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _frames(3)
	var whole: Vector2 = _as_event(at).floor()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = whole
		event.global_position = whole
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await _frames(2)
