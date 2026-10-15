## Parts put on each other connector to connector land exactly where
## BrickAgent's attach puts them, seated, and pass the check.
##
##   godot --headless --path . --script src/dev/by_connector_probe.gd [-- --out=DIR]
##
## Our sessions placed every part by its low corner on the lattice, so an arm
## on a clip at 30 degrees was arithmetic they got wrong, and they built none:
## 0% clips, bars, balls and hinges in our BrickBench characters, 4% in
## BrickAgent's (docs/BRICKBENCH.md). A placement can now say
## {"attach": {"to": "torso.hinge[0]", "by": "hinge[0]", "yaw": 240}}.
##
## Each case is one kind of joint: a stud, a side stud, a clip on a bar, a
## ball, a hinge, an axle, and a whole minifigure (hips, legs, arms, hands, a
## head on its neck, a hat, a tool in a hand) stood on a plate. Each must:
##   - put every part where BrickAgent's own placement() puts it, relative to
##     the first part: the poses below are what brickagent (MIT, Kulits and
##     Schmid; b3df55e) printed for the same calls, in LDraw's frame;
##   - be joined to the part it went on by BrickNet's labels, and clear of
##     every other by more than verify.py's 1 LDU (Exact, on the poses built);
##   - pass the whole check as a design (ok, and nothing said by the exact
##     check), or, the hinge folded the way it does not open, be refused
##     as BrickAgent's check refuses it.
## Then the same through an edit: a part attached to a brick standing by its
## number, one to a part a design named, and an edit after it that leaves the
## posed arms standing. And attachment_points says the addresses.
##
## On code without attach (7740d22) every placement lands at its corner, 0, 0,
## 0, and all 43 checks fail.
##
## --out=DIR writes each case's design as DIR/<case>.ldr, for BrickBench's own
## verify.py (tools/bench/brickbench.py has the export).
extends SceneTree

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _store: ModelStore
var _failed: int = 0
var _passed: int = 0
var _out: String = ""

## name, the design's bricks, BrickAgent's poses (stem, then x y z and the
## rotation's rows, LDraw), and whether the check must pass it.
const CASES: Array = [
	["a brick on a stud, turned a quarter",
		[{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0, "name": "base"},
		{"part": "3003", "color": 1, "attach": {"to": "base.stud[5]", "by": "hole[0]", "yaw": 90}}],
		[["3001", 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
		["3003", 20, -24, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0]], true],
	["a round plate on a side stud",
		[{"part": "87087", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0, "name": "holder"},
		{"part": "6141", "color": 47, "attach": {"to": "holder.open[0]", "by": "tube[0]"}}],
		[["87087", 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
		["6141", 0, 10, -18, 1, 0, 0, 0, 0, -1, 0, 1, 0]], true],
	["a bar in a clip, slid and turned",
		# On a column, so the bar hanging from it clears the ground.
		[{"part": "3005", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3005", "color": 72, "x": 0, "y": 3, "z": 0, "rot": 0},
		{"part": "3005", "color": 72, "x": 0, "y": 6, "z": 0, "rot": 0},
		{"part": "4085c", "color": 4, "x": 0, "y": 9, "z": 0, "rot": 0, "name": "clip"},
		{"part": "3957a", "color": 0, "attach": {"to": "clip.clip[0]", "by": "bar[0]",
			"slide": 4, "yaw": 30}}],
		[["4085c", 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
		["3957a", 0, 44, -20, 0.866025, 0, -0.5, 0, 1, 0, 0.5, 0, 0.866025]], true],
	["a ball in its socket, swung",
		[{"part": "22890", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0, "name": "base"},
		{"part": "14418", "color": 71, "attach": {"to": "base.ball[0]", "by": "ball[0]",
			"orient": {"yaw": 150}}}],
		[["22890", 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
		["14418", 55.980762, 0, -15, -0.866025, 0, -0.5, 0, 1, 0, 0.5, 0, -0.866025]], true],
	["a hinge opened 30 degrees",
		[{"part": "3937", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0, "name": "base"},
		{"part": "3938", "color": 4, "attach": {"to": "base.hinge[0]", "by": "hinge[0]", "yaw": -30}}],
		[["3937", 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
		["3938", 0, 1.339746, -5, 1, 0, 0, 0, 0.866025, -0.5, 0, 0.5, 0.866025]], true],
	["the same hinge folded into its base",
		[{"part": "3937", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0, "name": "base"},
		{"part": "3938", "color": 4, "attach": {"to": "base.hinge[0]", "by": "hinge[0]", "yaw": 30}}],
		[["3937", 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
		["3938", 0, 1.339746, 5, 1, 0, 0, 0, 0.866025, 0.5, 0, -0.5, 0.866025]], false],
	["an axle through a beam, slid",
		[{"part": "32523", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0, "name": "beam"},
		{"part": "3705", "color": 0, "attach": {"to": "beam.socket[1]", "by": "axle[0]",
			"slide": 32}}],
		[["32523", 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
		["3705", 0, -32, 0, 0, 1, 0, 1, 0, 0, 0, 0, -1]], true],
	["a minifigure posed on a plate: legs, hips, arms, hands, head, hat, an axe",
		[{"part": "3023b", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0, "name": "stand"},
		{"part": "3816c", "color": 1, "name": "right leg", "attach": {"to": "stand.stud[0]",
			"by": "hole[2]"}},
		{"part": "3815b", "color": 1, "name": "hips", "attach": {"to": "right leg.hinge[0]",
			"by": "hinge[0]"}},
		{"part": "3817c", "color": 1, "name": "left leg", "attach": {"to": "hips.hinge[1]",
			"by": "hinge[0]"}},
		{"part": "973", "color": 15, "name": "torso", "attach": {"to": "hips.fixed[1]",
			"by": "fixed[0]"}},
		{"part": "3818", "color": 15, "name": "right arm", "attach": {"to": "torso.hinge[0]",
			"by": "hinge[0]", "yaw": 240}},
		{"part": "3820", "color": 14, "name": "right hand", "attach": {"to": "right arm.hinge[1]",
			"by": "hinge[0]"}},
		{"part": "3819", "color": 15, "name": "left arm", "attach": {"to": "torso.hinge[1]",
			"by": "hinge[0]", "yaw": 230}},
		{"part": "3820", "color": 14, "name": "left hand", "attach": {"to": "left arm.hinge[1]",
			"by": "hinge[0]"}},
		{"part": "3626b", "color": 14, "name": "head", "attach": {"to": "torso.pin[0]",
			"by": "socket[0]", "yaw": 20}},
		{"part": "3624", "color": 70, "attach": {"to": "head.open[0]"}},
		{"part": "95330", "color": 71, "attach": {"to": "right hand.clip[0]", "by": "bar[0]"}}],
		[["3815b", 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
		["3816c", 0, 12, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
		["3817c", 0, 12, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
		["973", 0, -32, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
		["3818", -15.528431, -23.119074, 0, 0.985431, -0.085037, -0.147288, 0.170074, 0.492716,
			0.853409, 0, -0.866025, 0.5],
		["3820", -20.604632, -23.105863, -21.31788, 0.985431, -0.164279, -0.044018, 0.170074,
			0.951854, 0.255048, 0, -0.258819, 0.965926],
		["3819", 15.528431, -23.119074, 0, 0.985431, 0.109321, -0.130284, -0.170074, 0.633423,
			-0.754884, 0, 0.766044, 0.642788],
		["3820", 23.811577, -4.524395, 8.114643, 0.985431, -0.014823, -0.169427, -0.170074,
			-0.085886, -0.981681, 0, 0.996195, -0.087156],
		["3626b", 0, -56, 0, 0.939693, 0, -0.34202, 0, 1, 0, 0.34202, 0, 0.939693],
		["3624", 0, -56, 0, 0.939693, 0, -0.34202, 0, 1, 0, 0.34202, 0, 0.939693],
		["95330", -22.669938, -11.139204, -30.798076, 0.985431, -0.170068, -0.001484, 0.170074,
			0.985394, 0.008597, 0, -0.008724, 0.999962]], true],
]


func _initialize() -> void:
	_run()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
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
	if Exact.shape_for(_library, "3001") == null:
		print("by connector probe: SKIPPED — this build has no exact shapes (tools/build_exact.py "
			+ "writes assets/generated/exact/)")
		quit(0)
		return
	for case: Array in CASES:
		_case(str(case[0]), case[1], case[2], bool(case[3]))
	await _edits()
	await _addresses()
	_refusals()
	print("by connector probe: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## LDraw's frame to the app's: x, -y, -z.
static func _from_ldraw(row: Array) -> Transform3D:
	var c := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
	var r := Basis(Vector3(row[4], row[7], row[10]), Vector3(row[5], row[8], row[11]),
		Vector3(row[6], row[9], row[12]))
	return Transform3D(c * r * c, c * Vector3(row[1], row[2], row[3]))


## Where each placement of [param model] is built, in the world.
func _built(model: Assistant.Model) -> Array:
	var out: Array = []
	for placement: Assistant.Placement in model.placements:
		var mesh: Lbm.PartMesh = _library.mesh_for(placement.part)
		out.append(_assistant._transform(placement, mesh, model.section_for(placement))
			if mesh != null else Transform3D())
	return out


func _case(name: String, bricks: Array, golden: Array, valid: bool) -> void:
	for brick: Dictionary in bricks:
		if not _library.parts.has(str(brick["part"])):
			_say(false, "", "%s: the library has no part %s" % [name, brick["part"]])
			return
	var model: Assistant.Model = _assistant._read_model({"bricks": bricks})
	var odd := PackedStringArray()
	for placement: Assistant.Placement in model.placements:
		# Read by name, so that on code without attach this runs and fails on
		# where the parts land rather than on a parse error.
		var why: String = str(placement.get("odd_attach")) if placement.get("odd_attach") != null else ""
		var waiting: bool = placement.get("attach") is Dictionary \
			and not (placement.get("attach") as Dictionary).is_empty()
		if not why.is_empty() or waiting:
			odd.append("%s %s%s" % [placement.part, why, " (not done)" if waiting else ""])
	if not odd.is_empty():
		_say(false, "", "%s: not attached: %s" % [name, "; ".join(odd)])
		return
	var at: Array = _built(model)
	# Matched to BrickAgent's by part, in order, relative to its first part.
	var ours: Dictionary = {}       ## stem -> [transforms in order]
	for n: int in model.placements.size():
		var part: String = model.placements[n].part
		if not ours.has(part):
			ours[part] = []
		(ours[part] as Array).append(at[n])
	var root_ours: Transform3D = (ours[str(golden[0][0])] as Array)[0]
	var root_theirs: Transform3D = _from_ldraw(golden[0])
	var taken: Dictionary = {}
	var worst: float = 0.0
	var off := PackedStringArray()
	for row: Array in golden:
		var stem: String = str(row[0])
		var k: int = int(taken.get(stem, 0))
		taken[stem] = k + 1
		if not ours.has(stem) or k >= (ours[stem] as Array).size():
			off.append("%s missing" % stem)
			continue
		var mine: Transform3D = root_ours.affine_inverse() * ((ours[stem] as Array)[k] as Transform3D)
		var theirs: Transform3D = root_theirs.affine_inverse() * _from_ldraw(row)
		var miss: float = mine.origin.distance_to(theirs.origin)
		for c: int in 3:
			miss = maxf(miss, (mine.basis[c] - theirs.basis[c]).length() * 20.0)
		worst = maxf(worst, miss)
		if miss > 0.02:
			off.append("%s %s LDU off" % [stem, str(snappedf(miss, 0.001))])
	_say(off.is_empty(), "%s: every part where BrickAgent puts it (worst %s LDU)" % [name,
		str(snappedf(worst, 0.0001))], "%s: %s" % [name, ", ".join(off)])

	# Seated by BrickNet's labels, and clear by its colliders, on the poses built.
	var items: Array = []
	for n: int in model.placements.size():
		var shape: Exact.Shape = Exact.shape_for(_library, model.placements[n].part)
		items.append(Exact.Item.new(shape, at[n]) if shape != null else null)
	var index_of: Dictionary = {}
	for n: int in model.placements.size():
		index_of[model.placements[n]] = n
	var edges: Array = Exact.connections(items)
	var unjoined := PackedStringArray()
	for n: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[n]
		var on: Variant = placement.get("attached_to")
		if on == null:
			# Every part said by its connectors is put on what it names.
			if n < bricks.size() and (bricks[n] as Dictionary).has("attach"):
				unjoined.append("%s (not attached at all)" % placement.part)
			continue
		var m: int = int(index_of[on])
		if not edges.any(func(e: Array) -> bool:
				return (int(e[0]) == mini(n, m) and int(e[2]) == maxi(n, m))):
			unjoined.append("%s (%s)" % [placement.part, placement.get("attached_by")])
	_say(unjoined.is_empty(), "%s: each joined to what it went on by BrickNet's labels" % name,
		"%s: not joined: %s" % [name, ", ".join(unjoined)])
	var clashes: Array = Exact.clashes(items)
	if valid:
		var said := PackedStringArray()
		for found: Dictionary in clashes:
			said.append("%s and %s, %s LDU" % [model.placements[int(found["a"])].part,
				model.placements[int(found["b"])].part, str(snappedf(float(found["depth"]), 0.01))])
		_say(clashes.is_empty(), "%s: no two parts overlap by more than 1 LDU" % name,
			"%s: overlapping: %s" % [name, ", ".join(said)])

	var report: Dictionary = _assistant._check(model, true)
	var exact_said: Array = []
	for kind: Variant in (report.get("exact", {}) as Dictionary):
		exact_said.append_array(report["exact"][kind])
	if valid:
		_say(bool(report.get("ok", false)) and exact_said.is_empty(),
			"%s: the check passes it (%s)" % [name, report.get("summary", "")],
			"%s: the check says %s: %s" % [name, report.get("summary", ""),
				str(report.get("feedback", "")).left(900)])
	else:
		var named: bool = exact_said.any(func(s: Variant) -> bool:
			return str(s).contains("hinge") and str(s).contains("3938"))
		_say(not bool(report.get("ok", true)) and named and not clashes.is_empty(),
			"%s: refused, as BrickAgent's check refuses it, named as the hinge" % name,
			"%s: %s; exact said %s" % [name, report.get("summary", ""), exact_said])
	if not _out.is_empty() and valid:
		DirAccess.make_dir_recursive_absolute(_out)
		var file: String = _out.path_join(name.split(":")[0].replace(" ", "-") + ".ldr")
		var f := FileAccess.open(file, FileAccess.WRITE)
		f.store_string(_ldr_of(model, at))
		f.close()


## The model as LDraw lines, in LDraw's frame.
func _ldr_of(model: Assistant.Model, at: Array) -> String:
	var c := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
	var lines := PackedStringArray(["0 attach probe", "0 Name: probe.ldr"])
	for n: int in model.placements.size():
		var t: Transform3D = at[n]
		var r: Basis = c * t.basis * c
		var o: Vector3 = c * t.origin
		lines.append("1 %d %s %s %s %s %s %s %s %s %s %s %s %s %s.dat" % [
			model.placements[n].color, _f(o.x), _f(o.y), _f(o.z),
			_f(r.x.x), _f(r.y.x), _f(r.z.x), _f(r.x.y), _f(r.y.y), _f(r.z.y),
			_f(r.x.z), _f(r.y.z), _f(r.z.z), model.placements[n].part])
	return "\n".join(lines) + "\n"


static func _f(v: float) -> String:
	return "%.6f" % v


## The same joints through edit_model, as a session builds on what stands.
func _edits() -> void:
	_world.clear()
	_assistant.forget_built()
	var stood: Variant = await _assistant.use_tool("submit_design", {"name": "probe",
		"bricks": [{"part": "3023b", "color": 72, "x": 4, "y": 0, "z": 4, "rot": 0, "name": "stand"},
		{"part": "3816c", "color": 1, "name": "right leg", "attach": {"to": "stand.stud[0]", "by": "hole[2]"}},
		{"part": "3815b", "color": 1, "name": "hips", "attach": {"to": "right leg.hinge[0]", "by": "hinge[0]"}},
		{"part": "3817c", "color": 1, "name": "left leg", "attach": {"to": "hips.hinge[1]", "by": "hinge[0]"}},
		{"part": "973", "color": 4, "name": "torso", "attach": {"to": "hips.fixed[1]", "by": "fixed[0]"}},
		{"part": "3818", "color": 4, "name": "right arm", "attach": {"to": "torso.hinge[0]", "by": "hinge[0]", "yaw": 200}},
		{"part": "3819", "color": 4, "name": "left arm", "attach": {"to": "torso.hinge[1]", "by": "hinge[0]", "yaw": 160}},
		{"part": "3626b", "color": 14, "name": "head", "attach": {"to": "torso.pin[0]", "by": "socket[0]"}}]})
	var count: int = _world.brick_count()
	_say(count == 8, "submit_design puts the figure down: %d parts" % count,
		"submit_design: %d parts stand (%s)" % [count, str(stood).left(600)])
	# Hands on the arms standing, by name across calls, and a hat by a number.
	var head_id: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3626b":
			head_id = brick.id
	var said: Variant = await _assistant.use_tool("edit_model", {"add": [
		{"part": "3820", "color": 14, "name": "right hand", "attach": {"to": "right arm.hinge[1]", "by": "hinge[0]"}},
		{"part": "3820", "color": 14, "name": "left hand", "attach": {"to": "left arm.hinge[1]", "by": "hinge[0]"}},
		{"part": "3624", "color": 70, "attach": {"to": "#%d.open[0]" % head_id}}]})
	var text: String = _text_of(said)
	_say(_world.brick_count() == 11 and not text.begins_with("Not applied"),
		"edit_model attaches hands to arms named in the design and a hat to brick #%d" % head_id,
		"edit_model: %d parts stand: %s" % [_world.brick_count(), text.left(900)])
	# And an edit after it, which leaves the posed arms where they stand.
	var plate_id: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3023b":
			plate_id = brick.id
	said = await _assistant.use_tool("edit_model", {"recolor": [{"bricks": [plate_id], "color": 0}]})
	text = _text_of(said)
	_say(not text.begins_with("Not applied") and _world.brick_count() == 11,
		"a later edit passes with the posed arms and hands standing",
		"a later edit: %s" % text.left(900))
	# Read back, every part is where it stood: nothing re-seated off its joint.
	var model: Assistant.Model = _assistant._model_from_world()
	var moved := PackedStringArray()
	for placement: Assistant.Placement in model.placements:
		var mesh: Lbm.PartMesh = _library.mesh_for(placement.part)
		var brick: BrickWorld.Brick = _world.get_brick(placement.id)
		var again: Transform3D = _assistant._transform(placement, mesh, model.section_for(placement))
		if again.origin.distance_to(brick.transform.origin) > 0.01:
			moved.append("%s %s LDU" % [placement.part, str(snappedf(
				again.origin.distance_to(brick.transform.origin), 0.01))])
	_say(moved.is_empty() and model.placements.size() == 11,
		"read back, every attached part is written where it stands",
		"read back off where they stand: %s" % ", ".join(moved))


func _text_of(said: Variant) -> String:
	if said is String:
		return said
	var out := PackedStringArray()
	if said is Array:
		for block: Variant in said:
			if block is Dictionary and (block as Dictionary).get("type") == "text":
				out.append(str(block["text"]))
	return "\n".join(out)


## attachment_points says each connector by the address attach takes.
func _addresses() -> void:
	var torso: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "973":
			torso = brick.id
	var said: String = await _assistant._attachment_points({"brick": torso})
	_say(said.contains("#%d.hinge[0]" % torso) and said.contains("#%d.pin[0]" % torso)
		and said.contains("#%d.fixed[0]" % torso),
		"attachment_points names the torso's hinges, pin and fixed joints as #%d.hinge[0]..." % torso,
		"attachment_points on the torso: %s" % said.right(900))
	var part: String = await _assistant._attachment_points({"part": "3815b", "x": 0, "y": 0, "z": 0})
	_say(part.contains("hinge[1]") and part.contains("fixed[1]"),
		"attachment_points on a part number says its hinge[1] and fixed[1]",
		"attachment_points on 3815b: %s" % part.right(600))


## What cannot be done is said, and nothing is built somewhere else instead.
func _refusals() -> void:
	for case: Array in [
		["a connector the part does not have", {"part": "3003", "color": 1,
			"attach": {"to": "base.hinge[0]"}}, "has no hinge"],
		["two connectors that do not mate", {"part": "3003", "color": 1,
			"attach": {"to": "base.stud[0]", "by": "stud[0]"}}, "takes"],
		["a name nothing has", {"part": "3003", "color": 1,
			"attach": {"to": "nobody.stud[0]", "by": "hole[0]"}}, "no part is named"],
		["a stud turned off its axis", {"part": "3003", "color": 1,
			"attach": {"to": "base.stud[0]", "by": "hole[0]", "orient": {"pitch": 30}}},
			"only a ball"],
		["a part with no place at all", {"part": "3003", "color": 1}, "neither where"],
		# A bench session asked for a flame's bar in a round brick's hollow stud
		# ("open"), which takes a stud's kind; the same spot is the brick's clip.
		["a bar asked into a hollow stud, told of the clip there", {"part": "18395",
			"color": 4, "attach": {"to": "base.open[0]", "by": "bar[0]"}},
			"\"to\": \"base.clip[0]\", \"by\": \"bar[0]\" (the same spot)", "3062b"],
	]:
		var model: Assistant.Model = _assistant._read_model({"bricks": [
			{"part": str(case[3]) if case.size() > 3 else "3001", "color": 4, "x": 0, "y": 0,
				"z": 0, "rot": 0, "name": "base"},
			case[1]]})
		var report: Dictionary = _assistant._check(model, true)
		var feedback: String = str(report.get("feedback", ""))
		_say(not bool(report.get("ok", true)) and feedback.contains(str(case[2])),
			"%s: refused, saying so" % case[0],
			"%s: %s / %s" % [case[0], report.get("summary", ""), feedback.left(400)])


func _say(ok: bool, good: String, bad: String) -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % good)
	else:
		_failed += 1
		print("  FAIL %s" % bad)
