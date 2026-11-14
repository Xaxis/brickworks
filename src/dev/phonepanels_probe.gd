## The page editor, Motions and Simulate by finger, on a phone (docs/APP_UX8.md,
## unit phonepanels: the acts docs/app_ux8/phonewalk.md names in their files).
##
##   godot --path . --resolution 390x844 --script src/dev/phonepanels_probe.gd [-- --shots=DIR]
##
## Through the way in first, as a person comes: the sign-in screen up over
## the app (gate_for_probe), a throwaway account signed in with a password
## grant (as binrow_probe), the screen gone; the account deleted at the end.
## Needs .env (SUPABASE_URL, SUPABASE_SECRET_KEY). Then laid out for a phone
## at a browser's scale (as twist_probe holds it), by fingers as the window
## hands them over (InputEventScreenTouch and ScreenDrag; the engine raises
## its own click from them, as a phone's browser does), a touch screen's
## lists dragged by them (Input.emulate_touch_from_mouse, as field_drag_probe).
##
## Each act counts its presses as tools/web/phonewalk_flow.mjs counts them
## (a tap, a drag, a key, and each drag that brings a control into sight in
## its panel, 4.5% of the screen's height as the walk's), from its panel
## open; the More rows that open a panel are the walk's to count.
## 1. the page editor, from the timeline's Lay out the page… on the car's
##    page: an item dragged by a finger; one
##    sized by its corner (its tap, if not selected, and a drag that begins
##    on the fingertip round the corner, outside the item); words added:
##    Add words, a tap in their field to bring the keyboard up, "Hi", in no
##    more than 6 presses (the desktop's 3), the field reading "Hi"; an arrow
##    drawn by Draw an arrow and a drag (4 at most), which sets the words as
##    the selection leaves them; the page's words "Hi" once Done and opened
##    again; Done closes it. Every control on the screen; every control, the
##    corner, the knob, an arrow's handles and the rulers 44 points or more.
## 2. Motions, on 1484-1's doors: New motion (its name and Record in sight,
##    no keyboard asked for), Record, a door swung by a
##    finger as the walk swings one (10 moves 40 ms apart, still 0.2 s),
##    Stop, in no more than 8 presses (the desktop's 4): the drag recorded,
##    no part's actions opened over the panel and the selection as it was.
##    The editor opened again: its first joint's slider in sight in no more
##    than one drag, and dragged by a finger it moves its joint. Every
##    target in the panel, its keys' strips too, 44 points or more.
## 3. Simulate, on simulate_probe's gear train (an 8 driving a 24, put down
##    here; the orrery fixture reads locked since kinefuncs, 2026-11-14): Play in sight as it opens, and a
##    tap plays it; the cycle's slider in sight in no more than one drag, and
##    dragged by a finger it moves the cycle; a tap on another part makes it
##    the driver in no more than 2. Every target 44 points or more.
## 4. Measure taken out says what a finger does, in taps (edit_verbs).
## Pictures in --shots=DIR (else user://phonepanels). Exits non-zero when a
## check fails.
extends SceneTree

const DOORS := "res://vendor/omr/files/1484-1.mpd"
## A fingertip, points: Phone.TARGET, read to half a point.
const LEAST := Phone.TARGET - 0.5
## A drag that brings a control into sight, as the walk's: this much of the
## screen's height.
const SWIPE := 0.045
## The page editor's own controls (its items are the page's).
const PAGE_CONTROLS: Array[String] = ["page_prev", "page_next", "page_add_text", "page_add_image",
	"page_add_arrow", "page_arrow_colour", "page_arrow_width", "page_smaller", "page_larger",
	"page_put_back", "page_apply_later", "page_done", "page_words", "page_turn", "page_opacity",
	"page_ruler_top", "page_ruler_left"]

var _failures: int = 0
## The sections to run (--only=page,motions,simulate,measure); all when empty.
var _only: PackedStringArray = []
var _item_name: RegEx = RegEx.create_from_string("^page_[a-z]+_\\d+_\\d+$")
var _main: Node
var _camera: CadCamera
var _world: BrickWorld
var _builder: Builder
var _shell: Shell
var _store: ModelStore
var _phone: Node
var _out: String = "user://phonepanels"
var _email: String = ""
var _password: String = ""
## Presses of the act under way.
var _presses: int = 0
## Every act: [what, the desktop's presses, presses here, the most allowed].
var _acts: Array = []
## Every target measured: [name, across, down], points.
var _targets: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("phonepanels_probe: needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	ShellPrefs.kept_by_a_check = _own_data_folder()
	Phone._on = 1
	Phone._wide = false
	# A touch screen's: a list follows a finger only where there is one.
	Input.emulate_touch_from_mouse = true
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	# The sign-in screen over the app, as a person opening it meets it.
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	# A phone draws at a browser's scale, as twist_probe holds it.
	_phone = _main.get("_phone")
	if _phone != null:
		_phone.set_process(false)
	for link: Dictionary in root.size_changed.get_connections():
		var call: Callable = link["callable"]
		if call.get_method() == &"_match_screen_density":
			root.size_changed.disconnect(call)
	var main_script: GDScript = _main.get_script()
	root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
		ShellPrefs.interface_size(), true)
	await _frames(20)
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_shell = _main.get("_shell")
	_store = _main.get("_store")
	var size: Vector2i = DisplayServer.window_get_size()
	print("phonepanels_probe: a %d x %d window laid out for a phone, %.3f units to the point"
		% [size.x, size.y, _pt()])
	_check("the phone's layout is made, and the camera takes fingers as a phone's",
		_phone != null and _camera.phone)
	if not await _way_in():
		await _finish()
		return
	_store.keeps = false
	await _frames(30)

	if _runs("page"):
		print("\n1. the page editor, on the car's page")
		await _page_editor()
		await _put_away_page_editor()
	if _runs("motions"):
		print("\n2. Motions, on 1484-1's doors")
		await _motions()
	if _runs("simulate"):
		print("\n3. Simulate, on a gear train")
		await _simulate()
	if _runs("measure"):
		print("\n4. Measure's words, to a finger")
		await _measure_words()
	print("")
	print("  act                                   desktop  here  most")
	for act: Array in _acts:
		print("  %-38s %7d %5d %5d" % act)
	var small: Array = _targets.filter(func(t: Array) -> bool:
		return minf(float(t[1]), float(t[2])) < LEAST)
	print("  %d targets measured, %d under %d points: %s" % [_targets.size(), small.size(),
		int(Phone.TARGET), ", ".join(small.map(func(t: Array) -> String:
			return "%s %.0f x %.0f" % t))])
	await _finish()


func _runs(section: String) -> bool:
	return _only.is_empty() or _only.has(section)


## The sign-in screen up, a throwaway account signed in, the screen gone.
func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	if not _check("the app is built, its account there to sign in to", account != null
			and bool(_main.get("_built"))):
		return false
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("phonepanels")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


## Signed in with a password grant on an account the admin key made: the
## token bucket, not a code's verify (binrow_probe).
func _sign_in(account: Account, email: String) -> String:
	_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


# -- 1. the page editor ----------------------------------------------------------


func _page_editor() -> void:
	_check("the car is on the baseplate (%d parts)" % _world.brick_count(), _world.brick_count() > 20)
	var editor: PageEditor = _main.get("_page_editor")
	var state: Dictionary = await _lay_out_page(editor)
	if not _check("Lay out the page… opens the page editor on a page (%s)" % state.get("page", "none"),
			int(state.get("page", 0)) > 0 and not (state.get("items", {}) as Dictionary).is_empty()):
		return
	await _shot("1_page_editor")
	var named: Dictionary = editor.controls_by_name()
	for name: String in PAGE_CONTROLS:
		_measure(name, named.get(name))
	# All of it on the screen: a line of its words once held it wider than a phone.
	var screen: Rect2 = root.get_visible_rect().grow(1.0)
	var cut: Array[String] = []
	for name: String in PAGE_CONTROLS + ["page_canvas"]:
		var control: Control = named.get(name) as Control
		if control != null and control.is_visible_in_tree() and not screen.encloses(control.get_global_rect()):
			cut.append(name)
	_check("every control and the page on the screen, none cut off at its edge (%s)"
		% ("all" if cut.is_empty() else "cut: " + ", ".join(cut)), cut.is_empty())

	# An item dragged by a finger.
	var picture: String = ""
	for name: String in (state["items"] as Dictionary):
		if name.begins_with("page_picture_"):
			picture = name
			break
	if picture.is_empty():
		_check("the page has a step's picture to drag", false)
		return
	_presses = 0
	var item: Control = editor.controls_by_name()[picture]
	var at: Vector2 = _middle(item)
	var was: Array = state["items"][picture]
	await _finger_drag(at, at + Vector2(30, 40) * _pt())
	var now: Dictionary = editor.page_state()
	_check("%s dragged by a finger: from %s to %s, in %d" % [picture, was, now["items"].get(picture), _presses],
		now["items"].get(picture) != was and _presses <= 2)
	_act("the page editor: an item dragged", 1)

	# One sized by its corner: the fingertip round it, outside the item.
	_presses = 0
	if editor.page_state().get("selected", "") != picture:
		await _tap(_middle(editor.controls_by_name()[picture]))
	var handle: Control = editor.controls_by_name().get("page_resize")
	if not _check("the picture selected shows its corner", handle != null):
		return
	_measure("page_resize", handle)
	# The tap that selected it drew the page's items again.
	var corner_rect: Rect2 = (editor.controls_by_name()[picture] as Control).get_global_rect()
	var grab: Vector2 = _middle(handle)
	was = editor.page_state()["items"][picture]
	print("    the corner's fingertip runs %.0f points past the item's corner, %.0f into it" % [
		(handle.get_global_rect().end.x - corner_rect.end.x) / _pt(),
		(corner_rect.end.x - handle.get_global_rect().position.x) / _pt()])
	await _finger_drag(grab, grab + Vector2(-24, -18) * _pt())
	now = editor.page_state()
	var sized: Array = now["items"].get(picture, [])
	_check("its corner dragged by a finger from just outside it sizes it: %s to %s, in %d" % [was, sized,
		_presses], sized.size() == 4 and float(sized[2]) < float(was[2]) - 1.0
		and is_equal_approx(float(sized[0]), float(was[0])) and _presses <= 2)
	_act("the page editor: an item sized by its corner", 1)
	await _shot("1_page_sized")

	# Words added.
	_presses = 0
	var notes: int = (editor.page_state()["notes"] as Dictionary).size()
	await _tap(_middle(editor.controls_by_name()["page_add_text"]))
	await _until(func() -> bool: return (editor.page_state()["notes"] as Dictionary).size() > notes, 6.0)
	var field: LineEdit = editor.controls_by_name()["page_words"]
	_check("Add words puts words on the page, selected in their field to type over (\"%s\", \"%s\" selected)"
		% [field.text, field.get_selected_text()],
		(editor.page_state()["notes"] as Dictionary).size() == notes + 1 and field.has_focus()
		and field.get_selected_text() == field.text and not field.text.is_empty())
	await _shot("1_page_words_added")
	# The tap that brings a phone's keyboard up.
	await _tap(_middle(field))
	_check("a tap in the field to bring the keyboard up keeps its words selected (\"%s\" of \"%s\")"
		% [field.get_selected_text(), field.text], field.has_focus() and field.get_selected_text() == field.text)
	await _type("Hi")
	_check("\"Hi\" typed over them: the field reads \"%s\", in %d presses" % [field.text, _presses],
		field.text == "Hi" and _presses <= 6)
	_act("the page editor: words added", 3)
	var words_item: String = str(editor.page_state().get("selected", ""))
	_measure("page_resize (words)", editor.controls_by_name().get("page_resize"))
	_measure("page_turn_knob", editor.controls_by_name().get("page_turn_knob"))
	await _shot("1_page_words_typed")

	# An arrow drawn by a finger: Draw an arrow, then a drag on the page. The
	# words typed are set as the selection leaves them.
	_presses = 0
	var arrows: int = (editor.page_state().get("arrows", {}) as Dictionary).size()
	await _tap(_middle(editor.controls_by_name()["page_add_arrow"]))
	await _until(func() -> bool: return not bool(editor.page_state().get("laying", false)), 10.0)
	var page: Rect2 = (editor.controls_by_name()["page_canvas"] as Control).get_global_rect()
	await _finger_drag(page.position + page.size * Vector2(0.12, 0.62),
		page.position + page.size * Vector2(0.32, 0.8))
	var drawn: Callable = func() -> bool:
		var now_state: Dictionary = editor.page_state()
		return (now_state.get("arrows", {}) as Dictionary).size() > arrows \
			and not bool(now_state.get("laying", false))
	await _until(drawn, 10.0)
	await _frames(10)
	var arrow: int = -1
	for n: int in editor._items.size():
		if editor._items[n]["kind"] == "arrow":
			arrow = n
	if _check("Draw an arrow and a finger's drag on the page draw one, in %d (%d arrows, were %d)" % [
			_presses, (editor.page_state().get("arrows", {}) as Dictionary).size(), arrows],
			arrow >= 0 and _presses <= 4):
		_act("the page editor: an arrow drawn", 2)
		if editor.page_state().get("selected", "") != editor._item_name(arrow):
			editor._select(arrow)
			await _frames(4)
		var handles: Dictionary = editor.controls_by_name()
		var points: int = 0
		for name: String in handles:
			# Its handles; not the arrow itself (page_arrow_N_I, an item drawn its own size).
			if name.begins_with("page_arrow_") and name != "page_arrow_colour" and name != "page_arrow_width" \
					and _item_name.search(name) == null:
				_measure(name, handles[name])
				points += 1
		_check("its %d handles measured" % points, points >= 3)
		await _shot("1_page_arrow")

	# Done.
	_presses = 0
	await _tap(_middle(editor.controls_by_name()["page_done"]))
	await _frames(6)
	_check("Done closes the page editor in %d" % _presses, not editor.is_open() and _presses == 1)
	_act("the page editor: Done", 1)
	# The words kept on the page, opened again.
	await _lay_out_page(editor)
	var kept: String = ""
	for n: int in editor._items.size():
		if editor._item_name(n) == words_item:
			kept = str((editor._items[n].get("note", {}) as Dictionary).get("text", ""))
	_check("opened again, the page's words read \"%s\"" % kept, kept == "Hi")


## The page editor and the timeline put away, whatever the section reached.
func _put_away_page_editor() -> void:
	var editor: PageEditor = _main.get("_page_editor")
	if editor != null and editor.is_open():
		editor.close()
		await _frames(6)
	if (_main.get("_steps") as StepsBar).visible:
		_shell.run("timeline")
		await _frames(10)


## Lay out the page…, as a person reaches it: from the timeline, on its step.
func _lay_out_page(editor: PageEditor) -> Dictionary:
	var steps: StepsBar = _main.get("_steps")
	if steps.current_step() == null:
		_shell.run("timeline")
		await _until(func() -> bool: return steps.current_step() != null, 8.0)
	if not _check("the timeline is on a step", steps.current_step() != null):
		return {}
	await _frames(10)
	# Its own Lay out the page… where its Booklet row shows (steps_bar.gd's,
	# not this unit's: said, not checked), else the command as More runs it.
	var own: Control = steps.controls_by_name().get("booklet_lay_out") as Control
	if own != null and own.is_visible_in_tree():
		var r: Rect2 = own.get_global_rect()
		print("    the timeline's Lay out the page… is shown, %.0f x %.0f points; tapped" % [r.size.x / _pt(), r.size.y / _pt()])
		await _tap(r.get_center())
	else:
		print("    the timeline shows no Lay out the page… (its Booklet row hidden, order %s); run as More runs it"
			% str(steps.page_state().get("order", "")))
		_check("Lay out the page… runs", _shell.run("booklet_lay_out"))
	return await _page_laid(editor)


## The page laid out and its pictures asked for.
func _page_laid(editor: PageEditor) -> Dictionary:
	var state: Dictionary = {}
	for _n: int in 900:
		await process_frame
		state = editor.page_state()
		if int(state.get("page", 0)) > 0 and not bool(state.get("laying", true)):
			break
	await _frames(10)
	return editor.page_state()


# -- 2. Motions ----------------------------------------------------------------------


func _motions() -> void:
	if not await _open(DOORS):
		return
	_shell.run("pose")
	var panel: PosePanel = _main.get("_pose")
	var grab: GrabDrag = _main.get("_grab_drag")
	await _until(func() -> bool: return panel.visible and grab != null and grab.is_ready(), 60.0)
	if not _check("Motions opens, the model's joints read (%s)" % (grab.is_ready() if grab != null else "no grab"),
			panel.visible and grab != null and grab.is_ready()):
		return
	await _frames(20)
	await _shot("2_motions_list")

	# A suggested motion kept first, as the walk does before it records: the
	# list then holds a motion and the suggestions above where New motion was.
	var keeps: Dictionary = panel.controls_by_name()
	if keeps.has("motion_keep_0"):
		await _press(keeps["motion_keep_0"] as Control)
		await _frames(10)
	_check("a suggested motion kept (%d in the model)" % panel._motions().list.size(),
		panel._motions().list.size() >= 1)

	# New motion, Record, a door swung, Stop.
	_presses = 0
	await _press(panel._new)
	await _until(func() -> bool: return panel._view == "edit", 6.0)
	_check("New motion opens the editor", panel._view == "edit")
	await _frames(10)
	# Its name and Record in sight as it opens, and no keyboard asked for
	# (the name not focused: a phone's keyboard would cover the sheet).
	var name_seen: bool = _shown_in(panel._name).grow(1.0).encloses(panel._name.get_global_rect()) \
		and panel._name.get_global_rect().size.x >= 60.0 * _pt()
	var record_seen: bool = _shown_in(panel._record).grow(1.0).encloses(panel._record.get_global_rect())
	_check("its name (%.0f points across) and Record in sight as it opens, the name not focused"
		% (panel._name.get_global_rect().size.x / _pt()), name_seen and record_seen and not panel._name.has_focus())
	await _shot("2_motions_new")
	await _press(panel._record)
	_check("Record listens", panel.is_recording())
	var doors: Array = _doors(grab, panel)
	if not _check("a part that turns on a joint shows above the panel (%d)" % doors.size(), not doors.is_empty()):
		return
	var picked: int = _builder.selection.size()
	var opened: Array[String] = []
	var swung: int = 0
	for door: Dictionary in doors.slice(0, 2):
		var from: Vector2 = door["screen"]
		var out: Vector2 = from - (door.get("pivot", from + Vector2(0, 1)) as Vector2)
		var way: Vector2 = Vector2(-out.y, out.x).normalized()
		var by: float = minf(70.0, Room.across() * 0.15) * _pt()
		await _walk_drag(from, from + way * by)
		await _frames(10)
		var sheet: String = _sheet()
		if not sheet.is_empty():
			opened.append("\"%s\" with %d selected" % [sheet, _builder.selection.size()])
			# Put away by its Done, as the walk does, to reach Stop.
			var done: Control = (_phone.call("controls_by_name") as Dictionary).get(
				"phone_sheet_%s_done" % sheet.to_lower().replace(" ", "_"))
			if done != null:
				await _tap(_middle(done))
		swung += 1
		if panel._rec_drags > 0 or panel._rec_grab != null:
			break
	await _shot("2_motions_recording")
	_check("a door swung by a finger while recording opens no part's actions over the panel (%s), the selection as it was (%d, was %d)"
		% ["none" if opened.is_empty() else ", ".join(opened), _builder.selection.size(), picked],
		opened.is_empty() and _builder.selection.size() == picked)
	await _press(panel._record)
	await _frames(10)
	var keys: int = 0
	var edited: Motions.Motion = panel._edited()
	if edited != null:
		for track: Motions.Track in edited.tracks:
			keys += track.keys.size()
	_check("Stop keeps the drag as keys (%d, %s), in %d presses" % [keys, panel.status_words().left(70), _presses],
		not panel.is_recording() and keys >= 2 and _presses <= 8)
	_act("Motions: a motion recorded by dragging", 4)
	await _shot("2_motions_recorded")

	# A joint set by its slider, from the editor as it opens.
	var name: String = edited.name if edited != null else ""
	panel.back_to_list()
	await _frames(6)
	panel.edit(name)
	await _until(func() -> bool: return panel._view == "edit" and not panel._joint_parts.is_empty(), 6.0)
	await _frames(10)
	_presses = 0
	if not _check("its editor lists its joints (%d)" % panel._joint_parts.size(), not panel._joint_parts.is_empty()):
		return
	var slider: HSlider = panel._joint_parts[0]["slider"]
	var brought: int = await _bring(slider)
	var place: float = slider.value
	var r: Rect2 = slider.get_global_rect()
	await _finger_drag(Vector2(r.position.x + r.size.x * 0.25, r.get_center().y),
		Vector2(r.position.x + r.size.x * 0.7, r.get_center().y))
	await _frames(10)
	# Letting go fills the rows again: the slider read is the new row's.
	var after: float = place
	if not panel._joint_parts.is_empty() and is_instance_valid(panel._joint_parts[0]["slider"]):
		after = (panel._joint_parts[0]["slider"] as HSlider).value
	_check("its first joint's slider in sight in %d drags, and a finger's drag along it moves the joint: %.0f to %.0f, in %d"
		% [brought, place, after, _presses], brought <= 1 and not is_equal_approx(after, place)
		and _presses <= 2)
	_act("Motions: a joint set by its slider", 1)
	await _shot("2_motions_slider")
	_measure_panel(panel, "motions")
	panel.close()
	await _frames(6)


## Parts that turn on a joint, where a finger would take hold of them, above
## the panel and in the model's room: {screen, pivot, part, ...}.
func _doors(grab: GrabDrag, panel: Control) -> Array:
	var room: Rect2 = _view()
	var top: float = panel.get_global_rect().position.y
	var out: Array = []
	var links: Dictionary = grab._bodies.parent_link
	for body: Variant in links:
		var spot: Variant = grab.handle_on(int(body), links[body])
		if spot == null:
			continue
		var at: Vector2 = spot["screen"]
		if room.grow(-8.0 * _pt()).has_point(at) and at.y < top - 8.0 * _pt():
			out.append(spot)
	return out


# -- 3. Simulate ----------------------------------------------------------------------


func _simulate() -> void:
	if not await _gear_train():
		return
	_shell.run("simulate")
	var panel: SimulatePanel = _main.get("_simulate")
	# Read, then driven: the Working bar says "Turning the mechanism…" until the driver is said.
	var driven: Callable = func() -> bool:
		return panel.visible and panel.sim != null and not panel._reading \
			and not panel._driving and not str(panel.said().get("driver", "")).is_empty()
	await _until(driven, 60.0)
	if not _check("Simulate opens, its mechanism read (%s)" % panel.said().get("driver", ""),
			panel.visible and panel.sim != null):
		return
	await _frames(20)
	await _shot("3_simulate_open")
	_presses = 0
	var brought: int = await _bring(panel._play)
	var heard: Array[String] = []
	var hear: Callable = func() -> void: heard.append("pressed")
	panel._play.pressed.connect(hear)
	await _press(panel._play)
	var turns_then: float = panel.turns
	await _frames(6)
	panel._play.pressed.disconnect(hear)
	_check("Play in sight as it opens (%d drags), and a tap plays it, in %d (Play heard %d, it says \"%s\", status \"%s\", %.3f to %.3f turns)"
		% [brought, _presses, heard.size(), panel._play.text, panel.said().get("status", ""), turns_then, panel.turns],
		brought == 0 and panel.playing and _presses == 1)
	_act("Simulate: played (from its panel)", 1)
	await _shot("3_simulate_playing")
	if panel.playing:
		panel._play.pressed.emit()
		await _frames(4)

	_presses = 0
	brought = await _bring(panel._scrub)
	var turns: float = panel.turns
	var r: Rect2 = panel._scrub.get_global_rect()
	await _finger_drag(Vector2(r.position.x + r.size.x * 0.3, r.get_center().y),
		Vector2(r.position.x + r.size.x * 0.55, r.get_center().y))
	await _frames(6)
	_check("the cycle's slider in sight (%d drags), dragged by a finger: %.3f to %.3f turns, in %d"
		% [brought, turns, panel.turns, _presses], brought <= 1 and not is_equal_approx(panel.turns, turns)
		and _presses <= 2)
	_act("Simulate: the cycle scrubbed", 1)
	await _shot("3_simulate_scrubbed")

	# Another part made the driver, by a tap.
	_presses = 0
	var driver: String = str(panel.said().get("driver", ""))
	var grab: GrabDrag = _main.get("_grab_drag")
	await _until(func() -> bool: return grab != null and grab.is_ready(), 30.0)
	var parts: Array = _doors(grab, panel) if grab != null and grab.is_ready() else []
	var driving: Array = panel.sim.model.bodies.get(panel.sim.driver, []) if panel.sim != null else []
	for spot: Dictionary in parts:
		if str(panel.said().get("driver", "")) != driver or _presses >= 3:
			break
		# A part that is not the driver's, as a person taps the other gear.
		if driving.has(int(spot.get("part", -1))):
			continue
		await _tap(spot["screen"] as Vector2)
		await _frames(10)
	var now: String = str(panel.said().get("driver", ""))
	_check("a tap on another part makes it the driver, in %d: %s" % [_presses, now.left(60)],
		now != driver and _presses <= 2)
	_act("Simulate: another part made the driver", 1)
	_measure_panel(panel, "simulate")
	panel.close()
	await _frames(6)


## simulate_probe's train, put down as it puts it: an 8 on one axle meshing a
## 24 on another, both upright through a Technic plate on the floor.
func _gear_train() -> bool:
	_main.call("clear_model")
	await _frames(10)
	var t: float = _top_of_floor()
	_flat("3709b", Vector3(0, t + 8, 0), 71)
	_upright("3705", Vector3(-20, t + 0.5, 0), 0)
	_upright("3705", Vector3(20, t + 0.5, 0), 0)
	_gear("3647", Vector3(-20, t + 24, 0), 14)
	_gear("3648a", Vector3(20, t + 24, 0), 72)
	await _frames(5)
	_camera.frame(AABB(Vector3(-50, t, -40), Vector3(100, 60, 80)), 1.2)
	await _settle()
	var parts: int = _world.brick_count() - _store.scenery.size()
	return _check("a gear train put down (%d parts besides the floor)" % parts, parts == 5)


func _top_of_floor() -> float:
	var library: Variant = _main.get("_library")
	var top: float = -INF
	for id: Variant in _store.scenery:
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		if brick == null:
			continue
		var box: AABB = (brick.transform * library.mesh_for(brick.part_id).bounds).abs()
		var studs: float = 4.0 if library.parts[brick.part_id].stud_count > 0 else 0.0
		top = maxf(top, box.end.y - studs)
	return top if top > -INF else 0.0


func _flat(part_id: String, at: Vector3, colour: int) -> int:
	return _place(part_id, Transform3D(Basis.IDENTITY, at), colour)


func _upright(part_id: String, foot: Vector3, colour: int) -> int:
	var bounds: AABB = (_main.get("_library")).mesh_for(part_id).bounds
	var basis := Basis.IDENTITY
	var longest: int = 0
	for n: int in 3:
		if bounds.size[n] > bounds.size[longest]:
			longest = n
	if longest == 0:
		basis = Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	elif longest == 2:
		basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	var box: AABB = (Transform3D(basis, Vector3.ZERO) * bounds).abs()
	var middle: Vector3 = box.get_center()
	return _place(part_id, Transform3D(basis, Vector3(foot.x - middle.x, foot.y - box.position.y,
		foot.z - middle.z)), colour)


func _gear(part_id: String, at: Vector3, colour: int) -> int:
	var spec: Dictionary = Mechanism.spec_of(part_id)
	var basis := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	if str(spec.get("axis", "z")) == "y":
		basis = Basis.IDENTITY
	return _place(part_id, Transform3D(basis, at), colour)


func _place(part_id: String, at: Transform3D, colour: int) -> int:
	var id: int = _world.add_brick(part_id, colour, at)
	_builder.register(id, part_id, at)
	return id


# -- 4. Measure ----------------------------------------------------------------------


func _measure_words() -> void:
	_shell.run("measure")
	await _frames(6)
	var hint: String = str((_phone.call("state") as Dictionary).get("hint", ""))
	var said: String = str(_phone.get("_said"))
	_check("Measure taken out says what a finger does: \"%s\"" % said,
		said.contains("tap") and not said.contains("click") and not said.contains("Esc"))
	print("    the line over the model: \"%s\"" % hint)
	_shell.run("measure")
	await _frames(4)


# -- targets --------------------------------------------------------------------------


## [param control]'s size, in points, kept to be said; a check when under a
## fingertip.
func _measure(name: String, held: Variant) -> void:
	if not is_instance_valid(held) or not (held as Control).is_visible_in_tree():
		_check("%s is there to measure" % name, false)
		return
	var size: Vector2 = (held as Control).get_global_rect().size / _pt()
	_targets.append([name, size.x, size.y])
	if minf(size.x, size.y) < LEAST:
		_check("%s is a fingertip or more across: %.0f x %.0f points" % [name, size.x, size.y], false)


## Every target in [param panel] that shows, and its keys' strips.
func _measure_panel(panel: Control, what: String) -> void:
	var count: int = 0
	var small: Array[String] = []
	for found: Node in panel.find_children("*", "Control", true, false):
		var control: Control = found
		if not control.is_visible_in_tree():
			continue
		var strip: bool = control is PosePanel.KeyStrip
		if not strip and not TouchSizing.takes(control):
			continue
		var size: Vector2 = control.get_global_rect().size / _pt()
		count += 1
		_targets.append(["%s %s" % [what, control.name], size.x, size.y])
		if minf(size.x, size.y) < LEAST:
			small.append("%s %s %.0f x %.0f" % [control.get_class(), control.name, size.x, size.y])
	_check("%s: every one of its %d targets a fingertip or more across%s" % [what, count,
		"" if small.is_empty() else ": " + ", ".join(small)], count > 0 and small.is_empty())


# -- fingers --------------------------------------------------------------------------


## A control pressed by a finger where it is, brought into sight first.
func _press(control: Control) -> void:
	await _bring(control)
	await _tap(_middle(control))


## Drags that bring [param control] wholly into sight in the lists round it,
## each counted, as the walk's: from the middle of the list's shown part,
## 4.5% of the screen's height. How many it took (9: never).
func _bring(control: Control) -> int:
	for n: int in 9:
		var clip: Rect2 = _shown_in(control)
		var rect: Rect2 = control.get_global_rect()
		if clip.grow(1.0).encloses(rect):
			return n
		if n == 8:
			break
		var list: ScrollContainer = _list_of(control)
		if list == null:
			return 9
		var room: Rect2 = list.get_global_rect().intersection(root.get_visible_rect())
		var from: Vector2 = Vector2(room.get_center().x, room.get_center().y)
		var by: float = Room.down() * SWIPE * _pt()
		var up: bool = rect.end.y > clip.end.y
		await _finger_drag(from, from + Vector2(0.0, -by if up else by), 14, 0.4)
	return 9


## Where [param control] can be seen: the screen, cut by every list round it.
func _shown_in(control: Control) -> Rect2:
	var clip: Rect2 = root.get_visible_rect()
	var up: Node = control.get_parent()
	while up != null and up is Control:
		if up is ScrollContainer or (up as Control).clip_contents:
			clip = clip.intersection((up as Control).get_global_rect())
		up = up.get_parent()
	return clip


## The innermost list round [param control] that cuts it off.
func _list_of(control: Control) -> ScrollContainer:
	var rect: Rect2 = control.get_global_rect()
	var up: Node = control.get_parent()
	while up != null:
		var list := up as ScrollContainer
		if list != null and not list.get_global_rect().grow(1.0).encloses(rect):
			return list
		up = up.get_parent()
	return null


func _middle(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _tap(at: Vector2, hold: float = 0.0) -> void:
	_presses += 1
	_touch(0, at, true)
	await _frames(2)
	if hold > 0.0:
		await create_timer(hold).timeout
	_touch(0, at, false)
	await _frames(6)


## A finger dragged from [param from] to [param to] in [param steps] moves
## [param every] seconds apart, then still [param still] seconds before it
## lifts.
func _finger_drag(from: Vector2, to: Vector2, steps: int = 12, still: float = 0.3,
		every: float = 0.0) -> void:
	_presses += 1
	_touch(0, from, true)
	await _frames(2)
	var at: Vector2 = from
	for k: int in range(1, steps + 1):
		var next: Vector2 = from.lerp(to, float(k) / steps)
		_drag_to(0, next, next - at)
		at = next
		if every > 0.0:
			await create_timer(every).timeout
		else:
			await _frames(2)
	if still > 0.0:
		await create_timer(still).timeout
	_touch(0, to, false)
	await _frames(8)


## A door swung as the walk swings one: 10 moves 40 ms apart, still 0.2 s.
func _walk_drag(from: Vector2, to: Vector2) -> void:
	await _finger_drag(from, to, 10, 0.2, 0.04)


func _touch(index: int, at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _drag_to(index: int, at: Vector2, by: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = _as_event(at)
	drag.relative = _as_event(by)
	Input.parse_input_event(drag)


## Keys of the on-screen keyboard, one press each.
func _type(text: String) -> void:
	for letter: String in text:
		_presses += 1
		for down: bool in [true, false]:
			var key := InputEventKey.new()
			key.pressed = down
			key.unicode = letter.unicode_at(0)
			key.keycode = OS.find_keycode_from_string(letter.to_upper())
			Input.parse_input_event(key)
			await _frames(2)
	await _frames(4)


## A point in the viewport's units as the window hands it over.
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


# -- the rest -----------------------------------------------------------------


func _act(what: String, desktop: int) -> void:
	_acts.append([what, desktop, _presses, desktop * 2])


func _open(path: String) -> bool:
	var real: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(real):
		_check("%s is here (tools/omr.py fetch brings the sets)" % path, false)
		return false
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", real)
	for _n: int in 900:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0 and not _store.laying:
			break
	await _frames(10)
	await _frames(30)
	_camera.frame(_world_box(), 1.1)
	await _settle()
	return _check("%s open (%d parts)" % [path.get_file(), _world.brick_count()], _world.brick_count() > 0)


func _world_box() -> AABB:
	var box := AABB()
	var first: bool = true
	for id: int in _world._bricks:
		var at: Vector3 = _world.get_brick(id).transform.origin
		box = AABB(at, Vector3.ZERO) if first else box.expand(at)
		first = false
	return box.grow(40.0)


func _until(test: Callable, seconds: float) -> void:
	var end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if bool(test.call()):
			return
		await process_frame


## A point in the window's units.
func _pt() -> float:
	return Phone.per_point(root)


## The model's room on the screen.
func _view() -> Rect2:
	return (_main.call("model_cover") as Dictionary)["view"]


## The phone's sheet open now, by its title; "" for none.
func _sheet() -> String:
	return str((_phone.call("state") as Dictionary).get("sheet", "")) if _phone != null else ""


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


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out.path_join(name + ".png"))
	if image != null and image.save_png(path) == OK:
		print("    picture: %s" % path)


func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("")
	print("phonepanels_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
