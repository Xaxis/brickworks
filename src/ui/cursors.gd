## The pointer, saying what the mouse will do and what it is doing.
##
## Asked for by the owner: "the app's cursor should change based on which
## function is being performed", and again once the tools came in: "we're
## not seeing the cursor change based on the mode and context, as you
## obviously need to do." The first answer covered placing and the drags
## of the view; every tool but Paint and Delete then showed the same
## pointing hand as Select, the model's empty background the arrow though
## a drag there turns the view, and the Orbit, Pan and Zoom tools, Space
## and Alt nothing at all.
##
## One state at a time, worked out afresh every frame by [method choose]
## from what is true now — the tool, the keys held, what is under the
## pointer — and shown through Godot's default cursor shape: the shape the
## window uses wherever no control is under the pointer, which is exactly
## the model. Panels, text fields and buttons keep their own (an I-beam, a
## pointing hand), because the control under the pointer always wins over
## the default.
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

## The states the system draws, and the shape each is shown as.
const SYSTEM := {
	"arrow": Input.CURSOR_ARROW,
	"select": Input.CURSOR_POINTING_HAND,
	"blocked": Input.CURSOR_FORBIDDEN,
	"busy": Input.CURSOR_BUSY,
	"move": Input.CURSOR_MOVE,
}

## The states drawn from assets/ui/cursors, and the point of each that
## is the pointer, in the SVG's own 32-unit grid. No system has a cursor
## for turning a view, a paint bucket, an eraser or a hinge, and Godot
## offers no open or closed hand, magnifier or copy arrow on a desktop,
## so these are pictures everywhere and look the same everywhere.
const HOTSPOTS := {
	"place": Vector2(16, 16),
	"orbit": Vector2(16, 16),
	"hand": Vector2(16, 17),
	"grabbing": Vector2(16, 17),
	"zoom_in": Vector2(13, 13),
	"zoom_out": Vector2(13, 13),
	"box": Vector2(16, 16),
	"paint": Vector2(22, 27.5),
	"delete": Vector2(8.5, 23.5),
	"hide": Vector2(2.5, 2.5),
	"copy": Vector2(2.5, 2.5),
	"rotate": Vector2(2.5, 2.5),
	"hinge": Vector2(2.5, 2.5),
}

## The shapes the pictures are hung on.
##
## Godot hangs a custom picture on one of its seventeen system shapes
## rather than offering cursors of its own, and there are more pictures
## than shapes the app can spare: the interface shows the arrow, the
## I-beam, the pointing hand and a splitter's arrows; the print studio's
## picker the crosshair; a dialog's edges the four resize arrows; a row
## dragged in the outliner the drop and no-drop signs. A picture hung on
## any of those turned up there as well — a zoom glass on a dialog's
## edge. Only one cursor is on screen at a time, so three shapes nothing
## else asks for take turns: a picture is hung on one when it is wanted,
## and never on the one showing, so the cursor on screen never changes
## under the pointer by itself.
const SLOTS: Array[int] = [Input.CURSOR_HELP, Input.CURSOR_WAIT, Input.CURSOR_DRAG]

## What a click on a part does with each tool, as a pointer.
const TOOLS := {"paint": "paint", "delete": "delete", "hide": "hide", "clone": "copy",
	"rotate": "rotate", "hinge": "hinge", "move": "move"}

## A drag's verb ("turn", "slide", "zoom", "box") as the pointer that
## says it.
const VERBS := {"turn": "orbit", "slide": "hand", "zoom": "zoom_in", "box": "box"}

## What is true at this moment, as far as the pointer is concerned.
## Filled in by whoever owns the scene; [method choose] is the only
## thing that reads it.
class Situation extends RefCounted:
	## A button is holding the view (turning, sliding or zooming it), or a
	## part a drag picked up.
	var holding_view: bool = false
	var holding_part: bool = false
	## A box is being drawn.
	var boxing: bool = false
	## What a left drag will do to the view whatever is under the pointer:
	## a view tool is on, or Space or Alt is held. "orbit", "hand",
	## "zoom_in", "zoom_out" or "".
	var tool: String = ""
	## The view moved a moment ago without a button: the wheel, a
	## trackpad, a pinch, a key. "orbit", "hand", "zoom_in", "zoom_out"
	## or "".
	var moment: String = ""
	## The build is animating, and a click stops it rather than placing.
	var playing: bool = false
	## C is held, which paints what is under the pointer.
	var painting: bool = false
	## The tool in use (EditVerbs.mode).
	var mode: String = "select"
	## Something in hand — a part, a carried selection, a figure — that a
	## click puts down.
	var in_hand: bool = false
	## There is a ghost under the pointer, and whether a click would put
	## the part down there.
	var aimed: bool = false
	var can_place: bool = false
	## The part in hand has not arrived yet.
	var loading: bool = false
	## A part under the pointer.
	var over_part: bool = false
	## Shift, and Ctrl (Cmd on a Mac), held.
	var shift: bool = false
	var ctrl: bool = false
	## The pointer for what a left drag that starts on nothing does, by
	## the navigation preset and Shift (ViewPrefs.drag_verb).
	var left_drag: String = "orbit"

	## A drag is going on: a button holds the view or a part, or draws a
	## box. Only then does the pointer keep its shape over the panels
	## (see [member Cursors._shield]).
	func dragging() -> bool:
		return holding_view or holding_part or boxing


## The one state the pointer should be in.
##
## Something held first, because it is what the hand is doing; then a
## key or a view tool that lends the left button to the view; then what
## the view did a moment ago; and last what a click or a drag would do
## here, by the tool and what is under the pointer.
static func choose(now: Situation) -> String:
	if now.holding_part or now.holding_view:
		return "grabbing"
	if now.boxing:
		return "box"
	if not now.tool.is_empty():
		return now.tool
	if not now.moment.is_empty():
		return now.moment
	if now.playing:
		return "arrow"
	if now.painting:
		return "paint"
	if now.in_hand:
		# Shift with something in hand: a click picks out the part under
		# the pointer rather than putting this down, and a drag slides.
		if now.shift:
			return now.left_drag
		if now.aimed:
			return "place" if now.can_place else "blocked"
		if now.loading:
			return "busy"
		return now.left_drag
	if TOOLS.has(now.mode):
		return TOOLS[now.mode]
	# Select: a press on a part takes it (Ctrl: a copy of it); anywhere
	# else a drag moves the view (Ctrl: draws a box); Shift makes any drag
	# slide.
	if now.shift:
		return now.left_drag
	if now.ctrl:
		return "copy" if now.over_part else "box"
	return "select" if now.over_part else now.left_drag


var _shown: String = "arrow"
var _shown_shape: int = Input.CURSOR_ARROW

## The pictures, drawn once for this screen, and their hotspots in its
## pixels. See [method _draw_pictures].
var _pictures: Dictionary = {}
var _hotspots: Dictionary = {}

## Which picture hangs on each of [constant SLOTS] now, and the slot the
## next new one goes on.
var _hung: Dictionary = {}
var _next_slot: int = 0

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

## On the web: the style that shows each picture crisply at any device
## ratio, by state. See [method _crisp_on_the_web].
var _css: Dictionary = {}
var _css_key: String = ""
var _css_checked_at: int = 0

## Set when something may have changed what is under a pointer that has
## not moved, so the cursor is worked out again. See [method _input].
var _recheck: bool = false

## After that: whoever aims things at the pointer should aim again. The
## window's own replay reaches the interface only — Godot keeps a motion
## it makes up from every _input and _unhandled_input — so the model's
## ghost has to be told.
signal looked_again

## The control the pointer was over last frame, by instance id.
var _was_over: int = 0

## Whether the last pointer event was a finger's, raised as a mouse by
## emulation. There is no pointer on a touchscreen, and where the system
## thinks one is has nothing to do with where the finger went.
var _by_finger: bool = false

## Whether the button held now went down on the interface rather than
## the model.
var _pressed_on_interface: bool = false


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


## The system shape a state is shown as now: its own, or the slot its
## picture hangs on (-1 if it hangs on none yet).
func shape_of(state: String) -> int:
	if SYSTEM.has(state):
		return SYSTEM[state]
	for shape: int in _hung:
		if _hung[shape] == state:
			return shape
	return -1


## The picture a state is drawn as here, or null for the system's own.
func picture_of(state: String) -> Image:
	return _pictures.get(state)


## Whether this is the drag sheet, which covers the window during a drag
## and so is under the pointer without being anything the pointer is over.
func is_shield(control: Control) -> bool:
	return control == _shield


## Whether the drag sheet is up.
func shielding() -> bool:
	return _shield.mouse_filter != Control.MOUSE_FILTER_IGNORE


## The pointer for what is true now: its state, and the sheet over the
## panels while a drag goes on.
func show_for(now: Situation) -> void:
	show_state(choose(now), now.dragging())


## Put the pointer in a state, and over the panels as well while
## [param dragging].
##
## Only while a drag is held, never for what a state is called. A view
## tool's turn, or Ctrl's box with no button down, put the sheet over
## every panel for as long as the tool was on or the key held, and every
## click on a button turned the view instead (2026-10-12).
func show_state(state: String, dragging: bool = false) -> void:
	if not SYSTEM.has(state) and not _pictures.has(state):
		state = "arrow"
	var shield: bool = dragging and not TouchTools.wanted()
	if state == _shown and shield == shielding():
		return
	var shape: int = _hang(state) if state != _shown else _shown_shape
	_shown = state
	_shown_shape = shape
	if shield:
		# Up first and then shaped, so the shape takes at once: setting
		# a control's shape redraws the pointer only if the control is
		# there to be found under it.
		_shield.mouse_filter = Control.MOUSE_FILTER_PASS
		_shield.mouse_default_cursor_shape = shape as Control.CursorShape
	elif shielding():
		_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shield.mouse_default_cursor_shape = Control.CURSOR_ARROW
	Input.set_default_cursor_shape(shape as Input.CursorShape)
	# And the window asked to pick its shape again, now, where the pointer
	# stands. Setting the default is meant to do that by itself and on the
	# desktop does, a frame late; in a browser it did not, so when the
	# wheel's moment ended with the pointer still the page said "place"
	# and the canvas went on showing the zoom glass until the mouse moved.
	# A drag that ended over a panel wants the panel's own shape back for
	# the same reason.
	_recheck = true
	# Said to the page, as the controls' positions are (main._tell_page),
	# so a browser test can tell which state a picture belongs to.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.brickworksCursor = %s" % JSON.stringify(state), true)


## The shape to show a state as, its picture hung on a slot first if it
## is not on one: the next slot round that is not the one on screen.
func _hang(state: String) -> int:
	var shape: int = shape_of(state)
	if shape != -1:
		return shape
	shape = SLOTS[_next_slot]
	if shape == _shown_shape:
		_next_slot = (_next_slot + 1) % SLOTS.size()
		shape = SLOTS[_next_slot]
	_next_slot = (_next_slot + 1) % SLOTS.size()
	Input.set_custom_mouse_cursor(_pictures[state], shape as Input.CursorShape, _hotspots[state])
	_hung[shape] = state
	return shape


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
	if event is InputEventMouse:
		_by_finger = event.device == InputEvent.DEVICE_ID_EMULATION
	if event is InputEventMouseButton and event.is_pressed():
		# Godot has already found what is under this press.
		var over: Control = get_viewport().gui_get_hovered_control()
		_pressed_on_interface = over != null and over != _shield
	if event is InputEventKey or (event is InputEventMouseButton
			and not event.is_pressed()):
		_recheck = true


func _process(_delta: float) -> void:
	# Onto a panel or off one. A panel keeps the motion that crossed into
	# it from the model, so the model never heard the pointer leave: its
	# ghost stayed drawn at the panel's edge and the pointer's state went
	# on saying "place" over the parts bin. The control under the pointer
	# is the window's own answer, so a change of it is asked about too.
	var over: Control = get_viewport().gui_get_hovered_control()
	var over_id: int = 0 if over == null or over == _shield else over.get_instance_id()
	if over_id != _was_over:
		_was_over = over_id
		_recheck = true
	if _recheck and _by_finger:
		_recheck = false
	elif _recheck and not _holding_a_control():
		_recheck = false
		# A motion where the pointer already is, through the whole
		# window: the interface picks its shape again and the model
		# re-aims the ghost, both against what is there now.
		get_viewport().update_mouse_cursor_state()
		looked_again.emit()
	if not _css.is_empty():
		_crisp_on_the_web()


## Whether a button is down that went down on the interface, in which
## case the look again waits for it to come up.
##
## The replay goes where the system says the pointer is, and a button
## being pressed takes any motion as the pointer moving: one somewhere
## else and the button reads it as the pointer having left, and the
## click is lost. On a desktop the two places are the same; the minifig
## builder's probe, whose clicks are events and never move the system's
## pointer, lost every click to it. A press on the model has no control
## to lose it, so the pointer there still changes while the button is
## held.
func _holding_a_control() -> bool:
	return _pressed_on_interface and Input.get_mouse_button_mask() != 0


## The cursor pictures, drawn for this screen. They are handed to the
## system one at a time, as they are wanted (see [method _hang]).
func _draw_pictures() -> void:
	_scale = _cursor_scale()
	var web: bool = OS.has_feature("web")
	for state: String in HOTSPOTS:
		var path: String = Icons.CURSORS + state + ".svg"
		var picture: Image = Icons.image(path, _scale)
		if picture == null:
			push_warning("cursors: could not draw %s" % path)
			continue
		_pictures[state] = picture
		_hotspots[state] = (HOTSPOTS[state] * _scale).floor()
		if web:
			var sharp: Image = Icons.image(path, 2.0)
			if sharp != null:
				_css[state] = _image_set(picture, sharp, (HOTSPOTS[state] as Vector2).floor())


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
# not, so whenever the canvas is showing one of the pictures its style is
# replaced with one that does.
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


## Put the sharp style on the canvas if it is showing a picture.
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
	var state: String = str(_hung.get(shape, ""))
	var key: String = "%d %s" % [shape, state]
	var now: int = Time.get_ticks_msec()
	if key == _css_key and now < _css_checked_at:
		return
	_css_key = key
	_css_checked_at = now + 250
	if not _css.has(state):
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
		})(%s)""" % JSON.stringify(_css[state]), true)


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
