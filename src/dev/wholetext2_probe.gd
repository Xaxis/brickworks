## wholetext2: a save of someone else's file that falls to the whole write
## keeps each line the writer wrote from a line of the file that still says
## it (SourceFile.kept_said), and a Save, an Export or a share writes only the
## model it was pressed on (ModelStore.model_now).
##
## "keep" cases open a file in other programs' spellings (tabs, 1.00000, 1e-3,
## -0, a retired number, a direct colour, a name in capitals, a copy's name
## in other capitals, CRLF), edit it, and save it through the whole write
## twice in one process: the file's lines kept, and as pre261 wrote it
## (ModelStore.keep_file_lines false, "plain"). Each text is reopened and held
## to the model as edited (every part's place, colour and step), and the
## kept text must lose no line of the file the plain one keeps, and keep
## every placing line of a part nobody changed byte for byte.
## "during" cases open another model while a Save, an Export, a share's
## text or a paced save is being written: nothing is written for it.
## "time" holds a one-frame save and the autosave's longest frame with the
## lines kept beside the plain whole write, in turn, on 10030-1.
##
##   godot --headless --path . --script src/dev/wholetext2_probe.gd -- [--cases=a,b] [--keep=DIR]
extends "res://src/dev/exactsave_probe.gd"

const KEEP := """0 FILE wt2_keep.ldr
0 wholetext2 keep
0 Name: wt2_keep.ldr
0 Author: OtherProgram
0 BFC CERTIFY CCW

1\t4\t0.000\t0\t0\t1\t0\t0\t0\t1\t0\t0\t0\t1\t3001.dat
1 14 -100 -8 0 1.00000 0 0 0 1 0 0 0 1 3023.dat
1 2 200 1e-3 -0 1 0 0 0 1 0 0 0 1 3004.DAT
1 0x2FF0000 300 0 0 1 0 0 0 1 0 0 0 1 3005.dat
  1 1 100 0 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
0 // the second step
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3010.dat
1 16 400 0 0 1 0 0 0 1 0 0 0 1 Wt2_Sub.LDR
1 16 400 0 200 1 0 0 0 1 0 0 0 1 wt2_sub.ldr
0 STEP
0 NOFILE
0 FILE wt2_sub.ldr
0 wt2 sub
0 Name: wt2_sub.ldr
1 4 0 -24 0 1.000000 0 0 0 1 0 0 0 1 3001.dat
1 1 20 -48 0 1 0 0 0 1 0 0 0 1 3022.DAT
0 NOFILE
"""

## A model with no steps, two alike bricks: opened while a save is written.
const OTHER := """0 FILE wt2_other.ldr
0 wholetext2 other
0 Name: wt2_other.ldr
0 Author: OtherProgram
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"""

var _paths: Dictionary = {}


func _run() -> void:
	await process_frame
	var cases: String = "keep_unedited,keep_move,keep_retired,keep_paint,keep_mirror,save_during,export_during,text_during,paced_during,time"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--keep="):
			_keep = arg.trim_prefix("--keep=")
			DirAccess.make_dir_recursive_absolute(_keep)
		if arg.begins_with("--cases="):
			cases = arg.trim_prefix("--cases=")
	var asked: PackedStringArray = cases.split(",", false)
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
	for pair: Array in [["keep", KEEP.replace("\n", "\r\n")], ["other", OTHER]]:
		var path: String = PROBE_DIR + "wt2_%s.mpd" % pair[0]
		_write(ProjectSettings.globalize_path(path), str(pair[1]))
		_paths[pair[0]] = path
	if "keep_unedited" in asked:
		await _case_keep("keep_unedited: nothing changed, written whole", true, _unedited)
	if "keep_move" in asked:
		await _case_keep("keep_move: the 3010 moved 40 LDU along", true, _moved_part.bind("3010"))
	if "keep_retired" in asked:
		await _case_keep("keep_retired: the 3023 (a retired number) moved 40 LDU along", true,
			_moved_part.bind("3023"))
	if "keep_paint" in asked:
		await _case_keep("keep_paint: the 3004 (3004.DAT, 1e-3 and -0 in its line) painted blue", true,
			_painted.bind("3004"))
	if "keep_mirror" in asked:
		await _case_keep("keep_mirror: one copy of two mirrored in place, saved as the app saves it", false,
			_mirrored_copy_in_place)
	for what: String in ["save", "export", "text"]:
		if what + "_during" in asked:
			await _case_during(what, "open")
			await _case_during(what, "new")
	if "paced_during" in asked:
		await _case_paced_during("new")
		await _case_paced_during("open")
	if "time" in asked:
		await _case_time()
	ModelStore.write_over_files = true
	ModelStore.keep_file_lines = true
	_forget(PROBE_DIR)
	print("\nwholetext2_probe: %d failed, %d notes" % [_failures, _notes])
	quit(1 if _failures > 0 else 0)


# -- keep ---------------------------------------------------------------------------


## KEEP opened, edited by [param edit] (-> the file's lines of the parts it
## changed, or null when it was not made), saved through the whole write
## with the file's lines kept and as pre261 wrote it (forced there with
## write_over_files off where [param forced]), each reopened and held to the
## model as edited, and their lines held to the file's.
func _case_keep(said: String, forced: bool, edit: Callable) -> void:
	print("\n" + said)
	var tag: String = said.get_slice(":", 0)
	var original: String = _text_of(_paths["keep"])
	var texts: Dictionary = {}
	var changed: Dictionary = {}
	for kept: bool in [true, false]:
		var how: String = "kept" if kept else "plain"
		await _open(_paths["keep"])
		if _store.get("_source") == null:
			_ok(false, "%s: opened as someone else's file" % tag)
			return
		var lines: Variant = await edit.call()
		_ok(lines != null, "%s %s: the edit made" % [tag, how])
		if lines == null:
			return
		changed = lines
		var after: Array = _snapshot()
		ModelStore.write_over_files = not forced
		ModelStore.keep_file_lines = kept
		var at: String = ProjectSettings.globalize_path(PROBE_DIR + "wt2-%s-%s.mpd" % [tag, how])
		var saved: bool = bool(_main.call("save_model", at))
		ModelStore.write_over_files = true
		ModelStore.keep_file_lines = true
		var source: SourceFile = _store.get("_source")
		print("  %s: saved %s; last_whole \"%s\"; kept_why \"%s\"" % [how, saved, _store.last_whole,
			source.kept_why if source != null else "(no source)"])
		_ok(saved and not _store.last_whole.is_empty(), "%s %s: saved through the whole write" % [tag, how])
		var text: String = _text_of(at)
		texts[how] = text
		_kept("%s-%s.mpd" % [tag, how], text)
		await _open(at)
		var back: Array = _snapshot()
		var want: Array = after.duplicate()
		want.sort()
		back.sort()
		_ok(want == back, "%s %s reopened: %d parts as edited; missing %s; extra %s" % [tag, how,
			want.size(), str(_minus(want, back)), str(_minus(back, want))])
	if texts.size() < 2:
		return
	var kept_diff: Dictionary = _line_diff(original, texts["kept"])
	var plain_diff: Dictionary = _line_diff(original, texts["plain"])
	print("  against the file: kept %d lines gone, %d new; plain %d gone, %d new" % [
		(kept_diff["lost"] as Array).size(), (kept_diff["new"] as Array).size(),
		(plain_diff["lost"] as Array).size(), (plain_diff["new"] as Array).size()])
	for line: String in kept_diff["lost"]:
		print("      kept, gone: " + line)
	for line: String in kept_diff["new"]:
		print("      kept, new:  " + line)
	# Never a line of the file the plain whole write keeps lost by keeping.
	var lost_more: Array = _minus(kept_diff["lost"], plain_diff["lost"])
	_ok(lost_more.is_empty(), "%s: the kept text loses no line of the file the plain whole write keeps %s"
		% [tag, str(lost_more)])
	# Every placing line of a part nobody changed is in it, byte for byte.
	var file_lines: PackedStringArray = original.replace("\r", "").split("\n")
	var have: Dictionary = {}
	for line: String in texts["kept"].replace("\r", "").split("\n"):
		have[line] = int(have.get(line, 0)) + 1
	var missing: Array = []
	for n: int in file_lines.size():
		if not LdrModel.is_placing(file_lines[n]) or changed.has(n):
			continue
		if int(have.get(file_lines[n], 0)) > 0:
			have[file_lines[n]] = int(have[file_lines[n]]) - 1
		else:
			missing.append(file_lines[n])
	_ok(missing.is_empty(), "%s: every placing line nobody changed kept byte for byte (%d missing) %s"
		% [tag, missing.size(), str(missing)])
	var crlf: bool = not texts["kept"].replace("\r\n", "").contains("\n")
	_ok(crlf, "%s: every line of the kept text ends CRLF, as the file's" % tag)


func _unedited() -> Variant:
	return {}


## The one [param part] of the model's own section moved 40 LDU along:
## the file's line it was read from.
func _moved_part(part: String) -> Variant:
	var brick: BrickWorld.Brick = _top_part(part)
	if brick == null:
		return null
	_select([brick.id])
	var moved: int = _builder.move_selection_by(Vector3(40, 0, 0))
	_builder.clear_selection()
	await _frames(3)
	print("  (moved %d: %s, as %s)" % [moved, part, brick.part_id])
	return {LdrModel.kept_line(brick.origin): true} if moved > 0 else null


func _painted(part: String) -> Variant:
	var brick: BrickWorld.Brick = _top_part(part)
	if brick == null:
		return null
	_select([brick.id])
	var painted: int = int(_builder.call("paint_selection", 1))
	_builder.clear_selection()
	await _frames(3)
	print("  (painted %d)" % painted)
	return {LdrModel.kept_line(brick.origin): true} if painted > 0 else null


## The farther of the two copies mirrored in place: no patch says it, so it
## falls to the whole write as a person's save does. Its copy's line changes.
func _mirrored_copy_in_place() -> Variant:
	var copies: Dictionary = {}
	for brick: BrickWorld.Brick in _shown():
		if not brick.unit.is_empty():
			(copies.get_or_add(brick.unit, []) as Array).append(brick)
	if copies.size() < 2:
		return null
	var far: String = ""
	for unit: String in copies:
		if far.is_empty() or (copies[unit][0] as BrickWorld.Brick).transform.origin.z \
				> (copies[far][0] as BrickWorld.Brick).transform.origin.z:
			far = unit
	_select((copies[far] as Array).map(func(b: BrickWorld.Brick) -> int: return b.id))
	var mirrored: int = _builder.mirror_selection(0)
	_builder.clear_selection()
	await _frames(3)
	print("  (mirrored %d of %s)" % [mirrored, far])
	if mirrored <= 0:
		return null
	var lines: Dictionary = {}
	for brick: BrickWorld.Brick in copies[far]:
		var chain: PackedStringArray = brick.origin.split("/", false)
		for segment: String in chain:
			lines[segment.to_int()] = true
	return lines


func _top_part(part: String) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _shown():
		if brick.unit.is_empty() and not brick.origin.is_empty():
			var line: String = (_store.get("_source") as SourceFile).lines[LdrModel.kept_line(brick.origin)]
			if LdrModel.stem(LdrModel.reference_of(line.strip_edges())) == part:
				return brick
	print("  (no %s in the model's own section)" % part)
	return null


## Each part shown as "part cC sN x y z", in the file's coordinates, its
## step the rank of its step among its copy's.
func _snapshot() -> Array:
	var lift: Vector3 = _store._lift_now()
	var steps: Dictionary = {}
	for brick: BrickWorld.Brick in _shown():
		(steps.get_or_add(brick.unit, {}) as Dictionary)[brick.step] = true
	var out: Array = []
	for brick: BrickWorld.Brick in _shown():
		var held: Array = (steps[brick.unit] as Dictionary).keys()
		held.sort()
		var at: Vector3 = brick.transform.origin - lift
		var turn: Basis = brick.transform.basis
		out.append("%s c%d s%d %.1f %.1f %.1f %.2f %.2f %.2f" % [brick.part_id, brick.color_code,
			held.find(brick.step), at.x, at.y, at.z, turn.x.x, turn.y.y, turn.z.z])
	return out


static func _minus(a: Array, b: Array) -> Array:
	var pool: Dictionary = {}
	for item: Variant in b:
		pool[item] = int(pool.get(item, 0)) + 1
	var out: Array = []
	for item: Variant in a:
		if int(pool.get(item, 0)) > 0:
			pool[item] = int(pool[item]) - 1
		else:
			out.append(item)
	return out


# -- during -------------------------------------------------------------------------


## 10030-1 opened, one part moved, and [param what] begun: the Save button
## (ModelBar._on_save), Export's write (export_paced) or a share's text
## (text_for_file); a frame on, [param how]: another model opened ("open",
## which clears the baseplate a few frames later) or a new one begun ("new",
## at once). Judged by the model on the baseplate when it returned: another
## by then, nothing written and said why; still 10030-1, 10030-1 written.
## Never the other model's lines under 10030-1's name.
func _case_during(what: String, how: String) -> void:
	var tag: String = "%s_during %s" % [what, how]
	print("\n%s: 10030-1, one part moved, %s a frame into %s" % [tag,
		"another model opened" if how == "open" else "a new model begun",
		{"save": "the Save button's save", "export": "Export's write", "text": "a share's text"}[what]])
	await _open(SET)
	var brick: BrickWorld.Brick = _placed_once()
	if brick == null or not await _moved(brick):
		_ok(false, "%s: a part moved" % tag)
		return
	var bar: ModelBar = _main.get("_bar")
	var name: String = "wt2 %s %s" % [what, how]
	var disk: String = ProjectSettings.globalize_path(PROBE_DIR + "wt2_%s_%s.mpd" % [what, how])
	if what == "save":
		bar._name.text = name
		bar._name.text_changed.emit(name)
	var heard: Array = []
	var hear: Callable = func(words: String) -> void: heard.append(words)
	bar.said.connect(hear)
	var press: int = _store.model_now()
	var result: Array = [null, press]
	var run: Callable = func() -> void:
		var got: Variant = null
		if what == "save":
			got = await bar._on_save()
		elif what == "export":
			got = await _store.export_paced(disk, name)
		else:
			got = await _store.text_for_file(name, "Writing")
		result[1] = _store.model_now()
		result[0] = got
	run.call()
	await process_frame
	var still: bool = result[0] == null
	if how == "open":
		_main.call("_open", ProjectSettings.globalize_path(_paths["other"]))
	else:
		_main.call("clear_model")
		_world.add_brick("3001", 1, Transform3D.IDENTITY)
	for _n: int in 20000:
		if result[0] != null:
			break
		await process_frame
	for _n: int in 2000:
		if how == "new" or (_world.brick_count() == 2 and not _store.laying):
			break
		await process_frame
	await _frames(10)
	bar.said.disconnect(hear)
	var written: String = str(result[0]) if what == "text" \
		else _text_of(disk) if what == "export" else _text_of(ModelStore.saved_path(name))
	var theirs: bool = written.contains("wholetext2 other") or written.contains("wt2_other")
	var another: bool = int(result[1]) != press
	print("  %s: still writing then: %s; returned %s with %s on the baseplate; refused \"%s\"; heard %s; %d lines written"
		% [tag, still, str(result[0]).left(30), "another model" if another else "10030-1", _store.refused,
			str(heard), written.count("\n")])
	_ok(not theirs, "%s: nothing written for 10030-1 holds the model opened meanwhile" % tag)
	if another:
		var said: String = _store.refused if what != "save" else " | ".join(heard)
		_ok(written.is_empty() and said.contains(ModelStore.ANOTHER_OPENED),
			"%s: nothing written, and said: \"%s\"" % [tag, said])
	else:
		_ok(written.contains("10030"), "%s: done before the other model came, 10030-1 written" % tag)
	if what == "save":
		_ok(_store.title != name, "%s: the model on the baseplate keeps its own name (\"%s\")" % [tag,
			_store.title])
	await _frames(10)


## A model of the app's own of 600 parts with no steps, its build order worked
## out over frames (ModelStore.paces), saved (save_as_paced), and a frame on
## a new model begun ("new") or another opened ("open"), judged as
## [method _case_during] judges.
func _case_paced_during(how: String) -> void:
	var tag: String = "paced_during %s" % how
	print("\n%s: 600 parts of the app's own, no steps, %s while its order is worked out" % [tag,
		"a new model begun" if how == "new" else "another model opened"])
	_main.call("clear_model")
	await _frames(3)
	for n: int in 600:
		_world.add_brick("3001", 4, Transform3D(Basis.IDENTITY, Vector3((n % 25) * 100.0, 0.0,
			(n / 25) * 60.0)))
	await _frames(5)
	if not _store.paces():
		_ok(false, "%s: the model is one paced here (%d parts)" % [tag, _world.brick_count()])
		return
	var name: String = "wt2 paced %s" % how
	var job: Working.Job = Working.begin("Saving", 0, true)
	var press: int = _store.model_now()
	var result: Array = [null, press]
	var run: Callable = func() -> void:
		var got: bool = await _store.save_as_paced(name, job)
		result[1] = _store.model_now()
		result[0] = got
	run.call()
	await process_frame
	var still: bool = result[0] == null
	if how == "open":
		_main.call("_open", ProjectSettings.globalize_path(_paths["other"]))
	else:
		_main.call("clear_model")
		_world.add_brick("3001", 1, Transform3D.IDENTITY)
	for _n: int in 20000:
		if result[0] != null:
			break
		await process_frame
	job.end()
	for _n: int in 2000:
		if how == "new" or (_world.brick_count() == 2 and not _store.laying):
			break
		await process_frame
	await _frames(10)
	var written: String = _text_of(ModelStore.saved_path(name))
	var another: bool = int(result[1]) != press
	print("  %s: still planning then: %s; returned %s with %s on the baseplate; refused \"%s\"; %d lines written"
		% [tag, still, str(result[0]), "another model" if another else "the 600", _store.refused,
			written.count("\n")])
	if how == "new":
		_ok(still and another, "%s: the save was still being worked out when the new model was begun" % tag)
	if another:
		_ok(result[0] == false and written.is_empty() and _store.refused == ModelStore.ANOTHER_OPENED,
			"%s: nothing written, and said: \"%s\"" % [tag, _store.refused])
	else:
		_ok(written.count("3001.dat") == 600, "%s: done before the other model came, the 600 written" % tag)
	_ok(not written.contains("wt2_other"), "%s: nothing of the other model written under its name" % tag)
	_ok(_store.title != name, "%s: the model on the baseplate keeps its own name (\"%s\")" % [tag,
		_store.title])


# -- time ---------------------------------------------------------------------------


## 10030-1, one part moved: a one-frame save through the whole write
## (save_model), the text alone (to_text) and the autosave's text (written
## over frames), each with the file's lines kept and plain, in turn, five
## rounds, each in the other order.
func _case_time() -> void:
	print("\ntime: 10030-1, one part moved, saved through the whole write")
	await _open(SET)
	var brick: BrickWorld.Brick = _placed_once()
	if brick == null or not await _moved(brick):
		_ok(false, "time: a part moved")
		return
	var at: String = ProjectSettings.globalize_path(PROBE_DIR + "wt2-time.mpd")
	var took: Dictionary = {"kept": [], "plain": []}
	var frames: Dictionary = {"kept": [], "plain": []}
	var written: Dictionary = {"kept": [], "plain": []}
	var texts: Dictionary = {}
	for round: int in 5:
		# Each round in the other order, so neither always goes first.
		for kept: bool in ([true, false] if round % 2 == 0 else [false, true]):
			var how: String = "kept" if kept else "plain"
			ModelStore.write_over_files = false
			ModelStore.keep_file_lines = kept
			# The text alone, with no file written.
			var wrote: int = Time.get_ticks_usec()
			_store.to_text(_store.title, true)
			(written[how] as Array).append((Time.get_ticks_usec() - wrote) / 1000)
			await _frames(3)
			var began: int = Time.get_ticks_usec()
			var saved: bool = bool(_main.call("save_model", at))
			(took[how] as Array).append((Time.get_ticks_usec() - began) / 1000)
			texts[how] = _text_of(at)
			_ok(saved, "time %s: saved" % how)
			await _frames(5)
			# The autosave's way: over frames, the longest of them.
			var made: Array = []
			var ticks: Array = [Time.get_ticks_usec()]
			var tick: Callable = func() -> void: ticks.append(Time.get_ticks_usec())
			process_frame.connect(tick)
			await _store._text_into(made, _store.title, false, {}, FramePace.new())
			process_frame.disconnect(tick)
			ticks.append(Time.get_ticks_usec())
			var longest: int = 0
			for n: int in range(1, ticks.size()):
				longest = maxi(longest, int(ticks[n]) - int(ticks[n - 1]))
			(frames[how] as Array).append(longest / 1000)
			ModelStore.write_over_files = true
			ModelStore.keep_file_lines = true
			await _frames(5)
	var original: String = _text_of(SET)
	for pair: Array in [["save_model in one frame", took], ["to_text alone", written],
			["the autosave's longest frame", frames]]:
		var times: Dictionary = pair[1]
		print("  time: %s, kept %s ms (least %d), plain %s ms (least %d)" % [pair[0], str(times["kept"]),
			(times["kept"] as Array).min(), str(times["plain"]), (times["plain"] as Array).min()])
	for how: String in ["kept", "plain"]:
		_kept("time-%s.mpd" % how, texts[how])
		var diff: Dictionary = _line_diff(original, texts[how])
		print("  time %s: %d of the file's %d lines gone, %d new" % [how, (diff["lost"] as Array).size(),
			original.count("\n"), (diff["new"] as Array).size()])
	var source: SourceFile = _store.get("_source")
	print("  time: kept_why \"%s\"" % (source.kept_why if source != null else "(no source)"))
