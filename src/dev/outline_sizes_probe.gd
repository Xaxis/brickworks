## The real thing's outline read as sizes to build to: plan_scale takes the
## outline a session reads off a photograph before the first build and
## answers with the outline in levels of studs and plates, each setback on
## the side it steps in on and how tall each tier is, what breaks the outline
## as masses of their own, the height a building's storeys need, and the plan
## from above. No solid (OutlinePlan, design22 and design23).
##
##   godot --headless --path . --script src/dev/outline_sizes_probe.gd
##
## Five sets of the tune half, opened from their own LDraw files, each read as
## a perfect reader would read its photograph (design20's Silhouette): along
## its length from the front, and up its height. Each reading given to
## plan_scale sized by the part read; the levels its answer says hold the
## set's own outline at every tenth, within the tolerance it names. Then
## design23's three: the brief's box as a bound with the depth the plan's own,
## tenths in levels with a step only where the reading steps, and a building's
## height stretched for its storeys. Then setbacks on the side read (and
## mirrored from the back), a vehicle's body over its wheels with the wheels as
## breaks, what studs= measures, the asks before the first build, and wrong
## readings refused. No graphics card: the outline is the lattice's.
extends SceneTree

const SETS := "res://vendor/omr/files"
## Tune-half sets (tools/bench/realset.py sample --which tune): an animal, a
## BrickHeadz figure, a Technic vehicle and two Architecture skylines.
const FIVE: Array[String] = ["40148-1", "41587-1", "42061-1", "21051-1", "21034-1"]
const PLATE := 8.0
const STUD := 20.0
## LDU per lattice cell, and the cells either side a sample reads over: a
## tenth of a stud across, a quarter of a plate up (Silhouette.BAND).
const CELL := 2.0
const BAND := 2

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _store: ModelStore


## A model's outline from one side, in lattice cells: column 0 the left of
## the view, row 0 the lowest cell.
class Seen extends RefCounted:
	var cols: int = 0
	var rows: int = 0
	var top := PackedInt32Array()
	var left := PackedInt32Array()
	var right := PackedInt32Array()


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	if not DirAccess.dir_exists_absolute(SETS):
		print("SKIP no %s: tools/omr.py fetch brings the sets" % SETS)
		quit(3)
		return
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	root.add_child(_assistant)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	Assistant.design_parts = 1
	await process_frame

	await _asked_before_the_first_build()
	for number: String in FIVE:
		await _one_set(number)
	await _the_box_is_a_bound()
	await _levels_not_tenths()
	await _height_for_storeys()
	await _setbacks_on_their_side()
	await _a_body_over_its_wheels()
	await _what_studs_measures()
	await _readings_refused()
	print("\n%s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- the ask --------------------------------------------------------------------


func _asked_before_the_first_build() -> void:
	print("\nasked before the first build, once each, never once an outline is held")
	_clear()
	_assistant._outline_plan = null
	_assistant._outline_asked = {}
	var how: String = _text(await _assistant.use_tool("how_real_sets_build_this",
		{"subject": "fire engine"}))
	_ok(how.begins_with("Before the first build: Read the real thing's outline")
		and how.contains("give plan_scale outline=") and how.contains("sizes, not a shape")
		and how.contains("over its wheels, not down to the ground")
		and how.contains("which side it steps in on") and how.contains("{\"read\": n}")
		and how.contains("{\"box\": [w, d]}") and how.contains("a bound the model fits in")
		and how.contains("never off the brief's box") and how.contains("storeys="),
		"how_real_sets_build_this leads with the ask: sizes, not a shape; a vehicle's body over "
			+ "its wheels; a setback's side; the box a bound and deep= never off it; storeys=")
	how = _text(await _assistant.use_tool("how_real_sets_build_this", {"subject": "fire engine"}))
	_ok(not how.contains("Before the first build"), "...once: asked again, it does not")
	var scaled: String = _text(await _assistant.use_tool("plan_scale",
		{"subject": "fire engine", "longest_metres": 10}))
	_ok(scaled.contains("minifigure") and scaled.contains("give plan_scale outline="),
		"plan_scale with no outline answers the scale and asks for it")
	var built: String = _text(await _assistant.use_tool("submit_design", _truck()))
	_ok(built.begins_with("Built.") and built.split("\n\n").size() > 1
		and built.split("\n\n")[1].begins_with("Its masses are its own: no outline"),
		"the first build of a new design with none read asks, under its first line")
	_clear()
	built = _text(await _assistant.use_tool("submit_design", _truck()))
	_ok(not built.contains("Its masses are its own"), "...once")

	_assistant._outline_asked = {}
	var sized: String = _text(await _assistant.use_tool("plan_scale", {"subject": "fire engine",
		"longest_metres": 10, "studs": {"box": [12, 30]}, "outline": {"from": "front",
			"heights": [0.2, 0.25, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.25, 0.2]}}))
	_ok(sized.contains("The outline read") and sized.contains("These are the sizes to build "
		+ "to, not a shape") and not sized.contains("\"pattern\"")
		and not sized.contains("{\"extrude\"") and not sized.contains("{\"tiers\""),
		"the answer is sizes and names no solid to send: %s" % _line_with(sized, "not a shape"))
	how = _text(await _assistant.use_tool("how_real_sets_build_this", {"subject": "fire engine"}))
	_ok(not how.contains("Before the first build"), "with an outline held, nothing asks")
	_clear()
	built = _text(await _assistant.use_tool("submit_design", _truck()))
	_ok(not built.contains("Its masses are its own"), "...nor the first build")
	var same: String = _text(await _assistant.use_tool("plan_scale", {"subject": "fire engine",
		"longest_metres": 10}))
	_ok(same.contains("The outline read before stands: its top along its length"),
		"plan_scale again for the subject says the outline held stands")
	var other: String = _text(await _assistant.use_tool("plan_scale",
		{"subject": "lighthouse", "longest_metres": 30}))
	_ok(_assistant._outline_plan == null and other.contains("outline="),
		"plan_scale for another subject with none drops the one held, and asks")


# -- the five sets ----------------------------------------------------------------


func _one_set(number: String) -> void:
	print("\n%s" % number)
	if not _open(number):
		_ok(false, "%s opens" % number)
		return
	var front: Seen = _seen(_world.bricks())
	_ok(front.cols > 0, "%d x %d cells from the front" % [front.cols, front.rows])
	# Along its length: sized by the length read; at each tenth the level (or
	# the slope) its answer says holds the set's own top within the tolerance.
	var long: Vector2i = _span(front, "heights")
	var length: float = float(long.y - long.x + 1) * CELL / STUD
	var answer: String = _text(await _assistant.use_tool("plan_scale", {"subject": number,
		"longest_metres": 1, "studs": {"read": snappedf(length, 0.1)},
		"outline": _reading(front, "heights")}))
	var pieces: Array = _pieces(answer, "Its top along x")
	var tol: Array = _numbers_in(answer, "tenths within ", " plates of each other")
	var own: PackedFloat64Array = _samples(front, "heights")
	var off: Array = []
	for n: int in own.size():
		var at: float = float(n) / 10.0 * snappedf(length, 0.1)
		if not _held(pieces, at, own[n] / PLATE, (float(tol[0]) if not tol.is_empty() else 0.0)
				+ 1.0):
			off.append("%d: %s" % [n, OutlinePlan._n(snappedf(own[n] / PLATE, 0.1))])
	_ok(not pieces.is_empty() and not tol.is_empty() and off.is_empty(), "heights sized by the "
		+ "%s studs read, in %d levels and slopes: every tenth's top is held within the %s plates "
		% [OutlinePlan._n(snappedf(length, 0.1)), pieces.size(), str(tol)] + "said %s" % (
			"" if off.is_empty() else str(off)))
	# Up its height: sized by its widest; each tenth inside its tier's width.
	var widths: PackedFloat64Array = _samples(front, "widths")
	var widest: float = Array(widths).max() / STUD
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": number,
		"longest_metres": 1, "studs": {"read": snappedf(widest, 0.1)},
		"outline": _reading(front, "widths")}))
	var tiers: Array = _tiers(answer)
	var within: Array = _numbers_in(answer, "widths within ", " stud")
	var up: Vector2i = _span(front, "widths")
	var tall: float = float(up.y - up.x + 1) * CELL / PLATE
	var said: Array = _numbers_in(answer, "Up its height (", " plates")
	off = []
	for n: int in widths.size():
		var at: float = float(n) / 10.0 * (float(said[0]) if not said.is_empty() else tall)
		var tier: Vector3 = Vector3(-1, -1, -1)
		for one: Vector3 in tiers:
			if at >= one.x - 0.5 and at <= one.y + 0.5:
				tier = one
				if absf(one.z - widths[n] / STUD) <= (float(within[0]) if not within.is_empty()
						else 1.0) + 1.0:
					break
		if tier.z < 0.0 or absf(tier.z - widths[n] / STUD) > (float(within[0])
				if not within.is_empty() else 1.0) + 1.0:
			off.append("%d: %s" % [n, OutlinePlan._n(snappedf(widths[n] / STUD, 0.1))])
	_ok(not tiers.is_empty() and said.size() >= 1 and absf(float(said[0]) - tall) <= 1.0
		and off.is_empty(), "widths sized by its widest, %s studs: %s plates tall as the set is, "
			% [OutlinePlan._n(snappedf(widest, 0.1)), OutlinePlan._n(roundf(tall))]
			+ "in %d tiers, each tenth's width its tier's within the stud said %s" % [tiers.size(),
				"" if off.is_empty() else str(off)])


# -- design23: the box ----------------------------------------------------------------


func _the_box_is_a_bound() -> void:
	print("\nthe brief's box is a bound: the long side fits it, the depth is the plan's own")
	var body: Dictionary = {"from": "front", "heights": [0.2, 0.28, 0.3, 0.52, 0.52, 0.52, 0.33,
		0.32, 0.3, 0.28, 0.2], "deep": 0.55}
	var answer: String = _text(await _assistant.use_tool("plan_scale", {"subject": "a dozer",
		"longest_metres": 6.5, "studs": {"box": [33, 30]}, "outline": body}))
	_ok(answer.contains("sized at the brief's box, 33 x 30 studs, as a bound: its length fits the "
		+ "box's 33, and its width across is 18 studs, from its own plan (deep 0.55), not the "
		+ "box's 30") and answer.contains("33 studs long and 18 across")
		and answer.contains("Its plan from above: a rectangle, 33 studs along x and 18 across"),
		"a dozer in a 33 x 30 box: 33 long and 18 across, its own 0.55, never the box's 30 "
			+ "(design22 laid it 33 x 30): %s" % _line_with(answer, "sized at"))
	_ok(not answer.contains("At each scale builders use") and not answer.contains(
		"where the scale above says") and not answer.contains("minifigure"),
		"with a box, no scale table and no comparison with a scale")
	body["deep"] = 0.9
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a dozer",
		"longest_metres": 6.5, "studs": {"box": [33, 30]}, "outline": body}))
	_ok(answer.contains("deep= 0.9 is the box's own shape (30 / 33). The box bounds the set"),
		"a deep= that is the box's own shape is said: %s" % _line_with(answer, "own shape"))
	body.erase("deep")
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a dozer",
		"longest_metres": 6.5, "studs": {"footprint": [33, 30]}, "outline": body}))
	_ok(answer.contains("as a bound: its length fits the box's 33, and its width across is 13 "
		+ "studs, at 0.4 of its length, a long thing's usual, not the box's 30")
		and answer.contains("Give deep=, its width across"),
		"design22's footprint= is the same bound; with no deep= it is 0.4 across and asks for "
			+ "deep=: %s" % _line_with(answer, "sized at"))
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a motorbike",
		"longest_metres": 2.1, "studs": {"box": [43, 13]}, "outline": {"from": "front",
			"heights": [0.4, 0.42, 0.4, 0.39, 0.44, 0.47, 0.47, 0.5, 0.53, 0.42, 0.26],
			"deep": 0.36}}))
	_ok(answer.contains("its length fits the box's 43, and its width across, 15.5 studs from its "
		+ "own plan (deep 0.36), is held to the box's 13") and answer.contains(
			"43 studs long and 13 across"), "a plan read wider than the box keeps the box's "
		+ "length and holds its width to the box: %s" % _line_with(answer, "sized at"))
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a slab tower",
		"longest_metres": 259, "studs": {"box": [12, 13]}, "outline": {"from": "left",
			"widths": [0.4, 0.4, 0.36, 0.36, 0.32, 0.3, 0.3, 0.26, 0.24, 0.2, 0.16],
			"deep": 0.45}}))
	_ok(answer.contains("its widest face fits the box's 13, and its depth is 6 studs, from its "
		+ "own plan (deep 0.45), not the box's 12") and answer.contains("13 studs at its widest "
			+ "and 6 deep"), "a slab tower in a 12 x 13 box: 13 wide, 6 deep, not 12 "
		+ "(design22 laid it 13 x 12): %s" % _line_with(answer, "sized at"))


# -- design23: levels ------------------------------------------------------------------


func _levels_not_tenths() -> void:
	print("\ntenths in levels: a level ends only where the reading steps")
	# A long, level roofline read with a reader's noise, a dome in its middle.
	var noisy: Array = [0.06, 0.16, 0.17, 0.14, 0.17, 0.41, 0.19, 0.16, 0.15, 0.17, 0.06]
	var answer: String = _text(await _assistant.use_tool("plan_scale", {"subject": "a capitol",
		"longest_metres": 229, "studs": {"box": [56, 18]}, "outline": {"from": "front",
			"heights": noisy, "deep": 0.3}}))
	var pieces: Array = _pieces(answer, "Its top along x")
	var levels: Array = pieces.filter(func(p: Dictionary) -> bool: return not p["slope"])
	_ok(not answer.contains("/10, x") and levels.size() == 2
		and is_equal_approx(float(levels[0]["plates"]), float(levels[1]["plates"]))
		and float(levels[0]["plates"]) >= 22.0 and float(levels[0]["plates"]) <= 24.0
		and answer.contains("tenths within 6 plates of each other are one level"),
		"wings read 0.14 to 0.19 (20 to 27 plates) are one level each side, the same height, "
			+ "no tenth said alone:\n%s" % _lines_with(answer, "  x "))
	_ok(answer.contains("x 22.5 to 33.5: a slope or a curve, 24 plates at x 22.5, highest 57 "
		+ "plates at x 28") and answer.contains("(built with slopes or curves, not steps)"),
		"the dome between them is a curve, its highest said: %s" % _line_with(answer, "highest"))
	# The same hall read with steps: a step is where the reading puts one, and
	# one under a brick is a band.
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a long hall",
		"longest_metres": 60, "studs": {"longest": 48}, "outline": {"from": "front",
			"heights": [0.1, 0.1, 0.1, 0.2, 0.3, 0.3, 0.3, 0.2, 0.1, 0.1, 0.1],
			"steps": [0.25, 0.35, 0.65, 0.75]}}))
	_ok(answer.contains("  x 0 to 12: 12 plates\n  x 12 to 17: 24 plates\n  x 17 to 31: 36 "
		+ "plates\n  x 31 to 36: 24 plates\n  x 36 to 48: 12 plates"),
		"a roofline's steps along it, each stretch its own level:\n%s" % _lines_with(answer, "  x "))
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a palace",
		"longest_metres": 108, "studs": {"box": [26, 24]}, "outline": {"from": "front",
			"heights": [0.2, 0.22, 0.2, 0.2, 0.21, 0.23, 0.21, 0.2, 0.2, 0.22, 0.2],
			"steps": [0.1, 0.4, 0.6, 0.9], "deep": 0.3}}))
	_ok(answer.contains("  x 0 to 26: 13 plates") and answer.contains("(4 of the steps read are "
		+ "under a brick at this size: one level, a band or a line of tiles, not a step.)"),
		"steps read a plate apart are one level, and said to be bands:\n%s"
			% _lines_with(answer, "  "))


# -- design23: storeys -------------------------------------------------------------------


func _height_for_storeys() -> void:
	print("\na building's height stretched for its storeys, with the height read beside it")
	var palace: Dictionary = {"from": "front", "heights": [0.2, 0.2, 0.2, 0.2, 0.2, 0.27, 0.2,
		0.2, 0.2, 0.2, 0.2], "steps": [0.45, 0.55], "deep": 0.3, "storeys": 3}
	var answer: String = _text(await _assistant.use_tool("plan_scale", {"subject": "a palace",
		"longest_metres": 108, "studs": {"box": [26, 24]}, "outline": palace}))
	_ok(answer.contains("Height for its features: its 3 storeys need 19 plates at this size, a "
		+ "plinth of 2, 5 for each storey") and answer.contains("Its face is 13 plates as read, "
			+ "so it is stretched 1.5 times, to 19 plates, and every height up to it with it"),
		"a palace a fifth as tall as long: 13 plates read, its 3 storeys need 19, stretched 1.5: "
			+ _line_with(answer, "Height for"))
	_ok(answer.contains("  x 0 to 11.5: 19 plates (13 read)") and answer.contains(
		"  x 11.5 to 14.5: 23 plates (17 read)") and answer.contains("26 studs long and 8 across, "
			+ "23 plates at its highest") and answer.contains("stands on it, 6 plates higher "
				+ "than read"), "its face stretched, its centre above the face raised by the 6 "
		+ "plates the face gained, the read beside each, its length and plan as read:\n%s"
			% _lines_with(answer, "read)"))
	# The Capitol as design23's first start read it: wings level at a tenth of
	# its length, the dome 0.37. Its set has wings of 18 plates and a dome of
	# 48; stretching the dome with the storeys made it 70.
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a capitol",
		"longest_metres": 229, "studs": {"box": [56, 18]}, "outline": {"from": "front",
			"heights": [0.1, 0.1, 0.085, 0.1, 0.2, 0.37, 0.2, 0.1, 0.085, 0.1, 0.1],
			"plan": "rectangle", "deep": 0.32, "storeys": 3, "breaks": [{"name": "dome",
				"from": 0.4, "to": 0.6, "bottom": 0.1, "top": 0.37}, {"name": "steps",
				"from": 0.38, "to": 0.62, "bottom": 0, "top": 0.05}]}}))
	_ok(answer.contains("Its face is 14 plates as read, so it is stretched 1.4 times, to 19 "
		+ "plates") and answer.contains("  x 0 to 17: 19 plates (14 read)") and answer.contains(
			"  dome: x 22.5 to 33.5 (11 studs), y 19 to 57 plates (38 tall)") and answer.contains(
				"56 studs long and 18 across, 57 plates at its highest") and not answer.contains(
					"70 plates"), "a dome above the wings keeps its own 38 plates on the "
		+ "stretched wings, 57 where 52 are read, not stretched to 70:\n%s"
			% _lines_with(answer, "plates"))
	_ok(not answer.contains("read its underside"), "a building's steps on the ground are not "
		+ "told to be read as its underside: %s" % _line_with(answer, "underside"))
	# The Guggenheim as the same start read it: the annex and the rotunda each
	# run 8 of its 18 studs. Its storeys are counted on the rotunda, its main
	# block; its set has the rotunda 32 plates and the annex 21 to 24.
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a spiral museum",
		"longest_metres": 70, "studs": {"box": [18, 10]}, "outline": {"from": "front",
			"heights": [0.22, 0.24, 0.3, 0.3, 0.3, 0.42, 0.45, 0.45, 0.45, 0.42, 0.18],
			"deep": 0.55, "storeys": 6}}))
	_ok(answer.contains("Its face is 20 plates as read, so it is stretched 1.7 times, to 34 "
		+ "plates") and answer.contains("  x 0 to 8: 23 plates (13 read)") and answer.contains(
			"  x 8 to 16: 34 plates (20 read)"), "storeys counted on its main block, the highest "
		+ "level a quarter of its length or more, not the lower annex as long:\n%s"
			% _lines_with(answer, "read)"))
	palace["heights"] = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
	palace.erase("steps")
	palace["storeys"] = 5
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a long block",
		"longest_metres": 108, "studs": {"box": [26, 24]}, "outline": palace}))
	_ok(answer.contains("stretched 2 times, to 14 plates") and answer.contains(
		"That is the most an expert stretches it: build each storey 4 plates"),
		"a stretch is at most 2, then each storey a brick and a plate: %s"
			% _line_with(answer, "the most"))
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a hall",
		"longest_metres": 60, "studs": {"box": [16, 12]}, "outline": {"from": "front",
			"heights": [0.08, 0.38, 0.38, 0.38, 0.38, 0.38, 0.38, 0.38, 0.38, 0.38, 0.08],
			"steps": [0.05, 0.95], "deep": 0.6, "storeys": 1}}))
	_ok(answer.contains("its storey needs 9 plates") and answer.contains("Its face is 15 plates "
		+ "as read: room for it.") and not answer.contains("read)"),
		"a face with room for its storeys is not stretched: %s" % _line_with(answer, "Height for"))
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "an office tower",
		"longest_metres": 150, "studs": {"box": [12, 10]}, "outline": {"from": "front",
			"widths": [0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2], "deep": 0.8,
			"storeys": 39}}))
	_ok(answer.contains("Its 39 storeys are a tower's floors: at this size they are texture")
		and not answer.contains("read)"), "a tower's many floors are texture, never stretched: %s"
			% _line_with(answer, "39 storeys"))


# -- setbacks ---------------------------------------------------------------------


func _setbacks_on_their_side() -> void:
	print("\nsetbacks where the reading puts them, on the side each steps in on")
	var widths: Array = [0.4, 0.4, 0.4, 0.4, 0.3, 0.3, 0.3, 0.2, 0.2, 0.2, 0.2]
	var sided: Array = [{"at": 0.35, "side": "left"}, {"at": 0.65, "side": "right"}]
	var answer: String = _text(await _assistant.use_tool("plan_scale", {"subject": "a tower",
		"longest_metres": 120, "studs": {"read": 16}, "outline": {"from": "front",
			"widths": widths, "steps": sided, "plan": "rectangle", "deep": 0.5}}))
	_ok(answer.contains("in 3 tiers, ground first")
		and answer.contains("1. y 0 to 35, 35 plates tall: 16 studs wide, x 0 to 16")
		and answer.contains("2. y 35 to 65, 30 plates tall: 12 studs wide, x 4 to 16 (in 4 "
			+ "studs on its -x side, the photograph's left; the +x stays)")
		and answer.contains("3. y 65 to 100, 35 plates tall: 8 studs wide, x 4 to 12 (in 4 "
			+ "studs on its +x side, the photograph's right; the -x stays)"),
		"from the front: the first setback steps in on the left, the second on the right, "
			+ "each tier its height:\n%s" % _lines_with(answer, " plates tall: "))
	_ok(not answer.contains("/10, y") and answer.contains("Its plan from above: a rectangle, 16 "
		+ "studs across its widest tier and 8 deep"), "...no tenth said alone, and the plan is "
			+ "said in studs")
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a tower",
		"longest_metres": 120, "studs": {"read": 16}, "outline": {"from": "back",
			"widths": widths, "steps": sided}}))
	_ok(answer.contains("2. y 35 to 65, 30 plates tall: 12 studs wide, x 0 to 12 (in 4 "
		+ "studs on its +x side, the photograph's left; the -x stays)"),
		"from the back, the photograph's left is +x: %s" % _line_with(answer, "2. y 35"))
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a tower",
		"longest_metres": 120, "studs": {"read": 16}, "outline": {"from": "front",
			"widths": [0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.2, 0.2, 0.2, 0.2, 0.2],
			"steps": [{"at": 0.55, "side": "both"}]}}))
	_ok(answer.contains("2. y 55 to 100, 45 plates tall: 8 studs wide, x 4 to 12 (in 4 on its "
		+ "-x side and 4 on its +x)") and not answer.contains("came with no side"),
		"\"both\" steps in evenly: %s" % _line_with(answer, "2. y 55"))
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a tower",
		"longest_metres": 120, "studs": {"read": 16}, "outline": {"from": "front",
			"widths": [0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.2, 0.2, 0.2, 0.2, 0.2], "steps": [0.55]}}))
	_ok(answer.contains("1 of its setbacks came with no side, so each was taken as both sides "
		+ "evenly"), "a setback said with no side is taken as both, and the answer says to "
			+ "give the side")
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a tower",
		"longest_metres": 120, "studs": {"read": 16}, "outline": {"from": "front",
			"widths": [0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.39, 0.39, 0.39, 0.39, 0.39],
			"steps": [{"at": 0.55, "side": "left"}]}}))
	_ok(answer.contains("1 of the setbacks read is under a stud at this size, so the tiers either "
		+ "side are one") and not answer.contains("2. y"),
		"a setback under a stud at the size built is one tier, said to be a band")
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a tower",
		"longest_metres": 120, "studs": {"read": 16.4}, "outline": {"from": "front",
			"widths": [0.41, 0.41, 0.41, 0.41, 0.41, 0.41, 0.365, 0.365, 0.365, 0.365, 0.365],
			"steps": [{"at": 0.55, "side": "both"}]}}))
	_ok(answer.contains("15 studs wide, x 0 to 15 (in 1 stud on its +x side: one stud does not "
		+ "split between both)"), "\"both\" by one stud steps in on one side, and says why: %s"
			% _line_with(answer, "2. y 55"))


# -- a vehicle's body over its wheels -------------------------------------------------


func _a_body_over_its_wheels() -> void:
	print("\na long thing's body read over what holds it up; what breaks it, masses of their own")
	var tops: Array = [0.2, 0.25, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.25, 0.2]
	var over: Array = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
	var wheels: Array = [{"name": "front wheel", "from": 0.05, "to": 0.25, "bottom": 0,
		"top": 0.2}, {"name": "back wheel", "from": 0.75, "to": 0.95, "bottom": 0, "top": 0.2},
		{"name": "boom", "from": 0.3, "to": 0.9, "bottom": 0.3, "top": 0.4}]
	var answer: String = _text(await _assistant.use_tool("plan_scale", {"subject": "a loader",
		"longest_metres": 8, "studs": {"box": [14, 40]}, "outline": {"from": "front",
			"heights": tops, "bottoms": over, "breaks": wheels}}))
	_ok(answer.contains("40 studs long and 14 across, 30 plates at its highest")
		and answer.contains("  x 8 to 32: 30 plates") and answer.contains("Its underside along "
			+ "x, in levels:\n  x 0 to 40: 10 plates"),
		"sized by the box, 40 x 14, its body's top and underside in levels:\n%s"
			% _lines_with(answer, "  x "))
	_ok(answer.contains("What breaks the outline, each a mass of its own")
		and answer.contains("front wheel: x 2 to 10 (8 studs), y 0 to 20 plates (20 tall), on "
			+ "the ground") and answer.contains("back wheel: x 30 to 38 (8 studs)")
		and answer.contains("boom: x 12 to 36 (24 studs), y 30 to 40 plates (10 tall)")
		and not answer.contains("boom: x 12 to 36 (24 studs), y 30 to 40 plates (10 tall), on"),
		"each break said as its own mass, where it is and how big:\n%s"
			% _lines_with(answer, " tall)"))
	_ok(not answer.contains("read down to the ground"), "...the body read over its wheels is "
		+ "not told it reaches the ground")
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a loader",
		"longest_metres": 8, "studs": {"box": [14, 40]}, "outline": {"from": "front",
			"heights": tops, "breaks": wheels}}))
	_ok(answer.contains("Its body is read down to the ground over front wheel and back wheel: "
		+ "read its underside there"), "a body read down to the ground over its wheels is told "
			+ "to read its underside: %s" % _line_with(answer, "down to the ground"))
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": "a motorbike",
		"longest_metres": 2, "studs": {"longest": 40}, "outline": {"from": "back",
			"heights": [0.2, 0.42, 0.43, 0.4, 0.4, 0.46, 0.52, 0.5, 0.42, 0.3, 0.15],
			"bottoms": [0, 0, 0.12, 0.1, 0.07, 0.07, 0.07, 0.1, 0.12, 0, 0]}}))
	_ok(answer.contains("Its underside meets the ground at x 40, x 36, x 4, x 0 and is off it "
		+ "between: if what stands on the ground there is wheels, tracks or legs, read them as "
		+ "breaks="), "an underside meeting the ground at its ends with no breaks is asked "
			+ "whether those are wheels: %s" % _line_with(answer, "meets the ground"))


# -- studs= ---------------------------------------------------------------------------


func _what_studs_measures() -> void:
	print("\nstuds= names what it measures")
	var slab: Dictionary = {"from": "front", "widths": [0.24, 0.22, 0.17, 0.17, 0.17, 0.16,
		0.16, 0.15, 0.15, 0.13, 0.11], "steps": [{"at": 0.15, "side": "left"},
			{"at": 0.55, "side": "right"}], "deep": 2.2}
	var read: String = _text(await _assistant.use_tool("plan_scale", {"subject": "a slab tower",
		"longest_metres": 259, "studs": {"read": 6}, "outline": slab}))
	var longest: String = _text(await _assistant.use_tool("plan_scale", {"subject": "a slab tower",
		"longest_metres": 259, "studs": {"longest": 6}, "outline": slab}))
	_ok(read.contains("sized at studs= {\"read\": 6}: the part read, its widest width as the "
		+ "photograph shows it, 6 studs: 63 plates tall (25 studs), 6 studs at its widest and 13 "
		+ "deep") and not read.contains("where the scale above says"),
		"{\"read\": 6} is the face read, 6 studs wide, so 25 studs tall, within half again of the "
			+ "scale's 34: %s" % _line_with(read, "sized at"))
	var far: String = _text(await _assistant.use_tool("plan_scale", {"subject": "a slab tower",
		"longest_metres": 259, "studs": {"read": 3}, "outline": slab}))
	_ok(far.contains("That is 13 studs along its longest side, where the scale above says 34: "
		+ "the sizes are at studs=. If 3 is the whole model's longest side, not the part read, "
		+ "give {\"longest\": 3}."), "{\"read\": 3} far from the scale says both, and how to "
			+ "say the other: %s" % _line_with(far, "That is"))
	_ok(longest.contains("sized at studs= {\"longest\": 6}: 6 studs along its longest side: 15 "
		+ "plates tall (6 studs), 1 stud at its widest") and longest.contains("If 6 is the part you read, not the "
			+ "whole model, give {\"read\": 6}"), "{\"longest\": 6} is the whole tower 6 studs "
		+ "tall: %s" % _line_with(longest, "sized at"))
	var box: String = _text(await _assistant.use_tool("plan_scale", {"subject": "a slab tower",
		"longest_metres": 259, "studs": {"box": [12, 13]}, "outline": slab}))
	_ok(box.contains("sized at the brief's "
		+ "box, 12 x 13 studs, as a bound: its depth fits the box's 13, and its widest face is 6 "
		+ "studs, from its own plan (deep 2.2), not the box's 12") and box.contains("6 studs at "
			+ "its widest and 13 deep"), "{\"box\": [12, 13]} of a thing deeper than wide: its "
		+ "depth the box's long side, its face its own: %s" % _line_with(box, "sized at"))
	var bare: String = _text(await _assistant.use_tool("plan_scale", {"subject": "a slab tower",
		"longest_metres": 259, "studs": [6], "outline": slab}))
	_ok(bare.contains("studs= names what it measures") and bare.contains("[6] says none, so it "
		+ "was not taken") and bare.contains("sized at the scale above"),
		"a bare number says no measure: not taken, the forms said, the sizes at the scale's")
	var scale: String = _text(await _assistant.use_tool("plan_scale", {"subject": "a slab tower",
		"longest_metres": 259, "outline": slab}))
	_ok(scale.contains("sized at the scale above") and not scale.contains("where the scale above "
		+ "says"), "with no studs=, the sizes are the scale's: %s" % _line_with(scale, "sized at"))


# -- refused ------------------------------------------------------------------------


func _readings_refused() -> void:
	print("\nreadings that are wrong are refused, saying what is wrong, and nothing is held")
	var five: Array = [0.1, 0.2, 0.2, 0.1, 0.1]
	var wrong: Array = [
		[{"heights": five}, "from= is the side of your model"],
		[{"from": "top", "heights": five}, "from= is the side of your model"],
		[{"from": "front"}, "Give one of heights="],
		[{"from": "front", "heights": [0.1], "widths": [0.1]}, "Give one of heights="],
		[{"from": "front", "heights": [0.1, 0.2]}, "heights= has 2 numbers"],
		[{"from": "front", "heights": [0, 0, 0, 0, 0]}, "are all 0"],
		[{"from": "front", "heights": [0.1, 0.2, "tall", 0.1, 0.1]}, "holds only numbers"],
		[{"from": "front", "widths": five, "bottoms": [0, 0, 0, 0, 0]},
			"bottoms= goes with heights="],
		[{"from": "front", "heights": five, "bottoms": [0, 0.3, 0, 0, 0]}, "number 2 is over it"],
		[{"from": "front", "widths": five, "steps": [0.5, 0.3]}, "each past the one before"],
		[{"from": "front", "widths": five, "steps": [{"at": 0.5, "side": "up"}]},
			"left, right or both, not \"up\""],
		[{"from": "front", "widths": five, "plan": "star"}, "plan= is its shape from above"],
		[{"from": "front", "heights": five, "breaks": "wheels"}, "breaks= is what breaks"],
		[{"from": "front", "heights": five, "breaks": [{"from": 0, "to": 0.2, "bottom": 0,
			"top": 0.1}]}, "a break says what it is"],
		[{"from": "front", "heights": five, "breaks": [{"name": "wheel", "from": 0.3, "to": 0.2,
			"bottom": 0, "top": 0.1}]}, "its to= is past its from="],
		[{"from": "front", "heights": five, "breaks": [{"name": "wheel", "from": 0.1,
			"to": 0.2, "top": 0.1}]}, "wheel's bottom= is a share"],
		[{"from": "front", "heights": five, "storeys": 2.5}, "storeys= is how many storeys"],
		[{"from": "front", "heights": five, "storeys": "three"}, "storeys= is how many storeys"],
	]
	var refused: int = 0
	for one: Array in wrong:
		_assistant._outline_plan = null
		var answer: String = _text(await _assistant.use_tool("plan_scale", {"subject": "x",
			"longest_metres": 10, "outline": one[0]}))
		if answer.contains("The outline was not read: ") and answer.contains(str(one[1])) \
				and _assistant._outline_plan == null:
			refused += 1
		else:
			print("    not refused as it should be: %s -> %s" % [JSON.stringify(one[0]),
				_line_with(answer, "outline")])
	_ok(refused == wrong.size(), "%d of %d wrong readings refused, each saying what is wrong"
		% [refused, wrong.size()])


# -- reading ---------------------------------------------------------------------------


func _clear() -> void:
	_world.clear()
	_builder.lattice.clear()


func _open(number: String) -> bool:
	_clear()
	var path: String = SETS.path_join(number + ".mpd")
	var opened: Dictionary = _store.open_text(FileAccess.get_file_as_string(path), path.get_file())
	return _world.brick_count() > 0 and str(opened.get("error", "")).is_empty()


func _truck() -> Dictionary:
	var bricks: Array = []
	for x: int in [0, 4, 8]:
		bricks.append({"part": "3001", "color": 1, "x": x, "y": 0, "z": 0, "rot": 0})
	for x: int in [0, 4]:
		bricks.append({"part": "3001", "color": 1, "x": x, "y": 3, "z": 0, "rot": 0})
	bricks.append({"part": "3001", "color": 4, "x": 8, "y": 3, "z": 0, "rot": 0})
	return {"name": "truck", "description": "a small truck", "bricks": bricks,
		"assemblies": [], "features": []}


## [param bricks] seen from the front: each column's top, each row's left and
## right, in lattice cells from the ground.
func _seen(bricks: Array) -> Seen:
	var seen := Seen.new()
	var flat: Array = []
	var low := Vector2i(1 << 30, 1 << 30)
	var high := Vector2i(-(1 << 30), -(1 << 30))
	for raw: Variant in bricks:
		var brick: BrickWorld.Brick = raw
		var packed: PackedInt32Array = _builder.lattice.boxes_of(brick.id)
		if packed.is_empty():
			packed = _builder.boxes_for(_library.mesh_for(brick.part_id), brick.transform)
		for n: int in range(0, packed.size(), 6):
			flat.append([packed[n], packed[n + 3], packed[n + 1], packed[n + 4]])
			low = low.min(Vector2i(packed[n], packed[n + 1]))
			high = high.max(Vector2i(packed[n + 3], packed[n + 4]))
	if flat.is_empty():
		return seen
	seen.cols = high.x - low.x
	seen.rows = high.y - low.y
	seen.top.resize(seen.cols)
	seen.top.fill(0)
	seen.left.resize(seen.rows)
	seen.left.fill(-1)
	seen.right.resize(seen.rows)
	seen.right.fill(0)
	var ground: int = mini(low.y, 0)
	for box: Array in flat:
		var c0: int = int(box[0]) - low.x
		var c1: int = int(box[1]) - low.x
		for c: int in range(c0, c1):
			seen.top[c] = maxi(seen.top[c], int(box[3]) - ground)
		for r: int in range(int(box[2]) - low.y, int(box[3]) - low.y):
			seen.left[r] = c0 if seen.left[r] < 0 else mini(seen.left[r], c0)
			seen.right[r] = maxi(seen.right[r], c1)
	return seen


## The first and last filled column (heights) or row (widths).
func _span(seen: Seen, mode: String) -> Vector2i:
	var first: int = -1
	var last: int = -1
	for n: int in (seen.cols if mode == "heights" else seen.rows):
		var filled: bool = seen.top[n] > 0 if mode == "heights" else seen.left[n] >= 0
		if filled:
			if first < 0:
				first = n
			last = n
	return Vector2i(first, last)


## Each tenth's top (heights) or width (widths), LDU, read over BAND cells.
func _samples(seen: Seen, mode: String) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var span: Vector2i = _span(seen, mode)
	if span.x < 0:
		return out
	for n: int in 11:
		var at: int = clampi(span.x + roundi(float(n) / 10.0 * float(span.y - span.x)),
			span.x, span.y)
		if mode == "heights":
			var most: int = 0
			for c: int in range(maxi(span.x, at - BAND), mini(span.y, at + BAND) + 1):
				most = maxi(most, seen.top[c])
			out.append(float(most) * CELL)
		else:
			var left: int = -1
			var right: int = 0
			for r: int in range(maxi(span.x, at - BAND), mini(span.y, at + BAND) + 1):
				if seen.left[r] >= 0:
					left = seen.left[r] if left < 0 else mini(left, seen.left[r])
					right = maxi(right, seen.right[r])
			out.append(float(right - left) * CELL if left >= 0 else 0.0)
	return out


## What a reader who read [param seen] exactly would give plan_scale's outline=:
## shares of the length (heights) or of the height (widths), as a session
## reads them, to three places.
func _reading(seen: Seen, mode: String) -> Dictionary:
	var span: Vector2i = _span(seen, mode)
	var whole: float = float(span.y - span.x + 1) * CELL
	var values: Array = []
	for one: float in _samples(seen, mode):
		values.append(snappedf(one / whole, 0.001))
	return {"from": "front", mode: values}


## The level and slope lines under [param heading] in [param text]: each
## {"from", "to", "slope", "plates"} for a level, or a slope's "low" and
## "high" over its ends and its highest or lowest, the plates as built.
func _pieces(text: String, heading: String) -> Array:
	var out: Array = []
	var at: int = text.find(heading)
	if at < 0:
		return out
	var lines: PackedStringArray = text.substr(at).split("\n")
	for n: int in range(1, lines.size()):
		var line: String = lines[n]
		if not line.begins_with("  x ") and not line.begins_with("  z "):
			break
		var colon: int = line.find(": ")
		var span: PackedStringArray = line.substr(4, colon - 4).split(" to ")
		if span.size() != 2:
			break
		var piece: Dictionary = {"from": float(span[0]), "to": float(span[1]),
			"slope": line.contains("a slope or a curve")}
		var numbers: Array = []
		for word: String in line.substr(colon + 2).replace(",", " ").split(" ", false):
			if word.is_valid_float() and line.substr(colon + 2).contains(word + " plates"):
				numbers.append(float(word))
		if numbers.is_empty():
			break
		piece["plates"] = numbers[0]
		piece["low"] = Array(numbers).min()
		piece["high"] = Array(numbers).max()
		out.append(piece)
	return out


## Whether [param pieces] hold [param plates] at [param at] studs along, within
## [param slack] plates: the level there, or the slope's range.
func _held(pieces: Array, at: float, plates: float, slack: float) -> bool:
	for piece: Dictionary in pieces:
		if at < float(piece["from"]) - 0.5 or at > float(piece["to"]) + 0.5:
			continue
		if piece["slope"]:
			if plates >= float(piece["low"]) - slack and plates <= float(piece["high"]) + slack:
				return true
		elif absf(plates - float(piece["plates"])) <= slack:
			return true
	return false


## A tall thing's tiers as said: Vector3(y0, y1, studs wide), or its one level.
func _tiers(text: String) -> Array:
	var out: Array = []
	for line: String in text.split("\n"):
		var plain: String = line.strip_edges()
		var dot: int = plain.find(". y ")
		if dot > 0 and plain.substr(0, dot).is_valid_int():
			var ys: PackedStringArray = plain.substr(dot + 4, plain.find(",") - dot - 4).split(" to ")
			var wide: Array = _numbers_in(plain, "plates tall: ", " studs wide")
			if ys.size() == 2 and not wide.is_empty():
				out.append(Vector3(float(ys[0]), float(ys[1]), float(wide[0])))
	if out.is_empty():
		var tall: Array = _numbers_in(text, "Up its height (", " plates")
		var wide: Array = _numbers_in(text, "one level: ", " studs wide")
		if not tall.is_empty() and not wide.is_empty():
			out.append(Vector3(0.0, float(tall[0]), float(wide[0])))
	return out


## The numbers in [param text] between [param before] and [param after], each
## time both are there.
func _numbers_in(text: String, before: String, after: String) -> Array:
	var out: Array = []
	var at: int = text.find(before)
	while at >= 0:
		var end: int = text.find(after, at + before.length())
		if end < 0:
			break
		var number: String = text.substr(at + before.length(), end - at - before.length())
		if number.is_valid_float():
			out.append(float(number))
		at = text.find(before, end)
	return out


func _line_with(text: String, word: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(word):
			return line.strip_edges().left(300)
	return "(no line with \"%s\")" % word


func _lines_with(text: String, word: String) -> String:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if line.contains(word):
			out.append("    " + line.strip_edges().left(240))
	return "\n".join(out)


func _text(answer: Variant) -> String:
	if answer is Array:
		var texts := PackedStringArray()
		for block: Variant in answer:
			if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
				texts.append(str((block as Dictionary)["text"]))
		return "\n\n".join(texts)
	return str(answer)


func _ok(passed: bool, said: String) -> bool:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
	return passed
