## Seeing inside a model: the cut-away (K) and x-ray (I).
##
##   xvfb-run -a godot --path . --resolution 1400x900 --script src/dev/see_inside_probe.gd
##
## A closed room — four walls and a roof — with a red brick on its floor that
## nothing outside can see or click. The cut, from the key and dragged by its
## slider as a hand drags it, takes the roof off: the red brick is drawn, and
## a click reaches it. X-ray with the red brick selected draws the room
## see-through and a click goes through the walls to it; so does x-ray of a
## sub-assembly being edited. Both hold while the timeline steps through the
## build, and the booklet, made with both on, is the booklet made with both
## off. Then Orthanc, 8,785 parts, timed: dragging the cut writes no brick,
## and x-ray writes each batch once.
##
## Pictures to look at go to shots/see_inside/.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
var _shell: Node
var _verbs: EditVerbs
var _red: int = 0


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
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	_main.call("clear_model")
	await _frames(4)

	# `-- --orthanc` times Orthanc alone: on the GPU, say, where the rest
	# is no different.
	if not OS.get_cmdline_user_args().has("--orthanc"):
		_build_room()
		await _frames(6)
		_camera.frame(AABB(Vector3(-100, 0, -100), Vector3(200, 90, 200)))
		await _frames(30)
		await _the_cut()
		await _xray()
		await _with_the_timeline()
		await _the_booklet_ignores_them()
	await _orthanc()

	print("")
	if _failures == 0:
		print("see inside: the cut and x-ray show the inside of a model, a click "
			+ "reaches what they show, and the booklet never sees them")
	else:
		print("see inside: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- the room -----------------------------------------------------------------


## Four walls three bricks high round an 8 x 8 floor, a roof of four 4 x 4
## plates, and a red 2 x 2 brick in the middle of the floor.
func _build_room() -> void:
	var turned: Basis = BrickLattice.snap_basis(Basis(Vector3.UP, PI * 0.5))
	for course: int in 3:
		var top: float = 24.0 * (course + 1)
		for z: float in [-70.0, 70.0]:
			for x: float in [-40.0, 40.0]:
				_put("3010", 71, Transform3D(Basis.IDENTITY, Vector3(x, top, z)))
		for x: float in [-70.0, 70.0]:
			_put("3009", 71, Transform3D(turned, Vector3(x, top, 0)))
	for x: float in [-40.0, 40.0]:
		for z: float in [-40.0, 40.0]:
			_put("3031", 72, Transform3D(Basis.IDENTITY, Vector3(x, 80, z)))
	_red = _put("3003", 4, Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))


func _put(part: String, colour: int, where: Transform3D) -> int:
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)
	return brick_id


# -- the cut ------------------------------------------------------------------


func _the_cut() -> void:
	print("  the cut")
	var red_at: Vector2 = _screen(Vector3(0, 24, 0))
	_check("closed, the red brick cannot be clicked: the roof is in the way",
		_verbs.brick_at(red_at) != _red and _verbs.brick_at(red_at) != 0)
	await _shot("closed")

	await _key(KEY_K)
	var see: Object = _see()
	_check("K cuts the model", _is_cut())
	_check("...along Y, the axis it starts on", see != null and int(see.get("axis")) == 1)
	var cut: Plane = _world.call("cut_plane") if _is_cut() else Plane()
	_check("...taking away the side the eye is on, above (normal %s)" % cut.normal,
		cut.normal.is_equal_approx(Vector3.UP))
	_check("...between the floor and the roof (at %.0f)" % (cut.d), cut.d > 24.0 and cut.d < 72.0)
	var right: bool = _all_batches_cut(true)
	_check("each part drawn as the plane says: %d whole, %d cut through, %d not drawn"
		% _sides, right and _sides[1] > 0 and _sides[2] > 0)
	await _frames(4)
	_check("the red brick is clicked through the cut", _verbs.brick_at(red_at) == _red)
	var bar: Control = see.get("bar") if see != null else null
	_check("the cut's strip is up", bar != null and bar.is_visible_in_tree())
	await _shot("cut_along_y")

	# Dragged by its slider as a hand drags it: down to the floor, where it
	# cuts the red brick too, then up past the roof.
	var slider: HSlider = _control("cut_slider")
	if slider != null:
		var rect: Rect2 = slider.get_global_rect()
		var from: Vector2 = Vector2(rect.position.x + rect.size.x * float(
			(slider.value - slider.min_value) / (slider.max_value - slider.min_value)),
			rect.get_center().y)
		await _drag(from, Vector2(rect.position.x + rect.size.x * 0.25, from.y))
		var low: Plane = _world.call("cut_plane")
		_check("dragging the slider left lowers the cut (to %.0f)" % low.d,
			low.d < cut.d and is_equal_approx(float(see.get("at")), low.d))
		_check("...and the pointer follows it: the lattice is cut there too",
			_builder.lattice.cut.d == low.d)
		await _shot("cut_dragged_low")
		await _drag(Vector2(rect.position.x + rect.size.x * 0.25, from.y),
			Vector2(rect.end.x - 2.0, from.y))
		var high: Plane = _world.call("cut_plane")
		_check("...and right raises it past the roof (to %.0f)" % high.d, high.d > 80.0)
		_check("with nothing cut away the roof is clicked again",
			_verbs.brick_at(red_at) != _red)
	else:
		_check("the cut's strip has a slider", false)

	await _key(KEY_K, false, true)
	var flipped: Plane = _world.call("cut_plane") if _is_cut() else Plane()
	_check("Shift-K cuts away the other side", flipped.normal.is_equal_approx(Vector3.DOWN))
	if see != null:
		see.call("move_to", 41.0)
	await _frames(3)
	_check("...where the red brick is gone, and the click finds the roof",
		_verbs.brick_at(red_at) != _red)
	await _shot("cut_flipped")

	var along_x: Button = _control("cut_x")
	if along_x != null:
		await _click(along_x.get_global_rect().get_center())
	_check("the X button cuts along X", see != null and int(see.get("axis")) == 0)
	var cross: Plane = _world.call("cut_plane") if _is_cut() else Plane()
	_check("...across the middle (normal %s at %.0f)" % [cross.normal, cross.d],
		absf(cross.normal.x) == 1.0 and absf(cross.d) < 4.0)
	await _frames(4)
	await _shot("cut_along_x")

	var ghosts: CheckBox = _control("cut_ghosts")
	if ghosts != null:
		await _click(ghosts.get_global_rect().get_center())
	_check("Ghost leaves what is cut away as ghosts",
		_world.has_method("cut_leaves_ghosts") and bool(_world.call("cut_leaves_ghosts"))
		and _count_twins("beyond") > 0)
	await _frames(4)
	await _shot("cut_with_ghosts")
	if ghosts != null:
		await _click(ghosts.get_global_rect().get_center())
	_check("...and unticked takes them away", _count_twins("beyond") == 0)

	await _key(KEY_K)
	_check("K again: the whole model", not _is_cut())
	_check("...drawn with the plain shaders again", _all_batches_cut(false))
	_check("...and the pointer no longer passes the plane",
		_builder.lattice.cut.normal == Vector3.ZERO)
	_check("...and the strip is gone", bar == null or not bar.is_visible_in_tree())
	await _frames(4)


# -- x-ray --------------------------------------------------------------------


func _xray() -> void:
	print("  x-ray")
	var red_at: Vector2 = _screen(Vector3(0, 24, 0))
	_builder.clear_selection()
	await _key(KEY_I)
	var told: String = (_shell.get("status") as StatusBar).message.text
	_check("I with nothing selected stays off and says what to do: \"%s\"" % told,
		not _xrayed() and told.contains("select"))

	_builder.select_brick(_red, false)
	await _key(KEY_I)
	var model: int = _world.brick_count() - _store.scenery.size()
	var ghosts: Dictionary = _world.call("xray_ids") if _world.has_method("xray_ids") else {}
	_check("I with the red brick selected draws the other %d see-through (%d)"
		% [model - 1, ghosts.size()], ghosts.size() == model - 1 and not ghosts.has(_red))
	await _frames(4)
	var drawn: Array = _drawn()
	_check("...from a MultiMesh of their own: %d solid, %d see-through"
		% [drawn[0], drawn[1]], drawn[1] == _surfaces(ghosts) and drawn[0] == _solid_surfaces(ghosts))
	_check("a click goes through the walls to the red brick", _verbs.brick_at(red_at) == _red)
	await _key(KEY_ESCAPE)
	await _click(red_at)
	_check("...and selects it", _builder.selection.size() == 1 and _builder.selection.has(_red))
	await _shot("xray_selection")

	await _key(KEY_I)
	_check("I again ends it", not _xrayed() and _count_twins("xray") == 0)
	await _frames(3)
	_check("...and the walls are in the way again", _verbs.brick_at(red_at) != _red)

	# A sub-assembly being edited: the red brick and a plate put beside it.
	var plate: int = _put("3022", 14, Transform3D(Basis.IDENTITY, Vector3(-40, 8, -20)))
	_builder.select_brick(_red, false)
	_builder.select_brick(plate, true)
	var assemblies: Assemblies = _shell.get("assemblies")
	var path: String = assemblies.make("Table")
	assemblies.enter(path)
	await _frames(3)
	await _key(KEY_I)
	ghosts = _world.call("xray_ids") if _world.has_method("xray_ids") else {}
	_check("editing inside a sub-assembly, I sees through all but it (%d)" % ghosts.size(),
		_xrayed() and ghosts.size() == model - 1 and not ghosts.has(plate))
	await _frames(4)
	_check("...and its parts are clicked through the walls",
		_verbs.brick_at(_screen(Vector3(-40, 8, -20))) == plate)
	await _shot("xray_subassembly")
	assemblies.leave()
	await _frames(3)
	_check("leaving the sub-assembly ends it", not _xrayed())


# -- with the timeline --------------------------------------------------------


func _with_the_timeline() -> void:
	print("  with the timeline")
	_builder.select_brick(_red, false)
	await _key(KEY_I)
	await _key(KEY_K)
	await _key(KEY_B)
	var steps: StepsBar = _main.get("_steps")
	_check("B opens the timeline with x-ray and the cut on", steps.is_playing_back())
	steps.to_start()
	steps.step_forward()
	steps.step_forward()
	await _settled()
	var hidden: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		hidden += 1 if brick.hidden else 0
	var placed: bool = _all_batches_cut(true)
	_check("a step hides what is still to come (%d): the solid parts are the step's, as the cut has them"
		% hidden, hidden > 0 and placed)
	_check("...and the see-through ones are the step's too (%d)" % _drawn()[1],
		_drawn()[1] == _xray_surfaces(true))
	await _shot("timeline_step")
	steps.to_end()
	await _key(KEY_B)
	await _settled()
	placed = _all_batches_cut(true)
	_check("closing it shows the whole model, still cut (%d whole, %d cut through, %d not drawn)"
		% _sides, placed and _sides[0] + _sides[1] + _sides[2] > 0)
	_check("...and still in x-ray (%d see-through)" % _drawn()[1],
		_drawn()[1] == _xray_surfaces(false) and _drawn()[1] > 0)


## The surfaces x-ray should be drawing: every see-through part's, or with
## [param shown_only] only those of the parts on show.
func _xray_surfaces(shown_only: bool) -> int:
	var ids: Dictionary = _world.call("xray_ids") if _world.has_method("xray_ids") else {}
	var total: int = 0
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null or (shown_only and brick.hidden):
			continue
		total += _brick_surfaces(brick_id)
	return total


# -- the booklet --------------------------------------------------------------


func _the_booklet_ignores_them() -> void:
	print("  the booklet")
	_check("the cut and x-ray are on", _is_cut() and _xrayed())
	var with: String = ProjectSettings.globalize_path("res://shots/see_inside/booklet_with.html")
	var without: String = ProjectSettings.globalize_path(
		"res://shots/see_inside/booklet_without.html")
	await _main.call("_export_booklet", with)
	await _key(KEY_K)
	await _key(KEY_I)
	_check("...and now off", not _is_cut() and not _xrayed())
	await _main.call("_export_booklet", without)
	var a: String = FileAccess.get_file_as_string(with)
	var b: String = FileAccess.get_file_as_string(without)
	# Its words byte for byte, and its pictures pixel for pixel: a picture
	# is a JPEG, and two renders of the same step can differ by a JPEG
	# block's rounding, where a cut or a ghost would change thousands.
	var pictures := RegEx.create_from_string("data:image/jpeg;base64,([A-Za-z0-9+/=]+)")
	var words_a: String = pictures.sub(a, "IMG", true)
	var words_b: String = pictures.sub(b, "IMG", true)
	_check("the booklet made with them on has the words of the one made with them off (%d bytes)"
		% words_a.length(), not a.is_empty() and words_a == words_b)
	var seen_a: Array[RegExMatch] = pictures.search_all(a)
	var seen_b: Array[RegExMatch] = pictures.search_all(b)
	var unlike: int = 0
	for n: int in mini(seen_a.size(), seen_b.size()):
		unlike += _pixels_unlike(seen_a[n].get_string(1), seen_b[n].get_string(1))
	_check("...and its %d pictures (%d pixels unlike)" % [seen_a.size(), unlike],
		seen_a.size() > 0 and seen_a.size() == seen_b.size() and unlike == 0)


# -- a set-sized model --------------------------------------------------------


func _orthanc() -> void:
	print("  Orthanc")
	var placed: int = int(_main.call("_open", "res://models/orthanc.ldr"))
	await _frames(30)
	_check("Orthanc opens (%d parts)" % placed, placed > 8000)
	_camera.frame(_main.call("_built_bounds"))
	await _frames(20)
	var see: Object = _see()
	var whole_ms: float = await _frame_ms(4)
	var began: int = Time.get_ticks_usec()
	await _key(KEY_K)
	var first: float = float(Time.get_ticks_usec() - began) / 1000.0
	await _key(KEY_K)
	began = Time.get_ticks_usec()
	await _key(KEY_K)
	var again: float = float(Time.get_ticks_usec() - began) / 1000.0
	# The app's own work, all of it at once: the world on screen spreads a
	# rewrite over frames (FramePace), and here it is done before the clock
	# stops.
	_world.rebuilds_in_slices = false
	if see != null:
		see.call("set_cut", false)
		_world.call("_flush")
		began = Time.get_ticks_usec()
		see.call("set_cut", true)
		_world.call("_flush")
	var work: float = float(Time.get_ticks_usec() - began) / 1000.0
	print("    the cut on: %.0f ms the first time, %.0f ms after, %.1f ms of it the app's own work"
		% [first, again, work])
	_check("the cut turns on in %.1f ms of the app's own work, every part sorted" % work,
		_is_cut() and work < 1500.0)
	if see != null:
		var low: float = float((see.get("_slider") as HSlider).min_value)
		var high: float = float((see.get("_slider") as HSlider).max_value)
		# A drag: the plane a plate further each move, up the whole tower.
		var moves: int = 0
		var slowest: float = 0.0
		began = Time.get_ticks_usec()
		var at: float = _odd(low)
		while at < high:
			var one: int = Time.get_ticks_usec()
			see.call("move_to", at)
			_world.call("_flush")
			slowest = maxf(slowest, float(Time.get_ticks_usec() - one) / 1000.0)
			moves += 1
			at += 8.0
		var each: float = float(Time.get_ticks_usec() - began) / 1000.0 / maxf(moves, 1)
		print("    dragging the cut up the tower a plate a move: %d moves, %.1f ms each, %.1f the slowest"
			% [moves, each, slowest])
		# Against a whole frame of the same model on the same machine, not a
		# wall clock: at a load of 50 a move took 26 ms and a frame 1,355,
		# and the 25 ms budget failed a drag that was fine. A drag that
		# rewrote every part would cost a good share of a frame.
		_check("dragging it costs %.1f ms a move, under a tenth of a whole frame (%.0f ms)"
			% [each, whole_ms], each < whole_ms * 0.1)
		see.call("move_to", _odd(lerpf(low, high, 0.6)))
	_world.rebuilds_in_slices = true
	await _settled()
	await _frames(4)
	var cut_ms: float = await _frame_ms(4)
	var as_said: bool = _all_batches_cut(true)
	_check("Orthanc's parts drawn as the plane says: %d whole, %d cut through, %d not drawn"
		% _sides, as_said)
	print("    a frame of Orthanc here: %.0f ms whole, %.0f ms cut" % [whole_ms, cut_ms])
	await _shot("orthanc_cut")
	if see != null:
		see.call("cut_along", 0)
	await _settled()
	await _frames(4)
	await _shot("orthanc_cut_along_x")
	await _key(KEY_K)

	# X-ray of one brick near the middle.
	var middle: Vector3 = (_main.call("_built_bounds") as AABB).get_center()
	var nearest: int = 0
	var best: float = INF
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var d: float = brick.transform.origin.distance_squared_to(middle)
		if d < best:
			best = d
			nearest = brick.id
	_builder.select_brick(nearest, false)
	await _frames(2)
	began = Time.get_ticks_usec()
	await _key(KEY_I)
	await _settled()
	var xray_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	await _key(KEY_I)
	await _settled()
	# The app's own work, all of it at once: the world on screen spreads it
	# over frames (FramePace).
	_world.rebuilds_in_slices = false
	began = Time.get_ticks_usec()
	if see != null:
		see.call("set_xray", true)
	_world.call("_flush")
	var xray_work: float = float(Time.get_ticks_usec() - began) / 1000.0
	_world.rebuilds_in_slices = true
	print("    x-ray on: %.0f ms with the frames, %.0f ms of it the app's own work"
		% [xray_ms, xray_work])
	var ghosts: Dictionary = _world.call("xray_ids") if _world.has_method("xray_ids") else {}
	_check("x-ray of one part of %d costs %.0f ms of the app's own work" % [
		_world.brick_count(), xray_work], ghosts.size() > 8000 and xray_work < 1500.0)
	var drawn: Array = _drawn()
	_check("...%d see-through, %d solid" % [drawn[1], drawn[0]],
		drawn[1] == _surfaces(ghosts))
	print("    a frame of Orthanc in x-ray: %.0f ms" % (await _frame_ms(4)))
	await _shot("orthanc_xray")
	await _key(KEY_I)
	await _settled()
	_check("and off again", not _xrayed() and _count_twins("xray") == 0)


# -- reading the world --------------------------------------------------------


func _see() -> Object:
	return _shell.get("see_inside") if _shell != null else null


func _is_cut() -> bool:
	return _world.has_method("is_cut") and bool(_world.call("is_cut"))


func _xrayed() -> bool:
	return _world.has_method("xray_ids") and not (_world.call("xray_ids") as Dictionary).is_empty()


func _control(name: String) -> Control:
	var named: Dictionary = _shell.call("controls_by_name")
	return named.get(name)


## With [param cut], whether each part is drawn as the plane says it should
## be, worked out here from its own box: wholly on the near side by its
## batch with the plain shader, across the plane by the batch's MultiMesh
## that cuts, wholly past it not at all (or, leaving ghosts, by the one that
## cuts, for its ghost). Without, whether every part is drawn by its batch.
## The counts of each, by surface, go to [member _sides].
var _sides: Array = [0, 0, 0]


func _all_batches_cut(cut: bool) -> bool:
	var batches: Dictionary = _world.get("_batches")
	var plane: Plane = _world.call("cut_plane") if _is_cut() else Plane()
	var ghosts: bool = _is_cut() and bool(_world.call("cut_leaves_ghosts"))
	var xray: Dictionary = _world.call("xray_ids") if _world.has_method("xray_ids") else {}
	var any: bool = false
	_sides = [0, 0, 0]
	for key: String in batches:
		var batch: Object = batches[key]
		var whole: int = 0
		var through: int = 0
		for brick_id: int in batch.get("brick_ids"):
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			if brick == null or brick.hidden or xray.has(brick_id):
				continue
			any = true
			var side: int = -1
			if cut:
				var part: Lbm.PartMesh = _world.library.mesh_for(brick.part_id)
				var box: AABB = brick.transform * part.bounds
				var middle: float = plane.normal.dot(box.get_center())
				var reach: float = (box.size * 0.5).dot(plane.normal.abs())
				side = 1 if middle - reach > plane.d else (-1 if middle + reach <= plane.d else 0)
			_sides[side + 1] += 1
			if side < 0:
				whole += 1
			elif side == 0 or ghosts:
				through += 1
		var twin: Variant = batch.get("through") if "through" in batch else null
		var drawn_through: int = (twin as MultiMeshInstance3D).multimesh.instance_count \
			if twin != null else 0
		if (batch.get("multimesh") as MultiMesh).visible_instance_count != whole \
				or drawn_through != through:
			return false
	return any


func _count_twins(which: String) -> int:
	var batches: Dictionary = _world.get("_batches")
	var count: int = 0
	for key: String in batches:
		var batch: Object = batches[key]
		if which in batch and batch.get(which) != null:
			count += 1
	return count


## Instances drawn [solid, see-through], over every batch.
func _drawn() -> Array:
	var batches: Dictionary = _world.get("_batches")
	var solid: int = 0
	var ghost: int = 0
	for key: String in batches:
		var batch: Object = batches[key]
		solid += (batch.get("multimesh") as MultiMesh).visible_instance_count
		var twin: Variant = batch.get("xray") if "xray" in batch else null
		if twin != null:
			ghost += (twin as MultiMeshInstance3D).multimesh.instance_count
	return [solid, ghost]


func _brick_surfaces(brick_id: int) -> int:
	return (_world.get("_brick_batches") as Dictionary).get(brick_id, PackedStringArray()).size()


func _surfaces(ids: Dictionary) -> int:
	var total: int = 0
	for brick_id: int in ids:
		total += _brick_surfaces(brick_id)
	return total


func _solid_surfaces(ghosts: Dictionary) -> int:
	var total: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not ghosts.has(brick.id) and not brick.hidden:
			total += _brick_surfaces(brick.id)
	return total


## Pixels further apart than JPEG's rounding between two pictures.
func _pixels_unlike(a64: String, b64: String) -> int:
	if a64 == b64:
		return 0
	var a := Image.new()
	var b := Image.new()
	a.load_jpg_from_buffer(Marshalls.base64_to_raw(a64))
	b.load_jpg_from_buffer(Marshalls.base64_to_raw(b64))
	if a.get_size() != b.get_size():
		return a.get_width() * a.get_height()
	var count: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) > 0.16:
				count += 1
	return count


## The wall time of a frame, drawn, averaged over a few.
func _frame_ms(count: int) -> float:
	await RenderingServer.frame_post_draw
	var began: int = Time.get_ticks_usec()
	for _n: int in count:
		await RenderingServer.frame_post_draw
	return float(Time.get_ticks_usec() - began) / 1000.0 / count


## On an odd whole LDU, as the strip puts the plane.
static func _odd(value: float) -> float:
	return floorf(value / 2.0) * 2.0 + 1.0


## Until the world has drawn everything waiting to be drawn.
func _settled() -> void:
	for _n: int in 600:
		await process_frame
		if (_world.get("_dirty") as Dictionary).is_empty() and not bool(_world.get("_rebuild_queued")):
			break
	await _frames(2)


# -- hands --------------------------------------------------------------------


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	if held:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	await _frames(3)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	if down:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _drag(from: Vector2, to: Vector2) -> void:
	await _move(from)
	_button(from, true)
	await _frames(2)
	for n: int in 8:
		await _move(from.lerp(to, float(n + 1) / 8.0), true)
	_button(to, false)
	await _frames(4)


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


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/see_inside/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/see_inside/%s.png" % name)
