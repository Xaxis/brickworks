## Does a model file come out as a picture of the model, quickly enough for a
## file browser, from the app's corner view?
##
##   godot --path . --resolution 1400x900 --script src/dev/thumbs_probe.gd -- [--out=DIR]
##
## The bar (docs/APP_UX5.md, unit 12): an .ldr, an .mpd and an .io each drawn
## as a 256 px picture by the thumbnail command in 3 s or less, each the
## model's corner view; a file with parts not in the library still drawn.
##
## Each file is drawn the way the Linux package's thumbnailer draws it: the
## engine started again as a child, headless, with --thumbnail MODEL PICTURE
## 256 (ModelThumbnail, through BrickworksLoop), timed from start to exit.
## Each picture is then laid over the app's own corner picture of the same
## parts (ModelShot, on the graphics card, which is why this has a window):
## their outlines must be one, and closer than to any other corner's.
##
## Also: the catalogue's text is read for each part's geometry as JSON says,
## and the loop, the flag and the corner are the app's.
##
## Pictures go to --out (default user://thumbs_probe): each thumbnail and the
## app's corner picture beside it.
extends SceneTree

const THUMBNAIL := "res://src/render/model_thumbnail.gd"
const LOOP := "res://src/boot/brickworks_loop.gd"
## What a file browser waits for.
const MOST_MS := 3000
## A child that has not exited by then never will.
const GIVE_UP_MS := 30000
## The share of the app's outline the picture's must agree on.
const LEAST_OVERLAP := 0.90
const FILES: Array = [
	["car", "res://models/car.ldr"],
	["gatehouse mpd", "res://tests/fixtures/steps/gatehouse.mpd"],
	["gatehouse io", "res://tests/fixtures/studio/gatehouse_2025.io"],
]

var _failures: int = 0
var _out: String = "user://thumbs_probe"


func _initialize() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_out = ProjectSettings.globalize_path(_out)
	print("thumbs: pictures in %s" % _out)

	var drawer: GDScript = load(THUMBNAIL) if ResourceLoader.exists(THUMBNAIL) else null
	_wiring(drawer)
	if drawer != null:
		_lookup(drawer)

	var library := PartLibrary.new()
	library.load_catalogue()
	var unknown: String = _out.path_join("unknown.ldr")
	_write_unknown(unknown)
	for file: Array in FILES + [["unknown parts", unknown]]:
		await _one(str(file[0]), ProjectSettings.globalize_path(str(file[1])), library)

	print("thumbs: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)


## The loop the engine makes is the app's, it knows the flag the drawer
## answers to, and the drawer's corner is the app's corner picture's.
func _wiring(drawer: GDScript) -> void:
	_check(str(ProjectSettings.get_setting("application/run/main_loop_type")) == "BrickworksLoop",
		"the engine's main loop is BrickworksLoop (%s)"
		% ProjectSettings.get_setting("application/run/main_loop_type"))
	if drawer == null:
		_check(false, "there is a thumbnail command (%s)" % THUMBNAIL)
		return
	var named: Dictionary = drawer.get_script_constant_map()
	var loop: GDScript = load(LOOP) if ResourceLoader.exists(LOOP) else null
	_check(loop != null and loop.get_script_constant_map().get("FLAG") == named.get("FLAG")
		and loop.get_script_constant_map().get("THUMBNAIL") == THUMBNAIL,
		"the loop and the drawer answer to one flag (%s)" % named.get("FLAG"))
	var corner: Vector3 = named.get("CORNER", Vector3.ZERO)
	_check(corner == ModelShot.ANGLES["corner"],
		"the picture is drawn from the app's corner (%s, ModelShot's %s)"
		% [corner, ModelShot.ANGLES["corner"]])


## Each part's geometry found in the catalogue's text is what JSON says
## it is: a sample of every kind of id, and every id with a character a
## pattern would read as its own.
func _lookup(drawer: GDScript) -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/generated/catalogue.json"))
	var truth: Dictionary = {}
	for entry: Variant in (raw as Dictionary)["parts"]:
		truth[str((entry as Dictionary)["id"])] = str((entry as Dictionary)["mesh"])
	var ids := PackedStringArray()
	var all: Array = truth.keys()
	var step: int = maxi(all.size() / 400, 1)
	for n: int in range(0, all.size(), step):
		ids.append(str(all[n]))
	for id: String in all:
		for c: String in id:
			if not (c.is_valid_identifier() or c.is_valid_int()):
				ids.append(id)
				break
	ids.append("no-such-part-here")
	var found: Dictionary = drawer.call(&"mesh_names", ids)
	var wrong: Array = []
	for id: String in ids:
		if str(found.get(id, "")) != str(truth.get(id, "")):
			wrong.append(id)
	_check(wrong.is_empty() and not found.has("no-such-part-here"),
		"the catalogue's text gives each of %d parts the geometry JSON does (%d wrong: %s)"
		% [ids.size() - 1, wrong.size(), wrong.slice(0, 5)])


## A small model with parts no library has among its own: Studio's, a
## number nobody uses, and a sub-model file that is not beside it.
func _write_unknown(path: String) -> void:
	var text: String = FileAccess.get_file_as_string("res://models/car.ldr")
	text += "\n1 4 0 -40 0 1 0 0 0 1 0 0 0 1 bl_nosuchsticker.dat\n" \
		+ "1 15 40 -40 0 1 0 0 0 1 0 0 0 1 99999zz9.dat\n" \
		+ "1 16 0 -80 0 1 0 0 0 1 0 0 0 1 wheel_not_here.ldr\n"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _one(label: String, model: String, library: PartLibrary) -> void:
	print("── %s: %s" % [label, model.get_file()])
	var picture: String = _out.path_join(label.replace(" ", "_") + ".png")
	DirAccess.remove_absolute(picture)
	var ran: Dictionary = await _draw(model, picture)
	var said: String = str(ran["said"])
	_check(int(ran["exit"]) == 0 and FileAccess.file_exists(picture),
		"drawn by the command (exit %d, %s)" % [int(ran["exit"]), said.strip_edges().right(160)])
	_check(int(ran["ms"]) <= MOST_MS, "in %d ms, start to exit (at most %d)"
		% [int(ran["ms"]), MOST_MS])
	if not FileAccess.file_exists(picture):
		return
	var image := Image.load_from_file(picture)
	_check(image.get_width() == 256 and image.get_height() == 256,
		"%d x %d px" % [image.get_width(), image.get_height()])
	var mask: PackedByteArray = _mask_of_picture(image)
	var share: float = _count(mask) / float(mask.size())
	_check(share > 0.08, "the model fills %.0f%% of it, on a clear ground" % (share * 100.0))
	var counted := RegEx.create_from_string("(\\d+) of (\\d+) parts drawn").search(said)
	var drawn: int = counted.get_string(1).to_int() if counted else 0
	var placed: int = counted.get_string(2).to_int() if counted else 0
	if label == "unknown parts":
		_check(drawn > 0 and drawn == placed - 3,
			"drawn without the 3 parts the library has not got (%d of %d)" % [drawn, placed])
	else:
		_check(drawn > 0 and drawn == placed, "every part drawn (%d of %d)" % [drawn, placed])
	await _against_the_app(label, model, library, mask)


## The engine again, as the thumbnailer runs it: {"exit", "ms", "said"}.
func _draw(model: String, picture: String) -> Dictionary:
	var began: int = Time.get_ticks_msec()
	var child: Dictionary = OS.execute_with_pipe(OS.get_executable_path(), ["--headless",
		"--path", ProjectSettings.globalize_path("res://"), "--thumbnail", model, picture, "256"],
		false)
	if child.is_empty():
		return {"exit": -1, "ms": 0, "said": "could not start the engine"}
	var pid: int = int(child["pid"])
	var said: String = ""
	var out: FileAccess = child["stdio"]
	while OS.is_process_running(pid) and Time.get_ticks_msec() - began < GIVE_UP_MS:
		said += out.get_as_text()
		await process_frame
	var ms: int = Time.get_ticks_msec() - began
	if OS.is_process_running(pid):
		OS.kill(pid)
		return {"exit": -1, "ms": ms, "said": said + " (still running after %d s: stopped)"
			% (GIVE_UP_MS / 1000)}
	said += out.get_as_text()
	var errors: FileAccess = child["stderr"]
	said += errors.get_as_text()
	return {"exit": OS.get_process_exit_code(pid), "ms": ms, "said": said}


## The app's own picture of the same parts from each corner, on the graphics
## card: the thumbnail's outline is the corner's, and nearer it than any
## other corner's.
func _against_the_app(label: String, model: String, library: PartLibrary,
		mask: PackedByteArray) -> void:
	if not ModelShot.possible():
		_check(false, "the app's corner picture to compare with (no window)")
		return
	var text: String
	if model.get_extension() == "io":
		text = str(StudioIo.model_ldr(FileAccess.get_file_as_bytes(model))["text"])
	else:
		text = FileAccess.get_file_as_string(model)
	var world := BrickWorld.new()
	world.library = library
	world.keeps_history = false
	root.add_child(world)
	await process_frame
	for placement: LdrModel.Placement in LdrModel.parse(text, model.get_file()).flatten(library.parts):
		if library.parts.has(placement.part_id):
			world.add_brick(placement.part_id, placement.color_code, placement.transform)
	var shot := ModelShot.new()
	shot.library = library
	shot.rulers = false
	shot.give_up_after = 120.0
	root.add_child(shot)
	var overlaps: Dictionary = {}
	for from: String in ["corner", "far corner", "back right", "front left"]:
		var image: Image = await shot.take(world, from)
		if image == null:
			continue
		if from == "corner":
			image.save_png(_out.path_join(label.replace(" ", "_") + "_app_corner.png"))
		overlaps[from] = _overlap(mask, _mask_of_shot(image))
	shot.queue_free()
	world.queue_free()
	await process_frame
	var corner: float = float(overlaps.get("corner", 0.0))
	var other: float = 0.0
	for from: String in overlaps:
		if from != "corner":
			other = maxf(other, float(overlaps[from]))
	_check(corner >= LEAST_OVERLAP and corner > other,
		"its outline is the app's corner picture's (%.3f of it shared, at least %.2f; "
		% [corner, LEAST_OVERLAP] + "the nearest other corner %.3f)" % other)


## The picture's model, where it is not clear: one byte a pixel, 1 or 0.
func _mask_of_picture(image: Image) -> PackedByteArray:
	image.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = image.get_data()
	var mask := PackedByteArray()
	mask.resize(data.size() / 4)
	for n: int in mask.size():
		mask[n] = 1 if data[n * 4 + 3] >= 128 else 0
	return mask


## ModelShot's model, where it is not its ground, at the thumbnail's size.
func _mask_of_shot(image: Image) -> PackedByteArray:
	image.convert(Image.FORMAT_RGB8)
	var ground := Color(0.93, 0.94, 0.96)
	var mask := PackedByteArray()
	mask.resize(256 * 256)
	var cell: int = image.get_width() / 256
	for y: int in 256:
		for x: int in 256:
			var colour: Color = image.get_pixel(x * cell + cell / 2, y * cell + cell / 2)
			var off: float = absf(colour.r - ground.r) + absf(colour.g - ground.g) \
				+ absf(colour.b - ground.b)
			mask[y * 256 + x] = 1 if off > 0.06 else 0
	return mask


## Intersection over union of two masks.
func _overlap(a: PackedByteArray, b: PackedByteArray) -> float:
	var both: int = 0
	var either: int = 0
	for n: int in mini(a.size(), b.size()):
		if a[n] != 0 and b[n] != 0:
			both += 1
		if a[n] != 0 or b[n] != 0:
			either += 1
	return float(both) / float(maxi(either, 1))


func _count(mask: PackedByteArray) -> int:
	var n: int = 0
	for value: int in mask:
		n += value
	return n
