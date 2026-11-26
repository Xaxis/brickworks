## fastreview: each model file in a folder opened as Open opens it, and every
## part it reads written out one line each (part, colour, place to 0.01 LDU,
## turn to 0.0001, copy path, group, step), sorted: run in two builds on the
## same files, the two lists say whether both read the files alike.
##
##   godot --headless --path . --script src/dev/fastreview_reopen_probe.gd -- --dir=DIR --dump=DIR [--glob=*-save.mpd]
extends "res://src/dev/pastereview_probe.gd"


func _run() -> void:
	await process_frame
	var dir: String = ""
	var dump: String = ""
	var glob: String = "*-save.mpd"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			dir = arg.trim_prefix("--dir=")
		if arg.begins_with("--dump="):
			dump = arg.trim_prefix("--dump=")
		if arg.begins_with("--glob="):
			glob = arg.trim_prefix("--glob=")
	if dir.is_empty() or dump.is_empty():
		print("fastreview_reopen_probe: --dir= and --dump= are needed")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(dump)
	_forget(PROBE_DIR)
	DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
	SaveTo.native = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(240)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_verbs = _main.get("_verbs")
	_store = _main.get("_store")
	var files: Array = []
	for name: String in DirAccess.get_files_at(dir):
		if name.match(glob):
			files.append(name)
	files.sort()
	for name: String in files:
		await _open(dir.path_join(name))
		var lines := PackedStringArray()
		for brick: BrickWorld.Brick in _shown():
			var t: Transform3D = brick.transform
			var turn := PackedStringArray()
			for axis: int in 3:
				for k: int in 3:
					turn.append("%.4f" % (0.0 if absf(t.basis[axis][k]) < 0.00005 else t.basis[axis][k]))
			lines.append("%s %d %.2f %.2f %.2f [%s] %s |%s| %d" % [brick.part_id, brick.color_code,
				snappedf(t.origin.x, 0.01) + 0.0, snappedf(t.origin.y, 0.01) + 0.0, snappedf(t.origin.z, 0.01) + 0.0,
				" ".join(turn), brick.unit, brick.group, brick.step])
		lines.sort()
		var out := FileAccess.open(dump.path_join(name + ".parts"), FileAccess.WRITE)
		out.store_string("\n".join(lines) + "\n")
		out.close()
		print("  R %s: %d parts" % [name, lines.size()])
	_forget(PROBE_DIR)
	print("\nfastreview_reopen_probe: %d files read" % files.size())
	quit(0)
