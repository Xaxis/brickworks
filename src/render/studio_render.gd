## A photo-real picture of the model, or a turntable of it: File, Render….
##
## BrickLink Studio has Eyesight, a path tracer, and Mecabricks its Workshop
## renders. Godot is not a path tracer, so this gets their look the way a
## photographer would, with a set: the model on a seamless sweep, lit by
## three lights or a real place (an HDR panorama), its contact shadow on
## the floor, through a lens of a chosen focal length. Then three grades:
##
##   Quick  one frame in the window's own light and shading, at the size
##          asked for.
##   Good   on the desktop, global illumination (SDFGI: light bounced off
##          the sweep and the model), ambient occlusion and a key light
##          with a soft, widening shadow; in a browser, which has none of
##          those, eight frames averaged under a soft key.
##   Best   many frames averaged (64 on the desktop, 32 in a browser), each
##          jittered under the pixel, lit from another point of an area
##          light and with shadows cast from another point of the sky, and
##          seen through another point of a lens: smooth edges, soft
##          shadows, real occlusion and real depth of field, on either
##          renderer.
##
## Off screen, in viewports of its own with a copy of the model, so the
## window keeps drawing and answering: a frame of the render is a frame of
## the app, and the work is cut into frames (one sample of one piece of the
## picture each) small enough that a browser tab never stops answering. A
## picture bigger than the renderer can draw at once is drawn in pieces
## and put together.
##
## The averaging is two buffers taking turns (studio_sum), a first frame
## kept to measure the others against (studio_copy), and an 8-bit picture
## made of the two with a step of noise (studio_resolve). They are nested
## so the engine draws them in order, the innermost first: the scene, then
## the copy, then the sums, then the picture.
class_name StudioRender
extends Node

## How far along, 0 to 1, and in words.
signal progress(fraction: float, words: String)
## A piece of the picture is finished, at [param at] in it.
signal piece_done(piece: Image, at: Vector2i)

const SUM := preload("res://src/render/studio_sum.gdshader")
const RESOLVE := preload("res://src/render/studio_resolve.gdshader")
const COPY := preload("res://src/render/studio_copy.gdshader")
const BACKDROP := preload("res://src/render/studio_backdrop.gdshader")
const CONTACT := preload("res://src/render/studio_contact.gdshader")

## Real places to light the model with: Poly Haven's, CC0, recorded in
## docs/ATTRIBUTION.md. Key -> [words, file].
const HDRIS: Dictionary = {
	"softbox": ["Softbox studio", "res://assets/hdri/studio_small_09.hdr"],
	"window": ["Window light", "res://assets/hdri/photo_studio_loft_hall.hdr"],
	"daylight": ["Daylight", "res://assets/hdri/kloofendal_48d_partly_cloudy_puresky.hdr"],
}

## Where the camera looks from: key -> [words, direction from the model].
## Front is +z, as ModelShot has it.
const VIEWS: Dictionary = {
	"hero": ["Three-quarter, like the box", Vector3(-0.52, 0.44, 0.74)],
	"current": ["The view you are looking at", Vector3.ZERO],
	"front": ["Front", Vector3(0.0, 0.18, 1.0)],
	"side": ["Side", Vector3(1.0, 0.18, 0.0)],
	"back": ["Back three-quarter", Vector3(0.6, 0.42, -0.72)],
	"low": ["Low, looking up at it", Vector3(-0.55, 0.1, 0.83)],
	"top": ["From above", Vector3(-0.22, 1.0, 0.32)],
}

## The window's lights (main.tscn) as directions towards each, for
## CadCamera's starting view: [direction, energy under Forward+, casts a
## shadow, specular, colour]. The rig turns with the camera, so a render
## from the starting view is lit exactly as the window is. Used when no
## window lights are handed in; when they are, their own directions are.
const RIG: Array = [
	[Vector3(0.479, 0.659, 0.579), 0.9, true, 0.25, Color(1, 1, 1)],
	[Vector3(-0.647, 0.418, -0.637), 0.2, false, 0.3, Color(0.95, 0.96, 1.0)],
	[Vector3(-0.642, 0.552, 0.532), 0.3, false, 0.3, Color(1, 0.96, 0.9)],
]
## Which way CadCamera's starting view faces, from the model towards the
## eye, as a turn about the vertical: the rig is set for it.
const RIG_HEADING := -0.6108652  # -35 degrees

## The most a browser draws in one frame, in pixels. A bigger picture is
## drawn in pieces.
const MOST_PIXELS_WEB := 1920 * 1088
const MOST_SIDE_DESKTOP := 4096
## How much of the frame the model fills.
const FILL := 0.82
## The key light's size, as an angle across, for Best's area light.
const KEY_SPREAD := 0.12
## Frames for global illumination to gather before the first that counts.
## Twenty-four left it still brightening: Best, whose frames went on after,
## came out a sixth lighter than Good.
const WARM_UP := 64
## Global illumination's strength, and the key's under it. Measured by
## render_probe on Forward+: at 0.25 and the window's key the model came
## out a sixth lighter than Quick and the key's shadow on the floor 0.10
## deep against Quick's 0.17; at 0.15 and 1.4 times the key, lighter by
## a twentieth, as coloured, and 0.15 to 0.18 deep.
const GI_ENERGY := 0.15
const GI_KEY := 1.4
## How much of the ambient light Best moves into lights from the sky that
## cast shadows, which is what puts occlusion under a ledge.
const SKY_SHARE := 0.6

## The model, in the world being rendered, and what of it is its floor's
## baseplate: staged with it, and staged again when the floor changes.
var library: PartLibrary
var scenery: Dictionary = {}
## The window's camera and look, for the view being looked at and the
## window's own light: main's CadCamera, WorldEnvironment's environment
## and its Sun, Fill and Rim.
var eye: Camera3D
var look: Environment
var rig_lights: Array[DirectionalLight3D] = []

var _built: bool = false
var _busy: bool = false
var _cancelled: bool = false
var _floats: bool = true

var _scene: SubViewport
var _base: SubViewport
var _sums: Array[SubViewport] = []
var _out: SubViewport
var _sum_materials: Array[ShaderMaterial] = []
var _resolve_material: ShaderMaterial
var _camera: Camera3D
var _pivot: Node3D
var _stage: BrickWorld
var _backdrop: MeshInstance3D
var _backdrop_material: ShaderMaterial
var _contact: MeshInstance3D
var _contact_material: ShaderMaterial
var _lights: Array[DirectionalLight3D] = []
var _sky_light: DirectionalLight3D
var _floor_view: SubViewport
var _fence: SubViewport
var _floor_camera: Camera3D

var _staged: Array = []
var _bounds := AABB()
## The model's own bounds, without the baseplate it stands on: what a shot
## is aimed at and turns about. _bounds, with the plate, is what the sweep
## and the contact shadow are laid under.
var _framed := AABB()
## HDRI key -> StudioPanorama.
var _panoramas: Dictionary = {}

## The longest a frame took while rendering, and what the render was doing
## in it: a browser check reads it to say where a page stalled.
var worst_frame_ms: float = 0.0
var worst_step: String = ""
var _step: String = ""
var _frame_began_us: int = 0


func _process(_delta: float) -> void:
	if not _busy:
		_frame_began_us = 0
		return
	var now: int = Time.get_ticks_usec()
	if _frame_began_us > 0:
		var took: float = float(now - _frame_began_us) / 1000.0
		if took > worst_frame_ms:
			worst_frame_ms = took
			worst_step = _step
	_frame_began_us = now
	_step = ""


## Say what this frame is doing, for [member worst_step].
func _doing(what: String) -> void:
	_step = what if _step.is_empty() else _step + ", " + what


## What the last render was drawn with: a probe reads it.
var last_exposure: float = 1.0
var last_level: float = 1.0
## Where the model is in the sweep's metering picture.
var _floor_mask: Image
## The staging the contact shadow was drawn for.
var _contact_for: Array = []
var last_shot: Shot
var last_samples: int = 0
var last_tiles: int = 0


## Where the camera is and what it sees.
class Shot extends RefCounted:
	var origin: Vector3
	var basis: Basis
	## Vertical, degrees.
	var fov: float = 30.0
	var near: float = 1.0
	var far: float = 60000.0
	var focus_distance: float = 1000.0
	## The lens's radius, LDU; 0 is a pinhole.
	var aperture: float = 0.0
	## Which way the camera faces the model, from the model, about the vertical.
	var heading: float = 0.0
	## Towards the camera along the floor.
	var toward: Vector3 = Vector3.BACK


## What each grade does here.
class Plan extends RefCounted:
	var samples: int = 1
	var msaa: int = Viewport.MSAA_4X
	var gi: bool = false
	var occlusion: bool = false
	var key_spread: float = 0.0
	var sky_samples: bool = false
	var lens: bool = false
	var soft_key: float = 0.0
	var warm_up: int = 0


## Whether this renderer has global illumination and ambient occlusion:
## Forward+ does, Compatibility (every browser) does not.
static func full_renderer() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


## Whether a picture can be drawn at all: a headless run has nothing to
## draw with and hands back blank pictures (see ModelShot.possible).
static func possible() -> bool:
	return DisplayServer.get_name() != "headless"


static func plan_for(settings: RenderSettings) -> Plan:
	var plan := Plan.new()
	var full: bool = full_renderer()
	match settings.quality:
		RenderSettings.Quality.QUICK:
			plan.occlusion = full
		RenderSettings.Quality.GOOD:
			if full:
				plan.gi = true
				plan.occlusion = true
				plan.soft_key = 2.5
				plan.warm_up = WARM_UP
				# A few frames averaged, the key moved a little across its
				# area: one frame of a soft shadow is a soft shadow made of
				# noise, and at 4K that noise, and the acne of a light
				# skimming a brick's top, showed as hatching on every grey.
				plan.samples = 6
				plan.msaa = Viewport.MSAA_2X
				plan.key_spread = KEY_SPREAD * 0.35
			else:
				# No global illumination or occlusion in a browser: a few
				# frames averaged under a soft key instead, which smooths
				# the edges and softens the shadow the way Good does on the
				# desktop.
				plan.samples = 8
				plan.msaa = Viewport.MSAA_DISABLED
				# Half the area: eight copies of a shadow across the whole
				# of it showed as steps at its edge.
				plan.key_spread = KEY_SPREAD * 0.5
		RenderSettings.Quality.BEST:
			plan.samples = settings.samples_here()
			plan.msaa = Viewport.MSAA_DISABLED
			plan.gi = full
			plan.occlusion = full
			plan.key_spread = KEY_SPREAD
			# The sky's occlusion, from shadows cast from all over it. Not
			# where global illumination already occludes it, which takes
			# no light away for the sky lights to give back, and the model
			# came out a quarter too light.
			plan.sky_samples = not full
			plan.lens = settings.f_stop > 0.0
			plan.warm_up = WARM_UP if full else 0
	return plan


func is_busy() -> bool:
	return _busy


## Stop what is being drawn. It returns nothing, soon.
func cancel() -> void:
	if _busy:
		_cancelled = true


## Draw a picture. Null when there is nothing to draw, nothing to draw it
## with, or it was cancelled.
func render(world: BrickWorld, settings: RenderSettings) -> Image:
	if _busy or not possible() or world == null:
		return null
	_busy = true
	_cancelled = false
	worst_frame_ms = 0.0
	worst_step = ""
	_quicken()
	var image: Image = null
	if await _prepare(world, settings, false):
		image = await _picture(settings, 0.1, 1.0)
	_finish()
	return image


## Draw a turntable: [param each] is called with each frame's number and
## picture as it is finished. Returns how many were drawn, all of them
## unless cancelled.
func turntable(world: BrickWorld, settings: RenderSettings, each: Callable) -> int:
	if _busy or not possible() or world == null:
		return 0
	_busy = true
	_cancelled = false
	worst_frame_ms = 0.0
	worst_step = ""
	_quicken()
	var done: int = 0
	if await _prepare(world, settings, true):
		var frames: int = maxi(settings.frames, 1)
		for n: int in frames:
			_pivot.rotation = Vector3(0.0, TAU * float(n) / float(frames), 0.0)
			var from: float = 0.1 + 0.9 * float(n) / float(frames)
			var image: Image = await _picture(settings, from, from + 0.9 / float(frames),
				"frame %d of %d" % [n + 1, frames])
			if image == null:
				break
			await get_tree().process_frame
			_doing("keeping frame %d" % (n + 1))
			await each.call(n, image)
			done += 1
			if _cancelled:
				break
	_pivot.rotation = Vector3.ZERO
	_finish()
	return done


## Draw an animation of [param frames] frames, the same way: before each,
## [param pose_at] (frame -> brick id in the world -> Transform3D) says
## where the parts that move stand, and [param turn_at] (frame -> turns, 0
## to 1) how far round the model has turned. [param reach] is the box they
## sweep through, for the framing. The model itself is not touched; its
## copy on the stage is moved, and copied again for the next render.
## [param each] gets each frame as it is finished. Returns how many were
## drawn, all of them unless cancelled.
func animate(world: BrickWorld, settings: RenderSettings, frames: int, pose_at: Callable,
		turn_at: Callable, reach: AABB, each: Callable) -> int:
	if _busy or not possible() or world == null:
		return 0
	_busy = true
	_cancelled = false
	worst_frame_ms = 0.0
	worst_step = ""
	_quicken()
	var done: int = 0
	_reach = reach
	var turning: bool = false
	for n: int in frames:
		if not is_zero_approx(float(turn_at.call(n))):
			turning = true
			break
	if await _prepare(world, settings, turning):
		for n: int in maxi(frames, 1):
			var poses: Dictionary = pose_at.call(n)
			for brick_id: Variant in poses:
				var staged: int = int(_staged_ids.get(int(brick_id), 0))
				if staged != 0:
					_stage.move_brick(staged, poses[brick_id])
			_stage._flush()
			_pivot.rotation = Vector3(0.0, TAU * float(turn_at.call(n)), 0.0)
			var from: float = 0.1 + 0.9 * float(n) / float(frames)
			var image: Image = await _picture(settings, from, from + 0.9 / float(frames),
				"frame %d of %d" % [n + 1, frames])
			if image == null:
				break
			await get_tree().process_frame
			_doing("keeping frame %d" % (n + 1))
			await each.call(n, image)
			done += 1
			if _cancelled:
				break
	_pivot.rotation = Vector3.ZERO
	_reach = AABB()
	# The copy on the stage stands as the last frame did, not as the model
	# does: copied again next time.
	_staged = []
	_finish()
	return done


## The box an animation's moving parts sweep, framed with the model.
var _reach := AABB()
## Brick id in the world -> its copy's on the stage.
var _staged_ids: Dictionary = {}


## Where a part of the world is on the stage, for a probe: its copy's
## transform, or the identity when it was not staged.
func staged_transform(brick_id: int) -> Transform3D:
	var staged: BrickWorld.Brick = _stage.get_brick(int(_staged_ids.get(brick_id, 0))) \
		if _stage != null else null
	return staged.transform if staged != null else Transform3D.IDENTITY


func _finish() -> void:
	print("render: the longest frame %.0f ms (%s)" % [worst_frame_ms, worst_step])
	_settle()
	if _cancelled:
		progress.emit(0.0, "cancelled")
	_busy = false
	_cancelled = false


# -- the set ---------------------------------------------------------------


func _build() -> void:
	if _built:
		return
	_built = true
	var world := World3D.new()

	_out = _view(true, false)
	_out.name = "Out"
	add_child(_out)
	_resolve_material = _canvas(_out, RESOLVE)
	for n: int in 2:
		var sums: SubViewport = _view(true, true)
		sums.name = "Sum%d" % n
		_sums.append(sums)
		_sum_materials.append(_canvas(sums, SUM))
	_out.add_child(_sums[1])
	_sums[1].add_child(_sums[0])
	_base = _view(true, false)
	_base.name = "Base"
	_sums[0].add_child(_base)
	var copy_material: ShaderMaterial = _canvas(_base, COPY)
	_scene = _view(true, false)
	_scene.name = "Scene"
	_scene.world_3d = world
	_base.add_child(_scene)

	copy_material.set_shader_parameter("frame_tex", _scene.get_texture())
	for n: int in 2:
		_sum_materials[n].set_shader_parameter("frame_tex", _scene.get_texture())
		_sum_materials[n].set_shader_parameter("base_tex", _base.get_texture())
		_sum_materials[n].set_shader_parameter("sum_tex", _sums[1 - n].get_texture())
	_resolve_material.set_shader_parameter("base_tex", _base.get_texture())

	_camera = Camera3D.new()
	_camera.cull_mask = 1 | 2
	_scene.add_child(_camera)
	_camera.current = true

	for n: int in RIG.size():
		var light := DirectionalLight3D.new()
		_scene.add_child(light)
		_lights.append(light)
	_sky_light = DirectionalLight3D.new()
	_sky_light.shadow_enabled = true
	_sky_light.visible = false
	_scene.add_child(_sky_light)

	_backdrop = MeshInstance3D.new()
	_backdrop.layers = 2
	_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_backdrop_material = ShaderMaterial.new()
	_backdrop_material.shader = BACKDROP
	_backdrop_material.set_shader_parameter("linearise", full_renderer())
	_backdrop.material_override = _backdrop_material
	_scene.add_child(_backdrop)

	_pivot = Node3D.new()
	_scene.add_child(_pivot)
	_stage = BrickWorld.new()
	_stage.library = library
	_stage.keeps_history = false
	_pivot.add_child(_stage)

	_contact = MeshInstance3D.new()
	_contact.layers = 2
	_contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contact.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_contact_material = ShaderMaterial.new()
	_contact_material.shader = CONTACT
	# Before any transparent brick, which must be drawn over it.
	_contact_material.render_priority = -1
	_contact.material_override = _contact_material
	_pivot.add_child(_contact)

	# The model seen from under the floor, for its contact shadow: only the
	# bricks (layer 1), in a light of nothing, on nothing.
	_floor_view = SubViewport.new()
	_floor_view.name = "Floor"
	_floor_view.size = Vector2i(512, 512)
	_floor_view.transparent_bg = true
	_floor_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_floor_view.gui_disable_input = true
	_floor_view.world_3d = world
	add_child(_floor_view)
	_floor_camera = Camera3D.new()
	_floor_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_floor_camera.cull_mask = 1
	var plain := Environment.new()
	plain.background_mode = Environment.BG_CLEAR_COLOR
	plain.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	plain.ambient_light_color = Color(1, 1, 1)
	_floor_camera.environment = plain
	_floor_view.add_child(_floor_camera)
	_floor_camera.current = true

	# Whether the sums can hold more than 8 bits here: a browser without
	# float render targets gets 8-bit ones whatever is asked for.
	# Two pixels to read back, which makes a browser finish what it has
	# queued (see _picture).
	_fence = _view(false, false)
	_fence.name = "Fence"
	_fence.size = Vector2i(2, 2)
	add_child(_fence)
	await _draw([_fence])
	# A frame each, and the card left to finish each before the next: the
	# first draw of each is its shaders being built, which in a browser
	# drawing in software is seconds, and all of them in one frame held the
	# page for twelve. Read back instead, each still held it for as long.
	_size_all(Vector2i(8, 8))
	for view: SubViewport in [_scene, _base, _out]:
		await _draw([view])
		_doing("setting up the viewports")
		await GpuFence.finished()
	await _draw([_sums[0]])
	_doing("setting up the viewports")
	var probe: Image = await _read(_sums[0])
	_floats = probe != null and probe.get_format() in [Image.FORMAT_RGBAF, Image.FORMAT_RGBAH,
		Image.FORMAT_RGBF, Image.FORMAT_RGBH]
	for n: int in 2:
		_sum_materials[n].set_shader_parameter("floats", _floats)
	_resolve_material.set_shader_parameter("floats", _floats)


func _view(transparent: bool, floats: bool) -> SubViewport:
	var view := SubViewport.new()
	view.transparent_bg = transparent
	view.use_hdr_2d = floats
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.gui_disable_input = true
	view.size = Vector2i(8, 8)
	return view


func _canvas(view: SubViewport, shader: Shader) -> ShaderMaterial:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	view.add_child(rect)
	return material


func _size_all(size: Vector2i) -> void:
	for view: SubViewport in [_out, _sums[0], _sums[1], _base, _scene]:
		if view.size != size:
			view.size = size


## Draw these viewports once, and wait until they have been. Waited by
## frames drawn rather than on frame_post_draw so a cancel is noticed
## while a window that is not being drawn holds the picture up. What in
## them is new to the way they are set up is drawn first, a thing a frame
## (see [method _warm]).
func _draw(views: Array) -> bool:
	for view: SubViewport in views:
		if (view == _scene or view == _floor_view) and not await _warm(view):
			return false
	return await _draw_now(views)


## A view's picture, read back once the card has drawn it. Reading back
## waits for everything asked of the card before it, which in a browser
## drawing in software is the page held for as long as the picture takes
## to rasterise: the card is waited for first, a frame at a time, with the
## page answering (GpuFence).
func _read(view: SubViewport) -> Image:
	await GpuFence.finished()
	return view.get_texture().get_image()


## The layer a thing is put on to be drawn alone: nothing else is on it.
const WARM_LAYER := 1 << 19

## What has been drawn in which set-up: [method _warm]'s keys.
var _warmed: Dictionary = {}


## Before a 3D view of the set is drawn: each thing in it the view has not
## drawn in this set-up before, drawn first on its own, a thing a frame,
## and the card left to finish each before the next.
##
## Under Compatibility (every browser) a shader is built for each way it is
## drawn, in the frame that first draws it that way, and the set draws the
## model's shaders in ways the window never does: under a key light's
## shadow of its own, and in no light for the contact shadow; and the sweep
## and the contact shadow's own besides. Drawn together, the first open of
## File, Render… built eighteen programs in four frames, and in a browser
## drawing in software held the page for up to 9 s (a preview, 2026-10-12;
## about a second here, tools/web/render_open_check.mjs). A thing is a
## batch of the model for each shader and kind of mesh in it, the sweep, or
## the contact shadow: at most six programs a frame. Forward+ builds its
## pipelines away from the frame and needs none of this.
func _warm(view: SubViewport) -> bool:
	if full_renderer():
		return true
	var camera: Camera3D = _floor_camera if view == _floor_view else _camera
	var setup: String = _setup(view, camera)
	# Asked again for every frame of a render: a model's batches are
	# looked through only when what is staged or shown has changed.
	var asked: String = "%s %d %s %d %d" % [setup, camera.cull_mask, str(_staged),
		int(_backdrop.visible), int(_contact.visible and _contact.mesh != null)]
	if _warmed.has(asked):
		return true
	var due: Array[GeometryInstance3D] = []
	for thing: GeometryInstance3D in _things(camera.cull_mask):
		if not _warmed.has(setup + _kind(thing)):
			due.append(thing)
	if due.is_empty():
		_warmed[asked] = true
		return true
	var mask: int = camera.cull_mask
	var lights: Array[DirectionalLight3D] = _lights.duplicate()
	lights.append(_sky_light)
	var seen: Array[int] = []
	var lighting: Array[int] = []
	for light: DirectionalLight3D in lights:
		# A camera sees only the lights on the layers it draws: left off
		# them, what was built was for a set with no lights at all.
		seen.append(light.layers)
		light.layers = light.layers | WARM_LAYER
		# And they light and shadow the one thing: a shadow takes in all
		# its light's layers whatever the camera sees, and the whole
		# model's, drawn in software, was most of a frame's wait.
		lighting.append(light.light_cull_mask)
		light.light_cull_mask = WARM_LAYER
	camera.cull_mask = WARM_LAYER
	var done: bool = true
	for thing: GeometryInstance3D in due:
		var layers: int = thing.layers
		thing.layers = WARM_LAYER
		_doing("building the shaders of %s" % thing.name)
		done = await _draw_now([view])
		thing.layers = layers
		if not done:
			break
		await GpuFence.finished()
		_warmed[setup + _kind(thing)] = true
	for n: int in lights.size():
		lights[n].layers = seen[n]
		lights[n].light_cull_mask = lighting[n]
	camera.cull_mask = mask
	if done:
		_warmed[asked] = true
	return done


## What decides how a view draws a thing, besides the thing: its samples,
## the light it is in, which lights there are and which cast shadows.
func _setup(view: SubViewport, camera: Camera3D) -> String:
	var lights := PackedStringArray()
	for light: DirectionalLight3D in _lights + [_sky_light]:
		lights.append("%d%d" % [int(light.visible), int(light.shadow_enabled)])
	var environment: Environment = camera.environment
	return "%s %d %d %s|" % [view.name, view.msaa_3d,
		environment.get_instance_id() if environment != null else 0, "".join(lights)]


## Everything in the set the camera's [param mask] takes in that will be
## drawn: one of each kind (see [method _kind]).
func _things(mask: int) -> Array[GeometryInstance3D]:
	var kinds: Dictionary = {}
	var all: Array[GeometryInstance3D] = [_backdrop, _contact]
	for child: Node in _stage.get_children():
		if child is MultiMeshInstance3D:
			all.append(child as GeometryInstance3D)
	for thing: GeometryInstance3D in all:
		if not thing.is_visible_in_tree() or (thing.layers & mask) == 0:
			continue
		var batch := thing as MultiMeshInstance3D
		if batch != null and (batch.multimesh == null or batch.multimesh.mesh == null
				or batch.multimesh.instance_count == 0 or batch.multimesh.visible_instance_count == 0):
			continue
		var plain := thing as MeshInstance3D
		if plain != null and plain.mesh == null:
			continue
		var kind: String = _kind(thing)
		if not kinds.has(kind):
			kinds[kind] = thing
	var out: Array[GeometryInstance3D] = []
	out.assign(kinds.values())
	return out


## What a shader is built for: the shader, instanced or not, and the
## format of the mesh's vertices.
static func _kind(thing: GeometryInstance3D) -> String:
	var material: Material = thing.material_override
	var shader: Shader = (material as ShaderMaterial).shader if material is ShaderMaterial else null
	var mesh: Mesh = (thing as MultiMeshInstance3D).multimesh.mesh if thing is MultiMeshInstance3D \
		else (thing as MeshInstance3D).mesh
	var format: int = (mesh as ArrayMesh).surface_get_format(0) \
		if mesh is ArrayMesh and mesh.get_surface_count() > 0 else 0
	return "%d %d %s %d" % [shader.get_rid().get_id() if shader != null else 0,
		int(thing is MultiMeshInstance3D), mesh.get_class() if mesh != null else "", format]


func _draw_now(views: Array) -> bool:
	var names := PackedStringArray()
	for view: SubViewport in views:
		names.append(str(view.name))
	_doing("drawing %s at %s" % [",".join(names), str((views[0] as SubViewport).size)])
	for view: SubViewport in views:
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var drawn: int = Engine.get_frames_drawn()
	while Engine.get_frames_drawn() == drawn:
		await get_tree().process_frame
		if _cancelled:
			return false
	return true


## Copy the model on to the stage, a slice a frame (FramePace), unless what
## is there already is it.
func _stage_model(world: BrickWorld) -> bool:
	var wanted: Array = [world.get_instance_id(), world.generation(), world.revision,
		scenery.size(), scenery.hash(), _hidden_hash(world)]
	if wanted == _staged:
		return true
	_staged = []
	_staged_ids.clear()
	_stage.clear()
	_stage.hold_drawing()
	var pace := FramePace.new()
	var all: Array = world.bricks()
	var done: int = 0
	for brick: BrickWorld.Brick in all:
		done += 1
		if pace.due():
			progress.emit(0.06 * float(done) / float(maxi(all.size(), 1)),
				"setting up the model")
			await pace.next()
			if _cancelled:
				_stage.release_drawing()
				return false
			if world.revision != wanted[2]:
				_stage.release_drawing()
				return await _stage_model(world)
		# The baseplate the model stands on is staged with it: a render is a
		# photograph of the model on its floor (ModelFloor), and a floor
		# with no plate has no scenery to stage.
		if brick.hidden:
			continue
		if _step.is_empty():
			_doing("staging")
		_staged_ids[brick.id] = _stage.add_brick(brick.part_id, brick.color_code, brick.transform)
	_stage.release_drawing()
	# The batches are written on the frame after.
	await get_tree().process_frame
	_bounds = _stage.model_bounds()
	# Framed on the model, not its baseplate: the plate is the ground it
	# stands on, running out under the sweep, and a small model on a big
	# plate is still the subject of the picture.
	_framed = AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in all:
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if library != null else null
		if scenery.has(brick.id) or brick.hidden or mesh == null:
			continue
		var box: AABB = brick.transform * mesh.bounds
		_framed = box if first else _framed.merge(box)
		first = false
	if first:
		_framed = _bounds
	_staged = wanted
	return true


static func _hidden_hash(world: BrickWorld) -> int:
	var hidden: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if brick.hidden:
			hidden.append(brick.id)
	return hidden.hash()


## Everything a render needs that is the same for every frame of it.
func _prepare(world: BrickWorld, settings: RenderSettings, turning: bool) -> bool:
	if library == null:
		library = world.library
	if not _built:
		await _build()
	_stage.library = library
	progress.emit(0.0, "setting up the model")
	if not await _stage_model(world):
		return false
	if _bounds.size.length() <= 0.0:
		return false
	if _reach.size.length() > 0.0:
		_bounds = _bounds.merge(_reach)
		_framed = _framed.merge(_reach)
	var plan: Plan = plan_for(settings)
	var shot: Shot = aim(settings, _framed, turning)
	last_shot = shot
	last_samples = plan.samples
	_pivot.position = Vector3(_framed.get_center().x, 0.0, _framed.get_center().z)
	_stage.position = -_pivot.position
	_pivot.rotation = Vector3.ZERO
	# What the window's own light makes of this model from here: the
	# lightness every other choice is exposed to match.
	var metered: bool = settings.lighting != "studio" or plan.gi
	var wanted: float = 0.0
	if metered:
		var reference: RenderSettings = settings.copy()
		reference.lighting = "studio"
		reference.quality = RenderSettings.Quality.QUICK
		_dress(reference, plan_for(reference), shot)
		wanted = await _meter(shot, settings.size)
		if wanted < 0.0:
			return false
	_dress(settings, plan, shot)
	progress.emit(0.07, "the contact shadow")
	if settings.contact_shadow:
		if not await _contact_shadow():
			return false
	_contact.visible = settings.contact_shadow
	# Global illumination gathers over frames: let it settle before the
	# first one that counts.
	if plan.warm_up > 0:
		_size_all(Vector2i(256, 256))
		_point(shot, Rect2i(Vector2i.ZERO, settings.size), 0, settings.size,
			Vector2(0.0, 0.0), Vector2.ZERO)
		for n: int in plan.warm_up:
			if not await _draw([_scene]):
				return false
			if n % 4 == 0:
				progress.emit(0.07 + 0.03 * float(n) / float(plan.warm_up), "gathering the light")
	# Then exposed like a photographer metering off the subject, not the
	# sweep: a place photographed is as bright as it was, and light
	# bounced round a white studio adds up, and either came out half as
	# light again as the window draws the same bricks.
	last_exposure = 1.0
	if metered and wanted > 0.0:
		var environment: Environment = _camera.environment
		var base: float = environment.tonemap_exposure
		var scale: float = 1.0
		for _round: int in 3:
			var got: float = await _meter(shot, settings.size)
			if got < 0.0:
				return false
			if got <= 0.001 or absf(got / wanted - 1.0) < 0.03:
				break
			# Lightness is tone-mapped and grows slower than the light;
			# a little over the ratio closes in faster.
			scale *= clampf(pow(wanted / got, 1.4), 0.4, 2.5)
			environment.tonemap_exposure = base * scale
		last_exposure = scale
	# And the sweep brought to its colour: white white, black black.
	_floor_mask = null
	if _backdrop.visible:
		var level: float = 1.0
		_backdrop_material.set_shader_parameter("level", level)
		var goal: float = minf(settings.backdrop.get_luminance(), 0.95)
		for _round: int in 4:
			var floor_seen: float = await _meter_floor(shot, settings.size)
			if floor_seen < 0.0:
				return false
			if absf(floor_seen - goal) < 0.015 or floor_seen <= 0.0005:
				break
			level = clampf(level * clampf(pow(goal / floor_seen, 1.6), 0.3, 3.0), 0.05, 6.0)
			_backdrop_material.set_shader_parameter("level", level)
		last_level = level
	return true


## How light the sweep is: the brighter part of a small picture of it,
## less the model and so that the model's shadows on it do not count, the
## wall behind included (metered off the floor in front, a softbox's wall
## stayed grey). The model is in the picture and masked out of it, not
## left out: under Compatibility a light whose shadow-casters are all out
## of the picture is not drawn at all, and the floor metered without the
## key came out a grey that was "corrected" to a clipped white. -1 if
## cancelled.
func _meter_floor(shot: Shot, picture: Vector2i) -> float:
	var aspect: float = float(picture.x) / float(maxi(picture.y, 1))
	var small := Vector2i(maxi(roundi(120.0 * aspect), 16), 120)
	_size_all(small)
	_point(shot, Rect2i(Vector2i.ZERO, picture), 0, picture, Vector2.ZERO, Vector2.ZERO)
	if _floor_mask == null or _floor_mask.get_size() != small:
		var environment: Environment = _camera.environment
		var background: int = environment.background_mode
		environment.background_mode = Environment.BG_CLEAR_COLOR
		_camera.cull_mask = 1
		var masked: bool = await _draw([_scene])
		_camera.cull_mask = 1 | 2
		environment.background_mode = background as Environment.BGMode
		if not masked:
			return -1.0
		_doing("reading the floor's mask")
		_floor_mask = await _read(_scene)
	if not await _draw([_scene]):
		return -1.0
	var image: Image = await _read(_scene)
	if image == null:
		return 0.0
	var levels := PackedFloat32Array()
	for y: int in image.get_height():
		for x: int in image.get_width():
			if _floor_mask.get_pixel(x, y).a < 0.1:
				levels.append(image.get_pixel(x, y).get_luminance())
	if levels.is_empty():
		return 0.0
	levels.sort()
	return levels[int(float(levels.size() - 1) * 0.7)]


## The model's mean lightness from here, in a small picture of only the
## bricks on nothing: the sweep is left in the world, where it bounces
## light and catches shadows, and out of the picture. -1 if cancelled.
func _meter(shot: Shot, picture: Vector2i) -> float:
	var aspect: float = float(picture.x) / float(maxi(picture.y, 1))
	var small := Vector2i(maxi(roundi(120.0 * aspect), 16), 120)
	_size_all(small)
	var environment: Environment = _camera.environment
	var background: int = environment.background_mode
	environment.background_mode = Environment.BG_CLEAR_COLOR
	_camera.cull_mask = 1
	_point(shot, Rect2i(Vector2i.ZERO, picture), 0, picture, Vector2.ZERO, Vector2.ZERO)
	var drawn: bool = await _draw([_scene])
	_camera.cull_mask = 1 | 2
	environment.background_mode = background as Environment.BGMode
	if not drawn:
		return -1.0
	var image: Image = await _read(_scene)
	if image == null:
		return 0.0
	var sum: float = 0.0
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.95:
				sum += c.get_luminance()
				count += 1
	return sum / float(count) if count > 0 else 0.0


## Where the camera goes for these settings, framing [param bounds].
## [param turning]: the model will turn, so frame what it sweeps through.
func aim(settings: RenderSettings, bounds: AABB, turning: bool = false) -> Shot:
	var shot := Shot.new()
	shot.fov = settings.fov_degrees()
	var aspect: float = float(settings.size.x) / float(maxi(settings.size.y, 1))
	var frame: AABB = bounds
	if turning:
		# Every way round: the circle the footprint sweeps, as a square.
		var centre: Vector3 = bounds.get_center()
		var reach: float = Vector2(bounds.size.x, bounds.size.z).length() * 0.5
		frame = AABB(Vector3(centre.x - reach, bounds.position.y, centre.z - reach),
			Vector3(reach * 2.0, bounds.size.y, reach * 2.0))
	var view: String = settings.view if VIEWS.has(settings.view) else "hero"
	# Perspective is a frustum shifted to the model's column (CadCamera);
	# the picture is centred on what the view looks at either way.
	if view == "current" and eye != null and eye.projection != Camera3D.PROJECTION_ORTHOGONAL:
		var from: Transform3D = eye.global_transform
		var forward: Vector3 = -from.basis.z.normalized()
		var focus: Vector3 = eye.call("focus_now") if eye.has_method("focus_now") \
			else frame.get_center()
		var depth: float = maxf((focus - from.origin).dot(forward), 1.0)
		# The point looked at stays the size it is, through the new lens.
		var scale: float = tan(deg_to_rad(eye.fov) * 0.5) / tan(deg_to_rad(shot.fov) * 0.5)
		shot.basis = from.basis.orthonormalized()
		shot.origin = from.origin + forward * depth * (1.0 - scale)
	else:
		var direction: Vector3 = Vector3(VIEWS["hero"][1])
		if view == "current" and eye != null:
			direction = eye.global_transform.basis.z
		elif view != "current":
			direction = Vector3(VIEWS[view][1])
		shot.basis = _looking_from(direction.normalized())
		shot.origin = _fit(shot.basis, frame, shot.fov, aspect)
	# Clip planes round the model and the sweep behind it.
	var radius: float = frame.size.length() * 0.5
	var nearest: float = INF
	var farthest: float = 0.0
	var forward_axis: Vector3 = -shot.basis.z
	for n: int in 8:
		var corner: Vector3 = _corner(frame, n)
		var depth_here: float = (corner - shot.origin).dot(forward_axis)
		nearest = minf(nearest, depth_here)
		farthest = maxf(farthest, depth_here)
	shot.near = clampf(nearest * 0.5, 0.5, 200.0)
	shot.far = maxf(farthest, 1.0) + radius * 90.0
	shot.focus_distance = maxf(lerpf(nearest, farthest, clampf(settings.focus, 0.0, 1.0)),
		shot.near * 2.0)
	if settings.f_stop > 0.0:
		# A real lens on a real-sized model: an LDU is 0.4 mm.
		shot.aperture = settings.focal_mm / settings.f_stop * 0.5 / 0.4
	var along: Vector3 = Vector3(shot.basis.z.x, 0.0, shot.basis.z.z)
	if along.length() < 0.2:
		along = Vector3(-shot.basis.y.x, 0.0, -shot.basis.y.z)
	shot.toward = along.normalized() if along.length() > 0.0001 else Vector3.BACK
	shot.heading = atan2(shot.toward.x, shot.toward.z)
	return shot


static func _corner(box: AABB, n: int) -> Vector3:
	return box.position + Vector3(
		box.size.x if n & 1 else 0.0,
		box.size.y if n & 2 else 0.0,
		box.size.z if n & 4 else 0.0)


## A camera basis looking along -[param direction], up kept up.
static func _looking_from(direction: Vector3) -> Basis:
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.98 else Vector3.FORWARD
	return Basis.looking_at(-direction, up)


## Back the camera off until every corner of [param box] is inside the
## frame, then slide it so the model is in the middle of it.
static func _fit(basis: Basis, box: AABB, fov: float, aspect: float) -> Vector3:
	var tan_up: float = tan(deg_to_rad(fov) * 0.5) * FILL
	var tan_across: float = tan_up * aspect
	var target: Vector3 = box.get_center()
	var origin: Vector3 = target
	for _round: int in 4:
		var need: float = 0.0
		for n: int in 8:
			var corner: Vector3 = _corner(box, n) - target
			var back: float = corner.dot(basis.z)
			need = maxf(need, back + absf(corner.dot(basis.x)) / tan_across)
			need = maxf(need, back + absf(corner.dot(basis.y)) / tan_up)
		origin = target + basis.z * need
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for n: int in 8:
			var seen: Vector3 = _corner(box, n) - origin
			var depth: float = maxf(-seen.dot(basis.z), 0.001)
			var at := Vector2(seen.dot(basis.x) / depth, seen.dot(basis.y) / depth)
			low = low.min(at)
			high = high.max(at)
		var middle: Vector2 = (low + high) * 0.5
		target += (basis.x * middle.x + basis.y * middle.y) * need
	return origin


## The lights, the environment and the sweep, for this shot.
func _dress(settings: RenderSettings, plan: Plan, shot: Shot) -> void:
	var full: bool = full_renderer()
	var turn: float = shot.heading - RIG_HEADING + deg_to_rad(settings.light_turn)
	var spin := Basis(Vector3.UP, turn)
	var floor_y: float = _bounds.position.y
	var radius: float = _bounds.size.length() * 0.5
	var reach: float = (shot.origin - _bounds.get_center()).length() + radius * 2.5

	var panorama: StudioPanorama = _panorama(settings.lighting)
	# One environment for each way of lighting, kept and changed rather than
	# made again: in a browser each new one drawn for the first time held the
	# page for seconds, at the start of every draft.
	var key: String = "%s %s %s %s" % [settings.lighting, plan.gi, plan.occlusion,
		plan.sky_samples]
	var environment: Environment = _environments.get(key)
	if environment == null:
		environment = look.duplicate() if look != null else Environment.new()
		environment.glow_enabled = false
		environment.ssil_enabled = false
		environment.ssr_enabled = false
		environment.volumetric_fog_enabled = false
		environment.fog_enabled = false
		environment.ssao_enabled = plan.occlusion
		environment.sdfgi_enabled = plan.gi
		if look == null:
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.ambient_light_color = Color(0.86, 0.86, 0.87)
			environment.tonemap_mode = Environment.TONE_MAPPER_ACES
			environment.tonemap_white = 6.0
		if panorama != null and full:
			var sky := Sky.new()
			var material := PanoramaSkyMaterial.new()
			material.panorama = panorama.texture
			# As bright as the window's light whatever the place: its
			# average brought to one, and the exposure metered after.
			material.energy_multiplier = HDRI_LEVEL / maxf(panorama.average, 0.0001)
			sky.sky_material = material
			environment.sky = sky
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			environment.ambient_light_sky_contribution = 1.0
			environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		elif panorama != null:
			# Compatibility lights a sky in sRGB and both of its uses came
			# out wrong there: its ambient's tint several times too strong
			# (the window's warm room turned a grey plate orange), and its
			# reflection a grey veil over every face once the exposure was
			# metered up (a softbox's blue went #385185 where the window
			# draws #003496). So in a browser the place gives the light its
			# direction, colour and shadows, and the window's own sky stays
			# what the plastic reflects.
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.ambient_light_color = panorama.tint.lerp(Color(1, 1, 1), 0.5)
		if plan.gi:
			environment.sdfgi_use_occlusion = true
			environment.sdfgi_read_sky_light = true
			environment.sdfgi_cascades = 4
			environment.sdfgi_bounce_feedback = 0.5
			environment.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_100_PERCENT
			# Weak: at full strength the white sweep under the model lit it
			# like a second sun, and the probe measured the model half as
			# light again as the window draws it, its reds gone to pink.
			environment.sdfgi_energy = GI_ENERGY if panorama == null else 1.0
		_environments[key] = environment
	# What changes from picture to picture.
	environment.tonemap_exposure = look.tonemap_exposure if look != null else 1.05
	if settings.transparent:
		environment.background_mode = Environment.BG_CLEAR_COLOR
	else:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = settings.backdrop
	var ambient_forward: float = (look.ambient_light_energy if look != null else 0.24) \
		/ BrickWorld.light_energy(1.0)
	if look == null:
		ambient_forward = 0.4
	var key_energy_forward: float = 0.9
	if panorama != null:
		ambient_forward = HDRI_AMBIENT * (1.0 - 0.5 * panorama.key_share)
		key_energy_forward = HDRI_KEY * panorama.key_share
		environment.sky_rotation = Vector3(0.0, turn, 0.0) if full else Vector3.ZERO
	environment.ambient_light_energy = BrickWorld.light_energy(ambient_forward)
	if plan.gi:
		environment.sdfgi_min_cell_size = clampf(radius / 48.0, 0.5, 64.0)
	if plan.sky_samples:
		# Part of the even light moves into lights from the sky that cast
		# shadows (see _light_sample), which is what darkens under a ledge.
		environment.ambient_light_energy = BrickWorld.light_energy(
			ambient_forward * (1.0 - SKY_SHARE))
	_camera.environment = environment
	_scene.msaa_3d = plan.msaa as Viewport.MSAA

	# The lights.
	for n: int in _lights.size():
		var light: DirectionalLight3D = _lights[n]
		var row: Array = RIG[n]
		var source: DirectionalLight3D = rig_lights[n] if n < rig_lights.size() else null
		var own: Vector3 = source.global_transform.basis.z if source != null else Vector3(row[0])
		var toward: Vector3 = (spin * own).normalized()
		light.light_color = source.light_color if source != null else Color(row[4])
		light.light_specular = source.light_specular if source != null \
			else BrickWorld.light_specular(float(row[3]))
		light.shadow_enabled = bool(row[2]) and not settings.no_shadows
		light.light_energy = source.light_energy if source != null \
			else BrickWorld.light_energy(float(row[1]), bool(row[2]))
		light.visible = true
		if panorama != null:
			# The place's own brightest light is the key; the fill and rim
			# are the panorama's.
			if n == 0:
				toward = (Basis(Vector3.UP, turn) * panorama.key).normalized()
				light.light_energy = BrickWorld.light_energy(key_energy_forward, true)
				light.light_color = panorama.key_tint.lerp(Color(1, 1, 1), 0.5)
			else:
				light.visible = false
		if n == 0 and plan.gi and panorama == null:
			# Bounced light fills the key's shadow in, and a shadow filled
			# in on a white floor is no shadow: the key gains what the
			# bounce took, and the floor's shadow is as deep as Quick's.
			light.light_energy *= GI_KEY
		light.set_meta("toward", toward)
		_aim_light(light, toward)
		light.light_angular_distance = plan.soft_key if n == 0 else 0.0
		# Softer where frames are averaged under a key that moves: each
		# frame's copy of the shadow blends into the next.
		light.shadow_blur = 2.5 if not full and plan.samples > 1 \
			else (1.5 if plan.soft_key > 0.0 or not full else 1.0)
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		light.directional_shadow_max_distance = reach
		light.directional_shadow_fade_start = 1.0
		light.shadow_bias = 0.02
		light.shadow_normal_bias = 1.5
	_sky_light.visible = plan.sky_samples
	_sky_light.shadow_enabled = not settings.no_shadows
	_sky_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sky_light.directional_shadow_max_distance = reach
	_sky_light.directional_shadow_fade_start = 1.0
	_sky_light.shadow_bias = 0.03
	_sky_light.shadow_normal_bias = 1.2
	# Blurred well past the key's: a few dozen hard shadows from as many
	# points of the sky laid over each other showed as streaks fanning out
	# across the floor.
	_sky_light.shadow_blur = 4.0
	_sky_light.light_specular = 0.0
	_sky_light.set_meta("ambient", ambient_forward * SKY_SHARE)
	_sky_light.set_meta("turn", turn)
	# Straight down at half a sample's strength until the samples move it:
	# on average a sample lights a floor that much, and the metering that
	# comes before them must see the average, not one sample's corner.
	_aim_light(_sky_light, Vector3.UP)
	_sky_light.light_color = Color(0.9, 0.9, 0.92)
	_sky_light.light_energy = BrickWorld.light_energy(ambient_forward * SKY_SHARE, true)
	if full and settings.quality != RenderSettings.Quality.QUICK:
		_shadow_atlas(8192)
		# The finest occlusion and soft shadows there are, at full size: the
		# engine's defaults are made for a game's frame, half-size occlusion
		# and a few shadow taps, and in a 4K still both showed as a grid of
		# dots over every face.
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_ULTRA,
			false, 0.5, 4, 50.0, 300.0)
		RenderingServer.directional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	else:
		_shadow_atlas(_project_atlas())

	# The sweep, its wall behind the model and its floor running out
	# under the camera, turned to face it.
	var below: bool = shot.origin.y < floor_y
	_backdrop.visible = not settings.transparent and not below
	if _backdrop.visible:
		var footprint: float = Vector2(_bounds.size.x, _bounds.size.z).length() * 0.5
		var shape := Vector3(footprint * 1.25 + 40.0, maxf(radius * 2.0, 160.0),
			radius * 60.0 + reach * 3.0)
		if shape != _sweep_shape or _backdrop.mesh == null:
			_sweep_shape = shape
			_backdrop.mesh = _sweep(shape.x, shape.y, shape.z)
		var facing: Basis = Basis.looking_at(-shot.toward, Vector3.UP)
		_backdrop.global_transform = Transform3D(facing,
			Vector3(_bounds.get_center().x, floor_y, _bounds.get_center().z))
		_backdrop_material.set_shader_parameter("colour",
			Vector3(settings.backdrop.r, settings.backdrop.g, settings.backdrop.b))


## The shadow map's size, set only when it changes: the atlas is made
## again whenever it is set, and in a browser that was seconds a render.
func _shadow_atlas(size: int) -> void:
	if _atlas_size < 0:
		_atlas_size = _project_atlas()
	if size == _atlas_size:
		return
	_atlas_size = size
	RenderingServer.directional_shadow_atlas_set_size(size, true)


static func _project_atlas() -> int:
	return int(ProjectSettings.get_setting(
		"rendering/lights_and_shadows/directional_shadow/size", 4096))


var _atlas_size: int = -1
var _sweep_shape := Vector3.ZERO
## Environments by the way of lighting they are for: see _dress.
var _environments: Dictionary = {}


## How bright a panorama is made: its average luminance brought to this,
## and the ambient and key it lights with, under Forward+.
const HDRI_LEVEL := 1.0
const HDRI_AMBIENT := 0.5
const HDRI_KEY := 1.0


static func _aim_light(light: DirectionalLight3D, toward: Vector3) -> void:
	var up: Vector3 = Vector3.UP if absf(toward.y) < 0.98 else Vector3.FORWARD
	light.global_transform = Transform3D(Basis.looking_at(-toward, up), Vector3.ZERO)


## A floor that curves up into a wall: [param behind] from the model to
## where it starts curving, [param bend] the curve's radius, [param far]
## how far floor and wall run, so their edges are never in the picture.
static func _sweep(behind: float, bend: float, far: float) -> ArrayMesh:
	# (z, y, the angle the curve has turned through): the normal at each
	# point is the curve's own, so the light goes round the bend smoothly.
	# A normal a segment, the bend was drawn as bands across the wall.
	var profile: Array[Vector3] = []
	profile.append(Vector3(far, 0.0, 0.0))
	profile.append(Vector3(0.0, 0.0, 0.0))
	profile.append(Vector3(-behind, 0.0, 0.0))
	const STEPS := 48
	for n: int in range(1, STEPS + 1):
		var angle: float = PI * 0.5 * float(n) / float(STEPS)
		profile.append(Vector3(-behind - sin(angle) * bend, bend - cos(angle) * bend, angle))
	profile.append(Vector3(-behind - bend, far, PI * 0.5))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = far
	for n: int in profile.size() - 1:
		var a: Vector3 = profile[n]
		var b: Vector3 = profile[n + 1]
		# Square to the profile and into the sweep: up off the floor, out
		# of the wall towards the camera.
		var normals: Array[Vector3] = [Vector3(0.0, cos(a.z), sin(a.z)),
			Vector3(0.0, cos(a.z), sin(a.z)), Vector3(0.0, cos(b.z), sin(b.z)),
			Vector3(0.0, cos(b.z), sin(b.z))]
		var corners: Array[Vector3] = [Vector3(-half, a.y, a.x), Vector3(half, a.y, a.x),
			Vector3(half, b.y, b.x), Vector3(-half, b.y, b.x)]
		# Clockwise seen from inside the sweep, which is Godot's front:
		# drawn the other way, the floor showed its back, the engine turned
		# its normal down, and no light fell on it.
		for index: int in [0, 2, 1, 0, 3, 2]:
			tool.set_normal(normals[index])
			tool.add_vertex(corners[index])
	return tool.commit()


## Three silhouettes of the model seen from under the floor, blurred, for
## studio_contact: within a plate of the floor, a brick, and a few.
func _contact_shadow() -> bool:
	# The same model makes the same shadow: drawn once per model, not per
	# picture. In a browser drawing in software its three silhouettes were
	# the slowest frames of every draft.
	if _contact_for == _staged and _contact.mesh != null:
		return true
	var floor_y: float = _bounds.position.y
	var centre: Vector3 = _bounds.get_center()
	const HEIGHTS: Array = [6.0, 30.0, 110.0]
	const BLURS: Array = [6.0, 26.0, 90.0]
	var span: float = maxf(_bounds.size.x, _bounds.size.z) + 2.0 * 2.5 * float(BLURS[2]) + 40.0
	_floor_camera.size = span
	_floor_camera.global_transform = Transform3D(
		Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)),
		Vector3(centre.x, floor_y - 2.0, centre.z))
	_floor_camera.near = 1.5
	# In no light: only where the bricks are counts, and every light that
	# casts a shadow is a shadow map drawn again for this camera.
	var lit: Array[bool] = []
	var lights: Array[DirectionalLight3D] = _lights.duplicate()
	lights.append(_sky_light)
	for light: DirectionalLight3D in lights:
		lit.append(light.visible)
		light.visible = false
	var textures: Array[ImageTexture] = []
	for n: int in HEIGHTS.size():
		_floor_camera.far = 2.0 + float(HEIGHTS[n])
		if not await _draw([_floor_view]):
			for k: int in lights.size():
				lights[k].visible = lit[k]
			return false
		_doing("reading a silhouette")
		var silhouette: Image = await _read(_floor_view)
		var texel: float = span / float(_floor_view.size.x)
		var across: int = clampi(roundi(float(_floor_view.size.x) * texel / float(BLURS[n])), 4,
			_floor_view.size.x)
		silhouette.resize(across, across, Image.INTERPOLATE_LANCZOS)
		textures.append(ImageTexture.create_from_image(silhouette))
	for k: int in lights.size():
		lights[k].visible = lit[k]
	_contact_for = _staged
	_contact_material.set_shader_parameter("near_tex", textures[0])
	_contact_material.set_shader_parameter("mid_tex", textures[1])
	_contact_material.set_shader_parameter("far_tex", textures[2])
	_contact_material.set_shader_parameter("span", span)
	var plane := PlaneMesh.new()
	plane.size = Vector2(span, span)
	_contact.mesh = plane
	# In the pivot's space, which turns with the model; a hair above the
	# floor so it is never behind it.
	_contact.position = Vector3(0.0, floor_y + 0.4, 0.0)
	return true


# -- drawing -----------------------------------------------------------------


## The picture, piece by piece and sample by sample.
func _picture(settings: RenderSettings, from: float, to: float, words: String = "") -> Image:
	var plan: Plan = plan_for(settings)
	var shot: Shot = last_shot
	var picture: Vector2i = Vector2i(maxi(settings.size.x, 1), maxi(settings.size.y, 1))
	var tiles: Array[Rect2i] = _tiles(picture)
	last_tiles = tiles.size()
	var margin: int = 0
	if tiles.size() > 1 and plan.occlusion:
		# Occlusion looks a little past the edge of what it draws; each
		# piece is drawn wider and cut back.
		margin = clampi(picture.y / 24, 16, 96)
	var tile_size: Vector2i = tiles[0].size
	_size_all(tile_size + Vector2i(margin * 2, margin * 2))
	var result := Image.create(picture.x, picture.y, false, Image.FORMAT_RGBA8)
	var samples: int = plan.samples
	var steps: int = tiles.size() * samples
	var step: int = 0
	_resolve_material.set_shader_parameter("dither", 1.0 if samples > 1 else 0.0)
	_resolve_material.set_shader_parameter("sum_tex", _sums[(samples - 1) % 2].get_texture())
	for tile: Rect2i in tiles:
		for sample: int in samples:
			var pixel := Vector2.ZERO
			var lens := Vector2.ZERO
			if samples > 1:
				pixel = _jitter(sample)
				if plan.lens and shot.aperture > 0.0:
					lens = _disk(_r2(sample, 3)) * shot.aperture
			_point(shot, tile, margin, picture, pixel, lens)
			_light_sample(plan, sample, samples)
			var which: int = sample % 2
			_sum_materials[which].set_shader_parameter("first", sample == 0)
			_sum_materials[which].set_shader_parameter("weight",
				1.0 / float(samples) if _floats else 1.0 / float(sample + 1))
			var views: Array = [_scene, _sums[which]]
			if sample == 0:
				views.append(_base)
			if sample == samples - 1:
				views.append(_out)
			if not await _draw(views):
				return null
			if OS.has_feature("web") and samples > 1 and sample < samples - 1:
				# Wait for this frame here, not for all of them at the end: a
				# browser queues the drawing and hands back control, and the
				# read-back at the end waited for eight frames of Good in one
				# go (5 s in software) and for a cancelled Best's thirty-two.
				_doing("waiting for the frame")
				_fence.get_texture().get_image()
			step += 1
			if step % 4 == 0 or step == steps:
				var said: String = words if not words.is_empty() else (
					"%d of %d frames" % [sample + 1, samples] if samples > 1 else "drawing")
				if tiles.size() > 1 and words.is_empty():
					said = "piece %d of %d, %s" % [tiles.find(tile) + 1, tiles.size(), said]
				progress.emit(lerpf(from, to, float(step) / float(steps)), said)
		_doing("reading the picture back")
		var drawn: Image = await _read(_out)
		if drawn == null:
			return null
		# The copying and converting go in a frame of their own, after the
		# one that read the piece back.
		await get_tree().process_frame
		_doing("putting the piece in")
		if drawn.get_format() != Image.FORMAT_RGBA8:
			drawn.convert(Image.FORMAT_RGBA8)
		var inside: Rect2i = tile.intersection(Rect2i(Vector2i.ZERO, picture))
		result.blit_rect(drawn, Rect2i(Vector2i(margin, margin), inside.size), inside.position)
		piece_done.emit(drawn.get_region(Rect2i(Vector2i(margin, margin), inside.size)),
			inside.position)
	if not settings.transparent:
		await get_tree().process_frame
		_doing("converting")
		result.convert(Image.FORMAT_RGB8)
	return result


## The picture cut into pieces no bigger than this renderer draws at once,
## all the same size (the last ones may run past the edge).
func _tiles(picture: Vector2i) -> Array[Rect2i]:
	var across: int = 1
	var down: int = 1
	if OS.has_feature("web"):
		while ceili(float(picture.x) / float(across)) * ceili(float(picture.y) / float(down)) \
				> MOST_PIXELS_WEB:
			if float(picture.x) / float(across) >= float(picture.y) / float(down):
				across += 1
			else:
				down += 1
	else:
		across = ceili(float(picture.x) / float(MOST_SIDE_DESKTOP))
		down = ceili(float(picture.y) / float(MOST_SIDE_DESKTOP))
	var size := Vector2i(ceili(float(picture.x) / float(across)),
		ceili(float(picture.y) / float(down)))
	var out: Array[Rect2i] = []
	for row: int in down:
		for column: int in across:
			out.append(Rect2i(Vector2i(column * size.x, row * size.y), size))
	return out


## Aim the camera at one piece of the picture, moved [param pixel] under
## the pixel and [param lens] across the lens (LDU), with the plane in
## focus held where it is.
func _point(shot: Shot, tile: Rect2i, margin: int, picture: Vector2i,
		pixel: Vector2, lens: Vector2) -> void:
	var per_pixel: float = 2.0 * shot.near * tan(deg_to_rad(shot.fov) * 0.5) / float(picture.y)
	var centre: Vector2 = Vector2(tile.position) + Vector2(tile.size) * 0.5 + pixel
	var offset := Vector2((centre.x - float(picture.x) * 0.5) * per_pixel,
		-(centre.y - float(picture.y) * 0.5) * per_pixel)
	var origin: Vector3 = shot.origin
	if lens != Vector2.ZERO:
		origin += shot.basis.x * lens.x + shot.basis.y * lens.y
		offset -= lens * shot.near / shot.focus_distance
	_camera.global_transform = Transform3D(shot.basis, origin)
	_camera.set_frustum(per_pixel * float(tile.size.y + margin * 2), offset, shot.near, shot.far)


## Best's lights for one sample: the key moved across its area, and a
## light from another point of the sky.
func _light_sample(plan: Plan, sample: int, samples: int) -> void:
	var key: DirectionalLight3D = _lights[0]
	var toward: Vector3 = key.get_meta("toward", Vector3.UP)
	if plan.key_spread > 0.0 and samples > 1:
		var spot: Vector2 = _disk(_r2(sample, 1)) * plan.key_spread * 0.5
		var across: Vector3 = toward.cross(Vector3.UP).normalized() \
			if absf(toward.y) < 0.98 else Vector3.RIGHT
		var up: Vector3 = across.cross(toward).normalized()
		_aim_light(key, (toward + across * spot.x + up * spot.y).normalized())
	if not plan.sky_samples:
		return
	var turn: float = _sky_light.get_meta("turn", 0.0)
	var share: float = _sky_light.get_meta("ambient", 0.0)
	var panorama: StudioPanorama = null
	var picked: Vector2 = _r2(sample, 2)
	var direction: Vector3
	var colour := Color(0.9, 0.9, 0.92)
	var energy_forward: float
	if _panorama_in_use != null:
		panorama = _panorama_in_use
		direction = Basis(Vector3.UP, turn) * panorama.pick(picked)
		# Picked in proportion to its light, so every pick carries the
		# same share: the sum over the sphere (see StudioPanorama.total). Light
		# from under the floor is the floor's to stop.
		energy_forward = share * 2.0 if direction.y > 0.02 else 0.0
		var lit: Color = panorama.small.get_pixelv(panorama.cell(direction, turn))
		var level: float = maxf(lit.get_luminance(), 0.0001)
		colour = Color(lit.r / level, lit.g / level, lit.b / level).clamp(Color(0, 0, 0),
			Color(1.6, 1.6, 1.6))
	else:
		# Even over the sky above: a light of 2x the ambient it replaces
		# gives a face turned up the same light, on average, and a face
		# turned sideways half (cosine-weighted over the hemisphere).
		var height: float = picked.y
		var around: float = TAU * picked.x
		var flat: float = sqrt(maxf(1.0 - height * height, 0.0))
		direction = Vector3(cos(around) * flat, height, sin(around) * flat)
		energy_forward = share * 2.0
	_sky_light.light_color = colour
	_sky_light.light_energy = BrickWorld.light_energy(energy_forward, true)
	_aim_light(_sky_light, direction.normalized())


var _panorama_in_use: StudioPanorama = null


## The panorama for a lighting choice, read once.
func _panorama(lighting: String) -> StudioPanorama:
	_panorama_in_use = null
	if not HDRIS.has(lighting):
		return null
	if not _panoramas.has(lighting):
		var made: StudioPanorama = StudioPanorama.read(str(HDRIS[lighting][1]))
		if made == null:
			return null
		_panoramas[lighting] = made
	_panorama_in_use = _panoramas[lighting]
	return _panorama_in_use


## Where a sample sits under the pixel, in pixels: spread like a Gaussian
## a little under half a pixel wide, which smooths an edge without
## softening the picture.
static func _jitter(sample: int) -> Vector2:
	var at: Vector2 = _r2(sample, 0)
	var radius: float = minf(sqrt(-2.0 * log(maxf(at.x, 0.0001))) * 0.42, 1.3)
	return Vector2(cos(TAU * at.y), sin(TAU * at.y)) * radius


## A point on the unit disc, evenly.
static func _disk(at: Vector2) -> Vector2:
	var radius: float = sqrt(at.x)
	return Vector2(cos(TAU * at.y), sin(TAU * at.y)) * radius


## Martin Roberts' R2 sequence: points in the square that fill it evenly
## at any count, with a different start for each thing sampled so the
## pixel, the light, the sky and the lens do not move together.
static func _r2(n: int, stream: int) -> Vector2:
	const A1 := 0.7548776662466927
	const A2 := 0.5698402909980532
	var start := Vector2(fposmod(0.5 + 0.371 * float(stream), 1.0),
		fposmod(0.5 + 0.613 * float(stream), 1.0))
	return Vector2(fposmod(start.x + A1 * float(n + 1), 1.0),
		fposmod(start.y + A2 * float(n + 1), 1.0))


# -- the window ---------------------------------------------------------------


## Frames as fast as the machine draws them, while rendering: a window
## nobody looks at is given one a second with vsync on (ModelShot._quicken).
## And every frame drawn: the app may draw only what changed
## (IdleDraw, low-processor mode), and a render's steps that change
## nothing the engine can see would wait for a frame that never comes.
func _quicken() -> void:
	_was_low_processor = OS.low_processor_usage_mode
	OS.low_processor_usage_mode = false
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	_was_vsync = DisplayServer.window_get_vsync_mode()
	_was_max_fps = Engine.max_fps
	if _was_vsync != DisplayServer.VSYNC_DISABLED:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_quickened = true


func _settle() -> void:
	_shadow_atlas(_project_atlas())
	OS.low_processor_usage_mode = _was_low_processor
	if full_renderer():
		RenderingServer.environment_set_ssao_quality(
			int(ProjectSettings.get_setting("rendering/environment/ssao/quality", 2))
				as RenderingServer.EnvironmentSSAOQuality,
			bool(ProjectSettings.get_setting("rendering/environment/ssao/half_size", true)),
			float(ProjectSettings.get_setting("rendering/environment/ssao/adaptive_target", 0.5)),
			int(ProjectSettings.get_setting("rendering/environment/ssao/blur_passes", 2)),
			float(ProjectSettings.get_setting("rendering/environment/ssao/fadeout_from", 50.0)),
			float(ProjectSettings.get_setting("rendering/environment/ssao/fadeout_to", 300.0)))
		RenderingServer.directional_soft_shadow_filter_set_quality(
			int(ProjectSettings.get_setting(
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 2))
				as RenderingServer.ShadowQuality)
	if not _quickened:
		return
	_quickened = false
	if _was_vsync != DisplayServer.VSYNC_DISABLED:
		DisplayServer.window_set_vsync_mode(_was_vsync)
	Engine.max_fps = _was_max_fps


var _was_low_processor: bool = false
var _quickened: bool = false
var _was_vsync: int = DisplayServer.VSYNC_ENABLED
var _was_max_fps: int = 0
