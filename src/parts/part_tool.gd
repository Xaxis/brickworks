## make_part: how a design gets a part LEGO has not made.
##
## A design that needs a 1 x 7 Technic brick, a bracket three studs wide or
## a 2 x 2 round brick without its stud has, until now, had to build round
## the gap — or put a part in that does not exist and be refused for it. A
## LEGO designer would ask for the element. This is that request, made the
## way a person makes one in Make a part: a family and its sizes
## ([ElementMaker]), or a real part and what to change about it
## ([PartEditor]). The same rules refuse the same things, in the same
## words, and the part made is built by [PartForge], added to the library
## under Custom and kept, as a person's is. Its number then goes in
## check_design, edit_model and submit_design like any part's, and a model
## saved with it carries it.
##
## Kept out of assistant.gd, which only declares it and passes the call
## through.
class_name PartTool
extends RefCounted

## How long to wait for a part's geometry to arrive on the web, in ms.
const FETCH_PATIENCE := 30000


static func schema() -> Dictionary:
	var number := func(what: String) -> Dictionary:
		return {"type": "integer", "description": what}
	return {
		"name": "make_part",
		"description": ("Make a part LEGO has not made, when no real part will do: "
			+ "search_parts first, and use a real one if there is one. Either a new "
			+ "part of a family at any size — a 1 x 7 brick, a bracket with a 3 x 2 "
			+ "upright, a Technic brick 1 x 9, a brick with studs on two sides — or "
			+ "a real part changed: from=\"3700\" with across 6, from=\"3062b\" "
			+ "without its studs. It is checked as a person's part is (sizes the "
			+ "system has, walls 1.6 mm, studs on the grid) and refused with the "
			+ "reason if it cannot be made. Made, it is a part like any other: put "
			+ "its number in check_design, edit_model or submit_design, and a saved "
			+ "model carries it. Its studs, holes and pins are found as a real "
			+ "part's are, so it clutches and pins as they do."),
		"input_schema": {
			"type": "object",
			"properties": {
				"family": {"type": "string", "enum": ElementMaker.FAMILIES,
					"description": ("for a new part: brick (also plates and tiles: "
						+ "plates 1, studs false), slope, curved (a curved slope), "
						+ "inverted (slope), round, bracket (a plate with an upright "
						+ "whose studs face forward), technic (a 1 x N brick with a "
						+ "hole between every two studs)")},
				"from": {"type": "string", "description": ("instead of a family: a "
					+ "real part's number to change, keeping everything not changed "
					+ "as LEGO made it. Longer, wider and taller repeat a slice of "
					+ "it; a part with no slice that repeats (a 1 x 1, a round brick "
					+ "across) is refused.")},
				"across": number.call("studs along X: a brick's length; a slope's, "
					+ "bracket's or curved slope's width along its face or upright; "
					+ "a Technic brick's length. With from: the new length."),
				"deep": number.call("studs along Z: a brick's width; a slope's depth "
					+ "from back to foot; a bracket's plate depth. With from: the new "
					+ "width."),
				"plates": number.call("height in plates, 3 to a brick (a bracket is "
					+ "1, a Technic brick 3). With from: the new height."),
				"run": number.call("slope, inverted, curved: the rows the face falls "
					+ "over, from the front; the rest are flat with studs"),
				"angle": {"type": "integer", "enum": [33, 45, 65, 75], "description":
					"slope, inverted: one of LEGO's named angles, which sets run and "
					+ "plates as the real part has them"},
				"diameter": number.call("round: studs across"),
				"rise": number.call("bracket: the upright's height in studs"),
				"way": {"type": "string", "enum": ["down", "up"], "description":
					"bracket: whether the upright hangs down from the plate's front "
					+ "edge or stands up from it"},
				"sides": {"type": "string", "description": ("brick: the sides with "
					+ "studs on them, letters of fblr: f is the +z face (the front), "
					+ "b -z, l -x, r +x; studs 10 LDU under the top and every stud "
					+ "down. Needs 3 plates or more.")},
				"studs": {"description": ("a new part: true for studs on top (the "
					+ "default), false for a tile. With from: \"keep\", \"none\" to "
					+ "take them off, \"fill\" to put them on wherever the top is "
					+ "flat.")},
				"name": {"type": "string", "description":
					"what to call it; left out, it is named as LDraw names its parts"},
			},
			"additionalProperties": false,
		},
	}


## Make the part, add it to the library, keep it, and say what it is.
## Awaitable: a part changed from one whose geometry the browser has not
## fetched waits for it.
static func run(args: Dictionary, library: PartLibrary) -> String:
	if library == null:
		return "No parts library to add a part to."
	var from: String = str(args.get("from", "")).strip_edges().to_lower().trim_suffix(".dat")
	if not from.is_empty():
		return await _change(args, library, from)
	return _new(args, library)


static func _new(args: Dictionary, library: PartLibrary) -> String:
	var spec := ElementMaker.Spec.new()
	spec.family = str(args.get("family", "brick"))
	if not ElementMaker.FAMILIES.has(spec.family):
		return ("Not made: there is no family called %s. The families are %s; or give "
			+ "from with a real part's number to change it.") % [spec.family,
			", ".join(ElementMaker.FAMILIES)]
	# Each family's sizes as the dialog starts them, then what was asked.
	match spec.family:
		"slope", "inverted":
			spec.deep = 2
			ElementMaker.use_angle(spec, 45)
		"curved":
			spec.deep = 2
			spec.run = 2
			spec.plates = 2
		"bracket":
			spec.across = 2
			spec.deep = 1
			spec.plates = 1
		"technic":
			spec.deep = 1
			spec.plates = 3
	for field: String in ["across", "deep", "plates", "run", "diameter", "rise"]:
		if args.has(field):
			spec.set(field, int(args[field]))
	if args.has("angle"):
		ElementMaker.use_angle(spec, int(args["angle"]))
		for field: String in ["run", "plates"]:
			if args.has(field):
				spec.set(field, int(args[field]))
	if args.has("way"):
		spec.way = str(args["way"])
	if args.has("sides"):
		spec.sides = ElementMaker.canonical_sides(str(args["sides"]))
	if args.has("studs"):
		spec.studs = _truthy(args["studs"])
	spec.title = str(args.get("name", "")).strip_edges()
	var problem: String = ElementMaker.problem(spec)
	if not problem.is_empty():
		return "Not made: %s. It was asked as: %s." % [problem, spec.to_words()]
	var result: Dictionary = CustomParts.make(library, spec)
	if not str(result["problem"]).is_empty():
		return "Not made: %s." % result["problem"]
	return describe(library, str(result["id"]))


static func _change(args: Dictionary, library: PartLibrary, from: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(from)
	if info == null:
		return "Not made: there is no part %s to change. search_parts finds part numbers." % from
	var mesh: Lbm.PartMesh = await _mesh(library, from)
	if mesh == null:
		return "Not made: %s's geometry is not here, and did not arrive." % from
	var size: Vector3i = PartEditor.size_of(mesh)
	var edit := PartEditor.Edit.new()
	edit.from = from
	if args.has("across") and int(args["across"]) != size.x:
		edit.length = int(args["across"])
	if args.has("deep") and int(args["deep"]) != size.z:
		edit.width = int(args["deep"])
	if args.has("plates") and int(args["plates"]) != size.y:
		edit.plates = int(args["plates"])
	if args.has("studs"):
		var studs: Variant = args["studs"]
		edit.studs = str(studs) if typeof(studs) == TYPE_STRING else ("keep" if bool(studs)
			else "none")
	edit.title = str(args.get("name", "")).strip_edges()
	var result: Dictionary = CustomParts.make_modified(library, edit)
	if not str(result["problem"]).is_empty():
		return ("Not made: %s. %s is %d x %d studs and %d plates; a part changes only "
			+ "where a slice of it repeats.") % [result["problem"], from, size.x, size.z, size.y]
	return describe(library, str(result["id"]))


## What a made part is, in the terms a design uses: its number, its size in
## studs and plates, and where things attach to it.
static func describe(library: PartLibrary, id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(id)
	var mesh: Lbm.PartMesh = library.mesh_for(id)
	if info == null or mesh == null:
		return "Made %s, but it is not in the library." % id
	var size: Vector3i = PartEditor.size_of(mesh)
	var top: int = 0
	var sides: Dictionary = {}
	var holes: int = 0
	var under: int = 0
	for c: Lbm.Connector in mesh.connectors:
		match c.kind:
			"stud":
				if c.axis.y > 0.99:
					top += 1
				else:
					var face: String = _face_of(c.axis)
					sides[face] = int(sides.get(face, 0)) + 1
			"pin_hole", "axle_hole":
				holes += 1
			"tube":
				under += 1
	var said := PackedStringArray()
	said.append("Made part \"%s\": %s. It is in the parts library now (Custom) — use \"%s\" as "
		% [id, Inventory._tidy(info.name), id]
		+ "the part in check_design, edit_model or submit_design like any other, and a "
		+ "saved model carries it.")
	# The height as it is, not rounded to a whole plate: a bracket's upright
	# hangs 2.5 plates, and "3" would put the next part half a plate off.
	var low: float = INF
	var high: float = -INF
	for cells: AABB in mesh.boxes:
		low = minf(low, cells.position.y * mesh.cell_ldu)
		high = maxf(high, cells.end.y * mesh.cell_ldu)
	var plates: float = snappedf((high - low) / PartEditor.PLATE if high > low
		else float(size.y), 0.25)
	said.append("Footprint %d x %d studs (x by z), %s plates tall." % [size.x, size.z,
		str(int(plates)) if is_equal_approx(plates, roundf(plates)) else str(plates)])
	var attach := PackedStringArray()
	attach.append("%d stud%s on top" % [top, "" if top == 1 else "s"])
	for face: String in sides:
		attach.append("%d on its %s face, pointing %s" % [sides[face], face, face])
	if holes > 0:
		attach.append("%d Technic hole%s through it" % [holes, "" if holes == 1 else "s"])
	if under > 0:
		attach.append("%d tube%s or pin%s underneath" % [under, "" if under == 1 else "s",
			"" if under == 1 else "s"])
	said.append("It has " + ", ".join(attach) + ".")
	if not sides.is_empty():
		said.append("A part held by a side stud is placed with face set to that "
			+ "direction, its y the top of this part less 2.5 plates (the first row of "
			+ "side studs is 10 LDU under the top, and a part on it is a stud, 2.5 "
			+ "plates, across); each row further down is 2.5 plates lower. "
			+ "attachment_points gives the exact places.")
	return " ".join(said)


static func _face_of(axis: Vector3) -> String:
	if absf(axis.x) > 0.5:
		return "+x" if axis.x > 0.0 else "-x"
	if absf(axis.z) > 0.5:
		return "+z" if axis.z > 0.0 else "-z"
	return "up" if axis.y > 0.0 else "down"


static func _truthy(value: Variant) -> bool:
	if typeof(value) == TYPE_STRING:
		return not ["false", "no", "0", "none", "off"].has(str(value).to_lower())
	return bool(value)


## A part's geometry, fetched first if this build does not have it (the web
## carries some parts and fetches the rest), waiting up to FETCH_PATIENCE.
static func _mesh(library: PartLibrary, id: String) -> Lbm.PartMesh:
	var mesh: Lbm.PartMesh = library.mesh_for(id)
	if mesh != null:
		return mesh
	if not library.request_mesh(id, true):
		return null
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var deadline: int = Time.get_ticks_msec() + FETCH_PATIENCE
	while tree != null and library.mesh_for(id) == null and library.is_on_its_way(id) \
			and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return library.mesh_for(id)
