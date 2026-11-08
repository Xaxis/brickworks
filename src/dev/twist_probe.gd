## Two fingers turned about each other turn the view round the up, on a phone
## (docs/APP_UX6.md, unit twist).
##
##   godot --path . --resolution 390x844 --script src/dev/twist_probe.gd
##   PROBE_SIZE=1024x768 tools/probe.sh twist_probe --tablet     a tablet's layout
##   PROBE_SIZE=1280x720 tools/probe.sh twist_probe              the desktop's, any wider window
##
## The view turned, slid and zoomed under fingers, and two fingers turned
## about each other did nothing, where a map, a photo and LeoCAD turn with
## them. In the app laid out for a phone (a tablet's, or the desktop's with a
## touchscreen, by the window and --tablet), by fingers as the window hands
## them over, a frame at a time, each finger starting and stopping at rest as
## a person's does:
##   1. two fingers turned a quarter turn about the model turn the view 90°
##      ±5° round the up, its tilt as it was within 0.5°, and what was
##      between them still between them; the model as it was;
##   2. seen from above and from below, the model turns the way the fingers
##      went round on the screen, and the view still looks straight down or up;
##   3. a pinch, two fingers slid together and one finger's drag do what they
##      did before the twist, within 1% (SAME, measured on pre261 3f13e35f),
##      and a pinch turns nothing, nor does one whose fingers turn 6° as they
##      spread (pre261 turned the view by the first finger's way: the pointer
##      the engine raises from it);
##   4. a quarter turn and a spread at once, as a hand makes them: both;
##   5. two fingers with the first on a part (unit touchfix): a twist turns
##      the view and a pinch zooms it, the part neither carried off nor
##      selected; the first finger slipped past a carry's start before the
##      second came down, the part back where it was and the selection as it
##      was; a pinch whose first finger stays still on the ground lets go of
##      nothing; and one finger dragged on a part still carries it (pre261
##      carried the part off with the first finger and selected it);
##   6. on a phone's and a tablet's layout (TouchSizing), a dialog freed
##      while it was open leaves the next dialog laid out for a finger and its
##      field the one typed in (pre261 raised a script error over the freed
##      one and laid out nothing after it).
## Every gesture leaves the model as it was. Pictures before and after the
## turn in shots/twist/. Exits non-zero when a check fails.
extends SceneTree

const SHOTS := "res://shots/twist/"

## What a pinch, a slide and a drag did on pre261 (3f13e35f), before the twist,
## by whose fingers: a phone's and a tablet's (the camera's phone) or the
## desktop's. The pinch as the share of the distance left, the slide and the
## drag on a phone as degrees turned round the up, the slide on the desktop as
## how far the model moved on the screen, in the window's units.
const SAME := {
	"phone": {"pinch": 1.0 / 3.0, "slide": -82.244, "drag": -82.244},
	"desktop": {"pinch": 1.0 / 3.0, "slide": 152.107, "drag": -82.245},
}
## How far the fingers slide and a finger drags, in the window's units.
const TRAVEL := 150.0

var _failures: int = 0
var _main: Node
var _camera: CadCamera
var _world: BrickWorld
var _builder: Builder
var _verbs: EditVerbs
## Where the view was headed, as the camera aims (radians, not wrapped), as
## the second finger came down (_two).
var _yaw_at_second: float = 0.0
var _layout: String = "phone"
var _size: String = ""
var _home: Dictionary = {}
## Every part where it was put and nothing selected (_parts).
var _built: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("twist_probe: needs a window")
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	var tablet: bool = OS.get_cmdline_user_args().has("--tablet")
	_layout = "tablet" if tablet else ("phone" if mini(window.x, window.y) < int(Phone.NARROW)
		else "desktop")
	Phone._on = 0 if _layout == "desktop" else 1
	Phone._wide = tablet
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	# A phone draws at a browser's scale, as open_menu_reach_probe holds it.
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
	var room: Rect2 = _camera.seen_rect()
	print("twist_probe: a %s window, laid out for a %s; the model seen in %d x %d units"
		% [_size, _layout, roundi(room.size.x), roundi(room.size.y)])
	_check("the camera takes fingers as %s" % ("a phone's" if _layout != "desktop"
		else "the desktop's"), _camera.phone == (_layout != "desktop"))

	await _fresh_model()
	_built = _parts()
	_camera.set_view("default")
	_camera.frame(AABB(Vector3(-160, 0, -160), Vector3(320, 72, 320)))
	await _settle()
	_home = _camera.aim()

	print("\n1. two fingers turned a quarter turn about the model")
	await _turned_a_quarter()
	print("\n2. seen from above and from below, the model turns as the fingers went")
	await _as_the_fingers("top")
	await _as_the_fingers("bottom")
	print("\n3. a pinch, a slide and a drag, as before")
	await _as_before()
	print("\n4. a quarter turn and a spread at once")
	await _turn_and_spread()
	print("\n5. two fingers with the first on a part")
	await _on_a_part()
	print("\n6. a dialog freed while it was open, then the next")
	await _after_a_freed_dialog()

	print("\ntwist_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


# -- the bar -------------------------------------------------------------------


func _turned_a_quarter() -> void:
	await _go_home()
	var room: Rect2 = _camera.seen_rect()
	var middle: Vector2 = room.get_center()
	var under: Vector3 = _camera.call("_under", middle)
	var heading: float = _heading()
	var tilt: float = _tilt()
	var parts: Array = _parts()
	await _shot("1_before")
	await _two(_turning(middle, _reach(), 90.0))
	await _shot("2_turned")
	var turned: float = _turned(heading, _heading())
	print("  measure twist %.3f" % turned)
	_check("two fingers turned a quarter turn clockwise turn the view %.1f° round the up (90 ±5)"
		% turned, absf(absf(turned) - 90.0) <= 5.0)
	_check("...its tilt as it was (%.2f° to %.2f°)" % [tilt, _tilt()], absf(_tilt() - tilt) <= 0.5)
	var off: float = _camera.screen_of(under).distance_to(middle)
	_check("...round what was between the fingers, still between them (%.1f units off, %d at most)"
		% [off, roundi(_slack())], off <= _slack())
	_check("...and the model is as it was, nothing selected", _parts() == parts)

	# The other way, from where it ended: back where it began.
	await _two(_turning(middle, _reach(), -90.0))
	var back: float = _turned(heading, _heading())
	_check("turned back a quarter turn the other way, the view is back (%.1f° from it)" % back,
		absf(back) <= 2.0)
	_check("...the model as it was", _parts() == parts)


## Seen from above or below: a point of the model beside the one between the
## fingers goes round on the screen as the fingers went round, a quarter turn
## clockwise.
func _as_the_fingers(view: String) -> void:
	await _go_home()
	_camera.set_view(view)
	await _settle()
	var middle: Vector2 = _camera.seen_rect().get_center()
	var at: Vector3 = _camera.call("_under", middle)
	var beside: Vector3 = at + Vector3(60, 0, 0)
	var was: float = (_camera.screen_of(beside) - _camera.screen_of(at)).angle()
	var tilt: float = _tilt()
	await _two(_turning(middle, _reach(), 90.0))
	if view == "top":
		await _shot("3_from_above_turned")
	var now: float = (_camera.screen_of(beside) - _camera.screen_of(at)).angle()
	var went: float = rad_to_deg(angle_difference(was, now))
	print("  measure %s %.3f" % [view, went])
	_check("from %s, the model went %.1f° round on the screen as the fingers went 90° clockwise (±5)"
		% ["above" if view == "top" else "below", went], absf(went - 90.0) <= 5.0)
	_check("...and the view looks as straight %s as it did (%.2f° to %.2f°)" % [
		"down" if view == "top" else "up", tilt, _tilt()], absf(_tilt() - tilt) <= 0.5)


func _as_before() -> void:
	var same: Dictionary = SAME["desktop" if _layout == "desktop" else "phone"]
	var middle: Vector2 = _camera.seen_rect().get_center()
	var reach: float = _reach() * 0.4

	await _go_home()
	var far: float = _camera.distance_now()
	var heading: float = _heading()
	await _two(_turning(middle, reach, 0.0, 3.0))
	var pinch: float = _camera.distance_now() / far
	print("  measure pinch %.6f" % pinch)
	_check("a pinch spread three times as wide leaves %.4f of the distance (%.4f before, ±1%%)"
		% [pinch, same["pinch"]], _within(pinch, same["pinch"]))
	_check("...and turns nothing (%.3f°), the model as it was" % _turned(heading, _heading()),
		absf(_turned(heading, _heading())) <= 0.05 and _parts() == _built)

	await _go_home()
	heading = _heading()
	await _two(_turning(middle, reach, 6.0, 3.0))
	var sloppy: float = _camera.distance_now() / far
	var turned: float = _turned(heading, _heading())
	print("  measure sloppy %.6f %.3f" % [sloppy, turned])
	_check("a pinch whose fingers turn 6° as they spread zooms as far (%.4f) and turns nothing (%.3f°)"
		% [sloppy, turned], _within(sloppy, same["pinch"]) and absf(turned) <= 0.05
		and _parts() == _built)

	await _go_home()
	heading = _heading()
	var was: Vector3 = _camera.focus_now()
	var seen_at: Vector2 = _camera.screen_of(was)
	var slide := Vector2(TRAVEL, 0)
	await _two(func(t: float) -> Array:
		return [middle - Vector2(reach * 2.0, 0) + slide * t, middle + Vector2(reach * 2.0, 0) + slide * t])
	if _layout == "desktop":
		var moved: float = _camera.screen_of(was).x - seen_at.x
		print("  measure slide %.3f" % moved)
		_check("two fingers slid %d units slide the model %.2f units (%.2f before, ±1%%)" % [
			roundi(TRAVEL), moved, same["slide"]], _within(moved, same["slide"]) and _parts() == _built)
	else:
		var round_up: float = _turned(heading, _heading())
		print("  measure slide %.3f" % round_up)
		_check("two fingers slid %d units turn the view %.2f° (%.2f° before, ±1%%)" % [
			roundi(TRAVEL), round_up, same["slide"]], _within(round_up, same["slide"])
			and _parts() == _built)

	# One finger beside the model, on nothing, so it is the view's.
	await _go_home()
	heading = _heading()
	var low: Vector2 = middle + Vector2(-TRAVEL * 0.5, _reach() * 1.1)
	await _one(low, low + Vector2(TRAVEL, 0))
	var dragged: float = _turned(heading, _heading())
	print("  measure drag %.3f" % dragged)
	_check("one finger dragged %d units turns the view %.2f° (%.2f° before, ±1%%)" % [
		roundi(TRAVEL), dragged, same["drag"]], _within(dragged, same["drag"]) and _parts() == _built)


func _turn_and_spread() -> void:
	await _go_home()
	var middle: Vector2 = _camera.seen_rect().get_center()
	var far: float = _camera.distance_now()
	var heading: float = _heading()
	await _two(_turning(middle, _reach() * 0.6, 90.0, 2.0))
	var turned: float = _turned(heading, _heading())
	var left: float = _camera.distance_now() / far
	print("  measure both %.3f %.6f" % [turned, left])
	_check("turned a quarter turn as they spread twice as wide: %.1f° (90 ±5), %.4f of the distance (0.5000 ±1%%)"
		% [turned, left], absf(absf(turned) - 90.0) <= 5.0 and _within(left, 0.5)
		and _parts() == _built)


## Two 2 x 4 bricks crossed, framed small in the middle, so the fingers come
## down round the model and the point between them is on it, nothing
## selected. The example car a first visit opens is taken off first.
func _fresh_model() -> void:
	_main.call("clear_model")
	await _frames(4)
	for brick: Array in [["3001", 4, Basis.IDENTITY, Vector3(0, 24, 0)],
			["3001", 1, Basis(Vector3.UP, PI * 0.5), Vector3(0, 48, 0)]]:
		var where := Transform3D(brick[2] as Basis, brick[3] as Vector3)
		var id: int = _world.add_brick(brick[0], brick[1], where)
		_builder.register(id, brick[0], where)
	_builder.clear_selection()


## The fingers on the model itself, the first on a part, as a twist or a pinch
## on a small screen often is: the view's, and the model as it was. Each
## gesture on the model made afresh, so one that moved a part (pre261) leaves
## the next as it would find it.
func _on_a_part() -> void:
	await _go_home()
	var middle: Vector2 = _camera.seen_rect().get_center()
	var near: float = _reach() * 0.15
	var first: Vector2 = (_turning(middle, near, 90.0).call(0.0) as Array)[0]
	var under: int = _verbs.brick_at(first)
	_check("the first finger comes down on a part (%s)" % ("part %d" % under if under != 0
		else "the ground"), under != 0)

	# Each gesture judged against the model as it was just before it.
	var before: Array = _parts()
	var heading: float = _heading()
	await _two(_turning(middle, near, 90.0))
	var turned: float = _turned(heading, _heading())
	print("  measure on_part_twist %.3f %s" % [turned, _moved(before)])
	_check("a quarter twist begun on a part turns the view %.1f° (90 ±5), the model as it was (%s)"
		% [turned, _moved(before)], absf(absf(turned) - 90.0) <= 5.0 and _parts() == before)

	await _fresh_model()
	await _go_home()
	before = _parts()
	var far: float = _camera.distance_now()
	await _two(_turning(middle, near, 0.0, 3.0))
	var left: float = _camera.distance_now() / far
	print("  measure on_part_pinch %.6f %s" % [left, _moved(before)])
	_check("a pinch begun on a part zooms (%.4f of the distance, 0.3333 ±1%%), the model as it was (%s)"
		% [left, _moved(before)], _within(left, 1.0 / 3.0) and _parts() == before)

	# The first finger on its way before the second comes down, past where a
	# drag carries the part (Main.DRAG_SLOP, 5): a hand that lands unevenly.
	await _fresh_model()
	await _go_home()
	before = _parts()
	var slip := Vector2(-12.0, 0.0)
	var path: Callable = _turning(middle, near, 90.0)
	# The line between them turns less than 90° with the first finger 12
	# units out: as far as that, the view.
	var lines: Array = []
	for t: float in [0.0, 1.0]:
		var both: Array = path.call(t)
		lines.append(((both[1] as Vector2) - ((both[0] as Vector2) + slip)).angle())
	var wanted: float = absf(rad_to_deg(angle_difference(lines[0], lines[1])))
	await _two(path, 24, slip)
	# From the second finger on: the first finger alone turns the view on
	# the desktop's layout, as one finger does there.
	turned = absf(rad_to_deg(float(_camera.get("_target_yaw")) - _yaw_at_second))
	print("  measure slipped_twist %.3f %.3f %s" % [turned, wanted, _moved(before)])
	_check("...the first finger 12 units on before the second comes down: %.1f° from then (the fingers' %.1f ±5), the part back where it was and the selection as it was (%s)"
		% [turned, wanted, _moved(before)], absf(turned - wanted) <= 5.0 and _parts() == before)

	# A part selected, and a pinch whose first finger stays still on the
	# ground while the second spreads from it: no click, nothing let go of.
	await _fresh_model()
	await _go_home()
	var kept: int = int(_world._bricks.keys().min())
	_builder.select_brick(kept, false)
	var chosen: Array = _parts()
	var ground: Vector2 = middle + Vector2(0.0, _reach())
	_check("...the ground there has no part on it", _verbs.brick_at(ground) == 0)
	var spread_from: Callable = func(t: float) -> Array:
		return [ground, ground + Vector2(near * lerpf(1.0, 3.0, t), 0.0)]
	await _two(spread_from)
	print("  measure still_pinch %s" % [_builder.selection.keys()])
	_check("a pinch whose first finger stays still on the ground keeps the selection (%s, was [%d]) and the model"
		% [_builder.selection.keys(), kept], _parts() == chosen)
	_builder.clear_selection()

	# One finger: the part is carried, as before.
	await _fresh_model()
	await _go_home()
	before = _parts()
	await _one(first, first + Vector2(0.0, 60.0))
	print("  measure one_finger %s" % _moved(before))
	_check("one finger dragged 60 units on a part still carries it (%s)" % _moved(before),
		_moved_count(before) > 0)


## How many parts are not where [param before] had them, and how many are
## selected, in words.
func _moved(before: Array) -> String:
	return "%d parts moved, %d selected" % [_moved_count(before), _builder.selection.size()]


func _moved_count(before: Array) -> int:
	var placed: Array = (_parts()[0] as Array).duplicate()
	var moved: int = 0
	for said: String in before[0]:
		if said in placed:
			placed.erase(said)
		else:
			moved += 1
	return moved


## A dialog freed while it is open, then another dialog with a field: laid
## out for a finger and typed in. A window or a panel freed while it shows
## never says it hid, so TouchSizing still lists it; Godot's Cancel hides its
## dialog before SaveTo frees it, so a Save dialog cancelled is not one.
func _after_a_freed_dialog() -> void:
	var touch: TouchSizing = _main.get("_touch")
	if touch == null:
		print("  (the desktop's layout lays dialogs out as the desktop does: nothing to check)")
		return
	var gone := AcceptDialog.new()
	gone.dialog_text = "Freed while it is open"
	root.add_child(gone)
	gone.popup_centered()
	await _frames(10)
	gone.queue_free()
	await _frames(4)
	var freed: int = 0
	for item: Variant in touch.get("_open"):
		if not is_instance_valid(item):
			freed += 1
	print("  measure freed_open %d" % freed)
	_check("...a dialog freed while open is still listed (%d), as a person's would be" % freed, freed > 0)

	var asked := AcceptDialog.new()
	asked.title = "Name"
	var field := LineEdit.new()
	asked.add_child(field)
	root.add_child(asked)
	asked.popup_centered(Vector2i(300, 120))
	await _frames(2)
	field.grab_focus()
	await _frames(10)
	var placed: bool = asked.has_meta(&"touch_placed")
	var typed: Control = touch.typing()
	_check("the next dialog is laid out for a finger (%s) and its field is the one typed in (%s)"
		% ["laid out" if placed else "not laid out", "it" if typed == field else str(typed)],
		placed and typed == field)
	asked.queue_free()
	await _frames(4)


# -- fingers ---------------------------------------------------------------------


## Two fingers about [param middle], [param reach] from it each, turned
## [param degrees] clockwise on the screen as the share of the way goes 0 to 1,
## and spread [param spread] times as wide.
func _turning(middle: Vector2, reach: float, degrees: float, spread: float = 1.0) -> Callable:
	return func(t: float) -> Array:
		var way: Vector2 = Vector2.from_angle(deg_to_rad(degrees * t)) * reach * lerpf(1.0, spread, t)
		return [middle - way, middle + way]


## How far each finger is from the point between them: well off the model.
func _reach() -> float:
	var room: Vector2 = _camera.seen_rect().size
	return 0.3 * minf(room.x, room.y)


## How far what was between the fingers may end from it: 2% of the room.
func _slack() -> float:
	var room: Vector2 = _camera.seen_rect().size
	return 0.02 * minf(room.x, room.y)


## Two fingers down where [param path] starts, moved along it a frame at a
## time, both each frame, and lifted. With [param early], the first goes that
## far on its own, a frame at a time, before the second comes down.
func _two(path: Callable, steps: int = 24, early: Vector2 = Vector2.ZERO) -> void:
	var at: Array = path.call(0.0)
	_touch(0, at[0], true)
	if early != Vector2.ZERO:
		await process_frame
		var from: Vector2 = at[0]
		for n: int in 6:
			var next: Vector2 = from + early * _eased(n + 1, 6)
			_drag(0, next, next - (at[0] as Vector2))
			at[0] = next
			await process_frame
		var slipped: Vector2 = at[0] - from
		var moved_path: Callable = path
		path = func(t: float) -> Array:
			var both: Array = moved_path.call(t)
			return [(both[0] as Vector2) + slipped, both[1]]
	_yaw_at_second = float(_camera.get("_target_yaw"))
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
	await _settle()


func _one(from: Vector2, to: Vector2, steps: int = 24) -> void:
	_touch(0, from, true)
	await process_frame
	var at: Vector2 = from
	for n: int in steps:
		var next: Vector2 = from.lerp(to, _eased(n + 1, steps))
		_drag(0, next, next - at)
		at = next
		await process_frame
	_touch(0, to, false)
	await _settle()


## How far along the way a finger is after [param step] of [param steps]:
## from rest to rest, as a hand moves, not at an even pace from its first
## event (whose first move is then as long as any).
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


# -- measuring -------------------------------------------------------------------


## Which way the eye looks round the up, in degrees, from the camera as drawn.
func _heading() -> float:
	var ahead: Vector3 = -_camera.global_transform.basis.z
	return rad_to_deg(atan2(ahead.x, ahead.z))


## How far the eye looks down, in degrees.
func _tilt() -> float:
	var ahead: Vector3 = -_camera.global_transform.basis.z.normalized()
	return rad_to_deg(asin(clampf(-ahead.y, -1.0, 1.0)))


static func _turned(from: float, to: float) -> float:
	return rad_to_deg(angle_difference(deg_to_rad(from), deg_to_rad(to)))


static func _within(value: float, wanted: float) -> bool:
	return absf(value - wanted) <= absf(wanted) * 0.01


## Every part where it is, and the selected ones, each as its part and
## where it is, in order: not by id, as a part carried and put back comes
## back as another id (Builder._renumbered), where it was.
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


## The view the model was framed in, each gesture from there.
func _go_home() -> void:
	_camera.aim_at(_home)
	await _settle()


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
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	root.get_texture().get_image().save_png("%s%s_%s_%s.png" % [SHOTS, _size, _layout, name])
