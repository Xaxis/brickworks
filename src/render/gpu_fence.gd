## Waiting for the graphics card to finish what has been asked of it, with
## the page going on meanwhile.
##
## Reading a picture back (Image from a ViewportTexture) waits for the
## card to finish everything queued before it. In a browser drawing in
## software that is the whole picture rasterised, on the page's one thread:
## the owner's 4,242-part Falcon held the page 27 to 33 s a picture
## (2026-10-11, tools/web/freeze_check.mjs), and Claude's next call waited
## behind it. WebGL 2 has fences: one put in after the picture's draw is
## signalled when the card has done it, and asking whether it has does not
## wait. So the page asks once a frame, and reads the picture back when the
## card is done, which then costs nothing.
##
## And nothing more is drawn while it waits. During a design something on
## screen changes every frame (the run's clock, a progress line), and each
## frame drawn in software queued another two or three seconds of the whole
## model behind the picture: measured, the fence came 33 s after it was put
## in and the read after it still waited 23 s for the frames drawn
## meanwhile. Held, the page goes on running and answering, and the screen
## is drawn again, once, when the picture is read.
##
## Except for what a person does. The parts bin reads its pictures back this
## way too, eight at a time, and over Orthanc in Chromium on SwiftShader its
## first eight held the drawing from the model opening to 30 s and more after
## it: a click on the white wizard selected him at once, and the window went
## on showing the frame from before the click, "nothing selected" and no
## outline, until the fences came (2026-10-14, tools/web/outline_check.mjs).
## So a key, a click or the pointer moving is drawn held or not: the frame it
## changes, and whatever else changes in the ANSWER_MS after it.
##
## On the desktop a card does it in milliseconds and this returns at once.
class_name GpuFence
extends RefCounted

## Never longer than this, in ms: past it the read waits as it always did.
const LONGEST_MS := 120000

## Waits holding the drawing.
static var _holding: int = 0

## How long after a person's input the drawing is let go, in ms: the frame
## the input changed, and anything it set going (a panel filled in, a line
## in the status bar) drawn with it.
const ANSWER_MS := 500

## When the person last did something, and how many frames had been drawn
## then: until one more is drawn, or ANSWER_MS have gone, it is drawn.
static var _asked_at: int = -1_000_000
static var _drawn_when_asked: int = -1
static var _listening: bool = false

## Fences by number, kept by the page, and the next number.
const _PUT := """(function () {
	var canvas = document.getElementById('canvas') || document.querySelector('canvas');
	var gl = canvas && canvas.getContext('webgl2');
	if (!gl || !gl.fenceSync) return 0;
	var all = window.brickworksFences || (window.brickworksFences = { next: 1, gl: gl });
	var n = all.next++;
	all[n] = gl.fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0);
	gl.flush();
	return n;
})()"""
const _ASK := """(function (n) {
	var all = window.brickworksFences;
	var fence = all && all[n];
	if (!fence) return true;
	var gl = all.gl;
	if (gl.getSyncParameter(fence, gl.SYNC_STATUS) !== gl.SIGNALED) return false;
	gl.deleteSync(fence);
	delete all[n];
	return true;
})(%d)"""


## A fence after everything asked of the card so far: its number, or 0
## where there are none (the desktop, or no WebGL 2).
static func put() -> int:
	if not OS.has_feature("web"):
		return 0
	return int(JavaScriptBridge.eval(_PUT, true))


## Whether the card has done what was asked of it before fence [param n]
## was put in. Asking does not wait.
static func passed(n: int) -> bool:
	return n <= 0 or bool(JavaScriptBridge.eval(_ASK % n, true))


## Until the card has done what was asked of it before now. A coroutine:
## await it.
static func finished() -> void:
	var fence: int = put()
	if fence <= 0:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var until: int = Time.get_ticks_msec() + LONGEST_MS
	_listen(tree)
	_holding += 1
	RenderingServer.render_loop_enabled = _answering()
	while Time.get_ticks_msec() < until:
		await tree.process_frame
		if passed(fence):
			break
	_holding -= 1
	if _holding == 0:
		RenderingServer.render_loop_enabled = true


## Once: every input the window gets, and a look each frame at whether the
## drawing may go on.
static func _listen(tree: SceneTree) -> void:
	if _listening:
		return
	_listening = true
	tree.root.window_input.connect(func(_event: InputEvent) -> void: GpuFence._asked())
	tree.process_frame.connect(func() -> void: GpuFence._decide())


static func _asked() -> void:
	_asked_at = Time.get_ticks_msec()
	_drawn_when_asked = Engine.get_frames_drawn()
	if _holding > 0:
		RenderingServer.render_loop_enabled = true


static func _decide() -> void:
	if _holding > 0:
		RenderingServer.render_loop_enabled = _answering()


## Whether a person's input is still to be drawn: no frame since it, or
## within ANSWER_MS of it.
static func _answering() -> bool:
	return Engine.get_frames_drawn() == _drawn_when_asked \
		or Time.get_ticks_msec() - _asked_at < ANSWER_MS
