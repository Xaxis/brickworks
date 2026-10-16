## Does our palette pick the colours LEGO picked? For each real set that
## marks its inside, the set's own accent colours against the colours
## HiddenColours chooses for the same set, by build stage and by section.
##
##   godot --path . --script src/dev/hidden_colours_lego.gd -- --out=FILE [--shard=K/N]
##       [--before=PLANNER.gd] FILE ...
##
## Needs a window (SeenParts). Each set is opened as File, Open opens it and
## measured as the repository audit measures (48 sides, one picture each, at
## up to 1,024 pixels, hidden as on a table). Its accent colours are the
## audit's (tools/hidden_colours_audit.py): a vivid plain colour with three
## or more hidden parts and two of every three of its parts hidden. Ours are
## the colours the plan would give, by stage and by section, as a display
## model, with the set's defaults. One line a set:
##   {file, parts, hidden, lego: [codes], stages: [codes], sections: [codes]}
## and, with --before= (a copy of HiddenColours as it was, under another
## class name), stages_before and sections_before from that one.
## tools/hidden_colours_audit.py --lego FILE adds them up.
extends SceneTree

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _seen: SeenParts
## The planner as it was, a script to compare with: --before=res://….gd.
var _before: Script = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var out_path: String = ""
	var shard: int = 0
	var shards: int = 1
	var files: Array = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--before="):
			_before = load(argument.trim_prefix("--before="))
		elif argument.begins_with("--shard="):
			var said: PackedStringArray = argument.trim_prefix("--shard=").split("/")
			shard = int(said[0])
			shards = maxi(1, int(said[1]))
		else:
			files.append(argument)
	if not SeenParts.possible() or out_path.is_empty():
		print("needs a window and --out=")
		quit(1)
		return
	_library = PartLibrary.new()
	_library.load_catalogue()
	_world = BrickWorld.new()
	_world.library = _library
	_world.keeps_history = false
	get_root().add_child(_world)
	_world.visible = false
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	_seen = SeenParts.new()
	_seen.library = _library
	get_root().add_child(_seen)
	await process_frame
	var out := FileAccess.open(out_path, FileAccess.WRITE)
	for n: int in files.size():
		if n % shards != shard:
			continue
		var row: Dictionary = await _one(str(files[n]))
		out.store_line(JSON.stringify(row))
		out.flush()
		print("  " + JSON.stringify(row))
	out.close()
	quit(0)


func _one(path: String) -> Dictionary:
	_builder.forget_history()
	_store.open_text(FileAccess.get_file_as_string(path), path.get_file())
	await process_frame
	var bricks: Array = HiddenColours.bricks_of(_world, _store.scenery)
	var measured: SeenParts.Result = await _seen.measure(bricks, 48, 1.0, 1024, 1)
	var hidden: Dictionary = measured.hidden(true)
	# The set's own accents, as the audit reads them.
	var seen_count: Dictionary = {}
	var hidden_count: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var code: int = _library.plain_code(brick.color_code)
		var into: Dictionary = hidden_count if hidden.has(brick.id) else seen_count
		into[code] = int(into.get(code, 0)) + 1
	var lego: Array = []
	for code: int in hidden_count:
		var h: int = hidden_count[code]
		var s: int = int(seen_count.get(code, 0))
		var colour: PartLibrary.BrickColor = _library.colors.get(code)
		if colour == null or colour.finish != "solid" or colour.group != "solid":
			continue
		if h >= 3 and h * 3 >= (h + s) * 2 and HiddenColours.vivid(colour.rgb):
			lego.append(code)
	var assemblies := Assemblies.new()
	assemblies.world = _world
	assemblies.builder = _builder
	assemblies.library = _library
	assemblies.scenery = _store.scenery
	var steps: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery,
		{}, true)
	var row: Dictionary = {"file": path.get_file(), "parts": bricks.size(), "hidden": hidden.size(),
		"lego": lego}
	for mode: String in ["stages", "sections"]:
		var made: HiddenColours.Plan = HiddenColours.plan(_world, _library, _store.scenery,
			hidden, mode, steps, assemblies, {}, 0)
		row[mode] = _used(made.changes)
		# The palette as it was before (a copy of the planner at 12aaca2,
		# passed by --before=), for the same measure.
		if _before != null:
			var was: Variant = _before.call("plan", _world, _library, _store.scenery, hidden,
				mode, steps, assemblies, {}, 0)
			row[mode + "_before"] = _used((was as Object).get("changes"))
	return row


static func _used(changes: Dictionary) -> Array:
	var used: Dictionary = {}
	for brick_id: int in changes:
		used[int(changes[brick_id])] = true
	return used.keys()
