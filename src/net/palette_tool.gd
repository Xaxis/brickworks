## The person's palettes, for a session (APP_UX7 #8, mcppalettes).
##
## Palettes are the bin's (APP_UX6 palettes): each named, of parts in their
## colours and of sub-assemblies, kept apart from any model so what was
## gathered in one is there in the next. Asked to keep the pods' parts as a
## palette, the MCP walk's session said "none of my tools can create or save
## one" (w7). So a session reads and changes the same palettes, through the
## same file and the same code the bin's own rows run (PartShelf): a palette
## a session makes is the one the bin shows, and one the person made in the
## bin is the one a session reads.
##
## Two tools, because MCP says per tool whether it only looks: palettes reads
## (readOnlyHint), and Claude need not ask the person before it; edit_palette
## makes, keeps, takes out, renames, deletes, and puts a kept sub-assembly
## down in the model as the bin's tile does: whole, where a session says,
## each part where it stood beside the others, as one assembly of its own and
## one undo step. What the window asks the person before (taking a
## sub-assembly out, deleting a palette) a session does only with
## agreed=true, once the person has said yes.
##
## Tools of AppTools, served wherever the app's tools are: the desktop's MCP
## port, My Claude and the connector.
class_name PaletteTool
extends RefCounted

const NAMES: Array[String] = ["palettes", "edit_palette"]
const STUD := 20.0
const PLATE := 8.0
## Of a palette's entries, how many each is listed with when every palette is.
const LISTED_MOST := 40
## The longest a part's geometry is waited for before placing, ms.
const FETCH_WAIT_MS := 20000

var app: Node
## The parts the last place put down, for its answer's picture
## (SeeTools.pictured); empty when it put nothing down.
var changed: PackedInt64Array = PackedInt64Array()


static func definitions() -> Array:
	var bricks: Dictionary = {"type": "array", "items": {"type": "integer"},
		"description": "parts of the open model, by their numbers in look_at_model"}
	return [
		{
			"name": "palettes",
			"description": ("The person's own palettes, as the parts bin's Palettes keeps "
				+ "them: each named, of parts in their colours and of sub-assemblies, kept "
				+ "apart from any model so they are there in every model the person opens, "
				+ "on this computer (in this browser on the web). With no palette=, every "
				+ "palette with what it holds; palette= one by its name, in full: each part's "
				+ "number, name and colour, and each sub-assembly's name and parts. Changes "
				+ "nothing. edit_palette makes and changes them, and puts a sub-assembly down."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"palette": {"type": "string", "description": "a palette's name"},
			}},
		},
		{
			"name": "edit_palette",
			"description": ("Make or change one of the person's palettes (the parts bin's "
				+ "Palettes), as its New palette, Add and More rows do, or put one of its "
				+ "sub-assemblies down in the model. palette= its name. action make (a new "
				+ "palette called palette=; a name taken is refused) or add keeps parts in it, "
				+ "each part and colour once: bricks= parts of the open model by number, each "
				+ "in its colour; parts= any part by number and LDraw colour; from= \"model\" "
				+ "or \"selection\" every part of the open model or of the person's selection. "
				+ "assembly= keeps a sub-assembly whole by that name, as Add, The selection, "
				+ "as one sub-assembly does: its parts assembly_bricks=, or with none given "
				+ "from= (the selection or the whole model). Parts and a sub-assembly go in "
				+ "one call. take_out takes parts= or the sub-assembly assembly= out; rename "
				+ "renames the palette, or the sub-assembly assembly=, to to=; delete deletes "
				+ "the palette. Taking out a sub-assembly and deleting a palette need "
				+ "agreed=true: ask the person first, as the window asks them. action place "
				+ "puts the sub-assembly assembly= down in the model whole, as a click on its "
				+ "tile does: each part where it stood beside the others, as a sub-assembly "
				+ "of its own name, one undo step; at= {x, y, z} is where its low corner goes "
				+ "(studs, plates, studs, as look_at_model gives them; beside the model when "
				+ "not given), rot= quarter turns about the upright first, every part checked "
				+ "for room, all or nothing. A part alone from a palette goes in with "
				+ "edit_model's add, in its colour. Answered with what the palette holds, or "
				+ "with what was put down pictured (picture=false: words alone)."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["action", "palette"], "properties": {
				"action": {"type": "string", "enum": ["make", "add", "take_out", "rename",
					"delete", "place"]},
				"palette": {"type": "string", "description": "the palette's name (make: the new one's)"},
				"bricks": bricks,
				"parts": {"type": "array", "description": "parts by number, each in a colour",
					"items": {"type": "object", "additionalProperties": false,
						"required": ["part", "color"], "properties": {
						"part": {"type": "string", "description": "part number, e.g. 3001"},
						"color": {"type": "integer", "description": "LDraw colour code"},
					}}},
				"from": {"type": "string", "enum": ["model", "selection"]},
				"assembly": {"type": "string", "description": "a sub-assembly's name in the palette"},
				"assembly_bricks": bricks,
				"to": {"type": "string", "description": "rename: the new name"},
				"agreed": {"type": "boolean", "description": "the person said yes (take_out of a sub-assembly, delete)"},
				"at": {"type": "object", "additionalProperties": false, "properties": {
					"x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}},
					"description": "place: where the sub-assembly's low corner goes, in studs, plates and studs"},
				"rot": {"type": "integer", "description": "place: quarter turns about the upright, 0 to 3"},
				"picture": {"type": "boolean", "description": "place: false, words alone"},
			}},
		},
	]


## A coroutine: placing waits for its parts' shapes on the web.
func run(tool: String, input: Dictionary) -> String:
	changed = PackedInt64Array()
	if tool == "palettes":
		return _listed(input)
	var name: String = Quotes.off(str(input.get("palette", "")))
	if name.is_empty():
		return "palette= is the palette's name (palettes lists them). Nothing changed."
	match str(input.get("action", "")):
		"make", "add":
			return _kept(input, name)
		"take_out":
			return _taken_out(input, name)
		"rename":
			return _renamed(input, name)
		"delete":
			return _deleted(input, name)
		"place":
			return await _placed(input, name)
	return "action= is make, add, take_out, rename, delete or place. Nothing changed."


# -- reading --------------------------------------------------------------------


func _listed(input: Dictionary) -> String:
	var asked: String = Quotes.off(str(input.get("palette", "")))
	var all: Array = PartShelf.palettes()
	if not asked.is_empty():
		var one: Dictionary = _palette_named(asked)
		if one.is_empty():
			return _none_called(asked)
		return _held(one, 100000)
	if all.is_empty():
		return ("The person has no palettes yet. edit_palette action=make makes one, of parts "
			+ "in their colours and sub-assemblies, kept for every model they open.")
	var lines := PackedStringArray()
	lines.append("%s, kept for every model on this computer (in this browser on the web), "
		% Counted.of(all.size(), "palette") + "as the bin's Palettes shows them:")
	for one: Dictionary in all:
		lines.append("")
		lines.append(_held(one, LISTED_MOST))
	return "\n".join(lines)


## A palette in words: its name and counts, each part and colour, and each
## sub-assembly with its parts; at most [param most] entries.
func _held(one: Dictionary, most: int) -> String:
	var library: PartLibrary = app.get("_library")
	var lines := PackedStringArray()
	lines.append("“%s”: %s." % [str(one["name"]), PartsBin.palette_counts(one)
		if not (one["entries"] as Array).is_empty() else "empty"])
	var shown: int = 0
	for entry: Dictionary in one["entries"]:
		if shown >= most:
			lines.append("  … and %d more (palettes palette=“%s” lists them all)." % [
				(one["entries"] as Array).size() - shown, str(one["name"])])
			break
		shown += 1
		if entry.has("part"):
			lines.append("  part %s, %s, colour %d %s" % [str(entry["part"]),
				_part_name(library, str(entry["part"])), int(entry["colour"]),
				_colour_name(library, int(entry["colour"]))])
		else:
			lines.append("  sub-assembly “%s”, %s: %s" % [str(entry["name"]),
				Counted.of(int(entry["count"]), "part"), _tally(str(entry["ldraw"]))])
	return "\n".join(lines)


## A sub-assembly's parts, counted by part and colour: "2 x 3003 in 71, 1 x 3022 in 72".
static func _tally(ldraw: String) -> String:
	var counts: Dictionary = {}
	for line: String in ldraw.split("\n", false):
		var bits: PackedStringArray = line.strip_edges().split(" ", false)
		if bits.size() < 15 or bits[0] != "1":
			continue
		var key: String = "%s in %s" % [bits[14].trim_suffix(".dat"), bits[1]]
		counts[key] = int(counts.get(key, 0)) + 1
	var said := PackedStringArray()
	for key: String in counts:
		said.append("%d x %s" % [int(counts[key]), key])
	return ", ".join(said)


# -- making and keeping -------------------------------------------------------------


func _kept(input: Dictionary, name: String) -> String:
	var making: bool = str(input["action"]) == "make"
	var one: Dictionary = _palette_named(name)
	if making and not one.is_empty():
		return ("The person has a palette called “%s” already: action=add keeps more in it. "
			% str(one["name"]) + "Nothing changed.")
	if not making and one.is_empty():
		return _none_called(name)
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var wanted_assembly: String = Quotes.off(str(input.get("assembly", "")))
	var assembly_given: bool = input.has("assembly") or input.has("assembly_bricks")
	var from: String = str(input.get("from", ""))
	if not from.is_empty() and from not in ["model", "selection"]:
		return "from= is \"model\" or \"selection\". Nothing changed."
	if not from.is_empty() and _ids_from(from).is_empty():
		return ("Nothing is selected in the person's window. Nothing changed." if from == "selection"
			else "Nothing is built in the open model. Nothing changed.")
	# The parts, each in its colour: of the model by number, by number and
	# colour, and the model's or the selection's when from= is not the
	# sub-assembly's.
	var pairs: Array = []
	var named: Variant = _bricks_named(input.get("bricks", []), "bricks")
	if named is String:
		return named
	var from_parts: bool = not from.is_empty() and not (assembly_given
		and not input.has("assembly_bricks"))
	var ids: Array = named
	if from_parts:
		ids += _ids_from(from)
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		pairs.append([brick.part_id, brick.color_code])
	var given: Variant = input.get("parts", [])
	if not given is Array:
		return "parts= is a list of {part, color}. Nothing changed."
	for raw: Variant in given:
		var pair: Variant = _part_given(raw, library)
		if pair is String:
			return pair + ". Nothing changed."
		pairs.append(pair)
	# The sub-assembly, whole, as the bin keeps one: its parts' LDraw lines
	# where they stand (Carry.as_ldraw of Carry.gather).
	var assembly_ids: Array = []
	if assembly_given:
		var listed: Variant = _bricks_named(input.get("assembly_bricks", []), "assembly_bricks")
		if listed is String:
			return listed
		assembly_ids = listed
		if assembly_ids.is_empty() and not from.is_empty():
			assembly_ids = _ids_from(from)
		if assembly_ids.is_empty():
			return ("assembly= keeps a sub-assembly of parts of the model: give "
				+ "assembly_bricks= their numbers (look_at_model), or from=\"selection\". "
				+ "Nothing changed.")
	var held: Array = Carry.gather(world, library, assembly_ids) if not assembly_ids.is_empty() else []
	if not assembly_ids.is_empty() and held.is_empty():
		return "The sub-assembly's parts have no shapes here yet. Nothing changed."
	var assembly_name: String = wanted_assembly if not wanted_assembly.is_empty() \
		else _assembly_named(assembly_ids)
	# Given nothing, make makes an empty palette, as New palette does.
	var given_nothing: bool = not input.has("bricks") and not input.has("parts") \
		and from.is_empty() and not assembly_given
	if pairs.is_empty() and held.is_empty() and not (making and given_nothing):
		return ("Nothing to keep: give bricks=, parts=, from= or assembly_bricks=. Nothing "
			+ "changed.")
	var id: String = PartShelf.make_palette(name) if making else str(one["id"])
	var added: int = PartShelf.keep_parts(id, pairs) if not pairs.is_empty() else 0
	var kept_assembly: String = ""
	if not held.is_empty():
		var entry_id: String = PartShelf.keep_assembly(id, assembly_name, Carry.as_ldraw(held),
			held.size())
		if not entry_id.is_empty():
			kept_assembly = str(_entry_of(PartShelf.palette(id), entry_id).get("name", ""))
	one = PartShelf.palette(id)
	var lines := PackedStringArray()
	var what := PackedStringArray()
	if added > 0:
		what.append("%s, each in its colour" % Counted.of(added, "part"))
	if pairs.size() > added:
		what.append("%s there already or given twice" % Counted.of(pairs.size() - added, "part"))
	if not kept_assembly.is_empty():
		what.append("the sub-assembly “%s”, %s, whole" % [kept_assembly,
			Counted.of(held.size(), "part")])
	lines.append("%s the palette “%s”%s." % ["Made" if making else "Kept in",
		str(one["name"]), (": " + "; ".join(what)) if not what.is_empty() else ", empty"])
	lines.append(_held(one, LISTED_MOST))
	lines.append(("It is in the parts bin's Palettes for every model the person opens on "
		+ "this computer (in this browser on the web): a part from it is taken in hand in its "
		+ "colour, a sub-assembly whole. edit_palette action=place puts a sub-assembly down "
		+ "here; a part goes in with edit_model's add."))
	return "\n".join(lines)


## The parts of the model a list of numbers names, or why not.
func _bricks_named(given: Variant, field: String) -> Variant:
	if not given is Array:
		return "%s= is a list of part numbers from look_at_model. Nothing changed." % field
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var ids: Array = []
	var unknown := PackedStringArray()
	for raw: Variant in given:
		var number: int = int(raw) if (raw is int or raw is float) else 0
		if number <= 0 or store.scenery.has(number) or world.get_brick(number) == null:
			unknown.append(str(raw))
		elif not ids.has(number):
			ids.append(number)
	if not unknown.is_empty():
		return ("No part of the model numbered %s (look_at_model numbers them). Nothing changed."
			% ", ".join(unknown))
	return ids


## Every part of the open model, or of the person's selection, by number.
func _ids_from(from: String) -> Array:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var builder: Builder = app.get("_builder")
	var out: Array = []
	if from == "selection":
		for brick_id: Variant in builder.selection.keys():
			if world.get_brick(int(brick_id)) != null and not store.scenery.has(int(brick_id)):
				out.append(int(brick_id))
		return out
	for brick: BrickWorld.Brick in world.bricks():
		if not store.scenery.has(brick.id):
			out.append(brick.id)
	return out


## One of parts= checked: [part, colour], or why not.
static func _part_given(raw: Variant, library: PartLibrary) -> Variant:
	if not raw is Dictionary:
		return "each of parts= is {part, color}"
	var asked: String = str((raw as Dictionary).get("part", "")).strip_edges().to_lower() \
		.trim_suffix(".dat")
	var id: String = library.resolve(asked)
	if asked.is_empty() or not library.parts.has(id):
		return "no part numbered %s (search_parts finds it by its words)" % asked
	var colour: Variant = (raw as Dictionary).get("color", (raw as Dictionary).get("colour"))
	var code: int = int(colour) if (colour is int or colour is float) else -1
	if code in PartsBin.NOT_A_COLOUR or not library.colors.has(code):
		return "colour %s is not an LDraw colour code" % str(colour)
	return [id, code]


## What a sub-assembly kept without a name is called, as the bin calls it
## (PartsBin._assembly_named): the assembly its parts all are, else
## "Sub-assembly" in the person's language, as theirs once kept.
func _assembly_named(ids: Array) -> String:
	var world: BrickWorld = app.get("_world")
	var group: String = ""
	for n: int in ids.size():
		var brick: BrickWorld.Brick = world.get_brick(int(ids[n]))
		if n == 0:
			group = brick.group
		elif brick.group != group:
			group = ""
			break
	return group if not group.is_empty() else TranslationServer.translate("Sub-assembly")


# -- taking out, renaming, deleting -------------------------------------------------


func _taken_out(input: Dictionary, name: String) -> String:
	var one: Dictionary = _palette_named(name)
	if one.is_empty():
		return _none_called(name)
	var library: PartLibrary = app.get("_library")
	var gone: Array = []
	var given: Variant = input.get("parts", [])
	if not given is Array:
		return "parts= is a list of {part, color}. Nothing changed."
	for raw: Variant in given:
		var pair: Variant = _part_given(raw, library)
		if pair is String:
			return pair + ". Nothing changed."
		var entry: Dictionary = _part_entry(one, str(pair[0]), int(pair[1]))
		if entry.is_empty():
			return "“%s” holds no %s in colour %d. Nothing changed." % [str(one["name"]),
				str(pair[0]), int(pair[1])]
		gone.append(entry)
	var asked: String = Quotes.off(str(input.get("assembly", "")))
	if not asked.is_empty():
		var entry: Dictionary = _assembly_entry(one, asked)
		if entry.is_empty():
			return _no_assembly(one, asked)
		# Kept nowhere else: the window asks the person first.
		if not bool(input.get("agreed", false)):
			return ("Taking the sub-assembly “%s” out of “%s” loses it: it is kept nowhere else. "
				% [str(entry["name"]), str(one["name"])] + "The window asks the person first; "
				+ "ask them, and once they say yes call again with agreed=true. Nothing changed.")
		gone.append(entry)
	if gone.is_empty():
		return "Give parts= or assembly= to take out. Nothing changed."
	for entry: Dictionary in gone:
		PartShelf.take_out(str(one["id"]), str(entry["id"]))
	one = PartShelf.palette(str(one["id"]))
	return "Took %s out of “%s”. Models built with them keep their parts.\n%s" % [
		Counted.of(gone.size(), "entry", "entries"), str(one["name"]), _held(one, LISTED_MOST)]


func _renamed(input: Dictionary, name: String) -> String:
	var one: Dictionary = _palette_named(name)
	if one.is_empty():
		return _none_called(name)
	var to: String = PartShelf.clean_name(Quotes.off(str(input.get("to", ""))))
	if to.is_empty():
		return "to= is the new name. Nothing changed."
	var asked: String = Quotes.off(str(input.get("assembly", "")))
	if not asked.is_empty():
		var entry: Dictionary = _assembly_entry(one, asked)
		if entry.is_empty():
			return _no_assembly(one, asked)
		var was: String = str(entry["name"])
		if not PartShelf.rename_entry(str(one["id"]), str(entry["id"]), to):
			return "The sub-assembly is called “%s” already. Nothing changed." % was
		return "Renamed the sub-assembly “%s” in “%s” to “%s”." % [was, str(one["name"]), to]
	var taken: Dictionary = _palette_named(to)
	if not taken.is_empty() and str(taken["id"]) != str(one["id"]):
		return "The person has a palette called “%s” already. Nothing changed." % str(taken["name"])
	var before: String = str(one["name"])
	if not PartShelf.rename_palette(str(one["id"]), to):
		return "The palette is called “%s” already. Nothing changed." % before
	return "Renamed the palette “%s” to “%s”." % [before, str(PartShelf.palette(str(one["id"]))["name"])]


func _deleted(input: Dictionary, name: String) -> String:
	var one: Dictionary = _palette_named(name)
	if one.is_empty():
		return _none_called(name)
	var counts: String = PartsBin.palette_counts(one)
	if not bool(input.get("agreed", false)):
		return ("Deleting “%s” loses the %s in it. The window asks the person first; ask them, "
			% [str(one["name"]), counts] + "and once they say yes call again with agreed=true. "
			+ "Nothing changed.")
	PartShelf.delete_palette(str(one["id"]))
	return "Deleted the palette “%s” and the %s in it. Models built with them keep their parts." \
		% [str(one["name"]), counts]


# -- putting a sub-assembly down ------------------------------------------------------


func _placed(input: Dictionary, name: String) -> String:
	var one: Dictionary = _palette_named(name)
	if one.is_empty():
		return _none_called(name)
	var assistant: Assistant = app.get("_assistant")
	if assistant != null and assistant.is_busy():
		return "The app's own designer is building right now; wait for it to finish."
	var asked: String = Quotes.off(str(input.get("assembly", "")))
	var entry: Dictionary = _assembly_entry(one, asked) if not asked.is_empty() \
		else _only_assembly(one)
	if entry.is_empty():
		return _no_assembly(one, asked)
	var rot: Variant = input.get("rot", 0)
	if not (rot is int or rot is float) or float(rot) != floorf(float(rot)):
		return "rot= is a whole number of quarter turns, 0 to 3. Nothing changed."
	var library: PartLibrary = app.get("_library")
	var builder: Builder = app.get("_builder")
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var ids := PackedStringArray()
	for line: String in str(entry["ldraw"]).split("\n", false):
		var bits: PackedStringArray = line.strip_edges().split(" ", false)
		if bits.size() >= 15 and bits[0] == "1":
			var part: String = library.resolve(bits[14].trim_suffix(".dat"))
			if not ids.has(part):
				ids.append(part)
	if not await _shapes_here(ids):
		return "The sub-assembly's parts did not load, so it was not put down. Nothing changed."
	# Read as the bin reads it once its shapes are here: framed about the
	# point it turns round (Carry.from_ldraw).
	var parts: Array = Carry.from_ldraw(str(entry["ldraw"]), library)
	if parts.is_empty():
		return "The sub-assembly's parts did not load, so it was not put down. Nothing changed."
	var pivot: Vector3 = parts[0].get("pivot", Vector3.ZERO)
	var turn := Basis(Vector3.UP, posmod(int(rot), 4) * PI * 0.5)
	var where: Array = []
	var low := Vector3.INF
	for item: Dictionary in parts:
		var at: Transform3D = Transform3D(turn, Vector3.ZERO) * (item["at"] as Transform3D)
		at = Transform3D(at.basis.orthonormalized(), at.origin + pivot)
		where.append(at)
		var info: PartLibrary.PartInfo = library.parts.get(str(item["part"]))
		var box: AABB = (at * info.bounds).abs() if info != null else AABB(at.origin, Vector3.ZERO)
		low = low.min(box.position)
	# Where its low corner goes, moved by whole studs and plates so its parts
	# stay on the model's studs.
	var target: Vector3 = _asked_corner(input.get("at"), world, store, library)
	if target == Vector3.INF:
		return "at= is {x, y, z}: studs, plates and studs, as look_at_model gives them. Nothing changed."
	var move := Vector3(roundf((target.x - low.x) / STUD) * STUD,
		roundf((target.y - low.y) / PLATE) * PLATE, roundf((target.z - low.z) / STUD) * STUD)
	var group: String = _unused_assembly(str(entry["name"]), world)
	var path: String = Assemblies.path_from(group, "")
	if builder.copy_group.is_valid():
		path = builder.copy_group.call(path, {})
	var adds: Array = []
	for n: int in parts.size():
		var at: Transform3D = where[n]
		var placed := Transform3D(at.basis, at.origin + move)
		placed = Builder._tidy(placed, BrickLattice.is_square_to_grid(placed.basis))
		var part: String = str(parts[n]["part"])
		if not builder.room_for(part, placed, true):
			var blocker: BrickWorld.Brick = world.get_brick(builder.room_blocker) \
				if builder.room_blocker > 0 else null
			return ("Not put down: its %s would have no room there (%s). Nothing changed: give "
				% [_part_name(library, part), ("#%d, %s, is in the way" % [blocker.id,
					_part_name(library, blocker.part_id)]) if blocker != null
					else "below the ground or in another part"]
				+ "another at=, or rot=.")
		adds.append({"part": part, "color": int(parts[n]["color"]), "at": placed, "path": path,
			"step": int(builder.place_step.call(path)) if builder.place_step.is_valid() else -1})
	var steps: Array = builder.swap_bricks(PackedInt64Array(), adds)
	for step: Dictionary in steps:
		changed.append(int(step["brick"]))
	builder.record(steps, "pasted %s" % Counted.of(changed.size(), "part"))
	var verbs: EditVerbs = app.get("_verbs")
	if verbs != null and verbs.edited.is_valid():
		verbs.edited.call()
	var corner: Vector3 = low + move
	return ("Put down the sub-assembly “%s” from “%s” whole: %s, %s, each where it stood beside "
		% [str(entry["name"]), str(one["name"]), Counted.of(changed.size(), "part"),
			HandTools._numbers(changed)]
		+ "the others, as the sub-assembly “%s”, its low corner at x %s, y %s, z %s%s. One undo step."
		% [group, HandTools._n(corner.x / STUD), HandTools._n(corner.y / PLATE),
			HandTools._n(corner.z / STUD), (", turned %d quarter turn%s" % [posmod(int(rot), 4),
				"" if posmod(int(rot), 4) == 1 else "s"]) if posmod(int(rot), 4) != 0 else ""])


## Where at= asks for the low corner, in LDU; beside the model's parts
## (a stud past their +x side, level with their front, on the ground) when
## not given. Vector3.INF when at= is no place.
func _asked_corner(at: Variant, world: BrickWorld, store: ModelStore,
		library: PartLibrary) -> Vector3:
	if at is Dictionary:
		var out := Vector3.ZERO
		for axis: int in 3:
			var raw: Variant = (at as Dictionary).get(["x", "y", "z"][axis], 0)
			if not (raw is int or raw is float):
				return Vector3.INF
			out[axis] = float(raw) * (PLATE if axis == 1 else STUD)
		return out
	if at != null:
		return Vector3.INF
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in world.bricks():
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if store.scenery.has(brick.id) or info == null:
			continue
		var here: AABB = (brick.transform * info.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	if first:
		return Vector3.ZERO
	return Vector3(ceilf(box.end.x / STUD) * STUD + STUD, 0.0, floorf(box.position.z / STUD) * STUD)


## Every one of [param ids]'s shapes here, fetched first on the web, as the
## bin waits for a sub-assembly's (PartsBin._all_here).
func _shapes_here(ids: PackedStringArray) -> bool:
	var library: PartLibrary = app.get("_library")
	var waiting: Array[String] = []
	for id: String in ids:
		if not library.is_resident(id) and library.mesh_for(id) == null:
			library.request_mesh(id, true)
			waiting.append(id)
	var asked: int = Time.get_ticks_msec()
	while not waiting.is_empty() and Time.get_ticks_msec() - asked < FETCH_WAIT_MS:
		await Engine.get_main_loop().process_frame
		waiting = waiting.filter(func(id: String) -> bool: return not library.is_resident(id))
	for id: String in ids:
		if library.mesh_for(id) == null:
			return false
	return true


## [param wanted], or with a number after it where the model has an assembly
## of that name at any depth, as the bin names a sub-assembly put down from a
## palette (PartsBin._unused_assembly): one of its own, never another copy of
## one the model has.
static func _unused_assembly(wanted: String, world: BrickWorld) -> String:
	var taken: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		taken[brick.group] = true
		for segment: String in brick.unit.split("/", false):
			taken[segment.get_slice("#", 0)] = true
	for path: Variant in world.unit_steps.keys():
		for segment: String in str(path).split("/", false):
			taken[segment.get_slice("#", 0)] = true
	var base: String = wanted.strip_edges() if not wanted.strip_edges().is_empty() else "Sub-assembly"
	if not taken.has(base):
		return base
	var n: int = 2
	while taken.has("%s %d" % [base, n]):
		n += 1
	return "%s %d" % [base, n]


# -- finding ------------------------------------------------------------------------


## The person's palette called [param name], whatever its letters' case.
static func _palette_named(name: String) -> Dictionary:
	var wanted: String = PartShelf.clean_name(name).to_lower()
	for one: Dictionary in PartShelf.palettes():
		if str(one["name"]).to_lower() == wanted:
			return one
	return {}


static func _none_called(name: String) -> String:
	var names := PackedStringArray()
	for one: Dictionary in PartShelf.palettes():
		names.append("“%s”" % str(one["name"]))
	return ("The person has no palette called “%s”%s. Nothing changed." % [name,
		(" (theirs: %s)" % ", ".join(names)) if not names.is_empty()
			else "; they have none yet, and edit_palette action=make makes one"])


static func _assembly_entry(one: Dictionary, name: String) -> Dictionary:
	var wanted: String = PartShelf.clean_name(name).to_lower()
	for entry: Dictionary in one["entries"]:
		if entry.has("ldraw") and str(entry["name"]).to_lower() == wanted:
			return entry
	return {}


## The palette's sub-assembly when it holds exactly one.
static func _only_assembly(one: Dictionary) -> Dictionary:
	var found: Array = (one["entries"] as Array).filter(func(entry: Dictionary) -> bool:
		return entry.has("ldraw"))
	return found[0] if found.size() == 1 else {}


static func _no_assembly(one: Dictionary, asked: String) -> String:
	var names := PackedStringArray()
	for entry: Dictionary in one["entries"]:
		if entry.has("ldraw"):
			names.append("“%s”" % str(entry["name"]))
	if names.is_empty():
		return "“%s” holds no sub-assembly. Nothing changed." % str(one["name"])
	if asked.is_empty():
		return "assembly= names which of “%s”'s sub-assemblies: %s. Nothing changed." % [
			str(one["name"]), ", ".join(names)]
	return "“%s” holds no sub-assembly called “%s” (it holds %s). Nothing changed." % [
		str(one["name"]), asked, ", ".join(names)]


static func _entry_of(one: Dictionary, entry_id: String) -> Dictionary:
	for entry: Dictionary in one.get("entries", []):
		if str(entry["id"]) == entry_id:
			return entry
	return {}


static func _part_entry(one: Dictionary, part: String, colour: int) -> Dictionary:
	for entry: Dictionary in one["entries"]:
		if entry.has("part") and str(entry["part"]).to_lower() == part.to_lower() \
				and int(entry["colour"]) == colour:
			return entry
	return {}


static func _part_name(library: PartLibrary, part: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part)
	return PartsBin.tile_name(info) if info != null else part


static func _colour_name(library: PartLibrary, code: int) -> String:
	var colour: PartLibrary.BrickColor = library.colors.get(code)
	return colour.name if colour != null else "colour %d" % code
