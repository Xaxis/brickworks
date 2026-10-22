## What the app is busy with, along the foot of the window: what it is
## doing in words, a bar that fills as it goes (or a block that runs along
## it when the work cannot be counted), and Cancel where stopping makes
## sense. Gone when the work is done.
##
## Asked for by the owner (2026-10-12): pressing Timeline on a big model
## showed nothing for seconds while the page sat frozen, "so the studio
## doesn't appear and functionally act frozen". One pattern for every slow
## thing, in the status bar where every other message is (StatusBar), so
## it never covers the model.
##
## The work reports to a Job; the bar shows the newest job going:
##
##   var job := Working.begin("Laying out 9,429 parts in steps…", 9429, true)
##   await job.shown()          # drawn before the slow part starts
##   for ...:
##       job.count(done)
##       if job.cancelled: break
##       if pace.due(): await pace.next()
##   job.end()
##
## A Job works without the bar too (a probe, the command line), so the
## work never asks whether anyone is watching.
##
## Drawn sparingly. Every frame drawn draws the model too, and a browser
## drawing in software takes a large part of a second over Orthanc: a bar
## redrawn every slice would make the work it reports on several times
## slower. So what it shows is brought up to date at most every UPDATE_MS,
## and on the web not again until the card has drawn the last change of it
## (GpuFence): on a graphics card that is at once, and in software over
## Orthanc several seconds. Redrawn every quarter second regardless, the
## frames queued behind each other — Orthanc's timeline took 77 s instead
## of 8, and the booklet's first picture waited 17 s for the frames before.
class_name Working
extends HBoxContainer

const UPDATE_MS := 250
const BAR_WIDTH := 150.0
## The block that runs along an uncountable bar, as a share of it.
const RUNNER := 0.28

## The one on screen, in the status bar. Null where there is no shell.
static var shown_in: Working = null
## Every job going, oldest first. The newest is the one shown.
static var _jobs: Array = []


## One piece of work, from its start to its end.
class Job extends RefCounted:
	## What is being done, as the person reads it: "Laying out 9,429
	## parts in steps…". The count is put after it.
	var words: String = ""
	var done: int = 0
	## 0 when it cannot be counted.
	var total: int = 0
	var can_cancel: bool = false
	## Set by Cancel; the work looks at it between slices.
	var cancelled: bool = false
	var ended: bool = false
	var began_ms: int = 0
	## Which job this is, counting from the first: Working.attend asks
	## whether a command began one of its own.
	var number: int = 0
	## Pressed Cancel.
	signal cancel_wanted

	func say(text: String) -> void:
		words = text

	## How far along: [param of] changes the total when given.
	func count(at: int, of: int = -1) -> void:
		done = at
		if of >= 0:
			total = of

	## Wait until the bar saying so has been drawn, so the slow part of the
	## work starts after the person has seen that it heard them.
	##
	## Not just the next process_frame: a press is handled before its
	## frame's processing, so the process_frame after it is in the same
	## frame, still to be drawn, and the work started there was done before
	## the bar was ever on screen. Up to three frames where nothing is drawn
	## at all (headless, or a window nobody can see).
	func shown() -> void:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		for _n: int in 3:
			await tree.process_frame
			if Engine.get_frames_drawn() > _drawn_from:
				return

	var _drawn_from: int = 0

	## Whether this slice of the work is spent (FramePace): the work then
	## awaits [method next], which gives the frame back.
	func due() -> bool:
		if _pace == null:
			_pace = FramePace.new()
		return _pace.due()

	func next() -> void:
		if _pace == null:
			_pace = FramePace.new()
		await _pace.next()

	## Slices of at least [param least_us] from now on (FramePace).
	func slices_of(least_us: int) -> void:
		_pace = FramePace.new(least_us)

	var _pace: FramePace = null

	func cancel() -> void:
		if not can_cancel or ended:
			return
		cancelled = true
		cancel_wanted.emit()

	func end() -> void:
		if ended:
			return
		ended = true
		Working._jobs.erase(self)
		Working._tell_page({"what": words, "ended": true,
			"ms": Time.get_ticks_msec() - began_ms, "cancelled": cancelled})
		if Working.shown_in != null:
			Working.shown_in._refresh(true)

	## Counted in hundredths and said as a share, "… 40%": a picture being
	## rendered has no pieces worth counting, only how far along it is.
	var percent: bool = false

	## The words with the count: "… 3,200 of 9,429".
	func line() -> String:
		if total > 0 and percent:
			return "%s %d%%" % [words, roundi(100.0 * done / total)]
		if total > 0:
			return "%s %s of %s" % [words, Working.comma(done), Working.comma(total)]
		return words


## Begin a piece of work, shown from the next frame drawn.
static func begin(words: String, total: int = 0, can_cancel: bool = false) -> Job:
	var job := Job.new()
	job.words = words
	job.total = total
	job.can_cancel = can_cancel
	job.began_ms = Time.get_ticks_msec()
	job._drawn_from = Engine.get_frames_drawn()
	_begun += 1
	job.number = _begun
	_jobs.append(job)
	if shown_in != null:
		shown_in._refresh(true)
		shown_in._watch_drawn(job)
	return job


## The job being shown, or null.
static func current() -> Job:
	return _jobs[-1] if not _jobs.is_empty() else null


static func is_busy() -> bool:
	return not _jobs.is_empty()


## -- Every command, attended ---------------------------------------------
##
## The owner (2026-10-13): "a standard 'progress indicator or working
## indicator' for actions taken in the app … when I clicked 'Save and then
## new' it seemingly froze the app … for probably all actions
## comprehensively." So every command goes through [method attend], from a
## menu, the toolbar, a key or a dialog's button, and none of them has to
## ask for the bar.
##
## A command that holds the frame cannot draw anything while it does: the
## bar has to be on screen before it starts. So each command's cost is
## remembered, by how big the model was (the same Save is nothing on a car
## and seconds on Orthanc), and one known to be slow is said first —
## "Saving…" drawn, then the command run the frame after. One not known is
## run at once and timed, and is said first from then on. A command that
## goes on after it returns (a coroutine) is timed to its end, and one that
## has not said what it is doing gets its own words on the bar until then.
##
## Fast commands never flash a bar: one is said first only when what it
## cost the last time and what it costs on average are both over
## [constant SAY_FIRST_MS]: a dialog that is slow to build only the first
## time it opens is not said first again.

## What a command must cost to be said before it runs.
const SAY_FIRST_MS := 150.0
## How long a command that goes on after returning may run before it is
## said: two frames, so one that only waits a frame never shows the bar.
const GOES_ON_FRAMES := 2
const COSTS_PATH := "user://command_costs.json"

## "name@size" -> [average ms, last ms]. Kept between visits.
static var costs: Dictionary = {}
static var _depth: int = 0
static var _costs_read: bool = false
static var _begun: int = 0
static var _frame_end: _FrameEnd = null


## Run command [param name] now, or said first when it is known to be slow.
## [param doing] is what the bar says: "Saving…". [param in_press] for a
## command that must run inside the press itself (a browser opens a file
## dialog or goes full screen only then), which is never put off a frame;
## [param slow] when the caller already knows it will be, the first time.
##
## Its costs are kept by [param size], how much it has to do: the model's
## parts, or the selection's for a command that works on the selection.
static func attend(name: String, doing: String, run: Callable, in_press: bool = false,
		slow: bool = false, size: int = 0) -> void:
	# Inside another command: that one is being timed and said.
	if _depth > 0:
		await run.call()
		return
	var parts: int = size
	var said: Job = null
	if not in_press and (slow or expected_ms(name, parts) >= SAY_FIRST_MS):
		said = begin(doing)
		await said.shown()
	var begun_before: int = _begun
	var from: int = Time.get_ticks_usec()
	# Only what it does before its first await is inside it: a command
	# pressed while this one waits on a frame is a command of its own.
	var going := _Going.new()
	_depth += 1
	going.go(run)
	_depth -= 1
	# Still going after it returned, and saying nothing: said, until it ends.
	if not going.finished and said == null:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		for _n: int in GOES_ON_FRAMES:
			await tree.process_frame
			if going.finished:
				break
		# Unless it began a job of its own: that says what it does.
		if not going.finished and not _has_job_since(begun_before):
			said = begin(doing)
	if not going.finished:
		await going.ended
	# What it held: to its end, and the rest of the frame it ended in,
	# whatever it set going.
	if _frame_end != null and is_instance_valid(_frame_end):
		await _frame_end.ended
	_remember(name, parts, (Time.get_ticks_usec() - from) / 1000.0)
	if said != null:
		said.end()


## A command run to its end, however many frames that takes. [method go]
## is called without await, so it hands back at the command's first await
## and goes on with it; [member finished] says whether it has ended. Godot 4
## waits on a coroutine only with await: taking its result without await,
## to wait on its state object as Godot 3 did, is a script error in a debug
## build, which stops the caller there.
class _Going extends RefCounted:
	signal ended
	var finished: bool = false

	func go(run: Callable) -> void:
		await run.call()
		finished = true
		ended.emit()


## Whether a job begun after the [param count]th is still going.
static func _has_job_since(count: int) -> bool:
	for job: Job in _jobs:
		if job.number > count:
			return true
	return false


## What [param name] is expected to cost on a model of [param parts] parts:
## the least of its average and its last there, or where it has never run
## at this size, at the biggest size below it where it has. 0 when unknown.
static func expected_ms(name: String, parts: int) -> float:
	_read_costs()
	for size: int in range(_size_class(parts), -1, -1):
		var known: Variant = costs.get("%s@%d" % [name, size])
		if known is Array and (known as Array).size() == 2:
			return minf(float(known[0]), float(known[1]))
	return 0.0


## Sizes go up by fours: 0, 1-3, 4-15 … 4,096-16,383 parts.
static func _size_class(parts: int) -> int:
	return floori(log(float(maxi(parts, 0)) + 1.0) / log(4.0))


static func _remember(name: String, parts: int, ms: float) -> void:
	_read_costs()
	var key: String = "%s@%d" % [name, _size_class(parts)]
	var was: Variant = costs.get(key)
	var average: float = ms if not (was is Array) else (float(was[0]) + ms) / 2.0
	var before: bool = was is Array and minf(float(was[0]), float(was[1])) >= SAY_FIRST_MS
	costs[key] = [snappedf(average, 0.1), snappedf(ms, 0.1)]
	# Kept for the next visit only when it changes what is said first.
	if before != (minf(average, ms) >= SAY_FIRST_MS) and not _probing():
		var file: FileAccess = FileAccess.open(COSTS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(costs))
			file.close()


static func _read_costs() -> void:
	if _costs_read:
		return
	_costs_read = true
	# A probe starts from nothing, whatever ran before it in its folder.
	if _probing() or not FileAccess.file_exists(COSTS_PATH):
		return
	var read: Variant = JSON.parse_string(FileAccess.get_file_as_string(COSTS_PATH))
	if read is Dictionary:
		costs = read


static func _probing() -> bool:
	return OS.get_cmdline_args().has("--script")


## The end of each frame's work: after every node's _process and whatever
## it deferred, drawn or not (OwnFrames). A command is timed to here.
class _FrameEnd extends Node:
	signal ended

	func _ready() -> void:
		process_priority = 1000000
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		_end.call_deferred()

	func _end() -> void:
		ended.emit()


## The line and the count, for the page (brickworksState.working).
static func page_state() -> Dictionary:
	var job: Job = current()
	if job == null:
		return {}
	return {"words": job.words, "done": job.done, "total": job.total,
		"cancel": job.can_cancel, "ms": Time.get_ticks_msec() - job.began_ms}


static func comma(value: int) -> String:
	var text: String = str(absi(value))
	var out: String = ""
	for n: int in text.length():
		if n > 0 and (text.length() - n) % 3 == 0:
			out += ","
		out += text[n]
	return ("-" if value < 0 else "") + out


## When each job was first drawn and when it ended, in the page's own
## clock: tools/web/progress_check.mjs reads how long after a press the
## bar came up, against the press's own time.
static func _tell_page(event: Dictionary) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(("(window.brickworksWork = window.brickworksWork || [])"
		+ ".push(Object.assign(%s, {at: performance.now()}))") % JSON.stringify(event), true)


var _words: Label
var _bar: _Bar
var _cancel: Button
var _updated_at: int = 0
## The frame count when the bar last changed, until a fence is put in
## behind its drawing; then the fence, until the card has passed it.
var _changed_frames: int = -1
var _fence: int = 0


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	_bar = _Bar.new()
	_bar.custom_minimum_size = Vector2(BAR_WIDTH, 0)
	_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_bar)
	_words = Label.new()
	_words.add_theme_font_size_override("font_size", 12)
	_words.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.clip_text = true
	_words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_words)
	_cancel = Button.new()
	_cancel.text = "Cancel"
	_cancel.tooltip_text = "Stop this and leave the model as it was"
	_cancel.focus_mode = Control.FOCUS_NONE
	_cancel.add_theme_font_size_override("font_size", 11)
	for state: String in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(1, 1, 1, {"normal": 0.08, "hover": 0.16, "pressed": 0.24}[state])
		face.border_color = Color(1, 1, 1, 0.14)
		face.set_border_width_all(1)
		face.set_corner_radius_all(4)
		face.content_margin_left = 8
		face.content_margin_right = 8
		face.content_margin_top = 0
		face.content_margin_bottom = 0
		_cancel.add_theme_stylebox_override(state, face)
	_cancel.pressed.connect(func() -> void:
		var job: Job = Working.current()
		if job != null:
			job.cancel())
	add_child(_cancel)
	_frame_end = _FrameEnd.new()
	add_child(_frame_end)
	shown_in = self
	_refresh(true)


func _exit_tree() -> void:
	if shown_in == self:
		shown_in = null


func _process(_delta: float) -> void:
	# The frame the bar last changed in has been drawn: a fence behind it.
	if _changed_frames >= 0 and Engine.get_frames_drawn() > _changed_frames:
		_changed_frames = -1
		_fence = GpuFence.put()
	if visible:
		_refresh(false)


## Bring the words and the bar up to date: at once when a job begins or
## ends, otherwise no more often than UPDATE_MS, and not before the card
## has drawn the last change.
func _refresh(now: bool) -> void:
	var job: Job = Working.current()
	if job == null:
		visible = false
		return
	var ticks: int = Time.get_ticks_msec()
	if not now:
		if ticks - _updated_at < UPDATE_MS or _changed_frames >= 0:
			return
		if _fence > 0:
			if not GpuFence.passed(_fence):
				return
			_fence = 0
	_updated_at = ticks
	visible = true
	var changed: bool = false
	var line: String = job.line()
	if _words.text != line:
		_words.text = line
		changed = true
	_cancel.visible = job.can_cancel and not job.cancelled
	changed = _bar.show_job(job.total, job.done, ticks - job.began_ms) or changed
	if changed and OS.has_feature("web"):
		_changed_frames = Engine.get_frames_drawn()


## Say on the page when [param job] was first drawn: the first frame drawn
## after it began.
func _watch_drawn(job: Job) -> void:
	if not OS.has_feature("web"):
		return
	RenderingServer.frame_post_draw.connect(func() -> void:
		if not job.ended:
			Working._tell_page({"what": job.words, "shown": true,
				"ms": Time.get_ticks_msec() - job.began_ms}), CONNECT_ONE_SHOT)


func controls_by_name() -> Dictionary:
	return {"work_cancel": _cancel} if visible and _cancel.visible else {}


## The bar itself: a track, and in it how far along, or a block running
## along it when there is no knowing.
class _Bar extends Control:
	var _share: float = -1.0
	var _run: float = 0.0

	## Whether it changed.
	func show_job(total: int, done: int, ms: int) -> bool:
		var share: float = clampf(float(done) / float(total), 0.0, 1.0) if total > 0 else -1.0
		# Once along the track and back every two seconds.
		var run: float = absf(fmod(ms / 1000.0, 2.0) - 1.0) if total <= 0 else 0.0
		if is_equal_approx(share, _share) and is_equal_approx(run, _run):
			return false
		_share = share
		_run = run
		queue_redraw()
		return true

	func _draw() -> void:
		var height: float = 6.0
		var track := Rect2(0, (size.y - height) / 2.0, size.x, height)
		draw_rect(track, Color(1, 1, 1, 0.12))
		var fill: Rect2
		if _share >= 0.0:
			fill = Rect2(track.position, Vector2(track.size.x * _share, height))
		else:
			var width: float = track.size.x * Working.RUNNER
			fill = Rect2(track.position + Vector2((track.size.x - width) * _run, 0),
				Vector2(width, height))
		draw_rect(fill, Color(0.36, 0.6, 1.0, 0.95))
