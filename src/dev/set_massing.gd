## Every real set's massing (Massing), for a design to be measured against.
##
##   godot --headless --path . --script src/dev/set_massing.gd -- [DIR] [OUT]
##
## DIR is vendor/omr/files (tools/omr.py fetch), OUT
## assets/knowledge/set_massing.json. Each set named in DIR's index.json is
## opened as the app opens a file, and its parts measured as Massing reads
## a design: {"keys": [...], "models": [[number, name, top theme, parts,
## each key's value]]}. SetKnowledge.massing() reads it, holding out the
## sets under test. Not a probe: it needs the repository's files, and a run
## over the 1,235 sets is about ten minutes.
extends SceneTree

const KEYS := ["fill", "front", "side", "plan", "tall"]


func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "res://vendor/omr/files"
	var out_path: String = args[1] if args.size() > 1 else "res://assets/knowledge/set_massing.json"
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		dir.get_base_dir().path_join("index.json")))
	if not index is Array:
		print("no index.json beside %s" % dir)
		quit(2)
		return
	var named: Dictionary = {}
	for row: Variant in index:
		named[str((row as Dictionary).get("number", ""))] = row
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
	await process_frame
	var files: Array = []
	for file: String in DirAccess.get_files_at(dir):
		if (file.ends_with(".mpd") or file.ends_with(".ldr")) and named.has(file.get_basename()):
			files.append(file)
	files.sort()
	var models: Array = []
	for file: String in files:
		var row: Dictionary = named[file.get_basename()]
		world.clear()
		builder.lattice.clear()
		store.open_text(FileAccess.get_file_as_string(dir.path_join(file)), file)
		await process_frame
		var ids: Array = []
		for brick: BrickWorld.Brick in world.bricks():
			ids.append(brick.id)
		var found: Dictionary = Massing.read(builder.lattice, ids)
		if found.is_empty():
			continue
		var one: Array = [str(row["number"]), str(row["name"]),
			str(row.get("theme", "")).get_slice(" > ", 0), ids.size()]
		for key: String in KEYS:
			one.append(snappedf(float(found[key]), 0.001))
		models.append(one)
	var out := FileAccess.open(out_path, FileAccess.WRITE)
	out.store_string(JSON.stringify({"keys": KEYS, "models": models}))
	out.close()
	print("set_massing: %d sets of %d files into %s" % [models.size(), files.size(), out_path])
	quit(0)
