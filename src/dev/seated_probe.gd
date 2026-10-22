## What joins a section where a part is seated in another, and where one
## stud goes into a part turned to it, against what a builder would say.
##
##   godot --headless --path . --script src/dev/seated_probe.gd
##   ... -- --survey --sets=1793-1.mpd,7347-1.mpd   (vendor/omr/files names: what each reads)
##
## On real sets, read as Sections, Balance and Grab read them
## (Stability.stud_joints, Sections.joins and graph_of, Bodies):
##   6753-1's hinge control stick is seated in its base, by no stud and no
##     joint the connectors name: what joins it says the base, and the
##     joint graph holds them;
##   its trailer, drawn tipped 2 degrees, has 2 x 12 plates side by side
##     whose turned covers overlap: they touch, and nothing joins them;
##   its steering wheel's 1 x 8 plate is laid at 30 degrees on two hinges'
##     tops: it stands on the tops' studs, not on a stud of each hinge's
##     base under it, and Balance's reading weighs no stud there;
##   its fifth wheel, two liftarm triangles tipped 19 degrees on an axle
##     through the chassis, leans on a stud of the chassis brick under it:
##     it is a body of its own and turns on its axle, and what joins it says
##     no stud of that brick;
##   1793-1's hinge plate 2 x 5 pivot is seated in its top's large hole:
##     what joins it says the top;
##   5767-1's windscreen sides, a plate and a tile swung 16 degrees on a
##     hinge, hold the plate with a handle at their far end on one stud: it
##     turns on that stud, as a plate swung on one stud does, and is not
##     held there by clutch.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _sections: Sections


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_sections = (_main.get("_shell") as Shell).sections.sections
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--survey" in args:
		for arg: String in args:
			if arg.begins_with("--sets="):
				for name: String in arg.trim_prefix("--sets=").split(",", false):
					await _survey("res://vendor/omr/files/" + name)
		quit(0)
		return
	await _tow_truck()
	await _pivot_plate()
	await _swung()
	if _failures == 0:
		print("seated: a part seated in another joins, side by side does not, studs into a part "
			+ "turned to them hold only where it takes them, and one so taken turns")
	else:
		print("seated: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _open(path: String) -> bool:
	if not FileAccess.file_exists(path):
		_check("%s is here (tools/omr.py fetch brings the sets)" % path, false)
		return false
	_main.call("clear_model")
	for _n: int in 3:
		await process_frame
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 400:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	for _n: int in 10:
		await process_frame
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	for _n: int in 5:
		await process_frame
	return _world.brick_count() > 0


func _name(id: int) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	if brick == null:
		return "none"
	var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
	return "#%d %s" % [id, info.name.strip_edges() if info != null else brick.part_id]


func _bricks() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append(brick)
	return out


## The shared reading of [param bricks], with what only touches read too
## (Stability.beside, as what joins a section reads it).
func _joints(bricks: Array) -> Dictionary:
	var judge := Stability.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	var contacts: Dictionary = judge.contacts(bricks)
	var joints: Dictionary = Stability.stud_joints(contacts, _library, _builder.lattice)
	if judge.has_method("beside"):
		judge.call("beside", contacts, _library, _builder.lattice)
	return joints


func _of(part_id: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part_id:
			out.append(brick.id)
	return out


## Whether [param basis] is turned off the square by more than a degree.
static func _turned(basis: Basis) -> bool:
	var square: Basis = basis.orthonormalized()
	for c: int in 3:
		var column: Vector3 = square[c]
		if maxf(absf(column.x), maxf(absf(column.y), absf(column.z))) < 0.99985:
			return true
	return false


static func _ids_set(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for id: int in ids:
		out[id] = true
	return out


## Every part [param ids] is joined to by what joins a section says: part ->
## "on", "carries" or "links".
func _joined(ids: Array) -> Dictionary:
	var held: Dictionary = _sections.joins(_ids_set(ids))
	var out: Dictionary = {}
	for kind: String in ["on", "carries", "links"]:
		for other: int in held[kind]:
			out[other] = kind
	return out


func _tow_truck() -> void:
	print("6753-1:")
	if not await _open("res://vendor/omr/files/6753-1.mpd"):
		return
	var bricks: Array = _bricks()
	var joints: Dictionary = _joints(bricks)
	var graph: Dictionary = _sections.joint_graph(bricks)
	var beside: Dictionary = joints.get("beside", {})

	# The hinge control stick seated in its base.
	var stick: int = 0
	var base: int = 0
	for one: int in _of("4593"):
		for other: int in _of("4592"):
			if (joints["seated"] as Dictionary).has(Stability.pair_of(one, other)):
				stick = one
				base = other
	_check("the hinge control stick is seated in its base (%s in %s)" % [_name(stick), _name(base)],
		stick != 0)
	if stick != 0:
		var key: int = Stability.pair_of(stick, base)
		_check("  and not merely beside it", not beside.has(key))
		_check("  the joint graph holds them", (graph["links"] as Dictionary).has(key))
		_check("  what joins the stick says its base (it says %s)" % str(_joined([stick]).keys()),
			_joined([stick]).has(base))

	# The trailer's plates side by side, tipped 2 degrees.
	var pairs: int = 0
	var joined: int = 0
	for key: int in joints["seated"]:
		var one: BrickWorld.Brick = _world.get_brick(key >> 32)
		var other: BrickWorld.Brick = _world.get_brick(key & 0xFFFFFFFF)
		if one.part_id != "2445" or other.part_id != "2445":
			continue
		pairs += 1
		if not beside.has(key) or (graph["links"] as Dictionary).has(key) or _joined([one.id]).has(other.id):
			joined += 1
	_check("the trailer's 2 x 12 plates side by side, covers overlapping: %d pairs" % pairs, pairs >= 2)
	_check("  only touch, and nothing joins them (%d joined)" % joined, joined == 0)

	# The steering wheel's plate on two hinges at 30 degrees.
	var plate: int = 0
	for id: int in _of("3460"):
		if not _turned(_world.get_brick(id).transform.basis):
			continue
		for top: int in _of("3938"):
			if (joints["studs"] as Dictionary).has(Stability.pair_of(id, top)):
				plate = id
	_check("the steering plate is laid at an angle on two hinges (%s)" % _name(plate), plate != 0)
	if plate != 0:
		var said: Dictionary = _joined([plate])
		var tops: int = 0
		var bases: int = 0
		for other: int in said:
			match _world.get_brick(other).part_id:
				"3938":
					tops += 1 if said[other] == "on" else 0
				"3937":
					bases += 1
		_check("  it stands on the two hinges' tops (%d) and no stud of their bases (%d)" % [tops, bases],
			tops == 2 and bases == 0)
		var weighed: int = 0
		for hinge: int in _of("3937"):
			weighed += int((joints["studs"] as Dictionary).get(Stability.pair_of(hinge, plate), 0))
		_check("  Balance's reading weighs no stud of a base under it (%d)" % weighed, weighed == 0)

	# The fifth wheel: two liftarm triangles tipped 19 degrees on an axle.
	var bodies: Bodies = Bodies.read(_world, _library, _builder.lattice, _store.scenery, _builder.locked)
	var triangles: Array = _of("2905")
	var chassis: Array = _of("32531a")
	_check("the fifth wheel's two triangles and the chassis brick under them (%d, %d)" % [
		triangles.size(), chassis.size()], triangles.size() == 2 and chassis.size() == 1)
	if triangles.size() != 2 or chassis.size() != 1:
		return
	var wheel: int = int(bodies.body_of.get(triangles[0], -1))
	var under: int = int(bodies.body_of.get(chassis[0], -2))
	_check("  the fifth wheel is a body of its own, not the chassis' (%d parts and %d)" % [
		(bodies.members.get(wheel, PackedInt64Array()) as PackedInt64Array).size(),
		(bodies.members.get(under, PackedInt64Array()) as PackedInt64Array).size()], wheel != under)
	var link: Bodies.Link = bodies.parent_link.get(wheel)
	_check("  it turns on its axle (%s)" % (link.words() if link != null else "no joint"),
		link != null and link.kind == "axle")
	var ids: Array = []
	for brick_id: int in bodies.members.get(wheel, PackedInt64Array()):
		ids.append(brick_id)
	var held: Dictionary = _sections.joins(_ids_set(ids))
	_check("  what joins it says no stud of the chassis brick (on %s, carries %s)" % [
		(held["on"] as Dictionary).get(chassis[0], 0), (held["carries"] as Dictionary).get(chassis[0], 0)],
		not (held["on"] as Dictionary).has(chassis[0]) and not (held["carries"] as Dictionary).has(chassis[0]))
	_check("  and still its axle (%d joints)" % int(held["pins"]), int(held["pins"]) > 0)


func _pivot_plate() -> void:
	print("1793-1:")
	if not await _open("res://vendor/omr/files/1793-1.mpd"):
		return
	var bricks: Array = _bricks()
	var joints: Dictionary = _joints(bricks)
	var beside: Dictionary = joints.get("beside", {})
	var found: int = 0
	var joined: int = 0
	for key: int in joints["seated"]:
		var one: int = key >> 32
		var other: int = key & 0xFFFFFFFF
		if not _name(one).contains("Hinge Plate  2 x  5") or not _name(other).contains("Hinge Plate  2 x  5"):
			continue
		found += 1
		if _joined([one]).has(other):
			joined += 1
	_check("the hinge plate 2 x 5 pivot seated in its top's large hole (%d)" % found, found >= 1)
	_check("  what joins the pivot says its top (%d of %d)" % [joined, found], found > 0 and joined == found)


## Whether parts turned [param one] and [param other] stand turned to each
## other off the square by more than a degree.
static func _turned_to(one: Basis, other: Basis) -> bool:
	return _turned(one.orthonormalized().inverse() * other.orthonormalized())


## 5767-1's windscreen: each side's plate and tile, swung 16 degrees on a
## hinge, take the plate with a handle at their far end on one stud, the
## plate's in its socket and its own in the tile. Read as Grab reads them
## (Bodies): every joint between a handle and that plate or tile turns on
## its stud, and none holds it by clutch. (The handles' bars in clips are
## hinges, and not these.)
func _swung() -> void:
	print("5767-1:")
	if not await _open("res://vendor/omr/files/5767-1.mpd"):
		return
	var bodies: Bodies = Bodies.read(_world, _library, _builder.lattice, _store.scenery, _builder.locked)
	var handles: Dictionary = {}
	var turns: Array = []
	var other_kinds: Array = []
	var held: Array = []
	var sides: Dictionary = _ids_set(_of("3710") + _of("2431"))
	for handle: int in _of("60478"):
		var basis: Basis = _world.get_brick(handle).transform.basis
		for link: Bodies.Link in bodies.links:
			for pair: Array in link.pairs:
				var other: int = int(pair[1]) if int(pair[0]) == handle \
					else (int(pair[0]) if int(pair[1]) == handle else 0)
				if other == 0 or not sides.has(other) \
						or not _turned_to(basis, _world.get_brick(other).transform.basis):
					continue
				handles[handle] = true
				if link.kind == "stud":
					turns.append(other)
				else:
					other_kinds.append(link.kind)
		for why: Array in bodies.joined_by.get(handle, []):
			if str(why[1]).begins_with("studs") and sides.has(int(why[0])) \
					and _turned_to(basis, _world.get_brick(int(why[0])).transform.basis):
				handles[handle] = true
				held.append(_name(int(why[0])))
	_check("the windscreen's two plates with a handle, under and over parts swung on a hinge (%d)"
		% handles.size(), handles.size() == 2)
	_check("  each turns on its one stud with them (%d pairs on a joint that turns on a stud, %s)" % [turns.size(),
		str(other_kinds) if not other_kinds.is_empty() else "no other"],
		turns.size() >= 4 and other_kinds.is_empty())
	_check("  and none is held by it (held by studs: %s)" % str(held), held.is_empty())


## What [param path] reads: its seated pairs (beside or not) and pivots.
func _survey(path: String) -> void:
	if not await _open(path):
		return
	var bricks: Array = _bricks()
	var judge := Stability.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	var contacts: Dictionary = judge.contacts(bricks)
	# What Balance pays for the reading, best of three.
	var least: int = 1 << 30
	for _n: int in 3:
		contacts.erase("joints")
		var began: int = Time.get_ticks_usec()
		Stability.stud_joints(contacts, _library, _builder.lattice)
		least = mini(least, Time.get_ticks_usec() - began)
	var joints: Dictionary = contacts["joints"]
	var began: int = Time.get_ticks_usec()
	if judge.has_method("beside"):
		judge.call("beside", contacts, _library, _builder.lattice)
	var told: float = (Time.get_ticks_usec() - began) / 1000.0
	var beside: Dictionary = joints.get("beside", {})
	var pivots: Dictionary = joints.get("pivots", {})
	print("%s: %d parts, %d stud pairs, %d seated (%d beside), %d pivots, read in %.1f ms, beside in %.1f" % [
		path.get_file(), bricks.size(), (joints["studs"] as Dictionary).size(),
		(joints["seated"] as Dictionary).size(), beside.size(), pivots.size(), least / 1000.0, told])
	for key: int in joints["seated"]:
		if not beside.has(key):
			print("  seated: %s in %s" % [_name(key >> 32), _name(key & 0xFFFFFFFF)])
	for key: int in pivots:
		print("  pivot: %s and %s, the stud %s's" % [_name(key >> 32), _name(key & 0xFFFFFFFF),
			_name(int(joints["under"][key]))])
