## A small picture of every piece in the real-set index, as built.
##
##   tools/snippets.py build
##   ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 800x600 \
##     --script src/dev/snippet_thumbs.gd -- [--index=FILE] [--into=DIR] [--size=192]
##
## Writes DIR/<id with / as __>.png for each entry of the index
## (assets/knowledge/snippets.json.gz) that has none yet, into
## vendor/omr/thumbs/ by default: they are what Claude looks at to write
## each piece's description (tools/describe_snippets.sh), and what a
## person browsing the index sees. The app draws its own at search time.
##
## Needs a window (Xvfb will do). Not in the suite: it has no pass or
## fail, only pictures.
extends SceneTree

var _index: String = "res://assets/knowledge/snippets.json.gz"
var _into: String = "res://vendor/omr/thumbs"
var _size: int = 192


func _initialize() -> void:
	_run()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--index="):
			_index = argument.trim_prefix("--index=")
		elif argument.begins_with("--into="):
			_into = argument.trim_prefix("--into=")
		elif argument.begins_with("--size="):
			_size = int(argument.trim_prefix("--size="))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if not ModelShot.possible():
		print("no rendering device: this needs a window")
		quit(1)
		return
	var document: Dictionary = RealSnippets.read(_index)
	if document.is_empty():
		print("no index at %s (tools/snippets.py build)" % _index)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_into)

	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	var shot := ModelShot.new()
	shot.rulers = false
	shot.library = library
	root.add_child(shot)
	await process_frame

	var made: int = 0
	var kept: int = 0
	var failed: int = 0
	var started: int = Time.get_ticks_msec()
	var entries: Array = document.get("entries", [])
	for n: int in entries.size():
		var entry: Dictionary = entries[n]
		var path: String = _into.path_join(RealSnippets.file_name(entry) + ".png")
		if FileAccess.file_exists(path):
			kept += 1
			continue
		for brick: BrickWorld.Brick in world.bricks():
			builder.lattice.release(brick.id)
		world.clear()
		store.scenery.clear()
		store.open_text(RealSnippets.ldr_text(entry), "piece")
		await process_frame
		var image: Image = await shot.take(world, "corner", store.scenery)
		if image == null:
			failed += 1
			continue
		image.resize(_size, _size, Image.INTERPOLATE_LANCZOS)
		image.save_png(path)
		made += 1
		if made % 200 == 0:
			print("  %d made, %d of %d, %.1f s each" % [made, n + 1, entries.size(),
				(Time.get_ticks_msec() - started) / 1000.0 / made])
	print("%d thumbnails made, %d there already, %d without a picture, in %s"
		% [made, kept, failed, ProjectSettings.globalize_path(_into)])
	quit(0)
