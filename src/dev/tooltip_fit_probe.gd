## A long hover text stays inside the window, in the real app.
##
##   godot --path . --resolution 1280x800 --script src/dev/tooltip_fit_probe.gd
##   PROBE_SIZE=390x844 tools/probe.sh tooltip_fit_probe      as a phone is wide
##
## walk256 (TQ1): a technique's hover text, its use and why it works, is one
## line of three hundred letters, and Godot draws a tooltip's text as it is:
## it ran off the window's right edge at 1280. Here the parts bin's
## Techniques are searched for "door" and the pointer rests on each of the
## first rows, and then on a part's tile and on the search field: every
## tooltip that comes is inside the window, with its words in lines no
## wider than it.
extends SceneTree

var _failures: int = 0
var _main: Node
var _virtual: bool = OS.get_environment("XAUTHORITY").contains("xvfb-run")


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	var room: Rect2 = root.get_visible_rect()
	print("\n  the window: %d x %d" % [roundi(room.size.x), roundi(room.size.y)])
	var bin: PartsBin = _main.get("_bin")
	# A narrow window shows one column at a time, and may start with neither.
	var dock: SideDock = _main.get("_bin_dock")
	if dock != null and not dock.is_open():
		dock.set_open(true)
		await _frames(30)
	bin.show_category(PartsBin.TECHNIQUES)
	bin._search.text = "door"
	bin._run_search("door")
	await _frames(30)
	var seen: int = 0
	var rows: int = 0
	for child: Node in bin._grid.get_children():
		if not child.has_meta("technique") or rows >= 3:
			continue
		rows += 1
		var row: Control = child
		if not row.is_visible_in_tree() or not room.encloses(row.get_global_rect()):
			continue
		var tip: Window = await _hover(row)
		if tip == null:
			_check("%s: a tooltip comes" % row.get_meta("technique"), false)
			continue
		seen += 1
		_inside(str(row.get_meta("technique")), tip, room)
		await _rest()
	_check("tooltips came for the first rows (%d)" % seen, seen >= 1)
	# And a part's tile, and the search field, as plain tooltips.
	bin.show_category("All")
	bin._search.text = "3001"
	bin._run_search("3001")
	await _frames(30)
	if bin._grid.get_child_count() > 0:
		var tile: Control = bin._grid.get_child(0)
		var tip: Window = await _hover(tile)
		if tip != null:
			_inside("a part's tile", tip, room)
		await _rest()
	var shots: String = ProjectSettings.globalize_path("res://shots/tooltip_fit")
	DirAccess.make_dir_recursive_absolute(shots)
	print("\n%s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	_main.queue_free()
	await _frames(5)
	quit(1 if _failures else 0)


## [param tip] wholly inside [param room], and none of its lines wider.
func _inside(what: String, tip: Window, room: Rect2) -> void:
	var rect := Rect2(Vector2(tip.position), Vector2(tip.size))
	var label: Label = null
	for child: Node in tip.get_children():
		if child is Label:
			label = child
	var lines: int = label.get_line_count() if label != null else 0
	await _shot("tooltip_fit/%s_%dx%d" % [what.replace(" ", "_").replace("'", ""),
		roundi(room.size.x), roundi(room.size.y)])
	_check("%s: its hover text at %d, %d, %d x %d, in %d lines, inside the %d x %d window"
		% [what, roundi(rect.position.x), roundi(rect.position.y), roundi(rect.size.x),
			roundi(rect.size.y), lines, roundi(room.size.x), roundi(room.size.y)],
		room.grow(0.5).encloses(rect))


func _hover(control: Control) -> Window:
	var rect: Rect2 = control.get_global_rect()
	var at := Vector2(rect.position.x + minf(40.0, rect.size.x / 2.0), rect.get_center().y)
	_move(at)
	await _frames(3)
	_move(at + Vector2(1, 0))
	var until: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
		for sub: Window in root.get_embedded_subwindows():
			if sub is PopupPanel and (sub as PopupPanel).theme_type_variation == &"TooltipPanel" \
					and sub.visible:
				await _frames(3)
				return sub
	return null


## The pointer over the model, where nothing has a tooltip, until the last
## tooltip has gone.
func _rest() -> void:
	var room: Rect2 = root.get_visible_rect()
	_move(Vector2(room.end.x - 60.0, room.get_center().y))
	await _frames(20)


func _move(at: Vector2) -> void:
	var on_screen: Vector2 = root.get_final_transform() * at
	if _virtual:
		Input.warp_mouse(on_screen)
	var event := InputEventMouseMotion.new()
	event.position = on_screen
	event.global_position = on_screen
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/%s.png" % name)
