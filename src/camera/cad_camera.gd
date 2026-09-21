## An orbit camera for looking at a model rather than standing in one.
##
## What moves it:
##
##   turn    middle-drag · right-drag · two fingers
##   slide   shift-middle-drag · shift and two fingers
##   zoom    wheel · pinch
##   fit     F for the selection, shift-F or Home for all of it
##
## The left button is not in that list and must not be. It places,
## removes and selects, and a camera that also claims it with a modifier
## takes a share of the one button the app is about. It used to claim it
## twice — alt to turn and space to slide — and space is also the key
## that presses whatever button was last clicked, so sliding the view
## after touching the toolbar fired Clear and took the model and its
## undo history with it.
##
## Three things make it feel like a CAD viewport rather than a camera
## that happens to orbit, and all three are about keeping the point you
## are pointing at where it is:
##
##   Turning goes around whatever is under the cursor when the drag
##   starts, not around the world origin and not around wherever the
##   focus happened to be left. Falling back to the middle of the model
##   when the cursor is over nothing.
##
##   Sliding is worked out at the depth of that same point, so the brick
##   you grabbed stays under the pointer for the whole drag rather than
##   drifting because the focus plane is somewhere else.
##
##   Zooming goes towards the pointer. Point at the corner you want a
##   closer look at and it stays put instead of sliding off the edge.
##
## It is a turntable, not a trackball: up stays up, and the pitch stops
## just short of straight down. A model sitting on a baseplate has an
## obvious up, and a free rotation that can roll it is a rotation
## nobody asked for.
##
## Distances are in LDU, because everything here is. A 2x4 brick is 80
## wide and a big model runs to a few thousand, so the sensible viewing
## range covers three orders of magnitude and the zoom is geometric.
class_name CadCamera
extends Camera3D

## Where the camera looks and orbits around, in LDU.
@export var focus: Vector3 = Vector3.ZERO
## How far back it sits, in LDU.
@export var distance: float = 400.0
@export var min_distance: float = 8.0
@export var max_distance: float = 40000.0

@export_group("Feel")
@export var orbit_speed: float = 0.6
@export var pan_speed: float = 1.0
@export var zoom_step: float = 1.12
## How quickly the view catches up with the input, per second.
##
## Smoothing is what stops a wheel's discrete clicks reading as jerks.
## It is also what makes a drag feel like it is on elastic, so this is
## fast enough to be invisible while dragging and slow enough to round
## off a wheel click: about a twentieth of a second to close the gap.
@export var smoothing: float = 34.0

# Positive pitch puts the camera above the model looking down, which is
# how you look at a build sitting on a table. Negative would show it from
# underneath — all studs and tube cavities.
const _DEFAULT_YAW := deg_to_rad(-35.0)
const _DEFAULT_PITCH := deg_to_rad(26.0)

var _yaw: float = _DEFAULT_YAW
var _pitch: float = _DEFAULT_PITCH
var _target_yaw: float = _DEFAULT_YAW
var _target_pitch: float = _DEFAULT_PITCH
var _target_distance: float = 400.0
var _target_focus: Vector3 = Vector3.ZERO

## What a drag is doing, and which button it belongs to.
##
## Kept as one state rather than two flags, and cleared by the button
## rather than by the modifier. Reading the modifier again at release
## was the bug: let go of alt before the button and neither arm of the
## release ran, so the camera stayed turning with nothing held and every
## later mouse move spun the view. The probe passed because it built a
## synthetic release with the modifier still down — the one sequence
## fingers do not perform.
enum Doing { NOTHING, ORBIT, SLIDE }

var _doing: Doing = Doing.NOTHING
var _doing_with: int = 0
## A right button held down that has not yet moved far enough to count
## as a turn rather than a click.
var _dragging_right: bool = false
var _right_travel: float = 0.0
## How far away the thing being dragged is, so sliding keeps pace with
## it rather than with the focus plane.
var _grab_depth: float = 0.0

## Ask what is under a point on the screen. Set by whoever owns the
## scene; it takes a screen position and returns a Vector3 in the world
## or null. Without it the pivot falls back to the middle of the model,
## which is where this camera always turned.
var pick: Callable = Callable()

## What turning is going around, and whether there is one. Apart from
## the focus: see [method _pivot_on].
var _pivot: Vector3 = Vector3.ZERO
var _has_pivot: bool = false

## Whether to draw a mark on the pivot. True only while turning.
var pivot_shown: bool = false


## Where the mark goes.
func pivot() -> Vector3:
	return _pivot if _has_pivot else focus

## Fingers currently down, by the index the system gives each one.
##
## Tracked here rather than relying on the engine's mouse emulation,
## which turns one finger into a left button and so cannot tell a drag
## meant to turn the model from a tap meant to place a brick — it would
## do both, and place a brick wherever the turn happened to end.
var _touches: Dictionary = {}
## How far apart two fingers were last frame, for the pinch.
var _spread: float = 0.0

# Just under a right angle: letting the camera reach straight down makes
# the yaw axis degenerate and the view spin unpredictably.
const _PITCH_LIMIT := deg_to_rad(89.0)


func _ready() -> void:
	# A brick is 24 units tall, so the near plane has to be far tighter
	# than the engine default or resting the camera on a stud clips it.
	near = 1.0
	far = 60000.0
	fov = 45.0
	_target_distance = distance
	_target_focus = focus
	_apply(1.0)


## How far a finger may move and still count as a tap rather than a
## drag, in pixels. Generous, because a finger on glass is never still
## and a tap that is read as a tiny orbit feels like the app ignoring
## you.
const TAP_SLOP := 14.0

## How far the pointer may move with a button down and still count as a
## click rather than a drag, in pixels. Smaller than TAP_SLOP: a mouse
## does not wobble the way a finger does.
const DRAG_SLOP := 4.0

## Trackpad pan deltas arrive in scroll units rather than pixels, and a
## comfortable swipe is a few units. This turns one into the pixel
## movement that would have felt the same.
const TRACKPAD_PAN := 14.0

## How far one wheel click slides the view when shift is held, in
## pixels. A wheel click is a coarse thing, so this is larger than a
## trackpad swipe of the same nominal size.
const WHEEL_PAN := 36.0


## True when the last touch was a tap rather than a drag, so whoever
## handles placing can ask instead of guessing.
func last_touch_was_a_tap() -> bool:
	return _was_tap


## How long after a gesture the click it produces should be ignored, in
## milliseconds. Mouse emulation raises a click from the same finger
## that just turned the model, and it arrives after the touch does.
const SWALLOW_MS := 350


## True while the click raised by a finger that was dragging — or held —
## should be thrown away rather than acted on.
##
## Emulation cannot be turned off to avoid this: without it no text
## field in the app can be focused by tapping. So both kinds of event
## arrive, the touch decides what the gesture meant, and this says
## whether the click that follows means anything.
func swallowing_click() -> bool:
	return Time.get_ticks_msec() < _swallow_until


var _swallow_until: int = 0


## Called when a gesture was something other than a tap.
func swallow_next_click() -> void:
	_swallow_until = Time.get_ticks_msec() + SWALLOW_MS


var _was_tap: bool = false
var _touch_started: Vector2 = Vector2.ZERO
var _touch_travel: float = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_touches[touch.index] = touch.position
			if _touches.size() == 1:
				_touch_started = touch.position
				_touch_travel = 0.0
				_was_tap = false
			elif _touches.size() == 2:
				# A second finger cancels any tap the first was making:
				# nobody pinches meaning to place a brick.
				_was_tap = false
				_spread = _distance_between()
		else:
			var tapped: bool = _touches.size() == 1 and _touch_travel <= TAP_SLOP
			_was_tap = tapped
			# A drag or a pinch raises a click on release just as a tap
			# does. Only a tap should reach whoever places bricks.
			if not tapped:
				swallow_next_click()
			_touches.erase(touch.index)
			_spread = 0.0
			if _touches.is_empty():
				_end(_doing_with)
		return

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_touches[drag.index] = drag.position
		_touch_travel += drag.relative.length()

		if _touches.size() == 1:
			# One finger turns the model. It is what people try first,
			# and on a build sitting on a table it is what you do.
			#
			# Around what is under the finger, like the mouse: the
			# first drag event of a gesture anchors it.
			if _doing != Doing.ORBIT:
				_begin(Doing.ORBIT, MOUSE_BUTTON_LEFT, drag.position)
			_turn_by(drag.relative, 0.006)
			return

		if _touches.size() >= 2:
			# Two fingers move the model and, by the distance between
			# them, how close it is. Both at once, because separating
			# them would mean choosing one and being wrong half the time.
			var now: float = _distance_between()
			if _spread > 0.0 and now > 0.0:
				var change: float = _spread / now
				_target_distance = clampf(
					_target_distance * change, min_distance, max_distance)
			_spread = now

			# Halved: with two fingers down each contributes a drag
			# event, so the motion would otherwise be applied twice.
			#
			# Worked out from the field of view like every other pan,
			# rather than from the eyeballed constant the mouse was
			# fixed away from — which on a phone in portrait ran the
			# model at about three times the finger.
			_slide_by(drag.relative * 0.5)
		return

	# A trackpad, which is what most people are on.
	#
	# macOS sends two-finger scrolling as a pan gesture and pinching as
	# a magnify gesture, not as wheel clicks — so a camera that listens
	# only for the wheel and a middle button is a camera with no working
	# controls at all on a laptop. That is what this was.
	if event is InputEventPanGesture:
		var swipe: InputEventPanGesture = event
		# Turning, because turning is what a viewport is mostly for and
		# it should be the gesture that needs nothing held. Sliding
		# takes shift, which is where every tool that has both puts it.
		if swipe.shift_pressed:
			_slide_by(swipe.delta * TRACKPAD_PAN)
		else:
			_turn_by(swipe.delta * TRACKPAD_PAN, 0.004)
		return

	if event is InputEventMagnifyGesture:
		var pinch: InputEventMagnifyGesture = event
		if pinch.factor > 0.0:
			_zoom_by(1.0 / pinch.factor, pinch.position)
		return

	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_wheel(button)
			MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
				# Sideways scrolling is a trackpad swipe every time; no
				# mouse wheel goes that way.
				if button.pressed:
					_slide_by(Vector2(WHEEL_PAN * (
						-1.0 if button.button_index == MOUSE_BUTTON_WHEEL_LEFT
						else 1.0), 0.0))
			MOUSE_BUTTON_MIDDLE:
				# The CAD convention: middle turns it, shift-middle
				# slides it.
				if button.pressed:
					_begin(Doing.SLIDE if button.shift_pressed
						else Doing.ORBIT, MOUSE_BUTTON_MIDDLE,
						button.position)
				else:
					_end(MOUSE_BUTTON_MIDDLE)
			MOUSE_BUTTON_RIGHT:
				# Right-drag turns the model; right-click still takes a
				# brick off. Which of the two it was is decided by
				# whether the pointer moved, the same way a tap is told
				# from a drag on glass — so nothing has to be chosen in
				# advance and neither gesture is lost.
				if button.pressed:
					_dragging_right = true
					_right_travel = 0.0
				else:
					_dragging_right = false
					_end(MOUSE_BUTTON_RIGHT)
			# The left button is the app's, not the camera's.

	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _dragging_right and _doing == Doing.NOTHING:
			_right_travel += motion.relative.length()
			if _right_travel > DRAG_SLOP:
				# It is a turn, not a click, so the release must not
				# also take a brick off.
				swallow_next_click()
				_begin(Doing.ORBIT, MOUSE_BUTTON_RIGHT, motion.position)
		match _doing:
			Doing.ORBIT: _turn_by(motion.relative, 0.01)
			Doing.SLIDE: _slide_by(motion.relative)


## A wheel click, which in a browser might be a finger.
##
## A desktop build knows: a trackpad sends pan and magnify gestures and
## only a real wheel sends wheel clicks. A browser sends wheel events
## for both, so the shape of the event has to be read instead — small,
## often fractional deltas in a dense stream are a trackpad, and a pinch
## comes through with ctrl held, which nothing else does.
func _wheel(button: InputEventMouseButton) -> void:
	var up: bool = button.button_index == MOUSE_BUTTON_WHEEL_UP
	var kind: int = WheelKind.last()

	if kind & WheelKind.PINCH:
		_zoom_by(1.0 / zoom_step if up else zoom_step, button.position)
		return
	if kind & WheelKind.TRACKPAD:
		# Two fingers, which turn the model, or slide it with shift.
		var by := Vector2(0.0, -WHEEL_PAN if up else WHEEL_PAN)
		if button.shift_pressed:
			_slide_by(-by)
		else:
			_turn_by(by, 0.004)
		return
	if button.shift_pressed:
		_slide_by(Vector2(0.0, WHEEL_PAN if up else -WHEEL_PAN))
		return
	_zoom_by(1.0 / zoom_step if up else zoom_step, button.position)


# -- a drag, from the button that owns it --------------------------------


## Start turning or sliding, and anchor it on what is under the cursor.
func _begin(doing: Doing, with_button: int, at: Vector2) -> void:
	_doing = doing
	_doing_with = with_button
	var aim: Vector3 = _under(at)
	_grab_depth = maxf((aim - global_position).dot(
		-global_transform.basis.z), 1.0)
	if doing == Doing.ORBIT:
		_pivot_on(aim)
		pivot_shown = true


## Stop, if this is the button that started it.
func _end(with_button: int) -> void:
	if _doing == Doing.NOTHING or with_button != _doing_with:
		return
	_doing = Doing.NOTHING
	_doing_with = 0
	pivot_shown = false
	_has_pivot = false


## Where the pointer is aiming, in the world.
##
## Whatever is under it, if anything is; otherwise the point on the
## plane through the focus, which is where a model mostly is.
func _under(at: Vector2) -> Vector3:
	if pick.is_valid():
		var hit: Variant = pick.call(at)
		if hit is Vector3:
			return hit
	return _on_focus_plane(at)


## Turn around a point without moving the camera.
##
## The pivot is kept apart from the focus on purpose. The focus is what
## the camera points at; the pivot is what it swings around. Setting
## the focus to the grabbed point instead looks like the same thing and
## is not: the camera would re-aim at it the instant the button went
## down, so the view jumped before the drag had begun.
##
## Keeping them separate means taking hold changes nothing at all, and
## the drag then rotates the camera and its focus together about the
## pivot — which leaves the grabbed point exactly where it was and
## swings everything else around it.
func _pivot_on(point: Vector3) -> void:
	_pivot = point
	_has_pivot = true


func _turn_by(by: Vector2, rate: float) -> void:
	var around_up: float = -by.x * rate * orbit_speed
	var was: float = _target_pitch
	_target_pitch = clampf(was - by.y * rate * orbit_speed,
		-_PITCH_LIMIT, _PITCH_LIMIT)
	# The delta that was actually applied, which at the poles is less
	# than the one asked for — using the asked-for one would slide the
	# pivot sideways every time somebody drags past straight down.
	var around_right: float = _target_pitch - was
	_target_yaw += around_up

	if not _has_pivot or _target_focus.is_equal_approx(_pivot):
		return
	# Swing the focus about the pivot by the same rotation the camera
	# just made, so their offset keeps the direction the angles say it
	# has and the pivot stays where it is on screen.
	var right: Vector3 = global_transform.basis.x
	var turn: Basis = Basis(Vector3.UP, around_up) * Basis(right, around_right)
	_target_focus = _pivot + turn * (_target_focus - _pivot)


## Slide the view in its own plane, by a movement in screen pixels.
##
## At the depth of whatever was grabbed, not at the depth of the focus.
## Those are the same thing only when you happen to grab the middle of
## the model; grab a chimney standing well in front of it and a pan
## worked out at the focus plane moves the world slower than your hand,
## so the chimney drifts out from under the pointer over the drag.
##
## The scale itself is worked out from the field of view and the height
## of the window rather than guessed, so a hundred pixels of drag is a
## hundred pixels of movement.
func _slide_by(by: Vector2) -> void:
	var depth: float = _grab_depth if _doing == Doing.SLIDE \
		else _target_distance
	var scale: float = _ldu_per_pixel(depth) * pan_speed
	_target_focus -= global_transform.basis.x * by.x * scale
	_target_focus += global_transform.basis.y * by.y * scale


## Where a point on the screen lands on the plane through the focus.
func _on_focus_plane(at: Vector2) -> Vector3:
	if not is_inside_tree():
		return focus
	var forward: Vector3 = -global_transform.basis.z
	var origin: Vector3 = project_ray_origin(at)
	var towards: Vector3 = project_ray_normal(at)
	var facing: float = towards.dot(forward)
	if absf(facing) < 0.0001:
		return focus
	return origin + towards * ((focus - origin).dot(forward) / facing)


## World units to one pixel, at the plane the focus sits in.
func _ldu_per_pixel(at_depth: float = -1.0) -> float:
	var height: float = 900.0
	if is_inside_tree():
		height = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var depth: float = at_depth if at_depth > 0.0 else _target_distance
	if projection == Camera3D.PROJECTION_ORTHOGONAL:
		return size / height
	return 2.0 * depth * tan(deg_to_rad(fov) * 0.5) / height


## Move in or out, towards whatever is under the pointer.
##
## Zooming towards the middle of the screen is the thing that makes a
## viewport feel wrong without anyone being able to say why: you point
## at the corner of the model you want a closer look at, zoom, and it
## slides off the edge, so every zoom costs a pan to put right.
##
## Keeping the point under the pointer still is what every CAD viewport
## does, and for an orbit camera it is one line: the focus moves towards
## that point by the same proportion the distance shrinks.
func _zoom_by(factor: float, at_screen: Vector2 = Vector2.INF) -> void:
	var was: float = _target_distance
	_target_distance = clampf(was * factor, min_distance, max_distance)
	if projection == Camera3D.PROJECTION_ORTHOGONAL:
		# Moving an orthographic camera changes nothing on screen, so
		# the view itself has to grow and shrink.
		size = clampf(size * factor, 1.0, 40000.0)
	if at_screen.x == INF or not is_inside_tree():
		return
	var actual: float = _target_distance / was
	if is_equal_approx(actual, 1.0):
		return

	# Where the pointer is aiming, on the plane the focus sits in.
	var forward: Vector3 = (focus - global_position)
	if forward.length_squared() <= 0.0:
		return
	forward = forward.normalized()
	var origin: Vector3 = project_ray_origin(at_screen)
	var towards: Vector3 = project_ray_normal(at_screen)
	var facing: float = towards.dot(forward)
	if absf(facing) < 0.0001:
		return
	var aim: Vector3 = origin + towards * (
		(focus - origin).dot(forward) / facing)
	_target_focus = aim + (_target_focus - aim) * actual


## How far apart the first two fingers are.
func _distance_between() -> float:
	var points: Array = _touches.values()
	if points.size() < 2:
		return 0.0
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _process(delta: float) -> void:
	# A drag ends when its button comes up, and sometimes that never
	# happens: let go outside the window, or over something that
	# swallowed the release, and the press is the last event there is.
	# Without this the camera keeps turning with nothing held, which is
	# the same symptom the modifier bug had and is just as hard to
	# explain to whoever is looking at it.
	if _doing != Doing.NOTHING and _touches.is_empty() \
			and not Input.is_mouse_button_pressed(_doing_with):
		_end(_doing_with)
	if _dragging_right and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_dragging_right = false

	# An exponential approach, framerate independent: the same fraction of
	# the remaining distance per second whatever the frame time.
	_apply(1.0 - exp(-smoothing * delta))


func _apply(weight: float) -> void:
	_yaw = lerp_angle(_yaw, _target_yaw, weight)
	_pitch = lerp_angle(_pitch, _target_pitch, weight)
	distance = lerpf(distance, _target_distance, weight)
	focus = focus.lerp(_target_focus, weight)

	var offset := Vector3(
		cos(_pitch) * sin(_yaw),
		sin(_pitch),
		cos(_pitch) * cos(_yaw)) * distance
	global_position = focus + offset
	look_at(focus, Vector3.UP)

	# Clip planes that follow the distance.
	#
	# A fixed near plane has to be tight enough for the closest anyone
	# will ever get, and a tight near plane against a far plane sixty
	# thousand units away spends the whole depth buffer on the first
	# stud — so a model seen from across the baseplate gets its faces
	# fighting each other. Scaling both with the distance keeps the
	# ratio sane at every zoom.
	near = clampf(distance * 0.02, 0.5, 40.0)
	far = clampf(distance * 12.0, 2000.0, 80000.0)


## Perspective or straight-on.
##
## Orthographic is how a CAD drawing is read: parallel edges stay
## parallel, so two walls that are the same length measure the same on
## screen and a straight-on view is actually straight on. Perspective is
## how the thing will look on a table. Both are wanted, at different
## moments.
##
## Zoom scales the view rather than moving the camera when it is
## straight-on, because moving an orthographic camera changes nothing
## at all — which reads as the zoom being broken.
func square_on(yes: bool) -> void:
	if yes == (projection == Camera3D.PROJECTION_ORTHOGONAL):
		return
	projection = (Camera3D.PROJECTION_ORTHOGONAL if yes
		else Camera3D.PROJECTION_PERSPECTIVE)
	# Matched so the switch does not change how big the model looks.
	if yes:
		size = 2.0 * _target_distance * tan(deg_to_rad(fov) * 0.5)
	else:
		_target_distance = clampf(
			size * 0.5 / tan(deg_to_rad(fov) * 0.5),
			min_distance, max_distance)


func is_square_on() -> bool:
	return projection == Camera3D.PROJECTION_ORTHOGONAL


## Frame a box so it fills the view with a little room around it.
func frame(box: AABB, margin: float = 1.25) -> void:
	if box.size.length_squared() <= 0.0:
		return
	_target_focus = box.get_center()
	var radius: float = maxf(box.size.length() * 0.5, min_distance)
	# The distance at which a sphere of this radius subtends the vertical
	# field of view.
	_target_distance = clampf(
		radius / sin(deg_to_rad(fov) * 0.5) * margin, min_distance, max_distance)
	if projection == Camera3D.PROJECTION_ORTHOGONAL:
		size = radius * 2.0 * margin


## Point the camera from a named direction, keeping the focus.
func set_view(view: String) -> void:
	match view:
		"front": _target_yaw = 0.0; _target_pitch = 0.0
		"back": _target_yaw = PI; _target_pitch = 0.0
		"left": _target_yaw = -PI * 0.5; _target_pitch = 0.0
		"right": _target_yaw = PI * 0.5; _target_pitch = 0.0
		"top": _target_yaw = 0.0; _target_pitch = _PITCH_LIMIT
		"bottom": _target_yaw = 0.0; _target_pitch = -_PITCH_LIMIT
		"isometric":
			_target_yaw = deg_to_rad(-45.0)
			_target_pitch = atan(1.0 / sqrt(2.0))
		_: _target_yaw = _DEFAULT_YAW; _target_pitch = _DEFAULT_PITCH
