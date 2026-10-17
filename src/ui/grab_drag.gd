## A part grabbed in the view with the Select tool and moved about its joint
## as the real thing moves (Grab), with the structure answering as it goes.
##
## Press on a part and drag: if it hangs on a joint (a hinge, a clip, a
## turntable, a pin or an axle in a round hole, a ball, a round stud), its
## whole rigid body and everything beyond it turn, slide or swivel there, the
## gears it drives turn with it, and it stops where it meets the model. A part
## held rigidly to the anchor is carried as before (EditVerbs.drag_start).
##
## While it moves the model is drawn where the drag puts it
## (BrickWorld.set_drawn) and nothing else changes: the model, the lattice,
## the history and the revision stay as they were until the button comes up.
## Each frame it is weighed (Balance.weigh_pose, against the graph read once
## when it was grabbed): the support polygon and the centre of mass on the
## floor, the stud joints past half their working load tinted amber to red,
## the model leaning a few degrees over the edge it would tip over, and a line
## in the status bar. Let go, a joint without friction swings down under its
## own weight (Grab.settle), the pose is one step to undo, and what happens is
## said: "stands", "tips over to the left", a joint's studs carrying about
## 3x their working load.
class_name GrabDrag
extends Node

## A model that would tip leans this far over the edge while it is dragged,
## degrees: enough to see, not a fall.
const LEAN := 4.0
## Weighed at most this often while dragging, ms: a big model's weighing is
## a few milliseconds and the frame comes first.
const WEIGH_EVERY_MS := 50

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var camera: CadCamera
var scenery: Dictionary = {}
var say: Callable = func(_words: String) -> void: pass
## Called once the pose is kept: the model changed.
var edited: Callable = func() -> void: pass

var grab: Grab = null
var report: Balance.Report = null
## What the last drag said when let go, and its report: for a probe.
var last_words: String = ""
var last_report: Balance.Report = null
## Frame costs of the last drag, ms: the worst and the mean of follow + draw
## + weigh, and how many frames.
var worst_ms: float = 0.0
var mean_ms: float = 0.0
var frames: int = 0
## Bodies read once per revision, kept between drags.
var _bodies: Bodies = null
var _judge: Balance = null
var _mark: BalanceMark = null
var _weighed_at: int = 0
var _said: String = ""
var _total_ms: float = 0.0
var _leaning: bool = false


## A drag began on [param brick_id] at [param screen]. True when the drag
## is this tool's (it turns the part on its joint, or says why it cannot);
## false when the part should be carried as before.
func press(brick_id: int, screen: Vector2, selection: Dictionary = {}) -> bool:
	if world == null or camera == null:
		return false
	var origin: Vector3 = camera.ray_origin(screen)
	var direction: Vector3 = camera.ray_normal(screen)
	var hit: BrickLattice.Hit = builder.lattice.raycast(origin, direction)
	var at: Vector3 = origin + direction.normalized() * hit.distance if hit.is_valid() \
		else world.get_brick(brick_id).transform.origin
	grab = Grab.new()
	grab.world = world
	grab.builder = builder
	grab.library = library
	if _bodies == null or _bodies.revision != world.revision:
		_bodies = Bodies.read(world, library, builder.lattice, scenery, builder.locked)
	grab.bodies = _bodies
	var state: String = grab.begin(brick_id, at, selection)
	if state == "rigid":
		grab = null
		return false
	if state != "moves":
		say.call(grab.why)
		last_words = grab.why
		return true
	_judge = Balance.new()
	_judge.library = library
	_judge.lattice = builder.lattice
	_judge.floor_ids = scenery
	if not _judge.prepare(world.bricks()):
		_judge = null
	worst_ms = 0.0
	_total_ms = 0.0
	frames = 0
	_said = ""
	grab.follow(origin, direction, screen, camera)
	_tell("%s — drag to move it" % _capital(grab.said))
	return true


func is_grabbing() -> bool:
	return grab != null


## The pointer moved to [param screen] while the button is down.
func motion(screen: Vector2) -> void:
	if grab == null or grab.state != "moves":
		return
	var started: int = Time.get_ticks_usec()
	grab.follow(camera.ray_origin(screen), camera.ray_normal(screen), screen, camera)
	world.set_drawn(grab.placed)
	var now: int = Time.get_ticks_msec()
	if _judge != null and now - _weighed_at >= WEIGH_EVERY_MS:
		_weighed_at = now
		report = _judge.weigh_pose(grab.placed)
		_show(report, true)
	var line: String = "%s, %s" % [_capital(grab.said), grab.position_words()]
	if grab.stopped:
		line += " — stopped: it meets the model"
	if report != null and not report.empty:
		line += " · " + _standing_words(report, true)
	_tell(line)
	var spent: float = float(Time.get_ticks_usec() - started) / 1000.0
	frames += 1
	_total_ms += spent
	worst_ms = maxf(worst_ms, spent)
	mean_ms = _total_ms / float(frames)


## The button came up: settle what swings, keep the pose as one step, and
## say what the structure does now.
func release() -> String:
	if grab == null:
		return ""
	var held: Grab = grab
	grab = null
	if held.state != "moves":
		return held.why
	var swung: String = held.settle()
	world.set_drawn({})
	_unlean()
	var moved: int = held.commit(held.step_words())
	var words: String
	if moved == 0:
		words = "%s: not moved" % _capital(held.said)
		_clear_marks()
	else:
		words = "%s, %s" % [_capital(held.said), held.position_words()]
		if not swung.is_empty():
			words += "; " + swung
		if _judge != null:
			# Weighed as it now stands: the graph read when it was grabbed
			# (a turn on a joint moves no stud joint), the parts where the
			# pose left them.
			last_report = _judge.weigh_pose(held.placed)
			words += ". " + _standing_words(last_report, false)
			_show(last_report, false)
		edited.call()
	last_words = words
	_said = ""
	say.call(words)
	return words


## Escape, or the drag lost: everything back where it was, nothing kept.
func cancel() -> void:
	if grab == null:
		return
	grab = null
	world.set_drawn({})
	_unlean()
	_clear_marks()
	say.call("put back where it was")


func _capital(words: String) -> String:
	return words.substr(0, 1).to_upper() + words.substr(1) if not words.is_empty() else words


func _tell(line: String) -> void:
	if line == _said:
		return
	_said = line
	say.call(line)


## The model's balance and its most loaded joint, in words: "stands, 2 studs
## inside the left edge" or "would tip over to the left"; "the Plate 1 x 2's
## 2 studs carry about 3x their working load". About, because a stud's
## clutch is not published (docs/MECHANISMS.md, What "accurate" can honestly
## mean): honest to a factor of two.
func _standing_words(weighed: Balance.Report, live: bool) -> String:
	var out: String
	if weighed.margin >= 0.0:
		out = "stands, %s studs inside the %s edge" % [Balance.studs(weighed.margin), weighed.edge]
	else:
		out = "%s over to the %s, %s studs past its edge" % ["would tip" if live else "tips",
			weighed.edge, Balance.studs(-weighed.margin)]
	for one: Balance.JointLoad in weighed.joints:
		if one.ratio <= 1.0:
			break
		var info: PartLibrary.PartInfo = library.parts.get(one.beyond_part)
		var name: String = Bodies._short(info.name) if info != null else one.beyond_part
		out += "; the %s's %d stud%s carry about %sx their working load" % [name, one.studs,
			"" if one.studs == 1 else "s", Balance.tidy(one.ratio)]
		break
	return out


## The polygon and the weight on the floor, the loaded joints tinted, and,
## while dragging, the model leaning over the edge it would tip over.
func _show(weighed: Balance.Report, live: bool) -> void:
	if _mark == null:
		_mark = BalanceMark.new()
		_mark.world = world
		add_child(_mark)
	var tints: Dictionary = {}
	for one: Balance.JointLoad in weighed.joints:
		if one.ratio < 0.5 or scenery.has(one.beyond):
			continue
		tints[one.beyond] = BalanceMark.CLOSE.lerp(BalanceMark.TIPS,
			clampf((one.ratio - 0.5) * 2.0, 0.0, 1.0))
	_mark.show_report(weighed, tints)
	if live and weighed.margin < 0.0 and weighed.edge_ends.size() == 2:
		_lean(weighed)
	else:
		_unlean()


func _lean(weighed: Balance.Report) -> void:
	var a: Vector2 = weighed.edge_ends[0]
	var b: Vector2 = weighed.edge_ends[1]
	var on: Vector2 = Geometry2D.get_closest_point_to_segment(
		Vector2(weighed.centre.x, weighed.centre.z), a, b)
	var outward := Vector3(weighed.centre.x - on.x, 0.0, weighed.centre.z - on.y)
	if outward.length() < 0.01:
		return
	var turn_about: Vector3 = Vector3.UP.cross(outward.normalized()).normalized()
	var edge := Vector3(on.x, weighed.floor_y, on.y)
	world.transform = Transform3D(Basis.IDENTITY, edge) \
		* Transform3D(Basis(turn_about, deg_to_rad(LEAN)), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -edge)
	_leaning = true


func _unlean() -> void:
	if _leaning:
		world.transform = Transform3D.IDENTITY
		_leaning = false


func _clear_marks() -> void:
	if _mark != null:
		_mark.clear()


## Whether the model is drawn leaning: for a probe.
func is_leaning() -> bool:
	return _leaning


func _exit_tree() -> void:
	_unlean()


# -- for a session ------------------------------------------------------------------


## A session's move_part (AppTools): the same reading, joint, stops, gears,
## settling and weighing as a person's drag, as one undo step. With only
## part= it changes nothing and says what would move.
func for_session(input: Dictionary) -> String:
	var asked: String = str(input.get("part", "")).strip_edges()
	var ids: Array = _named_parts(asked)
	if ids.is_empty():
		return ("No part or sub-assembly %s here. part= takes a part's number (look_at_model) or "
			+ "a sub-assembly's name.") % asked
	if _bodies == null or _bodies.revision != world.revision:
		_bodies = Bodies.read(world, library, builder.lattice, scenery, builder.locked)
	var held := Grab.new()
	held.world = world
	held.builder = builder
	held.library = library
	held.bodies = _bodies
	var selection: Dictionary = {}
	if ids.size() > 1:
		for key: int in ids:
			selection[key] = true
	var first: int = ids[0]
	var state: String = held.begin(first, world.get_brick(first).transform.origin, selection)
	if state == "rigid":
		return ("#%d is held rigidly to what stays (%s): nothing it is built on turns. %s") % [
			first, _bodies.summary(), held.why]
	if state != "moves":
		return held.why
	var lines := PackedStringArray()
	var kind: String = held.link.kind
	var how: String = "holds where it is put" if held.link.holds else "turns freely and swings down under its own weight"
	if held.link.detent > 0.0:
		how = "clicks every %s°" % Balance.tidy(held.link.detent)
	var slides: String = ""
	if held.can_slide():
		var span: Vector2 = held.slide_range()
		slides = "; slides %s studs back or %s on along its line" % [
			Balance.studs(-span.x / BrickLattice.STUD), Balance.studs(span.y / BrickLattice.STUD)]
	var at: Vector3 = held.pivot / BrickLattice.STUD
	lines.append("%s (%s at x=%s y=%s z=%s studs, %s%s); %d bod%s move together%s." % [
		_capital(held.said), kind, Balance.studs(at.x), Balance.studs(at.y), Balance.studs(at.z),
		how, slides, held.moving_bodies.size(), "y" if held.moving_bodies.size() == 1 else "ies",
		(", and %d part%s of the gear train it drives" % [held.coupled.size(),
			"" if held.coupled.size() == 1 else "s"]) if not held.coupled.is_empty() else ""])
	var judge := Balance.new()
	judge.library = library
	judge.lattice = builder.lattice
	judge.floor_ids = scenery
	var weighs: bool = judge.prepare(world.bricks())
	if not input.has("degrees") and not input.has("along"):
		if weighs:
			lines.append("As it stands: %s." % _standing_words(judge.weigh_pose({}), false))
		lines.append("Nothing was changed. degrees= turns it%s." % (", along= slides it"
			if held.can_slide() else ""))
		return "\n".join(lines)
	var asked_for: String = ""
	if input.has("along"):
		if not held.can_slide():
			return "%s\nIt does not slide: nothing it is on is longer than the hole it is in." % lines[0]
		held.mode = "slide"
		var wanted: float = float(input["along"]) * BrickLattice.STUD
		held.slide_to(wanted)
		asked_for = "%s studs" % Balance.studs(float(input["along"]))
	elif held.mode == "ball":
		var way: Array = input.get("axis", []) as Array
		if way.size() != 3:
			return "%s\nA ball turns every way: give axis= [x, y, z] with degrees=." % lines[0]
		var about := Vector3(float(way[0]), float(way[1]), float(way[2]))
		if about.length() < 0.001:
			return "axis= must not be [0, 0, 0]."
		held.ball_to(Basis(about.normalized(), deg_to_rad(float(input["degrees"]))))
		asked_for = "%s°" % Balance.tidy(float(input["degrees"]))
	else:
		held.turn_to(float(input["degrees"]))
		asked_for = "%s°" % Balance.tidy(float(input["degrees"]))
	var stopped: bool = held.stopped
	var swung: String = held.settle()
	var moved: int = held.commit(held.step_words())
	if moved == 0:
		lines.append("It did not move: %s" % ("something is in the way at once." if stopped
			else "it is already there."))
		return "\n".join(lines)
	lines.append("Moved %d part%s: now %s (asked %s)%s%s." % [moved, "" if moved == 1 else "s",
		held.position_words(), asked_for,
		"; it stopped where it meets the model" if stopped else "",
		"; then " + swung if not swung.is_empty() else ""])
	if weighs:
		var after: Balance.Report = judge.weigh_pose(held.placed)
		last_report = after
		lines.append("Now: %s." % _standing_words(after, false))
		var numbers: String = after.said(func(id: int) -> String:
			var brick: BrickWorld.Brick = world.get_brick(id)
			return "#%d %s" % [id, brick.part_id] if brick != null else "#%d" % id)
		if not numbers.is_empty():
			lines.append(numbers)
	lines.append("One step: undo takes it back.")
	edited.call()
	last_words = "\n".join(lines)
	return last_words


## The parts a session names: a part's number, or every part of a
## sub-assembly by its name or path.
func _named_parts(asked: String) -> Array:
	var text: String = asked.trim_prefix("#")
	if text.is_valid_int():
		return [int(text)] if world.get_brick(int(text)) != null and not scenery.has(int(text)) else []
	var lower: String = asked.to_lower()
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		var path: String = Assemblies.path_of(brick)
		if path.is_empty():
			continue
		if path.to_lower() == lower or Assemblies.label(path).to_lower() == lower \
				or path.to_lower().begins_with(lower + "/"):
			out.append(brick.id)
	if out.is_empty():
		for brick: BrickWorld.Brick in world.bricks():
			var path: String = Assemblies.path_of(brick)
			for segment: String in Assemblies.segments(path):
				if Assemblies.label(segment).to_lower() == lower:
					out.append(brick.id)
					break
	return out
