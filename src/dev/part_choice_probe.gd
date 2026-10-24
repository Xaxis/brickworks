## The parts a design is handed for its words, judged on words nobody tuned on.
##
##   godot --headless --path . --script src/dev/part_choice_probe.gd
##
## An expert's walk of an MCP design found the designer handed wrong parts
## by name (walk180, 2026-10-23): add_minifig's "smile" was a baby's head and
## "grin" SpongeBob's, arms stayed red on a black torso, a captain hat that
## did not fit had nothing offered in its place; a tug's hull was nineteen
## of an LDraw part kept only for old files, 3660a, "(Obsolete)", which the
## parts list and the BrickLink order then carried; plan_scale made a 20 m
## tug 60 studs; and how_real_sets_build_this knew no "tugboat". Each is
## measured here over descriptions, parts and subjects written before the
## fix and not those of the walk:
##
## figures: 32 everyday figures. A head no generic set carries (a licence's
## or a named cast's, by assets/knowledge/minifig_sets.json) or of another
## mould than the classic head, for words that ask for neither; arms in a
## colour no official figure puts with that torso; and, under a roof half
## way up the hat, a refusal that offers no headgear which then stands.
## stale: every part a design, a search_parts or the palette can place. One
## LDraw keeps only for old files — an alias, an obsolete mould, a "~" part —
## where a current part of the same shape and size exists.
## scale: plan_scale's minifigure length for 14 vehicles and buildings, each
## within the range of the official minifigure-scale models of its kind in
## assets/knowledge/set_sizes.json, chosen here by their own names.
## kinds: how_real_sets_build_this for 20 subjects.
## colours: every part LDraw draws in one colour only, kept for old files
## (303923, "~_Slope Brick 45 2 x 2 Blue (Obsolete)"), placed by a design and
## opened from a file as the part it draws, in that colour (3039 in blue).
##
## `-- figures`, `-- stale`, `-- scale`, `-- kinds` or `-- colours` runs one.
extends SceneTree

## [description, add_minifig's arguments as a session writes them].
const FIGURES: Array = [
	["pirate captain", {"headwear": "pirate hat", "head": "eyepatch", "torso": "pirate", "accessory": "sword"}],
	["smiling chef", {"headwear": "chef hat", "head": "smile", "torso": "chef"}],
	["old fisherman with beard", {"headwear": "knit cap", "head": "beard", "torso": "sweater", "accessory": "fishing rod"}],
	["astronaut", {"headwear": "space helmet", "torso": "space", "back": "airtanks"}],
	["knight with helmet", {"headwear": "knight helmet", "torso": "armour", "accessory": "sword", "accessory_left": "shield"}],
	["firefighter", {"headwear": "fire helmet", "torso": "fire", "accessory": "axe"}],
	["police officer", {"headwear": "police hat", "head": "sunglasses", "torso": "police"}],
	["doctor", {"head": "glasses", "torso": "doctor", "colors": {"torso": 15, "legs": 15}}],
	["farmer", {"headwear": "straw hat", "head": "smile", "torso": "overalls", "accessory": "pitchfork"}],
	["construction worker", {"headwear": "construction helmet", "torso": "safety vest", "accessory": "shovel"}],
	["wizard", {"headwear": "wizard hat", "head": "long beard", "neck": "beard", "accessory": "staff", "colors": {"torso": 1, "legs": 1}}],
	["happy girl with ponytail", {"headwear": "ponytail", "head": "female smile", "colors": {"torso": 5}}],
	["grumpy old man", {"headwear": "grey hair", "head": "frown", "colors": {"torso": 28, "legs": 72}}],
	["scientist", {"headwear": "messy hair", "head": "glasses", "torso": "lab coat"}],
	["mail carrier", {"headwear": "cap", "head": "smile", "torso": "mail", "colors": {"torso": 1}}],
	["lifeguard", {"head": "sunglasses", "torso": "lifeguard", "colors": {"torso": 4, "legs": 4}}],
	["skier", {"headwear": "beanie", "head": "goggles", "footwear": "skis", "colors": {"torso": 2}}],
	["diver", {"headwear": "diving mask", "back": "airtanks", "footwear": "flippers", "colors": {"torso": 0, "legs": 0}}],
	["cowboy", {"headwear": "cowboy hat", "head": "moustache", "torso": "vest", "accessory": "lasso"}],
	["soldier", {"headwear": "army helmet", "head": "stern", "colors": {"torso": 2, "legs": 2}}],
	["airline pilot", {"headwear": "pilot cap", "head": "smile", "torso": "pilot"}],
	["mechanic", {"headwear": "cap", "head": "grin", "torso": "overalls", "accessory": "wrench"}],
	["baker", {"headwear": "chef hat", "head": "happy", "torso": "apron", "accessory": "baguette"}],
	["viking", {"headwear": "viking helmet", "head": "beard", "accessory": "axe", "colors": {"torso": 70}}],
	["tourist with camera", {"headwear": "sun hat", "head": "smile", "accessory": "camera", "colors": {"torso": 14}}],
	["painter", {"headwear": "beret", "head": "moustache", "accessory": "paintbrush", "colors": {"torso": 15}}],
	["gardener", {"headwear": "straw hat", "head": "smile", "torso": "apron", "accessory": "shovel"}],
	["train conductor", {"headwear": "conductor hat", "head": "smile", "colors": {"torso": 272, "legs": 272}}],
	["nurse", {"headwear": "nurse hat", "head": "female", "torso": "nurse"}],
	["sailor", {"headwear": "sailor hat", "head": "grin", "torso": "sailor"}],
	["laughing child", {"head": "laughing", "legs": "short", "colors": {"torso": 25}}],
	["angry guard", {"headwear": "helmet", "head": "angry", "accessory": "spear", "colors": {"torso": 71}}],
	["surprised shopkeeper", {"head": "surprised", "torso": "apron", "colors": {"torso": 0}}],
	["deckhand in a life jacket", {"headwear": "helmet", "neck": "life jacket", "head": "happy", "colors": {"torso": 0, "legs": 72}}],
]
## The words that ask for a head of another mould than the classic one.
const OTHER_MOULD_WORDS: Array[String] = ["baby", "toddler", "infant", "child", "kid",
	"robot", "alien", "skull", "skeleton", "animal", "droid"]
## Those of FIGURES whose hats are tried under a low roof.
const UNDER_A_ROOF: Array[String] = ["pirate captain", "smiling chef", "wizard", "cowboy",
	"firefighter", "police officer", "airline pilot", "train conductor", "nurse", "viking"]

## [what plan_scale is asked, metres, the official models of its kind, by
## their names in set_sizes.json (a regular expression over set and model
## name), and the themes that are minifigure scale for it].
const SCALE: Array = [
	["fire engine", 10.0, "(?i)fire (engine|truck|tender)|ladder truck|pumper"],
	["police car", 4.9, "(?i)police (car|cruiser|patrol car)|squad car|patrol car"],
	["city bus", 12.0, "(?i)\\bbus\\b"],
	["airliner", 40.0, "(?i)airliner|jet ?liner|passenger (jet|plane)|airbus|jumbo"],
	["helicopter", 12.0, "(?i)helicopter|copter|chopper"],
	["tow truck", 8.0, "(?i)tow ?truck|wrecker|recovery"],
	["ambulance", 6.0, "(?i)ambulance"],
	["dump truck", 9.0, "(?i)dump(er)? truck|tipper|garbage truck|rubbish|refuse"],
	["petrol station", 20.0, "(?i)gas station|petrol|service station|filling station|fuel"],
	["fire station", 25.0, "(?i)fire (station|house)"],
	["police station", 30.0, "(?i)police (station|headquarters|hq)"],
	["steam locomotive", 20.0, "(?i)steam|locomotive|loco\\b"],
	["family house", 12.0, "(?i)\\b(house|home|cottage)\\b"],
	["space shuttle", 37.0, "(?i)shuttle"],
	["farm tractor", 4.5, "(?i)tractor"],
]

## Subjects how_real_sets_build_this is asked about.
const KINDS: Array[String] = ["lighthouse", "windmill", "bulldozer", "forklift", "hovercraft",
	"snowmobile", "speedboat", "limousine", "motorbike", "skyscraper", "hospital", "church",
	"igloo", "satellite", "cinema", "museum", "zoo", "stagecoach", "campervan", "rowing boat"]

var _failures: int = 0
var library: PartLibrary
var world: BrickWorld
var builder: Builder
var assistant: Assistant
var _figure_data: Dictionary = {}


func _initialize() -> void:
	library = PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	world = BrickWorld.new()
	world.library = library
	root.add_child(world)
	builder = Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	assistant = Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	Minifig.shelf_file = "user://part_choice_probe_shelf.json"
	await process_frame
	var only: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ""
	if only.is_empty() or only == "figures":
		await _figures()
	if only.is_empty() or only == "stale":
		await _stale()
	if only.is_empty() or only == "scale":
		await _scale()
	if only.is_empty() or only == "kinds":
		await _kinds()
	if only.is_empty() or only == "colours":
		await _colours()
	assistant.queue_free()
	await process_frame
	print("\n%s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


static func _json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


# -- figures ------------------------------------------------------------------


func _figures() -> void:
	print("\nfigures: %d everyday descriptions" % FIGURES.size())
	_figure_data = _json("res://assets/knowledge/minifig_sets.json")
	var carried: Dictionary = _figure_data.get("parts", {})
	var plain_arms: Dictionary = _figure_data.get("plain_arms", {})
	_check("the official sets' figures are read: %d parts, %d torso colours"
		% [carried.size(), plain_arms.size()], carried.size() > 1000 and plain_arms.size() > 10)
	var character_heads: int = 0
	var unknown_heads: int = 0
	var odd_arms: int = 0
	var unknown_arms: int = 0
	var character_other: int = 0
	for row: Array in FIGURES:
		var said: String = row[0]
		var args: Dictionary = (row[1] as Dictionary).duplicate(true)
		args["name"] = said
		var made: Array = FigureTool.figure_for(args, library)
		var figure: Minifig = made[0]
		var head: String = figure.part("head")
		var asked_mould: bool = false
		for word: String in OTHER_MOULD_WORDS:
			if (" %s %s " % [said, str(args.get("head", ""))]).contains(word):
				asked_mould = true
		var head_says: String = _provenance(head, carried)
		var mould: String = Minifig._family(head)
		var odd_mould: bool = not head.is_empty() and not mould.begins_with("3626") and not asked_mould
		if head_says == "character" or odd_mould:
			character_heads += 1
		elif head_says == "unknown" and args.has("head"):
			unknown_heads += 1
		# The other parts chosen by words: what is worn, held and printed.
		var others := PackedStringArray()
		for slot: String in ["headwear", "torso", "neck", "accessory", "accessory_left", "back"]:
			if args.has(slot) and _provenance(figure.part(slot), carried) == "character":
				others.append("%s %s" % [slot, figure.part(slot)])
		character_other += others.size()
		# Arms against the torso, as official figures pair them.
		var torso: String = figure.part("torso")
		var torso_colour: int = int(figure.colours["torso"])
		var arm_colour: int = int(figure.colours["arms"])
		var arms_ok: String = "unknown"
		if Minifig._family(figure.part("arms")) != Minifig.ARM_RIGHT:
			arms_ok = "yes"      # another arm altogether: a skeleton's, a wing
		elif torso == "973":
			var pairs: Array = plain_arms.get(str(torso_colour), [])
			if not pairs.is_empty():
				arms_ok = "no"
				for pair: Array in pairs:
					if int(pair[0]) == arm_colour:
						arms_ok = "yes"
		elif MinifigData.TORSO_HANDS.has(torso):
			var want: int = int((MinifigData.TORSO_HANDS[torso] as Array)[0])
			arms_ok = "yes" if (torso_colour if want < 0 or want == 16 else want) == arm_colour else "no"
		if arms_ok == "no":
			odd_arms += 1
		elif arms_ok == "unknown":
			unknown_arms += 1
		var info: PartLibrary.PartInfo = library.parts.get(head)
		print("    %-28s head %-10s %-9s %s | torso %s in %d, arms in %d (%s)%s" % [said, head,
			head_says + (" mould" if odd_mould else ""),
			info.name.substr(0, 46) if info != null else "",
			torso, torso_colour, arm_colour, arms_ok,
			"" if others.is_empty() else " | character " + ", ".join(others)])
	print("  heads of a licence, a named cast or another mould: %d of %d (unknown to the sets: %d)"
		% [character_heads, FIGURES.size(), unknown_heads])
	print("  arms no official figure puts with that torso: %d (unknown: %d)" % [odd_arms, unknown_arms])
	print("  other parts of a licence or a named cast, for generic words: %d" % character_other)
	_check("no head of a licence, a named cast or another mould for generic words: %d"
		% character_heads, character_heads == 0)
	_check("no arms in a colour no official figure puts with the torso: %d" % odd_arms, odd_arms == 0)
	await _under_a_roof()


## "character" for a part only sets of a licence or a named cast carry (at
## least half of them), "generic", or "unknown" where no set is known to.
static func _provenance(part_id: String, carried: Dictionary) -> String:
	if part_id.is_empty():
		return "generic"
	var known: Variant = carried.get(part_id)
	if not known is Array:
		return "unknown"
	var sets: int = int((known as Array)[0])
	var generic: int = int((known as Array)[1])
	return "character" if generic * 2 < sets else "generic"


## Each tall hat under a roof half way up it: refused, and what is offered
## instead must be a headgear that then stands there.
func _under_a_roof() -> void:
	print("\n  under a roof half way up the hat")
	var without: int = 0
	var refused: int = 0
	var spot: int = 0
	for row: Array in FIGURES:
		if not UNDER_A_ROOF.has(str(row[0])):
			continue
		var args: Dictionary = (row[1] as Dictionary).duplicate(true)
		args["name"] = "%s %d" % [row[0], spot]
		var made: Array = FigureTool.figure_for(args, library)
		var figure: Minifig = made[0]
		var bare: Minifig = figure.copy()
		bare.parts["headwear"] = ""
		bare.parts["hat_extra"] = ""
		var top_hat: float = _top(figure)
		var top_bare: float = _top(bare)
		if top_hat - top_bare < 6.0:
			print("    %-20s its hat is not tall enough to test (%.0f LDU)" % [row[0], top_hat - top_bare])
			continue
		var x: int = 40 + spot * 8
		spot += 1
		# The floor, and a roof whose underside is half way up the hat.
		var floor_at := Transform3D(Basis.IDENTITY, Vector3(x * 20.0 + 40.0, 24.0, 100.0))
		var floor_id: int = world.add_brick("3001", 15, floor_at)
		builder.register(floor_id, "3001", floor_at)
		var under: float = 24.0 + top_bare + (top_hat - top_bare) * 0.5
		var roof_at := Transform3D(Basis.IDENTITY, Vector3(x * 20.0 + 20.0, snappedf(under + 8.0, 2.0), 90.0))
		var roof_id: int = world.add_brick("3958", 1, roof_at)
		builder.register(roof_id, "3958", roof_at)
		var call: Dictionary = args.duplicate(true)
		call.merge({"x": x, "z": 4, "y": 3})
		var said: String = str(await assistant.use_tool("add_minifig", call))
		if said.begins_with("Placed"):
			print("    %-20s stood under it: %s" % [row[0], said.substr(0, 90)])
			continue
		refused += 1
		var offered: RegExMatch = RegEx.create_from_string("headwear \"([^\"]+)\"").search(said)
		var stands: bool = false
		if offered != null and offered.get_string(1) != "none":
			call["headwear"] = offered.get_string(1)
			var again: String = str(await assistant.use_tool("add_minifig", call))
			stands = again.begins_with("Placed")
		if not stands:
			without += 1
		print("    %-20s refused; offers %s%s" % [row[0],
			"headwear \"%s\"" % offered.get_string(1) if offered != null else "no headgear",
			", which stands" if stands else ""])
	print("  refused with no headgear offered that stands: %d of %d refused" % [without, refused])
	_check("every tall hat refused under the roof is offered one that stands: %d without" % without,
		refused > 0 and without == 0)


## How high a figure reaches above the studs it stands on, in LDU.
func _top(figure: Minifig) -> float:
	var top: float = 0.0
	for item: Dictionary in figure.assemble(library):
		var info: PartLibrary.PartInfo = library.parts.get(str(item["part"]))
		if info == null:
			continue
		var box: AABB = ((item["at"] as Transform3D) * info.bounds).abs()
		top = maxf(top, box.end.y)
	return top


# -- stale parts -----------------------------------------------------------------


## LDraw's name for a part it keeps only for old files: an alias ("="), an
## obsolete mould, a "~" part.
static func _is_old(info: PartLibrary.PartInfo) -> bool:
	var name: String = info.name.strip_edges()
	return not info.is_redirect() and (name.begins_with("~") or name.begins_with("=")
		or info.category == "Obsolete" or name.contains("(Obsolete)"))


## What a part's name says it is, before what it is with: "slope brick 45 2 x
## 2 inverted" for every 3660.
static func _family(info: PartLibrary.PartInfo) -> String:
	var name: String = info.name.to_lower().replace("(obsolete)", "").replace("(complete)", "")
	name = name.lstrip("~=_ ")
	for cut: String in [" with ", " without ", " ("]:
		var at: int = name.find(cut)
		if at > 0:
			name = name.substr(0, at)
	return " ".join(name.split(" ", false))


func _same_box(a: PartLibrary.PartInfo, b: PartLibrary.PartInfo) -> bool:
	return a.bounds.position.distance_to(b.bounds.position) <= 1.0 \
		and a.bounds.end.distance_to(b.bounds.end) <= 1.0


func _stale() -> void:
	print("\nstale: every part a design can place")
	# What a design's part becomes when it is placed: by the call the app
	# makes where it has one, and LDraw's redirects otherwise.
	var placed_as := func(id: String) -> String:
		return str(library.call("current", id)) if library.has_method("current") else library.resolve(id)
	var current: Array[PartLibrary.PartInfo] = []
	var by_mesh: Dictionary = {}
	var by_family: Dictionary = {}
	for id: String in library.ids():
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.is_redirect() or _is_old(info) or not info.reachable or info.custom:
			continue
		current.append(info)
		if not by_mesh.has(info.mesh_hash):
			by_mesh[info.mesh_hash] = []
		(by_mesh[info.mesh_hash] as Array).append(info)
		var family: String = _family(info)
		if not by_family.has(family):
			by_family[family] = []
		(by_family[family] as Array).append(info)
	# The stale parts a current part of the same shape and size stands for.
	var twinned: Dictionary = {}
	for id: String in library.ids():
		var info: PartLibrary.PartInfo = library.parts[id]
		if not _is_old(info) or not info.reachable:
			continue
		var twin: bool = by_mesh.has(info.mesh_hash)
		if not twin:
			for other: PartLibrary.PartInfo in by_family.get(_family(info), []):
				# A print's twin is its own drawing (the same mesh): another
				# print of the mould is another picture.
				if _same_box(info, other) and other.decor() == 0 and info.decor() == 0:
					twin = true
					break
		if twin:
			twinned[id] = true
	print("  %d parts LDraw keeps only for old files have a current twin" % twinned.size())
	# Every number a design can say, as the design path places it.
	var stale_placed := PackedStringArray()
	var shape_changed := PackedStringArray()
	for id: String in library.ids():
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.custom:
			continue
		var final: String = library.resolve(id)
		if not twinned.has(final):
			continue
		var becomes: String = placed_as.call(id)
		var got: PartLibrary.PartInfo = library.parts.get(becomes)
		if got == null or _is_old(got) or got.is_redirect():
			stale_placed.append("%s->%s" % [id, becomes])
		elif not _same_box(library.parts[final], got):
			shape_changed.append("%s->%s" % [id, becomes])
	print("  placed as a part kept only for old files: %d %s" % [stale_placed.size(),
		", ".join(stale_placed.slice(0, 12))])
	print("  placed as a part of another shape or size: %d %s" % [shape_changed.size(),
		", ".join(shape_changed.slice(0, 12))])
	_check("no number a design can say is placed as a part kept only for old files "
		+ "where a current twin exists: %d" % stale_placed.size(), stale_placed.is_empty())
	_check("...and none as a part of another size: %d" % shape_changed.size(), shape_changed.is_empty())
	var tug: String = placed_as.call("3660")
	var tug_info: PartLibrary.PartInfo = library.parts.get(tug)
	_check("the tug's 3660 is placed as %s %s" % [tug, tug_info.name if tug_info != null else ""],
		tug_info != null and not _is_old(tug_info) and tug.begins_with("3660"))

	# The design path itself: a check of the tug's hull reads 3660 as it builds it.
	var hull: Variant = await assistant.use_tool("check_design", {"name": "hull", "bricks": [
		{"part": "3660", "color": 4, "x": 4, "y": 1, "z": 1},
		{"part": "3660a", "color": 4, "x": 8, "y": 1, "z": 1}]})
	var hull_text: String = str(hull)
	print("    check_design: %s" % hull_text.substr(0, 200).replace("\n", " | "))
	var model: Assistant.Model = assistant._read_model({"name": "hull", "bricks": [
		{"part": "3660", "color": 4, "x": 4, "y": 1, "z": 1},
		{"part": "3660a", "color": 4, "x": 8, "y": 1, "z": 1}]})
	var read: PackedStringArray = []
	for placement: Assistant.Placement in model.placements:
		read.append(library.resolve(placement.part))
	_check("a design's 3660 and 3660a are read as %s" % ", ".join(read),
		read.size() == 2 and not _is_old(library.parts[read[0]]) and not _is_old(library.parts[read[1]]))

	# What a search offers: search_parts and the palette, by every stale
	# part's own words and by the words a builder types.
	var queries := PackedStringArray(["slope inverted 2x2", "slope 45 2 x 2 inverted",
		"minifig hand", "plate 3x6 without corners", "minifig helmet modern", "tail fin",
		"technic gearbox", "minifig flipper", "plant grass stem", "magnet",
		"window 1x3x2 classic", "hinge plate 1x2 locking", "boat bow", "minifig hips",
		"minifig snowshoe", "brick 1x1 round", "technic shock absorber"])
	var offered_stale := PackedStringArray()
	var bin_stale := PackedStringArray()
	var bin := PartsBin.new()
	bin.library = library
	for query: String in queries:
		for info: PartLibrary.PartInfo in library.search(query, 20):
			if twinned.has(info.id):
				offered_stale.append("%s:%s" % [query, info.id])
		var shown: Array[PartLibrary.PartInfo] = bin._find(query, "all")
		for info: PartLibrary.PartInfo in shown.slice(0, 40):
			if twinned.has(info.id):
				bin_stale.append("%s:%s" % [query, info.id])
	var said_stale: int = 0
	var asked: int = 0
	for id: String in twinned:
		asked += 1
		if asked > 400:
			break
		var words: String = _family(library.parts[id])
		for info: PartLibrary.PartInfo in library.search(words, 10):
			if twinned.has(info.id):
				said_stale += 1
				break
	bin.free()
	print("  search_parts offers a part kept only for old files: %d %s" % [offered_stale.size(),
		", ".join(offered_stale.slice(0, 10))])
	print("  ...by those parts' own words: %d of %d" % [said_stale, mini(asked, 400)])
	print("  the palette shows one: %d %s" % [bin_stale.size(), ", ".join(bin_stale.slice(0, 10))])
	_check("search_parts offers none: %d, and by their own words %d"
		% [offered_stale.size(), said_stale], offered_stale.is_empty() and said_stale == 0)
	_check("the palette's search shows none: %d" % bin_stale.size(), bin_stale.is_empty())


# -- colours -----------------------------------------------------------------------


func _colours() -> void:
	# The catalogue's own word for them, read here rather than through the
	# library: LDraw's "Physical_Colour" parts, drawn in one colour whatever
	# they are placed in.
	var fixed: Dictionary = {}
	for entry: Variant in _json(library._resolve_root() + "catalogue.json").get("parts", []):
		var colours: Array = (entry as Dictionary).get("fixed_colors", [])
		if str(entry.get("kind", "")).contains("Physical_Colour") and colours.size() == 1 \
				and not bool(entry.get("recolourable", true)):
			fixed[str(entry["id"])] = int(colours[0])
	print("\ncolours: %d parts LDraw draws in one colour only" % fixed.size())
	var colour_of := func(id: String) -> int:
		return int(library.call("current_colour", id)) if library.has_method("current_colour") else -1
	# Every part made now that takes any colour, by its box and triangles: what
	# one drawn in one colour shares with the part it draws.
	var made_now: Dictionary = {}
	for id: String in library.ids():
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.recolourable and not info.is_redirect() and not info.custom and not _is_old(info) \
				and not fixed.has(id):
			var key: String = "%s %s %d" % [Vector3i(info.bounds.position.round()),
				Vector3i(info.bounds.end.round()), info.triangles]
			made_now[key] = (made_now.get(key, []) as Array) + [id]
	var mapped: int = 0
	var wrong := PackedStringArray()
	var missed := PackedStringArray()
	var alone: int = 0
	for id: String in fixed:
		var now: String = library.current(id)
		var got: PartLibrary.PartInfo = library.parts.get(now)
		var info: PartLibrary.PartInfo = library.parts[id]
		if now == id:
			var twins: Array = made_now.get("%s %s %d" % [Vector3i(info.bounds.position.round()),
				Vector3i(info.bounds.end.round()), info.triangles], [])
			if twins.is_empty():
				alone += 1
			else:
				missed.append("%s (%s)" % [id, twins[0]])
			continue
		if got == null or _is_old(got) or not got.recolourable \
				or not _same_box(info, got) or colour_of.call(id) != fixed[id]:
			wrong.append("%s->%s in %d" % [id, now, colour_of.call(id)])
			continue
		mapped += 1
	print("  placed as the part they draw, in their colour: %d; wrongly: %d %s" % [mapped,
		wrong.size(), ", ".join(wrong.slice(0, 8))])
	print("  kept as they are, no part made now drawn the same: %d; with one: %d %s" % [alone,
		missed.size(), ", ".join(missed.slice(0, 8))])
	_check("%d of %d are placed as the part they draw, in their colour; the %d left have no "
		% [mapped, fixed.size(), alone] + "part made now drawn as they are",
		mapped > 0 and wrong.is_empty() and missed.is_empty() and mapped + alone == fixed.size())
	_check("303923 is 3039 in blue: %s in %d" % [library.current("303923"), colour_of.call("303923")],
		library.current("303923") == "3039" and colour_of.call("303923") == 1)

	# A design that says it.
	var model: Assistant.Model = assistant._read_model({"name": "roof", "bricks": [
		{"part": "303923", "color": 4, "x": 0, "y": 0, "z": 0}]})
	var placed: Assistant.Placement = model.placements[0] if not model.placements.is_empty() else null
	_check("a design's 303923 in red is placed as %s in %d" % [placed.part if placed != null else "none",
		placed.color if placed != null else -1], placed != null and placed.part == "3039"
		and placed.color == 1)
	# A file that has it: its colour is the part's, whatever the line says.
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	world.clear()
	store.open_text("0 Roof\n1 16 0 -24 0 1 0 0 0 1 0 0 0 1 303923.dat\n"
		+ "1 4 40 -24 0 1 0 0 0 1 0 0 0 1 3039.dat\n", "roof.ldr")
	var opened := PackedStringArray()
	for brick: BrickWorld.Brick in world.bricks():
		opened.append("%s in %d" % [brick.part_id, brick.color_code])
	opened.sort()
	_check("a file's 303923 opens as 3039 in blue, beside its own 3039 in red: %s" % ", ".join(opened),
		opened == PackedStringArray(["3039 in 1", "3039 in 4"]))
	world.clear()
	# And a search offers none of them by their own words.
	var offered := PackedStringArray()
	var asked: int = 0
	for id: String in fixed:
		if library.current(id) == id:
			continue
		asked += 1
		for info: PartLibrary.PartInfo in library.search(library.parts[id].name.lstrip("~_"), 10):
			if fixed.has(info.id) and library.current(info.id) != info.id:
				offered.append(info.id)
				break
	_check("search_parts offers none by their own names: %d of %d" % [offered.size(), asked],
		offered.is_empty())


# -- scale ------------------------------------------------------------------------


func _scale() -> void:
	print("\nscale: plan_scale against the official models of each kind")
	var measured: Array = _json("res://assets/knowledge/set_sizes.json").get("models", [])
	_check("the official models are read: %d" % measured.size(), measured.size() > 200)
	var within: int = 0
	var judged: int = 0
	for row: Array in SCALE:
		var subject: String = row[0]
		var pattern := RegEx.create_from_string(str(row[2]))
		var lengths: Array[float] = []
		var named := PackedStringArray()
		for model: Array in measured:
			var title: String = str(model[3]) if not str(model[3]).is_empty() else str(model[1])
			if pattern.search(title) == null:
				continue
			lengths.append(float(model[5]))
			if named.size() < 4:
				named.append("%s %s %s" % [model[0], title.substr(0, 24), model[5]])
		if lengths.size() < 2:
			print("    %-18s too few official models to judge (%d)" % [subject, lengths.size()])
			continue
		lengths.sort()
		var low: float = lengths[0]
		var high: float = lengths[lengths.size() - 1]
		var said: String = str(await assistant.use_tool("plan_scale",
			{"subject": subject, "longest_metres": row[1]}))
		var studs: float = _minifig_studs(said)
		judged += 1
		var ok: bool = studs >= low and studs <= high
		within += 1 if ok else 0
		print("    %-18s %5.1f m -> %5.1f studs; %d official models %.0f to %.0f (%s) %s" % [
			subject, row[1], studs, lengths.size(), low, high, "; ".join(named),
			"" if ok else "OUTSIDE"])
	print("  within the official models' range: %d of %d" % [within, judged])
	_check("plan_scale is within the official models of its kind for all %d judged: %d"
		% [judged, within], judged >= 10 and within == judged)


## The minifigure row's length in a plan_scale answer.
static func _minifig_studs(said: String) -> float:
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^\\s*minifigure\\s+([\\d.]+) studs").search(said)
	return float(found.get_string(1)) if found != null else -1.0


# -- kinds of set -------------------------------------------------------------


func _kinds() -> void:
	print("\nkinds: how_real_sets_build_this for %d subjects" % KINDS.size())
	var found: int = 0
	for subject: String in KINDS:
		var said: Variant = await assistant.use_tool("how_real_sets_build_this", {"subject": subject})
		var text: String = str((said as Array)[0]["text"]) if said is Array else str(said)
		var matched: bool = not text.begins_with("No kind of real set")
		found += 1 if matched else 0
		var kinds := PackedStringArray()
		for line: RegExMatch in RegEx.create_from_string("(?m)^([A-Z][A-Z ]+) — measured over").search_all(text):
			kinds.append(line.get_string(1).to_lower())
		print("    %-14s %s" % [subject, ", ".join(kinds) if matched else "no match"])
	print("  found: %d of %d" % [found, KINDS.size()])
	_check("how_real_sets_build_this finds real sets for all %d subjects: %d" % [KINDS.size(), found],
		found == KINDS.size())
