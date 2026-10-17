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
## The room test's share of a frame, ms: past it a big section is moved on
## trust and checked when the pointer pauses or lets go (Grab.verify_step).
const FRAME_BUDGET_MS := 10.0
## More parts than this moving is a big section.
const BIG_SECTION := 40
## A pause this long, ms, is when a turn moved on trust is checked.
const PAUSE_MS := 120

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var camera: CadCamera
## The model's sub-assemblies: a copy posed is made its own first.
var assemblies: Assemblies
var scenery: Dictionary = {}
var say: Callable = func(_words: String) -> void: pass
## Called once the pose is kept: the model changed.
var edited: Callable = func() -> void: pass

var grab: Grab = null
## The end of a chain taken hold of (held still before the drag).
var chain: GrabChain = null
var report: Balance.Report = null
## What the last drag said when let go, and its report: for a probe.
var last_words: String = ""
var last_report: Balance.Report = null
## Frame costs of the last drag, ms: the worst and the mean of follow + draw
## + weigh, and how many frames.
var worst_ms: float = 0.0
var mean_ms: float = 0.0
var frames: int = 0
## The worst of each part of it: following the pointer (the room tests),
## and weighing.
var worst_follow_ms: float = 0.0
var worst_weigh_ms: float = 0.0
var worst_settle_ms: float = 0.0
## Of those: checking where it stops, and working out its cells.
var worst_verify_ms: float = 0.0
var worst_lay_ms: float = 0.0
## Bodies read once per revision, kept between drags.
var _bodies: Bodies = null
var _judge: Balance = null
var _judge_revision: int = -1
var _mark: BalanceMark = null
var _weighed_at: int = 0
var _said: String = ""
var _total_ms: float = 0.0
var _leaning: bool = false
var _moved_at: int = 0
## A big section let go, its cells worked out a share a frame, then kept.
var _laying: Grab = null
var _lay_keys: Array = []
var _laid: Dictionary = {}
var _lay_task: int = -1
## The frame that kept the last big section, ms.
var keep_ms: float = 0.0
## What that frame spent, ms: making copies its own, the commit, what an
## edit sets going (main's _on_model_edited).
var keep_took: Dictionary = {}
## A grab let go while its turn was still being checked: kept once it is.
var _settling: Grab = null


## A drag began on [param brick_id] at [param screen]. True when the drag
## is this tool's (it turns the part on its joint, or says why it cannot);
## false when the part should be carried as before.
func press(brick_id: int, screen: Vector2, selection: Dictionary = {}, chained: bool = false) -> bool:
	if world == null or camera == null:
		return false
	var origin: Vector3 = camera.ray_origin(screen)
	var direction: Vector3 = camera.ray_normal(screen)
	var hit: BrickLattice.Hit = builder.lattice.raycast(origin, direction)
	var at: Vector3 = origin + direction.normalized() * hit.distance if hit.is_valid() \
		else world.get_brick(brick_id).transform.origin
	# Held still before the drag: the end of a chain, every joint back to the
	# anchor following it.
	if chained and selection.size() <= 1:
		if not is_ready():
			if world.brick_count() >= READY_OFF_THREAD_FROM and not OS.has_feature("nothreads"):
				say.call("Reading how this model's parts are joined… a moment, then drag again.")
				return true
			_ready_now()
		var links := GrabChain.new()
		links.world = world
		links.builder = builder
		links.library = library
		links.bodies = _bodies
		if links.begin(brick_id, at) == "moves":
			chain = links
			grab = null
			frames = 0
			_said = ""
			_tell("%s — drag the end where it should go" % _capital(links.said))
			return true
	grab = Grab.new()
	grab.world = world
	grab.builder = builder
	grab.library = library
	if not is_ready():
		# A big model is read on a worker; a press before it is done waits
		# for it rather than hold the window for seconds.
		if world.brick_count() >= READY_OFF_THREAD_FROM and not OS.has_feature("nothreads"):
			grab = null
			say.call("Reading how this model's parts are joined… a moment, then drag again.")
			last_words = "reading"
			return true
		_ready_now()
	grab.bodies = _bodies
	grab.shared_mechanism = _mechanism
	var state: String = grab.begin(brick_id, at, selection)
	# A section this big is tested within a frame's share, and checked fully
	# on pauses and at the release; a smaller one is bisected at once.
	grab.budget_ms = FRAME_BUDGET_MS if grab.moving.size() > BIG_SECTION else INF
	if state == "rigid":
		grab = null
		return false
	if state != "moves":
		say.call(grab.why)
		last_words = grab.why
		return true
	worst_ms = 0.0
	worst_settle_ms = 0.0
	worst_verify_ms = 0.0
	worst_lay_ms = 0.0
	worst_follow_ms = 0.0
	worst_weigh_ms = 0.0
	_total_ms = 0.0
	frames = 0
	_said = ""
	grab.follow(origin, direction, screen, camera)
	_tell("%s — drag to move it" % _capital(grab.said))
	return true


func is_grabbing() -> bool:
	return grab != null or chain != null


## The pointer moved to [param screen] while the button is down.
func motion(screen: Vector2) -> void:
	if chain != null:
		_chain_motion(screen)
		return
	if grab == null or grab.state != "moves":
		return
	var started: int = Time.get_ticks_usec()
	grab.follow(camera.ray_origin(screen), camera.ray_normal(screen), screen, camera)
	worst_follow_ms = maxf(worst_follow_ms, float(Time.get_ticks_usec() - started) / 1000.0)
	world.set_drawn(grab.placed)
	var now: int = Time.get_ticks_msec()
	if _judge != null and now - _weighed_at >= WEIGH_EVERY_MS:
		_weighed_at = now
		var weighing: int = Time.get_ticks_usec()
		report = _judge.weigh_pose(grab.placed)
		_show(report, true)
		worst_weigh_ms = maxf(worst_weigh_ms, float(Time.get_ticks_usec() - weighing) / 1000.0)
	_moved_at = Time.get_ticks_msec()
	var line: String = "%s, %s" % [_capital(grab.said), grab.position_words()]
	if grab.unchecked:
		line += " — too big to test every frame: checked when you pause"
	elif grab.loop_short:
		line += " — stopped: its loop closes no further that way"
	elif grab.stopped:
		line += " — stopped: it meets the model"
	if report != null and not report.empty:
		line += " · " + _standing_words(report, true)
	_tell(line)
	var spent: float = float(Time.get_ticks_usec() - started) / 1000.0
	frames += 1
	_total_ms += spent
	worst_ms = maxf(worst_ms, spent)
	mean_ms = _total_ms / float(frames)


## The end of a chain drawn to the pointer: the point under it in the plane
## through where the end is, facing the eye.
func _chain_motion(screen: Vector2) -> void:
	var started: int = Time.get_ticks_usec()
	var origin: Vector3 = camera.ray_origin(screen)
	var direction: Vector3 = camera.ray_normal(screen).normalized()
	var short: float = chain.reach_ray(origin, direction)
	world.set_drawn(chain.placed)
	_tell("%s%s" % [_capital(chain.said), "" if short < 2.0
		else " — as far as its joints reach, %s studs short" % Balance.studs(short / BrickLattice.STUD)])
	var spent: float = float(Time.get_ticks_usec() - started) / 1000.0
	frames += 1
	worst_ms = maxf(worst_ms, spent)


## The button came up: settle what swings, keep the pose as one step, and
## say what the structure does now.
func release() -> String:
	if chain != null:
		var held: GrabChain = chain
		chain = null
		world.set_drawn({})
		var depth: int = builder.history_depth()
		var words: String = held.finish()
		builder.fold_since(depth)
		edited.call()
		last_words = words
		_said = ""
		say.call(words)
		return words
	if grab == null:
		return ""
	var held: Grab = grab
	grab = null
	if held.state != "moves":
		return held.why
	if held.unchecked:
		# Checked a frame at a time from here (_process), then kept.
		_settling = held
		say.call("%s — checking where it stops…" % _capital(held.said))
		return "checking"
	return _keep(held)


## Keep a grab let go: settle what swings, one step to undo, and say how the
## model stands.
func _keep(held: Grab, cells: Dictionary = {}) -> String:
	if not held.settled:
		held.settled = true
		held.swung = held.settle()
		if held.unchecked:
			_settling = held
			return "checking"
	# A big section's cells in the lattice worked out a share a frame before
	# it is kept: 131 turned parts at once held the release's frame 170 ms.
	if cells.is_empty() and held.moving.size() > BIG_SECTION and _laying == null:
		# The copies made their own in this frame, the cells in the next ones,
		# the move kept in the last: each well inside a frame.
		held.own_depth = builder.history_depth()
		held.own_words = _own_copies(held)
		held.own_done = true
		_laying = held
		_lay_keys = held.changed().keys()
		_laid = {}
		return "keeping"
	var swung: String = held.swung
	world.set_drawn({})
	_unlean()
	var depth: int = held.own_depth if held.own_done else builder.history_depth()
	var clock: int = Time.get_ticks_usec()
	var own: String = held.own_words if held.own_done else _own_copies(held)
	keep_took["copies"] = (Time.get_ticks_usec() - clock) / 1000
	clock = Time.get_ticks_usec()
	var moved: int = held.commit(held.step_words(), cells)
	keep_took["commit"] = (Time.get_ticks_usec() - clock) / 1000
	# Making a copy its own and the pose: one step to undo.
	builder.fold_since(depth)
	var words: String
	if moved == 0:
		words = "%s: not moved" % _capital(held.said)
		_clear_marks()
	else:
		words = "%s, %s" % [_capital(held.said), held.position_words()]
		if not swung.is_empty():
			words += "; " + swung
		if not own.is_empty():
			words += "; " + own
		if _judge != null:
			# Weighed as it now stands: the graph read when it was grabbed
			# (a turn on a joint moves no stud joint), the parts where the
			# pose left them.
			last_report = _judge.weigh_pose(held.placed)
			words += ". " + _standing_words(last_report, false)
			_show(last_report, false)
		clock = Time.get_ticks_usec()
		edited.call()
		keep_took["edited"] = (Time.get_ticks_usec() - clock) / 1000
	last_words = words
	_said = ""
	say.call(words)
	return words


## Before a pose is kept: each sub-assembly round what moves that has other
## copies and does not move whole is made a copy of its own (Assemblies.
## make_unique), innermost first, so the others stay as they were. Posing one
## of two alike minifigures' arm moved both arms: every copy follows an edit
## of one (Assemblies.after_edit). Returns the words, "" for none.
func _own_copies(held: Grab) -> String:
	if assemblies == null:
		return ""
	var moved: Dictionary = held.changed()
	var paths: Dictionary = {}
	for key: int in moved:
		var path: String = Assemblies.path_of(world.get_brick(key))
		while not path.is_empty():
			paths[path] = true
			path = Assemblies.parent_of(path)
	var order: Array = paths.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		return Assemblies.segments(a).size() > Assemblies.segments(b).size())
	var said := PackedStringArray()
	for path: String in order:
		var others: int = assemblies.copies_of(path).size()
		if others == 0:
			continue
		var whole: bool = true
		for brick: BrickWorld.Brick in assemblies.bricks_under(path):
			if not moved.has(brick.id):
				whole = false
				break
		if whole:
			continue
		assemblies.make_unique(path)
		said.append("this copy of %s is now its own; the other %s stay%s as %s" % [
			Assemblies.label(path), "one" if others == 1 else str(others),
			"s" if others == 1 else "", "it was" if others == 1 else "they were"])
	return "; ".join(said)


## Escape, or the drag lost: everything back where it was, nothing kept.
func cancel() -> void:
	_settling = null
	_laying = null
	if _lay_task >= 0:
		WorkerTasks.collect(_lay_task)
		_lay_task = -1
	if chain != null:
		chain = null
		world.set_drawn({})
		say.call("put back where it was")
		return
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
	if not is_ready():
		_ready_now()
	var held := Grab.new()
	held.world = world
	held.builder = builder
	held.library = library
	held.bodies = _bodies
	held.shared_mechanism = _mechanism
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
	# The graph read for this revision, as a drag weighs with.
	var judge: Balance = _judge
	var weighs: bool = judge != null
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
		held.use_slide()
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
	var depth: int = builder.history_depth()
	var own: String = _own_copies(held)
	var moved: int = held.commit(held.step_words())
	builder.fold_since(depth)
	if moved == 0:
		lines.append("It did not move: %s" % ("something is in the way at once." if stopped
			else "it is already there."))
		return "\n".join(lines)
	lines.append("Moved %d part%s: now %s (asked %s)%s%s%s." % [moved, "" if moved == 1 else "s",
		held.position_words(), asked_for,
		"; it stopped where it meets the model" if stopped else "",
		"; then " + swung if not swung.is_empty() else "",
		"; " + own if not own.is_empty() else ""])
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


# -- for a browser test ---------------------------------------------------------------

var _told_page: String = ""
var _told_page_at: int = 0


func _process(_delta: float) -> void:
	_ready_ahead()
	# A big section moved on trust: checked while the pointer rests, and,
	# let go, before it is kept.
	if grab != null and grab.unchecked and Time.get_ticks_msec() - _moved_at >= PAUSE_MS:
		grab.verify_step()
		world.set_drawn(grab.placed)
	if _laying != null:
		var began: int = Time.get_ticks_usec()
		# The cells on a worker (Builder.boxes_for is safe off the main
		# thread): one big part's turned cover alone was 187 ms of a frame.
		if _lay_task < 0 and not _lay_keys.is_empty() and not OS.has_feature("nothreads"):
			var work: Array = []
			for key: int in _lay_keys:
				var brick: BrickWorld.Brick = world.get_brick(key)
				if brick != null:
					work.append([key, library.mesh_for(brick.part_id), _laying.placed[key]])
			_lay_keys.clear()
			var out: Dictionary = _laid
			var cells: Builder = builder
			_lay_task = WorkerTasks.add(func() -> void:
				for item: Array in work:
					out[item[0]] = cells.boxes_for(item[1], item[2]), false, "lay a section's cells")
		if _lay_task >= 0:
			if WorkerThreadPool.is_task_completed(_lay_task):
				WorkerTasks.collect(_lay_task)
				_lay_task = -1
		while not _lay_keys.is_empty() and float(Time.get_ticks_usec() - began) / 1000.0 < FRAME_BUDGET_MS:
			var key: int = _lay_keys.pop_back()
			var brick: BrickWorld.Brick = world.get_brick(key)
			if brick != null:
				_laid[key] = builder.boxes_for(library.mesh_for(brick.part_id), _laying.placed[key])
		worst_lay_ms = maxf(worst_lay_ms, float(Time.get_ticks_usec() - began) / 1000.0)
		if _lay_keys.is_empty() and _lay_task < 0:
			var held: Grab = _laying
			_laying = null
			var kept_at: int = Time.get_ticks_usec()
			_keep(held, _laid)
			keep_ms = float(Time.get_ticks_usec() - kept_at) / 1000.0
		worst_settle_ms = maxf(worst_settle_ms, float(Time.get_ticks_usec() - began) / 1000.0)
	if _settling != null:
		var started: int = Time.get_ticks_usec()
		var done: bool = _settling.verify_step()
		worst_verify_ms = maxf(worst_verify_ms, float(Time.get_ticks_usec() - started) / 1000.0)
		worst_settle_ms = maxf(worst_settle_ms, float(Time.get_ticks_usec() - started) / 1000.0)
		world.set_drawn(_settling.placed)
		if done:
			var held: Grab = _settling
			_settling = null
			_keep(held)
	_tell_page()


## Whether a grab let go is still being checked before it is kept.
func is_settling() -> bool:
	return _settling != null or _laying != null


# -- ready ahead of the press ------------------------------------------------------

## From this many parts the reading goes to a worker, as the balance's does.
const READY_OFF_THREAD_FROM := 300
## How long the model must stand still before it is read, ms: not between
## the parts of one paste.
const READY_AFTER_MS := 250

var _mechanism: Mechanism = null
var _readying: int = -1
var _ready_for: int = -1
var _still: BrickWorld = null
var _still_lattice: BrickLattice = null
var _ready_out: Array = []
var _seen_revision: int = -1
var _changed_at: int = 0
## How long the last reading took, ms, and whether it ran on a worker.
var ready_ms: int = 0
var ready_off_thread: bool = false
## Each step of it, ms: bodies, balance, gears.
var ready_took: Dictionary = {}


## Whether what a grab needs is read for the model as it stands: the bodies,
## the graph Balance weighs, and the gear trains.
func is_ready() -> bool:
	return _bodies != null and _bodies.revision == world.revision \
		and _judge_revision == world.revision


## Read what a grab needs once the model has stood still a moment, so a
## press finds it ready: Bodies.read and Balance.prepare cost 0.4 s and more
## at 1,300 parts, which at the press held the drag's first frame for 5 s.
func _ready_ahead() -> void:
	if world == null or builder == null:
		return
	var now: int = Time.get_ticks_msec()
	if world.revision != _seen_revision:
		_seen_revision = world.revision
		_changed_at = now
	if _readying >= 0:
		if not WorkerThreadPool.is_task_completed(_readying):
			return
		WorkerTasks.collect(_readying)
		library.end_reading(_readying)
		_readying = -1
		if _ready_for == world.revision and grab == null:
			_adopt(_ready_out, _ready_for)
		_still.free()
		_still = null
		_still_lattice = null
		return
	if grab != null or is_ready() or now - _changed_at < READY_AFTER_MS:
		return
	if world.brick_count() < READY_OFF_THREAD_FROM or OS.has_feature("nothreads"):
		_ready_now()
		return
	var started: int = Time.get_ticks_msec()
	_ready_for = world.revision
	_still = world.copy_for_reading()
	_still_lattice = builder.lattice.copy_for_reading()
	var floor_ids: Dictionary = scenery.duplicate()
	var held: Dictionary = builder.locked.duplicate()
	var out: Array = [null, null, null, 0, {}]
	_ready_out = out
	var still: BrickWorld = _still
	var cells: BrickLattice = _still_lattice
	var parts: PartLibrary = library
	library.begin_reading()
	_readying = WorkerTasks.add(func() -> void:
		var read: Array = GrabDrag._read_all(still, parts, cells, floor_ids, held)
		out[0] = read[0]
		out[1] = read[1]
		out[2] = read[2]
		out[4] = read[3]
		out[3] = Time.get_ticks_msec() - started, false, "read the model's joints")
	library.reading_in(_readying)
	ready_off_thread = true


## Read now, on this thread: a small model, a browser without threads, or a
## press that came before the reading was done.
func _ready_now() -> void:
	var started: int = Time.get_ticks_msec()
	var read: Array = GrabDrag._read_all(world, library, builder.lattice, scenery, builder.locked)
	_adopt([read[0], read[1], read[2], Time.get_ticks_msec() - started, read[3]], world.revision)
	ready_off_thread = false


static func _read_all(from: BrickWorld, parts: PartLibrary, cells: BrickLattice,
		floor_ids: Dictionary, held: Dictionary) -> Array:
	var clock: int = Time.get_ticks_msec()
	var bodies: Bodies = Bodies.read(from, parts, cells, floor_ids, held)
	var took: Dictionary = {"bodies": Time.get_ticks_msec() - clock}
	clock = Time.get_ticks_msec()
	var judge := Balance.new()
	judge.library = parts
	judge.lattice = cells
	judge.floor_ids = floor_ids
	if not judge.prepare(from.bricks()):
		judge = null
	took["balance"] = Time.get_ticks_msec() - clock
	clock = Time.get_ticks_msec()
	# The gear trains, read once for every grab of a gear (Grab._gears): the
	# anchors are the ground.
	var mechanism: Mechanism = null
	var list: Array = []
	var ground: Array = []
	var gears: int = 0
	for brick: BrickWorld.Brick in from.bricks():
		if floor_ids.has(brick.id):
			continue
		var mesh: Lbm.PartMesh = parts.mesh_for(brick.part_id)
		if mesh == null:
			continue
		if not Mechanism.spec_of(brick.part_id).is_empty():
			gears += 1
		list.append({"key": brick.id, "part": brick.part_id, "at": brick.transform, "mesh": mesh})
		if bodies.body_of.has(brick.id) and bodies.anchors.has(int(bodies.body_of[brick.id])):
			ground.append(brick.id)
	if gears >= 2:
		mechanism = Mechanism.build(list, ground)
	took["gears"] = Time.get_ticks_msec() - clock
	return [bodies, judge, mechanism, took]


func _adopt(read: Array, revision: int) -> void:
	_bodies = read[0]
	_judge = read[1]
	_mechanism = read[2]
	ready_ms = int(read[3]) if read.size() > 3 else 0
	ready_took = read[4] if read.size() > 4 else {}
	if _bodies != null:
		_bodies.world = world
		_bodies.lattice = builder.lattice
		_bodies.revision = revision
	if _judge != null:
		_judge.lattice = builder.lattice
	_judge_revision = revision


## What a drag is doing, for a browser test: window.brickworksGrab, with a
## place on the page over a part of each of the first few bodies that turn
## on a joint, so a mouse can take hold of it as a person's would. Web
## builds only.
func _tell_page() -> void:
	if not OS.has_feature("web") or world == null or camera == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _told_page_at < 500:
		return
	_told_page_at = now
	var ratio: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
	var per_css: float = float(ratio) if ratio != null and float(ratio) > 0.0 else 1.0
	var to_window: Transform2D = get_viewport().get_final_transform()
	var handles: Array = []
	if grab == null and is_ready():
		for body: Variant in _bodies.parent_link:
			if handles.size() >= 4:
				break
			var spot: Variant = _handle(int(body), _bodies.parent_link[body])
			if spot != null:
				var at: Vector2 = to_window * (spot["screen"] as Vector2) / per_css
				spot.erase("screen")
				spot["x"] = roundi(at.x)
				spot["y"] = roundi(at.y)
				handles.append(spot)
	var state: Dictionary = {"grabbing": grab != null, "handles": handles,
		"said": last_words, "frames": frames, "worst_ms": snappedf(worst_ms, 0.01),
		"mean_ms": snappedf(mean_ms, 0.01), "revision": world.revision, "ready": is_ready(),
		"ready_ms": ready_ms, "bodies": _bodies.summary() if _bodies != null else ""}
	if grab != null:
		state["what"] = grab.said
		state["angle"] = snappedf(grab.angle, 0.1)
		state["stopped"] = grab.stopped
	var said: String = JSON.stringify(state)
	if said == _told_page:
		return
	_told_page = said
	JavaScriptBridge.eval("window.brickworksGrab = %s" % said, true)


## A point on the screen over a part of [param body], the one furthest from
## its joint's line that the pointer lands on: {screen, part, kind, id}.
func _handle(body: int, link: Bodies.Link) -> Variant:
	var best: Variant = null
	var furthest: float = -1.0
	for key: int in _bodies.members.get(body, PackedInt64Array()):
		var brick: BrickWorld.Brick = world.get_brick(key)
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		if info == null:
			continue
		var centre: Vector3 = brick.transform * info.bounds.get_center()
		var off: Vector3 = centre - link.point
		if link.axis != Vector3.ZERO:
			off -= link.axis * off.dot(link.axis)
		if off.length() <= furthest:
			continue
		# Its middle, then towards its corners: a turret under an arm shows
		# only its edge.
		for corner: int in 9:
			var spot: Vector3 = brick.transform * (info.bounds.get_center() if corner == 8
				else info.bounds.get_center().lerp(info.bounds.get_endpoint(corner), 0.7))
			if camera.is_position_behind(spot):
				continue
			var screen: Vector2 = camera.unproject_position(spot)
			var hit: BrickLattice.Hit = builder.lattice.raycast(camera.ray_origin(screen),
				camera.ray_normal(screen))
			if hit.is_valid() and hit.brick_id == key:
				furthest = off.length()
				best = {"screen": screen, "part": brick.part_id, "kind": link.kind, "id": key}
				break
	return best
