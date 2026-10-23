## View, Stress against arrangements whose answers can be worked out by
## hand, and against the models that ship, which stand.
##
##   godot --headless --path . --script src/dev/stress_probe.gd
##
## docs/COMPETITIVE.md, item 6. A column of 1x1 bricks carrying a 2x10 plate
## as a cantilever, loaded at its tip, reads red at its root, and every 1x1
## under it red too: each carries the whole cantilever's moment on one stud.
## The same cantilever on a column of 2x2s reads plain. The 2x10 alone on
## the 1x1s is not red: a stud holds a bare plate out three times over, and
## a check that called it weak would be Studio's, which "often flags parts
## that are actually well connected". A bonded wall reads plain, every part
## of it. The view tints what it says and nothing else: the paint, the
## history and the model's revision are as they were, on and off. And the
## models that ship stand, with no part red. Exits non-zero when an answer is
## wrong.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder

const TO_CM := 0.04   ## N·LDU to N·cm


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	await _cantilever_on_1x1s()
	await _cantilever_on_2x2s()
	await _bare_plate_on_1x1s()
	await _bonded_wall()
	await _drawn_not_painted()
	await _models_stand()
	print("")
	if _failures == 0:
		print("stress: the loaded cantilever's root reads red on 1x1s and plain on 2x2s, a bare "
			+ "one and a bonded wall are not libelled, the view changes no paint, and the "
			+ "shipped models read no part red")
	else:
		print("stress: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- building ------------------------------------------------------------------


func _fresh() -> void:
	if _world != null:
		_world.queue_free()
		_builder.queue_free()
		await process_frame
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	await process_frame


## A part with the middle of its footprint at [param x], [param z] and the
## bottom of its body at [param bottom], LDU; long along x. Returns its id.
func _put(part_id: String, x: float, bottom: float, z: float, colour: int = 4) -> int:
	var part: Lbm.PartMesh = _library.mesh_for(part_id)
	var info: PartLibrary.PartInfo = _library.parts.get(part_id)
	var basis := Basis.IDENTITY
	if info.size.x < info.size.z:
		basis = Basis(Vector3.UP, PI * 0.5)
	var box: AABB = (Transform3D(basis, Vector3.ZERO) * part.bounds).abs()
	var middle: Vector3 = box.get_center()
	var at := Transform3D(basis, Vector3(roundf(x - middle.x), roundf(bottom - box.position.y),
		roundf(z - middle.z)))
	var id: int = _world.add_brick(part_id, colour, at)
	_builder.register(id, part_id, at)
	return id


func _top(id: int) -> float:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var box: AABB = (brick.transform * part.bounds).abs()
	return box.end.y - (4.0 if _library.parts[brick.part_id].stud_count > 0 else 0.0)


## A column of [param part] five high, its top stud (the 1x1's, or a 2x2's
## nearer pair) at x 0 and 20, z 0; then a 2x10 plate out along x from it by
## its end studs; and [param load] 2x2 bricks stacked on its far end. Returns
## [the column bottom up, the plate, the load].
func _column_and_cantilever(part: String, load: int) -> Array:
	await _fresh()
	var column: Array = []
	var middle := Vector2(0, 0) if part == "3005" else Vector2(10, 10)
	var top: float = 0.0
	for _n: int in 5:
		var id: int = _put(part, middle.x, top, middle.y)
		column.append(id)
		top = _top(id)
	var plate: int = _put("3832", 90, top, 10, 1)
	var tip: Array = []
	top = _top(plate)
	for _n: int in load:
		var id: int = _put("3003", 170, top, 10, 14)
		tip.append(id)
		top = _top(id)
	return [column, plate, tip]


func _weigh() -> Stability.Report:
	var judge := Stability.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	judge.with_margins = true
	return judge.check(_world)


## The view on [param report]: what it tints, by id.
func _view(report: Stability.Report) -> StressView:
	var view := StressView.new()
	view.world = _world
	view.library = _library
	view.set_on(true)
	view.show_report(report)
	return view


func _grams(part_id: String) -> float:
	return Stability.grams(_library.parts.get(part_id))


func _near(got: float, want: float, within: float) -> bool:
	return absf(got - want) <= within


# -- the cases -------------------------------------------------------------------


## Six 2x2 bricks on the far end of a 2x10 plate held by its end stud on a
## column of 1x1s. About the edge of the one stud, half a stud past its
## middle, the plate's weight is 4 studs out and the load's 8, against the
## stud's 1 N half a stud in: 0.4 N·cm. Every 1x1 in the column carries the
## same moment on the same one stud, less its own few grams'.
func _cantilever_on_1x1s() -> void:
	print("a 2x10 cantilever, loaded at its tip, on a column of 1x1 bricks")
	var built: Array = await _column_and_cantilever("3005", 6)
	var report: Stability.Report = _weigh()
	var view: StressView = _view(report)
	var plate: int = built[1]
	var root: Balance.JointLoad = report.margins.get(plate)
	var weight: float = (_grams("3832") * 80.0 + 6.0 * _grams("3003") * 160.0) / 1000.0 \
		* Balance.GRAVITY * TO_CM
	_check("the plate's root is weighed: %s" % ("none" if root == null else
		"%.1f g on %d stud of %s, %.3f N·cm against %.2f" % [root.grams, root.studs, root.held_part,
		root.moment, root.capacity]), root != null and root.studs == 1 and root.held_part == "3005")
	if root == null:
		return
	_check("...its moment is the plate's and the load's about the stud's edge: %.3f N·cm, by hand %.3f"
		% [root.moment, weight], _near(root.moment, weight, weight * 0.03))
	_check("...and it reads red: margin %.2f, tinted %s" % [view.margin_of(plate),
		_world.stressed_ids().get(plate)], view.margin_of(plate) < StressView.WEAK
		and _world.stressed_ids().get(plate) == StressView.RED)
	var column: Array = built[0]
	var red: int = 0
	for n: int in range(1, column.size()):
		if _world.stressed_ids().get(column[n]) == StressView.RED:
			red += 1
	_check("every 1x1 over the bottom one reads red too, each on one stud (%d of %d)"
		% [red, column.size() - 1], red == column.size() - 1)
	var load_red: int = 0
	for id: int in built[2]:
		if _world.stressed_ids().has(id):
			load_red += 1
	_check("the load stacked on the plate's end is plain: %d of %d tinted" % [load_red,
		(built[2] as Array).size()], load_red == 0)
	var said: String = view.words(plate)
	_check("pointing at the plate says what it carries, on what: \"%s\"" % said,
		said.contains("carries %s g on 1 stud, margin %s" % [Balance.tidy(root.grams),
			StressView.margin_words(view.margin_of(plate))]))
	var asked: String = view.brace_words(plate)
	_check("...and Ask Claude to brace this says the joint's numbers: \"%s\"" % asked,
		asked.begins_with("Brace this:") and asked.contains("past its studs' working load"))
	_check("the plate is the weakest of the plate and its load: %d" % view.weakest_of(
		{plate: true, built[2][0]: true}), view.weakest_of({plate: true, built[2][0]: true}) == plate)
	view.free()


## The same, on a column of 2x2s: the plate held by four studs, its edge a
## stud further out and the far pair a stud and a half from it, 2 N·cm on
## four studs. Nothing reads red or amber.
func _cantilever_on_2x2s() -> void:
	print("the same cantilever on a column of 2x2 bricks")
	var built: Array = await _column_and_cantilever("3003", 6)
	var report: Stability.Report = _weigh()
	var view: StressView = _view(report)
	var plate: int = built[1]
	var root: Balance.JointLoad = report.margins.get(plate)
	_check("the plate's root is on 4 studs, margin %s" % (Balance.studs(view.margin_of(plate))
		if root != null else "none"), root != null and root.studs == 4)
	_check("nothing is tinted, root and column and all: %d parts plain of %d weighed (%s)" % [
		_world.brick_count() - _world.stressed_ids().size(), report.margins.size(),
		_margins(report, view)], _world.stressed_ids().is_empty() and report.margins.size() >= 5)
	view.free()


## The 2x10 alone on the 1x1s: 3.6 g four studs out on one stud's 0.4 N·cm.
func _bare_plate_on_1x1s() -> void:
	print("a bare 2x10 cantilever on a column of 1x1 bricks")
	var built: Array = await _column_and_cantilever("3005", 0)
	var report: Stability.Report = _weigh()
	var view: StressView = _view(report)
	var plate: int = built[1]
	var weight: float = _grams("3832") / 1000.0 * Balance.GRAVITY * 80.0 * TO_CM
	_check("the plate's root holds it %s times over, by hand %.1f, and it is not red"
		% [Balance.studs(view.margin_of(plate)), 0.4 / weight], view.margin_of(plate) >= StressView.WEAK
		and _near(view.margin_of(plate), 0.4 / weight, 0.4 / weight * 0.12)
		and _world.stressed_ids().get(plate) != StressView.RED)
	view.free()


## Four courses of 2x4 bricks laid as a wall is, each course half a brick
## along from the one under it. Every joint shares its load: no part tinted.
func _bonded_wall() -> void:
	print("a bonded wall of 2x4 bricks")
	await _fresh()
	var bottom: float = 0.0
	for course: int in 4:
		var shift: float = 40.0 if course % 2 == 1 else 0.0
		var last: int = 0
		for n: int in 4:
			last = _put("3001", shift + n * 80.0, bottom, 0)
		bottom = _top(last)
	var report: Stability.Report = _weigh()
	var view: StressView = _view(report)
	_check("%d bricks, none tinted (%s)" % [_world.brick_count(), _margins(report, view)],
		_world.stressed_ids().is_empty())
	view.free()


## On and off, the paint, the history and the revision are as they were;
## and a part drawn plain is drawn in its own colour faded, a red one red.
func _drawn_not_painted() -> void:
	print("the view draws, and paints nothing")
	var built: Array = await _column_and_cantilever("3005", 6)
	var plate: int = built[1]
	var plain: int = built[2][0]
	var revision: int = _world.revision
	var history: int = _world.history.size()
	var report: Stability.Report = _weigh()
	var view: StressView = _view(report)
	await process_frame
	var plate_brick: BrickWorld.Brick = _world.get_brick(plate)
	var plain_brick: BrickWorld.Brick = _world.get_brick(plain)
	var own: Color = _library.color(plain_brick.color_code).shown
	var drawn_plain: Color = _world._shown_colour(plain_brick, _library.color(plain_brick.color_code))
	var drawn_plate: Color = _world._shown_colour(plate_brick, _library.color(plate_brick.color_code))
	_check("a plain part is its own colour faded (%s, from %s)" % [drawn_plain.to_html(false),
		own.to_html(false)], drawn_plain.is_equal_approx(BrickWorld.faded(own)))
	_check("the red one is drawn red (%s)" % drawn_plate.to_html(false),
		drawn_plate.r > 0.8 and drawn_plate.g < 0.45 and drawn_plate.b < 0.45)
	view.set_on(false)
	await process_frame
	var after: Color = _world._shown_colour(plain_brick, _library.color(plain_brick.color_code))
	_check("off, every part is its own colour again (%s), nothing tinted" % after.to_html(false),
		after.is_equal_approx(own) and _world.stressed_ids().is_empty() and not _world.is_stressed())
	_check("the paint is as it was: blue plate, yellow load (%d, %d)" % [plate_brick.color_code,
		plain_brick.color_code], plate_brick.color_code == 1 and plain_brick.color_code == 14)
	_check("no step in the history and the revision unmoved (%d, %d)" % [_world.history.size() - history,
		_world.revision - revision], _world.history.size() == history and _world.revision == revision)
	view.free()


## The models that ship stand, and no part of them reads red.
func _models_stand() -> void:
	print("the shipped models")
	for name: String in ["house.ldr", "car.ldr", "lighthouse.ldr", "castle.ldr", "kart.ldr",
			"tower.ldr", "rocket.ldr", "station.ldr"]:
		await _fresh()
		var ldr: LdrModel = LdrModel.load_file("res://models/" + name)
		for piece: LdrModel.Placement in ldr.flatten():
			var part_id: String = piece.part_id.to_lower().trim_suffix(".dat")
			if _library.mesh_for(part_id) == null:
				continue
			var id: int = _world.add_brick(part_id, piece.color_code, piece.transform)
			if id != 0:
				_builder.register(id, part_id, piece.transform)
		var began: int = Time.get_ticks_msec()
		var report: Stability.Report = _weigh()
		var ms: int = Time.get_ticks_msec() - began
		var view: StressView = _view(report)
		var red: Array = []
		var amber: int = 0
		for id: int in _world.stressed_ids():
			if _world.stressed_ids()[id] == StressView.RED:
				red.append(view.words(id))
			else:
				amber += 1
		_check("%-14s %d parts, %d joints weighed, %d red, %d amber (%d ms)%s" % [name,
			_world.brick_count(), report.margins.size(), red.size(), amber, ms,
			"" if red.is_empty() else ": " + "; ".join(red)], red.is_empty())
		view.free()


## Each weighed joint's margin, bottom up, for a line.
func _margins(report: Stability.Report, view: StressView) -> String:
	var ids: Array = report.margins.keys()
	ids.sort()
	var out: PackedStringArray = []
	for id: int in ids:
		out.append(StressView.margin_words(view.margin_of(id)))
	return ", ".join(out)
