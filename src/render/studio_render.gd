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
## And two looks. "window" draws the plastic as the window does. "product"
## (RenderSettings.look) is a product shot's: the copy of the model drawn in
## plastic_body's PLASTIC_PRODUCT shaders (a gloss over the plastic, edges
## rounded where they catch the light, chrome and metal reflecting the
## studio, clear parts that tint what is behind them), lit by a key, a fill
## and a rim over a softbox studio's own light (an HDR panorama, which is
## also what everything glossy reflects), with screen-space bounce light
## and reflections on the desktop, and graded through AgX, a film-like
## tone curve, rather than ACES. The window itself is never touched: its
## plastic, its environment and its frame cost are the same either way.
## docs/RENDERING.md says what it reaches and what is left.
##
## And the lights placed in the model (SceneLights: bulbs, spots, suns and
## panels, BrickWorld.scene_lights) over the set, rasterised as Godot's own
## lights and path traced as lights of the tracer's, the same strength and
## the same cone in both. The exposure is metered without them, as a
## photographer meters the set and then adds a lamp: what a spot lights is
## brighter, and nothing outside its cone changes. In the Dark light
## (RenderSettings.lighting "dark") the studio is put out, its ambient
## lowered to a glimmer, and the model's lights are all there is, with the
## plastics that glow (glow-in-the-dark and the neons) drawn as light, as
## Studio's Eyesight draws them: lit from within, and lighting what is
## round them.
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
## An animation's frame [param n] about to be drawn from [param shot]
## ([method animate]): where its camera stands and its lens, frame by frame.
signal frame_shot(n: int, shot: Shot)

const SUM := preload("res://src/render/studio_sum.gdshader")
const RESOLVE := preload("res://src/render/studio_resolve.gdshader")
const COPY := preload("res://src/render/studio_copy.gdshader")
const BACKDROP := preload("res://src/render/studio_backdrop.gdshader")
const CONTACT := preload("res://src/render/studio_contact.gdshader")
const STUDIO_SKY := preload("res://src/render/studio_sky.gdshader")

## Real places to light the model with: Poly Haven's, CC0, recorded in
## docs/ATTRIBUTION.md. Key -> [words, file].
const HDRIS: Dictionary = {
	"softbox": ["Softbox studio", "res://assets/hdri/studio_small_09.hdr"],
	"window": ["Window light", "res://assets/hdri/photo_studio_loft_hall.hdr"],
	"daylight": ["Daylight", "res://assets/hdri/kloofendal_48d_partly_cloudy_puresky.hdr"],
}

## A photograph's staging (photoreal7, RenderSettings.stage), Best path traced
## in the product look: what the model stands on, lit as any surface is
## rather than drawn at its colour round the model's shadow, and a key that
## stands near the model, so its light falls off across the model and the
## surface as a real light's does (docs/RENDERING.md 5k). Key -> [words, a
## photographed tile of the surface ("" for a grain of the tracer's own), the
## tile's size (LDU: 1 mm is 2.5), how rough it is, its grain (0 a paper's
## fibres, 1 a desk's specks, 2 the tile), whether it is a table (flat, and
## the room beyond it seen past its edge), its own colour (sRGB), how deep
## its relief is (LDU, the tile's alpha its height)]. Tiles are Poly Haven's
## diffuse with its displacement in alpha, CC0 (docs/ATTRIBUTION.md). "white" is a product shot's white
## seamless, kept at its colour round the model as before: only its light
## is the near key's.
const STAGES: Dictionary = {
	"white": ["Photographed on white", "", 0.0, 0.9, 0, false, Color(1, 1, 1), 0.0],
	"paper": ["On paper", "", 0.0, 0.9, 0, false, Color(0.93, 0.925, 0.91), 0.0],
	"desk": ["On a desk", "", 0.0, 0.8, 1, true, Color(0.77, 0.74, 0.68), 0.0],
	"wood": ["On a wooden table", "res://assets/surfaces/oak_veneer_01.webp", 4575.0, 0.45, 2, true,
		Color(0.62, 0.45, 0.3), 0.2],
	"leather": ["On a leather desk pad", "res://assets/surfaces/leather_white.webp", 750.0, 0.55, 2,
		true, Color(0.36, 0.34, 0.32), 0.6],
	"terrazzo": ["On terrazzo", "res://assets/surfaces/terrazzo_tiles.webp", 5000.0, 0.3, 2, true,
		Color(0.45, 0.38, 0.32), 1.0],
}
## The staged key (photoreal7), where a render asks for none of its own
## (RenderSettings key_rise, key_far, key_size, key_share): how high it
## stands (degrees), how far from the model's middle and how big (in the
## model's radii), and how bright against the room's light (as the tent's
## key, TENT_KEY, is 1). Fitted to the photo bench's photographs
## (photoreal_probe --keys and tools/photoreal/fit_light.py, docs/RENDERING.md 5k).
const STAGE_KEY_RISE := 40.0
const STAGE_KEY_FAR := 4.0
const STAGE_KEY_SIZE := 1.0
const STAGE_KEY_SHARE := 2.0
## How a staged key's light falls off its axis: the power of the cosine
## (a softbox's face sends most of its light straight ahead).
const STAGE_KEY_BEAM := 2.0
## The room a staged table stands in, when the studio's light is asked for:
## a room's light through its windows, not a tent.
const STAGE_ROOM := "window"

## How much grain one traced sample carries, relative to its level, for the
## product look's denoise (path_tracer_resolve.glsl): a pixel differing from
## its neighbour by many times this over the root of the samples is an edge.
const PRODUCT_DENOISE := 5.0
## The product look's camera and wear (photoreal4), where a render asks for
## none of its own (RenderSettings grain, vignette, aberration, softness,
## age, dust, paper, seating): measured against the photo bench's photographs, each kept only
## where a measure moved (docs/RENDERING.md 5h).
const PRODUCT_GRAIN := 0.0
const PRODUCT_VIGNETTE := 0.0
const PRODUCT_ABERRATION := 0.0
const PRODUCT_AGE := 0.0
const PRODUCT_DUST := 0.3
const PRODUCT_PAPER := 0.0
const PRODUCT_SOFTNESS := 0.6
const PRODUCT_SEATING := 1.0
## The camera's processing (photoreal6, RenderSettings sharpen and jpeg):
## none of its own, so a render is the light as drawn unless asked for.
const PRODUCT_SHARPEN := 0.0
const PRODUCT_JPEG := 0.0
## The camera's tone and white balance (photoreal7, RenderSettings tone and
## balance), staged or not: its tone curve's S, and how much of the white
## card's cast its white balance takes out. Both lifted the close-ups in two
## judge runs (the red slope from 0.44 to 0.67) and cost the sets nothing
## (docs/RENDERING.md 5k).
const PRODUCT_TONE := 0.5
const PRODUCT_BALANCE := 1.0
## No two parts alike (photoreal8, RenderSettings batch, handling, studs and
## play): each part's colour batch, how much each has been handled, each
## stud's logo, and each part's seat, no further apart than the photographed
## parts are. Judged on the photo bench one at a time and together
## (docs/RENDERING.md 5l): batch, studs and play each lifted the close-ups
## beyond the judge's noise and are the product look's own; handling lifted
## the sets a little and lowered the close-ups more, so it is 0.
const PRODUCT_BATCH := 1.0
const PRODUCT_HANDLING := 0.0
const PRODUCT_STUDS := 1.0
const PRODUCT_PLAY := 1.0
## Handled wear gathered where fingers and stacking touch (photoreal9,
## RenderSettings.rubbed). 0 unless asked: in four pools beside the
## photographs it lifted the close-ups by 0.025 on the mean, within the
## judge's noise (the black 2x4 every time, the grey 1x3 down every time),
## and the sets not at all (docs/RENDERING.md 5m).
const PRODUCT_RUBBED := 0.0
## The stage matched to the photographs by measure (photoreal10,
## docs/RENDERING.md 5n), each 0 unless asked until judged: the table's own
## relief (RenderSettings.table), the light falling off across it
## (table_light, the model's radii) and the shade's fill tinted as daylight
## (fill).
const PRODUCT_TABLE := 0.0
const PRODUCT_TABLE_LIGHT := 0.0
const PRODUCT_FILL := 0.0
## Moulded edges (photoreal13, RenderSettings.edge; docs/RENDERING.md 5q):
## judged alone beside the photographs against this tree without it, the
## solo judge called more renders photographs (16 of 80 against 11), so on.
const PRODUCT_EDGE := 1.0
## The large source the glossy tops mirror (photoreal14, RenderSettings
## source and source_*; path_tracer.glsl's source_light): a bright window
## behind the model with the table's own key nearly gone, as a photograph by
## a window has it. On a table under the studio's light by default
## (PRODUCT_SOURCE, at SOURCE_LEVEL): judged by the fixed judge (photoreal16,
## a fresh blind name a verdict; docs/RENDERING.md 5t) it lifted every table
## close-up in every draw, 12 pictures of 12 (the grey brick 0.12 to 0.82, the
## black 0.28 to 0.61), +0.35 over the shots it changes (95%: +0.04 to
## +0.69). photoreal14b's "led by 0.012 and 0.022" was the old judge, whose
## kept names froze one draw a picture. In the tent it lost the red slope, so
## the seamless never has one. Its
## light in the sky's units; where its middle stands
## (round from straight behind the model as the camera sees it, in degrees;
## and up, where a flat top mirrors it: as high as the camera looks down,
## kept within SOURCE_RISE_LOW and SOURCE_RISE_HIGH and its lower edge above
## the floor); how big it is seen from the model (degrees), how soft its
## edges are (a share of its half size), how much darker its edges are than
## its middle, and how much of a staged table's near key stays beside it.
const SOURCE_LEVEL := 128.0
const PRODUCT_SOURCE := SOURCE_LEVEL
const SOURCE_RISE_LOW := 15.0
const SOURCE_RISE_HIGH := 65.0
const SOURCE_TURN := 0.0
const SOURCE_WIDE := 90.0
const SOURCE_TALL := 50.0
const SOURCE_EDGE := 0.04
const SOURCE_FALL := 0.0
const SOURCE_KEY := 0.05
## How much of the source a staged table mirrors (photoreal14b, RenderSettings
## source_spill): none. It is lit by it as the white card is, so it keeps its
## own colour; mirrored whole, its glare drew wood and terrazzo nearly white.
const SOURCE_SPILL := 0.0
## Moulded ABS's own unevenness (photoreal15, RenderSettings peel, sink,
## polish and scuff; path_tracer.glsl's peeled, sunk, polish_split and
## sparse_scuffs): each 0 unless asked until the photo bench's judge keeps it.
const PRODUCT_PEEL := 0.0
const PRODUCT_SINK := 0.0
const PRODUCT_POLISH := 0.0
const PRODUCT_SCUFF := 0.0
## A set photographed (photoreal19, RenderSettings.floor; path_tracer.glsl's
## photo version): the floor a product photograph's set stands on, on the
## bare seamless (glossy, exposed past white, its shade cool and coloured
## by the model; [method _floor_of] says where). On: the solo judge called the sweep's shots photographs
## more often with it in both classes, the sets +0.012 (95%: +0.003 to
## +0.021) and the close-ups +0.025 (+0.001 to +0.059), docs/RENDERING.md 5u.
const PRODUCT_FLOOR := 1.0

## The most one traced sample of the product look may give, in what its
## exposure draws as white (path_tracer.glsl): brighter is white whatever,
## and was a sparkle in a mean of 256.
const PRODUCT_MOST := 3.0

## Best's product look in the studio on a light backdrop is a light tent
## (photoreal2, path_tracer.glsl's tent()): white walls all round and a soft
## panel overhead this many times brighter, in place of the rig's hard key,
## whose shadow drew a crescent inside every stud that no product photograph
## has. A dark backdrop keeps the rig's pool of light.
const TENT_TOP := 6.0
## The tent's key (photoreal2): a soft box this bright at its face, against
## the panel's 1 and the walls' TENT_FILL (path_tracer.glsl), this many
## radians from its middle to its edge. A photograph's tent is never even:
## the red slope's photograph has its lit face five times its shaded end.
const TENT_KEY := 2.5
const TENT_KEY_SPREAD := 0.45
## The tent's two soft boxes (photoreal3, path_tracer.glsl's tent_box): wide
## boxes behind the model to each side, this bright against the walls'
## TENT_FILL. They are what a glossy part mirrors: its stud rims, edges and
## logo flanks show them as a photograph's do.
const TENT_BOX := 8.0
## How light a backdrop is at least to be a tent's paper rather than a pool
## of light, and to be the photograph's white the exposure is metered to.
const TENT_BACKDROP := 0.2
const PAPER_WHITE := 0.8
## The product look on a backdrop, path traced, drawn as a camera draws
## (photoreal2): a white card where the model stands is exposed to the
## paper's own light this many stops over (a product photograph's paper is
## exposed a little past white), the camera saturates the light by
## PHOTO_LINEAR_SATURATION as its colour matrix does, and its response is
## path_tracer_resolve.glsl's camera_curve, whose knee and top these are.
## LDraw's colours, which the plastic keeps exactly as the file says, came
## out duller than a camera draws the same parts. All four were fitted to
## the tent close-ups' photographs from the tracer's raw light
## (tools/bench/photoreal.py colour, docs/RENDERING.md 5f).
const PHOTO_EV := 0.33
const PHOTO_LINEAR_SATURATION := 1.3
const CAMERA_KNEE := 0.6
const CAMERA_TOP := 2.5

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
## The product look's key, fill and rim, as RIG: the key the window's own,
## a fill low on the camera's left, and a rim from behind and above that
## draws a line of light along every top edge and stud.
const PRODUCT_RIG: Array = [
	[Vector3(0.479, 0.659, 0.579), 1.0, true, 0.5, Color(1, 0.98, 0.95)],
	[Vector3(-0.93, 0.355, 0.087), 0.32, false, 0.15, Color(0.94, 0.96, 1.0)],
	[Vector3(0.62, 0.66, -0.425), 0.55, false, 1.0, Color(1, 1, 1)],
]
## The softbox studio the product look's plastic reflects and is lit by,
## when no photographed place is chosen.
const PRODUCT_SKY := "softbox"
## How far the product look's sweep falls away, from under the model to the
## edge of the picture: a gradient's, and a dark backdrop's pool of light.
const FALL_GRADIENT := 0.42
const FALL_DARK := 0.8
## How much of the softbox studio's room the product look's plastic
## reflects, its softboxes left whole (studio_sky.gdshader): the black flags
## round a glossy subject that keep black black.
const PRODUCT_ROOM := 0.2
## The product look's grade: Filmic's white, the saturation and contrast
## put back after it, and its exposure against the window's. Set on
## swatches of each colour on the white sweep at Good, read off the face
## the key lights (product_render_probe). At white 6, saturation 1.18 and
## contrast 1.06 a white brick came out #dbdad7 and green #1aa033 (LDraw's
## #f4f4f4 and #00852b). Brighter than this and red, blue and green ran
## past their colours while white still came up short: a film curve
## compresses white against a saturated colour, so the two are traded.
const PRODUCT_WHITE := 4.0
const PRODUCT_SATURATION := 1.08
const PRODUCT_CONTRAST := 1.03
const PRODUCT_EXPOSURE := 0.7

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
## The Dark light (lights): its ambient under Forward+, a glimmer where the
## window's is 0.24, and how much of its colour the backdrop keeps beyond the
## sweep, where no light reaches.
const DARK_AMBIENT := 0.025
const DARK_BACKDROP := 0.04
## How much light a glowing plastic gives off in the Dark light, as radiance
## in the window's units times its colour: the plastic shaders' glow and the
## tracer's emission. A 1 x 1 brick of it lights a face beside it about as
## the window's key does.
const GLOW := 2.0
## The rasterised glow: a light at each lump of glowing parts, this many LDU
## across at most, and at most this many of them, the brightest.
const GLOW_CELL := 80.0
const GLOW_LIGHTS := 12
## The Dark light under Compatibility (the web's), calibrated against
## Forward+'s picture: its exposure, and its lamps' energy over what
## BrickWorld.light_energy gives them. Compatibility adds light in sRGB, so a
## lamp that lights a dark set is far dimmer there than under Forward+,
## whose sRGB rises steepest out of black: the car under one sun of the
## model's own was a quarter as light (lreview, 2026-11-07). Measured on the
## card through zink, the picture's mean (Forward+ / Compatibility before /
## after): the car in the dark 18.4 / 9.9 / 22.6, under one sun 103.7 / 24.0
## / 109.2, under four 162.3 / 48.8 / 166.5 (with [method _suns_share]);
## the neon grid in the dark 171.2 / 127.3 / 175.3, and under eight bulbs
## 174.9 / 117.6 / 175.6 (the glow keeps its own lights, [method
## _glows_allowed]), and the floor eight bulbs light beside the white grid
## 64.6 / 15.7 / 64.7. Of the 24 pairs tried (exposure 1 to 3, lamps 1 to
## 14), none brought both one sun and four within 15% without the suns'
## share.
const DARK_COMPAT_EXPOSURE := 2.0
const DARK_COMPAT_LAMPS := 4.0

## The model, in the world being rendered, and what of it is not the model:
## the floor's baseplate, which a render leaves out for the studio's own
## floor. A plate made part of the model is the model, and is rendered.
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
## The lights placed in the model, on the set as it stands (SceneLights):
## what holds them turns and moves with the model's copy, and each light
## carries the light it is and its reach as meta, for the tracer
## (_traced_scene). And the rasterised glow's lights, in the Dark light.
var _lamps: Node3D
var _lamp_nodes: Array[Light3D] = []
var _glow_nodes: Array[OmniLight3D] = []
## How much the glowing plastics give off in the picture being drawn: GLOW in
## the Dark light, nothing otherwise.
var _glow: float = 0.0
var _floor_view: SubViewport
var _fence: SubViewport
var _floor_camera: Camera3D

var _staged: Array = []
var _bounds := AABB()
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
		Wake.rest(self)
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


## Keep the last path-traced picture's light before its exposure and tone
## curve (PathTracer.mean_image) in [member last_mean], with the exposure it
## was drawn at in [member last_drawn_at]: the photo bench's colour measure.
var keep_mean: bool = false
var last_mean: Image = null
var last_drawn_at: float = 0.0
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
	## Path traced (PathTracer): samples are passes of the tracer, every
	## pixel one sample a pass, and nothing of the raster's is drawn.
	var traced: bool = false


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
			if settings.traced_here():
				plan.traced = true
				plan.key_spread = KEY_SPREAD
				plan.lens = settings.f_stop > 0.0
				return plan
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
	set_process(true)
	_cancelled = false
	worst_frame_ms = 0.0
	worst_step = ""
	_quicken()
	settings = _drawn_in_lines(settings)
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
	set_process(true)
	_cancelled = false
	worst_frame_ms = 0.0
	worst_step = ""
	_quicken()
	settings = _drawn_in_lines(settings)
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
## drawn, all of them unless cancelled. [param swept] is the points the
## moving parts pass through (each one's corners, every frame): with
## [member RenderSettings.on_what_moves] the camera is fitted to them, which
## a box's corners far off the parts' own would leave small in the frame.
## [param framed_at] (frame -> [AABB in the model's place, float]) is what
## each frame is framed on and how far it has settled into the view chosen,
## the camera following it (_follow): a building video's what is built so
## far. [param camera_at] (frame -> [where the camera stands, its lens
## top to bottom in degrees, how far off what it looks at], or null) is a
## motion's camera keys (camerakeys): that frame drawn from exactly there,
## the model unturned; null, as the settings frame it.
func animate(world: BrickWorld, settings: RenderSettings, frames: int, pose_at: Callable,
		turn_at: Callable, reach: AABB, each: Callable,
		swept: PackedVector3Array = PackedVector3Array(),
		framed_at: Callable = Callable(), camera_at: Callable = Callable()) -> int:
	if _busy or not possible() or world == null:
		return 0
	_busy = true
	set_process(true)
	_cancelled = false
	worst_frame_ms = 0.0
	worst_step = ""
	_quicken()
	settings = _drawn_in_lines(settings)
	var done: int = 0
	_reach = reach
	_swept = swept
	var turning: bool = false
	for n: int in frames:
		if not is_zero_approx(float(turn_at.call(n))):
			turning = true
			break
	# Followed, each frame is fitted as the model stands turned then: the
	# circle a turn sweeps is not framed.
	var following: bool = framed_at.is_valid()
	if await _prepare(world, settings, turning and not following):
		var whole: Shot = last_shot
		for n: int in maxi(frames, 1):
			var poses: Dictionary = pose_at.call(n)
			for brick_id: Variant in poses:
				var staged: int = int(_staged_ids.get(int(brick_id), 0))
				if staged != 0:
					_stage.move_brick(staged, poses[brick_id])
					if _line_asked != null:
						_line.move(staged, poses[brick_id])
			_stage._flush()
			_pivot.rotation = Vector3(0.0, TAU * float(turn_at.call(n)), 0.0)
			if following:
				var framed: Array = framed_at.call(n)
				_follow(whole, settings, framed[0], float(framed[1]))
			if camera_at.is_valid():
				var keyed: Variant = camera_at.call(n)
				last_shot = keyed_shot(settings, keyed) if keyed is Array else whole
				_shadow_reach(last_shot, _bounds)
			frame_shot.emit(n, last_shot)
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
		if following or camera_at.is_valid():
			last_shot = whole
			_shadow_reach(whole, _bounds)
	_pivot.rotation = Vector3.ZERO
	_reach = AABB()
	_swept = PackedVector3Array()
	# The copy on the stage stands as the last frame did, not as the model
	# does: copied again next time.
	_staged = []
	if _line != null:
		_line.forget()
	_finish()
	return done


## The shot of a camera key (camerakeys): [param keyed] is [where the
## camera stands (the window's coordinates, as the stage has them), its lens
## top to bottom in degrees, how far off what it looks at]. From exactly
## there, through that lens: the clip planes round the model as [method aim]
## puts them, and the focus on what it looks at.
func keyed_shot(settings: RenderSettings, keyed: Array) -> Shot:
	var at: Transform3D = keyed[0]
	var shot := Shot.new()
	shot.basis = at.basis.orthonormalized()
	shot.origin = at.origin
	shot.fov = clampf(float(keyed[1]), 1.0, 170.0)
	var nearest: float = INF
	var farthest: float = 0.0
	for n: int in 8:
		var depth: float = (_corner(_bounds, n) - shot.origin).dot(-shot.basis.z)
		nearest = minf(nearest, depth)
		farthest = maxf(farthest, depth)
	shot.near = clampf(nearest * 0.5, 0.5, 200.0)
	shot.far = maxf(farthest, 1.0) + _bounds.size.length() * 0.5 * 90.0
	shot.focus_distance = maxf(float(keyed[2]), shot.near * 2.0)
	if settings.f_stop > 0.0:
		shot.aperture = settings.focal_mm / settings.f_stop * 0.5 / 0.4
	var along: Vector3 = Vector3(shot.basis.z.x, 0.0, shot.basis.z.z)
	if along.length() < 0.2:
		along = Vector3(-shot.basis.y.x, 0.0, -shot.basis.y.z)
	shot.toward = along.normalized() if along.length() > 0.0001 else Vector3.BACK
	shot.heading = atan2(shot.toward.x, shot.toward.z)
	return shot


## The camera for a frame framed on [param box] (part of the model, where
## it stands in the model) as [method animate]'s framed_at says: a building
## video's first step fills the picture, and the camera draws back as the
## model goes up, to [param whole], the picture's own, once the whole model
## is built and turned back. From [param whole]'s direction, through its
## lens, fitted to the box as the model stands turned in this frame; then,
## by [param settled] (0 to 1), as the view chosen frames the whole beyond
## a fit (As I see it and a saved view are a person's own framing, not
## fitted), so the last frames are the picture's. The shadows are drawn as
## far as this frame's camera needs, so a step close up has the sharp
## shadows a picture of it would.
func _follow(whole: Shot, settings: RenderSettings, box: AABB, settled: float) -> void:
	var turned: float = _pivot.rotation.y
	if box.size == Vector3.ZERO or (box.is_equal_approx(_bounds) and is_zero_approx(turned)
			and is_equal_approx(settled, 1.0)):
		last_shot = whole
		_shadow_reach(whole, _bounds)
		return
	var aspect: float = float(settings.size.x) / float(maxi(settings.size.y, 1))
	var turn := Basis(Vector3.UP, turned)
	var around: Vector3 = _pivot.position
	var points := PackedVector3Array()
	var everything := PackedVector3Array()
	for n: int in 8:
		points.append(around + turn * (_corner(box, n) - around))
		everything.append(_corner(_bounds, n))
	var centre: Vector3 = around + turn * (box.get_center() - around)
	var fitted_whole: Vector3 = _fit_points(whole.basis, everything, whole.fov, aspect)
	var fitted: Vector3 = _fit_points(whole.basis, points, whole.fov, aspect)
	var shot := Shot.new()
	shot.basis = whole.basis
	shot.fov = whole.fov
	shot.aperture = whole.aperture
	shot.heading = whole.heading
	shot.toward = whole.toward
	shot.far = whole.far
	shot.origin = fitted + (whole.origin - fitted_whole) * clampf(settled, 0.0, 1.0)
	var nearest: float = INF
	var farthest: float = 0.0
	for point: Vector3 in points:
		var depth: float = (point - shot.origin).dot(-shot.basis.z)
		nearest = minf(nearest, depth)
		farthest = maxf(farthest, depth)
	# A quarter of the way, not half: a part coming down from above comes
	# towards a camera looking down.
	shot.near = clampf(nearest * 0.25, 0.5, 200.0)
	shot.focus_distance = maxf(lerpf(nearest, farthest, clampf(settings.focus, 0.0, 1.0)),
		shot.near * 2.0)
	last_shot = shot
	_shadow_reach(shot, AABB(centre - box.size * 0.5, box.size))


## The lights' shadows drawn as far from [param shot]'s camera as
## [param box] needs, as _dress has them for the whole model.
func _shadow_reach(shot: Shot, box: AABB) -> void:
	var reach: float = (shot.origin - box.get_center()).length() + box.size.length() * 0.5 * 2.5
	for light: DirectionalLight3D in _lights:
		light.directional_shadow_max_distance = reach
	_sky_light.directional_shadow_max_distance = reach


## The box an animation's moving parts sweep, framed with the model.
var _reach := AABB()
## The points they pass through, for a frame fitted to them alone.
var _swept := PackedVector3Array()
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
	_line_asked = null
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
	_lamps = Node3D.new()
	_lamps.name = "Lamps"
	_pivot.add_child(_lamps)
	# Room for the lamps' shadows, each a share of it: the default's 2048
	# split eight ways blurred a spot's shadow in a 1080p picture.
	_scene.positional_shadow_atlas_size = 2048 if OS.has_feature("web") else 4096

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
		await _finished()
	await _draw([_sums[0]])
	_doing("setting up the viewports")
	var probe: Image = await _read(_sums[0])
	_floats = probe != null and probe.get_format() in [Image.FORMAT_RGBAF, Image.FORMAT_RGBAH,
		Image.FORMAT_RGBF, Image.FORMAT_RGBH]
	for n: int in 2:
		_sum_materials[n].set_shader_parameter("floats", _floats)
	_resolve_material.set_shader_parameter("floats", _floats)


## Whether [method warm_up] is under way; whether nobody is using the window
## (its argument), and whether a render is waiting for it.
var _warming: bool = false
var _idle: Callable
var _wanted: bool = false
## While warming up: whether nothing had changed but the set when it last
## took up again after a wait, so that what it has changed since is the
## set's alone, and drawn alone (see [method _draw_alone]).
var _alone: bool = false


## The set made ready ahead of the first render, the window's first open of
## Render included: its viewports made, and the sweep and the contact shadow
## drawn once, on a frame of their own.
##
## Under Compatibility (every browser) a shader is built in the frame that
## first draws it, and one the engine has never drawn is built four ways at
## once the first time it is drawn at all, whatever it is drawn for (its
## colour and depth passes, instanced and not), and then the way it is being
## drawn: the sweep's first draw was six programs in one frame of the first
## open, its slowest (136-140 ms on a lightly loaded box, 2026-10-17,
## tools/web/render_open_check.mjs), and the contact shadow's five.
## Drawn here first, each alone and the card left to finish each (see
## [method _warm]), the open has one program left to build for each, the
## way the render lights it. On the desktop (Forward+) the set's shaders are
## compiled the first time they are used, which on a machine that has never
## rendered held the open's first frame 90-133 ms.
##
## The dialog asks for this once nobody has touched the window for a while
## and nothing on it has changed (RenderDialog._warm_when_idle), and
## [param idle] says whether that is still so: each step waits until it is.
func warm_up(idle: Callable) -> void:
	if not possible() or _busy or _built or _warming:
		return
	_warming = true
	_idle = idle
	_look()
	await _build()
	# Their shapes as a render makes them (see _dress and _contact_shadow),
	# taken away again after: a mesh left on the contact shadow is the
	# shadow of a model already drawn.
	_backdrop.mesh = _sweep(100.0, 160.0, 1000.0)
	_contact.mesh = PlaneMesh.new()
	await _draw([_scene])
	_backdrop.mesh = null
	_contact.mesh = null
	if _alone:
		_draw_alone([])
	_alone = false
	_step = ""
	_warming = false
	_wanted = false
	warmed_up = true


## Whether [method warm_up] has run to its end: the set's viewports made and
## each thing in it drawn once the way the window's light draws it.
var warmed_up: bool = false


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
	await _finished()
	return view.get_texture().get_image()


## The card left to finish what it was asked (GpuFence). While warming up,
## what the set has changed since it last looked is drawn alone first:
## otherwise the window draws a frame of its own for it once the wait ends.
func _finished() -> void:
	if _alone:
		_draw_alone([])
	await GpuFence.finished()
	_look()


## Taken up again after a wait: whether what changes from here is the set's
## alone (see [member _alone]).
func _look() -> void:
	_alone = _warming and not _wanted and not RenderingServer.has_changed()


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
	var lights: Array[Light3D] = []
	lights.append_array(_lights)
	lights.append(_sky_light)
	# And the model's own (SceneLights), whose kinds build programs of their own.
	lights.append_array(_lamp_nodes)
	lights.append_array(_glow_nodes)
	var seen: Array[int] = []
	var lighting: Array[int] = []
	for light: Light3D in lights:
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
		await _finished()
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
	for light: Light3D in _lamp_nodes:
		lights.append("%s%d" % [light.get_class().left(1), int(light.shadow_enabled)])
	lights.append("g%d" % _glow_nodes.size())
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
	# Made ready ahead of time only while nobody is using the window: one
	# who starts to meanwhile is not given its frames, unless a render is
	# waiting on it. And only while nothing else wants a frame of it: the
	# set is then drawn alone (_draw_alone). FrameBudget's look draws
	# frames on purpose, and the set drawn while it looked held each of its
	# frames apart, one a hold: over Orthanc in software it was never
	# judged until the set was ready, 40 s in (2026-10-19).
	if _warming and not _wanted and not (_alone and _idle.call()):
		while _warming and not _wanted and not (_idle.call() and not RenderingServer.has_changed()):
			await get_tree().process_frame
		_look()
	var names := PackedStringArray()
	for view: SubViewport in views:
		names.append(str(view.name))
	_doing("drawing %s at %s" % [",".join(names), str((views[0] as SubViewport).size)])
	if _alone and _warming and not _wanted:
		_draw_alone(views)
		return true
	for view: SubViewport in views:
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var drawn: int = Engine.get_frames_drawn()
	while Engine.get_frames_drawn() == drawn:
		await get_tree().process_frame
		if _cancelled:
			return false
	_look()
	return true


## Whether the window is left out of the frames until its next one begins
## (see [method _draw_alone]).
static var _window_left_out: bool = false


## Made ready ahead of time, these viewports are drawn now and alone: not
## in a frame of the window.
##
## Each was a frame of the whole window, model and all, for a set eight
## pixels square. Over Orthanc in Chromium on SwiftShader the warm-up's six
## frames each held the page 1 to 5 s for the window's model, a frame at the
## end of each hold, with nobody touching it: the frames
## tools/web/outline_check.mjs counted standing still, put down to the
## parts bin (2026-10-19). So this one draw is forced here with the
## window's viewport left out, and the window is put back as its next frame
## begins (frame_pre_draw comes before anything is drawn); the screen shows
## what it showed meanwhile. Only when nothing but the set has changed since
## the window's last frame ([member _alone]): a change of the window's
## waiting to be drawn is a frame of it anyway, and these are drawn in it,
## as before. Called with no viewports, it draws what the set changed and
## nothing, so that the window does not draw a frame for that either.
##
## Not a frame of the window: the frame signals are held for it, so what
## times or waits on the window's frames (FrameBudget, OwnFrames) does not
## take it for one, and Engine's count of frames drawn stays as it was.
static func _draw_alone(views: Array) -> void:
	var window: RID = (Engine.get_main_loop() as SceneTree).root.get_viewport_rid()
	for view: SubViewport in views:
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.viewport_set_update_mode(window, RenderingServer.VIEWPORT_UPDATE_DISABLED)
	RenderingServer.set_block_signals(true)
	RenderingServer.force_draw(false)
	RenderingServer.set_block_signals(false)
	if _window_left_out:
		return
	_window_left_out = true
	# Put back where the window is drawn from on, and not a change itself:
	# frame_pre_draw comes before the server forgets what has changed.
	RenderingServer.frame_pre_draw.connect(func() -> void:
		_window_left_out = false
		RenderingServer.viewport_set_update_mode(window, RenderingServer.VIEWPORT_UPDATE_WHEN_VISIBLE),
		CONNECT_ONE_SHOT)


## Copy the model on to the stage, a slice a frame (FramePace), unless what
## is there already is it.
func _stage_model(world: BrickWorld) -> bool:
	var wanted: Array = [world.get_instance_id(), world.generation(), world.revision,
		scenery.size(), scenery.hash(), _hidden_hash(world), _stage.product]
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
		if scenery.has(brick.id) or brick.hidden:
			continue
		if _step.is_empty():
			_doing("staging")
		_staged_ids[brick.id] = _stage.add_brick(brick.part_id, brick.color_code, brick.transform)
	_stage.release_drawing()
	# The batches are written on the frame after.
	await get_tree().process_frame
	_bounds = _stage.model_bounds()
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
	# Asked for while the set is being made ready ahead of time: it is a
	# few frames from done.
	if _warming:
		_wanted = true
		while _warming:
			await get_tree().process_frame
	if not _built:
		await _build()
	_stage.library = library
	_stage.product = settings.look == "product"
	# lineart (APP_UX7 #22): a line look draws its own lines; the seam along
	# every part's edges would come out of its pictures as dots.
	_stage.set_edges_shown(_line_asked == null)
	# On the web a photographed place's light is fetched the first time a
	# picture is lit by one (WebPacks): the set waits for it, saying so. The
	# product look's softbox is the full renderer's alone (_dress).
	if (HDRIS.has(settings.lighting) or (settings.look == "product" and full_renderer())) \
			and not WebPacks.here(WebPacks.HDRI):
		progress.emit(0.0, "fetching the photographed light")
		await WebPacks.need(WebPacks.HDRI)
	progress.emit(0.0, "setting up the model")
	if not await _stage_model(world):
		return false
	if _line_asked != null and not await _line_staged():
		return false
	if _bounds.size.length() <= 0.0:
		return false
	# The product look's glass tints what is behind it, and on nothing (a
	# picture with no backdrop) there is nothing to tint: it would come out
	# clear. There it is blended over what is behind as the window's is,
	# its colour in the picture's alpha.
	for batch: GeometryInstance3D in _product_glass():
		var material := batch.material_override as ShaderMaterial
		while material != null:
			material.set_shader_parameter("over_nothing", settings.transparent)
			material = material.next_pass as ShaderMaterial
	# The set (the sweep, the floor, the contact shadow) is laid under the
	# model and everything its parts sweep; the camera frames that too, or
	# with [member RenderSettings.on_what_moves] only what the parts sweep.
	if _reach.size.length() > 0.0:
		_bounds = _bounds.merge(_reach)
	var moves: bool = settings.on_what_moves and _reach.size.length() > 0.0
	var plan: Plan = plan_for(settings)
	var shot: Shot = aim(settings, _reach if moves else _bounds, turning, _bounds,
		_swept if moves else PackedVector3Array())
	last_shot = shot
	last_samples = plan.samples
	_pivot.position = Vector3(_bounds.get_center().x, 0.0, _bounds.get_center().z)
	_stage.position = -_pivot.position
	_lamps.position = _stage.position
	_pivot.rotation = Vector3.ZERO
	# The model's own lights, and in the Dark light its glowing plastics
	# (SceneLights), each on the set as the model has them.
	var dark: bool = settings.lighting == "dark"
	_glow = GLOW if dark else 0.0
	_place_lamps(world.scene_lights, settings)
	_place_glows(settings)
	for batch: Node in _stage.get_children():
		if not batch is MultiMeshInstance3D:
			continue
		var plastic := (batch as MultiMeshInstance3D).material_override as ShaderMaterial
		while plastic != null:
			plastic.set_shader_parameter("room", 0.0 if dark else 1.0)
			plastic.set_shader_parameter("glow", _glow)
			plastic = plastic.next_pass as ShaderMaterial
	# What the window's own light makes of this model from here: the
	# lightness every other choice is exposed to match.
	# Not in the Dark light, which is as dark as it is: metered to the
	# window's lightness, its glimmer was made daylight again.
	var metered: bool = (settings.lighting != "studio" or plan.gi or plan.traced) and not dark
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
	_wanted_lightness = wanted
	if plan.traced:
		# The tracer meters its own picture (_traced), and casts its own
		# shadows: nothing of the raster's to draw first.
		_contact.visible = false
		_floor_mask = null
		last_exposure = 1.0
		return true
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
	# And the sweep brought to its colour: white white, black black. Not in
	# the Dark light, where it is as lit as the model's lights light it.
	_floor_mask = null
	_backdrop_material.set_shader_parameter("level", 1.0)
	last_level = 1.0
	if _backdrop.visible and not dark:
		var level: float = 1.0
		_backdrop_material.set_shader_parameter("level", level)
		var goal: float = minf(settings.backdrop.get_luminance(), 0.95)
		var before: Vector2 = Vector2.ZERO
		var product: bool = settings.look == "product"
		for _round: int in 4:
			var floor_seen: float = await _meter_floor(shot, settings.size)
			if floor_seen < 0.0:
				return false
			if absf(floor_seen - goal) < 0.015 or floor_seen <= 0.0005:
				break
			# Near white the film curve's shoulder lightens the sweep far
			# less than its light: the last round's answer says how much
			# less. Taken as 1 in 1.6, a white sweep under the product
			# look's exposure crept from #e4 to #ee in four rounds and
			# stopped short of white. The window look keeps 1 in 1.6: a
			# photographed place's sweep driven home went to its brightest
			# (6) and its bounce greyed the model (render_probe).
			var gain: float = 1.6
			if product and before.x > 0.0 and absf(log(level / before.x)) > 0.001:
				var answer: float = log(floor_seen / before.y) / log(level / before.x)
				gain = clampf(1.0 / maxf(answer, 0.01), 1.6, 12.0)
			before = Vector2(level, floor_seen)
			level = clampf(level * clampf(pow(goal / floor_seen, gain), 0.3, 3.0), 0.05, 6.0)
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
	# The sweep in the set's light alone, as the model is metered.
	_lamps.visible = false
	var floor_drawn: bool = await _draw([_scene])
	_lamps.visible = true
	if not floor_drawn:
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
	# The product look's clear parts are drawn whole, with what is behind
	# them, and on this picture's clear background that is nothing: they
	# counted as dark glass and lifted the exposure, where the window's,
	# drawn see-through, do not count.
	var clear: Array[GeometryInstance3D] = _product_glass()
	for batch: GeometryInstance3D in clear:
		batch.visible = false
	# Metered in the set's light alone: the model's own lights add to it.
	_lamps.visible = false
	var drawn: bool = await _draw([_scene])
	_lamps.visible = true
	for batch: GeometryInstance3D in clear:
		batch.visible = true
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


## The staged model's clear parts in the product look's glass, as shown.
func _product_glass() -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	if not _stage.product:
		return out
	var glass: Array = [BrickWorld.PRODUCT_SHADERS[BrickWorld.SHADERS["trans"]],
		BrickWorld.PRODUCT_SHADERS[BrickWorld.SHADERS["trans_two_sided"]]]
	for child: Node in _stage.get_children():
		var batch := child as MultiMeshInstance3D
		if batch != null and batch.visible and batch.material_override is ShaderMaterial \
				and (batch.material_override as ShaderMaterial).shader in glass:
			out.append(batch)
	return out


## Where the camera goes for these settings, framing [param bounds].
## [param turning]: the model will turn, so frame what it sweeps through.
## [param whole]: all there is to draw, when the frame is only part of it
## (an animation framed on what moves): the clip planes take it in.
## [param points]: fitted to these rather than [param bounds]' corners.
func aim(settings: RenderSettings, bounds: AABB, turning: bool = false,
		whole: AABB = AABB(), points: PackedVector3Array = PackedVector3Array()) -> Shot:
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
	# the picture is centred on what the view looks at either way. Framed on
	# what moves, the window's view gives its direction and the frame is fitted.
	# The window's view as it was when the render was asked for (RenderQueue),
	# or as it is.
	var kept: bool = settings.eye_fov > 0.0
	var seen: bool = kept or eye != null
	var from: Transform3D = settings.eye_transform if kept \
		else (eye.global_transform if eye != null else Transform3D())
	if view == "current" and seen and not settings.on_what_moves and not (
			settings.eye_orthogonal if kept else eye.projection == Camera3D.PROJECTION_ORTHOGONAL):
		var forward: Vector3 = -from.basis.z.normalized()
		var focus: Vector3 = settings.eye_focus if kept else (eye.call("focus_now")
			if eye.has_method("focus_now") else frame.get_center())
		var depth: float = maxf((focus - from.origin).dot(forward), 1.0)
		# The point looked at stays the size it is, through the new lens.
		var scale: float = tan(deg_to_rad(settings.eye_fov if kept else eye.fov) * 0.5) \
			/ tan(deg_to_rad(shot.fov) * 0.5)
		shot.basis = from.basis.orthonormalized()
		shot.origin = from.origin + forward * depth * (1.0 - scale)
	else:
		var direction: Vector3 = Vector3(VIEWS["hero"][1])
		if view == "current" and seen:
			direction = from.basis.z
		elif view != "current":
			direction = Vector3(VIEWS[view][1])
		shot.basis = _looking_from(direction.normalized())
		shot.origin = _fit(shot.basis, frame, shot.fov, aspect) if points.is_empty() or turning \
			else _fit_points(shot.basis, points, shot.fov, aspect)
	# Clip planes round the model and the sweep behind it; the focus across
	# what is framed.
	var clipped: AABB = frame if whole.size == Vector3.ZERO else frame.merge(whole)
	var radius: float = clipped.size.length() * 0.5
	var depths: Array = []
	for box: AABB in [clipped, frame]:
		var nearest: float = INF
		var farthest: float = 0.0
		for n: int in 8:
			var depth_here: float = (_corner(box, n) - shot.origin).dot(-shot.basis.z)
			nearest = minf(nearest, depth_here)
			farthest = maxf(farthest, depth_here)
		depths.append([nearest, farthest])
	shot.near = clampf(float(depths[0][0]) * 0.5, 0.5, 200.0)
	shot.far = maxf(float(depths[0][1]), 1.0) + radius * 90.0
	shot.focus_distance = maxf(lerpf(float(depths[1][0]), float(depths[1][1]),
		clampf(settings.focus, 0.0, 1.0)), shot.near * 2.0)
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
	var corners := PackedVector3Array()
	for n: int in 8:
		corners.append(_corner(box, n))
	return _fit_points(basis, corners, fov, aspect)


## As [method _fit], every one of [param points] inside the frame.
static func _fit_points(basis: Basis, points: PackedVector3Array, fov: float,
		aspect: float) -> Vector3:
	var tan_up: float = tan(deg_to_rad(fov) * 0.5) * FILL
	var tan_across: float = tan_up * aspect
	var box := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		box = box.expand(point)
	var target: Vector3 = box.get_center()
	var origin: Vector3 = target
	for _round: int in 4:
		var need: float = 0.0
		for point: Vector3 in points:
			var corner: Vector3 = point - target
			var back: float = corner.dot(basis.z)
			need = maxf(need, back + absf(corner.dot(basis.x)) / tan_across)
			need = maxf(need, back + absf(corner.dot(basis.y)) / tan_up)
		origin = target + basis.z * need
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for point: Vector3 in points:
			var seen: Vector3 = point - origin
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

	var product: bool = settings.look == "product"
	var dark: bool = settings.lighting == "dark"
	var panorama: StudioPanorama = _panorama(settings.lighting)
	_lit_by = panorama
	_room = 1.0
	_turn = turn
	# What the product look's plastic reflects and is lit by besides its
	# three lights, when no photographed place is: a softbox studio. Only on
	# the desktop, whose sky lights as it should (see below).
	var reflected: StudioPanorama = panorama
	if product and panorama == null and full and not dark:
		reflected = _panorama(PRODUCT_SKY)
		_panorama_in_use = null
		_lit_by = reflected
		_room = PRODUCT_ROOM
	# One environment for each way of lighting, kept and changed rather than
	# made again: in a browser each new one drawn for the first time held the
	# page for seconds, at the start of every draft.
	var key: String = "%s %s %s %s %s" % [settings.lighting, plan.gi, plan.occlusion,
		plan.sky_samples, settings.look]
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
		if reflected != null and full:
			var sky := Sky.new()
			if product and panorama == null:
				# The product look's own studio, its room flagged down.
				var studio_sky := ShaderMaterial.new()
				studio_sky.shader = STUDIO_SKY
				studio_sky.set_shader_parameter("panorama", reflected.texture)
				studio_sky.set_shader_parameter("energy",
					HDRI_LEVEL / maxf(reflected.average, 0.0001))
				studio_sky.set_shader_parameter("room", PRODUCT_ROOM)
				sky.sky_material = studio_sky
			else:
				var material := PanoramaSkyMaterial.new()
				material.panorama = reflected.texture
				# As bright as the window's light whatever the place: its
				# average brought to one, and the exposure metered after.
				material.energy_multiplier = HDRI_LEVEL / maxf(reflected.average, 0.0001)
				sky.sky_material = material
			if product:
				sky.process_mode = Sky.PROCESS_MODE_QUALITY
				sky.radiance_size = Sky.RADIANCE_SIZE_512
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
		if dark:
			# Nothing of the window's sky: no light from it, and nothing of
			# it in the plastic's gloss. What lights the model is its own.
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.ambient_light_color = Color(0.86, 0.88, 0.95)
			environment.ambient_light_sky_contribution = 0.0
			environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
			environment.sdfgi_read_sky_light = false
		if product:
			# A film's curve: highlights roll off to white rather than clip.
			# Not AgX, which does the same and also bends a bright red
			# towards orange on its way there: the sports car's bricks came
			# out the orange of a traffic cone (docs/RENDERING.md). Filmic
			# keeps red red, and gives back less colour and contrast than
			# ACES, so a little of each is put back.
			environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			environment.tonemap_white = PRODUCT_WHITE
			environment.adjustment_enabled = true
			environment.adjustment_saturation = PRODUCT_SATURATION
			environment.adjustment_contrast = PRODUCT_CONTRAST
			if full:
				# Deeper shading where parts meet. Not screen-space bounce
				# light (SSIL), whose half-size checker of samples showed as
				# dashes along every lit edge at Good's six frames, nor
				# screen-space reflections, which a viewport with a clear
				# background does not draw: global illumination bounces the
				# light at Good and Best.
				environment.ssao_intensity = 1.6
				environment.ssao_radius = 10.0
		_environments[key] = environment
	# What changes from picture to picture.
	environment.tonemap_exposure = look.tonemap_exposure if look != null else 1.05
	if product:
		environment.tonemap_exposure *= PRODUCT_EXPOSURE
	if dark and not full:
		environment.tonemap_exposure *= DARK_COMPAT_EXPOSURE
	if settings.transparent:
		environment.background_mode = Environment.BG_CLEAR_COLOR
	else:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = settings.backdrop
		if dark:
			environment.background_color = Color(settings.backdrop.r * DARK_BACKDROP,
				settings.backdrop.g * DARK_BACKDROP, settings.backdrop.b * DARK_BACKDROP)
	var ambient_forward: float = (look.ambient_light_energy if look != null else 0.24) \
		/ BrickWorld.light_energy(1.0)
	if look == null:
		ambient_forward = 0.4
	var key_energy_forward: float = 0.9
	if product and panorama == null and reflected != null:
		# The softbox's light in place of the window's even grey, at the
		# window's strength (the exposure is metered after).
		ambient_forward *= 0.8
	if panorama != null:
		ambient_forward = HDRI_AMBIENT * (1.0 - 0.5 * panorama.key_share)
		key_energy_forward = HDRI_KEY * panorama.key_share
		environment.sky_rotation = Vector3(0.0, turn, 0.0) if full else Vector3.ZERO
	elif reflected != null:
		environment.sky_rotation = Vector3(0.0, turn, 0.0)
	if dark:
		ambient_forward = DARK_AMBIENT
	environment.ambient_light_energy = BrickWorld.light_energy(ambient_forward)
	_ambient = ambient_forward
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
		var row: Array = PRODUCT_RIG[n] if product else RIG[n]
		var source: DirectionalLight3D = rig_lights[n] if n < rig_lights.size() and not product \
			else null
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
		# The Dark light puts the studio out.
		if dark:
			light.visible = false
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
		# Good's soft key filters its shadow over a wide spread of the map,
		# and on a face turned from the light the face itself lies behind
		# the map across that spread: at 0.02 every grey face the key lit
		# was hatched with the filter's pattern. Normal bias moves the test
		# a texel or two and did not reach (3 left it). Product only: the
		# window look's renders are as they were.
		light.shadow_bias = 0.12 if product else 0.02
		light.shadow_normal_bias = 1.5
	_sky_light.visible = plan.sky_samples and not dark
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
	# Not for a path-traced picture, which draws none of it, and goes on
	# beside a window still in use (RenderQueue).
	if full and settings.quality != RenderSettings.Quality.QUICK and not plan.traced:
		_shadow_atlas(8192)
		# The finest occlusion and soft shadows there are, at full size: the
		# engine's defaults are made for a game's frame, half-size occlusion
		# and a few shadow taps, and in a 4K still both showed as a grid of
		# dots over every face.
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_ULTRA,
			false, 0.5, 4, 50.0, 300.0)
		RenderingServer.directional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
		# And the model's own lights' (SceneLights).
		RenderingServer.positional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	else:
		_shadow_atlas(_project_atlas())

	# The sweep, its wall behind the model and its floor running out
	# under the camera, turned to face it.
	var below: bool = shot.origin.y < floor_y
	_backdrop.visible = not settings.transparent and not below
	if _backdrop.visible:
		var footprint: float = Vector2(_bounds.size.x, _bounds.size.z).length() * 0.5
		# A staged table (photoreal7) runs on behind the model as far as the
		# floor does in front, so no camera sees its far edge but at the
		# horizon (traced only: a draft keeps the studio's sweep); a studio's
		# paper turns up close behind.
		var far: float = radius * 60.0 + reach * 3.0
		var behind: float = far if _table(settings) and plan.traced else footprint * 1.25 + 40.0
		var shape := Vector3(behind, maxf(radius * 2.0, 160.0), far)
		if shape != _sweep_shape or _backdrop.mesh == null:
			_sweep_shape = shape
			_backdrop.mesh = _sweep(shape.x, shape.y, shape.z)
		var facing: Basis = Basis.looking_at(-shot.toward, Vector3.UP)
		_backdrop.global_transform = Transform3D(facing,
			Vector3(_bounds.get_center().x, floor_y, _bounds.get_center().z))
		_backdrop_material.set_shader_parameter("colour",
			Vector3(settings.backdrop.r, settings.backdrop.g, settings.backdrop.b))
		var dark_sweep: bool = settings.backdrop.get_luminance() < 0.2
		_backdrop_material.set_shader_parameter("fall", 0.0 if not settings.backdrop_gradient
			else (FALL_DARK if dark_sweep else FALL_GRADIENT))
		_backdrop_material.set_shader_parameter("pool", Vector2(radius * 0.7, radius * 3.2))


# -- the model's own lights (SceneLights) -----------------------------------------


## [param lights] (BrickWorld.scene_lights, the window's coordinates) put on
## the set as Godot's lights: a bulb an OmniLight3D and a spot a SpotLight3D,
## each falling off with the square of the distance (attenuation 2) and
## strong enough that a face 100 LDU away is lit as SceneLights.lit_at says;
## a sun a DirectionalLight3D; a panel a spot opened nearly flat, falling off
## as the cosine does, its size softening its shadows (the tracer's is a
## true square of light). None of their light is bounced by global
## illumination, nor by the tracer (path_tracer.glsl): what a spot lights is
## what it lights, and the draft shows the light Best draws.
func _place_lamps(lights: Array, settings: RenderSettings) -> void:
	for node: Light3D in _lamp_nodes:
		node.queue_free()
	_lamp_nodes.clear()
	var corner: float = _bounds.size.length()
	var compat_dark: bool = settings.lighting == "dark" and not full_renderer()
	var suns: float = _suns_share(lights) if compat_dark else 1.0
	for light: Dictionary in lights:
		var kind: String = str(light["kind"])
		var at: Vector3 = SceneLights.at_of(light)
		var aim: Vector3 = SceneLights.aim_of(light).normalized()
		var shadows: bool = bool(light.get("shadows", true)) and not settings.no_shadows
		var node: Light3D
		# Far enough that its fall to nothing at the end of its range is
		# beyond anything it lights: three times its farthest corner of the
		# model, the tracer's the same (path_tracer.glsl's reach).
		var reach: float = maxf(3.0 * (at.distance_to(_bounds.get_center()) + corner), 400.0)
		match kind:
			"point":
				var omni := OmniLight3D.new()
				omni.omni_range = reach
				omni.omni_attenuation = 2.0
				node = omni
			"spot", "area":
				var spot := SpotLight3D.new()
				spot.spot_range = reach
				spot.spot_attenuation = 2.0
				if kind == "spot":
					spot.spot_angle = float(light.get("cone", 40.0)) * 0.5
					# Godot raises the rim to the reciprocal of this.
					spot.spot_angle_attenuation = 1.0 / SceneLights.EDGE
				else:
					# A flat panel's light: the cosine of the angle off its face.
					spot.spot_angle = 80.0
					spot.spot_angle_attenuation = 1.0
				node = spot
			"directional":
				var sun := DirectionalLight3D.new()
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
				sun.directional_shadow_max_distance = maxf(corner * 4.0, 400.0)
				sun.directional_shadow_fade_start = 1.0
				sun.light_angular_distance = 0.5
				node = sun
			_:
				continue
		node.light_color = SceneLights.colour_of(light)
		node.light_energy = BrickWorld.light_energy(SceneLights.energy(light), shadows)
		if compat_dark:
			node.light_energy *= DARK_COMPAT_LAMPS * (suns if kind == "directional" else 1.0)
		node.light_indirect_energy = 0.0
		node.light_specular = BrickWorld.light_specular(0.5)
		node.shadow_enabled = shadows
		node.shadow_bias = 0.03
		node.shadow_normal_bias = 1.0
		if kind != "directional":
			node.light_size = float(light.get("size", 4.0)) * (1.0 if kind == "area" else 2.0)
		node.name = "Lamp%d" % _lamp_nodes.size()
		_lamps.add_child(node)
		var up: Vector3 = Vector3.UP if absf(aim.y) < 0.98 else Vector3.FORWARD
		node.transform = Transform3D(Basis.looking_at(aim, up), at)
		node.set_meta("lamp", light)
		node.set_meta("reach", reach)
		_lamp_nodes.append(node)


## In the Dark light, the plastics that glow lighting what is round them,
## rasterised: a light at each lump of glowing parts ([constant GLOW_CELL]
## across), as much light as their faces give off ([constant GLOW] of their
## colour over every face of their boxes), at most [constant GLOW_LIGHTS] of
## the brightest. They cast no shadow, being inside what glows; the tracer
## needs none of them, its glowing faces being lights of their own.
func _place_glows(settings: RenderSettings) -> void:
	for node: OmniLight3D in _glow_nodes:
		node.queue_free()
	_glow_nodes.clear()
	if _glow <= 0.0 or library == null:
		return
	var cells: Dictionary = {}
	for brick: BrickWorld.Brick in _stage.bricks():
		var colour: PartLibrary.BrickColor = library.color(brick.color_code)
		if colour == null or not colour.drawn_as in [PartLibrary.BrickColor.Finish.GLOW,
				PartLibrary.BrickColor.Finish.FLUORESCENT]:
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var box: AABB = info.bounds if info != null and info.bounds.size.length() > 0.0 \
			else AABB(Vector3(-10, -24, -10), Vector3(20, 24, 20))
		var middle: Vector3 = _stage.drawn_at(brick) * box.get_center()
		var faces: float = 2.0 * (box.size.x * box.size.y + box.size.y * box.size.z
			+ box.size.z * box.size.x)
		var lit: Color = colour.shown.srgb_to_linear()
		# What its faces give off, as a light at its middle: radiance times
		# area over four (a sphere's worth of a flat face's pi).
		var power: float = _glow * faces * 0.25
		var cell := Vector3i((middle / GLOW_CELL).floor())
		var into: Array = cells.get(cell, [Vector3.ZERO, Color(0, 0, 0), 0.0])
		into[0] = (into[0] as Vector3) + middle * power
		into[1] = (into[1] as Color) + lit * power
		into[2] = float(into[2]) + power
		cells[cell] = into
	var lumps: Array = cells.values()
	lumps.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) > float(b[2]))
	lumps = lumps.slice(0, GLOW_LIGHTS)
	if lumps.is_empty():
		return
	var own: int = _glows_allowed(lumps.size())
	if not full_renderer():
		_make_room(own)
	for lump: Array in _gathered(lumps, own):
		var power: float = float(lump[2])
		var colour: Color = (lump[1] as Color) / power
		var brightest: float = maxf(colour.r, maxf(colour.g, colour.b))
		var node := OmniLight3D.new()
		node.position = (lump[0] as Vector3) / power
		node.light_color = (colour / maxf(brightest, 0.0001)).linear_to_srgb()
		# Falling off a little slower than a point would: a lump of plastic
		# is no point, and a face beside it is lit by it whole.
		node.omni_attenuation = 1.5
		node.omni_range = maxf(_bounds.size.length() * 2.0, 400.0)
		node.light_energy = BrickWorld.light_energy(power * brightest * GLOW_RASTER)
		node.light_indirect_energy = 0.0
		node.light_specular = 0.0
		node.shadow_enabled = false
		node.light_size = GLOW_CELL * 0.25
		node.name = "Glow%d" % _glow_nodes.size()
		_lamps.add_child(node)
		_glow_nodes.append(node)


## The rasterised glow's light against a point's: falling off as distance to
## the 1.5 (above), it is matched to the square's at 40 LDU.
const GLOW_RASTER := 0.16
## The fewest glow lights Compatibility keeps while anything glows: the
## model's bulbs make room for them ([method _make_room]). Given to the
## nearest bulb instead, eight bulbs over a grid of neon bricks drew the
## glow from where the bulbs hang, its far floor black (lreview, 2026-11-07).
const GLOW_KEPT := 2


## [param lumps] ([position x power, colour x power, power] each, the
## brightest first) as [param most] lights at most: as they are when they are
## no more, and otherwise gathered round [param most] middles, each the
## power-weighted middle of the lumps nearest it (a few rounds of k-means
## from the brightest), so fewer lights still give off the glow from where
## it is, all of it.
static func _gathered(lumps: Array, most: int) -> Array:
	if lumps.size() <= most or most <= 0:
		return lumps if most > 0 else []
	var middles: Array[Vector3] = []
	for n: int in most:
		middles.append((lumps[n][0] as Vector3) / float(lumps[n][2]))
	var groups: Array = []
	for _round: int in 6:
		groups = []
		for n: int in most:
			groups.append([Vector3.ZERO, Color(0, 0, 0), 0.0])
		for lump: Array in lumps:
			var at: Vector3 = (lump[0] as Vector3) / float(lump[2])
			var nearest: int = 0
			for n: int in range(1, most):
				if at.distance_squared_to(middles[n]) < at.distance_squared_to(middles[nearest]):
					nearest = n
			var group: Array = groups[nearest]
			group[0] = (group[0] as Vector3) + (lump[0] as Vector3)
			group[1] = (group[1] as Color) + (lump[1] as Color)
			group[2] = float(group[2]) + float(lump[2])
		for n: int in most:
			if float(groups[n][2]) > 0.0:
				middles[n] = (groups[n][0] as Vector3) / float(groups[n][2])
	return groups.filter(func(group: Array) -> bool: return float(group[2]) > 0.0)


## Under Compatibility, the model's bulbs made few enough that [param glows]
## glow lights are drawn beside them on one thing (max_lights_per_object
## bulbs at most, its spots counted apart): the dimmest bulb given to the
## bulb nearest it, where the two of them are, by energy, until they fit.
## Past the limit Compatibility leaves out whichever lights come last, the
## glow's or the model's own.
func _make_room(glows: int) -> void:
	var most: int = int(ProjectSettings.get_setting(
		"rendering/limits/opengl/max_lights_per_object", 8))
	var bulbs: Array[OmniLight3D] = []
	for node: Light3D in _lamp_nodes:
		if node is OmniLight3D and node.visible:
			bulbs.append(node as OmniLight3D)
	while bulbs.size() > maxi(most - glows, 1):
		bulbs.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool:
			return a.light_energy < b.light_energy)
		var gone: OmniLight3D = bulbs.pop_front()
		var into: OmniLight3D = bulbs[0]
		for node: OmniLight3D in bulbs:
			if node.position.distance_squared_to(gone.position) \
					< into.position.distance_squared_to(gone.position):
				into = node
		var sum: float = into.light_energy + gone.light_energy
		var share: float = gone.light_energy / maxf(sum, 0.000001)
		into.position = into.position.lerp(gone.position, share)
		into.light_color = into.light_color.lerp(gone.light_color, share)
		into.light_energy = sum
		into.light_size = maxf(into.light_size, gone.light_size)
		into.omni_range = maxf(into.omni_range, gone.omni_range)
		gone.visible = false


## Under Compatibility, which adds light in sRGB, what each of the model's
## suns is given so that together they light as Forward+'s do: Forward+ adds
## them in linear light and encodes the sum, about its 1/2.2th power, so four
## equal suns light a face about 4^0.45 = 1.9 times as much as one, not 4.
## The sum's power over the sum of the powers: 1 for one sun or one far the
## strongest, n^-0.55 for n equal ones.
static func _suns_share(lights: Array) -> float:
	var whole: float = 0.0
	var parts: float = 0.0
	for light: Dictionary in lights:
		if str(light.get("kind", "")) != "directional":
			continue
		var energy: float = SceneLights.energy(light)
		whole += energy
		parts += pow(energy, 1.0 / 2.2)
	return pow(whole, 1.0 / 2.2) / parts if parts > 0.0 else 1.0


## How many glow lights the set may have for [param lumps] lumps of glowing
## parts: one each, up to [constant GLOW_LIGHTS]; and under Compatibility,
## which draws at most max_lights_per_object bulbs on one thing (8; its spots
## are counted apart, a glow is a bulb), what the model's bulbs leave of
## them, but never fewer than [constant GLOW_KEPT]: the bulbs make room
## ([method _make_room]). Past the limit it leaves lights out, the model's
## own among them: eight bulbs over a grid of neon bricks added nothing on
## the web (lreview, 2026-11-07).
func _glows_allowed(lumps: int) -> int:
	if full_renderer():
		return mini(lumps, GLOW_LIGHTS)
	var bulbs: int = 0
	for node: Light3D in _lamp_nodes:
		if node is OmniLight3D and node.visible:
			bulbs += 1
	var most: int = int(ProjectSettings.get_setting(
		"rendering/limits/opengl/max_lights_per_object", 8))
	return mini(lumps, clampi(maxi(most - bulbs, GLOW_KEPT), 0, GLOW_LIGHTS))


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
	_lamps.visible = false
	var textures: Array[ImageTexture] = []
	for n: int in HEIGHTS.size():
		_floor_camera.far = 2.0 + float(HEIGHTS[n])
		if not await _draw([_floor_view]):
			for k: int in lights.size():
				lights[k].visible = lit[k]
			_lamps.visible = true
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
	_lamps.visible = true
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
	if _line_asked != null:
		return await _line_picture(settings, from, to, words)
	var plan: Plan = plan_for(settings)
	_traced_last = plan.traced
	if plan.traced:
		return await _traced(settings, plan, from, to, words)
	var shot: Shot = last_shot
	var picture: Vector2i = Vector2i(maxi(settings.size.x, 1), maxi(settings.size.y, 1))
	var tiles: Array[Rect2i] = _tiles(picture)
	last_tiles = tiles.size()
	var margin: int = 0
	if plan.occlusion:
		# Occlusion looks a little past the edge of what it draws; each
		# piece is drawn wider and cut back. A picture in one piece too:
		# its last column came out darker, and not the same from one
		# drawing to the next (lights_probe, 2026-11-06).
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


# -- lineart (APP_UX7 #22): the Line art and Comic looks (LineArt) ----------


## The line looks, made the first time one is asked for, and what the
## picture being drawn in one was asked for; null for every other look.
var _line: LineArt = null
var _line_asked: RenderSettings = null
## What the flat picture put aside: the camera's light and layers, and the
## lights' being on.
var _flat_kept: Array = []


## What the set draws for [param settings]: itself, or for a line look what
## LineArt inks over, [member _line_asked] kept for the ink.
func _drawn_in_lines(settings: RenderSettings) -> RenderSettings:
	_line_asked = settings if LineArt.drawn_in_lines(settings.look) else null
	return LineArt.underneath(settings) if _line_asked != null else settings


## The line looks' copy of the model, made of the stage as staged.
func _line_staged() -> bool:
	if _line == null:
		_line = LineArt.new()
		_line.name = "LineArt"
		add_child(_line)
		_line.setup(_scene.world_3d, _pivot, library)
	_line.stage.library = library
	return await _line.stage_from(_stage, _staged, func() -> bool: return _cancelled)


## The set lit by nothing but an even white, the plastic's own colour and no
## more ([param on]), or as it was.
func _flat(on: bool) -> void:
	var lights: Array[Light3D] = []
	lights.append_array(_lights)
	lights.append(_sky_light)
	if on:
		_flat_kept = [_camera.environment, _camera.cull_mask, _lamps.visible]
		for light: Light3D in lights:
			_flat_kept.append(light.visible)
			light.visible = false
		_camera.environment = _line.flat_light
		_camera.cull_mask = 1
		_lamps.visible = false
	else:
		_camera.environment = _flat_kept[0]
		_camera.cull_mask = _flat_kept[1]
		_lamps.visible = _flat_kept[2]
		for n: int in lights.size():
			lights[n].visible = _flat_kept[3 + n]
	var dark: bool = _line_asked.lighting == "dark"
	for batch: Node in _stage.get_children():
		if not batch is MultiMeshInstance3D:
			continue
		var plastic := (batch as MultiMeshInstance3D).material_override as ShaderMaterial
		while plastic != null:
			plastic.set_shader_parameter("room", 0.0 if on or dark else 1.0)
			plastic.set_shader_parameter("glow", 0.0 if on else _glow)
			plastic = plastic.next_pass as ShaderMaterial


## A picture in a line look, a piece at a time as any picture is: for each,
## the set's two pictures of it (lit, then flat), the copy's two (its parts'
## numbers, then their faces), and the ink made of the four, read back.
func _line_picture(settings: RenderSettings, from: float, to: float, words: String) -> Image:
	var plan: Plan = plan_for(settings)
	var shot: Shot = last_shot
	var picture: Vector2i = Vector2i(maxi(settings.size.x, 1), maxi(settings.size.y, 1))
	var tiles: Array[Rect2i] = _tiles(picture)
	last_tiles = tiles.size()
	# Every piece drawn wider and cut back, for the widest line and the
	# occlusion's look past its edge: the lines meet across the cut.
	var margin: int = clampi(picture.y / 24, 16, 96)
	var size: Vector2i = tiles[0].size + Vector2i(margin * 2, margin * 2)
	_size_all(size)
	var result := Image.create(picture.x, picture.y, false, Image.FORMAT_RGBA8)
	_resolve_material.set_shader_parameter("dither", 0.0)
	_resolve_material.set_shader_parameter("sum_tex", _sums[0].get_texture())
	_sum_materials[0].set_shader_parameter("first", true)
	_sum_materials[0].set_shader_parameter("weight", 1.0)
	var full: float = await _line_full_light(shot, plan, picture)
	if full < 0.0:
		return null
	for tile: Rect2i in tiles:
		var piece: int = tiles.find(tile)
		_point(shot, tile, margin, picture, Vector2.ZERO, Vector2.ZERO)
		_light_sample(plan, 0, 1)
		if not await _draw([_scene, _sums[0], _base, _out]):
			return null
		_flat(true)
		var flat_drawn: bool = await _draw([_scene, _base])
		_flat(false)
		if not flat_drawn:
			return null
		_line.before_codes(_camera, _scene, size, _stage.transform)
		var coded: bool = await _draw([_line.codes_view])
		if coded:
			_line.before_normals()
			coded = await _draw([_line.normals_view])
		if coded:
			_line.before_light()
			_lights_seen_from(LineArt.LAYER, true)
			coded = await _draw([_line.light_view])
			_lights_seen_from(LineArt.LAYER, false)
		_line.after()
		if not coded:
			return null
		_line.before_ink(_out.get_texture(), _base.get_texture(), _line_asked, picture,
			tile.position - Vector2i(margin, margin), size, full)
		if not await _draw([_line.ink_view]):
			return null
		_doing("reading the picture back")
		var drawn: Image = await _read(_line.ink_view)
		if drawn == null:
			return null
		await get_tree().process_frame
		_doing("putting the piece in")
		if drawn.get_format() != Image.FORMAT_RGBA8:
			drawn.convert(Image.FORMAT_RGBA8)
		var inside: Rect2i = tile.intersection(Rect2i(Vector2i.ZERO, picture))
		result.blit_rect(drawn, Rect2i(Vector2i(margin, margin), inside.size), inside.position)
		piece_done.emit(drawn.get_region(Rect2i(Vector2i(margin, margin), inside.size)),
			inside.position)
		var said: String = words if not words.is_empty() else "inking"
		if tiles.size() > 1 and words.is_empty():
			said = "piece %d of %d, inking" % [piece + 1, tiles.size()]
		progress.emit(lerpf(from, to, float(piece + 1) / float(tiles.size())), said)
	if not _line_asked.transparent:
		await get_tree().process_frame
		_doing("converting")
		result.convert(Image.FORMAT_RGB8)
	return result


## Full light for a line picture [param picture] across (LineArt.full_light):
## the clay of the whole of it, drawn small once. Below 0 if cancelled.
func _line_full_light(shot: Shot, plan: Plan, picture: Vector2i) -> float:
	var small := Vector2i(LineArt.FULL_ACROSS,
		maxi(16, LineArt.FULL_ACROSS * picture.y / maxi(picture.x, 1)))
	_point(shot, Rect2i(Vector2i.ZERO, picture), 0, picture, Vector2.ZERO, Vector2.ZERO)
	_light_sample(plan, 0, 1)
	_line.before_codes(_camera, _scene, small, _stage.transform)
	_line.before_light()
	_lights_seen_from(LineArt.LAYER, true)
	var drawn: bool = await _draw([_line.light_view])
	_lights_seen_from(LineArt.LAYER, false)
	_line.after()
	if not drawn:
		return -1.0
	return LineArt.full_light(await _read(_line.light_view))


## The set's lights, the model's own among them, seen from [param layer]
## too or no longer: a camera sees only the lights on the layers it draws
## (as [method _warm] knows), and the clay is drawn on a layer of its own.
func _lights_seen_from(layer: int, seen: bool) -> void:
	var lights: Array[Light3D] = []
	lights.append_array(_lights)
	lights.append(_sky_light)
	lights.append_array(_lamp_nodes)
	lights.append_array(_glow_nodes)
	for light: Light3D in lights:
		light.layers = (light.layers | layer) if seen else (light.layers & ~layer)


## The picture path traced (PathTracer): the set put on the card, the
## exposure and the sweep metered on a small picture of it as the raster's
## are, then pass after pass, a frame of the app's each, the picture shown
## as it gets cleaner until it has its samples or [method finish_now].
func _traced(settings: RenderSettings, plan: Plan, from: float, to: float,
		words: String) -> Image:
	if _tracer == null:
		_tracer = PathTracer.new()
	var shot: Shot = last_shot
	var picture: Vector2i = Vector2i(maxi(settings.size.x, 1), maxi(settings.size.y, 1))
	_doing("putting the set on the card")
	var batches: Array = []
	var pace := FramePace.new()
	for child: Node in _stage.get_children():
		if child is MultiMeshInstance3D:
			batches.append(child)
			var multimesh: MultiMesh = (child as MultiMeshInstance3D).multimesh
			if multimesh != null and multimesh.mesh != null:
				_tracer.shape_of(multimesh.mesh)
			if pace.due():
				await pace.next()
				if _cancelled:
					return null
	_tracer.product = settings.look == "product"
	_tracer.seating = _own(settings.seating, PRODUCT_SEATING) if _tracer.product else 0.0
	_tracer.studs = _own(settings.studs, PRODUCT_STUDS) if _tracer.product else 0.0
	_tracer.play = _own(settings.play, PRODUCT_PLAY) if _tracer.product else 0.0
	_tracer.edge = _own(settings.edge, PRODUCT_EDGE) if _tracer.product else 0.0
	var breakup: Array = _breakup(settings)
	_tracer.peel = float(breakup[2])
	_tracer.sink = float(breakup[3])
	_tracer.marked = _tracer.product and (_own(settings.rubbed, PRODUCT_RUBBED) > 0.0
		or not _matched(settings).is_empty())
	_tracer.photo = _tracer.product and _floor_of(settings) > 0.0
	# The product look's picture has the samples' grain taken out
	# (path_tracer_resolve.glsl), as a photograph has none; the window look's
	# Best is drawn as it was.
	var clean: float = PRODUCT_DENOISE if settings.look == "product" else 0.0
	if not _tracer.stage(batches, _backdrop if _backdrop.visible else null):
		return null
	# A staged table stands in a room (photoreal7): it lights the model and is
	# seen past the table's edge.
	_stage_room = _room_of(settings) if _table(settings) else null
	_tracer.light_with(_stage_room if _stage_room != null else _lit_by)
	var stage: Array = _stage_of(settings) if _lit_stage(settings) else []
	await _read_surfaces(stage)
	_tracer.surface_with(_surface_tile(stage)[0])
	var environment: Environment = _camera.environment
	var tonemapper: int = 2 if environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC else 3
	var white: float = maxf(environment.tonemap_white, 1.0)
	var contrast: float = environment.adjustment_contrast if environment.adjustment_enabled else 1.0
	var saturation: float = environment.adjustment_saturation \
		if environment.adjustment_enabled else 1.0
	var exposure: float = environment.tonemap_exposure
	var level: float = 1.0
	# Metered on a small picture, as the raster's are: the model as light as
	# the window draws it, then the sweep brought to its colour.
	var aspect: float = float(picture.x) / float(maxi(picture.y, 1))
	var small := Vector2i(maxi(roundi(120.0 * aspect), 16), 120)
	var scale: float = 1.0
	var goal: float = minf(settings.backdrop.get_luminance(), 0.95)
	# The product look on a backdrop is metered as a photographer meters a
	# product shot: a white card where the model stands, exposed to the
	# photograph's white (_meter_card), so the model is as light as its light
	# and its colour make it, and the backdrop drawn at its own colour round
	# it (the shadow catcher). Otherwise in the set's light alone, as the
	# raster is metered: the model's own lights add to it (SceneLights). None
	# of it in the Dark light, as dark as it is.
	var catcher: bool = _catches(settings)
	# A staged surface (photoreal7) is metered and drawn as the catcher's
	# picture is, its surface lit rather than caught.
	var photo: bool = _photographic(settings)
	var staged: bool = photo and not _stage_of(settings).is_empty()
	_balance = Color(1, 1, 1)
	_card_colour = Color(1, 1, 1)
	var linear_saturation: float = 1.0
	if photo:
		tonemapper = 4
		white = 1.0
		contrast = 1.0
		saturation = 1.0
		linear_saturation = PHOTO_LINEAR_SATURATION
		scale = await _meter_card(settings, plan, shot, small, exposure, tonemapper, white, contrast,
			saturation)
		if scale <= 0.0:
			return null
		# The camera's white balance (photoreal7): the white card where the
		# model stands drawn white, as much as the balance asks.
		var amount: float = clampf(_own(settings.balance, PRODUCT_BALANCE), 0.0, 1.0)
		if amount > 0.0:
			var gain := Color(lerpf(1.0, 1.0 / _card_colour.r, amount),
				lerpf(1.0, 1.0 / _card_colour.g, amount), lerpf(1.0, 1.0 / _card_colour.b, amount))
			var kept: float = 0.2126 * _card_colour.r * gain.r + 0.7152 * _card_colour.g * gain.g \
				+ 0.0722 * _card_colour.b * gain.b
			_balance = gain / maxf(kept, 0.0001)
	for round: int in (0 if settings.lighting == "dark" or photo else 5):
		_tracer.scene = _traced_scene(settings, plan, shot, small, level, false)
		if not _tracer.begin(small):
			return null
		# A frame's share at a time: 48 samples at once held the window's
		# frame while the queue drew beside it.
		_doing("metering")
		for _part: int in 4:
			_tracer.trace(12, round)
			await get_tree().process_frame
			if _cancelled:
				return null
		if _wanted_lightness > 0.0:
			for _step_round: int in 4:
				var seen: Image = _tracer.picture(exposure * scale, tonemapper, white, contrast,
					saturation, true, false)
				var got: float = _mean_covered(seen)
				if got <= 0.001 or absf(got / _wanted_lightness - 1.0) < 0.02:
					break
				scale *= clampf(pow(_wanted_lightness / got, 1.4), 0.4, 2.5)
		if not _backdrop.visible or photo:
			break
		var floor_image: Image = _tracer.picture(exposure * scale, tonemapper, white, contrast,
			saturation, true, false)
		var floor_seen: float = _floor_level(floor_image)
		if absf(floor_seen - goal) < 0.015 or floor_seen <= 0.0005:
			break
		level = clampf(level * clampf(pow(goal / floor_seen, 1.6), 0.3, 3.0), 0.05, 6.0)
	last_exposure = scale
	last_level = level
	# The picture itself.
	var most: float = PRODUCT_MOST * white / maxf(exposure * scale, 0.0001) \
		if settings.look == "product" else 0.0
	# The light the backdrop gives the eye, so the picture shows it at
	# exactly its colour.
	var caught := Color(-1.0, 0.0, 0.0)
	if catcher:
		# Each channel's light through the curve, then the camera's linear
		# saturation undone round its luminance, which it keeps.
		var at: float = maxf(exposure * scale, 0.0001)
		var need := Color(_untoned(settings.backdrop.r, tonemapper, white, contrast),
			_untoned(settings.backdrop.g, tonemapper, white, contrast),
			_untoned(settings.backdrop.b, tonemapper, white, contrast))
		var grey: float = 0.2126 * need.r + 0.7152 * need.g + 0.0722 * need.b
		caught = Color(maxf(grey + (need.r - grey) / linear_saturation, 0.0) / at / _balance.r,
			maxf(grey + (need.g - grey) / linear_saturation, 0.0) / at / _balance.g,
			maxf(grey + (need.b - grey) / linear_saturation, 0.0) / at / _balance.b)
	_tracer.scene = _traced_scene(settings, plan, shot, picture, level, true, most, caught)
	# The camera's own marks, for the product look on a backdrop (photoreal4):
	# its sensor's noise, its lens's fall-off and fringes (the fringes in
	# pixels at a corner of a 1024-pixel picture, as many more as it is wider).
	var lens := Vector4.ZERO
	if photo:
		lens = Vector4(_own(settings.grain, PRODUCT_GRAIN), _own(settings.vignette, PRODUCT_VIGNETTE),
			_own(settings.aberration, PRODUCT_ABERRATION) * float(picture.x) / 1024.0,
			_own(settings.softness, PRODUCT_SOFTNESS))
	# Its processing (photoreal6): the sharpening in the resolve, the JPEG on
	# the finished picture.
	var sharpen: float = _own(settings.sharpen, PRODUCT_SHARPEN) if photo else 0.0
	var jpeg: float = _own(settings.jpeg, PRODUCT_JPEG) if photo else 0.0
	# A photograph's camera draws its own tone curve (photoreal7).
	var tone: float = _own(settings.tone, PRODUCT_TONE) if photo else 0.0
	if not _tracer.begin(picture):
		return null
	var wanted: int = maxi(plan.samples, 1)
	var per_pass: int = 1
	# A sample of a big picture is more than a frame can spare beside the
	# window's: it is given a band of rows at a time until there is room,
	# a quarter of them until the card has timed a pass.
	var rows: int = maxi(picture.y / 4, 1)
	var row: int = 0
	var card_ms: float = 0.0
	# What the card's timing asks for, taken up between whole samples: a
	# sample's bands all get the same count, or rows would differ in how
	# many they have.
	var fit_rows: int = rows
	var fit_per_pass: int = per_pass
	var count: int = mini(per_pass, wanted)
	var shown_at: int = Time.get_ticks_msec()
	_stopping = false
	while _tracer.samples < wanted:
		# Each sample's numbers come from its own index (path_tracer.glsl)
		# and the seed alone, not from how the passes fell: the same
		# settings trace the same picture however fast the card was
		# (lights_probe's "0 px outside the cone").
		_tracer.trace(count, 104729 * settings.seed, row, rows)
		row = 0 if row + rows >= picture.y else row + rows
		_doing("tracing %d samples, %d rows, %.1f ms on the card" % [count, rows, card_ms])
		await get_tree().process_frame
		if _cancelled:
			return null
		# A pass is kept to what the card can spare beside the window's frame,
		# timed on the card itself: the window's frame time says nothing of
		# it while the card has room, and much of the window's own noise.
		var sample_ms: float = _tracer.sample_ms()
		if sample_ms > 0.0:
			var fit: int = floori(pass_ms / sample_ms / float(picture.x))
			fit_rows = clampi(fit, 8, picture.y)
			fit_per_pass = clampi(fit / picture.y, 1, PathTracer.MOST_PER_PASS)
			card_ms = sample_ms * float(picture.x * fit_rows * fit_per_pass)
		if row != 0:
			continue
		rows = fit_rows
		per_pass = fit_per_pass
		count = mini(per_pass, wanted - _tracer.samples)
		var said: String = words if not words.is_empty() else \
			"%d of %d samples" % [_tracer.samples, wanted]
		progress.emit(lerpf(from, to, float(_tracer.samples) / float(wanted)), said)
		if _stopping:
			break
		# Shown as it gets cleaner, a picture a second, in two halves: the
		# dialog draws pieces, and the whole of it is the finished picture.
		if Time.get_ticks_msec() - shown_at > 1000 and _tracer.samples < wanted:
			shown_at = Time.get_ticks_msec()
			var so_far: Image = _tracer.picture(exposure * scale, tonemapper, white, contrast,
				saturation, settings.transparent, true, clean, linear_saturation, lens, sharpen, tone)
			if so_far != null:
				var half: int = picture.y / 2
				piece_done.emit(so_far.get_region(Rect2i(0, 0, picture.x, half)), Vector2i.ZERO)
				piece_done.emit(so_far.get_region(Rect2i(0, half, picture.x, picture.y - half)),
					Vector2i(0, half))
	_stopping = false
	last_samples = _tracer.samples
	last_drawn_at = exposure * scale
	last_mean = _tracer.mean_image() if keep_mean else null
	_doing("reading the picture back")
	var result: Image = _tracer.picture(exposure * scale, tonemapper, white, contrast,
		saturation, settings.transparent, true, clean, linear_saturation, lens, sharpen, tone)
	if result != null and not settings.transparent:
		await get_tree().process_frame
		_doing("converting")
		result.convert(Image.FORMAT_RGB8)
		if jpeg >= 1.0:
			# Off the main thread: a megapixel's JPEG and back is more than a
			# frame can spare. Nothing here touches the picture until it ends.
			_doing("saving as the camera did")
			if OS.has_feature("nothreads"):
				_through_jpeg(result, jpeg)
			else:
				var task: int = WorkerTasks.add(_through_jpeg.bind(result, jpeg), false, "a camera's JPEG")
				while not WorkerThreadPool.is_task_completed(task):
					await get_tree().process_frame
				WorkerTasks.collect(task)
	return result


## [param image], in place, as the camera saved it (photoreal6): through a
## JPEG at [param quality] (1 to 100, Godot's own encoder) and back, its
## blocks and ringing kept. Run on a worker: it touches only [param image].
func _through_jpeg(image: Image, quality: float) -> void:
	var saved: PackedByteArray = image.save_jpg_to_buffer(clampf(quality / 100.0, 0.01, 1.0))
	var back := Image.new()
	if saved.is_empty() or back.load_jpg_from_buffer(saved) != OK:
		return
	back.convert(image.get_format())
	image.copy_from(back)


## What the tracer lights and sees, as path_tracer.glsl's Scene reads it:
## with the model's own lights, unless [param lamps] is false (metering).
## [param caught], when its red is not below 0, is the light the shadow
## catcher shows the backdrop at; [param card] lays a white card for the
## sweep, metering (_meter_card).
func _traced_scene(settings: RenderSettings, plan: Plan, shot: Shot, picture: Vector2i,
		level: float, lamps: bool = true, most: float = 0.0, caught := Color(-1.0, 0.0, 0.0),
		card: bool = false) -> PackedFloat32Array:
	var tan_half: float = tan(deg_to_rad(shot.fov) * 0.5)
	var aspect: float = float(picture.x) / float(maxi(picture.y, 1))
	var across: Vector3 = shot.basis.x * tan_half * aspect
	var up: Vector3 = shot.basis.y * tan_half
	var back: Vector3 = shot.basis.z
	var product: bool = settings.look == "product"
	var data := PackedFloat32Array()
	data.append_array([shot.origin.x, shot.origin.y, shot.origin.z,
		shot.aperture if plan.lens else 0.0])
	data.append_array([across.x, across.y, across.z, 0.0])
	data.append_array([up.x, up.y, up.z, 0.0])
	data.append_array([back.x, back.y, back.z, shot.focus_distance])
	data.append_array([float(picture.x), float(picture.y), float(PathTracer.BOUNCES),
		1.0 if _tracer.has_glass() else 0.0])
	# The sky: a photographed place (the product look's softbox when no
	# place is chosen), or the window's own.
	var place: StudioPanorama = _lit_by
	var tent: bool = _tented(settings)
	if tent:
		place = null
	# A staging (photoreal7): its key stands near the model, and a table's
	# room is a photographed place, all of it (none of the studio's flags).
	var staged: bool = not _stage_of(settings).is_empty() and _photographic(settings)
	var lit_stage: bool = _lit_stage(settings)
	var room_kept: float = _room
	if _stage_room != null:
		place = _stage_room
		room_kept = 1.0
	var energy: float = 0.0
	if place != null:
		energy = HDRI_LEVEL / maxf(place.average, 0.0001)
		if product and settings.lighting == "studio" and _stage_room == null:
			energy *= _ambient
	# A tent's walls are the colour of its paper's light: a warm backdrop in
	# a photograph is a warm light on the model too.
	var sky := Color(_ambient, _ambient, _ambient)
	if tent:
		sky = _paper_tint(settings)
	data.append_array([sky.r, sky.g, sky.b, 1.0 if place != null else 0.0])
	data.append_array([energy, _turn, room_kept, float(PathTracer.PLACE_CELLS.x)])
	var behind: Color = settings.backdrop.srgb_to_linear()
	var beyond: Color = behind * (DARK_BACKDROP if settings.lighting == "dark" else 1.0)
	if caught.r >= 0.0:
		beyond = caught
	data.append_array([beyond.r, beyond.g, beyond.b, 0.0 if settings.transparent else 1.0])
	if card:
		behind = Color(1, 1, 1)
	var dark: bool = settings.backdrop.get_luminance() < 0.2
	var fall: float = 0.0 if not settings.backdrop_gradient or lit_stage \
		else (FALL_DARK if dark else FALL_GRADIENT)
	var radius: float = _bounds.size.length() * 0.5
	data.append_array([level, fall, radius * 0.7, radius * 3.2])
	data.append_array([behind.r, behind.g, behind.b, 1.0 if _backdrop.visible else 0.0])
	var origin: Vector3 = _backdrop.global_position
	data.append_array([origin.x, origin.y, origin.z, float(PathTracer.PLACE_CELLS.y)])
	# The lights: the rig as dressed, the key from anywhere on its area. A
	# photographed place is its own key.
	# A staging's key is its own (below).
	var lights: Array = []
	if tent and not staged and _lights.size() > 0 and _lights[0].visible:
		# The tent's key: a big soft box where the rig's key stands, which the
		# light's turn moves, so each face is lit as a product photograph's
		# are, one side bright and the other in the tent's fill. Large enough
		# that no stud draws a crescent in another's shadow.
		var key_from: Vector3 = _lights[0].get_meta("toward", Vector3.UP)
		var paper: Color = _paper_tint(settings) * TENT_KEY
		lights.append([key_from, TENT_KEY_SPREAD, paper, 1.0])
	elif not tent and not staged and (place == null or (product and settings.lighting == "studio")):
		for n: int in _lights.size():
			var light: DirectionalLight3D = _lights[n]
			if not light.visible or light.light_energy <= 0.0:
				continue
			var toward: Vector3 = light.get_meta("toward", Vector3.UP)
			var energy_here: float = light.light_energy
			var colour: Color = light.light_color * energy_here
			# Shadows where the window's light casts them: the key's alone.
			lights.append([toward, plan.key_spread * 0.5 if n == 0 else 0.0, colour,
				1.0 if light.shadow_enabled else 0.0])
	data.append_array([1.0 if product else 0.0, float(lights.size()), most,
		1.0 if caught.r >= 0.0 else (-1.0 if card else 0.0)])
	# The window's sky (main.tscn's), as its ambient light lights the model.
	var top := Color(0.53, 0.545, 0.565)
	var horizon := Color(0.735, 0.74, 0.75)
	var ground := Color(0.47, 0.47, 0.48)
	var room := Color(0.86, 0.86, 0.87)
	var share: float = 0.85
	if look != null:
		share = look.ambient_light_sky_contribution
		room = look.ambient_light_color
		var sky_material := look.sky.sky_material as ProceduralSkyMaterial \
			if look.sky != null else null
		if sky_material != null:
			top = sky_material.sky_top_color
			horizon = sky_material.sky_horizon_color
			ground = sky_material.ground_bottom_color
	for colour: Color in [top, horizon, ground]:
		var lit: Color = colour.srgb_to_linear() * share + room.srgb_to_linear() * (1.0 - share)
		data.append_array([lit.r, lit.g, lit.b, 0.0])
	for n: int in 4:
		if n < lights.size():
			var row: Array = lights[n]
			var toward: Vector3 = row[0]
			var colour: Color = row[2]
			data.append_array([toward.x, toward.y, toward.z, float(row[1])])
			data.append_array([colour.r, colour.g, colour.b, float(row[3])])
		else:
			data.append_array([0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	# The model's own lights (SceneLights), where they stand on the set now:
	# a turntable's frame has turned them with the model. Each as its raster
	# light is: the same strength, the same fall with distance and the same
	# cone, so the two ways of drawing light it alike.
	var rows: Array = []
	if lamps:
		for node: Light3D in _lamp_nodes:
			if rows.size() >= SceneLights.MOST:
				break
			var light: Dictionary = node.get_meta("lamp", {})
			if light.is_empty():
				continue
			var kind: int = SceneLights.KINDS.find(str(light["kind"]))
			var at: Vector3 = node.global_position
			var aim: Vector3 = -node.global_transform.basis.z.normalized()
			var cone: float = cos(deg_to_rad(float(light.get("cone", 40.0)) * 0.5)) \
				if kind == 1 else -1.0
			var lit: Color = SceneLights.colour_of(light).srgb_to_linear() \
				* SceneLights.energy(light)
			var shadows: bool = bool(light.get("shadows", true)) and not settings.no_shadows
			rows.append([at.x, at.y, at.z, float(kind), aim.x, aim.y, aim.z, cone,
				lit.r, lit.g, lit.b, 1.0 if shadows else 0.0,
				float(light.get("size", 4.0)), SceneLights.EDGE, float(node.get_meta("reach", 1e6)),
				0.0])
	data.append_array([float(rows.size()), _glow, TENT_TOP if tent else 0.0,
		TENT_BOX if tent else 0.0])
	for n: int in SceneLights.MOST:
		if n < rows.size():
			data.append_array(rows[n])
		else:
			var none := PackedFloat32Array()
			none.resize(16)
			data.append_array(none)
	# The product look's wear (photoreal4): age, dust, the backdrop's grain,
	# and what the backdrop is (photoreal5).
	var worn: bool = settings.look == "product"
	var stage: Array = _stage_of(settings)
	var grain: float = _own(settings.paper, PRODUCT_PAPER) if worn and _backdrop.visible else 0.0
	var grain_kind: float = float(settings.surface) if worn else 0.0
	if lit_stage and int(stage[4]) < 2:
		# A staged paper's fibres or desk's specks, always there.
		grain = maxf(grain, 1.0)
		grain_kind = float(stage[4])
	data.append_array([_own(settings.age, PRODUCT_AGE) if worn else 0.0,
		_own(settings.dust, PRODUCT_DUST) if worn else 0.0, grain, grain_kind])
	# The staging (photoreal7): its near key, and what the model stands on.
	if staged:
		var key: Array = _stage_key(settings)
		var at: Vector3 = key[0]
		var light: Color = key[2]
		var centre: Vector3 = _bounds.get_center()
		data.append_array([at.x, at.y, at.z, float(key[1])])
		data.append_array([light.r, light.g, light.b, float(key[3])])
		data.append_array([centre.x, centre.y, centre.z, STAGE_KEY_BEAM])
	else:
		data.append_array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0])
	if lit_stage:
		var mean: Color = _surface_tile(stage)[1]
		data.append_array([1.0, float(stage[4]), float(stage[2]), 1.0 if bool(stage[5]) else 0.0])
		data.append_array([1.0 / mean.r, 1.0 / mean.g, 1.0 / mean.b, float(stage[3])])
	else:
		data.append_array([0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.9])
	data.append_array([_balance.r, _balance.g, _balance.b, 0.0])
	data.append_array([float(_stage_of(settings)[7]) if lit_stage else 0.0, 0.0, 0.0, 0.0])
	# No two parts alike (photoreal8): each part's batch, its handling, each
	# stud's logo (the closest hit reads that one from each part's record).
	data.append_array([_own(settings.batch, PRODUCT_BATCH) if worn else 0.0,
		_own(settings.handling, PRODUCT_HANDLING) if worn else 0.0,
		_own(settings.studs, PRODUCT_STUDS) if worn else 0.0, 0.0])
	# The wear hands leave (photoreal9).
	data.append_array([_own(settings.rubbed, PRODUCT_RUBBED) if worn else 0.0, 0.0, 0.0, 0.0])
	# The stage matched to the photographs (photoreal10), read only by the
	# shader's marks version.
	var matched: Dictionary = _matched(settings) if worn else {}
	var key_way: Vector3 = _stage_key_way(settings)
	data.append_array([float(matched.get("table", 0.0)), float(matched.get("table_light", 0.0)),
		maxf(_bounds.size.length() * 0.5, 10.0), float(matched.get("fill", 0.0))])
	data.append_array([key_way.x, key_way.y, key_way.z, 0.0])
	# The large source (photoreal14), read only by the shader's marks version.
	data.append_array(_source_rows(settings, shot))
	# Moulded ABS's own unevenness (photoreal15): the polish split and the
	# scuffs, read only by the marks version (the peel and the sink go with
	# each part's record).
	var breakup: Array = _breakup(settings) if worn else [0.0, 0.0, 0.0, 0.0]
	data.append_array([float(breakup[0]), float(breakup[1]), float(breakup[2]), float(breakup[3])])
	# A set photographed (photoreal19), read only by the photo version.
	data.append_array([_floor_of(settings), 0.0, 0.0, 0.0])
	return data


## The floor a set photographed stands on (photoreal19) that [param
## settings] ask for, 0 for none: only in the product look, on the bare
## seamless paper the judge saw it on, where the sweep is the shadow
## catcher with no table's relief and no surface of its own. A lit stage
## is its own, and so is the gallery card's desk (CardPhoto.LOOK, a table
## on the catcher), which was not judged with it.
func _floor_of(settings: RenderSettings) -> float:
	if settings.look != "product" or not _catches(settings) or settings.surface != 0 \
			or _own(settings.table, PRODUCT_TABLE) > 0.0:
		return 0.0
	return maxf(_own(settings.floor, PRODUCT_FLOOR), 0.0)


## How bright the large source (photoreal14) that [param settings] ask for
## is, in the sky's units: 0 for none. Where nobody asks, PRODUCT_SOURCE on a
## table under the studio's light, and none elsewhere. Only where the
## product look is drawn as a camera draws (on a backdrop).
func _source_level(settings: RenderSettings) -> float:
	if settings.look != "product" or not _photographic(settings):
		return 0.0
	var fallback: float = PRODUCT_SOURCE if _table(settings) and settings.lighting == "studio" else 0.0
	return maxf(_own(settings.source, fallback), 0.0)


## The large source as path_tracer.glsl's Scene reads it: the way to its
## middle and its light, its face's right and half width, its up and half
## height (tangents), its colour and its edges' softness, and how much darker
## its edges are. It stands where the camera sees it above and behind the
## model, turning and rising with the view as a photographer moves the box
## with the camera, so a flat top always mirrors it.
func _source_rows(settings: RenderSettings, shot: Shot) -> PackedFloat32Array:
	var level: float = _source_level(settings)
	if level <= 0.0:
		var none := PackedFloat32Array()
		none.resize(20)
		return none
	# Into the picture along the floor (path_tracer.glsl's tent_frame): a
	# camera looking straight down has the picture's up as its way in.
	var back: Vector3 = shot.basis.z
	var up: Vector3 = shot.basis.y
	var ahead := Vector3(-back.x, 0.0, -back.z) + Vector3(up.x, 0.0, up.z)
	var into: Vector3 = ahead.normalized() if ahead.length_squared() > 1e-8 else Vector3(0.0, 0.0, -1.0)
	var right := Vector3(-into.z, 0.0, into.x)
	var tall_deg: float = clampf(_own(settings.source_tall, SOURCE_TALL), 1.0, 170.0)
	var looks_down: float = rad_to_deg(asin(clampf(back.y, -1.0, 1.0)))
	var mirrored: float = clampf(looks_down, maxf(SOURCE_RISE_LOW, tall_deg * 0.5 + 3.0),
		maxf(SOURCE_RISE_HIGH, tall_deg * 0.5 + 3.0))
	var rise: float = deg_to_rad(_own(settings.source_rise, mirrored))
	var turn: float = deg_to_rad(_own(settings.source_turn, SOURCE_TURN))
	var flat: Vector3 = into * cos(turn) + right * sin(turn)
	var middle: Vector3 = (flat * cos(rise) + Vector3.UP * sin(rise)).normalized()
	var across: Vector3 = (right * cos(turn) - into * sin(turn)).normalized()
	var face_up: Vector3 = across.cross(middle).normalized()
	var wide: float = tan(deg_to_rad(clampf(_own(settings.source_wide, SOURCE_WIDE), 1.0, 170.0)) * 0.5)
	var tall: float = tan(deg_to_rad(tall_deg) * 0.5)
	var tint: Color = _paper_tint(settings) if _tented(settings) else Color(1, 1, 1)
	return PackedFloat32Array([middle.x, middle.y, middle.z, level,
		across.x, across.y, across.z, wide,
		face_up.x, face_up.y, face_up.z, tall,
		tint.r, tint.g, tint.b, SOURCE_EDGE,
		clampf(_own(settings.source_fall, SOURCE_FALL), 0.0, 1.0),
		clampf(_own(settings.source_spill, SOURCE_SPILL), 0.0, 1.0), 0.0, 0.0])


## The stage matched to the photographs by measure (photoreal10) that
## [param settings] ask for, each lever above 0 by name: {} draws none, and
## the picture is then traced by the shader's plain version. A leather's or
## a stone's surface (RenderSettings.surface 2 or 3) is drawn only with a
## table's relief; without one it is a paper's fibres, as before.
func _matched(settings: RenderSettings) -> Dictionary:
	var out: Dictionary = {}
	if settings.look != "product":
		return out
	for pair: Array in [["table", settings.table, PRODUCT_TABLE],
			["table_light", settings.table_light, PRODUCT_TABLE_LIGHT],
			["fill", settings.fill, PRODUCT_FILL]]:
		var value: float = _own(float(pair[1]), float(pair[2]))
		if value > 0.0:
			out[pair[0]] = value
	# The large source (photoreal14) is drawn by the same version.
	if _source_level(settings) > 0.0:
		out["source"] = _source_level(settings)
	# So is moulded ABS's own unevenness (photoreal15).
	var breakup: Array = _breakup(settings)
	for i: int in 4:
		if float(breakup[i]) > 0.0:
			out[["polish", "scuff", "peel", "sink"][i]] = breakup[i]
	return out


## Moulded ABS's own unevenness (photoreal15) that [param settings] ask for,
## as the shader's breakup row reads it: the polish split, the scuffs, the
## peel and the sink, each 0 for none. Only in the product look.
func _breakup(settings: RenderSettings) -> Array:
	if settings.look != "product":
		return [0.0, 0.0, 0.0, 0.0]
	return [maxf(_own(settings.polish, PRODUCT_POLISH), 0.0), maxf(_own(settings.scuff, PRODUCT_SCUFF), 0.0),
		maxf(_own(settings.peel, PRODUCT_PEEL), 0.0), maxf(_own(settings.sink, PRODUCT_SINK), 0.0)]


## Which way the staged key stands from the model (_stage_key's), for the
## light that falls off across a table (photoreal10).
func _stage_key_way(settings: RenderSettings) -> Vector3:
	var toward: Vector3 = _lights[0].get_meta("toward", Vector3.UP) if not _lights.is_empty() \
		else Vector3.UP
	var flat := Vector3(toward.x, 0.0, toward.z)
	if flat.length() < 0.01:
		flat = Vector3(0.0, 0.0, 1.0)
	var rise: float = deg_to_rad(_own(settings.key_rise, STAGE_KEY_RISE))
	return (flat.normalized() * cos(rise) + Vector3.UP * sin(rise)).normalized()


## A product look's setting, or the look's own where none is asked (below 0).
static func _own(asked: float, fallback: float) -> float:
	return asked if asked >= 0.0 else fallback


## Whether the traced picture's sweep is a shadow catcher (photoreal2): the
## product look on a backdrop, as a product photograph's white seamless is
## its own colour wherever the model casts no shadow, with no line where the
## floor meets the wall.
func _catches(settings: RenderSettings) -> bool:
	return _photographic(settings) and not _lit_stage(settings)


## Whether the traced picture is drawn as a camera draws (photoreal2): the
## product look on a backdrop, metered from a white card where the model
## stands, through the camera's curve, with its marks. Its backdrop is a
## shadow catcher unless a stage lights it ([method _lit_stage]).
func _photographic(settings: RenderSettings) -> bool:
	return settings.look == "product" and _backdrop.visible and not settings.transparent \
		and settings.lighting != "dark"


## The staging asked for (STAGES), or [] for the seamless as before.
static func _stage_of(settings: RenderSettings) -> Array:
	return STAGES.get(settings.stage, []) if settings.look == "product" else []


## Whether a stage's surface is lit as any surface is (all but "white").
func _lit_stage(settings: RenderSettings) -> bool:
	return not _stage_of(settings).is_empty() and settings.stage != "white" \
		and _backdrop.visible and not settings.transparent and settings.lighting != "dark"


## Whether the stage is a table: flat, the room beyond it.
func _table(settings: RenderSettings) -> bool:
	return _lit_stage(settings) and bool(_stage_of(settings)[5])


## Whether the traced product look is lit by a light tent (TENT_TOP).
func _tented(settings: RenderSettings) -> bool:
	return settings.look == "product" and settings.lighting == "studio" and _backdrop.visible \
		and settings.backdrop.get_luminance() >= TENT_BACKDROP and not _table(settings)


## The photographed place a staged table's room is (photoreal7): the light
## asked for when it is one, otherwise STAGE_ROOM.
func _room_of(settings: RenderSettings) -> StudioPanorama:
	var key: String = settings.lighting if HDRIS.has(settings.lighting) else STAGE_ROOM
	if not _panoramas.has(key):
		var made: StudioPanorama = StudioPanorama.read(WebPacks.hdri(str(HDRIS[key][1])))
		if made == null:
			return null
		_panoramas[key] = made
	return _panoramas[key]


## A stage's photographed tile and its mean colour in linear light, as
## _read_surfaces read it: [Image or null, Color].
func _surface_tile(stage: Array) -> Array:
	var path: String = str(stage[1]) if stage.size() > 1 else ""
	return _surfaces.get(path, [null, Color(1, 1, 1)])


## The stage's tile read (photoreal7), once: a 2048-pixel JPEG decoded, made
## RGBA and its mean taken is more than a frame can spare, so off the main
## thread. Nothing reads what it fills until it ends.
func _read_surfaces(stage: Array) -> void:
	var path: String = str(stage[1]) if stage.size() > 1 else ""
	if path.is_empty() or _surfaces.has(path):
		return
	var read: Dictionary = {}
	if OS.has_feature("nothreads"):
		_read_surface(path, read)
	else:
		var task: int = WorkerTasks.add(_read_surface.bind(path, read), false, "a surface's picture")
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerTasks.collect(task)
	_surfaces[path] = [read.get("image"), read.get("mean", Color(1, 1, 1))]


## [param path]'s picture (imported as an Image) into [param read]: "image",
## RGBA8, and "mean", its colour in linear light.
func _read_surface(path: String, read: Dictionary) -> void:
	var image: Image = ResourceLoader.load(path, "Image") as Image
	if image == null:
		return
	image = image.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var small: Image = image.duplicate() as Image
	small.resize(32, 32, Image.INTERPOLATE_BILINEAR)
	var sum := Vector3.ZERO
	for y: int in 32:
		for x: int in 32:
			var c: Color = small.get_pixel(x, y).srgb_to_linear()
			sum += Vector3(c.r, c.g, c.b)
	sum /= 1024.0
	read["image"] = image
	read["mean"] = Color(maxf(sum.x, 0.01), maxf(sum.y, 0.01), maxf(sum.z, 0.01))


## The staged key (photoreal7): where it stands, its radius and the light it
## gives the model's middle, from the rig's key turned as the light is, at
## the stage's height and distance. [position, radius, light (linear), the
## distance that light is at].
func _stage_key(settings: RenderSettings) -> Array:
	var radius: float = maxf(_bounds.size.length() * 0.5, 10.0)
	var centre: Vector3 = _bounds.get_center()
	var way: Vector3 = _stage_key_way(settings)
	var far: float = _own(settings.key_far, STAGE_KEY_FAR) * radius
	var size: float = _own(settings.key_size, STAGE_KEY_SIZE) * radius
	var tint: Color = _paper_tint(settings) if _tented(settings) else Color(1, 1, 1)
	var light: Color = tint * TENT_KEY * _own(settings.key_share, STAGE_KEY_SHARE)
	# Beside a large source (photoreal14), as much of the key as it keeps.
	if _source_level(settings) > 0.0:
		light *= clampf(_own(settings.source_key, SOURCE_KEY), 0.0, 1.0)
	return [centre + way * far, minf(size, far * 0.9), light, far]


## The colour of a tent's light: its paper's, at its brightest channel 1.
## A paper darker than PAPER_WHITE is grey card, and the light white.
static func _paper_tint(settings: RenderSettings) -> Color:
	if settings.backdrop.get_luminance() < PAPER_WHITE:
		return Color(1, 1, 1)
	var paper: Color = settings.backdrop.srgb_to_linear()
	var most: float = maxf(paper.r, maxf(paper.g, paper.b))
	return Color(paper.r / most, paper.g / most, paper.b / most) if most > 0.0 else Color(1, 1, 1)


## The exposure (a scale on [param exposure]) that draws a white card where
## the model stands at the photograph's white: the backdrop's own colour
## when it is paper (PAPER_WHITE or lighter), white otherwise. The card is
## the sweep, lit by the set's light, read where nothing shadows it; the
## picture is read dimmed, so the card is never past white, and its light
## worked back from the tone curve (_untoned). 0 when cancelled.
func _meter_card(settings: RenderSettings, plan: Plan, shot: Shot, small: Vector2i,
		exposure: float, tonemapper: int, white: float, contrast: float,
		saturation: float) -> float:
	var goal: float = settings.backdrop.get_luminance()
	if goal < PAPER_WHITE:
		goal = 1.0
	# The card's light is the paper's own lightness in linear light, before
	# the curve: a white paper's card is 1, PHOTO_EV over, and the camera's
	# shoulder draws it a little short of white (the backdrop round the model
	# is drawn at its own colour whatever, the shadow catcher).
	var want: float = Color(goal, goal, goal).srgb_to_linear().r * white * pow(2.0, PHOTO_EV)
	var scale: float = 1.0
	const DIM := 0.2
	for round: int in 2:
		_tracer.scene = _traced_scene(settings, plan, shot, small, 1.0, false, 0.0,
			Color(-1.0, 0.0, 0.0), true)
		if not _tracer.begin(small):
			return 0.0
		_doing("metering")
		for _part: int in 4:
			_tracer.trace(12, round)
			await get_tree().process_frame
			if _cancelled:
				return 0.0
		var seen: Image = _tracer.picture(exposure * scale * DIM, tonemapper, white, contrast,
			saturation, true, false)
		# A staged key falls off across the card (photoreal7): it is read
		# round the model, not where the light is nearest.
		var card: float = _open_floor(seen, 0.9 if _stage_of(settings).is_empty() else 0.6)
		# Its colour from the second, exposed as metered: once, to keep the
		# frame short (a quarter of its pixels, about 2 ms).
		if round == 1:
			_card_colour = _floor_colour(seen, card)
		if card <= 0.0005:
			break
		var light: float = _untoned(card, tonemapper, white, contrast) / (exposure * scale * DIM)
		scale = want / maxf(light * exposure, 1e-6)
	return scale


## The open floor's lightness in a metering picture: the lightest tenth of
## what is not the model, where nothing shadows the card ([param share] of
## the way up its levels).
static func _open_floor(image: Image, share: float = 0.9) -> float:
	if image == null:
		return 0.0
	var levels := PackedFloat32Array()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			var seen: float = Color(c.r, c.g, c.b).get_luminance()
			# Not the model, and not the sweep's rise, which the card's
			# picture leaves black (path_tracer.glsl).
			if c.a < 0.1 and seen > 0.002:
				levels.append(seen)
	if levels.is_empty():
		return 0.0
	levels.sort()
	return levels[int(float(levels.size() - 1) * share)]


## The white card's colour in a metering picture (photoreal7): its pixels
## near [param level] (what _open_floor read), in linear light, their
## luminance brought to 1. The picture is dimmed below the camera curve's
## knee, so its sRGB undone is the light.
static func _floor_colour(image: Image, level: float) -> Color:
	var sum := Vector3.ZERO
	if image == null or level <= 0.0:
		return Color(1, 1, 1)
	# Every other pixel each way: the card's colour is the same across it.
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			var c: Color = image.get_pixel(x, y)
			var seen: float = Color(c.r, c.g, c.b).get_luminance()
			if c.a < 0.1 and absf(seen - level) < level * 0.15:
				var lin: Color = Color(c.r, c.g, c.b).srgb_to_linear()
				sum += Vector3(lin.r, lin.g, lin.b)
	var lum: float = 0.2126 * sum.x + 0.7152 * sum.y + 0.0722 * sum.z
	if lum <= 0.0:
		return Color(1, 1, 1)
	return Color(maxf(sum.x / lum, 0.05), maxf(sum.y / lum, 0.05), maxf(sum.z / lum, 0.05))


## A grey's light (exposed) as path_tracer_resolve.glsl draws it, 0 to 1:
## the tone curve at [param white], to sRGB, the contrast after.
static func _toned(light: float, tonemapper: int, white: float, contrast: float) -> float:
	var c: float = 0.0
	if tonemapper > 3:
		c = light / white
		if c > CAMERA_KNEE:
			var t: float = minf((c - CAMERA_KNEE) / (CAMERA_TOP - CAMERA_KNEE), 1.0)
			c = CAMERA_KNEE + (1.0 - CAMERA_KNEE) * (2.0 * t - t * t)
	elif tonemapper > 2:
		c = _aces(light * 1.8) / _aces(white * 1.8)
	else:
		c = _filmic(light) / _filmic(white)
	c = clampf(c, 0.0, 1.0)
	c = 12.92 * c if c < 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055
	return lerpf(0.5, c, contrast)


## The light (exposed) [method _toned] draws as [param shown].
static func _untoned(shown: float, tonemapper: int, white: float, contrast: float) -> float:
	# The curve's top: 1.0 itself is never below it in floating point
	# (1.055 - 0.055), and the search ran on to its end, which drew a white
	# backdrop's model a stop too light.
	var top: float = white * (CAMERA_TOP if tonemapper > 3 else 1.0)
	if shown >= _toned(top, tonemapper, white, contrast) - 1e-6:
		return top
	var low: float = 0.0
	var high: float = top
	for _step: int in 48:
		var middle: float = (low + high) * 0.5
		if _toned(middle, tonemapper, white, contrast) < shown:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


static func _filmic(x: float) -> float:
	const A := 0.22 * 4.0
	const B := 0.30 * 2.0
	const C := 0.10
	const D := 0.20
	const E := 0.01
	const F := 0.30
	return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F


static func _aces(c: float) -> float:
	return (c * (c + 0.0245786) - 0.000090537) / (c * (0.983729 * c + 0.432951) + 0.238081)


## The model's mean lightness in a metering picture: its pixels are those
## the tracer saw it in (alpha).
static func _mean_covered(image: Image) -> float:
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


## How light the sweep is in a metering picture: the brighter part of what
## is not the model, as _meter_floor reads the raster's.
static func _floor_level(image: Image) -> float:
	if image == null:
		return 0.0
	var levels := PackedFloat32Array()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a < 0.1:
				levels.append(Color(c.r, c.g, c.b).get_luminance())
	if levels.is_empty():
		return 0.0
	levels.sort()
	return levels[int(float(levels.size() - 1) * 0.7)]


## Stop tracing and keep the picture as it is: a path-traced picture is a
## picture at any count of samples, only noisier.
func finish_now() -> void:
	if _busy:
		_stopping = true


## How many samples the picture being traced has so far: 0 when none is.
func samples_traced() -> int:
	return _tracer.samples if _busy and _tracer != null else 0


## Whether the last picture was path traced.
func traced_last() -> bool:
	return _traced_last


## How long a pass of the path tracer may take of a frame: less for the
## queue (RenderQueue), which draws beside a window still in use.
var pass_ms: float = PathTracer.PASS_MS
var _tracer: PathTracer = null
var _stopping: bool = false
var _traced_last: bool = false
## What the last _dress lit the set by: the place (or the product look's
## softbox), how much of its room is kept, its turn and the ambient light.
var _lit_by: StudioPanorama = null
## A staged table's room (photoreal7, _room_of), what the tracer is lit by
## in place of _lit_by; and the stages' tiles read (_surface_tile).
var _stage_room: StudioPanorama = null
var _surfaces: Dictionary = {}
## A staged picture's white balance (photoreal7): each channel's gain, and
## the white card's colour the metering last read (linear, its luminance 1).
var _balance := Color(1, 1, 1)
var _card_colour := Color(1, 1, 1)
var _room: float = 1.0
var _turn: float = 0.0
var _ambient: float = 0.4
## The model's lightness in the window's own light, metered in _prepare.
var _wanted_lightness: float = 0.0


func _exit_tree() -> void:
	if _tracer != null:
		_tracer.release()
		_tracer = null


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
		var made: StudioPanorama = StudioPanorama.read(WebPacks.hdri(str(HDRIS[lighting][1])))
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
	_quick_count += 1
	if _quick_count > 1:
		return
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
	_quick_count = maxi(_quick_count - 1, 0)
	if _quick_count > 0:
		return
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
		RenderingServer.positional_soft_shadow_filter_set_quality(
			int(ProjectSettings.get_setting(
				"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 2))
				as RenderingServer.ShadowQuality)
	if not _quickened:
		return
	_quickened = false
	if _was_vsync != DisplayServer.VSYNC_DISABLED:
		DisplayServer.window_set_vsync_mode(_was_vsync)
	Engine.max_fps = _was_max_fps


## Renders going at once, File, Render…'s and the queue's (RenderQueue):
## the window is put back as it was when the last of them ends, not as the
## other found it.
static var _quick_count: int = 0
static var _was_low_processor: bool = false
static var _quickened: bool = false
static var _was_vsync: int = DisplayServer.VSYNC_ENABLED
static var _was_max_fps: int = 0
