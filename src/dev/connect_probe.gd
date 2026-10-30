## Connect (docs/APP_UX.md, B2): a point on the part, then the point it goes
## on, driven as a person drives it: keys and clicks sent as input events
## against the real scene, each action counted as the walk counts them (a
## click, a key, an aim of the pointer somewhere new, each one).
##
##   godot --path . --resolution 1400x900 --script src/dev/connect_probe.gd [-- only=SECTION,…]
##
## SECTION is column (8841-1's 1 x 16 column on its two pins: the bar, 6
## actions or fewer, and the same aim without Connect), turned (a 1 x 16 by
## its fourth hole onto a pin in a brick turned 30° and tilted 25°: any part
## at any angle, R about the joint), model (the toolbar's Connect on a part
## already down: moved by its point in one undo, and Esc puts it back), walk
## (the joint parts of the 25 of 8841-1 that docs/CADTASK.md section 9
## built, each by Connect, and that walk's actions a part with them).
## PROBE_SIZE=1280x720 runs it at the smaller window. Pictures go to
## shots/connect/WxH/.
extends SceneTree

const SETS := "res://vendor/omr/files/"
const BALANCE := "8841-1_Balance.mpd"
const EXACT_PLACE := 0.05
const EXACT_TURN := 0.002
## T and R on a joint as the build flow presses them (cad_task_flow.mjs,
## ON_JOINT_KEYS): each way on first, then each again turned.
const FLOW_KEYS := [KEY_T, KEY_T, KEY_T, KEY_T, KEY_R, KEY_R, KEY_R, KEY_R, KEY_T, KEY_T,
	KEY_T, KEY_T, KEY_R, KEY_R, KEY_T, KEY_T, KEY_T, KEY_T, KEY_R, KEY_R, KEY_R, KEY_R, KEY_T,
	KEY_T, KEY_T]
## Section 9's run of 8841-1 (bench/results/wholeset2-2026-10-18/after3/8841,
## 25 parts, 744 actions, 29.76 a part): its joint parts by their place in
## the file, each with the actions the run spent on it and, of those, what
## taking it and its colour cost (the search's click, Ctrl+A, the number
## typed, the tile's click; a swatch's click; a colour typed by name), which
## Connect does not change.
const WALK_ACTIONS := 744
const WALK_PARTS := 25
const WALK_JOINTS := {17: [16, 8], 18: [14, 8], 19: [20, 8], 20: [14, 8], 21: [258, 8],
	22: [18, 8], 23: [23, 18], 24: [4, 0], 25: [55, 7]}

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Shell
var _verbs: EditVerbs
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
	print("  window %s" % DisplayServer.window_get_size())
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
	for section: String in ["column", "turned", "model", "walk"]:
		if only.is_empty() or section in only.split(","):
			print("  -- %s" % section)
			await _rest()
			await call("_" + section)
	await _rest()
	print("")
	print("connect: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## Nothing in hand, nothing selected, the Select tool, and the model empty.
func _rest() -> void:
	if _verbs.mode == "connect":
		await _key(KEY_ESCAPE)
	_verbs.set_mode("select")
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(6)


# -- the column: 8841-1's 1 x 16 on its two pins ----------------------------------


func _column() -> void:
	var truth: Array = await _truth_of(BALANCE)
	var index: int = 21
	_check("8841-1's part 21 is the 1 x 16 column (%s)" % truth[index - 1][0],
		str(truth[index - 1][0]) == "3703")
	var want: Transform3D = truth[index - 1][2]
	await _lay(truth, index)
	var pair: Array = _goes_on(truth[index - 1][0], want)
	if pair.is_empty():
		_check("the column has a hole on a pin where the file has it", false)
		return
	var end_index: int = pair[0]
	var site: JointSnap.End = pair[1]
	await _look_at_joint(site, want, truth[index - 1][0])

	# Without Connect, as the build flow aims it: at the pin, then T and R.
	_count_from()
	await _hold(truth[index - 1][0], int(truth[index - 1][1]))
	var at: Vector2 = _screen(_end_at(truth[index - 1][0], end_index, want).at)
	await _act_move(at)
	var presses: int = -1
	for n: int in FLOW_KEYS.size() + 1:
		if _exact_ghost(want):
			presses = n
			break
		if n < FLOW_KEYS.size():
			await _act_key(FLOW_KEYS[n])
			await _move(at + Vector2(0, 1))
			await _move(at)
	print("    without Connect: %s" % ("on its place after %d presses of T and R" % presses
		if presses >= 0 else "not on its place after the build flow's %d presses of T and R"
		% FLOW_KEYS.size()))
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _shot("column_before")

	# With Connect: taken, aimed, N, its end hole, the pin.
	_count_from()
	var depth: int = _builder.history_depth()
	var count: int = _count()
	await _hold(truth[index - 1][0], int(truth[index - 1][1]))
	await _act_move(at)
	await _act_key(KEY_N)
	_check("N offers the column's points (%s, %d of them)" % [_verbs.connect_tool.stage,
		_verbs.connect_tool.points.size()], _verbs.connect_tool.stage == "point"
		and _verbs.connect_tool.points.size() >= 15)
	var marks: Node = _builder.find_child("ConnectPoints", false, false)
	_check("each point is drawn (%d)" % (marks.get_child_count() if marks != null else 0),
		marks != null and marks.get_child_count() == _verbs.connect_tool.points.size())
	await _shot("column_points")
	var on: Vector2 = _point_on_screen(end_index)
	await _move(on)
	_check("the end hole lights under the pointer (%d)" % _verbs.connect_tool.lit,
		_verbs.connect_tool.lit == end_index)
	await _act_click(on)
	_check("a click picks it: aiming by that hole alone (%s)" % _verbs.connect_tool.stage,
		_verbs.connect_tool.stage == "aim" and _builder.connect_end
		== _verbs.connect_tool.points[end_index])
	_check("the click on a point put nothing down (%d parts)" % _count(), _count() == count)
	await _act_move(at)
	var turns: int = await _turn_onto(want, at)
	_check("the ghost stands where the file has the column, %d presses of T and R (%s)"
		% [turns, _ldr_of(_builder.ghost_transform())], _exact_ghost(want))
	_check("the hole picked is on the pin: %.3f LDU off its line" % _off_line(
		_end_at(truth[index - 1][0], end_index, _builder.ghost_transform()).at, site),
		_off_line(_end_at(truth[index - 1][0], end_index, _builder.ghost_transform()).at,
		site) < 0.05)
	await _shot("column_aimed")
	await _act_click(at)
	var put: BrickWorld.Brick = _newest()
	_check("a click puts it down where the file has it (%s)" % (_ldr_of(put.transform)
		if put != null else "nothing"), put != null and _near(put.transform, want))
	_check("the column on in %d actions from the bin (bar: 6) — %s" % [_total(), _acts],
		_total() <= 6)
	_check("one Connect is one step to undo (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() - depth == 1)
	await _shot("column_after")
	await _key(KEY_Z, true)
	_check("one undo takes it off (%d parts)" % _count(), _count() == count)
	await _key(KEY_Z, true, true)
	_check("and redo puts it back (%d parts)" % _count(), _count() == count + 1)

	# Another hole picked puts it on the pin by that one: the point says where.
	await _move(at)
	await _key(KEY_N)
	var other: int = _other_hole(truth[index - 1][0], end_index)
	await _click(_point_on_screen(other))
	await _move(at + Vector2(0, 1))
	await _move(at)
	var by_other: Transform3D = _builder.ghost_transform()
	_check("by another hole (%d) the ghost is on the pin by that one: %.3f LDU off, %.0f LDU from the first's place"
		% [other, _off_line(_end_at(truth[index - 1][0], other, by_other).at, site),
		by_other.origin.distance_to(want.origin)],
		_off_line(_end_at(truth[index - 1][0], other, by_other).at, site) < 0.05
		and by_other.origin.distance_to(want.origin) > 19.0)
	await _key(KEY_ESCAPE)
	_check("Esc leaves Connect with the column still in hand (%s)" % _verbs.mode,
		_verbs.mode == "place" and _builder.connect_end == null)


# -- any part at any angle ---------------------------------------------------------


func _turned() -> void:
	_main.call("clear_model")
	await _frames(4)
	var turn := Basis(Vector3.UP, deg_to_rad(30.0)) * Basis(Vector3.RIGHT, deg_to_rad(25.0))
	var brick_at := Transform3D(turn, Vector3(0, 60, 0))
	var brick: int = _world.add_brick("3701", 4, brick_at)
	_builder.register(brick, "3701", brick_at)
	# A pin in its middle hole, as JointSnap seats one.
	var holes: Array = JointSnap.ends_of(_library.mesh_for("3701")).filter(
		func(end: JointSnap.End) -> bool: return end.kind == "pin_hole")
	holes.sort_custom(func(a: JointSnap.End, b: JointSnap.End) -> bool: return a.at.x < b.at.x)
	var hole: JointSnap.End = (holes[holes.size() / 2] as JointSnap.End).placed(brick_at, brick)
	var pin_end: JointSnap.End = null
	for end: JointSnap.End in JointSnap.ends_of(_library.mesh_for("4459")):
		if end.is_male():
			pin_end = end
			break
	var pin_at: Transform3D = JointSnap.pose(pin_end, hole, 1, 0.0, 0.0, Basis.IDENTITY)
	var pin: int = _world.add_brick("4459", 0, pin_at)
	_builder.register(pin, "4459", pin_at)
	var site: JointSnap.End = null
	for end: JointSnap.End in JointSnap.ends_of(_library.mesh_for("4459")):
		var placed: JointSnap.End = end.placed(pin_at, pin)
		if site == null or placed.at.distance_to(hole.at) > site.at.distance_to(hole.at):
			site = placed
	_camera.frame(AABB(brick_at.origin - Vector3(80, 80, 80), Vector3(160, 160, 160)), 1.4)
	_camera.look_from((site.axis + Vector3(0.3, 0.5, 0.2)).normalized())
	await _frames(40)

	_count_from()
	await _hold("3703", 1)
	var aim: Vector2 = _screen(site.aimed(_camera.global_position,
		(site.at - _camera.global_position).normalized()))
	await _act_move(aim)
	await _act_key(KEY_N)
	var fourth: int = _nth_hole("3703", 3)
	await _act_click(_point_on_screen(fourth))
	await _act_move(aim)
	var ghost: Transform3D = _builder.ghost_transform()
	var mine: JointSnap.End = _end_at("3703", fourth, ghost)
	_check("by its fourth hole on a pin in a brick turned 30° and tilted 25°: %.3f LDU off the pin's line, square to it by %.4f"
		% [_off_line(mine.at, site), absf(mine.axis.dot(site.axis))],
		_builder.is_on_joint() and _off_line(mine.at, site) < 0.05
		and absf(mine.axis.dot(site.axis)) > 0.999)
	_check("and it has room there", _builder.can_place())
	await _shot("turned_aimed")
	await _act_key(KEY_R)
	await _move(aim + Vector2(0, 1))
	await _move(aim)
	var swung: Transform3D = _builder.ghost_transform()
	var after_r: JointSnap.End = _end_at("3703", fourth, swung)
	var degrees: float = rad_to_deg(Quaternion(ghost.basis.orthonormalized()).angle_to(
		Quaternion(swung.basis.orthonormalized())))
	_check("R turns it %.1f° about the joint, the hole still on the pin (%.3f off)"
		% [degrees, _off_line(after_r.at, site)], degrees > 1.0 and _off_line(after_r.at, site) < 0.05)
	var depth: int = _builder.history_depth()
	await _act_click(aim)
	var put: BrickWorld.Brick = _newest()
	_check("a click puts it down as the ghost stood (%s)" % (_ldr_of(put.transform)
		if put != null else "nothing"), put != null and put.part_id == "3703"
		and _near(put.transform, swung))
	_check("in %d actions from the bin — %s; one step to undo (%d)" % [_total(), _acts,
		_builder.history_depth() - depth], _builder.history_depth() - depth == 1)
	await _shot("turned_after")


# -- the toolbar's Connect on a part already down ------------------------------


func _model() -> void:
	var truth: Array = await _truth_of(BALANCE)
	var index: int = 21
	var want: Transform3D = truth[index - 1][2]
	await _lay(truth, index)
	var pair: Array = _goes_on("3703", want)
	var end_index: int = pair[0]
	var site: JointSnap.End = pair[1]
	# The column lying on the floor in front of the balance, as a person
	# puts one down to pick it up again.
	var lying := Transform3D(Basis.IDENTITY, Vector3(want.origin.x - 10, 24, want.origin.z + 120))
	lying.origin = BrickLattice.to_ldu(BrickLattice.to_cell(lying.origin))
	var column: int = _world.add_brick("3703", 1, lying)
	_builder.register(column, "3703", lying)
	await _look_at_joint(site, want, "3703")
	_camera.frame((AABB(want.origin, Vector3.ZERO).expand(lying.origin)).grow(120.0), 1.3)
	_camera.look_from(Vector3(0.45, 0.6, 0.66).normalized())
	await _frames(40)
	var count: int = _count()
	var depth: int = _builder.history_depth()
	var held: String = _builder.held_part

	# Esc first: taken off and put back where it was.
	var button: Button = (_shell.toolbar._buttons as Dictionary).get("mode_connect")
	_check("the toolbar has Connect", button != null)
	if button == null:
		return
	await _click(button.get_global_rect().get_center())
	_check("the tool is on, waiting for a part (%s, %s)" % [_verbs.mode,
		_verbs.connect_tool.stage], _verbs.mode == "connect" and _verbs.connect_tool.stage == "part")
	var on_column: Vector2 = _screen((lying * _library.mesh_for("3703").bounds).get_center()
		+ Vector3(0, 12, 0))
	await _click(on_column)
	_check("a click on the column takes it into hand where it stands, its points offered (%s)"
		% _verbs.connect_tool.stage, _verbs.connect_tool.stage == "point"
		and _world.get_brick(column) == null
		and _near(_builder.ghost_transform(), lying))
	await _shot("model_points")
	await _key(KEY_ESCAPE)
	var back: BrickWorld.Brick = _newest()
	_check("Esc puts it back where it was (%s), the history as it was (%d)" % [
		_ldr_of(back.transform) if back != null else "nothing",
		_builder.history_depth() - depth], _count() == count and back != null
		and _near(back.transform, lying) and _builder.history_depth() == depth)

	# Then moved by its end hole onto the pin.
	_count_from()
	await _act_click(button.get_global_rect().get_center())
	await _act_click(on_column)
	await _act_click(_point_on_screen(end_index))
	var at: Vector2 = _screen(_end_at("3703", end_index, want).at)
	await _act_move(at)
	var turns: int = await _turn_onto(want, at)
	await _act_click(at)
	var moved: BrickWorld.Brick = _newest()
	_check("moved onto its pins by its end hole (%s), %d presses" % [_ldr_of(moved.transform)
		if moved != null else "nothing", turns], moved != null and _near(moved.transform, want)
		and _count() == count)
	_check("in %d actions — %s; one step to undo (%d)" % [_total(), _acts,
		_builder.history_depth() - depth], _builder.history_depth() - depth == 1)
	_check("the tool waits for the next part, nothing in hand (%s)"
		% _verbs.connect_tool.stage, _verbs.connect_tool.stage == "part"
		and not _builder.has_preview())
	await _shot("model_after")
	await _key(KEY_Z, true)
	var undone: BrickWorld.Brick = _newest()
	_check("one undo puts it back on the floor (%s)" % (_ldr_of(undone.transform)
		if undone != null else "nothing"), undone != null and _near(undone.transform, lying)
		and _count() == count and _builder.history_depth() == depth)
	await _key(KEY_ESCAPE)
	_check("Esc leaves the tool for Select (%s)" % _verbs.mode, _verbs.mode == "select")
	if held != "3703":
		print("    in hand after: %s (was %s)" % [_builder.held_part, held])


# -- the walk: 8841-1's joint parts of section 9's 25, each by Connect -------------


func _walk() -> void:
	var truth: Array = await _truth_of(BALANCE)
	var rows: Array = []
	var spent: int = 0
	var modelled: int = WALK_ACTIONS
	for index: int in WALK_JOINTS:
		var part: String = truth[index - 1][0]
		var want: Transform3D = truth[index - 1][2]
		await _lay(truth, index)
		var pair: Array = _goes_on(part, want)
		if pair.is_empty():
			_check("8841-1 #%d %s goes on a joint where the file has it" % [index, part], false)
			continue
		var end_index: int = pair[0]
		var site: JointSnap.End = pair[1]
		await _look_at_joint(site, want, part)
		_count_from()
		await _hold(part, int(truth[index - 1][1]))
		var at: Vector2 = _screen(_end_at(part, end_index, want).at)
		await _act_move(at)
		await _act_key(KEY_N)
		var on: Vector2 = _point_on_screen(end_index)
		await _move(on)
		var picked: bool = _verbs.connect_tool.lit == end_index
		await _act_click(on)
		await _act_move(at)
		var turns: int = await _turn_onto(want, at)
		var exact: bool = _exact_ghost(want)
		if exact:
			await _act_click(at)
		var put: BrickWorld.Brick = _newest() if exact else null
		exact = put != null and put.part_id == part and _near(put.transform, want)
		await _key(KEY_ESCAPE)
		await _key(KEY_ESCAPE)
		var flow: Array = WALK_JOINTS[index]
		var with_connect: int = int(flow[1]) + _total()
		# A person reaches for Connect where it saves something: a pin goes
		# in either end alike.
		var used: int = mini(int(flow[0]), with_connect)
		modelled += used - int(flow[0])
		spent += _total()
		rows.append({"index": index, "part": part, "acts": _total(), "turns": turns,
			"lit": picked, "exact": exact, "flow": flow[0], "walk": used})
		_check("8841-1 #%d %s by its %s on the %s of %s: %s in %d actions (%d of them T and R); the run took %d, with Connect %d"
			% [index, part, (_verbs.connect_tool.points[end_index] as JointSnap.End).kind
			if end_index < _verbs.connect_tool.points.size() else "?", site.kind,
			_world.get_brick(site.brick).part_id if _world.get_brick(site.brick) != null else "?",
			"exact" if exact else "NOT exact", _total(), turns, int(flow[0]), with_connect],
			exact and picked)
	var path: String = ProjectSettings.globalize_path("res://shots/connect/walk.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, " "))
	file.close()
	var per_part: float = float(modelled) / WALK_PARTS
	_check("the walk's 25 parts with these by Connect: %d actions, %.2f a part (bar: 18; the run %.2f)"
		% [modelled, per_part, float(WALK_ACTIONS) / WALK_PARTS], per_part <= 18.0)
	print("    (the run's own count for its other parts, these %d by Connect as measured here, %d actions in all from the bin)"
		% [rows.size(), spent])


# -- what a person aims at -------------------------------------------------------


## Parts 1 to [param index] - 1 down as the file has them, nothing selected.
func _lay(truth: Array, index: int) -> void:
	await _rest()
	for n: int in index - 1:
		var id: int = _world.add_brick(truth[n][0], truth[n][1], truth[n][2])
		_builder.register(id, truth[n][0], truth[n][2])
	_builder.clear_selection()
	await _frames(6)


## The point of [param part] that, where the file has it at [param want], is on
## a joint of a part down, and that joint: [index in its points, site], the
## nearest the joint's line first and then the nearest its middle. [] for none.
func _goes_on(part: String, want: Transform3D) -> Array:
	var best: Array = []
	var best_off: float = INF
	var ends: Array = JointSnap.ends_for(_library, part)
	for n: int in ends.size():
		var mine: JointSnap.End = (ends[n] as JointSnap.End).placed(want, 0)
		for site: JointSnap.End in JointSnap.sites_in(_world, _library):
			if not JointSnap.mates(ends[n], site) or absf(mine.axis.dot(site.axis)) < 0.999:
				continue
			var off: float = _off_line(mine.at, site)
			if off > 2.0:
				continue
			off += mine.at.distance_to(site.at) * 0.01
			if off < best_off:
				best_off = off
				best = [n, site]
	return best


## The view turned to the side a joint opens to, the part's place framed, as
## a person turns to see the pin a part goes on.
func _look_at_joint(site: JointSnap.End, want: Transform3D, part: String) -> void:
	var box: AABB = (want * _library.mesh_for(part).bounds).abs()
	_camera.frame(box.merge(AABB(site.at, Vector3.ZERO)).grow(30.0), 1.3)
	var holder: BrickWorld.Brick = _world.get_brick(site.brick)
	var middle: Vector3 = (holder.transform * _library.mesh_for(holder.part_id).bounds).abs() \
		.get_center()
	var outward: Vector3 = site.axis if (site.middle() - middle).dot(site.axis) >= 0.0 \
		else -site.axis
	_camera.look_from((outward + Vector3(0.25, 0.7, 0.35)).normalized())
	await _frames(40)


## T and R, the fewest found, until the ghost stands at [param want]: how many
## were pressed, each counted; -1 when none of eight of each brings it there.
func _turn_onto(want: Transform3D, at: Vector2) -> int:
	if _exact_ghost(want):
		return 0
	var pressed: int = 0
	for _t: int in 4:
		for _r: int in 8:
			if _exact_ghost(want):
				return pressed
			await _act_key(KEY_R)
			pressed += 1
			await _move(at + Vector2(0, 1))
			await _move(at)
		if _exact_ghost(want):
			return pressed
		await _act_key(KEY_T)
		pressed += 1
		await _move(at + Vector2(0, 1))
		await _move(at)
	return pressed if _exact_ghost(want) else -1


## Where Connect draws point [param n] on the screen while it offers them.
func _point_on_screen(n: int) -> Vector2:
	for point: Dictionary in _verbs.connect_tool.screen_points():
		if int(point["index"]) == n:
			return Vector2(point["x"], point["y"]) * (root.get_visible_rect().size
				/ Vector2(DisplayServer.window_get_size()))
	return Vector2(-100, -100)


func _end_at(part: String, n: int, at: Transform3D) -> JointSnap.End:
	return (JointSnap.ends_for(_library, part)[n] as JointSnap.End).placed(at, 0)


## Of [param part]'s holes, along its length, the [param nth] from its first.
func _nth_hole(part: String, nth: int) -> int:
	var ends: Array = JointSnap.ends_for(_library, part)
	var holes: Array = []
	for n: int in ends.size():
		if (ends[n] as JointSnap.End).kind == "pin_hole":
			holes.append(n)
	holes.sort_custom(func(a: int, b: int) -> bool:
		return (ends[a] as JointSnap.End).at.x < (ends[b] as JointSnap.End).at.x)
	return holes[clampi(nth, 0, holes.size() - 1)]


## A hole of [param part] seven along from [param n].
func _other_hole(part: String, n: int) -> int:
	var ends: Array = JointSnap.ends_for(_library, part)
	var mine: Vector3 = (ends[n] as JointSnap.End).at
	var best: int = n
	for m: int in ends.size():
		var end: JointSnap.End = ends[m]
		if end.kind == "pin_hole" and absf(absf(end.at.x - mine.x) - 140.0) < 1.0:
			best = m
	return best


func _exact_ghost(want: Transform3D) -> bool:
	return _builder.has_preview() and _builder.can_place() \
		and _near(_builder.ghost_transform(), want)


static func _off_line(point: Vector3, site: JointSnap.End) -> float:
	var v: Vector3 = point - site.at
	return (v - site.axis * v.dot(site.axis)).length()


# -- helpers ----------------------------------------------------------------------


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


## Taken into hand as from a tile of the bin, in its colour: one click.
func _hold(part: String, colour: int) -> void:
	_main.call("_on_part_chosen", part)
	for _n: int in 600:
		if _library.mesh_for(part) != null:
			break
		await process_frame
	_builder.held_color = colour
	_acts["click"] = int(_acts["click"]) + 1
	await _frames(3)


## The part put down last: the newest id.
func _newest() -> BrickWorld.Brick:
	var best: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if best == null or brick.id > best.id:
			best = brick
	return best


static func _near(a: Transform3D, b: Transform3D) -> bool:
	if a.origin.distance_to(b.origin) > EXACT_PLACE:
		return false
	for n: int in 3:
		if (a.basis[n] - b.basis[n]).length() > EXACT_TURN:
			return false
	return true


func _ldr_of(at: Transform3D) -> String:
	var numbers: PackedFloat64Array = LdrModel.from_transform(at)
	var words: PackedStringArray = []
	for n: int in numbers.size():
		words.append(String.num(numbers[n], 3 if n < 3 else 4))
	return " ".join(words)


func _count_from() -> void:
	_acts = {"point": 0, "click": 0, "key": 0}


func _total() -> int:
	return int(_acts["point"]) + int(_acts["click"]) + int(_acts["key"])


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


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


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
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


func _act_key(code: Key) -> void:
	_acts["key"] = int(_acts["key"]) + 1
	await _key(code)


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = ProjectSettings.globalize_path("res://shots/connect/%dx%d/%s.png" % [
		size.x, size.y, name])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s" % path)
