## Mechanisms, phase 1's core and nothing else: which parts turn together,
## which joints turn, which gears mesh, and how far every body turns for one
## turn of a driver, all read off the parts and where they stand. The proof
## of concept for docs/MECHANISMS.md, with no UI and nothing kept.
##
##   godot --path . --resolution 1400x900 --script src/dev/mechanism_probe.gd
##   godot --headless --path . --script src/dev/mechanism_probe.gd   (no pictures)
##
## What it turns:
##   - a real set, LEGO 8020's windmill (vendor/omr, tools/omr.py fetch): a
##     24 tooth gear drives an 8, whose axle's crown gear drives another 8
##     on the sails' axle, 9:1. Skipped, and said, without the file.
##   - an 8 driving a 24 on two axles in a beam;
##   - the same two axles also joined 16 to 16, which cannot turn;
##   - a worm driving a 24;
##   - a two-planet orrery: Earth's arm on the central axle, Mars's on a
##     turntable round it, both from one crank.
## Each is checked against its tooth counts, and with a display the windmill
## and the orrery are drawn turning (shots/mechanism/, frames and a WebP),
## the angles read back off the renderer's copy of the model.
##
## The model is kinematic and linear: bodies are parts joined rigidly
## (studs, an axle keyed in an axle hole, two pins), joints are an axle or a
## pin in a round hole and a turntable's top on its base, and a mesh says
## the two pitch circles move together where they touch. One unknown per
## joint, a turn relative to the body it hangs from; one equation per mesh;
## the driver's joint set to 1. Gaussian elimination says what each joint
## does, which are left free (they follow what carries them, as friction
## would have it) and whether the equations contradict each other (the
## train is locked, and which meshes lock it). Closed loops of joints and
## anything dynamic are phases 2 and 3.
extends SceneTree

const LDU_PER_TOOTH := 1.25   ## module 1 mm is 2.5 LDU; pitch radius is N m / 2

const Z := Vector3(0, 0, 1)
const Y := Vector3(0, 1, 0)

## part -> [kind, teeth, hole, face, axis, plane]. kind: spur, double (double
## bevel: meshes as a spur and at right angles), bevel (at right angles
## only), crown (as a spur, and at right angles to a spur). hole: what it
## takes an axle by (axle keys it, round lets it spin), none for a
## turntable's top. face: for a mesh at right angles, how far the part's
## origin is from its pitch plane, LDU — measured on real sets, below.
## axis: the part's own axis; plane: where along it the teeth are.
##
## Measured on the 354 Technic sets of the OMR (docs/MECHANISMS.md): of
## 809 pairs of parallel gears in one plane within 8 LDU of meshing, 722
## stand 1.25 LDU a tooth apart to 0.1 LDU and 42 more to 0.3 (a 16 and a
## 20 on a stud's diagonal, 44.7 for 45); 5 are within 1, and the other 40
## are 1.2 LDU or more out, neighbours rather than meshes. At right angles,
## 155 pairs of 6589 stand 17 LDU from where their axes cross (15 + 2),
## 28 of 32270 at 20 (15 + 5), 32270 and 32269 at 30 and 20, a crown and
## an 8, 16 or 24 at 30 and 12, 22, 32 (r + 2).
const GEARS: Dictionary = {
	"3647": ["spur", 8, "axle", 0.0, Z, 0.0],
	"10928": ["spur", 8, "axle", 0.0, Z, 0.0],
	"11955": ["spur", 8, "axle", 0.0, Z, 0.0],
	"7557": ["spur", 8, "round", 0.0, Z, 0.0],
	"69778": ["spur", 12, "axle", 0.0, Z, 0.0],
	"3590": ["spur", 12, "round", 0.0, Z, 0.0],
	"4019": ["spur", 16, "axle", 0.0, Z, 0.0],
	"94925": ["spur", 16, "axle", 0.0, Z, 0.0],
	"18946": ["spur", 16, "round", 0.0, Z, 0.0],
	"6542a": ["spur", 16, "round", 0.0, Z, 0.0],
	"6542b": ["spur", 16, "round", 0.0, Z, 0.0],
	"69779": ["spur", 20, "axle", 0.0, Z, 0.0],
	"81346": ["spur", 20, "round", 0.0, Z, 0.0],
	"3648a": ["spur", 24, "axle", 0.0, Z, 0.0],
	"3648b": ["spur", 24, "axle", 0.0, Z, 0.0],
	"24505": ["spur", 24, "axle", 0.0, Z, 0.0],
	"2471": ["spur", 24, "round", 0.0, Z, 0.0],
	"76019": ["spur", 24, "axle", 0.0, Z, 0.0],
	"76244": ["spur", 24, "axle", 0.0, Z, 0.0],
	"3649": ["spur", 40, "axle", 0.0, Z, 0.0],
	"34432": ["spur", 40, "axle", 0.0, Z, 0.0],
	"32270": ["double", 12, "axle", 5.0, Z, 0.0],
	"32269": ["double", 20, "axle", 5.0, Z, 0.0],
	"18575": ["double", 20, "axle", 5.0, Z, 0.0],
	"35185": ["double", 20, "round", 5.0, Z, 0.0],
	"46372": ["double", 28, "axle", 5.0, Z, 0.0],
	"65413": ["double", 28, "round", 5.0, Z, 0.0],
	"32498": ["double", 36, "axle", 5.0, Z, 0.0],
	"6589": ["bevel", 12, "axle", 2.0, Z, 0.0],
	"32198a": ["bevel", 20, "axle", 5.0, Z, 0.0],
	"32198b": ["bevel", 20, "axle", 5.0, Z, 0.0],
	"3650a": ["crown", 24, "axle", 2.0, Z, 0.0],
	"3650b": ["crown", 24, "axle", 2.0, Z, 0.0],
	"3650c": ["crown", 24, "axle", 2.0, Z, 0.0],
	# Turntables' tops, teeth round the rim: 99010 measured against a 20 at
	# 60 and a 12 at 50, 48168 against an 8 at 80 and a 24 at 100.
	"99010": ["spur", 28, "none", 0.0, Y, 0.0],
	"48168": ["spur", 56, "none", 0.0, Y, -20.0],
}
## Worms: part -> pitch radius, LDU. 4716 drives a 24 from 40 (51 of the
## 53 pairs near one) and an 8 from 20 (all 37); 27938 a 20 from 40.
const WORMS: Dictionary = {"4716": 10.0, "32905": 10.0, "73763": 10.0, "27938": 15.0}
## A worm advances one tooth a turn: its lead, LDU (pi times the module).
const WORM_LEAD := PI * 2.5
## Which way a worm's thread runs: +1 right-handed. An assumption; the
## ratio does not depend on it, the direction does.
const WORM_HAND := 1.0
## A turntable's top on its base: one origin, one axis (local Y), in all 71
## the OMR sets have.
const TURNTABLES: Dictionary = {"99010": "99009", "18938": "18939", "48168": "48452",
	"2855": "2856", "32274": "32273"}

## Two pitch circles touch when their centres are this close to r1 + r2.
const MESH_SLACK := 1.0
## A shaft is on a hole's line to within this, LDU, and reaches it to this.
const LINE_SLACK := 1.5
const REACH_SLACK := 2.0
## A stud is in a socket when they are this close.
const STUD_SLACK := 1.5

var _failures: int = 0
var _library: PartLibrary


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	await _windmill()
	_eight_to_twenty_four()
	_locked()
	_worm()
	await _orrery()
	print("")
	if _failures == 0:
		print("mechanism: gear trains read off the parts, every ratio its tooth counts', a "
			+ "locked train named, and the windmill and the orrery turned")
	else:
		print("mechanism: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- the cases ----------------------------------------------------------------


const WINDMILL := "res://vendor/omr/files/8020-1_Windmill.mpd"


func _windmill() -> void:
	print("  a real set: 8020's windmill (OMR)")
	if not FileAccess.file_exists(WINDMILL):
		print("    (no %s: tools/omr.py fetch brings the sets; skipped)" % WINDMILL)
		return
	var model := Mechanism.new()
	var placements: Array = LdrModel.load_file(WINDMILL).flatten()
	for placement: LdrModel.Placement in placements:
		model.add(placement.part_id, placement.transform, _library, placement.color_code)
	model.build()
	print("    %s" % model.summary())
	_check("57 parts read (%d)" % model.parts.size(), model.parts.size() == 57)
	var big: Gear = model.gear_of("3648a")
	var crown: Gear = model.gear_of("3650a")
	var sails: Gear = null
	for gear: Gear in model.gears:
		if gear.part == "10928" and gear.body != crown.body:
			sails = gear
	_check("two meshes: the 24 with an 8, and the crown at right angles with the other 8 (%s)"
		% model.meshes_said(), model.meshes.size() == 2)
	var result: Dictionary = model.solve(big.body)
	print(model.describe())
	_check("it turns (%s)" % result["said"], result["ok"])
	var crank: float = model.spin(big.body, big.axis)
	var middle: float = model.spin(crown.body, crown.axis)
	if sails == null:
		_check("an 8 on the sails' axle", false)
		return
	var out: float = model.spin(sails.body, sails.axis)
	_check("the crown's axle turns 24/8 = 3 times the crank's, the other way (%.6f)" % (middle / crank),
		absf(middle / crank + 3.0) < 1e-6)
	_check("the sails' axle turns 3 x 3 = 9 times the crank's (%.6f)" % absf(out / crank),
		absf(absf(out / crank) - 9.0) < 1e-6)
	# The sails are 3709b plates threaded on their axle by round holes: free
	# to spin on it, so they follow it, as friction has them do.
	var sail_plate: int = model.first_key("3709b")
	_check("the sail plates go round with their axle (free on it, followed)",
		model.body_of(sail_plate) != model.ground and model.follows(sail_plate, sails.key))
	_check("the frame stays where it is (%d of its parts)" % model.bodies[model.ground].size(),
		model.bodies[model.ground].size() >= 30)
	var still: Dictionary = model.pose(0.0)
	var moved: int = 0
	for key: int in still:
		if not _near(still[key], model.rest[key]):
			moved += 1
	_check("at 0 nothing has moved (%d)" % moved, moved == 0)
	if sails != null:
		await _draw("windmill", model, 16, deg_to_rad(2.5), big.key, [[sails.key, 9.0, "the sails"]])


func _eight_to_twenty_four() -> void:
	print("  an 8 driving a 24")
	var model := Mechanism.new()
	_bearings(model, [Vector3(0, 0, 0), Vector3(0, 40, 0)], Z)
	var axle_a: int = model.add("3706", Transform3D(_turn_x_to(Z), Vector3(0, 0, 30)), _library)
	model.add("3706", Transform3D(_turn_x_to(Z), Vector3(0, 40, 30)), _library)
	var small: int = model.add("3647", Transform3D(Basis.IDENTITY, Vector3(0, 0, 50)), _library)
	var large: int = model.add("3648a", Transform3D(Basis.IDENTITY, Vector3(0, 40, 50)), _library)
	model.build()
	print("    %s" % model.summary())
	var result: Dictionary = model.solve(model.body_of(axle_a))
	print(model.describe())
	var a: Gear = model.gear_at(small)
	var b: Gear = model.gear_at(large)
	var ratio: float = model.spin(b.body, b.axis) / model.spin(a.body, a.axis)
	_check("one mesh, and it turns (%s; %s)" % [model.meshes_said(), result["said"]],
		model.meshes.size() == 1 and result["ok"])
	_check("the 24 turns a third as fast, the other way (%.6f)" % ratio, absf(ratio + 1.0 / 3.0) < 1e-5)


func _locked() -> void:
	print("  the same two axles, also joined 16 to 16")
	var model := Mechanism.new()
	_bearings(model, [Vector3(0, 0, 0), Vector3(0, 40, 0)], Z)
	var axle_a: int = model.add("3706", Transform3D(_turn_x_to(Z), Vector3(0, 0, 30)), _library)
	model.add("3706", Transform3D(_turn_x_to(Z), Vector3(0, 40, 30)), _library)
	model.add("3647", Transform3D(Basis.IDENTITY, Vector3(0, 0, 50)), _library)
	model.add("3648a", Transform3D(Basis.IDENTITY, Vector3(0, 40, 50)), _library)
	model.add("94925", Transform3D(Basis.IDENTITY, Vector3(0, 0, 75)), _library)
	model.add("94925", Transform3D(Basis.IDENTITY, Vector3(0, 40, 75)), _library)
	model.build()
	print("    %s" % model.summary())
	var result: Dictionary = model.solve(model.body_of(axle_a))
	print(model.describe())
	_check("two meshes, 3:1 and 1:1 between the same two axles (%s)" % model.meshes_said(),
		model.meshes.size() == 2)
	_check("it is locked, and says so (%s)" % result["said"], not result["ok"] and result["locked"])
	_check("...naming both meshes as the ones that fight (%s)" % str(result["culprits"]),
		(result["culprits"] as Array).size() == 2)


func _worm() -> void:
	print("  a worm driving a 24")
	var model := Mechanism.new()
	# The worm's axle along x through two beams, the 24's along z below it.
	_bearings(model, [Vector3(-40, 0, 0), Vector3(40, 0, 0)], Vector3.RIGHT)
	_bearings(model, [Vector3(0, -40, -30)], Z)
	var worm_axle: int = model.add("3706", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), _library)
	model.add("3705", Transform3D(_turn_x_to(Z), Vector3(0, -40, -20)), _library)
	# 4716's axis is its local z: turned to run along x.
	var worm: int = model.add("4716", Transform3D(_turn_z_to(Vector3.RIGHT), Vector3.ZERO), _library)
	var wheel: int = model.add("3648a", Transform3D(Basis.IDENTITY, Vector3(0, -40, 0)), _library)
	model.build()
	print("    %s" % model.summary())
	var result: Dictionary = model.solve(model.body_of(worm_axle))
	print(model.describe())
	var w: Gear = model.gear_at(worm)
	var g: Gear = model.gear_at(wheel)
	var ratio: float = model.spin(g.body, g.axis) / model.spin(w.body, w.axis)
	_check("one mesh, a worm's, and it turns (%s; %s)" % [model.meshes_said(), result["said"]],
		model.meshes.size() == 1 and result["ok"])
	_check("the 24 turns once for 24 turns of the worm (1/%.4f)" % (1.0 / absf(ratio)),
		absf(absf(ratio) - 1.0 / 24.0) < 1e-5)


## Mars goes round once for every 1.8808 of Earth's: NASA's sidereal
## periods, 686.98 and 365.256 days.
const MARS_YEARS := 686.98 / 365.256


func _orrery() -> void:
	print("  a two-planet orrery: Earth on the central axle, Mars on a turntable, one crank")
	var model := Mechanism.new()
	# The frame: a beam lying flat, its holes up, and the turntable's base on
	# it (held to the frame in the real thing; said so here).
	var frame: int = model.add("32524", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), _library, 71)
	var base: int = model.add("99009", Transform3D(Basis.IDENTITY, Vector3(0, 39, 0)), _library, 72)
	model.grounded = [frame, base]
	var up := _turn_z_to(Y)
	# The central axle, Earth's: a 20 below the beam, Earth's arm and the sun on top.
	var centre: int = model.add("3707", Transform3D(_turn_x_to(Y), Vector3(0, 40, 0)), _library, 71)
	model.add("32269", Transform3D(up, Vector3(0, -20, 0)), _library, 72)
	var earth_arm: int = model.add("6632", Transform3D(Basis.IDENTITY, Vector3(0, 80, 0)), _library, 1)
	model.add("3704", Transform3D(_turn_x_to(Y), Vector3(0, 100, -40)), _library, 0)
	var earth: int = model.add("3941", Transform3D(Basis.IDENTITY, Vector3(0, 114, -40)), _library, 1)
	model.add("3941", Transform3D(Basis.IDENTITY, Vector3(0, 118, 0)), _library, 14)
	# The crank's axle, three studs off: a 28 meshing the 20 below, a 20 the
	# turntable's 28 above. It stops short of Mars's arm, which sweeps over it.
	var crank: int = model.add("3706", Transform3D(_turn_x_to(Y), Vector3(0, -11, 60)), _library, 71)
	model.add("46372", Transform3D(up, Vector3(0, -20, 60)), _library, 72)
	model.add("32269", Transform3D(up, Vector3(0, 39, 60)), _library, 72)
	# Mars's arm: the turntable's top, a beam pinned across it.
	var top: int = model.add("99010", Transform3D(Basis.IDENTITY, Vector3(0, 39, 0)), _library, 72)
	var across := Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
	var mars_arm: int = model.add("32524", Transform3D(across, Vector3(0, 59, 30)), _library, 4)
	var along_z := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	model.add("2780", Transform3D(along_z, Vector3(20, 59, 20)), _library, 0)
	model.add("2780", Transform3D(along_z, Vector3(-20, 59, 20)), _library, 0)
	model.build()
	print("    %s" % model.summary())
	_check("two meshes: 20 with 28 below, 20 with the turntable's 28 above (%s)"
		% model.meshes_said(), model.meshes.size() == 2)
	var result: Dictionary = model.solve(model.body_of(crank))
	print(model.describe())
	_check("it turns from the crank (%s)" % result["said"], result["ok"])
	var turn: float = model.spin(model.body_of(crank), Y)
	var earth_rate: float = model.spin(model.body_of(earth_arm), Y) / turn
	var mars_rate: float = model.spin(model.body_of(mars_arm), Y) / turn
	_check("Earth's arm turns 28/20 = 1.4 times the crank, the other way (%.6f)" % earth_rate,
		absf(earth_rate + 1.4) < 1e-5)
	_check("Mars's arm turns 20/28 of the crank, the other way (%.6f)" % mars_rate,
		absf(mars_rate + 20.0 / 28.0) < 1e-5)
	_check("both go round the sun the same way (%s)" % ("yes" if earth_rate * mars_rate > 0.0 else "no"),
		earth_rate * mars_rate > 0.0)
	var years: float = earth_rate / mars_rate
	var error: float = (years / MARS_YEARS - 1.0) * 100.0
	_check("a Mars year is %.4f Earth years here, against 1.8808: %+.1f%%, (28/20)^2 the nearest "
		% [years, error] + "two meshes of these gears give", absf(years - 1.96) < 1e-5 and absf(error) < 5.0)
	_check("Earth rides its arm, the arm's pins hold Mars's beam to the turntable",
		model.body_of(earth) == model.body_of(earth_arm) and model.body_of(mars_arm) == model.body_of(top))
	_check("the frame and the turntable's base stay (%s)" % ("yes" if model.body_of(base) == model.ground else "no"),
		model.body_of(base) == model.ground and model.body_of(frame) == model.ground)
	# One Earth year is 1/1.4 of a crank turn; draw two of them.
	await _draw("orrery", model, 24, TAU / 1.4 * 2.0 / 24.0, crank,
		[[earth_arm, 1.4, "Earth's arm"], [mars_arm, 20.0 / 28.0, "Mars's arm"]])


# -- drawing it ---------------------------------------------------------------


## Draw [param frames] frames, the driver turned [param step] radians a
## frame, and read back off the renderer's copy that each of [param outputs]
## ([key, ratio, words]) turns ratio times as far a frame as [param input]
## (in size: the sign of a mesh at right angles depends on which way round
## its axes are read).
func _draw(name: String, model: Mechanism, frames: int, step: float, input: int,
		outputs: Array) -> void:
	if not StudioRender.possible():
		print("    (headless: nothing drawn)")
		return
	var world := BrickWorld.new()
	world.library = _library
	root.add_child(world)
	var ids: Dictionary = {}   ## key -> brick id
	for key: int in model.parts:
		var row: Array = model.parts[key]
		ids[key] = world.add_brick(str(row[0]), int(row[4]), row[1])
	await process_frame
	var renderer := StudioRender.new()
	root.add_child(renderer)
	renderer.library = _library
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = Vector2i(480, 360)
	settings.contact_shadow = false
	settings.view = "hero"
	var poses: Array = []
	for n: int in frames:
		var placed: Dictionary = model.pose(step * float(n))
		var by_id: Dictionary = {}
		for key: int in placed:
			by_id[ids[key]] = placed[key]
		poses.append(by_id)
	var box := AABB()
	var first: bool = true
	for placed: Dictionary in poses:
		for brick_id: int in placed:
			var part: Lbm.PartMesh = _library.mesh_for(world.get_brick(brick_id).part_id)
			if part == null:
				continue
			var here: AABB = ((placed[brick_id] as Transform3D) * part.bounds).abs()
			box = here if first else box.merge(here)
			first = false
	var watched: Array = [[input, 1.0, "the driver"]]
	watched.append_array(outputs)
	var seen: Array = []   ## per frame, each watched part's angle about its axis
	var pictures: Array = []
	var done: int = await renderer.animate(world, settings, frames,
		func(n: int) -> Dictionary: return poses[n],
		func(_n: int) -> float: return 0.0, box,
		func(_n: int, image: Image) -> void:
			var angles: Array = []
			for one: Array in watched:
				var key: int = one[0]
				var turned: Basis = renderer.staged_transform(ids[key]).basis \
					* (model.rest[key] as Transform3D).basis.inverse()
				angles.append(_about(turned, model.joint_axis(model.body_of(key))))
			seen.append(angles)
			pictures.append(image))
	_check("%s: every frame drawn (%d of %d)" % [name, done, frames], done == frames)
	for w: int in range(1, watched.size()):
		var worst: float = 0.0
		for n: int in range(1, seen.size()):
			var a: float = wrapf(float(seen[n][0]) - float(seen[n - 1][0]), -180.0, 180.0)
			var b: float = wrapf(float(seen[n][w]) - float(seen[n - 1][w]), -180.0, 180.0)
			worst = maxf(worst, absf(absf(b) - absf(a) * float(watched[w][1])))
		_check("%s: in every frame drawn %s turns %.4f times the driver's step, to %.4f°"
			% [name, watched[w][2], float(watched[w][1]), worst], seen.size() == frames and worst < 0.01)
	if pictures.size() > 1:
		_check("%s: the pictures change as it turns (%.4f)" % [name, _difference(pictures[0], pictures[1])],
			_difference(pictures[0], pictures[1]) > 0.0005)
	var folder: String = ProjectSettings.globalize_path("res://shots/mechanism")
	DirAccess.make_dir_recursive_absolute(folder)
	var webp := AnimatedWebP.new(8)
	for n: int in pictures.size():
		(pictures[n] as Image).save_png(folder.path_join("%s_%02d.png" % [name, n]))
		webp.add(pictures[n])
	var file: FileAccess = FileAccess.open(folder.path_join("%s.webp" % name), FileAccess.WRITE)
	if file != null:
		file.store_buffer(webp.bytes())
		file.close()
	print("    pictures: shots/mechanism/%s_00..%02d.png and %s.webp" % [name, pictures.size() - 1, name])
	renderer.queue_free()
	world.queue_free()
	await process_frame


# -- fixtures ------------------------------------------------------------------


## A beam 3 round each point given, its holes along [param way], grounded:
## the bearings a hand-built train turns in.
func _bearings(model: Mechanism, points: Array, way: Vector3) -> void:
	for point: Vector3 in points:
		# 32523's holes run along its local y, its length along z.
		var basis := Basis.IDENTITY
		if way.is_equal_approx(Z):
			basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
		elif way.is_equal_approx(Vector3.RIGHT):
			basis = Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
		model.grounded.append(model.add("32523", Transform3D(basis, point), _library, 71))


## A turn taking local x (an axle's length) to [param way].
static func _turn_x_to(way: Vector3) -> Basis:
	if way.is_equal_approx(Vector3.RIGHT):
		return Basis.IDENTITY
	if way.is_equal_approx(Y):
		return Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	return Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))


## A turn taking local z (a gear's axis) to [param way].
static func _turn_z_to(way: Vector3) -> Basis:
	if way.is_equal_approx(Z):
		return Basis.IDENTITY
	if way.is_equal_approx(Y):
		return Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	return Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))


## How far a rotation turns about [param axis], degrees.
static func _about(turn: Basis, axis: Vector3) -> float:
	var across: Vector3 = (Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).cross(axis).normalized()
	var turned: Vector3 = turn * across
	return rad_to_deg(atan2(axis.dot(across.cross(turned)), across.dot(turned)))


static func _near(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.01 and a.basis.x.distance_to(b.basis.x) < 1e-5 \
		and a.basis.y.distance_to(b.basis.y) < 1e-5 and a.basis.z.distance_to(b.basis.z) < 1e-5


static func _difference(a: Image, b: Image) -> float:
	var total: float = 0.0
	var count: int = 0
	for y: int in range(0, a.get_height(), 3):
		for x: int in range(0, a.get_width(), 3):
			var one: Color = a.get_pixel(x, y)
			var two: Color = b.get_pixel(x, y)
			total += absf(one.r - two.r) + absf(one.g - two.g) + absf(one.b - two.b)
			count += 1
	return total / float(maxi(count, 1))


# -- the model -----------------------------------------------------------------


## A toothed part where it stands.
class Gear extends RefCounted:
	var key: int = 0
	var part: String = ""
	var kind: String = ""      ## spur, double, bevel, crown, worm
	var teeth: int = 0
	var radius: float = 0.0
	var face: float = 0.0
	var centre: Vector3        ## its teeth's plane, on its axis
	var axis: Vector3
	var length: float = 0.0    ## a worm's
	var body: int = 0


## Two gears whose teeth are in each other: where, and which way the teeth
## there move together (a tangent; a worm's axis for a worm).
class GearMesh extends RefCounted:
	var one: Gear
	var other: Gear
	var how: String = ""       ## parallel, right angle, worm
	var point: Vector3
	var along: Vector3


## A joint one body turns on in another: a line, and which body hangs from
## which once the tree is grown from the ground.
class Turn extends RefCounted:
	var a: int = 0
	var b: int = 0
	var point: Vector3
	var way: Vector3
	var parent: int = 0
	var child: int = 0
	var rate: float = 0.0
	var free: bool = false


class Mechanism extends RefCounted:
	## key -> [part id, rest Transform3D, PartMesh, name, colour]
	var parts: Dictionary = {}
	var rest: Dictionary = {}
	var grounded: Array = []
	var ground: int = -1
	var bodies: Dictionary = {}     ## body -> Array of keys
	var gears: Array[Gear] = []
	var meshes: Array[GearMesh] = []
	var turns: Array[Turn] = []     ## every joint between two bodies
	var tree: Array[Turn] = []      ## the ones the tree is grown along, root first
	var loops: int = 0              ## joints closing a loop
	var closing: Array[Turn] = []   ## those joints
	var floating: Array = []        ## bodies no joint reaches from the ground
	var _up: Dictionary = {}        ## union-find
	var _next: int = 1
	var _joint_of: Dictionary = {}  ## body -> its Turn in the tree

	func add(part_id: String, at: Transform3D, library: PartLibrary, colour: int = 71) -> int:
		var key: int = _next
		_next += 1
		var info: PartLibrary.PartInfo = library.parts.get(part_id)
		parts[key] = [part_id, at, library.mesh_for(part_id), info.name if info != null else "",
			colour]
		rest[key] = at
		return key

	func first_key(part_id: String) -> int:
		for key: int in parts:
			if parts[key][0] == part_id:
				return key
		return 0

	func gear_of(part_id: String) -> Gear:
		for gear: Gear in gears:
			if gear.part == part_id:
				return gear
		return null

	func gear_at(key: int) -> Gear:
		for gear: Gear in gears:
			if gear.key == key:
				return gear
		return null

	func body_of(key: int) -> int:
		var at: int = key
		while int(_up.get(at, at)) != at:
			at = int(_up.get(at, at))
		return at

	func _join(one: int, other: int) -> bool:
		var a: int = body_of(one)
		var b: int = body_of(other)
		if a == b:
			return false
		# The smaller key stays the root, so a body's name does not depend
		# on the order things were joined in.
		if a < b:
			_up[b] = a
		else:
			_up[a] = b
		return true

	## Read the bodies, the joints and the meshes off the parts.
	func build() -> void:
		var pieces: Array = []   ## [key, kind, origin, way, lo, hi]
		var holes: Dictionary = {}   ## bucket -> Array of [key, kind, at, way]
		var studs: Array = []    ## [key, at, way]
		var sockets: Dictionary = {}  ## bucket -> Array of [key, at, up]
		for key: int in parts:
			var row: Array = parts[key]
			var mesh: Lbm.PartMesh = row[2]
			var at: Transform3D = row[1]
			if mesh == null:
				continue
			var shaft: Array = _shaft_of(mesh)
			if not shaft.is_empty():
				for piece: Array in shaft:
					var origin: Vector3 = at * (piece[1] as Vector3)
					var way: Vector3 = (at.basis * (piece[2] as Vector3)).normalized()
					pieces.append([key, piece[0], origin, way, piece[3], piece[4]])
			else:
				for connector: Lbm.Connector in mesh.connectors:
					var kind: String = ""
					if connector.kind == "axle_hole":
						kind = "axle"
					elif connector.kind == "pin_hole":
						kind = "round"
					elif connector.kind == "bore" and absf(connector.radius - 6.0) < 0.6:
						kind = "round"
					if kind.is_empty():
						continue
					var middle: Vector3 = connector.position + connector.axis * connector.length * 0.5
					_bucket_in(holes, [key, kind, at * middle, (at.basis * connector.axis).normalized()])
				var spec: Array = GEARS.get(row[0], [])
				if not spec.is_empty() and spec[2] != "none":
					_bucket_in(holes, [key, spec[2], at.origin, (at.basis * (spec[4] as Vector3)).normalized()])
				elif WORMS.has(row[0]):
					_bucket_in(holes, [key, "axle", at.origin, (at.basis * Z).normalized()])
			for connector: Lbm.Connector in mesh.connectors:
				if connector.kind == "stud" and connector.gender == "male":
					studs.append([key, at * connector.position, (at.basis * connector.axis).normalized()])
			for socket: Vector2 in mesh.sockets:
				var point: Vector3 = at * Vector3(socket.x, mesh.bounds.position.y, socket.y)
				_bucket_in(sockets, [key, "socket", point, (at.basis * Vector3.UP).normalized()])

		# An axle keyed in an axle hole is one body with it; an axle or a
		# pin in a round hole turns in it.
		var held: Dictionary = {}    ## "shaft|part" -> [kind, origin, way]
		for piece: Array in pieces:
			var origin: Vector3 = piece[2]
			var way: Vector3 = piece[3]
			for hole: Array in _near_line(holes, origin, way, float(piece[4]), float(piece[5])):
				if hole[0] == piece[0]:
					continue
				if absf((hole[3] as Vector3).dot(way)) < 0.99:
					continue
				var gap: Vector3 = (hole[2] as Vector3) - origin
				var along: float = gap.dot(way)
				if along < float(piece[4]) - REACH_SLACK or along > float(piece[5]) + REACH_SLACK:
					continue
				if (gap - way * along).length() > LINE_SLACK:
					continue
				var how: String = "keyed" if piece[1] == "axle" and hole[1] == "axle" else "turns"
				if piece[1] == "pin" and hole[1] == "axle":
					continue
				var name: String = "%d|%d" % [piece[0], hole[0]]
				if held.has(name) and held[name][0] == "keyed":
					continue
				held[name] = [how, origin, way, piece[0], hole[0]]
		var shafts_turning: Dictionary = {}   ## shaft key -> Array of [holder, origin, way]
		for name: String in held:
			var it: Array = held[name]
			if it[0] == "keyed":
				_join(it[3], it[4])
			else:
				if not shafts_turning.has(it[3]):
					shafts_turning[it[3]] = []
				(shafts_turning[it[3]] as Array).append([it[4], it[1], it[2]])
		# Studs in sockets are one body.
		for stud: Array in studs:
			for socket: Array in _around(sockets, stud[1]):
				if socket[0] == stud[0]:
					continue
				if (socket[2] as Vector3).distance_to(stud[1]) > STUD_SLACK:
					continue
				if (socket[3] as Vector3).dot(stud[2]) < 0.95:
					continue
				_join(stud[0], socket[0])
		# A pin carries nothing of its own: what it joins turns on its line
		# against each other, and a pin in one part only is part of it.
		var lines: Array = []    ## [a, b, origin, way]
		for shaft: int in shafts_turning:
			var holders: Array = shafts_turning[shaft]
			var pin_only: bool = true
			for piece: Array in pieces:
				if piece[0] == shaft and piece[1] != "pin":
					pin_only = false
			var keyed_to_something: bool = false
			for other: int in parts:
				if other != shaft and body_of(other) == body_of(shaft):
					keyed_to_something = true
					break
			if pin_only and not keyed_to_something:
				_join(shaft, holders[0][0])
				for n: int in range(1, holders.size()):
					lines.append([holders[0][0], holders[n][0], holders[n][1], holders[n][2]])
			else:
				for holder: Array in holders:
					lines.append([shaft, holder[0], holder[1], holder[2]])
		# A turntable's top turns on its base.
		for key: int in parts:
			var base_id: String = TURNTABLES.get(parts[key][0], "")
			if base_id.is_empty():
				continue
			var at: Transform3D = parts[key][1]
			for other: int in parts:
				if parts[other][0] != base_id:
					continue
				var there: Transform3D = parts[other][1]
				if there.origin.distance_to(at.origin) < LINE_SLACK \
						and absf((there.basis * Y).normalized().dot((at.basis * Y).normalized())) > 0.99:
					lines.append([key, other, at.origin, (at.basis * Y).normalized()])
		for key: int in grounded:
			_join(grounded[0], key)
		# Two joints between the same two bodies on different lines hold
		# them together: two pins through two beams.
		var changed: bool = true
		while changed:
			changed = false
			var by_pair: Dictionary = {}
			for line: Array in lines:
				var a: int = body_of(line[0])
				var b: int = body_of(line[1])
				if a == b:
					continue
				var pair: String = "%d|%d" % [mini(a, b), maxi(a, b)]
				if not by_pair.has(pair):
					by_pair[pair] = []
				(by_pair[pair] as Array).append(line)
			for pair: String in by_pair:
				var found: Array = by_pair[pair]
				var first: Array = found[0]
				for line: Array in found:
					if not _same_line(first[2], first[3], line[2], line[3]):
						changed = _join(first[0], first[1]) or changed
						break
		turns.clear()
		var seen: Dictionary = {}
		for line: Array in lines:
			var a: int = body_of(line[0])
			var b: int = body_of(line[1])
			if a == b:
				continue
			var pair: String = "%d|%d" % [mini(a, b), maxi(a, b)]
			if seen.has(pair):
				continue
			seen[pair] = true
			var turn := Turn.new()
			turn.a = a
			turn.b = b
			turn.point = line[2]
			turn.way = line[3]
			turns.append(turn)
		bodies.clear()
		for key: int in parts:
			var body: int = body_of(key)
			if not bodies.has(body):
				bodies[body] = []
			(bodies[body] as Array).append(key)
		ground = body_of(grounded[0]) if not grounded.is_empty() else _largest()
		_grow()
		_find_gears()
		_find_meshes()

	func _largest() -> int:
		var best: int = -1
		for body: int in bodies:
			if best < 0 or (bodies[body] as Array).size() > (bodies[best] as Array).size():
				best = body
		return best

	## The tree of joints from the ground outwards, breadth first.
	func _grow() -> void:
		tree.clear()
		_joint_of.clear()
		loops = 0
		closing.clear()
		var reached: Dictionary = {ground: true}
		var frontier: Array = [ground]
		var used: Dictionary = {}
		while not frontier.is_empty():
			var body: int = frontier.pop_front()
			for turn: Turn in turns:
				if used.has(turn):
					continue
				var other: int = -1
				if turn.a == body:
					other = turn.b
				elif turn.b == body:
					other = turn.a
				if other < 0:
					continue
				used[turn] = true
				if reached.has(other):
					loops += 1
					turn.parent = body
					turn.child = other
					closing.append(turn)
					continue
				turn.parent = body
				turn.child = other
				reached[other] = true
				tree.append(turn)
				_joint_of[other] = turn
				frontier.append(other)
		floating.clear()
		for body: int in bodies:
			if not reached.has(body):
				floating.append(body)

	func _find_gears() -> void:
		gears.clear()
		for key: int in parts:
			var row: Array = parts[key]
			var at: Transform3D = row[1]
			var gear := Gear.new()
			gear.key = key
			gear.part = row[0]
			gear.body = body_of(key)
			if GEARS.has(row[0]):
				var spec: Array = GEARS[row[0]]
				gear.kind = spec[0]
				gear.teeth = spec[1]
				gear.radius = LDU_PER_TOOTH * float(spec[1])
				gear.face = spec[3]
				gear.axis = (at.basis * (spec[4] as Vector3)).normalized()
				gear.centre = at.origin + gear.axis * float(spec[5])
			elif WORMS.has(row[0]):
				gear.kind = "worm"
				gear.teeth = 1
				gear.radius = WORMS[row[0]]
				gear.axis = (at.basis * Z).normalized()
				gear.centre = at.origin
				var mesh: Lbm.PartMesh = row[2]
				gear.length = mesh.bounds.size.z if mesh != null else 40.0
			else:
				continue
			gears.append(gear)

	func _find_meshes() -> void:
		meshes.clear()
		for i: int in gears.size():
			for j: int in range(i + 1, gears.size()):
				var one: Gear = gears[i]
				var other: Gear = gears[j]
				if one.body == other.body:
					continue
				var found: GearMesh = null
				if one.kind == "worm" or other.kind == "worm":
					found = _worm_mesh(one, other) if one.kind == "worm" else _worm_mesh(other, one)
				else:
					found = _gear_mesh(one, other)
				if found != null:
					meshes.append(found)

	func _gear_mesh(one: Gear, other: Gear) -> GearMesh:
		var dot: float = one.axis.dot(other.axis)
		var gap: Vector3 = other.centre - one.centre
		if absf(dot) > 0.999:
			if one.kind == "bevel" or other.kind == "bevel":
				return null
			var along: float = gap.dot(one.axis)
			if absf(along) > 6.0:
				return null
			var across: Vector3 = gap - one.axis * along
			if absf(across.length() - one.radius - other.radius) > MESH_SLACK:
				return null
			var mesh := GearMesh.new()
			mesh.one = one
			mesh.other = other
			mesh.how = "parallel"
			mesh.point = one.centre + across.normalized() * one.radius
			mesh.along = one.axis.cross(mesh.point - one.centre).normalized()
			return mesh
		if absf(dot) > 0.02:
			return null
		# At right angles: a bevel with a bevel, or a crown with a spur.
		var faces: bool = (one.kind in ["bevel", "double"] and other.kind in ["bevel", "double"]) \
			or (one.kind == "crown" and other.kind in ["spur", "double"]) \
			or (other.kind == "crown" and one.kind in ["spur", "double"])
		if not faces:
			return null
		var normal: Vector3 = one.axis.cross(other.axis).normalized()
		if absf(gap.dot(normal)) > LINE_SLACK:
			return null
		# Where the two axes cross.
		var t: float = _crossing(one.centre, one.axis, other.centre, other.axis)
		var cross: Vector3 = one.centre + one.axis * t
		var d_one: float = one.centre.distance_to(cross)
		var d_other: float = other.centre.distance_to(cross)
		var face_one: float = one.face if one.kind != "spur" else 0.0
		var face_other: float = other.face if other.kind != "spur" else 0.0
		if absf(d_one - other.radius - face_one) > LINE_SLACK \
				or absf(d_other - one.radius - face_other) > LINE_SLACK:
			return null
		var toward_one: Vector3 = (one.centre - cross).normalized()
		var toward_other: Vector3 = (other.centre - cross).normalized()
		var mesh := GearMesh.new()
		mesh.one = one
		mesh.other = other
		mesh.how = "right angle"
		mesh.point = cross + toward_one * other.radius + toward_other * one.radius
		mesh.along = one.axis.cross(mesh.point - one.centre).normalized()
		return mesh

	func _worm_mesh(worm: Gear, wheel: Gear) -> GearMesh:
		if wheel.kind == "worm" or absf(worm.axis.dot(wheel.axis)) > 0.02:
			return null
		var gap: Vector3 = worm.centre - wheel.centre
		if absf(gap.dot(wheel.axis)) > 3.0:
			return null
		var normal: Vector3 = worm.axis.cross(wheel.axis).normalized()
		if absf(absf(gap.dot(normal)) - worm.radius - wheel.radius) > MESH_SLACK:
			return null
		var t: float = _crossing(worm.centre, worm.axis, wheel.centre, wheel.axis)
		if absf(t) > worm.length * 0.5 + REACH_SLACK:
			return null
		var on_worm: Vector3 = worm.centre + worm.axis * t
		var toward: Vector3 = normal * (-signf(gap.dot(normal)))
		var mesh := GearMesh.new()
		mesh.one = worm
		mesh.other = wheel
		mesh.how = "worm"
		mesh.point = on_worm + toward * worm.radius
		mesh.along = worm.axis
		return mesh

	## Along the first line, where it comes nearest the second.
	static func _crossing(p: Vector3, u: Vector3, q: Vector3, v: Vector3) -> float:
		var w: Vector3 = p - q
		var b: float = u.dot(v)
		var d: float = u.dot(w)
		var e: float = v.dot(w)
		var denominator: float = 1.0 - b * b
		if absf(denominator) < 1e-9:
			return 0.0
		return (b * e - d) / denominator

	static func _same_line(p: Vector3, u: Vector3, q: Vector3, v: Vector3) -> bool:
		if absf(u.dot(v)) < 0.99:
			return false
		var gap: Vector3 = q - p
		return (gap - u * gap.dot(u)).length() <= LINE_SLACK

	## The lengths of axle and pin a part is, in its own frame: [kind, a
	## point on the line, its way, from, to]. Empty for a part with a hole
	## off that line, or whose axles and pins are not on one line. (A hole
	## on it is the part's own: 32062's notch reads as an axle hole.)
	static func _shaft_of(mesh: Lbm.PartMesh) -> Array:
		var males: Array = []
		var holes: Array = []
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "axle_hole" or connector.kind == "pin_hole":
				holes.append(connector)
			if (connector.kind == "axle" or connector.kind == "pin") and connector.gender == "male":
				males.append(connector)
		if males.is_empty():
			return []
		var first: Lbm.Connector = males[0]
		var way: Vector3 = first.axis.normalized()
		var origin: Vector3 = first.position
		for connector: Lbm.Connector in males + holes:
			if not _same_line(origin, way, connector.position, connector.axis.normalized()):
				return []
		# Its reach along the line: the box, corner by corner.
		var lo: float = INF
		var hi: float = -INF
		for n: int in 8:
			var corner: Vector3 = mesh.bounds.position + mesh.bounds.size * Vector3(n & 1, (n >> 1) & 1,
				(n >> 2) & 1)
			var along: float = (corner - origin).dot(way)
			lo = minf(lo, along)
			hi = maxf(hi, along)
		var axles: Array = males.filter(func(c: Lbm.Connector) -> bool: return c.kind == "axle")
		var pins: Array = males.filter(func(c: Lbm.Connector) -> bool: return c.kind == "pin")
		if pins.is_empty():
			return [["axle", origin, way, lo, hi]]
		if axles.is_empty():
			return [["pin", origin, way, lo, hi]]
		# An axle pin: the axle the way its axle connector points.
		var axle: Lbm.Connector = axles[0]
		var split: float = (axle.position - origin).dot(way)
		if axle.axis.dot(way) > 0.0:
			return [["pin", origin, way, lo, split], ["axle", origin, way, split, hi]]
		return [["axle", origin, way, lo, split], ["pin", origin, way, split, hi]]

	static func _bucket_of(at: Vector3) -> Vector3i:
		return Vector3i(floori(at.x / 20.0), floori(at.y / 20.0), floori(at.z / 20.0))

	static func _bucket_in(buckets: Dictionary, row: Array) -> void:
		var box: Vector3i = _bucket_of(row[2])
		if not buckets.has(box):
			buckets[box] = []
		(buckets[box] as Array).append(row)

	static func _around(buckets: Dictionary, at: Vector3) -> Array:
		var out: Array = []
		var home: Vector3i = _bucket_of(at)
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					out.append_array(buckets.get(home + Vector3i(dx, dy, dz), []))
		return out

	## What is in the buckets a length of line passes through.
	static func _near_line(buckets: Dictionary, origin: Vector3, way: Vector3, lo: float,
			hi: float) -> Array:
		var out: Array = []
		var seen: Dictionary = {}
		var at: float = lo - REACH_SLACK
		while at <= hi + REACH_SLACK + 10.0:
			for row: Array in _around(buckets, origin + way * minf(at, hi + REACH_SLACK)):
				if not seen.has(row):
					seen[row] = true
					out.append(row)
			at += 10.0
		return out

	# -- solving --------------------------------------------------------------

	## The joints from the ground to [param body], root first.
	func path(body: int) -> Array[Turn]:
		var out: Array[Turn] = []
		var at: int = body
		while _joint_of.has(at):
			var turn: Turn = _joint_of[at]
			out.push_front(turn)
			at = turn.parent
		return out

	func joint_axis(body: int) -> Vector3:
		var turn: Turn = _joint_of.get(body)
		return turn.way if turn != null else Y

	## A mesh's equation: the teeth at its point move together along its
	## direction. For a worm, the wheel's teeth move along the worm's axis
	## as far as the thread advances.
	func _row(mesh: GearMesh) -> PackedFloat64Array:
		var row := PackedFloat64Array()
		row.resize(tree.size())
		var sides: Array = [[mesh.one, -1.0], [mesh.other, 1.0]]
		for side: Array in sides:
			var gear: Gear = side[0]
			for turn: Turn in path(gear.body):
				var k: int = tree.find(turn)
				var moves: float = turn.way.cross(mesh.point - turn.point).dot(mesh.along)
				if mesh.how == "worm":
					moves += WORM_HAND * WORM_LEAD / TAU * turn.way.dot(mesh.along)
				row[k] += float(side[1]) * moves
		return row

	## A joint closing a loop, as equations: what it joins may only turn
	## against each other about its line. Five of them: no turn about two
	## lines across it, and its point not moving, either way round.
	## Linear, as the meshes are, while every axis stays where it is.
	func _loop_rows(turn: Turn) -> Array:
		var across: Vector3 = turn.way.cross(Vector3.UP if absf(turn.way.y) < 0.9
			else Vector3.RIGHT).normalized()
		var other: Vector3 = turn.way.cross(across).normalized()
		var rows: Array = []
		for n: int in 5:
			var row := PackedFloat64Array()
			row.resize(tree.size())
			for side: Array in [[turn.parent, -1.0], [turn.child, 1.0]]:
				for one: Turn in path(int(side[0])):
					var k: int = tree.find(one)
					var value: float = 0.0
					if n == 0:
						value = one.way.dot(across)
					elif n == 1:
						value = one.way.dot(other)
					else:
						value = one.way.cross(turn.point - one.point)[n - 2]
					row[k] += float(side[1]) * value
			rows.append(row)
		return rows

	## Every joint's rate for one radian of [param driver]'s joint.
	## Returns {ok, locked, said, culprits}.
	func solve(driver: int) -> Dictionary:
		var out: Dictionary = {"ok": false, "locked": false, "said": "", "culprits": []}
		var turn: Turn = _joint_of.get(driver)
		if turn == null:
			out["said"] = "the driver turns on nothing"
			return out
		var held: Array = []
		for loop: Turn in closing:
			held.append_array(_loop_rows(loop))
		var rows: Array = []
		for mesh: GearMesh in meshes:
			rows.append(_row(mesh))
		var column: int = tree.find(turn)
		var answer: Dictionary = _eliminate(held + rows, tree.size(), column)
		if not answer["consistent"]:
			out["locked"] = true
			for n: int in meshes.size():
				var fewer: Array = rows.duplicate()
				fewer.remove_at(n)
				if _eliminate(held + fewer, tree.size(), column)["consistent"]:
					var mesh: GearMesh = meshes[n]
					(out["culprits"] as Array).append("%s %d-%d" % [mesh.how, mesh.one.teeth,
						mesh.other.teeth])
			out["said"] = "locked: the meshes ask for two different turns at once"
			for one: Turn in tree:
				one.rate = 0.0
			return out
		var rates: PackedFloat64Array = answer["rates"]
		var free: Dictionary = answer["free"]
		var moving: int = 0
		for k: int in tree.size():
			tree[k].rate = rates[k]
			tree[k].free = free.has(k)
			if absf(rates[k]) > 1e-12:
				moving += 1
		out["ok"] = true
		out["said"] = "%d of %d joints turn, %d free and following what carries them" % [moving,
			tree.size(), free.size()]
		return out

	## Gaussian elimination of [param rows] (each [param width] wide, equal
	## to 0) with the driver's rate set to 1: {consistent, rates, free
	## (column -> true)}. A free column is left at 0, following what carries
	## it.
	static func _eliminate(rows: Array, width: int, driver: int) -> Dictionary:
		var m: Array = []
		for row: PackedFloat64Array in rows:
			var copy := PackedFloat64Array(row)
			copy.append(0.0)
			m.append(copy)
		var lead := PackedFloat64Array()
		lead.resize(width + 1)
		lead[driver] = 1.0
		lead[width] = 1.0
		m.append(lead)
		var pivots: Dictionary = {}   ## column -> row
		var r: int = 0
		for c: int in width:
			if r == m.size():
				break
			var best: int = -1
			var size: float = 1e-9
			for i: int in range(r, m.size()):
				if absf((m[i] as PackedFloat64Array)[c]) > size:
					size = absf((m[i] as PackedFloat64Array)[c])
					best = i
			if best < 0:
				continue
			var swap: PackedFloat64Array = m[best]
			m[best] = m[r]
			m[r] = swap
			var pivot: PackedFloat64Array = m[r]
			var scale: float = pivot[c]
			for k: int in width + 1:
				pivot[k] /= scale
			m[r] = pivot
			for i: int in m.size():
				if i == r:
					continue
				var other: PackedFloat64Array = m[i]
				var factor: float = other[c]
				if absf(factor) < 1e-15:
					continue
				for k: int in width + 1:
					other[k] -= factor * pivot[k]
				m[i] = other
			pivots[c] = r
			r += 1
		for i: int in range(r, m.size()):
			if absf((m[i] as PackedFloat64Array)[width]) > 1e-7:
				return {"consistent": false, "rates": PackedFloat64Array(), "free": {}}
		var rates := PackedFloat64Array()
		rates.resize(width)
		var free: Dictionary = {}
		for c: int in width:
			if pivots.has(c):
				rates[c] = (m[pivots[c]] as PackedFloat64Array)[width]
			else:
				free[c] = true
		return {"consistent": true, "rates": rates, "free": free}

	## How fast [param body] turns about [param about], radians for one of
	## the driver's: the sum of every joint's rate on its way from the ground.
	func spin(body: int, about: Vector3) -> float:
		var omega := Vector3.ZERO
		for turn: Turn in path(body):
			omega += turn.way * turn.rate
		return omega.dot(about.normalized())

	## Whether a part turns with another: the same transform relative to
	## where they stood, at a turn of the driver.
	func follows(key: int, other: int) -> bool:
		var placed: Dictionary = pose(0.7)
		var mine: Transform3D = (placed[key] as Transform3D) * (rest[key] as Transform3D).affine_inverse()
		var theirs: Transform3D = (placed[other] as Transform3D) * (rest[other] as Transform3D).affine_inverse()
		return Mechanism._close(mine, theirs) and not Mechanism._close(mine, Transform3D.IDENTITY)

	static func _close(a: Transform3D, b: Transform3D) -> bool:
		return a.origin.distance_to(b.origin) < 0.01 and a.basis.x.distance_to(b.basis.x) < 1e-5 \
			and a.basis.y.distance_to(b.basis.y) < 1e-5 and a.basis.z.distance_to(b.basis.z) < 1e-5

	## Where every part stands with the driver turned [param angle] radians.
	func pose(angle: float) -> Dictionary:
		var at: Dictionary = {ground: Transform3D.IDENTITY}
		for turn: Turn in tree:
			var parent: Transform3D = at.get(turn.parent, Transform3D.IDENTITY)
			var about: Transform3D = Transform3D(Basis.IDENTITY, turn.point) \
				* Transform3D(Basis(turn.way, turn.rate * angle), Vector3.ZERO) \
				* Transform3D(Basis.IDENTITY, -turn.point)
			var both: Transform3D = parent * about
			at[turn.child] = Transform3D(both.basis.orthonormalized(), both.origin)
		var out: Dictionary = {}
		for key: int in parts:
			out[key] = (at.get(body_of(key), Transform3D.IDENTITY) as Transform3D) \
				* (rest[key] as Transform3D)
		return out

	func meshes_said() -> String:
		var said: PackedStringArray = []
		for mesh: GearMesh in meshes:
			said.append("%s %d-%d" % [mesh.how, mesh.one.teeth, mesh.other.teeth])
		return ", ".join(said) if not said.is_empty() else "none"

	## Every body: its parts, what it turns on and how fast. For reading a
	## model the inference got wrong.
	func describe() -> String:
		var lines: PackedStringArray = []
		for body: int in bodies:
			var names: Dictionary = {}
			for key: int in bodies[body]:
				names[parts[key][0]] = int(names.get(parts[key][0], 0)) + 1
			var said: PackedStringArray = []
			for id: String in names:
				said.append("%s%s" % [id, "" if names[id] == 1 else " x%d" % names[id]])
			var turn: Turn = _joint_of.get(body)
			var how: String = "the ground" if body == ground else ("floating" if turn == null
				else "on %d about %s at %s, rate %.4f%s" % [turn.parent, turn.way.snapped(Vector3.ONE * 0.001),
				turn.point.snapped(Vector3.ONE * 0.1), turn.rate, " (free)" if turn.free else ""])
			lines.append("      body %d: %s; %s" % [body, ", ".join(said), how])
		return "\n".join(lines)

	func summary() -> String:
		return "%d parts, %d bodies (the ground %d parts), %d joints in the tree, %d closing loops, " \
			% [parts.size(), bodies.size(), (bodies.get(ground, []) as Array).size(), tree.size(), loops] \
			+ "%d floating; %d gears, %d meshes" % [floating.size(), gears.size(), meshes.size()]
