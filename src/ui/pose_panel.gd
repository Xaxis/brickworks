## Build, Motions…: the model's own named movements (docs/MOTIONS.md):
## "Open the doors", "Steer left and right", "Lift the boom". The owner
## (2026-10-20): "for my observatory one might be 'open dome panel' and
## another 'extend telescope'".
##
## The panel lists the model's motions, each with Play and Play backwards;
## Play all runs them in order (each after the one it follows), and Loop
## runs it again until Stop. A sequence is a motion made of the model's
## motions in an order chosen (New sequence: "Show it all"), each played
## from where the one before left the model, backwards in reverse order. Playing goes through Grab (MotionPlayer), so a
## joint stops where it meets the model and the panel says where and on
## what; the model is left where it ends, one step to undo, so Play
## backwards closes what Play opened. What moves (MotionPlayer.suggest) is
## offered as motions to keep, one press each.
##
## A motion is made, or changed, in its editor: named; recorded by dragging
## the real parts with Grab in the view (every drag kept as keys at the
## times it happened, Grab's stops and gears with it, and the model put
## back after); or set joint by joint, a slider for each of Grab's joints
## that has room to move (the joints Pose's sliders were) and its keys on a
## strip of time, each eased, linear or held. Every change is one step of
## the history (Builder's "motions"), so undo, the file and a session over
## MCP see the same motions, and a motion a session defines shows here.
##
## Render animation draws the chosen motion off screen a frame at a time
## (StudioRender.animate), as render_motion does: in a browser an animated
## WebP; on the desktop the frames, the WebP and, where ffmpeg is
## installed, an MP4 go to Downloads (RenderOutput).
##
## pose_model and animate_model (AppTools) keep the joints and keys they
## had here: [member poser] and [member animation].
class_name PosePanel
extends PanelContainer

## The model's parts moved: a joint set, or the drags a recording made
## put back. (A motion kept or changed is a step the store hears itself.)
signal changed()

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var assemblies: Assemblies
var scenery: Dictionary = {}
var eye: Camera3D
var look: Environment
var rig_lights: Array[DirectionalLight3D] = []
var named: Callable = func() -> String: return "Model"
## Where desktop files go; Downloads when empty. A probe points it elsewhere.
var folder: String = ""
## The model's motions, played through Grab (main's).
var player: MotionPlayer
## Grab in the view (main's): what a drag holds while Record listens.
var grabbing: GrabDrag
## Puts the Select tool in hand, so a drag in the view takes hold of a part
## on its joint (main's).
var select_tool: Callable = func() -> void: pass

## pose_model's joints (a sub-assembly on a hinge or a turntable) and
## animate_model's keys, for a session over MCP.
var poser := Poser.new()
var animation := PoseAnimation.new()
var renderer: StudioRender
var settings := RenderSettings.new()

const SIZES: Array = [["480 × 300", Vector2i(480, 300)], ["720p", Vector2i(1280, 720)]]
const RATES: Array = [12, 24]
## How the keys go, as a builder says it, in the order Motions.HOWS has them.
const HOW_WORDS: Array = ["Eased", "Linear", "Held"]
## A drag recorded is sampled at most this often, s, then thinned to keys
## no further than [constant KEPT_DEG] (or [constant KEPT_STUDS]) from it.
const SAMPLE_EVERY := 1.0 / 30.0
const KEPT_DEG := 2.0
const KEPT_STUDS := 0.1
## A new motion's first key is at this time, s: a slider moved there moves
## its joint from where it stands to where it is put.
const FIRST_SECONDS := 2.0
## Beside Record, until it is pressed.
const RECORD_WORDS := "then drag parts in the view"
## The width a joint's place is shown in, px: "-180°", "12.35 studs".
const READOUT_WIDE := 72
## A motion's editor offers this many joints besides its own, until More.
const FEW_JOINTS := 5
## The panel's lists stop this far above the window's foot, px.
const FOOT := 44.0
const WIDE := 344

var _title: Label
var _close: Button
var _body: ScrollContainer
var _list_box: VBoxContainer
var _motion_rows: VBoxContainer
var _picks := ButtonGroup.new()
var _none: Label
var _play_all: Button
var _loop: CheckBox
var _suggest_heading: Label
var _suggest_rows: VBoxContainer
var _new: Button
var _new_sequence: Button
var _edit_box: VBoxContainer
var _seq_box: VBoxContainer
var _seq_back: Button
var _seq_remove: Button
var _seq_name: LineEdit
var _seq_play: Button
var _seq_reverse: Button
var _seq_rows: VBoxContainer
var _seq_pick: OptionButton
var _seq_add: Button
## The sequence editor's rows' buttons, by the row's number.
var _seq_buttons: Array = []
var _back: Button
var _remove: Button
var _name: LineEdit
var _record: Button
var _record_words: Label
var _edit_play: Button
var _edit_reverse: Button
var _time: HSlider
var _time_words: Label
var _joint_rows: VBoxContainer
var _more: Button
var _all_joints: bool = false
var _key_row: HBoxContainer
var _key_words: Label
var _how: OptionButton
var _drop_key: Button
var _driver_words: Label
var _rate: OptionButton
var _size: OptionButton
var _render: Button
var _cancel: Button
var _progress: ProgressBar
var _status: Label
var _frame: TextureRect
## Each motion row's buttons, by the row's number, for a browser test.
var _row_buttons: Array = []
var _keep_buttons: Array = []
## The joint rows: [{joint, slider, readout, strip}], as listed.
var _joint_parts: Array = []

## "list", "edit" or "sequence".
var _view: String = "list"
## The motion Render animation draws, by name.
var _chosen: String = ""
## The motion in the editor: the model's own of [member _editing_name], or
## a new one not kept until its first key.
var _editing_name: String = ""
var _draft: Motions.Motion = null
var _at: float = 0.0
## The key chosen on a strip: its joint and its number in its track.
var _key_joint: Motions.Joint = null
var _key_index: int = -1
## The edited motion played to look (nothing changes), for the time slider:
## null when it must be played again.
var _look: MotionPlayer.Played = null
var _drawn: bool = false
## A joint's slider held: the item its grab moves, and what it was asked.
var _held: MotionPlayer.Item = null
var _held_joint: Motions.Joint = null

## Playing: the frames drawn, the next one, and the button that stops it.
var _playing: bool = false
var _frames: Array = []
var _frame_at: float = 0.0
var _shown: int = -1
var _stop_button: Button = null
var _stop_words: String = ""

## Recording: when it began (the first drag's press), the depth of the
## history then, the drags kept, the grab held and its samples, and the
## tracks made so far: [{joint, keys}].
var _recording: bool = false
var _rec_clock: int = -1
var _rec_depth: int = 0
var _rec_drags: int = 0
var _rec_grab: Grab = null
var _rec_part: int = 0
var _rec_mode: String = ""
var _rec_depth_at_press: int = 0
var _rec_samples: Array = []
var _rec_tracks: Array = []
var _rec_refused := PackedStringArray()

var _working: bool = false
var _fraction: float = 0.0
var _last: Dictionary = {}
var _quiet: bool = false
## What was last seen of the model and its history: any change refreshes
## the lists (an undo, a motion a session defined).
var _seen_generation: int = -1
var _seen_history: Array = []
var _seen_motions: Motions = null
var _seen_revision: int = -1
var _suggested: Array = []
var _told_page: String = ""
var _told_page_at: int = 0


func _ready() -> void:
	visible = false
	set_process(false)
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = SIZES[0][1]
	settings.contact_shadow = false
	settings.view = "current"
	_build()


func open() -> void:
	visible = true
	set_process(true)
	_view = "list"
	_draft = null
	_editing_name = ""
	_suggested = player.suggest() if player != null else []
	_refresh()
	if _motions().is_empty():
		_say("Keep a suggestion, or press New motion to make one." if not _offered().is_empty()
			else "Press New motion, then Record and drag the parts that move, or set them joint by joint.")
	else:
		_say("Press Play to watch a motion. Edit changes it, or renames or removes it.")
	if not get_viewport().size_changed.is_connected(_fit_later):
		get_viewport().size_changed.connect(_fit_later)


func close() -> void:
	if _recording:
		stop_recording()
	if _playing:
		_stop_playing()
	if renderer != null and renderer.is_busy():
		renderer.cancel()
	_let_go_slider()
	_undraw()
	visible = false
	set_process(false)
	if get_viewport().size_changed.is_connected(_fit_later):
		get_viewport().size_changed.disconnect(_fit_later)


## The joints as the model stands, without the panel: for a session over
## MCP (AppTools' pose_model), which then swings one with [method set_angle].
func joints_now() -> Array[Poser.Joint]:
	poser.world = world
	poser.builder = builder
	poser.library = library
	poser.assemblies = assemblies
	if poser.joints.is_empty() or not (poser.holds() or poser.read_back()):
		poser.find()
	return poser.joints


## Swing one of pose_model's joints as far as it has room, one step to
## undo. Returns where it got to.
func set_angle(path: String, value: float) -> float:
	var one: Poser.Joint = poser.joint(path)
	if one == null:
		return 0.0
	poser.settle(path, value, one.angle)
	changed.emit()
	return poser.joint(path).angle


func _motions() -> Motions:
	return player.motions() if player != null else Motions.new()


func _say(words: String) -> void:
	_status.text = words


# -- the list ----------------------------------------------------------------------------


## Suggestions the model has not kept yet.
func _offered() -> Array:
	var motions: Motions = _motions()
	return _suggested.filter(func(one: Motions.Motion) -> bool: return motions.named(one.name) == null)


func _refresh() -> void:
	_seen_generation = world.generation()
	_seen_history = _history_now()
	_seen_motions = world.motions
	_seen_revision = world.revision
	_list_box.visible = _view == "list"
	_edit_box.visible = _view == "edit"
	_seq_box.visible = _view == "sequence"
	if _view == "list":
		_fill_list()
	elif _view == "sequence":
		_fill_sequence()
	else:
		_fill_editor()
	_set_buttons()
	_fit_later()


func _fill_list() -> void:
	var motions: Motions = _motions()
	_clear(_motion_rows)
	_row_buttons.clear()
	if motions.named(_chosen) == null:
		_chosen = (motions.list[0] as Motions.Motion).name if not motions.is_empty() else ""
	_none.visible = motions.is_empty()
	for motion: Motions.Motion in motions.list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_motion_rows.add_child(row)
		var name: String = motion.name
		var pick := CheckBox.new()
		pick.button_group = _picks
		pick.text = name
		pick.tooltip_text = "%s, %s s%s. Chosen, Render animation draws it" % [name,
			Motions.num(motions.seconds_of(motion), 1), (", after %s" % Motions.quoted(motion.after))
			if not motion.after.is_empty() and not motion.is_sequence() else (", a sequence: %s" % ", then ".join(
			Array(motion.sequence).map(func(one: String) -> String: return Motions.quoted(one))))
			if motion.is_sequence() else ""]
		pick.add_theme_font_size_override("font_size", 12)
		pick.focus_mode = Control.FOCUS_NONE
		pick.clip_text = true
		pick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.custom_minimum_size = Vector2(96, 0)
		pick.set_pressed_no_signal(name == _chosen)
		pick.pressed.connect(func() -> void:
			_chosen = name
			_set_buttons())
		row.add_child(pick)
		var forward := _button(row, "Play", func() -> void: play(name), "Play it in the view")
		var backward := _button(row, "Play backwards", func() -> void: play(name, true),
			"Play it from its end to its start: what Play opened, this closes")
		var edit := _button(row, "Edit", func() -> void: edit(name),
			"Change its order, rename it or remove it" if motion.is_sequence()
			else "Change its joints and keys, record it again, rename it or remove it")
		_row_buttons.append({"pick": pick, "play": forward, "back": backward, "edit": edit, "name": name})
	_play_all.visible = motions.in_order().size() > 1
	_loop.visible = not motions.is_empty()
	_new_sequence.visible = not motions.in_order().is_empty()
	_clear(_suggest_rows)
	_keep_buttons.clear()
	var offered: Array = _offered()
	_suggest_heading.visible = not offered.is_empty()
	_suggest_rows.visible = not offered.is_empty()
	for motion: Motions.Motion in offered:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_suggest_rows.add_child(row)
		var words := Label.new()
		words.text = motion.name
		words.tooltip_text = _suggestion_words(motion)
		words.mouse_filter = Control.MOUSE_FILTER_PASS
		words.add_theme_font_size_override("font_size", 12)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.clip_text = true
		words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(words)
		var name: String = motion.name
		_keep_buttons.append(_button(row, "Keep", func() -> void: keep_suggestion(name),
			"Keep it as one of the model's motions: saved with the model"))
	_fit_later()


## A suggestion said: each joint and how far it goes, tried for room.
func _suggestion_words(motion: Motions.Motion) -> String:
	var parts := PackedStringArray()
	for track: Motions.Track in motion.tracks:
		var most: float = 0.0
		for key: Array in track.keys:
			if absf(float(key[1]) - track.joint.at) > absf(most):
				most = float(key[1]) - track.joint.at
		parts.append("%s %s" % [player.joint_words(track.joint), _place_words(most, track.joint)])
	if motion.driver != null:
		parts.append("%s turned %s time%s" % [player.joint_words(motion.driver),
			Motions.num(motion.turns, 2), "" if is_equal_approx(motion.turns, 1.0) else "s"])
	return "%s: %s, over %s s" % [motion.name, ", ".join(parts), Motions.num(motion.length(), 1)]


## Keep the suggestion called [param name] as one of the model's motions:
## one step to undo.
func keep_suggestion(name: String) -> void:
	for one: Motions.Motion in _offered():
		if one.name == name:
			var motions: Motions = _motions()
			var had: Motions = motions.copy()
			motions.put(one)
			builder.record([{"undo": "motions", "motions": had}], "kept the motion %s" % Motions.quoted(name))
			_chosen = name
			_refresh()
			_say("Kept %s. Play plays it; undo takes it out." % Motions.quoted(name))
			return


# -- playing ------------------------------------------------------------------------------


## Play the motion [param name] in the view, [param reverse] from its end
## to its start, and leave the model where it ends: one step to undo. A
## press while it plays stops it.
func play(name: String, reverse: bool = false) -> void:
	var button: Button = _button_for(name, reverse)
	if _playing:
		var same: bool = _stop_button == button
		_stop_playing()
		if same:
			return
	if _recording or _working:
		return
	var motion: Motions.Motion = _motion_named(name)
	if motion == null:
		return
	_let_go_slider()
	_undraw()
	if motion.is_sequence():
		_play_sequence(motion, reverse, button)
		return
	var played: MotionPlayer.Played = player.play(motion, reverse, MotionPlayer.PLAY_FPS, true,
		"played %s%s" % [Motions.quoted(motion.name), " backwards" if reverse else ""])
	_stop_words = "%s %s%s: %s." % ["Played", Motions.quoted(motion.name), " backwards" if reverse else "",
		player.said(played)]
	if not played.standing.is_empty():
		_stop_words += " Now %s." % played.standing
	_look = null
	_begin_playing(played.frames, button)


## The sequence [param motion] played, each of its motions from where the
## one before left the model (in reverse order, each backwards, with
## [param reverse]): one step to undo.
func _play_sequence(motion: Motions.Motion, reverse: bool, button: Button) -> void:
	var missing: Array = []
	var order: Array = _motions().played_by(motion, reverse, missing)
	var run: MotionPlayer.Run = player.play_in_order(order, reverse, "played %s%s" % [
		Motions.quoted(motion.name), " backwards" if reverse else ""])
	var lines := PackedStringArray()
	for k: int in order.size():
		lines.append("%s: %s" % [Motions.quoted((order[k] as Motions.Motion).name), player.said(run.played[k])])
	for words: String in missing:
		lines.append("%s: passed over" % words)
	_stop_words = "Played %s%s, %d in order. %s." % [Motions.quoted(motion.name),
		" backwards" if reverse else "", order.size(), "; ".join(lines)]
	if not run.standing().is_empty():
		_stop_words += " Now %s." % run.standing()
	player.results[motion.name.to_lower()] = _stop_words
	_look = null
	_begin_playing(run.frames, button)


## Every motion in order of play (each after the one it follows), each
## from where the last left the model: one step to undo.
func play_all() -> void:
	if _playing:
		var same: bool = _stop_button == _play_all
		_stop_playing()
		if same:
			return
	if _recording or _working:
		return
	var order: Array = _motions().in_order()
	if order.is_empty():
		return
	_let_go_slider()
	_undraw()
	# Each frame with every part: drawn on the model as it ends, a motion's
	# frames showed a later one's parts where they end.
	var run: MotionPlayer.Run = player.play_in_order(order, false, "played every motion")
	var lines := PackedStringArray()
	for k: int in order.size():
		lines.append("%s: %s" % [Motions.quoted((order[k] as Motions.Motion).name), player.said(run.played[k])])
	_stop_words = "Played all %d in order. %s." % [order.size(), "; ".join(lines)]
	_look = null
	_begin_playing(run.frames, _play_all)


func _begin_playing(frames: Array, button: Button) -> void:
	_frames = frames
	_frame_at = 0.0
	_shown = -1
	_playing = not frames.is_empty()
	_say(_stop_words)
	if not _playing:
		return
	_stop_button = button
	if button != null:
		button.text = "Stop"
	_set_buttons()


func _stop_playing() -> void:
	_playing = false
	_frames = []
	if _stop_button != null and is_instance_valid(_stop_button):
		_stop_button.text = "Play all" if _stop_button == _play_all else (
			"Play backwards" if _stop_button.get_meta("backwards", false) else "Play")
	_stop_button = null
	_undraw()
	_set_buttons()


func _button_for(name: String, reverse: bool) -> Button:
	if _view == "edit":
		return _edit_reverse if reverse else _edit_play
	if _view == "sequence":
		return _seq_reverse if reverse else _seq_play
	for row: Dictionary in _row_buttons:
		if str(row["name"]) == name:
			return row["back"] if reverse else row["play"]
	return null


func _draw_frame(frame: Dictionary) -> void:
	world.set_drawn(frame)
	_drawn = true


func _undraw() -> void:
	if _drawn:
		world.set_drawn({})
		_drawn = false


# -- the editor -----------------------------------------------------------------------------


## The editor on the motion [param name].
func edit(name: String) -> void:
	if _recording or _playing or _working:
		return
	var motion: Motions.Motion = _motions().named(name)
	if motion == null:
		return
	_view = "sequence" if motion.is_sequence() else "edit"
	_editing_name = motion.name
	_chosen = motion.name
	_draft = null
	_all_joints = false
	_at = 0.0
	_key_joint = null
	_key_index = -1
	_look = null
	_refresh()
	if motion.is_sequence():
		_say("Up and Down change the order; Add puts another of the model's motions at its end.")
		return
	_say("Move the time, then a joint's slider: a key there. Record makes it again from drags.")


## The editor on a new motion, kept once it has its first key.
func new_motion() -> void:
	if _recording or _playing or _working:
		return
	_draft = Motions.Motion.new()
	_draft.name = _motions().free_name("New motion")
	_view = "edit"
	_all_joints = false
	_editing_name = ""
	_at = FIRST_SECONDS
	_key_joint = null
	_key_index = -1
	_look = null
	_refresh()
	_name.grab_focus()
	_name.select_all()
	_say("Name it, then press Record and drag the parts that move in the view. Or set it here: "
		+ "a joint's slider puts a key at the time above.")


func back_to_list() -> void:
	if _recording:
		stop_recording()
	if _playing:
		_stop_playing()
	_let_go_slider()
	_undraw()
	_view = "list"
	_draft = null
	_editing_name = ""
	_refresh()


## The motion being edited, or null.
func _edited() -> Motions.Motion:
	if _draft != null:
		return _draft
	return _motions().named(_editing_name) if not _editing_name.is_empty() else null


func _motion_named(name: String) -> Motions.Motion:
	if _draft != null and _draft.name == name:
		return _draft
	return _motions().named(name)


## A change to the edited motion, as one step of the history called
## [param words]: [param edit] changes it (a Motions.Motion). A new one is
## kept by its first change.
func _change(words: String, edit_with: Callable) -> void:
	var motions: Motions = _motions()
	var had: Motions = motions.copy()
	var motion: Motions.Motion = _edited()
	if motion == null:
		return
	edit_with.call(motion)
	if _draft != null:
		if motion.tracks.is_empty() and motion.driver == null:
			return
		motion.name = motions.free_name(motion.name.strip_edges() if not motion.name.strip_edges().is_empty()
			else "New motion")
		motions.put(motion)
		_draft = null
		_editing_name = motion.name
		words = "made the motion %s" % Motions.quoted(motion.name)
	else:
		# Its joints the ones kept, where a track was added.
		motions.put(motion)
	builder.record([{"undo": "motions", "motions": had}], words)
	_chosen = motion.name
	_look = null
	_seen_history = _history_now()
	_seen_motions = world.motions


func _fill_editor() -> void:
	var motion: Motions.Motion = _edited()
	if motion == null:
		_view = "list"
		_list_box.visible = true
		_edit_box.visible = false
		_fill_list()
		return
	_quiet = true
	if not _name.has_focus():
		_name.text = motion.name
	_remove.visible = _draft == null
	_time.max_value = maxf(motion.length() + FIRST_SECONDS, 4.0)
	_time.set_value_no_signal(_at)
	_time_words.text = "%s s" % Motions.num(_at, 1)
	_quiet = false
	_clear(_joint_rows)
	_joint_parts.clear()
	# Its tracks' joints first, then the others that move: a few, or all.
	var joints: Array = []
	for track: Motions.Track in motion.tracks:
		joints.append(track.joint)
	var others: int = 0
	for joint: Motions.Joint in player.movable():
		if not joints.any(func(one: Motions.Joint) -> bool: return one == joint or one.same_ref(joint)):
			joints.append(joint)
			others += 1
	var shown: int = joints.size() if _all_joints else mini(joints.size(), maxi(motion.tracks.size(), 0) + FEW_JOINTS)
	for n: int in shown:
		_joint_row(motion, joints[n])
	_more.visible = shown < joints.size()
	_more.text = "Show all %d joints that move" % (joints.size() - motion.tracks.size()) if others > 0 else ""
	if joints.is_empty():
		var none := Label.new()
		none.text = ("Nothing in the model moves on a joint a drag moves: a hinge, a turntable, "
			+ "a pin or an axle in a round hole.")
		none.add_theme_font_size_override("font_size", 12)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(WIDE - 24, 0)
		_joint_rows.add_child(none)
	_driver_words.visible = motion.driver != null
	if motion.driver != null:
		_driver_words.text = "It turns %s %s time%s in %s s, from wherever it stands; what it drives follows." % [
			player.joint_words(motion.driver), Motions.num(motion.turns, 2),
			"" if is_equal_approx(absf(motion.turns), 1.0) else "s", Motions.num(motion.driver_seconds, 1)]
	_show_key()
	# Its rows changed: the lists as tall as they now need.
	_fit_later()


func _track_of(motion: Motions.Motion, joint: Motions.Joint) -> Motions.Track:
	for track: Motions.Track in motion.tracks:
		if track.joint == joint or track.joint.same_ref(joint):
			return track
	return null


## Where [param joint] is at the editor's time: as its track says, else
## where it stands.
func _place_at(motion: Motions.Motion, joint: Motions.Joint) -> float:
	var track: Motions.Track = _track_of(motion, joint)
	return track.place_at(_at) if track != null else player.at_now(joint)


func _joint_row(motion: Motions.Motion, joint: Motions.Joint) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	_joint_rows.add_child(row)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	row.add_child(top)
	var called := Label.new()
	var gone: bool = player.parts_of(joint).is_empty()
	called.text = "%s, %s" % [player.joint_words(joint), "turning" if joint.mode == "turn" else "sliding"]
	# A long part name ends in an ellipsis, whole in its tooltip: the value
	# beside it always shows whole.
	called.tooltip_text = called.text
	called.mouse_filter = Control.MOUSE_FILTER_PASS
	called.add_theme_font_size_override("font_size", 12)
	called.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	called.clip_text = true
	called.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(called)
	var readout := Label.new()
	readout.add_theme_font_size_override("font_size", 12)
	readout.custom_minimum_size = Vector2(READOUT_WIDE, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(readout)
	var track: Motions.Track = _track_of(motion, joint)
	if gone:
		readout.text = ""
		var words := Label.new()
		words.text = player.gone_words(joint).left(1).to_upper() + player.gone_words(joint).substr(1) + "."
		words.add_theme_font_size_override("font_size", 11)
		words.modulate = Color(1, 1, 1, 0.7)
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.custom_minimum_size = Vector2(WIDE - 24, 0)
		row.add_child(words)
		return
	var slider := HSlider.new()
	_style_slider(slider)
	if joint.mode == "turn":
		slider.min_value = -180.0
		slider.max_value = 180.0
		slider.step = 1.0
	else:
		slider.min_value = -12.0
		slider.max_value = 12.0
		slider.step = 0.05
	var place: float = _place_at(motion, joint)
	if joint.mode == "turn":
		slider.min_value = minf(slider.min_value, floorf(place))
		slider.max_value = maxf(slider.max_value, ceilf(place))
	slider.set_value_no_signal(place)
	readout.text = _place_words(place, joint)
	slider.tooltip_text = "Where it is at the time above: moved, a key there"
	slider.drag_started.connect(func() -> void: _hold_slider(joint))
	slider.drag_ended.connect(func(_changed: bool) -> void: _let_go_slider(slider.value))
	slider.value_changed.connect(func(value: float) -> void:
		if _quiet:
			return
		readout.text = _place_words(value, joint)
		if _held != null and _held_joint == joint:
			_move_held(value)
		else:
			# A click on the track: a key there at once.
			_hold_slider(joint)
			_move_held(value)
			_let_go_slider(value))
	row.add_child(slider)
	var strip := KeyStrip.new()
	strip.custom_minimum_size = Vector2(0, 14)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.span = _time.max_value
	strip.now = _at
	strip.tooltip_text = "Its keys: a key pressed is chosen, dragged it moves in time; pressed between, the time goes there"
	if track != null:
		for key: Array in track.keys:
			strip.times.append(float(key[0]))
	if _key_joint == joint:
		strip.chosen = _key_index
	strip.picked.connect(func(index: int) -> void: _pick_key(joint, index))
	strip.moved.connect(func(index: int, t: float) -> void: _move_key(joint, index, t))
	strip.timed.connect(func(t: float) -> void: set_time(t))
	strip.visible = track != null
	row.add_child(strip)
	_joint_parts.append({"joint": joint, "slider": slider, "readout": readout, "strip": strip})


static func _place_words(value: float, joint: Motions.Joint) -> String:
	if joint.mode == "slide":
		return "%s studs" % Motions.num(value, 2)
	return "%d°" % roundi(value)


func _style_slider(slider: HSlider) -> void:
	slider.focus_mode = Control.FOCUS_NONE
	# The wheel scrolls the list, and sets no key.
	slider.scrollable = false
	slider.custom_minimum_size = Vector2(WIDE - 40, 18)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A track to see, as Simulate's scrub has.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.16)
	track.set_corner_radius_all(2)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	slider.add_theme_stylebox_override("slider", track)


## The editor's time set to [param t] seconds: each slider where its joint
## is then, and the model drawn there (played to look: nothing changes).
func set_time(t: float) -> void:
	var motion: Motions.Motion = _edited()
	if motion == null:
		return
	_at = clampf(snappedf(t, 0.05), 0.0, _time.max_value)
	_quiet = true
	_time.set_value_no_signal(_at)
	_quiet = false
	_time_words.text = "%s s" % Motions.num(_at, 1)
	_show_places(motion)
	_show_time(motion)


func _show_places(motion: Motions.Motion) -> void:
	_quiet = true
	for part: Dictionary in _joint_parts:
		var place: float = _place_at(motion, part["joint"])
		(part["slider"] as HSlider).set_value_no_signal(place)
		(part["readout"] as Label).text = _place_words(place, part["joint"])
		(part["strip"] as KeyStrip).now = _at
		(part["strip"] as KeyStrip).queue_redraw()
	_quiet = false


## The model drawn as the edited motion has it at the editor's time.
func _show_time(motion: Motions.Motion) -> void:
	if motion.tracks.is_empty() and motion.driver == null:
		return
	if _look == null:
		_look = player.play(motion, false, MotionPlayer.PLAY_FPS, false)
	if _look.frames.is_empty():
		return
	_draw_frame(_look.frames[clampi(roundi(_at * float(_look.fps)), 0, _look.frames.size() - 1)])


## A joint's slider taken hold of: its joint held on its Grab.
func _hold_slider(joint: Motions.Joint) -> void:
	if _recording or _playing or _working:
		return
	_let_go_slider()
	var item: MotionPlayer.Item = player.hold(joint)
	if item.grab == null:
		_say("%s: %s." % [player.joint_name(joint), item.stop_words])
		return
	_held = item
	_held_joint = joint


func _move_held(place: float) -> void:
	if _held == null:
		return
	player.step_to(_held, place)
	var drawn: Dictionary = world.drawn_ids().duplicate() if _drawn else {}
	drawn.merge(_held.grab.drawn(), true)
	_draw_frame(drawn)


## The slider let go at [param place]: a key at the editor's time, where
## its joint got to, one step to undo. With no place, only let go.
func _let_go_slider(place: float = NAN) -> void:
	if _held == null:
		return
	var item: MotionPlayer.Item = _held
	var joint: Motions.Joint = _held_joint
	_held = null
	_held_joint = null
	if is_nan(place):
		return
	var reached: float = player.step_to(item, place)
	var stopped: String = item.stop_words
	var from: float = item.from
	var at: float = _at
	var name: String = _edited().name if _edited() != null else ""
	_change("set %s at %s s in %s" % [player.joint_name(joint), Motions.num(at, 1), Motions.quoted(name)],
		func(motion: Motions.Motion) -> void:
			var track: Motions.Track = _track_of(motion, joint)
			if track == null:
				track = Motions.Track.new()
				track.joint = joint
				# It goes from where it stands to where it is put.
				if at > 0.0:
					track.add_key(0.0, snappedf(from, 0.01), "EASE")
				motion.tracks.append(track)
			var how: String = "EASE"
			for key: Array in track.keys:
				if absf(float(key[0]) - at) < 0.001:
					how = str(key[2])
			track.add_key(at, snappedf(reached, 0.01), how))
	var motion: Motions.Motion = _edited()
	var track: Motions.Track = _track_of(motion, joint) if motion != null else null
	if track != null:
		_key_joint = track.joint
		for n: int in track.keys.size():
			if absf(float(track.keys[n][0]) - at) < 0.001:
				_key_index = n
	_fill_editor()
	_set_buttons()
	if not stopped.is_empty():
		_say("%s. The key is there." % (stopped.left(1).to_upper() + stopped.substr(1)))
	else:
		_say("%s at %s at %s s." % [player.joint_name(joint), _place_words(reached, joint), Motions.num(at, 1)])
	_undraw()
	_show_time(motion)


func _pick_key(joint: Motions.Joint, index: int) -> void:
	var motion: Motions.Motion = _edited()
	var track: Motions.Track = _track_of(motion, joint) if motion != null else null
	if track == null or index >= track.keys.size():
		return
	_key_joint = track.joint
	_key_index = index
	set_time(float(track.keys[index][0]))
	for part: Dictionary in _joint_parts:
		(part["strip"] as KeyStrip).chosen = index if part["joint"] == joint else -1
		(part["strip"] as KeyStrip).queue_redraw()
	_show_key()


## The chosen key moved to [param t] seconds.
func _move_key(joint: Motions.Joint, index: int, t: float) -> void:
	var motion: Motions.Motion = _edited()
	var track: Motions.Track = _track_of(motion, joint) if motion != null else null
	if track == null or index >= track.keys.size():
		return
	t = clampf(snappedf(t, 0.05), 0.0, Motions.MOST_SECONDS)
	var key: Array = (track.keys[index] as Array).duplicate()
	if absf(float(key[0]) - t) < 0.001:
		return
	_change("moved a key of %s to %s s" % [player.joint_name(joint), Motions.num(t, 2)],
		func(edited_motion: Motions.Motion) -> void:
			var own: Motions.Track = _track_of(edited_motion, joint)
			own.keys.remove_at(index)
			own.add_key(t, float(key[1]), str(key[2])))
	var moved: Motions.Track = _track_of(_edited(), joint)
	_key_joint = moved.joint
	_key_index = -1
	for n: int in moved.keys.size():
		if absf(float(moved.keys[n][0]) - t) < 0.001:
			_key_index = n
	_at = t
	_fill_editor()
	_show_time(_edited())


func _show_key() -> void:
	var motion: Motions.Motion = _edited()
	var track: Motions.Track = _track_of(motion, _key_joint) if motion != null and _key_joint != null else null
	_key_row.visible = track != null and _key_index >= 0 and _key_index < track.keys.size()
	if not _key_row.visible:
		return
	var key: Array = track.keys[_key_index]
	_key_words.text = "Key at %s s, %s:" % [Motions.num(float(key[0]), 2), player.joint_name(track.joint)]
	_quiet = true
	_how.select(maxi(Motions.HOWS.find(str(key[2])), 0))
	_quiet = false
	_fit_later()


## The chosen key's way there: one of Motions.HOWS.
func set_how(how: String) -> void:
	var joint: Motions.Joint = _key_joint
	var index: int = _key_index
	if joint == null or index < 0 or not how in Motions.HOWS:
		return
	_change("made a key of %s %s" % [player.joint_name(joint), HOW_WORDS[Motions.HOWS.find(how)].to_lower()],
		func(motion: Motions.Motion) -> void:
			var track: Motions.Track = _track_of(motion, joint)
			if track != null and index < track.keys.size():
				track.keys[index][2] = how)
	_say("That key's way there is %s now." % HOW_WORDS[Motions.HOWS.find(how)].to_lower())
	_fill_editor()


func remove_key() -> void:
	var joint: Motions.Joint = _key_joint
	var index: int = _key_index
	var motion: Motions.Motion = _edited()
	var track: Motions.Track = _track_of(motion, joint) if motion != null and joint != null else null
	if track == null or index < 0 or index >= track.keys.size():
		return
	var last: bool = track.keys.size() == 1
	if last and motion.tracks.size() == 1 and motion.driver == null:
		_say("It is the motion's only key: Remove takes the motion out.")
		return
	_change("took a key of %s out" % player.joint_name(joint), func(edited_motion: Motions.Motion) -> void:
		var own: Motions.Track = _track_of(edited_motion, joint)
		own.keys.remove_at(index)
		if own.keys.is_empty():
			edited_motion.tracks.erase(own))
	_key_index = -1
	_key_joint = null
	_fill_editor()
	_say("Key taken out%s. Undo puts it back." % (", and the joint with it" if last else ""))


## The edited motion called [param words]: one step to undo. A motion
## that followed it follows it by its new name.
func rename(words: String) -> void:
	words = words.strip_edges().replace('"', "'")
	var motion: Motions.Motion = _edited()
	if motion == null or words.is_empty() or words == motion.name:
		return
	if _draft != null:
		_draft.name = words
		return
	var other: Motions.Motion = _motions().named(words)
	if other != null and other != motion:
		_say("The model has a motion called %s already: give this one another name." % Motions.quoted(words))
		_name.text = motion.name
		_seq_name.text = motion.name
		return
	var was: String = motion.name
	var motions: Motions = _motions()
	var had: Motions = motions.copy()
	for one: Motions.Motion in motions.list:
		if one.after.to_lower() == was.to_lower():
			one.after = words
		for n: int in one.sequence.size():
			if one.sequence[n].to_lower() == was.to_lower():
				one.sequence[n] = words
	motion.name = words
	builder.record([{"undo": "motions", "motions": had}], "renamed the motion %s %s" % [Motions.quoted(was),
		Motions.quoted(words)])
	_editing_name = words
	_chosen = words
	_refresh()
	_say("Renamed %s. Undo gives it its old name." % Motions.quoted(words))


## Take the edited motion out of the model: one step to undo.
func remove_motion() -> void:
	var motion: Motions.Motion = _edited()
	if motion == null or _draft != null:
		return
	var name: String = motion.name
	var motions: Motions = _motions()
	var had: Motions = motions.copy()
	motions.remove(name)
	builder.record([{"undo": "motions", "motions": had}], "took the motion %s out" % Motions.quoted(name))
	back_to_list()
	_say("Took %s out. Undo puts it back." % Motions.quoted(name))


# -- sequences ----------------------------------------------------------------------------


## A sequence of every motion the model has, in order of play (Play all's),
## kept at once as one step and opened to name and reorder: "Show it all".
func new_sequence() -> void:
	if _recording or _playing or _working:
		return
	var motions: Motions = _motions()
	var order: Array = motions.in_order()
	if order.is_empty():
		return
	var motion := Motions.Motion.new()
	motion.name = motions.free_name("Show it all")
	for one: Motions.Motion in order:
		motion.sequence.append(one.name)
	var had: Motions = motions.copy()
	motions.put(motion)
	builder.record([{"undo": "motions", "motions": had}], "made the sequence %s" % Motions.quoted(motion.name))
	_view = "sequence"
	_editing_name = motion.name
	_chosen = motion.name
	_draft = null
	_refresh()
	_seq_name.grab_focus()
	_seq_name.select_all()
	_say("Kept %s: every motion, in order. Name it; Up and Down change the order. Undo takes it out."
		% Motions.quoted(motion.name))


func _fill_sequence() -> void:
	var motions: Motions = _motions()
	var motion: Motions.Motion = motions.named(_editing_name)
	if motion == null or not motion.is_sequence():
		_view = "list"
		_list_box.visible = true
		_seq_box.visible = false
		_fill_list()
		return
	if not _seq_name.has_focus():
		_seq_name.text = motion.name
	_clear(_seq_rows)
	_seq_buttons.clear()
	for n: int in motion.sequence.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_seq_rows.add_child(row)
		var name: String = motion.sequence[n]
		var one: Motions.Motion = motions.named(name)
		var words := Label.new()
		words.text = "%d. %s" % [n + 1, name if one != null else "%s (gone)" % name]
		words.tooltip_text = ("%s, %s s" % [one.name, Motions.num(motions.seconds_of(one), 1)]) if one != null \
			else "The model has no motion %s now: played, it is passed over" % Motions.quoted(name)
		words.mouse_filter = Control.MOUSE_FILTER_PASS
		words.add_theme_font_size_override("font_size", 12)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.clip_text = true
		words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if one == null:
			words.modulate = Color(1, 1, 1, 0.55)
		row.add_child(words)
		var at: int = n
		var up := _button(row, "Up", func() -> void: move_in_sequence(at, -1), "Play it one sooner")
		var down := _button(row, "Down", func() -> void: move_in_sequence(at, 1), "Play it one later")
		var out := _button(row, "Take out", func() -> void: take_out_of_sequence(at),
			"Take it out of this sequence; the motion stays in the model")
		_seq_buttons.append({"up": up, "down": down, "out": out, "name": name})
	_seq_pick.clear()
	for one: Motions.Motion in motions.list:
		if one == motion:
			continue
		_seq_pick.add_item(one.name)
		_seq_pick.set_item_metadata(_seq_pick.item_count - 1, one.name)
	_seq_add.disabled = _seq_pick.item_count == 0
	_fit_later()


## A change to the sequence in the editor, one step called [param words]:
## [param edit_with] changes its names (a PackedStringArray, returned).
func _change_sequence(words: String, edit_with: Callable) -> void:
	var motions: Motions = _motions()
	var motion: Motions.Motion = motions.named(_editing_name)
	if motion == null or not motion.is_sequence() or _recording or _playing or _working:
		return
	var had: Motions = motions.copy()
	var names: PackedStringArray = edit_with.call(motion.sequence.duplicate())
	if names.is_empty():
		_say("A sequence plays one motion at least: Remove takes the sequence out.")
		return
	motion.sequence = names
	builder.record([{"undo": "motions", "motions": had}], words)
	_seen_history = _history_now()
	_seen_motions = world.motions
	_refresh()


## The sequence's motion at [param index] played [param by] sooner (less
## than 0) or later.
func move_in_sequence(index: int, by: int) -> void:
	var motion: Motions.Motion = _motions().named(_editing_name)
	if motion == null or index + by < 0 or index + by >= motion.sequence.size():
		return
	var name: String = motion.sequence[index]
	_change_sequence("played %s %s in %s" % [Motions.quoted(name), "sooner" if by < 0 else "later",
		Motions.quoted(motion.name)], func(names: PackedStringArray) -> PackedStringArray:
			names.remove_at(index)
			names.insert(index + by, name)
			return names)
	_say("%s plays %s now. Undo puts it back." % [Motions.quoted(name), "sooner" if by < 0 else "later"])


func take_out_of_sequence(index: int) -> void:
	var motion: Motions.Motion = _motions().named(_editing_name)
	if motion == null or index < 0 or index >= motion.sequence.size():
		return
	var name: String = motion.sequence[index]
	_change_sequence("took %s out of %s" % [Motions.quoted(name), Motions.quoted(motion.name)],
		func(names: PackedStringArray) -> PackedStringArray:
			names.remove_at(index)
			return names)
	_say("Took %s out of it; the motion stays in the model. Undo puts it back." % Motions.quoted(name))


## The model's motion [param name] played at the end of the sequence.
func add_to_sequence(name: String) -> void:
	var motions: Motions = _motions()
	var motion: Motions.Motion = motions.named(_editing_name)
	var one: Motions.Motion = motions.named(name)
	if motion == null or one == null or one == motion:
		return
	var tried: Motions = motions.copy()
	tried.named(motion.name).sequence.append(one.name)
	var missing: Array = []
	tried.played_by(tried.named(motion.name), false, missing)
	if missing.any(func(words: String) -> bool: return words.contains("inside itself")):
		_say("%s plays %s inside it: it cannot play in it too." % [Motions.quoted(one.name), Motions.quoted(motion.name)])
		return
	_change_sequence("added %s to %s" % [Motions.quoted(one.name), Motions.quoted(motion.name)],
		func(names: PackedStringArray) -> PackedStringArray:
			names.append(one.name)
			return names)
	_say("%s plays last now. Undo takes it out." % Motions.quoted(one.name))


# -- recording ----------------------------------------------------------------------------


## Record: every drag in the view from now until Stop is kept as keys of
## the edited motion, at the times it happened, and the model put back.
func record() -> void:
	if _recording:
		stop_recording()
		return
	if _playing or _working or _edited() == null:
		return
	_let_go_slider()
	_undraw()
	if _name.has_focus():
		rename(_name.text)
		_name.release_focus()
	select_tool.call()
	_recording = true
	_rec_clock = -1
	_rec_depth = builder.history_depth()
	_rec_drags = 0
	_rec_grab = null
	_rec_tracks = []
	_rec_refused = PackedStringArray()
	_record.text = "Stop"
	_record_words.text = "recording: drag the parts in the view"
	_set_buttons()
	_say("Recording %s: drag the parts that move in the view, as far and as fast as they should go. "
		% Motions.quoted(_edited().name) + "Stop when it is done.")


## Stop recording: the drags kept as the motion's keys (in place of the
## keys it had), the model put back where it stood when Record was
## pressed, and the motion one step to undo.
func stop_recording() -> void:
	if not _recording:
		return
	if _rec_grab != null:
		_end_drag()
	_recording = false
	_record.text = "Record"
	_record_words.text = RECORD_WORDS
	var motion: Motions.Motion = _edited()
	var drags: int = _rec_drags
	var put_back: bool = drags > 0 and builder.history_depth() - _rec_depth == drags
	if put_back:
		builder.undo_steps(drags)
		changed.emit()
	var tracks: Array = _rec_tracks
	_rec_tracks = []
	if tracks.is_empty() or motion == null:
		_set_buttons()
		_say("Nothing was dragged, so nothing was kept.%s" % (" " + "; ".join(_rec_refused) + "."
			if not _rec_refused.is_empty() else ""))
		return
	var name: String = motion.name
	_change("recorded the motion %s" % Motions.quoted(name), func(edited_motion: Motions.Motion) -> void:
		edited_motion.tracks = []
		edited_motion.driver = null
		edited_motion.seconds = 0.0
		for made: Dictionary in tracks:
			var track := Motions.Track.new()
			track.joint = made["joint"]
			for key: Array in made["keys"]:
				track.add_key(float(key[0]), float(key[1]), "EASE")
			edited_motion.tracks.append(track))
	var edited_now: Motions.Motion = _edited()
	_at = edited_now.length() if edited_now != null else 0.0
	_key_joint = null
	_key_index = -1
	_refresh()
	var keys: int = 0
	for made: Dictionary in tracks:
		keys += (made["keys"] as Array).size()
	_say("Kept %s: %d drag%s of %d joint%s, %d keys over %s s. %s Play plays it; undo takes it back.%s" % [
		Motions.quoted(edited_now.name if edited_now != null else name), drags, "" if drags == 1 else "s",
		tracks.size(), "" if tracks.size() == 1 else "s", keys,
		Motions.num(edited_now.length() if edited_now != null else 0.0, 1),
		"The model is back where it was." if put_back else "The model stands where the drags left it.",
		(" " + "; ".join(_rec_refused) + ".") if not _rec_refused.is_empty() else ""])


## A frame while recording: the grab held sampled, and a drag let go and
## kept made keys.
func _record_frame() -> void:
	var held: Grab = grabbing.grab if grabbing != null else null
	if held != null and held.state == "moves" and held != _rec_grab:
		if _rec_grab != null:
			_end_drag()
		if held.mode == "ball":
			if not _rec_refused.has(_ball_words(held)):
				_rec_refused.append(_ball_words(held))
			return
		_rec_grab = held
		_rec_part = held.part
		_rec_mode = held.mode
		_rec_depth_at_press = builder.history_depth()
		_rec_samples = []
		if _rec_clock < 0:
			_rec_clock = Time.get_ticks_usec()
	if grabbing != null and grabbing.chain != null and not _rec_refused.has(CHAIN_WORDS):
		_rec_refused.append(CHAIN_WORDS)
	if _rec_grab == null:
		return
	if held == _rec_grab:
		var t: float = float(Time.get_ticks_usec() - _rec_clock) / 1000000.0
		if _rec_samples.is_empty() or t - float((_rec_samples.back() as Array)[0]) >= SAMPLE_EVERY:
			_rec_samples.append([t, _grab_value(held)])
		return
	# Let go: kept once it has settled, swung or fallen.
	if grabbing.is_settling():
		return
	_end_drag()


const CHAIN_WORDS := ("A part held still and then dragged moves its chain of joints, which is not "
	+ "recorded: press and drag at once")


func _ball_words(held: Grab) -> String:
	return "#%d turns on a ball, which a motion does not turn" % held.part


func _grab_value(held: Grab) -> float:
	return held.shift / BrickLattice.STUD if held.mode == "slide" else held.angle


## The drag held let go and kept: its samples as keys of its joint, from
## where the joint stood before it to where it was kept.
func _end_drag() -> void:
	var held: Grab = _rec_grab
	_rec_grab = null
	if held == null or _rec_samples.is_empty():
		return
	if builder.history_depth() <= _rec_depth_at_press:
		return
	_rec_drags += 1
	var t_end: float = float(Time.get_ticks_usec() - _rec_clock) / 1000000.0
	var found: Variant = player.joint_named("#%d" % _rec_part, _rec_mode == "slide", true)
	if found is String:
		_rec_refused.append(str(found))
		return
	var joint: Motions.Joint = found
	for made: Dictionary in _rec_tracks:
		var other: Motions.Joint = made["joint"]
		if other == joint or other.same_ref(joint) or (other.lead != 0 and other.lead == joint.lead
				and other.mode == joint.mode):
			joint = other
	# Where it was kept, and so where it stood before it: the grab counts
	# from where it was grabbed.
	var kept: float = player.at_now(joint)
	var before: float = kept - _grab_value(held)
	var samples: Array = []
	for sample: Array in _rec_samples:
		samples.append([float(sample[0]), before + float(sample[1])])
	if absf(float((samples.back() as Array)[1]) - kept) > (KEPT_DEG if joint.mode == "turn" else KEPT_STUDS):
		samples.append([maxf(t_end, float((samples.back() as Array)[0]) + SAMPLE_EVERY), kept])
	var keys: Array = _thinned(samples, KEPT_DEG if joint.mode == "turn" else KEPT_STUDS)
	for made: Dictionary in _rec_tracks:
		if made["joint"] == joint:
			(made["keys"] as Array).append_array(keys)
			return
	_rec_tracks.append({"joint": joint, "keys": keys})


## [param samples] ([t, place]) thinned to the fewest that keep every
## sample within [param slack] of the line through them (Douglas-Peucker),
## snapped as the file writes them.
static func _thinned(samples: Array, slack: float) -> Array:
	if samples.size() <= 2:
		return samples.map(func(one: Array) -> Array: return [snappedf(float(one[0]), 0.001),
			snappedf(float(one[1]), 0.01)])
	var keep: Array = []
	keep.resize(samples.size())
	keep.fill(false)
	keep[0] = true
	keep[samples.size() - 1] = true
	var spans: Array = [[0, samples.size() - 1]]
	while not spans.is_empty():
		var span: Array = spans.pop_back()
		var a: Array = samples[span[0]]
		var b: Array = samples[span[1]]
		var worst: float = 0.0
		var at: int = -1
		for n: int in range(int(span[0]) + 1, int(span[1])):
			var s: Array = samples[n]
			var along: float = (float(s[0]) - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.000001)
			var off: float = absf(float(s[1]) - lerpf(float(a[1]), float(b[1]), along))
			if off > worst:
				worst = off
				at = n
		if at >= 0 and worst > slack:
			keep[at] = true
			spans.append([span[0], at])
			spans.append([at, span[1]])
	var out: Array = []
	for n: int in samples.size():
		if keep[n]:
			out.append([snappedf(float(samples[n][0]), 0.001), snappedf(float(samples[n][1]), 0.01)])
	return out


func is_recording() -> bool:
	return _recording


func is_playing() -> bool:
	return _playing


# -- rendering -----------------------------------------------------------------------------


## The motion chosen (or edited) drawn as an animation and kept: what
## Render animation does. [param job], from a session (ToolJobs), is the bar
## along the foot of the window. [param view] is RenderSettings.view: the
## person's own camera when empty. Returns how many frames were drawn.
func render_animation(job: Working.Job = null, view: String = "") -> int:
	if _working or world == null:
		return 0
	var motion: Motions.Motion = _edited() if _view != "list" else _motions().named(_chosen)
	if motion == null:
		_say("Keep or make a motion first: Render animation draws the one chosen.")
		return 0
	if _playing:
		_stop_playing()
	_let_go_slider()
	_undraw()
	var fps: int = int(RATES[maxi(_rate.selected, 0)])
	var drawn: MotionRender = MotionRender.frames_of(player, [motion], false, fps)
	if drawn.poses.is_empty():
		_say("Nothing to draw: %s" % drawn.lines[0])
		return 0
	var sheet_at: Array = []
	for k: int in SHEET_MOST:
		sheet_at.append(roundi(float(k) * float(drawn.poses.size() - 1) / float(SHEET_MOST - 1)))
	return await render_poses(drawn.poses, fps, func(_n: int) -> float: return 0.0, sheet_at, job, view,
		motion.name)


## Draw [param poses] (one a frame: brick id -> Transform3D of the parts
## that move), [param fps] a second, the model turned [param turn_at] (frame
## -> turns) round, and keep them as File, Render's Animation keeps its
## frames (MotionRender): a WebP, and on the desktop the frames and an MP4,
## named after the model and [param motion]. [param sheet_at]: the frames
## kept for [method sheet]. [param on_what_moves]: framed on what the parts
## sweep, from [param view]'s direction. A motion is rendered this way
## (render_motion, Render animation), as its frames. Returns how many were
## drawn.
func render_poses(poses: Array, fps: int, turn_at: Callable, sheet_at: Array,
		job: Working.Job = null, view: String = "", motion: String = "Animation",
		on_what_moves: bool = false) -> int:
	if _working or world == null or poses.is_empty():
		return 0
	_ready_renderer()
	_working = true
	_set_buttons()
	_last = {}
	var started: int = Time.get_ticks_msec()
	var frames: int = poses.size()
	var chosen: RenderSettings = settings.copy()
	chosen.fps = fps
	chosen.frames = frames
	if not view.is_empty():
		chosen.view = view
	chosen.on_what_moves = on_what_moves
	var output := RenderOutput.new()
	output.folder = folder
	output.begin_animation(str(named.call()), motion, chosen)
	_sheet = {}
	_sheet_fps = fps
	var stop: Callable = renderer.cancel
	if job != null:
		job.count(0, frames)
		job.cancel_wanted.connect(stop)
	var done: int = await MotionRender.draw(renderer, world, chosen, poses, turn_at, output,
		func(n: int, image: Image) -> void:
			_frame.texture = ImageTexture.create_from_image(image)
			_frame.visible = visible
			if sheet_at.has(n):
				_sheet[n] = image
			if job != null:
				job.count(n + 1))
	if job != null:
		job.cancel_wanted.disconnect(stop)
	var lines := PackedStringArray()
	if done == frames:
		_say("Putting the frames together…")
		if job != null:
			job.say(_status.text)
			job.count(0, 0)
		lines = await output.finish_turntable()
	_working = false
	_set_buttons()
	var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
	if lines.is_empty():
		_say("Cancelled." if done < frames else "Nothing was kept.")
		_progress.value = 0.0
		return done
	_progress.value = 1.0
	_last = {"frames": done, "bytes": output.last_bytes, "name": output.base_name() + ".webp",
		"paths": Array(output.paths), "kept": "; ".join(lines), "seconds": roundi(seconds)}
	_say("%d frames — %s — %.0f s." % [done, "; ".join(lines), seconds])
	_fit_later()
	return done


## [param poses] drawn as stills, framed on what they move (as a session's
## animation is), from [param view] (StudioRender.VIEWS), [param size] each: the pictures, or [] when there
## is nothing to draw with or a render is under way. Nothing is kept.
func draw_stills(poses: Array, size: Vector2i = Vector2i(480, 300), view: String = "hero") -> Array:
	if _working or world == null or poses.is_empty() or not StudioRender.possible():
		return []
	_ready_renderer()
	if renderer.is_busy():
		return []
	var chosen: RenderSettings = settings.copy()
	chosen.size = size
	chosen.view = view if StudioRender.VIEWS.has(view) else "hero"
	chosen.frames = poses.size()
	var out: Array = []
	await renderer.animate(world, chosen, poses.size(), func(n: int) -> Dictionary: return poses[n],
		func(_n: int) -> float: return 0.0, poser.reach(poses),
		func(_n: int, image: Image) -> void: out.append(image))
	return out


func _ready_renderer() -> void:
	if renderer == null:
		renderer = StudioRender.new()
		add_child(renderer)
		renderer.progress.connect(func(fraction: float, words: String) -> void:
			_fraction = fraction
			_progress.value = fraction
			if _working:
				_say("%s… %d%%" % [words.substr(0, 1).to_upper() + words.substr(1),
					roundi(fraction * 100.0)]))
	renderer.library = library
	renderer.scenery = scenery
	renderer.eye = eye
	renderer.look = look
	renderer.rig_lights = rig_lights
	# What the frames sweep is read off the model (Poser.reach).
	poser.world = world
	poser.library = library


## A few frames of the last render, frame number -> Image: at its keys, or
## spread over it. A session cannot see the window or play a file, and the
## first that animated 8808-1's steering said it had not watched it.
var _sheet: Dictionary = {}
## The rate the last render's frames were drawn at, a second.
var _sheet_fps: int = 12
const SHEET_MOST := 4
const SHEET_WIDE := 480
const SHEET_GAP := 4


## Which of animate_model's frames go in the sheet: each key's, or four
## spread out when there are more keys or none.
func _sheet_frames(frames: int) -> Array:
	var out: Array = []
	if animation.keys.size() >= 2 and animation.keys.size() <= SHEET_MOST:
		for key: Dictionary in animation.keys:
			out.append(clampi(roundi(float(key["t"]) * animation.fps), 0, frames - 1))
	else:
		for n: int in SHEET_MOST:
			out.append(roundi(float(n) * float(frames - 1) / float(SHEET_MOST - 1)))
	return out


## The last render's sheet as one picture, two frames to a row, each at
## most SHEET_WIDE across; null when nothing was drawn. [param times] is
## filled with each frame's time, in order. At half of 480 × 300 a session
## found them "too small to judge", and posed the model again to look.
func sheet(times: Array = []) -> Image:
	if _sheet.is_empty():
		return null
	var numbers: Array = _sheet.keys()
	numbers.sort()
	var images: Array = []
	for n: Variant in numbers:
		images.append(_sheet[n])
		times.append(float(n) / float(maxi(_sheet_fps, 1)))
	return sheet_of(images)


## [param images] as one picture, two to a row, each at most SHEET_WIDE
## across, a line between them; null for none.
static func sheet_of(images: Array) -> Image:
	if images.is_empty():
		return null
	var first: Image = images[0]
	var scale: float = minf(1.0, float(SHEET_WIDE) / float(maxi(first.get_width(), 1)))
	var cell := Vector2i(maxi(roundi(first.get_width() * scale), 1),
		maxi(roundi(first.get_height() * scale), 1))
	var across: int = mini(images.size(), 2)
	var rows: int = ceili(float(images.size()) / 2.0)
	# A line between the frames: without one, a session read the crane in
	# four frames as one picture of it moving about the frame.
	var step: Vector2i = cell + Vector2i(SHEET_GAP, SHEET_GAP)
	var out := Image.create(step.x * across - SHEET_GAP, step.y * rows - SHEET_GAP, false,
		Image.FORMAT_RGBA8)
	out.fill(Color(0.35, 0.35, 0.38))
	for k: int in images.size():
		var frame: Image = (images[k] as Image).duplicate()
		frame.convert(Image.FORMAT_RGBA8)
		frame.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(frame, Rect2i(Vector2i.ZERO, cell), Vector2i((k % 2) * step.x, (k / 2) * step.y))
	return out


func is_rendering() -> bool:
	return _working


## What the last render said: where it was written, or why nothing was.
func rendered_words() -> String:
	return _status.text


## What the panel says now.
func status_words() -> String:
	return _status.text


## Which buttons answer now: none while a render draws; only Stop while a
## motion plays or Record listens.
func _set_buttons() -> void:
	var busy: bool = _working or _recording
	for row: Dictionary in _row_buttons:
		for key: String in ["play", "back", "edit", "pick"]:
			var button: BaseButton = row[key]
			if is_instance_valid(button):
				button.disabled = busy or (_playing and button != _stop_button and key != "pick")
	for button: Button in _keep_buttons:
		if is_instance_valid(button):
			button.disabled = busy or _playing
	_play_all.disabled = busy or (_playing and _stop_button != _play_all)
	_new.disabled = busy or _playing
	_new_sequence.disabled = busy or _playing
	_seq_play.disabled = busy or (_playing and _stop_button != _seq_play)
	_seq_reverse.disabled = busy or (_playing and _stop_button != _seq_reverse)
	_seq_back.disabled = _working
	_seq_remove.disabled = busy or _playing
	_seq_name.editable = not busy
	_seq_add.disabled = busy or _playing or _seq_pick.item_count == 0
	for n: int in _seq_buttons.size():
		var row: Dictionary = _seq_buttons[n]
		var still: bool = busy or _playing
		for key: String in ["up", "down", "out"]:
			var button: Button = row[key]
			if is_instance_valid(button):
				button.disabled = still or (key == "up" and n == 0) \
					or (key == "down" and n == _seq_buttons.size() - 1)
	var motion: Motions.Motion = _edited()
	var empty: bool = motion == null or (motion.tracks.is_empty() and motion.driver == null)
	_edit_play.disabled = busy or empty or (_playing and _stop_button != _edit_play)
	_edit_reverse.disabled = busy or empty or (_playing and _stop_button != _edit_reverse)
	_record.disabled = _working or _playing
	_back.disabled = _working
	_remove.disabled = busy or _playing
	_name.editable = not busy
	_time.editable = not (busy or _playing)
	for part: Dictionary in _joint_parts:
		(part["slider"] as HSlider).editable = not (busy or _playing)
	var has: bool = _view == "edit" and not empty or _view != "edit" and not _chosen.is_empty()
	_render.disabled = _working or _recording or _playing or not has
	_cancel.visible = _working


func _process(delta: float) -> void:
	if _recording:
		_record_frame()
	if _playing:
		if grabbing != null and grabbing.is_grabbing():
			_stop_playing()
		else:
			_frame_at += delta * float(MotionPlayer.PLAY_FPS)
			var n: int = int(_frame_at)
			if n >= _frames.size():
				if _loop.button_pressed and _frames.size() > 1:
					_frame_at = 0.0
					n = 0
				else:
					_stop_playing()
					_say(_stop_words)
					n = -1
			if n >= 0 and n != _shown:
				_shown = n
				_draw_frame(_frames[n])
	elif not _recording and not _working and _held == null:
		# Something else changed the motions or the model: an undo, a redo,
		# a motion a session defined, another model opened.
		if world.generation() != _seen_generation:
			_suggested = player.suggest()
			_draft = null
			_view = "list"
			_refresh()
		elif not _same_history(_seen_history) or world.motions != _seen_motions:
			if world.revision != _seen_revision:
				_look = null
				_undraw()
			_refresh()
	_tell_page()


## The history as it stands: its depth and its newest step, the same
## dictionary until something is done, undone or redone.
func _history_now() -> Array:
	return [builder.history_depth(), builder.last_step() if builder.history_depth() > 0 else null]


func _same_history(seen: Array) -> bool:
	return seen.size() == 2 and int(seen[0]) == builder.history_depth() \
		and (builder.history_depth() == 0 or is_same(seen[1], builder.last_step()))


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	# A drag's own Escape puts it back.
	if grabbing != null and grabbing.is_grabbing():
		return
	if _working:
		renderer.cancel()
	elif _recording:
		stop_recording()
	elif _playing:
		_stop_playing()
	elif _view != "list":
		back_to_list()
	else:
		close()
	get_viewport().set_input_as_handled()


# -- building ------------------------------------------------------------------------


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.95)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 11
	backing.content_margin_bottom = 12
	add_theme_stylebox_override("panel", backing)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.text = "Motions"
	_title.add_theme_font_size_override("font_size", 14)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_close = _button(header, "Close", close, "Back to building (Escape)")
	_body = ScrollContainer.new()
	_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.custom_minimum_size = Vector2(WIDE, 0)
	column.add_child(_body)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	_body.add_child(inner)
	_build_list(inner)
	_build_editor(inner)
	_build_sequence(inner)
	column.add_child(HSeparator.new())
	var rendering := HBoxContainer.new()
	rendering.add_theme_constant_override("separation", 6)
	column.add_child(rendering)
	_render = _button(rendering, "Render animation", func() -> void: render_animation(),
		"Draw the chosen motion and keep it: an animated WebP, and on the desktop the frames and an MP4")
	_rate = OptionButton.new()
	_rate.add_theme_font_size_override("font_size", 12)
	_rate.focus_mode = Control.FOCUS_NONE
	for rate: int in RATES:
		_rate.add_item("%d a second" % rate)
	_rate.tooltip_text = "Frames a second"
	rendering.add_child(_rate)
	_size = OptionButton.new()
	_size.add_theme_font_size_override("font_size", 12)
	_size.focus_mode = Control.FOCUS_NONE
	for size: Array in SIZES:
		_size.add_item(str(size[0]))
	_size.item_selected.connect(func(index: int) -> void:
		settings.size = SIZES[index][1])
	rendering.add_child(_size)
	_cancel = _button(rendering, "Cancel", func() -> void:
		if renderer != null:
			renderer.cancel(), "Stop rendering (Escape)")
	_cancel.visible = false
	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.step = 0.001
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 5)
	column.add_child(_progress)
	_frame = TextureRect.new()
	_frame.custom_minimum_size = Vector2(WIDE, 120)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_frame)
	# The last frame drawn, once a render has drawn one.
	_frame.visible = false
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(WIDE, 0)
	_status.max_lines_visible = 6
	_status.modulate = Color(1, 1, 1, 0.8)
	column.add_child(_status)


func _heading(into: Control, words: String) -> Label:
	var heading := Label.new()
	heading.text = words
	heading.add_theme_font_size_override("font_size", 12)
	heading.modulate = Color(1, 1, 1, 0.55)
	into.add_child(heading)
	return heading


func _build_list(into: Control) -> void:
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 6)
	into.add_child(_list_box)
	_heading(_list_box, "The model's motions")
	_motion_rows = VBoxContainer.new()
	_motion_rows.add_theme_constant_override("separation", 3)
	_list_box.add_child(_motion_rows)
	_none = Label.new()
	_none.text = "None yet. A motion is a named movement of the model: Open the doors, Lift the boom."
	_none.add_theme_font_size_override("font_size", 12)
	_none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_none.custom_minimum_size = Vector2(WIDE - 24, 0)
	_list_box.add_child(_none)
	var playing := HBoxContainer.new()
	playing.add_theme_constant_override("separation", 8)
	_list_box.add_child(playing)
	_play_all = _button(playing, "Play all", play_all,
		"Play every motion in order, each after the one it follows")
	_loop = CheckBox.new()
	_loop.text = "Loop"
	_loop.tooltip_text = "Play it again and again until Stop"
	_loop.add_theme_font_size_override("font_size", 12)
	_loop.focus_mode = Control.FOCUS_NONE
	playing.add_child(_loop)
	_list_box.add_child(HSeparator.new())
	_suggest_heading = _heading(_list_box, "Suggested from what moves")
	_suggest_rows = VBoxContainer.new()
	_suggest_rows.add_theme_constant_override("separation", 3)
	_list_box.add_child(_suggest_rows)
	var making := HBoxContainer.new()
	making.add_theme_constant_override("separation", 6)
	_list_box.add_child(making)
	_new = _button(making, "New motion", new_motion,
		"Make a motion: name it, then Record and drag the parts, or set its joints one by one")
	_new_sequence = _button(making, "New sequence", new_sequence,
		"A motion made of the model's motions, in an order you choose: Show it all")


func _build_editor(into: Control) -> void:
	_edit_box = VBoxContainer.new()
	_edit_box.add_theme_constant_override("separation", 6)
	_edit_box.visible = false
	into.add_child(_edit_box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	_edit_box.add_child(top)
	_back = _button(top, "All motions", back_to_list, "Back to the list of the model's motions (Escape)")
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_remove = _button(top, "Remove", remove_motion, "Take this motion out of the model (undo puts it back)")
	var naming := HBoxContainer.new()
	naming.add_theme_constant_override("separation", 6)
	_edit_box.add_child(naming)
	var called := Label.new()
	called.text = "Name"
	called.add_theme_font_size_override("font_size", 12)
	naming.add_child(called)
	_name = LineEdit.new()
	_name.add_theme_font_size_override("font_size", 12)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.placeholder_text = "Open the dome"
	_name.max_length = 60
	_name.tooltip_text = "What a builder calls it: Open the dome, Extend the telescope"
	_name.text_submitted.connect(func(words: String) -> void:
		rename(words)
		_name.release_focus())
	_name.focus_exited.connect(func() -> void: rename(_name.text))
	naming.add_child(_name)
	var recording := HBoxContainer.new()
	recording.add_theme_constant_override("separation", 6)
	_edit_box.add_child(recording)
	_record = _button(recording, "Record", record,
		"Record drags: every drag of a part in the view, kept as keys at the times it happened")
	_record_words = Label.new()
	_record_words.text = RECORD_WORDS
	_record_words.add_theme_font_size_override("font_size", 11)
	_record_words.modulate = Color(1, 1, 1, 0.6)
	recording.add_child(_record_words)
	var playing := HBoxContainer.new()
	playing.add_theme_constant_override("separation", 6)
	_edit_box.add_child(playing)
	_edit_play = _button(playing, "Play", func() -> void: play(_edited().name if _edited() != null else ""),
		"Play it in the view")
	_edit_reverse = _button(playing, "Play backwards", func() -> void:
		play(_edited().name if _edited() != null else "", true),
		"Play it from its end to its start")
	_edit_reverse.set_meta("backwards", true)
	var timing := HBoxContainer.new()
	timing.add_theme_constant_override("separation", 6)
	_edit_box.add_child(timing)
	var at := Label.new()
	at.text = "At"
	at.add_theme_font_size_override("font_size", 12)
	timing.add_child(at)
	_time = HSlider.new()
	_style_slider(_time)
	_time.custom_minimum_size = Vector2(200, 18)
	_time.min_value = 0.0
	_time.max_value = 4.0
	_time.step = 0.05
	_time.tooltip_text = "The time in the motion: the model is drawn as it is then"
	_time.value_changed.connect(func(value: float) -> void:
		if not _quiet:
			set_time(value))
	timing.add_child(_time)
	_time_words = Label.new()
	_time_words.add_theme_font_size_override("font_size", 12)
	_time_words.custom_minimum_size = Vector2(44, 0)
	timing.add_child(_time_words)
	_heading(_edit_box, "Its joints")
	_joint_rows = VBoxContainer.new()
	_joint_rows.add_theme_constant_override("separation", 6)
	_edit_box.add_child(_joint_rows)
	_more = _button(_edit_box, "Show all joints", func() -> void:
		_all_joints = true
		_fill_editor()
		_set_buttons()
		_fit_later(), "Every joint in the model that moves, each with its slider")
	_more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_more.visible = false
	_key_row = HBoxContainer.new()
	_key_row.add_theme_constant_override("separation", 6)
	_key_row.visible = false
	_edit_box.add_child(_key_row)
	_key_words = Label.new()
	_key_words.add_theme_font_size_override("font_size", 12)
	_key_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_words.clip_text = true
	_key_words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_key_row.add_child(_key_words)
	_how = OptionButton.new()
	_how.add_theme_font_size_override("font_size", 12)
	_how.focus_mode = Control.FOCUS_NONE
	for words: String in HOW_WORDS:
		_how.add_item(words)
	_how.tooltip_text = "How it gets to this key: eased in and out, at one speed, or held until then"
	_how.item_selected.connect(func(index: int) -> void:
		if not _quiet:
			set_how(Motions.HOWS[index]))
	_key_row.add_child(_how)
	_drop_key = _button(_key_row, "Remove key", remove_key, "Take this key out")
	_driver_words = Label.new()
	_driver_words.add_theme_font_size_override("font_size", 12)
	_driver_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_driver_words.custom_minimum_size = Vector2(WIDE - 24, 0)
	_driver_words.visible = false
	_edit_box.add_child(_driver_words)


## The sequence editor: its name, Play and Play backwards, its motions in
## order, each with Up, Down and Take out, and Add for another of the
## model's motions at its end.
func _build_sequence(into: Control) -> void:
	_seq_box = VBoxContainer.new()
	_seq_box.add_theme_constant_override("separation", 6)
	_seq_box.visible = false
	into.add_child(_seq_box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	_seq_box.add_child(top)
	_seq_back = _button(top, "All motions", back_to_list, "Back to the list of the model's motions (Escape)")
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_seq_remove = _button(top, "Remove", remove_motion,
		"Take this sequence out of the model; its motions stay (undo puts it back)")
	var naming := HBoxContainer.new()
	naming.add_theme_constant_override("separation", 6)
	_seq_box.add_child(naming)
	var called := Label.new()
	called.text = "Name"
	called.add_theme_font_size_override("font_size", 12)
	naming.add_child(called)
	_seq_name = LineEdit.new()
	_seq_name.add_theme_font_size_override("font_size", 12)
	_seq_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seq_name.placeholder_text = "Show it all"
	_seq_name.max_length = 60
	_seq_name.tooltip_text = "What a builder calls it: Show it all"
	_seq_name.text_submitted.connect(func(words: String) -> void:
		rename(words)
		_seq_name.release_focus())
	_seq_name.focus_exited.connect(func() -> void:
		if _view == "sequence":
			rename(_seq_name.text))
	naming.add_child(_seq_name)
	var playing := HBoxContainer.new()
	playing.add_theme_constant_override("separation", 6)
	_seq_box.add_child(playing)
	_seq_play = _button(playing, "Play", func() -> void: play(_editing_name),
		"Play its motions in order, each from where the one before left the model")
	_seq_reverse = _button(playing, "Play backwards", func() -> void: play(_editing_name, true),
		"Play its motions backwards in reverse order: what Play opened, this closes")
	_seq_reverse.set_meta("backwards", true)
	_heading(_seq_box, "It plays, in order")
	_seq_rows = VBoxContainer.new()
	_seq_rows.add_theme_constant_override("separation", 3)
	_seq_box.add_child(_seq_rows)
	var adding := HBoxContainer.new()
	adding.add_theme_constant_override("separation", 6)
	_seq_box.add_child(adding)
	_seq_pick = OptionButton.new()
	_seq_pick.add_theme_font_size_override("font_size", 12)
	_seq_pick.focus_mode = Control.FOCUS_NONE
	_seq_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seq_pick.clip_text = true
	_seq_pick.tooltip_text = "Another of the model's motions to play at its end"
	adding.add_child(_seq_pick)
	_seq_add = _button(adding, "Add", func() -> void:
		if _seq_pick.selected >= 0:
			add_to_sequence(str(_seq_pick.get_item_metadata(_seq_pick.selected))),
		"Play the motion chosen at the end of this sequence")


func _button(into: Control, words: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	into.add_child(button)
	return button


## Rows taken out at once, so the panel is measured without them.
static func _clear(box: Container) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _fit_later() -> void:
	_fit.call_deferred()


## The lists as tall as they need, or as the window leaves room for above
## its foot, scrolling past that; the panel no bigger than what it shows.
func _fit() -> void:
	if not visible:
		return
	var parent: Control = get_parent() as Control
	var tall: float = parent.size.y if parent != null else get_viewport_rect().size.y
	var inner: Control = _body.get_child(0) as Control
	var wanted: float = inner.get_combined_minimum_size().y
	_body.custom_minimum_size.y = 0.0
	var others: float = get_combined_minimum_size().y
	var room: float = tall - position.y - FOOT - others
	_body.custom_minimum_size.y = clampf(wanted, minf(wanted, 80.0), maxf(room, 80.0))
	reset_size()


# -- for a browser test ---------------------------------------------------------------


func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var out: Dictionary = {"motions_close": _close, "motions_render": _render, "motions_cancel": _cancel,
		"motions_rate": _rate, "motions_size": _size}
	if _view == "list":
		out.merge({"motions_play_all": _play_all, "motions_loop": _loop, "motions_new": _new,
			"motions_new_sequence": _new_sequence})
		for n: int in _row_buttons.size():
			var row: Dictionary = _row_buttons[n]
			out["motion_pick_%d" % n] = row["pick"]
			out["motion_play_%d" % n] = row["play"]
			out["motion_back_%d" % n] = row["back"]
			out["motion_edit_%d" % n] = row["edit"]
		for n: int in _keep_buttons.size():
			out["motion_keep_%d" % n] = _keep_buttons[n]
	elif _view == "sequence":
		out.merge({"sequence_back": _seq_back, "sequence_remove": _seq_remove, "sequence_name": _seq_name,
			"sequence_play": _seq_play, "sequence_reverse": _seq_reverse, "sequence_pick": _seq_pick,
			"sequence_add": _seq_add})
		for n: int in _seq_buttons.size():
			out["sequence_up_%d" % n] = _seq_buttons[n]["up"]
			out["sequence_down_%d" % n] = _seq_buttons[n]["down"]
			out["sequence_out_%d" % n] = _seq_buttons[n]["out"]
	else:
		out.merge({"motions_back": _back, "motions_remove": _remove, "motions_name": _name,
			"motions_record": _record, "motions_play": _edit_play, "motions_reverse": _edit_reverse,
			"motions_time": _time, "motions_how": _how, "motions_drop_key": _drop_key})
		for n: int in _joint_parts.size():
			out["motions_joint_%d" % n] = _joint_parts[n]["slider"]
	var shown: Dictionary = {}
	for key: String in out:
		var control: Control = out[key]
		if is_instance_valid(control) and control.is_visible_in_tree():
			shown[key] = control
	return shown


## What the panel is doing, for a browser test: window.brickworksMotions,
## with each joint slider's ends and the time slider's on the page, so a
## click can set them as a person's would. Web builds only.
func _tell_page() -> void:
	if not OS.has_feature("web"):
		return
	var now: int = Time.get_ticks_msec()
	if now - _told_page_at < 500:
		return
	_told_page_at = now
	var ratio: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
	var per_css: float = float(ratio) if ratio != null and float(ratio) > 0.0 else 1.0
	var to_window: Transform2D = get_viewport().get_final_transform()
	var ends := func(control: Control) -> Dictionary:
		if not control.is_visible_in_tree():
			return {}
		var rect: Rect2 = to_window * control.get_global_rect()
		return {"x0": roundi(rect.position.x / per_css), "x1": roundi(rect.end.x / per_css),
			"y": roundi(rect.get_center().y / per_css)}
	var motions: Array = []
	for motion: Motions.Motion in _motions().list:
		motions.append({"name": motion.name, "seconds": snappedf(_motions().seconds_of(motion), 0.01),
			"tracks": motion.tracks.size(), "sequence": Array(motion.sequence)})
	var joints: Array = []
	var edited: Motions.Motion = _edited()
	for part: Dictionary in _joint_parts:
		var joint: Motions.Joint = part["joint"]
		var track: Motions.Track = _track_of(edited, joint) if edited != null else null
		var entry: Dictionary = {"name": player.joint_name(joint), "mode": joint.mode,
			"place": snappedf((part["slider"] as HSlider).value, 0.01),
			"min": (part["slider"] as HSlider).min_value, "max": (part["slider"] as HSlider).max_value,
			"keys": track.keys.size() if track != null else 0}
		entry.merge(ends.call(part["slider"]))
		joints.append(entry)
	var fps: int = int(RATES[maxi(_rate.selected, 0)])
	var chosen: Motions.Motion = edited if _view != "list" else _motions().named(_chosen)
	var state: Dictionary = {"open": visible, "view": _view, "motions": motions,
		"suggested": _offered().map(func(one: Motions.Motion) -> String: return one.name),
		"chosen": chosen.name if chosen != null else "", "editing": edited.name if edited != null else "",
		"at": _at, "time": ends.call(_time), "time_max": _time.max_value, "joints": joints,
		"recording": _recording, "playing": _playing, "working": _working,
		"fraction": snappedf(_fraction, 0.01), "status": _status.text,
		"frames_planned": roundi(_motions().seconds_of(chosen) * fps) + 1 if chosen != null else 0}
	if renderer != null:
		state["worst_frame_ms"] = roundi(renderer.worst_frame_ms)
		state["worst_step"] = renderer.worst_step
	for key: String in _last:
		state[key] = _last[key]
	var said: String = JSON.stringify(state)
	if said == _told_page:
		return
	_told_page = said
	JavaScriptBridge.eval("window.brickworksMotions = %s" % said, true)


## A joint's keys on a strip of the motion's time: a mark at each key,
## the chosen one in the accent, and a line where the editor's time is.
## A key pressed is chosen and can be dragged along; a press between the
## keys sets the time there.
class KeyStrip extends Control:
	signal picked(index: int)
	signal moved(index: int, t: float)
	signal timed(t: float)

	var times: Array = []
	## The seconds the strip spans, from 0.
	var span: float = 4.0
	var now: float = 0.0
	var chosen: int = -1
	var _dragging: int = -1
	var _drag_t: float = 0.0
	const NEAR := 7.0
	const INSET := 8.0

	func _x_of(t: float) -> float:
		return INSET + (size.x - 2.0 * INSET) * clampf(t / maxf(span, 0.01), 0.0, 1.0)

	func _t_of(x: float) -> float:
		return clampf((x - INSET) / maxf(size.x - 2.0 * INSET, 1.0), 0.0, 1.0) * span

	func _draw() -> void:
		var mid: float = size.y * 0.5
		draw_rect(Rect2(INSET, mid - 2.0, size.x - 2.0 * INSET, 4.0), Color(1, 1, 1, 0.16))
		draw_line(Vector2(_x_of(now), 0.0), Vector2(_x_of(now), size.y), Look.ACCENT, 1.0)
		for n: int in times.size():
			var t: float = _drag_t if n == _dragging else float(times[n])
			var x: float = _x_of(t)
			var r: float = 4.5
			var colour: Color = Look.ACCENT if n == chosen else Color(1, 1, 1, 0.85)
			draw_colored_polygon(PackedVector2Array([Vector2(x, mid - r), Vector2(x + r, mid),
				Vector2(x, mid + r), Vector2(x - r, mid)]), colour)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var press: InputEventMouseButton = event
			if press.pressed:
				var nearest: int = -1
				var best: float = NEAR
				for n: int in times.size():
					var off: float = absf(_x_of(float(times[n])) - press.position.x)
					if off <= best:
						best = off
						nearest = n
				if nearest >= 0:
					chosen = nearest
					_dragging = nearest
					_drag_t = float(times[nearest])
					picked.emit(nearest)
				else:
					timed.emit(_t_of(press.position.x))
				accept_event()
			elif _dragging >= 0:
				var index: int = _dragging
				_dragging = -1
				if absf(_drag_t - float(times[index])) > 0.02:
					moved.emit(index, _drag_t)
				queue_redraw()
				accept_event()
		elif event is InputEventMouseMotion and _dragging >= 0:
			_drag_t = snappedf(_t_of((event as InputEventMouseMotion).position.x), 0.05)
			queue_redraw()
			accept_event()
