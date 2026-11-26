## figreview3: the third independent review of the hand (handkeep c9d664aad: what
## is lifted stays in the model where it stood, drawn nowhere and out of the
## lattice). Each case lifts a figure, a selection or one plain part, does what a
## person or a session might with it in hand, and reads the model, the file and
## the lattice. The same file runs on live (129a7c3ed) and on handkeep.
##
##   godot --path . --resolution 1280x720 --script src/dev/figreview3_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh figreview3_probe                 every case
##   PROBE_SIZE=1280x720 tools/probe.sh figreview3_probe --case=turn     one case
##
## --case= turn, paste, sessadd, plainx, cars, connect, tool, sessundo, whole,
##         carry (all when not said).
##   turn     the whole model turned (Shift+E) with a figure, then a selection, in
##            hand; then Escape, or put down and Undo: where it stands against the
##            rest of the model, and what the lattice holds where it stood.
##   paste    a figure in hand, a copy pasted and put down where it stood, then
##            Escape: two parts in one place?
##   sessadd  a figure in hand, a session's edit_model add where it stood, then
##            Escape: the same.
##   plainx   X over one plain part, then the autosave, Ctrl+S, Escape and a
##            put-down where it stood: is it in the file, its step and line kept?
##   cars     X over one plain part of a car placed twice, put down where it
##            stood: each car's parts in the file.
##   connect  Connect's click on a figure's torso, then Select.
##   tool     a figure in hand, the Select tool chosen.
##   sessundo a session's edit, the person's lift, the session's undo.
##   whole    a car carried whole (a part the app cannot show inside it), put down
##            away: the car's own lines kept, the part it cannot show with it.
##   carry    a selection carried: autosave, Ctrl+S, Escape, put down, Undo.
##   dense    6541-1 at its last step: a figure lifted, the model turned, Escape:
##            does it stand inside other parts?
##   stepesc  a figure lifted at the last step, the timeline stepped back to the
##            start, Escape, then the end: each part drawn as the step it is at says.
## Exits non-zero when a check fails.
extends "res://src/dev/figreview2_probe.gd"

## A car with a part the app has no shape for inside it, placed once.
const UNSHOWN := """0 FILE main.ldr
0 figreview3: a car with a part the app cannot show in it
0 Name: main.ldr
0 Author: figreview3_probe
1 4 -200 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 16 0 0 0 1 0 0 0 1 0 0 0 1 car.ldr
0 STEP
0 NOFILE
0 FILE car.ldr
0 car
0 Name: car.ldr
1 72 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
1 72 0 0 40 1 0 0 0 1 0 0 0 1 3020.dat
1 15 0 -24 40 1 0 0 0 1 0 0 0 1 3001.dat
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 zzfr3_noshape.dat
0 STEP
0 NOFILE
"""

var _live: bool = false


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("figreview3_probe: needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			_case = arg.substr(7)
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	_layout = "phone" if mini(window.x, window.y) < int(Phone.NARROW) else "desktop"
	Phone._on = 0 if _layout == "desktop" else 1
	Phone._wide = false
	Keymap.reset()
	Keymap.use("brickworks")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(20)
	_store = _main.get("_store")
	_store.keeps = false
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_steps = _main.get("_steps")
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	_socket2 = CommandSocket.new()
	_socket2.assistant = _main.get("_assistant")
	_socket2.app = _main
	_main.add_child(_socket2)
	_gate = _builder.has_method("holds_lifted_figure")
	_live = not _builder.has_method("holds_lift")
	_code = "live" if _live else "handkeep"
	print("figreview3_probe: a %s window, case %s, code %s" % [_size, _case, _code])
	var wants: PackedStringArray = _case.split(",")
	var every: bool = wants.has("all")
	if every or wants.has("turn"):
		await _case_turn()
	if every or wants.has("paste"):
		await _case_paste()
	if every or wants.has("sessadd"):
		await _case_sessadd()
	if every or wants.has("plainx"):
		await _case_plainx()
	if every or wants.has("cars"):
		await _case_cars()
	if every or wants.has("connect"):
		await _case_connect()
	if every or wants.has("tool"):
		await _case_tool()
	if every or wants.has("sessundo"):
		await _case_sessundo()
	if every or wants.has("whole"):
		await _case_whole()
	if every or wants.has("carry"):
		await _case_carry()
	if every or wants.has("dense"):
		await _case_dense()
	if every or wants.has("stepesc"):
		await _case_stepesc()
	print("\nfigreview3_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


# -- helpers ----------------------------------------------------------------------


func _ref_brick() -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("3003") and brick.transform.origin.x < 0.0:
			return brick.id
	return 0


func _walls() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("3003") and brick.transform.origin.x > 100.0:
			out.append(brick.id)
	out.sort()
	return out


func _figure_ids() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if FIG_PARTS.has(brick.part_id.get_basename()) and not brick.part_id.begins_with("3023"):
			out.append(brick.id)
	return out


func _boxes_of(brick_id: int) -> PackedInt32Array:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	if brick == null:
		return PackedInt32Array()
	var mesh: Lbm.PartMesh = _builder.library.mesh_for(brick.part_id)
	return _builder.boxes_for(mesh, brick.transform) if mesh != null else PackedInt32Array()


static func _meet(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	var i: int = 0
	while i + 5 < a.size():
		var j: int = 0
		while j + 5 < b.size():
			if a[i] < b[j + 3] and b[j] < a[i + 3] and a[i + 1] < b[j + 4] and b[j + 1] < a[i + 4] \
					and a[i + 2] < b[j + 5] and b[j + 2] < a[i + 5]:
				return true
			j += 6
		i += 6
	return false


## The pairs, one of [param these] and one of [param those], whose parts meet.
func _overlaps(these: Array, those: Array) -> Array:
	var out: Array = []
	for a: int in these:
		for b: int in those:
			if a != b and _meet(_boxes_of(a), _boxes_of(b)):
				out.append("%s#%d x %s#%d" % [_world.get_brick(a).part_id.get_basename(), a,
					_world.get_brick(b).part_id.get_basename(), b])
	return out


## Escape with a figure in hand (Main, KEY_ESCAPE): whether it went back (live
## says nothing, and its drop_figure returns nothing).
func _figure_back() -> bool:
	if not _builder.is_holding_figure():
		return false
	var said: Variant = _builder.call("drop_figure")
	return said is bool and bool(said)


func _held_count() -> int:
	return _world.hand().size() if _world.has_method("hand") else -1


func _drop_all() -> void:
	if _builder.is_holding_figure():
		_builder.drop_figure()
	_builder.cancel_carry()
	await _frames(4)


## What the lattice's ray straight down at [param spot] meets first.
func _ray_down(spot: Vector3) -> int:
	var hit: BrickLattice.Hit = _builder.lattice.raycast(spot + Vector3(0, 4000, 0), Vector3.DOWN)
	return hit.brick_id if hit != null and hit.is_valid() else 0


func _written() -> String:
	_store.keeps = true
	_store.touch()
	var path: String = _store.write_now()
	_store.keeps = false
	return FileAccess.get_file_as_string(path) if not path.is_empty() else ""


func _count_in(text: String, part: String) -> int:
	var n: int = 0
	for line: String in text.split("\n"):
		var words: PackedStringArray = line.strip_edges().split(" ", false)
		if words.size() >= 15 and words[0] == "1" and words[14].to_lower().begins_with(part):
			n += 1
	return n


# -- turn: the whole model turned with something in hand ---------------------------


func _case_turn() -> void:
	print("\nTU. the whole model turned (Shift+E) with a figure, then a selection, in hand")
	var path: String = _fixture2("fr3_turn", REPLAN)
	for how: String in ["figure escape", "figure put", "carry escape"]:
		if not await _to_step(path, "last"):
			_check("turn %s: opens" % how, false)
			continue
		var name: String = "figreview3 turn " + how.replace(" ", "_")
		var ref: int = _ref_brick()
		var torso: int = int(_torsos()[0])
		var walls: Array = _walls()
		var mover: int = torso if how.begins_with("figure") else int(walls[0])
		var mover_part: String = _world.get_brick(mover).part_id
		var mover_colour: int = _world.get_brick(mover).color_code
		var was_at: Vector3 = _world.get_brick(mover).transform.origin
		var d0: float = was_at.distance_to(_world.get_brick(ref).transform.origin)
		var depth: int = _builder.history_depth()
		_builder.clear_selection()
		var held: bool = false
		if how.begins_with("figure"):
			held = _builder.lift_brick(torso) and _builder.is_holding_figure()
		else:
			for brick_id: int in walls:
				_builder.select_brick(brick_id, true)
			held = _verbs.lift() == walls.size() and _builder.is_carrying()
		await _frames(4)
		_main.call("_turn_model", 1)
		await _frames(6)
		# Live takes what is lifted off the model: it is not there to turn.
		var turned_at: Vector3 = _world.get_brick(mover).transform.origin if _world.get_brick(mover) != null \
			else Vector3.INF
		var in_lattice: bool = not _builder.lattice.boxes_of(mover).is_empty()
		var d_turned: float = turned_at.distance_to(_world.get_brick(ref).transform.origin) \
			if turned_at.x < INF else -1.0
		var still: bool = _builder.is_holding_figure() or _builder.is_carrying()
		var put: int = 0
		if how == "figure put":
			await _aim(Vector3(-300, 0, -300))
			put = _builder.place()
			await _frames(6)
			await _undo()
		else:
			if _builder.is_holding_figure():
				_builder.drop_figure()
			else:
				_verbs.put_away()
			await _frames(6)
		var brick: BrickWorld.Brick = _world.get_brick(mover)
		if brick == null:
			# Put back as a new part (live): the same part and colour nearest.
			var best: float = INF
			for one: BrickWorld.Brick in _world.bricks():
				if one.part_id == mover_part and one.color_code == mover_colour and one.id != ref:
					var near: float = minf(one.transform.origin.distance_to(was_at),
						one.transform.origin.distance_to(turned_at) if turned_at.x < INF else INF)
					if near < best:
						best = near
						brick = one
		if brick != null:
			mover = brick.id
		var now_at: Vector3 = brick.transform.origin if brick != null else Vector3.INF
		var d1: float = now_at.distance_to(_world.get_brick(ref).transform.origin) if brick != null else -1.0
		var mesh_cover: PackedInt32Array = _builder.lattice.boxes_of(mover)
		var cover_matches: bool = brick != null and mesh_cover == _boxes_of(mover)
		# A ray down where it stood once turned: what it meets.
		var ghost_hit: int = _ray_down(Vector3(turned_at.x, 0, turned_at.z)) if turned_at.x < INF else -1
		var t1: String = _text(name)
		var group: Array = _figure_ids() if how.begins_with("figure") else walls
		var others: Array = []
		for one: BrickWorld.Brick in _world.bricks():
			if not group.has(one.id):
				others.append(one.id)
		_result("turn.%s" % how.replace(" ", "_"), "in hand %s; at %s, turned %s (in the lattice in hand %s), still in hand %s; put #%d; now at %s; to the red brick %.1f before, %.1f turned, %.1f after (%s); lattice cover is where it stands %s; a ray down where it stood turned meets #%d; overlaps now %s"
			% [held, was_at.snapped(Vector3.ONE * 0.1), turned_at.snapped(Vector3.ONE * 0.1), in_lattice, still, put,
				now_at.snapped(Vector3.ONE * 0.1), d0, d_turned, d1, how, cover_matches, ghost_hit,
				_overlaps(group, others).slice(0, 4)])
		_check("turn %s: in hand, the model turned, then %s: it stands where the turn took it against the rest (%.1f from the red brick, was %.1f)"
			% [how, "put down and Undo" if how == "figure put" else "Escape", d1, d0], held and absf(d1 - d0) < 0.5)
		_check("turn %s: the lattice holds it where it stands (%s)" % [how, cover_matches], cover_matches)
		_check("turn %s: the saved file has it (%d torsos)" % [how, _figure_count_in(t1)], _figure_count_in(t1) == 1)
		await _drop_all()
		await _back_to(depth)


# -- two parts in one place: a paste, a session's add --------------------------------


func _case_paste() -> void:
	print("\nPA. a figure in hand, a copy pasted and put down where it stood, then Escape")
	var path: String = _fixture2("fr3_paste", REPLAN)
	if not await _to_step(path, "last"):
		_check("paste: opens", false)
		return
	var name: String = "figreview3 paste"
	var t0: String = _text(name)
	var depth: int = _builder.history_depth()
	var torso: int = int(_torsos()[0])
	var torso_was: Transform3D = _world.get_brick(torso).transform
	var ref: int = _ref_brick()
	_builder.clear_selection()
	_builder.select_brick(ref, false)
	_verbs.press("copy")
	await _frames(2)
	_builder.clear_selection()
	var held: bool = _builder.lift_brick(torso) and _builder.is_holding_figure()
	await _frames(4)
	_verbs.press("paste")
	await _frames(6)
	var carrying: bool = _builder.is_carrying()
	var figure_still: bool = _builder.is_holding_figure()
	await _aim(Vector3(torso_was.origin.x, 0, torso_was.origin.z))
	var before: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		before[brick.id] = true
	var put: int = _builder.place()
	await _frames(6)
	var pasted: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not before.has(brick.id):
			pasted.append(brick.id)
	var figure_after_put: bool = _builder.is_holding_figure()
	# Escape: a figure in hand goes back where it stood (Main, KEY_ESCAPE).
	if _builder.is_carrying():
		_verbs.put_away()
	var back: bool = _figure_back()
	_main.call("_refresh_preview")
	await _frames(6)
	var meets: Array = _overlaps(pasted, _figure_ids())
	var t1: String = _text(name)
	_result("paste", "figure in hand %s; paste in hand %s, figure still %s; put #%d (%d new: %s at %s); figure in hand after %s; Escape put back %s; torsos %d; overlaps %s; file torsos %d, 3003s %d (were %d)"
		% [held, carrying, figure_still, put, pasted.size(), pasted,
			_world.get_brick(int(pasted[0])).transform.origin if not pasted.is_empty() else Vector3.ZERO,
			figure_after_put, back, _torsos().size(), meets.slice(0, 6), _figure_count_in(t1), _count_in(t1, "3003"),
			_count_in(t0, "3003")])
	_check("paste: a copy pasted with a figure in hand cannot go where the figure stands in the file, or the figure is put back first (%d parts meet)"
		% meets.size(), meets.is_empty())
	_check("paste: the figure is not lost (%d torsos)" % _torsos().size(), _torsos().size() == 1)
	await _drop_all()
	await _back_to(depth)
	_check("paste: undone, the file as opened", _text(name) == t0)


func _case_sessadd() -> void:
	print("\nSA. a figure in hand, a session's edit_model add where it stood, then Escape")
	var path: String = _fixture2("fr3_sessadd", REPLAN)
	if not await _to_step(path, "last"):
		_check("sessadd: opens", false)
		return
	var name: String = "figreview3 sessadd"
	var t0: String = _text(name)
	var depth: int = _builder.history_depth()
	var torso: int = int(_torsos()[0])
	var at: Vector3 = _world.get_brick(torso).transform.origin
	_builder.clear_selection()
	var held: bool = _builder.lift_brick(torso) and _builder.is_holding_figure()
	await _frames(4)
	var said: String = ""
	var made: Array = []
	for y: float in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0]:
		var before: Dictionary = {}
		for brick: BrickWorld.Brick in _world.bricks():
			before[brick.id] = true
		said = await _call("edit_model", {"add": [{"part": "3005", "color": 14,
			"x": snappedf(at.x / 20.0 - 0.5, 0.1), "y": y, "z": snappedf(at.z / 20.0 - 0.5, 0.1)}], "picture": false})
		for brick: BrickWorld.Brick in _world.bricks():
			if not before.has(brick.id):
				made.append(brick.id)
		if not made.is_empty():
			said = "y %s: %s" % [y, said]
			break
	var still: bool = _builder.is_holding_figure()
	var back: bool = _figure_back()
	_main.call("_refresh_preview")
	await _frames(6)
	var meets: Array = _overlaps(made, _figure_ids())
	var t1: String = _text(name)
	_result("sessadd", "in hand %s; %s; made %s; still in hand %s; Escape put back %s; torsos %d; overlaps %s; file torsos %d"
		% [held, said.left(160).replace("\n", " / "), made, still, back, _torsos().size(), meets.slice(0, 6),
			_figure_count_in(t1)])
	_check("sessadd: a session's part is not put where the figure in hand stands in the file, or the figure goes back first (%d meet)"
		% meets.size(), meets.is_empty())
	_check("sessadd: the figure is not lost (%d torsos)" % _torsos().size(), _torsos().size() == 1)
	await _drop_all()
	await _back_to(depth)


# -- X over one plain part ---------------------------------------------------------


func _case_plainx() -> void:
	print("\nPX. X over one plain part: autosave, Ctrl+S, Escape, put down where it stood")
	var path: String = _fixture2("fr3_plainx", REPLAN)
	for how: String in ["write", "escape", "home"]:
		if not await _to_step(path, "last"):
			_check("plainx %s: opens" % how, false)
			continue
		var name: String = "figreview3 plainx " + how
		var t0: String = _text(name)
		var full0: Array = _full()
		var kept0: Array = _kept()
		var depth: int = _builder.history_depth()
		var ref: int = _ref_brick()
		var was: Transform3D = _world.get_brick(ref).transform
		_builder.clear_selection()
		var lifted: bool = _builder.lift_brick(ref)
		_verbs.set_mode("place")
		await _frames(4)
		var on_model: bool = _world.get_brick(ref) != null
		match how:
			"write":
				var text: String = _written()
				var unsaved: bool = _store.has_unsaved_work()
				_forget(name)
				_store.title = name
				_store.save_as(name)
				var after_save: bool = _store.has_unsaved_work()
				_forget(name)
				_result("plainx.write", "lifted %s, still on the model %s; autosave in hand: %d red 3003s (opened %d); unsaved in hand %s, after Ctrl+S in hand %s"
					% [lifted, on_model, _count_in_colour(text, "3003", 2), _count_in_colour(t0, "3003", 2), unsaved,
						after_save])
				_check("plainx write: the autosave written with one part lifted by X has it (%d)"
					% _count_in_colour(text, "3003", 2), _count_in_colour(text, "3003", 2) == 1)
				_check("plainx write: after Ctrl+S with it in hand, it still counts as unsaved work", after_save)
			"escape":
				_verbs.set_mode("select")
				_main.call("_refresh_preview")
				await _frames(6)
				var text: String = _text(name)
				_result("plainx.escape", "lifted %s; Escape (Select): parts %d (were %d), red 3003s in the file %d; depth %d (was %d)"
					% [lifted, _full().size(), full0.size(), _count_in_colour(text, "3003", 2), _builder.history_depth(), depth])
				_check("plainx escape: one part lifted by X and Escape is put back, not taken off (%d parts, were %d)"
					% [_full().size(), full0.size()], _full().size() == full0.size())
			"home":
				await _aim(Vector3(was.origin.x, 0, was.origin.z))
				var id: int = _builder.place()
				await _frames(6)
				var t1: String = _text(name)
				var lost: Array = _arr_diff(kept0, _kept())
				_result("plainx.home", "lifted %s; put #%d (was #%d); depth %d (was %d); kept differ %s; %d lines changed: %s"
					% [lifted, id, ref, _builder.history_depth(), depth, lost, _line_diff(t0, t1).size(),
						_line_diff(t0, t1).slice(0, 6)])
				_check("plainx home: put down where it stood, its step, sub-model and file line kept (%s)" % [lost],
					id != 0 and lost.is_empty())
				_check("plainx home: put down where it stood, the file as opened (%d lines differ)"
					% _line_diff(t0, t1).size(), t1 == t0)
		await _drop_all()
		_verbs.set_mode("select")
		await _back_to(depth)


func _count_in_colour(text: String, part: String, colour: int) -> int:
	var n: int = 0
	for line: String in text.split("\n"):
		var words: PackedStringArray = line.strip_edges().split(" ", false)
		if words.size() >= 15 and words[0] == "1" and int(words[1]) == colour \
				and words[14].to_lower().begins_with(part):
			n += 1
	return n


func _case_cars() -> void:
	print("\nCA. X over one plain part of a car placed twice, put down where it stood")
	for count: String in ["one", "two"]:
		var path: String = _fixture2("fr3_cars_" + count, NEST.replace("%CARS%",
			ONE_CAR if count == "one" else TWO_CARS))
		if not await _to_step(path, "last"):
			_check("cars %s: opens" % count, false)
			continue
		var name: String = "figreview3 cars " + count
		var t0: String = _text(name)
		var kept0: Array = _kept()
		var placed0: Array = _placed()
		var depth: int = _builder.history_depth()
		var white: int = 0
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id.begins_with("3001") and brick.color_code == 15 and white == 0 \
					and absf(absf(brick.transform.origin.z) - 40.0) < 1.0:
				white = brick.id
		if white == 0:
			_check("cars %s: the car's white brick found" % count, false)
			continue
		var was: Transform3D = _world.get_brick(white).transform
		var whites0: int = _count_colour(15, "3001")
		_builder.clear_selection()
		var lifted: bool = _builder.lift_brick(white)
		_verbs.set_mode("place")
		await _frames(6)
		var whites_in_hand: int = _count_colour(15, "3001")
		var t_hand: String = _written()
		await _aim(Vector3(was.origin.x, 0, was.origin.z))
		var id: int = _builder.place()
		await _frames(8)
		var t1: String = _text(name)
		var placed1: Array = _placed()
		var lost: Array = _arr_diff(kept0, _kept())
		var refused: String = str(_verbs.assemblies.refused) if _verbs.assemblies != null else ""
		_result("cars.%s" % count, "lifted %s; white 3001s on the model %d, in hand %d, after %d; autosave in hand: %d white lines; put #%d; refused '%s'; kept differ %s; %d lines changed: %s"
			% [lifted, whites0, whites_in_hand, _count_colour(15, "3001"), _count_in_colour(t_hand, "3001", 15), id,
				refused.left(80), lost.slice(0, 6), _line_diff(t0, t1).size(), _line_diff(t0, t1).slice(0, 8)])
		_check("cars %s: X over one car's part, no other car loses its own while it is in hand (%d of %d)"
			% [count, whites_in_hand, whites0], whites_in_hand >= whites0 - 1)
		_check("cars %s: put down where it stood, every part in its own step, sub-model and line (%s)" % [count, lost.slice(0, 4)],
			id != 0 and lost.is_empty())
		_check("cars %s: put down where it stood, the file as opened (%d lines differ)" % [count, _line_diff(t0, t1).size()],
			t1 == t0)
		await _drop_all()
		_verbs.set_mode("select")
		await _back_to(depth)
		_check("cars %s: undone, the file as opened (%d placed now differ from opened)" % [count,
			_arr_diff(placed0, _placed()).size()], _text(name) == t0)
		await _reopen_check("cars " + count, t1, placed1)


func _count_colour(colour: int, part: String) -> int:
	var n: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.color_code == colour and brick.part_id.begins_with(part):
			n += 1
	return n


# -- Connect, a tool chosen, a session's undo ------------------------------------------


func _case_connect() -> void:
	print("\nCO. Connect's click on a figure's torso, then Select")
	var path: String = _fixture2("fr3_connect", REPLAN)
	if not await _to_step(path, "last"):
		_check("connect: opens", false)
		return
	var name: String = "figreview3 connect"
	var t0: String = _text(name)
	var full0: Array = _full()
	var depth: int = _builder.history_depth()
	var torso: int = int(_torsos()[0])
	_builder.clear_selection()
	_verbs.set_mode("connect")
	await _frames(4)
	var tool: Node = _verbs.connect_tool
	var took: bool = bool(tool.call("take", torso))
	await _frames(6)
	var stage: String = str(tool.get("stage"))
	var holding: bool = _builder.is_holding_figure()
	var hand: int = _held_count()
	var t_mid: String = _written()
	_verbs.set_mode("select")
	await _frames(6)
	var holding2: bool = _builder.is_holding_figure()
	var hand2: int = _held_count()
	var unsaved: bool = _store.has_unsaved_work()
	var t1: String = _text(name)
	_result("connect", "take %s; stage '%s'; figure in hand %s, parts in hand %d; autosave torsos %d; then Select: figure in hand %s, parts in hand %d; unsaved %s; torsos on the model %d; file as opened %s; depth %d (was %d)"
		% [took, stage, holding, hand, _figure_count_in(t_mid), holding2, hand2, unsaved, _torsos().size(),
			t1 == t0, _builder.history_depth(), depth])
	_check("connect: a click on a figure with Connect leaves nothing lifted unseen once Select is chosen (figure in hand %s)"
		% holding2, not holding2)
	_check("connect: the figure is on the model and in the file (%d torsos)" % _figure_count_in(t1),
		_figure_count_in(t1) == 1 and _full().size() == full0.size())
	await _drop_all()
	await _back_to(depth)


func _case_tool() -> void:
	print("\nTO. a figure in hand, the Select tool chosen")
	var path: String = _fixture2("fr3_tool", REPLAN)
	if not await _to_step(path, "last"):
		_check("tool: opens", false)
		return
	var depth: int = _builder.history_depth()
	var torso: int = int(_torsos()[0])
	_builder.clear_selection()
	_builder.lift_brick(torso)
	_verbs.set_mode("place")
	await _frames(4)
	_verbs.set_mode("select")
	_main.call("_refresh_preview")
	await _frames(6)
	var holding: bool = _builder.is_holding_figure()
	var ghost: bool = _builder.has_preview()
	var drawn: int = 0
	for brick_id: int in _figure_ids():
		if not _world.has_method("in_hand") or not bool(_world.call("in_hand", brick_id)):
			drawn += 1
	_result("tool", "Select chosen with a figure in hand: still in hand %s, its ghost shown %s, its parts drawn %d of %d, torsos on the model %d"
		% [holding, ghost, drawn, _figure_ids().size(), _torsos().size()])
	_check("tool: choosing Select with a figure in hand puts it back, or keeps it shown (in hand %s, ghost %s, drawn %d)"
		% [holding, ghost, drawn], not holding and _torsos().size() == 1 or ghost)
	await _drop_all()
	await _back_to(depth)


func _case_sessundo() -> void:
	print("\nSU. a session's edit, the person's lift, then the session's undo")
	var path: String = _fixture2("fr3_sessundo", REPLAN)
	if not await _to_step(path, "last"):
		_check("sessundo: opens", false)
		return
	var depth: int = _builder.history_depth()
	var ref: int = _ref_brick()
	var said1: String = await _call("edit_model", {"recolor": [{"bricks": [ref], "color": 14}], "picture": false})
	var painted: bool = _world.get_brick(ref).color_code == 14
	_builder.clear_selection()
	_builder.lift_brick(int(_torsos()[0]))
	await _frames(4)
	var said2: String = await _call("undo", {})
	await _frames(6)
	var colour: int = _world.get_brick(ref).color_code
	var holding: bool = _builder.is_holding_figure()
	_result("sessundo", "session painted %s (%s); person lifted the figure; session undo: '%s'; the brick now colour %d; person still holds the figure %s"
		% [painted, said1.left(60).replace("\n", " / "), said2.left(160).replace("\n", " / "), colour, holding])
	_check("sessundo: the session's undo takes back the session's paint (colour %d) and leaves the person's figure in hand (%s)"
		% [colour, holding], colour != 14 and holding)
	await _drop_all()
	await _back_to(depth)


# -- a car carried whole, a part the app cannot show in it -----------------------------


func _case_whole() -> void:
	print("\nWH. a car carried whole, a part the app cannot show in it, put down away")
	var path: String = _fixture2("fr3_whole", UNSHOWN)
	if not await _open(path):
		_check("whole: opens", false)
		return
	_steps.to_end()
	await _frames(6)
	var name: String = "figreview3 whole"
	var t0: String = _text(name)
	var depth: int = _builder.history_depth()
	_builder.clear_selection()
	var car: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.group == "car":
			car.append(brick.id)
			_builder.select_brick(brick.id, true)
	var count: int = _verbs.lift()
	await _frames(4)
	var t_hand: String = _written()
	await _aim(Vector3(-100, 0, 300))
	var id: int = _builder.place()
	await _frames(8)
	var t1: String = _text(name)
	var diff: Array = _line_diff(t0, t1)
	var placed1: Array = _placed()
	_result("whole", "car parts %d, lifted %d; autosave in hand: noshape lines %d, 3001 lines %d (opened %d, %d); put #%d; %d lines changed: %s"
		% [car.size(), count, _count_in(t_hand, "zzfr3"), _count_in(t_hand, "3001"), _count_in(t0, "zzfr3"),
			_count_in(t0, "3001"), id, diff.size(), diff.slice(0, 8)])
	_check("whole: the part the app cannot show is in the file in hand and after (%d, %d)"
		% [_count_in(t_hand, "zzfr3"), _count_in(t1, "zzfr3")], _count_in(t_hand, "zzfr3") == 1 and _count_in(t1, "zzfr3") == 1)
	_check("whole: the car moved whole changes only the line that places it (%d lines: %s)" % [diff.size(), diff.slice(0, 4)],
		id != 0 and diff.size() == 2 and str(diff[0]).contains("car.ldr") and str(diff[1]).contains("car.ldr"))
	await _undo()
	_check("whole: one Undo, the file as opened byte for byte", _text(name) == t0)
	await _back_to(depth)
	await _reopen_check("whole", t1, placed1)


# -- a selection carried ------------------------------------------------------------------


func _case_carry() -> void:
	print("\nCR. a selection carried: autosave, Ctrl+S, Escape, put down, Undo")
	var path: String = _fixture2("fr3_carry", REPLAN)
	if not await _to_step(path, "fig"):
		_check("carry: opens", false)
		return
	var name: String = "figreview3 carry"
	var t0: String = _text(name)
	var full0: Array = _full()
	var kept0: Array = _kept()
	var line0: String = _timeline()
	var depth: int = _builder.history_depth()
	var walls: Array = _walls()
	_builder.clear_selection()
	for brick_id: int in walls:
		_builder.select_brick(brick_id, true)
	var count: int = _verbs.lift()
	await _frames(4)
	var text: String = _written()
	var unsaved: bool = _store.has_unsaved_work()
	_forget(name)
	_store.title = name
	_store.save_as(name)
	var after_save: bool = _store.has_unsaved_work()
	_forget(name)
	_verbs.put_away()
	await _frames(6)
	var t1: String = _text(name)
	_result("carry.escape", "lifted %d; autosave in hand: 3003s %d (opened %d); unsaved %s, after Ctrl+S %s; Escape: file as opened %s; timeline %s (was %s)"
		% [count, _count_in(text, "3003"), _count_in(t0, "3003"), unsaved, after_save, t1 == t0, _timeline(), line0])
	_check("carry: the autosave in hand has every part (%d of %d)" % [_count_in(text, "3003"), _count_in(t0, "3003")],
		_count_in(text, "3003") == _count_in(t0, "3003"))
	_check("carry: after Ctrl+S in hand it still counts as unsaved", after_save)
	_check("carry: Escape, the file as opened byte for byte, the timeline as it was",
		t1 == t0 and _full() == full0 and _same_steps(_timeline(), line0))
	_builder.clear_selection()
	for brick_id: int in walls:
		_builder.select_brick(brick_id, true)
	var again: int = _verbs.lift()
	_result("carry.again", "lifted %d again" % again)
	await _frames(4)
	await _aim(Vector3(-300, 0, 300))
	var id: int = _builder.place()
	await _frames(6)
	var t2: String = _text(name)
	var kept_lost: Array = _arr_diff(kept0, _kept())
	_result("carry.put", "put #%d; depth %d (was %d); %d lines changed: %s; timeline %s"
		% [id, _builder.history_depth(), depth, _line_diff(t0, t2).size(), _line_diff(t0, t2).slice(0, 6), _timeline()])
	_check("carry: put down, one step, only the moved parts' lines change (%d)" % _line_diff(t0, t2).size(),
		id != 0 and _builder.history_depth() == depth + 1 and _line_diff(t0, t2).size() == 2 * walls.size()
		and kept_lost.is_empty())
	await _undo()
	_check("carry: one Undo, byte for byte", _text(name) == t0 and _full() == full0)
	await _back_to(depth)


# -- a set's model turned with a figure in hand --------------------------------------------


func _case_dense() -> void:
	print("\nDE. 6541-1 at its last step: a figure lifted, the model turned, Escape")
	var path: String = _omr("6541-1")
	if not await _to_step(path, "last"):
		_check("dense: opens", false)
		return
	var name: String = "figreview3 dense"
	var depth: int = _builder.history_depth()
	var torso: int = int(_torsos()[0])
	var members: Array = Array(_builder.figure_of(torso))
	var others: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not members.has(brick.id):
			others.append(brick.id)
	var meets0: Array = _overlaps(members, others)
	_builder.clear_selection()
	var held: bool = _builder.lift_brick(torso) and _builder.is_holding_figure()
	await _frames(4)
	_main.call("_turn_model", 1)
	await _frames(6)
	var back: bool = _figure_back()
	_main.call("_refresh_preview")
	await _frames(6)
	var meets1: Array = _overlaps(members, others)
	var t1: String = _text(name)
	_result("dense", "figure of %d parts, in hand %s; turned; Escape put back %s; its parts meeting others before %d, after %d: %s; torsos in the file %d"
		% [members.size(), held, back, meets0.size(), meets1.size(), meets1.slice(0, 6), _figure_count_in(t1)])
	_check("dense: turned with a figure in hand and Escape, the figure is in no other part (%d meet, %d before)"
		% [meets1.size(), meets0.size()], meets1.size() <= meets0.size())
	await _drop_all()
	await _back_to(depth)


# -- Escape after the timeline stepped ------------------------------------------------------


func _case_stepesc() -> void:
	print("\nSE. a figure lifted at the last step, the timeline stepped back to the start, Escape")
	var path: String = _fixture2("fr3_stepesc", REPLAN)
	if not await _to_step(path, "last"):
		_check("stepesc: opens", false)
		return
	var depth: int = _builder.history_depth()
	var torso: int = int(_torsos()[0])
	var members: Array = Array(_builder.figure_of(torso))
	_builder.clear_selection()
	_builder.lift_brick(torso)
	await _frames(4)
	_steps.to_start()
	await _frames(8)
	var back: bool = _figure_back()
	_main.call("_refresh_preview")
	await _frames(8)
	var wrong: Array = []
	for brick_id: int in members:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null:
			wrong.append("#%d gone" % brick_id)
		elif brick.hidden != _ahead(brick_id):
			wrong.append("#%d hidden %s ahead %s" % [brick_id, brick.hidden, _ahead(brick_id)])
	_steps.to_end()
	await _frames(8)
	var wrong_end: Array = []
	for brick_id: int in members:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick != null and (brick.hidden or _ahead(brick_id)):
			wrong_end.append("#%d hidden %s ahead %s" % [brick_id, brick.hidden, _ahead(brick_id)])
	_camera.frame(_main.call("_built_bounds"))
	await _frames(10)
	await _shot("stepesc_end")
	_steps.stop()
	await _frames(8)
	var hidden_off: int = 0
	for brick_id: int in members:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick != null and brick.hidden:
			hidden_off += 1
	_result("stepesc", "Escape at the start put back %s; parts drawn against the step: %s; at the end: %s; the timeline put away: %d of %d still hidden"
		% [back, wrong, wrong_end, hidden_off, members.size()])
	_check("stepesc: put back with the timeline stepped back, each part drawn as its step says (%s, %s)"
		% [wrong, wrong_end], wrong.is_empty() and wrong_end.is_empty())
	await _drop_all()
	await _back_to(depth)
	# No step change at all: lifted and let go at the last step, the
	# timeline open throughout.
	if not await _to_step(path, "last"):
		return
	torso = int(_torsos()[0])
	members = Array(_builder.figure_of(torso))
	_builder.clear_selection()
	_builder.lift_brick(torso)
	await _frames(8)
	var back_same: bool = _figure_back()
	await _frames(8)
	var wrong_same: Array = []
	for brick_id: int in members:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null or brick.hidden:
			wrong_same.append("#%d %s" % [brick_id, "gone" if brick == null else "hidden"])
	_result("stepesc.same", "lifted and Escape at the last step: put back %s; not drawn %s" % [back_same, wrong_same])
	_check("stepesc same step: Escape at the step it was lifted at, every part drawn (%s)" % [wrong_same],
		wrong_same.is_empty())
	await _drop_all()
	await _back_to(depth)
	# The same for a part carried (the red brick of the last step).
	if not await _to_step(path, "last"):
		return
	var ref: int = _ref_brick()
	_builder.clear_selection()
	_builder.select_brick(ref, false)
	var lifted: int = _verbs.lift()
	await _frames(4)
	_steps.to_start()
	await _frames(8)
	_verbs.put_away()
	await _frames(8)
	_steps.to_end()
	await _frames(8)
	var brick2: BrickWorld.Brick = _world.get_brick(ref)
	_result("stepesc.carry", "lifted %d; Escape at the start, then the end: hidden %s, ahead %s"
		% [lifted, brick2.hidden if brick2 != null else "gone", _ahead(ref)])
	_check("stepesc carry: put back at the start, at the end it is drawn",
		brick2 != null and not brick2.hidden and not _ahead(ref))
	await _drop_all()
	await _back_to(depth)
