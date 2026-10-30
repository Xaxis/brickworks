## Moving by a number, a turn with no room, and a clone that stays in hand,
## as a person does them: keys and clicks sent as input events against the
## real scene, each action counted the way docs/APP_UX.md counts them (a
## click, a key, an aim of the pointer somewhere new, and a number typed,
## each one; the characters typed are counted too).
##
##   godot --path . --resolution 1400x900 --script src/dev/typed_moves_probe.gd [-- only=SECTION,…]
##
## SECTION is clones (A6: five copies in six actions), wall (A3: the walk's
## brick turned in its wall in three), typed (B1: what the field reads, puts
## and refuses, one undo a placement) or sets (B1's bar: the four parts
## CADTASK's section 9 typed in Properties, and 8841-1's pan swung to
## 23.58°, each put from the part in hand by a number). Pictures go to
## shots/typed/.
extends SceneTree

const SETS := "res://vendor/omr/files/"
const EXACT_PLACE := 0.05
const EXACT_TURN := 0.002

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Shell
var _verbs: EditVerbs
## What a person did, by kind, since the last _count_from().
var _acts: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
	for section: String in ["reading", "clones", "wall", "typed", "sets"]:
		if only.is_empty() or section in only.split(","):
			print("  -- %s" % section)
			# Each on an empty floor, whatever ran before it.
			_verbs.set_mode("select")
			_builder.clear_selection()
			_main.call("clear_model")
			await _frames(4)
			await call("_" + section)
			await _rest()
	print("")
	print("typed moves: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## Nothing in hand, nothing selected, the Select tool, and the model empty.
func _rest() -> void:
	if _verbs.typed.is_open():
		await _key(KEY_ESCAPE)
	if _builder.is_carrying():
		_verbs.put_away()
	_verbs.set_mode("select")
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(6)


# -- what the field reads ------------------------------------------------------


func _reading() -> void:
	var x := Vector3(1, 0, 0)
	var cases: Array = [
		["12", "move", x, Vector3(240, 0, 0), 0.0, 0.0],
		["3x", "move", Vector3.ZERO, Vector3(60, 0, 0), 0.0, 0.0],
		["x 3", "move", Vector3.ZERO, Vector3(60, 0, 0), 0.0, 0.0],
		["-2z", "move", Vector3.ZERO, Vector3(0, 0, -40), 0.0, 0.0],
		["3py", "move", Vector3.ZERO, Vector3(0, 24, 0), 0.0, 0.0],
		["y 3p", "move", Vector3.ZERO, Vector3(0, 24, 0), 0.0, 0.0],
		["2b y", "move", Vector3.ZERO, Vector3(0, 48, 0), 0.0, 0.0],
		["7 ldu y", "move", Vector3.ZERO, Vector3(0, 7, 0), 0.0, 0.0],
		["-14ly", "move", Vector3.ZERO, Vector3(0, -14, 0), 0.0, 0.0],
		["5mm x", "move", Vector3.ZERO, Vector3(12.5, 0, 0), 0.0, 0.0],
		["40/2+1lx", "move", Vector3.ZERO, Vector3(21, 0, 0), 0.0, 0.0],
		["2x-1py", "move", Vector3.ZERO, Vector3(40, -8, 0), 0.0, 0.0],
		["23.58", "turn", Vector3.ZERO, Vector3.ZERO, 23.58, 0.0],
		["23.58r", "move", Vector3.ZERO, Vector3.ZERO, 23.58, 0.0],
		["30", "tilt", Vector3.ZERO, Vector3.ZERO, 0.0, 30.0],
		["-30t", "move", Vector3.ZERO, Vector3.ZERO, 0.0, -30.0],
		["15 2lx", "turn", Vector3.ZERO, Vector3(2, 0, 0), 15.0, 0.0],
	]
	for case: Array in cases:
		var read: Dictionary = TypedEntry.parse(case[0], case[1], case[2])
		var ok: bool = str(read["error"]).is_empty() and not bool(read["empty"]) \
			and (read["move"] as Vector3).is_equal_approx(case[3]) \
			and is_equal_approx(float(read["turn"]), case[4]) \
			and is_equal_approx(float(read["tilt"]), case[5])
		_check("“%s” after %s reads as %s (%s)" % [case[0], case[1], read["words"],
			read["error"]], ok)
	for wrong: String in ["12", "3q", "x 3 deg", "r 3p"]:
		var read: Dictionary = TypedEntry.parse(wrong, "move", Vector3.ZERO)
		_check("“%s” is refused with words: %s" % [wrong, read["error"]],
			not str(read["error"]).is_empty())
	for unfinished: String in ["-", "3+", "x"]:
		var read: Dictionary = TypedEntry.parse(unfinished, "move", x)
		_check("“%s” is not finished, not wrong" % unfinished, bool(read["empty"])
			and str(read["error"]).is_empty())


# -- A6: a clone stays in hand ---------------------------------------------------


func _clones() -> void:
	_put("3004", 4, Vector3(-150, 24, 10))
	_camera.frame(AABB(Vector3(-200, 0, -120), Vector3(400, 80, 240)))
	await _frames(40)
	var tools: Toolbar = _shell.toolbar
	var buttons: Dictionary = tools._buttons
	await _click((buttons["mode_clone"] as Button).get_global_rect().get_center())
	_check("the Clone tool is on", _verbs.mode == "clone")
	_count_from()
	var start: int = _count()
	var depth: int = _builder.history_depth()
	await _act_click(_screen(Vector3(-150, 24, 10)))
	_check("a click on the part holds a copy", _builder.is_carrying())
	var spots: Array = []
	for n: int in 5:
		spots.append(_screen(Vector3(-90 + n * 60, 0, 10)))
	var stayed: bool = true
	for spot: Vector2 in spots:
		await _act_click(spot)
		stayed = stayed and _builder.is_carrying()
	await _shot("five_clones")
	_check("five clicks put five copies down (%d parts) and a copy stayed in hand after each"
		% _count(), _count() == start + 5 and stayed)
	_check("five copies in %d actions (bar: 6) — %s" % [_total(), _acts], _total() <= 6)
	_check("each copy is a step of its own to undo (%d steps)" % (_builder.history_depth() - depth),
		_builder.history_depth() - depth == 5)
	await _key(KEY_Z, true)
	_check("one undo takes one copy back (%d parts)" % _count(), _count() == start + 4)
	await _key(KEY_Z, true, true)
	await _key(KEY_ESCAPE)
	_check("Esc lets go of the copy, and the tool goes back to Select",
		not _builder.is_carrying() and _verbs.mode == "select")

	# Ctrl-D, the same: a key and five clicks.
	_main.call("clear_model")
	_put("3004", 4, Vector3(-150, 24, 10))
	await _frames(4)
	_select_only(_model().map(func(b: BrickWorld.Brick) -> int: return b.id))
	_count_from()
	start = _count()
	await _key(KEY_D, true)
	_acts["key"] = int(_acts["key"]) + 1
	for spot: Vector2 in spots:
		await _act_click(spot)
	_check("Ctrl-D and five clicks: five copies (%d parts) in %d actions, still holding one"
		% [_count(), _total()], _count() == start + 5 and _total() <= 6
		and _builder.is_carrying())
	await _right_click(_screen(Vector3(0, 0, 160)))
	_check("a right click lets go of it", not _builder.is_carrying())

	# A paste goes once, as before.
	_select_only([_model()[0].id])
	await _key(KEY_C, true)
	await _move(spots[0] + Vector2(0, 80))
	await _key(KEY_V, true)
	await _click(spots[0] + Vector2(0, 80))
	_check("a paste still goes once", not _builder.is_carrying())
	# And another tool ends a clone's run.
	_select_only([_model()[0].id])
	await _key(KEY_D, true)
	await _click((buttons["mode_move"] as Button).get_global_rect().get_center())
	_check("choosing another tool puts the clone's copy away",
		not _builder.is_carrying() and _verbs.mode == "move")


# -- A3: a turn with no room comes into hand -------------------------------------


## The walk's wall (docs/app_ux/appux_walk.gd): four 1 x 4 bricks in a row
## and four more on them half a brick along.
func _wall() -> void:
	for row: int in 2:
		for n: int in 4:
			_put("3010", 4, Vector3(-120 + n * 80 + row * 40, 24 + row * 24, 10))
	_camera.frame(AABB(Vector3(-200, -40, -120), Vector3(400, 120, 240)))
	await _frames(40)
	_shell.set_turn_step(15)
	# The bottom row's second: a brick on each side and two on it.
	var first: BrickWorld.Brick = _at(Vector3(-40, 24, 10))
	var was: Transform3D = first.transform
	var whole: int = _count()
	_select_only([first.id])
	await _frames(4)
	await _shot("wall_before")
	_count_from()
	await _key(KEY_R)
	_acts["key"] = int(_acts["key"]) + 1
	var red: Dictionary = _world.tinted_ids()
	var in_way: Array = Array(_verbs.flashed)
	_check("R: what is in the way is shown red (%d parts: %s)" % [in_way.size(), in_way],
		in_way.size() >= 1 and in_way.all(func(id: int) -> bool: return red.has(id)))
	_check("...and the brick is in hand, turned 15° (%s)" % _held_yaw(),
		_builder.is_carrying() and absf(_held_yaw() - 15.0) < 0.01)
	await _shot("wall_turn_in_hand")
	var spot: Vector2 = _screen(Vector3(-40, 0, 110))
	await _act_move(spot)
	await _frames(2)
	_check("aimed clear of the wall, it may go down there", _builder.can_place())
	await _act_click(spot)
	var put: BrickWorld.Brick = _newest()
	var yaw: float = rad_to_deg(put.transform.basis.get_euler().y) if put != null else 0.0
	_check("a click puts it down turned 15° (%.2f°), the wall's count kept (%d)" % [yaw, _count()],
		put != null and absf(yaw - 15.0) < 0.01 and _count() == whole)
	_check("the turned brick is down in %d actions (bar: 3) — %s" % [_total(), _acts],
		_total() <= 3)
	await _shot("wall_turned_down")
	await _key(KEY_Z, true)
	var back: BrickWorld.Brick = _at(was.origin)
	_check("one undo puts it back in the wall, square", back != null
		and back.transform.is_equal_approx(was) and _count() == whole)
	_select_only([back.id] if back != null else [])
	await _key(KEY_R)
	await _key(KEY_ESCAPE)
	back = _at(was.origin)
	_check("R then Esc: back as it was", back != null and back.transform.is_equal_approx(was)
		and not _builder.is_carrying() and _count() == whole)
	# The Rotate tool, the same.
	_verbs.set_mode("rotate")
	await _click(_spot_on(_at(was.origin)))
	_check("the Rotate tool in the wall: in hand, turned", _builder.is_carrying())
	await _key(KEY_ESCAPE)
	_check("...and Esc puts it back", _at(was.origin) != null and _count() == whole)
	_verbs.set_mode("select")
	# And T, with a brick in front and one behind: tipped over, a 1 x 4 is
	# deeper than it is wide.
	_put("3010", 4, Vector3(-40, 24, 30))
	_put("3010", 4, Vector3(-40, 24, -10))
	whole = _count()
	await _frames(3)
	back = _at(was.origin)
	_select_only([back.id] if back != null else [])
	await _key(KEY_T)
	_check("T in the wall: in hand, tipped", _builder.is_carrying())
	await _key(KEY_ESCAPE)
	_check("...and Esc puts it back", _at(was.origin) != null and _count() == whole)
	await create_timer(1.2).timeout
	_check("the red is gone after a second", _world.tinted_ids().is_empty())
	# Typed straight after: 30° instead of R's 15.
	_verbs.set_mode("select")
	back = _at(was.origin)
	_select_only([back.id] if back != null else [])
	await _key(KEY_R)
	await _type("30")
	_check("a number straight after takes R's place: in hand at 30° (%.2f)" % _held_yaw(),
		absf(_held_yaw() - 30.0) < 0.01)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)


## A point on the screen where this part is the one under the pointer: its
## top is under the bricks on it, so round its middle.
func _spot_on(brick: BrickWorld.Brick) -> Vector2:
	if brick == null:
		return Vector2.ZERO
	var middle: Vector2 = _screen(brick.transform.origin + Vector3(0, -12, 0))
	for r: int in range(0, 60, 4):
		for d: Vector2 in [Vector2(0, r), Vector2(r, 0), Vector2(-r, 0), Vector2(0, -r)]:
			if _verbs.brick_at(middle + d) == brick.id:
				return middle + d
	return middle


func _held_yaw() -> float:
	if not _builder.is_carrying() or _builder.carrying.items.is_empty():
		return 0.0
	var item: Dictionary = _builder.carrying.items[0]
	var basis: Basis = Basis(Vector3.UP, _builder.carrying.turns * PI * 0.5) \
		* (item["at"] as Transform3D).basis
	return rad_to_deg(basis.get_euler().y)


# -- B1: what the field puts, refuses and undoes --------------------------------


func _typed() -> void:
	_camera.frame(AABB(Vector3(-200, 0, -120), Vector3(400, 80, 240)))
	await _frames(30)
	_main.call("_on_part_chosen", "3001")
	await _frames(4)
	var spot: Vector2 = _screen(Vector3(-100, 0, 0))
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	var ghost: Transform3D = _builder.ghost_transform()
	_check("a 2 x 4 in hand over the floor", _builder.can_place())
	var start: int = _count()
	await _type("3x")
	_check("3x opens the field at the pointer, saying %s" % _meaning(), _verbs.typed.is_open()
		and _meaning().begins_with("x +3 studs"))
	_check("...and the ghost stands 3 studs along x (%s)" % _builder.ghost_transform().origin,
		_builder.ghost_transform().origin.is_equal_approx(ghost.origin + Vector3(60, 0, 0)))
	await _move(spot + Vector2(40, 30))
	_check("...and stays there while the pointer moves",
		_builder.ghost_transform().origin.is_equal_approx(ghost.origin + Vector3(60, 0, 0)))
	await _shot("typed_3x")
	var depth: int = _builder.history_depth()
	await _key(KEY_ENTER)
	var put: BrickWorld.Brick = _newest()
	_check("Enter puts it there exactly (%s)" % (put.transform.origin if put != null else null),
		put != null and put.transform.origin.is_equal_approx(ghost.origin + Vector3(60, 0, 0))
		and _count() == start + 1)
	_check("...as one step to undo, the part still in hand, the field closed",
		_builder.history_depth() == depth + 1 and _verbs.mode == "place"
		and not _verbs.typed.is_open() and not _builder.is_pinned())
	await _key(KEY_Z, true)
	_check("one undo takes it back", _count() == start)
	# Six studs along, clear of the ghost however it is turned.
	_put("3001", 4, ghost.origin + Vector3(120, 0, 0))
	await _frames(3)

	# Refused: onto a part already there.
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	await _type("6x")
	_check("onto a part already there: red, saying so (%s)" % _meaning(),
		_meaning().contains("no room") and not _builder.can_place())
	await _key(KEY_ENTER)
	_check("...Enter puts nothing down and the field stays", _count() == start + 1
		and _verbs.typed.is_open())
	await _shot("typed_refused")
	await _key(KEY_ESCAPE)
	_check("Esc closes it, the part still in hand and following the pointer",
		not _verbs.typed.is_open() and not _builder.is_pinned() and _verbs.mode == "place")

	# Up, in plates, and a sum.
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	ghost = _builder.ghost_transform()
	await _type("3py")
	await _key(KEY_ENTER)
	put = _newest()
	_check("3py puts it 3 plates up (%s)" % (put.transform.origin if put != null else null),
		put != null and put.transform.origin.is_equal_approx(ghost.origin + Vector3(0, 24, 0)))
	await _key(KEY_Z, true)

	# A number alone goes the way the ghost last went.
	await _move(_screen(Vector3(-140, 0, 0)))
	await _move(_screen(Vector3(-100, 0, 0)))
	var way: Vector3 = _builder.last_way
	ghost = _builder.ghost_transform()
	await _type("2")
	_check("2 alone goes the way the ghost last went (%s): %s" % [way, _meaning()],
		way != Vector3.ZERO and _builder.ghost_transform().origin.is_equal_approx(
			ghost.origin + way * 40.0))
	await _key(KEY_ESCAPE)

	# R then a number: that turn instead of R's quarter.
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	var square: Basis = _builder.ghost_transform().basis
	await _key(KEY_R)
	await _type("30")
	var turned: Basis = _builder.ghost_transform().basis
	var by: float = rad_to_deg((turned * square.inverse()).get_euler().y)
	_check("R then 30: the part turned 30° from before R (%.2f°)" % by, absf(by - 30.0) < 0.01)
	await _key(KEY_ENTER)
	put = _newest()
	_check("...and put down so, off the grid", put != null
		and not BrickLattice.is_square_to_grid(put.transform.basis))
	await _key(KEY_ESCAPE)

	# A copy in hand: Ctrl-D, then a number.
	_verbs.set_mode("select")
	_builder.clear_selection()
	_main.call("clear_model")
	_put("3001", 4, Vector3(-60, 24, 20))
	await _frames(3)
	_select_only([_model()[0].id])
	await _key(KEY_D, true)
	var there: Vector2 = _screen(Vector3(60, 0, 20))
	await _move(there)
	await _move(there + Vector2(1, 0))
	var would: Vector3 = (_builder.carrying.placements(_builder)[0]["at"] as Transform3D).origin
	await _type("-2z")
	await _key(KEY_ENTER)
	var copy: BrickWorld.Brick = _newest()
	_check("Ctrl-D, -2z, Enter: the copy 2 studs back of its ghost (%s, the ghost at %s), another in hand"
		% [copy.transform.origin if copy != null else null, would], copy != null
		and copy.transform.origin.is_equal_approx(would + Vector3(0, 0, -40))
		and _builder.is_carrying())
	await _key(KEY_ESCAPE)

	# On the model, straight after R: the selection turned by the number.
	_builder.clear_selection()
	_main.call("clear_model")
	_put("3001", 4, Vector3(-60, 24, 20))
	await _frames(3)
	var one: BrickWorld.Brick = _model()[0]
	var facing: Transform3D = one.transform
	_select_only([one.id])
	_shell.set_turn_step(90)
	await _key(KEY_R)
	depth = _builder.history_depth()
	await _type("45")
	_check("R on the model then 45: shown in hand, %.2f° from where it stood" % _held_yaw(),
		_builder.is_carrying() and absf(_held_yaw() - 45.0) < 0.01)
	await _key(KEY_ENTER)
	one = _newest()
	var yaw: float = rad_to_deg((one.transform.basis * facing.basis.inverse()).get_euler().y) \
		if one != null else 0.0
	_check("...Enter: it stands turned 45° where it was, not 135 (%.2f°)" % yaw,
		one != null and absf(yaw - 45.0) < 0.01)
	await _key(KEY_Z, true)
	var after_undo: BrickWorld.Brick = _model()[0]
	_check("...and one undo puts it back as before R",
		after_undo.transform.is_equal_approx(facing))
	_shell.set_turn_step(90)
	# And Esc after R and a number leaves R's quarter, as before typing.
	_select_only([after_undo.id])
	await _key(KEY_R)
	var quarter: Transform3D = _model()[0].transform
	await _type("45")
	await _key(KEY_ESCAPE)
	_check("R, a number, Esc: as R left it", _model().size() == 1
		and _model()[0].transform.basis.is_equal_approx(quarter.basis)
		and not _builder.is_carrying())
	# Nothing in hand and no R: digits are the views, as before.
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	await _type("5")
	_check("with nothing in hand, 5 is still the view from above", not _verbs.typed.is_open())


# -- B1's bar: what CADTASK typed in Properties ------------------------------------


## [set file, part, its line among the file's parts, what it is]: the parts section
## 9's runs typed in Properties (docs/CADTASK.md, gap 9, the runs' build
## logs: 5762-1's step 18, 8643-1's steps 8 and 9, 8841-1's step 1) and the
## pan's first 4262 swung to 23.58 (gap 10). The runs typed their places in
## a model lifted or slid on the floor, so by another number than the file's.
const PLACES: Array = [
	["5762-1_Plane.mpd", "3065", 47, "the 1 x 2's height behind the slopes"],
	["8643-1_Combination-with-8644.mpd", "3023", 43, "a plate, its height"],
	["8643-1_Combination-with-8644.mpd", "50949", 44, "the cab top on its sockets"],
	["8841-1_Balance.mpd", "3703", 21, "the column on its pins"],
	["8841-1_Balance.mpd", "4262", 45, "the pan's 4262 swung 23.58°"],
]


func _sets() -> void:
	var rows: Array = []
	for place: Array in PLACES:
		rows.append(await _one_place(place))
	var path: String = ProjectSettings.globalize_path("res://shots/typed/sets.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, " "))
	file.close()


func _one_place(place: Array) -> Dictionary:
	var file: String = place[0]
	var part: String = place[1]
	var row: Dictionary = {"set": file, "part": part, "what": place[3]}
	var truth: Array = await _truth_of(file)
	var index: int = _index_of(truth, part, place[2])
	if index < 0:
		_check("%s %s: found in the file" % [file.get_slice("_", 0), part], false)
		return row
	var want: Transform3D = truth[index][2]
	row["index"] = index + 1
	_main.call("clear_model")
	await _frames(4)
	for n: int in index:
		var id: int = _world.add_brick(truth[n][0], truth[n][1], truth[n][2])
		_builder.register(id, truth[n][0], truth[n][2])
	_builder.clear_selection()
	var mesh: Lbm.PartMesh = _library.mesh_for(part)
	var box: AABB = (want * mesh.bounds).abs() if mesh != null else AABB(want.origin, Vector3.ONE)
	_camera.frame(box.grow(60.0), 1.4)
	_camera.look_from(Vector3(0.55, 0.62, 0.56).normalized())
	await _frames(40)
	_count_from()
	_main.call("_on_part_chosen", part)
	for _n: int in 600:
		if _library.mesh_for(part) != null:
			break
		await process_frame
	_acts["click"] = int(_acts["click"]) + 1
	_builder.held_color = int(truth[index][1])
	# Aimed first, as it comes: a part on a joint takes the joint's turn.
	# Turned with R and T only when the ghost is not turned as it goes.
	var aim: Dictionary = await _aim_near(want, box)
	if not bool(aim.get("turned", false)):
		await _turn_to(want.basis)
		var again: Dictionary = await _aim_near(want, box)
		if again.has("at") or not aim.has("at"):
			aim = again
	row["aims_tried"] = aim.get("tried", 0)
	if aim.is_empty() or not aim.has("at"):
		_check("%s %s: a ghost near its place" % [file.get_slice("_", 0), part], false)
		await _key(KEY_ESCAPE)
		return row
	await _act_move(aim["at"])
	var ghost: Transform3D = _builder.ghost_transform()
	row["ghost"] = _ldr_of(ghost)
	var text: String = _words_for(ghost, want)
	row["typed"] = text
	# Whether the file's place has room by the rule a part put down meets.
	var room: bool = _builder.room_for(part, want, false, true)
	var blocker: BrickWorld.Brick = _world.get_brick(_builder.room_blocker) \
		if _builder.room_blocker != 0 else null
	row["room"] = room
	if not room:
		print("    no room where the file has it: %s in the way (%s)" % [
			blocker.part_id if blocker != null else "?", _ldr_of(blocker.transform)
			if blocker != null else ""])
	var before: int = _count()
	if not text.is_empty():
		await _type(text)
		_acts["typed"] = int(_acts["typed"]) + 1
		_acts["chars"] = int(_acts["chars"]) + text.length()
		row["meaning"] = _meaning()
		var shown: Transform3D = _builder.ghost_transform()
		row["shown"] = _ldr_of(shown)
		if not _builder.can_place():
			var fits: bool = _builder.room_for(part, shown, false, true)
			var against: BrickWorld.Brick = _world.get_brick(_builder.room_blocker) \
				if _builder.room_blocker != 0 else null
			print("    typed, it shows at %s: room %s, %s in the way (%s); pinned %s, armed %s" % [
				row["shown"], fits, against.part_id if against != null else "nothing",
				_ldr_of(against.transform) if against != null else "", _builder.is_pinned(),
				_verbs.get("_armed")])
		await _shot("set_%s_%s" % [file.get_slice("_", 0), part])
	await _key(KEY_ENTER)
	_acts["key"] = int(_acts["key"]) + 1
	var put: BrickWorld.Brick = _newest() if _count() > before else null
	var got: Transform3D = put.transform if put != null else Transform3D()
	var exact: bool = put != null and _near(got, want, EXACT_PLACE, EXACT_TURN)
	row["put"] = _ldr_of(got) if put != null else "nothing"
	row["want"] = _ldr_of(want)
	row["acts"] = _acts.duplicate()
	row["actions"] = _total()
	row["with_characters"] = _total() - int(_acts["typed"]) + int(_acts["chars"])
	var bar: int = 6 if part == "4262" else 8
	_check("%s %s, %s: typed “%s”, put %s (wanted %s): %d actions (bar: %d), %d counting each character — %s"
		% [file.get_slice("_", 0), part, place[3], text, row["put"], row["want"], _total(), bar,
		row["with_characters"], _acts], exact and _total() <= bar)
	await _key(KEY_ESCAPE)
	return row


## The file's parts as the app reads it: [part, colour, transform].
func _truth_of(file: String) -> Array:
	_main.call("clear_model")
	await _frames(4)
	_store.open_text(FileAccess.get_file_as_string(SETS + file), file.get_basename())
	await _frames(10)
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append([brick.part_id, brick.color_code, brick.transform])
	return out


func _index_of(truth: Array, part: String, line: int) -> int:
	var at: int = line - 1
	if at < truth.size() and str(truth[at][0]).begins_with(part):
		return at
	print("    the file's part %d is %s, not %s" % [line,
		truth[at][0] if at < truth.size() else "past its end", part])
	return -1


## Turned by T and R to the quarter turn nearest [param basis], as a person
## turns a part in hand, each press counted: a part a set has off the
## quarters is turned the rest of the way by its joint or a typed number.
func _turn_to(basis: Basis) -> void:
	var faces: Array[String] = BrickLattice.FACES
	var face: String = _builder.held_face
	var turns: int = _builder.held_rotation
	var nearest: float = INF
	for f: String in faces:
		for r: int in 4:
			var q := Quaternion((BrickLattice.basis_for(f, r).inverse() * basis).orthonormalized())
			var angle: float = q.get_angle()
			angle = minf(angle, TAU - angle)
			if angle < nearest - 0.001:
				nearest = angle
				face = f
				turns = r
	var tips: int = posmod(faces.find(face) - maxi(faces.find(_builder.held_face), 0), faces.size())
	if tips > faces.size() / 2:
		tips -= faces.size()
	for _n: int in absi(tips):
		await _key(KEY_T, false, tips < 0)
		_acts["key"] = int(_acts["key"]) + 1
	var quarters: int = posmod(turns - _builder.held_rotation, 4)
	if quarters == 3:
		quarters = -1
	for _n: int in absi(quarters):
		await _key(KEY_R, false, quarters < 0)
		_acts["key"] = int(_acts["key"]) + 1


## The pointer at points round the part's place, and the joints near it, as
## a person aims at where it goes: the aim whose ghost stands nearest the
## place, turned as it is there (or on its joint), that may go down.
## {at, site} or {} — the search is the probe's, and only the aim kept is
## a person's.
func _aim_near(want: Transform3D, box: AABB) -> Dictionary:
	var points: Array = []
	var middle: Vector3 = box.get_center()
	for p: Vector3 in [want.origin, middle, middle + Vector3(0, box.size.y * 0.5, 0),
			Vector3(middle.x, box.position.y, middle.z)]:
		var s: Vector2 = _screen(p)
		for d: Vector2 in [Vector2.ZERO, Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4),
				Vector2(0, -4), Vector2(8, 8), Vector2(-8, -8), Vector2(8, -8), Vector2(-8, 8),
				Vector2(16, 0), Vector2(-16, 0), Vector2(0, 16), Vector2(0, -16)]:
			points.append(s + d)
	for site: JointSnap.End in _builder.joint_sites():
		if site.at.distance_to(want.origin) <= 120.0:
			points.append(_screen(site.at))
	# Turned as it goes first, then on a joint, a typed turn about it away;
	# the nearest of the best kind. Typed numbers take it the rest.
	var best: Dictionary = {"tried": points.size()}
	var rank: float = INF
	for p: Vector2 in points:
		await _move(p)
		if not _builder.can_place():
			continue
		var g: Transform3D = _builder.ghost_transform()
		var turned: bool = _same_turn(g.basis, want.basis)
		if not turned and not _builder.is_on_joint():
			continue
		var score: float = g.origin.distance_to(want.origin) + (0.0 if turned else 1000.0)
		if score < rank:
			rank = score
			best["at"] = p
			best["turned"] = turned
			best["joint"] = _builder.is_on_joint()
			best["far"] = g.origin.distance_to(want.origin)
	return best


## What a person types to bring the ghost to its place: the turn about its
## joint, if it is on one and turned otherwise, then each axis it is off,
## in studs, plates or LDU as it divides.
func _words_for(ghost: Transform3D, want: Transform3D) -> String:
	var words: String = ""
	var at: Transform3D = ghost
	if not _same_turn(ghost.basis, want.basis):
		var turn: Basis = want.basis.orthonormalized() * ghost.basis.orthonormalized().inverse()
		var q := Quaternion(turn)
		var angle: float = rad_to_deg(q.get_angle())
		var axis: Vector3 = q.get_axis()
		var joint: Variant = _builder.get("_joint_site")
		var about: Vector3 = (joint as JointSnap.End).axis.normalized() if joint != null \
			else Vector3.UP
		if axis.dot(about) < 0.0:
			angle = -angle
		words += "%sr" % _figure(snappedf(angle, 0.01))
		var point: Vector3 = (joint as JointSnap.End).at if joint != null else ghost.origin
		var about_t := Transform3D(Basis.IDENTITY, point) \
			* Transform3D(Basis(about, deg_to_rad(snappedf(angle, 0.01))), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -point)
		at = about_t * ghost
	var off: Vector3 = want.origin - at.origin
	for i: int in 3:
		var v: float = snappedf(off[i], 0.01)
		if absf(v) < 0.01:
			continue
		var unit: String = "l"
		var n: float = v
		if is_zero_approx(fposmod(v, 20.0)) and i != 1:
			unit = ""
			n = v / 20.0
		elif is_zero_approx(fposmod(v, 8.0)):
			unit = "p"
			n = v / 8.0
		words += "%s%s%s" % [_figure(n), unit, "xyz"[i]]
	return words


## A number as a person types it: 30, not 30.0.
static func _figure(n: float) -> String:
	return str(roundi(n)) if is_equal_approx(n, roundf(n)) else String.num(n, 2)


# -- helpers ----------------------------------------------------------------------


func _count_from() -> void:
	_acts = {"point": 0, "click": 0, "key": 0, "typed": 0, "chars": 0}


func _total() -> int:
	return int(_acts["point"]) + int(_acts["click"]) + int(_acts["key"]) + int(_acts["typed"])


func _meaning() -> String:
	var label: Label = _verbs.typed.find_child("Meaning", true, false)
	return label.text if label != null else ""


func _put(part: String, colour: int, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _newest() -> BrickWorld.Brick:
	var best: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _model():
		if best == null or brick.id > best.id:
			best = brick
	return best


func _at(origin: Vector3) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _model():
		if brick.transform.origin.distance_to(origin) < 0.01:
			return brick
	return null


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


static func _near(a: Transform3D, b: Transform3D, place: float, turn: float) -> bool:
	if a.origin.distance_to(b.origin) > place:
		return false
	for n: int in 3:
		if (a.basis[n] - b.basis[n]).length() > turn:
			return false
	return true


static func _same_turn(a: Basis, b: Basis) -> bool:
	for n: int in 3:
		if (a[n] - b[n]).length() > 0.01:
			return false
	return true


func _ldr_of(at: Transform3D) -> String:
	var numbers: PackedFloat64Array = LdrModel.from_transform(at)
	var words: PackedStringArray = []
	for n: int in numbers.size():
		words.append(String.num(numbers[n], 3 if n < 3 else 4))
	return " ".join(words)


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _act_move(at: Vector2) -> void:
	_acts["point"] = int(_acts["point"]) + 1
	await _move(at)


func _button(at: Vector2, down: bool, which: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


## A click somewhere new: one action, as the walk counts one.
func _act_click(at: Vector2) -> void:
	_acts["click"] = int(_acts["click"]) + 1
	await _click(at)


func _right_click(at: Vector2) -> void:
	await _move(at)
	_button(at, true, MOUSE_BUTTON_RIGHT)
	await _frames(2)
	_button(at, false, MOUSE_BUTTON_RIGHT)
	await _frames(4)


func _key(code: Key, command: bool = false, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


## Characters as a browser's keyboard gives them to the engine: the key's
## code and its character, nothing the desktop alone has.
func _type(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		var code: Key = {"-": KEY_MINUS, ".": KEY_PERIOD, "/": KEY_SLASH, " ": KEY_SPACE,
			"+": KEY_PLUS, "*": KEY_ASTERISK}.get(c, OS.find_keycode_from_string(c.to_upper()))
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = code
			event.physical_keycode = code
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = ProjectSettings.globalize_path("res://shots/typed/%dx%d/%s.png" % [
		size.x, size.y, name])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s" % path)
