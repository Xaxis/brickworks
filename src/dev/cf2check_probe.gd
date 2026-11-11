## cf2check: an independent attack on copyfaults2's part-by-part follow
## (71081d24b). Reuses copyfaults_probe's helpers; fixtures src/dev/fixtures/cf2_*.
##
##   godot --headless --path . --script src/dev/cf2check_probe.gd
##
##   CF2_CASES=nestadd,axles   those cases
extends "res://src/dev/copyfaults_probe.gd"

const MINE: Array = ["nestadd", "nestadd2", "axles", "roof", "post16", "turned", "wholepaint",
	"clearredo", "steps", "mcppaint", "mcpadd", "nestdel", "reorder", "turnpart"]


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(1500.0).timeout.connect(func() -> void:
		print("cf2check probe: not finished in time")
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
	var cases: Array = MINE if OS.get_environment("CF2_CASES").is_empty() \
		else Array(OS.get_environment("CF2_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		match name:
			"nestadd": await _c_nestadd("cf2_nest_same.mpd")
			"nestadd2": await _c_nestadd("cfc_nested.mpd")
			"axles": await _c_axles()
			"roof": await _c_roof()
			"post16": await _c_post16()
			"turned": await _c_turned()
			"wholepaint": await _c_wholepaint()
			"clearredo": await _c_clearredo()
			"steps": await _c_steps()
			"mcppaint": await _c_mcppaint()
			"mcpadd": await _c_mcpadd()
			"nestdel": await _c_nestdel()
			"reorder": await _c_reorder()
			"turnpart": await _c_turnpart()
			_: _check("no such case %s" % name, false)
	print("\ncf2check probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- helpers ----------------------------------------------------------------------


## How many parts each copy holds directly, path -> count.
func _counts() -> Dictionary:
	var out: Dictionary = {}
	for path: String in _paths():
		out[path] = _parts_of(path).size()
	out["(model)"] = _parts_of("").size()
	return out


func _hand_put(part: String, colour: int, at: Transform3D, path: String) -> int:
	var put: int = _builder.put_part(part, colour, at)
	if put != 0:
		_world.get_brick(put).unit = path
		_world.get_brick(put).group = Assemblies.group_of(path)
	_main.call("_on_model_edited")
	await _frames(4)
	return put


func _select(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(ids.size())


func _say_parts(path: String) -> String:
	var out := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path:
			out.append("#%d %s c%d o%s s%d" % [brick.id, brick.part_id, brick.color_code,
				brick.origin, brick.step])
	return " | ".join(out)


func _non_scenery() -> int:
	var n: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			n += 1
	return n


## What a whole save writes of the definition [param name] (its section).
static func _section(text: String, name: String) -> String:
	for section: String in text.split("0 FILE "):
		if section.begins_with(name):
			return section
	return ""


func _colours(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id) or Assemblies.path_of(brick) != path:
			continue
		out.append("%s c%d y%.1f" % [brick.part_id, brick.color_code, brick.transform.origin.y])
	out.sort()
	return out


static func _ids_of(said: Array) -> Array:
	var out: Array = []
	for line: String in said:
		out.append(line.get_slice(" ", 0))
	return out


# -- 1: a part put down in a nested copy ------------------------------------------


## A 1x1 plate put down in one wheel of one car (both placed red, or red
## and blue): every wheel gains one, and no wheel two. The car-level copy
## follows after the wheel-level ones put it there already.
func _c_nestadd(fixture: String) -> void:
	await _open(_fixture(fixture))
	var opened: Array = _every_part()
	var tables: String = _tables()
	var counts: Dictionary = _counts()
	print("  opened: %s" % str(counts))
	var top: BrickWorld.Brick = _brick_of("Car#1/Wheel#1", "6141")
	if not _check("Car#1/Wheel#1's 4073 found", top != null):
		return
	var put: int = await _hand_put("3024", 2, top.transform.translated(Vector3(0, 32, 0)),
		"Car#1/Wheel#1")
	print("  put #%d; now %s" % [put, str(_counts())])
	for path: String in counts:
		var want: int = int(counts[path]) + (1 if path.contains("Wheel") else 0)
		_check("...%s holds %d parts (%d)  [%s]" % [path, want, int(_counts().get(path, -1)),
			_say_parts(path)], int(_counts().get(path, -1)) == want)
	var green: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3024":
			green += 1 if brick.color_code == 2 else 0
	_check("...four 3024s, every one green (%d green)" % green, green == 4)
	await _round_of("the part put down", opened, tables)


## Three deep: two trucks (red, blue), each two axles, each two wheels.
## A wheel's black hub painted green: all eight hubs green, nothing else; a
## wheel's top moved a stud: every wheel's top moved alike in its own wheel;
## a plate put down in a wheel: every wheel one more, no wheel two.
func _c_axles() -> void:
	await _open(_fixture("cf2_axles.mpd"))
	var counts: Dictionary = _counts()
	print("  opened: %s" % str(counts))
	var path: String = "Truck#1/Axle#1/Wheel#1"
	var hub: BrickWorld.Brick = _brick_of(path, "3062b")
	if not _check("%s's 3062b found (paths %s)" % [path, str(_paths())], hub != null):
		return
	# paint
	var opened: Array = _every_part()
	var tables: String = _tables()
	var before: Dictionary = {}
	for one: String in _paths():
		before[one] = _parts_of(one)
	_select([hub.id])
	_builder.paint_selection(2)
	_main.call("_on_model_edited")
	await _frames(4)
	for one: String in before:
		var want: Array = _said_of(before[one], "", Vector3.ZERO).map(func(line: String) -> String:
			return line.replace(" 3062b c0 ", " 3062b c2 "))
		_check("...painted: %s %s%s" % [one, "its hub green, the rest as it was"
			if one.contains("Wheel") else "as it was", _unlike(want, _twin_said(one))],
			want == _twin_said(one))
	await _round_of("the paint", opened, tables)
	# move
	await _open(_fixture("cf2_axles.mpd"))
	opened = _every_part()
	tables = _tables()
	var cap: BrickWorld.Brick = _brick_of(path, "6141")
	var hub2: BrickWorld.Brick = _brick_of(path, "3062b")
	var off: Vector3 = cap.transform.origin - hub2.transform.origin
	_select([cap.id])
	var moved: int = _builder.move_selection(Vector3i(0, 0, 10))
	_main.call("_on_model_edited")
	await _frames(4)
	var by: Vector3 = cap.transform.origin - hub2.transform.origin - off
	print("  moved %d; the top now %s from where it was over its hub" % [moved, str(by)])
	for one: String in _paths():
		if not one.contains("Wheel"):
			continue
		var c: BrickWorld.Brick = _brick_of(one, "6141")
		var h: BrickWorld.Brick = _brick_of(one, "3062b")
		var rel: Vector3 = h.transform.basis.inverse() * (c.transform.origin - h.transform.origin)
		var want: Vector3 = hub2.transform.basis.inverse() * (cap.transform.origin
			- hub2.transform.origin)
		_check("...moved: %s's top where Wheel#1's is over its hub (%s; want %s)" % [one,
			str(rel), str(want)], rel.distance_to(want) < 0.05)
	_check("...moved: the counts as opened (%s)" % str(_counts()), _counts() == counts)
	await _round_of("the move", opened, tables)
	# put down
	await _open(_fixture("cf2_axles.mpd"))
	opened = _every_part()
	tables = _tables()
	var top: BrickWorld.Brick = _brick_of(path, "6141")
	await _hand_put("3024", 14, top.transform.translated(Vector3(0, 32, 0)), path)
	for one: String in counts:
		var want: int = int(counts[one]) + (1 if one.contains("Wheel") else 0)
		_check("...put down: %s holds %d parts (%d)  [%s]" % [one, want,
			int(_counts().get(one, -1)), _say_parts(one)], int(_counts().get(one, -1)) == want)
	await _round_of("the part put down", opened, tables)


# -- 2: a definition the same either way round ------------------------------------


## roof.ldr is two 3003s and two yellow slopes back to back, the same
## turned a half; Roof#2 is placed turned a half. Roof#1's first slope (line
## 3) painted green: Roof#2's slope on the same line goes green, saved as
## one green slope in roof.ldr, and opened again each roof shows it.
func _c_roof() -> void:
	await _open(_fixture("cf2_roof.mpd"))
	var opened: Array = _every_part()
	var tables: String = _tables()
	print("  Roof#1: %s" % _say_parts("Roof#1"))
	print("  Roof#2: %s" % _say_parts("Roof#2"))
	var slopes: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == "Roof#1" and brick.part_id == "3039":
			slopes.append(brick)
	if not _check("Roof#1's two slopes found", slopes.size() == 2):
		return
	var first: BrickWorld.Brick = slopes[0]
	_select([first.id])
	_builder.paint_selection(2)
	_main.call("_on_model_edited")
	await _frames(4)
	print("  painted #%d (o%s); Roof#2: %s" % [first.id, first.origin, _say_parts("Roof#2")])
	var twin_green: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == "Roof#2" and brick.color_code == 2:
			twin_green.append(brick)
	_check("...one slope of Roof#2 green (%d)" % twin_green.size(), twin_green.size() == 1)
	if twin_green.size() == 1:
		var line_of := func(origin: String) -> String:
			return origin.get_slice("/", origin.get_slice_count("/") - 1)
		_check("...the one on Roof#1's painted slope's line (o%s, o%s)" % [first.origin,
			(twin_green[0] as BrickWorld.Brick).origin],
			line_of.call(first.origin) == line_of.call((twin_green[0] as BrickWorld.Brick).origin))
	var saved: String = _save()
	print("  saved (head): %s" % saved.left(500).replace("\n", " / "))
	var roof: String = _section(saved, "roof.ldr")
	print("  roof.ldr as saved:\n    %s" % roof.strip_edges().replace("\n", "\n    "))
	_check("...saved: roof.ldr written once, one slope green in it",
		saved.count("0 FILE roof.ldr") == 1 and roof.count(" 2 ") >= 1 and roof.count("\n1 2 ") == 1)
	await _round_of("the paint", opened, tables)


# -- 3: a copy placed in 16 beside one placed in a colour -------------------------


## post16: Post#1 placed in 16, Post#2 in red. A 1x1 plate put down in
## Post#2 in red: Post#1's goes down in 16. Post#2's lower 3003 (16) painted
## blue: Post#1's stays 16. Its own green 3003 painted yellow: both yellow.
func _c_post16() -> void:
	await _open(_fixture("cf2_post16.mpd"))
	var opened: Array = _every_part()
	var tables: String = _tables()
	print("  Post#1: %s" % _say_parts("Post#1"))
	print("  Post#2: %s" % _say_parts("Post#2"))
	var p1: Array = _parts_of("Post#1")
	var top: BrickWorld.Brick = _brick_of("Post#2", "3005")
	await _hand_put("3024", 4, top.transform.translated(Vector3(0, 32, 0)), "Post#2")
	var fresh: Array = _twin_said("Post#1").slice(p1.size())
	var shown16: int = int(p1[0][2])
	_check("...a red 3024 put down in Post#2: Post#1 its parts as they were and a 3024 in c%d, as its 16s show (%s)"
		% [shown16, str(fresh)], _twin_said("Post#1").slice(0, p1.size()) == _said_of(p1, "", Vector3.ZERO)
		and fresh.size() == 1 and str(fresh[0]).contains(" 3024 c%d " % shown16))
	var saved: String = _save()
	print("  post.ldr as saved:\n    %s" % _section(saved, "post.ldr").strip_edges().replace("\n",
		"\n    "))
	_check("...saved: post.ldr once, its 3024 in 16", saved.count("0 FILE post.ldr") == 1
		and _section(saved, "post.ldr").contains("1 16 ") and _section(saved, "post.ldr")
			.split("3024").size() == 2 and _section(saved, "post.ldr").contains("3024.dat")
		and RegEx.create_from_string("\\n1 16 [^\\n]*3024\\.dat").search(
			_section(saved, "post.ldr")) != null)
	await _round_of("the plate put down", opened, tables)
	await _open(_fixture("cf2_post16.mpd"))
	opened = _every_part()
	tables = _tables()
	p1 = _parts_of("Post#1")
	var low: BrickWorld.Brick = _brick_of("Post#2", "3003", 0)
	_select([low.id])
	_builder.paint_selection(1)
	_main.call("_on_model_edited")
	await _frames(4)
	_check("...Post#2's lower 3003 (16) painted blue: Post#1 as it was%s"
		% _unlike(_said_of(p1, "", Vector3.ZERO), _twin_said("Post#1")),
		_said_of(p1, "", Vector3.ZERO) == _twin_said("Post#1"))
	await _round_of("the paint", opened, tables)
	await _open(_fixture("cf2_post16.mpd"))
	opened = _every_part()
	tables = _tables()
	var own: BrickWorld.Brick = _brick_of("Post#2", "3003", 1)
	print("  Post#2's upper 3003: c%d" % own.color_code)
	_select([own.id])
	_builder.paint_selection(14)
	_main.call("_on_model_edited")
	await _frames(4)
	var yellow: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == "Post#1" and brick.part_id == "3003" \
				and brick.color_code == 14:
			yellow += 1
	_check("...Post#2's own green 3003 painted yellow: Post#1's yellow too (%s)"
		% _say_parts("Post#1"), yellow == 1)
	await _round_of("the paint", opened, tables)


# -- 4: a copy turned a quarter ----------------------------------------------------


## turned.mpd: Post#2 placed turned a quarter. Post#1's 3005 moved a stud
## along x: Post#2's 3005 moved a stud along its own x, every other part of
## it as it was, the two posts still the same shape.
func _c_turned() -> void:
	await _open(_fixture("cf2_turned.mpd"))
	var opened: Array = _every_part()
	var tables: String = _tables()
	var p2: Array = _parts_of("Post#2")
	var top: BrickWorld.Brick = _brick_of("Post#1", "3005")
	var was: Vector3 = top.transform.origin
	_select([top.id])
	var moved: int = _builder.move_selection(Vector3i(10, 0, 0))
	_main.call("_on_model_edited")
	await _frames(4)
	var by: Vector3 = top.transform.origin - was
	print("  moved %d by %s" % [moved, str(by)])
	var asm: Assemblies = _shell.assemblies
	var fit: Dictionary = asm.best_match(asm.content("Post#1"), asm.content("Post#2"))
	_check("...the posts the same shape still (%d of 3 laid)" % int(fit["score"]),
		int(fit["score"]) == 3)
	var now: Array = _parts_of("Post#2")
	var same: int = 0
	var moved_twin: int = 0
	for n: int in mini(now.size(), p2.size()):
		if now[n][0] != p2[n][0]:
			continue
		if (now[n][3] as Transform3D).is_equal_approx(p2[n][3]):
			same += 1
		elif now[n][1] == "3005":
			moved_twin += 1
			print("  Post#2's 3005 by %s" % str((now[n][3] as Transform3D).origin
				- (p2[n][3] as Transform3D).origin))
	_check("...Post#2: its 3005 moved, the other two as they were, under their numbers (%d, %d)"
		% [moved_twin, same], moved_twin == 1 and same == 2 and now.size() == 3)
	await _round_of("the move", opened, tables)


# -- 5: a whole copy painted -------------------------------------------------------


## Every part of Post#1 (red) selected and painted green: what Post#2
## (blue) does is said, not judged: its own-colour 3003 is red in both.
func _c_wholepaint() -> void:
	await _open(_fixture("cfc_owncolour.mpd"))
	var opened: Array = _every_part()
	var tables: String = _tables()
	print("  before: Post#2 %s" % _say_parts("Post#2"))
	_select(Array(_shell.assemblies.ids_under("Post#1")))
	_builder.paint_selection(2)
	_main.call("_on_model_edited")
	await _frames(4)
	print("  Post#1 painted green whole: Post#1 %s" % _say_parts("Post#1"))
	print("  ...Post#2 %s" % _say_parts("Post#2"))
	var saved: String = _save()
	print("  saved post.ldr:\n    %s" % _section(saved, "post.ldr").strip_edges().replace("\n",
		"\n    "))
	print("  main:\n    %s" % saved.get_slice("0 FILE post", 0).strip_edges().replace("\n",
		"\n    "))
	await _round_of("the paint", opened, tables)


# -- 6: a clear undone, a part landing, redone --------------------------------------


## The app's own file with a part on its way at a session's clear, landed
## by the undo (copyfaults_probe clear_held); then redo: the baseplate bare
## again, nothing left behind; and undo again: every part back once.
func _c_clearredo() -> void:
	var text: String = _fixture("cfc_absent.ldr")
	await _open(text)
	var count: int = _non_scenery()
	var waiting := LdrModel.Placement.new("3001", 2, Transform3D(Basis.IDENTITY,
		Vector3(0, 200, 0)), 0)
	_store.awaited.append(waiting)
	await _say("clear_model", {})
	await _say("undo", {})
	await _frames(6)
	print("  undone: %d parts (opened with %d)" % [_non_scenery(), count])
	await _say("undo", {"redo": true})
	await _frames(6)
	_check("...redone: the baseplate bare, nothing left behind (%d)" % _non_scenery(),
		_non_scenery() == 0)
	await _say("undo", {})
	await _frames(6)
	_check("...undone again: %d parts, each once (%d)" % [count + 1, _non_scenery()],
		_non_scenery() == count + 1)
	var saved: String = _save()
	_check("...saved: one 3001 green line, the zz9999 line kept (%d)" % saved.count(" 3001.dat"),
		saved.contains("zz9999.dat") and RegEx.create_from_string("\\n1 2 [^\\n]*3001\\.dat")
			.search_all(saved).size() == 1)


# -- 7: step edits over MCP on a copy placed in two colours --------------------------


## copyfaults_nest's towers (red, blue): new, prev, name on Tower#1's top;
## Tower#2's parts keep their numbers and colours, and their steps are
## Tower#1's after each; then undo back, redo, save, reopen.
func _c_steps() -> void:
	await _open(_fixture("copyfaults_nest.mpd"))
	var opened: Array = _every_part()
	var tables: String = _tables()
	var twin: Array = _copy_said("Tower#2")
	var colours: Array = _colours("Tower#2")
	var top: BrickWorld.Brick = _brick_of("Tower#1", "6141")
	for op: Dictionary in [{"op": "new", "bricks": [top.id]}, {"op": "prev", "bricks": [top.id]},
			{"op": "name", "step": 1, "name": "The base"}, {"op": "merge", "step": 1}]:
		var said: String = await _say("edit_steps", op)
		print("  edit_steps %s: %s" % [str(op), said.get_slice("\n", 0).left(140)])
		_check("...Tower#2 the same bricks, colours and lines (%s)" % _say_parts("Tower#2"),
			_ids_of(_copy_said("Tower#2")) == _ids_of(twin) and _colours("Tower#2") == colours)
		var t1: Array = _shape_steps("Tower#1")
		var t2: Array = _shape_steps("Tower#2")
		_check("...each tower's parts in the same steps (%s; %s)" % [str(t1), str(t2)], t1 == t2)
	var depth: int = _builder.history_depth()
	for _n: int in 3:
		_shell.run("undo")
		await _frames(6)
	_shell.run("undo")
	await _frames(6)
	_check("...four undos: every part as opened%s" % _unlike(opened, _every_part()),
		_every_part() == opened)
	_check("...the tables as opened", _tables() == tables)
	for _n: int in 4:
		_shell.run("redo")
		await _frames(6)
	_check("...four redos: back at the history's depth (%d, %d)" % [_builder.history_depth(),
		depth], _builder.history_depth() == depth)
	var shown: Array = _looks()
	var saved: String = _save()
	await _open(saved)
	_check("...saved and opened again: every part, colour, place and step as shown%s"
		% _unlike(shown, _looks()), shown == _looks())


# -- 8: over MCP --------------------------------------------------------------------


## A session paints Post#1's own red 3003 and its 3005 (16) green with
## edit_model's recolor: Post#2's own 3003 goes green, its 3005 stays blue.
func _c_mcppaint() -> void:
	await _open(_fixture("cfc_owncolour.mpd"))
	var opened: Array = _every_part()
	var tables: String = _tables()
	var own: BrickWorld.Brick = _brick_of("Post#1", "3003", 1)
	var top: BrickWorld.Brick = _brick_of("Post#1", "3005")
	var p2: Array = _parts_of("Post#2")
	var said: String = await _say("edit_model", {"recolor": [{"bricks": [own.id, top.id],
		"color": 2}], "picture": false})
	print("  edit_model recolor: %s" % said.get_slice("\n", 0).left(160))
	print("  Post#1 %s" % _say_parts("Post#1"))
	print("  Post#2 %s" % _say_parts("Post#2"))
	var want: Array = _said_of(p2, "", Vector3.ZERO)
	var own2: BrickWorld.Brick = _brick_of("Post#2", "3003", 1)
	for n: int in want.size():
		if str(want[n]).begins_with("#%d " % own2.id):
			want[n] = str(want[n]).replace(" c4 ", " c2 ")
	_check("...Post#2: its own 3003 green, the rest as it was%s" % _unlike(want,
		_twin_said("Post#2")), want == _twin_said("Post#2"))
	await _round_of("the recolour", opened, tables)


## A session swaps Car#1/Wheel#1's round plate for a 1x1 plate with
## edit_model's remove and add where it stood: every wheel's round plate
## swapped, each wheel its two parts still, no wheel three.
func _c_mcpadd() -> void:
	await _open(_fixture("cf2_nest_same.mpd"))
	var opened: Array = _every_part()
	var tables: String = _tables()
	var counts: Dictionary = _counts()
	var cap: BrickWorld.Brick = _brick_of("Car#1/Wheel#1", "3062b")
	var at: Dictionary = _placement_of(cap.id)
	var one: Dictionary = {"part": "3005", "color": 14}
	for key: String in ["x", "y", "z", "face", "rot"]:
		if at.has(key):
			one[key] = at[key]
	var said: String = await _say("edit_model", {"remove": [cap.id], "add": [one],
		"picture": false})
	print("  edit_model swap: %s" % said.get_slice("\n", 0).left(200))
	for path: String in counts:
		print("  %s: %s" % [path, _say_parts(path)])
	_check("...the counts as opened (%s; were %s)" % [str(_counts()), str(counts)],
		_counts() == counts)
	var plates: int = 0
	var rounds: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		plates += 1 if brick.part_id == "3005" else 0
		rounds += 1 if brick.part_id == "3062b" else 0
	_check("...four 3005s and no 3062b (%d, %d)" % [plates, rounds], plates == 4 and rounds == 0)
	await _round_of("the swap", opened, tables)


## A wheel's top taken off by hand: every wheel loses its top, one each.
func _c_nestdel() -> void:
	await _open(_fixture("cf2_nest_same.mpd"))
	var opened: Array = _every_part()
	var tables: String = _tables()
	var counts: Dictionary = _counts()
	var cap: BrickWorld.Brick = _brick_of("Car#1/Wheel#1", "6141")
	_select([cap.id])
	_builder.remove_selection()
	_main.call("_on_model_edited")
	await _frames(4)
	for path: String in counts:
		var want: int = int(counts[path]) - (1 if path.contains("Wheel") else 0)
		_check("...%s holds %d parts (%d)" % [path, want, int(_counts().get(path, -1))],
			int(_counts().get(path, -1)) == want)
	await _round_of("the delete", opened, tables)


## cfc_posts (two 3005s stacked, Post#2 a stud along): Post#1's lower one
## moved a stud aside, then its upper one moved down where the lower stood,
## then the first moved back up on top: each of Post#2's parts stands where
## Post#1's of the same line does, a stud along, after each, and saved and
## opened again.
func _c_reorder() -> void:
	await _open(_fixture("cfc_posts.mpd"))
	var opened: Array = _every_part()
	var tables: String = _tables()
	var low: BrickWorld.Brick = _brick_of("Post#1", "3005", 0)
	var high: BrickWorld.Brick = _brick_of("Post#1", "3005", 1)
	var low_id: int = low.id
	var high_id: int = high.id
	var plan: Array = [[low_id, Vector3i(10, 0, 0)], [high_id, Vector3i(0, -12, 0)],
		[low_id, Vector3i(-10, 24, 0)]]
	for one: Array in plan:
		_select([int(one[0])])
		var moved: int = _builder.move_selection(one[1])
		_main.call("_on_model_edited")
		await _frames(4)
		print("  moved #%d by %s: %d" % [int(one[0]), str(one[1]), moved])
		_check("...each of Post#2's parts a stud along from Post#1's of its line (%s)"
			% _by_line(), _lines_agree())
	await _round_of("the moves", opened, tables, Callable(), plan.size())
	_check("...opened again: each of Post#2's parts a stud along from Post#1's of its line (%s)"
		% _by_line(), _lines_agree())


func _by_line() -> String:
	var out := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick).begins_with("Post"):
			out.append("%s %s o%s %s" % [Assemblies.path_of(brick), brick.part_id, brick.origin,
				str(brick.transform.origin)])
	return " | ".join(out)


## Each line of post.ldr: Post#2's part minus Post#1's, all the same.
func _lines_agree() -> bool:
	var one: Dictionary = {}
	var two: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var line: String = brick.origin.get_slice("/", brick.origin.get_slice_count("/") - 1)
		if Assemblies.path_of(brick) == "Post#1":
			one[line] = brick.transform.origin
		elif Assemblies.path_of(brick) == "Post#2":
			two[line] = brick.transform.origin
	if one.size() != 2 or two.size() != 2 or one.keys() != two.keys():
		return false
	var by: Variant = null
	for line: String in one:
		var d: Vector3 = (two[line] as Vector3) - (one[line] as Vector3)
		if by == null:
			by = d
		elif d.distance_to(by) > 0.05:
			return false
	return true


## turned.mpd: Post#1's 3005 turned a quarter: Post#2's turns alike in its
## own frame, the posts the same shape, the other parts as they were.
func _c_turnpart() -> void:
	await _open(_fixture("cf2_turned.mpd"))
	var opened: Array = _every_part()
	var tables: String = _tables()
	var p2: Array = _parts_of("Post#2")
	var top: BrickWorld.Brick = _brick_of("Post#1", "3005")
	var was: Basis = top.transform.basis
	_select([top.id])
	var turned: int = _builder.turn_selection(1)
	_main.call("_on_model_edited")
	await _frames(4)
	print("  turned %d; basis now %s (was %s)" % [turned, str(top.transform.basis), str(was)])
	var asm: Assemblies = _shell.assemblies
	var fit: Dictionary = asm.best_match(asm.content("Post#1"), asm.content("Post#2"))
	_check("...the posts the same shape still (%d of 3, bases %s)" % [int(fit["score"]),
		str(fit.get("bases", "?"))], int(fit["score"]) == 3)
	var now: Array = _parts_of("Post#2")
	var same: int = 0
	var changed: int = 0
	for n: int in mini(now.size(), p2.size()):
		if now[n][0] != p2[n][0]:
			continue
		if (now[n][3] as Transform3D).is_equal_approx(p2[n][3]):
			same += 1
		elif now[n][1] == "3005":
			changed += 1
	_check("...Post#2: its 3005 turned, the other two as they were, under their numbers (%d, %d)"
		% [changed, same], changed == 1 and same == 2 and now.size() == 3)
	await _round_of("the turn", opened, tables)
