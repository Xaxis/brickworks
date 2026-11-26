## Simple's controls over the model (bench/results/simplemode-2026-11-24
## /PLAN.md): the layer Main puts in place of the studio's own, the phone's
## or the desktop's, while it is in Simple (Main.use_controls). The header
## stays, with Simple | Full in it (AppHeader.controls_switch); under it the
## model, and along the foot a tray:
##
##   colours   12 solid colours, picked first (a selected brick takes it too)
##   groups    Bricks, Plates, Slopes, Tiles (and round), Specials
##   parts     the group's six, pictured in the colour picked
##
## Over the model's foot the big Undo and Redo at the left, and at the right,
## while a brick is selected, Turn, Copy and Delete; while one is carried, a
## bin in their place. Fit in the top corner, and a line saying what a finger
## does now.
##
## One finger builds and two fingers move the camera (map B, chosen by the
## walks: bench/results/simplep1-2026-11-26/WALKS.md):
##   a drag out of the tray  the brick's ghost on the nearest legal studs, a
##                           lift over the finger; let go to put it there
##   a tap on a tile         that brick chosen: a tap on the model puts one
##   a tap on a brick        selects it
##   a drag on a brick       moves it (and what rests on it), re-snapped where
##                           it is let go, deleted over the bin, put back over
##                           the tray or by a second finger
##   one finger on nothing   nothing moves (once, how the view turns)
##   two fingers             turn and pinch the view; a tap of two undoes,
##                           of three redoes
## A mouse's left button is the finger, and a left drag on nothing turns the
## view, as the mouse has no second finger; the wheel and the right and
## middle buttons are the camera's own.
##
## Every act is the studio's own, so nothing is converted and the full studio
## sees every brick: a brick goes down by Builder.place, as one dragged out of
## the desktop's bin; a brick moves by EditVerbs.drag_start's carry, put down
## by Main._drop_dragged; Turn is Builder.turn_selection_by, Copy
## EditVerbs.duplicate_beside, Delete Builder.remove_selection, a colour
## Builder.paint_selection; Undo and Redo are Shell's.
##
## A part Simple cannot edit (in a sub-assembly or a figure, tilted, or a
## piece of a bendy part: [method left_alone]) is shown and left alone: a
## finger on it takes nothing, and entering Simple says so once.
class_name SimpleLayer
extends Control

## The tray's groups, in order, and the six parts of each.
const GROUPS: Array = [
	["Bricks", ["3005", "3004", "3622", "3010", "3003", "3001"]],
	["Plates", ["3024", "3023b", "3710", "3022", "3020", "3034"]],
	["Slopes", ["54200", "3040b", "3039", "3298", "3043", "3665a"]],
	["Tiles", ["3070b", "3069b", "3068b", "6141", "3062b", "3941"]],
	["Specials", ["60592c01", "33cc01", "4728", "4600", "4624c01", "3659"]],
]
## Red, orange, yellow, bright green, green, blue, white, tan, reddish
## brown, light and dark bluish grey, black: solid colours only.
const COLOURS: Array[int] = [4, 25, 14, 10, 2, 1, 15, 19, 70, 71, 72, 0]
## Sizes in points.
const SWATCH := 44.0
const SWATCH_ROW := 48.0
const TAB := 44.0
const TILE := 64.0
const MARGIN := 8.0
const GAP := 4.0
const BIG := 60.0
const ACT := 56.0
## A tray this wide in points or more has its colours on one row.
const ONE_ROW := 600.0
## How far a finger goes before its press is a drag, in points.
const SLOP := 10.0
## A part within this of the finger, in points, is the one it takes.
const NEAR := 26.0
## The least a stud is drawn, in points, when the view is pulled back as far
## as it goes over a small model: further, and a newcomer's drops land wrong
## (the lead's look at simplep1's walk: a stud 3-4 points on a far plate).
const LEAST_STUD := 12.0
## A new sketch's plate, in studs each way.
const SKETCH := 16
## The seat: a brick put down comes the last of this many LDU onto its
## studs, in this many ms.
const SEAT_LDU := 14.0
const SEAT_MS := 160.0
const BACK := Color(0.11, 0.12, 0.14, 0.97)
const LIT := Color(0.36, 0.6, 1.0, 1.0)
const BIN := Color(0.78, 0.2, 0.18, 0.92)
## How long a word said stays on the line, in ms.
const SAID_MS := 2600

## How far over the finger the ghost is aimed, in points: a fingertip
## hides what is under it, so the brick rides above it. A part taken off the
## model eases into it over the drag's first [constant RAMP] points, so it
## does not jump; a brick out of the tray is over the finger at once (walk
## 2). 56 points by the walks (WALKS.md); 0 aims at the fingertip.
var lift_points: float = 56.0
const RAMP := 40.0

var app: Node

## Where Main's notices strip goes while this is up, under the header.
var notices_slot: VBoxContainer

var _k: float = 1.0
var _foot: PanelContainer
var _tray_tall: float = 0.0
var _tabs: Array[Button] = []
var _tiles: Array[Control] = []
var _pictures: Array[TextureRect] = []
var _swatches: Array[Button] = []
var _undo: Button
var _redo: Button
var _turn: Button
var _copy: Button
var _delete: Button
var _bin: Button
var _fit: Button
var _pill: PanelContainer
var _pill_words: Label
var _group: int = 0
var _colour: int = 4
## The brick a tap on the tray chose: a tap on the model puts one there.
var _chosen: String = ""
## A finger's tap with a brick chosen shows its ghost where it would go and
## waits: a tap on the ghost puts it down, a tap elsewhere shows it there
## instead, a drag from it carries it. A finger hides where it lands, and
## aimed unseen the tapper's bricks went down a stud off 6 times in 9. A
## mouse's ghost follows the pointer, so its click puts one down at once.
var _ghost_shown: bool = false
## LDU round a shown ghost a tap still counts as on it: under half a stud, so
## a tap on the studs beside it shows it there.
const GHOST_SLACK := 8.0
## A finger that came down on the shown ghost, and the point that aimed it
## there (its foot on the screen) as the finger came down.
var _ghost_drag: bool = false
var _ghost_from: Vector2 = Vector2.ZERO
## The tile a press in the tray's gaps went to (_foot_input).
var _foot_tile: Control = null
## Each tile's picture: [part, colour] it was drawn in.
var _drawn_in: Dictionary = {}

# A brick dragged out of the tray (its tile's own input).
var _tray_part: String = ""
var _tray_from: Vector2 = Vector2.ZERO
var _tray_travel: float = 0.0
var _tray_dragging: bool = false

# The finger (or the mouse's left button) on the model.
var _finger: int = -1
var _mouse: bool = false
var _down: Vector2 = Vector2.ZERO
var _at: Vector2 = Vector2.ZERO
var _travel: float = 0.0
var _brick: int = 0
## A part Simple leaves alone that the press came down on.
var _left_one: int = 0
var _moving: bool = false
var _turning_view: bool = false
var _others: int = 0
var _hinted: bool = false
var _touches: Dictionary = {}
## Where each part a finger is moving stood when it was taken.
var _moved_from: Dictionary = {}

# A seat being drawn: brick id -> where it stands.
var _seating: Dictionary = {}
var _seat_from: int = 0

var _said: String = ""
var _said_until: int = 0
## The models told what Simple leaves alone, by their world's generation.
var _told_left: Dictionary = {}
## Full's camera, put back as it was when Simple did not move it (left).
var _camera_was: Dictionary = {}
var _framed_pose: Array = []

## What a check reads of the last drop: where it was aimed, whether it
## went down, and the parts it put down or moved.
var last_drop: Dictionary = {}
## How many of each act there were.
var counts: Dictionary = {"put": 0, "moved": 0, "refused": 0, "cancelled": 0, "tapped": 0, "hints": 0,
	"selected": 0, "turned": 0, "copied": 0, "deleted": 0, "binned": 0, "painted": 0, "left_alone": 0,
	"view_turns": 0}


func _ready() -> void:
	name = "SimpleLayer"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	notices_slot = VBoxContainer.new()
	notices_slot.name = "simple_notices"
	notices_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notices_slot)
	# Fit kept under the notices as they come and go.
	notices_slot.resized.connect(_lay_out)
	_build()
	get_viewport().size_changed.connect(_rebuild, CONNECT_DEFERRED)
	var builder: Builder = app.get("_builder")
	if builder != null:
		_colour = builder.held_color if COLOURS.has(builder.held_color) else COLOURS[0]
	_paint_swatches()
	var camera: CadCamera = app.get("_camera")
	if camera != null:
		camera.tapped_with.connect(_fingers_tapped)
		camera.double_tapped.connect(_double_tapped)
	var bar: ModelBar = app.get("_bar")
	if bar != null:
		bar.said.connect(_hear)
		# A new model begun in Simple is a sketch: on a small plate, framed.
		bar.started_new.connect(func() -> void:
			if is_visible_in_tree():
				new_sketch())
	set_process(true)


func p(points: float) -> float:
	return points * _k


func _rebuild() -> void:
	for child: Node in get_children():
		if child == notices_slot:
			continue
		remove_child(child)
		child.queue_free()
	_tabs.clear()
	_tiles.clear()
	_pictures.clear()
	_swatches.clear()
	_drawn_in.clear()
	_build()
	_paint_swatches()


func _build() -> void:
	_k = Phone.per_point(get_viewport())
	var room: Vector2 = get_viewport().get_visible_rect().size
	var across: float = room.x / maxf(_k, 0.001)
	var per_row: int = COLOURS.size() if across >= ONE_ROW else COLOURS.size() / 2
	var colour_rows: int = ceili(COLOURS.size() / float(per_row))

	_foot = PanelContainer.new()
	_foot.name = "simple_foot"
	_foot.mouse_filter = Control.MOUSE_FILTER_STOP
	var face := StyleBoxFlat.new()
	face.bg_color = BACK
	face.border_color = Color(1, 1, 1, 0.08)
	face.border_width_top = 1
	face.content_margin_left = p(MARGIN)
	face.content_margin_right = p(MARGIN)
	face.content_margin_top = p(GAP)
	face.content_margin_bottom = p(MARGIN)
	_foot.add_theme_stylebox_override("panel", face)
	_tray_tall = GAP + colour_rows * SWATCH_ROW + GAP + TAB + GAP + TILE + MARGIN + 3.0 * GAP
	_foot.anchor_left = 0.0
	_foot.anchor_right = 1.0
	_foot.anchor_top = 1.0
	_foot.anchor_bottom = 1.0
	_foot.offset_top = -p(_tray_tall)
	_foot.offset_bottom = 0.0
	_foot.gui_input.connect(_foot_input)
	add_child(_foot)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ceili(p(GAP)))
	_foot.add_child(column)

	# Colour first: a fingertip each.
	var strip := GridContainer.new()
	strip.columns = per_row
	strip.add_theme_constant_override("h_separation", 0)
	strip.add_theme_constant_override("v_separation", 0)
	column.add_child(strip)
	for code: int in COLOURS:
		var cell := CenterContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size.y = p(SWATCH_ROW)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		strip.add_child(cell)
		var swatch := Button.new()
		swatch.name = "simple_colour_%d" % code
		swatch.custom_minimum_size = Vector2(p(SWATCH), p(SWATCH))
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.accessibility_name = _colour_name(code)
		swatch.tooltip_text = _colour_name(code)
		swatch.set_meta("colour", code)
		swatch.pressed.connect(_on_swatch.bind(code))
		cell.add_child(swatch)
		_swatches.append(swatch)

	# The groups, a tab each.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", ceili(p(GAP)))
	column.add_child(tabs)
	var group := ButtonGroup.new()
	for n: int in GROUPS.size():
		var tab := Button.new()
		tab.name = "simple_group_%s" % str(GROUPS[n][0]).to_lower()
		tab.text = str(GROUPS[n][0])
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = n == _group
		tab.focus_mode = Control.FOCUS_NONE
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0.0, p(TAB))
		tab.clip_text = true
		tab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tab.add_theme_font_size_override("font_size", roundi(p(14.0)))
		_dress_tab(tab)
		tab.pressed.connect(_on_group.bind(n))
		tabs.add_child(tab)
		_tabs.append(tab)

	# The group's parts, pictured in the colour chosen.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ceili(p(GAP)))
	column.add_child(row)
	for n: int in (GROUPS[_group][1] as Array).size():
		var part: String = GROUPS[_group][1][n]
		var tile := PanelContainer.new()
		tile.name = "simple_brick_%s" % part
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(p(Phone.TARGET), p(TILE))
		tile.mouse_filter = Control.MOUSE_FILTER_STOP
		tile.accessibility_name = _part_name(part)
		tile.set_meta("part", part)
		tile.gui_input.connect(_tile_input.bind(tile, part))
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.custom_minimum_size = Vector2(p(TILE - 14.0), p(TILE - 14.0))
		tile.add_child(picture)
		row.add_child(tile)
		_tiles.append(tile)
		_pictures.append(picture)
	_dress_tiles()

	# Over the model's foot: Undo and Redo by the thumb at the left, and a
	# selected brick's Turn, Copy and Delete at the right; while one is
	# carried, the bin in their place.
	_undo = _round("undo", "Undo", "undo", BIG)
	_redo = _round("redo", "Redo", "redo", BIG)
	_turn = _round("turn", "Turn", "rotate", ACT)
	_copy = _round("copy", "Copy", "duplicate", ACT)
	_delete = _round("delete", "Delete", "delete", ACT)
	_bin = _round("bin", "Drop here to delete", "delete", BIG + 12.0, BIN)
	_fit = _round("fit", "Fit", "fit", 48.0)
	_undo.pressed.connect(_run.bind("undo"))
	_redo.pressed.connect(_run.bind("redo"))
	_turn.pressed.connect(turn_selected)
	_copy.pressed.connect(copy_selected)
	_delete.pressed.connect(delete_selected)
	_fit.pressed.connect(fit)
	_bin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# What a finger does now, over the buttons.
	_pill = PanelContainer.new()
	_pill.name = "simple_line"
	var pill_face := StyleBoxFlat.new()
	pill_face.bg_color = Color(0.09, 0.10, 0.12, 0.86)
	pill_face.set_corner_radius_all(ceili(p(16)))
	pill_face.content_margin_left = p(12)
	pill_face.content_margin_right = p(12)
	pill_face.content_margin_top = p(6)
	pill_face.content_margin_bottom = p(6)
	_pill.add_theme_stylebox_override("panel", pill_face)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill_words = Label.new()
	_pill_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pill_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pill_words.max_lines_visible = 2
	_pill_words.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	_pill_words.add_theme_font_size_override("font_size", ceili(p(14)))
	_pill_words.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_pill_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(_pill_words)
	add_child(_pill)
	_lay_out()


## A round button over the model, [param size] points across, its icon
## the toolbar's, its name for the page simple_[param what].
func _round(what: String, said: String, icon: String, size: float, ground: Color = Color(0, 0, 0, 0)) -> Button:
	var button := Button.new()
	button.name = "simple_" + what
	button.accessibility_name = said
	button.tooltip_text = said
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(p(size), p(size))
	button.size = Vector2(p(size), p(size))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon = Icons.icon_for(Toolbar.TOOLS + icon + ".svg", p(size * 0.5), Icons.density(self))
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var round := StyleBoxFlat.new()
		var base: Color = ground if ground.a > 0.0 else Color(0.11, 0.12, 0.14, 0.86)
		round.bg_color = Color(0.36, 0.6, 1.0, 0.55) if state.contains("pressed") \
			else (base if state != "disabled" else Color(base, 0.55))
		# Under half its size: at half or over, a bordered StyleBoxFlat drew a
		# seam down the middle (simplep1's walk 2).
		round.set_corner_radius_all(floori(p(size * 0.5) - 1.0))
		round.border_color = Color(1, 1, 1, 0.14)
		round.set_border_width_all(1)
		button.add_theme_stylebox_override(state, round)
	button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))
	add_child(button)
	return button


## The round buttons and the line placed over the model's foot, Fit under
## the header, the notices under the header.
func _lay_out() -> void:
	if _undo == null or _foot == null:
		return
	var room: Vector2 = get_viewport().get_visible_rect().size
	var top: float = _header_foot()
	notices_slot.position = Vector2(0.0, top)
	notices_slot.size = Vector2(room.x, 0.0)
	var foot: float = room.y - p(_tray_tall)
	var y: float = foot - p(MARGIN + 4.0) - p(BIG)
	if room.x / maxf(_k, 0.001) >= ONE_ROW:
		# Wide, a tablet's: Undo over Redo up the left side, at the middle of
		# the model's height where a thumb holding it rests (Procreate's side
		# bar). In the corner over a tray the width of the screen, the three
		# newcomers' look along the colours and parts nearer them never
		# reached it at 820 x 1180.
		var middle: float = (top + foot) * 0.5
		_undo.position = Vector2(p(MARGIN + 4.0), middle - p(BIG) - p(MARGIN) * 0.5)
		_redo.position = Vector2(p(MARGIN + 4.0), middle + p(MARGIN) * 0.5)
	else:
		_undo.position = Vector2(p(MARGIN + 4.0), y)
		_redo.position = Vector2(p(MARGIN + 4.0) + p(BIG) + p(MARGIN), y)
	var act_y: float = foot - p(MARGIN + 4.0) - p(ACT) - (p(BIG) - p(ACT)) * 0.5
	var right: float = room.x - p(MARGIN + 4.0)
	for button: Button in [_delete, _copy, _turn]:
		right -= p(ACT)
		button.position = Vector2(right, act_y)
		right -= p(MARGIN)
	_bin.position = Vector2(room.x - p(MARGIN + 4.0) - p(BIG + 12.0), foot - p(MARGIN + 4.0) - p(BIG + 12.0))
	_fit.position = Vector2(room.x - p(12.0) - p(48.0), top + notices_slot.size.y + p(12.0))


## Where the header ends, in the window's units: the phone's top bar, or the
## studio's own header kept over Simple.
func _header_foot() -> float:
	var phone: Control = app.get("_phone")
	if phone != null:
		return float(phone.call("top_height"))
	var bar: Control = app.get("_bar")
	if bar != null and bar.is_visible_in_tree():
		return bar.get_global_rect().end.y
	return 0.0


## The part of the window the model has: under the header, over the tray.
func model_room(window: Rect2) -> Rect2:
	var top: float = _header_foot()
	var bottom: float = window.end.y - p(_tray_tall)
	return Rect2(window.position.x, top, window.size.x, maxf(bottom - top, 1.0))


## Whether a point is on this layer's own controls or the header, for Main
## to leave alone.
func covers(point: Vector2) -> bool:
	for control: Control in [_foot, _undo, _redo, _turn, _copy, _delete, _fit, notices_slot]:
		if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return true
	var phone: Control = app.get("_phone")
	if phone != null:
		return bool(phone.call("covers", point))
	var bar: Control = app.get("_bar")
	return bar != null and bar.is_visible_in_tree() and bar.get_global_rect().has_point(point)


## Whether a brick aimed at [param point] is over the interface, not the
## model: the tray, the header, or a panel over everything. Not the round
## buttons: they float over the model's foot, and a ghost aimed there goes
## down there (simplep1's walk 1: a house's corner behind Undo was refused
## four times).
func _over_ui(point: Vector2) -> bool:
	if _foot != null and _foot.get_global_rect().has_point(point):
		return true
	for control: Control in [_undo, _redo, _turn, _copy, _delete, _fit, _bin]:
		if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return false
	return bool(app.call("_over_panel_at", point))


## The tray's height, in the window's units.
func foot_height() -> float:
	return p(_tray_tall)


# -- in and out (Main.use_controls) ---------------------------------------------------


## Simple's controls just put in place: the camera's fingers its (one finger
## builds, two move the view), a new sketch on its small plate, the model
## framed whole in the room left it, and what it leaves alone said once.
func entered() -> void:
	var camera: CadCamera = app.get("_camera")
	_camera_was = {"phone": camera.phone, "touch_over": camera.touch_over,
		"finger_taken": camera.finger_taken, "far": camera.max_distance, "pose": _pose(camera)}
	camera.phone = true
	camera.touch_over = Callable(app, &"_over_panel_at")
	camera.finger_taken = finger_taken
	_lay_out()
	_sketch()
	# The model framed and its left-alone parts counted a frame later: each
	# reads every part, and the switch is the controls' work alone, whatever
	# the model's size (10030 took it to 18.8 ms at 390 under load).
	_settle_in.call_deferred()


func _settle_in() -> void:
	if not is_visible_in_tree():
		return
	_frame()
	_tell_left_alone()


## Back to Full: the camera's fingers the studio's again, and its view as
## Full left it if Simple's was not moved.
func left() -> void:
	_cancel_press()
	var camera: CadCamera = app.get("_camera")
	if _camera_was.is_empty():
		return
	camera.phone = bool(_camera_was["phone"])
	camera.touch_over = _camera_was["touch_over"]
	camera.finger_taken = _camera_was["finger_taken"]
	camera.max_distance = float(_camera_was["far"])
	if str(_pose(camera)) == str(_framed_pose):
		_set_pose(camera, _camera_was["pose"])
	_camera_was = {}


## A model with nothing on it yet and nothing done to it is a new sketch:
## it stands on a 16 x 16 plate, so the first bricks are big in the view.
## The floor is the model's, so Full shows it too; no step of the history,
## as a new model's floor is none (ModelBar.started_new).
func _sketch() -> void:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var builder: Builder = app.get("_builder")
	if world == null or store == null or store.read_only or store.laying:
		return
	if world.brick_count() - store.scenery.size() > 0 or builder.history_depth() > 0:
		return
	var floor_now: ModelFloor = store.model_floor
	if floor_now.kind == ModelFloor.BASEPLATE and floor_now.across == SKETCH and floor_now.deep == SKETCH:
		return
	store.model_floor = ModelFloor.make(ModelFloor.BASEPLATE, SKETCH, SKETCH, floor_now.colour)
	app.call("_lay_baseplate")


## The model framed in Simple's room, the view kept from pulling back so far
## a stud is under [constant LEAST_STUD] points, unless the model itself
## needs that much room to be seen whole.
func _frame() -> void:
	var camera: CadCamera = app.get("_camera")
	camera.max_distance = float(_camera_was.get("far", 40000.0))
	var box: AABB = app.call("_built_bounds")
	if box.size.length_squared() <= 0.0:
		return
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var sketch: bool = world.brick_count() - store.scenery.size() == 0
	# A new sketch's plate fills the view: framed by its corners, as a flat
	# square is far less tall than the ball round it (by the ball it took 43%
	# of a 1280 x 800 window's room).
	if sketch:
		camera.frame_corners(box, 1.08)
	else:
		camera.frame(box, 1.15)
	_set_far(camera.get("_target_distance"))
	_framed_pose = _pose(camera)


## How far back the view may go: where a stud is LEAST_STUD points, or the
## model's own framed distance [param framed] and a little more.
func _set_far(framed: float) -> void:
	var camera: CadCamera = app.get("_camera")
	var tall: float = get_viewport().get_visible_rect().size.y
	var lens: float = 2.0 * tan(deg_to_rad(camera.fov) * 0.5)
	var studs: float = BrickLattice.STUD * tall / (lens * LEAST_STUD * _k)
	camera.max_distance = maxf(studs, framed * 1.1)


func fit() -> void:
	_frame()


## A new model in Simple: on the sketch's plate, framed (ModelBar.started_new).
func new_sketch() -> void:
	_sketch()
	_frame()


## The least a stud can be drawn now, in points, as far back as the view may
## go: for a check.
func least_stud_points() -> float:
	var camera: CadCamera = app.get("_camera")
	var tall: float = get_viewport().get_visible_rect().size.y
	var lens: float = 2.0 * tan(deg_to_rad(camera.fov) * 0.5)
	return BrickLattice.STUD * tall / (lens * camera.max_distance * _k)


static func _pose(camera: CadCamera) -> Array:
	return [camera.get("_target_yaw"), camera.get("_target_pitch"), camera.get("_target_distance"),
		camera.get("_target_focus"), camera.get("_target_frame")]


## The view put at [param pose] at once, the target and the camera alike.
static func _set_pose(camera: CadCamera, pose: Array) -> void:
	camera.set("_target_yaw", pose[0])
	camera.set("_target_pitch", pose[1])
	camera.set("_target_distance", pose[2])
	camera.set("_target_focus", pose[3])
	camera.set("_target_frame", pose[4])
	camera.call("_apply", 1.0)


## What Simple leaves alone said once a model, plainly.
func _tell_left_alone() -> void:
	var world: BrickWorld = app.get("_world")
	if world == null or _told_left.has(world.generation()):
		return
	# Counted once a model, none or some: a switch back and forth on a set
	# of thousands counts nothing again.
	_told_left[world.generation()] = true
	var alone: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if not left_alone(brick.id).is_empty():
			alone += 1
	if alone == 0:
		return
	_say(atr("Simple leaves %d parts as they are (in sub-assemblies, tilted or bendy): Full changes them")
		% alone, 6000)


## Why Simple leaves [param brick_id] alone, or "" when it can edit it: a
## part of a sub-assembly or a figure, one tilted off the studs' way or
## turned off a quarter, or a piece of a bendy part.
func left_alone(brick_id: int) -> String:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var builder: Builder = app.get("_builder")
	var brick: BrickWorld.Brick = world.get_brick(brick_id) if world != null else null
	if brick == null or store.scenery.has(brick_id):
		return ""
	if not brick.unit.is_empty() or not brick.group.is_empty() or builder.takes(brick_id).size() > 1:
		return "sub-assembly"
	if Flex.kind_of_piece(brick.part_id) != "" or Bands.is_piece_id(brick.part_id):
		return "bendy"
	var basis: Basis = brick.transform.basis.orthonormalized()
	if basis.y.dot(Vector3.UP) < 0.999 or (absf(basis.x.x) < 0.999 and absf(basis.x.z) < 0.999):
		return "tilted"
	return ""


# -- the colours and the tray ---------------------------------------------------


func _on_swatch(code: int) -> void:
	_colour = code
	var builder: Builder = app.get("_builder")
	if builder != null:
		builder.held_color = code
		# A brick selected takes it: the recolour, one step to undo.
		if not builder.selection.is_empty() and not builder.is_carrying():
			var painted: int = builder.paint_selection(code)
			if painted > 0:
				counts["painted"] += 1
				_edited()
				_say(atr("Painted %s") % _colour_name(code))
	_paint_swatches()
	_dress_tiles()


func _on_group(n: int) -> void:
	if n == _group:
		return
	_group = n
	_rebuild()


func _paint_swatches() -> void:
	var library: PartLibrary = app.get("_library")
	for swatch: Button in _swatches:
		var code: int = int(swatch.get_meta("colour"))
		var shown: Color = library.color(code).shown if library != null else Color.GRAY
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var face := StyleBoxFlat.new()
			face.bg_color = shown
			face.set_corner_radius_all(ceili(p(SWATCH * 0.5)))
			if code == _colour:
				face.border_color = Color.WHITE
				face.set_border_width_all(ceili(p(3)))
			else:
				face.border_color = Color(1, 1, 1, 0.22)
				face.set_border_width_all(1)
			swatch.add_theme_stylebox_override(state, face)


func _dress_tab(tab: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var face := StyleBoxFlat.new()
		var on: bool = state.contains("pressed")
		face.bg_color = Color(0.2, 0.22, 0.26, 1.0) if on else Color(1, 1, 1, 0.04)
		face.set_corner_radius_all(ceili(p(10)))
		face.border_color = Color(0.949, 0.804, 0.216) if on else Color(1, 1, 1, 0.08)
		face.set_border_width_all(ceili(p(2)) if on else 1)
		face.content_margin_left = p(4)
		face.content_margin_right = p(4)
		tab.add_theme_stylebox_override(state, face)
	tab.add_theme_color_override("font_color", Color(0.706, 0.725, 0.761))
	tab.add_theme_color_override("font_pressed_color", Color.WHITE)
	tab.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	tab.add_theme_color_override("font_hover_color", Color.WHITE)


func _dress_tiles() -> void:
	for tile: Control in _tiles:
		var face := StyleBoxFlat.new()
		var chosen: bool = str(tile.get_meta("part")) == _chosen
		face.bg_color = Color(0.2, 0.22, 0.26, 1.0) if not chosen else Color(0.2, 0.3, 0.46, 1.0)
		face.set_corner_radius_all(ceili(p(12)))
		face.border_color = LIT if chosen else Color(1, 1, 1, 0.1)
		face.set_border_width_all(ceili(p(2)) if chosen else 1)
		face.set_content_margin_all(p(4))
		tile.add_theme_stylebox_override("panel", face)


## A tile's picture asked for in the colour chosen, until it is drawn.
func _picture_tiles() -> void:
	var thumbnails: PartThumbnails = app.get("_thumbnails")
	if thumbnails == null:
		return
	for n: int in _tiles.size():
		var part: String = str(_tiles[n].get_meta("part"))
		if _drawn_in.get(n, []) == [part, _colour]:
			continue
		var picture: ImageTexture = thumbnails.request(part, _colour)
		if picture != null:
			_pictures[n].texture = picture
			_drawn_in[n] = [part, _colour]


## A press, a drag and a let-go on a brick's tile, by a finger (as Godot
## raises a click from it) or a mouse: a drag carries it over the model, a
## tap chooses it for taps on the model.
func _tile_input(event: InputEvent, tile: Control, part: String) -> void:
	var button := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		tile.accept_event()
		return
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		tile.accept_event()
		if button.pressed:
			_tray_part = part
			_tray_from = button.global_position
			_tray_travel = 0.0
			_tray_dragging = false
			return
		if _tray_part != part:
			return
		_tray_part = ""
		if not _tray_dragging:
			_tap_tile(part)
			return
		_tray_dragging = false
		_drop_from_tray(_aimed(button.global_position, p(RAMP)), button.global_position)
		return
	if motion != null and _tray_part == part and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		tile.accept_event()
		_tray_travel = maxf(_tray_travel, motion.global_position.distance_to(_tray_from))
		if not _tray_dragging and _tray_travel > p(SLOP):
			_tray_dragging = true
			_select_none()
			_take(part)
		if _tray_dragging:
			_aim(_aimed(motion.global_position, p(RAMP)))


## A press in the tray beside every tile, in a gap or its edge: the
## nearest tile's, as a fingertip is wider than the gap (simplep1's walk 1:
## the hurried newcomer's drags began on the tray's edge 5 times in 10).
func _foot_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	var pressed_at: Vector2 = Vector2.INF
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		pressed_at = button.global_position
	elif touch != null and touch.pressed:
		pressed_at = _foot.get_global_transform() * touch.position
	if pressed_at.x < INF:
		_foot_tile = tile_at(pressed_at)
	if _foot_tile != null and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		_foot.accept_event()
		return
	if _foot_tile != null and event is InputEventMouse:
		_tile_input(event, _foot_tile, str(_foot_tile.get_meta("part")))
		if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			_foot_tile = null


## The tile a press at [param point] is on, or the nearest within the gaps
## and the tray's edge: null for none.
func tile_at(point: Vector2) -> Control:
	var found: Control = null
	var best: float = p(MARGIN + 2.0)
	for tile: Control in _tiles:
		var rect: Rect2 = tile.get_global_rect()
		var off: Vector2 = (rect.get_center() - point).abs() - rect.size * 0.5
		var away: float = maxf(off.x, off.y)
		if away <= best:
			best = away
			found = tile
	return found


func _tap_tile(part: String) -> void:
	counts["tapped"] += 1
	_ghost_shown = false
	_chosen = "" if _chosen == part else part
	_dress_tiles()
	if not _chosen.is_empty():
		_select_none()
		_take(_chosen)
		var builder: Builder = app.get("_builder")
		if builder != null:
			builder.hide_preview()
	else:
		_put_hand_away()


## [param part] in hand in the colour chosen, as the bin's pick has it.
func _take(part: String) -> void:
	var builder: Builder = app.get("_builder")
	if builder == null:
		return
	builder.held_color = _colour
	if builder.held_part != part or str((app.get("_verbs") as EditVerbs).mode) != "place":
		app.call("_on_part_chosen", part)
	builder.held_color = _colour


## Where a finger at [param at] aims the ghost, [param travel] points into
## its drag: over it by [member lift_points], eased in. A mouse's pointer
## hides nothing, and aims where it points.
func _aimed(at: Vector2, travel: float) -> Vector2:
	if _mouse_now():
		return at
	var eased: float = clampf(travel / p(RAMP), 0.0, 1.0)
	return at + Vector2(0.0, -p(lift_points) * eased)


## Whether the pointer at work is a mouse's, not a finger's.
func _mouse_now() -> bool:
	return _mouse or (not _tray_part.is_empty() and _touches.is_empty() and not Phone.on())


## The ghost aimed at [param at]: on the nearest legal studs, or out of
## sight over the interface.
func _aim(at: Vector2) -> void:
	var builder: Builder = app.get("_builder")
	if builder == null:
		return
	if _over_ui(at):
		builder.hide_preview()
		return
	app.call("_refresh_preview", at)


func _drop_from_tray(at: Vector2, finger: Vector2, from: String = "tray") -> void:
	var builder: Builder = app.get("_builder")
	_ghost_shown = false
	last_drop = {"aimed": at, "put": [], "from": from}
	if builder == null:
		return
	if _over_ui(at) or _foot.get_global_rect().has_point(finger) or (app.get("_store") as ModelStore).laying:
		# Let go over the tray: put back, nothing down.
		counts["cancelled"] += 1
		last_drop["why"] = "over the tray"
		_put_hand_away()
		return
	_place_at(at)
	_put_hand_away()


## One of the part in hand put down where [param at] aims, seated, or
## refused and said so.
func _place_at(at: Vector2) -> void:
	app.call("_aim_at", at)
	_put_down()


## One of the part in hand put down where its ghost stands, seated, or
## refused and said so.
func _put_down() -> void:
	var builder: Builder = app.get("_builder")
	last_drop["valid"] = builder.can_place()
	last_drop["ghost"] = builder.ghost_transform()
	var id: int = builder.place() if builder.can_place() else 0
	if id != 0:
		counts["put"] += 1
		last_drop["put"] = [id]
		_seat([id])
	else:
		counts["refused"] += 1
		last_drop["why"] = "no room"
		_say(atr("No room there"))


## Nothing in hand once a drop is done, unless a tap chose a brick: the
## ghost goes, and the tool is Select's again, so nothing a finger does
## next puts a part down by itself.
func _put_hand_away() -> void:
	var builder: Builder = app.get("_builder")
	var verbs: EditVerbs = app.get("_verbs")
	if builder == null or verbs == null:
		return
	builder.hide_preview()
	if _chosen.is_empty() and verbs.mode == "place":
		verbs.set_mode("select")
	elif not _chosen.is_empty():
		_take(_chosen)
		builder.hide_preview()


## The part a tap on the model puts down: the tray's choice, or a part in
## hand to put down that Simple did not choose (kept through the switch from
## Full, or picked by a key), so it has a ghost and goes down as the tray's
## would. Empty when none.
func _held() -> String:
	if not _chosen.is_empty():
		return _chosen
	var builder: Builder = app.get("_builder")
	var verbs: EditVerbs = app.get("_verbs")
	if builder == null or verbs == null or builder.is_carrying() or verbs.mode != "place":
		return ""
	return builder.held_part


## Whether a tap's ghost is up, waiting for a tap on it to go down.
func ghost_waits() -> bool:
	var builder: Builder = app.get("_builder")
	return _ghost_shown and builder != null and builder.has_preview() and not _held().is_empty()


## The ghost's box on the screen; empty while there is none.
func ghost_rect() -> Rect2:
	var box: AABB = _ghost_box()
	if box.size == Vector3.ZERO:
		return Rect2()
	var camera: CadCamera = app.get("_camera")
	var rect := Rect2(camera.unproject_position(box.position), Vector2.ZERO)
	for n: int in 8:
		rect = rect.expand(camera.unproject_position(box.get_endpoint(n)))
	return rect


func _ghost_box() -> AABB:
	var builder: Builder = app.get("_builder")
	if builder == null or not builder.has_preview():
		return AABB()
	var part: Lbm.PartMesh = builder.library.mesh_for(builder.held_part)
	return builder.ghost_transform() * part.bounds if part != null else AABB()


## Whether a finger at [param at] is on the shown ghost, with a fingertip's
## slack: its ray through the ghost's box grown by GHOST_SLACK. Not the box's
## rectangle on the screen, which round a brick seen corner on takes in
## studs beside it, where a tap meant to show it there instead.
func _on_ghost(at: Vector2) -> bool:
	if not ghost_waits():
		return false
	var camera: CadCamera = app.get("_camera")
	return _ghost_box().grow(GHOST_SLACK).intersects_ray(camera.ray_origin(at), camera.ray_normal(at)) != null


## The point on the screen that aims the ghost where it stands: the middle
## of its foot, on what it stands on.
func _ghost_foot() -> Vector2:
	var box: AABB = _ghost_box()
	var camera: CadCamera = app.get("_camera")
	return camera.unproject_position(Vector3(box.get_center().x, box.position.y, box.get_center().z))


## The tray's choice let go of, and the tool Select's again.
func _unchoose() -> void:
	if _chosen.is_empty():
		return
	_chosen = ""
	_dress_tiles()
	_put_hand_away()


# -- a selected brick's buttons --------------------------------------------------------


func _selected() -> Array:
	var builder: Builder = app.get("_builder")
	return builder.selection.keys() if builder != null else []


func _select_none() -> void:
	var builder: Builder = app.get("_builder")
	if builder != null and not builder.selection.is_empty():
		builder.clear_selection()


## Turn: the selected brick a quarter about up, where it stands. Where there
## is no room to turn, what is in the way is lit and it stays as it was (the
## studio's turn takes it into hand instead, and a newcomer's next colour
## then painted nothing: appwalk's proposal 2).
func turn_selected() -> int:
	var builder: Builder = app.get("_builder")
	var verbs: EditVerbs = app.get("_verbs")
	if builder == null or builder.selection.is_empty() or builder.is_carrying():
		return 0
	var turned: int = builder.turn_selection_by(90.0)
	if turned == 0:
		verbs.call("_flash", builder.refused_by)
		_say(atr("No room to turn it there"))
		return 0
	counts["turned"] += 1
	_edited()
	_say(atr("Turned"))
	return turned


## Copy: a copy put down beside the selection and selected, to be dragged
## where it goes (EditVerbs.duplicate_beside, Edit, Duplicate's); with no room
## beside, a copy in hand, put down by a tap or a drag.
func copy_selected() -> int:
	var builder: Builder = app.get("_builder")
	var verbs: EditVerbs = app.get("_verbs")
	if builder == null or builder.selection.is_empty() or builder.is_carrying():
		return 0
	var copied: int = verbs.duplicate_beside()
	if copied > 0:
		counts["copied"] += 1
		if builder.is_carrying():
			_say(atr("Tap where the copy goes"))
		else:
			var put: Array = builder.selection.keys()
			_seat(put)
			_say(atr("A copy beside it: drag it where it goes"))
	return copied


## Delete: the selection taken off, one step to undo.
func delete_selected() -> int:
	var builder: Builder = app.get("_builder")
	if builder == null or builder.selection.is_empty() or builder.is_carrying():
		return 0
	var gone: int = builder.remove_selection()
	if gone > 0:
		counts["deleted"] += 1
		_edited()
		_say(atr("Deleted"))
	return gone


func _edited() -> void:
	var verbs: EditVerbs = app.get("_verbs")
	if verbs != null and verbs.edited.is_valid():
		verbs.edited.call()


func _run(what: String) -> void:
	_cancel_press()
	var shell: Shell = app.get("_shell")
	if shell != null:
		shell.run(what)


## Two fingers tapped undo and three redo, as Procreate's do: Shell's, as
## the phone's studio has them. A phone's own shell hears them there.
func _fingers_tapped(fingers: int) -> void:
	if not is_visible_in_tree() or app.get("_phone") != null:
		return
	var shell: Shell = app.get("_shell")
	if shell != null:
		shell.run_key("undo" if fingers == 2 else "redo")


## A finger tapped twice on the brick it selected turns it, as Turn does.
func _double_tapped(at: Vector2) -> void:
	if not is_visible_in_tree():
		return
	var verbs: EditVerbs = app.get("_verbs")
	var builder: Builder = app.get("_builder")
	var brick: int = verbs.brick_at(at)
	# A part in hand: its two taps showed it and put it down, and turn nothing.
	if brick != 0 and builder.selection.has(brick) and _held().is_empty():
		turn_selected()


# -- words -----------------------------------------------------------------------------


## The line over the model's foot: what a finger does here, or what was
## just said.
func hint() -> String:
	if Time.get_ticks_msec() < _said_until:
		return _said
	var builder: Builder = app.get("_builder")
	var finger: bool = Phone.on()
	if _moving:
		return atr("Let go to put it down · over the bin to delete it")
	if _tray_dragging or (_ghost_drag and _travel > p(SLOP)):
		return atr("Let go to put it down")
	if builder != null and builder.is_carrying():
		return atr("Tap where the copy goes")
	if ghost_waits():
		return atr("Tap it to put it down · drag it to move it")
	if not _held().is_empty():
		return atr("Tap where it goes") if finger else atr("Tap the model to put one there")
	if builder != null and not builder.selection.is_empty():
		return atr("Drag it to move it · tap a colour to paint it")
	return atr("Drag a brick onto the model · two fingers turn the view") if finger \
		else atr("Drag a brick onto the model · drag the view to turn it")


func _say(words: String, ms: int = SAID_MS) -> void:
	_said = words
	_said_until = Time.get_ticks_msec() + ms


## What the studio says (ModelBar.said), on Simple's line while it is up.
func _hear(words: String) -> void:
	if is_visible_in_tree() and not words.strip_edges().is_empty():
		_say(Phone.touch_words(words) if Phone.on() else words)


func _lay_pill() -> void:
	if _pill == null:
		return
	var words: String = hint()
	if _pill_words.text != words:
		_pill_words.text = words
	var room: Vector2 = get_viewport().get_visible_rect().size
	var inner: float = minf(room.x - p(MARGIN * 2.0 + 24.0), p(420.0))
	if _pill_words.custom_minimum_size.x != inner:
		_pill_words.custom_minimum_size.x = inner
	var size_now: Vector2 = _pill.get_combined_minimum_size()
	if _pill.size != size_now:
		_pill.size = size_now
	var at := Vector2((room.x - size_now.x) * 0.5,
		room.y - p(_tray_tall) - p(MARGIN + 4.0) - p(BIG) - p(8.0) - size_now.y)
	if _pill.position != at:
		_pill.position = at
	var shown: bool = not words.is_empty()
	if _pill.visible != shown:
		_pill.visible = shown


# -- a finger on the model ----------------------------------------------------------


## Whether the camera leaves the one finger down to this layer (CadCamera
## .finger_taken): always, one finger builds.
func finger_taken() -> bool:
	return true


## Whether Main leaves [param event] to this layer and the camera: every
## finger's touch and drag, the clicks Godot raises from them, and the
## mouse's buttons and moves over the model. The camera hears its own still
## (two fingers, the wheel, the right and middle buttons).
func takes(event: InputEvent) -> bool:
	if not is_visible_in_tree():
		return false
	return event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouse


func _input(event: InputEvent) -> void:
	# A second finger while a brick is carried out of the tray: the view's,
	# and the brick goes back to the tray, as a second finger always puts
	# what the first had back.
	var touch := event as InputEventScreenTouch
	if touch == null or not is_visible_in_tree():
		return
	if touch.pressed:
		_touches[touch.index] = true
		if _touches.size() >= 2 and _tray_dragging:
			_tray_dragging = false
			_tray_part = ""
			counts["cancelled"] += 1
			last_drop = {"put": [], "from": "tray", "why": "a second finger"}
			_put_hand_away()
	else:
		_touches.erase(touch.index)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or (app.get("_store") as ModelStore).laying:
		return
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	if touch != null:
		if touch.pressed:
			if _finger == -1 and not _mouse:
				_press(touch.position, touch.index)
			elif _finger != -1:
				_second_finger()
		elif touch.index == _finger:
			_release(touch.position)
		elif _others > 0:
			_others -= 1
		return
	if drag != null:
		if drag.index == _finger and _others == 0:
			_drag(drag.position)
		return
	var button := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	# A finger's clicks are its touches' already.
	if (button != null and button.device == InputEvent.DEVICE_ID_EMULATION) \
			or (motion != null and motion.device == InputEvent.DEVICE_ID_EMULATION):
		return
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and _finger == -1 and not _mouse:
			if bool(app.call("_over_panel_at", button.position)):
				return
			_mouse = true
			_press(button.position, -2)
		elif not button.pressed and _mouse:
			_release(button.position)
		return
	if motion != null:
		if _mouse:
			_drag(motion.position)
		elif (app.get("_builder") as Builder).is_carrying() or not _held().is_empty():
			# A copy in hand, or a brick chosen: its ghost where the mouse is.
			_aim(motion.position)


func _press(at: Vector2, index: int) -> void:
	if _touches.size() > 1 or bool(app.call("_over_panel_at", at)):
		_mouse = false
		return
	_finger = index
	_down = at
	_at = at
	_travel = 0.0
	_hinted = false
	_others = 0
	_turning_view = false
	_left_one = 0
	_brick = _brick_near(at)
	# Down on the ghost a tap showed: the finger's to carry, not a brick's.
	_ghost_drag = index != -2 and _on_ghost(at)
	if _ghost_drag:
		_ghost_from = _ghost_foot()
		_brick = 0
	var builder: Builder = app.get("_builder")
	# A copy in hand rides the finger from where it comes down.
	if builder.is_carrying():
		_brick = 0
		_aim(_aimed(at, p(RAMP)))


## A second finger: the camera's. A part being moved goes back.
func _second_finger() -> void:
	_others += 1
	_brick = 0
	if _ghost_drag:
		# The shown ghost carried: put back, as a second finger puts back
		# what the first had.
		_ghost_drag = false
		_ghost_shown = false
		(app.get("_builder") as Builder).hide_preview()
		counts["cancelled"] += 1
		last_drop = {"put": [], "from": "tap", "why": "a second finger"}
	if _moving:
		_moving = false
		var verbs: EditVerbs = app.get("_verbs")
		verbs.put_away()
		counts["cancelled"] += 1
		last_drop = {"put": [], "from": "model", "why": "a second finger"}
		_moved_from.clear()
		_put_hand_away()


func _drag(at: Vector2) -> void:
	_at = at
	_travel = maxf(_travel, at.distance_to(_down))
	var builder: Builder = app.get("_builder")
	if _ghost_drag:
		# The ghost moves as the finger does, from where it stood, and comes
		# up over the finger as the drag goes on, as one out of the tray.
		if _travel > p(SLOP):
			_aim(_aimed(_ghost_from + (at - _down), _travel))
		return
	if not _moving and _brick != 0 and _travel > p(SLOP):
		_start_move()
	if _moving:
		_aim(_aimed(at, _travel))
		_bin_lit(at)
		return
	if builder.is_carrying():
		_aim(_aimed(at, p(RAMP)))
		return
	if _mouse:
		# A mouse has no second finger: its left drag on nothing turns the view.
		if not _turning_view and _travel > p(4.0):
			_turning_view = true
			counts["view_turns"] += 1
			(app.get("_camera") as CadCamera).begin_drag(MOUSE_BUTTON_LEFT, _down, "turn")
		return
	# One finger on nothing: nothing moves; once, how the view turns.
	if _brick == 0 and not _hinted and _travel > p(36.0):
		_hinted = true
		counts["hints"] += 1
		_say(atr("Two fingers turn the view"))


## The press's brick lifted to follow the finger, with what rests on it
## unless that is a part Simple leaves alone.
func _start_move() -> void:
	var camera: CadCamera = app.get("_camera")
	var verbs: EditVerbs = app.get("_verbs")
	var builder: Builder = app.get("_builder")
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	_unchoose()
	if not builder.selection.has(_brick):
		builder.select_brick(_brick, false)
	var found: Dictionary = Carry.riders(world, builder.lattice, builder.selection.keys(), store.scenery,
		builder.takes, builder.locked)
	var alone: bool = false
	for rider: Variant in found["riders"]:
		if not left_alone(int(rider)).is_empty():
			alone = true
	# What the finger carries, read before the lift: once lifted it is in
	# hand, and the selection no longer names it (a drag into the bin
	# deleted nothing).
	var carried: Array = builder.selection.keys()
	if not alone:
		carried.append_array(found["riders"])
	_moved_from.clear()
	for id: Variant in carried:
		var brick: BrickWorld.Brick = world.get_brick(int(id))
		if brick != null:
			_moved_from[int(id)] = brick.transform
	_moving = verbs.drag_start(_brick, false, alone, [camera.ray_origin(_down), camera.ray_normal(_down)])
	if not _moving:
		_moved_from.clear()
		_brick = 0
		return


func _bin_lit(at: Vector2) -> void:
	var over: bool = _bin.get_global_rect().grow(p(8.0)).has_point(at)
	_bin.modulate = Color(1.25, 1.25, 1.25) if over else Color.WHITE


func _release(at: Vector2) -> void:
	_finger = -1
	var mouse: bool = _mouse
	_mouse = false
	var was_moving: bool = _moving
	_moving = false
	var others: int = _others
	_others = 0
	var brick: int = _brick
	_brick = 0
	var ghost_drag: bool = _ghost_drag
	_ghost_drag = false
	var camera: CadCamera = app.get("_camera")
	if _turning_view:
		_turning_view = false
		camera.end_drag(MOUSE_BUTTON_LEFT)
		return
	if others > 0:
		return
	var builder: Builder = app.get("_builder")
	var verbs: EditVerbs = app.get("_verbs")
	if was_moving:
		_end_move(at)
		return
	var tap: bool = _travel <= p(SLOP)
	if ghost_drag and not tap:
		# The shown ghost carried by the finger: down where it is let go, as
		# one out of the tray.
		_drop_from_tray(_aimed(_ghost_from + (at - _down), _travel), at, "tap")
		return
	# A copy in hand: put down where the finger aims, tapped or dragged.
	if builder.is_carrying() and verbs.mode != "place":
		var aim: Vector2 = at if tap else _aimed(at, p(RAMP))
		last_drop = {"aimed": aim, "put": [], "from": "copy"}
		app.call("_drop_dragged", aim)
		if not builder.is_carrying():
			counts["put"] += 1
			last_drop["put"] = builder.selection.keys()
			_seat(builder.selection.keys())
		return
	if not tap:
		return
	# A tap with a brick chosen on the tray, or a part in hand: a mouse's
	# click puts one down where its ghost was; a finger's tap shows the ghost
	# there, and a tap on that ghost puts it down.
	if not _held().is_empty():
		if not _chosen.is_empty():
			_take(_chosen)
		last_drop = {"aimed": at, "put": [], "from": "tap"}
		if mouse:
			_ghost_shown = false
			_place_at(at)
			builder.hide_preview()
		elif _on_ghost(at):
			last_drop["aimed"] = _ghost_foot()
			_put_down()
			if not (last_drop["put"] as Array).is_empty():
				_ghost_shown = false
				builder.hide_preview()
		else:
			_aim(at)
			_ghost_shown = builder.has_preview()
			last_drop["shown"] = _ghost_shown
		return
	var under: int = verbs.brick_at(at) if mouse else brick
	if under == 0:
		under = _left_one
	if under != 0 and not left_alone(under).is_empty():
		counts["left_alone"] += 1
		_say(atr("Simple leaves that part as it is: Full changes it"))
		builder.clear_selection()
		return
	if under != 0:
		builder.select_brick(under, false)
		counts["selected"] += 1
		_colour_of(under)
		return
	builder.clear_selection()


## The colour strip showing the colour of [param brick_id], selected.
func _colour_of(brick_id: int) -> void:
	var world: BrickWorld = app.get("_world")
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick != null and COLOURS.has(brick.color_code) and brick.color_code != _colour:
		_colour = brick.color_code
		(app.get("_builder") as Builder).held_color = _colour
		_paint_swatches()
		_dress_tiles()


func _end_move(at: Vector2) -> void:
	var builder: Builder = app.get("_builder")
	var world: BrickWorld = app.get("_world")
	var verbs: EditVerbs = app.get("_verbs")
	_bin.modulate = Color.WHITE
	var aim: Vector2 = _aimed(at, _travel)
	last_drop = {"aimed": aim, "put": [], "from": "model"}
	var ids: Array = _moved_from.keys()
	# Over the bin: put back and taken off, one step to undo.
	if _bin.get_global_rect().grow(p(8.0)).has_point(at):
		builder.cancel_carry()
		builder.clear_selection()
		for id: int in ids:
			builder.select_brick(id, true)
		var gone: int = builder.remove_selection()
		counts["binned"] += 1
		last_drop["why"] = "the bin"
		last_drop["gone"] = gone
		_moved_from.clear()
		_edited()
		_say(atr("Deleted"))
		_put_hand_away()
		return
	# Over the tray: put back where it was.
	if _foot.get_global_rect().has_point(at) or _over_ui(aim):
		verbs.put_away()
		counts["cancelled"] += 1
		last_drop["why"] = "over the tray"
		_moved_from.clear()
		_put_hand_away()
		return
	app.call("_drop_dragged", aim)
	var moved: Array = []
	for id: int in _moved_from:
		var brick: BrickWorld.Brick = world.get_brick(id)
		if brick != null and not brick.transform.is_equal_approx(_moved_from[id]):
			moved.append(id)
	if not builder.is_carrying() and not moved.is_empty():
		counts["moved"] += 1
		last_drop["put"] = moved
		_seat(moved)
	else:
		counts["refused"] += 1
		last_drop["why"] = "no room"
	_moved_from.clear()
	_put_hand_away()


## Whatever a finger was doing let go of, put back: the switch to Full or a
## button pressed mid-drag.
func _cancel_press() -> void:
	if _moving:
		var verbs: EditVerbs = app.get("_verbs")
		verbs.put_away()
	if _turning_view:
		(app.get("_camera") as CadCamera).end_drag(MOUSE_BUTTON_LEFT)
	_moving = false
	_turning_view = false
	_finger = -1
	_mouse = false
	_brick = 0
	_ghost_drag = false
	_ghost_shown = false
	_moved_from.clear()
	if _tray_dragging:
		_tray_dragging = false
		_tray_part = ""
		_put_hand_away()
	_unchoose()


## The part under [param at] Simple can edit, or the nearest within a
## fingertip; a part it leaves alone is kept apart ([member _left_one]).
func _brick_near(at: Vector2) -> int:
	var verbs: EditVerbs = app.get("_verbs")
	var under: int = verbs.brick_at(at)
	if under != 0:
		if left_alone(under).is_empty():
			return under
		_left_one = under
		return 0
	for ring: float in [NEAR * 0.5, NEAR]:
		for turn: int in 8:
			var found: int = verbs.brick_at(at + Vector2.from_angle(TAU * turn / 8.0) * p(ring))
			if found != 0 and left_alone(found).is_empty():
				return found
	return 0


# -- the seat ----------------------------------------------------------------------


## The parts just put down drawn coming the last few LDU onto their studs.
## Only their picture moves (BrickWorld.set_drawn): the model has them
## where they stand from the moment they are down.
func _seat(ids: Array) -> void:
	var world: BrickWorld = app.get("_world")
	if world == null or not world.drawn_ids().is_empty() and _seating.is_empty():
		return
	_seating.clear()
	for id: Variant in ids:
		var brick: BrickWorld.Brick = world.get_brick(int(id))
		if brick != null:
			_seating[int(id)] = brick.transform
	_seat_from = Time.get_ticks_msec()
	counts["seated"] = int(counts.get("seated", 0)) + 1
	_seat_frame()


func _seat_frame() -> void:
	if _seating.is_empty():
		return
	var world: BrickWorld = app.get("_world")
	var t: float = (Time.get_ticks_msec() - _seat_from) / SEAT_MS
	if t >= 1.0 or ShellPrefs.reduce_motion():
		_seating.clear()
		world.set_drawn({})
		return
	var above: float = SEAT_LDU * pow(1.0 - t, 3.0)
	var drawn: Dictionary = {}
	for id: int in _seating:
		if world.get_brick(id) == null:
			continue
		var at: Transform3D = _seating[id]
		drawn[id] = Transform3D(at.basis, at.origin + Vector3.UP * above)
	world.set_drawn(drawn)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_picture_tiles()
	_seat_frame()
	_lay_pill()
	var shell: Shell = app.get("_shell")
	var builder: Builder = app.get("_builder")
	if shell != null and _undo != null:
		_undo.disabled = not shell.can("undo")
		_redo.disabled = not shell.can("redo")
	var picked: bool = builder != null and not builder.selection.is_empty() and not builder.is_carrying()
	for button: Button in [_turn, _copy, _delete]:
		if button.visible != (picked and not _moving):
			button.visible = picked and not _moving
	if _bin.visible != _moving:
		_bin.visible = _moving
	# Nothing is aimed while no finger is: the ghost a stale pointer left goes.
	# A part in hand keeps its own (the switch check's 2 x 4 from the studio's
	# pick had its ghost taken each frame, and nothing could go down).
	if builder != null and not _tray_dragging and not _moving and builder.has_preview() \
			and not builder.is_carrying() and _held().is_empty():
		builder.hide_preview()


# -- words -----------------------------------------------------------------------------


func _part_name(part: String) -> String:
	return str(app.call("_part_said", part)) if app != null and app.has_method("_part_said") else part


func _colour_name(code: int) -> String:
	var library: PartLibrary = app.get("_library") if app != null else null
	return library.color(code).name if library != null else str(code)


## What a check reads: the controls by the names it presses them by, while
## the layer is up.
func controls_by_name() -> Dictionary:
	if not is_visible_in_tree():
		return {}
	var out: Dictionary = {"simple_foot": _foot}
	for button: Button in [_undo, _redo, _turn, _copy, _delete, _fit, _bin]:
		if button.is_visible_in_tree():
			out[button.name] = button
	for tab: Button in _tabs:
		out[tab.name] = tab
	for tile: Control in _tiles:
		out[tile.name] = tile
	for swatch: Button in _swatches:
		out[swatch.name] = swatch
	return out


## The tile of [param part], for a check to drag from: its group's tab is
## pressed first if it is not the one showing.
func tile_of(part: String) -> Control:
	for n: int in GROUPS.size():
		if (GROUPS[n][1] as Array).has(part) and n != _group:
			_on_group(n)
	for tile: Control in _tiles:
		if str(tile.get_meta("part")) == part:
			return tile
	return null


## Every part of the tray, in its groups' order.
static func tray_parts() -> Array[String]:
	var out: Array[String] = []
	for group: Array in GROUPS:
		for part: String in group[1]:
			out.append(part)
	return out


func chosen_colour() -> int:
	return _colour


func chosen_brick() -> String:
	return _chosen


func shown_group() -> int:
	return _group


## The round button named [param what] ("undo", "turn", "bin"...), for a check.
func button(what: String) -> Button:
	return {"undo": _undo, "redo": _redo, "turn": _turn, "copy": _copy, "delete": _delete,
		"bin": _bin, "fit": _fit}.get(what)
