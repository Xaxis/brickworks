extends SceneTree
## A repro for sections_probe's "a file written while it is out is the file
## written before" (red from the nightly of 2026-11-26): the bytes a Save
## writes with a section broken out, against a Save with it put back, a Save
## before it came out, and a Save after Undo took it home again.
##
##   godot --headless --path . --script src/dev/sectionsave_probe.gd
##   ... -- --sets=31025-1.mpd,42093-1.mpd  (vendor/omr/files names; the four below by default)
##
## Each file is kept in user://sectionsave_probe/ (or --keep=DIR) to be diffed.

const SETS: Array[String] = ["31025-1.mpd", "42093-1.mpd", "10179-1.mpd", "21016-1.mpd"]

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _ui: SectionsUi
var _sections: Sections
var _out: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.get_slice("=", 1)
	return fallback


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_ui = _shell.sections
	_sections = _ui.sections
	_out = _arg("keep", OS.get_user_data_dir().path_join("sectionsave_probe"))
	DirAccess.make_dir_recursive_absolute(_out)
	(_main.get("_exports") as Exports).folder = _out
	for name: String in _arg("sets", ",".join(SETS)).split(",", false):
		await _one_set(name)
	print("")
	print("sectionsave: %s" % ("every file the same" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _one_set(name: String) -> void:
	var path: String = "res://vendor/omr/files/" + name
	print("\n%s" % name)
	if not FileAccess.file_exists(path):
		print("  (no vendor/omr here; skipped)")
		return
	_main.call("clear_model")
	await process_frame
	_store.open_text(FileAccess.get_file_as_string(path), name.get_basename())
	for _n: int in 10:
		await process_frame
	_shell.assemblies.changed.emit()
	await _ui.suggest()
	_ui.accept()
	_main.call("_on_model_edited")
	for _n: int in 5:
		await process_frame
	var base: String = name.get_basename()
	var opened: String = _save("%s_0_accepted" % base)
	# Nothing changed, the model told it was edited: the same file.
	_main.call("_on_model_edited")
	var told: String = _save("%s_0b_told" % base)
	_same("%s: told it was edited with nothing changed, the same file" % name, opened, told)
	var tops: Array = _sections.sections()
	if tops.is_empty():
		_check("%s: a section to break out" % name, false)
		return
	var picks: Array = [tops.back()]
	for one: Dictionary in tops:
		var own: Dictionary = {}
		for brick_id: int in one["ids"]:
			own[brick_id] = true
		if _sections.way_off(own).y == 0.0 and one != tops.back():
			picks.append(one)
			break
	var n: int = 0
	for pick: Dictionary in picks:
		n += 1
		var section: String = pick["path"]
		var label: String = Assemblies.label(section)
		var before: String = _save("%s_%d_before" % [base, n])
		_sections.break_out(section)
		_main.call("_on_model_edited")
		var out: String = _save("%s_%d_out" % [base, n])
		_sections.put_back(section)
		_main.call("_on_model_edited")
		var back: String = _save("%s_%d_back" % [base, n])
		_builder.undo()
		_main.call("_on_model_edited")
		var undone_out: String = _save("%s_%d_undo_out" % [base, n])
		_builder.undo()
		_main.call("_on_model_edited")
		var home: String = _save("%s_%d_undo_home" % [base, n])
		_builder.redo()
		_builder.redo()
		_main.call("_on_model_edited")
		print("    %s" % label)
		_same("%s: %s out, the Save is the Save with it put back" % [name, label], back, out)
		_same("%s: %s out, the Save is the Save undone to home" % [name, label], home, out)
		_same("%s: %s out, the Save is the Save before it came out" % [name, label], before, out)
		_same("%s: %s put back, the Save is the Save before it came out" % [name, label], before, back)
		_same("%s: %s undone out, the Save is the Save while out" % [name, label], out, undone_out)
		_same("%s: %s undone home, the Save is the Save before it came out" % [name, label], before, home)


## What Save writes for this model now, kept on disk under [param tag].
func _save(tag: String) -> String:
	var to: String = _out.path_join(tag + ".ldr")
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
	var saved: bool = bool(_main.call("save_model", to))
	var text: String = FileAccess.get_file_as_string(to) if saved else ""
	var made: String = _store.to_text("Probe")
	var file := FileAccess.open(_out.path_join(tag + ".text.ldr"), FileAccess.WRITE)
	file.store_string(made)
	file.close()
	if not saved:
		print("    (%s: save_model said no)" % tag)
	return text


func _same(what: String, a: String, b: String) -> void:
	_check(what, a == b and not a.is_empty())
	if a == b:
		return
	var one: PackedStringArray = a.split("\n")
	var other: PackedStringArray = b.split("\n")
	var differ: int = 0
	var first: int = -1
	for i: int in mini(one.size(), other.size()):
		if one[i] != other[i]:
			differ += 1
			if first < 0:
				first = i
	if first >= 0:
		print("    (%d of %d lines differ; the first, line %d: %s | %s)" % [differ, one.size(), first,
			one[first].left(110), other[first].left(110)])
	else:
		print("    (%d lines against %d)" % [one.size(), other.size()])
