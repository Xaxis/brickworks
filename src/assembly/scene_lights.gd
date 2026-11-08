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
## The most suns a model keeps: with the studio's three lights and its sky,
## eight, the most suns Godot draws at once under either renderer. Past it
## a sun added nothing in the window's light (lreview, 2026-11-07), and the
## tracer drew what the raster did not.
const SUNS := 4
## How many of a file's lines of a light's words are read at most: past
## them the rest are kept as they are, unread. A file of 200,000 lines that
## were no lights took twice as long to open as one of comments, each tried
## as JSON (lreview, 2026-11-07).
const TRIES := 64
## Strength 1 lights a face this far from a lamp as the window's key does.
const REACH := 100.0
## The window's key light, as StudioRender's RIG has it under Forward+.
const KEY := 0.9
## A spot's cone, whole, in degrees: its narrowest and widest.
const NARROWEST := 2.0
const WIDEST := 160.0
## How a spot's light falls to nothing at the edge of its cone: the power
## of the rim (1 - pow(rim, EDGE), path_tracer.glsl's as Godot's spot
## shader has it), so both ways of drawing have the one edge. Over most of
## the cone it is nearly whole, and it fades over its outer part. Godot
## raises the rim to the reciprocal of SpotLight3D's spot_angle_attenuation:
## the raster's is 1 / EDGE (set at 3, the raster's spot lit the floor beside
## the car a third as much as the tracer's, falling away from its middle).
const EDGE := 3.0
## The strongest a light is kept at.
const STRONGEST := 50.0
## The colour a new light has: a warm white, as a tungsten-balanced lamp.
const WARM := "#fff1d6"


# -- kept with the model --------------------------------------------------------


## What the one reading of a model's file (LdrModel.parse) holds of its
## lights, sorted: "lights" those it keeps, in its order, up to [constant
## MOST] of them and [constant SUNS] suns (the file's coordinates); "why" how
## many of its lines it could not read, by reason; "read" each kept light's
## line as the file has it and "twins" how many lines the same as it come
## before it, so a save finds it again; "unread" the model's other light
## lines, as they are, in their order; "sections" a sub-model's light lines
## by its key, as LdrModel.section_lights has them, and "units" the copies of
## each, by its key: a sub-model's lights are its own, and stay in it.
##
## It belongs to the model it was read from: ModelStore keeps it for the
## world's generation the model was laid in, and nothing else reads the file
## again for it.
static func of_model(model: LdrModel) -> Dictionary:
	var sorting: Dictionary = _sorting(model.light_lines)
	var units: Dictionary = {}
	if not model.section_lights.is_empty():
		var paths: Array = model.unit_sections.keys()
		paths.sort()
		for path: String in paths:
			var key: String = model.unit_sections[path]
			if model.section_lights.has(key):
				if not units.has(key):
					units[key] = []
				(units[key] as Array).append(path)
	sorting["sections"] = model.section_lights
	sorting["units"] = units
	return sorting


## [method of_model] of [param text] alone, read as an open reads it: for
## what has only a text (a test, a probe). The app reads a model's lights as
## it opens it, once, and never this way.
static func of_text(text: String) -> Dictionary:
	if not text.contains(_WORD):
		return _sorting(PackedStringArray())
	return of_model(LdrModel.parse(text))


## The lights [param text] keeps ([method of_text]).
static func read(text: String) -> Array:
	return of_text(text)["lights"]


## [param text]'s lights and how many lines it could not read, by reason
## ([method of_text]).
static func sorted(text: String) -> Dictionary:
	var read_now: Dictionary = of_text(text)
	return {"lights": read_now["lights"], "why": read_now["why"]}


## The model's light lines of [param text] it could not read, as they are
## ([method of_text]).
static func unread(text: String) -> PackedStringArray:
	return of_text(text)["unread"]


## Where [param text]'s own model's lines end (LdrModel.main_span).
static func main_end(text: String) -> int:
	return LdrModel.main_end(text)


## The word after "0 !BRICKWORKS" on a light's line.
const _WORD := "LIGHT"


## [param lines] (a model's light lines, as LdrModel.light_lines has them)
## sorted as [method of_model] says, but for "sections" and "units". Only a
## line whose words begin as a light's do ("{") is tried, and only the first
## [constant TRIES] of those: past them the rest are kept as they are,
## unread, uncounted but for how many. Every line is the file's own, read
## once, as the file was opened.
static func _sorting(lines: PackedStringArray) -> Dictionary:
	var lights: Array = []
	var read_lines := PackedStringArray()
	var twins := PackedInt32Array()
	var taken := PackedInt32Array()
	var why: Dictionary = {}
	var seen: Dictionary = {}
	var none: int = 0
	var tries: int = 0
	var n: int = 0
	while n < lines.size() and tries < TRIES:
		var line: String = lines[n]
		var body: String = _body(line) if line.contains("{") else ""
		if not body.begins_with("{"):
			none += 1
			n += 1
			continue
		# The lines the same as it before it, all tried: the same words.
		var twin: int = int(seen.get(line, 0))
		seen[line] = twin + 1
		tries += 1
		var said: Array = checked(body)
		var reason: String = said[1]
		if reason.is_empty():
			reason = joins(lights, said[0])
		if reason.is_empty():
			lights.append(said[0])
			read_lines.append(line)
			twins.append(twin)
			taken.append(n)
		else:
			why[reason] = int(why.get(reason, 0)) + 1
		n += 1
	if none > 0:
		why["not a light's words"] = int(why.get("not a light's words", 0)) + none
	if n < lines.size():
		why["past the first %d light lines, which are all that are read" % TRIES] = \
			lines.size() - n
	var unread_lines: PackedStringArray = lines
	if not taken.is_empty():
		unread_lines = PackedStringArray()
		var from: int = 0
		for at: int in taken:
			unread_lines.append_array(lines.slice(from, at))
			from = at + 1
		unread_lines.append_array(lines.slice(from))
	return {"lights": lights, "why": why, "read": read_lines, "twins": twins,
		"unread": unread_lines, "sections": {}, "units": {}}


## The words of a light's [param line] after its word: "{...}" for a light.
static func _body(line: String) -> String:
	var at: int = line.find(_WORD, line.findn("!BRICKWORKS") + 11)
	return line.substr(at + _WORD.length()).strip_edges() if at >= 0 else ""


## Why [param light] cannot join [param lights] in a model, or "": a model
## keeps at most [constant MOST] lights, [constant SUNS] of them suns.
static func joins(lights: Array, light: Dictionary) -> String:
	if lights.size() >= MOST:
		return "a model keeps at most %d lights" % MOST
	if str(light.get("kind", "")) == "directional":
		var suns: int = 0
		for one: Dictionary in lights:
			if str(one.get("kind", "")) == "directional":
				suns += 1
		if suns >= SUNS:
			return ("a model keeps at most %d suns: with the studio's three lights and its "
				+ "sky that is eight, the most a renderer draws") % SUNS
	return ""


## What an open left out of [param why] (as [method of_model] counts them),
## in words for the status bar, each reason a part of its own as the bar's
## parts are (" — "): "2 light lines not read, kept in the file as they are
## — of a kind there is not (...) — a model keeps at most 4 suns: ..."; ""
## for none.
static func unread_words(why: Dictionary) -> String:
	if why.is_empty():
		return ""
	var count: int = 0
	for reason: String in why:
		count += int(why[reason])
	var said: String = "1 light line not read, kept in the file as it is" if count == 1 \
		else "%d light lines not read, kept in the file as they are" % count
	return " — ".join(PackedStringArray([said]) + PackedStringArray(why.keys()))


## [param text] with [param lights] (the file's coordinates) written into it
## in place of the light lines it has that were read ([method of_text]), and
## the lines of [param carried] it lacks after them, as they are. For what
## has only a text; the app writes with [method written_with].
static func written_into(text: String, lights: Array,
		carried: PackedStringArray = PackedStringArray()) -> String:
	var had: Dictionary = of_text(text)
	var lacking := PackedStringArray()
	if not carried.is_empty():
		var has: Dictionary = {}
		for line: String in had["unread"]:
			has[line] = int(has.get(line, 0)) + 1
		for line: String in carried:
			if int(has.get(line, 0)) > 0:
				has[line] = int(has[line]) - 1
			else:
				lacking.append(line)
	return _written(text, lights, had, lacking)


## [param text], the model's file as it is being written, with [param
## lights] (the file's coordinates) written into it as [param read] (the open's
## reading, [method of_model]) says. Each light read and not changed since
## keeps its line as the file had it, where it had it; a light changed is
## written in the place of the line it was read from, one added after the
## light before it, and a line read whose light is gone taken out. Every
## other line is left where it is. With [param whole] (the text written
## whole, none of the file's light lines in it) the lines it could not read
## go in after the lights, as they are. Each line ends as the text's do.
static func written_with(text: String, lights: Array, read: Dictionary, whole: bool) -> String:
	return _written(text, lights, read,
		read.get("unread", PackedStringArray()) if whole else PackedStringArray())


## The lines of a sub-model that [param read] (an open's reading, [method
## of_model]) keeps, by the definition [param instances] (Assemblies
## .file_frames) writes each in: its first copy still in the model's. A
## sub-model none of whose copies is left takes its lines with it.
static func kept_in(read: Dictionary, instances: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var units: Dictionary = read.get("units", {})
	var sections: Dictionary = read.get("sections", {})
	for key: String in units:
		for path: String in units[key]:
			if not instances.has(path):
				continue
			var def: String = str((instances[path] as Dictionary)["def"])
			if not out.has(def):
				out[def] = PackedStringArray(sections[key])
			break
	return out


## [method written_with]'s work: [param adding] go in after the lights.
static func _written(text: String, lights: Array, read: Dictionary,
		adding: PackedStringArray) -> String:
	var lines_read: PackedStringArray = read.get("read", PackedStringArray())
	var count: int = mini(lights.size(), MOST)
	if count == 0 and adding.is_empty() and lines_read.is_empty():
		return text
	var said: Array = read.get("lights", [])
	var twins: PackedInt32Array = read.get("twins", PackedInt32Array())
	# Where each line read is now: its start, its end, the next line's start.
	var spans: Array[Vector3i] = []
	var words_read := PackedStringArray()
	for m: int in lines_read.size():
		spans.append(_line_at(text, lines_read[m], twins[m]))
		words_read.append(_words(said[m]))
	# Each light kept as it was keeps its line: the first line after the last
	# so kept whose light is the same. A light changed takes a line read whose
	# light is gone, between the lights round it; one added follows the light
	# before it.
	var own := PackedInt32Array()
	own.resize(count)
	own.fill(-1)
	var used: Dictionary = {}
	var last: int = -1
	for n: int in count:
		var words: String = _words(lights[n])
		for m: int in range(last + 1, lines_read.size()):
			if spans[m].x >= 0 and not used.has(m) and words_read[m] == words:
				own[n] = m
				used[m] = true
				last = m
				break
	## A line read -> the lines written in its place: an Array, which is
	## appended to where it is (a packed array read out is a copy).
	var into: Dictionary = {}
	var first := PackedStringArray()        ## those before every line read
	var at: int = -1
	var placed: bool = false
	for n: int in count:
		var line: String = META + JSON.stringify(lights[n])
		if own[n] >= 0:
			at = own[n]
			line = lines_read[at]
		else:
			var upper: int = lines_read.size()
			for k: int in range(n + 1, count):
				if own[k] >= 0:
					upper = own[k]
					break
			for m: int in range(at + 1, upper):
				if spans[m].x >= 0 and not used.has(m):
					used[m] = true
					at = m
					break
		if at < 0:
			first.append(line)
			continue
		if not into.has(at):
			into[at] = []
		(into[at] as Array).append(line)
		placed = true
	if placed:
		(into[at] as Array).append_array(Array(adding))
	else:
		first.append_array(adding)
	var eol: String = LdrModel.eol_of(text)
	var pieces := PackedStringArray()
	var from: int = 0
	var trim: bool = false
	for m: int in lines_read.size():
		var span: Vector3i = spans[m]
		if span.x < 0:
			continue
		pieces.append(text.substr(from, span.x - from))
		var here := PackedStringArray()
		if not first.is_empty():
			here = first
			first = PackedStringArray()
		here.append_array(PackedStringArray(into.get(m, [])))
		# Its own line end, "" for the text's last line when it had none.
		var ending: String = text.substr(span.y, span.z - span.y)
		trim = here.is_empty() and ending.is_empty()
		if not here.is_empty():
			pieces.append(eol.join(here) + ending)
		from = span.z
	pieces.append(text.substr(from))
	var out: String = "".join(pieces)
	if trim and from >= text.length():
		# The text's last line taken out: the line end before it goes too.
		out = out.trim_suffix("\n").trim_suffix("\r")
	# No line read is there (the text written whole): after the model's first.
	return LdrModel.into_main(out, first)


## Where the [param twin]th line after the first that is [param line] whole
## is in [param text]: its start, its end before its line end, and where the
## next line starts; x -1 when it is not there.
static func _line_at(text: String, line: String, twin: int) -> Vector3i:
	var from: int = 0
	var count: int = 0
	while true:
		var at: int = text.find(line, from)
		if at < 0:
			return Vector3i(-1, -1, -1)
		var end: int = at + line.length()
		var starts: bool = at == 0 or text[at - 1] == "\n"
		var ends: bool = end == text.length() or text[end] == "\n" \
			or (text[end] == "\r" and (end + 1 == text.length() or text[end + 1] == "\n"))
		if starts and ends:
			if count == twin:
				var next: int = text.find("\n", end)
				return Vector3i(at, end, text.length() if next < 0 else next + 1)
			count += 1
		from = at + 1
	return Vector3i(-1, -1, -1)


## [param light] in words to compare, as a file keeps it: -0 written as 0.
static func _words(light: Dictionary) -> String:
	var out: Dictionary = light.duplicate(true)
	for field: String in ["at", "aim"]:
		if out.get(field) is Array:
			var numbers: Array = out[field]
			for n: int in numbers.size():
				if numbers[n] is float:
					numbers[n] = float(numbers[n]) + 0.0
	return JSON.stringify(out)


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
	return checked(said)[0]


## [param said] (a light's line, its JSON, or the dictionary) as a light and
## "", or an empty light and why it is none, in words a person reads.
static func checked(said: Variant) -> Array:
	var raw: Variant = said
	if said is String:
		# Quietly: a line that is no JSON is no light, not an error.
		var json := JSON.new()
		if json.parse(said as String) != OK:
			return [{}, "not a light's words"]
		raw = json.data
	if not raw is Dictionary:
		return [{}, "not a light's words"]
	return _checked(raw as Dictionary)


## [param given] as a light, each field checked and the rest filled in as a
## new light of its kind has them; empty when it is not one.
static func typed(given: Dictionary) -> Dictionary:
	return _checked(given)[0]


## [method typed], and why not. Each number is rounded as a file keeps it
## before it is checked, so what is kept is what was checked: a strength of
## 0.0004 was kept, written as 0 and refused at the next open, and the model
## lost both its lights (lreview, 2026-11-07).
static func _checked(given: Dictionary) -> Array:
	var kind: Variant = given.get("kind")
	if not kind is String or not str(kind) in KINDS:
		return [{}, "of a kind there is not (spot, point, directional or area)"]
	var at: Variant = _vector(given.get("at"))
	var aim: Variant = _vector(given.get("aim"))
	if at == null or aim == null or (aim as Vector3).length() < 0.001:
		return [{}, "its at and aim are not three numbers each, aim not all 0"]
	var light: Dictionary = _with({"kind": str(kind)}, at, aim)
	var colour: Variant = given.get("colour", WARM)
	if not colour is String or not Color.html_is_valid(str(colour)):
		return [{}, "its colour is not #rrggbb"]
	light["colour"] = "#" + Color.html(str(colour)).to_html(false)
	var strength: Variant = given.get("strength", 1.0)
	var kept_strength: float = snappedf(float(strength), 0.001) if _number(strength) else -1.0
	if kept_strength <= 0.0 or kept_strength > STRONGEST:
		return [{}, "its strength is not above 0 (0.001 at least, as a file keeps it) to %d"
			% roundi(STRONGEST)]
	light["strength"] = kept_strength
	var shadows: Variant = given.get("shadows", true)
	light["shadows"] = shadows if shadows is bool else true
	var default_size: float = 40.0 if kind == "area" else (0.0 if kind == "directional" else 4.0)
	var size: Variant = given.get("size", default_size)
	var kept_size: float = snappedf(float(size), 0.001) if _number(size) else -1.0
	if kept_size < 0.0 or kept_size > 4000.0 or (kind == "area" and kept_size <= 0.0):
		return [{}, "its size is not 0 to 4000 LDU (a panel's above 0: 0.001 at least, as a "
			+ "file keeps it)"]
	light["size"] = kept_size
	if kind == "spot":
		var cone: Variant = given.get("cone", 40.0)
		var kept_cone: float = snappedf(float(cone), 0.001) if _number(cone) else -1.0
		if kept_cone < NARROWEST or kept_cone > WIDEST:
			return [{}, "its cone is not %d to %d degrees" % [roundi(NARROWEST), roundi(WIDEST)]]
		light["cone"] = kept_cone
	return [light, ""]


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
