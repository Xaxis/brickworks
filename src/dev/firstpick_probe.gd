## The first pick's warm (smalls8, APP_UX10 "the first pick"): what the
## first part picked draws, drawn once out of sight after the first screen
## (Main._warm_first_pick, on the web), so the first pick does not wait for
## its shaders. In a window:
##
##   godot --path . --resolution 1280x720 --script src/dev/firstpick_probe.gd
##
## The warm leaves no ghost and no marks behind, changes no pixel of the
## model's room, adds nothing to the model and saves nothing; a part picked
## while it is drawn keeps its ghost, at its own size; and the warm draws the
## ghost and both batches of marks once each. The time it saves is the web's, read by
## tools/web/load_check.mjs --pick in same-moment pairs (start_abba).
extends SceneTree

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	ShellPrefs.kept_by_a_check = true
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	var store: ModelStore = _main.get("_store")
	for _n: int in 60:
		await process_frame
	var size: Vector2i = DisplayServer.window_get_size()
	print("FIRSTPICK window %dx%d, %d parts in the model" % [size.x, size.y, _world.brick_count()])

	# 1. The warm alone: nothing left behind, nothing seen, nothing changed.
	_check(not _builder.has_preview(), "no ghost before the warm")
	var parts: int = _world.brick_count()
	var revision: int = _world.revision
	var saves: int = store.saves if "saves" in store else -1
	var marks_before: int = _marks_drawn()
	# A still screen first: two frames alike, so what differs is the warm's.
	await RenderingServer.frame_post_draw
	var before: Image = root.get_texture().get_image()
	var still: int = -1
	for n: int in 600:
		await process_frame
		var now: Image = root.get_texture().get_image()
		if _differing(before, now) == 0:
			still = n
			break
		before = now
	print("FIRSTPICK the screen still after %d frames" % still)
	var ghost_frames: int = 0
	var marks_frames: int = 0
	var differing: int = 0
	var previewed: int = 0
	var warming: Array = [true]
	var warm := func() -> void:
		await _main.call("_warm_first_pick")
		warming[0] = false
	warm.call()
	for _n: int in 1200:
		if not warming[0]:
			break
		await RenderingServer.frame_post_draw
		if (_builder.get("_ghost") as MeshInstance3D).visible:
			ghost_frames += 1
			if _builder.has_preview():
				previewed += 1
		if _marks_drawn() > marks_before:
			marks_frames += 1
		var seen: Image = root.get_texture().get_image()
		var off: int = _differing(before, seen)
		if off > differing:
			differing = off
			_save(before, "before")
			_save(seen, "warm")
			print("FIRSTPICK differing pixels within %s" % str(_where(before, seen)))
	await _frames(6)
	_check(not warming[0], "the warm ended")
	_check(ghost_frames >= 1, "the ghost was drawn in %d frame(s) of the warm" % ghost_frames)
	_check(marks_frames >= 1 or not bool(ShellPrefs.value("joint_marks")),
		"both batches of marks were drawn in %d frame(s) of the warm" % marks_frames)
	_check(previewed == 0, "no preview while the warm's ghost is drawn (%d frames)" % previewed)
	_check(not _builder.has_preview() and not (_builder.get("_ghost") as MeshInstance3D).visible,
		"no ghost after the warm")
	_check(_marks_drawn() == marks_before, "no marks left after the warm (%d, were %d)" % [
		_marks_drawn(), marks_before])
	_check(differing == 0, "%d pixels of the model's room (%s) differ from the frame before the warm" % [
		differing, str(_room(before))])
	_check(_world.brick_count() == parts and _world.revision == revision,
		"the model as it was: %d parts, revision %d" % [_world.brick_count(), _world.revision])
	if saves >= 0:
		_check(store.saves == saves, "nothing saved")

	# 2. A part picked while the warm is drawn keeps its ghost, at its size.
	var view: Vector2 = root.get_visible_rect().size
	var aim: Vector2 = Vector2(view.x * 0.45, view.y * 0.5)
	warming[0] = true
	warm.call()
	for _n: int in 600:
		if (_builder.get("_ghost") as MeshInstance3D).visible:
			break
		await process_frame
	_main.call("_on_part_chosen", "3001")
	_main.call("_refresh_preview", aim)
	for _n: int in 1200:
		if not warming[0]:
			break
		await process_frame
	await _frames(6)
	var ghost: MeshInstance3D = _builder.get("_ghost")
	var scale: float = ghost.transform.basis.get_scale().x
	_check(_builder.has_preview() and is_equal_approx(scale, 1.0),
		"a part picked during the warm keeps its ghost (shown %s, scale %.3f)" % [
			_builder.has_preview(), scale])
	_builder.hide_preview()
	_main.call("_on_part_chosen", "3001")
	print("FIRSTPICK %s: %d failed" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


## How many mark batches are drawn under the builder (JointMarks' and the
## warm's own).
func _marks_drawn() -> int:
	var count: int = 0
	for node: Node in _builder.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := node as MultiMeshInstance3D
		if batch.name.contains("Marks") and batch.is_visible_in_tree() and batch.multimesh != null \
				and batch.multimesh.instance_count > 0:
			count += 1
	return count


## Samples of the model's room (Main._model_rect, in the window's pixels)
## that differ: what the warm draws is drawn there, and the status bar's
## words change by themselves ("3001 ready" put away after its seconds).
func _differing(a: Image, b: Image) -> int:
	if a.get_size() != b.get_size():
		return -1
	var room: Rect2i = _room(a)
	var count: int = 0
	for y: int in range(room.position.y, room.end.y, 2):
		for x: int in range(room.position.x, room.end.x, 2):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.02:
				count += 1
	return count


## The box round the samples that differ.
func _where(a: Image, b: Image) -> Rect2i:
	var box := Rect2i()
	var room: Rect2i = _room(a)
	for y: int in range(room.position.y, room.end.y, 2):
		for x: int in range(room.position.x, room.end.x, 2):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.02:
				box = Rect2i(x, y, 1, 1) if box.size == Vector2i.ZERO else box.expand(Vector2i(x, y))
	return box


func _room(image: Image) -> Rect2i:
	var rect: Rect2 = _main.call("_model_rect")
	var scale: Vector2 = Vector2(image.get_size()) / root.get_visible_rect().size
	var room := Rect2i(Vector2i((rect.position * scale).ceil()), Vector2i((rect.size * scale).floor()))
	return room.intersection(Rect2i(Vector2i.ZERO, image.get_size()))


func _save(image: Image, name: String) -> void:
	var dir: String = OS.get_environment("FIRSTPICK_SHOTS")
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(dir)
		image.save_png(dir.path_join(name + ".png"))


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
