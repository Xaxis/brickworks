## Prove the parts a file carries build on the engine's worker threads, all at
## once (CustomParts._built_at_once), round after round, without a crash and
## each the same as built alone on the main thread.
##
##   godot --headless --path . --script src/dev/carried_at_once_probe.gd \
##     [-- rounds=N] [-- dir=PATH] [-- FILE ...]
##
## Each FILE is opened as take_from opens one: its carried parts built with
## everything the file carries to draw on. dir= builds the .dat files a folder
## holds as load_all builds those kept in user://custom_parts. With neither,
## the repository's 42129-1, 10261-1 and 60216-1 (98, 91 and 78 carried
## files). A crash here is the crash itself: the run ends with signal 11,
## not a FAIL line (crashfind, 2026-10-17).
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var rounds: int = 12
	var dir: String = ""
	var files: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("rounds="):
			rounds = int(arg.substr(7))
		elif arg.begins_with("dir="):
			dir = arg.substr(4)
		else:
			files.append(arg)
	if files.is_empty() and dir.is_empty():
		files = PackedStringArray(["vendor/omr/files/42129-1.mpd",
			"vendor/omr/files/10261-1.mpd", "vendor/omr/files/60216-1.mpd"])
	var sets: Array = []
	if not dir.is_empty():
		var texts: Dictionary = {}
		for file_name: String in DirAccess.get_files_at(dir):
			if file_name.ends_with(".dat"):
				texts[file_name] = FileAccess.get_file_as_string(dir.path_join(file_name))
		sets.append(["%s (%d kept)" % [dir.get_file(), texts.size()], texts, {}])
	for path: String in files:
		var model: LdrModel = LdrModel.load_file(ProjectSettings.globalize_path("res://" + path)
			if not path.begins_with("/") else path)
		if model == null:
			_check("%s opens" % path, false)
			continue
		var carried: Dictionary = model.embedded_parts.duplicate()
		carried.merge(model.embedded_sources)
		carried.merge(model.embedded_data)
		sets.append(["%s (%d carried)" % [path.get_file(), model.embedded_parts.size()],
			model.embedded_parts.duplicate(), carried])
	for one: Array in sets:
		_round_after_round(one[0], one[1], one[2], rounds)
	print("")
	print("carried at once: %s" % ("every check passed" if _failures == 0
		else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


## [param texts] built at once [param rounds] times, and alone, here, after
## the first: each round's every part the same to the byte as built alone.
func _round_after_round(label: String, texts: Dictionary, others: Dictionary,
		rounds: int) -> void:
	print("%s" % label)
	var sources: Dictionary = {}
	for name: String in others:
		if not others[name] is PackedByteArray:
			sources[name] = others[name]
	# At once first: the first set of a run starts the forge on every worker
	# at once, as the app's start-up does (WorkerTasks.first_here). Built
	# alone first, here, the forge was warm before any worker ran it.
	var began: int = Time.get_ticks_msec()
	var first: Dictionary = CustomParts._built_at_once(texts, others)
	var slowest: int = Time.get_ticks_msec() - began
	var alone: Dictionary = {}
	began = Time.get_ticks_msec()
	for file_name: String in texts:
		if PartPrints.has_pictures(texts[file_name]):
			continue
		var made: PartForge.Result = PartForge.build(texts[file_name],
			file_name.get_basename(), sources, true, null, false)
		alone[file_name] = made.lbm if made.problem.is_empty() else made.problem
	var alone_ms: int = Time.get_ticks_msec() - began
	var differ: PackedStringArray = PackedStringArray()
	for n: int in rounds:
		var built: Dictionary = first
		if n > 0:
			began = Time.get_ticks_msec()
			built = CustomParts._built_at_once(texts, others)
			slowest = maxi(slowest, Time.get_ticks_msec() - began)
		for file_name: String in alone:
			var made: PartForge.Result = built.get(file_name)
			var got: Variant = null if made == null \
				else (made.lbm if made.problem.is_empty() else made.problem)
			if got != alone[file_name] and differ.size() < 8:
				differ.append("%s in round %d" % [file_name, n + 1])
	_check("%d parts built at once %d times, each as built alone (%d ms alone, %d ms at once at most)%s"
		% [alone.size(), rounds, alone_ms, slowest,
			"" if differ.is_empty() else ": not " + ", ".join(differ)],
		differ.is_empty() and not alone.is_empty())
