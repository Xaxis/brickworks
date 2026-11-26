extends SceneTree
## Is a piece that meets the rest side by side, no stud across the plane
## between them, tied back across it (Brickify's bond, Brickify.Laid.bond),
## and only where a tie is right? (snot7, 2026-11-26.) A builder ties a section
## back to the core with a plate or brick laid across the joint: here two
## plain parts side by side on one level, one of the piece and one of the
## rest, are laid again as that level with a part across. Each build is laid
## on the stud and plate grid as Brickify lays one; each tie is read off the
## parts' own connectors, not the grid: the part across has its studs in a
## part on each side, or theirs in it.
##
##   godot --headless --path . --script src/dev/bond_probe.gd

## The plane the piece meets the rest on: x = 2 studs, in LDU.
const PLANE := 40.0
## The column's courses, and the plate the block hung from its top starts at.
const TALL := 24
const HUNG := 45
const BLUE := 1
const RED := 4

var _library: PartLibrary
var _checker: Assistant
var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	return ok


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = _library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	root.add_child(builder)
	_checker = Assistant.new()
	_checker.library = _library
	_checker.world = world
	_checker.builder = builder
	await process_frame
	_hung_beside()
	_loose_beside()
	_bricks_beside_plates()
	_one_part_across()
	_nothing_beside()
	_two_colours()
	_held_already()
	print("")
	print("%d of %d checks pass" % [_checks - _failures, _checks])
	if _failures == 0:
		print("a piece side by side with the rest is tied back across the plane, and only there")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


# -- building ------------------------------------------------------------------


func _put(list: Array, part: String, colour: int, x: int, y: int, z: int, rot: int) -> void:
	list.append({"part": part, "color": colour, "x": x, "y": y, "z": z, "rot": rot})


## A column two studs by four of 2 x 4 bricks at [param x], [param z], its
## courses from plate [param y] up, [param courses] of them.
func _column(list: Array, x: int, z: int, y: int, courses: int, colour: int) -> void:
	for k: int in courses:
		_put(list, "3001", colour, x, y + 3 * k, z, 1)


## A block four studs square of 2 x 4 bricks, each course turned from the one
## under it so it is one piece.
func _block(list: Array, x: int, z: int, y: int, courses: int, colour: int) -> void:
	for k: int in courses:
		if k % 2 == 0:
			_put(list, "3001", colour, x, y + 3 * k, z, 1)
			_put(list, "3001", colour, x + 2, y + 3 * k, z, 1)
		else:
			_put(list, "3001", colour, x, y + 3 * k, z, 0)
			_put(list, "3001", colour, x, y + 3 * k, z + 2, 0)


func _model(list: Array) -> Assistant.Model:
	var model := Assistant.Model.new()
	model.name = "bond"
	for one: Dictionary in list:
		model.placements.append(Assistant.Placement.from_dict(one))
	return model


## The check as Brickify's props read it, weighed.
func _weighed(model: Assistant.Model) -> Dictionary:
	return _checker._check(model, true, true, false, false)


func _over(report: Dictionary) -> int:
	var balance: Balance.Report = report.get("balance")
	return balance.over if balance != null else -1


## By the parts' own connectors: each part across [constant PLANE] (its box
## on both sides of it) whose studs are in a socket of a part wholly on each
## side, or a stud of one in its own, with how many studs a side.
func _ties(model: Assistant.Model) -> Array:
	var at: Array[Transform3D] = []
	var boxes: Array[AABB] = []
	var meshes: Array = []
	for p: Assistant.Placement in model.placements:
		var mesh: Lbm.PartMesh = _library.mesh_for(p.part)
		var t: Transform3D = _checker._transform(p, mesh)
		at.append(t)
		boxes.append(t * mesh.bounds)
		meshes.append(mesh)
	var side := func(n: int) -> int:
		if boxes[n].end.x <= PLANE + 0.5:
			return 0
		if boxes[n].position.x >= PLANE - 0.5:
			return 1
		return -1
	var out: Array = []
	for n: int in model.placements.size():
		if side.call(n) != -1:
			continue
		var studs := Vector2i.ZERO
		for m: int in model.placements.size():
			var s: int = side.call(m)
			if s < 0 or not boxes[n].grow(8.0).intersects(boxes[m]):
				continue
			for pair: Array in [[n, m], [m, n]]:
				var whose: int = pair[0]
				var into: int = pair[1]
				for connector: Lbm.Connector in (meshes[whose] as Lbm.PartMesh).connectors:
					if connector.kind != "stud" or connector.gender != "male":
						continue
					var foot: Vector3 = at[whose] * connector.position
					var way: Vector3 = (at[whose].basis * connector.axis).normalized()
					if Joints.socket_at(at[into], meshes[into], foot, way):
						studs[s] += 1
		if studs.x > 0 and studs.y > 0:
			out.append([model.placements[n].part, model.placements[n].y, studs])
	return out


func _said(ties: Array) -> String:
	var words: PackedStringArray = []
	for tie: Array in ties:
		words.append("%s at plate %d, %d and %d studs" % [tie[0], int(tie[1]), (tie[2] as Vector2i).x,
			(tie[2] as Vector2i).y])
	return ", ".join(words) if not words.is_empty() else "none"


# -- the builds ----------------------------------------------------------------


## A block hung from one stud of a plate on top of a column, side by side with
## it all the way down: past its load, and tied back across the plane. Each
## block hung here is fewer parts than what holds it: one of more is, to the
## props, the model, and the column what hangs from it.
func _hung_beside() -> void:
	print("\n-- a block hung by one stud beside a column, side by side all the way down")
	var list: Array = []
	_column(list, 0, 0, 0, TALL, BLUE)
	_block(list, 2, 0, HUNG, 9, BLUE)
	_put(list, "3023b", BLUE, 1, TALL * 3, 0, 0)
	var model: Assistant.Model = _model(list)
	var report: Dictionary = _weighed(model)
	var before: Array = _ties(model)
	print("  before: %d over, ties %s" % [_over(report), _said(before)])
	if not _check("as laid, the block hangs past its load from one stud (%d over)" % _over(report),
			_over(report) >= 1 and before.size() == 1):
		return
	var after: Dictionary = Brickify._propped(model, _checker, report)
	var ties: Array = _ties(model)
	print("  after: %d over, bonded %d, propped %d, ties %s" % [_over(after), int(after.get("bonded", 0)),
		int(after.get("propped", 0)), _said(ties)])
	_check("tied back: no joint past its load (%d)" % _over(after), _over(after) == 0)
	_check("by ties across the plane, not props (%d ties, %d parts more)" % [int(after.get("bonded", 0)),
		int(after.get("propped", 0))], int(after.get("bonded", 0)) >= 1 and int(after.get("propped", 0)) == 0)
	_check("each tie's studs in a part on both sides, by the parts' own connectors (%d across)"
		% ties.size(), ties.size() >= int(after.get("bonded", 0)))
	_check("in one piece, the check passing", bool(after.get("ok", false)) and int(after.get("pieces", 0)) == 1)
	_check("in the block's colour, of plain parts", _plain_in(model, BLUE))


## The same block with nothing on top: apart, which the mend took out. Now the
## mend ties it.
func _loose_beside() -> void:
	print("\n-- a block beside a column, held by nothing")
	var list: Array = []
	_column(list, 0, 0, 0, 12, BLUE)
	_block(list, 2, 0, 9, 9, BLUE)
	var model: Assistant.Model = _model(list)
	var was: int = model.placements.size()
	var report: Dictionary = Brickify.mend(model, _checker)
	print("  mended %d, tied %d, pieces %d, ties %s" % [int(report.get("mended", 0)), int(report.get("tied", 0)),
		int(report.get("pieces", 0)), _said(_ties(model))])
	_check("the mend ties it rather than take it out (%d out, %d parts left of %d)" % [
		int(report.get("mended", 0)), model.placements.size(), was],
		int(report.get("mended", 0)) == 0 and int(report.get("pieces", 0)) == 1 and bool(report.get("ok", false)))
	_check("by a tie across the plane", _ties(model).size() >= 1)


## The fox's head: bricks of the piece beside plates of the rest, no course of
## the two the same. A brick is laid as its three plates, one of them across.
func _bricks_beside_plates() -> void:
	print("\n-- a block of bricks hung beside a column of plates")
	var list: Array = []
	for k: int in 36:
		_put(list, "3020", BLUE, 0, k, 0, 1)
	_block(list, 2, 0, 9, 9, BLUE)
	_put(list, "3023b", BLUE, 1, 36, 0, 0)
	var model: Assistant.Model = _model(list)
	var report: Dictionary = _weighed(model)
	var was: int = model.placements.size()
	print("  before: %d over" % _over(report))
	if not _check("as laid, past its load (%d over)" % _over(report), _over(report) >= 1):
		return
	var after: Dictionary = Brickify._propped(model, _checker, report)
	var ties: Array = _ties(model)
	print("  after: %d over, bonded %d, %d parts (was %d), ties %s" % [_over(after),
		int(after.get("bonded", 0)), model.placements.size(), was, _said(ties)])
	_check("tied: no joint past its load", _over(after) == 0 and int(after.get("bonded", 0)) >= 1)
	_check("each tie a plate across, its studs in both sides (%d across)" % ties.size(),
		ties.size() >= int(after.get("bonded", 0)))
	_check("a brick laid as plates: two parts more a tie, no more (%d more for %d)" % [
		model.placements.size() - was, int(after.get("bonded", 0))],
		model.placements.size() - was <= 2 * int(after.get("bonded", 0)))


## Two 1 x 2 plates end to end, one of each side, laid again as one 1 x 4: a
## part fewer, and the slot it leaves taken out.
func _one_part_across() -> void:
	print("\n-- a stack of 1 x 2 plates beside another, end to end, held by nothing")
	var list: Array = []
	for k: int in 12:
		_put(list, "3023b", BLUE, 0, k, 0, 0)
	for k: int in range(3, 12):
		_put(list, "3023b", BLUE, 2, k, 0, 0)
	var model: Assistant.Model = _model(list)
	var was: int = model.placements.size()
	var report: Dictionary = Brickify.mend(model, _checker)
	var long: int = 0
	for p: Assistant.Placement in model.placements:
		long += 1 if p.part == "3710" else 0
	print("  mended %d, %d parts (was %d), %d 1 x 4, ties %s" % [int(report.get("mended", 0)),
		model.placements.size(), was, long, _said(_ties(model))])
	_check("joined by a 1 x 4 across, a part fewer each (%d 1 x 4, %d parts of %d)" % [long,
		model.placements.size(), was], long >= 1 and model.placements.size() == was - long \
		and int(report.get("mended", 0)) == 0 and int(report.get("pieces", 0)) == 1)


## A block hung a stud off the column, nothing side by side: no tie, and
## nothing of it laid again (45 plates up, past a pillar's 24, so no prop
## either: as before).
func _nothing_beside() -> void:
	print("\n-- a block hung a stud away from the column")
	var list: Array = []
	_column(list, 0, 0, 0, TALL, BLUE)
	_block(list, 3, 0, HUNG, 9, BLUE)
	_put(list, "3623", BLUE, 1, TALL * 3, 0, 0)
	var model: Assistant.Model = _model(list)
	var parts: Array = model.placements.duplicate()
	var report: Dictionary = _weighed(model)
	var after: Dictionary = Brickify._propped(model, _checker, report)
	var kept: bool = model.placements.size() >= parts.size()
	for n: int in mini(parts.size(), model.placements.size()):
		kept = kept and parts[n] == model.placements[n]
	print("  before %d over, after %d, bonded %d, propped %d" % [_over(report), _over(after),
		int(after.get("bonded", 0)), int(after.get("propped", 0))])
	_check("no tie where nothing stands beside it, nothing laid again", _over(report) >= 1 \
		and int(after.get("bonded", 0)) == 0 and kept)


## Side by side in two colours: a part across would show one on the other's
## side, so none.
func _two_colours() -> void:
	print("\n-- a red block hung beside a blue column")
	var list: Array = []
	_column(list, 0, 0, 0, TALL, BLUE)
	_block(list, 2, 0, HUNG, 9, RED)
	_put(list, "3023b", BLUE, 1, TALL * 3, 0, 0)
	var model: Assistant.Model = _model(list)
	var report: Dictionary = _weighed(model)
	var after: Dictionary = Brickify._propped(model, _checker, report)
	print("  before %d over, after %d, bonded %d, propped %d" % [_over(report), _over(after),
		int(after.get("bonded", 0)), int(after.get("propped", 0))])
	_check("no tie across two colours (parts across: %s)" % _said(_ties(model)),
		_over(report) >= 1 and int(after.get("bonded", 0)) == 0 and _ties(model).size() <= 1)


## Standing on the ground beside the column: nothing past its load, nothing
## laid again.
func _held_already() -> void:
	print("\n-- a block standing beside a column")
	var list: Array = []
	_column(list, 0, 0, 0, 12, BLUE)
	_block(list, 2, 0, 0, 12, BLUE)
	_put(list, "3023b", BLUE, 1, 36, 0, 0)
	var model: Assistant.Model = _model(list)
	var parts: Array = model.placements.duplicate()
	var report: Dictionary = _weighed(model)
	var after: Dictionary = Brickify._propped(model, _checker, report)
	var same: bool = parts.size() == model.placements.size()
	for n: int in mini(parts.size(), model.placements.size()):
		same = same and parts[n] == model.placements[n]
	_check("nothing past its load (%d) and nothing laid again" % _over(after), _over(after) == 0 and same \
		and int(after.get("bonded", 0)) == 0)


## Every part a plain plate or brick of the core's, in [param colour].
func _plain_in(model: Assistant.Model, colour: int) -> bool:
	var plain: Dictionary = {}
	for entry: Array in Shapes.CORE_PLATES + Shapes.CORE_BRICKS:
		plain[Shapes.current(_library, str(entry[2]))] = true
	for p: Assistant.Placement in model.placements:
		if not plain.has(p.part) or p.color != colour or p.face != "up":
			print("  not plain: %s colour %d face %s" % [p.part, p.color, p.face])
			return false
	return true

