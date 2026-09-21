## Throwaway review probe: does state survive Clear that should not?
##   godot --headless --path . --script src/dev/_zzr_state_probe.gd
extends SceneTree


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main.tscn")
	var main: Node = scene.instantiate()
	get_root().add_child(main)
	for _n: int in 8:
		await process_frame

	var store: ModelStore = main.get("_store")
	var world: BrickWorld = main.get("_world")
	var bar: ModelBar = main.get("_bar")
	var builder: Builder = main.get("_builder")
	if store == null:
		print("no store — catalogue missing?")
		quit(1)
		return

	print("before clear: bricks=%d scenery=%s" % [
		world.brick_count(), str(store.scenery.keys())])

	bar._on_clear()
	for _n: int in 4:
		await process_frame
	print("after  clear: bricks=%d scenery=%s" % [
		world.brick_count(), str(store.scenery.keys())])

	var stale: Array = store.scenery.keys()
	stale.sort()
	var highest: int = int(stale[stale.size() - 1])
	print("highest scenery id still claimed: %d" % highest)

	# Build by hand until the id counter reaches that stale id.
	var placed: int = 0
	var victim: int = 0
	while placed < highest + 2:
		var at := Transform3D(Basis.IDENTITY,
			Vector3((placed % 8) * 80.0, float(placed / 8) * 24.0, 0.0))
		var brick_id: int = world.add_brick("3001", 4, at)
		if brick_id == 0:
			break
		builder.register(brick_id, "3001", at)
		if brick_id == highest:
			victim = brick_id
		placed += 1

	print("placed %d bricks by hand; world now holds %d" % [
		placed, world.brick_count()])
	print("brick id %d is a hand-placed 3001, and scenery claims it: %s" % [
		victim, str(store.scenery.has(victim))])

	var text: String = store.to_text("Test")
	var lines: int = 0
	for line: String in text.split("\n"):
		if line.begins_with("1 "):
			lines += 1
	print("to_text() wrote %d parts for %d hand-placed bricks" % [lines, placed])

	var stock: Inventory = Inventory.of(world, main.get("_library"), store.scenery)
	print("parts list counts %d pieces" % stock.pieces)
	quit(0)
