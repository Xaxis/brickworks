## Does dragging a box take the right bricks?
##
##   godot --path . --resolution 1200x800 --script src/dev/marquee_probe.gd
##
## Needs a window: what a box catches depends on where each brick lands
## on the screen, and that needs a camera with a viewport of a known
## size to project into.
##
## Two things to get right. The box has to take what is under it and
## nothing else — a selection that quietly includes a brick behind the
## one you meant is worse than no box at all, because the next key
## press acts on it. And the direction has to matter: left to right
## takes only what falls wholly inside, right to left takes anything
## the box touches, which is what every CAD tool this would be compared
## to does.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame

	var world: BrickWorld = main.get("_world")
	var builder: Builder = main.get("_builder")
	var camera: CadCamera = main.get("_camera")
	var store: ModelStore = main.get("_store")

	world.clear()
	builder.lattice.clear()
	store.scenery.clear()

	# A row of bricks, well apart, so each has the screen to itself.
	var ids: Array[int] = []
	for n: int in 5:
		var at := Transform3D(Basis.IDENTITY, Vector3(n * 120.0, 24.0, 0.0))
		var brick_id: int = world.add_brick("3001", 4, at)
		builder.register(brick_id, "3001", at)
		ids.append(brick_id)
	camera.set_view("front")
	camera.frame(world.model_bounds())
	for _n: int in 30:
		camera._apply(0.5)
		await process_frame

	var where: Callable = main._brick_on_screen
	var boxes: Dictionary = {}
	for brick_id: int in ids:
		var seen: Variant = where.call(world.get_brick(brick_id))
		if not (seen is Rect2):
			print("  %d is not on screen" % brick_id)
			continue
		boxes[brick_id] = seen
	if boxes.size() < 5:
		print("  only %d of 5 bricks are on screen" % boxes.size())
		quit(1)
		return

	# A box drawn around the middle three, wholly containing them.
	var middle: Rect2 = (boxes[ids[1]] as Rect2).merge(boxes[ids[3]])
	var generous: Rect2 = middle.grow(6.0)

	builder.clear_selection()
	var took: int = builder.select_in(generous, where, false)
	_check("a box round three of five takes three, took %d" % took, took == 3)
	_check("and it took the right three",
		builder.selection.has(ids[1]) and builder.selection.has(ids[2])
		and builder.selection.has(ids[3])
		and not builder.selection.has(ids[0])
		and not builder.selection.has(ids[4]))

	# A box that only clips the first and last. Wholly-inside takes
	# neither; touching takes both.
	var clipping := Rect2(
		Vector2((boxes[ids[0]] as Rect2).end.x - 4.0,
			(boxes[ids[0]] as Rect2).position.y),
		Vector2((boxes[ids[4]] as Rect2).position.x + 4.0
			- ((boxes[ids[0]] as Rect2).end.x - 4.0),
			(boxes[ids[0]] as Rect2).size.y))

	builder.clear_selection()
	var enclosed: int = builder.select_in(clipping, where, false)
	builder.clear_selection()
	var touched: int = builder.select_in(clipping, where, true)
	_check("dragging one way takes %d, the other %d — and they differ"
		% [enclosed, touched], touched > enclosed)
	_check("the touching one caught the clipped ends",
		builder.selection.has(ids[0]) and builder.selection.has(ids[4]))

	# And the direction is what decides which, so that the two are
	# reachable without a second control.
	var marquee := Marquee.new()
	root.add_child(marquee)
	marquee.begin(Vector2(400.0, 300.0))
	marquee.drag_to(Vector2(600.0, 400.0))
	_check("left to right means wholly inside", not marquee.takes_touching())
	marquee.begin(Vector2(600.0, 300.0))
	marquee.drag_to(Vector2(400.0, 400.0))
	_check("right to left means anything it touches", marquee.takes_touching())

	# A click is not a drag.
	marquee.begin(Vector2(500.0, 300.0))
	_check("a press alone draws nothing",
		not marquee.drag_to(Vector2(502.0, 301.0)))
	_check("moving past the slop draws a box",
		marquee.drag_to(Vector2(540.0, 330.0)))

	print("")
	if _failures == 0:
		print("a dragged box takes what it covers, and the direction says how")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _check(what: String, held: bool) -> void:
	print("  %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1
