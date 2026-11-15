## Building to the outline from the first mass: plan_scale takes the real
## thing's outline read off a photograph, and the app's own shapes take it as
## their profile, so the first build already has it (OutlinePlan).
##
##   godot --headless --path . --script src/dev/outline_build_probe.gd
##
## Five sets of the tune half, opened from their own LDraw files, each read as
## a perfect reader would read its photograph (design20's Silhouette, here
## [method _seen] and [method _reading]): along its length from the front,
## and up its height from the front. Each reading given to plan_scale at the
## set's own size; the mass its answer hands sent as it is; the mass read the
## same way and laid over the set's: within two plates at each tenth along,
## a stud at each tenth up. Then the steps (a tower's setbacks, each a tier of
## its own) and the plans from above (a Y, round, a T), the "outline" each of
## the app's shapes takes (an extrude over a length of its own, a loft, a
## revolve, tiers, a prism's storeys), readings refused with what is wrong,
## and the ask before the first build: in how_real_sets_build_this and the
## first submit_design, once each, never once an outline is held. No graphics
## card: the outline is the lattice's.
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
## Where the last _follows found the mass off its outline, for a failure.
var _missed: Array = []
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _store: ModelStore


## A model's outline from one side, in lattice cells, as Silhouette.of_bricks
## read it: column 0 the left of the view, row 0 the lowest cell.
class Seen extends RefCounted:
	var cols: int = 0
	var rows: int = 0
	var floor_cells: int = 0
	## The cell its first column and row are, in the lattice's own.
	var low_x: int = 0
	var low_y: int = 0
	var top := PackedInt32Array()
	var bottom := PackedInt32Array()
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
	await _steps_and_plans()
	await _each_shape_takes_it()
	await _readings_refused()
	print("\n%s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- the ask --------------------------------------------------------------------


func _asked_before_the_first_build() -> void:
	print("\nasked before the first build, once each, never once an outline is held")
	_clear()
	var how: String = _text(await _assistant.use_tool("how_real_sets_build_this",
		{"subject": "fire engine"}))
	_ok(how.contains("Before the first build: Build to the real thing's outline")
		and how.contains("plan_scale as outline="), "how_real_sets_build_this asks for it")
	how = _text(await _assistant.use_tool("how_real_sets_build_this", {"subject": "fire engine"}))
	_ok(not how.contains("Before the first build"), "...once: asked again, it does not")
	var scaled: String = _text(await _assistant.use_tool("plan_scale",
		{"subject": "fire engine", "longest_metres": 10}))
	_ok(scaled.contains("minifigure") and scaled.contains("give it to plan_scale as outline="),
		"plan_scale with no outline answers the scale and asks for it")
	var built: String = _text(await _assistant.use_tool("submit_design", _truck()))
	_ok(built.begins_with("Built.") and built.contains("Its mass is its own")
		and built.contains("The answer is this mass in that outline"),
		"the first build of a new design with none read asks, offering the mass in it")
	_clear()
	built = _text(await _assistant.use_tool("submit_design", _truck()))
	_ok(not built.contains("Its mass is its own"), "...once")

	_assistant._outline_asked = {}
	await _assistant.use_tool("plan_scale", {"subject": "fire engine", "longest_metres": 10,
		"studs": [30, 12], "outline": {"from": "front",
			"heights": [0.2, 0.25, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.25, 0.2]}})
	how = _text(await _assistant.use_tool("how_real_sets_build_this", {"subject": "fire engine"}))
	_ok(not how.contains("Before the first build"), "with an outline held, nothing asks")
	_clear()
	built = _text(await _assistant.use_tool("submit_design", _truck()))
	_ok(not built.contains("Its mass is its own"), "...nor the first build")
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
	var bricks: Array = _world.bricks()
	var front: Seen = _seen(bricks, "front")
	_ok(front.cols > 0, "%d parts, %d x %d cells from the front" % [bricks.size(), front.cols,
		front.rows])
	var heights: Dictionary = _reading(front, "heights")
	var widths: Dictionary = _reading(front, "widths")
	var long: float = roundf(float(_span(front, "heights").y - _span(front, "heights").x + 1)
		* CELL / STUD)
	var wide: float = roundf(Array(_samples(front, "widths")).max() / STUD)

	# Along its length: the mass the answer hands, sent as it is.
	var answer: String = _text(await _assistant.use_tool("plan_scale", {"subject": number,
		"longest_metres": 1, "studs": [long], "outline": heights}))
	var mass: Dictionary = _mass_in(answer)
	_ok(answer.contains("Build the first mass to it") and not mass.is_empty()
		and JSON.stringify(mass).contains("\"profile\":\"outline\""),
		"heights: the answer hands the first mass as a shape, its profile the outline")
	_like(front, await _built([mass], "front"), _resolved(mass), "heights",
		"%s studs long" % OutlinePlan._n(long))

	# Up its height: tiers to the widths.
	answer = _text(await _assistant.use_tool("plan_scale", {"subject": number,
		"longest_metres": 1, "studs": [wide], "outline": widths}))
	mass = _mass_in(answer)
	_ok(JSON.stringify(mass).contains("\"levels\":\"outline\""),
		"widths: the answer's mass is tiers, its levels the outline")
	_like(front, await _built([mass], "front"), _resolved(mass), "widths",
		"%s studs at its widest" % OutlinePlan._n(wide))


## Whether [param laid] follows the outline as the app resolved it ([param
## solid]): each stud's top within 2 plates of it (heights), all of them; or
## each plate's width within a stud (widths), at 85 in 100 — Shapes hangs a
## flat flank's tiles on side studs from the first course that has them, so
## a tier's foot stands a stud or two in for two to four plates, and where a
## tier narrows the flank's last band can stop short. And that it stands like
## [param set]: the area of the two sides seen from the front, the two laid
## one on the other, is 70% shared, as eleven samples of an outline can make it.
func _like(set: Seen, laid: Seen, solid: Dictionary, mode: String, size: String) -> void:
	var follows: float = _follows(laid, solid)
	var shared: float = _overlap(set, laid, mode)
	if not _ok(follows >= (1.0 if mode == "heights" else 0.85), "%s at %s: the mass follows the outline it was given, %d%% of "
		% [mode, size, roundi(follows * 100.0)] + "its %s of it" % ("studs' tops within 2 plates"
			if mode == "heights" else "plates' widths within a stud")):
		print("    missed (stud or plate: laid/outline): %s" % " ".join(_missed.slice(0, 24)))
	_ok(shared >= 0.7, "...and stands like the set: %d%% of their two sides shared"
		% roundi(shared * 100.0))


## The solid [param mass] resolves to with the outline held.
func _resolved(mass: Dictionary) -> Dictionary:
	var args: Dictionary = _assistant._with_outline(_design([mass.duplicate(true)]), [], [])
	return ((args["patterns"] as Array)[0] as Dictionary)["solids"][0]


## The share of [param laid]'s studs or plates that follow [param solid]: an
## extrude's top against its profile, tiers' widths against their levels.
## Each read at its stud's or plate's middle, where the shape reads the
## solid: a profile rising 15 plates a stud is a stud's column, one height.
func _follows(laid: Seen, solid: Dictionary) -> float:
	_missed.clear()
	var good: int = 0
	var all: int = 0
	var across: int = roundi(STUD / CELL)
	var up: int = roundi(PLATE / CELL)
	if solid.has("extrude"):
		var profile: Array = solid["extrude"]["profile"]
		for c: int in laid.cols:
			var cell: int = c + laid.low_x
			var x: float = float(floori(float(cell) / float(across))) + 0.5
			if posmod(cell, across) != across / 2 or laid.top[c] <= 0 \
					or x < float(profile[0][0]) or x > float(profile[-1][0]):
				continue
			all += 1
			if absf(float(laid.top[c]) * CELL / PLATE - _along(profile, x)) <= 2.0:
				good += 1
			else:
				_missed.append("%s:%s/%s" % [OutlinePlan._n(x - 0.5), OutlinePlan._n(
					float(laid.top[c]) * CELL / PLATE), OutlinePlan._n(_along(profile, x))])
	elif solid.has("tiers"):
		var levels: Array = solid["tiers"]["levels"]
		for r: int in laid.rows:
			var cell: int = r + laid.low_y
			if posmod(cell, up) != up / 2 or laid.left[r] < 0:
				continue
			all += 1
			var y: float = float(floori(float(cell) / float(up))) + 0.5
			var wide: float = float(laid.right[r] - laid.left[r]) * CELL / STUD
			if absf(wide - _level_at(levels, y)) <= 1.0:
				good += 1
			else:
				_missed.append("%s:%s/%s" % [OutlinePlan._n(y - 0.5), OutlinePlan._n(wide),
					OutlinePlan._n(_level_at(levels, y))])
	return float(good) / float(maxi(all, 1))


## [param profile] ([[along, plates], ...]) at [param x], linear between points.
func _along(profile: Array, x: float) -> float:
	for n: int in profile.size() - 1:
		var a: Array = profile[n]
		var b: Array = profile[n + 1]
		if x <= float(b[0]):
			var span: float = float(b[0]) - float(a[0])
			return float(b[1]) if span <= 0.0 else lerpf(float(a[1]), float(b[1]),
				(x - float(a[0])) / span)
	return float((profile[-1] as Array)[1])


## The width along x of [param levels] at [param y] plates: at a step, the
## level above.
func _level_at(levels: Array, y: float) -> float:
	for n: int in levels.size() - 1:
		var a: Array = levels[n]
		var b: Array = levels[n + 1]
		if y < float(b[0]) and float(b[0]) > float(a[0]):
			return lerpf(float(a[1]), float(b[1]), (y - float(a[0])) / (float(b[0]) - float(a[0])))
	return float((levels[-1] as Array)[1])


## How much of the two sides from the front is shared, over 50 slices of each
## laid one on the other: sum of the lesser over the sum of the greater.
func _overlap(set: Seen, laid: Seen, mode: String) -> float:
	var a: Vector2i = _span(set, mode)
	var b: Vector2i = _span(laid, mode)
	if a.x < 0 or b.x < 0:
		return 0.0
	var lesser: float = 0.0
	var greater: float = 0.0
	for k: int in 50:
		var share: float = (float(k) + 0.5) / 50.0
		var one: float = _slice(set, mode, a.x + roundi(share * float(a.y - a.x)))
		var two: float = _slice(laid, mode, b.x + roundi(share * float(b.y - b.x)))
		lesser += minf(one, two)
		greater += maxf(one, two)
	return lesser / greater if greater > 0.0 else 0.0


## A column's top (heights) or a row's width (widths), LDU.
func _slice(seen: Seen, mode: String, at: int) -> float:
	if mode == "heights":
		return float(seen.top[at]) * CELL
	return float(seen.right[at] - seen.left[at]) * CELL if seen.left[at] >= 0 else 0.0


# -- steps and plans ----------------------------------------------------------------


func _steps_and_plans() -> void:
	print("\nsteps and plans: a tower's setbacks, each a tier of its own; a Y, round, a T")
	# A tower read smooth, the way a reader at tenths sees many setbacks, and
	# the same with its steps counted: 6 setbacks, 7 tiers.
	var widths: Array = [0.3, 0.27, 0.24, 0.21, 0.18, 0.15, 0.12, 0.09, 0.06, 0.04, 0.02]
	var steps: Array = [0.14, 0.28, 0.42, 0.56, 0.7, 0.84]
	var answer: String = _text(await _assistant.use_tool("plan_scale", {"subject": "tower",
		"longest_metres": 300, "studs": [16, 16], "outline": {"from": "front",
			"widths": widths, "steps": steps}}))
	_ok(answer.contains("In 7 tiers, ground first"), "6 steps read: the answer names 7 tiers")
	var tiered: Dictionary = _mass_in(answer)
	var levels: Array = _resolved(tiered)["tiers"]["levels"]
	_ok(levels.size() == 14 and _width_count(levels) == 7, "...its levels 7 widths, a stud "
		+ "each side between them: %s studs" % ", ".join(_widths_of(levels)))
	var follows: float = _follows(await _built([tiered], "front"), _resolved(tiered))
	_ok(follows >= 0.85, "...and the mass laid follows them, %d%% of its plates within a stud"
		% roundi(follows * 100.0))
	var smooth: Seen = await _built([_mass_in(_text(await _assistant.use_tool("plan_scale",
		{"subject": "tower", "longest_metres": 300, "studs": [20, 20], "outline": {
			"from": "front", "widths": widths}})))], "front")
	_ok(_width_runs(smooth).size() > 7, "read smooth, it narrows a stud each side at a time, "
		+ "course by course (%d widths)" % _width_runs(smooth).size())

	# The plans, from above: each laid at the foot of a 12-stud tier.
	var foot: Dictionary = await _foot_of("Y")
	_ok(foot.get(Vector2i(6, 11), false) and foot.get(Vector2i(1, 2), false)
		and foot.get(Vector2i(10, 2), false) and not foot.get(Vector2i(6, 0), false)
		and not foot.get(Vector2i(0, 11), false) and not foot.get(Vector2i(11, 11), false),
		"a Y: a wing to the front and two back at its corners, its back middle and front "
		+ "corners empty (%d of 144 studs)" % foot.size())
	foot = await _foot_of("round")
	_ok(foot.get(Vector2i(6, 6), false) and not foot.get(Vector2i(0, 0), false)
		and not foot.get(Vector2i(11, 0), false) and not foot.get(Vector2i(0, 11), false)
		and not foot.get(Vector2i(11, 11), false) and foot.size() >= 100 and foot.size() <= 132,
		"round: its four corners empty, %d of 144 studs touched (a disc's middles are 112)"
			% foot.size())
	foot = await _foot_of("T")
	_ok(foot.get(Vector2i(0, 0), false) and foot.get(Vector2i(11, 0), false)
		and foot.get(Vector2i(6, 11), false) and not foot.get(Vector2i(0, 11), false)
		and not foot.get(Vector2i(11, 11), false),
		"a T: its bar along the back, its stem to the front (%d studs)" % foot.size())


## The studs a 12-stud tier with [param plan] stands on.
func _foot_of(plan: String) -> Dictionary:
	_clear()
	await _assistant.use_tool("submit_design", _design([{"pattern": "shape",
		"at": {"x": 0, "y": 0, "z": 0}, "color": 71, "solids": [{"tiers": {"centre": [6, 6],
			"plan": plan, "levels": [[0, 12, 12], [6, 12, 12]]}}]}]))
	var foot: Dictionary = {}
	for brick: BrickWorld.Brick in _assistant._bricks_inside({}):
		var packed: PackedInt32Array = _builder.lattice.boxes_of(brick.id)
		for n: int in range(0, packed.size(), 6):
			if packed[n + 1] > 4:
				continue
			for cx: int in range(packed[n], packed[n + 3]):
				for cz: int in range(packed[n + 2], packed[n + 5]):
					foot[Vector2i(floori(cx * CELL / STUD), floori(cz * CELL / STUD))] = true
	return foot


# -- each shape takes it ----------------------------------------------------------------


func _each_shape_takes_it() -> void:
	print("\neach of the app's shapes takes the outline as its profile")
	# A sledge's runners touch the ground at its ends; its underside is lifted
	# between them, as read.
	var car: Array = [0.12, 0.15, 0.16, 0.16, 0.24, 0.27, 0.27, 0.24, 0.17, 0.15, 0.13]
	var sills: Array = [0.0, 0.0, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.0, 0.0]
	await _assistant.use_tool("plan_scale", {"subject": "a car", "longest_metres": 4.5,
		"studs": [10, 30], "outline": {"from": "front", "heights": car, "bottoms": sills,
			"picture": "Car side view.jpg"}})
	_ok(_assistant._outline_plan != null and is_equal_approx(_assistant._outline_plan.length, 30.0)
		and is_equal_approx(_assistant._outline_plan.across, 10.0),
		"studs=[10, 30]: held 30 studs long and 10 across")
	# An extrude over a length of its own: the outline stretched to it.
	var laid: Seen = await _built([{"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0},
		"color": 0, "solids": [{"extrude": {"along": "x", "from": 0, "width": 8,
			"profile": "outline", "under": "outline", "length": 40}}]}], "front")
	var long: Vector2i = _span(laid, "heights")
	var top: int = 0
	for c: int in laid.cols:
		top = maxi(top, laid.top[c])
	_ok(absf(float(long.y - long.x + 1) * CELL / STUD - 40.0) <= 1.0
		and absf(float(top - laid.floor_cells) * CELL - 0.27 * 40.0 * STUD) <= 2.0 * PLATE,
		"an extrude's \"profile\": \"outline\" over \"length\": 40 lays it 40 studs long, its "
			+ "roof %s plates up (0.27 of 40 studs is 27)" % OutlinePlan._n(snappedf(
				float(top - laid.floor_cells) * CELL / PLATE, 0.5)))
	var said: String = " ".join(PackedStringArray(_assistant._pattern_advice))
	_ok(said.contains("Its extrude's top is the outline read off \"Car side view.jpg\""),
		"...and the answer says so")
	# The sills: off the ground between the wheels' places.
	var lifted: int = 0
	for c: int in range(long.x + 4, long.y - 4):
		if laid.bottom[c] - laid.floor_cells >= 1:
			lifted += 1
	_ok(lifted >= (long.y - long.x - 8) / 2, "...its underside off the ground: %d of %d columns"
		% [lifted, long.y - long.x - 8])
	# A loft's sections, to the same outline.
	laid = await _built([{"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 0,
		"solids": [{"loft": {"along": "x", "width": 10, "sections": "outline", "round": 0.3}}]}],
		"front")
	long = _span(laid, "heights")
	_ok(absf(float(long.y - long.x + 1) * CELL / STUD - 30.0) <= 1.0,
		"a loft's \"sections\": \"outline\" lays it at the outline's own 30 studs")
	# A widths reading taken by an extrude is refused, saying what takes it.
	await _assistant.use_tool("plan_scale", {"subject": "a lighthouse", "longest_metres": 30,
		"studs": [8], "outline": {"from": "front", "widths": [1, 0.9, 0.8, 0.7, 0.6, 0.55, 0.5,
			0.45, 0.4, 0.5, 0.2], "plan": "round"}})
	var refused: String = _text(await _assistant.use_tool("check_design", _design([{
		"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15, "solids": [{"extrude": {
			"along": "x", "width": 8, "profile": "outline"}}]}])))
	_ok(refused.contains("a tall thing's widths up its height, which tiers or a revolve up y takes"),
		"an extrude given a tall thing's widths is told what takes them: %s"
			% _line_with(refused, "outline"))
	# A revolve up y.
	laid = await _built([{"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15,
		"solids": [{"revolve": {"axis": "y", "centre": [4, 0, 4], "profile": "outline"}}]}],
		"front")
	var up: Vector2i = _span(laid, "widths")
	_ok(laid.rows > 0 and absf(float(up.y - up.x + 1) * CELL - 20.0 * PLATE) <= 4.0
		* PLATE, "a revolve's \"profile\": \"outline\" stands it %s plates tall (8 studs at its "
			% OutlinePlan._n(float(up.y - up.x + 1) * CELL / PLATE) + "widest: 20 plates)")
	# A prism's storeys, to a reading in three tiers.
	await _assistant.use_tool("plan_scale", {"subject": "a tower", "longest_metres": 100,
		"studs": [16], "outline": {"from": "front", "widths": [0.4, 0.4, 0.4, 0.4, 0.3, 0.3, 0.3,
			0.2, 0.2, 0.2, 0.2], "steps": [0.35, 0.65]}})
	_clear()
	var prism: String = _text(await _assistant.use_tool("submit_design", _design([{
		"pattern": "prism", "at": {"x": 12, "y": 0, "z": 12}, "sides": 8, "radius": 10,
		"color": 71, "storeys": {"outline": true}}])))
	_ok(prism.begins_with("Built.") and prism.contains("stands in 3 storeys")
		and prism.contains("Its storeys are the outline read: 3, radius 10, 8, 5"),
		"a prism's \"storeys\": {\"outline\": true} stands in the outline's 3 tiers, radius 10, "
			+ "8 and 5: %s" % _line_with(prism, "storeys"))


# -- refused ------------------------------------------------------------------------


func _readings_refused() -> void:
	print("\nreadings that are wrong are refused, saying what is wrong, and nothing is held")
	_assistant._outline_plan = null
	var wrong: Array = [
		[{"heights": [0.1, 0.2, 0.2, 0.1, 0.1]}, "from= is the side of your model"],
		[{"from": "top", "heights": [0.1, 0.2, 0.2, 0.1, 0.1]}, "from= is the side of your model"],
		[{"from": "front"}, "Give one of heights="],
		[{"from": "front", "heights": [0.1], "widths": [0.1]}, "Give one of heights="],
		[{"from": "front", "heights": [0.1, 0.2]}, "heights= has 2 numbers"],
		[{"from": "front", "heights": [0, 0, 0, 0, 0]}, "are all 0"],
		[{"from": "front", "heights": [0.1, 0.2, "tall", 0.1, 0.1]}, "holds only numbers"],
		[{"from": "front", "widths": [0.1, 0.2, 0.2, 0.1, 0.1], "bottoms": [0, 0, 0, 0, 0]},
			"bottoms= goes with heights="],
		[{"from": "front", "heights": [0.1, 0.2, 0.2, 0.1, 0.1], "bottoms": [0, 0.3, 0, 0, 0]},
			"number 2 is over it"],
		[{"from": "front", "widths": [0.1, 0.2, 0.2, 0.1, 0.1], "steps": [0.5, 0.3]},
			"each past the one before"],
		[{"from": "front", "widths": [0.1, 0.2, 0.2, 0.1, 0.1], "plan": "star"},
			"plan= is its shape from above"],
	]
	var refused: int = 0
	for one: Array in wrong:
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
	var none: String = _text(await _assistant.use_tool("check_design", _design([{
		"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15, "solids": [{"extrude": {
			"along": "x", "width": 8, "profile": "outline"}}]}])))
	_ok(none.contains("none has been read for this design"),
		"\"outline\" with none read is refused, saying to read it first: %s"
			% _line_with(none, "outline"))


# -- reading and building -------------------------------------------------------------


func _clear() -> void:
	_world.clear()
	_builder.lattice.clear()


func _open(number: String) -> bool:
	_clear()
	var path: String = SETS.path_join(number + ".mpd")
	var opened: Dictionary = _store.open_text(FileAccess.get_file_as_string(path), path.get_file())
	return _world.brick_count() > 0 and str(opened.get("error", "")).is_empty()


func _design(patterns: Array) -> Dictionary:
	return {"name": "mass", "description": "a mass to the outline", "bricks": [],
		"patterns": patterns, "assemblies": [], "features": []}


func _truck() -> Dictionary:
	var bricks: Array = []
	for x: int in [0, 4, 8]:
		bricks.append({"part": "3001", "color": 1, "x": x, "y": 0, "z": 0, "rot": 0})
	for x: int in [0, 4]:
		bricks.append({"part": "3001", "color": 1, "x": x, "y": 3, "z": 0, "rot": 0})
	bricks.append({"part": "3001", "color": 4, "x": 8, "y": 3, "z": 0, "rot": 0})
	return {"name": "truck", "description": "a small truck", "bricks": bricks,
		"assemblies": [], "features": []}


## [param patterns] built on a bare baseplate, then read from [param side].
func _built(patterns: Array, side: String) -> Seen:
	_clear()
	var answer: String = _text(await _assistant.use_tool("submit_design", _design(patterns)))
	if not answer.begins_with("Built."):
		print("    not built: %s" % answer.left(400))
		return Seen.new()
	return _seen(_assistant._bricks_inside({}), side)


## The pattern the answer hands to send as it is: the JSON line after "Build
## the first mass to it".
func _mass_in(answer: String) -> Dictionary:
	var at: int = answer.find("Build the first mass to it")
	if at < 0:
		return {}
	for line: String in answer.substr(at).split("\n"):
		if line.begins_with("{") and line.contains("\"pattern\""):
			var parsed: Variant = JSON.parse_string(line)
			return parsed if parsed is Dictionary else {}
	return {}


func _seen(bricks: Array, side: String) -> Seen:
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
			var across: Vector2i = Vector2i(packed[n], packed[n + 3]) if side == "front" \
				else Vector2i(packed[n + 2], packed[n + 5])
			flat.append([across.x, across.y, packed[n + 1], packed[n + 4]])
			low = low.min(Vector2i(across.x, packed[n + 1]))
			high = high.max(Vector2i(across.y, packed[n + 4]))
	if flat.is_empty():
		return seen
	seen.cols = high.x - low.x
	seen.rows = high.y - low.y
	seen.low_x = low.x
	seen.low_y = low.y
	seen.floor_cells = 0
	seen.top.resize(seen.cols)
	seen.top.fill(0)
	seen.bottom.resize(seen.cols)
	seen.bottom.fill(-1)
	seen.left.resize(seen.rows)
	seen.left.fill(-1)
	seen.right.resize(seen.rows)
	seen.right.fill(0)
	# Heights from the ground (y 0), so a mass and a set read alike.
	var ground: int = mini(low.y, 0)
	for box: Array in flat:
		var c0: int = int(box[0]) - low.x
		var c1: int = int(box[1]) - low.x
		var r0: int = int(box[2]) - low.y
		var r1: int = int(box[3]) - low.y
		for c: int in range(c0, c1):
			seen.top[c] = maxi(seen.top[c], int(box[3]) - ground)
			var b: int = int(box[2]) - ground
			seen.bottom[c] = b if seen.bottom[c] < 0 else mini(seen.bottom[c], b)
		for r: int in range(r0, r1):
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
func _samples(seen: Seen, mode: String, count: int = 11) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var span: Vector2i = _span(seen, mode)
	if span.x < 0:
		return out
	for n: int in count:
		var at: int = clampi(span.x + roundi(float(n) / float(count - 1) * float(span.y - span.x)),
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


## What a reader who read [param seen] exactly would give plan_scale's outline=.
func _reading(seen: Seen, mode: String) -> Dictionary:
	var span: Vector2i = _span(seen, mode)
	var whole: float = float(span.y - span.x + 1) * CELL
	var values: Array = []
	for one: float in _samples(seen, mode):
		values.append(snappedf(one / whole, 0.001))
	return {"from": "front", mode: values}














## The widths up the height, in runs: one entry a run of rows of one width.
## Each tier's width along x, ground first.
func _widths_of(levels: Array) -> Array:
	var out: Array = []
	for n: int in range(0, levels.size(), 2):
		out.append(OutlinePlan._n(float((levels[n] as Array)[1])))
	return out


## How many different widths, each 2 studs (a stud each side) from the next.
func _width_count(levels: Array) -> int:
	var seen: Array = _widths_of(levels)
	for n: int in seen.size() - 1:
		if absf(float(seen[n]) - float(seen[n + 1])) != 2.0:
			return -1
	return seen.size()


func _width_runs(seen: Seen) -> Array:
	var runs: Array = []
	for r: int in seen.rows:
		if seen.left[r] < 0:
			continue
		var w: int = seen.right[r] - seen.left[r]
		# A width within a stud of the last is the same tier, sloped at its edge.
		if runs.is_empty() or absi(w - int(runs[-1])) > int(STUD / CELL):
			runs.append(w)
	return runs


func _line_with(text: String, word: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(word):
			return line.strip_edges().left(240)
	return "(no line with \"%s\")" % word


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
