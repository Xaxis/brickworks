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
	## Many frames averaged: every one jittered under the pixel, lit from
	## another point of an area light and seen through another point of the
	## lens, so edges are smooth, shadows soft and the depth of field real.
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
## plastic with a gloss and rounded edges, clear parts that bend the light,
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
## Frames averaged for Best; 0 for this platform's own number.
var samples: int = 0
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


## Put one of [constant BACKDROPS] behind the model; false when there is no
## such backdrop.
func use_backdrop(name: String) -> bool:
	if not BACKDROPS.has(name):
		return false
	backdrop = BACKDROPS[name][0]
	backdrop_gradient = BACKDROPS[name][1]
	transparent = false
	return true


func copy() -> RenderSettings:
	var twin := RenderSettings.new()
	for property: Dictionary in get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var name: String = property["name"]
			twin.set(name, get(name))
	return twin


## How many frames Best averages here: fewer in a browser, which shares a
## graphics card it does not own with the rest of the page.
func samples_here() -> int:
	if quality != Quality.BEST:
		return 1
	if samples > 0:
		return samples
	return 32 if OS.has_feature("web") else 64


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
