## simplereview_off: the studio as it starts, written down whole, so a tree with
## Simple's switch (simplep2) can be held to one without it (b74893382), and
## to itself after many switches.
##
##   PROBE_SIZE=1280x720 tools/probe.sh simplereview_off_probe --srdump=FILE
##   PROBE_SIZE=390x844 tools/probe.sh simplereview_off_probe --srdump=FILE
##
## Writes FILE.start: every node under the root, in tree order, with its class,
## script, whether it is visible, its rectangle (a Control's) and each signal's
## connections (signal -> target class and method), and the counts of nodes,
## objects and orphans. Where Main has use_controls, it then switches 50 times
## (25 there and back), and writes FILE.after the same way. Exits 0.
## --folded means to start with the parts column folded (ShellPrefs parts_open)
## and time opening it, but at 1280 x 720 the column still starts open (the
## pref put before Main is made is not the one it reads); --stay=N goes into
## Simple for N frames and times coming back. Both say how many tiles the
## parts bin holds.
##
## godot --path . --resolution 1280x720 --script src/dev/simplereview_off_probe.gd
extends SceneTree

var _main: Node
var _dump: String = ""


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	await process_frame
	var folded: bool = false
	var stay: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--srdump="):
			_dump = arg.trim_prefix("--srdump=")
		if arg == "--folded":
			folded = true
		if arg.begins_with("--stay="):
			stay = int(arg.trim_prefix("--stay="))
	if _dump.is_empty():
		print("simplereview_off_probe: --srdump=FILE")
		quit(2)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var window: Vector2i = DisplayServer.window_get_size()
	var phone: bool = mini(window.x, window.y) < int(Phone.NARROW)
	Phone._on = 1 if phone else 0
	Phone._wide = false
	Keymap.reset()
	Keymap.use("brickworks")
	SaveTo.native = false
	if folded:
		# The parts column as a person left it folded last time.
		ShellPrefs.put("parts_open", false)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	if phone:
		(_main.get("_phone") as Node).set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
	await _frames(200)
	_write(_dump + ".start")
	print("simplereview_off_probe: %s window, %s; written %s.start" % [window, "phone" if phone else "desktop", _dump])
	print("simplereview_off_probe: at the start the parts bin holds %s" % _tiles())
	if folded:
		# The column the person folded last time, opened again.
		var opened_at: int = Time.get_ticks_usec()
		(_main.get("_bin_dock") as Node).call("set_open", true, false)
		await process_frame
		await process_frame
		print("simplereview_off_probe: the parts column opened in %d ms; the bin holds %s"
			% [(Time.get_ticks_usec() - opened_at) / 1000, _tiles()])
		quit(0)
		return
	if stay > 0 and _main.has_method("use_controls"):
		# Into Simple once and kept there, as a person using it would.
		_main.call("use_controls", &"simple")
		await _frames(stay)
		print("simplereview_off_probe: after %d frames in Simple the parts bin holds %s" % [stay, _tiles()])
		var back_at: int = Time.get_ticks_usec()
		_main.call("use_controls", &"full")
		await process_frame
		await process_frame
		print("simplereview_off_probe: back to Full in %d ms; the bin holds %s"
			% [(Time.get_ticks_usec() - back_at) / 1000, _tiles()])
		_write(_dump + ".stayed")
		quit(0)
		return
	if _main.has_method("use_controls"):
		var began: int = Time.get_ticks_msec()
		for n: int in 50:
			_main.call("use_controls", &"simple" if n % 2 == 0 else &"full")
			await _frames(2)
		await _frames(60)
		print("simplereview_off_probe: 50 switches in %d ms, now %s" % [Time.get_ticks_msec() - began,
			_main.call("controls_layer")])
		_write(_dump + ".after")
	quit(0)


func _tiles() -> String:
	var bin: Node = _main.get("_bin")
	if bin == null:
		return "no bin"
	var grid: Node = bin.get("_grid")
	return "%d tiles of %d (shown %d), %d nodes, %d objects" % [
		grid.get_child_count() if grid != null else -1, (bin.get("_display") as Array).size(),
		int(bin.get("_shown")), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_COUNT)]


func _write(path: String) -> void:
	var lines := PackedStringArray()
	var totals: Dictionary = {"nodes": 0, "connections": 0}
	_walk(root, "", lines, totals)
	lines.append("== nodes %d connections %d" % [totals["nodes"], totals["connections"]])
	lines.append("== objects %d nodes %d orphans %d" % [Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()


static func _plain(name: String) -> String:
	var out: String = name
	var re := RegEx.create_from_string("@[0-9]+")
	out = re.sub(out, "@#", true)
	return out


func _walk(node: Node, at: String, lines: PackedStringArray, totals: Dictionary) -> void:
	var path: String = at + "/" + _plain(String(node.name))
	totals["nodes"] = int(totals["nodes"]) + 1
	var script: Script = node.get_script()
	var line: String = "%s [%s%s]" % [path, node.get_class(),
		"" if script == null else " " + script.resource_path.get_file()]
	if node is CanvasItem:
		line += " vis=%s" % ("1" if (node as CanvasItem).visible else "0")
	if node is Control:
		var rect: Rect2 = (node as Control).get_global_rect()
		line += " rect=%d,%d,%d,%d" % [roundi(rect.position.x), roundi(rect.position.y),
			roundi(rect.size.x), roundi(rect.size.y)]
	lines.append(line)
	for signal_info: Dictionary in node.get_signal_list():
		var name: StringName = signal_info["name"]
		var links: Array = node.get_signal_connection_list(name)
		if links.is_empty():
			continue
		var targets := PackedStringArray()
		for link: Dictionary in links:
			var call: Callable = link["callable"]
			var object: Object = call.get_object()
			var who: String = "?"
			if object != null:
				var their: Script = object.get_script()
				who = object.get_class() if their == null else their.resource_path.get_file()
			targets.append("%s.%s" % [who, call.get_method()])
		targets.sort()
		totals["connections"] = int(totals["connections"]) + links.size()
		lines.append("    %s x%d: %s" % [name, links.size(), ", ".join(targets)])
	for child: Node in node.get_children(true):
		_walk(child, path, lines, totals)
