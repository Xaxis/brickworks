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
##
## The view is centred on the part of the window the model is seen in
## ([member seen]: between the columns, under the bars), not on the
## window, by shifting the lens: the frustum's offset in perspective, the
## camera slid in its own plane when straight-on, where sliding is the
## same thing. The window still draws all of it, so nothing moves but the
## picture. Godot's [method Camera3D.project_ray_normal] and
## [method Camera3D.project_position] assume a frustum centred on the
## window and are wrong for this one (0.09 rad out at the 168 units one
## column moves the middle; camera_probe): a ray from the screen is
## [method ray_origin] and [method ray_normal], which invert the
## projection the view is drawn with. [method Camera3D.unproject_position]
## is exact as it is. tests/test_lens.py keeps the engine's two out of src/.
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
enum Doing { NOTHING, ORBIT, SLIDE, ZOOM }

## Where a zooming drag began, which it zooms towards.
var _zoom_from: Vector2 = Vector2.ZERO
## Shift as the right button went down: it decides whether the drag that
## follows turns or slides.
var _right_shift: bool = false

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

## Ask whether a point on the screen is over the interface rather than
## the model. Set by whoever owns the scene; it takes a screen position
## and returns a bool. Nothing that begins there is the camera's: see
## [method _begins_over_interface].
var over_interface: Callable = Callable()

## What turning is going around, and whether there is one. Apart from
## the focus: see [method _pivot_on].
var _pivot: Vector3 = Vector3.ZERO
var _has_pivot: bool = false

## Whether to draw a mark on the pivot. True only while turning.
var pivot_shown: bool = false

## The part of the window the model is seen in, in the viewport's own
## units (a control's global rect, an event's position). Set by whoever
## owns the scene; it takes nothing and returns a Rect2. The view is
## centred on it and framed to fill it. Without it, the whole window.
var seen: Callable = Callable()

## Where the middle of the lens is on the screen, from the middle of the
## window, in the viewport's units. It eases to the middle of
## [method seen_rect], and holds still while a button or a finger is down
## so a column folding mid-drag cannot pull the model from under the
## pointer.
var _shift: Vector2 = Vector2.ZERO
## Whether the lens has been put on a real seen rect yet: the first one is
## taken at once rather than eased into, or the model would slide in from
## the window's middle as the app opened.
var _shift_known: bool = false
## The lens as last put on the camera, so a lens at rest sets nothing.
var _lensed: Array = []

## The lens moved on with nothing held: what is under a still pointer is
## not what was.
signal lens_moved


## Where the mark goes.
func pivot() -> Vector3:
	return _pivot if _has_pivot else focus


## A drag is turning the view.
func is_turning() -> bool:
	return _doing == Doing.ORBIT


## A drag is sliding it.
func is_sliding() -> bool:
	return _doing == Doing.SLIDE


## A button is holding the view: turning, sliding or zooming it.
func is_dragging() -> bool:
	return _doing != Doing.NOTHING


## The right button is down and has not moved far enough to be a turn,
## so letting go now is a click and takes a brick off.
func right_pending() -> bool:
	return _dragging_right and _doing == Doing.NOTHING


## How long the pointer goes on saying what a wheel notch, a swipe or a
## key did, in milliseconds. Each of those is over in an instant, and a
## cursor that changed for one frame would be a flicker rather than an
## answer; this is long enough to read and short enough that it is gone
## by the time the hand moves on.
const MOMENT_MS := 350

var _moment: String = ""
var _moment_until: int = 0


## What the view did a moment ago without a button held — "orbit",
## "slide", "zoom_in", "zoom_out" — or "" once that has passed. Drags
## are not in it: they are [method is_turning] and [method is_sliding]
## for exactly as long as they last, and a turn that went on claiming
## the pointer after its button came up would be a stale cursor.
func moment() -> String:
	return _moment if Time.get_ticks_msec() < _moment_until else ""


func _note(kind: String) -> void:
	_moment = kind
	_moment_until = Time.get_ticks_msec() + MOMENT_MS


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


## How many fingers are down, as this has seen them come and go.
func fingers() -> int:
	return _touches.size()


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

## Whether the right button's release ends a turn rather than a click.
##
## Separate from the window above, which it used to share, and the
## sharing was wrong in a way that only showed up as flakiness. That
## window exists because an emulated click arrives *after* the touch
## that caused it, so it has to be a span of time. A right-drag has no
## such delay: the release that matters is the very next one. Sharing
## one window meant a turn also threw away any left click that landed
## within a third of a second of it — so orbiting and then immediately
## placing a brick placed nothing, sometimes, depending on how fast the
## machine was drawing.
var _turned_not_clicked: bool = false


## True when the right release that is happening now ends a turn.
## Reading it answers for that release and no other.
func turned_rather_than_clicked() -> bool:
	var was: bool = _turned_not_clicked
	_turned_not_clicked = false
	return was


## Called when a gesture was something other than a tap.
func swallow_next_click() -> void:
	_swallow_until = Time.get_ticks_msec() + SWALLOW_MS


var _was_tap: bool = false
var _touch_started: Vector2 = Vector2.ZERO
var _touch_travel: float = 0.0

## The phone's gestures (PhoneShell): two fingers turn the view and pinch
## zooms it, and a finger the app has taken (finger_taken) is left to it.
var phone: bool = false
## Whether the app has the finger that is dragging now (a part being moved
## by it): asked at its first drag, on a phone.
var finger_taken: Callable = Callable()
## Whether a finger that comes down here is on the interface (a sheet, a
## bar): such a finger is not the camera's, on a phone.
var touch_over: Callable = Callable()
var _not_mine: Dictionary = {}
var _left_to_app: int = 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if phone and touch.pressed and _touches.is_empty() and touch_over.is_valid() \
				and bool(touch_over.call(touch.position)):
			_not_mine[touch.index] = true
			return
		if phone and not touch.pressed and _not_mine.has(touch.index):
			_not_mine.erase(touch.index)
			return
		if touch.pressed:
			if _touches.is_empty():
				_left_to_app = 0
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
			# does. Only a tap should reach whoever places bricks — or a
			# drag the app had, whose release is its own.
			if not tapped and _left_to_app != 1:
				swallow_next_click()
			_touches.erase(touch.index)
			_spread = 0.0
			if _touches.is_empty():
				_end(_doing_with)
		return

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if _not_mine.has(drag.index):
			return
		_touches[drag.index] = drag.position
		_touch_travel += drag.relative.length()

		if _touches.size() == 1 and phone:
			if _left_to_app == 0:
				_left_to_app = 1 if finger_taken.is_valid() and bool(finger_taken.call()) else -1
			if _left_to_app == 1:
				return
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

			# On a phone two fingers turn it, about the point between
			# them, and one finger is for building.
			if phone:
				if _doing != Doing.ORBIT:
					_begin(Doing.ORBIT, MOUSE_BUTTON_LEFT, _between())
				_turn_by(drag.relative * 0.5, 0.006)
				return

			# Halved: with two fingers down each contributes a drag
			# event, so the motion would otherwise be applied twice.
			#
			# Worked out from the field of view like every other pan,
			# rather than from the eyeballed constant the mouse was
			# fixed away from — which on a phone in portrait ran the
			# model at about three times the finger.
			_slide_by(drag.relative * 0.5)
		return

	if _begins_over_interface(event):
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
			_note("slide")
		else:
			_turn_by(swipe.delta * TRACKPAD_PAN, 0.004)
			_note("orbit")
		return

	if event is InputEventMagnifyGesture:
		var pinch: InputEventMagnifyGesture = event
		if pinch.factor > 0.0:
			var factor: float = pinch.factor
			if ViewPrefs.invert_zoom:
				factor = 1.0 / factor
			_zoom_by(1.0 / factor, pinch.position)
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
					_note("slide")
			MOUSE_BUTTON_MIDDLE:
				# The CAD convention: middle turns it, shift-middle
				# slides it — or the other way round, for the people who
				# came from a tool that does it the other way round.
				# Shift always gives the one the plain drag does not, so
				# neither gesture is lost whichever way this is set.
				if button.double_click:
					# Put the turning point where you are looking.
					#
					# Turning about whatever happens to be under the
					# cursor is right while a drag is happening and
					# wrong as a lasting choice: the model drifts out of
					# the middle of the screen over a few turns, and the
					# only way back is to frame the whole thing and lose
					# your place. This re-centres on the point you name
					# without changing how far away you are.
					_centre_on(button.position)
				elif button.pressed:
					# What the preset says the middle button does
					# (ViewPrefs.drag_verb); shift gives the other.
					begin_drag(MOUSE_BUTTON_MIDDLE, button.position,
						ViewPrefs.drag_verb(MOUSE_BUTTON_MIDDLE, button.shift_pressed))
				else:
					_end(MOUSE_BUTTON_MIDDLE)
			MOUSE_BUTTON_RIGHT:
				# Right-drag turns the model; a right click lets go of
				# the part in hand. Which of the two it was is decided by
				# whether the pointer moved, the same way a tap is told
				# from a drag on glass — so nothing has to be chosen in
				# advance and neither gesture is lost.
				if button.pressed:
					_dragging_right = true
					_right_travel = 0.0
					_right_shift = button.shift_pressed
					# A fresh press decides afresh. Without this, a
					# release that never reached the app — let go over a
					# panel, say — would leave the answer set for the
					# next one.
					_turned_not_clicked = false
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
				_turned_not_clicked = true
				# Turns, or with shift slides, as Studio's does — or
				# whatever the preset says the right button does.
				begin_drag(MOUSE_BUTTON_RIGHT, motion.position,
					ViewPrefs.drag_verb(MOUSE_BUTTON_RIGHT, _right_shift))
		match _doing:
			Doing.ORBIT: _turn_by(motion.relative, 0.01)
			Doing.SLIDE: _slide_by(motion.relative)
			Doing.ZOOM: _zoom_by(exp(motion.relative.y * 0.01), _zoom_from)


## Whether this event would start something over the interface: a
## wheel notch, a swipe, a pinch, or the right or middle button going
## down. Releases and movement are not asked about, so a drag begun over
## the model still ends wherever it is let go.
##
## Asked for by the owner: "when i'm scrolling within a modal or control
## panel ... it continues to move and effect the model in the main window
## behind it". Godot hands a wheel event on through any control that does
## not use it — a list already at its end, a dialog with nothing to scroll
## (mouse_force_pass_scroll_events is on by default) — and a swipe or a
## pinch is not stopped by a control at all. The side panels pass every
## event on by design, so a right drag begun in the parts bin turned the
## model too. Every one of those arrived here as if over the model.
func _begins_over_interface(event: InputEvent) -> bool:
	if not over_interface.is_valid():
		return false
	var at: Vector2
	if event is InputEventGesture:
		at = (event as InputEventGesture).position
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if not button.pressed or button.button_index == MOUSE_BUTTON_LEFT:
			return false
		at = button.position
	else:
		return false
	return bool(over_interface.call(at))


## Look at this point, from where you already are.
##
## The focus moves and the distance does not, so the model swings to the
## middle of the screen rather than jumping closer.
func _centre_on(at: Vector2) -> void:
	var aim: Vector3 = _under(at)
	_target_focus = aim
	_pivot_on(aim)
	pivot_shown = true


## A wheel click, which in a browser might be a finger.
##
## A desktop build knows: a trackpad sends pan and magnify gestures and
## only a real wheel sends wheel clicks. A browser sends wheel events
## for both, so the shape of the event has to be read instead — small,
## often fractional deltas in a dense stream are a trackpad, and a pinch
## comes through with ctrl held, which nothing else does.
func _wheel(button: InputEventMouseButton) -> void:
	var up: bool = button.button_index == MOUSE_BUTTON_WHEEL_UP
	if ViewPrefs.invert_zoom:
		up = not up
	var kind: int = WheelKind.last()

	if kind & WheelKind.PINCH:
		_zoom_by(1.0 / zoom_step if up else zoom_step, button.position)
		return
	if kind & WheelKind.TRACKPAD:
		# Two fingers, which turn the model, or slide it with shift.
		var by := Vector2(0.0, -WHEEL_PAN if up else WHEEL_PAN)
		if button.shift_pressed:
			_slide_by(-by)
			_note("slide")
		else:
			_turn_by(by, 0.004)
			_note("orbit")
		return
	if button.shift_pressed:
		_slide_by(Vector2(0.0, WHEEL_PAN if up else -WHEEL_PAN))
		_note("slide")
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


## Begin moving the view with a button held: "turn", "slide" or "zoom".
## Public for the left button, which the app owns and lends to the view
## only in the Mecabricks preset, on empty space.
func begin_drag(with_button: int, at: Vector2, verb: String) -> void:
	match verb:
		"turn":
			_begin(Doing.ORBIT, with_button, at)
		"slide":
			_begin(Doing.SLIDE, with_button, at)
		"zoom":
			_zoom_from = at
			_begin(Doing.ZOOM, with_button, at)


## The end of a drag begun with begin_drag.
func end_drag(with_button: int) -> void:
	_end(with_button)


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
	var origin: Vector3 = ray_origin(at)
	var towards: Vector3 = ray_normal(at)
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
	# Every caller is a wheel, a pinch or a key, none of them a drag, so
	# this is the one place to say so.
	if not is_equal_approx(factor, 1.0):
		_note("zoom_in" if factor < 1.0 else "zoom_out")
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
	var origin: Vector3 = ray_origin(at_screen)
	var towards: Vector3 = ray_normal(at_screen)
	var facing: float = towards.dot(forward)
	if absf(facing) < 0.0001:
		return
	var aim: Vector3 = origin + towards * (
		(focus - origin).dot(forward) / facing)
	_target_focus = aim + (_target_focus - aim) * actual


# -- from the keyboard -----------------------------------------------------
#
# Asked for by the owner: "why can't I use standard + and - for zoom?" The
# view moved only with a mouse, a trackpad or fingers, which is three ways
# and none of them on the keys every other viewer answers to. A tap is one
# step, the size a wheel notch is; holding keeps it going, smoothly, at a
# rate per second rather than per key repeat, so it is the same on a fast
# machine and a slow one and does not stutter at the repeat rate.

## Degrees a tap of an arrow turns the view, and how many a held one turns
## each second.
const KEY_TURN_STEP := 10.0
const KEY_TURN_PER_SECOND := 90.0
## A tap's share of the view slid, and a held key's each second.
const KEY_SLIDE_STEP := 0.08
const KEY_SLIDE_PER_SECOND := 0.6
## How much a held zoom key closes in each second: to a third.
const KEY_ZOOM_PER_SECOND := 3.0


## A drag's worth of turning, sliding or zooming from something that is
## not a held button the camera saw go down: the view cube's arrows and
## its pan and zoom pads (ViewCube). In screen pixels, as a drag is.
func turn_by_drag(by: Vector2) -> void:
	_note("orbit")
	_turn_by(by, 0.01)


func slide_by_drag(by: Vector2) -> void:
	_note("slide")
	_slide_by(by)


func zoom_by_drag(by: float, at: Vector2 = Vector2.INF) -> void:
	_zoom_by(exp(by * 0.01), at)


## Look at the focus from a direction, from the focus towards the eye: the
## view cube's faces, edges and corners. Straight up and down stop at the
## same limit a drag does.
func look_from(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	var way: Vector3 = direction.normalized()
	_target_pitch = clampf(asin(clampf(way.y, -1.0, 1.0)), -_PITCH_LIMIT, _PITCH_LIMIT)
	if Vector2(way.x, way.z).length() > 0.001:
		# The nearest turn to the one already taken, so the view swings
		# the short way round rather than spinning back through zero.
		var aim: float = atan2(way.x, way.z)
		_target_yaw = aim + TAU * roundf((_target_yaw - aim) / TAU)


## How far the view has turned round in all, in radians, without wrapping:
## a browser check turning it "all the way round" reads it.
func yaw_turned() -> float:
	return _target_yaw


func pitch_now() -> float:
	return _target_pitch


func distance_now() -> float:
	return _target_distance


func focus_now() -> Vector3:
	return _target_focus


## One step in or out, as a wheel notch is, towards the middle of the view.
func key_zoom(steps: int) -> void:
	if steps == 0:
		return
	_zoom_by(1.0 / zoom_step if steps > 0 else zoom_step)


## One step of turning: +x round to the right, +y tilting up.
func key_turn(direction: Vector2) -> void:
	_turn_degrees(direction * KEY_TURN_STEP)


## One step of sliding the view the way asked: +x right, +y up.
func key_slide(direction: Vector2) -> void:
	_slide_share(direction * KEY_SLIDE_STEP)


## Keys being held, a frame's worth: zoom +1 in or -1 out, and a direction
## to turn and to slide in.
func key_hold(delta: float, zoom: int, turn: Vector2, slide: Vector2) -> void:
	if zoom != 0:
		_zoom_by(pow(KEY_ZOOM_PER_SECOND, -float(zoom) * delta))
	if turn != Vector2.ZERO:
		_turn_degrees(turn * KEY_TURN_PER_SECOND * delta)
	if slide != Vector2.ZERO:
		_slide_share(slide * KEY_SLIDE_PER_SECOND * delta)


## Turn by degrees round the up axis and about the view's own right, the
## way a drag the same way would: right turns as dragging right does, up
## as dragging up.
func _turn_degrees(by: Vector2) -> void:
	_note("orbit")
	_target_yaw -= deg_to_rad(by.x)
	_target_pitch = clampf(_target_pitch + deg_to_rad(by.y), -_PITCH_LIMIT,
		_PITCH_LIMIT)


## Slide by a share of what the view shows, so a step is the same on
## screen at any zoom.
func _slide_share(by: Vector2) -> void:
	_note("slide")
	var across: float = _ldu_per_pixel() * (get_viewport().get_visible_rect().size.y
		if is_inside_tree() else 900.0)
	_target_focus += global_transform.basis.x * by.x * across
	_target_focus += global_transform.basis.y * by.y * across


## The point halfway between the first two fingers.
func _between() -> Vector2:
	var points: Array = _touches.values()
	if points.size() < 2:
		return points[0] if not points.is_empty() else Vector2.ZERO
	return ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5


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


## The pose last put on the camera, and the transform it came to. A camera
## at rest sets nothing: a transform set again unchanged is still a frame
## drawn (IdleDraw), and setting it every frame drew sixty a second of a
## model nobody moved. Moved by anything else, it is put back as before.
var _posed: Array = []
var _posed_at: Transform3D = Transform3D()

## Closer than this to where it is going, it is there: about a hundredth of
## a pixel, as a share of the distance or in radians. An exponential
## approach never arrives by itself, and a camera a hair from its target
## moved, and was drawn, for ever.
const ARRIVED := 0.00001


func _apply(weight: float) -> void:
	_yaw = lerp_angle(_yaw, _target_yaw, weight)
	_pitch = lerp_angle(_pitch, _target_pitch, weight)
	distance = lerpf(distance, _target_distance, weight)
	focus = focus.lerp(_target_focus, weight)
	if absf(angle_difference(_yaw, _target_yaw)) < ARRIVED:
		_yaw = _target_yaw
	if absf(angle_difference(_pitch, _target_pitch)) < ARRIVED:
		_pitch = _target_pitch
	var hair: float = maxf(_target_distance, 1.0) * ARRIVED
	if absf(distance - _target_distance) < hair:
		distance = _target_distance
	if focus.distance_to(_target_focus) < hair:
		focus = _target_focus
	_ease_lens(weight)
	var pose: Array = [_yaw, _pitch, distance, focus]
	if pose != _posed or global_transform != _posed_at:
		_posed = pose
		var offset := Vector3(
			cos(_pitch) * sin(_yaw),
			sin(_pitch),
			cos(_pitch) * cos(_yaw)) * distance
		global_position = focus + offset
		look_at(focus, Vector3.UP)
		_posed_at = global_transform

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
	_put_lens()


# -- the lens, centred on the part of the window the model is seen in -------


## The window, in the viewport's own units.
func _room() -> Vector2:
	if not is_inside_tree():
		return Vector2(1600.0, 900.0)
	var room: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(maxf(room.x, 1.0), maxf(room.y, 1.0))


## The part of the window the model is seen in: [member seen]'s answer,
## inside the window, or the whole window when there is none or it is too
## small to look at anything through.
func seen_rect() -> Rect2:
	var window := Rect2(Vector2.ZERO, _room())
	if seen.is_valid():
		var rect: Rect2 = (seen.call() as Rect2).intersection(window)
		if rect.size.x >= 32.0 and rect.size.y >= 32.0:
			return rect
	return window


## Whether anything is holding the view still: a drag, a finger, or a
## button down anywhere — over a panel too, since a part being dragged
## from the bin is aimed by where the model is under the pointer.
func _lens_held() -> bool:
	if _doing != Doing.NOTHING or not _touches.is_empty():
		return true
	for button: int in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if Input.is_mouse_button_pressed(button):
			return true
	return false


## Bring the lens towards the middle of the seen rect, as the pose is
## brought towards its target. A column folding, unfolding or sliding is
## followed frame by frame, so the model glides to the new middle.
func _ease_lens(weight: float) -> void:
	var aim: Vector2 = seen_rect().get_center() - _room() * 0.5
	if not _shift_known:
		if not seen.is_valid() or not is_inside_tree():
			return
		_shift_known = true
		_shift = aim
		return
	if _shift == aim or _lens_held():
		return
	_shift = _shift.lerp(aim, weight)
	if _shift.distance_to(aim) < 0.01:
		_shift = aim
	lens_moved.emit()


## Put the lens on the camera, if it is not on already: a value set again
## unchanged is a frame drawn (IdleDraw).
##
## Perspective is a frustum, so its middle can be off the window's: the
## same field of view across the window's height as before, at the near
## plane, offset by the shift. Straight-on, the camera slides in its own
## plane instead, which for parallel lines is exactly the same picture.
func _put_lens() -> void:
	var room: Vector2 = _room()
	var now: Array = [_shift, room, projection, size, fov, near, far, h_offset, v_offset]
	if now == _lensed:
		return
	if projection == Camera3D.PROJECTION_ORTHOGONAL:
		var per: float = size / room.y
		h_offset = -_shift.x * per
		v_offset = _shift.y * per
	else:
		h_offset = 0.0
		v_offset = 0.0
		var tall: float = 2.0 * near * tan(deg_to_rad(fov) * 0.5)
		set_frustum(tall, Vector2(-_shift.x, _shift.y) * tall / room.y, near, far)
	_lensed = [_shift, room, projection, size, fov, near, far, h_offset, v_offset]


## Where a ray through a point on the screen starts: the eye, or straight-on
## the point on the near plane. In the viewport's units, as an event's
## position is.
func ray_origin(at: Vector2) -> Vector3:
	if not is_inside_tree():
		return global_position
	var eye: Transform3D = get_camera_transform()
	if projection != Camera3D.PROJECTION_ORTHOGONAL:
		return eye.origin
	return eye * _through_lens(at)


## Which way a ray through a point on the screen goes, through the lens the
## view is drawn with.
func ray_normal(at: Vector2) -> Vector3:
	if not is_inside_tree():
		return -global_transform.basis.z
	var eye: Transform3D = get_camera_transform()
	if projection == Camera3D.PROJECTION_ORTHOGONAL:
		return -eye.basis.z.normalized()
	return (eye.basis * _through_lens(at)).normalized()


## A point on the screen, on the near plane, in the camera's own space: the
## projection the view is drawn with, run backwards.
func _through_lens(at: Vector2) -> Vector3:
	var room: Vector2 = _room()
	var clip := Vector4(at.x / room.x * 2.0 - 1.0, 1.0 - at.y / room.y * 2.0, -1.0, 1.0)
	var back: Vector4 = get_camera_projection().inverse() * clip
	return Vector3(back.x, back.y, back.z) / back.w


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
	_put_lens()


func is_square_on() -> bool:
	return projection == Camera3D.PROJECTION_ORTHOGONAL


## Frame a box so it fills the view with a little room around it.
func frame(box: AABB, margin: float = 1.25) -> void:
	if box.size.length_squared() <= 0.0:
		return
	_target_focus = box.get_center()
	var radius: float = maxf(box.size.length() * 0.5, min_distance)
	# The distance at which a sphere of this radius fits the narrower of
	# the two fields of view. The vertical one alone is the narrower only
	# on a window wider than it is tall: a phone held upright framed the
	# model to its height and cut off both its sides.
	#
	# Of the part of the window the model is seen in, not of the window:
	# the field of view spans the window's height, and the seen rect is
	# less than that across and down. Framed to the window, the ball round
	# a model took 92% of the room a 1280 x 720 window gives it, where the
	# margin means it to take 76% (centring_probe).
	var seen_size: Vector2 = seen_rect().size
	var share: float = minf(seen_size.x, seen_size.y) / _room().y
	var half: float = atan(tan(deg_to_rad(fov) * 0.5) * share)
	_target_distance = clampf(
		radius / sin(half) * margin, min_distance, max_distance)
	if projection == Camera3D.PROJECTION_ORTHOGONAL:
		size = radius * 2.0 * margin / share


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
