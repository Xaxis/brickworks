## An orbit camera for looking at a model rather than standing in one.
##
## It turns around a focus point that sits in the model, the way a CAD
## viewport does: drag to orbit, middle-drag or shift-drag to pan, wheel to
## dolly. The focus point is the thing that makes it feel right — zooming
## moves towards where you are looking, and orbiting keeps it centred, so
## the model never swings out of frame.
##
## Distances are in LDU, because everything here is. A 2x4 brick is 80 wide
## and a big model runs to a few thousand, so the sensible viewing range
## covers three orders of magnitude and the zoom is geometric.
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
## How quickly the view catches up with the input, per second. Smoothing
## is what stops a mouse wheel's discrete clicks reading as jerks.
@export var smoothing: float = 18.0

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

var _orbiting: bool = false
var _panning: bool = false

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


## True when the last touch was a tap rather than a drag, so whoever
## handles placing can ask instead of guessing.
func last_touch_was_a_tap() -> bool:
	return _was_tap


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
			if _touches.size() == 1 and _touch_travel <= TAP_SLOP:
				_was_tap = true
			_touches.erase(touch.index)
			_spread = 0.0
		return

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_touches[drag.index] = drag.position
		_touch_travel += drag.relative.length()

		if _touches.size() == 1:
			# One finger turns the model. It is what people try first,
			# and on a build sitting on a table it is what you do.
			_target_yaw -= drag.relative.x * 0.006 * orbit_speed
			_target_pitch = clampf(
				_target_pitch - drag.relative.y * 0.006 * orbit_speed,
				-_PITCH_LIMIT, _PITCH_LIMIT)
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

			var scale: float = _target_distance * 0.0016 * pan_speed
			# Halved: with two fingers down each contributes a drag
			# event, so the motion would otherwise be applied twice.
			var right: Vector3 = global_transform.basis.x
			var up: Vector3 = global_transform.basis.y
			_target_focus -= right * drag.relative.x * scale * 0.5
			_target_focus += up * drag.relative.y * scale * 0.5
		return

	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_target_distance = maxf(min_distance, _target_distance / zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_target_distance = minf(max_distance, _target_distance * zoom_step)
			MOUSE_BUTTON_MIDDLE:
				# Middle-drag orbits; with shift it pans.
				if button.shift_pressed:
					_panning = button.pressed
				else:
					_orbiting = button.pressed
			MOUSE_BUTTON_LEFT:
				# Left and right click place and remove bricks, so the
				# camera only claims the left button with a modifier: alt
				# to orbit, shift to pan. That also covers a trackpad with
				# no middle button.
				if button.alt_pressed:
					_orbiting = button.pressed
				elif button.shift_pressed:
					_panning = button.pressed

	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _orbiting:
			_target_yaw -= motion.relative.x * 0.01 * orbit_speed
			_target_pitch = clampf(
				_target_pitch - motion.relative.y * 0.01 * orbit_speed,
				-_PITCH_LIMIT, _PITCH_LIMIT)
		elif _panning:
			# Pan in the camera's own plane, scaled by distance so the
			# model tracks the cursor at any zoom.
			var scale: float = _target_distance * 0.0016 * pan_speed
			var right: Vector3 = global_transform.basis.x
			var up: Vector3 = global_transform.basis.y
			_target_focus -= right * motion.relative.x * scale
			_target_focus += up * motion.relative.y * scale


## How far apart the first two fingers are.
func _distance_between() -> float:
	var points: Array = _touches.values()
	if points.size() < 2:
		return 0.0
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _process(delta: float) -> void:
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


## Point the camera from a named direction, keeping the focus.
func set_view(view: String) -> void:
	match view:
		"front": _target_yaw = 0.0; _target_pitch = 0.0
		"back": _target_yaw = PI; _target_pitch = 0.0
		"left": _target_yaw = -PI * 0.5; _target_pitch = 0.0
		"right": _target_yaw = PI * 0.5; _target_pitch = 0.0
		"top": _target_yaw = 0.0; _target_pitch = _PITCH_LIMIT
		"bottom": _target_yaw = 0.0; _target_pitch = -_PITCH_LIMIT
		_: _target_yaw = _DEFAULT_YAW; _target_pitch = _DEFAULT_PITCH
