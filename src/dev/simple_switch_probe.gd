## simple_switch: the studio's controls swapped live between Full and Simple
## (Main.use_controls) lose nothing. Only the controls go: the model, its undo,
## the selection, what is in hand, a drag under way, the camera and the save
## are the same objects either side (Simple's plan, P2:
## bench/results/simplemode-2026-11-24/PLAN.md).
##
##   godot --path . --resolution 1280x720 --script src/dev/simple_switch_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh simple_switch_probe              the desktop's layout
##   PROBE_SIZE=390x844 tools/probe.sh simple_switch_probe               a phone's
##   PROBE_SIZE=1280x720 tools/probe.sh simple_switch_probe --case=drag  one case
##
## --case= layer, models, steps, hand, drag, typing, start (all when not said);
## --pictures=DIR keeps a picture of each layer there.
##   layer   Simple in and out: the studio's own controls put away but its
##           header (the desktop's column, the phone's bars) and back,
##           Simple's layer in their place, the model seen under the header
##           and over Simple's tray, a point where the parts bin was the
##           model's or Simple's, and the header's Full pressed brings the
##           studio back. Nothing of the model changes; the view is Simple's
##           framing in Simple and Full's again back in Full.
##   models  Simple's plan's P2 on four real models: 10030-1 (136 sub-model
##           sections), 6685-1 (the author's steps), 5972-1 (LSynth hoses, its
##           flexible parts) and 4005-1 with two parts the library lacks, one
##           in a sub-model. On each, Simple in and back; a part moved in Full;
##           into Simple, a part from the bin put down, a part moved, one
##           painted and one deleted, each by the command a person's press
##           runs, one undone and redone there; back to Full, the five undone
##           across the switch to the model as opened, redone, saved and
##           reopened. Held to the same edits made in Full alone: the file
##           saved byte for byte the same; every line of the file nobody
##           touched kept, byte for byte and in order, its steps and sections
##           with it; reopened, every part where it was.
##   steps   6685-1's timeline on its fifth step, a part selected: into Simple
##           the whole model shown, the selection kept, and the timeline key
##           opens nothing there; a part put down; back in Full, the timeline
##           on the same step. Saved and reopened, the steps as they were.
##   hand    A part from the bin in hand, and a part lifted off the model (X),
##           each through a switch both ways: still in hand, the ghost's part
##           and colour as they were, put down in Simple or put back (Esc)
##           where it was, byte for byte.
##   drag    A part dragged (the left button, or a finger on a phone), the
##           switch made half way, the drag carried on and let go: one step,
##           undone to where it was; and the other way round.
##   typing  The model's name being typed as the switch comes: the words kept.
##   start   ShellPrefs "controls" read at the start, and --controls= taking it.
## Exits non-zero when a check fails.
extends "res://src/dev/exactsave_probe.gd"

const STEPPED := "res://vendor/omr/files/6685-1.mpd"
const MODELS: Array = [
	["10030", "res://vendor/omr/files/10030-1.mpd"],
	["stepped", STEPPED],
	["flexible", "res://vendor/omr/files/5972-1.mpd"],
	["unshown", ""],
]
## 4005-1 and the two parts the library lacks put in it (_unshown_file).
const UNSHOWN_FROM := "res://vendor/omr/files/4005-1.mpd"

var _camera: CadCamera
var _shell: Shell
var _steps: StepsBar
var _layout: String = "desktop"
var _size: String = ""
var _pictures: String = ""
var _asked: PackedStringArray = []


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("simple_switch_probe: needs a window")
		quit(1)
		return
	var cases: String = "layer,models,steps,hand,drag,typing,start"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			cases = arg.trim_prefix("--case=")
		if arg.begins_with("--pictures="):
			_pictures = arg.trim_prefix("--pictures=")
	_asked = cases.split(",", false)
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	_layout = "phone" if mini(window.x, window.y) < int(Phone.NARROW) else "desktop"
	Phone._on = 0 if _layout == "desktop" else 1
	Phone._wide = false
	Keymap.reset()
	Keymap.use("brickworks")
	_forget(PROBE_DIR)
	DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
	SaveTo.native = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	# A phone draws at a browser's scale, as twist_probe holds it.
	if _layout == "phone":
		(_main.get("_phone") as Node).set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
	await _frames(20)
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_verbs = _main.get("_verbs")
	_store = _main.get("_store")
	_store.keeps = false
	_camera = _main.get("_camera")
	_shell = _main.get("_shell")
	_steps = _main.get("_steps")
	print("simple_switch_probe: a %s window, laid out for a %s" % [_size, _layout])
	if "layer" in _asked:
		await _case_layer()
	if "models" in _asked:
		for model: Array in MODELS:
			await _case_model(str(model[0]), str(model[1]) if not str(model[1]).is_empty()
				else _unshown_file())
	if "steps" in _asked:
		await _case_steps()
	if "hand" in _asked:
		await _case_hand()
	if "drag" in _asked:
		await _case_drag()
	if "typing" in _asked:
		await _case_typing()
	if "start" in _asked:
		_case_start()
	if _main.call("controls_layer") != &"full":
		_main.call("use_controls", &"full")
	_forget(PROBE_DIR)
	print("\nsimple_switch_probe: %d failed, %d notes" % [_failures, _notes])
	quit(1 if _failures > 0 else 0)


# -- the cases ---------------------------------------------------------------------


func _case_layer() -> void:
	print("\nlayer: Simple in and out, %s" % _layout)
	await _open(STEPPED)
	# The open's framing eased out before the camera is read (simplereview
	# F4: read at once it differed with the switch and without it).
	await _settle()
	var column: Control = (_main.get("_bar") as Control).get_parent()
	var phone: Control = _main.get("_phone")
	var bin_dock: Control = _main.get("_bin_dock")
	# A point where the parts bin is, or the phone's foot row: the studio's.
	var studio_point: Vector2 = bin_dock.get_global_rect().get_center() if phone == null \
		else Vector2(root.get_visible_rect().size.x * 0.5, root.get_visible_rect().size.y - 8.0)
	_ok(bool(_main.call("_over_panel_at", studio_point)), "in Full, %s is the studio's" % studio_point)
	await _picture("full")
	var before: Dictionary = _state()
	_ok(bool(_main.call("use_controls", &"simple")), "use_controls(simple)")
	await _frames(6)
	var simple: Control = _main.get("_simple")
	var bar: Control = _main.get("_bar")
	_ok(_main.call("controls_layer") == &"simple", "the layer says simple")
	# The header stays, as in every mode: everything else of the column goes,
	# and on a phone its bars but the header's row.
	var shown: Array = []
	for child: Node in column.get_children():
		if child != bar and child is Control and (child as Control).visible:
			shown.append(str(child.name))
	if phone != null:
		for what: String in ["_row", "_pill", "_fit", "_name"]:
			var part: Control = phone.get(what)
			if part != null and part.is_visible_in_tree():
				shown.append("phone " + what)
	_ok(shown.is_empty(), "the studio's own controls put away but its header (still shown: %s)" % ", ".join(shown))
	var header: Control = bar if phone == null else phone.get("_top")
	_ok(header != null and header.is_visible_in_tree(), "the studio's header kept")
	_ok(simple != null and simple.is_visible_in_tree(), "Simple's layer up")
	var room: Rect2 = _camera.seen_rect()
	var simple_room: Rect2 = simple.call("model_room", root.get_visible_rect())
	_ok(room.position.distance_to(simple_room.position) < 1.0 and room.size.distance_to(simple_room.size) < 1.0,
		"the model is seen under the header and over the tray: %s, Simple's room %s" % [room, simple_room])
	_ok(not bool(_main.call("_over_panel_at", studio_point)) or bool(simple.call("covers", studio_point)),
		"%s is the model's or Simple's own in Simple" % studio_point)
	var named: Dictionary = _main.call("_page_controls")
	var full: Button = named.get("controls_full")
	_ok(full != null and full.is_visible_in_tree(), "Full is on the page's list, in the header")
	if full != null:
		_ok(root.get_visible_rect().encloses(full.get_global_rect()) and full.size.x > 20.0,
			"Full on the screen: %s in %s" % [full.get_global_rect(), root.get_visible_rect()])
		_ok(_drawn_over(full).is_empty(), "nothing drawn over Full%s" % _drawn_over(full))
		_ok(bool(_main.call("_over_panel_at", full.get_global_rect().get_center())),
			"a press on Full is not the model's")
		if _layout == "phone":
			var least: float = Phone.px(root, Phone.TARGET) - 0.5
			_ok(full.size.y >= least and full.size.x >= least, "Full is a fingertip each way: %s" % full.size)
	_ok(str(ShellPrefs.value("controls")) == "simple", "remembered: simple")
	_same("into Simple", before, _state(), false)
	await _picture("simple")
	if full != null:
		full.pressed.emit()
	await _frames(6)
	_ok(_main.call("controls_layer") == &"full" and column.visible and (phone == null or phone.visible)
		and not simple.visible, "Full pressed: the studio's controls back, Simple's gone")
	_ok(bool(_main.call("_over_panel_at", studio_point)), "%s is the studio's again" % studio_point)
	_ok(str(ShellPrefs.value("controls")) == "full", "remembered: full")
	_same("back to Full", before, _state())
	_ok(bool(_main.call("use_controls", &"full")) and not bool(_main.call("use_controls", &"tiny")),
		"Full asked again is no change; a layer nobody made is refused")


## P2 on one model: the same edits made in Full alone and through the switch,
## each saved; held to each other and to the file.
func _case_model(tag: String, path: String) -> void:
	print("\nmodels: %s (%s), %s" % [tag, path.get_file(), _layout])
	var original: String = _text_of(path)
	await _open(path)
	var opened: Array = _records_all()
	var plan: Dictionary = _plan(opened)
	if plan.is_empty():
		_ok(false, "%s: four parts to edit, each placed once" % tag)
		return
	print("    editing %s" % plan["said"])
	# A: the edits in Full alone.
	var a_marks: Dictionary = await _edits(plan, false)
	if a_marks.is_empty():
		return
	await _walk_back(5, opened, a_marks["after"], tag + " in Full alone")
	var a_at: String = ProjectSettings.globalize_path(PROBE_DIR + tag + "-full.mpd")
	_ok(bool(_main.call("save_model", a_at)), "%s: saved, the edits in Full alone" % tag)
	var a_text: String = _text_of(a_at)
	var a_whole: String = _store.last_whole
	_kept(tag + "-full.mpd", a_text)

	# B: through the switch.
	await _open(path)
	_exact("%s: opened again as before" % tag, opened, _records_all())
	var again: Dictionary = _plan(_records_all())
	_ok(again.get("said", "") == plan["said"], "%s: the same parts chosen" % tag)
	_select([plan["p1"]])
	var before: Dictionary = _state()
	# The first switch of a run makes Simple's layer (Later loads its script):
	# said, not held, as a first use of anything loaded on first use.
	var making: bool = _main.get("_simple") == null
	var into: Array = []
	var back: Array = []
	for n: int in 3:
		into.append(_timed(&"simple"))
		await _frames(3)
		if n == 0:
			_same("%s: into Simple" % tag, before, _state(), false)
		back.append(_timed(&"full"))
		await _frames(3)
	_same("%s: and back to Full, three times over" % tag, before, _state())
	if making:
		_note("%s: the first switch, Simple's layer made: %.1f ms" % [tag, into[0]])
		into.remove_at(0)
	# The switch is the controls' work alone, whatever the model's size: the
	# least of its runs, as the box's load only adds.
	_ok(into.min() < 16.0 and back.min() < 16.0,
		"%s: the switch in %.1f ms and back in %.1f ms (the least of %s and %s)"
		% [tag, into.min(), back.min(), into, back])
	# Saved with no edit after the switch: the file as it came, byte for byte.
	var plain_at: String = ProjectSettings.globalize_path(PROBE_DIR + tag + "-unedited.mpd")
	_ok(bool(_main.call("save_model", plain_at)), "%s: saved unedited after a switch" % tag)
	_ok(_text_of(plain_at) == original, "%s: unedited after a switch, the file byte for byte (%d bytes against %d)"
		% [tag, _text_of(plain_at).length(), original.length()])
	_builder.clear_selection()
	var b_marks: Dictionary = await _edits(again, true)
	if b_marks.is_empty():
		return
	_exact("%s: the edits made through the switch are the edits made in Full" % tag,
		a_marks["after"], b_marks["after"])
	# Undo across the switch: the four of Simple, then the one of Full.
	await _undo_redo(4, false)
	_exact("%s: four undone in Full, back to before the switch" % tag, b_marks["e0"], _records_all())
	await _undo_redo(1, false)
	_exact("%s: and the one before it, the model as opened" % tag, opened, _records_all())
	await _undo_redo(5, true)
	_exact("%s: all five redone" % tag, b_marks["after"], _records_all())
	var b_at: String = ProjectSettings.globalize_path(PROBE_DIR + tag + "-switched.mpd")
	_ok(bool(_main.call("save_model", b_at)), "%s: saved, through the switch" % tag)
	var b_text: String = _text_of(b_at)
	_kept(tag + "-switched.mpd", b_text)
	_ok(b_text == a_text, "%s: saved byte for byte as the same edits in Full alone (%d bytes against %d%s)"
		% [tag, b_text.length(), a_text.length(),
			"" if _store.last_whole == a_whole else "; whole: %s / %s" % [_store.last_whole, a_whole]])
	_untouched(tag, original, b_text)
	await _open(b_at)
	_exact("%s: reopened, every part where it was" % tag, b_marks["after"], _records_all())


## 6685-1's timeline on its fifth step, through the switch.
func _case_steps() -> void:
	print("\nsteps: the timeline through the switch, %s" % _layout)
	var original: String = _text_of(STEPPED)
	await _open(STEPPED)
	await _main.call("_toggle_steps")
	for _n: int in 600:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	_ok(_steps.is_playing_back(), "the timeline open")
	for _n: int in 4:
		_steps.step_forward()
		await _frames(2)
	var at: Instructions.Step = _steps.current_step()
	var number: int = at.number if at != null else -1
	_ok(number > 1, "on step %d" % number)
	var ahead: int = (_builder.lattice.ahead as Dictionary).size()
	_ok(ahead > 0, "%d parts not put on yet" % ahead)
	var shown_one: int = -1
	for brick: BrickWorld.Brick in _shown():
		if not (_builder.lattice.ahead as Dictionary).has(brick.id):
			shown_one = brick.id
			break
	_select([shown_one])
	var picked: Array = _builder.selection.keys()
	var opened: Array = _records_all()
	_main.call("use_controls", &"simple")
	await _frames(4)
	_ok(not _steps.is_playing_back(), "into Simple: the timeline put away")
	_ok((_builder.lattice.ahead as Dictionary).is_empty(), "the whole model shown")
	_ok(_builder.selection.keys() == picked, "the selection kept: %s" % [_builder.selection.keys()])
	_exact("the model as it was", opened, _records_all())
	await _main.call("_toggle_steps")
	await _frames(4)
	_ok(not _steps.is_playing_back() and not _steps.is_starting(), "the timeline's key opens nothing in Simple")
	await _picture("simple-steps")
	_builder.clear_selection()
	var put: int = await _add_part(_spots_for(opened, [])[0])
	_ok(put != 0, "a part put down in Simple (its step %d)" % (_world.get_brick(put).step if put != 0 else -1))
	var after: Array = _records_all()
	_main.call("use_controls", &"full")
	for _n: int in 600:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	await _frames(3)
	var back: Instructions.Step = _steps.current_step()
	_ok(_steps.is_playing_back() and back != null and back.number == number,
		"back in Full: the timeline on step %d again (%d)" % [number, back.number if back != null else -1])
	await _picture("full-steps")
	_steps.stop()
	await _frames(2)
	var saved_at: String = ProjectSettings.globalize_path(PROBE_DIR + "steps.mpd")
	_ok(bool(_main.call("save_model", saved_at)), "saved")
	var saved: String = _text_of(saved_at)
	_untouched("steps", original, saved)
	await _open(saved_at)
	_exact("steps: reopened, every part where it was", after, _records_all())
	_ok(AuthorSteps.any(_world, _store.scenery), "reopened with its author's steps")

	# A timeline left on one model is not opened on another opened in Simple.
	await _main.call("_toggle_steps")
	for _n: int in 600:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	_main.call("use_controls", &"simple")
	await _frames(3)
	await _open("res://vendor/omr/files/5972-1.mpd")
	_main.call("use_controls", &"full")
	await _frames(60)
	_ok(not _steps.is_playing_back() and not _steps.is_starting(),
		"a timeline left on 6685-1 is not opened on 5972-1, opened in Simple")


## A part from the bin, and a part lifted (X), each held through the switch.
func _case_hand() -> void:
	print("\nhand: what is in hand through the switch, %s" % _layout)
	var fresh: Array = await _fresh()
	var depth: int = _builder.history_depth()
	_main.call("_on_part_chosen", "3003")
	_main.call("_on_color_chosen", 1)
	await _frames(2)
	var held: Array = [_builder.held_part, _builder.held_color, _verbs.mode]
	_main.call("use_controls", &"simple")
	await _frames(3)
	_ok([_builder.held_part, _builder.held_color, _verbs.mode] == held,
		"into Simple: still in hand, %s" % [[_builder.held_part, _builder.held_color, _verbs.mode]])
	var put: int = await _place_at(Vector3(200, 0, 0))
	_ok(put != 0 and _world.get_brick(put).part_id == "3003" and _world.get_brick(put).color_code == 1,
		"put down in Simple: %s" % (_world.get_brick(put).part_id if put != 0 else "nothing"))
	_main.call("use_controls", &"full")
	await _frames(3)
	_ok([_builder.held_part, _builder.held_color, _verbs.mode] == held, "back in Full: still in hand")
	_ok(_builder.history_depth() == depth + 1, "one step")
	await _undo_redo(1, false)
	_exact("undone: the model as it was", fresh, _records_all())
	_verbs.set_mode("select")
	_builder.held_part = ""

	# A part lifted off the model, put back by Escape.
	var small: int = _small_id()
	_select([small])
	_ok(_verbs.lift() > 0 and _builder.is_carrying(), "the 2 x 2 lifted (X)")
	_main.call("use_controls", &"simple")
	await _frames(3)
	_ok(_builder.is_carrying(), "into Simple: still carried")
	_main.call("use_controls", &"full")
	await _frames(3)
	_ok(_builder.is_carrying(), "back in Full: still carried")
	_main.call("use_controls", &"simple")
	await _frames(3)
	_verbs.put_away()
	await _frames(3)
	_ok(not _builder.is_carrying(), "put back (Esc) in Simple")
	_exact("put back where it was", fresh, _records_all())
	_ok(_builder.history_depth() == depth, "no step left by it")
	_main.call("use_controls", &"full")
	await _frames(3)

	# Lifted in Full, put down in Simple, undone in Full.
	_select([small])
	_verbs.lift()
	_main.call("use_controls", &"simple")
	await _frames(3)
	var moved: Dictionary = await _put([Vector3(-200, 0, 0), Vector3(-300, 0, 120)])
	_ok(not _builder.is_carrying() and (moved["ids"] as Array).size() <= 1,
		"put down elsewhere in Simple (at %s)" % [moved["spot"]])
	_ok(_shown().size() == fresh.size(), "no part more or less: %d" % _shown().size())
	_main.call("use_controls", &"full")
	await _frames(3)
	await _undo_redo(1, false)
	_exact("undone in Full: where it was", fresh, _records_all())


## A part dragged, the switch made half way.
func _case_drag() -> void:
	print("\ndrag: the switch half way through a drag, %s" % _layout)
	for into: StringName in [&"simple", &"full"]:
		var fresh: Array = await _fresh()
		if into == &"full":
			_main.call("use_controls", &"simple")
			await _frames(3)
		_camera.frame(_main.call("_built_bounds"))
		await _settle()
		var small: int = _small_id()
		var from: Vector2 = _point_on(small)
		_ok(from.x < INF, "the 2 x 2 is under %s" % from)
		if from.x == INF:
			continue
		var depth: int = _builder.history_depth()
		var to: Vector2 = from + Vector2(root.get_visible_rect().size.x * 0.12, 0)
		_down(from, true)
		await process_frame
		var at: Vector2 = from
		var held_mid: bool = false
		for n: int in 20:
			var next: Vector2 = from.lerp(to, float(n + 1) / 20.0)
			_moving(next, next - at)
			at = next
			await process_frame
			if n == 9:
				# Simple's mouse is a finger: its drag is its own (SimpleLayer).
				var simple: Node = _main.get("_simple")
				held_mid = bool(_main.get("_dragging_part")) or bool(_main.get("_grabbing")) \
					or (simple != null and simple.is_visible_in_tree() and bool(simple.get("_moving")))
				_main.call("use_controls", into)
				await process_frame
		_ok(held_mid, "taken hold of before the switch")
		if into == &"full":
			# Simple's own drag is put back as Simple goes, as a second
			# finger puts it back: where it stood, nothing in hand, no step.
			_ok(not bool(_main.get("_dragging_part")) and not _builder.is_carrying(),
				"into full half way: Simple's drag put back, nothing in hand")
			_down(to, false)
			await _frames(8)
			_ok(_builder.history_depth() == depth, "...no step (%d)" % (_builder.history_depth() - depth))
			_exact("...every part where it was", fresh, _records_all())
			continue
		_ok(bool(_main.get("_dragging_part")) or bool(_main.get("_grabbing")),
			"into %s half way: still held" % into)
		_down(to, false)
		await _frames(8)
		_ok(not bool(_main.get("_dragging_part")) and not _builder.is_carrying(), "let go: nothing left in hand")
		_ok(_shown().size() == fresh.size(), "no part more or less: %d" % _shown().size())
		var moved: bool = _moved_count(fresh) > 0
		_ok(moved and _builder.history_depth() == depth + 1,
			"the drag landed as one step (%d), the part moved: %s" % [_builder.history_depth() - depth, moved])
		await _undo_redo(1, false)
		_exact("undone: where it was", fresh, _records_all())
		if _main.call("controls_layer") != &"full":
			_main.call("use_controls", &"full")
			await _frames(3)


## The model's name being typed as the switch comes.
func _case_typing() -> void:
	print("\ntyping: the name being typed through the switch, %s" % _layout)
	await _fresh()
	# The bar's, which a phone's top bar shows as its own (PhoneShell).
	var field: LineEdit = (_main.get("_bar") as Node).get("_name") as LineEdit
	_ok(field != null and field.is_visible_in_tree(), "the name field")
	if field == null:
		return
	# A click takes the whole name (select_all_on_focus), so what is typed
	# replaces it, key by key as a keyboard sends it.
	field.grab_focus()
	await _frames(2)
	for c: String in "Harbour":
		for down: bool in [true, false]:
			var key := InputEventKey.new()
			key.keycode = OS.find_keycode_from_string(c.to_upper())
			key.unicode = c.unicode_at(0)
			key.pressed = down
			Input.parse_input_event(key)
		await process_frame
	await _frames(2)
	_ok(field.text == "Harbour", "typed: %s" % field.text)
	_main.call("use_controls", &"simple")
	await _frames(3)
	_ok(root.gui_get_focus_owner() == null, "into Simple: the field left")
	_ok(_store.title == "Harbour", "the name kept: %s" % _store.title)
	_main.call("use_controls", &"full")
	await _frames(3)
	_ok(field.text == "Harbour" and _store.title == "Harbour", "back in Full: %s" % field.text)


## ShellPrefs "controls" and --controls= read at the start.
func _case_start() -> void:
	print("\nstart: the hidden switch")
	ShellPrefs.put("controls", "simple")
	_ok(_main.call("_controls_wanted") == &"simple", "the device left in Simple starts in it")
	ShellPrefs.put("controls", "full")
	_ok(_main.call("_controls_wanted") == &"full", "and in Full")
	_ok(str(ShellPrefs.DEFAULTS.get("controls")) == "full", "a first visit is in Full")


# -- the edits ---------------------------------------------------------------------


## Four parts of the file to edit, far apart in its order, each of the model's
## own section or a sub-model placed once (so one line places each), and a
## spot beside the model for a part from the bin: {p0..p3, spot, said}.
func _plan(records: Array) -> Dictionary:
	var units_of: Dictionary = {}
	for brick: BrickWorld.Brick in _shown():
		var leaf: String = Assemblies.definition(Assemblies.leaf(brick.unit)) if not brick.unit.is_empty() else ""
		if not units_of.has(leaf):
			units_of[leaf] = {}
		(units_of[leaf] as Dictionary)[brick.unit] = true
	var once: Array = []
	for brick: BrickWorld.Brick in _shown():
		var leaf: String = Assemblies.definition(Assemblies.leaf(brick.unit)) if not brick.unit.is_empty() else ""
		if not brick.origin.is_empty() and (units_of[leaf] as Dictionary).size() == 1:
			once.append(brick)
	if once.size() < 8:
		return {}
	var picked: Array = []
	for k: int in 4:
		picked.append(once[int(float(k) / 4.0 * (once.size() - 1)) + k % 2])
	var said := PackedStringArray()
	for brick: BrickWorld.Brick in picked:
		said.append("%s %d (%s)" % [brick.part_id, brick.id, brick.unit if not brick.unit.is_empty() else "main"])
	return {"p0": picked[0].id, "p1": picked[1].id, "p2": picked[2].id, "p3": picked[3].id,
		"spot": _spots_for(records, [])[0], "said": ", ".join(said)}


## E0 a part moved in Full; then, in Simple when [param switch], E1 a 2 x 4
## from the bin put down, E2 a part moved, E3 one painted and E4 one deleted,
## each by the command a person's press runs, E4 undone and redone; back to
## Full. {e0, after}: the model after E0 and after all five; {} when an edit
## could not be made.
func _edits(plan: Dictionary, switch: bool) -> Dictionary:
	var depth: int = _builder.history_depth()
	if not await _moved(_world.get_brick(int(plan["p0"]))):
		_ok(false, "E0: %d has no room to move" % int(plan["p0"]))
		return {}
	var marks: Dictionary = {"e0": _records_all()}
	if switch:
		_select([plan["p1"]])
		var before: Dictionary = _state()
		_main.call("use_controls", &"simple")
		await _frames(3)
		_same("into Simple after an edit in Full", before, _state(), false)
		_builder.clear_selection()
	var put: int = await _add_part(plan["spot"])
	if put == 0:
		_ok(false, "E1: no room for a 2 x 4 at %s" % plan["spot"])
		return {}
	if not await _moved(_world.get_brick(int(plan["p1"]))):
		_ok(false, "E2: %d has no room to move" % int(plan["p1"]))
		return {}
	var painted: BrickWorld.Brick = _world.get_brick(int(plan["p2"]))
	_select([painted.id])
	_main.call("_on_color_chosen", 1 if painted.color_code != 1 else 4)
	await _verbs.press("paint")
	_select([plan["p3"]])
	await _verbs.press("delete")
	await _frames(2)
	_ok(_builder.history_depth() == depth + 5, "five edits, five steps (%d)%s"
		% [_builder.history_depth() - depth, " (four in Simple)" if switch else ""])
	marks["after"] = _records_all()
	if switch:
		_ok(_main.call("controls_layer") == &"simple", "the four made in Simple")
		var count: int = _world.brick_count()
		await _undo_redo(1, false)
		_ok(_world.brick_count() == count + 1, "undone in Simple: the part deleted is back")
		await _undo_redo(1, true)
		_exact("and redone in Simple", marks["after"], _records_all())
		var before: Dictionary = _state()
		_main.call("use_controls", &"full")
		await _frames(3)
		_same("back to Full", before, _state(), false)
	return marks


## A 2 x 4 from the bin, yellow, put down at [param spot]: its id, or 0.
func _add_part(spot: Vector3) -> int:
	_main.call("_on_part_chosen", "3001")
	_main.call("_on_color_chosen", 14)
	await _frames(2)
	var put: int = await _place_at(spot)
	_verbs.set_mode("select")
	_builder.held_part = ""
	return put


## use_controls([param layer]) timed: the call's ms, rounded to a tenth.
func _timed(layer: StringName) -> float:
	var began: int = Time.get_ticks_usec()
	_main.call("use_controls", layer)
	return snappedf((Time.get_ticks_usec() - began) / 1000.0, 0.1)


## [param count] undone (or redone) as the person's Undo and Redo do.
func _undo_redo(count: int, redo: bool) -> void:
	for _n: int in count:
		await _verbs.own_undo(redo)
		await _frames(2)


## The edits undone to the model as opened, and redone.
func _walk_back(count: int, opened: Array, after: Array, said: String) -> void:
	await _undo_redo(count, false)
	_exact("%s: undone to the model as opened" % said, opened, _records_all())
	await _undo_redo(count, true)
	_exact("%s: redone" % said, after, _records_all())


# -- what a switch must leave as it was -------------------------------------------


func _state() -> Dictionary:
	var picked: Array = _builder.selection.keys()
	picked.sort()
	return {"records": _records_all(), "selection": picked, "undo": _builder.history_depth(),
		"redo": (_builder.get("_redo") as Array).size(), "entered": _shell.assemblies.entered,
		"mode": _verbs.mode, "held": [_builder.held_part, _builder.held_color, _builder.is_carrying()],
		"unsaved": _store.has_unsaved_work(), "title": _store.title, "path": [_store.get("_saved_as"), _store.get("_known_path")],
		"camera": [_camera.get("_target_yaw"), _camera.get("_target_pitch"), _camera.get("_target_distance"),
			_camera.get("_target_focus"), _camera.global_transform]}


## Into Simple the view is framed on the model whole in Simple's room
## (SimpleLayer.entered), so [param camera] false leaves it out; back in
## Full it is Full's again.
func _same(said: String, was: Dictionary, now: Dictionary, camera: bool = true) -> void:
	var differ := PackedStringArray()
	for key: String in was:
		if key == "camera" and not camera:
			continue
		if str(was[key]) != str(now[key]):
			differ.append(key)
	_ok(differ.is_empty(), "%s: the model, selection, undo, hand, tool, save%s as they were%s"
		% [said, " and camera" if camera else "", "" if differ.is_empty() else " (differ: %s)" % ", ".join(differ)])


## Every line of [param original] nobody touched is in [param saved], byte for
## byte and in order; what is gone is part lines alone, at most the four
## edited; its steps and sections all there.
func _untouched(tag: String, original: String, saved: String) -> void:
	var diff: Dictionary = _line_diff(original, saved)
	var lost: Array = diff["lost"]
	var parts_only: bool = lost.all(func(line: String) -> bool: return line.strip_edges().begins_with("1 "))
	_ok(lost.size() <= 4 and parts_only, "%s: %d of the file's lines gone, each an edited part's (%s)"
		% [tag, lost.size(), " | ".join(PackedStringArray(lost.slice(0, 4)))])
	var kept: String = _without(original, lost)
	var put_in: Variant = _kept_in_order(kept, _without(saved, []))
	_ok(put_in != null, "%s: every other line kept, byte for byte and in order" % tag)
	for meta: String in ["0 STEP", "0 FILE ", "0 NOFILE", "SYNTH"]:
		_ok(saved.count(meta) >= original.count(meta), "%s: %s lines %d (the file's %d)"
			% [tag, meta.strip_edges(), saved.count(meta), original.count(meta)])


## [param text]'s lines but the first of each of [param lines].
static func _without(text: String, lines: Array) -> String:
	var take: Dictionary = {}
	for line: String in lines:
		take[line] = int(take.get(line, 0)) + 1
	var out := PackedStringArray()
	for line: String in text.replace("\r", "").split("\n"):
		if int(take.get(line, 0)) > 0:
			take[line] = int(take[line]) - 1
			continue
		out.append(line)
	return "\n".join(out)


# -- models, fingers and pictures ----------------------------------------------------


## 4005-1 with a part the library lacks in its own section and another in its
## boat, written to the probe's folder: its path.
func _unshown_file() -> String:
	var lines: PackedStringArray = _text_of(UNSHOWN_FROM).split("\n")
	var out := PackedStringArray()
	var files: int = 0
	var put: int = 0
	for line: String in lines:
		out.append(line)
		if line.begins_with("0 FILE "):
			files += 1
		elif line.begins_with("1 ") and put < files and files <= 2:
			put = files
			out.append("1 %d -200 -24 40 1 0 0 0 1 0 0 0 1 zzzsimplep2%s.dat\r" % [4 if files == 1 else 14,
				"a" if files == 1 else "b"])
	var at: String = PROBE_DIR + "unshown.mpd"
	_write(ProjectSettings.globalize_path(at), "\n".join(out))
	return at


## The HUD's controls after Simple's layer, shown, whose rectangles meet
## [param control]'s: "" when none.
func _drawn_over(control: Control) -> String:
	var simple: Control = _main.get("_simple")
	var hud: Node = simple.get_parent()
	var over := PackedStringArray()
	for n: int in range(simple.get_index() + 1, hud.get_child_count()):
		var other: Node = hud.get_child(n)
		if other is Control and (other as Control).is_visible_in_tree() \
				and (other as Control).get_global_rect().intersects(control.get_global_rect()):
			over.append("%s %s" % [other.name, (other as Control).get_global_rect()])
	return "" if over.is_empty() else " (%s)" % ", ".join(over)


## A 2 x 4 on the floor and a 2 x 2 beside it, nothing selected: the records.
func _fresh() -> Array:
	_builder.cancel_carry()
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(4)
	for brick: Array in [["3001", 4, Vector3(0, 24, 0)], ["3003", 1, Vector3(80, 24, 0)]]:
		var where := Transform3D(Basis.IDENTITY, brick[2] as Vector3)
		var id: int = _world.add_brick(brick[0], brick[1], where)
		_builder.register(id, brick[0], where)
	_builder.clear_selection()
	_builder.forget_history()
	_verbs.set_mode("select")
	await _frames(3)
	return _records_all()


func _small_id() -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3003":
			return brick.id
	return 0


## How many of [param before]'s parts are no longer where they were.
func _moved_count(before: Array) -> int:
	var now: Dictionary = {}
	for one: Dictionary in _records_all():
		now[int(one["id"])] = one["at"]
	var out: int = 0
	for one: Dictionary in before:
		if not now.has(int(one["id"])) or not (now[int(one["id"])] as Transform3D).is_equal_approx(one["at"]):
			out += 1
	return out


## A point on the screen where [param brick_id] is the part under it.
func _point_on(brick_id: int) -> Vector2:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	if brick == null:
		return Vector2.INF
	var centre: Vector2 = _camera.screen_of(brick.transform.origin + Vector3(0, -6, 0))
	for offset: Vector2 in [Vector2.ZERO, Vector2(0, 4), Vector2(0, -4), Vector2(4, 0), Vector2(-4, 0),
			Vector2(0, 8), Vector2(0, -8)]:
		if _verbs.brick_at(centre + offset) == brick_id:
			return centre + offset
	return Vector2.INF


## The left button (a finger on a phone) down or up at [param at].
func _down(at: Vector2, down: bool) -> void:
	if _layout == "phone":
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = _as_event(at)
		Input.parse_input_event(touch)
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = down
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	press.position = _as_event(at)
	press.global_position = press.position
	Input.parse_input_event(press)


func _moving(at: Vector2, by: Vector2) -> void:
	if _layout == "phone":
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = _as_event(at)
		drag.relative = _as_event(by)
		Input.parse_input_event(drag)
		return
	var move := InputEventMouseMotion.new()
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = _as_event(by)
	Input.parse_input_event(move)


## A point in the viewport's units as the window hands it over.
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


## Frames until the camera stops, and one drawn.
func _settle() -> void:
	var last := Transform3D()
	var still: int = 0
	for _n: int in 600:
		await process_frame
		if _camera.global_transform.is_equal_approx(last):
			still += 1
			if still >= 3:
				break
		else:
			still = 0
		last = _camera.global_transform
	await RenderingServer.frame_post_draw


func _picture(name: String) -> void:
	if _pictures.is_empty():
		return
	await _frames(20)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_pictures)
	root.get_texture().get_image().save_png(_pictures.path_join("%s_%s.png" % [_size, name]))
