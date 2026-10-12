## Drawing a frame only when something on screen changed.
##
## The app drew every frame whether or not anything had moved: about 5.5 ms
## of a desktop graphics card (RX 6700 XT) sixty times a second, and much
## more of a laptop's, while somebody only looked at a model, so fans spun
## and batteries drained (2026-10-11).
##
## Godot's low-processor mode draws a frame only when something was written
## to the RenderingServer since the last one: the camera moved, a brick put
## down, a step of the build animation, the ghost under the pointer, a
## button lit by the pointer, a part's picture, a shader that reads TIME
## while it is on screen (the loading shimmer). Everything else still runs
## every frame: the connector's clock out of view, the command socket,
## FramePace's slices. Only the drawing waits.
##
## So nothing may write to the RenderingServer every frame for nothing. A
## value set again unchanged is a frame drawn: the camera set its pose every
## frame, the axis gizmo redrew itself and the pivot mark rebuilt its lines.
## src/dev/idle_probe.gd counts the frames drawn with nothing happening, and
## when there are any it names the node whose processing draws them.
##
## And on the desktop, frames come no faster than the display's sixty while
## nothing is drawn or worked on: a frame that draws nothing is still the
## scripts run, and at Godot's 144 a second that was a tenth of a core for a
## model standing still. Anything drawn, or a slice of FramePace work, wakes
## it to 144 for half a second. A browser paces the page itself.
class_name IdleDraw
extends RefCounted

## Microseconds a frame at least, drawing or working, and standing still.
const AWAKE_USEC := 6900
const ASLEEP_USEC := 16666
## How long a frame drawn or a slice worked keeps it awake.
const AWAKE_MS := 500

static var _awake_until: int = 0
static var _drawn: int = 0
static var _pacing: bool = false


## As the app runs: on, but not in a probe that did not turn it on itself.
## Most probes count on a frame drawn for every frame they wait, and await
## frame_post_draw several times over with nothing changing in between.
static func for_the_app() -> void:
	if OS.get_cmdline_args().has("--script") and not OS.low_processor_usage_mode:
		return
	begin()


static func begin() -> void:
	OS.low_processor_usage_mode = true
	# On the web the browser paces the frames (requestAnimationFrame, or the
	# connector's clock while the tab is out of view), and the page's one
	# thread cannot sleep: a sleep there is a spin.
	if OS.has_feature("web"):
		OS.low_processor_usage_mode_sleep_usec = 0
		return
	keep_awake()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and not _pacing:
		_pacing = true
		tree.process_frame.connect(func() -> void: IdleDraw._pace())


## Every frame drawn, as before: for a benchmark, which measures the cost of
## a frame and so must draw them.
static func end() -> void:
	OS.low_processor_usage_mode = false


## Something is being worked on: frames at full rate for a while.
static func keep_awake() -> void:
	_awake_until = Time.get_ticks_msec() + AWAKE_MS


static func _pace() -> void:
	if Engine.get_frames_drawn() != _drawn:
		_drawn = Engine.get_frames_drawn()
		keep_awake()
	OS.low_processor_usage_mode_sleep_usec = AWAKE_USEC \
		if Time.get_ticks_msec() < _awake_until else ASLEEP_USEC
