extends SceneTree

func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	print("3811 in catalogue: ", library.parts.has("3811"))

	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)

	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)

	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)

	var scenery: Dictionary = {}
	assistant.scenery = scenery

	# Exactly what main.gd:_lay_baseplate does.
	var at := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0))
	var brick_id: int = world.add_brick("3811", 288, at)
	print("baseplate brick id: ", brick_id)
	if brick_id != 0:
		builder.register(brick_id, "3811", at)
		scenery[brick_id] = true

	print("brick_count: ", world.brick_count())
	print("--- _describe_world() ---")
	print(assistant._describe_world())
	print("--- end ---")
	print("--- _model_from_world() placements: ",
		assistant._model_from_world().placements.size())
	quit(0)
