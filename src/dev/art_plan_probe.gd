## Check a LEGO Art plan is laid as it says, and a bad one is refused.
##
##   godot --headless --path . --script src/dev/art_plan_probe.gd [-- --ldr=PATH]
##
## No network: the plans are canned, written as Claude writes them for the
## make_art tool. The failure that matters is a plan that is accepted and
## then quietly not kept to — the subject left flat, a background in round
## tiles, a star in the wrong finish — because the picture still looks like
## a picture. So each check reads what was laid against what the plan said,
## stud by stud. Then the tool itself, as the assistant and a session over
## MCP call it, and the dialog's Design with Claude.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	root.add_child(_assistant)
	await process_frame

	await _picture_case()
	_svg_case()
	_big_star_case()
	_refusals()
	await _tool_case()
	await _dialog_case()
	print("")
	print("%d failed" % _failures if _failures else "an Art plan is laid as it says")
	quit(1 if _failures else 0)


## A galaxy seen at an angle, as a photograph would have it: dark sky, a
## pale tilted disc, a bright core, a few stars. 192 x 128 pixels, 3 x 2
## panels at four pixels a stud.
func _photo() -> Image:
	var image := Image.create_empty(192, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.03, 0.03, 0.08))
	for y: int in 128:
		for x: int in 192:
			var d := Vector2((x + 0.5) - 96.0, ((y + 0.5) - 64.0) / 0.45)
			var r: float = d.length() / 80.0
			if r < 1.0:
				var c: Color = Color(0.03, 0.03, 0.08).lerp(Color(0.45, 0.5, 0.75), 1.0 - r)
				if r < 0.25:
					c = c.lerp(Color(1.0, 0.92, 0.7), 1.0 - r / 0.25)
				image.set_pixel(x, y, c)
	return image


## The plan a designer would write for that photograph.
const PLAN := {
	"name": "A galaxy, tilted",
	"panels": [3, 2],
	"base_colour": 0,
	"depth": 0,
	"palette": [0, 1, 272, 72, 71, 15, 14, 191, 226, 212, 320],
	"regions": [
		{"name": "sky", "everything": true, "texture": "smooth", "relief": 0,
			"contours": false, "stars": false},
		{"name": "disc", "ellipse": {"cx": 0.5, "cy": 0.5, "rx": 0.36, "ry": 0.16},
			"texture": "round", "relief": 1, "contours": true},
		{"name": "core", "ellipse": {"cx": 0.5, "cy": 0.5, "rx": 0.1, "ry": 0.07},
			"relief": 3, "texture": "smooth"},
	],
	"points": [
		{"at": [0.08, 0.12], "finish": "glow"},
		{"at": [0.9, 0.2], "finish": "trans-clear"},
		{"at": [0.15, 0.85], "finish": "pearl-gold"},
	],
}


func _picture_case() -> void:
	print("a canned plan over a photograph: sky smooth and flat, disc round and "
		+ "raised one, core raised three, three stars put by hand")
	var plan: ArtPlan = ArtPlan.parse(PLAN, _library)
	_check("the plan is accepted: %s" % ("yes" if plan.ok() else plan.trouble()), plan.ok())
	var art: MosaicArt.Art = plan.lay(_photo(), _library)
	if art == null:
		_check("and laid", false)
		return
	print("  %s" % ArtPlan.said_of(art))
	var p: MosaicArt.Plan = art.plan
	_check("on 3 x 2 panels, 48 x 32 studs", art.panels == Vector2i(3, 2)
		and p.across == 48 and p.down == 32)
	_check("on black panels, as the plan says", art.base_colour == 0)

	# Relief where the plan says, stud by stud.
	var disc: ArtPlan.Region = plan.regions[1]
	var core: ArtPlan.Region = plan.regions[2]
	var tall: float = float(p.down) / float(p.across)
	var wrong := PackedStringArray()
	var counted := {"sky": 0, "disc": 0, "core": 0}
	var stars: Dictionary = {}
	for point: Array in plan.points:
		var at: Vector2 = point[0]
		stars[Vector2i(int(at.x * p.across), int(at.y * p.down))] = int(point[1])
	for z: int in p.down:
		for x: int in p.across:
			if stars.has(Vector2i(x, z)):
				continue
			var at := Vector2((x + 0.5) / p.across, (z + 0.5) / p.down)
			var want: int = 3 if core.holds(at, tall) else (1 if disc.holds(at, tall) else 0)
			counted["core" if want == 3 else ("disc" if want == 1 else "sky")] += 1
			if p.relief[p.at(x, z)] != want:
				wrong.append("%d,%d is %d not %d" % [x, z, p.relief[p.at(x, z)], want])
	_check("every stud stands as high as its region says — %d core, %d disc, %d sky (%d wrong: %s)"
		% [counted["core"], counted["disc"], counted["sky"], wrong.size(),
			", ".join(wrong.slice(0, 4))], wrong.is_empty() and counted["core"] > 10)
	_check("nothing is a hole", not p.style.has(MosaicArt.Style.HOLE))

	# Texture where the plan says: what is on top of each stud.
	var tops: Dictionary = _tops(art)
	var round_in_sky: int = 0
	var square_in_disc: int = 0
	var disc_tops: int = 0
	var smooth_core: int = 0
	var core_tops: int = 0
	for z: int in p.down:
		for x: int in p.across:
			var key := Vector2i(x, z)
			if stars.has(key):
				continue
			var top: Assistant.Placement = tops.get(key)
			if top == null:
				continue
			var at := Vector2((x + 0.5) / p.across, (z + 0.5) / p.down)
			var round: bool = top.part in [MosaicArt.ROUND, MosaicArt.SPECK]
			if core.holds(at, tall):
				core_tops += 1
				if not round:
					smooth_core += 1
			elif disc.holds(at, tall):
				disc_tops += 1
				if not round and top.part != MosaicArt.QUARTER and top.part != MosaicArt.SLOPE:
					square_in_disc += 1
			elif round:
				round_in_sky += 1
	_check("the sky is smooth tiles: %d round elements in it" % round_in_sky, round_in_sky == 0)
	_check("the disc is round tiles, sloped up to the core: %d of %d square"
		% [square_in_disc, disc_tops], disc_tops > 50 and square_in_disc == 0)
	_check("the core is smooth: %d of %d not round" % [smooth_core, core_tops],
		core_tops > 10 and smooth_core == core_tops)
	var slopes: int = int(art.counts().get(MosaicArt.SLOPE, 0))
	_check("cheese slopes from the disc up to the core: %d" % slopes, slopes >= 6)
	var quarters: int = int(art.counts().get(MosaicArt.QUARTER, 0))
	var sky_quarters: int = 0
	for placement: Assistant.Placement in art.placements:
		if placement.part == MosaicArt.QUARTER:
			var at := Vector2((placement.x + 0.5) / p.across, (placement.z + 0.5) / p.down)
			if not disc.holds(at, tall):
				sky_quarters += 1
	_check("quarter circles only where contours are allowed: %d, %d of them in the sky"
		% [quarters, sky_quarters], sky_quarters == 0)

	# The stars put by hand, in their finishes, a plate proud of the sky.
	var placed: int = 0
	var said := PackedStringArray()
	for key: Vector2i in stars:
		var top: Assistant.Placement = tops.get(key)
		var finish: int = int(stars[key])
		var made: bool = not _library.parts[MosaicArt.ROUND].never_made_in(finish)
		var right: bool = top != null and top.part == MosaicArt.ROUND \
			and (top.color == finish or not made) and p.relief[p.at(key.x, key.y)] == 1
		if right:
			placed += 1
		said.append("%s %s in %s" % [str(key), top.part if top else "nothing",
			_library.color(top.color).name if top else "-"])
	_check("%d of %d stars where the plan put them, in its finish, a plate up: %s"
		% [placed, stars.size(), "; ".join(said)], placed == stars.size())
	var found: int = 0
	for placement: Assistant.Placement in art.placements:
		if placement.part == MosaicArt.ROUND and MosaicArt.ACCENTS.has(placement.color):
			found += 1
	_check("and no others: the sky said no stars (%d accent rounds)" % found,
		found == stars.size())

	# The palette.
	var off := PackedStringArray()
	for placement: Assistant.Placement in art.placements:
		if placement.y >= MosaicArt.SURFACE and not plan.palette.has(placement.color) \
				and not MosaicArt.ACCENTS.has(placement.color):
			off.append("%s in %d" % [placement.part, placement.color])
	_check("every element on the panels in the plan's palette (%d not: %s)"
		% [off.size(), ", ".join(off.slice(0, 4))], off.is_empty())

	_check_made_in(art)
	_check_one_piece(art)
	var measured: String = ArtPlan.measured(art, _library)
	_check("measured as the critique asks: %s" % measured.replace("\n", " ").left(200),
		measured.contains("Frame: 48 x 32 studs") and measured.contains("Stars: 3 —")
		and measured.contains("Relief:") and measured.contains("the edge is flat"))
	# The disc is 0.72 of 48 studs across, 34.6, so 34 stud centres (71%);
	# and 2 x 0.16 x 48 = 15.4 down, 16 rows of 32 (50%). What is raised
	# spans that, whatever the sky is read as.
	_check("the frame is the raised subject's: 71% by 50%",
		measured.contains("The raised subject spans 71% of the width and 50% of the height"))

	# As the tool lays it: into the world, a parts list to match.
	_world.clear()
	_builder.lattice.clear()
	var ids: PackedInt64Array = MosaicArt.put_down(art, _world, _builder, _assistant)
	var stock: Inventory = Inventory.of(_world, _library, {})
	var listed: Dictionary = {}
	for lot: Inventory.Lot in stock.lots:
		listed[lot.part_id] = int(listed.get(lot.part_id, 0)) + lot.count
	var agree: bool = stock.pieces == art.placements.size() and ids.size() == stock.pieces
	var counts: Dictionary = art.counts()
	for part: String in counts:
		if int(listed.get(part, 0)) != int(counts[part]):
			agree = false
	_check("the parts list: %d pieces in %d lots, part for part what was laid"
		% [stock.pieces, stock.lots.size()], agree)

	# Without the plan, the engine's own reading of the same picture still
	# raises the core and finds stars of its own: the default is untouched.
	var auto: MosaicArt.Art = MosaicArt.make(_photo(), plan.options(), _library)
	var middle: int = auto.plan.relief[auto.plan.at(24, 16)]
	_check("the engine's own plan of it is still its own: the core %d up, the sky corner %d"
		% [middle, auto.plan.relief[0]], middle >= 1 and auto.plan.relief[0] == 0)

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ldr="):
			var store := ModelStore.new()
			store.world = _world
			store.library = _library
			store.builder = _builder
			store.keeps = false
			print("  wrote %s: %s" % [arg.substr(6), store.export_to(arg.substr(6), "Galaxy")])


## From a sentence alone: no picture, so the plan carries a drawing.
func _svg_case() -> void:
	print("\nno picture: the plan draws one in SVG")
	var drawn := {
		"svg": ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 32" width="64" height="32">'
			+ '<rect width="64" height="32" fill="#0a1a5c"/>'
			+ '<circle cx="16" cy="16" r="9" fill="#f2cd37"/>'
			+ '<rect x="40" y="6" width="16" height="20" fill="#c91a09"/></svg>'),
		"panels": [2, 1],
		"regions": [
			{"everything": true, "texture": "smooth", "relief": 0},
			{"ellipse": {"cx": 0.25, "cy": 0.5, "rx": 0.15, "ry": 0.15}, "relief": 2,
				"texture": "round"},
			{"rect": {"x": 0.625, "y": 0.1875, "w": 0.25, "h": 0.625}, "colour": 4,
				"relief": 1},
		],
	}
	var plan: ArtPlan = ArtPlan.parse(drawn, _library)
	_check("accepted: %s" % ("yes" if plan.ok() else plan.trouble()), plan.ok())
	var art: MosaicArt.Art = plan.lay(null, _library)
	if art == null:
		_check("and drawn: %s" % plan.trouble(), false)
		return
	print("  %s" % ArtPlan.said_of(art))
	var p: MosaicArt.Plan = art.plan
	_check("on 2 x 1 panels, 32 x 16 studs", art.panels == Vector2i(2, 1) and p.across == 32
		and p.down == 16)
	var tops: Dictionary = _tops(art)
	var sun: Assistant.Placement = tops.get(Vector2i(8, 8))
	_check("the drawn circle is there: %s in %s, %d up" % [sun.part if sun else "-",
		_library.color(sun.color).name if sun else "-", p.relief[p.at(8, 8)]],
		sun != null and sun.part == MosaicArt.ROUND and sun.color in [14, 191, 226]
		and p.relief[p.at(8, 8)] == 2)
	var block: Assistant.Placement = tops.get(Vector2i(24, 8))
	_check("the rectangle in the region's one colour: %s" % (
		_library.color(block.color).name if block else "-"),
		block != null and block.color == 4 and p.relief[p.at(24, 8)] == 1)
	var sky: Assistant.Placement = tops.get(Vector2i(1, 1))
	_check("the sky drawn blue, smooth, flat: %s in %s" % [sky.part if sky else "-",
		_library.color(sky.color).name if sky else "-"],
		sky != null and sky.part != MosaicArt.ROUND and sky.color in [1, 272, 33]
		and p.relief[p.at(1, 1)] == 0)
	_check_one_piece(art)


## The brightest stars as 2 x 2 round tiles: one element on four studs, level,
## a plate proud, nothing else on top of them, and still one piece.
func _big_star_case() -> void:
	print("\nthe brightest stars as 2 x 2 round tiles")
	var plan: ArtPlan = ArtPlan.parse({"svg": ('<svg xmlns="http://www.w3.org/2000/svg" '
			+ 'viewBox="0 0 32 16"><rect width="32" height="16" fill="#05050a"/></svg>'),
		"panels": [2, 1], "regions": [{"everything": true, "texture": "smooth", "relief": 0}],
		"points": [{"at": [0.25, 0.5], "size": 2}, {"at": [0.75, 0.5], "size": 2,
			"finish": "pearl-gold"}, {"at": [0.5, 0.25]}]}, _library)
	_check("accepted: %s" % ("yes" if plan.ok() else plan.trouble()), plan.ok())
	var art: MosaicArt.Art = plan.lay(null, _library)
	if art == null:
		return
	var big: Array[Assistant.Placement] = []
	for placement: Assistant.Placement in art.placements:
		if placement.part == MosaicArt.BIG_ROUND:
			big.append(placement)
	var tops: Dictionary = _tops(art)
	var whole: int = 0
	for star: Assistant.Placement in big:
		var one: bool = int(star.y) == MosaicArt.SURFACE + 1
		for dz: int in 2:
			for dx: int in 2:
				one = one and tops.get(Vector2i(int(star.x) + dx, int(star.z) + dz)) == star
		if one:
			whole += 1
	_check("two 2 x 2 round tiles, each the top of all four of its studs, a plate up: %s"
		% ", ".join(big.map(func(p: Assistant.Placement) -> String:
			return "(%d, %d) in %s" % [p.x, p.z, _library.color(p.color).name])),
		big.size() == 2 and whole == 2 and big[0].x == 7 and big[0].z == 7)
	_check("in finishes the part is made in, the gold one gold",
		big.size() == 2 and big[1].color == 297
		and not _library.parts[MosaicArt.BIG_ROUND].never_made_in(big[0].color))
	_check("the measure counts them by size: %s" % ArtPlan.measured(art, _library).get_slice(
		"- Stars: ", 1).get_slice("\n", 0), ArtPlan.measured(art, _library).contains("2 x 2"))
	_check_made_in(art)
	_check_one_piece(art)
	var bad: ArtPlan = ArtPlan.parse({"points": [{"at": [0.5, 0.5], "size": 3}]}, _library)
	_check("a star of size 3 is refused: \"%s\"" % (bad.errors[0] if not bad.ok() else ""),
		not bad.ok() and bad.trouble().contains("points[0].size is 3"))


## Plans that are not plans, each refused with the fault named.
func _refusals() -> void:
	print("\nmalformed plans are refused, each fault named")
	var cases: Array = [
		["a list for a plan", [1, 2], "must be a JSON object"],
		["a misspelt field", {"regions": [{"everything": true, "height": 3}]},
			"\"height\" is not something a region says"],
		["relief too high", {"regions": [{"everything": true, "relief": 9}]},
			"regions[0].relief is 9; it must be from 0 to 6"],
		["relief not whole", {"regions": [{"everything": true, "relief": 1.5}]},
			"regions[0].relief must be a whole number"],
		["two shapes", {"regions": [{"everything": true, "rect": {"x": 0, "y": 0, "w": 1, "h": 1}}]},
			"needs exactly one shape"],
		["no shape", {"regions": [{"relief": 1}]}, "needs exactly one shape"],
		["a polygon of two points", {"regions": [{"polygon": [[0, 0], [1, 1]]}]},
			"three or more"],
		["a point off the picture", {"points": [[1.4, 0.2]]}, "is off the picture"],
		["a finish that is not one", {"points": [{"at": [0.5, 0.5], "finish": "sparkly"}]},
			"\"sparkly\" is not a finish"],
		["a texture that is not one", {"regions": [{"everything": true, "texture": "bumpy"}]},
			"texture \"bumpy\" is not one of"],
		["too many panels", {"panels": [7, 2]}, "panels across is 7"],
		["a panel colour no panel is made in", {"base_colour": 47},
			"a 16 x 16 panel is not made in it"],
		["a colour no Art set uses", {"regions": [{"everything": true, "colour": 999}]},
			"is not a colour LEGO Art is laid in"],
		["an svg that is not one", {"svg": "a galaxy"}, "svg must be the whole drawing"],
		["a crop off the picture", {"crop": {"x": 0.5, "y": 0, "w": 0.8, "h": 1}},
			"must lie on the picture"],
		["a flag that is not one", {"regions": [{"everything": true, "stars": "yes"}]},
			"stars must be true or false"],
	]
	for case: Array in cases:
		var plan: ArtPlan = ArtPlan.parse(case[1], _library)
		var said: String = plan.trouble() if not plan.ok() else "(accepted)"
		_check("%s: \"%s\"" % [case[0], said.split("\n- ")[1] if said.contains("\n- ") else said],
			not plan.ok() and said.contains(str(case[2])))
	# What real Milky Ways asked for and were refused: Medium Lilac for the
	# violet between the arms, Dark Azure for the arms. The nearest left
	# were Magenta and Light Blue.
	var lilac: ArtPlan = ArtPlan.parse({"palette": [0, 272, 85, 321, 1],
		"regions": [{"everything": true, "colour": 85}, {"rect": {"x": 0, "y": 0, "w": 0.5,
			"h": 1}, "colour": 321}]}, _library)
	_check("Medium Lilac and Dark Azure, which Art sets are laid in, a plan may ask for: %s"
		% ("yes" if lilac.ok() else lilac.trouble().split("\n")[1].left(60)), lilac.ok())
	# Every fault at once, so it can all be fixed in one go.
	var many: ArtPlan = ArtPlan.parse({"panels": [0, 1], "depth": -1,
		"regions": [{"everything": true, "relief": 8}], "points": [[2, 2]]}, _library)
	_check("four faults, four lines: %d" % many.errors.size(), many.errors.size() == 4)
	# No picture and no drawing: nothing to lay, said so.
	var bare: ArtPlan = ArtPlan.parse({"panels": [2, 2]}, _library)
	var nothing: MosaicArt.Art = bare.lay(null, _library)
	_check("no picture and no svg: \"%s\"" % (bare.errors[0] if not bare.errors.is_empty() else ""),
		nothing == null and not bare.ok() and bare.trouble().contains("draw it and pass it as svg"))
	var broken: ArtPlan = ArtPlan.parse({"svg": "<svg><rect></svg>"}, _library)
	var unread: MosaicArt.Art = broken.lay(null, _library)
	_check("an svg that will not draw: \"%s\"" % (broken.errors[0] if not broken.errors.is_empty() else ""),
		unread == null and broken.trouble().contains("could not be drawn"))


## The tools, called as the design loop and a session over MCP call them.
func _tool_case() -> void:
	print("\nthe tools: make_art and look_at_picture, as a design calls them")
	var names: Dictionary = {}
	for tool: Variant in _assistant.tool_catalogue():
		names[str((tool as Dictionary).get("name", ""))] = tool
	var schema: Dictionary = (names.get("make_art", {}) as Dictionary).get("input_schema", {})
	_check("offered to the design and to MCP, with a schema: %s"
		% ", ".join(PackedStringArray((schema.get("properties", {}) as Dictionary).keys())),
		names.has("make_art") and names.has("look_at_picture")
		and (schema.get("properties", {}) as Dictionary).has("regions"))
	# Every key the schema offers is one the plan reads, and the other way.
	var offered: Array = (schema.get("properties", {}) as Dictionary).keys()
	var region_offered: Array = (((schema["properties"] as Dictionary)["regions"]
		as Dictionary)["items"]["properties"] as Dictionary).keys()
	offered.sort()
	region_offered.sort()
	var reads: Array = ArtPlan.PLAN_KEYS.duplicate()
	var region_reads: Array = ArtPlan.REGION_KEYS.duplicate()
	reads.sort()
	region_reads.sort()
	_check("the schema and the reader agree on every field", offered == reads
		and region_offered == region_reads)

	_assistant.art_source = null
	_assistant.forget_references()
	var nothing: Variant = await _assistant.use_tool("look_at_picture", {})
	_check("no picture chosen: \"%s\"" % str(nothing).left(60),
		nothing is String and str(nothing).contains("Draw one"))
	_assistant.art_source = _photo()
	var shown: Variant = await _assistant.use_tool("look_at_picture", {})
	_check("a picture chosen: it is shown, %s" % (str((shown as Array)[0]["text"]).left(50)
		if shown is Array else str(shown)), shown is Array
		and str((shown as Array)[1].get("type", "")) == "image")

	# A bad plan leaves the baseplate as it was.
	_world.clear()
	_builder.lattice.clear()
	var keep := Transform3D(Basis.IDENTITY, Vector3(10, 24, 10))
	var mine: int = _world.add_brick("3001", 4, keep)
	_builder.register(mine, "3001", keep)
	var refused: Variant = await _assistant.use_tool("make_art", {"regions": [{"relief": 2}]})
	_check("a malformed plan is refused through the tool, the baseplate untouched: \"%s\""
		% str(refused).split("\n")[0], refused is String
		and str(refused).contains("not laid") and _world.brick_count() == 1)

	var laid: Array = []
	_assistant.art_laid.connect(func(art: MosaicArt.Art) -> void: laid.append(art))
	var answer: Variant = await _assistant.use_tool("make_art", PLAN)
	var said: String = str((answer as Array)[0]["text"]) if answer is Array else str(answer)
	var art: MosaicArt.Art = laid[0] if not laid.is_empty() else null
	var old_brick: bool = false
	for brick: BrickWorld.Brick in _world.bricks():
		old_brick = old_brick or brick.part_id == "3001"
	_check("make_art lays the plan in place of what was there: %d bricks, said \"%s\""
		% [_world.brick_count(), said.left(90)], art != null
		and _world.brick_count() == art.placements.size() and not old_brick)
	var images: int = 0
	var words: String = ""
	if answer is Array:
		for block: Variant in answer as Array:
			if str((block as Dictionary).get("type", "")) == "image":
				images += 1
			else:
				words += str((block as Dictionary).get("text", "")) + "\n"
	_check("and answers with the picture face on, to judge it by", images == 1)
	_check("with what was measured on it and the designers' checklist: %s" % (
		words.substr(words.find("- Frame"), 120).replace("\n", " ")),
		words.contains("first look") and words.contains("- Frame: 48 x 32 studs")
		and words.contains("- Stars: 3 —") and words.contains("the edge is flat")
		and words.contains("largest patch of one colour") and words.contains("fill the frame")
		and words.contains("31212") and words.contains("Two revisions at most"))
	# Revised under the same name: a revision, then the last one.
	var again: Variant = await _assistant.use_tool("make_art", PLAN)
	var third: Variant = await _assistant.use_tool("make_art", PLAN)
	var said_again: String = str((again as Array)[0]["text"]) if again is Array else str(again)
	var said_last: String = JSON.stringify(third)
	_check("laid again it is revision 1, then revision 2 and told to stop: \"%s\""
		% said_again.left(20), said_again.begins_with("Laid (revision 1)")
		and said_last.contains("revision 2") and said_last.contains("That was the last revision"))
	var renamed: Dictionary = PLAN.duplicate(true)
	renamed["name"] = "Another picture"
	var fresh: Variant = await _assistant.use_tool("make_art", renamed)
	_check("and a picture of another name is a first look again", fresh is Array
		and str((fresh as Array)[0]["text"]).begins_with("Laid (first look)"))
	var tops: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == MosaicArt.ROUND and brick.color_code == 329:
			tops["glow"] = true
		if brick.part_id == MosaicArt.SLOPE:
			tops["slope"] = true
	_check("what stands is the plan's: the glowing star and the slopes up to the core",
		tops.has("glow") and tops.has("slope"))
	var stock: Inventory = Inventory.of(_world, _library, {})
	_check("its parts list has every piece: %d" % stock.pieces,
		art != null and stock.pieces == art.placements.size())
	# The panels as sub-assemblies, so the booklet builds a panel at a time.
	var units: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		units[brick.unit] = true
	_check("each panel its own sub-assembly: %s" % ", ".join(PackedStringArray(units.keys())),
		units.has("Panel 1#1") and units.has("Panel 6#1") and units.has("Frame#1"))


## The dialog's Design with Claude hands on the picture and what was said.
func _dialog_case() -> void:
	print("\nthe dialog")
	var dialog := MosaicDialog.new()
	dialog.library = _library
	root.add_child(dialog)
	await process_frame
	dialog.show_for(_photo())
	var asked: Array = []
	dialog.claude_wanted.connect(func(brief: String) -> void: asked.append(brief))
	dialog._brief.text = "raise the core, make the stars glow"
	dialog._ask.pressed.emit()
	_check("Design with Claude asks with what was typed: \"%s\""
		% (asked[0] if not asked.is_empty() else ""), asked == ["raise the core, make the stars glow"]
		and not dialog.visible)
	var brief: String = MosaicDialog.art_brief(str(asked[0]) if not asked.is_empty() else "",
		dialog.chosen_panels())
	_check("and the run is asked to look, then plan it with make_art on the panels chosen: \"%s\""
		% brief, brief.contains("make_art") and brief.contains("look_at_picture")
		and brief.contains("3 x 2 panels") and brief.ends_with("make the stars glow"))
	dialog.queue_free()


## What is on top of each stud: stud -> the highest placement covering it.
func _tops(art: MosaicArt.Art) -> Dictionary:
	var out: Dictionary = {}
	for placement: Assistant.Placement in art.placements:
		if placement.y < MosaicArt.SURFACE:
			continue
		var size: Vector2i = MosaicArt.footprint(placement.part, placement.rot)
		for dz: int in size.y:
			for dx: int in size.x:
				var key := Vector2i(int(placement.x) + dx, int(placement.z) + dz)
				var was: Assistant.Placement = out.get(key)
				if was == null or placement.y > was.y:
					out[key] = placement
	return out


func _check_made_in(art: MosaicArt.Art) -> void:
	var wrong := PackedStringArray()
	for placement: Assistant.Placement in art.placements:
		var info: PartLibrary.PartInfo = _library.parts.get(placement.part)
		if info == null or info.never_made_in(placement.color):
			wrong.append("%s in %d" % [placement.part, placement.color])
	_check("every element in a colour it is made in (%d not: %s)"
		% [wrong.size(), ", ".join(wrong.slice(0, 5))], wrong.is_empty())


func _check_one_piece(art: MosaicArt.Art) -> void:
	var report: Dictionary = _assistant._check(art.model(), true)
	_check("one buildable piece: %s, %d piece%s, nothing floating"
		% [str(report.get("summary", "")), int(report.get("pieces", 0)),
		"" if int(report.get("pieces", 0)) == 1 else "s"],
		bool(report.get("ok", false)) and int(report.get("pieces", 0)) == 1
		and (report.get("floating", []) as Array).is_empty())


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
