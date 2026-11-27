## A two-finger tap undoes, a three-finger tap redoes and a double tap turns a
## part, on a phone (docs/APP_UX10.md, unit phonefingers).
##
##   godot --path . --resolution 390x844 --script src/dev/phonefingers_probe.gd
##   PROBE_SIZE=1024x768 tools/probe.sh phonefingers_probe --tablet     a tablet's layout
##
## Every iPhone app that edits undoes with a two-finger tap and redoes with
## three (Procreate; Brick Creator 3D since 19 November), and Brickworks had
## no tap gesture at all. In the app laid out for a phone (or a tablet, with
## --tablet), by touch events as a finger sends them, each finger coming down
## and lifting as the window hands them over:
##   1. a two-finger tap undoes and a three-finger tap redoes, each leaving
##      the model byte for byte as the top bar's Undo and Redo leave it, its
##      history as theirs, and saying what it took back as they do; where
##      there is nothing to undo it says so;
##   2. a second finger tapped while one drags a part, or while one turns the
##      view, undoes nothing: the part goes back where it was, as a second
##      finger always put it; a two-finger tap on the top bar is the bar's;
##   3. a two-finger tap with a part in hand undoes the last part put down and
##      the part stays in hand; with parts lifted off the model and carried,
##      Undo (the tap's and the bar's) takes the lift back and lets go of them,
##      so a tap after puts no second copy down;
##   4. a double tap on a part turns it 90° round the up, one step to undo,
##      undone byte for byte; on nothing, on a locked part, with a part in
##      hand (each tap puts one down) and with Select's adding on (each tap
##      adds or takes out) it is two taps, as before;
##   5. no false fires: 100 two-finger turns, pinches and twists on the car,
##      fast and slow, some begun on a part, say no tap and undo nothing; and
##      the least any of them went, in points, against a tap's 10.
## Exits non-zero when a check fails.
extends SceneTree

const CAR := "res://models/car.ldr"
## How far a fingertip wobbles in a tap, in the window's units: under the
## app's 5 for a drag (Main.DRAG_SLOP), as a tap on glass is.
const WOBBLE := Vector2(2.0, -1.5)

var _failures: int = 0
var _main: Node
var _camera: CadCamera
var _world: BrickWorld
var _builder: Builder
var _verbs: EditVerbs
var _store: ModelStore
var _phone: Node
var _layout: String = "phone"


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("phonefingers_probe: needs a window")
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var tablet: bool = OS.get_cmdline_user_args().has("--tablet")
	_layout = "tablet" if tablet else "phone"
	Phone._on = 1
	Phone._wide = tablet
	_main = load("res://src/main.tscn").instantiate()
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
		_phone.set("holds_scale", true)
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
	_store = _main.get("_store")
	_store.keeps = false
	var window: Vector2i = DisplayServer.window_get_size()
	print("phonefingers_probe: a %dx%d window laid out for a %s; a tap is %d ms and %.0f points, a double tap's second within %d ms and %.0f points"
		% [window.x, window.y, _layout, CadCamera.TAP_MS, CadCamera.TAP_POINTS,
			CadCamera.DOUBLE_TAP_MS, CadCamera.DOUBLE_TAP_POINTS])
	if not _check("the phone's layout is up, the camera taking fingers as a phone's",
			_phone != null and _camera.phone):
		quit(1)
		return

	print("\n1. a two-finger tap undoes and a three-finger tap redoes, as the bar's buttons do")
	await _as_the_buttons()
	print("\n2. a tap during a drag, and on the bar")
	await _during_a_drag()
	print("\n3. a tap with a part in hand")
	await _with_a_part_in_hand()
	print("\n4. a double tap turns a part")
	await _double_taps()
	print("\n5. no false fires: 100 turns, pinches and twists on the car")
	await _no_false_fires()
	print("\n6. where a person finds them: Keys and controls")
	await _in_the_keys_sheet()

	print("\nphonefingers_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


# -- 1. as the buttons ------------------------------------------------------------


## The model as the bar's Undo leaves it and as a two-finger tap does, each
## from the same model and the same edit; then Redo and a three-finger tap.
func _as_the_buttons() -> void:
	var by_button: Dictionary = await _undo_redo_by("button")
	var by_tap: Dictionary = await _undo_redo_by("tap")
	print("  measure undo_said %s | %s" % [by_button["undo_said"], by_tap["undo_said"]])
	print("  measure redo_said %s | %s" % [by_button["redo_said"], by_tap["redo_said"]])
	_check("the edit made a step (%d steps, from %d)" % [by_tap["edited_depth"], by_tap["depth"]],
		int(by_tap["edited_depth"]) == int(by_tap["depth"]) + 1)
	_check("a two-finger tap undid it: the model byte for byte as before it (%d bytes)"
		% str(by_tap["undone"]).length(), by_tap["undone"] == by_tap["before"])
	_check("...byte for byte as the bar's Undo leaves it, its steps to undo and redo as Undo's (%s, %s)"
		% [by_tap["undone_steps"], by_button["undone_steps"]],
		by_tap["undone"] == by_button["undone"] and by_tap["undone_steps"] == by_button["undone_steps"])
	_check("...saying what it took back as Undo does (\"%s\")" % by_tap["undo_said"],
		by_tap["undo_said"] == by_button["undo_said"] and str(by_tap["undo_said"]).begins_with("undid"))
	_check("a three-finger tap redid it: byte for byte as the bar's Redo leaves it (%s, %s)"
		% [by_tap["redone_steps"], by_button["redone_steps"]],
		by_tap["redone"] == by_button["redone"] and by_tap["redone"] == by_tap["edited"]
		and by_tap["redone_steps"] == by_button["redone_steps"])
	_check("...saying what it put back as Redo does (\"%s\")" % by_tap["redo_said"],
		by_tap["redo_said"] == by_button["redo_said"] and str(by_tap["redo_said"]).begins_with("redid"))
	_check("...the camera said one tap of two and one of three (%s)" % by_tap["said"],
		int(by_tap["said"]["two"]) == 1 and int(by_tap["said"]["three"]) == 1)

	# Nothing to undo: said, as a key says it.
	await _fresh_model()
	var said_before: Dictionary = _camera.taps_said.duplicate()
	await _tap([_spot(-0.15, 0.0), _spot(0.15, 0.0)])
	await _frames(8)
	var words: String = _said()
	print("  measure nothing_said %s" % words)
	_check("a two-finger tap with nothing to undo says so (\"%s\"), the model as it was" % words,
		words.to_lower().contains("nothing to undo") and _builder.history_depth() == 0
		and int(_camera.taps_said["two"]) == int(said_before["two"]) + 1)


## From a fresh model: a part taken off (Delete, one step), undone and redone
## by the bar's buttons or by taps, and the model's text at each point.
func _undo_redo_by(how: String) -> Dictionary:
	await _fresh_model()
	var out: Dictionary = {"before": _store.to_text(), "depth": _builder.history_depth()}
	_builder.select_brick(_top_brick(), false)
	(_main.get("_shell") as Shell).run("delete")
	await _frames(8)
	out["edited"] = _store.to_text()
	out["edited_depth"] = _builder.history_depth()
	var said_before: Dictionary = _camera.taps_said.duplicate()
	_say_nothing()
	if how == "button":
		(_tool("undo") as Button).pressed.emit()
	else:
		await _tap([_spot(-0.15, 0.1), _spot(0.15, 0.1)])
	await _frames(8)
	out["undone"] = _store.to_text()
	out["undone_steps"] = [_builder.history_depth(), _builder._redo.size()]
	out["undo_said"] = _said()
	_say_nothing()
	if how == "button":
		(_tool("redo") as Button).pressed.emit()
	else:
		await _tap([_spot(-0.2, 0.1), _spot(0.0, 0.1), _spot(0.2, 0.1)])
	await _frames(8)
	out["redone"] = _store.to_text()
	out["redone_steps"] = [_builder.history_depth(), _builder._redo.size()]
	out["redo_said"] = _said()
	out["said"] = {"two": int(_camera.taps_said["two"]) - int(said_before["two"]),
		"three": int(_camera.taps_said["three"]) - int(said_before["three"])}
	return out


# -- 2. during a drag -------------------------------------------------------------


func _during_a_drag() -> void:
	# One finger carries a part; a second taps.
	await _fresh_model()
	var parts: Array = _parts()
	var depth: int = _builder.history_depth()
	var twos: int = int(_camera.taps_said["two"])
	var on: Vector2 = _camera.screen_of(_world.get_brick(_top_brick()).transform.origin)
	_touch(0, on, true)
	await process_frame
	var at: Vector2 = on
	for n: int in 12:
		var next: Vector2 = on + Vector2(0.0, 60.0) * _eased(n + 1, 12)
		_drag(0, next, next - at)
		at = next
		await process_frame
	var carried: bool = bool(_main.get("_dragging_part")) or bool(_main.get("_grabbing"))
	var beside: Vector2 = _spot(0.25, -0.1)
	_touch(1, beside, true)
	_touch(1, beside, false)
	await process_frame
	for n: int in 6:
		var next: Vector2 = at + Vector2(0.0, 4.0)
		_drag(0, next, next - at)
		at = next
		await process_frame
	_touch(0, at, false)
	await _settle()
	print("  measure drag_tap carried=%s twos=%d depth=%d->%d" % [carried,
		int(_camera.taps_said["two"]) - twos, depth, _builder.history_depth()])
	_check("a finger dragging a part (%s), a second finger tapped: no undo (%d taps said, %d steps, was %d)"
		% ["carried" if carried else "not carried", int(_camera.taps_said["two"]) - twos,
			_builder.history_depth(), depth],
		carried and int(_camera.taps_said["two"]) == twos and _builder.history_depth() == depth)
	_check("...the part back where it was, the selection as it was, as a second finger always put it",
		_parts() == parts)

	# One finger turns the view; a second taps.
	await _fresh_model()
	parts = _parts()
	depth = _builder.history_depth()
	twos = int(_camera.taps_said["two"])
	var yaw: float = _camera.yaw_turned()
	var ground: Vector2 = _spot(0.0, 0.3)
	_check("...the view's finger starts on no part", _verbs.brick_at(ground) == 0)
	_touch(0, ground, true)
	await process_frame
	at = ground
	for n: int in 10:
		var next: Vector2 = ground + Vector2(80.0, 0.0) * _eased(n + 1, 10)
		_drag(0, next, next - at)
		at = next
		await process_frame
	_touch(1, _spot(-0.25, -0.2), true)
	_touch(1, _spot(-0.25, -0.2), false)
	await process_frame
	_touch(0, at, false)
	await _settle()
	_check("a finger turning the view (%.0f°), a second finger tapped: no undo, the model as it was"
		% rad_to_deg(absf(_camera.yaw_turned() - yaw)),
		int(_camera.taps_said["two"]) == twos and _builder.history_depth() == depth and _parts() == parts)

	# Two fingers on the top bar: the bar's, not the model's.
	await _fresh_model()
	_builder.select_brick(_top_brick(), false)
	(_main.get("_shell") as Shell).run("delete")
	await _frames(8)
	depth = _builder.history_depth()
	twos = int(_camera.taps_said["two"])
	# On the bar between its controls: with Simple | Full in the bar, the
	# middle of the window is its Undo button, which a finger presses.
	var bar: float = float(_phone.call("top_height")) * 0.5
	var free: Array = _bar_gaps(bar)
	_check("the top bar has room between its controls for two fingers (%s)" % str(free), free.size() >= 2)
	if free.size() < 2:
		return
	await _tap([Vector2(float(free[0]), bar), Vector2(float(free[1]), bar)])
	await _frames(6)
	_check("a two-finger tap on the top bar undoes nothing (%d steps, was %d)" % [
		_builder.history_depth(), depth],
		_builder.history_depth() == depth and int(_camera.taps_said["two"]) == twos)


# -- 3. a part in hand --------------------------------------------------------------


func _with_a_part_in_hand() -> void:
	await _fresh_model()
	_main.call("_on_part_chosen", "3001")
	await _frames(4)
	var count: int = _world.brick_count()
	var depth: int = _builder.history_depth()
	await _tap([_spot(0.0, 0.32)])
	await _frames(6)
	var placed: bool = _world.brick_count() == count + 1
	_check("a part in hand, a tap puts it down (%d parts, was %d)" % [_world.brick_count(), count], placed)
	_say_nothing()
	await _tap([_spot(-0.2, 0.0), _spot(0.2, 0.0)])
	await _frames(8)
	var said: String = _said()
	print("  measure in_hand %s held=%s ghost=%s" % [said, _builder.held_part, _verbs.shows_ghost()])
	_check("...a two-finger tap takes it back (%d parts, %d steps, was %d), saying so (\"%s\")"
		% [_world.brick_count(), _builder.history_depth(), depth, said],
		_world.brick_count() == count and _builder.history_depth() == depth and said.begins_with("undid"))
	_check("...and the part is still in hand, nothing put down by the tap (%s)" % _builder.held_part,
		_builder.held_part == "3001" and _verbs.shows_ghost())
	_verbs.call("put_away")
	_builder.held_part = ""
	_verbs.set_mode("select")
	await _frames(4)

	# Parts lifted off the model and carried: Undo, as the bar's, is the
	# lift taken back. They go back where they were and are let go, as Esc
	# does; before, the lift's step was undone under the hand, the parts
	# stayed held, and the next tap put a second of each down.
	var by: Dictionary = {}
	for how: String in ["tap", "button"]:
		await _fresh_model()
		_builder.select_brick(_top_brick(), false)
		(_main.get("_shell") as Shell).run("delete")
		await _frames(8)
		var before: String = _store.to_text()
		var depth_before: int = _builder.history_depth()
		_builder.select_brick(_lowest_brick(), false)
		_verbs.lift()
		await _frames(4)
		var carrying: bool = _builder.is_carrying()
		_say_nothing()
		if how == "tap":
			await _tap([_spot(-0.2, 0.0), _spot(0.2, 0.0)])
		else:
			(_tool("undo") as Button).pressed.emit()
		await _frames(8)
		var one: Dictionary = {"carried": carrying, "said": _said(), "held": _builder.is_carrying(),
			"text": _store.to_text(), "depth": _builder.history_depth(), "before": before,
			"depth_before": depth_before}
		# A tap on the ground after, as a person puts down what they think
		# they hold: nothing is held, so nothing is put down.
		await _tap([_spot(0.0, 0.32)])
		await _frames(6)
		one["after_tap"] = _store.to_text()
		by[how] = one
		print("  measure carried_%s said=%s held=%s parts %d->%d->%d" % [how, one["said"], one["held"],
			_lines(before), _lines(one["text"]), _lines(one["after_tap"])])
	var tap: Dictionary = by["tap"]
	_check("parts lifted and carried (%s), a two-finger tap takes the lift back, saying so (\"%s\"), and lets go of them"
		% [tap["carried"], tap["said"]], tap["carried"] and not tap["held"] and tap["said"] == "put back where it was")
	_check("...the model byte for byte as before the lift (%d parts), its steps as they were (%d, was %d)"
		% [_lines(tap["text"]), tap["depth"], tap["depth_before"]],
		tap["text"] == tap["before"] and tap["depth"] == tap["depth_before"])
	_check("...and a tap after puts no second copy down (%d parts)" % _lines(tap["after_tap"]),
		tap["after_tap"] == tap["before"])
	_check("...all of it as the bar's Undo does (\"%s\")" % by["button"]["said"],
		by["button"]["said"] == tap["said"] and by["button"]["text"] == tap["text"]
		and by["button"]["after_tap"] == tap["after_tap"] and by["button"]["held"] == tap["held"])


# -- 4. double taps -----------------------------------------------------------------


func _double_taps() -> void:
	await _fresh_model()
	var id: int = _top_brick()
	var before: String = _store.to_text()
	var depth: int = _builder.history_depth()
	var was: Basis = _world.get_brick(id).transform.basis
	var on: Vector2 = _camera.screen_of(_world.get_brick(id).transform.origin)
	_say_nothing()
	var gap: int = await _double_tap(on)
	await _frames(6)
	var turned_id: int = _top_brick()
	var now: Basis = _world.get_brick(turned_id).transform.basis
	var angle: float = rad_to_deg(was.get_rotation_quaternion().angle_to(now.get_rotation_quaternion()))
	var up: Vector3 = (now * was.inverse()).get_rotation_quaternion().get_axis()
	var said: String = _said()
	print("  measure double %.2f %s gap=%d said=%s" % [angle, up, gap, said])
	_check("a double tap on a part (its taps %d ms apart) turns it %.1f° (90 ±0.5) round the up (%s)"
		% [gap, angle, up], absf(angle - 90.0) <= 0.5 and absf(absf(up.y) - 1.0) < 0.01)
	_check("...in one step to undo (%d, was %d), saying so (\"%s\")" % [_builder.history_depth(), depth, said],
		_builder.history_depth() == depth + 1 and said.begins_with("turned"))
	(_tool("undo") as Button).pressed.emit()
	await _frames(8)
	_check("...and one Undo puts it back byte for byte (%d steps)" % _builder.history_depth(),
		_store.to_text() == before and _builder.history_depth() == depth)

	# On nothing: nothing.
	await _fresh_model()
	before = _store.to_text()
	var ground: Vector2 = _spot(0.0, 0.32)
	_check("...the ground there has no part on it", _verbs.brick_at(ground) == 0)
	await _double_tap(ground)
	await _frames(6)
	_check("a double tap on nothing does nothing (%d steps)" % _builder.history_depth(),
		_store.to_text() == before and _builder.history_depth() == 0 and _builder.selection.is_empty())

	# A locked part: nothing; the tap says it is locked.
	await _fresh_model()
	id = _top_brick()
	_builder.select_brick(id, false)
	_verbs.lock(true)
	_builder.clear_selection()
	await _frames(2)
	before = _store.to_text()
	depth = _builder.history_depth()
	_say_nothing()
	await _double_tap(_camera.screen_of(_world.get_brick(id).transform.origin))
	await _frames(6)
	said = _said()
	_check("a double tap on a locked part does nothing (%d steps, was %d), the tap saying it is locked (\"%s\")"
		% [_builder.history_depth(), depth, said],
		_store.to_text() == before and _builder.history_depth() == depth and said.contains("locked"))
	_builder.locked.clear()

	# A part in hand: each tap puts one down, as before.
	await _fresh_model()
	_main.call("_on_part_chosen", "3001")
	await _frames(4)
	var count: int = _world.brick_count()
	await _double_tap(_spot(0.0, 0.32))
	await _frames(6)
	_check("with a part in hand a double tap is two taps: two put down (%d parts, was %d), none turned"
		% [_world.brick_count(), count], _world.brick_count() == count + 2)
	_verbs.call("put_away")
	_builder.held_part = ""
	_verbs.set_mode("select")
	await _frames(4)

	# Select's adding on: each tap adds or takes out.
	await _fresh_model()
	before = _store.to_text()
	_verbs.adding = true
	id = _top_brick()
	await _double_tap(_camera.screen_of(_world.get_brick(id).transform.origin))
	await _frames(6)
	_check("with Select's adding on a double tap adds the part and takes it out (%d selected), none turned"
		% _builder.selection.size(), _store.to_text() == before and _builder.selection.is_empty())
	_verbs.adding = false
	await _shot("double_tap")


# -- 5. no false fires ------------------------------------------------------------


func _no_false_fires() -> void:
	if not await _open(CAR):
		return
	var before: String = _store.to_text()
	var depth: int = _builder.history_depth()
	var said_before: Dictionary = _camera.taps_said.duplicate()
	var room: Rect2 = _camera.seen_rect()
	var least: float = INF
	var kinds: Dictionary = {"turn": 0, "pinch": 0, "twist": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1119
	var per_point: float = Phone.per_point(root) / maxf(ShellPrefs.interface_size(), 0.01)
	for n: int in 100:
		var kind: String = ["turn", "pinch", "twist"][n % 3]
		kinds[kind] += 1
		# From a flick of 2 frames to a slow 24, as far as a person goes.
		var steps: int = [2, 3, 4, 6, 10, 16, 24][n % 7]
		var middle: Vector2 = room.get_center() + Vector2(rng.randf_range(-0.2, 0.2) * room.size.x,
			rng.randf_range(-0.2, 0.2) * room.size.y)
		var apart: float = rng.randf_range(0.12, 0.3) * minf(room.size.x, room.size.y)
		var way: Vector2 = Vector2.from_angle(rng.randf_range(0.0, TAU))
		var reach: float = rng.randf_range(40.0, 160.0) * per_point * 0.5
		var path: Callable
		match kind:
			"turn":
				var by: Vector2 = Vector2.from_angle(rng.randf_range(0.0, TAU)) * reach * 2.0
				path = func(t: float) -> Array:
					return [middle - way * apart + by * t, middle + way * apart + by * t]
			"pinch":
				var spread: float = (apart + reach * (1.0 if n % 2 == 0 else -0.6)) / apart
				path = func(t: float) -> Array:
					var now: float = apart * lerpf(1.0, spread, t)
					return [middle - way * now, middle + way * now]
			"twist":
				var degrees: float = rng.randf_range(25.0, 120.0) * (1.0 if n % 2 == 0 else -1.0)
				path = func(t: float) -> Array:
					var turned: Vector2 = way.rotated(deg_to_rad(degrees * t)) * apart
					return [middle - turned, middle + turned]
		var start: Array = path.call(0.0)
		var end: Array = path.call(1.0)
		var went: float = maxf((start[0] as Vector2).distance_to(end[0]),
			(start[1] as Vector2).distance_to(end[1])) / per_point
		least = minf(least, went)
		await _two(path, steps)
	var said: Dictionary = {}
	for key: String in _camera.taps_said:
		said[key] = int(_camera.taps_said[key]) - int(said_before[key])
	print("  measure false_fires %s steps %d->%d kinds %s least_points %.1f" % [said,
		depth, _builder.history_depth(), kinds, least])
	_check("100 gestures (%d turns, %d pinches, %d twists) said no tap of two, of three or double (%s)"
		% [kinds["turn"], kinds["pinch"], kinds["twist"], said],
		int(said["two"]) == 0 and int(said["three"]) == 0 and int(said["double"]) == 0)
	_check("...0 undos: the car byte for byte as it was, its steps as they were (%d, was %d)"
		% [_builder.history_depth(), depth], _store.to_text() == before and _builder.history_depth() == depth)
	_check("...the least any finger went was %.1f points, past a tap's %.0f" % [least, CadCamera.TAP_POINTS],
		least > CadCamera.TAP_POINTS)
	await _shot("car_after_100")


# -- 6. the keys sheet ----------------------------------------------------------


## Help, Keys and controls names the three under Building on a phone; and
## two fingers tapped while it is up are its, the model as it was.
func _in_the_keys_sheet() -> void:
	await _fresh_model()
	_builder.select_brick(_top_brick(), false)
	(_main.get("_shell") as Shell).run("delete")
	await _frames(8)
	var before: String = _store.to_text()
	var depth: int = _builder.history_depth()
	(_main.get("_shell") as Shell).run("keys")
	await _frames(20)
	var sheet: Control = _main.get("_controls") as Control
	var found: Dictionary = {}
	for label: Node in sheet.find_children("*", "Label", true, false):
		var words: String = (label as Label).text
		for want: String in ["2-finger tap", "3-finger tap", "double-tap"]:
			if words.contains(want) and (label as Control).is_visible_in_tree():
				found[want] = (label as Control).get_global_rect().end.y
	var down: float = root.get_visible_rect().size.y
	var in_sight: bool = found.values().all(func(y: float) -> bool: return y <= down)
	print("  measure keys_rows %s of %.0f" % [found, down])
	_check("Keys and controls names the 2-finger tap, the 3-finger tap and the double-tap (%s), in sight as it opens"
		% ", ".join(found.keys()), found.size() == 3 and in_sight)
	await _shot("keys_sheet")
	await _tap([_spot(-0.2, 0.0), _spot(0.2, 0.0)])
	await _frames(8)
	_check("...two fingers tapped with it up are its: the model as it was (%d steps, was %d), still up"
		% [_builder.history_depth(), depth],
		_store.to_text() == before and _builder.history_depth() == depth and sheet.is_visible_in_tree())
	sheet.hide()
	await _frames(6)


# -- fingers ---------------------------------------------------------------------


## Two places along the top bar at height [param y], each in the middle of
## a gap at least 12 units wide between the bar's visible buttons and
## fields, the two gaps nearest the window's middle; fewer when there are
## not two.
func _bar_gaps(y: float) -> Array:
	var taken: Array = []
	var stack: Array = [_phone]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if not (control is BaseButton or control is LineEdit):
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.position.y <= y and rect.end.y >= y:
			taken.append(Vector2(rect.position.x, rect.end.x))
	var across: float = root.get_visible_rect().size.x
	var gaps: Array = []
	var x: float = 0.0
	var run: float = -1.0
	while x <= across:
		var over: bool = false
		for span: Vector2 in taken:
			if x >= span.x - 2.0 and x <= span.y + 2.0:
				over = true
		if not over and run < 0.0:
			run = x
		if (over or x + 1.0 > across) and run >= 0.0:
			if x - run >= 12.0:
				gaps.append((run + x) * 0.5)
			run = -1.0
		x += 1.0
	gaps.sort_custom(func(a: float, b: float) -> bool:
		return absf(a - across * 0.5) < absf(b - across * 0.5))
	return gaps.slice(0, 2)


## Fingers down together, each wobbling 2 units as a fingertip does, and up
## a frame later: a tap of as many as [param at].
func _tap(at: Array) -> void:
	for n: int in at.size():
		_touch(n, at[n], true)
	await process_frame
	for n: int in at.size():
		_drag(n, (at[n] as Vector2) + WOBBLE, WOBBLE)
	await process_frame
	for n: int in at.size():
		_touch(n, (at[n] as Vector2) + WOBBLE, false)
	await process_frame
	await process_frame


## Two taps of one finger, a frame apart: the time between the first lifting
## and the second coming down, in ms.
func _double_tap(at: Vector2) -> int:
	_touch(0, at, true)
	await process_frame
	_drag(0, at + WOBBLE, WOBBLE)
	_touch(0, at + WOBBLE, false)
	var up: int = Time.get_ticks_msec()
	await process_frame
	var gap: int = Time.get_ticks_msec() - up
	var second: Vector2 = at + Vector2(3.0, 1.0)
	_touch(0, second, true)
	await process_frame
	_drag(0, second + WOBBLE, WOBBLE)
	_touch(0, second + WOBBLE, false)
	await process_frame
	await process_frame
	return gap


## Two fingers down where [param path] starts, moved along it a frame at a
## time, both each frame, and lifted (twist_probe's).
func _two(path: Callable, steps: int) -> void:
	var at: Array = path.call(0.0)
	_touch(0, at[0], true)
	_touch(1, at[1], true)
	await process_frame
	for n: int in steps:
		var to: Array = path.call(_eased(n + 1, steps))
		for index: int in 2:
			_drag(index, to[index], (to[index] as Vector2) - (at[index] as Vector2))
		at = to
		await process_frame
	for index: int in 2:
		_touch(index, at[index], false)
	await process_frame
	await process_frame


static func _eased(step: int, steps: int) -> float:
	return smoothstep(0.0, 1.0, float(step) / steps)


func _touch(index: int, at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _drag(index: int, at: Vector2, by: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = _as_event(at)
	drag.relative = _as_event(by)
	Input.parse_input_event(drag)


## A point in the viewport's units as the window hands it over.
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


## A point of the model's room, [param x] and [param y] shares of it from
## its middle.
func _spot(x: float, y: float) -> Vector2:
	var room: Rect2 = _camera.seen_rect()
	return room.get_center() + Vector2(x * room.size.x, y * room.size.y * 0.5)


# -- the model ----------------------------------------------------------------------


## Two 2 x 4 bricks crossed in the middle of the view, nothing selected and
## nothing to undo.
func _fresh_model() -> void:
	_main.call("clear_model")
	await _frames(4)
	for brick: Array in [["3001", 4, Basis.IDENTITY, Vector3(0, 24, 0)],
			["3001", 1, Basis(Vector3.UP, PI * 0.5), Vector3(0, 48, 0)]]:
		var where := Transform3D(brick[2] as Basis, brick[3] as Vector3)
		var id: int = _world.add_brick(brick[0], brick[1], where)
		_builder.register(id, brick[0], where)
	_builder.clear_selection()
	_builder.forget_history()
	_builder.locked.clear()
	_camera.set_view("default")
	_camera.frame(AABB(Vector3(-160, 0, -160), Vector3(320, 72, 320)))
	await _settle()


func _open(path: String) -> bool:
	var real: String = ProjectSettings.globalize_path(path)
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", real)
	for _n: int in 900:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0 and not _store.laying:
			break
	await _frames(30)
	_builder.clear_selection()
	_camera.set_view("default")
	await _settle()
	return _check("%s open (%d parts)" % [path.get_file(), _world.brick_count()], _world.brick_count() > 0)


## The highest part, by where it stands: the one a finger finds on top.
func _top_brick() -> int:
	var best: int = 0
	var high: float = -INF
	for id: int in _world._bricks:
		var y: float = _world.get_brick(id).transform.origin.y
		if y > high:
			high = y
			best = id
	return best


func _lowest_brick() -> int:
	var best: int = 0
	var low: float = INF
	for id: int in _world._bricks:
		var y: float = _world.get_brick(id).transform.origin.y
		if y < low:
			low = y
			best = id
	return best


## Every part where it is, and the selected ones, in order (twist_probe's).
func _parts() -> Array:
	var placed: Array = []
	var chosen: Array = []
	for id: int in _world._bricks:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		var said: String = "%s %s" % [brick.part_id, brick.transform]
		placed.append(said)
		if _builder.selection.has(id):
			chosen.append(said)
	placed.sort()
	chosen.sort()
	return [placed, chosen]


## How many part lines a model's text has.
static func _lines(text: String) -> int:
	var count: int = 0
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("1 "):
			count += 1
	return count


# -- what was said, the bar's buttons ------------------------------------------------


func _tool(what: String) -> Control:
	return (_phone.get("_tool_buttons") as Dictionary).get(what)


## The line the phone shows for a few seconds after something is said.
func _said() -> String:
	return str(_phone.get("_said")) if Time.get_ticks_msec() < int(_phone.get("_said_until")) else ""


func _say_nothing() -> void:
	_phone.set("_said", "")
	_phone.set("_said_until", 0)


## Frames until the camera stops, and one drawn (twist_probe's).
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
	var dir: String = "res://shots/phonefingers/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var window: Vector2i = DisplayServer.window_get_size()
	root.get_texture().get_image().save_png("%s%dx%d_%s_%s.png" % [dir, window.x, window.y, _layout, name])
