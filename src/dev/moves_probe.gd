## What a shared model's card says moves, for real sets: every word names
## parts that move as the word says (Playable).
##
##   godot --headless --path . --script src/dev/moves_probe.gd
##   godot --headless --path . --script src/dev/moves_probe.gd -- seeds|held_out
##   godot --headless --path . --script src/dev/moves_probe.gd -- dump FILE...
##
## moves268 (2026-10-25): the gallery's King's Castle and Dragon Defender
## both said "Moves: boom", and a castle has no boom. Each set in
## tests/fixtures/moves/truth.json is opened as the app opens it, its joints
## read as a drag reads them (GrabDrag), and what Playable says it moves is
## judged against what it really moves, from its renders and its own steps:
## a word it says that the set does not have fails (a line left out is
## better than a wrong one). The sets are the gallery's thirty seeds and the
## models that come with the app, where a word the set is marked as sure to
## have and the card does not say fails too (what the rule found right
## before stays found), and sixteen more held out: chosen and judged before
## the rule was changed and opened only after, where a word missed is told
## and not failed (the joints a drag finds do not see every crane's arm).
##
## With dump, each file named is read and each body Playable names is told:
## its word, its joint, how many parts and how far they reach, and what
## they are. Nothing is judged.
extends SceneTree

const TRUTH := "res://tests/fixtures/moves/truth.json"
const OMR := "res://vendor/omr/files/"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _library: PartLibrary
var _grab: GrabDrag
var _store: ModelStore


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_library = _main.get("_library")
	_grab = _main.get("_grab_drag")
	_store = _main.get("_store")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "dump":
		for path: String in args.slice(1):
			await _dump(path)
		_done()
		return
	var truth: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRUTH))
	# One group alone where it is named: the seeds, or the held out.
	var groups: Array = ["seeds", "held_out"]
	if args.size() > 0 and groups.has(args[0]):
		groups = [args[0]]
	for group: String in groups:
		print("── %s ──" % group)
		var sets: Dictionary = truth[group]
		for file: String in sets:
			await _judge(file, sets[file], group == "seeds")
	_done()


## [param file]'s words against what it really moves: [param said]'s
## "moves" are the words it may say, "sure" those it has; a sure word
## missed fails where [param must] is true, else is told.
func _judge(file: String, said: Dictionary, must: bool) -> void:
	var path: String = file if file.begins_with("res://") else OMR + file
	if not await _open(path):
		_check("%s opens" % file, false)
		return
	var found: Dictionary = _read()
	var words: PackedStringArray = Playable.kinds(found)
	var may: Array = said.get("moves", [])
	var sure: Array = said.get("sure", [])
	var wrong: Array = []
	for word: String in words:
		if not may.has(word):
			wrong.append("%s (%s)" % [word, _named(found[word])])
	var missing: Array = []
	for word: String in sure:
		if not words.has(word):
			missing.append(word)
	_check("%s %s: says %s%s%s" % [file, str(said.get("name", "")),
		Playable.words(words) if not words.is_empty() else "nothing",
		"; wrong: " + ", ".join(wrong) if not wrong.is_empty() else "",
		"; misses " + ", ".join(missing) if not missing.is_empty() else ""],
		wrong.is_empty() and (missing.is_empty() or not must))


func _open(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 600:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0 and not _store.laying:
			break
	for _n: int in 5:
		await process_frame
	return _world.brick_count() > 0


func _read() -> Dictionary:
	_grab._ready_now()
	return Playable.read(_grab.read_bodies(), _world, _library, _grab.read_mechanism())


## The first few parts [param ids] name, by name.
func _named(ids: Array) -> String:
	var out: Array = []
	for id: Variant in ids.slice(0, 2):
		out.append(_name_of(int(id)))
	return " · ".join(out)


func _name_of(id: int) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id) if brick != null else null
	return "%s %s" % [brick.part_id, info.name.strip_edges()] if info != null else "?"


## Each body that hangs on a joint and is not a hose, as Playable sees it.
func _dump(path: String) -> void:
	if not await _open(path):
		print("%s: did not open" % path)
		return
	var found: Dictionary = _read()
	print("%s: %d parts, %s" % [path.get_file(), _world.brick_count(),
		Playable.words(Playable.kinds(found))])
	var bodies: Bodies = _grab.read_bodies()
	var named: Dictionary = {}
	for kind: String in found:
		for id: Variant in found[kind]:
			named[int(bodies.body_of.get(int(id), -1))] = kind
	for key: Variant in bodies.parent_link:
		var body: int = int(key)
		if bodies.flexible.has(body):
			continue
		var link: Bodies.Link = bodies.parent_link[body]
		var ids: PackedInt64Array = bodies.members.get(body, PackedInt64Array())
		var reach: float = Playable._reach(bodies, body, link, _world, _library)
		var counts: Dictionary = {}
		for id: int in ids:
			var part: String = _name_of(id)
			counts[part] = int(counts.get(part, 0)) + 1
		var parts: Array = []
		for part: String in counts:
			parts.append("%d× %s" % [counts[part], part] if int(counts[part]) > 1 else part)
		print("  %-10s %d parts on %s %s, axis %s, reach %.0f: %s" % [str(named.get(body, "-")),
			ids.size(), link.kind, "turns" if link.turns else "slides", str(link.axis.snapped(Vector3.ONE * 0.01)),
			reach, ", ".join(parts.slice(0, 8))])


func _done() -> void:
	print("moves probe: %s" % ("every word a card says is a move the set has" if _failures == 0
		else "%d sets said what they do not move" % _failures))
	quit(1 if _failures > 0 else 0)
