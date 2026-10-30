## Does every tile in the parts bin say which part it is, before and after
## its picture comes?
##
##   godot --path . --resolution 1280x720 --script src/dev/bin_names_probe.gd
##
## A tile was a picture and a number: 3023b, 3004, 3022. A person new to
## LDraw's numbers hovered each to learn that 3710 is a plate 1 x 4, and on
## the web, opening the castle, the tiles were grey squares eight seconds in
## with only the number to go by (appux371 A4, 2026-10-30). This opens the
## app as a person does, the bin out, with the pictures held back as a slow
## network holds them, and asks of every tile in sight:
##
## * its name is under it in words, the part's (PartsBin.tile_name), in at
##   most two lines that fit the tile, and not its number;
## * no two tiles in sight read the same;
## * while its picture is coming, the part is drawn in its place from what
##   the catalogue says of it (PartSketch): read off the window's pixels, a
##   shape in the colour in hand, where a plain placeholder was a faint
##   square nobody could tell from its neighbour (it fails on that one);
## * and when the pictures land, the names and the tiles stay where they were;
## * and typed "slope 45 2x2", whose parts' names begin alike, the same of
##   each tile in sight: a name cut short goes on from where it parts from
##   its neighbour's, or ends in its number, so no two read the same.
##
## Also at 1400 x 900 (PROBE_SIZE=1400x900). Pictures of the bin waiting and
## drawn go to shots/bin_names/.
extends SceneTree

## How much of a tile's square the stand-in must cover in the colour in hand:
## pixels moved from the tile's own background towards that colour, by this
## much at least (0 to 1) and more towards it than any other way. The
## shimmer crossing a plain placeholder lifts it towards white, not red.
const DRAWN_SHARE := 0.12
const TOWARDS := 0.08
## Words that turn up parts whose names begin alike.
const ALIKE := "slope 45 2x2"

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
	_had_autosave = FileAccess.file_exists(ModelStore.autosave())
	if _had_autosave:
		_autosave = FileAccess.get_file_as_bytes(ModelStore.autosave())
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(180)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	# The bin out: a window under the design width shows the assistant with
	# the bin folded to its rail.
	(_main.get("_bin_dock") as SideDock).set_open(true)
	await create_timer(SideDock.SLIDE_SECONDS * 2.0).timeout
	await _frames(30)
	_thumbs = _main.get("_thumbnails")
	var bin: PartsBin = _main.get("_bin")
	var library: PartLibrary = _main.get("_library")
	var size: Vector2i = DisplayServer.window_get_size()
	print("  the parts bin in a %d x %d window" % [size.x, size.y])

	# Waiting: every picture forgotten and none drawn, as on a slow network.
	_forget_pictures()
	_thumbs.set_process(false)
	bin._run_search("")
	await _frames(8)
	var sight: Array[ThumbTile] = _seen(bin.get("_scroll"), _tiles_of(bin.get("_grid")))
	_check("%d tiles in sight, every one waiting for its picture" % sight.size(),
		sight.size() >= 8 and sight.all(func(tile: ThumbTile) -> bool:
			return tile.state == ThumbTile.State.LOADING))
	var names: Dictionary = _names(sight, library)
	await _stand_ins(sight)
	await _shot("waiting_%dx%d" % [size.x, size.y])
	var places: Array = sight.map(func(tile: ThumbTile) -> Rect2: return tile.get_global_rect())

	# The pictures land.
	_thumbs.set_process(true)
	for _n: int in 900:
		if sight.all(func(tile: ThumbTile) -> bool: return tile.state != ThumbTile.State.LOADING):
			break
		await process_frame
	await _frames(20)
	var drawn: int = sight.filter(func(tile: ThumbTile) -> bool:
		return tile.state == ThumbTile.State.READY and tile.texture != null).size()
	var after: Dictionary = {}
	for tile: ThumbTile in sight:
		after[tile.part_id] = _label_of(tile).text
	var moved: int = 0
	for n: int in sight.size():
		if not sight[n].get_global_rect().is_equal_approx(places[n]):
			moved += 1
	_check("then %d of %d became their pictures, with the same names (%s) and none moved (%d)"
		% [drawn, sight.size(), "same" if after == names else "changed", moved],
		drawn == sight.size() and after == names and moved == 0)
	await _shot("drawn_%dx%d" % [size.x, size.y])

	# A search for parts alike: seven inverted slopes once read "Slope 45
	# 2×2 Inverted wit…" side by side. Their pictures held back again.
	print("")
	print("  \"%s\" typed, the pictures held back" % ALIKE)
	_forget_pictures()
	_thumbs.set_process(false)
	bin._run_search(ALIKE)
	await _frames(8)
	var alike: Array[ThumbTile] = _seen(bin.get("_scroll"), _tiles_of(bin.get("_grid")))
	_check("%d tiles in sight, waiting for their pictures" % alike.size(), alike.size() >= 8)
	_names(alike, library)
	await _stand_ins(alike)
	await _shot("alike_%dx%d" % [size.x, size.y])
	_thumbs.set_process(true)

	_put_back_autosave()
	print("")
	print("bin names probe: every tile says its part, and stands in for its picture while it waits"
		if _failures == 0 else "bin names probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


## Each tile's name: its part's in words, in the lines that fit, and no two
## alike. Returns part -> what its tile reads.
func _names(sight: Array[ThumbTile], library: PartLibrary) -> Dictionary:
	var read: Dictionary = {}
	var named: int = 0
	var fits: int = 0
	var shown := PackedStringArray()
	for tile: ThumbTile in sight:
		var label: Label = _label_of(tile)
		var text: String = label.text if label != null else ""
		read[tile.part_id] = text
		shown.append(text.replace("\n", " / "))
		var name: String = PartsBin.tile_name(library.parts[tile.part_id])
		# Two names still alike when cut end in their numbers.
		var flat: String = text.replace("\n", " ").trim_suffix(" " + tile.part_id)
		var whole: bool = flat == name or (flat.contains("…") and _reads_from(flat, name))
		var words: bool = RegEx.create_from_string("[A-Za-z]{3}").search(flat) != null
		if whole and words and flat != tile.part_id:
			named += 1
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		var lines: PackedStringArray = text.split("\n")
		var widest: float = 0.0
		for line: String in lines:
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1,
				font_size).x)
		if lines.size() <= PartsBin.NAME_LINES and widest <= label.size.x + 0.5 \
				and label.get_global_rect().intersects(_cell_of(tile).get_global_rect()):
			fits += 1
	print("    they read: %s" % " | ".join(shown))
	_check("each names its part in words, not its number (%d of %d)" % [named, sight.size()],
		named == sight.size())
	_check("each name fits its tile, in two lines at most (%d of %d)" % [fits, sight.size()],
		fits == sight.size())
	var seen: Dictionary = {}
	for text: String in read.values():
		seen[text] = true
	_check("no two tiles in sight read the same (%d names for %d tiles)" % [seen.size(),
		sight.size()], seen.size() == sight.size())
	return read


## While waiting, each tile draws its part from the catalogue: read off the
## window, a shape in its square, not a faint square.
func _stand_ins(sight: Array[ThumbTile]) -> void:
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	var scale: Vector2 = Vector2(shot.get_size()) / root.get_visible_rect().size
	var drawn: int = 0
	var least: float = 1.0
	for tile: ThumbTile in sight:
		var side: float = minf(tile.size.x, tile.size.y)
		var square := Rect2(tile.global_position + (tile.size - Vector2(side, side)) * 0.5,
			Vector2(side, side))
		var area := Rect2i(Vector2i(square.position * scale), Vector2i(square.size * scale))
		area = area.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
		if not area.has_area():
			continue
		# The square's foot, clear of the fold's count at the top left.
		var ground: Color = shot.get_pixel(area.position.x + 1, area.end.y - 2)
		var towards := Vector3(tile.sketch_colour.r - ground.r, tile.sketch_colour.g - ground.g,
			tile.sketch_colour.b - ground.b).normalized()
		var coloured: int = 0
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				var pixel: Color = shot.get_pixel(x, y)
				var moved := Vector3(pixel.r - ground.r, pixel.g - ground.g, pixel.b - ground.b)
				var along: float = moved.dot(towards)
				if along > TOWARDS and (moved - towards * along).length() < along:
					coloured += 1
		var share: float = float(coloured) / float(area.size.x * area.size.y)
		least = minf(least, share)
		if tile.sketch != null and share >= DRAWN_SHARE:
			drawn += 1
	_check("each waiting tile draws its part in its place (%d of %d; the least covers %d%% of its square)"
		% [drawn, sight.size(), roundi(least * 100.0)], drawn == sight.size())


## Whether [param shown] is pieces of [param name] in order, with "…" where
## words are left out: its start, then where it parts from a tile beside it.
func _reads_from(shown: String, name: String) -> bool:
	var at: int = 0
	var pieces: PackedStringArray = shown.split("…")
	for n: int in pieces.size():
		var piece: String = pieces[n].strip_edges()
		if piece.is_empty():
			continue
		var found: int = name.find(piece, at)
		if found < 0 or (n == 0 and found != 0):
			return false
		at = found + piece.length()
	return true


func _label_of(tile: ThumbTile) -> Label:
	for node: Node in _cell_of(tile).find_children("*", "Label", true, false):
		return node
	return null


func _cell_of(tile: ThumbTile) -> Control:
	var at: Node = tile
	while at != null and not (at is Button and at.has_meta("part")):
		at = at.get_parent()
	return at if at != null else tile


func _forget_pictures() -> void:
	(_thumbs.get("_cache") as Dictionary).clear()
	(_thumbs.get("_order") as Array).clear()
	(_thumbs.get("_queued") as Dictionary).clear()
	(_thumbs.get("_queue") as Array).clear()
	(_thumbs.get("_failed") as Dictionary).clear()


func _tiles_of(grid: GridContainer) -> Array[ThumbTile]:
	var out: Array[ThumbTile] = []
	for cell: Node in grid.get_children():
		var tile: Variant = cell.get_meta("tile") if cell.has_meta("tile") else null
		if tile is ThumbTile:
			out.append(tile)
	return out


## The tiles wholly inside what the scroll shows.
func _seen(scroll: ScrollContainer, tiles: Array[ThumbTile]) -> Array[ThumbTile]:
	var view: Rect2 = scroll.get_global_rect().grow(0.5)
	var out: Array[ThumbTile] = []
	for tile: ThumbTile in tiles:
		if view.encloses(_cell_of(tile).get_global_rect()):
			out.append(tile)
	return out


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://shots/bin_names/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


func _put_back_autosave() -> void:
	if _had_autosave:
		var file: FileAccess = FileAccess.open(ModelStore.autosave(), FileAccess.WRITE)
		if file != null:
			file.store_buffer(_autosave)
			file.close()
	elif FileAccess.file_exists(ModelStore.autosave()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ModelStore.autosave()))
