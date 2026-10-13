## The surface pass: the app reads a model's open studs, the way they step and
## its plain walls exactly, lays the real pieces for each, and the design
## settles each with settle_surface. On fixtures with known answers:
##
##   a 6 x 8 roof of studs gets tiled, in its own colour, largest first, with
##   a textured tile or two;
##   a 3-step staircase of 2 x 4 bricks gets 45 degree slopes;
##   a yard a minifigure stands on keeps its studs;
##   a long plain wall is laid again with texture in it;
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
	await _build("roof", _roof())
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
	await _build("roof", _roof())
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

	print("\na long plain wall is laid again with texture in it")
	await _build("wall", _wall())
	said = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 700).replace("\n", "\n    "))
	var wall: SurfacePass.Finding = _finding("wall")
	_ok(wall != null and not wall.ids.is_empty(), "a plain wall is found and laid again")
	_ok(_count(_bricks(), ["98283", "15533", "87087"]) > 0,
		"...with masonry or turned-out studs in it")

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
	await _build("roof", _roof())
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


## A dark grey 8 x 8 base plate with a tower of bricks at one corner.
func _ground() -> Array:
	var out: Array = [{"part": "41539", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0}]
	for course: int in 3:
		out.append({"part": "3003", "color": 15, "x": 6, "y": 1 + course * 3, "z": 6, "rot": 0})
	return out


# -- helpers -------------------------------------------------------------------


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
