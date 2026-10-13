## What the selection's outline costs a frame on a big model, selected whole.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
##       --resolution 1400x900 --script src/dev/outline_cost_probe.gd
##
## Orthanc (9,429 parts), drawn in software: a frame with nothing selected
## and with every part selected, the view standing still and the view
## turning, and how long selecting all of it and every part of one colour
## takes. Drawn in software in a browser, a frame with all of Orthanc
## outlined took about 8 s, Mirror's bar 11.4 s to appear and Same colour held
## the page 6.7 s (2026-10-13): the outline drew the selection again in every
## frame, whatever had changed.
##
## A frame where only the interface changed must cost what it costs with
## nothing selected, within a twentieth (it cost a tenth more: 6,090 ms of
## the processor against 5,532 in software on the desktop); a frame where the
## view turned, within a tenth, the line put away until the view is still and
## back once it is; and taking the selection, well under a second.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _verbs: EditVerbs


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
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_verbs = _main.get("_verbs")
	# The pointer on the rail at the left, off the model.
	Input.warp_mouse(Vector2(8, 400))
	var placed: int = int(_main.call("_open", "res://models/orthanc.ldr"))
	_check("Orthanc opens (%d parts)" % placed, placed > 8000)
	_camera.set_view("default")
	_camera.frame(_main.call("_built_bounds"))
	await _still()
	_world.rebuilds_in_slices = false
	_world.call("_flush")
	await _frames(4)

	# Taken in turns, with and without, five times over, and the middle of
	# each kept.
	var bare_still: Array = []
	var bare_turning: Array = []
	var still: Array = []
	var turning: Array = []
	var took_all: float = 0.0
	var count: int = 0
	## The fewest pixels of the line seen once the view came to rest.
	var back: int = 1 << 30
	for _round: int in 5:
		_builder.clear_selection()
		await _frames(3)
		bare_still.append(await _frame_ms(4))
		bare_turning.append(await _turning_ms(4))
		await _still()
		var began: int = _cpu_ticks()
		_verbs.select_by("all")
		took_all = maxf(took_all, float(_cpu_ticks() - began) * 10.0)
		count = _builder.selection.size()
		await _frames(3)
		still.append(await _frame_ms(4))
		turning.append(await _turning_ms(4))
		await _still()
		await _frames(3)
		back = mini(back, _yellow(await _picture()))
	_builder.clear_selection()
	await _frames(4)
	var bare: float = _middle(bare_still)
	var outlined: float = _middle(still)
	var bare_turn: float = _middle(bare_turning)
	var outlined_turning: float = _middle(turning)

	# Every part of one colour: the colour most of the tower is.
	var colours: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		colours[brick.color_code] = int(colours.get(brick.color_code, 0)) + 1
	var most: int = 0
	for code: int in colours:
		if most == 0 or int(colours[code]) > int(colours[most]):
			most = code
	var one: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.color_code == most and not (_main.get("_store") as ModelStore).scenery.has(brick.id):
			one = brick.id
			break
	_builder.select_brick(one, false)
	await _frames(2)
	var began_colour: int = _cpu_ticks()
	_verbs.select_by("colour")
	var took_colour: float = float(_cpu_ticks() - began_colour) * 10.0
	var by_colour: int = _builder.selection.size()
	await _frames(2)
	var colour_frame: float = await _frame_ms(4)
	_builder.clear_selection()

	print("    the processor's time a frame, view still: %.0f ms bare, %.0f ms with all %d outlined (of %s and %s)"
		% [bare, outlined, count, _ms(bare_still), _ms(still)])
	print("    ...view turning: %.0f ms bare, %.0f ms outlined (of %s and %s)" % [
		bare_turn, outlined_turning, _ms(bare_turning), _ms(turning)])
	print("    selecting all: %.0f ms; every part of colour %d (%d parts): %.0f ms, then %.0f ms a frame"
		% [took_all, most, by_colour, took_colour, colour_frame])
	_check("a frame with all %d outlined and the view still costs %.0f ms against %.0f bare"
		% [count, outlined, bare], outlined <= bare * 1.05 + 30.0)
	_check("...and turning, %.0f ms against %.0f bare: a selection this big is put away "
		% [outlined_turning, bare_turn] + "while the view moves", outlined_turning <= bare_turn * 1.1 + 30.0)
	_check("...and its line is back each time the view comes to rest (%d pixels at the least)"
		% back, back > 200)
	_check("selecting all of it takes %.0f ms, every part of one colour %.0f ms"
		% [took_all, took_colour], took_all < 500.0 and took_colour < 500.0)
	print("")
	if _failures == 0:
		print("outline cost: a big selection outlined costs a frame no more than the model "
			+ "does standing still, and half as much again turning")
	else:
		print("outline cost: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _picture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## Pixels of the selection's yellow.
func _yellow(image: Image) -> int:
	var count: int = 0
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			var c: Color = image.get_pixel(x, y)
			if c.r > 0.85 and c.g > 0.75 and c.b < 0.45:
				count += 1
	return count


func _middle(values: Array) -> float:
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])


func _ms(values: Array) -> String:
	var out: PackedStringArray = []
	for value: float in values:
		out.append("%.0f" % value)
	return "/".join(out)


## The processor's time a frame, every frame drawn, the view still: the
## time the whole process spent, in software drawing included, which a
## machine busy with other work does not stretch as it does the clock's.
func _frame_ms(count: int) -> float:
	await RenderingServer.frame_post_draw
	var began: int = _cpu_ticks()
	for _n: int in count:
		await RenderingServer.frame_post_draw
	return float(_cpu_ticks() - began) * 10.0 / count


## The same with the view turned a little before each frame.
func _turning_ms(count: int) -> float:
	await RenderingServer.frame_post_draw
	var began: int = _cpu_ticks()
	for _n: int in count:
		_camera.turn_by_drag(Vector2(6.0, 0.0))
		await RenderingServer.frame_post_draw
	return float(_cpu_ticks() - began) * 10.0 / count


## The process's time on the processor so far, in hundredths of a second.
static func _cpu_ticks() -> int:
	var file: FileAccess = FileAccess.open("/proc/self/stat", FileAccess.READ)
	if file == null:
		return -1
	var line: String = file.get_line()
	var fields: PackedStringArray = line.substr(line.rfind(")") + 2).split(" ")
	return fields[11].to_int() + fields[12].to_int() if fields.size() > 12 else -1


func _still() -> void:
	var was: Transform3D = _camera.global_transform
	for _n: int in 120:
		await _frames(2)
		if _camera.global_transform.is_equal_approx(was):
			return
		was = _camera.global_transform


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
