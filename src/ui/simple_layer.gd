## Simple mode's layer over the model, its first prototype (simplep1): a
## tray of eight bricks with pictures and a strip of eight solid colours
## along the foot, a brick dragged out of the tray onto the model with its
## ghost on the nearest legal studs, let go to drop it with a seat, and Undo
## and Redo as big buttons by the thumb. Laid over the phone's or a
## tablet's studio (PhoneShell), whose foot row it takes the place of.
##
## Behind a hidden switch: ShellPrefs "simple" (ShellPrefs.simple_map), "a"
## or "b" for the finger map, "" for the full studio. Nothing in the window
## sets it yet; a browser's address does (?simple=b, ?simple=off).
##
## The plan is bench/results/simplemode-2026-11-24/PLAN.md; the walks that
## chose between the finger maps are bench/results/simplep1-2026-11-26/
## WALKS.md. The two maps:
##   a  where a finger starts decides: on a part it moves the part, on
##      empty space it turns the view, as the phone's studio does
##   b  how many fingers decides: one finger builds, and on empty space
##      turns nothing (a part within a fingertip of it is the one it
##      takes); two fingers turn the view and pinch it, and Fit frames it
##
## Every act is the studio's own, so nothing is converted and the full
## studio sees every brick: a brick goes down by Builder.place, as a part
## dragged out of the desktop's bin does (Main's part_dropped); a part
## moves by EditVerbs.drag_start's carry, put down by Main._drop_dragged;
## Undo and Redo are Shell's, and a two-finger tap still undoes.
class_name SimpleLayer
extends Control

## The tray, in the order it shows them: the bricks a first model is built
## of, two plates, a slope and a round.
const BRICKS: Array[String] = ["3001", "3003", "3004", "3010", "3020", "3022", "3039", "3062b"]
## Red, yellow, blue, green, orange, white, light bluish grey, black.
const COLOURS: Array[int] = [4, 14, 1, 2, 25, 15, 71, 0]
const STRIP := 52.0
const SWATCH := 44.0
const TILE := 68.0
const MARGIN := 8.0
const BIG := 60.0
## A tablet's tray, one row of eight, is this wide in points or more.
const ONE_ROW := 600.0
## How far a finger goes before its press is a drag, in points.
const SLOP := 10.0
## B: a part within this of the finger, in points, is the one it takes.
const NEAR := 26.0
## The seat: a brick put down comes the last of this many LDU onto its
## studs, in this many ms.
const SEAT_LDU := 14.0
const SEAT_MS := 160.0
const BACK := Color(0.11, 0.12, 0.14, 0.97)
const LIT := Color(0.36, 0.6, 1.0, 1.0)

## How far over the finger the ghost is aimed, in points: a fingertip
## hides what is under it, so the brick rides above it, as a phone's block
## puzzles lift their piece over the thumb. A part taken off the model eases
## into it over the drag's first [constant RAMP] points, so it does not
## jump; a brick out of the tray is over the finger at once (eased, a
## place just over the tray was aimed into it and refused, walk 2). Tuned
## by the walks (WALKS.md); 0 aims at the fingertip.
var lift_points: float = 56.0
const RAMP := 40.0

var app: Node
## "a" or "b": which finger map ([member map] in the header).
var map: String = "b"

var _k: float = 1.0
var _foot: PanelContainer
var _tiles: Array[Control] = []
var _pictures: Array[TextureRect] = []
var _swatches: Array[Button] = []
var _undo: Button
var _redo: Button
var _colour: int = 4
## The brick a tap on the tray chose: a tap on the model puts one there.
var _chosen: String = ""
## The tile a press in the tray's gaps went to (_foot_input).
var _foot_tile: Control = null
## Each tile's picture: the colour it was drawn in.
var _drawn_in: Dictionary = {}

# A brick dragged out of the tray (its tile's own input).
var _tray_part: String = ""
var _tray_from: Vector2 = Vector2.ZERO
var _tray_travel: float = 0.0
var _tray_dragging: bool = false

# The finger on the model (the camera sees it too).
var _finger: int = -1
var _down: Vector2 = Vector2.ZERO
var _travel: float = 0.0
var _brick: int = 0
var _moving: bool = false
var _others: int = 0
var _hinted: bool = false
var _touches: Dictionary = {}
## Where each part a finger is moving stood when it was taken.
var _moved_from: Dictionary = {}

# A seat being drawn: brick id -> where it stands.
var _seating: Dictionary = {}
var _seat_from: int = 0

## What a check reads of the last drop: where it was aimed, whether it
## went down, and the parts it put down or moved.
var last_drop: Dictionary = {}
## How many of each act there were.
var counts: Dictionary = {"put": 0, "moved": 0, "refused": 0, "cancelled": 0, "tapped": 0, "hints": 0}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	get_viewport().size_changed.connect(_rebuild, CONNECT_DEFERRED)
	var builder: Builder = app.get("_builder")
	if builder != null:
		_colour = builder.held_color if COLOURS.has(builder.held_color) else COLOURS[0]
		builder.held_color = _colour
	_paint_swatches()
	set_process(true)


func p(points: float) -> float:
	return points * _k


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_tiles.clear()
	_pictures.clear()
	_swatches.clear()
	_drawn_in.clear()
	_build()
	_paint_swatches()


func _build() -> void:
	_k = Phone.per_point(get_viewport())
	var across: float = get_viewport().get_visible_rect().size.x / maxf(_k, 0.001)
	var per_row: int = BRICKS.size() if across >= ONE_ROW else BRICKS.size() / 2
	var rows: int = BRICKS.size() / per_row

	_foot = PanelContainer.new()
	_foot.name = "simple_foot"
	_foot.mouse_filter = Control.MOUSE_FILTER_STOP
	var face := StyleBoxFlat.new()
	face.bg_color = BACK
	face.border_color = Color(1, 1, 1, 0.08)
	face.border_width_top = 1
	face.content_margin_left = p(MARGIN)
	face.content_margin_right = p(MARGIN)
	face.content_margin_top = p(4)
	face.content_margin_bottom = p(MARGIN)
	_foot.add_theme_stylebox_override("panel", face)
	var tall: float = STRIP + rows * (TILE + 4.0) + 4.0 + MARGIN
	_foot.anchor_left = 0.0
	_foot.anchor_right = 1.0
	_foot.anchor_top = 1.0
	_foot.anchor_bottom = 1.0
	_foot.offset_top = -p(tall)
	_foot.offset_bottom = 0.0
	_foot.gui_input.connect(_foot_input)
	add_child(_foot)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ceili(p(4)))
	_foot.add_child(column)

	# Colour first: the strip, a fingertip each.
	var strip := HBoxContainer.new()
	strip.custom_minimum_size.y = p(STRIP)
	strip.add_theme_constant_override("separation", 0)
	column.add_child(strip)
	for code: int in COLOURS:
		var cell := CenterContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		strip.add_child(cell)
		var swatch := Button.new()
		swatch.name = "simple_colour_%d" % code
		swatch.custom_minimum_size = Vector2(p(SWATCH), p(SWATCH))
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.accessibility_name = _colour_name(code)
		swatch.set_meta("colour", code)
		swatch.pressed.connect(_on_swatch.bind(code))
		cell.add_child(swatch)
		_swatches.append(swatch)

	# The bricks, pictured in the colour chosen.
	var grid := GridContainer.new()
	grid.columns = per_row
	grid.add_theme_constant_override("h_separation", ceili(p(4)))
	grid.add_theme_constant_override("v_separation", ceili(p(4)))
	column.add_child(grid)
	for n: int in BRICKS.size():
		var part: String = BRICKS[n]
		var tile := PanelContainer.new()
		tile.name = "simple_brick_%s" % part
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(p(Phone.TARGET), p(TILE))
		tile.mouse_filter = Control.MOUSE_FILTER_STOP
		tile.accessibility_name = _part_name(part)
		tile.tooltip_text = ""
		tile.set_meta("part", part)
		tile.gui_input.connect(_tile_input.bind(tile, part))
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.custom_minimum_size = Vector2(p(TILE - 12.0), p(TILE - 12.0))
		tile.add_child(picture)
		grid.add_child(tile)
		_tiles.append(tile)
		_pictures.append(picture)
	_dress_tiles()

	# Undo and Redo, big, by the thumb: over the model's foot, at its left.
	_undo = _big_button("undo")
	_redo = _big_button("redo")
	_lay_big()

	var phone: Control = app.get("_phone")
	if phone != null:
		phone.call("take_foot", p(tall), p(BIG + MARGIN + 4.0))
		phone.set("hint_from", Callable(self, &"hint"))


func _big_button(what: String) -> Button:
	var button := Button.new()
	button.name = "simple_" + what
	button.accessibility_name = "Undo" if what == "undo" else "Redo"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(p(BIG), p(BIG))
	button.size = Vector2(p(BIG), p(BIG))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon = Icons.icon_for(Toolbar.TOOLS + what + ".svg", p(30), Icons.density(self))
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var round := StyleBoxFlat.new()
		round.bg_color = Color(0.36, 0.6, 1.0, 0.55) if state.contains("pressed") \
			else Color(0.11, 0.12, 0.14, 0.86 if state != "disabled" else 0.55)
		# Under half its size: at half or over, a bordered StyleBoxFlat drew a
		# seam down the middle (walk 2's pictures).
		round.set_corner_radius_all(floori(p(BIG * 0.5) - 1.0))
		round.border_color = Color(1, 1, 1, 0.14)
		round.set_border_width_all(1)
		button.add_theme_stylebox_override(state, round)
	button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))
	button.pressed.connect(func() -> void:
		var shell: Shell = app.get("_shell")
		if shell != null:
			shell.run(what))
	add_child(button)
	return button


func _lay_big() -> void:
	if _undo == null or _foot == null:
		return
	var room: Vector2 = get_viewport().get_visible_rect().size
	var y: float = room.y + _foot.offset_top - p(MARGIN + 4.0) - p(BIG)
	_undo.position = Vector2(p(MARGIN + 4.0), y)
	_redo.position = Vector2(p(MARGIN + 4.0) + p(BIG) + p(MARGIN), y)


## The room the layer's own controls take: the foot and the big buttons.
func covers(point: Vector2) -> bool:
	for control: Control in [_foot, _undo, _redo]:
		if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return true
	return false


## Whether a brick aimed at [param point] is over the interface, not the
## model: the tray, or the studio's own panels. Not the big Undo and Redo:
## they float over the model's foot, and a ghost aimed there goes down
## there (walk 1: a house's corner behind Undo was refused four times).
func _over_ui(point: Vector2) -> bool:
	if _foot != null and _foot.get_global_rect().has_point(point):
		return true
	for control: Control in [_undo, _redo]:
		if control != null and control.get_global_rect().has_point(point):
			return false
	return bool(app.call("_over_panel_at", point))


## The foot's height, in the window's units.
func foot_height() -> float:
	return _foot.size.y if _foot != null else 0.0


# -- the colours and the tray ---------------------------------------------------


func _on_swatch(code: int) -> void:
	_colour = code
	var builder: Builder = app.get("_builder")
	if builder != null:
		builder.held_color = code
	_paint_swatches()
	_dress_tiles()


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


func _dress_tiles() -> void:
	for tile: Control in _tiles:
		var face := StyleBoxFlat.new()
		var chosen: bool = str(tile.get_meta("part")) == _chosen
		face.bg_color = Color(0.2, 0.22, 0.26, 1.0) if not chosen else Color(0.2, 0.3, 0.46, 1.0)
		face.set_corner_radius_all(ceili(p(12)))
		face.border_color = LIT if chosen else Color(1, 1, 1, 0.1)
		face.set_border_width_all(ceili(p(2)) if chosen else 1)
		face.content_margin_left = p(4)
		face.content_margin_right = p(4)
		face.content_margin_top = p(4)
		face.content_margin_bottom = p(4)
		tile.add_theme_stylebox_override("panel", face)


## A tile's picture asked for in the colour chosen, until it is drawn.
func _picture_tiles() -> void:
	var thumbnails: PartThumbnails = app.get("_thumbnails")
	if thumbnails == null:
		return
	for n: int in _tiles.size():
		var part: String = BRICKS[n]
		if int(_drawn_in.get(part, -1)) == _colour:
			continue
		var picture: ImageTexture = thumbnails.request(part, _colour)
		if picture != null:
			_pictures[n].texture = picture
			_drawn_in[part] = _colour


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
		_drop_from_tray(_aimed(button.global_position, p(RAMP)))
		return
	if motion != null and _tray_part == part and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		tile.accept_event()
		_tray_travel = maxf(_tray_travel, motion.global_position.distance_to(_tray_from))
		if not _tray_dragging and _tray_travel > p(SLOP):
			_tray_dragging = true
			_take(part)
		if _tray_dragging:
			_aim(_aimed(motion.global_position, p(RAMP)))


## A press in the tray beside every tile, in a gap or its edge: the
## nearest tile's, as a fingertip is wider than the gap (walk 1: the
## hurried newcomer's drags began on the tray's edge 5 times in 10).
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
	_chosen = "" if _chosen == part else part
	_dress_tiles()
	if not _chosen.is_empty():
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
## its drag: over it by [member lift_points], eased in.
func _aimed(at: Vector2, travel: float) -> Vector2:
	var eased: float = clampf(travel / p(RAMP), 0.0, 1.0)
	return at + Vector2(0.0, -p(lift_points) * eased)


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


func _drop_from_tray(at: Vector2) -> void:
	var builder: Builder = app.get("_builder")
	last_drop = {"aimed": at, "put": [], "from": "tray"}
	if builder == null:
		return
	if _over_ui(at) or (app.get("_store") as ModelStore).laying:
		# Let go over the tray: put back, nothing down.
		counts["cancelled"] += 1
		last_drop["why"] = "over the tray"
		_put_hand_away()
		return
	app.call("_aim_at", at)
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
		(app.get("_bar") as ModelBar).say("no room there")
	_put_hand_away()


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


## The line over the model's foot (PhoneShell.hint_from): what a finger does
## here, not what it does in the full studio ("drag turns the view" was
## wrong in B, walk 1).
func hint() -> String:
	if _tray_dragging or _moving:
		return "Let go to put it down"
	if not _chosen.is_empty():
		return "Tap the model to put one there"
	return "Drag a brick onto the model · two fingers turn the view" if map == "b" \
		else "Drag a brick onto the model · one finger turns the view"


# -- a finger on the model ----------------------------------------------------------


## Whether the camera leaves the one finger down to this layer (CadCamera
## .finger_taken): in B always; in A when it came down on a part.
func finger_taken() -> bool:
	return map == "b" or _brick != 0 or _moving or _tray_dragging


## Whether Main leaves [param event] to this layer and the camera: every
## finger's touch and drag, and the clicks Godot raises from them. A
## mouse's own clicks are the full studio's.
func takes(event: InputEvent) -> bool:
	if not is_visible_in_tree():
		return false
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return true
	return event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION


func _input(event: InputEvent) -> void:
	# A second finger while a brick is carried out of the tray: the view's,
	# and the brick goes back to the tray, as a second finger always puts
	# what the first had back.
	var touch := event as InputEventScreenTouch
	if touch == null:
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
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	if touch != null:
		if touch.pressed:
			_model_press(touch)
		elif touch.index == _finger:
			_model_lift(touch)
		elif _others > 0:
			_others -= 1
		return
	if drag != null and drag.index == _finger and _others == 0:
		_model_drag(drag)


func _model_press(touch: InputEventScreenTouch) -> void:
	if _finger == -1:
		# The first finger down, none other anywhere: on the model, ours.
		if _touches.size() > 1 or bool(app.call("_over_panel_at", touch.position)):
			return
		_finger = touch.index
		_down = touch.position
		_travel = 0.0
		_hinted = false
		_others = 0
		_brick = _brick_near(touch.position)
		return
	# A second finger: the camera's. A part being moved goes back.
	_others += 1
	_brick = 0
	if _moving:
		_moving = false
		var verbs: EditVerbs = app.get("_verbs")
		verbs.put_away()
		var builder: Builder = app.get("_builder")
		builder.clear_selection()
		counts["cancelled"] += 1
		last_drop = {"put": [], "from": "model", "why": "a second finger"}
		_put_hand_away()


func _model_drag(drag: InputEventScreenDrag) -> void:
	_travel = maxf(_travel, drag.position.distance_to(_down))
	if not _moving and _brick != 0 and _travel > p(SLOP):
		var camera: CadCamera = app.get("_camera")
		var verbs: EditVerbs = app.get("_verbs")
		_moving = verbs.drag_start(_brick, false, false, [camera.ray_origin(_down), camera.ray_normal(_down)])
		if not _moving:
			_brick = 0
		else:
			var builder: Builder = app.get("_builder")
			var world: BrickWorld = app.get("_world")
			_moved_from.clear()
			for id: Variant in builder.selection:
				var brick: BrickWorld.Brick = world.get_brick(int(id))
				if brick != null:
					_moved_from[int(id)] = brick.transform
	if _moving:
		_aim(_aimed(drag.position, _travel))
		return
	# B, one finger on empty space: nothing moves; once, how the view turns.
	if map == "b" and _brick == 0 and not _hinted and _travel > p(36.0):
		_hinted = true
		counts["hints"] += 1
		(app.get("_bar") as ModelBar).say("Two fingers turn the view")


func _model_lift(touch: InputEventScreenTouch) -> void:
	_finger = -1
	var was_moving: bool = _moving
	_moving = false
	var others: int = _others
	_others = 0
	_brick = 0
	if others > 0:
		return
	var builder: Builder = app.get("_builder")
	if was_moving:
		var at: Vector2 = _aimed(touch.position, _travel)
		last_drop = {"aimed": at, "put": [], "from": "model"}
		app.call("_drop_dragged", at)
		var world: BrickWorld = app.get("_world")
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
		builder.clear_selection()
		_put_hand_away()
		return
	# A tap with a brick chosen on the tray: one put down where it landed.
	if _travel <= p(SLOP) and not _chosen.is_empty():
		_take(_chosen)
		app.call("_aim_at", touch.position)
		last_drop = {"aimed": touch.position, "put": [], "from": "tap",
			"valid": builder.can_place(), "ghost": builder.ghost_transform()}
		var id: int = builder.place() if builder.can_place() else 0
		if id != 0:
			counts["put"] += 1
			last_drop["put"] = [id]
			_seat([id])
		else:
			counts["refused"] += 1
		builder.hide_preview()


## The part under [param at], or in B the nearest within a fingertip.
func _brick_near(at: Vector2) -> int:
	var verbs: EditVerbs = app.get("_verbs")
	var under: int = verbs.brick_at(at)
	if under != 0 or map != "b":
		return under
	for ring: float in [NEAR * 0.5, NEAR]:
		for turn: int in 8:
			var found: int = verbs.brick_at(at + Vector2.from_angle(TAU * turn / 8.0) * p(ring))
			if found != 0:
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
	_picture_tiles()
	_seat_frame()
	var shell: Shell = app.get("_shell")
	if shell != null and _undo != null:
		_undo.disabled = not shell.can("undo")
		_redo.disabled = not shell.can("redo")
	# Nothing is aimed while no finger is: the ghost a stale pointer left goes.
	var builder: Builder = app.get("_builder")
	if builder != null and not _tray_dragging and not _moving and builder.has_preview() \
			and not builder.is_carrying():
		builder.hide_preview()


# -- words -----------------------------------------------------------------------------


func _part_name(part: String) -> String:
	return str(app.call("_part_said", part)) if app != null and app.has_method("_part_said") else part


func _colour_name(code: int) -> String:
	var library: PartLibrary = app.get("_library") if app != null else null
	return library.color(code).name if library != null else str(code)


## What a check reads: the controls by the names it presses them by.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {"simple_undo": _undo, "simple_redo": _redo, "simple_foot": _foot}
	for tile: Control in _tiles:
		out[tile.name] = tile
	for swatch: Button in _swatches:
		out[swatch.name] = swatch
	return out


## The tile of [param part], for a check to drag from.
func tile_of(part: String) -> Control:
	for tile: Control in _tiles:
		if str(tile.get_meta("part")) == part:
			return tile
	return null


func chosen_colour() -> int:
	return _colour


func chosen_brick() -> String:
	return _chosen
