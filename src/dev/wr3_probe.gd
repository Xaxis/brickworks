## wingreview3's probe: the twin a lift takes off is laid again (room390,
## Assemblies._follow), and the copies' ask through 4-stud blocks (wingfin,
## Assemblies._meets, _hand_plan), each against what it replaced.
##
##   godot --headless --path . --script src/dev/wr3_probe.gd
##
##   WR3_CASES=follow,meets,ask   those parts only
##
## follow: a part of a copied sub-assembly lifted at the model's level (as a
## drag lifts it: Builder.lift_selection, the lift's own follow at the
## frame's end, Carry.show_moved, Builder.place, the put's follow) and put
## down a stud along, back where it stood, or further, in the original, in a
## mirrored copy, a turned copy, three copies, nested copies, a twin placed in
## another colour, a twin that differs, and both twins lifted together. Each:
## every copy's parts after, nothing through anything, undo/redo byte for
## byte, and the save opened again.
## meets: Assemblies._meets against the plain scan it replaced, on every part
## of a real set (10179: SNOT, hinges, turned and stacked parts) and random
## shifts across block edges.
## ask: Assemblies.room_in_copies against wingplace's own (8d0034b64, here as
## _old_room) on random hands over a 1,500-part sub-model placed three times
## (straight, mirrored, turned), each hand asked at three frames with one
## items array, as a drag asks it.
extends "res://src/dev/copyfaults_probe.gd"

var _tree: Assemblies
var _verbs: EditVerbs
var _bar_main: ModelBar
var _table := PackedStringArray()
## What the copies' ask said of the last hand before its click ("" for room).
var _asked_red: String = ""

const WING := """0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
0 Author: Brickworks

1 1 100 -8 0 1 0 0 0 1 0 0 0 1 3034.dat
1 4 40 -32 0 1 0 0 0 1 0 0 0 1 3003.dat
1 16 100 -32 -10 1 0 0 0 1 0 0 0 1 3004.dat
0
0 NOFILE
"""

const STRAIGHT := "1 16 0 0 0 1 0 0 0 1 0 0 0 1 wing.ldr"
const MIRRORED := "1 16 0 0 0 -1 0 0 0 1 0 0 0 1 wing.ldr"
const TURNED := "1 16 0 0 300 0 0 1 0 1 0 -1 0 0 wing.ldr"
const BEHIND := "1 16 0 0 -200 1 0 0 0 1 0 0 0 1 wing.ldr"
const GREEN_MIRRORED := "1 2 0 0 0 -1 0 0 0 1 0 0 0 1 wing.ldr"
const RED_STRAIGHT := "1 4 0 0 0 1 0 0 0 1 0 0 0 1 wing.ldr"

## [name, placement lines, which copy (index into the lines) each lifted
## part is in, the part, the move (world LDU), what is done first].
const WR3_LIST: Array = [
	["orig +x", [STRAIGHT, MIRRORED], [0], "3004", Vector3(20, 0, 0), ""],
	["orig -x", [STRAIGHT, MIRRORED], [0], "3004", Vector3(-20, 0, 0), ""],
	["orig +z", [STRAIGHT, MIRRORED], [0], "3004", Vector3(0, 0, 20), ""],
	["orig back in place", [STRAIGHT, MIRRORED], [0], "3004", Vector3.ZERO, ""],
	["orig far", [STRAIGHT, MIRRORED], [0], "3004", Vector3(60, 0, 0), ""],
	["mirrored copy +x", [STRAIGHT, MIRRORED], [1], "3004", Vector3(20, 0, 0), ""],
	["mirrored copy back", [STRAIGHT, MIRRORED], [1], "3004", Vector3.ZERO, ""],
	["turned copy +x", [STRAIGHT, TURNED], [0], "3004", Vector3(20, 0, 0), ""],
	["turned copy, its own +z", [STRAIGHT, TURNED], [1], "3004", Vector3(0, 0, 20), ""],
	["three copies +x", [STRAIGHT, MIRRORED, BEHIND], [0], "3004", Vector3(20, 0, 0), ""],
	["three copies back", [STRAIGHT, MIRRORED, BEHIND], [2], "3004", Vector3.ZERO, ""],
	["placing colour +x", [RED_STRAIGHT, GREEN_MIRRORED], [0], "3004", Vector3(20, 0, 0), ""],
	["placing colour back", [RED_STRAIGHT, GREEN_MIRRORED], [0], "3004", Vector3.ZERO, ""],
	["the brick 3003 +z", [STRAIGHT, MIRRORED], [0], "3003", Vector3(0, 0, 20), ""],
	["inside the wing +x", [STRAIGHT, MIRRORED], [0], "3004", Vector3(20, 0, 0), "enter"],
	["twin differs (moved under the follow)", [STRAIGHT, MIRRORED], [0], "3004", Vector3(20, 0, 0), "move_twin"],
	["twin gone (under the follow)", [STRAIGHT, MIRRORED], [0], "3003", Vector3(0, 0, 20), "drop_twin"],
	["orig +x, the twin's spot taken", [STRAIGHT, MIRRORED], [0], "3004", Vector3(20, 0, 0), "blocker"],
	["both twins +z", [STRAIGHT, MIRRORED], [0, 1], "3004", Vector3(0, 0, 20), ""],
	["both twins +x (along the mirror)", [STRAIGHT, MIRRORED], [0, 1], "3004", Vector3(20, 0, 0), ""],
	["both twins far +z", [STRAIGHT, MIRRORED], [0, 1], "3004", Vector3(0, 0, 40), ""],
	["both twins -x (along the mirror)", [STRAIGHT, MIRRORED], [0, 1], "3004", Vector3(-20, 0, 0), ""],
	["one and the other's 3003 +z", [STRAIGHT, MIRRORED], [0, 1], "3003", Vector3(0, 0, 20), ""],
	["both, three copies +x", [STRAIGHT, MIRRORED, BEHIND], [0, 1], "3004", Vector3(20, 0, 0), ""],
	["both twins, turned copy +x", [STRAIGHT, TURNED], [0, 1], "3004", Vector3(20, 0, 0), ""],
]


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(3000.0).timeout.connect(func() -> void:
		print("wr3 probe: not finished in time")
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
	var only: PackedStringArray = OS.get_environment("WR3_CASES").split(",", false)
	if only.is_empty() or "follow" in only:
		for one: Array in WR3_LIST:
			await _follow_case(one)
		await _nested_cases()
	if only.is_empty() or "meets" in only:
		await _meets_cases()
	if only.is_empty() or "ask" in only:
		await _ask_cases()
	print("\nthe table:")
	for line: String in _table:
		print("  " + line)
	print("\nwr3 probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- follow ---------------------------------------------------------------------


func _wing_file(lines: Array) -> String:
	var out := PackedStringArray(["0 FILE main.ldr", "0 Main", "0 Name: main.ldr",
		"0 Author: Brickworks", ""])
	for line: String in lines:
		out.append(line)
	out.append_array(["0", "0 NOFILE"])
	return "\n".join(out) + "\n" + WING


## The frame an LDraw type 1 line places its file in, in the world's axes
## (LdrModel.FLIP: y and z the other way).
static func _placed_by(line: String) -> Transform3D:
	var f: PackedStringArray = line.split(" ", false)
	var basis := Basis(Vector3(float(f[5]), float(f[8]), float(f[11])),
		Vector3(float(f[6]), float(f[9]), float(f[12])),
		Vector3(float(f[7]), float(f[10]), float(f[13])))
	var flip := Transform3D(Basis.from_scale(LdrModel.FLIP), Vector3.ZERO)
	return flip * Transform3D(basis, Vector3(float(f[2]), float(f[3]), float(f[4]))) * flip


## The copy's path whose plate stands where [param frame] puts the plate.
func _copy_at(frame: Transform3D) -> String:
	var want: Vector3 = frame * (Vector3(100, -8, 0) * LdrModel.FLIP)
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("3034") and brick.transform.origin.distance_to(want) < 0.5:
			return Assemblies.path_of(brick)
	if _world.brick_count() > 0:
		print("  no plate at %s: %s" % [str(want), ", ".join(_world.bricks().map(func(b: BrickWorld.Brick) -> String:
			return "%s %s %s" % [b.part_id, Assemblies.path_of(b), str(b.transform.origin)]))])
	return ""


## Each copy's parts, by the frame it stands in (its path found by its plate).
func _copies_now(frames: Array) -> Array:
	var out: Array = []
	for f: Transform3D in frames:
		var p: String = _copy_at(f)
		out.append(_wr_parts(p) if not p.is_empty() else PackedStringArray(["no copy there"]))
	return out


func _in(path: String, part: String) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path and brick.part_id.begins_with(part):
			return brick
	return null


## Every part of the copy at [param path], said: "part c<colour> at (x,y,z)".
func _wr_parts(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path:
			out.append("%s c%d at %s" % [brick.part_id, brick.color_code,
				str(brick.transform.origin.snappedf(0.1))])
	out.sort()
	return out


func _through() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var packed: PackedInt32Array = _builder.boxes_for(_library.mesh_for(brick.part_id),
			brick.transform)
		for other: int in _builder.lattice.blockers_boxes(packed, brick.id):
			if not _store.scenery.has(other):
				out.append("%s #%d through %s #%d" % [brick.part_id, brick.id,
					_world.get_brick(other).part_id if _world.get_brick(other) != null else "?", other])
	return out


func _bar_text() -> String:
	return (_bar_main.get("_status") as Label).text


## Lifted as a drag lifts it, the lift's follow made at the frame's end, and
## put down [param by] along (world LDU). What happened, said.
func _lift_put(ids: Array, by: Vector3) -> String:
	_pick(ids)
	var lifted: int = _builder.lift_selection()
	if lifted == 0:
		return "not lifted"
	# The frame's end: the lift's own follow (Main._edited_soon).
	await _edited()
	await _frames(2)
	if not _builder.is_carrying():
		return "the lift was refused: %s" % _bar_text()
	var carry: Carry = _builder.carrying
	carry.stand_where_lifted(_builder.lattice, _builder)
	carry.pin()
	if not carry.show_moved(Transform3D(Basis.IDENTITY, by), _builder.lattice, _builder):
		_builder.cancel_carry()
		await _edited()
		return "no room there (the carry's own)"
	# What the ghost says before the click: the copies' ask, as each aim makes
	# it (Builder._ask_copies), until it is answered.
	for _n: int in 200:
		_builder.call("_ask_copies")
		if (_builder.get("_copies_ask") as Dictionary).is_empty():
			break
	_asked_red = str(_builder.get("copies_refuse"))
	var put: int = _builder.place()
	if put == 0:
		_builder.cancel_carry()
		await _edited()
		return "not put down"
	await _edited()
	await _frames(2)
	if _builder.is_carrying():
		_builder.cancel_carry()
		await _edited()
	return "put %d" % put


func _follow_case(one: Array) -> void:
	var name: String = one[0]
	var lines: Array = one[1]
	var which: Array = one[2]
	var part: String = one[3]
	var by: Vector3 = one[4]
	var prep: String = one[5]
	var only: String = OS.get_environment("WR3_ONLY")
	if not only.is_empty() and not name.contains(only):
		return
	print("\n== follow: %s" % name)
	await _open(_wing_file(lines))
	var frames: Array = lines.map(func(l: String) -> Transform3D: return _placed_by(l))
	var paths: Array = frames.map(func(f: Transform3D) -> String: return _copy_at(f))
	if paths.has(""):
		_check("%s: every copy found (%s)" % [name, str(paths)], false)
		return
	# The file as opened, saved, opened and saved again with no edit: what a
	# reopen after the edit is held to.
	var unedited: String = _save()
	var opened_parts: Array = _copies_now(frames)
	await _open(unedited)
	var unedited_parts: Array = _copies_now(frames)
	if _save() != unedited or unedited_parts != opened_parts:
		print("  unedited, saved and opened again, it differs: %s  ->  %s" % [str(opened_parts), str(unedited_parts)])
		_wr_diff("unedited", unedited, _save())
	await _open(_wing_file(lines))
	paths = frames.map(func(f: Transform3D) -> String: return _copy_at(f))
	var lifted_ids: Array = []
	for k: int in which:
		var b: BrickWorld.Brick = _in(paths[k], part)
		lifted_ids.append(b.id)
	var edited: int = int(which[0])
	match prep:
		"enter":
			_tree.enter(paths[edited])
			await _frames(2)
		"move_twin":
			# The twin moved where no follow hears it: the copies no longer
			# lie on each other part for part.
			var twin: BrickWorld.Brick = _in(paths[1], part)
			_builder._apply({"undo": "move", "brick": twin.id,
				"transform": Transform3D(twin.transform.basis, twin.transform.origin + Vector3(0, 0, 20))})
			await _frames(2)
		"drop_twin":
			var twin: BrickWorld.Brick = _in(paths[1], "3004")
			_builder._apply({"undo": "remove", "brick": twin.id})
			await _frames(2)
		"blocker":
			# A 1 x 1 brick of the model's own where the mirrored copy's twin
			# would go: the copy has no room for it.
			var at := Transform3D(Basis.IDENTITY, Vector3(-130, 32, 10))
			var id: int = _world.add_brick("3005", 15, at)
			_builder.register(id, "3005", at)
			await _frames(2)
	var copies_before: Dictionary = {}
	for p: String in paths:
		copies_before[p] = _wr_parts(p)
	var count_before: int = _world.brick_count()
	var depth: int = _builder.history_depth()
	var before: String = _save()
	# Where each lifted part should go, and where its twins should then be.
	var want: Dictionary = {}
	var moved_world: Array = []
	for id: int in lifted_ids:
		moved_world.append(_world.get_brick(id).transform.origin + by)
	var said: String = await _lift_put(lifted_ids, by)
	var after: String = _save()
	var through: Array = _through()
	var copies_after: Dictionary = {}
	for p: String in paths:
		copies_after[p] = _wr_parts(p)
	var made: bool = _builder.history_depth() > depth
	print("  %s; history %d -> %d; %d parts -> %d; bar \"%s\"" % [said, depth,
		_builder.history_depth(), count_before, _world.brick_count(), _bar_text().left(160)])
	for p: String in paths:
		print("  %s before: %s" % [p, ", ".join(copies_before[p])])
		print("  %s after:  %s" % [p, ", ".join(copies_after[p])])
	if not through.is_empty():
		print("  through: %s" % ", ".join(through))
	var ok: bool = true
	var both: bool = which.size() > 1
	var differs: bool = prep == "move_twin" or prep == "drop_twin"
	print("  the ghost's ask before the click: \"%s\"" % _asked_red)
	var asked_red: String = _asked_red
	_asked_red = ""
	if said.begins_with("put"):
		# The ghost said what the click then did: red where it is refused.
		ok = _check("%s: the ghost red before the click exactly where the click is refused (asked \"%s\", made %s)"
			% [name, asked_red.left(120), made], asked_red.is_empty() == made) and ok
	if not made:
		ok = _check("%s: refused or not made, the file byte for byte (%s)" % [name, said],
			after == before) and ok
		if not both and not differs and prep != "blocker":
			ok = _check("%s: a plain drag of one part was made (%s; \"%s\")" % [name, said,
				_bar_text().left(160)], false) and ok
		if prep == "blocker":
			ok = _check("%s: refused, and why said (\"%s\")" % [name, _bar_text().left(160)],
				_bar_text().contains("No room") or _bar_text().contains("no room")) and ok
	elif prep == "blocker":
		ok = _check("%s: put down where the mirrored copy has no room for its twin" % name, false) and ok
	else:
		ok = _check("%s: nothing through anything (%s)" % [name, ", ".join(through)],
			through.is_empty()) and ok
		ok = _check("%s: the model has as many parts as before (%d, were %d)" % [name,
			_world.brick_count(), count_before], _world.brick_count() == count_before) and ok
		for p: String in paths:
			ok = _check("%s: %s holds as many parts as before (%d, were %d)" % [name, p,
				(copies_after[p] as PackedStringArray).size(), (copies_before[p] as PackedStringArray).size()],
				(copies_after[p] as PackedStringArray).size() == (copies_before[p] as PackedStringArray).size()) and ok
		if not both and not differs:
			# Each copy's part where the edited copy's went, in its frame.
			var inverse: Transform3D = (frames[edited] as Transform3D).affine_inverse()
			for k: int in paths.size():
				var wanted: Vector3 = (frames[k] as Transform3D) * (inverse * (moved_world[0] as Vector3))
				var there: bool = false
				for brick: BrickWorld.Brick in _world.bricks():
					if Assemblies.path_of(brick) == paths[k] and brick.part_id.begins_with(part) \
							and brick.transform.origin.distance_to(wanted) < 0.1:
						there = true
				ok = _check("%s: %s has its %s at %s" % [name, paths[k], part, str(wanted.snappedf(0.1))],
					there) and ok
		if differs:
			# The copy that differs keeps what it had: nothing laid in it.
			ok = _check("%s: the copy that differs as it was (%s)" % [name, ", ".join(copies_after[paths[1]])],
				copies_after[paths[1]] == copies_before[paths[1]]) and ok
		_shell.run("undo")
		await _frames(6)
		var undone: String = _save()
		_shell.run("redo")
		await _frames(6)
		var redone: String = _save()
		ok = _check("%s: one undo gives the file back byte for byte, a redo the edit" % name,
			undone == before and redone == after) and ok
		if undone != before:
			_wr_diff("undo", before, undone)
		if redone != after:
			_wr_diff("redo", after, redone)
		# Saved and opened again, as it was: each copy, found by where its
		# plate stands (a reopened file may number its copies afresh).
		var kept: Array = _copies_now(frames)
		await _open(after)
		var again: String = _save()
		var reopened: Array = _copies_now(frames)
		ok = _check("%s: saved and opened again, the same file and the same parts" % name,
			again == after and reopened == kept) and ok
		if again != after:
			_wr_diff("reopen", after, again)
		if reopened != kept:
			print("    after: %s\n    reopened: %s" % [str(kept), str(reopened)])
	_table.append("%-40s %s" % [name, "pass" if ok else "FAIL"])
	_tree.leave_to("")


func _wr_diff(what: String, a: String, b: String) -> void:
	var x: PackedStringArray = a.split("\n")
	var y: PackedStringArray = b.split("\n")
	var shown: int = 0
	for n: int in maxi(x.size(), y.size()):
		var l: String = x[n] if n < x.size() else "<none>"
		var r: String = y[n] if n < y.size() else "<none>"
		if l != r:
			print("    %s line %d: %s  |  %s" % [what, n + 1, l, r])
			shown += 1
			if shown > 8:
				break


## Nested copies: a car with two wheels, the car placed twice
## (cf2_nest_same.mpd). A wheel's plate, and the car's own brick, lifted at
## the model's level and put down a stud along.
func _nested_cases() -> void:
	for spec: Array in [["Car#1/Wheel#1", "4073", Vector3(20, 0, 0)], ["Car#1/Wheel#1", "4073", Vector3.ZERO],
			["Car#2/Wheel#4", "4073", Vector3(0, 0, -20)], ["Car#1", "3001", Vector3(20, 0, 0)]]:
		var name: String = "nested %s %s %s" % [spec[0], spec[1], str(spec[2])]
		print("\n== follow: %s" % name)
		await _open(_fixture("cf2_nest_same.mpd"))
		var paths: PackedStringArray = _tree.paths()
		var count_before: int = _world.brick_count()
		var before: String = _save()
		var depth: int = _builder.history_depth()
		var target: BrickWorld.Brick = null
		var plate_id: String = _library.resolve("4073")
		var round_id: String = _library.resolve("3062b")
		for brick: BrickWorld.Brick in _world.bricks():
			if Assemblies.path_of(brick) == str(spec[0]) \
					and brick.part_id == _library.resolve(str(spec[1])):
				target = brick
		if target == null:
			print("  parts: %s" % ", ".join(_world.bricks().map(func(b: BrickWorld.Brick) -> String:
				return "%s %s" % [b.part_id, Assemblies.path_of(b)])))
		if target == null:
			_check("%s: the part is there (%s)" % [name, str(paths)], false)
			continue
		var per_before: Dictionary = {}
		for p: String in paths:
			per_before[p] = _wr_parts(p)
		var said: String = await _lift_put([target.id], spec[2])
		var after: String = _save()
		var through: Array = _through()
		print("  %s; history %d -> %d; %d parts -> %d; bar \"%s\"" % [said, depth,
			_builder.history_depth(), count_before, _world.brick_count(), _bar_text().left(160)])
		var ok: bool = _builder.history_depth() > depth
		ok = _check("%s: made, %d parts (were %d), nothing through (%s)" % [name, _world.brick_count(),
			count_before, ", ".join(through)], ok and _world.brick_count() == count_before
			and through.is_empty()) and ok
		for p: String in paths:
			var now: PackedStringArray = _wr_parts(p)
			if now.size() != (per_before[p] as PackedStringArray).size() or now != per_before[p]:
				print("  %s: %s  ->  %s" % [p, ", ".join(per_before[p]), ", ".join(now)])
			ok = _check("%s: %s keeps its count (%d, were %d)" % [name, p, now.size(),
				(per_before[p] as PackedStringArray).size()],
				now.size() == (per_before[p] as PackedStringArray).size()) and ok
		# Each wheel's plate where the edited wheel's went, in its frame: the
		# four wheels' plates all a stud along alike, or all back in place.
		if str(spec[1]) == "4073":
			var local: Array = []
			for p: String in paths:
				if not Assemblies.leaf(p).begins_with("Wheel"):
					continue
				var plate: BrickWorld.Brick = _in(p, plate_id)
				var round: BrickWorld.Brick = _in(p, round_id)
				if plate == null or round == null:
					local.append("%s: missing" % p)
					continue
				local.append(str((plate.transform.origin - round.transform.origin).snappedf(0.1)))
			var alike: bool = local.all(func(v: String) -> bool: return v == str(local[0]))
			ok = _check("%s: every wheel's plate where the edited one's went, against its round brick (%s)"
				% [name, ", ".join(local)], alike and local.size() == 4) and ok
		if _builder.history_depth() > depth:
			_shell.run("undo")
			await _frames(6)
			var undone: String = _save()
			_shell.run("redo")
			await _frames(6)
			var redone: String = _save()
			ok = _check("%s: undo byte for byte, redo the edit" % name, undone == before and redone == after) and ok
			await _open(after)
			ok = _check("%s: saved and opened again, the same file" % name, _save() == after) and ok
		_table.append("%-40s %s" % [name, "pass" if ok else "FAIL"])


# -- meets ----------------------------------------------------------------------


func _meets_cases() -> void:
	print("\n== meets: Assemblies._meets against the plain scan")
	var text: String = FileAccess.get_file_as_string("res://vendor/omr/files/10179-1.mpd")
	if text.is_empty():
		_check("meets: 10179-1.mpd read", false)
		return
	await _open(text)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261125
	var copies: Array = ["", "A", "A/B", "C", "C/D#2"]
	var down: Array = []
	var blocks: Dictionary = {}
	var all: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var cells: PackedInt32Array = _builder.boxes_for(mesh, brick.transform)
		if cells.is_empty():
			continue
		all.append([brick.part_id, cells])
	# In a random order, each "going into" a random copy; stacked: some put
	# down twice, as equal parts are.
	var order: Array = range(all.size())
	for n: int in range(order.size() - 1, 0, -1):
		var m: int = rng.randi_range(0, n)
		var t: Variant = order[n]
		order[n] = order[m]
		order[m] = t
	for k: int in order:
		var one: Array = all[k]
		var entry: Array = [one[0], one[1], copies[rng.randi_range(0, copies.size() - 1)]]
		Assemblies._put_down(down, blocks, entry, Assemblies._blocks_of(one[1]))
		if rng.randf() < 0.05:
			Assemblies._put_down(down, blocks, [one[0], one[1], copies[rng.randi_range(0, copies.size() - 1)]],
				Assemblies._blocks_of(one[1]))
	var differ: int = 0
	var met: int = 0
	var asked: int = 0
	var shown: int = 0
	# Each entry's whole extent, so the plain scan skips at once what cannot
	# share a cell (shared_cells > 0 only where the extents overlap): the same
	# answer as the scan, in a fraction of its time.
	var extent: Array = down.map(func(d: Array) -> AABB: return _extent_of(d[1]))
	var count: int = int(OS.get_environment("WR3_MEETS")) if not OS.get_environment("WR3_MEETS").is_empty() else 3000
	for q: int in count:
		var one: Array = all[rng.randi_range(0, all.size() - 1)]
		var shift := Vector3i(rng.randi_range(-45, 45), rng.randi_range(-12, 12), rng.randi_range(-45, 45))
		if q % 4 == 0:
			shift = Vector3i.ZERO
		elif q % 4 == 1:
			# One cell over a block's edge either way.
			shift = Vector3i(rng.randi_range(-1, 1), 0, rng.randi_range(-1, 1))
		var cells: PackedInt32Array = BrickLattice.moved_by(one[1], shift)
		var copy: String = copies[rng.randi_range(0, copies.size() - 1)]
		var fast: String = Assemblies._meets(down, blocks, cells, Assemblies._blocks_of(cells), copy)
		var plain: String = ""
		var plain_k: int = -1
		var mine: AABB = _extent_of(cells)
		for k: int in down.size():
			var d: Array = down[k]
			if not mine.intersects(extent[k] as AABB):
				continue
			if not Assemblies.within(str(d[2]), copy) and BrickLattice.shared_cells(cells, d[1]) > 0:
				plain = str(d[0])
				plain_k = k
				break
		asked += 1
		if not plain.is_empty():
			met += 1
		if fast != plain:
			differ += 1
			if shown < 5:
				shown += 1
				print("  differs: %s shifted %s into \"%s\": fast \"%s\", plain \"%s\" (#%d)" % [one[0],
					str(shift), copy, fast, plain, plain_k])
	_check("meets: %d asks over %d parts of 10179 (%d filed): %d met something, %d differ from the plain scan"
		% [asked, all.size(), down.size(), met, differ], differ == 0 and met > 1000)
	_table.append("%-40s %s" % ["meets vs plain scan", "pass" if differ == 0 else "FAIL"])


## The cells' whole extent as a box (half-open, as the boxes are): two boxes
## that share a cell have extents that overlap by a cell or more.
static func _extent_of(cells: PackedInt32Array) -> AABB:
	var lo := Vector3(1 << 30, 1 << 30, 1 << 30)
	var hi := Vector3(-(1 << 30), -(1 << 30), -(1 << 30))
	var n: int = 0
	while n < cells.size():
		lo = lo.min(Vector3(cells[n], cells[n + 1], cells[n + 2]))
		hi = hi.max(Vector3(cells[n + 3], cells[n + 4], cells[n + 5]))
		n += 6
	# Shrunk a hair: boxes that only touch must not count as overlapping, and
	# AABB.intersects is true for those that touch.
	return AABB(lo + Vector3.ONE * 0.25, hi - lo - Vector3.ONE * 0.5)


# -- ask ------------------------------------------------------------------------


const ASK_PARTS: Array = ["3001", "3004", "3020", "3024", "3023", "3069b", "3062b", "4073",
	"87087", "99780", "2429", "2430", "3937", "3938", "4070", "44728", "2436", "60478",
	"30414", "3040", "3665", "2420", "3794b", "3003", "3034"]


func _ask_cases() -> void:
	print("\n== ask: room_in_copies against wingplace's (8d0034b64)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1125
	var parts: Array = ASK_PARTS.filter(func(p: String) -> bool: return _library.mesh_for(p) != null)
	print("  parts with shapes: %s" % ", ".join(parts))
	var lines := PackedStringArray(["0 FILE main.ldr", "0 Main", "0 Name: main.ldr", "0 Author: Brickworks", "",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 big.ldr",
		"1 16 -3000 0 0 -1 0 0 0 1 0 0 0 1 big.ldr",
		# Turned a quarter where the first stands: its twins land among the
		# first's parts and the hand's.
		"1 16 0 0 0 0 0 1 0 1 0 -1 0 0 big.ldr"])
	var turns: Array = ["1 0 0 0 1 0 0 0 1", "0 0 1 0 1 0 -1 0 0", "-1 0 0 0 1 0 0 0 -1",
		"0 0 -1 0 1 0 1 0 0", "1 0 0 0 0 -1 0 1 0", "1 0 0 0 0 1 0 -1 0", "0 1 0 -1 0 0 0 0 1"]
	# The model's own loose parts where the mirrored copy stands.
	for n: int in 400:
		lines.append("1 7 %s %s %s %s %s.dat" % [_num(-3000 + rng.randi_range(-50, 50) * 20.0),
			_num(-rng.randi_range(0, 12) * 8.0), _num(rng.randi_range(-50, 50) * 20.0),
			turns[rng.randi_range(0, turns.size() - 1)], parts[rng.randi_range(0, parts.size() - 1)]])
	lines.append_array(["0", "0 NOFILE", "0 FILE big.ldr", "0 Big", "0 Name: big.ldr", "0 Author: Brickworks", ""])
	for n: int in 1500:
		var x: float = rng.randi_range(-50, 50) * 20.0 + (5.0 if rng.randf() < 0.08 else 0.0)
		var z: float = rng.randi_range(-50, 50) * 20.0 + (10.0 if rng.randf() < 0.3 else 0.0)
		var y: float = -rng.randi_range(0, 12) * 8.0 + (4.0 if rng.randf() < 0.05 else 0.0)
		lines.append("1 %d %s %s %s %s %s.dat" % [rng.randi_range(0, 15), _num(x), _num(y), _num(z),
			turns[rng.randi_range(0, turns.size() - 1)], parts[rng.randi_range(0, parts.size() - 1)]])
	lines.append_array(["0", "0 NOFILE"])
	await _open("\n".join(lines) + "\n")
	var copies: PackedStringArray = _tree.copies_of("Big#1")
	print("  Big's copies: %s; %d parts" % [str(_tree.paths()), _world.brick_count()])
	_tree.enter("Big#1")
	await _frames(2)
	print("  copies laid on Big#1: %d" % _tree._copies_laid("Big#1").size())
	var differ: int = 0
	var red: int = 0
	var asked: int = 0
	var shown: int = 0
	var slow_new: int = 0
	var slow_old: int = 0
	var reasons: Dictionary = {}
	for h: int in 300:
		var items: Array = []
		var size: int = rng.randi_range(1, 12) if h % 10 != 0 else rng.randi_range(40, 120)
		for k: int in size:
			# Each on a spot of its own, 3 studs apart, so a hand is not in
			# its own way; some a hair off the grid.
			var at := Transform3D(Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5),
				Vector3((k % 6) * 60.0 + (5.0 if rng.randf() < 0.1 else 0.0), (k / 36) * 40.0,
					((k / 6) % 6) * 60.0))
			items.append([parts[rng.randi_range(0, parts.size() - 1)], at, "Big#1"])
		for f: int in 3:
			var frame := Transform3D(Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5),
				# World y is up (LdrModel.FLIP): on the ground or above it.
				Vector3(rng.randi_range(-50, 50) * 20.0 + (10.0 if f == 2 else 0.0), rng.randi_range(0, 16) * 8.0,
					rng.randi_range(-50, 50) * 20.0))
			var world_items: Array = items.map(func(i: Array) -> Array:
				return [i[0], frame * (i[1] as Transform3D), i[2]])
			var t0: int = Time.get_ticks_usec()
			var fresh: Variant = _tree.room_in_copies({"items": items, "frame": frame}, 0)
			var t1: int = Time.get_ticks_usec()
			var old: Variant = _old_room({"items": world_items}, 0)
			var t2: int = Time.get_ticks_usec()
			slow_new += t1 - t0
			slow_old += t2 - t1
			# And over several frames, a budget of 50 us, the same items again.
			var stepped: Variant = null
			var ask: Dictionary = {"items": items, "frame": frame}
			for _s: int in 100000:
				stepped = _tree.room_in_copies(ask, 50)
				if stepped != null:
					break
			asked += 1
			if str(fresh) != "":
				red += 1
				var why: String = str(fresh).left(40)
				reasons[why] = int(reasons.get(why, 0)) + 1
			if str(fresh) != str(old) or str(stepped) != str(old):
				differ += 1
				if shown < 6:
					shown += 1
					print("  differs: hand %d frame %d (%d parts): new \"%s\", stepped \"%s\", old \"%s\"" % [h, f,
						items.size(), str(fresh), str(stepped), str(old)])
	_tree.leave_to("")
	print("  red for: %s" % str(reasons))
	_check("ask: %d asks (%d hands, 3 frames each): %d red; %d differ from wingplace's; %d us new, %d us old in all"
		% [asked, 300, red, differ, slow_new, slow_old], differ == 0 and red > 20 and red < asked)
	_table.append("%-40s %s" % ["ask vs wingplace's", "pass" if differ == 0 else "FAIL"])


static func _num(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else str(value)


## Assemblies.room_in_copies as wingplace (8d0034b64) had it: items in the
## world, each ask reading the hand afresh, the plain scan.
func _old_room(ask: Dictionary, budget_us: int = 0) -> Variant:
	var items: Array = ask.get("items", [])
	if items.is_empty():
		return ""
	var library: PartLibrary = _tree.library
	if not ask.has("pairs"):
		var going: Array = []
		var by_level: Dictionary = {}
		var level_of: Dictionary = {}
		for item: Array in items:
			var real: String = library.resolve(str(item[0]))
			var at: Transform3D = (item[1] as Transform3D) * library.moved_by(str(item[0]))
			var into: String = str(item[2]) if item.size() > 2 else _tree.entered
			if not level_of.has(into):
				level_of[into] = _tree._changed_level(into)
			var level: String = level_of[into]
			going.append([real, at, level])
			if not level.is_empty():
				if not by_level.has(level):
					by_level[level] = []
				(by_level[level] as Array).append([real, at])
		var pairs: Array = []
		for level: String in by_level:
			var copies: Array = _tree._copies_laid(level)
			for c: int in range(copies.size() - 1, -1, -1):
				for one: Array in by_level[level]:
					pairs.append([copies[c], one])
		if pairs.is_empty():
			return ""
		ask.merge({"pairs": pairs, "going": going, "down": [], "cells": 0, "laid": {}, "next": 0})
	var pairs: Array = ask["pairs"]
	var going_down: Array = ask["going"]
	var down: Array = ask["down"]
	var laid_already: Dictionary = ask["laid"]
	while int(ask["cells"]) < going_down.size():
		var one: Array = going_down[int(ask["cells"])]
		ask["cells"] = int(ask["cells"]) + 1
		var mine: Lbm.PartMesh = library.mesh_for(str(one[0]))
		if mine != null:
			down.append([str(one[0]), _builder.boxes_for(mine, one[1]), str(one[2])])
	while int(ask["next"]) < pairs.size():
		var n: int = int(ask["next"])
		ask["next"] = n + 1
		var copy: Array = pairs[n][0]
		var item: Array = pairs[n][1]
		var other: String = copy[0]
		var laid: Array = _tree._laid(copy[1], str(item[0]), item[1])
		var at: Transform3D = laid[1]
		var mesh: Lbm.PartMesh = library.mesh_for(str(laid[0]))
		var key: String = "%s %s %s" % [other, laid[0], str(at.origin.snappedf(0.5))]
		if mesh == null or laid_already.has(key):
			continue
		laid_already[key] = true
		var blocker: int = _tree.in_the_way(str(laid[0]), at, 0, copy[2])
		if blocker > 0 and _tree._round_out(copy):
			blocker = _tree.in_the_way(str(laid[0]), at, 0, copy[2])
		if blocker != 0:
			return _tree.room_words(other, blocker)
		var cells: PackedInt32Array = _builder.boxes_for(mesh, at)
		for pass_n: int in 2:
			var met: String = ""
			for one: Array in down:
				if not Assemblies.within(str(one[2]), str(copy[3])) \
						and BrickLattice.shared_cells(cells, one[1]) > 0:
					met = str(one[0])
					break
			if met.is_empty():
				break
			if pass_n == 1 or not _tree._round_out(copy):
				return _tree._room_words_part(other, met)
		down.append([str(laid[0]), cells, other])
	return ""
