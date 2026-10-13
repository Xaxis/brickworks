## A LEGO Art picture as its designer decides it, in a few lines of JSON.
##
## The engine (MosaicArt) can read a whole plan off a picture, and that is
## the default. What it cannot know is what the picture is OF: that the
## galaxy's core is the subject and is raised, the sky flat behind it; that
## the wave's foam wants round tiles and the sky smooth ones; which three
## stars glow. A LEGO Art designer decides those first, and so does Claude,
## here: the crop and the panels, regions over the picture with their
## texture, relief, contours and star finishes, single stars put where it
## wants them, and a palette to keep to. Wherever the plan says nothing the
## engine reads the picture as it always has.
##
## Where the picture comes from: the one the person chose, or an SVG Claude
## draws when there is none ("a LEGO Art galaxy" from a sentence alone).
##
## Every coordinate is a fraction of the picture as laid — after the crop —
## from its top left: x across, y down, 0 to 1. Fractions, not studs, so a
## plan survives the panel count changing under it. A circle's radius is a
## fraction of the width, so it is round however the picture is shaped.
##
## [method parse] is the edge: whatever arrives is checked here, field by
## field, and refused with every fault named, so nothing malformed reaches
## the engine and a caller can fix all of it in one go.
class_name ArtPlan
extends RefCounted

## Finishes a star may be asked for by name, as the sets use them.
const FINISHES: Dictionary = {
	"trans-clear": 47, "glow": 329, "pearl-white": 183, "pearl-grey": 135,
	"pearl-gold": 297, "metallic-gold": 82, "metallic-silver": 80,
	"trans-light-blue": 43, "trans-medium-blue": 41, "trans-dark-blue": 33,
	"trans-yellow": 46, "trans-orange": 57, "trans-red": 36, "trans-purple": 52,
}
const TEXTURES: Dictionary = {
	"picture": MosaicArt.Tiling.PICTURE, "round": MosaicArt.Tiling.ROUND,
	"smooth": MosaicArt.Tiling.SMOOTH,
}
## What a plan and a region may say. Anything else is a mistake to be told
## about, not ignored: "height" for "relief" laid a flat picture in silence.
const PLAN_KEYS: Array[String] = ["name", "svg", "panels", "crop", "depth",
	"base_colour", "palette", "regions", "points"]
const REGION_KEYS: Array[String] = ["name", "everything", "polygon", "ellipse", "rect",
	"texture", "relief", "contours", "stars", "finish", "colour"]
const SHAPES: Array[String] = ["everything", "polygon", "ellipse", "rect"]
## Longest SVG taken, in characters. A picture drawn for 96 studs needs a
## small part of this; more is a mistake or a photograph pasted as paths.
const MOST_SVG := 200000
## Pixels a stud an SVG is drawn at before it is read a stud at a time.
const SVG_PER_STUD := 8


## One region: a shape over the picture and what it says. Only what it says
## changes; later regions are laid over earlier ones.
class Region extends RefCounted:
	var name: String = ""
	var shape: String = "everything"
	var polygon := PackedVector2Array()
	## Ellipse: centre in fractions; radii and the angle in degrees,
	## clockwise, the radii as fractions of the width.
	var centre := Vector2.ZERO
	var radii := Vector2.ONE
	var angle: float = 0.0
	var rect := Rect2(0, 0, 1, 1)
	var texture: int = -1
	var relief: int = -1
	## -1 unsaid, else 0 or 1.
	var contours: int = -1
	var stars: int = -1
	var finish: int = -1
	var colour: int = -1

	## Whether the point [param at], in fractions, is inside it, on a
	## picture [param tall] times as tall as it is wide.
	func holds(at: Vector2, tall: float) -> bool:
		match shape:
			"everything":
				return true
			"rect":
				return rect.has_point(at)
			"polygon":
				return Geometry2D.is_point_in_polygon(at, polygon)
			"ellipse":
				# In widths, so a circle is round on a picture of any shape.
				var d := Vector2(at.x - centre.x, (at.y - centre.y) * tall)
				d = d.rotated(-deg_to_rad(angle))
				var r := Vector2(maxf(radii.x, 1e-4), maxf(radii.y, 1e-4))
				return (d.x * d.x) / (r.x * r.x) + (d.y * d.y) / (r.y * r.y) <= 1.0
		return false


var name: String = ""
var svg: String = ""
## Panels across and down; down 0 takes it from the picture.
var panels := Vector2i(3, 0)
var crop := Rect2(0, 0, 1, 1)
## How high relief read off the picture rises where no region gives one.
var depth: int = 3
var base_colour: int = -1
var palette := PackedInt32Array()
var regions: Array[Region] = []
## [position in fractions, finish code] each.
var points: Array = []
## Every fault found, in words a caller can act on. Empty is a plan.
var errors := PackedStringArray()


func ok() -> bool:
	return errors.is_empty()


## The faults as one answer.
func trouble() -> String:
	return "The plan was not laid — %d thing%s to fix:\n- %s" % [errors.size(),
		"" if errors.size() == 1 else "s", "\n- ".join(errors)]


## Read a plan from what a caller sent. Never null: a plan that is not one
## comes back with [member errors] saying why.
static func parse(input: Variant, library: PartLibrary) -> ArtPlan:
	var out := ArtPlan.new()
	if not (input is Dictionary):
		out.errors.append("the plan must be a JSON object, not %s" % type_string(typeof(input)))
		return out
	var given: Dictionary = input
	for key: Variant in given:
		if not PLAN_KEYS.has(str(key)):
			out.errors.append("\"%s\" is not something a plan says; it says %s"
				% [key, ", ".join(PLAN_KEYS)])
	if given.has("name"):
		out.name = str(given["name"]).strip_edges().left(80)
	if given.has("svg"):
		out._read_svg(given["svg"])
	if given.has("panels"):
		out._read_panels(given["panels"])
	if given.has("crop"):
		var box: Variant = out._box(given["crop"], "crop")
		if box is Rect2:
			out.crop = box
	if given.has("depth"):
		out.depth = out._whole(given["depth"], "depth", 0, MosaicArt.MOST_DEPTH, out.depth)
	if given.has("base_colour"):
		out._read_base(given["base_colour"], library)
	if given.has("palette"):
		out._read_palette(given["palette"], library)
	if given.has("regions"):
		var listed: Variant = given["regions"]
		if not (listed is Array):
			out.errors.append("regions must be a list of regions")
		else:
			for index: int in (listed as Array).size():
				var region: Region = out._read_region(listed[index], "regions[%d]" % index, library)
				if region != null:
					out.regions.append(region)
	if given.has("points"):
		out._read_points(given["points"], library)
	return out


func _read_svg(value: Variant) -> void:
	if not (value is String) or not (value as String).contains("<svg") \
			or not (value as String).contains("</svg>"):
		errors.append("svg must be the whole drawing as text, <svg ...> to </svg>")
		return
	if (value as String).length() > MOST_SVG:
		errors.append("svg is %d characters; draw it in fewer than %d"
			% [(value as String).length(), MOST_SVG])
		return
	svg = value


func _read_panels(value: Variant) -> void:
	if not (value is Array) or (value as Array).size() not in [1, 2]:
		errors.append("panels must be [across, down], each 1 to %d (down may be 0 to "
			% MosaicArt.MOST_PANELS + "keep the picture's proportions)")
		return
	var list: Array = value
	panels.x = _whole(list[0], "panels across", 1, MosaicArt.MOST_PANELS, panels.x)
	if list.size() == 2:
		panels.y = _whole(list[1], "panels down", 0, MosaicArt.MOST_PANELS, panels.y)


func _read_base(value: Variant, library: PartLibrary) -> void:
	var code: int = _whole(value, "base_colour", 0, 100000, -1)
	if code < 0:
		return
	var made: PackedInt32Array = MosaicArt.colours_for(library, MosaicArt.BASE, MosaicArt.SOLID)
	if not made.has(code):
		errors.append("base_colour %d: a 16 x 16 panel is not made in it; it is made in %s"
			% [code, _named(library, made)])
		return
	base_colour = code


func _read_palette(value: Variant, library: PartLibrary) -> void:
	if not (value is Array) or (value as Array).is_empty():
		errors.append("palette must be a list of LDraw colour codes")
		return
	for index: int in (value as Array).size():
		var code: int = _colour(value[index], "palette[%d]" % index, library)
		if code >= 0 and not palette.has(code):
			palette.append(code)


func _read_region(value: Variant, at: String, library: PartLibrary) -> Region:
	if not (value is Dictionary):
		errors.append("%s must be an object" % at)
		return null
	var given: Dictionary = value
	var region := Region.new()
	for key: Variant in given:
		if not REGION_KEYS.has(str(key)):
			errors.append("%s: \"%s\" is not something a region says; it says %s"
				% [at, key, ", ".join(REGION_KEYS)])
	var said: Array[String] = []
	for shape: String in SHAPES:
		if given.has(shape):
			said.append(shape)
	if said.size() != 1:
		errors.append("%s needs exactly one shape — polygon, ellipse, rect, or "
			% at + "\"everything\": true — and has %s"
			% ("none" if said.is_empty() else ", ".join(said)))
		return null
	region.name = str(given.get("name", at))
	region.shape = said[0]
	match region.shape:
		"everything":
			if given["everything"] != true:
				errors.append("%s: everything can only be true" % at)
		"rect":
			var box: Variant = _box(given["rect"], at + ".rect")
			if box is Rect2:
				region.rect = box
		"polygon":
			var corners: Variant = given["polygon"]
			if not (corners is Array) or (corners as Array).size() < 3:
				errors.append("%s.polygon must be three or more [x, y] points" % at)
			else:
				for index: int in (corners as Array).size():
					var point: Variant = _point(corners[index], "%s.polygon[%d]" % [at, index])
					if point is Vector2:
						region.polygon.append(point)
		"ellipse":
			_read_ellipse(given["ellipse"], at + ".ellipse", region)
	if given.has("texture"):
		var word: String = str(given["texture"])
		if not TEXTURES.has(word):
			errors.append("%s.texture \"%s\" is not one of %s"
				% [at, word, ", ".join(PackedStringArray(TEXTURES.keys()))])
		else:
			region.texture = int(TEXTURES[word])
	if given.has("relief"):
		region.relief = _whole(given["relief"], at + ".relief", 0, MosaicArt.MOST_DEPTH, -1)
	for flag: String in ["contours", "stars"]:
		if given.has(flag):
			if not (given[flag] is bool):
				errors.append("%s.%s must be true or false" % [at, flag])
			else:
				region.set(flag, 1 if given[flag] else 0)
	if given.has("finish"):
		region.finish = _finish(given["finish"], at + ".finish", library)
	if given.has("colour"):
		region.colour = _colour(given["colour"], at + ".colour", library)
	return region


func _read_ellipse(value: Variant, at: String, region: Region) -> void:
	if not (value is Dictionary):
		errors.append("%s must be {cx, cy, rx, ry} and may have angle" % at)
		return
	var given: Dictionary = value
	for key: String in ["cx", "cy", "rx", "ry"]:
		if not given.has(key) or not _is_number(given[key]):
			errors.append("%s.%s must be a number" % [at, key])
			return
	for key: Variant in given:
		if str(key) not in ["cx", "cy", "rx", "ry", "angle"]:
			errors.append("%s: \"%s\" is not part of an ellipse (cx, cy, rx, ry, angle)"
				% [at, key])
	region.centre = Vector2(float(given["cx"]), float(given["cy"]))
	region.radii = Vector2(float(given["rx"]), float(given["ry"]))
	if region.radii.x <= 0.0 or region.radii.y <= 0.0 or region.radii.x > 2.0 \
			or region.radii.y > 2.0:
		errors.append("%s: rx and ry are fractions of the picture's width, more than 0 "
			% at + "and at most 2")
	if not _inside_ish(region.centre):
		errors.append("%s: the centre must be on the picture, 0 to 1 each way" % at)
	if given.has("angle"):
		if not _is_number(given["angle"]):
			errors.append("%s.angle must be degrees, a number" % at)
		else:
			region.angle = float(given["angle"])


func _read_points(value: Variant, library: PartLibrary) -> void:
	if not (value is Array):
		errors.append("points must be a list of {\"at\": [x, y], \"finish\": ...}")
		return
	for index: int in (value as Array).size():
		var at: String = "points[%d]" % index
		var one: Variant = value[index]
		var where: Variant = null
		var finish: int = FINISHES["trans-clear"]
		if one is Array:
			where = _point(one, at)
		elif one is Dictionary:
			for key: Variant in one:
				if str(key) not in ["at", "finish"]:
					errors.append("%s: \"%s\" is not part of a point (at, finish)" % [at, key])
			if not (one as Dictionary).has("at"):
				errors.append("%s needs \"at\": [x, y]" % at)
				continue
			where = _point(one["at"], at + ".at")
			if (one as Dictionary).has("finish"):
				finish = _finish(one["finish"], at + ".finish", library)
		else:
			errors.append("%s must be [x, y] or {\"at\": [x, y], \"finish\": ...}" % at)
			continue
		if where is Vector2 and finish >= 0:
			points.append([where, finish])


## A whole number from [param least] to [param most], or [param fallback]
## with the fault noted.
func _whole(value: Variant, at: String, least: int, most: int, fallback: int) -> int:
	if not _is_number(value) or not is_equal_approx(float(value), roundf(float(value))):
		errors.append("%s must be a whole number from %d to %d, not %s"
			% [at, least, most, JSON.stringify(value)])
		return fallback
	var whole: int = roundi(float(value))
	if whole < least or whole > most:
		errors.append("%s is %d; it must be from %d to %d" % [at, whole, least, most])
		return fallback
	return whole


func _point(value: Variant, at: String) -> Variant:
	if not (value is Array) or (value as Array).size() != 2 or not _is_number(value[0]) \
			or not _is_number(value[1]):
		errors.append("%s must be [x, y], fractions of the picture" % at)
		return null
	var point := Vector2(float(value[0]), float(value[1]))
	if not _inside_ish(point):
		errors.append("%s %s is off the picture: x and y run 0 to 1 from the top left"
			% [at, JSON.stringify(value)])
		return null
	return point


func _box(value: Variant, at: String) -> Variant:
	if not (value is Dictionary):
		errors.append("%s must be {x, y, w, h}, fractions of the picture" % at)
		return null
	for key: String in ["x", "y", "w", "h"]:
		if not (value as Dictionary).has(key) or not _is_number(value[key]):
			errors.append("%s.%s must be a number" % [at, key])
			return null
	var box := Rect2(float(value["x"]), float(value["y"]), float(value["w"]), float(value["h"]))
	if box.size.x <= 0.0 or box.size.y <= 0.0 or box.position.x < 0.0 or box.position.y < 0.0 \
			or box.end.x > 1.0001 or box.end.y > 1.0001:
		errors.append("%s %s must lie on the picture: x, y from 0, w and h more than 0, "
			% [at, JSON.stringify(value)] + "x + w and y + h at most 1")
		return null
	return box


func _colour(value: Variant, at: String, library: PartLibrary) -> int:
	var code: int = _whole(value, at, 0, 100000, -1)
	if code < 0:
		return -1
	if library.color(code) == null or not (MosaicArt.SOLID.has(code) or MosaicArt.ACCENTS.has(code)):
		errors.append("%s %d is not a colour LEGO Art is laid in; those are %s"
			% [at, code, _named(library, PackedInt32Array(MosaicArt.SOLID + MosaicArt.ACCENTS))])
		return -1
	return code


func _finish(value: Variant, at: String, library: PartLibrary) -> int:
	if value is String and (value as String).is_valid_int():
		value = (value as String).to_int()
	if value is String:
		if FINISHES.has(value):
			return int(FINISHES[value])
		errors.append("%s \"%s\" is not a finish; say one of %s, or a colour code"
			% [at, value, ", ".join(PackedStringArray(FINISHES.keys()))])
		return -1
	return _colour(value, at, library)


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and not is_nan(float(value)) \
		and not is_inf(float(value))


static func _inside_ish(point: Vector2) -> bool:
	return point.x >= 0.0 and point.y >= 0.0 and point.x <= 1.0 and point.y <= 1.0


static func _named(library: PartLibrary, codes: PackedInt32Array) -> String:
	var said := PackedStringArray()
	for code: int in codes:
		var colour: PartLibrary.BrickColor = library.color(code)
		said.append("%d %s" % [code, colour.name if colour != null else "?"])
	return ", ".join(said)


## The picture to lay: the SVG drawn, or [param picture], cut to the crop.
## Null, with the fault noted, when there is neither.
func source(picture: Image, library: PartLibrary) -> Image:
	var image: Image = null
	if not svg.is_empty():
		image = _drawn(library)
		if image == null:
			return null
	elif picture != null and not picture.is_empty():
		image = picture
	else:
		errors.append("there is no picture to work from: the person has not chosen one, "
			+ "so draw it and pass it as svg")
		return null
	if crop == Rect2(0, 0, 1, 1):
		return image
	var w: int = image.get_width()
	var h: int = image.get_height()
	var cut := Rect2i(roundi(crop.position.x * w), roundi(crop.position.y * h),
		maxi(1, roundi(crop.size.x * w)), maxi(1, roundi(crop.size.y * h)))
	cut = cut.intersection(Rect2i(0, 0, w, h))
	if cut.size.x < 2 or cut.size.y < 2:
		errors.append("the crop leaves less than two pixels of a %d x %d picture" % [w, h])
		return null
	return image.get_region(cut)


## The SVG drawn at [constant SVG_PER_STUD] pixels a stud across, over the
## panels' colour (black if none was said), so a drawing with no
## background is a dark ground rather than holes in the picture.
func _drawn(library: PartLibrary) -> Image:
	# A drawing with no size comes back one pixel square, not as a fault.
	var probe := Image.new()
	if probe.load_svg_from_string(svg, 1.0) != OK or probe.get_width() < 8 \
			or probe.get_height() < 8:
		errors.append("the svg could not be drawn: it must be well-formed SVG with a "
			+ "viewBox, or a width and height, of 8 or more")
		return null
	var wide: int = panels.x * MosaicArt.PANEL * SVG_PER_STUD
	var image := Image.new()
	if image.load_svg_from_string(svg, float(wide) / probe.get_width()) != OK or image.is_empty():
		image = probe
	image.convert(Image.FORMAT_RGBA8)
	var under: PartLibrary.BrickColor = library.color(base_colour if base_colour >= 0 else 0)
	var ground: Color = under.rgb if under != null else Color.BLACK
	var flat := Image.create_empty(image.get_width(), image.get_height(), false,
		Image.FORMAT_RGBA8)
	flat.fill(ground)
	flat.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return flat


## The engine's options for this plan. Its depth is the most anything
## stands, so a relief said for a region is never cut down to [member depth].
func options() -> MosaicArt.Options:
	var out := MosaicArt.Options.new()
	out.panels_across = panels.x
	out.panels_down = panels.y
	var most: int = depth
	for region: Region in regions:
		most = maxi(most, region.relief)
	out.depth = most
	return out


## The plan over a grid of [param across] x [param down] studs: each stud's
## centre against every region in turn, later over earlier, then the
## single stars.
func guide(across: int, down: int) -> MosaicArt.Guide:
	var out := MosaicArt.Guide.new()
	out.sized(across * down)
	out.palette = palette
	out.base_colour = base_colour
	out.depth = depth
	var tall: float = float(down) / float(across)
	for z: int in down:
		for x: int in across:
			var at := Vector2((x + 0.5) / across, (z + 0.5) / down)
			var i: int = x + z * across
			for region: Region in regions:
				if not region.holds(at, tall):
					continue
				if region.texture >= 0:
					out.texture[i] = region.texture
				if region.relief >= 0:
					out.relief[i] = region.relief
				if region.contours >= 0:
					out.contours[i] = region.contours
				if region.stars >= 0:
					out.stars[i] = region.stars
				if region.finish >= 0:
					out.finish[i] = region.finish
				if region.colour >= 0:
					out.colour[i] = region.colour
	for point: Array in points:
		var at: Vector2 = point[0]
		var x: int = clampi(int(at.x * across), 0, across - 1)
		var z: int = clampi(int(at.y * down), 0, down - 1)
		out.point[x + z * across] = int(point[1])
	return out


## The plan laid: the picture (or the drawing) read under the plan's guide
## and turned into parts. Null, with the fault noted, when there is no
## picture to lay.
func lay(picture: Image, library: PartLibrary) -> MosaicArt.Art:
	if not ok():
		return null
	var image: Image = source(picture, library)
	if image == null:
		return null
	var chosen: MosaicArt.Options = options()
	var size: Vector2i = MosaicArt.size_for(image, chosen)
	var plan: MosaicArt.Plan = MosaicArt.analyse(image, chosen, library,
		guide(size.x * MosaicArt.PANEL, size.y * MosaicArt.PANEL))
	return MosaicArt.lay(plan, chosen, library)


## The two tools a design is given for it: make_art, whose input is a plan,
## and look_at_picture, for a session that cannot otherwise see the
## picture the person chose. Here, beside [method parse], so what the tool
## says it takes and what is taken cannot drift apart.
static func schemas() -> Array:
	var point := {"type": "array", "items": {"type": "number"}, "minItems": 2, "maxItems": 2,
		"description": "[x, y], fractions of the picture from its top left"}
	var box := {"type": "object", "properties": {"x": {"type": "number"},
		"y": {"type": "number"}, "w": {"type": "number"}, "h": {"type": "number"}},
		"required": ["x", "y", "w", "h"], "additionalProperties": false}
	var finish := {"type": "string", "description": ("a star's finish: "
		+ ", ".join(PackedStringArray(FINISHES.keys())) + ", or an LDraw colour code")}
	var region := {
		"type": "object",
		"properties": {
			"name": {"type": "string", "description": "what it is: sky, core, the crest"},
			"everything": {"type": "boolean", "description": "the whole picture; put it first"},
			"polygon": {"type": "array", "items": point, "description": "three or more points"},
			"ellipse": {"type": "object", "properties": {
				"cx": {"type": "number"}, "cy": {"type": "number"},
				"rx": {"type": "number", "description": "half-width, a fraction of the picture's width"},
				"ry": {"type": "number", "description": "half-height, also a fraction of the WIDTH, so rx = ry is a circle"},
				"angle": {"type": "number", "description": "degrees clockwise"}},
				"required": ["cx", "cy", "rx", "ry"], "additionalProperties": false},
			"rect": box,
			"texture": {"type": "string", "enum": TEXTURES.keys(), "description": (
				"round: 1 x 1 round tiles, the theme's texture, for what is busy or soft "
				+ "(a star field, foam, cloud, hair, fur); smooth: square tiles merged into "
				+ "long ones, for flat colour (sky, a wall, a plain ground); picture: round "
				+ "where the picture is busy and smooth where it is flat")},
			"relief": {"type": "integer", "minimum": 0, "maximum": MosaicArt.MOST_DEPTH,
				"description": ("plates it stands above the panel. The background 0; the "
					+ "subject raised in terraces, an outer region 1 and an inner 2 or 3; "
					+ "cheese slopes are laid on the way up")},
			"contours": {"type": "boolean", "description":
				"curved edges inside it laid in quarter-circle tiles (default true)"},
			"stars": {"type": "boolean", "description": ("whether points of light the "
				+ "picture has here become stars in a finish (default true). False on a "
				+ "subject whose highlights are not stars")},
			"finish": finish,
			"colour": {"type": "integer", "description": ("lay the whole region in this "
				+ "one LDraw colour, whatever the picture has there")},
		},
		"additionalProperties": false,
	}
	return [{
		"name": "make_art",
		"description": ("Lay a picture as a LEGO Art set is laid — 31212 The Milky Way, "
			+ "31208 The Great Wave, 31213 Mona Lisa — on 16 x 16 panels joined underneath "
			+ "into one piece: square tiles merged where it is flat, 1 x 1 round tiles for "
			+ "texture, quarter circles along curved contours, stars in trans-clear, "
			+ "glow-in-the-dark, pearl and metallic set a plate proud, and the subject "
			+ "raised on stacked plates with cheese slopes. Use this, not submit_design, "
			+ "whenever LEGO Art, a mosaic, a picture in bricks or wall art is asked for. "
			+ "It replaces what is on the baseplate.\n"
			+ "The picture is the one the person chose (look_at_picture shows it). With "
			+ "none, draw it yourself as svg: one stud is one pixel, so big simple shapes "
			+ "in flat colours, like a poster.\n"
			+ "You decide what a LEGO Art designer decides, and the app reads everything "
			+ "you leave out off the picture: the panels and the crop; regions over the "
			+ "picture, each with its texture, its relief (the subject raised, the "
			+ "background flat), whether contours run in it and whether its points of "
			+ "light are stars and in what finish; single stars put exactly where you want "
			+ "them; a palette to keep to. Coordinates are fractions of the picture, 0 to "
			+ "1 from its top left. Later regions lie over earlier ones and change only "
			+ "what they say, so start with the whole picture and work inward. A plan "
			+ "that cannot be laid is refused with every fault named.\n"
			+ "The answer is the picture as laid, face on, and what it is made of. Look "
			+ "at it as a person would from across a room, and call make_art again with "
			+ "the plan changed if it does not read as the subject."),
		"input_schema": {
			"type": "object",
			"properties": {
				"name": {"type": "string", "description": "the picture's title"},
				"svg": {"type": "string", "description": ("the picture, drawn, when the "
					+ "person has not chosen one: a whole <svg> with a viewBox in the "
					+ "panels' proportions (0 0 96 48 for 6 x 3 panels, a unit a stud) "
					+ "and a rect filling it as the background. Leave it out to use "
					+ "their picture.")},
				"panels": {"type": "array", "items": {"type": "integer"}, "minItems": 2,
					"maxItems": 2, "description": ("[across, down], 1 to %d each; a "
						% MosaicArt.MOST_PANELS + "panel is 16 studs, 12.8 cm. down 0 "
						+ "keeps the picture's proportions. A large set is 4 to 6 across.")},
				"crop": box,
				"depth": {"type": "integer", "minimum": 0, "maximum": MosaicArt.MOST_DEPTH,
					"description": ("how high relief read off the picture rises where no "
						+ "region gives one; 0 keeps it flat there. Default 3.")},
				"base_colour": {"type": "integer", "description": ("the panels' LDraw "
					+ "colour, which shows between round tiles: usually the darkest of "
					+ "the background")},
				"palette": {"type": "array", "items": {"type": "integer"}, "description": (
					"LDraw colour codes to lay it in, as a set keeps to a dozen or so. "
					+ "Leave it out for all of them.")},
				"regions": {"type": "array", "items": region},
				"points": {"type": "array", "items": {"type": "object", "properties": {
					"at": point, "finish": finish}, "required": ["at"],
					"additionalProperties": false},
					"description": "single stars, each one stud (default trans-clear)"},
			},
			"additionalProperties": false,
		},
	}, {
		"name": "look_at_picture",
		"description": ("The picture the person chose to make into LEGO Art, as they "
			+ "gave it, with its size in pixels. Look at it before writing a make_art "
			+ "plan from it. When there is none it says so: draw one in make_art's svg."),
		"input_schema": {"type": "object", "properties": {}, "additionalProperties": false},
	}]


## What a laid plan came to, in words: its size, and its parts by element.
static func said_of(art: MosaicArt.Art) -> String:
	var said := PackedStringArray()
	for entry: Array in art.by_element():
		said.append("%d %s" % [int(entry[1]), str(entry[0])])
	var highest: int = 0
	for value: int in art.plan.relief:
		highest = maxi(highest, value)
	return "%d x %d studs on %d x %d panels (%.0f x %.0f cm), standing up to %d plate%s: %d parts — %s." % [
		art.plan.across, art.plan.down, art.panels.x, art.panels.y,
		art.plan.across * 0.8, art.plan.down * 0.8, highest, "" if highest == 1 else "s",
		art.placements.size(), ", ".join(said)]
