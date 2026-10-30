## A 10,000-part model answers at once (docs/APP_UX2.md, bigmodels), and
## what was made fast answers as it did when it was slow.
##
##   godot --path . --resolution 1400x900 --script src/dev/bigmodels_probe.gd \
##       [-- --only=hidden,quick,joined,ghost,replace]
##
## command_probe holds the times (--within). This holds the answers, on the
## castle and on Orthanc's 10,105 parts:
##
##   hidden    what the card's tally finds seen (SeenParts._tallied) is what
##             reading every picture back finds, part for part, side for
##             side, from below and from a table; and Orthanc measured as
##             the panel measures it takes seconds, not twenty;
##   joined    Everything connected from one part of Orthanc finds what
##             asking every part across every side finds (SelectBy.sideways
##             leaves most sides unasked), and with all of it selected it
##             stops at once;
##   ghost     all of Orthanc in hand is drawn as instances, every surface of
##             every part once, in its colour, and on the screen;
##   replace   a 2 x 4 in place of every part of Orthanc swaps where it has
##             room and leaves the rest standing, the lattice as it was, one
##             undo.
##
## Needs a window: what is hidden is measured from pictures.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _verbs: EditVerbs
var _library: PartLibrary


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _ms(from: int) -> int:
	return (Time.get_ticks_usec() - from) / 1000


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if not SeenParts.possible():
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	(_main.get("_playback") as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_library = _main.get("_library")

	var only: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7).split(",", false)
	if only.is_empty() or only.has("hidden"):
		await _open("castle")
		await _hidden_alike("castle", 128, 2)
	await _open("orthanc")
	if only.is_empty() or only.has("hidden"):
		await _hidden_alike("orthanc", 26, 1)
	if only.is_empty() or only.has("hidden") or only.has("quick"):
		await _hidden_quick()
	if only.is_empty() or only.has("joined"):
		await _joined()
	if only.is_empty() or only.has("ghost"):
		await _ghost()
	if only.is_empty() or only.has("replace"):
		await _replace()

	_world.clear()
	await _frames(10)
	_main.queue_free()
	await _frames(10)
	print("bigmodels: %s" % ("all held" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


func _open(model: String) -> void:
	var bar: ModelBar = _main.get("_bar")
	var placed: int = await bar.open_with_progress("res://models/%s.ldr" % model)
	bar.opened.emit(placed)
	await _frames(60)
	print("%s: %d parts" % [model, _world.brick_count()])


func _seen() -> SeenParts:
	var panel: HiddenColoursPanel = _main.get("_hidden_colours")
	return panel.get("_seen")


## The tally and the read-back, from [param views] sides drawn [param
## samples] times each, agree on every part and every side.
func _hidden_alike(model: String, views: int, samples: int) -> void:
	var seen: SeenParts = _seen()
	var bricks: Array = HiddenColours.bricks_of(_world, _verbs.scenery)
	seen.read_back = false
	var t: int = Time.get_ticks_usec()
	var tallied: SeenParts.Result = await seen.measure(bricks, views, SeenParts.FINEST, -1, samples)
	var tally_ms: int = _ms(t)
	seen.read_back = true
	t = Time.get_ticks_usec()
	var read: SeenParts.Result = await seen.measure(bricks, views, SeenParts.FINEST, -1, samples)
	var read_ms: int = _ms(t)
	seen.read_back = false
	print("    %s, %d sides x %d: tally %d ms, read back %d ms; %d seen, %d hidden" % [model,
		views, samples, tally_ms, read_ms, read.seen.size(), read.hidden().size()])
	_check("%s: both measures complete" % model, tallied.complete and read.complete)
	_check("%s: the tally sees what reading back sees (%d and %d parts)" % [model,
		tallied.seen.size(), read.seen.size()], _same(tallied.seen, read.seen))
	_check("%s: and from a table (%d and %d)" % [model, tallied.seen_on_table.size(),
		read.seen_on_table.size()], _same(tallied.seen_on_table, read.seen_on_table))
	var differ: String = ""
	for side: int in mini(tallied.per_view.size(), read.per_view.size()):
		if tallied.per_view[side] != read.per_view[side]:
			differ = ", side %d shows %d and %d" % [side, tallied.per_view[side],
				read.per_view[side]]
			break
	_check("%s: side by side, each side shows as many parts (%d and %d sides%s)" % [model,
		tallied.per_view.size(), read.per_view.size(), differ],
		tallied.per_view == read.per_view)
	_check("%s: something is hidden and something seen" % model,
		not read.hidden().is_empty() and not read.seen.is_empty())


func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: Variant in a:
		if not b.has(key):
			return false
	return true


## Orthanc measured as the panel measures it (every side, twice): in
## seconds, where reading every picture back took 17 to 23 s (bigmodels).
## The time it is held to is command_probe's (--within): on a box this
## shared it is the bound that would fail, not the tally.
func _hidden_quick() -> void:
	var seen: SeenParts = _seen()
	var bricks: Array = HiddenColours.bricks_of(_world, _verbs.scenery)
	var most: Array = [0, 0]
	var sample: Callable = func() -> void:
		most[0] = maxi(most[0], RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		most[1] = maxi(most[1], RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	process_frame.connect(sample)
	var t: int = Time.get_ticks_usec()
	var result: SeenParts.Result = await seen.measure(bricks)
	var took: int = _ms(t)
	process_frame.disconnect(sample)
	print("    orthanc, %d sides x %d: %d ms, %d hidden; a frame drew at most %d primitives in %d calls"
		% [result.views, result.samples, took, result.hidden().size(), most[0], most[1]])
	_check("orthanc measured from every side in %d ms (5,000 or less)" % took,
		result.complete and result.views == SeenParts.directions(SeenParts.VIEWS).size()
		and took <= 5000)


## Everything connected, from one part: what the full search finds.
func _joined() -> void:
	var lattice: BrickLattice = _builder.lattice
	var scenery: Dictionary = _verbs.scenery
	var one: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not scenery.has(brick.id):
			one = [brick.id]
			break
	var t: int = Time.get_ticks_usec()
	var found: Array = SelectBy.connected(_world, lattice, one, scenery)
	var quick_ms: int = _ms(t)
	# The search as it was: every part asked across every side.
	t = Time.get_ticks_usec()
	var all: Dictionary = {one[0]: true}
	var queue: Array = [one[0]]
	while not queue.is_empty():
		var here: int = queue.pop_back()
		for other: int in SelectBy._joined_to(_world, lattice, here):
			if all.has(other) or scenery.has(other):
				continue
			all[other] = true
			queue.append(other)
	var full_ms: int = _ms(t)
	var mine: Dictionary = {}
	for brick_id: int in found:
		mine[brick_id] = true
	var across: Array = SelectBy.sideways(_world, lattice)
	print("    joined from one part: %d found in %d ms, %d by asking every side in %d ms; %d and %d may be joined across x and z" % [
		found.size(), quick_ms, all.size(), full_ms, (across[0] as Dictionary).size(),
		(across[1] as Dictionary).size()])
	_check("joined from one part finds what asking every side finds (%d parts)" % all.size(),
		_same(mine, all) and all.size() > 1000)
	_verbs.select_by("all")
	await _frames(3)
	var seeds: Array = _builder.selection.keys()
	t = Time.get_ticks_usec()
	var every: Array = SelectBy.connected(_world, lattice, seeds, scenery)
	var at_once_ms: int = _ms(t)
	_check("with all %d selected it stops at once (%d ms)" % [seeds.size(), at_once_ms],
		every.size() == seeds.size() and at_once_ms < 100)
	_verbs.select_by("none")
	await _frames(3)


## All of Orthanc in hand: drawn as instances, on the screen.
func _ghost() -> void:
	var camera: CadCamera = _main.get("_camera")
	var image_before: Image = await _screen()
	_verbs.select_by("all")
	await _frames(3)
	var t: int = Time.get_ticks_usec()
	_verbs.duplicate_selection()
	var took: int = _ms(t)
	var carry: Carry = _builder.carrying
	var surfaces: int = 0
	for item: Dictionary in carry.items:
		surfaces += _library.mesh_for(str(item["part"])).surface_count()
	var instances: int = 0
	var drawn: int = 0
	for child: Node in carry._ghost.get_children():
		var each: MultiMeshInstance3D = child
		instances += each.multimesh.instance_count
		drawn += 1
	print("    %d parts in hand in %d ms: %d surfaces, %d instances in %d draws" % [
		carry.items.size(), took, surfaces, instances, drawn])
	_check("the ghost draws every surface of every part once (%d)" % surfaces,
		instances == surfaces and drawn < surfaces / 10)
	# Aimed in the middle of the view, the ghost shows there.
	var middle: Vector2 = root.get_visible_rect().size * 0.5
	carry.aim(_builder.lattice, _builder, camera.ray_origin(middle),
		camera.ray_normal(middle))
	await _frames(4)
	var image_after: Image = await _screen()
	var changed: int = 0
	for y: int in range(0, image_after.get_height(), 8):
		for x: int in range(0, image_after.get_width(), 8):
			if image_before.get_pixel(x, y).to_rgba32() != image_after.get_pixel(x, y).to_rgba32():
				changed += 1
	print("    %d sampled pixels changed by the ghost" % changed)
	_check("the ghost is on the screen", carry.is_aimed() and changed > 200)
	_builder.cancel_carry()
	_verbs.select_by("none")
	await _frames(4)


func _screen() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## A 2 x 4 in place of every part: the swaps where there is room, the rest
## standing as they were, and one undo back.
func _replace() -> void:
	var lattice: BrickLattice = _builder.lattice
	var before: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		before[brick.id] = lattice.boxes_of(brick.id)
	_verbs.select_by("all")
	await _frames(3)
	var depth: int = _builder.history_depth()
	var t: int = Time.get_ticks_usec()
	var done: Vector2i = _builder.replace_selection("3001")
	var took: int = _ms(t)
	print("    replace: %d swapped, %d left in %d ms" % [done.x, done.y, took])
	var kept: int = 0
	var unchanged: bool = true
	for brick_id: int in before:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null:
			continue
		kept += 1
		if lattice.boxes_of(brick_id) != before[brick_id]:
			unchanged = false
	_check("every part left standing is where it was in the lattice (%d)" % kept,
		unchanged and kept == before.size() - done.x)
	_check("some swapped and some had no room", done.x > 0 and done.y > 0)
	_check("one undo", _builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(3)
	var back: bool = _world.brick_count() == before.size()
	for brick: BrickWorld.Brick in _world.bricks():
		if not before.has(brick.id) or lattice.boxes_of(brick.id) != before[brick.id]:
			back = false
			break
	_check("undone, every part is back where it was", back)
	_verbs.select_by("none")
	await _frames(3)
