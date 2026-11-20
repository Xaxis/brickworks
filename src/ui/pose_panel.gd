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
## The camera is keyed in a motion too (camerakeys, docs/APP_UX10.md gap
## 12): Key the camera keeps where the window looks from at the editor's
## time, Turntable makes two keys a full turn round the model; Play and
## Render animation go through its keys, the person's own turning of the
## view held back meanwhile and given back at Stop. Keys of any track, the
## camera's among them, are picked together by Ctrl+click (Cmd on a Mac):
## Delete takes them all out in one step, and a drag of one moves them all.
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
## By finger, what the status line says, for the line over the model
## (PhoneShell.say): there the status scrolls with the list and may be out
## of sight when a press says something (smalls7).
signal said(words: String)

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
## The view the body was last scrolled for: a finger starts each view at its top.
var _scrolled_for := ""
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
## New motion and New sequence, in the list's foot or, by finger, the header.
var _making: HBoxContainer
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
## The list's joints locked (jointlock): its heading, its rows, and each
## row's Unlock.
var _lock_heading: Label
var _lock_rows: VBoxContainer
var _unlock_buttons: Array = []
## The joint rows: [{joint, slider, readout, strip, droop}], as listed.
var _joint_parts: Array = []

## Whether the pose shown holds (posehold), a label a line, and what it was
## last weighed of: the model, the pose drawn over it and when.
var _hold: VBoxContainer
var _hold_report: Balance.Report = null
var _hold_key: Array = []
var _hold_at: int = 0
## At most this often, ms: a slider dragged draws a pose a frame.
const HOLD_EVERY_MS := 120

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
## Whether the chosen key ([member _key_index]) is the camera's.
var _key_camera: bool = false
## Keys picked together (Ctrl+click, Cmd on a Mac): each [whose, seconds],
## whose a Motions.Joint or [constant CAMERA]. Delete takes them all out in
## one step; a drag of one moves them all.
var _picked: Array = []
const CAMERA := "camera"
## Whether Delete takes the picked keys out: a key was pressed last, not
## somewhere else.
var _keys_hot: bool = false
## The camera's section of the editor (camerakeys).
var _camera_heading: Label
var _camera_words: Label
var _camera_key: Button
var _camera_turn: Button
var _camera_strip: KeyStrip
## Where each frame playing puts the camera (MotionPlayer.camera_view, or
## null), and the window's view as it was before: given back at Stop.
var _cameras: Array = []
var _view_before: Dictionary = {}
var _fov_before: float = 0.0
var _projection_before: int = Camera3D.PROJECTION_PERSPECTIVE
var _size_before: float = 0.0
var _holding_view: bool = false
## What the status says while a motion's camera holds the view.
const HELD_WORDS := "The view follows the motion's camera keys: Stop gives it back."
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
## The model the last render's frame shown is of (BrickWorld.generation):
## another model's is not shown.
var _frame_for: int = -1
var _fraction: float = 0.0
var _last: Dictionary = {}
var _quiet: bool = false
## What was last seen of the model and its history: any change refreshes
## the lists (an undo, a motion a session defined).
var _seen_generation: int = -1
## The world the frames playing are of (BrickWorld.generation): replaced, the
## play stops (camreview M3).
var _playing_generation: int = -1
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
	# Its column's height is its room: the column is laid out after the
	# panel opens, and again as the window or the panels over it change.
	var parent: Control = get_parent() as Control
	if parent != null:
		parent.resized.connect(_fit_later)


func open() -> void:
	visible = true
	set_process(true)
	_view = "list"
	_draft = null
	_editing_name = ""
	_suggested = player.suggest() if player != null else []
	# Weighed at once, as it stands.
	_hold_key = []
	_hold_at = 0
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
	if poser.joints.is_empty() or poser.outdated() or not (poser.holds() or poser.read_back()):
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


# -- locks --------------------------------------------------------------------------------


## The parts [param joint] (a motion's, a row's) turns, as a drag takes it by
## them, and the two it turns between: [moving (id -> true), [its own part,
## the one it is on]]; [{}, []] when a drag finds no joint there.
func _lock_sides(joint: Motions.Joint) -> Array:
	var ids: Array = player.parts_of(joint) if player != null else []
	if ids.is_empty() or grabbing == null:
		return [{}, []]
	var picked: Grab = grabbing.picked_of(ids)
	var pair: Array = picked.lock_pair()
	var moving: Dictionary = {}
	if not pair.is_empty():
		for id: int in picked.bodies.parts_of(picked.moving_bodies):
			moving[id] = true
	return [moving, pair]


## The words of the lock [param joint] is held by (Motions.lock_words); ""
## when it is not locked.
func lock_said(joint: Motions.Joint) -> String:
	var motions: Motions = _motions()
	if motions.locks.is_empty():
		return ""
	var sides: Array = _lock_sides(joint)
	var lock: Motions.Lock = motions.lock_split(sides[0], world, builder)
	return "" if lock == null else Motions.lock_words(lock, world, library, builder)


## A row's Lock pressed: locked if it was not, else unlocked.
func toggle_lock(joint: Motions.Joint) -> void:
	var sides: Array = _lock_sides(joint)
	_say(set_lock(sides[0], sides[1], lock_said(joint).is_empty()))
	_refresh()


## A lock of the list's Unlock: let go, one step to undo.
func unlock(lock: Motions.Lock) -> void:
	var motions: Motions = _motions()
	if not motions.locks.has(lock):
		return
	var name: String = Motions.lock_name(lock, world, library, builder)
	var had: Motions = motions.copy()
	motions.locks.erase(lock)
	builder.record([{"undo": "motions", "motions": had}], "unlocked %s" % name)
	_seen_history = _history_now()
	_seen_motions = world.motions
	_say("Unlocked %s: it moves again. Undo locks it again." % name)
	_refresh()
	changed.emit()


## Lock ([param on]) or unlock the joint that turns [param moving] (id ->
## true) between [param pair] ([its own part, the one it is on]): one step to
## undo, what it did in words. Locking one locked, or unlocking one not, is
## said and changes nothing. What pose_model's lock= and a row's Lock do.
func set_lock(moving: Dictionary, pair: Array, on: bool) -> String:
	var motions: Motions = _motions()
	if pair.size() != 2 or world.get_brick(int(pair[0])) == null or world.get_brick(int(pair[1])) == null:
		return "That is on no joint a drag turns or slides: nothing to lock."
	var held: Motions.Lock = motions.lock_split(moving, world, builder)
	var lift: Vector3 = player.store.lift() if player != null and player.store != null else Vector3.ZERO
	var lock: Motions.Lock = held if held != null else Motions.lock_of(int(pair[0]), int(pair[1]), world, lift)
	var name: String = Motions.lock_name(lock, world, library, builder)
	var named: String = name.left(1).to_upper() + name.substr(1)
	if on == (held != null):
		return "%s is %s already: nothing changed." % [named, "locked" if on else "not locked"]
	var had: Motions = motions.copy()
	if on:
		motions.locks.append(lock)
	else:
		# Every lock this joint's turn would break: one joint, all of it.
		while held != null:
			motions.locks.erase(held)
			held = motions.lock_split(moving, world, builder)
	builder.record([{"undo": "motions", "motions": had}], ("locked %s" if on else "unlocked %s") % name)
	_seen_history = _history_now()
	_seen_motions = world.motions
	changed.emit()
	if on:
		return ("Locked %s: it keeps its angle and its slide. A drag of either part, R, a handle, "
			+ "Simulate's driver and Claude's moves are refused until it is unlocked; undo takes "
			+ "the lock off.%s") % [name, _copies_words(lock)]
	return "Unlocked %s: it moves again. Undo locks it again." % name


## What a lock of one copy of a sub-model leaves: which copy it is in, and
## that the joints of its other copies still move (a lock is of two parts,
## [Motions.Lock]); "" when the sub-model it is in has no other copy
## (jlreview L1: the answer named neither).
func _copies_words(lock: Motions.Lock) -> String:
	if assemblies == null:
		return ""
	var a: int = Motions.lock_part(lock.a, world, builder)
	var brick: BrickWorld.Brick = world.get_brick(a) if a != 0 else null
	var path: String = Assemblies.path_of(brick) if brick != null else ""
	# The innermost sub-model round it that is placed more than once.
	while not path.is_empty():
		var others: PackedStringArray = assemblies.copies_of(path)
		if not others.is_empty():
			var named := PackedStringArray()
			for one: String in others.slice(0, 10):
				named.append(Assemblies.label(one))
			var more: int = others.size() - named.size()
			return (" Only in this copy, %s (copy %d of %d): the same joint in the other %s (%s%s) still moves; "
				+ "lock each on its own row.") % [Assemblies.label(path),
				Assemblies.copy_of(Assemblies.leaf(path)), others.size() + 1,
				"copy" if others.size() == 1 else "%d copies" % others.size(), ", ".join(named),
				" and %d more" % more if more > 0 else ""]
		path = Assemblies.parent_of(path)
	return ""


func _motions() -> Motions:
	return player.motions() if player != null else Motions.new()


## [param words] in the status line, whole: the panel grows to them, and
## where the window has no room for all of them they are all in its tooltip
## (_fit). A sequence's words ran past six lines and were cut off.
func _say(words: String) -> void:
	if words == _status.text:
		return
	_status.text = words
	_status.tooltip_text = words
	if Phone.on():
		said.emit(words)
	_fit_later()


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
	if _frame_for != world.generation():
		_frame.visible = false
	if Phone.on() and _view != _scrolled_for:
		# The list's scroll left the editor's Record below the fold (phonewalk: 8 taps to record).
		_body.scroll_vertical = 0
	_scrolled_for = _view
	_list_box.visible = _view == "list"
	_making.visible = _view == "list"
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
	_clear(_lock_rows)
	_unlock_buttons.clear()
	_lock_heading.visible = not motions.locks.is_empty()
	_lock_rows.visible = not motions.locks.is_empty()
	for lock: Motions.Lock in motions.locks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_lock_rows.add_child(row)
		var words := Label.new()
		var name: String = Motions.lock_name(lock, world, library, builder)
		words.text = name.left(1).to_upper() + name.substr(1)
		words.tooltip_text = words.text
		words.mouse_filter = Control.MOUSE_FILTER_PASS
		words.add_theme_font_size_override("font_size", 12)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.clip_text = true
		words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(words)
		var held: Motions.Lock = lock
		_unlock_buttons.append(_button(row, "Unlock", func() -> void: unlock(held),
			"Let it move again: a drag, R, a handle, Simulate and Claude may turn or slide it"))
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
	if motion.path != null:
		parts.append("driven %s" % motion.path.said())
	var out: String = "%s: %s, over %s s" % [motion.name, ", ".join(parts), Motions.num(motion.length(), 1)]
	# What turns as it is driven, a sentence of its own, so each is said
	# whole in every language: inside the first, the drive's words were
	# left in English ("Rouler et tourner à gauche : driven 32 tenons"), and
	# its stop came before ", over 7.9 s".
	return out if motion.path == null else "%s. %s" % [out, player.path_words(motion.path)]


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
			_say(_with_let_go("Kept %s. Play plays it; undo takes it out." % Motions.quoted(name), motions))
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
	if played.drive != null and played.cameras.is_empty():
		_frame_drive(played)
	_begin_playing(played.frames, button, played.cameras)


## The view framed on all a path takes the model over, so it is seen
## driving all the way rather than out of the window; left as it is when
## all of it is in sight already (unit drive).
func _frame_drive(played: MotionPlayer.Played) -> void:
	var box: AABB = player.drive_box(played)
	if eye == null or not eye.has_method("frame") or not box.has_volume() or MotionPlayer.box_in_view(eye, box):
		return
	eye.call("frame", box)


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
	_begin_playing(run.frames, button, run.cameras)


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
	_begin_playing(run.frames, _play_all, run.cameras)


## [param frames] drawn one after another, [param cameras] (one a frame,
## MotionPlayer.camera_view or null) putting the window's view where a
## motion's camera keys have it, the person's own hand held back until Stop.
func _begin_playing(frames: Array, button: Button, cameras: Array = []) -> void:
	_frames = frames
	_cameras = cameras if cameras.size() == frames.size() and cameras.any(func(one: Variant) -> bool:
		return one != null) else []
	_frame_at = 0.0
	_shown = -1
	_playing = not frames.is_empty()
	_playing_generation = world.generation()
	_say(_stop_words if _cameras.is_empty() or not _playing else "%s %s" % [_stop_words, HELD_WORDS])
	if not _playing:
		return
	if not _cameras.is_empty():
		_hold_view()
	_stop_button = button
	if button != null:
		button.text = "Stop"
	_set_buttons()


## The window's view kept, to be given back at Stop, and held for the
## motion's camera: a turn, slide or zoom by hand is put back and said.
func _hold_view() -> void:
	if _holding_view or eye == null or not eye.has_method("hold_at"):
		return
	_holding_view = true
	_view_before = eye.call("aim")
	_fov_before = eye.fov
	_projection_before = eye.projection
	_size_before = eye.size
	if not eye.is_connected("held_back", _on_held_back):
		eye.connect("held_back", _on_held_back)


func _on_held_back(words: String) -> void:
	if _holding_view and _status.text != words:
		_say(words)


## The view where frame [param n]'s camera has it, when it has one.
func _show_camera(n: int) -> void:
	if not _holding_view or n >= _cameras.size() or _cameras[n] == null:
		return
	eye.call("hold_at", _cameras[n], HELD_WORDS)


## The view as it was before the motion's camera held it, eased back to;
## with [param aim_back] false, let go with the person's lens and left where
## it is (the model it looked at is gone).
func _give_view_back(aim_back: bool = true) -> void:
	if not _holding_view:
		return
	_holding_view = false
	_cameras = []
	eye.call("let_go")
	eye.projection = _projection_before as Camera3D.ProjectionType
	eye.size = _size_before
	eye.fov = _fov_before
	if aim_back:
		eye.call("aim_at", _view_before)


func _stop_playing(aim_back: bool = true) -> void:
	_playing = false
	_frames = []
	_give_view_back(aim_back)
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
	_key_camera = false
	_picked.clear()
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
	_key_camera = false
	_picked.clear()
	_look = null
	_refresh()
	# A phone's keyboard would come up over the sheet and its Record: the
	# name is typed over by a tap in it there.
	if not Phone.on():
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
	_picked.clear()
	_key_camera = false
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
		if not motion.has_own():
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
	# A refused line the change let go is said (Motions.let_go_words).
	if not motions.let_go.is_empty():
		_say(motions.let_go_words())


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
	_fill_path(motion)
	_fill_camera(motion)
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
	# Its lock (jointlock): a word on the row, pressed by a mouse or a finger.
	var locked: String = lock_said(joint)
	var lock := _button(top, "Locked" if not locked.is_empty() else "Lock",
		func() -> void: toggle_lock(joint),
		"Locked, it keeps its angle and its slide: a drag, R, a handle, Simulate and Claude are refused until it is unlocked")
	lock.toggle_mode = true
	lock.set_pressed_no_signal(not locked.is_empty())
	lock.accessibility_name = "%s: %s" % [called.text, lock.text]
	if Phone.on():
		lock.custom_minimum_size = Vector2(Phone.px(get_viewport(), Phone.TARGET),
			Phone.px(get_viewport(), Phone.TARGET))
	var slider := HSlider.new()
	slider.accessibility_name = called.text
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
	if not locked.is_empty():
		slider.editable = false
		slider.tooltip_text = locked
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
	# A fingertip tall for a finger, its keys taken as near.
	if Phone.on():
		strip.custom_minimum_size.y = Phone.px(get_viewport(), Phone.TARGET)
		strip.near = Phone.px(get_viewport(), Phone.TARGET * 0.5)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.span = _time.max_value
	strip.now = _at
	strip.tooltip_text = "Its keys: a key pressed is chosen, dragged it moves in time; pressed between, the time goes there"
	if track != null:
		for key: Array in track.keys:
			strip.times.append(float(key[0]))
	if _key_joint == joint and not _key_camera:
		strip.chosen = _key_index
	strip.also = _picked_indices(joint, track.keys if track != null else [])
	strip.picked.connect(func(index: int, adding: bool) -> void: _pick_key(joint, index, adding))
	strip.moved.connect(func(index: int, t: float) -> void: _move_key(joint, index, t))
	strip.let_go.connect(func(index: int, adding: bool) -> void: _let_go_key(joint, index, adding))
	strip.timed.connect(func(t: float) -> void: set_time(t))
	strip.visible = track != null
	row.add_child(strip)
	# Where the joint it turns droops (posehold): how far over, by the row.
	var droop := Label.new()
	droop.add_theme_font_size_override("font_size", 11)
	droop.add_theme_color_override("font_color", BalanceMark.TIPS.lerp(Color.WHITE, 0.35))
	droop.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	droop.custom_minimum_size = Vector2(WIDE - 24, 0)
	droop.visible = false
	row.add_child(droop)
	var listed := {"joint": joint, "slider": slider, "readout": readout, "strip": strip, "droop": droop,
		"lock": lock}
	_joint_parts.append(listed)
	_mark_row(listed)


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
	if _camera_strip != null:
		_camera_strip.now = _at
		_camera_strip.queue_redraw()
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


## A key of [param whose] (a joint, or [constant CAMERA]) pressed: chosen,
## the time there. [param adding] (Ctrl or Cmd held): picked with the keys
## picked already, or let go of when it was one of them; otherwise the one
## key picked.
func _pick_key(whose: Variant, index: int, adding: bool = false) -> void:
	var motion: Motions.Motion = _edited()
	var keys: Array = _keys_of(motion, whose) if motion != null else []
	if index < 0 or index >= keys.size():
		return
	var t: float = float(keys[index][0])
	_keys_hot = true
	var at: int = _picked_at(whose, t)
	if not adding and at >= 0 and _picked.size() > 1:
		# One of several picked, pressed: they stay picked, so a drag moves
		# them all; let go where it was, it is picked alone (_let_go_key).
		pass
	elif not adding:
		_picked = [[whose, t]]
	elif at >= 0 and _picked.size() > 1:
		# Let go of: the key chosen is the last of those still picked.
		_picked.remove_at(at)
		whose = _picked.back()[0]
		t = float(_picked.back()[1])
		keys = _keys_of(motion, whose)
		index = -1
		for n: int in keys.size():
			if absf(float(keys[n][0]) - t) < 0.001:
				index = n
		if index < 0:
			return
	elif at < 0:
		# The key chosen before is one of those picked.
		if _picked.is_empty() and _key_index >= 0:
			var before: Array = _keys_of(motion, CAMERA if _key_camera else _key_joint)
			if _key_index < before.size():
				_picked.append([CAMERA if _key_camera else _key_joint, float(before[_key_index][0])])
		_picked.append([whose, t])
	_key_camera = whose is String
	_key_joint = null if _key_camera else _track_of(motion, whose).joint
	_key_index = index
	set_time(t)
	_mark_picked()
	_show_key()
	if _picked.size() > 1:
		_say("%d keys picked: Delete takes them out together, a drag of one moves them all." % _picked.size())


## A key of [param whose] let go where it was pressed, not dragged: one of
## several picked, pressed with no Ctrl or Cmd, it is now picked alone.
func _let_go_key(whose: Variant, index: int, adding: bool) -> void:
	if adding or _picked.size() < 2:
		return
	var keys: Array = _keys_of(_edited(), whose)
	if index < 0 or index >= keys.size() or _picked_at(whose, float(keys[index][0])) < 0:
		return
	_picked = [[whose, float(keys[index][0])]]
	_mark_picked()
	_show_key()


## The keys of [param whose] in [param motion]: a joint's track's, or the
## camera's ([constant CAMERA]); [] for none.
func _keys_of(motion: Motions.Motion, whose: Variant) -> Array:
	if motion == null or whose == null:
		return []
	if whose is String:
		return motion.camera.keys if motion.camera != null else []
	var track: Motions.Track = _track_of(motion, whose)
	return track.keys if track != null else []


## Where [param whose]'s key at [param t] is in [member _picked], or -1.
func _picked_at(whose: Variant, t: float) -> int:
	for n: int in _picked.size():
		if _same_whose(_picked[n][0], whose) and absf(float(_picked[n][1]) - t) < 0.001:
			return n
	return -1


func _same_whose(one: Variant, other: Variant) -> bool:
	if one is String or other is String:
		return one is String and other is String
	return one == other or (one as Motions.Joint).same_ref(other)


## Which of [param keys] (of [param whose]) are picked, by their place in it.
func _picked_indices(whose: Variant, keys: Array) -> Array:
	var out: Array = []
	for n: int in keys.size():
		if _picked_at(whose, float(keys[n][0])) >= 0:
			out.append(n)
	return out


## Every strip drawn with the keys chosen and picked.
func _mark_picked() -> void:
	var motion: Motions.Motion = _edited()
	for part: Dictionary in _joint_parts:
		var strip: KeyStrip = part["strip"]
		strip.chosen = _key_index if not _key_camera and _key_joint != null \
			and _same_whose(part["joint"], _key_joint) else -1
		strip.also = _picked_indices(part["joint"], _keys_of(motion, part["joint"]))
		strip.queue_redraw()
	if _camera_strip != null:
		_camera_strip.chosen = _key_index if _key_camera else -1
		_camera_strip.also = _picked_indices(CAMERA, _keys_of(motion, CAMERA))
		_camera_strip.queue_redraw()


## The chosen key moved to [param t] seconds; the keys picked with it, all
## of them, by as much.
func _move_key(joint: Motions.Joint, index: int, t: float) -> void:
	var motion: Motions.Motion = _edited()
	var track: Motions.Track = _track_of(motion, joint) if motion != null else null
	if track == null or index >= track.keys.size():
		return
	t = clampf(snappedf(t, 0.05), 0.0, Motions.MOST_SECONDS)
	var key: Array = (track.keys[index] as Array).duplicate()
	if absf(float(key[0]) - t) < 0.001:
		return
	if _picked.size() > 1 and _picked_at(joint, float(key[0])) >= 0:
		move_picked(t - float(key[0]))
		return
	# Onto another key, it took that key's place without a word (camreview M2's sibling).
	var near: float = Motions.key_near(track.keys, t, [float(key[0])])
	if near >= 0.0:
		_say("A key is at %s s already: this one was left where it was." % Motions.num(near, 2))
		_fill_editor()
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
	var keys: Array = _keys_of(motion, CAMERA if _key_camera else _key_joint)
	_key_row.visible = _key_index >= 0 and _key_index < keys.size()
	if not _key_row.visible:
		return
	var key: Array = keys[_key_index]
	if _picked.size() > 1:
		_key_words.text = "%d keys picked:" % _picked.size()
	elif _key_camera:
		_key_words.text = "Key at %s s, the camera:" % Motions.num(float(key[0]), 2)
	else:
		_key_words.text = "Key at %s s, %s:" % [Motions.num(float(key[0]), 2), player.joint_name(_key_joint)]
	_quiet = true
	_how.select(maxi(Motions.HOWS.find(str(key.back())), 0))
	_quiet = false
	_fit_later()


## The chosen key's way there: one of Motions.HOWS.
func set_how(how: String) -> void:
	if _key_camera and _key_index >= 0 and how in Motions.HOWS:
		var at: int = _key_index
		_change("made a key of the camera %s" % HOW_WORDS[Motions.HOWS.find(how)].to_lower(),
			func(motion: Motions.Motion) -> void:
				if motion.camera != null and at < motion.camera.keys.size():
					motion.camera.keys[at][6] = how)
		_say("That key's way there is %s now." % HOW_WORDS[Motions.HOWS.find(how)].to_lower())
		_fill_editor()
		return
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
	if _picked.size() > 1 or _key_camera:
		remove_picked()
		return
	var joint: Motions.Joint = _key_joint
	var index: int = _key_index
	var motion: Motions.Motion = _edited()
	var track: Motions.Track = _track_of(motion, joint) if motion != null and joint != null else null
	if track == null or index < 0 or index >= track.keys.size():
		return
	var last: bool = track.keys.size() == 1
	if last and motion.tracks.size() == 1 and motion.driver == null and motion.path == null \
			and (motion.camera == null or motion.camera.keys.is_empty()):
		_say("It is the motion's only key: Remove takes the motion out.")
		return
	_change("took a key of %s out" % player.joint_name(joint), func(edited_motion: Motions.Motion) -> void:
		var own: Motions.Track = _track_of(edited_motion, joint)
		own.keys.remove_at(index)
		if own.keys.is_empty():
			edited_motion.tracks.erase(own))
	_key_index = -1
	_key_joint = null
	_picked.clear()
	_fill_editor()
	_say("Key taken out%s. Undo puts it back." % (", and the joint with it" if last else ""))


## Every key picked ([member _picked]: Ctrl+click), of any track and the
## camera's, taken out in one step. A track left with none goes, and the
## camera's with it; every key the motion has is not taken: Remove does that.
func remove_picked() -> void:
	var motion: Motions.Motion = _edited()
	var picks: Array = _picked.duplicate()
	if picks.is_empty() and _key_camera and _key_index >= 0:
		var keys: Array = _keys_of(motion, CAMERA)
		if _key_index < keys.size():
			picks = [[CAMERA, float(keys[_key_index][0])]]
	picks = picks.filter(func(pick: Array) -> bool:
		return _keys_of(motion, pick[0]).any(func(key: Array) -> bool:
			return absf(float(key[0]) - float(pick[1])) < 0.001))
	if motion == null or picks.is_empty():
		return
	var total: int = 0
	for track: Motions.Track in motion.tracks:
		total += track.keys.size()
	total += motion.camera.keys.size() if motion.camera != null else 0
	if picks.size() >= total and motion.driver == null and motion.path == null:
		_say("Those are all the motion's keys: Remove takes the motion out.")
		return
	_change(("took a key out of %s" % Motions.quoted(motion.name)) if picks.size() == 1
		else "took %d keys out of %s" % [picks.size(), Motions.quoted(motion.name)], func(edited: Motions.Motion) -> void:
			for pick: Array in picks:
				var keys: Array = _keys_of(edited, pick[0])
				for n: int in range(keys.size() - 1, -1, -1):
					if absf(float(keys[n][0]) - float(pick[1])) < 0.001:
						keys.remove_at(n)
			edited.tracks = edited.tracks.filter(func(one: Motions.Track) -> bool: return not one.keys.is_empty())
			if edited.camera != null and edited.camera.keys.is_empty():
				edited.camera = null)
	_key_index = -1
	_key_joint = null
	_key_camera = false
	_picked.clear()
	_fill_editor()
	_set_buttons()
	_say("Key taken out. Undo puts it back." if picks.size() == 1
		else "%d keys taken out together. Undo puts them all back." % picks.size())


## Every key picked moved [param by] seconds in one step, all by as much:
## none before 0 or past the longest, so the move is cut short there rather
## than pushing the first past the start, and none onto a key not picked (or
## within a frame of one), which is refused and said. Snapped past the start,
## then clamped, two keys dragged to 0 s took the place of the one there
## without a word (camreview M2); each is checked where it lands.
func move_picked(by: float) -> void:
	var motion: Motions.Motion = _edited()
	if motion == null or _picked.is_empty():
		return
	var earliest: float = INF
	var latest: float = 0.0
	for pick: Array in _picked:
		earliest = minf(earliest, float(pick[1]))
		latest = maxf(latest, float(pick[1]))
	by = clampf(snappedf(by, 0.001), -earliest, Motions.MOST_SECONDS - latest)
	if absf(by) < 0.001:
		return
	var picks: Array = _picked.duplicate()
	for pick: Array in picks:
		var to: float = snappedf(float(pick[1]) + by, 0.001)
		var mine: Array = picks.filter(func(one: Array) -> bool: return _same_whose(one[0], pick[0])).map(
			func(one: Array) -> float: return float(one[1]))
		var near: float = Motions.key_near(_keys_of(motion, pick[0]), to, mine)
		if near >= 0.0:
			_say("A key not picked is at %s s, where the key at %s s would go: the keys were left where they were."
				% [Motions.num(near, 2), Motions.num(float(pick[1]), 2)])
			_fill_editor()
			return
	_change("moved %d keys by %s s" % [picks.size(), Motions.num(by, 2)], func(edited: Motions.Motion) -> void:
		var taken: Array = []
		for pick: Array in picks:
			var keys: Array = _keys_of(edited, pick[0])
			for n: int in range(keys.size() - 1, -1, -1):
				if absf(float(keys[n][0]) - float(pick[1])) < 0.001:
					taken.append([pick[0], keys[n]])
					keys.remove_at(n)
		for one: Array in taken:
			var key: Array = (one[1] as Array).duplicate()
			key[0] = clampf(snappedf(float(key[0]) + by, 0.001), 0.0, Motions.MOST_SECONDS)
			if one[0] is String:
				edited.camera.add_key(key)
			else:
				_track_of(edited, one[0]).add_key(float(key[0]), float(key[1]), str(key[2])))
	for pick: Array in _picked:
		pick[1] = snappedf(float(pick[1]) + by, 0.001)
	_at = clampf(_at + by, 0.0, Motions.MOST_SECONDS)
	_key_index = -1
	var keys: Array = _keys_of(_edited(), CAMERA if _key_camera else _key_joint)
	for n: int in keys.size():
		if _picked_at(CAMERA if _key_camera else _key_joint, float(keys[n][0])) >= 0:
			_key_index = n
			break
	_fill_editor()
	_show_time(_edited())
	_say("%d keys moved %s s together. Undo puts them back." % [picks.size(), Motions.num(by, 2)])


# -- the camera's keys (camerakeys) ----------------------------------------------------------


## How far the model stands above the file's coordinates.
func _lift() -> Vector3:
	return player.store.lift() if player != null and player.store != null else Vector3.ZERO


## The camera keyed at the editor's time where the window looks from: the
## point it looks at, the way it looks from, how far off, its lens. A key
## there already (or within a frame: Motions.LEAST_KEY_GAP) is put in its
## place, its time and its way there kept, its turn taken the short way from
## its own: a turntable's last key keyed again from where it stands kept its
## full turn rather than going 0° round (camreview H1). A new key's turn is
## taken the short way from the key before it (or after), so it goes round no
## further than the view did. One step to undo.
func key_camera() -> void:
	var motion: Motions.Motion = _edited()
	if motion == null or eye == null or not eye.has_method("aim") or _playing or _working or _recording:
		return
	var aim: Dictionary = eye.call("aim")
	var focus: Array = aim["focus"]
	var numbers: Array = MotionPlayer.camera_numbers([Vector3(float(focus[0]), float(focus[1]), float(focus[2])),
		float(aim["yaw"]), float(aim["pitch"]), float(aim["distance"]), eye.fov], _lift())
	var keys: Array = motion.camera.keys if motion.camera != null else []
	var at: float = snappedf(_at, 0.001)
	var there: float = Motions.key_near(keys, at)
	var moved_to: bool = there >= 0.0 and absf(there - at) >= 0.001
	if there >= 0.0:
		at = there
	var how: String = "EASE"
	var near: Variant = null
	for key: Array in keys:
		if absf(float(key[0]) - at) < 0.001:
			how = str(key[6])
			near = float(key[2])
			break
	if near == null:
		for key: Array in keys:
			if float(key[0]) < at or near == null:
				near = float(key[2])
	var turn: float = float(numbers[1])
	if near != null:
		turn = float(near) + rad_to_deg(angle_difference(deg_to_rad(float(near)), deg_to_rad(turn)))
	var key: Variant = Motions.camera_key_of(at, numbers[0], turn, numbers[2], numbers[3], numbers[4], how)
	if key is String:
		_say("The camera is not keyed: %s." % key)
		return
	_change("keyed the camera at %s s in %s" % [Motions.num(at, 2), Motions.quoted(motion.name)],
		func(edited: Motions.Motion) -> void:
			if edited.camera == null:
				edited.camera = Motions.CameraTrack.new()
			edited.camera.add_key(key))
	_choose_camera_key(at)
	if moved_to:
		_say("The key at %s s keyed again, under a frame from the time: where the camera stands, what it looks at and its lens."
			% Motions.num(at, 3))
	else:
		_say("The camera keyed at %s s: where it stands, what it looks at and its lens. Play goes through its keys."
			% Motions.num(at, 2))


## A turntable: two keys round the middle of the model, the camera at the
## height and distance it stands at now, through its lens, a full turn over
## the motion's length (8 s for one with none yet) at one speed. In place of
## the camera's keys; one step to undo; any key may then be moved or changed.
func make_turntable() -> void:
	var motion: Motions.Motion = _edited()
	if motion == null or eye == null or _playing or _working or _recording:
		return
	var box: AABB = player._model_box()
	if box.size == Vector3.ZERO:
		_say("There is no model to go round.")
		return
	var centre: Vector3 = box.get_center()
	var offset: Vector3 = eye.global_position - centre
	var away: float = maxf(offset.length(), Motions.LEAST_AWAY)
	var seconds: float = motion.length() if motion.length() >= 1.0 else Motions.TURNTABLE_SECONDS
	var keys: Variant = Motions.turntable_keys((centre - _lift()) * LdrModel.FLIP,
		rad_to_deg(atan2(offset.x, offset.z)), rad_to_deg(asin(clampf(offset.y / away, -1.0, 1.0))), away,
		eye.fov, seconds)
	if keys is String:
		_say("No turntable: %s." % keys)
		return
	_change("made the camera go round %s" % Motions.quoted(motion.name), func(edited: Motions.Motion) -> void:
		edited.camera = Motions.CameraTrack.new()
		for key: Array in keys:
			edited.camera.add_key(key))
	_choose_camera_key(0.0)
	_say(("A turntable: the camera goes once round the model in %s s, at the height and distance it stands at "
		+ "now. Each key can be picked, moved or changed.") % Motions.num(seconds, 1))


## The camera's key at [param t] chosen, the editor at its time.
func _choose_camera_key(t: float) -> void:
	var keys: Array = _keys_of(_edited(), CAMERA)
	_key_camera = true
	_key_joint = null
	_key_index = -1
	for n: int in keys.size():
		if absf(float(keys[n][0]) - t) < 0.001:
			_key_index = n
	_picked = [[CAMERA, t]] if _key_index >= 0 else []
	_at = t
	_fill_editor()
	_set_buttons()


## The camera's key [param index] pressed on its strip: chosen (picked with
## others with [param adding]), and the view put where it looks from, so a
## person sees it and can key it again from there.
func _pick_camera_key(index: int, adding: bool) -> void:
	_pick_key(CAMERA, index, adding)
	var keys: Array = _keys_of(_edited(), CAMERA)
	if index < 0 or index >= keys.size() or eye == null or not eye.has_method("aim_at"):
		return
	var view: Array = MotionPlayer.camera_view(Motions.CameraTrack._view_of(keys[index]), _lift())
	eye.call("aim_at", {"yaw": view[1], "pitch": view[2], "distance": view[3],
		"focus": [(view[0] as Vector3).x, (view[0] as Vector3).y, (view[0] as Vector3).z]})
	eye.fov = float(view[4])


## The camera's key [param index] moved to [param t] on its strip, the keys
## picked with it by as much.
func _move_camera_key(index: int, t: float) -> void:
	var keys: Array = _keys_of(_edited(), CAMERA)
	if index < 0 or index >= keys.size():
		return
	var from: float = float(keys[index][0])
	t = clampf(snappedf(t, 0.05), 0.0, Motions.MOST_SECONDS)
	if absf(from - t) < 0.001:
		return
	if _picked_at(CAMERA, from) < 0:
		_picked = [[CAMERA, from]]
	move_picked(t - from)


func _fill_camera(motion: Motions.Motion) -> void:
	var keys: Array = motion.camera.keys if motion.camera != null else []
	_camera_strip.visible = not keys.is_empty()
	_camera_strip.span = _time.max_value
	_camera_strip.now = _at
	_camera_strip.times = keys.map(func(key: Array) -> float: return float(key[0]))
	_camera_strip.chosen = _key_index if _key_camera else -1
	_camera_strip.also = _picked_indices(CAMERA, keys)
	_camera_strip.queue_redraw()
	if keys.is_empty():
		_camera_words.text = "The view stays the person's. Key the camera to fly round the model."
	elif keys.size() == 1:
		_camera_words.text = "One key: the camera stands there all through the motion."
	else:
		_camera_words.text = "%d keys over %s s, %s° round the model." % [keys.size(),
			Motions.num(float(keys.back()[0]) - float(keys[0][0]), 2),
			Motions.num(absf(float(keys.back()[2]) - float(keys[0][2])), 1)]


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
	motions.rename_unread(was, words)
	builder.record([{"undo": "motions", "motions": had}], "renamed the motion %s %s" % [Motions.quoted(was),
		Motions.quoted(words)])
	_editing_name = words
	_chosen = words
	_refresh()
	_say(_with_let_go("Renamed %s. Undo gives it its old name." % Motions.quoted(words), motions))


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
	_say(_with_let_go("Took %s out. Undo puts it back." % Motions.quoted(name), motions))


## [param words], and after them what [param motions]' last change let go
## of the lines it did not read (Motions.let_go_words), if anything.
func _with_let_go(words: String, motions: Motions) -> String:
	return words if motions.let_go.is_empty() else "%s %s." % [words, motions.let_go_words()]


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
	if not motions.let_go.is_empty():
		_say(motions.let_go_words())
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
		motion.name, false, drawn.cameras)


## Draw [param poses] (one a frame: brick id -> Transform3D of the parts
## that move), [param fps] a second, the model turned [param turn_at] (frame
## -> turns) round, and keep them as File, Render's Animation keeps its
## frames (MotionRender): a WebP, and on the desktop the frames and an MP4,
## named after the model and [param motion]. [param sheet_at]: the frames
## kept for [method sheet]. [param on_what_moves]: framed on what the parts
## sweep, from [param view]'s direction. A motion is rendered this way
## (render_motion, Render animation), as its frames. [param cameras]: each
## frame's camera where a motion keys it (MotionRender.cameras). Returns how
## many were drawn.
func render_poses(poses: Array, fps: int, turn_at: Callable, sheet_at: Array,
		job: Working.Job = null, view: String = "", motion: String = "Animation",
		on_what_moves: bool = false, cameras: Array = []) -> int:
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
			_frame_for = world.generation()
			if sheet_at.has(n):
				_sheet[n] = image
			if job != null:
				job.count(n + 1), cameras)
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
		# Untyped until checked: rows built afresh have freed the old buttons.
		for key: String in ["play", "back", "edit", "pick"]:
			var item: Variant = row[key]
			if is_instance_valid(item):
				var button: BaseButton = item
				button.disabled = busy or (_playing and button != _stop_button and key != "pick")
	for item: Variant in _keep_buttons + _unlock_buttons:
		if is_instance_valid(item):
			(item as Button).disabled = busy or _playing
	for part: Dictionary in _joint_parts:
		if is_instance_valid(part.get("lock")):
			(part["lock"] as Button).disabled = busy or _playing
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
			var item: Variant = row[key]
			if is_instance_valid(item):
				var button: Button = item
				button.disabled = still or (key == "up" and n == 0) \
					or (key == "down" and n == _seq_buttons.size() - 1)
	var motion: Motions.Motion = _edited()
	var empty: bool = motion == null or not motion.has_own()
	_camera_key.disabled = busy or _playing
	_camera_turn.disabled = busy or _playing
	_edit_play.disabled = busy or empty or (_playing and _stop_button != _edit_play)
	_edit_reverse.disabled = busy or empty or (_playing and _stop_button != _edit_reverse)
	_record.disabled = _working or _playing
	_back.disabled = _working
	_remove.disabled = busy or _playing
	_name.editable = not busy
	_time.editable = not (busy or _playing)
	for part: Dictionary in _joint_parts:
		(part["slider"] as HSlider).editable = not (busy or _playing)
	for row: Array in _path_controls:
		(row[0] as OptionButton).disabled = busy or _playing
		(row[1] as SpinBox).editable = not (busy or _playing)
		(row[2] as SpinBox).editable = not (busy or _playing)
		(row[3] as Button).disabled = busy or _playing or _path_controls.size() <= 1
	for button: Button in [_path_make, _path_add, _path_drop]:
		button.disabled = busy or _playing
	_path_seconds.editable = not (busy or _playing)
	_path_eased.disabled = busy or _playing
	var has: bool = _view == "edit" and not empty or _view != "edit" and not _chosen.is_empty()
	_render.disabled = _working or _recording or _playing or not has
	_cancel.visible = _working


func _process(delta: float) -> void:
	if _recording:
		_record_frame()
	if _playing and world.generation() != _playing_generation:
		# The world the frames are of is gone (another model opened, New, a
		# Together join, a restore): stopped, and the view the motion's camera
		# held is the person's, where whatever opened the next one puts it. A
		# loop played on and held the view over the next model (camreview M3).
		_stop_playing(false)
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
				_show_camera(n)
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
	if not _recording and not _working:
		_weigh_hold()
	_tell_page()


# -- whether the pose holds ------------------------------------------------------------


## The pose shown weighed whenever it changes: the model as it stands, or
## the pose a slider, a key or a frame draws over it (the model unmoved),
## each against what Grab read of the model (GrabDrag.weigh_with), a few
## milliseconds a pose. Not until Grab has read the model as it stands.
func _weigh_hold() -> void:
	if grabbing == null:
		return
	var placed: Dictionary = world.drawn_ids() if _drawn else {}
	var key: Array = [world.generation(), world.revision, placed.hash()]
	var now: int = Time.get_ticks_msec()
	if key == _hold_key or now - _hold_at < HOLD_EVERY_MS:
		return
	var report: Balance.Report = grabbing.weigh_with(placed)
	if report == null:
		return
	_hold_key = key
	_hold_at = now
	show_hold(report)


## [param report]'s friction joints in the hold line, and each joint row
## that droops marked with how far over (PoseHold.pose_words).
func show_hold(report: Balance.Report) -> void:
	_hold_report = report
	var words: String = PoseHold.pose_words(report, _part_name)
	if words != hold_words():
		_clear(_hold)
		var droops: bool = not PoseHold.drooping(report).is_empty()
		for n: int in words.split("\n").size() if not words.is_empty() else 0:
			var line := Label.new()
			line.text = words.split("\n")[n]
			line.add_theme_font_size_override("font_size", 12 if n == 0 else 11)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size = Vector2(WIDE, 0)
			line.mouse_filter = Control.MOUSE_FILTER_PASS
			# What droops in the tint Stress marks red with; the rest quieter.
			if droops and n <= mini(PoseHold.drooping(report).size(), 3):
				line.add_theme_color_override("font_color", BalanceMark.TIPS.lerp(Color.WHITE, 0.35))
			else:
				line.modulate = Color(1, 1, 1, 0.8)
			_hold.add_child(line)
		_fit_later()
	_hold.visible = not words.is_empty()
	for row: Dictionary in _joint_parts:
		_mark_row(row)


## The hold lines as they read, one a line, for a probe and a session.
func hold_words() -> String:
	var lines := PackedStringArray()
	for line: Node in _hold.get_children():
		if line is Label and not line.is_queued_for_deletion():
			lines.append((line as Label).text)
	return "\n".join(lines)


## A joint row's droop mark: the friction joint that joint turns, past what
## one of its kind holds, with how far over.
func _mark_row(row: Dictionary) -> void:
	var mark: Label = row.get("droop")
	if mark == null:
		return
	var one: Balance.JointLoad = _droop_of(row["joint"])
	mark.visible = one != null
	if one != null:
		mark.text = "Droops: it holds %d%% of what hangs on it." % PoseHold.percent(one.share())


## The drooping friction joint [param joint] turns: the one whose part past
## it moves with the joint and whose part holding it does not.
func _droop_of(joint: Motions.Joint) -> Balance.JointLoad:
	var droops: Array = PoseHold.drooping(_hold_report)
	if droops.is_empty() or player == null:
		return null
	var moving: Dictionary = {}
	var parts: Array = player.parts_of(joint)
	var bodies: Bodies = grabbing.read_bodies() if grabbing != null and joint.by != "assembly" else null
	if bodies != null and not parts.is_empty() and bodies.body_of.has(int(parts[0])):
		parts = Array(bodies.members.get(bodies.body_of[int(parts[0])], PackedInt64Array()))
	for id: Variant in parts:
		moving[int(id)] = true
	for one: Balance.JointLoad in droops:
		if moving.has(one.beyond) and not moving.has(one.held_by):
			return one
	return null


## A part as the hold line names it: "#12 (Technic Ball Joint)".
func _part_name(id: int) -> String:
	var brick: BrickWorld.Brick = world.get_brick(id)
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
	return "#%d (%s)" % [id, Inventory._tidy(info.name)] if info != null else "#%d" % id


## The history as it stands: its depth and its newest step, the same
## dictionary until something is done, undone or redone.
func _history_now() -> Array:
	return [builder.history_depth(), builder.last_step() if builder.history_depth() > 0 else null]


func _same_history(seen: Array) -> bool:
	return seen.size() == 2 and int(seen[0]) == builder.history_depth() \
		and (builder.history_depth() == 0 or is_same(seen[1], builder.last_step()))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# A press anywhere but the panel: Delete is the view's again.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and not get_global_rect().has_point((event as InputEventMouseButton).position):
		_keys_hot = false
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if key.pressed and not key.echo and key.keycode in [KEY_DELETE, KEY_BACKSPACE] and _view == "edit" \
			and _keys_hot and not _picked.is_empty() and not _playing and not _working \
			and not get_viewport().gui_get_focus_owner() is LineEdit \
			and not get_viewport().gui_get_focus_owner() is TextEdit:
		remove_picked()
		get_viewport().set_input_as_handled()
		return
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
	# By finger, New motion and New sequence stand in the header, in sight
	# however far the list is scrolled and pushing none of it down. At the
	# list's foot they were five swipes down a phone's sheet (the phone walk:
	# 10 taps to record against the desktop's 4); at its head they pushed the
	# suggestions' Keep and a motion's Play below the fold (11 to keep and
	# play against 3).
	if Phone.on():
		_making.reparent(header, false)
		header.move_child(_making, 1)
	_build_editor(inner)
	_build_sequence(inner)
	# The foot: whether the pose holds, Render animation, its progress and
	# last frame, and the status. By finger it scrolls with the list, under
	# its last row, and only the header stands still. Standing still under
	# the list on a 664-point iPhone (390 x 664 once Safari's bars are
	# drawn), the hold's two lines, Render animation and the status, with
	# the moved parts' strip and the assistant's bar over the model, left
	# the list under one row between the header and them, and the panel
	# taller than its sheet: Keep never came wholly into sight, and the
	# joint's slider followed it out (smalls7, docs/PHONE.md fault 6). Where
	# the list and the foot both fit, as on every larger phone, the foot
	# lies where it did, under the list.
	var foot: Container = inner if Phone.on() else column
	# Whether the pose holds: in sight in every view, below what moves, and
	# on a phone the same line wrapped, since nothing there hovers.
	_hold = VBoxContainer.new()
	_hold.add_theme_constant_override("separation", 2)
	_hold.visible = false
	foot.add_child(_hold)
	foot.add_child(HSeparator.new())
	var rendering := HBoxContainer.new()
	rendering.add_theme_constant_override("separation", 6)
	foot.add_child(rendering)
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
	_size.accessibility_name = "Size"
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
	foot.add_child(_progress)
	_frame = TextureRect.new()
	_frame.custom_minimum_size = Vector2(WIDE, 120)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	foot.add_child(_frame)
	# The last frame drawn, once a render has drawn one.
	_frame.visible = false
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(WIDE, 0)
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	_status.modulate = Color(1, 1, 1, 0.8)
	foot.add_child(_status)


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
	# The joints locked, each with its Unlock: a lock is found where it is
	# kept, not only on a motion's row (jointlock).
	_lock_heading = _heading(_list_box, "Joints locked")
	_lock_rows = VBoxContainer.new()
	_lock_rows.add_theme_constant_override("separation", 3)
	_list_box.add_child(_lock_rows)
	_list_box.add_child(HSeparator.new())
	_suggest_heading = _heading(_list_box, "Suggested from what moves")
	_suggest_rows = VBoxContainer.new()
	_suggest_rows.add_theme_constant_override("separation", 3)
	_list_box.add_child(_suggest_rows)
	_making = HBoxContainer.new()
	_making.add_theme_constant_override("separation", 6)
	_list_box.add_child(_making)
	_new = _button(_making, "New motion", new_motion,
		"Make a motion: name it, then Record and drag the parts, or set its joints one by one")
	_new_sequence = _button(_making, "New sequence", new_sequence,
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
	_time.accessibility_name = "At, in seconds"
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
	var joints_heading: Label = _heading(_edit_box, "Its joints")
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
	_build_path(_edit_box)
	_build_camera(_edit_box)
	if Phone.on():
		_for_a_finger([top, joints_heading, _joint_rows, _more, _key_row, playing, timing],
			recording, naming, gap)


## The editor laid out for a finger (the phone's layout or a tablet's): in a
## phone's sheet under the model its list shows about 100 points, and a
## joint's slider sat under the name, Record, Play and the time, four to six
## swipes down, 5 to 7 taps against the desktop's 1 (phonewalk, APP_UX8
## phonepanels). So Record goes up beside All motions, where it stays in
## sight while the parts are dragged and Stop is pressed, and the joints come
## next; Play and the time follow them. The name takes the room between All
## motions and Record, in sight with them. What Record's line says the status
## line says once it is pressed. The desktop keeps its order.
func _for_a_finger(order: Array, recording: HBoxContainer, naming: HBoxContainer,
		gap: Control) -> void:
	var top: HBoxContainer = order[0]
	_name.reparent(top, false)
	top.move_child(_name, 1)
	_name.select_all_on_focus = true
	gap.visible = false
	naming.visible = false
	_record.reparent(top, false)
	top.move_child(_record, 2)
	recording.visible = false
	for n: int in order.size():
		_edit_box.move_child(order[n] as Control, n)


## The camera's section (camerakeys): what its keys do, Key the camera,
## Turntable, and its keys on a strip of time as a joint's are, between the
## joints' keys and the chosen key's row.
func _build_camera(into: Control) -> void:
	_camera_heading = _heading(into, "The camera")
	var making := HBoxContainer.new()
	making.add_theme_constant_override("separation", 6)
	into.add_child(making)
	_camera_key = _button(making, "Key the camera", key_camera,
		"A key at the time above where the view looks from: what it looks at, from where, and its lens")
	_camera_turn = _button(making, "Turntable", make_turntable,
		"Two keys: the camera once round the model over the motion, at the height and distance it is now")
	_camera_strip = KeyStrip.new()
	_camera_strip.custom_minimum_size = Vector2(0, 14)
	if Phone.on():
		_camera_strip.custom_minimum_size.y = Phone.px(get_viewport(), Phone.TARGET)
		_camera_strip.near = Phone.px(get_viewport(), Phone.TARGET * 0.5)
	_camera_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camera_strip.tooltip_text = ("The camera's keys: a key pressed is chosen and the view goes there; "
		+ "Ctrl+click picks several; dragged, they move in time")
	_camera_strip.picked.connect(_pick_camera_key)
	_camera_strip.moved.connect(_move_camera_key)
	_camera_strip.let_go.connect(func(index: int, adding: bool) -> void: _let_go_key(CAMERA, index, adding))
	_camera_strip.timed.connect(func(t: float) -> void: set_time(t))
	_camera_strip.visible = false
	into.add_child(_camera_strip)
	_camera_words = Label.new()
	_camera_words.add_theme_font_size_override("font_size", 11)
	_camera_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_camera_words.custom_minimum_size = Vector2(WIDE - 24, 0)
	_camera_words.modulate = Color(1, 1, 1, 0.7)
	into.add_child(_camera_words)
	# Under the joints' keys and above the chosen key's row, as a joint's
	# strip is: a camera key pressed shows that row below its strip, so the
	# strip stays under the pointer for the next Ctrl+click or drag. (A
	# phone's editor puts the row and Play first; its camera stays below.)
	if not Phone.on() and _key_row != null and _key_row.get_parent() == into:
		for control: Control in [_camera_heading, making, _camera_strip, _camera_words]:
			into.move_child(control, _key_row.get_index())


# -- a path: where the whole model drives (unit drive) ---------------------------------------


var _path_heading: Label
var _path_rows: VBoxContainer
var _path_make: Button
var _path_add: Button
var _path_drop: Button
var _path_seconds: SpinBox
var _path_eased: CheckBox
var _path_words: Label
var _path_timing: HBoxContainer
var _path_controls: Array = []
## Each leg's kind as its row offers it, Motions.LEGS's order.
const LEG_WORDS: Array = ["Straight", "Left", "Right"]


## The editor's path: Drive along a path when the motion has none; else
## its legs, a row each (straight so many studs, or left or right so many
## degrees on a radius), Add a leg, how long it takes and whether it gathers
## speed and slows, what turns as it rolls, and No path.
func _build_path(into: Control) -> void:
	_path_heading = _heading(into, "Where it drives")
	_path_rows = VBoxContainer.new()
	_path_rows.add_theme_constant_override("separation", 4)
	into.add_child(_path_rows)
	var making := HBoxContainer.new()
	making.add_theme_constant_override("separation", 6)
	into.add_child(making)
	_path_make = _button(making, "Drive along a path", drive_along,
		"The whole model driven along the ground, its wheels turning as it goes: 32 studs, then round a corner")
	_path_add = _button(making, "Add a leg", add_leg, "Another leg at the path's end: straight on")
	_path_drop = _button(making, "No path", remove_path, "The model stays where it stands; its joints still move")
	_path_timing = HBoxContainer.new()
	_path_timing.add_theme_constant_override("separation", 6)
	into.add_child(_path_timing)
	var over := Label.new()
	over.text = "Over"
	over.add_theme_font_size_override("font_size", 12)
	_path_timing.add_child(over)
	_path_seconds = _spin(_path_timing, 0.5, Motions.MOST_SECONDS, 0.5, "s", "How long it takes, seconds")
	_path_seconds.value_changed.connect(func(value: float) -> void:
		if not _quiet:
			set_path_seconds(value))
	_path_eased = CheckBox.new()
	_path_eased.text = "Eased"
	_path_eased.tooltip_text = "It gathers speed at the start and slows to a stop at the end"
	_path_eased.add_theme_font_size_override("font_size", 12)
	_path_eased.focus_mode = Control.FOCUS_NONE
	_path_eased.toggled.connect(func(on: bool) -> void:
		if not _quiet:
			set_path_eased(on))
	_path_timing.add_child(_path_eased)
	_path_words = Label.new()
	_path_words.add_theme_font_size_override("font_size", 11)
	_path_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_words.custom_minimum_size = Vector2(WIDE - 24, 0)
	_path_words.modulate = Color(1, 1, 1, 0.7)
	into.add_child(_path_words)


func _spin(into: Control, least: float, most: float, step: float, unit: String, tip: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = least
	spin.max_value = most
	spin.step = step
	spin.suffix = unit
	spin.tooltip_text = tip
	spin.select_all_on_focus = true
	spin.custom_minimum_size = Vector2(78, 0)
	spin.get_line_edit().add_theme_font_size_override("font_size", 12)
	into.add_child(spin)
	return spin


## The path's rows as the edited motion has it.
func _fill_path(motion: Motions.Motion) -> void:
	_clear(_path_rows)
	_path_controls.clear()
	var path: Motions.Path = motion.path
	_path_make.visible = path == null
	_path_add.visible = path != null and path.legs.size() < Motions.MOST_LEGS
	_path_drop.visible = path != null
	_path_timing.visible = path != null
	_path_words.visible = path != null
	if path == null:
		return
	_quiet = true
	for n: int in path.legs.size():
		var leg: Array = path.legs[n]
		var index: int = n
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_path_rows.add_child(row)
		var kind := OptionButton.new()
		kind.add_theme_font_size_override("font_size", 12)
		kind.focus_mode = Control.FOCUS_NONE
		for words: String in LEG_WORDS:
			kind.add_item(words)
		kind.select(Motions.LEGS.find(str(leg[0])))
		kind.tooltip_text = "Straight on, or a turn to the left or the right"
		row.add_child(kind)
		var straight: bool = str(leg[0]) == "STRAIGHT"
		var amount: SpinBox = _spin(row, -Motions.MOST_LEG_STUDS if straight else 1.0,
			Motions.MOST_LEG_STUDS if straight else Motions.MOST_TURN_DEG, 1.0, "studs" if straight else "°",
			"How far, studs (less than 0 backwards)" if straight else "How far round, degrees")
		amount.set_value_no_signal(float(leg[1]))
		var radius: SpinBox = _spin(row, Motions.LEAST_RADIUS, Motions.MOST_RADIUS, 1.0, "studs",
			"How wide the turn is: its radius, studs, at the middle of the back axle")
		radius.prefix = "r"
		radius.custom_minimum_size = Vector2(92, 0)
		radius.set_value_no_signal(float(leg[2]) if not straight else 0.0)
		radius.visible = not straight
		var out := _button(row, "Take out", func() -> void: remove_leg(index), "Take this leg out of the path")
		out.disabled = path.legs.size() <= 1
		kind.item_selected.connect(func(chosen: int) -> void:
			var to: String = Motions.LEGS[chosen]
			if to == str(path.legs[index][0]):
				return
			if to == "STRAIGHT":
				set_leg(index, to, MotionPlayer.DRIVE_STRAIGHT)
			else:
				var was: Array = path.legs[index]
				set_leg(index, to, MotionPlayer.DRIVE_CORNER if str(was[0]) == "STRAIGHT" else float(was[1]),
					float(was[2]) if str(was[0]) != "STRAIGHT" else player.corner_radius(path)))
		amount.value_changed.connect(func(value: float) -> void:
			if not _quiet:
				set_leg(index, str(path.legs[index][0]), value, float(path.legs[index][2])))
		radius.value_changed.connect(func(value: float) -> void:
			if not _quiet:
				set_leg(index, str(path.legs[index][0]), float(path.legs[index][1]), value))
		_path_controls.append([kind, amount, radius, out])
	_path_seconds.set_value_no_signal(path.seconds)
	_path_eased.set_pressed_no_signal(path.how == "EASE")
	_path_words.text = player.path_words(path)
	_quiet = false


## The edited motion driven along a path: 32 studs straight and a quarter
## turn to the left, at the tightest corner its steering takes well, its
## wheels and steering found from the model as it stands. One step.
func drive_along() -> void:
	var motion: Motions.Motion = _edited()
	if motion == null or motion.path != null or _recording or _playing or _working:
		return
	var path: Motions.Path = player.drive_path()
	_change("drove %s along a path" % Motions.quoted(motion.name), func(edited: Motions.Motion) -> void:
		edited.path = path)
	_refresh()
	_say(("It drives %s. %s Play plays it.") % [path.said(), player.path_words(path)])


## Leg [param index] of the edited motion's path made [param kind]
## ("STRAIGHT", "LEFT" or "RIGHT") of [param amount] (studs, or degrees on
## [param radius] studs). One step; what does not fit a leg is said.
func set_leg(index: int, kind: String, amount: float, radius: float = 0.0) -> void:
	var motion: Motions.Motion = _edited()
	if motion == null or motion.path == null or index < 0 or index >= motion.path.legs.size():
		return
	var leg: Variant = Motions.leg_of(kind, amount, radius)
	if leg is String:
		_say("%s%s." % [str(leg).left(1).to_upper(), str(leg).substr(1)])
		_refresh()
		return
	if leg == motion.path.legs[index]:
		return
	_change("changed the path of %s" % Motions.quoted(motion.name), func(edited: Motions.Motion) -> void:
		edited.path = edited.path.copy()
		edited.path.legs[index] = leg)
	_refresh()
	_say("It drives %s." % motion.path.said())


func add_leg() -> void:
	var motion: Motions.Motion = _edited()
	if motion == null or motion.path == null or motion.path.legs.size() >= Motions.MOST_LEGS:
		return
	_change("changed the path of %s" % Motions.quoted(motion.name), func(edited: Motions.Motion) -> void:
		edited.path = edited.path.copy()
		edited.path.legs.append(["STRAIGHT", MotionPlayer.DRIVE_STRAIGHT * 0.5, 0.0]))
	_refresh()
	_say("It drives %s." % motion.path.said())


func remove_leg(index: int) -> void:
	var motion: Motions.Motion = _edited()
	if motion == null or motion.path == null or motion.path.legs.size() <= 1 or index < 0 \
			or index >= motion.path.legs.size():
		return
	_change("changed the path of %s" % Motions.quoted(motion.name), func(edited: Motions.Motion) -> void:
		edited.path = edited.path.copy()
		edited.path.legs.remove_at(index))
	_refresh()
	_say("It drives %s." % motion.path.said())


func set_path_seconds(seconds: float) -> void:
	var motion: Motions.Motion = _edited()
	if motion == null or motion.path == null or is_equal_approx(seconds, motion.path.seconds):
		return
	_change("changed the path of %s" % Motions.quoted(motion.name), func(edited: Motions.Motion) -> void:
		edited.path = edited.path.copy()
		edited.path.seconds = snappedf(clampf(seconds, 0.5, Motions.MOST_SECONDS), 0.001)
		# Its length now its parts', as Record makes it: a file's MOTION
		# line said 8 seconds of a path made 3 (drivereview F8).
		edited.seconds = 0.0)
	_refresh()


func set_path_eased(on: bool) -> void:
	var motion: Motions.Motion = _edited()
	if motion == null or motion.path == null or (motion.path.how == "EASE") == on:
		return
	_change("changed the path of %s" % Motions.quoted(motion.name), func(edited: Motions.Motion) -> void:
		edited.path = edited.path.copy()
		edited.path.how = "EASE" if on else "LINEAR")
	_refresh()


## The edited motion no longer drives: its joints still move. One step; a
## motion that then moves nothing is kept until it is removed.
func remove_path() -> void:
	var motion: Motions.Motion = _edited()
	if motion == null or motion.path == null:
		return
	if motion.tracks.is_empty() and motion.driver == null:
		_say("It moves nothing but the path: Remove takes the motion out.")
		return
	_change("took the path out of %s" % Motions.quoted(motion.name), func(edited: Motions.Motion) -> void:
		edited.path = null
		edited.seconds = 0.0)
	_refresh()


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
## its foot, scrolling past that; the panel no bigger than what it shows;
## the status line whole, unless even with the lists at their least the
## window has no room for it.
func _fit() -> void:
	if not visible:
		return
	var parent: Control = get_parent() as Control
	var tall: float = parent.size.y if parent != null else get_viewport_rect().size.y
	# By finger, the room is what the tools' column shows, which already
	# keeps clear of the row of tools at the screen's foot. The box it sits
	# in scrolls in that column and is as tall as what it holds: measured
	# from the box, with the window's foot taken off again, the list was
	# given its least, the panel came out taller than the sheet, and the
	# sheet scrolled the whole panel as well as the list (smalls7).
	var foot: float = FOOT
	if Phone.on():
		foot = 0.0
		var column: ScrollContainer = parent.get_parent() as ScrollContainer if parent != null else null
		if column != null:
			tall = column.size.y
	var inner: Control = _body.get_child(0) as Control
	var wanted: float = inner.get_combined_minimum_size().y
	_body.custom_minimum_size.y = 0.0
	# Whole: a label that trims its words is as short as it likes.
	_status.max_lines_visible = -1
	_status.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_status.custom_minimum_size.y = 0.0
	var others: float = get_combined_minimum_size().y
	var room: float = tall - position.y - foot - others
	var least: float = minf(wanted, _least_list())
	if room < least:
		# Words too long for the window: as many lines as it has room for,
		# the last ending "…", and every word in the tooltip. By finger the
		# status scrolls with the list and is never cut.
		if not Phone.on():
			var line: float = _status.get_line_height() + _status.get_theme_constant("line_spacing")
			var lines: int = maxi(_status.get_line_count() - ceili((least - room) / maxf(line, 1.0)), 2)
			_status.max_lines_visible = lines
			_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			_status.custom_minimum_size.y = line * float(lines)
		room = least
	_body.custom_minimum_size.y = clampf(wanted, least, maxf(room, 80.0))
	reset_size()
	# Shrunk to its least across too: the box it sits in lays it out again,
	# as wide as the box. Its least size changes back by the end of a fit as
	# often as not, which tells the box nothing, and with the foot in the
	# list (by finger) nothing else did: the panel stayed a third narrower
	# than the screen (smalls7).
	var box: Container = parent as Container
	if box != null:
		box.queue_sort()


## The least of the list's own height: by finger three rows, each a
## fingertip's target and the gap between rows; with the mouse 80 units.
func _least_list() -> float:
	if not Phone.on():
		return 80.0
	return 3.0 * (Phone.px(get_viewport(), Phone.TARGET) + 3.0)


## How tall the panel is with its list at its least (three rows by finger,
## or the whole list where it is shorter): the least the tools' sheet under
## the model gives it on a phone held upright (Main._size_tool_sheet).
func least_tall() -> float:
	if not visible:
		return 0.0
	var inner: Control = _body.get_child(0) as Control
	var others: float = get_combined_minimum_size().y - _body.get_combined_minimum_size().y
	return others + minf(inner.get_combined_minimum_size().y, _least_list())


# -- for a browser test ---------------------------------------------------------------


func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	# motions_list: the list's scroller, so a check knows where its rows are
	# in sight (tools/web/phonewalk_flow.mjs bringIn), the foot scrolling
	# with them by finger.
	var out: Dictionary = {"motions_close": _close, "motions_render": _render, "motions_cancel": _cancel,
		"motions_rate": _rate, "motions_size": _size, "motions_list": _body}
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
		for n: int in _unlock_buttons.size():
			out["motion_unlock_%d" % n] = _unlock_buttons[n]
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
			"motions_time": _time, "motions_how": _how, "motions_drop_key": _drop_key,
			"motions_key_camera": _camera_key, "motions_turntable": _camera_turn,
			"motions_camera_keys": _camera_strip})
		for n: int in _joint_parts.size():
			out["motions_joint_%d" % n] = _joint_parts[n]["slider"]
			out["motions_lock_%d" % n] = _joint_parts[n]["lock"]
	var shown: Dictionary = {}
	for key: String in out:
		var item: Variant = out[key]
		if is_instance_valid(item) and (item as Control).is_visible_in_tree():
			shown[key] = item
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
			"keys": track.keys.size() if track != null else 0,
			"locked": (part["lock"] as Button).button_pressed}
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
		"hold": hold_words() if _hold.visible else "",
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
	## A key pressed; [param adding] with Ctrl held (Cmd on a Mac): picked
	## with those picked already.
	signal picked(index: int, adding: bool)
	signal moved(index: int, t: float)
	## A key let go where it was pressed, not dragged; [param adding] as its press.
	signal let_go(index: int, adding: bool)
	signal timed(t: float)

	var times: Array = []
	## The seconds the strip spans, from 0.
	var span: float = 4.0
	var now: float = 0.0
	var chosen: int = -1
	## The keys picked together with others (Ctrl+click), drawn as chosen.
	var also: Array = []
	var _dragging: int = -1
	var _drag_t: float = 0.0
	var _adding: bool = false
	## How near a press takes a key, px: half a fingertip for a finger.
	var near: float = NEAR
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
			var r: float = maxf(4.5, size.y * 0.18)
			var colour: Color = Look.ACCENT if n == chosen or also.has(n) else Color(1, 1, 1, 0.85)
			draw_colored_polygon(PackedVector2Array([Vector2(x, mid - r), Vector2(x + r, mid),
				Vector2(x, mid + r), Vector2(x - r, mid)]), colour)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var press: InputEventMouseButton = event
			if press.pressed:
				var nearest: int = -1
				var best: float = near
				for n: int in times.size():
					var off: float = absf(_x_of(float(times[n])) - press.position.x)
					if off <= best:
						best = off
						nearest = n
				if nearest >= 0:
					chosen = nearest
					_dragging = nearest
					_drag_t = float(times[nearest])
					_adding = press.ctrl_pressed or press.meta_pressed
					picked.emit(nearest, _adding)
				else:
					timed.emit(_t_of(press.position.x))
				accept_event()
			elif _dragging >= 0:
				var index: int = _dragging
				_dragging = -1
				if absf(_drag_t - float(times[index])) > 0.02:
					moved.emit(index, _drag_t)
				else:
					let_go.emit(index, _adding)
				queue_redraw()
				accept_event()
		elif event is InputEventMouseMotion and _dragging >= 0:
			_drag_t = snappedf(_t_of((event as InputEventMouseMotion).position.x), 0.05)
			queue_redraw()
			accept_event()
