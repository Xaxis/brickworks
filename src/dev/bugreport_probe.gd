## Reporting a bug is one press from anywhere while the beta is open
## (bugreport, 2026-11-09; FeedbackDialog.open_report, PictureMarks,
## Shell.report_bug, Main._offer_reports and _on_script_error).
##
##   tools/probe.sh bugreport_probe                       (1280x720)
##   PROBE_SIZE=1400x900 tools/probe.sh bugreport_probe
##   godot --path . --resolution 1280x720 --script src/dev/bugreport_probe.gd
##   ... -- --shots=DIR    the pictures there, not in shots/bugreport/
##
## As a person meets it: the sign-in screen up (gate_for_probe), a throwaway
## account signed in through it (SignInHelper, a Resend test address,
## deleted at the end), a small model open. Every press is an input event to
## the window. In place of the deployment the report goes to a stand-in,
## which keeps what it was handed and answers as api/_feedback.js does.
##
##   the beta off (the deployment says so): no Report a bug in the top bar;
##   Help has Report a bug…; the app's menu's Send feedback… opens as it
##   did, nothing ticked but the picture;
##   the beta open: Report a bug beside Account; one click on it opens the
##   report over the model, the window's picture in it, a bug chosen; a
##   drag on the picture draws a box, and the picture the stand-in is handed
##   has that box, red, where it was drawn (each edge within 2 pixels), its
##   details the box in the picture's pixels; Send says the report's number
##   and offers Your reports, which opens the site's reports;
##   Help, Report a bug… (its row, as the menu runs it) opens it over the
##   model, and Escape puts it away with nothing sent;
##   Alt-Shift-R opens it, turning nothing, and Cancel puts it away with
##   nothing sent;
##   an error in the app's scripts, as the engine hands the log it, is said
##   above the model with Report this; one click opens the report from it
##   with its log lines ticked, the error among them, and they go with it;
##   the dialog fits the window, Send on the screen, each time;
##   the beta shut again: the top bar's button is gone, and an error says
##   nothing.
extends SceneTree

## Blue and yellow: no red of the model's own for the mark's to be taken for.
const MODEL := "0 FILE probe.ldr\n0 Probe\n1 1 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
## The mark's red, as it reads back from a JPEG.
const RED_LEAST := 170
const OTHER_MOST := 110

var _failures: int = 0
var _main: Node
var _shell: Shell
var _account: Account
var _shots: String = ""
var _sent: Array[Dictionary] = []
var _size: String = ""
var _email: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	var size: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [size.x, size.y]
	_shots = ProjectSettings.globalize_path("res://shots/bugreport/" + _size)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=").path_join(_size)
	DirAccess.make_dir_recursive_absolute(_shots)
	print("bugreport probe at %s" % _size)
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_shell = _main.get("_shell")
		if _shell != null and _main.get("_bin") != null:
			break
	if _shell == null:
		print("  bugreport probe: SKIPPED — the shell never came up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_account = _main.get("_account")
	while _account.state == Account.State.CHECKING:
		await _account.changed
	await _frames(10)
	await _sign_in()
	if not _account.signed_in():
		_finish()
		return
	var store: ModelStore = _main.get("_store")
	var opened: Dictionary = store.open_text(MODEL, "Probe")
	_check("a two-brick model is open", str(opened.get("error", "")).is_empty() and store.world.bricks().size() == 2)
	await _frames(20)
	print("bugreport probe: a line for the log")

	await _beta_off()
	if await _beta_on():
		await _from_the_bar()
		await _from_help()
		await _from_the_key()
		await _from_an_error()
		await _beta_shut()
	var gone: int = await SignInHelper.delete_accounts(_email.get_slice("@", 0).left(-10), root)
	print("  (removed %d throwaway account(s))" % gone)
	_finish()


## Through the sign-in screen, as a person: a throwaway account.
func _sign_in() -> void:
	var gate: Control = _main.get("_gate")
	_check("the sign-in screen is up before anyone is in", gate != null and gate.visible)
	_email = SignInHelper.throwaway("bugrep")
	var why: String = await SignInHelper.sign_in(_account, _email, root)
	for _n: int in 900:
		await process_frame
		if _account.signed_in() and (gate == null or not gate.visible or _account.age_ask):
			break
	if _account.age_ask:
		await _account.answer_age(3, int(Time.get_datetime_dict_from_system()["year"]) - 30)
		for _n: int in 300:
			await process_frame
			if gate == null or not gate.visible:
				break
	await _frames(20)
	_check("a throwaway account is signed in through the screen%s" % ("" if why.is_empty() else " (%s)" % why),
		_account.signed_in() and _account.email == _email and (gate == null or not gate.visible))


## The deployment saying the beta is open, or not, as /api/account does.
func _say_beta(open: bool) -> void:
	_account.set("beta_open", open)
	_account.changed.emit()
	await _frames(8)


func _beta_off() -> void:
	print("\nthe beta off")
	await _say_beta(false)
	_check("no Report a bug in the top bar", not _shell.controls_by_name().has("report_bug"))
	var help: MenuButton = _shell.menu("Help")
	_check("Help has Report a bug… (with its key, %s)" % Keymap.written("report_bug"),
		help != null and _shell.item_index(help.get_popup(), "report_bug") >= 0
		and help.get_popup().get_item_text(_shell.item_index(help.get_popup(), "report_bug")).begins_with("Report a bug"))
	_check("Send feedback… is in the app's menu as it was", "feedback" in _shell._shown(Shell.APP_MENU))
	_check("Send feedback… can be run", _shell.run("feedback"))
	await _frames(12)
	var dialog: FeedbackDialog = _shell.feedback
	if not _check("it opens", dialog != null and dialog.visible):
		return
	var state: Dictionary = dialog.page_state()
	var body: Dictionary = dialog.body()
	_check("as it was: titled Send feedback, no kind chosen, nothing ticked but the picture",
		dialog.title == "Send feedback" and not bool(state.get("reporting", false)) and str(body["kind"]).is_empty()
		and body.has("picture") and not body.has("details") and not body.has("log") and not body.has("model"))
	dialog.hide()
	await _frames(4)


func _beta_on() -> bool:
	print("\nthe beta open")
	await _say_beta(true)
	var named: Dictionary = _shell.controls_by_name()
	var bar: ModelBar = _main.get("_bar")
	var account: Control = bar.controls_by_name()["account"]
	var button: Control = named.get("report_bug")
	if not _check("Report a bug is in the top bar", button != null and button.is_visible_in_tree()):
		return false
	_check("...beside Account, on its line, to its left (%s, %s)" % [button.get_global_rect(), account.get_global_rect()],
		button.get_parent() == account.get_parent() and button.get_index() == account.get_index() - 1
		and absf(button.get_global_rect().get_center().y - account.get_global_rect().get_center().y) < 2.0
		and button.get_global_rect().end.x <= account.get_global_rect().position.x + 1.0)
	_check("...and the menus are still on one line with it", bar.size.y < 44.0)
	return true


func _from_the_bar() -> void:
	print("\nfrom the top bar")
	var world: BrickWorld = _main.get("_world")
	var bricks: int = world.bricks().size()
	await _click((_shell.controls_by_name()["report_bug"] as Control).get_global_rect().get_center())
	var dialog: FeedbackDialog = await _report_up()
	if dialog == null:
		return
	dialog.send = _stand_in
	var state: Dictionary = dialog.page_state()
	_check("one click opened the report, from the bar: %s" % state["title"],
		bool(state["reporting"]) and state["from"] == "bar" and state["title"] == "Report a bug")
	_check("...over the model, which is as it was", world.bricks().size() == bricks and _main.get("_shell") == _shell)
	var window: int = root.get_texture().get_image().get_width()
	var size: Array = state["picture_size"]
	_check("...with the window's picture (%s, the window %d wide)" % [size, window],
		bool(state["picture"]) and size.size() == 2 and int(size[0]) == mini(window, 1600))
	_check("...a bug chosen, and what was expected asked", dialog.body()["kind"] == "bug"
		and dialog.controls_by_name().has("report_expected"))
	_check("...the version ticked, the model and the log not", dialog.body().has("details")
		and dialog.body()["details"].has("version") and not dialog.body().has("model") and not dialog.body().has("log"))
	_check("...it fits the window, Send on the screen", _fits(dialog) and dialog.get_ok_button().is_visible_in_tree())
	_check("...and says what will be sent: %s" % state["sends"],
		str(state["sends"]).begins_with("What you wrote · the picture · the version and your system"))
	await _shot("1_report")

	# A box drawn on the picture, as a hand drags.
	var picture: Control = dialog.controls_by_name().get("report_picture")
	if not _check("the picture is there to mark", picture != null):
		return
	var shown: Rect2 = picture.call("shown_rect")
	var from: Vector2 = shown.position + shown.size * Vector2(0.30, 0.25)
	var to: Vector2 = shown.position + shown.size * Vector2(0.62, 0.55)
	await _drag(_in_window(picture, from), _in_window(picture, to))
	var marks: Array = picture.get("marks")
	var expect: Rect2i = Rect2i()
	if _check("a drag on it draws one box (%s)" % [marks], marks.size() == 1):
		var a: Vector2i = picture.call("to_picture", from)
		var b: Vector2i = picture.call("to_picture", to)
		expect = Rect2i(a.min(b), (b - a).abs())
		_check("...where it was drawn, in the picture's pixels (%s, drawn %s)" % [marks[0], expect],
			_near(marks[0], expect, 1))
	_check("...and the line says so: %s" % dialog.page_state()["sends"],
		"the picture, with 1 mark" in str(dialog.page_state()["sends"]))
	await _shot("2_marked")
	(dialog.controls_by_name()["feedback_words"] as TextEdit).text = "The second brick floats after I undo."
	(dialog.controls_by_name()["report_expected"] as TextEdit).text = "It sits back on the first."
	await _click(_centre(dialog.controls_by_name()["feedback_send"]))
	for _n: int in 120:
		await process_frame
		if not _sent.is_empty() and bool(dialog.page_state()["sent"]):
			break
	if not _check("Send hands the stand-in one report", _sent.size() == 1):
		return
	var went: Dictionary = _sent[0]
	_check("its words, what was expected, where from, and the account's token", went["kind"] == "bug"
		and went["words"] == "The second brick floats after I undo." and went.get("expected") == "It sits back on the first."
		and went["source"] == "app" and str(went["details"].get("from")) == "bar" and not str(went["token"]).is_empty()
		and not went.has("email"))
	var drawn: Image = Image.new()
	var jpeg: PackedByteArray = Marshalls.base64_to_raw(str(went.get("picture", {}).get("data", "")))
	var read: bool = drawn.load_jpg_from_buffer(jpeg) == OK
	var before: Image = dialog.get("_picture")
	var found: Array = _red_box(drawn, before, expect) if read else [Rect2i(), 0.0]
	_check("the picture it was handed (%dx%d) has the box, red, where it was drawn: found %s, drawn %s (each edge within 2 px; its edge %d%% red)"
		% [drawn.get_width(), drawn.get_height(), found[0], expect, roundi(float(found[1]) * 100.0)],
		read and _near(found[0], expect, 2) and float(found[1]) >= 0.9)
	_check("...and its details say the box: %s" % went["details"].get("marks", ""),
		str(went["details"].get("marks", "")) == "%d,%d,%d,%d" % [expect.position.x, expect.position.y,
			expect.size.x, expect.size.y])
	state = dialog.page_state()
	_check("sent, it says its number and where to follow it: %s / %s" % [state["said"], state["status"]],
		state["said"] == "Thank you. Report #41 is in." and "Your reports" in str(state["status"])
		and dialog.controls_by_name().has("report_reports") and dialog.get_ok_button().text == "Close")
	_check("...and still fits the window", _fits(dialog))
	await _shot("3_thanks")
	var asked: int = Outside.opened.size()
	await _click(_centre(dialog.controls_by_name()["report_reports"]))
	_check("Your reports opens the site's reports (%s), and the dialog goes"
		% (Outside.opened.back() if Outside.opened.size() > asked else "nothing"),
		Outside.opened.size() == asked + 1 and str(Outside.opened.back()).ends_with("/settings#feedback")
		and not dialog.visible)


func _from_help() -> void:
	print("\nfrom Help")
	var help: MenuButton = _shell.menu("Help")
	var popup: PopupMenu = help.get_popup()
	help.show_popup()
	await _frames(6)
	var at: int = _shell.item_index(popup, "report_bug")
	_check("Help is open with Report a bug… in it", popup.visible and at >= 0)
	await _shot("4_help")
	# The row pressed, as the menu runs it.
	popup.id_pressed.emit(popup.get_item_id(at))
	popup.hide()
	var dialog: FeedbackDialog = await _report_up()
	if dialog == null:
		return
	_check("one press of its row opened the report, from the menu", dialog.page_state()["from"] == "menu"
		and bool(dialog.page_state()["reporting"]) and _fits(dialog))
	_check("...afresh: no words, no marks", (dialog.controls_by_name()["feedback_words"] as TextEdit).text.is_empty()
		and str(dialog.page_state()["marks"]).is_empty())
	(dialog.controls_by_name()["feedback_words"] as TextEdit).text = "Typed, then thought better of."
	await _key(KEY_ESCAPE)
	_check("Escape puts it away, and nothing is sent", not dialog.visible and _sent.size() == 1)


func _from_the_key() -> void:
	print("\nfrom its key")
	var builder: Builder = _main.get("_builder")
	var turned: Variant = builder.get("held_rotation")
	var accel: int = Keymap.key_of("report_bug")
	_check("Report a bug… has Alt-Shift-R under the app's keys (%s)" % Keymap.listed("report_bug"),
		accel == KEY_MASK_ALT | KEY_MASK_SHIFT | KEY_R)
	# Its row in the keys' table, a column a preset.
	var row: Array = []
	var table: String = FileAccess.get_file_as_string("res://docs/app_ux3/keys.md")
	for line: String in table.split("\n"):
		if line.begins_with("| `report_bug` |"):
			row = Array(line.trim_prefix("|").trim_suffix("|").split("|")).map(
				func(cell: String) -> String: return cell.strip_edges())
	_check("docs/app_ux3/keys.md has its row", row.size() >= 10)
	for n: int in Keymap.PRESETS.size():
		var preset: String = Keymap.PRESETS[n]
		Keymap.use(preset)
		var written: String = str(row[6 + n]) if row.size() >= 10 else "?"
		_check("...and under %s's (%s, the table %s)" % [preset, Keymap.listed("report_bug"), written],
			Keymap.key_of("report_bug") == accel and Keymap.listed("report_bug") == written)
	Keymap.use("brickworks")
	await _press(accel)
	var dialog: FeedbackDialog = await _report_up()
	if dialog == null:
		return
	_check("Alt-Shift-R opened the report, from the key", dialog.page_state()["from"] == "key" and _fits(dialog))
	_check("...and turned nothing", builder.get("held_rotation") == turned)
	await _click(_centre(dialog.controls_by_name()["feedback_cancel"]))
	_check("Cancel puts it away, and nothing is sent", not dialog.visible and _sent.size() == 1)


func _from_an_error() -> void:
	print("\nfrom an error notice")
	var log: RecentLog = _main.get("_log")
	var said: String = "Invalid call. Nonexistent function 'boom' in base 'Nil'."
	# As the engine hands its logger a script's error (Logger.ERROR_TYPE_SCRIPT).
	log._log_error("_probe_fault", "res://src/dev/bugreport_probe.gd", 7, "", said, false, 2,
		[] as Array[ScriptBacktrace])
	await _frames(8)
	var notice: RestoreNotice = _main.get("_error_notice")
	var report: Control = notice.controls_by_name().get("error_got_it_report") if notice != null else null
	_check("an error in the app's scripts is said above the model, with Report this", notice != null
		and notice.is_visible_in_tree() and report != null and report.is_visible_in_tree()
		and notice.words().begins_with("Something went wrong in Brickworks."))
	if report == null:
		return
	await _shot("5_error_notice")
	await _click(report.get_global_rect().get_center())
	var dialog: FeedbackDialog = await _report_up()
	if dialog == null:
		return
	dialog.send = _stand_in
	var state: Dictionary = dialog.page_state()
	_check("one click opened the report from it, its log lines ticked: %s" % state["log"],
		state["from"] == "notice" and dialog.body().has("log") and "up to the error" in str(state["log"]))
	_check("...the error among them", str(dialog.body().get("log", "")).contains(said)
		and str(dialog.body().get("log", "")).contains("bugreport probe: a line for the log"))
	_check("...and the line says so: %s" % state["sends"], "log lines" in str(state["sends"])
		and "the error it said" in str(state["sends"]))
	_check("...it fits the window", _fits(dialog))
	await _shot("6_from_error")
	(dialog.controls_by_name()["feedback_words"] as TextEdit).text = "It said something went wrong as I opened the bin."
	await _click(_centre(dialog.controls_by_name()["feedback_send"]))
	for _n: int in 120:
		await process_frame
		if _sent.size() == 2:
			break
	if _check("Send hands the stand-in the report", _sent.size() == 2):
		_check("...with the error's log lines and the error", str(_sent[1].get("log", "")).contains(said)
			and str(_sent[1]["details"].get("error", "")).contains(said) and _sent[1]["details"].get("from") == "notice")
	dialog.hide()
	_check("the notice went with Report this", not notice.visible)
	log._log_error("_probe_fault", "res://src/dev/bugreport_probe.gd", 7, "", said, false, 2,
		[] as Array[ScriptBacktrace])
	await _frames(8)
	_check("the same error again says nothing more", not notice.visible)


func _beta_shut() -> void:
	print("\nthe beta shut again")
	await _say_beta(false)
	_check("the top bar's Report a bug is gone", not _shell.controls_by_name().has("report_bug"))
	var log: RecentLog = _main.get("_log")
	log._log_error("_probe_other", "res://src/dev/bugreport_probe.gd", 9, "", "Another fault.", false, 2,
		[] as Array[ScriptBacktrace])
	await _frames(8)
	var notice: RestoreNotice = _main.get("_error_notice")
	_check("an error says nothing", notice == null or not notice.visible)
	_check("Help still has Report a bug…", _shell.item_index(_shell.menu("Help").get_popup(), "report_bug") >= 0)


## The report up, within a second or so: the dialog, or null.
func _report_up() -> FeedbackDialog:
	for _n: int in 90:
		await process_frame
		var dialog: FeedbackDialog = _shell.get("_feedback")
		if dialog != null and dialog.visible and bool(dialog.page_state().get("reporting", false)):
			await _frames(6)
			return dialog
	_check("the report opened", false)
	return null


## The box drawn into [param image] near [param near] (8 px round): the
## bounds of its mark-red that [param before], the picture before its marks,
## had none of within 2 px, and how much of those bounds' edge is red.
func _red_box(image: Image, before: Image, near: Rect2i) -> Array:
	var same: bool = before != null and before.get_size() == image.get_size()
	var look: Rect2i = near.grow(8).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var least := Vector2i(image.get_width(), image.get_height())
	var most := Vector2i(-1, -1)
	for y: int in range(look.position.y, look.end.y):
		for x: int in range(look.position.x, look.end.x):
			if _red(image, x, y) and not (same and _red_near(before, x, y)):
				least = least.min(Vector2i(x, y))
				most = most.max(Vector2i(x, y))
	if most.x < 0:
		return [Rect2i(), 0.0]
	var on: int = 0
	var all: int = 0
	for x: int in range(least.x + 1, most.x):
		for y: int in [least.y + 1, most.y - 1]:
			all += 1
			on += 1 if _red(image, x, y) else 0
	for y: int in range(least.y + 1, most.y):
		for x: int in [least.x + 1, most.x - 1]:
			all += 1
			on += 1 if _red(image, x, y) else 0
	return [Rect2i(least, most - least + Vector2i.ONE), float(on) / maxf(1.0, float(all))]


func _red(image: Image, x: int, y: int) -> bool:
	var c: Color = image.get_pixel(x, y)
	return c.r8 >= RED_LEAST and c.g8 <= OTHER_MOST and c.b8 <= OTHER_MOST


## Whether the picture had red of its own within 2 px of a point.
func _red_near(image: Image, x: int, y: int) -> bool:
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var at := Vector2i(x + dx, y + dy)
			if at.x < 0 or at.y < 0 or at.x >= image.get_width() or at.y >= image.get_height():
				continue
			var c: Color = image.get_pixel(at.x, at.y)
			if c.r8 >= 150 and c.g8 <= 130 and c.b8 <= 130:
				return true
	return false


func _near(a: Rect2i, b: Rect2i, within: int) -> bool:
	return absi(a.position.x - b.position.x) <= within and absi(a.position.y - b.position.y) <= within \
		and absi(a.end.x - b.end.x) <= within and absi(a.end.y - b.end.y) <= within and b.size.x > 0


## Its title bar and its foot inside the window, in the window's own
## (content-scaled) units, as an embedded dialog is placed.
func _fits(dialog: FeedbackDialog) -> bool:
	var title: int = dialog.get_theme_constant("title_height")
	return root.get_visible_rect().grow(0.5).encloses(Rect2(dialog.position - Vector2i(0, title),
		dialog.size + Vector2i(0, title)))


## In place of the deployment: kept, and answered as it would be.
func _stand_in(asked: Dictionary, token: String) -> Dictionary:
	await process_frame
	var kept: Dictionary = asked.duplicate(true)
	kept["token"] = token
	_sent.append(kept)
	return {"code": 200, "body": {"id": 40 + _sent.size(), "beta": true, "attached": {"picture": asked.has("picture")},
		"said": "Thank you. Stood in."}}


# -- a hand ----------------------------------------------------------------------

## [param local], a point of [param control], in the window's own units: a
## dialog is a window of its own inside the app's, placed in it (Main's
## _page_places does the same).
func _in_window(control: Control, local: Vector2) -> Vector2:
	var at: Vector2 = control.get_global_transform() * local
	var holder: Viewport = control.get_viewport()
	if holder is Window and holder != root:
		at += Vector2((holder as Window).position)
	return at


func _centre(control: Control) -> Vector2:
	return _in_window(control, control.size * 0.5)


func _event_at(at: Vector2) -> Vector2:
	return at * (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size)


func _move(at: Vector2, held: bool = false) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _event_at(at)
	move.global_position = move.position
	move.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(move)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _event_at(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	_move(at)
	await _frames(3)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(6)


func _drag(from: Vector2, to: Vector2) -> void:
	_move(from)
	await _frames(3)
	_button(from, true)
	await _frames(2)
	for n: int in range(1, 9):
		_move(from.lerp(to, n / 8.0), true)
		await _frames(1)
	_button(to, false)
	await _frames(6)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


func _press(accel: int) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = Keymap.press_of(accel)
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


func _shot(name: String) -> void:
	for _n: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join(name + ".png"))
	print("  wrote %s" % _shots.path_join(name + ".png"))


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _finish() -> void:
	print("bugreport probe: %s" % ("all ok" if _failures == 0 else "%d failed" % _failures))
	quit(0 if _failures == 0 else 1)
