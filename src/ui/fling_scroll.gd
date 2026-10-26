## A list thrown by a finger glides as a phone's does, and no further.
##
## Godot's ScrollContainer slows a throw by a fixed 1,000 units a second,
## every second, so its glide grows as the square of the speed it was thrown
## at: on a phone (1.85 units a point) 925 points at 1 point a millisecond,
## 3,700 at 2 and 14,800 at 4. A medium 434-point drag lifted moving threw
## More's list 8,500 points, end to end (first258), and no list could be
## flicked to where a person wanted it. A thumb expects a phone's glide:
## iOS's UIScrollView slows a throw by 0.2% a millisecond (its "normal"
## deceleration, 0.998 a ms), so a throw goes on as far as about 500 ms of
## the speed it left the finger at: 250 points at 0.5 points a ms, 500 at
## 1, 1,000 at 2 and 2,000 at 4. Android's OverScroller is shorter still at
## a slow throw and about the same at a fast one.
##
## One place for every list and panel that scrolls in the layout for a
## finger (Main makes it there, never on a desktop, whose wheel is its own):
## every ScrollContainer, in the window and in every window over it, is
## heard as a finger presses, moves and lifts on it (its gui_input, which a
## press on a row in it reaches as the list does). The drag itself is
## Godot's, a point for a point under the finger. When the finger lifts
## moving, the speed the list went at over its last WINDOW_MS goes on and
## slows as iOS's does; Godot's own glide never starts, the drag cancelled
## (by setting its scroll) before the list hears the lift. Lifted after
## STILL_MS with no movement, as a person stops a list where they want it,
## the list stays where it is. A finger down again catches a gliding list
## where it is.
class_name FlingScroll
extends Node

## iOS's normal deceleration: what a throw's speed is a millisecond later.
const DECELERATION := 0.998
## The finger's speed as it lifts is the list's over this long, ms.
const WINDOW_MS := 80
## Still this long before it lifts, ms: no throw.
const STILL_MS := 100
## A glide this slow has stopped, units a ms.
const STOPPED := 0.002

## Each ScrollContainer watched, by its id.
var _lists: Dictionary = {}
## Each list a finger is down on: its [ms, scroll] each frame it moved,
## the last of them, by its id.
var _seen: Dictionary = {}
## Each list gliding: [where it is, its speed in units a ms], by its id.
var _gliding: Dictionary = {}


func _ready() -> void:
	process_priority = 1000
	get_tree().node_added.connect(_on_added)
	_watch(get_tree().root)


func _watch(node: Node) -> void:
	_on_added(node)
	for child: Node in node.get_children(true):
		_watch(child)


func _on_added(node: Node) -> void:
	var list := node as ScrollContainer
	if list == null or _lists.has(list.get_instance_id()):
		return
	_lists[list.get_instance_id()] = weakref(list)
	list.gui_input.connect(_heard.bind(list.get_instance_id()))


## What a list hears from a finger, before the list does: a press catches
## it, a lift throws it.
##
## And a finger's move once. On the web it comes twice: as a touch, which
## Godot hands on as a mouse's move too (DEVICE_ID_EMULATION), and as the
## page's pointermove, which Godot's web input reads as a mouse's own, with
## the finger's movement (a 100-point drag: ten pointermoves of type touch
## beside the ten touchmoves, their movementY 100 in all). Both moved the
## list: it went twice as far as the finger, and a throw twice as fast.
## The second is taken here before the list hears it.
func _heard(event: InputEvent, id: int) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if motion.device != InputEvent.DEVICE_ID_EMULATION:
			var list := (_lists.get(id, weakref(null)) as WeakRef).get_ref() as ScrollContainer
			if list != null:
				list.accept_event()
		return
	var press := event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if press.pressed:
		_gliding.erase(id)
		_seen[id] = []
		_look(id)
	elif _seen.has(id):
		_look(id)
		_lifted(id)


func _process(delta: float) -> void:
	for id: int in _seen.keys():
		_look(id)
	_glide(delta * 1000.0)


## Where a list a finger is down on stands now, if it has moved.
func _look(id: int) -> void:
	var list := (_lists.get(id, weakref(null)) as WeakRef).get_ref() as ScrollContainer
	if list == null:
		_seen.erase(id)
		return
	var now: int = Time.get_ticks_msec()
	var at := Vector2(list.scroll_horizontal, list.scroll_vertical)
	var seen: Array = _seen[id]
	if seen.is_empty() or (seen.back() as Array)[1] != at:
		seen.append([now, at])
		while seen.size() > 2 and now - int((seen[1] as Array)[0]) > WINDOW_MS * 2:
			seen.pop_front()


## The finger lifted off a list: moving still, thrown.
func _lifted(id: int) -> void:
	var seen: Array = _seen[id]
	_seen.erase(id)
	var list := (_lists.get(id, weakref(null)) as WeakRef).get_ref() as ScrollContainer
	if list == null or seen.size() < 2:
		return
	var last: Array = seen.back()
	var at: Vector2 = last[1]
	# Godot's glide never starts: a scroll set cancels the drag, before the
	# list hears the lift that would have begun it.
	list.scroll_horizontal = roundi(at.x)
	list.scroll_vertical = roundi(at.y)
	if Time.get_ticks_msec() - int(last[0]) > STILL_MS:
		return
	# The speed over the last WINDOW_MS it moved: from the first look in
	# that time, or the one just before it.
	var first: Array = seen[0]
	for one: Variant in seen:
		if int(last[0]) - int((one as Array)[0]) <= WINDOW_MS:
			break
		first = one
	var took: float = float(int(last[0]) - int(first[0]))
	print("FLINGDEBUG seen=%s first=%s took=%s" % [str(seen.slice(-6)), str(first), took])
	if took > 0.0:
		_gliding[id] = [at, (at - (first[1] as Vector2)) / took]


## Each list gliding, [param ms] on: its speed slowed as iOS's slows, and
## the way that took it, exactly, whatever the frames.
func _glide(ms: float) -> void:
	if ms <= 0.0:
		return
	var kept: float = pow(DECELERATION, ms)
	var went: float = (1.0 - kept) / -log(DECELERATION)
	for id: int in _gliding.keys():
		var list := (_lists.get(id, weakref(null)) as WeakRef).get_ref() as ScrollContainer
		if list == null or not list.is_visible_in_tree():
			_gliding.erase(id)
			continue
		var at: Vector2 = _gliding[id][0]
		var speed: Vector2 = _gliding[id][1]
		at += speed * went
		speed *= kept
		# Stopped at either end, as a thrown list stops there.
		var most := Vector2(maxf(0.0, list.get_h_scroll_bar().max_value - list.get_h_scroll_bar().page),
			maxf(0.0, list.get_v_scroll_bar().max_value - list.get_v_scroll_bar().page))
		for axis: int in 2:
			if at[axis] <= 0.0 or at[axis] >= most[axis]:
				at[axis] = clampf(at[axis], 0.0, most[axis])
				speed[axis] = 0.0
		if list.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			list.scroll_horizontal = roundi(at.x)
		if list.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			list.scroll_vertical = roundi(at.y)
		if speed.length() < STOPPED:
			_gliding.erase(id)
		else:
			_gliding[id] = [at, speed]


## Whether a list is gliding now, for a check.
func gliding() -> bool:
	return not _gliding.is_empty()
