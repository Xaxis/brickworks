## A picture of every worked construction, to see that each reads as its name.
##
##   godot --path . --resolution 1400x900 --script src/dev/technique_sheet_probe.gd
##   ... -- --only=stone,arch          just the ones whose names have these
##   ... -- --verdicts=DIR             harvest_probe's passes, to choose from
##   ... -- --into=/some/dir            somewhere other than shots/techniques
##
## techniques_probe proves each construction builds. Whether a "corbel"
## looks like a corbel is a question about a picture. Writes, under
## shots/techniques/: one labelled contact sheet a construction a tile
## (sheet_N.png), every one of them laid out on baseplates (all.png), and
## that layout as LDraw (library.ldr), which tools/style.py measures:
##
##   tools/style.py shots/techniques/library.ldr --against fantasy
##
## Needs a window (Xvfb will do, as tools/check.sh gives one). Not in the
## suite: it has no pass or fail, only pictures for a person to look at.
extends SceneTree

const TILE := 300
const COLUMNS := 6
const PER_SHEET := 36
## The strip under each tile its name is written in.
const LABEL := 52

## Where it all goes; --into= for somewhere else.
var _out: String = "res://shots/techniques"


func _initialize() -> void:
	_run()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 120:
		await process_frame
	var world: BrickWorld = main.get("_world")
	var builder: Builder = main.get("_builder")
	var store: ModelStore = main.get("_store")
	var library: PartLibrary = main.get("_library")
	var assistant: Assistant = main.get("_assistant")
	store.keeps = false
	if not ModelShot.possible():
		print("no rendering device: this needs a window")
		quit(1)
		return

	var only := PackedStringArray()
	var verdicts: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=").split(",", false)
		elif argument.begins_with("--into="):
			_out = argument.trim_prefix("--into=")
		elif argument.begins_with("--verdicts="):
			verdicts = argument.trim_prefix("--verdicts=")
	var items: Array = _items(verdicts, only)
	DirAccess.make_dir_recursive_absolute(_out)

	var shot := ModelShot.new()
	shot.rulers = false
	shot.library = library
	main.add_child(shot)

	# One tile each, framed on the construction alone.
	var tiles: Array[Image] = []
	for item: Dictionary in items:
		_clear(world, builder, store)
		_place(item, Vector3.ZERO, world, builder, assistant, library)
		for _n: int in 4:
			await process_frame
		var image: Image = await shot.take(world, "corner")
		if image == null:
			image = Image.create(TILE, TILE, false, Image.FORMAT_RGB8)
			print("  no picture of %s" % item["label"])
		image.resize(TILE, TILE, Image.INTERPOLATE_LANCZOS)
		tiles.append(image)
	var sheets: int = 0
	for first: int in range(0, tiles.size(), PER_SHEET):
		sheets += 1
		var sheet: Image = await _sheet(tiles.slice(first, first + PER_SHEET),
			items.slice(first, first + PER_SHEET), first)
		sheet.save_png("%s/sheet_%d.png" % [_out, sheets])
	if not verdicts.is_empty():
		print("%d candidates, %d sheet(s), written to %s" % [items.size(), sheets,
			ProjectSettings.globalize_path(_out)])
		quit(0)
		return

	# All of them on the ground together, in rows by what they are for.
	_clear(world, builder, store)
	var x: float = 0.0
	var z: float = 0.0
	var row_deep: float = 0.0
	var group: String = ""
	for item: Dictionary in items:
		var size: Vector3 = _size(item)
		if x > 0.0 and (x + size.x > 72.0 or str(item.get("group", "")) != group):
			x = 0.0
			z += row_deep + 3.0
			row_deep = 0.0
		group = str(item.get("group", ""))
		_place(item, Vector3(x, 0, z), world, builder, assistant, library)
		x += size.x + 3.0
		row_deep = maxf(row_deep, size.z)
	main.call("_lay_baseplate")
	for _n: int in 6:
		await process_frame
	# Framed on the constructions: the plates under them are tiled whole
	# and run well past the last one.
	var built := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in world.bricks():
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if store.scenery.has(brick.id) or part == null:
			continue
		var here: AABB = (brick.transform * part.bounds).abs()
		built = here if first else built.merge(here)
		first = false
	var all: Image = await shot.take(world, "corner", {}, built)
	if all != null:
		all.save_png("%s/all.png" % _out)
	store.export_to(ProjectSettings.globalize_path("%s/library.ldr" % _out),
		"Worked constructions")
	print("%d constructions, %d sheet(s), written to %s" % [items.size(), sheets,
		ProjectSettings.globalize_path(_out)])
	quit(0)


## What to draw: the library, or a harvest's passes to choose from.
func _items(verdicts: String, only: PackedStringArray) -> Array:
	var out: Array = []
	if verdicts.is_empty():
		# In the order show_technique lists them: by what they are for.
		for group: String in Techniques.GROUPS:
			for one: Variant in Techniques.all():
				var technique: Dictionary = one
				if str(technique.get("group", "")) != group:
					continue
				out.append({"label": str(technique["name"]), "group": group,
					"bricks": technique["bricks"]})
	else:
		var file := FileAccess.open(verdicts.path_join("verdicts.jsonl"), FileAccess.READ)
		while file != null and not file.eof_reached():
			var line: String = file.get_line()
			if line.strip_edges().is_empty():
				continue
			var row: Dictionary = JSON.parse_string(line)
			if bool(row["ok"]):
				out.append({"label": str(row["file"]).get_basename(), "group": "",
					"bricks": row["bricks"]})
	if only.is_empty():
		return out
	var kept: Array = []
	for item: Dictionary in out:
		for word: String in only:
			if str(item["label"]).contains(word):
				kept.append(item)
				break
	return kept


## Built the way a design is, offset across the ground.
func _place(item: Dictionary, offset: Vector3, world: BrickWorld,
		builder: Builder, assistant: Assistant, library: PartLibrary) -> void:
	for raw: Variant in item["bricks"]:
		var put: Assistant.Placement = Assistant.Placement.from_dict(raw)
		put.x += offset.x
		put.z += offset.z
		var part: Lbm.PartMesh = library.mesh_for(put.part)
		if part == null:
			print("  %s: no part %s" % [item["label"], put.part])
			continue
		var at: Transform3D = assistant._transform(put, part)
		var id: int = world.add_brick(put.part, put.color, at)
		if id != 0:
			builder.register(id, put.part, at)


## How much ground one takes, in studs, from its placements.
func _size(item: Dictionary) -> Vector3:
	var most := Vector3(2, 0, 2)
	for raw: Variant in item["bricks"]:
		var brick: Dictionary = raw
		most.x = maxf(most.x, float(brick["x"]) + 2.0)
		most.z = maxf(most.z, float(brick["z"]) + 2.0)
	return Vector3(ceilf(most.x), 0, ceilf(most.z))


func _clear(world: BrickWorld, builder: Builder, store: ModelStore) -> void:
	world.clear()
	builder.lattice.clear()
	store.scenery.clear()


## The tiles in a grid with each one's name under it, drawn by the engine
## itself so the sheet needs nothing outside this project to make.
func _sheet(tiles: Array, items: Array, first: int) -> Image:
	var rows: int = int(ceil(float(tiles.size()) / COLUMNS))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(COLUMNS * TILE, rows * (TILE + LABEL))
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var back := ColorRect.new()
	back.color = Color(0.13, 0.13, 0.15)
	back.size = Vector2(viewport.size)
	viewport.add_child(back)
	for n: int in tiles.size():
		var at := Vector2((n % COLUMNS) * TILE, (n / COLUMNS) * (TILE + LABEL))
		var picture := TextureRect.new()
		picture.texture = ImageTexture.create_from_image(tiles[n])
		picture.position = at
		picture.size = Vector2(TILE, TILE)
		viewport.add_child(picture)
		var item: Dictionary = items[n]
		var label := Label.new()
		# Cut short by hand: a Label left to clip itself grew to fit and
		# wrote over its neighbours.
		label.text = ("%d  %s" % [first + n + 1, item["label"]]).left(34)
		if not str(item.get("group", "")).is_empty():
			label.text += "\n" + str(item["group"])
		label.position = at + Vector2(6, TILE + 2)
		label.size = Vector2(TILE - 12, LABEL - 4)
		label.clip_text = true
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
		viewport.add_child(label)
	root.add_child(viewport)
	for _n: int in 4:
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return image
