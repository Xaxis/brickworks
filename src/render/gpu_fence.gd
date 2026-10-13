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
## On the desktop a card does it in milliseconds and this returns at once.
class_name GpuFence
extends RefCounted

## Never longer than this, in ms: past it the read waits as it always did.
const LONGEST_MS := 120000

## Waits holding the drawing.
static var _holding: int = 0

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
	_holding += 1
	RenderingServer.render_loop_enabled = false
	while Time.get_ticks_msec() < until:
		await tree.process_frame
		if passed(fence):
			break
	_holding -= 1
	if _holding == 0:
		RenderingServer.render_loop_enabled = true
