## A part dragged in the view carries what rests on it, and Shift as it goes
## moves it alone (docs/APP_UX7.md, #20 carryrest; Brickyard's drag).
##
##   godot --path . --resolution 1400x900 --script src/dev/carryrest_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh carryrest_probe   the desktop's, by mouse
##   tools/probe.sh carryrest_phone_probe                 a phone's, by finger
##   tools/probe.sh carryrest_tablet_probe                a tablet's, by finger
##   ... --no-gate     past the sign-in screen without an account (no Supabase)
##
## Through the sign-in screen with a throwaway account (.env), as everyone
## uses Brickworks, then on a little model built for it: a 2 x 4 brick on
## another, with a 2 x 2 brick on it, a 2 x 2 plate on that and a 1 x 1 brick
## on top (all three resting on it, held by nothing else), and a 2 x 4 plate
## across its other half and a brick beside it that stays, with a 1 x 1 on the
## plate. pre261 moved the dragged brick alone and left the three hanging in
## the air.
##   1. by mouse with the Select tool (by finger on a phone's or a tablet's
##      layout), the brick dragged onto the ground: the three come with it,
##      each where it was on it, 0.00 LDU off; the plate across it, what is on
##      the plate, the brick beside and what the brick stands on stay where
##      they were; the bar says what it carries while it is dragged; one undo
##      puts all six back as they were, one redo moves them again;
##   2. Shift held from the start of the drag: the brick alone, the three where
##      they were; one undo puts it back;
##   3. Shift pressed half way and let go of again: alone while it is held, the
##      three back in their places, then with it again; let go of, all four
##      moved as in 1; still one undo;
##   4. Escape half way: everything where it was, nothing in hand, the brick
##      selected and not what rested on it;
##   5. what rests on a part found as a drag starts on the Millennium Falcon
##      (10179, 5,266 parts), every third part asked: 95% in 5 ms or less, the
##      slowest in 100 ms, the app's own time (ProbeTime: three times as long
##      on a box loaded past its cores) (Carry.riders).
## Pictures before, mid-drag and after in shots/carryrest/ (or CARRYREST_OUT).
## Exits non-zero when a check fails.
extends SceneTree

var OUT: String = OS.get_environment("CARRYREST_OUT") if OS.has_environment("CARRYREST_OUT") \
	else ProjectSettings.globalize_path("res://shots/carryrest")
## The big model what rests on its parts is timed on, and how long a look may
## take, ms.
const BIG := "res://vendor/omr/files/10179-1.mpd"
const LOOK_MS := 5.0
const LOOK_MOST_MS := 100.0

## The little model: a name, the part, its colour and where its top is.
const MODEL: Array = [
	["base", "3001", 1, Vector3(0, 24, 0)],
	["dragged", "3001", 4, Vector3(0, 48, 0)],
	["on it", "3003", 14, Vector3(-20, 72, 0)],
	["plate on that", "3022", 2, Vector3(-20, 80, 0)],
	["top", "3005", 15, Vector3(-30, 104, 10)],
	["beside, under", "3001", 0, Vector3(80, 24, 0)],
	["beside", "3001", 0, Vector3(80, 48, 0)],
	["across", "3020", 71, Vector3(40, 56, 0)],
	["on the plate", "3005", 25, Vector3(70, 80, 10)],
]
const RIDERS: Array = ["on it", "plate on that", "top"]
const STAY: Array = ["base", "beside, under", "beside", "across", "on the plate"]

var _failures: int = 0
var _main: Node
var _camera: CadCamera
var _world: BrickWorld
var _builder: Builder
var _verbs: EditVerbs
var _size: String = ""
var _layout: String = "desktop"
var _finger: bool = false
var _said: String = ""
var _email: String = ""
var _password: String = ""
var _last_screen := Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


## Laid out for a tablet (carryrest_tablet_probe); a phone's window is
## laid out for a phone by its size.
func _tablet() -> bool:
	return false


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("carryrest_probe: needs a window")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var gated: bool = not args.has("--no-gate")
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	var tablet: bool = _tablet()
	_layout = "tablet" if tablet else ("phone" if mini(window.x, window.y) < int(Phone.NARROW)
		else "desktop")
	_finger = _layout != "desktop"
	Phone._on = 1 if _finger else 0
	Phone._wide = tablet
	DirAccess.make_dir_recursive_absolute(OUT)
	if gated:
		Account.where = "user://probe_session.json"
		Account._clear()
	else:
		OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", gated)
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
	if _layout == "phone":
		(_main.get("_phone") as Node).set_process(false)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
	await _frames(20)
	(_main.get("_store") as ModelStore).keeps = false
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	(_main.get("_bar") as ModelBar).said.connect(func(text: String) -> void: _said = text)
	print("carryrest_probe: a %s window, laid out for a %s, %s" % [_size, _layout,
		"by finger" if _finger else "by mouse"])
	if gated and not await _way_in():
		await _finish()
		return
	if not gated:
		print("  (past the sign-in screen without an account: --no-gate)")

	print("\n1. the brick dragged %s carries what rests on it" % ("by finger" if _finger
		else "by mouse"))
	await _carried()
	if not _finger:
		print("\n2. Shift held from the start: the brick alone")
		await _alone_from_the_start()
		print("\n3. Shift pressed half way, then let go of")
		await _shift_half_way()
		print("\n4. Escape half way")
		await _escape_half_way()
		print("\n5. how long the look for what rests on a part takes on a big set")
		await _on_a_big_set()
	await _finish()


# -- the way in -------------------------------------------------------------------


func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("carryrest")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


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


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("\ncarryrest_probe (%s, %s): %s" % [_size, _layout,
		"all passed" if _failures == 0 else "%d failed" % _failures])
	quit(1 if _failures else 0)


# -- the cases --------------------------------------------------------------------


func _carried() -> void:
	await _fresh_model()
	var before: Dictionary = _where()
	var from: Vector2 = _press_point()
	var to: Vector2 = _ground_point()
	await _shot("1_before")
	var depth: int = _builder.history_depth()
	await _press(from)
	await _drag_to(from, from.lerp(to, 0.5), false, 12)
	var carried: int = _builder.carrying.count() if _builder.is_carrying() else 0
	var words: String = _said
	await _shot("2_mid_drag")
	_check("half way, %d parts in hand: the brick and the three resting on it (4)" % carried,
		carried == 4)
	if not _finger:
		_check("...and the bar says so: \"%s\"" % words,
			words == "moving 1 part and the 3 parts resting on it — Shift moves it alone")
	await _drag_to(from.lerp(to, 0.5), to, false, 12)
	await _release(to)
	await _shot("3_after")
	var after: Dictionary = _where()
	_moved_with(before, after, RIDERS, "the three resting on it")
	_stayed(before, after, STAY)
	_check("one step to undo (%d, was %d)" % [_builder.history_depth(), depth],
		_builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(3)
	_check("one undo puts all four back where they were, nothing else changed",
		_where() == before)
	_builder.redo()
	await _frames(3)
	_check("one redo moves them again, as they were moved", _where() == after)


func _alone_from_the_start() -> void:
	await _fresh_model()
	var before: Dictionary = _where()
	var from: Vector2 = _press_point()
	var to: Vector2 = _ground_point()
	var depth: int = _builder.history_depth()
	await _press(from)
	await _drag_to(from, from.lerp(to, 0.5), true, 12)
	var carried: int = _builder.carrying.count() if _builder.is_carrying() else 0
	var words: String = _said
	await _shot("4_shift_mid_drag")
	_check("Shift held: 1 part in hand (%d)" % carried, carried == 1)
	_check("...and the bar says how to carry them: \"%s\"" % words,
		words == "moving 1 part alone — let go of Shift for the 3 parts on it too")
	await _drag_to(from.lerp(to, 0.5), to, true, 12)
	await _release(to, true)
	var after: Dictionary = _where()
	_check("the brick moved (%s)" % _went(before, after, "dragged"),
		not _same_place(before["dragged"], after["dragged"]))
	_stayed(before, after, RIDERS + STAY)
	_builder.undo()
	await _frames(3)
	_check("one undo (%d steps, was %d) puts it back" % [_builder.history_depth() + 1, depth],
		_where() == before and _builder.history_depth() == depth)


func _shift_half_way() -> void:
	await _fresh_model()
	var before: Dictionary = _where()
	var from: Vector2 = _press_point()
	var to: Vector2 = _ground_point()
	var depth: int = _builder.history_depth()
	await _press(from)
	var half: Vector2 = from.lerp(to, 0.5)
	await _drag_to(from, half, false, 12)
	var first: int = _builder.carrying.count() if _builder.is_carrying() else 0
	_key(KEY_SHIFT, true)
	await _frames(3)
	var alone: int = _builder.carrying.count() if _builder.is_carrying() else 0
	var meanwhile: Dictionary = _where()
	await _shot("5_shift_pressed")
	_check("with what rests on it (%d in hand), then Shift: %d in hand" % [first, alone],
		first == 4 and alone == 1)
	var back: bool = true
	for name: String in RIDERS + STAY:
		back = back and meanwhile.has(name) and _same_place(meanwhile[name], before[name])
	_check("...the three back where they were, on nothing, while it is held", back)
	await _drag_to(half, from.lerp(to, 0.75), true, 6)
	_key(KEY_SHIFT, false)
	await _frames(3)
	var again: int = _builder.carrying.count() if _builder.is_carrying() else 0
	_check("Shift let go of: %d in hand again (4)" % again, again == 4)
	await _drag_to(from.lerp(to, 0.75), to, false, 6)
	await _release(to)
	var after: Dictionary = _where()
	_moved_with(before, after, RIDERS, "the three resting on it")
	_stayed(before, after, STAY)
	_check("one step to undo (%d, was %d)" % [_builder.history_depth(), depth],
		_builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(3)
	_check("one undo puts all four back", _where() == before)


func _escape_half_way() -> void:
	await _fresh_model()
	var before: Dictionary = _where()
	var from: Vector2 = _press_point()
	var to: Vector2 = _ground_point()
	await _press(from)
	await _drag_to(from, from.lerp(to, 0.5), false, 12)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames(3)
	await _button(from.lerp(to, 0.5), false)
	await _frames(3)
	_check("Escape half way: everything where it was (%s), nothing in hand"
		% ("so" if _where() == before else "not so"),
		_where() == before and not _builder.is_carrying())
	var chosen: Array = []
	for brick_id: int in _builder.selection:
		chosen.append(_world.get_brick(brick_id).part_id + "/%d" % _world.get_brick(brick_id).color_code)
	_check("...the dragged brick selected, as the drag chose it, and not what rested on it (%s)"
		% ", ".join(chosen), chosen == ["3001/4"])


## What rests on a part, looked for on a big set's every third part: the time
## a look takes, against [constant LOOK_MS] and [constant LOOK_MOST_MS]. The
## first look, every joint asked of every part, took 3.1 s from one part of
## the Millennium Falcon, down to the ground through its hull and legs.
func _on_a_big_set() -> void:
	if not FileAccess.file_exists(BIG):
		_check("%s is here (tools/omr.py fetch)" % BIG, false)
		return
	# Asked by name, so that pre261, which has no such look, fails here
	# rather than failing to load.
	var carry: Script = load("res://src/assembly/carry.gd")
	var named: bool = false
	for method: Dictionary in carry.get_script_method_list():
		named = named or method["name"] == "riders"
	if not _check("Carry has a look for what rests on a part", named):
		return
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", ProjectSettings.globalize_path(BIG))
	var store: ModelStore = _main.get("_store")
	for _n: int in 900:
		await process_frame
		if store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	var ids: Array = _world._bricks.keys()
	ids.sort()
	# The app's own time (ProbeTime): the box is shared, and a release runs
	# its probes four at a time.
	var times: Array = []
	var slowest: ProbeTime.Span = null
	var worst_id: int = 0
	var carried: int = 0
	var cut: int = 0
	var busy: float = 0.0
	for n: int in range(0, ids.size(), 3):
		var span := ProbeTime.Span.new()
		var found: Dictionary = carry.call("riders", _world, _builder.lattice, [ids[n]],
			_verbs.scenery, _builder.takes, _builder.locked)
		span.end()
		busy = maxf(busy, span.busy)
		if slowest == null or span.own > slowest.own:
			slowest = span
			worst_id = ids[n]
		times.append(span.own)
		carried += 1 if not (found["riders"] as Array).is_empty() else 0
		cut += 1 if bool(found["cut"]) else 0
	times.sort()
	var p95: float = times[int(times.size() * 0.95)]
	var slack: float = 3.0 if busy > ProbeTime.cores() else 1.0
	print("  measure big_look parts=%d asked=%d median_ms=%.2f p95_ms=%.2f worst_ms=%.2f carried_any=%d cut=%d slack=%.0f"
		% [ids.size(), times.size(), times[times.size() / 2], p95, slowest.own, carried, cut, slack])
	_check("on %s's %d parts, %d asked what rests on each: 95%% in %.2f ms or less (%.0f), the slowest %s (#%d %s, %.0f)"
		% [BIG.get_file(), ids.size(), times.size(), p95, LOOK_MS * slack, slowest.said(), worst_id,
			_world.get_brick(worst_id).part_id, LOOK_MOST_MS * slack],
		ids.size() > 1000 and p95 <= LOOK_MS * slack and slowest.own <= LOOK_MOST_MS * slack)


# -- the model and where it is -------------------------------------------------------


## The little model, framed, nothing selected and no history.
func _fresh_model() -> void:
	if _builder.is_carrying():
		_builder.cancel_carry()
	_main.call("clear_model")
	await _frames(4)
	for row: Array in MODEL:
		var at := Transform3D(Basis.IDENTITY, row[3] as Vector3)
		var id: int = _world.add_brick(row[1], row[2], at)
		_builder.register(id, row[1], at)
	_builder.forget_history()
	_builder.clear_selection()
	_verbs.set_mode("select")
	_camera.set_view("default")
	_camera.frame(AABB(Vector3(-260, 0, -60), Vector3(380, 110, 120)))
	await _settle()


## Each of the model's parts by its name, where it stands now (ids change as a
## part is lifted and put down, so by its part and colour).
func _where() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		for row: Array in MODEL:
			if brick.part_id == row[1] and brick.color_code == int(row[2]) \
					and not out.has(row[0]) and _named_free(out, row, brick):
				out[row[0]] = brick.transform
				break
	return out


## The two black bricks share a part and a colour: the lower is "beside, under".
func _named_free(out: Dictionary, row: Array, brick: BrickWorld.Brick) -> bool:
	if row[0] == "beside, under":
		return brick.transform.origin.y < 36.0
	if row[0] == "beside":
		return brick.transform.origin.y >= 36.0
	return true


func _same_place(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.001 and a.basis.is_equal_approx(b.basis)


func _went(before: Dictionary, after: Dictionary, name: String) -> String:
	if not before.has(name) or not after.has(name):
		return "gone"
	var by: Vector3 = (after[name] as Transform3D).origin - (before[name] as Transform3D).origin
	return "by %.1f, %.1f, %.1f LDU" % [by.x, by.y, by.z]


## [param names] moved with the dragged brick: each where it was on it.
func _moved_with(before: Dictionary, after: Dictionary, names: Array, what: String) -> void:
	_check("the dragged brick moved (%s)" % _went(before, after, "dragged"),
		after.has("dragged") and not _same_place(before["dragged"], after["dragged"]))
	if not after.has("dragged"):
		return
	var off: float = 0.0
	var all_moved: bool = true
	for name: String in names:
		if not after.has(name):
			off = INF
			continue
		var was: Transform3D = (before["dragged"] as Transform3D).affine_inverse() * before[name]
		var now: Transform3D = (after["dragged"] as Transform3D).affine_inverse() * after[name]
		off = maxf(off, was.origin.distance_to(now.origin))
		if not was.basis.is_equal_approx(now.basis):
			off = INF
		all_moved = all_moved and not _same_place(before[name], after[name])
	print("  measure riders_off %.4f" % off)
	_check("%s came with it, each %.2f LDU from where it was on it (0.00)" % [what, off],
		all_moved and off < 0.005)


## [param names] where they were.
func _stayed(before: Dictionary, after: Dictionary, names: Array) -> void:
	var moved: Array = []
	for name: String in names:
		if not after.has(name) or not _same_place(before[name], after[name]):
			moved.append(name)
	_check("%s stayed where they were%s" % [", ".join(names), "" if moved.is_empty()
		else " (moved: %s)" % ", ".join(moved)], moved.is_empty())


# -- the pointer -------------------------------------------------------------------


## A point on the dragged brick's face that the view sees, where nothing else
## is in front of it.
func _press_point() -> Vector2:
	var dragged: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3001" and brick.color_code == 4:
			dragged = brick.id
	for at: Vector3 in [Vector3(-20, 36, 20), Vector3(-20, 36, -20), Vector3(-40, 36, 0),
			Vector3(-30, 40, 20), Vector3(-30, 40, -20)]:
		var seen: Vector2 = _camera.unproject_position(at)
		if _verbs.brick_at(seen) == dragged:
			return seen
	_check("a point on the dragged brick is in sight", false)
	return _camera.unproject_position(Vector3(-20, 36, 20))


## The ground left of the model, where all four fit.
func _ground_point() -> Vector2:
	return _camera.unproject_position(Vector3(-180, 0, 0))


func _press(at: Vector2) -> void:
	_last_screen = at
	if _finger:
		_touch(at, true)
	else:
		await _button(at, true)
	await _frames(2)


func _release(at: Vector2, shift: bool = false) -> void:
	if _finger:
		_touch(at, false)
	else:
		await _button(at, false, shift)
	await _frames(4)


## From [param from] to [param to] in [param steps] frames, eased as a hand
## moves, Shift held or not.
func _drag_to(from: Vector2, to: Vector2, shift: bool, steps: int) -> void:
	for n: int in steps:
		var next: Vector2 = from.lerp(to, smoothstep(0.0, 1.0, float(n + 1) / steps))
		if _finger:
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = _as_event(next)
			drag.relative = _as_event(next) - _as_event(_last_screen)
			Input.parse_input_event(drag)
		else:
			var move := InputEventMouseMotion.new()
			move.position = _as_event(next)
			move.global_position = move.position
			move.relative = _as_event(next) - _as_event(_last_screen)
			move.button_mask = MOUSE_BUTTON_MASK_LEFT
			move.shift_pressed = shift
			Input.parse_input_event(move)
		_last_screen = next
		await _frames(2)


func _button(at: Vector2, down: bool, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.shift_pressed = shift
	Input.parse_input_event(event)
	await _frames(2)


func _touch(at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _key(code: Key, down: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = down
	key.shift_pressed = down and code == KEY_SHIFT
	Input.parse_input_event(key)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or rect.x <= 0.0:
		return at
	return at * (window / rect)


# -- frames and pictures ---------------------------------------------------------------


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
	await RenderingServer.frame_post_draw
	var path: String = OUT.path_join("%s_%s_%s.png" % [_size, _layout, name])
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)
