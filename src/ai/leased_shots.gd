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

## The most a picture waits, the lease's queue included: inside the ten
## minutes a session gives a call (ClaudeCode.TOOL_TIMEOUT_MS). A picture
## waited for is the picture the design would have had in a window; letters
## in its place would make how busy the box was part of the design.
const MOST_WAIT_S := 480.0

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
## one that has.
static func in_use() -> bool:
	return DisplayServer.get_name() == "headless" and not command().is_empty()


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
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id):
			continue
		var colour: int = ModelShot.PICKED_OUT if shot.highlight.has(brick.id) \
			else brick.color_code
		bricks.append([brick.part_id, colour, brick.transform])
		# A part made in this session, which the drawer's catalogue has not.
		if not made.has(brick.part_id) and library.custom.has(brick.part_id):
			made[brick.part_id] = library.custom[brick.part_id]
	var request: Dictionary = {
		# Which picture-taker, and what it has staged: the drawer stages
		# again exactly when this one would. Two stagings of one model can
		# differ in a few dozen pixels, where faces meet in a tie the card
		# breaks by the order things were made in.
		"shot": shot.get_instance_id(), "staged": shot.stage_key(world, skip),
		"bricks": bricks, "made": made, "from": from, "only": only,
		"rulers": shot.rulers, "marks": shot.marks, "give_up_after": shot.give_up_after,
	}
	if _dir.is_empty():
		_dir = OS.get_user_data_dir().path_join("leased_shots_%d" % OS.get_process_id())
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
			push_warning("leased shots: no picture within %d s" % int(MOST_WAIT_S))
			return null
		# Twice a second, not every frame: a process looked up in /proc.
		var now: float = Time.get_unix_time_from_system()
		if now - checked > 0.5:
			checked = now
			if _pid < 0 or not OS.is_process_running(_pid):
				if starts >= MOST_STARTS:
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
	arguments.append_array(["--path",
		ProjectSettings.globalize_path("res://"), "--log-file", _dir.path_join("drawer.log"),
		"--script", "res://src/dev/draw_shots.gd", "--", "--dir=" + _dir,
		"--app-pid=%d" % OS.get_process_id(), "--linger=%.1f" % LINGER_S])
	_pid = OS.create_process(str(words[0]), arguments)
	if _pid < 0:
		push_warning("leased shots: could not start %s" % str(words[0]))
