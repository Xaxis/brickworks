## A list thrown by a finger glides as far as a phone's does, and no further.
##
##   godot --headless --path . --script src/dev/fling_probe.gd
##
## fling272 (2026-10-25): first258 saw a medium 434-point drag on More's
## list, lifted while it was moving, glide 8,500 points, the whole list end
## to end. Godot's ScrollContainer slows a throw by a fixed 1,000 units a
## second every second, so its glide grows as the square of the speed it
## was thrown at; a thumb expects a phone's, which grows with the speed:
## iOS's UIScrollView slows a throw by 0.2% a millisecond ("normal"
## deceleration, 0.998 a ms), so it glides as far as about 500 ms of the
## speed it was thrown at.
##
## Here a list in a ScrollContainer, as every list and panel the app scrolls
## is one, is dragged by a finger (a mouse that stands for one, as the web
## build's touches do) at 0.5, 1, 2 and 4 points a millisecond and lifted
## while moving, with a point as many units as a phone's (720 across 390
## points) and as a tablet's (720 across 768). Each glide must be within 25%
## of iOS's for that speed; a slow drag must keep under the finger, a point
## for a point; and a drag held still 200 ms before it lifts must not glide.
## With the app's own handling of a throw (FlingScroll) where the build has
## it: on a build without, Godot's glide is measured.
extends SceneTree

## How fast each throw is, points a millisecond.
const SPEEDS: Array[float] = [0.5, 1.0, 2.0, 4.0]
## iOS's normal deceleration, a millisecond.
const IOS := 0.998
const SLACK := 0.25
## How many units a point is: a phone's, and a tablet's.
const SCALES: Dictionary = {"phone": 720.0 / 390.0, "tablet": 720.0 / 768.0}
## How long each drag moves before it lifts, ms, at the most: a fast one
## for as long as its 1,400 units of room take.
const DRAG_MS := 240.0

var _failures: int = 0
var _scroll: ScrollContainer
var _at := Vector2(200, 300)


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	await process_frame
	Engine.max_fps = 60
	# A finger, as the web build's touches are: a ScrollContainer drags only
	# where the screen is touched.
	Input.emulate_touch_from_mouse = true
	print("── a list thrown by a finger (touch %s) ──" % ("on" if DisplayServer.is_touchscreen_available()
		else "OFF"))
	var fling_path := "res://src/ui/fling_scroll.gd"
	if ResourceLoader.exists(fling_path):
		root.add_child((load(fling_path) as GDScript).new())
		print("    with the app's FlingScroll")
	else:
		print("    with Godot's own glide: this build has no FlingScroll")
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2.ZERO
	_scroll.size = Vector2(400, 1600)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(list)
	for n: int in 700:
		var row := Button.new()
		row.text = "Row %d" % n
		row.custom_minimum_size = Vector2(380, 100)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		list.add_child(row)
	root.add_child(_scroll)
	await _frames(10)
	_check("the list is longer than its room: %d units of %d" % [int(list.size.y), int(_scroll.size.y)],
		list.size.y > 40000.0)
	for named: String in SCALES:
		var k: float = SCALES[named]
		print("── %s: a point is %.2f units ──" % [named, k])
		for speed: float in SPEEDS:
			var got: Dictionary = await _throw(speed * k, 0.0)
			var glide: float = float(got["glide"]) / k
			var ios: float = speed / -log(IOS)
			var off: float = glide / ios - 1.0
			_check("thrown at %.1f pt/ms: glides %d points, iOS %d (%+d%%); under the finger %.2f a point" % [
				speed, roundi(glide), roundi(ios), roundi(off * 100.0), float(got["tracked"])],
				absf(off) <= SLACK and absf(float(got["tracked"]) - 1.0) <= 0.05)
		var held: Dictionary = await _throw(2.0 * k, 200.0)
		_check("held still 200 ms before it lifts: glides %.1f points" % (float(held["glide"]) / k),
			float(held["glide"]) / k < 1.0)
	print("fling probe: %s" % ("a throw glides as a phone's does" if _failures == 0
		else "%d checks failed" % _failures))
	quit(1 if _failures > 0 else 0)


func _mouse(pressed: bool) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = pressed
	press.position = _at
	press.global_position = _at
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_send(press)


func _move(by: Vector2) -> void:
	_at += by
	var motion := InputEventMouseMotion.new()
	motion.position = _at
	motion.global_position = _at
	motion.relative = by
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	_send(motion)


## [param event] to the window, in its own units, as a person's finger
## comes: a headless window is 64 points and drawn 1,600 across.
func _send(event: InputEvent) -> void:
	root.push_input(event, true)


## A finger down on the list, dragged up at [param speed] units a ms for
## DRAG_MS, held still [param still] ms, and lifted: {glide: how far the
## list went on after it lifted, units; tracked: how far the list went for
## each unit the finger went while it was down}.
func _throw(speed: float, still: float) -> Dictionary:
	_scroll.scroll_vertical = 4000
	await _frames(20)
	_at = Vector2(200, 1550)
	_mouse(true)
	await _frames(2)
	var from: float = _scroll.scroll_vertical
	var moved: float = 0.0
	var last: int = Time.get_ticks_usec()
	var began: int = last
	# No further than the room it has: a finger stays on the screen.
	var drag_ms: float = minf(DRAG_MS, 1400.0 / speed)
	while (Time.get_ticks_usec() - began) / 1000.0 < drag_ms:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var step: float = speed * (now - last) / 1000.0
		last = now
		# The finger goes up the screen: the list's content comes with it.
		_move(Vector2(0, -step))
		moved += step
	await process_frame
	var still_from: int = Time.get_ticks_usec()
	while still > 0.0 and (Time.get_ticks_usec() - still_from) / 1000.0 < still:
		await process_frame
	var tracked: float = (_scroll.scroll_vertical - from) / moved if moved > 0.0 else 0.0
	var lifted: float = _scroll.scroll_vertical
	_mouse(false)
	var was: int = _scroll.scroll_vertical
	var same: int = 0
	var waited: int = Time.get_ticks_msec()
	while same < 30 and Time.get_ticks_msec() - waited < 20000:
		await process_frame
		same = same + 1 if _scroll.scroll_vertical == was else 0
		was = _scroll.scroll_vertical
	return {"glide": absf(_scroll.scroll_vertical - lifted), "tracked": tracked}
