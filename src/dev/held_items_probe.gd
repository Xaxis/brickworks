## A minifigure holds what it is given, as the Tested mark reads a hand.
##
##   godot --headless --path . --script src/dev/held_items_probe.gd
##
## The windmill session (mcpq259, 2026-10-25) gave its miller a sack, and the
## save's check called it not held, 1.2 LDU into his hand: five turns to set
## it down by his feet. Of the 456 things MinifigData.GRIPS says a hand holds,
## 47 came out held through the figure (a cup's body 2.6 LDU into the torso,
## a hammer's head through the legs) and 44 held by a grip that is not the bar
## BrickNet's connectors put a hand on (a camera by its sight), since the grip
## is laid along the hand's only by the least turn and from the part's own
## lines. Here each figure is stood by one add_minifig (FigureTool.add, no
## second call): a hammer and a cup, a pole and a wrench, a torch and a
## camera, in the right hand and the left; each must pass Tested's whole test
## (every part held by BrickNet's connections, none through another), each
## thing it holds joined to a hand and clear of the figure, and the Minifigure
## builder's figure (FigureTool.parts_of, what it previews and puts down) the
## same. A sack, which BrickNet gives no bar a hand takes, is said so when it
## is put in the hand, not at the save. And an angler stood beside a bollard
## on a jetty turns his rod in his hand rather than being refused the spot.
## Needs BrickNet's shapes; exits
## non-zero when a hand does not hold what it is given.
extends SceneTree

const FIGURES: Array = [
	["a tool and a cup", {"accessory": "hammer", "accessory_left": "cup"}],
	["a pole and a wrench", {"accessory": "pole", "accessory_left": "wrench"}],
	["a torch and a camera", {"accessory": "torch", "accessory_left": "camera"}],
]
const BASE := "0 base\n1 4 0 -8 0 1 0 0 0 1 0 0 0 1 3958.dat\n"

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	if Exact.shape_for(_library, "3820") == null:
		print("held_items probe: SKIPPED, no BrickNet shapes")
		quit(1)
		return
	for figure: Array in FIGURES:
		await _holds(str(figure[0]), figure[1] as Dictionary)
	await _beside_a_bollard()
	await _said_when_not_held()
	print("")
	print("held items: each figure holds what it is given, Tested-held in one call, the "
		+ "builder's alike" if _failures == 0 else "held items: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _holds(what: String, args: Dictionary) -> void:
	print("── a figure holding %s ──" % what)
	_store.open_text(BASE, "base.ldr")
	var asked: Dictionary = {"name": "Holder", "x": 0, "z": 0}
	asked.merge(args)
	var stood: Dictionary = await FigureTool.add(asked, _library, _world, _builder)
	_check("stood by one add_minifig: %s" % str(stood.get("text", "")).left(110),
		bool(stood.get("ok", false)))
	if not bool(stood.get("ok", false)):
		return
	var figure: Minifig = FigureTool.figure_for(asked, _library)[0]
	var wanted: Dictionary = {}
	for slot: String in args:
		wanted[figure.part(slot)] = true
	var items: Array = []
	var ids: Array[String] = []
	var hands := PackedInt32Array()
	var held: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var shape: Exact.Shape = Exact.shape_for(_library, brick.part_id)
		if brick.part_id == "3820":
			hands.append(items.size())
		if wanted.has(brick.part_id):
			held[brick.part_id] = items.size()
		ids.append(brick.part_id)
		items.append(Exact.Item.new(shape, brick.transform) if shape != null else null)
	_check("it holds two things: %s" % ", ".join(PackedStringArray(held.keys())), held.size() == 2)
	for part_id: String in held:
		var i: int = held[part_id]
		var through: String = ""
		for j: int in items.size():
			if j != i and items[j] != null and items[i] != null \
					and not Exact.clash(items[i], items[j], true).is_empty():
				through = ids[j]
		_check("%s: joined to a hand by BrickNet's connectors, through nothing%s" % [part_id,
			"" if through.is_empty() else " (through %s)" % through],
			items[i] != null and Exact.connected(items, i, hands) and through.is_empty())
		_check("...and no lower than the figure's feet: %.1f LDU against %.1f" % [
			(items[i] as Exact.Item).lo.y if items[i] != null else 0.0, _feet(items, held)],
			items[i] != null and (items[i] as Exact.Item).lo.y >= _feet(items, held) - 0.5)
	var text: String = await _store._model_text(false)
	var tested: Dictionary = (await SharedPages.attach_tested(text, _library, _store))["tested"]
	var whole: Dictionary = (tested.get("tests", {}) as Dictionary).get("whole", {})
	_check("Tested's whole test: %s" % str(whole.get("why", "not tested")).left(120),
		bool(whole.get("ok", false)))
	# The Minifigure builder's figure, which it previews and puts down.
	var parts: Array[Dictionary] = FigureTool.parts_of(figure, _library)
	var unheld: PackedStringArray = FigureTool.unheld_in_hand(_library, parts)
	_check("the builder's figure holds them alike: %s" % ("both held" if unheld.is_empty()
		else "not held: %s" % ", ".join(unheld)), unheld.is_empty())


## hand264's own jetty session: its angler, asked for at x 15, z 5 facing
## -z, was refused because his fishing rod ran into the bollard beside him,
## and stood a stud along. The rod turns in his hand instead.
func _beside_a_bollard() -> void:
	print("── an angler beside a bollard on the session's jetty ──")
	_store.open_text(FileAccess.get_file_as_string("res://tests/fixtures/mcp/hand264_jetty.ldr"),
		"jetty.ldr")
	var stood: Dictionary = await FigureTool.add({"name": "Angler", "x": 15, "z": 5,
		"facing": "-z", "headwear": "fishing hat", "head": "smile", "torso": "fishing vest",
		"accessory": "fishing rod", "colors": {"legs": 28, "hips": 28}}, _library, _world, _builder)
	_check("stood where it was asked, the first time: %s" % str(stood.get("text", "")).left(110),
		bool(stood.get("ok", false)))
	if not bool(stood.get("ok", false)):
		return
	var text: String = await _store._model_text(false)
	var tested: Dictionary = (await SharedPages.attach_tested(text, _library, _store))["tested"]
	var whole: Dictionary = (tested.get("tests", {}) as Dictionary).get("whole", {})
	_check("...its rod held in his hand: Tested's whole test: %s" % str(whole.get("why", "")).left(110),
		bool(whole.get("ok", false)))
	var rod: float = INF
	var feet: float = INF
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.group.is_empty() or not brick.group.begins_with("Angler"):
			continue
		var box: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		if brick.part_id == "2614":
			rod = box.position.y
		else:
			feet = minf(feet, box.position.y)
	_check("...and the rod no lower than his feet: %.1f LDU against %.1f" % [rod, feet],
		rod < INF and rod >= feet - 1.0)


## The lowest point of the figure's parts but what it holds, in LDU, y up.
static func _feet(items: Array, held: Dictionary) -> float:
	var low: float = INF
	for j: int in items.size():
		if items[j] != null and not held.values().has(j):
			low = minf(low, (items[j] as Exact.Item).lo.y)
	return low


func _said_when_not_held() -> void:
	print("── a sack, which BrickNet gives no bar a hand takes ──")
	_store.open_text(BASE, "base.ldr")
	var stood: Dictionary = await FigureTool.add({"name": "Miller", "x": 0, "z": 0,
		"accessory_left": "10169"}, _library, _world, _builder)
	var text: String = str(stood.get("text", ""))
	_check("said when it is put in the hand: %s" % text.substr(text.find("10169 (")).left(160),
		bool(stood.get("ok", false)) and text.contains("10169 (")
			and text.contains("the check calls it not held"))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
