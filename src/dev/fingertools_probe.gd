## Measure and the move handles by finger, on a phone (docs/APP_UX8.md, unit
## fingertools).
##
##   godot --path . --resolution 390x844 --script src/dev/fingertools_probe.gd [-- --shots=DIR]
##
## Through the way in first, as a person comes: the sign-in screen up over
## the app (gate_for_probe), a throwaway account signed in with a password
## grant (as binrow_probe), the screen gone; the account deleted at the end.
## Needs .env (SUPABASE_URL, SUPABASE_SECRET_KEY). Then, laid out for a phone
## at a browser's scale (as twist_probe holds it), by fingers as the window
## hands them over (InputEventScreenTouch and ScreenDrag; the engine raises
## its own click from them, as it does in a phone's browser):
## 1. measure: two studs of the car, the view pinched in on them, measured by
##    the mouse at each stud's middle, then by two taps landing 8 points off
##    in each of eight ways and on the middle: every reading within 0.1 LDU of
##    the mouse's. Then two slow taps, each finger held 0.65 s: the ruler
##    still out, nothing selected, no part's actions, the same reading.
## 2. drag: a 2 x 4 brick tapped with the Move tool, its x arrow dragged
##    3 studs by the mouse, undone, then by a finger rested on it 0.65 s
##    first: the part 3 studs along its x as by the mouse, the view as it
##    was, the Move tool and the selection kept, no part's actions, one step
##    to undo. A second finger coming down mid-drag puts it back.
## 3. targets: every handle's target, where a finger's press takes it, at
##    least 44 points across (the widest circle inside it), for the Move
##    tool's arrows, panes and tag and the Rotate tool's rings, outer ring,
##    trackball and tag; a tap on the tag goes to the model's axes.
## 4. dialogs: 20 and more opened and closed, 17 of the app's from their
##    commands and 6 made here (freed while open, at once and at the frame's end; a list
##    filled afresh twice in a frame, its first rows freed at once; popped
##    and freed the same frame; one closed by OK): 0 errors that name
##    touch_sizing. pre261 put a row freed before its sizing's call in a
##    Control, an error for each.
## Pictures in --shots=DIR (else user://fingertools). Exits non-zero when a
## check fails.
extends SceneTree

## How far off a stud's middle each test tap lands, points.
const OFF := 8.0
## The most a finger's reading may differ from the mouse's, LDU.
const SAME_LDU := 0.1
## A slow tap, and a finger rested before it drags, seconds: past the
## phone's hold (Main.HOLD_MS, 480 ms).
const RESTED := 0.65
## Up in the air, clear of the floor and whatever stands on it.
const AIR := Vector3(0, 400, 0)
## How finely the targets are sampled, points.
const CELL := 2.0
## The app's dialogs opened from their commands, as More's rows run them;
## none of them the platform's own file dialog.
const DIALOGS: Array[String] = ["versions", "settings", "parts_list", "collection",
	"part_maker", "hidden_colours", "keys", "about", "clear", "floor_custom", "select_find",
	"compare_sets", "pattern", "step_to", "save_view", "palette", "account"]

var _failures: int = 0
var _main: Node
var _camera: CadCamera
var _world: BrickWorld
var _builder: Builder
var _verbs: EditVerbs
var _library: PartLibrary
var _shell: Shell
var _phone: Node
var _out: String = "user://fingertools"
var _email: String = ""
var _password: String = ""
var _errors := _Errors.new()
var _table: Array[String] = []


## What the engine says as an error, kept to be read.
class _Errors extends Logger:
	var lines: PackedStringArray = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, _error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		lines.append("%s %s (%s:%d, %s)" % [code, rationale, file, line, function])
		_lock.unlock()

	func since(from: int) -> PackedStringArray:
		_lock.lock()
		var said: PackedStringArray = lines.slice(from)
		_lock.unlock()
		return said

	func count() -> int:
		_lock.lock()
		var n: int = lines.size()
		_lock.unlock()
		return n


func _initialize() -> void:
	OS.add_logger(_errors)
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("fingertools_probe: needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	ShellPrefs.kept_by_a_check = _own_data_folder()
	Phone._on = 1
	Phone._wide = false
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	# The sign-in screen over the app, as a person opening it meets it.
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	# A phone draws at a browser's scale, as twist_probe holds it.
	_phone = _main.get("_phone")
	if _phone != null:
		_phone.set_process(false)
	for link: Dictionary in root.size_changed.get_connections():
		var call: Callable = link["callable"]
		if call.get_method() == &"_match_screen_density":
			root.size_changed.disconnect(call)
	var main_script: GDScript = _main.get_script()
	root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
		ShellPrefs.interface_size(), true)
	await _frames(20)
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	var size: Vector2i = DisplayServer.window_get_size()
	print("fingertools_probe: a %d x %d window laid out for a phone, %.3f units to the point"
		% [size.x, size.y, Phone.per_point(root)])
	_check("the phone's layout is made, and the camera takes fingers as a phone's",
		_phone != null and _camera.phone)
	if not await _way_in():
		await _finish()
		return
	(_main.get("_store") as ModelStore).keeps = false
	await _frames(30)

	print("\n1. measure: two studs of the car, by two taps")
	await _measure()
	print("\n2. drag: a part moved 3 studs by its x arrow")
	await _drag()
	print("\n3. targets: every handle a fingertip's or more")
	await _targets()
	print("\n4. dialogs: 20 opened and closed")
	await _dialogs()
	print("")
	print("  handle            target (points across)")
	for line: String in _table:
		print("  " + line)
	await _finish()


## The sign-in screen up, a throwaway account signed in, the screen gone.
func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("fingertools")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


## Signed in with a password grant on an account the admin key made: the
## token bucket, not a code's verify (binrow_probe).
func _sign_in(account: Account, email: String) -> String:
	_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


# -- 1. measure ---------------------------------------------------------------


func _measure() -> void:
	var car: int = _world._bricks.size()
	_check("the car is on the baseplate (%d parts)" % car, car > 20)
	var pair: Array = _two_studs()
	if pair.is_empty():
		_check("two studs of the car in sight to measure between", false)
		return
	# Pinched in on the two, as a person does to tap one.
	var box := AABB(pair[0], Vector3.ZERO).expand(pair[1]).grow(30.0)
	_camera.frame(box, 1.3)
	await _settle()
	var a: Vector2 = _camera.screen_of(pair[0])
	var b: Vector2 = _camera.screen_of(pair[1])
	var pitch: float = _pitch_at(pair[0])
	print("  the studs at %s and %s, %.1f and %.1f points from any other stud or connector; a stud %.1f points across"
		% [pair[0], pair[1], _isolation(a) / _pt(), _isolation(b) / _pt(), pitch / _pt()])
	_shell.run("measure")
	await _frames(6)
	var measure: Measure = _main.get("_measure")
	if not _check("More's Measure takes the ruler out", measure != null and measure.active):
		return
	_check("its words are for a finger: \"%s\"" % measure.words(),
		measure.words() == "Measuring: tap a point, then another")
	await _click(a)
	await _click(b)
	var mouse: Dictionary = measure.ends()
	var said: String = measure.label.text
	var span: Variant = _span(mouse)
	print("  the mouse's reading: %s (%s)" % [span, said])
	_check("the mouse measures between the two studs: \"%s\"" % said, span != null)
	if span == null:
		return
	var worst: float = 0.0
	var wrong: Array[String] = []
	var ways: Array[Vector2] = [Vector2.ZERO]
	for n: int in 8:
		ways.append(Vector2.from_angle(TAU * n / 8.0) * OFF * _pt())
	for way: Vector2 in ways:
		await _tap(a + way)
		await _tap(b + way)
		var by_finger: Variant = _span(measure.ends())
		var off: float = INF if by_finger == null else (by_finger as Vector3).distance_to(span)
		worst = maxf(worst, off)
		if off > SAME_LDU:
			wrong.append("%s pt: %s" % [_round(way / _pt()), by_finger])
	print("  measure finger_worst_ldu %.3f" % worst)
	_check("two taps 8 points off each stud's middle in each of 8 ways, and on it: each reading within %.1f LDU of the mouse's (worst %.2f LDU%s)"
		% [SAME_LDU, worst, "" if wrong.is_empty() else "; " + ", ".join(wrong)], wrong.is_empty())
	await _shot("1_measured_by_taps")
	# Slow taps: a finger held down past the phone's hold, then lifted.
	_builder.clear_selection()
	await _tap(a + ways[3], RESTED)
	await _tap(b + ways[3], RESTED)
	var slow: Variant = _span(measure.ends())
	var sheet: String = _sheet()
	_check("two slow taps (%.2f s each): the ruler still out (%s), the reading the mouse's (%s), nothing selected (%d), no part's actions (%s)"
		% [RESTED, measure.active, slow, _builder.selection.size(), sheet if sheet != "" else "none"],
		measure.active and slow != null and (slow as Vector3).distance_to(span) <= SAME_LDU
		and _builder.selection.is_empty() and sheet == "")
	_shell.run("measure")
	await _frames(4)
	_check("More's Measure again puts the ruler away", not measure.active)


## Two top studs of the car in sight, 2 to 5 studs apart, near the middle of
## the view: their tops, in the model.
func _two_studs() -> Array:
	var room: Rect2 = _view().grow(-40.0 * _pt())
	var tops: Array = []
	for id: int in _world._bricks:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind != "stud" or connector.gender != "male":
				continue
			var up: Vector3 = (brick.transform.basis * connector.axis).normalized()
			if up.y < 0.95:
				continue
			var top: Vector3 = brick.transform * (connector.position + connector.axis.normalized() * 4.0)
			var at: Vector2 = _camera.screen_of(top)
			if _camera.behind(top) or not room.has_point(at) or not _sees(at, id):
				continue
			tops.append([top, at, id])
	var middle: Vector2 = room.get_center()
	tops.sort_custom(func(x: Array, y: Array) -> bool:
		return (x[1] as Vector2).distance_to(middle) < (y[1] as Vector2).distance_to(middle))
	for first: Array in tops:
		for second: Array in tops:
			var apart: float = (first[0] as Vector3).distance_to(second[0])
			if second[2] != first[2] and absf((first[0] as Vector3).y - (second[0] as Vector3).y) < 0.1 \
					and apart >= 40.0 and apart <= 100.0:
				return [first[0], second[0]]
	return []


## Whether a click at [param at] meets part [param id].
func _sees(at: Vector2, id: int) -> bool:
	var lattice: BrickLattice = _builder.lattice
	return lattice.raycast(_camera.ray_origin(at), _camera.ray_normal(at)).brick_id == id


## How far [param at] is from the nearest other stud top or connector middle
## on the screen, units.
func _isolation(at: Vector2) -> float:
	var nearest: float = INF
	for id: int in _world._bricks:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		var points: Array[Vector3] = []
		if mesh != null:
			for connector: Lbm.Connector in mesh.connectors:
				if connector.kind == "stud" and connector.gender == "male":
					points.append(brick.transform * (connector.position
						+ connector.axis.normalized() * 4.0))
		for end: JointSnap.End in JointSnap.ends_for(_library, brick.part_id):
			points.append(end.placed(brick.transform, id).middle())
		for point: Vector3 in points:
			if _camera.behind(point):
				continue
			var off: float = _camera.screen_of(point).distance_to(at)
			if off > 0.5:
				nearest = minf(nearest, off)
	return nearest


## How many units a stud is across on the screen at [param at].
func _pitch_at(at: Vector3) -> float:
	return _camera.screen_of(at).distance_to(_camera.screen_of(at + Vector3(20, 0, 0)))


## The span the ruler measures, or null before its two points.
static func _span(ends: Dictionary) -> Variant:
	if ends.get("from") == null or ends.get("to") == null:
		return null
	return (ends["to"] as Vector3) - (ends["from"] as Vector3)


# -- 2. a part moved by its x arrow, by mouse and by finger ----------------------


func _drag() -> void:
	_main.call("clear_model")
	await _frames(4)
	var start := Transform3D(Basis.IDENTITY, AIR)
	var brick: int = _world.add_brick("3001", 4, start)
	_builder.register(brick, "3001", start)
	_builder.clear_selection()
	_camera.frame(AABB(AIR - Vector3(90, 90, 90), Vector3(180, 180, 180)), 1.2)
	_camera.look_from(Vector3(0.55, 0.5, 0.67).normalized())
	await _settle()
	_shell.run("mode_move")
	await _frames(4)
	await _tap(_spot_on(brick))
	_check("a tap with the Move tool puts its arrows on it (%d selected, %d handles)"
		% [_builder.selection.size(), _drawn()], _builder.selection.has(brick) and _drawn() == 3)
	if not _builder.selection.has(brick):
		_builder.select_brick(brick, false)
		await _frames(4)
	var handles: Handles = _verbs.handles
	var arrow: Dictionary = _arrow(0)
	if not _check("its x arrow is on the screen", not arrow.is_empty()):
		return
	await _shot("2_arrows_by_finger")
	var path: Array = _three_studs(arrow)
	var depth: int = _builder.history_depth()
	# By the mouse.
	await _mouse_drag(path)
	var by_mouse: Vector3 = _world.get_brick(_only_brick()).transform.origin - start.origin
	_check("the mouse drags its x arrow 3 studs: moved %s" % by_mouse,
		by_mouse.is_equal_approx(Vector3(60, 0, 0)) and _builder.history_depth() == depth + 1)
	_shell.run("undo")
	await _frames(6)
	brick = _only_brick()
	_check("...undone, back where it was",
		_world.get_brick(brick).transform.origin.is_equal_approx(start.origin))
	if not _builder.selection.has(brick):
		_builder.select_brick(brick, false)
		await _frames(4)
	# By a finger, rested on the arrow first as a hand is.
	var aim: Dictionary = _camera.aim()
	depth = _builder.history_depth()
	await _finger_drag(path, RESTED)
	brick = _only_brick()
	var by_finger: Vector3 = _world.get_brick(brick).transform.origin - start.origin
	var turned: String = _aim_moved(aim)
	var sheet: String = _sheet()
	print("  measure finger_moved %s mouse_moved %s" % [by_finger, by_mouse])
	_check("a finger rested %.2f s on its x arrow, then dragged: moved %s, as by the mouse (%s)"
		% [RESTED, by_finger, by_mouse], by_finger.is_equal_approx(by_mouse))
	_check("...the view as it was (%s)" % (turned if turned != "" else "unturned, unslid"),
		turned == "")
	_check("...the Move tool (%s), the part still selected (%d), no part's actions (%s), one step to undo (%d)"
		% [_verbs.mode, _builder.selection.size(), sheet if sheet != "" else "none",
			_builder.history_depth() - depth], _verbs.mode == "move" and _builder.selection.has(brick)
		and sheet == "" and _builder.history_depth() == depth + 1)
	await _shot("2_moved_by_finger")
	_shell.run("undo")
	await _frames(6)
	brick = _only_brick()
	if not _builder.selection.has(brick):
		_builder.select_brick(brick, false)
		await _frames(4)
	# A second finger down mid-drag: the gesture is the view's.
	var was: Vector3 = _world.get_brick(brick).transform.origin
	depth = _builder.history_depth()
	arrow = _arrow(0)
	path = _three_studs(arrow)
	var from: Vector2 = path[0]
	_touch(0, from, true)
	await _frames(3)
	for k: int in range(1, 7):
		_drag_to(0, from.lerp(path[1], k / 12.0), (path[1] - from) / 12.0)
		await _frames(2)
	var dragging: bool = handles.is_dragging()
	var second: Vector2 = from + Vector2(0, 160) * _pt()
	_touch(1, second, true)
	await _frames(3)
	for k: int in range(1, 6):
		_drag_to(1, second + Vector2(0, 8 * k) * _pt(), Vector2(0, 8) * _pt())
		_drag_to(0, from.lerp(path[1], 0.5) + Vector2(0, -8 * k) * _pt(), Vector2(0, -8) * _pt())
		await _frames(2)
	_touch(1, second + Vector2(0, 40) * _pt(), false)
	_touch(0, from.lerp(path[1], 0.5) + Vector2(0, -40) * _pt(), false)
	await _settle()
	brick = _only_brick()
	_check("a second finger down mid-drag (dragging: %s) puts it back as it was (%s), nothing to undo (%d)"
		% [dragging, _world.get_brick(brick).transform.origin, _builder.history_depth() - depth],
		dragging and _world.get_brick(brick).transform.origin.is_equal_approx(was)
		and _builder.history_depth() == depth and not handles.is_dragging())


## The one part there is now.
func _only_brick() -> int:
	return int(_world._bricks.keys()[0]) if not _world._bricks.is_empty() else 0


## Where to press on arrow [param n], and the arrow: {at, way (on the screen),
## handle}, empty when it is not drawn.
func _arrow(n: int) -> Dictionary:
	var handles: Handles = _verbs.handles
	for handle: Dictionary in handles.screen_handles():
		if handle["kind"] == "arrow" and int(handle["axis"]) == n:
			var points: PackedVector2Array = handle["points"]
			var at: Vector2 = points[0].lerp(points[1], 0.7)
			if handles.handle_at(at).get("kind") != "arrow" or int(handles.handle_at(at).get("axis", -1)) != n:
				continue
			return {"at": at, "handle": handle}
	return {}


## The press on [param arrow] and where the pointer goes for the part to
## move 3 studs along it: the point on its line under the press, 60 LDU on.
func _three_studs(arrow: Dictionary) -> Array:
	var handles: Handles = _verbs.handles
	var press: Vector2 = arrow["at"]
	var way: Vector3 = (arrow["handle"] as Dictionary)["way"]
	var pivot: Vector3 = handles.pivot()
	var origin: Vector3 = _camera.ray_origin(press)
	var normal: Vector3 = _camera.ray_normal(press)
	# The nearest point of the arrow's line to the press's ray.
	var b: float = way.dot(normal)
	var w: Vector3 = pivot - origin
	var t: float = (b * normal.dot(w) - way.dot(w)) / maxf(1.0 - b * b, 0.0001)
	var on: Vector3 = pivot + way * t
	return [press, _camera.screen_of(on + way * 60.0)]


func _mouse_drag(path: Array) -> void:
	var from: Vector2 = path[0]
	var to: Vector2 = path[1]
	await _move(from)
	_button(from, true)
	await _frames(2)
	for k: int in range(1, 13):
		await _move(from.lerp(to, k / 12.0), true)
	await _frames(4)
	_button(to, false)
	await _frames(8)


func _finger_drag(path: Array, rest: float) -> void:
	var from: Vector2 = path[0]
	var to: Vector2 = path[1]
	_touch(0, from, true)
	await _frames(2)
	if rest > 0.0:
		await create_timer(rest).timeout
		await _frames(2)
	var at: Vector2 = from
	for k: int in range(1, 13):
		var next: Vector2 = from.lerp(to, k / 12.0)
		_drag_to(0, next, next - at)
		at = next
		await _frames(2)
	await _frames(4)
	_touch(0, to, false)
	await _settle()


## What of the view's aim moved since [param was], in words; "" for nothing.
func _aim_moved(was: Dictionary) -> String:
	var now: Dictionary = _camera.aim()
	var moved: PackedStringArray = []
	for key: String in was:
		var a: Variant = was[key]
		var b: Variant = now.get(key)
		var same: bool = is_equal_approx(float(a), float(b)) if (a is float or a is int) \
			else (a as Vector3).is_equal_approx(b) if a is Vector3 else a == b
		if not same:
			moved.append("%s %s to %s" % [key, a, b])
	return ", ".join(moved)


## How many of the three handles are drawn now.
func _drawn() -> int:
	var handles: Handles = _verbs.handles
	return handles.screen_handles().size() if handles != null and handles.shown() else 0


## A point on the screen where part [param id] is under the pointer and no
## handle is.
func _spot_on(id: int) -> Vector2:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var middle: Vector2 = _camera.screen_of(brick.transform * mesh.bounds.get_center())
	var handles: Handles = _verbs.handles
	for r: int in range(0, 80, 3):
		for d: Vector2 in [Vector2(0, r), Vector2(r, 0), Vector2(-r, 0), Vector2(0, -r),
				Vector2(r, r), Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r)]:
			if _verbs.brick_at(middle + d) == id and (handles == null
					or handles.handle_at(middle + d).is_empty()):
				return middle + d
	return middle


# -- 3. every handle's target ---------------------------------------------------


func _targets() -> void:
	var brick: int = _only_brick()
	if not _builder.selection.has(brick):
		_builder.select_brick(brick, false)
	_camera.frame(AABB(AIR - Vector3(90, 90, 90), Vector3(180, 180, 180)), 1.2)
	_camera.look_from(Vector3(0.55, 0.5, 0.67).normalized())
	await _settle()
	var handles: Handles = _verbs.handles
	for tool: String in ["move", "rotate"]:
		_shell.run("mode_" + tool)
		await _frames(6)
		if not _builder.selection.has(brick):
			_builder.select_brick(brick, false)
			await _frames(4)
		var sizes: Dictionary = _target_sizes()
		var small: PackedStringArray = []
		var kinds: PackedStringArray = []
		for label: String in sizes:
			var across: float = float(sizes[label]) / _pt()
			_table.append("%-8s %-10s %5.1f" % [tool, label, across])
			kinds.append(label)
			if across < Phone.TARGET:
				small.append("%s %.1f" % [label, across])
		var wanted: int = 6 if tool == "rotate" else 4
		_check("the %s tool's %d handles (%s): every target %d points or more across%s"
			% [tool.capitalize(), sizes.size(), ", ".join(kinds), int(Phone.TARGET),
				"" if small.is_empty() else " (under: " + ", ".join(small) + ")"],
			small.is_empty() and sizes.size() >= wanted)
		await _shot("3_%s_handles" % tool)
	# The tag, by a tap: the next axes.
	var was: String = handles.frame
	var tag: Rect2 = handles.call("_tag_box", "", CadCamera.MAIN)
	await _tap(tag.get_center())
	_check("a tap on the tag (%s) goes to the next axes: %s to %s" % [_round(tag.size / _pt()),
		was, handles.frame], handles.frame != was)
	handles.frame = "part"
	_shell.run("mode_select")
	await _frames(4)


## Every handle drawn now, by what a press there takes: the widest circle
## inside where a press takes each one, units across. Sampled every
## [constant CELL] points over the handles and the tag, in the view.
func _target_sizes() -> Dictionary:
	var handles: Handles = _verbs.handles
	var tag: Rect2 = handles.call("_tag_box", "", CadCamera.MAIN)
	var area: Rect2 = handles.on_screen().merge(tag).grow(30.0 * _pt()).intersection(_view())
	var step: float = CELL * _pt()
	var w: int = ceili(area.size.x / step)
	var h: int = ceili(area.size.y / step)
	var names: Array[String] = [""]
	var label := PackedInt32Array()
	label.resize(w * h)
	for y: int in h:
		for x: int in w:
			var taken: Dictionary = handles.handle_at(area.position + Vector2(x + 0.5, y + 0.5) * step)
			var name: String = ""
			if not taken.is_empty():
				name = str(taken["kind"]) if taken["kind"] in ["frame", "ball"] \
					else "%s %s" % [taken["kind"], ("view" if int(taken["axis"]) == Handles.VIEW_AXIS
						else Handles.AXES[int(taken["axis"])])]
			var index: int = names.find(name)
			if index == -1:
				names.append(name)
				index = names.size() - 1
			label[y * w + x] = index
	# The nearest edge of a cell's own label to each cell (two passes, as
	# 8SSEDT): its distance is how far a circle round the cell reaches.
	var near := PackedVector2Array()
	near.resize(w * h)
	near.fill(Vector2.INF)
	for y: int in h:
		for x: int in w:
			var me: int = label[y * w + x]
			var cell := Vector2(x, y)
			var seeds: Array[Vector2] = []
			if x == 0:
				seeds.append(cell + Vector2(-0.5, 0))
			if y == 0:
				seeds.append(cell + Vector2(0, -0.5))
			if x == w - 1:
				seeds.append(cell + Vector2(0.5, 0))
			if y == h - 1:
				seeds.append(cell + Vector2(0, 0.5))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and label[ny * w + nx] != me:
					seeds.append(cell + Vector2(d) * 0.5)
			for seed: Vector2 in seeds:
				if seed.distance_squared_to(cell) < near[y * w + x].distance_squared_to(cell):
					near[y * w + x] = seed
	for sweep: int in 2:
		var ys: Array = range(h) if sweep == 0 else range(h - 1, -1, -1)
		var back: int = 1 if sweep == 0 else -1
		for y: int in ys:
			for x: int in (range(w) if sweep == 0 else range(w - 1, -1, -1)):
				for d: Vector2i in [Vector2i(-back, 0), Vector2i(0, -back), Vector2i(-back, -back),
						Vector2i(back, -back)]:
					_take_nearer(near, label, w, h, x, y, x + d.x, y + d.y)
			for x: int in (range(w - 1, -1, -1) if sweep == 0 else range(w)):
				_take_nearer(near, label, w, h, x, y, x + back, y)
	var widest: Dictionary = {}
	for index: int in w * h:
		var name: String = names[label[index]]
		if name == "":
			continue
		var cell := Vector2(index % w, index / w)
		var reach: float = near[index].distance_to(cell) * step * 2.0
		widest[name] = maxf(float(widest.get(name, 0.0)), reach)
	return widest


static func _take_nearer(near: PackedVector2Array, label: PackedInt32Array, w: int, h: int,
		x: int, y: int, nx: int, ny: int) -> void:
	if nx < 0 or ny < 0 or nx >= w or ny >= h or label[ny * w + nx] != label[y * w + x]:
		return
	var cell := Vector2(x, y)
	var theirs: Vector2 = near[ny * w + nx]
	if theirs.distance_squared_to(cell) < near[y * w + x].distance_squared_to(cell):
		near[y * w + x] = theirs


# -- 4. dialogs ------------------------------------------------------------------


func _dialogs() -> void:
	var touch: TouchSizing = _main.get("_touch")
	if not _check("dialogs are laid out for a finger (TouchSizing)", touch != null):
		return
	var from: int = _errors.count()
	var opened: Array[String] = []
	var unopened: Array[String] = []
	for name: String in DIALOGS:
		var before: Array = (touch.get("_open") as Array).duplicate()
		if not _shell.run(name):
			unopened.append(name)
			continue
		var shown: Array = []
		for _n: int in 90:
			await process_frame
			shown = (touch.get("_open") as Array).filter(func(held: Variant) -> bool:
				return is_instance_valid(held) and not held in before)
			if not shown.is_empty():
				break
		if shown.is_empty():
			unopened.append(name)
			continue
		await _frames(8)
		opened.append(name)
		if opened.size() == 1:
			await _shot("4_dialog_%s" % name)
		for held: Variant in shown:
			await _close(held)
		await _frames(4)
	print("  the app's opened and closed: %s%s" % [", ".join(opened),
		"" if unopened.is_empty() else "; opened none: " + ", ".join(unopened)])
	var made: int = 0
	# Freed while open, at the frame's end and at once: never said to hide.
	for at_once: bool in [false, true]:
		var gone := AcceptDialog.new()
		gone.dialog_text = "Freed while it is open"
		root.add_child(gone)
		gone.popup_centered()
		await _frames(10)
		if at_once:
			gone.free()
		else:
			gone.queue_free()
		await _frames(6)
		made += 1
	# A list filled afresh twice in a frame, its first rows freed at once.
	var listed := AcceptDialog.new()
	listed.title = "Rows"
	var rows := VBoxContainer.new()
	listed.add_child(rows)
	root.add_child(listed)
	listed.popup_centered(Vector2i(300, 200))
	await _frames(10)
	for again: int in 2:
		for child: Node in rows.get_children():
			child.free()
		for n: int in 12:
			var row := Button.new()
			row.text = "Row %d, fill %d" % [n, again]
			rows.add_child(row)
	await _frames(10)
	_check("...a list filled afresh twice in a frame: its rows sized for a finger (%.0f points tall)"
		% ((rows.get_child(0) as Control).size.y / _pt()),
		(rows.get_child(0) as Control).size.y >= _points(Phone.TARGET) - 0.5)
	listed.hide()
	listed.queue_free()
	await _frames(4)
	made += 1
	# Popped and freed in the same frame.
	var brief := ConfirmationDialog.new()
	brief.dialog_text = "Here and gone"
	root.add_child(brief)
	brief.popup_centered()
	brief.free()
	await _frames(6)
	made += 1
	# Opened and closed by OK, as many as it takes to make twenty.
	while opened.size() + made < 20:
		var plain := AcceptDialog.new()
		plain.dialog_text = "Opened and closed by OK"
		root.add_child(plain)
		plain.popup_centered()
		await _frames(10)
		plain.get_ok_button().pressed.emit()
		await _frames(4)
		plain.queue_free()
		await _frames(2)
		made += 1
	var said: PackedStringArray = _errors.since(from)
	var ours: PackedStringArray = []
	for line: String in said:
		if line.contains("touch_sizing"):
			ours.append(line)
	for line: String in said:
		print("    error said: %s" % line.left(300))
	print("  measure touch_sizing_errors %d of %d errors over %d dialogs" % [ours.size(), said.size(),
		opened.size() + made])
	_check("%d dialogs opened and closed (%d of the app's, %d made here): %d errors name touch_sizing%s"
		% [opened.size() + made, opened.size(), made, ours.size(),
			"" if ours.is_empty() else " (first: %s)" % ours[0].left(240)],
		opened.size() + made >= 20 and ours.is_empty())


## A dialog or a panel closed as a person closes it: a window's close, else
## put away.
func _close(held: Variant) -> void:
	if not is_instance_valid(held):
		return
	var window := held as Window
	if window != null:
		window.close_requested.emit()
		await _frames(6)
		if is_instance_valid(window) and window.visible:
			window.hide()
		return
	var panel := held as Control
	if panel != null and panel.visible:
		panel.hide()


# -- fingers and the mouse ------------------------------------------------------


## A tap at [param at], held [param hold] seconds.
func _tap(at: Vector2, hold: float = 0.0) -> void:
	_touch(0, at, true)
	await _frames(2)
	if hold > 0.0:
		await create_timer(hold).timeout
	_touch(0, at, false)
	await _frames(6)


func _touch(index: int, at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _drag_to(index: int, at: Vector2, by: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = _as_event(at)
	drag.relative = _as_event(by)
	Input.parse_input_event(drag)


func _move(at: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	await _frames(2)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(6)


## A point in the viewport's units as the window hands it over.
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


# -- the rest -----------------------------------------------------------------


## A point in the window's units.
func _pt() -> float:
	return Phone.per_point(root)


func _points(points: float) -> float:
	return points * _pt()


static func _round(at: Vector2) -> Vector2:
	return Vector2(snappedf(at.x, 0.1), snappedf(at.y, 0.1))


## The model's room on the screen.
func _view() -> Rect2:
	return (_main.call("model_cover") as Dictionary)["view"]


## The phone's sheet open now, by its title; "" for none.
func _sheet() -> String:
	return str((_phone.call("state") as Dictionary).get("sheet", "")) if _phone != null else ""


## Frames until the camera stops, and one drawn.
func _settle() -> void:
	var last := Transform3D()
	var still: int = 0
	for _n: int in 600:
		await process_frame
		if _camera.global_transform.is_equal_approx(last):
			still += 1
			if still >= 3:
				break
		else:
			still = 0
		last = _camera.global_transform
	await RenderingServer.frame_post_draw


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out.path_join(name + ".png"))
	if image != null and image.save_png(path) == OK:
		print("    picture: %s" % path)


func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("")
	print("fingertools_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
