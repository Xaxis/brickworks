## View › Split: the model seen straight on beside the perspective view
## (docs/APP_UX.md, B9). Studio splits its window into up to four viewports
## and LDCad swaps its split views for one large one; a part put on a side
## face, or under an overhang, is easier to aim with a front or a top view
## beside the perspective one.
##
## The second view looks at what the main view looks at, at the same scale,
## from the front out of the box; its header turns it to the top, the side
## or the back, and Fit frames the model in it. It never turns. Until it is
## zoomed or slid it follows the main view's focus and zoom; a wheel over it
## zooms it, and a drag that would turn or slide the main view slides it
## (a right drag does nothing, since a view square on cannot turn), and
## from then on its zoom and where it looks are its own, kept on this device
## ("split_zoom", "split_pan": how far from the main view's focus, so a model
## opened or framed (CadCamera.framed) brings it along).
##
## A click, a box, a handle or a Connect point in it acts as one in the main
## view does, through its own camera: the main camera asks [method
## has_point] which view a point is over (CadCamera.view_at), and takes its
## rays ([method ray_through]) and where a point is drawn ([method on_screen])
## from here, so every ray made from the screen (the ghost, a click, a part
## let go from the bin, the pivot of a turn) comes from the view the point is
## in. A drag begun in it stays its own wherever the pointer goes.
##
## It shares the model's world, so the part in hand, which is in that world,
## is drawn in both, and the handles and Connect's points are drawn over both
## (ViewOverlays). The rest drawn over the model is the main view's alone:
## its panels, the view cube and the cut's strip are in the main view's
## column, the selection's line is drawn under this, and a mesh of the main
## view's own (the pivot of a turn) is on [constant MAIN_ONLY], which this
## camera does not draw.
##
## It takes its width from the model's own column, beside it, and none from
## the bin or the right-hand column. A window with less than [constant LEAST]
## points a view, a phone, or a tablet held upright keeps one view: View ›
## Split is greyed with why, and the split comes back when there is room.
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
## The least width of each view, in points (Room): two of them is the
## model's column at the least for a split.
const LEAST := 320.0
## How often the model's size is asked again while it changes, ms: it is
## every part's box, and a model being opened changes every frame.
const REACH_EVERY_MS := 500
## Its own zoom, across its height in LDU, at the closest and the farthest.
const NEAREST := 20.0
const FARTHEST := 40000.0
## How long after a zoom or a slide its own view is written down, ms: a
## pinch is a stream of zooms.
const KEEP_AFTER_MS := 400

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
## Its own zoom (0 while it follows the main view's), how far what it looks
## at is from [member _anchor], and the main view's focus when it was last
## framed (or when this took a view of its own).
var _own_size: float = 0.0
var _offset := Vector3.ZERO
var _anchor := Vector3.ZERO
var _anchored: bool = false
var _keep_at: int = 0
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
	_own_size = clampf(float(ShellPrefs.value("split_zoom")), 0.0, FARTHEST)
	if _own_size < NEAREST:
		_own_size = 0.0
	var pan: Variant = ShellPrefs.value("split_pan")
	if pan is Array and (pan as Array).size() == 3:
		_offset = Vector3(float(pan[0]), float(pan[1]), float(pan[2]))
	if camera != null:
		camera.framed.connect(_on_framed)

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
	var fit_button := Button.new()
	fit_button.text = "Fit"
	fit_button.focus_mode = Control.FOCUS_NONE
	fit_button.tooltip_text = "Frame the whole model in this view"
	fit_button.pressed.connect(frame_model)
	_header.add_child(fit_button)
	_sides["fit"] = fit_button
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
	return room() >= least()


## The model's column a split needs, in the window's units: [constant LEAST]
## points a view, counted in points because a phone at three pixels to the
## point lays some 900 units across its 390 points, and had room for two in
## units (fit_check, 2026-10-30). None is enough on a phone (a short side
## under Phone.NARROW points) or a tablet held upright.
func least() -> float:
	var across: float = Room.across()
	var down: float = Room.down()
	if minf(across, down) < Phone.NARROW or (Phone.on() and across < down):
		return INF
	return LEAST * 2.0 * get_viewport().get_visible_rect().size.x / maxf(across, 1.0)


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
	if _keep_at > 0 and Time.get_ticks_msec() >= _keep_at:
		_keep_at = 0
		ShellPrefs.put("split_zoom", _own_size)
		ShellPrefs.put("split_pan", [_offset.x, _offset.y, _offset.z])


## Put the camera where it looks, from this side, at its scale, if that is
## not where it is already: the main view's focus and zoom, or its own.
func _follow() -> void:
	if camera == null or not is_inside_tree() or not visible:
		return
	var rect: Rect2 = _picture.get_global_rect()
	var root: Viewport = get_viewport()
	var scale: Vector2 = root.get_final_transform().get_scale()
	var pixels := Vector2i(maxi(2, roundi(rect.size.x * scale.x)),
		maxi(2, roundi(rect.size.y * scale.y)))
	var middle: Vector3 = looked_at()
	var shown: float = shown_size()
	var reach: float = _reach_now(middle)
	var pose: Array = [middle, shown, side, pixels, reach]
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
	_eye.look_at_from_position(middle + (way[0] as Vector3) * reach, middle, way[1] as Vector3)
	_same_as_main(root)


## Whether this has a zoom and a place of its own, or follows the main view.
func is_own() -> bool:
	return _own_size > 0.0


## What it looks at: the main view's focus, or its own.
func looked_at() -> Vector3:
	if not is_own():
		return camera.focus
	if not _anchored:
		_anchored = true
		_anchor = camera.focus
	return _anchor + _offset


## How much of the model its height shows, LDU: the main view's scale, or
## its own.
func shown_size() -> float:
	if is_own():
		return _own_size
	# The main view's world units to a unit of the window at its focus: the
	# frustum spans the window's height (CadCamera._ldu_per_pixel).
	var tall: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var across: float = camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL \
		else 2.0 * camera.distance * tan(deg_to_rad(camera.fov) * 0.5)
	return maxf(across / tall * _picture.get_global_rect().size.y, 1.0)


## A view of its own from here on, starting from what it shows now.
func _take_own() -> void:
	if is_own():
		return
	var middle: Vector3 = camera.focus
	_own_size = clampf(shown_size(), NEAREST, FARTHEST)
	_anchor = middle
	_anchored = true
	_offset = Vector3.ZERO


## The main view framed (a model opened, Fit, the usual view): its own view
## comes along, as far from the new focus as it was from the old.
func _on_framed(focus: Vector3) -> void:
	_anchor = focus
	_anchored = true
	_posed = []


## Zoom by [param factor] (under 1 is closer), keeping the point under
## [param at] where it is.
func zoom_by(factor: float, at: Vector2 = Vector2.INF) -> void:
	_take_own()
	var middle: Vector3 = looked_at()
	var was: float = _own_size
	_own_size = clampf(_own_size * factor, NEAREST, FARTHEST)
	var actual: float = _own_size / was
	if at.x != INF and not _posed.is_empty():
		var aim: Vector3 = _on_plane(at, middle)
		middle = aim + (middle - aim) * actual
	_offset = middle - _anchor
	_moved()


## Slide by a movement of the pointer in the window's units: what is under
## it moves with it.
func slide_by(by: Vector2) -> void:
	_take_own()
	var per: float = _own_size / maxf(_picture.get_global_rect().size.y, 1.0)
	var basis: Basis = _eye.global_transform.basis
	_offset += (-basis.x * by.x + basis.y * by.y) * per
	_moved()


## Look at [param point] from where it is, at the same zoom.
func centre_on(point: Vector3) -> void:
	_take_own()
	var basis: Basis = _eye.global_transform.basis
	var middle: Vector3 = looked_at()
	# Square on: only across the view, never nearer or farther.
	var way: Vector3 = point - middle
	_offset += way - basis.z * way.dot(basis.z)
	_moved()


## Frame the whole model in it: the header's Fit.
func frame_model() -> void:
	if camera == null or not bounds.is_valid():
		return
	var box: AABB = bounds.call()
	if box.size.length_squared() <= 0.0:
		return
	_take_own()
	var way: Array = FROM[side]
	var right: Vector3 = (way[1] as Vector3).cross(way[0] as Vector3).normalized()
	var up: Vector3 = way[1]
	var wide: float = 0.0
	var tall: float = 0.0
	for n: int in 8:
		var corner: Vector3 = box.get_endpoint(n) - box.get_center()
		wide = maxf(wide, absf(corner.dot(right)))
		tall = maxf(tall, absf(corner.dot(up)))
	var rect: Rect2 = _picture.get_global_rect()
	var aspect: float = rect.size.x / maxf(rect.size.y, 1.0)
	_own_size = clampf(maxf(tall * 2.0, wide * 2.0 / maxf(aspect, 0.01)) * 1.2, NEAREST, FARTHEST)
	_offset = box.get_center() - _anchor
	_moved()


func _moved() -> void:
	_posed = []
	_follow()
	_keep_at = Time.get_ticks_msec() + KEEP_AFTER_MS


## The point under [param at] on the plane through [param middle], square to
## the eye.
func _on_plane(at: Vector2, middle: Vector3) -> Vector3:
	var ray: Array = ray_through(at)
	var origin: Vector3 = ray[0]
	var normal: Vector3 = ray[1]
	return origin + normal * (middle - origin).dot(normal)


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


## How far from what it looks at the camera stands: outside the whole
## model, however close the view is, or the front of it is cut off.
func _reach_now(middle: Vector3) -> float:
	if not bounds.is_valid():
		return _reach
	var key: Array = [world.generation(), world.brick_count(), middle.snapped(Vector3.ONE * 200.0)] \
		if world != null else []
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
		far = maxf(far, corner.distance_to(middle))
	_reach = clampf(far + 400.0, 800.0, 15000.0)
	return _reach


## Whether a point of the window is over this view's picture, which is
## then this view's: its camera's rays, its box, its handles.
func has_point(at: Vector2) -> bool:
	return visible and not _posed.is_empty() and _picture.get_global_rect().has_point(at)


## The ray through a point of the window in this view, [origin, direction],
## in the window's units, as an event's position is; the line goes on past
## the picture's edges, so a drag begun here keeps its view.
func ray_through(at: Vector2) -> Array:
	var rect: Rect2 = _picture.get_global_rect()
	var share: Vector2 = (at - rect.position) / Vector2(maxf(rect.size.x, 1.0), maxf(rect.size.y, 1.0))
	var clip := Vector4(share.x * 2.0 - 1.0, 1.0 - share.y * 2.0, -1.0, 1.0)
	var back: Vector4 = _eye.get_camera_projection().inverse() * clip
	var placed: Transform3D = _eye.get_camera_transform()
	return [placed * (Vector3(back.x, back.y, back.z) / back.w), -placed.basis.z.normalized()]


## Where a point of the model is drawn in this view, in the window's units;
## (-1, -1) when the split is off.
func on_screen(point: Vector3) -> Vector2:
	if not visible or _posed.is_empty():
		return Vector2(-1.0, -1.0)
	var rect: Rect2 = _picture.get_global_rect()
	return rect.position + _eye.unproject_position(point) * rect.size / Vector2(_view.size)


## Whether a point of the model is behind this view's camera.
func behind(point: Vector3) -> bool:
	return _eye.is_position_behind(point)


## This view's camera, and a point of the window in its own picture's
## pixels, for what measures on the screen with a Camera3D (Grab.follow).
func eye() -> Camera3D:
	return _eye


func in_picture(at: Vector2) -> Vector2:
	var rect: Rect2 = _picture.get_global_rect()
	return (at - rect.position) * Vector2(_view.size) / Vector2(maxf(rect.size.x, 1.0),
		maxf(rect.size.y, 1.0))


## What it shows now, for what is drawn over it to know when to draw again.
func pose() -> Array:
	return _posed


## The view's picture, in the window's units.
func picture_rect() -> Rect2:
	return _picture.get_global_rect()


## Whether a point is on the header's buttons, which are over the view.
func header_has(at: Vector2) -> bool:
	return visible and _header.get_global_rect().has_point(at)


## The header's buttons by name ("front", "top", "side", "back", "fit",
## "close").
func buttons() -> Dictionary:
	return _sides


## The same, as a page is told of them (Main._page_controls): split_top...
func controls_by_name() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _sides:
		out["split_" + name] = _sides[name]
	return out


## The picture this view drew last, for a probe to read.
func picture() -> Image:
	return _view.get_texture().get_image()
