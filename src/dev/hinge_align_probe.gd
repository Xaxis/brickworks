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
	_wing()
	_refusals()
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


## [param count] segments in a line along X, a hundred LDU apart: [first
## fork plate, last finger plate].
func _lay_ring(count: int = 8) -> Array:
	_clear()
	var ends: Array = []
	for k: int in count:
		var x: float = 100.0 * k
		var fork: int = _put("44302b", 4, Transform3D(Basis(Vector3.UP, PI), Vector3(x - 20.0, 0, 0)))
		var finger: int = _put("44301b", 4, Transform3D(Basis.IDENTITY, Vector3(x + 20.0, 0, 0)))
		_put("3710", 15, Transform3D(Basis.IDENTITY, Vector3(x, 8, 0)))
		if k == 0:
			ends.append(fork)
		if k == count - 1:
			ends.append(finger)
	return ends


func _aligner() -> HingeAlign:
	var align := HingeAlign.new()
	align.world = _world
	align.builder = _builder
	align.library = _library
	align.bodies = Bodies.read(_world, _library, _builder.lattice, {}, _builder.locked)
	return align


func _where() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


func _moved_from(rest: Dictionary) -> int:
	var moved: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not Grab._same(brick.transform, rest[brick.id]):
			moved += 1
	return moved


## The ring of eight: Meet on its two ends closes it, every hinge 45° and on
## its clicks, the last finger in the first fork, the check passing; one
## undo takes it all back.
func _ring() -> void:
	var ends: Array = _lay_ring()
	var rest: Dictionary = _where()
	var align: HingeAlign = _aligner()
	_say(align.bodies.links.size() == 7, "the ring laid straight is 8 bodies on 7 click hinges",
		"the ring laid straight: %d links" % align.bodies.links.size())
	var ok: bool = align.solve(ends[1], ends[0])
	_say(ok, "ring: %s (%.0f ms, %d starts)" % [align.said, align.took_ms, align.tries],
		"ring: %s" % align.why)
	if not ok:
		return
	var square: bool = align.turns.size() == 7
	for turn: float in align.turns:
		square = square and absf(absf(turn) - 45.0) < 0.01
	_say(square, "ring: every hinge at 45°, two clicks: %s" % [align.turns],
		"ring: hinges at %s" % [align.turns])
	var depth: int = _builder.history_depth()
	var moved: int = align.commit()
	_say(moved == 21 and _builder.history_depth() == depth + 1,
		"ring: 21 of 24 parts swung, one step to undo",
		"ring: %d moved, history %d -> %d" % [moved, depth, _builder.history_depth()])
	_joined(ends[1], ends[0], "ring: the last plate's finger is in the first plate's fork")
	_passes("ring")
	_builder.undo()
	_say(_moved_from(rest) == 0, "ring: one undo puts all 24 parts back",
		"ring: %d parts not back after one undo" % _moved_from(rest))


## The wing and its strut: Meet on the strut's end and the wing's swings both
## hinges, and the strut's end is in the wing's.
func _wing() -> void:
	var ends: Array = _lay_wing(0)
	var align: HingeAlign = _aligner()
	var ok: bool = align.solve(ends[0], ends[1])
	_say(ok and align.turns.size() == 2 and absf(align.turns[0]) > 1.0 and absf(align.turns[1]) > 1.0,
		"wing: %s (%.0f ms)" % [align.said, align.took_ms], "wing: %s %s %s" % [align.said,
			align.why, align.turns])
	if not ok:
		return
	align.commit()
	_joined(ends[0], ends[1], "wing: the strut's hinge brick holds the wing's hinge top")
	_passes("wing")


## What must be refused, nothing moving: each with its words.
func _refusals() -> void:
	# The strut reaching 7 studs: further than the wing's hinge is from its own.
	var ends: Array = _lay_wing(0, 140.0)
	_refused(ends[0], ends[1], "a strut too long to meet the wing", "nearest leaves them")
	# Seven segments: 360° is no whole number of 22.5° clicks shared seven ways
	# that closes (seven sixteenths-of-a-turn steps never sum to nothing).
	ends = _lay_ring(7)
	_refused(ends[1], ends[0], "a ring of seven click hinges", "between the hinges' clicks")
	_clear()
	var one: int = _put("3020", 4, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)))
	var other: int = _put("3020", 4, Transform3D(Basis.IDENTITY, Vector3(200, 0, 0)))
	_refused(one, other, "two plates nothing joins", "not joined")
	var above: int = _put("3020", 1, Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
	_refused(one, above, "a plate and the plate on its studs", "held as one")


func _refused(one: int, other: int, name: String, words: String) -> void:
	var rest: Dictionary = _where()
	var depth: int = _builder.history_depth()
	var align: HingeAlign = _aligner()
	var ok: bool = align.solve(one, other)
	_say(not ok and align.why.contains(words) and _moved_from(rest) == 0
		and _builder.history_depth() == depth,
		"%s: refused, nothing moved: \"%s\"" % [name, align.why],
		"%s: solved %s, said \"%s%s\", %d moved" % [name, ok, align.said, align.why, _moved_from(rest)])


## Whether [param one] and [param other] are joined by a round joint, as the
## build check and Bodies read one: a finger in a fork, a pin in its eye.
func _joined(one: int, other: int, name: String) -> void:
	var entries: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		entries.append([brick.id, brick.transform, _library.mesh_for(brick.part_id)])
	var held: Dictionary = Joints.rounds(entries)
	var bodies: Bodies = Bodies.read(_world, _library, _builder.lattice, {}, _builder.locked)
	_say((held.get(one, {}) as Dictionary).has(other) and not bodies.closing.is_empty(),
		"%s (the model now a closed loop of %d joints)" % [name, bodies.links.size()],
		"%s: not joined (%d closing links)" % [name, bodies.closing.size()])


const TURN := Basis(Vector3.UP, PI * 0.5)


## A body with a wing on a hinge (1 x 2 hinge brick and top) above it and a
## strut on another under it, both flat; the wing's end has a hinge top under
## it, the strut's a hinge brick on it. [param flips]' bits turn the wing's
## root, the strut's root and the two ends half round, which way each opens.
## Returns [the strut's end, the wing's end].
func _lay_wing(flips: int, strut_reach: float = 100.0) -> Array:
	_clear()
	var wing_root := Basis(Vector3.UP, PI) if flips & 1 else Basis.IDENTITY
	var strut_root := Basis(Vector3.UP, PI) if flips & 2 else Basis.IDENTITY
	var ends := Basis(Vector3.UP, PI) if flips & 4 else Basis.IDENTITY
	_put("3020", 7, Transform3D(TURN, Vector3(0, 0, 0)))
	_put("3937", 7, Transform3D(wing_root, Vector3(0, 24, 30)))
	_put("3938", 7, Transform3D(wing_root, Vector3(0, 24, 30)))
	_put("3020", 1, Transform3D(TURN, Vector3(0, 32, 60)))
	var wing_end: int = _put("3938", 1, Transform3D(ends, Vector3(0, 24, 90)))
	_put("3938", 7, Transform3D(strut_root, Vector3(0, -8, -10)))
	_put("3937", 14, Transform3D(strut_root, Vector3(0, -8, -10)))
	var plate: String = "3795" if strut_reach <= 100.0 else "3034"
	var long: float = 120.0 if strut_reach <= 100.0 else 160.0
	_put(plate, 14, Transform3D(TURN, Vector3(0, -32, -20.0 + long * 0.5)))
	var strut_end: int = _put("3937", 14, Transform3D(ends, Vector3(0, -8, -10.0 + strut_reach)))
	return [strut_end, wing_end]


## The build check, as a session's check_design reads the model: buildable,
## one piece, nothing overlapping by its cover or its real shape.
func _passes(name: String) -> void:
	var model: Assistant.Model = _assistant._model_from_world()
	for placement: Assistant.Placement in model.placements:
		placement.mine = true
	_assistant.set("_strict_mine", true)
	var report: Dictionary = _assistant._check(model, true)
	_assistant.set("_strict_mine", false)
	var collisions: Array = (report.get("exact", {}) as Dictionary).get("collision", [])
	_say(bool(report.get("ok", false)) and int(report.get("pieces", 0)) == 1
		and (report.get("overlapping", {}) as Dictionary).is_empty() and collisions.is_empty(),
		"%s: the build check passes: %s, %d piece, no overlap" % [name, report.get("summary", ""),
			int(report.get("pieces", 0))],
		"%s: the build check: %s, %s pieces; %s" % [name, report.get("summary", ""),
			report.get("pieces", "?"), str(report.get("feedback", "")).left(400)])


func _say(ok: bool, good: String, bad: String) -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % good)
	else:
		_failed += 1
		print("  FAIL %s" % bad)
