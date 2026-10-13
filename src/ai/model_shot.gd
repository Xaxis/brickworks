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
## Big enough to judge a large model by.
##
## Six hundred and forty was chosen when a model was fifty bricks and
## filled the frame. A set-sized one is a thousand parts in the same
## square, so a nacelle is a few dozen pixels and the critique is being
## asked whether something it cannot see is the right shape. The cost
## of a picture goes up with its area — this roughly doubles it, which
## is a fraction of what the conversation around it costs, and it is
## the only thing in the loop that can see the model at all.
const SIZE := 1024

## How many frames to let it draw in before looking. Two would do when
## the window is in front; this is for when it is not.
const FRAMES_TO_DRAW := 6

## And the most to spend waiting, after which there is no picture and
## the caller falls back to the letters. Half a second of a design that
## takes minutes, and only ever spent once.
const MOST_FRAMES := 90

## The same cap, in seconds, which is the one that matters.
##
## Ninety frames is half a second on a machine with nothing else to do
## and ten minutes on one running four other copies of this engine —
## which is an ordinary afternoon here. The relay gives up at three
## minutes, so a picture that takes longer than that is not a slow
## picture, it is a design left blind: it asked for a side view, got
## nothing back, and said so in its own report. Twenty seconds and then
## the letters, which draw the plan and an elevation and hide nothing.
## A worse picture beats no picture.
##
## A variable so a probe can set it to nothing and watch the fallback.
var give_up_after: float = 20.0

## Time spent waiting for the graphics card — setting up the picture's
## render target, and handing a picture back — summed until whoever times
## frames takes it (Main._watch_own_frames). Reading a
## picture waits for everything queued to be drawn: a few milliseconds on a
## graphics card, and in a browser drawing in software, tens of seconds. A
## frame that waited on drawing has not been doing this app's work.
static var gpu_wait_us: int = 0

## Where each named view looks from, as a direction the camera sits
## along. The default is a three-quarter view, because an elevation
## flattens exactly the depth that tells you whether a shape works.
const ANGLES: Dictionary = {
	"corner": Vector3(0.72, 0.52, 0.72),
	# The opposite three-quarter. Between the two of them every wall is
	# seen: one corner shows two faces and hides the other two, which is
	# how a model was judged good with a blank front.
	"far corner": Vector3(-0.72, 0.52, -0.72),
	"front": Vector3(0.0, 0.18, 1.0),
	"back": Vector3(0.0, 0.18, -1.0),
	"left": Vector3(-1.0, 0.18, 0.0),
	"right": Vector3(1.0, 0.18, 0.0),
	"top": Vector3(0.0, 1.0, 0.02),
	# Straight down too, but the right way up for a picture laid flat: its
	# top edge (z = 0) at the top and x to the right, as it hangs on a wall.
	# "top" shows it turned half round.
	"face": Vector3(0.0, 1.0, -0.02),
}

var _viewport: SubViewport
var _camera: Camera3D
var _ruler: ShotRuler = null
## Whether to write the studs on. Off for the pictures a person looks at
## — the app's own screenshots and the gallery — and on for the ones a
## design is shown, which is the only place a number helps.
var rulers: bool = true
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
	# Neutral, and about half what it was: lit at twice its own colour,
	# light bluish grey came out white on the web, which lights in sRGB,
	# and the design was shown one grey where it had built two. The same
	# correction as the main view's (see main.tscn).
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.87, 0.87, 0.88)
	environment.ambient_light_energy = BrickWorld.light_energy(0.65)
	world.environment = environment
	_viewport.world_3d = world
	add_child(_viewport)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 1.0
	_camera.far = 60000.0
	_viewport.add_child(_camera)

	# Studs written on the picture. A render says what was built and not
	# where it is, so a design that can see the nacelle is too far
	# forward has to guess by how much, in a unit the picture does not
	# carry.
	_ruler = ShotRuler.new()
	_ruler.camera = _camera
	_ruler.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ruler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_ruler)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	key.light_energy = BrickWorld.light_energy(0.95)
	key.light_specular = BrickWorld.light_specular(0.25)
	_viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14.0, 132.0, 0.0)
	fill.light_energy = BrickWorld.light_energy(0.35)
	fill.light_color = Color(0.95, 0.96, 1.0)
	_viewport.add_child(fill)

	_stage = BrickWorld.new()
	_stage.library = library
	# A copy made for pictures has no history worth keeping.
	_stage.keeps_history = false
	_viewport.add_child(_stage)


## Put the model on the stage. Rebuilt each time rather than kept in
## step: a copy that is updated by listening to the real one is a second
## source of truth, and the one nobody is looking at is the one that
## drifts.
## Bricks to pick out, by number. The stage is a copy of the world, so
## recolouring one here changes a picture and not a model.
var highlight: Dictionary = {}
## Dark Pink, which is to say magenta. Opaque — trans-neon green was
## the first choice and renders as a wash you can see the brick behind,
## which is the wrong thing when the question is "which brick" — and far
## enough from the greys, reds and blues a model is actually built in
## that it cannot be mistaken for a colour somebody chose.
const PICKED_OUT := 5


## What was last staged, so a second picture of an unchanged model does not
## stage it again: the world, its revision, what was left out and what was
## picked out. Staging the owner's 4,242-part Falcon Heavy is every brick
## added to a second world and every batch written, and a picture used to
## do it twice — once to aim the camera, once more before reading the
## pixels — and every picture after it again.
var _staged: Array = []
var _staged_bounds := AABB()
## And every corner of every part staged, each part's box turned with it:
## what a picture is framed on (Picture.add_corners).
var _staged_corners := PackedVector3Array()


##
## And a slice a frame (FramePace), drawn when whole: copying four thousand
## bricks was most of a second of a browser's one thread in one go.
func _restage(world: BrickWorld, skip: Dictionary) -> AABB:
	var wanted: Array = [world.get_instance_id(), world.generation(),
		world.revision, skip.size(), skip.hash(), highlight.hash()]
	if wanted == _staged:
		return _staged_bounds
	_staged = wanted
	_stage.clear()
	_stage.hold_drawing()
	var pace := FramePace.new()
	var box := AABB()
	var corners := PackedVector3Array()
	var first: bool = true
	for brick: BrickWorld.Brick in world.bricks():
		if pace.due():
			await pace.next()
			if world.revision != wanted[2]:
				# The model changed while it was being copied: start again.
				_stage.release_drawing()
				_staged = []
				return await _restage(world, skip)
		if skip.has(brick.id):
			continue
		# What just changed, in a colour it cannot be in otherwise.
		#
		# A design is shown the model after an edit and has to find its
		# own change in it, which on four hundred bricks it does by
		# reading the list again rather than by looking. Brick-Composer
		# renders its before-and-after with the new part picked out for
		# the same reason.
		var colour: int = PICKED_OUT if highlight.has(brick.id) \
			else brick.color_code
		_stage.add_brick(brick.part_id, colour, brick.transform)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part == null:
			continue
		var here: AABB = (brick.transform * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
		Picture.add_corners(corners, brick.transform, part.bounds)
	_stage.release_drawing()
	_staged_bounds = box
	_staged_corners = corners
	return box


## ``only`` frames on part of the model rather than all of it.
##
## Everything here framed the whole thing, which was right when a model
## was fifty bricks. On a set-sized one a nacelle is a few dozen pixels
## across and the critique is being asked whether something it cannot
## make out is the right shape. A designer holding a real model turns
## it over and looks closely at one end.
func take(world: BrickWorld, from: String,
		skip: Dictionary = {}, only: AABB = AABB()) -> Image:
	if not possible() or world == null or world.brick_count() == 0:
		return null
	# A picture is a handful of frames of waiting, and how long a frame
	# takes is not this program's business until it is. Measured on this
	# machine: 989 ms a frame with vsync as shipped, 20 ms with it off.
	# So a picture cost six seconds at every model size from one brick
	# to four hundred — the model was never what made it slow — and a
	# design that takes twenty pictures spent two minutes waiting for a
	# compositor to look at a window nobody was looking at. When a
	# picture needed more than one try it went past the relay's three
	# minutes and came back as nothing at all, which is what a real
	# Voyager run spent its last ten minutes reporting: "the renderer
	# keeps timing out", a starship designed by somebody who never saw
	# it. With vsync off for the duration, the same picture takes under
	# a tenth of a second.
	_quicken()
	var image: Image = await _take(world, from, skip, only)
	_settle()
	return image


## Run frames as fast as the machine will, and remember what to put
## back. Only for as long as a picture takes: an interactive window
## spinning at four hundred frames a second is a laptop fan, and the
## person looking at it cannot see the difference.
func _quicken() -> void:
	# The browser decides its own frame rate and a page is never driven
	# from a command line, so there is nothing here to win on the web —
	# and a DisplayServer call the web platform does not implement is an
	# engine error, which this project treats as a failed deploy.
	if OS.has_feature("web"):
		return
	if _held > 0:
		# Already quickened by an outer call. Nesting happens: block()
		# calls take().
		_held += 1
		return
	_was_vsync = DisplayServer.window_get_vsync_mode()
	_was_max_fps = Engine.max_fps
	if _was_vsync != DisplayServer.VSYNC_DISABLED:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_held = 1


func _settle() -> void:
	if OS.has_feature("web"):
		return
	_held = maxi(0, _held - 1)
	if _held > 0:
		return
	if _was_vsync != DisplayServer.VSYNC_DISABLED:
		DisplayServer.window_set_vsync_mode(_was_vsync)
	Engine.max_fps = _was_max_fps


## How many pictures are being taken, and what the display was set to
## before the first of them.
var _held: int = 0
var _was_vsync: int = DisplayServer.VSYNC_ENABLED
var _was_max_fps: int = 0


func _take(world: BrickWorld, from: String,
		skip: Dictionary, only: AABB) -> Image:
	if _viewport == null:
		if library == null:
			library = world.library
		# Counted with the read-back: making the render target asks the
		# graphics card whether it is complete, and in a browser that waits
		# for everything queued (8 ms in software GL on the desktop, a second
		# in a browser drawing in software).
		await GpuFence.finished()
		var setting_up: int = Time.get_ticks_usec()
		_build()
		gpu_wait_us += Time.get_ticks_usec() - setting_up
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
	var bounds: AABB = await _restage(world, skip)
	if bounds.size.length() <= 0.0:
		return null
	# Staged in full either way, so what is around the part being looked
	# at is still in the picture — a close look at a nacelle that had
	# cut the hull out of it would not show whether the two meet.
	if only.size.length() > 0.0:
		bounds = only

	var direction: Vector3 = ANGLES.get(from, ANGLES["corner"]).normalized()
	var centre: Vector3 = bounds.get_center()
	var reach: float = bounds.size.length()
	_camera.position = centre + direction * reach
	# Looking straight down has no usable up vector along Y.
	var up_is: Vector3 = Vector3.BACK if absf(direction.y) > 0.95 else Vector3.UP
	if from == "face":
		up_is = Vector3.FORWARD
	_camera.look_at(centre, up_is)

	# How much of the view the model actually needs, and where in it:
	# every corner of every part, put onto what the camera calls across and
	# up, and the camera slid to the middle of them. Guessing from the
	# diagonal was the first attempt and it framed an eight-brick tower so
	# close that the tower was the whole picture and none of its edges were
	# in it. The corners of the box round the model were the next, framed
	# on the box's middle, and a model that is not a box was drawn to one
	# side of its picture: an L on the corner it does not have. A close
	# look is framed on the box it looks at.
	var across: Vector3 = _camera.global_transform.basis.x
	var up: Vector3 = _camera.global_transform.basis.y
	var corners := PackedVector3Array()
	if only.size.length() > 0.0:
		Picture.add_corners(corners, Transform3D.IDENTITY, only)
	else:
		corners = _staged_corners
		# The ruler is drawn too, along two edges of the box's base.
		if rulers:
			corners = corners + PackedVector3Array([bounds.position,
				bounds.position + Vector3(bounds.size.x, 0.0, 0.0),
				bounds.position + Vector3(0.0, 0.0, bounds.size.z)])
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point: Vector3 in corners:
		var at := Vector2((point - centre).dot(across), (point - centre).dot(up))
		low = low.min(at)
		high = high.max(at)
	var middle: Vector2 = (low + high) * 0.5
	_camera.position += across * middle.x + up * middle.y
	# A tenth of margin, so nothing is cropped by a stud.
	_camera.size = maxf(maxf(high.x - low.x, high.y - low.y) * 1.1, 40.0)
	_camera.current = true

	if _ruler != null:
		_ruler.visible = rulers
		_ruler.bounds = bounds
		_ruler.queue_redraw()

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
	#
	# Drawn once a try, not every frame of it. Updating always drew the
	# copy six times a picture, and reading the picture back waits for the
	# graphics card to finish everything queued: on the owner's 4,242-part
	# Falcon Heavy in a browser, drawing in software, that read took 45 s.
	var frames: int = 0
	var taken: Image = null
	var until: float = Time.get_unix_time_from_system() + give_up_after
	while frames < MOST_FRAMES and Time.get_unix_time_from_system() < until:
		# Re-staged every time round but the first, which staged it
		# already to work out where to point the camera. The viewport
		# hands back the state it had at the previous staging, so a
		# model staged once and then waited on comes back as whatever
		# was there before it — which, the first time, is nothing.
		# Only if the model changed meanwhile: _restage keeps what it
		# staged, and an unchanged model is already there.
		if frames > 0:
			await _restage(world, skip)
		_camera.current = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		# On the web one frame, in which it is drawn, and then the fence
		# below with the drawing held: every frame more is the whole model
		# drawn again ahead of the read, seconds each in software. A
		# picture drawn blank, the first while shaders compile, is tried
		# again.
		var drawing: int = 1 if OS.has_feature("web") else FRAMES_TO_DRAW
		for _n: int in drawing:
			await get_tree().process_frame
		frames += drawing
		var texture: ViewportTexture = _viewport.get_texture()
		if texture == null:
			continue
		# Read back once the card has drawn it: sooner, the read waits for
		# it on the page's one thread, 27 to 33 s a picture of the Falcon
		# in a browser drawing in software (GpuFence).
		await GpuFence.finished()
		var asked: int = Time.get_ticks_usec()
		var image: Image = texture.get_image()
		gpu_wait_us += Time.get_ticks_usec() - asked
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
		skip: Dictionary = {}, only: AABB = AABB()) -> Dictionary:
	var image: Image = await take(world, from, skip, only)
	if image == null:
		return {}
	return await encode(image)


## A picture already taken, as a content block: how one picture is both
## handed to the model and shown in the panel (the before and after of a
## change to a selection) without drawing it twice.
func encode(image: Image) -> Dictionary:
	# Encoded on a worker where there are workers: a megapixel PNG and its
	# base64 are a few hundred milliseconds of the page's one thread on the
	# web, for every picture a design takes. The image is this call's own.
	var encoded: Array = [PackedByteArray(), ""]
	var work := func() -> void:
		encoded[0] = image.save_png_to_buffer()
		encoded[1] = Marshalls.raw_to_base64(encoded[0])
	if OS.has_feature("nothreads"):
		work.call()
	else:
		var task: int = WorkerThreadPool.add_task(work, false, "encode a picture")
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
	if (encoded[0] as PackedByteArray).is_empty():
		return {}
	return {
		"type": "image",
		"source": {
			"type": "base64",
			"media_type": "image/png",
			"data": encoded[1],
		},
	}
