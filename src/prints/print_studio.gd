## Printed parts and stickers for the whole model, not only figures: what
## the parts bin's "Print…" and "Sticker…" open, and the model's sticker
## sheet.
##
## "Print…" opens the print designer on the part in hand (a 2 x 2 tile
## when nothing is) or any part typed into it; the print is saved as a
## part of its own, in the bin under "My prints", and put in hand to place.
## "Sticker…" asks for a face of the model — the next click on it, through
## a pane laid over the view so the click goes to nothing else — finds it
## and, unless Shift is held, the faces in the same plane beside it, opens
## the designer on a sticker that size, and sticks the sticker on. The
## sticker sheet lists the model's stickers, peels them off, moves them,
## and saves the sheet as a PDF or a 300 dpi PNG at true size.
class_name PrintStudio
extends Node

## A print or sticker was made: the bin should show it.
signal made(part_id: String)
signal said(words: String)

var library: PartLibrary
var world: BrickWorld
var builder: Builder
var camera: CadCamera
## Where the panels go.
var overlay: Node

var editor: PrintEditor
var sheet: StickerSheetDialog
var _picking: Control
var _picked: Callable
var _span: bool = true
var _face: Stickers.Face
## The brick a print is being drawn for, to put the print in its place.
var _replacing: int = 0
## The printed part or the sticker last put in the model, for a session to
## be told its number.
var last_placed: int = 0


func setup(on: Node) -> void:
	overlay = on
	editor = PrintEditor.new()
	editor.library = library
	_cover(editor)
	editor.made.connect(_on_made)
	sheet = StickerSheetDialog.new()
	sheet.studio = self
	_cover(sheet, 120)
	_picking = Control.new()
	_picking.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picking.mouse_filter = Control.MOUSE_FILTER_STOP
	_picking.visible = false
	_picking.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_picking.gui_input.connect(_on_pick_input)
	overlay.add_child(_picking)


func _cover(panel: Control, inset: int = 24) -> void:
	overlay.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: Side in [SIDE_LEFT, SIDE_TOP]:
		panel.set_offset(side, inset)
	for side: Side in [SIDE_RIGHT, SIDE_BOTTOM]:
		panel.set_offset(side, -inset)


## Print on a part: the one in hand, or a 2 x 2 tile.
func print_part(part_id: String) -> void:
	# One part picked out in the model is printed where it stands: the
	# printed part takes its place, in its colour, when it is saved.
	_replacing = 0
	if builder.selection.size() == 1:
		var brick: BrickWorld.Brick = world.get_brick(int(builder.selection.keys()[0]))
		if brick != null and not Stickers.is_sticker(library, brick.part_id):
			_replacing = brick.id
			editor.open(brick.part_id, "", brick.color_code)
			return
	var wanted: String = part_id if library.parts.has(part_id) else "3068b"
	if Stickers.is_sticker(library, wanted):
		wanted = "3068b"
	editor.open(wanted, "", 15)


## Ask for a face to put a sticker on: the next click on the model.
func sticker() -> void:
	ask_for_face(func(face: Stickers.Face) -> void:
		_face = face
		editor.open_sticker(face))


## The next click on the model names a face; [param then] is handed it.
## Shift held at the click keeps to the one part clicked.
func ask_for_face(then: Callable) -> void:
	_picked = then
	_picking.visible = true
	said.emit("Click the face to put the sticker on — it runs over the faces beside it in the "
		+ "same plane; Shift for one part only; Escape not to")


## The press and the release are both the pane's: a release let through
## to the view would put down whatever part is in hand.
func _on_pick_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	_picking.accept_event()
	if click.pressed:
		return
	_picking.visible = false
	if click.button_index != MOUSE_BUTTON_LEFT:
		said.emit("No sticker")
		_picked = Callable()
		return
	# Where the click was, in the viewport's coordinates, which the camera's
	# rays are in. Not the viewport's idea of the pointer: that is the
	# system's pointer, which a check that sends clicks does not move.
	face_at_point(click.global_position, not click.shift_pressed)


func _input(event: InputEvent) -> void:
	if _picking != null and _picking.visible and event is InputEventKey \
			and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_picking.visible = false
		_picked = Callable()
		said.emit("No sticker")
		get_viewport().set_input_as_handled()


## The face under a point of the view (the viewport's own coordinates, as a
## control's global position is), handed to whoever asked.
func face_at_point(at: Vector2, span: bool = true) -> Stickers.Face:
	_picking.visible = false
	var face: Stickers.Face = Stickers.face_at(world, library, camera.ray_origin(at),
		camera.ray_normal(at), span, camera.global_transform.basis.y)
	if face == null:
		said.emit("There is no flat face there to put a sticker on")
		return null
	if _picked.is_valid():
		var then: Callable = _picked
		_picked = Callable()
		then.call(face)
	return face


func _on_made(ids: Array, slot: String) -> void:
	if ids.is_empty():
		return
	var id: String = str(ids[0])
	if slot == "sticker" and _face != null:
		var brick: int = Stickers.stick(builder, id, _face)
		last_placed = brick
		said.emit("Stuck %s on %d part%s" % [id, _face.bricks.size(),
			"" if _face.bricks.size() == 1 else "s"] if brick != 0 else "Could not stick %s on" % id)
		_face = null
		sheet.refresh()
	elif _replacing != 0 and _in_place(id):
		said.emit("Printed it where it stands: %s, in the parts bin under My prints too" % id)
	else:
		said.emit("Made %s: it is in the parts bin under %s" % [id,
			library.parts[id].category if library.parts.has(id) else "My prints"])
	made.emit(id)


## The print put where the part it was drawn for stands, in its colour, as
## two steps of undo. False when that part is gone or is not what was
## printed on.
func _in_place(print_id: String) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(_replacing)
	_replacing = 0
	if brick == null or PartPrints.mould_of(library, brick.part_id) != PartPrints.base_of(print_id):
		return false
	var at: Transform3D = brick.transform
	var colour: int = brick.color_code
	builder.take_off(brick.id)
	last_placed = builder.put_part(print_id, colour, at)
	return last_placed != 0


## Stick a sticker that is made already on a face the next click names.
func stick_again(sticker_id: String) -> void:
	ask_for_face(func(face: Stickers.Face) -> void:
		var brick: int = Stickers.stick(builder, sticker_id, face)
		said.emit("Stuck %s on" % sticker_id if brick != 0 else "Could not stick it there")
		sheet.refresh())


## Peel one of a sticker off the model.
func peel(sticker_id: String) -> bool:
	var used: Dictionary = Stickers.in_model(world, library)
	var bricks: PackedInt64Array = used.get(sticker_id, PackedInt64Array())
	if bricks.is_empty():
		return false
	var done: bool = builder.take_off(bricks[bricks.size() - 1])
	sheet.refresh()
	return done


## Peel one off and stick it where the next click says.
func move(sticker_id: String) -> void:
	if peel(sticker_id):
		stick_again(sticker_id)


func open_sheet() -> void:
	sheet.open()


# -- for a session (AppTools' print_part) -----------------------------------------


## [param picture] printed on [param area] of the part numbered
## [param brick_id], where it stands, as Print… on that one part and Save
## print do. What came of it.
func print_on(brick_id: int, picture: Image, area: String, title: String) -> String:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return "There is no part numbered %d." % brick_id
	if Stickers.is_sticker(library, brick.part_id):
		return "#%d is a sticker: a sticker is drawn again, not printed on." % brick_id
	_replacing = brick.id
	editor.open(brick.part_id, "", brick.color_code)
	return await _draw(picture, area, title)


## [param picture] as a sticker on the [param side] ("up", "+x", …) of the
## part numbered [param brick_id] — and with [param span] the faces in the
## same plane beside it — as Sticker… and a click on that face do.
func sticker_on(brick_id: int, side: String, span: bool, picture: Image,
		title: String) -> String:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return "There is no part numbered %d." % brick_id
	if not BrickLattice.FACE_AXIS.has(side):
		return "side is one of %s." % ", ".join(PackedStringArray(BrickLattice.FACE_AXIS.keys()))
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
	if mesh == null:
		return "#%d's shape is not here yet; ask again in a moment." % brick_id
	# Aimed at that side from just outside it, as a click on it is.
	var normal: Vector3 = (BrickLattice.FACE_AXIS[side] as Vector3).normalized()
	var box: AABB = brick.transform * mesh.bounds
	var reach: float = absf(normal.dot(box.size)) * 0.5 + 0.5
	var face: Stickers.Face = Stickers.face_at(world, library, box.get_center() + normal * reach,
		-normal, span, Vector3.FORWARD)
	if face == null or not face.bricks.has(brick.id):
		return "The %s side of #%d has no flat face open for a sticker%s." % [side, brick_id,
			" (#%d is in the way)" % face.bricks[0] if face != null else ""]
	_face = face
	editor.open_sticker(face, title)
	return await _draw(picture, "sticker", title)


func _draw(picture: Image, area: String, title: String) -> String:
	# On the web the part's shape may be fetched first.
	var until: int = Time.get_ticks_msec() + 30000
	while editor.fetching() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	if editor.area_keys().is_empty():
		editor.close()
		_replacing = 0
		_face = null
		return "Nothing can be printed there: it has no face a print can go on."
	var heard: Array = [""]
	var listen := func(words: String) -> void: heard[0] = words
	said.connect(listen)
	var why: String = editor.draw_and_save(picture, area, title)
	said.disconnect(listen)
	if not why.is_empty():
		_replacing = 0
		_face = null
		return "Not done: %s." % why
	return str(heard[0]) + "."


func controls_by_name() -> Dictionary:
	var named: Dictionary = {}
	if editor != null and editor.visible:
		named.merge(editor.controls_by_name())
	if sheet != null and sheet.visible:
		named.merge(sheet.controls_by_name())
	if _picking != null and _picking.visible:
		named["sticker_pick"] = _picking
	return named
