## The surface pass cuts the ground back to what stands on it. On fixtures
## with known answers:
##
##   a house and a figure in one corner of a 32 x 32 baseplate: the baseplate
##   is laid again as the smallest baseplate holding them and a stud round,
##   its top where it was, what stands on it unmoved, the model one piece and
##   holding, and the answer says why;
##   kept with a reason, the 32 x 32 is back as it was and is not proposed
##   again;
##   a 16 x 16 plate with a small hut on it: laid again as a plate the hut's
##   size and a stud round, and accepted;
##   a plinth whose top is tiled but for a thin edge: left as it is;
##   a ground part with nothing on it, loose beside the model: taken off,
##   the model in fewer pieces;
##   and a cut that would open a hole inside the ground is never made.
##
##   godot --headless --path . --script src/dev/ground_cut_probe.gd
##
## design14 read the proof's 44: our scenes laid a ground over 78% of their
## footprint where their sets laid it over 18%, and the judge named
## "a flat green baseplate", "most of its baseplate exposed studs".
extends SceneTree


## The loop with the request taken out. Everything else is the real one.
class Offline extends Assistant:
	func _send() -> void:
		pass


var _failures: int = 0
var assistant: Offline
var world: BrickWorld
var builder: Builder
var library: PartLibrary


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	Assistant.design_parts = 1
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
	await process_frame

	print("\na house and a figure in one corner of a 32 x 32 baseplate")
	await _build("farmyard", _corner_house())
	await assistant.use_tool("add_minifig", {"name": "farmer", "x": 3, "z": 9})
	var base: int = _brick_of("3811")
	var top_before: float = _top_of(base)
	# The roof is the house's: the edge and flank findings beside it lay its
	# top and sides again, so the house is read by its roof.
	var roof_before: Dictionary = _where_all("3031")
	var open_before: int = _open_on(base)
	var said: String = _text_of(await assistant.surface_review())
	print("    " + said.substr(0, 1200).replace("\n", "\n    "))
	var cut: SurfacePass.Finding = _finding("ground")
	_ok(cut != null and not cut.offered and _brick_of("3811") == 0,
		"a ground finding, laid: the 32 x 32 baseplate is off")
	var laid: Array = _laid_by(cut)
	var new_base: BrickWorld.Brick = laid[0] if laid.size() == 1 else null
	var foot: Vector2i = (library.parts[new_base.part_id] as PartLibrary.PartInfo).footprint_studs() \
		if new_base != null else Vector2i.ZERO
	_ok(new_base != null and (library.parts[new_base.part_id] as PartLibrary.PartInfo
		).family_category() == "Baseplate" and foot.x * foot.y < 1024 and foot.x * foot.y >= 64,
		"...laid again as one smaller baseplate: %s (%d x %d)" % [
			new_base.part_id if new_base != null else "none", foot.x, foot.y])
	_ok(new_base != null and absf(_top_of(new_base.id) - top_before) < 0.1,
		"...its top where the old one's was (%.1f, %.1f)" % [
			_top_of(new_base.id) if new_base != null else 0.0, top_before])
	_ok(cut != null and cut.remove.size() == 1 and cut.remove[0] == base and _where_all("3031") == roof_before,
		"...it took off only the baseplate, the house standing where it stood")
	var report: Dictionary = await assistant._check(assistant._model_from_world())
	_ok(bool(report["ok"]) and int(report.get("pieces", 0)) == 1,
		"...and the model holds as one piece: %s" % report["summary"])
	_ok(new_base != null and _open_on(new_base.id) < open_before / 2,
		"...its open studs %d, from %d" % [_open_on(new_base.id) if new_base != null else -1,
			open_before])
	_ok(said.contains(cut.key + " ground") if cut != null else false,
		"the answer names it as a ground finding")
	_ok(said.count("real sets of scenes lay a base only the size of what stands on it") == 1,
		"...and says why, once")

	print("\nkept with a reason: the baseplate back as it was, and never proposed again")
	var kept: String = await assistant.use_tool("settle_surface", {"finding": cut.key
		if cut != null else "S1", "verdict": "keep",
		"reason": "the open green is the field the farmer's animals will graze"})
	print("    " + kept.substr(0, 300).replace("\n", "\n    "))
	_ok(_brick_of("3811") != 0 and new_base != null and world.get_brick(new_base.id) == null,
		"the 32 x 32 is back and the smaller one gone")
	_ok(absf(_top_of(_brick_of("3811")) - top_before) < 0.1, "...where it was")
	report = await assistant._check(assistant._model_from_world())
	_ok(bool(report["ok"]) and int(report.get("pieces", 0)) == 1,
		"...the model holding as one: %s" % report["summary"])
	said = _text_of(await assistant.surface_review())
	_ok(_ground_findings() == 1, "a second review proposes no ground cut there (%d in all)"
		% _ground_findings())

	print("\na 16 x 16 plate with a small hut on it")
	await _build("hut", _hut_on_plate())
	said = _text_of(await assistant.surface_review())
	cut = _finding("ground")
	laid = _laid_by(cut)
	var plate: BrickWorld.Brick = laid[0] if laid.size() == 1 else null
	var plate_foot: Vector2i = (library.parts[plate.part_id] as PartLibrary.PartInfo
		).footprint_studs() if plate != null else Vector2i.ZERO
	_ok(cut != null and _brick_of("91405") == 0 and plate != null
		and (library.parts[plate.part_id] as PartLibrary.PartInfo).family_category() == "Plate"
		and plate_foot.x * plate_foot.y <= 36,
		"the 16 x 16 is laid again as a plate the hut's size and a stud round: %s (%d x %d)" % [
			plate.part_id if plate != null else "none", plate_foot.x, plate_foot.y])
	var accepted: String = await assistant.use_tool("settle_surface", {"finding": cut.key
		if cut != null else "S1", "verdict": "accept"})
	_ok(accepted.contains("accepted"), "...and accepted: %s" % accepted.substr(0, 120))
	report = await assistant._check(assistant._model_from_world())
	_ok(bool(report["ok"]) and int(report.get("pieces", 0)) == 1,
		"...the hut holding as one: %s" % report["summary"])
	_ok(assistant.surface_pass().record().contains("ground part cut back"),
		"the record counts it: %s" % assistant.surface_pass().record())

	print("\na plinth tiled but for a thin edge is left as it is")
	await _build("plinth", _plinth())
	await assistant.surface_review()
	_ok(_ground_findings() == 0, "no ground finding on the plinth (%d)" % _ground_findings())

	print("\na ground part with nothing on it, loose beside the model, comes off")
	await _build("loose", _loose_plate())
	var pieces_before: int = int((await assistant._check(assistant._model_from_world())).get(
		"pieces", 0))
	said = _text_of(await assistant.surface_review())
	cut = _finding("ground")
	_ok(cut != null and cut.add.is_empty() and _brick_of("41539") == 0,
		"the loose 8 x 8 is taken off: %s" % (cut.laid if cut != null else "no finding"))
	accepted = await assistant.use_tool("settle_surface", {"finding": cut.key
		if cut != null else "S1", "verdict": "accept"})
	report = await assistant._check(assistant._model_from_world())
	_ok(int(report.get("pieces", 0)) < pieces_before,
		"...the model in %d pieces, from %d" % [int(report.get("pieces", 0)), pieces_before])
	_ok(accepted.contains("accepted"), "...and it settles: %s" % accepted.substr(0, 120))

	print("\na cut never opens a hole inside the ground")
	var ground: Dictionary = {}
	for x: int in range(1, 24, 2):
		for z: int in range(1, 24, 2):
			ground[Vector2i(x, z)] = true
	var inner: Dictionary = {}
	for x: int in range(9, 16, 2):
		for z: int in range(9, 16, 2):
			inner[Vector2i(x, z)] = true
	var outside: Dictionary = SurfacePass._outside_of(ground, inner)
	_ok(not outside.has(Vector2i(11, 11)), "a cut in the ground's middle is not reached from outside")
	var edge: Dictionary = {}
	for x: int in range(1, 24, 2):
		for z: int in range(17, 24, 2):
			edge[Vector2i(x, z)] = true
	outside = SurfacePass._outside_of(ground, edge)
	_ok(outside.has(Vector2i(11, 19)) and outside.has(Vector2i(11, 17)),
		"...and a cut out to its edge is")

	print("\n%s" % ("ground_cut_probe: all passed" if _failures == 0
		else "ground_cut_probe: %d failed" % _failures))
	quit(0 if _failures == 0 else 1)


## A 32 x 32 baseplate with a 2 x 2 column and a 4 x 4 roof in one corner.
func _corner_house() -> Array:
	var out: Array = [{"part": "3811", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0}]
	for x: int in [2, 4]:
		for z: int in [2, 4]:
			for course: int in 3:
				out.append({"part": "3003", "color": 15, "x": x, "y": 0.5 + course * 3, "z": z,
					"rot": 0})
	out.append({"part": "3031", "color": 4, "x": 2, "y": 9.5, "z": 2, "rot": 0})
	return out


## A 16 x 16 plate with a 4 x 4 hut of 2 x 2 bricks at its middle.
func _hut_on_plate() -> Array:
	var out: Array = [{"part": "91405", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0}]
	for x: int in [6, 8]:
		for z: int in [6, 8]:
			for course: int in 2:
				out.append({"part": "3003", "color": 19, "x": x, "y": 1 + course * 3, "z": z,
					"rot": 0})
	out.append({"part": "3031", "color": 70, "x": 6, "y": 7, "z": 6, "rot": 0})
	return out


## A black 16 x 16 plate, its top tiled but for the outer row, and a tower.
func _plinth() -> Array:
	var out: Array = [{"part": "91405", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0}]
	for x: int in range(1, 15, 2):
		for z: int in range(1, 15, 2):
			if x == 7 and z == 7:
				continue
			out.append({"part": "3068b", "color": 72, "x": x, "y": 1, "z": z, "rot": 0})
	for course: int in 4:
		out.append({"part": "3003", "color": 15, "x": 7, "y": 1 + course * 3, "z": 7, "rot": 0})
	return out


## A house on a 6 x 8 plate, and beside it a bare 8 x 8 plate joined to nothing.
func _loose_plate() -> Array:
	var out: Array = [{"part": "3036", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0}]
	for x: int in [0, 2, 4, 6]:
		for z: int in [0, 4]:
			out.append({"part": "3003", "color": 15, "x": x, "y": 1, "z": z, "rot": 0})
	out.append({"part": "41539", "color": 2, "x": 10, "y": 0, "z": 0, "rot": 0})
	return out


# -- helpers -------------------------------------------------------------------


func _build(name: String, bricks: Array) -> void:
	assistant._busy = false
	world.clear()
	builder.lattice.clear()
	var built: Variant = await assistant.use_tool("submit_design", {"name": name,
		"description": "a fixture", "bricks": bricks, "features": []})
	if not str(built).begins_with("Built"):
		print("    the %s: %s" % [name, str(built).substr(0, 300)])


func _bricks() -> Array[BrickWorld.Brick]:
	return assistant._bricks_inside({})


func _brick_of(part: String) -> int:
	for brick: BrickWorld.Brick in _bricks():
		if brick.part_id == part:
			return brick.id
	return 0


## Where each brick of [param part] stands, by its origin, as a set of strings.
func _where_all(part: String) -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _bricks():
		if brick.part_id == part:
			out[str(brick.transform.origin.snapped(Vector3.ONE * 0.1))] = true
	return out


## The top of a part's studs, LDU.
func _top_of(id: int) -> float:
	var brick: BrickWorld.Brick = world.get_brick(id)
	if brick == null:
		return -INF
	return (brick.transform * library.mesh_for(brick.part_id).bounds).abs().end.y


func _open_on(id: int) -> int:
	var ids: Array = []
	for brick: BrickWorld.Brick in _bricks():
		ids.append(brick.id)
	var n: int = 0
	for point: OpenPoints.Point in OpenPoints.read(assistant).points_of(ids):
		if point.kind == "stud" and point.by == 0 and point.way.dot(Vector3.UP) > 0.9 \
				and point.brick == id:
			n += 1
	return n


func _finding(kind: String) -> SurfacePass.Finding:
	var found: SurfacePass.Finding = null
	for one: SurfacePass.Finding in assistant.surface_pass().findings:
		if one.kind == kind:
			found = one
	return found


func _ground_findings() -> int:
	var n: int = 0
	for one: SurfacePass.Finding in assistant.surface_pass().findings:
		if one.kind == "ground":
			n += 1
	return n


func _laid_by(one: SurfacePass.Finding) -> Array:
	var out: Array = []
	if one == null:
		return out
	for id: int in one.ids:
		var brick: BrickWorld.Brick = world.get_brick(id)
		if brick != null:
			out.append(brick)
	return out


func _text_of(message: Variant) -> String:
	if message is String:
		return message
	var said := PackedStringArray()
	if message is Array:
		for block: Variant in message:
			var one: Dictionary = block
			if one.get("type", "") == "text":
				said.append(str(one.get("text", "")))
	return "\n".join(said)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
