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


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 180:
		await process_frame
		RenderingServer.force_draw(false)

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
		var wanted: Color = library.color(code).rgb
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
		RenderingServer.force_draw(false)
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

	print("")
	print("%d failed" % _failures if _failures
		else "every preview follows the palette")
	quit(1 if _failures else 0)


## Choose a colour, wait for the grid, and average what was drawn.
func _preview_colour(bin: PartsBin, part_id: String, code: int) -> Color:
	bin._on_colour(code)
	for _n: int in 90:
		await process_frame
		RenderingServer.force_draw(false)

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
