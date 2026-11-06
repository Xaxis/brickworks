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
## The last whole booklet made for a page past the steps: [key, html].
var _booklet: Array = []


static func definitions() -> Array:
	var parts: Dictionary = {"type": "array", "items": {"type": "integer"},
		"description": "parts by their numbers in look_at_model"}
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
				+ "new parts edged in magenta (edit_steps lists the steps). Changes nothing."),
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
	var picked: Variant = _parts(input, "highlight")
	if picked is String:
		return picked
	var through: Variant = _parts(input, "xray")
	if through is String:
		return through
	var skip: Dictionary = store.scenery.duplicate()
	var said := PackedStringArray()
	var new_ids: Array = []
	if input.has("step"):
		var built: Variant = _as_built(int(input["step"]), skip)
		if built is String:
			return built
		new_ids = built[0]
		said.append(built[1])
	if LeasedShots.in_use() and not ((picked as Array).is_empty()
			and (through as Array).is_empty() and not input.has("step")):
		return ("This app draws its pictures in a drawer of its own (a bench run), which "
			+ "draws the model as view_model does and no more: highlight=, xray= and step= "
			+ "are drawn in a window.")
	var shot: ModelShot = _ensure_shot()
	shot.edged = {}
	shot.see_through = {}
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
			return ("No picture in time from the %s; ask again, or look_at_model reads the "
				+ "model in words.") % view
		pictures.append(image)
	shot.edged = {}
	shot.see_through = {}
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
	if not (picked as Array).is_empty() or not new_ids.is_empty():
		said.append("The magenta is only in the picture; the parts keep their colours.")
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


## [param field]'s part numbers, those in the model; or why not.
func _parts(input: Dictionary, field: String) -> Variant:
	var given: Variant = input.get(field, [])
	if not given is Array:
		return "%s= is a list of part numbers, from look_at_model." % field
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var ids: Array = []
	var unknown := PackedStringArray()
	for raw: Variant in given:
		var number: int = int(raw)
		if store.scenery.has(number) or world.get_brick(number) == null:
			unknown.append(str(number))
		elif not ids.has(number):
			ids.append(number)
	if not unknown.is_empty():
		return "No part numbered %s (look_at_model numbers them)." % ", ".join(unknown)
	return ids


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
