## A part that only touches another carries what stands on it, and nothing
## hangs from it or levers on it.
##
##   godot --headless --path . --script src/dev/touch_probe.gd
##
## walk180 (bench/results/walk180-2026-10-23/findings.md, item M10) asked a
## session what breaks first on a tug it built. Its 66 g forecastle hangs
## from the hull on 4 studs of a 2x8 plate, at 0.85 of their working load,
## and the check read it safe: the forecastle's ladder stands on the deck by
## two rails between the deck's studs, the lift counted that a stud, and a
## joint that shares its load is not weighed. The session found it by
## rebuilding the bow in check_design without the ladder; no tool read View,
## Stress. Here the tug as the session built it (tests/fixtures/stability/
## walk180_bow.json) reads that joint at 0.85 with the ladder and without, in
## check_design and View, Stress alike, amber. A plate lying on a tile on a
## column, out past it, falls off it: red, and a weak joint. A column of
## bricks pressed down stands, on studs and on a tile. The models that ship
## stand with nothing red. And in the app, the status bar's verdict, View,
## Stress and a session's weakest_joints say the same. Exits non-zero when
## an answer is wrong.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	await _the_bow()
	await _cantilever_on_a_touch()
	await _columns_pressed_down()
	await _models_stand()
	await _the_app_agrees()
	print("")
	if _failures == 0:
		print("touch: the tug's bow is weighed at 0.85 whatever touches it, a plate on a touch "
			+ "past it falls, a column pressed down stands, the shipped models stand, and the "
			+ "verdict, View, Stress and weakest_joints agree")
	else:
		print("touch: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- building ------------------------------------------------------------------


func _fresh() -> void:
	if _world != null:
		_world.queue_free()
		_builder.queue_free()
		await process_frame
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	await process_frame


## The walk180 tug's bricks, as the session gave them to check_design; less
## the ladder and the plate it hangs from, when [param ladder] is false.
static func _tug(ladder: bool) -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/stability/walk180_bow.json"))
	var bricks: Array = data["bricks"]
	if not ladder:
		bricks = bricks.filter(func(b: Dictionary) -> bool:
			return not (b["part"] == "4175" or (b["part"] == "3023b" and int(b["y"]) == 9)))
	return bricks


## A part with the middle of its footprint at [param x], [param z] and the
## bottom of its body at [param bottom], LDU; long along x. Returns its id.
func _put(part_id: String, x: float, bottom: float, z: float) -> int:
	var part: Lbm.PartMesh = _library.mesh_for(part_id)
	var info: PartLibrary.PartInfo = _library.parts.get(part_id)
	var basis := Basis.IDENTITY
	if info.size.x < info.size.z:
		basis = Basis(Vector3.UP, PI * 0.5)
	var box: AABB = (Transform3D(basis, Vector3.ZERO) * part.bounds).abs()
	var middle: Vector3 = box.get_center()
	var at := Transform3D(basis, Vector3(roundf(x - middle.x), roundf(bottom - box.position.y),
		roundf(z - middle.z)))
	var id: int = _world.add_brick(part_id, 4, at)
	_builder.register(id, part_id, at)
	return id


func _top(id: int) -> float:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var box: AABB = (brick.transform * part.bounds).abs()
	return box.end.y - (4.0 if _library.parts[brick.part_id].stud_count > 0 else 0.0)


## Five 2x2 bricks from [param bottom], their middle at x 0, z 0. Returns them.
func _column(bottom: float) -> Array:
	var out: Array = []
	var top: float = bottom
	for _n: int in 5:
		var id: int = _put("3003", 0, top, 0)
		out.append(id)
		top = _top(id)
	return out


func _weigh() -> Stability.Report:
	var judge := Stability.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	judge.with_margins = true
	return judge.check(_world)


func _view(report: Stability.Report) -> StressView:
	var view := StressView.new()
	view.world = _world
	view.library = _library
	view.set_on(true)
	view.show_report(report)
	return view


## The id of the one part [param part_id] in the world.
func _the(part_id: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part_id:
			return brick.id
	return 0


# -- the cases -------------------------------------------------------------------


## The tug, with its ladder and without: the joint under the forecastle
## weighed the same, as check_design and View, Stress weigh it.
func _the_bow() -> void:
	print("walk180's tug: its forecastle hung on 4 studs, its ladder standing on the deck")
	var ratios: Array = []
	for ladder: bool in [true, false]:
		await _fresh()
		var assistant := Assistant.new()
		assistant.library = _library
		assistant.world = _world
		assistant.builder = _builder
		get_root().add_child(assistant)
		await process_frame
		var model := Assistant.Model.new()
		for one: Dictionary in _tug(ladder):
			model.placements.append(Assistant.Placement.from_dict(one))
		var checked: Dictionary = assistant._check(model, false, true)
		var balance: Balance.Report = checked.get("balance")
		var said: String = balance.said(func(id: int) -> String:
			var placement: Assistant.Placement = model.placements[id - 1]
			return "brick %d (%s at %s)" % [id - 1, placement.part, placement.where()])
		var first: String = said.get_slice("Most loaded stud joints (1 N a stud working, 3 N lets go): ", 1)
		_check("%s: check_design names the forecastle's joint first: %s" % [
			"with the ladder" if ladder else "without it", first.get_slice(";", 0)],
			first.begins_with("brick 48 (3034 at 18,3,5) hanging from brick 30 (92438 at 4,4,2) on 4 studs"))
		for placement: Assistant.Placement in model.placements:
			var at: Transform3D = assistant._joined_at(placement, _library.mesh_for(placement.part), model)
			_builder.register(_world.add_brick(placement.part, placement.color, at), placement.part, at)
		var report: Stability.Report = _weigh()
		var plate: int = 0
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id == "3034":
				plate = brick.id
		var root: Balance.JointLoad = report.margins.get(plate)
		var view: StressView = _view(report)
		_check("...View, Stress weighs it: %s" % (view.words(plate) if root != null else "not weighed"),
			root != null and root.hangs and root.studs == 4 and root.held_part == "92438"
				and root.ratio > 0.8 and root.ratio < 0.95)
		_check("...and tints the forecastle amber, within twice its working load (margin %s)"
			% StressView.margin_words(view.margin_of(plate)),
			_world.stressed_ids().get(plate) == StressView.AMBER)
		if ladder:
			var judge := Stability.new()
			judge.library = _library
			judge.lattice = _builder.lattice
			var graph: Dictionary = judge.contacts(_world.bricks())
			var joints: Dictionary = Stability.stud_joints(graph, _library, _builder.lattice)
			var deck: int = 0
			for brick: BrickWorld.Brick in _world.bricks():
				if brick.part_id == "92438" and brick.color_code == 72:
					deck = brick.id
			var key: int = Stability.pair_of(_the("4175"), deck)
			_check("the ladder on the deck is a touch, joined by nothing: in studs %s, beside %s, the deck under it %s"
				% [joints["studs"].has(key), joints["beside"].has(key),
					int(joints["resting"].get(key, 0)) == deck],
				not joints["studs"].has(key) and joints["beside"].has(key)
					and int(joints["resting"].get(key, 0)) == deck)
		if root != null:
			ratios.append(root.ratio)
		view.free()
		assistant.queue_free()
	_check("the ladder shares nothing of the joint's load: %s with it, %s without" % [
		Balance.tidy(ratios[0]) if ratios.size() > 0 else "-", Balance.tidy(ratios[1]) if ratios.size() > 1 else "-"],
		ratios.size() == 2 and absf(float(ratios[0]) - float(ratios[1])) < 0.03)


## A 2x10 plate lying by its end on a 2x2 tile atop a column, out eight studs
## past it: held by no joint, its weight past where it touches. It falls.
## The column stands on a 2x10 plate under the arm, so the whole does not
## tip over and the touch is all there is to say.
func _cantilever_on_a_touch() -> void:
	print("a 2x10 plate lying on a tile on a column, out past it")
	await _fresh()
	var column: Array = _column(_top(_put("3832", 80, 0.0, 0)))
	var tile: int = _put("3068b", 0, _top(column[-1]), 0)
	var plate: int = _put("3832", 80, _top(tile), 0)
	var report: Stability.Report = _weigh()
	var view: StressView = _view(report)
	var kinds: Array = report.risks.map(func(risk: Stability.Risk) -> String: return risk.kind)
	_check("the verdict says it: %s (%s)" % [report.summary(), ", ".join(kinds)],
		kinds == ["rests on a touch"])
	_check("View, Stress tints it red and says why: \"%s\"" % view.words(plate),
		_world.stressed_ids().get(plate) == StressView.RED
			and view.words(plate).contains("stands on a touch alone"))
	_check("...and nothing under it is libelled: %d of %d tinted" % [_world.stressed_ids().size(),
		_world.brick_count()], _world.stressed_ids().size() == 1)
	view.free()
	# The same plate on the column's studs is a cantilever its studs hold.
	await _fresh()
	column = _column(_top(_put("3832", 80, 0.0, 0)))
	plate = _put("3832", 80, _top(column[-1]), 0)
	report = _weigh()
	view = _view(report)
	_check("on the column's studs instead, it is held: %s, margin %s" % [report.summary(),
		StressView.margin_words(view.margin_of(plate))], report.is_stable()
		and view.margin_of(plate) >= StressView.CLOSE)
	view.free()


## Five 2x2 bricks on a 4x4 plate with two 2x4 bricks on top, on their
## studs; and the same standing on a 2x2 tile, pressed down on a touch.
## Both stand.
func _columns_pressed_down() -> void:
	print("a column of bricks pressed down")
	await _fresh()
	var column: Array = _column(_top(_put("3031", 0, 0.0, 0)))
	var top: float = _top(column[-1])
	for _n: int in 2:
		top = _top(_put("3001", 0, top, 0))
	var report: Stability.Report = _weigh()
	var view: StressView = _view(report)
	_check("on its studs: %s, %d tinted" % [report.summary(), _world.stressed_ids().size()],
		report.is_stable() and _world.stressed_ids().is_empty())
	view.free()
	await _fresh()
	var tile: int = _put("3068b", 0, _top(_put("3031", 0, 0.0, 0)), 0)
	column = _column(_top(tile))
	top = _top(column[-1])
	for _n: int in 2:
		top = _top(_put("3001", 0, top, 0))
	report = _weigh()
	view = _view(report)
	_check("on a tile, the touch carrying it straight down: %s, %d tinted" % [report.summary(),
		_world.stressed_ids().size()], report.is_stable() and _world.stressed_ids().is_empty())
	_check("...its foot stands on the tile: \"%s\"" % view.words(column[0]),
		view.words(column[0]).contains("stands on what is under it"))
	view.free()


## The models that ship stand, and no part of them reads red or tips off.
func _models_stand() -> void:
	print("the shipped models")
	for name: String in ["house.ldr", "car.ldr", "lighthouse.ldr", "castle.ldr", "kart.ldr",
			"tower.ldr", "rocket.ldr", "station.ldr"]:
		await _fresh()
		var ldr: LdrModel = LdrModel.load_file("res://models/" + name)
		for piece: LdrModel.Placement in ldr.flatten():
			var part_id: String = piece.part_id.to_lower().trim_suffix(".dat")
			if _library.mesh_for(part_id) == null:
				continue
			var id: int = _world.add_brick(part_id, piece.color_code, piece.transform)
			if id != 0:
				_builder.register(id, part_id, piece.transform)
		var report: Stability.Report = _weigh()
		var view: StressView = _view(report)
		var red: Array = []
		for id: int in _world.stressed_ids():
			if _world.stressed_ids()[id] == StressView.RED:
				red.append(view.words(id))
		var weak: Array = report.risks.filter(func(risk: Stability.Risk) -> bool:
			return risk.kind in ["levered", "rests on a touch"])
		_check("%-14s %s, %d red%s" % [name, report.summary(), red.size(),
			"" if red.is_empty() else ": " + "; ".join(red)], red.is_empty() and weak.is_empty())
		view.free()


## In the app: the tug, then the plate on a touch, put down as a session
## puts them; the status bar's verdict, View, Stress and weakest_joints each
## say the same of them.
func _the_app_agrees() -> void:
	print("the app: the verdict, View, Stress and weakest_joints")
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	var socket := CommandSocket.new()
	socket.assistant = main.get("_assistant")
	socket.app = main
	main.add_child(socket)
	var world: BrickWorld = main.get("_world")
	var shell: Shell = main.get("_shell")
	var assistant: Assistant = main.get("_assistant")
	main.call("clear_model")
	await process_frame
	# Laid where check_design laid it, as the person's own parts: put down
	# with submit_design, the build check's faults would refuse the plate on
	# its touch below.
	_world.queue_free()
	_builder.queue_free()
	_world = world
	_builder = main.get("_builder")
	var model := Assistant.Model.new()
	for one: Dictionary in _tug(true):
		model.placements.append(Assistant.Placement.from_dict(one))
	for placement: Assistant.Placement in model.placements:
		var at: Transform3D = assistant._joined_at(placement, _library.mesh_for(placement.part), model)
		_builder.register(world.add_brick(placement.part, placement.color, at), placement.part, at)
	_check("the tug laid in the app: %d parts" % world.brick_count(), world.brick_count() > 80)
	var plate: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if brick.part_id == "3034":
			plate = brick.id
	var said: String = await _say(socket, "weakest_joints", {})
	var first: String = said.get_slice("the weakest:\n", 1).get_slice("\n", 0)
	_check("weakest_joints says the forecastle's joint first: %s" % first.strip_edges(),
		first.contains("#%d Plate 2 x 8 hangs from" % plate) and first.contains("on 4 studs")
			and first.contains("(0.8") and first.contains("amber"))
	var verdict: String = await _verdict(main)
	_check("the status bar's verdict: %s, as weakest_joints' first line: %s" % [verdict,
		said.get_slice("\n", 0)], not verdict.is_empty() and said.get_slice("\n", 0).contains(verdict))
	shell.stress.set_on(true)
	for _n: int in 400:
		await process_frame
		if shell.stress.report != null:
			break
	_check("View, Stress tints the forecastle amber: %s" % shell.stress.words(plate),
		world.stressed_ids().get(plate) == StressView.AMBER)
	said = await _say(socket, "weakest_joints", {"part": plate})
	_check("weakest_joints part= says what View, Stress says pointing at it: %s" % said.get_slice("\n", 1),
		said.contains(shell.stress.words(plate)))
	main.call("clear_model")
	await process_frame
	var column: Array = _column(_top(_put("3832", 80, 0.0, 0)))
	plate = _put("3832", 80, _top(_put("3068b", 0, _top(column[-1]), 0)), 0)
	said = await _say(socket, "weakest_joints", {})
	_check("on a touch past it, weakest_joints says it falls: %s" % said.get_slice("\n", 0),
		said.contains("(rests on a touch)") and said.contains("by touch alone") and said.contains("red"))
	verdict = await _verdict(main)
	_check("...the status bar says it: %s" % verdict, verdict.contains("rests on a touch"))
	for _n: int in 400:
		await process_frame
		if world.stressed_ids().get(plate) == StressView.RED:
			break
	_check("...and View, Stress tints it red: %s" % shell.stress.words(plate),
		world.stressed_ids().get(plate) == StressView.RED)
	shell.stress.set_on(false)
	_world = null
	main.queue_free()
	await process_frame


## The status bar's verdict, once it has weighed the model as it stands.
func _verdict(main: Node) -> String:
	var world: BrickWorld = main.get("_world")
	for _n: int in 600:
		await process_frame
		if int(main.get("_stability_revision")) == world.revision and not bool(main.get("_weighing")):
			break
	return str(main.get("_stability_text"))


func _say(socket: CommandSocket, tool: String, arguments: Dictionary) -> String:
	var answer: Variant = await socket.answer_rpc({"jsonrpc": "2.0", "id": 1,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	return text
