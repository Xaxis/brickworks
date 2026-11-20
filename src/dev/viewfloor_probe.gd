## Fingers never leave the view under the floor or lose the model (smalls10
## item 4), on a phone, 390 x 844:
##
##   godot --path . --resolution 390x844 --script src/dev/viewfloor_probe.gd
##   -- --measure     prints what each gesture left and fails nothing
##
## On the car and on Orthanc, each opened and seen from the default view: 100
## two-finger gestures (turns, pinches, twists and long pans, flicks to slow
## drags, from anywhere on the model's room), then a tap on Fit, then 100
## more, each as touch events the window hands over. After each, where the
## view is going (CadCamera.aim) is read: under the floor (the eye below the
## plane the model stands on, the model upright, so the floor shows), inside
## a part (the eye in a part's cover), and lost (none of the model's parts
## drawn in the room it is seen in, Main.parts_seen). And the mouse's own: a right drag of 800 pixels
## down, 40 wheel notches in, a slide of 3000 pixels and a turn begun far off
## the model, each from the default view on the car.
##
## The bar: no gesture and no Fit leaves the view under the floor or the model
## lost, on either model; the mouse is held by the same rule; the view cube's
## Bottom still looks from under the model, and a drag from there goes no
## further down. Exits non-zero when a check fails.
extends SceneTree

const CAR := "res://models/car.ldr"
const ORTHANC := "res://models/orthanc.ldr"

var _failures: int = 0
var _measure: bool = false
var _main: Node
var _camera: CadCamera
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _phone: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	if _measure:
		print("  %s  %s" % ["....", what])
		return ok
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("viewfloor_probe: needs a window")
		quit(1)
		return
	_measure = OS.get_cmdline_user_args().has("--measure")
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	Phone._on = 1
	Phone._wide = false
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
	_store = _main.get("_store")
	_store.keeps = false
	var window: Vector2i = DisplayServer.window_get_size()
	print("viewfloor_probe: a %dx%d window laid out for a phone" % [window.x, window.y])
	if not _check("the phone's layout is up, the camera taking fingers as a phone's",
			_phone != null and _camera.phone):
		quit(1)
		return

	var totals: Dictionary = {}
	for path: String in [CAR, ORTHANC]:
		print("\n%s: 100 gestures, Fit, 100 more" % path.get_file())
		totals[path.get_file()] = await _gestures(path)
	print("\nthe mouse, on the car")
	await _mouse()
	print("\nthe view cube's Bottom")
	await _bottom()

	print("\nviewfloor_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	print("viewfloor_probe totals %s" % JSON.stringify(totals))
	quit(1 if _failures else 0)


# -- fingers ------------------------------------------------------------------------


func _gestures(path: String) -> Dictionary:
	var out: Dictionary = {}
	if not await _open(path):
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = 1120
	for half: String in ["first", "after_fit"]:
		var counts: Dictionary = {"under": 0, "inside": 0, "lost": 0, "inside_box": 0, "looking_up": 0}
		var lowest: float = INF
		var worst: String = ""
		if half == "after_fit":
			var fit: Button = _phone.get("_fit")
			fit.pressed.emit()
			await _settle()
			var at_fit: Dictionary = _where()
			print("  measure %s fit: %s" % [path.get_file(), _words(at_fit)])
			_check("%s: Fit leaves the view %s" % [path.get_file(), _words(at_fit)],
				not bool(at_fit["under"]) and not bool(at_fit["lost"]))
		for n: int in 100:
			var kind: String = ["turn", "pinch", "twist", "pan"][n % 4]
			await _gesture(kind, n, rng)
			var now: Dictionary = _where()
			for key: String in counts:
				if bool(now[key]):
					counts[key] += 1
			if _measure and bool(now["lost"]) and int(counts["lost"]) <= 4:
				print("    lost after #%d %s: %s" % [n, kind, _words(now)])
			if float(now["eye_y"]) < lowest:
				lowest = float(now["eye_y"])
				worst = "#%d %s: %s" % [n, kind, _words(now)]
		print("  measure %s %s %s lowest eye %.1f LDU (%s)" % [path.get_file(), half,
			JSON.stringify(counts), lowest, worst])
		_check("%s, %s: 0 of 100 gestures under the floor (%d) or lost (%d); inside a part %d, looking up %d"
			% [path.get_file(), half.replace("_", " "), counts["under"], counts["lost"], counts["inside"],
				counts["looking_up"]], int(counts["under"]) == 0 and int(counts["lost"]) == 0)
		out[half] = counts
	await _shot(path.get_file().get_basename())
	return out


## One two-finger gesture of [param kind], somewhere on the model's room.
func _gesture(kind: String, n: int, rng: RandomNumberGenerator) -> void:
	var room: Rect2 = _camera.seen_rect()
	var steps: int = [2, 3, 4, 6, 10, 16, 24][n % 7]
	var middle: Vector2 = room.get_center() + Vector2(rng.randf_range(-0.3, 0.3) * room.size.x,
		rng.randf_range(-0.3, 0.3) * room.size.y)
	var apart: float = rng.randf_range(0.1, 0.3) * minf(room.size.x, room.size.y)
	var way: Vector2 = Vector2.from_angle(rng.randf_range(0.0, TAU))
	var reach: float = rng.randf_range(40.0, 220.0)
	var path: Callable
	match kind:
		"turn":
			var by: Vector2 = Vector2.from_angle(rng.randf_range(0.0, TAU)) * reach
			path = func(t: float) -> Array:
				return [middle - way * apart + by * t, middle + way * apart + by * t]
		"pan":
			# A long sweep of both fingers, mostly up or down the screen, as a
			# person drags a phone's view to look over or under the model.
			var by: Vector2 = Vector2(rng.randf_range(-0.3, 0.3), 1.0 if n % 8 < 4 else -1.0) \
				* rng.randf_range(0.4, 0.9) * room.size.y
			path = func(t: float) -> Array:
				return [middle - way * apart + by * t, middle + way * apart + by * t]
		"pinch":
			var spread: float = (apart + reach * (1.0 if n % 2 == 0 else -0.6)) / apart
			path = func(t: float) -> Array:
				var now: float = apart * lerpf(1.0, maxf(spread, 0.1), t)
				return [middle - way * now, middle + way * now]
		_:
			var degrees: float = rng.randf_range(25.0, 120.0) * (1.0 if n % 2 == 0 else -1.0)
			path = func(t: float) -> Array:
				var turned: Vector2 = way.rotated(deg_to_rad(degrees * t)) * apart
				return [middle - turned, middle + turned]
	await _two(path, steps)


func _two(path: Callable, steps: int) -> void:
	var at: Array = path.call(0.0)
	_touch(0, at[0], true)
	_touch(1, at[1], true)
	await process_frame
	for n: int in steps:
		var to: Array = path.call(smoothstep(0.0, 1.0, float(n + 1) / steps))
		for index: int in 2:
			_drag(index, to[index], (to[index] as Vector2) - (at[index] as Vector2))
		at = to
		await process_frame
	for index: int in 2:
		_touch(index, at[index], false)
	await process_frame
	await process_frame


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


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


# -- the mouse ----------------------------------------------------------------------


func _mouse() -> void:
	if not await _open(CAR):
		return
	var centre: Vector2 = _camera.seen_rect().get_center()
	# A right drag straight down the screen: the view tips over the model
	# and under it, as far as the drag goes.
	_camera.begin_drag(MOUSE_BUTTON_RIGHT, centre, "turn")
	var lowest: Dictionary = {}
	for _n: int in 20:
		_motion(Vector2(0.0, 40.0))
		var now: Dictionary = _where()
		if lowest.is_empty() or float(now["eye_y"]) < float(lowest["eye_y"]):
			lowest = now
	_camera.end_drag(MOUSE_BUTTON_RIGHT)
	print("  measure mouse drag 800 px down: %s" % _words(lowest))
	_check("a right drag 800 px down stops above the floor: %s" % _words(lowest), not bool(lowest["under"]))
	# And back up: the drag still turns it.
	_camera.begin_drag(MOUSE_BUTTON_RIGHT, centre, "turn")
	for _n: int in 10:
		_motion(Vector2(0.0, -40.0))
	_camera.end_drag(MOUSE_BUTTON_RIGHT)
	var up: Dictionary = _where()
	print("  measure mouse drag 400 px up: %s" % _words(up))
	_check("...and 400 px back up looks down on it (%.0f°)" % rad_to_deg(float(up["pitch"])),
		float(up["pitch"]) > deg_to_rad(30.0))

	_main.call("default_view")
	await _settle()
	var deepest: Dictionary = {}
	for _n: int in 40:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = centre
		_camera._unhandled_input(wheel)
		deepest = _where()
	print("  measure mouse 40 notches in at the middle: %s" % _words(deepest))

	_main.call("default_view")
	await _settle()
	_camera.begin_drag(MOUSE_BUTTON_MIDDLE, centre, "slide")
	for _n: int in 30:
		_motion(Vector2(100.0, 0.0))
	_camera.end_drag(MOUSE_BUTTON_MIDDLE)
	var slid: Dictionary = _where()
	print("  measure mouse slide 3000 px: %s" % _words(slid))
	_check("a middle drag of 3000 px leaves the car on screen: %s" % _words(slid), not bool(slid["lost"]))
	# From there, the view at the edge of the car, two fingers spread to four
	# times as far apart: the view shrinks round a focus off to the side,
	# and the iPhone's walk lost the car so.
	var at: Vector2 = _camera.seen_rect().get_center()
	var was_far: float = _camera.distance_now()
	await _two(func(t: float) -> Array:
		var half: float = lerpf(40.0, 160.0, t)
		return [at - Vector2(half, 0.0), at + Vector2(half, 0.0)], 10)
	var pinched: Dictionary = _where()
	await _shot("zoomed_in_at_the_edge")
	print("  measure ...then spread to zoom in, %.0f to %.0f away: %s" % [was_far, float(pinched["distance"]),
		_words(pinched)])
	_check("...and two fingers spread from there to zoom in (%.0f to %.0f away) keep it: %s"
		% [was_far, float(pinched["distance"]), _words(pinched)],
		not bool(pinched["lost"]) and float(pinched["distance"]) < was_far * 0.5)

	_main.call("default_view")
	await _settle()
	var room: Rect2 = _camera.seen_rect()
	var corner: Vector2 = room.position + Vector2(room.size.x * 0.95, room.size.y * 0.05)
	_camera.begin_drag(MOUSE_BUTTON_RIGHT, corner, "turn")
	for _n: int in 30:
		_motion(Vector2(-60.0, 25.0))
	_camera.end_drag(MOUSE_BUTTON_RIGHT)
	var swung: Dictionary = _where()
	print("  measure mouse turn begun at the room's corner, 1800 px across, 750 down: %s" % _words(swung))
	_check("a turn begun off the model leaves it on screen and above the floor: %s" % _words(swung),
		not bool(swung["lost"]) and not bool(swung["under"]))
	_main.call("default_view")
	await _settle()


func _motion(by: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = by
	motion.position = _camera.seen_rect().get_center()
	_camera._unhandled_input(motion)


## The view cube's Bottom looks from under the model, as it always has; a
## drag from there goes up, and no further down.
func _bottom() -> void:
	_camera.set_view("bottom")
	await _settle()
	var below: Dictionary = _where()
	_check("Bottom looks up from under the model (%s)" % _words(below),
		float(below["pitch"]) < deg_to_rad(-80.0))
	var centre: Vector2 = _camera.seen_rect().get_center()
	_camera.begin_drag(MOUSE_BUTTON_RIGHT, centre, "turn")
	_motion(Vector2(0.0, 40.0))
	var down: Dictionary = _where()
	_motion(Vector2(0.0, -200.0))
	var back: Dictionary = _where()
	_camera.end_drag(MOUSE_BUTTON_RIGHT)
	_check("...a drag from there goes no further down (%.1f° to %.1f°) and comes up (%.1f°)"
		% [rad_to_deg(float(below["pitch"])), rad_to_deg(float(down["pitch"])), rad_to_deg(float(back["pitch"]))],
		float(down["pitch"]) >= float(below["pitch"]) - 0.0001 and float(back["pitch"]) > float(below["pitch"]) + 0.2)
	_main.call("default_view")
	await _settle()


# -- where the view is -----------------------------------------------------------------


## Where the view is going: the eye's height against the floor's plane, its
## tilt, whether it is in a part, in the model's box, and how many of the
## sampled parts are in the room it is seen in.
func _where() -> Dictionary:
	_camera._apply(1.0)
	var eye: Vector3 = _camera.global_position
	var upright: bool = not _camera.is_turned()
	var cell: Vector3i = BrickLattice.to_cell(eye)
	var in_part: int = _builder.lattice.brick_at(cell)
	if in_part != 0 and _store.scenery.has(in_part):
		in_part = 0
	# Main's own count, as the browser's walk asks for it (phonewalk's view_floor).
	var seen: int = _main.call("parts_seen")
	var box: AABB = _main.call("_built_bounds")
	var focus: Vector3 = _camera.focus_now()
	var nearest: Vector3 = focus.clamp(box.position, box.end)
	return {"eye_y": eye.y, "pitch": _camera.pitch_now(), "distance": _camera.distance_now(),
		"focus_off": focus.distance_to(nearest), "across": box.size.length(),
		"under": upright and eye.y < 0.0, "looking_up": upright and _camera.pitch_now() < 0.0,
		"inside": in_part != 0, "inside_box": box.has_point(eye), "seen": seen,
		"lost": seen == 0 and in_part == 0}


static func _words(at: Dictionary) -> String:
	var flags: Array = []
	for key: String in ["under", "inside", "lost"]:
		if bool(at.get(key, false)):
			flags.append(key.to_upper())
	return "eye %.1f LDU %s the floor, tilt %.1f°, %.0f away, focus %.0f off the model %.0f across, %d sampled parts seen%s" % [
		absf(float(at["eye_y"])), "above" if float(at["eye_y"]) >= 0.0 else "below",
		rad_to_deg(float(at["pitch"])), float(at["distance"]), float(at["focus_off"]), float(at["across"]),
		int(at["seen"]),
		(" " + ", ".join(flags)) if not flags.is_empty() else ""]


# -- the model ------------------------------------------------------------------------


func _open(path: String) -> bool:
	var real: String = ProjectSettings.globalize_path(path)
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", real)
	for _n: int in 3600:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0 and not _store.laying:
			break
	await _frames(30)
	_builder.clear_selection()
	_main.call("default_view")
	await _settle()
	var seen: int = _main.call("parts_seen")
	return _check("%s open (%d parts, %d sampled seen)" % [path.get_file(), _world.brick_count(), seen],
		_world.brick_count() > 0 and seen > 0)


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
	var dir: String = "res://shots/viewfloor/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	root.get_texture().get_image().save_png("%s%s.png" % [dir, name])
