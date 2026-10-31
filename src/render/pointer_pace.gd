## What the pointer is over, drawn at the pace the device draws.
##
## A step of the pointer onto another part outlines it, and that is a frame
## drawn: the whole view again, whatever else changed. On a device that
## draws a frame in a few milliseconds that is nothing. In a browser drawing
## in software it is the whole model in software: the rich car of the
## together check, on a floor of 49 baseplates (2.4 million triangles), took
## 180 to 550 ms a frame on the box, and a browser hands the page the
## mouse's next step only once the frame before it is drawn. So the owner's
## page there drew the outline at the mouse's first step, half way to the
## part it was going to, and saw the second step 412 ms after the mouse
## moved (median, 40 moves, rel-m229): the other person was told where the
## pointer was that much later, and the outline on the part the pointer
## stopped on came a second frame after that.
##
## So on a device whose drawn frames cost more than SLOW_MS, what the
## pointer is over is drawn in the first frame the pointer did not move in,
## or once it has waited as long as a drawn frame takes, so a long sweep is
## still followed: where the pointer comes to rest, not every place on its
## way. On a device that draws quickly it is drawn in the frame it changed,
## as before. What the pointer is over is known at once either way (a click
## acts on it, Together says it); only its drawing waits.
##
## A drawn frame's cost is the page's, from its drawing to the next frame:
## a browser holds the next frame until the one before is drawn, and in
## software it waits there, or in the next frame's drawing when frames are
## drawn back to back. The frame's own scripts are not counted: a probe's
## busy frames are not slow drawing.
class_name PointerPace
extends RefCounted

## A drawn frame dearer than this and the device draws slowly, as
## FrameBudget judges one.
const SLOW_MS := FrameBudget.SLOW_MS
## The drawn frames judged by: the middle of the last few, so one slow
## frame (a shader built, a model read in) is not the device's pace.
const KEPT := 3

static var _costs: Array[float] = []
static var _pretended: float = -1.0
static var _listening: bool = false
## When this process frame and the last one began, when the last drawing
## began and how many frames had been drawn then, and when the pointer last
## moved, in microseconds.
static var _frame_us: int = 0
static var _last_frame_us: int = 0
static var _draw_us: int = 0
static var _drawn: int = 0
static var _moved_us: int = -1


## Whether what the pointer is over may be drawn in this frame, asked for
## [param waited_ms] ago.
static func now(waited_ms: float) -> bool:
	_listen()
	var cost: float = drawn_ms()
	if cost <= SLOW_MS:
		return true
	if _moved_us <= _last_frame_us:
		return true
	return waited_ms >= cost


## What a drawn frame costs the page lately, in ms: 0 until a few have been
## drawn.
static func drawn_ms() -> float:
	if _pretended >= 0.0:
		return _pretended
	if _costs.size() < KEPT:
		return 0.0
	var sorted: Array[float] = _costs.duplicate()
	sorted.sort()
	return sorted[KEPT / 2]


## A device of [param ms] a drawn frame, for a probe, until it is told -1.
static func pretend(ms: float) -> void:
	_listen()
	_pretended = ms


static func _listen() -> void:
	if _listening:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_listening = true
	tree.root.window_input.connect(func(event: InputEvent) -> void: PointerPace._input(event))
	tree.process_frame.connect(func() -> void: PointerPace._frame())
	# The class's own function, not a lambda: the renderer outlives the
	# scripts, and a lambda still connected to it at exit aborted the quit
	# (core dumped, hover_cost_probe).
	RenderingServer.frame_pre_draw.connect(PointerPace._drawing)


static func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_moved_us = Time.get_ticks_usec()


static func _drawing() -> void:
	_draw_us = Time.get_ticks_usec()


static func _frame() -> void:
	var at: int = Time.get_ticks_usec()
	# A frame out of view is paced by the connector's clock, not drawn for
	# anyone (FrameBudget does not count it either).
	if Engine.get_frames_drawn() != _drawn and _draw_us > 0 and not FramePace.unwatched:
		_costs.append((at - _draw_us) / 1000.0)
		while _costs.size() > KEPT:
			_costs.remove_at(0)
	_drawn = Engine.get_frames_drawn()
	_last_frame_us = _frame_us
	_frame_us = at
