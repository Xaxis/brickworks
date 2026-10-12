## A picture of the model to keep: large, sharp, on a clear background.
##
## Studio has a renderer for this and Mecabricks a Blender add-on; here
## the only picture of a model was a screenshot with the panels round it,
## or the command line's --shot, which nobody using the app would find.
## So Export offers one: the model alone — no baseplate, no ghost, no
## outline — seen from where the view is looking, framed to fill the
## picture, at several times the screen's size, with nothing behind it so
## it sits on any page.
##
## Drawn by a viewport of its own looking at the same world as the app's,
## with the scene's lights and a copy of its environment that clears to
## nothing instead of drawing the sky.
class_name Picture
extends Node

## The picture's size, in pixels. Three to two, the shape of a print.
const SIZE := Vector2i(2400, 1600)

var world: BrickWorld
var camera: Camera3D
var scenery: Dictionary = {}
## Everything drawn in the world that is not the model: the ghost, the
## selection's outline, the turning mark. Hidden while the picture is
## taken and shown again after.
var aside: Array[Node3D] = []
## Called after the picture, to put back whatever else hides bricks.
var shown_again: Callable = func() -> void: pass


## Draw the model and return the picture, or null if there is nothing to
## draw. Takes a few frames.
func take(size: Vector2i = SIZE) -> Image:
	var bounds: AABB = _model_bounds()
	if bounds.size.length_squared() <= 0.0:
		return null
	var view := SubViewport.new()
	view.size = size
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	view.world_3d = get_viewport().world_3d
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)

	var lens := Camera3D.new()
	lens.fov = camera.fov
	lens.near = camera.near
	lens.far = camera.far
	# Perspective or straight-on, centred: the view's own lens is shifted
	# to the middle of the model's column (CadCamera), and this picture is
	# framed on the model by itself.
	lens.projection = Camera3D.PROJECTION_ORTHOGONAL \
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL \
		else Camera3D.PROJECTION_PERSPECTIVE
	var environment: Environment = _clear_environment()
	if environment != null:
		lens.environment = environment
	view.add_child(lens)
	_frame(lens, bounds, float(size.x) / float(size.y))
	lens.current = true

	# The model alone.
	var keep: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if not scenery.has(brick.id) and not brick.hidden:
			keep[brick.id] = true
	world.show_only(keep)
	var was_visible: Array[bool] = []
	for node: Node3D in aside:
		was_visible.append(node.visible)
		node.visible = false

	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()

	for n: int in aside.size():
		aside[n].visible = was_visible[n]
	world.show_only({})
	shown_again.call()
	view.queue_free()
	return image


## Save it where a person will find it: the browser's downloads, or the
## Downloads folder. Returns a line to tell them.
static func keep(image: Image, file_name: String, into: String = "") -> String:
	var bytes: PackedByteArray = image.save_png_to_buffer()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, file_name, "image/png")
		return "downloaded %s" % file_name
	var folder: String = into if not into.is_empty() \
		else OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if folder.is_empty():
		folder = OS.get_user_data_dir()
	var path: String = folder.path_join(file_name.replace("\\", "/").get_file())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write %s" % file_name
	file.store_buffer(bytes)
	file.close()
	return "wrote %s" % path


## The scene's own environment, clearing to nothing instead of the sky.
## The sky is still what the plastic reflects and what lights it.
func _clear_environment() -> Environment:
	var scene: Environment = get_viewport().world_3d.environment
	if scene == null and camera.environment != null:
		scene = camera.environment
	if scene == null:
		return null
	var copy: Environment = scene.duplicate()
	copy.background_mode = Environment.BG_CLEAR_COLOR
	return copy


## From the direction the view is looking, at the distance that makes the
## model fill the picture.
func _frame(lens: Camera3D, bounds: AABB, aspect: float) -> void:
	var facing: Vector3 = -camera.global_transform.basis.z.normalized()
	var radius: float = bounds.size.length() * 0.5
	var centre: Vector3 = bounds.get_center()
	# The narrower of the two angles decides; a little room round it.
	var half_tall: float = deg_to_rad(lens.fov) * 0.5
	var half_wide: float = atan(tan(half_tall) * aspect)
	var distance: float = radius / sin(minf(half_tall, half_wide)) * 1.05
	var up: Vector3 = camera.global_transform.basis.y.normalized()
	lens.global_transform = Transform3D(Basis.IDENTITY, centre - facing * distance) \
		.looking_at(centre, up)
	if lens.projection == Camera3D.PROJECTION_ORTHOGONAL:
		lens.size = radius * 2.1


func _model_bounds() -> AABB:
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id) or brick.hidden:
			continue
		var part: Lbm.PartMesh = world.library.mesh_for(brick.part_id)
		if part == null:
			continue
		var here: AABB = (brick.transform * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	return box
