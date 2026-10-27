## A body built on real joints passes the build check, as real sets do.
##
##   godot --headless --path . --script src/dev/joint_check_probe.gd
##
## The check by real shapes (ExactCheck) refused every pair whose BrickNet
## pieces overlap by more than 1 LDU, and a socket's mouth, a clip's jaws and a
## hinge's knuckles are pieces that a seated ball, bar or pin goes into: real
## sets' jointed parts came back as collisions (docs/DESIGN_SCORES.md,
## "Technique: joints held by their real shapes"). Each case below is two parts of a real set as the set's
## file has them, which collide by their shapes at the joint and must now pass;
## then a leg on Joint-8 ball plates as a session builds it; then what must
## still be refused: a Joint-8 joint turned past its socket's jaws (Shelob's
## legs, realset 2026-10-16), said as the joint it is, a ball pushed through
## its socket, a hinge folded into its base, and a real set's clip on its
## bar in a run kept to BrickBench's parts, whose verify.py forgives nothing.
## And a part BrickNet gives another part's shape, judged by its cover.
extends SceneTree

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _store: ModelStore
var _failed: int = 0
var _passed: int = 0

## name, the two parts as the set's file has them (where the check reads them),
## the joint's kind.
const REAL: Array = [
	["a Joint-8 ball in its socket (14417 in 14704, 31088's whale)",
		["1 72 -214.178 -138.006 -103.14 0.336 -0.174 0.925 0.059 0.985 0.163 -0.94 0 0.342 14417.dat",
		"1 71 -250.631 -144.169 -118.769 -0.28 -0.255 -0.925 -0.312 0.936 -0.163 0.907 0.243 -0.342 14704.dat"],
		"ball"],
	["a towball in a steering arm (6628 in 2739a, 10283)",
		["1 4 -304.232 -215.224 30.2 0.96 -0.28 0 -0.28 -0.96 0 0 0 -1 6628.dat",
		"1 72 -343.2687 -310.1955 20.3 -0.031952 0.960309 0.277438 -0.09459 -0.28009 0.955621 0.995 0.004 0.1 2739a.dat"],
		"ball"],
	["a clip on a bar (30377 on 60478's handle, 10315)",
		["1 4 220 -90 50 -1 0 0 0 1 0 0 0 -1 60478.dat",
		"1 4 170 -120.0559 50 0 0.759957 0.649973 0 0.649973 -0.759957 -1 0 0 30377.dat"],
		"clip"],
	["a universal joint turned 54 degrees (62519 in 62520, 10261)",
		["1 71 810 -1054 410 0 0 -1 1 0 0 0 -1 0 62520.dat",
		"1 71 810.046 -1054.114 412.614 0.588 -0.002 0.809 -0.071 -0.996 0.05 0.806 -0.087 -0.586 62519.dat"],
		"hinge"],
	["a lever turned square on its base (4593 on 4592, 10246)",
		["1 71 82 -378 290 0 -1 0 0 0 1 -1 0 0 4592.dat",
		"1 0 82 -378 290 0 0 -1 0 -1 0 -1 0 0 4593.dat"],
		"hinge"],
	["a Technic pin in its hole (2780 in 32531a, 10276)",
		["1 0 -80 -32 680 0 0 -1 0 1 0 1 0 0 32531a.dat",
		"1 0 -100 -22 640 0 0 1 0 1 0 -1 0 0 2780.dat"],
		"pin"],
]

## A Joint-8 plate's ball in the next one's socket, turned about the ball:
## 15 degrees sideways, as real sets turn it (21 at most), and 50, past where
## the socket's jaws meet the neck; and the next one pushed 5 LDU onto the
## ball, further off its socket's middle than BrickNet joins (3 LDU).
const TURNED_15 := ["1 72 0 -8 0 1 0 0 0 1 0 0 0 1 14419.dat",
	"1 72 -58.9778 -8 -7.7646 0.9659 0 -0.2588 0 1 0 0.2588 0 0.9659 14419.dat"]
const TURNED_50 := ["1 72 0 -8 0 1 0 0 0 1 0 0 0 1 14419.dat",
	"1 72 -49.2836 -8 -22.9813 0.6428 0 -0.766 0 1 0 0.766 0 0.6428 14419.dat"]
const OFF_ITS_SOCKET := ["1 72 0 -8 0 1 0 0 0 1 0 0 0 1 14419.dat",
	"1 72 -55 -8 0 1 0 0 0 1 0 0 0 1 14419.dat"]


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
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	if Exact.shape_for(_library, "14419") == null:
		print("joint check probe: SKIPPED — this build has no exact shapes (tools/build_exact.py "
			+ "writes assets/generated/exact/)")
		quit(0)
		return
	PartsOnly.use(PackedStringArray())

	for case: Array in REAL:
		_passes(str(case[0]), case[1], str(case[2]))
	_passes("a Joint-8 plate turned 15 degrees sideways in the next one's socket",
		TURNED_15, "")
	_leg()
	_refused("a Joint-8 plate turned 50 degrees sideways, past its socket's jaws",
		TURNED_50, ["14419"], "bent 50 degrees in its ball joint")
	_refused("a Joint-8 plate pushed 5 LDU onto the ball, off its socket", OFF_ITS_SOCKET,
		["14419"], "overlap")
	_hinge_folded()
	_stick()
	# A run kept to BrickBench's parts: verify.py forgives no overlap, joint or
	# not, so neither does the check.
	PartsOnly.use(PackedStringArray(["60478", "30377"]), "the probe's list")
	_refused("a clip on a bar (30377 on 60478's handle, 10315), in a run kept to BrickBench's parts",
		(REAL[2] as Array)[1], ["60478", "30377"], "overlap")
	PartsOnly.use(PackedStringArray())
	print("joint check probe: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The lines opened as a model, read back as a session's model is, and checked
## as review_model checks a whole design: every part this design's.
func _checked(lines: Array) -> Dictionary:
	var text: String = "0 probe\n" + "\n".join(PackedStringArray(lines)) + "\n"
	_store.open_text(text, "probe.ldr")
	var model: Assistant.Model = _assistant._model_from_world()
	for placement: Assistant.Placement in model.placements:
		placement.mine = true
	_assistant.set("_strict_mine", true)
	var report: Dictionary = _assistant._check(model, true)
	_assistant.set("_strict_mine", false)
	return report


## The two parts standing, by their exact shapes: the deepest overlap and the
## joint the check holds it to be.
func _between() -> Array:
	var items: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		var shape: Exact.Shape = Exact.shape_for(_library, brick.part_id)
		items.append(Exact.Item.new(shape, brick.transform) if shape != null else null)
	if items.size() != 2 or items[0] == null or items[1] == null:
		return [{}, ""]
	var exact := ExactCheck.new({}, 0)
	exact.items = items
	return [Exact.clash(items[0], items[1]), exact.at_joint(0, 1)]


func _passes(name: String, lines: Array, kind: String) -> void:
	var report: Dictionary = _checked(lines)
	var said: Array = (report.get("exact", {}) as Dictionary).get("collision", [])
	var shapes: Array = _between()
	var clash: Dictionary = shapes[0]
	if not kind.is_empty():
		# The case is worth asking only while the shapes do meet at the joint.
		_say(not clash.is_empty() and shapes[1] == kind,
			"%s: the shapes overlap %.1f LDU, at the %s" % [name, float(clash.get("depth", 0.0)), kind],
			"%s: shapes overlap %s, held to be at the joint '%s', not '%s'" % [name,
				clash.get("depth", "not at all"), shapes[1], kind])
	_say(said.is_empty(), "%s: passes, nothing collides" % name,
		"%s: refused: %s" % [name, "; ".join(PackedStringArray(said))])


func _refused(name: String, lines: Array, parts: Array, words: String) -> void:
	var report: Dictionary = _checked(lines)
	var said: Array = (report.get("exact", {}) as Dictionary).get("collision", [])
	var hit: String = ""
	for sentence: Variant in said:
		var s: String = str(sentence)
		if parts.all(func(p: String) -> bool: return s.contains(p)) and s.contains(words):
			hit = s
	_say(not hit.is_empty(), "%s: refused: %s" % [name, hit.left(300)],
		"%s: not refused with \"%s\" (said: %s; summary: %s)" % [name, words, said,
			report.get("summary", "")])


## A control stick on a plate as a session lays it, and with a brick in it.
## BrickNet gives 4592c01 73587p01's shape, moved 1.59 LDU down and 4.77 back
## (its newer stick and base, drawn otherwise), so the base stood 1.6 LDU in
## the plate under it where LDraw's own geometry is clear of it (13, 26, 27
## and 29 of the gallery's real sets). Another part's shape is no shape
## (Exact.own): the stick is judged by its cover, which still finds a brick
## stood inside it.
func _stick() -> void:
	_say(Exact.shape_for(_library, "4592c01") == null and Exact.shape_for(_library, "3020") != null,
		"a part BrickNet gives another part's shape (4592c01, 73587p01's moved) has none; a plate its own",
		"4592c01 has a shape: %s; 3020: %s" % [Exact.shape_for(_library, "4592c01"),
			Exact.shape_for(_library, "3020")])
	var on: Array = [{"part": "3020", "color": 7, "x": 0, "y": 0, "z": 0},
		{"part": "4592c01", "color": 0, "x": 0, "y": 1, "z": 0}]
	for inside: bool in [false, true]:
		_world.clear()
		var bricks: Array = on.duplicate()
		if inside:
			bricks.append({"part": "3005", "color": 4, "x": 0, "y": 1, "z": 0})
		var report: Dictionary = _assistant._check(_assistant._read_model({"bricks": bricks}), true)
		var said: String = str(report.get("feedback", ""))
		if inside:
			_say(said.contains("3005") and said.contains("overlaps"),
				"a brick stood inside the control stick is refused by its cover: %s" % said.strip_edges().left(160),
				"a brick inside the control stick: %s" % said.left(300))
		else:
			_say(str(report.get("summary", "")).ends_with("buildable"),
				"a control stick on a plate passes: %s" % report.get("summary", ""),
				"a control stick on a plate: %s" % said.left(300))


## A leg of Joint-8 plates as a session lays it (Shelob's first right leg,
## realset 2026-10-16, which bent each joint about 40 degrees, down and
## forward): the plates on a body, each on the last one's ball by attach.
func _leg() -> void:
	_world.clear()
	var model: Assistant.Model = _assistant._read_model({"bricks": [
		{"part": "3003", "color": 0, "x": 15, "y": 0, "z": 22},
		{"part": "3003", "color": 0, "x": 15, "y": 3, "z": 22},
		{"part": "3036", "color": 0, "x": 13, "y": 6, "z": 17, "rot": 1},
		{"part": "14417", "color": 72, "x": 18, "y": 6.5, "z": 23, "rot": 1, "name": "sR1"},
		{"part": "14419", "color": 72, "name": "fR1", "attach": {"to": "sR1.ball[0]",
			"by": "ball[1]", "align": ["-x", [0.75, 0.5, 0.4]]}},
		{"part": "14419", "color": 72, "name": "tR1", "attach": {"to": "fR1.ball[0]",
			"by": "ball[1]", "align": ["-x", [0.3, 0.35, 0.9]]}},
		{"part": "14419", "color": 72, "name": "pR1", "attach": {"to": "tR1.ball[0]",
			"by": "ball[1]", "align": ["-x", [0.1, -0.3, 0.95]]}}]})
	var report: Dictionary = _assistant._check(model, true)
	var said: Array = (report.get("exact", {}) as Dictionary).get("collision", [])
	_say(said.is_empty() and model.placements.size() == 7,
		"a leg of three Joint-8 plates on a body, each bent about 40 degrees: nothing collides",
		"a leg of Joint-8 plates: %d parts; %s" % [model.placements.size(),
			"; ".join(PackedStringArray(said))])


## A hinge laid by attach: opened 30 degrees it passes, folded the way it does
## not open it is refused as the hinge (as BrickAgent's own check refuses it).
func _hinge_folded() -> void:
	for yaw: int in [-30, 30]:
		_world.clear()
		var model: Assistant.Model = _assistant._read_model({"bricks": [
			{"part": "3937", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0, "name": "base"},
			{"part": "3938", "color": 4, "attach": {"to": "base.hinge[0]", "by": "hinge[0]",
				"yaw": yaw}}]})
		var report: Dictionary = _assistant._check(model, true)
		var said: Array = (report.get("exact", {}) as Dictionary).get("collision", [])
		if yaw < 0:
			_say(said.is_empty(), "a hinge opened 30 degrees: passes",
				"a hinge opened 30 degrees: refused: %s" % "; ".join(PackedStringArray(said)))
		else:
			_say(said.any(func(s: Variant) -> bool: return str(s).contains("hinge")),
				"the same hinge folded into its base: refused as the hinge",
				"the same hinge folded into its base: not refused as the hinge (said: %s)" % [said])


func _say(ok: bool, good: String, bad: String) -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % good)
	else:
		_failed += 1
		print("  FAIL %s" % bad)
