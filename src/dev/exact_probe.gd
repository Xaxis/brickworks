## The build check finds what BrickBench's verify.py refused in our designs.
##
##   godot --headless --path . --script src/dev/exact_probe.gd
##
## On 2026-10-14 verify.py refused 8 of our 10 BrickBench designs for 46
## pairs of parts whose real shapes overlap and for decorations resting with
## nothing holding them, every one of which our check had passed
## (docs/BRICKBENCH.md). Each case here is one kind of those pairs, the two
## parts as the design placed them (their LDraw lines, out of our designs'
## own model files), read as a session's model is (Assistant._model_from_world)
## and checked as review_model checks a whole design: every part this
## design's. Each must be named, with its fix, or seated exactly where the
## miss was a few LDU. Last, cases that must pass: the same parts put right,
## and a minifigure as add_minifig makes it.
##
## Before ExactCheck every case below failed: the check passed them all.
extends SceneTree

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _store: ModelStore
var _failed: int = 0
var _passed: int = 0

## name, LDraw lines, what must be said: {"collision": [part ids named] and
## words, "not held": [part], "seated": [part]}.
const CASES: Array = [
	["a side stud pushed into the next brick (11211 by 3003, model-008)",
		["1 71 -20 -192 -60 1 0 0 0 1 0 0 0 1 3003.dat",
		"1 71 10 -192 -40 0 0 1 0 1 0 -1 0 0 11211.dat"],
		{"collision": ["11211", "3003"], "words": "side stud"}],
	["hinge plates through each other (3937 and 3938, model-008)",
		["1 72 80 -440 -110 1 0 0 0 1 0 0 0 1 3937.dat",
		"1 72 80 -435 -101.34 1 0 0 0 0.5 0.866025 0 -0.866025 0.5 3938.dat"],
		{"collision": ["3937", "3938"], "words": "hinge"}],
	["a horn on a round plate's own point, an axle through it (2142, model-002)",
		["1 19 40 -280 -100 1 0 0 0 1 0 0 0 1 4032a.dat",
		"1 19 40 -280 -100 0 0 1 0 1 0 -1 0 0 2142.dat",
		"1 0 40 -292 -100 0 1 0 -1 0 0 0 0 1 3704.dat"],
		{"collision": ["2142", "4032a"], "words": "LDU"}],
	["a fez at its head's own point (85975 on 3626cpbd, model-006)",
		["1 14 228.75 -112 -220 0 0 -1 0 1 0 1 0 0 3626cpbd.dat",
		"1 70 228.75 -112 -220 0 0 -1 0 1 0 1 0 0 85975.dat"],
		{"collision": ["85975", "3626cpbd"], "words": "16 LDU up"}],
	["a sword through the hand that holds it (3847 in 3820, model-010)",
		["1 71 76.31 -149.226 -78.648 0.985446 -0.120202 0.120202 0.169991 0.696815 -0.696815 0 0.707107 0.707107 3820.dat",
		"1 135 75.9104 -146.909 -93.1174 0.985446 -0.0862768 0.146469 0.169991 0.500152 -0.849089 0 0.861629 0.507538 3847.dat"],
		{"collision": ["3847", "3820"], "words": "LDU"}],
	["a round brick sunk into the plate under it (3941 in 3035, model-006)",
		["1 15 380 -136 -100 0 0 -1 0 1 0 1 0 0 3035.dat",
		"1 2 360 -156 -40 0 -1 0 1 0 0 0 0 1 3941.dat"],
		{"collision": ["3941", "3035"], "words": "LDU"}],
	["a tile 2 LDU off the side stud it hangs on (3070b on 30414, model-010)",
		["1 2 100 -48 -150 1 0 0 0 1 0 0 0 1 30414.dat",
		"1 4 70 -46 -168 1 0 0 0 0 -1 0 1 0 3070b.dat"],
		{"seated": ["3070b"]}],
	["a crystal 4 LDU off its stud (30385 on 18674, model-005)",
		["1 297 380 -8 -300 1 0 0 0 1 0 0 0 1 18674.dat",
		"1 57 384 -8 -304 1 0 0 0 1 0 0 0 1 30385.dat"],
		{"seated": ["30385"]}],
	["a dome off the round plate it sits on (20952 on 6141, model-009)",
		["1 15 110 -24 -230 1 0 0 0 1 0 0 0 1 6141.dat",
		"1 15 100 -40 -220 1 0 0 0 1 0 0 0 1 20952.dat"],
		{"collision": ["20952", "6141"], "words": "LDU"}],
	["a gem resting on a slope (30153 on 3039, model-002)",
		["1 70 160 -24 -130 1 0 0 0 1 0 0 0 1 3039.dat",
		"1 36 170 -30 -130 1 0 0 0 1 0 0 0 1 30153.dat"],
		{"collision": ["30153", "3039"], "words": "LDU"}],
	["a round tile lying on a round plate where it has no stud (98138 on 74611, model-007)",
		["1 4 240 -8 -140 1 0 0 0 1 0 0 0 1 74611.dat",
		"1 0 170 -16 -190 1 0 0 0 1 0 0 0 1 98138.dat"],
		{"not held": ["98138"]}],
	# The attach round's three (2026-10-15), each confirmed in BrickBench's own
	# simulation: the potato's shoes and legs as model-042 (run 2) stood them,
	# its body over their heels, which our check held by the floor and which
	# tips (its hat, a dish on a round plate, moved only because the body under
	# it did: CLEAN has the dish); and model-047's trash can lying on its side,
	# on one line of its facets, which rolls.
	["a body over its shoes' heels, which tips (model-042's potato, attach run 2)",
		["1 1 160 -24 -280 1 0 0 0 1 0 0 0 1 15068.dat",
		"1 1 240 -24 -280 1 0 0 0 1 0 0 0 1 15068.dat",
		"1 1 160 -24 -260 0 0 -1 0 1 0 1 0 0 3001.dat",
		"1 1 240 -24 -260 0 0 -1 0 1 0 1 0 0 3001.dat",
		"1 1 160 -48 -220 0 0 -1 0 1 0 1 0 0 3001.dat",
		"1 1 240 -48 -220 0 0 -1 0 1 0 1 0 0 3001.dat",
		"1 1 160 -72 -220 0 0 -1 0 1 0 1 0 0 3001.dat",
		"1 1 240 -72 -220 0 0 -1 0 1 0 1 0 0 3001.dat",
		"1 1 160 -80 -220 0 0 -1 0 1 0 1 0 0 3020.dat",
		"1 1 240 -80 -220 0 0 -1 0 1 0 1 0 0 3020.dat",
		"1 70 200 -88 -180 1 0 0 0 1 0 0 0 1 3958.dat",
		"1 70 200 -112 -200 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 70 200 -112 -160 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 70 200 -136 -180 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 70 200 -160 -200 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 70 200 -160 -160 1 0 0 0 1 0 0 0 1 3001.dat"],
		{"tips over": "past the edge"}],
	# And model-047's flame 1.27 LDU into the tipped lid it pushes open (run 2),
	# which our shapes, read by each collider group's own vertex lines and not
	# the vertices its faces use, had as clear (tools/build_exact.py read_obj).
	["a flame against the tipped lid it pushes open (18395 and 3033, model-047, attach run 2)",
		["1 191 130 -139 -50 -1 0 0 0 1 0 0 0 -1 18395.dat",
		"1 288 100 -225.2003 -27.9966 1 0 0 0 -0.173648193563432 0.984807750209226 0 -0.984807750209226 -0.173648193563432 3033.dat"],
		{"collision": ["18395", "3033"], "words": "LDU"}],
	["a trash can lying on its side, which rolls (model-047, attach run 1)",
		["1 71 280 -20 -76 1 0 0 0 0 -1 0 1 0 14769.dat",
		"1 71 280 -20 -52 1 0 0 0 0 -1 0 1 0 4032a.dat",
		"1 71 280 -20 -60 1 0 0 0 0 -1 0 1 0 4032a.dat",
		"1 72 280 -20 -68 1 0 0 0 0 -1 0 1 0 4032a.dat",
		"1 71 280 -20 -44 1 0 0 0 0 -1 0 1 0 3941.dat"],
		{"tips over": "past the 3 LDU"}],
]

## Built right, these must say nothing: [name, lines].
const CLEAN: Array = [
	["two bricks stacked on their studs",
		["1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat"]],
	["a fez seated on its head's stud",
		["1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3005.dat",
		"1 14 0 -48 0 1 0 0 0 1 0 0 0 1 3626cpbd.dat",
		"1 70 0 -64 0 1 0 0 0 1 0 0 0 1 85975.dat"]],
	["a round tile on the round plate's stud",
		["1 4 240 -8 -140 1 0 0 0 1 0 0 0 1 74611.dat",
		"1 0 230 -16 -130 1 0 0 0 1 0 0 0 1 98138.dat"]],
	["a 1 x 2 with side studs, a tile on them",
		["1 2 100 -24 -150 1 0 0 0 1 0 0 0 1 11211.dat",
		"1 4 90 -14 -168 1 0 0 0 0 -1 0 1 0 3070b.dat",
		"1 4 110 -14 -168 1 0 0 0 0 -1 0 1 0 3070b.dat"]],
	# Both stand in BrickBench's simulation (0.06 and 0.03 LDU in two seconds).
	["a dish on a round plate on a round brick, as the potato's hat (model-042)",
		["1 0 0 -24 0 1 0 0 0 1 0 0 0 1 87081.dat",
		"1 0 0 -32 0 1 0 0 0 1 0 0 0 1 4032a.dat",
		"1 0 0 -48 0 1 0 0 0 1 0 0 0 1 3960.dat"]],
	["the potato's shoes and legs with its body over its feet",
		["1 1 160 -24 -280 1 0 0 0 1 0 0 0 1 15068.dat",
		"1 1 240 -24 -280 1 0 0 0 1 0 0 0 1 15068.dat",
		"1 1 160 -24 -260 0 0 -1 0 1 0 1 0 0 3001.dat",
		"1 1 240 -24 -260 0 0 -1 0 1 0 1 0 0 3001.dat",
		"1 1 160 -48 -220 0 0 -1 0 1 0 1 0 0 3001.dat",
		"1 1 240 -48 -220 0 0 -1 0 1 0 1 0 0 3001.dat",
		"1 1 160 -72 -220 0 0 -1 0 1 0 1 0 0 3001.dat",
		"1 1 240 -72 -220 0 0 -1 0 1 0 1 0 0 3001.dat",
		"1 1 160 -80 -220 0 0 -1 0 1 0 1 0 0 3020.dat",
		"1 1 240 -80 -220 0 0 -1 0 1 0 1 0 0 3020.dat",
		"1 70 200 -88 -240 1 0 0 0 1 0 0 0 1 3958.dat",
		"1 70 200 -112 -260 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 70 200 -112 -220 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 70 200 -136 -240 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 70 200 -160 -260 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 70 200 -160 -220 1 0 0 0 1 0 0 0 1 3001.dat"]],
]


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
	# A build without the exact shapes checks by the lattice alone, as before.
	if Exact.shape_for(_library, "3001") == null:
		print("exact probe: SKIPPED — this build has no exact shapes (tools/build_exact.py "
			+ "writes assets/generated/exact/)")
		quit(0)
		return

	# On a bare floor, as BrickBench stands every build (ExactCheck.tips).
	_assistant.floor_kind = func() -> String: return ModelFloor.NONE
	for case: Array in CASES:
		# A seat is for what a design puts down: those parts come as new ones.
		var report: Dictionary = _checked(case[1], (case[2] as Dictionary).has("seated"))
		_expect(str(case[0]), report, case[2])
	for case: Array in CLEAN:
		var report: Dictionary = _checked(case[1])
		var said: Array = _exact_said(report)
		_say(said.is_empty(), "%s: nothing said" % case[0],
			"%s: said %s" % [case[0], "; ".join(PackedStringArray(said))])
	await _figure()
	_hinge()
	print("exact probe: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The lines opened as a model, read back as a session's model is, and
## checked as review_model checks a whole design; [param fresh], as a design
## that puts them all down does (check_design, submit_design).
func _checked(lines: Array, fresh: bool = false) -> Dictionary:
	var text: String = "0 probe\n" + "\n".join(PackedStringArray(lines)) + "\n"
	_store.open_text(text, "probe.ldr")
	var model: Assistant.Model = _assistant._model_from_world()
	for placement: Assistant.Placement in model.placements:
		placement.mine = true
		if fresh:
			placement.id = 0
	_assistant.set("_strict_mine", true)
	var report: Dictionary = _assistant._check(model, true)
	_assistant.set("_strict_mine", false)
	report["model"] = model
	return report


## Every sentence the exact check said, of any kind.
func _exact_said(report: Dictionary) -> Array:
	var out: Array = []
	var found: Dictionary = report.get("exact", {})
	for kind: Variant in found:
		out.append_array(found[kind])
	return out


func _expect(name: String, report: Dictionary, wanted: Dictionary) -> void:
	var found: Dictionary = report.get("exact", {})
	if wanted.has("collision"):
		var said: Array = found.get("collision", [])
		var hit: String = ""
		for sentence: Variant in said:
			var s: String = str(sentence)
			if (wanted["collision"] as Array).all(func(p: String) -> bool: return s.contains(p)):
				hit = s
		_say(not hit.is_empty() and hit.contains(str(wanted.get("words", ""))),
			"%s: named, with its fix: %s" % [name, hit],
			"%s: not named as a collision with \"%s\" (said: %s; summary: %s)" % [name,
				wanted.get("words", ""), said, report.get("summary", "")])
	if wanted.has("not held"):
		var said: Array = found.get("not held", [])
		var hit: String = ""
		for sentence: Variant in said:
			if str(sentence).contains(str((wanted["not held"] as Array)[0])):
				hit = str(sentence)
		_say(not hit.is_empty(), "%s: said not held: %s" % [name, hit],
			"%s: not said to be unheld (summary: %s)" % [name, report.get("summary", "")])
	if wanted.has("tips over"):
		var said: Array = found.get("tips over", [])
		var hit: String = ""
		for sentence: Variant in said:
			if str(sentence).contains(str(wanted["tips over"])):
				hit = str(sentence)
		_say(not hit.is_empty(), "%s: said it tips: %s" % [name, hit],
			"%s: not said to tip with \"%s\" (said: %s; summary: %s)" % [name,
				wanted["tips over"], said, report.get("summary", "")])
		# And on a baseplate, whose studs hold it, nothing of the kind.
		_assistant.floor_kind = func() -> String: return ModelFloor.BASEPLATE
		var plated: Dictionary = _assistant._check(report["model"], true)
		_assistant.floor_kind = func() -> String: return ModelFloor.NONE
		var still: Array = (plated.get("exact", {}) as Dictionary).get("tips over", [])
		_say(still.is_empty(), "%s: on a baseplate, not said to tip" % name,
			"%s: on a baseplate, still said to tip: %s" % [name, still])
	if wanted.has("seated"):
		var advice: String = "\n".join(PackedStringArray(report.get("advice", [])))
		var part: String = str((wanted["seated"] as Array)[0])
		var collided: Array = found.get("collision", [])
		var still: bool = collided.any(func(s: Variant) -> bool: return str(s).contains(part))
		_say(advice.contains("Seated") and advice.contains(part) and not still and found.has("collision"),
			"%s: seated exactly, and nothing collides" % name,
			"%s: not seated (advice: %s; collisions: %s)" % [name, advice.left(300), collided])


## A minifigure as add_minifig makes it, a fez among its parts: checked as a
## design is, it must say nothing — a figure built here is BrickBench-clean.
func _figure() -> void:
	_store.open_text("0 base\n1 4 0 -8 0 1 0 0 0 1 0 0 0 1 3958.dat\n", "base.ldr")
	var stood: Dictionary = await FigureTool.add({"name": "Duke", "x": 0, "z": 0,
		"headwear": "85975", "accessory": "3847"}, _library, _world, _builder)
	if not bool(stood.get("ok", false)):
		_say(false, "", "a figure with a fez and a sword: not placed (%s)" % stood.get("text", ""))
		return
	var model: Assistant.Model = _assistant._model_from_world()
	for placement: Assistant.Placement in model.placements:
		placement.mine = true
	_assistant.set("_strict_mine", true)
	var report: Dictionary = _assistant._check(model, true)
	_assistant.set("_strict_mine", false)
	var said: Array = _exact_said(report)
	_say(report.has("exact") and said.is_empty(),
		"a figure with a fez and a sword, as add_minifig makes it: nothing said",
		"a figure with a fez and a sword, as add_minifig makes it: said %s" % (
			"; ".join(PackedStringArray(said)) if report.has("exact") else "no exact check at all"))
	# In a breastplate (2587), its head seated clear of it by more than the
	# 1 LDU verify.py tosses a coin over: model-010's one collision, a head the
	# figure tool had stood exactly 1 LDU into the armour.
	_store.open_text("0 base\n1 4 0 -8 0 1 0 0 0 1 0 0 0 1 3958.dat\n", "base.ldr")
	stood = await FigureTool.add({"name": "Knight", "x": 0, "z": 0, "head": "3626cp01",
		"neck": "2587"}, _library, _world, _builder)
	if not bool(stood.get("ok", false)):
		_say(false, "", "a figure in a breastplate: not placed (%s)" % stood.get("text", ""))
		return
	var items: Array = []
	var at: Dictionary = {}     ## part -> its item's index
	for brick: BrickWorld.Brick in _world.bricks():
		var shape: Exact.Shape = Exact.shape_for(_library, brick.part_id)
		at[brick.part_id] = items.size()
		items.append(Exact.Item.new(shape, brick.transform) if shape != null else null)
	if not (at.has("3626cp01") and at.has("2587") and at.has("973")):
		_say(false, "", "a figure in a breastplate: its parts are %s" % str(at.keys()))
		return
	var meets: Dictionary = Exact.clash(items[at["3626cp01"]], items[at["2587"]], true)
	var joined: bool = Exact.connected(items, at["3626cp01"], PackedInt32Array([at["973"], at["2587"]]))
	_say(meets.is_empty() and joined,
		"a figure in a breastplate: its head clear of it and joined to the torso",
		"a figure in a breastplate: head and armour %s, joined %s" % [meets, joined])


## A section hung on the app's own tilting hinge, as a session writes it: the
## two halves the app lays are clean by BrickNet's shapes at any angle it
## opens to, and folded the way it does not open, named as the hinge it is.
func _hinge() -> void:
	# Asked of the joint, on a baseplate: a flap opened past its brick's edge,
	# stood alone on a bare floor, tips, as it would in the hand.
	_assistant.floor_kind = func() -> String: return ModelFloor.BASEPLATE
	var folded: Assistant.Model = _assistant._read_model({"bricks": [
		{"part": "3004", "color": 0, "x": 0, "y": 0, "z": 0},
		{"part": "3023", "color": 0, "x": 0, "y": 0, "z": 0, "section": "flap"}],
		"sections": [{"name": "flap", "x": 0, "y": 3, "z": 0, "axis": "x",
			"degrees": -45, "hinge": "tilting"}]})
	var named: Array = (_assistant._check(folded, true).get("exact", {}) as Dictionary).get(
		"collision", [])
	_say(named.any(func(s: Variant) -> bool: return str(s).contains("3938") \
			and str(s).contains("hinge")),
		"the app's tilting hinge folded -45 degrees, into its base: named as the hinge",
		"the app's tilting hinge folded -45 degrees: not named (%s)" % [named])
	for degrees: float in [0.0, 30.0, 60.0, 90.0]:
		var model: Assistant.Model = _assistant._read_model({"bricks": [
			{"part": "3004", "color": 0, "x": 0, "y": 0, "z": 0},
			{"part": "3004", "color": 0, "x": 0, "y": 0, "z": 0, "section": "flap"},
			{"part": "3023", "color": 0, "x": 0, "y": 3, "z": 0, "section": "flap"}],
			"sections": [{"name": "flap", "x": 0, "y": 3, "z": 0, "axis": "x",
				"degrees": degrees, "hinge": "tilting"}]})
		var report: Dictionary = _assistant._check(model, true)
		var said: Array = _exact_said(report)
		_say(report.has("exact") and said.is_empty() and bool(report.get("ok", false)),
			"the app's tilting hinge at %d degrees: nothing said" % int(degrees),
			"the app's tilting hinge at %d degrees: %s; %s" % [int(degrees),
				report.get("summary", ""), "; ".join(PackedStringArray(said))])


func _say(ok: bool, good: String, bad: String) -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % good)
	else:
		_failed += 1
		print("  FAIL %s" % bad)
