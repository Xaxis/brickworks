extends SceneTree

# Implements the proposal's landing animation exactly as specified and
# runs its own stated assertion: after `finished`, every brick's
# transform equals the one it had before playback started.

const DROP := 48.0
const LAND_MS := 130.0
const TARGET_MS := 3600.0
const FASTEST_MS := 45.0
const SLOWEST_MS := 320.0

var world: BrickWorld
var library: PartLibrary
var steps: Array[Instructions.Step] = []
var showing: Dictionary = {}
var at: int = 0
var per_step: float = 100.0
var clock: float = 0.0
var running: bool = false
var flight: Array = []
var launch_queue: Array = []   # {id, due, to}
var elapsed: float = 0.0
var peak_flight: int = 0
var _saved: bool = false
var _save_off: int = 0
var _save_worst: float = 0.0
var _interrupt_off: int = 0

func _initialize() -> void:
	await process_frame
	library = PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue"); quit(1); return
	world = BrickWorld.new()
	world.library = library
	root.add_child(world)

	for name: String in ["tower", "house", "lighthouse"]:
		await _run(name)
	quit(0)

func _run(name: String) -> void:
	world.clear()
	var model: LdrModel = LdrModel.load_file("res://models/%s.ldr" % name)
	var before: Dictionary = {}
	for item: Variant in model.flatten(library.parts):
		var p: LdrModel.Placement = item
		var id: int = world.add_brick(p.part_id, p.color_code, p.transform)
		if id != 0:
			before[id] = p.transform
	await process_frame

	steps = Instructions.plan(world, library)
	showing = {}
	at = 0
	clock = 0.0
	elapsed = 0.0
	flight.clear()
	launch_queue.clear()
	peak_flight = 0
	_saved = false
	_save_off = 0
	_save_worst = 0.0
	running = true
	per_step = clampf(TARGET_MS / float(steps.size()), FASTEST_MS, SLOWEST_MS)
	world.show_only(showing)
	_advance()

	# 60 fps, in ms.
	var dt: float = 1000.0 / 60.0
	var guard: int = 0
	while running and guard < 5000:
		guard += 1
		elapsed += dt
		_tick(dt)

	# The proposal's own assertion.
	var off: int = 0
	var worst: float = 0.0
	for id: int in before:
		var brick: BrickWorld.Brick = world.get_brick(id)
		var d: float = brick.transform.origin.distance_to((before[id] as Transform3D).origin)
		if d > 0.0001:
			off += 1
			worst = maxf(worst, d)
	print("%-11s %3d bricks, %2d steps, per_step %.0f ms, peak in flight %d" % [
		name, before.size(), steps.size(), per_step, peak_flight])
	print("            after finished: %d bricks NOT back on their cell, worst %.1f LDU"
		% [off, worst])
	print("            autosave at t=2500ms would write %d bricks off-cell, worst %.1f LDU"
		% [_save_off, _save_worst])

func _tick(dt: float) -> void:
	# _process: advance flight
	var i: int = flight.size() - 1
	while i >= 0:
		var e: Dictionary = flight[i]
		e["t"] += dt / LAND_MS
		if e["t"] >= 1.0:
			world.move_brick(e["id"], e["to"])
			flight.remove_at(i)
		else:
			var t: float = e["t"]
			var s: float = t * t * (3.0 - 2.0 * t)
			world.move_brick(e["id"], (e["from"] as Transform3D).interpolate_with(e["to"], s))
		i -= 1
	# staggered launches
	var j: int = launch_queue.size() - 1
	while j >= 0:
		var q: Dictionary = launch_queue[j]
		if elapsed >= q["due"]:
			_launch(q["id"])
			launch_queue.remove_at(j)
		j -= 1
	peak_flight = maxi(peak_flight, flight.size())
	# What the autosave would write. main.gd fires touch() in the `built`
	# handler, one frame before play(); ModelStore.AUTOSAVE_DELAY_MS is
	# 2500 and TARGET_MS is 3600, so tick() writes mid-assembly.
	if not _saved and elapsed >= 2500.0:
		_saved = true
		_save_off = flight.size()
		_save_worst = 0.0
		for e: Dictionary in flight:
			var b: BrickWorld.Brick = world.get_brick(e["id"])
			_save_worst = maxf(_save_worst,
				b.transform.origin.distance_to((e["to"] as Transform3D).origin))

	clock += dt
	while clock >= per_step and running:
		clock -= per_step
		_advance()

func _launch(id: int) -> void:
	var brick: BrickWorld.Brick = world.get_brick(id)
	var to: Transform3D = brick.transform
	var from := Transform3D(to.basis, to.origin + Vector3(0.0, DROP, 0.0))
	world.move_brick(id, from)
	flight.append({"id": id, "from": from, "to": to, "t": 0.0})

func _advance() -> void:
	if at >= steps.size():
		_stop()
		return
	var ids: PackedInt64Array = steps[at].brick_ids
	var stagger: float = per_step / float(ids.size())
	var n: int = 0
	for id: int in ids:
		showing[id] = true
		if n == 0:
			_launch(id)
		else:
			launch_queue.append({"id": id, "due": elapsed + stagger * n})
		n += 1
	at += 1
	world.show_only(showing)

func _stop() -> void:
	running = false
	world.show_only({})
