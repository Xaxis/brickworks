## Was that a trackpad or a mouse wheel?
##
## On a Mac the window tells you: two-finger scrolling arrives as a pan
## gesture and pinching as a magnify gesture, each unmistakable. In a
## browser it does not. Both come through as wheel events, so a camera
## that treats every wheel as a mouse wheel gives a laptop the one
## gesture it did not want — and the web build is the one most people
## use.
##
## They are still distinguishable, just not by type. A trackpad reports
## small deltas, often fractional, in a dense stream. A wheel reports
## large whole ones, usually a multiple of a hundred or so. And a pinch
## arrives as a wheel event with ctrl held, which nothing else does.
##
## The reading is sticky for a moment, because a fast swipe accelerates
## into deltas as large as a wheel click's and would otherwise change
## its mind halfway through.
class_name WheelKind
extends RefCounted

const TRACKPAD := 1
const PINCH := 2

## How long a trackpad stays believed after the last small delta, in
## milliseconds — long enough to cover the accelerated middle of a
## swipe, short enough that picking up a mouse is noticed.
const STICKY_MS := 1500

static var _ready: bool = false


static func install() -> void:
	if _ready or not OS.has_feature("web"):
		_ready = true
		return
	_ready = true
	# Concatenated rather than formatted: the script uses the remainder
	# operator, and GDScript's % would try to read that as a placeholder.
	JavaScriptBridge.eval("""
		(function () {
			if (window.__bwWheel) { return; }
			var state = { trackpad: 0, pinch: 0, seen: 0 };
			window.__bwWheel = state;
			window.addEventListener('wheel', function (e) {
				state.pinch = e.ctrlKey ? 1 : 0;
				var size = Math.abs(e.deltaY) + Math.abs(e.deltaX);
				// deltaMode 0 is pixels, which is what a trackpad sends;
				// a wheel reporting lines or pages is a wheel.
				var fine = e.deltaMode === 0
					&& (size < 50 || (e.deltaY % 1) !== 0);
				if (fine) { state.seen = Date.now(); }
				state.trackpad =
					(Date.now() - state.seen) < STICKY ? 1 : 0;
			}, { capture: true, passive: true });
		})();
	""".replace("STICKY", str(STICKY_MS)), true)


## What the last wheel event looked like, as a bitfield. Zero on a
## desktop build, where the question does not arise: a pan gesture is a
## trackpad and a wheel is a wheel.
static func last() -> int:
	if not OS.has_feature("web"):
		return 0
	if not _ready:
		install()
	var value: Variant = JavaScriptBridge.eval(
		"window.__bwWheel ? (window.__bwWheel.trackpad | "
		+ "(window.__bwWheel.pinch << 1)) : 0", true)
	return int(value) if value != null else 0
