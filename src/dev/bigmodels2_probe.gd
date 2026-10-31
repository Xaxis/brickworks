## Orthanc's big commands, made quicker, answer as they did (docs/APP_UX3.md,
## bigmodels2). command_probe holds the times
## (--within=instructions.first:15,suggest_sections:3,stability:2,hidden_colours:2);
## this holds the answers, on Orthanc's 10,105 parts and the car:
##
##   godot --path . --resolution 1400x900 --script src/dev/bigmodels2_probe.gd
##
##   stability  Check stability shows the status bar's own weighing of the
##              model as it stands (Main.weighed_now), the very report, not a
##              second weighing: waited for when under way, begun when not,
##              straight after opening and once weighed; and that is what
##              weighing afresh gives:
##              the same verdict, risks, balance, margin and joints. On a
##              worker (Stability.check_paced) it is what the window's own
##              check is, and the window keeps drawing meanwhile.
##   sections   suggested from the reading the booklet keeps
##              (Instructions.read_shape) and from a fresh one, the same
##              sections, part for part, and the kept reading unchanged; and
##              on workers, the joint graph read beside the order
##              (Sections._cut_on_a_worker), the same again.
##   cut        where Colour the hidden parts cuts the model open is where
##              asking every box at every plane cuts it, for parts changed
##              all over the model.
##
## Needs a window: the app's own scene, as a person has it.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _bar: ModelBar
var _library: PartLibrary


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	(_main.get("_playback") as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_bar = _main.get("_bar")
	_library = _main.get("_library")
	for model: String in ["car", "orthanc"]:
		await _open(model)
		await _stability(model)
	await _sections()
	_cut()
	_world.clear()
	await _frames(10)
	_main.queue_free()
	await _frames(10)
	print("bigmodels2 probe: %s" % ("ok" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)


func _open(model: String) -> void:
	var placed: int = await _bar.open_with_progress("res://models/%s.ldr" % model)
	_bar.opened.emit(placed)
	await _frames(30)
	print("%s: %d parts open" % [model, _world.brick_count()])


## What a balance says, to compare two: its words, margin, centre and every
## stud joint's load.
static func _balance_said(report: Balance.Report) -> String:
	if report == null:
		return "none"
	return "%s | margin %.3f centre %s grams %.1f joints %s held %d tipping %d" % [report.words(),
		report.margin, str(report.centre), report.grams, str(report.joints.map(
			func(one: Balance.JointLoad) -> String:
				return "%d:%d:%.3f" % [one.beyond, one.held_by, one.ratio])), report.held.size(),
		report.tipping.size()]


## What Check stability reads of a check: whether it stands and every risk.
## Not its grams: the status bar's leave out the baseplate (Main.weigh_joints).
static func _risks_said(report: Stability.Report) -> String:
	return "%s %s" % [report.is_stable(), str(report.risks.map(func(risk: Stability.Risk) -> String:
		return "%d %s %.3f %s" % [risk.brick_id, risk.kind, risk.margin, risk.message]))]


## Check stability, as from the menu: how long until its balance is shown,
## and whether that is the status bar's own weighing of the model as it
## stands, the very report.
func _checked(model: String, when: String) -> Stability.Report:
	var under_way: bool = _main.get("_weighing")
	_shell.balance_shown = null
	var from: int = Time.get_ticks_msec()
	_shell.run("stability")
	var until: int = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < until and _shell.balance_shown == null:
		await process_frame
	var took: int = Time.get_ticks_msec() - from
	var weighed: Stability.Report = _main.get("_weighed")
	var shown: Balance.Report = _shell.balance_shown
	_check("%s, %s (the status bar %s): Check stability shows its weighing itself, in %d ms"
		% [model, when, "weighing" if under_way else "not weighing", took], shown != null
		and weighed != null and int(_main.get("_weighed_revision")) == _world.revision
		and shown == weighed.balance)
	for _n: int in 4:
		_escape()
		await _frames(2)
	return weighed


func _stability(model: String) -> void:
	# Straight after opening, with the status bar weighing or about to: Check
	# stability waits for it or begins it, and weighs nothing twice.
	await _checked(model, "just opened")
	# Then once the status bar has weighed, as a person reading "stands up"
	# would.
	var weighed: Stability.Report = await _checked(model, "weighed already")
	if weighed == null:
		return
	var shown: Balance.Report = weighed.balance
	# Weighed afresh, as Check stability weighed before.
	var stability: Stability = _main.get("_stability")
	stability.floor_ids = _store.scenery
	var fresh: Stability.Report = stability.check(_world)
	var judge := Balance.new()
	judge.library = _library
	judge.floor_ids = _store.scenery
	judge.lattice = _builder.lattice
	var again: Balance.Report = judge.measure(_world.bricks(), [])
	_check("%s: ...and it is what weighing afresh gives: %s" % [model,
		_balance_said(again).left(120)], _balance_said(shown) == _balance_said(again))
	_check("%s: ...the same verdict and risks (%s)" % [model, fresh.summary()],
		_risks_said(weighed) == _risks_said(fresh))
	# On a worker, the window drawing meanwhile.
	var longest: Array = [0]
	var last: Array = [Time.get_ticks_usec()]
	var watch := func() -> void:
		var now: int = Time.get_ticks_usec()
		longest[0] = maxi(int(longest[0]), now - int(last[0]))
		last[0] = now
	process_frame.connect(watch)
	var met: Array = [false]
	var from: int = Time.get_ticks_msec()
	last[0] = Time.get_ticks_usec()
	var paced: Stability.Report = await stability.check_paced(_world, func() -> void:
		met[0] = true)
	var paced_ms: int = Time.get_ticks_msec() - from
	process_frame.disconnect(watch)
	_check("%s: on a worker it is what the window's own check is (%d ms, the longest frame %d ms)"
		% [model, paced_ms, int(longest[0]) / 1000], paced != null and met[0]
		and _risks_said(paced) == _risks_said(fresh)
		and _balance_said(paced.balance) == _balance_said(fresh.balance))
	if _world.brick_count() >= Stability.ON_A_WORKER_FROM:
		_check("%s: ...and the window kept drawing: the longest frame %d ms of %d ms" % [model,
			int(longest[0]) / 1000, paced_ms], int(longest[0]) / 1000 < maxi(paced_ms / 2, 250))
	for _n: int in 4:
		_escape()
		await _frames(2)


func _escape() -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = pressed
		Input.parse_input_event(key)


## Suggested from a fresh reading and from the one kept, on Orthanc: the same.
func _sections() -> void:
	var sections: Sections = _shell.sections.sections
	var bricks: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			bricks.append(brick)
	var wanted: int = clampi(roundi(bricks.size() / Sections.PER_SECTION), 2, Sections.MOST)
	Instructions._shaped_lock.lock()
	Instructions._shaped = {}
	Instructions._shaped_lock.unlock()
	var from: int = Time.get_ticks_msec()
	var cold: Dictionary = sections._cut(bricks, wanted)
	var cold_ms: int = Time.get_ticks_msec() - from
	var kept: Array = Instructions.read_shape(_world, _library, _store.scenery, false)
	var kept_before: String = _nodes_said(kept)
	from = Time.get_ticks_msec()
	var warm: Dictionary = sections._cut(bricks, wanted)
	var warm_ms: int = Time.get_ticks_msec() - from
	_check("Orthanc's sections from a fresh reading (%d ms) and the kept one (%d ms): the same %d"
		% [cold_ms, warm_ms, (warm["sections"] as Array).size()],
		str([cold["sections"], cold["figures"], cold["loose"]])
			== str([warm["sections"], warm["figures"], warm["loose"]])
		and (warm["sections"] as Array).size() >= 2)
	_check("...and the kept reading is as it was (%d parts)" % kept.size(), kept_before
		== _nodes_said(Instructions.read_shape(_world, _library, _store.scenery, false)))
	# On workers, the joint graph read beside the order, as Suggest sections
	# reads a big model: the same sections as in one go.
	from = Time.get_ticks_msec()
	var paced: Dictionary = await sections._cut_on_a_worker(bricks, wanted, null)
	var paced_ms: int = Time.get_ticks_msec() - from
	_check("...and on workers, the joint graph beside the order (%d ms): the same %d" % [paced_ms,
		(paced.get("sections", []) as Array).size()],
		str([paced.get("sections"), paced.get("figures"), paced.get("loose")])
			== str([warm["sections"], warm["figures"], warm["loose"]]))
	var fresh: Array[Instructions.Node2] = Instructions._survey(_world, _library, _store.scenery)
	Instructions._find_supports(fresh, _world, _library)
	Instructions._find_joints(fresh, _world, _library)
	Instructions._tidy_needs(fresh)
	Instructions._find_hangers(fresh)
	_check("...and is what reading afresh gives", _nodes_said(fresh) == kept_before)


static func _nodes_said(nodes: Array) -> String:
	var out := PackedStringArray()
	for node: Instructions.Node2 in nodes:
		out.append("%d %s %s %s %s %s %s %d" % [node.id, str(node.needs), str(node.after),
			str(node.weak), str(node.joined), str(node.contacts), str(node.hung), node.wheel])
	return "\n".join(out)


## Where the hidden parts' pictures cut the model open, against every box
## asked at every plane.
func _cut() -> void:
	var bricks: Array = HiddenColours.bricks_of(_world, _store.scenery)
	for share: int in [1, 3, 10]:
		var changed: Dictionary = {}
		for n: int in bricks.size():
			if n % share == 0:
				changed[int(bricks[n][0])] = true
		var from: int = Time.get_ticks_usec()
		var cut: Array = HiddenColoursPanel.cut_through(bricks, changed, _library)
		var cut_ms: float = (Time.get_ticks_usec() - from) / 1000.0
		from = Time.get_ticks_usec()
		var asked: Array = _cut_by_asking(bricks, changed)
		var asked_ms: float = (Time.get_ticks_usec() - from) / 1000.0
		_check("the cut through %d changed parts of Orthanc is where asking every box puts it (%.0f ms, asked %.0f ms)"
			% [changed.size(), cut_ms, asked_ms], str(cut) == str(asked))


## HiddenColoursPanel.cut_through as it was: every box asked at every plane.
func _cut_by_asking(bricks: Array, changed: Dictionary) -> Array:
	var boxes: Array[AABB] = []
	var whole := AABB()
	var any: bool = false
	for entry: Array in bricks:
		var part: Lbm.PartMesh = _library.mesh_for(str(entry[1]))
		if part == null:
			continue
		var box: AABB = (entry[3] as Transform3D) * part.bounds
		whole = box if not any else whole.merge(box)
		any = true
		if changed.has(int(entry[0])):
			boxes.append(box)
	var best: Array = [Plane(Vector3(0, 0, 1), whole.get_center().z), HiddenColoursPanel.INTO]
	var most: int = 0
	var ways: Array = [[2, Vector3(0, 0, 1), HiddenColoursPanel.INTO],
		[0, Vector3(1, 0, 0), Vector3(1.0, 0.5, 0.45)], [1, Vector3(0, 1, 0), Vector3(0.35, 1.0, 0.5)]]
	var stride: int = maxi(1, boxes.size() / 150)
	for way: Array in ways:
		var axis: int = way[0]
		for at: int in range(0, boxes.size(), stride):
			var d: float = boxes[at].get_center()[axis]
			var through: int = 0
			for box: AABB in boxes:
				if box.position[axis] < d and box.end[axis] > d:
					through += 1
			if through > most:
				most = through
				best = [Plane(way[1], d), way[2]]
	return best
