## What compiling the first screen costs on this machine: the time to load
## main.tscn (main.gd and every script it names, and theirs), and the memory
## that compile held at its height and kept after.
##
##   godot --headless --path . --script src/dev/start_cost.gd [-- --runs=3]
##
## Each run is a process of its own (a script loads once a process): run it
## a few times and take the median. The web's compile is this one's work on
## the scripts' tokens, so a change's ratio here is the ratio to expect
## there (webstart12, 2026-11-19).
##
## It names no class of the app's: naming one would compile it here first.
extends SceneTree


func _initialize() -> void:
	var before_mb: float = OS.get_static_memory_usage() / 1048576.0
	var began: int = Time.get_ticks_usec()
	# --pre=FILE: scripts to load first, one a line ("res://path [anything]"),
	# each a load of its own, in the order given.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pre="):
			var most: float = 0.0
			for line: String in FileAccess.get_file_as_string(arg.trim_prefix("--pre=")).split("\n", false):
				var at: int = Time.get_ticks_usec()
				load(line.get_slice(" ", 0))
				most = maxf(most, (Time.get_ticks_usec() - at) / 1000.0)
			print("start_cost: loaded first in %.0f ms (the longest load %.0f ms); memory %.0f MB, %.0f MB at its height"
				% [(Time.get_ticks_usec() - began) / 1000.0, most, OS.get_static_memory_usage() / 1048576.0,
					OS.get_static_memory_peak_usage() / 1048576.0])
	var scene: PackedScene = load("res://src/main.tscn")
	var ms: float = (Time.get_ticks_usec() - began) / 1000.0
	var peak_mb: float = OS.get_static_memory_peak_usage() / 1048576.0
	var after_mb: float = OS.get_static_memory_usage() / 1048576.0
	print("start_cost: main.tscn compiled in %.0f ms; memory %.0f MB before, %.0f MB at its height, %.0f MB after%s"
		% [ms, before_mb, peak_mb, after_mb, "" if scene != null else " (NOT LOADED)"])
	# And each script given, loaded after it, as a feature's first use loads
	# one (Later): what that costs once the first screen is in.
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--then="):
			continue
		var path: String = arg.trim_prefix("--then=")
		began = Time.get_ticks_usec()
		var got: Resource = load(path)
		print("start_cost: then %s in %.0f ms; memory %.0f MB after, %.0f MB at the height so far%s"
			% [path, (Time.get_ticks_usec() - began) / 1000.0, OS.get_static_memory_usage() / 1048576.0,
				OS.get_static_memory_peak_usage() / 1048576.0, "" if got != null else " (NOT LOADED)"])
	quit(0 if scene != null else 1)
