## Is a model in as many pieces as it really is?
##
##   godot --headless --path . --script src/dev/pieces_probe.gd
##
## The check counts the pieces a model falls into, to tell a builder and
## Claude that something is floating ("in 4 pieces"), and the bench scores a
## build by it. It joined parts by studs, pins, clips and hinges and by what
## sits on a part's top, so a part held otherwise was a piece of its own: a
## sticker on an upright face (the sides round's locomotive, 4 pieces for two
## cab plates) and every braid of a string laid with lay_flex (its sailing
## ship, 64 pieces for its rigging). Each case is built in the real scene, the
## sticker put on with print_part and the string laid with lay_flex as a
## session over MCP does, and asked of every place that counts: the design
## check (check_design, review_model, the bench's candidate_probe), the check
## an edit gets of what it leaves hanging, Tools, Check stability's balance,
## and the status bar's "stands up". The string is one piece as lay_flex lays
## it and with its pieces loose in the model, as most real sets' files have
## their hoses; two magnets touching are one piece, and a stud apart two. A
## brick in the air is still a piece of its own, and a sticker stuck to
## nothing. And a car with its driver in it is a car, not "a figure apart"
## from the car beside it that nothing couples, as the locomotive was from
## its tender; a figure on its own still stands apart, named.
extends SceneTree

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _assistant: Assistant
var _shell: Shell
var _next: int = 0

const RED := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 80 24'><rect width='80' height='24' fill='#c00'/><rect x='10' y='6' width='60' height='12' fill='#fff'/></svg>"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_assistant = _main.get("_assistant")
	_shell = _main.get("_shell")
	_socket = CommandSocket.new()
	_socket.assistant = _assistant
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame

	await _sticker_on_a_wall()
	await _rigging()
	await _coupled()
	await _with_a_driver()
	await _in_the_air()
	print("pieces probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _sticker_on_a_wall() -> void:
	print("── a sticker on an upright face of a brick wall ──")
	_main.call("clear_model")
	var left: int = _put("3001", 0, 0, 0)
	_put("3001", 80, 0, 0)
	_put("3001", 40, 24, 0)
	await _say_counts("the wall alone", 1, 0)
	var said: String = await _say("print_part", {"brick": left, "sticker": true, "side": "+z",
		"span": false, "svg": RED, "name": "Cab plate"})
	var sticker: int = _newest()
	_check("print_part sticks a sticker on the wall's +z face: %s" % said.left(90),
		sticker != 0 and Stickers.is_sticker(_library, _world.get_brick(sticker).part_id))
	_check("...which stands upright on it, its face looking along +z",
		sticker != 0 and _world.get_brick(sticker).transform.basis.y.normalized().dot(Vector3.BACK) > 0.99)
	# The booklet asks what it is stuck to by the same points the check
	# holds it by: the brick it covers most, first (the baseplate's studs
	# reach up behind its bottom edge too).
	var on: PackedInt64Array = Stickers.stuck_to(_world, _library, sticker)
	_check("...and the booklet has it stuck to the brick it is on, #%d, first: %s" % [left, on],
		not on.is_empty() and on[0] == left)
	await _say_counts("the wall with a sticker of ours on its side", 1, 0)
	# And one LDraw files as a Sticker, stuck the same way on the other side.
	var theirs: String = _an_ldraw_sticker()
	if theirs.is_empty():
		_check("an LDraw sticker the library has the shape of", false)
		return
	var back: Stickers.Face = Stickers.face_at(_world, _library, Vector3(0, 12, -40),
		Vector3.BACK, false)
	var stuck: int = _builder.put_part(theirs, 15, back.transform()) if back != null else 0
	_check("LDraw's sticker %s stuck on the wall's -z face" % theirs, stuck != 0)
	await _say_counts("...and one of LDraw's on its back", 1, 0)
	# A sticker stuck to nothing, held up in the air, is still a piece.
	_builder.put_part(theirs, 15, Transform3D(Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN),
		Vector3(0, 300, 200)))
	await _say_counts("...and a sticker held in the air, touching nothing", 2, 1, false)


func _rigging() -> void:
	print("── a rigging string between two masts on a hull ──")
	_main.call("clear_model")
	_put("3034", 0, 0, 0)
	var tops: Array[int] = []
	for x: float in [-70.0, 70.0]:
		var top: int = 0
		for course: int in 3:
			top = _put("3005", x, 8.0 + 24.0 * course, -10)
		tops.append(top)
	await _say_counts("the hull and its two masts", 1, 0)
	var said: String = await _say("lay_flex", {"kind": "string",
		"from": {"brick": tops[0]}, "to": {"brick": tops[1]}})
	var items: Dictionary = Flex.items_in(_world)
	var braids: int = 0
	for path: String in items:
		braids = (items[path]["bricks"] as Array).size()
	_check("lay_flex lays a string from one mast's top to the other's: %s" % said.left(90),
		said.begins_with("Laid") and items.size() == 1 and braids > 3)
	await _say_counts("the rigging with the hull, %d pieces of string" % braids, 1, 0)
	# Its far end let go: the mast's top course taken off from under it.
	_builder.take_off(tops[1])
	await _say_counts("the same string, its far end free, hanging from the near mast", 1, 0)
	# And its braids loose in the model, in no item of their own, as most of
	# the LDraw model repository's sets have their hoses: one with the next
	# where they touch.
	for path: String in items:
		for brick: BrickWorld.Brick in items[path]["bricks"]:
			if _world.get_brick(brick.id) != null:
				brick.unit = ""
				brick.group = ""
	_check("...its pieces now in no item", Flex.items_in(_world).is_empty())
	await _say_counts("...the same braids loose in the model", 1, 0)


func _coupled() -> void:
	print("── two cars coupled by their magnets ──")
	_main.call("clear_model")
	var magnet: String = ""
	for id: String in ["2609dc01", "2609bc01", "30159bc01", "2607bc01"]:
		if _library.parts.has(id) and _library.mesh_for(id) != null:
			magnet = id
			break
	if magnet.is_empty():
		_check("a magnet the library has the shape of", false)
		return
	var one: int = _put(magnet, 0, 0, 0)
	var first: AABB = _world.get_brick(one).transform * _library.mesh_for(magnet).bounds
	# The second turned round, its end against the first one's end.
	var turned := Basis(Vector3.UP, PI)
	var own: AABB = Transform3D(turned, Vector3.ZERO) * _library.mesh_for(magnet).bounds
	var place: Callable = func(gap: float) -> int:
		var at := Transform3D(turned, Vector3(roundf(first.end.x + gap - own.position.x),
			roundf(first.position.y - own.position.y), roundf(first.get_center().z - own.get_center().z)))
		var id: int = _world.add_brick(magnet, 0, at)
		_builder.register(id, magnet, at)
		return id
	var two: int = place.call(0.0)
	await _say_counts("two %s end to end, touching" % magnet, 1, 0)
	_builder.take_off(two)
	place.call(20.0)
	await _say_counts("...and a stud apart, touching nothing", 2, 0)


## The sides round's locomotive: its driver stands in its cab, and nothing
## couples its tender to it. The two are two pieces, and the one with the
## driver in it is a locomotive, not a figure standing apart.
func _with_a_driver() -> void:
	print("── a car with its driver, and a bigger car beside it that nothing couples ──")
	_main.call("clear_model")
	_put("3034", 0, 0, 0)
	var said: String = await _say("add_minifig", {"name": "Driver", "x": 0, "z": 0})
	_check("add_minifig stands a driver on the first car: %s" % said.left(80),
		said.to_lower().contains("driver") and not said.begins_with("No"))
	for x: float in [-70.0, -50.0, -30.0, -10.0, 10.0, 30.0, 50.0, 70.0]:
		for z: float in [-10.0, 10.0]:
			if z > 0.0 and (x == 10.0 or x == 30.0):
				continue
			_put("3024", x, 8, z)
	_put("3034", 160, 0, 0)
	for x: float in [90.0, 110.0, 130.0, 150.0, 170.0, 190.0, 210.0, 230.0]:
		for z: float in [-10.0, 10.0]:
			_put("3005", x, 8, z)
			_put("3024", x, 32, z)
	await _apart("the car with its driver against the bigger car", 2, 0)
	await _say("add_minifig", {"name": "Walker", "x": 20, "z": 10})
	await _apart("...and a figure on the ground well away from both", 3, 1)


## The check's pieces, and how many of them it lets stand apart (a named
## item or a figure): what candidate_probe passes on, pieces less those.
func _apart(what: String, pieces: int, named: int) -> void:
	var model: Assistant.Model = _assistant._model_from_world()
	for placement: Assistant.Placement in model.placements:
		placement.mine = true
	var report: Dictionary = _assistant._check(model, true)
	_check("%s: %d pieces, %d let stand apart (%d figures), wanted %d and %d (%s)" % [what,
		int(report["pieces"]), int(report["named"]), int(report["figures"]), pieces, named,
		report["summary"]], int(report["pieces"]) == pieces and int(report["named"]) == named)


func _in_the_air() -> void:
	print("── a brick floating in the air ──")
	_main.call("clear_model")
	_put("3001", 0, 0, 0)
	_put("3001", 0, 200, 200)
	await _say_counts("a brick on the ground and one in the air", 2, 1, false)


## What every place that counts says of the model as it stands: [param
## pieces] for the check, [param hanging] parts an edit's check finds held
## up by nothing, the balance's parts adrift (as many), and the status bar's
## "stands up" when [param stands]. A part in the air makes the rest lean
## in the status bar's reckoning, which is its own question.
func _say_counts(what: String, pieces: int, hanging: int, stands: bool = true) -> void:
	var model: Assistant.Model = _assistant._model_from_world()
	# As the bench's candidate_probe and review_model judge it.
	for placement: Assistant.Placement in model.placements:
		placement.mine = true
	var report: Dictionary = _assistant._check(model, true)
	_check("%s: the check says %d piece%s (%s), wanted %d" % [what, int(report["pieces"]),
		"" if int(report["pieces"]) == 1 else "s", report["summary"], pieces],
		int(report["pieces"]) == pieces)
	# What an edit's check asks of what it leaves: held from the ground alone.
	_assistant._ground_only = true
	var ground: Dictionary = _assistant._check(_assistant._model_from_world(), true)
	_assistant._ground_only = false
	_check("...an edit's check finds %d part%s held up by nothing, wanted %d" % [
		(ground["floating"] as Array).size(),
		"" if (ground["floating"] as Array).size() == 1 else "s", hanging],
		(ground["floating"] as Array).size() == hanging)
	var balance: Balance.Report = await _shell.weigh_balance(null, false)
	_check("...Check stability's balance has %d adrift, wanted %d" % [
		balance.adrift if balance != null else -1, hanging],
		balance != null and balance.adrift == hanging)
	var stability: Stability = _main.get("_stability")
	stability.floor_ids = _store.scenery
	var line: String = stability.check(_world).summary()
	if stands:
		_check("...and the status bar says \"%s\"" % line, line.begins_with("stands up"))
	else:
		print("        the status bar says \"%s\"" % line)


## The first part LDraw files as a Sticker that is flat and has a shape here.
func _an_ldraw_sticker() -> String:
	var ids: Array = _library.parts.keys()
	ids.sort()
	for id: String in ids:
		var info: PartLibrary.PartInfo = _library.parts[id]
		if info.category != "Sticker" or id.begins_with("bw-") or info.name.contains("Formed") \
				or info.size.x < 20.0 or info.size.z < 10.0 or info.size.y > 1.0:
			continue
		var mesh: Lbm.PartMesh = _library.mesh_for(id)
		if mesh != null and mesh.bounds.size.x <= 40.0 and mesh.bounds.size.z <= 20.0:
			return id
	return ""


## A part with its footprint's middle at x, z and its body's bottom at
## [param bottom], square to the grid.
func _put(part_id: String, x: float, bottom: float, z: float) -> int:
	var part: Lbm.PartMesh = _library.mesh_for(part_id)
	var box: AABB = part.bounds.abs()
	var middle: Vector3 = box.get_center()
	var at := Transform3D(Basis.IDENTITY, Vector3(roundf(x - middle.x),
		roundf(bottom - box.position.y), roundf(z - middle.z)))
	var id: int = _world.add_brick(part_id, 4, at)
	_builder.register(id, part_id, at)
	return id


func _newest() -> int:
	var most: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		most = maxi(most, brick.id)
	return most


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


## A tool's answer as text, called as the connector calls it: a job's
## answer once it ends, when the call answered with a job.
func _say(tool: String, arguments: Dictionary) -> String:
	var said: String = _text(await _rpc("tools/call", {"name": tool, "arguments": arguments}))
	var job: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(said)
	if job == null:
		return said
	for _n: int in 90:
		said = _text(await _rpc("tools/call", {"name": "job",
			"arguments": {"id": int(job.get_string(1))}}))
		if not said.contains(" is still going"):
			return said
	return "job %s never ended" % job.get_string(1)


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text
