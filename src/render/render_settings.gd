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
}

var quality: int = Quality.GOOD
## How the plastic and the set are drawn: "window", as the window draws
## them, or "product", as a product shot is lit and finished (StudioRender:
## plastic with a gloss and rounded edges, clear parts that tint what is behind,
## a key, fill and rim over a studio's light, and AgX's film-like tones).
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
## "studio" for three lights, or one of StudioRender.HDRIS.
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
## Where the window looked from when the render was asked for, kept for
## a render drawn later (RenderQueue): the "current" view is then that
## one, not wherever the window has turned since. Unset while eye_fov is 0.
var eye_transform: Transform3D = Transform3D()
var eye_fov: float = 0.0
var eye_orthogonal: bool = false
var eye_focus: Vector3 = Vector3.ZERO


## Keep where [param camera] looks from now, and what it looks at.
func keep_eye(camera: Camera3D) -> void:
	eye_transform = camera.global_transform
	eye_fov = camera.fov
	eye_orthogonal = camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	eye_focus = camera.call("focus_now") if camera.has_method("focus_now") \
		else camera.global_position - camera.global_transform.basis.z * 100.0


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
## backdrop, or none for nothing behind; depth_of_field. What was wrong with
## [param asked], or "".
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
	if asked.has("look"):
		if not LOOKS.has(str(asked["look"])):
			return "look is window or product."
		look = str(asked["look"])
	if asked.has("backdrop"):
		var backdrop_asked: String = str(asked["backdrop"])
		if backdrop_asked == "none":
			use_backdrop("white")
			transparent = true
		elif not use_backdrop(backdrop_asked):
			return "backdrop is white, gradient, grey, dark or none."
	if bool(asked.get("depth_of_field", false)):
		# A lens wide enough to blur is many frames through it: Best's.
		f_stop = 4.0
		focus = 0.4
		quality = Quality.BEST
	return ""


## The most samples a render is asked for by name.
const MOST_SAMPLES := 4096


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
