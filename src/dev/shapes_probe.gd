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
	for id: String in ["3665a", "4287c", "3660b"]:
		var shape: Dictionary = Shapes.part(_library, id, true)
		_check("%s, inverted, falls %s, %s studs along it" % [id, shape.get("turn", "?"),
			shape.get("d", "?")], not shape.is_empty())
	# 3040b's high stud is at its low z, so it falls towards +z unturned, as
	# the rock pattern has always laid it.
	_check("a 45 degree slope needs no turn to fall towards +z",
		int(Shapes.part(_library, "3040b").get("turn", -1)) == 0)

	print("")
	print("  a car on the shape's own wheels")
	# Every bench car that tried a shaped body gave it up: raised over nothing
	# it floated, and with wheels added its slopes ran into the tyres' boxes.
	var on_wheels: Dictionary = (BODIES["car"] as Dictionary).duplicate(true)
	on_wheels["solids"] = [
		{"extrude": {"along": "x", "from": 0, "width": 8, "round": 1.5,
			"profile": [[0, 7], [3, 9], [8, 10], [20, 10], [21, 9]], "under": [[0, 2], [21, 2]]}},
		{"loft": {"along": "x", "centre": 4, "color": 40, "sections": [
			{"at": 7, "width": 7, "height": 1, "bottom": 9.5, "round": 0.3},
			{"at": 10, "width": 6, "height": 6, "bottom": 9.5, "round": 0.4},
			{"at": 15, "width": 6, "height": 6, "bottom": 9.5, "round": 0.4},
			{"at": 19, "width": 7, "height": 1, "bottom": 9.5, "round": 0.3}]}}]
	on_wheels.erase("cuts")
	on_wheels["wheels"] = [4, 16]
	var car: Assistant.Model = assistant._read_model({"name": "car", "patterns": [on_wheels]})
	await assistant._ensure_parts(car)
	var rolling: Dictionary = assistant._check(car, true)
	var rims: int = 0
	for placement: Assistant.Placement in car.placements:
		rims += 1 if placement.part == Shapes.WHEEL else 0
	_check("laid with its wheels: %s, %d wheels" % [str(assistant._pattern_trouble), rims],
		assistant._pattern_trouble.is_empty() and rims == 4)
	_check("one piece on its wheels, nothing floating or overlapping: %s" % rolling["summary"],
		bool(rolling["ok"]) and int(rolling.get("pieces", 0)) == 1)
	var narrow: Dictionary = on_wheels.duplicate(true)
	(((narrow["solids"] as Array)[0] as Dictionary)["extrude"] as Dictionary)["width"] = 11
	assistant._read_model({"name": "car", "patterns": [narrow]})
	_check("a body 11 studs across is told wheels want 6, 8, 10 or 12",
		str(assistant._pattern_trouble).contains("6, 8, 10 or 12"))
	var high: Dictionary = on_wheels.duplicate(true)
	(((high["solids"] as Array)[0] as Dictionary)["extrude"] as Dictionary)["under"] = [[0, 7],
		[21, 7]]
	assistant._read_model({"name": "car", "patterns": [high]})
	_check("a body raised off its wheels' bricks is told to come down to them",
		str(assistant._pattern_trouble).contains("does not come down"))

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
					"85984", "3665a", "3660b", "4287c", "3747b", "13547", "11477", "15068",
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

	await _said_bodies(assistant, world, builder, store, out_dir)

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
		var lanes: int = 0
		var curved: int = 0
		for placement: Assistant.Placement in model.placements:
			if placement.face != "up":
				turned += 1
				if Style.kinds_of(placement.part).contains("c") or placement.part in [
						"3070b", "3069b", "3068b", "2431", "63864", "26603", "87079", "54200",
						"85984", "11477", "15068", "50950", "24309", "61678", "93606"]:
					faces += 1
				if placement.part in ["11477", "15068", "50950", "24309", "61678", "93606"]:
					curved += 1
			elif placement.part in SIDE_STUDS:
				anchors += 1
				lanes += int(SIDE_STUDS[placement.part])
		var total: int = maxi(1, model.placements.size())
		_check("%s: %d of %d parts turned out (%d%%), %d of them tiles and slopes, on %d side studs: %s, %d pieces"
			% [one[0], turned, total, roundi(100.0 * turned / total), faces, anchors,
			verdict["summary"], int(verdict["pieces"])],
			turned * 10 >= total and faces > 0 and anchors > 0 and bool(verdict["ok"])
				and int(verdict["pieces"]) == 1)
		# Where the flank curves across, curved slopes, not a cheese slope a
		# stud; and the side studs in runs, 1 x 2s and 1 x 4s, not a 1 x 1 a
		# lane. The egg was 2 curved of 143 turned out, on 84 1 x 1s. A hull's
		# side falls straight down to its keel, and keeps its tiles.
		_check("...%d curved slopes on its flank, %d side-stud bricks holding %d lanes"
			% [curved, anchors, lanes], (curved * 20 >= turned or one[0] == "a hull")
				and anchors * 4 < lanes * 3)
		# A side and its mirror turned out together: judged one at a time, the
		# hull kept one flank and laid the other upright. (Its two shells are
		# not yet laid alike: 29 parts on one side, 14 on the other.)
		var by_face: Dictionary = {}
		for placement: Assistant.Placement in model.placements:
			by_face[placement.face] = int(by_face.get(placement.face, 0)) + 1
		var axis: String = str(Shapes.last.get("mirror", ""))
		var pair: Array = ["+z", "-z"] if axis == "z" else (["+x", "-x"] if axis == "x" else [])
		_check("...both its mirrored sides turned out: %s; %s" % [str(by_face),
			str(Shapes.last.get("shells_kept", []))], pair.is_empty()
			or int(by_face.get(pair[0], 0)) > 0 and int(by_face.get(pair[1], 0)) > 0)
	# A minifigure-scale car, 8 wide and 3.5 plates tall over its arches, as
	# the held-out run said it: the shells took two studs off each side and
	# kept 5 of their 74 parts, and the body "eroded into a narrow strip" four
	# studs wide. A shell that holds less than most of what it takes is
	# given back, and that side laid upright.
	var thin: Array = _laid({"pattern": "shape", "color": 4, "at": {"x": 0, "y": 0, "z": 0},
		"solids": [{"loft": {"along": "x", "centre": 4, "sections": [
			{"at": 0, "width": 7, "height": 3, "bottom": 4, "round": 0.3},
			{"at": 1, "width": 8, "height": 3.5, "bottom": 4, "round": 0.3},
			{"at": 5, "width": 8, "height": 3.5, "bottom": 4, "round": 0.3},
			{"at": 9, "width": 8, "height": 3, "bottom": 4, "round": 0.3},
			{"at": 15, "width": 8, "height": 2, "bottom": 4, "round": 0.3},
			{"at": 17.5, "width": 7.5, "height": 1.5, "bottom": 4, "round": 0.3},
			{"at": 18, "width": 6, "height": 1, "bottom": 4, "round": 0.3}]}},
			{"loft": {"along": "x", "centre": 4, "color": 40, "sections": [
				{"at": 3.5, "width": 6, "height": 0, "bottom": 7.5, "round": 0.8},
				{"at": 6, "width": 6, "height": 3, "bottom": 7, "round": 0.8},
				{"at": 9, "width": 6, "height": 3, "bottom": 7, "round": 0.8},
				{"at": 13, "width": 6, "height": 0, "bottom": 7, "round": 0.8}]}}],
		"cuts": [
			{"revolve": {"axis": "z", "centre": [4, 3, -0.5], "profile": [[0, 1.3], [2.5, 1.3]]}},
			{"revolve": {"axis": "z", "centre": [4, 3, 6], "profile": [[0, 1.3], [2.5, 1.3]]}},
			{"revolve": {"axis": "z", "centre": [14, 3, -0.5], "profile": [[0, 1.3], [2.5, 1.3]]}},
			{"revolve": {"axis": "z", "centre": [14, 3, 6], "profile": [[0, 1.3], [2.5, 1.3]]}}]})
	var wide := Vector2(INF, -INF)
	for one: Dictionary in thin:
		if float(one["x"]) >= 6.0 and float(one["x"]) < 12.0 and str(one.get("face", "up")) == "up":
			wide = Vector2(minf(wide.x, float(one["z"])), maxf(wide.y, float(one["z"])))
	_check("a minifigure-scale car's body keeps its flanks: %d parts, across its middle from z %s to %s; %s"
		% [thin.size(), wide.x, wide.y, str(Shapes.last.get("shells_kept", []))],
		thin.size() >= 60 and wide.x <= 0.0 and wide.y >= 7.0)
	# A curved slope is hollow under its high end, so a stud there reaches into
	# nothing: on its side it is held by its low rows or by nothing. The
	# held-out owl's body on its post, as the run said it, was refused four
	# times for 11477s held by nothing or resting on a cheese slope.
	var grips: Array = []
	for id: String in ["11477", "15068", "50950", "24309", "61678", "54200", "3040b"]:
		grips.append("%s %s" % [id, str(Shapes.part(_library, id).get("grips", []))])
	_check("a stud grips a curved slope under its low rows, a straight one under all: %s"
		% ", ".join(PackedStringArray(grips)), Shapes.part(_library, "11477").get("grips") == [1]
		and Shapes.part(_library, "24309").get("grips") == [1, 2]
		and Shapes.part(_library, "3040b").get("grips") == [0, 1])
	assistant._brief = "a barn owl"
	var perched: Assistant.Model = assistant._read_model({"patterns": [OWL_POST, OWL_BODY]})
	var perched_verdict: Dictionary = assistant._check(perched, true)
	var curved_out: int = 0
	var held_by_nothing: int = 0
	for index: int in perched.placements.size():
		var placement: Assistant.Placement = perched.placements[index]
		if placement.face != "up" and placement.part in ["11477", "15068", "50950", "24309"]:
			curved_out += 1
			if (perched_verdict.get("floating", []) as Array).has(index):
				held_by_nothing += 1
	_check("an owl's body on its post, as the held-out run said it: %s, %d pieces, %d curved slopes turned out, %d held by nothing"
		% [perched_verdict["summary"], int(perched_verdict["pieces"]), curved_out, held_by_nothing],
		bool(perched_verdict["ok"]) and int(perched_verdict["pieces"]) == 1 and curved_out >= 12
			and not str(perched_verdict["feedback"]).contains("held by nothing"))
	# The held-out car's body, 5 plates over arches, on its axles: its nose past
	# the front arch was plates beside the middle's brick course, joined to it
	# by nothing, and came away in 14 parts. The run threw the body away.
	assistant._brief = "a sports car"
	var nosed: Assistant.Model = assistant._read_model({"bricks": CAR_AXLES, "patterns": [CAR_BODY]})
	var nosed_verdict: Dictionary = assistant._check(nosed, true)
	_check("a car's body over its arches keeps its nose: %s, %d pieces; the shape %d piece(s)"
		% [nosed_verdict["summary"], int(nosed_verdict["pieces"]), int(Shapes.last.get("pieces", 0))],
		bool(nosed_verdict["ok"]) and int(nosed_verdict["pieces"]) == 1
			and int(Shapes.last.get("pieces", 0)) == 1 and nosed.placements.size() > 100)
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
					"profile": [[0, 4], [9, 4]]}}]}, ["48092", "74611", "27507", "79393", "27925", "14769"]],
			["a dome", {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
				"solids": [{"dome": {"centre": [5, 0, 5], "radii": [4, 12, 4]}}]},
				["74611", "11213", "15068", "60474"]],
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
	# A dome's step was a ledge of bare studs a stud wide, ring over ring: a
	# wedding cake from the side. Eased, the round below carries curved slopes
	# falling out round its rim and the round above bridges in over them.
	var dome: Array = _laid({"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
		"solids": [{"dome": {"centre": [5, 0, 5], "radii": [4, 12, 4]}}]})
	var eased: Array = (Shapes.last.get("round_runs", []) as Array).filter(
		func(said: String) -> bool: return said.ends_with("eased"))
	# Both its steps: the 8 to the 6, and the 6 to the 4, whose rim is the 2 x 2
	# curved slopes of a round of 6.
	_check("a dome's step is eased in curved slopes round the rim below: %s; %s"
		% [", ".join(PackedStringArray(eased)), _counted(dome)],
		eased.size() == 2 and _count(dome, ["15068"]) == 12 and _count(dome, ["25269"]) == 8)
	# A squat dome's rings are a plate or two each, and were a stack of round
	# plates under a dish, studs bare on every ring: a tin with a lid. The
	# round of 6 a plate tall over the 8 is the 8's eased rim, all of it.
	var squat: Array = _laid({"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
		"solids": [{"dome": {"centre": [5, 0, 5], "radii": [4, 7, 4]}}]})
	var squat_said: Array = Shapes.last.get("round_runs", [])
	_check("...and a squat dome's short rings too: %s; %s" % [", ".join(PackedStringArray(squat_said)),
		_counted(squat)], _count(squat, ["15068"]) == 8 and _count(squat, ["11213", "3961"]) == 0)
	# An oval is not a round: an owl's head, 13 studs by 11, passes through a
	# disc of 8 one plate thick at its crown, and a round plate laid there
	# with a dish on it read as a hat. A disc a plate thick is a round only
	# on or under another round.
	var head: Array = _laid({"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "solids": [
		{"ellipsoid": {"centre": [12, 13, 10], "radii": [6.6, 13, 5.5]}, "color": 19},
		{"ellipsoid": {"centre": [12, 12, 13.6], "radii": [5.4, 10.5, 2.2]}, "color": 15}]})
	_check("an oval head is not crowned with a round plate and a dish: %s" % str(Shapes.last.get(
		"round_runs", [])), _count(head, ["3961", "44375b", "3960", "74611", "11213"]) == 0
		and int(Shapes.last.get("pieces", 0)) == 1)
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


## The held-out owl's stone post and body, as its run (owl_d3) said them.
const OWL_POST: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "top": "smooth",
	"solids": [{"box": {"from": [6, 0, 5], "size": [8, 20, 6], "edge": 1, "round": 1}, "color": 72}]}
const OWL_BODY: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "solids": [
	{"ellipsoid": {"centre": [10, 35, 7.5], "radii": [5, 15, 4.5]}, "color": 15},
	{"loft": {"along": "z", "centre": 10, "sections": [
		{"at": 1, "width": 5, "height": 3, "bottom": 20, "round": 0.6},
		{"at": 4, "width": 7, "height": 8, "bottom": 23, "round": 0.8},
		{"at": 6, "width": 6, "height": 6, "bottom": 30, "round": 0.8}]}, "color": 84},
	{"ellipsoid": {"centre": [5.8, 35, 6.5], "radii": [1.6, 14, 4.2]}, "color": 84},
	{"ellipsoid": {"centre": [14.2, 35, 6.5], "radii": [1.6, 14, 4.2]}, "color": 84},
	{"ellipsoid": {"centre": [10, 54, 7.5], "radii": [4.5, 11, 4]}, "color": 84},
	{"ellipsoid": {"centre": [10, 53, 9.5], "radii": [3.8, 9, 2.2]}, "color": 15}]}

## The held-out car's axles and wheels and its body, as its run (car_d3) said them,
## but for its wheels: turned so each cross hole faces in, on an axle 6 that ends
## in them. As the run had them, an axle 8 ran through both wheels' clip rings,
## 2 LDU into each by the parts' real shapes (Shapes.WHEEL).
const CAR_AXLES: Array = [
	{"part": "3700", "color": 0, "x": 3, "y": 2, "z": 2, "rot": 0},
	{"part": "3700", "color": 0, "x": 3, "y": 2, "z": 5, "rot": 0},
	{"part": "3706", "color": 0, "x": 3.7, "y": 3, "z": 1, "rot": 1},
	{"part": "18976c01", "color": 71, "x": 2.5, "y": 0, "z": 0, "rot": 2},
	{"part": "18976c01", "color": 71, "x": 2.5, "y": 0, "z": 6.5, "rot": 0},
	{"part": "3700", "color": 0, "x": 15, "y": 2, "z": 2, "rot": 0},
	{"part": "3700", "color": 0, "x": 15, "y": 2, "z": 5, "rot": 0},
	{"part": "3706", "color": 0, "x": 15.7, "y": 3, "z": 1, "rot": 1},
	{"part": "18976c01", "color": 71, "x": 14.5, "y": 0, "z": 0, "rot": 2},
	{"part": "18976c01", "color": 71, "x": 14.5, "y": 0, "z": 6.5, "rot": 0}]
const CAR_BODY: Dictionary = {"pattern": "shape", "color": 321, "solids": [
	{"extrude": {"along": "x", "from": 0, "width": 8, "round": 0.5,
		"profile": [[0, 7], [1, 9], [6, 10], [18, 10.5], [20, 10]], "under": [[0, 5], [20, 5]]},
		"color": 321},
	{"loft": {"along": "x", "centre": 4, "sections": [
		{"at": 7, "width": 6, "height": 0.5, "bottom": 10, "round": 0.3},
		{"at": 10.5, "width": 6, "height": 4, "bottom": 10, "round": 0.4},
		{"at": 13.5, "width": 5.5, "height": 4, "bottom": 10, "round": 0.4},
		{"at": 18, "width": 6, "height": 0.5, "bottom": 10, "round": 0.3}]}, "color": 0}],
	"cuts": [
		{"revolve": {"axis": "z", "centre": [4, 3.75, 0], "profile": [[0, 1.9], [2, 1.9]]}},
		{"revolve": {"axis": "z", "centre": [4, 3.75, 6], "profile": [[0, 1.9], [2, 1.9]]}},
		{"revolve": {"axis": "z", "centre": [16, 3.75, 0], "profile": [[0, 1.9], [2, 1.9]]}},
		{"revolve": {"axis": "z", "centre": [16, 3.75, 6], "profile": [[0, 1.9], [2, 1.9]]}}]}

## Bodies as design sessions said them, each of which the shape laid in
## pieces or floating, and whose sessions then built the body again by hand,
## square, without its curves: each must now be one piece, stand, and taper
## at its ends into slopes, curved slopes and wedges that are held. And where
## a shape cannot be held, the shape must say so, and how to hold it.
func _said_bodies(assistant: Assistant, world: BrickWorld, builder: Builder,
		store: ModelStore, out_dir: String) -> void:
	print("")
	print("  bodies as sessions said them: one piece, standing, ends held")
	var shaped: Dictionary = {}
	for entry: Array in Shapes.Plan.SLOPES + Shapes.Plan.INVERTED:
		shaped[str(entry[3])] = true
		shaped[str(entry[4])] = true
	for part: String in Shapes.EDGE_PLATES + Shapes.EDGE_BRICKS + Shapes.ROUND_PLATES \
			+ Shapes.ROUND_BRICKS + Patterns.WEDGES:
		shaped[part] = true
	for part: Variant in Patterns.HANDED:
		shaped[str(part)] = true
	var stability := Stability.new()
	stability.library = _library
	stability.lattice = builder.lattice
	# [what, the design, the axis its ends are along ("" for none)]
	for one: Array in [
			["the steps round's car, its cockpit cut", {"patterns": [CAR_STEPS_CUT]}, "x"],
			["the steps round's car, its fastback, studs on top", {"patterns": [CAR_STEPS_FASTBACK]}, "x"],
			["a curved car, its nose four plates up", {"patterns": [CAR_CURVED_NOSE]}, "x"],
			["a curved car, its tail past the back axle", {"patterns": [CAR_CURVED_TAIL]}, "x"],
			["the sides round's car, its back axle at 15.5", {"patterns": [CAR_SIDES_AXLE]}, "x"],
			["a locomotive's boiler, its smokebox black", {"patterns": [BOILER]}, ""],
			["a ship's hull, its bow planked black", {"patterns": [HULL_BOW]}, "x"],
			["a starfighter's nose on its stands", {"bricks": FIGHTER_NOSE_BRICKS,
				"patterns": [FIGHTER_NOSE]}, "+z"],
			["a dog on four legs", {"patterns": [DOG]}, ""]]:
		var given: Dictionary = (one[1] as Dictionary).duplicate(true)
		given["floor"] = "none"
		assistant._brief = str(one[0])
		var model: Assistant.Model = assistant._read_model(given)
		await assistant._ensure_parts(model)
		var verdict: Dictionary = assistant._check(model, true)
		var floating: Array = verdict.get("floating", [])
		var laid_pieces: int = int(Shapes.last.get("pieces", 0))
		# Its ends: within two studs of each, the shaped parts there, none of
		# them floating.
		var ends: String = ""
		var ends_ok: bool = true
		if not str(one[2]).is_empty():
			# "x" both its ends along x; "+z" its end towards +z alone.
			var along: String = str(one[2]).right(1)
			var both: bool = not str(one[2]).begins_with("+")
			var low: float = INF
			var high: float = -INF
			var written: int = (given.get("bricks", []) as Array).size()
			for index: int in range(written, model.placements.size()):
				var p: Assistant.Placement = model.placements[index]
				var a: float = p.x if along == "x" else p.z
				low = minf(low, a)
				high = maxf(high, a)
			var at_low: int = 0
			var at_high: int = 0
			for index: int in range(written, model.placements.size()):
				var p: Assistant.Placement = model.placements[index]
				if not shaped.has(p.part) or floating.has(index):
					continue
				var a: float = p.x if along == "x" else p.z
				at_low += 1 if a <= low + 2.0 else 0
				at_high += 1 if a >= high - 3.0 else 0
			ends = ", %d shaped parts at one end and %d at the other" % [at_low, at_high]
			ends_ok = at_high > 0 and (at_low > 0 or not both)
		assistant._apply(model)
		for _n: int in 3:
			await process_frame
		var stands: Stability.Report = stability.check(world)
		_check("%s: %s, %d piece%s, %d floating, the shape laid in %d%s; %s" % [one[0],
			verdict["summary"], int(verdict["pieces"]), "" if int(verdict["pieces"]) == 1 else "s",
			floating.size(), laid_pieces, ends, stands.summary()],
			bool(verdict["ok"]) and int(verdict["pieces"]) == 1 and floating.is_empty()
				and laid_pieces == 1 and ends_ok and stands.is_stable())
		if not out_dir.is_empty():
			var path: String = "%s/said_%s.ldr" % [out_dir, str(one[0]).split(",")[0].replace(" ", "_")
				.replace("'", "")]
			print("  saved %s: %s" % [path, store.export_to(path, "Model")])
		world.clear()
		builder.lattice.clear()
	# What cannot be held is said, with the fix, by the shape itself.
	for one: Array in [
			["an owl's body said at y 55 with nothing under it", {"patterns": [OWL_RAISED]},
				["underside is at y=55", "floats", "Build what it stands on"]],
			["two engine pods said as one shape, six studs apart", {"patterns": [ENGINES]},
				["does not touch the body", "x 23-26", "a shape of its own"]],
			["a wheel asked at x 15.5", {"patterns": [CAR_SIDES_AXLE]}, ["laid at x=16"]]]:
		var given: Dictionary = (one[1] as Dictionary).duplicate(true)
		given["floor"] = "none"
		var model: Assistant.Model = assistant._read_model(given)
		var advice: String = "\n".join(PackedStringArray(assistant._check(model, true).get("advice", [])))
		var said: bool = true
		for words: String in one[2]:
			said = said and advice.contains(words)
		var line: String = ""
		for piece: String in advice.split("\n"):
			if piece.contains(str(one[2][0])):
				line = piece
		_check("%s is said, with the fix: %s" % [one[0], line.left(240)], said)


## The bricks with studs on a side a shell is held by, and how many lanes each.
const SIDE_STUDS: Dictionary = {"87087": 1, "11211": 2, "30414": 4}


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


## The steps round's car (2026-10-13-steps), its second request: its cockpit
## cut into the body. Laid in 9 pieces; its session built the body by hand.
const CAR_STEPS_CUT: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
	"solids": [{"extrude": {"along": "x", "width": 8, "round": 1.5, "profile": [[0, 5], [1,
	6], [4, 7], [8, 8], [14, 8], [14.01, 13], [16, 11.5], [18, 9.5], [19, 8]],
	"under": [[0, 2], [19, 2]]}}], "cuts": [{"box": {"from": [8, 8, 1], "size": [6, 8, 6]},
	"keep": true}, {"box": {"from": [9, 4, 1], "size": [4, 8, 6]}, "keep": true}],
	"wheels": [4, 14], "wheel_color": 71}

## The same car's third request, a fastback, studs on top: 6 pieces, its nose
## corners floating. The session: "the generator left the nose floating".
const CAR_STEPS_FASTBACK: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4, "top": "studs",
	"solids": [{"extrude": {"along": "x", "width": 8, "round": 1.5, "profile": [[0, 5], [1,
	6], [4, 7], [8, 8], [14, 8], [14.01, 14], [16, 12], [18, 10], [19, 8]], "under": [[0,
	2], [19, 2]]}}], "wheels": [4, 14], "wheel_color": 71}

## A smoothly curved car (2026-10-14), its nose four plates up: 9 pieces.
const CAR_CURVED_NOSE: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 321,
	"solids": [{"extrude": {"along": "x", "width": 8, "round": 2, "profile": [[0, 4], [1,
	5.5], [3, 6.5], [7, 7.5], [9, 8], [16, 8.5], [19, 8.5], [21, 7.5], [22, 6]],
	"under": [[0, 2], [22, 2]]}}, {"loft": {"along": "x", "centre": 4, "color": 40,
	"sections": [{"at": 7.5, "width": 7, "height": 1, "bottom": 7.5}, {"at": 10.5,
	"width": 6, "height": 5, "bottom": 8, "round": 0.6}, {"at": 14, "width": 6,
	"height": 5, "bottom": 8, "round": 0.6}, {"at": 19, "width": 6, "height": 1,
	"bottom": 8.5}]}}], "wheels": [4, 17], "wheel_color": 71}

## The same car's next request, its tail past the back axle: 6 pieces.
const CAR_CURVED_TAIL: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
	"solids": [{"extrude": {"along": "x", "width": 8, "round": 1.5, "profile": [[0, 6], [2,
	7], [7, 8], [17, 8], [21, 7.5], [22, 6.5]], "under": [[0, 2], [22, 2]]}},
	{"loft": {"along": "x", "centre": 4, "color": 0, "sections": [{"at": 7.5, "width": 7,
	"height": 1, "bottom": 7.5}, {"at": 10.5, "width": 6, "height": 6, "bottom": 7.5,
	"round": 0.4}, {"at": 14.5, "width": 6, "height": 5, "bottom": 7.5, "round": 0.4},
	{"at": 19.5, "width": 7, "height": 1, "bottom": 7.5}]}}], "wheels": [4, 17],
	"wheel_color": 71}

## The sides round's car (2026-10-14-sides), its back axle at x 15.5: its
## Technic bricks half a stud off the body's studs, refused.
const CAR_SIDES_AXLE: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
	"solids": [{"extrude": {"along": "x", "width": 8, "round": 1.5, "profile": [[0, 5], [1,
	6], [6, 8], [17, 9], [19, 9], [20, 7]], "under": [[0, 2], [20, 2]]}},
	{"loft": {"along": "x", "centre": 4, "color": 40, "sections": [{"at": 7, "width": 7,
	"height": 1, "bottom": 8}, {"at": 10, "width": 6, "height": 6, "bottom": 8.5,
	"round": 0.5}, {"at": 13, "width": 6, "height": 6, "bottom": 8.5, "round": 0.5},
	{"at": 18, "width": 6, "height": 1, "bottom": 9}]}}], "wheels": [4, 15.5],
	"wheel_color": 71}

## A locomotive's boiler as the 2026-10-12 session said it, its smokebox
## black, lying on the ground: the two colours met face to face and nothing
## crossed, 2 pieces.
const BOILER: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0},
	"solids": [{"revolve": {"axis": "x", "centre": [0, 7.5, 3], "profile": [[0, 3], [4,
	3]]}, "color": 0}, {"revolve": {"axis": "x", "centre": [4, 7.5, 3], "profile": [[0, 3],
	[18, 3]]}, "color": 288}]}

## A ship's hull with its bow planked black: the bow's one tie to the hull
## was an inverted curved slope counted holding what it does not, 2 pieces.
const HULL_BOW: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 70,
	"solids": [{"loft": {"along": "x", "centre": 5, "sections": [{"at": 6, "width": 9,
	"height": 13, "bottom": 1, "round": 0.4, "keel": 0.6}, {"at": 10, "width": 10,
	"height": 14, "bottom": 0, "round": 0.4, "keel": 0.6}, {"at": 26, "width": 10,
	"height": 14, "bottom": 0, "round": 0.4, "keel": 0.6}, {"at": 34, "width": 7,
	"height": 13, "bottom": 2, "round": 0.4, "keel": 0.5}]}}, {"loft": {"along": "x",
	"centre": 5, "color": 0, "sections": [{"at": 0, "width": 2, "height": 10, "bottom": 5,
	"round": 0.4, "keel": 0.5}, {"at": 3, "width": 7, "height": 12, "bottom": 2,
	"round": 0.4, "keel": 0.6}, {"at": 6, "width": 9, "height": 13, "bottom": 1,
	"round": 0.4, "keel": 0.6}]}}]}

## The sides round's starfighter (2026-10-14-sides), its fuselage on its
## stands as its session sent them: the nose past the stands in 3 pieces.
const FIGHTER_NOSE_BRICKS: Array = [{"part": "3941", "color": 72, "x": 13, "y": 0, "z": 8, "rot": 0}, {"part": "3941",
	"color": 72, "x": 13, "y": 3, "z": 8, "rot": 0}, {"part": "3022", "color": 72, "x": 13,
	"y": 6, "z": 8, "rot": 0}, {"part": "3022", "color": 72, "x": 13, "y": 7, "z": 8,
	"rot": 0}, {"part": "3941", "color": 72, "x": 25, "y": 0, "z": 8, "rot": 0},
	{"part": "3941", "color": 72, "x": 25, "y": 3, "z": 8, "rot": 0}, {"part": "3022",
	"color": 72, "x": 25, "y": 6, "z": 8, "rot": 0}, {"part": "3022", "color": 72, "x": 25,
	"y": 7, "z": 8, "rot": 0}, {"part": "3941", "color": 72, "x": 19, "y": 0, "z": 30,
	"rot": 0}, {"part": "3941", "color": 72, "x": 19, "y": 3, "z": 30, "rot": 0},
	{"part": "3022", "color": 72, "x": 19, "y": 6, "z": 30, "rot": 0}, {"part": "3022",
	"color": 72, "x": 19, "y": 7, "z": 30, "rot": 0}, {"part": "41539", "color": 72,
	"x": 12, "y": 8, "z": 2, "rot": 0}, {"part": "41539", "color": 72, "x": 20, "y": 8,
	"z": 2, "rot": 0}, {"part": "3027", "color": 72, "x": 12, "y": 8, "z": 10, "rot": 0},
	{"part": "3028", "color": 72, "x": 17, "y": 8, "z": 16, "rot": 1}, {"part": "3958",
	"color": 72, "x": 17, "y": 8, "z": 28, "rot": 0}, {"part": "3027", "color": 72,
	"x": 12, "y": 9, "z": 2, "rot": 0}, {"part": "3027", "color": 72, "x": 12, "y": 9,
	"z": 8, "rot": 0}, {"part": "3020", "color": 72, "x": 12, "y": 9, "z": 14, "rot": 0},
	{"part": "3023", "color": 72, "x": 16, "y": 9, "z": 14, "rot": 1}, {"part": "3020",
	"color": 72, "x": 24, "y": 9, "z": 14, "rot": 0}, {"part": "3023", "color": 72,
	"x": 23, "y": 9, "z": 14, "rot": 1}, {"part": "3027", "color": 72, "x": 17, "y": 9,
	"z": 14, "rot": 1}, {"part": "3958", "color": 72, "x": 17, "y": 9, "z": 30, "rot": 0}]

const FIGHTER_NOSE: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15, "top": "studs",
	"solids": [{"loft": {"along": "z", "centre": 20, "sections": [{"at": 0, "width": 6,
	"height": 11, "bottom": 10, "round": 0.3}, {"at": 16, "width": 6, "height": 12,
	"bottom": 10, "round": 0.3}, {"at": 30, "width": 4, "height": 7, "bottom": 10,
	"round": 0.4}, {"at": 42, "width": 2, "height": 3, "bottom": 10, "round": 0.5}]}}]}

## A dog on four legs a stud thick: its flank's shells took the legs into
## themselves, held none of them, and the body floated.
const DOG: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 70,
	"solids": [{"ellipsoid": {"centre": [10, 15, 4], "radii": [7, 7, 3.5]}},
	{"box": {"from": [5, 0, 2], "size": [2, 13, 1]}}, {"box": {"from": [5, 0, 5],
	"size": [2, 13, 1]}}, {"box": {"from": [13, 0, 2], "size": [2, 13, 1]}},
	{"box": {"from": [13, 0, 5], "size": [2, 13, 1]}}, {"ellipsoid": {"centre": [18.5, 20,
	4], "radii": [3, 6, 2.5]}, "color": 19}]}

## The sides round's owl (2026-10-14-sides), its body said at y 55 before
## its branch was built: 358 parts floating, and nothing said why.
const OWL_RAISED: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 84,
	"solids": [{"ellipsoid": {"centre": [11, 67, 7.5], "radii": [6.5, 12, 5.5]}}],
	"face": {"facing": "+z", "x": 11, "y": 67, "z": 13, "across": 8, "color": 15,
	"rim": 84, "eyes": 0, "beak": 19}}

## The sides round's starfighter's two engine pods said as one shape, six
## studs apart: 2 pieces, and nothing said why.
const ENGINES: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 71,
	"solids": [{"loft": {"along": "z", "centre": 25, "sections": [{"at": 0, "width": 4,
	"height": 8, "bottom": 6, "round": 0.6}, {"at": 14, "width": 4, "height": 8,
	"bottom": 6, "round": 0.6}]}}, {"loft": {"along": "z", "centre": 15,
	"sections": [{"at": 0, "width": 4, "height": 8, "bottom": 6, "round": 0.6}, {"at": 14,
	"width": 4, "height": 8, "bottom": 6, "round": 0.6}]}}], "top": "studs"}
