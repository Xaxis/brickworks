## A part made here goes out inside every file that places it, whatever the
## model was opened from (moulds2, mouldreview's carry finding): a set's .mpd,
## a bare .ldr with no FILE line, the same with Windows line ends, and a new
## model. Each written as Save, File > Export and the autosave write it, and
## copied to the clipboard; each read back on a library and a kept folder
## that never saw the part. Every part the file had is still there in its
## colour, and the made part placed and built from the file.
##
##   godot --headless --path . --script src/dev/made_carry_probe.gd -- [--carry-out=DIR]
##
## Made parts go to user://made_carry_probe/, never the person's own.
extends SceneTree

const PROBE_DIR := "user://made_carry_probe/"
const PART := "bw-carryprobe-s000001"
const TEXT := """0 Custom Shape Carry Probe
0 Name: bw-carryprobe-s000001.dat
0 Author: made_carry_probe
0 !LDRAW_ORG Unofficial_Part

0 BFC CERTIFY CCW

3 16 -10 0 -10 10 0 -10 10 0 10
3 16 -10 0 -10 10 0 10 -10 0 10
3 16 -10 8 -10 10 8 10 10 8 -10
3 16 -10 8 -10 -10 8 10 10 8 10
3 16 -10 0 -10 -10 8 -10 10 8 -10
3 16 -10 0 -10 10 8 -10 10 0 -10
3 16 -10 0 10 10 0 10 10 8 10
3 16 -10 0 10 10 8 10 -10 8 10
3 16 -10 0 -10 -10 0 10 -10 8 10
3 16 -10 0 -10 -10 8 10 -10 8 -10
3 16 10 0 -10 10 8 -10 10 8 10
3 16 10 0 -10 10 8 10 10 0 10
0
"""
const BARE := """0 Bare probe model
0 Name: bare.ldr
0 Author: made_carry_probe
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 80 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
"""

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _library: PartLibrary
var _verbs: EditVerbs
var _store: ModelStore
var _out: String = ""
var _failures: int = 0


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--carry-out="):
			_out = arg.trim_prefix("--carry-out=")
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
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
	var made: Dictionary = CustomParts.add(_library, TEXT, PART, true)
	_ok(str(made["problem"]).is_empty() and _library.parts.has(PART), "the part made: %s" % [made])
	_write(PROBE_DIR + "bare.ldr", BARE)
	_write(PROBE_DIR + "crlf.ldr", BARE.replace("\n", "\r\n"))
	for which: Array in [["a set's file (6627-1.mpd)", "res://vendor/omr/files/6627-1.mpd"],
			["a bare .ldr, no FILE line", PROBE_DIR + "bare.ldr"],
			["the same with Windows line ends", PROBE_DIR + "crlf.ldr"],
			["a new model", ""]]:
		await _case(which[0], which[1])
	_finish()


## Opened from [param path] (or new), the part placed beside a part of the
## file's, then each writer read back where the part was never made.
func _case(what: String, path: String) -> void:
	print("\n%s" % what)
	var before: Dictionary = {}
	if path.is_empty():
		_builder.clear_selection()
		_main.call("clear_model")
		await _frames(10)
	else:
		await _open(path)
		before = _counts(FileAccess.get_file_as_string(path), _library)
	var other: int = _world.bricks()[0].id if _world.brick_count() > 0 else 0
	_builder.held_part = PART
	var id: int = await _place_at(Vector3(200, 0, 200))
	_ok(id != 0, "the made part placed in it (%d parts now)" % _world.brick_count())
	var want: Dictionary = before.duplicate()
	var key: String = "%s:%d" % [PART, _world.get_brick(id).color_code if id != 0 else 0]
	want[key] = int(want.get(key, 0)) + 1
	var tag: String = path.get_file().get_basename() if not path.is_empty() else "new"
	var saved_at: String = ProjectSettings.globalize_path(PROBE_DIR + "saved-%s.mpd" % tag)
	_main.call("save_model", saved_at)
	_check(what, "Save", FileAccess.get_file_as_string(saved_at), want, tag + "-save")
	var exported: String = await _store.text_for_file(_store.title, "Writing it for the probe…")
	_check(what, "File > Export (and a link's upload)", exported, want, tag + "-export")
	var autosaved: String = await _store._model_text(true)
	_check(what, "the autosave", autosaved, want, tag + "-autosave")
	# Copied with a part of the file's, and pasted where the part was never made.
	var ids: Array = [id] if other == 0 or other == id else [id, other]
	var held: Array = Carry.gather(_world, _library, ids)
	var copied: String = Carry.as_ldraw(held, _library)
	CustomParts.dir = PROBE_DIR + "elsewhere-%s-copy/" % tag
	var fresh := PartLibrary.new()
	fresh.load_catalogue()
	var pasted: Array = Carry.from_ldraw(copied, fresh)
	var pasted_made: int = pasted.filter(func(item: Dictionary) -> bool:
		return str(item["part"]) == PART).size()
	_ok(not held.is_empty() and pasted.size() == held.size() and pasted_made == 1
			and fresh.mesh_for(PART) != null,
		"copied, pasted where it was never made: %d of %d parts, the made one %s" % [pasted.size(),
			held.size(), "built" if fresh.mesh_for(PART) != null else "NOT built"])
	CustomParts.dir = PROBE_DIR


## [param text], a model written by [param writer], read where the part was
## never made: every part [param want] says, by part and colour, placed, and
## the made part built from the file.
func _check(what: String, writer: String, text: String, want: Dictionary, tag: String) -> void:
	if not _out.is_empty():
		_write(_out.path_join(tag + ".mpd"), text)
	CustomParts.dir = PROBE_DIR + "elsewhere-%s/" % tag
	var fresh := PartLibrary.new()
	fresh.load_catalogue()
	var got: Dictionary = _counts(text, fresh)
	CustomParts.dir = PROBE_DIR
	var lost := PackedStringArray()
	for key: String in want:
		if int(got.get(key, 0)) != int(want[key]):
			lost.append("%s %d of %d" % [key, int(got.get(key, 0)), int(want[key])])
	for key: String in got:
		if not want.has(key):
			lost.append("%s %d, not in the model" % [key, int(got[key])])
	_ok(lost.is_empty() and fresh.mesh_for(PART) != null,
		"%s: read back where the part was never made, %d parts as the model has them, the made part %s%s"
			% [writer, _total(got), "built from its 0 FILE" if fresh.mesh_for(PART) != null
				else "NOT built", "" if lost.is_empty() else "; differs: " + ", ".join(lost)])


## The parts [param text] places, read as an open reads it on [param into]
## (the parts it carries taken in first), by "part:colour" -> how many.
func _counts(text: String, into: PartLibrary) -> Dictionary:
	var model: LdrModel = LdrModel.parse(text, "probe.mpd")
	CustomParts.take_from(into, model)
	var out: Dictionary = {}
	for placement: LdrModel.Placement in model.flatten(into.parts):
		var key: String = "%s:%d" % [placement.part_id, placement.color_code]
		out[key] = int(out.get(key, 0)) + 1
	return out


static func _total(counts: Dictionary) -> int:
	var out: int = 0
	for key: String in counts:
		out += int(counts[key])
	return out


func _open(path: String) -> void:
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 600:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(5)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null and playback.is_playing():
		playback.stop()
		await _frames(3)
	_builder.forget_history()
	_verbs.set_mode("select")
	_builder.clear_selection()


func _place_at(at: Vector3) -> int:
	for dx: int in [0, 40, 80, -40, 120, 160]:
		for dz: int in [0, 60, -60, 120]:
			var spot: Vector3 = at + Vector3(dx, 0, dz)
			for _n: int in 6:
				_builder.update_preview(spot + Vector3(0, 600, 0), Vector3.DOWN)
				await process_frame
			var id: int = _builder.place()
			if id != 0:
				await _frames(3)
				return id
	return 0


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _finish() -> void:
	_forget(PROBE_DIR)
	if _failures == 0:
		print("\nevery writer carries the part made here, whatever the model was opened from")
	else:
		print("\n%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	for name: String in DirAccess.get_directories_at(dir):
		_forget(dir + name + "/")
	DirAccess.remove_absolute(dir)
