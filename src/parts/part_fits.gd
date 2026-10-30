## The parts that fit a part: what goes in its holes, in its clip, on its
## bar, on its studs (appux371 B5, 2026-10-30).
##
## Nothing in the parts bin answered "what goes on this?": a person who knew
## that a beam takes a pin found one by its name, and one who did not, did
## not. Studio has "Find compatible bricks". This reads what the catalogue
## says of each part, the kinds of connector it has, and lists the parts
## whose connectors take the selected part's, the kind made for it first
## (a pin for a pin hole, a bar for a clip, the top of a hinge for its base),
## then the parts that sit on its studs and fit on them whole (a 1 x 1 round
## plate on a jumper), then what it sits on. Within each, the parts real sets
## use most come first.
##
## From the catalogue alone, so it answers on the web before any part's
## geometry is fetched. A bar is known by its name: the catalogue counts a
## part's rounds, not how wide each is, and a bar is a round a clip takes.
class_name PartFits
extends RefCounted

## What each kind of end takes, and how well: 2 made for it, a pin in a pin
## hole, a bar in a clip; 1 one that goes in and turns loose, an axle in a
## pin hole (JointSnap.TAKES, with the clip, the bar and the click hinge's
## fingers, which it snaps by their rounds).
const TAKES: Dictionary = {
	"pin_hole": {"pin": 2, "axle": 1},
	"pin": {"pin_hole": 2},
	"axle": {"axle_hole": 2, "pin_hole": 1},
	"axle_hole": {"axle": 2},
	"clip": {"bar": 2},
	"bar": {"clip": 2},
	"finger": {"fork": 2},
	"fork": {"finger": 2},
	"ball": {"socket": 2},
	"socket": {"ball": 2},
}

## How a part fits, best first: the other half of the same part (a hinge's
## top for its base), a connector made for one of its own, one that goes in
## loose, on its studs, and under it.
const OTHER_HALF := 5
const MADE_FOR := 4
const GOES_IN := 3
const ON_ITS_STUDS := 2
const UNDER_IT := 1

## The families whose underside takes studs, as a plate's does.
const ON_STUDS: Array[String] = ["Brick", "Plate", "Tile", "Slope", "Wedge", "Bracket", "Arch",
	"Panel", "Cone", "Dish", "Cylinder", "Wing", "Hinge", "Window", "Door", "Fence", "Windscreen",
	"Container", "Turntable"]
## Kept out: what nobody fits to anything they build.
const LEFT_OUT: Array[String] = ["Sticker", "Sticker Shortcut", "Obsolete", "Moved", "Helper"]
## The two halves of a part LDraw numbers apart.
const HALVES: Dictionary = {"base": "top", "top": "base"}

static var WORD := RegEx.create_from_string("[a-z]+")


## The kinds of end [param info] has that a part fits to, as a set: its
## catalogue's connectors, a clip by its name where the catalogue counts only
## its round (15712, Tile 1 x 1 with Clip), a bar or a handle by its name,
## its studs, and an underside that takes studs.
static func kinds_of(info: PartLibrary.PartInfo) -> Dictionary:
	var kinds: Dictionary = {}
	for kind: String in TAKES:
		if int(info.connector_counts.get(kind, 0)) > 0:
			kinds[kind] = true
	# Its words read only where they may say clip, bar or handle: this is
	# asked of every part in the catalogue.
	var lowered: String = info.name.to_lower()
	var words: Dictionary = {}
	if lowered.contains("clip") or lowered.contains("bar") or lowered.contains("handle"):
		for found: RegExMatch in WORD.search_all(lowered):
			words[found.get_string()] = true
	var rounds: bool = int(info.connector_counts.get("bore", 0)) > 0
	if rounds and (words.has("clip") or words.has("clips")):
		kinds["clip"] = true
	if info.category == "Bar" or words.has("bar") or words.has("handle") \
			or words.has("handles"):
		kinds["bar"] = true
	if info.stud_count > 0:
		kinds["stud"] = true
	if info.family_category() in ON_STUDS or int(info.connector_counts.get("tube", 0)) > 0:
		kinds["underside"] = true
	return kinds


## The parts that fit [param subjects] (part numbers), best first, at most
## [param most]: each by the best way it fits any of them, then by how much
## sets use it.
static func for_parts(library: PartLibrary, subjects: PackedStringArray,
		most: int = 300) -> Array[PartLibrary.PartInfo]:
	var offered: Dictionary = {}       ## kind -> how well a part with it fits
	var studs := Vector2i.ZERO         ## the largest top a part may sit on whole
	var stud_count: int = 0
	var halves: Dictionary = {}        ## another half's name -> true
	var takes_studs: bool = false
	for id: String in subjects:
		var info: PartLibrary.PartInfo = library.parts.get(id)
		if info == null:
			continue
		var kinds: Dictionary = kinds_of(info)
		for kind: String in kinds:
			for other: String in TAKES.get(kind, {}):
				var how: int = MADE_FOR if int(TAKES[kind][other]) == 2 else GOES_IN
				offered[other] = maxi(int(offered.get(other, 0)), how)
		if kinds.has("stud"):
			var own: Vector2i = info.footprint_studs()
			studs = Vector2i(maxi(studs.x, mini(own.x, own.y)), maxi(studs.y, maxi(own.x, own.y)))
			stud_count = maxi(stud_count, info.stud_count)
		takes_studs = takes_studs or kinds.has("underside")
		var half: String = _other_half(info.name)
		if not half.is_empty():
			halves[half] = true
	var ranked: Array = []      ## [how, commonness, area, id, info]
	for id: String in library.ids():
		var info: PartLibrary.PartInfo = library.parts[id]
		if not _offerable(library, info):
			continue
		var how: int = 0
		if not halves.is_empty() and halves.has(Inventory._tidy(info.name).to_lower()):
			how = OTHER_HALF
		var kinds: Dictionary = kinds_of(info)
		for kind: String in kinds:
			how = maxi(how, int(offered.get(kind, 0)))
		var footprint: Vector2i = info.footprint_studs()
		var low: int = mini(footprint.x, footprint.y)
		var high: int = maxi(footprint.x, footprint.y)
		if how < ON_ITS_STUDS and stud_count > 0 and kinds.has("underside") \
				and low <= studs.x and high <= studs.y and low * high <= stud_count:
			how = ON_ITS_STUDS
		if how < UNDER_IT and takes_studs and kinds.has("stud"):
			how = UNDER_IT
		if how > 0:
			ranked.append([how, info.commonness(), low * high, id, info])
	ranked.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] > b[0]
		if not is_equal_approx(a[1], b[1]):
			return a[1] > b[1]
		if a[2] != b[2]:
			return a[2] < b[2]
		return str(a[3]).naturalnocasecmp_to(str(b[3])) < 0)
	var out: Array[PartLibrary.PartInfo] = []
	for row: Array in ranked:
		if out.size() >= most:
			break
		out.append(row[4])
	return out


## The name of a part's other half, lowercase, where LDraw numbers the two
## halves of one part apart: "Hinge 1 x 2 Top" for "Hinge 1 x 2 Base".
static func _other_half(name: String) -> String:
	var words: PackedStringArray = Inventory._tidy(name).to_lower().split(" ", false)
	for n: int in words.size():
		if HALVES.has(words[n]):
			words[n] = HALVES[words[n]]
			return " ".join(words)
	return ""


## Whether a part is one to offer: plain, placeable in this build, made now
## where LDraw keeps an older number, and of the parts people build with.
static func _offerable(library: PartLibrary, info: PartLibrary.PartInfo) -> bool:
	if info.is_redirect() or not info.reachable or info.decor() != 0 \
			or info.name.begins_with("=") or info.name.begins_with("~") \
			or info.category in LEFT_OUT or PartSearch._other_line(info):
		return false
	return not library.superseded(info.id)
