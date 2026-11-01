## How long the app's own work took, on a box that other work shares.
##
## Releases run their probes four at a time on a box that other projects
## and agents share, at a load of 15 to 45 on 12 cores (24 threads). A bar
## on the clock's time counted the box against the app there: three
## releases held on one day (2026-10-31) for a booklet's cover, a layout and
## a frame that were slow only by the box. So a probe judges the app's own
## time:
##
##   - the clock's time less what the main thread waited for a CPU it was
##     ready to run on (field 2 of /proc/self/schedstat, the run-queue wait;
##     0 where there is none), read at the start and at the end;
##   - against a bar three times as long when the last minute's load, at the
##     start or at the end, the larger, is past the box's physical cores
##     (slack): a busy box slows the work itself too, its caches and memory
##     shared, not only its turn at a CPU. Physical, not logical: two
##     threads on one core share it with no wait for either, and here (12
##     cores, 24 threads) the app's own time rose 1.5 to 2 times between a
##     load of 10 and 22 with the run-queue wait near 0 (2026-10-31);
##   - and says both, the app's own time and the wait, with the load and
##     the cores (Span.said), so a reader sees how much of it was the box.
##
## Nothing is loosened beyond that: a frame or an act slow of its own fails
## as it did. A time spent off the main thread (a worker's, a download's,
## the GPU's) is not the main thread's wait: a probe that times one says
## whether the load slows it before it gives it the slack.
class_name ProbeTime
extends RefCounted

## The box's physical cores, counted once as the class loads (a probe's
## worker may ask).
static var _cores: int = _physical_cores()


## How long the main thread has waited for a CPU it was ready to run on,
## in ms, since it began. From any thread: /proc/self is the main
## thread's.
static func waited_ms() -> float:
	var stat: FileAccess = FileAccess.open("/proc/self/schedstat", FileAccess.READ)
	if stat == null:
		return 0.0
	var fields: PackedStringArray = stat.get_line().split(" ", false)
	return fields[1].to_float() / 1e6 if fields.size() > 1 else 0.0


## The box's load over the last minute.
static func box_load() -> float:
	var file: FileAccess = FileAccess.open("/proc/loadavg", FileAccess.READ)
	return file.get_line().get_slice(" ", 0).to_float() if file != null else 0.0


## The box's physical cores: on Linux the distinct (physical id, core id)
## pairs of /proc/cpuinfo, else the logical processors.
static func cores() -> int:
	return _cores


static func _physical_cores() -> int:
	var file: FileAccess = FileAccess.open("/proc/cpuinfo", FileAccess.READ)
	var pairs: Dictionary = {}
	var socket: String = ""
	while file != null and not file.eof_reached():
		var line: String = file.get_line()
		var value: String = line.get_slice(":", 1).strip_edges()
		if line.begins_with("physical id"):
			socket = value
		elif line.begins_with("core id"):
			pairs[socket + "/" + value] = true
	return pairs.size() if not pairs.is_empty() else OS.get_processor_count()


## What a bar is multiplied by: 3 when the larger of [param load_then] and
## the load now is past the box's physical cores, else 1.
static func slack(load_then: float) -> float:
	return 3.0 if maxf(load_then, box_load()) > _cores else 1.0


## "load 21 of 12 cores".
static func load_said(busy: float) -> String:
	return "load %.0f of %d cores" % [busy, _cores]


## Of the entries of [param list] (Frames.gaps or Frames.work) that ended
## at or after [param from] usec, the frame an act began in too, the one
## with the most of the app's own time: [its own ms, its ms on the clock,
## the main thread's wait in it, its end in usec, what the label said]; all
## 0 when none did.
static func longest(list: Array, from: int = 0) -> Array:
	var most: Array = [0.0, 0.0, 0.0, 0, null]
	for entry: Array in list:
		if int(entry[0]) < from:
			continue
		var own: float = maxf(float(entry[1]) - float(entry[2]), 0.0)
		if own > float(most[0]):
			most = [own, float(entry[1]), float(entry[2]), int(entry[0]), entry[3]]
	return most


## Of [param spans], the one with the most of the app's own time.
static func slowest(spans: Array) -> Span:
	var most: Span = null
	for span: Span in spans:
		if most == null or span.own > most.own:
			most = span
	return most


## Of [param spans], the box's largest load at a start or an end: what
## their bar's slack is read from.
static func busiest(spans: Array) -> float:
	var most: float = 0.0
	for span: Span in spans:
		most = maxf(most, span.busy)
	return most


## One act, timed from when this is made to [method end].
class Span extends RefCounted:
	## The clock's time, the main thread's wait for a CPU in it and the rest,
	## the app's own, in ms; and the box's load, the larger at its start or
	## its end.
	var ms: float = 0.0
	var waited: float = 0.0
	var own: float = 0.0
	var busy: float = 0.0
	var _from_us: int = 0
	var _from_waited: float = 0.0

	func _init() -> void:
		busy = ProbeTime.box_load()
		_from_waited = ProbeTime.waited_ms()
		_from_us = Time.get_ticks_usec()

	## Ends it, and gives it back.
	func end() -> Span:
		var now: int = Time.get_ticks_usec()
		waited = maxf(ProbeTime.waited_ms() - _from_waited, 0.0)
		ms = (now - _from_us) / 1000.0
		own = maxf(ms - waited, 0.0)
		busy = maxf(busy, ProbeTime.box_load())
		return self

	## What its bar is multiplied by (ProbeTime.slack).
	func slack() -> float:
		return 3.0 if busy > ProbeTime.cores() else 1.0

	## "412 ms of its own (38 waiting for a CPU; load 21 of 12 cores)".
	func said() -> String:
		return "%.0f ms of its own (%.0f waiting for a CPU; %s)" % [own, waited,
			ProbeTime.load_said(busy)]


## Every frame from when it is added to the tree, each with the main
## thread's wait for a CPU in it. Added before the app's own nodes connect
## to process_frame, it is the first of what runs in a frame, so what they
## do when they wake is counted.
class Frames extends Node:
	## Each frame from one process_frame to the next, drawing included: [its
	## end in usec, ms, of them the main thread's wait for a CPU, what
	## [member label] said as it ended].
	var gaps: Array = []
	## Each frame's own work, drawing aside: from process_frame to the
	## drawing, or when it draws nothing, to the end of its processing
	## (OwnFrames): [its end in usec, ms, of them the wait, what [member
	## label] said as it ended].
	var work: Array = []
	## Said as each frame and each frame's work ends, kept with it.
	var label: Callable = Callable()
	## The box's load when it was added.
	var busy: float = 0.0
	## Whether the frame it is added in counts, from then on: an act pressed
	## just after is in it. Else the first frame kept is the next one.
	var from_now: bool = true
	var _began_us: int = 0
	var _began_waited: float = 0.0
	## Whether this frame's work has not been kept yet, and where its
	## processing ended: [usec, the wait, what label said], or [].
	var _working: bool = false
	var _processed_at: Array = []

	func _ready() -> void:
		# After every other node's _process.
		process_priority = 1000000
		busy = ProbeTime.box_load()
		if from_now:
			_began_us = Time.get_ticks_usec()
			_began_waited = ProbeTime.waited_ms()
			_working = true
		get_tree().process_frame.connect(_begin)
		RenderingServer.frame_pre_draw.connect(_drawing)

	func _exit_tree() -> void:
		get_tree().process_frame.disconnect(_begin)
		RenderingServer.frame_pre_draw.disconnect(_drawing)

	func _begin() -> void:
		var now: int = Time.get_ticks_usec()
		var waited: float = ProbeTime.waited_ms()
		# The last frame drew nothing: its work ended with its processing.
		if _working and not _processed_at.is_empty():
			work.append([_processed_at[0], (int(_processed_at[0]) - _began_us) / 1000.0,
				float(_processed_at[1]) - _began_waited, _processed_at[2]])
		if _began_us > 0:
			gaps.append([now, (now - _began_us) / 1000.0, waited - _began_waited,
				label.call() if label.is_valid() else null])
		_began_us = now
		_began_waited = waited
		_working = true
		_processed_at = []

	func _process(_delta: float) -> void:
		_processed.call_deferred()

	func _processed() -> void:
		if _working:
			_processed_at = [Time.get_ticks_usec(), ProbeTime.waited_ms(),
				label.call() if label.is_valid() else null]

	func _drawing() -> void:
		if not _working:
			return
		_working = false
		var now: int = Time.get_ticks_usec()
		work.append([now, (now - _began_us) / 1000.0, ProbeTime.waited_ms() - _began_waited,
			label.call() if label.is_valid() else null])

	## What a bar is multiplied by, from the load when it was added and now.
	func slack() -> float:
		return ProbeTime.slack(busy)
