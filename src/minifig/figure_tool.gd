## add_minifig: how a design peoples its scene.
##
## A design says who stands where — "Saruman on the balcony, in white,
## with a staff" — and this makes the figure from real parts and stands
## it there. Each slot takes a part number or a few words, matched
## against the names of the parts that can fill it, so a design does not
## have to know that a wizard's hat is 6131. It stands on whatever is
## under its feet, the way a figure placed by hand does, and is refused
## if anything is in the way or if it would stand in the air.
##
## Kept out of assistant.gd, which only declares it and passes the call
## through: every rule about figures lives in src/minifig/.
class_name FigureTool
extends RefCounted

const STUD := 20.0
const PLATE := 8.0
## Words that say nothing about which part is meant.
const FILLER: Array[String] = ["the", "and", "with", "minifig", "minifigure",
	"figure", "a", "an", "of", "in", "on", "his", "her", "its"]


static func schema() -> Dictionary:
	var slot := func(what: String) -> Dictionary:
		return {"type": "string", "description": what}
	return {
		"name": "add_minifig",
		"description": ("Stand a minifigure in the model, made from real "
			+ "parts in their real places: who lives in it, guards it, "
			+ "works in it — or the subject itself, where the brief asks for "
			+ "a person at minifigure scale (a pilot, a knight on a horse). "
			+ "Add them once what they stand on is built — submitting a "
			+ "whole new design replaces them. Each slot takes a part number "
			+ "or a few words matched against the names of the parts made "
			+ "for it (\"wizard hat\", \"long beard\", \"robe\", \"staff\"); "
			+ "leave a slot out for a plain one. It stands on whatever is "
			+ "highest under its feet, two studs side by side, and is "
			+ "refused if something is in the way. Its parts are not counted "
			+ "in the model's variety, as a set's figures are not."),
		"input_schema": {
			"type": "object",
			"properties": {
				"name": slot.call("who it is; the name of its sub-model in the saved file"),
				"x": {"type": "number", "description":
					"studs: the first of the two studs it stands on"},
				"z": {"type": "number", "description": "studs"},
				"y": {"type": "number", "description":
					"plates: the height of the floor it stands on, which a "
					+ "room or a balcony with anything over it needs; left "
					+ "out, it stands on whatever is highest at that spot"},
				"facing": {"type": "string", "enum": ["+z", "-z", "+x", "-x"],
					"description": "which way its face looks: +z, the default, is towards the front view"},
				"headwear": slot.call("hair, hat or helmet, or \"none\""),
				"hat_extra": slot.call("a visor, plume or feathers fixed onto the headgear"),
				"head": slot.call("a face: \"beard\", \"smile\", \"angry\""),
				"neck": slot.call("armour, a scarf, a beard, a life jacket, or left out"),
				"back": slot.call("airtanks, a backpack, a quiver, wings, or left out"),
				"cape": slot.call("a cape, or left out"),
				"torso": slot.call("what is printed on the chest; an odd body (a battle droid, a skeleton) brings its own head, arms and legs"),
				"arms": slot.call("plain, printed sleeves, or another arm (\"skeleton\", \"wing\")"),
				"hands": slot.call("plain, or a hook, boxing gloves, a prosthetic"),
				"hips": slot.call("a printed belt or sash, or left out"),
				"hipwear": slot.call("a skirt, a tail or a belt over the hips"),
				"legs": slot.call("plain, printed, \"short\" for a child, a wooden leg, a mermaid tail"),
				"footwear": slot.call("flippers, skis, skates, or left out"),
				"accessory": slot.call("what it holds in its right hand"),
				"accessory_left": slot.call("what it holds in its left hand"),
				"colors": {"type": "object", "description": (
					"LDraw colour codes by slot: headwear, hat_extra, head, neck, "
					+ "back, cape, torso, arms, hands, hips, hipwear, legs, "
					+ "footwear, accessory, accessory_left. A printed torso "
					+ "brings arm and hand colours of its own."),
					"additionalProperties": {"type": "integer"}},
			},
			"required": ["name", "x", "z"],
			"additionalProperties": false,
		},
	}


## The figure some arguments describe, and what in them matched
## nothing: [Minifig, PackedStringArray].
static func figure_for(args: Dictionary, library: PartLibrary) -> Array:
	var figure := Minifig.new()
	figure.name = str(args.get("name", "Minifig")).strip_edges()
	var unmatched := PackedStringArray()
	var colours: Dictionary = args.get("colors", {}) if args.get("colors") is Dictionary else {}
	if colours.has("torso"):
		figure.colours["torso"] = int(colours["torso"])
	# The torso first: an odd body brings parts of its own, which what
	# else was asked for then replaces.
	var order: Array[String] = ["torso"]
	for slot: String in Minifig.SLOTS:
		if slot != "torso":
			order.append(slot)
	for slot: String in order:
		if not args.has(slot):
			continue
		var wanted: String = str(args[slot]).strip_edges()
		var found: String = choose(library, slot, wanted)
		if found == "?":
			unmatched.append("%s \"%s\"" % [slot, wanted])
			continue
		figure.choose(library, slot, found)
	for slot: Variant in colours:
		if Minifig.SLOTS.has(str(slot)):
			figure.colours[str(slot)] = int(colours[slot])
	# Arms as official figures wear them with that torso, unless their colour
	# was asked for: told only that its torso was black, a deckhand kept the
	# red arms every figure starts in, which no set puts with black (walk180).
	if not colours.has("arms") and Minifig._family(figure.part("arms")) == Minifig.ARM_RIGHT:
		var torso: String = figure.part("torso")
		var worn: int = int(figure.colours["torso"])
		if torso == "973":
			var paired: int = SetKnowledge.plain_arms(worn)
			figure.colours["arms"] = paired if paired >= 0 else worn
		elif MinifigData.TORSO_HANDS.has(torso):
			var printed: int = int((MinifigData.TORSO_HANDS[torso] as Array)[0])
			figure.colours["arms"] = worn if printed < 0 or printed == 16 else printed
	return [figure, unmatched]


## The part that best answers some words for a slot: "" for none, "?"
## for nothing that matched.
##
## By the words of its name, whole: "cap" is not a captain. Never a part only
## a licence or a named cast wears, nor a head of another mould than the
## classic one, for words that a part of anybody's would answer: matched by
## their names, "smile" was a baby's head, "grin" SpongeBob's and "beard"
## Tony Stark's (walk180, 2026-10-23), since the names say what is printed
## and not whose face it is. The set inventories say whose (SetKnowledge).
## Such a part is the answer only to words no other part has: "spongebob".
## Of the rest, the most words, then the part more sets use, then the one
## that says least besides ("Hat Wizard" before "Hat Wizard with Stars").
static func choose(library: PartLibrary, slot: String, wanted: String) -> String:
	var asked: String = wanted.to_lower().strip_edges()
	if asked.is_empty() or asked == "none" or asked == "nothing":
		return "" if Minifig.OPTIONAL.has(slot) else "?"
	# A run kept to a list of parts (PartsOnly) chooses among those alone.
	var all: Array[PartLibrary.PartInfo] = []
	for info: PartLibrary.PartInfo in Minifig.choices(library, slot):
		if PartsOnly.allows(info.id, library):
			all.append(info)
	for info: PartLibrary.PartInfo in all:
		if info.id == asked:
			return info.id
	if slot == "legs" and (asked.contains("short") or asked.contains("child")):
		return "41879a"
	if asked == "plain":
		var plain: Dictionary = {"head": "3626cp01", "torso": "973",
			"arms": Minifig.ARM_RIGHT, "hands": Minifig.HAND,
			"hips": Minifig.PLAIN_HIPS, "legs": Minifig.PLAIN_LEGS}
		if plain.has(slot):
			return plain[slot]
	var words: Array[PackedStringArray] = []
	for word: String in asked.replace("'s ", " ").replace("'", "").replace(",", " ") \
			.replace("-", " ").split(" ", false):
		if not FILLER.has(word) and word.length() >= 3:
			var forms := PackedStringArray([_singular(word)])
			for other: String in SAID_AS.get(forms[0], []):
				forms.append(other)
			words.append(forms)
	if words.is_empty():
		return "?"
	var best: PartLibrary.PartInfo = null
	var best_key: Array = []
	for info: PartLibrary.PartInfo in all:
		var own: PackedStringArray = _words_of(info.name)
		var matched: int = 0
		for forms: PackedStringArray in words:
			for form: String in forms:
				if own.has(form):
					matched += 1
					break
		if matched == 0:
			continue
		var whose: int = _whose(library, info, slot, words)
		var key: Array = [1 if whose > 0 else 0, matched, whose,
			maxi(SetKnowledge.carried(info.id), info.in_sets), -info.name.length()]
		if best == null or _before(key, best_key):
			best = info
			best_key = key
	return best.id if best != null else "?"


## Lexicographic: [param a] is the better key.
static func _before(a: Array, b: Array) -> bool:
	for n: int in a.size():
		if a[n] != b[n]:
			return a[n] > b[n]
	return false


## 2 for a part anybody's figure wears, 1 where no set is known to carry it,
## 0 for a licence's or a named cast's, or a head of another mould than the
## classic one (a baby's, SpongeBob's, a creature's) unless the words name it.
static func _whose(library: PartLibrary, info: PartLibrary.PartInfo, slot: String,
		words: Array[PackedStringArray]) -> int:
	if slot == "head" and not Minifig._family(info.id).begins_with("3626"):
		var mould: PartLibrary.PartInfo = library.parts.get(Minifig._family(info.id))
		var named: PackedStringArray = _words_of(mould.name if mould != null else info.name)
		for forms: PackedStringArray in words:
			if forms[0] not in ["minifig", "head"] and named.has(forms[0]):
				return SetKnowledge.generic(info.id)
		return 0
	var whose: int = SetKnowledge.generic(info.id)
	# Where no set inventory says, LDraw's own name may: it files a licence's
	# prints under its initials ("Torso with SW Dark Red Robe Pattern").
	if whose == 1:
		for word: String in _words_of(info.name):
			if LICENCE_WORDS.has(word):
				return 0
	return whose


## The words LDraw names a licence's parts by.
const LICENCE_WORDS: Array[String] = ["sw", "hp", "lotr", "lor", "potc", "batman", "marvel",
	"spongebob", "simpsons", "disney", "ninjago", "chima", "nexo", "minecraft", "jurassic",
	"avengers", "superman", "spider", "stark", "vader", "hobbit", "muppet", "mario"]


## A name's words, lower case, each as said and in the singular.
static func _words_of(name: String) -> PackedStringArray:
	var out := PackedStringArray()
	for word: String in name.to_lower().replace("'s ", " ").replace("'", "").replace("/", " ") \
			.replace("-", " ").replace(",", " ") \
			.replace("(", " ").replace(")", " ").split(" ", false):
		out.append(word)
		var one: String = _singular(word)
		if one != word:
			out.append(one)
	return out


static func _singular(word: String) -> String:
	if word.length() > 4 and word.ends_with("es") and word.substr(word.length() - 3, 1) in ["s", "x", "h"]:
		return word.left(-2)
	if word.length() > 3 and word.ends_with("s") and not word.ends_with("ss"):
		return word.left(-1)
	return word


## A word a description says a face with -> the words LDraw names prints by:
## its heads say Smile, Grin, Frown, Scowl, Open Mouth, Raised Eyebrows.
const SAID_AS: Dictionary = {
	"smile": ["grin", "smiling"], "grin": ["smile"],
	"happy": ["smile", "grin", "smiling"], "smiling": ["smile", "grin"],
	"smiley": ["smile"], "cheerful": ["smile", "grin"], "friendly": ["smile"],
	"laughing": ["laugh", "laughing", "open"], "laugh": ["laughing", "open"],
	"angry": ["scowl", "frown", "frowning"], "cross": ["angry", "scowl", "frown"],
	"grumpy": ["frown", "scowl", "annoyed"], "stern": ["determined", "frown"],
	"serious": ["stern", "neutral", "determined"], "sad": ["frown", "worried"],
	"scared": ["worried", "open"], "frightened": ["scared", "worried"],
	"afraid": ["scared", "worried"], "surprised": ["open", "raised", "scared"],
	"shocked": ["scared", "open"], "nervous": ["worried", "scared"],
	"sleepy": ["closed"], "tired": ["closed"], "winking": ["wink"],
	"woman": ["female"], "girl": ["female"], "lady": ["female"],
	"old": ["wrinkles", "grey"], "elderly": ["wrinkles", "grey"],
	"bearded": ["beard"], "mustache": ["moustache"], "moustache": ["mustache"],
	"grey": ["gray"], "gray": ["grey"],
}


## Stand the figure the arguments describe in the world. A coroutine: a
## part not yet to hand is fetched first. Returns {ok, text, ids, box}.
static func add(args: Dictionary, library: PartLibrary, world: BrickWorld,
		builder: Builder) -> Dictionary:
	# Whose parts are whose, and the arms each torso is worn with: fetched on
	# the web the first time a figure is asked for.
	await SetKnowledge.ensure(builder)
	var made: Array = figure_for(args, library)
	var figure: Minifig = made[0]
	var unmatched: PackedStringArray = made[1]
	if figure.name.is_empty():
		figure.name = "Minifig"
	# A part an odd body brings with it, or one named by number, may still be
	# off a run's list of parts (PartsOnly).
	var barred: PackedStringArray = PartsOnly.barred(figure.part_ids(library), library)
	if not barred.is_empty():
		return {"ok": false, "ids": PackedInt64Array(), "box": AABB(),
			"text": "Not placed: %s. Name another for its slot." % PartsOnly.swap_words(
				", ".join(barred))}
	await _fetch(library, figure.part_ids(library))
	for part_id: String in figure.part_ids(library):
		if library.mesh_for(part_id) == null:
			return {"ok": false, "ids": PackedInt64Array(), "box": AABB(),
				"text": "Not placed: %s could not be loaded." % part_id}

	var facing: String = str(args.get("facing", "+z"))
	var rotation: int = _turns_for(facing)
	var x: float = float(args.get("x", 0))
	var z: float = float(args.get("z", 0))
	var along_x: bool = posmod(rotation, 2) == 0
	var centre := Vector3((x + (1.0 if along_x else 0.5)) * STUD, 0.0,
		(z + (0.5 if along_x else 1.0)) * STUD)
	var parts: Array[Dictionary] = parts_of(figure, library)
	# On top of whatever is highest there, unless a height is given: a
	# figure in a room or on a balcony has a roof over it, and the top of
	# the roof is the highest surface under its feet.
	var at: Transform3D = builder.settle_figure(centre, rotation)
	if args.has("y"):
		at.origin.y = float(args["y"]) * PLATE
	var resting_plates: float = at.origin.y / PLATE
	var under_feet: Array[int] = []
	for side: float in [-10.0, 10.0]:
		under_feet.append(builder.lattice.brick_at(
			BrickLattice.to_cell(at * Vector3(side, -1.0, 0.0))))
	if at.origin.y > 0.0 and under_feet.max() == 0:
		return {"ok": false, "ids": PackedInt64Array(), "box": AABB(),
			"text": ("Not placed: nothing to stand on at x %s, z %s, y %s — "
				% [_n(x), _n(z), _n(resting_plates)] + "it would stand in the "
				+ "air. Give the height of a floor that is there, or leave y "
				+ "out to stand it on the highest thing at that spot.")}
	# A figure's head is a stud, and the highest thing under a second
	# figure's feet is the first one's hat: asked for the same spot, a
	# design would stack them. Nobody means that.
	for under: int in under_feet:
		if under != 0 and builder.figure_of(under).size() > 1:
			return {"ok": false, "ids": PackedInt64Array(), "box": AABB(),
				"text": "Not placed: %s is already standing at x %s, z %s."
					% [world.get_brick(under).group, _n(x), _n(z)]}
	# What it holds, clear of the model by its real shape as well as its cover:
	# a rod 1.2 LDU into a bollard's cone fits the lattice and fails Tested.
	var around: Array = _model_near(library, world, at)
	var fits: Callable = func(trial: Array[Dictionary]) -> bool:
		return builder.figure_fits(trial, at) and _held_clear_of(library, trial, at, around)
	if not fits.call(parts):
		parts = turned_to_fit(library, parts, fits)
	if not builder.figure_fits(parts, at):
		var why: String = _in_the_way(parts, at, Vector2(x, z), library, world, builder)
		# Bare-headed it would stand: a lower hat of the kind asked for, which
		# is what a designer reaches for under a wheelhouse roof. Told only to
		# go bare-headed, a session put its captain in a knit cap by guessing,
		# after five refusals (walk180).
		if why.contains(" Without headwear"):
			var lower: String = await _lower_headwear(figure, str(args.get("headwear", "")),
				at, library, builder)
			var info: PartLibrary.PartInfo = library.parts.get(lower)
			if info != null:
				why = why.replace(" Without headwear", (" A lower one stands there: headwear "
					+ "\"%s\" (%s). Without headwear") % [lower, " ".join(info.name.split(" ", false))])
		return {"ok": false, "ids": PackedInt64Array(), "box": AABB(),
			"text": ("Not placed: something is in the way of a figure standing "
				+ "at x %s, z %s, y %s. A figure is two studs wide, one deep "
				% [_n(x), _n(z), _n(resting_plates)]
				+ "and five plates and a head tall; it needs that clear "
				+ "above its feet, and its arms and what it holds a stud "
				+ "either side.") + why}
	var ids: PackedInt64Array = builder.put_figure(parts, figure.name, at)
	var group: String = world.get_brick(ids[0]).group if not ids.is_empty() else figure.name
	figure.name = group
	Minifig.keep(figure)

	var box := AABB()
	var first: bool = true
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		var here: AABB = (brick.transform * mesh.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	var said: String = "Placed %s, %d parts, facing %s, feet on the studs at x %s, z %s, y %s: %s." % [
		group, ids.size(), facing, _n(x), _n(z), _n(resting_plates),
		_describe(figure, library)]
	if not unmatched.is_empty():
		said += " Nothing matched %s, so those are plain." % ", ".join(unmatched)
	for part_id: String in unheld_in_hand(library, parts):
		var info: PartLibrary.PartInfo = library.parts.get(part_id)
		said += (" %s (%s) is in the hand by its own grip, but the connectors the save's check "
			% [part_id, " ".join(info.name.split(" ", false)) if info != null else "held"]
			+ "reads (BrickNet's) give it none a hand's clip takes, so the check calls it not "
			+ "held: stand it on a stud beside the figure instead, or give the hand another.")
	return {"ok": true, "ids": ids, "box": box, "text": said}


## The things [param parts]' hands hold that nothing the exact check knows
## joins to a hand, by part: a sack's grab handle (10169) and a mug's
## (33054) are no bar in BrickNet's connectors, so no turn or seat in the
## hand helps. Said when the figure is put down, not found at the save.
static func unheld_in_hand(library: PartLibrary, parts: Array[Dictionary]) -> PackedStringArray:
	var ids: Array = []
	for item: Dictionary in parts:
		ids.append(str(item["part"]))
	var shapes: Dictionary = Exact.shapes_for(library, ids)
	var items: Array = []
	var hands := PackedInt32Array()
	for n: int in parts.size():
		var shape: Exact.Shape = shapes.get(str(parts[n]["part"]))
		items.append(Exact.Item.new(shape, parts[n]["at"]) if shape != null else null)
		if str(parts[n]["slot"]) == "hands":
			hands.append(n)
	var out := PackedStringArray()
	for n: int in parts.size():
		if HELD_BY_BAR.has(str(parts[n]["slot"])) and items[n] != null \
				and (items[n] as Exact.Item).shape.has_pieces() and not Exact.connected(items, n, hands):
			out.append(str(parts[n]["part"]))
	return out


## What a refused figure runs into, by part, and what would stand: the same
## figure without its headwear, or the nearest spot a stud or two away. A
## session told only "something is in the way" looked a captain into a
## wheelhouse five times, with a probe figure and an undo, to find the roof
## plate over his hat (walk180, 2026-10-23).
static func _in_the_way(parts: Array[Dictionary], at: Transform3D, spot: Vector2,
		library: PartLibrary, world: BrickWorld, builder: Builder) -> String:
	var hit: Dictionary = {}
	var by_slot: Dictionary = {}
	for item: Dictionary in parts:
		var where: Transform3D = at * (item["at"] as Transform3D)
		var boxes: PackedInt32Array = builder.boxes_for(library.mesh_for(str(item["part"])), where)
		for other: int in builder.lattice.blockers_boxes(boxes):
			hit[other] = true
			var slots: Array = by_slot.get(other, [])
			if not slots.has(str(item["slot"])):
				slots.append(str(item["slot"]))
			by_slot[other] = slots
	if hit.is_empty():
		return ""
	var named := PackedStringArray()
	for other: int in hit.keys().slice(0, 4):
		var brick: BrickWorld.Brick = world.get_brick(other)
		if brick == null:
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		var low: float = (brick.transform * mesh.bounds).abs().position.y if mesh != null \
			else brick.transform.origin.y
		named.append("#%d %s%s from y %s (its %s)" % [other, brick.part_id,
			" " + " ".join(info.name.split(" ", false)) if info != null else "",
			_n(snappedf(low / PLATE, 0.25)),
			" and ".join(PackedStringArray(by_slot[other]))])
	var said: String = " In the way: %s%s." % ["; ".join(named),
		" and %d more" % (hit.size() - named.size()) if hit.size() > named.size() else ""]
	var bare: Array[Dictionary] = []
	for item: Dictionary in parts:
		if not str(item["slot"]) in ["headwear", "hat_extra"]:
			bare.append(item)
	if bare.size() < parts.size() and builder.figure_fits(bare, at):
		return said + " Without headwear it stands there (headwear \"none\")."
	var nearest: Vector3 = Vector3.INF
	for dx: int in range(-2, 3):
		for dz: int in range(-2, 3):
			var by := Vector3(dx * STUD, 0.0, dz * STUD)
			if by == Vector3.ZERO or by.length() >= nearest.length():
				continue
			if builder.figure_fits(parts, at.translated(by)):
				nearest = by
	if nearest != Vector3.INF:
		return said + " The nearest spot it stands is x %s, z %s." % [
			_n(spot.x + nearest.x / STUD), _n(spot.y + nearest.z / STUD)]
	return said


## The headgear lower than the figure's that stands at [param at], or "":
## of those anybody's figure wears, the ones that say most of what was asked
## ("captain hat": a hat), then of its kind (LDraw's first word: Hat, Cap,
## Helmet, Hair), then the most worn. A coroutine: the few tried are fetched.
static func _lower_headwear(figure: Minifig, asked: String, at: Transform3D,
		library: PartLibrary, builder: Builder) -> String:
	var worn: PartLibrary.PartInfo = library.parts.get(figure.part("headwear"))
	if worn == null:
		return ""
	var kind: String = Minifig.group_of(worn, "headwear")
	var words: PackedStringArray = _words_of(asked)
	var ranked: Array = []
	for info: PartLibrary.PartInfo in Minifig.choices(library, "headwear"):
		if info.id == worn.id or info.bounds.end.y >= worn.bounds.end.y - 2.0 \
				or not PartsOnly.allows(info.id, library) or SetKnowledge.generic(info.id) == 0:
			continue
		var own: PackedStringArray = _words_of(info.name)
		var said: int = 0
		for word: String in words:
			if not FILLER.has(word) and own.has(word):
				said += 1
		ranked.append([said, 1 if Minifig.group_of(info, "headwear") == kind else 0,
			maxi(SetKnowledge.carried(info.id), info.in_sets), info.id])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return _before(a, b))
	var tried := PackedStringArray()
	for row: Array in ranked.slice(0, LOWER_TRIED):
		tried.append(str(row[3]))
	await _fetch(library, tried)
	for id: String in tried:
		if library.mesh_for(id) == null:
			continue
		var trial: Minifig = figure.copy()
		trial.choose(library, "headwear", id)
		if builder.figure_fits(parts_of(trial, library), at):
			return id
	return ""


## How many lower headgear a refused figure tries on.
const LOWER_TRIED := 24


## What each slot's part sits on, by its connectors: a hat on the head's stud,
## a visor on the hat, a sword's bar in a hand's clip, a head on the neck.
const SITS_ON: Dictionary = {"headwear": ["head"], "hat_extra": ["headwear"],
	"accessory": ["hands"], "accessory_left": ["hands"], "head": ["torso", "neck"]}
## How far a part may be moved onto its seat, in LDU: a fez is drawn 16 above
## where the classic head's headgear goes.
const SEAT_REACH := 24.0


## A figure's parts as they go into a model, each seated on what holds it
## (seated_exactly): what a session's figure, the Minifigure builder's
## preview and the figure it puts down are all made of, so the three agree.
static func parts_of(figure: Minifig, library: PartLibrary) -> Array[Dictionary]:
	return seated_exactly(library, figure.assemble(library))


## The figure's parts with each one that runs into another moved onto the
## connector of the part it sits on, where one of those is near: BrickNet's
## colliders and connectors (Exact), which BrickBench's check judges a figure
## by. The standard joints are clean by them; a fez (drawn 16 LDU above where
## other headgear goes) and a sword held off its bar were not, and the check
## refused the figures this made (docs/BRICKBENCH.md). Only moved, never
## turned; one that cannot be seated stays where it was and the check says so.
static func seated_exactly(library: PartLibrary, parts: Array[Dictionary]) -> Array[Dictionary]:
	var ids: Array = []
	for item: Dictionary in parts:
		ids.append(str(item["part"]))
	var shapes: Dictionary = Exact.shapes_for(library, ids)
	if shapes.is_empty():
		return parts
	var items: Array = []
	for item: Dictionary in parts:
		var shape: Exact.Shape = shapes.get(str(item["part"]))
		items.append(Exact.Item.new(shape, item["at"]) if shape != null else null)
	for i: int in parts.size():
		var slot: String = str(parts[i]["slot"])
		if not SITS_ON.has(slot) or items[i] == null:
			continue
		var on := PackedInt32Array()
		for j: int in parts.size():
			if j != i and (SITS_ON[slot] as Array).has(str(parts[j]["slot"])) and items[j] != null:
				on.append(j)
		if on.is_empty():
			continue
		var clashing: bool = false
		for j: int in items.size():
			if j != i and items[j] != null and not Exact.clash(items[i], items[j], true).is_empty():
				clashing = true
				break
		if not clashing and Exact.connected(items, i, on):
			continue
		var found: Dictionary = Exact.seat_move(items, i, SEAT_REACH, 0.05, on)
		if not found.is_empty():
			var was: Exact.Item = items[i]
			var there := Exact.Item.new(was.shape, was.at.translated(found["move"]))
			var clear: bool = true
			for j: int in items.size():
				if j != i and items[j] != null and not Exact.clash(there, items[j], true).is_empty():
					clear = false
					break
			items[i] = there
			if clear and Exact.connected(items, i, on):
				parts[i]["at"] = there.at
				continue
			items[i] = was
		# Held by its bar or its axle and still through what holds it: slid
		# along that line until it is clear, as a sword slides in a hand.
		if Exact.connected(items, i, on):
			var slide: Variant = Exact.slide_clear(items, i, on)
			if slide is Vector3:
				items[i] = Exact.Item.new((items[i] as Exact.Item).shape,
					(items[i] as Exact.Item).at.translated(slide))
				parts[i]["at"] = (items[i] as Exact.Item).at
		if HELD_BY_BAR.has(slot) and not _held_clear(items, i, on):
			var turned: Variant = turned_in_hand(items, i, on)
			if turned is Transform3D:
				items[i] = Exact.Item.new((items[i] as Exact.Item).shape, turned)
				parts[i]["at"] = turned
	return parts


## [param parts] with what a hand holds turned about its bar in the hand,
## the least turn first, until [param fits] says yes of the whole figure, or
## as they were. A figure stood beside a bollard on a jetty was refused for
## its fishing rod, which could have pointed the other way, and the session
## stood it a stud along instead (hand264).
static func turned_to_fit(library: PartLibrary, parts: Array[Dictionary],
		fits: Callable) -> Array[Dictionary]:
	var ids: Array = []
	for item: Dictionary in parts:
		ids.append(str(item["part"]))
	var shapes: Dictionary = Exact.shapes_for(library, ids)
	var items: Array = []
	var hands := PackedInt32Array()
	for n: int in parts.size():
		var shape: Exact.Shape = shapes.get(str(parts[n]["part"]))
		items.append(Exact.Item.new(shape, parts[n]["at"]) if shape != null else null)
		if str(parts[n]["slot"]) == "hands":
			hands.append(n)
	for n: int in parts.size():
		if not HELD_BY_BAR.has(str(parts[n]["slot"])) or items[n] == null:
			continue
		var trial: Array[Dictionary] = []
		for item: Dictionary in parts:
			trial.append(item.duplicate())
		var turned: Variant = turned_in_hand(items, n, hands, func(there: Transform3D) -> bool:
			trial[n]["at"] = there
			return bool(fits.call(trial)))
		if turned is Transform3D:
			trial[n]["at"] = turned
			return trial
	return parts


## The model's parts standing within a few studs of a figure at [param at],
## by their exact shapes.
static func _model_near(library: PartLibrary, world: BrickWorld, at: Transform3D) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if brick.transform.origin.distance_to(at.origin) > NEAR:
			continue
		var shape: Exact.Shape = Exact.shape_for(library, brick.part_id)
		if shape != null and shape.has_pieces():
			out.append(Exact.Item.new(shape, brick.transform))
	return out


## How near a figure the model's parts are asked about, in LDU: past the
## reach of a figure's longest held thing, a lance.
const NEAR := 12.0 * STUD


## Whether what [param parts]' hands hold, stood at [param at], is clear of
## [param around] by the parts' exact shapes.
static func _held_clear_of(library: PartLibrary, parts: Array[Dictionary], at: Transform3D,
		around: Array) -> bool:
	for item: Dictionary in parts:
		if not HELD_BY_BAR.has(str(item["slot"])):
			continue
		var shape: Exact.Shape = Exact.shape_for(library, str(item["part"]))
		if shape == null or not shape.has_pieces():
			continue
		var held := Exact.Item.new(shape, at * (item["at"] as Transform3D))
		for other: Exact.Item in around:
			if not Exact.clash(held, other, true).is_empty():
				return false
	return true


## What a hand holds by a bar: it may turn about the bar in the hand, as a
## real one does, and is seated by the bar BrickNet's connectors know.
const HELD_BY_BAR: Array[String] = ["accessory", "accessory_left"]
## The turns about the bar tried, in degrees each way, smallest first.
const TURN_STEP := 15.0
## How far along the bar it may slide besides, in LDU, a step at a time.
const SLIDE_STEPS: Array[float] = [0.0, 2.0, -2.0, 4.0, -4.0, 6.0, -6.0, 8.0, -8.0]


## Whether item [param i] is joined to one of [param on] and clear of every
## other item, as the check (ExactCheck) reads a figure.
static func _held_clear(items: Array, i: int, on: PackedInt32Array) -> bool:
	return Exact.connected(items, i, on) and _clear_at(items, i, (items[i] as Exact.Item).at)


## And no lower than the figure's feet, the lowest of the rest: a figure's
## parts are in the app's axes, y up (Minifig.assemble). Asked the other way
## round, the jetty session's fishing rod was turned to hang straight down
## through the water (hand264).
static func _clear_at(items: Array, i: int, at: Transform3D) -> bool:
	var there := Exact.Item.new((items[i] as Exact.Item).shape, at)
	var ground: float = INF
	for j: int in items.size():
		if j != i and items[j] != null:
			ground = minf(ground, (items[j] as Exact.Item).lo.y)
	if there.lo.y < ground - 0.5:
		return false
	for j: int in items.size():
		if j != i and items[j] != null and not Exact.clash(there, items[j], true).is_empty():
			return false
	return true


## Where item [param i], a thing in a hand of [param on], is held by its
## bar in the hand's clip and clear of the figure, or null. Laid by the
## grips table (Minifig.in_hand), the turn about the bar is only the least
## that lines the two up: a cup's body went 2.6 LDU into the torso, a
## hammer's head through the legs, and 47 of the 456 things the table names
## were held through the figure. And its grip is the table's, read off the
## part's own lines, which for 44 more is not the bar BrickNet's connectors
## put a hand on (a camera held by its sight), so the check saw nothing hold
## them: the miller's sack in walk256's windmill session cost five turns.
## So each of its bars that a clip takes is laid in the hand's clip, nearest
## the grip first, and turned about the clip's line, the least turn first,
## and slid a little along it, until it is clear and joined, and [param
## also] (given the place) says yes when there is more to ask.
static func turned_in_hand(items: Array, i: int, on: PackedInt32Array,
		also: Callable = Callable()) -> Variant:
	var item: Exact.Item = items[i]
	var clips: Array = []
	for j: int in on:
		var hand: Exact.Item = items[j]
		if hand == null:
			continue
		for one: Array in hand.world():
			var k: int = one[0]
			if hand.shape.kind[k] == Exact.AXLE and hand.shape.sub[k] == Exact.S_CLIP:
				clips.append(one)
	var bars: Array = []
	for k: int in item.shape.kind.size():
		if item.shape.kind[k] == Exact.AXLE and item.shape.sub[k] == Exact.S_BAR:
			bars.append(k)
	var seats: Array = []
	for clip: Array in clips:
		for k: int in bars:
			var bar: Transform3D = item.at * item.shape.frames[k]
			seats.append([bar.origin.distance_to(clip[1] as Vector3), clip, k])
	seats.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for seat: Array in seats:
		var clip: Array = seat[1]
		var k: int = seat[2]
		var centre: Vector3 = clip[1]
		var line: Vector3 = clip[2]
		var laid: Transform3D = _bar_in_clip(item.at, item.shape.frames[k], centre, line)
		for n: int in int(180.0 / TURN_STEP) + 1:
			for sign: float in ([1.0] if n == 0 or n * TURN_STEP >= 180.0 else [1.0, -1.0]):
				var turn := Basis(line, deg_to_rad(sign * n * TURN_STEP))
				var turned := Transform3D(turn, centre - turn * centre) * laid
				for slide: float in SLIDE_STEPS:
					var there: Transform3D = turned.translated(line * slide)
					if not _clear_at(items, i, there):
						continue
					items[i] = Exact.Item.new(item.shape, there)
					var joined: bool = Exact.connected(items, i, on)
					items[i] = item
					if joined and (not also.is_valid() or bool(also.call(there))):
						return there
	return null


## [param at], turned the least way that lays the bar of frame [param bar]
## (in the part's own frame; it points along minus its y) along [param line]
## either way, and moved so the bar's middle is at [param centre].
static func _bar_in_clip(at: Transform3D, bar: Transform3D, centre: Vector3,
		line: Vector3) -> Transform3D:
	var along: Vector3 = (at.basis * -bar.basis.y).normalized()
	var target: Vector3 = line if along.dot(line) >= 0.0 else -line
	var basis: Basis = at.basis
	var axis: Vector3 = along.cross(target)
	if axis.length() > 1e-6:
		basis = Basis(axis.normalized(), atan2(axis.length(), along.dot(target))) * basis
	return Transform3D(basis, centre - basis * bar.origin)


## Quarter turns that face a figure one of the four ways. A figure is
## built facing +z; a turn of R carries that round as any part's would.
static func _turns_for(facing: String) -> int:
	var want: Vector3 = BrickLattice.FACE_AXIS.get(facing, Vector3.BACK)
	for turns: int in 4:
		var looks: Vector3 = BrickLattice.basis_for("up", turns) * Vector3.BACK
		if looks.distance_to(want) < 0.01:
			return turns
	return 0


static func _describe(figure: Minifig, library: PartLibrary) -> String:
	var said := PackedStringArray()
	for slot: String in Minifig.SLOTS:
		var part: String = figure.part_for_colour(slot)
		if part.is_empty():
			continue
		var info: PartLibrary.PartInfo = library.parts.get(part)
		var name: String = info.name.strip_edges().replace("  ", " ") if info != null else part
		said.append("%s %s %s (%s)" % [slot, part, name,
			library.color(int(figure.colours[slot])).name])
	return "; ".join(said)


static func _fetch(library: PartLibrary, ids: PackedStringArray) -> void:
	var wanted: Dictionary = {}
	for part_id: String in ids:
		if not library.is_resident(part_id) and library.request_mesh(part_id, true):
			wanted[part_id] = true
	var deadline: int = Time.get_ticks_msec() + 20000
	while not wanted.is_empty() and Time.get_ticks_msec() < deadline:
		await Engine.get_main_loop().process_frame
		for part_id: String in wanted.keys():
			if library.is_resident(part_id):
				wanted.erase(part_id)


static func _n(value: float) -> String:
	return str(snappedf(value, 0.01)).trim_suffix(".0")
