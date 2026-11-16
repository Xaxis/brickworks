## A sub-model's copies follow an edit only where every copy can take it
## (followfix). A sub-model's copies are one definition, as Studio and
## LeoCAD hold them, so an edit to one copy is made in all of them or in
## none:
## - a part locked in any copy refuses the edit in all ("Locked in one copy
##   of Sill: Plate 1 x 2. Unlock it, or use Build › Make this copy unique");
## - a copy with no room for what the edit would lay or move there, as a
##   part put there by hand would have none, refuses it in all ("No room in
##   Sill (copy 2): Plate 1 x 1 is in the way there. Move it, or use Build ›
##   Make this copy unique");
## - a copy that can take it follows as before.
## Up to swreview (2026-11-15) a twin followed through its lock, and a
## follow was laid through the other copy's neighbours and saved so.
##
## Each edit made as a person makes it (paint, Replace with the part in
## hand, a drag, a turn, Delete, a copy pasted into a copy) and as a
## session makes it over MCP (edit_model's recolor, swap, move, turn,
## remove), on Sill placed twice, with the twin free, locked, or with a
## part where it would go. A refused edit leaves the file byte for byte, no
## history step, the lock where it was, and the words on the bar (or in the
## session's answer); an allowed one is undone by one undo byte for byte,
## and redone as made. Nothing is ever through a part. Then the attacks: a
## mirrored copy, a sub-model placed three times inside another, a copy
## written as a definition of its own, a Build together room (a refusal
## sends nothing), undo and redo round a refusal, the save opened again, and
## live's save and back. And what is not in a twin's way (flfix): a part
## outside its copy it met already where it stood, where they share no more
## cells after ("met": the same refused where they share more), and real
## sets' parts that stand in others, nudged a plate as the review found them
## refused ("real": 10179's axle #1028 through a 2 x 12 plate of another
## sub-model, its bush #1030 and axle #1076; 10030's tap #446, whose tilted
## twin's cover met its own copy's grille): each made, every copy with it.
##
##   godot --headless --path . --script src/dev/followfix_probe.gd
##
##   FOLLOWFIX_CASES=paint,mcp_move,mirror   those cases
##   LIVE_SAVED=F [LIVE_OURS=G] [LIVE_READ=H]   the live round trip: F Sill
##     placed twice as live's build saved it, G where ours after a drag is
##     written, H live's save of G; without F the case skips, saying so. A
##     worktree at the live sha writes F and H with a one-off headless
##     script that opens through ModelBar.open_text_with_progress and saves
##     ModelStore.to_text(title, true).
extends "res://src/dev/copyfaults_probe.gd"

## Each edit, by hand and over MCP, with the twins it is tried with.
const FOLLOW_EDITS: Dictionary = {
	"paint": ["free", "locked"], "replace": ["free", "locked", "room"],
	"drag": ["free", "locked", "room"], "rotate": ["free", "locked", "room"],
	"delete": ["free", "locked"], "paste": ["free", "room"],
	"mcp_paint": ["free", "locked"], "mcp_swap": ["free", "locked", "room"],
	"mcp_move": ["free", "locked", "room"], "mcp_turn": ["free", "locked", "room"],
	"mcp_delete": ["free", "locked"]}
const ATTACKS: Array = ["mirror", "nested", "own_definition", "together", "undo_redo", "reopen",
	"live", "met", "real"]

## Real sets' edits no copy may refuse (flfix): [the file in vendor/omr/files,
## the part nudged, its part]. Each a plate up by the move handles, as the
## review's sweep made it.
const REAL_ALLOWED: Array = [["10179-1.mpd", 1028, "44294"], ["10179-1.mpd", 1030, "32123a"],
	["10179-1.mpd", 1076, "44294"], ["10030-1.mpd", 446, "4599a"]]

## Sill: a red 2 x 4 brick, a black 1 x 2 plate and a yellow 1 x 1 plate on
## it. Each edit is made in the copy at the origin; its twin is in the copy
## 200 LDU along z (or as [method _file] places it).
const SILL := """0 FILE sill.ldr
0 Sill
0 Name: sill.ldr
0 Author: Brickworks

1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 0 -20 -8 -10 1 0 0 0 1 0 0 0 1 3023.dat
1 14 30 -8 10 1 0 0 0 1 0 0 0 1 3024.dat
0
0 NOFILE
"""
const SECOND := "1 16 0 0 200 1 0 0 0 1 0 0 0 1 sill.ldr"
const MIRRORED := "1 16 0 0 200 -1 0 0 0 1 0 0 0 1 sill.ldr"

## Where each edit's twin goes in the copy at z 200, in the copy's frame: a
## blue 1 x 1 plate there (outside Sill) leaves it no room. Each is clear
## of the copy as it stands.
const BLOCKERS: Dictionary = {
	# The 1 x 2 plate made a 1 x 2 brick in place reaches 3 plates up.
	"replace": Vector3(-30, -16, -10), "mcp_swap": Vector3(-30, -16, -10),
	# The yellow 1 x 1 dragged a stud along x, off the brick's end; moved by
	# a session a stud the other way, still on the brick (a session's edit
	# leaving a part held by nothing is refused for that, before any copy).
	"drag": Vector3(50, -8, 10), "mcp_move": Vector3(10, -8, 10),
	# The 1 x 2 plate turned a quarter by R: kept on the studs, it lies along
	# z from -40 to 0 at x -40 to -20.
	"rotate": Vector3(-30, -8, -30),
	# A session's turn is about the middle, so the plate is first moved half
	# a stud each way to turn onto the studs (a session's z is the file's
	# turned round): along z from -40 to 0 at x -20 to 0.
	"mcp_turn": Vector3(-10, -8, -30),
	# The yellow 1 x 1 pasted at the stud (-30, 10).
	"paste": Vector3(-30, -8, 10)}

const LOCK_WORDS := "Locked in one copy of Sill"
const ROOM_WORDS := "No room in Sill (copy 2)"

var _verbs: EditVerbs
var _bar_main: ModelBar
var _assemblies: Assemblies
## The table the report quotes: one line a case.
var _table := PackedStringArray()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(2400.0).timeout.connect(func() -> void:
		print("followfix probe: not finished in time")
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
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	_verbs = _main.get("_verbs")
	_bar_main = _main.get("_bar")
	_assemblies = _shell.assemblies
	var only: PackedStringArray = OS.get_environment("FOLLOWFIX_CASES").split(",", false)
	for edit: String in FOLLOW_EDITS:
		if not only.is_empty() and not edit in only:
			continue
		for twin: String in FOLLOW_EDITS[edit]:
			print("\n== %s, the twin %s" % [edit, twin])
			await _case(edit, twin)
	for attack: String in ATTACKS:
		if not only.is_empty() and not attack in only:
			continue
		print("\n== %s" % attack)
		match attack:
			"mirror": await _attack_mirror()
			"nested": await _attack_nested()
			"own_definition": await _attack_own_definition()
			"together": await _attack_together()
			"undo_redo": await _attack_undo_redo()
			"reopen": await _attack_reopen()
			"live": await _attack_live()
			"met": await _attack_met()
			"real": await _attack_real()
	print("\nthe table:")
	for line: String in _table:
		print("  " + line)
	print("\nfollowfix probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- the file --------------------------------------------------------------------


## Sill placed at the origin and as [param second] places it, with a blue
## 1 x 1 plate where [param blocker] says in the second's frame (none for
## null).
func _file(blocker: Variant = null, second: String = SECOND) -> String:
	var lines := PackedStringArray(["0 FILE main.ldr", "0 Main", "0 Name: main.ldr",
		"0 Author: Brickworks", "", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 sill.ldr", second])
	if blocker is Vector3:
		var frame: Transform3D = _placed_by(second)
		var at: Vector3 = frame * (blocker as Vector3)
		lines.append("1 1 %s %s %s 1 0 0 0 1 0 0 0 1 3024.dat" % [_n(at.x), _n(at.y), _n(at.z)])
	lines.append_array(["0", "0 NOFILE"])
	return "\n".join(lines) + "\n" + SILL


static func _n(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else str(value)


## The frame an LDraw type 1 line [param line] places its file in.
static func _placed_by(line: String) -> Transform3D:
	var f: PackedStringArray = line.split(" ", false)
	var basis := Basis(Vector3(float(f[5]), float(f[8]), float(f[11])),
		Vector3(float(f[6]), float(f[9]), float(f[12])),
		Vector3(float(f[7]), float(f[10]), float(f[13])))
	return Transform3D(basis, Vector3(float(f[2]), float(f[3]), float(f[4])))


## The copies of Sill, by where each stands: [the one edited, its twin].
func _sills() -> Array:
	var near: String = ""
	var far: String = ""
	for brick: BrickWorld.Brick in _world.bricks():
		var path: String = Assemblies.path_of(brick)
		if not Assemblies.definition(Assemblies.leaf(path)).begins_with("Sill"):
			continue
		if brick.part_id.begins_with("3001"):
			if absf(brick.transform.origin.z) < 100.0:
				near = path
			else:
				far = path
	return [near, far]


## The part [param part] (its number's start) in the copy at [param path].
func _in(path: String, part: String) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path and brick.part_id.begins_with(part):
			return brick
	return null


## What the bar says now, as a person reads it.
func _bar_text() -> String:
	return (_bar_main.get("_status") as Label).text


## Every part that shares a cell of the lattice with another, as swreview
## found the follow's (these files' parts meet only stud to hole, which no
## cell is shared by): "part #id through part #id" each. Asked as pre261
## can, for the red run.
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


# -- each edit ------------------------------------------------------------------


## [param edit] made in the near copy, with its twin in the far copy
## [param twin]: "free", "locked" (the twin locked first) or "room" (a part
## where the twin would go).
func _case(edit: String, twin: String) -> void:
	await _open(_file(BLOCKERS.get(edit) if twin == "room" else null))
	var sills: Array = _sills()
	var part: String = "3024" if edit in ["drag", "mcp_move", "delete", "mcp_delete", "paste"] \
		else "3023"
	var mine: BrickWorld.Brick = _in(sills[0], part)
	var theirs: BrickWorld.Brick = _in(sills[1], part)
	if mine == null or theirs == null:
		_check("%s/%s: Sill's two copies opened (%s)" % [edit, twin, str(sills)], false)
		return
	if twin == "locked":
		_pick([theirs.id])
		_builder.lock_selection(true)
	var through_before: Array = _through()
	var before: String = _save()
	var depth: int = _builder.history_depth()
	var was_twin: String = _state(theirs.id)
	var said: String = await _make(edit, mine, sills[0])
	await _frames(6)
	var after: String = _save()
	var through: Array = _through()
	var twin_now: String = _state(theirs.id)
	var copies: String = _twin_part_now(sills[1], part, theirs.id)
	print("  %s; twin was %s, now %s; history %d -> %d; bar \"%s\"" % [said.left(300), was_twin,
		twin_now, depth, _builder.history_depth(), _bar_text()])
	if not through.is_empty():
		print("  through: %s" % ", ".join(through))
	var mcp: bool = edit.begins_with("mcp_")
	var words: String = said if mcp else _bar_text()
	var ok: bool = through_before.is_empty() and through.is_empty()
	match twin:
		"free":
			var followed: bool = _followed(edit, was_twin, copies, theirs.id)
			ok = _check("%s, twin free: the edit made and its twin followed (%s), one step, nothing through"
				% [edit, copies], followed and after != before
				and _builder.history_depth() == depth + 1 and through.is_empty()) and ok
			# One undo puts the file back byte for byte; a redo makes it again.
			_shell.run("undo")
			await _frames(6)
			var undone: String = _save()
			_shell.run("redo")
			await _frames(6)
			var redone: String = _save()
			ok = _check("%s: one undo gives the file back byte for byte, a redo the edit again"
				% edit, undone == before and redone == after) and ok
		"locked", "room":
			var wanted: String = LOCK_WORDS if twin == "locked" else ROOM_WORDS
			ok = _check("%s, twin %s: refused, the file byte for byte, no history step, said (\"%s\")"
				% [edit, twin, words.left(200)], after == before
				and _builder.history_depth() == depth and twin_now == was_twin
				and words.contains(wanted) and through.is_empty()) and ok
			if twin == "locked":
				ok = _check("%s: the twin still locked" % edit,
					_builder.is_locked(theirs.id)) and ok
			# What a session reads: nothing done, and why.
			if mcp:
				ok = _check("%s: the session told nothing was done" % edit,
					said.contains("Not done, and nothing changed")) and ok
	_table.append("%-11s %-6s %s" % [edit, twin, "pass" if ok else "FAIL"])
	_builder.unlock_all()


## The edit [param edit] made of [param mine] (in the copy at [param path])
## as a person or a session makes it. What it said, or the session's answer.
func _make(edit: String, mine: BrickWorld.Brick, path: String) -> String:
	match edit:
		"paint":
			_pick([mine.id])
			_builder.held_color = 2
			_verbs.press("paint")
			return "painted #%d green" % mine.id
		"replace":
			_pick([mine.id])
			_builder.held_part = "3004"
			var swapped: int = await _verbs.replace()
			return "replaced #%d with a 3004: %d" % [mine.id, swapped]
		"drag":
			# The move handles' drag (Handles): picked up, let go a stud along.
			_pick([mine.id])
			_builder.drag_begin()
			var moved: int = _builder.drag_end(Transform3D(Basis.IDENTITY, Vector3(20, 0, 0)))
			_verbs.edited.call()
			return "dragged #%d a stud: %d" % [mine.id, moved]
		"rotate":
			_pick([mine.id])
			var turned: int = _verbs.turn_by(90.0)
			return "turned #%d a quarter: %d" % [mine.id, turned]
		"delete":
			_pick([mine.id])
			await _verbs.press("delete")
			return "deleted #%d" % mine.id
		"paste":
			# Copied, the copy entered, and the copy put down at the stud
			# (-30, 10) of its brick, as a click puts it.
			_pick([mine.id])
			_verbs.copy()
			_assemblies.enter(path)
			_builder.clear_selection()
			_verbs.paste()
			var carry: Carry = _builder.carrying
			var put: int = 0
			if carry != null:
				carry.stand_where_lifted(_builder.lattice, _builder)
				carry.pin()
				if carry.show_moved(Transform3D(Basis.IDENTITY, Vector3(-60, 0, 0)), _builder.lattice,
						_builder):
					put = _builder.place()
					_verbs.edited.call()
				_builder.cancel_carry()
			await _frames(4)
			_assemblies.leave_to("")
			return "pasted a copy of #%d in %s: #%d" % [mine.id, path, put]
		"mcp_paint":
			return await _say("edit_model", {"recolor": [{"bricks": [mine.id], "color": 2}],
				"picture": false})
		"mcp_swap":
			var at: Dictionary = _placement_of(mine.id)
			var one: Dictionary = {"part": "3004", "color": mine.color_code}
			for key: String in ["x", "y", "z", "face", "rot"]:
				if at.has(key):
					one[key] = at[key]
			return await _say("edit_model", {"remove": [mine.id], "add": [one], "picture": false})
		"mcp_move":
			return await _say("edit_model", {"move": [{"bricks": [mine.id], "dx": -1}],
				"picture": false})
		"mcp_turn":
			# Turned about its middle a 1 x 2 stands between studs, which the
			# session's check refuses; half a stud each way first puts it on them.
			return await _say("edit_model", {"move": [{"bricks": [mine.id], "dx": 0.5, "dz": 0.5}],
				"turn": [{"bricks": [mine.id], "yaw": 90}], "picture": false})
		"mcp_delete":
			return await _say("edit_model", {"remove": [mine.id], "picture": false})
	return "no such edit"


## A part as it stands, to compare: "part colour place", or "gone".
func _state(brick_id: int) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	if brick == null:
		return "gone"
	return "%s c%d %s %s" % [brick.part_id, brick.color_code, brick.transform.origin.snapped(
		Vector3.ONE * 0.1), brick.transform.basis.get_euler().snapped(Vector3.ONE * 0.01)]


## The far copy's parts of [param part]'s kind and what stands in its place,
## said: "3024 c14 (...)", for the line.
func _twin_part_now(path: String, part: String, was: int) -> String:
	var out := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path and not brick.part_id.begins_with("3001"):
			out.append("%s%s c%d at %s" % ["" if brick.id == was else "new ", brick.part_id,
				brick.color_code, brick.transform.origin.snapped(Vector3.ONE * 0.1)])
	return "; ".join(out)


## Whether the far copy's part, [param was_twin] before, took [param edit].
func _followed(edit: String, was_twin: String, copies: String, twin_id: int) -> bool:
	var now: String = _state(twin_id)
	match edit:
		"paint", "mcp_paint":
			return now.contains(" c2 ")
		"replace", "mcp_swap":
			return now == "gone" and copies.contains("new 3004")
		"drag", "mcp_move", "rotate", "mcp_turn":
			return now != "gone" and now != was_twin
		"delete", "mcp_delete":
			return now == "gone"
		"paste":
			return copies.contains("new 3024")
	return false


# -- the attacks ------------------------------------------------------------------


## A copy placed by a mirror: a drag follows, the other way; a lock in it
## refuses; a part where its mirrored drag goes refuses (in the copy's own
## frame the drag's place, which the mirror puts at -x).
func _attack_mirror() -> void:
	for twin: String in ["free", "locked", "room"]:
		await _open(_file(BLOCKERS["drag"] if twin == "room" else null, MIRRORED))
		var sills: Array = _sills()
		var mine: BrickWorld.Brick = _in(sills[0], "3024")
		var theirs: BrickWorld.Brick = _in(sills[1], "3024")
		if mine == null or theirs == null:
			_check("mirror: two copies (%s)" % str(sills), false)
			continue
		if twin == "locked":
			_pick([theirs.id])
			_builder.lock_selection(true)
		var before: String = _save()
		var was: String = _state(theirs.id)
		await _make("drag", mine, sills[0])
		await _frames(6)
		var now: String = _state(theirs.id)
		var through: Array = _through()
		print("  mirrored twin %s -> %s; bar \"%s\"; through %s" % [was, now, _bar_text(), through])
		var ok: bool
		if twin == "free":
			# Mirrored, a stud along +x in the near copy is a stud along -x.
			ok = _check("mirror: a drag followed in the mirrored copy, the other way",
				now != was and theirs.transform.origin.x < -40.0 and through.is_empty())
		else:
			ok = _check("mirror, twin %s: refused, the file byte for byte (\"%s\")" % [twin,
				_bar_text()], _save() == before and now == was and through.is_empty()
				and _bar_text().contains(LOCK_WORDS if twin == "locked" else ROOM_WORDS))
		_table.append("%-11s %-6s %s" % ["mirror", twin, "pass" if ok else "FAIL"])
		_builder.unlock_all()


const WINDOW := """0 FILE win.mpd
0 Win
0 Name: win.mpd
0 Author: Brickworks

1 16 0 0 0 1 0 0 0 1 0 0 0 1 win.ldr
1 16 0 0 200 1 0 0 0 1 0 0 0 1 win.ldr
1 16 0 0 400 1 0 0 0 1 0 0 0 1 win.ldr
%s0
0 NOFILE
0 FILE win.ldr
0 Win
0 Name: win.ldr
0 Author: Brickworks

1 7 0 24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 0 0 1 0 0 0 1 0 0 0 1 sill.ldr
0
0 NOFILE
"""


## Sill inside Win, Win placed three times: a drag in the first Win's Sill
## follows into all three; a lock in the third's refuses it; a part where
## the third's drag goes refuses it.
func _attack_nested() -> void:
	for twin: String in ["free", "locked", "room"]:
		var extra: String = "1 1 50 -8 410 1 0 0 0 1 0 0 0 1 3024.dat\n" if twin == "room" else ""
		await _open(WINDOW % extra + SILL)
		var plates: Array = []          ## the yellow 1 x 1 of each Win's Sill, by the file's z
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id.begins_with("3024") and brick.color_code == 14:
				plates.append(brick)
		# The scene's z is the file's turned round: Win#1's at -10, Win#3's at -410.
		plates.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
			return a.transform.origin.z > b.transform.origin.z)
		if plates.size() != 3:
			_check("nested: three Sills (%d)" % plates.size(), false)
			continue
		var mine: BrickWorld.Brick = plates[0]
		var third: BrickWorld.Brick = plates[2]
		print("  paths: %s" % ", ".join(plates.map(func(b: BrickWorld.Brick) -> String:
			return Assemblies.path_of(b))))
		if twin == "locked":
			_pick([third.id])
			_builder.lock_selection(true)
		var before: String = _save()
		var was: Array = plates.map(func(b: BrickWorld.Brick) -> String: return _state(b.id))
		var depth: int = _builder.history_depth()
		await _make("drag", mine, Assemblies.path_of(mine))
		await _frames(6)
		var now: Array = plates.map(func(b: BrickWorld.Brick) -> String: return _state(b.id))
		var through: Array = _through()
		print("  %s -> %s; history %d -> %d; refused \"%s\"; bar \"%s\"" % [was, now, depth,
			_builder.history_depth(), _assemblies.get("refused"), _bar_text()])
		var ok: bool
		if twin == "free":
			ok = _check("nested: a drag in Win#1's Sill followed in all three, one step",
				now[1] != was[1] and now[2] != was[2] and _builder.history_depth() == depth + 1
				and through.is_empty())
			_shell.run("undo")
			await _frames(6)
			ok = _check("nested: one undo, the file byte for byte", _save() == before) and ok
		else:
			ok = _check("nested, the third's twin %s: refused in all three (\"%s\")" % [twin,
				_bar_text()], _save() == before and now == was and through.is_empty()
				and _builder.history_depth() == depth
				and _bar_text().contains("Locked in one copy of Sill" if twin == "locked"
					else "No room in Sill"))
		_table.append("%-11s %-6s %s" % ["nested", twin, "pass" if ok else "FAIL"])
		_builder.unlock_all()


## Sill and Sill2, alike part for part but two definitions: no copies of
## each other, so an edit of one is not made in the other, and a lock in
## the other refuses nothing.
func _attack_own_definition() -> void:
	var own: String = SILL.replace("sill.ldr", "sill2.ldr").replace("0 Sill\n", "0 Sill2\n")
	var text: String = _file(null, "1 16 0 0 200 1 0 0 0 1 0 0 0 1 sill2.ldr") + own
	await _open(text)
	var near: BrickWorld.Brick = null
	var far: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("3023"):
			# The scene's z is the file's turned round: the far copy's is -190.
			if absf(brick.transform.origin.z) < 100.0:
				near = brick
			else:
				far = brick
	if near == null or far == null:
		_check("own_definition: both opened", false)
		return
	print("  near in %s, far in %s" % [Assemblies.path_of(near), Assemblies.path_of(far)])
	_pick([far.id])
	_builder.lock_selection(true)
	var was: String = _state(far.id)
	var depth: int = _builder.history_depth()
	await _make("paint", near, Assemblies.path_of(near))
	await _frames(6)
	var ok: bool = _check("own_definition: the paint made (#%d %s), the other definition's part as it was, locked or not (bar \"%s\")"
		% [near.id, _state(near.id), _bar_text()], _state(near.id).contains(" c2 ")
		and _state(far.id) == was and _builder.history_depth() == depth + 1)
	_table.append("%-11s %-6s %s" % ["own_def", "locked", "pass" if ok else "FAIL"])
	_builder.unlock_all()


## In a Build together room (Together.check_alone: this side's changes kept,
## as they would go): a refused edit, made at once (a paint) and at the
## frame's end (Delete mode's click, Main._edited_soon), sends nothing; an
## allowed one sends its change and its twin's.
func _attack_together() -> void:
	await _open(_file())
	var together: Together = _main.get("_together")
	together.check_alone([{"who": "a11ce000", "name": "Ann", "here": true, "owner": false,
		"at": null, "sel": [], "view": null}])
	await _frames(10)
	var sills: Array = _sills()
	var mine: BrickWorld.Brick = _in(sills[0], "3023")
	var theirs: BrickWorld.Brick = _in(sills[1], "3023")
	var yellow: BrickWorld.Brick = _in(sills[0], "3024")
	var yellow_twin: BrickWorld.Brick = _in(sills[1], "3024")
	_pick([theirs.id, yellow_twin.id])
	_builder.lock_selection(true)
	await _frames(4)
	var sent: int = (together.get("_pending") as Array).size()
	await _make("paint", mine, sills[0])
	await _frames(8)
	var after_paint: int = (together.get("_pending") as Array).size()
	# Delete mode's click: the change followed at the frame's end.
	_builder.remove_brick_id(yellow.id)
	await _frames(8)
	var after_delete: int = (together.get("_pending") as Array).size()
	print("  sends kept: %d, after the refused paint %d, after the refused click %d; yellow %s"
		% [sent, after_paint, after_delete, _state(yellow.id)])
	var ok: bool = _check("together: a refused edit sends nothing, at once or at the frame's end",
		after_paint == sent and after_delete == sent and _world.get_brick(yellow.id) != null)
	_builder.unlock_all()
	await _make("paint", mine, sills[0])
	await _frames(8)
	var changes: Dictionary = {}
	for one: Dictionary in (together.get("_pending") as Array).slice(after_delete):
		changes.merge(one["changes"])
	ok = _check("together: an allowed paint sends both copies' parts (%d sends, %d parts)" % [
		(together.get("_pending") as Array).size() - after_delete, changes.size()],
		changes.has(together.uid_of(mine.id)) and changes.has(together.uid_of(theirs.id))) and ok
	together._stop("")
	await _frames(6)
	_table.append("%-11s %-6s %s" % ["together", "both", "pass" if ok else "FAIL"])


## Round a refusal: undo takes back the step before it, not the refused one;
## a refusal made with something to redo keeps the redo.
func _attack_undo_redo() -> void:
	await _open(_file())
	var sills: Array = _sills()
	var plate: BrickWorld.Brick = _in(sills[0], "3023")
	var yellow: BrickWorld.Brick = _in(sills[0], "3024")
	var start: String = _save()
	# An allowed paint, then a refused one.
	await _make("paint", plate, sills[0])
	await _frames(6)
	var painted: String = _save()
	_pick([_in(sills[1], "3024").id])
	_builder.lock_selection(true)
	_builder.held_color = 1
	_pick([yellow.id])
	_verbs.press("paint")
	await _frames(6)
	var refused_kept: bool = _save() == painted
	_shell.run("undo")
	await _frames(6)
	var undone: bool = _save() == start
	# With the paint undone, a refused edit leaves its redo.
	_pick([yellow.id])
	_verbs.press("paint")
	await _frames(6)
	_shell.run("redo")
	await _frames(6)
	var redone: bool = _save() == painted
	print("  refused kept the paint: %s; undo back to the start: %s; redo after a refusal: %s"
		% [refused_kept, undone, redone])
	var ok: bool = _check("undo_redo: undo after a refusal takes back the step before it; the redo outlives a refusal",
		refused_kept and undone and redone)
	_table.append("%-11s %-6s %s" % ["undo_redo", "", "pass" if ok else "FAIL"])
	_builder.unlock_all()


## Saved after an allowed drag and a refused one, and opened again: one
## definition, both copies moved, nothing through; saved again the same.
func _attack_reopen() -> void:
	await _open(_file(BLOCKERS["paste"]))
	var sills: Array = _sills()
	# Refused: the pasted copy has no room in the far copy.
	await _make("paste", _in(sills[0], "3024"), sills[0])
	await _frames(6)
	await _make("drag", _in(sills[0], "3024"), sills[0])
	await _frames(6)
	var saved: String = _save()
	await _open(saved)
	var again: String = _save()
	sills = _sills()
	var near: BrickWorld.Brick = _in(sills[0], "3024")
	var far: BrickWorld.Brick = _in(sills[1], "3024")
	var defs: int = saved.count("0 FILE ")
	var through: Array = _through()
	print("  %d FILE lines; near yellow at %s, far at %s; through %s" % [defs,
		near.transform.origin if near != null else "none", far.transform.origin if far != null
		else "none", through])
	var ok: bool = _check("reopen: one Sill, both copies' yellow moved, nothing through, saved again the same",
		defs == 2 and near != null and far != null and near.transform.origin.x > 40.0
		and far.transform.origin.x > 40.0 and through.is_empty() and again == saved)
	_table.append("%-11s %-6s %s" % ["reopen", "", "pass" if ok else "FAIL"])


## Sill placed twice as live's build saved it (LIVE_SAVED: the fixture
## opened and saved by the build on brickworks.diy) opened here as ours is;
## a drag with its twin locked refused, the file to the byte; unlocked, the
## drag followed and nothing through, written to LIVE_OURS, one undo the
## file to the byte; that as live saves it again (LIVE_READ) opened here as
## ours was shown. Skipped, saying so, without LIVE_SAVED.
func _attack_live() -> void:
	var saved: String = OS.get_environment("LIVE_SAVED")
	if saved.is_empty() or not FileAccess.file_exists(saved):
		print("  live: LIVE_SAVED not given, skipped")
		_table.append("%-11s %-6s %s" % ["live", "", "skipped"])
		return
	await _open(_file())
	var ours_shown: Array = _looks(false)
	await _open(FileAccess.get_file_as_string(saved))
	var ok: bool = _check("live: live's save opened as ours is (%d parts)" % _looks(false).size(),
		_looks(false) == ours_shown)
	var sills: Array = _sills()
	var mine: BrickWorld.Brick = _in(sills[0], "3024")
	var theirs: BrickWorld.Brick = _in(sills[1], "3024")
	if mine == null or theirs == null:
		_check("live: two copies (%s)" % str(sills), false)
		_table.append("%-11s %-6s %s" % ["live", "", "FAIL"])
		return
	_pick([theirs.id])
	_builder.lock_selection(true)
	var before: String = _save()
	var depth: int = _builder.history_depth()
	var was: String = _state(theirs.id)
	await _make("drag", mine, sills[0])
	await _frames(6)
	ok = _check("live: its twin locked, the drag refused, the file to the byte (\"%s\")"
		% _bar_text(), _save() == before and _builder.history_depth() == depth
		and _bar_text().contains(LOCK_WORDS)) and ok
	_builder.unlock_all()
	before = _save()
	await _make("drag", mine, sills[0])
	await _frames(6)
	var ours: String = _save()
	ok = _check("live: unlocked, the drag followed (%s), nothing through"
		% _twin_part_now(sills[1], "3024", theirs.id), ours != before
		and _state(theirs.id) != was and _through().is_empty()) and ok
	var out: String = OS.get_environment("LIVE_OURS")
	if not out.is_empty():
		var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		file.store_string(ours)
		file.close()
	var shown: Array = _looks(false)
	_shell.run("undo")
	await _frames(6)
	ok = _check("live: one undo, the file to the byte", _save() == before) and ok
	var read: String = OS.get_environment("LIVE_READ")
	if read.is_empty() or not FileAccess.file_exists(read):
		print("  live: LIVE_READ not given, live's read of ours skipped")
	else:
		await _open(FileAccess.get_file_as_string(read))
		ok = _check("live: ours as live saves it, opened here as ours was shown",
			_looks(false) == shown) and ok
	_table.append("%-11s %-6s %s" % ["live", "", "pass" if ok else "FAIL"])
	_builder.unlock_all()


## A part outside the far copy where its yellow 1 x 1 stands, a 1 x 2 brick
## through it (a set's parts stand in each other so: 10179's axles through a
## plate of another sub-model). The near yellow dragged a stud along -x by
## the handles: where the brick covers both places ("same") the twin shares
## no more cells with it after, and the edit is made in both copies; where
## it covers half the first and all the second ("deeper"), refused in both,
## as a part outside the copy met anew is.
func _attack_met() -> void:
	var ok: bool = true
	for how: String in ["same", "deeper"]:
		# The 1 x 2 brick along x in the far copy's frame, its middle at x 20
		# (over x 0 to 40: both places) or x 10 (-10 to 30: half, then all).
		var x: int = 20 if how == "same" else 10
		var text: String = _file().replace(SECOND + "\n",
			SECOND + "\n1 1 %d -24 210 1 0 0 0 1 0 0 0 1 3004.dat\n" % x)
		await _open(text)
		var sills: Array = _sills()
		var mine: BrickWorld.Brick = _in(sills[0], "3024")
		var theirs: BrickWorld.Brick = _in(sills[1], "3024")
		var before: String = _save()
		var depth: int = _builder.history_depth()
		_bar_main.say("")
		_pick([mine.id])
		_builder.drag_begin()
		var moved: int = _builder.drag_end(Transform3D(Basis.IDENTITY, Vector3(-20, 0, 0)))
		if moved > 0:
			_verbs.edited.call()
		await _frames(6)
		var twin_x: float = _world.get_brick(theirs.id).transform.origin.x \
			if _world.get_brick(theirs.id) != null else INF
		print("  %s: moved %d; twin at x %s; history %d -> %d; refused \"%s\"; bar \"%s\"" % [how,
			moved, twin_x, depth, _builder.history_depth(), _assemblies.refused, _bar_text()])
		if how == "same":
			ok = _check("met same: the twin shares no more with the brick it stood in, so both moved, one step",
				moved == 1 and is_equal_approx(twin_x, 10.0) and _builder.history_depth() == depth + 1
				and _assemblies.refused.is_empty() and not _bar_text().contains("No room")) and ok
			_shell.run("undo")
			await _frames(6)
			ok = _check("met same: one undo, byte for byte", _save() == before) and ok
		else:
			ok = _check("met deeper: refused in both copies, the file byte for byte, said",
				_save() == before and _builder.history_depth() == depth
				and is_equal_approx(twin_x, 30.0) and _bar_text().contains(ROOM_WORDS)
				and _bar_text().contains("Brick 1 x 2")) and ok
	_table.append("%-11s %-6s %s" % ["met", "", "pass" if ok else "FAIL"])


## Real sets' nudges the review found refused for nothing (REAL_ALLOWED):
## each made, and every copy's twin moved with it, one undo step; one undo
## gives the file back.
func _attack_real() -> void:
	var ok: bool = true
	var opened: String = ""
	for item: Array in REAL_ALLOWED:
		if str(item[0]) != opened:
			await _open(FileAccess.get_file_as_string("res://vendor/omr/files/" + str(item[0])))
			opened = str(item[0])
		var brick: BrickWorld.Brick = _world.get_brick(int(item[1]))
		if brick == null or not brick.part_id.begins_with(str(item[2])):
			ok = _check("real %s #%d: the %s the review nudged" % [item[0], item[1], item[2]],
				false) and ok
			continue
		var path: String = Assemblies.path_of(brick)
		var copies: int = _assemblies.copies_of(path).size()
		var was: Dictionary = {}
		for one: BrickWorld.Brick in _world.bricks():
			was[one.id] = one.transform
		var before: String = _save()
		var depth: int = _builder.history_depth()
		_bar_main.say("")
		_pick([brick.id])
		_builder.drag_begin()
		var moved: int = _builder.drag_end(Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
		if moved > 0:
			_verbs.edited.call()
		await _frames(2)
		var changed: int = 0
		for one: BrickWorld.Brick in _world.bricks():
			if was.has(one.id) and not (was[one.id] as Transform3D).is_equal_approx(one.transform):
				changed += 1
		var made: bool = _builder.history_depth() == depth + 1
		print("  %s #%d %s in %s (%d other copies): moved %d, %d parts moved in all; history %d -> %d; refused \"%s\"; bar \"%s\""
			% [item[0], item[1], brick.part_id, path, copies, moved, changed, depth,
			_builder.history_depth(), _assemblies.refused, _bar_text().left(160)])
		ok = _check("real %s #%d: made, and its twin in each of the %d other copies with it"
			% [item[0], item[1], copies], made and moved == 1 and changed == copies + 1
			and _assemblies.refused.is_empty() and not _bar_text().contains("No room")) and ok
		if made:
			_shell.run("undo")
			await _frames(2)
			ok = _check("real %s #%d: one undo gives the file back" % [item[0], item[1]],
				_save() == before) and ok
	_table.append("%-11s %-6s %s" % ["real", "", "pass" if ok else "FAIL"])
