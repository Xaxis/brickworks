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
## column (into _line), which costs twice the reach a pixel rather than the
## reach squared. Outside the mask and nearer than the line's width, the line
## is drawn. Both passes cover only the selection's rectangle on screen, so
## one brick costs a few thousand pixels, not the window. The overlay, over
## the 3D view and under every panel, only lays the finished line on.
##
## Drawn again only when what it shows can have changed: the selection,
## the lens, the cut, the window. All of Orthanc selected, drawn in software,
## made every frame cost the tower several times over — the progress bar's
## frames too, so Mirror's bar took 11.4 s to appear (2026-10-13); a frame
## where only the interface changes now lays the line it already has. And a
## batch of the world's whose every part is selected is drawn into the mask
## from the world's own MultiMesh, not copied a part at a time.
##
## A selection of more than [constant MOST_WHILE_MOVING] triangles is not
## drawn again while the view moves: its line is put away, and drawn once
## the view has come to rest. Drawing it again every frame of a turn was a
## second model's worth of drawing a frame, so a big selection cost what a
## small one does only standing still. Drawn in software (a browser on
## SwiftShader, llvmpipe) no selection is: there the mask and the passes,
## window-sized, cost several times the model's own frame whatever is in
## them.
##
## Nothing is put in the model's world, so a picture, a render or the
## booklet, each drawn by a viewport of its own looking at that world,
## never sees it. And nothing is written while nothing changes, so standing
## still nothing is drawn (IdleDraw).
class_name SelectionOutline
extends CanvasLayer

const MASK_SHADER := preload("res://src/render/outline_mask.gdshader")
const MASK_CUT_SHADER := preload("res://src/render/outline_mask_cut.gdshader")
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
## The most triangles a selection may have and still be drawn again in
## every frame of a turn: a few hundred bricks.
const MOST_WHILE_MOVING := 100000
## Renderers that draw on the processor, by the name they give.
const SOFTWARE := ["swiftshader", "llvmpipe", "softpipe", "lavapipe"]
## Round everything in the mask's world: its instances are the world's own
## MultiMeshes too, whose bounds the world keeps on its own instances.
const EVERYWHERE := AABB(Vector3(-1.0e6, -1.0e6, -1.0e6), Vector3(2.0e6, 2.0e6, 2.0e6))


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
var _line: SubViewport
var _shapes: Node3D
var _reader: Region
var _liner: Region
var _overlay: Region
## The mask's paint, and its paint while a cut is on.
var _paint: ShaderMaterial
var _paint_cut: ShaderMaterial
var _along: ShaderMaterial
var _down: ShaderMaterial
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
## A MultiMesh of the world's, drawn whole -> its instance in the mask; and
## a surface mesh -> the instance drawing the parts of it copied one by one.
var _shared: Dictionary = {}
var _copied: Dictionary = {}
## Round everything outlined, in the world; and the lens it was last put on
## the screen through.
var _bounds: AABB = AABB()
var _seen_from: Array = []
## The selection's triangles, and whether its line waits for the view to
## come to rest because the view moved.
var _triangles: int = 0
var _waiting: bool = false
## The most triangles drawn again while the view moves, here.
var _most_while_moving: int = MOST_WHILE_MOVING


func _ready() -> void:
	# Over the 3D view, under the HUD (layer 1) and every panel in it.
	layer = 0
	var adapter: String = RenderingServer.get_video_adapter_name().to_lower()
	for name: String in SOFTWARE:
		if adapter.contains(name):
			_most_while_moving = 0
	# After the camera has moved this frame, so the rectangle is this
	# frame's.
	process_priority = 1000
	_paint = ShaderMaterial.new()
	_paint.shader = MASK_SHADER
	_paint_cut = ShaderMaterial.new()
	_paint_cut.shader = MASK_CUT_SHADER

	# Each pass inside the viewport of the one that reads it, so it is
	# drawn first: the mask, then the rows, then the line.
	_line = _pass_viewport()
	add_child(_line)
	_rows = _pass_viewport()
	_line.add_child(_rows)
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

	_down = ShaderMaterial.new()
	_down.shader = LINE_SHADER
	_liner = Region.new()
	_liner.texture = _rows.get_texture()
	_liner.material = _down
	_line.add_child(_liner)

	_overlay = Region.new()
	_overlay.texture = _line.get_texture()
	add_child(_overlay)
	for region: Region in [_reader, _liner, _overlay]:
		region.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		region.mouse_filter = Control.MOUSE_FILTER_IGNORE
		region.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	visible = false
	get_viewport().size_changed.connect(_fit)
	_fit()
	set_process(false)


static func _pass_viewport() -> SubViewport:
	var view := SubViewport.new()
	view.disable_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return view


## Outline these bricks (id -> anything), or nothing for an empty set.
func show_selection(selection: Dictionary) -> void:
	if _mask == null:
		return
	var whole: Array = []
	var loose: Dictionary = {}
	var bounds := AABB()
	var any: bool = false
	if world != null and library != null and not selection.is_empty():
		var drawn: Array = world.drawn_as(selection)
		whole = drawn[0]
		loose = drawn[1]
		bounds = drawn[2]
		_triangles = int(drawn[3])
		any = not whole.is_empty() or not loose.is_empty()
	# Nothing, again: nothing written, so nothing drawn for it.
	if not any and not visible:
		return

	var keep: Dictionary = {}
	for multimesh: MultiMesh in whole:
		keep[multimesh] = true
		if not _shared.has(multimesh):
			_shared[multimesh] = _instance(multimesh)
	for multimesh: Variant in _shared.keys():
		if not keep.has(multimesh):
			(_shared[multimesh] as Node).queue_free()
			_shared.erase(multimesh)
	for surface: Variant in _copied.keys():
		if not loose.has(surface):
			(_copied[surface] as Node).queue_free()
			_copied.erase(surface)
	for surface: ArrayMesh in loose:
		var drawn: MultiMeshInstance3D = _copied.get(surface)
		if drawn == null:
			var made := MultiMesh.new()
			made.transform_format = MultiMesh.TRANSFORM_3D
			made.mesh = surface
			drawn = _instance(made)
			_copied[surface] = drawn
		var places: Array = loose[surface]
		# Fresh slots every time, as BrickWorld._fresh_slots says: in a
		# browser, instance data written over in place was never drawn.
		drawn.multimesh.instance_count = 0
		drawn.multimesh.instance_count = places.size()
		for slot: int in places.size():
			drawn.multimesh.set_instance_transform(slot, places[slot])

	_bounds = bounds
	_waiting = false
	_overlay.visible = true
	_seen_from = []
	visible = any
	_size_targets()
	set_process(any)
	if any:
		# Drawn now, whatever its size: the selection changed, not the view.
		_look_through()
		_follow_cut()
		_place()
		_draw_again()
	else:
		for view: SubViewport in [_mask, _rows, _line]:
			view.render_target_update_mode = SubViewport.UPDATE_DISABLED


## Into the mask's world, drawn with the mask's paint and seen from
## anywhere: the world's own MultiMeshes are not bounded by it.
func _instance(multimesh: MultiMesh) -> MultiMeshInstance3D:
	var drawn := MultiMeshInstance3D.new()
	drawn.multimesh = multimesh
	drawn.material_override = _paint_cut if _cut_on else _paint
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drawn.custom_aabb = EVERYWHERE
	_shapes.add_child(drawn)
	return drawn


## The mask, the rows and the line drawn again in the frame being drawn,
## once each.
func _draw_again() -> void:
	for view: SubViewport in [_mask, _rows, _line]:
		view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(_delta: float) -> void:
	var changed: bool = _look_through()
	changed = _follow_cut() or changed
	var moved: bool = _place()
	if moved and _triangles > _most_while_moving:
		# Put away until the view has come to rest.
		if not _waiting:
			_waiting = true
			_overlay.visible = false
		return
	if moved or changed or _waiting:
		_draw_again()
	if _waiting:
		_waiting = false
		_overlay.visible = true


## The mask seen through whatever camera draws the view.
func _look_through() -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.get_instance_id() == _lens:
		return false
	_lens = camera.get_instance_id()
	RenderingServer.viewport_attach_camera(_mask.get_viewport_rid(), camera.get_camera_rid())
	return true


## The cut-away takes off what is past its plane, and the outline goes round
## what is left. Unless the cut leaves ghosts: then what it took is still
## drawn, and outlined. Written only when it changes.
func _follow_cut() -> bool:
	if world == null:
		return false
	var on: bool = world.is_cut() and not world.cut_leaves_ghosts()
	var plane: Plane = world.cut_plane()
	var at := Vector4(plane.normal.x, plane.normal.y, plane.normal.z, plane.d)
	if on == _cut_on and (not on or at == _cut):
		return false
	if on != _cut_on:
		for drawn: Node in _shapes.get_children():
			(drawn as GeometryInstance3D).material_override = _paint_cut if on else _paint
	_cut_on = on
	_cut = at
	_paint_cut.set_shader_parameter("cut_plane", at)
	return true


## The passes over the selection's rectangle on screen and the line's reach
## round it. Worked out again only when the lens moved, which is also when
## the mask must be drawn again.
func _place() -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return false
	var lens: Array = [camera.get_camera_transform(), camera.get_camera_projection(), _pixels]
	if lens == _seen_from:
		return false
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
	for region: Region in [_liner, _overlay]:
		if area != region.area:
			region.area = area
			region.queue_redraw()
	return true


## The line its width in the window's pixels, and the passes the window's
## size.
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
	_down.set_shader_parameter("reach", _reach)
	_down.set_shader_parameter("width", minf(line, float(_reach) - 1.0))
	_down.set_shader_parameter("colour", colour)
	_seen_from = []
	if visible:
		_place()
		_draw_again()


## The window's size while something is outlined, and next to nothing while
## nothing is: three targets the size of a 2x window are 60 MB of a graphics
## card's memory, a browser's included, for each of the two outlines.
##
## Not at once, once they have the window's size: each new size is three new
## render targets, and a browser waits for the card to finish everything
## asked of it before it makes one. Drawing in software that was a second a
## time, and the pointer going from a part onto Brickify's button let go of
## the hover's targets in the frame it pressed, so the bar saying it had
## begun was drawn 1.8 s after the press (progress_check, 2026-10-15). They
## go small once nothing has been outlined for SHRINK_AFTER_MS.
func _size_targets() -> void:
	if visible:
		_resize(_pixels)
		return
	_emptied_at = Time.get_ticks_msec()
	if _mask.size != _pixels or not is_inside_tree():
		_resize(Vector2i(2, 2))
		return
	get_tree().create_timer(SHRINK_AFTER_MS / 1000.0).timeout.connect(
		_shrink_if_still_empty.bind(_emptied_at))


const SHRINK_AFTER_MS := 4000
var _emptied_at: int = 0


func _shrink_if_still_empty(emptied_at: int) -> void:
	if not visible and _emptied_at == emptied_at:
		_resize(Vector2i(2, 2))


func _resize(wanted: Vector2i) -> void:
	if _mask.size != wanted:
		for view: SubViewport in [_mask, _rows, _line]:
			view.size = wanted
