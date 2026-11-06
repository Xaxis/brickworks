## What a session sees, as a person sees it (APP_UX4, seeing).
##
## A person turns the model round, picks parts out, sees through the roof,
## steps the timeline back and reads the booklet's pages. A session had one
## view a call (view_model), nothing picked out but what an edit had just
## changed, and the booklet in numbers alone (booklet_layout): on the MCP
## walk it checked a model from three sides in three calls, and described
## page 2 in millimetres, saying it had not seen it. ldraw-xray, made for
## agents to inspect LDraw models, and Brickforge's capture_model draw
## exactly these: boards of views, named parts edged with the rest ghosted,
## a shell seen through, the model as built to a step.
##
## view_board: up to six of view_model's views in one labelled picture,
## each the view view_model gives alone (ModelShot, the same camera and
## lights), and with highlight=, xray= and step= the parts picked out, seen
## through, or the model as built to a step. booklet_page: a page of the
## booklet as Instructions draws it and its PDF prints it (BookletPng), so
## a session that edits the booklet sees what it did.
##
## Both change nothing. Tools of AppTools, served wherever the app's tools
## are: the desktop's MCP port, My Claude and the connector.
class_name SeeTools
extends RefCounted

const NAMES: Array[String] = ["view_board", "booklet_page"]
## view_model's views, in the board's order.
const VIEWS: Array[String] = ["front", "back", "left", "right", "top", "corner"]
## Each view's side on a board of two or more, px: the board of six is
## 1536 x 1104, about what one picture costs a conversation at 1.6 of
## view_model's (Claude counts an image as width x height / 750 tokens),
## where six calls cost six.
const CELL := 512
## A booklet page's pixels a millimetre: 1,399 x 1,035 for the 269 x 199
## mm page, under the 1,568 px Claude scales a picture down to.
const PAGE_DENSITY := 5.2

var app: Node
var _shot: ModelShot
## Each part's studs' ways in its own frame, kept between stud maps (StudMap).
var _ways: Dictionary = {}
## The last whole booklet made for a page past the steps: [key, html].
var _booklet: Array = []


static func definitions() -> Array:
	# A list or one of them: brick numbers, part numbers, colours or a step
	# (APP_UX5 seeing2). Untyped, as edit_booklet's pull= is: a JSON schema
	# of one type turned "3024" away.
	var parts: Dictionary = {"description": ("parts, one or a list of: their numbers in "
		+ "look_at_model (12), a part number as a string (\"3024\": every one of it), a colour "
		+ "(\"red\"), or a step (\"step:3\": that step's new parts)")}
	return [
		{
			"name": "view_board",
			"description": ("Look at the model from up to six sides in one picture: each "
				+ "view labelled, and each the picture view_model gives from that side "
				+ "(views= any of front, back, left, right, top, corner; all six when not "
				+ "given). Also takes, with one view or several: where= to look closely at "
				+ "one box, as view_model's; highlight= parts edged in magenta in their own "
				+ "colours with every other part drawn see-through, to find them in a big "
				+ "model or inside it; xray= parts drawn see-through, so what they hide shows "
				+ "(a roof, a shell, a hull); step=N the model as built to step N, that step's "
				+ "new parts edged in magenta (edit_steps lists the steps); studs=true every part "
				+ "coloured by where its studs point (up, down, front, back, left, right), a "
				+ "legend under the picture, to see which way a part offers studs before "
				+ "building on it. Changes nothing."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"views": {"type": "array", "items": {"type": "string", "enum": VIEWS},
					"description": "the sides, in the board's order"},
				"where": {"type": "object", "additionalProperties": false,
					"description": "a box in studs and plates to look closely at",
					"required": ["x_from", "x_to", "y_from", "y_to", "z_from", "z_to"],
					"properties": {
						"x_from": {"type": "number"}, "x_to": {"type": "number"},
						"y_from": {"type": "number"}, "y_to": {"type": "number"},
						"z_from": {"type": "number"}, "z_to": {"type": "number"},
					}},
				"highlight": parts,
				"xray": parts,
				"step": {"type": "integer", "description": "a step's number, from 1"},
				"studs": {"type": "boolean", "description": ("each part coloured by where its "
					+ "studs point, as View, Stud directions draws it")},
			}},
		},
		{
			"name": "booklet_page",
			"description": ("A page of the building instructions as a picture, drawn as "
				+ "Instructions draws it and as its PDF prints it: page 1 the cover, the "
				+ "steps' pages from 2 (booklet_layout lists them), then the finished model "
				+ "and the parts list. See what edit_booklet did. A steps page is drawn on its "
				+ "own in seconds; the cover and the pages after the steps need the whole "
				+ "booklet, which on a big model takes minutes (a job). Changes nothing."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["page"], "properties": {
					"page": {"type": "integer", "description": "the page's number, from 1"},
				}},
		},
	]


## A coroutine, as AppTools.run is.
func run(tool: String, input: Dictionary, work: Working.Job = null) -> Variant:
	match tool:
		"view_board":
			return await _view_board(input)
		"booklet_page":
			return await _booklet_page(input, work)
	return "No tool called %s." % tool


# -- view_board ---------------------------------------------------------------------


func _view_board(input: Dictionary) -> Variant:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var library: PartLibrary = app.get("_library")
	if world.brick_count() - store.scenery.size() <= 0:
		return "There is nothing built to look at yet."
	if not ModelShot.possible():
		return ("This app is running without a window, so it has nothing to draw a picture "
			+ "with; look_at_model reads the model in words.")
	var views: Array[String] = []
	for raw: Variant in input.get("views", VIEWS):
		var view: String = str(raw)
		if not view in VIEWS:
			return "views= are any of %s; %s is not one." % [", ".join(VIEWS), view]
		if not view in views:
			views.append(view)
	if views.is_empty():
		return "views= names at least one side: %s." % ", ".join(VIEWS)
	var said := PackedStringArray()
	var picked: Variant = _parts(input, "highlight", said)
	if picked is String:
		return picked
	var through: Variant = _parts(input, "xray", said)
	if through is String:
		return through
	var studs: bool = bool(input.get("studs", false))
	var skip: Dictionary = store.scenery.duplicate()
	var new_ids: Array = []
	if input.has("step"):
		var built: Variant = _as_built(int(input["step"]), skip)
		if built is String:
			return built
		new_ids = built[0]
		said.append(built[1])
	if LeasedShots.in_use() and not ((picked as Array).is_empty()
			and (through as Array).is_empty() and not input.has("step") and not studs):
		return ("This app draws its pictures in a drawer of its own (a bench run), which "
			+ "draws the model as view_model does and no more: highlight=, xray=, step= "
			+ "and studs= are drawn in a window.")
	var shot: ModelShot = _ensure_shot()
	shot.edged = {}
	shot.see_through = {}
	shot.painted = {}
	var facing: Dictionary = {}
	if studs:
		facing = StudMap.facings(world, library, skip, _ways)
		shot.painted = StudMap.paints(facing)
		said.append(StudMap.said(facing, world, library))
	for brick_id: int in picked as Array:
		shot.edged[brick_id] = true
	for brick_id: int in new_ids:
		shot.edged[brick_id] = true
	for brick_id: int in through as Array:
		shot.see_through[brick_id] = true
	if not (picked as Array).is_empty():
		# The rest ghosted, so the parts picked out are seen wherever they are.
		for brick: BrickWorld.Brick in world.bricks():
			if not skip.has(brick.id) and not shot.edged.has(brick.id):
				shot.see_through[brick.id] = true
		var hidden: Array = (picked as Array).filter(func(brick_id: int) -> bool:
			return skip.has(brick_id))
		said.append("Edged in magenta, in their own colours: %s; every other part drawn "
			% _named(picked) + "see-through.")
		if not hidden.is_empty():
			said.append("Not built yet at that step, so not drawn: %s." % _named(hidden))
	if not (through as Array).is_empty():
		said.append("Drawn see-through, so what they hide shows: %s." % _named(through))
	var close: AABB = Assistant._box_from(input.get("where"))
	var pictures: Array[Image] = []
	for view: String in views:
		var image: Image = await shot.take(world, view, skip, close)
		if image == null:
			shot.edged = {}
			shot.see_through = {}
			shot.painted = {}
			return ("No picture in time from the %s; ask again, or look_at_model reads the "
				+ "model in words.") % view
		pictures.append(image)
	shot.edged = {}
	shot.see_through = {}
	shot.painted = {}
	var picture: Image = pictures[0]
	var labels := PackedStringArray()
	for view: String in views:
		labels.append(view.capitalize() + (", close up" if close.size.length() > 0.0 else "")
			+ (", step %d" % int(input["step"]) if input.has("step") else ""))
	if pictures.size() > 1:
		var columns: int = 2 if pictures.size() in [2, 4] else 3
		picture = await shot.board(pictures, labels, CELL, columns)
		said.insert(0, "The model from %s, in one picture %d x %d px: each labelled, and each "
			% [_listed(views), picture.get_width(), picture.get_height()]
			+ "the picture view_model gives from that side, %d px a side." % CELL)
	else:
		said.insert(0, "The model from the %s%s, %d px a side:" % [views[0],
			", close up" if close.size.length() > 0.0 else "", picture.get_width()])
	if studs:
		picture = await StudMap.with_legend(shot, picture, StudMap.counts(facing))
		said.insert(1, "The stud map's legend is under the picture.")
	if not (picked as Array).is_empty() or not new_ids.is_empty():
		said.append("The magenta is only in the picture; the parts keep their colours.")
	if studs:
		said.append("The stud colours are only in the picture; the parts keep their own.")
	return [{"type": "text", "text": "\n".join(said)}, AppTools._picture_block(picture)]


## The pictures' own taker, kept: the model staged once for every view, and
## none of the design's pictures held up by a session's (the assistant's
## ModelShot carries what its last edit changed).
func _ensure_shot() -> ModelShot:
	if _shot == null or not is_instance_valid(_shot):
		_shot = ModelShot.new()
		_shot.library = app.get("_library")
		app.add_child(_shot)
	return _shot


## [param field]'s parts, those in the model: a list of selectors, or one,
## each a brick's number (look_at_model's), a part number ("3024": every
## one of it), a colour ("red") or a step ("step:3": its new parts); or why
## not. What each picked, when it was not a brick's number, said in
## [param said]. A session that wanted the car's 1 x 1 plates listed ten
## numbers it first had to find (APP_UX5 seeing2).
func _parts(input: Dictionary, field: String, said: PackedStringArray = PackedStringArray()) -> Variant:
	var given: Variant = input.get(field, [])
	if not (given is Array):
		given = [given]
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var library: PartLibrary = app.get("_library")
	var ids: Array = []
	var unknown := PackedStringArray()
	var by: PackedStringArray = PackedStringArray()
	for raw: Variant in given:
		var found: Variant = _selected(raw, world, store, library)
		if found is String:
			unknown.append(str(found))
			continue
		var picked: Array = found[0]
		if not str(found[1]).is_empty():
			by.append(str(found[1]))
		for brick_id: int in picked:
			if not ids.has(brick_id):
				ids.append(brick_id)
	if not unknown.is_empty():
		return ("%s= takes a part's number from look_at_model (12), a part number as a string "
			% field + "(\"3024\"), a colour (\"red\") or a step (\"step:3\"): %s." % "; ".join(unknown))
	if not by.is_empty():
		said.append("%s %s." % ["Picked out:" if field == "highlight" else "Seen through:",
			"; ".join(by)])
	return ids


## One selector's parts and what it picked, in words ("" for a brick's own
## number); or why it picks none.
func _selected(raw: Variant, world: BrickWorld, store: ModelStore, library: PartLibrary) -> Variant:
	var standing: Callable = func(brick_id: int) -> bool:
		return not store.scenery.has(brick_id) and world.get_brick(brick_id) != null
	if raw is float or raw is int:
		var number: int = int(raw)
		if standing.call(number):
			return [[number], ""]
		# A part number given as a number: 3024 is no brick of the car's.
		var as_part: Array = _of_part(str(number), world, store)
		if not as_part.is_empty():
			return [as_part, _part_said(str(number), as_part.size(), library)]
		return "no part numbered %d (look_at_model numbers them)" % number
	var text: String = str(raw).strip_edges()
	var lower: String = text.to_lower()
	var step: RegExMatch = RegEx.create_from_string("^step\\s*[:=#]?\\s*(\\d+)$").search(lower)
	if step != null:
		var built: Variant = _as_built(int(step.get_string(1)), {})
		if built is String:
			return "%s: %s" % [text, (built as String).trim_suffix(".")]
		return [built[0], "step %d's %d new part%s" % [int(step.get_string(1)),
			(built[0] as Array).size(), "" if (built[0] as Array).size() == 1 else "s"]]
	if lower.begins_with("#") and lower.substr(1).is_valid_int():
		if standing.call(int(lower.substr(1))):
			return [[int(lower.substr(1))], ""]
		return "no part numbered %s" % text
	var part: String = lower.trim_suffix(".dat")
	var of_part: Array = _of_part(part, world, store)
	if not of_part.is_empty():
		return [of_part, _part_said(part, of_part.size(), library)]
	var codes: Array = _colour_codes(lower, library)
	if not codes.is_empty():
		var coloured: Array = []
		for brick: BrickWorld.Brick in world.bricks():
			if not store.scenery.has(brick.id) and brick.color_code in codes:
				coloured.append(brick.id)
		if coloured.is_empty():
			return "no part of the model is %s" % text
		return [coloured, "%d %s part%s" % [coloured.size(), library.color(int(codes[0])).name,
			"" if coloured.size() == 1 else "s"]]
	if lower.is_valid_int() and standing.call(int(lower)):
		return [[int(lower)], ""]
	if library != null and library.parts.has(part):
		return "no %s in the model" % text
	return "%s is no part's number, part number, colour or step here" % text


## Every part of [param part_id] standing, by number.
func _of_part(part_id: String, world: BrickWorld, store: ModelStore) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if not store.scenery.has(brick.id) and brick.part_id.to_lower() == part_id:
			out.append(brick.id)
	return out


func _part_said(part_id: String, count: int, library: PartLibrary) -> String:
	return "%s, every %s (%d)" % [part_id, HandTools._part_name(library, part_id), count]


## The colour codes named [param words], LDraw's name or LEGO's ("red",
## "Bright Red", "light bluish grey"), as a colour's code ("4") does not:
## a number is a brick's.
static func _colour_codes(words: String, library: PartLibrary) -> Array:
	var asked: String = words.replace("_", " ").replace("-", " ").strip_edges()
	while asked.contains("  "):
		asked = asked.replace("  ", " ")
	asked = asked.replace("gray", "grey")
	var out: Array = []
	if library == null or asked.is_empty():
		return out
	for code: int in library.colors:
		var colour: PartLibrary.BrickColor = library.colors[code]
		for name: String in [colour.name, colour.lego_name]:
			if name.to_lower().replace("_", " ").replace("gray", "grey") == asked and not code in out:
				out.append(code)
	return out


## The model as built to step [param number]: what is not built yet left
## out ([param skip] grows), and [that step's new parts, what to say]; or
## why not.
func _as_built(number: int, skip: Dictionary) -> Variant:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var library: PartLibrary = app.get("_library")
	var steps: Array[Instructions.Step] = Instructions.plan(world, library, store.scenery, {},
		true)
	if steps.is_empty():
		return "There is nothing built to have steps."
	var last: int = steps[steps.size() - 1].number
	if number < 1 or number > last:
		return "There is no step %d: the steps run 1 to %d (edit_steps lists them)." % [number,
			last]
	var built: Dictionary = {}
	var fresh: Array = []
	for step: Instructions.Step in steps:
		if step.number > number:
			continue
		for brick_id: int in step.brick_ids:
			built[brick_id] = true
			if step.number == number and not fresh.has(brick_id):
				fresh.append(brick_id)
	for brick: BrickWorld.Brick in world.bricks():
		if not built.has(brick.id):
			skip[brick.id] = true
	return [fresh, "As built to step %d of %d, %d parts; step %d's %d new parts edged in magenta: %s." % [
		number, last, built.size(), number, fresh.size(), _named(fresh)]]


## "#12 Brick 2 x 4, #14 Seat 2 x 2": at most eight named, then how many more.
func _named(ids: Array) -> String:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var said := PackedStringArray()
	for brick_id: int in ids.slice(0, 8):
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		said.append("#%d %s" % [brick_id, HandTools._part_name(library, brick.part_id)
			if brick != null else "?"])
	if ids.size() > 8:
		said.append("and %d more" % (ids.size() - 8))
	return ", ".join(said)


static func _listed(views: Array[String]) -> String:
	var words: Array = views.map(func(view: String) -> String:
		return "the corner" if view == "corner" else view)
	if words.size() == 1:
		return str(words[0])
	return "%s and %s" % [", ".join(PackedStringArray(words.slice(0, words.size() - 1))),
		words[words.size() - 1]]


# -- a hand tool's change, pictured ---------------------------------------------------

## A close look's side, px: edit_model's (Assistant.CLOSE_UP), a quarter of a
## whole picture's cost.
const CLOSE_UP := 480
## Room round what changed in a close look, LDU: two studs, as edit_model's.
const ROOM := 40.0


## [param said], a mirror's, split's or merge's answer, with the parts it
## made ([param made]) pictured as edit_model answers: unset [param wanted]
## a close look at them from the corner, edged in magenta; true the whole
## model so; false the words alone. On the MCP walk three looks in thirteen
## tasks were only to see what these did (APP_UX4).
func pictured(said: String, made: PackedInt64Array, wanted: Variant) -> Variant:
	if (wanted is bool and not bool(wanted)) or not ModelShot.possible() \
			or LeasedShots.in_use():
		return said
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var library: PartLibrary = app.get("_library")
	var box := AABB()
	var first: bool = true
	for brick_id: int in made:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if part == null:
			continue
		var here: AABB = (brick.transform * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	if first:
		return said
	var whole: bool = wanted is bool and bool(wanted)
	var shot: ModelShot = _ensure_shot()
	shot.edged = {}
	shot.see_through = {}
	for brick_id: int in made:
		shot.edged[brick_id] = true
	var image: Image = await shot.take(world, "corner", store.scenery,
		AABB() if whole else box.grow(ROOM))
	shot.edged = {}
	if image == null:
		return said
	if not whole:
		image.resize(CLOSE_UP, CLOSE_UP, Image.INTERPOLATE_LANCZOS)
	return [{"type": "text", "text": said},
		{"type": "text", "text": ("The whole model from the corner, the %d made edged in magenta:"
			if whole else "Close up on what changed, from the corner, the %d made edged in "
			+ "magenta (picture=true shows the whole model):") % made.size()},
		AppTools._picture_block(image),
		{"type": "text", "text": "The magenta is only in the picture; the parts keep their colours."}]


# -- check_design's findings, pictured ------------------------------------------------

## The most named parts edged in one picture.
const FINDINGS_MOST := 40


## check_design's [param answer] with the parts its findings name pictured
## (APP_UX5 seeing2): a check of the model as it stands (edit=) that finds a
## part floating, overlapping or not joined names it "#14", and a session
## then looked for #14 in look_at_model's list. Each named part standing
## edged in magenta in its own colours and every other part see-through,
## from the corner, as view_board's highlight= draws them; the parts the
## change takes off left out. A check of a list of bricks (bricks=) names
## parts that are not on the baseplate, and is answered as it was; so is a
## check whose findings name none.
func findings_pictured(answer: Variant, input: Dictionary) -> Variant:
	if not (answer is String) or not (input.get("edit") is Dictionary) \
			or not ModelShot.possible() or LeasedShots.in_use():
		return answer
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var text: String = answer
	# The findings: what comes before the weighing, past the line saying what
	# was asked, which names the parts the change touches.
	var findings: String = text.get_slice("\nBalance:", 0)
	if findings.begins_with("What if"):
		findings = findings.substr(findings.find("\n") + 1) if findings.contains("\n") else ""
	var edit: Dictionary = input["edit"]
	var gone: Dictionary = store.scenery.duplicate()
	for raw: Variant in (edit["remove"] if edit.get("remove") is Array else []):
		gone[int(raw)] = true
	var named: Array = []
	for found: RegExMatch in RegEx.create_from_string("#(\\d+)").search_all(findings):
		var brick_id: int = int(found.get_string(1))
		if not gone.has(brick_id) and world.get_brick(brick_id) != null \
				and not named.has(brick_id):
			named.append(brick_id)
	if named.is_empty():
		return answer
	var shot: ModelShot = _ensure_shot()
	shot.edged = {}
	shot.see_through = {}
	shot.painted = {}
	for brick_id: int in named.slice(0, FINDINGS_MOST):
		shot.edged[brick_id] = true
	for brick: BrickWorld.Brick in world.bricks():
		if not gone.has(brick.id) and not shot.edged.has(brick.id):
			shot.see_through[brick.id] = true
	var image: Image = await shot.take(world, "corner", gone)
	shot.edged = {}
	shot.see_through = {}
	if image == null:
		return answer
	var moved: bool = not edit.keys().filter(func(key: String) -> bool:
		return key != "remove").is_empty()
	var said: String = ("The part%s the findings name, edged in magenta in %s own colours, every "
		% ["" if named.size() == 1 else "s", "its" if named.size() == 1 else "their"]
		+ "other part see-through, from the corner%s: %s." % [
			", without the parts the change takes off" if gone.size() > store.scenery.size() else "",
			_named(named)])
	if moved:
		said += (" Drawn as the model stands: the change was made to a copy, so a part it "
			+ "moves, turns or adds is not drawn so.")
	return [{"type": "text", "text": text}, {"type": "text", "text": said},
		AppTools._picture_block(image),
		{"type": "text", "text": "The magenta is only in the picture; the parts keep their colours."}]


# -- booklet_page -------------------------------------------------------------------


func _booklet_page(input: Dictionary, work: Working.Job) -> Variant:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var library: PartLibrary = app.get("_library")
	var bar: ModelBar = app.get("_bar")
	if world.brick_count() - store.scenery.size() <= 0:
		return "There is nothing built to make a booklet of."
	if DisplayServer.get_name() == "headless":
		return ("The booklet's pictures need something to draw with, and this app is running "
			+ "without a window; booklet_layout reads its pages in numbers.")
	if BookletMaker.busy:
		return "The booklet is being drawn already; ask again once it is done."
	var number: int = int(input.get("page", 0))
	if number < 1:
		return "Give page= a page's number, from 1, the cover; booklet_layout lists the steps' pages."
	var title: String = bar.model_name() if bar != null else "Model"
	var maker: BookletMaker = _maker()
	var laid: Array[Booklet.Page] = await maker.lay_out_only(world, store.scenery, title)
	maker.queue_free()
	if laid.is_empty():
		return "There is nothing built to make a booklet of."
	var first: int = laid[0].number
	var last: int = laid[laid.size() - 1].number
	var shown: Booklet.Page = null
	for page: Booklet.Page in laid:
		if page.number == number:
			shown = page
	var html: String = ""
	var what: String = ""
	if shown != null and shown.kind == "steps":
		# The page's own steps drawn and no others: seconds, where the whole
		# booklet of a big model is minutes (the page editor's way).
		var numbers: Dictionary = {}
		for entry: Booklet.Entry in shown.entries:
			numbers[entry.number] = true
		maker = _maker()
		if work != null:
			work.say("Drawing page %d of the booklet…" % number)
		var drawn: Array[Booklet.Page] = await maker.draw_steps(world, store.scenery, title, numbers)
		var document: Booklet.Document = maker.document
		maker.queue_free()
		for page: Booklet.Page in drawn:
			if page.number == number and document != null:
				html = "%s\n%s\n%s\n%s" % [Booklet.head(document, false),
					Booklet.parts_style(document), Booklet.page_html(page, document), Booklet.TAIL]
		var steps: Array = numbers.keys()
		steps.sort()
		what = "step%s %s" % ["" if steps.size() == 1 else "s", ", ".join(PackedStringArray(
			steps.map(func(n: int) -> String: return str(n))))]
	else:
		html = await _whole_booklet(title, work)
		what = "the cover" if number == 1 else ("a callout's page" if shown != null
			else "past the steps: the finished model or the parts list")
	if html.is_empty():
		return "The booklet could not be drawn; ask again."
	var drawer := BookletPng.new()
	app.add_child(drawer)
	var image: Image = drawer.page_image(html, number, PAGE_DENSITY)
	drawer.queue_free()
	if image == null:
		return ("The booklet has no page %d: page 1 is the cover, the steps run on pages %d to "
			% [number, first] + "%d, and the finished model and the parts list follow." % last)
	return [{"type": "text", "text": ("Page %d (%s), as Instructions draws it and its PDF prints "
		+ "it, %d x %d px. The steps run on pages %d to %d, after the cover; the finished model "
		+ "and the parts list follow.") % [number, what, image.get_width(), image.get_height(),
		first, last]}, AppTools._picture_block(image)]


func _maker() -> BookletMaker:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var library: PartLibrary = app.get("_library")
	var maker := BookletMaker.new()
	maker.library = library
	# The hidden parts' colours shown where each group starts, as Export's.
	maker.marks = HiddenColours.live_marks(store.hidden_scheme, world, library, store.scenery)
	app.add_child(maker)
	return maker


## The whole booklet, as Instructions makes it, kept while the model and how
## its steps are printed stay as they are.
func _whole_booklet(title: String, work: Working.Job) -> String:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var key: Array = [world.get_instance_id(), world.generation(), world.revision,
		str(world.step_looks).hash(), store.scenery.hash(), title]
	if not _booklet.is_empty() and _booklet[0] == key:
		return _booklet[1]
	var maker: BookletMaker = _maker()
	maker.job = work
	if work != null:
		work.say("Drawing the booklet of %s…" % title)
	var html: String = await maker.make(world, store.scenery, title)
	maker.queue_free()
	_booklet = [key, html] if not html.is_empty() else []
	return html
