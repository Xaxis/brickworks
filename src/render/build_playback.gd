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

var world: BrickWorld
var library: PartLibrary

var _steps: Array[Instructions.Step] = []
var _showing: Dictionary = {}
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
## throughout — the baseplate, and anything placed by hand, which was
## already there and did not just get built.
func play(keep: Dictionary) -> bool:
	if world == null or library == null:
		return false
	_steps = Instructions.plan(world, library, keep)
	if _steps.size() < 2:
		# One step is not an assembly, it is the model. Playing it would
		# be a flicker and then the same picture.
		return false

	_showing = keep.duplicate()
	_at = 0
	_clock = 0.0
	_running = true
	_per_step = clampf(TARGET_MS / float(_steps.size()), FASTEST_MS, SLOWEST_MS)
	world.show_only(_showing)
	set_process(true)
	# The first step immediately, so the baseplate does not sit empty
	# for a beat before anything happens.
	_advance()
	return true


## Put the whole model back at once. Called when somebody starts doing
## something else — they have stopped watching, and a model half drawn
## because of an animation is a model that looks broken.
func stop() -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	world.show_only({})
	finished.emit()


func _process(delta: float) -> void:
	if not _running:
		return
	_clock += delta * 1000.0
	# A loop rather than one step per tick: a slow frame should cost the
	# animation its place in time, not its place in the model.
	while _clock >= _per_step and _running:
		_clock -= _per_step
		_advance()


func _advance() -> void:
	if _at >= _steps.size():
		stop()
		return
	for brick_id: int in _steps[_at].brick_ids:
		_showing[brick_id] = true
	_at += 1
	world.show_only(_showing)
