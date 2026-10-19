## Drawing less on a device whose frames are slow, and nothing less on one
## whose frames are not.
##
## A frame drawn in software (a browser on SwiftShader, which is what a
## weak device is here) costs 0.5 to 3 s whatever is happening in it: the
## sun's 4096² shadow atlas, the model four samples deep and resolved, glow,
## the interface (docs/MECHANISMS.md, swingtrace). The app's own work in
## such a frame is a few milliseconds. So what lowers a slow frame is what
## the frame draws.
##
## Every drawn frame that follows a drawn frame is timed: from the end of
## one drawing to the end of the next, less that frame's own work (its
## scripts, from process_frame to drawing). On a graphics card that is the
## display's pace, 7 to 17 ms. Two seconds after the window is up the app
## draws a few frames on purpose and times them, and it goes on timing every
## frame it draws anyway. When the fastest fifth of the last few frames is
## still over SLOW_MS, the next of CUTS is made, and the frames after it
## timed again: the order is what buys the most for the least seen
## (measured in docs/SLOW_DEVICES.md). A device that never draws a slow
## frame never has anything cut, and nothing here writes to the renderer
## until something is.
##
## In a browser a frame's timing is when it was handed to the browser's GPU
## process, which draws it later: in software a dozen frames can be handed
## over at the display's 17 ms each while each takes 0.4 to 2 s to draw. So
## on the web a look ends with a fence (GpuFence) after its frames, and is
## judged again by when the drawing was done.
##
## Only lowered, never raised again in a session: a device slow once is
## slow, and raising it to find out costs the slow frames again.
##
## Probes leave it off unless they turn it on (watch()), as IdleDraw: a
## windowed probe drawn in software would otherwise see the look it checks
## lowered under it.
class_name FrameBudget
extends Node

## What a drawn frame may cost before the device is slow, in ms.
const SLOW_MS := 50.0
## How many timed frames a judgment takes, and which of them, fastest
## first, it judges by (the fastest fifth: a capable device's few long
## frames, a shader compiled or a model read in, never count).
const JUDGED := 6
const JUDGED_BY := 1
## When the first look is taken, in ms after the window is up, and how
## many frames it may draw for it.
const FIRST_LOOK_MS := 2000
const LOOK_FRAMES := 10
## The first frames of a look, before any is timed: shaders compiled for
## the first time cost more than a frame does.
const WARM_FRAMES := 2

## What is cut, in order. Each is a thing the frame stops drawing:
## "dense": on a screen of more than one device pixel to the point (a
##   phone's 3x), the 3D drawn at one pixel to the point and stretched, the
##   interface still at full sharpness; nothing at one to one;
## "scale": the 3D drawn at SCALE of a pixel to the point, and stretched;
## "msaa": the model's edges no longer drawn four samples deep;
## "glow": the glow round bright faces;
## "shadow": the sun's shadow itself, its light brought up to match;
## "ssao": the occlusion in corners (Forward+ only; the web has none).
## Ordered by what each bought in a browser drawing in software, paired
## with the build before (docs/SLOW_DEVICES.md): dense and scale about
## halved a frame, msaa took a third off (half with a model in), the shadow
## a fifth, glow next to nothing. msaa goes before scale: on a laptop it
## bought as much, and edges drawn one sample deep are seen far less than
## the whole view drawn at half. The sun's shadow filtered harder and its
## atlas made smaller were rungs once; they bought no more than the shadow
## gone, and both are the RenderingServer's for every light, so they would
## have lowered the photo-real render's shadows too.
const CUTS: Array[String] = ["ssao", "dense", "msaa", "scale", "shadow", "glow"]
## Pixels to the point the 3D is drawn at when "scale" is cut.
const SCALE := 0.5
## Cuts a check may make that are no part of the ladder: "ui", the
## interface not drawn, to measure what it costs.
const MEASURE_ONLY: Array[String] = ["ui"]

## Whether frames are timed and cuts made.
var watching: bool = false
## The cuts in force, in the order made.
var cuts: Array[String] = []
## The cuts a check set itself (pin), which nothing changes until it is
## let go again.
var pinned: bool = false
## Timed frames, ms, the newest last.
var timed: Array[float] = []
## What was judged and when: [ms since start, the judged cost, cuts after].
var judged: Array = []
## How many looks have been taken.
var looks: int = 0
## What a frame of the last look cost by its fence, in ms, or -1.
var fenced: float = -1.0

var _viewport: Viewport = null
var _environment: Environment = null
var _sun: DirectionalLight3D = null
var _sun_energy: float = 0.0
var _sun_energy_unshadowed: float = 0.0
var _ladder: Array[String] = []
var _ratio: float = 1.0
## The frame timing: when this process frame began, when its drawing
## began, and the end of the last drawing and which process frame it was.
var _began_us: int = 0
var _own_us: int = 0
var _last_drawn_us: int = 0
var _last_drawn_frame: int = -1
## Frames left to time for a look, warm frames to skip, and the frames a
## look has drawn and may draw.
var _looking: int = 0
var _warm: int = 0
var _look_drawn: int = 0
var _look_most: int = 0
## The look's fence (GpuFence, on the web): when the look began, its
## frames' own work, whether any was drawn apart from the one before, and
## the fence once it is put in after its last frame.
var _look_began_us: int = 0
var _look_own_us: int = 0
var _look_apart: bool = false
var _look_open: bool = false
var _fence: int = 0
var _first_look_at: int = 0
var _since_cut: int = 0


## [viewport] is the window's, [environment] the world's, [sun] the light
## whose shadow may go; [sun_energy_unshadowed] what its energy is when it
## casts none, which on the web is not what it is when it does
## (BrickWorld.light_energy).
func setup(viewport: Viewport, environment: Environment, sun: DirectionalLight3D,
		sun_energy_unshadowed: float) -> void:
	_viewport = viewport
	_environment = environment
	_sun = sun
	_sun_energy = sun.light_energy
	_sun_energy_unshadowed = sun_energy_unshadowed
	_ratio = device_ratio()
	_ladder = ladder_for(RenderingServer.get_current_rendering_method(), _ratio)


## As the app runs: on, but not in a probe that did not turn it on itself.
func for_the_app() -> void:
	if OS.get_cmdline_args().has("--script") or DisplayServer.get_name() == "headless":
		return
	watch()


## Time the frames, and cut when they are slow.
func watch() -> void:
	if watching:
		return
	watching = true
	process_priority = -1000000
	get_tree().process_frame.connect(_frame_begins)
	RenderingServer.frame_pre_draw.connect(_drawing)
	RenderingServer.frame_post_draw.connect(_drawn)
	_first_look_at = Time.get_ticks_msec() + FIRST_LOOK_MS


## The cuts this renderer and screen have: the web's Compatibility draws
## no occlusion, and a screen of a pixel to the point has nothing to make
## less dense, so cutting either would buy nothing and spend a judgment.
static func ladder_for(method: String, ratio: float) -> Array[String]:
	var ladder: Array[String] = []
	for cut: String in CUTS:
		if cut == "ssao" and method == "gl_compatibility":
			continue
		if cut == "dense" and ratio <= 1.25:
			continue
		ladder.append(cut)
	return ladder


## The cut a judgment of [cost] ms a frame makes next: one, or, when the
## frames are many times over, more at once, so a device at two seconds a
## frame is not made to sit through a judgment per cut.
static func cuts_for(cost: float) -> int:
	if cost <= SLOW_MS:
		return 0
	if cost > SLOW_MS * 16.0:
		return 3
	if cost > SLOW_MS * 4.0:
		return 2
	return 1


## The judged cost of [samples]: the JUDGED_BY'th fastest of the last JUDGED.
static func judge(samples: Array[float]) -> float:
	if samples.size() < JUDGED:
		return -1.0
	var last: Array[float] = []
	last.assign(samples.slice(-JUDGED))
	last.sort()
	return last[JUDGED_BY]


func _frame_begins() -> void:
	_began_us = Time.get_ticks_usec()
	_own_us = 0
	if _look_open and _looking == 0:
		_look_open = false
		# A look held apart (GpuFence) waited between its frames: its time
		# to the fence is not its frames' cost.
		_fence = 0 if _look_apart else GpuFence.put()
	if _fence > 0 and GpuFence.passed(_fence):
		_fence = 0
		_fenced_look()
	if _looking > 0:
		# Drawing on purpose: a write to the renderer, of what it already
		# has, is a frame drawn (IdleDraw).
		RenderingServer.viewport_set_clear_mode(_viewport.get_viewport_rid(),
			RenderingServer.VIEWPORT_CLEAR_ALWAYS)
		return
	if pinned:
		return
	if _first_look_at > 0 and Time.get_ticks_msec() >= _first_look_at:
		_first_look_at = 0
		look()


## Draw frames on purpose until [frames] of them are timed.
##
## Only a frame drawn right after a drawn frame is timed, and the drawing
## can be held between two (GpuFence, while the parts bin's pictures are
## read back), so a look counts the frames it timed, not the frames it
## drew. Held apart every time, it ends after three times as many drawn,
## with what it has: a look that ended at ten drawn with two of them timed
## left a check waiting for a third forever (2026-10-19).
##
## And on the web a look ends with a fence after its frames, and is judged
## again by when the fence passes. A browser hands each frame to its GPU
## process and goes on: in software the frames it timed were a dozen at the
## display's 17 ms, and SwiftShader then took 0.4 to 2 s to draw each one
## (docs/SLOW_DEVICES.md). On the desktop there is no fence, and the
## timing is the drawing's.
func look(frames: int = LOOK_FRAMES) -> void:
	looks += 1
	_looking = frames
	_warm = WARM_FRAMES
	_look_drawn = 0
	_look_most = (frames + WARM_FRAMES) * 3
	_look_began_us = Time.get_ticks_usec()
	_look_own_us = 0
	_look_apart = false
	_look_open = true
	_fence = 0
	timed.clear()


## The look's fence passed: what each of its frames cost, less their own
## work, and cut by that where the frames timed said quick.
func _fenced_look() -> void:
	if _look_drawn < 2:
		return
	var spent_us: int = Time.get_ticks_usec() - _look_began_us - _look_own_us
	fenced = snappedf(spent_us / 1000.0 / _look_drawn, 0.1)
	if pinned or cuts_for(fenced) == 0:
		return
	_decide(fenced)


func _drawing() -> void:
	if _began_us != 0:
		_own_us = Time.get_ticks_usec() - _began_us


func _drawn() -> void:
	var now: int = Time.get_ticks_usec()
	var frame: int = Engine.get_process_frames()
	var follows: bool = _last_drawn_frame >= 0 and frame == _last_drawn_frame + 1
	var spent_us: int = now - _last_drawn_us - _own_us
	_last_drawn_us = now
	_last_drawn_frame = frame
	if _looking > 0:
		_look_drawn += 1
		_look_own_us += _own_us
		if _look_drawn > 1 and not follows:
			_look_apart = true
		if _look_drawn >= _look_most:
			_looking = 0
	# A frame out of view is paced by the connector's clock, not drawn for
	# anyone (Main._watch_view): not this device's speed.
	if not follows or FramePace.unwatched:
		return
	if _warm > 0:
		_warm -= 1
		return
	if _looking > 0:
		_looking -= 1
	take(spent_us / 1000.0)


## A drawn frame's cost, [ms]: kept, and the last few judged once there
## have been enough since the last cut.
func take(ms: float) -> void:
	timed.append(ms)
	while timed.size() > JUDGED * 2:
		timed.remove_at(0)
	_since_cut += 1
	if pinned or _since_cut < JUDGED:
		return
	var cost: float = judge(timed)
	if cost < 0.0:
		return
	_decide(cost)


## Judged [cost] ms a frame: under SLOW_MS nothing is cut and the look ends;
## over it, the next rungs, more the further over, and a look at once.
func _decide(cost: float) -> void:
	var more: int = cuts_for(cost)
	if more == 0 or cuts.size() >= _ladder.size():
		_looking = 0
		return
	var next: Array[String] = cuts.duplicate()
	for cut: String in _ladder:
		if next.size() >= cuts.size() + more:
			break
		if not next.has(cut):
			next.append(cut)
	judged.append([Time.get_ticks_msec(), snappedf(cost, 0.1), next])
	_apply(next)
	# And look again at once, at what is drawn now.
	look()


## A check's own cuts, held until let go: [wanted] are cut, in that order,
## and nothing is judged.
func pin(wanted: Array[String]) -> void:
	pinned = true
	_looking = 0
	_apply(wanted)


## Let a check's cuts go: back to what was judged before, and judging.
func unpin() -> void:
	pinned = false
	var kept: Array[String] = []
	for entry: Array in judged:
		kept.assign(entry[2])
	_apply(kept)


## What the page is told (Main._tell_page): the cuts in force, the last
## frames timed and the judgments made.
func page_state() -> Dictionary:
	return {"cuts": cuts, "pinned": pinned, "watching": watching,
		"timed": timed.map(func(ms: float) -> float: return snappedf(ms, 0.1)),
		"cost": snappedf(judge(timed), 0.1), "judged": judged,
		"ladder": _ladder, "looking": _looking, "looks": looks, "fenced": fenced,
		"drawn": Engine.get_frames_drawn()}


func _apply(wanted: Array[String]) -> void:
	var scale_was: float = _scale_for(cuts)
	for cut: String in CUTS + MEASURE_ONLY:
		var on: bool = wanted.has(cut)
		if on != cuts.has(cut):
			_set_cut(cut, on)
	if _scale_for(wanted) != scale_was:
		_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		_viewport.scaling_3d_scale = _scale_for(wanted)
	cuts.assign(wanted)
	_since_cut = 0


func _set_cut(cut: String, on: bool) -> void:
	match cut:
		"ssao":
			_environment.ssao_enabled = not on
		"glow":
			_environment.glow_enabled = not on
		"msaa":
			_viewport.msaa_3d = Viewport.MSAA_DISABLED if on \
				else ProjectSettings.get_setting_with_override("rendering/anti_aliasing/quality/msaa_3d") as Viewport.MSAA
		"dense", "scale":
			pass
		"shadow":
			_sun.shadow_enabled = not on
			_sun.light_energy = _sun_energy_unshadowed if on else _sun_energy
		"ui":
			_viewport.canvas_cull_mask = 0 if on else 0xFFFFFFFF


## The 3D's scale with [these] cuts: whole, one pixel to the point
## ("dense"), or SCALE of one ("scale").
func _scale_for(these: Array[String]) -> float:
	var per_point: float = 1.0 / _ratio
	if these.has("scale"):
		return minf(1.0, SCALE * per_point)
	if these.has("dense"):
		return minf(1.0, per_point)
	return 1.0


## Device pixels to the point: a browser's devicePixelRatio, and the
## screen's scale on the desktop.
static func device_ratio() -> float:
	var ratio: float = 1.0
	if OS.has_feature("web"):
		var said: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
		if said != null:
			ratio = float(said)
	elif DisplayServer.get_name() != "headless":
		ratio = DisplayServer.screen_get_scale()
	return maxf(ratio, 1.0)
