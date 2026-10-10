## Does picking a colour actually recolour anything?
##
##   godot --path . --script src/dev/colour_probe.gd
##
## Not headless: the previews are rendered by a SubViewport, and a
## viewport with no rendering device produces nothing to measure.
##
## The question is asked of pixels rather than of the code, because
## every way this breaks leaves the code looking right. A preview cached
## under the wrong key, a tint the shader ignores, a grid that is not
## redrawn — each of those is a brick that stays red while the palette
## says blue, and none of them is visible in a variable.
##
## Fixed-colour parts are checked too, and checked for *not* changing.
## Not a printed head — a head's print is fixed but the shell under it
## is not, so a head correctly comes in any colour. A sticker is the
## real case: every surface of one is moulded.
extends SceneTree

var _failures: int = 0
var _main: Node


func _initialize() -> void:
	_run()


## Waiting, not forcing.
##
## This used to call RenderingServer.force_draw in each of its waits, for
## the reason main.gd still does in the two places that capture a
## picture: a process frame is not a drawn frame, and an unattended
## window stops being asked to redraw. Here it was only hurrying things
## along — and forcing a draw from inside a frame re-enters the renderer,
## which on a busy machine deadlocks. The probe then hung for ever, which
## stops the whole suite rather than failing it, and it printed nothing
## on the way because its output was still in a buffer.
##
## The previews arrive on their own. Waiting for them is enough.
func _run() -> void:
	await process_frame
	# Counted in frames, and a window nothing is looking at gets one a
	# second on this machine. Without this the probe is minutes of
	# waiting for a compositor.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 180:
		await process_frame

	var bin: PartsBin = _main.get("_bin")
	var builder: Builder = _main.get("_builder")
	var library: PartLibrary = _main.get("_library")

	# An ordinary brick, which follows whatever colour is chosen.
	for pair: Array in [[4, "Red"], [1, "Blue"], [14, "Yellow"], [0, "Black"]]:
		var code: int = pair[0]
		var seen: Color = await _preview_colour(bin, "3001", code)
		if seen.a < 0.01:
			_say("no preview drawn for 3001 in %s" % pair[1], false)
			continue
		# Judged against the colours under test, not against all 44.
		# The palette holds near-duplicates — Blue and Trans Dark Blue
		# are a hair apart — and a lit brick is brighter than its flat
		# swatch, so "nearest of everything" picked the transparent twin
		# and called a working preview a failure. What matters is that
		# the preview follows the choice, which this asks directly.
		var nearest: int = _nearest_of(seen, [4, 1, 14, 0], library)
		_say("the 3001 preview in %s reads as %s  (rgb %.2f %.2f %.2f)" % [
				pair[1], library.color(nearest).name, seen.r, seen.g, seen.b],
			nearest == code)

		# And the thing about to be placed has to agree with the palette.
		_say("...and the held colour follows, got %d" % builder.held_color,
			builder.held_color == code)

	# The ghost — the part about to be placed, in the viewport. It takes
	# its colour through a shader parameter rather than through the
	# palette the previews use, so it is a second thing that can be
	# right while the other is wrong.
	var world: BrickWorld = _main.get("_world")
	var target: BrickWorld.Brick = world.bricks()[0]
	for code: int in [4, 1, 14]:
		bin._on_colour(code)
		builder.update_preview(
			target.transform.origin + Vector3(0, 400, 0), Vector3.DOWN)
		await process_frame
		var material: ShaderMaterial = builder.get("_ghost_material")
		var tint: Color = material.get_shader_parameter("tint")
		var wanted: Color = library.color(code).shown
		_say("the ghost is tinted %s  (rgb %.2f %.2f %.2f)" % [
				library.color(code).name, tint.r, tint.g, tint.b],
			tint.is_equal_approx(wanted))

	# And a brick already placed must not repaint itself when the
	# palette changes. Choosing a colour is choosing what comes next.
	var placed_as: int = target.color_code
	bin._on_colour(1 if placed_as != 1 else 4)
	await process_frame
	_say("a placed brick keeps its own colour, %d -> %d"
		% [placed_as, target.color_code], target.color_code == placed_as)

	# A part moulded in a fixed colour must ignore the palette. Searched
	# for first, because it is not on the first page of the bin and a
	# cell that is not on screen has no preview to measure.
	#
	# A printed head is the wrong part for this and was the first thing
	# tried: the print is fixed but the shell underneath is not, so a
	# head comes in any colour and its preview follows the palette
	# correctly. The parts that genuinely cannot be recoloured are the
	# 649 stickers, every surface of which is moulded.
	bin._run_search("003432c")
	for _n: int in 40:
		await process_frame
	var yellow_first: Color = await _preview_colour(bin, "003432c", 4)
	var yellow_again: Color = await _preview_colour(bin, "003432c", 1)
	if yellow_first.a <= 0.01 or yellow_again.a <= 0.01:
		_say("a sticker could not be previewed at all", false)
	if yellow_first.a > 0.01 and yellow_again.a > 0.01:
		# Split over temporaries: GDScript will not take a line break
		# before a dot, so a wrapped method chain is a parse error.
		var was := Vector3(yellow_first.r, yellow_first.g, yellow_first.b)
		var now := Vector3(yellow_again.r, yellow_again.g, yellow_again.b)
		var moved: float = was.distance_to(now)
		_say("a sticker keeps the colours it is printed in (moved %.3f)"
			% moved, moved < 0.08)

	# Choosing a part has to look like choosing a part. The handler set
	# every cell unpressed including the one just pressed, so the only
	# sign anything had happened was the ghost in the viewport.
	bin._run_search("")
	for _n: int in 40:
		await process_frame
	bin._on_part("3001")
	await process_frame

	var lit := PackedStringArray()
	for child: Node in (bin.get("_grid") as Node).get_children():
		var button: Button = child
		if button.button_pressed:
			lit.append(str(button.get_meta("part", "?")))
	_say("choosing 3001 lights 3001 and nothing else, lit: %s"
		% ("none" if lit.is_empty() else ", ".join(lit)),
		lit.size() == 1 and lit[0] == "3001")

	print("")
	await _each_its_own(bin)

	print("")
	await _every_colour_can_be_chosen(bin, builder, library)

	print("")
	print("%d failed" % _failures if _failures
		else "every preview follows the palette, and shows its own part")
	quit(1 if _failures else 0)


## Choose a colour, wait for the grid, and average what was drawn.
## Is each cell a picture of its own part?
##
## The previews share one offscreen viewport, one camera and one mesh
## holder, and drawing is a coroutine that waits for a frame. Two of
## them started in the same frame both wrote to that one viewport and
## both woke on the same draw, so they read back the same image — the
## second job's — and the first cached it under its own key. Half the
## bin showed the wrong part, and which half changed with the scroll.
##
## Telling a picture of a 1x1 plate from a picture of a 2x4 brick is
## hard; noticing that they are the same picture is not.
func _each_its_own(bin: PartsBin) -> void:
	# Parts that look nothing like each other, so two of them coming
	# back identical cannot be a coincidence of framing. The first line
	# also documents what a comment cannot: that the fix is in the
	# thumbnailer rather than in how the bin asks for them.
	var want: Array[String] = ["3005", "3001", "3024", "3070b", "3811"]
	var seen: Dictionary = {}

	# Drawn fresh, all of them, starting now.
	#
	# Asking for previews that are already cached tests nothing: the
	# collision only happens between two that are being drawn at the
	# same moment, and by the time the bin has settled everything on
	# screen was drawn long ago, one at a time, correctly.
	var thumbs: PartThumbnails = bin.thumbnails
	(thumbs.get("_cache") as Dictionary).clear()
	(thumbs.get("_queued") as Dictionary).clear()
	(thumbs.get("_order") as Array).clear()
	for part_id: String in want:
		thumbs.request(part_id, 4)
	for _n: int in 240:
		await process_frame

	for part_id: String in want:
		var texture: Texture2D = bin.thumbnails.request(part_id, 4)
		if texture == null:
			print("  skip  %s has no preview yet" % part_id)
			continue
		var image: Image = texture.get_image()
		# A cheap fingerprint: a picture of a different part differs in
		# thousands of pixels, so a handful of samples settles it.
		var mark := PackedFloat32Array()
		var step: int = maxi(image.get_width() / 12, 1)
		for x: int in range(0, image.get_width(), step):
			for y: int in range(0, image.get_height(), step):
				var pixel: Color = image.get_pixel(x, y)
				mark.append(pixel.a)
				mark.append(pixel.get_luminance())
		var key: String = str(mark)
		if seen.has(key):
			_say("%s and %s are different pictures"
				% [part_id, seen[key]], false)
		else:
			seen[key] = part_id
	if seen.size() >= 3:
		_say("%d parts, %d different pictures" % [want.size(), seen.size()],
			seen.size() == want.size())


## Can every colour be had by hand?
##
## The palette was a fixed row of 44: five of them retired, and Medium
## Azure, Dark Orange, Coral and the rest of what sets use today
## missing, so 278 colours could only be had from a model that already
## used them. Asked of the palette the person sees, by pressing it.
func _every_colour_can_be_chosen(bin: PartsBin, builder: Builder,
		library: PartLibrary) -> void:
	var toggle: Button = bin.get("_all_colours")
	if toggle.button_pressed:
		toggle.button_pressed = false
	await process_frame
	var short: Dictionary = bin.get("_swatches")
	var wanted: Array[int] = [322, 484, 78, 29, 321, 57, 31, 330, 353, 315]
	var missing := PackedInt32Array()
	for code: int in wanted:
		if not short.has(code):
			missing.append(code)
	_say("the short palette has %d colours, among them Medium Azure, Dark Orange, Coral%s"
			% [short.size(), "" if missing.is_empty() else " — missing %s" % str(missing)],
		missing.is_empty())
	_say("...and not Light Grey, which LEGO stopped making in 2004",
		not short.has(7) or not library.is_current(7))

	toggle.button_pressed = true
	await process_frame
	var everything: Dictionary = bin.get("_swatches")
	var unreachable := PackedInt32Array()
	for code: int in library.colors:
		if not everything.has(code) and not code in PartsBin.NOT_A_COLOUR:
			unreachable.append(code)
	_say("all of them: %d of %d colours can be pressed, %d cannot" % [
			everything.size(), library.colors.size(), unreachable.size()],
		unreachable.is_empty())

	# Pressing one is choosing it, chrome as much as plain plastic.
	for code: int in [484, 383, 117, 20004]:
		var swatch: Button = (bin.get("_swatches") as Dictionary).get(code)
		if swatch == null:
			_say("no swatch for %d" % code, false)
			continue
		swatch.emit_signal("pressed")
		await process_frame
		_say("pressing %s holds it, held %d" % [library.color(code).name, builder.held_color],
			builder.held_color == code)

	# The eyedropper on a colour the short palette hides opens the long
	# one with it lit, or the palette would show nothing chosen.
	toggle.button_pressed = false
	await process_frame
	bin.show_held("3001", 7)
	await process_frame
	var lit: Button = (bin.get("_swatches") as Dictionary).get(7)
	_say("picking up a Light Grey brick shows Light Grey chosen",
		lit != null and lit.button_pressed and toggle.button_pressed)

	# Which colours the held part comes in, marked.
	bin.show_held("3001", 4)
	await process_frame
	var shown: Dictionary = bin.get("_swatches")
	var marked: int = 0
	var expected: int = 0
	for code: int in shown:
		if int(shown[code].get("made_in")) > 0:
			marked += 1
	var info: PartLibrary.PartInfo = library.parts["3001"]
	for code: int in info.colors:
		if shown.has(code):
			expected += 1
	_say("3001's colours are marked on the palette: %d of the %d shown" % [
			marked, expected],
		expected > 0 and marked == expected)

	# A picture of the panel, to look at: the palette is the point.
	for _n: int in 10:
		await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	var area: Rect2 = (bin as Control).get_global_rect()
	var scale: Vector2 = Vector2(shot.get_size()) / root.get_visible_rect().size
	var crop := Rect2i(Vector2i(area.position * scale), Vector2i(area.size * scale))
	crop = crop.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	if crop.has_area():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
		shot.get_region(crop).save_png(ProjectSettings.globalize_path("res://shots/palette.png"))
		print("  wrote shots/palette.png")
	toggle.button_pressed = false


func _preview_colour(bin: PartsBin, part_id: String, code: int) -> Color:
	bin._on_colour(code)
	for _n: int in 90:
		await process_frame

	var cells: Dictionary = bin.get("_cells")
	var cell: TextureRect = cells.get(part_id)
	if cell == null or cell.texture == null:
		return Color(0, 0, 0, 0)

	var image: Image = cell.texture.get_image()
	var total := Vector3.ZERO
	var counted: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			# The previews are drawn on nothing, so anything opaque is
			# part. Near-black pixels are shadow rather than plastic and
			# would drag every average towards black.
			if pixel.a > 0.6 and pixel.get_luminance() > 0.06:
				total += Vector3(pixel.r, pixel.g, pixel.b)
				counted += 1
	if counted == 0:
		return Color(0, 0, 0, 0)
	total /= float(counted)
	return Color(total.x, total.y, total.z, 1.0)


## Which palette colour the drawn average is nearest, judged where
## distances mean something. Lighting shifts a rendered colour, so the
## test is which one it is closest to rather than whether it matches.
func _nearest_of(seen: Color, among: Array, library: PartLibrary) -> int:
	var best: int = -1
	var best_gap: float = INF
	var here: Vector3 = Mosaic._oklab(seen)
	for code: int in among:
		var gap: float = here.distance_squared_to(
			Mosaic._oklab(library.color(code).rgb))
		if gap < best_gap:
			best_gap = gap
			best = code
	return best


func _say(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
