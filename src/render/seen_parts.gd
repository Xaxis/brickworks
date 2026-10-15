## Which parts of a model can be seen from outside it, measured rather than
## guessed.
##
## The model is drawn from many sides, every part a flat colour that is its
## own number (seen_codes), with no perspective, at a pixel no wider than a
## part's own detail; every number in every picture is read back. A part
## whose number is in none of them cannot be seen from any of those sides:
## that is what "hidden" means here, and nothing else. A box test (what is
## in front of a part's middle) calls a brick behind a window hidden and a
## brick behind a gap between two others hidden too; the pictures do not.
##
## Each surface is culled as the app's plastic culls it (one-sided unless
## LDraw does not certify its winding), so what the pictures hide is what
## the app's own view hides: drawn from both sides, a part was called hidden
## behind a wall the app lets you see through from that side.
##
## What it draws from: the 26 directions of a cube (its faces, edges and
## corners, the sides a person turns a model to) and as many more spread
## evenly over the sphere (a Fibonacci spiral), from below as well, because
## a model is picked up; each side twice, half a pixel apart. It is a
## sample, and a part glimpsed only through a crack narrower than a pixel,
## from a side between those drawn, can be missed: docs/HIDDEN_COLOURS.md
## measures how often, against pictures from sides never drawn here. See-through plastic is not drawn, so what is
## behind glass is seen, and is itself counted as seen.
##
## The pictures are read without walking their pixels in GDScript: each is
## sorted as integers (in C++), and the distinct values are found by
## binary search from one to the next — a few thousand searches a picture
## instead of four million reads.
##
## Nothing here changes the model. HiddenColours decides what to do with
## what is hidden; src/dev/hidden_colours_probe.gd holds this to a
## picture-for-picture comparison.
class_name SeenParts
extends Node

## How many sides to look from, the cube's 26 among them. A part seen only
## through a crack, from a side between those drawn, is what a sample can
## miss; more sides, each drawn twice (SAMPLES), make that less likely. On
## seven models, eight sides drawn before and after (three never measured
## from) show no pixel changed (docs/HIDDEN_COLOURS.md).
const VIEWS := 128
## Each side drawn this many times, the camera moved half a pixel along the
## diagonal the second time: a sliver thinner than a pixel that falls
## between the first picture's samples falls on the second's.
const SAMPLES := 2
## How far below level a side may look up and still be one a person sees a
## model on a table from: six degrees. Looked at exactly level, a part's
## bottom face is edge on and drawn as a line or not at all, by rounding.
const TABLE_BELOW := -0.1
## The finest a pixel is, in LDU: under a plate's lip (4 LDU) and a
## stud's (6 across), so a gap a person can see into is a few pixels.
const FINEST := 1.0
## The most pixels a picture is across, which sets how fine a pixel is on
## a big model: 2,048 over Orthanc's 1,900 LDU is about one LDU.
const MOST_PIXELS := 2048
## And on the web, where the visitor's graphics card draws it.
const MOST_PIXELS_WEB := 1024
## How long one picture may take before the measure is given up on.
const GIVE_UP := 30.0
## Numbers a picture can tell apart (seen_codes).
const SPAN := 13823

var library: PartLibrary
## Said as it goes: (done, of).
signal progressed(done: int, of: int)
## Set to stop a measure part way: it ends incomplete.
var cancelled: bool = false

var _viewport: SubViewport
var _camera: Camera3D
var _token_rect: ColorRect
var _material: ShaderMaterial
## For the surfaces the plastic draws from both sides; [member _material]
## culls the back faces as plastic.gdshader does, so a part seen through a
## surface the app does not draw from behind is seen here too.
var _material_two_sided: ShaderMaterial
var _token: int = 0
## One measure or picture at a time: the panel and a session's call share
## the viewports, and two drawing into one read each other's pictures.
var _busy: bool = false


func _wait_turn() -> void:
	while _busy:
		await get_tree().process_frame
	_busy = true


## What a measure found.
class Result extends RefCounted:
	## World brick id -> true: seen from at least one side.
	var seen: Dictionary = {}
	## Seen from a side that is not below the model: what a person walking
	## round it on a table sees. A model is picked up and turned over too,
	## so [member seen] is what may never change; this is what a display
	## model shows, for a measure of real sets.
	var seen_on_table: Dictionary = {}
	## Every brick drawn (not see-through), world id -> true.
	var drawn: Dictionary = {}
	## See-through bricks: never in front of anything, seen by definition.
	var see_through: Dictionary = {}
	var views: int = 0
	## Pictures a side (SeenParts.SAMPLES).
	var samples: int = 1
	## LDU a pixel, the finest and the coarsest picture's.
	var finest: float = 0.0
	var coarsest: float = 0.0
	var seconds: float = 0.0
	## Every side was drawn and read. A measure that is not complete has
	## not looked everywhere, and nothing may be called hidden from it.
	var complete: bool = false
	## Per side, how many parts it showed: what a probe reads to see the
	## sides were all different pictures.
	var per_view: PackedInt32Array = PackedInt32Array()

	## The bricks drawn and seen from nowhere; with [param on_table], seen
	## from nowhere but underneath.
	func hidden(on_table: bool = false) -> Dictionary:
		var out: Dictionary = {}
		if not complete:
			return out
		var looked: Dictionary = seen_on_table if on_table else seen
		for brick_id: int in drawn:
			if not looked.has(brick_id):
				out[brick_id] = true
		return out


static func possible() -> bool:
	return DisplayServer.get_name() != "headless"


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(64, 64)
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_taa = false
	_viewport.use_debanding = false
	_viewport.positional_shadow_atlas_size = 0
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var flat := World3D.new()
	var black := Environment.new()
	black.background_mode = Environment.BG_COLOR
	black.background_color = Color(0, 0, 0)
	black.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	black.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	flat.environment = black
	_viewport.world_3d = flat
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 1.0
	_camera.far = 200000.0
	_camera.current = true
	_viewport.add_child(_camera)
	_token_rect = ColorRect.new()
	_token_rect.size = Vector2(3, 3)
	_token_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_token_rect)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/render/seen_codes.gdshader")
	_material_two_sided = ShaderMaterial.new()
	_material_two_sided.shader = preload("res://src/render/seen_codes_two_sided.gdshader")
	for material: ShaderMaterial in [_material, _material_two_sided]:
		material.set_shader_parameter("linearise",
			RenderingServer.get_current_rendering_method() != "gl_compatibility")


## The sides to look from: the cube's 26 first, then the rest of [param
## count] spread over the sphere, none nearer than eight degrees to one
## already taken.
static func directions(count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x: int in [-1, 0, 1]:
		for y: int in [-1, 0, 1]:
			for z: int in [-1, 0, 1]:
				if x != 0 or y != 0 or z != 0:
					out.append(Vector3(x, y, z).normalized())
	var golden: float = PI * (3.0 - sqrt(5.0))
	var spiral: int = maxi(count * 2, 64)
	for n: int in spiral:
		if out.size() >= count:
			break
		var y: float = 1.0 - (float(n) + 0.5) / float(spiral) * 2.0
		var r: float = sqrt(maxf(0.0, 1.0 - y * y))
		var way := Vector3(cos(golden * n) * r, y, sin(golden * n) * r)
		var near: bool = false
		for taken: Vector3 in out:
			if taken.dot(way) > cos(deg_to_rad(8.0)):
				near = true
				break
		if not near:
			out.append(way)
	return out


## The camera's axes looking from [param direction]: x across the picture,
## y up it, z back towards the camera. Straight down or up, x stays x.
static func basis_from(direction: Vector3) -> Basis:
	var back: Vector3 = direction.normalized()
	var hint: Vector3 = Vector3.UP if absf(back.y) < 0.98 else Vector3.BACK
	var across: Vector3 = hint.cross(back).normalized()
	var up: Vector3 = back.cross(across).normalized()
	return Basis(across, up, back)


## Which of [param bricks] can be seen: [[world id, part, colour,
## transform], ...]. A coroutine.
func measure(bricks: Array, count: int = VIEWS, finest: float = FINEST,
		most: int = -1, samples: int = SAMPLES) -> Result:
	await _wait_turn()
	var result := Result.new()
	var started: int = Time.get_ticks_msec()
	cancelled = false
	if most <= 0:
		most = MOST_PIXELS_WEB if OS.has_feature("web") else MOST_PIXELS
	var stage := BrickWorld.new()
	stage.library = library
	stage.keeps_history = false
	var by_number: Dictionary = {}
	var whole := AABB()
	var any: bool = false
	for entry: Array in bricks:
		var code: int = int(entry[2])
		var colour: PartLibrary.BrickColor = library.color(code)
		if colour != null and colour.is_transparent():
			result.see_through[int(entry[0])] = true
			continue
		var number: int = stage.add_brick(str(entry[1]), code, entry[3])
		if number == 0:
			continue
		by_number[number] = int(entry[0])
		result.drawn[int(entry[0])] = true
		var part: Lbm.PartMesh = library.mesh_for(str(entry[1]))
		var box: AABB = (entry[3] as Transform3D) * part.bounds
		whole = box if not any else whole.merge(box)
		any = true
	if not any:
		stage.free()
		result.complete = true
		_busy = false
		return result
	_viewport.add_child(stage)
	# A part with a window moulded in (a fixed see-through surface) is drawn
	# without it.
	for instance: MultiMeshInstance3D in stage.see_through_instances():
		instance.visible = false
	stage.draw_as(_material, func(number: int) -> Color:
		return BookletStudio.code_colour(number), _material_two_sided)
	await get_tree().process_frame

	var sides: Array[Vector3] = directions(count)
	var passes: int = ceili(float(by_number.size()) / float(SPAN))
	result.finest = INF
	result.coarsest = 0.0
	var ok: bool = true
	var done: int = 0
	for way: Vector3 in sides:
		if cancelled:
			ok = false
			break
		var pixel: float = _aim(way, whole, finest, most)
		result.finest = minf(result.finest, pixel)
		result.coarsest = maxf(result.coarsest, pixel)
		var shown: Dictionary = {}
		var on_table: bool = way.y > TABLE_BELOW
		var aimed: Transform3D = _camera.transform
		for sample: int in samples:
			# The second picture half a pixel along the diagonal.
			var shift: float = pixel * 0.5 * float(sample)
			_camera.transform = Transform3D(aimed.basis, aimed.origin
				+ (aimed.basis.x + aimed.basis.y) * shift)
			for pass_number: int in passes:
				_material.set_shader_parameter("first", float(pass_number * SPAN))
				_material_two_sided.set_shader_parameter("first", float(pass_number * SPAN))
				var image: Image = await _drawn()
				if image == null:
					ok = false
					break
				for value: int in _values(image):
					var number: int = value + pass_number * SPAN
					if by_number.has(number):
						result.seen[by_number[number]] = true
						if on_table:
							result.seen_on_table[by_number[number]] = true
						shown[number] = true
			if not ok:
				break
		if not ok:
			break
		result.per_view.append(shown.size())
		done += 1
		progressed.emit(done, sides.size())
	result.views = done
	result.samples = samples
	result.complete = ok and done == sides.size()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_material.set_shader_parameter("first", 0.0)
	_material_two_sided.set_shader_parameter("first", 0.0)
	stage.queue_free()
	result.seconds = float(Time.get_ticks_msec() - started) / 1000.0
	_busy = false
	return result


## Point the camera along [param way] at [param whole], framed with a few
## pixels to spare, a pixel [param finest] LDU or as fine as [param most]
## pixels allow. Returns the pixel's size.
func _aim(way: Vector3, whole: AABB, finest: float, most: int) -> float:
	var turn: Basis = basis_from(way)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for n: int in 8:
		var corner: Vector3 = whole.position + Vector3(
			whole.size.x if n & 1 else 0.0,
			whole.size.y if n & 2 else 0.0,
			whole.size.z if n & 4 else 0.0)
		var at := Vector2(corner.dot(turn.x), corner.dot(turn.y))
		low = low.min(at)
		high = high.max(at)
	var span: Vector2 = high - low
	var pixel: float = maxf(finest, maxf(span.x, span.y) / float(most - 24))
	var size := Vector2i(ceili(span.x / pixel) + 24, ceili(span.y / pixel) + 24)
	_viewport.size = size
	var middle: Vector2 = (low + high) * 0.5
	var reach: float = whole.size.length() + 100.0
	var depth: float = whole.get_center().dot(turn.z)
	_camera.transform = Transform3D(turn, turn.x * middle.x + turn.y * middle.y
		+ turn.z * (depth + reach))
	_camera.size = float(size.y) * pixel
	_camera.far = reach * 2.0 + 100.0
	return pixel


## The distinct numbers in a picture of codes: each pixel as an integer,
## sorted, and walked from one value to the next by binary search.
static func _values(image: Image) -> PackedInt32Array:
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	# The token in the corner is not a part.
	image.fill_rect(Rect2i(0, 0, 8, 8), Color(0, 0, 0, 1))
	var pixels: PackedInt32Array = image.get_data().to_int32_array()
	pixels.sort()
	var out := PackedInt32Array()
	var at: int = 0
	var count: int = pixels.size()
	while at < count:
		var value: int = pixels[at]
		var red: int = value & 0xFF
		var green: int = (value >> 8) & 0xFF
		var blue: int = (value >> 16) & 0xFF
		if red >= 40 and green >= 40 and blue >= 40:
			var number: int = roundi((red - 64) / 8.0) + 24 * roundi((green - 64) / 8.0) \
				+ 576 * roundi((blue - 64) / 8.0)
			if number > 0:
				out.append(number)
		at = pixels.bsearch(value + 1, true)
	return out


## Draw the codes once and hand the picture back, once it is the picture
## asked for: its corner carries a token set for it (as BookletStudio
## waits for its own), because a viewport hands back what it drew last
## until it draws again.
func _drawn(viewport: SubViewport = null, token_rect: ColorRect = null) -> Image:
	if viewport == null:
		viewport = _viewport
		token_rect = _token_rect
	_token = (_token + 1) % 81
	var colour := Color8(16 * (_token % 9) + 96, 16 * (_token / 9) + 96, 136)
	token_rect.color = colour
	var until: float = Time.get_ticks_msec() / 1000.0 + GIVE_UP
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	while Time.get_ticks_msec() / 1000.0 < until:
		await get_tree().process_frame
		var texture: ViewportTexture = viewport.get_texture()
		if texture == null:
			continue
		await GpuFence.finished()
		var image: Image = texture.get_image()
		if image == null or image.get_width() < 8:
			continue
		var got: Color = image.get_pixel(1, 1)
		if absf(got.r - colour.r) < 0.03 and absf(got.g - colour.g) < 0.03:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			return image
	push_warning("seen parts: a picture was not drawn within %d s" % int(GIVE_UP))
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return null


# -- pictures ----------------------------------------------------------------
#
# The model as it looks, in the app's own plastic, for the preview and for
# the proof that what is seen did not change: the same bricks drawn before
# and after, from the same side, compared pixel for pixel.

var _lit: SubViewport
var _lit_camera: Camera3D
var _lit_token: ColorRect


func _lit_viewport() -> void:
	if _lit != null:
		return
	_lit = SubViewport.new()
	_lit.size = Vector2i(64, 64)
	_lit.transparent_bg = false
	_lit.msaa_3d = Viewport.MSAA_DISABLED
	_lit.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_lit.use_taa = false
	_lit.positional_shadow_atlas_size = 0
	_lit.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var world := World3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.93, 0.95, 0.97)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.9, 0.91)
	environment.ambient_light_energy = BrickWorld.light_energy(0.8)
	world.environment = environment
	_lit.world_3d = world
	add_child(_lit)
	_lit_camera = Camera3D.new()
	_lit_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_lit_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_lit_camera.near = 1.0
	_lit_camera.far = 200000.0
	_lit_camera.current = true
	_lit.add_child(_lit_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50.0, -20.0, 0.0)
	key.light_energy = BrickWorld.light_energy(0.75)
	key.light_specular = BrickWorld.light_specular(0.15)
	_lit.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 140.0, 0.0)
	fill.light_energy = BrickWorld.light_energy(0.3)
	fill.light_specular = 0.0
	_lit.add_child(fill)
	_lit_token = ColorRect.new()
	_lit_token.size = Vector2(3, 3)
	_lit_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lit.add_child(_lit_token)


## [param bricks] as they are and with [param changes] (brick id -> colour),
## from [param from], drawn in one world with only the colours changed in
## between (BrickWorld.repaint_in_place): [before, after]. Two worlds built
## alike still draw in their own order, and on the seams where two parts'
## faces lie in one plane the order decides which shows; the Colosseum's
## base differed by 122 pixels between two worlds of the same bricks.
func pictures(bricks: Array, changes: Dictionary, from: Vector3, frame: AABB,
		most: int = 900, cut: bool = false, plane: Plane = Plane()) -> Array:
	_lit_viewport()
	await _wait_turn()
	var stage := BrickWorld.new()
	stage.library = library
	stage.keeps_history = false
	# What the stage numbers each brick, which it may not place at all.
	var number_of: Dictionary = {}
	for entry: Array in bricks:
		var number: int = stage.add_brick(str(entry[1]), int(entry[2]), entry[3])
		if number != 0:
			number_of[int(entry[0])] = number
	_lit.add_child(stage)
	if cut:
		stage.set_cut(true, plane)
	await get_tree().process_frame
	_frame_lit(from, frame, most)
	var was: Image = await _drawn(_lit, _lit_token)
	var by_number: Dictionary = {}
	for id: int in changes:
		if number_of.has(id):
			by_number[number_of[id]] = int(changes[id])
	stage.repaint_in_place(by_number)
	await get_tree().process_frame
	var now: Image = await _drawn(_lit, _lit_token)
	stage.queue_free()
	_busy = false
	var out: Array = []
	for image: Image in [was, now]:
		if image != null:
			if image.get_format() != Image.FORMAT_RGBA8:
				image.convert(Image.FORMAT_RGBA8)
			image.fill_rect(Rect2i(0, 0, 8, 8), Color(0.93, 0.95, 0.97))
		out.append(image)
	return out


## The lit camera along [param from], framed on [param frame], at most
## [param most] pixels across.
func _frame_lit(from: Vector3, frame: AABB, most: int) -> void:
	var turn: Basis = basis_from(from)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for n: int in 8:
		var corner: Vector3 = frame.position + Vector3(
			frame.size.x if n & 1 else 0.0,
			frame.size.y if n & 2 else 0.0,
			frame.size.z if n & 4 else 0.0)
		var at := Vector2(corner.dot(turn.x), corner.dot(turn.y))
		low = low.min(at)
		high = high.max(at)
	var span: Vector2 = high - low
	var pixel: float = maxf(span.x, span.y) / float(most - 24)
	var size := Vector2i(ceili(span.x / pixel) + 24, ceili(span.y / pixel) + 24)
	_lit.size = size
	var middle: Vector2 = (low + high) * 0.5
	var reach: float = frame.size.length() + 100.0
	_lit_camera.transform = Transform3D(turn, turn.x * middle.x + turn.y * middle.y
		+ turn.z * (frame.get_center().dot(turn.z) + reach))
	_lit_camera.size = float(size.y) * pixel
	_lit_camera.far = reach * 2.0 + 100.0


## [param bricks] ([[id, part, colour, transform], ...]) as they look from
## [param from], at most [param most] pixels across, framed on [param
## frame] (the whole model's box, so pictures of one model line up). With
## [param cut] on, everything on the side the plane's normal points to is
## cut away (BrickWorld.set_cut), the faces it cuts drawn as faces: the
## inside, seen. The token's corner is painted over; a coroutine.
func picture(bricks: Array, from: Vector3, frame: AABB, most: int = 900,
		cut: bool = false, plane: Plane = Plane()) -> Image:
	_lit_viewport()
	await _wait_turn()
	var stage := BrickWorld.new()
	stage.library = library
	stage.keeps_history = false
	for entry: Array in bricks:
		stage.add_brick(str(entry[1]), int(entry[2]), entry[3])
	_lit.add_child(stage)
	if cut:
		stage.set_cut(true, plane)
	await get_tree().process_frame
	var turn: Basis = basis_from(from)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for n: int in 8:
		var corner: Vector3 = frame.position + Vector3(
			frame.size.x if n & 1 else 0.0,
			frame.size.y if n & 2 else 0.0,
			frame.size.z if n & 4 else 0.0)
		var at := Vector2(corner.dot(turn.x), corner.dot(turn.y))
		low = low.min(at)
		high = high.max(at)
	var span: Vector2 = high - low
	var pixel: float = maxf(span.x, span.y) / float(most - 24)
	var size := Vector2i(ceili(span.x / pixel) + 24, ceili(span.y / pixel) + 24)
	_lit.size = size
	var middle: Vector2 = (low + high) * 0.5
	var reach: float = frame.size.length() + 100.0
	_lit_camera.transform = Transform3D(turn, turn.x * middle.x + turn.y * middle.y
		+ turn.z * (frame.get_center().dot(turn.z) + reach))
	_lit_camera.size = float(size.y) * pixel
	_lit_camera.far = reach * 2.0 + 100.0
	var image: Image = await _drawn(_lit, _lit_token)
	stage.queue_free()
	_busy = false
	if image == null:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, 8, 8), Color(0.93, 0.95, 0.97))
	return image
