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
## A model standing on the baseplate's studs does not fall: they hold it, and
## on a baseplate the plate is the floor. Off by default; a probe may set it.
var topple_on_baseplate: bool = false
## The room test's share of a frame, ms: past it a big section is moved on
## trust and checked when the pointer pauses or lets go (Grab.verify_step).
const FRAME_BUDGET_MS := 10.0
## A loop's room test may run this long in a frame, ms.
const LOOP_BUDGET_MS := 24.0
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
## The last motion's cost, ms: for a probe sampling frame by frame.
var last_motion_ms: float = 0.0
## The worst of each part of it: following the pointer (the room tests),
## and weighing.
var worst_follow_ms: float = 0.0
## What the worst following frame spent its time on.
var worst_follow_said: String = ""
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
## A grab let go swinging on a free joint (Grab.swing): drawn a frame at a
## time and kept when it comes to rest, or when a press catches it.
var _swinging: Grab = null
var _swing_began: int = 0
## The swing's own share of a frame, ms, at most: past it the swing goes
## slower than the clock rather than hold the frame.
const SWING_BUDGET_MS := 8.0
## A frame's simulated time at most, s: a slow frame does not leap.
const SWING_MOST_FRAME_S := 0.05
## The last swing's frames: how many, the worst and mean of its own work
## (stepping, room tests, drawing), ms; and how long it took on the clock.
var swing_frames: int = 0
var swing_worst_ms: float = 0.0
var swing_mean_ms: float = 0.0
var swing_clock_s: float = 0.0
var _swing_total_ms: float = 0.0
## The last swing, kept for a probe.
var last_swing: Swing = null


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
	# on pauses and at the release; a smaller one is bisected at once. A loop
	# is tested whole each frame but bisected where it stops a round at a
	# time, on pauses: each round solves the loop and works out its turned
	# parts' covers afresh (a steering's two wheels, 11 ms each).
	grab.budget_ms = FRAME_BUDGET_MS if grab.moving.size() > BIG_SECTION \
		else (LOOP_BUDGET_MS if grab.linkage != null else INF)
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
	var following: float = float(Time.get_ticks_usec() - started) / 1000.0
	if following > worst_follow_ms:
		worst_follow_said = "solving %.1f ms, %d room tests %.1f ms" % [grab.frame_solve_ms,
			grab.frame_tests, grab.frame_test_ms]
	worst_follow_ms = maxf(worst_follow_ms, following)
	world.set_drawn(grab.placed)
	var now: int = Time.get_ticks_msec()
	if _judge != null and now - _weighed_at >= WEIGH_EVERY_MS:
		_weighed_at = now
		var weighing: int = Time.get_ticks_usec()
		report = _judge.weigh_pose(grab.placed)
		_show(report, true)
		worst_weigh_ms = maxf(worst_weigh_ms, float(Time.get_ticks_usec() - weighing) / 1000.0)
	_moved_at = Time.get_ticks_msec()
	# The line is said ten times a second, not every frame: each new text is
	# laid out afresh and sets a timer of its own to clear it. Said at once
	# when it stops or goes again.
	if now - _told_at < TELL_EVERY_MS and grab.stopped == _told_stopped:
		_count_frame(started)
		return
	_told_at = now
	_told_stopped = grab.stopped
	var line: String = "%s, %s" % [_capital(grab.said), grab.position_words()]
	if grab.unchecked and grab.linkage != null:
		line += " — stopped: it meets the model (found to a tenth of a degree when you pause)"
	elif grab.unchecked:
		line += " — too big to test every frame: checked when you pause"
	elif grab.loop_short:
		line += " — stopped: its loop closes no further that way"
	elif grab.stopped:
		line += " — stopped: it meets the model"
	if report != null and not report.empty:
		line += " · " + _standing_words(report, true)
	_tell(line)
	_count_frame(started)


## The status line during a drag, said at most this often, ms.
const TELL_EVERY_MS := 100
var _told_at: int = 0
var _told_stopped: bool = false


## A drag frame's cost, from [param started] (usec), into the counts.
func _count_frame(started: int) -> void:
	var spent: float = float(Time.get_ticks_usec() - started) / 1000.0
	frames += 1
	_total_ms += spent
	worst_ms = maxf(worst_ms, spent)
	mean_ms = _total_ms / float(frames)
	last_motion_ms = spent


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
		# Checked from here, then kept: on a worker where there are threads,
		# else a frame at a time (_process).
		_settling = held
		say.call("%s — checking where it stops…" % _capital(held.said))
		if not OS.has_feature("nothreads"):
			_verify_off_thread(held)
		return "checking"
	return _keep(held)


## A big section let go: where it stops checked, and its swing under its own
## weight found, on a worker, the window drawing it where it was let go
## meanwhile. A frame at a time, one part's turned cover was one test and
## the worst frame 160 ms. The lattice is only read; nothing edits the model
## while a grab is being kept (is_settling).
func _verify_off_thread(held: Grab) -> void:
	world.set_drawn(held.placed.duplicate())
	held.budget_ms = INF
	_verify_task = WorkerTasks.add(func() -> void:
		while not held.verify_step():
			pass
		if not held.settled:
			held.settled = true
			held.swung = held.settle()
			while not held.verify_step():
				pass, false, "check a section let go")


var _verify_task: int = -1


## Whether [param held], let go, falls before anything in it swings: the
## model is past its edge as it was let go, and the grabbed joint holds. It
## begins to fall at once; what hangs on a free joint inside it is held
## while it falls, a fifth of a second or so, and swings as it lands (_land):
## the two together are not worked out. A grabbed joint that is free swings
## first, as before: it drops at once, and may bring the weight back.
func _falls_first(held: Grab) -> bool:
	if _judge == null or held.swing == null or held.swing_has_grabbed():
		return false
	return _fall_of(held.placed, _judge.weigh_pose(held.placed)).has("turn")


## Keep a grab let go: settle what swings, one step to undo, and say how the
## model stands.
func _keep(held: Grab, cells: Dictionary = {}) -> String:
	if not held.settled:
		# A free joint swings, frame by frame (_swing_frame), and is kept when
		# it comes to rest; the rest settle at once.
		if _swinging == null and held.swing_begin():
			if _falls_first(held):
				held.swing = null
				held.settled = true
				held.swung = ""
			else:
				_swinging = held
				_swing_began = Time.get_ticks_msec()
				swing_frames = 0
				swing_worst_ms = 0.0
				swing_mean_ms = 0.0
				_swing_total_ms = 0.0
				say.call("%s — swinging…" % _capital(held.said))
				last_words = "swinging"
				return "swinging"
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
			var fell: Dictionary = _fall_of(held.placed, last_report)
			if fell.has("turn"):
				# Shown falling as a body falls about its edge (Topple.timed),
				# then kept with the pose as one step.
				var from: Dictionary = _standing_now()
				var timing: Dictionary = Topple.timed(fell["steps"], Swing.lump(world, library, from.keys()))
				fall_seconds = float(timing["seconds"])
				fall_lowest = INF
				_falling = {"start": Time.get_ticks_msec(), "steps": fell["steps"],
					"turn": fell["turn"], "from": from, "depth": depth, "timing": timing,
					"words": "%s; then it %s, falling for %s s" % [words, fell["words"],
						Balance.tidy(fall_seconds)],
					"step": "then it %s" % fell["words"]}
				last_words = _falling["words"]
				say.call("%s…" % _capital(str(fell["words"])))
				return last_words
			# Held by the baseplate's studs it would tip, and does not.
			words += ". " + _capital(_standing_words(last_report, fell.has("why_not")))
			if fell.has("why_not"):
				words += ". " + str(fell["why_not"])
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


## A model let go past its edge falls over (Topple): {turn, steps, words},
## or {why_not} when it would but does not, or {} when it stands. Not a
## model standing on the baseplate's studs, which hold it (unless
## [member topple_on_baseplate]); not one Balance reads as past its edge
## where it stood too, whose support it cannot see.
func _fall_of(placed: Dictionary, weighed: Balance.Report) -> Dictionary:
	if weighed == null or weighed.empty or weighed.margin >= 0.0:
		return {}
	if _bodies != null and not _bodies._standing.is_empty() and not topple_on_baseplate:
		return {"why_not": ("It does not fall: it stands on the baseplate's studs, which hold it "
			+ "(on a baseplate the plate is the floor).")}
	if _judge != null and _judge.weigh_pose({}).margin < 0.0:
		return {}
	var corners: PackedVector3Array = Topple.corners_of(world, library, placed, scenery)
	var fell: Dictionary = Topple.fall(corners, weighed.centre, weighed.floor_y)
	if (fell["falls"] as Array).is_empty():
		return {}
	return fell


## Every part of the model where it stands now, not the baseplate.
func _standing_now() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if not scenery.has(brick.id):
			out[brick.id] = brick.transform
	return out


## A fall shown: [member _falling] {start, steps, turn, from, depth, timing,
## words}.
var _falling: Dictionary = {}
## The last fall's time, simulated (Topple.timed), and on the clock, s.
var fall_seconds: float = 0.0
var fall_clock_s: float = 0.0
## The lowest any corner of the model was drawn in the last fall, for a
## probe: below the floor it would have gone through it.
var fall_lowest: float = INF


## Whether a model let go is being shown falling over.
func is_falling() -> bool:
	return not _falling.is_empty()


## One frame of a fall: drawn where the body falling about its edge has got
## to by the clock (Topple.timed), and at the end kept with the pose as one
## step; then what hangs on a free joint swings in its new lie, starting
## with the speed the fall gave it (_land).
func _fall_frame() -> void:
	var seconds: float = float(Time.get_ticks_msec() - int(_falling["start"])) / 1000.0
	var from: Dictionary = _falling["from"]
	var timing: Dictionary = _falling["timing"]
	if seconds < float(timing["seconds"]):
		var turn: Transform3D = Topple.turn_at(_falling["steps"], timing, seconds)
		var drawn: Dictionary = {}
		for key: Variant in from:
			drawn[key] = turn * (from[key] as Transform3D)
		world.set_drawn(drawn)
		if not _falling.has("corners"):
			_falling["corners"] = Topple.corners_of(world, library, from, scenery)
		for corner: Vector3 in _falling["corners"]:
			fall_lowest = minf(fall_lowest, (turn * corner).y)
		return
	var fell: Dictionary = _falling
	_falling = {}
	fall_clock_s = seconds
	world.set_drawn({})
	_lay_fallen(fell["from"], fell["turn"], int(fell["depth"]), str(fell["step"]))
	var words: String = _capital(str(fell["words"]))
	if _land(timing, int(fell["depth"]), words):
		return
	last_words = words
	say.call(words)
	edited.call()


## A model that has fallen and landed: what hangs on a free joint in it
## swings in its new lie (Grab.land_begin), drawn as a swing is and kept in
## the same step. False when nothing swings, or the model is too big to read
## again in a frame.
func _land(timing: Dictionary, depth: int, words: String) -> bool:
	if world.brick_count() >= READY_OFF_THREAD_FROM:
		return false
	_ready_now()
	var held := Grab.new()
	held.world = world
	held.builder = builder
	held.library = library
	held.bodies = _bodies
	var line: Vector3 = timing["line"]
	if not held.land_begin(line * float(timing["speed"]), timing["point"]):
		return false
	held.landing_depth = depth
	held.landing_said = words
	_swinging = held
	_swing_began = Time.get_ticks_msec()
	swing_frames = 0
	swing_worst_ms = 0.0
	swing_mean_ms = 0.0
	_swing_total_ms = 0.0
	say.call("%s; as it lands, %s swings…" % [words, held.said])
	last_words = "swinging"
	return true


## A swing after a landing, over: kept in the drag's step, and said.
func _keep_landing(held: Grab, why: String) -> void:
	world.set_drawn({})
	held.commit("swung %s as it landed" % held.said)
	builder.fold_since(held.landing_depth)
	var swung: String = why if not why.is_empty() else held.swing.words()
	var words: String = held.landing_said
	if not swung.is_empty():
		words += "; as it landed, %s %s, and came to rest hanging within its friction of straight down" % [
			held.said, swung]
	last_words = words
	_said = ""
	say.call(words)
	edited.call()


## Every part turned by [param turn] from [param from], kept as one step with
## what came before it since [param depth]. Returns the words.
func _lay_fallen(from: Dictionary, turn: Transform3D, depth: int, words: String) -> String:
	var steps: Array = []
	for key: Variant in from:
		var brick: BrickWorld.Brick = world.get_brick(int(key))
		if brick == null:
			continue
		var to: Transform3D = turn * (from[key] as Transform3D)
		steps.append({"undo": "move", "brick": int(key), "transform": brick.transform})
		world.move_brick(int(key), to)
		builder.lattice.release(int(key))
		builder.lattice.occupy_boxes(int(key), builder.boxes_for(library.mesh_for(brick.part_id), to))
	builder.record(steps, words)
	builder.fold_since(depth)
	_clear_marks()
	return _capital(words)


## Escape, or the drag lost: everything back where it was, nothing kept.
func cancel() -> void:
	if _swinging != null:
		_swinging = null
		world.set_drawn({})
		_unlean()
		_clear_marks()
		say.call("put back where it was")
		return
	if _verify_task >= 0:
		WorkerTasks.collect(_verify_task)
		_verify_task = -1
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
	_make_mark()
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


func _make_mark() -> void:
	if _mark == null:
		_mark = BalanceMark.new()
		_mark.world = world
		add_child(_mark)


## Whether the balance mark has been drawn once ahead of the first drag.
var _mark_warmed: bool = false


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
	if input.has("to"):
		return _chain_for_session(int(ids[0]), input["to"])
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
	# A free joint swings to rest, run here at once (Swing.run), as a drag's
	# is drawn; the rest settle.
	var swung: String
	if held.swing_begin() and _falls_first(held):
		swung = ""
	elif held.swing != null:
		held.swing.run()
		held.swing_pose()
		last_swing = held.swing
		swung = held.swing_words()
	else:
		swung = held.settle()
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
		var fell: Dictionary = _fall_of(held.placed, after)
		if fell.has("turn"):
			var from: Dictionary = _standing_now()
			var timing: Dictionary = Topple.timed(fell["steps"], Swing.lump(world, library, from.keys()))
			fall_seconds = float(timing["seconds"])
			_lay_fallen(from, fell["turn"], depth, "then it %s" % fell["words"])
			lines.append("Then it %s: its centre of mass was %s studs past its %s edge, and it turned "
				% [fell["words"], Balance.studs(-after.margin), after.edge]
				+ "about that edge until the floor stopped it, falling for %s s." % Balance.tidy(fall_seconds))
			if world.brick_count() < READY_OFF_THREAD_FROM:
				_ready_now()
				var landed := Grab.new()
				landed.world = world
				landed.builder = builder
				landed.library = library
				landed.bodies = _bodies
				if landed.land_begin((timing["line"] as Vector3) * float(timing["speed"]), timing["point"]):
					landed.swing.run()
					landed.swing_pose()
					last_swing = landed.swing
					landed.commit("swung %s as it landed" % landed.said)
					builder.fold_since(depth)
					lines.append("As it landed, %s %s, and came to rest hanging within its friction of "
						% [landed.said, landed.swing.words()] + "straight down.")
		else:
			lines.append("Now: %s.%s" % [_standing_words(after, fell.has("why_not")),
				" " + str(fell["why_not"]) if fell.has("why_not") else ""])
		var numbers: String = after.said(func(id: int) -> String:
			var brick: BrickWorld.Brick = world.get_brick(id)
			return "#%d %s" % [id, brick.part_id] if brick != null else "#%d" % id)
		if not numbers.is_empty():
			lines.append(numbers)
	lines.append("One step: undo takes it back.")
	edited.call()
	last_words = "\n".join(lines)
	return last_words


## A session's move_part with to=: the part taken as the end of its chain
## of joints back to the anchor (GrabChain) and drawn to the point, every
## joint within the range it has alone, as a person's hold-then-drag does;
## tested, eased back to the furthest that has room, one step to undo.
func _chain_for_session(end: int, to: Variant) -> String:
	var point: Array = to as Array if to is Array else []
	if point.size() != 3:
		return "to= is a point, [x, y, z] in studs, as move_part says where a joint is."
	var target := Vector3(float(point[0]), float(point[1]), float(point[2])) * BrickLattice.STUD
	var brick: BrickWorld.Brick = world.get_brick(end)
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
	var held_at: Vector3 = brick.transform * (info.bounds.get_center() if info != null else Vector3.ZERO)
	var links := GrabChain.new()
	links.world = world
	links.builder = builder
	links.library = library
	links.bodies = _bodies
	if links.begin(end, held_at) != "moves":
		return "#%d has no chain of turning joints back to what stays: %s." % [end, links.why]
	var off: float = links.reach(target)
	var depth: int = builder.history_depth()
	var words: String = links.finish()
	builder.fold_since(depth)
	var lines := PackedStringArray()
	lines.append("%s; its middle is %s studs from the point%s." % [_capital(words),
		Balance.studs(links.end_point().distance_to(target) / BrickLattice.STUD),
		" (as near as its joints reach)" if off >= 2.0 else ""])
	if builder.history_depth() > depth and _judge != null:
		var after: Balance.Report = _judge.weigh_pose(links.placed)
		last_report = after
		lines.append("Now: %s." % _standing_words(after, false))
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


func _process(delta: float) -> void:
	_ready_ahead()
	if _swinging != null:
		_swing_frame(delta)
	# The balance mark drawn once, unseen, while nothing is held, so its
	# material is built before the first drag needs it (BalanceMark.warm).
	if not _mark_warmed and grab == null and chain == null and camera != null and is_ready():
		_mark_warmed = true
		_make_mark()
		_mark.warm(camera)
	if not _falling.is_empty():
		_fall_frame()
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
	if _settling != null and _verify_task >= 0:
		var waiting: int = Time.get_ticks_usec()
		if WorkerThreadPool.is_task_completed(_verify_task):
			WorkerTasks.collect(_verify_task)
			_verify_task = -1
			var checked: Grab = _settling
			_settling = null
			world.set_drawn(checked.placed)
			_keep(checked)
		worst_settle_ms = maxf(worst_settle_ms, float(Time.get_ticks_usec() - waiting) / 1000.0)
	elif _settling != null:
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
	return _settling != null or _laying != null or not _falling.is_empty() or _swinging != null


## Whether a section let go is swinging.
func is_swinging() -> bool:
	return _swinging != null


## One frame of a swing: the frame's time stepped (Swing.advance, within
## its budget), drawn, and kept once it rests.
func _swing_frame(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	var held: Grab = _swinging
	held.swing.advance(clampf(delta, 0.0, SWING_MOST_FRAME_S), SWING_BUDGET_MS)
	held.swing_pose()
	world.set_drawn(held.placed)
	var spent: float = float(Time.get_ticks_usec() - started) / 1000.0
	swing_frames += 1
	_swing_total_ms += spent
	swing_worst_ms = maxf(swing_worst_ms, spent)
	swing_mean_ms = _swing_total_ms / float(swing_frames)
	if held.swing.at_rest:
		_end_swing("")


## The swing over: kept where it is, as one step with the drag, and said.
## [param why] is said instead of the swing's own words (a press caught it).
func _end_swing(why: String) -> void:
	var held: Grab = _swinging
	_swinging = null
	swing_clock_s = float(Time.get_ticks_msec() - _swing_began) / 1000.0
	last_swing = held.swing
	held.settled = true
	held.swing_pose()
	if held.landing:
		_keep_landing(held, why)
		return
	held.swung = why if not why.is_empty() else held.swing_words()
	_keep(held)


## A press while a section swings catches it where it is, as a hand would:
## kept there, as one step with the drag.
func catch() -> void:
	if _swinging == null:
		return
	_end_swing("caught by a press %s s into its swing" % Balance.tidy(_swinging.swing.time))


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
	# Pinions in racks, read here too, not on the press.
	bodies.racks()
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


## What a drag is doing, for a browser test: window.brickworksGrab. Its
## handles, a place on the page over a part of each of the first few bodies
## that turn on a joint (so a mouse can take hold of it as a person's
## would), only when the page asks (window.brickworksGrabAsk), and found
## again only when the model or the view has changed: found twice a second
## for every model, raycasting each body's parts, they cost a 4,000-part
## model's frames 180 to 460 ms in a browser. Web builds only.
func _tell_page() -> void:
	if not OS.has_feature("web") or world == null or camera == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _told_page_at < 500:
		return
	_told_page_at = now
	var handles: Array = []
	if grab == null and is_ready() and bool(JavaScriptBridge.eval("!!window.brickworksGrabAsk", true)):
		var seen: Array = [world.revision, camera.global_transform, get_viewport().get_visible_rect().size,
			get_viewport().get_final_transform()]
		if seen != _handles_for:
			_handles_for = seen
			_handles = _find_handles()
		handles = _handles
	var state: Dictionary = {"grabbing": grab != null, "handles": handles,
		"said": last_words, "frames": frames, "worst_ms": snappedf(worst_ms, 0.01),
		"mean_ms": snappedf(mean_ms, 0.01), "revision": world.revision, "ready": is_ready(),
		"ready_ms": ready_ms, "bodies": _bodies.summary() if _bodies != null else ""}
	if grab != null:
		state["what"] = grab.said
		state["angle"] = snappedf(grab.angle, 0.1)
		state["stopped"] = grab.stopped
	state["swinging"] = _swinging != null
	state["swing_frames"] = swing_frames
	state["swing_mean_ms"] = snappedf(swing_mean_ms, 0.01)
	state["swing_worst_ms"] = snappedf(swing_worst_ms, 0.01)
	var said: String = JSON.stringify(state)
	if said == _told_page:
		return
	_told_page = said
	JavaScriptBridge.eval("window.brickworksGrab = %s" % said, true)


## The handles found last, and for what: [revision, eye, view size, its
## place in the window].
var _handles: Array = []
var _handles_for: Array = []
## At most this many of a body's parts, furthest from its joint first, are
## raycast for a handle.
const HANDLE_PARTS := 4


## A place on the page over a part of each of the first eight bodies that
## turn on a joint and show: [{x, y, part, kind, id}].
func _find_handles() -> Array:
	var ratio: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
	var per_css: float = float(ratio) if ratio != null and float(ratio) > 0.0 else 1.0
	var to_window: Transform2D = get_viewport().get_final_transform()
	var out: Array = []
	for body: Variant in _bodies.parent_link:
		if out.size() >= 8:
			break
		var spot: Variant = _handle(int(body), _bodies.parent_link[body])
		if spot != null:
			var at: Vector2 = to_window * (spot["screen"] as Vector2) / per_css
			spot.erase("screen")
			spot["x"] = roundi(at.x)
			spot["y"] = roundi(at.y)
			out.append(spot)
	return out


## A point on the screen over a part of [param body], of the
## [constant HANDLE_PARTS] furthest from its joint's line the first the
## pointer lands on: {screen, part, kind, id}.
func _handle(body: int, link: Bodies.Link) -> Variant:
	# The furthest few by their middles alone, before any ray is cast.
	var order: Array = []   ## [distance off the line, brick id]
	for key: int in _bodies.members.get(body, PackedInt64Array()):
		var brick: BrickWorld.Brick = world.get_brick(key)
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		if info == null:
			continue
		var off: Vector3 = brick.transform * info.bounds.get_center() - link.point
		if link.axis != Vector3.ZERO:
			off -= link.axis * off.dot(link.axis)
		order.append([off.length(), key])
	order.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	for entry: Array in order.slice(0, HANDLE_PARTS):
		var key: int = int(entry[1])
		var brick: BrickWorld.Brick = world.get_brick(key)
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
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
				return {"screen": screen, "part": brick.part_id, "kind": link.kind, "id": key}
	return null
