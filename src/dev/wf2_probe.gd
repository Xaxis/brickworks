## wingfix2's probe: one step that changes two copies of a sub-model by hand
## (wingreview3 F1 and F2). Both twins of a part, picked together (Alt-A takes
## every copy's), dragged or nudged: where the two copies would take it
## differently (along a mirrored copy's axis, a turned copy, three copies)
## the ghost is red before the click with the words the click's refusal says,
## and the click changes nothing, the file byte for byte and no step to undo;
## where they agree (along the axis a mirror keeps, back in place) it goes
## through, every copy the same shape after, each copy's part where its own
## copy put it, and the untouched third copy given it once. Parts of two
## copies that are not twins (one's 1 x 2, the other's 2 x 2) each go into
## both. One part taken into hand by X and typed a stud along is a move too
## (wingkeep): the other copy follows, and where its twin has no room the
## ghost is red with the words before the click. Then wingreview3's own
## follow table (wr3_probe), whole.
##
##   godot --headless --path . --script src/dev/wf2_probe.gd
##
##   WF2_ONLY=words   only the cases whose names have them (wingfix2's)
##   WF2_OWN=1        wingfix2's cases only, not wr3_probe's table
##   WF2_ROUNDTRIP=1  only saved, opened and saved again, unedited and after
##                    one twin dragged, with a mirrored copy placed first and
##                    a straight one: a finding, not a check (wingfix2 N1:
##                    after an edit, a file whose first copy is mirrored is
##                    written again from the other hand on its second save,
##                    the parts where they were; also before wingfix2)
extends "res://src/dev/wr3_probe.gd"

const UNLIKE := "Moved in two copies of Wing at once, and differently"

## [name, placement lines, the parts picked ([copy index, part] each), how
## ("drag": lifted and put down, as wr3_probe's; "nudge": moved a stud by the
## keys; "x": the one part taken into hand by X, its ghost typed there and
## clicked), the move (world LDU), "made" or "refused", and optionally what
## is done first (wr3_probe's "blocker") and the refusal's first words
## ([constant UNLIKE] where not given)].
const WF2_LIST: Array = [
	["drag both, three copies +z (they agree)", [STRAIGHT, MIRRORED, BEHIND],
		[[0, "3004"], [1, "3004"]], "drag", Vector3(0, 0, 20), "made"],
	["drag both back where they stood", [STRAIGHT, MIRRORED],
		[[0, "3004"], [1, "3004"]], "drag", Vector3.ZERO, "made"],
	["drag both +x along the mirror", [STRAIGHT, MIRRORED],
		[[0, "3004"], [1, "3004"]], "drag", Vector3(20, 0, 0), "refused"],
	["drag both, three copies, the third's untouched, -x", [STRAIGHT, MIRRORED, BEHIND],
		[[0, "3004"], [1, "3004"]], "drag", Vector3(-20, 0, 0), "refused"],
	["drag both, a turned copy +z", [STRAIGHT, TURNED],
		[[0, "3004"], [1, "3004"]], "drag", Vector3(0, 0, 20), "refused"],
	["drag the 3003 of all three copies +x", [STRAIGHT, MIRRORED, BEHIND],
		[[0, "3003"], [1, "3003"], [2, "3003"]], "drag", Vector3(20, 0, 0), "refused"],
	["drag one's 3004 and the other's 3003 +x (not twins)", [STRAIGHT, MIRRORED],
		[[0, "3004"], [1, "3003"]], "drag", Vector3(20, 0, 0), "made"],
	["nudge one +x, the other follows", [STRAIGHT, MIRRORED],
		[[0, "3004"]], "nudge", Vector3(20, 0, 0), "made"],
	["nudge both +z (they agree)", [STRAIGHT, MIRRORED],
		[[0, "3004"], [1, "3004"]], "nudge", Vector3(0, 0, 20), "made"],
	["nudge both +x along the mirror", [STRAIGHT, MIRRORED],
		[[0, "3004"], [1, "3004"]], "nudge", Vector3(20, 0, 0), "refused"],
	["nudge both, three copies +x", [STRAIGHT, MIRRORED, BEHIND],
		[[0, "3004"], [1, "3004"]], "nudge", Vector3(20, 0, 0), "refused"],
	["nudge both, a turned copy +x", [STRAIGHT, TURNED],
		[[0, "3004"], [1, "3004"]], "nudge", Vector3(20, 0, 0), "refused"],
	["X one +x, the other follows", [STRAIGHT, MIRRORED],
		[[0, "3004"]], "x", Vector3(20, 0, 0), "made"],
	["X one +x, the twin's spot taken", [STRAIGHT, MIRRORED],
		[[0, "3004"]], "x", Vector3(20, 0, 0), "refused", "blocker", "No room in "],
]


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(2400.0).timeout.connect(func() -> void:
		print("wf2 probe: not finished in time")
		quit(1))
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
	_verbs = _main.get("_verbs")
	_bar_main = _main.get("_bar")
	_tree = _shell.assemblies
	if not OS.get_environment("WF2_ROUNDTRIP").is_empty():
		for lines: Array in [[MIRRORED, STRAIGHT], [STRAIGHT, MIRRORED]]:
			await _open(_wing_file(lines))
			var first: String = _save()
			await _open(first)
			var second: String = _save()
			print("\n== round trip, unedited, %s first: %s" % [lines[0].left(20),
				"the same" if first == second else "differs"])
			_wr_diff("unedited", first, second)
			# One twin dragged +z, the other copy following: saved, opened, saved.
			await _open(_wing_file(lines))
			var frames: Array = lines.map(func(l: String) -> Transform3D: return _placed_by(l))
			var one: BrickWorld.Brick = _in(_copy_at(frames[0]), "3004")
			print("  one twin +z: %s" % await _lift_put([one.id], Vector3(0, 0, 20)))
			var edited: String = _save()
			await _open(edited)
			var again: String = _save()
			print("== round trip, one twin +z, %s first: %s" % [lines[0].left(20),
				"the same" if edited == again else "differs"])
			_wr_diff("edited", edited, again)
		quit(0)
		return
	for one: Array in WF2_LIST:
		await _wf2_case(one)
	if OS.get_environment("WF2_OWN").is_empty() and OS.get_environment("WF2_ONLY").is_empty():
		for one: Array in WR3_LIST:
			await _follow_case(one)
		await _nested_cases()
	print("\nthe table:")
	for line: String in _table:
		print("  " + line)
	print("\nwf2 probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


## Each copy's parts in its own frame ([param frame], the world's axes): "part
## at (x,y,z)", sorted. Copies of one shape say the same.
func _local_parts(path: String, frame: Transform3D) -> PackedStringArray:
	var out := PackedStringArray()
	var inverse: Transform3D = frame.affine_inverse()
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path:
			out.append("%s at %s" % [brick.part_id, str((inverse * brick.transform.origin).snappedf(0.1))])
	out.sort()
	return out


func _wf2_case(one: Array) -> void:
	var name: String = one[0]
	var lines: Array = one[1]
	var picks: Array = one[2]
	var how: String = one[3]
	var by: Vector3 = one[4]
	var want: String = one[5]
	var prep: String = str(one[6]) if one.size() > 6 else ""
	var unlike: String = str(one[7]) if one.size() > 7 else UNLIKE
	var only: String = OS.get_environment("WF2_ONLY")
	if not only.is_empty() and not name.contains(only):
		return
	print("\n== wf2: %s" % name)
	await _open(_wing_file(lines))
	var frames: Array = lines.map(func(l: String) -> Transform3D: return _placed_by(l))
	var paths: Array = frames.map(func(f: Transform3D) -> String: return _copy_at(f))
	if paths.has(""):
		_check("%s: every copy found (%s)" % [name, str(paths)], false)
		_table.append("%-52s %s" % [name, "FAIL"])
		return
	if prep == "blocker":
		# wr3_probe's: a 1 x 1 brick of the model's own where the mirrored
		# copy's twin would go.
		var block := Transform3D(Basis.IDENTITY, Vector3(-130, 32, 10))
		_builder.register(_world.add_brick("3005", 15, block), "3005", block)
		await _frames(2)
	var ids: Array = []
	## [part, where in its copy's frame it goes] of each part picked.
	var goes: Array = []
	for pick: Array in picks:
		var brick: BrickWorld.Brick = _in(paths[int(pick[0])], str(pick[1]))
		ids.append(brick.id)
		goes.append([brick.part_id, ((frames[int(pick[0])] as Transform3D).affine_inverse()
			* (brick.transform.origin + by)).snappedf(0.1)])
	var per_before: Dictionary = {}
	for p: String in paths:
		per_before[p] = _wr_parts(p)
	var count_before: int = _world.brick_count()
	var depth: int = _builder.history_depth()
	var before: String = _save()
	var said: String = ""
	_asked_red = ""
	if how == "drag":
		said = await _lift_put(ids, by)
	elif how == "x":
		said = await _x_put(int(ids[0]), by)
	else:
		_pick(ids)
		var cells := Vector3i(roundi(by.x / BrickLattice.CELL), roundi(by.y / BrickLattice.CELL),
			roundi(by.z / BrickLattice.CELL))
		said = "nudged %d" % _builder.move_selection(cells)
		await _edited()
		await _frames(2)
	var asked: String = _asked_red
	_asked_red = ""
	var after: String = _save()
	var made: bool = _builder.history_depth() > depth
	var bar: String = _bar_text()
	print("  %s; history %d -> %d; %d parts -> %d; bar \"%s\"" % [said, depth,
		_builder.history_depth(), count_before, _world.brick_count(), bar.left(160)])
	for k: int in paths.size():
		print("  %s now, in its frame: %s" % [paths[k], ", ".join(_local_parts(paths[k], frames[k]))])
	# A ghost stands in hand for a drag and for X's part; a nudge has none.
	var ghost: bool = how != "nudge"
	if ghost:
		print("  the ghost's ask before the click: \"%s\"" % asked)
	var ok: bool = _check("%s: %s (history %d -> %d)" % [name, want, depth, _builder.history_depth()],
		made == (want == "made"))
	if ghost:
		ok = _check("%s: the ghost red before the click exactly where the click is refused (\"%s\")"
			% [name, asked.left(100)], asked.is_empty() == made) and ok
	if want == "refused":
		ok = _check("%s: the ghost and the bar say why (ghost \"%s\", bar \"%s\")" % [name,
			asked.left(60), bar.left(60)], (not ghost or asked.begins_with(unlike))
			and bar.begins_with(unlike)) and ok
		ok = _check("%s: the file byte for byte" % name, after == before) and ok
		for p: String in paths:
			ok = _check("%s: %s as it was" % [name, p], _wr_parts(p) == per_before[p]) and ok
	elif made:
		var through: Array = _through()
		ok = _check("%s: nothing through anything (%s)" % [name, ", ".join(through)],
			through.is_empty()) and ok
		ok = _check("%s: the model has as many parts as before (%d, were %d)" % [name,
			_world.brick_count(), count_before], _world.brick_count() == count_before) and ok
		var shape: PackedStringArray = _local_parts(paths[0], frames[0])
		for k: int in paths.size():
			var mine: PackedStringArray = _local_parts(paths[k], frames[k])
			ok = _check("%s: %s holds as many parts as before (%d, were %d)" % [name, paths[k],
				mine.size(), (per_before[paths[k]] as PackedStringArray).size()],
				mine.size() == (per_before[paths[k]] as PackedStringArray).size()) and ok
			ok = _check("%s: %s the shape %s is" % [name, paths[k], paths[0]], mine == shape) and ok
			# Each part picked where its own copy put it, in every copy.
			for went: Array in goes:
				var at: String = "%s at %s" % [went[0], str(went[1])]
				ok = _check("%s: %s has %s" % [name, paths[k], at], mine.has(at)) and ok
		_shell.run("undo")
		await _frames(6)
		var undone: String = _save()
		_shell.run("redo")
		await _frames(6)
		var redone: String = _save()
		ok = _check("%s: one undo gives the file back byte for byte, a redo the edit" % name,
			undone == before and redone == after) and ok
		var kept: Array = []
		for k: int in paths.size():
			kept.append(_local_parts(paths[k], frames[k]))
		await _open(after)
		var again: String = _save()
		var reopened: Array = []
		for k: int in frames.size():
			var p: String = _copy_at(frames[k])
			reopened.append(_local_parts(p, frames[k]) if not p.is_empty() else PackedStringArray())
		ok = _check("%s: saved and opened again, the same file and the same parts" % name,
			again == after and reopened == kept) and ok
		if again != after:
			_wr_diff("reopen", after, again)
		if reopened != kept:
			print("    after: %s\n    reopened: %s" % [str(kept), str(reopened)])
	_table.append("%-52s %s" % [name, "pass" if ok else "FAIL"])
	_tree.leave_to("")


## Taken into hand by X (Builder.lift_brick: still the model's where it
## stood), its ghost aimed from above where it stood and typed the rest of
## the way to [param by] along (TypedEntry: pin_hand, typed_hand), the copies'
## ask answered as each aim makes it (Builder._ask_copies), and clicked. What
## happened, said.
func _x_put(brick_id: int, by: Vector3) -> String:
	var mode: String = _verbs.mode
	var aimed: Variant = _x_aim(brick_id, by)
	if aimed is String:
		_x_done(mode)
		return aimed
	_asked_red = str(_builder.get("copies_refuse"))
	var at: Variant = _builder.ghost_place()
	var put: int = _builder.place()
	await _edited()
	await _frames(2)
	_x_done(mode)
	return "X: aimed at %s, typed to %s, put %d" % [str(aimed), str(at), put]


## X over [param brick_id], as the key does (Builder.lift_brick, then the
## Place tool), its ghost aimed from above where it stood and typed the rest
## of the way to [param by] along, and the copies' ask answered: where it
## was aimed, or what went wrong (a String).
func _x_aim(brick_id: int, by: Vector3) -> Variant:
	_builder.clear_selection()
	var stood: Vector3 = _world.get_brick(brick_id).transform.origin
	if not _builder.lift_brick(brick_id) or not _builder.holds_lifted_part():
		return "not taken into hand"
	_verbs.set_mode("place")
	if not _builder.holds_lifted_part():
		return "let go of by the Place tool"
	_builder.update_preview(stood + Vector3(0, 400, 0), Vector3.DOWN)
	var aimed: Variant = _builder.ghost_place()
	if aimed == null or not _builder.pin_hand():
		return "no ghost where it stood"
	_builder.typed_hand(stood + by - (aimed as Vector3), 0.0, 0.0, Vector3.RIGHT)
	for _n: int in 200:
		_builder.call("_ask_copies")
		if (_builder.get("_copies_ask") as Dictionary).is_empty():
			break
	return aimed


## What X left in hand let go of, and the tool there was before it.
func _x_done(mode: String) -> void:
	_builder.unpin_hand()
	_builder.put_hand_back()
	_verbs.set_mode(mode)
