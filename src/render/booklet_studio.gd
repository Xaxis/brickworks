## The booklet's camera: pictures of the model drawn the way a printed
## booklet draws them.
##
## The booklet used to photograph the main window — the person's own view,
## baseplate and sky and all — hiding the interface and moving their camera
## while it did. A printed step is a different picture: the model alone on
## the page, from one fixed angle with no perspective, every part outlined
## in ink, at a size chosen for the page it is printed on. So it is drawn
## here, off screen, into three viewports of its own:
##
##   colour  the model as it looks, in its own lights, on nothing
##   codes   every brick a flat colour that is its number (booklet_codes)
##   ink     the two together: a line wherever the number changes
##           (booklet_ink), which is the picture that goes on the page
##
## Bricks are put on a stage in the order the booklet builds them, so the
## picture after any step is the first so many bricks (BrickWorld.show_first)
## and costs the same at step 1 as at step 1,000.
##
## The codes also say what can be seen. A step whose new parts are hidden
## behind the model is a step nobody can follow, and the way a real
## booklet fixes it is to turn the model round; [method seen] measures how
## much of a step's new parts the picture shows against how much of them
## there is, which is what decides when to turn.
class_name BookletStudio
extends Node

## The angle every step is drawn from: from the front and to the right,
## thirty degrees up, the way a booklet stands a model on the page.
const FRONT := Vector3(0.62, 0.68, 1.0)
## Turned round to the back, for a step whose parts are behind.
const BACK := Vector3(-0.62, 0.68, -1.0)

## How long one picture may take before it is given up on, in seconds.
const GIVE_UP := 20.0

var library: PartLibrary
## Drawn larger and scaled down: the codes cannot be anti-aliased (a blend
## of two numbers is a third), so the smooth line comes from drawing at
## twice the size. One on the web, where the GPU is whatever the visitor has.
var supersample: int = 2
## Outline the parts a step adds in a band of their own colour (booklet_ink);
## see Booklet.
var mark_new: bool = false
## Fade the picture to the page over this many of its own pixels at the
## edges, for a picture whose model runs off them; 0 for none.
var fade: float = 0.0
## How strongly to draw the creases inside a part: see booklet_ink.
var crease: float = 1.0

var _colour: SubViewport
var _codes: SubViewport
var _ink: SubViewport
var _colour_camera: Camera3D
var _codes_camera: Camera3D
var _ink_rect: ColorRect
var _ink_material: ShaderMaterial
var _code_material: ShaderMaterial
var _colour_token: ColorRect
var _codes_token: ColorRect
var _token: int = 0
var _stages: Array[Stage] = []
## The codes' world's light, which is none: see [method measure_all].
var _flat: Environment
var _lanes: Array[Lane] = []


## A stage: the same bricks twice, once in the colour world and once in
## the codes world, numbered in the order they are built.
class Stage extends RefCounted:
	var colour: BrickWorld
	var codes: BrickWorld
	## World brick id -> number on this stage, from 1.
	var number: Dictionary = {}
	var count: int = 0
	## Each brick's box, by number, for framing without asking the world.
	var boxes: Array[AABB] = []


## What a picture shows, read off its codes.
class Shot extends RefCounted:
	var image: Image
	## What [method shoot]'s [code]finish[/code] made of the picture.
	var made: Variant = null
	## The worker reading the picture, and cutting it down, until
	## [method finished] says it is done; -1 when there is none.
	var task: int = -1
	## Where the model is in the picture, in its pixels, and where the new
	## parts are. Empty when there are none.
	var model_rect: Rect2 = Rect2()
	var new_rect: Rect2 = Rect2()


## How to point the camera: the direction it looks from, the point of
## the view plane at the centre of the picture, and how many pixels a
## unit of the model is.
class View extends RefCounted:
	var from: Vector3 = FRONT
	var centre: Vector2 = Vector2.ZERO
	var scale: float = 1.0

	func _init(direction: Vector3 = FRONT, middle: Vector2 = Vector2.ZERO,
			pixels_per_ldu: float = 1.0) -> void:
		from = direction
		centre = middle
		scale = pixels_per_ldu

	func basis() -> Basis:
		return BookletStudio.basis_for(from)

	## Where a point of the model lands in a picture [param size] across.
	func project(point: Vector3, size: Vector2) -> Vector2:
		var turn: Basis = basis()
		return Vector2(
			size.x * 0.5 + (point.dot(turn.x) - centre.x) * scale,
			size.y * 0.5 - (point.dot(turn.y) - centre.y) * scale)


## The camera's axes for a view from [param direction]: x across the
## picture, y up it, z back towards the camera.
static func basis_for(direction: Vector3) -> Basis:
	var back: Vector3 = direction.normalized()
	var across: Vector3 = Vector3.UP.cross(back).normalized()
	var up: Vector3 = back.cross(across).normalized()
	return Basis(across, up, back)


## The rectangle a set of boxes covers on the view plane, in model units,
## y up.
static func extent(boxes: Array, direction: Vector3) -> Rect2:
	var turn: Basis = basis_for(direction)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for box: AABB in boxes:
		for n: int in 8:
			var corner: Vector3 = box.position + Vector3(
				box.size.x if n & 1 else 0.0,
				box.size.y if n & 2 else 0.0,
				box.size.z if n & 4 else 0.0)
			var at := Vector2(corner.dot(turn.x), corner.dot(turn.y))
			low = low.min(at)
			high = high.max(at)
	if low.x > high.x:
		return Rect2()
	return Rect2(low, high - low)


func _ready() -> void:
	if OS.has_feature("web"):
		supersample = 1
	_colour = _viewport(true)
	var world := World3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	# Flatter than the main view's light: a booklet is read, not admired,
	# and a face in deep shadow is a face whose colour cannot be told.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.9, 0.91)
	environment.ambient_light_energy = BrickWorld.light_energy(0.8)
	world.environment = environment
	_colour.world_3d = world
	add_child(_colour)
	_colour_camera = _camera()
	_colour.add_child(_colour_camera)
	# The key from over the reader's left shoulder, so the tops are the
	# lightest faces and the side facing right the darkest, as in print.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50.0, -20.0, 0.0)
	key.light_energy = BrickWorld.light_energy(0.75)
	key.light_specular = BrickWorld.light_specular(0.15)
	_colour.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 140.0, 0.0)
	fill.light_energy = BrickWorld.light_energy(0.3)
	fill.light_specular = 0.0
	_colour.add_child(fill)
	_colour_token = _token_rect()
	_colour.add_child(_colour_token)

	_codes = _viewport(false)
	var flat := World3D.new()
	var black := Environment.new()
	_flat = black
	black.background_mode = Environment.BG_COLOR
	black.background_color = Color(0, 0, 0)
	black.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	black.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	flat.environment = black
	_codes.world_3d = flat
	add_child(_codes)
	_codes_camera = _camera()
	_codes.add_child(_codes_camera)
	_codes_token = _token_rect()
	_codes.add_child(_codes_token)
	_code_material = ShaderMaterial.new()
	_code_material.shader = preload("res://src/render/booklet_codes.gdshader")
	_code_material.set_shader_parameter("linearise",
		RenderingServer.get_current_rendering_method() != "gl_compatibility")

	_ink = SubViewport.new()
	_ink.transparent_bg = true
	_ink.disable_3d = true
	_ink.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_ink)
	_ink_rect = ColorRect.new()
	_ink_material = ShaderMaterial.new()
	_ink_material.shader = preload("res://src/render/booklet_ink.gdshader")
	_ink_material.set_shader_parameter("colour_tex", _colour.get_texture())
	_ink_material.set_shader_parameter("code_tex", _codes.get_texture())
	_ink_rect.material = _ink_material
	_ink.add_child(_ink_rect)


func _viewport(lit: bool) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.transparent_bg = lit
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	viewport.use_debanding = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.positional_shadow_atlas_size = 0
	return viewport


func _camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 1.0
	camera.far = 200000.0
	camera.current = true
	return camera


func _token_rect() -> ColorRect:
	var rect := ColorRect.new()
	rect.position = Vector2.ZERO
	rect.size = Vector2(3, 3)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Put bricks on a new stage, in the order given, which is the order the
## pictures reveal them in. [param bricks] is [[world id, part, colour,
## transform], ...]. Returns the stage; [method forget] takes it down.
func stage(bricks: Array) -> Stage:
	var made := Stage.new()
	made.colour = BrickWorld.new()
	made.colour.library = library
	made.codes = BrickWorld.new()
	made.codes.library = library
	for entry: Array in bricks:
		var id: int = made.colour.add_brick(str(entry[1]), int(entry[2]), entry[3])
		if id == 0:
			continue
		made.codes.add_brick(str(entry[1]), int(entry[2]), entry[3])
		made.count += 1
		made.number[int(entry[0])] = made.count
		var part: Lbm.PartMesh = library.mesh_for(str(entry[1]))
		made.boxes.append((entry[3] as Transform3D) * part.bounds)
	_colour.add_child(made.colour)
	_codes.add_child(made.codes)
	made.codes.draw_as(_code_material, func(number: int) -> Color:
		return code_colour(number))
	made.colour.visible = false
	made.codes.visible = false
	_stages.append(made)
	return made


func forget(made: Stage) -> void:
	_stages.erase(made)
	made.colour.queue_free()
	made.codes.queue_free()
	for lane: Lane in _lanes:
		if lane.twins.has(made):
			var twin: Twin = lane.twins[made]
			twin.in_codes.queue_free()
			twin.in_alone.queue_free()
			lane.twins.erase(made)


## The colour that is brick [param number]'s code: see booklet_codes.
static func code_colour(number: int) -> Color:
	var low: int = number % 16384
	var high: int = mini(number / 16384, 31)
	return Color(
		(float(low % 32) * 8.0 + 4.0) / 255.0,
		(float((low / 32) % 32) * 8.0 + 4.0) / 255.0,
		(float((low / 1024) * 2) * 8.0 + 4.0) / 255.0,
		(float(high) * 8.0 + 4.0) / 255.0)


## Draw [param made] with its first [param upto] bricks showing, those
## numbered from [param new_from] on marked as new, from [param view],
## [param size] pixels. How much of the new parts a view shows is
## [method measure_all]'s.
##
## A picture is read back here, and what comes of it is worked out on a
## worker thread ([method finished] waits for it): where the model and the
## new parts are, the picture cut down to [param size], and [param finish]
## (Image -> anything, in [member Shot.made]), which is how the maker
## turns it into a JPEG. That was a tenth of a second a picture on the one
## thread, three quarters of a castle's booklet, while the card waited.
func shoot(made: Stage, upto: int, new_from: int, view: View, size: Vector2i,
		finish: Callable = Callable()) -> Shot:
	var shot := Shot.new()
	var big: Vector2i = size * supersample
	_aim(made, upto, new_from, view, big)
	_ink.size = big
	_ink_rect.size = Vector2(big)
	_ink_material.set_shader_parameter("pixel", Vector2(1.0 / big.x, 1.0 / big.y))
	# A third of a millimetre of ink at the booklet's resolution.
	_ink_material.set_shader_parameter("ink", maxf(2.0, 1.5 * supersample))
	_ink_material.set_shader_parameter("mark_new", mark_new and new_from <= upto)
	# A band of about two thirds of a millimetre round the new parts.
	_ink_material.set_shader_parameter("halo", maxf(3.0, 3.0 * supersample))
	_ink_material.set_shader_parameter("fade", fade * supersample)
	_ink_material.set_shader_parameter("crease", crease)

	_colour.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_codes.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ink.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var drawn: Image = await _drawn(_ink, [Vector2i(1, 1), Vector2i(4, 1)],
		[_codes_token.color, _colour_token.color])
	var codes: Image = _codes.get_texture().get_image() if drawn != null else null
	_colour.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_codes.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_ink.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if drawn == null:
		return shot
	shot.task = WorkerThreadPool.add_task(
		_develop.bind(shot, drawn, codes, size, supersample, finish), false,
		"booklet picture")
	return shot


## Until [param shot]'s worker is done with it, the window going on meanwhile.
func finished(shot: Shot) -> void:
	if shot.task < 0:
		return
	# A build without threads does the work when it is waited for.
	while OS.has_feature("threads") and not WorkerThreadPool.is_task_completed(shot.task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(shot.task)
	shot.task = -1


# -- measuring many views at once ---------------------------------------------


## How many views [method measure_all] draws in one frame.
const LANES := 8


## A pair of code pictures of its own, for [method measure_all]: the codes
## as [method shoot] draws them, and the new parts alone, both drawn in one
## frame, with a copy of each stage it has measured on.
class Lane extends RefCounted:
	var codes: SubViewport
	var alone: SubViewport
	var codes_camera: Camera3D
	var alone_camera: Camera3D
	var codes_token: ColorRect
	var alone_token: ColorRect
	var codes_material: ShaderMaterial
	var alone_material: ShaderMaterial
	## Stage -> Twin.
	var twins: Dictionary = {}


## A stage's codes drawn in a lane: its batches' MultiMeshes copied, each
## drawn twice, once in either of the lane's pictures.
class Twin extends RefCounted:
	var multimeshes: Array[MultiMesh] = []
	var ids: Array[PackedInt64Array] = []
	var in_codes: Node3D
	var in_alone: Node3D

	## As BrickWorld.show_first.
	func show_first(upto: int) -> void:
		for index: int in multimeshes.size():
			multimeshes[index].visible_instance_count = ids[index].bsearch(upto)


## How much of each step's new parts each of [param asks] shows, as
## the share of their pixels the picture shows against what they would
## cover with nothing in front: 1 is all in view, 0 hidden, -1 when it could
## not be drawn. Asks are [[stage, upto, new_from, view, size], ...], and
## the answers come back in their order.
##
## Measured one at a time, each took two frames, one for the picture and
## one for its new parts alone, and a castle's 400 steps took 23 s on the
## desktop's card, nearly all of it waiting for frames. Here [constant
## LANES] are drawn in a frame, both pictures of each at once, each as a
## mask the engine counts (_count_marked).
func measure_all(asks: Array) -> Array:
	var out: Array = []
	out.resize(asks.size())
	out.fill(-1.0)
	var at: int = 0
	while at < asks.size():
		var count: int = mini(LANES, asks.size() - at)
		var tokens: Array = []
		for index: int in count:
			tokens.append(_aim_lane(_lane(index), asks[at + index]))
		var until: int = Time.get_ticks_msec() + int(GIVE_UP * 1000.0)
		var pictures: Array = []
		pictures.resize(count * 2)
		var left: int = count
		while left > 0 and Time.get_ticks_msec() < until:
			await get_tree().process_frame
			await GpuFence.finished()
			for index: int in count:
				if pictures[index * 2] != null:
					continue
				var lane: Lane = _lanes[index]
				var codes: Image = _fresh(lane.codes, tokens[index])
				var alone: Image = _fresh(lane.alone, tokens[index]) if codes != null else null
				if codes == null or alone == null:
					continue
				pictures[index * 2] = codes
				pictures[index * 2 + 1] = alone
				lane.codes.render_target_update_mode = SubViewport.UPDATE_DISABLED
				lane.alone.render_target_update_mode = SubViewport.UPDATE_DISABLED
				left -= 1
		if left > 0:
			push_warning("booklet: a picture was not drawn within %d s" % int(GIVE_UP))
		for index: int in count:
			if pictures[index * 2] == null:
				continue
			var ask: Array = asks[at + index]
			var whole: int = _count_marked(pictures[index * 2 + 1])
			if int(ask[2]) > int(ask[1]) or whole == 0:
				out[at + index] = 1.0
			else:
				out[at + index] = clampf(float(_count_marked(pictures[index * 2]))
					/ float(whole), 0.0, 1.0)
		for index: int in count:
			_lanes[index].codes.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_lanes[index].alone.render_target_update_mode = SubViewport.UPDATE_DISABLED
		at += count
	return out


func _lane(index: int) -> Lane:
	while _lanes.size() <= index:
		var lane := Lane.new()
		lane.codes_material = _code_material.duplicate()
		lane.alone_material = _code_material.duplicate()
		lane.alone_material.set_shader_parameter("only_new", true)
		for material: ShaderMaterial in [lane.codes_material, lane.alone_material]:
			material.set_shader_parameter("mask", true)
		for which: int in 2:
			var viewport: SubViewport = _viewport(false)
			viewport.world_3d = World3D.new()
			viewport.world_3d.environment = _flat
			add_child(viewport)
			var camera: Camera3D = _camera()
			viewport.add_child(camera)
			var token: ColorRect = _token_rect()
			viewport.add_child(token)
			if which == 0:
				lane.codes = viewport
				lane.codes_camera = camera
				lane.codes_token = token
			else:
				lane.alone = viewport
				lane.alone_camera = camera
				lane.alone_token = token
		_lanes.append(lane)
	return _lanes[index]


## Set [param lane] to draw [param ask] (see [method measure_all]); the
## token its pictures will carry.
func _aim_lane(lane: Lane, ask: Array) -> Color:
	var made: Stage = ask[0]
	var big: Vector2i = (ask[4] as Vector2i) * supersample
	if not lane.twins.has(made):
		lane.twins[made] = _twin(lane, made)
	for other: Stage in lane.twins:
		var twin: Twin = lane.twins[other]
		twin.in_codes.visible = other == made
		twin.in_alone.visible = other == made
	(lane.twins[made] as Twin).show_first(int(ask[1]) + 1)
	for material: ShaderMaterial in [lane.codes_material, lane.alone_material]:
		material.set_shader_parameter("new_from", float(ask[2]))
	for viewport: SubViewport in [lane.codes, lane.alone]:
		viewport.size = big
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for camera: Camera3D in [lane.codes_camera, lane.alone_camera]:
		_point(camera, made, ask[3], big)
	_bump_token()
	lane.codes_token.color = _codes_token.color
	lane.alone_token.color = _codes_token.color
	return _codes_token.color


func _twin(lane: Lane, made: Stage) -> Twin:
	var twin := Twin.new()
	twin.in_codes = Node3D.new()
	twin.in_alone = Node3D.new()
	for drawn: Array in made.codes.drawing():
		var source: MultiMesh = drawn[0]
		var copy := MultiMesh.new()
		copy.transform_format = source.transform_format
		copy.use_colors = source.use_colors
		copy.use_custom_data = source.use_custom_data
		copy.mesh = source.mesh
		copy.instance_count = source.instance_count
		copy.buffer = source.buffer
		for pair: Array in [[twin.in_codes, lane.codes_material],
				[twin.in_alone, lane.alone_material]]:
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = copy
			instance.material_override = pair[1]
			instance.custom_aabb = drawn[2]
			(pair[0] as Node3D).add_child(instance)
		twin.multimeshes.append(copy)
		twin.ids.append(drawn[1])
	lane.codes.add_child(twin.in_codes)
	lane.alone.add_child(twin.in_alone)
	return twin


## The new pixels of a picture drawn as a mask (booklet_codes' mask),
## every other one of every other row from the fifth, as they were counted
## off the codes one by one. Counted by the engine, every other pixel taken
## by halving it, nearest: in a loop here, a castle's views were three
## seconds of counting. Halving takes the second of each two, so the
## picture is moved a pixel in first.
static func _count_marked(mask: Image) -> int:
	var width: int = mask.get_width()
	var height: int = mask.get_height()
	if width % 2 == 1 or height % 2 == 1 or height < 6:
		var count: int = 0
		for y: int in range(4, height, 2):
			for x: int in range(0, width, 2):
				if mask.get_pixel(x, y).r > 0.5:
					count += 1
		return count
	var moved := Image.create(width + 2, height + 2, false, mask.get_format())
	moved.blit_rect(mask, Rect2i(Vector2i.ZERO, mask.get_size()), Vector2i(1, 1))
	moved.resize(width / 2 + 1, height / 2 + 1, Image.INTERPOLATE_NEAREST)
	var half: Image = moved.get_region(Rect2i(0, 2, width / 2, height / 2 - 2))
	half.convert(Image.FORMAT_L8)
	return half.get_data().count(255)


## [param viewport]'s picture when it carries [param token], else null.
static func _fresh(viewport: SubViewport, token: Color) -> Image:
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.get_width() < 8:
		return null
	var got: Color = image.get_pixel(1, 1)
	if absf(got.r - token.r) > 0.03 or absf(got.g - token.g) > 0.03:
		return null
	return image


## On a worker: [method shoot]'s picture read, cut down and finished.
static func _develop(shot: Shot, drawn: Image, codes: Image, size: Vector2i,
		times: int, finish: Callable) -> void:
	_read_rects(codes, shot, 1.0 / float(times))
	# The tokens out of the corner, then down to the size asked for.
	if drawn.get_format() != Image.FORMAT_RGBA8:
		drawn.convert(Image.FORMAT_RGBA8)
	drawn.fill_rect(Rect2i(0, 0, 12, 12), Color(0, 0, 0, 0))
	if times > 1:
		drawn.resize(size.x, size.y, Image.INTERPOLATE_CUBIC)
	shot.image = drawn
	if finish.is_valid():
		shot.made = finish.call(drawn)


## Read a pixel of the codes as booklet_codes wrote it: a brick when every
## channel is 64 or more, new when blue's level is odd.
static func _is_brick(data: PackedByteArray, at: int) -> bool:
	return data[at] >= 40 and data[at + 1] >= 40 and data[at + 2] >= 40


static func _is_new(data: PackedByteArray, at: int) -> bool:
	return _is_brick(data, at) and ((data[at + 2] - 60) >> 3) & 1 == 1


## Where the model and the new parts are, read off the codes at a
## sixth of their size: a walk over every pixel of a page-sized picture
## in GDScript was a second and a half a step, most of a castle's ten
## minutes.
static func _read_rects(full: Image, shot: Shot, factor: float) -> void:
	const SHRINK := 6
	var codes: Image = full.duplicate()
	codes.resize(maxi(1, full.get_width() / SHRINK), maxi(1, full.get_height() / SHRINK),
		Image.INTERPOLATE_NEAREST)
	factor *= float(full.get_width()) / float(codes.get_width())
	var data: PackedByteArray = codes.get_data()
	var width: int = codes.get_width()
	var height: int = codes.get_height()
	var channels: int = 4 if codes.get_format() == Image.FORMAT_RGBA8 else 3
	var low := Vector2i(width, height)
	var high := Vector2i(-1, -1)
	var new_low := Vector2i(width, height)
	var new_high := Vector2i(-1, -1)
	var stride: int = 1
	for y: int in range(1, height, stride):
		var row: int = y * width * channels
		for x: int in range(0, width, stride):
			var at: int = row + x * channels
			if not _is_brick(data, at):
				continue
			low = Vector2i(mini(low.x, x), mini(low.y, y))
			high = Vector2i(maxi(high.x, x), maxi(high.y, y))
			if _is_new(data, at):
				new_low = Vector2i(mini(new_low.x, x), mini(new_low.y, y))
				new_high = Vector2i(maxi(new_high.x, x), maxi(new_high.y, y))
	if high.x >= 0:
		shot.model_rect = Rect2(Vector2(low) * factor, Vector2(high - low + Vector2i.ONE) * factor)
	if new_high.x >= 0:
		shot.new_rect = Rect2(Vector2(new_low) * factor,
			Vector2(new_high - new_low + Vector2i.ONE) * factor)


func _aim(made: Stage, upto: int, new_from: int, view: View, big: Vector2i) -> void:
	for other: Stage in _stages:
		other.colour.visible = other == made
		other.codes.visible = other == made
	made.colour.show_first(upto + 1)
	made.codes.show_first(upto + 1)
	_code_material.set_shader_parameter("new_from", float(new_from))
	_colour.size = big
	_codes.size = big
	for camera: Camera3D in [_colour_camera, _codes_camera]:
		_point(camera, made, view, big)
	_bump_token()


## Point [param camera] at [param made] from [param view], for a picture
## [param big] pixels.
func _point(camera: Camera3D, made: Stage, view: View, big: Vector2i) -> void:
	var turn: Basis = view.basis()
	var reach: float = 0.0
	var middle := Vector3.ZERO
	if not made.boxes.is_empty():
		var whole: AABB = made.boxes[0]
		for box: AABB in made.boxes:
			whole = whole.merge(box)
		reach = whole.size.length() + 1000.0
		middle = whole.get_center()
	var at: Vector3 = (turn.x * view.centre.x + turn.y * view.centre.y
		+ turn.z * (middle.dot(turn.z) + reach))
	camera.transform = Transform3D(turn, at)
	camera.size = float(big.y) / (view.scale * float(supersample))
	camera.far = reach * 2.0 + 1000.0


func _bump_token() -> void:
	# Light values only: see booklet_codes for what the dark ones go through.
	_token = (_token + 1) % 81
	var colour := Color8(16 * (_token % 9) + 96, 16 * (_token / 9) + 96, 136)
	_colour_token.color = colour
	_codes_token.color = colour


## Wait for [param viewport] to draw the picture asked for: its corner
## pixels carry the tokens set for it. A viewport hands back whatever it
## drew last until it draws again, and a picture of the step before,
## offered as this one, is exactly the error nobody would notice.
func _drawn(viewport: SubViewport, spots: Array, tokens: Array) -> Image:
	var until: float = Time.get_ticks_msec() / 1000.0 + GIVE_UP
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	while Time.get_ticks_msec() / 1000.0 < until:
		await get_tree().process_frame
		var texture: ViewportTexture = viewport.get_texture()
		if texture == null:
			continue
		# Read back once the card has drawn it, with nothing more drawn
		# meanwhile (GpuFence, as ModelShot reads): sooner, the read waits
		# for it on the page's one thread, and in a browser drawing in
		# software the car's booklet held the page three seconds a picture,
		# and seventeen for the first when frames were queued ahead of it.
		await GpuFence.finished()
		var image: Image = texture.get_image()
		if image == null or image.get_width() < 8:
			continue
		var fresh: bool = true
		for index: int in spots.size():
			var spot: Vector2i = spots[index]
			var got: Color = image.get_pixel(spot.x, spot.y)
			var want: Color = tokens[index]
			if absf(got.r - want.r) > 0.03 or absf(got.g - want.g) > 0.03:
				fresh = false
		if fresh:
			# Both tokens are read from this picture, so the two passes it
			# was drawn from had both drawn what was asked for.
			return image
	push_warning("booklet: a picture was not drawn within %d s" % int(GIVE_UP))
	return null
