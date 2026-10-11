## Making an element LEGO has not made: a brick, plate, tile, slope,
## curved slope, round part, bracket or Technic brick of any size, or a
## brick with studs on its sides, written as a real LDraw part file.
##
## A LEGO element designer asks for a new mould, or a change to an existing
## one, inside the system's dimensions. This is the same request made of the
## same system: a family and its dimensions in, an LDraw `.dat` out, built the
## way the official library builds the part it most resembles — `stud.dat`
## for every stud, `stud4.dat` tubes and `stud3.dat` pins underneath,
## `box5.dat` for the shell and the cavity — so that every tool which reads
## LDraw can draw it and this one can find its connectors by the same walk it
## uses for the other twenty-seven thousand.
##
## The numbers are the library's own, measured off the parts named beside
## each family (and pinned by tests/test_elements.py against those parts):
##
##   stud pitch 20 LDU (8 mm)      a stud 12 across, 4 tall   (stud.dat)
##   plate 8 LDU (3.2 mm)          brick 24, three plates      (3001)
##   wall 4 LDU (1.6 mm)           top 4 LDU                   (s/3001s01)
##   tube 16 across, 12 inside     between four studs          (stud4.dat)
##   slope lip 4 LDU               the vertical foot of a slope (3039, 3298)
##   side stud 10 under the top    then every 20 down          (87087, 22885)
##   bracket upright 4 LDU         past the plate's footprint  (99781, 44728)
##   Technic hole 10 under the top a 12 LDU bore, 16 mouth     (3700, 3701)
##
## Everything is in LDraw's own space: X right, Y *down*, origin at the
## middle of the footprint on the top of the body, the long side along X.
## The app's axis change happens where every other part's does, in the mesh
## build.
##
## What this does not do is design a mould. Draft angles, gate positions,
## ejector pins and the 0.1 mm a real brick is shy of its pitch are not in
## LDraw at all — see docs/custom-elements.md for what is known about those
## and what this is honest about not modelling.
class_name ElementMaker
extends RefCounted

const STUD := 20.0
const PLATE := 8.0
const WALL := 4.0
const TOP := 4.0
const LIP := 4.0
## The radius of a tube (stud4.dat drawn at 8) and of a 1-wide part's pin
## (stud3.dat at 4).
const TUBE_RADIUS := 8.0
const PIN_RADIUS := 4.0
const STUD_RADIUS := 6.0
## The largest element the maker will draw, in studs a side. LEGO's
## largest plates are 16 x 16 and its baseplates go to 48 x 48, which the
## library has; past 32 the app's own build of the part takes long enough
## (13 s for a 32 x 32 plate on a busy machine) that the dialog stalls.
const MOST_STUDS := 32
const MOST_PLATES := 36

## The families, by the word a designer would use.
const FAMILIES: Array[String] = ["brick", "slope", "inverted", "round", "curved",
	"bracket", "technic"]

## The sides a brick can carry studs on, in the order they are written:
## front (LDraw's -Z, the long face 87087 and 30414 put theirs on), back,
## left (-X) and right.
const SIDES := "fblr"
## The tallest bracket upright, in studs.
const MOST_RISE := 8
## A Technic brick's hole: its middle under the top, its bore and the
## mouth each face is counterbored to, as 3700 draws them; and the solid
## under the holes stops this far down, leaving a cavity for studs.
const HOLE_Y := 10.0
const BORE := 6.0
const MOUTH := 8.0
const HOLE_FLOOR := 18.0
## Steps along a curved slope's face: an eighth of a circle, as 11477 draws
## its own, in steps of 5.6 degrees.
const CURVE_STEPS := 8

## The four slope angles LEGO names, as the drop and run the library draws
## them with. LEGO's angle is a name, not a measurement: the "33" is 20 LDU
## of drop over 40 of run (26.6 degrees) in 3298, and the "75" is 68 over
## 20 (73.6) in 4460b. Picking a named angle picks that part's proportions.
##
## [run in studs, height in plates], from 3298, 3039, 60481 and 4460b.
const NAMED_ANGLES: Dictionary = {
	33: [2, 3],
	45: [1, 3],
	65: [1, 6],
	75: [1, 9],
}

## Who the header names as the author: the part was drawn by the program
## at a designer's request, and LDraw wants a name either way.
const AUTHOR := "Brickworks element maker"


## What to make. Built by the dialog, by [method from_part] when an
## existing part is being resized, or read back from a part's own header.
class Spec extends RefCounted:
	var family: String = "brick"
	## Studs along X, and along Z. A brick's long side is X, as in the
	## library; a slope is [member across] wide and [member deep] from
	## its back to the foot of the slope.
	var across: int = 4
	var deep: int = 2
	## Height in plates: 1 is a plate, 3 a brick.
	var plates: int = 3
	## False for a smooth top: a tile, or a round tile.
	var studs: bool = true
	## The rows a slope falls over, from the front. The rest are flat.
	var run: int = 1
	## A round part's diameter, in studs.
	var diameter: int = 2
	## A designer's own name for it. Empty takes the LDraw-style title.
	var title: String = ""
	## The part this was resized from, as "3001", when it was.
	var derived_from: String = ""
	## A brick's sides that carry studs, as letters of [constant SIDES].
	var sides: String = ""
	## A bracket's upright, in studs, and whether it hangs "down" from the
	## plate's front edge or stands "up" from it.
	var rise: int = 1
	var way: String = "down"

	func duplicate() -> Spec:
		var copy := Spec.new()
		copy.family = family
		copy.across = across
		copy.deep = deep
		copy.plates = plates
		copy.studs = studs
		copy.run = run
		copy.diameter = diameter
		copy.title = title
		copy.derived_from = derived_from
		copy.sides = sides
		copy.rise = rise
		copy.way = way
		return copy

	## The spec as a line of words, the form the header carries and the
	## form [method ElementMaker.parse_spec] reads.
	func to_words() -> String:
		var words: String = "family=%s" % family
		if family == "round":
			words += " diameter=%d" % diameter
		else:
			words += " across=%d deep=%d" % [across, deep]
		words += " plates=%d" % plates
		if family == "slope" or family == "inverted" or family == "curved":
			words += " run=%d" % run
		if family == "bracket":
			words += " rise=%d way=%s" % [rise, way]
		if not sides.is_empty():
			words += " sides=%s" % sides
		# A curve over the whole depth has no flat rows for a stud to stand
		# on, so with studs or without it is the same part.
		var studded: bool = studs or (family == "curved" and run == deep)
		words += " studs=%s" % ("yes" if studded else "no")
		if not derived_from.is_empty():
			words += " from=%s" % derived_from
		return words


## Why a spec cannot be made, or "" when it can. Said in a designer's words,
## because the dialog shows it.
static func problem(spec: Spec) -> String:
	if not FAMILIES.has(spec.family):
		return "there is no family called %s" % spec.family
	if spec.plates < 1 or spec.plates > MOST_PLATES:
		return "a part is 1 to %d plates tall" % MOST_PLATES
	if not spec.sides.is_empty():
		if spec.family != "brick":
			return "only a brick carries studs on its sides"
		for n: int in spec.sides.length():
			var letter: String = spec.sides[n]
			if not SIDES.contains(letter) or spec.sides.count(letter) > 1:
				return "the sides are f, b, l and r (front, back, left, right), each once"
		if spec.plates < 3:
			# A side stud is 12 LDU across and its row 20 LDU, which a part
			# shorter than a brick has no room for.
			return "studs on a side need a part at least a brick (3 plates) tall"
	if spec.family == "round":
		if spec.diameter < 1 or spec.diameter > 16:
			return "a round part is 1 to 16 studs across"
		return ""
	if spec.across < 1 or spec.deep < 1 \
			or spec.across > MOST_STUDS or spec.deep > MOST_STUDS:
		return "each side is 1 to %d studs" % MOST_STUDS
	if spec.family == "slope" or spec.family == "inverted":
		if spec.deep < 2:
			return "a slope needs at least 2 rows: one flat, one falling"
		if spec.run < 1 or spec.run >= spec.deep:
			return "the slope falls over 1 to %d rows, leaving one flat" \
				% (spec.deep - 1)
		if spec.plates < 2:
			return "a slope is at least 2 plates tall"
	if spec.family == "curved":
		if spec.run < 1 or spec.run > spec.deep:
			return "the curve falls over 1 to %d rows" % spec.deep
		if spec.plates < 2:
			return "a curved slope is at least 2 plates tall"
	if spec.family == "bracket":
		if spec.plates != 1:
			return "a bracket's flat part is a plate: 1 plate tall"
		if spec.rise < 1 or spec.rise > MOST_RISE:
			return "a bracket's upright is 1 to %d studs tall" % MOST_RISE
		if spec.way != "down" and spec.way != "up":
			return "a bracket's upright goes down or up"
	if spec.family == "technic":
		if spec.deep != 1:
			return "a Technic brick is one stud wide; its holes run through that way"
		if spec.plates != 3:
			return "a Technic brick is one brick (3 plates) tall"
	return ""


## The angle a slope's face really makes with the ground, in degrees. A
## curved slope's is where it is steepest, at its foot.
static func true_angle(spec: Spec) -> float:
	if spec.family == "curved":
		var foot_rise: float = spec.plates * PLATE - LIP
		# The eighth of a circle leaves the foot at dy/dz = Ay / Az, with
		# Ay the drop over (sqrt 2 - 1): see [method curve_profile].
		return rad_to_deg(atan2(foot_rise / (sqrt(2.0) - 1.0), spec.run * STUD))
	if spec.family != "slope" and spec.family != "inverted":
		return 0.0
	var drop: float = spec.plates * PLATE - LIP
	return rad_to_deg(atan2(drop, spec.run * STUD))


## The nearest named angle to what a slope really is, or 0 when it is not
## close to any of them (within five degrees of the part that name means).
static func named_angle(spec: Spec) -> int:
	var best: int = 0
	var off: float = 5.0
	for name: int in NAMED_ANGLES:
		var shape: Array = NAMED_ANGLES[name]
		var probe := Spec.new()
		probe.family = "slope"
		probe.run = int(shape[0])
		probe.plates = int(shape[1])
		var gap: float = absf(true_angle(probe) - true_angle(spec))
		if gap < off:
			off = gap
			best = name
	return best


## Set a slope to one of the named angles, keeping its width and as much
## of its depth as the angle allows.
static func use_angle(spec: Spec, name: int) -> void:
	if not NAMED_ANGLES.has(name):
		return
	var shape: Array = NAMED_ANGLES[name]
	spec.run = int(shape[0])
	spec.plates = int(shape[1])
	spec.deep = maxi(spec.deep, spec.run + 1)


## The LDraw-style title: "Brick  2 x  7", "Slope Brick 45  3 x  2".
static func title_for(spec: Spec) -> String:
	if not spec.title.strip_edges().is_empty():
		return spec.title.strip_edges()
	match spec.family:
		"round":
			var word: String = _word(spec)
			return "%s %s x %s%s Round" % [word, _pad(spec.diameter),
				_pad(spec.diameter), _height_words(spec)]
		"slope", "inverted":
			var named: int = named_angle(spec)
			var angle: String = str(named) if named > 0 \
				else str(int(round(true_angle(spec))))
			return "Slope Brick %s %s x %s%s%s" % [angle, _pad(spec.deep),
				_pad(spec.across), _bricks_words(spec),
				" Inverted" if spec.family == "inverted" else ""]
		"curved":
			return "Slope Brick Curved %s x %s%s%s" % [_pad(spec.deep), _pad(spec.across),
				_bricks_words(spec), "" if spec.studs or spec.run == spec.deep
					else " without Studs"]
		"bracket":
			# The library's way: the plate, then the upright, both short
			# side first — "Bracket  1 x  2 -  2 x  2 Down".
			return "Bracket %s x %s - %s x %s %s%s" % [_pad(spec.deep), _pad(spec.across),
				_pad(spec.rise), _pad(spec.across), spec.way.capitalize(),
				"" if spec.studs else " without Top Studs"]
		"technic":
			return "Technic Brick %s x %s with Hole%s%s" % [_pad(1), _pad(spec.across),
				"" if spec.across <= 2 else "s", "" if spec.studs else " without Studs"]
	var short: int = mini(spec.across, spec.deep)
	var long: int = maxi(spec.across, spec.deep)
	return "%s %s x %s%s%s" % [_word(spec), _pad(short), _pad(long),
		_height_words(spec), _sides_words(spec)]


## "with Stud on 1 Side", "with Studs on Two Opposite Sides": what the
## library calls a brick with studs on its sides (87087, 47905, 4733).
static func _sides_words(spec: Spec) -> String:
	if spec.sides.is_empty():
		return ""
	var count: int = 0
	for n: int in spec.sides.length():
		var letter: String = spec.sides[n]
		count += maxi(spec.across, spec.deep) if letter == "f" or letter == "b" \
			else mini(spec.across, spec.deep)
	count *= side_rows(spec).size()
	var studs_word: String = "Stud" if count == 1 else "Studs"
	var opposite: bool = spec.sides.length() == 2 and (
		(spec.sides.contains("f") and spec.sides.contains("b"))
		or (spec.sides.contains("l") and spec.sides.contains("r")))
	if opposite:
		return " with %s on Two Opposite Sides" % studs_word
	if spec.sides.length() == 1:
		return " with %s on 1 Side" % studs_word
	return " with %s on %s Sides" % [studs_word,
		["", "", "Two Adjacent", "Three", "Four"][spec.sides.length()]]


## The heights a brick's side studs stand at, in LDU under its top: the
## first 10 down, as 87087's is, so a plate on it lines up with the top,
## and then one every 20, as 22885's two rows are, while a whole row fits.
static func side_rows(spec: Spec) -> Array[float]:
	var rows: Array[float] = []
	var h: float = spec.plates * PLATE
	var k: int = 0
	while k * STUD + STUD <= h:
		rows.append(STUD * 0.5 + k * STUD)
		k += 1
	return rows


## Plate, Tile or Brick, by height and top.
static func _word(spec: Spec) -> String:
	if spec.plates == 1:
		return "Plate" if spec.studs else "Tile"
	return "Brick"


## What a height says after the footprint. A plate or a brick says nothing:
## the word already did.
static func _height_words(spec: Spec) -> String:
	if spec.plates == 1 or spec.plates == 3:
		return "" if spec.studs or spec.plates == 1 else " without Studs"
	return _thirds(spec.plates) + ("" if spec.studs else " without Studs")


## A slope says its height only when it is not one brick, as the library's
## do: "Slope Brick 65  2 x  2 x  2".
static func _bricks_words(spec: Spec) -> String:
	return "" if spec.plates == 3 else _thirds(spec.plates)


## A height in bricks and thirds, the library's way: " x  2", " x   2/3",
## " x  1 & 1/3".
static func _thirds(plates: int) -> String:
	var whole: int = plates / 3
	var rest: int = plates % 3
	if rest == 0:
		return " x %s" % _pad(whole)
	if whole == 0:
		return " x   %d/3" % rest
	return " x %s & %d/3" % [_pad(whole), rest]


static func _pad(n: int) -> String:
	return ("%2d" % n)


## The LDraw category the part belongs to, which is what its header says.
## The app files every made part under "Custom" as well; this is what it
## is to every other tool.
static func category_for(spec: Spec) -> String:
	match spec.family:
		"slope", "inverted", "curved":
			return "Slope"
		"bracket":
			return "Bracket"
		"technic":
			return "Technic"
	return _word(spec)


## A file name for the part, unique to its shape. LDraw's own numbers are
## LEGO's design numbers, which a made part does not have, so it is named
## in its own space: "bw-" and the shape, which no LDraw number begins with.
static func id_for(spec: Spec) -> String:
	var tail: String = ""
	match spec.family:
		"round":
			tail = "r%dx%d" % [spec.diameter, spec.plates]
		"slope":
			tail = "s%dx%dx%dr%d" % [spec.deep, spec.across, spec.plates, spec.run]
		"inverted":
			tail = "i%dx%dx%dr%d" % [spec.deep, spec.across, spec.plates, spec.run]
		"curved":
			tail = "c%dx%dx%dr%d" % [spec.deep, spec.across, spec.plates, spec.run]
		"bracket":
			tail = "k%dx%dx%d%s" % [spec.deep, spec.across, spec.rise, spec.way.left(1)]
		"technic":
			tail = "h1x%d" % spec.across
		_:
			tail = "b%dx%dx%d" % [mini(spec.across, spec.deep),
				maxi(spec.across, spec.deep), spec.plates]
	if not spec.studs and not (spec.family == "curved" and spec.run == spec.deep):
		tail += "t"
	if not spec.sides.is_empty():
		tail += "-s" + spec.sides
	return "bw-" + tail


## The part file. Returns "" for a spec [method problem] refuses.
static func dat(spec: Spec, id: String = "") -> String:
	if not problem(spec).is_empty():
		return ""
	if id.is_empty():
		id = id_for(spec)
	var out := PackedStringArray()
	out.append("0 " + title_for(spec))
	out.append("0 Name: %s.dat" % id)
	out.append("0 Author: " + AUTHOR)
	out.append("0 !LDRAW_ORG Unofficial_Part")
	out.append("0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt")
	out.append("")
	out.append("0 BFC CERTIFY CCW")
	out.append("")
	out.append("0 !CATEGORY " + category_for(spec))
	out.append("0 !KEYWORDS Brickworks, custom element")
	out.append("")
	out.append(MADE_BY + " " + spec.to_words())
	if not spec.derived_from.is_empty():
		out.append("0 // Resized from %s.dat" % spec.derived_from)
	out.append("")
	var body := PackedStringArray()
	match spec.family:
		"round":
			_round(spec, body)
		"slope":
			_slope(spec, body)
		"inverted":
			_inverted(spec, body)
		"curved":
			_curved(spec, body)
		"bracket":
			_bracket(spec, body)
		"technic":
			_technic(spec, body)
		_:
			_box(spec, body)
			if not spec.sides.is_empty():
				_side_studs(spec, body)
	out.append_array(body)
	out.append("0")
	return "\n".join(out) + "\n"


## Read the spec a made part carries in its header, or null for a part
## this did not make.
static func parse_spec(text: String) -> Spec:
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if not line.begins_with(MADE_BY):
			continue
		var spec: Spec = from_words(line.substr(MADE_BY.length()))
		var title: String = text.split("\n")[0].strip_edges().trim_prefix("0").strip_edges()
		spec.title = "" if title == title_for(spec) else title
		return spec
	return null


const MADE_BY := "0 // Made by Brickworks:"


## A spec from the words [method Spec.to_words] writes.
static func from_words(words: String) -> Spec:
	var spec := Spec.new()
	for word: String in words.strip_edges().split(" ", false):
		var pair: PackedStringArray = word.split("=")
		if pair.size() != 2:
			continue
		match pair[0]:
			"family": spec.family = pair[1]
			"across": spec.across = pair[1].to_int()
			"deep": spec.deep = pair[1].to_int()
			"plates": spec.plates = pair[1].to_int()
			"run": spec.run = pair[1].to_int()
			"diameter": spec.diameter = pair[1].to_int()
			"studs": spec.studs = pair[1] != "no"
			"from": spec.derived_from = pair[1]
			"sides": spec.sides = canonical_sides(pair[1])
			"rise": spec.rise = pair[1].to_int()
			"way": spec.way = pair[1]
	return spec


## Sides in the order they are written, each once, whatever order they
## were given in: "rf" and "fr" are the same brick.
static func canonical_sides(text: String) -> String:
	var out: String = ""
	var given: String = text.to_lower()
	for n: int in SIDES.length():
		if given.contains(SIDES[n]):
			out += SIDES[n]
	# A letter that is not a side is kept, so problem() can say so rather
	# than a typo quietly becoming a different brick.
	for n: int in given.length():
		if not SIDES.contains(given[n]) and not out.contains(given[n]):
			out += given[n]
	return out


## The spec that makes a standard part, read from its LDraw name: the way
## into resizing a part rather than starting from nothing.
##
## Only the plain families are recognised — "Brick  2 x  4", "Plate  1 x  6",
## "Tile  2 x  2 with Groove", "Slope Brick 45  2 x  2", "Slope Brick 33
## 3 x  2 Inverted", "Brick  2 x  2 Round", "Plate  4 x  4 Round" — and a
## name that says anything more (printed, with a clip, with a hole) is not
## a plain part and returns null rather than a part it is not.
static func from_part(part_id: String, name: String, tall: float = 0.0) -> Spec:
	var text: String = name.strip_edges()
	if text.begins_with("~") or text.begins_with("="):
		return null
	var words: PackedStringArray = text.replace("&", " ").split(" ", false)
	if words.is_empty():
		return null
	var spec := Spec.new()
	spec.derived_from = part_id
	var at: int = 0
	var head: String = words[0]
	# "Slope Brick Curved  2 x  1": its name has no height, so the part's
	# own ([param tall], LDU from top to bottom) says how many plates.
	if head == "Slope" and words.size() > 2 and words[1] == "Brick" \
			and words[2] == "Curved":
		var found_curve: Array = _dims(words, 3)
		if found_curve.is_empty() or int(found_curve[3]) != words.size():
			return null
		spec.family = "curved"
		spec.deep = int(found_curve[0])
		spec.across = int(found_curve[1])
		spec.run = spec.deep
		spec.studs = false
		spec.plates = int(found_curve[2]) if int(found_curve[2]) > 0 \
			else int(round(tall / PLATE))
		return spec if problem(spec).is_empty() else null
	# "Bracket  1 x  2 -  2 x  2 Down": the plate, then the upright.
	if head == "Bracket":
		var plate: Array = _dims(words, 1)
		if plate.is_empty() or int(plate[2]) != 0:
			return null
		var dash: int = int(plate[3])
		if dash >= words.size() or words[dash] != "-":
			return null
		var upright: Array = _dims(words, dash + 1)
		if upright.is_empty() or int(upright[2]) != 0 \
				or int(upright[3]) != words.size() - 1:
			return null
		var way: String = words[words.size() - 1].to_lower()
		if (way != "down" and way != "up") or int(upright[1]) != int(plate[1]):
			return null
		spec.family = "bracket"
		spec.deep = int(plate[0])
		spec.across = int(plate[1])
		spec.plates = 1
		spec.rise = int(upright[0])
		spec.way = way
		return spec if problem(spec).is_empty() else null
	# "Technic Brick  1 x  4 with Holes".
	if head == "Technic" and words.size() > 1 and words[1] == "Brick":
		var technic: Array = _dims(words, 2)
		if technic.is_empty() or int(technic[0]) != 1 or int(technic[2]) != 0:
			return null
		var tail: String = " ".join(words.slice(int(technic[3])))
		if tail != "with Hole" and tail != "with Holes":
			return null
		spec.family = "technic"
		spec.across = int(technic[1])
		spec.deep = 1
		spec.plates = 3
		return spec if problem(spec).is_empty() else null
	if head == "Slope" and words.size() > 2 and words[1] == "Brick":
		var angle: int = words[2].to_int()
		if not NAMED_ANGLES.has(angle):
			return null
		spec.family = "slope"
		at = 3
		var dims: Array = _dims(words, at)
		if dims.is_empty():
			return null
		spec.deep = int(dims[0])
		spec.across = int(dims[1])
		at = int(dims[3])
		var shape: Array = NAMED_ANGLES[angle]
		spec.run = int(shape[0])
		spec.plates = int(dims[2]) if int(dims[2]) > 0 else int(shape[1])
		if spec.run >= spec.deep:
			return null
		var rest: PackedStringArray = words.slice(at)
		if rest.size() == 1 and rest[0] == "Inverted":
			spec.family = "inverted"
		elif not rest.is_empty():
			return null
		return spec if problem(spec).is_empty() else null
	if not head in ["Brick", "Plate", "Tile"]:
		return null
	var found: Array = _dims(words, 1)
	if found.is_empty():
		return null
	at = int(found[3])
	var rest: PackedStringArray = words.slice(at)
	var is_round: bool = false
	if not rest.is_empty() and rest[0] == "Round":
		is_round = true
		rest = rest.slice(1)
	# A tile's groove is the only qualifier a plain part carries — and a
	# brick's studs on its sides, which the maker makes too.
	if rest.size() == 2 and rest[0] == "with" and rest[1] == "Groove":
		rest = PackedStringArray()
	if not is_round and head == "Brick":
		var sides: String = SIDE_NAMES.get(" ".join(rest), "")
		if not sides.is_empty():
			spec.sides = sides
			rest = PackedStringArray()
	if not rest.is_empty():
		return null
	spec.studs = head != "Tile"
	spec.plates = int(found[2]) if int(found[2]) > 0 else (3 if head == "Brick" else 1)
	if is_round:
		if int(found[0]) != int(found[1]):
			return null
		spec.family = "round"
		spec.diameter = int(found[0])
	else:
		spec.family = "brick"
		spec.across = maxi(int(found[0]), int(found[1]))
		spec.deep = mini(int(found[0]), int(found[1]))
	return spec if problem(spec).is_empty() else null


## What the library's names for bricks with side studs say, as the sides
## the maker puts them on: the long face first, as 87087 and 30414 do.
const SIDE_NAMES: Dictionary = {
	"with Stud on 1 Side": "f",
	"with Studs on 1 Side": "f",
	"with Studs on Side": "f",
	"with Studs on One Side": "f",
	"with Two Studs on One Side": "f",
	"with Studs on Two Opposite Sides": "fb",
	"with Studs on 2 Opposite Sides": "fb",
	"with Studs on Four Sides": "fblr",
	"with Studs on 4 Sides": "fblr",
}


## "2 x 4" or "2 x 4 x 2/3" from words[at], as [first, second, plates or
## 0, the index after them]; empty if the words are not dimensions.
static func _dims(words: PackedStringArray, at: int) -> Array:
	if words.size() < at + 3 or words[at + 1] != "x":
		return []
	if not words[at].is_valid_int() or not words[at + 2].is_valid_int():
		return []
	var first: int = words[at].to_int()
	var second: int = words[at + 2].to_int()
	var plates: int = 0
	var next: int = at + 3
	if words.size() > next + 1 and words[next] == "x":
		var thirds: int = 0
		var cursor: int = next + 1
		if words[cursor].is_valid_int():
			thirds = words[cursor].to_int() * 3
			cursor += 1
		elif words[cursor].is_valid_float():
			# The library's newer names: "x  0.667", "x  1.667".
			thirds = int(round(words[cursor].to_float() * 3.0))
			cursor += 1
		if cursor < words.size() and words[cursor].contains("/3"):
			thirds += words[cursor].get_slice("/", 0).to_int()
			cursor += 1
		if thirds <= 0:
			return []
		plates = thirds
		next = cursor
	return [first, second, plates, next]


# -- the families -----------------------------------------------------------


## Brick, plate and tile: s/3001s01 and s/3023bs01, at any size. Studs on
## top, a shell, a cavity four LDU in from every wall, and underneath tubes
## between every four studs — or pins between every two, on a part one stud
## wide — running from the cavity's ceiling to the bottom.
static func _box(spec: Spec, out: PackedStringArray) -> void:
	var along: int = maxi(spec.across, spec.deep)
	var over: int = mini(spec.across, spec.deep)
	var x: float = along * STUD * 0.5
	var z: float = over * STUD * 0.5
	var h: float = spec.plates * PLATE
	if spec.studs:
		_studs_on_top(out, along, over, 0.0, 0.0, 0.0)
	out.append("0 // Shell")
	if spec.studs or spec.plates > 1:
		out.append(_ref(0, h, 0, x, 0, 0, 0, -h, 0, 0, 0, z, "box5.dat"))
		_rim(out, h, -x, x, -z, z, -x + WALL, x - WALL, -z + WALL, z - WALL)
	else:
		# A tile's groove: the shell stops a plate's eighth short of the
		# bottom and steps in by one, as s/3068bs01 draws it.
		out.append(_ref(0, h - 1.0, 0, x, 0, 0, 0, -(h - 1.0), 0, 0, 0, z, "box5.dat"))
		_rim(out, h - 1.0, -x, x, -z, z, -x + 1.0, x - 1.0, -z + 1.0, z - 1.0)
		out.append(_ref(0, h - 1.0, 0, x - 1.0, 0, 0, 0, 1, 0, 0, 0, z - 1.0, "box4.dat"))
		_rim(out, h, -x + 1.0, x - 1.0, -z + 1.0, z - 1.0,
			-x + WALL, x - WALL, -z + WALL, z - WALL)
	_cavity(out, h, x - WALL, z - WALL, 0.0)
	_underside(out, along, over, 0.0, 0.0, h, func(_at: float) -> float: return TOP)


## A slope: 3039 and 3298, at any width, depth, run and height.
##
## A flat run of studded rows at the back, the face falling from the front
## edge of those rows to a four-LDU lip at the foot, and a cavity whose
## ceiling follows the face four LDU beneath it, as the real parts' do.
## The tubes underneath start at that ceiling, on its low side, so none of
## them comes through the face.
static func _slope(spec: Spec, out: PackedStringArray) -> void:
	var x: float = spec.across * STUD * 0.5
	var back: float = spec.deep * STUD * 0.5
	var front: float = -back
	var edge: float = back - (spec.deep - spec.run) * STUD   ## where the face starts
	var h: float = spec.plates * PLATE
	var foot: float = h - LIP

	if spec.studs:
		_studs_on_top(out, spec.across, spec.deep - spec.run, 0.0,
			0.0, back - (spec.deep - spec.run) * STUD * 0.5)
	out.append("0 // Top, face, lip and back")
	_face(out, [[x, 0, back], [-x, 0, back], [-x, 0, edge], [x, 0, edge]], [0, -1, 0])
	var fall: Array = [0.0, -(edge - front), -foot]   ## outward: up and forward
	_face(out, [[x, 0, edge], [-x, 0, edge], [-x, foot, front], [x, foot, front]],
		[0, fall[1], fall[2]])
	_face(out, [[x, foot, front], [-x, foot, front], [-x, h, front], [x, h, front]],
		[0, 0, -1])
	_face(out, [[x, 0, back], [x, h, back], [-x, h, back], [-x, 0, back]], [0, 0, 1])
	for side: float in [x, -x]:
		var way: float = signf(side)
		_face(out, [[side, 0, back], [side, 0, edge], [side, h, edge], [side, h, back]],
			[way, 0, 0])
		_face(out, [[side, h, edge], [side, 0, edge], [side, foot, front],
			[side, h, front]], [way, 0, 0])
	_outline(out, [[x, 0, back], [-x, 0, back], [-x, 0, edge], [x, 0, edge]])
	_line(out, [x, foot, front], [-x, foot, front])
	_line(out, [x, h, front], [-x, h, front])
	_line(out, [x, h, back], [-x, h, back])
	for side: float in [x, -x]:
		_line(out, [side, 0, back], [side, h, back])
		_line(out, [side, 0, edge], [side, foot, front])
		_line(out, [side, foot, front], [side, h, front])
		_line(out, [side, h, back], [side, h, front])

	# The cavity, open underneath, its ceiling four LDU under the top and
	# the face.
	var ix: float = x - WALL
	var ib: float = back - WALL
	var iff: float = front + WALL
	var ceiling: Callable = func(at: float) -> float:
		if at >= edge:
			return TOP
		return TOP + foot * (edge - at) / (edge - front)
	var low: float = ceiling.call(iff)
	out.append("0 // Cavity")
	_rim(out, h, -x, x, front, back, -ix, ix, iff, ib)
	_face(out, [[ix, TOP, ib], [-ix, TOP, ib], [-ix, TOP, edge], [ix, TOP, edge]],
		[0, 1, 0])
	_face(out, [[ix, TOP, edge], [-ix, TOP, edge], [-ix, low, iff], [ix, low, iff]],
		[0, -fall[1], -fall[2]])
	_face(out, [[ix, low, iff], [-ix, low, iff], [-ix, h, iff], [ix, h, iff]], [0, 0, 1])
	_face(out, [[ix, TOP, ib], [ix, h, ib], [-ix, h, ib], [-ix, TOP, ib]], [0, 0, -1])
	for side: float in [ix, -ix]:
		var inward: float = -signf(side)
		_face(out, [[side, TOP, ib], [side, TOP, edge], [side, h, edge], [side, h, ib]],
			[inward, 0, 0])
		_face(out, [[side, h, edge], [side, TOP, edge], [side, low, iff],
			[side, h, iff]], [inward, 0, 0])
	_outline(out, [[ix, TOP, ib], [-ix, TOP, ib], [-ix, TOP, edge], [ix, TOP, edge]])
	_line(out, [ix, low, iff], [-ix, low, iff])
	for side: float in [ix, -ix]:
		_line(out, [side, TOP, ib], [side, h, ib])
		_line(out, [side, TOP, edge], [side, low, iff])
		_line(out, [side, low, iff], [side, h, iff])
	_underside(out, spec.across, spec.deep, 0.0, 0.0, h, ceiling)


## An inverted slope: 3660, at any size. The whole top is studded; the back
## rows stand on a flat bottom with a cavity like a brick's; under the front
## rows the bottom rises to a four-LDU lip at the top of the front face.
##
## The wedge under the face is drawn solid. A real mould cores it out from
## the back to keep the wall even, which LDraw's 3660 draws as a pocket the
## app's collision fills anyway; here it is left out, and said so.
static func _inverted(spec: Spec, out: PackedStringArray) -> void:
	var x: float = spec.across * STUD * 0.5
	var back: float = spec.deep * STUD * 0.5
	var front: float = -back
	var flat: int = spec.deep - spec.run
	var edge: float = back - flat * STUD   ## where the bottom starts rising
	var h: float = spec.plates * PLATE

	if spec.studs:
		_studs_on_top(out, spec.across, spec.deep, 0.0, 0.0, 0.0)
	out.append("0 // Top, lip, face and back")
	_face(out, [[x, 0, back], [-x, 0, back], [-x, 0, front], [x, 0, front]], [0, -1, 0])
	_face(out, [[x, 0, front], [-x, 0, front], [-x, LIP, front], [x, LIP, front]],
		[0, 0, -1])
	var under: Array = [0.0, edge - front, -(h - LIP)]   ## outward: down and forward
	_face(out, [[x, LIP, front], [-x, LIP, front], [-x, h, edge], [x, h, edge]],
		[0, under[1], under[2]])
	_face(out, [[x, 0, back], [x, h, back], [-x, h, back], [-x, 0, back]], [0, 0, 1])
	for side: float in [x, -x]:
		var way: float = signf(side)
		_face(out, [[side, 0, back], [side, 0, edge], [side, h, edge], [side, h, back]],
			[way, 0, 0])
		_face(out, [[side, 0, edge], [side, 0, front], [side, LIP, front],
			[side, h, edge]], [way, 0, 0])
	_outline(out, [[x, 0, back], [-x, 0, back], [-x, 0, front], [x, 0, front]])
	_line(out, [x, LIP, front], [-x, LIP, front])
	_line(out, [x, h, edge], [-x, h, edge])
	_line(out, [x, h, back], [-x, h, back])
	for side: float in [x, -x]:
		_line(out, [side, 0, back], [side, h, back])
		_line(out, [side, 0, front], [side, LIP, front])
		_line(out, [side, LIP, front], [side, h, edge])
		_line(out, [side, h, edge], [side, h, back])

	out.append("0 // Cavity under the flat rows")
	var middle: float = (edge + back) * 0.5
	var half: float = (back - edge) * 0.5
	_rim(out, h, -x, x, edge, back, -x + WALL, x - WALL, edge + WALL, back - WALL)
	_cavity(out, h, x - WALL, half - WALL, middle)
	_underside(out, spec.across, flat, 0.0, middle, h,
		func(_at: float) -> float: return TOP)


## A round brick, plate or tile: 3941 and 4032 without their axle holes.
##
## The wall is 4-4cyli scaled to the radius, the top a 4-4disc, the cavity
## an inverted cylinder four LDU in; the bottom ring is drawn out in quads
## on the same sixteen points the primitives use, so the two meet exactly.
## Studs go wherever a whole stud fits on the top, tubes wherever a whole
## tube fits in the cavity.
static func _round(spec: Spec, out: PackedStringArray) -> void:
	var r: float = spec.diameter * STUD * 0.5
	var inner: float = r - WALL
	var h: float = spec.plates * PLATE
	if spec.studs:
		out.append("0 // Studs")
		for i: int in spec.diameter:
			for j: int in spec.diameter:
				var sx: float = -r + STUD * 0.5 + i * STUD
				var sz: float = -r + STUD * 0.5 + j * STUD
				if sqrt(sx * sx + sz * sz) + STUD_RADIUS <= r + 0.5:
					out.append(_ref(sx, 0, sz, 1, 0, 0, 0, 1, 0, 0, 0, 1, "stud.dat"))
	out.append("0 // Wall, top and bottom ring")
	out.append(_ref(0, 0, 0, r, 0, 0, 0, h, 0, 0, 0, r, "4-4cyli.dat"))
	out.append(_ref(0, 0, 0, r, 0, 0, 0, 1, 0, 0, 0, r, "4-4disc.dat"))
	out.append(_ref(0, 0, 0, r, 0, 0, 0, 1, 0, 0, 0, r, "4-4edge.dat"))
	out.append(_ref(0, h, 0, r, 0, 0, 0, 1, 0, 0, 0, r, "4-4edge.dat"))
	out.append(_ref(0, h, 0, inner, 0, 0, 0, 1, 0, 0, 0, inner, "4-4edge.dat"))
	for k: int in 16:
		var a: Array = CIRCLE[k]
		var b: Array = CIRCLE[(k + 1) % 16]
		_face(out, [[r * a[0], h, r * a[1]], [r * b[0], h, r * b[1]],
			[inner * b[0], h, inner * b[1]], [inner * a[0], h, inner * a[1]]],
			[0, 1, 0])
	out.append("0 // Cavity")
	out.append("0 BFC INVERTNEXT")
	out.append(_ref(0, TOP, 0, inner, 0, 0, 0, h - TOP, 0, 0, 0, inner, "4-4cyli.dat"))
	out.append("0 BFC INVERTNEXT")
	out.append(_ref(0, TOP, 0, inner, 0, 0, 0, 1, 0, 0, 0, inner, "4-4disc.dat"))
	out.append(_ref(0, TOP, 0, inner, 0, 0, 0, 1, 0, 0, 0, inner, "4-4edge.dat"))
	if spec.diameter >= 2:
		out.append("0 // Tubes")
		for i: int in range(1, spec.diameter):
			for j: int in range(1, spec.diameter):
				var tx: float = -r + i * STUD
				var tz: float = -r + j * STUD
				if sqrt(tx * tx + tz * tz) + TUBE_RADIUS <= inner:
					out.append(_ref(tx, TOP, tz, 1, 0, 0, 0, -(h - TOP) / 4.0,
						0, 0, 0, 1, "stud4.dat"))


## Studs on a brick's sides: 87087, 47905, 4733 and 30414 at any size.
##
## stud.dat stood on the wall and turned to point out of it, in rows 10
## LDU under the top and every 20 down from there ([method side_rows]), one
## per stud of the top along that side — so a plate held by them lines up
## with the top of the brick and with the studs above, which is what makes
## a sideways face of plates and tiles meet the rest of a model square.
## The library's own draw a hollow stud let into the wall; this one is the
## solid stud on the face, which takes a plate the same way.
static func _side_studs(spec: Spec, out: PackedStringArray) -> void:
	var along: int = maxi(spec.across, spec.deep)
	var over: int = mini(spec.across, spec.deep)
	var x: float = along * STUD * 0.5
	var z: float = over * STUD * 0.5
	out.append("0 // Studs on the sides")
	for y: float in side_rows(spec):
		if spec.sides.contains("f"):
			for i: int in along:
				out.append(_ref(-x + STUD * 0.5 + i * STUD, y, -z,
					1, 0, 0, 0, 0, -1, 0, 1, 0, "stud.dat"))
		if spec.sides.contains("b"):
			for i: int in along:
				out.append(_ref(-x + STUD * 0.5 + i * STUD, y, z,
					1, 0, 0, 0, 0, 1, 0, -1, 0, "stud.dat"))
		if spec.sides.contains("l"):
			for j: int in over:
				out.append(_ref(-x, y, -z + STUD * 0.5 + j * STUD,
					0, 1, 0, -1, 0, 0, 0, 0, 1, "stud.dat"))
		if spec.sides.contains("r"):
			for j: int in over:
				out.append(_ref(x, y, -z + STUD * 0.5 + j * STUD,
					0, -1, 0, 1, 0, 0, 0, 0, 1, "stud.dat"))


## A bracket: 99781, 99780 and 44728 at any size. A plate with an upright
## on its front edge whose studs point forward, which is how a model turns
## a face of studs to the side.
##
## Measured off the library's: the upright is 4 LDU thick and stands just
## in front of the plate's footprint, so the plate's own studs stay on the
## grid and the origin stays on their middle, as 99781's does; its studs are
## 10 LDU from the plate's top (hanging down) or its bottom (standing up),
## then every 20, so a plate held by them meets the bracket's plate square.
static func _bracket(spec: Spec, out: PackedStringArray) -> void:
	var x: float = spec.across * STUD * 0.5
	var d: float = spec.deep * STUD * 0.5
	var zf: float = -d - WALL                 ## the upright's face
	var p: float = PLATE
	var r: float = spec.rise * STUD
	var down: bool = spec.way == "down"
	var low: float = r if down else p         ## the upright's bottom
	var high: float = 0.0 if down else p - r  ## and its top
	if spec.studs:
		_studs_on_top(out, spec.across, spec.deep, 0.0, 0.0, 0.0)
	out.append("0 // Plate and upright")
	# The top: the plate's, and with the upright hanging down, the
	# upright's top edge with it.
	_face(out, [[x, 0, d], [-x, 0, d], [-x, 0, zf if down else -d],
		[x, 0, zf if down else -d]], [0, -1, 0])
	if not down:
		_face(out, [[x, high, -d], [-x, high, -d], [-x, high, zf], [x, high, zf]],
			[0, -1, 0])
		_face(out, [[x, high, -d], [x, 0, -d], [-x, 0, -d], [-x, high, -d]], [0, 0, 1])
	else:
		_face(out, [[x, low, zf], [-x, low, zf], [-x, low, -d], [x, low, -d]],
			[0, 1, 0])
		_face(out, [[x, p, -d], [x, low, -d], [-x, low, -d], [-x, p, -d]], [0, 0, 1])
	_face(out, [[x, high, zf], [-x, high, zf], [-x, low, zf], [x, low, zf]], [0, 0, -1])
	_face(out, [[x, 0, d], [x, p, d], [-x, p, d], [-x, 0, d]], [0, 0, 1])
	for side: float in [x, -x]:
		var way: float = signf(side)
		_face(out, [[side, 0, -d], [side, 0, d], [side, p, d], [side, p, -d]], [way, 0, 0])
		_face(out, [[side, high, zf], [side, high, -d], [side, low, -d], [side, low, zf]],
			[way, 0, 0])
	# The underside: a ring round the cavity, which has the upright for its
	# front wall.
	var ix: float = x - WALL
	if down:
		_face(out, [[x, p, d], [-x, p, d], [-ix, p, d - WALL], [ix, p, d - WALL]], [0, 1, 0])
		for side: float in [x, -x]:
			var inner: float = side - signf(side) * WALL
			_face(out, [[side, p, d], [inner, p, d - WALL], [inner, p, -d], [side, p, -d]],
				[0, 1, 0])
	else:
		_rim(out, p, -x, x, zf, d, -ix, ix, -d, d - WALL)
	_outline(out, [[x, 0, d], [-x, 0, d], [-x, 0, zf if down else -d],
		[x, 0, zf if down else -d]])
	_outline(out, [[x, high, zf], [-x, high, zf], [-x, low, zf], [x, low, zf]])
	_line(out, [x, p, d], [-x, p, d])
	_line(out, [x, low, -d], [-x, low, -d])
	if not down:
		_line(out, [x, high, -d], [-x, high, -d])
	for side: float in [x, -x]:
		_line(out, [side, 0, d], [side, p, d])
		_line(out, [side, p, d], [side, p, -d])
		_line(out, [side, high, -d], [side, low, -d])
		_line(out, [side, p if down else 0.0, -d], [side, low if down else high, -d])
	_cavity(out, p, ix, d - WALL * 0.5, -WALL * 0.5)
	_underside(out, spec.across, spec.deep, 0.0, 0.0, p,
		func(_at: float) -> float: return TOP)
	out.append("0 // Studs on the upright")
	for k: int in spec.rise:
		var y: float = (STUD * 0.5 + k * STUD) if down else (p - STUD * 0.5 - k * STUD)
		for i: int in spec.across:
			out.append(_ref(-x + STUD * 0.5 + i * STUD, y, zf,
				1, 0, 0, 0, 0, -1, 0, 1, 0, "stud.dat"))


## A curved slope's face, as points (z, y) from the top of the curve at
## the back to its foot at the front: an eighth of a circle drawn in the
## part's own proportions, as 11477 draws its 1-8cyli — level where it
## leaves the flat rows, and at its steepest where it meets the 4 LDU lip.
##
## In terms of how far along the curve a point is, u (0 at the top, 1 at
## the foot), the face is foot * (2 + sqrt 2) * (1 - sqrt(1 - u^2 / 2))
## under the top, which is the circle x^2 + y^2 = 1 seen through the
## part's own scale. [param steps] points are spaced evenly round it.
static func curve_profile(spec: Spec, steps: int = CURVE_STEPS) -> Array:
	var back: float = spec.deep * STUD * 0.5
	var front: float = -back
	var edge: float = back - (spec.deep - spec.run) * STUD
	var foot: float = spec.plates * PLATE - LIP
	var rise: float = foot / (sqrt(2.0) - 1.0)
	var points: Array = []
	for k: int in steps + 1:
		var theta: float = deg_to_rad(45.0) * (1.0 - float(k) / steps)
		var z: float = edge + (edge - front) * (sin(theta) - cos(theta))
		var y: float = rise * (sqrt(2.0) - cos(theta) - sin(theta))
		if k == 0:
			z = edge
			y = 0.0
		elif k == steps:
			z = front
			y = foot
		points.append([z, y])
	return points


## Where a curved slope's face is under its top at [param z], in LDU: 0
## on the flat rows, the curve of [method curve_profile] over the rest.
static func curve_at(spec: Spec, z: float) -> float:
	var back: float = spec.deep * STUD * 0.5
	var front: float = -back
	var edge: float = back - (spec.deep - spec.run) * STUD
	if z >= edge:
		return 0.0
	var u: float = clampf((edge - z) / (edge - front), 0.0, 1.0)
	return (spec.plates * PLATE - LIP) * (2.0 + sqrt(2.0)) * (1.0 - sqrt(1.0 - u * u * 0.5))


## A curved slope: 11477, 15068, 50950 and 93606 at any width, depth,
## height and length of curve, with flat studded rows behind it when the
## curve does not take the whole depth.
##
## The face is drawn in [constant CURVE_STEPS] strips so that it shades as
## one curve; only its edges are lines. The cavity's ceiling follows the
## face four LDU under it, as a slope's does, and the tubes start on it.
static func _curved(spec: Spec, out: PackedStringArray) -> void:
	var x: float = spec.across * STUD * 0.5
	var back: float = spec.deep * STUD * 0.5
	var front: float = -back
	var flat: int = spec.deep - spec.run
	var edge: float = back - flat * STUD
	var h: float = spec.plates * PLATE
	var foot: float = h - LIP
	var profile: Array = curve_profile(spec)
	# The whole top, back to front: the flat rows, then the curve.
	var top: Array = []
	if flat > 0:
		top.append([back, 0.0])
	top.append_array(profile)

	if spec.studs and flat > 0:
		_studs_on_top(out, spec.across, flat, 0.0, 0.0, back - flat * STUD * 0.5)
	out.append("0 // Top, curve, lip and back")
	for n: int in top.size() - 1:
		var a: Array = top[n]
		var b: Array = top[n + 1]
		var dz: float = float(b[0]) - float(a[0])
		var dy: float = float(b[1]) - float(a[1])
		_face(out, [[x, a[1], a[0]], [-x, a[1], a[0]], [-x, b[1], b[0]], [x, b[1], b[0]]],
			[0, dz, -dy])
	_face(out, [[x, foot, front], [-x, foot, front], [-x, h, front], [x, h, front]],
		[0, 0, -1])
	_face(out, [[x, 0, back], [x, h, back], [-x, h, back], [-x, 0, back]], [0, 0, 1])
	for side: float in [x, -x]:
		var way: float = signf(side)
		for n: int in top.size() - 1:
			var a: Array = top[n]
			var b: Array = top[n + 1]
			_face(out, [[side, a[1], a[0]], [side, b[1], b[0]], [side, h, b[0]],
				[side, h, a[0]]], [way, 0, 0])
	if flat > 0:
		_outline(out, [[x, 0, back], [-x, 0, back], [-x, 0, edge], [x, 0, edge]])
	else:
		_line(out, [x, 0, back], [-x, 0, back])
	_line(out, [x, foot, front], [-x, foot, front])
	_line(out, [x, h, front], [-x, h, front])
	_line(out, [x, h, back], [-x, h, back])
	for side: float in [x, -x]:
		_line(out, [side, 0, back], [side, h, back])
		_line(out, [side, foot, front], [side, h, front])
		_line(out, [side, h, back], [side, h, front])
		for n: int in profile.size() - 1:
			var a: Array = profile[n]
			var b: Array = profile[n + 1]
			_line(out, [side, a[1], a[0]], [side, b[1], b[0]])

	# The cavity, its ceiling four LDU under the top all the way along.
	var ix: float = x - WALL
	var ib: float = back - WALL
	var iff: float = front + WALL
	var ceiling: Callable = func(at: float) -> float:
		return TOP + curve_at(spec, at)
	var inside: Array = [[ib, ceiling.call(ib)]]
	for point: Array in top:
		if float(point[0]) < ib and float(point[0]) > iff:
			inside.append([point[0], TOP + float(point[1])])
	inside.append([iff, ceiling.call(iff)])
	out.append("0 // Cavity")
	_rim(out, h, -x, x, front, back, -ix, ix, iff, ib)
	for n: int in inside.size() - 1:
		var a: Array = inside[n]
		var b: Array = inside[n + 1]
		var dz: float = float(b[0]) - float(a[0])
		var dy: float = float(b[1]) - float(a[1])
		_face(out, [[ix, a[1], a[0]], [-ix, a[1], a[0]], [-ix, b[1], b[0]], [ix, b[1], b[0]]],
			[0, -dz, dy])
	var first: Array = inside[0]
	var last: Array = inside[inside.size() - 1]
	_face(out, [[ix, first[1], ib], [ix, h, ib], [-ix, h, ib], [-ix, first[1], ib]],
		[0, 0, -1])
	_face(out, [[ix, last[1], iff], [-ix, last[1], iff], [-ix, h, iff], [ix, h, iff]],
		[0, 0, 1])
	for side: float in [ix, -ix]:
		var inward: float = -signf(side)
		for n: int in inside.size() - 1:
			var a: Array = inside[n]
			var b: Array = inside[n + 1]
			_face(out, [[side, a[1], a[0]], [side, b[1], b[0]], [side, h, b[0]],
				[side, h, a[0]]], [inward, 0, 0])
	_line(out, [ix, first[1], ib], [-ix, first[1], ib])
	_line(out, [ix, last[1], iff], [-ix, last[1], iff])
	for side: float in [ix, -ix]:
		_line(out, [side, first[1], ib], [side, h, ib])
		_line(out, [side, last[1], iff], [side, h, iff])
	_underside(out, spec.across, spec.deep, 0.0, 0.0, h, ceiling)


## A Technic brick: 3700, 3701 and the rest of the 1 x N bricks with holes,
## at any length. A hole between every two studs (one under the stud of a
## 1 x 1, as 6541's), each a 12 LDU bore with a 16 LDU mouth counterbored
## into both faces — peghole.dat, as the library draws every pin hole — so
## a Technic pin goes through it.
##
## The library's bricks are hollow round each hole; this one is solid from
## the top to 18 LDU down, under the holes, and hollow below that for the
## studs of the part it stands on, with a pin under each hole as 3700 has.
## The same outside, the same holes and the same clutch, and nothing for a
## part to be pushed into.
static func _technic(spec: Spec, out: PackedStringArray) -> void:
	var n: int = spec.across
	var x: float = n * STUD * 0.5
	var z: float = STUD * 0.5
	var h: float = 3 * PLATE
	var holes: Array[float] = holes_of(spec)
	if spec.studs:
		_studs_on_top(out, n, 1, 0.0, 0.0, 0.0)
	out.append("0 // Top and ends")
	_face(out, [[x, 0, z], [-x, 0, z], [-x, 0, -z], [x, 0, -z]], [0, -1, 0])
	for side: float in [x, -x]:
		_face(out, [[side, 0, -z], [side, 0, z], [side, h, z], [side, h, -z]],
			[signf(side), 0, 0])
	_outline(out, [[x, 0, z], [-x, 0, z], [-x, 0, -z], [x, 0, -z]])
	for side: float in [x, -x]:
		_line(out, [side, 0, -z], [side, h, -z])
		_line(out, [side, 0, z], [side, h, z])
	out.append("0 // Faces, with a mouth for every hole")
	var top_of_mouth: float = HOLE_Y - MOUTH
	var foot_of_mouth: float = HOLE_Y + MOUTH
	for face_z: float in [-z, z]:
		var out_way: float = signf(face_z)
		_face(out, [[x, 0, face_z], [-x, 0, face_z], [-x, top_of_mouth, face_z],
			[x, top_of_mouth, face_z]], [0, 0, out_way])
		_face(out, [[x, foot_of_mouth, face_z], [-x, foot_of_mouth, face_z],
			[-x, h, face_z], [x, h, face_z]], [0, 0, out_way])
		var from: float = -x
		for c: float in holes:
			if c - MOUTH > from:
				_face(out, [[from, top_of_mouth, face_z], [c - MOUTH, top_of_mouth, face_z],
					[c - MOUTH, foot_of_mouth, face_z], [from, foot_of_mouth, face_z]],
					[0, 0, out_way])
			from = c + MOUTH
		if x > from:
			_face(out, [[from, top_of_mouth, face_z], [x, top_of_mouth, face_z],
				[x, foot_of_mouth, face_z], [from, foot_of_mouth, face_z]], [0, 0, out_way])
		_line(out, [x, h, face_z], [-x, h, face_z])
	for c: float in holes:
		# The square round each mouth, less the mouth: 4-4ndis, facing out
		# of the face. Then peghole.dat, which counterbores the mouth two
		# LDU in, and a bore through between the two.
		out.append(_ref(c, HOLE_Y, -z, MOUTH, 0, 0, 0, 0, -MOUTH, 0, 1, 0, "4-4ndis.dat"))
		out.append(_ref(c, HOLE_Y, z, MOUTH, 0, 0, 0, 0, MOUTH, 0, -1, 0, "4-4ndis.dat"))
		# The back one first, as 3700 has them: the merged hole takes the
		# axis of the face it sorts first by, and so has 3700's.
		out.append(_ref(c, HOLE_Y, z, 1, 0, 0, 0, 0, 1, 0, -1, 0, "peghole.dat"))
		out.append(_ref(c, HOLE_Y, -z, 1, 0, 0, 0, 0, -1, 0, 1, 0, "peghole.dat"))
		out.append("0 BFC INVERTNEXT")
		out.append(_ref(c, HOLE_Y, -z + 2.0, BORE, 0, 0, 0, 0, -BORE, 0, 2.0 * (z - 2.0), 0,
			"4-4cyli.dat"))
	out.append("0 // Underneath: a cavity for studs, and a pin under each hole")
	_rim(out, h, -x, x, -z, z, -x + WALL, x - WALL, -z + WALL, z - WALL)
	out.append("0 BFC INVERTNEXT")
	out.append(_ref(0, h, 0, x - WALL, 0, 0, 0, -(h - HOLE_FLOOR), 0, 0, 0, z - WALL,
		"box5.dat"))
	if n >= 2:
		for c: float in holes:
			out.append(_ref(c, HOLE_FLOOR, 0, 1, 0, 0, 0, -(h - HOLE_FLOOR) / 4.0, 0,
				0, 0, 1, "stud3.dat"))


## Where a Technic brick's holes are along it, in LDU from its middle: one
## between every two studs, or the one under a 1 x 1's stud.
static func holes_of(spec: Spec) -> Array[float]:
	var holes: Array[float] = []
	var x: float = spec.across * STUD * 0.5
	if spec.across == 1:
		holes.append(0.0)
	else:
		for i: int in range(1, spec.across):
			holes.append(-x + i * STUD)
	return holes


## The sixteen points LDraw's round primitives are drawn on, as written in
## p/4-4cyli.dat, x then z.
const CIRCLE: Array = [
	[1.0, 0.0], [0.9239, 0.3827], [0.7071, 0.7071], [0.3827, 0.9239],
	[0.0, 1.0], [-0.3827, 0.9239], [-0.7071, 0.7071], [-0.9239, 0.3827],
	[-1.0, 0.0], [-0.9239, -0.3827], [-0.7071, -0.7071], [-0.3827, -0.9239],
	[0.0, -1.0], [0.3827, -0.9239], [0.7071, -0.7071], [0.9239, -0.3827],
]


# -- shared pieces ------------------------------------------------------------


## A grid of studs on the top at y, centred at (cx, cz).
static func _studs_on_top(out: PackedStringArray, along: int, over: int, y: float,
		cx: float, cz: float) -> void:
	out.append("0 // Studs")
	for i: int in along:
		for j: int in over:
			var sx: float = cx - along * STUD * 0.5 + STUD * 0.5 + i * STUD
			var sz: float = cz - over * STUD * 0.5 + STUD * 0.5 + j * STUD
			out.append(_ref(sx, y, sz, 1, 0, 0, 0, 1, 0, 0, 0, 1, "stud.dat"))


## The inside of the part: an inverted box5 from the ceiling to the bottom,
## exactly as s/3001s01 draws it.
static func _cavity(out: PackedStringArray, h: float, ix: float, iz: float,
		cz: float) -> void:
	out.append("0 // Cavity")
	out.append("0 BFC INVERTNEXT")
	out.append(_ref(0, h, cz, ix, 0, 0, 0, -(h - TOP), 0, 0, 0, iz, "box5.dat"))


## What grips a stud from below, for a footprint of [param along] studs on
## X by [param over] on Z centred at (cx, cz): tubes between every four
## studs, or pins between every two on a part one stud wide. Each runs
## from the ceiling — [param ceiling] says where that is, by Z, on the
## side nearer the front — to the bottom, and one with less than four LDU
## to run is left out.
static func _underside(out: PackedStringArray, along: int, over: int, cx: float,
		cz: float, h: float, ceiling: Callable) -> void:
	var places: Array = []
	var x0: float = cx - along * STUD * 0.5
	var z0: float = cz - over * STUD * 0.5
	if along >= 2 and over >= 2:
		for i: int in range(1, along):
			for j: int in range(1, over):
				places.append([x0 + i * STUD, z0 + j * STUD, "stud4.dat", TUBE_RADIUS])
	elif over == 1 and along >= 2:
		for i: int in range(1, along):
			places.append([x0 + i * STUD, cz, "stud3.dat", PIN_RADIUS])
	elif along == 1 and over >= 2:
		for j: int in range(1, over):
			places.append([cx, z0 + j * STUD, "stud3.dat", PIN_RADIUS])
	if places.is_empty():
		return
	out.append("0 // Underside")
	for place: Array in places:
		var top: float = ceiling.call(float(place[1]) - float(place[3]))
		if h - top < 4.0:
			continue
		out.append(_ref(float(place[0]), top, float(place[1]), 1, 0, 0, 0,
			-(h - top) / 4.0, 0, 0, 0, 1, str(place[2])))


## The flat ring along the bottom between an outer rectangle and an inner
## one, facing down — the four quads that close every brick in the library.
static func _rim(out: PackedStringArray, y: float, ox0: float, ox1: float, oz0: float,
		oz1: float, ix0: float, ix1: float, iz0: float, iz1: float) -> void:
	_face(out, [[ox1, y, oz1], [ix1, y, iz1], [ix0, y, iz1], [ox0, y, oz1]], [0, 1, 0])
	_face(out, [[ox0, y, oz1], [ix0, y, iz1], [ix0, y, iz0], [ox0, y, oz0]], [0, 1, 0])
	_face(out, [[ox0, y, oz0], [ix0, y, iz0], [ix1, y, iz0], [ox1, y, oz0]], [0, 1, 0])
	_face(out, [[ox1, y, oz0], [ix1, y, iz0], [ix1, y, iz1], [ox1, y, oz1]], [0, 1, 0])


## A polygon wound so that it faces [param outward], which is what BFC
## CERTIFY CCW asks for: the cross product of its first two edges points
## out of the plastic. Winding every face by hand is how a part ends up
## with one face drawn inside out; this cannot.
static func _face(out: PackedStringArray, points: Array, outward: Array) -> void:
	var a: Array = points[0]
	var b: Array = points[1]
	var c: Array = points[2]
	var ux: float = float(b[0]) - float(a[0])
	var uy: float = float(b[1]) - float(a[1])
	var uz: float = float(b[2]) - float(a[2])
	var vx: float = float(c[0]) - float(a[0])
	var vy: float = float(c[1]) - float(a[1])
	var vz: float = float(c[2]) - float(a[2])
	var nx: float = uy * vz - uz * vy
	var ny: float = uz * vx - ux * vz
	var nz: float = ux * vy - uy * vx
	var ordered: Array = points
	if nx * float(outward[0]) + ny * float(outward[1]) + nz * float(outward[2]) < 0.0:
		ordered = points.duplicate()
		ordered.reverse()
	var line: String = "4 16" if ordered.size() == 4 else "3 16"
	for p: Array in ordered:
		line += " %s %s %s" % [_n(float(p[0])), _n(float(p[1])), _n(float(p[2]))]
	out.append(line)


## A closed loop of edge lines, for the creases the shading keeps sharp.
static func _outline(out: PackedStringArray, points: Array) -> void:
	for n: int in points.size():
		_line(out, points[n], points[(n + 1) % points.size()])


static func _line(out: PackedStringArray, a: Array, b: Array) -> void:
	out.append("2 24 %s %s %s %s %s %s" % [_n(float(a[0])), _n(float(a[1])),
		_n(float(a[2])), _n(float(b[0])), _n(float(b[1])), _n(float(b[2]))])


static func _ref(x: float, y: float, z: float, a: float, b: float, c: float,
		d: float, e: float, f: float, g: float, h: float, i: float,
		file: String) -> String:
	return "1 16 %s %s %s %s %s %s %s %s %s %s %s %s %s" % [_n(x), _n(y), _n(z),
		_n(a), _n(b), _n(c), _n(d), _n(e), _n(f), _n(g), _n(h), _n(i), file]


## A number as LDraw writes one: no trailing zeros, no "-0", and four
## places at most, which is a twenty-fifth of a micron.
static func _n(value: float) -> String:
	var rounded: float = snappedf(value, 0.0001)
	if absf(rounded - roundf(rounded)) < 0.00005:
		var whole: int = int(roundf(rounded))
		return str(whole)
	var text: String = String.num(rounded, 4)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return "0" if text == "-0" else text
