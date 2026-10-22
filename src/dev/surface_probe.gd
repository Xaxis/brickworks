## The surface pass: the app reads a model's open studs, the way they step and
## its plain walls exactly, lays the real pieces for each, and the design
## settles each with settle_surface. On fixtures with known answers:
##
##   a 6 x 8 roof of studs gets tiled, in its own colour, largest first, with
##   a textured tile or two;
##   a 3-step staircase of 2 x 4 bricks gets 45 degree slopes;
##   a stair of four plate steps a stud deep gets two curved slopes, the
##   model in no more pieces;
##   a body's flank of six plain bricks gets a skin on its side, tiles a
##   plate proud, and one under a course of another colour is left;
##   a car's black course between its wheels, under its red body, gets none;
##   a body of stacked plates gets a skin on both sides in one finding, over
##   the step a stud back on one, the plates' outer row laid again with studs
##   turned out; one course of bricks under plates (a car's side) gets one;
##   open studs on a part's side get tiles on their side;
##   sixteen small tops are all laid in one review;
##   a yard a minifigure stands on keeps its studs;
##   a building's long plain wall is laid again with masonry, no stud
##   turned out;
##
## then that settling works (reject with a reason puts the studs back and is
## never proposed again, keep remembers, accept adjusts), that the app's own
## loop hands the pass before the creative pass, and that saving from outside
## reminds a session that never ran it, without refusing.
##
##   godot --headless --path . --script src/dev/surface_probe.gd
##
## The bench scored surface lowest through six rounds and the judge named the
## same faults each time: "a roof of exposed studs", "stud staircases". Before
## this pass the app had nothing that finished a stud a session built by hand.
extends SceneTree


## The loop with the request taken out. Everything else is the real one.
class Offline extends Assistant:
	var sent: int = 0

	func _send() -> void:
		sent += 1


var _failures: int = 0
var _notes: PackedStringArray = PackedStringArray()
var assistant: Offline
var world: BrickWorld
var builder: Builder
var library: PartLibrary


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
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
	assistant = Offline.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	assistant.progress.connect(func(note: String) -> void: _notes.append(note))
	var ended: Array = []
	assistant.finished.connect(func(ok: bool, summary: String) -> void:
		ended.append([ok, summary]))
	await process_frame

	print("\na 6 x 8 roof of studs gets tiled")
	await _build("house", _roof())
	var plate: int = _brick_of("3036")
	_ok(_open_on(plate) == 48, "the roof plate has 48 open studs (%d)" % _open_on(plate))
	var handed: Variant = await assistant.surface_review()
	_keep_picture(handed, "roof")
	var said: String = _text_of(handed)
	print("    " + said.substr(0, 900).replace("\n", "\n    "))
	var roof: SurfacePass.Finding = _finding("studs")
	_ok(roof != null and roof.studs == 48 and not roof.offered,
		"one finding: the 48 studs of the roof, laid, not offered")
	_ok(_open_on(plate) == 0, "...and no stud of the roof is open now (%d)" % _open_on(plate))
	var tiles: Array = _laid_by(roof)
	var colours: Dictionary = {}
	var biggest: int = 0
	var textured: int = 0
	for brick: BrickWorld.Brick in tiles:
		colours[brick.color_code] = true
		var info: PartLibrary.PartInfo = library.parts[brick.part_id]
		var foot: Vector2i = info.footprint_studs()
		biggest = maxi(biggest, foot.x * foot.y)
		if brick.part_id in SurfacePass.ACCENTS:
			textured += 1
	_ok(colours.keys() == [4], "...every tile in the roof's own red: %s" % str(colours.keys()))
	_ok(biggest >= 8, "...largest first: its biggest tile is %d studs" % biggest)
	_ok(textured >= 1 and textured <= 3, "...with %d textured tile%s among them"
		% [textured, "" if textured == 1 else "s"])
	_ok(said.contains("S1 studs") and said.contains("settle_surface"),
		"the answer names S1 and how to settle it")
	_ok(not str(said).contains("Not applied"), "nothing laid was refused")
	var report: Dictionary = await assistant._check(assistant._model_from_world())
	_ok(bool(report["ok"]), "the roof, tiled, holds as one: %s" % report["summary"])

	print("\nsettling: a reason is wanted, reject takes it off and it stays off")
	var short: String = await assistant.use_tool("settle_surface",
		{"finding": "S1", "verdict": "reject", "reason": "no"})
	_ok(short.begins_with("Say why"), "a reject without a reason is asked for one")
	var rejected: String = await assistant.use_tool("settle_surface", {"finding": "S1",
		"verdict": "reject", "reason": "this roof gets a terrace of its own"})
	print("    " + rejected.replace("\n", "\n    "))
	_ok(roof.verdict == "rejected" and _open_on(plate) == 48,
		"rejected: the tiles are off and the 48 studs are open again (%d)" % _open_on(plate))
	_ok(rejected.contains("Every finding is settled"), "...and every finding is settled")
	var again: String = _text_of(await assistant.surface_review())
	_ok(again.begins_with("The surface pass found nothing to finish"),
		"a second review leaves the rejected roof alone")

	print("\naccept, adjusted plain")
	await _build("house", _roof())
	plate = _brick_of("3036")
	await assistant.surface_review()
	roof = _finding("studs")
	var accents_before: int = _count(_laid_by(roof), SurfacePass.ACCENTS)
	var plain: String = await assistant.use_tool("settle_surface",
		{"finding": "all", "verdict": "accept", "plain": true})
	print("    " + plain.replace("\n", "\n    "))
	_ok(roof.verdict == "adjusted" and _count(_laid_by(roof), SurfacePass.ACCENTS) == 0
		and accents_before > 0, "accepted plain: %d textured tiles laid plain" % accents_before)
	_ok(_open_on(plate) == 0, "...still no open stud on the roof")

	print("\na 3-step staircase of 2 x 4 bricks gets slopes")
	await _build("steps", _steps())
	var tread_one: int = _brick_at("3001", 3)
	var tread_two: int = _brick_at("3001", 6)
	_ok(tread_one != 0 and tread_two != 0, "two step bricks stand above the first")
	handed = await assistant.surface_review()
	_keep_picture(handed, "steps")
	said = _text_of(handed)
	print("    " + said.substr(0, 900).replace("\n", "\n    "))
	var stairs: SurfacePass.Finding = _finding("staircase")
	_ok(stairs != null, "a staircase is found")
	var slopes: int = 0
	for brick: BrickWorld.Brick in _bricks():
		if (library.parts[brick.part_id] as PartLibrary.PartInfo).family_category() == "Slope":
			slopes += 1
	_ok(slopes >= 2, "...and the steps are slopes now: %d slope%s" % [slopes,
		"" if slopes == 1 else "s"])
	_ok(world.get_brick(tread_one) == null and world.get_brick(tread_two) == null,
		"...laid in place of the two step bricks")
	_ok(_open_at_height(48.0) == 0 and _open_at_height(72.0) == 0,
		"...no open stud left on the treads above the first")
	report = await assistant._check(assistant._model_from_world())
	_ok(bool(report["ok"]), "the sloped steps hold as one: %s" % report["summary"])
	var kept: String = await assistant.use_tool("settle_surface", {"finding":
		stairs.key if stairs != null else "S9",
		"verdict": "keep", "reason": "the steps are a stair for the figures"})
	_ok(stairs.verdict == "kept" and _brick_at("3001", 3) != 0 and _brick_at("3001", 6) != 0,
		"kept: the step bricks are back as they were: %s" % kept.get_slice("\n", 0))

	print("\na staircase of tiled steps gets slopes, its tread tiles off")
	await _build("tiled steps", _tiled_steps())
	var tread_tile: int = _brick_at("2431", 6)
	_ok(tread_tile != 0 and _open_at_height(48.0) == 0, "the second tread is a tile, no stud open")
	said = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 700).replace("\n", "\n    "))
	stairs = _finding("staircase")
	_ok(stairs != null and stairs.said.contains("tiled studs"), "a tiled staircase is found")
	slopes = 0
	for brick: BrickWorld.Brick in _bricks():
		if (library.parts[brick.part_id] as PartLibrary.PartInfo).family_category() == "Slope":
			slopes += 1
	_ok(slopes >= 2 and world.get_brick(tread_tile) == null,
		"...the steps are slopes (%d) and the tread's tile is off" % slopes)
	report = await assistant._check(assistant._model_from_world())
	_ok(bool(report["ok"]) and int(report.get("pieces", 0)) == 1,
		"...and it holds as one piece: %s" % report["summary"])
	var put_back: String = await assistant.use_tool("settle_surface", {"finding": "all",
		"verdict": "reject", "reason": "these steps are a stair for the figures"})
	_ok(world.get_brick(tread_tile) == null and _brick_at("2431", 6) != 0
		and _brick_at("3001", 3) != 0, "rejected, the bricks and the tread's tile are back: %s"
		% put_back.get_slice("\n", 0))

	print("\na stair of four plate steps a stud deep gets two curved slopes, a pair each")
	await _build("speeder nose", _plate_steps())
	var pieces_before: int = await _pieces()
	said = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 700).replace("\n", "\n    "))
	stairs = _finding("staircase")
	_ok(stairs != null and not stairs.ids.is_empty() and stairs.said.contains("by a plate"),
		"a staircase of plate steps is found and laid")
	var curves: Array = []
	for brick: BrickWorld.Brick in _bricks():
		if brick.part_id in ["15068", "11477", "88930", "7302"]:
			curves.append(brick)
	_ok(curves.size() == 2 and (curves[0] as BrickWorld.Brick).part_id == "15068",
		"...as 2 curved slopes two plates tall, two studs across: %s" % str(curves.map(
			func(brick: BrickWorld.Brick) -> String: return brick.part_id)))
	_ok(_brick_at("3020", 4) == 0 and _brick_at("3021", 6) == 0
		and _brick_at("3021", 4) != 0 and _brick_at("3022", 6) != 0,
		"...the upper treads' plates cut under them, the rest of each laid again")
	# Read as the pass reads them: a stud under a curved slope's hollow high
	# end is open to a tip test, and the lattice knows better.
	var stepped: SurfacePass = assistant.surface_pass()
	stepped._read = OpenPoints.read(assistant)
	var left_on_steps: int = 0
	for key: Vector3i in stepped.open_tops():
		if key.y * 2 < 64:
			left_on_steps += 1
	_ok(left_on_steps == 0, "...no stud left open on the four steps (%d)" % left_on_steps)
	_ok(await _pieces() == pieces_before, "...and the model is in as many pieces as before (%d)"
		% pieces_before)

	print("\na flank of six plain bricks on a body gets a skin on its side")
	await _build("speeder hull", _flank())
	pieces_before = await _pieces()
	said = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 900).replace("\n", "\n    "))
	var skins: int = 0
	for one: SurfacePass.Finding in assistant.surface_pass().findings:
		if one.kind == "flank" and not one.ids.is_empty():
			skins += 1
	_ok(skins == 2 and _finding("wall") == null,
		"both flanks are skinned (%d), and not textured as a building's wall" % skins)
	_ok(_count(_bricks(), ["30414"]) == 4 and _count(_bricks(), ["3010"]) == 8,
		"...one course of each laid again with its studs turned out (%d 30414)"
		% _count(_bricks(), ["30414"]))
	var low_skin: int = 0
	var side_brick: Lbm.PartMesh = library.mesh_for("30414")
	for brick: BrickWorld.Brick in _bricks():
		if brick.part_id == "30414" and brick.transform.origin.z > 40.0 \
				and absf((brick.transform * side_brick.bounds).abs().position.y) < 1.0:
			low_skin += 1
	_ok(low_skin == 2, "...the white-striped side's a course lower, under a red one (%d)"
		% low_skin)
	_ok(_sideways(["5520"]) == 4 and _sideways(["87079"]) == 2
		and _sideways(["15068", "3020"]) == 0, "...and on them, on their side, tiles straight "
		+ "on the studs, a rounded end at each end (%d) and a 2 x 4 between (%d)" % [
			_sideways(["5520"]), _sideways(["87079"])])
	var proud: float = 0.0
	for brick: BrickWorld.Brick in _bricks():
		if brick.part_id in ["5520", "87079"] \
				and BrickLattice.face_of(brick.transform.basis) != "up":
			var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
			proud = maxf(proud, -(brick.transform * mesh.bounds).abs().position.z)
	_ok(absf(proud - 8.0) < 0.5, "...standing a plate proud of the flank (%.0f LDU)" % proud)
	_ok(said.contains("under a body of white"),
		"the flank under a white course is left, not painted over")
	_ok(await _pieces() == pieces_before, "...and the model is in as many pieces as before (%d)"
		% pieces_before)
	await assistant.use_tool("settle_surface", {"finding": "all", "verdict": "reject",
		"reason": "the hull wants its bricks bare here"})
	_ok(_count(_bricks(), ["30414", "5520", "87079"]) == 0
		and _count(_bricks(), ["3010"]) == 12, "rejected, the plain bricks are back")

	print("\na car's black course between its wheels, under its red body, gets no skin")
	await _build("racing car", _car())
	pieces_before = await _pieces()
	said = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 900).replace("\n", "\n    "))
	var black_out: int = 0
	var black_plain: int = 0
	for brick: BrickWorld.Brick in _bricks():
		if brick.part_id in SurfacePass.SIDE_STUDS.values() and brick.color_code == 0:
			black_out += 1
		if brick.part_id == "3009" and brick.color_code == 0:
			black_plain += 1
	_ok(black_out == 0 and black_plain == 2,
		"no stud of the black course is turned out (%d), its bricks as they were" % black_out)
	_ok(said.contains("under a wider course") or said.contains("under a body of red"),
		"...said why: it is not the body's flank")
	_ok(await _pieces() == pieces_before, "...and the model is in as many pieces as before (%d)"
		% pieces_before)

	print("\na body of stacked plates gets a skin on both sides, over the step on one")
	await _build("speeder fuselage", _plate_body())
	pieces_before = await _pieces()
	said = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 900).replace("\n", "\n    "))
	var plated: SurfacePass.Finding = null
	for one: SurfacePass.Finding in assistant.surface_pass().findings:
		if one.kind == "flank" and one.said.contains("three plates stacked"):
			plated = one
	_ok(plated != null and not plated.ids.is_empty() and plated.said.contains("flanks"),
		"the plates' flanks are found and laid, both sides as one finding")
	var near_side: int = 0
	var far_side: int = 0
	for brick: BrickWorld.Brick in _bricks():
		if brick.part_id == "30414":
			if brick.transform.origin.z < 40.0:
				near_side += 1
			else:
				far_side += 1
	_ok(near_side == 2 and far_side == 2, "...their outer row laid again with studs turned "
		+ "out, two 1 x 4s a side (%d and %d)" % [near_side, far_side])
	_ok(_sideways(["5520"]) == 4 and _sideways(["87079"]) == 2, "...and on them, on their "
		+ "side, a rounded end at each end (%d) and a 2 x 4 tile between (%d)"
		% [_sideways(["5520"]), _sideways(["87079"])])
	_ok(_count(_bricks(), ["3035"]) == 1 and _count(_bricks(), ["3034"]) == 6,
		"...the three plates under the skin cut, each one's rest laid again (%d 4 x 8, %d 2 x 8)"
		% [_count(_bricks(), ["3035"]), _count(_bricks(), ["3034"])])
	_ok(await _pieces() == pieces_before, "...and the model is in as many pieces as before (%d)"
		% pieces_before)
	_ok(plated != null and plated.of == "plates", "...told apart in the record as of plates")
	await assistant.use_tool("settle_surface", {"finding": "all", "verdict": "reject",
		"reason": "the fuselage keeps its plates here"})
	_ok(_count(_bricks(), ["30414", "5520", "87079"]) == 0
		and _count(_bricks(), ["3035"]) == 4, "rejected, the plates are back whole")

	print("\nwhere one side cannot be skinned all along, the other side matches it")
	await _build("speeder fuselage", _plate_body() + [{"part": "3005", "color": 0, "x": 0,
		"y": 0, "z": -1, "rot": 0}])
	await assistant.surface_review()
	var by_side: Array = [{}, {}]
	for brick: BrickWorld.Brick in _bricks():
		if brick.part_id in SurfacePass.SIDE_STUDS.values():
			var side: Dictionary = by_side[0 if brick.transform.origin.z < 40.0 else 1]
			side[brick.part_id] = int(side.get(brick.part_id, 0)) + 1
	_ok(by_side[0] == by_side[1] and by_side[0] == {"30414": 1, "11211": 1, "87087": 1},
		"a post in front of a stud of the -z side: both sides skinned seven studs (%s, %s)"
		% [str(by_side[0]), str(by_side[1])])

	print("\na course of bricks under plates gets a skin: a car's side")
	await _build("racing car", _brick_under_plates())
	pieces_before = await _pieces()
	said = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 700).replace("\n", "\n    "))
	_ok(_count(_bricks(), ["30414"]) == 4 and _count(_bricks(), ["3008"]) == 0,
		"both sides' course laid again with studs turned out (%d 30414)"
		% _count(_bricks(), ["30414"]))
	_ok(_sideways(["5520"]) == 4 and _sideways(["87079"]) == 2,
		"...and skinned (%d rounded ends, %d 2 x 4 tiles)" % [_sideways(["5520"]),
			_sideways(["87079"])])
	_ok(await _pieces() == pieces_before, "...and the model is in as many pieces as before (%d)"
		% pieces_before)

	print("\nopen studs on a side get tiles on their side")
	await _build("speeder", _side_studs())
	var side_open: int = _open_sideways()
	said = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 500).replace("\n", "\n    "))
	_ok(side_open == 8 and _open_sideways() == 0,
		"the side's %d open studs are all covered (%d left)" % [side_open, _open_sideways()])
	_ok(_sideways(["2431", "3069b", "3068b", "87079", "63864"]) >= 2,
		"...by tiles laid on their side (%d)" % _sideways(["2431", "3069b", "3068b", "87079",
			"63864"]))
	await assistant.use_tool("settle_surface", {"finding": "all", "verdict": "accept"})
	_ok(assistant.surface_pass().record().contains("8 side studs tiled"),
		"...and the record says them apart from tops: %s" % assistant.surface_pass().record())

	print("\nevery finding is laid at once, not twelve of them")
	await _build("pillars", _pillars())
	said = _text_of(await assistant.surface_review())
	var laid_fields: int = 0
	for one: SurfacePass.Finding in assistant.surface_pass().findings:
		if one.kind == "studs" and not one.ids.is_empty():
			laid_fields += 1
	_ok(laid_fields == 16 and assistant.surface_pass().more == 0
		and not said.contains("not laid yet"),
		"all 16 tops are laid in one review (%d), none left for another" % laid_fields)

	print("\na head's hard top edges are curved over, the top raised flush")
	await _build("owl head", _head())
	var head_top: float = assistant._bounds_of(_bricks()).end.y
	said = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 700).replace("\n", "\n    "))
	var crown: SurfacePass.Finding = _finding("edge")
	_ok(crown != null and not crown.ids.is_empty(), "the top's hard edges are found and laid")
	var curved: int = _count(_bricks(), ["15068", "11477"])
	_ok(curved >= 4, "...as %d curved slopes along them" % curved)
	_ok(absf(assistant._bounds_of(_bricks()).end.y - head_top - 8.0) < 1.0,
		"...and the top raised a plate, flush with them (%.0f to %.0f)"
		% [head_top, assistant._bounds_of(_bricks()).end.y])
	# As the pass reads them: a curved slope's hollow underside reads as
	# nothing on the stud to a tip test, and the lattice knows better.
	var finished: SurfacePass = assistant.surface_pass()
	finished._read = OpenPoints.read(assistant)
	_ok(finished.open_tops().is_empty(), "...with no stud left open on it (%d)"
		% finished.open_tops().size())
	report = await assistant._check(assistant._model_from_world())
	_ok(bool(report["ok"]) and int(report.get("pieces", 0)) == 1,
		"...and the head holds as one piece: %s" % report["summary"])
	await _build("house roof", _head())
	await assistant.surface_review()
	_ok(_finding("edge") == null, "a building's top keeps its edges")

	print("\nan edit that would leave the model in more pieces is refused while a pass keeps count")
	await _build("owl head", _head())
	assistant._keep_pieces = 1
	var split: String = await assistant.use_tool("edit_model", {"add": [
		{"part": "3001", "color": 4, "x": 6, "y": 0, "z": 0, "rot": 0}]})
	assistant._keep_pieces = -1
	_ok(split.begins_with("Not applied — it would leave the model in 2 pieces"),
		"refused: %s" % split.get_slice("\n", 0))

	print("\na wing laid at an angle is tiled in its own frame")
	await _build_with("wing", _wing(), [{"name": "wing", "x": 0, "y": 3, "z": 0,
		"axis": "z", "degrees": 15, "hinge": true}])
	var wing_plate: int = _brick_of("3020")
	var wing_open: int = _open_on(wing_plate)
	said = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 500).replace("\n", "\n    "))
	var tilted: SurfacePass.Finding = _finding("studs")
	_ok(wing_open == 8 and tilted != null and tilted.section == "wing",
		"the wing's %d open studs are found, in its section" % wing_open)
	_ok(_open_on(wing_plate) == 0 and tilted != null and not tilted.ids.is_empty(),
		"...and tiled in it: %d left open" % _open_on(wing_plate))

	print("\na yard a minifigure stands on keeps its studs")
	await _build("yard", _yard())
	var yard: int = _brick_of("41539")
	await assistant.use_tool("add_minifig", {"name": "gardener", "x": 3, "z": 3})
	var before: int = _open_on(yard)
	var figure: int = 0
	for brick: BrickWorld.Brick in _bricks():
		if (library.parts[brick.part_id] as PartLibrary.PartInfo).family_category().begins_with(
				"Minifig"):
			figure += 1
	_ok(figure >= 4, "a figure of %d parts stands on the yard" % figure)
	said = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 600).replace("\n", "\n    "))
	_ok(_open_on(yard) == before, "...and its studs are left as they were (%d)" % _open_on(yard))
	_ok(said.contains("a yard"), "...said: a yard")

	print("\na building's long plain wall is laid again with masonry in it, no stud turned out")
	await _build("house wall", _wall())
	said = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 700).replace("\n", "\n    "))
	var wall: SurfacePass.Finding = _finding("wall")
	_ok(wall != null and not wall.ids.is_empty(), "a plain wall is found and laid again")
	_ok(_count(_bricks(), ["98283", "15533"]) > 0 and _count(_bricks(), ["87087"]) == 0,
		"...with masonry in it (%d) and no turned-out stud (%d)" % [
			_count(_bricks(), ["98283", "15533"]), _count(_bricks(), ["87087"])])

	print("\nthe ground is offered, laid only when told")
	await _build("ground", _ground())
	var base: int = _brick_of("41539")
	said = _text_of(await assistant.surface_review())
	var ground: SurfacePass.Finding = _finding("studs")
	_ok(ground != null and ground.offered and ground.key.begins_with("G")
		and _open_on(base) == 60, "the base is offered as %s, nothing laid on it"
		% (ground.key if ground != null else "nothing"))
	var tiled: String = await assistant.use_tool("settle_surface", {"finding": "G1",
		"verdict": "tile"})
	_ok(_open_on(base) == 0, "\"tile\" lays it: %s" % tiled.get_slice("\n", 0))

	print("\nsaving from outside reminds a session that never ran it, without refusing")
	await _build("house", _roof())
	var reminder: String = await assistant.next_review()
	_ok(reminder.begins_with("Before it is finished: The surface pass has not been run"),
		"the first save says so: %s" % reminder.substr(0, 90))
	var second: String = await assistant.next_review()
	_ok(second.contains("The surface pass has not been run")
		and second.contains("The creative pass"), "the next says it again, with the creative pass")
	await assistant.surface_review()
	var unsettled: String = await assistant.next_review()
	_ok(unsettled.contains("S1 not settled"), "with the pass laid and not settled, saving says which")

	print("\nin the app's own loop the pass comes before the creative pass")
	assistant._busy = false
	world.clear()
	builder.lattice.clear()
	ended.clear()
	_ok(assistant.design("A small red house"), "a new design")
	await _reply([_tool("submit_design", {"name": "house", "description": "a box with a roof",
		"bricks": _roof(), "features": []})])
	_ok(assistant._looked_back, "it holds, so it is looked at whole first")
	await _reply([{"type": "text", "text": "It reads as a house."}])
	var brief: String = _text_of(assistant._messages.back())
	_ok(brief.begins_with("The surface pass") and brief.contains("S1 studs"),
		"next: the surface pass, laid")
	_ok(ended.is_empty() and bool(assistant._detailing.get("surface", false)),
		"...a turn of its own, the run going on")
	await _reply([_tool("settle_surface", {"finding": "all", "verdict": "accept"})])
	brief = _text_of(assistant._messages.back())
	_ok(brief.contains("Every finding is settled") and brief.contains("The creative pass"),
		"settled, the creative pass comes straight after")
	_ok(brief.contains("The surface pass tiled tops"), "...told a touch on a tile floats")
	_ok(_said("the surface pass: 1 finding: 1 accepted"), "the progress line records it")
	assistant.cancel()
	await process_frame

	print("")
	if _failures == 0:
		print("OK surface_probe")
	else:
		print("FAILED surface_probe: %d" % _failures)
	quit(1 if _failures > 0 else 0)


# -- fixtures ------------------------------------------------------------------


## A block of 2 x 2 bricks, 8 x 6 studs, and a red 6 x 8 plate on it.
func _roof() -> Array:
	var out: Array = []
	for x: int in [0, 2, 4, 6]:
		for z: int in [0, 2, 4]:
			out.append({"part": "3003", "color": 15, "x": x, "y": 0, "z": z, "rot": 0})
	out.append({"part": "3036", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0})
	return out


## Three 2 x 4 bricks, each a brick up and a stud back.
func _steps() -> Array:
	return [{"part": "3001", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3001", "color": 72, "x": 0, "y": 3, "z": 1, "rot": 0},
		{"part": "3001", "color": 72, "x": 0, "y": 6, "z": 2, "rot": 0}]


## A green 8 x 8 plate on a course of 2 x 2 bricks.
func _yard() -> Array:
	var out: Array = []
	for x: int in [0, 2, 4, 6]:
		for z: int in [0, 2, 4, 6]:
			out.append({"part": "3003", "color": 70, "x": x, "y": 0, "z": z, "rot": 0})
	out.append({"part": "41539", "color": 2, "x": 0, "y": 3, "z": 0, "rot": 0})
	return out


## A plain tan wall, 8 studs long and four courses tall, bonded.
func _wall() -> Array:
	var out: Array = []
	for course: int in 4:
		if course % 2 == 0:
			for x: int in [0, 4]:
				out.append({"part": "3010", "color": 19, "x": x, "y": course * 3, "z": 0, "rot": 0})
		else:
			out.append({"part": "3004", "color": 19, "x": 0, "y": course * 3, "z": 0, "rot": 0})
			out.append({"part": "3010", "color": 19, "x": 2, "y": course * 3, "z": 0, "rot": 0})
			out.append({"part": "3004", "color": 19, "x": 6, "y": course * 3, "z": 0, "rot": 0})
	return out


## Five white plates on a block of bricks, each a stud shorter than the one
## under it, along x: four steps a plate high and a stud deep, then a top two
## studs deep. The second step's plate is a 2 x 4 and a 1 x 2.
func _plate_steps() -> Array:
	return [{"part": "3001", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3003", "color": 15, "x": 4, "y": 0, "z": 0, "rot": 0},
		{"part": "3795", "color": 15, "x": 0, "y": 3, "z": 0, "rot": 0},
		{"part": "3020", "color": 15, "x": 1, "y": 4, "z": 0, "rot": 0},
		{"part": "3023b", "color": 15, "x": 5, "y": 4, "z": 0, "rot": 1},
		{"part": "3020", "color": 15, "x": 2, "y": 5, "z": 0, "rot": 0},
		{"part": "3021", "color": 15, "x": 3, "y": 6, "z": 0, "rot": 0},
		{"part": "3022", "color": 15, "x": 4, "y": 7, "z": 0, "rot": 0}]


## A red body 8 studs long and 4 deep, three courses tall: each long side a
## flank of six 1 x 4 bricks, two a course, round a core of 2 x 4 and 2 x 2
## bricks bonded across its joints, and a 4 x 8 plate on top. The +z side's
## top course is white, a stripe.
func _flank() -> Array:
	var out: Array = []
	for course: int in 3:
		for x: int in [0, 4]:
			for z: int in [0, 3]:
				out.append({"part": "3010", "color": 15 if course == 2 and z == 3 else 4,
					"x": x, "y": course * 3, "z": z, "rot": 0})
		if course % 2 == 0:
			for x: int in [0, 4]:
				out.append({"part": "3001", "color": 4, "x": x, "y": course * 3, "z": 1, "rot": 0})
		else:
			out.append({"part": "3003", "color": 4, "x": 0, "y": course * 3, "z": 1, "rot": 0})
			out.append({"part": "3001", "color": 4, "x": 2, "y": course * 3, "z": 1, "rot": 0})
			out.append({"part": "3003", "color": 4, "x": 6, "y": course * 3, "z": 1, "rot": 0})
	out.append({"part": "3035", "color": 4, "x": 0, "y": 9, "z": 0, "rot": 0})
	return out


## The bench car's side in small: a black course 6 studs long and 4 deep,
## between where its wheels would be, and on it a red course 10 long that
## reaches two studs past it at each end, over the arches, and a
## red 4 x 10 plate on top.
func _car() -> Array:
	var out: Array = []
	for z: int in [0, 3]:
		out.append({"part": "3009", "color": 0, "x": 2, "y": 0, "z": z, "rot": 0})
		out.append({"part": "3009", "color": 4, "x": 0, "y": 3, "z": z, "rot": 0})
		out.append({"part": "3010", "color": 4, "x": 6, "y": 3, "z": z, "rot": 0})
	out.append({"part": "2456", "color": 0, "x": 2, "y": 0, "z": 1, "rot": 0})
	out.append({"part": "3001", "color": 4, "x": 0, "y": 3, "z": 1, "rot": 0})
	out.append({"part": "2456", "color": 4, "x": 4, "y": 3, "z": 1, "rot": 0})
	out.append({"part": "3030", "color": 4, "x": 0, "y": 6, "z": 0, "rot": 0})
	return out


## A red body of plates 8 studs long and 4 deep, seven plates tall: four 4 x
## 8 plates, then three plates a stud narrower on the +z side (a 2 x 8 and a 1
## x 8 each), so that side steps back a stud over its fourth plate.
func _plate_body() -> Array:
	var out: Array = []
	for up: int in 4:
		out.append({"part": "3035", "color": 4, "x": 0, "y": up, "z": 0, "rot": 0})
	for up: int in range(4, 7):
		out.append({"part": "3034", "color": 4, "x": 0, "y": up, "z": 0, "rot": 0})
		out.append({"part": "3460", "color": 4, "x": 0, "y": up, "z": 2, "rot": 0})
	return out


## A red body 8 long and 4 deep: one course of bricks, a 1 x 8 on each side
## of a 2 x 8, and three 4 x 8 plates on it.
func _brick_under_plates() -> Array:
	var out: Array = [{"part": "3008", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3007", "color": 4, "x": 0, "y": 0, "z": 1, "rot": 0},
		{"part": "3008", "color": 4, "x": 0, "y": 0, "z": 3, "rot": 0}]
	for up: int in range(3, 6):
		out.append({"part": "3035", "color": 4, "x": 0, "y": up, "z": 0, "rot": 0})
	return out


## Two 1 x 4 bricks with studs on a side, one on the other, on a 1 x 4 plate:
## eight side studs open, in two rows.
func _side_studs() -> Array:
	return [{"part": "3710", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "30414", "color": 72, "x": 0, "y": 1, "z": 0, "rot": 0},
		{"part": "30414", "color": 72, "x": 0, "y": 4, "z": 0, "rot": 0}]


## Sixteen 2 x 2 columns in a row on two 2 x 16 plates, a brick and three
## bricks tall by turns: sixteen tops of four studs, each a finding.
func _pillars() -> Array:
	var out: Array = [{"part": "4282", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "4282", "color": 72, "x": 16, "y": 0, "z": 0, "rot": 0}]
	for n: int in 16:
		for course: int in (1 if n % 2 == 0 else 3):
			out.append({"part": "3003", "color": 1, "x": n * 2, "y": 1 + course * 3, "z": 0,
				"rot": 0})
	return out


## A dark grey 8 x 8 base plate with a tower of bricks at one corner.
func _ground() -> Array:
	var out: Array = [{"part": "41539", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0}]
	for course: int in 3:
		out.append({"part": "3003", "color": 15, "x": 6, "y": 1 + course * 3, "z": 6, "rot": 0})
	return out


# -- helpers -------------------------------------------------------------------


## The three steps again, every tread tiled.
func _tiled_steps() -> Array:
	return _steps() + [{"part": "2431", "color": 72, "x": 0, "y": 3, "z": 0, "rot": 0},
		{"part": "2431", "color": 72, "x": 0, "y": 6, "z": 1, "rot": 0},
		{"part": "87079", "color": 72, "x": 0, "y": 9, "z": 2, "rot": 0}]


## A tan head: 2 x 2 bricks under a 6 x 6 plate, its top tiled.
func _head() -> Array:
	var out: Array = []
	for x: int in [0, 2, 4]:
		for z: int in [0, 2, 4]:
			out.append({"part": "3003", "color": 19, "x": x, "y": 0, "z": z, "rot": 0})
	out.append({"part": "3958", "color": 19, "x": 0, "y": 3, "z": 0, "rot": 0})
	for z: int in [0, 2, 4]:
		out.append({"part": "69729", "color": 19, "x": 0, "y": 4, "z": z, "rot": 0})
	return out


## A 1 x 2 brick and, hinged on it, a 2 x 4 plate: a wing.
func _wing() -> Array:
	return [{"part": "3004", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 1},
		{"part": "3020", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 0, "section": "wing"}]


## A design from outside, on a bare baseplate.
func _build(name: String, bricks: Array) -> void:
	await _build_with(name, bricks, [])


func _build_with(name: String, bricks: Array, sections: Array) -> void:
	assistant._busy = false
	world.clear()
	builder.lattice.clear()
	# As the app's Clear does: the fixture before is not this one's subject.
	# Without it the owl head made the house roof after it an owl.
	assistant.forget_built()
	var args: Dictionary = {"name": name, "description": "a fixture", "bricks": bricks,
		"features": []}
	if not sections.is_empty():
		args["sections"] = sections
	var built: Variant = await assistant.use_tool("submit_design", args)
	if not str(built).begins_with("Built"):
		print("    could not build the %s: %s" % [name, str(built).substr(0, 300)])


func _bricks() -> Array[BrickWorld.Brick]:
	return assistant._bricks_inside({})


func _brick_of(part: String) -> int:
	for brick: BrickWorld.Brick in _bricks():
		if brick.part_id == part:
			return brick.id
	return 0


## The brick of [param part] whose bottom is [param plates] up.
func _brick_at(part: String, plates: int) -> int:
	for brick: BrickWorld.Brick in _bricks():
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if brick.part_id == part and mesh != null \
				and absf((brick.transform * mesh.bounds).abs().position.y - plates * 8.0) < 1.0:
			return brick.id
	return 0


func _open_points() -> Array:
	var ids: Array = []
	for brick: BrickWorld.Brick in _bricks():
		ids.append(brick.id)
	var out: Array = []
	for point: OpenPoints.Point in OpenPoints.read(assistant).points_of(ids):
		# Up, or up in a section tipped a little (a wing).
		if point.kind == "stud" and point.by == 0 and point.way.dot(Vector3.UP) > 0.9:
			out.append(point)
	return out


## Open studs that point sideways, nothing on them.
func _open_sideways() -> int:
	var ids: Array = []
	for brick: BrickWorld.Brick in _bricks():
		ids.append(brick.id)
	var n: int = 0
	for point: OpenPoints.Point in OpenPoints.read(assistant).points_of(ids):
		if point.kind == "stud" and point.by == 0 and absf(point.way.y) < 0.1:
			n += 1
	return n


func _open_on(brick: int) -> int:
	var n: int = 0
	for point: Variant in _open_points():
		if (point as OpenPoints.Point).brick == brick:
			n += 1
	return n


func _open_at_height(y: float) -> int:
	var n: int = 0
	for point: Variant in _open_points():
		if absf((point as OpenPoints.Point).at.y - y) < 1.0:
			n += 1
	return n


func _finding(kind: String) -> SurfacePass.Finding:
	for one: SurfacePass.Finding in assistant.surface_pass().findings:
		if one.kind == kind:
			return one
	return null


func _laid_by(one: SurfacePass.Finding) -> Array:
	var out: Array = []
	if one == null:
		return out
	for id: int in one.ids:
		var brick: BrickWorld.Brick = world.get_brick(id)
		if brick != null:
			out.append(brick)
	return out


## How many pieces the model is in, as the check reads it.
func _pieces() -> int:
	var report: Dictionary = await assistant._check(assistant._model_from_world())
	return int(report.get("pieces", 0))


## The bricks of [param parts] laid on their side.
func _sideways(parts: Array) -> int:
	var n: int = 0
	for brick: BrickWorld.Brick in _bricks():
		if brick.part_id in parts and BrickLattice.face_of(brick.transform.basis) != "up":
			n += 1
	return n


func _count(bricks: Array, parts: Array) -> int:
	var n: int = 0
	for brick: Variant in bricks:
		if (brick as BrickWorld.Brick).part_id in parts:
			n += 1
	return n


## Where there is a screen to draw on, the one picture the pass hands over,
## kept in the app's user folder to be looked at: surface_<name>.png.
func _keep_picture(answer: Variant, name: String) -> void:
	if not answer is Array:
		return
	for block: Variant in answer:
		var one: Dictionary = block
		if str(one.get("type", "")) != "image":
			continue
		var image := Image.new()
		if image.load_png_from_buffer(Marshalls.base64_to_raw(
				str((one["source"] as Dictionary)["data"]))) == OK:
			var path: String = OS.get_user_data_dir().path_join("surface_%s.png" % name)
			image.save_png(path)
			print("    the picture handed over: %s" % path)


func _reply(content: Array) -> void:
	var body: String = JSON.stringify({"content": content, "stop_reason": "end_turn"})
	await assistant._on_response([HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(), body.to_utf8_buffer()])


func _tool(name: String, input: Dictionary) -> Dictionary:
	return {"type": "tool_use", "id": "t%d" % randi(), "name": name, "input": input}


## All the words in an answer or a message, wherever they sit in it.
func _text_of(message: Variant) -> String:
	if message is String:
		return message
	var content: Variant = message
	if message is Dictionary:
		content = (message as Dictionary).get("content")
	if content is String:
		return content
	var said := PackedStringArray()
	for block: Variant in content:
		var one: Dictionary = block
		if one.get("type", "") == "text":
			said.append(str(one.get("text", "")))
		elif one.get("type", "") == "tool_result":
			said.append(_text_of(one.get("content")))
	return "\n".join(said)


func _said(start: String) -> bool:
	for note: String in _notes:
		if note.begins_with(start):
			return true
	return false


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
