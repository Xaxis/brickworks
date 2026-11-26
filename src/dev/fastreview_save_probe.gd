## fastreview: an independent review of stepfast's indexed paste scan
## (SourceFile._copy_line's `under` and `_copies_to_lay_on`). The cases
## savereview_probe has not got: a paste mirrored, recoloured whole, moved and
## turned, deleted; a file's copy deleted and another pasted; copies of
## copies (also across a save and reopen); a sub-model pasted into itself
## (placed once, placed three times, and into its own inner copy); and many
## pasted copies, each fifth mirrored, each seventh painted, each third moved,
## each fourth deleted, five of them pasted again. Each is saved as Save does
## and written whole, reopened and judged part by part (savereview's _case),
## its files kept to be compared byte for byte with a tree from before
## stepfast run at the same moment.
##
##   godot --headless --path . --script src/dev/fastreview_save_probe.gd -- --keep=DIR [--cases=a,b]
extends "res://src/dev/savereview_probe.gd"


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--keep="):
			_keep = arg.trim_prefix("--keep=")
			DirAccess.make_dir_recursive_absolute(_keep)
		if arg.begins_with("--cases="):
			_only = arg.trim_prefix("--cases=").split(",", false)
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
	_fixture_lf = ProjectSettings.globalize_path(PROBE_DIR + "fr_fixture.mpd")
	_write(_fixture_lf, FIXTURE)
	var f: String = _fixture_lf
	await _case("fr_pmir", f, _paste_then.bind("sr_car", 0, "mirror"))
	await _case("fr_pmirw", f, _paste_then.bind("sr_wing", 0, "mirror"))
	await _case("fr_ppaint", f, _paste_then.bind("sr_wing", 2, "paint"))
	await _case("fr_pmove", f, _paste_then.bind("sr_car", 0, "move"))
	await _case("fr_pdel", f, _paste_then.bind("sr_car", 1, "delete"))
	await _case("fr_pmirun", f, _paste_then.bind("sr_car", 0, "mirror_undo_redo"))
	await _case("fr_delpaste", f, _delete_then_paste.bind("sr_car", 1, 0))
	await _case("fr_delpastew", f, _delete_then_paste.bind("sr_wing", 0, 2))
	await _case("fr_cc", f, _copies_of_copies.bind("sr_car", 0, 3))
	await _case("fr_ccw", f, _copies_of_copies.bind("sr_wing", 1, 2))
	await _case("fr_ccsave", f, _copy_after_save.bind("sr_car", 0))
	await _case("fr_self_once", f, _paste_entered.bind("sr_once", 0, _copy_ids.bind("sr_once", 0)))
	await _case("fr_self_wing", f, _paste_entered.bind("sr_wing", 0, _copy_ids.bind("sr_wing", 0)))
	await _case("fr_self_flap", f, _paste_into_inner.bind("sr_car", 0))
	await _case("fr_self_car", f, _paste_car_into_flap.bind("sr_car", 0))
	var many: String = ProjectSettings.globalize_path(PROBE_DIR + "fr_many.mpd")
	_write(many, _many_text(120, true))
	await _case("fr_manymix", many, _many_mixed_edits)
	var plain: String = ProjectSettings.globalize_path(PROBE_DIR + "fr_many_plain.mpd")
	_write(plain, _many_text(120, false))
	await _case("fr_manyplain", plain, _many_mixed_edits)
	_forget(PROBE_DIR)
	print("\nfastreview_save_probe: %d failed, %d notes" % [_failures, _notes])
	quit(1 if _failures > 0 else 0)


## The parts of the paste of [param def]'s [param n]th copy that came down
## last, as a person's next act finds them: every brick added by the paste.
func _paste_then(def: String, n: int, then: String) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	var put: Array = await _paste_ids(found[1], false)
	if put.is_empty():
		return ""
	var did: String = await _act(put, then)
	return "" if did.is_empty() else "%s (%d) pasted: %d put down, units %s; then %s" % [found[0],
		(found[1] as Array).size(), put.size(), _units_of(put), did]


## One act on [param ids]: mirror, paint (all yellow), move (whole, then a
## quarter turn), delete, mirror then undo and redo.
func _act(ids: Array, what: String) -> String:
	_select(ids)
	var out: String = ""
	match what:
		"mirror":
			out = "mirrored %d" % _verbs.mirror()
		"paint":
			out = "painted %d" % _builder.paint_selection(14)
		"move":
			var moved: int = 0
			for by: Vector3 in [Vector3(0, 0, 200), Vector3(0, 0, -200), Vector3(200, 0, 0), Vector3(0, -400, 0)]:
				moved = _builder.move_selection_by(by)
				if moved > 0:
					break
			out = "moved %d, turned %d" % [moved, _builder.turn_selection(1)]
		"delete":
			out = "deleted %d" % _builder.remove_selection()
		"mirror_undo_redo":
			var mirrored: int = _verbs.mirror()
			_builder.clear_selection()
			var undone: bool = _builder.undo()
			var redone: bool = _builder.redo()
			out = "mirrored %d, undone %s, redone %s" % [mirrored, undone, redone]
	_builder.clear_selection()
	await _frames(3)
	return out


## The file's [param gone]th copy of [param def] deleted, then its
## [param from]th (counted after the delete) copied and pasted.
func _delete_then_paste(def: String, gone: int, from: int) -> String:
	var found: Array = _copy(def, gone)
	if found.is_empty():
		return ""
	_select(found[1])
	var deleted: int = _builder.remove_selection()
	_builder.clear_selection()
	await _frames(3)
	var said: String = await _paste_copy(def, from, false)
	return "" if said.is_empty() or deleted == 0 else "%s deleted (%d); %s" % [found[0], deleted, said]


## [param def]'s [param n]th copy pasted, then that paste copied and pasted,
## [param depth] times in all: each a copy of the copy before.
func _copies_of_copies(def: String, n: int, depth: int) -> String:
	var found: Array = _copy(def, n)
	if found.is_empty():
		return ""
	var ids: Array = found[1]
	var units := PackedStringArray()
	for _k: int in depth:
		var put: Array = await _paste_ids(ids, false)
		if put.is_empty():
			return ""
		units.append(str(_units_of(put)))
		ids = put
	return "%s pasted, then each paste pasted again (%d deep): %s" % [found[0], depth, " -> ".join(units)]


## [param def]'s [param n]th copy pasted and the model saved over its own
## copy of the file and opened again; then the pasted copy (as the file now
## has it) copied and pasted.
func _copy_after_save(def: String, n: int) -> String:
	var own: String = ProjectSettings.globalize_path(PROBE_DIR + "fr_ccsave-own.mpd")
	_write(own, FileAccess.get_file_as_string(_fixture_lf))
	await _open(own)
	var first: String = await _paste_copy(def, n, false)
	if first.is_empty():
		return ""
	var saved: bool = bool(_main.call("save_model", own))
	_kept("fr_ccsave-first.mpd", FileAccess.get_file_as_string(own))
	print("  W fr_ccsave first why=%s" % (_store.last_whole if not _store.last_whole.is_empty() else "(a patch)"))
	await _open(own)
	var copies: Array = _copies_of(def)
	if copies.is_empty():
		return ""
	var newest: String = copies[-1]
	var put: Array = await _paste_ids(_ids_under(newest), false)
	return "" if put.is_empty() or not saved else "%s; saved and reopened, its copies %s; %s pasted: units %s" % [
		first, copies, newest, _units_of(put)]


## [param def]'s [param n]th copy's first inner copy entered, and a copy of
## that inner copy's own parts pasted into it: a sub-model inside itself.
func _paste_into_inner(def: String, n: int) -> String:
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
	return await _paste_into(inner, _ids_under(inner))


## A copy of the whole [param def] (its [param n]th) pasted into its own
## first inner copy: the car inside its own flap.
func _paste_car_into_flap(def: String, n: int) -> String:
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
	return await _paste_into(inner, found[1])


## [param ids] copied, then pasted while editing inside [param path].
func _paste_into(path: String, ids: Array) -> String:
	var copied: Array = _records(ids)
	_select(ids)
	_verbs.copy()
	_builder.clear_selection()
	_verbs.assemblies.enter(path)
	var put: Dictionary = {"ids": []}
	if _verbs.paste() > 0:
		put = await _put(_spots_for(_records_all(), copied))
	_verbs.assemblies.leave_to("")
	await _frames(3)
	return "" if (put["ids"] as Array).is_empty() else "%d parts copied, pasted inside %s: %d put down, units %s" % [
		ids.size(), path, (put["ids"] as Array).size(), str(_units_of(put["ids"])).left(300)]


## Every part pasted; then of the pasted copies each fifth mirrored, each
## seventh painted, each third moved, each fourth deleted, and five of the
## rest copied and pasted again.
func _many_mixed_edits() -> String:
	var said: String = await _paste_all()
	if said.is_empty():
		return ""
	var copies: Dictionary = {}
	for brick: BrickWorld.Brick in _shown():
		if brick.origin.is_empty() and not brick.unit.is_empty():
			copies.get_or_add(Assemblies.segments(brick.unit)[0], []).append(brick.id)
	var paths: Array = copies.keys()
	paths.sort_custom(func(x: String, y: String) -> bool: return Assemblies.copy_of(x) < Assemblies.copy_of(y))
	var counts: Dictionary = {"mirror": 0, "paint": 0, "move": 0, "delete": 0}
	var kept: Array = []
	for k: int in paths.size():
		var ids: Array = copies[paths[k]]
		_select(ids)
		if k % 4 == 3:
			counts["delete"] += 1 if _builder.remove_selection() > 0 else 0
			_builder.clear_selection()
			continue
		if k % 5 == 4:
			counts["mirror"] += 1 if _verbs.mirror() > 0 else 0
		if k % 7 == 6:
			counts["paint"] += 1 if _builder.paint_selection(14) > 0 else 0
		if k % 3 == 2:
			_select(ids)
			counts["move"] += 1 if _builder.move_selection_by(Vector3(0, -400, 0)) > 0 else 0
		_builder.clear_selection()
		kept.append(paths[k])
	await _frames(3)
	var again: int = 0
	for k: int in mini(5, kept.size()):
		var ids: Array = _ids_under(str(kept[k * 3 % kept.size()]))
		if not (await _paste_ids(ids, false)).is_empty():
			again += 1
	return "%s; of %d pasted copies %s; %d pasted again" % [said, paths.size(), str(counts), again]
