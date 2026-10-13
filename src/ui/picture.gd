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
## turning mark. Hidden while the picture is taken and shown again after.
## (The selection's outline is drawn over the window, not in the world, so
## a picture never sees it.)
var aside: Array[Node3D] = []
## Called after the picture, to put back whatever else hides bricks.
var shown_again: Callable = func() -> void: pass


## Draw the model and return the picture, or null if there is nothing to
## draw. Takes a few frames.
func take(size: Vector2i = SIZE) -> Image:
	var corners: PackedVector3Array = await _corners()
	if corners.is_empty():
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
	# Perspective or straight-on. Not the view's lens, which is shifted to
	# the middle of the model's column (CadCamera): this picture has a lens
	# of its own, shifted to the middle of what it draws (_frame).
	lens.projection = Camera3D.PROJECTION_ORTHOGONAL \
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL \
		else Camera3D.PROJECTION_PERSPECTIVE
	var environment: Environment = _clear_environment()
	if environment != null:
		lens.environment = environment
	view.add_child(lens)
	_frame(lens, corners, float(size.x) / float(size.y))
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


## How much of the picture's narrower way the model fills: a twentieth
## clear on each side.
const FILL := 0.9


## From the direction the view is looking, framed on what is drawn: every
## corner of every part, as the lens sees it, in the middle of the picture
## and filling it.
##
## This framed the box round the model, from its middle, and what is drawn
## is not the box: in perspective the near half of a model is drawn larger
## than the far half, and a model that is not a box leaves much of its box
## empty. The example car sat 5% low in its own picture and filled 64% of
## it; an L of bricks sat 9% low and 8% to one side and filled 44%
## (centring_probe).
##
## The eye stays where it was, as far back as takes in a ball round the
## model, so the picture is in no stronger perspective than before: put
## close enough to fill the picture with the view's own lens, an L's near
## end loomed over the rest. The lens is then shifted and narrowed to what
## that eye sees, which from one eye is the same picture moved and enlarged,
## so it is exactly in the middle both ways. Straight-on, the lens is slid
## in its plane, which is the same thing.
func _frame(lens: Camera3D, corners: PackedVector3Array, aspect: float) -> void:
	var axes: Basis = camera.global_transform.basis.orthonormalized()
	var across: Vector3 = axes.x
	var up: Vector3 = axes.y
	var ahead: Vector3 = -axes.z
	# The corners in the view's own axes: across, up and ahead.
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for point: Vector3 in corners:
		var at := Vector3(point.dot(across), point.dot(up), point.dot(ahead))
		low = low.min(at)
		high = high.max(at)
	var middle: Vector3 = (low + high) * 0.5
	if lens.projection == Camera3D.PROJECTION_ORTHOGONAL:
		lens.global_transform = Transform3D(axes,
			across * middle.x + up * middle.y + ahead * (low.z - 100.0))
		lens.size = maxf(high.y - low.y, (high.x - low.x) / aspect) / FILL
		lens.far = maxf(camera.far, high.z - low.z + 200.0)
		return

	var radius: float = (high - low).length() * 0.5
	var half_tall: float = deg_to_rad(lens.fov) * 0.5
	var half_wide: float = atan(tan(half_tall) * aspect)
	var back: float = radius / sin(minf(half_tall, half_wide)) * 1.05
	var eye: Vector3 = across * middle.x + up * middle.y + ahead * (middle.z - back)

	# What that eye sees, as the slope of a ray from it: across and up over
	# the distance ahead.
	var seen_low := Vector2(INF, INF)
	var seen_high := Vector2(-INF, -INF)
	var nearest: float = INF
	var farthest: float = 0.0
	for point: Vector3 in corners:
		var from_eye: Vector3 = point - eye
		var deep: float = from_eye.dot(ahead)
		var at := Vector2(from_eye.dot(across), from_eye.dot(up)) / deep
		seen_low = seen_low.min(at)
		seen_high = seen_high.max(at)
		nearest = minf(nearest, deep)
		farthest = maxf(farthest, deep)
	var tall: float = maxf(seen_high.y - seen_low.y, (seen_high.x - seen_low.x) / aspect) / FILL
	lens.global_transform = Transform3D(axes, eye)
	lens.near = clampf(nearest * 0.5, 0.05, camera.near)
	lens.far = maxf(camera.far, farthest * 1.5)
	lens.set_frustum(lens.near * tall, (seen_low + seen_high) * 0.5 * lens.near,
		lens.near, lens.far)


## The corners of every part shown, each part's box turned with the part.
## What is drawn lies inside them and reaches them nearly everywhere. A
## slice of the model a frame (FramePace): Orthanc is 9,429 parts.
func _corners() -> PackedVector3Array:
	var corners := PackedVector3Array()
	var pace := FramePace.new()
	for brick: BrickWorld.Brick in world.bricks():
		if pace.due():
			await pace.next()
		if scenery.has(brick.id) or brick.hidden:
			continue
		var part: Lbm.PartMesh = world.library.mesh_for(brick.part_id)
		if part != null:
			add_corners(corners, brick.transform, part.bounds)
	return corners


## A box's eight corners, placed: what a picture is framed on. ModelShot's
## too.
static func add_corners(into: PackedVector3Array, at: Transform3D, box: AABB) -> void:
	for n: int in 8:
		into.append(at * (box.position + box.size * Vector3(
			float(n & 1), float((n >> 1) & 1), float((n >> 2) & 1))))
