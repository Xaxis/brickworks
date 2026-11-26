## pasteexact: a pasted model, saved and reopened three times, has every part
## exactly where it was put down, and a part nobody moved is written as it was
## read. Each case pastes, checks the paste against what was copied (each part
## moved by the one move, its turn the copied part's to the bit), saves,
## reopens, saves again and reopens, three times: every reopen has each part
## where the paste put it (within 0.002 LDU and 2e-6 a turn element, none
## mirrored), every placing line of the file opened is in the first save byte
## for byte, and the second and third saves are the first byte for byte.
##
## 1. All of 10030-1 (3,037 parts, 283 copies of 136 sub-models, matrices
##    rounded off square) pasted in the same tab at (1200, 0, 0). On live
##    (129a7c3ed) 76 parts came back up to 0.44 LDU off and some pins and
##    plates mirrored (appfix FINDINGS S1, pastereview case 3).
## 2. The same, pasted from another tab (Carry.whole_text, paste_from).
## 3. A mirrored copy of a sub-model, pasted. On pre261 (e9d973192) it and 4,
##    6 and 7 were written whole, which wrote the sections round them again
##    (0.951 as 0.9510001, 3023 as 3023b) though nobody had moved them.
## 4. A copy turned off square (0.951/0.309), holding a plain and a mirrored
##    copy of a sub-model of its own, pasted.
## 5. A part at 10,000 LDU and a copy turned 30 degrees beside it, pasted
##    beside them.
## 6. The whole fixture pasted, turned a quarter in hand first (R).
## 7. The turned copy duplicated beside itself (Edit › Duplicate, Ctrl+D).
## 8. The fixture put whole into another file (a file dragged in, the
##    session's open_model into=true).
## 9. Two of the three parts of a copy turned 30 degrees, pasted.
##
##   godot --headless --path . --script src/dev/pasteexact_probe.gd -- [--cases=1,3] [--keep=DIR]
##
## --keep=DIR copies each saved file there; --cases= runs those cases alone.
extends "res://src/dev/exactsave_probe.gd"

const FIXTURE := """0 FILE pe_main.ldr
0 pasteexact fixture
0 Name: pe_main.ldr
0 Author: pasteexact_probe
1 16 0 0 0 1 0 0 0 1 0 0 0 1 pe_plain.ldr
1 16 200 0 0 -1 0 0 0 1 0 0 0 1 pe_plain.ldr
1 16 0 0 300 0.951 0 0.309 0 1 0 -0.309 0 0.951 pe_turned.ldr
1 4 10000.37 0 -10000.5 1 0 0 0 1 0 0 0 1 3001.dat
1 16 10100.123 0 -9900.25 0.866 0 0.5 0 1 0 -0.5 0 0.866 pe_plain.ldr
0 NOFILE
0 FILE pe_plain.ldr
0 pe_plain
0 Name: pe_plain.ldr
0 Author: pasteexact_probe
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 10 -32 0 0.951 0 0.309 0 1 0 -0.309 0 0.951 3710.dat
1 14 -20 -56 10 0 0 1 0 1 0 -1 0 0 3040b.dat
0 NOFILE
0 FILE pe_turned.ldr
0 pe_turned
0 Name: pe_turned.ldr
0 Author: pasteexact_probe
1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -32 0 1 0 0 0 1 0 0 0 1 pe_inner.ldr
1 16 60 -32 0 -1 0 0 0 1 0 0 0 1 pe_inner.ldr
0 NOFILE
0 FILE pe_inner.ldr
0 pe_inner
0 Name: pe_inner.ldr
0 Author: pasteexact_probe
1 15 0 0 0 1 0 0 0 1 0 0 0 1 3023.dat
1 0 10 -8 0 0.951 0 0.309 0 1 0 -0.309 0 0.951 3040b.dat
0 NOFILE
"""
## Someone else's file of two parts, the fixture put into it whole (case 8).
const HOST := """0 pe_host
0 Name: pe_host.ldr
0 Author: pasteexact_probe
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 40 -24 0 0.951 0 0.309 0 1 0 -0.309 0 0.951 3710.dat
"""
## Within this of the paste's place a part is where it was put: single
## precision at 10,000 LDU is 0.001 apart, and a line says a place to 1/10,000.
const NEAR := 0.002
const TURN_NEAR := 0.000002


func _run() -> void:
	await process_frame
	var cases: String = "1,2,3,4,5,6,7,8,9"
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
	_write(ProjectSettings.globalize_path(PROBE_DIR + "pe_fixture.mpd"), FIXTURE)
	if "1" in asked:
		await _case_set(false)
	if "2" in asked:
		await _case_set(true)
	if "3" in asked:
		await _case_fixture("3. a mirrored copy pasted", "mirrored", _mirrored_copy, Vector3(0, 0, -400), 0)
	if "4" in asked:
		await _case_fixture("4. a copy turned off square, a mirrored copy inside it, pasted", "turned",
			_turned_copy, Vector3(0, 0, -600), 0)
	if "5" in asked:
		await _case_fixture("5. a part at 10,000 LDU and a copy turned 30 degrees beside it, pasted",
			"far", _far_parts, Vector3(10600, 0, 10000), 0)
	if "6" in asked:
		await _case_fixture("6. the whole fixture pasted, turned a quarter in hand", "quarter", _every_part,
			Vector3(0, 0, -1200), 1)
	if "7" in asked:
		await _case_duplicate()
	if "8" in asked:
		await _case_put_in()
	if "9" in asked:
		await _case_fixture("9. two of the three parts of a copy turned 30 degrees, pasted", "some", _some_parts,
			Vector3(10600, 0, 10400), 0)
	_forget(PROBE_DIR)
	print("\npasteexact_probe: %d failed, %d notes" % [_failures, _notes])
	quit(1 if _failures > 0 else 0)


# -- the cases ------------------------------------------------------------------


func _case_set(other_tab: bool) -> void:
	print("\n%s. 10030-1 pasted whole %s at (1200, 0, 0)" % ["2" if other_tab else "1",
		"from another tab" if other_tab else "in the same tab"])
	await _open(SET)
	var original: String = _text_of(SET)
	var ids: Array = _shown().map(func(brick: BrickWorld.Brick) -> int: return brick.id)
	await _paste_and_save("10030-" + ("other" if other_tab else "same"), original, ids,
		[Vector3(1200, 0, 0)], 0, other_tab)


func _case_fixture(said: String, tag: String, pick: Callable, spot: Vector3, quarters: int) -> void:
	print("\n" + said)
	var path: String = PROBE_DIR + "pe_fixture.mpd"
	await _open(path)
	var ids: Array = pick.call()
	_ok(not ids.is_empty(), "%s: %d parts to copy" % [tag, ids.size()])
	if ids.is_empty():
		return
	await _paste_and_save(tag, FIXTURE, ids, [spot, spot + Vector3(0, 0, -400), spot + Vector3(400, 0, 0)],
		quarters, false)


## 8. The fixture put whole into another file (a file dragged in, the
## session's open_model into=true: ModelStore.held_from), saved three times.
func _case_put_in() -> void:
	print("\n8. the fixture put whole into another file (a file dragged in)")
	await _open(PROBE_DIR + "pe_fixture.mpd")
	var theirs: Array = _records_all()
	var host_at: String = PROBE_DIR + "pe_host.ldr"
	_write(ProjectSettings.globalize_path(host_at), HOST)
	await _open(host_at)
	var held: Dictionary = await _store.held_from(FIXTURE, "pe_fixture.mpd")
	_ok(str(held["error"]).is_empty() and (held["items"] as Array).size() == theirs.size(),
		"held_from: %d parts in hand of the fixture's %d (%s)" % [(held["items"] as Array).size(), theirs.size(),
			held["error"]])
	if not str(held["error"]).is_empty():
		return
	var had: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		had[brick.id] = true
	_builder.cancel_carry()
	_builder.hold_copy(held["items"])
	_builder.carrying.bring(held)
	await _put([Vector3(0, 0, -400), Vector3(0, 0, -800), Vector3(600, 0, 0)])
	var fresh: Array = _records_all().filter(func(one: Dictionary) -> bool: return not had.has(one["id"]))
	_ok(fresh.size() == theirs.size(), "put in: %d of %d put down" % [fresh.size(), theirs.size()])
	if fresh.size() != theirs.size():
		return
	_held_exact("put-in", theirs, fresh, true)
	await _three_saves("put-in", HOST, _records_all())


## 7. The fixture's turned copy duplicated beside itself (Edit › Duplicate,
## Ctrl+D), saved three times.
func _case_duplicate() -> void:
	print("\n7. the fixture's turned copy duplicated beside itself (Ctrl+D)")
	var path: String = PROBE_DIR + "pe_fixture.mpd"
	await _open(path)
	var ids: Array = _turned_copy()
	var had: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		had[brick.id] = true
	_select(ids)
	var copied: Array = _records(ids)
	var made: int = _verbs.duplicate_beside()
	await _frames(3)
	if _builder.is_carrying():
		await _put([Vector3(0, 0, -800), Vector3(400, 0, -800)])
	var fresh: Array = _records_all().filter(func(one: Dictionary) -> bool: return not had.has(one["id"]))
	_ok(made == ids.size() and fresh.size() == ids.size(), "duplicate_beside made %d, %d put down, of %d"
		% [made, fresh.size(), ids.size()])
	_builder.clear_selection()
	if fresh.size() != ids.size():
		return
	_held_exact("duplicate", copied, fresh, true)
	await _three_saves("duplicate", FIXTURE, _records_all())


# -- a paste, checked, then saved three times ------------------------------------


## [param ids] copied in the model opened from [param original]'s text, pasted
## ([param other_tab]: as another tab pastes it), turned [param quarters] in
## hand, put down at the first of [param spots] that takes it, checked
## against what was copied, then saved and reopened three times.
func _paste_and_save(tag: String, original: String, ids: Array, spots: Array, quarters: int,
		other_tab: bool) -> void:
	var copied: Array = _records(ids)
	_select(ids)
	var count: int = _verbs.copy()
	_builder.clear_selection()
	var held: int = 0
	if other_tab:
		var kept: String = Carry.whole_text("", "pasteexact", _library)
		_fresh_tab()
		held = _verbs.paste_from(kept)
	else:
		held = _verbs.paste()
	_ok(count == ids.size() and held == count, "%s: copied %d, paste holds %d" % [tag, count, held])
	if quarters != 0:
		_builder.rotate_held(quarters)
	var put: Dictionary = await _put(spots)
	var pasted: Array = _records(put["ids"])
	_ok(pasted.size() == count, "%s: put down %d of %d at %s" % [tag, pasted.size(), count, put["spot"]])
	if pasted.size() != count:
		return
	_held_exact(tag, copied, pasted, quarters == 0)
	await _three_saves(tag, original, _records_all())


## The model as it stands, [param after] its parts, saved, reopened and saved
## again, three times: each reopen has every part where [param after] has
## it, the first save holds each placing line of [param original] byte for
## byte, and the second and third are the first byte for byte.
func _three_saves(tag: String, original: String, after: Array) -> void:
	var at: String = ProjectSettings.globalize_path(PROBE_DIR + tag + ".mpd")
	var first: String = ""
	for round: int in 3:
		var saved: bool = bool(_main.call("save_model", at))
		var how: String = "a patch" if _store.last_whole.is_empty() else "written whole: " + _store.last_whole
		var text: String = _text_of(at)
		_kept("%s-%d.mpd" % [tag, round + 1], text)
		if round == 0:
			first = text
			var diff: Dictionary = _line_diff(original, text)
			var lost: Array = diff["lost"]
			var placing: Array = lost.filter(func(line: String) -> bool: return line.strip_edges().begins_with("1 "))
			_ok(saved and placing.is_empty(),
				"%s save 1 (%s): every line placing a part or copy of the file opened kept byte for byte: %d of %d lines gone, %d placing (%s)"
				% [tag, how, lost.size(), original.split("\n").size(), placing.size(),
					" | ".join(PackedStringArray(placing.slice(0, 3)))])
			var put_in: Array = (diff["new"] as Array).filter(func(line: String) -> bool:
				return line.strip_edges().begins_with("1 "))
			print("    %d placing lines put in: %s" % [put_in.size(), " | ".join(PackedStringArray(put_in.slice(0, 4)))])
		else:
			var diff: Dictionary = _line_diff(first, text)
			_ok(saved and text == first, "%s save %d (%s): the first save byte for byte (%d lines gone, %d new: %s -> %s)"
				% [tag, round + 1, how, (diff["lost"] as Array).size(), (diff["new"] as Array).size(),
					" | ".join(PackedStringArray((diff["lost"] as Array).slice(0, 2))),
					" | ".join(PackedStringArray((diff["new"] as Array).slice(0, 2)))])
		await _open(at)
		var back: Array = _records_all()
		_ok(_part_colours(after) == _part_colours(back), "%s reopen %d: %d parts against %d; part:colour %s"
			% [tag, round + 1, back.size(), after.size(), _diff_counts(_part_colours(after), _part_colours(back))])
		_strict("%s reopen %d" % [tag, round + 1], after, back)


## Each of [param pasted] is one of [param copied] moved by the one move the
## lowest corner of their places says, its turn the copied part's to the bit
## where [param unturned]: what a paste put down is what was copied.
func _held_exact(tag: String, copied: Array, pasted: Array, unturned: bool) -> void:
	if not unturned:
		# Turned in hand: every part laid by the one move and turn the first
		# copied part was (the turn is the hand's).
		var laid: Dictionary = _laid_alike(copied, pasted)
		_ok(bool(laid["lies"]), "%s: pasted, turned, each part the copied one moved and turned by one move (%s): most apart %.5f LDU, turn element %.7f"
			% [tag, laid["move"], float(laid["origin"]), float(laid["basis"])])
		return
	var move: Vector3 = _low(pasted) - _low(copied)
	var p: Dictionary = _pair(copied, pasted, move)
	var bits: int = 0
	var buckets: Dictionary = {}
	for one: Dictionary in pasted:
		var key: String = "%s:%d" % [one["part"], int(one["color"])]
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(one)
	for one: Dictionary in copied:
		var at: Transform3D = one["at"]
		var same: bool = false
		for other: Dictionary in buckets.get("%s:%d" % [one["part"], int(one["color"])], []):
			var there: Transform3D = other["at"]
			if there.origin.distance_to(at.origin + move) <= NEAR and there.basis == at.basis:
				same = true
				break
		if not same:
			bits += 1
	_ok(int(p["unpaired_a"]) == 0 and int(p["unpaired_b"]) == 0 and float(p["origin"]) <= NEAR and bits == 0,
		"%s: pasted, each part the copied one moved by %s: %d against %d; most apart %.5f LDU; %d turned otherwise than copied (to the bit)"
		% [tag, move, copied.size(), pasted.size(), float(p["origin"]), bits])
	if bits > 0 or float(p["origin"]) > NEAR:
		print("        worst: %s" % p["worst"])


## [param a]'s parts where [param b] has them, within [constant NEAR] and
## [constant TURN_NEAR], none mirrored.
func _strict(said: String, a: Array, b: Array) -> void:
	var p: Dictionary = _pair(a, b, Vector3.ZERO)
	var mirrored: int = _mirrors(a, b)
	var bad: bool = int(p["unpaired_a"]) > 0 or int(p["unpaired_b"]) > 0 or float(p["origin"]) > NEAR \
		or float(p["basis"]) > TURN_NEAR or mirrored > 0
	_ok(not bad, "%s: %d against %d; unpaired %d/%d; most apart %.5f LDU, turn element %.7f; %d mirrored"
		% [said, a.size(), b.size(), int(p["unpaired_a"]), int(p["unpaired_b"]), float(p["origin"]),
			float(p["basis"]), mirrored])
	if bad:
		print("        worst: %s" % p["worst"])


## Whether one move lays each of [param copied] on one of [param pasted] of
## its part and colour, the move the first copied part's to one of its kind
## says: {lies, move, origin (most LDU apart), basis (most apart, any element)}.
func _laid_alike(copied: Array, pasted: Array) -> Dictionary:
	var out: Dictionary = {"lies": false, "move": Transform3D.IDENTITY, "origin": INF, "basis": INF}
	if copied.is_empty() or copied.size() != pasted.size():
		return out
	var anchor: Dictionary = copied[0]
	for candidate: Dictionary in pasted:
		if candidate["part"] != anchor["part"] or int(candidate["color"]) != int(anchor["color"]):
			continue
		var move: Transform3D = (candidate["at"] as Transform3D) * (anchor["at"] as Transform3D).affine_inverse()
		var left: Array = pasted.duplicate()
		var most_origin: float = 0.0
		var most_basis: float = 0.0
		var lies: bool = true
		for one: Dictionary in copied:
			var there: Transform3D = move * (one["at"] as Transform3D)
			var hit: int = -1
			var hit_d: float = INF
			for n: int in left.size():
				var other: Dictionary = left[n]
				if other["part"] != one["part"] or int(other["color"]) != int(one["color"]):
					continue
				var d: float = (other["at"] as Transform3D).origin.distance_to(there.origin)
				if d < hit_d:
					hit_d = d
					hit = n
			if hit < 0 or hit_d > NEAR:
				lies = false
				break
			var b: Basis = (left[hit]["at"] as Transform3D).basis
			for axis: int in 3:
				for k: int in 3:
					most_basis = maxf(most_basis, absf(b[axis][k] - there.basis[axis][k]))
			most_origin = maxf(most_origin, hit_d)
			left.remove_at(hit)
		if lies and most_basis <= 0.00001:
			return {"lies": true, "move": move, "origin": most_origin, "basis": most_basis}
		if most_origin < float(out["origin"]):
			out = {"lies": false, "move": move, "origin": most_origin, "basis": most_basis}
	return out


## The lowest corner of [param records]' places, each axis its least: the
## same part's on both sides of a move, so their difference is the move.
func _low(records: Array) -> Vector3:
	var low := Vector3(INF, INF, INF)
	for one: Dictionary in records:
		var o: Vector3 = (one["at"] as Transform3D).origin
		low = Vector3(minf(low.x, o.x), minf(low.y, o.y), minf(low.z, o.z))
	return low


# -- the fixture's parts -----------------------------------------------------------


## The top copies of the fixture: their path -> [ids].
func _tops() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _shown():
		var top: String = Assemblies.segments(brick.unit)[0] if not brick.unit.is_empty() else ""
		if not out.has(top):
			out[top] = []
		(out[top] as Array).append(brick)
	return out


## The copy of pe_plain the fixture places mirrored, at x 200: its parts are
## read in their other hand, so none is turned the mirror way here.
func _mirrored_copy() -> Array:
	var tops: Dictionary = _tops()
	for top: String in tops:
		if Assemblies.definition(top) != "pe_plain":
			continue
		var x: float = 0.0
		for brick: BrickWorld.Brick in tops[top]:
			x += brick.transform.origin.x / (tops[top] as Array).size()
		if x > 100.0 and x < 400.0:
			return (tops[top] as Array).map(func(brick: BrickWorld.Brick) -> int: return brick.id)
	return []


func _turned_copy() -> Array:
	var tops: Dictionary = _tops()
	for top: String in tops:
		if Assemblies.definition(top) == "pe_turned":
			return (tops[top] as Array).map(func(brick: BrickWorld.Brick) -> int: return brick.id)
	return []


func _far_parts() -> Array:
	return _shown().filter(func(brick: BrickWorld.Brick) -> bool: return brick.transform.origin.x > 5000.0) \
		.map(func(brick: BrickWorld.Brick) -> int: return brick.id)


## Two of the three parts of the far copy of pe_plain, turned 30 degrees.
func _some_parts() -> Array:
	var tops: Dictionary = _tops()
	for top: String in tops:
		if Assemblies.definition(top) == "pe_plain" and ((tops[top] as Array)[0] as BrickWorld.Brick) \
				.transform.origin.x > 5000.0:
			return (tops[top] as Array).slice(0, 2).map(func(brick: BrickWorld.Brick) -> int: return brick.id)
	return []


func _every_part() -> Array:
	return _shown().map(func(brick: BrickWorld.Brick) -> int: return brick.id)
