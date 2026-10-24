## Finding a part from a photo, with Brickognize answering for real.
##
##   godot --path . --resolution 1280x860 --script src/dev/photo_search_probe.gd
##   ... -- --keep        and write the photos to tests/fixtures/photos/
##
## Five single parts are drawn by the app's own renderer (ModelShot), each
## alone in a colour of its own, and each picture goes through the parts
## bin's camera path as a chosen photo does: to Brickognize's public API,
## its BrickLink numbers back into parts here, shown as the bin's results.
## Four of the five must have the part in the first three. Two of the five
## are numbered differently by BrickLink and LDraw (3062 is 3062b, 3069 is
## 3069b), so the numbers are mapped and not merely matched.
##
## It asks a third party over the internet, so it is not in the suite
## (tools/suite/out.txt): photo_search_stub_probe is, with Brickognize stood
## in for. Pictures of the bin go to shots/photo_search/.
extends SceneTree

## The parts, each in a colour that sets it off.
const PARTS: Array = [["3001", 4], ["3039", 1], ["3062b", 14], ["3069b", 72], ["3700", 71]]
## How many of them must lead with the right part, in the first three.
const AT_LEAST := 4

var _failures: int = 0


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
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	var world: BrickWorld = main.get("_world")
	var builder: Builder = main.get("_builder")
	var store: ModelStore = main.get("_store")
	var library: PartLibrary = main.get("_library")
	var bin: PartsBin = main.get("_bin")
	store.keeps = false
	if not ModelShot.possible():
		print("photo search probe: SKIPPED, no rendering device: this needs a window")
		quit(1)
		return
	var keep: bool = OS.get_cmdline_user_args().has("--keep")

	# Said before the first photo goes.
	(bin.controls_by_name()["photo search"] as Button).pressed.emit()
	await _frames(6)
	await _shot("told")
	_check("the first press says where the photo goes",
		bin._telling != null and bin._telling.visible)
	bin._telling.hide()

	var shot := ModelShot.new()
	shot.rulers = false
	shot.library = library
	main.add_child(shot)
	var found: int = 0
	for pair: Array in PARTS:
		var part: String = pair[0]
		world.clear()
		builder.lattice.clear()
		store.scenery.clear()
		world.add_brick(part, int(pair[1]), Transform3D.IDENTITY)
		await _frames(4)
		var photo: Image = await shot.take(world, "corner")
		if photo == null:
			_check("%s is drawn" % part, false)
			continue
		if keep:
			var path: String = ProjectSettings.globalize_path(
				"res://tests/fixtures/photos/%s.jpg" % part)
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			photo.save_jpg(path, 0.85)
		var answer: Array = await _ask(bin, photo)
		var first: PackedStringArray = bin.first_found(3)
		var right: bool = first.has(part) and answer.is_empty()
		if right:
			found += 1
		print("  %s %s: Brickognize said %s; the bin shows %s" % [
			"ok  " if right else "miss", part, _said(answer, bin), str(first)])
		if part == "3001":
			await _frames(30)
			await _shot("results")
	_check("%d of %d photos have their part in the bin's first three (at least %d)"
		% [found, PARTS.size(), AT_LEAST], found >= AT_LEAST)

	print("")
	if _failures == 0:
		print("photo search: Brickognize names the part in a photo, and the bin shows it")
	else:
		print("photo search: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## A photo through the bin as the picker hands one over; what went wrong, if
## anything, as [why], or [] once it is answered.
func _ask(bin: PartsBin, photo: Image) -> Array:
	var said: Array = [null]
	var answered: Callable = func(_guesses: Array) -> void: said[0] = []
	var failed: Callable = func(why: String) -> void: said[0] = [why]
	bin._brickognize.answered.connect(answered, CONNECT_ONE_SHOT)
	bin._brickognize.failed.connect(failed, CONNECT_ONE_SHOT)
	bin._identify(photo)
	var deadline: int = Time.get_ticks_msec() + 45000
	while said[0] == null and Time.get_ticks_msec() < deadline:
		await process_frame
	for one: Array in [[bin._brickognize.answered, answered], [bin._brickognize.failed, failed]]:
		if (one[0] as Signal).is_connected(one[1]):
			(one[0] as Signal).disconnect(one[1])
	await _frames(4)
	return ["no answer in 45 s"] if said[0] == null else said[0]


func _said(answer: Array, bin: PartsBin) -> String:
	if not answer.is_empty():
		return str(answer[0])
	var out := PackedStringArray()
	for id: String in bin.first_found(5):
		out.append("%s %d%%" % [id, roundi(float(bin._guesses.get(id, 0.0)) * 100.0)])
	return ", ".join(out)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/photo_search/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/photo_search/%s.png" % name)
