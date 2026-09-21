## A picture of the model, for the assistant to look at.
##
## [ModelView] draws the model as letters, which was a great deal better
## than nothing and is still what a headless run gets. But a design is
## judged on whether it reads as the thing it is meant to be, and that
## is a question about a picture. Letters answer "is the roof a
## continuous slope"; they do not answer "does this look like a house".
##
## Renders the model that is on screen, from a second camera into an
## offscreen viewport that shares the same 3D world — so it is the same
## bricks under the same lights, not a reconstruction that could
## disagree with what the person is looking at.
class_name ModelShot
extends Node

## Big enough to see a stud, small enough to be a modest part of a
## conversation. A square keeps the cost the same from every angle.
const SIZE := 640

## How many frames to let it draw in before looking. Two would do when
## the window is in front; this is for when it is not.
const FRAMES_TO_DRAW := 6

## And the most to spend waiting, after which there is no picture and
## the caller falls back to the letters. Half a second of a design that
## takes minutes, and only ever spent once.
const MOST_FRAMES := 90

## Where each named view looks from, as a direction the camera sits
## along. The default is a three-quarter view, because an elevation
## flattens exactly the depth that tells you whether a shape works.
const ANGLES: Dictionary = {
	"corner": Vector3(0.72, 0.52, 0.72),
	"front": Vector3(0.0, 0.18, 1.0),
	"back": Vector3(0.0, 0.18, -1.0),
	"left": Vector3(-1.0, 0.18, 0.0),
	"right": Vector3(1.0, 0.18, 0.0),
	"top": Vector3(0.0, 1.0, 0.02),
}

var _viewport: SubViewport
var _camera: Camera3D
var _stage: BrickWorld

## The library the copy is built from. Set by whoever owns this.
var library: PartLibrary


## Whether a picture can be taken at all.
##
## A headless run has nothing to draw with, and asking it to draw gives
## a blank image rather than an error — a picture of nothing, presented
## as a picture of the model.
##
## Asking for a RenderingDevice instead was the obvious test and the
## wrong one: the Compatibility renderer has no RenderingDevice and
## draws perfectly well, and Compatibility is what the web build runs
## on. That check would have turned pictures off for everybody actually
## using this, and left them on here.
static func possible() -> bool:
	return DisplayServer.get_name() != "headless"


func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	# Drawing only while a picture is being taken. Left on, the app
	# renders a second full copy of the model every frame for the rest
	# of the session, for nobody.
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_4X

	# A world of its own, with a copy of the model in it.
	#
	# Sharing the main world and pointing a second camera at it is the
	# obvious way and does not work: the viewport renders once and its
	# texture never changes again, so every angle comes back as the
	# first one — four identical pictures, labelled front, top, left and
	# corner. Nothing errors. The only way to notice is to compare them.
	#
	# The world has to be assigned before entering the tree; it is
	# created on entry, so reading world_3d beforehand gives null.
	var world := World3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.93, 0.94, 0.96)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.88, 0.94)
	environment.ambient_light_energy = 1.3
	world.environment = environment
	_viewport.world_3d = world
	add_child(_viewport)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 1.0
	_camera.far = 60000.0
	_viewport.add_child(_camera)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	key.light_energy = 1.9
	_viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14.0, 132.0, 0.0)
	fill.light_energy = 0.7
	fill.light_color = Color(0.86, 0.9, 1.0)
	_viewport.add_child(fill)

	_stage = BrickWorld.new()
	_stage.library = library
	_viewport.add_child(_stage)


## Put the model on the stage. Rebuilt each time rather than kept in
## step: a copy that is updated by listening to the real one is a second
## source of truth, and the one nobody is looking at is the one that
## drifts.
func _restage(world: BrickWorld, skip: Dictionary) -> AABB:
	_stage.clear()
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id):
			continue
		_stage.add_brick(brick.part_id, brick.color_code, brick.transform)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part == null:
			continue
		var here: AABB = (brick.transform * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	return box


func take(world: BrickWorld, from: String,
		skip: Dictionary = {}) -> Image:
	if not possible() or world == null or world.brick_count() == 0:
		return null

	if _viewport == null:
		if library == null:
			library = world.library
		_build()
		# The viewport, its lights and its batches all want a frame to
		# exist in before anything asks them to draw. Without this the
		# first picture of a session is reliably of nothing.
		for _n: int in 4:
			await get_tree().process_frame

	# Framed on the model, with the workspace left out.
	#
	# The baseplate is a brick like any other and is 32 studs across.
	# Photographing the whole world put it in every picture, filling the
	# frame, and the model the picture was taken of was a few percent of
	# it in one corner — so the assistant was shown, over and over, a
	# large grey square.
	var bounds: AABB = _restage(world, skip)
	if bounds.size.length() <= 0.0:
		return null

	var direction: Vector3 = ANGLES.get(from, ANGLES["corner"]).normalized()
	var centre: Vector3 = bounds.get_center()
	var reach: float = bounds.size.length()
	_camera.position = centre + direction * reach
	# Looking straight down has no usable up vector along Y.
	_camera.look_at(centre,
		Vector3.BACK if absf(direction.y) > 0.95 else Vector3.UP)

	# How much of the view the model actually needs, worked out by
	# projecting its eight corners onto what the camera calls across and
	# up. Guessing from the diagonal was the first attempt and it framed
	# an eight-brick tower so close that the tower was the whole picture
	# and none of its edges were in it.
	var across: Vector3 = _camera.global_transform.basis.x
	var up: Vector3 = _camera.global_transform.basis.y
	var widest: float = 0.0
	for n: int in 8:
		var corner: Vector3 = bounds.position + Vector3(
			bounds.size.x if n & 1 else 0.0,
			bounds.size.y if n & 2 else 0.0,
			bounds.size.z if n & 4 else 0.0) - centre
		widest = maxf(widest, absf(corner.dot(across)))
		widest = maxf(widest, absf(corner.dot(up)))
	# A tenth of margin, so nothing is cropped by a stud.
	_camera.size = maxf(widest * 2.2, 40.0)
	_camera.current = true

	# Drawn over the next few frames rather than awaited once.
	#
	# The documented way is to await frame_post_draw. That works for the
	# first picture and then hangs: the signal only comes when the
	# window actually draws, and a window behind another one, on a
	# machine that throttles what it cannot see, may not draw for a long
	# time. Awaiting it stalls the whole design on something the person
	# cannot know they need to fix. Process frames keep coming whether
	# or not anything is drawn.
	# Drawn over as many frames as it takes, up to a limit.
	#
	# The documented way is to await frame_post_draw. That works for the
	# first picture and then hangs: the signal only comes when the
	# window actually draws, and a window behind another one, on a
	# machine that throttles what it cannot see, may not draw for a long
	# time. Awaiting it stalls the whole design on something the person
	# cannot know they need to fix. Process frames keep coming whether
	# or not anything is drawn.
	#
	# A fixed number of them was the next attempt and it was wrong in
	# the other direction: the very first picture of a session takes
	# about twenty-five frames and every one after it takes six,
	# because the first one is also compiling shaders. Six gave a blank
	# picture once per session — always the first, always silently.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var frames: int = 0
	var taken: Image = null
	while frames < MOST_FRAMES:
		# Re-staged every time round, not once before the loop. The
		# viewport hands back the state it had at the previous staging,
		# so a model staged once and then waited on comes back as
		# whatever was there before it — which, the first time, is
		# nothing.
		_restage(world, skip)
		_camera.current = true
		for _n: int in FRAMES_TO_DRAW:
			await get_tree().process_frame
		frames += FRAMES_TO_DRAW
		var texture: ViewportTexture = _viewport.get_texture()
		if texture == null:
			continue
		var image: Image = texture.get_image()
		# One flat colour is what a viewport that has not drawn yet
		# hands back, and a picture of nothing offered as a picture of
		# the model is worse than none — it is a confident answer about
		# a model nobody looked at.
		if image != null and not _is_blank(image):
			taken = image
			break
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return taken


## Whether every pixel sampled is the same. Sampled, not walked: a
## blank image is blank everywhere, so a hundred points settle it.
static func _is_blank(image: Image) -> bool:
	var first: Color = image.get_pixel(0, 0)
	var step: int = maxi(image.get_width() / 10, 1)
	for x: int in range(0, image.get_width(), step):
		for y: int in range(0, image.get_height(), step):
			if not image.get_pixel(x, y).is_equal_approx(first):
				return false
	return true


## The picture as a content block the model can be handed.
##
## Returns an empty dictionary when there is no picture to give, which
## the caller reads as "fall back to the letters".
func block(world: BrickWorld, from: String,
		skip: Dictionary = {}) -> Dictionary:
	var image: Image = await take(world, from, skip)
	if image == null:
		return {}
	var bytes: PackedByteArray = image.save_png_to_buffer()
	if bytes.is_empty():
		return {}
	return {
		"type": "image",
		"source": {
			"type": "base64",
			"media_type": "image/png",
			"data": Marshalls.raw_to_base64(bytes),
		},
	}
