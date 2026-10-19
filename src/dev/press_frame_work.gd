extends Node
## Work in a press's own frame, before the app's process sees the press, as
## a slow page does it: reading the bodies, or the grab's own process, in
## the frame that handles the press. Processed before every other node; the
## first frame [member pressed] says the press is in, it takes [member ms]
## and is done. A hold timed from the press counted that work as held: the
## flywheel was taken by its chain on m81's preview. Timed from the first
## frame that saw it still, it is not (grab_probe -- --only=chain,
## slow_frames_probe).

## Whether the press this works in is in, asked each frame.
var pressed: Callable
## How long the work takes, ms.
var ms: int = 600
## What it took, once done: 0 until then.
var took: int = 0


func _ready() -> void:
	process_priority = -2000000


func _process(_delta: float) -> void:
	if took == 0 and pressed.is_valid() and pressed.call():
		var began: int = Time.get_ticks_msec()
		OS.delay_msec(ms)
		took = Time.get_ticks_msec() - began
