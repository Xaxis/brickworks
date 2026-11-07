## Lights placed in the model (APP_UX5 #7, lights): a spot over the cockpit,
## a bulb in a lamp post, a low sun from one side, a softbox overhead, kept
## with the model as StudWorx keeps its lights. Render draws them over its
## studio (StudioRender), rasterised and path traced alike, and in its Dark
## light they are all there is, with the plastics that glow.
##
## Four kinds, as a photographer has them:
##   point        a bulb: light every way from where it is, falling off with
##                the square of the distance; its size is the bulb's radius,
##                which softens its shadows
##   spot         a point that shines only inside its cone ([member cone], the
##                cone's whole angle in degrees), its edge soft and nothing at
##                all outside it
##   directional  a sun: the same light everywhere, from one way
##   area         a square panel of light [member size] across, shining from
##                one face, brighter square on than edge on: soft shadows
##
## Strength 1 is the window's own key light: a sun of strength 1 lights a face
## turned to it as the key does, and a lamp of strength 1 lights a face 5 studs
## (100 LDU) away as the key does, four times as brightly at half that.
##
## The world holds them in the window's coordinates (BrickWorld.scene_lights);
## the model's file keeps each as a line LDraw readers pass over
## ([constant META]), in the file's coordinates, as the cut and the saved
## views are kept (CutShape, SavedViews): they come back when the file opens,
## the parts are never changed, and an older Brickworks opens the file whole
## and passes over them. They are changed in Render's Lights in the model
## (RenderDialog) and by light_model over MCP (AppTools).
class_name SceneLights
extends RefCounted

## A light's line in the model's file: JSON, in the file's coordinates
## (LDraw's: y down, z towards the viewer, the model where the file has it):
##   {"kind": "spot", "at": [0.0, -260.0, 0.0], "aim": [0.0, 1.0, 0.0],
##    "colour": "#fff1d6", "strength": 1.5, "cone": 40.0, "size": 4.0,
##    "shadows": true}
## at in LDU; aim the way it shines, a unit vector; colour as a person picks
## it (sRGB); cone a spot's whole angle in degrees; size a bulb's radius or a
## panel's side in LDU.
const META := "0 !BRICKWORKS LIGHT "
const KINDS: Array[String] = ["point", "spot", "directional", "area"]
## The most a model keeps, as many as the path tracer lights a bounce with.
const MOST := 8
## Strength 1 lights a face this far from a lamp as the window's key does.
const REACH := 100.0
## The window's key light, as StudioRender's RIG has it under Forward+.
const KEY := 0.9
## A spot's cone, whole, in degrees: its narrowest and widest.
const NARROWEST := 2.0
const WIDEST := 160.0
## How a spot's light falls to nothing at the edge of its cone: Godot's
## SpotLight3D spot_angle_attenuation, and path_tracer.glsl's the same, so
## both ways of drawing have the one edge. Over most of the cone it is
## nearly whole, and it fades over its outer part.
const EDGE := 3.0
## The strongest a light is kept at.
const STRONGEST := 50.0
## The colour a new light has: a warm white, as a tungsten-balanced lamp.
const WARM := "#fff1d6"


# -- kept with the model --------------------------------------------------------


## The lights [param text] keeps, in its order, as [method written_into] wrote
## them (the file's coordinates). A line this cannot read is passed over, and
## past [constant MOST] the rest are.
static func read(text: String) -> Array:
	var out: Array = []
	if not text.contains(META):
		return out
	for line: String in text.split("\n"):
		if not line.begins_with(META) or out.size() >= MOST:
			continue
		var light: Dictionary = parsed(line.substr(META.length()).strip_edges())
		if not light.is_empty():
			out.append(light)
	return out


## [param text] with [param lights] (the file's coordinates) written into it
## after its first line, in their order, and any it had taken out; with none,
## only taken out.
static func written_into(text: String, lights: Array) -> String:
	if lights.is_empty() and not text.contains(META):
		return text
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		if not line.begins_with(META):
			kept.append(line)
	for n: int in mini(lights.size(), MOST):
		kept.insert(mini(1 + n, kept.size()), META + JSON.stringify(lights[n]))
	return "\n".join(kept)


## [param lights] as the window holds them, in the file's coordinates: the
## model stood [param lift] up from where its file has it (ModelStore.lift).
static func in_file(lights: Array, lift: Vector3) -> Array:
	var out: Array = []
	for light: Dictionary in lights:
		out.append(_with(light, (at_of(light) - lift) * LdrModel.FLIP,
			aim_of(light) * LdrModel.FLIP))
	return out


## [param lights] as a file keeps them, in the window's coordinates: the
## model stood [param lift] up from where its file has it.
static func placed(lights: Array, lift: Vector3) -> Array:
	var out: Array = []
	for light: Dictionary in lights:
		out.append(_with(light, at_of(light) * LdrModel.FLIP + lift,
			aim_of(light) * LdrModel.FLIP))
	return out


## [param lights] moved [param by] with the model they light: it stood lower
## or higher once its parts arrived (ModelStore._settle).
static func moved(lights: Array, by: Vector3) -> Array:
	var out: Array = []
	for light: Dictionary in lights:
		out.append(_with(light, at_of(light) + by, aim_of(light)))
	return out


## Whether [param a] and [param b] are the same lights, to a hundredth of an
## LDU and a ten-thousandth of their aim: what a file keeps of them is rounded.
static func same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for n: int in a.size():
		var one: Dictionary = a[n]
		var other: Dictionary = b[n]
		if str(one["kind"]) != str(other["kind"]) \
				or bool(one.get("shadows", true)) != bool(other.get("shadows", true)) \
				or not colour_of(one).is_equal_approx(colour_of(other)) \
				or at_of(one).distance_to(at_of(other)) > 0.01 \
				or aim_of(one).distance_to(aim_of(other)) > 0.0001:
			return false
		for field: String in ["strength", "cone", "size"]:
			if absf(float(one.get(field, 0.0)) - float(other.get(field, 0.0))) > 0.001:
				return false
	return true


# -- one light ------------------------------------------------------------------


## A new light of [param kind] (one of [constant KINDS]) lighting [param box],
## in the window's coordinates, the way a photographer would first set it:
## a spot well over it, its cone just taking it in; a bulb a little above it;
## a sun from [param from] (the way the window looks, towards the model) and
## above; a panel over it as wide as it is. Empty for a kind there is not.
static func made(kind: String, box: AABB, from: Vector3 = Vector3(-0.5, -0.6, -0.6)) -> Dictionary:
	if not kind in KINDS:
		return {}
	var middle: Vector3 = box.get_center()
	var span: float = maxf(Vector2(box.size.x, box.size.z).length(), 40.0)
	var top: float = box.end.y
	var light: Dictionary = {"kind": kind, "colour": WARM, "shadows": true}
	match kind:
		"spot":
			var height: float = maxf(span * 1.2, 120.0)
			light["at"] = _point(Vector3(middle.x, top + height, middle.z))
			light["aim"] = _point(Vector3.DOWN)
			# The cone just round what it lights, from where it hangs.
			light["cone"] = snappedf(clampf(rad_to_deg(2.0 * atan(span * 0.6 / height)),
				15.0, 90.0), 1.0)
			light["size"] = 4.0
			light["strength"] = snappedf(pow((height + top - middle.y) / REACH, 2.0) * 0.8, 0.1)
		"point":
			var above: float = maxf(box.size.y * 0.5, 30.0)
			light["at"] = _point(Vector3(middle.x, top + above, middle.z))
			light["aim"] = _point(Vector3.DOWN)
			light["size"] = 4.0
			light["strength"] = snappedf(pow((above + top - middle.y) / REACH, 2.0) * 0.5, 0.1)
		"directional":
			var way: Vector3 = from.normalized() if from.length() > 0.001 else Vector3.FORWARD
			# Down at least as steeply as the window's key.
			way = Vector3(way.x, minf(way.y, -0.55), way.z).normalized()
			light["aim"] = _point(way)
			light["at"] = _point(middle - way * span)
			light["size"] = 0.0
			light["strength"] = 0.6
		"area":
			var height: float = maxf(span, 100.0)
			light["at"] = _point(Vector3(middle.x, top + height, middle.z))
			light["aim"] = _point(Vector3.DOWN)
			light["size"] = snappedf(maxf(span * 0.6, 40.0), 1.0)
			light["strength"] = snappedf(pow((height + top - middle.y) / REACH, 2.0) * 0.6, 0.1)
	light["strength"] = clampf(float(light["strength"]), 0.1, STRONGEST)
	light["size"] = minf(float(light["size"]), 4000.0)
	# In the words a file keeps, as every light is.
	return typed(light)


## [param light] moved to where [param eye] is and shining the way it looks:
## a photographer holding the lamp where the camera stands. A sun takes only
## the way.
static func from_eye(light: Dictionary, eye: Transform3D) -> Dictionary:
	var way: Vector3 = -eye.basis.z.normalized()
	return _with(light, eye.origin, way)


## [param light] hung over [param box], shining straight down on it from
## where it is above it now (or a little above the box when it is below it),
## a spot's cone opened to take the box in.
static func over(light: Dictionary, box: AABB) -> Dictionary:
	var middle: Vector3 = box.get_center()
	var height: float = maxf(at_of(light).y - box.end.y, maxf(box.size.y, 60.0))
	var out: Dictionary = _with(light, Vector3(middle.x, box.end.y + height, middle.z),
		Vector3.DOWN)
	if str(light["kind"]) == "spot":
		var span: float = maxf(Vector2(box.size.x, box.size.z).length(), 20.0)
		out["cone"] = snappedf(clampf(rad_to_deg(2.0 * atan(span * 0.6 / height)),
			NARROWEST, 90.0), 1.0)
	return out


## Where [param light] is.
static func at_of(light: Dictionary) -> Vector3:
	var at: Array = light["at"]
	return Vector3(float(at[0]), float(at[1]), float(at[2]))


## The way [param light] shines.
static func aim_of(light: Dictionary) -> Vector3:
	var aim: Array = light["aim"]
	return Vector3(float(aim[0]), float(aim[1]), float(aim[2]))


## Its colour, as a person picked it (sRGB).
static func colour_of(light: Dictionary) -> Color:
	var said: String = str(light.get("colour", WARM))
	return Color.html(said) if Color.html_is_valid(said) else Color.html(WARM)


## How brightly [param light] lights a face square to it [param distance] LDU
## away, in the window's units (its key is [constant KEY]): a sun the same
## everywhere, a lamp by the square of the distance.
static func lit_at(light: Dictionary, distance: float) -> float:
	var strength: float = float(light.get("strength", 1.0)) * KEY
	if str(light["kind"]) == "directional":
		return strength
	return strength * REACH * REACH / maxf(distance * distance, 0.0001)


## The light's energy as Godot's lights take it under Forward+: a sun's on
## a face, a lamp's at one LDU (OmniLight3D and SpotLight3D fall off with the
## square of the distance, omni_attenuation 2).
static func energy(light: Dictionary) -> float:
	return lit_at(light, 1.0)


## A light's kind in words, as Render lists it: "Spot", "Sun"...
static func kind_words(kind: String) -> String:
	match kind:
		"point":
			return "Bulb"
		"spot":
			return "Spot"
		"directional":
			return "Sun"
		"area":
			return "Light panel"
	return kind


## The lights, in words for a session: where each is, which way it shines and
## how strongly, numbered from 1 as light_model's number= takes them.
static func words(lights: Array) -> String:
	if lights.is_empty():
		return "The model keeps no lights of its own."
	var out := PackedStringArray()
	out.append("The model keeps %d light%s of its own:" % [lights.size(),
		"" if lights.size() == 1 else "s"])
	for n: int in lights.size():
		var light: Dictionary = lights[n]
		var at: Vector3 = at_of(light)
		var aim: Vector3 = aim_of(light)
		var line: String = "%d. %s (%s), colour %s, strength %s" % [n + 1,
			kind_words(str(light["kind"])).to_lower(), str(light["kind"]),
			colour_of(light).to_html(false), _num(float(light.get("strength", 1.0)))]
		if str(light["kind"]) != "directional":
			line += ", at [%s, %s, %s]" % [_num(at.x), _num(at.y), _num(at.z)]
		if str(light["kind"]) != "point":
			line += ", shining towards [%s, %s, %s]" % [_num(aim.x), _num(aim.y), _num(aim.z)]
		if str(light["kind"]) == "spot":
			line += ", a cone of %s°" % _num(float(light.get("cone", 40.0)))
		if str(light["kind"]) == "area":
			line += ", %s LDU across" % _num(float(light.get("size", 40.0)))
		if not bool(light.get("shadows", true)):
			line += ", casting no shadow"
		out.append(line)
	return "\n".join(out)


static func _num(value: float) -> String:
	var rounded: float = snappedf(value, 0.01)
	return str(int(rounded)) if is_equal_approx(rounded, roundf(rounded)) else str(rounded)


## [param light] at [param at], shining along [param aim], its fields in one
## order, as typed() has them: the same light is the same words, which
## Together compares (Together._heal) and a file keeps. An aim already of
## unit length (to what a file keeps) is kept as it is, so a light read and
## written again is written the same.
static func _with(light: Dictionary, at: Vector3, aim: Vector3) -> Dictionary:
	var way: Vector3 = aim
	if absf(aim.length() - 1.0) > 0.00001:
		way = aim.normalized() if aim.length() > 0.000001 else Vector3.DOWN
	var out: Dictionary = {"kind": light.get("kind"), "at": _point(at),
		"aim": [snappedf(way.x, 0.000001), snappedf(way.y, 0.000001), snappedf(way.z, 0.000001)]}
	for field: String in ["colour", "strength", "shadows", "size", "cone"]:
		if light.has(field):
			out[field] = light[field]
	return out


static func _point(at: Vector3) -> Array:
	return [snappedf(at.x, 0.001), snappedf(at.y, 0.001), snappedf(at.z, 0.001)]


## A light's line, or light_model's words for one, read back: every number a
## number, finite and in reason, the kind one there is. Empty for anything
## else: a file is anybody's to edit, and a session's words anybody's to send.
static func parsed(said: Variant) -> Dictionary:
	var raw: Variant = JSON.parse_string(said) if said is String else said
	if not raw is Dictionary:
		return {}
	return typed(raw as Dictionary)


## [param given] as a light, each field checked and the rest filled in as a
## new light of its kind has them; empty when it is not one.
static func typed(given: Dictionary) -> Dictionary:
	var kind: Variant = given.get("kind")
	if not kind is String or not str(kind) in KINDS:
		return {}
	var at: Variant = _vector(given.get("at"))
	var aim: Variant = _vector(given.get("aim"))
	if at == null or aim == null or (aim as Vector3).length() < 0.001:
		return {}
	var light: Dictionary = _with({"kind": str(kind)}, at, aim)
	var colour: Variant = given.get("colour", WARM)
	if not colour is String or not Color.html_is_valid(str(colour)):
		return {}
	light["colour"] = "#" + Color.html(str(colour)).to_html(false)
	var strength: Variant = given.get("strength", 1.0)
	if not _number(strength) or float(strength) <= 0.0 or float(strength) > STRONGEST:
		return {}
	light["strength"] = snappedf(float(strength), 0.001)
	var shadows: Variant = given.get("shadows", true)
	light["shadows"] = shadows if shadows is bool else true
	var default_size: float = 40.0 if kind == "area" else (0.0 if kind == "directional" else 4.0)
	var size: Variant = given.get("size", default_size)
	if not _number(size) or float(size) < 0.0 or float(size) > 4000.0 \
			or (kind == "area" and float(size) <= 0.0):
		return {}
	light["size"] = snappedf(float(size), 0.001)
	if kind == "spot":
		var cone: Variant = given.get("cone", 40.0)
		if not _number(cone) or float(cone) < NARROWEST or float(cone) > WIDEST:
			return {}
		light["cone"] = snappedf(float(cone), 0.001)
	return light


static func _vector(said: Variant) -> Variant:
	if not said is Array or (said as Array).size() != 3:
		return null
	var out := Vector3.ZERO
	for n: int in 3:
		if not _number((said as Array)[n]):
			return null
		out[n] = float((said as Array)[n])
	return out


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) \
		and absf(float(value)) < 1e7
