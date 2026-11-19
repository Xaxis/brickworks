## The status bar's weigh over frames, where there are no threads
## (Stability.check_in_frames, docs/PHONE.md "The no-threads export on
## WebKit"), against the weigh in one go that a worker does.
##
##   godot --headless --path . --script src/dev/weighpace_probe.gd
##   tools/probe.sh weighpace_probe
##   ... -- MODEL...    those models instead of the twenty below
##
## Without threads the engine runs a pool task in the frame that asks for it,
## and the weigh of a model past 600 parts held one frame for the whole of
## it: 1.7 s on 75969-1 in WebKit, 8.6 s on Orthanc, after every change. Over
## frames it is the same code with places to give the frame back. The bar:
## 1. on twenty real models, Orthanc, 10179-1 and 75969-1 among them, the
##    report over frames is the one in one go: its verdict, weight, joints
##    and every risk and margin, to the message;
## 2. on Orthanc it is spread over frames: no stretch of it between two
##    frames a tenth of the weigh in one go. The aim is its slice and a
##    part's share past it (Stability.IN_FRAMES_US and 10 ms, desktop time),
##    which it misses by what is still in one piece (Joints.held_otherwise,
##    Balance._weigh, docs/PHONE.md): said beside it, not held to it;
## 3. a weigh stopped part way (a change meanwhile, Main._weigh) says null,
##    never a verdict.
extends SceneTree

const MODELS: Array[String] = ["res://models/orthanc.ldr", "res://vendor/omr/files/10179-1.mpd",
	"res://vendor/omr/files/75969-1.mpd", "res://vendor/omr/files/42082-1.mpd",
	"res://vendor/omr/files/8466-1.mpd", "res://vendor/omr/files/21318-1.mpd",
	"res://vendor/omr/files/10264-1.mpd", "res://vendor/omr/files/8202-1.mpd",
	"res://vendor/omr/files/42083-1.mpd", "res://vendor/omr/files/7191-1.mpd",
	"res://vendor/omr/files/42096-1.mpd", "res://vendor/omr/files/21323-1.mpd",
	"res://vendor/omr/files/10261-1.mpd", "res://vendor/omr/files/10283-1.mpd",
	"res://vendor/omr/files/41075-1.mpd", "res://vendor/omr/files/42054-1.mpd",
	"res://vendor/omr/files/3188-1.mpd", "res://vendor/omr/files/70816-1.mpd",
	"res://vendor/omr/files/6765-1.mpd", "res://models/castle.ldr"]
## Past the slice, what one part's own step may take before the frame is
## given back, desktop time on a loaded box: the aim.
const PART_SLACK_MS := 10.0
## The most of the weigh in one go one stretch of it over frames may be.
const MOST_OF_ONE_GO := 0.1

var _failures: int = 0
## The longest stretch between two frames while a weigh goes on, in ms.
var _longest: float = 0.0
var _last_us: int = 0
var _watching: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("  FAIL  no catalogue")
		quit(1)
		return
	process_frame.connect(_on_frame)
	var models: Array = Array(OS.get_cmdline_user_args()).filter(func(a: String) -> bool:
		return not a.begins_with("--"))
	if models.is_empty():
		models = MODELS
	var same: int = 0
	for path: String in models:
		var built: Array = await _built(library, path)
		if built.is_empty():
			_failures += 1
			print("  FAIL  %s: did not open" % path.get_file())
			continue
		var world: BrickWorld = built[0]
		var builder: Builder = built[1]
		var whole := _judge(library, builder.lattice)
		var began: int = Time.get_ticks_usec()
		var at_once: Stability.Report = whole.check(world)
		var once_ms: float = (Time.get_ticks_usec() - began) / 1000.0
		var paced := _judge(library, builder.lattice)
		_longest = 0.0
		_last_us = Time.get_ticks_usec()
		_watching = true
		began = Time.get_ticks_usec()
		var frames_from: int = Engine.get_process_frames()
		var over: Stability.Report = await paced.check_in_frames(world,
			FramePace.new(FramePace.LEAST_US, Stability.IN_FRAMES_US))
		var paced_ms: float = (Time.get_ticks_usec() - began) / 1000.0
		_watching = false
		var frames: int = Engine.get_process_frames() - frames_from
		var differs: String = _differs(at_once, over)
		if differs.is_empty():
			same += 1
			print("  ok    %s, %d parts: the same over %d frames (%s); in one go %d ms, over frames %d ms, its longest stretch %.1f ms"
				% [path.get_file(), world.brick_count(), frames, at_once.summary(), roundi(once_ms),
					roundi(paced_ms), _longest])
		else:
			_failures += 1
			print("  FAIL  %s: over frames differs: %s" % [path.get_file(), differs])
		if path.ends_with("orthanc.ldr"):
			var bar: float = once_ms * MOST_OF_ONE_GO
			var aim: float = Stability.IN_FRAMES_US / 1000.0 + PART_SLACK_MS
			if _longest <= bar and frames > 50:
				print("  ok    Orthanc's weigh over %d frames: its longest stretch %.1f ms, under a tenth of it in one go (%d ms); the aim %.0f ms %s"
					% [frames, _longest, roundi(once_ms), aim, "met" if _longest <= aim else "not yet met"])
			else:
				_failures += 1
				print("  FAIL  Orthanc's weigh: its longest stretch %.1f ms over %d frames (bar %.0f ms, a tenth of it in one go, 50+ frames)"
					% [_longest, frames, bar])
			await _stopped_says_null(library, world, builder)
		world.queue_free()
		builder.queue_free()
		await process_frame
	print("  %s   %d of %d models weigh the same over frames as in one go"
		% ["ok  " if same == models.size() else "FAIL", same, models.size()])
	if _failures > 0:
		print("\n%d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _on_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if _watching:
		_longest = maxf(_longest, (now - _last_us) / 1000.0)
	_last_us = now


func _judge(library: PartLibrary, lattice: BrickLattice) -> Stability:
	var judge := Stability.new()
	judge.library = library
	judge.lattice = lattice
	judge.with_margins = true
	return judge


## 3: stopped a few frames in, as Main stops it when the model changes.
func _stopped_says_null(library: PartLibrary, world: BrickWorld, builder: Builder) -> void:
	var judge := _judge(library, builder.lattice)
	var stopping := func() -> void:
		for _n: int in 5:
			await process_frame
		judge.stopped = true
	stopping.call()
	var report: Stability.Report = await judge.check_in_frames(world,
		FramePace.new(FramePace.LEAST_US, Stability.IN_FRAMES_US))
	if report == null:
		print("  ok    a weigh stopped five frames in says nothing (null), not a verdict")
	else:
		_failures += 1
		print("  FAIL  a weigh stopped part way said \"%s\"" % report.summary())


## What differs between [param a] and [param b], or "".
func _differs(a: Stability.Report, b: Stability.Report) -> String:
	if a == null or b == null:
		return "one is null (%s, %s)" % [a, b]
	if a.summary() != b.summary():
		return "verdict \"%s\" against \"%s\"" % [a.summary(), b.summary()]
	if not is_equal_approx(a.total_grams, b.total_grams) or a.joints != b.joints:
		return "%s g, %d joints against %s g, %d" % [a.total_grams, a.joints, b.total_grams, b.joints]
	if a.risks.size() != b.risks.size():
		return "%d risks against %d" % [a.risks.size(), b.risks.size()]
	for n: int in a.risks.size():
		var one: Stability.Risk = a.risks[n]
		var other: Stability.Risk = b.risks[n]
		if one.message != other.message or one.brick_id != other.brick_id \
				or not is_equal_approx(one.margin, other.margin):
			return "risk %d: \"%s\" against \"%s\"" % [n, one.message, other.message]
	if a.margins.size() != b.margins.size():
		return "%d margins against %d" % [a.margins.size(), b.margins.size()]
	for id: Variant in a.margins:
		var one: Balance.JointLoad = a.margins[id]
		var other: Balance.JointLoad = b.margins.get(id)
		if other == null or not is_equal_approx(one.ratio, other.ratio):
			return "the margin of #%s" % id
	if a.held != b.held:
		return "what holds each part"
	return ""


## [world, builder] with [param path] laid as stability_probe lays Orthanc,
## or [] when it does not open.
func _built(library: PartLibrary, path: String) -> Array:
	var ldr: LdrModel = LdrModel.load_file(path)
	if ldr == null:
		return []
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	await process_frame
	for piece: LdrModel.Placement in ldr.flatten():
		var part_id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(part_id) == null:
			continue
		var id: int = world.add_brick(part_id, piece.color_code, piece.transform)
		if id != 0:
			builder.register(id, part_id, piece.transform)
	if world.brick_count() == 0:
		world.queue_free()
		builder.queue_free()
		return []
	return [world, builder]
