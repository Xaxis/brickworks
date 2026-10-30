## A model's own named movements on real sets (docs/MOTIONS.md, unit 1):
## each defined over MCP, saved, opened again, played, played backwards and
## rendered once, through Grab's joints.
##
##   godot --path . --resolution 1400x900 --script src/dev/motions_probe.gd
##   ... -- OUT_DIR   (where the files go; shots/motions when not given)
##
##  1. 1484-1's doors, two gates and a mailbox: list_motions suggests
##     opening them, define_motion keeps that, and played they open and
##     backwards they close.
##  2. 8808-1's steering, left and right through its rack: both front arms
##     turn, one way and then the other.
##  3. 4096-1's crane: its boom lifts.
##  4. 8841-1's chassis: a driver, its steering wheel turned, and the rack it
##     drives follows.
##  5. 31070-1's windscreen meets the model at once: the stop is said, by
##     name and degree.
##  6. The file: a motion's lines come back from a .mpd byte for byte, and
##     from an .ldr and an .io; a door saved open opens no further; an edit
##     elsewhere keeps them; a part taken off is said by name; define is one
##     undo step; animate_model is a motion played once.
##  7. The observatory of the third MCP walk (tests/fixtures/mcpwalk3), with
##     the session's "Show it all", a copy of the back wall's tracks, made a
##     real sequence (unit 5): defined over MCP, its line saved and read
##     back byte for byte, played (the dome, then the telescope, then the
##     back wall), backwards in reverse order to where it was built,
##     rendered whole, a motion of it taken out and said by name with its
##     line kept, undone; the file's AFTER chain still plays; and the
##     picture of the back wall's panels is from the view that sees them.
extends SceneTree

const DOORS := "res://vendor/omr/files/1484-1.mpd"
const RACER := "res://vendor/omr/files/8808-1.mpd"
const CRANE := "res://vendor/omr/files/4096-1_Crane.mpd"
const CHASSIS := "res://vendor/omr/files/8841-1_Chassis.mpd"
const WINDSCREEN := "res://vendor/omr/files/31070-1.mpd"
const OBSERVATORY := "res://tests/fixtures/mcpwalk3/small-observatory.ldr"
const SHOW := "Show it all"
const SHOWS: Array = ["Open the dome panel", "Extend the telescope", "Open the back wall panels"]

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _player: MotionPlayer
var _out: String = ""
var _next: int = 0
var _windowed: bool = false


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://shots/motions")
	DirAccess.make_dir_recursive_absolute(_out)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_player = _main.get("_motions")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	_windowed = StudioRender.possible()
	if not _windowed:
		print("motions probe: drawn headless, so nothing is rendered (xvfb-run draws it)")
	Download.folder = _out
	(_main.get("_pose") as PosePanel).folder = _out
	await _doors()
	await _racer()
	await _crane()
	await _chassis()
	await _windscreen()
	await _ldr()
	await _assembly()
	await _observatory()
	print("")
	if _failures == 0:
		print("motions: defined over MCP, saved and opened again, played, reversed and rendered on "
			+ "five real sets; the lines come back byte for byte")
	else:
		print("motions: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- the sets --------------------------------------------------------------------


func _doors() -> void:
	print("── 1484-1: open the doors ──")
	if not await _open(DOORS):
		return
	var built: Dictionary = _poses()
	var listed: String = await _say("list_motions", {})
	_print(listed)
	_check("list_motions suggests opening the doors, with nothing kept yet",
		listed.contains("\"Open the doors\"") and listed.contains("no motions of its own yet"))
	_check("...and changes nothing", _off(built)[0] == 0 and _builder.history_depth() == 0)
	var said: String = await _say("define_motion", {"name": "Open the doors", "suggested": true})
	_print(said)
	_check("define_motion keeps the suggestion and plays it once to check", said.begins_with("Kept \"Open the doors\"")
		and said.contains("went from 0° to"))
	_check("...putting the model back (%d parts off)" % _off(built)[0], _off(built)[0] == 0)
	_check("...as one undo step", _builder.history_depth() == 1)
	var motion: Motions.Motion = _player.motions().named("Open the doors")
	var doors: Array = []
	for track: Motions.Track in motion.tracks if motion != null else []:
		doors.append(track.joint)
	await _round_trip("doors", "Open the doors", built)
	# Saved open, it opens no further: the file says where each door stood.
	await _say("play_motion", {"name": "Open the doors"})
	var open_at: Dictionary = _poses()
	var file: String = _out.path_join("doors_open.mpd")
	_write(file, _store.to_text("Doors open"))
	var lines: PackedStringArray = _motion_lines(FileAccess.get_file_as_string(file))
	_print("\n".join(lines))
	var at_open: bool = lines.size() > 1 and not lines[1].contains(" AT 0 ")
	_check("saved with the doors open, each track says where its door stood (AT)", at_open)
	if not await _open(file):
		return
	said = await _say("list_motions", {"suggest": false})
	_print(said)
	_check("...opened again, list_motions says the doors stand open", said.contains("it stands at")
		and not said.contains("it stands at 0° now"))
	said = await _say("play_motion", {"name": "Open the doors", "reverse": true})
	_print(said)
	_check("...and played backwards they close to where they were built: %d parts off"
		% _off_ids(built, open_at.keys())[0], _off_ids(built, open_at.keys(), 0.05)[0] == 0)
	said = await _say("play_motion", {"name": "Open the doors"})
	var reopened: Array = _off_ids(open_at, open_at.keys(), 0.05)
	_check("...and played forward they open as far as before, no further (%d parts off)" % reopened[0],
		reopened[0] == 0)
	# An edit elsewhere keeps them; the door's own part taken off is said.
	var other: int = 0
	var lead: int = (doors[0] as Motions.Joint).lead if not doors.is_empty() else 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not open_at.has(brick.id) and not _store.scenery.has(brick.id) and brick.id != lead:
			other = brick.id
			break
	_builder.remove_brick_id(other)
	said = await _say("list_motions", {"suggest": false})
	_check("a part taken off elsewhere leaves the motion as it was",
		said.contains("\"Open the doors\"") and not said.contains("is gone"))
	_builder.remove_brick_id(lead)
	said = await _say("list_motions", {"suggest": false})
	_print(said)
	_check("the door's own part taken off, the motion says its joint is gone, by name",
		said.contains("Open the doors: its joint is gone"))
	var text: String = _store.to_text("Doors")
	_check("...and its lines stay in the file (%d)" % _motion_lines(text).size(),
		_motion_lines(text).size() == lines.size())
	await _say("undo", {"steps": 2})
	said = await _say("list_motions", {"suggest": false})
	_check("undone, the part is back and the motion finds it again", not said.contains("is gone"))


func _racer() -> void:
	print("── 8808-1: steer left and right, through its rack ──")
	if not await _open(RACER):
		return
	var built: Dictionary = _poses()
	var keys: Array = [{"t": 0, "place": 0}, {"t": 1, "place": 90}, {"t": 3, "place": -90}, {"t": 4, "place": 0}]
	var said: String = await _say("define_motion", {"name": "Steer left and right", "tracks": [
		{"joint": "#80", "keys": keys}]})
	_print(said)
	_check("define_motion on the steering wheel (#80), played once", said.begins_with("Kept \"Steer left and right\""))
	_check("...putting the model back", _off(built)[0] == 0)
	# Both front arms turn, one way at 1 s and the other at 3 s.
	var played: MotionPlayer.Played = _player.play(_player.motions().named("Steer left and right"))
	var arms: Array = [50, 54]
	var turned: int = 0
	for id: int in arms:
		var at_1: Transform3D = played.frames[12].get(id, built[id])
		var at_3: Transform3D = played.frames[36].get(id, built[id])
		var one: float = _yaw(built[id], at_1)
		var other: float = _yaw(built[id], at_3)
		print("    arm #%d: %.1f° at 1 s, %.1f° at 3 s" % [id, one, other])
		if absf(one) > 3.0 and absf(other) > 3.0 and signf(one) != signf(other):
			turned += 1
	_check("both front arms steer one way and then the other through the rack (%d of 2)" % turned,
		turned == 2)
	await _round_trip("steering", "Steer left and right", built)


func _crane() -> void:
	print("── 4096-1: lift the crane's boom ──")
	if not await _open(CRANE):
		return
	var built: Dictionary = _poses()
	var listed: String = await _say("list_motions", {})
	_print(listed)
	_check("list_motions suggests lifting the boom", listed.contains("\"Lift the boom\""))
	var said: String = await _say("define_motion", {"name": "Lift the boom", "tracks": [
		{"joint": "#31", "keys": [{"t": 0, "place": 0}, {"t": 2, "place": 30}]}]})
	_print(said)
	_check("define_motion on the boom (#31)", said.begins_with("Kept \"Lift the boom\""))
	var before: float = _world.get_brick(31).transform.origin.y
	await _round_trip("crane", "Lift the boom", built)
	_check("...and what it moves rose when played, %.1f LDU on the mean" % _lifted, _lifted > 2.0)
	print("    (the boom's hinge stood at y=%.1f)" % before)


func _chassis() -> void:
	print("── 8841-1's chassis: a driver, the steering wheel turned, its rack following ──")
	if not await _open(CHASSIS):
		return
	var built: Dictionary = _poses()
	var moves: String = await _say("move_part", {})
	var wheel: int = 0
	for line: String in moves.split("\n"):
		if line.begins_with("  steering: #") or line.begins_with("  rack: #"):
			wheel = int(line.get_slice(": #", 1).get_slice(" ", 0))
			break
	_check("move_part names what turns the rack (#%d)" % wheel, wheel > 0)
	if wheel == 0:
		_print(moves)
		return
	var said: String = await _say("define_motion", {"name": "Turn the wheel", "driver": {
		"joint": "#%d" % wheel, "turns": 1, "seconds": 4}})
	_print(said)
	_check("define_motion with a driver, turned once in 4 s", said.begins_with("Kept \"Turn the wheel\""))
	var played: MotionPlayer.Played = _player.play(_player.motions().named("Turn the wheel"))
	var slid: float = 0.0
	for id: Variant in played.frames.back():
		if (built[id] as Transform3D).basis.is_equal_approx((played.frames.back()[id] as Transform3D).basis):
			slid = maxf(slid, (built[id] as Transform3D).origin.distance_to((played.frames.back()[id] as Transform3D).origin))
	_check("...what it drives moves with it: a part not turned slides %.1f LDU (the rack)" % slid, slid > 1.0)
	await _round_trip("chassis", "Turn the wheel", built)


func _windscreen() -> void:
	print("── 31070-1: a windscreen that meets the model ──")
	if not await _open(WINDSCREEN):
		return
	var built: Dictionary = _poses()
	var said: String = await _say("define_motion", {"name": "Raise the windscreen", "tracks": [
		{"joint": "#143", "keys": [{"t": 0, "place": 0}, {"t": 1, "place": 30}]}]})
	_print(said)
	_check("define_motion says where it stops, by name and degree, and on what",
		said.contains("#143 stops at 0° of the 30° asked, where the "))
	said = await _say("play_motion", {"name": "Raise the windscreen"})
	_print(said)
	_check("play_motion says it too, and nothing moved", said.contains("stops at 0°")
		and said.contains("Nothing moved.") and _off(built)[0] == 0)
	said = await _say("list_motions", {"suggest": false})
	_check("list_motions keeps what it was last found to do", said.contains("Last played: #143 stops at 0°"))
	# animate_model is a motion defined and played once: its keys on a part.
	if _windowed:
		said = _text(await _finished(await _rpc("tools/call", {"name": "animate_model", "arguments":
			{"keys": [{"t": 0, "angles": {"#143": 0}}, {"t": 1, "angles": {"#143": 30}}]}})))
		_print(said)
		_check("animate_model, as a motion played once, says where it stopped",
			said.contains("#143 stops at 0° of the 30° asked"))
		_check("...and the model stands as it was built", _off(built)[0] == 0)
		said = _text(await _finished(await _rpc("tools/call", {"name": "animate_model", "arguments":
			{"turntable": true}})))
		_print(said)
		_check("animate_model with only the model turned round still renders it",
			said.contains(": 12 frames, 12 a second") and said.contains(".webp"))


## A small model of plain parts in an .ldr (no sub-models): a door on a
## hinge brick, its motion saved and read back.
func _ldr() -> void:
	print("── an .ldr of its own, and an .io ──")
	var file: String = _out.path_join("hinge.ldr")
	_write(file, "0 Hinge\n0 Name: hinge.ldr\n0 Author: Brickworks\n\n"
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
		+ "1 71 0 -24 0 1 0 0 0 1 0 0 0 1 3937.dat\n"
		+ "1 71 0 -24 0 1 0 0 0 1 0 0 0 1 3938.dat\n"
		+ "1 1 0 -32 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
	if not await _open(file):
		return
	var top: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3938":
			top = brick.id
	var said: String = await _say("define_motion", {"name": "Swing the flap", "tracks": [
		{"joint": "#%d" % top, "keys": [{"t": 0, "place": 0}, {"t": 1, "place": 20, "how": "linear"}]}]})
	_print(said)
	_check("a motion on a plain .ldr's hinge", said.begins_with("Kept \"Swing the flap\""))
	# The autosave and what a shared link is written from carry it too. A
	# probe's store keeps none unless it asks (main), in its own data folder.
	_store.keeps = true
	_store.touch()
	var kept: String = _store.write_now()
	_store.keeps = false
	await _frames(5)
	var saved: String = FileAccess.get_file_as_string(ModelStore.autosave())
	_check("the autosave carries its lines (%d) (%s)" % [_motion_lines(saved).size(), kept.get_file()],
		_motion_lines(saved).size() == 4)
	var shared: String = await _store.text_for_file("Hinge", "Writing it for its link…")
	_check("...and so does the text a shared link is written from (%d)" % _motion_lines(shared).size(),
		_motion_lines(shared).size() == 4)
	var text: String = _store.to_text("Hinge")
	var lines: PackedStringArray = _motion_lines(text)
	_check("its .ldr has no FILE lines and carries the motion (%d lines)" % lines.size(),
		not text.contains("0 FILE") and lines.size() == 4)
	_write(file, text)
	if not await _open(file):
		return
	_check("...opened again, its lines come back the same", _motion_lines(_store.to_text("Hinge")) == lines)
	# Through Studio's .io as the app writes and reads it.
	var bytes: PackedByteArray = StudioIo.pack(_store.to_text("Hinge"), PackedByteArray(), 4)
	var read: Dictionary = StudioIo.read(bytes)
	_check("...and through an .io, written and read back", _motion_lines(str(read.get("text", ""))) == lines)
	_store.open_text(str(read["text"]), "hinge")
	await _frames(10)
	_check("...which opens with its motion", _player.motions().named("Swing the flap") != null)
	# One step to undo, and back.
	var depth: int = _builder.history_depth()
	await _say("define_motion", {"name": "Swing back", "tracks": [{"joint": "#%d" % _lead("3938"), "keys": [
		{"t": 0, "place": 20}, {"t": 1, "place": 0}]}], "after": "Swing the flap"})
	_check("a second motion, after the first, is one undo step", _builder.history_depth() == depth + 1
		and _player.motions().sequence("Swing the flap").size() == 2)
	await _say("undo", {})
	_check("...undone, it is gone", _player.motions().named("Swing back") == null
		and _player.motions().named("Swing the flap") != null)
	await _say("undo", {"redo": true})
	_check("...redone, it is back", _player.motions().named("Swing back") != null)
	said = await _say("play_motion", {"name": "Swing the flap", "sequence": true})
	_print(said)
	_check("a sequence plays in order: %s" % said.get_slice("\n", 0).left(80),
		said.find("Swing the flap") < said.find("Swing back") and said.find("Swing back") > 0)


## A flap that is a sub-assembly of its own in an .mpd: a motion on a part
## of it is kept by the sub-assembly's name, which comes back with the file.
func _assembly() -> void:
	print("── a sub-assembly's name as the joint's ref ──")
	var file: String = _out.path_join("flap.mpd")
	_write(file, "0 FILE main.ldr\n0 Main\n0 Name: main.ldr\n0 Author: Brickworks\n\n"
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
		+ "1 71 0 -24 0 1 0 0 0 1 0 0 0 1 3937.dat\n"
		+ "1 1 0 0 0 1 0 0 0 1 0 0 0 1 flap.ldr\n0 NOFILE\n"
		+ "0 FILE flap.ldr\n0 Flap\n0 Name: flap.ldr\n0 Author: Brickworks\n\n"
		+ "1 71 0 -24 0 1 0 0 0 1 0 0 0 1 3938.dat\n"
		+ "1 1 0 -32 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 NOFILE\n")
	if not await _open(file):
		return
	var said: String = await _say("define_motion", {"name": "Lift the flap", "tracks": [
		{"joint": "#%d" % _lead("3938"), "keys": [{"t": 0, "place": 0}, {"t": 1, "place": 20}]}]})
	_print(said)
	var lines: PackedStringArray = _motion_lines(_store.to_text("Flap"))
	_print("\n".join(lines))
	_check("a part of a sub-assembly that moves whole is kept by the sub-assembly's name",
		lines.size() == 4 and lines[1].contains("JOINT ASSEMBLY \""))
	# Saved and opened again.
	var text: String = _store.to_text("Flap")
	_write(file, text)
	if not await _open(file):
		return
	_check("...opened again, its lines come back byte for byte", _motion_lines(_store.to_text("Flap")) == lines)
	said = await _say("play_motion", {"name": "Lift the flap"})
	_print(said)
	_check("...and the name finds the flap again, which plays", said.contains("went from 0° to 20°")
		and said.contains("One step"))


# -- a sequence: the observatory's "Show it all" -----------------------------------


func _observatory() -> void:
	print("── the observatory: Show it all, a sequence ──")
	if not await _open(OBSERVATORY):
		return
	var built: Dictionary = _poses()
	var had: PackedStringArray = _motion_lines(_store.to_text("Observatory"))
	var said: String = await _say("define_motion", {"name": SHOW, "sequence": SHOWS})
	_print(said)
	_check("define_motion makes the session's \"Show it all\" a sequence of the three",
		said.begins_with("Changed \"Show it all\" in the model, a sequence of 3"))
	_check("...checked once, each from where the one before left the model: the telescope out clear",
		said.contains("\"Extend the telescope\":") and said.contains("slid") and not said.contains("stops at"))
	_check("...the model put back (%d parts off), one undo step" % _off(built)[0],
		_off(built)[0] == 0 and _builder.history_depth() == 1)
	var refused: String = await _say("define_motion", {"name": "Loop", "sequence": ["Loop"]})
	_check("a sequence that plays itself is refused: %s" % refused, refused.contains("cannot play itself"))
	refused = await _say("define_motion", {"name": "Twice", "sequence": ["Open the dome", "Nothing"]})
	_check("...and one naming a motion the model lacks: %s" % refused.left(60),
		refused.begins_with("No motion \"Open the dome\""))
	var lines: PackedStringArray = _motion_lines(_store.to_text("Observatory"))
	_print("\n".join(lines))
	var line: String = '0 !BRICKWORKS MOTION "Show it all" SEQUENCE "Open the dome panel" "Extend the telescope" "Open the back wall panels"'
	_check("its line is the sequence by name, in order, in place of the copied tracks (%d lines, %d before)"
		% [lines.size(), had.size()], lines.has(line) and not "\n".join(lines).contains('MOTION_TRACK "Show it all"')
		and lines.size() == had.size() - 6)
	_check("...and the other motions' lines, AFTER and all, are as they were",
		Array(lines).filter(func(one: String) -> bool: return not one.contains('"Show it all"')) \
		== Array(had).filter(func(one: String) -> bool: return not one.contains('"Show it all"')))
	var file: String = _out.path_join("observatory show.ldr")
	_write(file, _store.to_text("Observatory"))
	if not await _open(file):
		return
	var again: PackedStringArray = _motion_lines(_store.to_text("Observatory"))
	_check("saved and opened again, its %d lines come back byte for byte" % again.size(), again == lines)
	var listed: String = await _say("list_motions", {"suggest": false})
	_print(listed)
	_check("list_motions says it is a sequence, and of what",
		listed.contains("\"Show it all\", 8 s, a sequence: \"Open the dome panel\", then \"Extend the telescope\", then \"Open the back wall panels\""))
	built = _poses()
	var depth: int = _builder.history_depth()
	var answer: Dictionary = await _rpc("tools/call", {"name": "play_motion", "arguments": {"name": SHOW}})
	said = _text(answer)
	_print(said)
	var dome: int = _player.motions().named("Open the dome panel").tracks[0].joint.lead
	var doors: Array = _player.motions().named("Open the back wall panels").tracks.map(
		func(track: Motions.Track) -> int: return track.joint.lead)
	var order: Array = [said.find("Played \"Open the dome panel\""), said.find("Played \"Extend the telescope\""),
		said.find("Played \"Open the back wall panels\"")]
	_check("play_motion plays the three in order: %s" % str(order), order[0] >= 0 and order[0] < order[1]
		and order[1] < order[2])
	var moved: Array = _off(built)
	var turned: float = rad_to_deg((built[dome] as Transform3D).basis.get_rotation_quaternion().angle_to(
		_world.get_brick(dome).transform.basis.get_rotation_quaternion()))
	_check("...the dome open %.0f°, the telescope out, the panels open: %d parts moved, one step" % [turned,
		moved[0]], absf(turned - 110.0) < 2.0 and moved[0] > 20 and _builder.history_depth() == depth + 1
		and doors.all(func(id: int) -> bool: return not (built[id] as Transform3D).is_equal_approx(
			_world.get_brick(id).transform)))
	if _windowed:
		var sheet: Image = _image_of(answer)
		if sheet != null:
			sheet.save_png(_out.path_join("observatory_show_played.png"))
		_check("...with a picture, its view said (%s)" % said.get_slice("The picture:", 1).strip_edges().left(120),
			sheet != null and said.contains("view=\""))
	said = await _say("play_motion", {"name": SHOW, "reverse": true})
	_print(said)
	order = [said.find("Played \"Open the back wall panels\" backwards"),
		said.find("Played \"Extend the telescope\" backwards"), said.find("Played \"Open the dome panel\" backwards")]
	var back: Array = _off_tolerant(built)
	_check("backwards, in reverse order (%s), to where it was built: %d parts off (%.3f LDU, %.2f°)" % [
		str(order), back[0], back[1], back[2]], order[0] >= 0 and order[0] < order[1] and order[1] < order[2]
		and int(back[0]) == 0)
	# The back wall's panels, behind the dome: from the front corner they
	# are hardly seen, so the picture is from where they are.
	var walls: MotionPlayer.Played = _player.play(_player.motions().named("Open the back wall panels"))
	var seen: Dictionary = MotionRender.seen_from(_world, _main.get("_library"), _builder.lattice, walls.frames)
	var view: String = MotionRender.best_view(seen)
	_print(str(seen))
	_check("the back wall's panels are seen best from %s (%d%%), not the front corner (%d%%)" % [view,
		roundi(float(seen.get(view, 0.0)) * 100.0), roundi(float(seen["hero"]) * 100.0)], view != "hero"
		and float(seen[view]) > float(seen["hero"]) + MotionRender.BETTER_BY)
	var domed: MotionPlayer.Played = _player.play(_player.motions().named("Open the dome panel"))
	seen = MotionRender.seen_from(_world, _main.get("_library"), _builder.lattice, domed.frames)
	_print(str(seen))
	_check("...and the dome panel, high on top, from wherever sees it: %s (%d%%)" % [
		MotionRender.best_view(seen), roundi(float(seen[MotionRender.best_view(seen)]) * 100.0)],
		float(seen[MotionRender.best_view(seen)]) > 0.5)
	if _windowed:
		answer = await _rpc("tools/call", {"name": "play_motion", "arguments": {"name": "Open the back wall panels"}})
		said = _text(answer)
		_print(said)
		var sheet: Image = _image_of(answer)
		if sheet != null:
			sheet.save_png(_out.path_join("observatory_back_wall_played.png"))
		_check("play_motion's picture of the back wall's panels says its view: %s" % said.get_slice(
			"The picture:", 1).strip_edges(), said.contains("view=\"%s\"" % view))
		await _say("undo", {})
		var rendered: Dictionary = await _finished(await _rpc("tools/call", {"name": "render_motion",
			"arguments": {"name": SHOW}}))
		said = _text(rendered)
		_print(said)
		var panel: PosePanel = _main.get("_pose")
		var frames: int = 0
		for one: String in SHOWS:
			frames += roundi(_player.motions().named(one).length() * 12.0) + 1
		# Named after the motion, "Show it all 2.webp" when an earlier run's is
		# there: the app never writes over a render (a second run in one
		# checkout failed here, 2026-10-30).
		var named := RegEx.create_from_string("Show it all( \\d+)?\\.webp$")
		_check("render_motion renders it whole: %s, %s" % [said.get_slice(":", 0), str(panel._last.get("name", ""))],
			said.contains("Rendered %d frames" % frames) and named.search(str(panel._last.get("name", ""))) != null
			and int(_off_tolerant(built)[0]) == 0)
	# A motion of it taken out is said by name, and its line is kept.
	await _say("define_motion", {"name": "Extend the telescope", "remove": true})
	listed = await _say("list_motions", {"suggest": false})
	_check("a motion of it taken out is said by name: %s" % listed.get_slice("Show it all\": ", 1).get_slice("\n", 0),
		listed.contains("\"Show it all\": the model has no motion \"Extend the telescope\""))
	_check("...and its line is kept as it was", _motion_lines(_store.to_text("Observatory")).has(line))
	said = await _say("play_motion", {"name": SHOW})
	_print(said)
	_check("...played, the other two play and the gone one is passed over", said.contains("passed over")
		and said.contains("Played \"Open the dome panel\"") and said.contains("Played \"Open the back wall panels\"")
		and not said.contains("Played \"Extend the telescope\""))
	await _say("undo", {})
	await _say("undo", {})
	_check("...undone, the telescope's motion is back and the model as built (%d off)" % _off_tolerant(built)[0],
		_player.motions().named("Extend the telescope") != null and int(_off_tolerant(built)[0]) == 0)
	# The file's AFTER chain still plays: the telescope after the dome.
	said = await _say("play_motion", {"name": "Extend the telescope", "sequence": true})
	_print(said)
	_check("the file's AFTER chain plays as before: the dome, then the telescope, not the sequence",
		said.find("Played \"Open the dome panel\"") >= 0 and said.find("Played \"Open the dome panel\"")
		< said.find("Played \"Extend the telescope\"") and not said.contains("back wall"))
	await _say("undo", {})


# -- a motion saved, opened, played, reversed and rendered -----------------------


var _lifted: float = 0.0


func _round_trip(label: String, name: String, built: Dictionary) -> void:
	var first: String = _store.to_text(label)
	var lines: PackedStringArray = _motion_lines(first)
	_print("\n".join(lines))
	var file: String = _out.path_join(label + ".mpd")
	_write(file, first)
	if not await _open(file):
		return
	var again: PackedStringArray = _motion_lines(_store.to_text(label))
	_check("%s: saved as .mpd and opened again, its %d motion lines come back byte for byte"
		% [label, lines.size()], not lines.is_empty() and again == lines)
	var listed: String = await _say("list_motions", {"suggest": false})
	_check("...list_motions finds its joints again", listed.contains("\"%s\"" % name)
		and not listed.contains("is gone"))
	var at: Dictionary = _poses()
	var answer: Dictionary = await _rpc("tools/call", {"name": "play_motion", "arguments": {"name": name}})
	var said: String = _text(answer)
	_print(said)
	var moved: Array = _off(at)
	_check("...played, it moves %d parts, one undo step (or ends where it began)" % moved[0],
		said.begins_with("Played \"%s\"" % name) and (said.contains("One step: undo takes it back")
		if moved[0] > 0 else said.contains("It ends where it began")))
	# How far what moved rose, on the mean: a boom lifted rises.
	var rose: float = 0.0
	var count: int = 0
	for key: Variant in at:
		var brick: BrickWorld.Brick = _world.get_brick(int(key))
		if brick != null and not (at[key] as Transform3D).is_equal_approx(brick.transform):
			rose += brick.transform.origin.y - (at[key] as Transform3D).origin.y
			count += 1
	_lifted = rose / maxf(float(count), 1.0)
	if _windowed:
		var sheet: Image = _image_of(answer)
		if sheet != null:
			sheet.save_png(_out.path_join(label + "_played.png"))
		_check("...with a picture of its frames (%s)" % (str(sheet.get_size()) if sheet != null else "none"),
			sheet != null)
	said = await _say("play_motion", {"name": name, "reverse": true})
	_print(said)
	var back: Array = _off_tolerant(at)
	_check("...played backwards, it comes back where it began (%d parts off; %.3f LDU and %.3f° at most)"
		% back, int(back[0]) == 0)
	if not _windowed:
		return
	var rendered: Dictionary = await _finished(await _rpc("tools/call", {"name": "render_motion",
		"arguments": {"name": name}}))
	said = _text(rendered)
	_print(said)
	var webp: String = _out.path_join(str((_main.get("_pose") as PosePanel)._last.get("name", "")))
	var mp4: String = webp.get_basename() + ".mp4"
	_check("...rendered as a job, a WebP and an MP4, the model as it was", said.contains("Rendered ")
		and FileAccess.file_exists(webp) and (FileAccess.file_exists(mp4) or RenderOutput.ffmpeg().is_empty())
		and int(_off_tolerant(at)[0]) == 0)
	var drawn_sheet: Image = _image_of(rendered)
	if drawn_sheet != null:
		drawn_sheet.save_png(_out.path_join(label + "_rendered.png"))
	# Its frames show it moving: the first against the one at its middle.
	var frames: String = webp.get_basename()
	var drawn: int = 0
	for kept: String in DirAccess.get_files_at(frames):
		if kept.begins_with("frame_") and kept.ends_with(".png"):
			drawn += 1
	var opening: Image = Image.load_from_file(frames.path_join("frame_0001.png")) if drawn > 0 else null
	var changed: int = 0
	for n: int in [drawn / 4, drawn / 2, drawn]:
		var later: String = frames.path_join("frame_%04d.png" % maxi(n, 1))
		if FileAccess.file_exists(later):
			changed = maxi(changed, _changed(opening, Image.load_from_file(later)))
	_check("...its %d frames show it moving: %d pixels differ from its first" % [drawn, changed],
		drawn > 2 and changed > 200)


# -- helpers -------------------------------------------------------------------------


static func _motion_lines(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with(Motions.META):
			out.append(line.strip_edges())
	return out


func _lead(part: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			return brick.id
	return 0


## How far [param to] has turned from [param from] about the upright, degrees.
static func _yaw(from: Transform3D, to: Transform3D) -> float:
	var turned: Basis = to.basis.orthonormalized() * from.basis.orthonormalized().inverse()
	var x: Vector3 = turned * Vector3.RIGHT
	return rad_to_deg(atan2(-x.z, x.x))


func _changed(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return 0
	var count: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.1:
				count += 1
	return count


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _open(path: String) -> bool:
	var real: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(real):
		print("    (no %s: tools/omr.py fetch brings the sets)" % path)
		_failures += 1
		return false
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", real)
	for _n: int in 600:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(5)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null and playback.is_playing():
		playback.stop()
	_builder.forget_history()
	await _frames(20)
	return _world.brick_count() > 0


func _poses() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


## [parts not standing exactly as in [param built], the furthest off in LDU].
func _off(built: Dictionary) -> Array:
	return _off_ids(built, [], 0.0)


func _off_tolerant(built: Dictionary) -> Array:
	return _off_ids(built, [], 0.05)


## As [method _off], over [param ids] only (all when empty), within
## [param slack] LDU and a tenth of a degree: [count, the most LDU off, the
## most degrees turned].
func _off_ids(built: Dictionary, ids: Array, slack: float = 0.0) -> Array:
	var count: int = 0
	var most: float = 0.0
	var turned_most: float = 0.0
	var each: Array = ids if not ids.is_empty() else built.keys()
	for key: Variant in each:
		var brick: BrickWorld.Brick = _world.get_brick(int(key))
		var was: Variant = built.get(key)
		if brick == null or was == null:
			continue
		var off: float = (was as Transform3D).origin.distance_to(brick.transform.origin)
		var a: Basis = (was as Transform3D).basis.orthonormalized()
		var b: Basis = brick.transform.basis.orthonormalized()
		# The most any axis moved, as an angle.
		var chord: float = maxf(a.x.distance_to(b.x), maxf(a.y.distance_to(b.y), a.z.distance_to(b.z)))
		var turned: float = rad_to_deg(2.0 * asin(clampf(chord * 0.5, 0.0, 1.0)))
		var same: bool = (was as Transform3D).is_equal_approx(brick.transform) \
			or (slack > 0.0 and off <= slack and turned <= 0.1)
		if not same:
			count += 1
			most = maxf(most, off)
		turned_most = maxf(turned_most, turned if not (was as Transform3D).is_equal_approx(brick.transform) else 0.0)
	return [count, most, turned_most]


func _say(tool: String, arguments: Dictionary) -> String:
	return _text(await _rpc("tools/call", {"name": tool, "arguments": arguments}))


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


static func _image_of(result: Dictionary) -> Image:
	for block: Dictionary in result.get("content", []):
		if str(block.get("type", "")) == "image":
			var image := Image.new()
			if image.load_png_from_buffer(Marshalls.base64_to_raw(str(block.get("data", "")))) == OK:
				return image
	return null


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


## [param result], or when it is a job, the job's answer once it ends.
func _finished(result: Dictionary) -> Dictionary:
	var found: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(_text(result))
	if found == null:
		return result
	for _n: int in 120:
		var polled: Dictionary = await _rpc("tools/call", {"name": "job", "arguments":
			{"id": int(found.get_string(1))}})
		if not _text(polled).contains(" is still going"):
			return polled
	return {"content": [{"type": "text", "text": "the job never ended"}]}


func _print(said: String) -> void:
	print("    " + said.replace("\n", "\n    "))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
