## How much of its box a model fills, a design's massing planned before its
## first brick, and its builds held to the plan.
##
##   godot --headless --path . --script src/dev/massing_probe.gd
##
## The measure first, on models laid here: a block on a plate is its box
## (the plate left out as ground), two towers over a hall are not; a bench
## design of 7746-1, the Single-Drum Roller (d13l44), fills 59% of its box
## where City sets of its size fill 15% to 28%, the set under test held out
## by number and name.
##
## Then the plan (plan_massing): a tower on a podium is read as planned,
## its setback said, its fill against City sets, its outline drawn from the
## front and the side; a block is told it is fuller than three in four of
## them. how_real_sets_build_this asks for the plan until there is one.
##
## Then each build read against it, as a session's first build is: built as
## planned; the tower short; the setback built up; a gap between wings
## filled; the space under a deck filled; a chimney missing; a gabled roof
## built flat; a rotunda built square; walls round an open room as planned;
## a plan laid 20 studs off the build read where the build stands; and a
## build with no plan asked for one after its first line.
extends SceneTree


## The loop with the request taken out. Everything else is the real one.
class Offline extends Assistant:
	func _send() -> void:
		pass


const FIXTURES := "res://tests/fixtures/massing/"
const BRIEF := "Single-Drum Roller, in the style of LEGO® City sets: fitting in about 24 x 27 " \
	+ "studs, 160 to 270 pieces."
const DEPOT := "A depot, in the style of LEGO® City sets, 150 to 250 pieces."

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
	_ok(absf(float(towers.get("fill", 0.0)) - 0.625) < 0.01 and int(towers.get("ground", 1)) == 0,
		"two towers over a hall two bricks tall fill five eighths of their box: %s" % _said(towers))
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
	var roller: Dictionary = Massing.read(builder.lattice, ids)
	_ok(ids.size() == 212 and absf(float(roller.get("fill", 0.0)) - 0.59) < 0.01,
		"a bench design of 7746-1, %d parts, fills 59%% of its box: %s" % [ids.size(), _said(roller)])
	var held: Array = (SetKnowledge.massing().get("models", []) as Array).filter(
		func(row: Array) -> bool: return str(row[0]).begins_with("7746"))
	var all: Array = (SetKnowledge._load(SetKnowledge.MASSING).get("models", []) as Array).filter(
		func(row: Array) -> bool: return str(row[0]) == "7746-1")
	_ok(held.is_empty() and all.size() == 1,
		"7746-1 is in the sets' file and not in what a design is measured by while it is held out")
	var ref: Dictionary = Massing.sets_like(BRIEF, PackedStringArray(), 215)
	_ok(str(ref.get("by", "")) == "City sets" and int(ref.get("sets", 0)) >= Massing.FEWEST
		and float(ref.get("q3", 1.0)) < 0.35 and float(ref.get("q1", 0.0)) > 0.1,
		"City sets of about 215 parts fill %d%% to %d%% of their box (%d sets)" % [
			roundi(float(ref.get("q1", 0.0)) * 100), roundi(float(ref.get("q3", 0.0)) * 100),
			int(ref.get("sets", 0))])
	_ok(Massing.sets_like("A thing", PackedStringArray(), 300).is_empty(),
		"a brief naming no theme or kind is measured by no sets")

	print("\nthe plan, before any brick")
	world.clear()
	builder.lattice.clear()
	assistant.heard("a depot", true)
	var asked: String = _text_of(await assistant.use_tool("how_real_sets_build_this",
		{"subject": "depot"}))
	_ok(asked.ends_with(Assistant.PLAN_MASSING_NEXT),
		"how_real_sets_build_this ends by asking for the plan, while there is none")
	var refused: String = str(await assistant.use_tool("plan_massing", {"volumes": [
		{"name": "tower", "x_from": 4, "x_to": 4, "z_from": 0, "z_to": 8, "y_to": 30}]}))
	_ok(refused.begins_with("tower: each _to is past its _from"),
		"a volume with no width is refused, said what to give: %s" % refused.left(80))
	var plan: String = str(await assistant.use_tool("plan_massing", {"brief": DEPOT,
		"volumes": _tower_on_podium(0), "front": "a tall tower over a low hall",
		"side": "the same, the tower set back"}))
	print("    " + plan.replace("\n", "\n    "))
	_ok(plan.begins_with("Massing planned: 2 volumes, 16 x 16 studs and 30 plates over all. "
		+ "Seen from above, every column counted from its top down, it fills 40% of its box. "
		+ "City sets of "), "the answer leads with how much of its box the plan fills, 40%, "
		+ "against City sets")
	_ok(plan.contains("none under test): fuller than three in four of them")
		and plan.contains("If this subject is a block, keep it and say why."),
		"...fuller than three in four, for the session to settle")
	_ok(plan.contains("tower: 8 x 8 studs, 6 to 30 plates (x 4 to 12, z 4 to 12), on the podium: "
		+ "set back 4 at the front, 4 at the back, 4 at the left, 4 at the right"),
		"...the tower read as set back on the podium")
	var front: PackedStringArray = plan.substr(plan.find("From the front:")).split("\n\n")[0] \
		.split("\n")
	_ok(front.size() > 4 and front[1].count("#") < front[front.size() - 2].count("#")
		and front[1].contains("top 30 plates"),
		"...its outline from the front drawn, the tower narrower than the podium")
	var asked_again: String = _text_of(await assistant.use_tool("how_real_sets_build_this",
		{"subject": "depot"}))
	_ok(not asked_again.contains("plan_massing"), "...and how_real_sets_build_this asks no more")
	var full: String = str(await assistant.use_tool("plan_massing", {"volumes": [
		{"name": "lean-to", "x_from": 0, "x_to": 4, "z_from": 0, "z_to": 12, "y_to": 12,
			"top": {"x_from": 0, "x_to": 1}},
		{"name": "shed", "x_from": 4, "x_to": 16, "z_from": 0, "z_to": 12, "y_to": 12,
			"top": {"z_from": 6, "z_to": 6}}]}))
	_ok(full.contains("rising to a ridge along x")
		and full.contains("narrowing to 1 x 12 at its top"),
		"a roof's ridge and a lean-to's slope are read from their tops")

	print("\neach build, read against the plan")
	await _plan(assistant, _tower_on_podium(0))
	var as_planned: String = await _build(assistant, world, builder, _podium_and_tower(30))
	_ok(as_planned.begins_with("Massing: built as planned: the podium and tower, each there at "
		+ "its height") and as_planned.contains("\n\nBuilt. "),
		"built as planned, said first, then that it stands: %s" % as_planned.left(160))
	_ok(as_planned.contains("You planned it to read from the front as: a tall tower over a low "
		+ "hall; and from the side as: the same, the tower set back."),
		"...with the front and the side it was planned to read as")
	var short: String = await _build(assistant, world, builder, _podium_and_tower(18))
	_ok(short.begins_with("Massing, against the plan: 1 of 2 volumes as planned (the podium).")
		and short.contains("tower: short, its top at about 18 plates where 30 was planned."),
		"a tower built to 18 plates of 30 is short: %s" % _first(short, "tower"))
	var boxed: String = await _build(assistant, world, builder, [_fill(0, 0, 0, 16, 16, 10, 3, 19)])
	_ok(boxed.contains("podium: the setback round the tower is built up, 192 square studs of it "
		+ "to about 30 plates, where its top was planned at 6."),
		"a box built for it has the setback round the tower built up: %s" % _first(boxed, "podium"))
	await _plan(assistant, [
		_volume("west wing", 0, 6, 0, 10, 0, 12), _volume("east wing", 10, 16, 0, 10, 0, 12)])
	var bridged: String = await _build(assistant, world, builder, [_fill(0, 0, 0, 16, 10, 4, 3, 19)])
	_ok(bridged.contains("between the west wing and the east wing (planned open, 4 x 10 studs): "
		+ "built up over 100% of it, to about 12 plates."),
		"the gap between two wings, built up, is said: %s" % _first(bridged, "between"))
	await _plan(assistant, [
		_volume("post", 6, 10, 4, 8, 0, 12), _volume("deck", 0, 16, 0, 12, 12, 15)])
	var under: String = await _build(assistant, world, builder, [_fill(0, 0, 0, 16, 12, 5, 3, 19)])
	_ok(under.contains("deck: the space under it, planned open below 12 plates, is filled under "),
		"the space under a deck, filled, is said: %s" % _first(under, "deck"))
	await _plan(assistant, [
		_volume("house", 0, 16, 0, 12, 0, 9), _volume("chimney", 12, 14, 2, 4, 9, 21)])
	var no_chimney: String = await _build(assistant, world, builder,
		[_fill(0, 0, 0, 16, 12, 3, 3, 19)])
	_ok(no_chimney.contains("chimney: only 0% of it is built where it was planned"),
		"a chimney not built is said missing: %s" % _first(no_chimney, "chimney"))
	var gabled: Dictionary = _volume("roof", 0, 16, 0, 12, 9, 18)
	gabled["top"] = {"z_from": 6, "z_to": 6}
	await _plan(assistant, [_volume("house", 0, 16, 0, 12, 0, 9), gabled])
	var flat: String = await _build(assistant, world, builder, [_fill(0, 0, 0, 16, 12, 6, 3, 19)])
	_ok(flat.contains("roof: built up past its slope over ")
		and flat.contains("its top was to come down to its edges."),
		"a gabled roof built as a flat block is said built past its slope: %s" % _first(flat, "roof"))
	var rotunda: Dictionary = _volume("rotunda", 0, 12, 0, 12, 0, 12)
	rotunda["round"] = true
	await _plan(assistant, [rotunda])
	var squared: String = await _build(assistant, world, builder, [_fill(0, 0, 0, 12, 12, 4, 3, 19)])
	_ok(squared.contains("round the rotunda (planned open, ") and squared.contains(" in 4 places)"),
		"a rotunda built square has its four corners said: %s" % _first(squared, "round the"))
	await _plan(assistant, [_volume("room", 0, 12, 0, 12, 0, 12)])
	var walls: Dictionary = _fill(0, 0, 0, 12, 12, 4, 3, 19)
	walls["wall"] = 1
	var room: String = await _build(assistant, world, builder, [walls])
	_ok(room.begins_with("Massing: built as planned"),
		"walls round an open room are the room as planned: %s" % room.left(120))
	await _plan(assistant, _tower_on_podium(20))
	var moved: String = await _build(assistant, world, builder, _podium_and_tower(30))
	_ok(moved.begins_with("Massing: built as planned (read with the plan moved -20 studs across "
		+ "and 0 deep, to where the build stands)"),
		"a plan laid 20 studs off the build is read where the build stands: %s" % moved.left(140))

	print("\nno plan")
	assistant.heard("a depot", true)
	_ok(assistant._massing_plan.is_empty(), "a fresh brief begins with no plan")
	var unplanned: String = await _build(assistant, world, builder, _podium_and_tower(30))
	_ok(unplanned.begins_with("Built. ") and unplanned.contains("\n\n" + MassingPlan.NO_PLAN + "\n\n"),
		"a build with no plan says it stands, then asks for the plan")

	print("\nmassing: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## A 16 x 16 podium 6 plates tall, an 8 x 8 tower 24 plates on it, set
## back 4 studs all round; [param x] studs along.
func _tower_on_podium(x: int) -> Array:
	return [_volume("podium", x, x + 16, 0, 16, 0, 6), _volume("tower", x + 4, x + 12, 4, 12, 6, 30)]


## Those built at 0, the tower to [param top] plates.
func _podium_and_tower(top: int) -> Array:
	return [_fill(0, 0, 0, 16, 16, 2, 3, 19), _fill(4, 6, 4, 8, 8, (top - 6) / 3, 3, 72)]


func _volume(name: String, x0: float, x1: float, z0: float, z1: float, y0: float,
		y1: float) -> Dictionary:
	return {"name": name, "x_from": x0, "x_to": x1, "z_from": z0, "z_to": z1, "y_from": y0,
		"y_to": y1}


## plan_massing [param volumes] for a City depot, seen from the front and
## the side as the tower on its podium.
func _plan(assistant: Assistant, volumes: Array) -> void:
	await assistant.use_tool("plan_massing", {"brief": DEPOT, "volumes": volumes,
		"front": "a tall tower over a low hall", "side": "the same, the tower set back"})


## A session's first build of [param patterns], its answer.
func _build(assistant: Assistant, world: BrickWorld, builder: Builder, patterns: Array) -> String:
	world.clear()
	builder.lattice.clear()
	var answer: String = str(await assistant.use_tool("submit_design", {"name": "depot",
		"description": "a fixture", "floor": "none", "bricks": [], "features": [],
		"patterns": patterns}))
	if not answer.contains("Built. "):
		print("    not built: %s" % answer.left(300))
	return answer


## A solid rectangle of bricks or plates as the shape pattern lays one.
func _fill(x: int, y: int, z: int, across: int, deep: int, layers: int, rise: int,
		color: int) -> Dictionary:
	return {"pattern": "fill", "shape": "rectangle", "at": {"x": x, "y": y, "z": z},
		"across": across, "deep": deep, "layers": layers, "rise": rise, "color": color}


## The massing of what [param patterns] lay, built as a session's design is.
func _built(assistant: Assistant, world: BrickWorld, builder: Builder, patterns: Array) -> Dictionary:
	var answer: String = await _build(assistant, world, builder, patterns)
	if not answer.contains("Built. "):
		return {}
	var ids: Array = []
	for brick: BrickWorld.Brick in assistant._bricks_inside({}):
		ids.append(brick.id)
	return Massing.read(builder.lattice, ids)


## The line of [param said] that begins with [param name], after its dash.
func _first(said: String, name: String) -> String:
	for line: String in said.split("\n"):
		if line.strip_edges().trim_prefix("- ").begins_with(name):
			return line.strip_edges()
	return said.left(400).replace("\n", " | ")


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
