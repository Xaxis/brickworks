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
##   staircase  studs, or tiles, stepping up a plate to a brick at a time over
##              one to three studs, two steps or more: a slope or curved slope
##              laid on each tread, rising to the next, or the step brick
##              itself laid again as a 45 degree slope where the tread is one
##              stud deep; a tiled tread's tiles come off first, and what of
##              each lay beyond the slope is laid again; and steps a plate
##              high, two at a time: a curved slope two plates tall over each
##              pair, the upper tread's plate cut under it (_cover_pairs);
##   edge       a body's hard top edge — a flat top, studs or tiles, ending at
##              a face that drops away: curved slopes along the edge falling
##              outward, the rest of the top raised flush with a plate and
##              tiles, its own tiles off first; nothing under the top is
##              touched. Not for a building, whose roof and parapet keep their
##              edges;
##   flank      a body's side of plain bricks, stacked: a course of it laid
##              again with its studs turned out, and on them, on their side,
##              plates and tiles with a curved slope at each end (_flanks).
##              Not for a building;
##   wall       a building's long plain wall of one-wide bricks, one colour:
##              laid again by restyle_model's own pass, some as masonry, no
##              stud turned out.
##
## Every finding is laid at once, up to MOST_FINDINGS; any over are counted
## and said, for the next review to lay.
##
## Whatever takes a part off is refused if the model would then be in more
## pieces: edit_model keeps to the count the model is in (Assistant
## ._keep_pieces).
##
## How it decides what is meant to be built on, in the order it asks:
##   - only a stud with nothing on it (BrickLattice.standing_on, the same
##     question a shape asks before it tiles its own top), nothing of the
##     model within a brick over it, and seen — open to the sky, or to the
##     outside on two sides under something high over it, as a lower wing is
##     — is open (standing_free): a stud something stands on, or a floor
##     between walls and under a roof, is not finished; and each lay is
##     checked again first, since anything may stand there by then;
##   - only studs of bricks, plates, slopes, wedges and wings are
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
## Findings laid at once; the rest are said, counted, and laid by the next
## review. Twelve once, and the edges round's starfighter kept "rows of exposed
## studs along the dark-red wing stripes" that the pass had found and not
## laid: its session never asked for the rest. Every finding is one edit and
## one check, so laying all of a model's costs little more than twelve.
const MOST_FINDINGS := 40
## How long laying may go on one finding at a time, when the edit of them all
## was refused: a session's call is answered within three minutes or never.
const LAYING_MS := 100000
const MOST_STAIRCASES := 12
const MOST_WALLS := 6
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
	"60477", "54200", "85984", "5404"]
## The curved ones two plates tall are what a pair of plate steps is laid in:
## 88930 four studs across, 15068 two, 11477 one, each two studs deep, and
## 7302 three deep where one tread of the pair is two.
const CURVED: Array = ["93606", "61678", "24309", "50950", "88930", "15068", "11477",
	"7302"]
## A step brick laid again as a slope: 45 degrees, two studs deep.
const STEP_SLOPES: Array = ["3037", "3038", "3039", "3040b"]
## And under a one-stud tread a brick tall where no brick can be laid again:
## a plate and a cheese slope on it.
const CHEESE := "54200"
const ROW_PLATES: Array = ["3710", "3623", "3023b", "3024"]
## The rest of a step brick behind its slope, a brick tall.
const FILL_BRICKS: Array = ["3001", "3002", "3010", "3003", "3622", "3004", "3005"]
## And of a plate cut along an edge, a plate tall, largest first.
const PLATES: Array = ["41539", "3036", "3958", "3032", "3035", "3031", "3034", "3795",
	"3020", "3021", "3022", "3460", "3666", "3710", "3623", "3023b", "3024"]
## What rounds a hard top edge: curved slopes two plates tall, two studs deep.
const EDGE_SLOPES: Array = ["15068", "11477"]
## Edges rounded at once, the biggest tops first.
const MOST_EDGES := 12
## Families whose studs are finished; any other part's stud is its detail. Not a
## baseplate's: it is the floor, which the app may take back as scenery, and a
## tile left on the floor is a piece of its own. The edges round's shop had 29
## of them, single tiles lying on its floor, after its ground was tiled.
const FINISHED_KINDS: Array = ["Brick", "Plate", "Slope", "Wedge", "Wing"]
## What standing among a field makes it a yard.
const LIVING: Array = ["Minifig", "Figure", "Animal", "Plant"]
## A subject built of straight slopes first; anything else curved first.
## Only words that name a building: a car has a roof, and in the edges round
## the car found nothing to round, read as a building, where the same model
## read as a car had three tops rounded.
const BUILT_WORDS: Array = ["house", "shop", "store", "castle", "tower", "temple",
	"cabin", "church", "gatehouse", "building", "modular", "hut", "lighthouse", "fort",
	"fortress", "palace", "cottage", "school", "bank", "cafe", "bakery", "mill",
	"factory", "warehouse", "pagoda", "shed", "inn", "tavern"]
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
	## The section its studs are in (a wing laid at an angle), or "".
	var section: String = ""
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
	var rounded: int = 0
	var skinned: int = 0
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
				"edge":
					rounded += 1
				"flank":
					skinned += 1
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
	if rounded > 0:
		kept.append("%d top%s rounded" % [rounded, "" if rounded == 1 else "s"])
	if skinned > 0:
		kept.append("%d flank%s skinned" % [skinned, "" if skinned == 1 else "s"])
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
	var to_lay: Array[Finding] = []
	var offers: Array[Finding] = []
	for one: Finding in found:
		if one.offered:
			_offered += 1
			one.key = "G%d" % _offered
			findings.append(one)
			offers.append(one)
		else:
			to_lay.append(one)
	var laid: Array[Finding] = await _lay_all(to_lay, Time.get_ticks_msec() + LAYING_MS)
	for one: Finding in laid:
		_numbered += 1
		one.key = "S%d" % _numbered
		findings.append(one)
	if laid.is_empty() and offers.is_empty():
		assistant.progress.emit("the surface pass: nothing to finish")
		return ("The surface pass found nothing to finish: no open stud field, no stud "
			+ "staircase, no hard top edge, no plain flank and no long plain wall%s." % (
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
	lines.append("The surface pass: the app read the model's open studs, its tops, the "
		+ "way they step and where they end, and its plain walls, and laid real pieces "
		+ "for each as a proposal, standing on the model now (marked in the picture):")
	for one: Finding in laid:
		lines.append("  %s %s: %s Laid: %s%s." % [one.key, one.kind, one.said, one.laid,
			_bricks_said(one.ids)])
	for one: Finding in offers:
		lines.append("  %s, offered, not laid: %s \"tile\" lays %s." % [one.key, one.said,
			one.laid])
	if not left_alone.is_empty():
		lines.append("Left as studs: %s." % "; ".join(left_alone))
	if more > 0:
		lines.append(("And %d more found and not laid yet, the smallest (at most %d are " % [
			more, MOST_FINDINGS]) + "laid at once): settle these, then review_model "
			+ "{\"surface\": true} again lays them.")
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
	_taken_off = {}
	var points: Array = _points()
	var tops: Dictionary = open_tops("", points)
	# And the tops already tiled, by the studs under their tiles: a staircase
	# of tiled steps is still a staircase, and a tiled top still has an edge.
	var levels: Dictionary = tile_tops()
	levels.merge(tops)
	var claimed: Dictionary = {}
	var gone: Dictionary = {}
	var stairs: Array[Finding] = _staircases(levels, claimed, gone)
	var edges: Array[Finding] = []
	if not _straight_first():
		edges = _edges(levels, claimed)
	var fields: Array[Finding] = _fields(tops, claimed)
	# And each section's own: a wing laid at an angle is studs up in its own
	# frame, and tiled in it. The starfighter's wings were open fields of
	# studs, all in sections.
	for name: Variant in _read.model.sections.keys():
		var tilted: Dictionary = open_tops(str(name), points)
		if not tilted.is_empty():
			fields.append_array(_fields(tilted, {}, str(name)))
	# A building's long plain walls are textured; a body's flanks skinned.
	var walls: Array[Finding] = _walls(gone) if _straight_first() else _flanks(gone)
	var by_size := func(a: Finding, b: Finding) -> bool: return a.studs > b.studs
	stairs.sort_custom(by_size)
	edges.sort_custom(by_size)
	fields.sort_custom(by_size)
	walls.sort_custom(by_size)
	var room: int = MOST_FINDINGS
	for group: Array in [[stairs, MOST_STAIRCASES], [edges, MOST_EDGES], [walls, MOST_WALLS],
			[fields, MOST_FINDINGS]]:
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


## Every connection point of the model's bricks, read once.
func _points() -> Array:
	if _read == null:
		_read = OpenPoints.read(assistant)
	var ids: Array = []
	for brick: BrickWorld.Brick in assistant._bricks_inside({}):
		ids.append(brick.id)
	return _read.points_of(ids)


## Every open stud of the main body, or of one [param section], by where it is
## in its own frame in half studs and lattice cells up: {"at" in the world,
## "here" in its frame, "brick", "colour", "part"}. Open is standing_free, up
## in its frame, on a part whose studs are finished, its square all part,
## outside every zone the design kept.
func open_tops(section: String = "", points: Array = []) -> Dictionary:
	var out: Dictionary = {}
	var bricks: Array[BrickWorld.Brick] = assistant._bricks_inside({})
	if bricks.is_empty():
		return out
	if points.is_empty():
		points = _points()
	var box: AABB = assistant._bounds_of(bricks)
	var library: PartLibrary = assistant.library
	for raw: Variant in points:
		var point: OpenPoints.Point = raw
		if point.kind != "stud" or point.section != section:
			continue
		if section.is_empty() and point.way.dot(Vector3.UP) < 0.99:
			continue
		if not section.is_empty() and (point.face != "up" or point.way.dot(Vector3.UP) < 0.5):
			continue
		if not standing_free(point, box):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(point.part)
		if info == null or not finished_kind(info) or not _whole_square(point) \
				or _in_zone(point.at):
			continue
		var brick: BrickWorld.Brick = assistant.world.get_brick(point.brick)
		out[key_of(point.local_at)] = {"at": point.at, "here": point.local_at,
			"brick": point.brick, "colour": brick.color_code if brick != null else 16,
			"part": point.part, "top": point.at.y}
	return out


## Every tile of the main body lying face up with nothing on it and seen,
## by the studs under it, as open_tops has them: {"at" the stud under it,
## "brick" the part under it, "tile" the tile, "colour" the tile's, "top" the
## tile's top}. Printed and round tiles are detail and are left out.
func tile_tops() -> Dictionary:
	var out: Dictionary = {}
	var bricks: Array[BrickWorld.Brick] = assistant._bricks_inside({})
	if bricks.is_empty():
		return out
	if _read == null:
		_read = OpenPoints.read(assistant)
	var box: AABB = assistant._bounds_of(bricks)
	var lattice: BrickLattice = assistant.builder.lattice
	for brick: BrickWorld.Brick in bricks:
		var info: PartLibrary.PartInfo = assistant.library.parts.get(brick.part_id)
		if info == null or info.family_category() != "Tile" or _plain(info) != "tile":
			continue
		var placement: Assistant.Placement = _read.by_id.get(brick.id)
		if placement == null or placement.face != "up" or not placement.section.is_empty():
			continue
		var mesh: Lbm.PartMesh = assistant.library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var tile: AABB = (brick.transform * mesh.bounds).abs()
		for c: Vector2i in _cells_of(tile):
			var on: Vector3 = Vector3(c.x * 10.0, tile.end.y, c.y * 10.0)
			if _in_zone(on) or not _seen(on, Vector3.UP, brick.id, box):
				continue
			var under: int = lattice.brick_at(BrickLattice.to_cell(
				Vector3(on.x, tile.position.y - 3.0, on.z)))
			if under == 0 or assistant.scenery.has(under):
				continue
			var at := Vector3(on.x, tile.position.y, on.z)
			out[key_of(at)] = {"at": at, "here": at, "brick": under, "tile": brick.id,
				"colour": brick.color_code, "part": brick.part_id, "top": tile.end.y}
	return out


## The stud cells of a part's box, in half studs.
static func _cells_of(box: AABB) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x: float = box.position.x + 10.0
	while x < box.end.x - 1.0:
		var z: float = box.position.z + 10.0
		while z < box.end.z - 1.0:
			out.append(Vector2i(roundi(x / 10.0), roundi(z / 10.0)))
			z += STUD
		x += STUD
	return out


## What a part is to a cut: "tile", "plate" or "brick" for the plain ones,
## a rectangle; "" for anything else, which a cut leaves alone.
static func _plain(info: PartLibrary.PartInfo) -> String:
	var name: String = info.name.to_lower()
	for word: String in ["round", "pattern", "print", "sticker", "grille", "with", "corner",
			"modulex", "duplo"]:
		if name.contains(word) and not (word == "with" and name.ends_with("with groove")):
			return ""
	match info.family_category():
		"Tile":
			return "tile" if name.begins_with("tile") else ""
		"Plate":
			return "plate" if name.begins_with("plate") else ""
		"Brick":
			return "brick" if name.begins_with("brick") else ""
	return ""


static func key_of(at: Vector3) -> Vector3i:
	return Vector3i(roundi(at.x / 10.0), roundi(at.y / 2.0), roundi(at.z / 10.0))


## Whether a stud is open: nothing stands on it, nothing of the model is
## within a brick over it, and it is seen — nothing over it out to the edge of
## the model's [param box], or open to the outside on two sides at least, as a
## lower wing is under the upper one. A stud something stands on, or will (a
## floor inside, under a roof, between walls), stays a stud.
func standing_free(point: OpenPoints.Point, box: AABB) -> bool:
	if not _nothing_on(point):
		return false
	return _seen(point.at, point.way, point.brick, box)


## Whether a surface at [param at], facing [param way], of part [param own],
## has nothing of the model within a brick over it and is seen: nothing over
## it out to the edge of the model's [param box], or open to the outside on
## two sides at least.
func _seen(at: Vector3, way: Vector3, own: int, box: AABB) -> bool:
	var reach: AABB = box.grow(8.0)
	var up: Vector3 = at + way * 6.0
	while reach.has_point(up):
		if _other_than(own, up):
			if up.distance_to(at) <= 30.0:
				return false
			break
		up += way * 8.0
	if not reach.has_point(up):
		return true
	var open: int = 0
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		# Over the stripes and greebles a brick tall on the same surface, and
		# under what is over it: nothing is within a brick of it.
		var along: Vector3 = at + way * 34.0
		var clear: bool = true
		while reach.has_point(along):
			if _other_than(own, along):
				clear = false
				break
			along += side * 8.0
		if clear:
			open += 1
	return open >= 2


## Whether nothing stands on a stud: the lattice's own answer
## (BrickLattice.standing_on, which shapes ask before a smooth top) for a stud
## square to the world, in the main body; for one in a turned section, whose
## square the lattice's world-square rooms do not fit, whether anything is
## where its tip reaches (OpenPoints).
func _nothing_on(point: OpenPoints.Point) -> bool:
	if not point.section.is_empty() or point.way.dot(Vector3.UP) < 0.99:
		return point.by == 0
	var stud := Vector2i(floori(point.at.x / STUD), floori(point.at.z / STUD))
	var top: int = roundi(point.at.y / BrickLattice.CELL)
	for other: Variant in assistant.builder.lattice.standing_on([stud], top,
			point.brick).values():
		if not assistant.scenery.has(int(other)):
			return false
	return point.by == 0


## Whether a brick of the model other than [param own] is at [param at].
func _other_than(own: int, at: Vector3) -> bool:
	var other: int = assistant.builder.lattice.brick_at(BrickLattice.to_cell(at))
	return other != 0 and other != own and not assistant.scenery.has(other)


## Whether a part's studs are ones a set finishes: a plain brick's, plate's,
## slope's, wedge's or wing's. A round plate, a jumper, a
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


## Whether all of a stud's square is part, a little under its top, in its own
## frame: a tile laid on a wedge's corner stud would overhang the edge.
func _whole_square(point: OpenPoints.Point) -> bool:
	var lattice: BrickLattice = assistant.builder.lattice
	var turn: Basis = _read.frame_of(point.brick).basis if _read != null else Basis.IDENTITY
	for corner: Vector2 in [Vector2(-6, -6), Vector2(6, -6), Vector2(-6, 6), Vector2(6, 6)]:
		var under: Vector3 = point.at + turn * Vector3(corner.x, -3.0, corner.y)
		if lattice.brick_at(BrickLattice.to_cell(under)) == 0:
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


## Whether the subject is a building: built of straight slopes first, and its
## roof and parapet keep their edges. Read off its name — the design's name
## from outside, the request's first sentence in the app's loop — and not its
## description, where a car's roof and windscreen are described.
func _straight_first() -> bool:
	var words: PackedStringArray = assistant._brief.get_slice(".", 0).to_lower().replace(
		",", " ").replace("-", " ").split(" ", false)
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
				ups, depth, links, claimed, gone, straight)
			if one != null:
				out.append(one)
	return out


## The parts that cover one staircase's risers, as a finding; null where none
## could be laid.
func _cover_staircase(feet: Array, d: Vector2i, perp: Vector2i, column: Dictionary,
		tops: Dictionary, rise_of: Dictionary, ups: Dictionary, depth: Dictionary,
		links: Dictionary, claimed: Dictionary, gone: Dictionary, straight: bool) -> Finding:
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
		_across(row, perp)
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
		if int(rise_of[row[0]]) > 1:
			steps[row_key.get_slice("|", 0)] = true
			rises[int(rise_of[row[0]])] = true
	# And the steps a plate high, which no slope is: two at a time.
	var laid_before: int = one.add.size()
	_cover_pairs(one, feet, d, perp, column, tops, rise_of, ups, depth, links, claimed,
		straight)
	if one.add.size() > laid_before:
		rises[1] = true
		for c: Vector2i in _pairs_laid:
			steps[str(c.x * absi(d.x) + c.y * absi(d.y))] = true
	if one.add.is_empty():
		return null
	var rise_words := PackedStringArray()
	for r: int in rises:
		rise_words.append({1: "a plate", 2: "two plates", 3: "a brick"}[r])
	var way: String = {Vector2i(0, 2): "+z", Vector2i(2, 0): "+x", Vector2i(0, -2): "-z",
		Vector2i(-2, 0): "-x"}[d]
	var tiled: bool = false
	for key: Vector3i in one.cells:
		tiled = tiled or (tops[key] as Dictionary).has("tile")
	one.said = "%d %s stepping up %s %d time%s by %s, %s." % [one.cells.size(),
		"tiled studs" if tiled else "studs", way, steps.size(), "" if steps.size() == 1 else "s",
		" or ".join(rise_words), _where_said(one.box)]
	one.studs = one.cells.size()
	one.laid = _pieces_said(one)
	one.seen_from = "far corner" if d.x > 0 or d.y > 0 else "corner"
	return one


## Feet in order across the way up.
static func _across(row: Array, perp: Vector2i) -> void:
	row.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x * perp.x + a.y * perp.y < b.x * perp.x + b.y * perp.y)


## The feet of the plate steps the last _cover_pairs laid a slope over, the
## upper of each pair with the lower.
var _pairs_laid: Array[Vector2i] = []


## The steps a plate high, covered two at a time. No slope is a plate tall,
## so the staircase cover passed them by, and they were what the judge named
## on every body: the starfighter's "nose steps down in layers", the car's
## "stepped edges where the wings and fastback should flow", the owl's "bands
## of tiles on the breast meet in hard steps". Up each run of them from the
## bottom, a pair of treads — the lower one and the one a plate over it,
## which rises a plate again at its far end — is laid as one slope two
## plates tall on the lower tread's studs, its high end flush with the tread
## two plates up: a curved slope two studs deep over two one-stud treads
## (15068, 11477, 88930 four across), 7302 three deep where one of them is
## two; straight first for a building. The upper tread's plate is taken off
## under the slope and the rest of it laid again in plates, as the crown
## cuts a top's tiles, and either tread's tiles come off. A lone step at the
## top of a run is left: its top may be crowned.
func _cover_pairs(one: Finding, feet: Array, d: Vector2i, perp: Vector2i, column: Dictionary,
		tops: Dictionary, rise_of: Dictionary, ups: Dictionary, depth: Dictionary,
		links: Dictionary, claimed: Dictionary, straight: bool) -> void:
	_pairs_laid = []
	# Pairs up each run of plate steps, from its bottom: lower foot -> upper.
	var on: Dictionary = {}
	for raw: Variant in feet:
		on[raw as Vector2i] = true
	var plate_step := func(c: Vector2i) -> bool:
		return on.has(c) and int(rise_of.get(c, 0)) == 1
	var below: Dictionary = {}
	for c: Vector2i in on:
		if plate_step.call(c) and links.has(c) and plate_step.call(links[c]):
			below[links[c]] = c
	var pairs: Dictionary = {}
	for c: Vector2i in on:
		if not plate_step.call(c) or below.has(c):
			continue
		var at: Vector2i = c
		while links.has(at) and plate_step.call(links[at]):
			var upper: Vector2i = links[at]
			pairs[at] = upper
			if not links.has(upper) or not plate_step.call(links[upper]):
				break
			at = links[upper]
	if pairs.is_empty():
		return
	# Rows of lower feet side by side, with the same treads.
	var rows: Dictionary = {}
	for c: Vector2i in pairs:
		var along: int = c.x * absi(d.x) + c.y * absi(d.y)
		var row_key: String = "%d|%d|%d|%d" % [along, (column[c] as Vector3i).y,
			mini(int(depth[c]), DEEPEST_TREAD + 1), (ups[c] as Array).size()]
		if not rows.has(row_key):
			rows[row_key] = []
		(rows[row_key] as Array).append(c)
	var fall := Vector2i(-d.x / 2, -d.y / 2)
	var used: Dictionary = {}
	# By the height each pair stands at: its cells, and the tiles and plates
	# cut there. A plate is cut only by the slopes at its own height: the
	# rest of the first pair's upper plate is under the second pair's treads.
	var levels: Dictionary = {}
	var slopes: Array = []
	var taken: Array[Vector2i] = []
	for row_key: String in rows:
		var row: Array = rows[row_key]
		_across(row, perp)
		var runs: Array = [[]]
		for raw: Variant in row:
			var c: Vector2i = raw
			var run: Array = runs[-1]
			if not run.is_empty() and c != (run[-1] as Vector2i) + perp:
				runs.append([])
			(runs[-1] as Array).append(c)
		var height: int = int(row_key.get_slice("|", 1))
		if not levels.has(height):
			levels[height] = [{}, {}, {}]
		var level: Array = levels[height]
		for run: Array in runs:
			for piece: Array in _pair_pieces(run, d, column, tops, depth, ups, claimed, used,
					straight, fall):
				slopes.append(piece[0])
				for c: Vector2i in piece[1]:
					(level[0] as Dictionary)[c] = true
					taken.append(c)
				for n: int in [2, 3]:
					for id: Variant in piece[n]:
						(level[n - 1] as Dictionary)[int(id)] = true
				for c: Vector2i in piece[4]:
					if not _pairs_laid.has(c):
						_pairs_laid.append(c)
	if slopes.is_empty():
		return
	# The tiles' rest stays a top, and is claimed; a plate's rest is under
	# the next treads, which the next pair stands on.
	var kept: Array = [one.remove.size(), one.restore.size(), one.add.size()]
	for height: int in levels:
		var level: Array = levels[height]
		var band: Dictionary = level[0]
		var tiles: Array[int] = []
		var plates: Array[int] = []
		for id: Variant in (level[1] as Dictionary):
			tiles.append(int(id))
		for id: Variant in (level[2] as Dictionary):
			plates.append(int(id))
		if not _cut(one, tiles, band, claimed) or not _cut(one, plates, band, {}):
			for id: int in one.remove.slice(int(kept[0])):
				_taken_off.erase(id)
			one.remove = one.remove.slice(0, int(kept[0]))
			one.restore = one.restore.slice(0, int(kept[1]))
			one.add = one.add.slice(0, int(kept[2]))
			_pairs_laid = []
			return
	one.add.append_array(slopes)
	_take(one, taken, column, tops, claimed)


## The slopes for one run of lower feet side by side, widest first: each
## [placement, its cells, the tiles under it, the plates it cuts, the feet
## it covers]. A piece is laid only where every cell is free, the upper
## tread is a plain plate a plate over the lower one, the slope was made in
## the colour, and it fits and is held with those parts off.
func _pair_pieces(run: Array, d: Vector2i, column: Dictionary, tops: Dictionary,
		depth: Dictionary, ups: Dictionary, claimed: Dictionary, used: Dictionary,
		straight: bool, fall: Vector2i) -> Array:
	var out: Array = []
	var c0: Vector2i = run[0]
	var upper: int = (ups[c0] as Array).size()
	var lower: int = int(depth[c0])
	var level: float = ((tops[column[c0]] as Dictionary)["at"] as Vector3).y
	# The lower tread whole where it is a step; one stud of it where it is a
	# floor, or where no slope is as deep as the two treads.
	var depths: Array[int] = [1]
	if lower > 1 and lower <= DEEPEST_TREAD:
		depths.push_front(lower)
	var n: int = 0
	while n < run.size():
		var laid: bool = false
		for back: int in depths:
			for option: Dictionary in _slopes_for(back + upper, 2, straight):
				var wide: int = int(option["w"])
				if n + wide > run.size():
					continue
				var cells: Array[Vector2i] = []
				var feet: Array[Vector2i] = []
				var treads: Array[Vector2i] = []
				for a: int in wide:
					var c: Vector2i = run[n + a]
					feet.append(c)
					feet.append((ups[c] as Array)[-1])
					for k: int in back:
						cells.append(c - d * k)
					for k: int in range(1, upper + 1):
						cells.append(c + d * k)
						treads.append(c + d * k)
				if not _free_cells(cells, column, claimed) \
						or cells.any(func(c: Vector2i) -> bool: return used.has(c)):
					continue
				var colour: int = int((tops[column[run[n]]] as Dictionary)["colour"])
				var info: PartLibrary.PartInfo = assistant.library.parts.get(str(option["id"]))
				if info == null or info.never_made_in(colour):
					continue
				var under: Array[int] = _plates_under(treads, column, tops, level)
				if under.is_empty():
					continue
				var tiles: Array[int] = _tiles_on(cells, column, tops)
				var skip: Dictionary = {}
				for id: int in tiles + under:
					skip[id] = true
				var placed: Dictionary = _at_cells(str(option["id"]), cells, level, colour,
					posmod(Shapes.OUT.find(fall) + int(option["turn"]), 4))
				if not _fits(placed, skip):
					continue
				for c: Vector2i in cells:
					used[c] = true
				out.append([placed, cells, tiles, under, feet])
				n += wide
				laid = true
				break
			if laid:
				break
		if not laid:
			n += 1
	return out


## The plates an upper tread stands on, by id: each a plain plate, a plate
## tall, laid square in the main body, its bottom at [param level] (the
## lower tread's studs), so taken off under a slope nothing but its own
## plate goes. Empty where any is not.
func _plates_under(treads: Array[Vector2i], column: Dictionary, tops: Dictionary,
		level: float) -> Array[int]:
	var out: Array[int] = []
	for c: Vector2i in treads:
		var top: Dictionary = tops[column[c]]
		var id: int = int(top["brick"])
		if out.has(id):
			continue
		var brick: BrickWorld.Brick = assistant.world.get_brick(id)
		var placement: Assistant.Placement = _read.by_id.get(id) if _read != null else null
		if brick == null or placement == null or placement.face != "up" \
				or not placement.section.is_empty():
			return []
		var info: PartLibrary.PartInfo = assistant.library.parts.get(brick.part_id)
		var mesh: Lbm.PartMesh = assistant.library.mesh_for(brick.part_id)
		if info == null or mesh == null or _plain(info) != "plate":
			return []
		var box: AABB = (brick.transform * mesh.bounds).abs()
		if absf(box.position.y - level) > 1.0 or absf(box.size.y - 12.0) > 1.0:
			return []
		out.append(id)
	return out


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
			# A tiled tread: its tiles come off first, the rest of each laid again.
			var tiles: Array[int] = _tiles_on(cells, column, tops)
			var skip: Dictionary = {}
			for id: int in tiles:
				skip[id] = true
			var placed: Dictionary = _slope_at(option, cells, column, tops, fall)
			if not _fits(placed, skip) or not _cut(one, tiles, _set_of(cells), claimed):
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
	if gone.has(brick_id) or not _free_to_take(one, brick_id):
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
	# The tiles on its tread come off with it.
	var tiles: Array[int] = _tiles_on(cells, column, tops)
	var skip: Dictionary = {brick_id: true}
	for id: int in tiles:
		skip[id] = true
	for placed: Variant in made:
		if not _fits(placed as Dictionary, skip):
			return false
	if not _cut(one, tiles, _set_of(cells), claimed):
		return false
	gone[brick_id] = true
	_taken_off[brick_id] = one
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
	var cells: Array[Vector2i] = []
	for c: Vector2i in free:
		cells.append(c)
	var tiles: Array[int] = _tiles_on(cells, column, tops)
	var skip: Dictionary = {}
	for id: int in tiles:
		skip[id] = true
	for placed: Variant in plates:
		if not _fits(placed as Dictionary, skip):
			return
	if not _cut(one, tiles, _set_of(cells), claimed):
		return
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
## [param bottom]; or plates, or tiles, given [param parts].
func _bricks_over(cells: Dictionary, bottom: float, colour: int,
		parts: Array = FILL_BRICKS) -> Array:
	var out: Array = []
	var options: Array = _rectangles(parts, colour)
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


## The tiles lying on these cells, by id.
static func _tiles_on(cells: Array[Vector2i], column: Dictionary, tops: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for c: Vector2i in cells:
		if not column.has(c):
			continue
		var top: Dictionary = tops[column[c]]
		if top.has("tile") and not out.has(int(top["tile"])):
			out.append(int(top["tile"]))
	return out


static func _set_of(cells: Array[Vector2i]) -> Dictionary:
	var out: Dictionary = {}
	for c: Vector2i in cells:
		out[c] = true
	return out


## The parts a finding of this reading takes off, by id: two findings may
## not take off the same one. The edges round's starfighter had a 4 x 8
## plate under a plate step on either side of its spine, each finding
## cutting it and laying its rest again over the other's slope: the edit of
## them all was refused for the overlap, and one at a time only four of
## twelve were laid before the time ran out.
var _taken_off: Dictionary = {}


func _free_to_take(one: Finding, id: int) -> bool:
	return not _taken_off.has(id) or _taken_off[id] == one


## Take plain parts off where a proposal goes ([param band]) and lay again
## what of each lay outside it, in parts of its own kind, height and colour, so
## nothing else of the model changes. False, and nothing taken, when one of
## them is not a plain tile, plate or brick laid square.
func _cut(one: Finding, ids: Array[int], band: Dictionary, claimed: Dictionary) -> bool:
	var plan: Array = []
	for id: int in ids:
		if one.remove.has(id):
			continue
		if not _free_to_take(one, id):
			return false
		var brick: BrickWorld.Brick = assistant.world.get_brick(id)
		var placement: Assistant.Placement = _read.by_id.get(id) if _read != null else null
		if brick == null or placement == null or placement.face != "up" \
				or not placement.section.is_empty():
			return false
		var info: PartLibrary.PartInfo = assistant.library.parts.get(brick.part_id)
		var mesh: Lbm.PartMesh = assistant.library.mesh_for(brick.part_id)
		var kind: String = _plain(info) if info != null else ""
		if mesh == null or kind.is_empty():
			return false
		var box: AABB = (brick.transform * mesh.bounds).abs()
		var rest: Dictionary = {}
		for c: Vector2i in _cells_of(box):
			if not band.has(c):
				rest[c] = true
		plan.append([id, placement, box.position.y, brick.color_code, kind, rest])
	for step: Array in plan:
		_taken_off[int(step[0])] = one
		one.remove.append(int(step[0]))
		one.restore.append(_as_dict(step[1] as Assistant.Placement))
		var rest: Dictionary = step[5]
		for c: Variant in rest.keys():
			claimed[c] = true
		one.add.append_array(_bricks_over(rest, float(step[2]), int(step[3]),
			{"tile": TILES, "plate": PLATES, "brick": FILL_BRICKS}[str(step[4])]))
	return true


# -- hard edges ---------------------------------------------------------------


## The hard top edges of a body, crowned: where a flat top (studs or tiles)
## ends at a face that drops away, curved slopes along that edge falling
## outward, and the rest of the top raised flush with them, a plate and a
## tile; the top's own tiles come off first. Nothing under the top is touched,
## so whatever ties the body together still does. "The head is a hard-edged
## cube", "square corners ... no curved slopes": the judge, on every body built
## here. Not for a building, whose roof and parapet keep their edges, nor for
## the ground.
func _edges(levels: Dictionary, claimed: Dictionary) -> Array[Finding]:
	var out: Array[Finding] = []
	var cell_key: Dictionary = {}
	for key: Vector3i in levels:
		var c := Vector2i(key.x, key.z)
		if not claimed.has(c):
			cell_key[c] = key
	var model_box: AABB = assistant._bounds_of(assistant._bricks_inside({}))
	var living: Array = _living_boxes()
	var curves: Array = []
	for id: String in EDGE_SLOPES:
		var shape: Dictionary = Shapes.part(assistant.library, id)
		if not shape.is_empty() and int(shape["h"]) == 2 and int(shape["d"]) == 2:
			curves.append(shape)
	curves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["w"]) > int(b["w"]))
	if curves.is_empty():
		return out
	var seen: Dictionary = {}
	for start: Vector2i in cell_key:
		if seen.has(start):
			continue
		var top: float = float((levels[cell_key[start]] as Dictionary)["top"])
		var field: Dictionary = {}
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			field[c] = true
			for step: Vector2i in WAYS:
				var next: Vector2i = c + step
				if cell_key.has(next) and not seen.has(next) and absf(float(
						(levels[cell_key[next]] as Dictionary)["top"]) - top) < 1.0:
					seen[next] = true
					queue.append(next)
		if field.size() < 2 * SMALLEST_FIELD:
			continue
		var keys: Array[Vector3i] = []
		for c: Variant in field:
			keys.append(cell_key[c])
		var box: AABB = _box_of(keys, levels)
		if _ground(box, model_box) or _lived_on(box, living):
			continue
		var one: Finding = _crown(field, cell_key, levels, curves, claimed)
		if one != null:
			out.append(one)
	return out


## Crown one flat top: its edges that drop away found and sloped, the rest
## raised flush. Null where no edge can be, or something does not fit.
func _crown(field: Dictionary, cell_key: Dictionary, levels: Dictionary, curves: Array,
		claimed: Dictionary) -> Finding:
	var first: Dictionary = levels[cell_key[field.keys()[0]]]
	var base: float = (first["at"] as Vector3).y
	var counts: Dictionary = {}
	for c: Variant in field:
		var colour: int = int((levels[cell_key[c]] as Dictionary)["colour"])
		counts[colour] = int(counts.get(colour, 0)) + 1
	var colour: int = int(first["colour"])
	for code: Variant in counts:
		if int(counts[code]) > int(counts[colour]):
			colour = int(code)
	var band: Dictionary = {}
	var slopes: Array = []
	var ways := PackedStringArray()
	for d: Vector2i in WAYS:
		var perp := Vector2i(absi(d.y), absi(d.x))
		var fall := Vector2i(d.x / 2, d.y / 2)
		# The edge's cells whose two studs in are the top's and not sloped yet,
		# and whose outside is clear beside a slope and drops below it.
		var ready: Array[Vector2i] = []
		for c: Variant in field:
			var cell: Vector2i = c
			if field.has(cell + d) or not field.has(cell - d) or band.has(cell) \
					or band.has(cell - d):
				continue
			var clear: bool = true
			for y: float in [base - 4.0, base + 4.0, base + 12.0]:
				clear = clear and not _other_than(0, Vector3((cell + d).x * 10.0, y,
					(cell + d).y * 10.0))
			if clear:
				ready.append(cell)
		ready.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x * perp.x + a.y * perp.y < b.x * perp.x + b.y * perp.y)
		var n: int = 0
		var sloped: bool = false
		while n < ready.size():
			var laid: bool = false
			for shape: Dictionary in curves:
				var wide: int = int(shape["w"])
				if n + wide > ready.size() or ready[n + wide - 1] != ready[n] + perp * (wide - 1):
					continue
				# A run of one is a corner's end, not an edge.
				var alone: bool = wide == 1 and (n == 0 or ready[n - 1] != ready[n] - perp) \
					and (n + 1 >= ready.size() or ready[n + 1] != ready[n] + perp)
				if alone:
					continue
				var span: Array[Vector2i] = []
				for a: int in wide:
					span.append(ready[n + a])
					span.append(ready[n + a] - d)
				for cell: Vector2i in span:
					band[cell] = true
				slopes.append(_at_cells(str(shape["id"]), span, base, colour,
					posmod(Shapes.OUT.find(fall) + int(shape["turn"]), 4)))
				n += wide
				laid = true
				sloped = true
				break
			if not laid:
				n += 1
		if sloped:
			ways.append({Vector2i(0, 2): "+z", Vector2i(2, 0): "+x", Vector2i(0, -2): "-z",
				Vector2i(-2, 0): "-x"}[d])
	if slopes.is_empty():
		return null
	var inner: Dictionary = {}
	for c: Variant in field:
		if not band.has(c):
			inner[c] = true
	var plates: Array = _bricks_over(inner.duplicate(), base, colour, PLATES)
	var tiles: Array = _bricks_over(inner.duplicate(), base + PLATE, colour, TILES)
	var cells: Array[Vector2i] = []
	for c: Variant in field:
		cells.append(c as Vector2i)
	var column: Dictionary = {}
	for c: Vector2i in cells:
		column[c] = cell_key[c]
	var old: Array[int] = _tiles_on(cells, column, levels)
	var skip: Dictionary = {}
	for id: int in old:
		skip[id] = true
	for placed: Variant in slopes + plates:
		if not _fits(placed as Dictionary, skip):
			return null
	for placed: Variant in tiles:
		if not _fits(placed as Dictionary, skip, plates):
			return null
	var one := Finding.new()
	one.kind = "edge"
	if not _cut(one, old, field, claimed):
		return null
	one.add.append_array(slopes)
	one.add.append_array(plates)
	one.add.append_array(tiles)
	_take(one, cells, column, levels, claimed)
	one.studs = cells.size()
	one.said = "a top of %d %s, %s, its hard edge%s on the %s side%s %s." % [cells.size(),
		"tiles' studs" if not old.is_empty() else "studs", _where_said(one.box),
		"" if ways.size() == 1 else "s", ", ".join(ways), "" if ways.size() == 1 else "s",
		"curved over, the rest raised flush with a plate and tiles"]
	one.laid = _pieces_said(one)
	return one


# -- stud fields ---------------------------------------------------------------


## The open stud fields left, each at one height and joined stud to stud:
## tiles for each that is not a yard, the ground offered, small ones left.
func _fields(tops: Dictionary, claimed: Dictionary, section: String = "") -> Array[Finding]:
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
		one.section = section
		one.cells = field
		one.box = box
		one.studs = field.size()
		var free: Dictionary = {}
		var colours: Dictionary = {}
		for key: Vector3i in field:
			var top: Dictionary = tops[key]
			free[Vector2i(key.x, key.z)] = [top["here"], int(top["colour"])]
			colours[int(top["colour"])] = true
		var y: float = ((tops[field[0]] as Dictionary)["here"] as Vector3).y
		one.offered = section.is_empty() and _ground(box, model_box)
		var accents: int = 0
		if field.size() >= ACCENTS_FROM and not one.offered:
			accents = 1 if field.size() < 40 else (2 if field.size() < 80 else 3)
		var made: Array[int] = []
		one.add = _tiles_over(free, y, accents, made, true, TILES, section)
		one.accents = made
		if one.add.is_empty():
			continue
		var names := PackedStringArray()
		for code: int in colours:
			names.append(assistant._colour_name(code).to_lower())
		var across: int = roundi(box.size.x / STUD)
		var deep: int = roundi(box.size.z / STUD)
		one.said = "%s, %d open stud%s in %s, %d x %d studs %s%s." % [
			"the ground, a floor things will stand on" if one.offered else _what_top(box, model_box),
			field.size(), "" if field.size() == 1 else "s", ", ".join(names), across, deep,
			_where_said(box), "" if section.is_empty() else ", in section '%s'" % section]
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
		test: bool, parts: Array = TILES, section: String = "") -> Array:
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
			var placed: Dictionary = _tile_at(id, span, free, y, colour, rot, section)
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
				int(option[3]), section)
			if test and not _fits(placed, {}):
				continue
			for one: Vector2i in span:
				free.erase(one)
			out.append(placed)
			break
	return out


func _tile_at(id: String, span: Array[Vector2i], free: Dictionary, y: float, colour: int,
		rot: int, section: String = "") -> Dictionary:
	var low := Vector2(INF, INF)
	for c: Vector2i in span:
		var at: Vector3 = (free[c] as Array)[0]
		low = Vector2(minf(low.x, at.x), minf(low.y, at.z))
	var placed: Dictionary = {"part": id, "color": colour,
		"x": snappedf(low.x / STUD - 0.5, 0.05), "y": snappedf(y / PLATE, 0.25),
		"z": snappedf(low.y / STUD - 0.5, 0.05), "rot": rot}
	if not section.is_empty():
		placed["section"] = section
	return placed


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
	# Masonry only: a building's wall with studs turned out of it in a
	# scatter read to the judge as "odd studs and stud-up knobs" "in clumps".
	var change: Dictionary = assistant._restyle({"where": where, "turned_out": false,
		"masonry": 0.35})
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


# -- flanks --------------------------------------------------------------------


## Bricks with studs on one long side, by how many studs: a course of them
## turns the studs of a flank out.
const SIDE_STUDS: Dictionary = {1: "87087", 2: "11211", 4: "30414"}
## The plain one-wide bricks a flank's course is read in, by length, and the
## two-wide ones, whose outer row is a one-wide brick's.
const FLANK_ONE_WIDE: Dictionary = {"3005": 1, "3004": 2, "3622": 3, "3010": 4, "3009": 6,
	"3008": 8}
const FLANK_TWO_WIDE: Dictionary = {"3003": 2, "3002": 3, "3001": 4, "2456": 6, "3007": 8}
const ONE_WIDE_BRICK: Dictionary = {1: "3005", 2: "3004", 3: "3622", 4: "3010", 6: "3009",
	8: "3008"}
## What a skin is laid in on its side, two studs tall, by how long: plates on
## the side studs and tiles on the plates, and at each end a curved slope
## falling away to it, as tall as the plate and tile.
const SKIN_PLATES: Dictionary = {4: "3020", 3: "3021", 2: "3022", 1: "3023b"}
const SKIN_TILES: Dictionary = {4: "87079", 3: "26603", 2: "3068b", 1: "3069b"}
const SKIN_END := "15068"
## And a row's tiles alone, one stud tall, where the two rows of a skin are
## in two colours.
const ROW_TILES: Dictionary = {4: "2431", 3: "63864", 2: "3069b", 1: "3070b"}
## The shortest run of a course a skin is laid on, in studs: a curved slope
## at each end.
const SHORTEST_SKIN := 4


## The flanks of a body that is not a building: a wall of plain bricks,
## stacked, open to the air, each course of it a skin can be laid on — studs
## turned out of the course and a skin two studs tall on them, over the
## course above it too: plates and tiles laid on their side, and at each end
## a curved slope falling away to it, following the body's line. "The flanks
## and tail are walls of stacked plain bricks with visible seams" (the car),
## "the hull sides are flat slab walls" (the starfighter): the judge, of every
## body whose sides were built by hand. A run is skinned only where the face
## above its course is flush with it, so the skin lies on the body, and
## nothing stands within a plate and tile of it; courses are tried from the
## top down, the next skin two courses under the last.
func _flanks(gone: Dictionary) -> Array[Finding]:
	var out: Array[Finding] = []
	var model: Assistant.Model = assistant._model_from_world()
	var middle := Vector3.ZERO
	var standing: Array[BrickWorld.Brick] = assistant._bricks_inside({})
	for brick: BrickWorld.Brick in standing:
		middle += brick.transform.origin
	if not standing.is_empty():
		middle /= float(standing.size())
	# Every outer row of a plain brick with a long face open, by the face it
	# is in and its course.
	var faces: Dictionary = {}
	for placement: Assistant.Placement in model.placements:
		if gone.has(placement.id) or placement.face != "up" or not placement.section.is_empty() \
				or _in_zone(Vector3(placement.x * STUD, placement.y * PLATE, placement.z * STUD)):
			continue
		var long: int = int(FLANK_ONE_WIDE.get(placement.part,
			FLANK_TWO_WIDE.get(placement.part, 0)))
		if long == 0:
			continue
		var tint: PartLibrary.BrickColor = assistant.library.color(placement.color)
		if tint != null and tint.is_transparent():
			continue
		var along_x: bool = placement.rot % 2 == 0
		var two: bool = FLANK_TWO_WIDE.has(placement.part)
		for half: int in (2 if two else 1):
			var row := Assistant.Placement.from_dict({"part": ONE_WIDE_BRICK[long],
				"color": placement.color, "x": placement.x + (half if two and not along_x else 0),
				"y": placement.y, "z": placement.z + (half if two and along_x else 0),
				"rot": placement.rot})
			var facing: String = assistant._open_side(row, long, along_x, middle)
			if facing.is_empty():
				continue
			var depth: float = row.z if along_x else row.x
			var key: String = "%s|%s" % [facing, snappedf(depth, 0.5)]
			if not faces.has(key):
				faces[key] = {}
			var courses: Dictionary = faces[key]
			var course: float = snappedf(placement.y, 0.25)
			if not courses.has(course):
				courses[course] = []
			(courses[course] as Array).append({"placement": placement, "long": long,
				"along": row.x if along_x else row.z, "depth": depth, "facing": facing,
				"along_x": along_x, "inner": {} if not two else {"part": ONE_WIDE_BRICK[long],
					"color": placement.color, "x": placement.x + (1 - half if not along_x else 0),
					"y": placement.y, "z": placement.z + (1 - half if along_x else 0),
					"rot": placement.rot}})
	var taken: Dictionary = {}
	for key: String in faces:
		var courses: Dictionary = faces[key]
		# A flank is stacked: two courses of it at least.
		if courses.size() < 2:
			continue
		var heights: Array = courses.keys()
		heights.sort()
		heights.reverse()
		var skinned: Array = []    ## [low along, high along, bottom, top] in studs, LDU
		for course: Variant in heights:
			var row: Array = courses[course]
			row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a["along"]) < float(b["along"]))
			for run: Array in _flank_runs(row, taken, skinned, float(course)):
				var one: Finding = _skin(run, float(course))
				if one == null:
					continue
				for entry: Dictionary in run:
					taken[(entry["placement"] as Assistant.Placement).id] = true
				skinned.append([float(run[0]["along"]), float(run[-1]["along"])
					+ int(run[-1]["long"]), float(course) * PLATE + 4.0,
					float(course) * PLATE + 44.0])
				out.append(one)
	return out


## The runs of a course a skin can be laid on: bricks joined end to end,
## none taken by another skin, each stud of them clear in front for a plate
## and a tile and flush behind over the course above, at least
## SHORTEST_SKIN long, and not overlapping a skin laid above.
func _flank_runs(row: Array, taken: Dictionary, skinned: Array, course: float) -> Array:
	var out: Array = []
	var run: Array = []
	var flush := func(entry: Dictionary) -> bool:
		var id: int = (entry["placement"] as Assistant.Placement).id
		if taken.has(id) or _taken_off.has(id):
			return false
		var bottom: float = course * PLATE
		for raw: Variant in skinned:
			var skin: Array = raw
			if float(entry["along"]) < float(skin[1]) \
					and float(entry["along"]) + int(entry["long"]) > float(skin[0]) \
					and bottom + 44.0 > float(skin[2]) and bottom + 4.0 < float(skin[3]):
				return false
		for step: int in int(entry["long"]):
			if not _skin_room(entry, float(entry["along"]) + step, bottom):
				return false
		return true
	for entry: Dictionary in row:
		var ok: bool = flush.call(entry)
		var joined: bool = not run.is_empty() and absf(float(run[-1]["along"])
			+ int(run[-1]["long"]) - float(entry["along"])) < 0.05
		if not ok or not joined:
			if _run_long(run) >= SHORTEST_SKIN:
				out.append(run)
			run = []
		if ok:
			run.append(entry)
	if _run_long(run) >= SHORTEST_SKIN:
		out.append(run)
	return out


static func _run_long(run: Array) -> int:
	var long: int = 0
	for entry: Dictionary in run:
		long += int(entry["long"])
	return long


## Whether one stud of a course's face, [param along] studs along, has room
## for a skin: nothing of the model within a plate and a tile in front of it,
## from half a plate over the course's bottom to five plates over it, and
## the model just behind the face over the course above.
func _skin_room(entry: Dictionary, along: float, bottom: float) -> bool:
	var facing: String = entry["facing"]
	var along_x: bool = entry["along_x"]
	var out: Vector3 = Assistant.FACES[facing]
	var face: float = (float(entry["depth"]) + (1.0 if facing.begins_with("+") else 0.0)) * STUD
	var at := func(a: float, up: float, off: float) -> Vector3:
		var across: float = face + off
		return Vector3(a, up, across) if along_x else Vector3(across, up, a)
	var sign: float = out.x + out.z
	for side: float in [-6.0, 6.0]:
		var a: float = (along + 0.5) * STUD + side
		# And nothing just under it in front: a ledge's studs are tiled, a
		# plate up into the skin's first half plate.
		for up: float in [-2.0, 6.0, 14.0, 22.0, 30.0, 38.0, 42.0]:
			for off: float in [2.0, 7.0, 12.0, 15.0]:
				if _other_than(0, at.call(a, bottom + up, sign * off)):
					return false
		for up: float in [28.0, 36.0, 42.0]:
			if assistant.builder.lattice.brick_at(BrickLattice.to_cell(
					at.call(a, bottom + up, -sign * 2.0))) == 0:
				return false
	return true


## One run's skin, as a finding: its bricks laid again with their studs
## turned out (a two-wide brick's inner row as a plain brick), and on those
## studs a curved slope at each end and plates and tiles between, on their
## side. Null where any of it does not fit or is not held.
func _skin(run: Array, course: float) -> Finding:
	var first: Dictionary = run[0]
	var facing: String = first["facing"]
	var along_x: bool = first["along_x"]
	var out: Vector3 = Assistant.FACES[facing]
	var along_way: Vector3 = Vector3.RIGHT if along_x else Vector3.BACK
	var colours: Dictionary = {}
	for entry: Dictionary in run:
		var code: int = (entry["placement"] as Assistant.Placement).color
		colours[code] = int(colours.get(code, 0)) + int(entry["long"])
	var colour: int = -1
	for code: int in colours:
		if colour < 0 or int(colours[code]) > int(colours[colour]):
			colour = code
	var skip: Dictionary = {}
	for entry: Dictionary in run:
		skip[(entry["placement"] as Assistant.Placement).id] = true
	# The course again, its studs turned out.
	var bricks: Array = []
	var inner: Array = []
	var studs: Array[Vector3] = []
	## The colour of the face behind each row of the skin, by where along:
	## the course's own under the lower row, the face over it under the
	## upper. A tile two studs tall in one colour over a course and the one
	## above painted out the starfighter's stripe; each row keeps its own.
	var lower: Dictionary = {}
	for entry: Dictionary in run:
		var placement: Assistant.Placement = entry["placement"]
		var left: int = int(entry["long"])
		var at: float = float(entry["along"])
		while left > 0:
			var long: int = 4 if left >= 4 else (2 if left >= 2 else 1)
			var turned: Array = _turned_out(SIDE_STUDS[long], placement.color, at, course,
				float(entry["depth"]), along_x, long, out)
			if turned.is_empty():
				return null
			bricks.append(turned[0])
			studs.append_array(turned[1] as Array)
			for stud: Variant in turned[1]:
				lower[snappedf((stud as Vector3).dot(along_way), 1.0)] = placement.color
			at += long
			left -= long
		if not (entry["inner"] as Dictionary).is_empty():
			inner.append(entry["inner"])
	for placed: Variant in bricks + inner:
		if not _fits(placed as Dictionary, skip):
			return null
	studs.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.dot(along_way) < b.dot(along_way))
	var long: int = studs.size()
	var colours_of: Array = []    ## [lower, upper] at each stud along
	var sign: float = out.x + out.z
	for stud: Vector3 in studs:
		var below: int = int(lower.get(snappedf(stud.dot(along_way), 1.0), colour))
		var behind: Vector3 = stud - out * 2.0
		behind.y = course * PLATE + 34.0
		var id: int = assistant.builder.lattice.brick_at(BrickLattice.to_cell(behind))
		var over: BrickWorld.Brick = assistant.world.get_brick(id) if id != 0 else null
		colours_of.append([below, over.color_code if over != null else below])
	# The skin on them: a curved slope at each end in the course's colour,
	# plates and tiles between.
	var ends: bool = long >= SHORTEST_SKIN \
		and not _never_made(SKIN_END, int(colours_of[0][0])) \
		and not _never_made(SKIN_END, int(colours_of[long - 1][0]))
	var pieces: Array = []
	var plates: Array = []
	var n: int = 0
	if ends:
		var low: Dictionary = _onto_side(SKIN_END, int(colours_of[0][0]), studs.slice(0, 2),
			facing, -along_way)
		var high: Dictionary = _onto_side(SKIN_END, int(colours_of[long - 1][0]),
			studs.slice(long - 2, long), facing, along_way)
		if low.is_empty() or high.is_empty():
			ends = false
		else:
			pieces.append(low)
			pieces.append(high)
			n = 2
	var stop: int = long - 2 if ends else long
	var plate_studs: Array = []    ## [stud, row 0 or 1, index along]
	var first_row: float = INF
	while n < stop:
		var part: int = mini(4, stop - n)
		var plate: Dictionary = _onto_side(SKIN_PLATES[part], colour, studs.slice(n, n + part),
			facing)
		if plate.is_empty():
			return null
		plates.append(plate)
		for stud: Vector3 in _studs_of(plate, out):
			first_row = minf(first_row, stud.y)
			plate_studs.append([stud, 0, n + roundi((stud.dot(along_way)
				- studs[n].dot(along_way)) / STUD)])
		n += part
	for one: Array in plate_studs:
		one[1] = 0 if (one[0] as Vector3).y < first_row + 1.0 else 1
	# Tiles on the plates: two studs tall where both rows are one colour,
	# a row at a time where they are not.
	var at: int = 2 if ends else 0
	while at < stop:
		var pair: Array = colours_of[at]
		var to: int = at
		while to < stop and (colours_of[to] as Array) == pair and to - at < 4:
			to += 1
		var rows: Array = [[0, 1]] if int(pair[0]) == int(pair[1]) else [[0], [1]]
		for wanted: Array in rows:
			var tone: int = int(pair[wanted[0]])
			var targets: Array[Vector3] = []
			for one: Array in plate_studs:
				if wanted.has(int(one[1])) and int(one[2]) >= at and int(one[2]) < to:
					targets.append(one[0])
			var size: int = to - at
			var id: String = SKIN_TILES[size] if wanted.size() == 2 else ROW_TILES[size]
			if _never_made(id, tone):
				return null
			var tile: Dictionary = _onto_side(id, tone, targets, facing)
			if tile.is_empty():
				return null
			pieces.append(tile)
		at = to
	for placed: Variant in plates:
		if not _fits(placed as Dictionary, skip, bricks + inner):
			return null
	for placed: Variant in pieces:
		if not _fits(placed as Dictionary, skip, bricks + inner + plates):
			return null
	var one := Finding.new()
	one.kind = "flank"
	for entry: Dictionary in run:
		var placement: Assistant.Placement = entry["placement"]
		if one.remove.has(placement.id):
			continue
		_taken_off[placement.id] = one
		one.remove.append(placement.id)
		one.restore.append(_as_dict(placement))
	one.add = bricks + inner + plates + pieces
	one.studs = long
	var from: float = float(first["along"])
	var face: float = (float(first["depth"]) + (1.0 if facing.begins_with("+") else 0.0)) * STUD
	var low := Vector3(from * STUD, course * PLATE + 4.0, face)
	var size := Vector3(long * STUD, 40.0, 16.0)
	if not along_x:
		low = Vector3(face, low.y, from * STUD)
		size = Vector3(16.0, 40.0, long * STUD)
	if facing.begins_with("-"):
		if along_x:
			low.z -= 16.0
		else:
			low.x -= 16.0
	one.box = AABB(low, size)
	one.said = "the %s flank, a course of %d plain brick%s in %s %s and the face over it, " % [
		facing, run.size(), "" if run.size() == 1 else "s",
		assistant._colour_name(colour).to_lower(), _where_said(one.box)] \
		+ "skinned on its side: studs turned out of the course, %s." % (
			"curved slopes at both ends and plates and tiles between" if ends
			else "plates and tiles on them")
	one.laid = _pieces_said(one)
	one.seen_from = "corner" if facing.begins_with("+") else "far corner"
	return one


func _never_made(id: String, colour: int) -> bool:
	var info: PartLibrary.PartInfo = assistant.library.parts.get(id)
	return info == null or assistant.library.mesh_for(id) == null or info.never_made_in(colour)


## A brick with studs on its side, [param long] studs, laid where a run's
## brick was ([param along] studs along, in course [param course], one-wide
## row [param depth]) and turned so its studs point [param out]:
## [placement, its side studs in the world], or [] where no turn does.
func _turned_out(id: String, colour: int, along: float, course: float, depth: float,
		along_x: bool, long: int, out: Vector3) -> Array:
	var mesh: Lbm.PartMesh = assistant.library.mesh_for(id)
	if mesh == null:
		return []
	for rot: int in 4:
		var placed: Dictionary = {"part": id, "color": colour,
			"x": along if along_x else depth, "y": course, "z": depth if along_x else along,
			"rot": rot}
		var at: Transform3D = assistant._transform(Assistant.Placement.from_dict(placed), mesh)
		var box: AABB = (at * mesh.bounds).abs()
		var size_along: float = box.size.x if along_x else box.size.z
		if absf(size_along - long * STUD) > 2.0:
			continue
		var studs: Array[Vector3] = []
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "stud" and connector.gender == "male" \
					and (at.basis * connector.axis).normalized().dot(out) > 0.9:
				studs.append(at * connector.position)
		if studs.size() == long:
			return [placed, studs]
	return []


## The studs of a part laid as [param placed] that point [param out], in the
## world.
func _studs_of(placed: Dictionary, out: Vector3) -> Array[Vector3]:
	var found: Array[Vector3] = []
	var mesh: Lbm.PartMesh = assistant.library.mesh_for(str(placed["part"]))
	if mesh == null:
		return found
	var at: Transform3D = assistant._transform(Assistant.Placement.from_dict(placed), mesh)
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind == "stud" and connector.gender == "male" \
				and (at.basis * connector.axis).normalized().dot(out) > 0.9:
			found.append(at * connector.position)
	return found


## A part laid on its side facing [param facing], turned and placed so the
## stud squares of its underside take [param studs] — those of its lowest
## row, the rest of it over them, never under — and, for a slope, falling
## toward [param fall]: a placement, or {} where no turn does. The same
## arithmetic Assistant._panel lays a shape's tiles with.
func _onto_side(id: String, colour: int, studs: Array[Vector3], facing: String,
		fall: Vector3 = Vector3.ZERO) -> Dictionary:
	var mesh: Lbm.PartMesh = assistant.library.mesh_for(id)
	var info: PartLibrary.PartInfo = assistant.library.parts.get(id)
	if mesh == null or info == null or studs.is_empty():
		return {}
	var foot: Vector2i = info.footprint_studs()
	var b: AABB = mesh.bounds
	var under: Array[Vector3] = []
	for i: int in foot.x:
		for k: int in foot.y:
			under.append(Vector3(b.position.x + 10.0 + 20.0 * i, b.position.y,
				b.position.z + 10.0 + 20.0 * k))
	var lowest: float = INF
	for point: Vector3 in studs:
		lowest = minf(lowest, point.y)
	var falls := Vector3.ZERO
	if fall != Vector3.ZERO:
		var shape: Dictionary = Shapes.part(assistant.library, id)
		if shape.is_empty():
			return {}
		falls = [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1),
			Vector3(-1, 0, 0)][posmod(-int(shape["turn"]), 4)]
	for rot: int in 4:
		var basis: Basis = BrickLattice.basis_for(facing, rot)
		if falls != Vector3.ZERO and (basis * falls).dot(fall) < 0.9:
			continue
		var turned: Array[Vector3] = []
		for point: Vector3 in under:
			turned.append(basis * point)
		for first: Vector3 in turned:
			var origin: Vector3 = studs[0] - first
			var all_on: bool = true
			for point: Vector3 in studs:
				var on: bool = false
				for other: Vector3 in turned:
					if (origin + other - point).length() < 1.0:
						on = true
						break
				if not on:
					all_on = false
					break
			if not all_on:
				continue
			var down: bool = false
			for other: Vector3 in turned:
				down = down or (origin + other).y < lowest - 1.0
			if down:
				continue
			var corner: Vector3 = origin + BrickLattice.to_ldu(assistant._corner_cell(mesh, id,
				basis))
			return {"part": id, "color": colour, "x": snappedf(corner.x / STUD, 0.1),
				"y": snappedf(corner.y / PLATE, 0.25), "z": snappedf(corner.z / STUD, 0.1),
				"face": facing, "rot": rot}
	return {}


# -- laying --------------------------------------------------------------------


var _why_not: String = ""


## Lay every finding in one edit, checked once, after checking again that
## each one's studs are still open. A check of a model with sections is most of
## a minute: laid one finding at a time, a review of the starfighter took six,
## past the three minutes a session's call may take. One at a time only when
## the edit as a whole is refused, so one bad finding costs only itself.
func _lay_all(these: Array[Finding], until: int) -> Array[Finding]:
	var ready: Array[Finding] = []
	_read = OpenPoints.read(assistant)
	var points: Array = _points()
	var now: Dictionary = {}
	for one: Finding in these:
		_why_not = _not_ready(one, now, points)
		if _why_not.is_empty():
			ready.append(one)
		else:
			_could_not(one)
	var add: Array = []
	var remove: Array[int] = []
	for one: Finding in ready:
		add.append_array(one.add)
		remove.append_array(one.remove)
	await _keep_pieces(not remove.is_empty())
	var out: Array[Finding] = []
	if ready.size() > 1:
		var ids: Array[int] = await _edit(add, remove)
		if not ids.is_empty():
			_share_out(ready, ids)
			out = ready
			ready = []
	for one: Finding in ready:
		if Time.get_ticks_msec() > until:
			more += 1
			continue
		var ids: Array[int] = await _edit(one.add, one.remove)
		if ids.is_empty():
			_could_not(one)
			continue
		one.ids = ids
		_boxed(one)
		out.append(one)
	assistant._keep_pieces = -1
	return out


## Where a proposal takes parts off, the pieces the model is in now, which
## edit_model then keeps to: a step brick or a wall brick laid again in smaller
## parts may have been what held two others together. Read only when it is
## needed: a check of a model with sections is most of a minute.
func _keep_pieces(taking_off: bool) -> void:
	assistant._keep_pieces = -1
	if not taking_off:
		return
	var report: Dictionary = await assistant._checked(assistant._model_from_world(), true)
	assistant._keep_pieces = int(report.get("pieces", 0))


## Lay one finding (ground offered, tiled when asked), checked open first.
func _lay(one: Finding) -> bool:
	_read = OpenPoints.read(assistant)
	_why_not = _not_ready(one, {}, _points())
	if not _why_not.is_empty():
		return false
	await _keep_pieces(not one.remove.is_empty())
	var ids: Array[int] = await _edit(one.add, one.remove)
	assistant._keep_pieces = -1
	if ids.is_empty():
		return false
	one.ids = ids
	_boxed(one)
	return true


## Why a finding cannot be laid now, or "": its studs must all still be open
## (anything may stand on them since it was found) and what it lays again must
## still stand. [param now] keeps each frame's open studs, read once.
func _not_ready(one: Finding, now: Dictionary, points: Array) -> String:
	if not one.cells.is_empty():
		if not now.has(one.section):
			var tops: Dictionary = open_tops(one.section, points)
			if one.section.is_empty():
				tops.merge(tile_tops())
			now[one.section] = tops
		var open: Dictionary = now[one.section]
		for key: Vector3i in one.cells:
			if not open.has(key):
				return "something stands on its studs now"
	for id: int in one.remove:
		if assistant.world.get_brick(id) == null:
			return "a brick it lays again has gone"
	return ""


func _could_not(one: Finding) -> void:
	left_alone.append("a %s at %s, which could not be laid as it stands: %s"
		% [one.kind, _where_said(one.box), _why_not])


## The box of what was laid, for the picture's mark.
func _boxed(one: Finding) -> void:
	if one.kind == "wall" or one.ids.is_empty():
		return
	var laid: AABB = assistant._bounds_of(_bricks(one.ids))
	one.box = one.box.merge(laid) if one.box.has_volume() else laid


## The bricks one edit laid, given back to the findings they were laid for:
## by part, frame and place as the model reads them back, and anything left
## over to the finding nearest it.
func _share_out(ready: Array[Finding], ids: Array[int]) -> void:
	var wanted: Dictionary = {}
	for id: int in ids:
		wanted[id] = true
	var fresh: Dictionary = {}
	for placement: Assistant.Placement in assistant._model_from_world().placements:
		if wanted.has(placement.id):
			var mark: String = _signature(placement.part, placement.section, placement.x,
				placement.y, placement.z)
			if not fresh.has(mark):
				fresh[mark] = []
			(fresh[mark] as Array).append(placement.id)
	var left: Dictionary = wanted.duplicate()
	for one: Finding in ready:
		one.ids = []
		for raw: Variant in one.add:
			var placed: Dictionary = raw
			var mark: String = _signature(str(placed["part"]), str(placed.get("section", "")),
				float(placed["x"]), float(placed["y"]), float(placed["z"]))
			var list: Array = fresh.get(mark, [])
			if not list.is_empty():
				var id: int = int(list.pop_front())
				one.ids.append(id)
				left.erase(id)
	for raw: Variant in left.keys():
		var brick: BrickWorld.Brick = assistant.world.get_brick(int(raw))
		if brick == null:
			continue
		var nearest: Finding = ready[0]
		for one: Finding in ready:
			if one.box.get_center().distance_to(brick.transform.origin) \
					< nearest.box.get_center().distance_to(brick.transform.origin):
				nearest = one
		nearest.ids.append(int(raw))
	for one: Finding in ready:
		_boxed(one)


static func _signature(part: String, section: String, x: float, y: float, z: float) -> String:
	return "%s|%s|%s|%s|%s" % [part, section, snappedf(x, 0.1), snappedf(y, 0.25),
		snappedf(z, 0.1)]


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
func _fits(placed: Dictionary, skip: Dictionary, with_these: Array = []) -> bool:
	if _read == null:
		_read = OpenPoints.read(assistant)
	var also: Array = []
	for n: int in with_these.size():
		var other: Assistant.Placement = Assistant.Placement.from_dict(with_these[n])
		var mesh: Lbm.PartMesh = assistant.library.mesh_for(other.part)
		if mesh != null:
			also.append([-(n + 1), mesh, assistant._transform(other, mesh, null), ""])
	var trial: Dictionary = _read.test(Assistant.Placement.from_dict(placed), skip, also)
	if not bool(trial["fits"]):
		return false
	for by: Variant in trial["held_by"]:
		if int(by) != 0 and not skip.has(int(by)):
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
