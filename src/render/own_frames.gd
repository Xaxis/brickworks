## How long each frame's own work took, whether or not it was drawn.
##
## A frame's work runs from the scene tree's process_frame to the renderer's
## frame_pre_draw. Drawing only what changed (IdleDraw), a frame that
## changes nothing on screen never reaches frame_pre_draw, and reading a
## model or weighing it changes nothing on screen: timed by the draw alone,
## the slowest frames went unrecorded. So a frame that draws nothing ends
## after every node's _process and whatever they deferred, and is reported
## when the next begins.
class_name OwnFrames
extends Node

## A frame's own work, in microseconds.
signal timed(spent_us: int)

var _began: int = 0
var _ended: int = 0


func _ready() -> void:
	# After every other node's _process.
	process_priority = 1000000
	get_tree().process_frame.connect(_begin)
	RenderingServer.frame_pre_draw.connect(_drawing)


func _begin() -> void:
	if _began != 0 and _ended != 0:
		timed.emit(_ended - _began)
	_began = Time.get_ticks_usec()
	_ended = 0


func _process(_delta: float) -> void:
	_end.call_deferred()


func _end() -> void:
	_ended = Time.get_ticks_usec()


func _drawing() -> void:
	if _began == 0:
		return
	timed.emit(Time.get_ticks_usec() - _began)
	_began = 0
