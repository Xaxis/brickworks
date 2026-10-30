## A set's bin draws no slower than the whole library's (docs/APP_UX.md B10).
##
##   godot --path . --resolution 1280x720 --script src/dev/setbin_time_probe.gd
##
## The biggest sets there are: 75419-1 Death Star (9,188 pieces, 1,173 kinds
## by part and colour), bigbox-1 (10,253 pieces, 1,779 kinds, the most kinds
## of any) and 5008796-1 (17,085 pieces, the most pieces). For the whole
## library and for each set's bin, timed in one run on one machine:
##   fill    the bin listed afresh, up to its next frame drawn (median of 7);
##   scroll  a frame of the grid scrolled 30 px a frame for 90 frames, its
##           pictures coming in (median and p95);
## and the counts worked out again (PartsBin._recount) over a model of 3,000
## parts, which a set's bin does once a model change (at most every
## RECOUNT_MSEC while a part is dragged).
## Fails where a set's fill or median scroll frame is slower than the whole
## library's by more than the noise between two runs of the library itself.
extends SceneTree

const SETS: Array[String] = ["75419-1", "bigbox-1", "5008796-1"]

var _failures: int = 0
var _bin: PartsBin


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


static func _median(values: Array) -> float:
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2]) if not sorted.is_empty() else 0.0


static func _p95(values: Array) -> float:
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))]) if not sorted.is_empty() else 0.0


## The bin listed afresh up to its next frame drawn, in ms, 7 times.
func _fill() -> float:
	var times: Array = []
	for _n: int in 7:
		await process_frame
		var began: int = Time.get_ticks_usec()
		_bin.call("_run_search", "")
		await RenderingServer.frame_post_draw
		times.append((Time.get_ticks_usec() - began) / 1000.0)
	return _median(times)


## Frames of the grid scrolled down, 30 px a frame: [median, p95] in ms.
func _scroll() -> Array:
	var scroll: ScrollContainer = _bin.get("_scroll")
	scroll.scroll_vertical = 0
	for _n: int in 10:
		await process_frame
	var times: Array = []
	var last: int = Time.get_ticks_usec()
	for _n: int in 90:
		scroll.scroll_vertical += 30
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	return [_median(times), _p95(times)]


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 1200:
		await process_frame
		var bin: PartsBin = main.get("_bin")
		if bin != null and int(bin.get("_offerable")) > 0:
			break
	for _n: int in 30:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	_bin = main.get("_bin")
	var dock: Variant = main.get("_bin_dock")
	if dock != null and not dock.is_open():
		dock.set_open(true)
	var world: BrickWorld = main.get("_world")

	# The library twice, so the noise between two runs of one bin is known.
	var library_fill: Array = [await _fill(), 0.0]
	var library_scroll: Array = await _scroll()
	library_fill[1] = await _fill()
	var again: Array = await _scroll()
	var fill_noise: float = absf(float(library_fill[1]) - float(library_fill[0]))
	var frame_noise: float = absf(float(again[0]) - float(library_scroll[0]))
	var fill_whole: float = maxf(float(library_fill[0]), float(library_fill[1]))
	var frame_whole: float = maxf(float(library_scroll[0]), float(again[0]))
	print("the whole library: fill %.1f / %.1f ms, scroll frame median %.1f / %.1f ms, p95 %.1f / %.1f ms"
		% [library_fill[0], library_fill[1], library_scroll[0], again[0], library_scroll[1], again[1]])

	for number: String in SETS:
		var kinds: int = await _bin.build_from(PackedStringArray([number]))
		if kinds == 0:
			_check("%s is in the inventories" % number, false)
			continue
		var set_bin: SetBin = _bin.set_bin()
		var fill: float = await _fill()
		var frames: Array = await _scroll()
		print("%s (%s pieces, %d kinds shown): fill %.1f ms, scroll frame median %.1f ms, p95 %.1f ms"
			% [set_bin.title, PartsBin._comma(set_bin.pieces), kinds, fill, frames[0], frames[1]])
		_check("%s's bin fills no slower than the library's (%.1f against %.1f ms, noise %.1f)"
			% [number, fill, fill_whole, fill_noise], fill <= fill_whole + maxf(fill_noise, 1.0))
		_check("...and scrolls no slower (median frame %.1f against %.1f ms, noise %.1f)"
			% [frames[0], frame_whole, frame_noise], float(frames[0]) <= frame_whole + maxf(frame_noise, 1.0))

	# The counts over a model of 3,000 parts, as a model change has them.
	var parts: Array[String] = ["3001", "3020", "3023", "3069b", "3004", "3710"]
	for n: int in 3000:
		world.add_brick(parts[n % parts.size()], [4, 1, 14, 71, 72, 0][n % 6],
			Transform3D(Basis.IDENTITY, Vector3(20.0 * (n % 60), 24.0 * (n / 3600), 20.0 * ((n / 60) % 60))))
	var recounts: Array = []
	for _n: int in 11:
		var began: int = Time.get_ticks_usec()
		_bin.call("_recount")
		recounts.append((Time.get_ticks_usec() - began) / 1000.0)
		await process_frame
	print("the counts over %d parts worked out again: median %.2f ms, most %.2f ms"
		% [world.brick_count(), _median(recounts), _p95(recounts)])
	var lib: PartLibrary = main.get("_library")
	var builder: Builder = main.get("_builder")
	var began: int = Time.get_ticks_usec()
	var used: Dictionary = SetBin.used_in(world, builder.scenery, lib)
	var counted: int = Time.get_ticks_usec()
	_bin.set_bin().tally(used, lib)
	var tallied: int = Time.get_ticks_usec()
	print("  of which: the model's parts counted %.2f ms, the set's line summed %.2f ms, %d tiles made"
		% [(counted - began) / 1000.0, (tallied - counted) / 1000.0,
			(_bin.get("_grid") as GridContainer).get_child_count()])
	_check("the counts over 3,000 parts take under a frame's 16 ms (%.2f)" % _median(recounts),
		_median(recounts) < 16.0)

	if _failures == 0:
		print("setbin time probe: a set's bin draws no slower than the whole library's")
	else:
		print("setbin time probe: %d failed" % _failures)
	quit(1 if _failures else 0)
