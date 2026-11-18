## A part picked up off the model goes on by the joint it was picked up by
## (docs/APP_UX9.md, grabseat; StudWorx 11-13).
##
##   godot --headless --path . --script src/dev/grabseat_probe.gd
##   godot --headless --path . --script src/dev/grabseat_probe.gd -- --out=DIR --bin-was=FILE
##
## Twenty parts with joints on more than one face, each stood in the model and
## picked up by each of its joints, the way a person does: X with the pointer
## on that joint (Builder.lift_brick), and a drag with the Select tool begun on
## it (Builder.lift_selection, which a drag of one part carries as Carry).
## Each is then aimed at a target whose joint takes the one held (the
## pointer's line at the target's joint, Builder.update_preview) and put
## down (Builder.place). The joints are the probe's own reading of the part:
## its studs, hollow studs and studs' holes by its exact shape's labels, and
## its pins, axles, holes, bars, clips, balls and sockets by JointSnap. A stud
## or a stud's hole goes on a Plate 1 x 1 (3024) standing upright, so a side
## stud turns up into it, and, for one not pointing up or down, on one standing
## square to it as well; the rest on a part posed onto the joint as the part
## stands (TARGETS).
##
## The bar, line by line:
##   the seat: the joint picked up by lands on the target's joint, to 0.01 LDU:
##     a stud and a hole at one place pointing one way (as Exact.meets joins
##     them), the rest on one line (a ball's centre on the socket's);
##   the bin: the same parts held from the bin and aimed the same way go
##     where today's code put them (--bin-was, written by a run on it with
##     --out), to 0.001 LDU;
##   a ball picked up by its ball goes where the same part from the bin goes
##     (balljoints' seat).
## Run on code without a grip (the gap run), it says, for each part and the
## joint it was picked up by, the joint it went on by, and fails nothing.
## --out=DIR writes grabseat.json (every case) and bin.json there.
extends SceneTree

const PARTS: Array = ["87087", "4070", "99781", "32952", "3700", "32523", "4733", "30414",
	"11211", "44728", "6541", "4085", "60478", "2780", "3701", "6536", "43093", "14419",
	"15456", "3003"]
## The part a stud or a stud's hole goes on, by its stud or its hole.
const STUD_TARGET := "3024"
## What each JointSnap end goes on: [part, the kind of its end], the next
## where the first has no room (a short bar between a ball and a plate takes
## a flat clip, not an upright one).
const TARGETS: Dictionary = {
	"pin": [["3700", "pin_hole"]], "pin_hole": [["2780", "pin"]],
	"axle": [["32064", "axle_hole"]], "axle_hole": [["4519", "axle"]],
	"shaft": [["4085", "bore"], ["61252", "bore"], ["11476", "bore"], ["15712", "bore"]],
	"bore": [["87994", "shaft"]],
	"ball": [["14418", "socket"]], "socket": [["14417", "ball"]],
}
## Where each part stands in the model, and where it goes.
const HOME := Vector3(-400.0, 160.0, 0.0)
const PUT := Vector3(400.0, 160.0, 0.0)
## How near the joint picked up by lands to the target's, LDU (the bar), and
## a bin seat to today's.
const PLACE := 0.01
const SAME_SEAT := 0.001

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _gripped: bool = false
## The grip's class, where there is one (not on the gap run's code).
var _grip_script: GDScript = null
var _out: String = ""
var _bin_was: String = ""
var _cases: Array = []
var _bin: Dictionary = {}
## --only=PART,PART: those parts alone; --debug: what the hand said at each.
var _only: PackedStringArray = []
var _debug: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--bin-was="):
			_bin_was = arg.substr(10)
		elif arg.begins_with("--only="):
			_only = arg.substr(7).split(",")
		elif arg == "--debug":
			_debug = true
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	await process_frame
	_gripped = "grip" in _builder
	if _gripped:
		_grip_script = load("res://src/assembly/grip.gd")
	print("grabseat: %s" % ("a part goes on by the joint it was picked up by" if _gripped
		else "the gap run: today's code, no grip"))

	for part_id: String in PARTS:
		if _only.is_empty() or _only.has(part_id):
			_part(part_id)
	_summary()
	_bin_against()
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
		_write(_out.path_join("grabseat.json"), {"gripped": _gripped, "cases": _cases})
		_write(_out.path_join("bin.json"), _bin)
	print("")
	if _failures == 0:
		print("grabseat: passed" if _gripped else "grabseat: gap run done")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	if not passed:
		print("  FAIL  %s" % said)
		_failures += 1


func _clear() -> void:
	if _builder.is_carrying():
		_builder.carrying.drop()
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_builder.clear_selection()


# -- a part, each of its joints, both ways of picking it up ---------------------


func _part(part_id: String) -> void:
	var shape: Exact.Shape = Exact.shape_for(_library, part_id)
	var joints: Array = _joints(part_id)
	print("\n%s %s: %d joints" % [part_id, _name(part_id), joints.size()])
	for joint: Array in joints:
		var targets: Array = _targets_for(part_id, shape, joint)
		if targets.is_empty():
			print("  %s: nothing here takes it" % joint[0])
		for ways: Array in targets:
			var target: Array = _fitting(part_id, ways)
			if target.is_empty():
				print("  %s on %s: no room there by this joint, either way" % [joint[0], ways[0][3]])
				_cases.append({"part": part_id, "joint": joint[0], "target": ways[0][3],
					"way": "-", "result": "no room on the target by this joint"})
				continue
			for way: String in ["x", "drag"]:
				_case(part_id, shape, joints, joint, target, way)
			_bin_case(part_id, joint, target)


## The first of [param ways] to stand a target where the part has room on it
## by the joint, by the rule the hand puts parts by; [] for none.
func _fitting(part_id: String, ways: Array) -> Array:
	for target: Array in ways:
		_clear()
		if _builder.put_part(str(target[0]), 1, target[1]) != 0 \
				and _builder.room_for(part_id, target[4], false, true):
			return target
	return []


## Every joint of [param part_id] in its own frame: [said, kind, the exact
## connector's index or the JointSnap end]. kind is "stud", "hole" or the end's.
func _joints(part_id: String) -> Array:
	var out: Array = []
	var shape: Exact.Shape = Exact.shape_for(_library, part_id)
	for k: int in shape.connector_count() if shape != null else 0:
		var stud: bool = shape.kind[k] == Exact.STUD \
			and (shape.sub[k] == Exact.S_STUD or shape.sub[k] == Exact.S_OPEN)
		var hole: bool = shape.kind[k] == Exact.HOLE and shape.sub[k] == Exact.S_HOLE
		if not stud and not hole:
			continue
		var way: Vector3 = (-shape.frames[k].basis.y).normalized()
		out.append(["%s %s at %s" % ["stud" if stud else "stud's hole", _dir(way if stud else -way),
			_v(shape.frames[k].origin)], "stud" if stud else "hole", k])
	for end: JointSnap.End in JointSnap.ends_for(_library, part_id):
		out.append(["%s %s at %s" % [JointSnap.SAID.get(end.kind, end.kind), _dir(end.axis),
			_v(end.at)], end.kind, end])
	return out


## The targets for one joint, the part standing upright where it goes (PUT),
## each a list of ways to stand it, of which the first with room for both is
## used: [the target part, where it stands, its joint (index or end), what it
## is said as, where the part held goes on it]. None for a joint nothing here
## takes.
func _targets_for(part_id: String, shape: Exact.Shape, joint: Array) -> Array:
	var out: Array = []
	var kind: String = joint[1]
	if kind == "stud" or kind == "hole":
		var theirs: Exact.Shape = Exact.shape_for(_library, STUD_TARGET)
		var t: int = -1
		for k: int in theirs.connector_count():
			if (theirs.kind[k] == Exact.STUD) == (kind == "hole") \
					and (theirs.sub[k] == Exact.S_HOLE or theirs.sub[k] == Exact.S_STUD):
				t = k
		var k: int = joint[2]
		var way: Vector3 = (-shape.frames[k].basis.y).normalized()
		# Upright: the part turned so its joint's way is the plate's (a stud
		# up into the plate's hole, a hole down onto its stud), as little as
		# that takes.
		var turned: Basis = JointSnap._turned_onto(Basis.IDENTITY, way, Vector3.UP)
		var at := Transform3D(turned, PUT)
		var upright := Transform3D(Basis.IDENTITY,
			at * shape.frames[k].origin - theirs.frames[t].origin)
		out.append([[STUD_TARGET, upright, t, "an upright %s's %s" % [STUD_TARGET,
			"hole" if kind == "stud" else "stud"], at]])
		# Square to it, for a joint on a side: the plate turned so its joint
		# meets this one as the part stands.
		if absf(way.y) < 0.99:
			var plate: Basis = JointSnap._turned_onto(Basis.IDENTITY,
				(-theirs.frames[t].basis.y).normalized(), way)
			var stands := Transform3D(Basis.IDENTITY, PUT)
			var square := Transform3D(plate,
				stands * shape.frames[k].origin - plate * theirs.frames[t].origin)
			out.append([[STUD_TARGET, square, t, "a %s on its side" % STUD_TARGET, stands]])
		return out
	if not TARGETS.has(kind):
		return out
	var mine: JointSnap.End = joint[2]
	var stands := Transform3D(Basis.IDENTITY, PUT)
	var held: JointSnap.End = mine.placed(stands, 0)
	var ways: Array = []
	for each: Array in TARGETS[kind]:
		var target_part: String = each[0]
		for end: JointSnap.End in JointSnap.ends_for(_library, target_part):
			if end.kind != each[1] or not JointSnap.mates(end, held):
				continue
			# The target posed onto the joint as the part stands, as the hand
			# would put it there (JointSnap.pose), each way it can go, turned
			# about it and, a bar or a clip, along it: the first with room for
			# both is the target.
			# A bar in a clip as the hand puts one (JointSnap.ways): the shorter
			# wholly along the longer, middle on middle first, then at either end.
			var slides: Array = [0.0]
			if end.is_round():
				var mine_long: float = mine.reach
				var theirs_long: float = end.reach
				slides = [mine_long * 0.5, mine_long - theirs_long * 0.5, theirs_long * 0.5] \
					if theirs_long >= mine_long \
					else [mine_long * 0.5, theirs_long * 0.5, mine_long - theirs_long * 0.5]
			for side: int in [1, -1]:
				for roll: float in [0.0, 90.0, 180.0, 270.0]:
					for slide: float in slides:
						var there: Transform3D = JointSnap.pose(end, held, side, slide, roll,
							Basis.IDENTITY)
						ways.append([target_part, there, end, "a %s's %s" % [target_part,
							JointSnap.SAID.get(end.kind, end.kind)], stands])
	if not ways.is_empty():
		out.append(ways)
	return out


func _case(part_id: String, shape: Exact.Shape, joints: Array, joint: Array, target: Array,
		way: String) -> void:
	_clear()
	var home := Transform3D(Basis.IDENTITY, HOME)
	var row: Dictionary = {"part": part_id, "joint": joint[0], "target": target[3], "way": way}
	_cases.append(row)
	var id: int = _builder.put_part(part_id, 4, home)
	var there: Transform3D = target[1]
	var tid: int = _builder.put_part(str(target[0]), 1, there)
	if id == 0 or tid == 0:
		row["result"] = "not put in the model"
		return
	var press: Array = _press(part_id, home, joint, id)
	if press.is_empty():
		row["result"] = "cannot be pressed"
		print("  %-5s %s: no line to it from outside the part" % [way, joint[0]])
		_ok(not _gripped, "%s %s: no line to it" % [part_id, joint[0]])
		return
	row["held_by"] = press[2]
	var lifted: bool = false
	if way == "x":
		lifted = bool(_builder.call("lift_brick", id, press[0], press[1])) if _gripped \
			else _builder.lift_brick(id)
	else:
		_builder.clear_selection()
		_builder.select_brick(id, false)
		lifted = (int(_builder.call("lift_selection", [press[0], press[1]])) if _gripped
			else _builder.lift_selection()) > 0
	if not lifted:
		row["result"] = "not lifted"
		_ok(false, "%s %s: not lifted" % [part_id, joint[0]])
		return
	var aims: Array = _aims(target)
	_aim_over(aims)
	var aim: Array = aims[0]
	var valid: bool = _builder.can_place()
	if _debug:
		print("    debug %s: on a joint %s (%s), grip %s, carrying %s, ghost %s, valid %s, aimed from %s going %s" % [
			way, _builder.is_on_joint(), _builder.joint_words(),
			_builder.get("_grip_on"), _builder.is_carrying(),
			_numbers(_builder.ghost_transform()), valid, aim[0], aim[1]])
		print("    debug target %s at %s" % [target[3], _numbers(target[1])])
	var put: int = _builder.place()
	if put == 0:
		row["result"] = "refused (the ghost red)" if not valid else "not put"
		print("  %-5s %s → %s: not put down" % [way, joint[0], target[3]])
		_ok(not _gripped, "%s %s by %s: not put down on %s" % [part_id, way, joint[0], target[3]])
		return
	var final: Transform3D = _world.get_brick(put).transform
	var by: Array = []
	for other: Array in joints:
		if _lands(part_id, other, final, str(target[0]), target[2], there):
			by.append(other[0])
	var landed: bool = by.has(joint[0])
	row["went_on_by"] = by
	row["at"] = _numbers(final)
	row["result"] = "on by it" if landed else "on by another" if not by.is_empty() else "on by none"
	print("  %-5s held by %s → %s: on by %s%s" % [way, joint[0], target[3],
		"none" if by.is_empty() else ", ".join(by), "" if landed else "   <- not the joint held"])
	if _gripped:
		_ok(landed, "%s by %s (%s): went on by %s" % [part_id, joint[0], way,
			"none" if by.is_empty() else ", ".join(by)])
		if way == "x" and joint[1] == "ball" and _bin.has(_bin_key(part_id, joint, target)):
			var from_bin: Array = _bin[_bin_key(part_id, joint, target)]
			_ok(not from_bin.is_empty() and _same(final, from_bin, PLACE),
				"%s by its ball: %s, from the bin %s" % [part_id, _numbers(final), from_bin])


## The same part held from the bin, upright, and aimed the same way: where it
## goes, for today's code to be compared with.
func _bin_case(part_id: String, joint: Array, target: Array) -> void:
	_clear()
	var there: Transform3D = target[1]
	if _builder.put_part(str(target[0]), 1, there) == 0:
		return
	_builder.held_part = part_id
	_builder.held_color = 4
	_builder.held_face = "up"
	_builder.held_rotation = 0
	_aim_over(_aims(target))
	var put: int = _builder.place()
	_bin[_bin_key(part_id, joint, target)] = _numbers(_world.get_brick(put).transform) \
		if put != 0 else []


func _bin_key(part_id: String, joint: Array, target: Array) -> String:
	return "%s|%s|%s" % [part_id, joint[0], target[3]]


func _bin_against() -> void:
	if _bin_was.is_empty():
		return
	var was: Variant = JSON.parse_string(FileAccess.get_file_as_string(_bin_was))
	if not was is Dictionary:
		_ok(false, "the bin's seats from today's code: %s unread" % _bin_was)
		return
	var same: int = 0
	for key: String in _bin:
		var then: Array = (was as Dictionary).get(key, [-1])
		var now: Array = _bin[key]
		var alike: bool = then.size() == now.size()
		for n: int in now.size() if alike else 0:
			alike = alike and absf(float(now[n]) - float(then[n])) <= SAME_SEAT
		if alike:
			same += 1
		else:
			_ok(false, "from the bin, %s: today %s, now %s" % [key, then, now])
	print("\nthe bin: %d of %d seats as today's code put them" % [same, _bin.size()])


func _summary() -> void:
	var by_way: Dictionary = {}
	for row: Dictionary in _cases:
		var key: String = row["way"]
		if not by_way.has(key):
			by_way[key] = {}
		var tally: Dictionary = by_way[key]
		var result: String = str(row.get("result", ""))
		tally[result] = int(tally.get(result, 0)) + 1
	print("\n%d cases over %d parts" % [_cases.size(), PARTS.size()])
	for key: String in by_way:
		print("  %s: %s" % ["X over the joint" if key == "x" else "a drag begun on the joint",
			JSON.stringify(by_way[key])])


# -- the pointer -----------------------------------------------------------------


## A line from outside the part, standing at [param home], that meets it at
## [param joint] as a person points at it to pick it up: [from, way, said].
## Along a stud or a stud's hole into it; at a hole's mouth beside its line;
## across a pin, an axle, a bar, a clip or a ball. With a grip, the first
## line whose grip holds the joint; without, the first that meets the part.
func _press(part_id: String, home: Transform3D, joint: Array, id: int) -> Array:
	var tries: Array = []   ## [point, way into the part]
	if joint[2] is int:
		var shape: Exact.Shape = Exact.shape_for(_library, part_id)
		var frame: Transform3D = home * shape.frames[int(joint[2])]
		var way: Vector3 = (-frame.basis.y).normalized()
		var open: Vector3 = way if joint[1] == "stud" else -way
		# A stud's hole in a Technic hole's mouth is pressed on the face
		# round it, the hole itself open to the line.
		for off: Vector3 in _across(open, [0.0, 2.0, 4.0] if joint[1] == "stud"
				else [0.0, 2.0, 4.0, 7.0, 9.0]):
			tries.append([frame.origin + off, -open])
	else:
		var end: JointSnap.End = (joint[2] as JointSnap.End).placed(home, id)
		if end.is_hole() or end.is_wrap():
			for side: int in [1, -1]:
				var mouth: Vector3 = end.at + end.axis * end.reach * side
				for off: Vector3 in _across(end.axis, [7.0, 5.0, 9.0]):
					tries.append([mouth + off, -end.axis * side])
		else:
			var middle: Vector3 = end.middle()
			for along: float in [0.0, 2.0, -2.0]:
				for off: Vector3 in _across(end.axis, [1.0]):
					tries.append([middle + end.axis * along, -off])
			# On its end, along it: a side stud's clip, a pin's tip, a bar's.
			for side: int in [1, -1]:
				for off: Vector3 in _across(end.axis, [0.0, 2.0, 4.0, 5.0, 7.0]):
					tries.append([middle + end.axis * side * 300.0 + off, -end.axis * side])
	for one: Array in tries:
		var way: Vector3 = (one[1] as Vector3).normalized()
		var from: Vector3 = (one[0] as Vector3) - way * 300.0
		var hit: BrickLattice.Hit = _builder.lattice.raycast(from, way)
		if hit.brick_id != id:
			continue
		if _gripped:
			var grip: Variant = _grip_script.call("picked", _library, part_id, home, from, way,
				hit.distance)
			if grip == null or not _holds(grip, joint):
				continue
		return [from, way, "the line %s going %s" % [_v(from + way * hit.distance), _dir(way)]]
	return []


## Whether a grip holds [param joint].
func _holds(grip: Variant, joint: Array) -> bool:
	if joint[2] is int:
		return (grip.studs as PackedInt32Array).has(int(joint[2]))
	var mine: JointSnap.End = joint[2]
	for end: JointSnap.End in grip.ends:
		if end.kind == mine.kind and end.at.is_equal_approx(mine.at) \
				and end.axis.is_equal_approx(mine.axis):
			return true
	return false


## Points round a line going [param axis]: square to it, each [param radii]
## out; and the line itself for a radius of 0.
func _across(axis: Vector3, radii: Array) -> Array:
	var out: Array = []
	for radius: float in radii:
		if radius == 0.0:
			out.append(Vector3.ZERO)
			continue
		for square: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.UP, Vector3.LEFT,
				Vector3.FORWARD, Vector3.DOWN]:
			if absf(square.dot(axis)) < 0.01:
				out.append(square * radius)
	return out


## Lines at the target's joint, from where the part held comes to it
## first, as a person moves the pointer over a joint until the ghost is on
## it: [[from, way], ...]. Along a stud or a hole into it; across anything
## else, from each side and a little along it.
func _aims(target: Array) -> Array:
	var there: Transform3D = target[1]
	if target[2] is int:
		var shape: Exact.Shape = Exact.shape_for(_library, str(target[0]))
		var frame: Transform3D = there * shape.frames[int(target[2])]
		var way: Vector3 = (-frame.basis.y).normalized()
		var open: Vector3 = way if shape.kind[int(target[2])] == Exact.STUD else -way
		return [[frame.origin + open * 300.0 + _slant(open), -open]]
	var end: JointSnap.End = (target[2] as JointSnap.End).placed(there, 0)
	var middle: Vector3 = end.middle()
	var held_at: Vector3 = (target[4] as Transform3D).origin
	var from: Vector3 = held_at - middle
	from -= end.axis * from.dot(end.axis)
	var sides: Array = _across(end.axis, [1.0])
	if from.length() >= 1.0:
		sides.push_front(from.normalized())
	var out: Array = []
	# Along a bar or a clip as well, which a part goes on anywhere along.
	var alongs: Array = [0.0, 2.0, -2.0, 4.0, -4.0]
	if end.is_round():
		for k: float in [0.4, -0.4, 0.8, -0.8, 0.95, -0.95, 1.0, -1.0]:
			alongs.append(end.reach * 0.5 * k)
	for along: float in alongs:
		for side: Vector3 in sides:
			var at: Vector3 = middle + end.axis * along
			out.append([at + side * 300.0, -side])
	return out


## The ghost aimed along each of [param lines] in turn until it is on a
## joint (the hand's, or a stud's by a grip) where it can be put down, as a
## person moves the pointer over one until the ghost is green; left on the
## first line where it was on one, red, where none is green; on the first
## line where it was on none.
func _aim_over(lines: Array) -> void:
	var first_on: Array = []
	for line: Array in lines:
		_builder.update_preview(line[0], line[1])
		# Read by name: the gap run's code has neither.
		var on: bool = _builder.is_on_joint() or _builder.get("_grip_on") == true \
			or (_builder.is_carrying() and _builder.carrying.has_method("is_posed")
				and _builder.carrying.call("is_posed"))
		if on and _builder.can_place():
			return
		if on and first_on.is_empty():
			first_on = line
	var back: Array = first_on if not first_on.is_empty() else lines[0]
	_builder.update_preview(back[0], back[1])


## A little off the straight line along a joint, as a person's never is:
## 0.3 LDU across.
func _slant(open: Vector3) -> Vector3:
	return (_across(open, [0.3]) as Array)[0]


# -- what went on --------------------------------------------------------------


## Whether [param joint] of the part, put at [param final], is on the target's
## joint [param theirs] of [param target_part] standing at [param there].
func _lands(part_id: String, joint: Array, final: Transform3D, target_part: String,
		theirs: Variant, there: Transform3D) -> bool:
	if joint[2] is int:
		if not theirs is int:
			return false
		var mine: Array = Exact.Item.new(Exact.shape_for(_library, part_id), final).connector(int(joint[2]))
		var other: Array = Exact.Item.new(Exact.shape_for(_library, target_part), there).connector(
			int(theirs))
		return (mine[1] as Vector3).distance_to(other[1]) <= PLACE \
			and (mine[2] as Vector3).dot(other[2]) >= 0.9999
	if theirs is int:
		return false
	var a: JointSnap.End = (joint[2] as JointSnap.End).placed(final, 0)
	var b: JointSnap.End = (theirs as JointSnap.End).placed(there, 0)
	if not JointSnap.mates(a, b):
		return false
	if a.is_ball():
		return a.at.distance_to(b.at) <= PLACE
	var off: Vector3 = a.at - b.at
	return (off - b.axis * off.dot(b.axis)).length() <= PLACE and absf(a.axis.dot(b.axis)) >= 0.9999


static func _same(at: Transform3D, numbers: Array, within: float) -> bool:
	var now: Array = _numbers(at)
	for n: int in now.size():
		if absf(float(now[n]) - float(numbers[n])) > within:
			return false
	return true


static func _numbers(at: Transform3D) -> Array:
	return [snappedf(at.origin.x, 0.0001), snappedf(at.origin.y, 0.0001), snappedf(at.origin.z, 0.0001),
		snappedf(at.basis.x.x, 0.0001), snappedf(at.basis.x.y, 0.0001), snappedf(at.basis.x.z, 0.0001),
		snappedf(at.basis.y.x, 0.0001), snappedf(at.basis.y.y, 0.0001), snappedf(at.basis.y.z, 0.0001),
		snappedf(at.basis.z.x, 0.0001), snappedf(at.basis.z.y, 0.0001), snappedf(at.basis.z.z, 0.0001)]


func _name(part_id: String) -> String:
	var info: PartLibrary.PartInfo = _library.parts.get(part_id)
	return Inventory._tidy(info.name) if info != null else part_id


static func _dir(way: Vector3) -> String:
	var names: Dictionary = {Vector3.UP: "up", Vector3.DOWN: "down", Vector3.RIGHT: "+x",
		Vector3.LEFT: "-x", Vector3.BACK: "+z", Vector3.FORWARD: "-z"}
	for key: Vector3 in names:
		if way.dot(key) > 0.999:
			return names[key]
	return _v(way)


static func _v(v: Vector3) -> String:
	return "(%s, %s, %s)" % [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


func _write(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, " "))
