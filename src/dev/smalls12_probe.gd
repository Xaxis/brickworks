## smalls12's file checks, each a few seconds and no window:
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
extends SceneTree

var _failures: int = 0

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
	_names()
	_old_lines()
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


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok   " if ok else "FAIL ", what])
	if not ok:
		_failures += 1
