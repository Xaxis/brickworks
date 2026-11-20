## View, Stress's Swing (docs/APP_UX10.md, swoosh): a model held by a part and
## swung like a toy, 1 m in 0.5 s and a quarter turn (SwingTest).
##
##   godot --headless --path . --script src/dev/swoosh_probe.gd [-- --only=hand|gallery|app] [--out=DIR]
##
##  1. Hand sums: the walk's tower (eight 2 x 4s on one corner stud of a
##     2 x 4) held by its top brick, the car (models/car.ldr) held by its
##     roof, and a ship whose wing, a 2 x 10 plate with an engine of four
##     2 x 2s at its tip, hangs from the fuselage on 2 studs. Each joint's
##     load at its worst moment of the arc is within 1% of the hand's sum
##     (bench/results/swoosh-2026-11-20/hand_sums.md, worked by its hand.py
##     from the parts dumped to --out=DIR: each part's acceleration
##     by differencing where the swing puts it, not by the app's ω and α).
##     The tower and the car hold through the swing; the ship's wing comes
##     away first, named with its 5 parts, its weight and its 2 studs, though
##     Lift holds it still. At rest (no speed, gravity straight down) the
##     swing's sums are Balance's still ones, joint by joint.
##  2. Ten gallery models (the gallery's seeds), each held where a child
##     takes hold of it (the widest part of its top third that Lift holds it
##     all by, still): the first part to come away named, or that it holds;
##     then Strengthen's fix for that joint put down (what comes away as its
##     side), and swung again: it comes away later in the arc, or not at all.
##  3. The app: Stress › Swing pressed with the ship's fuselage selected:
##     the panel heads with the wing coming away, red, the fuselage blue, a
##     row that lets go offers Strengthen and, pressed, the model is swung
##     again and the wing holds; weakest_joints swing= says the same in 1
##     call, and g4, the house swung by its roof, in 2 (look_at_model, then
##     weakest_joints swing=); Lift pressed gives way to it with the part
##     kept, Swing again sets it down; nothing is written to the model.
##     And the time: a Swing on Orthanc and 10179 takes no frame over 100 ms
##     of the app's own work, the status bar saying it swings meanwhile.
## Exits non-zero when a check fails.
extends SceneTree

const MODELS := "res://models/"
const OMR := "res://vendor/omr/files/"
const UP := "1 0 0 0 1 0 0 0 1"
## How near the hand's number the app's must be.
const WITHIN := 0.01
## The gallery's ten (its seeds, tools/web/gallery_seeds/seeds.json), each
## held by its top: the toys a child would pick up, the scenes left out.
const SEEDS := "res://tools/web/gallery_seeds/"
const GALLERY: Array[String] = ["potted_cactus", "maintenance_robot", "vintage_tractor", "sports_car",
	"working_windmill", "tank_engine", "sleeping_dragon", "garden_pagoda", "moon_rover", "red_fox"]
## The hand's sums (hand_sums.md): case -> "beyond:held_by" -> the most of
## what lets it go the joint carries, at its worst moment.
const HAND: Dictionary = {
	"tower": {"1:2": 0.156223, "8:9": 0.081367, "7:8": 0.066398, "6:7": 0.053408, "5:6": 0.042282, "4:5": 0.033106, "3:4": 0.025537, "2:3": 0.019144},
	"car": {"10:16": 0.01492, "12:21": 0.01492, "26:16": 0.007533, "33:16": 0.006611, "23:11": 0.003124, "13:22": 0.003013, "27:36": 0.001773, "28:37": 0.001773, "61:57": 0.001554, "46:34": 0.000914},
	"ship": {"3:1": 1.011952, "2:1": 0.000183},
}
## The bricks of the ship's engine.
const ENGINE := 4

var _failures: int = 0
var _only: String = ""
var _out: String = ""
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _main: Node
var _shell: Shell
var _socket: CommandSocket
var _next: int = 0
var _began: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
	if _only.is_empty() or _only in ["hand", "gallery"]:
		_library = PartLibrary.new()
		if not _library.load_catalogue():
			print("no catalogue")
			quit(1)
			return
		if _only.is_empty() or _only == "hand":
			await _hand()
		if _only.is_empty() or _only == "gallery":
			await _gallery()
		if _world != null:
			_world.queue_free()
			_builder.queue_free()
			await process_frame
	if _only.is_empty() or _only == "app":
		await _app()
	print("")
	if _failures == 0:
		print("swoosh: each joint's load at the swing's worst is the hand's to 1%, the first to come "
			+ "away is named and Strengthen makes it hold or go later, and Stress's Swing and "
			+ "weakest_joints swing= say the same, in time")
	else:
		print("swoosh: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- 1. the hand's sums -----------------------------------------------------------


func _hand() -> void:
	print("\nhand sums")
	# The walk's tower: a 2 x 4 on the floor, eight 2 x 4s stacked on its
	# corner stud; held by the top one.
	var tower := PackedStringArray([_line(15, "3001", 0, 0, 0, 24)])
	for n: int in 8:
		tower.append(_line(1, "3001", 60, 24 + n * 24, 20, 24))
	await _open("tower", "\n".join(tower))
	var top: int = _top_part()
	var tower_swung: RefCounted = _swing(top)
	_say_swung("the tower by its top brick", tower_swung)
	_dump("tower", tower_swung, top)
	_check("the tower holds through the swing: \"%s\"" % tower_swung.call("headline"),
		(tower_swung.get("away") as Array).is_empty())
	_against_hand("tower", tower_swung)
	_at_rest("tower", top)

	# The car by its roof.
	await _open("car", FileAccess.get_file_as_string(MODELS + "car.ldr"))
	var roof: int = _top_part()
	var car_swung: RefCounted = _swing(roof)
	_say_swung("the car by its roof (#%d %s)" % [roof, _world.get_brick(roof).part_id], car_swung)
	_dump("car", car_swung, roof)
	_against_hand("car", car_swung)
	_at_rest("car", roof)

	# The ship: its wing on 2 studs under the fuselage, an engine at its tip.
	await _open("ship", "\n".join(_ship()))
	var fuselage: int = _part_at("3001", Vector3(0, 0, 0))
	var ship_swung: RefCounted = _swing(fuselage)
	_at_rest("ship", fuselage)
	_say_swung("the ship by its fuselage", ship_swung)
	_dump("ship", ship_swung, fuselage)
	var away: Array = ship_swung.get("away")
	var first: RefCounted = away[0] if not away.is_empty() else null
	var wing: int = _part_at("3832", Vector3(120, 0, 0))
	_check("the ship's wing comes away first, at its 2 studs: \"%s\"" % ship_swung.call("headline"),
		first != null and str(first.get("why")) == "lets go" and (first.get("joint") as Balance.JointLoad).beyond == wing
		and (first.get("joint") as Balance.JointLoad).studs == 2
		and str(ship_swung.call("headline")).contains("at its 2 studs"))
	var lifted: RefCounted = _lift(fuselage)
	_check("held still (Lift) the wing holds: \"%s\"" % lifted.call("headline"),
		(lifted.get("away") as Array).is_empty())
	_against_hand("ship", ship_swung)


## A 2 x 4 fuselage brick with a 1 x 2 fin on it, and the wing: a 2 x 10
## plate along x from 20 to 220 under the fuselage's end, one column of its
## studs (2) in the brick's underside, an engine of four 2 x 2 bricks hung
## under its tip.
func _ship() -> PackedStringArray:
	var lines := PackedStringArray([_line(4, "3001", 0, 0, 0, 24), _line(71, "3004", 0, 24, 0, 24)])
	lines.append("1 7 120 0 0 %s 3832.dat" % UP)
	for n: int in ENGINE:
		lines.append("1 14 200 %d 0 %s 3003.dat" % [8 + n * 24, UP])
	return lines


func _swing(by: int) -> RefCounted:
	var swinger: RefCounted = load("res://src/assembly/swing_test.gd").new()
	swinger.library = _library
	swinger.lattice = _builder.lattice
	swinger.floor_ids = _store.scenery
	var swung: RefCounted = swinger.swing(_world.bricks(), by)
	swung.set("namer", func(id: int) -> String:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		return "#%d %s" % [id, brick.part_id if brick != null else "?"])
	return swung


func _lift(by: int) -> RefCounted:
	var lifter: RefCounted = load("res://src/assembly/lift_test.gd").new()
	lifter.library = _library
	lifter.lattice = _builder.lattice
	lifter.floor_ids = _store.scenery
	var lifted: RefCounted = lifter.lift(_world.bricks(), by)
	lifted.set("namer", func(id: int) -> String: return "#%d" % id)
	return lifted


func _say_swung(what: String, swung: RefCounted) -> void:
	print("    %s: %s" % [what, swung.call("headline")])
	var worst: Dictionary = swung.get("worst_at")
	for one: Balance.JointLoad in swung.get("joints"):
		print("      #%d on #%d %s: %.4f of %.4f N·cm = %.4f at %.4f s" % [one.beyond, one.held_by,
			one.kind, one.moment, one.ultimate, LiftTest.give_of(one), float(worst.get(one, -1.0))])
	for n: int in (swung.get("away") as Array).size():
		var one: RefCounted = (swung.get("away") as Array)[n]
		var joint: Balance.JointLoad = one.get("joint")
		print("      AWAY %s at %.4f s: %s" % [one.get("why"), float((swung.get("times") as Array)[n]),
			"#%d on #%d %.4f of %.4f" % [joint.beyond, joint.held_by, joint.moment, joint.ultimate]
			if joint != null else str(one.get("ids"))])


## Each joint the app weighed at its worst against the hand's sum, when the
## hand's are in (HAND).
func _against_hand(case: String, swung: RefCounted) -> void:
	var want: Dictionary = HAND.get(case, {})
	if want.is_empty():
		print("    (no hand sums for %s yet: run bench/results/swoosh-2026-11-20/hand.py on --out's files)" % case)
		return
	var got: Dictionary = {}
	for one: Balance.JointLoad in swung.get("joints"):
		got["%d:%d" % [one.beyond, one.held_by]] = LiftTest.give_of(one)
	for n: int in (swung.get("away") as Array).size():
		var one: RefCounted = (swung.get("away") as Array)[n]
		var joint: Balance.JointLoad = one.get("joint")
		if joint != null and not bool(one.get("whole")):
			got["%d:%d" % [joint.beyond, joint.held_by]] = LiftTest.give_of(joint)
	var worst: float = 0.0
	var missing: int = 0
	for key: String in want:
		if not got.has(key):
			missing += 1
			continue
		var hand: float = float(want[key])
		worst = maxf(worst, absf(float(got[key]) - hand) / maxf(hand, 0.000001))
	_check("%s: %d joints at their worst within %.2f%% of the hand's sums (want 1%%), none missing" % [
		case, want.size(), worst * 100.0], worst <= WITHIN and missing == 0 and got.size() == want.size())


## The swing's sums at rest (no speed, gravity straight down) are Balance's
## still ones, joint by joint: the moving path adds speed and nothing else.
func _at_rest(case: String, by: int) -> void:
	var weigher: Balance = _held_weigher(by)
	var still: Balance.Report = weigher.get_meta("still")
	weigher.moving = Balance.Moving.new()
	var resting: Balance.Report = weigher.weigh_moving()
	var by_key: Dictionary = {}
	for one: Balance.JointLoad in resting.joints:
		by_key["%d:%d" % [one.beyond, one.held_by]] = one
	var worst: float = 0.0
	var missing: int = 0
	for one: Balance.JointLoad in still.joints:
		var other: Balance.JointLoad = by_key.get("%d:%d" % [one.beyond, one.held_by])
		if other == null:
			missing += 1
			continue
		worst = maxf(worst, absf(other.moment - one.moment) / maxf(one.ultimate, 0.000001))
	_check("%s: at rest the swing's sums are Balance's still ones (%d joints, within %s of what lets each go)"
		% [case, still.joints.size(), String.num_scientific(worst)], missing == 0 and worst < 0.000001
		and resting.joints.size() == still.joints.size())


## A Balance that has read the model held by [param by], as SwingTest reads
## it; its still report kept as the meta "still".
func _held_weigher(by: int) -> Balance:
	var weigher := Balance.new()
	weigher.library = _library
	weigher.lattice = _builder.lattice
	var judge := Stability.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	var model: Array = _world.bricks().filter(func(item: Variant) -> bool:
		return not _store.scenery.has((item as BrickWorld.Brick).id))
	var graph: Dictionary = judge.contacts(model)
	weigher.support = Balance.support_of({by: graph["boxes"][by]})
	weigher.set_meta("still", weigher.measure(model, [], null, graph))
	weigher.set_meta("boxes", graph["boxes"])
	return weigher


## The parts, the tree and the stud joints as Balance reads them with the
## model held by [param by], and what the app said of each, for the hand's
## sums (tools/swoosh_hand.py).
func _dump(case: String, swung: RefCounted, by: int) -> void:
	if _out.is_empty():
		return
	var weigher: Balance = _held_weigher(by)
	var ids: PackedInt64Array = weigher.get("_ids")
	var rest: Array = weigher.get("_rest")
	var middles: Array = weigher.get("_middle")
	var masses: PackedFloat64Array = weigher.get("_mass")
	var shapes: Array = weigher.get("_meshes")
	var parts: Array = []
	for n: int in ids.size():
		var at: Transform3D = rest[n]
		var b: Basis = at.basis
		parts.append({"id": ids[n], "part": _world.get_brick(ids[n]).part_id, "grams": masses[n],
			"middle": _v(at * (middles[n] as Vector3)), "size": _v((shapes[n] as Lbm.PartMesh).bounds.size),
			"basis": [_v(b.x), _v(b.y), _v(b.z)]})
	var bridges: Array = []
	for bridge: Dictionary in weigher.get("_bridges"):
		var one: Dictionary = {"child": bridge["child"], "lower": bridge["lower"]}
		if bridge.has("studs"):
			var upper: int = bridge["upper"]
			var meshes: Array = weigher.get("_meshes")
			one["kind"] = "studs"
			one["centre"] = _v(bridge["centre"])
			one["normal"] = _v(bridge["normal"])
			one["studs"] = (bridge["studs"] as PackedVector3Array).duplicate() as Array
			one["studs"] = (one["studs"] as Array).map(func(s: Vector3) -> Array: return _v(s))
			one["corners"] = (bridge["corners"] as PackedVector3Array) as Array
			one["corners"] = (one["corners"] as Array).map(func(s: Vector3) -> Array: return _v(s))
			one["lets_go"] = Balance.lets_go(meshes[upper])
			one["upper"] = upper
		else:
			one["kind"] = "pins" if bridge.has("pins") else "hold"
		bridges.append(one)
	var app: Array = []
	var worst: Dictionary = swung.get("worst_at")
	for one: Balance.JointLoad in swung.get("joints"):
		app.append({"beyond": one.beyond, "held_by": one.held_by, "kind": one.kind, "moment": one.moment,
			"ultimate": one.ultimate, "give": LiftTest.give_of(one), "at": worst.get(one, -1.0)})
	var away: Array = []
	for n: int in (swung.get("away") as Array).size():
		var one: RefCounted = (swung.get("away") as Array)[n]
		var joint: Balance.JointLoad = one.get("joint")
		away.append({"why": one.get("why"), "ids": Array(one.get("ids")), "at": (swung.get("times") as Array)[n],
			"beyond": joint.beyond if joint != null else 0, "held_by": joint.held_by if joint != null else 0,
			"moment": joint.moment if joint != null else 0.0, "ultimate": joint.ultimate if joint != null else 0.0,
			"give": LiftTest.give_of(joint) if joint != null else 0.0})
	var held: BrickWorld.Brick = _world.get_brick(by)
	var dump: Dictionary = {"case": case, "by": by, "ids": Array(ids), "parent": Array(weigher.get("_parent")),
		"reached": Array(weigher.get("_reached")), "parts": parts, "bridges": bridges, "app": app, "away": away,
		"hand": _v(held.transform * _library.mesh_for(held.part_id).bounds.get_center()),
		"toward": "right" if str(swung.get("toward")) == "right" else "front",
		"arc": {"metres": swung.get("metres"), "seconds": swung.get("seconds"), "turn": swung.get("turn")},
		"to_cm": Balance.MM_PER_LDU / 10.0, "gravity": Balance.GRAVITY}
	var file := FileAccess.open(_out.path_join("%s.json" % case), FileAccess.WRITE)
	file.store_string(JSON.stringify(dump, " "))
	file.close()


static func _v(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


# -- 2. the gallery ---------------------------------------------------------------


func _gallery() -> void:
	print("\nten gallery models, each held by its top")
	var named: int = 0
	var better: int = 0
	for name: String in GALLERY:
		await _open(name, FileAccess.get_file_as_string(SEEDS + name + ".ldr"))
		var by: int = _hand_hold()
		var swung: RefCounted = _swing(by)
		var away: Array = swung.get("away")
		var held_by: String = "#%d %s" % [by, _world.get_brick(by).part_id]
		print("    %s (%d parts), held by %s: %s" % [name, _world.brick_count() - _store.scenery.size(),
			held_by, swung.call("headline")])
		if away.is_empty():
			named += 1
			better += 1
			_check("%s holds through the swing, said so" % name,
				str(swung.call("headline")).contains("everything holds"))
			continue
		named += 1
		var first: RefCounted = away[0]
		var when: float = float((swung.get("times") as Array)[0])
		var joint: Balance.JointLoad = first.get("joint")
		if joint == null or bool(first.get("whole")):
			print("      first away is %s, not one joint: no joint for Strengthen" % first.get("why"))
			_check("%s: what comes away first named" % name, true)
			continue
		var fixed: bool = await _strengthen(joint, first.get("ids"), by)
		if not fixed:
			_check("%s: Strengthen has a fix for the joint that lets go (#%d on #%d)" % [name, joint.beyond,
				joint.held_by], false)
			continue
		var again: RefCounted = _swing(by)
		var after: Array = again.get("away")
		var same_at: float = INF
		for n: int in after.size():
			var one: RefCounted = after[n]
			var j: Balance.JointLoad = one.get("joint")
			if j != null and j.beyond == joint.beyond and j.held_by == joint.held_by:
				same_at = float((again.get("times") as Array)[n])
		var later: bool = same_at > when
		if later:
			better += 1
		print("      after Strengthen: %s" % again.call("headline"))
		_check("%s: after Strengthen #%d comes away %s (first %.2f s)" % [name, joint.beyond,
			"not at all" if same_at == INF else "at %.2f s" % same_at, when], later)
	_check("the first to come away named on %d of 10, later or not at all after Strengthen on %d" % [
		named, better], named == 10 and better == 10)


## Strengthen's fix for [param joint] (as the Swing row offers it), put
## down; false when it has none.
func _strengthen(joint: Balance.JointLoad, away: PackedInt64Array, by: int) -> bool:
	var fixer: RefCounted = load("res://src/assembly/strengthen.gd").new()
	fixer.world = _world
	fixer.library = _library
	fixer.builder = _builder
	fixer.scenery = _store.scenery
	var judge := Stability.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	judge.floor_ids = _store.scenery
	judge.with_margins = true
	var report: Stability.Report = judge.check(_world)
	var weak := StressView.Weak.new()
	weak.id = joint.beyond
	weak.ids = [joint.beyond]
	weak.around = joint.held_by
	weak.joint = joint
	weak.margin = 0.0
	for id: int in away:
		weak.side[id] = true
	weak.swung_by = by
	var fix: RefCounted = await fixer.find(report, weak)
	if fix == null:
		return false
	print("      Strengthen adds %s" % fix.what)
	return not (fixer.place(fix) as PackedInt64Array).is_empty()


# -- 3. the app -------------------------------------------------------------------


func _app() -> void:
	print("\nthe app")
	_began = Time.get_ticks_msec()
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_store = _main.get("_store")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_at("the window up")
	await _open_in_app("ship", "\n".join(_ship()))
	var stress: StressView = _shell.stress
	if not stress.on:
		_shell.run("stress")
	await _weighed()
	var panel: StressPanel = stress.panel
	var fuselage: int = _part_at("3001", Vector3(0, 0, 0))
	var wing: int = _part_at("3832", Vector3(120, 0, 0))
	var before: String = _store.saved_text()
	_builder.selection.clear()
	_builder.selection[fuselage] = true
	var controls: Dictionary = panel.controls_by_name()
	_check("Stress's panel has Swing beside Lift", controls.has("stress_swing") and controls.has("stress_lift"))
	(controls["stress_swing"] as Button).button_pressed = true
	(controls["stress_swing"] as Button).pressed.emit()
	await _swung(stress)
	var shown: Dictionary = panel.fields()
	print("    panel: %s" % shown["count"])
	_check("the panel heads with the wing coming away first, at its 2 studs: \"%s\"" % shown["count"],
		str(shown["count"]).begins_with("Swung by Brick 2 x 4: Plate 2 x 10") and str(shown["count"]).contains("comes away first")
		and str(shown["count"]).contains("at its 2 studs") and bool(shown["swing"]) and not bool(shown["lift"]))
	var tints: Dictionary = _world.tinted_ids()
	_check("the wing red, the fuselage blue", tints.get(wing) == StressView.RED
		and tints.get(fuselage) == StressView.LIFTED)
	# Its row: Strengthen offered, pressed, swung again.
	panel.call("_choose", 0, false)
	for _n: int in 600:
		await process_frame
		if panel.fix != null or not bool(panel.fields()["finding"]):
			break
	shown = panel.fields()
	_check("the wing's row offers Strengthen: \"%s\"" % shown["offer"], bool(shown["strengthen"]))
	var mcp_before: String = await _say("weakest_joints", {"swing": fuselage})
	print("    MCP:\n      " + mcp_before.replace("\n", "\n      ").left(1600))
	_check("weakest_joints swing= in 1 call says the wing comes away first, as the panel",
		mcp_before.begins_with("Swung by #%d" % fuselage) and mcp_before.contains("comes away first")
		and mcp_before.contains("at its 2 studs") and mcp_before.contains("Call edit_model"))
	if bool(shown["strengthen"]):
		panel.strengthen()
		await _weighed()
		await _swung(stress)
		shown = panel.fields()
		_check("after Strengthen, swung again, the wing holds: \"%s\"" % shown["count"],
			not str(shown["count"]).contains("#%d" % wing) and str(shown["count"]).begins_with("Swung by"))
		_shell.run("undo")
		await _weighed()
		await _swung(stress)
	# Lift gives way to Swing with the part kept, and back; Swing again sets it down.
	(controls["stress_lift"] as Button).button_pressed = true
	(controls["stress_lift"] as Button).pressed.emit()
	await _swung(stress)
	shown = panel.fields()
	_check("Lift pressed lifts by the same part, held still: \"%s\"" % shown["count"],
		str(shown["count"]).begins_with("Lifted by Brick 2 x 4") and bool(shown["lift"]) and not bool(shown["swing"]))
	(controls["stress_swing"] as Button).button_pressed = true
	(controls["stress_swing"] as Button).pressed.emit()
	await _swung(stress)
	(controls["stress_swing"] as Button).button_pressed = false
	(controls["stress_swing"] as Button).pressed.emit()
	await _frames(5)
	shown = panel.fields()
	_check("Swing again sets it down: Stress's own rows back", not bool(shown["swing"]) and not bool(shown["lift"])
		and not stress.lifting)
	var after_text: String = _store.saved_text()
	_check("nothing written to the model", before == after_text)

	# g4: the house swung by its roof, in 2 calls.
	await _open_in_app("house", FileAccess.get_file_as_string(MODELS + "house.ldr"))
	var calls: int = 0
	var looked: String = await _say("look_at_model", {})
	calls += 1
	var roof: int = _top_part()
	var g4: String = await _say("weakest_joints", {"swing": roof})
	calls += 1
	print("    g4 (house by its roof, #%d):\n      %s" % [roof, g4.replace("\n", "\n      ").left(1200)])
	_check("g4 answered in %d calls: what comes away first, or that it holds, named" % calls,
		calls <= 2 and looked.contains("#%d" % roof) and g4.begins_with("Swung by #%d" % roof)
		and (g4.contains("comes away first") or g4.contains("everything holds") or g4.contains("stays behind")
			or g4.contains("falls off first")))
	_shell.run("stress")
	await _frames(5)

	# The time: Orthanc and 10179.
	await _timed("orthanc", FileAccess.get_file_as_string(MODELS + "orthanc.ldr"))
	await _timed("10179", FileAccess.get_file_as_string(OMR + "10179-1.mpd"))


## A Swing on [param name] by its top: the longest frame the app took
## meanwhile, its own work alone (headless draws nothing).
func _timed(name: String, text: String) -> void:
	await _open_in_app(name, text)
	var stress: StressView = _shell.stress
	if not stress.on:
		_shell.run("stress")
	await _weighed()
	var by: int = _top_part()
	_builder.selection.clear()
	_builder.selection[by] = true
	var said: Array = []
	var longest: float = 0.0
	var frames: int = 0
	var started: int = Time.get_ticks_usec()
	stress.set_swing(true)
	var last: int = Time.get_ticks_usec()
	longest = (last - started) / 1000.0
	var saying: String = (_shell.status.fields() as Dictionary).get("message", "")
	for _n: int in 20000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		longest = maxf(longest, (now - last) / 1000.0)
		last = now
		frames += 1
		if stress.lift != null:
			break
	var took: float = (Time.get_ticks_usec() - started) / 1000000.0
	print("    %s (%d parts) by #%d: %.1f s over %d frames, the longest %.1f ms; %s" % [name,
		_world.brick_count(), by, took, frames, longest,
		stress.lift.call("headline") if stress.lift != null else "no result"])
	_check("%s: a Swing takes no frame over 100 ms of the app's own work (%.1f ms), the status bar "
		% [name, longest] + "saying it swings meanwhile (\"%s\")" % saying,
		stress.lift != null and longest <= 100.0 and saying.begins_with("swing: swinging it by"))
	stress.set_swing(false)
	_shell.run("stress")
	await _frames(3)


func _swung(stress: StressView) -> void:
	for _n: int in 6000:
		await process_frame
		if stress.lift != null or not stress.lifting:
			break
	await _frames(3)


func _weighed() -> void:
	var stress: StressView = _shell.stress
	for _n: int in 3000:
		await process_frame
		if stress.report != null and not Working.is_busy():
			break
	await _frames(3)


func _open_in_app(name: String, text: String) -> void:
	_main.call("clear_model")
	_store.open_text(text, name + ".ldr")
	await _frames(30)
	_at("%s open, %d parts" % [name, _world.brick_count()])


func _at(what: String) -> void:
	print("    (%s, %d ms)" % [what, Time.get_ticks_msec() - _began])


func _say(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	return text


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


# -- the models ---------------------------------------------------------------------


func _open(name: String, text: String) -> void:
	if _world != null:
		_world.queue_free()
		_builder.queue_free()
		await process_frame
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	_store.open_text(text, name + ".ldr")


## The part a child holds a model by: of those whose top is within a plate
## of the model's top, the one nearest its middle, seen from above.
func _top_part() -> int:
	var top: float = -INF
	var tops: Dictionary = {}
	var middle := Vector3.ZERO
	var count: int = 0
	for item: Variant in _world.bricks():
		var brick: BrickWorld.Brick = item
		if _store.scenery.has(brick.id):
			continue
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var box: AABB = brick.transform * mesh.bounds
		tops[brick.id] = [box.end.y, box.get_center()]
		top = maxf(top, box.end.y)
		middle += box.get_center()
		count += 1
	middle /= maxf(count, 1)
	var found: int = 0
	var near: float = INF
	for id: Variant in tops:
		var at: Array = tops[id]
		if float(at[0]) < top - 8.0:
			continue
		var off: float = Vector2((at[1] as Vector3).x - middle.x, (at[1] as Vector3).z - middle.z).length()
		if off < near:
			near = off
			found = int(id)
	return found


## Where a child takes hold of a model to swing it: of the parts whose top is
## in the model's top third, the widest seen from above (nearest the middle
## between equals), the first that Lift holds everything by, still. A model
## is picked up where it holds: the swing is what is weighed.
func _hand_hold() -> int:
	var low: float = INF
	var high: float = -INF
	var tops: Array = []
	var middle := Vector3.ZERO
	for item: Variant in _world.bricks():
		var brick: BrickWorld.Brick = item
		if _store.scenery.has(brick.id):
			continue
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var box: AABB = brick.transform * mesh.bounds
		low = minf(low, box.position.y)
		high = maxf(high, box.end.y)
		middle += box.get_center()
		tops.append([brick.id, box])
	middle /= maxf(tops.size(), 1)
	var near: Array = tops.filter(func(one: Array) -> bool:
		return (one[1] as AABB).end.y >= high - (high - low) / 3.0)
	near.sort_custom(func(a: Array, b: Array) -> bool:
		var wa: float = (a[1] as AABB).size.x * (a[1] as AABB).size.z
		var wb: float = (b[1] as AABB).size.x * (b[1] as AABB).size.z
		if absf(wa - wb) > 1.0:
			return wa > wb
		var ca: Vector3 = (a[1] as AABB).get_center() - middle
		var cb: Vector3 = (b[1] as AABB).get_center() - middle
		return Vector2(ca.x, ca.z).length() < Vector2(cb.x, cb.z).length())
	for n: int in mini(near.size(), 12):
		var lifted: RefCounted = _lift(int(near[n][0]))
		if int(lifted.get("by")) != 0 and (lifted.get("away") as Array).is_empty():
			return int(near[n][0])
	return int(near[0][0]) if not near.is_empty() else 0


## The part [param part] whose middle, seen from above, is nearest [param at].
func _part_at(part: String, at: Vector3) -> int:
	var found: int = 0
	var near: float = INF
	for item: Variant in _world.bricks():
		var brick: BrickWorld.Brick = item
		if brick.part_id != part:
			continue
		var off: float = Vector2(brick.transform.origin.x - at.x, brick.transform.origin.z - at.z).length()
		if off < near:
			near = off
			found = brick.id
	return found


static func _line(colour: int, part: String, x: float, bottom: float, z: float, tall: float) -> String:
	return "1 %d %d %d %d %s %s.dat" % [colour, int(x), -int(bottom + tall), int(z), UP, part]
