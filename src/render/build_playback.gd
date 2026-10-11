## Watching a model go up instead of finding it there.
##
## A design takes minutes. For all of them the panel shows a spinner and
## some progress lines, and then the whole thing appears at once — the
## one moment worth seeing, over before it registers, and no sense of
## how the thing is put together.
##
## So it assembles. The order is not the order the model emitted its
## bricks in, which is whatever order it thought of them; it is the
## order recovered from the finished geometry by [Instructions] — the
## same order the printable booklet uses, bottom up, each brick resting
## on something already there. That is the difference between a model
## appearing in pieces and a model being built.
##
## Pacing is the whole problem. Four hundred bricks one at a time is
## four hundred frames of nothing happening, and six bricks one at a
## time is over before the eye finds it. So the total time is roughly
## fixed and the step rate falls out of it, with floors and ceilings so
## neither extreme is silly.
##
## And it must never cost the page its frames. The owner asked the web
## app for a Falcon Heavy, 4,242 parts, and it "damn near froze my
## computer". Measured on that model, on the desktop: planning the booklet's
## order took 15.5 s in one frame, at every submit and every edit; each step
## then walked every brick and rebuilt the batches it touched; and each
## rebuild asked whether the model stands, 4.4 s a time, about once a frame.
## The page in a browser was frozen for minutes. Now:
##
## - only what is new is assembled — what was already standing stays, so an
##   edit that recolours one brick plays nothing and add_rooms plays the
##   rooms ([method play]'s keep);
## - past [constant PLANNED_UP_TO] new bricks the order is course by course,
##   one sort, rather than the booklet's plan, whose cost grows faster than
##   the model;
## - a step costs a count per batch ([method BrickWorld.reveal_through]), not
##   a walk of the model;
## - and the whole of it takes at most [constant LONGEST_MS], however many
##   steps, several to a frame if need be.
class_name BuildPlayback
extends Node

## Roughly how long the whole assembly should take, in milliseconds.
## Long enough to follow, short enough that nobody reaches for a
## keyboard to skip it.
const TARGET_MS := 3600.0
## No step may be quicker than this or it reads as a flicker, nor slower
## than this or a small model feels like it is stalling.
const FASTEST_MS := 45.0
const SLOWEST_MS := 320.0
## And no assembly longer than this. The Falcon's 4,242 parts are about 530
## steps, which at the fastest step was 24 s of a model going up while the
## assistant had long since moved on.
const LONGEST_MS := 8000.0
## New bricks up to this many go up in the booklet's order. Beyond it, the
## plan's cost is the problem: it grows with the square of the bricks (730
## bricks, 0.3 s; 4,242, 15.5 s), and a frame is not the place to spend it.
## Two hundred is about 25 ms.
const PLANNED_UP_TO := 200
## Bricks a step adds, course by course: what the booklet adds at most.
const PER_STEP := 8

var world: BrickWorld
var library: PartLibrary

## The bricks to come, in the order they go up, and where each step ends
## in it: step n shows order[0 .. step_ends[n]).
var _order := PackedInt64Array()
var _step_ends := PackedInt64Array()
var _at: int = 0
var _per_step: float = 100.0
var _clock: float = 0.0
var _running: bool = false

signal finished


func _ready() -> void:
	set_process(false)


func is_playing() -> bool:
	return _running


## Assemble what is in the world, leaving [param keep] on screen
## throughout — the baseplate, anything placed by hand, and whatever was
## already standing before the change being shown.
func play(keep: Dictionary) -> bool:
	stop()
	if world == null or library == null:
		return false
	if not world.reveal_ended.is_connected(_on_reveal_ended):
		world.reveal_ended.connect(_on_reveal_ended)
	_lay_out(keep)
	if _step_ends.size() < 2:
		# One step is not an assembly, it is the model. Playing it would
		# be a flicker and then the same picture.
		return false

	world.begin_reveal(_order)
	if not world.is_revealing():
		return false
	_at = 0
	_clock = 0.0
	_running = true
	_per_step = clampf(TARGET_MS / float(_step_ends.size()), FASTEST_MS, SLOWEST_MS)
	_per_step = minf(_per_step, LONGEST_MS / float(_step_ends.size()))
	set_process(true)
	# The first step immediately, so the baseplate does not sit empty
	# for a beat before anything happens.
	_advance_to(1)
	return true


## Put the whole model back at once. Called when somebody starts doing
## something else — they have stopped watching, and a model half drawn
## because of an animation is a model that looks broken.
func stop() -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	world.end_reveal()
	finished.emit()


func _process(delta: float) -> void:
	if not _running:
		return
	_clock += delta * 1000.0
	# However many steps are due, shown in one go: a slow frame costs the
	# animation its place in time, not its place in the model, and not
	# another slow frame either.
	var due: int = mini(_step_ends.size(), 1 + int(_clock / _per_step))
	if due > _at:
		_advance_to(due)


func _advance_to(steps: int) -> void:
	_at = steps
	# Showing the last brick ends the reveal, which ends this.
	world.reveal_through(int(_step_ends[steps - 1]) - 1)


## The model changed under the animation, or it played out.
func _on_reveal_ended() -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	finished.emit()


## Work out [member _order] and [member _step_ends] for everything not in
## [param keep].
func _lay_out(keep: Dictionary) -> void:
	_order = PackedInt64Array()
	_step_ends = PackedInt64Array()
	var coming: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if not keep.has(brick.id):
			coming.append(brick)
	if coming.size() < 2:
		return
	if coming.size() <= PLANNED_UP_TO:
		var seen: Dictionary = {}
		for step: Instructions.Step in Instructions.plan(world, library, keep):
			for brick_id: int in step.brick_ids:
				if seen.has(brick_id) or world.get_brick(brick_id) == null:
					continue
				seen[brick_id] = true
				_order.append(brick_id)
			if _order.size() > 0 and (_step_ends.is_empty()
					or _step_ends[_step_ends.size() - 1] < _order.size()):
				_step_ends.append(_order.size())
		return
	_courses(coming)


## Course by course: lowest first, and across each course in rows. One
## sort of packed keys, so it costs the same few milliseconds however the
## model is shaped.
func _courses(coming: Array) -> void:
	var keys := PackedInt64Array()
	var wide: bool = coming.size() >= 1 << 15
	for index: int in coming.size():
		var brick: BrickWorld.Brick = coming[index]
		var low: Vector3 = brick.transform.origin
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part != null:
			low = (brick.transform * part.bounds).position
		var y: int = clampi(int(floor(low.y / BrickLattice.CELL)) + 32768, 0, 65535)
		if wide:
			keys.append((y << 32) | index)
			continue
		var x: int = clampi(int(floor(low.x / BrickLattice.CELL)) + 32768, 0, 65535)
		var z: int = clampi(int(floor(low.z / BrickLattice.CELL)) + 32768, 0, 65535)
		keys.append((y << 47) | (x << 31) | (z << 15) | index)
	keys.sort()
	var mask: int = (1 << 32) - 1 if wide else (1 << 15) - 1
	for key: int in keys:
		_order.append((coming[key & mask] as BrickWorld.Brick).id)
		if _order.size() % PER_STEP == 0:
			_step_ends.append(_order.size())
	if _step_ends.is_empty() or _step_ends[_step_ends.size() - 1] < _order.size():
		_step_ends.append(_order.size())
