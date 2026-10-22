## Pictures drawn by a process of their own, for an app with no window.
##
## A design run of the bench (tools/bench/run.py) is the app driven over its
## port for ten minutes or more, and it needs the graphics card for under a
## second of that: its pictures. Run in a window on the box's GPU lease, a
## design held one of the two slots for a whole session it barely drew in, so
## two designs ran at once and every other job that draws waited behind them.
##
## So the bench starts the app headless, with --draw-by= naming how to start
## a windowed Godot on the lease (the box's `gpu`, xvfb-run and godot, as a
## JSON list of words; this project and the drawer's arguments follow), and each
## picture is drawn by src/dev/draw_shots.gd: this app's own ModelShot,
## handed the very bricks, colours and placings it would have staged itself,
## in a process that holds the lease while it draws and for a few seconds
## after, for the next picture. A check's picture and the look after it, or
## the three of a review, are one drawer.
class_name LeasedShots
extends RefCounted

const ARGUMENT := "--draw-by="

## How long a drawer stays after its last picture, waiting for the next.
## Starting one is a few seconds: the catalogue and the first shaders.
const LINGER_S := 20.0

## The most a picture waits, the lease's queue included, before the caller
## is given null and draws the letters, as a window gives up on a picture
## after ModelShot.give_up_after. Eight minutes was the first cap: behind
## two windowed designs and a queue of seven, three of four designs' checks
## waited 460 to 534 s, and each session took the app for stuck and stopped
## with nothing built (2026-10-20). Letters now and then are a design that
## goes on.
const MOST_WAIT_S := 120.0

## Drawers started for one picture before it is given up: one that exits
## without answering (it lingered out just as the request was written) is
## started again.
const MOST_STARTS := 3

static var _words: Array = []
static var _read: bool = false
static var _one: LeasedShots = null

var _dir: String = ""
var _pid: int = -1
var _asked: int = 0


## How a drawer is started, from --draw-by=, or empty.
static func command() -> Array:
	if not _read:
		_read = true
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with(ARGUMENT):
				var parsed: Variant = JSON.parse_string(argument.substr(ARGUMENT.length()))
				if parsed is Array:
					_words = parsed
	return _words


## Whether pictures are drawn elsewhere: no window here, and a way to start
## one that has, or an app that started this one to draw them (BestOfTwo).
static func in_use() -> bool:
	return DisplayServer.get_name() == "headless" \
		and (not command().is_empty() or not BestOfTwo.second_of().is_empty())


static func shared() -> LeasedShots:
	if _one == null:
		_one = LeasedShots.new()
	return _one


## The picture [param shot] would take of [param world], drawn by a drawer,
## or null as [method ModelShot.take] gives null: nothing to draw, or no
## picture in time.
func take(shot: ModelShot, world: BrickWorld, from: String, skip: Dictionary,
		only: AABB) -> Image:
	var library: PartLibrary = shot.library if shot.library != null else world.library
	# What ModelShot._restage stages, in its order: the skipped left out and
	# the picked out in its colour, so the drawer stages these and no more.
	var bricks: Array = []
	var made: Dictionary = {}
	var shaped: bool = false
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id):
			continue
		var colour: int = ModelShot.PICKED_OUT if shot.highlight.has(brick.id) \
			else brick.color_code
		bricks.append([brick.part_id, colour, brick.transform])
		shaped = shaped or library.mesh_for(brick.part_id) != null
		# A part made in this session, which the drawer's catalogue has not.
		if not made.has(brick.part_id) and library.custom.has(brick.part_id):
			made[brick.part_id] = library.custom[brick.part_id]
	# Nothing to stage, or nothing staged with a shape: ModelShot finds no
	# bounds and gives no picture at once, and so does this, without a wait
	# for the GPU for it: a check's picture with nothing left to stage is
	# what three designs of a four-worker run waited eight minutes for.
	if not shaped:
		return null
	var request: Dictionary = {
		# Which picture-taker, and what it has staged: the drawer stages
		# again exactly when this one would. A model staged twice came out
		# 58 pixels of a million apart from one staged once, scattered
		# single pixels, most likely faces that tie.
		"shot": shot.get_instance_id(), "staged": shot.stage_key(world, skip),
		"bricks": bricks, "made": made, "from": from, "only": only,
		"rulers": shot.rulers, "marks": shot.marks, "give_up_after": shot.give_up_after,
	}
	# A second design's pictures are drawn by the app that started it, which
	# watches a folder it named; no drawer is started here.
	var by_app: bool = not BestOfTwo.second_of().is_empty()
	if _dir.is_empty():
		_dir = BestOfTwo.shots_dir() if by_app \
			else OS.get_user_data_dir().path_join("leased_shots_%d" % OS.get_process_id())
		DirAccess.make_dir_recursive_absolute(_dir)
	_asked += 1
	var name: String = "%06d" % _asked
	var writing: String = _dir.path_join(name + ".writing")
	var file: FileAccess = FileAccess.open(writing, FileAccess.WRITE)
	if file == null:
		push_warning("leased shots: could not write %s (%d)" % [writing, FileAccess.get_open_error()])
		return null
	file.store_var(request)
	file.close()
	DirAccess.rename_absolute(writing, _dir.path_join(name + ".asked"))

	var answer: String = _dir.path_join(name + ".drawn")
	var until: float = Time.get_unix_time_from_system() + MOST_WAIT_S
	var starts: int = 0
	var checked: float = 0.0
	var tree: SceneTree = shot.get_tree()
	while not FileAccess.file_exists(answer):
		if Time.get_unix_time_from_system() > until:
			# Taken back, so a drawer that comes later does not draw it for nobody.
			DirAccess.remove_absolute(_dir.path_join(name + ".asked"))
			push_warning("leased shots: no picture within %d s" % int(MOST_WAIT_S))
			return null
		# Twice a second, not every frame: a process looked up in /proc.
		var now: float = Time.get_unix_time_from_system()
		if now - checked > 0.5 and not by_app:
			checked = now
			if _pid < 0 or not OS.is_process_running(_pid):
				if starts >= MOST_STARTS:
					DirAccess.remove_absolute(_dir.path_join(name + ".asked"))
					push_warning("leased shots: %d drawers ended without the picture" % starts)
					return null
				starts += 1
				_start()
		await tree.process_frame
	var read: FileAccess = FileAccess.open(answer, FileAccess.READ)
	var drawn: Variant = read.get_var() if read != null else null
	if read != null:
		read.close()
	DirAccess.remove_absolute(answer)
	if not drawn is Dictionary or (drawn as Dictionary).is_empty():
		return null
	var got: Dictionary = drawn
	return Image.create_from_data(int(got["width"]), int(got["height"]), bool(got["mipmaps"]),
		int(got["format"]) as Image.Format, got["data"])


func _start() -> void:
	var words: Array = command()
	var arguments := PackedStringArray()
	for word: Variant in words.slice(1):
		arguments.append(str(word))
	# The script first, so the lease's log and `gpu --status`, which keep a
	# command's first 200 characters, say what holds the GPU.
	arguments.append_array(["--script", "res://src/dev/draw_shots.gd", "--path",
		ProjectSettings.globalize_path("res://"), "--log-file", _dir.path_join("drawer.log"),
		"--", "--dir=" + _dir,
		"--app-pid=%d" % OS.get_process_id(), "--linger=%.1f" % LINGER_S])
	_pid = OS.create_process(str(words[0]), arguments)
	if _pid < 0:
		push_warning("leased shots: could not start %s" % str(words[0]))
		return
	# Stopped with the app: a drawer still in the lease's queue when the app
	# ends would take a slot when its turn came, for nobody.
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	if not root.tree_exiting.is_connected(_stop):
		root.tree_exiting.connect(_stop)


func _stop() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)


## The drawing half: a drawer process's (src/dev/draw_shots.gd), and an app
## drawing a second design's pictures beside its own (BestOfTwo). Each
## request is staged in a world of its own that is never drawn, and pictured
## by a ModelShot of its own, one for each of the asking app's picture-takers.
class Drawer extends RefCounted:
	var library: PartLibrary
	## Where its worlds and picture-takers are added.
	var parent: Node
	var _takers: Dictionary = {}
	var _made: Dictionary = {}

	## The oldest request waiting in [param dir], or "".
	static func next(dir: String) -> String:
		var waiting: PackedStringArray = PackedStringArray()
		for name: String in DirAccess.get_files_at(dir):
			if name.ends_with(".asked"):
				waiting.append(name)
		if waiting.is_empty():
			return ""
		waiting.sort()
		return waiting[0]

	## Draw the request [param asked] in [param dir] and answer it with its
	## .drawn, the picture's pixels as they came off the card, or an empty
	## dictionary for no picture. How many bricks it staged, -1 for none.
	func answer(dir: String, asked: String) -> int:
		var file: FileAccess = FileAccess.open(dir.path_join(asked), FileAccess.READ)
		var request: Variant = file.get_var() if file != null else null
		if file != null:
			file.close()
		DirAccess.remove_absolute(dir.path_join(asked))
		var answered: Dictionary = {}
		if request is Dictionary:
			var image: Image = await draw(request)
			if image != null:
				answered = {"width": image.get_width(), "height": image.get_height(),
					"mipmaps": image.has_mipmaps(), "format": image.get_format(),
					"data": image.get_data()}
		var name: String = asked.get_basename()
		var writing: String = dir.path_join(name + ".writing-answer")
		var out: FileAccess = FileAccess.open(writing, FileAccess.WRITE)
		if out == null:
			return -1
		out.store_var(answered)
		out.close()
		DirAccess.rename_absolute(writing, dir.path_join(name + ".drawn"))
		if answered.is_empty():
			return -1
		return (request as Dictionary).get("bricks", []).size()

	func draw(request: Dictionary) -> Image:
		# The session's own parts first, built from their LDraw as the app
		# built them, and once a drawer.
		var made: Dictionary = request.get("made", {})
		for id: String in made:
			if _made.get(id, "") == made[id]:
				continue
			var added: Dictionary = CustomParts.add(library, str(made[id]), id, false)
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

	## Its worlds and picture-takers gone.
	func clear() -> void:
		for taker: Dictionary in _takers.values():
			(taker["world"] as Node).queue_free()
			(taker["shot"] as Node).queue_free()
		_takers.clear()

	func _taker(id: int) -> Dictionary:
		if not _takers.has(id):
			var world := BrickWorld.new()
			world.library = library
			world.keeps_history = false
			# Never drawn where it is: its batches are held for good, and
			# in an app with a window it is out of sight as well.
			world.visible = false
			parent.add_child(world)
			world.hold_drawing()
			var shot := ModelShot.new()
			shot.library = library
			parent.add_child(shot)
			_takers[id] = {"world": world, "shot": shot, "staged": []}
		return _takers[id]
