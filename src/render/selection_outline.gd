## A line round what is selected, as CAD draws a selection.
##
## A selection you cannot see is a trap: the next key press acts on
## whatever you last shift-clicked, which by then may be forty bricks
## ago and off screen. So the outline is not decoration — it is the only
## thing that makes the operations safe to offer.
##
## It was a box round every brick, drawn over everything: a chain of 29
## links selected came out as a yellow scribble over the links' own faces,
## and any big selection the same (seen live, 2026-10-12). Studio, Fusion
## and Onshape draw one clean line round the selection's silhouette, and
## so does this.
##
## How: the selected parts are drawn again, plain white, into a mask of
## their own — a SubViewport the size of the window with a world of its own
## — through the view's own camera, attached to it, so the mask is seen
## through the same lens whatever the lens does. Two passes then find how
## far each pixel is from the mask: along its row (into _rows), then down its
## column (the overlay, over the 3D view and under every panel), which costs
## twice the reach a pixel rather than the reach squared. Outside the mask
## and nearer than the line's width, the line is drawn. Both passes cover
## only the selection's rectangle on screen, so one brick costs a few
## thousand pixels, not the window.
##
## Nothing is put in the model's world, so a picture, a render or the
## booklet, each drawn by a viewport of its own looking at that world,
## never sees it. And nothing is written while nothing changes, so standing
## still nothing is drawn (IdleDraw).
class_name SelectionOutline
extends CanvasLayer

const MASK_SHADER := preload("res://src/render/outline_mask.gdshader")
const ROWS_SHADER := preload("res://src/render/outline_rows.gdshader")
const LINE_SHADER := preload("res://src/render/outline_line.gdshader")

## The yellow the app has always picked parts out in, and the line's width
## in points: the interface's unit, so a 2x screen draws it twice the pixels.
const SELECTED := Color(1.0, 0.86, 0.2)
const SELECTED_WIDTH := 2.5
## The part under the pointer, where the viewer shows it: paler and finer,
## so it never reads as picked.
const HOVER := Color(0.6, 0.85, 1.0, 0.85)
const HOVER_WIDTH := 1.75
## The furthest a line reaches, in pixels: the shaders' loops are this long
## at most.
const MOST_REACH := 12


## A region of a texture drawn where it is, and nothing else: each pass
## covers the selection's rectangle, not the window.
class Region extends Control:
	var texture: Texture2D
	## In the texture's pixels, and how many of them to a unit here.
	var area: Rect2 = Rect2()
	var per_unit: float = 1.0

	func _draw() -> void:
		if texture != null and area.has_area():
			draw_texture_rect_region(texture,
				Rect2(area.position / per_unit, area.size / per_unit), area)


var library: PartLibrary
var world: BrickWorld
var colour: Color = SELECTED
## Points.
var width: float = SELECTED_WIDTH

var _mask: SubViewport
var _rows: SubViewport
var _shapes: Node3D
var _reader: Region
var _overlay: Region
var _paint: ShaderMaterial
var _along: ShaderMaterial
var _line: ShaderMaterial
## The window's size in pixels, its pixels to a point, and the line's reach
## in pixels.
var _pixels: Vector2i = Vector2i.ONE
var _per_point: float = 1.0
var _reach: int = 4
## The camera the mask is seen through, by its instance id.
var _lens: int = 0
## The cut as the mask last drew it.
var _cut: Vector4 = Vector4.ZERO
var _cut_on: bool = false
## Surface mesh -> its MultiMeshInstance3D in the mask.
var _drawn: Dictionary = {}
## Round everything outlined, in the world; and the lens it was last put on
## the screen through.
var _bounds: AABB = AABB()
var _seen_from: Array = []


func _ready() -> void:
	# Over the 3D view, under the HUD (layer 1) and every panel in it.
	layer = 0
	# After the camera has moved this frame, so the rectangle is this
	# frame's.
	process_priority = 1000
	_paint = ShaderMaterial.new()
	_paint.shader = MASK_SHADER

	_rows = SubViewport.new()
	_rows.disable_3d = true
	_rows.transparent_bg = true
	_rows.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_rows)
	# Inside the rows' viewport, so it is drawn before them.
	_mask = SubViewport.new()
	_mask.own_world_3d = true
	_mask.transparent_bg = true
	_mask.positional_shadow_atlas_size = 0
	_mask.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_rows.add_child(_mask)
	_shapes = Node3D.new()
	_mask.add_child(_shapes)

	_along = ShaderMaterial.new()
	_along.shader = ROWS_SHADER
	_reader = Region.new()
	_reader.texture = _mask.get_texture()
	_reader.material = _along
	_rows.add_child(_reader)

	_line = ShaderMaterial.new()
	_line.shader = LINE_SHADER
	_overlay = Region.new()
	_overlay.texture = _rows.get_texture()
	_overlay.material = _line
	add_child(_overlay)
	for region: Region in [_reader, _overlay]:
		region.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		region.mouse_filter = Control.MOUSE_FILTER_IGNORE
		region.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	visible = false
	get_viewport().size_changed.connect(_fit)
	_fit()
	set_process(false)


## Outline these bricks (id -> anything), or nothing for an empty set.
func show_selection(selection: Dictionary) -> void:
	if _mask == null:
		return
	var by_surface: Dictionary = {}
	var bounds := AABB()
	var any: bool = false
	if world != null and library != null:
		for brick_id: int in selection:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick == null or brick.hidden:
				continue
			var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if part == null:
				continue
			for surface: ArrayMesh in part.surfaces:
				var places: Array = by_surface.get(surface, [])
				if places.is_empty():
					by_surface[surface] = places
				places.append(brick.transform)
			var box: AABB = brick.transform * part.bounds
			bounds = bounds.merge(box) if any else box
			any = true
	# Nothing, again: nothing written, so nothing drawn for it.
	if not any and not visible:
		return

	for surface: Variant in _drawn.keys():
		if not by_surface.has(surface):
			(_drawn[surface] as Node).queue_free()
			_drawn.erase(surface)
	for surface: ArrayMesh in by_surface:
		var drawn: MultiMeshInstance3D = _drawn.get(surface)
		if drawn == null:
			drawn = MultiMeshInstance3D.new()
			drawn.multimesh = MultiMesh.new()
			drawn.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			drawn.multimesh.mesh = surface
			drawn.material_override = _paint
			drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_shapes.add_child(drawn)
			_drawn[surface] = drawn
		var places: Array = by_surface[surface]
		# Fresh slots every time, as BrickWorld._fresh_slots says: in a
		# browser, instance data written over in place was never drawn.
		drawn.multimesh.instance_count = 0
		drawn.multimesh.instance_count = places.size()
		for slot: int in places.size():
			drawn.multimesh.set_instance_transform(slot, places[slot])
		# The surfaces carry a box of their own, which a MultiMesh measures
		# from, not where its instances are (BrickWorld._rebuild).
		drawn.custom_aabb = bounds

	_bounds = bounds
	_seen_from = []
	visible = any
	_size_targets()
	var mode: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if any \
		else SubViewport.UPDATE_DISABLED
	_mask.render_target_update_mode = mode
	_rows.render_target_update_mode = mode
	set_process(any)
	if any:
		_process(0.0)


func _process(_delta: float) -> void:
	_look_through()
	_follow_cut()
	_place()


## The mask seen through whatever camera draws the view.
func _look_through() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.get_instance_id() == _lens:
		return
	_lens = camera.get_instance_id()
	RenderingServer.viewport_attach_camera(_mask.get_viewport_rid(), camera.get_camera_rid())


## The cut-away takes off what is past its plane, and the outline goes round
## what is left. Unless the cut leaves ghosts: then what it took is still
## drawn, and outlined. Written only when it changes.
func _follow_cut() -> void:
	if world == null:
		return
	var on: bool = world.is_cut() and not world.cut_leaves_ghosts()
	var plane: Plane = world.cut_plane()
	var at := Vector4(plane.normal.x, plane.normal.y, plane.normal.z, plane.d)
	if on == _cut_on and (not on or at == _cut):
		return
	_cut_on = on
	_cut = at
	_paint.set_shader_parameter("cut_on", on)
	_paint.set_shader_parameter("cut_plane", at)


## Both passes over the selection's rectangle on screen and the line's reach
## round it. Worked out again only when the lens moved.
func _place() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var lens: Array = [camera.get_camera_transform(), camera.get_camera_projection(), _pixels]
	if lens == _seen_from:
		return
	_seen_from = lens
	var window := Rect2(Vector2.ZERO, Vector2(_pixels))
	var area: Rect2 = window
	var behind: bool = false
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for n: int in 8:
		var corner: Vector3 = _bounds.position + _bounds.size * Vector3(
			n & 1, (n >> 1) & 1, (n >> 2) & 1)
		if camera.is_position_behind(corner):
			behind = true
			break
		var at: Vector2 = camera.unproject_position(corner) * _per_point
		lo = lo.min(at)
		hi = hi.max(at)
	if not behind:
		var grown: float = float(_reach + 2)
		area = Rect2(lo.floor() - Vector2(grown, grown),
			(hi.ceil() - lo.floor()) + Vector2(grown, grown) * 2.0).intersection(window)
	# The rows a reach further up and down than the line, which reads them
	# there.
	var rows: Rect2 = area.grow_individual(0, _reach, 0, _reach).intersection(window)
	if rows != _reader.area:
		_reader.area = rows
		_reader.queue_redraw()
	if area != _overlay.area:
		_overlay.area = area
		_overlay.queue_redraw()


## The line its width in the window's pixels, and the mask and the rows the
## window's size.
func _fit() -> void:
	var view: Viewport = get_viewport()
	var pixels: Vector2i = (view as Window).size if view is Window else Vector2i(view.size)
	_pixels = pixels.max(Vector2i.ONE)
	_size_targets()
	_per_point = float(_pixels.x) / maxf(view.get_visible_rect().size.x, 1.0)
	_overlay.per_unit = _per_point
	var line: float = width * maxf(_per_point, 1.0)
	_reach = mini(ceili(line + 1.0), MOST_REACH)
	_along.set_shader_parameter("reach", _reach)
	_line.set_shader_parameter("reach", _reach)
	_line.set_shader_parameter("width", minf(line, float(_reach) - 1.0))
	_line.set_shader_parameter("colour", colour)
	_seen_from = []
	if visible:
		_place()


## The window's size while something is outlined, and next to nothing while
## nothing is: two targets the size of a 2x window are 60 MB of a graphics
## card's memory, a browser's included, for each of the two outlines.
func _size_targets() -> void:
	var wanted: Vector2i = _pixels if visible else Vector2i(2, 2)
	if _mask.size != wanted:
		_mask.size = wanted
		_rows.size = wanted
