## smalls12's file checks, headless, about a minute:
##
##   godot --headless --path . --script src/dev/smalls12_probe.gd
##
##  1. A motion's name as the person typed it (camreview F2): written and
##     read back with its inner runs of spaces, its quotes made single, a
##     name in any script, and written again the same. A name that is only
##     edge spaces round its words is trimmed, as it always was. The file's
##     other words still split on any run of spaces or tabs: every motion
##     line in the repo's own models reads the same as before (the same
##     lines written, the same lines not read), and a line with tabs and
##     double spaces between its words reads as its single-spaced self.
##  2. An unedited save keeps the file's bytes (kbk3review L1), with the app
##     up (about a minute): opened from the person's models, the kept copy
##     is the file's bytes, its size the file's; a Latin-1 file, a UTF-8
##     one with a BOM and CRLF, and one with no line end at its last line
##     save back byte for byte by the fast path, twice; the save holds no
##     second copy once its moment is kept, nor does an autosave; an edit
##     saved is kept as its new file's bytes, and Undo then saves the file
##     as it was, its kept copy that file again.
extends SceneTree

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _bar: ModelBar

const MOTION_FILES: Array[String] = [
	"res://src/dev/fixtures/bench/sculpt170-080.ldr",
	"res://src/dev/fixtures/metalines/drive.ldr",
	"res://src/dev/fixtures/metalines/apps.mpd",
	"res://src/dev/fixtures/house/robot.ldr",
	"res://tests/fixtures/mcpwalk3/observatory.ldr",
	"res://tests/fixtures/mcpwalk3/small-observatory.ldr",
	"res://tests/fixtures/motions/8808-1_rim_off.mpd",
	"res://tools/web/gallery_seeds/maintenance_robot.ldr",
	"res://tools/web/gallery_seeds/working_windmill.ldr",
]


func _initialize() -> void:
	_run()


func _run() -> void:
	_names()
	_old_lines()
	await _kept_bytes()
	print("\nSMALLS12 %s, %d failed" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _names() -> void:
	print("\n1. A motion's name as typed")
	var names: Array = [
		['Fly "round"', "Fly 'round'"],
		["Fly  round   twice", "Fly  round   twice"],
		["Облёт  回る ☆", "Облёт  回る ☆"],
		["  spaced  ", "spaced"],
		["  two  words  ", "two  words"],
	]
	for pair: Array in names:
		var typed: String = pair[0]
		var motion := Motions.Motion.new()
		motion.name = typed
		motion.camera = Motions.CameraTrack.new()
		motion.camera.add_key(Motions.camera_key_of(0.0, Vector3(1, -2, 3), 10.0, 20.0, 300.0, 30.0))
		motion.camera.add_key(Motions.camera_key_of(3.0, Vector3(1, -2, 3), 370.0, 20.0, 300.0, 30.0, "linear"))
		var made := Motions.new()
		made.list.append(motion)
		# A sequence that plays it, its name quoted in the line's words too.
		var plays := Motions.Motion.new()
		plays.name = "Show  it all"
		plays.sequence = PackedStringArray([typed.replace('"', "'").strip_edges()])
		made.list.append(plays)
		var lines: PackedStringArray = made.lines()
		var back: Motions = Motions.read("0 Model\n" + "\n".join(lines) + "\n")
		var lines2: PackedStringArray = back.lines()
		var got: String = back.list[0].name if not back.list.is_empty() else "(none)"
		var played: String = str(back.named("Show  it all").sequence) if back.named("Show  it all") != null \
			else "(no sequence)"
		_check("%s written %s, read back as %s, its sequence plays %s, written again the same" % [
			JSON.stringify(typed), lines[0], JSON.stringify(got), played],
			got == str(pair[1]) and lines == lines2 and back.unread.is_empty()
			and back.list[0].camera != null and back.list[0].camera.keys.size() == 2
			and back.named("Show  it all") != null and back.named("Show  it all").sequence.size() == 1
			and back.named("Show  it all").sequence[0] == str(pair[1]))


## Every motion line in the repo's models read as before: what the reader
## made of each line made one space apart (MetaIndex clean, the old reading)
## is what it makes of the line as the file has it.
func _old_lines() -> void:
	print("\n2. Old files' motion lines read the same")
	var files: int = 0
	var all_lines: int = 0
	for path: String in MOTION_FILES:
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty():
			_check("%s read" % path, false)
			continue
		var cleaned := PackedStringArray()
		var count: int = 0
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("0 !BRICKWORKS MOTION"):
				cleaned.append(MetaIndex.clean(line))
				count += 1
			else:
				cleaned.append(line)
		var now: Motions = Motions.read(text)
		var before: Motions = Motions.read("\n".join(cleaned))
		files += 1
		all_lines += count
		_check("%s: %d motion lines, %d motions, %d not read: read as the old reading read them" % [
			path.get_file(), count, now.list.size(), now.unread.size()],
			now.lines() == before.lines() and now.unread.size() == before.unread.size()
			and now.list.size() == before.list.size())
	var spaced: String = "0 Model\n0 !BRICKWORKS MOTION_CAMERA \"Fly round\"\t8  AT 10 -40 20 TURN  325 TILT 26 AWAY 640 FOV 30 LINEAR\n"
	var single: String = "0 Model\n0 !BRICKWORKS MOTION_CAMERA \"Fly round\" 8 AT 10 -40 20 TURN 325 TILT 26 AWAY 640 FOV 30 LINEAR\n"
	var a: Motions = Motions.read(spaced)
	var b: Motions = Motions.read(single)
	_check("a camera line with a tab and double spaces between its words reads as its single-spaced self: %s"
		% str(a.lines()), a.lines() == b.lines() and a.unread.is_empty() and a.list.size() == 1)
	print("  %d files, %d motion lines" % [files, all_lines])


## Item 2: the kept copy is the file's bytes.
func _kept_bytes() -> void:
	print("\n2. An unedited save keeps the file's bytes")
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_store = _main.get("_store")
	_bar = _main.get("_bar")
	_store.keeps = false
	var robot: PackedByteArray = FileAccess.get_file_as_bytes("res://src/dev/fixtures/house/robot.ldr")
	var first: int = robot.find(10) + 1
	# Latin-1 bytes in an author line after the title, as old files have them.
	var latin := PackedByteArray()
	latin.append_array(robot.slice(0, first))
	latin.append_array("0 Author: Jos".to_ascii_buffer())
	latin.append(0xE9)
	latin.append_array(" M".to_ascii_buffer())
	latin.append(0xFC)
	latin.append_array("ller\n".to_ascii_buffer())
	latin.append_array(robot.slice(first))
	var crlf := PackedByteArray([0xEF, 0xBB, 0xBF])
	crlf.append_array(robot.get_string_from_utf8().replace("\n", "\r\n").to_utf8_buffer())
	var open_end: PackedByteArray = robot.slice(0, robot.size() - 1)
	for case: Array in [["latin1", latin], ["bom_crlf", crlf], ["no_last_end", open_end]]:
		await _kept_case(str(case[0]), case[1])


func _kept_case(tag: String, raw: PackedByteArray) -> void:
	var path: String = "user://models/smalls12_%s.ldr" % tag
	var put := FileAccess.open(path, FileAccess.WRITE)
	put.store_buffer(raw)
	put.close()
	if not await _open_path(path):
		_check("%s: opened" % tag, false)
		return
	var kept: PackedByteArray = _store.get("_kept_bytes")
	_check("%s opened: the kept copy is the file's bytes (%d bytes kept, the file %d)" % [tag, kept.size(),
		raw.size()], typeof(_store.get("_kept_bytes")) == TYPE_PACKED_BYTE_ARRAY and kept == raw)
	var saved: String = ModelStore.saved_path(_bar.model_name())
	var one: Array = await _bar_save()
	var held: PackedByteArray = _store.get("_stored")
	_check("%s saved unedited: byte for byte %s, by the fast path %s, no second copy held (%d bytes)" % [tag,
		one[0] == raw, one[1], held.size()], one[0] == raw and one[1] and held.is_empty()
		and (_store.get("_kept_bytes") as PackedByteArray) == raw)
	_store.call("_write", ModelStore.autosave(), _store.title)
	held = _store.get("_stored")
	_check("%s autosaved: no copy held by it (%d bytes), the kept copy the file's" % [tag, held.size()],
		held.is_empty() and (_store.get("_kept_bytes") as PackedByteArray) == raw)
	var two: Array = await _bar_save()
	_check("%s saved again after the autosave: byte for byte %s, by the fast path %s" % [tag, two[0] == raw,
		two[1]], two[0] == raw and two[1])
	# An edit saved: kept as its new file. Undo, and the save is the file again.
	var world: BrickWorld = _store.world
	var brick: BrickWorld.Brick = null
	for one_brick: BrickWorld.Brick in world.bricks():
		brick = one_brick
		break
	if brick == null:
		_check("%s: a part to recolour" % tag, false)
		return
	var builder: Builder = _main.get("_builder")
	var depth: int = builder.history_depth()
	builder.paint_brick(brick.id, 4 if brick.color_code != 4 else 1)
	for _n: int in 4:
		await process_frame
	var edited: Array = await _bar_save()
	kept = _store.get("_kept_bytes")
	held = _store.get("_stored")
	_check("%s recoloured and saved: written by the save (fast path %s), the kept copy its bytes (%d), none held"
		% [tag, edited[1], kept.size()], not edited[1] and edited[0] != raw and kept == edited[0]
		and held.is_empty() and builder.history_depth() == depth + 1)
	builder.undo()
	for _n: int in 4:
		await process_frame
	var back: Array = await _bar_save()
	_check("%s undone and saved: written by the save, its kept copy that file's bytes (%d)" % [tag,
		(_store.get("_kept_bytes") as PackedByteArray).size()],
		not back[1] and (_store.get("_kept_bytes") as PackedByteArray) == back[0]
		and back[0] == FileAccess.get_file_as_bytes(saved))


func _open_path(path: String) -> bool:
	_main.call("clear_model")
	for _n: int in 4:
		await process_frame
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _settle()
	return placed > 0


## [the bytes saved, whether the fast path was taken]
func _bar_save() -> Array:
	var path: String = ModelStore.saved_path(_bar.model_name())
	var fast: bool = bool(_store.call("_kept_now", path, _bar.model_name()))
	var ok: bool = await _bar._on_save()
	for _n: int in 4:
		await process_frame
	if not ok:
		print("  not saved: %s" % _store.refused)
	return [FileAccess.get_file_as_bytes(path), fast]


func _settle() -> void:
	for _n: int in 4000:
		if not _store.laying and _store.awaited.is_empty():
			break
		await process_frame
	for _n: int in 6:
		await process_frame


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok   " if ok else "FAIL ", what])
	if not ok:
		_failures += 1
