## View, Reference picture…: a photo, a plan or a drawing laid in the scene
## to build over, as Studio's Add Reference Image lays one (docs/APP_UX2.md,
## refimage). A PNG or a JPEG (or a WebP, BMP or SVG: PictureFile) on a plane
## on the floor, or standing behind the model as the front view or the side
## view sees it; its width typed in studs or dragged by a corner, its opacity,
## and a lock that leaves the mouse to the model.
##
## - Unlocked, a click on it (the Select tool, nothing in hand, no part in
##   front of it) picks it out: its corners show, a corner dragged sizes it
##   from the corner across, and the picture dragged slides it in its plane.
##   Esc, or a click anywhere else, puts it down.
## - Locked, it is not there for the mouse: a click through it is the
##   model's, and picks the part behind.
## - Kept in the model's file after its first line, on two lines LDraw
##   readers ignore (META, PICTURE_META): where it lies and how it looks, then
##   the picture itself, as a WebP in base64 made once when it is chosen, so
##   a save opened again gives the same picture back. Never in what is
##   published or exported (ModelStore.reference).
## - Never in a picture of the model: Render and the booklet draw worlds of
##   their own, and Export's picture leaves it aside with the ghost
##   (Picture.aside). The parts list counts parts, and it is none.
class_name ReferenceImage
extends Node3D

const META := "0 !BRICKWORKS REFERENCE "
const PICTURE_META := "0 !BRICKWORKS REFERENCE_PICTURE "
## Where it can lie: on the floor, or standing behind the model, square to
## the front view (From the front) or to the side view (From the right).
const PLANES: Array[String] = ["floor", "front", "side"]
const PLANE_WORDS: Dictionary = {"floor": "On the floor",
	"front": "Standing, seen from the front", "side": "Standing, seen from the side"}
## Its longer side as it is kept, px, at most: enough to trace a plan or a
## photo by, and the model's file carries it.
const LONGEST := 2048
const QUALITY := 0.85
## The most of the picture a file may carry, in base64 characters.
const MOST_KEPT := 24 * 1024 * 1024
## How far over the floor it lies, LDU: above a baseplate's top and under
## its studs, which stand through it as through a sheet of paper.
const ABOVE_FLOOR := 0.5
## How far behind the model a standing one stands, LDU.
const BEHIND := 20.0
const STUD := 20.0
## Its least and greatest width, LDU.
const NARROWEST := 20.0
const WIDEST := 40000.0
## Its width when it is first laid, at least, LDU: 16 studs.
const LEAST_FIRST := 320.0
const START_OPACITY := 0.5
## A press that moves no further than this is a click, px.
const DRAG_SLOP := 4.0
## A corner's square across, and how near the pointer takes it, px.
const CORNER := 10.0
const PICK := 9.0
## A corner and the one across from it, as (along, up) from the middle.
const SIGNS: Array[Vector2] = [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]

var store: ModelStore
var camera: CadCamera
var builder: Builder
var verbs: EditVerbs
## The model's box, or the floor's when nothing is built: where it is laid.
var bounds: Callable = func() -> AABB: return AABB()
## Whether a point of the window is over a panel rather than the model.
var over_panel: Callable = func(_at: Vector2) -> bool: return false
## Says a line in the bar along the top.
var say: Callable = func(_line: String) -> void: pass

## Which plane it lies in (PLANES).
var on: String = "floor"
## Its middle, in the world.
var centre := Vector3.ZERO
## Its width, LDU; its height follows the picture's shape.
var width: float = 640.0
var opacity: float = START_OPACITY
## Locked, the mouse goes through it to the model.
var locked: bool = false
## The file it came from, as it was called.
var picture_name: String = ""
## Picked out, its corners showing.
var selected: bool = false

## The picture as kept: a WebP in base64.
var _data: String = ""
## Its height over its width.
var _aspect: float = 1.0
var _mesh: MeshInstance3D
var _quad: QuadMesh
var _material: StandardMaterial3D
var _overlays: ViewOverlays
var _files: PictureFile
## A press on it that has not been let go: {at, view, corner (-1 for the
## picture itself), centre, width, grip, moved}.
var _press: Dictionary = {}
var _dialog: AcceptDialog
var _named: Label
var _plane: OptionButton
var _width: SpinBox
var _fade: HSlider
var _opacity: SpinBox
var _lock: CheckBox
var _filling: bool = false


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# Drawn before any see-through part, which is drawn over it.
	_material.render_priority = -1
	_quad = QuadMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.name = "Picture"
	_mesh.mesh = _quad
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_mesh.visible = false
	add_child(_mesh)
	# Its corners, over the model and under the menus, as the handles'.
	_overlays = ViewOverlays.new()
	_overlays.name = "ReferenceCorners"
	_overlays.camera = camera
	_overlays.draw_in = _draw_corners
	add_child(_overlays)
	_files = PictureFile.new()
	_files.title = "Choose a picture to build over"
	_files.picked.connect(take)
	_files.failed.connect(func(why: String) -> void: say.call(why))
	add_child(_files)
	_make_dialog()
	set_process(false)
	if builder != null:
		builder.selection_changed.connect(func(count: int) -> void:
			if count > 0:
				set_selected(false))
	if store != null:
		store.loaded.connect(func(_name: String, _bricks: int) -> void: from_store())
		store.begun.connect(func(_name: String) -> void: from_store())
		from_store()


func has_picture() -> bool:
	return not _data.is_empty()


## The command: a picture to choose when there is none, else its settings,
## the picture picked out.
func open() -> void:
	if not has_picture():
		_files.ask()
		return
	_fill()
	_dialog.popup()
	_dialog.reset_size()
	# Over the right-hand column, clear of the model's middle.
	var room: Vector2 = get_viewport().get_visible_rect().size
	_dialog.position = Vector2i(maxi(0, int(room.x) - _dialog.size.x - 16),
		mini(72, maxi(0, int(room.y) - _dialog.size.y)))
	if not locked:
		set_selected(true)


## [param image], called [param called], as the picture: kept as it will be
## saved, and shown. The first is laid on the floor under the model, as wide
## as it; one chosen again takes its place and keeps where it was.
func take(image: Image, called: String) -> void:
	if image == null or image.is_empty():
		say.call("could not read that picture")
		return
	var kept: Image = image.duplicate()
	var longest: int = maxi(kept.get_width(), kept.get_height())
	if longest > LONGEST:
		var scale: float = float(LONGEST) / longest
		kept.resize(maxi(1, roundi(kept.get_width() * scale)),
			maxi(1, roundi(kept.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	var bytes: PackedByteArray = kept.save_webp_to_buffer(true, QUALITY)
	var data: String = Marshalls.raw_to_base64(bytes)
	var first: bool = not has_picture()
	if bytes.is_empty() or not _use(data):
		say.call("could not keep %s as a reference picture" % called)
		return
	picture_name = called.get_file().left(120)
	if first:
		on = "floor"
		width = _first_width()
		opacity = START_OPACITY
		locked = false
		centre = _laid_centre()
	_show()
	_kept()
	if builder != null:
		builder.clear_selection()
	open()
	say.call("%s laid to build over: drag a corner to size it, or type its width" % picture_name)


## The picture taken away, from the scene and the model's file.
func remove_picture() -> void:
	var was: String = picture_name
	_clear()
	_kept()
	_dialog.hide()
	say.call("took away the reference picture %s" % was)


## Picked out, its corners shown, or put down. Never while it is locked.
func set_selected(yes: bool) -> void:
	selected = yes and has_picture() and not locked
	if not selected:
		_press = {}
	# Its corners drawn while it is picked out, then put away.
	set_process(true)


## The picture as the model's file keeps it (ModelStore.reference), {} for
## none: where it is put back to the file's coordinates, as the model's
## parts are (ModelStore.lift).
func said() -> Dictionary:
	if not has_picture():
		return {}
	var at: Vector3 = centre - (store.lift() if store != null else Vector3.ZERO)
	return {"on": on, "at": [snappedf(at.x, 0.001), snappedf(at.y, 0.001), snappedf(at.z, 0.001)],
		"width": width, "opacity": snappedf(opacity, 0.001), "locked": locked,
		"name": picture_name, "picture": _data}


## Shown as the model's file says, or taken away when it says none: after a
## model is opened, and when one is begun.
func from_store() -> void:
	set_selected(false)
	var kept: Dictionary = store.reference if store != null else {}
	if kept.is_empty() or not _use(str(kept["picture"])):
		_clear()
		if store != null:
			store.reference = {}
		_dialog.hide()
		return
	var at: Array = kept["at"]
	on = kept["on"]
	centre = Vector3(at[0], at[1], at[2]) + store.lift()
	width = kept["width"]
	opacity = kept["opacity"]
	locked = kept["locked"]
	picture_name = kept["name"]
	_show()
	if _dialog.visible:
		_fill()


## Its four corners in the world, from the top left round.
func corners() -> Array[Vector3]:
	var axes: Basis = _axes()
	var half := Vector2(width, width * _aspect) * 0.5
	var out: Array[Vector3] = []
	for way: Vector2 in SIGNS:
		out.append(centre + axes.x * way.x * half.x + axes.y * way.y * half.y)
	return out


func height() -> float:
	return width * _aspect


## Where the ray from [param at] meets the picture, as a distance along it,
## or -1 when it misses.
func meets(origin: Vector3, direction: Vector3) -> float:
	if not has_picture() or not visible:
		return -1.0
	var axes: Basis = _axes()
	var facing: float = direction.dot(axes.z)
	if absf(facing) < 0.000001:
		return -1.0
	var along: float = (centre - origin).dot(axes.z) / facing
	if along <= 0.0:
		return -1.0
	var off: Vector3 = origin + direction * along - centre
	if absf(off.dot(axes.x)) > width * 0.5 or absf(off.dot(axes.y)) > height() * 0.5:
		return -1.0
	return along


## The settings' fields by name, for a probe to fill as a person does.
func controls_by_name() -> Dictionary:
	return {"reference_plane": _plane, "reference_width": _width,
		"reference_opacity": _opacity, "reference_fade": _fade, "reference_lock": _lock,
		"reference_dialog": _dialog, "reference_files": _files}


# -- the mouse ---------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if not has_picture() or not is_visible_in_tree():
		return
	if not _press.is_empty():
		_while_pressed(event)
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE and selected:
		set_selected(false)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	if over_panel.call(button.position):
		return
	var corner: int = _corner_at(button.position) if selected else -1
	if corner < 0 and not _takes(button):
		set_selected(false)
		return
	get_viewport().set_input_as_handled()
	var view: int = camera.view_at(button.position)
	_press = {"at": button.position, "view": view, "corner": corner, "centre": centre,
		"width": width, "grip": _on_plane(button.position, view), "moved": false}


## Whether a press is the picture's: unlocked, the Select tool with nothing
## in hand, no key held that makes it something else, and no part of the
## model nearer along the ray than the picture.
func _takes(button: InputEventMouseButton) -> bool:
	if locked or verbs == null or verbs.mode != "select" or verbs.shows_ghost() \
			or builder.is_carrying() or button.shift_pressed or button.ctrl_pressed \
			or button.alt_pressed or button.meta_pressed or button.double_click \
			or Input.is_key_pressed(KEY_SPACE):
		return false
	var origin: Vector3 = camera.ray_origin(button.position)
	var direction: Vector3 = camera.ray_normal(button.position)
	var along: float = meets(origin, direction)
	if along < 0.0:
		return false
	var hit: BrickLattice.Hit = builder.lattice.raycast(origin, direction)
	return not hit.is_valid() or store.scenery.has(hit.brick_id) or hit.distance >= along


func _while_pressed(event: InputEvent) -> void:
	var moved: InputEventMouseMotion = event as InputEventMouseMotion
	if moved != null:
		get_viewport().set_input_as_handled()
		if not bool(_press["moved"]) and moved.position.distance_to(_press["at"]) <= DRAG_SLOP:
			return
		_press["moved"] = true
		_drag_to(moved.position)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null:
		return
	get_viewport().set_input_as_handled()
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		# Put back as it was.
		centre = _press["centre"]
		width = _press["width"]
		_press = {}
		_show()
		return
	if button.button_index != MOUSE_BUTTON_LEFT or button.pressed:
		return
	var press: Dictionary = _press
	_press = {}
	if bool(press["moved"]):
		_kept()
		_fill()
		say.call("reference picture %s wide" % _studs_words(width))
		return
	if builder != null:
		builder.clear_selection()
	set_selected(true)
	say.call("the reference picture: drag it to slide it, a corner to size it; "
		+ "View › Reference picture… types its width, or locks it")


## The press dragged to [param at]: a corner sizes it from the one across,
## keeping its shape; the picture itself slides in its plane.
func _drag_to(at: Vector2) -> void:
	var view: int = int(_press["view"])
	var point: Variant = _on_plane(at, view)
	if point == null or _press["grip"] == null:
		return
	var axes: Basis = _axes()
	var corner: int = int(_press["corner"])
	var was: Vector3 = _press["centre"]
	if corner < 0:
		var by: Vector3 = (point as Vector3) - (_press["grip"] as Vector3)
		centre = was + by.round()
		_show()
		return
	var way: Vector2 = SIGNS[corner]
	var half := Vector2(float(_press["width"]), float(_press["width"]) * _aspect) * 0.5
	var across: Vector3 = was - axes.x * way.x * half.x - axes.y * way.y * half.y
	var off: Vector3 = (point as Vector3) - across
	var wide: float = maxf(off.dot(axes.x) * way.x, off.dot(axes.y) * way.y / maxf(_aspect, 0.0001))
	width = clampf(roundf(wide), NARROWEST, WIDEST)
	centre = across + axes.x * way.x * width * 0.5 + axes.y * way.y * height() * 0.5
	_show()
	say.call("%s wide" % _studs_words(width))


## Where the ray through [param at] in [param view] meets the picture's
## plane, or null.
func _on_plane(at: Vector2, view: int) -> Variant:
	var origin: Vector3 = camera.ray_origin(at, view)
	var direction: Vector3 = camera.ray_normal(at, view)
	var normal: Vector3 = _axes().z
	var facing: float = direction.dot(normal)
	if absf(facing) < 0.000001:
		return null
	var along: float = (centre - origin).dot(normal) / facing
	return origin + direction * along if along > 0.0 else null


## The corner under [param at], in whichever view it is in, or -1.
func _corner_at(at: Vector2) -> int:
	var view: int = camera.view_at(at)
	var points: Array[Vector3] = corners()
	for n: int in points.size():
		if not camera.behind(points[n], view) \
				and camera.screen_of(points[n], view).distance_to(at) <= PICK:
			return n
	return -1


func _process(_delta: float) -> void:
	var shown: bool = has_picture() and is_visible_in_tree() and selected
	_overlays.show_drawn(shown)
	if not shown:
		set_process(false)


func _draw_corners(canvas: Control, view: int) -> void:
	var points: Array[Vector2] = []
	for corner: Vector3 in corners():
		if camera.behind(corner, view):
			return
		points.append(camera.screen_of(corner, view))
	for n: int in 4:
		canvas.draw_line(points[n], points[(n + 1) % 4], Look.ACCENT, 2.0, true)
	for point: Vector2 in points:
		var square := Rect2(point - Vector2.ONE * CORNER * 0.5, Vector2.ONE * CORNER)
		canvas.draw_rect(square, Look.FACE)
		canvas.draw_rect(square, Look.ACCENT, false, 2.0)


# -- in the scene ------------------------------------------------------------


## The plane's axes: x along the picture, y up it, z out of its face.
func _axes() -> Basis:
	match on:
		# Its top towards the back, as From above shows the model.
		"floor": return Basis(Vector3.RIGHT, -PI * 0.5)
		# Square to From the right, its left towards the front.
		"side": return Basis(Vector3.UP, PI * 0.5)
	return Basis.IDENTITY


## Shown where it is and as it looks now.
func _show() -> void:
	if not has_picture():
		_mesh.visible = false
		return
	_quad.size = Vector2(width, height())
	_mesh.transform = Transform3D(_axes(), centre)
	_material.albedo_color = Color(1, 1, 1, clampf(opacity, 0.0, 1.0))
	_mesh.visible = true


## [param data] (a picture in base64) as the picture shown. False when it
## does not read as one.
func _use(data: String) -> bool:
	if data.is_empty() or data.length() > MOST_KEPT:
		return false
	var bytes: PackedByteArray = Marshalls.base64_to_raw(data)
	var image: Image = PictureFile.decode(bytes, "webp") if not bytes.is_empty() else null
	if image == null or image.is_empty():
		return false
	_aspect = float(image.get_height()) / maxf(1.0, image.get_width())
	image.generate_mipmaps()
	_material.albedo_texture = ImageTexture.create_from_image(image)
	_data = data
	return true


func _clear() -> void:
	_data = ""
	picture_name = ""
	set_selected(false)
	_material.albedo_texture = null
	_mesh.visible = false


## Told to the model, whose next save and autosave keep it.
func _kept() -> void:
	if store == null:
		return
	store.reference = said()
	store.touch()


## As wide as the model, or the floor under it, in whole studs.
func _first_width() -> float:
	var box: AABB = bounds.call()
	var across: float = maxf(box.size.x, box.size.z)
	return clampf(ceilf(maxf(across, LEAST_FIRST) / STUD) * STUD, NARROWEST, WIDEST)


## Where it is laid in its plane: under the model's middle on the floor,
## or standing on the floor behind the model.
func _laid_centre() -> Vector3:
	var box: AABB = bounds.call()
	var middle: Vector3 = box.get_center()
	match on:
		"front":
			return Vector3(middle.x, height() * 0.5, box.position.z - BEHIND)
		"side":
			return Vector3(box.position.x - BEHIND, height() * 0.5, middle.z)
	return Vector3(middle.x, ABOVE_FLOOR, middle.z)


static func _studs_words(ldu: float) -> String:
	return "%s studs" % String.num(ldu / STUD, 2)


# -- the settings ------------------------------------------------------------


func _make_dialog() -> void:
	_dialog = AcceptDialog.new()
	_dialog.title = "Reference picture"
	_dialog.ok_button_text = "Done"
	# The model stays to hand while it is open: its corners dragged, the
	# view turned.
	_dialog.exclusive = false
	_dialog.add_button("Remove", true, "remove")
	_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"remove":
			remove_picture())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(360, 0)
	_dialog.add_child(column)

	var chosen := HBoxContainer.new()
	chosen.add_theme_constant_override("separation", 8)
	_named = Label.new()
	_named.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_named.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chosen.add_child(_named)
	var another := Button.new()
	another.text = "Choose another…"
	another.pressed.connect(func() -> void: _files.ask())
	chosen.add_child(another)
	column.add_child(chosen)

	_plane = OptionButton.new()
	_plane.accessibility_name = "Lies"
	for plane: String in PLANES:
		_plane.add_item(str(PLANE_WORDS[plane]))
	_plane.item_selected.connect(func(index: int) -> void:
		if _filling:
			return
		on = PLANES[index]
		centre = _laid_centre()
		_changed())
	column.add_child(_line("Lies", _plane, ""))

	# A stud is 20 LDU, so a step of 0.05 is one LDU.
	_width = _spin(NARROWEST / STUD, WIDEST / STUD, 1.0 / STUD, "Width, studs")
	_width.value_changed.connect(func(studs: float) -> void:
		if _filling:
			return
		var bottom: float = centre.y - height() * 0.5
		width = clampf(roundf(studs * STUD), NARROWEST, WIDEST)
		# A standing one stays standing where it stood.
		if on != "floor":
			centre.y = bottom + height() * 0.5
		_changed())
	column.add_child(_line("Width", _width, "studs"))

	_fade = HSlider.new()
	_fade.min_value = 0
	_fade.max_value = 100
	_fade.step = 1
	_fade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fade.custom_minimum_size = Vector2(140, 0)
	_fade.accessibility_name = "Opacity"
	_opacity = _spin(0, 100, 1, "Opacity, percent")
	_opacity.custom_minimum_size = Vector2(80, 0)
	for field: Range in [_fade, _opacity]:
		var other: Range = _opacity if field == _fade else _fade
		field.value_changed.connect(func(percent: float) -> void:
			if _filling:
				return
			_filling = true
			other.value = percent
			_filling = false
			opacity = clampf(percent / 100.0, 0.0, 1.0)
			_changed())
	var fading := HBoxContainer.new()
	fading.add_theme_constant_override("separation", 8)
	fading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fading.add_child(_fade)
	fading.add_child(_opacity)
	column.add_child(_line("Opacity", fading, "%"))

	_lock = CheckBox.new()
	_lock.text = "Locked: clicks go through it to the model"
	_lock.toggled.connect(func(on_now: bool) -> void:
		if _filling:
			return
		locked = on_now
		set_selected(not locked)
		_changed())
	column.add_child(_lock)
	_dialog.visibility_changed.connect(func() -> void:
		if not _dialog.visible:
			set_selected(false))
	add_child(_dialog)


## Shown now, and kept.
func _changed() -> void:
	_show()
	_kept()


## The fields filled from the picture as it is.
func _fill() -> void:
	_filling = true
	_named.text = picture_name
	_named.tooltip_text = picture_name
	_plane.select(maxi(0, PLANES.find(on)))
	_width.value = width / STUD
	_fade.value = roundf(opacity * 100.0)
	_opacity.value = roundf(opacity * 100.0)
	_lock.button_pressed = locked
	_filling = false


func _spin(least: float, most: float, step: float, named: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = least
	spin.max_value = most
	spin.step = step
	spin.update_on_text_changed = true
	spin.select_all_on_focus = true
	spin.custom_minimum_size = Vector2(96, 0)
	spin.accessibility_name = named
	return spin


func _line(words: String, field: Control, after: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = words
	label.custom_minimum_size = Vector2(70, 0)
	line.add_child(label)
	line.add_child(field)
	if not after.is_empty():
		var unit := Label.new()
		unit.text = after
		line.add_child(unit)
	return line


# -- in the file ---------------------------------------------------------------


## The reference picture a model's [param text] keeps, as [method said]
## gives it, or {} when it keeps none or what it keeps is not one. The
## picture is checked when it is shown ([method _use]).
static func read(text: String) -> Dictionary:
	var settings: String = _line_of(text, META)
	var picture: String = _line_of(text, PICTURE_META)
	if settings.is_empty() or picture.is_empty() or picture.length() > MOST_KEPT:
		return {}
	var parsed: Variant = JSON.parse_string(settings)
	if not (parsed is Dictionary):
		return {}
	var kept: Dictionary = parsed
	var plane: String = str(kept.get("on", ""))
	var at: Variant = kept.get("at")
	var wide: Variant = kept.get("width")
	if plane not in PLANES or not (at is Array) or (at as Array).size() != 3 \
			or not (wide is float or wide is int):
		return {}
	var place: Array = []
	for each: Variant in at:
		if not (each is float or each is int) or not is_finite(float(each)) \
				or absf(float(each)) > 1000000.0:
			return {}
		place.append(float(each))
	var faded: Variant = kept.get("opacity", START_OPACITY)
	return {"on": plane, "at": place,
		"width": clampf(float(wide), NARROWEST, WIDEST) if is_finite(float(wide)) else LEAST_FIRST,
		"opacity": clampf(float(faded), 0.0, 1.0) if faded is float or faded is int
			else START_OPACITY,
		"locked": kept.get("locked") is bool and bool(kept["locked"]),
		"name": str(kept.get("name", "")).left(120),
		"picture": picture}


## [param text] with the picture [param kept] ([method said]) on two lines
## after its first, inside the model itself for an .mpd, as SetBin and
## ModelStore.with_share write theirs; as it is for none.
static func written_into(text: String, kept: Dictionary) -> String:
	var picture: String = str(kept.get("picture", ""))
	if picture.is_empty():
		return text
	var settings: Dictionary = kept.duplicate()
	settings.erase("picture")
	var lines: String = META + JSON.stringify(settings) + "\n" + PICTURE_META + picture + "\n"
	var cut: int = text.find("\n")
	if cut < 0:
		return text + "\n" + lines
	return text.substr(0, cut + 1) + lines + text.substr(cut + 1)


## What follows [param meta] on its own line of [param text], or "".
static func _line_of(text: String, meta: String) -> String:
	var begins: int = 0 if text.begins_with(meta) else text.find("\n" + meta)
	if begins < 0:
		return ""
	if text[begins] == "\n":
		begins += 1
	begins += meta.length()
	var ends: int = text.find("\n", begins)
	return text.substr(begins, (ends if ends >= 0 else text.length()) - begins).strip_edges()
