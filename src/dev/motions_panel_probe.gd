## Build, Motions… driven as a person drives it, on real sets
## (docs/MOTIONS.md, unit 2): pointer clicks on the panel's own buttons,
## sliders and key strips, and drags of the real parts in the view.
##
##   godot --path . --resolution 1400x900 --script src/dev/motions_panel_probe.gd
##   ... -- OUT_DIR   (pictures and files; bench/results/motions2-2026-10-20 when not given)
##
##  1. 1484-1's doors: the panel suggests opening them, Keep keeps it (one
##     undo step), Play opens them in the view and leaves them open, Play
##     backwards closes them to where they were built. New motion, named,
##     Record, a gate dragged open in the view: kept as one motion of its
##     drag's keys, the model put back, one undo step; played, the gate
##     opens to where the drag left it. A key edited (its way there, and a
##     joint's slider at another time), Play all in order, undo, saved and
##     opened again with the lines back, and a motion defined over MCP
##     showing in the open panel.
##  2. 8808-1's steering: the suggestion kept and played both ways; the
##     steering wheel dragged while recording turns the arms through the
##     rack when played (Grab's loop); the editor offers only joints that
##     move; a slider moved puts a key, undo takes it out.
##  3. The observatory of the third MCP walk (unit 5): the session's
##     copied "Show it all" removed, New sequence keeps every motion in
##     order as one (one step, undone and redone), Down, Take out and Add
##     each one step and undone, Play plays the dome, the telescope and
##     the back wall each from where the last left the model, every frame
##     with every part, Play backwards puts it as built; the list shows it
##     as a row, and saved and opened again its line comes back byte for
##     byte.
## Pictures of the panel in each state (suggested, list, recording,
## editing) in OUT_DIR, named by the window's size: PROBE_SIZE=1280x720
## tools/probe.sh runs it at that size too.
extends SceneTree

const DOORS := "res://vendor/omr/files/1484-1.mpd"
const RACER := "res://vendor/omr/files/8808-1.mpd"
const OBSERVATORY := "res://tests/fixtures/mcpwalk3/observatory.ldr"
const SHOWS: Array = ["Open the dome panel", "Extend the telescope", "Open the back wall panels"]

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _camera: CadCamera
var _shell: Shell
var _verbs: EditVerbs
var _grab: GrabDrag
var _player: MotionPlayer
var _panel: PosePanel
var _out: String = ""
var _next: int = 0
var _last_screen := Vector2.ZERO


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else "/mnt/Projects/brickworks/bench/results/motions2-2026-10-20"
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
	_camera = _main.get("_camera")
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	_grab = _main.get("_grab_drag")
	_player = _main.get("_motions")
	_panel = _main.get("_pose")
	_panel.folder = _out
	Download.folder = _out
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	if not StudioRender.possible():
		print("motions panel probe: needs a window (tools/probe.sh runs it in one)")
		quit(3)
		return
	await _doors()
	await _racer()
	await _observatory()
	print("")
	if _failures == 0:
		print("motions panel: kept, played both ways, recorded from a drag, edited by its joints, "
			+ "played all, undone, saved and opened again, and a session's motion shown, on 1484-1 and 8808-1")
	else:
		print("motions panel: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- 1484-1 -------------------------------------------------------------------------------


func _doors() -> void:
	print("── 1484-1: the doors ──")
	if not await _open(DOORS):
		return
	var built: Dictionary = _poses()
	var depth: int = _builder.history_depth()
	_check("Build has Motions…", _shell.menu_id("pose") >= 0 and _shell.can("pose"))
	_shell.run("pose")
	await _frames(8)
	_check("it opens, called Motions", _panel.visible and _panel._title.text == "Motions")
	var offered: Array = _panel._offered().map(func(one: Motions.Motion) -> String: return one.name)
	_check("it suggests opening the doors (%s), the model having none yet" % str(offered),
		offered.has("Open the doors") and _player.motions().is_empty())
	_check("...and changes nothing (%d parts off, %d steps)" % [_off(built)[0], _builder.history_depth() - depth],
		_off(built)[0] == 0 and _builder.history_depth() == depth)
	_fits("suggested")
	await _shots("doors_suggested")
	# Keep, the suggestion's button.
	await _click(_panel._keep_buttons[offered.find("Open the doors")])
	var motion: Motions.Motion = _player.motions().named("Open the doors")
	_check("Keep keeps it as one of the model's motions, one undo step (%s)" % _panel.status_words(),
		motion != null and _builder.history_depth() == depth + 1 and _panel._row_buttons.size() == 1)
	if motion == null:
		return
	var doors: Array = []
	for track: Motions.Track in motion.tracks:
		doors.append_array(_player.parts_of(track.joint))
	# Play, the row's button: drawn opening in the view, then kept open.
	var drawn_moved: Array = [false]
	await _click(_panel._row_buttons[0]["play"])
	_check("Play plays it in the view (the button says Stop)", _panel.is_playing()
		and (_panel._row_buttons[0]["play"] as Button).text == "Stop")
	await _until_played(func() -> void:
		if not _world.drawn_ids().is_empty():
			drawn_moved[0] = true)
	var open_at: Dictionary = _poses()
	var opened: Array = _off_ids(built, _door_parts(doors), 0.05)
	_check("...drawn moving as it plays, and leaves the doors open (%d parts moved, most %.0f°)" % [
		opened[0], opened[2]], drawn_moved[0] and int(opened[0]) > 0 and float(opened[2]) > 30.0)
	_check("...said in the panel, in the motion's words: %s" % _panel.status_words().left(110),
		_panel.status_words().begins_with("Played \"Open the doors\"") and (_panel.status_words().contains("went from")
			or _panel.status_words().contains("stops at")))
	_fits("list")
	await _shots("doors_list")
	await _click(_panel._row_buttons[0]["back"])
	await _until_played()
	var closed: Array = _off_ids(built, _door_parts(doors), 0.05)
	_check("Play backwards closes them to where they were built (%d parts off, %.3f LDU)" % [closed[0], closed[1]],
		int(closed[0]) == 0)
	# Record a gate opened by hand.
	var asked_at: int = Time.get_ticks_msec()
	await _click(_panel._new)
	print("    the editor, its joints found, opened in %d ms (with the click's frames)" % (Time.get_ticks_msec() - asked_at))
	_check("New motion opens the editor on a new one, its name chosen to type over (%s)" % _panel._name.text,
		_panel._view == "edit" and _panel._name.has_focus() and _panel._draft != null)
	await _type("Open the gate")
	var at_record: int = _builder.history_depth()
	await _click(_panel._record)
	_check("Record listens, and says to drag (%s)" % _panel.status_words().left(60),
		_panel.is_recording() and _panel._record.text == "Stop")
	_fits("recording")
	await _shots("doors_recording")
	var gate: Motions.Joint = motion.tracks[0].joint
	var before_drag: Dictionary = _poses()
	var dragged: Grab = await _drag(_player.parts_of(gate), 50.0, 25)
	await _button(_last_screen, false)
	await _settled()
	await _frames(4)
	var after_drag: Dictionary = _poses()
	var moved_by_drag: Array = _off_ids(before_drag, [], 0.05)
	_check("a gate dragged in the view while recording turns on its hinge (%d parts, %.0f°)" % [
		moved_by_drag[0], moved_by_drag[2]], dragged != null and int(moved_by_drag[0]) > 0)
	await _frames(20)
	var depth_before_stop: int = _builder.history_depth()
	await _click(_panel._record)
	var recorded: Motions.Motion = _player.motions().named("Open the gate")
	print("    " + _panel.status_words())
	_check("Stop keeps it as \"Open the gate\": %s" % (_track_words(recorded) if recorded != null else "none"),
		recorded != null and recorded.tracks.size() == 1 and (recorded.tracks[0] as Motions.Track).keys.size() >= 2)
	_check("...the model back where it was (%d parts off)" % _off(before_drag)[0],
		int(_off_ids(before_drag, [], 0.05)[0]) == 0)
	_check("...one undo step for the kept motion (history %d, was %d at Record, %d at Stop)" % [
		_builder.history_depth(), at_record, depth_before_stop], _builder.history_depth() == at_record + 1)
	if recorded == null:
		return
	await _click(_panel._edit_play)
	await _until_played()
	var replayed: Array = _off_ids(after_drag, [], 0.5)
	_check("...and played, the gate opens to where the drag left it (%d parts off, %.2f LDU, %.2f°)" % [
		replayed[0], replayed[1], replayed[2]], int(replayed[0]) == 0)
	# Its key strip: the last key chosen, made linear.
	var row: Dictionary = _panel._joint_parts[0]
	var strip: PosePanel.KeyStrip = row["strip"]
	var keys: Array = (recorded.tracks[0] as Motions.Track).keys
	await _click_at(_strip_point(strip, float(keys.back()[0])))
	_check("a key pressed on its strip is chosen, and the time goes to it (%s s)" % Motions.num(_panel._at, 2),
		_panel._key_index == keys.size() - 1 and absf(_panel._at - float(keys.back()[0])) < 0.06
		and _panel._key_row.visible)
	var depth_now: int = _builder.history_depth()
	_panel._how.select(1)
	_panel._how.item_selected.emit(1)
	await _frames(3)
	recorded = _player.motions().named("Open the gate")
	_check("its way there made Linear, one step (%s)" % str((recorded.tracks[0] as Motions.Track).keys.back()),
		str((recorded.tracks[0] as Motions.Track).keys.back()[2]) == "LINEAR" and _builder.history_depth() == depth_now + 1)
	# A key at another time, from the joint's slider.
	await _click_at(_slider_point(_panel._time, 0.5))
	var t: float = _panel._at
	var slider: HSlider = _panel._joint_parts[0]["slider"]
	var keys_before: int = (recorded.tracks[0] as Motions.Track).keys.size()
	await _click_at(_slider_point(slider, _ratio_of(slider, 20.0)))
	recorded = _player.motions().named("Open the gate")
	var added: Array = []
	for key: Array in (recorded.tracks[0] as Motions.Track).keys:
		if absf(float(key[0]) - t) < 0.01:
			added = key
	_check("the time moved (%s s) and the gate's slider set there puts a key at it (%s)" % [Motions.num(t, 2),
		str(added)], not added.is_empty() and (recorded.tracks[0] as Motions.Track).keys.size() == keys_before + 1
		and absf(float(added[1]) - 20.0) < 3.0 and _builder.history_depth() == depth_now + 2)
	_fits("editing")
	await _shots("doors_editing")
	# Undo, as Edit > Undo: the key is gone, in the panel too.
	await _undo()
	await _frames(4)
	recorded = _player.motions().named("Open the gate")
	_check("Undo takes the key out (%d keys), and the panel shows it (%d marks)" % [
		(recorded.tracks[0] as Motions.Track).keys.size(), (_panel._joint_parts[0]["strip"] as PosePanel.KeyStrip).times.size()],
		(recorded.tracks[0] as Motions.Track).keys.size() == keys_before
		and (_panel._joint_parts[0]["strip"] as PosePanel.KeyStrip).times.size() == keys_before)
	# Play all, from the list.
	var before_all: Dictionary = _poses()
	await _click(_panel._back)
	_check("All motions goes back to the list, both there", _panel._view == "list" and _panel._row_buttons.size() == 2)
	await _click(_panel._play_all)
	_check("Play all plays them", _panel.is_playing() and _panel._play_all.text == "Stop")
	await _until_played()
	_check("...in order, each said: %s" % _panel.status_words().left(120),
		_panel.status_words().begins_with("Played all 2 in order") and _panel.status_words().contains("\"Open the doors\":")
		and _panel.status_words().contains("\"Open the gate\":"))
	await _undo()
	await _frames(4)
	_check("...one step: undo puts the model back as it stood (%d parts off)" % _off_ids(before_all, [], 0.05)[0],
		int(_off_ids(before_all, [], 0.05)[0]) == 0)
	# Saved and opened again: the lines come back, and the panel lists them.
	var text: String = _store.to_text("Doors and gate")
	var lines: PackedStringArray = _motion_lines(text)
	var file: String = _out.path_join("doors_and_gate.mpd")
	_write(file, text)
	if not await _open(file):
		return
	_shell.run("pose")
	await _frames(8)
	var again: PackedStringArray = _motion_lines(_store.to_text("Doors and gate"))
	_check("saved and opened again, its %d motion lines come back byte for byte, and the panel lists %s"
		% [lines.size(), str(_panel._row_buttons.map(func(r: Dictionary) -> String: return str(r["name"])))],
		not lines.is_empty() and again == lines and _panel._row_buttons.size() == 2)
	# A session defines one while the panel is open.
	var said: String = await _say("define_motion", {"name": "Open the mailbox", "tracks": [
		{"joint": "#%d" % _player.parts_of((_player.motions().named("Open the doors").tracks.back() as Motions.Track).joint)[0],
		"keys": [{"t": 0, "place": 0}, {"t": 1.5, "place": 45}]}]})
	print("    " + said.get_slice("\n", 0))
	await _frames(4)
	var names: Array = _panel._row_buttons.map(func(r: Dictionary) -> String: return str(r["name"]))
	_check("a motion a session defines over MCP shows in the open panel (%s)" % str(names),
		said.begins_with("Kept") and names.has("Open the mailbox"))
	_check("three motions listed, with Play all and Loop", names.size() == 3 and _panel._play_all.is_visible_in_tree()
		and _panel._loop.is_visible_in_tree())
	_fits("three motions")
	await _shots("doors_three_motions")
	await _undo()
	await _frames(4)
	names = _panel._row_buttons.map(func(r: Dictionary) -> String: return str(r["name"]))
	_check("...and undone, it goes from the panel (%s)" % str(names), not names.has("Open the mailbox"))
	_panel.close()


# -- 8808-1 -------------------------------------------------------------------------------


func _racer() -> void:
	print("── 8808-1: the steering ──")
	if not await _open(RACER):
		return
	var built: Dictionary = _poses()
	var depth: int = _builder.history_depth()
	_shell.run("pose")
	await _frames(8)
	var offered: Array = _panel._offered().map(func(one: Motions.Motion) -> String: return one.name)
	_check("it suggests steering left and right (%s)" % str(offered), offered.has("Steer left and right"))
	_fits("suggested")
	await _shots("racer_suggested")
	if not offered.has("Steer left and right"):
		return
	await _click(_panel._keep_buttons[offered.find("Steer left and right")])
	var motion: Motions.Motion = _player.motions().named("Steer left and right")
	_check("Keep keeps it, one step", motion != null and _builder.history_depth() == depth + 1)
	if motion == null:
		return
	var arms: Array = _arms()
	var turned: Dictionary = {}
	await _click(_panel._row_buttons[0]["play"])
	await _until_played(func() -> void:
		for id: int in arms:
			var at: Variant = _world.drawn_ids().get(id)
			if at != null and not (at as Transform3D).basis.is_equal_approx((built[id] as Transform3D).basis):
				turned[id] = true)
	_check("Play turns both front arms in the view, through the rack (%d of %d): %s" % [turned.size(), arms.size(),
		_panel.status_words().left(90)], arms.size() == 2 and turned.size() == 2)
	_check("...and ends where it began, as steering left and right does (%d parts off)" % _off_ids(built, [], 0.5)[0],
		int(_off_ids(built, [], 0.5)[0]) == 0)
	await _click(_panel._row_buttons[0]["back"])
	await _until_played()
	_check("Play backwards plays it the other way, back where it was built (%d off)" % _off_ids(built, [], 0.5)[0],
		int(_off_ids(built, [], 0.5)[0]) == 0)
	_fits("list")
	await _shots("racer_list")
	# Record the steering wheel turned by hand.
	await _click(_panel._new)
	await _type("Steer left")
	var at_record: int = _builder.history_depth()
	await _click(_panel._record)
	_fits("recording")
	await _shots("racer_recording")
	var wheel: int = _wheel()
	var before: Dictionary = _poses()
	var dragged: Grab = await _drag([wheel], 40.0, 20) if wheel != 0 else null
	await _button(_last_screen, false)
	await _settled()
	await _frames(4)
	var after: Dictionary = _poses()
	var arms_moved: Array = _off_ids(before, arms, 0.05)
	_check("the steering wheel dragged while recording turns the arms through the rack (%d of 2)" % arms_moved[0],
		dragged != null and int(arms_moved[0]) == 2)
	await _click(_panel._record)
	var recorded: Motions.Motion = _player.motions().named("Steer left")
	print("    " + _panel.status_words())
	_check("Stop keeps \"Steer left\", the model put back (%d parts off), one step" % _off_ids(before, [], 0.05)[0],
		recorded != null and int(_off_ids(before, [], 0.05)[0]) == 0 and _builder.history_depth() == at_record + 1)
	if recorded == null:
		return
	await _click(_panel._edit_play)
	await _until_played()
	var replayed: Array = _off_ids(after, arms, 0.6)
	_check("...played, the arms turn as the drag turned them (%d of 2 off, %.2f LDU, %.2f°): %s" % [replayed[0],
		replayed[1], replayed[2], _panel.status_words().left(80)], int(replayed[0]) == 0)
	# The editor offers only joints that move.
	var offered_joints: Array = _panel._joint_parts.map(func(p: Dictionary) -> String:
		return _player.joint_name(p["joint"]))
	var stuck: Array = []
	for part: Dictionary in _panel._joint_parts:
		var item: MotionPlayer.Item = _player.hold(part["joint"])
		var moves: bool = item.grab != null and (absf(_player.step_to(item, item.from + 10.0) - item.from) >= 0.5
			or absf(_player.step_to(item, item.from - 10.0) - item.from) >= 0.5 or (part["joint"] as Motions.Joint).mode == "slide")
		if not moves:
			stuck.append(_player.joint_name(part["joint"]))
	_check("its editor offers a slider for each joint that moves (%d: %s), none that cannot (%s)" % [
		offered_joints.size(), ", ".join(offered_joints.slice(0, 6)), str(stuck)],
		not offered_joints.is_empty() and stuck.is_empty())
	await _click_at(_slider_point(_panel._time, 0.2))
	var t: float = _panel._at
	var slider: HSlider = _panel._joint_parts[0]["slider"]
	var keys_before: int = (recorded.tracks[0] as Motions.Track).keys.size()
	var depth_now: int = _builder.history_depth()
	await _click_at(_slider_point(slider, _ratio_of(slider, 25.0)))
	recorded = _player.motions().named("Steer left")
	_check("a slider moved at %s s puts a key there (%d keys, were %d), one step" % [Motions.num(t, 2),
		(recorded.tracks[0] as Motions.Track).keys.size(), keys_before],
		(recorded.tracks[0] as Motions.Track).keys.size() == keys_before + 1 and _builder.history_depth() == depth_now + 1)
	_fits("editing")
	await _shots("racer_editing")
	await _undo()
	await _frames(4)
	recorded = _player.motions().named("Steer left")
	_check("...and undo takes it out (%d keys)" % (recorded.tracks[0] as Motions.Track).keys.size(),
		(recorded.tracks[0] as Motions.Track).keys.size() == keys_before)
	# The last joint offered, scrolled to as a person scrolls: its slider
	# shows whole, and a click on it adds that joint to the motion.
	var last: Dictionary = _panel._joint_parts.back()
	var far: HSlider = last["slider"]
	_panel._body.ensure_control_visible(far)
	await _frames(4)
	var seen: bool = _panel._body.get_global_rect().grow(1.0).encloses(far.get_global_rect())
	var tracks_before: int = recorded.tracks.size()
	depth_now = _builder.history_depth()
	await _click_at(_slider_point(far, _ratio_of(far, _player.at_now(last["joint"]) + (0.5 if
		(last["joint"] as Motions.Joint).mode == "slide" else 15.0))))
	recorded = _player.motions().named("Steer left")
	_check("the last joint offered (%s) shows whole once scrolled to, and its slider adds it (%d tracks, were %d)" % [
		_player.joint_name(last["joint"]), recorded.tracks.size(), tracks_before], seen
		and recorded.tracks.size() == tracks_before + 1 and _builder.history_depth() == depth_now + 1)
	await _undo()
	await _frames(4)
	recorded = _player.motions().named("Steer left")
	# Render animation: the motion chosen, drawn and kept.
	var frames: int = await _panel.render_animation()
	_check("Render animation draws the motion being edited (%d frames): %s" % [frames, _panel.status_words().left(90)],
		frames == roundi(recorded.length() * 12.0) + 1 and _panel._last.has("kept"))
	_panel.close()
	_check("Close stops drawing anything over the model", _world.drawn_ids().is_empty() and not _panel.is_processing())


# -- the observatory: a sequence ------------------------------------------------------------


func _row_names() -> Array:
	return _panel._row_buttons.map(func(r: Dictionary) -> String: return str(r["name"]))


func _shown_order() -> Array:
	var motion: Motions.Motion = _player.motions().named("Show it all")
	return Array(motion.sequence) if motion != null else []


func _observatory() -> void:
	print("── the observatory: a sequence ──")
	if not await _open(OBSERVATORY):
		return
	_builder.forget_history()
	_shell.run("pose")
	await _frames(8)
	var built: Dictionary = _poses()
	_check("the panel lists the walk's four motions (%s)" % str(_row_names()), _row_names().size() == 4
		and _row_names().has("Show it all"))
	# The session's "Show it all" was a copy of the back wall's tracks.
	await _click(_panel._row_buttons[_row_names().find("Show it all")]["edit"])
	await _click(_panel._remove)
	_check("its copied \"Show it all\" taken out (%s)" % str(_row_names()), _panel._view == "list"
		and not _row_names().has("Show it all"))
	var depth: int = _builder.history_depth()
	await _click(_panel._new_sequence)
	_check("New sequence keeps every motion, in order, as one (%s), one step" % str(_shown_order()),
		_panel._view == "sequence" and _shown_order() == SHOWS and _builder.history_depth() == depth + 1
		and _panel._seq_name.text == "Show it all")
	_check("...its rows in order, each with Up, Down and Take out", _panel._seq_buttons.size() == 3
		and _panel._seq_buttons[0]["up"].disabled and not _panel._seq_buttons[0]["down"].disabled
		and _panel._seq_buttons[2]["down"].disabled)
	_fits("a sequence")
	await _shots("observatory_sequence")
	await _undo()
	_check("...undone, it is gone and the list is back", _player.motions().named("Show it all") == null
		and _panel._view == "list")
	_shell.run("redo")
	await _frames(6)
	_check("...redone, it is a row like any motion (%s)" % str(_row_names()), _row_names().has("Show it all"))
	await _click(_panel._row_buttons[_row_names().find("Show it all")]["edit"])
	_check("Edit on its row opens it", _panel._view == "sequence" and _panel._seq_buttons.size() == 3)
	depth = _builder.history_depth()
	await _click(_panel._seq_buttons[0]["down"])
	_check("Down plays the dome later (%s), one step" % str(_shown_order()), _shown_order() == [SHOWS[1],
		SHOWS[0], SHOWS[2]] and _builder.history_depth() == depth + 1)
	await _undo()
	_check("...undone, the order is back (%s), the editor still open" % str(_shown_order()),
		_shown_order() == SHOWS and _panel._view == "sequence")
	await _click(_panel._seq_buttons[2]["up"])
	_check("Up plays the back wall sooner (%s)" % str(_shown_order()), _shown_order() == [SHOWS[0], SHOWS[2],
		SHOWS[1]])
	await _undo()
	await _click(_panel._seq_buttons[1]["out"])
	_check("Take out takes the telescope out of it (%s), the motion kept" % str(_shown_order()),
		_shown_order() == [SHOWS[0], SHOWS[2]] and _player.motions().named(SHOWS[1]) != null)
	await _undo()
	var pick: int = -1
	for n: int in _panel._seq_pick.item_count:
		if str(_panel._seq_pick.get_item_metadata(n)) == SHOWS[0]:
			pick = n
	_panel._seq_pick.select(pick)
	await _click(_panel._seq_add)
	_check("Add plays the dome again at its end (%s)" % str(_shown_order()), _shown_order().size() == 4
		and _shown_order()[3] == SHOWS[0])
	await _undo()
	_check("...and every change undone: %s, at the depth it was made at" % str(_shown_order()),
		_shown_order() == SHOWS and _builder.history_depth() == depth)
	# Played: each from where the one before left the model.
	await _click(_panel._seq_play)
	var sizes: Dictionary = {}
	for frame: Dictionary in _panel._frames:
		sizes[frame.size()] = true
	_check("Play plays it (%d frames), every frame with every part it moves (%s)" % [_panel._frames.size(),
		str(sizes.keys())], _panel.is_playing() and _panel._frames.size() == 99 and sizes.size() == 1)
	await _frames(40)
	await _shots("observatory_sequence_playing")
	await _until_played()
	var said: String = _panel.status_words()
	print("    " + said.left(400))
	var dome: int = _player.motions().named(SHOWS[0]).tracks[0].joint.lead
	var turned: float = rad_to_deg((built[dome] as Transform3D).basis.get_rotation_quaternion().angle_to(
		_world.get_brick(dome).transform.basis.get_rotation_quaternion()))
	var moved: Array = _off_ids(built, [], 0.05)
	_check("...in order, each said, the dome open %.0f° and %d parts moved, one step" % [turned, moved[0]],
		said.begins_with("Played \"Show it all\", 3 in order") and said.find(SHOWS[0]) < said.find(SHOWS[1])
		and said.find(SHOWS[1]) < said.find(SHOWS[2]) and absf(turned - 110.0) < 2.0 and int(moved[0]) > 20
		and _builder.history_depth() == depth + 1)
	await _shots("observatory_sequence_played")
	await _click(_panel._seq_reverse)
	await _until_played()
	var back: Array = _off_ids(built, [], 0.05)
	_check("Play backwards, in reverse order, puts it as built: %d parts off (%s)" % [back[0],
		_panel.status_words().left(90)], int(back[0]) == 0
		and _panel.status_words().begins_with("Played \"Show it all\" backwards"))
	await _click(_panel._seq_back)
	_check("the list shows it as a row, with Play, Play backwards and Edit", _row_names().has("Show it all")
		and not _panel._row_buttons[_row_names().find("Show it all")]["play"].disabled)
	_fits("the list with a sequence")
	await _shots("observatory_list")
	# Saved and opened again.
	var text: String = _store.to_text("Observatory")
	var lines: PackedStringArray = _motion_lines(text)
	var file: String = _out.path_join("observatory_sequence.ldr")
	_write(file, text)
	if not await _open(file):
		return
	_shell.run("pose")
	await _frames(8)
	var again: PackedStringArray = _motion_lines(_store.to_text("Observatory"))
	_check("saved and opened again, its %d lines come back byte for byte, the sequence's among them" % lines.size(),
		again == lines and lines.has('0 !BRICKWORKS MOTION "Show it all" SEQUENCE "Open the dome panel" '
		+ '"Extend the telescope" "Open the back wall panels"') and _row_names().has("Show it all"))
	_panel.close()


# -- the panel, as a person uses it ---------------------------------------------------------


## Whether the panel fits the window: inside the model's part of it, clear
## of the view cube; and each joint's value shows whole beside its name.
func _fits(state: String) -> void:
	await _frames(2)
	for part: Dictionary in _panel._joint_parts:
		var readout: Label = part["readout"]
		if is_instance_valid(readout) and readout.is_visible_in_tree():
			var called: Label = readout.get_parent().get_child(0)
			var wide: float = readout.get_theme_font("font").get_string_size(readout.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, readout.get_theme_font_size("font_size")).x
			var whole: bool = wide <= readout.size.x + 0.5 \
				and called.get_global_rect().end.x <= readout.get_global_rect().position.x
			if not whole:
				_check("%s: %s's value shows whole beside its name (%s)" % [state, called.text, readout.text], false)
	var rect: Rect2 = _panel.get_global_rect()
	var view: Rect2 = root.get_visible_rect()
	var cube: Control = _main.get("_gizmo")
	var clear: bool = cube == null or not cube.visible or not rect.intersects(cube.get_global_rect())
	_check("%s: the panel fits the window (%s in %s) clear of the view cube" % [state, str(rect.size.round()),
		str(view.size)], view.encloses(rect) and clear)


## The window as it is in [param state], named by its size: run at
## 1400 x 900, and with PROBE_SIZE=1280x720 at that (a display without a
## window manager will not resize the window).
func _shots(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = _out.path_join("%s_%dx%d.png" % [name, size.x, size.y])
	image.save_png(path)
	print("    picture: %s" % path)


func _click(control: Control) -> void:
	await _frames(2)
	if control == null or not control.is_visible_in_tree():
		_check("the control to press shows (%s)" % (control.name if control != null else "none"), false)
		return
	await _click_at(control.get_global_rect().get_center())


func _click_at(at: Vector2) -> void:
	await _move(at, 0)
	await _button(at, true)
	await _button(at, false)
	await _frames(3)


## Typed into the control that has the focus, then Enter.
func _type(words: String) -> void:
	var focus: Control = root.gui_get_focus_owner()
	if focus is LineEdit:
		(focus as LineEdit).select_all()
	for c: String in words:
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = c.unicode_at(0)
		key.keycode = OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
		Input.parse_input_event(key)
		await process_frame
		var up: InputEventKey = key.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		await process_frame
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	Input.parse_input_event(enter)
	await _frames(3)


## Where on [param slider] a click sets it to [param ratio] of its range.
func _slider_point(slider: HSlider, ratio: float) -> Vector2:
	var rect: Rect2 = slider.get_global_rect()
	var grabber: Texture2D = slider.get_theme_icon("grabber")
	var wide: float = grabber.get_width() if grabber != null else 16.0
	return Vector2(rect.position.x + wide * 0.5 + (rect.size.x - wide) * ratio, rect.get_center().y)


static func _ratio_of(slider: HSlider, value: float) -> float:
	return (value - slider.min_value) / (slider.max_value - slider.min_value)


func _strip_point(strip: PosePanel.KeyStrip, t: float) -> Vector2:
	var rect: Rect2 = strip.get_global_rect()
	return Vector2(rect.position.x + strip._x_of(t), rect.get_center().y)


func _until_played(each: Callable = Callable()) -> void:
	for _n: int in 1200:
		await process_frame
		if each.is_valid():
			each.call()
		if not _panel.is_playing():
			break
	await _frames(3)


func _undo() -> void:
	_shell.run("undo")
	await _frames(6)


## Take hold of one of [param ids] in the view and turn it [param degrees]
## about its joint, in [param steps] moves a few frames apart, the button
## still down: the grab, or null.
func _drag(ids: Array, degrees: float, steps: int) -> Grab:
	await _camera_still()
	var press: Dictionary = _press_point(ids)
	if press.is_empty():
		_check("a part to drag shows in the view", false)
		return null
	var screen: Vector2 = press["screen"]
	await _move(screen, 0)
	await _button(screen, true)
	await _move(screen + Vector2(0, 7), MOUSE_BUTTON_MASK_LEFT)
	var grab: Grab = _grab.grab
	if grab == null or grab.state != "moves":
		_check("a drag on #%d turns it on its joint (%s)" % [int(press["brick"]), _grab.last_words], false)
		return null
	var hold: Vector3 = grab._hold
	for n: int in range(1, steps + 1):
		var turned: Vector3 = _about(grab.pivot, grab.axis, degrees * n / steps) * hold
		await _move(_camera.unproject_position(turned), MOUSE_BUTTON_MASK_LEFT)
		await _frames(1)
	await create_timer(0.1).timeout
	await _move(_last_screen + Vector2(0.5, 0), MOUSE_BUTTON_MASK_LEFT)
	return grab


func _press_point(ids: Array) -> Dictionary:
	var panel: Rect2 = _panel.get_global_rect()
	for key: Variant in ids:
		var brick: BrickWorld.Brick = _world.get_brick(int(key))
		var info: PartLibrary.PartInfo = (_main.get("_library") as PartLibrary).parts.get(brick.part_id)
		if info == null:
			continue
		var box: AABB = info.bounds
		var spots: Array = [box.get_center()]
		for corner: int in 8:
			spots.append(box.get_center().lerp(box.get_endpoint(corner), 0.7))
		for spot: Vector3 in spots:
			var at: Vector3 = brick.transform * spot
			if _camera.is_position_behind(at):
				continue
			var screen: Vector2 = _camera.unproject_position(at)
			if not root.get_visible_rect().grow(-8.0).has_point(screen) or panel.has_point(screen) \
					or bool(_main.call("_over_panel_at", screen)):
				continue
			if _verbs.brick_at(screen) == int(key):
				return {"screen": screen, "brick": int(key)}
	return {}


static func _about(pivot: Vector3, axis: Vector3, degrees: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pivot) \
		* Transform3D(Basis(axis.normalized(), deg_to_rad(degrees)), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)


func _camera_still() -> void:
	var was: Transform3D = _camera.global_transform
	var still: int = 0
	for _n: int in 240:
		await process_frame
		var now: Transform3D = _camera.global_transform
		still = still + 1 if now.is_equal_approx(was) else 0
		was = now
		if still >= 3:
			return


func _settled() -> void:
	for _n: int in 1200:
		if not _grab.is_settling():
			break
		await process_frame


func _move(at: Vector2, mask: int) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = _as_event(at) - _as_event(_last_screen)
	move.button_mask = mask
	Input.parse_input_event(move)
	_last_screen = at
	await process_frame


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)
	await _frames(2)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or rect.x <= 0.0:
		return at
	return at * (window / rect)


# -- the sets -------------------------------------------------------------------------------


## The parts that turn with [param leads]' doors: every part of their bodies.
func _door_parts(leads: Array) -> Array:
	var bodies: Bodies = _grab.read_bodies()
	var out: Array = []
	for lead: Variant in leads:
		var body: int = int(bodies.body_of.get(int(lead), -1))
		for id: int in bodies.members.get(body, PackedInt64Array()):
			out.append(id)
	return out


## 8808-1's two steering arms, as move_part names them.
func _arms() -> Array:
	var out: Array = []
	var library: PartLibrary = _main.get("_library")
	for brick: BrickWorld.Brick in _world.bricks():
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info != null and info.name.contains("Steering Arm"):
			out.append(brick.id)
	return out


func _wheel() -> int:
	var library: PartLibrary = _main.get("_library")
	for brick: BrickWorld.Brick in _world.bricks():
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info != null and info.name.contains("Steering Wheel"):
			return brick.id
	return 0


func _track_words(motion: Motions.Motion) -> String:
	var out := PackedStringArray()
	for track: Motions.Track in motion.tracks:
		out.append("%s: %s" % [_player.joint_name(track.joint), str(track.keys.map(func(k: Array) -> String:
			return "%s s %s" % [Motions.num(float(k[0]), 2), Motions.num(float(k[1]), 1)]))])
	return "; ".join(out)


func _open(path: String) -> bool:
	var real: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(real):
		print("    (no %s: tools/omr.py fetch brings the sets)" % path)
		_failures += 1
		return false
	if _panel.visible:
		_panel.close()
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", real)
	for _n: int in 600:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(30)
	return true


func _say(tool: String, arguments: Dictionary) -> String:
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next + 1,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	_next += 1
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	return text


static func _motion_lines(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with(Motions.META):
			out.append(line.strip_edges())
	return out


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _poses() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


func _off(built: Dictionary) -> Array:
	return _off_ids(built, [], 0.0)


## [parts not standing as in [param built] within [param slack] LDU and a
## tenth of a degree, the most LDU off, the most degrees turned], over
## [param ids] (all when empty).
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
		var chord: float = maxf(a.x.distance_to(b.x), maxf(a.y.distance_to(b.y), a.z.distance_to(b.z)))
		var turned: float = rad_to_deg(2.0 * asin(clampf(chord * 0.5, 0.0, 1.0)))
		if off > slack or turned > maxf(0.1, slack * 2.0):
			count += 1
			most = maxf(most, off)
			turned_most = maxf(turned_most, turned)
	return [count, most, turned_most]


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
