## How a model is built, against how real sets of its kind are.
##
## Every measure before this was of what a model is made of — how many
## different parts, colours, how big. None was of how it is built, and
## the owner's verdict on an Orthanc that held together and measured
## fine on those was that it "still ultimately sucked": too symmetric,
## functional square bricks studs-up, nothing used creatively. Measured
## against real fantasy sets (tools/style.py, over LDraw's official
## models), that Orthanc was 0% sideways where they are a median 19%, 0%
## at an angle against 27%, 57% plain bricks and plates against 28%, and
## 88% mirror-symmetric against 31%. Telling the design in words changed
## nothing; a rebuild with the craft guidance came out 0%, 0% and 77%.
##
## So it is measured, the way variety is, and said only on the tails:
## below the tenth percentile of real sets of the kind, or above the
## ninetieth, so the advice costs one real set in ten at most.
##
## The rules for what kind a part is live in tools/style.py, which
## writes every part's kinds into style_norms.json; this reads them
## rather than keeping a second copy that would drift.
class_name Style
extends RefCounted

## Where the norms are: packed for the web build, which leaves
## assets/generated out of the export, and generated on the desktop.
const NORMS: Array[String] = ["res://assets/generated/style_norms.json",
	"res://assets/web/style_norms.json"]
## Real sets are only measured from this size, so a model is too.
const LEAST := 100
## A part's studs point up when within this of straight up, as in
## tools/style.py (cos 20 degrees).
const UP_COS := 0.9397
## Turned by other than a quarter turn, when any axis is further than
## this from square, as in tools/style.py.
const SQUARE := 0.02
## How close a mirrored part has to land, in LDU, as in tools/style.py.
const TOLERANCE := 4.0

static var _norms: Dictionary = {}
static var _loaded: bool = false
## Read at first use, under a lock: a build's check and Brickify read the
## norms on a worker, and a table put on one thread while another copies
## it leaves the copy holding nothing, as Mechanism's gear table did
## (racefix, 2026-10-20). Their callers read them here first, but a lock
## does not depend on every caller remembering to.
static var _norms_lock := Mutex.new()


static func norms() -> Dictionary:
	_norms_lock.lock()
	if not _loaded:
		_loaded = true
		for path: String in NORMS:
			if not FileAccess.file_exists(path):
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_norms = parsed
				break
	var read: Dictionary = _norms
	_norms_lock.unlock()
	return read


## A part's kinds as tools/style.py names them, in letters: c curve,
## s slope, n a part that turns studs sideways, a a part that lets
## another sit at an angle, t texture, i tile, o organic, p plain, and u
## when its studs say which way is up. "" for what is not a building
## part — a figure, a sticker — and unknown parts.
static func kinds_of(part: String) -> String:
	var kinds: Dictionary = norms().get("part_kinds", {}) as Dictionary
	return str(kinds.get(part, ""))


## The words that put a brief with a group of real sets, first group first.
const GROUP_WORDS: Array = [
	[["orthanc", "mordor", "rivendell", "hobbit", "lord of the rings",
		"wizard", "dragon", "elf", "elven", "dwarf", "fantasy", "castle",
		"knight", "medieval", "fortress", "keep", "dungeon", "ruin",
		"tolkien", "isengard", "sauron", "magic"], "fantasy"],
	[["spaceship", "starship", "space", "rocket", "star wars", "x-wing",
		"tie fighter", "shuttle", "satellite", "planet"], "space"],
	[["car", "truck", "train", "locomotive", "bus", "plane", "aircraft",
		"helicopter", "boat", "ship", "tractor", "motorbike", "vehicle"],
		"vehicles"],
	[["skyline", "landmark", "architecture", "cathedral", "skyscraper"],
		"architecture"],
	[["house", "shop", "station", "street", "town", "city", "building",
		"cafe", "bakery", "school", "hotel", "modular"], "buildings_since_2010"],
]


## Which real sets a brief is to be compared with.
##
## By what the brief says, because the brief is the only thing that
## knows a tower is Orthanc and not an office block. Castles go with the
## fantasy sets: twelve of the fourteen castles in the repository are
## from 1984-93 and build almost nothing sideways, which is not the bar.
static func group_for(brief: String) -> String:
	var groups: Dictionary = norms().get("groups", {}) as Dictionary
	for pair: Array in GROUP_WORDS:
		# Whole words (SubjectWords): "bust" is not a bus, nor a
		# gatehouse a house.
		if groups.has(pair[1]) and not SubjectWords.first_named(brief, pair[0]).is_empty():
			return str(pair[1])
	return "since_2010" if groups.has("since_2010") else ""


## The measures of some parts, each [part id, colour, Transform3D of
## the part, its box in its own LDU]: the shares of building parts that
## point their studs other than up, that are turned off the square, and
## of each kind, and the share with a mirror partner.
static func measure(parts: Array) -> Dictionary:
	var counted: int = 0
	var tally: Dictionary = {"snot": 0, "angled": 0, "curve": 0, "slope": 0,
		"plain": 0, "texture": 0, "shaped": 0}
	var boxes: Array = []
	for entry: Array in parts:
		var part: String = entry[0]
		var kinds: String = kinds_of(part)
		if kinds.is_empty():
			continue
		counted += 1
		var at: Transform3D = entry[2]
		var basis: Basis = at.basis.orthonormalized()
		var turned: bool = _angled(basis)
		if turned:
			tally["angled"] += 1
		if kinds.contains("u") and basis.y.y < UP_COS:
			tally["snot"] += 1
		if kinds.contains("c"):
			tally["curve"] += 1
		elif kinds.contains("s"):
			tally["slope"] += 1
		if kinds.contains("p"):
			tally["plain"] += 1
		if kinds.contains("t"):
			tally["texture"] += 1
		if kinds.contains("c") or kinds.contains("s") or turned:
			tally["shaped"] += 1
		var own: AABB = entry[3]
		var box: AABB = at * own
		boxes.append([part, int(entry[1]), box.get_center(), box.size / 2.0])
	var found: Dictionary = {"parts": counted}
	if counted == 0:
		return found
	for key: String in tally:
		found[key] = float(tally[key]) / float(counted)
	found["symmetry"] = _symmetry(boxes)
	return found


static func _angled(basis: Basis) -> bool:
	for column: Vector3 in [basis.x, basis.y, basis.z]:
		for value: float in [column.x, column.y, column.z]:
			if minf(absf(value), absf(absf(value) - 1.0)) > SQUARE:
				return true
	return false


## The share of parts with a partner mirrored across the best vertical
## plane, as tools/style.py finds it: pairs of like parts level with
## each other vote for the plane halfway between them, and the middle of
## the model is tried too. The middle alone was tried first, and read
## the shipped castle as 0% mirrored where the tool reads 55%: a plane
## that falls between the lines of the part grid matches nothing.
static func _symmetry(boxes: Array) -> float:
	if boxes.is_empty():
		return 0.0
	var grid: Dictionary = {}
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for n: int in boxes.size():
		var one: Array = boxes[n]
		var centre: Vector3 = one[2]
		var key: Array = [one[0], one[1], _cell(centre)]
		if not grid.has(key):
			grid[key] = []
		(grid[key] as Array).append(n)
		low = Vector3(minf(low.x, centre.x), minf(low.y, centre.y), minf(low.z, centre.z))
		high = Vector3(maxf(high.x, centre.x), maxf(high.y, centre.y), maxf(high.z, centre.z))
	var best: float = 0.0
	for axis: int in [0, 2]:
		var planes: Array = _planes(boxes, axis)
		planes.append((low[axis] + high[axis]) / 2.0)
		for at: float in planes:
			best = maxf(best, _mirrored(boxes, grid, axis, at))
	return best


## Where a mirror plane across an axis might be: the three places pairs
## of like parts, level with each other, most often put halfway between
## them.
static func _planes(boxes: Array, axis: int) -> Array:
	var others: Array = [2, 1] if axis == 0 else [0, 1]
	var buckets: Dictionary = {}
	for one: Array in boxes:
		var centre: Vector3 = one[2]
		var half: Vector3 = one[3]
		var key: Array = [one[0], one[1], roundi(centre[others[0]] / TOLERANCE),
			roundi(centre[others[1]] / TOLERANCE), roundi(half[axis]),
			roundi(half[others[0]])]
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(centre[axis])
	var votes: Dictionary = {}
	for key: Variant in buckets:
		var values: Array = buckets[key]
		values.sort()
		values = values.slice(0, 120)
		for i: int in values.size():
			for j: int in range(i + 1, values.size()):
				var middle: float = roundf((float(values[i]) + float(values[j])) / 4.0) * 2.0
				votes[middle] = int(votes.get(middle, 0)) + 1
	var ranked: Array = votes.keys()
	ranked.sort_custom(func(a: float, b: float) -> bool:
		return int(votes[a]) > int(votes[b]))
	return ranked.slice(0, 3)


## The share of parts with a partner across the plane axis = at: one
## partner each, a part across the plane from itself its own.
static func _mirrored(boxes: Array, grid: Dictionary, axis: int, at: float) -> float:
	if true:
		var matched: Dictionary = {}
		for n: int in boxes.size():
			if matched.has(n):
				continue
			var one: Array = boxes[n]
			var target: Vector3 = one[2]
			target[axis] = 2.0 * at - target[axis]
			var home: Vector3i = _cell(target)
			var found: int = -1
			for dx: int in [-1, 0, 1]:
				for dy: int in [-1, 0, 1]:
					for dz: int in [-1, 0, 1]:
						var key: Array = [one[0], one[1], home + Vector3i(dx, dy, dz)]
						for other: int in grid.get(key, []):
							if matched.has(other) and other != n:
								continue
							var them: Array = boxes[other]
							var centre: Vector3 = them[2]
							if (centre - target).abs()[(centre - target).abs().max_axis_index()] > TOLERANCE:
								continue
							found = other
							break
						if found >= 0:
							break
					if found >= 0:
						break
				if found >= 0:
					break
			if found >= 0:
				matched[n] = true
				matched[found] = true
		return float(matched.size()) / float(boxes.size())
	return 0.0


static func _cell(point: Vector3) -> Vector3i:
	return Vector3i(int(floor(point.x / TOLERANCE)), int(floor(point.y / TOLERANCE)),
		int(floor(point.z / TOLERANCE)))


## What to tell a design, or "": the measures on the tails of real sets
## of its kind, each with the median and the edge it is past. [param about]
## is what it is of, so a tower is told of the call shaped like a tower.
## [param shaped]: its body was laid by the shape pattern, so it is told to
## keep that body, not to say one.
static func advice(found: Dictionary, group: String, about: String = "",
		shaped: bool = false) -> String:
	if int(found.get("parts", 0)) < LEAST or group.is_empty():
		return ""
	var band: Dictionary = (norms().get("groups", {}) as Dictionary).get(group, {})
	if band.is_empty():
		return ""
	var said := PackedStringArray()
	var traits: Dictionary = traits_of(about)
	# A model shaped by its curves is not built squarely, whatever share of
	# it is turned: a rocket of round bricks and cylinder halves is round,
	# and was told it was a pile of bricks for having nothing on its side.
	var curved: bool = found.has("curve") and band.has("curve") \
		and float(found["curve"]) > float((band["curve"] as Array)[2])
	var low: Array = [
		["snot", "of its parts sideways or upside down — a face of tiles on brackets, a headlight brick, a grille stood up"],
		["shaped", "curved, sloped or at an angle"],
		["curve", "curved — arches, rounds, curved slopes, wedges"],
		["angled", "turned to an angle — a section on a hinge, a wall that bends, a horn that leans"],
	]
	for pair: Array in low:
		var key: String = pair[0]
		if not found.has(key) or not band.has(key):
			continue
		if curved and key in ["snot", "angled"]:
			continue
		var edges: Array = band[key]
		if float(found[key]) < float(edges[0]):
			said.append("%s %s, where they are about %s (and below %s is plainer than nine in ten)"
				% [_share(found[key]), pair[1], _share(edges[1]), _share(edges[0])])
	for pair: Array in [["plain", "plain rectangular bricks and plates"],
			["symmetry", "mirrored left to right"]]:
		var key: String = pair[0]
		if not found.has(key) or not band.has(key):
			continue
		var edges: Array = band[key]
		if float(found[key]) > float(edges[2]):
			said.append("%s %s, where they are about %s (and above %s is more than nine in ten)"
				% [_share(found[key]), pair[1], _share(edges[1]), _share(edges[2])])
	if said.is_empty():
		return ""
	# The calls that do it, by name: designs take up a technique when it
	# is one call they are told of — the finishing pass was used in two runs
	# running once the advice named it, and a prism once in four without.
	# And which calls, by what the subject is. The owner's Falcon Heavy was
	# told "a prism with piers, for a tower like this one" — its description
	# named the launch tower — and "restyle_model", which dresses a plain
	# wall in round tiles: polka dots on a rocket.
	var calls: PackedStringArray = calls_for(traits, found, band, about, shaped)
	var who: String = "real sets since 2010" if group == "since_2010" else (
		"real %s sets%s" % [group.replace("_since_2010", ""),
			" since 2010" if group.ends_with("_since_2010") else ""])
	return ("Built more squarely than %s (%d measured, from LDraw's "
		% [who, int(band.get("models", 0))]
		+ "official models):\n  " + "\n  ".join(said) + "\nThis is how a "
		+ "model that holds together comes to look like a pile of bricks. "
		+ "The way out is technique, not more bricks: brackets and headlight "
		+ "bricks to turn a face, sections turned to the angle a thing really "
		+ "has, curved slopes and arches where an edge can round, the rock "
		+ "pattern where the ground is irregular — and symmetry only where the "
		+ "subject has it."
		+ ("\nOne call each: " + "; ".join(calls) + "." if not calls.is_empty() else ""))


## What a subject is, as the techniques for it go: round in section,
## a vehicle, a living thing, a machine, a building. Read off the brief and
## the model's own name, by words; a subject can be more than one (a
## steam locomotive is a vehicle with a round boiler), and a rocket that
## mentions its launch tower is still a rocket.
const TRAITS: Dictionary = {
	"round": ["rocket", "missile", "booster", "silo", "lighthouse", "chimney",
		"column", "pillar", "boiler", "locomotive", "steam engine", "fuselage",
		"submarine", "torpedo", "barrel", "pipe", "funnel", "smokestack",
		"capsule", "airship", "zeppelin", "blimp", "tree trunk", "mushroom",
		"bottle", "vase", "saturn v", "launcher"],
	"vehicle": ["car", "truck", "lorry", "van", "bus", "train", "locomotive",
		"tram", "plane", "aircraft", "airliner", "jet", "helicopter", "boat",
		"ship", "yacht", "galleon", "schooner", "submarine", "tractor",
		"motorbike", "motorcycle", "bicycle", "kart", "racer", "tank",
		"spaceship", "starship", "shuttle", "rocket", "rover", "digger",
		"excavator", "bulldozer", "vehicle", "porsche", "ferrari", "lamborghini",
		"coupe", "roadster", "supercar", "hatchback", "sedan", "saloon",
		"speed champions", "formula 1", "f1", "fire engine"],
	"living": ["animal", "dragon", "owl", "bird", "eagle", "parrot", "cat",
		"dog", "horse", "dinosaur", "creature", "monster", "fish", "whale",
		"shark", "insect", "butterfly", "bear", "lion", "elephant", "bust",
		"tree", "flower", "plant", "bonsai", "puppy", "kitten", "rabbit", "bunny",
		"fox", "wolf", "pig", "cow", "sheep", "goat", "duck", "chicken", "penguin",
		"frog", "turtle", "tortoise", "snake", "lizard", "crocodile", "monkey",
		"gorilla", "giraffe", "zebra", "deer", "kangaroo", "koala", "panda",
		"tiger", "unicorn", "octopus", "crab", "spider", "bee", "squirrel",
		"hedgehog", "dolphin", "otter", "camel", "hippo", "rhino"],
	# A person or a character of one: built of sub-assemblies on joints, as a
	# creature is (Style.character_of).
	# Not "minifigure": a car "at minifigure scale" is a car.
	"figure": ["figure", "figurine", "character",
		"statue", "person", "people", "man", "men", "woman", "women", "boy",
		"girl", "child", "kid", "baby", "human", "humanoid", "knight", "wizard",
		"witch", "king", "queen", "prince", "princess", "pirate", "soldier",
		"astronaut", "cowboy", "ninja", "samurai", "viking", "warrior", "hero",
		"superhero", "clown", "chef", "doctor", "farmer", "mermaid", "fairy",
		"troll", "ogre", "goblin", "zombie", "ghost", "skeleton", "vampire",
		"alien", "snowman", "scarecrow", "puppet", "mascot", "gnome",
		"dancer", "athlete", "sailor", "firefighter", "fireman", "policeman",
		"monk", "angel", "yeti", "teddy",
		# A subject that is a he or a she is a person or a character of one. Three
		# letters at least: SubjectWords does not read "he".
		"his", "him", "himself", "she", "her", "herself"],
	"machine": ["mech", "robot", "machine", "crane", "excavator", "digger",
		"engine", "factory", "windmill", "clock", "mill", "pump", "drill",
		"walker", "turbine"],
	# A model that moves on purpose, worked from one crank. The owner asked
	# for an orrery; nothing here knew what one was but an aeroplane.
	"mechanism": ["orrery", "planetarium", "tellurion", "armillary", "mechanism",
		"kinetic", "automaton", "automata", "clockwork", "gearbox", "gear train",
		"crank", "marble run"],
}


## The subject's traits, as {trait: true}. Whole words, plurals let in
## (SubjectWords):
## "car" is not in "carriage" or "scarlet". A hyphenated word is one word:
## a Porsche's "whale-tail spoiler" and "rear-engine" layout made it a
## living thing and a machine, and no description said "car", so every
## check told the bench's car to shape a creature's body with eyes and
## talons and never named the car advice.
static func traits_of(about: String) -> Dictionary:
	# A hyphenated word is one word: "whale-tail" names no whale.
	var joined: String = RegEx.create_from_string("(?<=\\w)-(?=\\w)").sub(about.to_lower(), "", true)
	var found: Dictionary = {}
	for one: String in TRAITS:
		if not SubjectWords.first_named(joined, TRAITS[one]).is_empty():
			found[one] = true
	if found.is_empty() and is_tower(about):
		found["tower"] = true
	return found


## The living things that are not creatures: no limbs to put on joints.
const PLANTS: Array = ["tree", "flower", "plant", "bonsai", "tree trunk", "mushroom"]
## What gives a thing a face, and so a character's build: a chair with eyes
## and lashes, a paperclip with brows, a toilet that grins. Not "face" or
## "mouth" alone, which a clock, a cliff and a river have.
const FACE_WORDS: Array = ["eyes", "eyebrows", "eyelashes", "eyelids", "moustache",
	"mustache", "grin", "grinning", "smile", "smiling", "frown", "frowning", "googly"]


## Whether [param about] is a figure, a creature or a character, which a set
## builds of sub-assemblies on joints: "figure" for a person or a character
## of one, "creature" for an animal, "face" for a thing given a face; "" for
## anything else. A hyphenated word is its last part, which is what it is
## (a balloon-dog is a dog; a Porsche's whale-tail is a tail, and its
## rear-engine an engine, neither a creature).
static func character_of(about: String) -> String:
	var heads: String = RegEx.create_from_string("\\b(?:\\w+-)+(\\w+)\\b").sub(
		about.to_lower(), "$1", true)
	# A vehicle named before any person is the subject, its driver or crew its
	# crew: the bench's fire engine "with a firefighter" and its Porsche "at
	# minifigure scale" were told, in every check, that they were figures with
	# nothing on a joint. People named first are the subject, at a bus stop or
	# at the wheel.
	var said: PackedStringArray = SubjectWords.of(heads)
	var vehicle: int = _first_at(said, TRAITS["vehicle"])
	var person: int = _first_at(said, TRAITS["figure"])
	if vehicle >= 0 and (person < 0 or vehicle < person):
		return ""
	if not SubjectWords.first_named(heads, TRAITS["figure"]).is_empty():
		return "figure"
	var creatures: Array = (TRAITS["living"] as Array).filter(func(word: Variant) -> bool:
		return not PLANTS.has(word) and str(word) != "bust")
	if not SubjectWords.first_named(heads, creatures).is_empty():
		return "creature"
	if not SubjectWords.first_named(heads, FACE_WORDS).is_empty():
		return "face"
	return ""


## Where a character stands, rather than what one is: with a building
## (SurfacePass.BUILT_WORDS) or a tower (TOWER_WORDS), a place a set is a
## scene of.
const PLACE_WORDS: Array = ["pyramid", "river", "jungle", "world", "island", "village",
	"town", "city", "street", "camp", "ruins", "cave", "forest", "garden", "park", "farm",
	"harbour", "harbor", "room", "office", "scene", "diorama", "vignette", "clearing",
	"skyline", "stage", "studio", "spa", "beach", "desert", "landscape", "yard", "market",
	"arena", "lair", "swamp", "valley", "mountain", "lake"]
## Where a phrase's first noun phrase ends: what its head noun is the last word before.
const PHRASE_ENDS: Array = [" in ", " of ", " with ", " on ", " at ", " for ", " from ",
	" that ", " which ", " who ", " where ", " beside ", " by ", " under ", " over ",
	" near ", " inside ", " and "]


## The word a name or a description is headed by, as English heads one: the
## last noun of its first noun phrase. "Scorpion Pyramid" is a pyramid,
## "Micro World - The End" a world, "A jungle camp in the style of..." a camp.
static func head_noun(phrase: String) -> String:
	var text: String = RegEx.create_from_string("\\b(?:\\w+-)+(\\w+)\\b").sub(
		phrase.to_lower(), "$1", true)
	for stop: String in [",", ":", ";", ".", "(", " - ", " – ", " — ", "!", "?"]:
		var at: int = text.find(stop)
		if at >= 0:
			text = text.left(at)
	text = " %s " % text
	for end: String in PHRASE_ENDS:
		var at: int = text.find(end)
		if at >= 0:
			text = text.left(at)
	var words: PackedStringArray = SubjectWords.of(text)
	return words[words.size() - 1] if not words.is_empty() else ""


## Whether the character [param about] names is in a scene, or on a vehicle,
## rather than the subject: a name or a description of it ([param titles])
## headed by a place, a building or a vehicle, or a place or a building named
## in [param about] before any person or creature. A scene with a statue in it
## was sent back as a figure, and dropped its body (Scorpion Pyramid, Jungle
## River, Micro World - The End, Dino Explorer; the real-set test, 2026-10-16).
static func in_a_scene(about: String, titles: Array) -> bool:
	var places: Array = PLACE_WORDS + SurfacePass.BUILT_WORDS + TOWER_WORDS
	var settings: Dictionary = {}
	for word: Variant in places + (TRAITS["vehicle"] as Array):
		settings[str(word)] = true
	for title: Variant in titles:
		var head: String = head_noun(str(title))
		if not head.is_empty() and not SubjectWords.kind_of_word(head, settings).is_empty():
			return true
	var said: PackedStringArray = SubjectWords.of(RegEx.create_from_string(
		"\\b(?:\\w+-)+(\\w+)\\b").sub(about.to_lower(), "$1", true))
	var creatures: Array = (TRAITS["living"] as Array).filter(func(word: Variant) -> bool:
		return not PLANTS.has(word) and str(word) != "bust")
	var place: int = _first_at(said, places)
	var who: int = _first_at(said, (TRAITS["figure"] as Array) + creatures)
	return place >= 0 and (who < 0 or place < who)


## Where in [param said] (a brief's words) a word or phrase of [param
## vocabulary] first comes, as SubjectWords names it; -1 for nowhere.
static func _first_at(said: PackedStringArray, vocabulary: Array) -> int:
	var best: int = -1
	for raw: Variant in vocabulary:
		var want: PackedStringArray = SubjectWords.of(str(raw))
		if want.is_empty():
			continue
		for start: int in said.size() - want.size() + 1:
			if best >= 0 and start >= best:
				break
			var all: bool = true
			if want.size() == 1:
				all = not SubjectWords.kind_of_word(said[start], {want[0]: true}).is_empty()
			else:
				for k: int in want.size():
					if not SubjectWords.forms(said[start + k]).has(want[k]):
						all = false
						break
			if all:
				best = start
				break
	return best


## What a body the shape pattern laid is told under these shares.
const SHAPED_KEEP := ("the body the shape laid, kept: its core is plain bricks inside, "
	+ "which these shares count, so work on what shows — the features, edit_model on its "
	+ "outside, the surface pass, or the shape said again with its numbers changed — "
	+ "rather than building the body again by hand")


## The calls to name, for what the subject is and what the measures said.
## Each is one call, named, because designs take up a technique when it is
## one call they are told of.
static func calls_for(traits: Dictionary, found: Dictionary, band: Dictionary,
		about: String, shaped: bool = false) -> PackedStringArray:
	var calls := PackedStringArray()
	# A body the shape pattern laid is not told to say one. Told to under these
	# same shares — its hidden core is plain bricks — both cars of the cabins
	# round judged their shaped body a pile of bricks and built the car again
	# by hand: likeness 3, both.
	if shaped and (traits.has("vehicle") or traits.has("living")):
		calls.append(SHAPED_KEEP)
	var low_snot: bool = found.has("snot") and band.has("snot") \
		and float(found["snot"]) < float((band["snot"] as Array)[0])
	var plain: bool = found.has("plain") and band.has("plain") \
		and float(found["plain"]) > float((band["plain"] as Array)[2])
	var low_angle: bool = found.has("angled") and band.has("angled") \
		and float(found["angled"]) < float((band["angled"] as Array)[0])
	if traits.has("round"):
		calls.append("the round pattern, for whatever is round in section here — "
			+ "round bricks, cylinder halves and corner rounds up one axis, with "
			+ "bands of colour, cones, Technic struts and a nose, upright or lying "
			+ "along x; a round of square bricks is the commonest way a model "
			+ "here has looked like a pile of them")
	if traits.has("vehicle"):
		if not shaped:
			calls.append("the shape pattern, for a body that is not a box — a car's, a "
				+ "hull, a fuselage — said as its solids (a side profile extruded, a "
				+ "loft through sections, a revolve), which lays its slopes, curved "
				+ "slopes, wedge plates and tiles for you. On wheels, it stands on "
				+ "something: the chassis plates and the wheel units first, as bricks, "
				+ "then the shape with its at.y on the chassis's top, and a box cut "
				+ "round each wheel's whole box (a round cut leaves the tyre's corners "
				+ "in the body, and the check refuses the overlap) — a shape raised "
				+ "over nothing floats")
		calls.append("for a vehicle: wedge plates where an edge runs at a slant "
			+ "(show_technique \"smooth diagonal\"), curved slopes over a bonnet, a "
			+ "hull or a cab roof, studs_out for a smooth side panel, a section "
			+ "on a hinge (hinge: true) for a windscreen, a ramp or a hatch that "
			+ "opens, and its face as lamps and a grille (show_technique "
			+ "\"headlamps and grille\")")
	# A figure, a creature or a character is sub-assemblies on joints, not a
	# shape: this said "the shape pattern, for a creature's body and head", the
	# figures guide said the opposite, and the attach round's balloon dog was
	# told both in one reply and built a stack of round bricks.
	if not character_of(about).is_empty():
		calls.append("for a figure, a creature or a character: its head, body and limbs "
			+ "sub-assemblies of shaped parts (curved slopes, wedges and round bricks for a "
			+ "body, nothing square that is not), each on a joint at its pose's angle — "
			+ "place_technique \"posed minifigure\", \"jointed figure\", \"jointed animal\", "
			+ "\"limb on a clip\", \"ball shoulder\", \"head on a neck\", \"tail on a bar\", "
			+ "\"hinged wing\" — and the shape pattern only for a body that is a hull (a "
			+ "whale's); its face in features, each a part — show_technique \"round "
			+ "face\", \"eye with a highlight\", \"beak or snout\", \"ears or tufts\"")
	elif traits.has("living"):
		calls.append("for a living thing: curved slopes and wedges for a body, "
			+ "sections on hinges for wings, ears and limbs, the rock pattern for "
			+ "anything rough, and nothing square that is not; its face in "
			+ "features, each a part — show_technique \"round face\", \"eye with a "
			+ "highlight\", \"beak or snout\", \"ears or tufts\", \"talons\"")
	if traits.has("machine"):
		calls.append("for a machine: Technic beams pinned to Technic bricks for "
			+ "arms and frames, a section on a hinge for a joint, grille tiles, "
			+ "round plates and levers for the machinery's texture")
	if traits.has("mechanism"):
		calls.append("for a mechanism — an orrery, an automaton: a gear train from "
			+ "one crank, Technic gears on axles through Technic bricks at the gears' "
			+ "own spacing; what moves carried on arms off the turning axles, a planet "
			+ "on a beam at its distance out; a heavy, wide base for it to turn on; a "
			+ "counterweight opposite a long arm so it balances")
	if not calls.is_empty():
		return calls
	# A building, a tower, a castle — or nothing the words said.
	if low_snot or plain:
		calls.append("restyle_model, for the plain faces already built")
	if low_angle:
		# A tower is told of the clustered form by name. Run 14 had four piers
		# round a core rising into horns and built them square, by hand, with
		# the prism named here for a pier: nothing at an angle.
		if traits.has("tower") or is_tower(about):
			calls.append("a prism with piers, for a tower like this one — {\"pattern\": "
				+ "\"prism\", ..., \"sides\": 8, \"open\": 3, \"piers\": {\"count\": 4, "
				+ "\"courses\": a fifth more than the core's}}: faceted piers clustered "
				+ "round a many-sided core, deep clefts between them, rising past its "
				+ "summit into horns")
		else:
			calls.append("a prism pattern, for a tower, a pier or a turret that should have more than four sides")
	return calls


## Whether a brief is of a tower: what a clustered prism is for.
static func is_tower(about: String) -> bool:
	# Whole words: a shopkeeper is not a keep, and "inspired" not a spire.
	return not SubjectWords.first_named(about, TOWER_WORDS).is_empty()


const TOWER_WORDS: Array = ["tower", "orthanc", "keep", "spire", "turret", "minaret",
	"lighthouse", "citadel", "barad", "pinnacle", "watchtower", "belltower"]


static func _share(value: Variant) -> String:
	return "%d%%" % int(round(float(value) * 100.0))
