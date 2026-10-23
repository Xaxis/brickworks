## The feature pass, driven by the app: for each feature a subject is known
## by, the app looks up how real sets built it, keeps the pieces that lay
## whole, and lays the best one that fits where the feature goes, as a
## proposal. The design's part is to accept it (moved, turned or recoloured
## if it needs to be), ask for the next, or reject it with a reason.
##
## Why the app does it rather than the rules asking. The creative pass
## lifted creativity from 3.0 to 5.2 because the app hands the design that
## turn itself; the feature chain only told sessions which feature was next,
## and they worked two of six, searched, read the pieces and built their own:
## not one of 12,967 credited real-set pieces was ever laid, even when three
## were handed over with ids. A real piece already standing in the model,
## seen in the picture, is a different question from "remember to search
## and place": is this right here?
##
## Where a feature goes is the design's to say (submit_design's features
## take x, y, z and facing); without that it is read off the feature's name
## ([constant WHERE]: eyes at the top of the front, wheels low on the sides)
## and the model's box, and said as a guess the design can move.
class_name FeaturePass
extends RefCounted

const STUD := 20.0
const PLATE := 8.0
## Pieces looked at for a feature, before those that do not lay whole or
## are not the feature are left out, and the most parts one may have to be
## laid as a proposal.
const LOOKED_AT := 80
const MOST_PARTS := 40
## Pieces kept as candidates for a feature, in the index's order.
const CANDIDATES := 6
## How far from where the feature goes a piece may be seated, in LDU, and
## for a feature facing sideways how far in front of or behind that face.
## Seven studs every way put a starfighter's exhausts on top of its
## fuselage and its canopy on the cockpit floor.
const REACH := 4.0 * STUD
const DEPTH := 1.5 * STUD
## Open studs tried as a seat for one piece in one orientation.
const SEATS := 28
## Whole edits tried for one feature before it is handed over as it is.
const LAYINGS := 3

## Where on a subject a feature is, by the words of its name: [words, the
## way it faces, how high (0 the bottom of the model, 1 its top)]. The
## front is +z, as the "front" picture looks at it. First match wins.
const WHERE: Array = [
	[["talon", "foot", "claw", "paw", "hoof", "toe"], "+z", 0.06],
	[["eye", "face", "facial", "disc", "beak", "brow", "mouth", "muzzle", "snout",
		"cockpit", "visor", "windscreen", "windshield", "canopy", "head"], "+z", 0.78],
	[["grille", "grill", "headlamp", "headlight", "lamp", "light", "bumper", "nose",
		"bonnet", "hood", "intake", "splitter", "badge", "plate"], "+z", 0.3],
	[["door", "entrance", "shopfront", "storefront", "window", "awning", "sign",
		"counter", "display", "porch", "step"], "+z", 0.35],
	[["wheel", "tyre", "tire", "arch", "mudguard", "fender", "skirt", "sill"], "+x", 0.12],
	[["wing", "fin", "flank", "side", "mirror", "pod", "cannon", "laser", "gun",
		"arm", "feather", "plumage"], "+x", 0.5],
	[["tail", "exhaust", "thruster", "engine", "rear", "taillight", "booster"], "-z", 0.4],
	[["ear", "tuft", "horn", "crest", "roof", "chimney", "antenna", "aerial", "spoiler",
		"turret", "tower", "dome", "top", "mast"], "up", 1.0],
]

## As built, a piece's front is +z (LDraw's -z, which its modellers face to
## the viewer); this many quarter turns about the upright bring it to face
## each way.
const TURN_TO: Dictionary = {"+z": 0, "+x": 1, "-z": 2, "-x": 3}


## What the app laid for one feature, and what the design said of it.
class Proposal extends RefCounted:
	var feature: String = ""
	## Where it goes: {x, y, z, facing} in studs and plates, and whether
	## that was read off its name rather than said.
	var spot: Dictionary = {}
	var guessed: bool = false
	## The real-set pieces that lay whole, best first, and the next to try.
	var candidates: Array = []
	var next: int = 0
	## The piece laid, the bricks laid for it (a pair: both copies), and how
	## each copy was laid: {"bricks", "turn", "up"}.
	var piece: Dictionary = {}
	var ids: Array[int] = []
	var copies: Array = []
	## Pieces that fit nowhere near, by id.
	var missed: PackedStringArray = PackedStringArray()
	## "" until the design settles it: "accepted", "adjusted", "rejected",
	## "built", "skipped"; "kept" when a loop's turns ran out with it standing.
	var verdict: String = ""
	var reason: String = ""

	func settled() -> bool:
		return not verdict.is_empty()


var assistant: Assistant
## Feature name in lower case -> the spot the design gave it.
var spots: Dictionary = {}
## Feature name in lower case -> its Proposal.
var proposals: Dictionary = {}


func _init(of: Assistant) -> void:
	assistant = of


## A new design: its features' spots, and nothing proposed yet.
func reset(given: Dictionary) -> void:
	spots = given.duplicate(true)
	proposals = {}


## The spots a submission gives its features: {"name", "x", "y", "z",
## "facing"} for each that says where. Strings say nothing.
static func read_spots(args: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var given: Variant = args.get("features", [])
	if not given is Array:
		return out
	for raw: Variant in given:
		if not raw is Dictionary:
			continue
		var one: Dictionary = raw
		var name: String = str(one.get("name", "")).strip_edges().to_lower()
		if name.is_empty() or not (one.has("x") and one.has("y") and one.has("z")):
			continue
		var facing: String = str(one.get("facing", "+z")).strip_edges().to_lower()
		out[name] = {"x": float(one["x"]), "y": float(one["y"]), "z": float(one["z"]),
			"facing": facing if Assistant.FACES.has(facing) else "+z"}
	return out


func proposal(name: String) -> Proposal:
	return proposals.get(name.to_lower())


## Whether the design has said what each of these features is to be.
func open(names: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for name: String in names:
		var one: Proposal = proposal(name)
		if one == null or not one.settled():
			out.append(name)
	return out


## Where a feature goes: where the design said, or read off its name and
## the model's box. In studs and plates, with the way it faces.
func spot_for(name: String) -> Dictionary:
	var said: Dictionary = spots.get(name.to_lower(), {})
	if not said.is_empty():
		return said
	var box: AABB = assistant._bounds_of(assistant._bricks_inside({}))
	var facing: String = "+z"
	var high: float = 0.5
	var words: PackedStringArray = RealSnippets.words(name)
	var found: bool = false
	for row: Array in WHERE:
		for word: String in row[0]:
			if words.has(RealSnippets.stem(word)) or words.has(word):
				facing = row[1]
				high = row[2]
				found = true
				break
		if found:
			break
	# A model a good deal longer along x than z runs along x, as a car laid
	# that way does: its front is +x and its sides are +z and -z.
	if box.size.x > 1.3 * box.size.z:
		facing = str({"+z": "+x", "-z": "-x", "+x": "+z", "-x": "-z"}.get(facing, facing))
	var at := Vector3(0.0, box.position.y + box.size.y * high, 0.0)
	# On the model's surface at that height, not its box's: the bricks
	# whose height spans it, their outermost face that way. A base plate
	# wider than the owl on it put the eyes on the plate's front edge.
	var band: Array = []
	var all: Array = []
	for brick: BrickWorld.Brick in assistant._bricks_inside({}):
		var mesh: Lbm.PartMesh = assistant.library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var one: AABB = (brick.transform * mesh.bounds).abs()
		all.append(one)
		if one.position.y - PLATE <= at.y and one.end.y + PLATE >= at.y:
			band.append(one)
	if band.is_empty():
		band = all
	var spans := AABB()
	for n: int in band.size():
		spans = band[n] if n == 0 else spans.merge(band[n])
	var middle: Vector3 = spans.get_center() if not band.is_empty() else box.get_center()
	at.x = middle.x
	at.z = middle.z
	match facing:
		"+z":
			at.z = spans.end.z
		"-z":
			at.z = spans.position.z
		"+x":
			at.x = spans.end.x
		"-x":
			at.x = spans.position.x
		"up":
			at.y = box.end.y
	# One of a pair is off the middle, so its other is mirrored across it:
	# guessed at the middle, a pair of eyes was one eye.
	var across: String = _across(box)
	if _plural(name) and not facing.ends_with(across):
		if across == "x":
			at.x -= maxf(1.5 * STUD, 0.2 * spans.size.x)
		else:
			at.z -= maxf(1.5 * STUD, 0.2 * spans.size.z)
	return {"x": snappedf(at.x / STUD, 0.5), "y": snappedf(at.y / PLATE, 1.0),
		"z": snappedf(at.z / STUD, 0.5), "facing": facing, "guessed": true}


## The real pieces for a feature that lay whole and are that feature, best
## first: the subject's own sets first (RealSnippets.search), then any.
##
## A piece is the feature when what it is (RealSnippets.what_it_is) names
## the feature's own noun or a word the index takes as the same: the
## fenders of "tyre fenders", the hands of "claw hands" (a claw, a
## gripper). Matched on the whole description, the subject's words decided
## it: "harbour tug boat" ran together as "tugboat", the rarest word in the
## query, and a tugboat's funnel came first for its fenders, its windows,
## its bitts and its mast (walk180, 2026-10-23). A feature no piece is
## gets none, and the design builds it.
func candidates_for(name: String) -> Array:
	var subject: String = Assistant._subject_words(assistant._asked_as())
	var query: String = ("%s %s" % [subject, name]).strip_edges()
	var box: AABB = assistant._bounds_of(assistant._bricks_inside({}))
	var widest: float = maxf(box.size.x, box.size.z) / STUD
	var most: float = maxf(4.0, widest * 0.6)
	var said: PackedStringArray = RealSnippets.words(name)
	var nouns: Array = nouns_of(name)
	var found: Array = []
	var seen: Dictionary = {}
	for asked: String in [query, name]:
		for row: Variant in RealSnippets.search(asked, most, [], LOOKED_AT, 2):
			var entry: Dictionary = (row as Array)[1]
			if seen.has(entry["id"]) or not bool(entry.get("lays", false)) \
					or not bool(entry.get("square", true)) \
					or int(entry.get("parts", 0)) > MOST_PARTS:
				continue
			seen[entry["id"]] = true
			var named: int = names_it(entry, said, nouns)
			if named > 0:
				found.append([named, found.size(), entry])
	# Those that say more of it first, then in the search's order: the
	# subject's own sets, then the best scored.
	found.sort_custom(func(one: Array, other: Array) -> bool:
		return one[0] > other[0] if one[0] != other[0] else one[1] < other[1])
	var out: Array = []
	for row: Array in found.slice(0, CANDIDATES):
		out.append(row[2])
	return out


## The nouns a feature is named by, each with the words the index takes as
## the same: the last word of each thing it lists ("mast and navigation
## lights" is a mast and lights).
static func nouns_of(name: String) -> Array:
	var out: Array = []
	var parts: PackedStringArray = RegEx.create_from_string(
		"(?i)\\s*(?:,|&|\\band\\b|\\bwith\\b|\\bon\\b|\\bat\\b|\\bfor\\b|\\bplus\\b)\\s*").sub(
		name, "|", true).split("|", false)
	for part: String in parts:
		var said: PackedStringArray = RealSnippets.words(part)
		if said.is_empty():
			continue
		out.append(RealSnippets.kin(said[-1]))
	return out


## How well what [param entry] is says a feature, given as its words
## ([param said]) and its nouns ([method nouns_of]): 0 when it names none of
## its nouns, nor a word the index takes as the same; otherwise two for each
## of the feature's words it says as they are, and one for a noun it says
## another way. The front door before a hatch, the arm's claw before a
## chameleon's hand for "claw hands".
static func names_it(entry: Dictionary, said: PackedStringArray, nouns: Array) -> int:
	var what: PackedStringArray = RealSnippets.what_it_is(entry)
	var named: bool = false
	for kin: PackedStringArray in nouns:
		for word: String in kin:
			if what.has(word):
				named = true
	if not named:
		return 0
	var score: int = 0
	var heads: Dictionary = {}
	for kin: PackedStringArray in nouns:
		heads[kin[0]] = kin
	for word: String in said:
		if what.has(word):
			score += 2
		elif heads.has(word):
			for other: String in heads[word]:
				if what.has(other):
					score += 1
					break
	return maxi(score, 1)


## Lay the best piece that fits for a feature, as its proposal, unless one
## already stands. Awaited.
func propose(name: String) -> Proposal:
	var key: String = name.to_lower()
	var one: Proposal = proposals.get(key)
	if one == null:
		one = Proposal.new()
		one.feature = name
		proposals[key] = one
	if one.settled() or (not one.ids.is_empty() and _standing(one.ids)):
		return one
	if one.spot.is_empty():
		one.spot = spot_for(name)
		one.guessed = bool(one.spot.get("guessed", false))
	if one.candidates.is_empty() and one.next == 0:
		one.candidates = candidates_for(name)
	await _lay_next(one)
	return one


## Lay the next candidate that fits, from one.next on. Leaves one.piece
## empty when none does.
func _lay_next(one: Proposal) -> void:
	one.piece = {}
	one.ids = []
	one.copies = []
	var tries: int = 0
	while one.next < one.candidates.size() and tries < LAYINGS:
		var entry: Dictionary = one.candidates[one.next]
		one.next += 1
		var fit: Dictionary = await fit(entry, one.spot)
		if fit.is_empty():
			one.missed.append(str(entry["id"]))
			continue
		tries += 1
		var ids: Array[int] = await lay(fit["bricks"])
		if ids.is_empty():
			one.missed.append(str(entry["id"]))
			continue
		one.piece = entry
		one.ids = ids
		one.copies = [fit]
		# A pair, off the middle: its other one, the same piece mirrored
		# across the model.
		var other: Dictionary = mirrored(one.spot)
		if _plural(one.feature) and not other.is_empty():
			var second: Dictionary = await fit(entry, other)
			if not second.is_empty():
				var more: Array[int] = await lay(second["bricks"])
				if not more.is_empty():
					one.ids.append_array(more)
					one.copies.append(second)
		return


## The spot across the model's middle from [param spot], left for right,
## or {} when it is on the middle already.
func mirrored(spot: Dictionary) -> Dictionary:
	var box: AABB = assistant._bounds_of(assistant._bricks_inside({}))
	var axis: String = _across(box)
	var middle: float = (box.get_center().x if axis == "x" else box.get_center().z) / STUD
	var value: float = float(spot[axis])
	if absf(value - middle) < 1.0:
		return {}
	var out: Dictionary = spot.duplicate()
	out[axis] = snappedf(2.0 * middle - value, 0.5)
	if str(spot["facing"]) == "+" + axis:
		out["facing"] = "-" + axis
	elif str(spot["facing"]) == "-" + axis:
		out["facing"] = "+" + axis
	return out


## The axis across a model, left to right as it faces you: x, unless it is a
## good deal longer along x than z (a car laid that way), then z.
static func _across(box: AABB) -> String:
	return "z" if box.size.x > 1.3 * box.size.z else "x"


static func _plural(name: String) -> bool:
	var last: String = name.strip_edges().to_lower().split(" ")[-1]
	return last.ends_with("s") and not last.ends_with("ss") and not last.ends_with("us")


## Whether every one of these bricks still stands.
func _standing(ids: Array[int]) -> bool:
	for id: int in ids:
		if assistant.world.get_brick(id) == null:
			return false
	return true


## Where [param entry] fits and holds nearest [param spot]: {"bricks":
## placements as edit_model takes them, "turn", "up", "at"}, or {}. Each way
## the piece can face the spot is tried, seated by one of its lowest
## hollows on a free stud of the model that points the same way, and kept
## when none of its parts runs into the model and at least one is held by
## it (OpenPoints.test, the check's own rules a part at a time).
func fit(entry: Dictionary, spot: Dictionary) -> Dictionary:
	var facing: String = str(spot.get("facing", "+z"))
	var target := Vector3(float(spot["x"]) * STUD, float(spot["y"]) * PLATE,
		float(spot["z"]) * STUD)
	var read: OpenPoints = OpenPoints.read(assistant)
	var ids: Array = []
	for brick: BrickWorld.Brick in assistant._bricks_inside({}):
		ids.append(brick.id)
	var box: AABB = assistant._bounds_of(assistant._bricks_inside({}))
	var out: Vector3 = Assistant.FACES.get(facing, Vector3.UP)
	# On a worker (WorkerTasks.awaited): the model's open points read, and
	# each free stud near the spot walked out through the lattice, were 300 ms
	# of one frame for every piece tried, six to a feature, on a Technic
	# loader's 128 parts (jobs70, 2026-10-21).
	var free: Array = await WorkerTasks.awaited(func() -> Variant:
		var found: Array = []
		for point: OpenPoints.Point in read.points_of(ids):
			if point.kind == "stud" and point.by == 0 and point.section.is_empty() \
					and point.at.distance_to(target) <= REACH and _outside(point, out, box) \
					and (facing == "up" or absf((point.at - target).dot(out)) <= DEPTH):
				found.append(point)
		return found, "find the free studs a feature's piece may sit on", assistant.library)
	free.sort_custom(func(a: OpenPoints.Point, b: OpenPoints.Point) -> bool:
		return a.at.distance_to(target) < b.at.distance_to(target))
	for option: Array in _ways(facing):
		var turn: int = option[0]
		var up: String = option[1]
		var way: Vector3 = Assistant.FACES[up]
		var seats: Array = free.filter(func(point: OpenPoints.Point) -> bool:
			return point.way.dot(way) > 0.99).slice(0, SEATS)
		if seats.is_empty():
			continue
		var base: Variant = await assistant._snippet_bricks(entry, Vector3.ZERO, turn, {}, up)
		if base is String:
			return {}
		var hollows: Array = _lowest_hollows(base as Array, way)
		var tried: Dictionary = {}
		for seat: OpenPoints.Point in seats:
			for hollow: Vector3 in hollows:
				var by: Vector3 = seat.at - hollow
				var shift := Vector3(snappedf(by.x / STUD, 0.05), snappedf(by.y / PLATE, 0.25),
					snappedf(by.z / STUD, 0.05))
				var key: String = str(shift)
				if tried.has(key):
					continue
				tried[key] = true
				var moved: Array = _shifted(base as Array, shift)
				if _stands(read, moved):
					return {"bricks": moved, "turn": turn, "up": up,
						"at": Vector3(seat.at.x / STUD, seat.at.y / PLATE, seat.at.z / STUD)}
	return {}


## Whether a free stud is on the model's outside, seen the way the feature
## faces: nothing of the model on it, and nothing between it and the edge of
## the model's box that way. The nearest free studs to where a corner shop's
## awning, sign and cornice go were on its floors, inside, and all three were
## laid there and rejected.
func _outside(point: OpenPoints.Point, out: Vector3, box: AABB) -> bool:
	var lattice: BrickLattice = assistant.builder.lattice
	var start: Vector3 = point.at + point.way * 6.0
	var at: Vector3 = start
	var reach: AABB = box.grow(STUD)
	for way: Vector3 in [point.way, out]:
		at = start
		for step: int in 200:
			at += way * 8.0
			if not reach.has_point(at):
				break
			var other: int = lattice.brick_at(BrickLattice.to_cell(at))
			if other != 0 and other != point.brick and not assistant.scenery.has(other):
				return false
	return true


## The ways a piece is tried facing a spot, as [turns, up]: as built with
## its front to it, then for a side, tipped whole so its studs face out.
static func _ways(facing: String) -> Array:
	if facing == "up" or facing == "down" or not TURN_TO.has(facing):
		return [[0, "up"], [1, "up"], [2, "up"], [3, "up"]]
	var out: Array = [[int(TURN_TO[facing]), "up"]]
	for turn: int in 4:
		out.append([turn, facing])
	return out


## The hollows on the underside of a piece laid as [param bricks], where
## underside is against [param way]: those of its lowest layer, in LDU.
func _lowest_hollows(bricks: Array, way: Vector3) -> Array:
	var found: Array = []
	var lowest: float = INF
	for raw: Variant in bricks:
		var placement: Assistant.Placement = Assistant.Placement.from_dict(raw)
		var mesh: Lbm.PartMesh = assistant.library.mesh_for(placement.part)
		if mesh == null:
			continue
		var at: Transform3D = assistant._transform(placement, mesh, null)
		if (at.basis * Vector3.DOWN).normalized().dot(-way) < 0.99:
			continue
		var bottom: float = mesh.bounds.position.y
		for socket: Vector2 in mesh.sockets:
			var point: Vector3 = at * Vector3(socket.x, bottom, socket.y)
			var height: float = point.dot(way)
			if height < lowest - 1.0:
				lowest = height
				found = [point]
			elif absf(height - lowest) <= 1.0:
				found.append(point)
	return found


static func _shifted(bricks: Array, by: Vector3) -> Array:
	var out: Array = []
	for raw: Variant in bricks:
		var one: Dictionary = (raw as Dictionary).duplicate()
		one["x"] = snappedf(float(one["x"]) + by.x, 0.01)
		one["y"] = snappedf(float(one["y"]) + by.y, 0.01)
		one["z"] = snappedf(float(one["z"]) + by.z, 0.01)
		out.append(one)
	return out


## Whether bricks laid as they are would fit and be held by the model.
static func _stands(read: OpenPoints, bricks: Array) -> bool:
	var held: bool = false
	for raw: Variant in bricks:
		var trial: Dictionary = read.test(Assistant.Placement.from_dict(raw))
		if not bool(trial["fits"]):
			return false
		for by: Variant in trial["held_by"]:
			if int(by) > 0:
				held = true
	return held


## Lay bricks through edit_model, checked like any edit; the ids they were
## given, or none when it was refused.
func lay(bricks: Array, remove: Array[int] = []) -> Array[int]:
	var before: Dictionary = {}
	for brick: BrickWorld.Brick in assistant.world.bricks():
		before[brick.id] = true
	var input: Dictionary = {"add": bricks}
	if not remove.is_empty():
		input["remove"] = remove
	assistant._laying_whole = true
	var answer: Variant = await assistant._run_tool({"name": "edit_model", "input": input})
	assistant._laying_whole = false
	var head: String = str(answer if answer is String else "")
	var out: Array[int] = []
	if head.begins_with("Not applied") or head.begins_with("No brick") \
			or head.begins_with("Nothing in that") or head.begins_with("That would"):
		return out
	for brick: BrickWorld.Brick in assistant.world.bricks():
		if not before.has(brick.id):
			out.append(brick.id)
	return out


## Take the proposal's bricks off, those still standing. True when they
## are gone.
func take_off(one: Proposal) -> bool:
	var standing: Array = []
	for id: int in one.ids:
		if assistant.world.get_brick(id) != null:
			standing.append(id)
	if standing.is_empty():
		one.ids = []
		return true
	assistant._laying_whole = true
	var answer: Variant = await assistant._run_tool({"name": "edit_model",
		"input": {"remove": standing}})
	assistant._laying_whole = false
	var head: String = str(answer if answer is String else "")
	if head.begins_with("Not applied") or head.begins_with("That would"):
		return false
	one.ids = []
	return true


## The same piece laid again, moved by whole studs and plates, turned, or
## recoloured: in one edit with taking the old copies off, so a refusal
## leaves it where it was. "" when it went down; why not otherwise.
func adjust(one: Proposal, move: Dictionary, turns: int, recolor: Dictionary) -> String:
	var bricks: Array = []
	var copies: Array = []
	for n: int in one.copies.size():
		var copy: Dictionary = one.copies[n]
		var by := Vector3(float(move.get("dx", 0.0)), float(move.get("dy", 0.0)),
			float(move.get("dz", 0.0)))
		# The other of a pair moves the mirror way across the model.
		if n == 1:
			by.x = -by.x
		var laid: Array = copy["bricks"]
		if turns != 0:
			var turned: Variant = await assistant._snippet_bricks(one.piece, Vector3.ZERO,
				int(copy["turn"]) + (turns if n == 0 else -turns), {}, str(copy["up"]))
			if turned is String:
				return str(turned)
			# Kept where it was: its low corner where the old one's was.
			laid = _shifted(turned as Array, _low(laid) - _low(turned as Array))
		var moved: Array = _shifted(laid, by)
		if not recolor.is_empty():
			for brick: Variant in moved:
				var colour: int = int((brick as Dictionary)["color"])
				(brick as Dictionary)["color"] = int(recolor.get(colour, colour))
		bricks.append_array(moved)
		copies.append({"bricks": moved, "turn": int(copy["turn"]) + (turns if n == 0 else -turns),
			"up": copy["up"], "at": copy.get("at", Vector3.ZERO) + by})
	var standing: Array[int] = []
	for id: int in one.ids:
		if assistant.world.get_brick(id) != null:
			standing.append(id)
	var ids: Array[int] = await lay(bricks, standing)
	if ids.is_empty():
		return ("Not applied: laid there it would run into the model or hold by "
			+ "nothing, so it stays where it was. Move it less, or the other way.")
	one.ids = ids
	one.copies = copies
	return ""


static func _low(bricks: Array) -> Vector3:
	var low := Vector3(INF, INF, INF)
	for raw: Variant in bricks:
		var one: Dictionary = raw
		low = low.min(Vector3(float(one["x"]), float(one["y"]), float(one["z"])))
	return low


## What a feature came to, in a line, once it has been settled.
func said(name: String) -> String:
	var one: Proposal = proposal(name)
	if one == null or not one.settled():
		return ""
	var piece: String = "%s \"%s\"" % [one.piece.get("id", ""), one.piece.get("name", "")] \
		if not one.piece.is_empty() else ""
	match one.verdict:
		"accepted":
			return "real piece %s laid by the app, accepted%s" % [piece,
				" (a pair)" if one.copies.size() > 1 else ""]
		"adjusted":
			return "real piece %s laid by the app, adjusted and kept" % piece
		"kept":
			return "real piece %s laid by the app, kept" % piece
		"built":
			return "built by the design%s" % (": " + one.reason if not one.reason.is_empty()
				else "")
		"rejected":
			return "the app's piece rejected: %s" % one.reason
		"skipped":
			return "left out by the design%s" % (": " + one.reason if not one.reason.is_empty()
				else "")
	return one.verdict
