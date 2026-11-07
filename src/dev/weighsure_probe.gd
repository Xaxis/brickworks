## One weight for one model, and one style of number on a line
## (docs/APP_UX6.md, weighsure).
##
##   godot --path . --resolution 1280x720 --script src/dev/weighsure_probe.gd
##   tools/probe.sh weighsure_probe        (PROBE_SIZE=1400x900 for the other)
##   ... -- --shots=DIR    the pictures there, not in shots/weighsure/
##
## The walk's eight 1 x 4s read 8 g just built, 13 g with the next part in
## hand, 12 g after one was turned and put back, then 13 g again: the status
## bar said the stability check's sum, made at most once a second on a
## worker, an earlier model's. And the car's size read "4½ × 10.8 studs ·
## 3.6 × 8.64 × 4.96 cm", a fraction beside a decimal and one place beside
## two. The bar, read in every frame as it is drawn:
## 1. the car, as the app opens it at its start and as Open opens it: every
##    weight the status bar says, from its first, is 52 g;
## 2. the walk's wall, built as the walk builds it (the search, a tile, eight
##    clicks): from the frame the last is down, through the ghost swept over
##    it with the next part in hand, R on a brick in it (in hand, turned) and
##    that brick put down, every frame with the eight down reads their
##    weight; and every frame, the one in hand too, reads the weight of the
##    bricks the model holds then;
## 3. every model tested_models opens weighs the same with no shapes loaded
##    and with all: the status bar's weight (ModelSize; with none, every part
##    on its way), and the balance's (Balance.measure, check_design's grams)
##    read on a worker with half the shapes loaded;
## 4. the car's size reads "4.5 × 10.8 studs, 15 plates high · 3.60 × 8.64 ×
##    4.96 cm", and no size or place the bar says puts a fraction beside a
##    decimal, or a centimetre to other than two places.
##
## The data folder is the run's own (probe.sh gives one).
extends SceneTree

## The car's weight, as the walk read it.
const CAR := "52 g"
const CAR_SIZE := "4.5 × 10.8 studs, 15 plates high · 3.60 × 8.64 × 4.96 cm"
const SHIPPED: Array[String] = ["res://models/kart.ldr", "res://models/castle.ldr",
	"res://models/orrery.ldr"]
const AMBULANCE := "res://vendor/omr/files/6680-1.mpd"
const MISPLACED := "1 16 30 -16 150 0 0 1 0 1 0 -1 0 0 3023.dat"
const TWO_BUILDS: Array[String] = ["res://vendor/omr/files/620-1.mpd",
	"res://vendor/omr/files/6511-1.mpd"]
const ORTHANC := "res://models/orthanc.ldr"
const BENCH := "res://src/dev/fixtures/bench/"

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _camera: CadCamera
var _bin: PartsBin
var _shots: String = ""
var _size: String = ""
## Every frame as drawn, while watched: [what is going on, the model's
## parts, the weight said, the counts said].
var _seen: Array = []
var _phase: String = ""
## Every size and place line the bar said.
var _lines: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ShellPrefs.kept_by_a_check = _own_data_folder()
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.substr(8)
	if _shots.is_empty():
		_shots = ProjectSettings.globalize_path("res://shots/weighsure")
	DirAccess.make_dir_recursive_absolute(_shots)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_size = "%dx%d" % [root.size.x, root.size.y]
	print("── a %s window ──" % _size)
	# From the app's first frame: what the bar says as each is drawn.
	RenderingServer.frame_pre_draw.connect(_watch)
	_phase = "start"
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_world = _main.get("_world")
		if _world != null and _world.brick_count() > 1 and _main.get("_shell") != null:
			break
	if _world == null or _main.get("_shell") == null:
		print("  weighsure probe: SKIPPED — the window did not come up")
		quit(3)
		return
	_shell = _main.get("_shell")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_camera = _main.get("_camera")
	_bin = _main.get("_bin")
	_store.keeps = false
	Keymap.reset()
	Keymap.use("brickworks")
	await _until_laid()
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(10)

	_the_car_at_start()
	await _the_car_opened()
	await _the_car_size()
	await _the_wall()
	await _tested_models()
	_one_style()

	RenderingServer.frame_pre_draw.disconnect(_watch)
	Keymap.use("brickworks")
	Keymap.reset()
	print("")
	if _failures == 0:
		print("weighsure probe: all checks passed")
	else:
		print("weighsure probe: %d check(s) FAILED" % _failures)
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


## Each frame as it is drawn: the input of the frame handled and every
## node's processing done, the bar's words as a person reads them.
func _watch() -> void:
	if _phase.is_empty():
		return
	var shell: Shell = _main.get("_shell") if _main != null else null
	var world: BrickWorld = _main.get("_world") if _main != null else null
	var store: ModelStore = _main.get("_store") if _main != null else null
	if shell == null or shell.status == null or world == null:
		return
	var fields: Dictionary = shell.status.fields()
	var counts: String = str(fields.get("counts", ""))
	var parts: int = world.brick_count() - (store.scenery.size() if store != null else 0)
	_seen.append([_phase, parts, _weight_of(counts), counts])
	for key: String in ["size", "place"]:
		var line: String = str(fields.get(key, ""))
		if not line.is_empty():
			_lines[line] = true


## The grams the counts' line ends with, as said: "52 g", or "".
static func _weight_of(counts: String) -> String:
	var found: RegExMatch = RegEx.create_from_string(r"(\d+ g)$").search(counts)
	return found.get_string(1) if found != null else ""


## The frames of [param phases] seen since [param from].
func _frames_of(phases: Array, from: int = 0) -> Array:
	return _seen.slice(from).filter(func(one: Array) -> bool: return str(one[0]) in phases)


## What [param frames] said, each weight once, in order: "52 g ×300".
static func _said(frames: Array) -> String:
	var runs := PackedStringArray()
	var last: String = "?"
	var run: int = 0
	for one: Array in frames:
		var weight: String = str(one[2]) if not str(one[2]).is_empty() else "(none)"
		if weight == last:
			run += 1
			continue
		if run > 0:
			runs.append("%s ×%d" % [last, run])
		last = weight
		run = 1
	if run > 0:
		runs.append("%s ×%d" % [last, run])
	return ", ".join(runs)


# -- 1: the car's weight from its first number ------------------------------------------

func _the_car_at_start() -> void:
	var frames: Array = _frames_of(["start"])
	var said: Array = frames.filter(func(one: Array) -> bool: return not str(one[2]).is_empty())
	var other: Array = said.filter(func(one: Array) -> bool: return str(one[2]) != CAR)
	_check("1: the app's start, the car: every weight said from the first is %s (%d frames: %s)"
		% [CAR, frames.size(), _said(frames)], not said.is_empty() and other.is_empty())


func _the_car_opened() -> void:
	var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(
		"res://models/car.ldr"))
	var bar: ModelBar = _main.get("_bar")
	var from: int = _seen.size()
	_phase = "open"
	var result: Dictionary = await bar.open_text_with_progress(text, "car")
	bar.opened.emit(int(result["placed"]))
	await _until_laid()
	# Past the weighing's second, and its worker's.
	await create_timer(2.0).timeout
	await _frames(10)
	var frames: Array = _frames_of(["open"], from)
	var said: Array = frames.filter(func(one: Array) -> bool:
		return not str(one[2]).is_empty() and int(one[1]) > 0)
	var other: Array = said.filter(func(one: Array) -> bool: return str(one[2]) != CAR)
	_check("1: Open, the car: every weight said from the first is %s (%d frames: %s)"
		% [CAR, frames.size(), _said(frames)], not said.is_empty() and other.is_empty())
	_phase = "idle"


# -- 4: the car's size in one style -----------------------------------------------------

func _the_car_size() -> void:
	_builder.clear_selection()
	await _frames(6)
	var said: String = str(_shell.status.fields().get("size", ""))
	_check("4: the car's size reads \"%s\" (\"%s\")" % [CAR_SIZE, said], said == CAR_SIZE)
	await _shot_bar("car")
	# A selection's, as modelinfo picks them: a 2 x 4 plate, the eight 1 x 2
	# plates, a tyre on its edge.
	for which: Array in [["3020", 1], ["3023b", 8], ["3641", 1]]:
		_builder.clear_selection()
		var picked: int = 0
		for brick: BrickWorld.Brick in _model():
			if brick.part_id == str(which[0]) and picked < int(which[1]):
				_builder.select_brick(brick.id, picked > 0)
				picked += 1
		await _frames(4)
		var line: String = str(_shell.status.fields().get("size", ""))
		print("  %d x %s selected: \"%s\"" % [picked, which[0], line])
	_builder.clear_selection()
	await _frames(4)


# -- 2: the walk's wall -------------------------------------------------------------------

## Four 1 x 4 bricks in a row and four more on them, half a brick along, as
## appux_walk builds them; then the ghost swept over them with the next in
## hand (Q), and R on one of them in the wall, put down turned.
func _the_wall() -> void:
	_main.call("clear_model")
	await _frames(30)
	_camera.frame(AABB(Vector3(-200, -40, -120), Vector3(400, 120, 240)))
	await _frames(40)
	var search: LineEdit = _bin.get("_search")
	await _click(search.get_global_rect().get_center())
	await _key(KEY_A, true)
	await _type("1x4 brick")
	await create_timer(0.35).timeout
	await _frames(4)
	var grid: GridContainer = _bin.get("_grid")
	var first: Control = grid.get_child(0)
	var part: String = str(first.get_meta("part", "?"))
	await _click(first.get_global_rect().get_center())
	await _frames(6)
	var from: int = _seen.size()
	_phase = "building"
	for row: int in 2:
		for n: int in 4:
			if _count() == 7:
				# The last: watched from the frame it is down.
				_phase = "the last"
			var at := Vector3(-120 + n * 80 + row * 40, row * 24, 0)
			var spot: Vector2 = _camera.unproject_position(at + Vector3(0, 24, 0))
			await _move(spot)
			await _move(spot + Vector2(1, 0))
			await _click(spot + Vector2(1, 0))
	await _key(KEY_ESCAPE)
	_phase = "built"
	await _frames(20)
	await _shot("wall")
	print("  the wall: %d parts of %s" % [_count(), part])
	# The ghost swept across it, the next part in hand.
	_phase = "in hand"
	await _key(KEY_Q)
	for n: int in 40:
		await _move(_camera.unproject_position(Vector3(-160 + n * 8, 48, 0)))
	await _shot("ghost_over_wall")
	await _key(KEY_ESCAPE)
	await _frames(10)
	# R on a brick in the wall: in hand, turned 15°; then put down.
	var one: BrickWorld.Brick = _model()[0]
	_builder.clear_selection()
	_builder.selection[one.id] = true
	_builder.selection_changed.emit(1)
	await _frames(10)
	_shell.set_turn_step(15)
	await _frames(5)
	_phase = "turned in hand"
	await _key(KEY_R)
	var lifted: bool = _world.get_brick(one.id) == null and _builder.is_carrying()
	if lifted:
		var spot: Vector2 = _camera.unproject_position(Vector3(-120, 24, 160))
		await _move(spot)
		await _frames(20)
		_phase = "put down"
		await _click(spot + Vector2(1, 0))
	_phase = "put down"
	# Past the stability check's second, and its worker's.
	await create_timer(2.0).timeout
	await _frames(10)
	await _shot("turned_down")
	await _key(KEY_ESCAPE)
	_builder.clear_selection()
	await _frames(10)
	_phase = "idle"
	var grams: float = Stability.grams(_library.parts[part])
	var eight: String = "%.0f g" % (grams * 8)
	var frames: Array = _frames_of(["the last", "built", "in hand", "turned in hand", "put down"],
		from)
	var down: Array = frames.filter(func(one_frame: Array) -> bool: return int(one_frame[1]) == 8)
	var wrong: Array = down.filter(func(one_frame: Array) -> bool:
		return str(one_frame[2]) != eight)
	_check(("2: the eight 1 x 4s read %s in every frame they are all down, from the last placed, "
		+ "with the next part in hand and after one is turned and put down (%d frames: %s)")
		% [eight, down.size(), _said(down)], down.size() > 100 and wrong.is_empty())
	for phase: String in ["the last", "built", "in hand", "put down"]:
		var these: Array = _frames_of([phase], from)
		print("    %-15s %s" % [phase, _said(these)])
	var held: Array = _frames_of(["turned in hand"], from)
	print("    %-15s %s (parts down: %s)" % ["turned in hand", _said(held),
		", ".join(_parts_in(held))])
	_check("2: R on a brick in the wall put it in hand, and it went down: %d parts" % _count(),
		lifted and _count() == 8)
	# Each frame's weight the model's as it is in that frame: the brick in
	# hand is off the model, as its count says.
	var mismatched: Array = frames.filter(func(one_frame: Array) -> bool:
		return str(one_frame[2]) != "%.0f g" % (grams * int(one_frame[1])))
	_check("2: every frame's weight is the bricks down then (%d frames, %d not: %s)"
		% [frames.size(), mismatched.size(), _said(mismatched)], mismatched.is_empty())


## The parts down in [param frames], each count once.
static func _parts_in(frames: Array) -> PackedStringArray:
	var counts: Dictionary = {}
	for one: Array in frames:
		counts[str(one[1])] = true
	return PackedStringArray(counts.keys())


# -- 3: every model tested_models opens, no shapes and all ------------------------------

func _tested_models() -> void:
	print("\n  3: tested_models' models, weighed with no shapes loaded and with all")
	var bare: PartLibrary = _bare_library()
	if bare == null:
		_check("3: a library with the catalogue and no shapes", false)
		return
	_half = PartLibrary.new()
	_half.load_catalogue()
	var models: Array = []
	var stack: Array = [[["3001", 4, Vector3(0, 0, 0)]], [["3001", 1, Vector3(0, -24, 0)]],
		[["3069b", 14, Vector3(-20, -32, -10)]]]
	models.append(["tiled", _ldr("tiled", stack)])
	models.append(["resting", _ldr("resting", stack + [[["3004", 2, Vector3(-20, -56, -10)]]])])
	models.append(["two", _ldr("two", stack.slice(0, 2)
		+ [[["3001", 1, Vector3(200, 0, 0)]], [["3001", 2, Vector3(200, -24, 0)]]])])
	models.append(["against", _ldr("against", stack.slice(0, 2)
		+ [[["3003", 1, Vector3(50, 0, 0)]]])])
	models.append(["rim", _ldr("rim", [[["11213", 71, Vector3(80, -8, -100)]],
		[["54200", 71, Vector3(50, -8, -150)]]])])
	var filed: String = FileAccess.get_file_as_string(AMBULANCE)
	models.append([AMBULANCE.get_file(), filed])
	models.append([AMBULANCE.get_file() + " mended", filed.replace(MISPLACED, "0 // " + MISPLACED)])
	for path: String in TWO_BUILDS + SHIPPED:
		models.append([path.get_file(), FileAccess.get_file_as_string(path)])
	for file: String in DirAccess.get_files_at(BENCH):
		models.append([file, FileAccess.get_file_as_string(BENCH + file)])
	models.append([ORTHANC.get_file(), FileAccess.get_file_as_string(ORTHANC)])
	var same: int = 0
	var balanced: int = 0
	for model: Array in models:
		var name: String = model[0]
		var all: Dictionary = await _weigh(str(model[1]), name, _library, true)
		var none: Dictionary = await _weigh(str(model[1]), name, bare, false)
		var alike: bool = all["said"] == none["said"] and absf(float(all["grams"])
			- float(none["grams"])) < 0.01 and int(all["parts"]) > 0
		same += 1 if alike else 0
		var balance_alike: bool = absf(float(all["balance"]) - float(all["half"])) < 0.01
		balanced += 1 if balance_alike else 0
		print("    %s %-28s all shapes: %s (%d down); none: %s (%d down, %d on their way); "
			% ["ok  " if alike else "FAIL", name, all["said"], int(all["parts"]),
				none["said"], int(none["down"]), int(none["coming"])]
			+ "the balance %.2f g, with half the shapes on a worker %.2f g%s"
			% [float(all["balance"]), float(all["half"]), "" if balance_alike else "  FAIL"])
	_check("3: every model weighs the same with no shapes loaded and with all: %d of %d"
		% [same, models.size()], same == models.size())
	_check("3: ...and the balance weighs the same with half the shapes loaded as with all: %d of %d"
		% [balanced, models.size()], balanced == models.size())


## A library with the whole catalogue and no shape at all: what a browser
## has before the parts it opens are fetched. Its root is a folder of its own
## with the catalogue and the colours, and no parts.
func _bare_library() -> PartLibrary:
	var folder: String = "user://weighsure_bare/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for file: String in ["catalogue.json", "colors.json"]:
		var copied: Error = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(PartLibrary.FULL_ROOT + file),
			ProjectSettings.globalize_path(folder + file))
		if copied != OK:
			return null
	var bare := PartLibrary.new()
	bare.set("_root", folder)
	if not bare.load_catalogue(folder + "catalogue.json"):
		return null
	return bare


## [param text] opened in a world of its own on [param library], as the app
## opens a file: {said: the status bar's weight, grams, parts (down and on
## their way), down, coming}; with [param balance], the balance's weight with
## every shape, and on a worker with half the parts' shapes loaded.
func _weigh(text: String, name: String, library: PartLibrary, balance: bool) -> Dictionary:
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	await process_frame
	store.open_text(text, name)
	await _frames(2)
	var coming: Array = _coming(store)
	var size: ModelSize = _of_model(world, library, store.scenery, coming)
	var out: Dictionary = {"said": "%.0f g" % size.grams,
		"grams": size.grams, "parts": size.parts, "down": world.brick_count() - store.scenery.size(),
		"coming": coming.size()}
	if balance:
		var bricks: Array = world.bricks()
		var judge := Balance.new()
		judge.library = library
		judge.lattice = builder.lattice
		judge.floor_ids = store.scenery
		out["balance"] = judge.measure(bricks).grams
		out["half"] = await _half_balance(world, builder, store, bricks)
	world.clear()
	world.queue_free()
	builder.queue_free()
	await _frames(2)
	return out


## A library the balance reads half the shapes from.
var _half: PartLibrary = null


## The balance's weight of [param bricks] read on a worker, as the status
## bar's weighing reads it, from a library with every other part's shape
## loaded and the rest not yet; a part made from the file (always to hand in
## the app) with its shape.
func _half_balance(world: BrickWorld, builder: Builder, store: ModelStore, bricks: Array) -> float:
	var half: PartLibrary = _half
	half.release_geometry()
	for id: String in _library.custom:
		var info: PartLibrary.PartInfo = _library.parts.get(id)
		var made: Lbm.PartMesh = _library.get("_custom_meshes").get(info.mesh_hash) \
			if info != null else null
		if made != null and not half.custom.has(id):
			half.add_custom(info, made, str(_library.custom[id]))
	var ids: Array = []
	for brick: BrickWorld.Brick in bricks:
		if not brick.part_id in ids:
			ids.append(brick.part_id)
	for n: int in range(0, ids.size(), 2):
		half.mesh_for(str(ids[n]))
	var judge := Balance.new()
	judge.library = half
	judge.lattice = builder.lattice.copy_for_reading()
	judge.floor_ids = store.scenery.duplicate()
	var still: BrickWorld = world.copy_for_reading()
	var weighed: Array = [0.0]
	half.begin_reading()
	var task: int = WorkerThreadPool.add_task(func() -> void:
		weighed[0] = judge.measure(still.bricks()).grams)
	while not WorkerThreadPool.is_task_completed(task):
		await process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	half.end_reading(task)
	still.free()
	return float(weighed[0])


## The parts of [param store]'s model on their way, as the status bar counts
## them (ModelSize.coming); none where this build does not.
func _coming(store: ModelStore) -> Array:
	var sizes: GDScript = load("res://src/assembly/model_size.gd")
	if _has_static(sizes, "coming"):
		return sizes.call("coming", store)
	return []


func _of_model(world: BrickWorld, library: PartLibrary, scenery: Dictionary,
		coming: Array) -> ModelSize:
	var sizes: GDScript = load("res://src/assembly/model_size.gd")
	if _has_static(sizes, "coming"):
		return sizes.callv("of_model", [world, library, scenery, coming])
	return sizes.callv("of_model", [world, library, scenery])


static func _has_static(script: Script, method: String) -> bool:
	for one: Dictionary in script.get_script_method_list():
		if str(one["name"]) == method:
			return true
	return false


## A model in its author's steps, as tested_models writes them: each step a
## list of [part, colour, where].
static func _ldr(name: String, steps: Array) -> String:
	var lines := PackedStringArray(["0 FILE %s.ldr" % name, "0 %s" % name, "0 Name: %s.ldr" % name,
		"0 Author: weighsure probe", ""])
	for step: Array in steps:
		for one: Array in step:
			var at: Vector3 = one[2]
			lines.append("1 %d %d %d %d 1 0 0 0 1 0 0 0 1 %s.dat" % [int(one[1]),
				int(at.x), int(at.y), int(at.z), str(one[0])])
		lines.append("0 STEP")
	return "\r\n".join(lines) + "\r\n"


# -- 4: one style a line --------------------------------------------------------------------

## Every size and place line the bar said, through the whole run: studs and
## plates all in quarters or all in decimals, and centimetres to two places.
func _one_style() -> void:
	var mixed := PackedStringArray()
	for line: String in _lines:
		var studs: String = line.get_slice(" · ", 0) if line.contains(" cm") else line
		var fraction: bool = studs.contains("¼") or studs.contains("½") or studs.contains("¾")
		var decimal: bool = RegEx.create_from_string(r"\d\.\d").search(studs) != null
		# A decimal's trailing nought: "15.0 plates high" beside "4.5".
		var nought: bool = RegEx.create_from_string(r"\d\.\d*0(?!\d)").search(studs) != null
		var cm_ok: bool = true
		if line.contains(" cm"):
			for number: String in line.get_slice(" · ", 1).trim_suffix(" cm").split(" × "):
				cm_ok = cm_ok and RegEx.create_from_string(r"^\d+\.\d\d$").search(number) != null
		if (fraction and decimal) or nought or not cm_ok:
			mixed.append("\"%s\"" % line)
	print("  4: %d lines said: %s" % [_lines.size(), ", ".join(PackedStringArray(_lines.keys().slice(0, 8)))])
	_check("4: every size and place said is in one style, no decimal's nought, centimetres to two places (%d of %d not%s)"
		% [mixed.size(), _lines.size(), "" if mixed.is_empty() else ": " + ", ".join(mixed.slice(0, 6))],
		mixed.is_empty() and _lines.size() >= 4)


# -- helpers ---------------------------------------------------------------------------------

func _until_laid() -> void:
	for _n: int in 3000:
		if not _world.is_being_laid() and not _store.laying:
			return
		await process_frame


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
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _type(text: String) -> void:
	for n: int in text.length():
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
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join("%s_%s.png" % [name, _size]))


## The status bar alone, at twice its size, to read its words.
func _shot_bar(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var scale: Vector2 = Vector2(image.get_size()) / root.get_visible_rect().size
	var bar: Rect2 = _shell.status.get_global_rect()
	var cut := Rect2i(Vector2i(bar.position * scale), Vector2i(bar.size * scale))
	var strip: Image = image.get_region(cut.intersection(Rect2i(Vector2i.ZERO, image.get_size())))
	strip.resize(strip.get_width() * 2, strip.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	strip.save_png(_shots.path_join("%s_bar_%s.png" % [name, _size]))


func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _check(what: String, held: bool) -> void:
	print("  %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1
