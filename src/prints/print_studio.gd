## Printed parts and stickers for the whole model, not only figures: what
## the parts bin's "Print…" and "Sticker…" open, the model's sticker sheet,
## and Edit, Printed versions…, which swaps a part for one of the prints the
## LEGO Group made of it.
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
## Edit, Printed versions…, and the thumbnails it draws them with.
var versions: PrintedVersions
var thumbnails: PartThumbnails
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
	versions = PrintedVersions.new()
	versions.studio = self
	versions.thumbnails = thumbnails
	_cover(versions, 80)
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
	if library.mesh_for(brick.part_id) == null:
		return "#%d's shape is not here yet; ask again in a moment." % brick_id
	# Aimed at that side from just outside it, as a click on it is.
	var face: Stickers.Face = _face_on(brick, side, span)
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


# -- the printed versions LEGO made ---------------------------------------------------


## The plain part a part is a version of: 3068b for 3068bpb0001 and for a
## print made here on it, the part itself for a plain one.
func plain_of(part_id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if info != null and not info.print_of.is_empty():
		return info.print_of
	return PartPrints.base_of(part_id)


## The printed and stickered versions of a part the library has, the
## prints first, the most used first ([method PartLibrary.prints_of]); with
## [param words], those whose name has every one of them ("porsche").
func versions_of(part_id: String, words: String = "") -> Array[PartLibrary.PartInfo]:
	var found: Array[PartLibrary.PartInfo] = library.prints_of(plain_of(part_id))
	var wanted: PackedStringArray = words.to_lower().split(" ", false)
	if wanted.is_empty():
		return found
	return found.filter(func(info: PartLibrary.PartInfo) -> bool:
		var said: String = (info.id + " " + info.name).to_lower()
		return Array(wanted).all(func(word: String) -> bool: return said.contains(word)))


## Edit, Printed versions…: the selection's versions to choose from, or
## why there are none.
func open_versions() -> void:
	var ids: PackedInt64Array = _selected_alike()
	if ids.is_empty():
		said.emit("Select a part to see its printed versions; parts of one kind for several")
		return
	var part: String = world.get_brick(ids[0]).part_id
	if versions_of(part).is_empty():
		said.emit("%s has no printed or stickered versions in the library" % plain_of(part))
		return
	versions.open(plain_of(part), ids, world.get_brick(ids[0]).color_code)


## Whether Printed versions… has something to offer for the selection.
func offers_versions() -> bool:
	var ids: PackedInt64Array = _selected_alike()
	return not ids.is_empty() and not versions_of(world.get_brick(ids[0]).part_id).is_empty()


## The selected parts when they are all versions of one plain part (a row
## of plain 1 x 2 tiles, or one printed and one plain), else none.
func _selected_alike() -> PackedInt64Array:
	var out := PackedInt64Array()
	var plain: String = ""
	for key: Variant in builder.selection.keys():
		var brick: BrickWorld.Brick = world.get_brick(int(key))
		if brick == null or Stickers.sticks(library, brick.part_id):
			continue
		if plain.is_empty():
			plain = plain_of(brick.part_id)
		elif plain_of(brick.part_id) != plain:
			return PackedInt64Array()
		out.append(brick.id)
	return out


## Swap the parts numbered [param ids] for [param version] — a printed or
## stickered version of theirs, or the plain part again — each in its own
## colour where it stands, as one step of undo: Edit, Printed versions…'s
## choice, and print_part's version=. What came of it.
func swap_to(ids: PackedInt64Array, version: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(version)
	if info == null or info.is_redirect():
		return "There is no part %s in the library." % version
	var plains: Dictionary = {}
	var already: int = 0
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			return "There is no part numbered %d." % brick_id
		plains[plain_of(brick.part_id)] = true
		if brick.part_id == version:
			already += 1
	if already == ids.size():
		return "%s %s already." % ["#%d is" % ids[0] if ids.size() == 1 else "They are", version]
	if plains.size() != 1 or (plain_of(version) != plains.keys()[0] and version != plains.keys()[0]):
		return "%s is not a version of %s: its versions are what print_part lists for it." % [
			version, ", ".join(PackedStringArray(plains.keys()))]
	# On the web the version's shape may be fetched first.
	if library.mesh_for(version) == null and library.request_mesh(version, true):
		var until: int = Time.get_ticks_msec() + 30000
		while library.mesh_for(version) == null and Time.get_ticks_msec() < until:
			await get_tree().process_frame
	if library.mesh_for(version) == null:
		return "%s's shape could not be had." % version
	var kept: Dictionary = builder.selection.duplicate()
	builder.selection.clear()
	for brick_id: int in ids:
		builder.selection[brick_id] = true
	var done: Vector2i = builder.replace_selection(version, true)
	var swapped: Array = builder.selection.keys() if done.x > 0 else []
	# The person's own selection is theirs: a session's swap of other parts
	# leaves it as it was, less any part swapped away.
	if not _same_ids(kept.keys(), Array(ids)):
		builder.selection.clear()
		for key: Variant in kept:
			if world.get_brick(int(key)) != null:
				builder.selection[int(key)] = true
		builder.selection_changed.emit(builder.selection.size())
	last_placed = int(swapped[0]) if not swapped.is_empty() else 0
	if done.x == 0:
		return "Nothing swapped: %s has no room where %s stands." % [version,
			"they stand" if ids.size() > 1 else "it stands"]
	return "Swapped %d part%s for %s, %s%s." % [done.x, "" if done.x == 1 else "s", version,
		Inventory._tidy(info.name), "" if done.y == 0 else "; %d had no room for it" % done.y]


static func _same_ids(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for one: Variant in a:
		if not b.has(int(one)):
			return false
	return true


## [param sticker_id], a sticker the library has (one of LDraw's, or one
## made here), stuck on the [param side] of the part numbered [param
## brick_id], its middle on that face's middle, as the sticker in hand put
## down on that face is. What came of it.
func stick_part_on(brick_id: int, side: String, sticker_id: String, colour: int) -> String:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return "There is no part numbered %d." % brick_id
	if not Stickers.sticks(library, sticker_id):
		return "%s is not a sticker: search_parts \"sticker\" finds the library's." % sticker_id
	if library.mesh_for(sticker_id) == null and library.request_mesh(sticker_id, true):
		var until: int = Time.get_ticks_msec() + 30000
		while library.mesh_for(sticker_id) == null and Time.get_ticks_msec() < until:
			await get_tree().process_frame
	if library.mesh_for(sticker_id) == null:
		return "%s's shape could not be had." % sticker_id
	var face: Stickers.Face = _face_on(brick, side, false)
	if face == null or not face.bricks.has(brick.id):
		return "The %s side of #%d has no flat face open for a sticker%s." % [side, brick_id,
			" (#%d is in the way)" % face.bricks[0] if face != null else ""]
	var film: Lbm.PartMesh = library.mesh_for(sticker_id)
	var put: int = builder.put_part(sticker_id, colour, Stickers.laid_on(face, film.bounds))
	last_placed = put
	sheet.refresh()
	if put == 0:
		return "Could not stick %s on." % sticker_id
	var size: Vector3 = film.bounds.size
	var fits: String = "" if size.x <= face.size.x + 0.5 and size.z <= face.size.y + 0.5 \
		else " It is larger than the face (%s by %s LDU on %s by %s): a sticker for another part?" \
			% [_n(size.x), _n(size.z), _n(face.size.x), _n(face.size.y)]
	return "Stuck %s on the %s side of #%d.%s" % [sticker_id, side, brick_id, fits]


static func _n(value: float) -> String:
	return String.num(value, 1).trim_suffix(".0")


## The flat face on the [param side] ("up", "+x", …) of [param brick], as a
## click on it from just outside finds it; with [param span] the faces in
## the same plane beside it too. Null when there is none; another part's
## when that part is in the way.
func _face_on(brick: BrickWorld.Brick, side: String, span: bool) -> Stickers.Face:
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
	if mesh == null or not BrickLattice.FACE_AXIS.has(side):
		return null
	var normal: Vector3 = (BrickLattice.FACE_AXIS[side] as Vector3).normalized()
	var box: AABB = brick.transform * mesh.bounds
	var reach: float = absf(normal.dot(box.size)) * 0.5 + 0.5
	var face: Stickers.Face = Stickers.face_at(world, library, box.get_center() + normal * reach,
		-normal, span, Vector3.FORWARD)
	return face


func controls_by_name() -> Dictionary:
	var named: Dictionary = {}
	if editor != null and editor.visible:
		named.merge(editor.controls_by_name())
	if sheet != null and sheet.visible:
		named.merge(sheet.controls_by_name())
	if versions != null and versions.visible:
		named.merge(versions.controls_by_name())
	if _picking != null and _picking.visible:
		named["sticker_pick"] = _picking
	return named
