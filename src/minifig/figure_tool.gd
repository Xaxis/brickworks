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
			+ "works in it. Add them once the model is built — submitting a "
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
				"head": slot.call("a face: \"beard\", \"smile\", \"angry\""),
				"neck": slot.call("cape, armour, backpack, or left out"),
				"torso": slot.call("what is printed on the chest"),
				"hips": slot.call("a printed belt or sash, or left out"),
				"legs": slot.call("plain, printed, or \"short\" for a child"),
				"accessory": slot.call("what it holds in its right hand"),
				"colors": {"type": "object", "description": (
					"LDraw colour codes by slot: headwear, head, neck, "
					+ "torso, arms, hands, hips, legs, accessory. A printed "
					+ "torso brings arm and hand colours of its own."),
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
	for slot: String in Minifig.SLOTS:
		if Minifig.COLOUR_ONLY.has(slot) or not args.has(slot):
			continue
		var wanted: String = str(args[slot]).strip_edges()
		var found: String = choose(library, slot, wanted)
		if found == "?":
			unmatched.append("%s \"%s\"" % [slot, wanted])
			continue
		if slot == "torso":
			figure.dress_torso(found)
		else:
			figure.parts[slot] = found
	for slot: Variant in colours:
		if Minifig.SLOTS.has(str(slot)):
			figure.colours[str(slot)] = int(colours[slot])
	return [figure, unmatched]


## The part that best answers some words for a slot: "" for none, "?"
## for nothing that matched.
static func choose(library: PartLibrary, slot: String, wanted: String) -> String:
	var asked: String = wanted.to_lower().strip_edges()
	if asked.is_empty() or asked == "none" or asked == "nothing":
		return "" if Minifig.OPTIONAL.has(slot) else "?"
	var all: Array[PartLibrary.PartInfo] = Minifig.choices(library, slot)
	for info: PartLibrary.PartInfo in all:
		if info.id == asked:
			return info.id
	if slot == "legs" and (asked.contains("short") or asked.contains("child")):
		return "41879a"
	if asked == "plain":
		var plain: Dictionary = {"head": "3626cp01", "torso": "973",
			"hips": Minifig.PLAIN_HIPS, "legs": Minifig.PLAIN_LEGS}
		if plain.has(slot):
			return plain[slot]
	var words: PackedStringArray = PackedStringArray()
	for word: String in asked.replace(",", " ").split(" ", false):
		if not FILLER.has(word) and word.length() >= 3:
			words.append(word.trim_suffix("s") if word.length() > 4 else word)
	if words.is_empty():
		return "?"
	var best: String = "?"
	var best_score: float = 0.0
	for info: PartLibrary.PartInfo in all:
		var name: String = info.name.to_lower()
		var score: float = 0.0
		for word: String in words:
			if name.contains(word):
				score += 1.0
		if score <= 0.0:
			continue
		# Of two that say as much, the one that says less besides: "Hat
		# Wizard" before "Hat Wizard with Stars and Moon Pattern".
		score -= name.length() * 0.001
		if score > best_score:
			best_score = score
			best = info.id
	return best


## Stand the figure the arguments describe in the world. A coroutine: a
## part not yet to hand is fetched first. Returns {ok, text, ids, box}.
static func add(args: Dictionary, library: PartLibrary, world: BrickWorld,
		builder: Builder) -> Dictionary:
	var made: Array = figure_for(args, library)
	var figure: Minifig = made[0]
	var unmatched: PackedStringArray = made[1]
	if figure.name.is_empty():
		figure.name = "Minifig"
	await _fetch(library, figure.part_ids())
	for part_id: String in figure.part_ids():
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
	var parts: Array[Dictionary] = figure.assemble(library)
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
	if not builder.figure_fits(parts, at):
		return {"ok": false, "ids": PackedInt64Array(), "box": AABB(),
			"text": ("Not placed: something is in the way of a figure standing "
				+ "at x %s, z %s, y %s. A figure is two studs wide, one deep "
				% [_n(x), _n(z), _n(resting_plates)]
				+ "and five plates and a head tall; it needs that clear "
				+ "above its feet, and its arms and what it holds a stud "
				+ "either side.")}
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
	return {"ok": true, "ids": ids, "box": box, "text": said}


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
