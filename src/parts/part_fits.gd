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


## Put [param part_id], in [param colour], on a free connector of one of the
## bricks [param on] (the selection), as Bricksmith's Insert Related adds the
## tyre a wheel takes: a double-click on a tile of Fits (PartsBin). By what
## Connect puts a part on by (JointSnap): the first of their connectors one of
## the part's ends goes on, nearest [param eye] first, by the first way on it
## from that side that has room; then a part that sits on studs on the first
## stud it has room on, and one that takes studs under the first tube
## (Attach). A connector with a part in it already has no room. One step to
## undo. {brick, words}: the brick put down, 0 for none, and in words what was
## done or why nothing was.
static func put_on(builder: Builder, library: PartLibrary, on: PackedInt64Array,
		part_id: String, colour: int, eye: Vector3) -> Dictionary:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	var named: String = Inventory._tidy(info.name) if info != null else part_id
	if library.mesh_for(part_id) == null:
		return {"brick": 0, "words": "%s is not here yet" % named}
	var bricks: Array[BrickWorld.Brick] = []
	for brick_id: int in on:
		var brick: BrickWorld.Brick = builder.world.get_brick(brick_id)
		if brick != null and library.mesh_for(brick.part_id) != null:
			bricks.append(brick)
	if bricks.is_empty():
		return {"brick": 0, "words": "select the part it goes on first"}
	builder.below = 0.0

	var held: Array = JointSnap.ends_for(library, part_id)
	var sites: Array = []
	for brick: BrickWorld.Brick in bricks:
		for end: JointSnap.End in JointSnap.ends_for(library, brick.part_id):
			sites.append(end.placed(brick.transform, brick.id))
	sites.sort_custom(func(a: JointSnap.End, b: JointSnap.End) -> bool:
		return a.middle().distance_squared_to(eye) < b.middle().distance_squared_to(eye))
	var mated: int = 0
	for site: JointSnap.End in sites:
		var way: Vector3 = (site.middle() - eye).normalized()
		for choice: Array in JointSnap.choices(held, site, eye, way):
			mated += 1
			var at: Transform3D = JointSnap.pose(choice[0], site, int(choice[1]), float(choice[2]),
				0.0, Basis.IDENTITY)
			if not builder.room_for(part_id, at, true, true):
				continue
			var made: int = _put(builder, part_id, colour, at, site.brick)
			if made != 0:
				var under: BrickWorld.Brick = builder.world.get_brick(site.brick)
				var theirs: PartLibrary.PartInfo = library.parts.get(under.part_id)
				return {"brick": made, "words": "put %s on %s" % [named, JointSnap.describe(site,
					Inventory._tidy(theirs.name) if theirs != null else under.part_id)]}

	# On studs, or under them: a 1 x 1 round plate on a jumper's.
	var mine: Array = Attach.points_of(library, part_id)
	for wanted: Array in [[Exact.STUD, Exact.HOLE, "on the studs of"],
			[Exact.HOLE, Exact.STUD, "under"]]:
		var targets: Array = []     ## [how far from the eye, brick, its point]
		for brick: BrickWorld.Brick in bricks:
			for point: Attach.Point in Attach.points_of(library, brick.part_id):
				if point.kind == int(wanted[0]):
					targets.append([((brick.transform * point.frame).origin).distance_squared_to(eye),
						brick, point])
		targets.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for target: Array in targets:
			var brick: BrickWorld.Brick = target[1]
			for point: Attach.Point in mine:
				if point.kind != int(wanted[1]) or not Attach.compatible(target[2], point):
					continue
				mated += 1
				var posed: Dictionary = Attach.pose(brick.transform, target[2], point)
				if not posed.has("at") or not builder.room_for(part_id, posed["at"], true, true):
					continue
				var made: int = _put(builder, part_id, colour, posed["at"], brick.id)
				if made != 0:
					var theirs: PartLibrary.PartInfo = library.parts.get(brick.part_id)
					return {"brick": made, "words": "put %s %s %s" % [named, wanted[2],
						Inventory._tidy(theirs.name) if theirs != null else brick.part_id]}
	if mated == 0:
		return {"brick": 0, "words": "%s has nothing that goes on what is selected" % named}
	return {"brick": 0, "words": "no room for %s on what is selected: every place it goes on is taken"
		% named}


## Down at [param at] as one step, in the sub-assembly of the brick
## [param by] it goes on and in the step a part put down by hand goes in.
static func _put(builder: Builder, part_id: String, colour: int, at: Transform3D,
		by: int) -> int:
	var made: int = builder.put_part(part_id, colour, at)
	if made == 0:
		return 0
	var brick: BrickWorld.Brick = builder.world.get_brick(made)
	var beside: BrickWorld.Brick = builder.world.get_brick(by)
	if beside != null:
		builder.set_path(brick, Assemblies.path_of(beside))
	brick.step = int(builder.place_step.call(Assemblies.path_of(brick))) \
		if builder.place_step.is_valid() else -1
	return made


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
