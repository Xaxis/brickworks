## The timeline draws exactly the parts of the step it shows, however soon
## after it opens a step is changed (timeline4, 2026-10-31).
##
##   godot --path . --resolution 1280x720 --script src/dev/timeline_drawn_probe.gd
##
## mcpcad found it in a browser: a model of nine 2 x 4 bricks, one a step,
## opened as Open… > From a file opens one; the Timeline; Next to step 4.
## The timeline said "Step 4 of 9 · 4 of 9 bricks" and the view showed the
## baseplate and none of the four. Here, the same steps in the desktop's
## window, RUNS times each way: with and without a reference picture laid,
## and Next pressed at once (a frame apart, from the frame the timeline is
## up) or after a wait. Each time, at step 4:
## - the scene: what each batch draws (its first visible_instance_count
##   slots, by where each slot's part stands) is the four bricks of steps 1
##   to 4 and nothing else;
## - the picture: the view drawn holds the red of step 1's brick and the
##   yellow of step 3's.
## TIMELINE_RUNS=N (default 5) a way; pictures of the first run each way in
## TIMELINE_SHOTS or user://timeline_drawn_probe.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _steps: StepsBar
var _shell: Shell
var _shots: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_steps = _main.get("_steps")
	_shell = _main.get("_shell")
	_shots = OS.get_environment("TIMELINE_SHOTS")
	if _shots.is_empty():
		_shots = OS.get_user_data_dir().path_join("timeline_drawn_probe")
	DirAccess.make_dir_recursive_absolute(_shots)
	var runs: int = maxi(1, OS.get_environment("TIMELINE_RUNS").to_int()) \
		if not OS.get_environment("TIMELINE_RUNS").is_empty() else 5
	for picture: bool in [false, true]:
		for quick: bool in [true, false]:
			var empty: int = 0
			var wrong: int = 0
			for run: int in runs:
				var seen: Dictionary = await _once(picture, quick, run == 0)
				if not seen["drawn"]:
					empty += 1
				if not seen["right"]:
					wrong += 1
			_check("%s, Next %s: step 4 drawn with its four bricks in %d of %d runs (%d drew none)"
				% ["a reference picture laid" if picture else "no picture",
				"at once" if quick else "after a wait", runs - wrong, runs, empty],
				wrong == 0)
	print("")
	print("timeline_drawn: %s" % ("every check passed" if _failures == 0
		else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## The model opened, the picture laid or not, the timeline opened and Next
## pressed to step 4; what the scene and the picture show then.
func _once(picture: bool, quick: bool, keep: bool) -> Dictionary:
	if _steps.is_playing_back():
		_steps.stop()
	_main.call("clear_model")
	await _frames(3)
	var bar: ModelBar = _main.get("_bar")
	var store: ModelStore = _main.get("_store")
	var job: Working.Job = Working.begin("Opening in_view_nine_steps.ldr…")
	await job.shown()
	var result: Dictionary = await store.open_text_fetched(_nine_steps(), "in_view_nine_steps",
		null, job)
	job.end()
	bar.opened.emit(int(result["placed"]))
	await _frames(10)
	var reference: ReferenceImage = _main.get("_reference")
	if picture:
		var plan := Image.create_empty(400, 300, false, Image.FORMAT_RGBA8)
		plan.fill(Color(0.95, 0.95, 0.9))
		plan.fill_rect(Rect2i(40, 40, 120, 80), Color(0.1, 0.3, 0.8))
		reference.take(plan, "plan.png")
		await _frames(3)
		var dialog: Variant = reference.controls_by_name().get("reference_dialog")
		if dialog is AcceptDialog:
			(dialog as AcceptDialog).hide()
		await _frames(3)
	_shell.run("timeline")
	for _n: int in 600:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	if not quick:
		await _frames(30)
	for _n: int in 3:
		_steps.step_forward()
		await _frames(1 if quick else 10)
	await _frames(8)
	var at: Vector2i = _steps.timeline_at()
	var drawn: Array = _drawn_places()
	var wanted: Array = _step_places(at.x)
	var image: Image = await _picture()
	var colours: Vector2i = _red_and_yellow(image)
	var seen_right: bool = drawn == wanted
	var drawn_any: bool = colours.x > 50 and colours.y > 50
	print("    %s, %s: at %d of %d, drawn %s, wanted %s, red %d px, yellow %d px" % [
		"picture" if picture else "no picture", "at once" if quick else "after a wait",
		at.x, at.y, drawn, wanted, colours.x, colours.y])
	if keep or not (seen_right and drawn_any):
		image.save_png(_shots.path_join("step4_%s_%s_%d.png" % [
			"picture" if picture else "nopicture", "quick" if quick else "wait",
			Time.get_ticks_msec()]))
	if picture:
		reference.remove_picture()
	return {"drawn": drawn_any, "right": seen_right and drawn_any}


## Where each part every batch draws stands, rounded, sorted: the slots a
## batch draws are its first visible_instance_count.
func _drawn_places() -> Array:
	var places: Array = []
	for one: Array in _world.drawing():
		var multimesh: MultiMesh = one[0]
		var count: int = multimesh.visible_instance_count
		if count < 0:
			count = multimesh.instance_count
		for slot: int in count:
			var origin: Vector3 = multimesh.get_instance_transform(slot).origin
			places.append(Vector3i(roundi(origin.x), roundi(origin.y), roundi(origin.z)))
	places.sort()
	return _unique(places)


## Where the first [param count] parts of the timeline's order stand,
## rounded, sorted, with the baseplate's.
func _step_places(count: int) -> Array:
	var places: Array = []
	var order: PackedInt64Array = _steps.reveal_order()[0]
	var shown: Dictionary = {}
	for n: int in mini(count, order.size()):
		shown[order[n]] = true
	for brick: BrickWorld.Brick in _world.bricks():
		var store: ModelStore = _main.get("_store")
		if shown.has(brick.id) or store.scenery.has(brick.id):
			var origin: Vector3 = _world.drawn_at(brick).origin
			places.append(Vector3i(roundi(origin.x), roundi(origin.y), roundi(origin.z)))
	places.sort()
	return _unique(places)


static func _unique(sorted: Array) -> Array:
	var out: Array = []
	for one: Variant in sorted:
		if out.is_empty() or out[-1] != one:
			out.append(one)
	return out


## The window as drawn, cut to the part the model is seen in.
func _picture() -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var camera: CadCamera = _main.get("_camera")
	var seen: Rect2 = camera.seen_rect()
	var cut := Rect2i(Vector2i(seen.position), Vector2i(seen.size)).intersection(
		Rect2i(Vector2i.ZERO, image.get_size()))
	return image.get_region(cut) if cut.has_area() else image


## Pixels of the red of brick 1 and the yellow of brick 3.
static func _red_and_yellow(image: Image) -> Vector2i:
	var red: int = 0
	var yellow: int = 0
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			var c: Color = image.get_pixel(x, y)
			if c.r8 > 110 and c.g8 < 50 and c.b8 < 50:
				red += 1
			if c.r8 > 170 and c.g8 > 140 and c.b8 < 90:
				yellow += 1
	return Vector2i(red, yellow)


## Nine 2 x 4 bricks stacked, each a step of the author's (in_view_flow's).
static func _nine_steps() -> String:
	var lines := PackedStringArray(["0 Nine steps", "0 Name: in_view_nine_steps.ldr",
		"0 Author: in_view_flow"])
	for n: int in 9:
		lines.append("1 %d 0 %d 0 1 0 0 0 1 0 0 0 1 3001.dat" % [[4, 1, 14, 2][n % 4], -24 * n])
		lines.append("0 STEP")
	return "\n".join(lines) + "\n"


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
