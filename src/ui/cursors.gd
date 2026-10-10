## The pointer, saying what the mouse will do and what it is doing.
##
## Asked for by the owner: "the app's cursor should change based on which
## function is being performed." It was the system arrow everywhere, so
## nothing on screen said whether a click would put a brick down, whether
## the right button was about to take one off or turn the view, or that
## the part just picked was still on its way and a click would do nothing.
##
## One state at a time, worked out afresh every frame by [method choose]
## from what is true now, and shown through Godot's default cursor shape:
## the shape the window uses wherever no control is under the pointer,
## which is exactly the model. Panels, text fields and buttons keep their
## own (an I-beam, a pointing hand), because the control under the
## pointer always wins over the default.
##
## Polled, not switched by events, because every stale cursor is an
## ending that never arrived: a drag let go outside the window, a dialog
## closed by a key with the pointer standing still, Escape. Asking "what
## is true now" every frame cannot miss an ending. The camera and the box
## select already keep watch over their own lost releases (see
## CadCamera._process and Main._process), so following their state
## follows those fixes too.
class_name Cursors
extends CanvasLayer

## Which system shape each state is shown as.
##
## Godot hangs a custom picture on a shape rather than offering cursors
## of its own, so the states with a picture borrow shapes this interface
## never shows: nothing in it drags and drops, resizes or asks for help.
## The borrowed shape is also the fallback if the picture cannot be
## drawn, so each is the nearest system one to what it stands for.
const SHAPES := {
	"arrow": Input.CURSOR_ARROW,
	"place": Input.CURSOR_CAN_DROP,
	"blocked": Input.CURSOR_FORBIDDEN,
	"busy": Input.CURSOR_BUSY,
	"select": Input.CURSOR_POINTING_HAND,
	"remove": Input.CURSOR_WAIT,
	"orbit": Input.CURSOR_DRAG,
	"slide": Input.CURSOR_MOVE,
	"zoom_in": Input.CURSOR_VSIZE,
	"zoom_out": Input.CURSOR_HSIZE,
	"box": Input.CURSOR_CROSS,
	"paint": Input.CURSOR_HELP,
}

## The states drawn from assets/ui/cursors, and the point of each that
## is the pointer, in the SVG's own 32-unit grid. The rest are the
## system's own and are drawn by the system.
const HOTSPOTS := {
	"place": Vector2(2.5, 2.5),
	"remove": Vector2(2.5, 2.5),
	"orbit": Vector2(16, 16),
	"slide": Vector2(16, 16),
	"zoom_in": Vector2(13, 13),
	"zoom_out": Vector2(13, 13),
	"box": Vector2(16, 16),
	"paint": Vector2(4.5, 27.5),
}

## States that belong to a drag in progress. They keep the pointer for
## the whole drag, panels included: see [member _shield].
const GESTURES := ["orbit", "slide", "box"]

## What is true at this moment, as far as the pointer is concerned.
## Filled in by whoever owns the scene; [method choose] is the only
## thing that reads it.
class Situation extends RefCounted:
	## The view is being turned or slid by a button held down.
	var turning: bool = false
	var sliding: bool = false
	## A box is being drawn.
	var boxing: bool = false
	## The right button is down over a brick and has not moved far
	## enough to be a turn: letting go takes that brick off.
	var removing: bool = false
	## C is held, which paints what is under the pointer.
	var painting: bool = false
	## The view moved a moment ago without a button: the wheel, a
	## trackpad, a pinch, a key. "orbit", "slide", "zoom_in", "zoom_out"
	## or "".
	var moment: String = ""
	## The build is animating, and a click stops it rather than placing.
	var playing: bool = false
	## Shift is held over a brick, so a click picks it out.
	var selecting: bool = false
	## There is a ghost under the pointer, and whether a click would put
	## the part down there.
	var aimed: bool = false
	var can_place: bool = false
	## The part being held has not arrived yet.
	var loading: bool = false


## The one state the pointer should be in.
##
## A drag in progress first, because it is what the hand is doing; then
## the right button about to take a brick off; then a key held; then
## what the view did a moment ago; and last what a click would do here.
static func choose(now: Situation) -> String:
	if now.turning:
		return "orbit"
	if now.sliding:
		return "slide"
	if now.boxing:
		return "box"
	if now.removing:
		return "remove"
	if now.painting:
		return "paint"
	if not now.moment.is_empty():
		return now.moment
	if now.playing:
		return "arrow"
	if now.selecting:
		return "select"
	if now.aimed:
		return "place" if now.can_place else "blocked"
	if now.loading:
		return "busy"
	return "arrow"


var _shown: String = "arrow"

## A sheet over everything, there only while a drag is going on.
##
## The default shape only applies where no control is under the pointer,
## so a turn that swept across a panel turned into an arrow halfway
## through. While a drag lasts this covers the window and carries the
## drag's shape. It passes every event on — the drag's motion and its
## release still reach the camera and the box select exactly as before —
## and it is taken away the moment the drag ends.
var _shield: Control

## The scale the cursor pictures were drawn at.
var _scale: float = 1.0

## On the web: the style that shows each borrowed shape crisply at any
## device ratio, by system shape. See [method _crisp_on_the_web].
var _css: Dictionary = {}
var _css_shape: int = -1
var _css_checked_at: int = 0

## Set when something may have changed what is under a pointer that has
## not moved, so the cursor is worked out again. See [method _input].
var _recheck: bool = false

## After that: whoever aims things at the pointer should aim again. The
## window's own replay reaches the interface only — Godot keeps a motion
## it makes up from every _input and _unhandled_input — so the model's
## ghost has to be told.
signal looked_again


func _ready() -> void:
	# Above every panel and dialog, or a drag across one loses its shape.
	layer = 120
	_shield = Control.new()
	_shield.name = "CursorShield"
	_shield.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shield)
	_draw_pictures()
	# Every button the interface makes from here on, and every one it
	# already has: a pointing hand says "this is pressed", which the
	# arrow they all had did not.
	get_tree().node_added.connect(_point_at)
	_point_at_all(get_tree().root)


## The state on screen now.
func shown() -> String:
	return _shown


## Whether this is the drag sheet, which covers the window during a drag
## and so is under the pointer without being anything the pointer is over.
func is_shield(control: Control) -> bool:
	return control == _shield


## Whether the drag sheet is up.
func shielding() -> bool:
	return _shield.mouse_filter != Control.MOUSE_FILTER_IGNORE


## Put the pointer in a state.
func show_state(state: String) -> void:
	if state == _shown or not SHAPES.has(state):
		return
	_shown = state
	var shape: int = SHAPES[state]
	if state in GESTURES and not TouchTools.wanted():
		# Up first and then shaped, so the shape takes at once: setting
		# a control's shape redraws the pointer only if the control is
		# there to be found under it.
		_shield.mouse_filter = Control.MOUSE_FILTER_PASS
		_shield.mouse_default_cursor_shape = shape as Control.CursorShape
	elif shielding():
		_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shield.mouse_default_cursor_shape = Control.CURSOR_ARROW
		# The drag may have ended over a panel, which should show its
		# own shape now rather than at the next movement.
		_recheck = true
	Input.set_default_cursor_shape(shape as Input.CursorShape)
	# Said to the page, as the controls' positions are (main._tell_page),
	# so a browser test can tell which state a picture belongs to.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.brickworksCursor = %s" % JSON.stringify(state), true)


func _input(event: InputEvent) -> void:
	# A key or a click can change what is under a pointer that has not
	# moved: Escape or Done closes the dialog it was over, Tab folds a
	# panel away from under it, a comma opens one on top of it. Godot
	# picks the shape when the pointer moves, so without this the
	# pointing hand of a Done button that is no longer there stayed
	# until the mouse was nudged.
	#
	# Not for a click a finger made. There is no pointer to correct on a
	# touchscreen, and the ghost a hold-to-remove hides on purpose would
	# be put straight back.
	if event is InputEventKey or (event is InputEventMouseButton
			and not event.is_pressed()
			and event.device != InputEvent.DEVICE_ID_EMULATION):
		_recheck = true


func _process(_delta: float) -> void:
	if _recheck:
		_recheck = false
		# A motion where the pointer already is, through the whole
		# window: the interface picks its shape again and the model
		# re-aims the ghost, both against what is there now.
		get_viewport().update_mouse_cursor_state()
		looked_again.emit()
	if not _css.is_empty():
		_crisp_on_the_web()


## The cursor pictures, drawn for this screen and handed to the system.
func _draw_pictures() -> void:
	_scale = _cursor_scale()
	var web: bool = OS.has_feature("web")
	for state: String in HOTSPOTS:
		var path: String = Icons.CURSORS + state + ".svg"
		var picture: Image = Icons.image(path, _scale)
		if picture == null:
			push_warning("cursors: could not draw %s" % path)
			continue
		var hotspot: Vector2 = (HOTSPOTS[state] * _scale).floor()
		Input.set_custom_mouse_cursor(picture, SHAPES[state], hotspot)
		if web:
			var sharp: Image = Icons.image(path, 2.0)
			if sharp != null:
				_css[SHAPES[state]] = _image_set(picture, sharp,
					(HOTSPOTS[state] as Vector2).floor())


## How big to draw the cursor pictures for this screen.
##
## A pointer is a fixed size to the eye, so on a screen with twice the
## pixels to the inch it wants twice the pixels. Godot hands a picture to
## Windows and X11 pixel for pixel, so that is done here, from the
## screen's density.
##
## Not on a Mac, which takes the picture's pixels as points and so
## shows a 64-pixel picture at twice the size rather than twice as
## sharp. And not in a browser, where the system shape is a CSS cursor
## measured in CSS pixels: there the sharper picture goes in alongside
## as a second resolution, see [method _crisp_on_the_web].
static func _cursor_scale() -> float:
	if OS.has_feature("web") or OS.get_name() == "macOS":
		return 1.0
	if DisplayServer.get_name() == "headless":
		return 1.0
	var dpi: int = DisplayServer.screen_get_dpi()
	if dpi >= 168:
		return 2.0
	if dpi >= 132:
		return 1.5
	return 1.0


# -- the web -------------------------------------------------------------
#
# Godot shows a custom cursor in a browser as `url(<png>) x y` on the
# canvas, and a CSS cursor's picture is measured in CSS pixels: a
# 32-pixel picture on a screen with two device pixels to each CSS pixel
# is blown up to 64 and is visibly soft beside the system's own. CSS can
# say "this one at 1x, that one at 2x" with image-set(), and Godot does
# not, so whenever the canvas is showing one of the borrowed shapes its
# style is replaced with one that does.
#
# Godot rewrites the style only when the shape changes, and this follows
# the shape every frame, so the soft version is on screen for at most a
# frame. It is re-asserted a few times a second as well, for the case
# where the shape changed and changed back between two frames.


## The two resolutions of a picture and its hotspot, as the part of a CSS
## cursor that follows the function's name: "(url(…) 1x, url(…) 2x) x y,
## auto". The hotspot is in CSS pixels, which is the 1x picture's.
func _image_set(normal: Image, sharp: Image, hotspot: Vector2) -> String:
	return "(url(\"data:image/png;base64,%s\") 1x, url(\"data:image/png;base64,%s\") 2x) %d %d, auto" % [
		Marshalls.raw_to_base64(normal.save_png_to_buffer()),
		Marshalls.raw_to_base64(sharp.save_png_to_buffer()),
		int(hotspot.x), int(hotspot.y)]


## Put the sharp style on the canvas if it is showing a borrowed shape.
##
## The page picks the syntax, by trying it: image-set() where the browser
## has it, the prefixed one where only that exists, and where neither,
## nothing — a browser drops a cursor value it cannot read and Godot's own
## 1x picture stays. It was chosen here first, by asking CSS.supports()
## once at start-up, and the first build in Chromium came out with no
## function name at all: "(url(…)", which the browser threw away, so
## every picture was the soft one. Trying it where it is used cannot
## disagree with the browser using it.
func _crisp_on_the_web() -> void:
	var shape: int = DisplayServer.cursor_get_shape()
	var now: int = Time.get_ticks_msec()
	if shape == _css_shape and now < _css_checked_at:
		return
	_css_shape = shape
	_css_checked_at = now + 250
	if not _css.has(shape):
		return
	JavaScriptBridge.eval("""
		(function (sets) {
			const canvas = document.getElementById('canvas');
			if (!canvas) return;
			if (canvas.dataset.cursor === sets
					&& canvas.style.cursor.includes('image-set')) return;
			for (const name of ['image-set', '-webkit-image-set']) {
				canvas.style.cursor = name + sets;
				if (canvas.style.cursor.includes('image-set')) {
					canvas.dataset.cursor = sets;
					return;
				}
			}
		})(%s)""" % JSON.stringify(_css[shape]), true)


# -- buttons ---------------------------------------------------------------


func _point_at_all(node: Node) -> void:
	_point_at(node)
	for child: Node in node.get_children():
		_point_at_all(child)


## A pointing hand over anything that is pressed rather than read.
func _point_at(node: Node) -> void:
	if not (node is BaseButton or node is Slider):
		return
	var control: Control = node
	if control.mouse_default_cursor_shape == Control.CURSOR_ARROW:
		control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
