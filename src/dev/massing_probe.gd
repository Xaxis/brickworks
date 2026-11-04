## How much of its box a model fills, and what a session is told of it.
##
##   godot --headless --path . --script src/dev/massing_probe.gd
##
## The measure first, on models laid here: a block on a plate is its box
## (the plate left out as ground), two towers over a hall are not. Then
## a bench design of 7746-1, the Single-Drum Roller (d13l44, 217 parts),
## opened from its file: it fills 59% of its box, as design15's read of the
## bench said, where City sets of its size fill 15% to 28%, the set under
## test held out by number and name. review_model of the whole says so, and
## not again while the massing is the same. A session's first build of a
## block is told it in the build's answer, a lean one (walls round an open
## yard) nothing, and a brief naming no theme or kind nothing.
extends SceneTree


## The loop with the request taken out. Everything else is the real one.
class Offline extends Assistant:
	func _send() -> void:
		pass


const FIXTURES := "res://tests/fixtures/massing/"
const BRIEF := "Single-Drum Roller, in the style of LEGO® City sets: fitting in about 24 x 27 " \
	+ "studs, 160 to 270 pieces."

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DesignMemory.hold_out(PackedStringArray(["7746-1"]))
	DesignMemory.hold_name("Single-Drum Roller")
	Assistant.design_parts = 1
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("FAIL no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var assistant := Offline.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	await process_frame

	print("the measure")
	var block: Dictionary = await _built(assistant, world, builder, [
		_fill(0, 0, 0, 16, 16, 1, 1, 72),
		_fill(2, 1, 2, 12, 12, 4, 3, 19)])
	_ok(float(block.get("fill", 0.0)) >= 0.97 and int(block.get("ground", 0)) == 1
		and block.get("box", []) == [12.0, 12.0, 12],
		"a 12 x 12 block 12 plates tall on a 16 x 16 plate fills its box, the plate left out "
		+ "as ground: %s" % _said(block))
	var towers: Dictionary = await _built(assistant, world, builder, [
		_fill(0, 0, 0, 16, 8, 2, 3, 19),
		_fill(0, 6, 0, 4, 8, 6, 3, 19),
		_fill(12, 6, 0, 4, 8, 6, 3, 19)])
	_ok(absf(float(towers.get("fill", 0.0)) - 0.625) < 0.01 and int(towers.get("ground", 1)) == 0
		and absf(float(towers.get("front", 0.0)) - 0.625) < 0.01
		and is_equal_approx(float(towers.get("side", 0.0)), 1.0),
		"two towers over a hall two bricks tall fill five eighths of their box, from the front "
		+ "too, and all of it from the side: %s" % _said(towers))

	print("\na bench design, and the sets it is measured against")
	world.clear()
	builder.lattice.clear()
	var ldr: LdrModel = LdrModel.load_file(FIXTURES + "single_drum_roller.ldr")
	for piece: LdrModel.Placement in ldr.flatten():
		var part_id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(part_id) == null:
			continue
		var id: int = world.add_brick(part_id, piece.color_code, piece.transform)
		if id != 0:
			builder.register(id, part_id, piece.transform)
	var ids: Array = []
	for brick: BrickWorld.Brick in assistant._bricks_inside({}):
		ids.append(brick.id)
	_ok(ids.size() == 212, "the roller is built: %d parts" % ids.size())
	var roller: Dictionary = Massing.read(builder.lattice, ids)
	_ok(absf(float(roller.get("fill", 0.0)) - 0.59) < 0.01,
		"it fills 59%% of its box, as the bench read said: %s" % _said(roller))
	var held: Array = (SetKnowledge.massing().get("models", []) as Array).filter(
		func(row: Array) -> bool: return str(row[0]).begins_with("7746"))
	_ok(held.is_empty(), "the set under test is not in the table while it is held out")
	var all: Array = (SetKnowledge._load(SetKnowledge.MASSING).get("models", []) as Array).filter(
		func(row: Array) -> bool: return str(row[0]) == "7746-1")
	_ok(all.size() == 1, "...and is in the file: %s" % str(all))
	var ref: Dictionary = Massing.sets_like(BRIEF, PackedStringArray(), 215)
	_ok(str(ref.get("by", "")) == "City sets" and int(ref.get("sets", 0)) >= Massing.FEWEST
		and int(ref.get("low", 0)) >= 215 / Massing.BAND and int(ref.get("high", 0)) <= 215 * Massing.BAND,
		"City sets of about 215 parts: %s" % str(ref))
	_ok(float(ref.get("q3", 1.0)) < 0.35 and float(ref.get("q1", 0.0)) > 0.1,
		"...filling a quarter of their box or so: %d%% to %d%%" % [roundi(float(ref.get("q1", 0.0)) * 100),
			roundi(float(ref.get("q3", 0.0)) * 100)])

	print("\nwhat a session is told")
	assistant.heard("single drum roller", true)
	assistant._words_passed = BRIEF
	var reviewed: String = _text_of(await assistant.review(""))
	var finding: String = reviewed.substr(reviewed.find("Massing: "))
	print("    " + finding.substr(0, 1200).replace("\n", "\n    "))
	_ok(reviewed.contains("Massing: seen from above, every column counted from its top down, "
		+ "the model fills 59% of its box. City sets of "), "review_model says how much it fills")
	_ok(reviewed.contains("none under test), so it is fuller than three in four of them"),
		"...against City sets of its size, none under test")
	_ok(reviewed.contains("If this subject is a block, keep it and say why."),
		"...for the session to settle")
	var again: String = _text_of(await assistant.review(""))
	_ok(not again.contains("Massing: "), "...and not again while the massing is the same")
	_ok(Massing.sets_like("A thing", PackedStringArray(), 300).is_empty(),
		"a brief naming no theme or kind measures nothing")

	print("\na session's first build")
	assistant._words_passed = "A depot, in the style of LEGO® City sets, 150 to 250 pieces."
	world.clear()
	builder.lattice.clear()
	var first: String = str(await assistant.use_tool("submit_design", {"name": "depot",
		"description": "a fixture", "floor": "none", "bricks": [], "features": [],
		"patterns": [_fill(2, 0, 2, 12, 12, 4, 3, 19)]}))
	_ok(first.begins_with("Built") and first.contains("Massing: seen from above")
		and first.contains("fills 100% of its box"), "a block is told it in the build's answer")
	if not first.contains("Massing: "):
		print("    " + first.left(1500).replace("\n", "\n    "))
	world.clear()
	builder.lattice.clear()
	var yard: String = str(await assistant.use_tool("submit_design", {"name": "yard",
		"description": "a fixture", "floor": "none", "bricks": [], "features": [],
		"patterns": [_walls(0, 0, 0, 24, 24, 2, 3, 19)]}))
	var open_ids: Array = []
	for brick: BrickWorld.Brick in assistant._bricks_inside({}):
		open_ids.append(brick.id)
	var depot_ref: Dictionary = Massing.sets_like(assistant._words_passed, PackedStringArray(), 200)
	var open_yard: Dictionary = Massing.read(builder.lattice, open_ids)
	_ok(yard.begins_with("Built") and not yard.contains("Massing: ")
		and float(open_yard.get("fill", 1.0)) < float(depot_ref.get("q3", 0.0)),
		"walls round an open yard, filling less than three in four of its sets, are told "
		+ "nothing: %s against %d%%" % [_said(open_yard), roundi(float(depot_ref.get("q3", 0.0)) * 100)])
	if not yard.begins_with("Built"):
		print("    " + yard.left(800).replace("\n", "\n    "))

	print("\nmassing: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## A solid rectangle of bricks or plates as the shape pattern lays one.
func _fill(x: int, y: int, z: int, across: int, deep: int, layers: int, rise: int,
		color: int) -> Dictionary:
	return {"pattern": "fill", "shape": "rectangle", "at": {"x": x, "y": y, "z": z},
		"across": across, "deep": deep, "layers": layers, "rise": rise, "color": color}


## Its walls alone, a stud thick, open at the top.
func _walls(x: int, y: int, z: int, across: int, deep: int, layers: int, rise: int,
		color: int) -> Dictionary:
	var out: Dictionary = _fill(x, y, z, across, deep, layers, rise, color)
	out["wall"] = 1
	return out


## The massing of what [param patterns] lay, built as a session's design is.
func _built(assistant: Assistant, world: BrickWorld, builder: Builder, patterns: Array) -> Dictionary:
	world.clear()
	builder.lattice.clear()
	var answer: Variant = await assistant.use_tool("submit_design", {"name": "fixture",
		"description": "a fixture", "floor": "none", "bricks": [], "features": [],
		"patterns": patterns})
	if not str(answer).begins_with("Built"):
		print("    not built: %s" % str(answer).left(300))
		return {}
	var ids: Array = []
	for brick: BrickWorld.Brick in assistant._bricks_inside({}):
		ids.append(brick.id)
	return Massing.read(builder.lattice, ids)


func _said(found: Dictionary) -> String:
	if found.is_empty():
		return "nothing"
	return "fill %.2f, front %.2f, side %.2f, plan %.2f, ground %d, box %s" % [found["fill"],
		found["front"], found["side"], found["plan"], found["ground"], str(found["box"])]


func _text_of(message: Variant) -> String:
	if message is String:
		return message
	var said := PackedStringArray()
	for block: Variant in message:
		if block is Dictionary and (block as Dictionary).get("type", "") == "text":
			said.append(str((block as Dictionary).get("text", "")))
	return "\n".join(said)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
