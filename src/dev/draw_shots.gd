## Pictures for an app with no window of its own (src/ai/leased_shots.gd).
##
##   gpu xvfb-run -a godot --path . --script src/dev/draw_shots.gd -- \
##     --dir=D --app-pid=P --linger=S
##
## Started by that app, never by hand: it watches D for requests (NNNNNN.asked,
## the bricks ModelShot would stage, each [part, colour, placing], the parts
## the session made, and the camera's angle, close look, rulers and marks),
## draws each with ModelShot as the app would in a window, and answers with
## NNNNNN.drawn, the picture's pixels as they came off the card (an empty
## dictionary for no picture). It ends S seconds after its last picture,
## YIELD_S after it when another job waits for the GPU, or when the app has
## gone, so the GPU lease it runs on is held only while it draws.
extends SceneTree

var _library: PartLibrary
## For each of the app's picture-takers, by its id: a ModelShot of this
## drawer's, the bricks to be pictured in a world of their own that is never
## drawn (ModelShot copies them onto its stage as it copies the app's), and
## what the app's had staged when it was last asked.
var _takers: Dictionary = {}
var _made: Dictionary = {}


func _initialize() -> void:
	_run()


func _arg(prefix: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix + "="):
			return a.substr(prefix.length() + 1)
	return ""


func _run() -> void:
	await process_frame
	var dir: String = _arg("--dir")
	var app: int = int(_arg("--app-pid"))
	var linger: float = float(_arg("--linger")) if not _arg("--linger").is_empty() else 20.0
	if dir.is_empty() or not DirAccess.dir_exists_absolute(dir):
		print("draw_shots: no --dir")
		quit(2)
		return
	# Frames as the app's are, driven from the command line: drawn when
	# something changed, and as fast as they come (Main._unthrottle...).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	IdleDraw.begin()
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("draw_shots: no catalogue")
		quit(1)
		return
	print("draw_shots: ready in %d ms" % Time.get_ticks_msec())
	var idle_since: float = Time.get_unix_time_from_system()
	while true:
		var asked: String = _next(dir)
		if asked.is_empty():
			# The whole linger while nobody else wants the GPU; a moment
			# when somebody waits for it, who has it as soon as this ends.
			var idle: float = Time.get_unix_time_from_system() - idle_since
			if idle > linger or (idle > YIELD_S and _others_wait()):
				break
			if not _alive(app):
				print("draw_shots: the app has gone")
				break
			await create_timer(0.05).timeout
			continue
		var started: int = Time.get_ticks_msec()
		var file: FileAccess = FileAccess.open(dir.path_join(asked), FileAccess.READ)
		var request: Variant = file.get_var() if file != null else null
		if file != null:
			file.close()
		DirAccess.remove_absolute(dir.path_join(asked))
		var answer: Dictionary = {}
		if request is Dictionary:
			var image: Image = await _draw(request)
			if image != null:
				answer = {"width": image.get_width(), "height": image.get_height(),
					"mipmaps": image.has_mipmaps(), "format": image.get_format(),
					"data": image.get_data()}
		var name: String = asked.get_basename()
		var writing: String = dir.path_join(name + ".writing-answer")
		var out: FileAccess = FileAccess.open(writing, FileAccess.WRITE)
		out.store_var(answer)
		out.close()
		DirAccess.rename_absolute(writing, dir.path_join(name + ".drawn"))
		print("draw_shots: %s %s in %d ms, %d bricks" % [name,
			"drawn" if not answer.is_empty() else "NO PICTURE", Time.get_ticks_msec() - started,
			(request as Dictionary).get("bricks", []).size() if request is Dictionary else 0])
		idle_since = Time.get_unix_time_from_system()
	quit(0)


## How long a drawer stays after a picture when another job waits for the GPU.
const YIELD_S := 2.0


## Whether another job waits for the GPU's lease: a ticket in its queue
## (~/.claude/claude-core/bin/gpu keeps one a waiter, under BOX_GPU_DIR).
static func _others_wait() -> bool:
	var dir: String = OS.get_environment("BOX_GPU_DIR")
	var queue: String = (dir if not dir.is_empty() else "/tmp/box-gpu").path_join("queue")
	return DirAccess.dir_exists_absolute(queue) and not DirAccess.get_files_at(queue).is_empty()


## Whether the app that started this still runs. Not OS.is_process_running,
## which answers only for this process's own children (the app is its
## grandparent, through the lease and xvfb-run); /proc where there is one.
static func _alive(pid: int) -> bool:
	if pid <= 0 or not DirAccess.dir_exists_absolute("/proc/self"):
		return true
	return DirAccess.dir_exists_absolute("/proc/%d" % pid)


## The oldest request waiting, or "".
func _next(dir: String) -> String:
	var waiting: PackedStringArray = PackedStringArray()
	for name: String in DirAccess.get_files_at(dir):
		if name.ends_with(".asked"):
			waiting.append(name)
	if waiting.is_empty():
		return ""
	waiting.sort()
	return waiting[0]


func _draw(request: Dictionary) -> Image:
	# The session's own parts first, built from their LDraw as the app built
	# them, and once a drawer.
	var made: Dictionary = request.get("made", {})
	for id: String in made:
		if _made.get(id, "") == made[id]:
			continue
		var added: Dictionary = CustomParts.add(_library, str(made[id]), id, false)
		if not str(added.get("problem", "")).is_empty():
			print("draw_shots: could not make %s: %s" % [id, added["problem"]])
		_made[id] = made[id]
	var taker: Dictionary = _taker(int(request.get("shot", 0)))
	var world: BrickWorld = taker["world"]
	# Staged again when the app's would be and not otherwise: a model
	# unchanged is left as it was, so ModelShot keeps what it staged.
	if taker["staged"] != request.get("staged", []):
		taker["staged"] = request.get("staged", [])
		world.clear()
		for brick: Array in request.get("bricks", []):
			world.add_brick(str(brick[0]), int(brick[1]), brick[2])
	var shot: ModelShot = taker["shot"]
	shot.rulers = bool(request.get("rulers", true))
	shot.marks = request.get("marks", [])
	shot.give_up_after = float(request.get("give_up_after", 20.0))
	return await shot.take(world, str(request.get("from", "corner")), {},
		request.get("only", AABB()))


func _taker(id: int) -> Dictionary:
	if not _takers.has(id):
		var world := BrickWorld.new()
		world.library = _library
		world.keeps_history = false
		root.add_child(world)
		world.hold_drawing()
		var shot := ModelShot.new()
		shot.library = _library
		root.add_child(shot)
		_takers[id] = {"world": world, "shot": shot, "staged": []}
	return _takers[id]
