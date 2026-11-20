## Reading too long for one frame, spread over frames without being written
## as slices: the work runs on a thread of its own that takes turns with the
## main thread, never beside it.
##
## A reading such as the surface pass's (SurfacePass.find) walks the whole
## model through a dozen stages, each a loop that cannot give a frame back
## without every caller of it awaiting: on Orthanc it held one frame 11.6 s,
## and on 10179 56 s (finishpass, 2026-11-20). FramePace needs the work
## written as a coroutine; this needs only [method pause] called in its hot
## loops, which is nothing on any thread but a fiber's, so the same code
## gives the same answers called on the main thread as it always did.
##
## The main thread hands the work a turn and waits; the work runs until its
## slice is spent, at a pause, and hands the turn back; the main thread
## draws a frame and hands it another. The two never run at once, so what
## the work reads is never written while it reads it. It reads the part
## library as a reader on a worker does (PartLibrary.begin_reading): a part
## not loaded is read as having none, and [method run] loads what was
## missed and runs it again, as Assistant._laid_whole does.
##
## Where a thread cannot be had (a browser engine built without them) the
## work runs whole, on the main thread, as before.
##
##   var answer: Variant = await Fiber.run(func() -> Variant: return pass.find(), job)
class_name Fiber
extends RefCounted

## A turn's length: what the work does between two frames.
const SLICE_US := 25000

## The thread the running fiber's work is on, or 0: [method pause] is
## nothing on any other. Written only while the main thread waits.
static var _thread_id: int = 0
static var _running: Fiber = null

## The stretches of work between two pauses longer than [constant LONG_US],
## of every fiber since a probe last cleared it: [ms, the pause before, the
## pause after]. Where a turn ran long, it names the loop with no pause in it.
static var long_stretches: Array = []
const LONG_US := 40000

## The longest turn the work took, in microseconds, and how many it took.
var longest_us: int = 0
var turns: int = 0

var _work: Callable
var _go := Semaphore.new()
var _back := Semaphore.new()
var _started := Semaphore.new()
var _turn_began: int = 0
var _last_pause: int = 0
var _last_site: StringName = &"start"
var _done: bool = false
var _answer: Variant = null


## Hand the turn back if this slice is spent, when called on a fiber's
## thread; nothing anywhere else. Called in the hot loops of work a fiber
## may run.
static func pause(site: StringName = &"") -> void:
	if _thread_id == 0 or OS.get_thread_caller_id() != _thread_id:
		return
	_running._maybe_give_back(site)


## Whether this is called on a running fiber's thread.
static func here() -> bool:
	return _thread_id != 0 and OS.get_thread_caller_id() == _thread_id


## Whether work is running in a fiber now.
static func busy() -> bool:
	return _running != null


## [param work]'s answer, run in turns of [constant SLICE_US] with a frame
## between each; [param job], when given, is told each turn is done. Read
## through [param library], whose missed parts are loaded (by
## [param fetch], awaited with them, when given) and the work run again,
## three times at most. Awaited, on the main thread. Run whole when a fiber
## is already running or no thread can be had.
static func run(work: Callable, library: PartLibrary, fetch: Callable = Callable(),
		job: Working.Job = null) -> Variant:
	if _running != null or not OS.has_feature("threads") and OS.has_feature("web"):
		return work.call()
	var answer: Variant = null
	for _round: int in 3:
		library.unread_by_readers()
		var fiber := Fiber.new()
		fiber._work = work
		answer = await fiber._run_turns(library, job)
		var missed: PackedStringArray = library.unread_by_readers()
		if missed.is_empty():
			return answer
		var before: int = missed.size()
		if fetch.is_valid():
			await fetch.call(missed)
		var resident: int = 0
		for id: String in missed:
			if library.mesh_for(id) != null:
				resident += 1
		# None of them to be had: the main thread reads them empty too.
		if resident == 0 or before == 0:
			return answer
	return answer


func _run_turns(library: PartLibrary, job: Working.Job) -> Variant:
	var thread := Thread.new()
	library.begin_reading()
	_running = self
	if thread.start(_on_thread) != OK:
		_running = null
		library.end_reading()
		return _work.call()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	# A browser starts a thread's worker only when the page's own thread
	# lets go of the turn: it is waited for by frames, never blocked on,
	# before the first turn is handed over.
	while not _started.try_wait():
		await tree.process_frame
	while true:
		var began: int = Time.get_ticks_usec()
		_go.post()
		_back.wait()
		turns += 1
		longest_us = maxi(longest_us, Time.get_ticks_usec() - began)
		if _done:
			break
		if job != null:
			job.count(turns)
		IdleDraw.keep_awake()
		await tree.process_frame
	thread.wait_to_finish()
	_running = null
	library.end_reading()
	return _answer


func _on_thread() -> void:
	# Its turns never overlap the main thread's: what a node's methods ask
	# of the thread calling them, this one has.
	Thread.set_thread_safety_checks_enabled(false)
	_thread_id = OS.get_thread_caller_id()
	_started.post()
	_go.wait()
	_turn_began = Time.get_ticks_usec()
	_last_pause = _turn_began
	_answer = _work.call()
	_stretch(Time.get_ticks_usec(), &"end")
	_done = true
	_thread_id = 0
	_back.post()


func _maybe_give_back(site: StringName) -> void:
	var now: int = Time.get_ticks_usec()
	_stretch(now, site)
	if now - _turn_began < SLICE_US:
		return
	_back.post()
	_go.wait()
	_turn_began = Time.get_ticks_usec()
	_last_pause = _turn_began


func _stretch(now: int, site: StringName) -> void:
	if now - _last_pause > LONG_US:
		long_stretches.append([(now - _last_pause) / 1000.0, _last_site, site])
	_last_pause = now
	_last_site = site
