## Prove a model survives being saved and reopened.
##
## The claim is that .ldr is lossless for what this app puts in it — the
## same parts, the same colours, the same places. That is worth checking
## rather than assuming, because the round trip crosses the axis
## conversion twice and a sign error there is invisible on a symmetric
## model.
##
##   godot --headless --path . --script src/dev/store_probe.gd
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)

	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)

	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder

	# A model with rotation and a range of colours, so an axis or sign
	# error in the conversion has something to show up on.
	var wanted: Array = [
		{"part": "3001", "colour": 4, "at": Vector3(0, 24, 0), "turn": 0},
		{"part": "3001", "colour": 14, "at": Vector3(40, 48, 0), "turn": 1},
		{"part": "3024", "colour": 2, "at": Vector3(-60, 24, 40), "turn": 2},
		{"part": "3068b", "colour": 47, "at": Vector3(80, 24, -40), "turn": 3},
	]
	for entry: Dictionary in wanted:
		var at := Transform3D(
			Basis(Vector3.UP, entry["turn"] * PI * 0.5), entry["at"])
		var id: int = world.add_brick(entry["part"], entry["colour"], at)
		if id != 0:
			builder.register(id, entry["part"], at)

	var before: Array = _snapshot(world)
	print("wrote %d bricks" % before.size())

	if not store.save_as("round trip"):
		print("  XX could not save")
		quit(1)
		return

	var reopened: int = store.open(ModelStore.SAVE_DIR + "round trip.ldr")
	var after: Array = _snapshot(world)
	print("read back %d bricks" % reopened)

	_expect(before.size() == after.size(),
		"brick count: %d then %d" % [before.size(), after.size()])

	for n: int in mini(before.size(), after.size()):
		var a: Dictionary = before[n]
		var b: Dictionary = after[n]
		_expect(a["part"] == b["part"],
			"brick %d part: %s then %s" % [n, a["part"], b["part"]])
		_expect(a["colour"] == b["colour"],
			"brick %d colour: %d then %d" % [n, a["colour"], b["colour"]])
		_expect(a["at"].distance_to(b["at"]) < 0.01,
			"brick %d position: %v then %v" % [n, a["at"], b["at"]])
		_expect(_same_basis(a["basis"], b["basis"]),
			"brick %d orientation changed" % n)

	DirAccess.remove_absolute(ModelStore.SAVE_DIR + "round trip.ldr")
	if _failures == 0:
		print("round trip is lossless")
	else:
		print("%d difference(s)" % _failures)
	quit(1 if _failures > 0 else 0)


static func _snapshot(world: BrickWorld) -> Array:
	var out: Array = []
	for item: Variant in world.bricks():
		var brick: BrickWorld.Brick = item
		out.append({
			"part": brick.part_id,
			"colour": brick.color_code,
			"at": brick.transform.origin,
			"basis": brick.transform.basis,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["at"].y != b["at"].y:
			return a["at"].y < b["at"].y
		if a["at"].x != b["at"].x:
			return a["at"].x < b["at"].x
		return a["at"].z < b["at"].z)
	return out


static func _same_basis(a: Basis, b: Basis) -> bool:
	for n: int in 3:
		if a[n].distance_to(b[n]) > 0.001:
			return false
	return true


func _expect(condition: bool, detail: String) -> void:
	if not condition:
		_failures += 1
		print("  XX %s" % detail)
