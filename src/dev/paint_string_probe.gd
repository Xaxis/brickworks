## A person paints the string of someone else's file, saves, opens another
## file and comes back: the string is yellow (keeptext5).
##
##   godot --headless --path . --script src/dev/paint_string_probe.gd
##
## 42079-1's string is LDCad's: a path with its caps and its rope, the rope
## a part of its own made from the lines LDCad generated (CustomParts). Its
## colour is said on the line placing the rope's sub-model, as LDCad says a
## path's. keeptext4 never wrote a flexible part's colour, refused the
## save, and the next open lost the work (kt4review #1). Here, as a person
## does it:
## 1. 42079-1 opened from the LDraw model repository;
## 2. the rope painted yellow, in its sub-model, as a person picks it;
## 3. saved by Save: the file is written, as a patch of the file (only the
##    line giving the rope its colour changed), and the bar says nothing
##    is left out;
## 4. another file opened over it: the work is set aside for Undo;
## 5. the saved file opened again: the rope is yellow, every other part as
##    it was.
## And the rope's two ends painted alone, which no line can say without
## painting the path's caps too: written as live writes it, the bar saying
## once what of the file that leaves out, and yellow when opened again.
extends SceneTree

const FILE := "res://vendor/omr/files/42079-1.mpd"
const OTHER := "res://src/dev/fixtures/kt3r_leocad.ldr"
const ROPE := "42079 - string_subpart1-flex"
const ENDS := "42079 - string-flex"
const STRING := "forklift#1/Fork#1/String#1"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _bar: ModelBar
var _said: Array = []


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	_bar.said.connect(func(text: String) -> void: _said.append(text))
	var text: String = FileAccess.get_file_as_string(FILE)
	if _check("%s read (%d chars)" % [FILE, text.length()], not text.is_empty()):
		await _paint(text, ROPE, true)
		await _paint(text, ENDS, false)
	print("paint_string probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


## [param text] opened, the bricks of [param part] in the string painted
## yellow and saved by Save, another file opened over it, and the saved file
## opened again. [param patched]: the save is a patch of the file.
func _paint(text: String, part: String, patched: bool) -> void:
	print("\n%s painted yellow" % part)
	var name: String = "42079-1 %s" % ("rope" if patched else "ends")
	await _open(text, name)
	var before: Dictionary = _colours()
	var ids: Array = _bricks_of(part)
	if not _check("opened %d parts, someone else's file kept; %d of %s in the string" % [
			_world.brick_count(), ids.size(), part],
			_store.call("_live_source") != null and ids.size() == 1):
		return
	# Into the string's sub-model, as a person goes in to pick its rope.
	var at: String = Assemblies.path_of(_world.get_brick(int(ids[0])))
	_shell.assemblies.enter(Assemblies.parent_of(at) if at != STRING else STRING)
	_builder.clear_selection()
	_builder.selection[int(ids[0])] = true
	_builder.selection_changed.emit(1)
	var painted: int = _builder.paint_selection(14)
	await _frames(6)
	_shell.assemblies.leave_to("")
	_check("painted %d (%s in %s) yellow" % [painted, part, at],
		painted == 1 and _world.get_brick(int(ids[0])).color_code == 14)
	# Saved as Save saves it.
	_said.clear()
	var path: String = ModelStore.saved_path(name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var saved_ok: bool = await _bar.call("_on_save")
	var saved: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var whole: String = str(_store.get("last_whole"))
	_check("Save: written (%d chars), %s" % [saved.length(),
		"a patch of the file" if whole.is_empty() else "as live writes it (%s)" % whole],
		saved_ok and not saved.is_empty() and whole.is_empty() == patched)
	if patched:
		var changed: Array = _changed(text, saved)
		_check("...one line of the file changed, the rope's sub-model's colour: %s" % str(changed),
			changed.size() == 1 and str(changed[0]).begins_with("1 14 ")
			and str(changed[0]).ends_with("42079 - String_subPart1.ldr"))
	var left: Array = _said.filter(func(line: String) -> bool: return line.contains("won't be kept"))
	_check("...the bar says %s" % (str(left) if not left.is_empty() else "nothing is left out"),
		left.is_empty() == patched)
	# Another file opened over it: the work set aside for Undo.
	var aside: int = _store.opened_over.size()
	_store.keeps = true
	var opened: Dictionary = await _bar.open_text_with_progress(
		FileAccess.get_file_as_string(OTHER), "kt3r leocad")
	_bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)
	_store.keeps = false
	_check("another file opened: the work set aside for Undo (%d -> %d)" % [aside,
		_store.opened_over.size()], _store.opened_over.size() == aside + 1)
	# The saved file opened again.
	await _open(saved, name)
	var again: Dictionary = _colours()
	var yellow: Array = _bricks_of(part).filter(func(id: int) -> bool:
		return _world.get_brick(id).color_code == 14)
	_check("opened again: %s is yellow" % part, yellow.size() == 1)
	if not patched:
		return
	var others: int = 0
	for key: String in before:
		if key.begins_with(part + "|"):
			continue
		if int(again.get(key, -1)) != int(before[key]):
			others += 1
	_check("...and %d other parts in another colour than they were" % others, others == 0)


## Each part by its number and place -> how many of it there are, by colour.
func _colours() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var at: Vector3 = brick.transform.origin.snapped(Vector3.ONE * 0.1)
		out["%s|%s|%d" % [brick.part_id, str(at), brick.color_code]] = \
			int(out.get("%s|%s|%d" % [brick.part_id, str(at), brick.color_code], 0)) + 1
	return out


func _bricks_of(part: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			out.append(brick.id)
	return out


## The lines of [param now] that are not lines of [param was], the app's
## own aside.
static func _changed(was: String, now: String) -> Array:
	var had: Dictionary = {}
	for line: String in was.split("\n"):
		had[line] = int(had.get(line, 0)) + 1
	var out: Array = []
	for line: String in now.split("\n"):
		if line.begins_with("0 !BRICKWORKS"):
			continue
		if int(had.get(line, 0)) > 0:
			had[line] = int(had[line]) - 1
		else:
			out.append(line.strip_edges())
	return out


func _open(text: String, name: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var opened: Dictionary = await _bar.open_text_with_progress(text, name)
	_bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
