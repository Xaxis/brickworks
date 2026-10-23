## Is a part on a turned part's stud held, when the stud's tip is in its own
## part's cover as well?
##
##   godot --headless --path . --script src/dev/turned_tips_probe.gd
##
## A turned part's cover keeps every cell its boxes touch, so it holds its
## own studs' tips as well as the part standing on them. The check asked the
## lattice for the first cover at a tip, and where that was the stud's own
## part it read the tip as in nothing. Where the part on the stud has no
## exact shape, or the part with the stud has none, that lattice reading is
## all the check has: a ball 28 across laid with the chamfered 2 x 4 wings
## (41769b and 41770b, which BrickNet has no shape for) was refused, one
## 1 x 1 tile on a wing's stud in the strip turned 210 degrees "not held",
## and a design that used them lost the tile. The piece count read tips the
## same way, so a part held only by such a stud was a piece of its own.
extends SceneTree

var _failures: int = 0
var _assistant: Assistant
var _library: PartLibrary


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = world
	_assistant.builder = builder
	get_root().add_child(_assistant)
	await process_frame

	_lattice()
	_tips()
	_ball()

	print("")
	print("%s: %d failure%s" % ["PASS" if _failures == 0 else "FAIL", _failures,
		"" if _failures == 1 else "s"])
	quit(0 if _failures == 0 else 1)


## The lattice's own answer: past a part's own cover, and nothing else changed.
func _lattice() -> void:
	print("  a cell in two covers, the stud's own part's first")
	var lattice := BrickLattice.new()
	lattice.occupy_boxes(1, PackedInt32Array([0, 0, 0, 4, 4, 4]))
	lattice.occupy_boxes(2, PackedInt32Array([2, 2, 2, 6, 6, 6]))
	var both := Vector3i(3, 3, 3)
	_check("brick_at names the first, its own: %d" % lattice.brick_at(both),
		lattice.brick_at(both) == 1)
	_check("brick_but past its own names the other: %d" % lattice.brick_but(both, 1),
		lattice.brick_but(both, 1) == 2)
	_check("and past the other names it: %d" % lattice.brick_but(both, 2),
		lattice.brick_but(both, 2) == 1)
	_check("a cell in its own cover alone is in nothing else: %d"
		% lattice.brick_but(Vector3i(1, 1, 1), 1), lattice.brick_but(Vector3i(1, 1, 1), 1) == 0)
	_check("a cell in another's alone is that one's: %d"
		% lattice.brick_but(Vector3i(5, 5, 5), 1), lattice.brick_but(Vector3i(5, 5, 5), 1) == 2)
	_check("an empty cell is in nothing: %d" % lattice.brick_but(Vector3i(9, 9, 9), 1),
		lattice.brick_but(Vector3i(9, 9, 9), 1) == 0)


## The check's two readings of a stud's tip, support and pieces, on two covers
## laid as a turned section lays them: a 1 x 1 plate's tip in its own cover
## and in a tile's, both covers topping out at the same cell, so that what
## sits on top of either finds nothing.
func _tips() -> void:
	print("")
	print("  a plate's stud tip in its own cover and a tile's")
	var model: Assistant.Model = _assistant._read_model({"bricks": [
		{"part": "3024", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3070b", "color": 4, "x": 6, "y": 0, "z": 6, "rot": 0}]})
	var plate: Assistant.Placement = model.placements[0]
	var part: Lbm.PartMesh = _library.mesh_for(plate.part)
	var tip := Vector3.ZERO
	for connector: Lbm.Connector in part.connectors:
		if connector.kind == "stud" and connector.gender == "male":
			tip = _assistant._joined_at(plate, part, model) * (connector.position
				+ connector.axis.normalized() * Joints.STUD_REACH)
	var t: Vector3i = BrickLattice.to_cell(tip)
	var own := PackedInt32Array([t.x - 3, t.y - 3, t.z - 3, t.x + 1, t.y + 1, t.z + 1])
	var tile := PackedInt32Array([t.x, t.y - 3, t.z, t.x + 4, t.y + 1, t.z + 4])
	var lattice := BrickLattice.new()
	lattice.occupy_boxes(1, own)
	lattice.occupy_boxes(2, tile)
	var cells_of: Dictionary = {0: own, 1: tile}
	var reaching: Array = _assistant._studs_reaching_in(model, cells_of, lattice)
	var into: Array = reaching.map(func(pair: Array) -> String: return "%d>%d" % [pair[0], pair[1]])
	_check("support reads the plate's stud in the tile: %s" % [into], into == ["0>1"])
	var pieces: Array = _assistant._pieces_of(model, cells_of, lattice, cells_of.duplicate())
	_check("and the two are one piece: %d" % pieces.size(), pieces.size() == 1)


## The model it was found on: the ball's own wings swapped for the chamfered
## ones, the same 2 x 4s to a stud, with no exact shape.
func _ball() -> void:
	print("")
	print("  a ball 28 across of hinged panels, its long wings the chamfered ones")
	var model: Assistant.Model = _assistant._read_model({"patterns": [{"pattern": "shell",
		"kind": "ball", "across": 28, "at": {"x": 20, "y": 0, "z": 20}, "color": 1}]})
	var swapped: int = 0
	for placement: Assistant.Placement in model.placements:
		if placement.part == "41769a" or placement.part == "41770a":
			placement.part = placement.part.trim_suffix("a") + "b"
			swapped += 1
	_check("its %d long wings swapped, of %d parts, for ones with no exact shape" % [swapped,
		model.placements.size()], swapped >= 24 and Exact.shape_for(_library, "41769b") == null
		and Exact.shape_for(_library, "41770b") == null)
	var verdict: Dictionary = _assistant._check(model, true)
	var unheld: Array = verdict.get("unheld", [])
	var said: PackedStringArray = []
	for index: Variant in unheld:
		var placement: Assistant.Placement = model.placements[int(index)]
		said.append("%s at %s in '%s'" % [placement.part, placement.where(), placement.section])
	_check("nothing on their studs is said not held: %s" % (", ".join(said) if not said.is_empty()
		else "none"), unheld.is_empty())
	_check("and the check passes: %s" % verdict["summary"], bool(verdict["ok"]))
	if not bool(verdict["ok"]):
		print("     %s" % str(verdict["feedback"]).replace("\n", " ").substr(0, 600))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
