## What stands on a shape's smooth top locks to it.
##
##   godot --headless --path . --script src/dev/standing_probe.gd
##
## A shape's top is tiled, so it reads as a surface. The owner's Claude
## session built an orrery on one and found the collar standing on it
## floated: "two shape patterns don't lock together unless the lower one
## keeps studs". A tile has no stud, so whatever stands on one grips
## nothing, and the check passed it — resting on a part counts as held up.
## Only a second shape was told where to keep studs; a round, the design's
## own bricks and anything added later with edit_model stood on tiles.
##
## A builder tiles a top only where nothing will stand on it. So here a
## collar, a column and a brick are stood on a tiled top every way a design
## can do it, and each must be gripped by the studs of the shape under it:
## a stud of the lower part reaching into the upper, read off the parts'
## own connectors. A shape keeps tiles wherever nothing stands; a tile
## something is put down on later becomes the plate of its size, in one undo
## with what was added, and only under what this change put down; and the
## check no longer has a part resting on a smooth face to report.
extends SceneTree

const GREY := 71
const YELLOW := 14
## The flat tiles a smooth top is laid in.
const TILES: Array[String] = ["3070b", "3069b", "63864", "2431", "6636", "4162",
	"3068b", "26603", "87079"]

## A body with a smooth top: a box ten studs square and six plates tall.
const BODY := {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": GREY,
	"solids": [{"box": {"from": [0, 0, 0], "size": [10, 6, 10]}}]}
## A round base, as an orrery stands on: a revolve whose top is rings of
## corner round tiles.
const BASE := {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": GREY,
	"solids": [{"revolve": {"axis": "y", "centre": [5, 0, 5], "profile": [[0, 5], [6, 5]]}}]}
## A collar said as a second shape: a ring.
const COLLAR_SHAPE := {"pattern": "shape", "at": {"x": 0, "y": 6, "z": 0}, "color": YELLOW,
	"solids": [{"revolve": {"axis": "y", "centre": [5, 0, 5], "profile": [[0, 3], [3, 3]]}}],
	"cuts": [{"revolve": {"axis": "y", "centre": [5, -1, 5], "profile": [[0, 1.6], [6, 1.6]]}}]}
## A collar said as a round: a column four studs across.
const COLLAR_ROUND := {"pattern": "round", "at": {"x": 3, "y": 6, "z": 3}, "diameter": 4,
	"color": YELLOW, "stack": [{"plates": 6}]}

var _failures: int = 0
var _library: PartLibrary
var _builder: Builder
var _assistant: Assistant
var _world: BrickWorld


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	root.add_child(_assistant)
	await process_frame

	print("\nin one design, on a box's tiled top")
	await _one_design("a second shape, a ring", [BODY, COLLAR_SHAPE], [])
	await _one_design("a round, a column four studs across", [BODY, COLLAR_ROUND], [])
	await _one_design("the design's own bricks, 2 x 2 plates one thick", [BODY], _ring(6))
	print("\nin one design, on a round base's rings of tiles")
	await _one_design("a round on a revolve", [BASE, COLLAR_ROUND], [])
	await _one_design("a ring on a revolve", [BASE, COLLAR_SHAPE], [])

	print("\nadded later, with edit_model, on what stands")
	_clear()
	await _assistant.use_tool("submit_design", {"name": "body", "description": "a body",
		"patterns": [BODY]})
	var tiles_before: int = _count_tiles(_assistant._model_from_world())
	var edited: String = str(await _assistant.use_tool("edit_model", {"add": [
		{"part": "3003", "color": YELLOW, "x": 4, "y": 6, "z": 4, "rot": 0},
		{"part": "3003", "color": YELLOW, "x": 4, "y": 9, "z": 4, "rot": 0}]}))
	var now: Assistant.Model = _assistant._model_from_world()
	_ok(edited.begins_with("Done"), "the edit lands: %s" % edited.left(60))
	var held: int = _grips(now)
	_ok(held > 0, "a 2 x 2 brick added on the top is gripped by %d stud%s under it"
		% [held, "" if held == 1 else "s"])
	var tiles_after: int = _count_tiles(now)
	_ok(tiles_after < tiles_before and tiles_after >= tiles_before - 4,
		"...the tiles under it laid again as the plates of their size, the rest still tiles "
			+ "(%d tiles, %d before; %d studs bare beside it)" % [tiles_after, tiles_before,
			_bare_studs(now)])

	print("\nan edit about a selection: one undo takes back both")
	_builder.selection.clear()
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.color_code == GREY and brick.transform.origin.y > 5 * Assistant.PLATE - 1.0:
			_builder.selection[brick.id] = true
	var was: Dictionary = _standing()
	var depth: int = _builder.history_depth()
	var said: String = str(await _assistant.use_tool("edit_selection", {"add": [
		{"part": "3022", "color": YELLOW, "x": 1, "y": 6, "z": 1, "rot": 0}]}))
	now = _assistant._model_from_world()
	_ok(said.begins_with("Done"), "the selection's edit lands: %s" % said.left(60))
	_ok(_grips(now) > held, "a 2 x 2 plate put down on the selected top is gripped (%d studs, %d before)"
		% [_grips(now), held])
	_ok(_builder.history_depth() == depth + 1, "...one undo step (%d, was %d)"
		% [_builder.history_depth(), depth])
	_builder.undo()
	_ok(_standing() == was, "undone, the tiles are back and the plate is gone (%d parts, %d before)"
		% [_world.brick_count(), was.values().reduce(func(a: int, b: int) -> int: return a + b, 0)])
	_assistant.unfocus()
	_builder.selection.clear()

	print("\nthe person's own part on a tile is theirs: an edit elsewhere leaves it")
	var tile: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if TILES.has(brick.part_id) and tile == null:
			tile = brick
	var mesh: Lbm.PartMesh = _library.mesh_for("3024")
	var hand: Assistant.Placement = Assistant.Placement.new()
	hand.part = "3024"
	hand.color = 4
	var tile_box: PackedInt32Array = BrickLattice._bound_of(_builder.boxes_for(
		_library.mesh_for(tile.part_id), tile.transform))
	hand.x = tile_box[0] / BrickLattice.CELLS_PER_STUD
	hand.z = tile_box[2] / BrickLattice.CELLS_PER_STUD
	hand.y = tile_box[4] / BrickLattice.CELLS_PER_PLATE
	var on_it: Transform3D = _assistant._transform(hand, mesh)
	var placed: int = _world.add_brick("3024", 4, on_it)
	_builder.register(placed, "3024", on_it)
	var tiles_now: int = _count_tiles(_assistant._model_from_world())
	var far: int = 0
	var lowest: float = INF
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.color_code == GREY and brick.transform.origin.y < lowest:
			lowest = brick.transform.origin.y
			far = brick.id
	said = str(await _assistant.use_tool("edit_model", {"recolor": [{"bricks": [far], "color": 72}]}))
	_ok(said.begins_with("Done") and _count_tiles(_assistant._model_from_world()) == tiles_now
		and _world.get_brick(tile.id) != null,
		"a brick recoloured below leaves the tile under the person's plate a tile (%d tiles)"
			% _count_tiles(_assistant._model_from_world()))

	print("")
	if _failures > 0:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	else:
		print("what stands on a smooth top stands on studs")
	quit(1 if _failures > 0 else 0)


## One design: the patterns and bricks given, checked as a submission is.
func _one_design(what: String, patterns: Array, bricks: Array) -> void:
	_clear()
	var model: Assistant.Model = _assistant._read_model({"name": what, "patterns": patterns,
		"bricks": bricks})
	await _assistant._ready_to_check(model)
	var verdict: Dictionary = _assistant._check(model, true)
	var gripped: int = _grips(model)
	var resting: bool = false
	for line: Variant in verdict.get("advice", []):
		resting = resting or str(line).contains("Resting on a smooth face")
	_ok(bool(verdict["ok"]) and gripped > 0 and not resting,
		"%s: gripped by %d stud%s of the shape under it, %s%s" % [what, gripped,
			"" if gripped == 1 else "s", verdict["summary"],
			", and the check calls a part resting on a smooth face" if resting else ""])
	_ok(_bare_studs(model) <= 8, "...the top round it still smooth (%d studs bare)" % _bare_studs(model))


## 2 x 2 plates on a 10 x 10 top, one plate thick: what the check itself
## calls resting on a smooth face, held by nothing.
static func _ring(y: int) -> Array:
	var out: Array = []
	for at: Vector2i in [Vector2i(3, 3), Vector2i(5, 3), Vector2i(3, 5), Vector2i(5, 5)]:
		out.append({"part": "3022", "color": YELLOW, "x": at.x, "y": y, "z": at.y, "rot": 0})
	return out


## How many studs of the grey parts reach into a yellow one: what holds the
## one to the other, read off the parts' own connectors as the check does.
func _grips(model: Assistant.Model) -> int:
	var upper := BrickLattice.new()
	upper.keeps_columns = false
	for n: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[n]
		if placement.color != YELLOW:
			continue
		var mesh: Lbm.PartMesh = _library.mesh_for(placement.part)
		if mesh != null:
			upper.occupy_boxes(n + 1, _builder.boxes_for(mesh, _assistant._transform(placement,
				mesh, model.section_for(placement))))
	var studs: int = 0
	for placement: Assistant.Placement in model.placements:
		if placement.color != GREY:
			continue
		for tip: Vector3 in _stud_tips(placement, model):
			if upper.brick_at(BrickLattice.to_cell(tip)) != 0:
				studs += 1
	return studs


## Grey studs on the grey parts' top with nothing on them: where the top is
## not smooth.
func _bare_studs(model: Assistant.Model) -> int:
	var all := BrickLattice.new()
	all.keeps_columns = false
	var top: float = -INF
	for n: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[n]
		var mesh: Lbm.PartMesh = _library.mesh_for(placement.part)
		if mesh != null:
			all.occupy_boxes(n + 1, _builder.boxes_for(mesh, _assistant._transform(placement,
				mesh, model.section_for(placement))))
			if placement.color == GREY:
				top = maxf(top, placement.y)
	var bare: int = 0
	for placement: Assistant.Placement in model.placements:
		if placement.color != GREY or not is_equal_approx(placement.y, top):
			continue
		for tip: Vector3 in _stud_tips(placement, model):
			if all.brick_at(BrickLattice.to_cell(tip)) == 0:
				bare += 1
	return bare


## A little past the tip of each of a placement's studs, where the part
## held by it is.
func _stud_tips(placement: Assistant.Placement, model: Assistant.Model) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var mesh: Lbm.PartMesh = _library.mesh_for(placement.part)
	if mesh == null:
		return out
	var at: Transform3D = _assistant._transform(placement, mesh, model.section_for(placement))
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind == "stud" and connector.gender == "male":
			out.append(at * (connector.position + connector.axis.normalized() * 5.0))
	return out


func _count_tiles(model: Assistant.Model) -> int:
	var tiles: int = 0
	for placement: Assistant.Placement in model.placements:
		if TILES.has(placement.part):
			tiles += 1
	return tiles


## What stands, as "part colour transform" -> how many.
func _standing() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var key: String = "%s %d %s" % [brick.part_id, brick.color_code, brick.transform]
		out[key] = int(out.get(key, 0)) + 1
	return out


func _clear() -> void:
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()


func _ok(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_failures += 1
