## Before and after pictures of colouring a model's hidden parts, and the
## proof that its outside did not change.
##
##   godot --path . --script src/dev/hidden_colours_pictures.gd -- \
##       [--mode=sections] [--stages=0] [--on-table] FILE ...
##
## Needs a window. Each file is opened as File, Open opens it, measured
## (SeenParts, 128 sides), planned (HiddenColours) and coloured, as the
## panel's Apply does; then drawn from the front corner and cut open
## through the middle, before and after, into
## shots/hidden_colours/<file>/ (outside_before, outside_after,
## inside_before, inside_after, and all four in sheet.png), and drawn again
## before and after from eight sides, three of them never measured from,
## and compared pixel for pixel. One line a file is printed, and goes to
## shots/hidden_colours/pictures.jsonl.
##
## Not in the suite: Orthanc alone is minutes. The probe
## (hidden_colours_probe.gd) is the check; this is the evidence to look at.
extends SceneTree

const SHOTS := "res://shots/hidden_colours"
const CORNER := Vector3(0.72, 0.52, 0.72)

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _seen: SeenParts


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var mode: String = "sections"
	var stages: int = 0
	var on_table: bool = false
	var files: Array = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--stages="):
			stages = int(argument.trim_prefix("--stages="))
		elif argument == "--on-table":
			on_table = true
		else:
			files.append(argument)
	if not SeenParts.possible():
		print("  no rendering device — this needs a window")
		quit(1)
		return
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var log := FileAccess.open(ProjectSettings.globalize_path(SHOTS.path_join("pictures.jsonl")),
		FileAccess.READ_WRITE if FileAccess.file_exists(SHOTS.path_join("pictures.jsonl"))
		else FileAccess.WRITE)
	log.seek_end()
	for path: String in files:
		var row: Dictionary = await _one(path, mode, stages, on_table)
		print("  " + JSON.stringify(row))
		log.store_line(JSON.stringify(row))
		log.flush()
	log.close()
	quit(0)


func _one(path: String, mode: String, stages: int, on_table: bool) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	_builder.forget_history()
	_store.open_text(FileAccess.get_file_as_string(path), path.get_file())
	await process_frame
	var assemblies := Assemblies.new()
	assemblies.world = _world
	assemblies.builder = _builder
	assemblies.library = _library
	assemblies.scenery = _store.scenery
	var before: Array = HiddenColours.bricks_of(_world, _store.scenery)
	var measured: SeenParts.Result = await _seen.measure(before)
	var steps: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery,
		{}, true)
	var made: HiddenColours.Plan = HiddenColours.plan(_world, _library, _store.scenery,
		measured.hidden(on_table), mode, steps, assemblies, {}, stages)
	made.views = measured.views
	made.pixel = measured.coarsest
	HiddenColours.apply(made, _world, _builder, assemblies)
	var after: Array = HiddenColours.bricks_of(_world, _store.scenery)
	var rebuilt: int = assemblies.copies_follow(_builder.touched_groups(_builder.last_step()))[1]

	var name: String = path.get_file().get_basename()
	var into: String = SHOTS.path_join(name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(into))
	var frame: AABB = _frame(before)
	var cut: Array = HiddenColoursPanel.cut_through(before, made.changes, _library)
	# What was applied, as it stands in the world after (SeenParts.pictures
	# draws before and after in one world, only the colours changed).
	var applied: Dictionary = {}
	var was_colour: Dictionary = {}
	for entry: Array in before:
		was_colour[int(entry[0])] = int(entry[2])
	for entry: Array in after:
		if int(entry[2]) != int(was_colour.get(int(entry[0]), -1)):
			applied[int(entry[0])] = int(entry[2])
	var outside: Array = await _seen.pictures(before, applied, CORNER, frame, 900)
	var inside: Array = await _seen.pictures(before, applied, cut[1], frame, 900, true, cut[0])
	var shots: Dictionary = {"outside_before": outside[0], "outside_after": outside[1],
		"inside_before": inside[0], "inside_after": inside[1]}
	for key: String in shots:
		if shots[key] != null:
			(shots[key] as Image).save_png(ProjectSettings.globalize_path(into.path_join(key + ".png")))
	_sheet(shots).save_png(ProjectSettings.globalize_path(into.path_join("sheet.png")))

	# The outside, from eight sides, three of them never measured from.
	var differ: Array = []
	for way: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(-1, 0, 0),
			Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0.37, 0.61, -0.7),
			Vector3(-0.83, 0.21, 0.52), Vector3(0.2, -0.9, 0.39)]:
		if on_table and way.y < -0.05:
			continue
		var pair: Array = await _seen.pictures(before, applied, way, frame, 800)
		var was: Image = pair[0]
		var now: Image = pair[1]
		var off: int = _apart(was, now)
		differ.append(off)
		# A side that differs, kept to look at.
		if off != 0 and was != null and now != null:
			was.save_png(ProjectSettings.globalize_path(into.path_join("differs_%d_before.png"
				% differ.size())))
			now.save_png(ProjectSettings.globalize_path(into.path_join("differs_%d_after.png"
				% differ.size())))
	var groups: Array = []
	for group: HiddenColours.Group in made.groups:
		if group.recoloured > 0:
			groups.append([group.label, HiddenColours.colour_name(_library, group.colour),
				group.recoloured])
	return {"file": path.get_file(), "mode": mode, "on_table": on_table,
		"parts": made.parts, "hidden": made.hidden, "coloured": made.changes.size(),
		"groups": groups, "kept": made.kept, "views": made.views,
		"pixel": snappedf(made.pixel, 0.01), "copies_rebuilt": rebuilt,
		"outside_pixels_differ": differ, "seconds": snappedf(
			float(Time.get_ticks_msec() - started) / 1000.0, 0.1)}


func _frame(bricks: Array) -> AABB:
	var whole := AABB()
	var any: bool = false
	for entry: Array in bricks:
		var part: Lbm.PartMesh = _library.mesh_for(str(entry[1]))
		if part == null:
			continue
		var box: AABB = (entry[3] as Transform3D) * part.bounds
		whole = box if not any else whole.merge(box)
		any = true
	return whole


## The four pictures on one sheet: outside above, inside below, before on
## the left.
static func _sheet(shots: Dictionary) -> Image:
	var size := Vector2i(0, 0)
	for key: String in shots:
		if shots[key] != null:
			size = size.max((shots[key] as Image).get_size())
	var sheet: Image = Image.create(size.x * 2 + 12, size.y * 2 + 12, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(1, 1, 1))
	var at: Dictionary = {"outside_before": Vector2i(0, 0), "outside_after": Vector2i(size.x + 12, 0),
		"inside_before": Vector2i(0, size.y + 12), "inside_after": Vector2i(size.x + 12, size.y + 12)}
	for key: String in at:
		var shot: Image = shots.get(key)
		if shot == null:
			continue
		if shot.get_format() != Image.FORMAT_RGBA8:
			shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), at[key])
	return sheet


static func _apart(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return -1
	var first: PackedByteArray = a.get_data()
	var second: PackedByteArray = b.get_data()
	if first == second:
		return 0
	var off: int = 0
	for at: int in range(0, first.size(), 4):
		if first[at] != second[at] or first[at + 1] != second[at + 1] \
				or first[at + 2] != second[at + 2]:
			off += 1
	return off
