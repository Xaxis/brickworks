## How much room there is, in the unit a person would use.
##
## Points on the desktop, CSS pixels in a browser — the same thing: the
## size a thing appears, not the number of pixels it is drawn with. A
## phone reports three device pixels to the point and an ordinary
## monitor reports one, so a measurement in pixels says a phone is
## wider than a laptop.
##
## Which it did. The test for "is there room for both panels" divided
## the canvas by the app's own content scale, and that scale is the
## device ratio capped at two — so a screen at three to one came out
## half as wide as it is rather than a third, and an eight-hundred-point
## phone held sideways measured as roomier than the threshold. Both
## panels stayed open across a screen with no room for either.
class_name Room
extends RefCounted


static func across() -> float:
	if OS.has_feature("web"):
		# The browser knows, and nothing derived from the canvas does:
		# the canvas is sized in device pixels and the ratio between
		# them is exactly what is being asked about.
		var reported: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		if reported != null and float(reported) > 0.0:
			return float(reported)
	# Godot reports a desktop window in screen coordinates, which are
	# already points; the high-resolution framebuffer is separate.
	return float(DisplayServer.window_get_size().x)


static func down() -> float:
	if OS.has_feature("web"):
		var reported: Variant = JavaScriptBridge.eval("window.innerHeight", true)
		if reported != null and float(reported) > 0.0:
			return float(reported)
	return float(DisplayServer.window_get_size().y)
