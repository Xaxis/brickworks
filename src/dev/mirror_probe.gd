## Mirror in place: a selection lands on its own footprint, so it is never
## refused for the parts beside it, and is still refused where its
## reflection runs into a part not selected.
##
##   godot --headless --path . --script src/dev/mirror_probe.gd
##
## progress_check's mirror step (Ctrl-A, then Shift-M over the view) was
## refused, "no room to mirror it there", on every build back to m87
## (2026-10-19). The timeline was open at Orthanc's first step, so Ctrl-A took
## the two bricks shown, a 2 x 6 and a 1 x 6 side by side, x 380 to 440. The
## plane was the point a turn goes round (Carry.pivot_of), a stud centre or
## corner both ways, which for their z was x = 420: the reflection landed a
## stud over, on the 2 x 8s beside them. Here, as a person does it: Orthanc
## opened as File, Open opens it, all of it mirrored left to right and front
## to back, and its figures one at a time, each taken back by one undo; its
## first step on the timeline, its author's since orthsteps212, refused, its
## reflection landing on parts the step does not show; the same two bricks
## built between their neighbours; a half turn of each, which went round the
## same point and a stud over too, and the pair turned half round and then a
## quarter, on the studs; and a mirror whose reflection lands on a part not
## selected, refused, with nothing changed.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _verbs: EditVerbs


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
	CustomParts.dir = "user://mirror_probe_parts/"
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_verbs = _main.get("_verbs")

	print("Orthanc, all of it")
	_main.call("clear_model")
	await _quiet()
	var placed: int = await (_main.get("_bar") as ModelBar).open_with_progress(
		"res://models/orthanc.ldr")
	(_main.get("_bar") as ModelBar).opened.emit(placed)
	await _quiet()
	print("  %d parts open, %d of them scenery" % [_world.brick_count(), _store.scenery.size()])
	for axis: int in [0, 2]:
		_verbs.select_by("all")
		await _in_place(axis, "Orthanc")

	print("Orthanc's figures, one at a time")
	await _figures()

	# Its first step is its author's since orthsteps212: the plinth's first
	# course, twenty parts in a cross, whose reflection lands on parts the
	# step does not show. The pair its worked-out first step was is built
	# alone below (_between).
	print("Orthanc on the timeline, at its first step: Ctrl-A takes what it shows")
	await _main.call("_toggle_steps")
	await _quiet()
	for axis: int in [0, 2]:
		_verbs.select_by("all")
		await _onto_hidden(axis, "its first step")
	await _main.call("_toggle_steps")
	await _quiet()

	print("the same two bricks, built between their neighbours")
	await _between()

	print("the same two bricks alone, half round and then a quarter")
	await _turns()

	print("a reflection onto a part not selected")
	await _refused()

	_world.clear()
	await _frames(10)
	print("")
	print("mirror: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	_main.queue_free()
	await _frames(10)
	quit(1 if _failures > 0 else 0)


## The selection mirrored across [param axis] as Shift-M does: all of it,
## as one step that one undo takes back. With [param exact], parts that are
## their own mirror image, onto the footprint they had: a figure's arms and
## hands are not, and keep their own shapes turned (Mirror).
func _in_place(axis: int, name: String, exact: bool = false) -> void:
	var chosen: int = _builder.selection.size()
	var before: Dictionary = _snapshot()
	var depth: int = _builder.history_depth()
	var was: AABB = _footprint()
	_why_refused(axis)
	var made: int = _builder.mirror_selection(axis)
	_check("%s, %d parts selected, mirrored across %s: %d" % [name, chosen,
		"x" if axis == 0 else "z", made], made == chosen and chosen > 0)
	if exact:
		_check("...onto the footprint it had (%s)" % _footprint(),
			_footprint().is_equal_approx(was))
	_check("...one step to undo", _builder.history_depth() == depth + (1 if made > 0 else 0))
	if made > 0:
		_builder.undo()
		await _frames(2)
	_check("...and one undo puts it back", _snapshot() == before)


## The selection, what the timeline shows of a model, mirrored across [param
## axis] onto parts it does not show: refused, and nothing changed.
func _onto_hidden(axis: int, name: String) -> void:
	var chosen: int = _builder.selection.size()
	var before: Dictionary = _snapshot()
	var made: int = _builder.mirror_selection(axis)
	_check("%s, %d parts selected of %d, mirrored across %s onto parts it does not show: refused (%d)"
		% [name, chosen, _world.brick_count(), "x" if axis == 0 else "z", made],
		chosen > 0 and chosen < _world.brick_count() and made == 0)
	_check("...and nothing changed", _snapshot() == before)


## The selection turned half round where it stands, as the properties
## panel's Turn of 180 does: like a mirror both ways, onto its own footprint.
func _half_turn(name: String) -> void:
	var chosen: int = _builder.selection.size()
	var before: Dictionary = _snapshot()
	var was: AABB = _footprint()
	var turned: int = _builder.turn_selection_by(180.0)
	_check("%s, %d parts, turned half round where it stands: %d" % [name, chosen, turned],
		turned == chosen and chosen > 0)
	_check("...onto the footprint it had (%s)" % _footprint(), _footprint().is_equal_approx(was))
	var again: int = _builder.turn_selection_by(180.0)
	_check("...and half round again, back exactly where it was (%d)" % again,
		again == chosen and _snapshot() == before)
	for _n: int in (1 if turned > 0 else 0) + (1 if again > 0 else 0):
		_builder.undo()
		await _frames(2)
	_check("...and the undos put it back", _snapshot() == before)


## Each minifigure of Orthanc, a sub-model standing apart, mirrored where it
## stands. Its other sub-models are the stages its file builds it in
## (orthsteps212), parts of the tower, which a reflection in place would put
## through their neighbours.
func _figures() -> void:
	var units: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and not brick.unit.is_empty():
			if not units.has(brick.unit):
				units[brick.unit] = []
			(units[brick.unit] as Array).append(brick)
	for unit: String in units:
		if not Minifig.is_figure(units[unit], _builder.library):
			continue
		_builder.selection.clear()
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.unit == unit:
				_builder.selection[brick.id] = true
		await _in_place(0, unit)
	_builder.clear_selection()


## Orthanc's first step as its file has it: a 2 x 6 and a 1 x 6 turned along
## z, side by side, a 1 x 6 to their left and three 2 x 8s to their right,
## touching. Mirrored both ways where they stand, and the neighbours as they
## were.
func _between() -> void:
	_main.call("clear_model")
	await _quiet()
	var along_z := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))
	var two: int = _put("2456", 0, Vector3(400, 24, 100), along_z)
	var one: int = _put("3009", 0, Vector3(430, 24, 100), along_z)
	_put("3009", 0, Vector3(370, 24, 100), along_z)
	for z: float in [60.0, 100.0, 140.0]:
		_put("3007", 0, Vector3(520, 24, z))
	await _frames(3)
	var pair: Dictionary = {_world.get_brick(two).transform: true,
		_world.get_brick(one).transform: true}
	var neighbours: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not pair.has(brick.transform) and not _store.scenery.has(brick.id):
			neighbours[brick.id] = brick.transform
	# By where they stand: an undo puts a part back under a new id.
	var select_pair: Callable = func() -> void:
		_builder.selection.clear()
		for brick: BrickWorld.Brick in _world.bricks():
			if pair.has(brick.transform):
				_builder.selection[brick.id] = true
	for axis: int in [0, 2]:
		select_pair.call()
		await _in_place(axis, "a 2 x 6 and a 1 x 6", true)
	select_pair.call()
	await _half_turn("a 2 x 6 and a 1 x 6")
	var kept: bool = neighbours.keys().all(func(id: int) -> bool:
		return _world.get_brick(id) != null and _world.get_brick(id).transform == neighbours[id])
	_check("...and the four beside them are where they were", kept)


## The pair alone, turned half round about its middle and then a quarter
## about a stud: every part still on the studs, its box from stud edge to
## stud edge.
func _turns() -> void:
	_main.call("clear_model")
	await _quiet()
	var along_z := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))
	_builder.selection.clear()
	_builder.selection[_put("2456", 0, Vector3(400, 24, 100), along_z)] = true
	_builder.selection[_put("3009", 0, Vector3(430, 24, 100), along_z)] = true
	await _frames(3)
	var half: int = _builder.turn_selection_by(180.0)
	var quarter: int = _builder.turn_selection(1)
	var edges: Array = []
	for brick_id: int in _builder.selection:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		var box: AABB = (brick.transform * _builder.library.mesh_for(brick.part_id).bounds).abs()
		for at: float in [box.position.x, box.position.z, box.end.x, box.end.z]:
			edges.append(at)
	var on_studs: bool = edges.all(func(at: float) -> bool:
		return is_zero_approx(fposmod(at + 0.01, BrickLattice.STUD) - 0.01))
	_check("turned half round (%d), then a quarter (%d), on the studs: %s" % [half, quarter,
		str(edges)], half == 2 and quarter == 2 and on_studs)


## Two 1 x 2 bricks a stud apart and a third, not selected, where the
## reflection of one of them goes: refused, and nothing changed. Then with
## the third out of the way, the two mirror.
func _refused() -> void:
	_main.call("clear_model")
	await _quiet()
	var left: int = _put("3004", 4, Vector3(-40, 24, 10))
	var right: int = _put("3001", 1, Vector3(40, 24, 20))
	var stood: int = _put("3004", 14, Vector3(40, 48, 10))
	await _frames(3)
	_builder.selection.clear()
	_builder.selection[left] = true
	_builder.selection[stood] = true
	var before: Dictionary = _snapshot()
	var made: int = _builder.mirror_selection(0)
	_check("a reflection onto a 2 x 4 brick not selected is refused (%d)" % made, made == 0)
	_check("...and nothing changed", _snapshot() == before)
	_check("...and the selection is as it was", _builder.selection.size() == 2
		and _builder.selection.has(left) and _builder.selection.has(stood))
	_world.remove_brick(right)
	_builder.lattice.release(right)
	_builder.selection.clear()
	_builder.selection[left] = true
	_builder.selection[stood] = true
	made = _builder.mirror_selection(0)
	_check("with it gone, the two mirror (%d)" % made, made == 2)


## Says what the reflection of the selection would run into that is not
## selected, when it would, a few of them by name. Nothing changes.
func _why_refused(axis: int) -> void:
	var library: PartLibrary = _builder.library
	var middle: float = _footprint().get_center()[axis]
	var across: float = snappedf(middle, BrickLattice.STUD * 0.5)
	var found: Dictionary = {}
	for brick_id: int in _builder.selection:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		var part: String = brick.part_id
		var other: String = Mirror.counterpart(library, part)
		if not other.is_empty() and library.mesh_for(other) != null:
			part = other
		var at: Transform3D = Builder._tidy(Mirror.reflected(brick.transform, axis, across),
			BrickLattice.is_square_to_grid(brick.transform.basis))
		var packed: PackedInt32Array = _builder.boxes_for(library.mesh_for(part), at)
		for id: int in _builder.lattice.blockers_boxes(packed, 0, _builder.selection):
			found[id] = brick
	if found.is_empty():
		return
	var named: Array = []
	for id: int in found:
		var them: BrickWorld.Brick = _world.get_brick(id)
		var mine: BrickWorld.Brick = found[id]
		if named.size() < 4:
			named.append("%s at %s by %s at %s" % [them.part_id if them != null else "?",
				them.transform.origin if them != null else Vector3.ZERO, mine.part_id,
				mine.transform.origin])
	print("    across %s = %.0f it runs into %d parts not selected: %s" % [
		"x" if axis == 0 else "z", across, found.size(), ", ".join(named)])


## The box round the selection.
func _footprint() -> AABB:
	return _builder._bounds_of(PackedInt64Array(_builder.selection.keys()), Transform3D.IDENTITY)


func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var key: String = "%s|%d|%s" % [brick.part_id, brick.color_code, brick.transform]
		out[key] = int(out.get(key, 0)) + 1
	return out


func _put(part: String, colour: int, at: Vector3, basis: Basis = Basis.IDENTITY) -> int:
	var where := Transform3D(basis, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)
	return brick_id


func _quiet() -> void:
	var calm: int = 0
	for _n: int in 600:
		var t0: int = Time.get_ticks_usec()
		await process_frame
		if Working.is_busy() or Time.get_ticks_usec() - t0 > 50000:
			calm = 0
		else:
			calm += 1
		if calm >= 5:
			return


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
