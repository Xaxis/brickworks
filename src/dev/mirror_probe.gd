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
##
## And a design's mirror pattern turns its parts as Mirror does: the walk's
## side pod (mirrorparts_probe's) by submit_design's mirror pattern, across x
## and across z, part for part what mirror_parts makes of the same pod, to
## 0.01 LDU; every part the pattern mirrors in five kept real-set designs
## (fixtures/mirror_designs.json) what Builder.mirror_bricks makes of the same
## half; and a part with no mirror image named in submit_design's reply. The
## pattern kept each brick's rot until mirrorpattern (2026-11-06): across x a
## headlight, a cheese slope and a hinge plate stayed at rot 1, facing in, and
## across z a right wedge plate stayed right, a wrong car said as done.
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

	print("a design's mirror pattern, part for part what mirror_parts makes")
	await _pattern()

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
		var image: Dictionary = Mirror.image(library, brick.part_id, brick.transform, axis,
			across, true)
		var at: Transform3D = Builder._tidy(image["at"],
			BrickLattice.is_square_to_grid(brick.transform.basis))
		var packed: PackedInt32Array = _builder.boxes_for(library.mesh_for(image["part"]), at)
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


# -- a design's mirror pattern (mirrorpattern) ---------------------------------------


## The walk's pod as its session laid it (seeing2's walk, s1; mirrorparts_probe):
## a 4 x 6 plate, a left wing plate, a 1 x 2 slope falling out, a headlight
## brick facing out and a cheese slope on it falling out.
const POD: Array = [
	{"part": "3032", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 1},
	{"part": "41770", "color": 71, "x": 2, "y": 1, "z": 1},
	{"part": "3040", "color": 4, "x": 2, "y": 1, "z": 0, "rot": 1},
	{"part": "4070", "color": 4, "x": 3, "y": 1, "z": 5, "rot": 1},
	{"part": "54200", "color": 4, "x": 3, "y": 4, "z": 5, "rot": 1}]
## A tile printed with a picture that reads one way only, which no part is
## the mirror image of (Mirror: none).
const LONE := "1126pt0"
## Five designs sessions submitted with a mirror pattern in the realset
## bench, each cut after its first mirror (bench/results, 2026-10-26 to 11-04).
const KEPT := "res://src/dev/fixtures/mirror_designs.json"

var _socket: CommandSocket
var _next: int = 0


## Patterns._mirror kept each brick's turn and laid it by its footprint: a
## design mirrored by it was a wrong car said as done. Across x the pod's
## headlight brick, slope and cheese slope stayed at rot 1, facing in; across
## z a wing plate's other hand pointed back. Now each part it lays is made
## its mirror image as mirror_parts makes it. Checked as a session meets it,
## over MCP: the walk's pod by submit_design with a mirror pattern, and by
## submit_design and mirror_parts, part for part, across x and across z; a
## part with no mirror image named in submit_design's reply; and five kept
## designs from the realset bench, every part the pattern mirrors against
## the Builder's mirror (mirror_parts') on the same half.
func _pattern() -> void:
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	for axis: String in ["x", "z"]:
		await _pod_mirrored(axis)
	await _no_image_said()
	await _kept_designs()


## The pod mirrored across [param axis] at -1 by a design's mirror pattern,
## and laid alone and mirrored by mirror_parts across the same plane: alike,
## part for part (part, colour, pose to 0.01 LDU).
func _pod_mirrored(axis: String) -> void:
	_main.call("clear_model")
	await _quiet()
	var said: String = await _say("submit_design", {"name": "Side pods", "floor": "none",
		"bricks": POD, "patterns": [{"pattern": "mirror", "about": axis, "at": -1}]})
	var by_pattern: Array = _rows(_model_ids())
	_main.call("clear_model")
	await _quiet()
	await _say("submit_design", {"name": "Side pod", "floor": "none", "bricks": POD})
	var pod: Array[int] = _model_ids()
	await _say("mirror_parts", {"bricks": pod, "axis": axis, "copy": true, "across": -1,
		"picture": false})
	var by_hand: Array = _rows(_model_ids())
	_check("the walk's pod across %s, by a design's mirror pattern and by mirror_parts: %d and %d "
		% [axis, by_pattern.size(), by_hand.size()] + "parts, %d alike" % _alike(by_pattern,
			by_hand), by_pattern.size() == 2 * POD.size() and by_pattern == by_hand)
	if by_pattern != by_hand:
		print("    said: %s" % said.left(400))
		_differ(by_pattern, by_hand, "the pattern", "mirror_parts")
	_main.call("clear_model")
	await _quiet()


## A part with no mirror image, mirrored by a design's pattern: named in
## submit_design's reply, never said as done.
func _no_image_said() -> void:
	var library: PartLibrary = _main.get("_library")
	var image: Dictionary = Mirror.image(library, LONE, Transform3D.IDENTITY, 0, 0.0)
	_check("%s %s has no mirror image (Mirror)" % [LONE, _named(LONE)],
		not bool(image["exact"]))
	_main.call("clear_model")
	await _quiet()
	var said: String = await _say("submit_design", {"name": "Signs", "floor": "none",
		"bricks": [{"part": "3020", "color": 15, "x": 0, "y": 0, "z": 0},
			{"part": LONE, "color": 15, "x": 0, "y": 1, "z": 0}],
		"patterns": [{"pattern": "mirror", "about": "x", "at": -1}]})
	var parts: Array = _model_ids().map(func(id: int) -> String:
		return _world.get_brick(id).part_id)
	_check("a design mirroring it lays it on both sides (%s)" % ", ".join(parts),
		parts.count(LONE) == 2)
	var at: int = said.find("no mirror image")
	_check("...and submit_design's reply names it as having no mirror image: \"%s\""
		% (said.substr(maxi(0, at - 60), 260) if at >= 0 else said.left(300)),
		at >= 0 and said.contains(_named(LONE)))
	_main.call("clear_model")
	await _quiet()


## Each kept design read as submit_design reads it, with its first mirror and
## without: what the mirror adds, part for part, is what the Builder's mirror
## (mirror_parts') makes of the half it reflects, laid as the read lays it.
func _kept_designs() -> void:
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(KEPT))
	var assistant: Assistant = _main.get("_assistant")
	var designs: int = 0
	var parts: int = 0
	var mirrored: int = 0
	var alike: int = 0
	for entry: Dictionary in kept as Array:
		var design: Dictionary = entry["design"]
		var patterns: Array = design["patterns"]
		var mirror: Dictionary = patterns.back()
		var axis: int = 0 if str(mirror.get("about", "x")) == "x" else 2
		var before: Dictionary = design.duplicate(true)
		before["patterns"] = patterns.slice(0, patterns.size() - 1)
		var without: Array = _read_rows(assistant, before)
		var with: Array = _read_rows(assistant, design)
		# What the mirror adds; a dressing tile, which the read picks for each
		# part dressed by where it is, set apart.
		var made: Array = _less(with, without)
		var lost: Array = _less(without, with)
		var dressed: Array = made.filter(func(row: String) -> bool: return row.ends_with("|dressing"))
		made = made.filter(func(row: String) -> bool: return not row.ends_with("|dressing"))
		# The half it reflects, as the read lays it: its own bricks, or all before it.
		var half: Dictionary = before
		if mirror.get("bricks") is Array and not (mirror["bricks"] as Array).is_empty():
			half = {"name": design.get("name", "Model"), "bricks": mirror["bricks"]}
		var model: Assistant.Model = assistant._read_model(half)
		model.link_sections()
		_main.call("clear_model")
		await _quiet()
		var ids := PackedInt64Array()
		var skipped: int = 0
		for placement: Assistant.Placement in model.placements:
			var mesh: Lbm.PartMesh = assistant.library.mesh_for(placement.part)
			if placement.dressing or placement.attached_to != null or mesh == null:
				skipped += 1
				continue
			var at: Transform3D = assistant._transform(placement, mesh,
				model.sections.get(placement.section))
			var brick_id: int = _world.add_brick(placement.part, placement.color, at)
			_builder.register(brick_id, placement.part, at)
			ids.append(brick_id)
		# The floor out of the way: 42081-1's half reaches under the ground,
		# off the baseplate's edge, and two beams' reflections land in it, so
		# Mirror refuses it there, which says nothing of what it makes.
		var floor: Array = _store.scenery.keys()
		for brick_id: int in floor:
			_builder.lattice.release(brick_id)
		var by_hand: Array = _rows(Array(_builder.mirror_bricks(ids, axis,
			float(mirror["at"]) * BrickLattice.STUD)))
		for brick_id: int in floor:
			var plate: BrickWorld.Brick = _world.get_brick(brick_id)
			if plate != null:
				_builder.register(brick_id, plate.part_id, plate.transform)
		var lone: int = _builder.no_image.size()
		var same: int = _alike(made, by_hand)
		designs += 1
		parts += by_hand.size()
		mirrored += made.size()
		alike += same
		_check(("%s, mirrored across %s at %s: the pattern made %d, mirror_parts %d of the %d it "
			+ "reflects, %d alike (%d with no mirror image; %d dressing tiles; %d set aside; %d of "
			+ "the rest moved)") % [entry["from"], "x" if axis == 0 else "z", str(mirror["at"]),
			made.size(), by_hand.size(), ids.size(), same, lone, dressed.size(), skipped,
			lost.size()], not by_hand.is_empty() and made.size() == by_hand.size()
			and same == made.size() and lost.is_empty())
		if same != made.size() or made.size() != by_hand.size():
			_differ(made, by_hand, "the pattern", "mirror_parts")
		_main.call("clear_model")
		await _quiet()
	_check("every part the pattern mirrors in %d kept designs is mirror_parts' (%d of %d, "
		% [designs, alike, mirrored] + "mirror_parts made %d)" % parts,
		designs == 5 and alike == mirrored and alike == parts and parts > 0)


## [param design] read as submit_design reads it: each part as a row of
## [method _row], a dressing tile's marked.
func _read_rows(assistant: Assistant, design: Dictionary) -> Array:
	var model: Assistant.Model = assistant._read_model(design)
	model.link_sections()
	var rows: Array = []
	for placement: Assistant.Placement in model.placements:
		var mesh: Lbm.PartMesh = assistant.library.mesh_for(placement.part)
		if mesh == null:
			continue
		var row: String = _row(placement.part, placement.color, assistant._transform(placement,
			mesh, model.sections.get(placement.section)))
		rows.append(row + ("|dressing" if placement.dressing else ""))
	rows.sort()
	return rows


## Each brick as what it is and where, sorted: two sets of parts alike when
## these are.
func _rows(ids: Array) -> Array:
	var rows: Array = []
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick != null:
			rows.append(_row(brick.part_id, brick.color_code, brick.transform))
	rows.sort()
	return rows


## A part, its colour and its pose to 0.01 LDU.
static func _row(part: String, colour: int, at: Transform3D) -> String:
	var row := PackedStringArray([part, str(colour)])
	for v: Vector3 in [at.origin, at.basis.x, at.basis.y, at.basis.z]:
		for n: int in 3:
			row.append(str(snappedf(v[n], 0.01) + 0.0))
	return "|".join(row)


## The rows of [param one] not in [param other], each as many times more.
static func _less(one: Array, other: Array) -> Array:
	var left: Array = other.duplicate()
	var out: Array = []
	for row: Variant in one:
		var at: int = left.find(row)
		if at >= 0:
			left.remove_at(at)
		else:
			out.append(row)
	return out


static func _alike(one: Array, other: Array) -> int:
	return one.size() - _less(one, other).size()


func _differ(one: Array, other: Array, one_name: String, other_name: String) -> void:
	for row: Variant in _less(one, other).slice(0, 8):
		print("      only %s: %s" % [one_name, row])
	for row: Variant in _less(other, one).slice(0, 8):
		print("      only %s: %s" % [other_name, row])


func _named(part: String) -> String:
	var info: PartLibrary.PartInfo = (_main.get("_library") as PartLibrary).parts.get(part)
	return " ".join(PackedStringArray(info.name.split(" ", false))) if info != null else part


func _model_ids() -> Array[int]:
	var ids: Array[int] = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			ids.append(brick.id)
	ids.sort()
	return ids


func _say(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get(
			"content", []):
		text += str(block.get("text", ""))
	return text
