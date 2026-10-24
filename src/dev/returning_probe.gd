## A returning person opens on their own latest model, not the example car.
##
##   godot --headless --path . --script src/dev/returning_probe.gd
##
## walk239 (2026-10-24, A16) and walk180 (D2): signed in on a new browser,
## a phone or a fresh desktop, a person whose account keeps their models
## was shown the example car a first visit is shown, not their work. A
## first visit keeps the car: it is what the sign-in screen dims behind it,
## for somebody to see what they are signing in to, and the browser flows
## start from it. Here the app starts as a first visit does, the car on the
## baseplate; then the account's look (CloudModels.looked) finds two
## models, the newer named first as the account lists them, each in the
## models here as a look fetches them. The car gives way to the newer, by
## its name, saved and unchanged. An account with no models leaves the car;
## and a car a person has touched is never replaced.
extends SceneTree

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _world: BrickWorld


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	Engine.max_fps = 0
	CustomParts.keeps = false
	CustomParts.dir = "user://returning_probe_parts/"
	# Two models of theirs, as a look writes them among the models here.
	DirAccess.make_dir_recursive_absolute(ModelStore.SAVE_DIR)
	_write("Older Tower", ["0 FILE older tower.ldr", "0 Older Tower", "0 Name: older tower.ldr",
		"1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat"])
	_write("Taco Truck", ["0 FILE taco truck.ldr", "0 Taco Truck", "0 Name: taco truck.ldr",
		"1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat", "1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 15 0 -72 0 1 0 0 0 1 0 0 0 1 3001.dat"])
	await _start()
	var car: int = _built()
	_check("a first visit starts on the example car (%d parts, \"%s\")" % [car, _store.title],
		car > 20 and bool(_main.get("_sample_untouched")))

	print("the account's look finds two models, the taco truck saved last")
	await _look("Taco Truck")
	_check("the car gives way to the person's latest model: \"%s\", %d parts" % [_store.title, _built()],
		_store.title == "Taco Truck" and _built() == 3)
	_check("...opened as File, Open opens it, nothing to save", not _store.has_unsaved_work())

	print("an account with no models")
	_main.queue_free()
	await process_frame
	await process_frame
	await _start()
	await _look("")
	_check("the example car stays (%d parts, \"%s\")" % [_built(), _store.title], _built() > 20)

	print("a car somebody has touched")
	var builder: Builder = _main.get("_builder")
	builder.held_part = "3001"
	builder.put_part("3001", 4, Transform3D(Basis.IDENTITY, Vector3(200, 24, 200)))
	(_main.get("_builder") as Builder).placed.emit(_last(), "3001")
	await process_frame
	var touched: int = _built()
	await _look("Taco Truck")
	_check("it is never replaced (%d parts, \"%s\")" % [_built(), _store.title],
		_built() == touched and _store.title != "Taco Truck")

	print("")
	print("returning: %s" % ("all checks passed" if _failures == 0 else "%d check(s) FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _start() -> void:
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: Node = _main.get("_playback")
	if playback != null:
		playback.call("stop")
	_store = _main.get("_store")
	_world = _main.get("_world")
	for _n: int in 30:
		await process_frame


## The account's look, as CloudModels makes one: its newest model named,
## and the look said done.
func _look(newest: String) -> void:
	var cloud: Node = _main.get("_cloud")
	if cloud == null or not cloud.has_signal("looked"):
		print("    (no CloudModels.looked here)")
		return
	cloud.set("newest", newest)
	cloud.emit_signal("looked")
	for _n: int in 120:
		await process_frame


func _write(name: String, lines: Array) -> void:
	var file: FileAccess = FileAccess.open(ModelStore.SAVE_DIR + name + ".ldr", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()


func _built() -> int:
	return _world.brick_count() - _store.scenery.size()


func _last() -> int:
	var last: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		last = maxi(last, brick.id)
	return last
