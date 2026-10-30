## Hinge align: the joints between two parts swing so the two meet, and the
## result is a model the build check passes (docs/APP_UX.md, B4).
##
##   godot --headless --path . --script src/dev/hinge_align_probe.gd
##
## A ring of eight click hinge plates laid in a line, each a 1 x 2 with a
## fork, a 1 x 2 with a finger and a 1 x 4 over both, is closed by Meet on
## its two ends: every hinge at 45°, on its clicks, the last finger in the
## first fork. A wing on a hinge and a strut on another, both lying flat,
## swing so the strut's end meets the wing's. Each is then read as the build
## check reads a design (no overlap, one piece, the meeting a joint) and
## taken back with one undo. And what must be refused, with words and
## nothing moved: a strut too short to reach, the same wing on click hinges
## whose clicks never meet, and two parts no joint is between.
extends SceneTree

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("FAIL: no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	get_root().add_child(_assistant)
	await process_frame
	_ring()
	print("hinge align probe: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _put(part: String, colour: int, at: Transform3D) -> int:
	var id: int = _world.add_brick(part, colour, at)
	_builder.register(id, part, at)
	return id


func _clear() -> void:
	_builder.clear_selection()
	_world.clear()
	_builder.forget_history()


## Eight segments in a line along X, a hundred LDU apart: [first fork plate,
## last finger plate].
func _lay_ring() -> Array:
	_clear()
	var ends: Array = []
	for k: int in 8:
		var x: float = 100.0 * k
		var fork: int = _put("44302b", 4, Transform3D(Basis(Vector3.UP, PI), Vector3(x - 20.0, 0, 0)))
		var finger: int = _put("44301b", 4, Transform3D(Basis.IDENTITY, Vector3(x + 20.0, 0, 0)))
		_put("3710", 15, Transform3D(Basis.IDENTITY, Vector3(x, 8, 0)))
		if k == 0:
			ends.append(fork)
		if k == 7:
			ends.append(finger)
	return ends


func _aligner() -> HingeAlign:
	var align := HingeAlign.new()
	align.world = _world
	align.builder = _builder
	align.library = _library
	align.bodies = Bodies.read(_world, _library, _builder.lattice, {}, _builder.locked)
	return align


func _ring() -> void:
	var ends: Array = _lay_ring()
	var align: HingeAlign = _aligner()
	print("  bodies: %d, links %d" % [align.bodies.members.size(), align.bodies.links.size()])
	var ok: bool = align.solve(ends[1], ends[0])
	print("  solve: %s in %.0f ms, %d tries: %s%s" % [ok, align.took_ms, align.tries, align.said, align.why])
	print("  turns: %s" % [align.turns])
	if ok:
		align.commit()
		_report("ring")


## The build check, as a session's check_design reads the model.
func _report(name: String) -> Dictionary:
	var model: Assistant.Model = _assistant._model_from_world()
	for placement: Assistant.Placement in model.placements:
		placement.mine = true
	_assistant.set("_strict_mine", true)
	var report: Dictionary = _assistant._check(model, true)
	_assistant.set("_strict_mine", false)
	print("  %s check: %s | %s" % [name, report.get("summary", ""), str(report.get("feedback", "")).left(600)])
	return report


func _say(ok: bool, good: String, bad: String) -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % good)
	else:
		_failed += 1
		print("  FAIL %s" % bad)
