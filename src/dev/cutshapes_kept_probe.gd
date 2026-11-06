## A cut-away kept with the model (APP_UX4 8, bar 3): saved, and back when
## the file opens.
##
##   godot --headless --path . --script src/dev/cutshapes_kept_probe.gd
##
## The sample car cut by a box round its roof, its floor pulled down two
## plates, saved as a person saves it and opened again: the box is back
## where it was, cutting, its strip up, and every part there. The same for
## a sphere, a cylinder and the plane; the cut put away is gone from the
## next save. Then someone else's file, an .mpd of two models and no steps
## opened from disk: cut, saved, and its own lines are all still there,
## with no steps put in, and the cut comes back with it.
##
##   -- --keep=DIR    leaves the files it saved in DIR, with what each holds
##   -- --older=DIR   opens each file left there, to be run by an older
##                    Brickworks, which knows nothing of the cut: each opens
##                    whole, and uncut
extends SceneTree

const META := "0 !BRICKWORKS CUT_AWAY "
const PLANE := 0
const BOX := 1
const SPHERE := 2
const CYLINDER := 3

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Node
## Saved file name -> how many parts it holds, for --keep.
var _kept: Dictionary = {}


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
	for _n: int in 60:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_shell = _main.get("_shell")

	var older: String = _argument("--older")
	if not older.is_empty():
		await _opened_by_an_older_one(older)
	else:
		var see: Object = _see()
		if see == null or not see.has_method("cut_by"):
			_check("a cut by a box, a sphere or a cylinder to keep", false)
			print("\ncutshapes kept: a person cannot cut a model away by a box, a sphere or a cylinder here")
			quit(1)
			return
		await _the_car()
		await _someone_elses_file()
		var keep: String = _argument("--keep")
		if not keep.is_empty():
			_leave_in(keep)
	print("")
	if _failures == 0:
		print("cutshapes kept: the cut is kept with the model, in its own file and someone else's, "
			+ "and an older Brickworks opens them whole" if not older.is_empty()
			else "cutshapes kept: the cut is kept with the model, in its own file and someone else's")
	else:
		print("cutshapes kept: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- the car ------------------------------------------------------------------


func _the_car() -> void:
	print("  the car, saved and opened")
	var placed: int = int(_main.call("_open", "res://models/car.ldr"))
	await _settled()
	var parts: int = _parts()
	_check("the sample car opens (%d parts)" % placed, placed > 50 and parts == placed)
	var see: Object = _see()

	# A box round the roof, its floor pulled down two plates as its knob is.
	_builder.clear_selection()
	_builder.select_brick(_first("4213"), false)
	_shell.call("run", "cut_box")
	_builder.clear_selection()
	see.call("push", 2, 2)
	await _settled()
	_check("the car is cut by a box", _shape() == BOX)
	await _round_trip("the box", "cutshapes_box.ldr", parts)

	for kind: int in [SPHERE, CYLINDER]:
		var name: String = ["", "", "sphere", "cylinder"][kind]
		see.call("cut_by", kind)
		await _settled()
		_check("...then by a %s" % name, _shape() == kind)
		await _round_trip("the " + name, "cutshapes_%s.ldr" % name, parts)

	# The plane, along X, moved and flipped.
	see.call("cut_along", 0)
	see.call("move_to", 11.0)
	see.call("flip")
	await _settled()
	_check("...then by the plane", _world.is_cut() and _shape() == PLANE
		and int(see.get("axis")) == 0)
	await _round_trip("the plane", "cutshapes_plane.ldr", parts)

	# Put away: the next save keeps none.
	see.call("set_cut", false)
	await _settled()
	var path: String = ModelStore.SAVE_DIR + "cutshapes_none.ldr"
	_check("put away, it is saved without one", bool(_main.call("save_model", path))
		and _lines_of(FileAccess.get_file_as_string(path)).is_empty())
	_main.call("_open", path)
	await _settled()
	_check("...and opens uncut", not _world.is_cut() and not bool(see.get("cutting")))


## The cut on now saved as [param file], something else opened, and the
## file opened again: the same cut back, cutting, and [param parts] there.
func _round_trip(what: String, file: String, parts: int) -> void:
	var see: Object = _see()
	var was: Array = _the_cut()
	var path: String = ModelStore.SAVE_DIR + file
	var saved: bool = bool(_main.call("save_model", path))
	var text: String = FileAccess.get_file_as_string(path)
	var lines: PackedStringArray = _lines_of(text)
	_check("%s saved in the model's file, one line: %s" % [what,
		lines[0].trim_prefix(META) if lines.size() == 1 else str(lines.size())],
		saved and lines.size() == 1)
	_main.call("clear_model")
	await _settled()
	_check("...something else on the baseplate, nothing is cut", not _world.is_cut()
		and not bool(see.get("cutting")) and not (see.get("bar") as Control).visible)
	_main.call("_open", path)
	await _settled()
	var now: Array = _the_cut()
	_check("...opened again, %s is back where it was (%s)" % [what, str(now)],
		_world.is_cut() and bool(see.get("cutting")) and _same(now, was)
		and (see.get("bar") as Control).visible)
	_check("...with every part (%d)" % _parts(), _parts() == parts)
	_kept[file] = parts


# -- someone else's file ------------------------------------------------------


func _someone_elses_file() -> void:
	print("  someone else's file: an .mpd of two models, no steps, from disk")
	var source: String = _two_models()
	var folder: String = OS.get_user_data_dir().path_join("cutshapes")
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = folder.path_join("garage.mpd")
	var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	out.store_string(source)
	out.close()
	var placed: int = int(_main.call("_open", path))
	await _settled()
	var parts: int = _parts()
	_check("it opens (%d parts)" % parts, parts > 50 and parts == placed)
	_check("...as someone else's file, written back as it is", _store.call("_live_source") != null)
	_shell.call("run", "cut_box")
	await _settled()
	var see: Object = _see()
	see.call("grow", 1)
	await _settled()
	_check("cut by a box", _shape() == BOX)
	var was: Array = _the_cut()
	var saved: String = ModelStore.SAVE_DIR + "garage.ldr"
	_check("saved", bool(_main.call("save_model", saved)))
	var text: String = FileAccess.get_file_as_string(saved)
	_check("...with the cut, one line", _lines_of(text).size() == 1)
	_check("...and the file's own lines all still there, in its order",
		_in_order(source, text))
	_check("...its two models kept (%d FILE lines)" % text.count("0 FILE "),
		text.count("0 FILE ") == source.count("0 FILE "))
	_check("...and no steps put in", not text.contains("0 STEP"))
	_main.call("clear_model")
	await _settled()
	_main.call("_open", saved)
	await _settled()
	_check("opened again, the box is back where it was", _world.is_cut()
		and _same(_the_cut(), was))
	_check("...with every part (%d)" % _parts(), _parts() == parts)
	_kept["garage.ldr"] = parts


## The car as an .mpd of two models, its wheels a model of their own, with
## no steps: the kind of file another program writes.
func _two_models() -> String:
	var wheels := PackedStringArray()
	var body := PackedStringArray()
	for line: String in FileAccess.get_file_as_string("res://models/car.ldr").split("\n"):
		var words: PackedStringArray = line.strip_edges().split(" ", false)
		if words.size() < 15 or words[0] != "1":
			continue
		if words[14].to_lower() in ["3641.dat", "4624.dat"]:
			wheels.append(line.strip_edges())
		else:
			body.append(line.strip_edges())
	return "\n".join(PackedStringArray([
		"0 FILE garage.ldr", "0 A car in a garage", "0 Name: garage.ldr",
		"0 Author: someone else",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 wheels.ldr"]) + body + PackedStringArray([
		"0 NOFILE", "0 FILE wheels.ldr", "0 Its wheels", "0 Name: wheels.ldr",
		"0 Author: someone else"]) + wheels + PackedStringArray(["0 NOFILE", ""]))


## Whether every line of [param source] is in [param text], in its order.
static func _in_order(source: String, text: String) -> bool:
	var lines: PackedStringArray = text.split("\n")
	var at: int = 0
	for line: String in source.split("\n"):
		var wanted: String = line.strip_edges()
		if wanted.is_empty():
			continue
		while at < lines.size() and lines[at].strip_edges() != wanted:
			at += 1
		if at >= lines.size():
			print("    not found in order: %s" % wanted)
			return false
		at += 1
	return true


# -- an older Brickworks ------------------------------------------------------


func _leave_in(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for file: String in _kept:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(ModelStore.SAVE_DIR + file),
			folder.path_join(file))
	var out: FileAccess = FileAccess.open(folder.path_join("parts.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(_kept, "\t"))
	out.close()
	print("  left %d files in %s" % [_kept.size(), folder])


func _opened_by_an_older_one(folder: String) -> void:
	print("  opened by this Brickworks")
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		folder.path_join("parts.json")))
	_check("the files a newer one saved are there", listed is Dictionary
		and not (listed as Dictionary).is_empty())
	if not listed is Dictionary:
		return
	for file: String in listed:
		var path: String = folder.path_join(file)
		var lines: int = _lines_of(FileAccess.get_file_as_string(path)).size()
		_main.call("_open", path)
		await _settled()
		var parts: int = _parts()
		_check("%s (its cut line %s) opens whole: %d parts of %d, uncut" % [file,
			"there" if lines == 1 else "missing", parts, int(listed[file])],
			lines == 1 and parts == int(listed[file]) and not _world.is_cut())


# -- reading the app ----------------------------------------------------------


func _see() -> Object:
	return _shell.get("see_inside") if _shell != null else null


func _shape() -> int:
	if not _world.is_cut():
		return -1
	var shape: Object = _world.call("cut_shape")
	return PLANE if shape == null else int(shape.get("kind"))


## What the cut is, to compare: its shape, and where.
func _the_cut() -> Array:
	var see: Object = _see()
	if _shape() == PLANE:
		return [PLANE, int(see.get("axis")), float(see.get("at")), bool(see.get("cuts_positive"))]
	return [_shape(), see.get("room")]


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size() or a.is_empty() or a[0] != b[0]:
		return false
	if int(a[0]) == PLANE:
		return a[1] == b[1] and is_equal_approx(float(a[2]), float(b[2])) and a[3] == b[3]
	return (a[1] as AABB).is_equal_approx(b[1] as AABB)


func _parts() -> int:
	return _world.brick_count() - _store.scenery.size()


func _first(part: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and not _store.scenery.has(brick.id):
			return brick.id
	return 0


static func _lines_of(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with(META):
			out.append(line.strip_edges())
	return out


func _settled() -> void:
	for _n: int in 600:
		await process_frame
		if (_world.get("_dirty") as Dictionary).is_empty() \
				and not bool(_world.get("_rebuild_queued")) and _store.awaited.is_empty():
			break
	for _n: int in 3:
		await process_frame


static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.trim_prefix(prefix + "=")
	return ""
