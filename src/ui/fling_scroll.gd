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
## finger (Main makes it there, never on a desktop, whose wheel is its own).
## A finger's press and lift are heard by the window before anything in it,
## a dialog's and the parts bin's too (the bin scrolls itself, and its cell
## takes the lift). While the finger is down, every list showing is looked
## at once a frame. When the finger lifts moving, the speed the list went at
## over its last frames goes on and slows as iOS's does; Godot's own glide
## never starts, its drag cancelled (by setting its scroll) before the list
## hears the lift. Lifted still, as a person stops a list where they want
## it, the list stays where it is. A finger down again catches a gliding
## list where it is. Nothing is looked at once the glides end.
class_name FlingScroll
extends Node

## iOS's normal deceleration: what a throw's speed is a millisecond later.
const DECELERATION := 0.998
## The finger's speed as it lifts is the list's over this long, ms, or over
## its last three frames where they come further apart.
const WINDOW_MS := 100.0
## Still this long before it lifts, ms, and a frame or more: no throw.
const STILL_MS := 100.0
## A glide this slow has stopped, units a ms.
const STOPPED := 0.002

## Each ScrollContainer watched, by its id.
var _lists: Dictionary = {}
## A finger (or the mouse) is down, and whether it is a finger.
var _down: bool = false
var _by_touch: bool = false
## Each list showing while it is down: [usec, scroll] each frame, by its id.
var _seen: Dictionary = {}
## Each list gliding: [where it is, its speed in units a ms], by its id.
var _gliding: Dictionary = {}


func _ready() -> void:
	process_priority = 1000
	set_process(false)
	get_tree().node_added.connect(_on_added)
	get_tree().root.window_input.connect(_heard)
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
	list.gui_input.connect(_once.bind(list))


## A finger's move reaches a list once. On the web it comes twice: as a
## touch, which Godot hands on as a mouse's move too (DEVICE_ID_EMULATION),
## and as the page's pointermove, which Godot's web input reads as a
## mouse's own, with the finger's movement (a 100-point drag: ten
## pointermoves of type touch beside the ten touchmoves, their movementY 100
## in all). Both moved the list: it went twice as far as the finger, and a
## throw twice as fast. The second is taken here before the list hears it.
func _once(event: InputEvent, list: ScrollContainer) -> void:
	if _down and _by_touch and event is InputEventMouseMotion \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		list.accept_event()


## Every event the window has, before anything in it: a press catches the
## lists gliding and begins looking at the lists showing; a lift throws.
func _heard(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if press.pressed and not _down:
		_down = true
		_by_touch = press.device == InputEvent.DEVICE_ID_EMULATION
		_gliding.clear()
		_seen.clear()
		for id: int in _lists.keys():
			var list := (_lists[id] as WeakRef).get_ref() as ScrollContainer
			if list == null:
				_lists.erase(id)
			elif list.is_visible_in_tree():
				_seen[id] = []
		_look()
		set_process(true)
	elif not press.pressed and _down:
		_down = false
		_lifted()


func _process(delta: float) -> void:
	if _down:
		_look()
	_glide(delta * 1000.0)
	if not _down and _gliding.is_empty():
		set_process(false)


## Where each list looked at stands now.
func _look() -> void:
	var now: int = Time.get_ticks_usec()
	for id: int in _seen:
		var list := (_lists[id] as WeakRef).get_ref() as ScrollContainer
		if list == null:
			continue
		var seen: Array = _seen[id]
		seen.append([now, _scroll_of(list)])
		if seen.size() > 64:
			seen.remove_at(1)


## The finger lifted: each list it moved, moving still, thrown.
func _lifted() -> void:
	var now: int = Time.get_ticks_usec()
	for id: int in _seen:
		var list := (_lists[id] as WeakRef).get_ref() as ScrollContainer
		var seen: Array = _seen[id]
		if list == null or seen.is_empty():
			continue
		var at: Vector2 = _scroll_of(list)
		if seen.all(func(one: Array) -> bool: return one[1] == at):
			continue
		# Godot's glide never starts: a scroll set cancels the drag, before
		# the list hears the lift that would have begun it.
		list.scroll_horizontal = roundi(at.x)
		list.scroll_vertical = roundi(at.y)
		var speed: Vector2 = _thrown(seen, at, now)
		if speed != Vector2.ZERO:
			_gliding[id] = [at, speed]
	_seen.clear()


## How fast a list was going as the finger lifted, units a ms: the slope of
## its scroll against the clock over its last frames (least squares). 0
## when it stood still before the lift STILL_MS, and twice as long as
## between its last two moves.
##
## The frames' own looks, not the lift's: the moves a frame hears came in
## while the frame before it drew, so a frame's look is where the finger
## was as it began. The lift's look is where the finger was as it lifted,
## anywhere in the frame before; counted as the frame's, it made a throw
## half as fast where a browser draws in software, a frame 100 ms or more.
func _thrown(seen: Array, at: Vector2, now: int) -> Vector2:
	var last: Array = seen.back()
	# When the frames saw it move last, and the time between its last two
	# moves: a browser drawing in software sees a finger's moves a frame
	# apart, 100 ms and more.
	var moved: Array = []
	for n: int in range(seen.size() - 1, 0, -1):
		if seen[n][1] != seen[n - 1][1]:
			moved.append(int(seen[n][0]))
			if moved.size() == 2:
				break
	var apart: float = float(moved[0] - moved[1]) / 1000.0 if moved.size() == 2 else 0.0
	if at == last[1] and not moved.is_empty() \
			and float(now - int(moved[0])) / 1000.0 > maxf(STILL_MS, apart * 2.0):
		return Vector2.ZERO
	var gap: float = float(int(last[0]) - int(seen[maxi(0, seen.size() - 2)][0])) / 1000.0
	var window: float = maxf(WINDOW_MS, gap * 3.0)
	var used: Array = seen.filter(func(one: Array) -> bool:
		return float(int(last[0]) - int(one[0])) / 1000.0 <= window)
	# From the last look before it set off: a throw two frames long, where
	# a browser draws in software, is not slowed by the rest before it.
	while used.size() > 2 and used[1][1] == used[0][1]:
		used.pop_front()
	# Thrown within the last frame: from its look to the lift's.
	if used.size() < 2 or used[0][1] == last[1]:
		used = [last, [now, at]]
	var mean_t: float = 0.0
	var mean_at := Vector2.ZERO
	for one: Array in used:
		mean_t += float(int(one[0]) - now) / 1000.0 / used.size()
		mean_at += (one[1] as Vector2) / used.size()
	var top := Vector2.ZERO
	var bottom: float = 0.0
	for one: Array in used:
		var t: float = float(int(one[0]) - now) / 1000.0 - mean_t
		top += t * ((one[1] as Vector2) - mean_at)
		bottom += t * t
	return top / bottom if bottom > 0.0 else Vector2.ZERO


## Each list gliding, [param ms] on: its speed slowed as iOS's slows, and
## the way that took it, exactly, whatever the frames. A list scrolled by
## something else meanwhile, or hidden, stops.
func _glide(ms: float) -> void:
	if ms <= 0.0:
		return
	var kept: float = pow(DECELERATION, ms)
	var went: float = (1.0 - kept) / -log(DECELERATION)
	for id: int in _gliding.keys():
		var list := (_lists[id] as WeakRef).get_ref() as ScrollContainer
		var at: Vector2 = _gliding[id][0]
		if list == null or not list.is_visible_in_tree() \
				or _scroll_of(list) != Vector2(roundi(at.x), roundi(at.y)):
			_gliding.erase(id)
			continue
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
		list.scroll_horizontal = roundi(at.x)
		list.scroll_vertical = roundi(at.y)
		# Where the list took it: a list that cannot scroll that way stays.
		at = Vector2(at.x if list.scroll_horizontal == roundi(at.x) else float(list.scroll_horizontal),
			at.y if list.scroll_vertical == roundi(at.y) else float(list.scroll_vertical))
		if speed.length() < STOPPED:
			_gliding.erase(id)
		else:
			_gliding[id] = [at, speed]


static func _scroll_of(list: ScrollContainer) -> Vector2:
	return Vector2(list.scroll_horizontal, list.scroll_vertical)


## Whether a list is gliding now, for a check.
func gliding() -> bool:
	return not _gliding.is_empty()
