## Every part the CAD task's three sets have off the grid, put where the set
## has it through the interface, part by part, as a person does: taken into
## hand, turned with R and T, aimed with the pointer until its ghost stands
## where the booklet shows it, clicked; and where the pointer cannot say it,
## its place or its swing about its joint typed in Properties (X, Y, Z,
## Hinge). Each checked against the set's file, to the LDU and degree and
## exactly (0.05 LDU, 0.002 of its matrix).
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
##     --resolution 1400x900 --script src/dev/offgrid_probe.gd [-- only=8841]
##
## Off the grid is off the 24 turns, or a place that is not on the 2 LDU
## lattice in some axis (docs/CADTASK.md, gap 4): 5762-1's lights and
## propellers, 8643-1's wheels and tyres, 8841-1's axle and its balance's
## two pans, 39 parts. The parts before each run are put down as the file
## has them; the parts of the run go down one after another, each on the
## ones the interface put before it, in the order a person takes within the
## step (a pan hangs from its plates down, as its pins say). Every part the
## run puts down is checked, and the lights stacked on the off-grid ones too.
## Rows in shots/offgrid/offgrid.json, pictures in shots/offgrid/.
extends SceneTree

const SETS := "res://vendor/omr/files/"
## [file, parts down from the file before the run (by their place in the
## file, from 1), the parts the run puts, in the order taken].
const RUNS := [
	["5762-1_Plane.mpd", 15, [15, 16, 17, 18]],
	["5762-1_Plane.mpd", 50, [50, 51]],
	["8643-1_Combination-with-8644.mpd", 46, [46, 47, 48, 49, 50, 51, 52, 53,
		54, 55, 56, 57, 58, 59, 60, 61]],
	["8841-1_Balance.mpd", 22, [22]],
	["8841-1_Balance.mpd", 38, [45, 44, 41, 40, 38, 39, 42, 43, 46,
		55, 52, 51, 47, 48, 49, 50, 53, 54]],
]
const EXACT_PLACE := 0.05
const EXACT_TURN := 0.002
## Parts the file has a hair off where what holds them puts them, typed to
## the file's place only once the parts that hang from them are down: 8841-1's
## right pan has one pin 0.35 LDU off its hole (-186.7 where its hole is at
## -186.35), and the connector on it is where the hole says.
const TYPED_LAST := {"8841-1_Balance.mpd": [52]}

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Shell
var _rows: Array = []
## Counted for the part being put: what a person did.
var _acts: Dictionary = {}
## Where the pointer was last moved, in the window's units.
var _last_point := Vector2.ZERO
## Parts of the run to type to the file's place at its end (TYPED_LAST):
## [row, brick id, want].
var _later: Array = []


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
	for run: Array in RUNS:
		if not only.is_empty() and not str(run[0]).begins_with(only):
			continue
		await _one_run(run[0], int(run[1]), run[2])
	var path: String = ProjectSettings.globalize_path("res://shots/offgrid/offgrid.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_rows, " "))
	file.close()
	var counts: Dictionary = {}
	for row: Dictionary in _rows:
		counts[row["result"]] = int(counts.get(row["result"], 0)) + 1
	print("")
	print("offgrid: %d parts: %s" % [_rows.size(), counts])
	print("offgrid: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## The file's parts as the app reads it: [part, colour, transform], in the
## file's order.
func _truth_of(file: String) -> Array:
	_main.call("clear_model")
	await _frames(4)
	_store.open_text(FileAccess.get_file_as_string(SETS + file), file.get_basename())
	await _frames(10)
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		out.append([brick.part_id, brick.color_code, brick.transform])
	return out


func _one_run(file: String, before: int, order: Array) -> void:
	print("  %s: %d parts down from the file, then %s through the interface" % [file,
		before - 1, order])
	var truth: Array = await _truth_of(file)
	_main.call("clear_model")
	await _frames(4)
	var box := AABB()
	for n: int in range(before - 1):
		var put: Array = truth[n]
		var id: int = _world.add_brick(put[0], put[1], put[2])
		_builder.register(id, put[0], put[2])
	for index: int in order:
		var want: Transform3D = truth[index - 1][2]
		var mesh: Lbm.PartMesh = _library.mesh_for(truth[index - 1][0])
		var here: AABB = (want * mesh.bounds).abs() if mesh != null else AABB(want.origin, Vector3.ONE)
		box = here if box.size == Vector3.ZERO else box.merge(here)
	_builder.clear_selection()
	await _frames(10)
	var made: Dictionary = {}
	_later = []
	for index: int in order:
		var put: Array = truth[index - 1]
		var row: Dictionary = await _put_one(file, index, put, made)
		_rows.append(row)
	# The file's own hairs, typed now that nothing more hangs from them.
	for later: Array in _later:
		var row: Dictionary = later[0]
		var brick_id: int = later[1]
		var want: Transform3D = later[2]
		row["typed"] = await _type_to(brick_id, want)
		var got: Transform3D = _world.get_brick(brick_id).transform
		row["final"] = _ldr_of(got)
		row["off_ldu"] = snappedf(got.origin.distance_to(want.origin), 0.001)
		row["off_degrees"] = snappedf(rad_to_deg(Quaternion(got.basis.orthonormalized())
			.angle_to(Quaternion(want.basis.orthonormalized()))), 0.001)
		row["acts"] = _acts.duplicate()
		var exact: bool = _near(got, want, EXACT_PLACE, EXACT_TURN)
		row["result"] = "exact, typed" if exact else "off"
		_check("%s #%d %s, typed last to the file's place: %s (%s; wanted %s; typed %s)" % [
			file.get_slice("_", 0), int(row["index"]), row["part"], row["result"], row["final"],
			row["want"], ", ".join(row["typed"])], exact)
		_builder.clear_selection()
	await _shot("%s_%d" % [file.get_basename().get_slice("_", 0), before])


## One part: aimed at what holds it as the file has it and clicked, then its
## place or swing typed where the pointer could not say it.
func _put_one(file: String, index: int, put: Array, made: Dictionary) -> Dictionary:
	_acts = {"point": 0, "click": 0, "key": 0, "typed": 0}
	var part: String = put[0]
	var want: Transform3D = put[2]
	var row: Dictionary = {"set": file, "index": index, "part": part,
		"want": _ldr_of(want)}
	await _hold(part)
	_builder.held_color = int(put[1])
	var how: String = await _aim(part, want)
	row["aimed"] = how
	if _builder.ghost_place() == null or not _builder.can_place():
		row["ghost"] = "none" if _builder.ghost_place() == null else "red"
		row["result"] = "not placed"
		row["acts"] = _acts.duplicate()
		_check("%s #%d %s: a ghost that may go (%s)" % [file.get_slice("_", 0), index, part,
			row["ghost"]], false)
		await _key(KEY_ESCAPE)
		_as_the_file(0, put, made, index)
		return row
	row["ghost"] = _ldr_of(_builder.ghost_transform())
	var at: Vector2 = _last_point
	var shown: Transform3D = _builder.ghost_transform()
	await _move(at + Vector2(0, 1))
	await _move(at)
	if not _near(_builder.ghost_transform(), shown, 0.01, 0.0005):
		print("    the ghost moved on a second look: %s, was %s" % [
			_ldr_of(_builder.ghost_transform()), _ldr_of(shown)])
	var ids: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		ids[brick.id] = true
	await _click_whole(at)
	var brick_id: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not ids.has(brick.id):
			brick_id = brick.id
	await _key(KEY_ESCAPE)
	if brick_id == 0:
		row["result"] = "not placed"
		row["acts"] = _acts.duplicate()
		_check("%s #%d %s: the click put it down" % [file.get_slice("_", 0), index, part], false)
		_as_the_file(0, put, made, index)
		return row
	made[index] = brick_id
	var got: Transform3D = _world.get_brick(brick_id).transform
	row["put"] = _ldr_of(got)
	row["by_pointer"] = _near(got, want, EXACT_PLACE, EXACT_TURN)
	var typed: Array = []
	var last: bool = (TYPED_LAST.get(file, []) as Array).has(index)
	if not _near(got, want, EXACT_PLACE, EXACT_TURN) and not last:
		typed = await _type_to(brick_id, want)
		got = _world.get_brick(brick_id).transform
	if last and not _near(got, want, EXACT_PLACE, EXACT_TURN):
		_later.append([row, brick_id, want])
		row["typed"] = []
		row["final"] = _ldr_of(got)
		row["result"] = "typed last"
		_builder.clear_selection()
		await _frames(3)
		return row
	row["typed"] = typed
	row["final"] = _ldr_of(got)
	row["off_ldu"] = snappedf(got.origin.distance_to(want.origin), 0.001)
	row["off_degrees"] = snappedf(rad_to_deg(Quaternion(got.basis.orthonormalized())
		.angle_to(Quaternion(want.basis.orthonormalized()))), 0.001)
	var exact: bool = _near(got, want, EXACT_PLACE, EXACT_TURN)
	var to_ldu: bool = float(row["off_ldu"]) <= 1.0 and float(row["off_degrees"]) <= 1.0
	row["result"] = ("exact by the pointer" if bool(row["by_pointer"]) else
		("exact, typed" if exact else ("to the LDU and degree" if to_ldu else "off")))
	row["acts"] = _acts.duplicate()
	_check("%s #%d %s: %s (%s; wanted %s; %s%s)" % [file.get_slice("_", 0), index, part,
		row["result"], row["final"], row["want"], how,
		"" if typed.is_empty() else ", typed " + ", ".join(typed)], exact)
	_builder.clear_selection()
	if not exact:
		_as_the_file(brick_id, put, made, index)
	await _frames(3)
	return row


## A part the run could not put where the file has it is put there from the
## file, said so, so the parts after it are tried on what holds them.
func _as_the_file(brick_id: int, put: Array, made: Dictionary, index: int) -> void:
	if brick_id != 0 and _world.get_brick(brick_id) != null:
		_builder.lattice.release(brick_id)
		_world.remove_brick(brick_id)
	var id: int = _world.add_brick(put[0], put[1], put[2])
	_builder.register(id, put[0], put[2])
	made[index] = id
	print("    put from the file, for the parts after it")


# -- aiming ----------------------------------------------------------------------


## Aim the part in hand until its ghost stands at [param want], or as near
## as the pointer brings it: on a joint by its end (T for the next way on, R
## for the next turn about it), else on the studs or face of what it rests
## against. Says how.
func _aim(part: String, want: Transform3D) -> String:
	var mesh: Lbm.PartMesh = _library.mesh_for(part)
	_frame_on(want, mesh)
	await _frames(45)
	# On a joint: the ends of parts down that one of its ends, where the file
	# has it, is on.
	var sites: Array = []
	for end: JointSnap.End in JointSnap.ends_of(mesh):
		var mine: JointSnap.End = end.placed(want, 0)
		for site: JointSnap.End in JointSnap.sites_in(_world, _library):
			if not JointSnap.mates(end, site):
				continue
			if absf(mine.axis.dot(site.axis)) < 0.999:
				continue
			var d: float = _off_line(mine.at, site)
			if d < 2.0:
				sites.append([d, site])
	sites.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var best: Dictionary = {"off": INF, "point": Vector2.ZERO, "t": -1, "r": -1}
	var seen: Dictionary = {"sites": sites.size(), "on": 0, "valid": 0, "aimed": []}
	for pair: Array in sites.slice(0, 4):
		var site: JointSnap.End = pair[1]
		# Looked at from the side the joint opens to, as a person turns the
		# view to see the pin a wheel goes on: the far side's are hidden.
		var holder: BrickWorld.Brick = _world.get_brick(site.brick)
		var middle: Vector3 = (holder.transform * _library.mesh_for(holder.part_id).bounds) \
			.abs().get_center()
		var outward: Vector3 = site.axis if (site.middle() - middle).dot(site.axis) >= 0.0 \
			else -site.axis
		_camera.look_from((outward + Vector3(0.25, 0.7, 0.35)).normalized())
		await _frames(40)
		var point: Vector2 = _screen(site.aimed(_camera.global_position,
			(site.at - _camera.global_position).normalized()))
		await _move(point + Vector2(0, 1))
		await _move(point)
		(seen["aimed"] as Array).append("%s of %s %s" % [site.kind,
			_world.get_brick(site.brick).part_id, "on" if _builder.is_on_joint() else
			("ghost elsewhere" if _builder.ghost_place() != null else "no ghost")])
		for t: int in 4:
			for r: int in 8:
				var off: float = _how_far(want)
				if off < EXACT_PLACE:
					return "on its joint (%s), %d T, %d R" % [site.kind, t, r]
				if _builder.is_on_joint():
					seen["on"] = int(seen["on"]) + 1
					if _builder.can_place():
						seen["valid"] = int(seen["valid"]) + 1
				# Where the file has it, but refused: say what is in the way.
				if _builder.ghost_place() != null and not _builder.can_place() \
						and _near(_builder.ghost_transform(), want, EXACT_PLACE, EXACT_TURN):
					print("    the ghost stands where the file has it, red: in the way %s"
						% _in_the_way(_builder.held_part, want))
				var score: float = _swing_off(want, site)
				if score < float(best["off"]):
					best = {"off": score, "point": point, "t": t, "r": r,
						"pose": _builder.ghost_transform()}
				await _key(KEY_R)
				await _move(point + Vector2(0, 1))
				await _move(point)
			await _key(KEY_T)
			await _move(point + Vector2(0, 1))
			await _move(point)
	# On the studs or against a face: turned as the file has it first.
	var joint_best: Dictionary = best.duplicate()
	if not sites.is_empty():
		print("    joints: %s" % seen)
	# Off every joint, where R and T turn the part itself. Not where a swing
	# and a slide on its joint would take it to the file: that is the way.
	var contacts: Array = _contacts(want, mesh) if float(best["off"]) >= 1000.0 else []
	if not contacts.is_empty():
		best = {"off": INF, "point": Vector2.ZERO, "t": -1, "r": -1}
		await _move(Vector2(root.get_visible_rect().size.x * 0.6, 70))
		await _turn_to(want.basis)
	for contact: Array in contacts:
		for point: Vector3 in contact[1]:
			var on: Vector2 = _screen(point)
			await _move(on)
			var off: float = _how_far(want)
			if off < float(best["off"]):
				best = {"off": off, "point": on, "t": -1, "r": -1}
			if off < EXACT_PLACE:
				return "on the %s of %s" % [contact[2], contact[0]]
	if best["off"] == INF:
		return "nowhere"
	# The nearest it came: for a joint, back to that pose by T and R, as a
	# person turns it back (where R and T stand is the joint's memory, so
	# the presses that found it are not the presses that find it again).
	if int(best["t"]) >= 0:
		var at: Vector2 = best["point"]
		var pose: Transform3D = best["pose"]
		await _move(at + Vector2(0, 1))
		await _move(at)
		for t: int in 4:
			for r: int in 8:
				if _near(_builder.ghost_transform(), pose, 0.01, 0.0005):
					return "on its joint, %.2f off the file (slide %.2f, swing and slide typed)" % [
						_how_far(want), float(best["off"])]
				await _key(KEY_R)
				await _move(at + Vector2(0, 1))
				await _move(at)
			await _key(KEY_T)
			await _move(at + Vector2(0, 1))
			await _move(at)
		return "on its joint, not found again"
	await _move(best["point"])
	return "by the pointer, %.2f off the file%s" % [_how_far(want),
		"" if joint_best["off"] == INF else " (its joint %.2f)" % float(joint_best["off"])]


## How far the ghost on a joint is from [param want] when what is between
## them is a swing about the joint's [param axis] and a slide along it, what
## Hinge and a typed place say: the slide, and a hundredth of the swing's
## degrees; past a thousand when it is any other turn.
func _swing_off(want: Transform3D, site: JointSnap.End) -> float:
	if _builder.ghost_place() == null or not _builder.can_place() or not _builder.is_on_joint():
		return INF
	var axis: Vector3 = site.axis
	var ghost: Transform3D = _builder.ghost_transform()
	var q := Quaternion((want.basis.orthonormalized() * ghost.basis.orthonormalized().inverse()))
	var degrees: float = rad_to_deg(q.get_angle())
	var gap: Vector3 = want.origin - ghost.origin
	if degrees > 0.05 and absf(q.get_axis().dot(axis)) < 0.999:
		return 1000.0 + degrees + gap.length()
	# A swing keeps the part as far from the joint's line as it was: the
	# other end of a plate on the joint is another pose, not a swing away.
	var mine: Vector3 = ghost.origin - site.at
	var theirs: Vector3 = want.origin - site.at
	var round_off: float = absf((mine - axis * mine.dot(axis)).length()
		- (theirs - axis * theirs.dot(axis)).length())
	return absf(gap.dot(axis)) + degrees * 0.01 + round_off * 10.0


## How far the ghost is from [param want]: LDU, and a whole cell more for a
## different turn, so a ghost turned right ranks first.
## The parts the lattice says a part at [param at] would run into.
func _in_the_way(part: String, at: Transform3D) -> Array:
	var names: Array = []
	var packed: PackedInt32Array = _builder.boxes_for(_library.mesh_for(part), at)
	for other: int in _builder.lattice.blockers_boxes(packed):
		var brick: BrickWorld.Brick = _world.get_brick(other)
		names.append(brick.part_id if brick != null else str(other))
	return names


func _how_far(want: Transform3D) -> float:
	if _builder.ghost_place() == null or not _builder.can_place():
		return INF
	var ghost: Transform3D = _builder.ghost_transform()
	var turned: float = 0.0
	for n: int in 3:
		turned += (ghost.basis[n] - want.basis[n]).length()
	return ghost.origin.distance_to(want.origin) + (0.0 if turned < 0.01 else 50.0 + turned)


static func _off_line(point: Vector3, site: JointSnap.End) -> float:
	var v: Vector3 = point - site.at
	return (v - site.axis * v.dot(site.axis)).length() + maxf(0.0, -v.dot(site.axis) - 30.0) \
		+ maxf(0.0, v.dot(site.axis) - site.reach - 30.0)


## The parts down a part at [param want] rests on or against, each with the
## points on the face it meets to aim at: [name, points, face].
func _contacts(want: Transform3D, mesh: Lbm.PartMesh) -> Array:
	var mine: AABB = (want * mesh.bounds).abs()
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		var other: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if other == null:
			continue
		var theirs: AABB = (brick.transform * other.bounds).abs()
		if not theirs.grow(1.5).intersects(mine):
			continue
		# The axis they meet across: the one they overlap least on.
		var meet: AABB = theirs.grow(1.5).intersection(mine)
		var axis: int = 0
		for n: int in 3:
			if meet.size[n] < meet.size[axis]:
				axis = n
		var above: bool = mine.get_center()[axis] > theirs.get_center()[axis]
		var face: float = theirs.end[axis] - 0.6 if above else theirs.position[axis] + 0.6
		var points: Array = []
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		var inner: AABB = theirs.intersection(mine.grow(0.5))
		for i: int in 5:
			for j: int in 5:
				var p := Vector3.ZERO
				p[axis] = face
				p[u] = lerpf(inner.position[u] + 1.0, inner.end[u] - 1.0, (i + 0.5) / 5.0)
				p[v] = lerpf(inner.position[v] + 1.0, inner.end[v] - 1.0, (j + 0.5) / 5.0)
				points.append(p)
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		out.append([info.name if info != null else brick.part_id, points,
			("top" if above else "bottom") if axis == 1 else "side", meet.get_volume()])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[3]) > float(b[3]))
	return out


## The view on the part's place from the side its face is aimed at: from
## above and in front, or, for a part that hangs, from below and to the
## side, the eye kept above the floor as a person orbiting under a model
## that stands on its plate keeps it.
func _frame_on(want: Transform3D, mesh: Lbm.PartMesh) -> void:
	var box: AABB = (want * mesh.bounds).abs()
	_camera.frame(box.grow(16.0))
	var hangs: bool = false
	for brick: BrickWorld.Brick in _world.bricks():
		var other: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if other == null:
			continue
		var theirs: AABB = (brick.transform * other.bounds).abs()
		if theirs.grow(1.5).intersects(box) and theirs.get_center().y > box.get_center().y + 4.0 \
				and theirs.position.y > box.position.y:
			hangs = true
	var up: float = 0.8
	if hangs:
		var distance: float = maxf(float(_camera.get("_target_distance")), 1.0)
		up = clampf((30.0 - box.get_center().y) / distance + 0.08, -0.6, -0.15)
	var flat: float = sqrt(maxf(1.0 - up * up, 0.0))
	_camera.look_from(Vector3(0.57 * flat, up, 0.82 * flat))


# -- typed --------------------------------------------------------------------


## Select the part as a person does, by a click on it, and type in
## Properties what the pointer could not say: its swing about its joint
## (Hinge), then its place (X, Y, Z). Returns what was typed.
func _type_to(brick_id: int, want: Transform3D) -> Array:
	var typed: Array = []
	var inspector: Inspector = _shell.inspector if _shell != null else null
	if inspector == null:
		return ["no Properties"]
	inspector.set_open(true)
	await _select(brick_id)
	if not _builder.selection.has(brick_id):
		return ["could not select it"]
	var got: Transform3D = _world.get_brick(brick_id).transform
	var turn_off: bool = false
	for n: int in 3:
		if (got.basis[n] - want.basis[n]).length() > EXACT_TURN:
			turn_off = true
	if turn_off:
		var angle: Variant = _builder.hinge_angle()
		var to: Variant = _hinge_of(brick_id, want)
		if angle != null and to != null:
			await _type_in(inspector, "prop_hinge", String.num(float(to), 2))
			typed.append("Hinge %s" % String.num(float(to), 2))
	got = _world.get_brick(brick_id).transform
	# Each box is a move of its own: one refused where the others have not
	# yet moved it clear ("no room there") is typed again after them, as a
	# person types it again.
	var names: Array = ["prop_x", "prop_y", "prop_z"]
	for _pass: int in 3:
		for n: int in 3:
			if absf(got.origin[n] - want.origin[n]) > EXACT_PLACE * 0.5:
				await _type_in(inspector, names[n], String.num(snappedf(want.origin[n], 0.01), 2))
				typed.append("%s %s" % ["XYZ"[n], String.num(snappedf(want.origin[n], 0.01), 2)])
				got = _world.get_brick(brick_id).transform
		if got.origin.distance_to(want.origin) <= EXACT_PLACE:
			break
	return typed


## The Hinge that stands the selection at [param want]: its turn off
## square about the joint, as Builder.hinge_angle reads one.
func _hinge_of(brick_id: int, want: Transform3D) -> Variant:
	var now: Variant = _builder.hinge_angle()
	if now == null:
		return null
	var got: Basis = _world.get_brick(brick_id).transform.basis.orthonormalized()
	var turn: Basis = want.basis.orthonormalized() * got.inverse()
	var q := Quaternion(turn)
	var by: float = rad_to_deg(q.get_angle())
	var axis: Vector3 = q.get_axis() if by > 0.001 else Vector3.UP
	var joint_axis: Vector3 = _joint_axis(brick_id)
	if joint_axis.dot(axis) < 0.0:
		by = -by
	return float(now) + by


func _joint_axis(brick_id: int) -> Vector3:
	var ids := PackedInt64Array([brick_id])
	var joint: Dictionary = _builder.call("_joint_of", ids)
	return (joint.get("axis", Vector3.UP) as Vector3).normalized()


func _select(brick_id: int) -> void:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var box: AABB = (brick.transform * mesh.bounds).abs()
	var middle: Vector3 = box.get_center()
	await _key(KEY_V)
	# On its body, not its middle, which a tyre's is not; from the view the
	# part was put down in first, then turned to it from each side in turn,
	# as a person turns to a part to click it.
	var half: Vector3 = box.size * 0.5
	var points: Array = [middle, middle + Vector3(0, half.y - 1.0, 0),
		middle + Vector3(half.x - 2.0, half.y - 1.0, 0), middle + Vector3(-half.x + 2.0, half.y - 1.0, 0),
		middle + Vector3(0, half.y - 1.0, half.z - 2.0), middle + Vector3(0, half.y - 1.0, -half.z + 2.0),
		middle + Vector3(half.x - 1.0, 0, 0), middle + Vector3(-half.x + 1.0, 0, 0),
		middle + Vector3(0, 0, half.z - 1.0), middle + Vector3(0, 0, -half.z + 1.0)]
	var views: Array = [Vector3.ZERO, Vector3(0.35, 0.8, 0.5), Vector3(-0.35, 0.8, 0.5),
		Vector3(0.35, 0.8, -0.5), Vector3(-0.35, 0.8, -0.5)]
	for view: Vector3 in views:
		if view != Vector3.ZERO:
			_camera.frame(box.grow(30.0))
			_camera.look_from(view.normalized())
			await _frames(40)
		for p: Vector3 in points:
			await _click(_screen(p))
			if _builder.selection.has(brick_id) and _builder.selection.size() == 1:
				return
			_builder.clear_selection()
			await _frames(2)


## Click into a box in Properties, select what is in it, type, Enter.
func _type_in(inspector: Inspector, name: String, text: String) -> void:
	await _frames(6)
	var controls: Dictionary = inspector.controls_by_name()
	var spin: SpinBox = controls.get(name)
	if spin == null:
		print("    no %s in Properties" % name)
		return
	var field: LineEdit = spin.get_line_edit()
	# Scrolled to, as a person scrolls a panel the column gives little room.
	var scroll: ScrollContainer = inspector.get("_scroll")
	if scroll != null:
		scroll.ensure_control_visible(spin)
		await _frames(4)
	await _click(field.get_global_rect().get_center())
	if not field.has_focus():
		print("    %s did not take the keys (at %s)" % [name, field.get_global_rect()])
		return
	await _key(KEY_A, true)
	await _type(text)
	await _key(KEY_ENTER)
	_acts["typed"] = int(_acts["typed"]) + 1
	await _frames(6)
	if field.has_focus():
		print("    %s kept the keys after Enter" % name)


# -- helpers ----------------------------------------------------------------------


static func _near(a: Transform3D, b: Transform3D, place: float, turn: float) -> bool:
	if a.origin.distance_to(b.origin) > place:
		return false
	for n: int in 3:
		if (a.basis[n] - b.basis[n]).length() > turn:
			return false
	return true


func _hold(part: String) -> void:
	_main.call("_on_part_chosen", part)
	for _n: int in 600:
		if _library.mesh_for(part) != null:
			break
		await process_frame
	_acts["click"] = int(_acts.get("click", 0)) + 1


## Turned to [param basis] by T and R, as a person turns a part in hand.
func _turn_to(basis: Basis) -> void:
	for _f: int in 6:
		for _r: int in 4:
			var now: Basis = BrickLattice.basis_for(_builder.held_face, _builder.held_rotation)
			if _same_turn(now, basis):
				return
			await _key(KEY_R)
		await _key(KEY_T)


static func _same_turn(a: Basis, b: Basis) -> bool:
	for n: int in 3:
		if (a[n] - b[n]).length() > 0.01:
			return false
	return true


func _ldr_of(at: Transform3D) -> String:
	var numbers: PackedFloat64Array = LdrModel.from_transform(at)
	var words: PackedStringArray = []
	for n: int in numbers.size():
		words.append(String.num(numbers[n], 3 if n < 3 else 4))
	return " ".join(words)


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2) -> void:
	_last_point = at
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	_acts["point"] = int(_acts.get("point", 0)) + 1
	await _frames(3)


func _click(at: Vector2) -> void:
	await _move(at)
	await _click_whole(at)


func _type(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper())
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


## A press and a release in whole pixels, cut down, as a browser's are.
func _click_whole(at: Vector2) -> void:
	var whole: Vector2 = _as_event(at).floor()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = whole
		event.global_position = whole
		Input.parse_input_event(event)
		await _frames(2)
	_acts["click"] = int(_acts.get("click", 0)) + 1
	await _frames(3)


func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	_acts["key"] = int(_acts.get("key", 0)) + 1
	await _frames(3)


func _shot(name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/offgrid/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/offgrid/%s.png" % name)
