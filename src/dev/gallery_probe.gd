## Render every shipped model, so somebody can look at them.
##
##   godot --path . --resolution 1200x800 --script src/dev/gallery_probe.gd
##
## The suite can tell you a model stands up, weighs 110 grams and is in
## one piece. It cannot tell you whether it looks like a house. That is
## a question about a picture, and the only way to answer it is to make
## the picture and look.
extends SceneTree

const OUT := "user://gallery"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame

	var world: BrickWorld = main.get("_world")
	var builder: Builder = main.get("_builder")
	var store: ModelStore = main.get("_store")
	var library: PartLibrary = main.get("_library")
	var stability: Stability = main.get("_stability")

	var shot := ModelShot.new()
	shot.library = library
	main.add_child(shot)
	DirAccess.make_dir_recursive_absolute(OUT)

	var names: PackedStringArray = PackedStringArray()
	for argument: String in OS.get_cmdline_user_args():
		names.append(argument)
	if names.is_empty():
		var here: DirAccess = DirAccess.open("res://models")
		for file: String in here.get_files():
			if file.ends_with(".ldr"):
				names.append(file.get_basename())

	for name: String in names:
		var path: String = "res://models/%s.ldr" % name
		var placed: int = store.open(path)
		if placed == 0:
			print("  %-12s could not open" % name)
			continue
		for _n: int in 20:
			await process_frame

		var verdict: String = stability.check(world).summary()
		for from: String in ["corner", "front"]:
			var image: Image = await shot.take(world, from, store.scenery)
			if image == null:
				print("  %-12s no picture from the %s" % [name, from])
				continue
			image.save_png("%s/%s_%s.png" % [OUT, name, from])
		print("  %-12s %3d bricks · %s" % [name, placed, verdict])

	print("")
	print("written to %s" % ProjectSettings.globalize_path(OUT))
	quit(0)
