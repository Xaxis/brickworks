## View › Split: the model seen straight on beside the perspective view
## (docs/APP_UX.md, B9). Studio splits its window into up to four viewports
## and LDCad swaps its split views for one large one; a part put on a side
## face, or under an overhang, is easier to aim with a front or a top view
## beside the perspective one.
##
## The second view looks at what the main view looks at, at the same scale,
## from the front out of the box; its header turns it to the top, the side
## or the back. It follows the main view's focus and zoom and never turns
## with it, so a wheel, a turn or a slide over it moves the main view, and
## this one follows.
##
## A click in it places, picks and connects as one in the main view does,
## through its own camera's ray: the main camera hands a point here to
## [method ray_at] ([member CadCamera.beside]), so every ray made from the
## screen (the ghost, a click, a part let go from the bin, the pivot of a
## turn) comes from the view the point is in.
##
## It shares the model's world, so the part in hand, which is in that world,
## is drawn in both. What is drawn over the model is the main view's alone:
## its panels, the view cube and the cut's strip are in the main view's
## column, the selection's line is drawn under this, and a mesh of the main
## view's own (the pivot of a turn) is on [constant MAIN_ONLY], which this
## camera does not draw.
##
## It takes its width from the model's own column, beside it, and none from
## the bin or the right-hand column. A window with less than [constant LEAST]
## a view (a phone, a narrow tablet) keeps one view: View › Split is greyed
## with why, and the split comes back when the window is wide enough again.
## Off out of the box, and kept on this device (ShellPrefs "split",
## "split_side").
##
## It draws only when the main view draws (IdleDraw): its camera is set only
## when what it shows has changed, and nothing of it is drawn while it is off.
class_name SplitView
extends Control

## The sides it looks from, in the header's order, and their words.
const SIDES: Array[String] = ["front", "top", "side", "back"]
const SIDE_WORDS: Dictionary = {"front": "Front", "top": "Top", "side": "Side", "back": "Back"}
## Each side's way from what is looked at to the eye, and which way is up on
## the screen. The front is CadCamera's (+z); the side is the right side; the
## top has the front at its foot.
const FROM: Dictionary = {
	"front": [Vector3(0, 0, 1), Vector3.UP],
	"top": [Vector3(0, 1, 0), Vector3(0, 0, -1)],
	"side": [Vector3(1, 0, 0), Vector3.UP],
	"back": [Vector3(0, 0, -1), Vector3.UP],
}
## The render layer of what is drawn in the main view only. Layer 20 is the
## floor's shadow (FloorLayer) and a render's warm light's (StudioRender).
const MAIN_ONLY := 1 << 18
## The least width of each view, in the window's units: two of them is the
## model's column at the least for a split.
const LEAST := 320.0
## How often the model's size is asked again while it changes, ms: it is
## every part's box, and a model being opened changes every frame.
const REACH_EVERY_MS := 500

## The main view's camera, which this follows.
var camera: CadCamera
## The main view's column, whose room this shares.
var beside_of: Control
## The model's box (Main._built_bounds), for how far back this stands.
var bounds: Callable = Callable()
## What says the model changed: [generation, parts] (BrickWorld).
var world: BrickWorld

## The side looked from, one of [constant SIDES].
var side: String = "front"

## Shown or put away, by the command or by the window's width.
signal shown_changed

var _view: SubViewport
var _eye: Camera3D
var _picture: TextureRect
var _header: HBoxContainer
var _sides: Dictionary = {}
## What the camera was last put at, so a view at rest sets nothing.
var _posed: Array = []
## How far from the focus the camera stands, and what it was worked out for.
var _reach: float = 1500.0
var _reach_for: Array = []
var _reach_at: int = -REACH_EVERY_MS


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	visible = false
	var kept: String = str(ShellPrefs.value("split_side"))
	side = kept if kept in SIDES else "front"

	_view = SubViewport.new()
	_view.name = "SecondView"
	_view.world_3d = get_viewport().find_world_3d()
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.gui_disable_input = true
	_view.size = Vector2i(2, 2)
	add_child(_view)
	_eye = Camera3D.new()
	_eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	_eye.cull_mask = 0xFFFFF & ~MAIN_ONLY
	_eye.current = true
	_view.add_child(_eye)

	_picture = TextureRect.new()
	_picture.texture = _view.get_texture()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_picture)

	# A line between the two views.
	var edge := ColorRect.new()
	edge.color = Look.EDGE
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_right = 1.0
	add_child(edge)

	# Its header: which side it looks from, and back to one view.
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 2)
	_header.position = Vector2(10.0, 10.0)
	add_child(_header)
	var group := ButtonGroup.new()
	for which: String in SIDES:
		var button := Button.new()
		button.text = str(SIDE_WORDS[which])
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Look at the model from the %s, square on" % (
			"right side" if which == "side" else which)
		button.button_pressed = which == side
		button.pressed.connect(show_side.bind(which))
		_header.add_child(button)
		_sides[which] = button
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	Keymap.tell(close, "Back to one view ({split_view})")
	close.pressed.connect(set_on.bind(false))
	_header.add_child(close)
	_sides["close"] = close


## Whether the person wants the split, on this device.
static func wanted() -> bool:
	return bool(ShellPrefs.value("split"))


## Whether the model's column has room for two views.
func fits() -> bool:
	return room() >= LEAST * 2.0


## The model's column, shown as one view or two: the row's width less the
## columns beside it. Not the main view's width and this one's: as this
## shows or goes, the row lays them out a frame later, and the main view
## halved while this was still nothing wide read as no room, and put it
## away again.
func room() -> float:
	var row: Control = get_parent() as Control
	if row == null or beside_of == null:
		return 0.0
	var taken: float = 0.0
	for child: Node in row.get_children():
		var column: Control = child as Control
		if column != null and column.visible and column != self and column != beside_of:
			taken += column.size.x
	return row.size.x - taken


func is_showing() -> bool:
	return visible


## Turn the split on or off, and keep that on this device.
func set_on(on: bool) -> void:
	ShellPrefs.put("split", on)
	fit()


## Show the split if it is wanted and has room, else put it away: after the
## command, and whenever the model's column changes width.
func fit() -> void:
	var show: bool = wanted() and fits()
	if show == visible:
		return
	visible = show
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if show \
		else SubViewport.UPDATE_DISABLED
	_posed = []
	if show:
		_follow.call_deferred()
	shown_changed.emit()


## Look from [param which], one of [constant SIDES], and keep it.
func show_side(which: String) -> void:
	if not which in SIDES:
		return
	side = which
	ShellPrefs.put("split_side", which)
	var button: Button = _sides[which]
	if not button.button_pressed:
		button.set_pressed_no_signal(true)
	_posed = []
	_follow()


func _process(_delta: float) -> void:
	if visible:
		_follow()


## Put the camera where the main view looks, from this side, at its scale,
## if that is not where it is already.
func _follow() -> void:
	if camera == null or not is_inside_tree() or not visible:
		return
	var rect: Rect2 = _picture.get_global_rect()
	var root: Viewport = get_viewport()
	var scale: Vector2 = root.get_final_transform().get_scale()
	var pixels := Vector2i(maxi(2, roundi(rect.size.x * scale.x)),
		maxi(2, roundi(rect.size.y * scale.y)))
	# The main view's world units to a unit of the window at its focus: the
	# frustum spans the window's height (CadCamera._ldu_per_pixel).
	var tall: float = maxf(root.get_visible_rect().size.y, 1.0)
	var across: float = camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL \
		else 2.0 * camera.distance * tan(deg_to_rad(camera.fov) * 0.5)
	var shown: float = maxf(across / tall * rect.size.y, 1.0)
	var reach: float = _reach_now()
	var pose: Array = [camera.focus, shown, side, pixels, reach]
	if pose == _posed:
		_same_as_main(root)
		return
	_posed = pose
	if _view.size != pixels:
		_view.size = pixels
	var way: Array = FROM[side]
	_eye.size = shown
	_eye.near = 1.0
	_eye.far = reach * 2.0 + 2000.0
	_eye.look_at_from_position(camera.focus + (way[0] as Vector3) * reach, camera.focus,
		way[1] as Vector3)
	_same_as_main(root)


## Smoothed as the main view is, and as finely drawn: FrameBudget cuts the
## window's and this follows.
func _same_as_main(root: Viewport) -> void:
	if _view.msaa_3d != root.msaa_3d:
		_view.msaa_3d = root.msaa_3d
	if _view.screen_space_aa != root.screen_space_aa:
		_view.screen_space_aa = root.screen_space_aa
	if _view.scaling_3d_scale != root.scaling_3d_scale:
		_view.scaling_3d_mode = root.scaling_3d_mode
		_view.scaling_3d_scale = root.scaling_3d_scale


## How far from the focus the camera stands: outside the whole model,
## however close the main view is, or the front of it is cut off.
func _reach_now() -> float:
	if not bounds.is_valid():
		return _reach
	var key: Array = [world.generation(), world.brick_count()] if world != null else []
	var now: int = Time.get_ticks_msec()
	if key == _reach_for or now - _reach_at < REACH_EVERY_MS:
		return _reach
	_reach_for = key
	_reach_at = now
	var box: AABB = bounds.call()
	var far: float = 0.0
	for n: int in 8:
		var corner: Vector3 = box.position + Vector3(box.size.x if n & 1 else 0.0,
			box.size.y if n & 2 else 0.0, box.size.z if n & 4 else 0.0)
		far = maxf(far, corner.distance_to(camera.focus))
	_reach = clampf(far + 400.0, 800.0, 15000.0)
	return _reach


## The ray through a point of the window, [origin, direction], when the
## point is in this view; null when it is not, or the split is off. In the
## window's units, as an event's position is.
func ray_at(at: Vector2) -> Variant:
	if not visible or _posed.is_empty():
		return null
	var rect: Rect2 = _picture.get_global_rect()
	if not rect.has_point(at):
		return null
	var share: Vector2 = (at - rect.position) / rect.size
	var clip := Vector4(share.x * 2.0 - 1.0, 1.0 - share.y * 2.0, -1.0, 1.0)
	var back: Vector4 = _eye.get_camera_projection().inverse() * clip
	var eye: Transform3D = _eye.get_camera_transform()
	return [eye * (Vector3(back.x, back.y, back.z) / back.w), -eye.basis.z.normalized()]


## Where a point of the model is drawn in this view, in the window's units;
## (-1, -1) when the split is off.
func on_screen(point: Vector3) -> Vector2:
	if not visible or _posed.is_empty():
		return Vector2(-1.0, -1.0)
	var rect: Rect2 = _picture.get_global_rect()
	return rect.position + _eye.unproject_position(point) * rect.size / Vector2(_view.size)


## The view's picture, in the window's units.
func picture_rect() -> Rect2:
	return _picture.get_global_rect()


## Whether a point is on the header's buttons, which are over the view.
func header_has(at: Vector2) -> bool:
	return visible and _header.get_global_rect().has_point(at)


## The header's buttons by name ("front", "top", "side", "back", "close").
func buttons() -> Dictionary:
	return _sides


## The picture this view drew last, for a probe to read.
func picture() -> Image:
	return _view.get_texture().get_image()
