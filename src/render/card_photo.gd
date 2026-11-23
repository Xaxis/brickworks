## A model's card in the gallery and the home feed, drawn as a photograph of
## the real model (cardlook, docs/PLAN.md row 4).
##
## The card was the model cut out in the window's own light, on the page's
## ground: a CAD's picture beside every other site's photographs. Render's
## Best had learned to stand a model on a real table under a lamp
## (photoreal7 to photoreal10, docs/RENDERING.md 5k to 5n), but only a
## person who opened Render saw it. So the Share panel draws the card with
## that stage: the model from where the view looks, path traced on the
## table, the light falling off across it, through the camera's tone and
## white balance, its edges sharpened and saved as a camera saves.
##
## Path traced where the graphics card traces rays (PathTracer). Elsewhere
## (a browser) the same desk is frames averaged under the studio's lights
## ([constant RASTER]): no table's relief, but a desk's colour, soft light
## and a shadow, which the blind judge also chose over the cut-out every
## time. Not on a phone, whose memory a second copy of a big model may not
## have, and never longer than [constant RASTER_MOST_MS]: past it the card
## is the cut-out it was. The link's picture and the page's cut-out are
## not this: they are drawn by Picture as before, so a model's page keeps
## its ground in both themes.
class_name CardPhoto
extends Node

## The stage, as RenderSettings says it (docs/RENDERING.md 5n): photoreal10's
## measured desk, the bench's grey 1x3's (tools/photoreal/shots.json), which
## the solo judge called a photograph more often than any other stage: a
## matte desk's laminate with its relief, in daylight, the light falling
## off across it from a lamp 42 of the model's radii away, the camera's
## edges sharpened and saved as a camera saves. Render's own stages (a
## desk under a near lamp, leather, wood) washed an orange fox out to yellow
## on the house's models; this one kept every colour
## (bench/results/cardlook-2026-11-23).
const LOOK: Dictionary = {
	"lighting": "daylight",
	"backdrop": "#c4bcae",
	"surface": 1,
	"table": 1.0,
	"table_light": 42.0,
	"focal_mm": 50.0,
	"sharpen": 0.6,
	"jpeg": 90.0,
}
## The same desk frames averaged, where no rays are traced: the studio's
## lights, not the daylight, whose sky turned the desk blue-grey without
## the tracer's white balance (cardlook's raster round). Fewer frames than
## Best's 32: the card is made smaller, which smooths what they leave.
const RASTER: Dictionary = {
	"lighting": "studio",
	"samples": 16,
}
## The longest a frames-averaged card may take, in milliseconds, before it
## is given up for the cut-out: a browser drawing in software (a test's)
## would hold the publish for many seconds.
const RASTER_MOST_MS := 2500
## Samples a pixel: the card is drawn at twice its size and made smaller,
## which takes out three quarters of what is left of the noise. 64 and 96
## could not be told apart on the house's models at the card's size, and
## the time is mostly the set's, not the samples' (cardlook's try2).
const SAMPLES := 64

var world: BrickWorld
var library: PartLibrary
var scenery: Dictionary = {}
## The window's camera, its environment and its Sun, Fill and Rim, as
## StudioRender takes them.
var eye: Camera3D
var look: Environment
var rig_lights: Array[DirectionalLight3D] = []
## In place of [constant LOOK]'s, for the bench to try another (card_probe).
var asked: Dictionary = {}
## How long the last card took to draw, in milliseconds, and when each of
## its steps began (milliseconds in, then the render's words), for the bench.
var last_ms: float = 0.0
var steps: PackedStringArray = PackedStringArray()


## Whether a card can be drawn as a photograph here: a window to draw in,
## and not a phone ([constant RASTER]).
static func possible() -> bool:
	return StudioRender.possible() and (PathTracer.available() or not Phone.on())


## Whether it is path traced here, or frames averaged.
static func traced() -> bool:
	return PathTracer.available()


## What the card is drawn with, at [param size].
func settings(size: Vector2i) -> RenderSettings:
	var chosen: Dictionary = LOOK.merged(asked if traced() else RASTER.merged(asked, true), true)
	var out := RenderSettings.new()
	out.quality = RenderSettings.Quality.BEST
	out.look = "product"
	out.size = size
	out.samples = int(chosen.get("samples", SAMPLES))
	out.view = "current"
	out.backdrop = Color.html(str(chosen.get("backdrop", "#ffffff")))
	for key: String in chosen:
		if key in ["samples", "backdrop"]:
			continue
		if key in ["stage", "lighting"]:
			out.set(key, str(chosen[key]))
		elif key == "surface":
			out.surface = int(chosen[key])
		else:
			out.set(key, float(chosen[key]))
	# From the way the view looks, the camera backed off until every corner
	# of every part is in the frame (StudioRender._fit_points): the view's
	# own framing is the window's shape, not the card's, and the box round a
	# tower or an orrery's arms left the model a third of the card.
	var corners: PackedVector3Array = _corners()
	if eye != null and not corners.is_empty():
		var basis: Basis = StudioRender._looking_from(eye.global_transform.basis.z.normalized())
		var fov: float = out.fov_degrees()
		out.eye_transform = Transform3D(basis,
			StudioRender._fit_points(basis, corners, fov, float(size.x) / float(size.y)))
		out.eye_fov = fov
		out.eye_orthogonal = false
		var box := AABB(corners[0], Vector3.ZERO)
		for point: Vector3 in corners:
			box = box.expand(point)
		out.eye_focus = box.get_center()
	return out


## The corners of the parts the card draws (Picture.add_corners), each
## part's box turned with it: not the floor's plate, not a hidden part.
func _corners() -> PackedVector3Array:
	var corners := PackedVector3Array()
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id) or brick.hidden:
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info != null:
			Picture.add_corners(corners, brick.transform, info.bounds)
	return corners


## The model drawn as a photograph at [param size], from where the view
## looks, or null when it cannot be ([method possible]) or there is nothing
## to draw. A renderer of its own, let go after: a card is drawn once a
## publish, and the copy of the model it stages is the model's size again.
func take(size: Vector2i) -> Image:
	if not possible() or world == null or world.brick_count() == 0:
		return null
	var began: int = Time.get_ticks_usec()
	var render := StudioRender.new()
	render.library = library
	render.scenery = scenery
	render.eye = eye
	render.look = look
	render.rig_lights = rig_lights
	add_child(render)
	steps.clear()
	render.progress.connect(func(_fraction: float, words: String) -> void:
		if steps.is_empty() or not steps[-1].ends_with(" " + words):
			steps.append("%d %s" % [(Time.get_ticks_usec() - began) / 1000, words]))
	if not traced():
		get_tree().create_timer(RASTER_MOST_MS / 1000.0).timeout.connect(func() -> void:
			if is_instance_valid(render):
				render.cancel())
	var image: Image = await render.render(world, settings(size))
	render.queue_free()
	last_ms = float(Time.get_ticks_usec() - began) / 1000.0
	return image
