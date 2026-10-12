extends SceneTree
## A solid said as a shape comes out as a set builder would lay it: in one
## piece, passing the check, its surfaces sloped, curved and tiled rather
## than stepped in studs, and a mirror of itself where the shape is.
##
## The held-out car was told every check to use wedge plates, curved slopes
## and a hinged section and used none: its body was plates stacked square.
## These are the four held-out kinds of body — a car, a hull, a bird and a
## fuselage — each said as one shape.
##
##   godot --headless --path . --script src/dev/shapes_probe.gd [-- OUTDIR]
##
## With OUTDIR each is saved there as shape_<name>.ldr, to be measured and
## looked at.

var _failures: int = 0
var _library: PartLibrary

## The four bodies, each as a design would say it.
const BODIES: Dictionary = {
	"car": {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
		"solids": [
			{"extrude": {"along": "x", "from": 0, "width": 10, "round": 1.5,
				"profile": [[0, 5], [2, 7], [9, 8], [24, 8], [26, 7]],
				"under": [[0, 0], [26, 0]]}},
			{"loft": {"along": "x", "centre": 5, "color": 40, "sections": [
				{"at": 8, "width": 9, "height": 1, "bottom": 7.5, "round": 0.3},
				{"at": 12, "width": 8, "height": 7, "bottom": 7.5, "round": 0.4},
				{"at": 18, "width": 8, "height": 7, "bottom": 7.5, "round": 0.4},
				{"at": 23, "width": 9, "height": 1, "bottom": 7.5, "round": 0.3}]}}],
		"cuts": [
			{"revolve": {"axis": "z", "centre": [5, 1.5, -1], "profile": [[0, 2], [12, 2]]}},
			{"revolve": {"axis": "z", "centre": [20, 1.5, -1], "profile": [[0, 2], [12, 2]]}}]},
	"hull": {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 70,
		"bands": [{"from": 0, "to": 4, "color": 0}],
		"loft": {"along": "x", "sections": [
			{"at": 0, "width": 9, "height": 26, "bottom": 2, "round": 0.4, "keel": 0.4},
			{"at": 6, "width": 12, "height": 28, "bottom": 0, "round": 0.5, "keel": 0.6},
			{"at": 22, "width": 12, "height": 28, "bottom": 0, "round": 0.5, "keel": 0.6},
			{"at": 32, "width": 6, "height": 26, "bottom": 1, "round": 0.6, "keel": 0.7},
			{"at": 36, "width": 1, "height": 22, "bottom": 4, "round": 0.6, "keel": 0.7}]},
		"cuts": [{"box": {"from": [-1, 14, -1], "size": [40, 30, 16]}}]},
	"bird": {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 70,
		"solids": [
			{"ellipsoid": {"centre": [10, 10, 6], "radii": [7, 10, 5]}},
			{"ellipsoid": {"centre": [16, 18, 6], "radii": [3.5, 9, 3.5]}},
			{"loft": {"along": "x", "centre": 6, "sections": [
				{"at": 0, "width": 5, "height": 2, "bottom": 9, "round": 0.5},
				{"at": 5, "width": 6, "height": 5, "bottom": 8, "round": 0.6}]}}],
		"bands": [{"from": 0, "to": 9, "color": 19}]},
	"fuselage": {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15,
		"solids": [
			{"revolve": {"axis": "x", "centre": [0, 8.5, 4], "profile": [
				[0, 1], [3, 2.6], [7, 3.4], [26, 3.4], [32, 2.4], [36, 1.2]]}},
			{"ellipsoid": {"centre": [7, 15, 4], "radii": [4, 6, 2.5], "color": 40}}],
		"bands": [{"from": 8, "to": 9, "color": 1}]},
}


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var out_dir: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = _library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	var store := ModelStore.new()
	store.world = world
	store.library = _library
	store.builder = builder
	store.keeps = false
	await process_frame

	print("  the surface parts read off their meshes")
	for id: String in ["3040b", "4286", "60477", "11477", "15068", "61678", "50950",
			"54200", "85984"]:
		var shape: Dictionary = Shapes.part(_library, id)
		_check("%s falls %s, %s studs along it, %s tall" % [id, shape.get("turn", "?"),
			shape.get("d", "?"), shape.get("h", "?")], not shape.is_empty())
	for id: String in ["3665a", "4287a", "3660a"]:
		var shape: Dictionary = Shapes.part(_library, id, true)
		_check("%s, inverted, falls %s, %s studs along it" % [id, shape.get("turn", "?"),
			shape.get("d", "?")], not shape.is_empty())
	# 3040b's high stud is at its low z, so it falls towards +z unturned, as
	# the rock pattern has always laid it.
	_check("a 45 degree slope needs no turn to fall towards +z",
		int(Shapes.part(_library, "3040b").get("turn", -1)) == 0)

	for name: String in BODIES:
		print("")
		print("  a %s, said as one shape" % name)
		var body: Dictionary = BODIES[name]
		assistant._brief = "a %s" % name
		var model: Assistant.Model = assistant._read_model({"name": name, "patterns": [body]})
		var verdict: Dictionary = assistant._check(model, true)
		var parts: Dictionary = {}
		var curved: int = 0
		var sloped: int = 0
		var tiles: int = 0
		var wedges: int = 0
		for placement: Assistant.Placement in model.placements:
			parts[placement.part] = int(parts.get(placement.part, 0)) + 1
			var kinds: String = Style.kinds_of(placement.part)
			if kinds.contains("c"):
				curved += 1
			if placement.part in ["3040b", "3039", "4286", "3298", "60477", "30363", "54200",
					"85984", "3665a", "3660a", "4287a", "3747b", "13547", "11477", "15068",
					"50950", "24309", "61678", "93606", "24201", "32803"]:
				sloped += 1
			if placement.part in ["87079", "26603", "3068b", "2431", "63864", "3069b", "3070b"]:
				tiles += 1
			if Patterns.HANDED.has(placement.part) or placement.part in Patterns.WEDGES:
				wedges += 1
		var total: int = model.placements.size()
		var shown: Array = []
		for part: Variant in parts:
			shown.append("%s x%d" % [part, parts[part]])
		print("  parts: %s" % ", ".join(PackedStringArray(shown)))
		print("  %s" % str(Shapes.last))
		_check("laid without trouble: %s" % str(assistant._pattern_trouble),
			assistant._pattern_trouble.is_empty() and total > 20)
		_check("passes the check in one piece: %s, %d pieces" % [verdict["summary"],
			int(verdict["pieces"])], bool(verdict["ok"]) and int(verdict["pieces"]) == 1)
		if not bool(verdict["ok"]):
			print(str(verdict["feedback"]).left(1500))
		_check("its surface sloped and curved, not studs: %d curved, %d sloped, %d tiles, %d wedges of %d"
			% [curved, sloped, tiles, wedges, total], curved + sloped > total / 20 and tiles > 0)
		var advice: String = "\n".join(verdict.get("advice", []))
		var lopsided: bool = advice.contains("The model is a mirror of itself about")
		_check("a mirror of itself, part for part%s" % ("" if not lopsided else ": "
			+ advice.substr(advice.find("The model is a mirror"), 200)), not lopsided)
		if not out_dir.is_empty():
			assistant._apply(model)
			for _n: int in 3:
				await process_frame
			var path: String = "%s/shape_%s.ldr" % [out_dir, name]
			print("  saved %s: %s" % [path, store.export_to(path, "Model")])
			world.clear()
			builder.lattice.clear()

	print("")
	print("  a round or cut plan is laid in round parts and wedges, not a staircase")
	# Each of these came out a staircase of plain plates and bricks with no
	# wedge in it: the wedge's cut side had to lie outside every stud of the
	# plan, and on a round plan the studs the edge cuts are the plan's own.
	var round_parts: Array = Shapes.ROUND_PLATES + Shapes.ROUND_BRICKS
	var edge_parts: Array = Shapes.EDGE_PLATES + Shapes.EDGE_BRICKS + Patterns.WEDGES
	for one: Array in [
			["a cylinder of radius 5", {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0},
				"color": 84, "solids": [{"revolve": {"axis": "y", "centre": [6, 0, 6],
					"profile": [[0, 5], [6, 5]]}}]}, 8, 4],
			["a box with 45 degree corners", {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0},
				"color": 4, "box": {"from": [0, 0, 0], "size": [10, 6, 10], "chamfer": 3}}, 0, 8],
			# Its plan edges, with its curved sides left upright to show them.
			["an egg", {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 84,
				"sideways": false,
				"solids": [{"ellipsoid": {"centre": [6, 16, 6], "radii": [5, 16, 5]}},
					{"ellipsoid": {"centre": [6, 15, 8], "radii": [3.8, 14, 3.5], "color": 15}}]},
				8, 8]]:
		assistant._brief = str(one[0])
		var model: Assistant.Model = assistant._read_model({"patterns": [one[1]]})
		var verdict: Dictionary = assistant._check(model, true)
		var rounds: int = 0
		var cut: int = 0
		var curved: int = 0
		var sideways: int = 0
		for placement: Assistant.Placement in model.placements:
			if placement.part in round_parts:
				rounds += 1
			elif placement.part in edge_parts:
				cut += 1
			if Style.kinds_of(placement.part).contains("c"):
				curved += 1
			if placement.face != "up":
				sideways += 1
		var total: int = maxi(1, model.placements.size())
		var share: float = float(curved + sideways) / float(total)
		_check("%s: %d round parts, %d wedges and cut corners, %d%% curved or sideways, %s, %d pieces"
			% [one[0], rounds, cut, roundi(100.0 * share), verdict["summary"], int(verdict["pieces"])],
			rounds >= int(one[2]) and cut >= int(one[3]) and bool(verdict["ok"])
				and int(verdict["pieces"]) == 1)
		if str(one[0]) == "an egg":
			# Was 4%: two wedges in 409 parts, and the side panels of its flanks.
			_check("...the egg curved or sideways in a tenth of its parts or more",
				share >= 0.10)
	print("")
	print("  a side that curves up and down is laid on its side")
	# The held-out owl kept its shape body and still read as a staircase from
	# the front: an egg's flank laid in courses steps out a stud at a time.
	# Laid on its side, on studs out of the core, its outside is plates,
	# tiles and slopes. Upright (above, "sideways": false) it was 2% turned.
	for one: Array in [
			["an egg", {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 84,
				"solids": [{"ellipsoid": {"centre": [6, 16, 6], "radii": [5, 16, 5]}},
					{"ellipsoid": {"centre": [6, 15, 8], "radii": [3.8, 14, 3.5], "color": 15}}]}],
			["a hull", BODIES["hull"]],
			["a bird", BODIES["bird"]]]:
		assistant._brief = str(one[0])
		var model: Assistant.Model = assistant._read_model({"patterns": [one[1]]})
		var verdict: Dictionary = assistant._check(model, true)
		var turned: int = 0
		var faces: int = 0
		var anchors: int = 0
		for placement: Assistant.Placement in model.placements:
			if placement.face != "up":
				turned += 1
				if Style.kinds_of(placement.part).contains("c") or placement.part in [
						"3070b", "3069b", "3068b", "2431", "63864", "26603", "87079", "54200",
						"85984", "11477", "15068", "50950", "24309", "61678", "93606"]:
					faces += 1
			elif placement.part == "87087":
				anchors += 1
		var total: int = maxi(1, model.placements.size())
		_check("%s: %d of %d parts turned out (%d%%), %d of them tiles and slopes, on %d side studs: %s, %d pieces"
			% [one[0], turned, total, roundi(100.0 * turned / total), faces, anchors,
			verdict["summary"], int(verdict["pieces"])],
			turned * 10 >= total and faces > 0 and anchors > 0 and bool(verdict["ok"])
				and int(verdict["pieces"]) == 1)
	# A cylinder curves round, not up: its side is the round parts', and a
	# ramp's low end is its slopes'.
	var tower: Array = _laid({"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 84,
		"solids": [{"revolve": {"axis": "y", "centre": [6, 0, 6], "profile": [[0, 5], [12, 5]]}}]})
	var turned_tower: int = 0
	for one: Dictionary in tower:
		if str(one.get("face", "up")) != "up":
			turned_tower += 1
	_check("...and a cylinder's side is not turned: %d" % turned_tower, turned_tower == 0)

	print("")
	print("  a round section is laid in round parts, as the round pattern lays one")
	# A cylinder of radius 4, a dome and a stepped column came out as plates
	# tiled stud by stud with corner rounds at the rim: a staircase in plan.
	# Real sets lay a round of 8 in four corner rounds tied by a round plate,
	# of 4 in round bricks, and crown a dome with a dish.
	for one: Array in [
			["a cylinder of radius 4", {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0},
				"color": 84, "solids": [{"revolve": {"axis": "y", "centre": [5, 0, 5],
					"profile": [[0, 4], [9, 4]]}}]}, ["48092", "74611"]],
			["a dome", {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
				"solids": [{"dome": {"centre": [5, 0, 5], "radii": [4, 12, 4]}}]},
				["74611", "11213", "44375b"]],
			["a column stepping in", {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0},
				"color": 15, "solids": [{"revolve": {"axis": "y", "centre": [4, 0, 4], "profile": [
					[0, 3], [6, 3], [7, 2], [16, 2], [17, 1], [22, 1]]}}]}, ["5152", "3941"]]]:
		assistant._brief = str(one[0])
		var model: Assistant.Model = assistant._read_model({"patterns": [one[1]]})
		var verdict: Dictionary = assistant._check(model, true)
		var curved: int = 0
		var named: Dictionary = {}
		for placement: Assistant.Placement in model.placements:
			if Style.kinds_of(placement.part).contains("c"):
				curved += 1
			named[placement.part] = true
		var wanted: Array = one[2]
		var has_all: bool = true
		for part: String in wanted:
			has_all = has_all and named.has(part)
		_check("%s: %d of %d parts round, %s among them: %s, %d pieces" % [one[0], curved,
			model.placements.size(), ", ".join(PackedStringArray(wanted)), verdict["summary"],
			int(verdict["pieces"])], curved == model.placements.size() and has_all
			and bool(verdict["ok"]) and int(verdict["pieces"]) == 1)
	# A square post is not a round one: its section fills its box.
	var post: Array = _laid({"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15,
		"box": {"from": [0, 0, 0], "size": [2, 9, 2]}})
	_check("...and a square post is laid square: %s" % _counted(post),
		_count(post, ["3941", "4032a", "87081", "60474"]) == 0)

	# A straight edge a stud's middle crosses is the studs' own: a ramp's
	# falls each cross a stud half way, and wedges laid there sawed teeth.
	var straight: Array = _laid({"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0},
		"color": 15, "surface": "straight", "extrude": {"along": "x", "width": 4,
			"profile": [[0, 2], [12, 14]]}})
	_check("a ramp's straight edges take no wedge: %d" % _count(straight, edge_parts + round_parts),
		_count(straight, edge_parts + round_parts) == 0)

	print("")
	print("  what each surface is laid in")
	# A ramp falling a plate a stud: an 18 degree slope or a curved 4 x 1 fits
	# that fall; a chamfer falling three plates a stud, a 45.
	var ramp: Array = _laid({"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15,
		"surface": "straight", "extrude": {"along": "x", "width": 4,
			"profile": [[0, 2], [12, 14]]}})
	_check("a ramp falling a plate a stud takes 18 degree slopes: %s" % _counted(ramp),
		_count(ramp, ["60477", "30363"]) > 0)
	var curved: Array = _laid({"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15,
		"surface": "curved", "extrude": {"along": "x", "width": 4,
			"profile": [[0, 2], [12, 14]]}})
	_check("...and said curved, curved slopes: %s" % _counted(curved),
		_count(curved, ["61678", "93606", "50950", "24309", "11477", "15068"]) > 0)
	var tiled: Array = _laid({"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15,
		"box": {"from": [0, 0, 0], "size": [6, 6, 4]}})
	var studded: Array = _laid({"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15,
		"top": "studs", "box": {"from": [0, 0, 0], "size": [6, 6, 4]}})
	_check("a box's top is tiled, %d tiles; with \"top\": \"studs\", %d"
		% [_count(tiled, ["87079", "3068b", "26603", "2431", "63864", "3069b", "3070b"]),
		_count(studded, ["87079", "3068b", "26603", "2431", "63864", "3069b", "3070b"])],
		_count(tiled, ["87079", "3068b", "26603", "2431", "63864", "3069b", "3070b"]) > 0
			and _count(studded, ["87079", "3068b", "26603", "2431", "63864", "3069b", "3070b"]) == 0)
	var banded: Array = _laid({"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15,
		"bands": [{"from": 0, "to": 3, "color": 0}], "box": {"from": [0, 0, 0], "size": [4, 9, 4]}})
	var low_black: bool = true
	var high_white: bool = true
	for one: Dictionary in banded:
		if float(one["y"]) < 3.0 and int(one["color"]) != 0:
			low_black = false
		if float(one["y"]) >= 3.0 and int(one["color"]) != 15:
			high_white = false
	_check("a band colours it by height: black under plate 3, white over it",
		low_black and high_white)
	# A straight side: bricks with studs on it every other course, each with a
	# tile two studs tall laid flat on them; "panels": false for none.
	var box: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15,
		"box": {"from": [0, 0, 0], "size": [8, 12, 4]}}
	var smooth: Assistant.Model = assistant._read_model({"patterns": [box]})
	var side_bricks: int = 0
	var side_tiles: int = 0
	for placement: Assistant.Placement in smooth.placements:
		if placement.part in ["30414", "11211", "87087"]:
			side_bricks += 1
		elif placement.face != "up":
			side_tiles += 1
	var verdict: Dictionary = assistant._check(smooth)
	_check("a box's straight sides are tiles on side-stud bricks: %d bricks, %d tiles, %s"
		% [side_bricks, side_tiles, verdict["summary"]], side_bricks >= 8
			and side_tiles == side_bricks and bool(verdict["ok"]) and int(verdict["pieces"]) == 1)
	var plain: Dictionary = box.duplicate(true)
	plain["panels"] = false
	var bare: int = 0
	for placement: Assistant.Placement in assistant._read_model({"patterns": [plain]}).placements:
		if placement.part in ["30414", "11211", "87087"] or placement.face != "up":
			bare += 1
	_check("...and none with \"panels\": false (%d)" % bare, bare == 0)
	var trouble: Array = []
	Shapes.lay({"pattern": "shape", "loft": {"along": "x", "sections": []}}, trouble, _library)
	_check("a loft without sections is refused, saying what it wants: %s" % str(trouble),
		str(trouble).contains("sections"))

	print("")
	if _failures == 0:
		print("a solid can be said as a shape")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _laid(shape: Dictionary) -> Array:
	var trouble: Array = []
	var made: Array = Shapes.lay(shape, trouble, _library)
	if not trouble.is_empty():
		print("  trouble: %s" % str(trouble))
	return made


func _count(made: Array, parts: Array) -> int:
	var n: int = 0
	for one: Dictionary in made:
		if str(one["part"]) in parts:
			n += 1
	return n


func _counted(made: Array) -> String:
	var counts: Dictionary = {}
	for one: Dictionary in made:
		counts[one["part"]] = int(counts.get(one["part"], 0)) + 1
	var said: Array = []
	for part: Variant in counts:
		said.append("%s x%d" % [part, counts[part]])
	return ", ".join(PackedStringArray(said))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
