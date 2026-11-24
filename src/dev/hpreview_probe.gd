## hpreview: an independent review of hubprogram's save path and its run,
## kept (hpfix) with its findings' checks made checks:
##   tools/probe.sh hpreview_probe -- only=files     (both trees: merge base and hubprogram)
##   tools/probe.sh hpreview_probe -- only=history   (undo, redo, copy, paste, Ctrl+S, New)
##   tools/probe.sh hpreview_probe -- only=plays     (long runs' frames, refusals, words, Stop, close)
##   tools/probe.sh hpreview_probe -- only=mcp
##   tools/probe.sh hpreview_probe -- only=extra     (sub-models' app lines, any case)
##   tools/probe.sh hpreview_probe -- only=again     (Ctrl+S and another model while typing, undo)
##   tools/probe.sh hpreview_probe -- only=mcpopen   (a session's open_model while typing)
##   tools/probe.sh hpreview_phone_probe [-- shots=DIR]   (430 x 932: Run and Stop by finger)
## No only= runs files, history, plays, mcp, extra, again and mcpopen. Names
## no class the merge base lacks, so it compiles on both trees. What the
## writer does to a file as live does too, not this feature's, is said
## "known" with why, and fails nothing (KNOWN).
##
##   godot --path . --resolution 1400x900 --script src/dev/hpreview_probe.gd
extends SceneTree

const FIX_PATH := "res://src/dev/fixtures/hubprogram/arm_program.ldr"
## The writer's ways with a file that live has too, by the file's case: said,
## and failing nothing here. F3 (a sub-model's app line after its Author
## went above its Name) was fixed by mergekeep (LdrModel.NAMED_HERE), and its
## cases fail again.
const KNOWN := {
	"twosubs": "a sub-model placed twice is written with its copies' numbers (COPY), as live writes it",
	"metas": "PAGE_SETUP written where the writer keeps it, as live does",
	"bom": "the byte-order mark is not written back, as live",
	"nonl": "a line end is written at the file's end, as live",
	"body": "an app line in the model's body is written in its head (live drops it)",
}
const MODELS := "user://models/"
const META := "0 !BRICKWORKS PROGRAM "
const BAR := "repeat 3\n  to 90° at 50%\n  wait 1 s\n  to 0° at 50%"
const SPIKE_STANDS := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))

var _failures: int = 0
var _main: Node
var _shell: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _verbs: Node
var _panel: Node
var _socket: Object
var _rpc_id: int = 0
var _new: bool = false
var _shots: String = "user://"


func _initialize() -> void:
	_run.call_deferred()


## The sections run when the command line names none: "" for every one but
## the phone's (hpreview_phone_probe's, in a phone's window).
func _sections() -> String:
	return ""


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


## [method _check], but for the file case [param case] the writer treats as
## live does (KNOWN): said with why, failing nothing.
func _check_known(case: String, what: String, ok: bool) -> bool:
	if not ok and KNOWN.has(case):
		print("  known %s (%s)" % [what, KNOWN[case]])
		return false
	return _check(what, ok)


func _note(what: String) -> void:
	print("  note  %s" % what)


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(2400.0).timeout.connect(func() -> void:
		print("hpreview_probe: FAILED, not finished in 2400 s")
		quit(1))
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var size: Vector2i = DisplayServer.window_get_size()
	if size.x < 1200:
		Phone._on = 1
		Phone._wide = size.x >= 600
	DirAccess.make_dir_recursive_absolute(MODELS)
	var only: String = _sections()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.trim_prefix("only=")
		if arg.begins_with("shots="):
			_shots = arg.trim_prefix("shots=").trim_suffix("/") + "/"
	await _start()
	process_frame.connect(_on_process_frame)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	_new = _world.get("program") != null
	print("hpreview_probe: %dx%d, %s build" % [size.x, size.y, "hubprogram" if _new else "merge-base"])
	if only.is_empty() or ("," + only + ",").contains(",files,"):
		await _files()
	if _new and (only.is_empty() or ("," + only + ",").contains(",history,")):
		await _history()
	if _new and (only.is_empty() or ("," + only + ",").contains(",plays,")):
		await _plays()
	if _new and (only.is_empty() or ("," + only + ",").contains(",mcp,")):
		await _mcp()
	if _new and ("," + only + ",").contains(",phone,"):
		await _phone()
	if only.is_empty() or ("," + only + ",").contains(",extra,"):
		await _extra()
		await _typo()
	if _new and (only.is_empty() or ("," + only + ",").contains(",again,")):
		await _again()
	if _new and (only.is_empty() or ("," + only + ",").contains(",mcpopen,")):
		await _mcpopen()
	print("\nhpreview_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


## Sub-model lines of other app features, after Author: is the move above
## Name the program's own, or every sub-model meta's?
func _extra() -> void:
	print("\nextra: a sub-model's own app line after its Author, unedited save")
	var fix: String = FileAccess.get_file_as_string(FIX_PATH)
	var line: String = ""
	for one: String in fix.split("\n"):
		if one.begins_with(META):
			line = one
	var without: String = fix.replace(line + "\n", "")
	var anchor: String = "0 FILE arm.ldr\n0 Arm\n0 Name: arm.ldr\n0 Author: Brickworks\n"
	for case: Array in [["sub_program", META + JSON.stringify({"text": "turn 10° at 20%"})],
			["sub_view", "0 !BRICKWORKS VIEW {\"distance\":400,\"focus\":[0,0,0],\"name\":\"arm view\",\"pitch\":-25,\"yaw\":30}"],
			["sub_light", "0 !BRICKWORKS LIGHT {\"aim\":[0,1,0],\"at\":[0,-50,0],\"colour\":\"#00ff00\",\"kind\":\"point\",\"shadows\":true,\"size\":4,\"strength\":1}"],
			["sub_view_lower", "0 !BrickWorks view {\"distance\":400,\"focus\":[0,0,0],\"name\":\"arm view\",\"pitch\":-25,\"yaw\":30}"]]:
		var text: String = _insert_after(without, anchor, str(case[1]))
		var file: String = "hpr_%s.ldr" % case[0]
		_write(MODELS + file, text)
		_main.call("clear_model")
		await _frames(6)
		await _open(MODELS + file)
		var saved: String = await _save(file)
		var at_before: int = Array(text.split("\n")).find(str(case[1]))
		var at_after: int = Array(saved.split("\n")).find(str(case[1]))
		# F4: a lower-case one was dropped from every save.
		_check("%s: the sub-model's line kept as written (the line at %d, then %d)" % [case[0], at_before,
			at_after], at_after >= 0)
		_check_known(str(case[0]), "%s: unedited save byte for byte (%s; the line at %d, then %d)" % [case[0],
			"same" if saved == text else _first_difference(text, saved), at_before, at_after], saved == text)


## A person's own slip, saved and reopened: named as what it is, a line that
## does not run (F8: it was "words this build cannot run").
func _typo() -> void:
	print("\nextra: a person's own typo, reopened")
	var fix: String = FileAccess.get_file_as_string(FIX_PATH)
	var line: String = ""
	for one: String in fix.split("\n"):
		if one.begins_with(META):
			line = one
	_write(MODELS + "hpr_typo.ldr", fix.replace(line, META + JSON.stringify({"text": "to 90° at 150%"})))
	_main.call("clear_model")
	await _frames(6)
	await _open(MODELS + "hpr_typo.ldr")
	var note: String = ModelBar.unshown_words(_store) if _new else ""
	_check("the open names it a line that does not run (%s)" % note.strip_edges().left(160),
		not _new or (note.contains("does not run as written (Line 1: a speed is 100% at most")
		and not note.contains("this build cannot run")))


## A session's open_model while the person types in the program box: where
## do the words go when the box is left?
func _mcpopen() -> void:
	print("\nmcpopen: words typed for model A, the session opens model B, the box left")
	var fix: String = FileAccess.get_file_as_string(FIX_PATH)
	_write(MODELS + "hpr_a.ldr", fix)
	_write(MODELS + "hpr_b.ldr", fix.replace("repeat 3", "repeat 2"))
	_main.call("clear_model")
	await _frames(6)
	await _open(MODELS + "hpr_a.ldr")
	_shell.call("run", "simulate")
	await _settled()
	var box: TextEdit = (_panel.call("controls_by_name") as Dictionary).get("simulate_program")
	box.grab_focus()
	await _frames(4)
	box.select_all()
	await _type_text("to 30° at 20%")
	# The words typed are A's at once, and work not saved (F2): a session's
	# open asks first, as for any change.
	_check("typed: A's program is the words in the box (%s), work not saved (%s)" % [
		_program_now().left(30).c_escape(), _store.has_unsaved_work()],
		_program_now() == "to 30° at 20%" and bool(_store.has_unsaved_work()))
	var said: Array = await _say_all("open_model", {"name": "hpr_b.ldr"})
	await _settled()
	_check("open_model refused with A's words not saved (%s)" % str(said[0]).get_slice("\n", 0).left(160),
		str(said[0]).begins_with("Not opened") and _program_now() == "to 30° at 20%")
	said = await _say_all("open_model", {"name": "hpr_b.ldr", "discard_changes": true})
	await _settled()
	print("    open_model, discard_changes: %s" % str(said[0]).get_slice("\n", 0).left(200))
	print("    B open: its program %s; box %s; focus %s; panel visible %s" % [_program_now().left(30).c_escape(),
		box.text.left(30).c_escape(), box.has_focus(), _panel.visible])
	_check("B open, the box still in focus: it shows B's program (%s)" % box.text.left(30).c_escape(),
		box.text.begins_with("repeat 2"))
	box.release_focus()
	await _frames(6)
	_check("the box left: B's program is its own (%s), not A's words" % _program_now().left(30).c_escape(),
		_program_now().begins_with("repeat 2"))
	var saved: String = await _save("hpr_b.ldr")
	var lines: Array = _programish(saved)
	_check("B saved with its own program (%s)" % _said(lines), lines.size() == 1
		and str(lines[0][1]).contains("repeat 2"))
	var a_file: String = FileAccess.get_file_as_string(MODELS + "hpr_a.ldr")
	_check("A's file as it was: its changes discarded, as asked", a_file == fix)


## The history checks headless clicks could not make: Ctrl+S with the box in
## focus, Stop, and undo after a kept Clear.
func _again() -> void:
	print("\nagain: Ctrl+S with words in the box, Stop, undo after Clear")
	var fix: String = _named(FileAccess.get_file_as_string(FIX_PATH), "hpr_ctrls")
	_write(MODELS + "hpr_ctrls.ldr", fix)
	_main.call("clear_model")
	await _frames(6)
	await _open(MODELS + "hpr_ctrls.ldr")
	_shell.call("run", "simulate")
	await _settled()
	var named: Dictionary = _panel.call("controls_by_name")
	var box: TextEdit = named.get("simulate_program")
	var run: Button = named.get("simulate_run")
	box.grab_focus()
	await _frames(4)
	box.select_all()
	await _type_text("to 30° at 20%")
	print("    box: %s, focus %s; model's program %s" % [box.text.c_escape(), box.has_focus(),
		_program_now().left(30).c_escape()])
	_check("the words in the box are work not saved (has_unsaved_work %s)" % _store.has_unsaved_work(),
		bool(_store.has_unsaved_work()))
	await _key(KEY_S, true)
	await _settled()
	var after: String = FileAccess.get_file_as_string(MODELS + "hpr_ctrls.ldr")
	var said: Array = _programish(after)
	_check("Ctrl+S with the box in focus writes the words in the box (%s; model's %s; focus %s)" % [
		_said(said), _program_now().left(30).c_escape(), box.has_focus()],
		said.size() == 1 and str(said[0][1]).contains("30° at 20%"))
	_check("...and nothing is left unsaved (%s), no dialog asking (%s)" % [_store.has_unsaved_work(),
		", ".join(_asking())], not bool(_store.has_unsaved_work()) and _asking().is_empty())
	# Typed again, unsaved, then another model opened in its place: the
	# words were this one's, dropped with it; never the other's.
	await _type_text(" ")
	await _frames(4)
	# Opened another model with the words still in the box, never left.
	_write(MODELS + "hpr_other.ldr", fix.replace(BAR.json_escape() if false else "repeat 3", "repeat 2"))
	_main.call("_open", MODELS + "hpr_other.ldr")
	await _settled()
	_note("another model opened with the box in focus: its program %s; the box %s; focus %s" % [
		_program_now().left(30).c_escape(), box.text.left(30).c_escape(), box.has_focus()])
	_check("another model opened with the box in focus: the box shows its program (%s)" % box.text.left(30).c_escape(),
		box.text.begins_with("repeat 2"))
	box.release_focus()
	await _frames(6)
	_check("...the box left: the other model's program is its own, not the words typed for the first (%s)" % (
		_program_now().left(40).c_escape()), _program_now().begins_with("repeat 2"))
	var first_again: String = FileAccess.get_file_as_string(MODELS + "hpr_ctrls.ldr")
	var first_lines: Array = _programish(first_again)
	_check("the first model's file keeps what Ctrl+S wrote (%s)" % _said(first_lines), first_lines.size() == 1
		and str(first_lines[0][1]).contains("30° at 20%"))
	_panel.call("close")
	await _frames(6)

	print("  Stop pressed mid-program")
	_main.call("clear_model")
	await _frames(10)
	var rig: Dictionary = _spike_beam(0.0)
	await _frames(10)
	var rest: Dictionary = _rest()
	_shell.call("run", "simulate")
	await _settled()
	named = _panel.call("controls_by_name")
	run = named.get("simulate_run")
	var beam: BrickWorld.Brick = _world.get_brick(int(rig["beam"]))
	_panel.call("set_program", "to 3600° at 10%")
	run.pressed.emit()
	for _n: int in 600:
		await process_frame
		if bool(_panel.get("running")):
			break
	await _frames(60)
	run.pressed.emit()
	await _frames(2)
	var at_stop: Transform3D = _world.drawn_at(beam)
	var running_after: bool = bool(_panel.get("running"))
	await _frames(60)
	var later: Transform3D = _world.drawn_at(beam)
	_check("Stop pressed: running %s, the beam drawn where Stop left it 60 frames on (moved %.3f°; %.1f° from rest), said \"%s\"" % [
		running_after, rad_to_deg(Quaternion((at_stop.basis.inverse() * later.basis).orthonormalized()).get_angle()),
		rad_to_deg(Quaternion((beam.transform.basis.inverse() * at_stop.basis).orthonormalized()).get_angle()),
		_panel.call("said").get("program", "")], not running_after and at_stop.is_equal_approx(later)
		and not at_stop.is_equal_approx(beam.transform))
	_check("...the model itself never moved", _same_as(rest))
	var depth: int = _builder.history_depth()
	await _verbs.press("undo")
	await _frames(6)
	# F9: the program taken back, its run's pose goes with it.
	_check("undo after the run (history %d -> %d): program %s; the beam drawn at rest (%s); model at rest %s" % [depth,
		_builder.history_depth(), _program_now().c_escape(), _world.drawn_at(beam).is_equal_approx(beam.transform),
		_same_as(rest)], _program_now().is_empty() and _world.drawn_at(beam).is_equal_approx(beam.transform)
		and _same_as(rest))
	# Play after a stopped run: does the panel's reading start where Stop left it?
	_panel.call("set_program", "to 90° at 50%")
	run.pressed.emit()
	for _n: int in 600:
		await process_frame
		if not bool(_panel.get("running")) and not bool(_panel.get("_preparing")) and _n > 30:
			break
	_note("then run to its end: %s" % _panel.call("said").get("program", ""))
	_panel.call("close")
	await _frames(6)

	print("  undo after a kept Clear")
	_main.call("clear_model")
	await _frames(6)
	# Opened as File › Open opens it, its floor laid (ModelBar.opened): by
	# _open (Main._open, the start-up's, whose caller lays the floor after
	# it) the model stood on no plate though its file says a 32 x 32, and
	# the Clear's undo laid the plate, 15 parts of 14 (smalls6 item 3).
	var bar: ModelBar = _main.get("_bar")
	await bar.open_with_progress(MODELS + "hpr_ctrls.ldr")
	bar.opened.emit(_world.brick_count())
	await _settled()
	var had: String = _program_now()
	var parts: int = _world.brick_count()
	var plates: int = _store.scenery.size()
	var saved: String = _store.saved_text()
	_main.call("clear_model", true)
	await _frames(6)
	var cleared: int = _world.brick_count()
	_note("opened: %d parts, %d of them the floor; cleared: %d parts, program %s" % [parts, plates,
		cleared, _program_now().c_escape()])
	await _verbs.press("undo")
	await _settled()
	# The whole count, the floor in it, and what Save writes (smalls6 item 3):
	# it said 15 of 14 here, and hpfix counted the model's own parts alone.
	_check("undo after Clear: %d parts of %d, %d of them the floor of %d, the program back (%s)" % [
		_world.brick_count(), parts, _store.scenery.size(), plates, _program_now().left(30).c_escape()],
		_world.brick_count() == parts and _store.scenery.size() == plates and _program_now() == had)
	_check("...Save writes the file it would have before the Clear, byte for byte (%s)" % (
		"same" if _store.saved_text() == saved else _first_difference(_store.saved_text(), saved)),
		_store.saved_text() == saved)
	await _verbs.press("redo")
	await _settled()
	_check("...redo: the Clear again, %d parts of %d, program %s" % [_world.brick_count(), cleared,
		_program_now().c_escape()], _world.brick_count() == cleared and _program_now().is_empty())
	await _verbs.press("undo")
	await _settled()
	_check("...undo again: %d parts of %d, %d the floor, the program back, Save the same" % [
		_world.brick_count(), parts, _store.scenery.size()], _world.brick_count() == parts
		and _store.scenery.size() == plates and _program_now() == had and _store.saved_text() == saved)


func _start() -> void:
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		if _main.get("_shell") != null and _main.get("_world") != null:
			break
	await _frames(60)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_verbs = _main.get("_verbs")
	_panel = _main.get("_simulate")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var account: Account = _main.get("_account")
	while account.state == Account.State.CHECKING:
		await account.changed
	account.email = "hpreview-probe@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	await _frames(20)
	# Nothing saved, on a phone: the studio's first screen over the car, as a
	# real first visit has it, put away by its ✕ before the program row is
	# tapped; left up, every tap landed on it (hpreview_phone, m338reds).
	await SignInHelper.put_away_first_screen(_main)


# -- 1. files ---------------------------------------------------------------------------------


func _variants() -> Array:
	var fix: String = FileAccess.get_file_as_string(FIX_PATH)
	var lines: PackedStringArray = fix.split("\n")
	var line: String = ""
	for one: String in lines:
		if one.begins_with(META):
			line = one
	var without: PackedStringArray = PackedStringArray()
	for one: String in lines:
		if one != line:
			without.append(one)
	var p2: String = META + JSON.stringify({"text": "turn 10° at 20%"})
	var p3: String = META + JSON.stringify({"text": "wait 2 s"})
	var out: Array = []
	out.append(["head", fix])
	# In the sub-model's head only.
	out.append(["sub", _insert_after(_join(without), "0 FILE arm.ldr\n0 Arm\n0 Name: arm.ldr\n0 Author: Brickworks\n", p2)])
	# The model's and two sub-models', each its own.
	var two: String = _insert_after(fix, "0 FILE arm.ldr\n0 Arm\n0 Name: arm.ldr\n0 Author: Brickworks\n", p2)
	two = two.replace("1 16 0 0 0 1 0 0 0 1 0 0 0 1 arm.ldr\n0\n", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 arm.ldr\n"
		+ "1 16 200 0 0 1 0 0 0 1 0 0 0 1 arm2.ldr\n0\n")
	two += ("0 FILE arm2.ldr\n0 Arm2\n0 Name: arm2.ldr\n0 Author: Brickworks\n" + p3 + "\n\n"
		+ "1 0 0 -306 0 0 0 1 0 1 0 -1 0 0 2780.dat\n1 14 0 -326 -10 1 0 0 0 0 -1 0 1 0 32316.dat\n0\n0 NOFILE\n")
	out.append(["twosubs", two])
	# Beside other app metas: a page setup in the head, a step name in a step.
	var metas: String = fix.replace(line + "\n", "0 !BRICKWORKS PAGE_SETUP A5\n" + line + "\n0 !BRICKWORKS ZOOM 2\n")
	metas = metas.replace("1 71 0 -96 50 1 0 0 0 1 0 0 0 1 3003.dat\n0 STEP\n",
		"1 71 0 -96 50 1 0 0 0 1 0 0 0 1 3003.dat\n0 !BRICKWORKS STEP_NAME Base\n0 STEP\n")
	out.append(["metas", metas])
	out.append(["crlf", fix.replace("\n", "\r\n")])
	out.append(["bom", String.chr(0xFEFF) + fix])
	out.append(["nonl", fix.trim_suffix("\n")])
	# In the model's body, after its first step.
	out.append(["body", _join(without).replace("3003.dat\n0 STEP\n", "3003.dat\n0 STEP\n" + line + "\n", )])
	# Someone else's single file, the line last with no line end.
	var parts := PackedStringArray()
	for one: String in lines:
		if one.begins_with("1 ") and not one.ends_with(".ldr"):
			parts.append(one)
		if one == "0 NOFILE":
			break
	var theirs_head: String = "0 Arm on a hub\n0 Name: theirs.ldr\n0 Author: Someone Else\n"
	out.append(["theirs_last", theirs_head + "\n".join(parts) + "\n" + line])
	out.append(["malformed", fix.replace(line, META + "{\"text\":\"to 90° at 50%\"")])
	var long_note: String = "to 90° at 50% # " + "x".repeat(120000)
	out.append(["long", fix.replace(line, META + JSON.stringify({"text": long_note}))])
	var many := PackedStringArray()
	for n: int in 250:
		many.append("wait 1 s")
	out.append(["manylines", fix.replace(line, META + JSON.stringify({"text": "\n".join(many)}))])
	out.append(["two", fix.replace(line, line + "\n" + META + JSON.stringify({"text": "to 45° at 50%"}))])
	out.append(["unicode", fix.replace(line, META + JSON.stringify({"text": "beep 440\ntourner 90°\nto 90° at 50% # ⚙ 日本語"}))])
	out.append(["unicode_ok", fix.replace(line, META + JSON.stringify({"text": "to 90° at 50% # ⚙ 日本語 é"}))])
	out.append(["noport", fix.replace(line, META + JSON.stringify({"text": "C to 90° at 50%"}))])
	out.append(["spaced", fix.replace(line, "0  !BRICKWORKS   PROGRAM   {\"text\" : \"to 90 at 50%\"}")])
	out.append(["lower", fix.replace(line, "0 !BrickWorks program {\"text\":\"to 90 at 50%\"}")])
	out.append(["lower_sub", _insert_after(_join(without), "0 FILE arm.ldr\n0 Arm\n0 Name: arm.ldr\n0 Author: Brickworks\n",
		"0 !BrickWorks program {\"text\":\"wait 3 s\"}")])
	out.append(["empty_text", fix.replace(line, META + "{\"text\":\"\"}")])
	return out


static func _join(lines: PackedStringArray) -> String:
	return "\n".join(lines)


static func _insert_after(text: String, after: String, line: String) -> String:
	var at: int = text.find(after)
	if at < 0:
		push_error("no anchor")
		return text
	return text.insert(at + after.length(), line + "\n")


func _files() -> void:
	print("\n1. files: open, save unedited, save again; then (hubprogram) set a program, save, reopen")
	for variant: Array in _variants():
		var name: String = variant[0]
		var text: String = variant[1]
		var file: String = "hpr_%s.ldr" % name
		print("\n  -- %s (%d bytes, %d PROGRAM-ish lines)" % [name, text.length(), _programish(text).size()])
		_write(MODELS + file, text)
		_main.call("clear_model")
		await _frames(6)
		await _open(MODELS + file)
		var note: String = ModelBar.unshown_words(_store)
		var parts: int = _world.brick_count() - _store.scenery.size()
		print("    opened: %d parts; program %s; note \"%s\"" % [parts, _program_now().left(80).c_escape()
			if _new else "(none in this build)", note.strip_edges()])
		var saved: String = await _save(file)
		_check_known(name, "%s: an unedited save is the file byte for byte (%s)" % [name, "same" if saved == text
			else _first_difference(text, saved)], saved == text)
		if saved != text:
			_print_changed(text, saved)
		var again: String = await _save(file)
		_check("%s: saved again, the same" % name, again == saved)
		# A whole-model edit: a brick put down, saved; the PROGRAM lines stay as they were.
		var before_lines: Array = _programish(text)
		_flat("3001", Vector3(400, _top_of_floor() + 24.0, 400), 4)
		await _frames(4)
		var edited: String = await _save(file)
		var after_lines: Array = _programish(edited)
		_check("%s: a brick put down and saved: the PROGRAM lines kept, as written (%d -> %d)" % [name,
			before_lines.size(), after_lines.size()], _same_raws(before_lines, after_lines))
		if not _same_raws(before_lines, after_lines):
			print("      before: %s" % _said(before_lines))
			print("      after:  %s" % _said(after_lines))
		if not _new:
			continue
		# Set a program, as Run or leaving the box does.
		_write(MODELS + file, text)
		_main.call("clear_model")
		await _frames(6)
		await _open(MODELS + file)
		var had: String = _program_now()
		var set: bool = bool(_panel.call("set_program", "to 45° at 20%"))
		await _frames(4)
		var changed: String = await _save(file)
		var diff: Array = _diff(text, changed)
		print("    set (%s), saved: removed %s; added %s" % [set, _short(diff[0]), _short(diff[1])])
		var only_program: bool = (diff[0] as Array).all(func(l: String) -> bool: return _is_programish(l)) \
			and (diff[1] as Array).all(func(l: String) -> bool: return _is_programish(l)) \
			and (diff[1] as Array).size() == 1
		_check_known(name, "%s: a program set changes or adds only its PROGRAM line" % name, only_program)
		_main.call("clear_model")
		await _frames(6)
		await _open(MODELS + file)
		_check("%s: reopened, the program is the one set (%s; it was %s)" % [name, _program_now().c_escape(),
			had.left(40).c_escape()], _program_now() == "to 45° at 20%")
		var resaved: String = await _save(file)
		_check("%s: reopened and saved, byte for byte" % name, resaved == changed)
		# And taken out.
		_panel.call("set_program", "")
		var out: String = await _save(file)
		var diff2: Array = _diff(changed, out)
		print("    taken out, saved: removed %s; added %s" % [_short(diff2[0]), _short(diff2[1])])
		_main.call("clear_model")
		await _frames(6)
		await _open(MODELS + file)
		_check("%s: taken out, reopened: no program of the model's (%s)" % [name, _program_now().left(40).c_escape()],
			_program_now().is_empty())


func _programish(text: String) -> Array:
	var out: Array = []
	var lines: PackedStringArray = text.split("\n")
	for n: int in lines.size():
		if _is_programish(lines[n]):
			out.append([n, lines[n]])
	return out


static func _is_programish(line: String) -> bool:
	var words: PackedStringArray = line.strip_edges().split(" ", false)
	return words.size() >= 3 and words[0] == "0" and words[1].to_upper().trim_prefix(String.chr(0xFEFF)) == "!BRICKWORKS" \
		and words[2].to_upper() == "PROGRAM"


static func _same_raws(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for n: int in a.size():
		if str(a[n][1]) != str(b[n][1]):
			return false
	return true


static func _said(list: Array) -> String:
	return ", ".join(PackedStringArray(list.map(func(one: Array) -> String:
		return "line %d %s" % [one[0], str(one[1]).left(70).c_escape()])))


## Lines removed and lines added, as multisets.
static func _diff(a: String, b: String) -> Array:
	var count: Dictionary = {}
	for line: String in a.split("\n"):
		count[line] = int(count.get(line, 0)) + 1
	var added: Array = []
	for line: String in b.split("\n"):
		if int(count.get(line, 0)) > 0:
			count[line] = int(count[line]) - 1
		else:
			added.append(line)
	var removed: Array = []
	for line: String in count:
		for _n: int in int(count[line]):
			removed.append(line)
	return [removed, added]


static func _short(list: Array) -> String:
	return "[%s]" % ", ".join(PackedStringArray(list.map(func(l: String) -> String:
		return l.left(70).c_escape())))


static func _print_changed(a: String, b: String) -> void:
	var d: Array = _diff(a, b)
	print("      removed %s" % _short(d[0]))
	print("      added   %s" % _short(d[1]))


# -- 2. history: undo, redo, copy, paste, Ctrl+S, New ----------------------------------------


func _history() -> void:
	print("\n2. history")
	var fix: String = FileAccess.get_file_as_string(FIX_PATH)
	_write(MODELS + "hpr_hist.ldr", fix)
	_main.call("clear_model")
	await _frames(6)
	await _open(MODELS + "hpr_hist.ldr")
	_check("opened with the bar's program", _program_now() == BAR)
	_check("opened unedited: no unsaved work", not bool(_store.has_unsaved_work()))
	_panel.call("set_program", "to 45° at 20%")
	await _frames(4)
	_check("a program set on a saved model is unsaved work (has_unsaved_work %s)" % _store.has_unsaved_work(),
		bool(_store.has_unsaved_work()))
	await _verbs.press("undo")
	await _frames(6)
	_check("undo: the bar's program again (%s)" % _program_now().left(30).c_escape(), _program_now() == BAR)
	await _verbs.press("redo")
	await _frames(6)
	_check("redo: the set one (%s)" % _program_now().c_escape(), _program_now() == "to 45° at 20%")
	# Select everything, copy, paste, duplicate.
	await _verbs.press("select_all")
	await _frames(4)
	await _verbs.press("copy")
	await _frames(4)
	var count: int = _world.brick_count()
	await _verbs.press("duplicate")
	await _settled()
	print("    duplicate: %d parts -> %d" % [count, _world.brick_count()])
	_check("a copy and a duplicate leave the model's program as it was (%s)" % _program_now().c_escape(),
		_program_now() == "to 45° at 20%")
	var one: String = await _save("hpr_hist.ldr")
	var two: String = await _save("hpr_hist.ldr")
	_check("saved twice, the same", one == two)
	var lines: Array = _programish(one)
	_check("one PROGRAM line in the model's head, the set one (%s)" % _said(lines),
		lines.size() == 1 and str(lines[0][1]) == META + JSON.stringify({"text": "to 45° at 20%"}))
	_main.call("clear_model")
	await _frames(6)
	await _open(MODELS + "hpr_hist.ldr")
	_check("reopened: the set program", _program_now() == "to 45° at 20%")
	# Undo after Clear: the program comes back with the model (main._clear_undone).
	_main.call("clear_model")
	await _frames(6)
	await _verbs.press("undo")
	await _settled()
	_note("undo after Clear: %d parts, program %s" % [_world.brick_count(), _program_now().c_escape()])

	print("  words typed in the box, then Ctrl+S with the box still in focus")
	# Named, so Ctrl+S saves it where it is: the fixture's "0 Untitled" made
	# Ctrl+S ask for a name, and the dialog stayed open over every later
	# section, taking their keys and clicks (hpreview's again and mcpopen).
	fix = _named(fix, "hpr_ctrls")
	_write(MODELS + "hpr_ctrls.ldr", fix)
	_main.call("clear_model")
	await _frames(6)
	await _open(MODELS + "hpr_ctrls.ldr")
	_shell.call("run", "simulate")
	await _settled()
	var named: Dictionary = _panel.call("controls_by_name")
	var box: TextEdit = named.get("simulate_program")
	await _click(box.get_global_rect().get_center())
	await _frames(4)
	box.select_all()
	await _type_text("to 30° at 20%")
	print("    box: %s, focus %s; model's program %s" % [box.text.c_escape(), box.has_focus(),
		_program_now().left(30).c_escape()])
	await _key(KEY_S, true)
	await _settled()
	var after: String = FileAccess.get_file_as_string(MODELS + "hpr_ctrls.ldr")
	var said: Array = _programish(after)
	_check("Ctrl+S with the box in focus writes the words in the box (%s; model's %s; file changed %s)" % [
		_said(said), _program_now().left(30).c_escape(), after != fix],
		said.size() == 1 and str(said[0][1]).contains("30° at 20%"))
	_check("...with no dialog left asking (%s)" % ", ".join(_asking()), _asking().is_empty())
	_note("has_unsaved_work after Ctrl+S: %s" % _store.has_unsaved_work())
	_panel.call("close")
	await _frames(6)
	_note("after closing Simulate, the model's program %s; has_unsaved_work %s" % [
		_program_now().c_escape(), _store.has_unsaved_work()])


# -- 3. plays ----------------------------------------------------------------------------------


func _plays() -> void:
	print("\n3. plays")
	_main.call("clear_model")
	await _frames(10)
	var rig: Dictionary = _spike_beam(0.0)
	await _frames(10)
	var rest: Dictionary = _rest()
	_shell.call("run", "simulate")
	await _settled()
	var named: Dictionary = _panel.call("controls_by_name")
	var run: Button = named.get("simulate_run")
	# What each says, begun with: F8 had "wait 0 s" refused in words that
	# allowed 0, and 1e400 and 1e-9 split at their e.
	for case: Array in [["wait 0 s", "Ran to its end in 0 s"], ["wait -1 s", "Line 1: a time from 0 to 600 s."],
			["to 90° at 150%", "Line 1: a speed is 100% at most"], ["repeat 0\n  wait 1 s", "Line 1: repeat goes round"],
			["to 90° at 101%", "Line 1: a speed is 100% at most"], ["to 90°", "Ran to its end in 0.11 s: A 90°."],
			["B to 90°", "Line 1: no motor is on port B."],
			["turn 1e400° at 50%", "Line 1: 1e400° is more than the 36000° a line turns at most."],
			["to nan° at 50%", "Line 1: to takes degrees"], ["to inf° at 50%", "Line 1: to takes degrees"],
			["wait 1e-9 s", "Ran to its end in 0 s"], ["wait 1e-3 s", "Ran to its end in 0 s"],
			["run 1% for 600 s", "0."]]:
		var timed: Dictionary = await _run_timed(str(case[0]), 20.0)
		_check("%s: %s (longest frame %.0f ms, prepared in %.0f ms, ran %s s)" % [str(case[0]).c_escape(),
			str(timed["said"]).left(160), timed["worst_ms"], timed["prep_ms"], timed["seconds"]],
			str(timed["said"]).begins_with(str(case[1])))
		await _stop_now(run)
	print("  long programs: does any frame hang? (F6: 174 ms and 117 ms; the bar is 16 ms of work a frame)")
	_worst_work = 0.0
	var idle: float = await _idle_worst(120)
	print("    120 frames with nothing running: the longest %.1f ms, its work %.1f ms" % [idle, _worst_work])
	for program: String in ["repeat 1000\n  turn 360° at 100%", "run 100% for 600 s",
			"repeat 1000\n  repeat 1000\n    wait 0.001 s", "repeat 1000\n  turn 1° at 100%\n  turn -1° at 100%",
			"repeat 1000\n  to 36000° at 100%\n  to -36000° at 100%"]:
		var timed: Dictionary = await _run_timed(program, 30.0)
		_check("%s: the most work in a frame %.1f ms, %s (the longest frame %.1f ms; prepared in %.0f ms; %d moves, %s s): %s" % [
			program.c_escape(), timed["work_ms"], "working the run out" if timed["work_preparing"] else "running it",
			timed["worst_ms"], timed["prep_ms"], timed["moves"], timed["seconds"],
			str(timed["said"]).left(120)], float(timed["work_ms"]) < 16.0)
		await _stop_now(run)
	print("  Stop mid-program")
	var beam: BrickWorld.Brick = _world.get_brick(int(rig["beam"]))
	_panel.call("set_program", "to 3600° at 10%")
	_panel.call("run_program")
	for _n: int in 600:
		await process_frame
		if bool(_panel.get("running")):
			break
	await _frames(60)
	await _click(run.get_global_rect().get_center())
	await _frames(2)
	var at_stop: Transform3D = _world.drawn_at(beam)
	var running_after: bool = bool(_panel.get("running"))
	await _frames(60)
	var later: Transform3D = _world.drawn_at(beam)
	_check("Stop clicked: running %s, the beam drawn where Stop left it 60 frames on (moved %.3f°), said \"%s\"" % [
		running_after, rad_to_deg(Quaternion((at_stop.basis.inverse() * later.basis).orthonormalized()).get_angle()),
		_panel.call("said").get("program", "")], not running_after and at_stop.is_equal_approx(later)
		and not at_stop.is_equal_approx(beam.transform))
	_check("...the model itself never moved", _same_as(rest))
	await _verbs.press("undo")
	await _frames(6)
	_check("undo after the run: program %s; the beam drawn at rest (%s); model at rest %s" % [
		_program_now().left(30).c_escape(), _world.drawn_at(beam).is_equal_approx(beam.transform), _same_as(rest)],
		_world.drawn_at(beam).is_equal_approx(beam.transform) and _same_as(rest))
	await _verbs.press("redo")
	await _frames(6)
	print("  Simulate closed mid-program")
	_panel.call("run_program")
	for _n: int in 600:
		await process_frame
		if bool(_panel.get("running")):
			break
	await _frames(30)
	_panel.call("close")
	await _frames(30)
	_check("closed mid-run: not running (%s), the beam drawn where it stands" % _panel.get("running"),
		not bool(_panel.get("running")) and _world.drawn_at(beam).is_equal_approx(beam.transform) and _same_as(rest))
	# Several motors: seven SPIKE motors, ports A to F.
	var hp: Script = load("res://src/assembly/hub_program.gd")
	var ports: Dictionary = hp.call("ports_of", {1: "54675", 2: "54675", 3: "54675", 4: "54675", 5: "54675",
		6: "54675", 7: "54675"})
	var past: String = hp.call("unported_words", ports)
	_check("seven hub motors: ports %s, the seventh said (\"%s\")" % [str(hp.call("lettered", ports)), past],
		(hp.call("lettered", ports) as Array).size() == 6 and past.contains("#7 is on no port"))
	var seven: Object = hp.call("parse", "G to 90°")
	_note("\"G to 90°\" with seven: %s" % str(seven.get("errors")))
	var unnamed: Variant = hp.call("parse", "to 90°").call("ports_used", ports)
	_check("a line naming no port with seven: said, the seventh too (%s)" % str(unnamed).left(200),
		unnamed is String and str(unnamed).contains("#7 is on no port"))
	var ran: Dictionary = {"seconds": 0.11}
	_check("...and a run's end says it (%s)" % str(hp.call("ran_words", ran, ports)),
		str(hp.call("ran_words", ran, ports)).contains("#7 is on no port"))


## [param text] with its title line (the second) [param title]: a model
## with a name of its own, saved by Ctrl+S under it.
static func _named(text: String, title: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	lines[1] = "0 " + title
	return "\n".join(lines)


## The dialogs showing, by name: one left open takes every key after it.
func _asking() -> PackedStringArray:
	var out := PackedStringArray()
	for node: Node in root.find_children("*", "AcceptDialog", true, false):
		if (node as Window).visible:
			out.append("%s \"%s\"" % [node.name, (node as AcceptDialog).dialog_text.left(60)])
	return out


## What the frame's processing took apart from its drawing: from
## process_frame, which comes before every node's _process and every await
## of it (the run's slices among them), to frame_pre_draw, which comes as
## the drawing begins, in the main thread's own time on a CPU
## (/proc/thread-self/schedstat), not the clock's. On this box a frame's
## drawing alone took up to 85 ms with nothing running (Xvfb, at a load of
## 40 on 24 cores), and the clock's time between the two counted the time
## the thread waited for a CPU: 13.5 ms of it in frames doing nothing.
var _frame_began: int = 0
var _worst_work: float = 0.0
var _worst_preparing: bool = false


## The main thread's time on a CPU so far, in µs; the clock's where /proc
## cannot be read.
static func _cpu_us() -> int:
	var file: FileAccess = FileAccess.open("/proc/thread-self/schedstat", FileAccess.READ)
	if file == null:
		return Time.get_ticks_usec()
	return int(file.get_line().get_slice(" ", 0).to_int() / 1000)


func _on_process_frame() -> void:
	_frame_began = _cpu_us()


func _on_pre_draw() -> void:
	if _frame_began > 0:
		var work: float = (_cpu_us() - _frame_began) / 1000.0
		if work > _worst_work:
			_worst_work = work
			_worst_preparing = _panel != null and bool(_panel.get("_preparing"))


## The longest of [param count] frames from now, in ms.
func _idle_worst(count: int) -> float:
	var last: int = Time.get_ticks_usec()
	var worst: float = 0.0
	for _n: int in count:
		await process_frame
		var now: int = Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	return worst


## [param program] set and Run pressed: the longest frame until it runs (or
## refuses), and what it says.
func _run_timed(program: String, most_s: float) -> Dictionary:
	_panel.call("set_program", program)
	await _frames(2)
	var said_before: String = str(_panel.call("said").get("program", ""))
	_worst_work = 0.0
	var began: int = Time.get_ticks_usec()
	var last: int = began
	var worst: float = 0.0
	_panel.call("run_program")
	var now: int = Time.get_ticks_usec()
	worst = maxf(worst, (now - last) / 1000.0)
	last = now
	var prep: float = 0.0
	while (Time.get_ticks_usec() - began) / 1e6 < most_s:
		await process_frame
		now = Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		if not bool(_panel.get("_preparing")) and prep == 0.0:
			prep = (now - began) / 1000.0
		if not bool(_panel.get("_preparing")) and (bool(_panel.get("running"))
				or str(_panel.call("said").get("program", "")) != said_before):
			break
	for _n: int in 30:
		await process_frame
		now = Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	var ran: Dictionary = _panel.get("_ran")
	return {"worst_ms": worst, "work_ms": _worst_work, "work_preparing": _worst_preparing, "prep_ms": prep, "said": _panel.call("said").get("program", ""),
		"moves": HubProgram.move_count(ran), "seconds": Simulation.figure(snappedf(float(ran.get("seconds", 0.0)), 0.01))}


func _stop_now(run: Button) -> void:
	if bool(_panel.get("running")):
		_panel.call("run_program")
	await _frames(4)


# -- 4. MCP ----------------------------------------------------------------------------------


func _mcp() -> void:
	print("\n4. over MCP")
	_panel.call("close")
	_main.call("clear_model")
	await _frames(10)
	_spike_beam(0.0)
	await _frames(10)
	for program: String in ["", "   \n  ", "spin 3", "C to 90° at 50%", "to 90° at 50%", "to 90° at 50%", ""]:
		var depth: int = _builder.history_depth()
		var answer: Array = await _say_all("simulate_mechanism", {"program": program})
		print("    program %s: (history %d -> %d) model's program now %s\n      %s" % [program.c_escape(), depth,
			_builder.history_depth(), _program_now().c_escape(), str(answer[0]).replace("\n", "\n      ").left(900)])
	# A model with no motor at all.
	_main.call("clear_model")
	await _frames(10)
	_flat("3001", Vector3(0, _top_of_floor() + 24.0, 0), 4)
	await _frames(4)
	var depth: int = _builder.history_depth()
	var answer: Array = await _say_all("simulate_mechanism", {"program": "to 90° at 50%"})
	print("    no motor: (history %d -> %d) program now %s\n      %s" % [depth, _builder.history_depth(),
		_program_now().c_escape(), str(answer[0]).replace("\n", "\n      ").left(600)])
	var saved: String = await _save("hpr_nomotor.ldr")
	_note("no motor, saved: %s" % _said(_programish(saved)))


# -- 5. phone ---------------------------------------------------------------------------------


func _phone() -> void:
	print("\n5. the program row at this width, by finger")
	_main.call("clear_model")
	await _frames(10)
	_spike_beam(0.0)
	await _frames(10)
	_shell.call("run", "simulate")
	await _settled()
	var named: Dictionary = _panel.call("controls_by_name")
	var box: TextEdit = named.get("simulate_program")
	var run: Button = named.get("simulate_run")
	var screen: Rect2 = root.get_visible_rect()
	print("    screen %s; box %s; run %s" % [screen, box.get_global_rect(), run.get_global_rect()])
	var scroll: Node = box.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	var view: Rect2 = (scroll as Control).get_global_rect() if scroll != null else screen
	var shown: Rect2 = box.get_global_rect().intersection(view)
	await _touch(shown.get_center())
	await _frames(20)
	_check("tapped, the box has focus", box.has_focus())
	await _type_text("to 3600° at 10%")
	_check("typed by the phone's keys: %s" % box.text.c_escape(), box.text == "to 3600° at 10%")
	view = (scroll as Control).get_global_rect() if scroll != null else screen
	var run_rect: Rect2 = run.get_global_rect().intersection(view).intersection(screen)
	_check("Run shows on the screen after typing (%s, %s)" % [run.get_global_rect(), run_rect], run_rect.has_area())
	await _touch(run_rect.get_center() if run_rect.has_area() else run.get_global_rect().get_center())
	for _n: int in 600:
		await process_frame
		if bool(_panel.get("running")):
			break
	_check("Run tapped: running (%s), the model's program %s" % [_panel.get("running"), _program_now().c_escape()],
		bool(_panel.get("running")) and _program_now() == "to 3600° at 10%")
	await _frames(30)
	var line: Label = _panel.get("_program_said")
	view = (scroll as Control).get_global_rect() if scroll != null else screen
	_check("running: what it says is on the screen (%s in %s)" % [line.get_global_rect(), view.intersection(screen)],
		view.intersection(screen).encloses(line.get_global_rect()))
	run_rect = run.get_global_rect().intersection(view).intersection(screen)
	await _touch(run_rect.get_center() if run_rect.has_area() else run.get_global_rect().get_center())
	await _frames(20)
	_check("Stop tapped: stopped (%s, \"%s\")" % [not bool(_panel.get("running")), _panel.call("said").get("program", "")],
		not bool(_panel.get("running")))
	view = (scroll as Control).get_global_rect() if scroll != null else screen
	_check("...and what it says is on the screen (F7: below the fold; %s in %s)" % [line.get_global_rect(),
		view.intersection(screen)], line.text.begins_with("Stopped") and view.intersection(screen).encloses(line.get_global_rect()))
	var scrub: HSlider = named.get("simulate_scrub")
	var sim: Simulation = _panel.get("sim")
	var span: float = sim.cycle() if sim != null else 0.0
	var turned: float = float(_panel.get("turns"))
	_check("...the slider where the program left the arm (F7: at 0; %.4f of %.4f, the arm at %.4f turns)" % [
		scrub.value, scrub.max_value, turned], absf(turned) > 0.01 and span > 0.0
		and absf(scrub.value - fposmod(turned, span)) < 0.002 * maxf(span, 1.0))
	await _shot("phone_stopped")


# -- rigs and files ---------------------------------------------------------------------------


func _spike_beam(x: float) -> Dictionary:
	var t: float = _top_of_floor()
	var h: float = t + 326.0
	for n: int in 7:
		_flat("3003", Vector3(x, t + 24.0 * (n + 1), -50), 71)
	_flat("3738", Vector3(x, h - 150, -50), 71)
	for dx: float in [-40.0, 40.0]:
		_upright("2780", Vector3(x + dx, h - 150, -50), 0)
	var motor: int = _place("54675", Transform3D(SPIKE_STANDS, Vector3(x, h, -50)), 71, "")
	var beam: int = _place("32316", Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1),
		Vector3(0, -1, 0)), Vector3(x, h, 10)), 14, "Arm")
	for y: float in [20.0, -20.0]:
		_along_z("2780", Vector3(x, h + y, 0), 0, "Arm")
	return {"motor": motor, "beam": beam, "h": h, "t": t}


func _top_of_floor() -> float:
	var library: PartLibrary = _main.get("_library")
	var top: float = -INF
	for id: Variant in _store.scenery:
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		if brick == null:
			continue
		var box: AABB = (brick.transform * library.mesh_for(brick.part_id).bounds).abs()
		var studs: float = 4.0 if library.parts[brick.part_id].stud_count > 0 else 0.0
		top = maxf(top, box.end.y - studs)
	return top if top > -INF else 0.0


func _place(part_id: String, at: Transform3D, colour: int, unit: String) -> int:
	var id: int = _world.add_brick(part_id, colour, at)
	_builder.register(id, part_id, at)
	if not unit.is_empty():
		_world.get_brick(id).unit = unit + "#1"
		_world.get_brick(id).group = Assemblies.group_of(unit + "#1")
	return id


func _flat(part_id: String, at: Vector3, colour: int, unit: String = "") -> int:
	return _place(part_id, Transform3D(Basis.IDENTITY, at), colour, unit)


func _along_z(part_id: String, at: Vector3, colour: int, unit: String = "") -> int:
	return _place(part_id, Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0),
		Vector3(-1, 0, 0)), at), colour, unit)


func _upright(part_id: String, at: Vector3, colour: int, unit: String = "") -> int:
	return _place(part_id, Transform3D(Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0),
		Vector3(0, 0, 1)), at), colour, unit)


func _rest() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


func _same_as(rest: Dictionary) -> bool:
	for id: Variant in rest:
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		if brick == null or not brick.transform.is_equal_approx(rest[id]):
			return false
	return true


func _program_now() -> String:
	return str(_world.get("program")) if _world.get("program") != null else ""


func _save(file: String) -> String:
	if not bool(_main.call("save_model", MODELS + file)):
		print("    could not write %s" % file)
		return ""
	await _settled()
	return FileAccess.get_file_as_string(MODELS + file)


func _open(path: String) -> void:
	_main.call("_open", path)
	await _settled()


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _first_difference(a: String, b: String) -> String:
	var n: int = 0
	while n < mini(a.length(), b.length()) and a[n] == b[n]:
		n += 1
	return "differ at %d of %d/%d: %s | %s" % [n, a.length(), b.length(), a.substr(maxi(n - 20, 0), 60).c_escape(),
		b.substr(maxi(n - 20, 0), 60).c_escape()]


func _settled() -> void:
	for _n: int in 600:
		if _store == null or _store.awaited.is_empty():
			break
		await process_frame
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 120000:
		await process_frame
		if not Working.is_busy() and (not _panel.visible or (_panel.get("sim") != null
				and not bool(_panel.get("_reading")) and not bool(_panel.get("_driving")))):
			break
	await _frames(10)


func _say_all(tool: String, arguments: Dictionary) -> Array:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	var pictured: bool = false
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
		pictured = pictured or str(block.get("type", "")) == "image"
	if text.is_empty() and (answer as Dictionary).has("error"):
		text = str((answer as Dictionary)["error"])
	return [text, pictured]


func _type_text(words: String) -> void:
	for n: int in words.length():
		var key := InputEventKey.new()
		key.pressed = true
		if words[n] == "\n":
			key.keycode = KEY_ENTER
			key.physical_keycode = KEY_ENTER
		else:
			key.unicode = words.unicode_at(n)
		Input.parse_input_event(key)
		await process_frame
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
	await _frames(4)


func _key(code: Key, ctrl: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.ctrl_pressed = ctrl
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(3)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(3)


## A finger's tap: a touch down and up (emulated as a mouse by the project).
func _touch(at: Vector2) -> void:
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = _as_event(at)
		Input.parse_input_event(touch)
		await _frames(4)
	await _frames(4)


func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var dir: String = ProjectSettings.globalize_path(_shots)
	DirAccess.make_dir_recursive_absolute(dir)
	image.save_png(dir + name + ".png")
	print("    picture: %s%s.png" % [dir, name])
