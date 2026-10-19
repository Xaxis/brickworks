extends RefCounted
## How long a press has been held still, by what the frames saw: from the
## first frame after the one that handled the press to the last frame that
## saw it still. Not by the clock: on a page drawing a frame a second, a
## press and its release or its drag come a frame apart. And not from the
## press, nor from the frame that handled it: that frame's own work, reading
## the bodies before its process or drawing slowly after it, is no hold.
## Timed from it, a quick drag on m81's preview took a flywheel by its chain
## (grab_flow), the press-and-move a frame apart reading as 0.6 s held.
## The chain's hold (main.gd), a finger's that takes a part off, and the
## view cube's buttons' (view_cube.gd) are timed by it.

var _came: bool = false
var _first_ms: int = -1
var _last_ms: int = -1


## A press came: nothing held yet.
func start() -> void:
	_came = false
	_first_ms = -1
	_last_ms = -1


## A frame's process saw the press still down where it began.
func saw() -> void:
	if not _came:
		# The frame that handled the press: it saw the press come.
		_came = true
		return
	_last_ms = Time.get_ticks_msec()
	if _first_ms < 0:
		_first_ms = _last_ms


## How long the frames saw it held, ms: 0 until the frames after the one
## that handled the press have seen it held.
func held_ms() -> int:
	return _last_ms - _first_ms
