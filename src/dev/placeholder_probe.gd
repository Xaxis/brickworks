## Does a picture that is still coming look like it is coming?
##
##   godot --path . --resolution 1400x900 --script src/dev/placeholder_probe.gd
##
## Not headless: the previews are drawn by a SubViewport, and with no
## rendering device none would ever arrive.
##
## The parts bin is an infinite scroll over 24,731 parts and the cells it
## adds had no picture until theirs was drawn: an empty square, the same
## as a part that has no picture at all. On the web, where most parts are
## a fetch before they are a render, a fast scroll showed a page of
## nothing for as long as the network took. This asks, of the real app:
##
## * a tile starts as a placeholder and ends as its picture,
## * nothing changes size when the picture lands,
## * a part that cannot be drawn ends as "no preview", not as a
##   placeholder for ever,
## * the tiles on screen are drawn before the ones below them — the bin
##   asked for every cell of a page in list order, so a scroll waited
##   behind every cell scrolled past,
## * and once everything in sight is drawn, no tile is doing any work.
##
## The same for the minifigure builder's grid and its slots. Pictures of
## each state go to shots/placeholders/ for a person to look at.
extends SceneTree

var _failures: int = 0
var _main: Node
var _thumbs: PartThumbnails
var _autosave: PackedByteArray = PackedByteArray()
var _had_autosave: bool = false


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# The app opens and autosaves this machine's own model. Nothing here
	# edits it, and it is put back as it was regardless.
	_had_autosave = FileAccess.file_exists(ModelStore.AUTOSAVE)
	if _had_autosave:
		_autosave = FileAccess.get_file_as_bytes(ModelStore.AUTOSAVE)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(180)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_thumbs = _main.get("_thumbnails")
	var bin: PartsBin = _main.get("_bin")

	print("  the parts bin")
	await _bin_fills_in(bin)
	print("")
	await _in_sight_first(bin)
	print("")
	await _cannot_be_drawn(bin, _main.get("_library"))
	print("")
	print("  the minifigure builder")
	await _builder_fills_in(_main.get("_figures"))

	_put_back_autosave()
	print("")
	if _failures == 0:
		print("placeholder probe: tiles wait as placeholders, land as pictures in place, "
			+ "in sight first, and say when there is none")
	else:
		print("placeholder probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


## A fresh grid: placeholders first, pictures after, nothing moving.
func _bin_fills_in(bin: PartsBin) -> void:
	_forget_pictures()
	# Held while the grid is laid out, so the placeholders can be seen and
	# measured before the first picture lands; on this machine a page
	# fills in a few frames, which a person never sees and a probe barely.
	_thumbs.set_process(false)
	bin._run_search("")
	var tiles: Array[ThumbTile] = _tiles_of(bin.get("_grid"))
	_check("a fresh grid of %d tiles starts with every one waiting" % tiles.size(),
		tiles.size() > 0 and tiles.all(func(tile: ThumbTile) -> bool:
			return tile.state == ThumbTile.State.LOADING))
	await _frames(6)
	var sight: Array[ThumbTile] = _seen(bin.get("_scroll"), tiles)
	var sizes: Dictionary = _sizes(sight)
	_check("and %d of them are in sight, each a placeholder with the shimmer on it"
			% sight.size(),
		sight.size() >= 8 and sight.all(func(tile: ThumbTile) -> bool:
			return tile.state == ThumbTile.State.LOADING and tile.material != null))
	await _shot_of(bin, "desktop_bin_loading")

	_thumbs.set_process(true)
	var took: int = await _until_drawn(sight, 900)
	var drawn: int = sight.filter(func(tile: ThumbTile) -> bool:
		return tile.state == ThumbTile.State.READY and tile.texture != null).size()
	_check("every tile in sight became its picture (%d of %d, %d frames)"
		% [drawn, sight.size(), took], drawn == sight.size())
	var moved: Array[String] = _moved(sizes)
	_check("and nothing changed size when the pictures landed%s"
		% ("" if moved.is_empty() else ": " + ", ".join(moved)), moved.is_empty())
	# Settled: the rows drawn ahead and behind as well as those in sight,
	# and every fade over. Timed rather than counted, because frames here
	# are uncapped and thirty of them are shorter than one fade.
	var sighted: ThumbTile.Sight = bin.get("_sight")
	await _until_drawn(sighted.tiles(), 900)
	await create_timer(ThumbTile.FADE_SECONDS * 3.0).timeout
	var busy: int = tiles.filter(func(tile: ThumbTile) -> bool:
		return tile.is_processing()).size()
	var shimmering: int = sight.filter(func(tile: ThumbTile) -> bool:
		return tile.material != null).size()
	_check("once drawn, no tile is doing any work (%d processing, %d with the shimmer)"
		% [busy, shimmering], busy == 0 and shimmering == 0)
	await _shot_of(bin, "desktop_bin_loaded")


## Scrolled a long way down before anything is drawn: what is on screen
## comes first, what is far below never comes at all until it is near.
func _in_sight_first(bin: PartsBin) -> void:
	_forget_pictures()
	_thumbs.set_process(false)
	bin._run_search("")
	bin._show_more()
	bin._show_more()
	await _frames(8)
	var grid: GridContainer = bin.get("_grid")
	var scroll: ScrollContainer = bin.get("_scroll")
	var tiles: Array[ThumbTile] = _tiles_of(grid)
	var row: float = (grid.get_child(0) as Control).size.y + grid.get_theme_constant("v_separation")
	var rows: int = ceili(float(tiles.size()) / grid.columns)
	scroll.scroll_vertical = int(row * 40.0)
	await _frames(6)
	var sight: Array[ThumbTile] = _seen(scroll, tiles)
	var first_row: int = rows
	var last_row: int = 0
	for tile: ThumbTile in sight:
		var at: int = tiles.find(tile) / grid.columns
		first_row = mini(first_row, at)
		last_row = maxi(last_row, at)
	var screen: int = last_row - first_row + 1
	_check("scrolled to row %d of %d, rows %d to %d in sight"
		% [40, rows, first_row, last_row], not sight.is_empty() and first_row >= 35)

	var landed: Dictionary = {}           ## tile -> frame it became a picture
	_thumbs.set_process(true)
	for frame: int in 900:
		for tile: ThumbTile in tiles:
			if not landed.has(tile) and tile.state != ThumbTile.State.LOADING:
				landed[tile] = frame
		if sight.all(func(tile: ThumbTile) -> bool: return landed.has(tile)) \
				and landed.size() >= sight.size() + screen * grid.columns:
			break
		await process_frame
	# A few more frames, so anything drawn out of order has had its chance.
	await _frames(20)
	for tile: ThumbTile in tiles:
		if not landed.has(tile) and tile.state != ThumbTile.State.LOADING:
			landed[tile] = 99999

	var below: Array[ThumbTile] = []        ## the next screenful, drawn ahead
	var far_below: Array[ThumbTile] = []    ## beyond that
	var far_above: Array[ThumbTile] = []    ## scrolled past
	for index: int in tiles.size():
		var at: int = index / grid.columns
		# The bin counts a row cut by the edge as in sight, and so a
		# screen as a row or two more than the rows whose middles show:
		# "far" starts past the most it could have drawn ahead.
		if at > last_row and at <= last_row + screen:
			below.append(tiles[index])
		elif at > last_row + screen + 4:
			far_below.append(tiles[index])
		elif at < first_row - screen - 2:
			far_above.append(tiles[index])
	var last_seen: int = 0
	for tile: ThumbTile in sight:
		last_seen = maxi(last_seen, int(landed.get(tile, 99999)))
	var first_below: int = 99999
	for tile: ThumbTile in below:
		first_below = mini(first_below, int(landed.get(tile, 99999)))
	_check("all %d tiles in sight were drawn (the last on frame %d)" % [sight.size(), last_seen],
		sight.all(func(tile: ThumbTile) -> bool: return landed.has(tile)))
	_check("before any of the next screenful below (the first of those on frame %d)"
		% first_below, last_seen < first_below)
	var drawn_far: int = far_below.filter(func(tile: ThumbTile) -> bool:
		return landed.has(tile)).size() + far_above.filter(func(tile: ThumbTile) -> bool:
		return landed.has(tile)).size()
	_check("and none of the %d far below or %d scrolled past were drawn at all (%d were)"
		% [far_below.size(), far_above.size(), drawn_far],
		drawn_far == 0 and far_below.size() > 40 and far_above.size() > 40)
	scroll.scroll_vertical = 0


## A part with nothing to draw, and a part with no geometry anywhere.
func _cannot_be_drawn(bin: PartsBin, library: PartLibrary) -> void:
	var empty: PartLibrary.PartInfo = _fake_part("zzprobe-empty", "Probe part with empty geometry")
	library.add_custom(empty, Lbm.PartMesh.new(), "0 probe\n")
	var nowhere: PartLibrary.PartInfo = _fake_part("zzprobe-nowhere", "Probe part with no geometry")
	library.add_custom(nowhere, Lbm.PartMesh.new(), "0 probe\n")
	# Not made here after all: no geometry in the cache, none on disk,
	# and nowhere to fetch it from.
	(library.get("_custom_meshes") as Dictionary).erase(nowhere.mesh_hash)
	library.custom.erase(nowhere.id)

	bin._run_search("zzprobe")
	var tiles: Array[ThumbTile] = _tiles_of(bin.get("_grid"))
	_check("both probe parts are in the bin (%d)" % tiles.size(), tiles.size() == 2)
	var sizes: Dictionary = {}
	await _frames(4)
	sizes = _sizes(tiles)
	# Long enough for a fetch to fail over the network as well as at once:
	# on a machine the deployment answers, the second part is asked of
	# the real parts store, which says 404.
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 30000:
		if tiles.all(func(tile: ThumbTile) -> bool:
				return tile.state == ThumbTile.State.FAILED):
			break
		await process_frame
	for tile: ThumbTile in tiles:
		_check("%s ends as \"no preview\" rather than waiting for ever (%s)"
			% [tile.part_id, ThumbTile.State.keys()[tile.state]],
			tile.state == ThumbTile.State.FAILED and tile.material == null
				and not tile.is_processing())
	var moved: Array[String] = _moved(sizes)
	_check("and the failed tiles kept their size%s"
		% ("" if moved.is_empty() else ": " + ", ".join(moved)), moved.is_empty())
	await _shot_of(bin, "desktop_bin_failed")

	# Out of the library again, ids and all: every search walks the ids
	# and looks each one up.
	var ids: PackedStringArray = library.get("_ordered_ids")
	for info: PartLibrary.PartInfo in [empty, nowhere]:
		library.parts.erase(info.id)
		library.custom.erase(info.id)
		(library.get("_custom_meshes") as Dictionary).erase(info.mesh_hash)
		ids.remove_at(ids.find(info.id))
	library.set("_ordered_ids", ids)
	bin._run_search("")
	await _frames(4)


## The minifigure builder: its grid and its slots wait the same way, and
## the slots' words stay where they are when their pictures land.
func _builder_fills_in(figures: MinifigDialog) -> void:
	_forget_pictures()
	_thumbs.set_process(false)
	figures.open()
	await _frames(8)
	var grid: GridContainer = figures.get("_grid")
	var scroll: ScrollContainer = grid.get_parent()
	var sight: Array[ThumbTile] = _seen(scroll, _tiles_of(grid))
	var slots: Array[ThumbTile] = []
	var words: Array[Control] = []
	for slot: String in Minifig.SLOTS:
		var tile: ThumbTile = (figures.get("_slot_tiles") as Dictionary)[slot]
		if not tile.part_id.is_empty():
			slots.append(tile)
		words.append((figures.get("_slot_words") as Dictionary)[slot])
	var both: Array[ThumbTile] = _joined(sight, slots)
	var sizes: Dictionary = _sizes(both)
	var places: Array[Vector2] = []
	for label: Control in words:
		places.append(label.global_position)
	_check("the grid opens with %d tiles in sight, all waiting and named (%s...)"
			% [sight.size(), sight[0].caption if not sight.is_empty() else "-"],
		sight.size() >= 6 and sight.all(func(tile: ThumbTile) -> bool:
			return tile.state == ThumbTile.State.LOADING and not tile.caption.is_empty()))
	_check("and the %d slots with a part are waiting too" % slots.size(),
		slots.size() >= 4 and slots.all(func(tile: ThumbTile) -> bool:
			return tile.state == ThumbTile.State.LOADING))
	await _shot_of(figures, "desktop_minifig_loading")

	_thumbs.set_process(true)
	var took: int = await _until_drawn(both, 900)
	var drawn: int = both.filter(func(tile: ThumbTile) -> bool:
		return tile.state == ThumbTile.State.READY and tile.texture != null).size()
	_check("every one became its picture (%d of %d, %d frames)"
		% [drawn, both.size(), took], drawn == both.size())
	var moved: Array[String] = _moved(sizes)
	_check("with nothing changing size%s"
		% ("" if moved.is_empty() else ": " + ", ".join(moved)), moved.is_empty())
	var shifted: int = 0
	for n: int in words.size():
		if not words[n].global_position.is_equal_approx(places[n]):
			shifted += 1
	_check("and no slot's words moved when its picture landed (%d did)" % shifted, shifted == 0)
	await _frames(30)
	await _shot_of(figures, "desktop_minifig_loaded")
	figures.close()


# -- helpers -------------------------------------------------------------------


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## Every picture forgotten, so the next grid has to wait for all of them.
func _forget_pictures() -> void:
	(_thumbs.get("_cache") as Dictionary).clear()
	(_thumbs.get("_order") as Array).clear()
	(_thumbs.get("_queued") as Dictionary).clear()
	(_thumbs.get("_queue") as Array).clear()
	(_thumbs.get("_failed") as Dictionary).clear()


func _tiles_of(grid: GridContainer) -> Array[ThumbTile]:
	var out: Array[ThumbTile] = []
	for cell: Node in grid.get_children():
		var tile: Variant = cell.get_meta("tile", null)
		if tile is ThumbTile:
			out.append(tile)
	return out


## The tiles whose middle is inside what the scroll shows.
func _seen(scroll: ScrollContainer, tiles: Array[ThumbTile]) -> Array[ThumbTile]:
	var view: Rect2 = scroll.get_global_rect()
	var out: Array[ThumbTile] = []
	for tile: ThumbTile in tiles:
		if view.has_point(tile.get_global_rect().get_center()):
			out.append(tile)
	return out


func _joined(a: Array[ThumbTile], b: Array[ThumbTile]) -> Array[ThumbTile]:
	var out: Array[ThumbTile] = []
	out.append_array(a)
	out.append_array(b)
	return out


## Each tile's size and its cell's, to compare after.
func _sizes(tiles: Array[ThumbTile]) -> Dictionary:
	var out: Dictionary = {}
	for tile: ThumbTile in tiles:
		out[tile] = [tile.size, (tile.get_parent() as Control).size,
			_cell_of(tile).size]
	return out


func _cell_of(tile: ThumbTile) -> Control:
	var at: Node = tile
	while at != null and not (at is Button):
		at = at.get_parent()
	return at if at != null else tile


func _moved(before: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for tile: ThumbTile in before:
		var now: Array = [tile.size, (tile.get_parent() as Control).size, _cell_of(tile).size]
		if now != before[tile]:
			out.append("%s %s -> %s" % [tile.part_id, str(before[tile][0]), str(now[0])])
	return out


func _until_drawn(tiles: Array[ThumbTile], most: int) -> int:
	for frame: int in most:
		if tiles.all(func(tile: ThumbTile) -> bool:
				return tile.state != ThumbTile.State.LOADING):
			return frame
		await process_frame
	return most


func _fake_part(id: String, name: String) -> PartLibrary.PartInfo:
	var info := PartLibrary.PartInfo.new()
	info.id = id
	info.name = name
	info.category = "Brick"
	info.mesh_hash = "probe-%s" % id
	info.size = Vector3(40, 24, 20)
	info.bounds = AABB(Vector3(-20, -24, -10), info.size)
	return info


## A picture of one panel, cut out of the window.
func _shot_of(panel: Control, name: String) -> void:
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	var scale: Vector2 = Vector2(shot.get_size()) / root.get_visible_rect().size
	var area: Rect2 = panel.get_global_rect()
	var crop := Rect2i(Vector2i(area.position * scale), Vector2i(area.size * scale))
	crop = crop.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	if not crop.has_area():
		print("    no picture: %s is not on screen" % name)
		return
	var path: String = ProjectSettings.globalize_path("res://shots/placeholders/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	shot.get_region(crop).save_png(path)
	print("    picture: shots/placeholders/%s.png" % name)


func _put_back_autosave() -> void:
	if _had_autosave:
		var file: FileAccess = FileAccess.open(ModelStore.AUTOSAVE, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_autosave)
			file.close()
	elif FileAccess.file_exists(ModelStore.AUTOSAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ModelStore.AUTOSAVE))
