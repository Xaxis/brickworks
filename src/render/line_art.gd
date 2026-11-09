## The Line art and Comic looks (RenderSettings.look "lineart" and "comic",
## APP_UX7 #22): the model drawn as a person inks it, to colour over or to
## print, as BUF3D's line and comic looks draw a model and no LEGO CAD does.
##
## Line art is black lines on white paper, the shade in halftone dots: an
## outline round the model, a line where each part meets the next (so a
## wall's bricks can be counted, as in a booklet), a finer one where a
## part's surface turns a corner, and dots that grow where the light leaves
## a face and on the floor under it. Comic is the same lines and dots over
## the plastic's own colours, flat, a shade darker away from the light.
## Either on the backdrop's colour or on nothing (RenderSettings.transparent).
##
## StudioRender draws the model twice in the set as it stands, as the window
## draws it (one frame, as Quick does: the lines and the dots are the
## picture, so a grade adds nothing to them, and the draft is the picture):
## lit, for the shadow it casts on the floor, and in its own colours with no
## light (flat), prints and all. This keeps a copy of the model of its own
## beside the render's, on a layer no camera of the set's sees, drawn three
## times more: each part a flat colour that is its number (booklet_codes),
## which way each face looks (line_normals), and all of it white clay in the
## set's light, so the light on a black part and on a white one are drawn
## alike (the window lights black plastic a third as much, for its own
## colour, as white). line_art.gdshader makes the picture of the five.
##
## The window's own look and the product look never come here: their
## pictures are drawn as they were, to the pixel.
class_name LineArt
extends Node

const INK := preload("res://src/render/line_art.gdshader")
const CODES := preload("res://src/render/booklet_codes.gdshader")
const NORMALS := preload("res://src/render/line_normals.gdshader")
## The looks drawn here, of RenderSettings.LOOKS.
const LOOKS: Array[String] = ["lineart", "comic"]
## The copy's own layer: the set's camera draws 1 and 2, the floor's 1, and
## StudioRender's warm-up 1 << 19.
const LAYER := 1 << 18
## A part's line across, as a share of the picture's short side (2.4 pixels
## at 1080p), never thinner than this many pixels (a line between two parts
## a pixel either side of where they meet, solid); the halftone's cell the
## same way (7.2 at 1080p), about a newspaper's 65 lines an inch with the
## picture printed A5.
const INK_SHARE := 1.0 / 450.0
const THINNEST := 2.0
const CELL_SHARE := 1.0 / 150.0
const SMALLEST_CELL := 4.0

## The copy: every part where the render's stage has it, a number each.
var stage: BrickWorld
## Brick id on the render's stage -> on the copy.
var ids: Dictionary = {}
var codes_view: SubViewport
var normals_view: SubViewport
var light_view: SubViewport
var ink_view: SubViewport

var _for: Array = []
var _codes_camera: Camera3D
var _normals_camera: Camera3D
var _light_camera: Camera3D
var _codes: ShaderMaterial
var _normals: ShaderMaterial
var _clay: StandardMaterial3D
var _ink: ShaderMaterial
## The flat picture's light: the plastic's colour and nothing else.
var flat_light: Environment


## Whether [param look] is drawn here.
static func drawn_in_lines(look: String) -> bool:
	return look in LOOKS


## Every look a render takes, in words, as a session is told them.
static func looks_in_words() -> String:
	var names: Array = RenderSettings.LOOKS.keys()
	return ", ".join(names.slice(0, names.size() - 1)) + " or " + str(names[-1])


## What the set draws for [param asked], a line look: the same shot, one
## frame, sharp, on nothing (the paper is put round it here).
static func underneath(asked: RenderSettings) -> RenderSettings:
	var drawn: RenderSettings = asked.copy()
	drawn.quality = RenderSettings.Quality.QUICK
	drawn.transparent = true
	drawn.f_stop = 0.0
	return drawn


## Made once, in [param world] (the set's), the copy under [param parent],
## which turns with the model.
func setup(world: World3D, parent: Node3D, library: PartLibrary) -> void:
	var linear: bool = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	_codes = ShaderMaterial.new()
	_codes.shader = CODES
	_codes.set_shader_parameter("linearise", linear)
	_normals = ShaderMaterial.new()
	_normals.shader = NORMALS
	_normals.set_shader_parameter("linearise", linear)
	var plain := Environment.new()
	plain.background_mode = Environment.BG_COLOR
	plain.background_color = Color(0, 0, 0)
	plain.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	plain.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	plain.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	codes_view = _view_3d(world, "LineCodes")
	_codes_camera = _camera_in(codes_view, plain)
	normals_view = _view_3d(world, "LineNormals")
	_normals_camera = _camera_in(normals_view, plain)
	# The clay: white, matt, no glint, both sides of a face drawn as the
	# plastic's are; in the set's light and its shadows (the render's own
	# stage casts them, and this copy is where it is).
	_clay = StandardMaterial3D.new()
	_clay.albedo_color = Color(1, 1, 1)
	_clay.roughness = 1.0
	_clay.metallic_specular = 0.0
	_clay.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_clay.cull_mode = BaseMaterial3D.CULL_DISABLED
	light_view = _view_3d(world, "LineLight")
	_light_camera = _camera_in(light_view, null)

	flat_light = Environment.new()
	flat_light.background_mode = Environment.BG_CLEAR_COLOR
	flat_light.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	flat_light.ambient_light_color = Color(1, 1, 1)
	flat_light.ambient_light_energy = BrickWorld.light_energy(1.0)
	flat_light.ambient_light_sky_contribution = 0.0
	flat_light.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	flat_light.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	flat_light.tonemap_exposure = 1.0

	ink_view = SubViewport.new()
	ink_view.name = "LineInk"
	ink_view.transparent_bg = true
	ink_view.disable_3d = true
	ink_view.gui_disable_input = true
	ink_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	ink_view.size = Vector2i(8, 8)
	add_child(ink_view)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink = ShaderMaterial.new()
	_ink.shader = INK
	_ink.set_shader_parameter("code_tex", codes_view.get_texture())
	_ink.set_shader_parameter("normal_tex", normals_view.get_texture())
	_ink.set_shader_parameter("light_tex", light_view.get_texture())
	rect.material = _ink
	ink_view.add_child(rect)

	stage = BrickWorld.new()
	stage.name = "LineStage"
	stage.library = library
	stage.keeps_history = false
	stage.visible = false
	parent.add_child(stage)


func _view_3d(world: World3D, called: String) -> SubViewport:
	var view := SubViewport.new()
	view.name = called
	view.world_3d = world
	view.transparent_bg = false
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	view.use_taa = false
	view.use_debanding = false
	view.positional_shadow_atlas_size = 0
	view.gui_disable_input = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.size = Vector2i(8, 8)
	add_child(view)
	return view


func _camera_in(view: SubViewport, environment: Environment) -> Camera3D:
	var camera := Camera3D.new()
	camera.cull_mask = LAYER
	camera.environment = environment
	view.add_child(camera)
	camera.current = true
	return camera


## The copy made of [param from], the render's stage, unless it is already
## of the staging [param key]; a slice a frame (FramePace). False if
## [param cancelled] says so meanwhile.
func stage_from(from: BrickWorld, key: Array, cancelled: Callable) -> bool:
	if key == _for and not key.is_empty():
		return true
	_for = []
	ids.clear()
	stage.clear()
	stage.hold_drawing()
	var pace := FramePace.new()
	for brick: BrickWorld.Brick in from.bricks():
		if pace.due():
			await pace.next()
			if cancelled.call():
				stage.release_drawing()
				return false
		ids[brick.id] = stage.add_brick(brick.part_id, brick.color_code, brick.transform)
	stage.release_drawing()
	await get_tree().process_frame
	_for = key
	return true


## Forget the copy: it is made again for the next line picture.
func forget() -> void:
	_for = []


## A part of the render's stage moved, for an animation's frame: its copy too.
func move(staged: int, to: Transform3D) -> void:
	var twin: int = int(ids.get(staged, 0))
	if twin != 0:
		stage.move_brick(twin, to)


## Ready to draw the codes from where [param camera] (the set's, in
## [param scene]) looks, at [param size]: the copy shown where the stage is
## ([param placed], under the same turn), on its own layer, its parts in
## their numbers.
func before_codes(camera: Camera3D, scene: SubViewport, size: Vector2i,
		placed: Transform3D) -> void:
	stage.transform = placed
	for view: SubViewport in [codes_view, normals_view, light_view]:
		if view.size != size:
			view.size = size
	for twin: Camera3D in [_codes_camera, _normals_camera, _light_camera]:
		twin.global_transform = camera.global_transform
		twin.set_frustum(camera.size, camera.frustum_offset, camera.near, camera.far)
	_light_camera.environment = camera.environment
	_light_camera.attributes = camera.attributes
	light_view.positional_shadow_atlas_size = scene.positional_shadow_atlas_size
	stage.draw_as(_codes, func(brick_id: int) -> Color:
		return BookletStudio.code_colour(brick_id))
	for child: Node in stage.get_children():
		var batch := child as MultiMeshInstance3D
		if batch != null:
			batch.layers = LAYER
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	stage.visible = true


## Then which way every face looks.
func before_normals() -> void:
	for child: Node in stage.get_children():
		var batch := child as MultiMeshInstance3D
		if batch != null:
			batch.material_override = _normals


## Then all of it in clay, in the set's light.
func before_light() -> void:
	for child: Node in stage.get_children():
		var batch := child as MultiMeshInstance3D
		if batch != null:
			batch.material_override = _clay


## The copy out of every picture again.
func after() -> void:
	stage.visible = false


## The ink drawn for one piece of a picture [param asked] for: [param lit]
## and [param flat] the set's two pictures of it, [param size] across, its
## first pixel at [param at] in a picture [param picture] across.
func before_ink(lit: Texture2D, flat: Texture2D, asked: RenderSettings, picture: Vector2i,
		at: Vector2i, size: Vector2i) -> void:
	if ink_view.size != size:
		ink_view.size = size
	_ink.set_shader_parameter("lit_tex", lit)
	_ink.set_shader_parameter("flat_tex", flat)
	_ink.set_shader_parameter("pixel", Vector2(1.0 / float(size.x), 1.0 / float(size.y)))
	_ink.set_shader_parameter("origin", Vector2(at))
	var tall: float = float(mini(picture.x, picture.y))
	_ink.set_shader_parameter("ink", maxf(THINNEST, tall * INK_SHARE))
	_ink.set_shader_parameter("cell", maxf(SMALLEST_CELL, tall * CELL_SHARE))
	_ink.set_shader_parameter("comic", asked.look == "comic")
	var backdrop: Color = asked.backdrop
	_ink.set_shader_parameter("paper", Vector4(backdrop.r, backdrop.g, backdrop.b,
		0.0 if asked.transparent else 1.0))
