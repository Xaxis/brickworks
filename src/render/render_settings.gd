## What a render is asked for: File, Render… (RenderDialog) fills one in and
## StudioRender draws it.
##
## Everything here is a choice a person makes in the dialog, in the words
## of a photographer's set: how good, how big, on what, lit how, from where
## and through what lens.
class_name RenderSettings
extends RefCounted

enum Quality {
	## The window's own look, at the size asked for: one frame.
	QUICK,
	## Global illumination, ambient occlusion and soft shadows where the
	## renderer has them (the desktop's), a contact shadow everywhere.
	GOOD,
	## Path traced where the graphics card traces rays (PathTracer): light
	## followed bounce by bounce, so shadows soften as they should, the floor
	## lights the model, and glass tints what is behind it. Elsewhere many
	## frames averaged: every one jittered under the pixel, lit from another
	## point of an area light and seen through another point of the lens, so
	## edges are smooth, shadows soft and the depth of field real.
	BEST,
}

## The backdrops a render is offered by name, as File, Render… and
## render_model name them: [colour (sRGB), lit as a studio's, falling away
## from the model (backdrop_gradient)].
const BACKDROPS: Dictionary = {
	"white": [Color(1, 1, 1), false],
	"gradient": [Color(0.96, 0.965, 0.975), true],
	"grey": [Color(0.74, 0.75, 0.77), false],
	"dark": [Color(0.05, 0.055, 0.065), true],
}
## The looks, by name: words for each.
const LOOKS: Dictionary = {
	"window": "As in the window",
	"product": "Product",
	# lineart (APP_UX7 #22): the model inked as a person would draw it (LineArt).
	"lineart": "Line art",
	"comic": "Comic",
}

var quality: int = Quality.GOOD
## How the plastic and the set are drawn: "window", as the window draws
## them, or "product", as a product shot is lit and finished (StudioRender:
## plastic with a gloss and rounded edges, clear parts that tint what is behind,
## a key, fill and rim over a studio's light, and AgX's film-like tones); or
## inked (LineArt): "lineart", black lines on white with the shade in halftone
## dots, and "comic", the same lines over the plastic's own flat colours.
var look: String = "window"
var size: Vector2i = Vector2i(1920, 1080)
## Nothing behind the model: the backdrop is not drawn, the contact shadow
## is, as a shadow on nothing.
var transparent: bool = false
## The sweep's colour, as a person picks it (sRGB).
var backdrop: Color = Color(1, 1, 1)
## The sweep lit like a studio's, brightest under the model and falling
## away towards the edges of the picture, rather than one even colour.
var backdrop_gradient: bool = false
## "studio" for three lights, or one of StudioRender.HDRIS, or "dark": the
## studio put out, its ambient a glimmer, the model's own lights
## (SceneLights) and its glowing plastics all that lights it (lights,
## APP_UX5 #7).
var lighting: String = "studio"
## Which way the light comes from, turned round the model, in degrees.
var light_turn: float = 0.0
var contact_shadow: bool = true
## One of StudioRender.VIEWS: "current" is where the window looks from.
var view: String = "hero"
## On a full-frame camera; the short side of the picture is 24 mm.
var focal_mm: float = 50.0
## The lens's f-number; 0 for everything sharp. Only Best has a lens wide
## enough to blur.
var f_stop: float = 0.0
## Where the focus is, across the model's depth: 0 its nearest point,
## 1 its farthest.
var focus: float = 0.5
## Frames averaged for Best, or where it is path traced its samples, each
## a pass over every pixel; 0 for this platform's own number.
var samples: int = 0
## Best path traced where the card can. False keeps it frames averaged,
## for a probe to compare the two.
var traced: bool = true
## Which samples a path-traced picture takes: another number traces
## others, for a probe to measure the noise against a picture of its own.
var seed: int = 0
## For a turntable: how many pictures round, and how many a second.
var frames: int = 36
var fps: int = 24
## For an animation of a motion: framed on what its parts sweep through the
## whole of it ("framed on what moves"), from the view's direction, rather
## than as the view is ("as I see it").
var on_what_moves: bool = false
## The key light casts no shadow. For a probe, to measure the shadow by
## what taking it away changes.
var no_shadows: bool = false
## The product look's camera (photoreal4), path traced on a backdrop: its
## sensor's noise, in 8-bit levels at mid grey as a photograph's ISO gives it
## (none on a white that is white); its lens's darkening towards the corners,
## the share of the light lost at a corner; and its colour fringes, pixels at a
## corner, red out and blue in. Below 0, the camera's own (StudioRender
## PRODUCT_GRAIN, PRODUCT_VIGNETTE, PRODUCT_ABERRATION). The photo bench
## matches each to its photograph (tools/photoreal/shots.json).
var grain: float = -1.0
var vignette: float = -1.0
var aberration: float = -1.0
## How soft that camera draws an edge (0 the picture's own pixels, 1 a third
## of each pixel's light spread to its neighbours); below 0, PRODUCT_SOFTNESS.
var softness: float = -1.0
## That camera's own processing (photoreal6), as a phone's or a compact's
## picture has been through it before anyone sees it: its sharpening, the
## share of an edge's step added back (an unsharp mask a pixel and a bit
## wide, its halos), and the JPEG it saved, at this quality (1 to 100; 0 for
## none). Below 0, PRODUCT_SHARPEN and PRODUCT_JPEG. The photo bench matches
## each to its photograph's (tools/photoreal/shots.json).
var sharpen: float = -1.0
var jpeg: float = -1.0
## The product look's wear (photoreal4), path traced: how played-with the
## parts are (0 new, 1 decades: whites and greys yellowed, each part its own
## amount), the dust on their tops (0 none, 1 a shelf's year), and how much
## the backdrop shows a paper's or a table's grain and uneven light (0 a
## cut-out's seamless). Below 0, the look's own (StudioRender PRODUCT_AGE,
## PRODUCT_DUST, PRODUCT_PAPER).
var age: float = -1.0
var dust: float = -1.0
var paper: float = -1.0
## The plastic as a person picks it (photoreal26), in the product look at
## Best, path traced: "new", straight from the box, or "played", a set
## played with for years: whites and greys yellowed, each part handled and
## seated its own way, dust on its tops (StudioRender.PLAYED_*, photoreal25's
## wear and age). An age, dust, handling or seating asked for above wins.
const PLASTICS: Dictionary = {"new": "New", "played": "Played with"}
var plastic: String = "new"
## What that grain is (photoreal5), for the photo bench to match the surface
## each photograph's parts stand on: 0 a paper's or a card's fibres, 1 a
## matte desk's specks and smudges; and drawn by [member table]
## (photoreal10), 2 a leather desk pad, 3 a stone counter.
var surface: int = 0
## A photograph's staging (photoreal7), Best path traced in the product look:
## one of StudioRender.STAGES (what the model stands on, lit as any surface
## is, under a key that stands near the model so its light falls off across
## the model and the surface), or "" for the seamless as before.
var stage: String = ""
## That staging's key: how high it stands (degrees), how far from the
## model's middle and how big (the model's radii), how bright against the
## room's light. Below 0, StudioRender's STAGE_KEY_RISE, _FAR, _SIZE and
## _SHARE; the photo bench fits each to its photograph.
var key_rise: float = -1.0
var key_far: float = -1.0
var key_size: float = -1.0
var key_share: float = -1.0
## That staged photograph's camera (photoreal7): how far its tone curve bends
## the picture (0 the light's own sRGB, 1 a camera JPEG's S), and how much of
## a white card's cast where the model stands its white balance takes out
## (0 none, 1 all). Below 0, StudioRender's PRODUCT_TONE and PRODUCT_BALANCE.
var tone: float = -1.0
var balance: float = -1.0
## How far each part sits from exactly in place, as a built set's never sit
## quite square (0 exactly, 1 up to PathTracer.SEAT_SHIFT off and SEAT_TURN
## degrees turned); below 0, PRODUCT_SEATING.
var seating: float = -1.0
## No two parts alike (photoreal8), path traced in the product look: how far
## each part's colour strays from the next of its colour, by its batch and
## its age (0 none, 1 as far as the photographed sets' parts do); how
## unevenly the parts have been handled, some scuffed and dulled and most
## not (0 none, 1 as the photographed sets'); and how far each stud's logo
## and top differ from the next (0 none, 1 some rubbed nearly flat). Below
## 0, StudioRender's PRODUCT_BATCH, PRODUCT_HANDLING and PRODUCT_STUDS.
var batch: float = -1.0
var handling: float = -1.0
var studs: float = -1.0
## That seating as LEGO's own play lets a part sit (photoreal8): its turn
## about the vertical kept to the stud grid's and its slide across a little
## wider, as measured from above (0 as photoreal4 drew it, 1 as measured).
## Below 0, StudioRender's PRODUCT_PLAY.
var play: float = -1.0
## How much handled wear gathers where fingers and stacking touch
## (photoreal9), path traced in the product look: the body's edges, each
## stud's rim and wall, dust at each stud's foot, each part its own (0 none,
## 1 as the bench's black 2x4 shows it). Below 0, StudioRender's
## PRODUCT_RUBBED.
var rubbed: float = -1.0
## The stage matched to the photographs by measure (photoreal10), path traced
## in the product look on a backdrop: the table's own relief, a leather's
## cells, a stone's grains, a desk's laminate (0 none, 1 as measured; which
## table is [member surface]); how far the light that falls off across the
## table stands from the model (its radii, 0 none); how much the shade's fill
## is tinted as daylight is, by as much of the light as the model keeps from
## it (0 none, 1 as measured). Below 0, StudioRender's PRODUCT_TABLE,
## _TABLE_LIGHT and _FILL.
var table: float = -1.0
var table_light: float = -1.0
var fill: float = -1.0
## Moulded edges (photoreal13), path traced in the product look: each edge's
## rounding straying along it, each part its own way, with a nick here and
## there, and a slope's face rounded into the part's ends; 0 the same radius
## everywhere, 1 as the photographs show it. Below 0, StudioRender's
## PRODUCT_EDGE.
var edge: float = -1.0
## How much narrower across than the grid each part is drawn, in LDU
## (photoreal30), path traced in the product look: a real part is moulded a
## little under its grid (0.5 LDU, 0.2 mm), so parts side by side leave a
## slot. 0 the grid's own size. Below 0, StudioRender's PRODUCT_CLEARANCE.
var clearance: float = -1.0
## How many stops brighter than the metered white card the product look on
## a backdrop is exposed (photoreal30): a high-key product photograph's
## white parts are as bright as its paper. Below 0, StudioRender's
## PRODUCT_HIGH_KEY.
var high_key: float = -1.0
## A large bright source the glossy tops mirror (photoreal14), path traced in
## the product look on a backdrop: a softbox or a window card standing above
## and behind the model as the camera sees it, sharp-edged, the tent or the
## room kept round it for the fill. [member source] is its light in the
## sky's units (0 none); [member source_rise] how high its middle stands
## (degrees), [member source_turn] how far round from straight behind the
## model (degrees to the right, 0 to 360: 180 stands it in front, behind the
## camera), [member source_wide] and
## [member source_tall] how big it is seen from the model (degrees),
## [member source_fall] how much darker its edges are than its middle (0
## even, 1 dark at the corners), and [member source_key] how much of a
## staged table's near key stays with it (0 none, 1 all). Below 0,
## StudioRender's PRODUCT_SOURCE (on a table under the studio's light,
## photoreal16; none elsewhere) and SOURCE_*; [member source_rise] below 0
## stands it where a flat top mirrors it, as high as the camera looks down.
var source: float = -1.0
var source_rise: float = -1.0
var source_turn: float = -1.0
var source_wide: float = -1.0
var source_tall: float = -1.0
var source_fall: float = -1.0
var source_key: float = -1.0
## How much of the large source a staged table mirrors (photoreal14b), 0 to
## 1: 0 lit by it but no glare from it, so the table keeps its own colour.
## Below 0, StudioRender's SOURCE_SPILL.
var source_spill: float = -1.0
## Moulded ABS is never a perfect mirror (photoreal15), path traced in the
## product look: [member peel] its skin's orange-peel waviness, so every
## reflection in it wobbles; [member sink] how far it dips round each stud's
## foot and over each tube, where the plastic is thickest; [member polish]
## how much sharper the mould's polished tops mirror than its satin sides,
## with faint polishing lines across a top; and [member scuff] a few short
## hairline scratches and pits on each part. Each 0 none, 1 as measured on
## the photo bench's close-ups. Below 0, StudioRender's PRODUCT_PEEL,
## PRODUCT_SINK, PRODUCT_POLISH and PRODUCT_SCUFF.
var peel: float = -1.0
var sink: float = -1.0
var polish: float = -1.0
var scuff: float = -1.0
## A set photographed (photoreal19), path traced in the product look on the
## shadow catcher: the floor it stands on as a product photograph's (a glossy
## sweep exposed past white, its shade cool and coloured by the model, the
## model faintly mirrored in it). 0 the catcher as before, 1 as the set
## photographs show it; below 0, StudioRender's PRODUCT_FLOOR.
var floor: float = -1.0
## That floor fitted to the set photographs' stage (photoreal26): how much of
## the tent's soft boxes' light and of its key's the floor shows (0 none, 1
## all), how far past white it is exposed (1 none), its shade's colour (0 a
## daylight fill's blue, 1 the photographs' lavender), how much of the light
## the parts bounce down it shows, and its gloss (reflectance head on and
## roughness). Below 0, StudioRender's PRODUCT_FLOOR_*.
var floor_boxes: float = -1.0
var floor_over: float = -1.0
var floor_key: float = -1.0
var floor_shade: float = -1.0
var floor_bounce: float = -1.0
var floor_f0: float = -1.0
var floor_rough: float = -1.0
## Where the window looked from when the render was asked for, kept for
## a render drawn later (RenderQueue): the "current" view is then that
## one, not wherever the window has turned since. Unset while eye_fov is 0.
var eye_transform: Transform3D = Transform3D()
var eye_fov: float = 0.0
var eye_orthogonal: bool = false
var eye_focus: Vector3 = Vector3.ZERO
## A view saved with the model (SavedViews) the picture is from, by its name,
## or "": the eye above is then that view's, with [member view] "current", so
## a render of it is drawn from there whatever the window looks at.
var saved_view: String = ""


## Keep where [param camera] looks from now, and what it looks at.
func keep_eye(camera: Camera3D) -> void:
	eye_transform = camera.global_transform
	eye_fov = camera.fov
	eye_orthogonal = camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	eye_focus = camera.call("focus_now") if camera.has_method("focus_now") \
		else camera.global_position - camera.global_transform.basis.z * 100.0


## Draw from [param kept], a view saved with the model (SavedViews), as the
## window looks from it: [param camera], the window's, for its lens and its
## limits. The camera is left where it is.
func keep_view(kept: Dictionary, camera: Camera3D) -> void:
	view = "current"
	saved_view = str(kept["name"])
	eye_transform = SavedViews.eye_of(kept, camera)
	eye_fov = camera.fov if camera != null else 45.0
	eye_orthogonal = bool(kept.get("square", false))
	eye_focus = SavedViews.focus_of(kept)


## The view no longer a saved one, nor where the window looked from when
## asked: "current" is the window's as it is again.
func forget_eye() -> void:
	saved_view = ""
	eye_fov = 0.0


## Put one of [constant BACKDROPS] behind the model; false when there is no
## such backdrop.
func use_backdrop(name: String) -> bool:
	if not BACKDROPS.has(name):
		return false
	backdrop = BACKDROPS[name][0]
	backdrop_gradient = BACKDROPS[name][1]
	transparent = false
	return true


## Change these as a session asks for a render by name (render_queue): quality
## quick, good or best; size 720p, 1080p, 4k or square; samples; view; look;
## backdrop, or none for nothing behind; depth_of_field; light, studio, an
## HDRI's name or dark. What was wrong with [param asked], or "".
func take(asked: Dictionary) -> String:
	var grades: Dictionary = {"quick": Quality.QUICK, "good": Quality.GOOD, "best": Quality.BEST}
	var sizes: Dictionary = {"720p": Vector2i(1280, 720), "1080p": Vector2i(1920, 1080),
		"4k": Vector2i(3840, 2160), "square": Vector2i(1080, 1080)}
	if asked.has("quality"):
		if not grades.has(str(asked["quality"])):
			return "quality is quick, good or best."
		quality = grades[str(asked["quality"])]
	if asked.has("size"):
		if not sizes.has(str(asked["size"])):
			return "size is 720p, 1080p, 4k or square."
		size = sizes[str(asked["size"])]
	if asked.has("samples"):
		var count: int = int(asked["samples"])
		if count < 1 or count > MOST_SAMPLES:
			return "samples is 1 to %d." % MOST_SAMPLES
		samples = count
	if asked.has("view"):
		var view_asked: String = str(asked["view"])
		if not view_asked in ["current", "hero", "front", "side", "back", "low", "top"]:
			return "view is current, hero, front, side, back, low or top."
		view = view_asked
		forget_eye()
	if asked.has("look"):
		if not LOOKS.has(str(asked["look"])):
			return "look is %s." % LineArt.looks_in_words()
		look = str(asked["look"])
	if asked.has("backdrop"):
		var backdrop_asked: String = str(asked["backdrop"])
		if backdrop_asked == "none":
			use_backdrop("white")
			transparent = true
		elif not use_backdrop(backdrop_asked):
			return "backdrop is white, gradient, grey, dark or none."
	# lights (APP_UX5 #7): the light the set is in.
	if asked.has("light"):
		var light_asked: String = str(asked["light"])
		if not light_asked in LIGHTINGS_BESIDE and not StudioRender.HDRIS.has(light_asked):
			return "light is studio, %s or dark." % ", ".join(StudioRender.HDRIS.keys())
		lighting = light_asked
	if bool(asked.get("depth_of_field", false)):
		# A lens wide enough to blur is many frames through it: Best's.
		f_stop = 4.0
		focus = 0.4
		quality = Quality.BEST
	# photoreal7: what the model stands on, its own colour on the backdrop
	# unless a backdrop was asked for too.
	if asked.has("stage"):
		var wrong: String = use_stage(str(asked["stage"]), not asked.has("backdrop"))
		if not wrong.is_empty():
			return wrong
	return ""


## What the model stands on (photoreal7, StudioRender.STAGES), by its key, or
## none for the seamless backdrop; with [param coloured] the backdrop takes
## the stage's own colour (and something to stand on), otherwise it keeps the
## one asked for. What was wrong, or "".
func use_stage(asked: String, coloured: bool = true) -> String:
	if asked == "none" or asked.is_empty():
		stage = ""
		return ""
	if not StudioRender.STAGES.has(asked):
		return "stage is none, %s." % ", ".join(StudioRender.STAGES.keys())
	if transparent and not coloured:
		return "a stage stands the model on something, and backdrop none draws nothing under it."
	stage = asked
	if coloured:
		backdrop = StudioRender.STAGES[asked][6]
		backdrop_gradient = false
		transparent = false
	return ""


## The most samples a render is asked for by name.
const MOST_SAMPLES := 4096

## The lights beside the photographed places: the studio's three, and the
## Dark light (lights, APP_UX5 #7).
const LIGHTINGS_BESIDE: Array[String] = ["studio", "dark"]


# -- presets: Render's choices kept by a name, for any model ---------------------

## Where the presets are kept, on this computer or in this browser: a preset
## is how its person renders, so every model is offered it, as the booklet's
## page styles are (BookletSheet.STYLES_FILE).
const PRESETS_FILE := "user://render_presets.cfg"
## What a preset keeps: every choice Render's panel makes, and nothing of
## where the window looked from nor a probe's switches.
const PRESET_KEEPS: Array[String] = ["quality", "look", "size", "transparent", "backdrop",
	"backdrop_gradient", "lighting", "light_turn", "contact_shadow", "view", "saved_view",
	"focal_mm", "f_stop", "focus", "samples", "frames", "fps", "stage", "plastic"]


## These choices as a preset keeps them: words, numbers and the backdrop's
## colour as it is. A colour written as #rrggbb comes back a shade off the
## one Render names (Dark), and the panel then showed a colour of its own.
func preset() -> Dictionary:
	var out: Dictionary = {}
	for field: String in PRESET_KEEPS:
		var value: Variant = get(field)
		if value is Vector2i:
			value = [(value as Vector2i).x, (value as Vector2i).y]
		out[field] = value
	return out


## [param said], a preset as [method preset] made it, put on these choices,
## each checked: the file is the person's to edit. What was passed over, in
## words, or "". A saved view it names is only named here: Render looks it
## up in the model open ([method keep_view]).
func use_preset(said: Dictionary) -> String:
	var passed := PackedStringArray()
	for field: String in PRESET_KEEPS:
		if not said.has(field):
			continue
		var value: Variant = said[field]
		var number: bool = (value is float or value is int) and is_finite(float(value))
		match field:
			"quality":
				if number and int(value) in [Quality.QUICK, Quality.GOOD, Quality.BEST]:
					quality = int(value)
					continue
			"look":
				if LOOKS.has(str(value)):
					look = str(value)
					continue
			"size":
				if _a_size(value):
					size = Vector2i(int(value[0]), int(value[1]))
					continue
			"transparent", "backdrop_gradient", "contact_shadow":
				if value is bool:
					set(field, value)
					continue
			"backdrop":
				if value is Color:
					backdrop = value
					continue
				if value is String and Color.html_is_valid(str(value)):
					backdrop = Color.html(str(value))
					continue
			"lighting":
				if str(value) in LIGHTINGS_BESIDE or StudioRender.HDRIS.has(str(value)):
					lighting = str(value)
					continue
			"stage":
				if value is String and (str(value).is_empty() or StudioRender.STAGES.has(str(value))):
					stage = str(value)
					continue
			"plastic":
				if PLASTICS.has(str(value)):
					plastic = str(value)
					continue
			"light_turn":
				if number and absf(float(value)) <= 180.0:
					light_turn = float(value)
					continue
			"view":
				if StudioRender.VIEWS.has(str(value)):
					view = str(value)
					continue
			"saved_view":
				if value is String:
					saved_view = SavedViews.clean_name(str(value))
					continue
			"focal_mm":
				if number and float(value) >= 10.0 and float(value) <= 400.0:
					focal_mm = float(value)
					continue
			"f_stop":
				if number and float(value) >= 0.0 and float(value) <= 64.0:
					f_stop = float(value)
					continue
			"focus":
				if number and float(value) >= 0.0 and float(value) <= 1.0:
					focus = float(value)
					continue
			"samples":
				if number and int(value) >= 0 and int(value) <= MOST_SAMPLES:
					samples = int(value)
					continue
			"frames":
				if number and int(value) >= 1 and int(value) <= 720:
					frames = int(value)
					continue
			"fps":
				if number and int(value) >= 1 and int(value) <= 60:
					fps = int(value)
					continue
		passed.append(field)
	if saved_view.is_empty():
		eye_fov = 0.0
	return "" if passed.is_empty() else "passed over: " + ", ".join(passed)


static func _a_size(value: Variant) -> bool:
	if not value is Array or (value as Array).size() != 2:
		return false
	for n: Variant in value:
		if not (n is float or n is int) or float(n) < 16.0 or float(n) > 8192.0:
			return false
	return true


## The presets kept, by name, in the order they were first kept.
static func presets() -> Dictionary:
	var out: Dictionary = {}
	var file := ConfigFile.new()
	if file.load(PRESETS_FILE) != OK:
		return out
	for name: String in file.get_sections():
		var kept: Variant = file.get_value(name, "preset", {})
		if kept is Dictionary:
			out[name] = kept
	return out


## [param settings]' choices kept as the preset [param name], over one of
## that name. What went wrong, or "".
static func save_preset(name: String, settings: RenderSettings) -> String:
	var called: String = SavedViews.clean_name(name)
	if called.is_empty():
		return "a preset needs a name"
	var file := ConfigFile.new()
	file.load(PRESETS_FILE)
	file.set_value(called, "preset", settings.preset())
	return "" if file.save(PRESETS_FILE) == OK else "the preset could not be kept"


static func forget_preset(name: String) -> void:
	var file := ConfigFile.new()
	if file.load(PRESETS_FILE) == OK and file.has_section(name):
		file.erase_section(name)
		file.save(PRESETS_FILE)


func copy() -> RenderSettings:
	var twin := RenderSettings.new()
	for property: Dictionary in get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var name: String = property["name"]
			twin.set(name, get(name))
	return twin


## Samples a path-traced Best takes when none are asked for: as many as
## Studio's Eyesight's default, and on the box's RX 6700 XT a 720p picture
## of the example car in a few seconds.
const TRACED_SAMPLES := 256


## How many frames Best averages here, or samples it traces: fewer frames
## in a browser, which shares a graphics card it does not own with the rest
## of the page.
func samples_here() -> int:
	if quality != Quality.BEST:
		return 1
	if samples > 0:
		return samples
	if traced_here():
		return TRACED_SAMPLES
	return 32 if OS.has_feature("web") else 64


## What Best takes here when nobody says how many: its samples where it is
## path traced, otherwise its frames.
static func best_samples() -> int:
	if PathTracer.available():
		return TRACED_SAMPLES
	return 32 if OS.has_feature("web") else 64


## Whether Best is path traced here: asked for, and a card that traces
## rays. A picture with nothing behind it is not: its shadow on nothing is
## the frames-averaged one's (StudioRender's contact shadow).
func traced_here() -> bool:
	return quality == Quality.BEST and traced and not transparent and PathTracer.available()


## Best as the render dialog and render_model say it is here.
func best_words() -> String:
	if traced_here():
		return ("Path traced, %d samples: soft shadows, light bounced off the floor and "
			+ "between the parts, glass that tints what is behind it, and depth of field if "
			+ "you want it.") % samples_here()
	var words: String = ("%d frames averaged: soft shadows from an area light, smooth edges, "
		+ "shading under every ledge, and depth of field if you want it.") % samples_here()
	if transparent and traced and PathTracer.available():
		return words + " With nothing behind the model it is not path traced."
	if not PathTracer.available():
		return words + " " + PathTracer.why_not()
	return words


## The vertical field of view, in degrees, for a picture this shape: the
## picture's short side is a full-frame camera's 24 mm.
func fov_degrees() -> float:
	var short_half: float = atan(12.0 / maxf(focal_mm, 1.0))
	if size.y <= size.x:
		return rad_to_deg(short_half * 2.0)
	# Portrait: the short side is across, and the camera keeps its height.
	var across_half: float = short_half
	return rad_to_deg(2.0 * atan(tan(across_half) * float(size.y) / float(size.x)))


## The camera's own field of view, as a focal length on the same sensor.
static func focal_for(fov: float, picture: Vector2i) -> float:
	var half: float = deg_to_rad(fov) * 0.5
	if picture.y > picture.x:
		half = atan(tan(half) * float(picture.x) / float(picture.y))
	return 12.0 / maxf(tan(half), 0.0001)
