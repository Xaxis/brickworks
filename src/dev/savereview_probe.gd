## savereview: an independent review of exactsave (8eda1a4b7, from pre261
## 00d35a98f). Each case opens a file, makes one person's edit, saves it as
## Save does (ModelStore patch, its gate, live's write or whole) and writes it
## whole too (as a model made here is written), reopens each and judges every
## part against the model as it was before the save: lost, added, moved by
## any amount (0.01 LDU, 0.0001 of a turn), mirrored, recoloured, in another
## kind of copy or another step. Run in a pre261 tree and an exactsave tree
## at the same moment, their kept files are diffed after (savereview.py).
##
##   godot --headless --path . --script src/dev/savereview_probe.gd -- --keep=DIR [--cases=a,b] [--sets=0|1]
##
## --keep=DIR keeps every file each case wrote, named by the case; --cases=
## runs those cases alone (by name prefix); --sets=0 skips the real sets.
extends "res://src/dev/pastereview_probe.gd"

const FIXTURE := """0 FILE sr_main.ldr
0 sr_main
0 Name: sr_main.ldr
0 Author: savereview_probe
1 16 0 0 0 1 0 0 0 1 0 0 0 1 sr_wing.ldr
1 16 300 0 0 -1 0 0 0 1 0 0 0 1 sr_wing.ldr
1 4 0 0 300 0.866025 0 0.5 0 1 0 -0.5 0 0.866025 sr_wing.ldr
1 16 -300 0 0 0.9511 0 0.309 0 1 0 -0.309 0 0.9511 sr_car.ldr
1 1 -300 0 300 1 0 0 0 1 0 0 0 1 sr_car.ldr
1 16 600 0 0 1 0 0 0 1 0 0 0 1 sr_once.ldr
1 14 600 0 300 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 16 900 0 0 1 0 0 0 1 0 0 0 1 sr_missing.ldr
1 16 900 0 300 2 0 0 0 1 0 0 0 1 3003.dat
1 16 900 0 500 1 0.5 0 0 1 0 0 0 1 3003.dat
1 16 900 0 700 1 0 0 0 0.000001 0 0 0 1 3003.dat
1 71 1200 0 0 1 0 -1.192093E-07 0 1 0 1.192093E-07 0 1 3001.dat
0 STEP
0 NOFILE
0 FILE sr_wing.ldr
0 sr_wing
0 Name: sr_wing.ldr
0 Author: savereview_probe
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 -20 -8 0 1 0 0 0 1 0 0 0 1 3022.dat
1 15 30 -24 0 1 0 0 0 1 0 0 0 1 3040.dat
1 16 0 32 0 1 0 0 0 1 0 0 0 1 41769.dat
0 NOFILE
0 FILE sr_car.ldr
0 sr_car
0 Name: sr_car.ldr
0 Author: savereview_probe
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 -20 -8 0 1 0 0 0 1 0 0 0 1 sr_flap.ldr
1 16 20 -8 0 -1 0 0 0 1 0 0 0 -1 sr_flap.ldr
0 NOFILE
0 FILE sr_flap.ldr
0 sr_flap
0 Name: sr_flap.ldr
0 Author: savereview_probe
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3023.dat
1 2 0 -8 0 1 0 0 0 1 0 0 0 1 3024.dat
0 NOFILE
0 FILE sr_once.ldr
0 sr_once
0 Name: sr_once.ldr
0 Author: savereview_probe
1 16 0 0 0 0.9511 0 0.309 0 1 0 -0.309 0 0.9511 3001.dat
1 16 0 -24 0 0.9511 0 0.309 0 1 0 -0.309 0 0.9511 3003.dat
1 16 0 24 0 1 0 0 0 1 0 0 0 1 3004.dat
0 NOFILE
"""

## The sub-model's first copy mirrored (det -1), a copy mirrored in z, one
## plain and one mirrored and turned 30 degrees.
const MIRROR_FIRST := """0 FILE sm_main.ldr
0 sm_main
0 Name: sm_main.ldr
0 Author: savereview_probe
1 16 0 0 0 -1 0 0 0 1 0 0 0 1 sm_wing.ldr
1 16 300 0 0 1 0 0 0 1 0 0 0 -1 sm_wing.ldr
1 16 0 0 300 1 0 0 0 1 0 0 0 1 sm_wing.ldr
1 16 300 0 300 -0.866025 0 0.5 0 1 0 0.5 0 0.866025 sm_wing.ldr
0 NOFILE
0 FILE sm_wing.ldr
0 sm_wing
0 Name: sm_wing.ldr
0 Author: savereview_probe
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 -20 -8 0 1 0 0 0 1 0 0 0 1 3022.dat
1 15 30 -24 0 1 0 0 0 1 0 0 0 1 3040.dat
1 16 0 32 0 1 0 0 0 1 0 0 0 1 41769.dat
1 14 40 -8 30 0 0 1 0 1 0 -1 0 0 3024.dat
0 NOFILE
"""

## A copy placed in a direct colour, one in 16 under a parent placed red,
## the sub-model's parts in 16 and one fixed.
const DIRECT := """0 FILE dc_main.ldr
0 dc_main
0 Name: dc_main.ldr
0 Author: savereview_probe
1 0x2FF8800 0 0 0 1 0 0 0 1 0 0 0 1 dc_box.ldr
1 4 300 0 0 1 0 0 0 1 0 0 0 1 dc_holder.ldr
0 NOFILE
0 FILE dc_holder.ldr
0 dc_holder
0 Name: dc_holder.ldr
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 dc_box.ldr
0 NOFILE
0 FILE dc_box.ldr
0 dc_box
0 Name: dc_box.ldr
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3024.dat
0 NOFILE
"""

const SETS := ["10030-1.mpd", "8841-1.mpd", "42116-1.mpd"]

var _keep: String = ""
var _only: PackedStringArray = PackedStringArray()
var _fixture_lf: String = ""
var _fixture_crlf: String = ""


func _run() -> void:
	await process_frame
	var sets: bool = true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--keep="):
			_keep = arg.trim_prefix("--keep=")
			DirAccess.make_dir_recursive_absolute(_keep)
		if arg.begins_with("--cases="):
			_only = arg.trim_prefix("--cases=").split(",", false)
		if arg == "--sets=0":
			sets = false
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
	_fixture_lf = ProjectSettings.globalize_path(PROBE_DIR + "sr_fixture.mpd")
	_write(_fixture_lf, FIXTURE)
	_fixture_crlf = ProjectSettings.globalize_path(PROBE_DIR + "sr_fixture_crlf.mpd")
	_write(_fixture_crlf, FIXTURE.replace("\n", "\r\n"))
	for file: String in [_fixture_lf, _fixture_crlf]:
		var tag: String = "lf" if file == _fixture_lf else "crlf"
		await _case(tag + "_u0", file, Callable())
		if tag == "crlf":
			await _case(tag + "_pc", file, _paste_copy.bind("sr_car", 0, false))
			await _case(tag + "_t30", file, _turn_copy.bind("sr_wing", 2, 30.0))
			continue
		await _case(tag + "_t30", file, _turn_copy.bind("sr_wing", 2, 30.0))
		await _case(tag + "_t45x2", file, _turn_copy_twice.bind("sr_wing", 0, 45.0, -15.0))
		await _case(tag + "_tmir", file, _turn_copy.bind("sr_wing", 1, 30.0))
		await _case(tag + "_tcar", file, _turn_copy.bind("sr_car", 0, 30.0))
		await _case(tag + "_pc", file, _paste_copy.bind("sr_car", 0, false))
		await _case(tag + "_pmir", file, _paste_copy.bind("sr_wing", 1, false))
		await _case(tag + "_p30", file, _paste_copy.bind("sr_wing", 2, false))
		await _case(tag + "_phand", file, _paste_copy.bind("sr_car", 0, true))
		await _case(tag + "_cut", file, _cut_paste.bind("sr_once", 0))
		await _case(tag + "_cutcar", file, _cut_paste.bind("sr_car", 1))
		await _case(tag + "_pundo", file, _paste_undo_redo.bind("sr_car", 0))
		await _case(tag + "_pmvp", file, _paste_then_move.bind("sr_car", 0, true))
		await _case(tag + "_pmvo", file, _paste_then_move.bind("sr_once", 0, false))
		await _case(tag + "_mvmir", file, _move_inside.bind("sr_wing", 1))
		await _case(tag + "_mvcar", file, _move_inside.bind("sr_car", 0))
		await _case(tag + "_rcp", file, _paste_recolour.bind("sr_car", 1))
		await _case(tag + "_odd", file, _odd_parts)
		await _case(tag + "_dup", file, _duplicate.bind("sr_car", 1))
		await _case(tag + "_uniq", file, _unique.bind("sr_wing", 2))
		await _case(tag + "_nest", file, _paste_inner.bind("sr_car", 1))
		await _case(tag + "_pp2", file, _paste_twice.bind("sr_flap", "sr_car", 0))
		await _case(tag + "_mirror", file, _mirror_copy.bind("sr_once", 0))
		# Pasted while editing inside a copy (N4): a loose part and a copy
		# into the sub-model placed once, the same into one placed three
		# times (one of them mirrored) and into the car placed twice.
		await _case(tag + "_pin_loose", file, _paste_entered.bind("sr_once", 0, _loose_ids.bind("3001", 14)))
		await _case(tag + "_pin_copy", file, _paste_entered.bind("sr_once", 0, _copy_ids.bind("sr_wing", 2)))
		await _case(tag + "_pin_wing", file, _paste_entered.bind("sr_wing", 0, _loose_ids.bind("3001", 14)))
		await _case(tag + "_pin_car", file, _paste_entered.bind("sr_car", 0, _copy_ids.bind("sr_once", 0)))
	var mirror_first: String = ProjectSettings.globalize_path(PROBE_DIR + "sm_fixture.mpd")
	_write(mirror_first, MIRROR_FIRST)
	await _case("mf_u0", mirror_first, Callable())
	await _case("mf_t30z", mirror_first, _turn_copy.bind("sm_wing", 1, 30.0))
	await _case("mf_t30m", mirror_first, _turn_copy.bind("sm_wing", 3, 30.0))
	await _case("mf_pm", mirror_first, _paste_copy.bind("sm_wing", 0, false))
	await _case("mf_pm30", mirror_first, _paste_copy.bind("sm_wing", 3, false))
	await _case("mf_mvplain", mirror_first, _move_inside.bind("sm_wing", 2))
	await _case_twice("tw_lf", _fixture_lf)
	if _only.has("tm"):
		await _case_timing()
	var direct: String = ProjectSettings.globalize_path(PROBE_DIR + "direct.mpd")
	_write(direct, DIRECT)
	await _case("dc_pdirect", direct, _paste_copy.bind("dc_box", 0, false))
	await _case("dc_pholder", direct, _paste_copy.bind("dc_holder", 0, false))
	await _case("dc_drift", _fixture_lf, _drift.bind("sr_car", 0))
	# Many copies at the top, all pasted at once: a line each, each laid on
	# the file's copies (timing).
	for mixed: bool in [false, true]:
		var many: String = ProjectSettings.globalize_path(PROBE_DIR + ("many_mixed.mpd" if mixed else "many.mpd"))
		_write(many, _many_text(600, mixed))
		await _case("many_%s" % ("mixed" if mixed else "plain"), many, _paste_all)
	if sets:
		for name: String in SETS:
			var path: String = "res://vendor/omr/files/" + name
			var tag: String = name.get_basename().replace("-", "_")
			await _case(tag + "_u0", path, Callable(), true)
			await _case(tag + "_pc", path, _paste_any.bind(2), true)
			if name == "42116-1.mpd":
				continue
			await _case(tag + "_t30", path, _turn_any.bind(2, 30.0), true)
			if name != "10030-1.mpd":
				await _case(tag + "_pmvo", path, _paste_any_move_original.bind(), true)
		await _case_twice("tw_10030", "res://vendor/omr/files/10030-1.mpd")
	_forget(PROBE_DIR)
	print("\nsavereview_probe: %d failed, %d notes" % [_failures, _notes])
	quit(1 if _failures > 0 else 0)


## Save times, each save repeated: 10030-1 unedited, and the 600 copies
## (plain, and every other one mirrored) all pasted.
func _case_timing() -> void:
	print("\n== tm")
	var at: String = ProjectSettings.globalize_path(PROBE_DIR + "tm.mpd")
	await _open("res://vendor/omr/files/10030-1.mpd")
	for k: int in 5:
		var began: int = Time.get_ticks_usec()
		_main.call("save_model", at)
		print("  TM 10030_unedited save %d: %.0f ms (%s)" % [k, (Time.get_ticks_usec() - began) / 1000.0,
			_store.last_whole if not _store.last_whole.is_empty() else "a patch"])
	for mixed: bool in [false, true]:
		var many: String = ProjectSettings.globalize_path(PROBE_DIR + "tm_many.mpd")
		_write(many, _many_text(600, mixed))
		await _open(many)
		await _paste_all()
		for k: int in 3:
			var began: int = Time.get_ticks_usec()
			_main.call("save_model", at)
			print("  TM many_%s save %d: %.0f ms (%s)" % ["mixed" if mixed else "plain", k,
				(Time.get_ticks_usec() - began) / 1000.0, _store.last_whole.left(60) if not _store.last_whole.is_empty()
				else "a patch"])


## [param count] copies of a three-part sub-model on a grid, every other one
## mirrored where [param mixed].
static func _many_text(count: int, mixed: bool) -> String:
	var out := PackedStringArray(["0 FILE many.ldr", "0 many", "0 Name: many.ldr", "0 Author: savereview_probe"])
	var side: int = int(ceil(sqrt(float(count))))
	for n: int in count:
		var turn: String = "-1 0 0 0 1 0 0 0 1" if mixed and n % 2 == 1 else "1 0 0 0 1 0 0 0 1"
		out.append("1 16 %d 0 %d %s many_t.ldr" % [(n % side) * 120, (n / side) * 80, turn])
	out.append_array(["0 NOFILE", "0 FILE many_t.ldr", "0 many_t", "0 Name: many_t.ldr",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "1 4 -20 -8 0 1 0 0 0 1 0 0 0 1 3022.dat",
		"1 15 30 -24 0 1 0 0 0 1 0 0 0 1 3040.dat", "0 NOFILE", ""])
	return "\n".join(out)


func _paste_all() -> String:
	var ids: Array = []
	for brick: BrickWorld.Brick in _shown():
		ids.append(brick.id)
	var put: Array = await _paste_ids(ids, false)
	return "" if put.is_empty() else "all %d copied, pasted: %d put down" % [ids.size(), put.size()]


## Saved over the file it came from twice without reopening between: a copy
## of [param file], a copy of a sub-model placed twice pasted and saved over
## it, then the paste moved whole and saved over it again; reopened, every
## part where it was. The second save patches the same file the first did.
func _case_twice(tag: String, file: String) -> void:
	if not _only.is_empty() and not Array(_only).any(func(one: String) -> bool: return tag.begins_with(one)):
		return
	print("\n== %s" % tag)
	var own: String = ProjectSettings.globalize_path(PROBE_DIR + tag + "-own.mpd")
	_write(own, FileAccess.get_file_as_string(ProjectSettings.globalize_path(file)))
	await _open(own)
	var said: String = ""
	if file == _fixture_lf:
		said = await _paste_copy("sr_car", 0, false)
	else:
		said = await _paste_any(2)
	if said.is_empty():
		_note("%s: no paste" % tag)
		return
	var first_ok: bool = bool(_main.call("save_model", own))
	print("  W %s first why=%s" % [tag, _store.last_whole if not _store.last_whole.is_empty() else "(a patch)"])
	_kept(tag + "-first.mpd", FileAccess.get_file_as_string(own))
	# The paste moved whole: the newest copy's parts.
	var newest: String = ""
	for brick: BrickWorld.Brick in _shown():
		if brick.origin.is_empty() and not brick.unit.is_empty():
			newest = Assemblies.segments(brick.unit)[0]
	var ids: Array = _ids_under(newest)
	_select(ids)
	var moved: int = 0
	for by: Vector3 in [Vector3(0, 0, 200), Vector3(0, 0, -200), Vector3(200, 0, 0), Vector3(0, -400, 0)]:
		moved = _builder.move_selection_by(by)
		if moved > 0:
			break
	var turned: int = _builder.turn_selection_by(30.0)
	_builder.clear_selection()
	await _frames(3)
	var before: Array = _records_all()
	var second_ok: bool = bool(_main.call("save_model", own))
	print("  W %s second why=%s" % [tag, _store.last_whole if not _store.last_whole.is_empty() else "(a patch)"])
	var text: String = FileAccess.get_file_as_string(own)
	_kept(tag + "-second.mpd", text)
	print("  edit: %s; then %s (%d parts) moved %d and turned %d, saved over it again" % [said, newest, ids.size(),
		moved, turned])
	_ok(first_ok and second_ok, "%s: both saves" % tag)
	await _open(own)
	_judge(tag + " second save", before, _records_all())


# -- one case ---------------------------------------------------------------------


## [param edit] made to the model [param file] opens as (a Callable that
## awaits and says what it did, or "" when it could not), then saved as
## Save does and written whole: each reopened and judged.
func _case(tag: String, file: String, edit: Callable, big: bool = false) -> void:
	if not _only.is_empty():
		var wanted: bool = false
		for one: String in _only:
			if tag.begins_with(one):
				wanted = true
		if not wanted:
			return
	print("\n== %s" % tag)
	await _open(file)
	var opened: Array = _records_all()
	var did: String = "unedited"
	if edit.is_valid():
		did = str(await edit.call())
		if did.is_empty():
			_note("%s: the edit could not be made" % tag)
			return
	await _frames(3)
	var before: Array = _records_all()
	if tag.ends_with("_u0"):
		var tops: Dictionary = {}
		for one: Dictionary in before:
			tops[str(one["unit"])] = int(tops.get(str(one["unit"]), 0)) + 1
		print("  units: %s" % str(tops).left(400))
	print("  edit: %s (%d parts before the save, %d opened)" % [did, before.size(), opened.size()])
	var original: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(file))
	# Save as Save does: the patch, its gate, live's write, or whole.
	var at: String = ProjectSettings.globalize_path(PROBE_DIR + tag + "-save.mpd")
	var began: int = Time.get_ticks_usec()
	var saved_ok: bool = bool(_main.call("save_model", at))
	var save_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	var why: String = _store.last_whole if not _store.last_whole.is_empty() else "(a patch)"
	var saved: String = FileAccess.get_file_as_string(at)
	_kept(tag + "-save.mpd", saved)
	# Written whole, as a model made here is.
	_store.set("_writing_whole", true)
	began = Time.get_ticks_usec()
	var whole: String = _store.to_text(_store.title)
	var whole_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	_store.set("_writing_whole", false)
	var whole_at: String = ProjectSettings.globalize_path(PROBE_DIR + tag + "-whole.mpd")
	_write(whole_at, whole)
	_kept(tag + "-whole.mpd", whole)
	# The autosave's text, over frames for a big model.
	var auto_ms: float = -1.0
	var auto: String = ""
	if big:
		began = Time.get_ticks_usec()
		auto = await _store._model_text(true)
		auto_ms = (Time.get_ticks_usec() - began) / 1000.0
		_kept(tag + "-auto.mpd", auto)
	var diff: Dictionary = _line_diff(original, saved)
	var fresh: Array = (diff["new"] as Array).filter(func(line: String) -> bool:
		return not line.strip_edges().begins_with("0 !BRICKWORKS") and not line.strip_edges().is_empty())
	print("  T %s save_ms=%.0f whole_ms=%.0f auto_ms=%.0f" % [tag, save_ms, whole_ms, auto_ms])
	print("  W %s why=%s" % [tag, why])
	print("  L %s lines gone=%d new=%d%s" % [tag, (diff["lost"] as Array).size(), fresh.size(),
		"" if (diff["lost"] as Array).is_empty() else " first gone: " + " | ".join(PackedStringArray(
			(diff["lost"] as Array).slice(0, 3)))])
	_ok(saved_ok, "%s: saved" % tag)
	var steps_before: Dictionary = _world.unit_steps.duplicate()
	began = Time.get_ticks_usec()
	await _open(at)
	print("  T %s reopen_save_ms=%.0f" % [tag, (Time.get_ticks_usec() - began) / 1000.0])
	_judge(tag + " save", before, _records_all())
	var moved_steps := PackedStringArray()
	for path: String in steps_before:
		if _world.unit_steps.has(path) and int(_world.unit_steps[path]) != int(steps_before[path]):
			moved_steps.append("%s %d -> %d" % [path, int(steps_before[path]), int(_world.unit_steps[path])])
	print("  U %s copies in another step: %d%s" % [tag, moved_steps.size(),
		"" if moved_steps.is_empty() else " (" + ", ".join(moved_steps.slice(0, 4)) + ")"])
	# Saved again, unedited: the same text (a save is stable).
	var again_at: String = ProjectSettings.globalize_path(PROBE_DIR + tag + "-again.mpd")
	_main.call("save_model", again_at)
	var again: String = FileAccess.get_file_as_string(again_at)
	_kept(tag + "-again.mpd", again)
	var again_diff: Dictionary = _line_diff(saved, again)
	print("  S %s saved again unedited: %d lines gone, %d new (%s)" % [tag, (again_diff["lost"] as Array).size(),
		(again_diff["new"] as Array).size(), _store.last_whole if not _store.last_whole.is_empty() else "a patch"])
	await _open(whole_at)
	_judge(tag + " whole", before, _records_all())
	if big and not auto.is_empty():
		var auto_at: String = ProjectSettings.globalize_path(PROBE_DIR + tag + "-auto.mpd")
		_write(auto_at, auto)
		await _open(auto_at)
		_judge(tag + " auto", before, _records_all())


## [param before] against [param back], paired part by part: lost, added,
## moved past 0.01 LDU or 0.0001 of a turn, mirrored, in another kind of copy
## or another step. The whole model may stand elsewhere (stood on the ground
## again): judged from the lowest part's offset.
func _judge(said: String, before: Array, back: Array) -> void:
	var offset: Vector3 = _offset(before, back)
	var buckets: Dictionary = {}
	for one: Dictionary in back:
		var key: String = "%s:%d" % [one["part"], int(one["color"])]
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(one)
	var unpaired: int = 0
	var over: int = 0
	var most: float = 0.0
	var most_basis: float = 0.0
	var mirrored: int = 0
	var kinds: int = 0
	var steps: int = 0
	var worst: String = ""
	var kind_eg: String = ""
	var step_eg: String = ""
	var lost_eg: String = ""
	for one: Dictionary in before:
		var key: String = "%s:%d" % [one["part"], int(one["color"])]
		var bucket: Array = buckets.get(key, [])
		var at: Transform3D = one["at"]
		var best: int = -1
		var best_d: float = INF
		for n: int in bucket.size():
			var there: Transform3D = (bucket[n] as Dictionary)["at"]
			var d: float = at.origin.distance_to(there.origin - offset)
			if d < best_d:
				best_d = d
				best = n
		if best < 0 or best_d > 20.0:
			unpaired += 1
			if lost_eg.is_empty():
				lost_eg = "%s in %s at %s" % [key, one["unit"], at.origin]
			continue
		var other: Dictionary = bucket[best]
		bucket.remove_at(best)
		var ob: Basis = (other["at"] as Transform3D).basis
		var db: float = 0.0
		for row: int in 3:
			for col: int in 3:
				db = maxf(db, absf(at.basis[row][col] - ob[row][col]))
		if signf(ob.determinant()) != signf(at.basis.determinant()):
			mirrored += 1
		elif db > 0.5:
			for axis: int in 3:
				if at.basis[axis].dot(ob[axis]) < -0.5:
					mirrored += 1
					break
		if best_d > 0.01 or db > 0.0001:
			over += 1
			if best_d > most or db > most_basis:
				worst = "%s in %s at %s vs %s, basis %s vs %s" % [key, one["unit"], at.origin,
					(other["at"] as Transform3D).origin - offset, at.basis, ob]
		most = maxf(most, best_d)
		most_basis = maxf(most_basis, db)
		if _kinds(str(one["unit"])) != _kinds(str(other["unit"])):
			kinds += 1
			if kind_eg.is_empty():
				kind_eg = "%s %s -> %s" % [key, one["unit"], other["unit"]]
		if int(one["step"]) != int(other["step"]):
			steps += 1
			if step_eg.is_empty():
				step_eg = "%s in %s step %d -> %d" % [key, one["unit"], int(one["step"]), int(other["step"])]
	var extra: int = 0
	for key: String in buckets:
		extra += (buckets[key] as Array).size()
	var bad: bool = unpaired > 0 or extra > 0 or over > 0 or mirrored > 0
	_ok(not bad, "R %s: %d against %d; lost %d, added %d; %d past 0.01 LDU/0.0001 (most %.4f LDU, %.6f); %d mirrored; %d in another kind of copy; %d in another step; offset %s"
		% [said, before.size(), back.size(), unpaired, extra, over, most, most_basis, mirrored, kinds, steps, offset])
	if not worst.is_empty():
		print("        worst: %s" % worst)
	if not lost_eg.is_empty():
		print("        lost: %s" % lost_eg)
	if not kind_eg.is_empty():
		print("        kind: %s" % kind_eg)
	if not step_eg.is_empty():
		print("        step: %s" % step_eg)


## How far [param back] stands from [param before]: the lowest part's rise.
func _offset(before: Array, back: Array) -> Vector3:
	var low_a: float = -INF
	var low_b: float = -INF
	for one: Dictionary in before:
		low_a = maxf(low_a, (one["at"] as Transform3D).origin.y)
	for one: Dictionary in back:
		low_b = maxf(low_b, (one["at"] as Transform3D).origin.y)
	if before.is_empty() or back.is_empty():
		return Vector3.ZERO
	return Vector3(0, snappedf(low_b - low_a, 0.001), 0) if absf(low_b - low_a) > 0.0005 else Vector3.ZERO


## A copy's path by the kinds of copy alone ("Car#2/Flap#1" -> "Car/Flap").
static func _kinds(unit: String) -> String:
	var out: String = ""
	for segment: String in Assemblies.segments(unit):
		out += "/" + Assemblies.definition(segment)
	return out


func _records(ids: Array) -> Array:
	var out: Array = []
	for id: Variant in ids:
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		if brick == null:
			continue
		out.append({"part": brick.part_id, "color": brick.color_code, "at": brick.transform,
			"unit": brick.unit, "group": brick.group, "id": brick.id, "step": brick.step})
	return out


func _kept(name: String, text: String) -> void:
	if not _keep.is_empty():
		_write(_keep.path_join(name), text)


static func _line_diff(was: String, now: String) -> Dictionary:
	var pool: Dictionary = {}
	for line: String in was.replace("\r", "").split("\n"):
		pool[line] = int(pool.get(line, 0)) + 1
	var fresh: Array = []
	for line: String in now.replace("\r", "").split("\n"):
		if int(pool.get(line, 0)) > 0:
			pool[line] = int(pool[line]) - 1
		else:
			fresh.append(line)
	var lost: Array = []
	for line: String in pool:
		for _n: int in int(pool[line]):
			if not line.strip_edges().is_empty():
				lost.append(line)
	return {"lost": lost, "new": fresh}


# -- finding copies ---------------------------------------------------------------


## The top-level copies of [param def] (by its file name's stem), in path
## order.
func _copies_of(def: String) -> Array:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _shown():
		if brick.unit.is_empty():
			continue
		var top: String = Assemblies.segments(brick.unit)[0]
		if Assemblies.definition(top).to_lower().begins_with(def):
			out[top] = true
	var paths: Array = out.keys()
	paths.sort_custom(func(x: String, y: String) -> bool: return Assemblies.copy_of(x) < Assemblies.copy_of(y))
	return paths


func _ids_under(path: String) -> Array:
	var ids: Array = []
	for brick: BrickWorld.Brick in _shown():
		if brick.unit == path or brick.unit.begins_with(path + "/"):
			ids.append(brick.id)
	return ids


## The [param n]th top-level copy of [param def]: [path, ids], or [].
func _copy(def: String, n: int) -> Array:
	var paths: Array = _copies_of(def)
	if n >= paths.size():
		print("  (no copy %d of %s: %s)" % [n, def, paths])
		return []
	return [paths[n], _ids_under(paths[n])]


# -- the edits --------------------------------------------------------------------


func _turn_copy(def: String, n: int, degrees: float) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	return await _turn_ids(found[0], found[1], [degrees])


func _turn_copy_twice(def: String, n: int, first: float, second: float) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	return await _turn_ids(found[0], found[1], [first, second])


func _turn_ids(path: String, ids: Array, turns: Array) -> String:
	_select(ids)
	var done: Array = []
	for by: Vector3 in [Vector3.ZERO, Vector3(0, -200, 0), Vector3(0, -600, 0)]:
		if by != Vector3.ZERO and _builder.move_selection_by(by) == 0:
			continue
		done = []
		for degrees: float in turns:
			if _builder.turn_selection_by(degrees) > 0:
				done.append(degrees)
		if done.size() == turns.size():
			break
	_builder.clear_selection()
	await _frames(3)
	return "" if done.size() != turns.size() else "%s (%d parts) turned %s" % [path, ids.size(), done]


func _paste_ids(ids: Array, turn_in_hand: bool) -> Array:
	var copied: Array = _records(ids)
	_select(ids)
	_verbs.copy()
	_builder.clear_selection()
	if _verbs.paste() == 0:
		return []
	if turn_in_hand:
		_builder.rotate_held(1)
	var put: Dictionary = await _put(_spots_for(_records_all(), copied))
	return put["ids"]


func _paste_copy(def: String, n: int, turn_in_hand: bool) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	var put: Array = await _paste_ids(found[1], turn_in_hand)
	return "" if put.is_empty() else "%s (%d parts) copied, pasted%s: %d put down, units %s" % [found[0],
		(found[1] as Array).size(), " turned in hand" if turn_in_hand else "", put.size(), _units_of(put)]


func _units_of(ids: Array) -> Array:
	var out: Dictionary = {}
	for id: Variant in ids:
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		if brick != null:
			out[brick.unit] = true
	return out.keys()


func _cut_paste(def: String, n: int) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	var copied: Array = _records(found[1])
	_select(found[1])
	if _verbs.cut() == 0:
		return ""
	await _frames(3)
	if _verbs.paste() == 0:
		return ""
	var put: Dictionary = await _put(_spots_for(_records_all(), copied))
	return "" if (put["ids"] as Array).is_empty() else "%s cut and pasted: %d put down, units %s" % [found[0],
		(put["ids"] as Array).size(), _units_of(put["ids"])]


func _paste_undo_redo(def: String, n: int) -> String:
	var said: String = await _paste_copy(def, n, false)
	if said.is_empty():
		return ""
	var undone: bool = _builder.undo()
	await _frames(3)
	var count: int = _shown().size()
	var redone: bool = _builder.redo()
	await _frames(3)
	return "%s; undone %s (%d parts), redone %s (%d parts)" % [said, undone, count, redone, _shown().size()]


## Pasted, then one part moved: of the paste ([param of_paste]) or of the
## original.
func _paste_then_move(def: String, n: int, of_paste: bool) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	var put: Array = await _paste_ids(found[1], false)
	if put.is_empty():
		return ""
	var pick: int = int((put if of_paste else (found[1] as Array))[0])
	var moved: String = await _move_one(pick)
	return "" if moved.is_empty() else "%s pasted (%d), then %s of the %s moved %s" % [found[0], put.size(),
		_world.get_brick(pick).part_id, "paste" if of_paste else "original", moved]


func _move_one(id: int) -> String:
	for by: Vector3 in [Vector3(0, -40, 0), Vector3(0, 40, 0), Vector3(20, 0, 0), Vector3(0, 0, 20),
			Vector3(0, -400, 0), Vector3(-20, 0, 0)]:
		_select([id])
		if _builder.move_selection_by(by) > 0:
			_builder.clear_selection()
			await _frames(3)
			return str(by)
	_builder.clear_selection()
	return ""


func _move_inside(def: String, n: int) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	var pick: int = int((found[1] as Array)[0])
	var moved: String = await _move_one(pick)
	return "" if moved.is_empty() else "%s of %s moved %s" % [_world.get_brick(pick).part_id, found[0], moved]


func _paste_recolour(def: String, n: int) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	var put: Array = await _paste_ids(found[1], false)
	if put.is_empty():
		return ""
	_select([put[0]])
	var painted: int = _builder.paint_selection(14)
	_builder.clear_selection()
	await _frames(3)
	return "%s pasted (%d), one part painted yellow: %d" % [found[0], put.size(), painted]


## The scaled, sheared and near-singular parts and the Stud.io-numbered one
## moved and turned a quarter.
func _odd_parts() -> String:
	var ids: Array = []
	for brick: BrickWorld.Brick in _shown():
		if brick.unit.is_empty() and brick.transform.origin.x > 850.0:
			ids.append(brick.id)
	if ids.is_empty():
		return ""
	var out: PackedStringArray = PackedStringArray()
	for id: int in ids:
		var b: BrickWorld.Brick = _world.get_brick(id)
		out.append("%s det %.6f" % [b.part_id, b.transform.basis.determinant()])
	_select(ids)
	var moved: int = _builder.move_selection_by(Vector3(0, 0, -40))
	var turned: int = _builder.turn_selection_by(90.0)
	_builder.clear_selection()
	await _frames(3)
	for id: int in ids:
		var b: BrickWorld.Brick = _world.get_brick(id)
		out.append("now det %.6f" % b.transform.basis.determinant())
	return "the odd parts (%d) moved %d, turned %d: %s" % [ids.size(), moved, turned, ", ".join(out)]


func _duplicate(def: String, n: int) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	var had: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		had[brick.id] = true
	_select(found[1])
	var count: int = _verbs.duplicate_beside()
	_builder.cancel_carry()
	_builder.clear_selection()
	await _frames(3)
	var put: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not had.has(brick.id):
			put.append(brick.id)
	return "" if put.is_empty() else "%s duplicated beside (%d): %d put down, units %s" % [found[0], count,
		put.size(), _units_of(put)]


func _unique(def: String, n: int) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	_select(found[1])
	var made: String = _verbs.make_unique(found[0])
	_builder.clear_selection()
	await _frames(3)
	return "" if made.is_empty() else "%s made unique: %s" % [found[0], made]


## The first copy inside the [param n]th of [param def], copied and pasted on
## its own.
func _paste_inner(def: String, n: int) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	var inner: String = ""
	for id: Variant in found[1]:
		var unit: String = _world.get_brick(int(id)).unit
		if unit.count("/") >= 1:
			inner = unit
			break
	if inner.is_empty():
		return ""
	var put: Array = await _paste_ids(_ids_under(inner), false)
	return "" if put.is_empty() else "%s copied, pasted: %d put down, units %s" % [inner, put.size(), _units_of(put)]


## What [param what] names (ids) copied, then pasted while editing inside the
## [param n]th copy of [param into_def] (Assemblies.enter, what a
## double-click does): the paste goes into that copy. Every part put down
## must be in it.
func _paste_entered(into_def: String, n: int, what: Callable) -> String:
	var into: Array = _copy(into_def, n)
	var ids: Array = what.call()
	if into.is_empty() or ids.is_empty():
		return ""
	var copied: Array = _records(ids)
	_select(ids)
	_verbs.copy()
	_builder.clear_selection()
	_verbs.assemblies.enter(str(into[0]))
	var put: Dictionary = {"ids": []}
	if _verbs.paste() > 0:
		put = await _put(_spots_for(_records_all(), copied))
	_verbs.assemblies.leave_to("")
	await _frames(3)
	var inside: int = 0
	for id: Variant in put["ids"]:
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		if brick != null and Assemblies.within(brick.unit, str(into[0])):
			inside += 1
	_ok(not (put["ids"] as Array).is_empty() and inside == (put["ids"] as Array).size(),
		"pasted inside %s: %d of %d put down are in it" % [into[0], inside, (put["ids"] as Array).size()])
	return "" if (put["ids"] as Array).is_empty() else "%d parts copied, pasted inside %s: %d put down, units %s" % [
		ids.size(), into[0], (put["ids"] as Array).size(), _units_of(put["ids"])]


## The loose parts of [param part] in [param colour].
func _loose_ids(part: String, colour: int) -> Array:
	var ids: Array = []
	for brick: BrickWorld.Brick in _shown():
		if brick.unit.is_empty() and brick.part_id == part and brick.color_code == colour:
			ids.append(brick.id)
	return ids


## The parts of the [param n]th top-level copy of [param def].
func _copy_ids(def: String, n: int) -> Array:
	var found: Array = _copy(def, n)
	return [] if found.is_empty() else found[1]


## [param inner_def]'s first copy inside [param def]'s [param n]th pasted twice.
func _paste_twice(inner_def: String, def: String, n: int) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	var inner: String = ""
	for id: Variant in found[1]:
		var unit: String = _world.get_brick(int(id)).unit
		if unit.count("/") >= 1 and Assemblies.definition(Assemblies.leaf(unit)).to_lower().begins_with(inner_def):
			inner = unit
			break
	if inner.is_empty():
		return ""
	var one: Array = await _paste_ids(_ids_under(inner), false)
	var two: Array = await _paste_ids(_ids_under(inner), false)
	return "" if one.is_empty() or two.is_empty() else "%s pasted twice: units %s, %s" % [inner, _units_of(one),
		_units_of(two)]


## A copy turned twelve times by 30 degrees (a whole turn) and dragged 50
## times there and back: each part's turn against its turn before, at most.
func _drift(def: String, n: int) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	var was: Array = _records(found[1])
	_select(found[1])
	var lifted: int = _builder.move_selection_by(Vector3(0, -400, 0))
	var turns: int = 0
	for _k: int in 12:
		if _builder.turn_selection_by(30.0) > 0:
			turns += 1
	var drags: int = 0
	for k: int in 50:
		if _builder.move_selection_by(Vector3(20, 0, 0) if k % 2 == 0 else Vector3(-20, 0, 0)) > 0:
			drags += 1
	_builder.move_selection_by(Vector3(0, 400, 0))
	_builder.clear_selection()
	await _frames(3)
	var most: float = 0.0
	var now: Array = _records(found[1])
	for k: int in mini(was.size(), now.size()):
		var a: Basis = (was[k]["at"] as Transform3D).basis
		var b: Basis = (now[k]["at"] as Transform3D).basis
		for row: int in 3:
			for col: int in 3:
				most = maxf(most, absf(a[row][col] - b[row][col]))
	return "%s lifted %d, turned 30 x %d, dragged %d: most a turn's element moved %.8f" % [found[0], lifted, turns,
		drags, most]


func _mirror_copy(def: String, n: int) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	_select(found[1])
	var count: int = _verbs.mirror()
	_builder.clear_selection()
	await _frames(3)
	return "" if count == 0 else "%s mirrored (%d)" % [found[0], count]


# -- the real sets ------------------------------------------------------------------


## A top-level copy of a definition placed at least [param least] times at
## the top, of 4 to 300 parts, one turned off square where there is one:
## [path, ids] or [].
func _pick(least: int) -> Array:
	var by_def: Dictionary = {}
	var size: Dictionary = {}
	var odd: Dictionary = {}
	for brick: BrickWorld.Brick in _shown():
		if brick.unit.is_empty():
			continue
		var top: String = Assemblies.segments(brick.unit)[0]
		var def: String = Assemblies.definition(top)
		by_def.get_or_add(def, {})[top] = true
		size[top] = int(size.get(top, 0)) + 1
		var b: Basis = brick.transform.basis
		for axis: int in 3:
			for k: int in 3:
				var v: float = absf(b[axis][k])
				if v > 0.0001 and absf(v - 1.0) > 0.0001:
					odd[top] = true
	var chosen: String = ""
	for def: String in by_def:
		var tops: Array = (by_def[def] as Dictionary).keys()
		if tops.size() < least:
			continue
		tops.sort()
		for top: String in tops:
			if int(size[top]) < 4 or int(size[top]) > 300:
				continue
			if chosen.is_empty() or odd.has(top) and not odd.has(chosen):
				chosen = top
	if chosen.is_empty():
		return []
	return [chosen, _ids_under(chosen)]


func _paste_any(least: int) -> String:
	var found: Array = _pick(least)
	if found.is_empty():
		return ""
	var put: Array = await _paste_ids(found[1], false)
	return "" if put.is_empty() else "%s (%d parts) copied, pasted: %d put down, units %s" % [found[0],
		(found[1] as Array).size(), put.size(), _units_of(put).slice(0, 4)]


func _turn_any(least: int, degrees: float) -> String:
	var found: Array = _pick(least)
	if found.is_empty():
		return ""
	return await _turn_ids(found[0], found[1], [degrees])


## A copy of a definition placed once pasted, then a part of the original
## moved: the pasted line names the section the move rewrites.
func _paste_any_move_original() -> String:
	var once: Array = []
	var by_def: Dictionary = {}
	for brick: BrickWorld.Brick in _shown():
		if brick.unit.is_empty():
			continue
		var top: String = Assemblies.segments(brick.unit)[0]
		by_def.get_or_add(Assemblies.definition(top), {})[top] = true
	for brick: BrickWorld.Brick in _shown():
		if brick.unit.is_empty() or brick.unit.contains("/"):
			continue
		if (by_def[Assemblies.definition(brick.unit)] as Dictionary).size() == 1:
			var ids: Array = _ids_under(brick.unit)
			if ids.size() >= 4 and ids.size() <= 300:
				once = [brick.unit, ids]
				break
	if once.is_empty():
		return ""
	var put: Array = await _paste_ids(once[1], false)
	if put.is_empty():
		return ""
	var moved: String = await _move_one(int((once[1] as Array)[0]))
	return "" if moved.is_empty() else "%s (placed once, %d parts) pasted, a part of the original moved %s" % [
		once[0], (once[1] as Array).size(), moved]
