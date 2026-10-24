## How long a big set takes to open in the real window, drawn on the GPU:
## when its first picture is on the screen and when it is fully open.
##
##   godot --path . --resolution 1280x860 --script src/dev/open_time_probe.gd
##   godot --path . --resolution 1280x860 --script src/dev/open_time_probe.gd -- --model=res://vendor/omr/files/10297-1.mpd
##
## A measure, nothing held (tools/suite/out.txt): walk180 (A8) opened the
## Boutique Hotel, 10297-1's 3,164 parts, from the library. Here its file is
## opened as the library opens one (ModelBar.open_text_with_progress, then
## the bar's opened), from an empty baseplate, and every frame's drawn
## primitives are read (RenderingServer): the first picture is the first
## frame that draws 90% of what the frame drawing it whole draws, and fully
## open is when the open has ended, the model is weighed (the status bar's
## line) and a second of frames is drawn alike. Both from the open's start,
## in ms. Copied into another build's checkout, it times that build alike.
extends SceneTree

var _drawn: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var path: String = "res://vendor/omr/files/10297-1.mpd"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			path = arg.trim_prefix("--model=")
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 240:
		await process_frame
	var bar: ModelBar = main.get("_bar")
	var store: ModelStore = main.get("_store")
	await bar._start_new()
	for _n: int in 60:
		await process_frame
	var text: String = FileAccess.get_file_as_string(path)
	var name: String = ModelStore.title_in(text, path.get_file())
	print("opening %s (%d parts) in the window" % [name, ModelStore.count_in(text)])

	var began: int = Time.get_ticks_msec()
	var watching: Array = [true]
	var count := func() -> void:
		while watching[0]:
			await RenderingServer.frame_post_draw
			_drawn.append([Time.get_ticks_msec() - began, RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	count.call()
	var result: Dictionary = await bar.open_text_with_progress(text, name)
	bar.opened.emit(int(result["placed"]))
	var opened: int = Time.get_ticks_msec() - began
	# Weighed, and a second of frames drawn alike.
	var weighed: int = -1
	var settled: int = -1
	while Time.get_ticks_msec() - began < 120000:
		await process_frame
		var said: String = str(main.get("_stability_text"))
		if weighed < 0 and not said.is_empty():
			weighed = Time.get_ticks_msec() - began
		if weighed >= 0 and _alike_for(1000):
			settled = Time.get_ticks_msec() - began
			break
	watching[0] = false
	var whole: int = int(_drawn[_drawn.size() - 1][1]) if not _drawn.is_empty() else 0
	var first: int = -1
	for frame: Array in _drawn:
		if int(frame[1]) >= whole * 0.9:
			first = int(frame[0])
			break
	print("  %d parts down, %s" % [store.world.brick_count() - store.scenery.size(), result.get("error", "")])
	print("  the frame drawing it whole: %d primitives" % whole)
	print("  first picture %d ms, the open ended %d ms, weighed %d ms, fully open %d ms (from the open's start)"
		% [first, opened, weighed, settled])
	print("  phases %s" % JSON.stringify(store.open_phases))
	quit(0 if first >= 0 and settled >= 0 else 1)


## Whether the frames of the last [param ms] all drew what the last did.
func _alike_for(ms: int) -> bool:
	if _drawn.size() < 2:
		return false
	var last: Array = _drawn[_drawn.size() - 1]
	if int(last[0]) - int(_drawn[0][0]) < ms:
		return false
	for n: int in range(_drawn.size() - 1, -1, -1):
		if int(last[0]) - int(_drawn[n][0]) > ms:
			return true
		if int(_drawn[n][1]) != int(last[1]):
			return false
	return true
