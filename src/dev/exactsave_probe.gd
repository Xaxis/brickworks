## exactsave: a saved model reopens exactly. A whole-file write keeps each
## copy's frame as the file had it (the matrix read, never a fit of its parts
## and never a mirror the file did not have), and a paste of copies of the
## file's own sub-models is a patch: the file's lines byte for byte, and one
## line placing each copy put down.
##
## 1. 10030-1 written whole, untouched (ModelStore._writing_whole): reopened,
##    every part where it was. Up to exactsave each copy but the first of a
##    sub-model was written by an orthonormal fit of its parts, and 10030's
##    matrices are not orthonormal (0.951/0.308): parts came back up to
##    0.44 LDU off, mirror-symmetric pins and plates in their mirror image.
## 2. All of 10030-1 copied and pasted at (1200, 0, 0), saved: the file's
##    lines byte for byte, one new line for each copy put down; reopened,
##    every one of the 6,074 parts where it was (appfix FINDINGS S1).
## 3. The same paste then a part of the original moved, one of a sub-model
##    the file places once and the paste places again: reopened, every part
##    where it was (a patch, the moved part's line alone gone; or whole).
## 4. Twelve real sets with rounded matrices (ODD_SETS): each written whole,
##    every part where it was; and one part moved and saved, its line the one
##    changed and only in its place.
## 5. A sub-model a real set places once, its parts turned off square,
##    moved and turned whole by 30 degrees: a patch rewriting the one line
##    placing it (TURN_SETS, the first with room).
##
##   godot --headless --path . --script src/dev/exactsave_probe.gd -- [--keep=DIR] [--cases=1,5]
##
## --keep=DIR copies each saved file there, for tools that read them after;
## --cases= runs those cases alone.
extends "res://src/dev/pastereview_probe.gd"

const SET := "res://vendor/omr/files/10030-1.mpd"
## Real sets whose matrices are most often rounded off square (the share of
## their placing lines not of 0 and 1), many with mirrored sub-models: 8841-1
## places 2,483 of its 2,505 references mirrored.
const ODD_SETS := ["8841-1_Combination-with-8700.mpd", "8012-1.mpd",
	"8855-1_Combination-with-8700.mpd", "8273-1_Utility-Cargo-Truck.mpd", "42124-1.mpd",
	"6285-1.mpd", "7750-1.mpd", "4005-1.mpd", "6685-1.mpd", "920-2.mpd", "41497-1.mpd",
	"42116-1.mpd"]
var _keep: String = ""


func _run() -> void:
	await process_frame
	var cases: String = "1,2,3,4,5"
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
	if "1" in asked:
		await _case_whole()
	if "2" in asked:
		await _case_paste()
	if "3" in asked:
		await _case_paste_and_move()
	if "4" in asked:
		for set: String in ODD_SETS:
			await _case_odd(set)
	if "5" in asked:
		await _case_turned_whole()
	_forget(PROBE_DIR)
	print("\nexactsave_probe: %d failed, %d notes" % [_failures, _notes])
	quit(1 if _failures > 0 else 0)


## The file as text, its lines.
static func _text_of(path: String) -> String:
	return FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))


func _kept(name: String, text: String) -> void:
	if not _keep.is_empty():
		_write(_keep.path_join(name), text)


## The lines of [param was] that [param now] has not got, and the lines
## [param now] has that [param was] has not, as multisets: {"lost", "new"}.
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
			lost.append(line)
	return {"lost": lost, "new": fresh}


## Whether [param now] holds [param was]'s lines in their order, byte for
## byte, with only lines put between them: the lines put in, or [] when a
## line of [param was] is missing or changed.
static func _kept_in_order(was: String, now: String) -> Variant:
	var a: PackedStringArray = was.split("\n")
	var b: PackedStringArray = now.split("\n")
	var put: Array = []
	var k: int = 0
	for line: String in b:
		if k < a.size() and line == a[k]:
			k += 1
		else:
			put.append(line)
	# A file that ended with a line break has an empty last "line".
	if k < a.size() and not (k == a.size() - 1 and a[k].is_empty()):
		return null
	return put


func _case_whole() -> void:
	print("\n1. 10030-1 written whole, untouched")
	await _open(SET)
	var before: Array = _records_all()
	_store.set("_writing_whole", true)
	var text: String = _store.to_text(_store.title)
	_store.set("_writing_whole", false)
	var at: String = ProjectSettings.globalize_path(PROBE_DIR + "10030-whole.mpd")
	_write(at, text)
	_kept("10030-whole.mpd", text)
	await _open(at)
	var back: Array = _records_all()
	_ok(_part_colours(before) == _part_colours(back), "whole: reopened %d parts against %d; part:colour %s"
		% [back.size(), before.size(), _diff_counts(_part_colours(before), _part_colours(back))])
	_exact("whole: reopened, each part where it was", before, back)


func _case_paste() -> void:
	print("\n2. 10030-1 copied whole and pasted at (1200, 0, 0), saved")
	await _open(SET)
	var original: String = _text_of(SET)
	var ids: Array = []
	for brick: BrickWorld.Brick in _shown():
		ids.append(brick.id)
	_select(ids)
	_verbs.copy()
	_builder.clear_selection()
	_ok(_verbs.paste() == ids.size(), "paste() holds all %d" % ids.size())
	var put: Dictionary = await _put([Vector3(1200, 0, 0)])
	_ok((put["ids"] as Array).size() == ids.size(), "put down %d at %s" % [(put["ids"] as Array).size(), put["spot"]])
	var tops: Dictionary = {}
	for brick: BrickWorld.Brick in _shown():
		var top: String = Assemblies.segments(brick.unit)[0] if not brick.unit.is_empty() else "(main)"
		tops[top] = int(tops.get(top, 0)) + 1
	print("    copies at the top now: %s; their steps %s" % [tops, _world.unit_steps.keys().filter(
		func(path: String) -> bool: return not path.contains("/")).map(
		func(path: String) -> String: return "%s=%d" % [path, int(_world.unit_steps[path])])])
	var after: Array = _records_all()
	# Written whole too, as a save the patch cannot make writes it: each
	# copy put down laid on the file's by its parts, never mirrored.
	_store.set("_writing_whole", true)
	var whole: String = _store.to_text(_store.title)
	_store.set("_writing_whole", false)
	var whole_at: String = ProjectSettings.globalize_path(PROBE_DIR + "10030-paste-whole.mpd")
	_write(whole_at, whole)
	_kept("10030-paste-whole.mpd", whole)
	var at: String = ProjectSettings.globalize_path(PROBE_DIR + "10030-paste.mpd")
	_ok(bool(_main.call("save_model", at)), "saved")
	print("    written whole because: %s" % (_store.last_whole if not _store.last_whole.is_empty() else "(a patch)"))
	var saved: String = _text_of(at)
	_kept("10030-paste.mpd", saved)
	var put_in: Variant = _kept_in_order(original, saved)
	_ok(put_in != null, "every line of the file kept, byte for byte and in order")
	if put_in != null:
		var placing: Array = (put_in as Array).filter(func(line: String) -> bool:
			return line.strip_edges().begins_with("1 "))
		var other: Array = (put_in as Array).filter(func(line: String) -> bool:
			return not line.strip_edges().begins_with("1 ") and not line.strip_edges().begins_with("0 !BRICKWORKS"))
		_ok(placing.size() == 3 and other.size() <= 2,
			"put in: %d lines placing a copy, %d other (%s)" % [placing.size(), other.size(),
				" | ".join(PackedStringArray((put_in as Array).slice(0, 8)))])
	else:
		var diff: Dictionary = _line_diff(original, saved)
		print("    %d of the file's lines gone, %d new" % [(diff["lost"] as Array).size(), (diff["new"] as Array).size()])
	await _open(at)
	var back: Array = _records_all()
	_ok(_part_colours(after) == _part_colours(back), "reopened %d parts against %d; part:colour %s"
		% [back.size(), after.size(), _diff_counts(_part_colours(after), _part_colours(back))])
	_exact("paste: reopened, each part where it was", after, back)
	await _open(whole_at)
	var copies: int = _text_of(whole_at).count("\n0 FILE ") + (1 if whole.begins_with("0 FILE ") else 0)
	_exact("paste written whole: reopened, each part where it was (%d FILE sections, the set has %d)"
		% [copies, original.count("\n0 FILE ") + (1 if original.begins_with("0 FILE ") else 0)],
		after, _records_all())


func _case_paste_and_move() -> void:
	print("\n3. the same paste, and one part of the original moved")
	await _open(SET)
	var original: String = _text_of(SET)
	# A part of a sub-model the file places once: after the paste the copy
	# put down places it too, so its line is no longer the original's alone.
	var chosen: BrickWorld.Brick = _placed_once()
	var ids: Array = []
	for brick: BrickWorld.Brick in _shown():
		ids.append(brick.id)
	_select(ids)
	_verbs.copy()
	_builder.clear_selection()
	_verbs.paste()
	await _put([Vector3(1200, 0, 0)])
	var moved: bool = chosen != null and await _moved(chosen)
	_ok(moved, "%s of %s moved by a typed amount" % [chosen.part_id if chosen != null else "(none)",
		chosen.unit if chosen != null else ""])
	var after: Array = _records_all()
	var at: String = ProjectSettings.globalize_path(PROBE_DIR + "10030-paste-move.mpd")
	_ok(bool(_main.call("save_model", at)), "saved")
	print("    written whole because: %s" % (_store.last_whole if not _store.last_whole.is_empty() else "(a patch)"))
	var saved: String = _text_of(at)
	_kept("10030-paste-move.mpd", saved)
	var diff: Dictionary = _line_diff(original, saved)
	# A patch changes the moved part's line alone; written whole, every
	# part is still where it was, which is what is asked below.
	if _store.last_whole.is_empty():
		_ok((diff["lost"] as Array).size() <= 1, "a patch: the file's lines gone: %d (%s)"
			% [(diff["lost"] as Array).size(), " | ".join(PackedStringArray((diff["lost"] as Array).slice(0, 4)))])
	else:
		_note("written whole: %s" % _store.last_whole)
	await _open(at)
	_exact("paste and move: reopened, each part where it was", after, _records_all())


## 4. A real set with rounded matrices: written whole, every part where it
## was; then one part of a sub-model placed once moved by a typed amount and
## saved, the one line of it changed, only its place, and every part where it
## was when reopened.
func _case_odd(name: String) -> void:
	print("\n4. %s" % name)
	var path: String = "res://vendor/omr/files/" + name
	await _open(path)
	var before: Array = _records_all()
	_store.set("_writing_whole", true)
	var text: String = _store.to_text(_store.title)
	_store.set("_writing_whole", false)
	var whole_at: String = ProjectSettings.globalize_path(PROBE_DIR + "odd-whole.mpd")
	_write(whole_at, text)
	_kept(name.get_basename() + "-whole.mpd", text)
	await _open(whole_at)
	_exact("%s written whole" % name, before, _records_all())

	await _open(path)
	var original: String = _text_of(path)
	var chosen: BrickWorld.Brick = _placed_once()
	if chosen == null:
		_note("%s: no part in a sub-model placed once" % name)
		return
	if not await _moved(chosen):
		_note("%s: the part chosen (%s) has no room to move" % [name, chosen.part_id])
		return
	var after: Array = _records_all()
	var at: String = ProjectSettings.globalize_path(PROBE_DIR + "odd-moved.mpd")
	_ok(bool(_main.call("save_model", at)), "%s: saved, %s moved (%s, %s)" % [name, chosen.part_id,
		"square" if _square(chosen.transform.basis) else "turned off square", chosen.unit])
	var saved: String = _text_of(at)
	_kept(name.get_basename() + "-moved.mpd", saved)
	var diff: Dictionary = _line_diff(original, saved)
	var lost: Array = diff["lost"]
	var fresh: Array = (diff["new"] as Array).filter(func(line: String) -> bool:
		return not line.strip_edges().begins_with("0 !BRICKWORKS"))
	var only_place: bool = lost.size() == 1 and fresh.size() == 1
	if only_place:
		var was: PackedStringArray = (lost[0] as String).strip_edges().split(" ", false)
		var now: PackedStringArray = (fresh[0] as String).strip_edges().split(" ", false)
		only_place = was.size() == now.size() and was.size() >= 15
		for k: int in was.size():
			if only_place and (k < 2 or k > 4) and was[k] != now[k]:
				only_place = false
	_ok(only_place and _store.last_whole.is_empty(), "%s: one line changed, its place alone: %d gone, %d new%s (%s -> %s)"
		% [name, lost.size(), fresh.size(), "" if _store.last_whole.is_empty() else ", written whole: " + _store.last_whole,
			" | ".join(PackedStringArray(lost.slice(0, 2))), " | ".join(PackedStringArray(fresh.slice(0, 2)))])
	await _open(at)
	_exact("%s: moved, saved, reopened" % name, after, _records_all())


## 5. A sub-model a real set places once, holding parts turned off square,
## moved and then turned whole by 30 degrees about the up axis
## (Builder.turn_selection_by): every part of it turned by the one turn, so
## the save is a patch rewriting the one line that places it and no line of
## its section. Each part squared after the turn, each moved by its own turn
## and every one of its lines was rewritten. The first of TURN_SETS' copies
## placed once that has room for the move and the turn.
const TURN_SETS := ["6285-1.mpd", "6685-1.mpd", "4005-1.mpd", "7750-1.mpd", "920-2.mpd", "10030-1.mpd"]


func _case_turned_whole() -> void:
	print("\n5. a sub-model placed once, moved and turned whole by 30 degrees, saved")
	for name: String in TURN_SETS:
		var path: String = "res://vendor/omr/files/" + name
		await _open(path)
		# Top-level copies, each of a definition placed once, with a part
		# turned off square: top -> [ids].
		var tops: Dictionary = {}
		var kinds: Dictionary = {}
		var odd: Dictionary = {}
		for brick: BrickWorld.Brick in _shown():
			if brick.unit.is_empty():
				continue
			for segment: String in Assemblies.segments(brick.unit):
				kinds[Assemblies.definition(segment)] = (kinds.get(Assemblies.definition(segment), {}) as Dictionary) \
					.merged({segment: true})
			var top: String = Assemblies.segments(brick.unit)[0]
			if not tops.has(top):
				tops[top] = []
			(tops[top] as Array).append(brick.id)
			if not _square(brick.transform.basis):
				odd[top] = true
		for top: String in tops:
			if not odd.has(top) or (kinds[Assemblies.definition(top)] as Dictionary).size() != 1 \
					or (tops[top] as Array).size() < 3 or (tops[top] as Array).size() > 200:
				continue
			if await _turned_whole(name, path, top, tops[top]):
				return
	_ok(false, "no sub-model placed once in %s could be moved and turned" % [TURN_SETS])


## [param top]'s parts [param ids], of the set [param name] at [param
## path], moved and turned whole, saved and reopened: whether it turned
## (else the set is opened again and nothing is asked).
func _turned_whole(name: String, path: String, top: String, ids: Array) -> bool:
	var original: String = _text_of(path)
	_select(ids)
	var turned: int = 0
	for by: Vector3 in [Vector3(0, -400, 0), Vector3(0, 400, 0), Vector3(800, 0, 0), Vector3(0, 0, 800)]:
		if _builder.move_selection_by(by) == 0:
			continue
		for degrees: float in [30.0, -30.0]:
			turned = _builder.turn_selection_by(degrees)
			if turned > 0:
				break
		if turned > 0:
			break
	_builder.clear_selection()
	await _frames(3)
	if turned == 0:
		print("    %s %s (%d parts): no room to move and turn it" % [name, top, ids.size()])
		await _open(path)
		return false
	_ok(turned == ids.size(), "%s: %s moved and turned, %d of its %d parts" % [name, top, turned, ids.size()])
	var after: Array = _records_all()
	var at: String = ProjectSettings.globalize_path(PROBE_DIR + "turned.mpd")
	_ok(bool(_main.call("save_model", at)), "saved")
	var saved: String = _text_of(at)
	_kept(name.get_basename() + "-turned.mpd", saved)
	var diff: Dictionary = _line_diff(original, saved)
	var fresh: Array = (diff["new"] as Array).filter(func(line: String) -> bool:
		return not line.strip_edges().begins_with("0 !BRICKWORKS"))
	_ok(_store.last_whole.is_empty() and (diff["lost"] as Array).size() == 1 and fresh.size() == 1,
		"a patch, the line placing it alone changed: %d gone, %d new%s (%s -> %s)" % [
			(diff["lost"] as Array).size(), fresh.size(),
			"" if _store.last_whole.is_empty() else ", written whole: " + _store.last_whole,
			" | ".join(PackedStringArray((diff["lost"] as Array).slice(0, 2))),
			" | ".join(PackedStringArray(fresh.slice(0, 2)))])
	await _open(at)
	_exact("turned whole: reopened", after, _records_all())
	return true


## A part the file has, of a sub-model placed once (or the model's own), one
## turned off square where there is one; null where none is.
func _placed_once() -> BrickWorld.Brick:
	var units_of: Dictionary = {}
	for brick: BrickWorld.Brick in _shown():
		var leaf: String = Assemblies.definition(Assemblies.leaf(brick.unit)) if not brick.unit.is_empty() else ""
		if not units_of.has(leaf):
			units_of[leaf] = {}
		(units_of[leaf] as Dictionary)[brick.unit] = true
	var chosen: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _shown():
		var leaf: String = Assemblies.definition(Assemblies.leaf(brick.unit)) if not brick.unit.is_empty() else ""
		if brick.origin.is_empty() or (units_of[leaf] as Dictionary).size() != 1:
			continue
		if chosen == null:
			chosen = brick
		if not _square(brick.transform.basis):
			return brick
	return chosen


## [param brick] moved by a typed amount, as the properties' X, Y and Z
## move it, the first of a few ways it has room to go: whether it moved.
func _moved(brick: BrickWorld.Brick) -> bool:
	var moved: int = 0
	for by: Vector3 in [Vector3(0, -400, 0), Vector3(0, 400, 0), Vector3(400, 0, 0), Vector3(0, 0, 400),
			Vector3(-400, 0, 0), Vector3(0, -2000, 0)]:
		_select([brick.id])
		moved = _builder.move_selection_by(by)
		if moved > 0:
			break
	_builder.clear_selection()
	await _frames(3)
	return moved > 0


## Whether [param basis] turns by quarter turns alone: each element 0 or 1.
static func _square(basis: Basis) -> bool:
	for axis: int in 3:
		for k: int in 3:
			var v: float = absf(basis[axis][k])
			if v > 0.0001 and absf(v - 1.0) > 0.0001:
				return false
	return true


## Each part of [param a] where [param b] has one of its part and colour,
## within a hundredth of an LDU and a ten-thousandth of a turn, and none
## turned into its mirror image.
func _exact(said: String, a: Array, b: Array) -> void:
	var p: Dictionary = _pair(a, b, Vector3.ZERO)
	var mirrored: int = _mirrors(a, b)
	var bad: bool = int(p["unpaired_a"]) > 0 or int(p["unpaired_b"]) > 0 or int(p["over"]) > 0 or mirrored > 0
	_ok(not bad, "%s: %d against %d; unpaired %d/%d; most apart %.5f LDU, rotation element %.7f; %d pairs past 0.01 LDU or 0.0001; %d mirrored"
		% [said, a.size(), b.size(), int(p["unpaired_a"]), int(p["unpaired_b"]), float(p["origin"]),
			float(p["basis"]), int(p["over"]), mirrored])
	if int(p["over"]) > 0:
		print("        worst: %s" % p["worst"])


## How many parts of [param a] have, at their place in [param b], only a part
## of theirs whose turn is the mirror image of theirs: the nearest of its part
## and colour, its basis's determinant the other sign or its columns flipped.
func _mirrors(a: Array, b: Array) -> int:
	var buckets: Dictionary = {}
	for one: Dictionary in b:
		var key: String = "%s:%d" % [one["part"], int(one["color"])]
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(one)
	var out: int = 0
	for one: Dictionary in a:
		var at: Transform3D = one["at"]
		var best: Dictionary = {}
		var best_d: float = INF
		for other: Dictionary in buckets.get("%s:%d" % [one["part"], int(one["color"])], []):
			var d: float = at.origin.distance_to((other["at"] as Transform3D).origin)
			if d < best_d:
				best_d = d
				best = other
		if best.is_empty() or best_d > 0.5:
			continue
		var other_basis: Basis = (best["at"] as Transform3D).basis
		if signf(other_basis.determinant()) != signf(at.basis.determinant()):
			out += 1
			continue
		for axis: int in 3:
			if at.basis[axis].dot(other_basis[axis]) < -0.5:
				out += 1
				break
	return out
