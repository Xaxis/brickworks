## The surface pass, driven by the app: it reads the model exactly — its open
## studs, the way they step, the plain walls — finds what a real set would have
## finished, lays the real pieces for each as a proposal, and hands the design
## one picture of them standing on the model, to settle each: accept it
## (adjusted if need be), reject it with a reason, or keep the studs where they
## are the point.
##
## Why the app does it rather than the rules asking. The bench scored surface
## and technique lowest (3.5-3.8 of 10) through six rounds of prompt and process
## changes, and the judge said the same every round: "a roof of exposed studs",
## "mostly plain bricks stacked studs-up", "stud staircases". Shapes tile their
## own tops; the studs a session builds by hand were never covered. The one
## change that moved a dimension was the creative pass (creativity 3.0 to 5.2),
## and it worked because the app handed the design a turn of its own with
## something concrete in it. A roof already tiled, seen in a picture, is a
## different question from "surfaces meant to be smooth are tiled".
##
## What it finds:
##   studs      an open stud field on what is not built on — a roof, a body, a
##              hood, a wing, the top of a wall — tiled in its own colour,
##              largest real sizes first, with a textured tile or two (grille,
##              ingot, jumper) where a set would vary a big one;
##   staircase  studs stepping up a plate to a brick at a time over one to
##              three studs, two steps or more: a slope or curved slope laid on
##              each tread, rising to the next, or the step brick itself laid
##              again as a 45 degree slope where the tread is one stud deep;
##   wall       a long plain wall of one-wide bricks, one colour: laid again
##              by restyle_model's own pass, some as masonry, some turned out.
##
## How it decides what is meant to be built on, in the order it asks:
##   - only a stud with nothing on it and nothing of the model above it is
##     open (standing_free): a stud something stands on, or that a roof
##     covers, is not finished; and each lay is checked again first, since a
##     finding laid before it, or the design, may now stand there;
##   - only studs of bricks, plates, slopes, wedges, wings and baseplates are
##     read: a round plate's, a jumper's, a figure's or a plant's stud is the
##     detail itself; and a stud whose square is not all part (a wedge's
##     corner) is left, since a tile there would overhang;
##   - a Brick Art mosaic is all studs on purpose: nothing is proposed;
##   - a field a figure, an animal or a plant stands among is a yard;
##   - the ground (a plate or two up from the model's bottom, spanning most
##     of it: a base) is a floor things will stand on, the creative pass's
##     figures among them: it is offered (G1), laid only when the design says
##     "tile";
##   - fewer than four studs together are a detail, not a field;
##   - and wherever the design said "keep", or rejected the app's pieces, is
##     never proposed again for this design.
class_name SurfacePass
extends RefCounted

const STUD := 20.0
const PLATE := 8.0
## Turns the app's own loop gives the pass.
const TURNS := 4
## Findings laid at once; the rest are said and come with the next review.
const MOST_FINDINGS := 12
const MOST_STAIRCASES := 4
const MOST_WALLS := 3
const SMALLEST_FIELD := 4
## A tread deeper than this is a floor, not a step.
const DEEPEST_TREAD := 3
## Studs a field has before it is varied with a textured tile.
const ACCENTS_FROM := 16

## Flat tiles, largest first by area (Patterns.TILES has plates).
const TILES: Array = ["10202", "1751", "69729", "87079", "4162", "26603", "6636",
	"3068b", "2431", "63864", "3069b", "3070b"]
## Textured tiles a set varies a big field with: grille, ingot, jumper.
const ACCENTS: Array = ["2412b", "96910", "15573"]
## What an accent becomes when the design wants it plain.
const PLAIN_ACCENT := "3069b"
## Slopes laid on a tread, straight and curved, read off their own meshes
## (Shapes.part) for how deep they fall and how tall they are.
const STRAIGHT: Array = ["3037", "3038", "3039", "3040b", "3297", "3298", "4286",
	"60477", "54200", "85984"]
const CURVED: Array = ["93606", "61678", "24309", "50950", "15068", "11477"]
## A step brick laid again as a slope: 45 degrees, two studs deep.
const STEP_SLOPES: Array = ["3037", "3038", "3039", "3040b"]
## And under a one-stud tread a brick tall where no brick can be laid again:
## a plate and a cheese slope on it.
const CHEESE := "54200"
const ROW_PLATES: Array = ["3710", "3623", "3023b", "3024"]
## The rest of a step brick behind its slope, a brick tall.
const FILL_BRICKS: Array = ["3001", "3002", "3010", "3003", "3622", "3004", "3005"]
## Families whose studs are finished; any other part's stud is its detail.
const FINISHED_KINDS: Array = ["Brick", "Plate", "Slope", "Wedge", "Wing", "Baseplate"]
## What standing among a field makes it a yard.
const LIVING: Array = ["Minifig", "Figure", "Animal", "Plant"]
## A subject built of straight slopes first; anything else curved first.
const BUILT_WORDS: Array = ["house", "shop", "store", "castle", "tower", "roof",
	"station", "temple", "cabin", "church", "gate", "gatehouse", "wall", "building",
	"modular", "street", "town", "city", "hut", "lighthouse", "fort", "palace",
	"bridge", "cottage", "school", "bank", "cafe", "bakery", "garage", "hall",
	"mill", "factory", "warehouse", "pagoda", "shed"]
## Along +z, +x, -z, -x in half studs: the ways a staircase can rise.
const WAYS: Array[Vector2i] = [Vector2i(0, 2), Vector2i(2, 0), Vector2i(0, -2),
	Vector2i(-2, 0)]


## One thing found, what the app laid for it, and what the design said.
class Finding extends RefCounted:
	## "S1", or "G1" for ground offered and not laid.
	var key: String = ""
	## "studs", "staircase" or "wall".
	var kind: String = ""
	## Where and why, in a line.
	var said: String = ""
	## What was laid, in words.
	var laid: String = ""
	## The open studs it is on, as tops keys; and its box in LDU.
	var cells: Array[Vector3i] = []
	var box := AABB()
	var studs: int = 0
	## The ground, offered rather than laid.
	var offered: bool = false
	## The placements laid (as edit_model takes them), which of them are
	## textured tiles, the bricks taken off for it and those bricks as they
	## were, to put back.
	var add: Array = []
	var accents: Array[int] = []
	var remove: Array[int] = []
	var restore: Array = []
	## The bricks laid for it, once laid.
	var ids: Array[int] = []
	## The view that sees it best: a slope falling toward -x or -z, or a wall
	## facing that way, is seen from the far corner. "" for either.
	var seen_from: String = ""
	## "" until settled: "accepted", "adjusted", "rejected", "kept"; "left"
	## when a loop's turns ran out with it standing.
	var verdict: String = ""
	var reason: String = ""

	func settled() -> bool:
		return not verdict.is_empty()

	func mark() -> Vector3:
		return Vector3(box.get_center().x, box.end.y + 4.0, box.get_center().z)


var assistant: Assistant
## Every finding of this design, laid or offered, in the order handed.
var findings: Array[Finding] = []
## Where the design said keep, or rejected the app's pieces: [AABB in LDU,
## why]. Never proposed again for this design.
var zones: Array = []
## Whether the pass has been handed for this design.
var ran: bool = false
## Whether saving has said so to a session that never ran it.
var reminded: bool = false
## What the last reading left alone, in a line each, and how many it found
## but did not lay (over MOST_FINDINGS).
var left_alone: PackedStringArray = PackedStringArray()
var more: int = 0
var _numbered: int = 0
var _offered: int = 0
## The model read once per reading: placements by brick id.
var _read: OpenPoints = null


func _init(of: Assistant) -> void:
	assistant = of


## A new design: nothing found, nothing kept, the pass still to come.
func reset() -> void:
	findings = []
	zones = []
	ran = false
	reminded = false
	left_alone = PackedStringArray()
	more = 0
	_numbered = 0
	_offered = 0


## The laid findings not settled yet.
func open() -> Array[Finding]:
	var out: Array[Finding] = []
	for one: Finding in findings:
		if not one.offered and not one.settled():
			out.append(one)
	return out


## What the pass came to, in a line: "" when it has not run.
func record() -> String:
	if not ran:
		return ""
	if findings.is_empty():
		return "nothing to finish"
	var by: Dictionary = {}
	var tiled: int = 0
	var sloped: int = 0
	var walls: int = 0
	for one: Finding in findings:
		var verdict: String = one.verdict if one.settled() else (
			"offered" if one.offered else "not settled")
		by[verdict] = int(by.get(verdict, 0)) + 1
		if verdict in ["accepted", "adjusted", "left"]:
			match one.kind:
				"studs":
					tiled += one.studs
				"staircase":
					sloped += 1
				"wall":
					walls += 1
	var said := PackedStringArray()
	for verdict: String in ["accepted", "adjusted", "left", "rejected", "kept", "offered",
			"not settled"]:
		if by.has(verdict):
			said.append("%d %s" % [int(by[verdict]), verdict])
	var kept := PackedStringArray()
	if tiled > 0:
		kept.append("%d studs tiled" % tiled)
	if sloped > 0:
		kept.append("%d staircase%s sloped" % [sloped, "" if sloped == 1 else "s"])
	if walls > 0:
		kept.append("%d wall%s textured" % [walls, "" if walls == 1 else "s"])
	return "%d finding%s: %s%s" % [findings.size(), "" if findings.size() == 1 else "s",
		", ".join(said), "" if kept.is_empty() else "; " + ", ".join(kept)]


## What saving says to a session from outside about the pass, without
## refusing: that it was never run, or which findings wait. "" otherwise.
func reminder() -> String:
	if not ran:
		return ("The surface pass has not been run: review_model {\"surface\": true} "
			+ "finishes the open stud fields, stud staircases and plain walls with real "
			+ "pieces laid on the model, for you to settle. Then save again.")
	var left: Array[Finding] = open()
	if left.is_empty():
		return ""
	var keys := PackedStringArray()
	for one: Finding in left:
		keys.append(one.key)
	return ("The surface pass has %s not settled: settle_surface each — accept, reject "
		% ", ".join(keys) + "or keep, with a reason — then save again.")


## For the creative pass: a touch stood on a tiled top floats, so where the
## pass tiled, said; "" where it tiled nothing.
func for_touches() -> String:
	for one: Finding in findings:
		if one.kind == "studs" and not one.offered and not one.ids.is_empty() \
				and one.verdict in ["", "accepted", "adjusted", "left"]:
			return ("The surface pass tiled tops: a touch stood on a tile floats, so stand "
				+ "it where studs are, or take a tile off for it.")
	return ""


# -- handing it over -----------------------------------------------------------


## Find, lay and hand over: the findings in words and one picture of the
## proposal standing on the model, marked. An Array of content blocks, or a
## String where there is no picture or nothing was found. Awaited.
func hand() -> Variant:
	ran = true
	if assistant._bricks_inside({}).is_empty():
		return "The baseplate is bare: build the model before its surface."
	assistant.progress.emit("the surface pass: reading the model's studs, steps and walls")
	var found: Array[Finding] = find()
	var laid: Array[Finding] = []
	var offers: Array[Finding] = []
	for one: Finding in found:
		if one.offered:
			_offered += 1
			one.key = "G%d" % _offered
			findings.append(one)
			offers.append(one)
			continue
		if await _lay(one):
			_numbered += 1
			one.key = "S%d" % _numbered
			findings.append(one)
			laid.append(one)
		else:
			left_alone.append("a %s at %s, which could not be laid as it stands: %s"
				% [one.kind, _where_said(one.box), _why_not])
	if laid.is_empty() and offers.is_empty():
		assistant.progress.emit("the surface pass: nothing to finish")
		return ("The surface pass found nothing to finish: no open stud field, no stud "
			+ "staircase and no long plain wall%s." % (
				" (left alone: %s)" % "; ".join(left_alone) if not left_alone.is_empty() else ""))
	assistant.progress.emit("the surface pass: laid %d proposal%s%s" % [laid.size(),
		"" if laid.size() == 1 else "s", ", offered %d" % offers.size()
			if not offers.is_empty() else ""])
	var text: String = _brief(laid, offers)
	var picture: Dictionary = await _picture(laid + offers)
	if picture.is_empty():
		return text
	return [{"type": "text", "text": text}, picture]


func _brief(laid: Array[Finding], offers: Array[Finding]) -> String:
	var lines := PackedStringArray()
	lines.append("The surface pass: the app read the model's open studs, the way they "
		+ "step and its plain walls, and laid real pieces for each as a proposal, "
		+ "standing on the model now (marked in the picture):")
	for one: Finding in laid:
		lines.append("  %s %s: %s Laid: %s%s." % [one.key, one.kind, one.said, one.laid,
			_bricks_said(one.ids)])
	for one: Finding in offers:
		lines.append("  %s, offered, not laid: %s \"tile\" lays %s." % [one.key, one.said,
			one.laid])
	if not left_alone.is_empty():
		lines.append("Left as studs: %s." % "; ".join(left_alone))
	if more > 0:
		lines.append("And %d more, smaller: review_model {\"surface\": true} again " % more
			+ "once these are settled.")
	lines.append(SETTLE_HOW)
	return "\n".join(lines)


const SETTLE_HOW := """Settle each with settle_surface {"finding": "S1", \
"verdict": ...} (or "finding": "all"): "accept" keeps it — with "plain": true \
for plain tiles where the textured ones are, or "recolor": {"4": 320}, to \
adjust it; "reject" with a reason takes the app's pieces off and puts back \
what they replaced, to finish it your own way; "keep" with a reason does the \
same and leaves the studs for good — a yard, a mosaic, a studded texture, \
where a touch will stand. A real set leaves studs only where something is \
built on them."""


static func _bricks_said(ids: Array[int]) -> String:
	if ids.is_empty():
		return ""
	var said := PackedStringArray()
	for id: int in ids.slice(0, 12):
		said.append("#%d" % id)
	return " (bricks %s%s)" % [", ".join(said), ", ..." if ids.size() > 12 else ""]


## One picture of what was laid, each finding numbered, from the corner that
## sees most of them: slopes falling away from the usual corner are seen from
## the far one.
func _picture(shown: Array[Finding]) -> Dictionary:
	if not ModelShot.possible() or shown.is_empty():
		return {}
	var shot: ModelShot = assistant._ensure_shot()
	shot.highlight = {}
	var marks: Array = []
	var far: int = 0
	for one: Finding in shown:
		marks.append([one.mark(), one.key])
		far += {"far corner": 1, "corner": -1}.get(one.seen_from, 0)
	shot.marks = marks
	var image: Image = await shot.take(assistant.world, "far corner" if far > 0 else "corner",
		assistant.scenery)
	shot.marks = []
	if image == null:
		return {}
	return await shot.encode(image)


# -- settling ------------------------------------------------------------------


## settle_surface: what the design says of one finding, a few, or all.
func settle(args: Dictionary) -> String:
	var asked: String = str(args.get("finding", "")).strip_edges()
	var verdict: String = str(args.get("verdict", "")).strip_edges().to_lower()
	var reason: String = str(args.get("reason", "")).strip_edges()
	if not verdict in ["accept", "reject", "keep", "tile"]:
		return "verdict is one of \"accept\", \"reject\", \"keep\" or, for ground offered, \"tile\"."
	if findings.is_empty():
		return ("Nothing has been proposed yet: review_model {\"surface\": true} reads the "
			+ "model and lays the surface pass's pieces.")
	var which: Array[Finding] = _named(asked, verdict)
	if which.is_empty():
		var keys := PackedStringArray()
		for one: Finding in findings:
			keys.append(one.key)
		return "No finding called \"%s\". There is: %s, or \"all\"." % [asked, ", ".join(keys)]
	if verdict in ["reject", "keep"] and reason.split(" ", false).size() < 3:
		return ("Say why in a sentence (reason): what is wrong with the app's pieces there, "
			+ "or what the studs are for.")
	var said := PackedStringArray()
	for one: Finding in which:
		said.append(await _settle_one(one, verdict, reason, args))
	var left: Array[Finding] = open()
	if left.is_empty():
		said.append("Every finding is settled: %s." % record())
		assistant.progress.emit("the surface pass: %s" % record())
	else:
		var keys := PackedStringArray()
		for one: Finding in left:
			keys.append(one.key)
		said.append("Still to settle: %s." % ", ".join(keys))
	return "\n".join(said)


func _named(asked: String, verdict: String) -> Array[Finding]:
	var out: Array[Finding] = []
	if asked.to_lower() == "all":
		for one: Finding in findings:
			if one.settled():
				continue
			# All the laid ones, or for "tile" all the ground offered.
			if one.offered == (verdict == "tile"):
				out.append(one)
		return out
	for word: String in asked.replace(",", " ").split(" ", false):
		for one: Finding in findings:
			if one.key.to_lower() == word.to_lower() and not out.has(one):
				out.append(one)
	return out


func _settle_one(one: Finding, verdict: String, reason: String, args: Dictionary) -> String:
	match verdict:
		"accept", "tile":
			if one.offered and one.ids.is_empty():
				if not await _lay(one):
					return "%s: could not be laid as it stands now (%s); tile it with edit_model." % [
						one.key, _why_not]
				one.offered = false
				one.verdict = "accepted"
				return "%s: tiled — %s%s." % [one.key, one.laid, _bricks_said(one.ids)]
			if not _standing(one):
				return ("%s: the app's pieces are not all standing any more; reject it with " % one.key
					+ "a reason, or keep it.")
			var adjusted: bool = false
			var add: Array = one.add.duplicate(true)
			if bool(args.get("plain", false)) and not one.accents.is_empty():
				for n: int in one.accents:
					(add[n] as Dictionary)["part"] = PLAIN_ACCENT
				adjusted = true
			if args.get("recolor") is Dictionary and not (args["recolor"] as Dictionary).is_empty():
				var recolor: Dictionary = {}
				for key: Variant in args["recolor"]:
					recolor[int(str(key))] = int((args["recolor"] as Dictionary)[key])
				for raw: Variant in add:
					var placed: Dictionary = raw
					placed["color"] = int(recolor.get(int(placed["color"]), int(placed["color"])))
				adjusted = true
			if adjusted:
				var ids: Array[int] = await _edit(add, one.ids)
				if ids.is_empty():
					return "%s: not adjusted, it stays as laid: %s" % [one.key, _why_not]
				one.add = add
				if bool(args.get("plain", false)):
					one.accents = []
				one.ids = ids
				one.verdict = "adjusted"
				return "%s: adjusted and kept%s." % [one.key, _bricks_said(ids)]
			one.verdict = "accepted"
			return "%s: accepted." % one.key
		"reject", "keep":
			if not one.ids.is_empty() and not await _take_off(one):
				return "%s: could not take the app's pieces off (%s); settle it another way." % [
					one.key, _why_not]
			one.verdict = "rejected" if verdict == "reject" else "kept"
			one.reason = reason
			zones.append([one.box.grow(2.0), reason])
			return "%s: %s — %s; %s." % [one.key, one.verdict, reason,
				"the studs stay, and the pass leaves them alone" if verdict == "keep"
					else "the app's pieces are off, finish it your own way"]
	return ""


## For an outside loop's turns that ran out: what stands is kept as laid.
func close() -> void:
	for one: Finding in open():
		one.verdict = "left"


# -- reading the model ---------------------------------------------------------


## Everything the pass would do to the model as it stands, best first, at most
## MOST_FINDINGS laid; nothing is laid here.
func find() -> Array[Finding]:
	left_alone = PackedStringArray()
	more = 0
	var out: Array[Finding] = []
	if _is_mosaic():
		left_alone.append("a Brick Art mosaic: its studs are the picture")
		return out
	_read = OpenPoints.read(assistant)
	var tops: Dictionary = open_tops()
	var claimed: Dictionary = {}
	var gone: Dictionary = {}
	var stairs: Array[Finding] = _staircases(tops, claimed, gone)
	var fields: Array[Finding] = _fields(tops, claimed)
	var walls: Array[Finding] = _walls(gone)
	var by_size := func(a: Finding, b: Finding) -> bool: return a.studs > b.studs
	stairs.sort_custom(by_size)
	fields.sort_custom(by_size)
	walls.sort_custom(by_size)
	var room: int = MOST_FINDINGS
	for group: Array in [[stairs, MOST_STAIRCASES], [fields, MOST_FINDINGS], [walls, MOST_WALLS]]:
		var these: Array = group[0]
		var most: int = int(group[1])
		for n: int in these.size():
			var one: Finding = these[n]
			if one.offered:
				out.append(one)
			elif n < most and room > 0:
				out.append(one)
				room -= 1
			else:
				more += 1
	return out


## Every open stud on the model, by where it is in half studs and lattice
## cells up: {"at", "brick", "colour", "part"}. Open is standing_free, on a
## part whose studs are finished, its square all part, outside every zone the
## design kept.
func open_tops() -> Dictionary:
	var out: Dictionary = {}
	var bricks: Array[BrickWorld.Brick] = assistant._bricks_inside({})
	if bricks.is_empty():
		return out
	if _read == null:
		_read = OpenPoints.read(assistant)
	var top: float = assistant._bounds_of(bricks).end.y
	var ids: Array = []
	for brick: BrickWorld.Brick in bricks:
		ids.append(brick.id)
	var library: PartLibrary = assistant.library
	for point: OpenPoints.Point in _read.points_of(ids):
		if point.kind != "stud" or not point.section.is_empty() \
				or point.way.dot(Vector3.UP) < 0.99:
			continue
		if not standing_free(point, top):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(point.part)
		if info == null or not finished_kind(info) or not _whole_square(point.at) \
				or _in_zone(point.at):
			continue
		var brick: BrickWorld.Brick = assistant.world.get_brick(point.brick)
		out[key_of(point.at)] = {"at": point.at, "brick": point.brick,
			"colour": brick.color_code if brick != null else 16, "part": point.part}
	return out


static func key_of(at: Vector3) -> Vector3i:
	return Vector3i(roundi(at.x / 10.0), roundi(at.y / 2.0), roundi(at.z / 10.0))


## Whether nothing stands on a stud and nothing of the model is over it, up to
## the model's top: a stud something stands on, or will (under a roof, an
## overhang, a floor above), stays a stud.
func standing_free(point: OpenPoints.Point, top: float) -> bool:
	if point.by != 0:
		return false
	var lattice: BrickLattice = assistant.builder.lattice
	var y: float = point.at.y + 6.0
	while y <= top + 4.0:
		var other: int = lattice.brick_at(BrickLattice.to_cell(Vector3(point.at.x, y, point.at.z)))
		if other != 0 and other != point.brick and not assistant.scenery.has(other):
			return false
		y += 8.0
	return true


## Whether a part's studs are ones a set finishes: a plain brick's, plate's,
## slope's, wedge's, wing's or baseplate's. A round plate, a jumper, a
## Technic part, a figure or a plant has its stud as its detail.
static func finished_kind(info: PartLibrary.PartInfo) -> bool:
	if not FINISHED_KINDS.has(info.family_category()):
		return false
	var name: String = info.name.to_lower()
	for word: String in ["round", "centre stud", "center stud", "jumper", "technic",
			"hollow stud", "pattern", "sticker"]:
		if name.contains(word):
			return false
	return true


## Whether all of a stud's square is part, a little under its top: a tile
## laid on a wedge's corner stud would overhang the edge.
func _whole_square(at: Vector3) -> bool:
	var lattice: BrickLattice = assistant.builder.lattice
	for corner: Vector2 in [Vector2(-6, -6), Vector2(6, -6), Vector2(-6, 6), Vector2(6, 6)]:
		if lattice.brick_at(BrickLattice.to_cell(at + Vector3(corner.x, -3.0, corner.y))) == 0:
			return false
	return true


func _in_zone(at: Vector3) -> bool:
	for zone: Array in zones:
		if (zone[0] as AABB).has_point(at):
			return true
	return false


## A Brick Art picture, laid by make_art or read off the model: most of a big
## model one-stud plates and tiles.
func _is_mosaic() -> bool:
	if assistant._art_laid > 0:
		return true
	var bricks: Array[BrickWorld.Brick] = assistant._bricks_inside({})
	if bricks.size() < 100:
		return false
	var dots: int = 0
	for brick: BrickWorld.Brick in bricks:
		var info: PartLibrary.PartInfo = assistant.library.parts.get(brick.part_id)
		if info != null and info.footprint_studs() == Vector2i.ONE \
				and info.family_category() in ["Plate", "Tile"]:
			dots += 1
	return dots >= 0.7 * bricks.size()


## Whether the subject is built of straight slopes first: a building's roof.
## Anything else follows its line with curves first.
func _straight_first() -> bool:
	var words: PackedStringArray = assistant._brief.to_lower().replace(".", " ").replace(
		",", " ").split(" ", false)
	for word: String in words:
		if BUILT_WORDS.has(word) or BUILT_WORDS.has(word.trim_suffix("s")):
			return true
	return false


# -- staircases ----------------------------------------------------------------


## The stud staircases: two risers or more of one to three plates, along one
## way, each tread between them one to three studs deep. Each riser is covered
## so it rises to the next tread, and the cells it covers are claimed.
func _staircases(tops: Dictionary, claimed: Dictionary, gone: Dictionary) -> Array[Finding]:
	var column: Dictionary = {}
	for key: Vector3i in tops:
		column[Vector2i(key.x, key.z)] = key
	var out: Array[Finding] = []
	var straight: bool = _straight_first()
	for d: Vector2i in WAYS:
		var perp := Vector2i(absi(d.y), absi(d.x))
		var rise_of: Dictionary = {}    ## foot -> plates up to the next
		for c: Vector2i in column:
			if not column.has(c + d):
				continue
			var rise: int = (int((column[c + d] as Vector3i).y) - int((column[c] as Vector3i).y)) * 2
			var plates: int = roundi(rise / PLATE)
			if plates >= 1 and plates <= 3 and absf(rise - plates * PLATE) < 1.0:
				rise_of[c] = plates
		var ups: Dictionary = {}
		var depth: Dictionary = {}
		var links: Dictionary = {}
		for c: Vector2i in rise_of:
			var high: int = (column[c + d] as Vector3i).y
			var run: Array[Vector2i] = []
			var at: Vector2i = c + d
			while column.has(at) and (column[at] as Vector3i).y == high \
					and run.size() <= DEEPEST_TREAD:
				run.append(at)
				if rise_of.has(at):
					break
				at += d
			ups[c] = run
			if rise_of.has(run[-1]) and run.size() <= DEEPEST_TREAD:
				links[c] = run[-1]
			var low: int = (column[c] as Vector3i).y
			var deep: int = 1
			var back: Vector2i = c - d
			while column.has(back) and (column[back] as Vector3i).y == low \
					and deep <= DEEPEST_TREAD:
				deep += 1
				back -= d
			depth[c] = deep
		var led: Dictionary = {}
		for c: Vector2i in links:
			led[links[c]] = true
		var on: Array[Vector2i] = []
		for c: Vector2i in rise_of:
			if links.has(c) or led.has(c):
				on.append(c)
		if on.is_empty():
			continue
		# One staircase: the feet joined up it and across it.
		var group: Dictionary = {}
		for c: Vector2i in on:
			group[c] = c
		var root := func(c: Vector2i) -> Vector2i:
			var at: Vector2i = c
			while group[at] != at:
				at = group[at]
			return at
		for c: Vector2i in on:
			for other: Vector2i in [links.get(c, c), c + perp, c - perp]:
				if other != c and group.has(other):
					var a: Vector2i = root.call(c)
					var b: Vector2i = root.call(other)
					if a != b:
						group[a] = b
		var stairs: Dictionary = {}
		for c: Vector2i in on:
			var r: Vector2i = root.call(c)
			if not stairs.has(r):
				stairs[r] = []
			(stairs[r] as Array).append(c)
		for feet: Variant in stairs.values():
			var one: Finding = _cover_staircase(feet as Array, d, perp, column, tops, rise_of,
				ups, depth, claimed, gone, straight)
			if one != null:
				out.append(one)
	return out


## The parts that cover one staircase's risers, as a finding; null where none
## could be laid.
func _cover_staircase(feet: Array, d: Vector2i, perp: Vector2i, column: Dictionary,
		tops: Dictionary, rise_of: Dictionary, ups: Dictionary, depth: Dictionary,
		claimed: Dictionary, gone: Dictionary, straight: bool) -> Finding:
	var one := Finding.new()
	one.kind = "staircase"
	# Rows: the feet at one height and one place along the way up, side by
	# side, with the same rise and tread.
	var rows: Dictionary = {}
	for raw: Variant in feet:
		var c: Vector2i = raw
		var along: int = c.x * absi(d.x) + c.y * absi(d.y)
		var row_key: String = "%d|%d|%d|%d" % [along, (column[c] as Vector3i).y,
			int(rise_of[c]), mini(int(depth[c]), DEEPEST_TREAD + 1)]
		if not rows.has(row_key):
			rows[row_key] = []
		(rows[row_key] as Array).append(c)
	var steps: Dictionary = {}
	var rises: Dictionary = {}
	for row_key: String in rows:
		var row: Array = rows[row_key]
		row.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x * perp.x + a.y * perp.y < b.x * perp.x + b.y * perp.y)
		# Contiguous runs across.
		var run: Array[Vector2i] = []
		for n: int in row.size():
			var c: Vector2i = row[n]
			if not run.is_empty() and c != run[-1] + perp:
				_cover_row(one, run, d, perp, column, tops, rise_of, ups, depth, claimed, gone,
					straight)
				run = []
			run.append(c)
		_cover_row(one, run, d, perp, column, tops, rise_of, ups, depth, claimed, gone, straight)
		steps[row_key.get_slice("|", 0)] = true
		rises[int(rise_of[row[0]])] = true
	if one.add.is_empty():
		return null
	var rise_words := PackedStringArray()
	for r: int in rises:
		rise_words.append({1: "a plate", 2: "two plates", 3: "a brick"}[r])
	var way: String = {Vector2i(0, 2): "+z", Vector2i(2, 0): "+x", Vector2i(0, -2): "-z",
		Vector2i(-2, 0): "-x"}[d]
	one.said = "%d studs stepping up %s %d time%s by %s, %s." % [one.cells.size(), way,
		steps.size(), "" if steps.size() == 1 else "s", " or ".join(rise_words),
		_where_said(one.box)]
	one.studs = one.cells.size()
	one.laid = _pieces_said(one)
	one.seen_from = "far corner" if d.x > 0 or d.y > 0 else "corner"
	return one


## Cover one row of feet: a slope on each tread rising to the next, or where a
## tread is one stud deep under a brick's rise, the brick above laid again as a
## 45 degree slope; else a plate and a cheese slope on the tread.
func _cover_row(one: Finding, run: Array[Vector2i], d: Vector2i, perp: Vector2i,
		column: Dictionary, tops: Dictionary, rise_of: Dictionary, ups: Dictionary,
		depth: Dictionary, claimed: Dictionary, gone: Dictionary, straight: bool) -> void:
	if run.is_empty():
		return
	var rise: int = int(rise_of[run[0]])
	var deep: int = int(depth[run[0]])
	if rise == 1:
		return
	var tread: int = deep if deep <= DEEPEST_TREAD else (2 if rise == 3 else 1)
	var fall := Vector2i(-d.x / 2, -d.y / 2)
	if tread == 1 and rise == 3:
		var left: Array[Vector2i] = _lay_again(one, run, d, perp, column, tops, ups, claimed,
			gone, fall)
		if not left.is_empty():
			_plate_and_cheese(one, left, d, perp, column, tops, claimed, fall)
		return
	var options: Array = _slopes_for(tread, rise, straight)
	if options.is_empty():
		return
	var n: int = 0
	while n < run.size():
		var done: bool = false
		for option: Dictionary in options:
			var wide: int = int(option["w"])
			if n + wide > run.size():
				continue
			var cells: Array[Vector2i] = []
			for a: int in wide:
				for b: int in tread:
					cells.append(run[n + a] - d * b)
			if not _free_cells(cells, column, claimed):
				continue
			var placed: Dictionary = _slope_at(option, cells, column, tops, fall)
			if not _fits(placed, {}):
				continue
			_take(one, cells, column, tops, claimed)
			one.add.append(placed)
			n += wide
			done = true
			break
		if not done:
			n += 1


## Slopes that fall [param tread] studs and stand [param rise] plates, widest
## first, curved or straight first as the subject reads.
func _slopes_for(tread: int, rise: int, straight: bool) -> Array:
	var out: Array = []
	for list: Array in ([STRAIGHT, CURVED] if straight else [CURVED, STRAIGHT]):
		var these: Array = []
		for id: String in list:
			var shape: Dictionary = Shapes.part(assistant.library, id)
			if not shape.is_empty() and int(shape["d"]) == tread and int(shape["h"]) == rise:
				these.append(shape)
		these.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["w"]) > int(b["w"]))
		out.append_array(these)
	return out


## A slope standing on [param cells], falling toward [param fall], as
## edit_model takes it, in the colour of the part under its first cell.
func _slope_at(shape: Dictionary, cells: Array[Vector2i], column: Dictionary,
		tops: Dictionary, fall: Vector2i) -> Dictionary:
	var low := Vector2(INF, INF)
	var y: float = 0.0
	var colour: int = 16
	for cell: Vector2i in cells:
		var top: Dictionary = tops[column[cell]]
		var at: Vector3 = top["at"]
		low = Vector2(minf(low.x, at.x), minf(low.y, at.z))
		y = at.y
		colour = int(top["colour"]) if colour == 16 else colour
	return {"part": str(shape["id"]), "color": colour,
		"x": snappedf(low.x / STUD - 0.5, 0.05), "y": snappedf(y / PLATE, 0.25),
		"z": snappedf(low.y / STUD - 0.5, 0.05),
		"rot": posmod(Shapes.OUT.find(fall) + int(shape["turn"]), 4)}


## Where a tread is one stud deep and the rise behind it a brick: the brick
## above it laid again as a 45 degree slope, its sloped row where the tread's
## riser was and its studs under the next step, the rest of it in bricks of
## its own colour. Returns the feet it could not do this for.
func _lay_again(one: Finding, run: Array[Vector2i], d: Vector2i, perp: Vector2i,
		column: Dictionary, tops: Dictionary, ups: Dictionary, claimed: Dictionary,
		gone: Dictionary, fall: Vector2i) -> Array[Vector2i]:
	var left: Array[Vector2i] = []
	var by_brick: Dictionary = {}
	for c: Vector2i in run:
		var front: Vector2i = (ups[c] as Array)[0]
		var brick: int = int((tops[column[front]] as Dictionary)["brick"])
		if not by_brick.has(brick):
			by_brick[brick] = []
		(by_brick[brick] as Array).append(c)
	for brick_id: int in by_brick:
		var feet: Array = by_brick[brick_id]
		if not _lay_brick_again(one, brick_id, feet, d, perp, column, tops, claimed, gone, fall):
			for c: Variant in feet:
				left.append(c as Vector2i)
	return left


func _lay_brick_again(one: Finding, brick_id: int, feet: Array, d: Vector2i, perp: Vector2i,
		column: Dictionary, tops: Dictionary, claimed: Dictionary, gone: Dictionary,
		fall: Vector2i) -> bool:
	if gone.has(brick_id):
		return false
	var brick: BrickWorld.Brick = assistant.world.get_brick(brick_id)
	var placement: Assistant.Placement = _read.by_id.get(brick_id)
	if brick == null or placement == null or placement.face != "up" \
			or not placement.section.is_empty():
		return false
	var info: PartLibrary.PartInfo = assistant.library.parts.get(brick.part_id)
	var mesh: Lbm.PartMesh = assistant.library.mesh_for(brick.part_id)
	if info == null or mesh == null or info.family_category() != "Brick" \
			or not finished_kind(info):
		return false
	var box: AABB = (brick.transform * mesh.bounds).abs()
	if absf(box.size.y - 28.0) > 1.0:
		return false
	# Its studs, in half studs, by row along the way up.
	var cells: Array[Vector2i] = []
	var x: float = box.position.x + 10.0
	while x < box.end.x - 1.0:
		var z: float = box.position.z + 10.0
		while z < box.end.z - 1.0:
			cells.append(Vector2i(roundi(x / 10.0), roundi(z / 10.0)))
			z += STUD
		x += STUD
	# Rows along the way up, one apart: the half-stud cells are two apart.
	var along := func(c: Vector2i) -> int: return (c.x * d.x + c.y * d.y) / 2
	var front: int = 1 << 30
	for c: Vector2i in cells:
		front = mini(front, along.call(c))
	var rows: int = 0
	for c: Vector2i in cells:
		rows = maxi(rows, (int(along.call(c)) - front) / 2 + 1)
	if rows < 2:
		return false
	# Its front row is exactly the tread's top of this run: every one a stud
	# whose foot below is one of these.
	var fronts: Dictionary = {}
	for c: Variant in feet:
		fronts[(c as Vector2i) + d] = true
	for c: Vector2i in cells:
		if along.call(c) == front and not fronts.has(c):
			return false
	var bottom: float = box.position.y
	var colour: int = brick.color_code
	var row_cells := func(r: int) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for c: Vector2i in cells:
			if along.call(c) == front + 2 * r:
				out.append(c)
		out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x * perp.x + a.y * perp.y < b.x * perp.x + b.y * perp.y)
		return out
	var first: Array[Vector2i] = row_cells.call(0)
	var made: Array = []
	var n: int = 0
	while n < first.size():
		var laid: bool = false
		for id: String in STEP_SLOPES:
			var shape: Dictionary = Shapes.part(assistant.library, id)
			if shape.is_empty() or int(shape["d"]) != 2:
				continue
			var wide: int = int(shape["w"])
			if n + wide > first.size():
				continue
			var span: Array[Vector2i] = []
			for a: int in wide:
				span.append(first[n + a])
				span.append(first[n + a] + d)
			made.append(_at_cells(str(shape["id"]), span, bottom, colour,
				posmod(Shapes.OUT.find(fall) + int(shape["turn"]), 4)))
			n += wide
			laid = true
			break
		if not laid:
			return false
	# The rest of it, behind the slope, in bricks.
	var rest: Dictionary = {}
	for r: int in range(2, rows):
		for c: Vector2i in row_cells.call(r):
			rest[c] = true
	made.append_array(_bricks_over(rest, bottom, colour))
	# The slope's studs, where they were open: tiled, as the tread was.
	var studs_up: Array[Vector3i] = []
	var top_key: int = roundi((bottom + 24.0) / 2.0)
	for c: Vector2i in row_cells.call(1):
		if column.has(c) and not claimed.has(c) and (column[c] as Vector3i).y == top_key:
			studs_up.append(column[c])
	var skip: Dictionary = {brick_id: true}
	for placed: Variant in made:
		if not _fits(placed as Dictionary, skip):
			return false
	gone[brick_id] = true
	one.remove.append(brick_id)
	one.restore.append(_as_dict(placement))
	one.add.append_array(made)
	var taken: Array[Vector2i] = []
	for c: Vector2i in cells:
		taken.append(c)
	_take(one, taken, column, tops, claimed)
	if not studs_up.is_empty():
		var top_y: float = bottom + 24.0
		var free: Dictionary = {}
		for key: Vector3i in studs_up:
			free[Vector2i(key.x, key.z)] = [tops[key]["at"], colour]
		var none: Array[int] = []
		for tile: Variant in _tiles_over(free, top_y, 0, none, false):
			one.add.append(tile)
	return true


## Where nothing else could be laid on a one-stud tread under a brick's rise:
## a plate along the tread and a cheese slope on each of its studs.
func _plate_and_cheese(one: Finding, feet: Array[Vector2i], d: Vector2i, perp: Vector2i,
		column: Dictionary, tops: Dictionary, claimed: Dictionary, fall: Vector2i) -> void:
	var cheese: Dictionary = Shapes.part(assistant.library, CHEESE)
	if cheese.is_empty():
		return
	var free: Dictionary = {}
	for c: Vector2i in feet:
		if not claimed.has(c):
			var top: Dictionary = tops[column[c]]
			free[c] = [top["at"], int(top["colour"])]
	if free.is_empty():
		return
	var y: float = ((free.values()[0] as Array)[0] as Vector3).y
	var none: Array[int] = []
	var plates: Array = _tiles_over(free.duplicate(), y, 0, none, false, ROW_PLATES)
	var cheeses: Array = []
	for c: Vector2i in free:
		var at: Vector3 = (free[c] as Array)[0]
		var span: Array[Vector2i] = [c]
		var placed: Dictionary = _at_cells(CHEESE, span, y + PLATE, int((free[c] as Array)[1]),
			posmod(Shapes.OUT.find(fall) + int(cheese["turn"]), 4))
		placed["x"] = snappedf(at.x / STUD - 0.5, 0.05)
		placed["z"] = snappedf(at.z / STUD - 0.5, 0.05)
		cheeses.append(placed)
	for placed: Variant in plates:
		if not _fits(placed as Dictionary, {}):
			return
	var cells: Array[Vector2i] = []
	for c: Vector2i in free:
		cells.append(c)
	_take(one, cells, column, tops, claimed)
	one.add.append_array(plates)
	one.add.append_array(cheeses)


## A part covering half-stud [param cells], its low corner theirs, at height
## [param bottom] in LDU.
func _at_cells(id: String, cells: Array[Vector2i], bottom: float, colour: int,
		rot: int) -> Dictionary:
	var low := Vector2i(1 << 30, 1 << 30)
	for c: Vector2i in cells:
		low = Vector2i(mini(low.x, c.x), mini(low.y, c.y))
	return {"part": id, "color": colour, "x": snappedf((low.x * 10.0 - 10.0) / STUD, 0.05),
		"y": snappedf(bottom / PLATE, 0.25), "z": snappedf((low.y * 10.0 - 10.0) / STUD, 0.05),
		"rot": rot}


## Plain bricks over half-stud cells, largest first, a brick tall from
## [param bottom].
func _bricks_over(cells: Dictionary, bottom: float, colour: int) -> Array:
	var out: Array = []
	var options: Array = _rectangles(FILL_BRICKS, colour)
	var order: Array = cells.keys()
	order.sort_custom(_before)
	for raw: Variant in order:
		var c: Vector2i = raw
		if not cells.has(c):
			continue
		for option: Array in options:
			var span: Array[Vector2i] = _span(c, int(option[1]), int(option[2]))
			if span.all(func(one: Vector2i) -> bool: return cells.has(one)):
				for one: Vector2i in span:
					cells.erase(one)
				out.append(_at_cells(str(option[0]), span, bottom, colour, int(option[3])))
				break
	return out


# -- stud fields ---------------------------------------------------------------


## The open stud fields left, each at one height and joined stud to stud:
## tiles for each that is not a yard, the ground offered, small ones left.
func _fields(tops: Dictionary, claimed: Dictionary) -> Array[Finding]:
	var out: Array[Finding] = []
	var seen: Dictionary = {}
	var small: int = 0
	var small_studs: int = 0
	var living: Array = _living_boxes()
	var model_box: AABB = assistant._bounds_of(assistant._bricks_inside({}))
	for start: Vector3i in tops:
		if seen.has(start) or claimed.has(Vector2i(start.x, start.z)):
			continue
		var field: Array[Vector3i] = []
		var queue: Array[Vector3i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var key: Vector3i = queue.pop_back()
			field.append(key)
			for step: Vector3i in [Vector3i(2, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, 0, 2),
					Vector3i(0, 0, -2)]:
				var next: Vector3i = key + step
				if tops.has(next) and not seen.has(next) \
						and not claimed.has(Vector2i(next.x, next.z)):
					seen[next] = true
					queue.append(next)
		if field.size() < SMALLEST_FIELD:
			small += 1
			small_studs += field.size()
			continue
		var box: AABB = _box_of(field, tops)
		if _lived_on(box, living):
			left_alone.append("%d studs %s that a figure, an animal or a plant stands among: a yard"
				% [field.size(), _where_said(box)])
			continue
		var one := Finding.new()
		one.kind = "studs"
		one.cells = field
		one.box = box
		one.studs = field.size()
		var free: Dictionary = {}
		var colours: Dictionary = {}
		for key: Vector3i in field:
			var top: Dictionary = tops[key]
			free[Vector2i(key.x, key.z)] = [top["at"], int(top["colour"])]
			colours[int(top["colour"])] = true
		var y: float = ((tops[field[0]] as Dictionary)["at"] as Vector3).y
		one.offered = _ground(box, model_box)
		var accents: int = 0
		if field.size() >= ACCENTS_FROM and not one.offered:
			accents = 1 if field.size() < 40 else (2 if field.size() < 80 else 3)
		var made: Array[int] = []
		one.add = _tiles_over(free, y, accents, made, true)
		one.accents = made
		if one.add.is_empty():
			continue
		var names := PackedStringArray()
		for code: int in colours:
			names.append(assistant._colour_name(code).to_lower())
		var across: int = roundi(box.size.x / STUD)
		var deep: int = roundi(box.size.z / STUD)
		one.said = "%s, %d open stud%s in %s, %d x %d studs %s." % [
			"the ground, a floor things will stand on" if one.offered else _what_top(box, model_box),
			field.size(), "" if field.size() == 1 else "s", ", ".join(names), across, deep,
			_where_said(box)]
		one.laid = _pieces_said(one)
		out.append(one)
	if small > 0:
		left_alone.append("%d smaller group%s of fewer than %d studs (%d studs), detail"
			% [small, "" if small == 1 else "s", SMALLEST_FIELD, small_studs])
	return out


## What a top is, by where it is on the model: "the top" for the highest,
## "a top" otherwise.
static func _what_top(box: AABB, model_box: AABB) -> String:
	return "the top" if box.end.y >= model_box.end.y - 30.0 else "a top"


## Whether a field is the model's ground: a plate or two up from its bottom,
## a base, and spanning most of it one way.
static func _ground(box: AABB, model_box: AABB) -> bool:
	if box.position.y > model_box.position.y + 16.5:
		return false
	return box.size.x >= 0.6 * model_box.size.x or box.size.z >= 0.6 * model_box.size.z


func _living_boxes() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in assistant._bricks_inside({}):
		var info: PartLibrary.PartInfo = assistant.library.parts.get(brick.part_id)
		if info == null:
			continue
		var category: String = info.family_category()
		for kind: String in LIVING:
			if category.begins_with(kind):
				var mesh: Lbm.PartMesh = assistant.library.mesh_for(brick.part_id)
				if mesh != null:
					out.append((brick.transform * mesh.bounds).abs())
				break
	return out


## Whether a figure, an animal or a plant stands on or among a field.
static func _lived_on(box: AABB, living: Array) -> bool:
	var reach := AABB(box.position - Vector3(STUD, 2.0, STUD),
		box.size + Vector3(2.0 * STUD, 14.0, 2.0 * STUD))
	for one: Variant in living:
		var other: AABB = one
		if reach.intersects(other) and other.position.y >= box.position.y - 4.0:
			return true
	return false


## Tiles over half-stud cells, each {cell: [stud position, colour]}, largest
## first in the colour under them, with [param accents] textured tiles spread
## over it first; their indexes in [param made]. Every tile is tested to fit
## and hold as it stands ([param test]).
func _tiles_over(free: Dictionary, y: float, accents: int, made: Array[int],
		test: bool, parts: Array = TILES) -> Array:
	var out: Array = []
	if free.is_empty():
		return out
	if accents > 0:
		var low := Vector2i(1 << 30, 1 << 30)
		var high := Vector2i(-(1 << 30), -(1 << 30))
		for c: Vector2i in free:
			low = Vector2i(mini(low.x, c.x), mini(low.y, c.y))
			high = Vector2i(maxi(high.x, c.x), maxi(high.y, c.y))
		var long_x: bool = high.x - low.x >= high.y - low.y
		for k: int in accents:
			var t: float = float(k + 1) / float(accents + 1)
			var aim := Vector2(lerpf(low.x, high.x, t if long_x else 0.5),
				lerpf(low.y, high.y, 0.5 if long_x else t))
			var best: Array = []
			var nearest: float = INF
			for c: Vector2i in free:
				for along: bool in [long_x, not long_x]:
					var other: Vector2i = c + (Vector2i(2, 0) if along else Vector2i(0, 2))
					if not free.has(other) or int(free[other][1]) != int(free[c][1]):
						continue
					var far: float = (Vector2(c) - aim).length()
					if far < nearest:
						nearest = far
						best = [c, other, along]
			if best.is_empty():
				break
			var colour: int = int(free[best[0]][1])
			var id: String = ""
			for n: int in ACCENTS.size():
				var candidate: String = ACCENTS[(k + n) % ACCENTS.size()]
				var info: PartLibrary.PartInfo = assistant.library.parts.get(candidate)
				if info != null and not info.never_made_in(colour) \
						and assistant.library.mesh_for(candidate) != null:
					id = candidate
					break
			if id.is_empty():
				break
			var foot: Vector2i = (assistant.library.parts[id] as PartLibrary.PartInfo).footprint_studs()
			var rot: int = 0 if (foot.x >= foot.y) == bool(best[2]) else 1
			var span: Array[Vector2i] = [best[0], best[1]]
			var placed: Dictionary = _tile_at(id, span, free, y, colour, rot)
			if test and not _fits(placed, {}):
				continue
			free.erase(best[0])
			free.erase(best[1])
			made.append(out.size())
			out.append(placed)
	var order: Array = free.keys()
	order.sort_custom(_before)
	var by_colour: Dictionary = {}
	for raw: Variant in order:
		var c: Vector2i = raw
		if not free.has(c):
			continue
		var colour: int = int(free[c][1])
		if not by_colour.has(colour):
			by_colour[colour] = _rectangles(parts, colour)
		for option: Array in by_colour[colour]:
			var span: Array[Vector2i] = _span(c, int(option[1]), int(option[2]))
			if not span.all(func(one: Vector2i) -> bool:
					return free.has(one) and int(free[one][1]) == colour):
				continue
			var placed: Dictionary = _tile_at(str(option[0]), span, free, y, colour,
				int(option[3]))
			if test and not _fits(placed, {}):
				continue
			for one: Vector2i in span:
				free.erase(one)
			out.append(placed)
			break
	return out


func _tile_at(id: String, span: Array[Vector2i], free: Dictionary, y: float, colour: int,
		rot: int) -> Dictionary:
	var low := Vector2(INF, INF)
	for c: Vector2i in span:
		var at: Vector3 = (free[c] as Array)[0]
		low = Vector2(minf(low.x, at.x), minf(low.y, at.z))
	return {"part": id, "color": colour, "x": snappedf(low.x / STUD - 0.5, 0.05),
		"y": snappedf(y / PLATE, 0.25), "z": snappedf(low.y / STUD - 0.5, 0.05), "rot": rot}


## Parts that cover a rectangle, by area and then squareness, each way round
## and only in colours they were made in (the 1 x 1 always): [id, across x,
## along z, rot].
func _rectangles(parts: Array, colour: int) -> Array:
	var out: Array = []
	for id: String in parts:
		var info: PartLibrary.PartInfo = assistant.library.parts.get(id)
		if info == null or assistant.library.mesh_for(id) == null:
			continue
		var foot: Vector2i = info.footprint_studs()
		if info.never_made_in(colour) and foot != Vector2i.ONE:
			continue
		out.append([id, foot.x, foot.y, 0])
		if foot.x != foot.y:
			out.append([id, foot.y, foot.x, 1])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		var area_a: int = int(a[1]) * int(a[2])
		var area_b: int = int(b[1]) * int(b[2])
		if area_a != area_b:
			return area_a > area_b
		return mini(int(a[1]), int(a[2])) > mini(int(b[1]), int(b[2])))
	return out


static func _span(c: Vector2i, across: int, deep: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in across:
		for k: int in deep:
			out.append(c + Vector2i(2 * i, 2 * k))
	return out


static func _before(a: Variant, b: Variant) -> bool:
	var one: Vector2i = a
	var two: Vector2i = b
	return one.y < two.y or (one.y == two.y and one.x < two.x)


# -- plain walls ---------------------------------------------------------------


## The long plain walls: one-wide plain bricks, and the outer rows of
## two-wide ones, with a face open to the air, joined course to course in
## one plane, at least six studs long and three courses tall and nine tenths
## one colour. Each is laid again by restyle_model's own pass, in its box.
func _walls(gone: Dictionary) -> Array[Finding]:
	var out: Array[Finding] = []
	var model: Assistant.Model = assistant._model_from_world()
	var middle := Vector3.ZERO
	var standing: Array[BrickWorld.Brick] = assistant._bricks_inside({})
	for brick: BrickWorld.Brick in standing:
		middle += brick.transform.origin
	if not standing.is_empty():
		middle /= float(standing.size())
	var walls: Dictionary = {}
	for placement: Assistant.Placement in model.placements:
		if gone.has(placement.id) or placement.face != "up" or not placement.section.is_empty():
			continue
		var long: int = int(Patterns.ONE_WIDE.get(placement.part,
			Assistant.TWO_WIDE.get(placement.part, 0)))
		if long == 0:
			continue
		var tint: PartLibrary.BrickColor = assistant.library.color(placement.color)
		if tint != null and tint.is_transparent():
			continue
		var along_x: bool = placement.rot % 2 == 0
		var rows: Array = [placement]
		if Assistant.TWO_WIDE.has(placement.part):
			rows = []
			for half: int in 2:
				rows.append(Assistant.Placement.from_dict({"part": Assistant.ONE_WIDE_OF[long],
					"color": placement.color, "x": placement.x + (0 if along_x else half),
					"y": placement.y, "z": placement.z + (half if along_x else 0),
					"rot": placement.rot}))
		for raw: Variant in rows:
			var row: Assistant.Placement = raw
			var facing: String = assistant._open_side(row, long, along_x, middle)
			if facing.is_empty():
				continue
			var depth: float = row.z if along_x else row.x
			var key: String = "%s|%s" % [facing, snappedf(depth, 0.5)]
			if not walls.has(key):
				walls[key] = []
			(walls[key] as Array).append({"id": placement.id, "along": row.x if along_x else row.z,
				"y": row.y, "long": long, "colour": placement.color, "along_x": along_x,
				"depth": depth, "facing": facing})
	for key: String in walls:
		var bricks: Array = walls[key]
		var seen: Dictionary = {}
		for n: int in bricks.size():
			if seen.has(n):
				continue
			var region: Array = []
			var queue: Array[int] = [n]
			seen[n] = true
			while not queue.is_empty():
				var at: int = queue.pop_back()
				region.append(bricks[at])
				var one: Dictionary = bricks[at]
				for m: int in bricks.size():
					if seen.has(m):
						continue
					var other: Dictionary = bricks[m]
					if absf(float(other["y"]) - float(one["y"])) <= 3.01 \
							and float(other["along"]) <= float(one["along"]) + int(one["long"]) \
							and float(one["along"]) <= float(other["along"]) + int(other["long"]):
						seen[m] = true
						queue.append(m)
			var found: Finding = _wall_finding(region)
			if found != null:
				out.append(found)
	return out


func _wall_finding(region: Array) -> Finding:
	var low_along: float = INF
	var high_along: float = -INF
	var low_y: float = INF
	var high_y: float = -INF
	var colours: Dictionary = {}
	var area: int = 0
	var ids: Dictionary = {}
	for raw: Variant in region:
		var one: Dictionary = raw
		low_along = minf(low_along, float(one["along"]))
		high_along = maxf(high_along, float(one["along"]) + int(one["long"]))
		low_y = minf(low_y, float(one["y"]))
		high_y = maxf(high_y, float(one["y"]) + 3.0)
		colours[int(one["colour"])] = int(colours.get(int(one["colour"]), 0)) + int(one["long"])
		area += int(one["long"]) * 3
		ids[int(one["id"])] = true
	var main: int = -1
	for code: int in colours:
		if main < 0 or int(colours[code]) > int(colours[main]):
			main = code
	var wide: float = high_along - low_along
	var tall: float = high_y - low_y
	if wide < 6.0 or tall < 9.0 or area < 72 or int(colours[main]) * 3 < 0.9 * area:
		return null
	var first: Dictionary = region[0]
	var along_x: bool = bool(first["along_x"])
	var depth: float = float(first["depth"])
	var where: Dictionary = {"y_from": low_y - 0.01, "y_to": high_y - 2.99}
	where["x_from" if along_x else "z_from"] = low_along - 0.01
	where["x_to" if along_x else "z_to"] = high_along - 0.99
	where["z_from" if along_x else "x_from"] = depth - 1.01
	where["z_to" if along_x else "x_to"] = depth + 0.01
	var change: Dictionary = assistant._restyle({"where": where})
	if not change.has("edit"):
		return null
	var edit: Dictionary = change["edit"]
	var one := Finding.new()
	one.kind = "wall"
	for raw: Variant in edit.get("remove", []):
		var id: int = int(raw)
		var placement: Assistant.Placement = _read.by_id.get(id) if _read != null else null
		if placement == null:
			return null
		one.remove.append(id)
		one.restore.append(_as_dict(placement))
	one.add = edit.get("add", [])
	one.studs = area / 3
	var low := Vector3((low_along if along_x else depth) * STUD, low_y * PLATE,
		(depth if along_x else low_along) * STUD)
	var high := Vector3((high_along if along_x else depth + 1.0) * STUD, high_y * PLATE,
		(depth + 1.0 if along_x else high_along) * STUD)
	one.box = AABB(low, high - low)
	one.said = "the %s face, %d studs by %d plates of plain bricks in %s, %s." % [
		str(first["facing"]), roundi(wide), roundi(tall),
		assistant._colour_name(main).to_lower(), _where_said(one.box)]
	one.laid = str(change["summary"]).trim_suffix(".")
	one.seen_from = "corner" if str(first["facing"]).begins_with("+") else "far corner"
	return one


# -- laying --------------------------------------------------------------------


var _why_not: String = ""


## Lay a finding through edit_model, checked like any edit, after checking
## again that its studs are still open: something may stand on them now.
func _lay(one: Finding) -> bool:
	_why_not = ""
	if not one.cells.is_empty():
		_read = OpenPoints.read(assistant)
		var now: Dictionary = open_tops()
		for key: Vector3i in one.cells:
			if not now.has(key):
				_why_not = "something stands on its studs now"
				return false
	for id: int in one.remove:
		if assistant.world.get_brick(id) == null:
			_why_not = "a brick it lays again has gone"
			return false
	var ids: Array[int] = await _edit(one.add, one.remove)
	if ids.is_empty():
		return false
	one.ids = ids
	if one.kind != "wall":
		one.box = one.box.merge(assistant._bounds_of(_bricks(ids))) if one.box.has_volume() \
			else assistant._bounds_of(_bricks(ids))
	return true


## Take a finding's pieces off and put back what they replaced.
func _take_off(one: Finding) -> bool:
	var standing: Array[int] = []
	for id: int in one.ids:
		if assistant.world.get_brick(id) != null:
			standing.append(id)
	if standing.is_empty() and one.restore.is_empty():
		one.ids = []
		return true
	var put_back: Array[int] = await _edit(one.restore, standing, true)
	if put_back.is_empty() and not one.restore.is_empty():
		return false
	if one.restore.is_empty() and assistant.world.get_brick(standing[0]) != null:
		return false
	one.ids = []
	return true


## One edit through edit_model: what it added, by id; none when refused (why,
## in _why_not). [param removing_only] takes an edit that adds nothing.
func _edit(add: Array, remove: Array[int], removing_only: bool = false) -> Array[int]:
	var before: Dictionary = {}
	for brick: BrickWorld.Brick in assistant.world.bricks():
		before[brick.id] = true
	var input: Dictionary = {}
	if not add.is_empty():
		input["add"] = add
	if not remove.is_empty():
		input["remove"] = remove
	var out: Array[int] = []
	if input.is_empty():
		return out
	assistant._laying_whole = true
	assistant._quiet_edit = true
	var answer: Variant = await assistant._run_tool({"name": "edit_model", "input": input})
	assistant._quiet_edit = false
	assistant._laying_whole = false
	var head: String = str(answer if answer is String else (
		((answer as Array)[0] as Dictionary).get("text", "") if answer is Array
			and not (answer as Array).is_empty() and (answer as Array)[0] is Dictionary else ""))
	if head.begins_with("Not applied") or head.begins_with("No brick") \
			or head.begins_with("Nothing in that") or head.begins_with("That would"):
		_why_not = head.substr(0, 200).replace("\n", " ")
		return out
	for brick: BrickWorld.Brick in assistant.world.bricks():
		if not before.has(brick.id):
			out.append(brick.id)
	if out.is_empty() and removing_only:
		out.append(0)
	return out


func _standing(one: Finding) -> bool:
	for id: int in one.ids:
		if assistant.world.get_brick(id) == null:
			return false
	return not one.ids.is_empty()


func _bricks(ids: Array[int]) -> Array[BrickWorld.Brick]:
	var out: Array[BrickWorld.Brick] = []
	for id: int in ids:
		var brick: BrickWorld.Brick = assistant.world.get_brick(id)
		if brick != null:
			out.append(brick)
	return out


## Whether a placement would fit and be held where the model stands now,
## the bricks in [param skip] taken off.
func _fits(placed: Dictionary, skip: Dictionary) -> bool:
	if _read == null:
		_read = OpenPoints.read(assistant)
	var trial: Dictionary = _read.test(Assistant.Placement.from_dict(placed), skip)
	if not bool(trial["fits"]):
		return false
	for by: Variant in trial["held_by"]:
		if int(by) > 0 and not skip.has(int(by)):
			return true
	return int(trial.get("rests_on", 0)) == -1


func _free_cells(cells: Array[Vector2i], column: Dictionary, claimed: Dictionary) -> bool:
	for c: Vector2i in cells:
		if not column.has(c) or claimed.has(c):
			return false
	return true


## Claim cells for a finding: its studs and its box.
func _take(one: Finding, cells: Array[Vector2i], column: Dictionary, tops: Dictionary,
		claimed: Dictionary) -> void:
	for c: Vector2i in cells:
		claimed[c] = true
		if column.has(c):
			var key: Vector3i = column[c]
			if not one.cells.has(key):
				one.cells.append(key)
	one.box = _box_of(one.cells, tops) if not one.cells.is_empty() else one.box


static func _as_dict(placement: Assistant.Placement) -> Dictionary:
	var out: Dictionary = {"part": placement.part, "color": placement.color, "x": placement.x,
		"y": placement.y, "z": placement.z, "rot": placement.rot}
	if placement.face != "up":
		out["face"] = placement.face
	if not placement.section.is_empty():
		out["section"] = placement.section
	return out


# -- said ----------------------------------------------------------------------


## The studs' box in LDU, a stud square each, to their tops.
static func _box_of(cells: Array[Vector3i], tops: Dictionary) -> AABB:
	var box := AABB()
	var first: bool = true
	for key: Vector3i in cells:
		if not tops.has(key):
			continue
		var at: Vector3 = (tops[key] as Dictionary)["at"]
		var one := AABB(at - Vector3(10.0, 0.0, 10.0), Vector3(STUD, 4.0, STUD))
		box = one if first else box.merge(one)
		first = false
	return box


## Where a box is, in studs and plates, as the session's coordinates read.
static func _where_said(box: AABB) -> String:
	return "x %s-%s z %s-%s at %s plates" % [_num(box.position.x / STUD), _num(box.end.x / STUD),
		_num(box.position.z / STUD), _num(box.end.z / STUD), _num(box.position.y / PLATE)]


static func _num(value: float) -> String:
	return Assistant.Placement._num(snappedf(value, 0.1))


## The pieces of a finding in words, commonest first: "2 x 87079 Tile 2 x 4".
func _pieces_said(one: Finding) -> String:
	var count: Dictionary = {}
	for raw: Variant in one.add:
		var id: String = str((raw as Dictionary)["part"])
		count[id] = int(count.get(id, 0)) + 1
	var ids: Array = count.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(count[a]) > int(count[b]))
	var said := PackedStringArray()
	for id: Variant in ids:
		said.append("%d x %s %s" % [int(count[id]), str(id), assistant._part_called(str(id))])
	var text: String = ", ".join(said)
	if not one.remove.is_empty():
		text += ", in place of %d brick%s" % [one.remove.size(), "" if one.remove.size() == 1 else "s"]
	return text
