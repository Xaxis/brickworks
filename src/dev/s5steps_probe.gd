## Step edits at a model's end, and round LPub's groups, on real files, saved
## and opened again (s5review's, kept by s5fix 2026-11-18). Each file opened,
## then for the model and its sub-model of the most steps: a part put on top
## after the last step (addend), and closed into a step (addend_close); the
## last two steps merged; the last taken out; the last split; the one before
## it put later; a part moved to the last; the first taken out. Patched, then
## written whole. Each is saved, opened again, and its pages read: number,
## section, the turn in force, the look (its turn's own fields left to the
## turn in force), parts. A row is ok when the pages read the same, the save
## saves to itself, and the pages are as many more or fewer as the edit says.
## A part put on top writes no line of the author's again: what the save put
## in taken out, the rest is the file byte for byte (s5review F2: 5540-1's
## "0 STEP" before its own "0 ROTSTEP END" was written "0 ROTSTEP END").
##
##   godot --headless --path . --script src/dev/s5steps_probe.gd
##   S5_ALL=1      the three big files too (orthanc, 10179, 8063): ~15 min more
##   S5_ONLY=a,b   files whose name is one of them
##   S5_OPS=a,b    those edits alone
##   S5_EVERY=1    also merge and remove at every step of a file with LPub groups
##   S5_SAVE=DIR   each save written there, named the same in any snapshot
##
## Exits 1 when a row fails that KNOWN does not hold: the faults base has
## (pre261 e04dbde4b, the same probe), each owned by a unit to come. A
## known row is said "known" with why, never FAIL, as hpreview says its
## own: a release counts every FAIL line as a failure whatever the exit,
## and held rel-m312 on this probe's known rows (m312fix, 2026-11-18).
extends "res://src/dev/keep_text_probe.gd"

const FILES: Array = [
	["srmetas", "/mnt/Projects/brickworks/bench/results/streview-2026-11-15/srmetas.ldr"],
	["358", "res://vendor/omr/files/358-1.mpd"],
	["5540", "res://vendor/omr/files/5540-1_Plane.mpd"],
]
const BIG: Array = [
	["orthanc", "res://models/orthanc.ldr"],
	["10179", "res://vendor/omr/files/10179-1.mpd"],
	["8063", "res://vendor/omr/files/8063-1.mpd"],
]
## Rows that fail on base too (pre261 e04dbde4b, this probe, S5_ALL=1
## S5_EVERY=1, s5fix 2026-11-18), and what fails. smalls5 mended 358's and
## 10179's addend, and no row that passes on base fails after it.
const TURN_LATER := "a last step put later, past the author's turn end, opens unturned: live already, no unit's yet"
const COUNT := "pages reopen as shown and save to themselves; a main model whose last steps are its sub-models' is not one page more or fewer, as the probe counts"
const NO_PART := "the main model has no part of its own to put on top: none is put"
const KNOWN: Dictionary = {
	"5540 s0 later_last patch": TURN_LATER, "5540 s0 later_last whole": TURN_LATER,
	"orthanc s0 addend patch": NO_PART, "orthanc s0 addend whole": NO_PART,
	"orthanc s0 addend_close patch": NO_PART, "orthanc s0 addend_close whole": NO_PART,
	"orthanc s0 merge_last patch": COUNT, "orthanc s0 merge_last whole": COUNT,
	"orthanc s0 remove_last patch": COUNT, "orthanc s0 remove_last whole": COUNT,
	"orthanc s0 remove_first patch": COUNT, "orthanc s0 remove_first whole": COUNT,
	"10179 s0 merge_last patch": COUNT, "10179 s0 merge_last whole": COUNT,
	"10179 s0 remove_last patch": COUNT, "10179 s0 remove_last whole": COUNT,
}
var _s5_save: String = ""
var _s5_rows: Array = []
var _s5_bad: int = 0


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_s5_save = OS.get_environment("S5_SAVE")
	if not _s5_save.is_empty():
		DirAccess.make_dir_recursive_absolute(_s5_save)
	var only: PackedStringArray = OS.get_environment("S5_ONLY").split(",", false)
	var files: Array = FILES + (BIG if OS.get_environment("S5_ALL") == "1" or not only.is_empty() else [])
	for entry: Array in files:
		if not only.is_empty() and not str(entry[0]) in only:
			continue
		if not FileAccess.file_exists(str(entry[1])):
			# srmetas is streview's file, in the main checkout's results.
			print("\n== %s: not here (%s), left out" % [entry[0], entry[1]])
			continue
		await _s5_file(str(entry[0]), FileAccess.get_file_as_string(str(entry[1])))
	ModelStore.patch_files = true
	print("\ns5steps rows:")
	var new_faults: PackedStringArray = PackedStringArray()
	for row: Array in _s5_rows:
		var mark: String = row[0]
		var label: String = row[1]
		print("  %s %s" % [mark, label])
		if mark == "FAIL":
			new_faults.append(label)
		elif mark == "ok  " and KNOWN.has(label):
			print("    (known, and passes now: %s)" % KNOWN[label])
	print("s5steps: %d unlike or lost, %d not known: %s" % [_s5_bad, new_faults.size(), ", ".join(new_faults)])
	_world.clear()
	await _frames(4)
	quit(1 if not new_faults.is_empty() else 0)


func _s5_file(name: String, text: String) -> void:
	print("\n== %s (%d lines)" % [name, text.split("\n").size()])
	ModelStore.patch_files = true
	var t0: int = Time.get_ticks_msec()
	await _open(text, name)
	print("  opened in %d ms" % (Time.get_ticks_msec() - t0))
	var unedited: String = _store.saved_text()
	_s5_keep(name, "unedited", "", unedited)
	var sections: Array = [""]
	var best: String = ""
	var most: int = 0
	for path: String in AuthorSteps.paths_in(_world, _store.scenery).keys():
		if path.is_empty() or AuthorSteps.in_parent(_world, path) or AuthorSteps.home(_world, path) != path:
			continue
		var n: int = _ops_steps(path).size()
		if n > most:
			most = n
			best = path
	if most >= 3:
		sections.append(best)
	print("  sections: %s (%d steps), %s (%d steps)" % ["the model", _ops_steps("").size(), best, most])
	var ops: Array = ["addend", "addend_close", "merge_last", "remove_last", "split_last", "later_last",
		"to_last", "remove_first"]
	var only_ops: PackedStringArray = OS.get_environment("S5_OPS").split(",", false)
	for whole: bool in [false, true]:
		for s: int in sections.size():
			for op: String in ops:
				if not only_ops.is_empty() and not op in only_ops:
					continue
				if s > 0 and op.begins_with("addend"):
					continue
				await _s5_one(name, text, str(sections[s]), "s%d" % s, op, -1, whole)
	if OS.get_environment("S5_EVERY") == "1" and text.contains("MULTI_STEP"):
		for s: int in sections.size():
			await _open(text, name)
			var count: int = _ops_steps(str(sections[s])).size()
			for k: int in mini(count - 1, 40):
				for op: String in ["merge_at", "remove_at"]:
					await _s5_one(name, text, str(sections[s]), "s%d" % s, op, k, false)


func _s5_one(name: String, text: String, section: String, tag: String, op: String, k: int,
		whole: bool) -> void:
	ModelStore.patch_files = not whole
	await _open(text, name)
	var steps: Array = _ops_steps(section)
	var n: int = steps.size()
	var label: String = "%s %s %s%s %s" % [name, tag, op, "" if k < 0 else str(k), "whole" if whole else "patch"]
	if n < 3:
		print("  --  %s: %d steps" % [label, n])
		return
	var pages_before: int = _s5_pages().size()
	var said: String = ""
	var expect: int = 0
	var last: Array = steps[n - 1][1]
	var top: int = -1
	for j: int in range(n - 1, -1, -1):
		if not (steps[j][1] as Array).is_empty():
			top = int((steps[j][1] as Array)[-1])
			break
	match op:
		"addend", "addend_close":
			_select_only([top])
			(_main.get("_verbs") as EditVerbs).duplicate_selection(false)
			var put: int = await _put_down(true)
			await _frames(4)
			var brick: BrickWorld.Brick = _world.get_brick(put)
			said = "put #%d step %d" % [put, brick.step if brick != null else -9]
			if op == "addend_close":
				said += "; " + _shell.change_steps("close", [], null)
			expect = 1
		"merge_last":
			said = _shell.change_steps("merge", [], _ops_step(section, steps[n - 2]))
			expect = -1
		"remove_last":
			said = _shell.change_steps("delete", [], _ops_step(section, steps[n - 1]))
			expect = -1
		"remove_first":
			said = _shell.change_steps("delete", [], _ops_step(section, steps[0]))
			expect = -1
		"split_last":
			if last.size() < 2:
				print("  --  %s: the last step has one part" % label)
				return
			said = _shell.change_steps("new", last.slice(last.size() / 2), _ops_step(section, steps[n - 1]))
			expect = 1
		"later_last":
			said = _shell.change_steps("later", [], _ops_step(section, steps[n - 2]))
		"to_last":
			if (steps[n - 3][1] as Array).is_empty():
				print("  --  %s: step n-3 has no part of its own" % label)
				return
			said = _shell.change_steps("to", [(steps[n - 3][1] as Array)[0]], _ops_step(section, steps[n - 1]))
			expect = -1 if (steps[n - 3][1] as Array).size() == 1 else 0
		"merge_at":
			said = _shell.change_steps("merge", [], _ops_step(section, steps[k]))
			expect = -1
		"remove_at":
			said = _shell.change_steps("delete", [], _ops_step(section, steps[k]))
			expect = -1
	await _frames(4)
	var shown: Array = _s5_pages()
	var t0: int = Time.get_ticks_msec()
	var saved: String = _store.saved_text()
	var took: int = Time.get_ticks_msec() - t0
	var wrote: String = str(_store.get("last_whole"))
	_s5_keep(name, "%s_%s%s" % [tag, op, "" if k < 0 else "%02d" % k], "whole" if whole else "patch", saved)
	await _open(saved, name)
	var again: Array = _s5_pages()
	var resaved: String = _store.saved_text()
	var unlike: String = _s5_unlike(shown, again)
	if unlike.is_empty() and op.begins_with("addend"):
		unlike = _s5_touched(text, saved, name)
	var counted: bool = op.ends_with("_at") or op == "to_last" or shown.size() == pages_before + expect
	var ok: bool = unlike.is_empty() and resaved == saved and counted
	var mark: String = "ok  " if ok else "known" if KNOWN.has(label) else "FAIL"
	print("  %s %s (\"%s\"): %s, saved in %d ms; pages %d -> %d shown, %d reopened%s; saves to itself %s%s%s" % [
		mark, label, said.get_slice("\n", 0).left(70),
		"patched" if wrote.is_empty() else "whole: " + wrote.left(50), took, pages_before, shown.size(),
		again.size(), "" if counted else " (expected %+d)" % expect, resaved == saved,
		"" if unlike.is_empty() else "\n      UNLIKE " + unlike,
		"" if mark != "known" else "\n      (known: %s)" % KNOWN[label]])
	if not ok:
		_s5_bad += 1
	_s5_rows.append([mark, label])


func _s5_keep(name: String, what: String, mode: String, text: String) -> void:
	if _s5_save.is_empty():
		return
	var file := FileAccess.open(_s5_save.path_join("%s__%s%s.ldr" % [name, what,
		"" if mode.is_empty() else "__" + mode]), FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Each page: number, section, step, turn, look, parts.
func _s5_pages() -> Array:
	var lift: Vector3 = _store.lift()
	var out: Array = []
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		var parts: Array = []
		for id: int in step.brick_ids:
			var brick: BrickWorld.Brick = _world.get_brick(id)
			if brick == null:
				continue
			var o: Vector3 = brick.transform.origin - lift
			parts.append("%s/%d@%.1f,%.1f,%.1f" % [brick.part_id, brick.color_code, o.x, o.y, o.z])
		parts.sort()
		var turn: Dictionary = BookletLooks.turn_at(_world, step.authored_in, step.authored_step)
		var look: Dictionary = BookletLooks.of(_world, step.authored_in, step.authored_step).duplicate(true)
		# A turn's own fields, its line among them: the turn in force is
		# the page's. A part after the author's "0 ROTSTEP END" is in the
		# step that line ended the turn for, with the line in its look.
		look.erase("turn")
		look.erase("how")
		look.erase("line")
		out.append("#%d sec'%s' turn[%s] look%s x%d [%s]" % [step.number, step.section,
			"-" if turn.is_empty() else "%s %s" % [turn.get("how", "REL"), str(turn["turn"])],
			JSON.stringify(look, "", true), step.times, " ".join(parts)])
	return out


## "" when [param saved] is [param text] with lines put in alone (a part's,
## a STEP, the app's title) and the name the probe opened it by
## ([param name]) in its head; else the first of the file's lines it wrote
## again or left out.
static func _s5_touched(text: String, saved: String, name: String) -> String:
	var was: PackedStringArray = text.replace("\r", "").split("\n")
	var now: PackedStringArray = saved.replace("\r", "").split("\n")
	var i: int = 0
	for line: String in now:
		if i < was.size() and line == was[i]:
			i += 1
		elif i < 3 and line == "0 " + name:
			i += 1
		elif not (line.begins_with("1 ") or line == "0 STEP" or line.begins_with("0 !BRICKWORKS TITLE ")):
			return "line %d of the file, \"%s\", written \"%s\"" % [i + 1, was[i] if i < was.size() else "", line]
	return "" if i == was.size() else "line %d of the file, \"%s\", left out" % [i + 1, was[i]]


static func _s5_unlike(a: Array, b: Array) -> String:
	if a == b:
		return ""
	for n: int in maxi(a.size(), b.size()):
		var x: String = str(a[n]) if n < a.size() else "(none)"
		var y: String = str(b[n]) if n < b.size() else "(none)"
		if x != y:
			return "%d pages vs %d; first unlike, page %d:\n        shown:  %s\n        reopen: %s" % [
				a.size(), b.size(), n + 1, x.left(300), y.left(300)]
	return "?"
